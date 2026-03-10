# Level 1 Flow — Product Planning

> From business initiative to well-defined tickets ready for engineering.

---

## Overview

```
/ai26-write-prd {EPIC}
  PM + LLM
  Input:  business initiative — document or conversation
  Output: ai26/epics/{EPIC}/prd.md

      ↓  architect reads the PRD

/ai26-design-epic-architecture {EPIC}
  Architect + LLM
  Input:  PRD + ai26/context/ + docs/architecture/
  Output: ai26/epics/{EPIC}/architecture.md
          ADRs if epic-level decisions are made

      ↓  PM + architect together

/ai26-decompose-epic {EPIC}
  PM + Architect + LLM
  Input:  PRD + architecture context + Jira (via MCP)
  Output: vertical tickets created in Jira
```

---

## Phase 1a — PRD

### What it does

Produces a structured, complete PRD from a business initiative. The PM either brings
an existing document or starts from a description. The LLM helps surface gaps, ambiguities,
and edge cases through conversation — not by presenting a checklist upfront.

### Entry points

**From an existing document:**

    /ai26-write-prd EPIC-42
    > I have a document already. [attaches file or pastes content]

The LLM reads the document, loads `ai26/context/DOMAIN.md` and `ai26/context/DECISIONS.md`,
and begins the conversation. It does not dump all detected issues at once — it engages
naturally, asking about one thing at a time, with gaps emerging as the conversation develops.

**From scratch:**

    /ai26-write-prd EPIC-42
    > We want to allow agents to manage customer conversations from a unified inbox.

The LLM uses the configured interaction style (socratic by default) to help the PM
articulate scope, actors, use cases, constraints, and success criteria.

### What the LLM detects and questions

The LLM monitors for these gap types throughout the conversation. It does not surface
them all at once — they emerge as the conversation develops:

| Gap type | Example |
|---|---|
| **Missing error paths** | "You describe opening a conversation — what happens if the customer already has one open?" |
| **Ambiguous terms** | "You use 'notify the agent' — is that in-app, email, or both?" |
| **Conflict with existing domain** | "We already have a concept called 'Case' in the domain — is this the same thing or different?" |
| **Unstated assumptions** | "You assume the agent is always assigned — what happens if the conversation has no agent yet?" |
| **Missing success criteria** | "How do we know this feature is working correctly in production?" |
| **Scope boundary unclear** | "Does this include historical conversations or only new ones from this feature forward?" |
| **Missing actors** | "You mention the customer receives a notification — who sends it? Which system?" |
| **Non-functional requirements absent** | "Any constraints on response time or volume? How many conversations do agents handle simultaneously?" |

The LLM does not invent problems — it asks questions that expose gaps the PM may not
have considered. When the PM answers, the LLM incorporates the answer and moves on.

### When the PRD is complete

The LLM proposes closing the PRD when:
1. All sections of the template are filled
2. No open questions remain from the conversation
3. Every use case has at least one error path
4. Success criteria are defined

    LLM: I think we have a complete PRD. Here is a summary of what we covered:
         - 3 actors: Agent, Supervisor, Customer
         - 5 use cases with error paths
         - 2 non-functional requirements
         - Success criteria defined

         Shall I write prd.md?

The PM confirms, and the LLM writes `ai26/epics/{EPIC}/prd.md`.
The PM can review it immediately — same pattern as design artefacts.

### PRD format

`ai26/epics/{EPIC}/prd.md` — Markdown with fixed sections:

```markdown
# PRD — [Epic title]

Epic: [EPIC-ID]
Date: [YYYY-MM-DD]
Status: draft | review | approved
Author: [PM name]

---

## Business context

[Why this epic exists. What problem it solves. What changes for users if we build it.]

---

## Actors

| Actor | Role |
|---|---|
| Agent | ... |
| Customer | ... |

---

## Use cases

### UC-1 — [Title]
**Actor:** [who initiates]
**Goal:** [what they want to achieve]
**Preconditions:** [what must be true before this can happen]

**Happy path:**
1. ...
2. ...

**Error paths:**
- [condition] → [what happens]
- [condition] → [what happens]

---

## Out of scope

[Explicitly what is NOT included in this epic, to avoid scope creep.]

---

## Non-functional requirements

- [Performance, volume, availability constraints]

---

## Success criteria

[How we know this is working correctly in production. Observable, measurable.]

---

## Open questions

[Questions that remain unresolved at PRD approval time. Each must be resolved
before the engineering phase starts.]

| Question | Owner | Due |
|---|---|---|
| ... | ... | ... |
```

---

## Phase 1b — Epic Architecture

### What it does

The architect reads the approved PRD and opens a technical conversation with the LLM.
The output is a technical context document that informs ticket decomposition — not a
detailed design, but enough to make estimation honest.

    /ai26-design-epic-architecture EPIC-42

### What the LLM loads

1. `ai26/epics/{EPIC}/prd.md` — the approved PRD
2. `ai26/context/DOMAIN.md` — existing domain concepts
3. `ai26/context/ARCHITECTURE.md` — architectural constraints
4. `ai26/context/DECISIONS.md` — global decisions (applied as constraints, not debated)
5. `ai26/context/DEBT.md` — known risk areas
6. `docs/architecture/modules/` — existing module documentation
7. `docs/adr/` — existing ADRs

