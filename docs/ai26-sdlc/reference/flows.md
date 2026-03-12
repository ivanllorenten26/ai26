# AI26 SDLC — Flows Guide

> From Artisans to Orchestrators: 80% AI-generated PRs, engineers as compound architects.

---

## 1. The Model: Compound Engineering

Every feature should make the next feature easier to build.

The compound loop:

| Phase | Weight | What happens |
|---|---|---|
| **Plan** | 40% | Design the domain, make decisions, write artefacts |
| **Work** | 10% | Agent implements from artefacts |
| **Assess** | 30% | Validate, review, catch gaps |
| **Compound** | 20% | Feed knowledge back into context files |

**Core principle: fix the context, not the output.**

> When an agent fails, do not manually rewrite the code.
> Debug why the agent failed and update the system prompt so it never makes the same mistake again.

ADRs written during design, DEBT.md entries for fragile areas, and coding rules in `CLAUDE.md` are not documentation overhead — they are the compound interest on your engineering investment. Each one makes the next agent invocation smarter.

---

## 2. Four Flows: When to Use What

```
Is this a full feature / multi-ticket initiative?
  YES → Flow A: Epic
        Example: "Add transcript archival and conversation analysis"
        Start:   /ai26-start-sdlc --prd   or   /ai26-start-sdlc --epic SXG-42

Is this a standalone feature or ticket with domain impact?
  YES → Flow B: Standalone Ticket (fidelity 2)
        Example: "Add a new endpoint to fetch analysis results"
        Start:   /ai26-start-sdlc --ticket SXG-1234

Is this a bug fix with domain impact (new error case, state change)?
  YES → Flow B: Standalone Ticket (fidelity 1)
        Example: "Handle race condition when conversation closes during escalation"
        Start:   /ai26-start-sdlc --fix SXG-999

Is this a typo, dependency bump, config change, obvious bug?
  YES → Flow C: Quick Fix
        Example: "Fix NPE in message serializer", "Bump Spring Boot to 3.4.1"
        Start:   /ai26-start-sdlc --quickfix SXG-888
        Note:    If the agent discovers complexity, it auto-escalates to Flow B

Is this a legacy module that needs to be migrated to AI26 standard?
  YES → Flow D: Migration
        Example: "Migrate the chat module to Clean Architecture"
        Start:   /ai26-start-sdlc --migrate chat-module
```

When in doubt, run `/ai26-start-sdlc` — it will ask or auto-detect.

---

## 3. Flow A: Epic

Three skill invocations replace the former five-skill sequence (`write-prd → design-epic-architecture → decompose-epic → design-epic → implement`).

### Step 1: `/ai26-write-prd {EPIC-ID}`

| | |
|---|---|
| **Input** | Business requirements — from PM, stakeholders, or engineer description |
| **Output** | `ai26/epics/{EPIC}/prd.md` |
| **You do** | Co-author requirements with the AI. Review and approve. |

### Step 2: `/ai26-design-epic {EPIC-ID}`

Five internal phases — one skill invocation:

| Phase | What happens | Output |
|---|---|---|
| 1. Load context | Reads prd.md + ai26/context/ + docs/adr/ | — |
| 2. Architecture | Conversation with architect | `architecture.md` + ADRs |
| 3. Monolithic design | Designs ENTIRE epic as one coherent block | `ai26/epics/{EPIC}/design/` |
| 4. Slice into tickets | Distributes design into per-ticket dirs | `ai26/features/TBD-N/` + `plan.md` |
| 5. Materialise | Creates Jira tickets, renames TBD dirs | Jira tickets |

**Why monolithic design first?** The domain model, contracts, and events belong to the domain — not to tickets. Designing the whole epic before slicing ensures coherent field names, consistent error conventions, and no duplicate models across tickets. Slicing is a size concern (keep PRs reviewable), not a design concern.

**You do:** Approve the architecture conversation (Phase 2). Review the ticket decomposition proposal (Phase 4). Phases 3 and 5 run autonomously.

**Resume:** If interrupted, re-run `/ai26-design-epic {EPIC-ID}` — it detects existing artefacts and resumes from the right phase.

### Step 3: `/ai26-implement-user-story {TICKET-ID}` (per ticket)

