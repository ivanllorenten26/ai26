---
rules: [D-07]
---

← [Recipes Index](../how-to.md)

# Domain Events

### When

Create a domain event when an aggregate state change must be communicated to other bounded contexts, external systems, or the data platform. Events are the mechanism for **eventual consistency** — they replace direct cross-aggregate calls and cross-aggregate transactions.

When an operation affects two aggregates (e.g. confirming an order also adds loyalty points to a customer), save the first aggregate and emit an event — never save both in the same transaction. A separate listener runs a second use case in its own transaction. See [Use Cases — Cross-aggregate consistency via events](./use-cases.md#cross-aggregate-consistency-via-events) for the full pattern.

Ask: *"If this state change happened and no one was notified, would something break elsewhere?"* If yes, emit an event.

Every domain event is published to the **Lakehouse via Kafka** — this is a data mandate. The event must carry enough state for consumers to work without calling back to the source. This is why we use **Event-Carried State Transfer (ECST)**: every event includes a full snapshot of the aggregate at the moment of the transition.

For the full design rationale, see [Domain Events — ECST Pattern](../domain-events.md).

### Template

**Sealed hierarchy (one per aggregate, lives in `domain/events/`):**

Each aggregate has one sealed class that enumerates every event it can produce. Variants are named in the **past tense** — they are facts, not commands. `eventId` is unique per emission; `occurredAt` is captured at creation, before any async delay. Every variant carries a `snapshot` — the aggregate's full state as primitives.

```kotlin
// domain/events/ConversationEvent.kt
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

**Snapshot (primitives only, lives in `domain/events/`):**

The snapshot is a `data class` of primitives — no domain types, no framework types. It is what crosses service boundaries and feeds the Lakehouse. The aggregate builds it via `toSnapshot()`.

```kotlin
// domain/events/ConversationSnapshot.kt
data class ConversationSnapshot(
    val id: UUID,
    val customerId: UUID,
    val status: String,
    val customerPlatform: String,
    val language: String,
    val startedAt: Instant,
    val updatedAt: Instant?,
)
```

```kotlin
// Inside the aggregate — Conversation.kt
fun toSnapshot(): ConversationSnapshot = ConversationSnapshot(
    id = id,
    customerId = customerId,
    status = status.name,
    customerPlatform = customerPlatform.name,
    language = language.name,
    startedAt = startedAt,
    updatedAt = updatedAt,
)
```

**Single emitter per aggregate (domain port + outbox implementation):**

One emitter interface handles all event variants for an aggregate. The interface lives in `domain/` with zero framework imports. The implementation writes to a **transactional outbox table** within the same DB transaction — a separate polling publisher sends to Kafka asynchronously. This eliminates the dual-write problem.

```kotlin
// domain/EventEmitter.kt — generic port
fun interface EventEmitter<T : Event> {
    fun emit(event: T)
}

// domain/ConversationEventEmitter.kt — aggregate-specific port
fun interface ConversationEventEmitter : EventEmitter<ConversationEvent> {
    override fun emit(event: ConversationEvent)
}

// infrastructure/outbound/AbstractOutboxEventEmitter.kt — shared outbox logic
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

// infrastructure/outbound/OutboxConversationEventEmitter.kt — one-liner, no body
@Component
class OutboxConversationEventEmitter(
    override val outbox: TransactionalOutbox<KafkaOutboxMessage>,
    override val objectMapper: ObjectMapper,
    @param:Value("\${kafka.outbox.conversation-events.topic}")
    override val topic: String,
) : AbstractOutboxEventEmitter<ConversationEvent>(), ConversationEventEmitter
```

Topic name comes from `application.yml` — never hardcoded:

```yaml
# application.yml
kafka:
  outbox:
    conversation-events:
      topic: "valium.conversation.events.v1"
```

**Outbox configuration (infrastructure/configuration):**

```kotlin
// shared/config/OutboxConfig.kt
@Configuration
class OutboxConfig {
    
    @Bean
    fun transactionalOutbox(dataSource: DataSource, meterRegistry: MeterRegistry) =
        TransactionalOutbox.withDefaults<KafkaOutboxMessage>(
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

**Kafka consumer (infrastructure/inbound):**

Consumers use `@KafkaListener` — not Spring `@EventListener`. The consumer sits in `infrastructure/inbound/` (same layer as controllers). A custom `ConcurrentKafkaListenerContainerFactory` with `KafkaProtoDeserializerBuilder` handles proto deserialization automatically.

```kotlin
// infrastructure/configuration/KafkaConsumerConfiguration.kt
@Configuration
class KafkaConsumerConfiguration {

    @Bean
    fun conversationEventContainerFactory(
        kafkaProperties: KafkaProperties,
        errorHandler: CommonErrorHandler,
    ): ConcurrentKafkaListenerContainerFactory<String, ConversationEventProto?> {
        val consumerFactory = DefaultKafkaConsumerFactory(
            kafkaProperties.buildConsumerProperties(),
            StringDeserializer(),
            KafkaProtoDeserializerBuilder(ConversationEventProto.parser()).build(),
        )
        val factory = ConcurrentKafkaListenerContainerFactory<String, ConversationEventProto?>()
        factory.consumerFactory = consumerFactory
        factory.setCommonErrorHandler(errorHandler)
        return factory
    }

    @Bean
    fun kafkaErrorHandler(): CommonErrorHandler {
        val backoff = ExponentialBackOff(1000L, 1.5).apply { maxElapsedTime = 30_000L }
        return DefaultErrorHandler(backoff)
    }
}

// infrastructure/inbound/ConversationEventKafkaConsumer.kt
@Component
class ConversationEventKafkaConsumer(
    private val handleClosed: HandleConversationClosedUseCase,
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
            event.hasConversationClosed() -> handleClosed(/* map proto to primitives */)
            event.hasConversationCreated() -> { /* no-op or delegate */ }
            else -> log.warn("Unknown event variant for key=$key")
        }
    }
}
```

**Chaining event emission in the use case:**

Save first, then emit — both happen in the same `@Transactional` scope. With the outbox, both `repository.save()` and `emitter.emit()` are DB writes in the same transaction — either both succeed or both fail.

```kotlin
val saved = conversationRepository.save(closed)

// Outbox write — participates in the same DB transaction as save
// occurredAt is passed explicitly using an injected Clock — no Instant.now() defaults
eventEmitter.emit(ConversationEvent.Closed(occurredAt = Instant.now(clock), snapshot = saved.toSnapshot()))

return Either.Success(saved.toDTO())
```

### Anti-patterns

```kotlin
// ❌ Standalone data class per event — no compile-time exhaustiveness
data class ConversationCreated(val conversationId: UUID, val occurredAt: Instant)
data class ConversationClosed(val conversationId: UUID, val closedAt: Instant)
// ✅ Sealed hierarchy: ConversationEvent.Created, ConversationEvent.Closed

// ❌ Minimal event without snapshot — forces consumers to call back
data class ConversationClosed(val conversationId: UUID, val closedAt: Instant)
// ✅ Every event carries ConversationSnapshot — ECST

// ❌ Domain types in snapshot — not serializable across boundaries
data class ConversationSnapshot(val conversationId: ConversationId, val status: ConversationStatus)
// ✅ Primitives only: UUID, String, Instant

// ❌ One emitter per event type — port proliferation
interface ConversationCreatedEmitter { fun emit(event: ConversationEvent.Created) }
interface ConversationClosedEmitter { fun emit(event: ConversationEvent.Closed) }
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

// ❌ Direct kafkaTemplate.send() — dual-write problem
class KafkaConversationEventEmitter(private val kafkaTemplate: KafkaTemplate<String, ByteArray>) {
    override fun emit(event: ConversationEvent) {
        kafkaTemplate.send(TOPIC, key, payload)  // outside DB transaction!
    }
}
// ✅ Use transactional outbox: transactionalOutbox.storeForReliablePublishing(...)

// ❌ Consuming Kafka events with Spring @EventListener
@EventListener
fun onConversationEvent(event: ConversationEvent) { ... }
// ✅ @KafkaListener for Kafka topics; @EventListener is for in-process Spring events only

// ❌ Emitter accepts entity instead of event — emitter should not build the event
interface ConversationEventEmitter { fun emit(conversation: Conversation) }
// ✅ Emitter accepts ConversationEvent — the use case builds the event

// ❌ Event built from pre-save state
val closed = conversation.close().getOrElse { ... }
eventEmitter.emit(ConversationEvent.Closed(snapshot = closed.toSnapshot()))  // not persisted yet!
val saved = conversationRepository.save(closed)
// ✅ Save first: val saved = repository.save(closed); emitter.emit(...)

// ❌ No domain port — use case imports concrete infrastructure class
class CloseConversation(private val emitter: OutboxConversationEventEmitter)
// ✅ Depend on the port: ConversationEventEmitter (interface in domain/events/)

// ❌ Event named as command (present tense)
sealed class ConversationEvent {
    data class Close(...) : ConversationEvent()  // imperative = command, not event
}
// ✅ Past tense: Closed, Created, Queued
```

### See also

- [Domain Events — ECST Pattern](../domain-events.md) — full design rationale, snapshot rules, Kafka contract, outbox configuration
- [Proto Appendix](../domain-events-proto-appendix.md) — Protobuf conventions and `n26/argon` reference
- [Architecture Principles — Domain Events](../architecture-principles.md#domain-events-between-aggregates)
- [Transactions](./use-cases.md#transactions) for eventual consistency rules
