---
name: ai26-decompose-epic
description: SDLC3 Phase 1c. PM + Architect + LLM decompose an approved epic into vertical tickets in Jira. Each ticket is a unit of user-observable value that crosses all technical layers. Use after ai26-design-epic-architecture.
argument-hint: [EPIC-ID] — Jira epic ID
---

# ai26-decompose-epic

Decomposes an approved epic into vertical tickets in Jira.
A vertical ticket delivers user-observable value and crosses all technical layers.
This is not task decomposition by layer — it is decomposition by value slice.

---

## Step 1 — Load context

Read in this order:
1. `ai26/epics/{EPIC}/prd.md` — required. Stop if missing: "Run /ai26-write-prd first."
2. `ai26/epics/{EPIC}/architecture.md` — required. Stop if missing: "Run /ai26-design-epic-architecture first."
3. `ai26/config.yaml`
4. `ai26/context/DEBT.md` (if exists)

Check Jira via MCP for existing child tickets under the epic. If tickets already exist:

    {N} tickets already exist under {EPIC-ID}:
    - {TICKET-ID}: {title} ({status})
    - ...

    Do you want to:
    A. Review and refine the existing decomposition
    B. Add new tickets to the existing ones
    C. Start fresh (existing tickets will not be deleted — Jira tickets must be closed manually)

---

## Step 2 — Propose initial decomposition

Analyse the PRD use cases and architecture context. Propose an initial decomposition
before the conversation starts — this gives PM and architect something concrete to react to.

Rules for decomposition:
- Each ticket delivers **user-observable value** independently
- Each ticket crosses all technical layers (domain, application, infrastructure, API, tests)
- A ticket is NOT a single layer — flag and reject horizontal decompositions
- Tickets should be independently deployable when merged
- Respect dependencies declared in the architecture context

Show the proposal:

    Based on the PRD and architecture context, I suggest {N} tickets:

    1. {title}
       Value: {what changes for a user when this is merged}
       ACs: {from PRD use cases}
       Technical notes: {from architecture.md}
       Risk: {BAJO/MEDIO/ALTO} — {reason, reference DEBT.md if applicable}
       Depends on: {ticket N, or "nothing"}

    2. ...

    Does this decomposition make sense?
    You can merge, split, reorder, or add tickets before I create them in Jira.

---

## Step 3 — Iterate

PM and architect refine the decomposition. The LLM:

- Flags tickets that appear to be horizontal (single-layer work):

      "Implement {Aggregate} domain model" delivers no user-observable value on its own.
      Consider grouping it with the use case and API that first uses it.

- Flags tickets that appear too large (multiple independent value slices):

      This ticket seems to contain two independent deliverables: {X} and {Y}.
      These could be split — {X} could ship without {Y}.
      Do you want to split them?

- Flags missing dependencies:

      Ticket 3 depends on a domain concept introduced in ticket 1.
      I'll add that dependency.

- Flags open PRD questions that affect scope:

      The PRD has an open question: "{question}" (section {N}).
      This affects ticket {N} — the answer changes whether it is one ticket or two.
      This must be resolved before I create the tickets.

Do not create Jira tickets while there are unresolved open questions in the PRD that
affect ticket scope.

---

## Step 4 — Confirm and create

Once the decomposition is confirmed:

    Ready to create {N} tickets in Jira under {EPIC-ID}:

    {list of tickets with title, ACs, risk, dependencies}

    Confirm?

Create each ticket in Jira via MCP with:
- Title
- Description (from PRD use case, in business language)
- Acceptance criteria (from PRD, one per line)
- Technical notes (from architecture.md, clearly labelled as technical context)
- Epic link
- Risk label
- Dependency links ("blocks" / "is blocked by")

Show progress as tickets are created:

    ✓ Created TICKET-124: {title}
    ✓ Created TICKET-125: {title}
    ...

---

## Step 5 — Update epic plan

Write or update `ai26/epics/{EPIC}/plan.md`:

```markdown
# Epic Plan — {EPIC-ID}

Epic: {EPIC-ID}
Title: {epic title}
Status: in_progress
Created: {date}
Last updated: {date}

## Stories

| ID | Title | Status | Branch |
|---|---|---|---|
| {TICKET-ID} | {title} | pending | — |
| ... | ... | ... | ... |
```

---

## Step 6 — Commit

```
git add ai26/epics/{EPIC}/plan.md
git commit -m "{EPIC-ID} decompose: {N} tickets created in Jira"
git push
```

Show: `✓ committed and pushed`

---

## Step 7 — Close

    Decomposition complete for {EPIC-ID}.
    {N} tickets created in Jira.

    Next step: pick a ticket and run /ai26-start-sdlc {TICKET-ID} to begin design.
