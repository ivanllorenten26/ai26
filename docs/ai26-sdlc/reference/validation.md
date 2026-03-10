# Validation

> How AI26 ensures that what was designed is what was built, and that it works correctly.

---

## Responsibilities

Validation in AI26 has three distinct responsibilities:

```
1. Design ↔ Code coherence
   Everything defined in the artefacts exists in the code.

2. Test coverage
   Every designed scenario has a test. Every test passes.

3. Ticket ↔ Design coherence
   Every acceptance criterion in Jira is reflected in the scenarios.
```

Validation does not check code quality or architectural patterns. Those are guaranteed
by the implementation skills — if a skill generates code, that code follows the correct
patterns by construction. Validation checks that the right things were built, and that
they work.

---

## When validation runs

Validation runs automatically at the end of `ai26-implement-user-story`. The engineer
does not invoke it manually — it is a gate, not an optional step.

If validation fails, `ai26-implement-user-story` does not complete. The engineer must
resolve the violations before the feature is considered done.

Validation can also be run independently at any point:

    /ai26-validate-user-story TICKET-123

This is useful when the engineer has made manual changes outside the implementation
flow and wants to check coherence before continuing.

---

## Responsibility 1 — Design ↔ Code coherence

For each element defined in the artefacts, the LLM checks that a corresponding
implementation exists in the codebase.

| Artefact element | What must exist in code |
|---|---|
| Use case in `use-case-flows.yaml` | A class implementing that use case |
| Error variant in `error-catalog.yaml` | A type representing that error |
| Endpoint in `api-contracts.yaml` | A handler method for that path + method |
| Event in `events.yaml` (published) | A publisher for that event |
| Event in `events.yaml` (consumed) | A handler for that event |
| Aggregate in `domain-model.yaml` | A class representing that aggregate |

The LLM does not check implementation details — it checks existence and naming coherence.
It does not know or care which specific files or classes are used, as long as the
mapping is traceable.

If an element is missing:

    Validation issue — Design ↔ Code coherence:

    use-case-flows.yaml defines CloseConversation but no corresponding
    implementation was found in the codebase.

    Proposed fix: generate the CloseConversation use case implementation.
    Shall I do that now?

---

## Responsibility 2 — Test coverage

The LLM checks that every scenario defined in the design has a corresponding test,
and that all tests pass.

**Scenario coverage:**
Every Gherkin scenario in `ai26/features/{TICKET}/scenarios/` must have a step definition.
Scenarios without step definitions are blocking — they represent untested behaviour.

**Error path coverage:**
Every error variant in `error-catalog.yaml` must be exercised by at least one test.
An error type that is defined but never tested is a gap.

**Test execution:**
The LLM runs the test suite and checks that all tests pass. A failing test is a
blocking violation — the feature is not done until tests pass.

If a scenario has no step definition:

    Validation issue — Test coverage:

    Scenario "Cannot close an archived conversation" in close-conversation.feature
    has no step definition.

    Proposed fix: generate the step definition for this scenario.
    Shall I do that now?

If a test fails:

    Validation issue — Test coverage:

    CloseConversationTest > cannot close archived conversation FAILED
    Expected: 422 Unprocessable Entity
    Actual:   200 OK

    This looks like a missing status check in the use case implementation.
    Do you want me to investigate the failing test?

---

## Responsibility 3 — Ticket ↔ Design coherence

The LLM reads the acceptance criteria from the Jira ticket (via MCP) and checks
that each AC is covered by at least one Gherkin scenario.

If an AC has no corresponding scenario:

    Validation issue — Ticket ↔ Design coherence:

    Jira AC: "Agent receives a notification when a conversation is escalated to them"
    No scenario found that covers this acceptance criterion.

    Proposed fix: add a scenario to escalate-conversation.feature for this AC.
    Shall I draft it?

This check catches cases where the design drifted from the original ticket requirements —
features that were designed but not what was asked, or requirements that were forgotten
during the design conversation.

---

## Violation severity

Not all violations are equal. The LLM classifies them:

| Severity | Meaning | Blocks promotion? |
|---|---|---|
| **Blocking** | The feature is incomplete or incorrect | Yes |
| **Warning** | A gap that should be addressed but does not indicate incorrectness | No |

Blocking violations:
- A use case defined in artefacts has no implementation
- A Gherkin scenario has no step definition
- A test is failing
- A Jira AC has no corresponding scenario

Warnings:
- An artefact element exists in code but is not referenced in any test
- A domain term in the glossary is not used in any artefact

---

## Proposed corrections

When the LLM finds a violation, it always proposes a correction. It never just reports
and leaves the engineer to figure it out.

The engineer can:

    "Yes" / "Do it"   → LLM applies the correction immediately
    "No"              → violation stays open, engineer handles it manually
    "Explain"         → LLM explains why it flagged this and what the correct state looks like
    "Defer"           → violation is recorded as explicitly deferred with a reason

Deferred violations are included in the validation report and must be acknowledged
before promotion. They do not block promotion — but they are visible.

---

## Validation report

After all checks complete, the LLM produces a summary:

    Validation report — TICKET-123
    ──────────────────────────────────────────────────────

    Design ↔ Code coherence       ✓ 5/5 elements traced
    Test coverage                 ✓ 4/4 scenarios covered — all tests passing
    Ticket ↔ Design coherence     ✓ 3/3 ACs covered

    Blocking violations:          0
    Warnings:                     1
      ⚠ Domain term "Inbox" in glossary.yaml not used in any scenario

    Status: PASS — ready for promotion

    Next step: /ai26-promote-user-story TICKET-123

If there are blocking violations:

    Status: FAIL — resolve blocking violations before promotion

    Blocking violations:
      ✗ CloseConversation implementation not found
      ✗ Scenario "Cannot close archived conversation" has no step definition

    Proposed corrections are available above. Resolve them and re-run validation,
    or run /ai26-implement-user-story TICKET-123 to retry the full implementation.

---

## What validation does not do

- Does not check code style or formatting — that belongs in CI linting
- Does not check architectural patterns — guaranteed by implementation skills
- Does not replace human code review — `ai26-review-user-story` covers first-pass review
- Does not check performance or security — out of scope for this gate
