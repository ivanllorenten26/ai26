# Project Structure

Folder layout and package conventions for the `service/` module.

## Single-module by default

**N26 backend guild rule: services use a single Gradle module unless there is a documented, justified reason to split.**

A single module with well-named packages (`domain/`, `application/`, `infrastructure/`) gives you the same architectural separation as multiple modules, without the accidental complexity: no cross-module dependency wiring, no duplicated `build.gradle.kts` configurations, no `testFixtures` visibility issues, and simpler refactoring (moving a class between packages is a rename; moving between modules is a build reconfiguration).

ArchUnit enforces the dependency rule between packages at compile time — `domain/` cannot import from `infrastructure/`, `application/` cannot import from `infrastructure/` — with the same strength that Gradle enforces between modules. The guardrail is equivalent; the cost is lower.∫

### Current state of valium

valium has three Gradle modules today:

| Module | Status | Role |
|---|---|---|
| `service/` | **Active** — all new code goes here | The single module where these standards apply |
| `application/` | **Legacy** — do not modify unless explicitly asked | The original module being migrated away from |
| `persistence/` | introduced after creating the `service/` module, currently in progress | Holds shared database schema; will be absorbed into `service/` when the migration completes |

---

The folder structure directly encodes the architecture. A class in `domain/` has no framework imports. A class in `application/` orchestrates domain objects. A class in `infrastructure/inbound/` receives external input (HTTP, SQS, scheduled triggers) and typically delegates to a use case — unless the operation is pure infrastructure plumbing with no domain logic. A class in `infrastructure/outbound/` implements a domain port against a real database or external service. When you open any file, its folder tells you what it is allowed to do and what it is not allowed to import.

There is no `feature/` or `vertical-slice/` nesting. Everything is flat within each layer. This makes it easy to enforce the dependency rule: `domain/` never imports from `application/` or `infrastructure/`, `application/` never imports from `infrastructure/`. ArchUnit tests encode these rules and enforce them in CI.

---

## Source Structure

```
service/src/main/kotlin/de/tech26/valium/
├── {module}/                              # Bounded context (e.g. conversation, contact-center)
│   ├── domain/                            # Aggregates, entities, value objects, repository interfaces, domain events
│   │   ├── Conversation.kt               # Aggregate root (private constructor + companion create())
│   │   ├── ConversationId.kt             # Value object
│   │   ├── ConversationStatus.kt         # Enum / sealed class
│   │   ├── ConversationRepository.kt     # Repository interface (port)
│   │   └── errors/
│   │       └── ConversationError.kt      # Domain error sealed class
│   ├── application/                      # Use cases (@Service, @Transactional)
│   │   ├── CreateConversationUseCase.kt  # Use case returning Either<DomainError, DTO>
│   │   ├── CloseConversationUseCase.kt   # Use case returning Either<DomainError, DTO>
│   └── infrastructure/
│       ├── inbound/                       # Controllers, request/response DTOs
│       │   ├── ConversationController.kt
│       │   ├── CreateConversationRequest.kt
│       │   └── ConversationResponse.kt
│       └── outbound/                      # Repository implementations, external API clients
│           └── JooqConversationRepository.kt
└── shared/
    └── kernel/                            # Either<E,S>, shared value objects, base interfaces
```

The `shared/kernel/` package contains types that are genuinely shared across all modules: `Either`, base domain event interface, common value objects. It does not contain business logic. If you find yourself putting business rules in `shared/`, it is a sign those rules belong in a specific module's domain layer instead.

Package naming: `de.tech26.valium.{module}.{layer}` — no feature nesting inside packages.

No feature nesting means you will not see `de.tech26.valium.conversation.createConversation.domain`. Everything for the `conversation` module's domain layer is in `de.tech26.valium.conversation.domain`, regardless of how many use cases exist. This keeps the package tree flat and predictable, and prevents the layer from being silently bypassed by "convenience" classes placed outside the standard paths.

---

## Test Structure

```
service/src/test/kotlin/de/tech26/valium/
├── {module}/
│   ├── ArchitectureTest.kt               # ArchUnit layer rules
│   ├── ConversationFeatureTest.kt        # Full-stack BDD feature tests (TestRestTemplate + TestContainers)
│   ├── domain/                            # Mother Objects for the module
│   │   └── ConversationMother.kt
│   ├── application/                       # Use case tests (primary SUT)
│   │   └── CreateConversationUseCaseTest.kt
│   └── infrastructure/
│       ├── inbound/                       # Controller tests (@WebMvcTest) — mandatory
│       │   └── ConversationControllerTest.kt
│       └── outbound/                      # Integration tests (TestContainers)
│           └── JooqConversationRepositoryIntegrationTest.kt
└── config/                                # Shared test infrastructure
    ├── TestConfiguration.kt
    └── TestContainersConfig.kt
```

The test structure mirrors the source structure by layer. `application/` contains use case tests (mocks only). `infrastructure/inbound/` contains `@WebMvcTest` controller tests. `infrastructure/outbound/` contains TestContainers integration tests. `{FeatureName}FeatureTest.kt` at the module root contains full-stack BDD feature tests using `TestRestTemplate` and TestContainers.

The `ArchitectureTest.kt` at the module root (not inside a layer sub-package) is intentional: it tests the module as a whole, asserting that domain classes do not import from infrastructure, that use cases do not return infrastructure types, and so on. It is created once per module and should not be modified manually.

Mother Objects live in `domain/` within the test tree because they produce domain objects — their factory methods call the same `Conversation.create()` and `Order.confirm()` that production code uses. They are not mocks.

---

## Test Resources

```
service/src/test/resources/
└── application-test.yml                   # Test application configuration
```

> `.feature` files are **design artefacts only** — they live in `.features/{TICKET}/scenarios/` and are generated by `sdlc-design-feature`. They are **not** copied to `src/test/resources/`. Traceability is maintained via `// Scenario:` docstring comments in `*Test.kt` files, verified by `sdlc-validate-feature`.

---

## Package Naming Conventions

### By layer

```kotlin
// Domain
package de.tech26.valium.conversation.domain

// Application
package de.tech26.valium.conversation.application

// Infrastructure inbound
package de.tech26.valium.conversation.infrastructure.inbound

// Infrastructure outbound
package de.tech26.valium.conversation.infrastructure.outbound
```

### File naming

File naming follows the same predictability principle as package naming. Every type has exactly one canonical name pattern. If you open `CreateConversationUseCase.kt`, you know it is in `application/`, returns `Either`, and has a corresponding `CreateConversationUseCaseTest.kt`. If you open `JooqConversationRepository.kt`, you know it is in `infrastructure/outbound/`, implements `ConversationRepository`, and has a corresponding integration test. There are no naming exceptions.

| Type | Example |
|---|---|
| Aggregate root | `Conversation.kt` |
| Value object | `ConversationId.kt`, `ConversationStatus.kt` |
| Repository interface | `ConversationRepository.kt` |
| Domain error | `ConversationError.kt` |
| Use case | `CreateConversationUseCase.kt` |
| Input model | `CreateConversationCommand.kt` |
| Output model | `ConversationDto.kt` |
| Controller | `ConversationController.kt` |
| Request DTO | `CreateConversationRequest.kt` |
| Response DTO | `ConversationResponse.kt` |
| JOOQ adapter | `JooqConversationRepository.kt` |
| Use case test | `CreateConversationUseCaseTest.kt` |
| Controller test | `ConversationControllerTest.kt` |
| Integration test | `JooqConversationRepositoryIntegrationTest.kt` |
| Mother Object | `ConversationMother.kt` |
| Feature test | `ConversationFeatureTest.kt` |
