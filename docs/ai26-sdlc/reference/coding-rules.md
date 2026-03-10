<!-- GENERATED from ai26/config.yaml + docs/coding-standards/recipes/rule-index.yaml
     Do not edit manually. Run: ./scripts/generate-coding-rules-doc.sh -->

# Coding Rules Reference

> Every rule has an ID. Use the ID when discussing violations in code review, in `ai26-review-user-story` output, and in CHECKS.md entries. The ID is stable — the rule text may be refined over time.

---

## How to use this document

- **Implementing a feature** → read the recipe linked in the "Recipe" column for the layer you are working in.
- **In code review** → reference the rule ID (e.g. `D-01`) so the discussion is unambiguous.
- **Updating a rule** → change `ai26/config.yaml` → `coding_rules`, then run `./scripts/generate-coding-rules-doc.sh` to regenerate this file.

---

## Clean Architecture (CC)

| ID | Rule | Recipe | Skills |
|---|---|---|---|
| CC-01 | Domain layer: zero framework imports (org.springframework.*, jakarta.*, org.jooq.*) | [`domain.md`](../../coding-standards/recipes/domain.md) | `dev-create-aggregate`, `dev-create-domain-entity`, `dev-create-value-object`, `dev-create-domain-service`, `dev-create-domain-event`, `ai26-review-user-story` |
| CC-02 | Infrastructure classes in inbound/ or outbound/ — nothing flat in infrastructure/ | [`infrastructure.md`](../../coding-standards/recipes/infrastructure.md), [`controllers.md`](../../coding-standards/recipes/controllers.md) | `dev-create-rest-controller`, `dev-create-jpa-repository`, `dev-create-jooq-repository`, `dev-create-api-client`, `dev-create-sqs-publisher`, `dev-create-sqs-subscriber`, `dev-create-kafka-publisher`, `dev-create-kafka-subscriber`, `ai26-review-user-story` |
| CC-03 | Either<DomainError, DTO> from de.tech26.valium.shared.kernel — never kotlin.Result, never arrow.core.Either | [`error-handling.md`](../../coding-standards/recipes/error-handling.md) | `dev-create-use-case`, `dev-create-domain-exception`, `ai26-review-user-story` |
| CC-04 | Repository/emitter ports: plain return types — nullable for not-found, throws for infra. Never Either on port signatures | [`repositories.md`](../../coding-standards/recipes/repositories.md), [`error-handling.md`](../../coding-standards/recipes/error-handling.md) | `ai26-review-user-story` |
| CC-05 | DTO fields: primitives only (String, Int, Long, Boolean, Double). UUID→String, Instant→String, enum→String(.name) | [`domain.md`](../../coding-standards/recipes/domain.md), [`use-cases.md`](../../coding-standards/recipes/use-cases.md), [`dto-design.md`](../../coding-standards/recipes/dto-design.md) | `dev-create-aggregate`, `dev-create-use-case`, `dev-create-rest-controller`, `ai26-review-user-story` |

---

## Domain (D)

