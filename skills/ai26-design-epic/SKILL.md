---
name: ai26-design-epic
description: SDLC3 Phase 1b+1c+2a combined. Absorbs architecture analysis, epic decomposition, and full per-ticket design into 5 internal phases. Produces architecture.md, ADRs, monolithic epic design, per-ticket artefacts, and Jira tickets — in that order. Jira ticket creation is the last step, not a mid-pipeline checkpoint. Use after ai26-write-prd. Accepts flags: --interactive (conversational mode per ticket), --tickets (comma-separated subset), --resume (continue from a previous run).
argument-hint: "[EPIC-ID] [--interactive] [--tickets TBD-1,TBD-3] [--resume]"
---

# ai26-design-epic

Produces the complete design for an entire epic in 5 internal phases:
architecture → monolithic domain design → slice into tickets → write artefacts → materialise Jira.

Replaces the previous three-skill sequence: `ai26-design-epic-architecture` → `ai26-decompose-epic` → `ai26-design-epic`.

---

## Flags

| Flag | Default | Behaviour |
|---|---|---|
| `--interactive` | off | Conversational mode: asks design questions ticket by ticket. More control. |
| `--tickets TBD-1,TBD-3` | all | Design only the listed tickets. |
| `--resume` | off | Detect existing artefacts and skip completed phases. |

Default mode is **semi-automatic**: infers design decisions from PRD and context, interrupts only when genuinely uncertain.

---

## Phase 1 — Load context

Read in this order:
1. `ai26/epics/{EPIC}/prd.md` — required. Stop if missing: "Run /ai26-write-prd first."
2. `ai26/config.yaml`
3. `ai26/context/DOMAIN.md`
4. `ai26/context/ARCHITECTURE.md`
5. `ai26/context/DECISIONS.md` (if exists)
6. `ai26/context/DEBT.md` (if exists)
7. `docs/architecture/modules/` — existing module docs (summary)
8. `docs/adr/` — titles only

**Resume detection:** Check what already exists:
- `ai26/epics/{EPIC}/architecture.md` → Phase 2 already done, skip to Phase 3
- `ai26/epics/{EPIC}/design/` → Phase 3 already done, skip to Phase 4
- `ai26/features/{TBD-N}/` dirs → Phase 4 partially done, resume from first incomplete ticket
- `ai26/epics/{EPIC}/plan.md` with real Jira IDs → Phase 5 done

Show the engineer what was found:

    Epic: {EPIC-ID} — {title}
    prd.md: ✓ ({date})
    architecture.md: ✓ / ✗ missing
    design/: ✓ / ✗ missing
    features/: {N} ticket dirs found / ✗ none

    Starting from Phase {N}.

Wait for confirmation before proceeding.

---

## Phase 2 — Architecture

*Absorbs: ai26-design-epic-architecture Steps 2–6*

Silently analyse the PRD against the loaded context. Detect:
- Which existing aggregates and bounded contexts are affected
- New domain concepts not in `DOMAIN.md`
- Likely database schema changes
- DEBT.md areas touched
- New inter-component communication patterns
- External service dependencies

Open a brief architecture conversation with the engineer. Surface findings:

    I've read the PRD for {EPIC-ID}: {title}.

    Before we design, here is what I found:
    Domain: {affected aggregates, or "new domain area"}
    Debt:   {RISK:alto areas, or "none touched"}
    Schema: {migrations likely / no schema changes expected}
    ADRs:   {relevant existing ADRs, or "none"}

    {first question or observation}

**DEBT.md RISK: alto areas require explicit acknowledgement** before continuing.

Work through these areas in conversation:
- **Affected domain concepts** — which aggregates modified, new aggregates or BCs introduced, lifecycle states extended
- **Database implications** — new tables/columns/indexes, migration approach
- **Inter-component communication** — new sync calls, new async events/topics
- **Epic-level architectural decisions** — decisions required before decomposition makes sense
- **External dependencies** — services the epic depends on but does not own

When an architectural decision is committed:

    That decision is worth capturing. Should I document it as an ADR?

Write ADR immediately on confirmation:
```
git add docs/adr/{date}-{slug}.md
git commit -m "{EPIC-ID} adr: {title}"
git push
```

When the conversation is complete, write `ai26/epics/{EPIC}/architecture.md`:

```markdown
# Epic Architecture — {title}

Epic: {EPIC-ID}
Date: {YYYY-MM-DD}

## Affected domain concepts

| Concept | Status | Notes |
|---|---|---|
| {name} | new / modified / existing | {notes} |

## Database implications

{description, or "No schema changes expected."}

## Debt areas touched

| Area | Risk | Decision |
|---|---|---|
| {area} | {level} | acknowledged / will be addressed |

## Epic-level decisions

| Decision | ADR |
|---|---|
| {decision} | {adr file} |

## External dependencies

| Dependency | Type | Status |
|---|---|---|
| {name} | sync / async | confirmed / TBD |

## Notes for decomposition

{Sequencing constraints, rough effort signals, risks.}
```

