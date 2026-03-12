---
name: test-create-controller-tests
description: Creates controller integration tests using MockMvc to verify HTTP contracts, serialization, and error mapping. Use when you need to test a REST controller's transport layer behavior.
argument-hint: [ControllerName] testing [HTTP method] [endpoint path]
---

# Create Controller Tests

Creates controller integration tests using `@WebMvcTest` and `MockMvc` to verify HTTP contracts, request/response serialization, header validation, and error mapping. Tests the transport layer independently from business logic — the Use Case is mocked.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create a controller test `{CONTROLLER_NAME}Test` in:
- `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{ControllerName}Test.kt`

## Implementation Rules

### Prerequisites

`ControllerTest` is an abstract base class at `{TEST_SRC}/{BASE_PACKAGE_PATH}/ControllerTest.kt` that sets `@ActiveProfiles("test")`, provides `makeRequest()`, and adds shared header validation (customerId, locale, platform). If it does not exist in the module yet, create it manually following the pattern in the project's existing `ControllerTest.kt`, or use standalone `@WebMvcTest` with `@ActiveProfiles("test")` until the base class is available.

### Test Characteristics
- ✅ `@WebMvcTest({ControllerName}::class)` — loads only the web layer
- ✅ Extend `ControllerTest` (abstract base class at `{TEST_SRC}/{BASE_PACKAGE_PATH}/ControllerTest.kt`)
- ✅ `@MockkBean` for the Use Case dependency (with `springmockk`)
- ✅ Test naming: `should {expected behavior} when {condition}`
- ✅ Given-When-Then structure in each test
- ✅ Cover: happy path, validation errors, domain exceptions, unexpected errors
- ❌ Do **not** add `@ActiveProfiles("test")` — the base class already declares it

### What to Test
- ✅ HTTP status codes (201, 200, 400, 404, 500)
- ✅ Response body structure (JSON paths)
- ✅ Request body validation (missing/blank fields → 400)
- ✅ **Input parsing** (invalid UUID string → 400, unknown enum value → 400) — parsed by controller
- ✅ `Either.Error` mapping: use case returns `Either.Error(UCError.X)` → correct HTTP status
- ✅ Content-Type handling
- ❌ **Shared header validation** (customerId, locale, platform) — already covered by `ControllerTest`; only add header tests for headers **specific to this endpoint**
- ❌ Business logic (tested in Use Case tests)
- ❌ Database interactions (tested in integration tests)
- ❌ Full Spring context (use `@WebMvcTest`, not `@SpringBootTest`)
- ❌ `ApplicationException` testing — that class is eliminated; fold is `toResponseEntity()` returning `ResponseEntity` directly

## Example Implementation

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound

import com.ninjasquad.springmockk.MockkBean
import {BASE_PACKAGE}.ControllerTest
import {BASE_PACKAGE}.{module}.application.{UseCaseName}
import {BASE_PACKAGE}.{module}.domain.errors.{UseCaseName}DomainError
import {sharedImports.either}
import io.mockk.every
import io.mockk.slot
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.NullAndEmptySource
import org.junit.jupiter.params.provider.ValueSource
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.{httpMethod}
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

// @ActiveProfiles("test") — inherited from ControllerTest
@WebMvcTest({ControllerName}::class)
class {ControllerName}Test : ControllerTest() {

    @MockkBean
    private lateinit var {useCase}: {UseCaseName}

    // Implement abstract members required by ControllerTest
    override fun requestBuilder() = {httpMethod}("{endpoint}")
        .contentType(MediaType.APPLICATION_JSON)
        .content("""{"field": "value"}""")

    override fun mockSuccessfulRequest() {
        every { {useCase}(any()) } returns Either.Success({expectedDTO})
    }

    override fun capturedCustomerInformation(): CustomerInformation = TODO("capture from slot")

    // --- Happy Path ---

    @Test
    fun `should return {statusCode} when {operation} succeeds`() {
        // Given
        every { {useCase}(any()) } returns Either.Success({expectedDTO})

        // When & Then
        mockMvc.perform(makeRequest())
            .andExpect(status().is{StatusName})
            .andExpect(jsonPath("$.{responseField}").value({expectedValue}))
    }

