# Engineer Guide

End-to-end tutorial: take a Jira ticket from `/ai26-start-sdlc` through design, implement, validate, review, and promote. Audience: product engineers.

---

## Prerequisites

- Claude Code installed and configured
- AI26 skills installed (`/marketplace install ai26`)
- Jira MCP connected to your project
- `ai26/config.yaml` and `ai26/context/` files in place (run `/ai26-start-sdlc --check` to verify)

---

## The shape of a ticket lifecycle

Every ticket follows the same five-step sequence:

```
1. Design       /ai26-design-ticket {TICKET-ID}
      ↓
2. Implement    /ai26-implement-user-story {TICKET-ID}
      ↓
3. Validate     (automatic at end of implement)
      ↓
4. Review       /ai26-review-user-story {TICKET-ID}
      ↓
5. Promote      /ai26-promote-user-story {TICKET-ID}
      ↓
   Open PR
```

For epics, step 1 is replaced by `/ai26-write-prd` + `/ai26-design-epic`. For quick fixes, all five steps collapse into `/ai26-implement-fix`.

---

## Step 0 — Start from any entry point

Always begin with:

```
/ai26-start-sdlc SXG-1234
```

The skill reads your Jira ticket, scans `ai26/context/`, and recommends a flow. It tells you:

```
Ticket: SXG-1234 — Add endpoint to fetch conversation analysis results
Type: Standalone feature with domain impact
Recommended flow: Flow B (Fidelity 2)

Next step: /ai26-design-ticket SXG-1234
```

If you already know the flow, you can skip `ai26-start-sdlc` and call the design skill directly.

---

## Step 1 — Design

Run the design skill:

```
/ai26-design-ticket SXG-1234
```

The skill opens a structured conversation. It reads `ai26/context/DOMAIN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, and `DEBT.md` first, then reads the Jira ticket. It will ask you questions — answer them honestly and completely.

**What it asks:**

- Which bounded context does this belong to?
- What aggregate does this use case operate on?
- What are all the error cases? (Not just the happy path)
- Does this introduce any new domain events?
- Are there new DB migrations required?
- Does this touch any area flagged in `DEBT.md`?

**What you do:**

You answer, challenge, and approve. When the AI proposes a domain model, push back if it is wrong. The quality of the artefacts depends on the quality of this conversation.

**What it produces:**

A full artefact set committed to `ai26/features/SXG-1234/`:

```
ai26/features/SXG-1234/
  domain-model.yaml         ← aggregates, states, methods
  use-case-flows.yaml       ← use cases, error cases, side effects
  api-contracts.yaml        ← endpoints, request/response shapes
  error-catalog.yaml        ← all error types, HTTP status codes
  glossary.yaml             ← new domain terms
  scenarios/
    fetch-analysis.feature  ← Gherkin BDD scenarios
  ops-checklist.yaml        ← migrations, feature flags, alerts
  diagrams.md               ← Mermaid class, sequence, ER diagrams
```

**Sample artefact snippet** — `use-case-flows.yaml`:

```yaml
useCases:
  - name: FetchConversationAnalysis
    actor: Agent
    input:
      - name: conversationId
        type: String
    output:
      type: ConversationAnalysisDTO
    errorCases:
      - condition: "conversation does not exist"
        error: ConversationNotFound
      - condition: "analysis not yet available"
        error: AnalysisNotAvailable
    sideEffects: []
    dependsOn: []
```

**Sample artefact snippet** — `scenarios/fetch-analysis.feature`:

```gherkin
Feature: Fetch conversation analysis results

  Background:
    Given a conversation exists with id "conv-123" and status CLOSED

  Scenario: Successfully fetch analysis for a closed conversation
    Given analysis results exist for conversation "conv-123"
    When I fetch analysis for conversation "conv-123"
    Then the response is 200
    And the analysis results are returned

  Scenario: Cannot fetch analysis for a non-existent conversation
    When I fetch analysis for conversation "unknown-id"
    Then the response is 404

  Scenario: Cannot fetch analysis when it is not yet available
    Given no analysis exists for conversation "conv-123"
    When I fetch analysis for conversation "conv-123"
    Then the response is 422