| ID | Rule | Recipe | Skills |
|---|---|---|---|
| D-01 | Aggregate root: class with private constructor — NOT data class | [`domain.md`](../../coding-standards/recipes/domain.md) | `dev-create-aggregate`, `ai26-review-user-story` |
| D-02 | companion object with create() for new instances, from() for DB rehydration | [`domain.md`](../../coding-standards/recipes/domain.md) | `dev-create-aggregate`, `dev-create-domain-entity`, `ai26-review-user-story` |
| D-03 | init block with require() for constructor invariants only | [`domain.md`](../../coding-standards/recipes/domain.md), [`error-handling.md`](../../coding-standards/recipes/error-handling.md) | `dev-create-aggregate`, `dev-create-value-object`, `ai26-review-user-story` |
| D-04 | Mutations return new instances via private copy() — no var, no public setters | [`domain.md`](../../coding-standards/recipes/domain.md) | `dev-create-aggregate`, `dev-create-domain-entity`, `ai26-review-user-story` |
| D-05 | Business methods that can fail return Either<SealedError, Aggregate> — never throw | [`domain.md`](../../coding-standards/recipes/domain.md), [`error-handling.md`](../../coding-standards/recipes/error-handling.md) | `dev-create-aggregate`, `dev-create-domain-exception`, `ai26-review-user-story` |
| D-06 | Sealed error classes nested inside the aggregate | [`error-handling.md`](../../coding-standards/recipes/error-handling.md) | `dev-create-aggregate`, `dev-create-domain-exception`, `ai26-review-user-story` |
| D-07 | toDTO() for boundary crossing, toSnapshot() for domain events | [`domain.md`](../../coding-standards/recipes/domain.md), [`domain-events.md`](../../coding-standards/recipes/domain-events.md) | `dev-create-aggregate`, `dev-create-domain-event`, `ai26-review-user-story` |
| D-08 | ID value object: data class {Name}Id(val value: UUID) — NOT @JvmInline value class | [`domain.md`](../../coding-standards/recipes/domain.md) | `dev-create-aggregate`, `ai26-review-user-story` |
| D-09 | ID factory: random() — NOT new(), NOT generate() | [`domain.md`](../../coding-standards/recipes/domain.md) | `ai26-review-user-story` |
| D-10 | ID has fromString(raw: String) for parsing from HTTP/SQS input | [`domain.md`](../../coding-standards/recipes/domain.md), [`controllers.md`](../../coding-standards/recipes/controllers.md) | `dev-create-aggregate`, `dev-create-rest-controller`, `dev-create-sqs-subscriber`, `ai26-review-user-story` |
| D-11 | Value objects: @JvmInline value class for single-field wrappers, data class for multi-field or IDs | [`domain.md`](../../coding-standards/recipes/domain.md) | `dev-create-value-object`, `ai26-review-user-story` |
| D-12 | Status enum has behavior methods (isActive(), canBeCancelled()) — not just constants | [`domain.md`](../../coding-standards/recipes/domain.md) | `ai26-review-user-story` |
| D-13 | Cross-aggregate references by ID only — never embed another aggregate | [`domain.md`](../../coding-standards/recipes/domain.md), [`child-entities.md`](../../coding-standards/recipes/child-entities.md) | `dev-create-aggregate`, `dev-create-domain-entity`, `ai26-review-user-story` |
| D-14 | One Repository per aggregate root | [`repositories.md`](../../coding-standards/recipes/repositories.md), [`child-entities.md`](../../coding-standards/recipes/child-entities.md), [`use-cases.md`](../../coding-standards/recipes/use-cases.md) | `dev-create-aggregate`, `dev-create-jpa-repository`, `dev-create-jooq-repository`, `ai26-review-user-story` |

---

## Application (A)

| ID | Rule | Recipe | Skills |
|---|---|---|---|
| A-01 | Use case returns Either<SealedError, DTO> — never raw domain entities | [`use-cases.md`](../../coding-standards/recipes/use-cases.md), [`error-handling.md`](../../coding-standards/recipes/error-handling.md) | `dev-create-use-case`, `ai26-review-user-story` |
| A-02 | Entry point: operator fun invoke() with primitive parameters — no Command/DTO input objects | [`use-cases.md`](../../coding-standards/recipes/use-cases.md) | `dev-create-use-case`, `ai26-review-user-story` |
| A-03 | @Service and @Transactional | [`use-cases.md`](../../coding-standards/recipes/use-cases.md) | `dev-create-use-case`, `ai26-review-user-story` |
| A-04 | One aggregate per transaction | [`use-cases.md`](../../coding-standards/recipes/use-cases.md) | `ai26-review-user-story` |
| A-05 | No infrastructure imports | [`use-cases.md`](../../coding-standards/recipes/use-cases.md) | `dev-create-use-case`, `ai26-review-user-story` |
| A-06 | No try/catch for expected business outcomes — use Either from domain methods | [`use-cases.md`](../../coding-standards/recipes/use-cases.md), [`error-handling.md`](../../coding-standards/recipes/error-handling.md) | `dev-create-use-case`, `ai26-review-user-story` |

---

## Infrastructure (I)

