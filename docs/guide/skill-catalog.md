# Skill Catalog

One entry per skill: name, description, when to use, and category. Grouped by category.

All skills are invoked in Claude Code with `/{skill-name} [arguments]`. Run `/ai26-start-sdlc` when you are not sure which skill to use — it routes to the right one.

---

## SDLC Orchestration

These skills manage the end-to-end software development lifecycle. They are the entry points for all work.

---

### `ai26-start-sdlc`

**Description:** The universal entry point. Reads a Jira ticket ID (or prompts you for one), evaluates the context, and routes to the correct flow (Flow A/B/C) with the right skill.

**When to use:** Always start here unless you are resuming a known in-progress flow. Also use `/ai26-start-sdlc --check` to verify your environment setup.

**Usage:**
```
/ai26-start-sdlc                    — interactive: asks what you want to start
/ai26-start-sdlc SXG-1234           — start or resume from a specific ticket
/ai26-start-sdlc --check            — verify setup (config, context files, Jira MCP)
/ai26-start-sdlc SXG-1234 --backfill — generate artefacts from existing code
```

---

### `ai26-write-prd`

**Description:** Co-authors a Product Requirements Document for an epic. Leads a structured conversation with the PM (or engineer acting as PM) to capture business problem, goals, constraints, success metrics, and out-of-scope items. Produces `ai26/epics/{EPIC-ID}/prd.md`.

**When to use:** At the start of Flow A (epic flow), before running `ai26-design-epic`. Requires a Jira epic ID.

**Usage:**
```
/ai26-write-prd EPIC-123
```

---

### `ai26-design-epic`

**Description:** Designs an entire epic as one coherent block, then slices it into implementable tickets. Runs five internal phases: load context → architecture conversation → monolithic design → ticket decomposition → Jira materialisation. Replaces the deprecated `ai26-design-epic-architecture` + `ai26-decompose-epic` sequence.

**When to use:** Flow A, after the PRD is approved. The central planning skill for multi-ticket initiatives.

**Usage:**
```
/ai26-design-epic EPIC-123
```

Re-entrant: if interrupted, re-run to resume from the last completed phase.

---

### `ai26-design-ticket`

**Description:** Runs a full design conversation for a standalone ticket, producing the complete artefact set: domain model, use cases, API contracts, events, error catalog, Gherkin scenarios, and ops checklist. Supports fidelity 1 (minimal artefacts for bug fixes) and fidelity 2 (full artefacts for features).

**When to use:** Flow B — standalone tickets that were not part of an epic designed with `ai26-design-epic`. This is the most commonly used design skill for day-to-day ticket work.

**Usage:**
```
/ai26-design-ticket SXG-1234              — fidelity 2 (default, full artefacts)
/ai26-design-ticket SXG-1234 --fidelity 1 — fidelity 1 (minimal artefacts, bug fixes)
```

---

### `ai26-implement-user-story`

**Description:** Implements a ticket from its design artefacts. Reads `ai26/features/{TICKET}/`, proposes an implementation plan, implements autonomously using the `dev-create-*` and `test-create-*` scaffolding skills, then runs validation automatically. Used for both Flow A tickets (from `ai26-design-epic`) and Flow B tickets (from `ai26-design-ticket`).

**When to use:** After design artefacts are committed and approved. The primary implementation skill.

**Usage:**
```
/ai26-implement-user-story SXG-1234
```

Re-entrant: detects partial implementation and continues from where it stopped.

---

### `ai26-validate-user-story`

**Description:** Verifies three things: (1) every element in the design artefacts has a corresponding implementation, (2) every Gherkin scenario has a test and all tests pass, (3) every Jira acceptance criterion has a scenario. Runs automatically at the end of `ai26-implement-user-story` but can also be run manually.

**When to use:** Automatically triggered after implementation. Run manually after making changes outside the implementation flow, or to check status mid-development.

**Usage:**
```
/ai26-validate-user-story SXG-1234
```

---

### `ai26-review-user-story`

**Description:** Automated first-pass code review. Checks architectural compliance against all coding rules (CC-01 through T-08), naming conventions, error handling patterns, and artefact-to-code coherence. Produces a structured report with violations labelled by rule ID.

**When to use:** After validation passes, before promotion and before opening a PR.