Commit:
```
git add ai26/epics/{EPIC}/architecture.md
git commit -m "{EPIC-ID} architecture: epic technical context"
git push
```

---

## Phase 3 — Monolithic design

*New phase — replaces per-ticket design-user-story runs*

Design the ENTIRE epic as a single coherent block before any ticket boundary exists. The domain model, events, and contracts belong to the domain — not to tickets. Slicing is a size concern handled in Phase 4.

Write to `ai26/epics/{EPIC}/design/`. This directory is the source of truth for the full epic domain model. Individual ticket artefacts in Phase 4 are slices of this.

### 3a — Domain model

Produce `ai26/epics/{EPIC}/design/domain-model.yaml` covering ALL aggregates, entities, value objects, and lifecycle states introduced or modified by this epic.

Follow coding rules D-01 through D-14 from `ai26/config.yaml`.

In semi-automatic mode: derive from PRD use cases + architecture.md affected concepts. Interrupt only if a new aggregate has no model in architecture.md:

    The PRD introduces {concept} but architecture.md has no model for it.
    What fields and lifecycle states should it have?

### 3b — Use case flows

Produce `ai26/epics/{EPIC}/design/use-case-flows.yaml` covering ALL use cases from the PRD — happy paths and error paths.

Map each error path to domain errors using patterns from `ai26/context/DECISIONS.md`.

### 3c — Error catalog

Produce `ai26/epics/{EPIC}/design/error-catalog.yaml` covering ALL errors across all use cases.

### 3d — API contracts

Produce `ai26/epics/{EPIC}/design/api-contracts.yaml` for ALL HTTP endpoints introduced or modified.

Derive from PRD use cases and existing API patterns in `ai26/context/INTEGRATIONS.md`. Interrupt if a new resource path cannot be inferred.

### 3e — Events

Produce `ai26/epics/{EPIC}/design/events.yaml` for ALL domain events introduced or modified.

Derive from architecture.md and PRD use case side effects.

### 3f — Glossary

Produce `ai26/epics/{EPIC}/design/glossary.yaml` for ALL new domain terms introduced by the epic.

### 3g — Ops checklist

Produce `ai26/epics/{EPIC}/design/ops-checklist.yaml` covering:
- Flyway migrations (from architecture.md database implications)
- New external dependencies
- New Kafka topics (from events)
- Feature flags
- Observability (metrics, alerts)

Flag infra provisioning items as `TODO: requires infra`.

After writing each artefact:

    ✓ design/{artefact} written. Continue or "show it"?

Commit the full monolithic design as one commit:
```
git add ai26/epics/{EPIC}/design/
git commit -m "{EPIC-ID} design: monolithic epic design complete"
git push
```

---

## Phase 4 — Slice into tickets

*Absorbs: ai26-decompose-epic Steps 2–3*

The domain model, contracts, and events are already fully specified. Slicing is purely about keeping PRs reviewable and deployable independently.

### 4a — Propose decomposition

Analyse the monolithic design and PRD use cases. Propose an initial decomposition:

    Based on the PRD and monolithic design, I suggest {N} tickets:

    TBD-1 — {title}
      Value: {what changes for a user when this is merged}
      ACs: {from PRD use cases}
      Domain slice: {aggregates/methods from design/domain-model.yaml}
      API slice: {endpoints from design/api-contracts.yaml}
      Events: {events from design/events.yaml}
      Ops: {migrations/infra items from design/ops-checklist.yaml}
      Risk: {BAJO/MEDIO/ALTO} — {reason}
      Depends on: {TBD-N or "nothing"}

    TBD-2 — ...

    Does this decomposition make sense?
    You can merge, split, or reorder before I distribute artefacts.

Rules for decomposition:
- Each ticket delivers **user-observable value** independently
- Each ticket crosses all technical layers (domain, application, infrastructure, API, tests)
- Tickets should be independently deployable when merged
- Flag horizontal decompositions (single-layer work) and reject them

### 4b — Distribute artefacts

Once decomposition is confirmed, distribute the monolithic design into per-ticket directories.

