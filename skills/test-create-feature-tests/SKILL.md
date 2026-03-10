---
name: test-create-feature-tests
description: Creates full-stack BDD feature tests with Gherkin docstring comments, TestRestTemplate, and TestContainers. Use when you need acceptance tests expressed in business language that exercise the full HTTP stack.
argument-hint: [FeatureName] covering [business scenarios]
---

# Create Feature Tests

Creates full-stack BDD feature tests that express use case behaviour in business language.
These tests are **acceptance tests**: they exercise the full HTTP stack (controller → use case → real database)
via `TestRestTemplate`. Each `@Test` method starts with a Gherkin docstring comment block that matches
the corresponding `Scenario:` in the `.features/{TICKET}/scenarios/` design artefact.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Prerequisites

### Mother Object

Test methods use `{EntityName}Mother` imported from `{BASE_PACKAGE}.{module}.domain` (testFixtures source set). Run `test-create-mother-object` if it does not exist yet.

### Repository

Feature tests inject the real JOOQ or JPA repository (not an in-memory fake). The real infrastructure adapter must exist before writing feature tests.

## Task

Create BDD feature tests for `{FEATURE_NAME}` in:
- `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/{FeatureName}FeatureTest.kt`

## Implementation Rules

- ✅ `@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)` for full server
- ✅ `@Testcontainers` + real PostgreSQL — no mocks at the persistence layer
- ✅ `@ActiveProfiles("test")` on every test class
- ✅ `TestRestTemplate` for HTTP calls — NOT `MockMvc`
- ✅ Each `@Test` method starts with a Gherkin docstring comment block (`// Scenario: ...`)
- ✅ `@BeforeEach` cleans DB state between tests (delete via repository or truncate)
- ✅ Given-phase: seed state via the real repository (`repository.save(...)`) or Mother Objects
- ✅ When-phase: call the HTTP endpoint via `TestRestTemplate`
- ✅ Then-phase: assert HTTP status code, response body, and/or database state via repository
- ✅ Test file placed at module root alongside `ArchitectureTest.kt` — NOT inside a sub-package
- ❌ No `MockMvc` — use `TestRestTemplate`
- ❌ No `InMemory*Repository` — use real infrastructure adapter
- ❌ No `.feature` files in `src/test/resources/` — `.feature` files are design artefacts in `.features/{TICKET}/scenarios/` only
- ❌ No Cucumber annotations (`@Given`, `@When`, `@Then`, `@After`)

## Example Implementation

```kotlin
// {TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/{FeatureName}FeatureTest.kt

package {BASE_PACKAGE}.{module}

import {BASE_PACKAGE}.{module}.domain.{EntityName}Mother
import {BASE_PACKAGE}.{module}.domain.{EntityName}Status
import {BASE_PACKAGE}.{module}.infrastructure.outbound.Jooq{EntityName}Repository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.web.client.TestRestTemplate
import org.springframework.http.HttpStatus
import org.springframework.test.context.ActiveProfiles
import org.testcontainers.junit.jupiter.Testcontainers

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@ActiveProfiles("test")
class {FeatureName}FeatureTest {

    @Autowired private lateinit var restTemplate: TestRestTemplate
    @Autowired private lateinit var repository: Jooq{EntityName}Repository

    @BeforeEach
    fun setUp() {
        // Clean DB state before each test — ensures test isolation
        repository.deleteAll()
    }

    @Test
    fun `should perform action on {resource} via API`() {
        // Scenario: Successfully perform action on {resource}
        //   Given an open {resource} exists in the database
        //   When I {action} the {resource} via HTTP
        //   Then I should receive a 200 response
        //   And the {resource} status in the database should be {EXPECTED_STATE}

        val {entity} = {EntityName}Mother.create()
        repository.save({entity})

        val response = restTemplate.exchange(
            "/api/v1/{resources}/{id}/{action}",
            org.springframework.http.HttpMethod.PUT,
            null,
            {EntityName}Controller.ResponseDto::class.java,
            {entity}.id.value
        )

        assertThat(response.statusCode).isEqualTo(HttpStatus.OK)
        assertThat(repository.findById({entity}.id)!!.status).isEqualTo({EntityName}Status.{EXPECTED_STATE})
    }

    @Test
    fun `should return 404 when {resource} does not exist`() {
        // Scenario: Reject action when {resource} does not exist
        //   Given no {resource} exists with the given ID
        //   When I {action} the {resource} via HTTP
        //   Then I should receive a 404 response

        val nonExistentId = java.util.UUID.randomUUID()

        val response = restTemplate.exchange(
            "/api/v1/{resources}/{id}/{action}",
            org.springframework.http.HttpMethod.PUT,
            null,
            Any::class.java,
            nonExistentId
        )

        assertThat(response.statusCode).isEqualTo(HttpStatus.NOT_FOUND)
    }

    @Test
    fun `should return 409 when {resource} is already in terminal state`() {
        // Scenario: Reject action when {resource} is already in terminal state
        //   Given a {resource} in {TERMINAL_STATE} state exists in the database
        //   When I {action} the {resource} via HTTP
        //   Then I should receive a 409 response

        val {entity} = {EntityName}Mother.{terminalState}()
        repository.save({entity})

        val response = restTemplate.exchange(
            "/api/v1/{resources}/{id}/{action}",
            org.springframework.http.HttpMethod.PUT,
            null,
            Any::class.java,
            {entity}.id.value
        )

        assertThat(response.statusCode).isEqualTo(HttpStatus.CONFLICT)
    }
}
```

