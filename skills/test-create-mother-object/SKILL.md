---
name: test-create-mother-object
description: Creates Mother Object test fixtures for domain entities in the testFixtures source set. Use when you need reusable test data factories for a domain entity or aggregate.
argument-hint: [EntityName] in [module]
---

# Skill: test-create-mother-object

## Purpose

Creates a Mother Object for a domain entity in the `testFixtures` source set, under the same package as the entity (`{BASE_PACKAGE}.{module}.domain`). Mother Objects provide reusable, readable test fixtures that hide construction details and allow each test to override only the fields it cares about.

This skill creates the canonical fixture — all test skills (`test-create-use-case-tests`, `test-create-feature-tests`, `test-create-integration-tests`) import from this location.

---

## Prerequisites

- Read `ai26/config.yaml` → `modules` → find the module with `active: true`. From that module read `test_fixtures_root`, `base_package`, `main_source_root`.
- The entity/aggregate must already exist in the domain layer.
- The entity must have a factory method (`from(...)` or `create(...)`) in its `companion object`.

---

## Output

One or two files per entity:

| File | Description |
|------|-------------|
| `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{EntityName}Mother.kt` | Mother Object fixture |
| `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{SealedClassName}Mother.kt` | Error fixture (only when entity has sealed error classes) |

Where:
- `TEST_FIXTURES_SRC` = value of `test_fixtures_source_root` from `ai26/config.yaml`, default `service/src/testFixtures/kotlin`
- `BASE_PACKAGE_PATH` = `basePackage` with dots replaced by `/` (e.g. `de/tech26/valium`)
- `MODULE` = the module name passed as argument (e.g. `conversation`)

---

## Pattern

```kotlin
package {BASE_PACKAGE}.{module}.domain

import {BASE_PACKAGE}.{module}.domain.{EntityName}
import {BASE_PACKAGE}.{module}.domain.{EntityName}Id
// import other value objects used by the entity

object {EntityName}Mother {

    fun create(
        id: {EntityName}Id = {EntityName}Id.random(),
        // ... all other fields with sensible defaults
    ): {EntityName} = {EntityName}.from(
        id = id,
        // ... pass all fields
    )
}
```

Rules:
- `object` (not `class`) — Mother Objects are singletons
- Package matches the entity's package (`{BASE_PACKAGE}.{module}.domain`) — lives in `testFixtures`, not in `test`
- **Always delegate to the domain factory** (`create()` / `from()`) — never construct domain objects directly; the factory enforces `init`-block invariants
- **Default parameters are random, not fixed** — `UUID.randomUUID()` for IDs, `Instant.now()` for timestamps, `{EnumType}.random()` for enums. Random defaults prevent false positives from accidental coupling and communicate *"this field doesn't matter for this test"*
- Use the entity's `from()` factory, NOT constructors directly
- No Spring annotations — pure Kotlin
- No `@JvmStatic` — Kotlin callers don't need it

### Domain-owned random generation

The convention is uniform: every domain type provides `.random()`. Where it lives depends on the type:

| Type | Where `.random()` lives | Reason |
|---|---|---|
| **Value Object / ID** | Production `companion object` | Every UUID is valid; safe to call anywhere |
| **Enum** | `testFixtures/` companion extension | "Valid creation values" is test knowledge, not domain knowledge |
| **Aggregate / Entity** | `testFixtures/` companion extension | A random aggregate only makes sense in test context |

**Enums** — implement as a companion extension in `testFixtures/`:

```kotlin
// testFixtures/{EnumName}Extensions.kt
fun {EnumType}.Companion.random(): {EnumType} = entries.random()
```

The production enum only needs an empty `companion object` so the extension can attach:

```kotlin
enum class CustomerPlatform {
    IOS, ANDROID, WEB;
    companion object  // empty — enables companion extensions in testFixtures
}
```

When not all enum values are valid for creation, the extension restricts the set in one place:

```kotlin
// Only OPEN is valid at creation time — all other states are reached via transitions
fun ConversationStatus.Companion.random(): ConversationStatus =
    listOf(ConversationStatus.OPEN).random()
```

**Aggregates and Entities** — implement as a companion extension in `testFixtures/`:

```kotlin
// testFixtures/{AggregateName}Extensions.kt
fun {AggregateName}.Companion.random(): {AggregateName} =
    {AggregateName}.create(
        // fill required fields using their own .random()
        customerId = CustomerId.random(),
        platform = CustomerPlatform.random(),
    )
```

> Aggregates run `init` invariants and real business logic. A randomly constructed aggregate only makes sense in test setup — keeping `.random()` in `testFixtures/` prevents it from being called in production by accident.

**Value Objects and IDs** — `.random()` is already in their production companion:

```kotlin
// Already generated by dev-create-value-object / dev-create-aggregate
data class ConversationId(val value: UUID) {
    companion object {
        fun random(): ConversationId = ConversationId(UUID.randomUUID())
    }
}
```

