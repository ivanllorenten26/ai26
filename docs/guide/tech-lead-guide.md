# Tech Lead Guide

How to onboard a team onto AI26, manage the context layer, handle ADRs, use the compound feedback loop, and review migration plans. Audience: tech leads and architects.

---

## Your role in AI26

The tech lead is the custodian of the context layer. Your job is to ensure that `ai26/context/` accurately reflects the team's architecture, decisions, and known debt — at all times. The quality of every AI-generated output in every session is determined by the quality of what is in these files.

You are also the arbitrator of architectural decisions. When a design conversation surfaces an ADR candidate, you are the one who decides, and your reasoning goes into the ADR.

---

## Onboarding a new team

### Install skills

```
/marketplace install ai26
```

This installs all three skill layers: SDLC orchestration (`ai26-*`), PM and design skills, and dev/test scaffolding skills (`dev-*`, `test-*`).

### Run the onboarding skill

```
/ai26-onboard-team
```

This skill guides you through creating the foundational files your team needs. It will:

1. Create `ai26/config.yaml` — stack configuration, module definitions, conventions
2. Create `ai26/context/DOMAIN.md` — bounded contexts and ubiquitous language
3. Create `ai26/context/ARCHITECTURE.md` — layer rules and structural constraints
4. Create `ai26/context/DECISIONS.md` — settled decisions the AI applies as constraints
5. Create `ai26/context/DEBT.md` — known fragile areas with risk levels
6. Create `ai26/context/INTEGRATIONS.md` — inbound/outbound integrations, Kafka topics
7. Verify the setup with `/ai26-start-sdlc --check`

**Start with what your team knows implicitly and make it explicit.** A minimal but honest context is better than a detailed but incomplete one. The system improves as the context improves.

### Verify setup

```
/ai26-start-sdlc --check
```

Expected output:

```
AI26 setup check
─────────────────────────────────────
✓ ai26/config.yaml — valid
✓ ai26/context/DOMAIN.md — found
✓ ai26/context/ARCHITECTURE.md — found
✓ ai26/context/DECISIONS.md — found
✓ ai26/context/DEBT.md — found
✓ Jira MCP — connected (project: SXG)
✓ Git remote — origin configured

Setup complete.
```

---

## Managing the context layer

The five context files are the team's institutional memory. They degrade if not maintained.

### `ai26/context/DOMAIN.md`

Contains the bounded contexts, aggregate registry, and ubiquitous language. Update this when:

- A new aggregate is introduced (add it to the aggregate table for its bounded context)
- A new term enters the domain vocabulary
- An existing term's definition changes
- An aggregate is deprecated

**Rule:** if an aggregate is not listed in `DOMAIN.md`, the AI will assume it does not exist and may create a duplicate. Keep the aggregate table complete.

### `ai26/context/ARCHITECTURE.md`

Contains non-negotiable structural constraints: layer rules, dependency directions, and named prohibitions. Update this when:

- A new structural pattern is established
- A constraint is relaxed or tightened
- A new layer or module is introduced

Do not put the reasoning here — that belongs in `DECISIONS.md`. Keep `ARCHITECTURE.md` as a list of constraints that apply unconditionally.

### `ai26/context/DECISIONS.md`

Contains global design decisions: why the system is shaped the way it is. Update this when:

- A significant architectural choice is made that applies across multiple features
- A bounded context boundary is established or changed
- A cross-cutting data model decision is made

Every entry needs a `Why` field. Without it, the constraint has no weight — the AI may debate it rather than apply it.

### `ai26/context/DEBT.md`

Contains known technical debt with risk levels: `alto`, `medio`, `bajo`. Update this when:

- A fragile area is identified
- A risk level changes (e.g., after a partial fix)
- Debt is resolved (remove the entry or mark it resolved)

`alto` entries surface immediately during design conversations and may pause the conversation. Keep this list honest — under-reporting debt means engineers walk into fragile areas without warning.

### `ai26/context/INTEGRATIONS.md`

Contains the full integration surface: inbound endpoints, outbound HTTP calls, Kafka topics emitted and consumed, AI/ML services, downstream dependents. Update this when:

- A new integration is introduced
- An endpoint signature changes
- A Kafka topic is added, renamed, or deprecated
- A new downstream service starts depending on the service

---

## Handling ADRs

ADRs are written during design conversations. When a design conversation for a ticket surfaces a significant architectural decision, the AI will propose an ADR. Your job is to decide, document the reasoning, and approve.

ADR files go into `docs/adr/` with the format:

```
docs/adr/YYYY-MM-DD-{slug}.md
```

Example:

```
docs/adr/2026-03-12-notification-delivery-model.md
```

Every ADR has a status (`proposed`, `accepted`, `superseded`, `deprecated`). Accepted ADRs are referenced by `ai26/context/DECISIONS.md` as summaries. The full reasoning lives in the ADR.

**When to write an ADR vs. a DECISIONS.md entry:**

- ADR: a specific decision made at a point in time, with options considered, trade-offs, and outcome. Feature-specific or time-bounded.
- DECISIONS.md entry: a global constraint that applies to all future features. Cross-cutting, stable, team-wide.

An ADR for "we chose Kafka over SQS for domain events" is an ADR. A DECISIONS.md entry for "domain events are published via Kafka, not by direct service calls" is a DECISIONS.md entry. These are complementary.

---

