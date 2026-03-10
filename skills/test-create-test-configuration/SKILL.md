---
name: test-create-test-configuration
description: Creates shared test infrastructure including TestContainers setup, Spring test configuration, and test properties. Use when setting up a new service or module that needs integration test support.
argument-hint: [module-name] with [TestContainers, BDD context]
---

# Create Test Configuration

Creates shared test infrastructure: TestContainers setup, BDD context, Spring test configuration, and test properties.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`,
`test_fixtures_source_root=service/src/testFixtures/kotlin`.

## Task

Create test configuration files in:
- `{TEST_SRC}/{BASE_PACKAGE_PATH}/config/TestConfiguration.kt`
- `{TEST_SRC}/{BASE_PACKAGE_PATH}/config/TestContainersConfig.kt`
- `{TEST_RESOURCES}/application-test.yml`

> Feature tests use `TestRestTemplate` + `@SpringBootTest(RANDOM_PORT)` + TestContainers. This configuration provides the shared `TestContainersConfig` needed by those tests. See `test-create-feature-tests` for the BDD Gherkin docstring pattern.

## Implementation Rules

- ✅ Shared TestContainers config reused across all integration tests
- ✅ Fixed `Clock` for deterministic time-based tests
- ✅ `@ActiveProfiles("test")` everywhere
- ✅ Mother Objects pattern for test data (in each module's test package, not centralized)
- ❌ No centralized TestDataBuilders class — each module owns its Mother Objects
- ❌ No test SQL schemas here — use Flyway migrations
- ❌ No H2 — always TestContainers PostgreSQL
- ❌ No Cucumber dependencies — BDD uses Gherkin docstring comments in JUnit5 test methods

## Spring Test Configuration

```kotlin
package {BASE_PACKAGE}.config

import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary
import io.mockk.mockk
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

@TestConfiguration
class TestConfiguration {

    @Bean
    @Primary
    fun testClock(): Clock = Clock.fixed(
        Instant.parse("2024-01-01T12:00:00Z"),
        ZoneOffset.UTC
    )

    // Mock external services that should not be called in tests
    @Bean
    @Primary
    fun testEventPublisher(): ApplicationEventPublisher = mockk(relaxed = true)
}
```

## TestContainers Configuration

```kotlin
package {BASE_PACKAGE}.config

import org.springframework.boot.test.context.TestConfiguration
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container

@TestConfiguration
class TestContainersConfig {

    companion object {
        @Container
        @JvmStatic
        val postgres = PostgreSQLContainer("postgres:15")
            .withDatabaseName("valium_test")
            .withUsername("test_user")
            .withPassword("test_password")

        @DynamicPropertySource
        @JvmStatic
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", postgres::getJdbcUrl)
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
        }
    }
}
```

## Test Properties

```yaml
# {TEST_RESOURCES}/application-test.yml
spring:
  datasource:
    url: jdbc:tc:postgresql:15:///valium_test
    driver-class-name: org.testcontainers.jdbc.ContainerDatabaseDriver
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true
  flyway:
    enabled: true

logging:
  level:
    {BASE_PACKAGE}: DEBUG
    org.testcontainers: INFO
```

## Build Configuration

```kotlin
// service/build.gradle.kts — test dependencies

dependencies {
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")

    // TestContainers
    testImplementation("org.testcontainers:testcontainers")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")

    // Mocking
    testImplementation("io.mockk:mockk")
    testImplementation("com.ninja-squad:springmockk")

    // Assertions (AssertJ is included with spring-boot-starter-test)

}
```

## Mother Objects Pattern (per module)

Each module defines its own Mother Objects in the `testFixtures` source set, mirroring the domain package: `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/{module}/domain/`. Run `test-create-mother-object` to generate them.

> See `test-create-use-case-tests` for the full Mother Objects pattern with naming conventions, factory method examples, and usage in tests.

## Anti-Patterns

```kotlin
// ❌ Centralized TestDataBuilders with every domain type
object TestDataBuilders {
    fun anOrder() = ...
    fun aCustomer() = ...
    fun aConversation() = ...
    // Grows unbounded, couples all modules
}

// ✅ Per-module Mother Objects
object OrderMother { fun valid() = ... }      // in order module tests
object CustomerMother { fun valid() = ... }   // in customer module tests
```

```kotlin
// ❌ H2 in-memory database
@DataJpaTest  // defaults to H2

// ✅ Real PostgreSQL
@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
```

## Verification

1. `TestContainersConfig` starts PostgreSQL successfully
2. `application-test.yml` loads with `@ActiveProfiles("test")`
3. Tests run: `./gradlew service:test`

## Package Location

- Config: `{TEST_SRC}/{BASE_PACKAGE_PATH}/config/`
- Mother Objects: `{TEST_FIXTURES_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/` (testFixtures source set, mirroring domain package — use `test-create-mother-object`)
- Properties: `{TEST_RESOURCES}/application-test.yml`
