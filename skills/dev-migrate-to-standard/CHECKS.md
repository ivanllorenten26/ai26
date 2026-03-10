# CHECKS.md — migrate-to-standard check catalogue

This file defines all checks applied by the `migrate-to-standard` skill.
Each check has a stable ID, a description of the violation it detects, and a
reference to the atomic skill whose Implementation Rules or Anti-Patterns define
the expected pattern.

---

## Domain Layer — D01–D07

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| D01 | D-01 | Aggregate root is declared as `class` with `private constructor` — NOT `data class` | `create-aggregate` |
| D02 | D-02 | Has a `companion object` containing `fun create(` and/or `fun from(` | `create-aggregate` |
| D03 | D-04 | All constructor properties are `val` (no `var` in the primary constructor parameter list) | `create-aggregate` |
| D04 | D-03 | Has an `init` block with at least one `require(` or `check(` call | `create-aggregate` |
| D05 | D-07 | Has a `fun toDTO()` method | `create-aggregate` |
| D06 | CC-01 | Zero framework imports: no `org.springframework.*`, `jakarta.*`, or `org.jooq.*` | `create-aggregate` |
| D07 | D-14 | Repository and EventEmitter interfaces are declared inside `domain/` (not inside `infrastructure/`) | `create-domain-event` |

### Detection rules

**D01** — FAIL if file contains `data class {ClassName}` where `{ClassName}` is the aggregate root.

**D02** — FAIL if file does not contain `companion object` OR companion object does not contain `fun create(` or `fun from(`.

**D03** — FAIL if there is a `var ` declaration among the primary constructor parameters (between `private constructor(` and the matching `)` of the constructor).

**D04** — FAIL if file does not contain an `init {` block, OR the `init` block contains neither `require(` nor `check(`.

**D05** — FAIL if file does not contain `fun toDTO()`.

**D06** — FAIL if file contains any import matching `org.springframework`, `jakarta.persistence`, or `org.jooq`.

**D07** — FAIL if a `*Repository` or `*EventEmitter` interface is located in an `infrastructure/` package.

---

## Domain Errors — E01–E02

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| E01 | D-06 | Error class uses `sealed class` — NOT `sealed interface`, NOT `enum class` | `create-domain-exception` |
| E02 | D-06 | File is located in a `domain/errors/` package | `create-domain-exception` |

### Detection rules

**E01** — FAIL if the primary declaration is `sealed interface` or `enum class` (the skill requires `sealed class`).

**E02** — FAIL if the file path does not contain `domain/errors/`.

---

## Application Layer — A01–A06

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| A01 | A-01, CC-03 | Returns `Either<…, …>` — NOT `Result<…,…>` or nullable | `create-use-case` |
| A02 | A-02 | Entry point is `operator fun invoke(` | `create-use-case` |
| A03 | A-02 | Parameters of `invoke` are primitives (`String`, `Int`, `Long`, `UUID`, `Boolean`) — NOT Command/DTO input objects | `create-use-case` |
| A04 | A-03 | Annotated with `@Service` and `@Transactional` | `create-use-case` |
| A05 | A-05 | No imports from `infrastructure.*` | `create-use-case` |
| A06 | A-01 | The sealed error class referenced in `Either` exists in `domain/errors/` | `create-use-case` |

### Detection rules

**A01** — FAIL if `operator fun invoke(` return type does not contain `Either<`. FAIL if return type contains `Result<` (Kotlin stdlib Result or a custom Result type).

**A02** — FAIL if file does not contain `operator fun invoke(`.

**A03** — WARN if `invoke` parameter types end in `Command`, `Request`, `Input`, or `DTO` (input value objects are a design smell per project conventions).

**A04** — FAIL if file does not contain `@Service`. FAIL if file does not contain `@Transactional`.

**A05** — FAIL if file imports any symbol from a package containing `.infrastructure.`.

**A06** — WARN if the error class name extracted from `Either<{ErrorClass}, …>` cannot be found under `domain/errors/` of the same module.

