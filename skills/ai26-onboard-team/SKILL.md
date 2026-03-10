---
name: ai26-onboard-team
description: AI26 setup skill. Guides a team through the full onboarding process — creates ai26/config.yaml, builds the context files (DOMAIN.md, ARCHITECTURE.md, DECISIONS.md, DEBT.md, INTEGRATIONS.md), generates aggregate documentation files, and produces the initial C1/C4 architecture diagrams. Use when adopting AI26 on a new or existing project.
argument-hint: [--new | --existing] — new project from scratch, or existing codebase
---

# ai26-onboard-team

Guides a team through the complete AI26 setup. The output is a repository
ready to run `/ai26-start-sdlc`.

This skill is conversational — it asks questions, shows drafts, waits for
confirmation before writing anything. Nothing is written without the engineer
reviewing it first.

---

## Step 1 — Detect context

Check what already exists:

```
ai26/config.yaml               exists?
ai26/context/DOMAIN.md         exists?
ai26/context/ARCHITECTURE.md   exists?
ai26/context/DECISIONS.md      exists?
ai26/context/DEBT.md           exists?
ai26/context/INTEGRATIONS.md   exists?
ai26/domain/                   exists?
docs/architecture/diagrams/    exists?
```

Report what was found:

    AI26 onboarding check
    ──────────────────────────────────────────
    ✗ ai26/config.yaml — not found
    ✗ ai26/context/ — not found
    ✗ ai26/domain/ — not found

    Starting full onboarding. I'll guide you through each step.
    Nothing will be written until you confirm each section.

If all files exist, run the verification from `ai26-start-sdlc --check` and
report what is complete. Offer to update specific files if needed.

---

## Step 2 — Detect project structure

Before asking questions, scan the repository silently:

- Build files (`build.gradle`, `pom.xml`, `package.json`) → infer `stack`
- Module directories → infer `modules` list
- Source packages → infer `base_package` per module
- Flyway migration directories → infer `flyway.path` per module
- Existing domain code → detect bounded context candidates (package names under `domain/`)
- Existing aggregates → list class names that look like aggregate roots
- Existing ADRs in `docs/adr/` → read titles for context

Surface what was found before asking anything:

    I've scanned the repository. Here's what I found:

    Stack:        Kotlin + Spring Boot + Gradle
    Modules:      service/ (active), application/ (legacy)
    Base package: de.tech26.valium

    Possible bounded contexts (from package structure):
    - conversation (service/src/.../domain/conversation/)
    - agent (service/src/.../domain/agent/)

    Existing aggregates detected:
    - Conversation, Message (in conversation/)
    - Agent (in agent/)

    Existing ADRs: 3 found in docs/adr/

    Does this look right? I'll use this as the starting point.

Wait for confirmation before proceeding.

---

## Step 3 — Create `ai26/config.yaml`

Ask only what could not be inferred:

    I'll create ai26/config.yaml. A few questions:

    1. Is `service/` the only active module for new features?
       (I see `application/` exists — should it be marked legacy?)

    2. Does `service/` use JOOQ or JPA for persistence?

    3. What event bus does the service use? (kafka / sqs / none)

    [Only ask if 2 or more modules share the same database:]
    4. Multiple modules detected that share the same PostgreSQL database.
       Should I add a table name prefix per module to avoid collisions?
       For example, `tablePrefix: "svc_"` on the service module would
       generate `svc_conversation` instead of `conversation`.
       Leave null if modules have disjoint table names or use separate schemas.

