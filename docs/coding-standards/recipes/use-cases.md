---
rules: [CC-05, D-14, A-01, A-02, A-03, A-04, A-05, A-06]
---

← [Recipes Index](../how-to.md)

# Use Cases & Transactions

- [Use Cases](#use-cases)
- [Transactions](#transactions)

---

## Use Cases

### When

Every user-facing business operation is a use case. Use cases are the **primary system under test** — they orchestrate the domain and define transaction boundaries.

One use case = one business operation = one class with `operator fun invoke`.

### Template

**Pattern 1** covers any operation that loads an existing entity, mutates it, and saves it back. The entity's business method returns `Either` — the use case maps entity errors to use-case errors with `mapError` and unwraps with `getOrElse`. **Pattern 2** covers creation flows where the entity is built from scratch and an event is emitted. Use Pattern 2 whenever a state change needs to notify other parts of the system. In Pattern 2, `runCatching` bridges the entity's `require`/`check` throws (object invariants) to `Either` — this is valid because `create()` throws, not returns `Either`. In both patterns `save()` is called directly with no `Either` wrapping — persistence exceptions propagate unchecked to `@ControllerAdvice` and become 500s.

**Pattern 1 — Load entity, execute action, persist:**
```kotlin
// application/CloseConversation.kt
@Service
@Transactional
class CloseConversation(
    private val conversationRepository: ConversationRepository
) {

    operator fun invoke(conversationId: UUID): Either<CloseConversationDomainError, ConversationDTO> {
        val id = ConversationId(conversationId)

        val conversation = conversationRepository.findById(id)
            ?: return Either.Error(CloseConversationDomainError.ConversationNotFound(id))

        val closed = conversation.close()
            .mapError { CloseConversationDomainError.InvalidStatus(conversation.status) }
            .getOrElse { return Either.Error(it) }

        // Persistence exceptions propagate unchecked — caught by @ControllerAdvice → 500
        return Either.Success(conversationRepository.save(closed).toDTO())
    }
}
```

**Pattern 2 — Create, persist, emit event:**
```kotlin
// application/CreateConversation.kt
@Service
@Transactional
class CreateConversation(
    private val conversationRepository: ConversationRepository,
    private val eventEmitter: ConversationEventEmitter
) {

    operator fun invoke(
        customerId: String,
        subject: String
    ): Either<CreateConversationDomainError, ConversationDTO> {
        // Bridge entity invariant throw to Either.Error for expected validation outcomes
        val conversation = runCatching { Conversation.create(customerId, subject) }
            .getOrElse { return Either.Error(CreateConversationDomainError.InvalidInput(it.message ?: "")) }

        // Persistence exceptions propagate unchecked — caught by @ControllerAdvice → 500
        val saved = conversationRepository.save(conversation)
        eventEmitter.emit(ConversationEvent.Created(snapshot = saved.toSnapshot()))
        return Either.Success(saved.toDTO())
    }
}
```

**Sealed domain error (co-located in domain/errors/) — business outcomes only:**
```kotlin
// domain/errors/CreateConversationDomainError.kt
sealed class CreateConversationDomainError {
    data class InvalidInput(val reason: String) : CreateConversationDomainError()
    // No PersistenceFailure or EventEmissionFailure — infra failures are not business outcomes
}
```

### Rules

- Parameters are **primitives only** (`String`, `Int`, `UUID`, `List<String>`, …) — never domain types, DTOs, or command objects. `UUID` is accepted as a primitive. Inside the use case, immediately wrap primitives into domain types and validate.
- Return `Either<DomainError, DTO>` — never return raw domain entities
- `@Transactional` goes here — not on repositories or controllers
- Business logic belongs in the entity — use cases only orchestrate

### Anti-patterns

```kotlin
// ❌ Returns custom sealed Result instead of Either
sealed class CreateOrderResult { class Success(val id: String); class Failure(val msg: String) }

// ❌ Infrastructure types in signature leak layer boundaries
fun invoke(request: CreateConversationRequest): ResponseEntity<ConversationResponse>

// ❌ Business logic that belongs in the entity
class CreateConversation {
    operator fun invoke(...) {
        if (subject.length > 200) return Either.Error(...)  // put this in Conversation.create()
    }
}

// ❌ Domain types or command objects in parameters — use primitives instead
operator fun invoke(command: CreateConversationCommand): Either<...>
operator fun invoke(id: ConversationId): Either<...>  // should be invoke(id: UUID)
```

### See also

- [Architecture Principles — Application Layer](../architecture-principles.md#application-layer-use-cases)
- [Transactions](#transactions)

---

## Transactions

### When and where

`@Transactional` belongs on the **use case**, never on repositories or controllers.

| Layer | `@Transactional`? |
|---|---|
| Domain | Never |
| Application (use case) | Yes — this is the transaction boundary |
| Infrastructure (repository) | Never — repository is inside the use case transaction |
| Infrastructure (controller) | Never |

`@Transactional` belongs on the use case because the use case defines the unit of work — it decides which aggregates to load, mutate, and save. Repositories sit inside that transaction automatically; adding `@Transactional` to a repository would create a nested transaction with confusing propagation semantics. Controllers are stateless HTTP handlers and must never own a transaction boundary.

### One aggregate per transaction

```kotlin
// ✅ Correct — one aggregate, one transaction
@Service
@Transactional
class ConfirmOrder(private val orderRepository: OrderRepository) {
    operator fun invoke(orderId: UUID): Either<ConfirmOrderDomainError, OrderDTO> {
        val id = OrderId(orderId)
        val order = orderRepository.findById(id)
            ?: return Either.Error(ConfirmOrderDomainError.OrderNotFound(id))

        val confirmed = order.confirm()
            .mapError { ConfirmOrderDomainError.InvalidStatus(order.status) }
            .getOrElse { return Either.Error(it) }

        // Persistence exceptions propagate unchecked — caught by @ControllerAdvice → 500
        return Either.Success(orderRepository.save(confirmed).toDTO())
    }
}
```

### Cross-aggregate consistency via events (eventual consistency)

When an operation affects two aggregates (e.g. confirming an order also adds loyalty points to the customer), do not save both in the same transaction — that violates the one-aggregate-per-transaction rule. Instead, save the first aggregate and emit an event. A separate listener picks up the event and runs a second use case in its own transaction. The two aggregates are eventually consistent, which is the correct model for independent bounded contexts.

```kotlin
// ✅ Correct — only Order is modified; Customer is updated in a separate transaction via event
@Service
@Transactional
class ConfirmOrder(
    private val orderRepository: OrderRepository,
    private val orderConfirmedEmitter: OrderConfirmedEmitter
) {
    operator fun invoke(orderId: UUID): Either<ConfirmOrderDomainError, OrderDTO> {
        val id = OrderId(orderId)
        val order = orderRepository.findById(id)
            ?: return Either.Error(ConfirmOrderDomainError.OrderNotFound(id))

        val confirmed = order.confirm()
            .mapError { ConfirmOrderDomainError.InvalidStatus(order.status) }
            .getOrElse { return Either.Error(it) }

        // Persistence exceptions propagate unchecked — caught by @ControllerAdvice → 500
        val saved = orderRepository.save(confirmed)
        orderConfirmedEmitter.emit(OrderConfirmed(saved.id, saved.customerId))
        return Either.Success(saved.toDTO())
    }
}

// In a separate Kafka consumer + use case (separate transaction, separate service or same):
@Component
class OrderConfirmedKafkaConsumer(private val addLoyaltyPoints: AddLoyaltyPointsUseCase) {
    @KafkaListener(
        topics = ["\${kafka.order-events.consumer.topic}"],
        groupId = "\${kafka.order-events.consumer.group-id}",
        containerFactory = "orderEventContainerFactory",
    )
    fun consume(message: Message<ByteArray>) {
        val event = // deserialize from message.payload
        addLoyaltyPoints(event.customerId, event.orderId)
    }
}
```

### Anti-patterns

```kotlin
// ❌ @Transactional on repository — already inside the use case transaction
@Repository
@Transactional  // remove this
class JooqOrderRepository(...) : OrderRepository

// ❌ Two aggregates in one transaction — consistency boundary violation
@Transactional
fun confirmOrder(orderId: OrderId, customerId: CustomerId) {
    val confirmed = order.confirm().getOrElse { ... }
    customer.addLoyaltyPoints()     // second aggregate — use events instead
    orderRepository.save(confirmed)
    customerRepository.save(customer)
}
```

### See also

- [Architecture Principles — Cross-Aggregate Transactions](../architecture-principles.md#cross-aggregate-transactions)
- [Domain Events](./domain-events.md) — full event template and ECST pattern for the listener side
