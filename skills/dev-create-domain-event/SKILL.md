---
name: dev-create-domain-event
description: Creates domain events with aggregate snapshot payload (event-carried state transfer) and their infrastructure emitters. When an aggregate emits multiple event types, wraps them in a single sealed {Aggregate}Event envelope — the sopranium InternalPaymentEvent pattern. Use when an aggregate state change needs to notify other parts of the system.
argument-hint: [AggregateName] emitting [list of transitions] in [module]
---

# Create Domain Event

Creates domain events using **Event-Carried State Transfer (ECST)** — every event carries a full snapshot of the aggregate state at emission time. Consumers never need to call back to the source. Events are published via a **transactional outbox** to Kafka.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Output Files

For an aggregate named `{Aggregate}` with transitions `Created`, `Closed`, etc.:

| File | Layer |
|---|---|
| `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/events/{Aggregate}Snapshot.kt` | Domain |
| `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/events/{Aggregate}Event.kt` | Domain |
| `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{Aggregate}EventEmitter.kt` | Domain port |
| `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/Outbox{Aggregate}EventEmitter.kt` | Infrastructure |

Snapshot and event files live in `domain/events/`. Emitter port lives in `domain/` (alongside the generic `EventEmitter<T>` interface).

## Implementation Rules

### Snapshot (`{Aggregate}Snapshot.kt` — `domain/events/`)
- ✅ `data class` of **primitives only** — `UUID`, `String`, `Instant`, `Long`, `Boolean`, nullable variants
- ✅ Zero domain types — convert enums to `String` via `.name`, IDs to `UUID` via `.value`
- ✅ Carries the **full** aggregate state at the moment of emission — ECST
- ✅ Zero framework annotations
- ❌ No domain enum fields (`ConversationStatus`) — use `String` (e.g. `status: String`)
- ❌ No domain ID types (`ConversationId`) — use `UUID` (e.g. `conversationId: UUID`)

### Event envelope (`{Aggregate}Event.kt` — `domain/events/`)
- ✅ `sealed class {Aggregate}Event : Event` — extends the `Event` interface; one class per aggregate
- ✅ `abstract override val eventId: UUID`, `abstract override val occurredAt: Instant`, `abstract override val key: String` in the sealed class
- ✅ `abstract override val snapshot: {Aggregate}Snapshot` in the sealed class
- ✅ Each variant is a `data class` with `eventId = UUID.randomUUID()` as default. **No default for `occurredAt`** — caller passes `Instant.now(clock)` explicitly
- ✅ Each variant defines `override val key: String` (required by the `Event` interface)
- ✅ Variants named in **past tense** (`Created`, `Closed`, `Queued`) — they are facts
- ✅ Variants can carry transition-specific fields beyond the snapshot (e.g. `sessionId` for `Queued`)
- ❌ No `previousStatus` field — the sealed variant name IS the transition signal
- ❌ No framework annotations
- ❌ No `occurredAt = Instant.now()` default — always pass via injected `Clock`

### Emitter port (`{Aggregate}EventEmitter.kt` — `domain/`)
- ✅ `fun interface` in domain layer — zero framework imports, extends generic `EventEmitter<{Aggregate}Event>`
- ✅ Single method: `fun emit(event: {Aggregate}Event)` — returns `Unit`, throws on failure
- ✅ One emitter per aggregate — not one per transition
- ❌ No `Either` return type — emitters return `Unit`

### Abstract emitter (`AbstractOutboxEventEmitter.kt` — `infrastructure/outbound/`)
- ✅ Shared base class — all emit logic lives here, never duplicated per aggregate
- ✅ Declares three abstract properties: `outbox`, `objectMapper`, `topic`
- ✅ `emit()` stores a `KafkaOutboxMessage` with `stream = topic`, `key = event.key`, `eventPayload = objectMapper.writeValueAsBytes(event)`
- ✅ One abstract class per service — reused across all aggregates

### Emitter implementation (`Outbox{Aggregate}EventEmitter.kt` — `infrastructure/outbound/`)
- ✅ Named `Outbox{Aggregate}EventEmitter` — prefix `Outbox` indicates transactional outbox transport
- ✅ `@Component` annotation
- ✅ Extends `AbstractOutboxEventEmitter<{Aggregate}Event>()` and implements the domain port
- ✅ **No body** — all logic is in the abstract class
- ✅ Topic injected via `@param:Value("\${kafka.outbox.{aggregate}-events.topic}")` — never hardcoded
- ✅ Uses `ObjectMapper` (Jackson) for serialization — inherited from the abstract class
- ✅ `application.yml` must have a `kafka.outbox.{aggregate}-events.topic` entry
- ❌ No `const val TOPIC` / `companion object` — topic comes from properties
- ❌ No `protoMapper` — use `objectMapper` (Jackson)
- ❌ No `runCatching` — the outbox write either succeeds (same transaction) or throws
- ❌ No direct `kafkaTemplate.send()` — use the outbox

