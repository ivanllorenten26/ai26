---
name: test-create-architecture-tests
description: Creates ArchUnit tests that enforce Clean Architecture layer rules for a module. Use once per module to automate architectural invariant checks in CI.
argument-hint: [module-name] to enforce layer dependency rules
---

# Create Architecture Tests

Generates a single ArchUnit test class for a module that codifies all Clean Architecture
layer invariants. **Idempotent** — if `ArchitectureTest.kt` already exists for the module,
print a message and stop without modifying anything.

---

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`test_source_root=service/src/test/kotlin`.

---

## Pre-flight check

Check whether `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/ArchitectureTest.kt` already exists.

- **Exists** → print `⊘ ArchitectureTest already exists for module {MODULE} — skipping.` and stop.
- **Does not exist** → proceed.

---

## Output

Generate exactly **one** file:

```
{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/ArchitectureTest.kt
```

---

## Generated file template

```kotlin
package {BASE_PACKAGE}.{module}

import com.tngtech.archunit.core.domain.JavaClasses
import com.tngtech.archunit.core.importer.ClassFileImporter
import com.tngtech.archunit.core.importer.ImportOption
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestInstance
import org.springframework.web.bind.annotation.RestController

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class ArchitectureTest {

    private lateinit var importedClasses: JavaClasses

    @BeforeAll
    fun importClasses() {
        importedClasses = ClassFileImporter()
            .withImportOption(ImportOption.DoNotIncludeTests())
            .importPackages("{BASE_PACKAGE}.{module}")
    }

    // Rule 1 — Domain must not depend on any framework
    @Test
    fun `domain layer does not depend on Spring, JPA or JOOQ`() {
        noClasses()
            .that().resideInAPackage("..{module}.domain..")
            .should().dependOnClassesThat()
            .resideInAnyPackage(
                "org.springframework..",
                "jakarta.persistence..",
                "org.jooq.."
            )
            .check(importedClasses)
    }

    // Rule 2 — Application layer only uses @Service and @Transactional
    @Test
    fun `application layer uses only @Service and @Transactional annotations`() {
        noClasses()
            .that().resideInAPackage("..{module}.application..")
            .should().dependOnClassesThat()
            .resideInAnyPackage(
                "jakarta.persistence..",
                "org.jooq..",
                "org.springframework.web..",
                "org.springframework.data.."
            )
            .check(importedClasses)
    }

    // Rule 3 — Infrastructure must use inbound/outbound sub-packages (nothing flat)
    @Test
    fun `infrastructure layer has no classes directly in infrastructure package`() {
        noClasses()
            .that().resideInAPackage("{BASE_PACKAGE}.{module}.infrastructure")
            .should().exist()
            .check(importedClasses)
    }

    // Rule 4a — Domain does not depend on application
    @Test
    fun `domain layer does not depend on application layer`() {
        noClasses()
            .that().resideInAPackage("..{module}.domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..{module}.application..")
            .check(importedClasses)
    }

    // Rule 4b — Domain does not depend on infrastructure
    @Test
    fun `domain layer does not depend on infrastructure layer`() {
        noClasses()
            .that().resideInAPackage("..{module}.domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..{module}.infrastructure..")
            .check(importedClasses)
    }

    // Rule 4c — Application does not depend on infrastructure
    @Test
    fun `application layer does not depend on infrastructure layer`() {
        noClasses()
            .that().resideInAPackage("..{module}.application..")
            .should().dependOnClassesThat()
            .resideInAPackage("..{module}.infrastructure..")
            .check(importedClasses)
    }

    // Rule 5 — Repository implementations live in outbound
    @Test
    fun `repository implementations reside in infrastructure outbound`() {
        classes()
            .that().implement(com.tngtech.archunit.core.domain.JavaClass.Predicates.simpleNameEndingWith("Repository"))
            .and().areNotInterfaces()
            .should().resideInAPackage("..{module}.infrastructure.outbound..")
            .check(importedClasses)
    }

    // Rule 6 — Controllers live in inbound
    @Test
    fun `REST controllers reside in infrastructure inbound`() {
        classes()
            .that().areAnnotatedWith(RestController::class.java)
            .should().resideInAPackage("..{module}.infrastructure.inbound..")
            .check(importedClasses)
    }
}
```

Replace `{BASE_PACKAGE}` and `{module}` with the resolved values for the target module.

---

## Substitution rules

| Placeholder | Value |
|---|---|
| `{BASE_PACKAGE}` | resolved from `ai26/config.yaml` → active module `base_package` |
| `{module}` | the module name argument (e.g. `chat`, `loans`) |

---

## After writing the file

Print:
```
✓ ArchitectureTest created at {TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/ArchitectureTest.kt

  Rules enforced:
    [1] Domain has no Spring/JPA/JOOQ imports
    [2] Application layer uses only @Service and @Transactional
    [3] Infrastructure has no flat classes (inbound/outbound required)
    [4a] Domain does not depend on application
    [4b] Domain does not depend on infrastructure
    [4c] Application does not depend on infrastructure
    [5] Repository implementations reside in infrastructure.outbound
    [6] @RestController classes reside in infrastructure.inbound

Run with: ./gradlew service:test --tests "{BASE_PACKAGE}.{module}.ArchitectureTest"
```

---

## Constraints

- Write only the single `ArchitectureTest.kt` file — no other files.
- Do not modify existing test infrastructure.
- The class must be a plain JUnit 5 test (no Spring context needed).
- ArchUnit dependency must already be present in the project's `build.gradle`.
  If it is missing, print a warning: `⚠ com.tngtech.archunit:archunit-junit5 not found in build.gradle — add it before running these tests.`
