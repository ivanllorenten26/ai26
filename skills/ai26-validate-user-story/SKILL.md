---
name: ai26-validate-user-story
description: SDLC3 Phase 2c. Automatic validation gate that checks design-to-code coherence, test coverage, and ticket-to-design coherence. Runs automatically at the end of ai26-implement-user-story. Can also be invoked manually at any point.
argument-hint: [TICKET-ID] — Jira ticket ID
---

# ai26-validate-user-story

Validates that what was designed is what was built, and that it works correctly.
Three responsibilities: design↔code coherence, test coverage, ticket↔design coherence.

---

## Step 1 — Load context

Read:
1. `ai26/features/{TICKET}/domain-model.yaml`
2. `ai26/features/{TICKET}/use-case-flows.yaml`
3. `ai26/features/{TICKET}/error-catalog.yaml`
4. `ai26/features/{TICKET}/api-contracts.yaml` (if exists)
5. `ai26/features/{TICKET}/events.yaml` (if exists)
6. `ai26/features/{TICKET}/scenarios/` — all feature files
7. Ticket from Jira via MCP — acceptance criteria
8. `ai26/config.yaml` — validation settings

---

## Check 1 — Design ↔ Code coherence

For each element in the artefacts, verify a corresponding implementation exists:

| Artefact element | What to look for in code |
|---|---|
| Use case in `use-case-flows.yaml` | A class implementing that use case |
| Error variant in `error-catalog.yaml` | A type representing that error |
| Endpoint in `api-contracts.yaml` | A handler for that path + method |
| Published event in `events.yaml` | A publisher for that event |
| Consumed event in `events.yaml` | A handler for that event |
| Aggregate in `domain-model.yaml` | A class representing that aggregate |

The LLM traces by name — it does not check implementation logic, only existence
and naming coherence. Search the codebase using the naming conventions from
`ai26/config.yaml`.

On violation:

    ✗ Design ↔ Code — BLOCKING
    use-case-flows.yaml defines CloseConversation but no implementation was found.
    Proposed fix: generate the CloseConversation use case.
    Apply fix? [yes / no / explain]

---

## Check 2 — Test coverage

**Scenario traceability:**
For each `Scenario:` in the `.feature` files under `ai26/features/{TICKET}/scenarios/`,
verify that a `// Scenario: {name}` docstring comment exists in a `*Test.kt` or
`*FeatureTest.kt` file in the test sources. Match is case-insensitive, trimmed.
A scenario with no corresponding docstring is blocking.

**Error path coverage:**
For each `errorVariant` in `error-catalog.yaml`, verify at least one test exercises it.
Search test files for references to the error type name.

**Test execution:**
Run the test suite. Derive the command from `stack.build` in `ai26/config.yaml`:
- `gradle` → `./gradlew {module}:test`
- `maven` → `./mvnw test`
- `npm` → `npm test`

A failing test is a blocking violation.

On violation:

    ✗ Test coverage — BLOCKING
    Scenario "Cannot close an archived conversation" in close-conversation.feature
    has no matching "// Scenario: Cannot close an archived conversation" docstring in test sources.
    Proposed fix: add // Scenario: docstring to the corresponding @Test method.
    Apply fix? [yes / no / explain]

    ✗ Test coverage — BLOCKING
    CloseConversationUseCaseTest > cannot close archived conversation FAILED
    Expected: Either.Error(Archived)  Actual: Either.Success(...)
    Do you want me to investigate? [yes / no]

---

## Check 3 — Ticket ↔ Design coherence

Read the acceptance criteria from Jira (via MCP). For each AC, verify at least one
Gherkin scenario covers it.

Match by semantic similarity — the scenario does not need to quote the AC verbatim,
but it must exercise the same behaviour.

On violation:

    ✗ Ticket ↔ Design — BLOCKING
    Jira AC: "Agent receives a notification when conversation is escalated"
    No scenario found covering this AC.
    Proposed fix: add a scenario to escalate-conversation.feature.
    Apply fix? [yes / no / explain]

---

## Correction handling

For each violation, the engineer chooses:

- **yes / do it** → apply the proposed fix immediately
- **no** → violation stays open, engineer handles manually
- **explain** → LLM explains the violation in detail
- **defer** → violation recorded as explicitly deferred with reason

Deferred violations are included in the report and surfaced at promotion.
They do not block promotion but are visible.

---

## Severity

| Severity | Examples | Blocks promotion? |
|---|---|---|
| **Blocking** | Missing implementation, failing test, missing scenario, uncovered AC | Yes |
| **Warning** | Domain term not used in any scenario | No |

---

## Validation report

    Validation report — {TICKET-ID}
    ──────────────────────────────────────
    Design ↔ Code coherence    ✓ {N}/{N} elements traced
    Test coverage              ✓ {N}/{N} scenarios covered — all tests passing
    Ticket ↔ Design            ✓ {N}/{N} ACs covered

    Blocking violations: 0
    Warnings: {N}

    Status: PASS

    Next step: /ai26-promote-user-story {TICKET-ID}

On failure:

    Status: FAIL — resolve blocking violations before promotion

    Blocking violations:
    ✗ {violation 1}
    ✗ {violation 2}

Commit on pass:
```
git add ai26/features/{TICKET}/plan.md
git commit -m "{TICKET-ID} validate: all checks passing"
git push
```