```

**At the end of the design phase**, the skill validates cross-references between artefacts (every error case in `use-case-flows.yaml` must have an entry in `error-catalog.yaml`, every endpoint must reference a use case, etc.) and asks for your sign-off before closing.

---

## Step 2 — Implement

Once the artefacts are committed and you are satisfied with the design:

```
/ai26-implement-user-story SXG-1234
```

The skill reads your artefacts and proposes an implementation plan:

```
Implementation plan — SXG-1234

1. Domain: no new aggregate — FetchConversationAnalysis reads existing Conversation aggregate
2. Use case: FetchConversationAnalysis (new)
   - Reads ConversationRepository + AnalysisRepository
   - Returns Either<FetchAnalysisDomainError, ConversationAnalysisDTO>
3. Infrastructure/inbound: GET /api/v1/conversations/{id}/analysis
   - ConversationController — add fetchAnalysis() method
4. Error types: FetchAnalysisDomainError sealed class (ConversationNotFound, AnalysisNotAvailable)
5. Tests:
   - FetchConversationAnalysisUseCaseTest (use case unit tests)
   - ConversationControllerTest additions (controller slice tests)
   - FetchConversationAnalysisFeatureTest (full-stack BDD)

Proceed with implementation? [yes / adjust]
```

You review the plan. If something is wrong, correct it before saying yes — this is far cheaper than fixing generated code.

Once you approve, the agent implements autonomously. It calls the scaffolding skills internally (`dev-create-use-case`, `dev-create-rest-controller`, `test-create-feature-tests`, etc.) and commits each logical unit with the ticket ID:

```
SXG-1234 implement FetchConversationAnalysis use case
SXG-1234 add GET /api/v1/conversations/{id}/analysis endpoint
SXG-1234 add feature tests for conversation analysis
```

**Sample generated use case:**

```kotlin
@Service
@Transactional
class FetchConversationAnalysis(
    private val conversationRepository: ConversationRepository,
    private val analysisRepository: AnalysisRepository
) {
    operator fun invoke(
        conversationId: String
    ): Either<FetchAnalysisDomainError, ConversationAnalysisDTO> {
        val id = ConversationId.fromString(conversationId)
        conversationRepository.findById(id)
            ?: return Either.Error(FetchAnalysisDomainError.ConversationNotFound(id))

        val analysis = analysisRepository.findByConversationId(id)
            ?: return Either.Error(FetchAnalysisDomainError.AnalysisNotAvailable(id))

        return Either.Success(analysis.toDTO())
    }
}
```

---

## Step 3 — Validate (automatic)

Validation runs automatically at the end of `ai26-implement-user-story`. You do not invoke it manually. It checks:

1. **Design-to-code coherence** — every use case, error type, endpoint, and event in the artefacts has a corresponding implementation
2. **Test coverage** — every Gherkin scenario has a step definition; all tests pass
3. **Ticket-to-design coherence** — every Jira acceptance criterion has a Gherkin scenario

**If it passes:**

```
Validation report — SXG-1234
─────────────────────────────────────
Design ↔ Code coherence    ✓ 4/4 elements traced
Test coverage              ✓ 3/3 scenarios covered — all tests passing
Ticket ↔ Design coherence  ✓ 2/2 ACs covered

Blocking violations: 0
Warnings: 0