**Usage:**
```
/ai26-review-user-story SXG-1234
```

---

### `ai26-promote-user-story`

**Description:** The Compound step. Merges feature artefacts from `ai26/features/{TICKET}/` into `docs/architecture/modules/{module}/`, indexes ADRs, proposes `ai26/context/` updates for confirmation, and handles epic promotion if this is the last ticket in an epic. Blocked if there are unresolved blocking validation violations.

**When to use:** After validation passes and review is complete. The last step before opening a PR. Do not skip this — it is what makes the loop compound.

**Usage:**
```
/ai26-promote-user-story SXG-1234
```

---

### `ai26-implement-fix`

**Description:** Flow C — direct implementation without a design phase. For typos, dependency bumps, config changes, and obvious single-file bugs. Reads the ticket and `DEBT.md`, evaluates escalation triggers (touches >3 files non-trivially, requires a migration, touches a DEBT.md `alto` area), implements if safe, and auto-escalates to `ai26-design-ticket --fidelity 1` if complexity is detected.

**When to use:** Quick fixes only. When in doubt, use `ai26-design-ticket` instead.

**Usage:**
```
/ai26-implement-fix SXG-999
```

---

### `ai26-refine-user-story`

**Description:** Lightweight artefact editor. Makes targeted changes to committed design artefacts — corrects an error type, adds a missing use case, adjusts an HTTP status code — without re-running the full design conversation. Validates cross-references after edits.

**When to use:** When artefacts need small corrections after they were approved. More surgical than re-running the full design.

**Usage:**
```
/ai26-refine-user-story SXG-1234
```

---

### `ai26-backfill-user-story`

**Description:** Generates design artefacts retroactively from existing code. Used when code was written without going through the design phase and you need artefacts for validation, promotion, or context updates.

**When to use:** Only as a corrective measure for code written outside the AI26 flow. Routinely using this skill indicates the Compound Loop is not running. The `--backfill` flag on `ai26-start-sdlc` calls this automatically.

**Usage:**
```
/ai26-backfill-user-story SXG-1234
```

---

### `ai26-sync-context`

**Description:** Detects divergence between `ai26/context/` files and the actual state of the codebase. Proposes corrections to close the gap. Does not modify code — only updates context files with explicit confirmation.

**When to use:** When design conversations produce outdated domain models, or periodically as a hygiene check (recommended monthly for active teams). Tech lead responsibility.

**Usage:**
```
/ai26-sync-context
```

---

## Team and Project Setup

---

### `ai26-onboard-team`

**Description:** Guides a tech lead through the full AI26 setup for a new team or codebase: creates `ai26/config.yaml`, initialises all five `ai26/context/` files, installs skills, and verifies the configuration. For existing codebases, helps bootstrap context from the existing code.

**When to use:** Once, when a new team adopts AI26. Also useful when adding AI26 to a pre-existing codebase.

**Usage:**
```
/ai26-onboard-team
```

---

## Compound Feedback

These skills capture what went wrong during any SDLC step and graduate resolved observations
to permanent institutional memory. Use them whenever AI output is wrong — instead of
manually fixing the result, capture the observation so the context improves.

---

### `ai26-compound`

**Description:** Observe-only feedback capture. When an AI agent produces wrong output at any SDLC checkpoint (design, implementation, review, PR feedback, or a production incident), this skill records the observation in `ai26/features/{TICKET}/COMPOUND.md`. It asks what went wrong, which step produced it, what type of fix is needed, and what should have happened instead. Does not modify any artefact, context file, or code.

**When to use:** Immediately whenever the engineer spots something wrong with AI26 output. Invoke before applying corrections so the observation is not lost.

**Usage:**
```
/ai26-compound SXG-1234
```

---

### `ai26-compound-resolve`

**Description:** Graduation skill. Processes resolved observations from a ticket's `COMPOUND.md`, archives each to the permanent `ai26/context/LEARNINGS.md` record, and optionally proposes a `CLAUDE.md` rule for systemic fixes. Future agents read `LEARNINGS.md` to avoid repeating the same mistakes.

**When to use:** After applying corrections and re-running the affected SDLC step successfully. Run before `ai26-promote-user-story` — promotion is blocked if pending observations remain.

**Usage:**
```
/ai26-compound-resolve SXG-1234
```

---