Usage in Mothers:

```kotlin
id: ConversationId = ConversationId.random(),
customerId: CustomerId = CustomerId.random(),
customerPlatform: CustomerPlatform = CustomerPlatform.random(),
status: ConversationStatus = ConversationStatus.random(),
```

---

## Steps

### Step 1 — Read entity definition

Read the entity source file at `{SOURCE_ROOT}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{EntityName}.kt`.

Identify:
- The `from(...)` or `create(...)` factory method signature
- All field types and their constructors/factories
- Any nested value objects that need Mother defaults
- Any nested sealed error classes (e.g. `CancelError`, `ActivateError`)

### Step 2 — Resolve output path

From `ai26/config.yaml` → `modules` → active module:
```
test_fixtures_root: service/src/testFixtures/kotlin   # use this if present, else default
base_package: de.tech26.valium
```

Output path = `{testFixturesSourceRoot}/{basePackage as path}/{module}/domain/{EntityName}Mother.kt`

Example: `service/src/testFixtures/kotlin/de/tech26/valium/conversation/domain/ConversationMother.kt`

### Step 3 — Check for sealed error classes

If the entity defines nested sealed error classes (e.g. `CancelError`, `ActivateError`), generate a companion error Mother file:

```kotlin
// {EntityName}CancelErrorMother.kt
package {BASE_PACKAGE}.{module}.domain

object {EntityName}CancelErrorMother {
    fun invalidStatus(
        current: {EntityName}Status = {EntityName}Status.ACTIVE
    ): {EntityName}.CancelError.InvalidStatus =
        {EntityName}.CancelError.InvalidStatus(current)
}
```

### Step 4 — Generate Mother Object

Apply the pattern above. For each parameter:
- If it's a **domain ID value object** → use `{EntityName}Id.random()` (production companion)
- If it's a **domain enum** → use `{EnumType}.random()` (companion extension from `testFixtures/`)
- If it's an **aggregate or entity** → use `{AggregateName}.Companion.random()` (companion extension from `testFixtures/`)
- If it's a `List` → default to `emptyList()`
- If it's `Instant` → default to `Instant.now()` for timestamps
- If it's `Boolean` → default to `false`
- If it's a raw `UUID` (no value object wrapping it) → use `UUID.randomUUID()`
- **Never use hardcoded magic values** — random defaults communicate *"this field doesn't affect the test"*

### Step 5 — Write files

Write the Mother Object(s) to the resolved path(s).

---

## Constraints

- Always place Mother Objects in the `testFixtures` source set under `{BASE_PACKAGE_PATH}/{MODULE}/domain/` — never in `src/test`.
- Never use `@Component`, `@Bean`, or any Spring annotation.
- Never import from `jakarta.persistence.*` or `org.jooq.*`.
- Do not create a Mother Object if the entity does not yet exist.
- One Mother Object per entity — do not create `ConversationMother` and `ConversationAggregateMother` for the same entity.

---

## Example

Given `Conversation` aggregate with:
```kotlin
companion object {
    fun from(id: ConversationId, customerId: CustomerId, status: ConversationStatus, createdAt: Instant): Conversation
}
```

Produces (`service/src/testFixtures/kotlin/de/tech26/valium/conversation/domain/ConversationMother.kt`):
```kotlin
package de.tech26.valium.conversation.domain

import de.tech26.valium.conversation.domain.Conversation
import de.tech26.valium.conversation.domain.ConversationId
import de.tech26.valium.conversation.domain.ConversationStatus
import java.time.Instant
import java.util.UUID

object ConversationMother {

    fun create(
        id: ConversationId = ConversationId.random(),          // ID VO owns its random — in production companion
        customerId: CustomerId = CustomerId.random(),          // same convention for all ID VOs
        status: ConversationStatus = ConversationStatus.random(),  // enum random — in testFixtures extension
        startedAt: Instant = Instant.now(),
        customerPlatform: CustomerPlatform = CustomerPlatform.random(),  // enum random — in testFixtures extension
        language: N26Locale.Lang = N26Locale.Lang.random(),
    ): Conversation = Conversation.create(
        id = id,
        customerId = customerId,
        startedAt = startedAt,
        customerPlatform = customerPlatform,
        language = language,
    )

    // Named states compose on top of create()
    fun closed() = create().close()
    fun withCustomer(customerId: CustomerId) = create(customerId = customerId)
}
```

---

## See Also

- `test-create-use-case-tests` — consumes Mother Objects for use case unit tests
- `test-create-feature-tests` — consumes Mother Objects for BDD acceptance tests
- `test-create-integration-tests` — consumes Mother Objects for infrastructure tests
- `sdlc-implement-feature` Step 1.7 — invokes this skill automatically per aggregate
- `dev-create-domain-exception` — defines sealed error classes for which error Mother Objects may be needed