| ID | Rule | Recipe | Skills |
|---|---|---|---|
| I-01 | Controllers are humble objects — delegate to use case, no business logic | [`controllers.md`](../../coding-standards/recipes/controllers.md) | `dev-create-rest-controller`, `ai26-review-user-story` |
| I-02 | Controllers fold Either directly — map Error to ApplicationException | [`controllers.md`](../../coding-standards/recipes/controllers.md), [`error-handling.md`](../../coding-standards/recipes/error-handling.md) | `dev-create-rest-controller`, `ai26-review-user-story` |
| I-03 | Request bodies have bean validation annotations (@field:NotBlank, etc.) | [`controllers.md`](../../coding-standards/recipes/controllers.md) | `dev-create-rest-controller`, `ai26-review-user-story` |
| I-04 | Outbound adapters: implementation prefix (Jooq, Jpa, Kafka, Sqs, Http, Stub, InMemory, Logging) | [`infrastructure.md`](../../coding-standards/recipes/infrastructure.md), [`outbound-adapters.md`](../../coding-standards/recipes/outbound-adapters.md) | `dev-create-jpa-repository`, `dev-create-jooq-repository`, `dev-create-api-client`, `dev-create-sqs-publisher`, `dev-create-sqs-subscriber`, `dev-create-kafka-publisher`, `dev-create-kafka-subscriber`, `ai26-review-user-story` |
| I-05 | Outbound adapters: runCatching for infra errors | [`infrastructure.md`](../../coding-standards/recipes/infrastructure.md), [`external-apis.md`](../../coding-standards/recipes/external-apis.md), [`messaging.md`](../../coding-standards/recipes/messaging.md) | `dev-create-jpa-repository`, `dev-create-jooq-repository`, `dev-create-api-client`, `dev-create-sqs-publisher`, `dev-create-kafka-publisher`, `ai26-review-user-story` |
| I-06 | Outbound adapters: @Retry where appropriate | [`infrastructure.md`](../../coding-standards/recipes/infrastructure.md), [`external-apis.md`](../../coding-standards/recipes/external-apis.md), [`messaging.md`](../../coding-standards/recipes/messaging.md) | `ai26-review-user-story` |

---

## Testing (T)

| ID | Rule | Recipe | Skills |
|---|---|---|---|
| T-01 | TestContainers only — never H2 | [`testing.md`](../../coding-standards/recipes/testing.md) | `test-create-use-case-tests`, `test-create-controller-tests`, `test-create-feature-tests`, `test-create-integration-tests`, `test-create-test-configuration`, `ai26-review-user-story` |
| T-02 | Mock only outbound ports — never domain entities or value objects | [`testing.md`](../../coding-standards/recipes/testing.md) | `test-create-use-case-tests`, `ai26-review-user-story` |
| T-03 | Mother Objects for test data — no inline construction in test bodies | [`testing.md`](../../coding-standards/recipes/testing.md), [`mother-objects.md`](../../coding-standards/recipes/mother-objects.md) | `test-create-use-case-tests`, `test-create-controller-tests`, `test-create-feature-tests`, `test-create-integration-tests`, `ai26-review-user-story` |
| T-04 | // Scenario: docstring on every @Test method | [`testing.md`](../../coding-standards/recipes/testing.md) | `ai26-review-user-story` |
| T-05 | Feature tests: @SpringBootTest(RANDOM_PORT) + TestRestTemplate, NOT MockMvc | [`testing.md`](../../coding-standards/recipes/testing.md) | `test-create-feature-tests`, `ai26-review-user-story` |
| T-06 | Feature tests: inject real repository adapter, NOT InMemory fakes | [`testing.md`](../../coding-standards/recipes/testing.md) | `test-create-feature-tests`, `ai26-review-user-story` |
| T-07 | Controller tests and feature tests are mandatory | [`testing.md`](../../coding-standards/recipes/testing.md) | `test-create-controller-tests`, `test-create-feature-tests`, `ai26-validate-user-story`, `ai26-review-user-story` |
| T-08 | @BeforeEach cleans DB state in feature tests | [`testing.md`](../../coding-standards/recipes/testing.md) | `test-create-feature-tests`, `ai26-review-user-story` |

---
