---
rules: [I-04]
---

← [Recipes Index](../how-to.md)

# Outbound Adapters

An outbound adapter is any infrastructure class that calls outside the service boundary on behalf of the domain: a database repository, an HTTP client, an event publisher, or a message queue producer. Every outbound adapter implements a **domain port** (an interface in the `domain/` package) and lives in `infrastructure/outbound/`. The domain and application layers never import the adapter — they only know the port interface.

---

### When

| Adapter type | When to create |
|---|---|
| JOOQ / JPA repository | The domain needs to persist or query an aggregate root |
| HTTP API client | A use case needs data from an external service |
| Event publisher (Kafka / SQS) | A use case needs to emit a domain event after a state change |
| Message queue producer (SQS) | A use case needs to enqueue work for asynchronous processing |

All four are outbound adapters — they all follow the same structural rules: domain port in `domain/`, implementation in `infrastructure/outbound/`, private mapping functions co-located in the adapter file.

### Package structure

```
service/src/main/kotlin/de/tech26/valium/{module}/
├── domain/
│   ├── Order.kt                          ← aggregate root
│   ├── OrderRepository.kt                ← domain port (interface, zero framework imports)
│   └── ports/
│       └── PaymentGateway.kt             ← domain port for external HTTP service
├── application/
│   └── ConfirmOrder.kt                   ← use case — imports only domain.*
└── infrastructure/
    ├── inbound/
    │   └── OrderController.kt
    └── outbound/                         ← ALL outbound adapters here (I-03)
        ├── JooqOrderRepository.kt        ← implements OrderRepository
        └── StripePaymentGateway.kt       ← implements PaymentGateway
```

Nothing lives flat in `infrastructure/` — every class is under `inbound/` or `outbound/` (CC-02 / I-03).

### Template

**Domain port (zero framework imports — CC-01):**
```kotlin
// domain/OrderRepository.kt
interface OrderRepository {
    fun save(order: Order): Order
    fun findById(id: OrderId): Order?
    fun findByCustomerId(customerId: String): List<Order>
}
```

```kotlin
// domain/ports/PaymentGateway.kt
interface PaymentGateway {
    fun charge(orderId: OrderId, amountCents: Long, currency: String): Either<ChargeError, ChargeReference>

    sealed class ChargeError {
        data class InsufficientFunds(val orderId: OrderId) : ChargeError()
        object ProviderUnavailable : ChargeError()
    }
}
```

> The domain port uses only domain types (`OrderId`, `Either`, `ChargeReference`). No `import org.springframework.*`, no `import retrofit2.*`, no JOOQ types.

**JOOQ repository adapter (infrastructure/outbound — mapping functions private to the file):**
```kotlin
// infrastructure/outbound/JooqOrderRepository.kt
@Repository
class JooqOrderRepository(
    private val dsl: DSLContext,
) : OrderRepository {

    override fun save(order: Order): Order {
        dsl.insertInto(ORDER_V1)
            .set(ORDER_V1.ID, order.id.value)
            .set(ORDER_V1.CUSTOMER_ID, order.customerId)
            .set(ORDER_V1.AMOUNT_CENTS, order.amountCents)
            .set(ORDER_V1.CURRENCY, order.currency)
            .set(ORDER_V1.STATUS, order.status.toJooq())
            .set(ORDER_V1.CREATED_AT, order.createdAt)
            .onConflict(ORDER_V1.ID).doUpdate()
            .set(ORDER_V1.STATUS, order.status.toJooq())
            .execute()
        return order
    }

    override fun findById(id: OrderId): Order? =
        dsl.selectFrom(ORDER_V1)
            .where(ORDER_V1.ID.eq(id.value))
            .fetchOne()
            ?.toDomain()

    override fun findByCustomerId(customerId: String): List<Order> =
        dsl.selectFrom(ORDER_V1)
            .where(ORDER_V1.CUSTOMER_ID.eq(customerId))
            .fetch()
            .map { it.toDomain() }

    // ── Private mapping — translation stays in the adapter (I-04) ──────────────

    private fun OrderV1Record.toDomain(): Order = Order.from(
        id         = OrderId(id),
        customerId = customerId,
        amountCents = amountCents,
        currency   = currency,
        status     = status.toDomain(),
        createdAt  = createdAt,
    )

    private fun OrderStatus.toJooq(): OrderV1Status = OrderV1Status.valueOf(name)
    private fun OrderV1Status.toDomain(): OrderStatus = OrderStatus.valueOf(name)
}
```

**HTTP adapter (infrastructure/outbound — maps provider response to domain type):**
```kotlin
// infrastructure/outbound/StripePaymentGateway.kt
@Component
class StripePaymentGateway(
    private val stripeClient: StripeClient,     // Retrofit interface
) : PaymentGateway {

    override fun charge(
        orderId: OrderId,
        amountCents: Long,
        currency: String,
    ): Either<PaymentGateway.ChargeError, ChargeReference> =
        try {
            val response = stripeClient.createCharge(orderId.value.toString(), amountCents, currency)
            Either.Success(response.toDomain())
        } catch (ex: StripeInsufficientFundsException) {
            Either.Error(PaymentGateway.ChargeError.InsufficientFunds(orderId))
        } catch (ex: StripeUnavailableException) {
            Either.Error(PaymentGateway.ChargeError.ProviderUnavailable)
        }

    // ── Private mapping — StripeChargeResponse never leaks outside this file (I-04) ──

    private fun StripeChargeResponse.toDomain(): ChargeReference =
        ChargeReference(id = chargeId, processedAt = Instant.parse(createdAt))
}
```

