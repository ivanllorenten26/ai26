# Domain Events — Protobuf Appendix

Conventions for the Protobuf wire format used to serialize domain events onto Kafka. This is a companion to [Domain Events — ECST Pattern](./domain-events.md); read that first for the domain-side design.

---

## Proto Repository

Proto definitions live in **[n26/argon](https://github.com/n26/argon)** — the company-wide schema repository. They do not live in this repository. Every service that produces or consumes Kafka events references `argon` protos via code generation.

### Argon module structure

Argon has two top-level modules:

| Module | Transport | Status |
|--------|-----------|--------|
| `v1/`  | Kinesis streams | **Deprecated** — do not add new definitions here |
| `v2/`  | Kafka topics | **Current** — all new protos go here |

Within `v2/`, the proto root is `v2/argon/src/main/proto/`. The full file path follows the pattern:

```
v2/argon/src/main/proto/n26/proto/app/{service}/{domain}/{schema-version}/{file}.proto
```

The `{schema-version}` (e.g. `v1`) is the **proto schema version**, not the transport version. A brand-new Kafka proto starts at `v1`. The transport (Kafka vs Kinesis) is determined by the top-level module (`v2/` vs `v1/`).

### Production precedent — Sopranium

Sopranium's [`InternalPaymentEventMapper`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/outbound/event/InternalPaymentEventMapper.kt) maps domain events to its proto definition at:

```
v2/argon/src/main/proto/n26/proto/app/sopranium/internalpayment/v1/internal_payment_events.proto
```

### Valium's proto layout

Valium's protos follow the same convention:

```
v2/argon/src/main/proto/n26/proto/app/valium/conversation/v1/conversation_events.proto
```

> **Package** (inside the `.proto` file): `n26.proto.app.valium.conversation.v1`

### CODEOWNERS

When adding a new service directory to argon, add the team as code owner in the `CODEOWNERS` file:

```
n26/proto/*/valium @n26/valium-team
```

This pattern covers `api`, `app`, and `stream` definitions. PRs to argon must be approved by the listed code owners.

---

## Proto Structure — `oneof` for Variant Discrimination

The sealed class hierarchy in Kotlin maps to a `oneof` in Proto. The `oneof` field acts as the variant discriminator — consumers switch on which field is set, exactly like Kotlin's `when(event)`.

### Sketch

```protobuf
syntax = "proto3";

package n26.proto.app.valium.conversation.v1;

option java_multiple_files = true;
option java_outer_classname = "ConversationEventsProto";
option java_package = "com.n26.proto.app.valium.conversation.v1";
option go_package = "github.com/n26/argon/v2/valium.conversation.v1";

import "google/protobuf/timestamp.proto";
import "google/api/field_behavior.proto";

message ConversationEvent {
    string event_id = 1;
    google.protobuf.Timestamp occurred_at = 2;
    ConversationSnapshot snapshot = 3;

    oneof variant {
        Created created = 10;
        Queued queued = 11;
        Closed closed = 12;
        // New variants get the next field number — never reuse a number
    }
}

message Created {
    // No extra fields — snapshot carries all state
}

message Queued {
    string session_id = 1;  // transition-specific metadata
}

message Closed {
    // No extra fields
}

message ConversationSnapshot {
    string conversation_id = 1;
    string customer_id = 2;
    string status = 3;
    string customer_platform = 4;
    string language = 5;
    google.protobuf.Timestamp started_at = 6;
    google.protobuf.Timestamp updated_at = 7;  // nullable: absence = not set
}
```

### Mapping to the sealed hierarchy

| Proto concept | Kotlin concept |
|---|---|
| `ConversationEvent` message | `ConversationEvent` sealed class |
| `oneof variant` | Sealed subclass (`Created`, `Queued`, `Closed`) |
| `ConversationSnapshot` message | `ConversationSnapshot` data class |
| `event_id`, `occurred_at` | `abstract val eventId`, `abstract val occurredAt` |
| Variant-specific fields (`session_id` in `Queued`) | Extra properties on the variant data class |

---

## Mapper — Infrastructure Outbound

The mapper converts between the Kotlin sealed hierarchy and the Proto generated classes. It lives in `infrastructure/outbound/` because Protobuf serialization is a transport concern — the domain never sees Proto types.

The mapper is used in two places:
1. **Producer side** — `OutboxConversationEventEmitter` calls `toProto()` before writing `toByteArray()` to the transactional outbox.
2. **Consumer side** — `ConversationEventKafkaConsumer` (or its mapper dependency) calls `fromProto()` to reconstruct the domain event from the wire format.

### Template

```kotlin
// infrastructure/outbound/ConversationEventProtoMapper.kt
@Component
class ConversationEventProtoMapper {

    fun toProto(event: ConversationEvent): ConversationEventProto {
        val builder = ConversationEventProto.newBuilder()
            .setEventId(event.eventId.toString())
            .setOccurredAt(event.occurredAt.toProtoTimestamp())
            .setSnapshot(event.snapshot.toProto())

        when (event) {
            is ConversationEvent.Created -> builder.setCreated(CreatedProto.getDefaultInstance())
            is ConversationEvent.Queued -> builder.setQueued(
                QueuedProto.newBuilder().setSessionId(event.sessionId.toString()).build()
            )
            is ConversationEvent.Closed -> builder.setClosed(ClosedProto.getDefaultInstance())
        }

        return builder.build()
    }

    fun fromProto(proto: ConversationEventProto): ConversationEvent {
        val snapshot = proto.snapshot.toDomain()
        val eventId = UUID.fromString(proto.eventId)
        val occurredAt = proto.occurredAt.toInstant()

        return when (proto.variantCase) {
            CREATED -> ConversationEvent.Created(eventId, occurredAt, snapshot)
            QUEUED -> ConversationEvent.Queued(eventId, occurredAt, snapshot, UUID.fromString(proto.queued.sessionId))
            CLOSED -> ConversationEvent.Closed(eventId, occurredAt, snapshot)
            VARIANT_NOT_SET -> throw IllegalArgumentException("ConversationEvent variant not set")
        }
    }

    private fun ConversationSnapshot.toProto(): ConversationSnapshotProto =
        ConversationSnapshotProto.newBuilder()
            .setConversationId(conversationId.toString())
            .setCustomerId(customerId.toString())
            .setStatus(status)
            .setCustomerPlatform(customerPlatform)
            .setLanguage(language)
            .setStartedAt(startedAt.toProtoTimestamp())
            .also { builder -> updatedAt?.let { builder.setUpdatedAt(it.toProtoTimestamp()) } }
            .build()

    private fun ConversationSnapshotProto.toDomain(): ConversationSnapshot =
        ConversationSnapshot(
            conversationId = UUID.fromString(conversationId),
            customerId = UUID.fromString(customerId),
            status = status,
            customerPlatform = customerPlatform,
            language = language,
            startedAt = startedAt.toInstant(),
            updatedAt = if (hasUpdatedAt()) updatedAt.toInstant() else null,
        )
}
```

### Rules

1. **Mapper lives in `infrastructure/outbound/`** — Proto types are framework types. The domain layer never imports them.
2. **`when` on `variantCase` must be exhaustive** — no `else` branch. Adding a new variant to the proto forces a compile error until the mapper handles it.
3. **`VARIANT_NOT_SET` throws** — a proto without a variant is a corrupt message, not a business error.
4. **Private extension functions** for `toProto()` / `toDomain()` — keeps the mapper self-contained. Do not scatter proto conversions across multiple files.

---

## Consumer Deserialization

Two strategies for deserializing Proto messages on the consumer side. Both are production-proven at N26.

### Strategy A — N26 Kafka Starter (recommended)

Use `KafkaProtoDeserializerBuilder` from `n26-spring-boot-starter-kafka` to get a typed `ConsumerFactory` — the framework deserializes the proto before the listener method is called.

```kotlin
// infrastructure/inbound/KafkaConsumerConfiguration.kt
@Configuration
class KafkaConsumerConfiguration(
    private val kafkaProperties: KafkaProperties,
) {
    @Bean
    fun conversationEventConsumerFactory(): ConsumerFactory<String, ConversationEventProto> =
        DefaultKafkaConsumerFactory(
            kafkaProperties.buildConsumerProperties(null),
            StringDeserializer(),
            KafkaProtoDeserializerBuilder.forProto(ConversationEventProto.getDefaultInstance())
                .withFailOnUnknownFields(false)
                .build()
        )

    @Bean
    fun conversationEventListenerContainerFactory(
        conversationEventConsumerFactory: ConsumerFactory<String, ConversationEventProto>,
    ): ConcurrentKafkaListenerContainerFactory<String, ConversationEventProto> =
        ConcurrentKafkaListenerContainerFactory<String, ConversationEventProto>().apply {
            consumerFactory = conversationEventConsumerFactory
            setCommonErrorHandler(
                DefaultErrorHandler(FixedBackOff(1000L, 3L))
            )
            containerProperties.ackMode = ContainerProperties.AckMode.BATCH
        }
}
```

The listener receives a typed proto directly:

```kotlin
@KafkaListener(
    topics = ["valium.conversation.events.v1"],
    containerFactory = "conversationEventListenerContainerFactory",
)
fun consume(@Payload(required = false) event: ConversationEventProto?) {
    event ?: return  // Tombstone
    val domainEvent = protoMapper.fromProto(event)
    // ...
}
```

**Precedent:** Oxygenium's [`UserDeviceSnapshotConsumer.kt`](https://github.com/n26/oxygenium/blob/main/service/src/main/kotlin/de/tech26/oxygenium/stream/consumer/kafka/UserDeviceSnapshotConsumer.kt) + [`KafkaConsumerConfig.kt`](https://github.com/n26/oxygenium/blob/main/service/src/main/kotlin/de/tech26/oxygenium/config/KafkaConsumerConfig.kt).

### Strategy B — Manual `ByteArray` deserialization

Use `ConsumerFactory<String, ByteArray>` and deserialize manually — gives full control over error handling.

```kotlin
@KafkaListener(
    topics = ["valium.conversation.events.v1"],
    containerFactory = "manualAcknowledgmentKafkaListenerContainerFactory",
)
fun consume(message: Message<ByteArray>, acknowledgment: Acknowledgment) {
    val event = ConversationEventProto.parseFrom(message.payload)
    val domainEvent = protoMapper.fromProto(event)
    // ...
    acknowledgment.acknowledge()
}
```

**Precedent:** Sopranium's [`ComplianceCheckConsumer.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/inbound/stream/compliancecheck/ComplianceCheckConsumer.kt) + [`AbstractComplianceCheckConsumer.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/inbound/stream/compliancecheck/AbstractComplianceCheckConsumer.kt).

### Which strategy to choose?

| | Strategy A (N26 Starter) | Strategy B (Manual ByteArray) |
|---|---|---|
| Boilerplate | Less — framework handles deserialization | More — manual `parseFrom` + ack |
| Error classification | Built-in via `FailedToDeserializeProtoException` | Manual try/catch |
| Tombstone handling | `@Payload(required = false)` — nullable param | Check `message.payload` for null/empty |
| Ack mode | BATCH (default) or MANUAL | MANUAL (explicit `acknowledge()`) |
| Best for | Standard event consumption | Complex error handling, conditional acks |

**Default choice:** Strategy A — it reduces boilerplate and integrates with the N26 Kafka Starter's error classification.

---

## Schema Evolution

Proto fields are **additive** — new optional fields can be added without breaking existing consumers. The rules:

| Change | Safe? | Why |
|---|---|---|
| Add optional field to `ConversationSnapshot` | Yes | Old consumers ignore unknown fields |
| Add new variant to `oneof` | Yes | Old consumers see `VARIANT_NOT_SET` — mapper throws, DLQ catches |
| Remove a field | No | Existing consumers that read it will get default values silently |
| Rename a field | No | Proto uses field numbers, not names, but generated code changes |
| Change a field number | No | Binary-incompatible — breaks all consumers |
| Change field type | No | Different wire encoding — breaks deserialization |

When a breaking change is unavoidable, create a **new topic version** (`v2`) and run both topics in parallel during migration:
```
valium.conversation.events.v1  ← old consumers
valium.conversation.events.v2  ← new consumers
```

---

## See Also

- [Domain Events — ECST Pattern](./domain-events.md) — the domain-side design
- [Domain Events Recipe](./recipes/domain-events.md) — copy-paste templates
- [Architecture Principles — Domain Events](./architecture-principles.md#domain-events-between-aggregates) — architectural rationale
