---
name: ai26-decompose-migration
description: Legacy migration Phase 3. Reads the approved Migration PRD and decomposes it into migration tickets — one per aggregate or use case cluster — ordered by dependency and risk. Each ticket includes what legacy files are being replaced, the target architecture, acceptance criteria (contracts must be preserved), and the link to design artefacts. Produces ai26/migrations/{MODULE}/plan.md. Use after ai26-write-migration-prd, before running ai26-start-sdlc on each migration ticket. Invoke as /ai26-decompose-migration {MODULE}.
argument-hint: "[MODULE] — module name from ai26/config.yaml"
---

# ai26-decompose-migration

Phase 3 of the legacy migration flow. Takes the approved PRD and produces a set of
vertical migration tickets, each of which can be executed through the standard
`ai26-start-sdlc` → `ai26-design-ticket` → `ai26-implement-user-story` flow.

---

## Step 1 — Load context

Read:
1. `ai26/migrations/{MODULE}/prd.md` — the approved Phase 2 output
2. `ai26/migrations/{MODULE}/assessment.yaml` — for contract details
3. `ai26/config.yaml` — Jira project key

If `prd.md` does not exist:

    No Migration PRD found for {MODULE}.
    Run /ai26-write-migration-prd {MODULE} first.

---

## Step 2 — Generate migration tickets

For each item in the PRD's **Migration order** table, create a migration ticket definition.

Each ticket must answer:

1. **What legacy code is being replaced?** (file list from assessment)
2. **What is the target architecture?** (aggregate + use cases from PRD)
3. **What contracts must be preserved?** (API/event/DB contracts from assessment — non-negotiable)
4. **What are the acceptance criteria?**
5. **What are the dependencies?** (other migration tickets that must complete first)

Format each ticket as:

    Migration ticket {N}: {TICKET-TITLE}
    ──────────────────────────────────────────────────

    Summary: Migrate {AggregateName} from legacy to Clean Architecture + DDD

    Replaces:
      {LegacyServiceClass}.kt
      {LegacyEntityClass}.kt
      {LegacyRepositoryClass}.kt

    Target:
      Aggregate:   {AggregateName} (D-01, D-02)
      Use cases:   {UseCaseName1}, {UseCaseName2}
      Repository:  {AggregateNameRepository} (JOOQ/JPA)
      Controller:  Preserve existing endpoint — {HTTP_METHOD} {path}

    Contract constraints (must be preserved):
      API:      {HTTP_METHOD} {path} → {status} (same request/response shape)
      Events:   topic "{topic}" payload {PayloadType} fields preserved
      Database: table "{table}" — no destructive schema changes

    Acceptance criteria:
      - [ ] New aggregate passes all D-01..D-14 rules
      - [ ] Use case returns Either<Error, DTO> (A-01, CC-03)
      - [ ] Existing API contract preserved (same HTTP method, path, status codes)
      - [ ] Controller tests pass (T-07)
      - [ ] Integration tests pass against TestContainers PostgreSQL (T-01)
      - [ ] Legacy code still compiles alongside new code (Strangler Fig)
      - [ ] ai26-validate-user-story passes

    Migration pattern: {Strangler Fig | Branch by Abstraction | Expand-Contract}
    Cutover risk: {low | medium | high}
    Depends on: {ticket N, or none}

Show all tickets to the engineer. Ask:

    Does this decomposition look right?
    Anything to merge, split, or reorder?

Wait for confirmation before writing.

---

## Step 3 — Write plan.md

Write `ai26/migrations/{MODULE}/plan.md`:

```markdown
# Migration Plan — {MODULE}

> Generated {DATE} by ai26-decompose-migration
> PRD: ai26/migrations/{MODULE}/prd.md
> Assessment: ai26/migrations/{MODULE}/assessment.yaml

## Status

| # | Title | Jira | Status | Branch | Notes |
|---|-------|------|--------|--------|-------|
| 1 | Migrate {AggregateName} | — | pending | — | |
| 2 | Migrate {AggregateName2} | — | pending | — | depends on #1 |
| ... | | | | | |

## Ticket Definitions

### Ticket 1 — {TITLE}

**Replaces:**
- `{LegacyFile1}.kt`
- `{LegacyFile2}.kt`

**Target architecture:**
- Aggregate: `{AggregateName}`
- Use cases: `{UseCaseName1}`, `{UseCaseName2}`

**Contract constraints:**
- API: `{HTTP_METHOD} {path}` — shape must be preserved
- Database: table `{table_name}` — no destructive changes

**Acceptance criteria:**
- [ ] D-01..D-14 compliant aggregate
- [ ] Either-based error handling (A-01, CC-03)
- [ ] Controller test (T-07)
- [ ] Integration test with TestContainers (T-01)
- [ ] Legacy code still compiles (Strangler Fig)
- [ ] ai26-validate-user-story passes

**Migration pattern:** {Strangler Fig | Branch by Abstraction}
**Risk:** {low | medium | high}
**Depends on:** {ticket number or none}

---

### Ticket 2 — ...

[repeat for each ticket]

## How to run a migration ticket

1. Run `/ai26-start-sdlc {JIRA-ID}` — creates branch, routes to ai26-design-ticket
2. During design: the skill auto-loads assessment.yaml and prd.md as context
3. Artefacts are constrained by the contract definitions above — do not change contracts
4. Run `/ai26-implement-user-story {JIRA-ID}` after design is approved
5. Run `/ai26-validate-user-story {JIRA-ID}` — must pass before cutover
6. Cutover: route traffic from legacy to new (feature flag / proxy)
7. Delete legacy files
8. Run `/ai26-promote-user-story {JIRA-ID}`

## Cutover checklist (per ticket)

- [ ] New code passes all tests
- [ ] Legacy code still works (parallel coexistence verified)
- [ ] Feature flag / routing switch prepared
- [ ] Rollback plan documented
- [ ] Traffic switched
- [ ] Legacy code deleted
- [ ] Ticket promoted
```

---

## Step 4 — Create Jira tickets (optional)

Ask:

    Shall I create these {N} tickets in Jira via MCP?
    They will be created in project {JIRA_PROJECT} and linked to each other.

If yes, create each ticket via Jira MCP:
- Title: `[MIGRATION] {title from plan}`
- Description: ticket definition from Step 2
- Labels: `migration`, `ai26`
- Link: "is blocked by" previous ticket in the dependency chain

Update `plan.md` with the Jira IDs:

```markdown
| 1 | Migrate {AggregateName} | {JIRA-ID} | pending | — | |
```

Commit the updated plan.md.

---

## Step 5 — Commit

```
git add ai26/migrations/{MODULE}/plan.md
git commit -m "chore({MODULE}): add migration decomposition plan ({N} tickets)"
git push
```

---

## Step 6 — Next step

    Migration plan ready for {MODULE}. {N} tickets defined.

    Start the first ticket:
    /ai26-start-sdlc {FIRST-JIRA-ID}

    The design skill will automatically load the assessment and PRD as context
    and enforce backward-compatible contract constraints.