Show the draft before writing:

    Here's the config I'll create:

    ```yaml
    # ai26/config.yaml
    # modules are Gradle build modules only — aggregates live in ai26/domain/

    stack:
      language: kotlin
      framework: spring-boot
      build: gradle
      database: postgresql
      test_framework: mockk
      containers: testcontainers

    shared_imports:
      either: de.tech26.valium.shared.kernel.Either
      logger: de.tech26.valium.shared.kernel.logger

    modules:
      - name: service
        path: service/
        active: true
        base_package: de.tech26.valium
        base_package_path: de/tech26/valium
        main_source_root: service/src/main/kotlin
        test_source_root: service/src/test/kotlin
        test_fixtures_root: service/src/testFixtures/kotlin
        test_resources_root: service/src/test/resources
        conventions:
          orm: jooq
          http_client: retrofit
          error_handling: either
          test_containers: true
          event_bus: kafka

      - name: persistence
        path: persistence/
        active: false
        base_package: de.tech26.valium.persistence
        base_package_path: de/tech26/valium/persistence
        main_source_root: persistence/src/main/kotlin
        flyway:
          migration_root: persistence/src/main/resources/db/migration
          naming_pattern: "V{version}__{description}.sql"
          tablePrefix: ~  # null = no prefix. Set to e.g. "svc_" if multiple modules share the same DB.

      - name: application
        path: application/
        active: false
        base_package: de.tech26.valium.auth
        base_package_path: de/tech26/valium/auth
        main_source_root: application/src/main/kotlin
        test_source_root: application/src/test/kotlin
        conventions:
          orm: jpa
          error_handling: exceptions
          test_containers: false
          event_bus: none

    # Coding rules — enforced by skills and validated by ai26-review-user-story.
    # These come pre-filled from the plugin. Edit only if your project deviates intentionally.
    coding_rules:
      cross_cutting:
        CC-01: "Domain layer: zero framework imports (org.springframework.*, jakarta.*, org.jooq.*)"
        CC-02: "Infrastructure classes in inbound/ or outbound/ — nothing flat in infrastructure/"
        CC-03: "Either<DomainError, DTO> from de.tech26.valium.shared.kernel — never kotlin.Result, never arrow.core.Either"
        CC-04: "Repository/emitter ports: plain return types — nullable for not-found, throws for infra. Never Either on port signatures"
        CC-05: "DTO fields: primitives only (String, Int, Long, Boolean, Double). UUID→String, Instant→String, enum→String(.name)"
      domain:
        D-01: "Aggregate root: class with private constructor — NOT data class"
        D-02: "companion object with create() for new instances, from() for DB rehydration"
        D-03: "init block with require() for constructor invariants only"
        D-04: "Mutations return new instances via private copy() — no var, no public setters"
        D-05: "Business methods that can fail return Either<SealedError, Aggregate> — never throw"
        D-06: "Sealed error classes nested inside the aggregate"
        D-07: "toDTO() for boundary crossing, toSnapshot() for domain events"
        D-08: "ID value object: data class {Name}Id(val value: UUID) — NOT @JvmInline value class"
        D-09: "ID factory: random() — NOT new(), NOT generate()"
        D-10: "ID has fromString(raw: String) for parsing from HTTP/SQS input"
        D-11: "Value objects: @JvmInline value class for single-field wrappers, data class for multi-field or IDs"
        D-12: "Status enum has behavior methods (isActive(), canBeCancelled()) — not just constants"
        D-13: "Cross-aggregate references by ID only — never embed another aggregate"
        D-14: "One Repository per aggregate root"
      application:
        A-01: "Use case returns Either<SealedError, DTO> — never raw domain entities"
        A-02: "Entry point: operator fun invoke() with primitive parameters — no Command/DTO input objects"
        A-03: "@Service and @Transactional"
        A-04: "One aggregate per transaction"
        A-05: "No infrastructure imports"
        A-06: "No try/catch for expected business outcomes — use Either from domain methods"
      infrastructure:
        I-01: "Controllers are humble objects — delegate to use case, no business logic"
        I-02: "Controllers fold Either directly — map Error to ApplicationException"
        I-03: "Request bodies have bean validation annotations (@field:NotBlank, etc.)"
        I-04: "Outbound adapters: implementation prefix (Jooq, Jpa, Kafka, Sqs, Http, Stub, InMemory, Logging)"
        I-05: "Outbound adapters: runCatching for infra errors"
        I-06: "Outbound adapters: @Retry where appropriate"
      testing:
        T-01: "TestContainers only — never H2"
        T-02: "Mock only outbound ports — never domain entities or value objects"
        T-03: "Mother Objects for test data — no inline construction in test bodies"
        T-04: "// Scenario: docstring on every @Test method"
        T-05: "Feature tests: @SpringBootTest(RANDOM_PORT) + TestRestTemplate, NOT MockMvc"
        T-06: "Feature tests: inject real repository adapter, NOT InMemory fakes"
        T-07: "Controller tests and feature tests are mandatory"
        T-08: "@BeforeEach cleans DB state in feature tests"
    ```

    Confirm to write, or tell me what to change.

