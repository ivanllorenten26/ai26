---
name: test-create-use-case-tests
description: Creates BDD-style unit tests for Use Cases with MockK and Mother Objects. Use when you need to verify business logic in a use case by mocking only its repository/gateway boundaries.
argument-hint: [UseCaseName] covering [business scenarios]
---

# Create Use Case Tests

Creates BDD-style unit tests for Use Cases using MockK + AssertJ assertions. Use Cases are the **primary SUT** — mock only repositories (boundaries), use real domain entities.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.
Also resolve `shared_imports.either` (fallback: `de.tech26.valium.shared.kernel.Either`).

## Task

Create unit tests for `{USE_CASE_NAME}` in:
- `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/application/{UseCaseName}Test.kt`
- `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{EntityName}Mother.kt` (if not existing — see `test-create-mother-object`)

## Implementation Rules

- ✅ Mock **only** repositories and external gateways (architectural boundaries)
- ✅ Use **real** domain entities — never mock entities
- ✅ Test names: `should {action} when {condition}` (business-readable)
- ✅ Each `@Test` method starts with a Gherkin docstring comment block (`// Scenario: ...`)
- ✅ Arrange-Act-Assert structure with clear sections (after the docstring block)
- ✅ Mother Objects for consistent test data
- ✅ Verify `Either.Success` for success, `Either.Error` for expected failures
- ✅ Verify repository interactions with `verify { }`
- ✅ Call use case with **primitive** parameters (`UUID`, `String`) — the use case signature accepts primitives only. Use real `UUID.randomUUID()` or Mother-seeded IDs as arguments.
- ✅ Assert on error fields: `assertThat((error as SomeError.NotFound).id).isEqualTo(expectedId)`
- ❌ No mocking domain entities or value objects
- ❌ No testing framework behavior (Spring, JPA)
- ❌ No Cucumber annotations (`@Given`, `@When`, `@Then`) — Gherkin lives as `// Scenario:` docstring comments, not as executed step definitions
- ❌ No `Gateway` suffix — use `Repository`

## Example Implementation

### Test Class
```kotlin
package {BASE_PACKAGE}.{module}.application

import {BASE_PACKAGE}.{module}.domain.{EntityName}
import {BASE_PACKAGE}.{module}.domain.{EntityName}Id
import {BASE_PACKAGE}.{module}.domain.{EntityName}Repository
import {BASE_PACKAGE}.{module}.domain.errors.{UseCaseName}DomainError
import {BASE_PACKAGE}.{module}.domain.{EntityName}Mother
import {sharedImports.either}
import io.mockk.*
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class {UseCaseName}Test {

    private val {entity}Repository = mockk<{EntityName}Repository>()
    private val eventEmitter = mockk<{EntityName}CreatedEventEmitter>(relaxed = true)

    private val useCase = {UseCaseName}(
        {entity}Repository,
        eventEmitter
    )

    @Test
    fun `should create {entity} when valid data provided`() {
        // Scenario: Successfully create {entity}
        //   Given valid input data is provided
        //   When I create the {entity}
        //   Then the {entity} should be created successfully
        //   And the {entity} should be saved to the repository

        // Arrange — repository returns plain type (no Either)
        every { {entity}Repository.save(any()) } answers { firstArg() }

        // Act — primitives only (UUID, String); use case wraps them to domain types internally
        val result = useCase(UUID.randomUUID(), "valid-subject")

        // Assert
        assertThat(result).isInstanceOf(Either.Success::class.java)
        verify { {entity}Repository.save(any()) }
    }

    @Test
    fun `should return NotFound when {entity} does not exist`() {
        // Scenario: Return error when {entity} does not exist
        //   Given no {entity} exists with the given ID
        //   When I perform the operation
        //   Then I should receive a {EntityName}NotFound error
        //   And no {entity} should be saved

        // Arrange
        val missingId = UUID.randomUUID()
        every { {entity}Repository.findById({EntityName}Id(missingId)) } returns null

        // Act — pass UUID primitive, not domain ID
        val result = useCase(missingId, "valid-subject")

        // Assert
        assertThat(result).isInstanceOf(Either.Error::class.java)
        val error = (result as Either.Error).value
        assertThat(error).isInstanceOf({UseCaseName}DomainError.{EntityName}NotFound::class.java)
        verify(exactly = 0) { {entity}Repository.save(any()) }
    }

    @Test
    fun `should return error when domain validation fails`() {
        // Scenario: Reject invalid input
        //   Given an invalid subject (blank)
        //   When I create the {entity}
        //   Then I should receive an InvalidInput error
        //   And no {entity} should be saved

        // Arrange — blank subject triggers init validation in entity via runCatching

        // Act — pass blank string primitive
        val result = useCase(UUID.randomUUID(), "")

        // Assert
        assertThat(result).isInstanceOf(Either.Error::class.java)
        val error = (result as Either.Error).value
        assertThat(error).isInstanceOf({UseCaseName}DomainError.InvalidInput::class.java)
        verify(exactly = 0) { {entity}Repository.save(any()) }
    }

    @Test
    fun `should return error when {entity} is in invalid status for the operation`() {
        // Scenario: Reject operation when {entity} is in invalid status
        //   Given an {entity} in an incompatible status exists
        //   When I perform the operation
        //   Then I should receive an InvalidStatus error
        //   And no {entity} should be saved

        // Arrange — entity exists but its current status prevents the operation
        val {entity} = {EntityName}Mother.inactive()  // status that fails the business rule
        every { {entity}Repository.findById({entity}.id) } returns {entity}

        // Act — pass the UUID from the Mother-seeded entity
        val result = useCase({entity}.id.value, "valid-subject")

        // Assert
        assertThat(result).isInstanceOf(Either.Error::class.java)
        val error = (result as Either.Error).value
        assertThat(error).isInstanceOf({UseCaseName}DomainError.InvalidStatus::class.java)
        verify(exactly = 0) { {entity}Repository.save(any()) }
    }
}
// Note: persistence failures (DB down, etc.) are NOT tested as use-case unit tests.
// They propagate as unchecked exceptions to @ControllerAdvice → 500.
// Test them at the integration test layer (TestContainers) if needed.
```