### A-05 — Application layer imports only domain types

The use case imports the domain port interface and domain types. It never imports Spring, JOOQ, Retrofit, or any infrastructure class directly. Spring wires the correct adapter implementation at runtime via the constructor.

```kotlin
// application/ConfirmOrder.kt
package de.tech26.valium.order.application

// ✅ Only domain imports
import de.tech26.valium.order.domain.Order
import de.tech26.valium.order.domain.OrderId
import de.tech26.valium.order.domain.OrderRepository
import de.tech26.valium.order.domain.ports.PaymentGateway
import de.tech26.valium.shared.kernel.Either

// ❌ Never import infrastructure types in the application layer
// import de.tech26.valium.order.infrastructure.outbound.JooqOrderRepository   ← concrete class
// import org.springframework.data.jpa.repository.JpaRepository                ← Spring framework
// import org.jooq.DSLContext                                                   ← JOOQ
// import retrofit2.Response                                                    ← Retrofit

@Service
@Transactional
class ConfirmOrder(
    private val orderRepository: OrderRepository,      // domain port, not the adapter
    private val paymentGateway: PaymentGateway,        // domain port, not the adapter
) {
    operator fun invoke(orderId: UUID): Either<ConfirmOrderDomainError, OrderDTO> {
        val id = OrderId(orderId)

        val order = orderRepository.findById(id)
            ?: return Either.Error(ConfirmOrderDomainError.OrderNotFound(id))

        val confirmed = order.confirm()
            .mapError { ConfirmOrderDomainError.InvalidStatus(order.status) }
            .getOrElse { return Either.Error(it) }

        val chargeRef = paymentGateway.charge(id, confirmed.amountCents, confirmed.currency)
            .mapError { ConfirmOrderDomainError.PaymentFailed(it) }
            .getOrElse { return Either.Error(it) }

        val saved = orderRepository.save(confirmed.withCharge(chargeRef))
        return Either.Success(saved.toDTO())
    }
}
```

### Rules

- All outbound adapters live in `infrastructure/outbound/` — nothing flat in `infrastructure/` (I-03).
- Domain port interfaces live in `domain/` or `domain/ports/` — zero framework imports (CC-01).
- Mapping functions (`toDomain()`, `toRecord()`, `toJooq()`) are **private** to the adapter file — infrastructure types (`JooqRecord`, `StripeChargeResponse`, `HttpResponse`) never leak into the domain or application layer (I-04).
- The application layer imports only `domain.*` types — never concrete adapters, Spring classes, or persistence/client libraries (A-05).
- Adapter constructors declare port interfaces, not concrete implementations — Spring wires them via DI.
- Repository ports return nullable types (`Order?`) for not-found — never `Optional`, never `Either` (see [Repositories](./repositories.md)).

### Anti-patterns

```kotlin
// ❌ Outbound adapter flat in infrastructure/ (not in outbound/)
package de.tech26.valium.order.infrastructure   // wrong
// ✅
package de.tech26.valium.order.infrastructure.outbound

// ❌ JOOQ record leaking into a domain type or use case
class Order(val record: OrderV1Record)          // infrastructure type in domain
fun findById(id: OrderId): OrderV1Record?       // port returns infrastructure type
// ✅ Port returns Order? — the adapter converts before returning

// ❌ Public mapping function exported from the adapter
// OrderV1Record.kt (top-level)
fun OrderV1Record.toDomain(): Order = ...       // now anyone can call it
// ✅ Private extension function inside JooqOrderRepository — not callable outside the file

// ❌ Spring import in the application layer
// application/ConfirmOrder.kt
import org.springframework.data.jpa.repository.JpaRepository   // wrong — infra in application
import de.tech26.valium.order.infrastructure.outbound.JooqOrderRepository  // wrong — concrete adapter

// ❌ Either on the repository port for infrastructure failures
interface OrderRepository {
    fun save(order: Order): Either<PersistenceError, Order>   // infra concern in the port
}
// ✅ Let persistence exceptions propagate unchecked — the domain must not model infra failures

// ❌ Adapter annotated with domain-layer semantics
// domain/OrderRepository.kt
@Repository   // Spring annotation — domain must not know about Spring
interface OrderRepository
// ✅ @Repository goes on the implementation in infrastructure/outbound/
```

### See also

- [Repositories](./repositories.md) for the complete JOOQ adapter template and nullable return convention
- [Error Handling](./error-handling.md) for why repositories never return `Either` and how infrastructure failures reach `@ControllerAdvice`
- [Consuming External APIs](./external-apis.md) for `@Retry` configuration — named instances, back-off, and which exceptions to retry
