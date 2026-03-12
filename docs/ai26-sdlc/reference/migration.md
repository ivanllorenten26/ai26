# Migration Reference

> End-to-end guide for migrating a legacy Spring Boot module to AI26 standard.

---

## Overview

Migration is Flow D in the AI26 SDLC. It takes a legacy module — built without Clean
Architecture, DDD, or AI26 conventions — and incrementally replaces it with
correctly-structured code, producing a complete context layer along the way.

```
/ai26-start-sdlc --migrate {MODULE}
        │
        ▼
Phase 1 — Assess        /ai26-assess-module {MODULE}
        │                   Output: ai26/migrations/{MODULE}/assessment.yaml
        ▼
Phase 2 — Migration PRD  /ai26-write-migration-prd {MODULE}
        │                   Output: ai26/migrations/{MODULE}/prd.md
        ▼
Phase 3 — Decompose      /ai26-decompose-migration {MODULE}
        │                   Output: ai26/migrations/{MODULE}/plan.md + Jira tickets
        ▼
Phases 4–6 — Per ticket  /ai26-start-sdlc {TICKET-ID}  (repeated per ticket)
                            Flow B (design → implement → validate → review → promote)
```

All contracts extracted in Phase 1 are **non-negotiable** — the new implementation
must preserve HTTP API shapes, event topic names and payload structure, and database
schema compatibility.

See [migration-strategy.md](../vision/migration-strategy.md) for the strategic rationale.

---

## Phase 1 — Assess (`ai26-assess-module`)

```
/ai26-assess-module {MODULE}
```

Reads every Kotlin file in the module, classifies it by actual role (not package name),
extracts all contracts, discovers domain concepts, and identifies gaps and risks.

**What it scans:**
- Every Kotlin file: controllers, services, repositories, entities, DTOs, listeners, publishers, config
- HTTP endpoints (from Spring mapping annotations)
- Event topics (from `@KafkaListener`, `KafkaTemplate`, `@SqsListener`, `SqsTemplate`)
- Database schema (from JPA entities + Flyway migration files)
- External service calls (from Retrofit, `WebClient`, `FeignClient`, `RestTemplate`)

**Human decision point:** After scanning, the skill shows a summary and asks for
corrections before writing `assessment.yaml`. This is your one opportunity to fix
misclassifications before they propagate to the PRD.

**Output:** `ai26/migrations/{MODULE}/assessment.yaml`

See [migration-assessment-format.md](migration-assessment-format.md) for the full schema.

**Config change:** `migration_status: in_progress` is added to the module entry in
`ai26/config.yaml`. This triggers the in-progress banner in `ai26-start-sdlc`.

---

## Phase 2 — Migration PRD (`ai26-write-migration-prd`)

```
/ai26-write-migration-prd {MODULE}
```

A design conversation between the engineer and the AI. Reads the assessment and
produces the target architecture and migration strategy.

**What it decides (with engineer):**
1. Target bounded contexts — which domain concepts belong together
2. Target aggregates per context — what the rich domain model looks like
3. Target use cases — what operations each aggregate exposes
4. Migration pattern per aggregate — Strangler Fig, Branch by Abstraction, or Expand-Contract
5. Migration order — least coupled first, highest business value first

**Hard constraint:** All API, event, and database contracts from `assessment.yaml`
are listed as NON-NEGOTIABLE in the PRD. The conversation may refine names and
structure, but cannot change external contracts without an explicit Expand-Contract plan.

**Human decision points:**
- Approve or adjust each proposed bounded context boundary
- Approve or adjust each aggregate and its states
- Approve the migration order (reorder if priorities differ)

**Output:** `ai26/migrations/{MODULE}/prd.md`

---

## Phase 3 — Decompose (`ai26-decompose-migration`)

```
/ai26-decompose-migration {MODULE}
```

Takes the approved PRD and generates one migration ticket per aggregate/use case.

**Each ticket includes:**
- What legacy code is being replaced (specific class names from `assessment.yaml`)
- Target architecture (aggregate, use cases, ports)
- Contract constraints reproduced verbatim (NON-NEGOTIABLE section)
- Acceptance criteria:
  - Domain rules: D-01 through D-14 compliance
  - Error handling: Either sealed class (A-01, CC-03)
  - Tests: controller tests (T-07), TestContainers integration tests (T-01)
  - Contract preservation: legacy code still compiles + same external behaviour
  - `ai26-validate-user-story` passes