### Mother Objects

Mother Objects live in `testFixtures/` — use `test-create-mother-object` to generate them. Key conventions for use case tests:
- Defaults are **random** (`UUID.randomUUID()`, `Instant.now()`, `{EnumType}.random()`) — communicates "this field doesn't matter for this test"
- Always delegate to the domain factory (`create()` / `from()`) — never build domain objects directly
- Named methods compose on `create()` to express domain states

```kotlin
// Lives in testFixtures — generated by test-create-mother-object
package {BASE_PACKAGE}.{module}.domain

import java.time.Instant
import java.util.UUID

object {EntityName}Mother {

    fun create(
        id: UUID = UUID.randomUUID(),               // random default
        customerId: UUID = UUID.randomUUID(),
        subject: String = "test-subject",           // obviously-fake, not a magic value
        status: {EntityName}Status = {EntityName}Status.random(),  // domain-owned random
        startedAt: Instant = Instant.now(),
    ): {EntityName} = {EntityName}.create(          // delegate to domain factory
        id = id,
        customerId = customerId,
        subject = subject,
        startedAt = startedAt,
    )

    // Named states for tests that need a specific lifecycle position
    fun inactive() = create().deactivate()          // compose on create()
    fun closed()   = create().close()
}
```

## Testing Guidelines

### What to Test
- ✅ Happy path — valid input → success result
- ✅ Domain validation failures — invalid input → `InvalidInput` or `InvalidStatus` error
- ✅ Entity not found — missing data → not found error
- ✅ Repository interaction verification — correct data saved
- ❌ Persistence failures — infrastructure exceptions are NOT domain errors; they propagate unchecked to `@ControllerAdvice`. Test at the integration test layer instead.

### Error Test Checklist

For every `Either.Error` branch:
1. Assert the **type**: `assertThat(error).isInstanceOf(SomeError.Variant::class.java)`
2. Assert the **fields**: `assertThat((error as SomeError.Variant).id).isEqualTo(expectedId)`
3. Verify **no side effects**: `verify(exactly = 0) { repository.save(any()) }`

### What NOT to Test
- ❌ Spring transaction management
- ❌ HTTP status codes (test in controller tests)
- ❌ Database query logic (test in integration tests)
- ❌ Framework wiring

## Anti-Patterns

```kotlin
// ❌ Mocking domain entities
val order = mockk<Order>() // Never mock entities!
every { order.confirm() } returns mockk()

// ❌ Testing framework behavior
verify { transactionManager.commit() } // Not your concern

// ❌ Cucumber annotations — Gherkin lives as docstring comments, not executed step definitions
@Given("an open conversation exists")
fun givenOpen() { ... }
@When("I close it")
fun whenClose() { ... }

// ❌ Custom BDD DSL
fun test(block: TestContext.() -> Unit) { ... } // Unnecessary indirection; use plain JUnit5 + MockK

// ❌ Gateway naming
private val orderGateway = mockk<OrderGateway>() // Use Repository

// ❌ String for what should be a UUID — passes the wrong primitive type
val result = useCase("some-string-id", "PENDING")  // "some-string-id" is not a valid UUID
// ✅ Use UUID primitive for identity, String for string parameters
val result = useCase(UUID.randomUUID(), "PENDING")

// ❌ Domain types in use case call — the use case signature accepts primitives only
val result = useCase(OrderId(UUID.randomUUID()), OrderStatus.PENDING)  // domain types are NOT parameters
// ✅ Primitives only — the use case wraps them internally
val result = useCase(UUID.randomUUID(), "PENDING")

// ❌ Vague error assertion — does not verify what went wrong
assertThat(result).isInstanceOf(Either.Error::class.java)  // which error? which fields?
// ✅
val error = (result as Either.Error).value
assertThat(error).isInstanceOf(CancelOrderDomainError.OrderNotFound::class.java)
assertThat((error as CancelOrderDomainError.OrderNotFound).id).isEqualTo(expectedId)
```

## Verification

1. Tests pass: `./gradlew service:test --tests "*{UseCaseName}Test"`
2. Only repositories/gateways are mocked — no entity mocks
3. All `Either.Error` branches have specific error type assertions with field checks
4. Mother objects provide consistent, reusable test data
5. Use case called with primitive parameters (`UUID`, `String`) — not domain types (`{EntityName}Id`, domain enums)

## Package Location

- Tests: `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/application/`
- Mothers: `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/` (testFixtures source set)