---

## Infrastructure Inbound — I01–I03

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| I01 | CC-02 | File is in `infrastructure/inbound/` — NOT flat `infrastructure/` | `create-rest-controller` |
| I02 | I-01 | Controller is a humble object: delegates immediately to a use case, no own state | `create-rest-controller` |
| I03 | I-01 | No business logic: no `if`/`when` branching on domain state inside handler methods | `create-rest-controller` |

### Detection rules

**I01** — FAIL if a `@RestController` or `@Controller` file is not inside a path containing `infrastructure/inbound/`.

**I02** — WARN if the controller declares any `private val` field that is not a use case (i.e., not ending in `UseCase`).

**I03** — WARN if handler methods contain `when (` or `if (` targeting a domain type (heuristic: when-branch referencing a sealed class from `domain/`).

---

## Infrastructure Outbound — O01–O03

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| O01 | CC-02 | File is in `infrastructure/outbound/` | repos/emitters skills |
| O02 | D-14 | Class implements an interface from `domain/` | `create-aggregate` |
| O03 | I-04 | Class name has an implementation-prefix: `InMemory`, `Jpa`, `Jooq`, `Logging`, `Sqs`, `Kafka`, `Http`, `Stub` | team convention |

### Detection rules

**O01** — FAIL if a repository/emitter implementation file is not inside a path containing `infrastructure/outbound/`.

**O02** — FAIL if the class declaration does not contain `: {DomainInterface}` (i.e., there is no `: {Name}Repository` or `: {Name}EventEmitter` in the class header).

**O03** — WARN if the class name does not start with one of the recognised implementation prefixes.

---

## BDD Tests — B01–B05

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| B01 | T-01, T-05 | Uses `@Testcontainers` and `@SpringBootTest(webEnvironment = RANDOM_PORT)` | `create-feature-tests` |
| B02 | T-05 | Injects `TestRestTemplate`, NOT `MockMvc` | `create-feature-tests` |
| B03 | T-06 | Injects the real repository adapter (e.g., `Jooq*Repository`), NOT an `InMemory*` fake | `create-feature-tests` |
| B04 | T-08 | Has a `@BeforeEach` method that cleans DB state | `create-feature-tests` |
| B05 | T-04 | Each `@Test` method has a `// Scenario:` docstring comment | `create-feature-tests` |

### Detection rules

**B01** — FAIL if a `*FeatureTest.kt` file does NOT contain `@Testcontainers` or does NOT contain `webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT`.

**B02** — FAIL if a `*FeatureTest.kt` file injects `MockMvc` instead of `TestRestTemplate`.

**B03** — FAIL if a `*FeatureTest.kt` file injects an `InMemory*Repository` instead of the real infrastructure adapter.

**B04** — WARN if no `@BeforeEach` method that resets DB state (e.g., calls `deleteAll()` or similar) is found in the `*FeatureTest.kt` (risk of test pollution).

**B05** — WARN if a `@Test` method in a `*FeatureTest.kt` does not start with a `// Scenario:` comment line (missing traceability to design artefact).

---

## Use Case Tests — U01–U03

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| U01 | T-02 | Mocks only repository/gateway ports — never domain entities or value objects | `create-use-case-tests` |
| U02 | T-03 | Uses Mother Objects for test data (no inline object construction in test bodies) | `create-use-case-tests` |
| U03 | CC-03 | Asserts `Either.Success` / `Either.Error` with specific subtypes | `create-use-case-tests` |

### Detection rules

**U01** — WARN if `mockk<{DomainClass}>()` appears where `{DomainClass}` does not end in `Repository`, `EventEmitter`, `Gateway`, or `Client`.

**U02** — WARN if test bodies construct domain objects inline (heuristic: `{AggregateName}(` or `{AggregateName}.create(` directly inside a `@Test` function body rather than delegating to a Mother Object).

