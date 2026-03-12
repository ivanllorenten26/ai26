# AI26 Glossary

Every term used across AI26 skills and reference documentation, defined for everyone — engineers, PMs, and leads.

---

## A

**ADR (Architecture Decision Record)**
A short, structured document that captures a significant design decision, the options considered, and the reasoning behind the choice. ADRs live in `docs/adr/` and are permanent. They are written during the design phase and referenced by `ai26/context/DECISIONS.md`. Once written, an ADR is never deleted — only superseded.

**Aggregate**
In Domain-Driven Design, a cluster of domain objects (entities and value objects) that form a consistency boundary. The aggregate root is the only entry point from outside. In AI26, every aggregate root is a `class` with a private constructor and a `companion object` providing `create()` and `from()` factory methods.

**Aggregate Root**
The main entity in an aggregate that controls all access to the objects within. External code may only reference the aggregate by the root's ID. AI26 rule: aggregate roots are `class` (never `data class`) with a private constructor.

**Artefact**
A structured YAML or Gherkin file produced during the design phase. Artefacts are the contract between design and implementation. The full set: `domain-model.yaml`, `use-case-flows.yaml`, `api-contracts.yaml`, `events.yaml`, `error-catalog.yaml`, `glossary.yaml`, `scenarios/*.feature`, `ops-checklist.yaml`, `diagrams.md`.

**Artefact Set**
All the design artefacts produced for a single ticket or feature. The set is stored in `ai26/features/{TICKET-ID}/`.

---

## B

**Backfill**
The process of generating design artefacts retroactively from existing code that was written without going through the AI26 design phase. Handled by the `ai26-backfill-user-story` skill. This is a corrective measure, not normal workflow — using it routinely indicates the Compound Loop is not running.

**Bounded Context**
A well-defined part of the domain with its own ubiquitous language, aggregates, and ownership rules. Defined in `ai26/context/DOMAIN.md`. Cross-context references are by ID only — never by embedding another aggregate's data.

---

## C

**Clean Architecture**
The structural pattern used in the Valium codebase. Code is organised into layers: `domain/` (zero framework imports), `application/` (use cases), `infrastructure/inbound/` (controllers, subscribers), `infrastructure/outbound/` (repositories, publishers). Dependencies flow inward — infrastructure depends on application and domain, never the reverse.

**CLAUDE.md**
The root configuration file read by Claude Code at the start of every session. Contains the stack, project overview, hard rules, and pointers to the full context layer. Along with `ai26/context/`, this is the primary input to every AI agent in every session.

**COMPOUND.md**
A transient observation inbox created per ticket at `ai26/features/{TICKET}/COMPOUND.md`. Accumulates what went wrong at any SDLC checkpoint via `/ai26-compound`. Cleared (deleted) after all observations are resolved with `/ai26-compound-resolve`. `ai26-promote-user-story` is blocked while pending observations remain.

**Compound Engineering**
The operating model behind AI26. A four-step loop (Plan → Work → Assess → Compound) where every completed feature feeds knowledge back into the context layer, making the next feature easier to build. The opposite of vibe coding. Coined and popularised by Every.to.

**Compound Loop**
The four steps of Compound Engineering: Plan (40% of engineer focus), Work (10%), Assess (30%), Compound (20%). The Compound step — updating `ai26/context/` and promoting artefacts — is what makes the loop self-improving. Skipping it breaks the compound effect.

**Compound Step**
The fourth step of the Compound Loop. Executed via `ai26-promote-user-story`. It merges feature artefacts into `docs/architecture/`, updates `ai26/context/` files, and ensures ADRs are indexed. The step that makes each future feature start with more context than the last.

**Context Drift**
The gradual divergence between the contents of `ai26/context/` and the actual state of the codebase. Caused by PRs that change domain behaviour without updating context files. Detected and repaired by `ai26-sync-context`. A stale context produces worse AI outputs and incorrect design conversations.

