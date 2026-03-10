---
name: dev-create-aggregate
description: Creates a complete DDD aggregate root with its ID value object, status enum, repository interface, and DTO. Use when modelling a new domain concept that has identity, lifecycle, and persistence.
argument-hint: [AggregateName] in [module] with [prop1:Type, prop2:Type] [optional: states ACTIVE|INACTIVE|...]
---

# Create Aggregate

Creates all files that form a single cohesive domain unit: aggregate root, ID value object, status enum (when lifecycle states exist), repository interface, and DTO. This is the primary entry point for domain modelling — a developer never creates one of these without the others.

This skill is a **mid-level orchestrator**: it references `dev-create-value-object` and `dev-create-domain-entity` patterns instead of duplicating them, and produces a complete, self-consistent aggregate boundary in one invocation.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`, `main_source_root=service/src/main/kotlin`.

## Task

Create a new aggregate `{AggregateName}` in module `{MODULE}` with properties `{PROPERTIES}`:

1. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{AggregateName}.kt` — aggregate root
2. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{AggregateName}Id.kt` — ID value object
3. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{AggregateName}Status.kt` — lifecycle enum (include when entity has states)
4. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{AggregateName}Repository.kt` — repository interface
5. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{AggregateName}DTO.kt` — DTO for use case return values

## Implementation Rules

Apply `coding_rules` from `ai26/config.yaml`: **CC-01, CC-03, CC-04, CC-05, D-01 through D-14**.

### Aggregate Root
Follow D-01, D-02, D-03, D-04, D-05, D-06, D-07, CC-01. See template below.

### ID Value Object
Follow D-08, D-09, D-10. See template below.

### Status Enum
Include only when the aggregate has distinct lifecycle states (D-12).

### Repository Interface
Collection-like API in `domain/`. Follow CC-04 and D-14.

### DTO
Lives in `domain/` alongside the aggregate. Follow CC-05.

## Error Handling in Business Methods

Business methods that can fail a business rule return `Either<SealedError, {AggregateName}>`. Use `require` only for programming invariants that should never be violated in a valid flow (blank name, negative amount).

| Situation | Pattern | Example |
|---|---|---|
| Constructor invariant (programming error) | `require(...)` in `init` block | `require(name.isNotBlank())` |
| Business rule violation (expected outcome) | Return `Either.Error(SealedError)` | `if (status != PENDING) return Either.Error(...)` |
| Successful mutation | Return `Either.Success(newInstance)` | `return Either.Success(copy(...))` |

Sealed error classes are nested inside the aggregate to keep them co-located with the business rules they describe.

## Example Implementation

### Aggregate Root

```kotlin
package {BASE_PACKAGE}.{module}.domain

import de.tech26.valium.shared.kernel.Either
import java.time.Instant

class {AggregateName} private constructor(
    val id: {AggregateName}Id,
    val name: String,
    val amount: Long,
    val status: {AggregateName}Status,
    val createdAt: Instant,
    val closedAt: Instant? = null,
) {

    init {
        require(name.isNotBlank()) { "name cannot be blank" }
        require(amount > 0) { "amount must be positive" }
    }

    // Business rule: can only activate from PENDING status
    fun activate(): Either<ActivateError, {AggregateName}> {
        if (status != {AggregateName}Status.PENDING) {
            return Either.Error(ActivateError.InvalidStatus(status))
        }
        return Either.Success(copy(status = {AggregateName}Status.ACTIVE))
    }

    // Business rule: can only cancel from cancellable statuses
    fun cancel(): Either<CancelError, {AggregateName}> {
        if (!status.canBeCancelled()) {
            return Either.Error(CancelError.InvalidStatus(status))
        }
        return Either.Success(copy(status = {AggregateName}Status.CANCELLED))
    }

    fun toDTO(): {AggregateName}DTO = {AggregateName}DTO(
        id = id.toString(),
        name = name,
        amount = amount,
        status = status.name,
        createdAt = createdAt.toString(),
        closedAt = closedAt?.toString()
    )

    // Primitives-only snapshot for domain events
    // See Domain Events recipe: domain/events/{AggregateName}Snapshot.kt
    fun toSnapshot(): {AggregateName}Snapshot = {AggregateName}Snapshot(
        id = id.value,
        name = name,
        amount = amount,
        status = status.name,  // enum → String — snapshot has no domain types
        createdAt = createdAt,
        closedAt = closedAt,
    )

    private fun copy(
        name: String = this.name,
        amount: Long = this.amount,
        status: {AggregateName}Status = this.status,
        closedAt: Instant? = this.closedAt,
    ): {AggregateName} = {AggregateName}(
        id = this.id,
        name = name,
        amount = amount,
        status = status,
        createdAt = this.createdAt,
        closedAt = closedAt,
    )

    // Sealed errors nested inside aggregate — co-located with the business rules they describe
    sealed class ActivateError {
        data class InvalidStatus(val current: {AggregateName}Status) : ActivateError()
    }

    sealed class CancelError {
        data class InvalidStatus(val current: {AggregateName}Status) : CancelError()
    }

    companion object {
        fun create(name: String, amount: Long): {AggregateName} =
            {AggregateName}(
                id = {AggregateName}Id.random(),
                name = name,
                amount = amount,
                status = {AggregateName}Status.PENDING,
                createdAt = Instant.now()
            )

        // Rehydration from DB — events are only produced by business methods on live aggregates
        fun from(
            id: {AggregateName}Id,
            name: String,
            amount: Long,
            status: {AggregateName}Status,
            createdAt: Instant,
            closedAt: Instant? = null
        ): {AggregateName} = {AggregateName}(id, name, amount, status, createdAt, closedAt)
    }
}
```