On confirmation, write and commit:

```
git add ai26/config.yaml
git commit -m "chore: add ai26/config.yaml"
git push
```

---

## Step 4 — Create `ai26/context/DOMAIN.md`

This is the most important file. Take it one bounded context at a time.

For each detected bounded context:

    Let's document the {ContextName} bounded context.

    From the code I can see:
    - Aggregate: Conversation (with states OPEN, ASSIGNED, CLOSED, ESCALATED)
    - Aggregate: Message (child entity of Conversation)

    I need your input on:

    1. What does this context own? (in business terms, not technical)
    2. What does it explicitly NOT own?
       (things that live nearby but belong to a different context)
    3. Are there domain terms the team uses that shouldn't be used?
       (synonyms to reject — e.g. "don't call it a Ticket, call it a Conversation")

Show draft after each context and wait for confirmation before writing the next.

Once all bounded contexts are confirmed, write the full `DOMAIN.md` and commit:

```
git add ai26/context/DOMAIN.md
git commit -m "chore: add ai26/context/DOMAIN.md"
git push
```

---

## Step 5 — Create `ai26/context/ARCHITECTURE.md`

`ARCHITECTURE.md` contains **only structural layer rules and prohibitions** — what layers exist,
what can depend on what, and what is structurally forbidden. Nothing else belongs here:

- Testing strategy → lives in `ai26/config.yaml` (`conventions.test_containers`, etc.)
- Flyway paths → lives in `ai26/config.yaml` (`flyway.path`)
- The *why* behind any rule → lives in `DECISIONS.md`
- Code conventions (naming, error handling patterns) → live in the skills themselves

    Now let's document the architectural constraints.

    From the code I can see this project uses Clean Architecture with:
    - domain/ — no framework imports detected
    - application/ — use cases with @Service
    - infrastructure/inbound/ and infrastructure/outbound/ — present

    Questions:
    1. Are there any structural constraints not obvious from the layer structure?
       (things a new engineer could easily get wrong about where code must or must not live)
    2. Are there any legacy exceptions to the layer rules?
       (modules or classes that violate the standard intentionally)

Show the draft. Wait for confirmation. Write and commit:

```
git add ai26/context/ARCHITECTURE.md
git commit -m "chore: add ai26/context/ARCHITECTURE.md"
git push
```

---

## Step 6 — Create `ai26/context/DECISIONS.md`

    Now let's capture the system design decisions that are already settled.

    These are decisions about WHY the system is shaped the way it is —
    domain modelling, data modelling, inter-component communication,
    infrastructure choices. Not about how code is written.

    From the ADRs I found, I can pre-populate some entries.
    Tell me any decisions the team knows implicitly but hasn't written down:

    - Why are the bounded contexts split this way?
    - Are there data modelling decisions that took effort to reach?
    - Why does the service communicate via Kafka vs direct API calls?
    - Are there infrastructure choices with a specific reason?

Collect answers. Show draft. Wait for confirmation. Write and commit:

```
git add ai26/context/DECISIONS.md
git commit -m "chore: add ai26/context/DECISIONS.md"
git push
```

---

## Step 7 — Create `ai26/context/DEBT.md`

    Finally, technical debt. This helps the LLM warn you when a ticket
    touches a risky area.

    Risk levels:
    - alto  — surfaces immediately, may recommend pausing the design
    - medio — mentioned as a warning, design continues
    - bajo  — noted in the plan, no interruption

    What areas of the codebase are known to be fragile or risky to touch?
    If there's no known debt, I'll create the file with a placeholder.

Collect entries. For each entry ask: What? Why is it a risk? Any workaround? Any plan to fix it?

Show draft. Wait for confirmation. Write and commit:

```
git add ai26/context/DEBT.md
git commit -m "chore: add ai26/context/DEBT.md"
git push
```

---

## Step 8 — Create `ai26/context/INTEGRATIONS.md`

Before asking questions, scan the codebase silently:

