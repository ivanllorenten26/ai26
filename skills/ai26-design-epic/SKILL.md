---
name: ai26-design-epic
description: SDLC3 utility. Produces the full design artefact set for every ticket in an epic's plan.md in a single pass — domain model, use case flows, error catalog, API contracts, events, Gherkin scenarios, and ops checklist. By default runs in semi-automatic mode, inferring design decisions from the epic's PRD and architecture.md and only interrupting for genuinely ambiguous decisions. Use after ai26-decompose-epic when you want to complete the design phase for the entire epic before starting implementation. Accepts flags: --interactive (conversational mode, ticket by ticket), --tickets (comma-separated list to design only a subset).
argument-hint: "[EPIC-ID] [--interactive] [--tickets TBD-1,TBD-3]"
---

# ai26-design-epic

Produces the full design artefact set for every ticket in an epic in a single pass.
Reads the epic's `plan.md`, `prd.md`, and `architecture.md`, then runs the
`ai26-design-user-story` flow for each ticket — inferring design decisions from the
epic context and only interrupting when a decision is genuinely ambiguous.

---

## Flags

| Flag | Default | Behaviour |
|---|---|---|
| `--interactive` | off | Conversational mode: asks the same design questions as `ai26-design-user-story` for every ticket. More control, more work. |
| `--tickets TBD-1,TBD-3` | all | Design only the listed tickets (by plan.md ID). |

Default mode is **semi-automatic**: the skill infers answers from PRD use cases, architecture decisions, and existing ADRs. It only pauses for decisions that cannot be resolved from context.

---

## Step 1 — Load epic context

Read in this order:
1. `ai26/epics/{EPIC}/plan.md` — required. Stop if missing: "Run /ai26-decompose-epic first."
2. `ai26/epics/{EPIC}/prd.md` — required. Stop if missing: "Run /ai26-write-prd first."
3. `ai26/epics/{EPIC}/architecture.md` — required. Stop if missing: "Run /ai26-design-epic-architecture first."
4. `ai26/config.yaml`
5. `ai26/context/DOMAIN.md`
6. `ai26/context/ARCHITECTURE.md`
7. `ai26/context/DECISIONS.md` (if exists)
8. `ai26/context/DEBT.md` (if exists)
9. `docs/adr/` — titles only

Parse `plan.md` to get the ordered ticket list and their dependencies. If `--tickets` was provided, filter to only the listed IDs. Warn if a filtered ticket has unresolved dependencies not in the filtered set.

**Ticket ID resolution:** If ticket IDs in `plan.md` are real Jira IDs (e.g., `AS-1234`), read ACs and description from Jira via MCP to supplement the PRD. If IDs are placeholders (e.g., `TBD-1`), derive all context from `prd.md` and `architecture.md` — no Jira call needed.

Show the plan before starting:

    Epic: {EPIC-ID} — {epic title}
    Mode: semi-automatic | interactive
    Tickets to design: {N}

    {ID} — {title} [{risk}] {depends-on or ""}
    {ID} — {title} [{risk}] ...

    Existing artefacts:
    {ID}: ✓ domain-model.yaml, ✓ use-case-flows.yaml, ✗ scenarios/ (incomplete)
    {ID}: ✗ none

    {N} tickets need full design, {N} need completion.
    Proceed?

Wait for confirmation before starting.

---

## Step 2 — Design each ticket

Process tickets in dependency order (tickets with no dependencies first, then those
whose dependencies are complete). Tickets that can be designed in parallel are noted
but still processed sequentially in this skill.

For each ticket, run the full `ai26-design-user-story` flow adapted to the selected mode.

### Semi-automatic mode (default)

The goal is to produce complete, correct artefacts without interrupting the engineer
for decisions that are already answered by the epic context. Interrupt only when
genuinely uncertain.

**For each artefact area, follow this inference strategy:**

**Domain model**
- Map the ticket's use case to affected aggregates from `architecture.md → Affected domain concepts`.
- Use field names, types, and lifecycle states from `architecture.md` and `prd.md → Domain model changes`.
- Use coding rules from `ai26/config.yaml → coding_rules` (D-01 through D-14).
- If a new aggregate is introduced that has no model in `architecture.md`, interrupt:

      Ticket {ID}: the domain model for {concept} is not defined in architecture.md.
      What fields and lifecycle states should it have?

**Use case flows**
- Derive directly from the PRD use case (happy path + error paths) for this ticket.
- Map each error path to a domain error using existing patterns in `ai26/context/DECISIONS.md`.
- If an error path has no obvious mapping, interrupt.