## Migration

These skills handle the migration of existing modules that were built without AI26 conventions.

---

### `ai26-assess-module`

**Description:** Produces a structured assessment of an existing module: architectural violations against coding rules, missing test coverage, context file gaps, and a risk-classified debt inventory. The starting point for any migration plan.

**When to use:** Before beginning a migration. Run once per module being assessed.

**Usage:**
```
/ai26-assess-module service
```

---

### `ai26-write-migration-prd`

**Description:** Produces a migration PRD defining the scope, goals, constraints, and success criteria for migrating a module to AI26 conventions. Similar to `ai26-write-prd` but for technical goals rather than product features.

**When to use:** After `ai26-assess-module` produces the assessment. Before decomposing the migration into tickets.

**Usage:**
```
/ai26-write-migration-prd service
```

---

### `ai26-decompose-migration`

**Description:** Breaks a migration PRD into implementable tickets, sequenced correctly (schema changes before code changes, high-risk debt addressed early). Creates Jira tickets.

**When to use:** After the migration PRD is approved. Produces the ticket backlog for the migration.

**Usage:**
```
/ai26-decompose-migration service
```

---

## Dev Scaffolding

These skills generate code scaffolding for specific architectural elements. They are called automatically by `ai26-implement-user-story`, but can also be invoked directly when you need to create a specific element outside the full ticket flow.

---

### `dev-create-aggregate`

**Description:** Scaffolds a new aggregate root: `class` with private constructor, `companion object` with `create()` and `from()` factory methods, `init` block with `require()` invariants, business methods returning `Either`, `toDTO()`, and `toSnapshot()`.

**When to use:** When a new aggregate root is introduced. Called automatically by `ai26-implement-user-story` when `domain-model.yaml` has a `status: new` aggregate entry.

**Usage:**
```
/dev-create-aggregate Conversation
```

---

### `dev-create-use-case`

**Description:** Scaffolds a use case class: `@Service @Transactional`, `operator fun invoke()` with primitive parameters, `Either<DomainError, DTO>` return type, repository injection as port interface.

**When to use:** When a new use case is introduced. Called automatically by `ai26-implement-user-story`.

**Usage:**
```
/dev-create-use-case CloseConversation
```

---

### `dev-create-rest-controller`

**Description:** Scaffolds a REST controller: humble object pattern, nested `RequestDto` and `ResponseDto`, `Either` folding to `ResponseStatusException`, `@Operation` annotations, bean validation on request bodies.

**When to use:** When a new REST endpoint is introduced. Called automatically by `ai26-implement-user-story` when `api-contracts.yaml` has new endpoints.

**Usage:**
```
/dev-create-rest-controller ConversationController
```

---

### `dev-create-value-object`

**Description:** Scaffolds a value object following team conventions: `@JvmInline value class` for single-field wrappers, `data class {Name}Id(val value: UUID)` for IDs.

**When to use:** When a new value object is needed.

**Usage:**
```
/dev-create-value-object Email
/dev-create-value-object ConversationId --id
```

---

### `dev-create-domain-event`

**Description:** Scaffolds the full domain event infrastructure for an aggregate: sealed event class, aggregate snapshot class (primitives only), emitter port interface, outbox emitter implementation, Protobuf mapper.

**When to use:** When a new domain event is introduced for an aggregate.

**Usage:**
```
/dev-create-domain-event ConversationClosed --aggregate Conversation
```

---

### `dev-create-jooq-repository`

**Description:** Scaffolds a JOOQ repository adapter: implements the domain repository port, uses `DSLContext`, private `toDomain()` and `toJooq()` extension functions, correct table naming per `ai26/config.yaml` `tablePrefix`.

**When to use:** When a new repository implementation is needed. Called automatically by `ai26-implement-user-story`.

**Usage:**
```
/dev-create-jooq-repository Conversation
```

---

### `dev-create-domain-entity`

**Description:** Scaffolds a child entity inside an existing aggregate boundary. Not for new aggregate roots — use `dev-create-aggregate` for those.

**When to use:** When adding a subordinate entity to an existing aggregate root. Called automatically by `ai26-implement-user-story` when `domain-model.yaml` has a `status: new` child entity entry.

**Usage:**
```
/dev-create-domain-entity Message inside Conversation
```

---