**Context Files**
The five files in `ai26/context/` that form the shared knowledge base: `DOMAIN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `DEBT.md`, `INTEGRATIONS.md`. Read by AI agents at the start of every skill invocation. See `docs/ai26-sdlc/reference/context-files.md` for the full format guide.

**Context Layer**
The combination of `ai26/context/` files, `ai26/domain/` aggregate docs, and `CLAUDE.md`. Together they represent the team's accumulated institutional memory. Keeping the context layer accurate is as important as keeping tests green.

---

## D

**DDD (Domain-Driven Design)**
A design philosophy and set of patterns (aggregates, bounded contexts, ubiquitous language, domain events) used throughout Valium. AI26's design phase is built around DDD concepts.

**Design Artefacts**
See Artefact.

**Domain Event**
An event that represents something significant that happened within the domain (e.g., `ConversationClosed`). In Valium, domain events use the Event-Carried State Transfer (ECST) pattern — the event payload contains a full aggregate snapshot. Published via transactional outbox to Kafka.

**domain-model.yaml**
The artefact that defines aggregates, entities, value objects, states, and invariants for a feature. The `status` field on each element (`new`, `modified`, `existing`, `deprecated`, `removed`) controls what the promotion step does with it.

---

## E

**ECST (Event-Carried State Transfer)**
The domain event pattern used in Valium. Every event carries a full snapshot of the aggregate state at the time of the event. Consumers do not need to query back for additional data.

**Either**
The functional error-handling type used throughout the codebase. `Either<Error, Success>`. Imported from `de.tech26.valium.shared.kernel` — never from `kotlin.Result` or `arrow.core.Either`. Use cases return `Either<DomainError, DTO>`. Business methods that can fail return `Either<SealedError, Aggregate>`.

**Epic**
A business initiative composed of multiple related tickets. In AI26, epics are processed by `ai26-design-epic`, which designs the whole epic as one coherent block before slicing it into tickets. Epic artefacts live in `ai26/epics/{EPIC-ID}/`.

**error-catalog.yaml**
The artefact that enumerates every error type introduced by a feature, classified as `eitherErrors` (business rule violations), `domainExceptions` (invariant violations), or `applicationExceptions` (infrastructure failures). Every error in `use-case-flows.yaml` must have a corresponding entry.

---

## F

**Feature Test**
A full-stack BDD acceptance test. Uses `@SpringBootTest(RANDOM_PORT)`, `TestRestTemplate`, and real TestContainers infrastructure. No mocks. One feature test per Gherkin scenario. Mandatory per rule T-07.

**Feature Workspace**
The directory `ai26/features/{TICKET-ID}/` that holds all design artefacts for a single ticket. After promotion, this workspace can be deleted — the knowledge has moved into `docs/architecture/` and `ai26/context/`.

**Fidelity**
The level of planning rigour applied to a task. Three levels: Fidelity 1 (Quick Fix, ~20% human planning), Fidelity 2 (Sweet Spot, ~60% human planning — most features), Fidelity 3 (Big Uncertain, ~100% human planning). The `ai26-design-ticket` skill accepts `--fidelity 1` for bug fixes with domain impact.

**Flow A / Flow B / Flow C**
The three SDLC flows in AI26. Flow A is for epics (`ai26-write-prd` → `ai26-design-epic` → `ai26-implement-user-story` per ticket). Flow B is for standalone tickets (`ai26-design-ticket` → `ai26-implement-user-story`). Flow C is for quick fixes (`ai26-implement-fix`). All three are accessible from `/ai26-start-sdlc`.

---

## G

**Gherkin**
The structured natural-language format for writing BDD scenarios: `Given / When / Then`. Used in `scenarios/*.feature` artefact files and as `// Scenario:` docstring comments embedded directly in JUnit test methods. Every error case and happy path in `use-case-flows.yaml` must have a Gherkin scenario.

**Glossary (artefact)**
The `glossary.yaml` artefact produced during the design phase. Captures domain terms introduced by a feature. At promotion, new terms are merged into the module glossary.

---

## I

**Implementation Skill**
A skill that generates code (`dev-create-*`, `test-create-*`). These skills read artefacts and the context layer to produce code that follows the team's architectural patterns. Implementation skills guarantee architectural compliance by construction.

**Intention Debt**
Code that was correct for a specification the business no longer endorses. Harder to see than technical debt — tools cannot detect it. Managed by keeping design artefacts aligned with current business rules and by running `ai26-sync-context` to detect drift.

---

## L

**LEARNINGS.md**
The permanent institutional memory at `ai26/context/LEARNINGS.md`. Contains graduated observations from `/ai26-compound-resolve` — each entry records what went wrong at an SDLC checkpoint, the root cause, and what was changed to fix it. Never deleted. Read at startup by `ai26-design-ticket`, `ai26-implement-user-story`, and `ai26-review-user-story` so past mistakes are not repeated. Created automatically by `ai26-onboard-team` or on the first graduation.

---

## M

**Mother Object**
A test helper class that provides pre-built, valid instances of a domain object for use in tests. Named `{Aggregate}Mother.kt`. Mother Objects delegate to the domain factory (`create()` / `from()`), never the constructor directly. Default parameter values are random, not hardcoded.

---

## O

**Onboarding**
The process of setting up AI26 on a new team or codebase. Managed by the `ai26-onboard-team` skill. Produces `ai26/config.yaml`, an initial `ai26/context/` directory, and verifies the setup with `/ai26-start-sdlc --check`.

**ops-checklist.yaml**
The artefact that captures operational concerns for a feature: DB migration required, feature flag needed, new alerts, runbook updates. Not promoted to architecture documentation — it is a per-ticket checklist for the engineer.

---

## P

**PRD (Product Requirements Document)**
A structured document that captures the business context, goals, user stories, constraints, and success metrics for an epic. Produced by `ai26-write-prd`. Stored in `ai26/epics/{EPIC-ID}/prd.md`. The input to `ai26-design-epic`.

**Promotion**
The final step of the feature lifecycle, executed by `ai26-promote-user-story`. Merges feature artefacts into `docs/architecture/`, updates `ai26/context/`, and indexes ADRs. Promotion is blocked if there are unresolved blocking validation violations. This is the Compound step.

**Promotion Report**
The summary produced by `ai26-promote-user-story` after it completes. Lists every file updated, every ADR indexed, every context update applied, and whether epic promotion is deferred.

---

## R

**Renaissance Engineer**
The target engineering role described in the AI26 vision: an engineer who orchestrates fleets of specialised AI agents, writes instructions and context rather than syntax, and is valued for domain expertise and system architecture rather than typing speed.

**Repository Port**
An interface defined in the `domain/` layer that describes persistence operations for an aggregate. Implementations live in `infrastructure/outbound/` (e.g., `JooqConversationRepository`). Repository ports use plain return types — `nullable` for not-found, throws for infrastructure failures. Never `Either` on port signatures (rule CC-04).

---

## S

**Scenario**
A single Gherkin test case: one happy path or one error path. Every use case error case defined in `use-case-flows.yaml` must have a corresponding scenario in `scenarios/*.feature`. Scenarios are also embedded as `// Scenario:` docstrings in JUnit test methods.

**SDLC (Software Development Lifecycle)**
The end-to-end process from business requirement to production code. AI26's SDLC maps to the Compound Loop: Plan (design skills) → Work (implement skills) → Assess (validate and review skills) → Compound (promote skill).

**Skill**
A specialised Claude Code command that automates one step of the SDLC. Invoked with `/{skill-name} [arguments]`. Skills are the primary way to interact with AI26. They read the context layer before executing and produce structured, reviewable output.

**Spec Driven Development**
The design philosophy underlying AI26: when AI can generate code from a precise description, the primary artefact of software development is the description (the spec), not the code. Described in `docs/ai26-sdlc/vision/the-thesis.md`.

**Stack**
The technology configuration in `ai26/config.yaml`: language (Kotlin), framework (Spring Boot), build tool (Gradle), repository type (JOOQ), error handling style (Either), event bus (Kafka). Skills read the stack configuration to generate compliant code.

---

## T

**Technical Debt (DEBT.md)**
Documented fragile areas in the codebase. Stored in `ai26/context/DEBT.md` with a risk level (`alto`, `medio`, `bajo`). `alto` entries surface immediately during design and may pause the design conversation. Read by `ai26-design-ticket` and `ai26-design-epic` before proposing any changes to the affected area.

**Transactional Outbox**
The persistence pattern used for reliable domain event publishing. The event is written to an outbox table in the same database transaction as the aggregate save. A separate process reads the outbox and publishes to Kafka. Prevents the "dual-write" problem where the DB commit succeeds but the Kafka publish fails.

---

## U

**Ubiquitous Language**
The shared vocabulary defined for each bounded context in `ai26/context/DOMAIN.md`. AI agents use canonical terms and reject synonyms. For example: in the Conversations context, use "Conversation" not "Ticket" or "Case"; use "Close" not "Resolve" or "Complete".

**Use Case**
An application-layer class that orchestrates domain objects to execute a single business operation. Annotated with `@Service` and `@Transactional`. Entry point: `operator fun invoke()` with primitive parameters. Returns `Either<DomainError, DTO>`. One use case per business operation.

**use-case-flows.yaml**
The artefact that defines every use case for a feature: actor, inputs, output type, error cases, and side effects (events, notifications). The source of truth for the error catalog and Gherkin scenarios — both are derived from it.

---

## V

**Validation**
The gate between implementation and promotion, executed automatically at the end of `ai26-implement-user-story`. Three checks: (1) design-to-code coherence, (2) test coverage, (3) Jira acceptance-criteria-to-scenario coherence. Blocking violations prevent promotion. See `docs/ai26-sdlc/reference/validation.md`.

**Value Object**
An immutable domain concept with no identity (e.g., `Email`, `Money`). In AI26, single-field non-ID value objects use `@JvmInline value class`. ID value objects use `data class {Name}Id(val value: UUID)` — never `@JvmInline` (rule D-08).

**Vibe Coding**
The anti-pattern of using AI to generate code without a system: ad-hoc prompting, no design artefacts, no context layer, no promotion. Output is produced but knowledge is not compounded. Every new session starts from zero.

---

## 80% AI Mandate

The organisational target: 80% of all Pull Requests must be significantly AI-assisted or generated. Not a micromanagement tool — a systemic forcing function to surface tech debt that blocks AI adoption and to break old habits. Performance is measured by architectural orchestration quality and context creation, not lines of code.
