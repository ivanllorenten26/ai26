---
name: ai26-design-ticket
description: SDLC3 Phase 2a (standalone ticket). Evolved from ai26-design-user-story. Two modes via --fidelity: fidelity 2 (default) produces the full artefact set for a standalone feature with domain impact; fidelity 1 produces minimal artefacts for bug fixes or small changes. Use when a ticket has no epic-level design artefacts — i.e. it was not produced by ai26-design-epic.
argument-hint: "[TICKET-ID] [--fidelity 1|2]"
---

# ai26-design-ticket

Collaborative design for a standalone ticket. Produces the correct artefact set based on
fidelity level. Use when the ticket was not part of an epic designed with `ai26-design-epic`.

---

## Flags

| Flag | Default | Behaviour |
|---|---|---|
| `--fidelity 2` | default | Full artefact set. Standalone feature with domain/architecture impact. |
| `--fidelity 1` | | Minimal artefacts. Bug fix or small change that touches the domain. |

---

## Step 1 — Load context

Read in this order:
1. `ai26/config.yaml`
2. Ticket from Jira via MCP — description, ACs, epic link
3. Parent epic context (`ai26/epics/{EPIC}/prd.md`, `ai26/epics/{EPIC}/architecture.md`) if exists
4. `ai26/context/DOMAIN.md`
5. `ai26/context/ARCHITECTURE.md`
6. `ai26/context/DECISIONS.md` (if exists)
7. `ai26/context/DEBT.md` (if exists)
8. `docs/adr/` — titles only
9. `ai26/features/{TICKET}/` — existing artefacts if any
10. `ai26/context/LEARNINGS.md` (if exists) — scan for past observations relevant to this ticket's domain or bounded context. If any are found, surface them before starting the design conversation:

        Past lessons relevant to this ticket:
        OBS-007 | implement | skill — dev-create-aggregate generated public constructor (D-01)
        OBS-012 | design | context — accountId must be AccountId(UUID) value object, not String

    Reference these proactively during design to avoid repeating past mistakes.

**Migration context:** Check if this ticket is part of a legacy migration plan. Look for
`ai26/migrations/*/plan.md` files that reference this ticket's Jira ID. If found:
- Read `ai26/migrations/{MODULE}/assessment.yaml` — for the extracted contracts
- Read `ai26/migrations/{MODULE}/prd.md` — for the target architecture and strategy

Surface the constraints before the design conversation:

    Migration ticket detected — contract constraints apply:

    API contracts (NON-NEGOTIABLE — must be preserved):
      POST /conversations → 201 (same request/response shape)

    Database contracts (NON-NEGOTIABLE — no destructive changes):
      table "conversations" — columns must be preserved or migrated via Expand-Contract

    Target architecture from PRD:
      Aggregate: Conversation (Strangler Fig pattern)
      Use cases: OpenConversation, CloseConversation

    Design the new implementation to honour these constraints.
    If a contract change is needed, explicitly call it out and confirm with the engineer first.

**Fidelity inference:** If `--fidelity` was not provided, infer from the ticket:
- Ticket type is Bug → fidelity 1
- Title contains "fix", "patch", "bump", "update dependency" → fidelity 1
- Otherwise → fidelity 2

Confirm inferred fidelity:

    Ticket: {TICKET-ID} — {title}
    Inferred fidelity: {1|2} ({reason})
    Fidelity {1|2} artefacts: {list what will be produced}

    Correct, or override with --fidelity {1|2}?

**Module resolution:** From `ai26/config.yaml`, identify the target module(s):
1. Ticket or invocation explicitly names a module → use it
2. Only one module `active: true` → use it without asking
3. Multiple active modules → infer from ticket's bounded context, then confirm
4. Non-active (legacy) module involved → warn before proceeding

**If partial artefacts exist:**

    Found existing design workspace for {TICKET-ID}:
    ✓ domain-model.yaml
    ✗ error-catalog.yaml — missing

    A. Continue from where this left off
    B. Start fresh (confirm before overwriting)

---

## Step 2 — Fidelity 2: Full design conversation

*Use for standalone features with domain/architecture impact.*

### Open the conversation

    I've read {TICKET-ID}: "{title}".

    Context loaded:
    - {N} existing domain concepts in scope
    - {N} relevant ADRs
    - {debt area warnings if any}

    {first question or observation}

### Design conversation

Drive the conversation to cover all artefact areas. Let it flow naturally — do not use a rigid Q&A format. Cover:

- Domain model (aggregates, states, methods, invariants)
- Use cases (inputs, outputs, error paths, side effects)
- Error catalog (derived from use case error paths)
- API contracts (endpoints, if feature has HTTP surface)
- Events (published and consumed, if feature has event interactions)
- Glossary (new domain terms introduced)
- Ops checklist (migrations, feature flags, observability)

