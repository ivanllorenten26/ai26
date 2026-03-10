---
name: ai26-review-user-story
description: SDLC3 Phase 2d. Automated first-pass code review that checks artefact-to-code coherence, code quality heuristics, and DDD/Clean Architecture pattern compliance. Does not replace human review. Run after ai26-validate-user-story passes, before ai26-promote-user-story.
argument-hint: [TICKET-ID] — Jira ticket ID
---

# ai26-review-user-story

Automated first-pass review. Not a replacement for human review — a complement.
Checks that the implementation follows the team's agreed patterns before a human
spends time reviewing structural problems that the system can detect automatically.

---

## Step 1 — Load context

Read:
1. `ai26/features/{TICKET}/domain-model.yaml`
2. `ai26/features/{TICKET}/use-case-flows.yaml`
3. `ai26/features/{TICKET}/error-catalog.yaml`
4. `ai26/features/{TICKET}/api-contracts.yaml` (if exists)
5. `ai26/features/{TICKET}/events.yaml` (if exists)
6. `ai26/features/{TICKET}/plan.md` — list of files created per subtask
7. `ai26/config.yaml` — stack, conventions, error_handling, repository_type
8. `ai26/context/ARCHITECTURE.md`

Collect the list of implementation files from `plan.md` (files_created per subtask).
These are the files under review.

---

## Check 1 — Clean Architecture layer rules

Read `ai26/config.yaml` → `coding_rules`. Verify **CC-01** and **CC-02** for each file under review:

| File location | Expected contents |
|---|---|
| `domain/` | CC-01: No framework imports (`org.springframework.*`, `jakarta.*`, `org.jooq.*`) |
| `application/` | A-05: No infrastructure imports; A-03: `@Service` only framework annotation |
| `infrastructure/inbound/` | CC-02: In `inbound/` subpackage |
| `infrastructure/outbound/` | CC-02: In `outbound/` subpackage |

On violation:

    ✗ Layer rule — BLOCKING
    SendCustomerMessage.kt imports jakarta.persistence.Entity
    Violates CC-01: domain layer must have zero framework imports.
    Fix: move persistence mapping to the outbound adapter.
    Apply fix? [yes / no / explain]

---

## Check 2 — DDD pattern compliance

Read `ai26/config.yaml` → `coding_rules`. Verify **D-01, D-02, D-03, D-04, D-08, D-12, D-13, D-14, A-02, A-03, CC-04**:

| Concept | Rules |
|---|---|
| Aggregate roots | D-01, D-02, D-03, D-04, D-07 |
| ID value objects | D-08, D-09, D-10 |
| Value objects | D-11 |
| Status enums | D-12 |
| Use cases | A-01, A-02, A-03 |
| Repository interfaces | CC-04, D-14 |

On violation:

    ✗ DDD pattern — BLOCKING
    Conversation aggregate has a public setter: setStatus(status: Status)
    Violates D-04: mutations must return new instances via private copy() — no public setters.
    Proposed fix: replace with a domain method that encodes the intent (e.g., close(), archive()).
    Apply fix? [yes / no / explain]

---

## Check 3 — Error handling consistency

Read `ai26/config.yaml` → `modules[].conventions.error_handling`. Verify **CC-03, D-05, D-06, A-01, A-06, I-02**:

If `error_handling: either`:
- A-01: use cases return `Either<SealedError, DTO>` — not throw domain exceptions
- I-02: controllers fold Either directly — map Error to ApplicationException
- A-06: no `try/catch` for expected business outcomes — use Either from domain methods
- D-05: business methods that can fail return `Either<SealedError, Aggregate>`
- D-06: sealed error classes nested inside the aggregate

On violation:

    ✗ Error handling — BLOCKING
    CloseConversationUseCase throws ConversationAlreadyClosedException directly.
    Violates A-06 and CC-03: project convention is Either-based error handling.
    Proposed fix: return Either.Error(ConversationError.AlreadyClosed) instead.
    Apply fix? [yes / no / explain]