**U03** — FAIL if test assertions use `assertEquals` or `assertThat` on the raw `Either` without pattern-matching the `Either.Success` or `Either.Error` subtypes (heuristic: `assert.*Either` without `is Either.Success` or `is Either.Error`).

**U04** — WARN if test assertions use `assert(result is Either)` without checking the specific subtype (should use `assertThat(result).isInstanceOf(Either.Success::class.java)` or cast + field checks).

**U05** — WARN if test accesses error variants via `(result as Either.Error).value` without a subsequent type check on the variant subtype.

**U06** — WARN if a repository mock is created with `relaxed = true` and no explicit `every { … } returns …` configuration (risk of silent green tests).

**U07** — WARN if Mother Object functions have required (non-default) parameters for structural fields like `id`, `createdAt`, or `status` (should have sensible defaults).

---

## Domain Layer Extensions — D08–D11

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| D08 | D-08 | ID value object uses `data class {Name}Id(val value: UUID)` — NOT `@JvmInline value class` | `create-aggregate` |
| D09 | CC-05 | DTO fields are primitives or serializable types only — no domain types, enums as `String`, no value objects | `create-aggregate` |
| D10 | D-04 | Aggregate body contains no `var` property declarations (outside constructor) | `create-aggregate` |
| D11 | D-12 | Status enum (when present) has at least one behaviour method — NOT just constants | `create-aggregate` |

### Detection rules

**D08** — FAIL if an `{AggregateName}Id` class is declared as `@JvmInline value class` instead of `data class`.

**D09** — WARN if a `*DTO` or `*Dto` data class contains a field whose type matches a domain enum, value object, or aggregate root from the same module (instead of the primitive/string representation).

**D10** — FAIL if the aggregate class body (after the constructor closing `)`) contains a `var ` property declaration.

**D11** — WARN if a `*Status` or `*State` enum in `domain/` contains only enum constants and no methods (missed opportunity to encode state machine behaviour).

---

## Domain Events — DE01–DE06

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| DE01 | D-04 | Event data class has only `val` fields — no `var` | `create-domain-event` |
| DE02 | — | Event class name is in past tense — NOT imperative or present tense | `create-domain-event` |
| DE03 | I-04 | Event emitter implementation has a transport prefix (`Logging*`, `Sqs*`, `Kafka*`, `Stub*`) — NOT same name as the interface | `create-domain-event` |
| DE04 | CC-02 | Event emitter interface is in `domain/` — implementation is in `infrastructure/outbound/` | `create-domain-event` |
| DE05 | — | Emitter `emit()` parameter is a domain event data class — NOT an aggregate root | `create-domain-event` |
| DE06 | — | Aggregate root that emits events has a `domainEvents` list for collected events | `create-aggregate` |

### Detection rules

**DE01** — FAIL if the event data class contains any `var` property.

**DE02** — WARN if the event class name ends with a present-tense or imperative verb: `Create`, `Update`, `Delete`, `Send`, `Process`, `Start`, `Stop`, or ends in `Command` (should be past tense: `Created`, `Updated`, `Closed`).

**DE03** — FAIL if a class that implements `{EventName}Emitter` has the exact same name as the interface (i.e., class `ConversationClosedEmitter` implementing `ConversationClosedEmitter` — name clash).

**DE04** — FAIL if the `{EventName}Emitter` interface file is inside `infrastructure/` rather than `domain/`. FAIL if the implementation class is inside `domain/` rather than `infrastructure/outbound/`.

**DE05** — FAIL if an `{EventName}Emitter` interface's `emit()` method parameter type matches an aggregate root (heuristic: a class in `domain/` with `private constructor` and `companion object`) rather than a domain event data class. The emitter must receive the domain event, not the aggregate. Fix: change signature to `emit(event: {EventName})`.

**DE06** — WARN if an aggregate root's business method invokes an `*Emitter` dependency directly (instead of registering events in a `_domainEvents` list and letting the use case drain them). Also WARN if an aggregate root references event emission but does not declare a `val domainEvents` property — the collected events pattern requires the aggregate to accumulate events internally.