**Error catalog**
- Derive from use case flow error paths.
- Use existing error naming conventions from `docs/adr/` and `ai26/context/DECISIONS.md`.
- No interruption needed for this artefact — fully derivable.

**API contracts**
- Only for tickets with HTTP surface (controller in scope).
- Derive endpoint path, method, request/response shape from PRD use case and existing API patterns in `ai26/context/INTEGRATIONS.md`.
- If the HTTP contract cannot be inferred (new resource, ambiguous path), interrupt.

**Events**
- Derive from `architecture.md → New events on ConversationEvent sealed class` and PRD use case side effects.
- No interruption needed if the event is listed in `architecture.md`.

**Gherkin scenarios**
- Generate one scenario per AC from the plan.md ticket entry.
- Add at least one error path scenario per error in the use case flow.
- Use `# Scenario:` docstring convention from coding rules T-04.
- No interruption needed.

**Ops checklist**
- Derive from: Flyway migrations needed (from `architecture.md → Database implications`), new external dependencies (from `architecture.md → External dependencies`), new Kafka topics (from events artefact).
- Flag items that require infra provisioning as `TODO: requires infra`.
- No interruption needed.

**ADR detection**
- If a design decision arises that is not already captured in `docs/adr/` or `ai26/context/DECISIONS.md`, and it is significant enough to be worth capturing, interrupt:

      Decision encountered in ticket {ID}: {description of decision}.
      Options: {A} vs {B}.
      My recommendation: {option} — {reason}.
      Should I document this as an ADR, or proceed with my recommendation?

### Interactive mode (--interactive)

Run the full `ai26-design-user-story` conversational flow for each ticket, one at a time.
After completing each ticket, confirm before moving to the next:

    ✓ Design complete for {ID}.
    Ready for {next-ID} — {title}?

---

## Step 3 — Write artefacts

Write to `ai26/features/{TICKET-ID}/` following the schemas in
`docs/ai26-sdlc/reference/artefacts.md`.

Artefact filenames:
- `domain-model.yaml`
- `use-case-flows.yaml`
- `error-catalog.yaml`
- `api-contracts.yaml` (only if HTTP surface)
- `events.yaml` (only if events involved)
- `glossary.yaml`
- `scenarios/` (one `.feature` file per use case)
- `ops-checklist.yaml`

Commit after each ticket (not after each artefact — one commit per ticket):

```
git add ai26/features/{TICKET-ID}/
git commit -m "{TICKET-ID} design: full artefact set"
git push
```

Show progress after each ticket:

    ✓ {TICKET-ID} — {title}
      domain-model.yaml, use-case-flows.yaml, error-catalog.yaml,
      api-contracts.yaml, events.yaml, scenarios/ (N scenarios), ops-checklist.yaml
      ADRs: {list or "none"}
      ──────────────────────────────
      {N-remaining} tickets remaining.

---

## Step 4 — Cross-epic completeness check

After all tickets are designed, run validation across the full set:

1. Every UC in `prd.md` is covered by at least one ticket's artefacts.
2. Every domain concept in `architecture.md → Affected domain concepts` appears in at least one `domain-model.yaml`.
3. No two tickets define conflicting models for the same aggregate (e.g., different field names for the same entity).
4. Every open question in `prd.md` that affects a designed ticket is either resolved in the artefacts or explicitly flagged in the ops checklist.

Report violations:

    Cross-epic validation:
    ✓ All PRD use cases covered
    ✗ Conflict: Conversation.sessionId typed as UUID in TBD-1 but as String in TBD-3
    ✗ Open question #6 (NFRs) affects TBD-5 — not resolved

Require the engineer to resolve conflicts before closing. Flag unresolved open questions as `RISK` items in the affected ops checklists.

---

## Step 5 — Update plan.md

Update `ai26/epics/{EPIC}/plan.md` to mark designed tickets:

```
| TBD-1 | Add SessionId to Conversation and Message | MEDIO | designed | {branch} |
```

```
git add ai26/epics/{EPIC}/plan.md
git commit -m "{EPIC-ID} design: epic design phase complete ({N} tickets)"
git push
```

---

## Step 6 — Close

    Epic design complete for {EPIC-ID}.

    Tickets designed: {N}
    Artefacts written: {total count}
    ADRs written: {list or "none"}
    Conflicts resolved: {N}
    Open risks flagged: {N}

    Next step: pick a ticket and run /ai26-implement-user-story {TICKET-ID}
    Recommended starting point: {lowest-dependency ticket with no blockers}
