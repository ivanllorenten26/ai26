---
name: test-create-contract-tests
description: Generates WireMock-based contract tests for outbound HTTP client adapters. Use when you need to verify that an adapter correctly handles success, error, and timeout responses from an external service.
argument-hint: [AdapterName] in [module] testing [service endpoints]
---

# Create Contract Tests

Generates WireMock-based contract tests for outbound HTTP client adapters created by `dev-create-api-client`. Covers success, 4xx client error, 5xx server error, timeout, and retry scenarios. Use when you need confidence that an adapter correctly handles all response variants from an external service.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`test_source_root=service/src/test/kotlin`,
`test_fixtures_source_root=service/src/testFixtures/kotlin`.

## Task

Create WireMock contract tests for `{AdapterName}` in:

1. `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{serviceName}/{AdapterName}ContractTest.kt` — test class covering all response scenarios
2. `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/shared/test/ContractTest.kt` — composed annotation (create once; skip if already exists)
3. `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/shared/test/WireMockTestExtension.kt` — JUnit 5 extension for stub reset (create once; skip if already exists)
4. `{TEST_FIXTURES_RESOURCES}/mappings/{serviceName}/success.json` — WireMock stub: 200 response
5. `{TEST_FIXTURES_RESOURCES}/mappings/{serviceName}/client-error.json` — WireMock stub: 404 response
6. `{TEST_FIXTURES_RESOURCES}/mappings/{serviceName}/server-error.json` — WireMock stub: 500 response
7. `{TEST_FIXTURES_RESOURCES}/mappings/{serviceName}/timeout.json` — WireMock stub: delayed response beyond `readTimeout`

Files 2 and 3 are created once and reused across all contract test invocations.

## Implementation Rules

- ✅ Test class annotated with `@ContractTest` composed annotation
- ✅ Inject adapter under test via `@Autowired` — test the real Spring bean
- ✅ Four test categories: success path (verify `Either.Success`), 4xx (verify `Either.Error`), 5xx (verify exception propagates), retry (verify `wireMockServer.verify(N, ...)`)
- ✅ Stub JSON files in `{TEST_FIXTURES_RESOURCES}/mappings/{serviceName}/` — auto-loaded by `@AutoConfigureWireMock`
- ✅ Use AssertJ assertions: `assertThat(result).isInstanceOf(Either.Success::class.java)`
- ✅ `@ContractTest` is a composed annotation — do not repeat `@SpringBootTest` + `@AutoConfigureWireMock` individually on each test class
- ✅ `WireMockTestExtension` resets stubs after each test via `@AfterEach`
- ❌ No `@MockkBean` — contract tests use real HTTP over WireMock, not mocked ports
- ❌ No H2 or in-memory databases — use TestContainers if persistence is needed
- ❌ Do not hardcode WireMock port — use `@AutoConfigureWireMock(port = 0)` + `${wiremock.server.port}` in properties

### Required dependencies (add to `service/build.gradle.kts` if not present)
```kotlin
testImplementation(platform(libs.spring.cloud.dependencies))
testImplementation(libs.spring.cloud.contract.wiremock)
testFixturesImplementation(platform(libs.spring.boot.dependencies))
testFixturesImplementation(platform(libs.spring.cloud.dependencies))
testFixturesImplementation(libs.spring.boot.starter.test)
testFixturesImplementation(libs.spring.cloud.contract.wiremock)
```

## Example Implementation

### 1. Composed Annotation (`ContractTest.kt` — created once, in testFixtures)
```kotlin
package {BASE_PACKAGE}.shared.test

import org.junit.jupiter.api.extension.ExtendWith
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.cloud.contract.wiremock.AutoConfigureWireMock
import org.springframework.test.context.ActiveProfiles

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureWireMock(port = 0)
@ActiveProfiles("test")
@ExtendWith(WireMockTestExtension::class)
@Retention(AnnotationRetention.RUNTIME)
@Target(AnnotationTarget.CLASS)
annotation class ContractTest
```

### 2. WireMock Extension (`WireMockTestExtension.kt` — created once, in testFixtures)
```kotlin
package {BASE_PACKAGE}.shared.test

import com.github.tomakehurst.wiremock.WireMockServer
import org.junit.jupiter.api.extension.AfterEachCallback
import org.junit.jupiter.api.extension.ExtensionContext
import org.springframework.test.context.junit.jupiter.SpringExtension

class WireMockTestExtension : AfterEachCallback {

    override fun afterEach(context: ExtensionContext) {
        val appContext = SpringExtension.getApplicationContext(context)
        val wireMock = appContext.getBean(WireMockServer::class.java)
        wireMock.resetAll()
    }
}
```

