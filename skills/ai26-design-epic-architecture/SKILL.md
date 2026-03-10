---
name: ai26-design-epic-architecture
description: SDLC3 Phase 1b. Architect + LLM analyse the PRD to produce the technical context for an epic — affected domain concepts, database implications, debt areas, and epic-level architectural decisions. Use after ai26-write-prd and before ai26-decompose-epic.
argument-hint: [EPIC-ID] — Jira epic ID
---

# ai26-design-epic-architecture

Produces the technical context for an epic. Reads the PRD and the repository context,
surfaces technical implications, and opens a conversation with the architect to make
any epic-level architectural decisions before ticket decomposition.

---

## Step 1 — Load context

Read in this order:
1. `ai26/epics/{EPIC}/prd.md` — the approved PRD (required — stop if missing)
2. `ai26/config.yaml` — interaction style
3. `ai26/context/DOMAIN.md`
4. `ai26/context/ARCHITECTURE.md`
5. `ai26/context/DECISIONS.md` (if exists)
6. `ai26/context/DEBT.md` (if exists)
7. `docs/architecture/modules/` — existing module documentation
8. `docs/adr/` — existing ADRs (titles only for initial load)

If prd.md is missing:

    ai26/epics/{EPIC}/prd.md not found.
    Run /ai26-write-prd {EPIC} first to produce the PRD before architectural analysis.

---

## Step 2 — Silent analysis

Before opening the conversation, analyse the PRD against the loaded context.
Do not show this analysis to the architect — use it to prepare the conversation.

Detect:
- Which existing aggregates and bounded contexts are referenced or affected
- Whether new domain concepts are introduced (not in DOMAIN.md)
- Whether database schema changes are likely (new entities, new relationships)
- Which areas in DEBT.md are touched by the epic use cases
- Whether the epic introduces inter-component communication not covered by DECISIONS.md
- External service dependencies mentioned or implied

---

## Step 3 — Open the conversation

Greet the architect with a brief summary of what you found:

    I've read the PRD for {EPIC-ID}: {epic title}.

    Before we start, here is what I noticed:

    Domain: {affected aggregates or "no existing concepts affected — new domain area"}
    Debt:   {RISK:alto areas touched, or "no debt areas touched"}
    Schema: {likely migration needed / no schema changes expected}
    ADRs:   {any existing ADRs that are relevant, or "none"}

    Let's go through the technical implications. {first question based on interaction style}

Use the configured interaction style for the conversation that follows.

**If a DEBT.md area with RISK: alto is touched, surface it immediately and require acknowledgement:**

    ⚠ This epic touches {area}, which is marked RISK: alto in DEBT.md.
    Reason: {reason from DEBT.md}

    Do you want to address this debt as part of the epic, or proceed with the risk acknowledged?

Do not continue until the architect responds.

---

## Step 4 — Cover each area

Work through these areas in conversation. Do not use a rigid Q&A format —
let the conversation flow, covering each area naturally:

### Affected domain concepts
For each use case in the PRD:
- Which existing aggregates are modified?
- Are new aggregates or bounded contexts introduced?
- Are existing lifecycle states extended?

### Database implications
- New tables needed?
- New columns or indexes on existing tables?
- Migration approach (additive only? data transformation needed?)

### Inter-component communication
- Does the epic introduce new synchronous calls between services?
- New async events or topics?
- If not covered by DECISIONS.md, open a decision conversation

### Epic-level architectural decisions
When an architectural decision is needed before decomposition can be meaningful
(e.g. "is Inbox a new aggregate or a projection?"), open the decision conversation:

    This requires a decision before we can decompose into tickets sensibly.
    {question using configured interaction style}

When the architect commits to a direction:

    That decision is worth capturing. Should I document it as an ADR?

Write the ADR immediately on confirmation. Commit it:
```
git add docs/adr/{date}-{title}.md
git commit -m "{EPIC-ID} adr: {title}"
git push
```

### External dependencies
- Services the epic depends on but does not own
- Confirm availability and contract status

---

## Step 5 — Write artefact

When the conversation is complete, propose writing:

    I have enough to write the architecture context. Shall I?

Write `ai26/epics/{EPIC}/architecture.md`:

```markdown
# Epic Architecture — {Epic title}

Epic: {EPIC-ID}
Date: {YYYY-MM-DD}
Author: {architect name or "unknown"}

---

## Affected domain concepts

| Concept | Status | Notes |
|---|---|---|
| {name} | new / modified / existing | {notes} |

---

## Database implications

{description of schema changes needed, or "No schema changes expected."}

---

## Debt areas touched

| Area | Risk | Decision |
|---|---|---|
| {area} | {risk level} | acknowledged / will be addressed |

---

## Epic-level decisions

| Decision | ADR |
|---|---|
| {decision} | {adr filename} |

---

## External dependencies

| Dependency | Type | Status |
|---|---|---|
| {name} | sync / async | confirmed / TBD |

---

## Notes for decomposition

{Anything the architect wants PM to know before ticket decomposition.
Rough effort signals, sequencing constraints, risks.}
```

Notify after writing:

    ✓ ai26/epics/{EPIC}/architecture.md written.
    You can review it now or continue. Say "show it" or "continue".

Wait for the architect's response.

---

## Step 6 — Commit

```
git add ai26/epics/{EPIC}/architecture.md
git commit -m "{EPIC-ID} architecture: epic technical context complete"
git push
```

Show: `✓ committed and pushed`

---

## Step 7 — Close

    Epic architecture complete for {EPIC-ID}.

    Next step: /ai26-decompose-epic {EPIC-ID}
    (PM + Architect decompose the epic into vertical tickets in Jira.)