- REST controllers (`@RestController`) → detect inbound HTTP endpoints and auth mechanisms
- Retrofit `@POST` / `@GET` interfaces, `WebClient` / `FeignClient` → detect outbound HTTP calls
- Kafka publishers (`KafkaTemplate`, `@KafkaListener`) → detect events emitted/consumed
- SQS publishers/listeners (`SqsTemplate`, `@SqsListener`) → detect events emitted/consumed
- Bedrock/OpenAI/Vertex SDK calls → detect AI/ML service usage
- Package names like `client/`, `external/` → infer downstream dependency candidates

Surface what was found:

    I've scanned the codebase for integrations. Here's what I found:

    Inbound HTTP:    5 endpoints detected (GET, POST on /conversations)
    Outbound HTTP:   2 services detected (IdentityService, NotificationService)
    Events emitted:  5 event types on topic 'conversations'
    Events consumed: 2 event types (agents, customers topics)
    AI/ML services:  1 detected (Amazon Bedrock — BedrockClient calls found)
    Downstream:      Could not detect — needs your input

    Does this look right? Tell me what I missed or got wrong.

Wait for confirmation.

For sections the scan could not populate (especially **Downstream services** — who
calls our API or consumes our events is not visible in code), ask explicitly:

    I couldn't detect downstream services from the code — this isn't visible
    from within the service itself.

    Which other services call our API, or consume the events we emit?
    For each, what would break if we changed the contract?

Collect entries. Show the full draft. Wait for confirmation. Write and commit:

```
git add ai26/context/INTEGRATIONS.md
git commit -m "chore: add ai26/context/INTEGRATIONS.md"
git push
```

---

## Step 9 — Generate initial C1/C4 diagrams

With `INTEGRATIONS.md` and `DOMAIN.md` complete, generate the initial diagrams:

    Generating C1 and C4 diagrams from INTEGRATIONS.md and DOMAIN.md...

Generate `ai26/context/diagrams/c1-system-context.md` and
`ai26/context/diagrams/c4-components.md` following the format in
`docs/ai26-sdlc/reference/context-mapping.md`.

The same Mermaid content is written to `docs/service/assets/` as the team's navigable
diagram convention (replaces `.puml` files — Mermaid renders natively in GitHub and VS Code).

Show both diagrams. Wait for confirmation. Write and commit:

```
mkdir -p ai26/context/diagrams
git add ai26/context/diagrams/ docs/service/assets/c1-system-context.md docs/service/assets/c4-components.md
git commit -m "chore: add initial C1 and C4 architecture diagrams"
git push
```

---

## Step 10 — Create aggregate documentation files

For each aggregate detected in Step 2:

    Now let's document the {AggregateName} aggregate.
    I'll read the source file and generate the Mermaid diagram and YAML model.

    Reading: {path to Conversation.kt}...

    Here's what I found. Please review — I'll mark gaps where
    I couldn't determine something from the code alone.

Generate the full `ai26/domain/{module}/{aggregate}.md` following the format
in `docs/ai26-sdlc/reference/aggregate-format.md`. Mark any gaps as `# TODO: confirm with team`.

Show draft per aggregate. Wait for confirmation. Write and commit after all aggregates
in a module are confirmed:

```
git add ai26/domain/{module}/
git commit -m "chore: add aggregate docs for {module} module"
git push
```

---

## Step 11 — Verify setup

Run the full setup check:

    AI26 setup check
    ──────────────────────────────────────────
    ✓ ai26/config.yaml — valid
    ✓ ai26/context/DOMAIN.md — found
    ✓ ai26/context/ARCHITECTURE.md — found
    ✓ ai26/context/DECISIONS.md — found
    ✓ ai26/context/DEBT.md — found
    ✓ ai26/context/INTEGRATIONS.md — found
    ✓ ai26/domain/ — {N} aggregates documented
    ✓ ai26/context/diagrams/ — C1 and C4 generated
    ✓ Jira MCP — connected (project: {PROJECT})
    ✓ Git remote — origin configured

    Setup complete.

    Next step: /ai26-start-sdlc

If anything is missing, surface it with a proposed fix before closing.

---

## Existing codebase note

For teams adopting on an existing codebase, this skill generates context from
what exists in the code. It cannot recover decisions that were made verbally
and never written down — those gaps are surfaced as questions.

After onboarding, use `/ai26-start-sdlc {TICKET-ID}` to start the first feature.
For retroactive artefact generation on already-implemented features:

    /ai26-start-sdlc {TICKET-ID} --backfill