### 3. Contract Test Class
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{serviceName}

import {BASE_PACKAGE}.{module}.domain.{ServiceName}Client
import {BASE_PACKAGE}.shared.kernel.Either
import {BASE_PACKAGE}.shared.test.ContractTest
import com.github.tomakehurst.wiremock.WireMockServer
import com.github.tomakehurst.wiremock.client.WireMock.exactly
import com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor
import com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

@ContractTest
class {AdapterName}ContractTest {

    @Autowired
    private lateinit var client: {ServiceName}Client

    @Autowired
    private lateinit var wireMockServer: WireMockServer

    @Test
    fun `returns Success when service responds 200`() {
        // WireMock stub loaded from mappings/{serviceName}/success.json
        val result = client.get{Resource}("existing-id")
        assertThat(result).isInstanceOf(Either.Success::class.java)
    }

    @Test
    fun `returns Error when service responds 404`() {
        // WireMock stub loaded from mappings/{serviceName}/client-error.json
        val result = client.get{Resource}("missing-id")
        assertThat(result).isInstanceOf(Either.Error::class.java)
    }

    @Test
    fun `propagates exception when service responds 500`() {
        // WireMock stub loaded from mappings/{serviceName}/server-error.json
        // @Retry will exhaust retries, then the exception propagates
        org.junit.jupiter.api.assertThrows<Exception> {
            client.get{Resource}("server-error-id")
        }
    }

    @Test
    fun `retries on 5xx before propagating`() {
        // stub returns 500 — verify retry count matches resilience4j config
        org.junit.jupiter.api.assertThrows<Exception> {
            client.get{Resource}("server-error-id")
        }
        wireMockServer.verify(exactly(3), getRequestedFor(urlEqualTo("/api/v1/{resource}/server-error-id")))
    }
}
```

### 4. Stub JSON files

**`mappings/{serviceName}/success.json`**
```json
{
  "request": {
    "method": "GET",
    "urlPattern": "/api/v1/{resource}/.*"
  },
  "response": {
    "status": 200,
    "headers": { "Content-Type": "application/json" },
    "jsonBody": {
      "id": "existing-id",
      "field1": "value1",
      "field2": "value2"
    }
  }
}
```

**`mappings/{serviceName}/client-error.json`**
```json
{
  "request": {
    "method": "GET",
    "url": "/api/v1/{resource}/missing-id"
  },
  "response": {
    "status": 404,
    "headers": { "Content-Type": "application/json" },
    "jsonBody": { "error": "not_found", "message": "Resource not found" }
  }
}
```

**`mappings/{serviceName}/server-error.json`**
```json
{
  "request": {
    "method": "GET",
    "url": "/api/v1/{resource}/server-error-id"
  },
  "response": {
    "status": 500,
    "headers": { "Content-Type": "application/json" },
    "jsonBody": { "error": "internal_error" }
  }
}
```

## Anti-Patterns

```kotlin
// ❌ Mocking the adapter instead of testing over real HTTP
@MockkBean
private lateinit var client: PaymentClient  // defeats the purpose of contract tests

// ❌ Repeating composed annotations — use @ContractTest
@SpringBootTest
@AutoConfigureWireMock(port = 0)
@ActiveProfiles("test")
class PaymentAdapterContractTest  // ← use @ContractTest instead

// ❌ Hardcoded WireMock port
@AutoConfigureWireMock(port = 8089)  // port collision risk
// ✅ port = 0 lets the OS assign a free port

// ❌ Placing stubs in wrong directory
src/test/resources/wiremock/  // won't be auto-loaded
src/test/resources/mappings/{serviceName}/  // test sources, not testFixtures
// ✅ Correct
src/testFixtures/resources/mappings/{serviceName}/
```

## Verification

1. Tests compile: `./gradlew service:compileKotlin`
2. Tests pass: `./gradlew service:test --tests "*{AdapterName}ContractTest"`
3. All 4 scenarios covered: success, 4xx, 5xx, retry count
4. Stub JSON files exist in `{TEST_FIXTURES_RESOURCES}/mappings/{serviceName}/`
5. `@ContractTest` composed annotation exists in `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/shared/test/`
6. No `@MockkBean` in contract test class

## Package Location

Test class: `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{serviceName}/`

Shared annotations (testFixtures): `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/shared/test/`

Stub files (testFixtures): `{TEST_FIXTURES_RESOURCES}/mappings/{serviceName}/`
