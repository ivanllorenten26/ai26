---
rules: [CC-01, CC-02, D-01, D-02, D-04, D-09, A-01, CC-03]
---

← [Recipes Index](../how-to.md)

# Migration Patterns

- [Pattern 1 — Anemic service → Use case + rich aggregate](#pattern-1--anemic-service--use-case--rich-aggregate)
- [Pattern 2 — Exception-based errors → Either sealed class](#pattern-2--exception-based-errors--either-sealed-class)
- [Pattern 3 — JPA entity in domain → Port + JPA outbound adapter](#pattern-3--jpa-entity-in-domain--port--jpa-outbound-adapter)
- [Pattern 4 — Spring annotations in domain class → Pure domain object](#pattern-4--spring-annotations-in-domain-class--pure-domain-object)
- [Pattern 5 — God service → Multiple focused use cases](#pattern-5--god-service--multiple-focused-use-cases)

---

## Pattern 1 — Anemic service → Use case + rich aggregate

The most common legacy anti-pattern: a `@Entity` data class with no behaviour, and a
`@Service` class that contains all the business logic for that entity.

### Before

```kotlin
// Legacy: anemic entity
@Entity
@Table(name = "conversations")
data class ConversationEntity(
    @Id val id: UUID,
    var status: String,
    val createdAt: Instant
)

// Legacy: service holds all logic
@Service
class ConversationService(
    private val conversationRepository: ConversationJpaRepository
) {
    fun close(id: UUID) {
        val entity = conversationRepository.findById(id).orElseThrow {
            EntityNotFoundException("Conversation $id not found")
        }
        if (entity.status == "CLOSED") {
            throw IllegalStateException("Already closed")
        }
        entity.status = "CLOSED"
        conversationRepository.save(entity)
    }
}
```

### After

```kotlin
// domain/Conversation.kt  — rich aggregate root (rules D-01, D-02)
class Conversation private constructor(
    val id: ConversationId,
    val status: ConversationStatus,
    val createdAt: Instant
) {
    fun close(): Conversation {
        require(status != ConversationStatus.CLOSED) {
            "Conversation ${id.value} is already closed"
        }
        return copy(status = ConversationStatus.CLOSED)
    }

    private fun copy(status: ConversationStatus) =
        Conversation(id = id, status = status, createdAt = createdAt)

    companion object {
        fun create(): Conversation = Conversation(
            id = ConversationId.random(),          // rule D-09
            status = ConversationStatus.OPEN,
            createdAt = Instant.now()
        )
        fun from(id: ConversationId, status: ConversationStatus, createdAt: Instant) =
            Conversation(id, status, createdAt)
    }
}

// domain/ConversationId.kt  (rule D-08)
data class ConversationId(val value: UUID) {
    companion object {
        fun random() = ConversationId(UUID.randomUUID())
        fun from(value: UUID) = ConversationId(value)
    }
}

// application/CloseConversation.kt  — use case (rule A-01, CC-03)
@Service
@Transactional
class CloseConversation(
    private val conversationRepository: ConversationRepository
) {
    operator fun invoke(id: ConversationId): Either<CloseConversationError, Conversation> {
        val conversation = conversationRepository.findById(id)
            ?: return Either.Error(CloseConversationError.NotFound(id))
        return try {
            val closed = conversation.close()
            Either.Success(conversationRepository.save(closed))
        } catch (e: IllegalArgumentException) {
            Either.Error(CloseConversationError.AlreadyClosed(id))
        }
    }
}
```

### Why

- `ConversationEntity` mixed persistence concerns with (absent) domain behaviour — violates CC-01 (no framework imports in domain) and D-01 (aggregate roots are not `data class`)
- Business rule "cannot close a closed conversation" lived in the service — it belongs in the aggregate
- `@Service` becomes a use case; the aggregate enforces its own invariants

---

## Pattern 2 — Exception-based errors → Either sealed class

Legacy code uses thrown exceptions for business rule violations. AI26 uses `Either`
from `de.tech26.valium.shared.kernel` (rule CC-03, A-01).

### Before

```kotlin
// Legacy: throws for business errors
@Service
class PaymentService {
    fun process(id: UUID): Payment {
        val payment = repository.findById(id)
            ?: throw EntityNotFoundException("Payment $id not found")
        if (payment.status == "PROCESSED") {
            throw IllegalStateException("Payment already processed")
        }
        // ... process
        return payment
    }
}

// Legacy: controller catches exceptions
@RestController
class PaymentController(private val paymentService: PaymentService) {
    @PostMapping("/payments/{id}/process")
    fun process(@PathVariable id: UUID): ResponseEntity<PaymentResponse> {
        return try {
            ResponseEntity.ok(paymentService.process(id).toResponse())
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: IllegalStateException) {
            ResponseEntity.status(409).build()
        }
    }
}
```

### After

```kotlin
// domain/ProcessPaymentError.kt  — sealed error type
sealed class ProcessPaymentError {
    data class NotFound(val id: PaymentId) : ProcessPaymentError()
    data class AlreadyProcessed(val id: PaymentId) : ProcessPaymentError()
}

// application/ProcessPayment.kt  — returns Either (rule CC-03)
@Service
@Transactional
class ProcessPayment(private val paymentRepository: PaymentRepository) {
    operator fun invoke(id: PaymentId): Either<ProcessPaymentError, Payment> {
        val payment = paymentRepository.findById(id)
            ?: return Either.Error(ProcessPaymentError.NotFound(id))
        if (payment.status == PaymentStatus.PROCESSED) {
            return Either.Error(ProcessPaymentError.AlreadyProcessed(id))
        }
        return Either.Success(paymentRepository.save(payment.process()))
    }
}

// infrastructure/inbound/PaymentController.kt  — humble object (rule CC-02)
@RestController
class PaymentController(private val processPayment: ProcessPayment) {
    @PostMapping("/api/v1/payments/{id}/process")
    fun process(@PathVariable id: UUID): ResponseEntity<PaymentResponse> =
        when (val result = processPayment(PaymentId.from(id))) {
            is Either.Success -> ResponseEntity.ok(result.value.toResponse())
            is Either.Error -> when (result.error) {
                is ProcessPaymentError.NotFound -> ResponseEntity.notFound().build()
                is Either.Error -> ResponseEntity.status(409).build()
            }
        }
}
```

### Why

- `Either` makes error paths explicit in the type signature — the caller cannot ignore them
- The controller becomes a humble translation layer; no business logic inside `when` branches
- `EntityNotFoundException` and `IllegalStateException` are infrastructure concerns that should not cross layer boundaries

---

## Pattern 3 — JPA entity in domain → Port + JPA outbound adapter

Legacy code lets JPA entities (with `@Entity`, `@Column`, `@OneToMany`) leak into the
domain layer. The domain must be free of framework imports (rule CC-01, CC-02).

### Before

```kotlin
// Legacy: JPA entity used directly in service
@Entity
@Table(name = "conversations")
data class Conversation(
    @Id @GeneratedValue val id: UUID? = null,
    @Column(name = "status") var status: String = "OPEN",
    @OneToMany(mappedBy = "conversation") val messages: List<Message> = emptyList()
)

@Service
class ConversationService(
    private val conversationRepository: ConversationJpaRepository  // Spring Data repo
) {
    fun findOpen() = conversationRepository.findByStatus("OPEN")
}
```

### After

```kotlin
// domain/ConversationRepository.kt  — port (interface in domain, no framework imports)
interface ConversationRepository {
    fun findById(id: ConversationId): Conversation?
    fun findAllOpen(): List<Conversation>
    fun save(conversation: Conversation): Conversation
}

// infrastructure/outbound/ConversationJpaRepository.kt  — Spring Data (rule CC-02)
interface ConversationJpaRepository : JpaRepository<ConversationJpaEntity, UUID>

// infrastructure/outbound/ConversationJpaEntity.kt  — JPA entity stays in infra
@Entity
@Table(name = "conversations")
class ConversationJpaEntity(
    @Id val id: UUID,
    @Column(name = "status") val status: String,
    @Column(name = "created_at") val createdAt: Instant
)

// infrastructure/outbound/ConversationRepositoryImpl.kt  — adapter
@Repository
class ConversationRepositoryImpl(
    private val jpaRepository: ConversationJpaRepository
) : ConversationRepository {
    override fun findById(id: ConversationId) =
        jpaRepository.findById(id.value).orElse(null)?.toDomain()

    override fun findAllOpen() =
        jpaRepository.findByStatus("OPEN").map { it.toDomain() }

    override fun save(conversation: Conversation) =
        jpaRepository.save(conversation.toEntity()).toDomain()

    private fun ConversationJpaEntity.toDomain() = Conversation.from(
        id = ConversationId.from(id),
        status = ConversationStatus.valueOf(status),
        createdAt = createdAt
    )

    private fun Conversation.toEntity() = ConversationJpaEntity(
        id = id.value,
        status = status.name,
        createdAt = createdAt
    )
}
```

### Why

- The domain aggregate (`Conversation`) has zero framework imports — satisfies CC-01
- JPA details (`@Entity`, `@Column`, Spring Data) are isolated in `infrastructure/outbound/` — satisfies CC-02
- The domain port defines the contract; the adapter fulfills it without the domain knowing how

---

## Pattern 4 — Spring annotations in domain class → Pure domain object

A service class in the legacy code contains `@Service`, `@Autowired`, or `@Value`
annotations. Moving to a use case means removing all framework coupling (rule CC-01).

### Before

```kotlin
// Legacy: Spring annotations inside what should be a domain service
@Service
class ConversationDomainService {
    @Value("\${conversation.max-messages}")
    private val maxMessages: Int = 100

    @Autowired
    lateinit var auditLogger: AuditLogger

    fun canAddMessage(conversation: Conversation): Boolean {
        auditLogger.log("Checking message limit for ${conversation.id}")
        return conversation.messages.size < maxMessages
    }
}
```

### After

```kotlin
// domain/ConversationPolicy.kt  — pure domain object, no framework imports (CC-01)
class ConversationPolicy(private val maxMessages: Int) {
    fun canAddMessage(conversation: Conversation): Boolean =
        conversation.messageCount < maxMessages
}

// application/AddMessage.kt  — use case wires policy with config
@Service
class AddMessage(
    private val conversationRepository: ConversationRepository,
    @Value("\${conversation.max-messages}") maxMessages: Int
) {
    private val policy = ConversationPolicy(maxMessages)

    operator fun invoke(
        conversationId: ConversationId,
        content: String
    ): Either<AddMessageError, Message> {
        val conversation = conversationRepository.findById(conversationId)
            ?: return Either.Error(AddMessageError.ConversationNotFound(conversationId))
        if (!policy.canAddMessage(conversation)) {
            return Either.Error(AddMessageError.MessageLimitReached(conversationId))
        }
        // ...
    }
}
```

### Why

- `@Value` and `@Autowired` are Spring framework annotations — they must not appear in domain classes (CC-01)
- The policy object is now a plain Kotlin class, fully testable without a Spring context
- Configuration is injected at the use case level (application layer), not the domain level

---

## Pattern 5 — God service → Multiple focused use cases

A service class over 300 lines or with more than 8–10 injected dependencies is a
"god service" — it handles too many responsibilities. Each responsibility becomes a
focused use case.

### Before

```kotlin
// Legacy: god service handling everything about Conversation
@Service
class ConversationService(
    private val conversationRepo: ConversationJpaRepository,
    private val messageRepo: MessageJpaRepository,
    private val agentRepo: AgentJpaRepository,
    private val notificationService: NotificationService,
    private val analyticsService: AnalyticsService,
    private val auditService: AuditService,
    private val kafkaTemplate: KafkaTemplate<String, Any>,
    private val featureFlagService: FeatureFlagService
) {
    fun createConversation(...) { ... }
    fun closeConversation(...) { ... }
    fun addMessage(...) { ... }
    fun escalateToAgent(...) { ... }
    fun assignAgent(...) { ... }
    fun fetchAnalytics(...) { ... }
}
```

### After

```
application/
  CreateConversation.kt      ← one use case, 2–3 dependencies
  CloseConversation.kt       ← one use case, 1–2 dependencies
  AddMessage.kt              ← one use case, 2–3 dependencies
  EscalateConversation.kt    ← one use case, 2–3 dependencies
  AssignAgent.kt             ← one use case, 2–3 dependencies
```

Each use case:

```kotlin
// application/CloseConversation.kt
@Service
@Transactional
class CloseConversation(
    private val conversationRepository: ConversationRepository,   // port
    private val eventPublisher: ConversationEventPublisher        // port
) {
    operator fun invoke(id: ConversationId): Either<CloseConversationError, Conversation> {
        val conversation = conversationRepository.findById(id)
            ?: return Either.Error(CloseConversationError.NotFound(id))
        val closed = conversation.close()
            .getOrElse { return Either.Error(CloseConversationError.AlreadyClosed(id)) }
        val saved = conversationRepository.save(closed)
        eventPublisher.publish(ConversationEvent.Closed(saved.toSnapshot()))
        return Either.Success(saved)
    }
}
```

### Why

- Each use case has a single responsibility and 2–3 dependencies — fully unit-testable in isolation
- The god service's 8 dependencies are distributed across use cases that each need 2–3
- Port interfaces (`ConversationRepository`, `ConversationEventPublisher`) keep use cases free of infrastructure details
- The decomposition mirrors how `ai26-decompose-migration` generates tickets: one ticket per use case

---

## Reference

- [migration.md](../../ai26-sdlc/reference/migration.md) — end-to-end migration workflow
- [domain.md](domain.md) — aggregate root and value object patterns
- [use-cases.md](use-cases.md) — use case structure and Either pattern
- [error-handling.md](error-handling.md) — Either and sealed error types
- [infrastructure.md](infrastructure.md) — ports and adapters structure
