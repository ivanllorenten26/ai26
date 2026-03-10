---
name: dev-create-domain-entity
description: Creates a child entity inside an existing aggregate boundary. Use when adding a subordinate entity to an existing aggregate root — not for new aggregate roots (use dev-create-aggregate for that).
argument-hint: [EntityName] inside [AggregateName] aggregate in [module] with [property1:Type1, property2:Type2]
---

# Create Domain Entity

Creates a child entity that lives inside an existing aggregate boundary. Use this skill when you need to add a subordinate entity to an existing aggregate root — for example, `OrderItem` inside `Order`, or `Address` inside `Customer`.

**When to use this skill vs. `dev-create-aggregate`:**
- `dev-create-domain-entity` → the entity is owned by and accessed through an existing aggregate root (child entity)
- `dev-create-aggregate` → the entity IS the aggregate root; it has its own identity, lifecycle, and repository

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.
Also resolve `shared_imports.either` (fallback: `de.tech26.valium.shared.kernel.Either`).

## Task

Create a child entity `{ENTITY_NAME}` inside the `{AGGREGATE_NAME}` aggregate in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{EntityName}.kt` — child entity class

For a value object ID (`{EntityName}Id`), invoke the **`dev-create-value-object`** skill only if this child entity has independent identity within the aggregate.

> **Child entity rule**: child entities are accessed only through the aggregate root — they have **no repository** of their own. If you need a repository, use `dev-create-aggregate` instead.

## Implementation Rules

- ✅ Private constructor with companion `from()` or `create()` factory
- ✅ `init` block for invariant validation
- ✅ Immutable — mutations return new instances via `copy()`
- ✅ Domain methods express business behavior (Tell Don't Ask — Section 7.11)
- ✅ Business methods that can fail return `Either<SealedError, {EntityName}>` — never `check()` for expected outcomes
- ✅ Status enum with behavior methods
- ✅ Value object ID (`data class {EntityName}Id(val value: UUID)` — see `dev-create-value-object` skill), only if entity has independent identity
- ❌ No repository interface — child entities are accessed through the aggregate root only; use `dev-create-aggregate` if a repository is needed
- ❌ No DTO class — the child entity is exposed via the aggregate root's DTO
- ❌ No framework annotations (`@Entity`, `@Service`, etc.)
- ❌ No `data class` — use class with private constructor (prevents external instantiation)
- ❌ No public setters or mutable state
- ❌ No infrastructure imports

## Example Implementation

### Child Entity
```kotlin
package {BASE_PACKAGE}.{module}.domain

import de.tech26.valium.shared.kernel.Either
import java.time.Instant

// Child entity — no repository, no DTO. Accessed only through {AggregateName}.
class {EntityName} private constructor(
    val id: {EntityName}Id,
    val property1: String,
    val property2: {Type},
    val status: {EntityName}Status,
    val createdAt: Instant
) {

    init {
        require(property1.isNotBlank()) { "property1 cannot be blank" }
    }

    // Business methods that can fail return Either — never check() for expected outcomes
    fun performBusinessAction(parameter: {Type}): Either<PerformError, {EntityName}> {
        if (status != {EntityName}Status.ACTIVE) {
            return Either.Error(PerformError.InvalidStatus(status))
        }
        return Either.Success(copy(status = {EntityName}Status.PROCESSED))
    }

    fun deactivate(): {EntityName} =
        copy(status = {EntityName}Status.INACTIVE)

    private fun copy(
        property1: String = this.property1,
        property2: {Type} = this.property2,
        status: {EntityName}Status = this.status
    ): {EntityName} = {EntityName}(
        id = this.id,
        property1 = property1,
        property2 = property2,
        status = status,
        createdAt = this.createdAt
    )

    sealed class PerformError {
        data class InvalidStatus(val current: {EntityName}Status) : PerformError()
    }

    companion object {
        fun from(
            id: {EntityName}Id,
            property1: String,
            property2: {Type},
            status: {EntityName}Status,
            createdAt: Instant
        ): {EntityName} = {EntityName}(id, property1, property2, status, createdAt)

        fun create(property1: String, property2: {Type}): {EntityName} =
            {EntityName}(
                id = {EntityName}Id.random(),
                property1 = property1,
                property2 = property2,
                status = {EntityName}Status.ACTIVE,
                createdAt = Instant.now()
            )
    }
}
```

### Value Object ID

For the entity ID, use the **`dev-create-value-object`** skill with the ID pattern. Example result:

```kotlin
// {EntityName}Id.kt — created by dev-create-value-object
package {BASE_PACKAGE}.{module}.domain

import java.util.UUID

data class {EntityName}Id(val value: UUID) {
    companion object {
        fun random(): {EntityName}Id = {EntityName}Id(UUID.randomUUID())
        fun fromString(raw: String): {EntityName}Id = {EntityName}Id(UUID.fromString(raw))
    }
    override fun toString(): String = value.toString()
}
```

> `random()` lives in the **production** companion — every UUID is a valid ID, so there are no constraints to enforce. Both `create()` and test code use it.

### Entity `.random()` in testFixtures

After creating the entity, add a companion extension in `testFixtures/` so Mother Objects can call `{EntityName}.Companion.random()`:

```kotlin
// testFixtures/{EntityName}Extensions.kt
fun {EntityName}.Companion.random(): {EntityName} =
    {EntityName}.create(
        property1 = "random-value",
        property2 = {Type}.random(),
    )
```

> `.random()` for entities lives in `testFixtures/` — **not** in production. An entity runs `init` invariants and enforces business rules. Constructing one with random data only makes sense in test context. Keeping it in `testFixtures/` prevents accidental production use.

### Status Enum
```kotlin
package {BASE_PACKAGE}.{module}.domain

enum class {EntityName}Status {
    ACTIVE, INACTIVE, PROCESSED, CANCELLED;

    fun isActive(): Boolean = this == ACTIVE
    fun canBeProcessed(): Boolean = this == ACTIVE
}
```

## Anti-Patterns

```kotlin
// ❌ Data class with public constructor — anyone can create invalid state
data class Order(val id: OrderId, val items: List<OrderItem>, val status: OrderStatus)

// ❌ Mutable state
class Order(var status: OrderStatus)

// ❌ Ask pattern — exposing state for external decisions
class Order(val items: List<OrderItem>) {
    fun getItems() = items  // Let caller decide what to do
}
// ✅ Tell pattern — entity makes its own decisions
class Order { fun confirm(): Order { /* validates internally */ } }

// ❌ Framework annotations in domain
@Entity data class Order(...)

// ❌ Infrastructure dependency in domain
class Order(private val repository: OrderRepository) // DI in entity!
```

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. No imports from `org.springframework`, `javax.persistence`, or `infrastructure`
3. Constructor is private with companion factory
4. All mutations return new instances
5. No repository interface generated — child entity is accessed through the aggregate root
6. Business methods that can fail return `Either<SealedError, {EntityName}>` — no `check()` for expected outcomes

## Package Location

Place in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/`
