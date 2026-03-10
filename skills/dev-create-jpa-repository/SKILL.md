---
name: dev-create-jpa-repository
description: Creates JPA repository implementation in infrastructure/outbound for standard CRUD. Use when you need simple database operations with minimal complexity.
argument-hint: [EntityName]Repository implementation with JPA
---

# Create JPA Repository

Creates a JPA repository implementation in `infrastructure/outbound/` for standard CRUD operations. JPA is ideal for simple database access with automatic query generation.

## When to Use JPA vs JOOQ

| JPA | JOOQ |
|-----|------|
| Standard CRUD | Complex joins/aggregations |
| Simple filtering | Type-safe custom SQL |
| ORM features (lazy loading) | Performance-critical queries |
| Quick development | Full SQL control |

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create JPA repository implementation for `{ENTITY_NAME}Repository` in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{EntityName}JpaRepository.kt` — repository implementation
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{EntityName}JpaEntity.kt` — JPA entity + mappers
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/SpringData{EntityName}Repository.kt` — Spring Data interface (internal collaborator)

## Implementation Rules

- ✅ Located in `infrastructure/outbound/` (not flat `infrastructure/`)
- ✅ Implements domain interface from `{module}.domain.{EntityName}Repository`
- ✅ JPA entity is separate from domain entity — never leaks outward
- ✅ `toDomainEntity()` on JPA entity, `toJpaEntity()` as extension on domain entity
- ✅ Spring Data interface as internal collaborator
- ✅ Returns plain types: `{EntityName}?` for not-found, `{EntityName}` for save — **no `Either`**
- ✅ Constraint violations throw JPA exceptions (e.g. `DataIntegrityViolationException`) — propagates unchecked
- ❌ No domain entity annotations (`@Entity` stays in infrastructure)
- ❌ No returning JPA entities to callers — always map to domain
- ❌ `Either` in any method return type — port returns plain types

## Example Implementation

### Repository Implementation
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import {BASE_PACKAGE}.{module}.domain.{EntityName}
import {BASE_PACKAGE}.{module}.domain.{EntityName}Id
import {BASE_PACKAGE}.{module}.domain.{EntityName}Repository
import {BASE_PACKAGE}.{module}.domain.{EntityName}Status
import org.springframework.stereotype.Repository

@Repository
class {EntityName}JpaRepository(
    private val jpaRepository: SpringData{EntityName}Repository
) : {EntityName}Repository {

    override fun save({entity}: {EntityName}): {EntityName} {
        val jpaEntity = {entity}.toJpaEntity()
        return jpaRepository.save(jpaEntity).toDomainEntity()
    }

    override fun findById(id: {EntityName}Id): {EntityName}? =
        jpaRepository.findById(id.value).orElse(null)?.toDomainEntity()

    override fun findByStatus(status: {EntityName}Status): List<{EntityName}> =
        jpaRepository.findByStatus(status.name).map { it.toDomainEntity() }

    override fun delete(id: {EntityName}Id) {
        jpaRepository.deleteById(id.value)
    }
}
```

### Spring Data Interface
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface SpringData{EntityName}Repository : JpaRepository<{EntityName}JpaEntity, UUID> {
    fun findByStatus(status: String): List<{EntityName}JpaEntity>
    fun findByCustomerId(customerId: String): List<{EntityName}JpaEntity>
}
```

### JPA Entity
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import jakarta.persistence.*
import java.time.Instant
import java.util.UUID

@Entity
@Table(name = "{table_name}")
class {EntityName}JpaEntity(
    @Id val id: UUID,
    @Column(name = "property1", nullable = false) val property1: String,
    @Column(name = "property2") val property2: String?,
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false) val status: String,
    @Column(name = "created_at", nullable = false) val createdAt: Instant,
    @Version val version: Int = 0
) {
    // JPA no-arg constructor
    protected constructor() : this(UUID.randomUUID(), "", null, "", Instant.now())

    fun toDomainEntity(): {EntityName} = {EntityName}.from(
        id = {EntityName}Id(id),
        property1 = property1,
        property2 = property2,
        status = {EntityName}Status.valueOf(status),
        createdAt = createdAt
    )
}

fun {EntityName}.toJpaEntity(): {EntityName}JpaEntity = {EntityName}JpaEntity(
    id = this.id.value,
    property1 = this.property1,
    property2 = this.property2?.toString(),
    status = this.status.name,
    createdAt = this.createdAt
)
```

## Anti-Patterns

```kotlin
// ❌ JPA entity in domain layer
package {BASE_PACKAGE}.chat.domain
@Entity data class Conversation(...)

// ❌ Returning JPA entity from repository
override fun findById(id: EntityId): ConversationJpaEntity? // leaks infrastructure

// ❌ Repository in flat infrastructure/ instead of outbound/
package {BASE_PACKAGE}.chat.infrastructure // wrong

// ❌ Domain entity with JPA annotations
@Entity @Table(name = "orders")
data class Order(val id: OrderId, ...)
```

## Typical Next Step

After `dev-create-jpa-repository`, verify the persistence adapter with `test-create-integration-tests`, passing:
- Repository class name: `{EntityName}JpaRepository`
- Module name for test package placement

Then pass the repository interface name `{EntityName}Repository` to `dev-create-use-case` to wire the persistence into business operations.

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. Repository is in `infrastructure/outbound/` package
3. Implements domain interface — no extra public methods
4. JPA entity has `toDomainEntity()`, domain has `toJpaEntity()` extension
5. No JPA annotations in domain layer

## Package Location

Place in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/`