### Use case — event emission
- ✅ Save first: `val saved = repository.save(entity)`
- ✅ Emit using the saved state: `eventEmitter.emit({Aggregate}Event.Closed(snapshot = saved.toSnapshot()))`
- ✅ Both `save()` and `emit()` are in the same `@Transactional` use case — outbox guarantees atomicity
- ❌ Do NOT emit from pre-save state — snapshot must reflect the persisted state

## Example Implementation

### 1. Snapshot (primitives only)

```kotlin
// domain/events/ConversationSnapshot.kt
package {BASE_PACKAGE}.{module}.domain.events

import java.time.Instant
import java.util.UUID

data class ConversationSnapshot(
    val id: UUID,                   // ConversationId.value — UUID primitive
    val customerId: UUID,           // CustomerId.value — UUID primitive
    val status: String,             // ConversationStatus.name — String primitive
    val customerPlatform: String,   // CustomerPlatform.name — String primitive
    val language: String,           // N26Locale.Lang.name — String primitive
    val startedAt: Instant,
    val updatedAt: Instant?,
)
```

### 2. Sealed event envelope

```kotlin
// domain/events/ConversationEvent.kt
package {BASE_PACKAGE}.{module}.domain.events

import java.time.Instant
import java.util.UUID

sealed class ConversationEvent : Event {
    abstract override val snapshot: ConversationSnapshot

    data class Created(
        override val eventId: UUID = UUID.randomUUID(),
        override val occurredAt: Instant,
        override val snapshot: ConversationSnapshot,
    ) : ConversationEvent() {
        override val key: String = "${snapshot.id}_${snapshot.startedAt.epochSecond}"
    }

    data class Queued(
        override val eventId: UUID = UUID.randomUUID(),
        override val occurredAt: Instant,
        override val snapshot: ConversationSnapshot,
        val sessionId: UUID = UUID.randomUUID(),  // transition-specific metadata
    ) : ConversationEvent() {
        override val key: String = "${snapshot.id}_${occurredAt.epochSecond}"
    }

    data class Closed(
        override val eventId: UUID = UUID.randomUUID(),
        override val occurredAt: Instant,
        override val snapshot: ConversationSnapshot,
    ) : ConversationEvent() {
        override val key: String = "${snapshot.id}_${occurredAt.epochSecond}"
    }
}
```

### 3. Emitter port (domain layer)

```kotlin
// domain/ConversationEventEmitter.kt
package {BASE_PACKAGE}.{module}.domain

fun interface ConversationEventEmitter : EventEmitter<ConversationEvent> {
    override fun emit(event: ConversationEvent)  // returns Unit — infrastructure failures throw
}
```

### 4. Abstract outbox emitter (infrastructure/outbound — shared, one per service)

```kotlin
// infrastructure/outbound/AbstractOutboxEventEmitter.kt
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import com.fasterxml.jackson.databind.ObjectMapper
import de.tech26.outbox.messagerelay.springkafka.KafkaOutboxMessage
import de.tech26.outbox.messagestore.TransactionalOutbox
import {BASE_PACKAGE}.{module}.domain.EventEmitter
import {BASE_PACKAGE}.{module}.domain.events.Event

abstract class AbstractOutboxEventEmitter<T : Event> : EventEmitter<T> {
    protected abstract val outbox: TransactionalOutbox<KafkaOutboxMessage>
    protected abstract val objectMapper: ObjectMapper
    protected abstract val topic: String

    override fun emit(event: T) {
        outbox.storeForReliablePublishing(
            KafkaOutboxMessage(
                stream = topic,
                key = event.key,
                eventType = event::class.simpleName!!,
                eventPayload = objectMapper.writeValueAsBytes(event),
            ),
        )
    }
}
```

### 5. Concrete outbox emitter (infrastructure/outbound — one per aggregate)

```kotlin
// infrastructure/outbound/OutboxConversationEventEmitter.kt
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import com.fasterxml.jackson.databind.ObjectMapper
import de.tech26.outbox.messagerelay.springkafka.KafkaOutboxMessage
import de.tech26.outbox.messagestore.TransactionalOutbox
import {BASE_PACKAGE}.{module}.domain.ConversationEventEmitter
import {BASE_PACKAGE}.{module}.domain.events.ConversationEvent
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component

@Component
class OutboxConversationEventEmitter(
    override val outbox: TransactionalOutbox<KafkaOutboxMessage>,
    override val objectMapper: ObjectMapper,
    @param:Value("\${kafka.outbox.conversation-events.topic}")
    override val topic: String,
) : AbstractOutboxEventEmitter<ConversationEvent>(), ConversationEventEmitter
```

### 6. application.yml — topic configuration

```yaml
# application.yml
kafka:
  outbox:
    conversation-events:
      topic: "valium.conversation.events.v1"  # one topic per aggregate
```

### 7. `toSnapshot()` inside the aggregate

```kotlin
// Inside {Aggregate}.kt
fun toSnapshot(): {Aggregate}Snapshot = {Aggregate}Snapshot(
    id = id,                                // UUID — not ConversationId
    customerId = customerId,                // UUID — not CustomerId
    status = status.name,                   // String — not ConversationStatus
    customerPlatform = customerPlatform.name,
    language = language.name,
    startedAt = startedAt,
    updatedAt = updatedAt,
)
```