Status: PASS — ready for promotion
Next step: /ai26-promote-user-story SXG-1234
```

**If it fails:**

The skill proposes corrections. Accept them (`"yes"`) to have the agent fix them automatically, or handle them manually and re-run:

```
/ai26-validate-user-story SXG-1234
```

You can also run this at any point if you have made manual changes outside the implementation flow.

---

## Step 4 — Review

```
/ai26-review-user-story SXG-1234
```

This is an automated first-pass code review. It checks:

- Architectural compliance (layer rules CC-01 through I-06)
- Naming conventions
- Error handling patterns
- Test completeness
- Artefact-to-code coherence

It produces a structured report with any rule violations labelled by ID (e.g., `D-01`, `CC-03`). You address the findings before promoting.

The automated review does not replace human review. It removes the mechanical checks so your human reviewer can focus on business logic and strategic implications.

---

## Step 5 — Promote

```
/ai26-promote-user-story SXG-1234
```

This is the Compound step. It:

1. Merges feature artefacts into `docs/architecture/modules/{module}/` (accumulative — nothing is overwritten silently)
2. Indexes any new ADRs from `docs/adr/`
3. Proposes updates to `ai26/context/` files (you confirm each one individually)
4. Asks whether to delete the feature workspace `ai26/features/SXG-1234/`

**Sample promotion report:**

```
Promotion complete — SXG-1234
──────────────────────────────────────────────────────

Module documentation updated:
  docs/architecture/modules/chat/use-case-flows.yaml
    + FetchConversationAnalysis (new)

  docs/architecture/modules/chat/error-catalog.yaml
    + FetchAnalysisDomainError (new)
    + FetchAnalysisDomainError.AnalysisNotAvailable (new)

  docs/architecture/modules/chat/api-contracts.yaml
    + GET /api/v1/conversations/{id}/analysis (new)

Context updates applied:
  ai26/context/DOMAIN.md: AnalysisNotAvailable added to ubiquitous language

Feature workspace:
  ai26/features/SXG-1234/ can be deleted. Keep it? [yes/no]
```

---

## Step 6 — Open the PR

After promotion, push your branch and open the PR:

```bash
git push -u origin feature/SXG-1234-fetch-analysis
gh pr create --title "SXG-1234 add GET /conversations/{id}/analysis endpoint"
```

The PR description should reference the ticket and note that artefacts are promoted. Human reviewers can read `ai26/features/SXG-1234/` (if kept) or the promoted docs for context.

---

## Commit message conventions

All commit messages must start with the Jira ticket ID:

```
SXG-1234 implement FetchConversationAnalysis use case
SXG-1234 add controller endpoint and feature tests
SXG-1234 promote artefacts to architecture docs
```

---

## Handling quick fixes

For a typo, dependency bump, or obvious single-file bug, skip the design step:

```
/ai26-implement-fix SXG-999
```

The agent reads the ticket, evaluates whether it is genuinely simple, implements, runs tests, and commits. If it discovers the fix is more complex than expected (touches DEBT.md `alto` areas, requires a migration, touches more than 3 files non-trivially), it escalates automatically to `/ai26-design-ticket --fidelity 1` and continues from there.

---

## Handling interruptions

If your session is interrupted mid-implement, re-run the skill with the same ticket ID:

```
/ai26-implement-user-story SXG-1234
```

The skill detects existing artefacts and partial implementation, and resumes from the right point. The same applies to `ai26-design-epic` — it resumes from the last completed phase.

---

## What to check in review

When reviewing a PR produced by AI26:

- **Artefacts match intent** — read `ai26/features/{TICKET}/` or the promoted docs. Does the domain model reflect what was actually decided?
- **Gherkin docstrings in tests** — do the `// Scenario:` comments accurately describe what each test exercises?
- **Error cases are complete** — is every variant in `error-catalog.yaml` covered by a test?
- **No over-implementation** — is there code that does something not in the spec?
- **Context updates are accurate** — do the proposed `ai26/context/` changes reflect what was actually decided in this feature?

---

## Reference

- [Skill Catalog](./skill-catalog.md) — full list of available skills
- [Conventions Cheatsheet](./conventions-cheatsheet.md) — layer rules, naming, error handling at a glance
- [Troubleshooting](./troubleshooting.md) — FAQ for common failures
- [Artefacts reference](../ai26-sdlc/reference/artefacts.md) — full YAML schema for every artefact
- [Validation reference](../ai26-sdlc/reference/validation.md) — how validation works in detail
- [Promotion reference](../ai26-sdlc/reference/promotion.md) — what promotion does and where things go
