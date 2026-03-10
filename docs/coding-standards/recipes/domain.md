---
rules: [CC-01, CC-05, D-01, D-02, D-03, D-04, D-05, D-07, D-08, D-09, D-10, D-11, D-12, D-13]
---

← [Recipes Index](../how-to.md)

# Domain Building Blocks

- [Aggregate Roots](#aggregate-roots)
- [Value Objects](#value-objects)
- [Domain Services](#domain-services)

---

## Aggregate Roots

### When

Create a new aggregate root when you are modelling a domain concept that has:
- **Identity** — it has a unique ID that persists over time
- **Lifecycle** — it transitions through states (PENDING → ACTIVE → CANCELLED)
- **Consistency boundary** — all changes to it and its children must happen together

Create a **child entity** (not a new aggregate) when the concept only makes sense inside an existing aggregate and has no lifecycle independent of the root.

### Template

**Aggregate root (7-file bundle):**

The private constructor forces all callers through `create()` or `from()`, so invariants in the `init` block run on every construction path. `create()` is for new instances (generates an ID, sets initial status); `from()` is for rehydration from the database. The private `copy()` method keeps state transitions immutable — `confirm()` returns a new `Order` rather than mutating `this`. The aggregate does not collect events internally — the use case builds the event after save using `toSnapshot()`. See [Domain Events — ECST Pattern](../domain-events.md).

```kotlin
// domain/Order.kt
class Order private constructor(
    val id: OrderId,
    val customerId: String,
    val amount: Long,
    val status: OrderStatus,
    val createdAt: Instant
) {

    init {
        require(customerId.isNotBlank()) { "customerId cannot be blank" }
        require(amount > 0) { "amount must be positive" }
    }

    fun confirm(): Either<ConfirmError, Order> {
        if (status != OrderStatus.PENDING) return Either.Error(ConfirmError.NotPending(id.value))
        return Either.Success(copy(status = OrderStatus.CONFIRMED))
    }

    sealed class ConfirmError {
        data class NotPending(val orderId: UUID) : ConfirmError()
    }

    fun cancel(): Either<CancelError, Order> {
        if (!status.canBeCancelled()) return Either.Error(CancelError.NotCancellable(id.value))
        return Either.Success(copy(status = OrderStatus.CANCELLED))
    }

    sealed class CancelError {
        data class NotCancellable(val orderId: UUID) : CancelError()
    }

    fun toDTO(): OrderDTO = OrderDTO(id.toString(), customerId, amount, status.name, createdAt.toString())

    // Primitives-only snapshot for domain events — see Domain Events recipe for details
    fun toSnapshot(): OrderSnapshot = ...

    private fun copy(status: OrderStatus = this.status): Order =
        Order(id, customerId, amount, status, createdAt)

    companion object {
        fun create(customerId: String, amount: Long): Order =
            Order(OrderId.random(), customerId, amount, OrderStatus.PENDING, Instant.now())

        fun from(id: OrderId, customerId: String, amount: Long, status: OrderStatus, createdAt: Instant): Order =
            Order(id, customerId, amount, status, createdAt)
    }
}
```

```kotlin
// domain/OrderId.kt
data class OrderId(val value: UUID) {
    override fun toString(): String = value.toString()

    companion object {
        fun random(): OrderId = OrderId(UUID.randomUUID())
        fun fromString(raw: String): OrderId = OrderId(UUID.fromString(raw))
    }
}
```

```kotlin
// domain/OrderStatus.kt
enum class OrderStatus {
    PENDING, CONFIRMED, CANCELLED;

    fun canBeCancelled(): Boolean = this == PENDING || this == CONFIRMED
}
```

```kotlin
// domain/OrderRepository.kt
interface OrderRepository {
    fun save(order: Order): Order
    fun findById(id: OrderId): Order?
    fun findByCustomerId(customerId: String): List<Order>
}
```

```kotlin
// domain/OrderDTO.kt
data class OrderDTO(val id: String, val customerId: String, val amount: Long, val status: String, val createdAt: String)
```

**Event files (`domain/events/OrderSnapshot.kt`, `domain/events/OrderEvent.kt`):** snapshot + sealed hierarchy with ECST. Full template and rules in [Domain Events Recipe](./domain-events.md).

### Rules

- One aggregate per transaction — never save two aggregates in the same `@Transactional` method
- Cross-aggregate references by ID only — `Order` holds `customerId: String`, never `customer: Customer`
- One `Repository` per aggregate root — no `OrderItemRepository`

### Anti-patterns

```kotlin
// ❌ data class exposes public copy() — callers bypass invariants
data class Order(val id: OrderId, var status: OrderStatus)

// ❌ Large aggregate — Customer owns Orders, Payments, Addresses
data class Customer(val orders: List<Order>, val payments: List<Payment>)

// ❌ ID as raw UUID — loses type safety at boundaries
fun findById(id: UUID): Order?   // which entity is this UUID for?
```

### See also

- [Architecture Principles — Aggregate Pattern](../architecture-principles.md#aggregate-pattern)

---

## Status Enums

### When

Every aggregate with a lifecycle has a status enum. The enum does two things:
1. **Names the states** — `PENDING`, `CONFIRMED`, `CANCELLED`
2. **Encodes allowed transitions** — `canBeCancelled()` returns `true` for states from which cancellation is valid

Transition guards live on the enum, not on the aggregate. This keeps the aggregate's business methods readable and makes the transition matrix testable in isolation.

### Template

```kotlin
// domain/OrderStatus.kt
enum class OrderStatus {
    PENDING, CONFIRMED, SHIPPED, CANCELLED;

    fun canBeConfirmed(): Boolean = this == PENDING
    fun canBeCancelled(): Boolean = this == PENDING || this == CONFIRMED
    fun canBeShipped(): Boolean = this == CONFIRMED
}
```

The aggregate calls the guard inside its business method and returns `Either.Error` if the transition is not allowed:

```kotlin
// domain/Order.kt
fun confirm(): Either<ConfirmError, Order> {
    if (!status.canBeConfirmed()) return Either.Error(ConfirmError.InvalidStatus(status))
    return Either.Success(copy(status = OrderStatus.CONFIRMED))
}

fun cancel(): Either<CancelError, Order> {
    if (!status.canBeCancelled()) return Either.Error(CancelError.InvalidStatus(status))
    return Either.Success(copy(status = OrderStatus.CANCELLED))
}

fun ship(): Either<ShipError, Order> {
    if (!status.canBeShipped()) return Either.Error(ShipError.InvalidStatus(status))
    return Either.Success(copy(status = OrderStatus.SHIPPED))
}
```

The lifecycle matrix makes the allowed transitions explicit:

| From \ To   | CONFIRMED | SHIPPED | CANCELLED |
|-------------|-----------|---------|-----------|
| PENDING     | ✓         |         | ✓         |
| CONFIRMED   |           | ✓       | ✓         |
| SHIPPED     |           |         |           |
| CANCELLED   |           |         |           |

### Rules

- Transition guards (`canBe…()`) live on the enum — the aggregate calls them, never reimplements the logic inline
- Guard method names mirror the aggregate method: `cancel()` calls `canBeCancelled()`
- Terminal states (SHIPPED, CANCELLED) have no guards — no method returns `true` from them

### Anti-patterns

```kotlin
// ❌ Transition logic inline in the aggregate — duplicated if multiple methods need it
fun cancel(): Either<CancelError, Order> {
    if (status != OrderStatus.PENDING && status != OrderStatus.CONFIRMED)
        return Either.Error(CancelError.InvalidStatus(status))
    ...
}
// ✅ status.canBeCancelled() — one place to change when transitions evolve

// ❌ Boolean flag instead of status enum — cannot add states without changing callers
class Order(val isCancelled: Boolean, val isConfirmed: Boolean)

// ❌ Guard that returns true for terminal states — terminal means no exit
fun canBeCancelled(): Boolean = this != CANCELLED  // SHIPPED can be "cancelled"?
```

### See also

- [Error Handling](./error-handling.md) — why business methods return `Either` instead of throwing

---

## Value Objects

### When

Wrap a primitive when it carries **domain meaning beyond its raw type**: an email address is not just a `String`, a money amount is not just a `Long`. Value objects make the domain model self-documenting and enforce business rules at the type level.

**Constructor rule:** use private constructor + factory returning `Either` when the valid value space is **narrower** than the input type (e.g. `String` → `Email` — many strings are not valid emails). Use a public constructor when the input type already constrains all possible values (e.g. `UUID` → `ConversationId` — every UUID is a valid ID).

Three sub-patterns:

| Sub-pattern | Constructor | Use when |
|---|---|---|
| ID value object (`data class`) | **Public** — input type (UUID) already guarantees validity | Wrapping UUID identity for an entity |
| Simple wrapper (`data class` private constructor) | **Private** — input type is wider than valid values | Single primitive with validation (email, IBAN, percentage 0–100) |
| Rich value object (`data class` private constructor) | **Private** — multiple fields or complex invariants | Multiple fields or operations (e.g. `Money.add()`) |

### Template

Use the **ID value object** sub-pattern for entity identity — it makes UUID parameters type-safe so `findById(conversationId)` cannot accidentally accept an `orderId`. Use a **simple wrapper** when a single primitive needs business validation rules (e.g. email format). Use a **rich value object** when you need multiple fields or operations that produce a new value (e.g. `Money.add()`).

**ID value object (public constructor — every UUID is a valid ID):**
```kotlin
// domain/ConversationId.kt
data class ConversationId(val value: UUID) {
    override fun toString(): String = value.toString()

    companion object {
        fun random(): ConversationId = ConversationId(UUID.randomUUID())
        fun fromString(raw: String): ConversationId = ConversationId(UUID.fromString(raw))
    }
}
```

**Simple wrapper (private constructor — not every String is a valid email):**
```kotlin
// domain/Email.kt
data class Email private constructor(val value: String) {
    companion object {
        fun of(raw: String): Either<ValidationError, Email> {
            val trimmed = raw.trim().lowercase()
            return when {
                trimmed.isBlank() -> Either.Error(ValidationError("Email cannot be blank"))
                !trimmed.contains("@") -> Either.Error(ValidationError("Invalid email format"))
                else -> Either.Success(Email(trimmed))
            }
        }
    }
    override fun toString(): String = value
}
```

**Rich value object:**
```kotlin
// domain/Money.kt
data class Money private constructor(val amount: Long, val currency: String) {
    init {
        require(amount >= 0) { "Money amount cannot be negative" }
        require(currency.length == 3) { "Currency must be ISO 4217 (3 chars): $currency" }
    }
    companion object {
        fun of(amount: Long, currency: String): Money = Money(amount, currency.uppercase())
    }
    fun add(other: Money): Money {
        require(currency == other.currency) { "Cannot add different currencies: $currency vs ${other.currency}" }
        return Money(amount + other.amount, currency)
    }
    override fun toString(): String = "$amount $currency"
}
```

### Anti-patterns

```kotlin
// ❌ Public constructor when valid values are narrower than the input type
data class Email(val value: String)  // Email("not-an-email") compiles fine
// ✅ Private constructor + factory returning Either — forces validation

// ✅ Public constructor is fine when the input type already constrains all values
data class ConversationId(val id: UUID)  // Every UUID is a valid ConversationId

// ❌ Mutable state — value objects must be immutable
data class Money(var amount: Long, var currency: String)

// ❌ Side effects in value object
data class Email(val value: String) {
    fun sendWelcome() { /* I/O in a value object */ }
}
```

### See also

- [Architecture Principles — Value Object](../architecture-principles.md#domain-layer-core)

---

## Domain Services

### When

Use a domain service for **business logic that spans multiple aggregates** and does not naturally belong to any one of them.

Decision table:

| Logic belongs to... | Put it in... |
|---|---|
| Single entity's state or behavior | Entity method |
| Cross-entity / cross-aggregate business rule | **Domain Service** |
| Application orchestration (load, save, publish) | Use Case |
| External system integration | Infrastructure adapter (outbound) |

### Template

**Interface (domain layer — no framework annotations):**
```kotlin
// domain/DiscountPolicy.kt
interface DiscountPolicy {
    fun calculate(order: Order, customer: Customer): Money
}
```

**Pure domain implementation (when no external I/O needed):**
```kotlin
// domain/DiscountPolicyImpl.kt
class DiscountPolicyImpl : DiscountPolicy {
    override fun calculate(order: Order, customer: Customer): Money {
        val volumeDiscount = order.calculateVolumeDiscount()
        val loyaltyDiscount = customer.loyaltyDiscount()
        return Money.best(volumeDiscount, loyaltyDiscount)
    }
}
```

**Infrastructure implementation (when external data is needed):**
```kotlin
// infrastructure/outbound/ExchangeRateServiceImpl.kt
@Service
class ExchangeRateServiceImpl(
    private val ratesClient: ExternalRatesClient
) : ExchangeRateService {

    override fun convert(amount: Money, targetCurrency: String): Money {
        val rate = ratesClient.fetchRate(amount.currency, targetCurrency)
        return amount.convertAt(rate)
    }
}
```

### Anti-patterns

```kotlin
// ❌ Stateful domain service — must be stateless
class PricingService {
    private var lastCalculation: Money = Money.ZERO  // mutable state
}

// ❌ Tell Don't Ask violation — logic belongs in Order
class OrderValidationService {
    fun isValid(order: Order): Boolean =
        order.items.isNotEmpty() && order.total() > Money.ZERO  // Order knows this
}

// ❌ Orchestration in domain service — this is a use case
class OrderProcessingService(
    private val orderRepo: OrderRepository,   // repositories = orchestration
    private val gateway: PaymentGateway
) {
    fun process(orderId: OrderId) { /* load, call, save, publish */ }
}

// ❌ Framework annotation on domain interface
@Service  // infrastructure concern in domain
interface PricingService
```