### `dev-create-domain-service`

**Description:** Scaffolds a stateless domain service for business logic that spans multiple aggregates and does not naturally belong to a single entity or value object.

**When to use:** When cross-aggregate logic needs a home in the domain layer.

**Usage:**
```
/dev-create-domain-service ConversationAssignmentPolicy
```

---

### `dev-create-domain-exception`

**Description:** Creates the correct error type for a business rule violation — thrown domain exception, `Either` sealed error, or application exception — following ADR 2026-01-27.

**When to use:** When a domain entity or use case needs to signal a business rule violation.

**Usage:**
```
/dev-create-domain-exception ConversationAlreadyClosed
```

---

### `dev-create-jpa-repository`

**Description:** Scaffolds a JPA repository implementation in `infrastructure/outbound` for standard CRUD operations. Use when simple database operations are sufficient and JOOQ is not needed.

**When to use:** When a new repository adapter needs a Spring Data JPA implementation. Called automatically by `ai26-implement-user-story`.

**Usage:**
```
/dev-create-jpa-repository Conversation
```

---

### `dev-create-flyway-migration`

**Description:** Scaffolds a Flyway SQL migration file with TODO markers for human review. Supports `CREATE TABLE` (from domain model) and `ALTER TABLE` (add column, index, constraint).

**When to use:** When a feature needs database schema changes. Called automatically by `ai26-implement-user-story` when `domain-model.yaml` has schema changes.

**Usage:**
```
/dev-create-flyway-migration create-table Conversation
/dev-create-flyway-migration alter-table Conversation --add agent_id:UUID
```

---

### `dev-create-kafka-publisher`

**Description:** Scaffolds an outbound Kafka publisher for a domain event using `KafkaTemplate<String, ByteArray>` and Jackson. Follows the sopranium pattern — one topic per aggregate, sealed class variants per transition.

**When to use:** When the module needs to produce messages to a Kafka topic. Called automatically by `ai26-implement-user-story` when `events.yaml` has `direction: outbound` Kafka entries.

**Usage:**
```
/dev-create-kafka-publisher ConversationClosed
```

---

### `dev-create-kafka-subscriber`

**Description:** Scaffolds an inbound Kafka listener adapter as a humble object that delegates to a use case, with `ExponentialBackOff` retry and manual acknowledgment.

**When to use:** When the module needs to consume messages from a Kafka topic.

**Usage:**
```
/dev-create-kafka-subscriber AgentAssigned
```

---

### `dev-create-sqs-publisher`

**Description:** Scaffolds an outbound SQS publisher adapter with domain port, `SqsTemplate`, `@Retry`, and error mapping.

**When to use:** When the module needs to send messages to an SQS queue.

**Usage:**
```
/dev-create-sqs-publisher ConversationAnalysis
```

---

### `dev-create-sqs-subscriber`

**Description:** Scaffolds an inbound SQS listener adapter as a humble object that delegates to a use case.

**When to use:** When the module needs to consume messages from an SQS queue.

**Usage:**
```
/dev-create-sqs-subscriber ConversationAnalysis
```

---

### `dev-create-sqs-redrive`

**Description:** Scaffolds a DLQ reprocessor that reads failed messages from a dead-letter queue and reprocesses them via the use case.

**When to use:** When an SQS operation needs manual or scheduled DLQ replay.

**Usage:**
```
/dev-create-sqs-redrive ConversationAnalysis
```

---

### `dev-create-api-client`

**Description:** Scaffolds an outbound HTTP client adapter using Retrofit with configuration, retry, and error mapping.

**When to use:** When the module needs to call an external HTTP service.

**Usage:**
```
/dev-create-api-client ConversationAnalysisClient
```

---

### `dev-generate-jooq-schema`

**Description:** Regenerates JOOQ type-safe classes from Flyway migrations using the project's code-generation pipeline.

**When to use:** After adding or modifying a Flyway migration, before implementing a JOOQ repository.

**Usage:**
```
/dev-generate-jooq-schema Conversation
```

---

### `dev-generate-http-files`

**Description:** Generates IntelliJ `.http` files from existing REST controllers for manual API testing against local or staging environments.

**When to use:** After implementing a controller, to get executable HTTP request files.

**Usage:**
```
/dev-generate-http-files ConversationController
/dev-generate-http-files --all
```