## Gherkin Docstring Convention

Every `@Test` method that implements a design scenario MUST start with a `// Scenario:` docstring block:

```kotlin
@Test
fun `should close conversation via API`() {
    // Scenario: Successfully close a conversation via HTTP
    //   Given an open conversation exists in the database
    //   When I PUT /api/v1/conversations/{id}/close
    //   Then I should receive a 200 response
    //   And the conversation status in the database should be CLOSED

    // ... test implementation ...
}
```

The scenario name on the first line (`// Scenario: Successfully close a conversation via HTTP`) should
describe the business behaviour in plain language — the same language used in the design discussion.
Use the same wording consistently across the test method name, the docstring, and any related documentation.

## Anti-Patterns

```kotlin
// ❌ MockMvc — wrong layer for feature tests (use TestRestTemplate)
@Autowired private lateinit var mockMvc: MockMvc

// ❌ InMemoryRepository — feature tests must use real infrastructure
@Autowired private lateinit var repository: InMemoryConversationRepository

// ❌ Cucumber annotations — no Cucumber framework
@Given("an open conversation exists")
fun givenOpenConversation() { ... }

// ❌ No Gherkin docstring — test has no traceability to design artefact
@Test
fun `should close conversation`() {
    // no Scenario: comment — linter will flag this
    ...
}

// ❌ Missing @ActiveProfiles("test") — test may hit production config
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ConversationFeatureTest { ... }  // missing @ActiveProfiles("test")

// ❌ No @BeforeEach cleanup — state leaks between tests
class ConversationFeatureTest {
    // missing @BeforeEach fun setUp() — tests pollute each other
}
```

```kotlin
// ✅ Full-stack test with Gherkin docstring
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@ActiveProfiles("test")
class CloseConversationFeatureTest {

    @Autowired private lateinit var restTemplate: TestRestTemplate
    @Autowired private lateinit var repository: JooqConversationRepository

    @BeforeEach
    fun setUp() { repository.deleteAll() }

    @Test
    fun `should close conversation via API`() {
        // Scenario: Successfully close a conversation via HTTP
        //   Given an open conversation exists in the database
        //   When I PUT /api/v1/conversations/{id}/close
        //   Then I should receive a 200 response
        //   And the conversation status in the database should be CLOSED

        val conversation = ConversationMother.create()
        repository.save(conversation)

        val response = restTemplate.exchange(
            "/api/v1/conversations/{id}/close",
            HttpMethod.PUT,
            null,
            ConversationController.ResponseDto::class.java,
            conversation.id.value
        )

        assertThat(response.statusCode).isEqualTo(HttpStatus.OK)
        assertThat(repository.findById(conversation.id)!!.status).isEqualTo(ConversationStatus.CLOSED)
    }
}
```

## Verification

1. No `MockMvc` imports — feature tests use `TestRestTemplate` only
2. No `InMemory*Repository` — real infrastructure adapter is injected
3. No `io.cucumber` imports — no Cucumber framework
4. Every `@Test` method has a `// Scenario:` docstring comment
5. Scenario names match the `.features/{TICKET}/scenarios/` design artefact
6. `@Testcontainers` and `RANDOM_PORT` are present
7. `@ActiveProfiles("test")` is present
8. `@BeforeEach` cleans DB state
9. Tests pass: `./gradlew service:test --tests "*{FeatureName}FeatureTest"`

## Package Location

- Tests: `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/` (module root, alongside `ArchitectureTest.kt`)