| | |
|---|---|
| **Input** | `ai26/features/{TICKET}/` artefacts |
| **Output** | Kotlin source code + tests |
| **You do** | Review implementation plan. Agent implements autonomously. |

Automatic post-implementation:
1. `ai26-validate-user-story` — design-to-code coherence + test coverage
2. `/ai26-review-user-story {TICKET-ID}` — automated code review
3. `/ai26-promote-user-story {TICKET-ID}` — updates `ai26/context/` **(the Compound step)**

### Artefacts produced per ticket

| Artefact | Description | When present |
|---|---|---|
| `domain-model.yaml` | Aggregates, entities, VOs, states, methods | Always (if domain changes) |
| `use-case-flows.yaml` | Happy path + error paths per use case | Always |
| `error-catalog.yaml` | Error types, HTTP codes, messages | Always |
| `api-contracts.yaml` | Endpoints, request/response schemas | Only if HTTP surface |
| `events.yaml` | Domain events, topics, payloads | Only if events |
| `glossary.yaml` | New domain terms | Always |
| `scenarios/*.feature` | Gherkin BDD scenarios | Always |
| `ops-checklist.yaml` | Migrations, feature flags, observability | Always |
| `diagrams.md` | Mermaid diagrams (class, state, sequence, ER) | Always |

---

## 4. Flow B: Standalone Ticket

Use when a ticket was not part of an epic designed with `ai26-design-epic`.

### Fidelity 2 — Standalone feature with domain impact

```
/ai26-design-ticket {TICKET-ID}
→ /ai26-implement-user-story {TICKET-ID}
→ ai26-validate-user-story (automatic)
→ /ai26-review-user-story {TICKET-ID}
→ /ai26-promote-user-story {TICKET-ID}
```

Full artefact set. Conversational design flow identical to the old `ai26-design-user-story`.

### Fidelity 1 — Bug fix with domain impact

```
/ai26-design-ticket {TICKET-ID} --fidelity 1
→ /ai26-implement-user-story {TICKET-ID}
→ ai26-validate-user-story (automatic)
```

Minimal artefacts: `scenarios/` + `error-catalog.yaml` + `domain-model.yaml` (only if domain changes). A `fidelity: 1` marker tells the validator to relax checks for missing artefacts.

**Auto-escalation:** If during fidelity 1 design the agent discovers the fix requires new aggregates, events, API endpoints, or migrations — it escalates to fidelity 2 automatically.

---

## 5. Flow C: Quick Fix

```
/ai26-implement-fix {TICKET-ID}
```

The agent:
1. Reads ticket + `ai26/context/DEBT.md`
2. Searches codebase for affected files
3. **Evaluates escalation** before touching any code
4. Implements the fix
5. Runs `./gradlew service:test`
6. Commits with ticket ID

Suitable for: typos, dependency bumps, config changes, single-file obvious bugs.

**Escalation triggers** (agent decides, no human needed):
- Fix requires adding domain model elements → auto-escalates to fidelity 1
- Fix touches DEBT.md RISK: alto area → auto-escalates to fidelity 1
- Fix touches >3 files in non-trivial ways → auto-escalates to fidelity 1
- Fix requires a Flyway migration → auto-escalates to fidelity 1

**Full auto-escalation chain:**
```
implement-fix
  → (if complexity detected)
  → ai26-design-ticket --fidelity 1
  → ai26-implement-user-story
  → ai26-validate-user-story
```

---

## 6. Flow D: Migration

Use when an existing module was built outside AI26 standards and needs to be brought into
Clean Architecture + DDD alignment. This is a six-phase flow that ends with each extracted
ticket going through Flow B.

```
/ai26-start-sdlc --migrate {MODULE}
```

### Phase overview

| Phase | Skill | Output |
|---|---|---|
| 1. Assess | `ai26-assess-module` | `ai26/migrations/{MODULE}/assessment.md` — violations, risk areas, migration scope |
| 2. Migration PRD | `ai26-write-migration-prd` | `ai26/migrations/{MODULE}/prd.md` — business justification, success criteria |
| 3. Decompose | `ai26-decompose-migration` | `ai26/migrations/{MODULE}/plan.md` — ordered ticket list, each a vertical slice of the migration |
| 4–6. Per-ticket | Flow B (fidelity 1 or 2 per ticket) | Implementation of each migration ticket |