---

### `dev-migrate-to-standard`

**Description:** Migrates a single source file from legacy patterns to current AI26 conventions. Used during migration tickets to bring individual files into compliance.

**When to use:** During migration work identified by `ai26-assess-module`.

**Usage:**
```
/dev-migrate-to-standard src/main/kotlin/.../ConversationService.kt
```

---

## Testing

These skills generate test scaffolding. Called automatically by `ai26-implement-user-story`, or invoked directly when you need to add tests outside the full flow.

---

### `test-create-use-case-tests`

**Description:** Generates use case unit tests with Gherkin `// Scenario:` docstrings, MockK-mocked repository ports, Kotest assertions, and coverage for every error case in `error-catalog.yaml`.

**When to use:** When a new use case is implemented. Called automatically by `ai26-implement-user-story`.

**Usage:**
```
/test-create-use-case-tests CloseConversation
```

---

### `test-create-controller-tests`

**Description:** Generates `@WebMvcTest` controller tests covering every HTTP status the controller can return. Mandatory per rule T-07.

**When to use:** When a new controller endpoint is implemented. Called automatically by `ai26-implement-user-story`.

**Usage:**
```
/test-create-controller-tests ConversationController
```

---

### `test-create-feature-tests`

**Description:** Generates full-stack BDD feature tests using `@SpringBootTest(RANDOM_PORT)`, `TestRestTemplate`, and real TestContainers infrastructure. One test method per Gherkin scenario. Mandatory per rule T-07.

**When to use:** After use case and controller tests exist. Provides end-to-end acceptance test coverage. Called automatically by `ai26-implement-user-story`.

**Usage:**
```
/test-create-feature-tests SXG-1234
```

---

### `test-create-integration-tests`

**Description:** Creates integration tests for infrastructure adapters (JPA/JOOQ repositories, external services) using TestContainers. Verifies that outbound adapters correctly persist and retrieve domain entities against a real database.

**When to use:** When a new repository or outbound adapter is implemented. Called automatically by `ai26-implement-user-story`. Mandatory per rule T-01 (TestContainers only — never H2).

**Usage:**
```
/test-create-integration-tests ConversationRepositoryImpl
```

---

### `test-create-contract-tests`

**Description:** Generates WireMock-based contract tests for outbound HTTP client adapters. Verifies that the adapter correctly handles success, error, and timeout responses from an external service.

**When to use:** When a new HTTP client adapter is implemented with `dev-create-api-client`.

**Usage:**
```
/test-create-contract-tests ConversationAnalysisClient
```

---

### `test-create-architecture-tests`

**Description:** Creates ArchUnit tests that enforce Clean Architecture layer rules for a module: domain has no framework imports (CC-01), infrastructure is in `inbound/` or `outbound/` (CC-02), no circular dependencies.

**When to use:** Once per module, typically during onboarding or migration. Automates architectural invariant checks in CI.

**Usage:**
```
/test-create-architecture-tests service
```

---

### `test-create-test-configuration`

**Description:** Creates shared test infrastructure: TestContainers setup, Spring test configuration, and test properties. The foundation that other test skills depend on.

**When to use:** Once when setting up a new service or module that needs integration test support. Run before other test skills.

**Usage:**
```
/test-create-test-configuration service
```

---

### `test-create-mother-object`

**Description:** Generates a Mother Object for a domain aggregate: delegates to domain factory methods, uses random defaults, typed override parameters.

**When to use:** When a new aggregate is introduced and test helpers are needed. Called automatically when scaffolding tests.

**Usage:**
```
/test-create-mother-object Conversation
```

---

## Deprecated skills

The following skills are deprecated. Do not use them — use the replacements listed.

| Deprecated skill | Replacement |
|---|---|
| `ai26-design-epic-architecture` | `ai26-design-epic` |
| `ai26-decompose-epic` | `ai26-design-epic` |
| `ai26-design-user-story` | `ai26-design-ticket` |

---

## Reference

- [Flows reference](../ai26-sdlc/reference/flows.md) — when to use Flow A vs B vs C, with decision tree
- [Engineer Guide](./engineer-guide.md) — end-to-end tutorial showing skills in context
- [Glossary](./glossary.md) — definitions for skill, artefact, compound step, fidelity