### ID Value Object

```kotlin
package {BASE_PACKAGE}.{module}.domain

import java.util.UUID

data class {AggregateName}Id(val value: UUID) {
    override fun toString(): String = value.toString()

    companion object {
        fun random(): {AggregateName}Id = {AggregateName}Id(UUID.randomUUID())
        fun fromString(raw: String): {AggregateName}Id = {AggregateName}Id(UUID.fromString(raw))
    }
}
```

> `random()` lives in the **production** companion because every UUID is a valid ID — there are no domain constraints. Both `create()` (production) and Mother Objects (tests) use it. Calling it in production is safe and has no side effects.

### Aggregate `.random()` in testFixtures

After creating the aggregate, add a companion extension in `testFixtures/` so Mother Objects and test setup can call `{AggregateName}.Companion.random()`:

```kotlin
// testFixtures/{AggregateName}Extensions.kt
fun {AggregateName}.Companion.random(): {AggregateName} =
    {AggregateName}.create(
        name = "random-${UUID.randomUUID()}",
        amount = (1L..1000L).random(),
        // ... fill all required fields with their own .random() or sensible defaults
    )
```

> `.random()` for the aggregate lives in `testFixtures/` — **not** in production code. An aggregate runs `init` invariants and real business logic. A randomly constructed aggregate is only meaningful in test context. Putting it in production would mix test concerns with domain logic, and a developer could accidentally call it in non-test code.

### Status Enum

```kotlin
package {BASE_PACKAGE}.{module}.domain

enum class {AggregateName}Status {
    PENDING, ACTIVE, CANCELLED;

    fun isActive(): Boolean = this == ACTIVE
    fun canBeCancelled(): Boolean = this == PENDING || this == ACTIVE
}
```

### Repository Interface

```kotlin
package {BASE_PACKAGE}.{module}.domain

// Plain return types — no Either. Infrastructure exceptions propagate unchecked.
interface {AggregateName}Repository {
    fun save({aggregateName}: {AggregateName}): {AggregateName}
    fun findById(id: {AggregateName}Id): {AggregateName}?   // null = not found
    fun findByStatus(status: {AggregateName}Status): List<{AggregateName}>
}
```

### DTO

```kotlin
package {BASE_PACKAGE}.{module}.domain

// All fields must be primitives: String, Int, Long, Boolean, Double.
// UUID → String, Instant → String (ISO-8601), enums → String (.name), nullable → String?
data class {AggregateName}DTO(
    val id: String,           // UUID.toString()
    val name: String,
    val amount: Long,
    val status: String,       // {AggregateName}Status.name
    val createdAt: String,    // Instant.toString()
    val closedAt: String?     // Instant.toString() or null
)
```

## Anti-Patterns

```kotlin
// ❌ data class aggregate root — exposes copy() publicly, breaking invariant control
data class {AggregateName}(val id: {AggregateName}Id, val status: {AggregateName}Status)
// ✅ Regular class with private constructor and explicit factory methods

// ❌ ID as raw UUID instead of value object — loses type safety at boundaries
class {AggregateName}Repository {
    fun findById(id: UUID): {AggregateName}?
}
// ✅ fun findById(id: {AggregateName}Id): {AggregateName}?

// ❌ @JvmInline value class for ID — use plain data class instead
@JvmInline value class {AggregateName}Id(val value: UUID)  // ← wrong pattern
// ✅ data class {AggregateName}Id(val value: UUID)  // public constructor — every UUID is a valid ID

// ❌ DTO in infrastructure package — breaks domain self-containment
package {BASE_PACKAGE}.{module}.infrastructure
data class {AggregateName}DTO(...)
// ✅ DTO lives in domain/ alongside the aggregate

// ❌ DTO with domain/JVM types instead of primitives — not serialization-safe across layers
data class {AggregateName}DTO(
    val id: UUID,                       // ← must be String
    val status: {AggregateName}Status,  // ← must be String (status.name)
    val createdAt: Instant,             // ← must be String (createdAt.toString())
)
// ✅
data class {AggregateName}DTO(
    val id: String,        // UUID.toString()
    val status: String,    // {AggregateName}Status.name
    val createdAt: String, // Instant.toString()
)

// ❌ Status enum without behavior — callers must ask and decide externally
enum class {AggregateName}Status { PENDING, ACTIVE, CANCELLED }
// Called as: if (entity.status == PENDING || entity.status == ACTIVE) { cancel() }
// ✅ canBeCancelled() encapsulates the rule inside the enum

// ❌ Using check() for expected business outcomes — throws 500, caller cannot recover gracefully
fun activate(): {AggregateName} {
    check(status == {AggregateName}Status.PENDING) { "Cannot activate" }  // ← throws RuntimeException
    return copy(status = {AggregateName}Status.ACTIVE)
}
// ✅ Return Either so the use case can map to the right HTTP status
fun activate(): Either<ActivateError, {AggregateName}> {
    if (status != {AggregateName}Status.PENDING) return Either.Error(ActivateError.InvalidStatus(status))
    return Either.Success(copy(status = {AggregateName}Status.ACTIVE))
}

// ❌ Using require() for business rules — require is for invariants, not business outcomes
fun cancel(): {AggregateName} {
    require(status.canBeCancelled()) { "Cannot cancel" }  // ← require is for programming invariants
    return copy(status = {AggregateName}Status.CANCELLED)
}
// ✅ Use require() only in init blocks for true invariants (blank name, negative amount)
```

## Verification

1. `./gradlew service:compileKotlin` passes
2. Conventions satisfied: CC-01, CC-03, CC-05, D-01 through D-10

## Package Location

Place all files in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/`