**Human decision point:** Review the proposed ticket list and order before Jira
creation. Reorder, split, or merge tickets at this stage.

**Output:** `ai26/migrations/{MODULE}/plan.md` + Jira tickets (optional via MCP)

---

## Phases 4–6 — Per-ticket (Flow B)

Each migration ticket goes through the standard Flow B:

```
/ai26-start-sdlc {TICKET-ID}
        │
        ▼
/ai26-design-ticket {TICKET-ID}     ← reads assessment.yaml + prd.md as additional context
        │
        ▼
/ai26-implement-user-story {TICKET-ID}
        │
        ▼
ai26-validate-user-story            ← automatic
        │
        ▼
/ai26-review-user-story {TICKET-ID}
        │
        ▼
/ai26-promote-user-story {TICKET-ID}
```

`ai26-design-ticket` automatically loads `assessment.yaml` and `prd.md` when it detects
the ticket belongs to a migration (reads `ai26/migrations/*/plan.md` and checks if the
ticket ID appears in it). Contract constraints are surfaced before the design conversation.

---

## Configuration

Migration state is tracked in `ai26/config.yaml`:

```yaml
modules:
  - name: service
    path: service/
    migration_status: in_progress    # pending | in_progress | completed
    migration_plan: ai26/migrations/service/plan.md
```

| Value | Meaning |
|---|---|
| `pending` (or absent) | No migration started |
| `in_progress` | Assessment done, migration underway |
| `completed` | All tickets complete, legacy code deleted |

When `migration_status: in_progress`, `ai26-start-sdlc` surfaces a proactive banner:

```
⚠ Module service has a migration in progress (3/8 tickets complete).
Run /ai26-start-sdlc --migrate service to continue, or choose a different flow.
```

---

## Resumability

Migrations span multiple sprints. `ai26-start-sdlc` detects the state and offers
to resume from the right place:

**No assessment yet:**
```
/ai26-start-sdlc --migrate service
→ Runs /ai26-assess-module service
```

**Assessment done, no PRD:**
```
/ai26-start-sdlc --migrate service
→ Runs /ai26-write-migration-prd service
```

**PRD done, no plan:**
```
/ai26-start-sdlc --migrate service
→ Runs /ai26-decompose-migration service
```

**Plan exists, tickets in progress:**
```
/ai26-start-sdlc --migrate service

Found migration plan for service. Progress: 3/8 tickets complete.
Next ticket: SXG-1102 — migrate ConversationRepository

A. Continue from next migration ticket (SXG-1102)
B. Start from the beginning (/ai26-assess-module service)
```

---

## Cutover

When all tickets in `plan.md` are marked complete:

1. Run `ai26-sync-context` to verify the context layer reflects the migrated domain
2. Delete the legacy classes that have been replaced (the Strangler Fig has fully grown)
3. Update `migration_status: completed` in `ai26/config.yaml`
4. Delete `ai26/migrations/{MODULE}/` (optional — keep for historical reference)

The legacy code deletion is a deliberate, manual step. Do not auto-delete — verify
that all tests pass and no other module references the deleted classes.

---

## Files produced

| File | Phase | Lifetime |
|---|---|---|
| `ai26/migrations/{MODULE}/assessment.yaml` | Phase 1 | Permanent reference |
| `ai26/migrations/{MODULE}/prd.md` | Phase 2 | Permanent reference |
| `ai26/migrations/{MODULE}/plan.md` | Phase 3 | Permanent reference |
| `ai26/features/{TICKET}/` | Phases 4–6 (per ticket) | Deleted after promotion |

---

## Reference

- [Migration strategy](../vision/migration-strategy.md) — why Strangler Fig, why extract-then-reimplement
- [Assessment format](migration-assessment-format.md) — full assessment.yaml schema
- [Migration recipe](../../coding-standards/recipes/migration.md) — before/after code patterns
- [flows.md — Flow D](flows.md) — skill map and phase overview