---

## Domain Exceptions Extensions — E03–E05

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| E03 | — | Thrown domain exceptions extend `RuntimeException` — NOT checked `Exception` | `create-domain-exception` |
| E04 | — | Application exceptions extend `ValiumApplicationException` — NOT `RuntimeException` directly | `create-domain-exception` |
| E05 | D-06 | Sealed error variants include context fields (ID, reason) — NOT only a bare `message: String` | `create-domain-exception` |

### Detection rules

**E03** — FAIL if a class in `domain/` ending in `Exception` extends `Exception` directly (checked) instead of `RuntimeException`.

**E04** — FAIL if a class in `application/errors/` ending in `ApplicationException` does NOT extend `ValiumApplicationException`.

**E05** — WARN if a `data class` variant inside a sealed error class contains only a single `message: String` field and no ID or context field (should carry actionable context like the aggregate ID or invalid value).

---

## Application Layer Extensions — A07

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| A07 | A-06 | Use case does NOT wrap domain method calls in `try/catch` for expected business outcomes | `create-use-case` |

### Detection rules

**A07** — WARN if the use case body contains a `try {` block that catches a domain exception (a class ending in `Exception` from `domain/`) and maps it to `Either.Error(…)`. Expected business outcomes should be modelled as `Either` returns from the domain method — not as exceptions caught at the use case level.

---

## Infrastructure Inbound Extensions — I04–I06

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| I04 | I-01 | Controller handler methods call the use case with primitives and receive a DTO — NOT a domain aggregate | `create-rest-controller` |
| I05 | I-02 | Controller maps errors by throwing `*ApplicationException` — NOT constructing a custom `ErrorResponse` inline | `create-rest-controller` |
| I06 | I-03 | Request body classes have bean validation annotations (`@field:NotBlank`, `@field:NotNull`, `@field:Valid`) — NOT bare unvalidated fields | `create-rest-controller` |

### Detection rules

**I04** — WARN if a controller handler method contains direct property access on what appears to be an aggregate root (heuristic: accessing `.status`, `.id`, `.createdAt` on a variable that is not typed as `*DTO` or `*Dto`).

**I05** — WARN if a controller file declares a `data class` or `class` named `*ErrorResponse`, `*Error`, or `*Problem` inline (error responses should be handled by `ValiumApplicationException` and a global handler, not per-controller response classes).

**I06** — WARN if a `*Request` or `*RequestBody` data class in the controller file contains `val property: String` fields without any `@field:` annotation (missing input validation at the HTTP boundary).

---

## BDD Tests Extensions — B06

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| B06 | T-04 | Each `@Test` method in `*FeatureTest.kt` and `*UseCaseTest.kt` starts with a `// Scenario:` docstring comment | `create-feature-tests`, `create-use-case-tests` |

### Detection rules

**B06** — WARN if a `@Test` method in a `*FeatureTest.kt` or `*UseCaseTest.kt` does not start with a `// Scenario:` comment line (missing business-language description of what the test covers).

---

## Architecture Tests — AR01–AR02

| ID  | Convention | Check | Source skill |
|-----|-----------|-------|--------------|
| AR01 | CC-01, CC-02 | `ArchitectureTest.kt` exists for the module | `create-architecture-tests` |
| AR02 | CC-01, CC-02 | `ArchitectureTest.kt` covers the 6 core invariants | `create-architecture-tests` |

### Detection rules

**AR01** — FAIL if no file matching `ArchitectureTest.kt` exists under `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/`.

**AR02** — WARN if `ArchitectureTest.kt` is missing any of the following patterns (each represents one invariant):
- `domain` + `spring` or `springframework` (domain isolation check)
- `application` + `@Service` or `@Transactional` (application annotation check)
- `inbound` (controller placement check)
- `outbound` (repository placement check)
- `infrastructure` + `domain` (no infrastructure → domain import check)
- `cycle` or `cycles` (no-cycle check)
