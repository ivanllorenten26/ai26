---
name: dev-create-jooq-repository
description: Creates JOOQ repository implementation in infrastructure/outbound for type-safe SQL. Use when you need complex queries, joins, or performance-critical database operations.
argument-hint: [EntityName]Repository implementation with JOOQ
---

# Create JOOQ Repository

Creates a JOOQ repository implementation in `infrastructure/outbound/` for type-safe SQL with full control over database operations. JOOQ provides compile-time query validation and excellent performance.

## When to Use JOOQ vs JPA

| JOOQ | JPA |
|------|-----|
| Complex joins/aggregations | Standard CRUD |
| Type-safe SQL required | Simple filtering |
| Performance-critical paths | ORM features wanted |
| Database-first approach | Quick prototyping |

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## JOOQ Import Conventions

Generated JOOQ classes live in the `persistence` module under `de.tech26.valium.persistence.jooq`. Import patterns:

| Import target | Pattern |
|---|---|
| Table constant | `de.tech26.valium.persistence.jooq.tables.{TableClass}.Companion.{TABLE_CONSTANT}` |
| Record class | `de.tech26.valium.persistence.jooq.tables.records.{EntityName}Record` |
| Enum | `de.tech26.valium.persistence.jooq.enums.{EnumName}` |

Example (from actual codebase):
```kotlin
import de.tech26.valium.persistence.jooq.tables.ConversationV2.Companion.CONVERSATION_V2
import de.tech26.valium.persistence.jooq.tables.records.ConversationV2Record
import de.tech26.valium.persistence.jooq.enums.ConversationV2Status
```

> Run `dev-generate-jooq-schema` first to regenerate JOOQ classes after Flyway migrations.

## Task

Create JOOQ repository implementation for `{ENTITY_NAME}Repository` in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/Jooq{EntityName}Repository.kt` — repository implementation; mapping functions (`toDomain()`, `toJooq()`) are private extension functions in the same file

## Implementation Rules

- ✅ Located in `infrastructure/outbound/`
- ✅ Implements domain interface from `{module}.domain.{EntityName}Repository`
- ✅ Injects `DSLContext` for all queries
- ✅ Record-to-domain mapping via extension function `toDomainEntity()`
- ✅ `@Repository` annotation only — no `@Transactional` on the repository class
- ✅ Optimistic locking via VERSION column check
- ✅ Returns plain types: `{EntityName}?` for not-found, `{EntityName}` for save — **no `Either`**
- ✅ JOOQ exceptions (e.g. `DataAccessException`) propagate unchecked to `@ControllerAdvice → 500`
- ❌ No domain type leakage — always map records to domain entities
- ❌ No raw SQL strings — use JOOQ DSL exclusively
- ❌ `Either` in any method return type — port returns plain types

## Example Implementation

### Repository Implementation
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import {BASE_PACKAGE}.{module}.domain.{EntityName}
import {BASE_PACKAGE}.{module}.domain.{EntityName}Id
import {BASE_PACKAGE}.{module}.domain.{EntityName}Repository
import {BASE_PACKAGE}.{module}.domain.{EntityName}Status
import de.tech26.valium.persistence.jooq.tables.{TableClass}.Companion.{TABLE_CONSTANT}
import de.tech26.valium.persistence.jooq.tables.records.{EntityName}Record
import org.jooq.DSLContext
import org.springframework.stereotype.Repository

@Repository
class Jooq{EntityName}Repository(
    private val dsl: DSLContext
) : {EntityName}Repository {

    override fun save({entity}: {EntityName}): {EntityName} {
        val record = dsl.insertInto({TABLE_NAME})
            .set({TABLE_NAME}.ID, {entity}.id.value)
            .set({TABLE_NAME}.PROPERTY1, {entity}.property1)
            .set({TABLE_NAME}.STATUS, {entity}.status.name)
            .set({TABLE_NAME}.CREATED_AT, {entity}.createdAt)
            .onDuplicateKeyUpdate()
            .set({TABLE_NAME}.PROPERTY1, {entity}.property1)
            .set({TABLE_NAME}.STATUS, {entity}.status.name)
            .returning()
            .fetchOne()
            ?: throw IllegalStateException("Failed to save {entity}")

        return record.toDomainEntity()
    }

    override fun findById(id: {EntityName}Id): {EntityName}? =
        dsl.selectFrom({TABLE_NAME})
            .where({TABLE_NAME}.ID.eq(id.value))
            .fetchOne()
            ?.toDomainEntity()

    override fun findByStatus(status: {EntityName}Status): List<{EntityName}> =
        dsl.selectFrom({TABLE_NAME})
            .where({TABLE_NAME}.STATUS.eq(status.name))
            .orderBy({TABLE_NAME}.CREATED_AT.desc())
            .fetch()
            .map { it.toDomainEntity() }

    override fun delete(id: {EntityName}Id) {
        dsl.deleteFrom({TABLE_NAME})
            .where({TABLE_NAME}.ID.eq(id.value))
            .execute()
    }
}
```

