---
name: ai26-refine-user-story
description: SDLC3 utility. Lightweight artefact editor for an existing ai26/features/{TICKET}/ workspace. Updates a single design artefact without re-running the full ai26-design-user-story conversation. Use when a small change is needed after design is complete — a new error case, a renamed field, an added state.
argument-hint: [TICKET-ID] [artefact?] — Jira ticket ID, optional artefact name to edit
---

# ai26-refine-user-story

Targeted artefact editor. Does not re-run the design conversation. Does not touch
artefacts that are not relevant to the change. Checks downstream consequences
and surfaces them before writing.

Use when:
- A new error case was discovered during implementation
- A field was renamed and needs updating across artefacts
- An AC was clarified and a scenario needs updating
- A state was added to the domain model

Do not use when:
- The scope of the ticket itself changed — that requires re-running `ai26-design-user-story`
- Multiple artefacts need structural changes — the full design conversation handles this better

---

## Step 1 — Load context

Read:
1. `ai26/features/{TICKET}/domain-model.yaml`
2. `ai26/features/{TICKET}/use-case-flows.yaml`
3. `ai26/features/{TICKET}/error-catalog.yaml`
4. `ai26/features/{TICKET}/api-contracts.yaml` (if exists)
5. `ai26/features/{TICKET}/events.yaml` (if exists)
6. `ai26/features/{TICKET}/glossary.yaml` (if exists)
7. `ai26/features/{TICKET}/scenarios/` — list all feature files
8. `ai26/config.yaml`

If the engineer specified an artefact name as argument, focus on that file.
If not, ask:

    Which artefact do you want to update?
    1. domain-model.yaml
    2. use-case-flows.yaml
    3. error-catalog.yaml
    4. api-contracts.yaml
    5. events.yaml
    6. scenarios/
    7. glossary.yaml

---

## Step 2 — Understand the change

Ask for the change if not already described:

    What needs to change in {artefact}?

Accept freeform input. Examples the LLM must handle:

- "Add a ESCALATED state to Conversation"
- "Rename field closedAt to resolvedAt in CloseConversation output"
- "Add error case: conversation belongs to a different customer"
- "Add a scenario for the case where the agent is not assigned"
- "The notification field in ops-checklist should be high priority, not medium"

---

## Step 3 — Analyse downstream consequences

Before writing any change, analyse which other artefacts reference the element
being modified.

Cross-reference rules:

| Changed in | May affect |
|---|---|
| `domain-model.yaml` — aggregate property or state | `use-case-flows.yaml` (inputs/outputs), `api-contracts.yaml` (request/response schemas), `error-catalog.yaml` (conditions), `scenarios/` (scenario data) |
| `use-case-flows.yaml` — use case name or output type | `api-contracts.yaml` (endpoint), `events.yaml` (side effects), `scenarios/` (feature file title) |
| `error-catalog.yaml` — error variant name | `use-case-flows.yaml` (errorCases), `api-contracts.yaml` (error responses), `scenarios/` (scenario titles) |
| `api-contracts.yaml` — field name or status code | `scenarios/` (expected response data) |
| `events.yaml` — payload field | `scenarios/` (event assertions) |

Surface consequences before writing:

    Proposed change:
      domain-model.yaml — rename property closedAt → resolvedAt on Conversation

    Downstream consequences:
      use-case-flows.yaml — CloseConversation output references closedAt → needs update
      api-contracts.yaml  — GET /conversations/{id} response has closedAt field → needs update
      scenarios/          — close-conversation.feature checks "closedAt" in response → needs update

    Apply all changes? [yes / yes but show each / no — I'll handle manually]

If the engineer says "yes but show each", show a diff for each file before writing it.

---

## Step 4 — Apply changes

For each file to update:

1. Show the proposed diff in a readable format:

       domain-model.yaml — Conversation aggregate
       - closedAt: Instant
       + resolvedAt: Instant

2. Write the change only after confirmation (or if engineer said "yes" to all).

3. Update the `status` field of the modified entry:
   - If it was `existing` → change to `modified`
   - If it was `new` → keep as `new` (already a new entry)
   - If it was already `modified` → keep as `modified`

---

## Step 5 — Commit

```
git add ai26/features/{TICKET}/
git commit -m "{TICKET-ID} refine: {brief description of change}"
git push
```

---

## Step 6 — Report

    Refinement complete — {TICKET-ID}
    ──────────────────────────────────────────────────────

    Change applied:
      {description of what changed}

    Files updated:
      {list of updated files}

    If implementation is already in progress:
      Run /ai26-validate-user-story {TICKET-ID} to check code still matches artefacts.