## The compound feedback loop

Your primary quality signal is whether the compound loop is actually running. Signs it is running correctly:

- Promotion (`ai26-promote-user-story`) is being run on every completed ticket
- `ai26/context/` files are being updated after each feature
- Validation blocking rates decrease over successive tickets (fewer surprises)
- Design conversations for ticket 20 require less clarification than for ticket 5

Signs the loop is breaking:

- Engineers are using `ai26-backfill-user-story` routinely — design was skipped
- `ai26-promote-user-story` is being skipped — context is not being updated
- Context drift is accumulating — `ai26-sync-context` warnings are being ignored
- Engineers are manually rewriting AI-generated code rather than updating context

### Capturing wrong AI output — compound feedback

When an agent produces wrong output, the correct response is to capture the observation
and fix the underlying context — not to rewrite the result and move on.

```
/ai26-compound {TICKET-ID}
```

This records what went wrong and what type of fix is needed (`context`, `artefact`,
`skill`, or `rule`) into `ai26/features/{TICKET}/COMPOUND.md`. After applying the fix
and re-running the affected step:

```
/ai26-compound-resolve {TICKET-ID}
```

This graduates the resolved observation to `ai26/context/LEARNINGS.md` — the permanent
institutional memory. Future agents read it at startup to avoid repeating the same mistake.
`ai26-promote-user-story` is blocked if pending observations remain in `COMPOUND.md`.

**Signs the feedback loop is working:**

- `ai26/context/LEARNINGS.md` is growing over time
- Engineers run `/ai26-compound` during review rather than silently fixing code
- Promotion is clean — no `COMPOUND.md` blocking warnings

See `docs/ai26-sdlc/reference/compound-feedback.md` for the full workflow.

### Running `ai26-sync-context`

When you suspect context has drifted from code:

```
/ai26-sync-context
```

The skill scans the codebase and compares it to `ai26/context/`. It reports discrepancies:

```
Context drift detected:

ai26/context/DOMAIN.md
  Conversation aggregate — status field lists: OPEN, CLOSED, ARCHIVED
  Codebase shows:          OPEN, CLOSED, ARCHIVED, ESCALATED
  Proposed fix: add ESCALATED to Conversation states in DOMAIN.md

ai26/context/INTEGRATIONS.md
  Missing: GET /api/v1/conversations/{id}/analysis
  (added in SXG-456, never registered)
  Proposed fix: add endpoint to Inbound HTTP section

Apply all proposed fixes? [yes / review each / no]
```

Review each proposed fix. The AI corrects the context to match the code — not the other way around. If the code is wrong and the context is right, reject the proposed fix and fix the code instead.

---

## Onboarding a new engineer

When a new engineer joins:

1. Point them to `ai26/context/` — the success criterion is that they can read these five files and understand the architecture, constraints, and things not to do, without reading the code first.
2. Walk them through `/ai26-start-sdlc --check` to verify their environment.
3. Assign a Fidelity 1 or Fidelity 2 ticket for their first AI26 flow. Sit in on the first design conversation.
4. Review their first PR with attention to: were the artefacts approved before implementation started? Did promotion run?

---

## Reviewing migration plans

When the team is migrating a legacy module to AI26 conventions, the migration flow is:

```
/ai26-assess-module {MODULE}          ← assess current state
/ai26-write-migration-prd {MODULE}    ← define migration scope
/ai26-decompose-migration {MODULE}    ← break into implementable tickets
```

### Reviewing the assessment (`ai26-assess-module`)

The assessment produces a report covering: architectural violations, missing tests, context file gaps, and a risk-classified debt inventory. Review this report with the PM to align on what is being fixed and what is being deferred.

### Reviewing the migration PRD (`ai26-write-migration-prd`)

Like a product PRD but for technical goals. Ensure:
- The migration scope is realistic for the team's capacity
- High-risk debt (`alto`) is sequenced early
- The PRD explicitly states what will not be migrated in this phase

### Reviewing the decomposition (`ai26-decompose-migration`)

The decomposition produces migration tickets. For each ticket, verify:
- The ticket scope does not require touching multiple DEBT.md `alto` areas simultaneously
- Dependencies between tickets are correctly sequenced (schema migrations before code changes, etc.)
- The ticket complexity is appropriate for a single PR

---

## Context quality as a team discipline

Treat `ai26/context/` maintenance with the same discipline as keeping tests green.

A PR that introduces a new aggregate without updating `DOMAIN.md` is incomplete. A PR that establishes a new global design pattern without updating `DECISIONS.md` is incomplete. Make this expectation explicit in your team's PR template and code review culture.

The tech lead is the last line of defence before context drift accumulates. The promotion step surfaces proposed context updates for confirmation — that is your moment to validate that the updates accurately reflect what was decided.

---

## Reference

- [Onboarding reference](../ai26-sdlc/reference/onboarding.md) — full setup steps and config schema
- [Context Files reference](../ai26-sdlc/reference/context-files.md) — format guide for all five context files
- [Flows reference](../ai26-sdlc/reference/flows.md) — Flow A/B/C in detail
- [Engineer Guide](./engineer-guide.md) — what your engineers are doing step by step
- [Skill Catalog](./skill-catalog.md) — `ai26-onboard-team`, `ai26-sync-context`, `ai26-assess-module` details
- [Glossary](./glossary.md) — definitions for context drift, intention debt, compound loop