### Record-to-Domain Mapper
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import de.tech26.valium.persistence.jooq.tables.records.{EntityName}Record

fun {EntityName}Record.toDomainEntity(): {EntityName} = {EntityName}.from(
    id = {EntityName}Id(id),
    property1 = property1,
    property2 = property2,
    status = {EntityName}Status.valueOf(status),
    createdAt = createdAt
)
```

### Dynamic Query Example
```kotlin
fun findWithCriteria(
    customerId: String?,
    status: {EntityName}Status?,
    fromDate: Instant?
): List<{EntityName}> {
    val conditions = mutableListOf(DSL.trueCondition())

    customerId?.let { conditions.add({TABLE_NAME}.CUSTOMER_ID.eq(it)) }
    status?.let { conditions.add({TABLE_NAME}.STATUS.eq(it.name)) }
    fromDate?.let { conditions.add({TABLE_NAME}.CREATED_AT.ge(it)) }

    return dsl.selectFrom({TABLE_NAME})
        .where(DSL.and(conditions))
        .orderBy({TABLE_NAME}.CREATED_AT.desc())
        .fetch()
        .map { it.toDomainEntity() }
}
```

### Join Query Example
```kotlin
fun findWithDetails(id: {EntityName}Id): {EntityName}WithDetails? {
    val records = dsl.select()
        .from({TABLE_NAME})
        .leftJoin(CHILD_TABLE).on({TABLE_NAME}.ID.eq(CHILD_TABLE.PARENT_ID))
        .where({TABLE_NAME}.ID.eq(id.value))
        .fetch()

    if (records.isEmpty()) return null

    val entity = records.first().into({TABLE_NAME}).toDomainEntity()
    val children = records
        .filter { it[CHILD_TABLE.ID] != null }
        .map { it.into(CHILD_TABLE).toDomainChild() }

    return {EntityName}WithDetails(entity, children)
}
```

## Anti-Patterns

```kotlin
// ❌ @Transactional on repository — belongs on the use case only
@Repository
@Transactional  // ← remove this; add @Transactional to the use case instead
class OrderJooqRepository(...)

// ❌ Raw SQL strings
dsl.fetch("SELECT * FROM orders WHERE id = ?", id)

// ❌ Returning JOOQ records to domain
override fun findById(id: EntityId): OrderRecord? // leaks infrastructure

// ❌ Repository in flat infrastructure/
package {BASE_PACKAGE}.chat.infrastructure // wrong — use outbound/

// ❌ Missing optimistic locking on update
dsl.update(ORDERS).set(...).where(ORDERS.ID.eq(id)).execute()
// ✅ With version check
dsl.update(ORDERS).set(...).where(ORDERS.ID.eq(id)).and(ORDERS.VERSION.eq(version)).execute()
```

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. Repository is in `infrastructure/outbound/` package
3. Implements domain interface — no extra public methods
4. All queries use JOOQ DSL — no raw SQL strings
5. Record mapper converts to domain entity

## Package Location

Place in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/`
