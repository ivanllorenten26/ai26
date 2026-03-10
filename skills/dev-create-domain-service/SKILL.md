---
name: dev-create-domain-service
description: Creates stateless domain services for business logic spanning multiple aggregates. Use when logic does not naturally belong to a single entity or value object.
argument-hint: [ServiceName] that [cross-aggregate operation description]
---

# Create Domain Service

Creates stateless domain services that encapsulate business logic spanning multiple aggregates or requiring coordination between domain concepts. Use when an operation does not naturally belong to a single entity or value object.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create a domain service `{SERVICE_NAME}` in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{ServiceName}.kt` (interface)
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{ServiceNameImpl}.kt` (implementation, only if pure domain logic)

If the implementation requires infrastructure (external APIs, DB lookups beyond repository), place the implementation in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{ServiceNameImpl}.kt`

## Implementation Rules

- ✅ Define an interface in the domain layer
- ✅ Stateless — no mutable instance state
- ✅ Pure functions when possible (deterministic, side-effect-free)
- ✅ Named with domain language, not technical language
- ✅ Operates on domain types (entities, value objects), not primitives or DTOs
- ✅ Constructor injection for domain dependencies (other domain services, repository interfaces)
- ❌ Framework annotations on the domain interface
- ❌ Infrastructure concerns (HTTP, DB, messaging) in the domain interface
- ❌ Business logic that belongs to a single entity — put it in the entity instead (Tell Don't Ask, per §7.11)
- ❌ Application orchestration logic — that belongs in Use Cases

## When to Use Domain Service vs Entity vs Use Case

| Logic belongs to... | Put it in... |
|---------------------|-------------|
| Single entity's state | Entity method |
| Cross-entity business rule | **Domain Service** |
| Application orchestration | Use Case |
| External system integration | Infrastructure adapter |

## Example Implementation

### Interface (domain layer)

```kotlin
package {BASE_PACKAGE}.{module}.domain

interface {ServiceName} {
    fun {operationName}({param1}: {DomainType1}, {param2}: {DomainType2}): {ReturnType}
}
```

### Pure Domain Implementation

```kotlin
package {BASE_PACKAGE}.{module}.domain

class {ServiceName}Impl : {ServiceName} {

    override fun {operationName}(
        {param1}: {DomainType1},
        {param2}: {DomainType2}
    ): {ReturnType} {
        // Cross-aggregate business logic
        val result = {param1}.{domainMethod}()
        val validated = {param2}.{validateAgainst}(result)
        return {ReturnType}.from(validated)
    }
}
```

### Concrete Example: eligibility check with error propagation

```kotlin
// Illustrative example — replace names with your domain types
package {BASE_PACKAGE}.{module}.domain

import de.tech26.valium.shared.kernel.Either

interface EligibilityService {
    fun checkEligibility(account: Account, product: Product): Either<EligibilityError, EligibilityResult>
}

sealed class EligibilityError {
    data class AccountSuspended(val accountId: AccountId) : EligibilityError()
    data class ProductUnavailable(val productId: ProductId) : EligibilityError()
}

class EligibilityServiceImpl(
    private val riskPolicy: RiskPolicy
) : EligibilityService {

    override fun checkEligibility(
        account: Account,
        product: Product
    ): Either<EligibilityError, EligibilityResult> {
        // Propagate aggregate errors using mapError to adapt sealed types
        val riskScore = riskPolicy.evaluate(account, product)
            .mapError { EligibilityError.AccountSuspended(account.id) }
            .getOrElse { return Either.Error(it) }

        return if (product.isAvailableFor(riskScore)) {
            Either.Success(EligibilityResult.Eligible(riskScore))
        } else {
            Either.Error(EligibilityError.ProductUnavailable(product.id))
        }
    }
}
```

### Infrastructure Implementation (when external resources needed)

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import {BASE_PACKAGE}.{module}.domain.{ServiceName}
import org.springframework.stereotype.Service

@Service
class {ServiceName}Impl(
    private val externalClient: ExternalClient
) : {ServiceName} {

    override fun {operationName}(
        {param1}: {DomainType1},
        {param2}: {DomainType2}
    ): {ReturnType} {
        val externalData = externalClient.fetch({param1}.id)
        return {param1}.{combine}(externalData, {param2})
    }
}
```

## Error Handling

When a domain service calls aggregate business methods that return `Either`, propagate errors explicitly:

```kotlin
// ✅ Propagating errors from aggregate methods
fun applyEligibility(account: Account, product: Product): Either<EligibilityError, Result> {
    val validated = account.validate()
        .mapError { EligibilityError.AccountSuspended(account.id) }
        .getOrElse { return Either.Error(it) }

    return product.applyTo(validated)
        .mapError { EligibilityError.ProductUnavailable(product.id) }
}
```

Rules:
- ✅ One sealed error class per domain service operation
- ✅ Use `mapError` to adapt aggregate-level errors to service-level errors
- ✅ Use `getOrElse { return Either.Error(it) }` as the early-exit pattern
- ❌ Do not swallow aggregate errors — callers need to know why the operation failed
- ❌ Do not catch exceptions from aggregate methods — let them propagate as unchecked errors to `@ControllerAdvice`

## Anti-Patterns

```kotlin
// ❌ Stateful domain service — services must be stateless
class PricingService {
    private var lastCalculation: Money = Money.ZERO  // Mutable state!
    fun calculate(order: Order): Money { /* ... */ }
}

// ❌ Logic that belongs to the entity (Tell Don't Ask violation)
class OrderValidationService {
    fun validate(order: Order): Boolean {
        return order.items.isNotEmpty() &&      // This is Order's responsibility
               order.total() > Money.ZERO       // Ask pattern — put in Order
    }
}

// ❌ Application orchestration disguised as domain service
class OrderProcessingService(
    private val orderRepo: OrderRepository,    // Orchestration = Use Case
    private val paymentGateway: PaymentGateway,
    private val notificationService: NotificationService
) {
    fun processOrder(orderId: OrderId) { /* ... */ }
}

// ❌ Framework annotations on domain interface
@Service  // Infrastructure concern in domain!
interface PricingService { /* ... */ }

// ❌ Swallowing aggregate errors — business context is lost
fun process(account: Account): Either<ProcessError, Result> {
    val result = account.activate().getOrElse { return Either.Error(ProcessError.Unknown) }
    // ✅ Use mapError to preserve context: account.activate().mapError { ProcessError.ActivationFailed(it) }
    return Either.Success(Result.from(result))
}
```

## Verification

1. Interface compiles without framework imports: `./gradlew service:compileKotlin`
2. Interface lives in `domain/` package — no infrastructure imports
3. Implementation is stateless — no `var` properties, no mutable collections
4. Operations use domain types, not primitives or DTOs
5. No orchestration logic (loading from repo, saving, publishing events)
6. Aggregate `Either` errors are propagated with `mapError`/`getOrElse` — not swallowed

## Package Location

- Interface: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/`
- Pure implementation: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/`
- Infrastructure implementation: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/`