### 8. Use case — emit after save (same transaction)

```kotlin
// Both calls are inside @Transactional — outbox write + repository.save() are atomic
// occurredAt comes from an injected Clock — no Instant.now() defaults on variants
val saved = conversationRepository.save(closed)
eventEmitter.emit(ConversationEvent.Closed(occurredAt = Instant.now(clock), snapshot = saved.toSnapshot()))
return Either.Success(saved.toDTO())
```

## Anti-Patterns

```kotlin
// ❌ Domain types in snapshot — not serializable across boundaries
data class ConversationSnapshot(
    val conversationId: ConversationId,   // ← domain type
    val status: ConversationStatus,       // ← domain enum
)
// ✅ Primitives only: UUID, String, Instant

// ❌ Standalone data class per event — no compile-time exhaustiveness
data class ConversationCreated(val conversationId: UUID, val occurredAt: Instant)
data class ConversationClosed(val conversationId: UUID, val closedAt: Instant)
// ✅ Sealed hierarchy: ConversationEvent.Created, ConversationEvent.Closed

// ❌ Thin event — forces consumers to call back
data class ConversationClosed(val conversationId: UUID, val closedAt: Instant)
// ✅ Every event carries ConversationSnapshot — ECST

// ❌ One emitter per event variant — port proliferation
interface ConversationCreatedEmitter { fun emit(event: ConversationEvent.Created) }
interface ConversationClosedEmitter  { fun emit(event: ConversationEvent.Closed) }
// ✅ Single emitter: ConversationEventEmitter.emit(event: ConversationEvent)

// ❌ Emitter returns Either — infrastructure failures are not business outcomes
interface ConversationEventEmitter {
    fun emit(event: ConversationEvent): Either<EmissionError, Unit>
}
// ✅ Returns Unit, throws on failure

// ❌ Hardcoded topic constant — cannot change per environment without recompiling
companion object {
    const val TOPIC = "valium.conversation.events.v1"
}
// ✅ Inject from application.yml: @param:Value("\${kafka.outbox.conversation-events.topic}")

// ❌ Inline outbox logic in every emitter — duplicates boilerplate across aggregates
@Component
class OutboxConversationEventEmitter(...) : ConversationEventEmitter {
    override fun emit(event: ConversationEvent) {
        transactionalOutbox.storeForReliablePublishing(...)  // duplicated in every emitter
    }
}
// ✅ Extend AbstractOutboxEventEmitter — concrete emitter has no body

// ❌ Direct kafkaTemplate.send() — dual-write problem (if DB and Kafka fail independently)
class KafkaConversationEventEmitter(private val kafkaTemplate: KafkaTemplate<String, ByteArray>) {
    override fun emit(event: ConversationEvent) {
        kafkaTemplate.send(TOPIC, key, payload)  // outside DB transaction!
    }
}
// ✅ Use transactional outbox: transactionalOutbox.storeForReliablePublishing(...)

// ❌ Emit from pre-save state
val closed = conversation.close().getOrElse { ... }
eventEmitter.emit(ConversationEvent.Closed(snapshot = closed.toSnapshot()))  // not persisted yet!
val saved = conversationRepository.save(closed)
// ✅ Save first: val saved = repository.save(closed); emitter.emit(...)

// ❌ previousStatus field — redundant; event variant already describes the transition
data class Closed(val snapshot: ConversationSnapshot, val previousStatus: ConversationStatus)
// ✅ data class Closed(val snapshot: ConversationSnapshot)

// ❌ Event named as command (present/imperative tense)
sealed class ConversationEvent { data class Close(...) : ConversationEvent() }
// ✅ Past tense: Closed, Created, Queued

// ❌ No domain port — use case depends on concrete infra class
class CloseConversation(private val emitter: OutboxConversationEventEmitter)
// ✅ Depend on the port: ConversationEventEmitter (fun interface in domain/)

// ❌ Event and snapshot files in domain/ (emitter port goes in domain/, but event/snapshot go in domain/events/)
// domain/ConversationEvent.kt
// domain/ConversationSnapshot.kt
// ✅ domain/events/ConversationEvent.kt
// ✅ domain/events/ConversationSnapshot.kt
// ✅ domain/ConversationEventEmitter.kt
```

## Verification

1. Domain files compile with zero framework imports: `./gradlew service:compileKotlin`
2. Snapshot fields are all primitives (`UUID`, `String`, `Instant`, `Long`, `Boolean`, nullables) — no domain types
3. Event variants named in past tense
4. Emitter interface in `domain/`, not in `domain/events/`
5. Outbox emitter extends `AbstractOutboxEventEmitter` and has no body
6. Topic injected via `@param:Value` — no `const val TOPIC` or `companion object`
7. `application.yml` contains `kafka.outbox.{aggregate}-events.topic` entry
8. Use case emits after `repository.save()`, not before

## Package Location

- Snapshot: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/events/`
- Event sealed class: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/events/`
- Emitter port: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/`
- Outbox emitter: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/`