**Decision detection:** When a significant architectural decision arises, open the decision conversation. When committed:

    That decision is worth capturing. Should I document it as an ADR?

Write ADR immediately on confirmation:
```
git add docs/adr/{date}-{slug}.md
git commit -m "{TICKET-ID} adr: {title}"
git push
```

**Lightweight epic analysis (when no epic architecture exists):**
- Detect affected aggregates as they come up
- Flag DEBT.md areas when the conversation touches them
- Surface external dependencies as they are mentioned
- If DEBT.md RISK: alto area touched, recommend:

      This feature touches {area} which is marked RISK: alto in DEBT.md.
      Consider running /ai26-design-epic for a full epic-level analysis.
      Proceed anyway?

### Write artefacts progressively

Write each artefact as its area is settled. After writing:

    ✓ {artefact} written. Continue or "show it"?

Artefacts for fidelity 2:
- `domain-model.yaml`
- `use-case-flows.yaml`
- `error-catalog.yaml`
- `api-contracts.yaml` (only if HTTP surface)
- `events.yaml` (only if events involved)
- `glossary.yaml`
- `scenarios/` (one `.feature` per use case)
- `ops-checklist.yaml`
- `diagrams.md`

Write `fidelity: 2` in `ops-checklist.yaml`.

Commit per artefact:
```
git add ai26/features/{TICKET}/{artefact}
git commit -m "{TICKET-ID} design: {artefact description}"
git push
```

### Diagrams

Generate `diagrams.md` as the final artefact.

| Diagram type | Include when |
|---|---|
| Domain class diagram | Ticket introduces or modifies aggregates, entities, or value objects |
| State machine diagram | Aggregate has lifecycle with states and transitions |
| Sequence diagram (use case) | Use case crosses two or more components |
| Sequence diagram (event flow) | Ticket emits or consumes domain events |
| Component diagram | Ticket introduces new bounded context or external dependency |
| ER diagram | Ticket has Flyway migrations |

Use actual class/field names from `domain-model.yaml`. State diagram states match aggregate status enum values exactly.

---

## Step 2 — Fidelity 1: Abbreviated flow

*Use for bug fixes or small changes that touch the domain.*

### Open the conversation

    I've read {TICKET-ID}: "{title}".
    Fidelity 1 — abbreviated design for bug fix / small change.

    What I'll produce: scenarios + error-catalog + domain-model (if domain changes).

    Let me ask a few targeted questions.

### Abbreviated design conversation

Focus only on what changed. Cover:
- What is the current (broken) behaviour?
- What is the expected (fixed) behaviour?
- Does this require a new error case, state, or domain method?
- Are there edge cases or race conditions relevant to the fix?

Do NOT design the full domain model unless domain changes are required. Do NOT produce API contracts, events, glossary, or ops checklist unless directly affected by the fix.

If during the conversation the fix turns out to require:
- A new aggregate or bounded context
- A new event or topic
- New API endpoints
- Database schema changes

→ Escalate automatically:

    This fix requires changes that go beyond fidelity 1 scope:
    {reason}.
    Escalating to fidelity 2 — continuing with full design conversation.

Continue with Step 2 (Fidelity 2) from that point.

### Write artefacts

Artefacts for fidelity 1:
- `scenarios/` — one `.feature` per affected use case (required)
- `error-catalog.yaml` — only new or modified error cases (required)
- `domain-model.yaml` — only if domain model changes (conditional)
- `diagrams.md` — only if a state machine or sequence diagram aids understanding (conditional)

Write `fidelity: 1` in `ops-checklist.yaml` (minimal entry — just the fidelity marker plus any migration needed).

Commit:
```
git add ai26/features/{TICKET}/
git commit -m "{TICKET-ID} design: fidelity-1 artefacts"
git push
```

---

## Step 3 — Completeness check (fidelity 2 only)

1. Every `errorCase` in `use-case-flows.yaml` has an entry in `error-catalog.yaml`
2. Every endpoint in `api-contracts.yaml` references a `useCase` in `use-case-flows.yaml`
3. Every event side effect in `use-case-flows.yaml` has an entry in `events.yaml`
4. Every scenario covers at least happy path and one error path
5. Every domain term in `domain-model.yaml` appears in `glossary.yaml`
6. Every Jira AC has at least one corresponding scenario
7. `diagrams.md` exists and names match `domain-model.yaml`

Report violations. Engineer must resolve before closing.

---

## Step 4 — Close

    Design complete for {TICKET-ID}.
    Fidelity: {1|2}

    Artefacts written: {list}
    ADRs written: {list or "none"}
    Open items: {any warnings or deferred decisions}

    Next step: /ai26-implement-user-story {TICKET-ID}
