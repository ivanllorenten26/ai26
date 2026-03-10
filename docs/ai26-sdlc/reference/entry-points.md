# Entry Points

> How to start working with AI26 regardless of where you are in the process.

---

## The single entry point

All flows start with one skill:

    /ai26-start-sdlc [optional: JIRA-ID]

The LLM asks where you are and routes you to the right place. You never need to know
which underlying skill to invoke — `ai26-start-sdlc` figures that out.

    LLM: What do you want to work on?

         A. New epic       — I have a business initiative, help me decompose it into tickets
         B. Existing epic  — I have an epic in Jira, continue from there
         C. New ticket     — I have an epic, help me define and design a new ticket
         D. Existing ticket — I have a ticket, help me design and implement it

If you provide a Jira ID upfront, the LLM reads it and skips the question:

    /ai26-start-sdlc EPIC-42     → detects it is an epic, asks A or B
    /ai26-start-sdlc TICKET-123  → detects it is a ticket, goes to D

---

## Option A — New epic

You have a business initiative. No Jira epic exists yet.

    /ai26-start-sdlc
    > A

    LLM: Do you have an existing document (PRD, brief, email) or do you want
         to start from a description?

Flows into Phase 1a (PRD) → Phase 1b (Epic Architecture) → Phase 1c (Decomposition).
An epic is created in Jira at the start of Phase 1c.

See `level1-flow.md` for the full detail of each phase.

---

## Option B — Existing epic

You have an epic in Jira. Work may have already started.

    /ai26-start-sdlc EPIC-42

The LLM reads the epic from Jira (via MCP) and evaluates what exists:

```
LLM reads:
  - Epic description and ACs from Jira
  - Child tickets already created
  - ai26/epics/EPIC-42/ if it exists (previous AI26 work)
  - ai26/context/ and docs/architecture/

LLM evaluates:
  ✓ PRD exists (ai26/epics/EPIC-42/prd.md)        → skip Phase 1a
  ✗ Architecture context missing               → run Phase 1b
  ✓ Tickets already in Jira                    → show existing decomposition, offer to refine
```

The LLM shows what it found and proposes where to continue:

    LLM: I found a PRD for EPIC-42 and 3 tickets already in Jira.
         No architecture context exists yet.

         I suggest:
         1. Run epic architecture analysis (Phase 1b)
         2. Review existing tickets against the architecture context
         3. Create missing tickets if needed

         Does that work, or do you want to go straight to a specific ticket?

---

## Option C — New ticket

You have an epic, and you want to create and design a new ticket for it.

    /ai26-start-sdlc
    > C
    > Epic: EPIC-42

The LLM reads the epic context (PRD + architecture if they exist) and opens a
conversation to define the ticket scope. Output: a new ticket created in Jira
with description and ACs, then flows directly into the design phase (Phase 2a).

If the epic has no PRD or architecture context, the LLM proceeds with what it
has — reading the epic from Jira and the existing `ai26/context/` — and notes what
is missing:

    LLM: No PRD or architecture context found for EPIC-42.
         I'll work from the epic description in Jira and the repository context.
         Some information that would normally come from the epic phases may need
         to be clarified during the design conversation.

---

## Option D — Existing ticket

You have a ticket in Jira. This is the most common entry point for engineers.

    /ai26-start-sdlc TICKET-123

### Bootstrap evaluation

Before opening the design conversation, the LLM evaluates what it has:

```
LLM reads:
  1. Ticket from Jira (description, ACs, epic link)
  2. Parent epic context (ai26/epics/{EPIC}/ if exists)
  3. ai26/context/ (DOMAIN, ARCHITECTURE, DECISIONS, DEBT)
  4. docs/architecture/modules/{module}/ (existing domain documentation)
  5. docs/adr/ (existing decisions)
  6. ai26/features/{TICKET}/ (partial work if adoption scenario)

LLM evaluates against required artefacts:
  domain-model.yaml       — can derive from Jira + context? needs conversation?
  use-case-flows.yaml     — ACs in Jira are a start, error paths likely missing
  error-catalog.yaml      — almost always needs conversation
  scenarios/              — can generate from ACs if they are well-written
  api-contracts.yaml      — needs conversation if not in ticket
  ops-checklist.yaml      — can partially derive, needs confirmation
```

The LLM then summarises what it has and what it needs:

    LLM: I've read TICKET-123 and the repository context.

         I have enough to start the design conversation. A few things to note:

         - The ticket has 3 ACs but no error paths defined — we'll work those out together
         - The ticket mentions "inbox" but that concept doesn't exist in the domain yet —
           we'll need to define it
         - TICKET-123's epic has no architecture context — I'll do a lightweight analysis
           as we go and flag anything that looks like a risk

         Ready to start the design conversation?

### Lightweight epic analysis (when no epic architecture exists)

When there is no `ai26/epics/{EPIC}/architecture.md`, the LLM does not skip the analysis —
it performs a lighter version inline, during the design conversation:

- Detects which existing aggregates are touched
- Flags DEBT.md risk areas if the feature touches them
- Surfaces external dependencies as they emerge from the design
- Proposes ADRs when architectural decisions arise

This is less thorough than a dedicated Phase 1b, but ensures the engineer is not
designing blind. If a significant risk is found during this inline analysis, the LLM
recommends pausing and running a proper epic architecture phase before continuing.

### Partial adoption scenario

If `ai26/features/{TICKET}/` already exists with some artefacts (engineer started previously,
or artefacts were generated by another tool), the LLM loads them and shows what is there:

    LLM: I found an existing design workspace for TICKET-123:

         ✓ domain-model.yaml (last modified 2026-03-01)
         ✓ use-case-flows.yaml (last modified 2026-03-01)
         ✗ error-catalog.yaml — missing
         ✗ scenarios/ — missing

         Do you want to:
         A. Continue from where this left off (generate the missing artefacts)
         B. Review the existing artefacts first before continuing
         C. Start fresh (existing artefacts will be overwritten after confirmation)

The LLM never overwrites existing artefacts without explicit confirmation.

---

## The invariant

Regardless of entry point, the design phase does not end until all configured artefacts
exist and pass the cross-reference validation. The path to get there varies — the destination
does not.

```
Any entry point
      ↓
Bootstrap evaluation (what do I have? what do I need?)
      ↓
Fill the gaps (conversation, Jira, context, lightweight analysis)
      ↓
ai26/features/{TICKET}/ complete and valid
      ↓
/ai26-implement-user-story TICKET-123
```

The engineer never needs to track which artefacts are missing — the LLM does that.
The engineer's job is to make decisions. The LLM's job is to make sure all decisions
are captured before implementation starts.