### What the LLM surfaces

The LLM analyses the PRD against the loaded context and opens a conversation with
the architect. It surfaces:

**Affected domain concepts:**
Which existing aggregates, entities, and bounded contexts are touched.
If the PRD introduces a new concept, the LLM flags it for domain modelling in Phase 2a.

**Database implications:**
Whether new tables, columns, indexes, or migrations are needed.
It does not design the schema — it flags that one will be needed.

**Debt areas touched:**
If the epic touches areas marked `RISK: alto` in `DEBT.md`, the LLM surfaces this
immediately. The architect must acknowledge the risk before the conversation continues.

    LLM: This epic touches the conversation routing logic, which is marked
         RISK: alto in DEBT.md (reason: high coupling, no test coverage).
         Any changes here carry a higher implementation risk than estimated.
         Do you want to address the debt as part of this epic, or proceed with the risk acknowledged?

**Epic-level decisions:**
If the epic requires an architectural decision before tickets can be decomposed
(e.g. sync vs async communication with a new external service), the LLM opens
the decision conversation using the configured interaction style.
Decisions are documented as ADRs before the conversation moves on.

**External dependencies:**
Services, teams, or infrastructure that the epic depends on but does not own.
These become explicit risks in the decomposition phase.

### Output format

`ai26/epics/{EPIC}/architecture.md` — Markdown with fixed sections:

```markdown
# Epic Architecture — [Epic title]

Epic: [EPIC-ID]
Date: [YYYY-MM-DD]
Author: [Architect name]

---

## Affected domain concepts

| Concept | Status | Notes |
|---|---|---|
| Conversation | modified | new states: ESCALATED |
| Inbox | new | not yet in domain model |

---

## Database implications

- New table: inboxes
- New column: conversations.escalated_at
- Migration risk: low — additive only

---

## Debt areas touched

| Area | Risk | Decision |
|---|---|---|
| Conversation routing | RISK: alto | acknowledged, not addressed in this epic |

---

## Epic-level decisions

| Decision | ADR |
|---|---|
| Inbox as separate aggregate vs projection | ADR-2026-03-07-inbox-model.md |

---

## External dependencies

| Dependency | Type | Status |
|---|---|---|
| Notification service | async event consumer | confirmed available |
| Customer service API | sync HTTP | contract TBD |

---

## Implementation notes for decomposition

[Anything the architect wants PM to know before decomposing into tickets.
Rough effort signals, sequencing constraints, risks.]
```

---

## Phase 1c — Decomposition

### What it does

PM + architect + LLM decompose the epic into vertical tickets.
Each ticket is a slice of user-observable value that crosses all technical layers.

    /ai26-decompose-epic EPIC-42

### The vertical ticket principle

A ticket is **not** a unit of technical work. It is a unit of delivered value.

The LLM will flag decompositions that violate this:

    LLM: "Implement Conversation aggregate" is a horizontal ticket — it delivers
         no user-observable value on its own. Consider grouping it with the
         use case and API that first uses it into a single vertical slice.

Each ticket must be independently deployable — when it is merged, something
observable changes for a user.

### The conversation

The LLM proposes an initial decomposition based on the PRD use cases and the
architecture context. PM and architect iterate:

    LLM: Based on the PRD and architecture context, I suggest 4 tickets:

         1. Agent can open a conversation with a customer
            ACs: [from PRD UC-1]
            Technical notes: new Inbox aggregate, migration needed
            Risk: MEDIO — touches debt area (acknowledged)
            Depends on: nothing

         2. Agent can close a conversation
            ACs: [from PRD UC-2]
            Technical notes: additive to existing Conversation aggregate
            Risk: BAJO
            Depends on: ticket 1

         3. Agent can escalate a conversation to a supervisor
            ACs: [from PRD UC-3]
            Technical notes: new ESCALATED state, notification event
            Risk: MEDIO — new external dependency (notification service)
            Depends on: ticket 1

         4. Supervisor can view all escalated conversations
            ACs: [from PRD UC-4]
            Technical notes: read-only query, no state changes
            Risk: BAJO
            Depends on: ticket 3

         Does this decomposition make sense? Any tickets to merge, split, or reorder?

The PM and architect can:
- Merge tickets that are too small to be worth separate delivery
- Split tickets that contain multiple independent value slices
- Reorder based on business priority
- Add acceptance criteria from the PRD
- Flag dependencies the LLM missed

### Creating tickets in Jira

Once the decomposition is confirmed, the LLM creates the tickets in Jira via MCP:

    LLM: Ready to create 4 tickets in Jira under epic EPIC-42. Confirm?

Each ticket is created with:
- Title
- Description (from PRD use case)
- Acceptance criteria
- Technical notes (from architecture context)
- Risk level
- Epic link
- Dependencies (linked as "blocks" / "is blocked by")

The PM or architect can review the created tickets in Jira before engineering starts.

### When decomposition is blocked

If the PRD has open questions that affect decomposition scope, the LLM stops:

    LLM: The PRD has an open question about historical conversations (section 7).
         The answer changes whether ticket 4 is one ticket or three.
         This must be resolved before I can create the tickets.

Open questions in the PRD are blocking — they must be resolved before Jira tickets
are created.
