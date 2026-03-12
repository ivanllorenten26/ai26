---
name: test-create-integration-tests
description: Creates integration tests for infrastructure adapters (JPA/JOOQ repositories, external services) using TestContainers. Use when you need to verify that an outbound adapter correctly persists or retrieves domain entities.
argument-hint: [AdapterName] using [infrastructure type]
---

# Create Integration Tests

Creates integration tests for infrastructure adapters (repositories, external services) using TestContainers. These verify that infrastructure implementations correctly persist and retrieve domain objects.

## When to Use Which Pattern

| Situation | Example class name | Pattern to use |
|---|---|---|
| JPA repository round-trip | `JpaOrderRepositoryIntegrationTest` | JPA Repository (see below) |
| JOOQ complex query | `JooqOrderRepositoryIntegrationTest` | JOOQ Repository (see below) |
| External HTTP adapter | `PaymentClientContractTest` | Use `test-create-contract-tests` instead — WireMock contract tests have their own skill |

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create integration tests for `{ADAPTER_NAME}` in:
`{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{Adapter}IntegrationTest.kt`

## Implementation Rules

- ✅ Annotate with `@PersistenceIntegrationTest` — the project's composed annotation that wires up TestContainers PostgreSQL, `@SpringBootTest`, `@ActiveProfiles("test")`, and the JOOQ `DSLContext`. If this annotation does not exist yet, create it manually following the pattern in the project's existing `PersistenceIntegrationTest.kt`.
- ✅ Test save/retrieve round-trips with domain objects
- ✅ Verify domain object integrity after persistence
- ✅ Test query operations (findBy criteria)
- ✅ Test error cases (not found, constraint violations)
- ✅ Use Mother Objects for test data
- ❌ No H2/in-memory databases — real PostgreSQL via TestContainers only
- ❌ Do NOT combine `@SpringBootTest` + `@Testcontainers` + `@ActiveProfiles` individually — use `@PersistenceIntegrationTest`
- ❌ No testing framework behavior (JPA mapping internals)
- ❌ No test configuration defined here — use `test-create-test-configuration` skill

## JPA Repository Integration Test

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import {BASE_PACKAGE}.{module}.domain.{Entity}
import {BASE_PACKAGE}.{module}.domain.{Entity}Id
import {BASE_PACKAGE}.{module}.domain.{Entity}Mother
import {BASE_PACKAGE}.{module}.domain.{Entity}Repository
import {BASE_PACKAGE}.shared.test.PersistenceIntegrationTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

@PersistenceIntegrationTest
class Jpa{Entity}RepositoryIntegrationTest {

    @Autowired
    private lateinit var repository: {Entity}Repository

    @Test
    fun `should save and retrieve {entity} with all fields intact`() {
        val entity = {Entity}Mother.create()

        repository.save(entity)
        val retrieved = repository.findById(entity.id)

        assertThat(retrieved).isNotNull
        assertThat(retrieved!!.id).isEqualTo(entity.id)
        assertThat(retrieved.{fieldOne}).isEqualTo(entity.{fieldOne})
    }

    @Test
    fun `should return null when {entity} not found`() {
        val nonExistentId = {Entity}Id(UUID.randomUUID())

        val result = repository.findById(nonExistentId)

        assertThat(result).isNull()
    }

    @Test
    fun `should find {entities} by criteria`() {
        val entityA = {Entity}Mother.withCustomerId(customerId)
        val entityB = {Entity}Mother.withCustomerId(customerId)
        val entityC = {Entity}Mother.create()  // different customer
        repository.save(entityA)
        repository.save(entityB)
        repository.save(entityC)

        val results = repository.findByCustomerId(customerId)

        assertThat(results).hasSize(2)
        assertThat(results.all { it.customerId == customerId }).isTrue()
    }

    @Test
    fun `should persist updated state correctly`() {
        val original = {Entity}Mother.create()
        repository.save(original)

        val updated = original.performAction()  // domain method returns new instance
        repository.save(updated)

        val retrieved = repository.findById(original.id)
        assertThat(retrieved!!.status).isEqualTo(updated.status)
    }
}
```

## JOOQ Repository Integration Test

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import {BASE_PACKAGE}.{module}.domain.{Entity}
import {BASE_PACKAGE}.{module}.domain.{Entity}Mother
import {BASE_PACKAGE}.{module}.domain.{Entity}Repository
import {BASE_PACKAGE}.shared.test.PersistenceIntegrationTest
import org.assertj.core.api.Assertions.assertThat
import org.jooq.DSLContext
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

@PersistenceIntegrationTest
class Jooq{Entity}RepositoryIntegrationTest {

    @Autowired
    private lateinit var repository: {Entity}Repository

    @Autowired
    private lateinit var dsl: DSLContext

    @Test
    fun `should save and retrieve {entity} with all fields intact`() {
        val entity = {Entity}Mother.create()
        repository.save(entity)

        val retrieved = repository.findById(entity.id)

        assertThat(retrieved).isNotNull
        assertThat(retrieved!!.id).isEqualTo(entity.id)
    }

    @Test
    fun `should execute join query correctly`() {
        // Arrange — insert prerequisite data via DSLContext for complex joins
        dsl.insertInto(RELATED_TABLE)
            .set(RELATED_TABLE.ID, relatedId)
            .execute()
        val entity = {Entity}Mother.create()
        repository.save(entity)

        val results = repository.findWithDetails(relatedId)

        assertThat(results).hasSize(1)
    }
}
```

> **External HTTP adapter tests** use WireMock and belong in a separate skill: `test-create-contract-tests`. Integration tests in this skill are **persistence only** (JPA/JOOQ round-trips via TestContainers).

## Anti-Patterns

```kotlin
// ❌ Using H2 instead of real database
@DataJpaTest // Uses H2 by default — different SQL semantics, misses Postgres-specific behaviour
class OrderRepositoryTest { ... }

// ❌ Stacking annotations manually instead of using the composed annotation
@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
class OrderRepositoryIntegrationTest { ... }

// ✅ Real PostgreSQL with TestContainers via the composed annotation
@PersistenceIntegrationTest
class OrderRepositoryIntegrationTest { ... }
```

```kotlin
// ❌ Testing framework internals
@Test
fun `should map JPA entity columns correctly`() {
    // Testing JPA mapping is framework behavior, not business logic
}

// ✅ Test domain object persistence integrity
@Test
fun `should preserve order total after save and retrieve`() {
    val order = OrderMother.withItems(3)
    repository.save(order)
    val retrieved = repository.findBy(order.id())
    assertThat(retrieved!!.totalAmount()).isEqualTo(order.totalAmount())
}
```

## Verification

1. Tests annotated with `@PersistenceIntegrationTest` (not raw `@SpringBootTest + @Testcontainers`)
2. Domain object integrity verified after round-trip (not just save/retrieve existence)
3. Tests run: `./gradlew service:test --tests "*IntegrationTest*"`
4. No H2 dependency in `build.gradle.kts`

## Package Location

`{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/`