For each ticket TBD-N:
- Create `ai26/features/TBD-N/`
- Write the slice of `domain-model.yaml` relevant to this ticket's scope
- Write the slice of `use-case-flows.yaml` for this ticket's use cases
- Write the slice of `error-catalog.yaml` for this ticket's errors
- Write `api-contracts.yaml` if this ticket has HTTP surface
- Write `events.yaml` if this ticket emits/consumes events
- Write `glossary.yaml` for terms introduced in this ticket
- Write `ops-checklist.yaml` for migrations/infra needed by this ticket
- Write `scenarios/` — one `.feature` file per use case with ACs as scenarios
- Write `diagrams.md` — see diagram rules below

**Scenarios generation rules:**
- One scenario per AC from the ticket description
- At least one error path scenario per error in use-case-flows.yaml
- Use `# Scenario:` docstring convention from coding rules T-04

**Diagram rules:**

| Diagram type | Include when |
|---|---|
| Domain class diagram | Ticket introduces or modifies aggregates, entities, or value objects |
| State machine diagram | Aggregate has lifecycle with states and transitions |
| Sequence diagram (use case) | Use case crosses two or more components |
| Sequence diagram (event flow) | Ticket emits or consumes domain events |
| Component diagram | Ticket introduces new bounded context or external dependency |
| ER diagram | Ticket has Flyway migrations |

Write a `fidelity: 2` marker in each ticket's `ops-checklist.yaml` so downstream skills know the full artefact set is present.

Write `plan.md`:

```markdown
# Epic Plan — {EPIC-ID}

Epic: {EPIC-ID}
Title: {title}
Status: in_progress
Created: {date}
Last updated: {date}

## Stories

| ID | Title | Risk | Status | Branch |
|---|---|---|---|---|
| TBD-1 | {title} | {risk} | designed | — |
| TBD-2 | {title} | {risk} | designed | — |
```

Commit per ticket (not per artefact):
```
git add ai26/features/TBD-N/
git commit -m "TBD-N design: full artefact set"
git push
```

Show progress:

    ✓ TBD-1 — {title}
      domain-model.yaml, use-case-flows.yaml, error-catalog.yaml,
      api-contracts.yaml, events.yaml, scenarios/ ({N} scenarios),
      ops-checklist.yaml, diagrams.md ({diagram types})
      ──────────────────────────────
      {N-remaining} tickets remaining.

---

## Phase 5 — Materialise Jira tickets

*Absorbs: ai26-decompose-epic Steps 4–5*

Jira ticket creation is the LAST step. Local artefacts are complete before any Jira call.

Check Jira for existing child tickets under the epic. If tickets already exist, show them and ask:

    {N} tickets already exist under {EPIC-ID}:
    - {TICKET-ID}: {title} ({status})

    Do you want to:
    A. Map existing Jira tickets to TBD-N dirs (rename dirs to real IDs)
    B. Create new tickets for TBD-N dirs that have no Jira counterpart
    C. Skip Jira creation (keep TBD-N dirs as-is)

For each TBD-N without a Jira ticket, create in Jira via MCP:
- Title (from plan.md)
- Description (from PRD use case, in business language)
- Acceptance criteria (from scenarios/ feature files)
- Technical notes (from architecture.md, labelled as technical context)
- Epic link
- Risk label
- Dependency links

Show progress:

    ✓ Created AS-1234: {title}
    ✓ Created AS-1235: {title}

After all tickets are created, rename `TBD-N` directories to real Jira IDs:
```
git mv ai26/features/TBD-1 ai26/features/AS-1234
git mv ai26/features/TBD-2 ai26/features/AS-1235
```

Update `plan.md` with real IDs and commit:
```
git add ai26/epics/{EPIC}/plan.md ai26/features/
git commit -m "{EPIC-ID} decompose: {N} tickets created in Jira — TBD dirs renamed"
git push
```

---

## Cross-epic completeness check

After Phase 4 (before Phase 5), validate:

1. Every UC in `prd.md` is covered by at least one ticket's use-case-flows.yaml
2. Every domain concept in `architecture.md → Affected domain concepts` appears in at least one `domain-model.yaml`
3. No two tickets define conflicting models for the same aggregate
4. Every open question in `prd.md` that affects a designed ticket is resolved or flagged in ops-checklist.yaml

Report violations:

    Cross-epic validation:
    ✓ All PRD use cases covered
    ✗ Conflict: Conversation.sessionId typed as UUID in TBD-1 but String in TBD-3
    ✗ Open question #6 (NFRs) affects TBD-5 — not resolved

Require the engineer to resolve conflicts before Phase 5.

---

## Close

    Epic design complete for {EPIC-ID}.

    Tickets designed: {N}
    Artefacts written: {total}
    ADRs written: {list or "none"}
    Jira tickets created: {N or "skipped"}

    Next step: pick a ticket and run /ai26-implement-user-story {TICKET-ID}
    Recommended starting point: {lowest-dependency ticket}