---

## Check 4 — Test quality

Read `ai26/config.yaml` → `coding_rules.testing`. Verify **T-01 through T-08**:

| Rule | Meaning |
|---|---|
| T-01 | TestContainers only — never H2 |
| T-02 | Mock only outbound ports — never domain entities or value objects |
| T-03 | Mother Objects for test data — no inline construction in test bodies |
| T-04 | `// Scenario:` docstring on every `@Test` method |
| T-05 | Feature tests: `@SpringBootTest(RANDOM_PORT)` + `TestRestTemplate`, NOT `MockMvc` |
| T-06 | Feature tests: inject real repository adapter, NOT InMemory fakes |
| T-07 | Controller tests and feature tests are mandatory |
| T-08 | `@BeforeEach` cleans DB state in feature tests |

T-01, T-05, T-06, T-07 are BLOCKING. T-02, T-03, T-04, T-08 are WARNINGS.

On violation (warning, non-blocking):

    ⚠ Test quality — WARNING
    SendCustomerMessageTest constructs a Conversation inline rather than using ConversationMother.
    Violates T-03: use Mother Objects for consistent test data.

---

## Check 5 — API contract alignment

If `api-contracts.yaml` exists, for each endpoint:

- HTTP method and path match the controller handler annotation
- Request body fields match the controller's request DTO fields
- Response status codes match the controller's `@ResponseStatus` or `ResponseEntity` types
- Error responses match `error-catalog.yaml` variants

On violation:

    ✗ API contract — BLOCKING
    api-contracts.yaml defines POST /conversations/{id}/messages → 201 Created
    SendCustomerMessageController returns 200 OK.
    Proposed fix: add @ResponseStatus(HttpStatus.CREATED) to the handler method.
    Apply fix? [yes / no / explain]

---

## Check 6 — Event contract alignment

If `events.yaml` exists, for each published event:

- Event class name matches the name in `events.yaml`
- Payload fields match the defined payload structure
- Publisher is invoked in the correct aggregate method or use case

On violation:

    ✗ Event contract — BLOCKING
    events.yaml defines CustomerMessageSent with field: conversationId
    CustomerMessageSentEvent class has field: id
    Field name mismatch.
    Proposed fix: rename field in CustomerMessageSentEvent to conversationId.
    Apply fix? [yes / no / explain]

---

## Correction handling

For each violation, the engineer chooses:

- **yes / do it** → apply the proposed fix immediately
- **no** → violation stays open, engineer handles manually
- **explain** → LLM explains the violation in detail
- **defer** → violation recorded as explicitly deferred with reason

Deferred violations are included in the report and visible at promotion. They do not block promotion.

---

## Severity

| Severity | Examples | Blocks promotion? |
|---|---|---|
| **Blocking** | Layer rule violations, DDD pattern violations, error handling inconsistency, API contract mismatch, event field mismatch | Yes |
| **Warning** | Test quality issues, minor naming inconsistencies | No |

---

## Review report

    Review report — {TICKET-ID}
    ──────────────────────────────────────────────────────

    Clean Architecture layers    ✓ {N} files — no layer violations
    DDD patterns                 ✓ {N} aggregates, {N} use cases — patterns correct
    Error handling               ✓ Either-based throughout
    Test quality                 ⚠ {N} warning(s)
    API contract alignment       ✓ {N}/{N} endpoints match
    Event contract alignment     ✓ {N}/{N} events match

    Blocking violations: 0
    Warnings: {N}

    Status: PASS

    Note: this is an automated first-pass review. Human review is still required.
    Next step: /ai26-promote-user-story {TICKET-ID}

On failure:

    Status: FAIL — resolve blocking violations before promotion

    Blocking violations:
    ✗ {violation 1}
    ✗ {violation 2}

Commit on pass:

```
git add ai26/features/{TICKET}/plan.md
git commit -m "{TICKET-ID} review: automated review passing"
git push
```