    // --- Input Validation ---

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = ["invalid-value"])
    fun `should return 400 when {field} is invalid`({field}: String?) {
        // When & Then
        mockMvc.perform(
            {httpMethod}("{endpoint}")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"field": ${if ({field} != null) "\"${field}\"" else "null"}}""")
        ).andExpect(status().isBadRequest)
    }

    // --- Input parsing (controller parses String → domain type) ---

    @Test
    fun `should return 400 when {field} value is not a valid enum`() {
        // No use case mock needed — controller rejects invalid input before calling use case
        mockMvc.perform(
            {httpMethod}("{endpoint}")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"field": "INVALID_VALUE"}""")
        ).andExpect(status().isBadRequest)
    }

    // --- Either.Error mapping (fold without ApplicationException) ---

    @Test
    fun `should return {errorStatus} when use case returns {domainError}`() {
        // Given — use case returns Either.Error, controller folds to ResponseEntity via toResponseEntity()
        every { {useCase}(any(), any()) } returns Either.Error({UseCaseName}Error.{SpecificError}({entityId}))

        // When & Then
        mockMvc.perform(
            {httpMethod}("{endpoint}")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"field": "VALID_VALUE"}""")
        ).andExpect(status().is{ErrorStatusName})
    }

    // --- Unexpected Errors ---

    @Test
    fun `should return 500 when use case throws unexpected exception`() {
        // Given
        every { {useCase}(any()) } throws RuntimeException("Unexpected error")

        // When & Then
        mockMvc.perform(
            {httpMethod}("{endpoint}")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"field": "value"}""")
        ).andExpect(status().isInternalServerError)
    }

    // --- Capturing and Verifying Input ---

    @Test
    fun `should pass correct input to use case`() {
        // Given
        val inputCapturer = slot<{InputType}>()
        every { {useCase}(capture(inputCapturer)) } returns Either.Success({expectedDTO})

        // When
        mockMvc.perform(
            {httpMethod}("{endpoint}")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"field": "expectedValue"}""")
        ).andExpect(status().is{StatusName})

        // Then
        assertThat(inputCapturer.captured.field).isEqualTo("expectedValue")
    }
}
```

## Test Categories Checklist

For each controller, cover these categories:

| Category | What to verify |
|----------|---------------|
| **Happy path** | Correct status code + response body |
| **Request validation** | Missing/blank body fields → 400 |
| **Input parsing** | Invalid UUID path param → 400; unknown enum value → 400 (no use case mock needed) |
| **Header validation** | Shared headers (customerId, locale, platform) → covered by `ControllerTest` base class; only add tests for endpoint-specific headers |
| **Either.Error mapping** | `Either.Error(UCError.X)` → controller folds to correct HTTP status via `ResponseStatusException` |
| **Unexpected errors** | `RuntimeException` from use case → 500 |
| **Input mapping** | Capture use case input (typed params) and verify correct mapping |

## Anti-Patterns

```kotlin
// ❌ Using @SpringBootTest — too heavy, loads full context
@SpringBootTest
class ControllerTest { /* ... */ }

// ❌ Testing business logic in controller test
@Test
fun `should calculate discount`() {
    // Business logic belongs in use case tests, not here
}

// ❌ Not testing error mapping
// Only testing happy path — missing validation and exception tests

// ❌ Hardcoded JSON without testing structure
mockMvc.perform(post("/api").content("{}"))
    .andExpect(status().isOk)  // No response body assertions!

// ❌ Missing @ActiveProfiles("test")
@WebMvcTest(MyController::class)  // May load wrong beans without profile
class MyControllerTest { /* ... */ }

// ❌ Duplicating shared header validation already in ControllerTest
@ParameterizedTest
@NullAndEmptySource
fun `should return 400 when platform header is missing`(platform: String?) { ... }
// ✅ Delete it — ControllerTest covers customerId, locale, platform for every controller

// ❌ Not extending ControllerTest
@ActiveProfiles("test")
@WebMvcTest(MyController::class)
class MyControllerTest { ... }  // ← misses inherited header tests and makeRequest() helper
// ✅ class MyControllerTest : ControllerTest() { ... }
```

## Verification

1. Test compiles: `./gradlew service:compileTestKotlin`
2. Test passes: `./gradlew service:test --tests '*{ControllerName}Test'`
3. Uses `@WebMvcTest` (not `@SpringBootTest`)
4. Use Case is mocked with `@MockkBean`
5. Covers at least: happy path, one validation error, one domain exception, unexpected error
6. No business logic assertions (only HTTP contract)

## Package Location

Place in: `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/`