### Resume behaviour

If `ai26/migrations/{MODULE}/plan.md` already exists, `ai26-start-sdlc` detects it and
offers to resume:

```
Found migration plan for chat-module. Progress: 3/8 tickets complete.
Next ticket: SXG-1102 — migrate ConversationRepository

A. Continue from next migration ticket (SXG-1102)
B. Start from the beginning (/ai26-assess-module chat-module)
```

### In-progress proactive surfacing

If any module in `ai26/config.yaml` has `migration_status: in_progress`, `ai26-start-sdlc`
surfaces it at the top of the guided dialogue even when the engineer did not choose migration:

```
⚠ Module chat-module has a migration in progress (3/8 tickets complete).
Run /ai26-start-sdlc --migrate chat-module to continue, or choose a different flow.
```

---

## 7. The Compound Step (applies to all flows)

Every completed ticket feeds knowledge back via `ai26-promote-user-story`:

| File updated | What gets added |
|---|---|
| `ai26/context/DOMAIN.md` | New aggregates, entities, domain terms |
| `ai26/context/ARCHITECTURE.md` | New structural decisions |
| `ai26/context/DECISIONS.md` | Settled decisions that apply globally |
| `ai26/context/INTEGRATIONS.md` | New integrations, Kafka topics |
| `docs/adr/` | ADRs written during design |
| `ai26/context/DEBT.md` | Fragile areas flagged for future agents |

The compound effect: a codebase with 50 designed tickets produces a context set that makes ticket 51 dramatically easier to design and implement correctly. Skip the Compound step and you lose the compounding.

### Compound feedback loop

When AI output is wrong, the compound feedback skills capture the lesson so the context improves:

```
Wrong output at any step
      ↓
/ai26-compound {TICKET-ID}          ← observe and record → COMPOUND.md
      ↓
Apply correction (context file / artefact / skill / coding rule)
      ↓
Re-run the affected step
      ↓
/ai26-compound-resolve {TICKET-ID}  ← graduate → ai26/context/LEARNINGS.md
      ↓
/ai26-promote-user-story {TICKET-ID}
```

| Skill | Role |
|---|---|
| `ai26-compound` | Captures what went wrong at any SDLC checkpoint into `COMPOUND.md` |
| `ai26-compound-resolve` | Graduates resolved observations to `LEARNINGS.md`, optionally proposes CLAUDE.md rules |

`ai26-promote-user-story` is blocked if `COMPOUND.md` has pending observations.
Future agents read `LEARNINGS.md` at startup to avoid repeating past mistakes.

See `docs/ai26-sdlc/reference/compound-feedback.md` for the full reference.

---

## 8. Skill Map

| Skill | Flow | Status |
|---|---|---|
| `ai26-write-prd` | A — Epic PRD | active |
| `ai26-design-epic` | A — Architecture + Design + Decompose + Jira | active |
| `ai26-design-ticket` | B — Standalone ticket design (fidelity 1 or 2) | active |
| `ai26-implement-fix` | C — Direct implementation, no design | active |
| `ai26-assess-module` | D — Migration: assessment phase | active |
| `ai26-write-migration-prd` | D — Migration: PRD phase | active |
| `ai26-decompose-migration` | D — Migration: decompose into tickets | active |
| `ai26-implement-user-story` | A/B/D — Implementation from artefacts | active |
| `ai26-validate-user-story` | A/B — Design-to-code validation | active |
| `ai26-review-user-story` | A/B — Automated code review | active |
| `ai26-promote-user-story` | A/B — Compound step | active |
| `ai26-compound` | utility — Capture wrong AI output into COMPOUND.md | active |
| `ai26-compound-resolve` | utility — Graduate resolved observations to LEARNINGS.md | active |
| `ai26-refine-user-story` | utility — Lightweight artefact editor | active |
| `ai26-backfill-user-story` | utility — Retroactive artefact generation | active |
| `ai26-sync-context` | utility — Detect and fix context drift | active |
| `ai26-design-epic-architecture` | — | **deprecated → ai26-design-epic** |
| `ai26-decompose-epic` | — | **deprecated → ai26-design-epic** |
| `ai26-design-user-story` | — | **deprecated → ai26-design-ticket** |
