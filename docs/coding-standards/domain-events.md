# Domain Events — ECST Pattern

How to design, structure, and emit domain events in this codebase. This is the authoritative reference for event architecture; the [Domain Events Recipe](./recipes/domain-events.md) has copy-paste templates, and [Architecture Principles](./architecture-principles.md#domain-events-between-aggregates) covers the *why*.

---

## Table of Contents

1. [Core Concept: Event-Carried State Transfer (ECST)](#1-core-concept-event-carried-state-transfer-ecst)
2. [Event Anatomy](#2-event-anatomy)
3. [Sealed Hierarchy — One Per Aggregate](#3-sealed-hierarchy--one-per-aggregate)
4. [Snapshot — Carrying the Full State](#4-snapshot--carrying-the-full-state)
5. [Single Emitter Per Aggregate](#5-single-emitter-per-aggregate)
6. [Use Case Integration](#6-use-case-integration)
7. [Kafka Topic Contract](#7-kafka-topic-contract)
8. [Kafka Infrastructure — Producer & Consumer](#8-kafka-infrastructure--producer--consumer)
9. [Sessions — Transition Metadata](#9-sessions--transition-metadata)
10. [Anti-Patterns](#10-anti-patterns)
11. [Decision Records](#11-decision-records)
12. [Industry References](#12-industry-references)

---

## 1. Core Concept: Event-Carried State Transfer (ECST)

Every domain event carries a **complete snapshot** of the aggregate's state at the moment of the transition. This is the Event-Carried State Transfer pattern (Martin Fowler, 2017).

### Why ECST instead of minimal events?

| Minimal events (`ConversationClosed(id, closedAt)`) | ECST (`ConversationClosed(snapshot)`) |
|---|---|
| Consumer must call back to the source to get full state | Consumer is self-sufficient — no callback needed |
| Source service becomes a runtime dependency of every consumer | Consumers are fully decoupled — they can work offline |
| Adding a field to an event = coordinated deployment | Adding a field to the snapshot = backward-compatible addition |
| Suitable for in-process events between aggregates | Required for cross-service events and Lakehouse ingestion |

**The Lakehouse mandate makes ECST non-negotiable:** the data platform ingests domain events via Kafka to build analytics, audit trails, and ML pipelines. Each event must carry enough state to reconstruct the aggregate's view at that point in time. A minimal event forces the Lakehouse to call back to the service — defeating the purpose of event-driven data ingestion.

### When ECST is overkill

For **in-process** events between aggregates within the same service (e.g. Spring `ApplicationEventPublisher`), a lighter event is acceptable — the consumer can load the aggregate directly from the shared database. But the moment an event crosses a service boundary or reaches Kafka, it must carry the full snapshot.

---

## 2. Event Anatomy

Every domain event has three parts:

```
┌──────────────────────────────────────────────┐
│  Event                                       │
│  ├── variant: sealed class discriminator     │
│  │   (e.g. ConversationEvent.Closed)         │
│  ├── metadata: occurredAt, eventId           │
│  └── snapshot: full aggregate state          │
│      at the moment of the transition         │
└──────────────────────────────────────────────┘
```

- **Variant** — the sealed subclass tells consumers *what* happened without parsing the payload. Pattern-matching (`when`) gives compile-time exhaustiveness.
- **Metadata** — `eventId` (UUID, unique per emission), `occurredAt` (Instant, captured at creation). These are always present regardless of the variant.
- **Snapshot** — a `data class` containing the aggregate's full state as primitives and collections of primitives. The consumer never needs to call back.

---

## 3. Sealed Hierarchy — One Per Aggregate

Each aggregate has **one sealed class** that enumerates every event that aggregate can produce. This gives:

- **Compile-time safety** — `when(event)` is exhaustive. Adding a new variant forces every consumer to handle it.
- **Single import** — consumers import `ConversationEvent`, not a list of individual event types.
- **Co-location** — all event structure is visible in one file.

### Template

```kotlin
// domain/events/ConversationEvent.kt
sealed class ConversationEvent {
    abstract val eventId: UUID
    abstract val occurredAt: Instant
    abstract val snapshot: ConversationSnapshot

    data class Created(
        override val eventId: UUID = UUID.randomUUID(),
        override val occurredAt: Instant = Instant.now(),
        override val snapshot: ConversationSnapshot,
    ) : ConversationEvent()

    data class Queued(
        override val eventId: UUID = UUID.randomUUID(),
        override val occurredAt: Instant = Instant.now(),
        override val snapshot: ConversationSnapshot,
    ) : ConversationEvent()

    data class Closed(
        override val eventId: UUID = UUID.randomUUID(),
        override val occurredAt: Instant = Instant.now(),
        override val snapshot: ConversationSnapshot,
    ) : ConversationEvent()
}
```

### Naming rules

- The **sealed class** is `{Aggregate}Event` — singular, not plural.
- Each **variant** is a **past-tense verb** — `Created`, `Closed`, `Queued` — because events are facts, not commands.
- Full class path reads naturally: `ConversationEvent.Created`, `ConversationEvent.Closed`.
- File lives in `domain/events/` — events are domain concepts.

### Why not standalone data classes?

Standalone events (`ConversationCreated.kt`, `ConversationClosed.kt`, `ConversationQueued.kt`) scatter the event structure across multiple files. Adding a new transition means creating a new file and hoping every consumer discovers it. With a sealed class, the compiler forces every `when` block to handle the new variant — no event is silently ignored.

---

## 4. Snapshot — Carrying the Full State

The snapshot is a `data class` of **primitives only** — no domain types, no framework types. It is the event's payload and the aggregate's external representation.

### Template

```kotlin
// domain/events/ConversationSnapshot.kt
data class ConversationSnapshot(
    val conversationId: UUID,
    val customerId: UUID,
    val status: String,
    val customerPlatform: String,
    val language: String,
    val startedAt: Instant,
    val updatedAt: Instant?,
)
```

### Rules

1. **Primitives only** — `UUID`, `String`, `Instant`, `Int`, `Long`, `Boolean`, `List<String>`, etc. No `ConversationId`, no `ConversationStatus`, no `N26Locale.Lang`. The snapshot crosses boundaries — it must be serializable without domain imports.
2. **The aggregate builds the snapshot** — the aggregate knows its own state. Add a `fun toSnapshot(): ConversationSnapshot` method on the aggregate root. Never build the snapshot externally.
3. **Snapshot ≠ DTO** — the `toDTO()` method builds a DTO for HTTP responses. The `toSnapshot()` method builds a snapshot for events. They may carry the same fields today, but they serve different consumers and evolve independently.
4. **Additive evolution** — adding a new field to the snapshot is a backward-compatible change (new field defaults to `null`). Removing or renaming a field is a breaking change that requires a new topic version.

### Aggregate integration

```kotlin
// domain/Conversation.kt — inside the aggregate
fun toSnapshot(): ConversationSnapshot = ConversationSnapshot(
    conversationId = id,
    customerId = customerId,
    status = status.name,
    customerPlatform = customerPlatform.name,
    language = language.name,
    startedAt = startedAt,
    updatedAt = updatedAt,
)
```

---

## 5. Single Emitter Per Aggregate

Each aggregate has **one emitter port** — not one per event type. The emitter accepts the sealed parent type, so it handles every variant through a single interface.

### Why a single emitter?

| One emitter per event type | Single emitter per aggregate |
|---|---|
| N emitter interfaces per aggregate | 1 emitter interface per aggregate |
| N constructor parameters in the use case | 1 constructor parameter |
| Adding a new event = new interface + new impl + new mock | Adding a new event = new sealed variant, emitter doesn't change |
| Port proliferation makes testing noisy | Clean, stable interface |

### Template

**Port (domain layer):**

```kotlin
// domain/events/ConversationEventEmitter.kt
interface ConversationEventEmitter {
    fun emit(event: ConversationEvent)
}
```

The interface lives in `domain/events/` alongside the sealed class. It accepts `ConversationEvent` — the caller passes the specific variant (`ConversationEvent.Created(...)`) and the implementation handles routing internally.

**Implementation (infrastructure/outbound — transactional outbox):**

The implementation writes events to a **transactional outbox table** within the same database transaction as the aggregate save — not directly to Kafka. A separate polling publisher reads the outbox and sends to Kafka asynchronously. This eliminates the [dual-write problem](https://microservices.io/patterns/data/transactional-outbox.html): if the DB transaction rolls back, no event is stored; if Kafka is temporarily down, events accumulate in the outbox and are retried.

This is the pattern used by Sopranium ([`OutboxSubscriber`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/outbound/event/OutboxSubscriber.kt) → [`OutboxConfiguration`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/configuration/OutboxConfiguration.kt) → `PollingPublisherToKafka`).

```kotlin
// infrastructure/outbound/OutboxConversationEventEmitter.kt
@Component
class OutboxConversationEventEmitter(
    private val transactionalOutbox: TransactionalOutbox<KafkaOutboxMessage>,
    private val protoMapper: ConversationEventProtoMapper,
) : ConversationEventEmitter {

    override fun emit(event: ConversationEvent) {
        val key = event.snapshot.conversationId.toString()
        val payload = protoMapper.toProto(event).toByteArray()
        val eventType = event::class.simpleName!!

        transactionalOutbox.storeForReliablePublishing(
            KafkaOutboxMessage(
                stream = TOPIC,
                eventPayload = payload,
                key = key,
                eventType = eventType,
            )
        )
    }

    companion object {
        const val TOPIC = "valium.conversation.events.v1"
    }
}
```

The `transactionalOutbox.storeForReliablePublishing(...)` call inserts a row into the `outbox` table. Because the emitter is called inside a `@Transactional` use case, this insert participates in the same transaction as the `repository.save()`. The `PollingPublisherToKafka` (configured separately — see [§8](#8-kafka-infrastructure--producer--consumer)) reads the outbox periodically and sends each message to Kafka via `KafkaTemplate<String, ByteArray>`.

**Naming convention:**
- Port: `{Aggregate}EventEmitter` — e.g. `ConversationEventEmitter`
- Implementation: `Outbox{Aggregate}EventEmitter` — e.g. `OutboxConversationEventEmitter`

---

## 6. Use Case Integration

The use case orchestrates: load → mutate → save → emit. The event is constructed from the **saved** entity's snapshot — never from the pre-save state.

### Template

```kotlin
@Service
@Transactional
class CloseConversation(
    private val conversationRepository: ConversationRepository,
    private val eventEmitter: ConversationEventEmitter,
    private val clock: Clock,
) {
    operator fun invoke(conversationId: UUID): Either<CloseConversationDomainError, ConversationDTO> {
        val id = ConversationId(conversationId)

        val conversation = conversationRepository.findById(id)
            ?: return Either.Error(CloseConversationDomainError.NotFound(id))

        val closed = conversation.close(Instant.now(clock))
            .mapError { CloseConversationDomainError.AlreadyClosed(id) }
            .getOrElse { return Either.Error(it) }

        val saved = conversationRepository.save(closed)

        eventEmitter.emit(ConversationEvent.Closed(snapshot = saved.toSnapshot()))

        return Either.Success(saved.toDTO())
    }
}
```

### Save-then-emit ordering

```
repository.save(entity)        ← DB write
eventEmitter.emit(event)       ← outbox write (same DB transaction!)
return Either.Success(dto)
```

With the transactional outbox, both `repository.save()` and `eventEmitter.emit()` are **writes to the same database** within the same `@Transactional` method. Either both succeed or both fail — there is no window where the entity is saved but the event is lost, or vice versa.

The event must still be built from the **saved** entity, not the in-memory one. This guarantees the snapshot matches what is in the database.

### Delivery guarantee

The outbox guarantees **at-least-once delivery** to Kafka. The `PollingPublisherToKafka` reads uncommitted outbox rows and publishes them. If Kafka is temporarily unavailable, the rows stay in the outbox and are retried on the next poll. Consumers must be idempotent — they may see the same event more than once.

Because the outbox write is transactional, there is no "fire-and-forget vs. critical" distinction at the emitter level. Every emitted event is reliably stored. The distinction only applies to **in-process events** (e.g. Spring `ApplicationEventPublisher` for intra-service communication) where the transport is not transactional.

---

## 7. Kafka Topic Contract

### Topic naming

```
{service}.{aggregate}.events.v{version}
```

Examples:
- `valium.conversation.events.v1`
- `valium.chatbot.events.v1`

### Partition key

The partition key is the aggregate root's ID (`conversationId`). This guarantees that all events for the same aggregate are delivered **in order** within the same partition, which is critical for consumers that rebuild state from event streams.

### One topic per aggregate

Each aggregate gets its own topic. Never mix events from different aggregates into a single topic — it makes consumer filtering fragile and partition ordering meaningless.

### Wire format

Events are serialized as **Protobuf** before being sent to Kafka. The proto definitions live in `n26/argon`, not in this repository. See the [Proto Appendix](./domain-events-proto-appendix.md) for the Protobuf conventions, `oneof` discrimination, and the mapping layer.

### Ordering guarantee

Kafka guarantees ordering **within a partition**. Since all events for the same `conversationId` go to the same partition (via the partition key), consumers see:

```
ConversationEvent.Created  →  ConversationEvent.Queued  →  ConversationEvent.Closed
```

in the exact order they were emitted, for that conversation. Events for different conversations may interleave across partitions — this is expected and correct.

---

## 8. Kafka Infrastructure — Producer & Consumer

This section covers the infrastructure configuration that sits between the domain-level emitter/listener and the actual Kafka cluster. These are all `infrastructure/` concerns — the domain and application layers never see them.

### 8.1 Producer — Outbox + Polling Publisher

The producer path has two parts: the **outbox emitter** (§5, called from the use case) and the **polling publisher** (configured once, runs as a scheduled task).

```kotlin
// infrastructure/configuration/OutboxConfiguration.kt
@Configuration
class OutboxConfiguration {

    @Bean
    fun transactionalOutbox(
        dataSource: DataSource,
        meterRegistry: MeterRegistry,
    ) = TransactionalOutbox.withDefaults<KafkaOutboxMessage>(
        datasource = dataSource,
        tableName = "outbox",
        meterRegistry = meterRegistry,
    )

    @Bean
    fun pollingPublisher(
        dataSource: DataSource,
        kafkaTemplate: KafkaTemplate<String, ByteArray>,
        meterRegistry: MeterRegistry,
        taskScheduler: TaskScheduler,
    ) = PollingPublisherToKafka.Builder(
        datasource = dataSource,
        kafkaTemplate = kafkaTemplate,
        taskScheduler = taskScheduler,
        meterRegistry = meterRegistry,
        tableName = "outbox",
    )
        .pollForMessagesToDeliverEvery(Duration.ofMillis(500))
        .sendMessagesInBatchesOf(size = 100)
        .build()
}
```

Dependencies: `de.tech26.outbox:outbox-message-relay-spring-kafka` and `de.tech26.outbox:outbox-message-store`. These are N26 internal libraries — see Sopranium's [`OutboxConfiguration`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/configuration/OutboxConfiguration.kt) for a production reference.

The `KafkaTemplate<String, ByteArray>` is configured with `StringSerializer` (key) and `ByteArraySerializer` (value):

```kotlin
// infrastructure/configuration/KafkaProducerConfiguration.kt
@Configuration
class KafkaProducerConfiguration {

    @Bean
    fun kafkaTemplate(kafkaProperties: KafkaProperties): KafkaTemplate<String, ByteArray> =
        kafkaProperties.buildProducerProperties()
            .also { it[CommonClientConfigs.CLIENT_ID_CONFIG] = "valium-kafka-producer" }
            .let { DefaultKafkaProducerFactory(it, StringSerializer(), ByteArraySerializer()) }
            .let { KafkaTemplate(it) }
}
```

### 8.2 Consumer — `@KafkaListener` + Proto Deserialization

Kafka consumers sit in `infrastructure/inbound/` — the same layer as controllers, triggered by messages instead of HTTP. Two deserialization strategies are used across N26:

**Strategy A — N26 Kafka Starter (recommended for new code):**

Uses `KafkaProtoDeserializerBuilder` from `com.n26.n26-spring-boot-starter-kafka:sb3-starter` for automatic proto deserialization. The consumer receives the typed proto object directly.

```kotlin
// infrastructure/configuration/KafkaConsumerConfiguration.kt
@Configuration
class KafkaConsumerConfiguration {

    @Bean
    fun conversationEventConsumerFactory(
        kafkaProperties: KafkaProperties,
    ): ConsumerFactory<String, ConversationEventProto?> =
        DefaultKafkaConsumerFactory(
            kafkaProperties.buildConsumerProperties(),
            StringDeserializer(),
            KafkaProtoDeserializerBuilder(ConversationEventProto.parser()).build(),
        )

    @Bean
    fun conversationEventContainerFactory(
        conversationEventConsumerFactory: ConsumerFactory<String, ConversationEventProto?>,
        errorHandler: CommonErrorHandler,
    ): ConcurrentKafkaListenerContainerFactory<String, ConversationEventProto?> {
        val factory = ConcurrentKafkaListenerContainerFactory<String, ConversationEventProto?>()
        factory.consumerFactory = conversationEventConsumerFactory
        factory.setCommonErrorHandler(errorHandler)
        return factory
    }
}

// infrastructure/inbound/ConversationEventKafkaConsumer.kt
@Component
class ConversationEventKafkaConsumer(
    private val handleConversationClosed: HandleConversationClosedUseCase,
) {
    private val log = LoggerFactory.getLogger(this::class.java)

    @KafkaListener(
        topics = ["\${kafka.conversation-events.consumer.topic-name}"],
        containerFactory = "conversationEventContainerFactory",
        groupId = "\${kafka.conversation-events.consumer.group-id}",
    )
    fun consume(
        @Payload(required = false) event: ConversationEventProto?,
        @Header(KafkaHeaders.RECEIVED_KEY) key: String,
    ) {
        event?.let { processEvent(it, key) }
            ?: log.info("Tombstone event consumed for key=$key")
    }

    private fun processEvent(event: ConversationEventProto, key: String) {
        when {
            event.hasConversationClosed() -> handleConversationClosed(/* map proto to domain */)
            event.hasConversationCreated() -> { /* no-op or delegate */ }
            else -> log.warn("Unknown event variant for key=$key")
        }
    }
}
```

This pattern is used by Oxygenium ([`UserDeviceSnapshotConsumer`](https://github.com/n26/oxygenium/blob/main/service/src/main/kotlin/de/tech26/oxygenium/stream/consumer/kafka/UserDeviceSnapshotConsumer.kt), [`KafkaConsumerConfig`](https://github.com/n26/oxygenium/blob/main/service/src/main/kotlin/de/tech26/oxygenium/config/KafkaConsumerConfig.kt)).

**Strategy B — Manual ByteArray deserialization:**

Used by Sopranium ([`ComplianceCheckConsumer`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/inbound/stream/compliancecheck/ComplianceCheckConsumer.kt), [`AbstractComplianceCheckConsumer`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/inbound/stream/compliancecheck/AbstractComplianceCheckConsumer.kt)). The consumer receives raw `ByteArray` and manually calls `Proto.parseFrom(bytes)`. This gives more control over error handling at the cost of verbosity.

```kotlin
// infrastructure/inbound/ConversationEventKafkaConsumer.kt
@Component
class ConversationEventKafkaConsumer(
    private val handleConversationClosed: HandleConversationClosedUseCase,
) {
    @KafkaListener(
        topics = ["\${kafka.conversation-events.consumer.topic-name}"],
        containerFactory = "defaultKafkaListenerContainerFactory",
        groupId = "\${kafka.conversation-events.consumer.group-id}",
    )
    fun consume(
        message: Message<ByteArray>,
        acknowledgment: Acknowledgment,
    ) {
        try {
            val event = ConversationEventProto.parseFrom(message.payload)
            processEvent(event)
            acknowledgment.acknowledge()
        } catch (ex: InvalidProtocolBufferException) {
            log.error("Failed to deserialize event", ex)
            acknowledgment.nack(Duration.ofMillis(1000))
        }
    }
}
```

### 8.3 Consumer Error Handling

Both strategies require a `CommonErrorHandler` bean. The standard pattern at N26 is `DefaultErrorHandler` with exponential or fixed backoff, combined with a parking lot for messages that exhaust retries:

```kotlin
@Bean
fun kafkaErrorHandler(
    failedMessageHandler: ParkFailedKafkaMessage,  // sends to DLQ or parks in DB
): CommonErrorHandler {
    val backoff = ExponentialBackOff(1000L, 1.5).apply { maxElapsedTime = 30_000L }
    return DefaultErrorHandler(failedMessageHandler::invoke, backoff)
}
```

- **Retriable errors** (network timeout, DB lock) are retried with backoff.
- **Non-retriable errors** (deserialization failure, unknown event type) are classified to skip retries via `setClassifications(...)`.
- **Dead letters / parking:** after all retries are exhausted, the `ConsumerRecordRecoverer` implementation parks the message (Sopranium writes to a DB parking table via [`KafkaConfiguration`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/configuration/KafkaConfiguration.kt); others use a DLQ topic).

### 8.4 N26 Kafka Starter

The `com.n26.n26-spring-boot-starter-kafka:sb3-starter` (already in `application/build.gradle.kts`) provides:

- `KafkaProtoDeserializerBuilder` — typed proto deserialization from `ByteArray`
- `FailedToDeserializeProtoException` / `NonRetrievableException` — error classification
- Auto-configuration for SSL keystores and consumer group IDs

Reference the [N26 Kafka documentation](https://backstage.tech26.de/docs/default/component/backend-docs/onboarding/infrastructure/kafka/configuration/kafka-authentication-authorization/#authentication) for cluster configuration and authentication.

---

## 9. Sessions — Transition Metadata

Some state transitions carry metadata specific to that transition — information that is not part of the aggregate's persistent state but is useful for consumers.

A **session** is an example of this pattern: a UUID generated at the moment of a state transition, identifying that particular "session" of the conversation. For example, when a conversation transitions from `ACTIVE_VA` to `QUEUED`, a `queueSessionId` captures that specific handoff. The session ID is not stored in the `Conversation` aggregate — it exists only in the event.

### Template

When a transition needs extra metadata, add it to the specific sealed variant — not to the snapshot:

```kotlin
data class Queued(
    override val eventId: UUID = UUID.randomUUID(),
    override val occurredAt: Instant = Instant.now(),
    override val snapshot: ConversationSnapshot,
    val sessionId: UUID = UUID.randomUUID(),  // transition-specific metadata
) : ConversationEvent()
```

### Rules

- Transition metadata belongs on the **variant**, not the snapshot. The snapshot is the aggregate's state; the variant carries what happened and any context specific to that transition.
- Not every variant needs extra metadata — most carry only the snapshot.
- Do not overload this pattern. If the metadata is part of the aggregate's state, put it in the aggregate and the snapshot. Sessions are for ephemeral transition context only.

---

## 10. Anti-Patterns

### Event design

```kotlin
// ❌ Standalone data class per event — no compile-time exhaustiveness
data class ConversationCreated(val conversationId: UUID, val occurredAt: Instant)
data class ConversationClosed(val conversationId: UUID, val closedAt: Instant)
// ✅ Sealed hierarchy: ConversationEvent.Created, ConversationEvent.Closed

// ❌ Minimal event without snapshot — forces consumers to call back
data class ConversationClosed(val conversationId: UUID, val closedAt: Instant)
// ✅ Every event carries ConversationSnapshot — consumers are self-sufficient

// ❌ Domain types in snapshot — not serializable across boundaries
data class ConversationSnapshot(
    val conversationId: ConversationId,  // domain type, not UUID
    val status: ConversationStatus,      // enum, not String
)
// ✅ Primitives only: UUID, String, Instant, Int, Long, Boolean

// ❌ Snapshot built outside the aggregate
val snapshot = ConversationSnapshot(
    conversationId = conversation.id,   // reaches into aggregate internals
    status = conversation.status.name,
)
// ✅ Aggregate owns its representation: saved.toSnapshot()

// ❌ Event named as a command (present tense, imperative)
sealed class ConversationEvent {
    data class Close(...) : ConversationEvent()  // command, not event
}
// ✅ Past tense: Closed, Created, Queued

// ❌ Mutable fields in events
data class Created(var snapshot: ConversationSnapshot) : ConversationEvent()
// ✅ All fields are val — events are immutable facts
```

### Emitter design

```kotlin
// ❌ One emitter per event type — causes port proliferation
interface ConversationCreatedEmitter { fun emit(event: ConversationEvent.Created) }
interface ConversationClosedEmitter { fun emit(event: ConversationEvent.Closed) }
// ✅ Single emitter: ConversationEventEmitter.emit(event: ConversationEvent)

// ❌ Emitter returns Either — infrastructure failures are not business outcomes
interface ConversationEventEmitter {
    fun emit(event: ConversationEvent): Either<EmissionError, Unit>
}
// ✅ Returns Unit, throws on failure

// ❌ Emitter accepts entity instead of event
interface ConversationEventEmitter {
    fun emit(conversation: Conversation)  // emitter builds the event? No.
}
// ✅ Emitter accepts ConversationEvent — the use case builds the event

// ❌ Business logic in the emitter
class KafkaConversationEventEmitter : ConversationEventEmitter {
    override fun emit(event: ConversationEvent) {
        if (event is ConversationEvent.Created && isPriority(event)) {
            sendUrgentAlert()  // domain logic in infrastructure
        }
        kafkaTemplate.send(...)
    }
}
// ✅ Emitter is a pure transport adapter — serialize and send, nothing else

// ❌ No domain port — use case imports concrete infrastructure class
class CloseConversation(
    private val emitter: OutboxConversationEventEmitter  // infrastructure import in application layer
)
// ✅ Use case depends on the port: ConversationEventEmitter (interface in domain/)

// ❌ Direct kafkaTemplate.send() from emitter — dual-write problem
class KafkaConversationEventEmitter(
    private val kafkaTemplate: KafkaTemplate<String, ByteArray>,
) : ConversationEventEmitter {
    override fun emit(event: ConversationEvent) {
        kafkaTemplate.send(TOPIC, key, payload)  // outside DB transaction!
    }
}
// ✅ Use transactional outbox — write to outbox table within the same transaction

// ❌ Consuming Kafka events with Spring @EventListener
@EventListener
fun onConversationEvent(event: ConversationEvent) { ... }
// ✅ Use @KafkaListener for Kafka topics; @EventListener is for in-process Spring events only
```

### Use case integration

```kotlin
// ❌ Event built from pre-save state
val closed = conversation.close().getOrElse { ... }
eventEmitter.emit(ConversationEvent.Closed(snapshot = closed.toSnapshot()))  // not yet saved!
val saved = conversationRepository.save(closed)
// ✅ Save first, then emit from saved entity

// ❌ Emit before save — if save fails, event is already out
eventEmitter.emit(ConversationEvent.Created(snapshot = conversation.toSnapshot()))
conversationRepository.save(conversation)
// ✅ Save first: val saved = repository.save(conversation); emitter.emit(...)
```

---

## 11. Decision Records

| Decision | Rationale |
|---|---|
| ECST over minimal events | Lakehouse mandate — every event must carry full state for ingestion. Eliminates callback coupling. |
| Sealed hierarchy per aggregate | Compile-time exhaustiveness. Single import. Co-located structure. |
| Single emitter per aggregate | Reduces port proliferation. Stable interface when adding new event variants. |
| Primitives in snapshot | Snapshots cross service boundaries and feed Protobuf serialization. Domain types are not portable. |
| Aggregate builds snapshot | `toSnapshot()` encapsulates internal state — no external code reaches into aggregate fields. |
| Protobuf wire format | Company standard for Kafka. Schema evolution via `n26/argon`. See [Proto Appendix](./domain-events-proto-appendix.md). |
| Session metadata on variant | Transition context is ephemeral — it does not belong in the aggregate or the snapshot. |
| Transactional outbox | Eliminates dual-write problem. Guarantees at-least-once delivery. Matches Sopranium's production pattern ([`OutboxSubscriber`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/outbound/event/OutboxSubscriber.kt) + [`OutboxConfiguration`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/configuration/OutboxConfiguration.kt)). |
| `@KafkaListener` for consumers | Spring `@EventListener` is for in-process events. Kafka consumers use `@KafkaListener` with typed container factories. |
| N26 Kafka Starter for deserialization | `KafkaProtoDeserializerBuilder` provides typed proto deserialization, error classification, and SSL auto-config. |
| Save-then-emit ordering | Snapshot must reflect persisted state. Outbox write is in the same DB transaction as the save. |

---

## 12. Industry References

The patterns in this document are not invented here — they come from a well-established body of work on event-driven architecture and domain-driven design.

| Book / Article | Author | What it gives you |
|---|---|---|
| *Domain-Driven Design* | Eric Evans (2003) | Chapter 8 introduces domain events as first-class citizens of the model. The concept that events are facts — things that happened — originates here. |
| *Implementing Domain-Driven Design* | Vaughn Vernon (2013) | Chapters 8 and 13 cover domain events in depth: how aggregates produce them, how they cross bounded contexts, and the publish-subscribe mechanics. The most practical guidance on event design in a DDD context. |
| *[What do you mean by "Event-Driven"?](https://martinfowler.com/articles/201701-event-driven.html)* | Martin Fowler (2017) | Defines the three flavors of event-driven architecture: Event Notification, Event-Carried State Transfer (ECST), and Event Sourcing. Our snapshot pattern is ECST — this article is the canonical explanation. |
| *Building Event-Driven Microservices* | Adam Bellemare (2020) | End-to-end treatment of event-driven systems: event schemas, topic design, consumer patterns, exactly-once semantics, and the transactional outbox. Covers Kafka natively. |
| *Designing Data-Intensive Applications* | Martin Kleppmann (2017) | Chapter 11 (Stream Processing) covers event logs, dual-write problems, change data capture, and the outbox pattern. The theoretical foundation for why we use a transactional outbox instead of direct Kafka writes. |
| *Enterprise Integration Patterns* | Gregor Hohpe & Bobby Woolf (2003) | The canonical catalog of messaging patterns: event message, publish-subscribe channel, dead letter channel, idempotent receiver. The vocabulary used in §8 comes from here. |
| *Microservices Patterns* | Chris Richardson (2018) | Chapter 3 covers the transactional outbox and polling publisher in detail as solutions to the dual-write problem. Directly influenced our outbox + `PollingPublisherToKafka` architecture. |
| *Building Microservices* | Sam Newman (2nd ed., 2021) | Chapters 4 and 6 cover event-driven communication between services, choreography vs orchestration, and the trade-offs of asynchronous messaging. Practical guidance on when events are the right integration choice. |
| *Monolith to Microservices* | Sam Newman (2019) | Chapter 4 (Decomposing the Database) covers the strangler pattern, change data capture, and the outbox as strategies for decoupling data ownership — directly relevant to how we emit events from a transactional boundary. |

---

## See Also

- [Domain Events Recipe](./recipes/domain-events.md) — copy-paste templates
- [Architecture Principles — Domain Events](./architecture-principles.md#domain-events-between-aggregates) — architectural rationale
- [Proto Appendix](./domain-events-proto-appendix.md) — Protobuf conventions and `n26/argon` reference
- [Quick Reference — Domain Events](./quick-reference.md#domain-events) — cheat-sheet

### N26 Production References

Source files used as precedent for the patterns documented here:

**Sopranium** (`n26/sopranium` — Internal Payments Service):

| Concern | File |
|---|---|
| Domain events (sealed class) | [`DomainEvents.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/domain/model/DomainEvents.kt) |
| Outbox subscriber | [`OutboxSubscriber.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/outbound/event/OutboxSubscriber.kt) |
| Proto mapper | [`InternalPaymentEventMapper.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/outbound/event/InternalPaymentEventMapper.kt) |
| Outbox + polling publisher config | [`OutboxConfiguration.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/configuration/OutboxConfiguration.kt) |
| Kafka template + error handler | [`KafkaConfiguration.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/configuration/KafkaConfiguration.kt) |
| Consumer (`@KafkaListener`) | [`ComplianceCheckConsumer.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/inbound/stream/compliancecheck/ComplianceCheckConsumer.kt) |
| Consumer base (manual ack) | [`AbstractComplianceCheckConsumer.kt`](https://github.com/n26/sopranium/blob/main/src/main/kotlin/com/n26/sopranium/infrastructure/adapters/inbound/stream/compliancecheck/AbstractComplianceCheckConsumer.kt) |

**Oxygenium** (`n26/oxygenium` — Authentication Service):

| Concern | File |
|---|---|
| Typed proto consumer | [`UserDeviceSnapshotConsumer.kt`](https://github.com/n26/oxygenium/blob/main/service/src/main/kotlin/de/tech26/oxygenium/stream/consumer/kafka/UserDeviceSnapshotConsumer.kt) |
| Consumer config (N26 Starter) | [`KafkaConsumerConfig.kt`](https://github.com/n26/oxygenium/blob/main/service/src/main/kotlin/de/tech26/oxygenium/config/KafkaConsumerConfig.kt) |
