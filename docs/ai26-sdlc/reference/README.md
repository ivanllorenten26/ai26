# AI26 — AI-Augmented Software Development Lifecycle

> Status: theoretical proposal
> Date: 2026-03-07

---

## What this is

AI26 is a distributed, configurable AI-augmented development lifecycle.

It covers the full spectrum from business initiative to production code — product planning,
architectural design, implementation, validation, and promotion to permanent documentation.

The core skills are published to a Claude marketplace and installed per team. Each team
owns its configuration and context. Nothing is hardcoded to a specific repository.

---

## Core principles

### 1. The human is the architect

The LLM does not make architectural decisions. It helps the human make better decisions
faster — by asking the right questions, surfacing trade-offs, and structuring what the
human already knows.

When a decision is made, it is documented immediately — not at the end of the feature.

### 2. Context is explicit and versioned

Every team maintains a `ai26/context/` directory in their repository. This is the shared
knowledge base that all skills read before doing anything. Skills are only as good as
the context they receive. Keeping `ai26/context/` accurate is a team discipline.

### 3. Configurable interaction style

Teams configure their preferred default. Can be overridden per invocation:

- **Socratic** — LLM asks questions that lead the human to articulate decisions. Best for
  high-impact architectural decisions where the reasoning matters as much as the outcome.
- **Proactive** — LLM makes a reasoned recommendation. Human validates or challenges.
  Best when context is well-documented.
- **Reactive** — LLM presents options with trade-offs and waits. Best for lower-stakes
  decisions or when the human already has a strong prior.

### 4. Two levels of decision

| Level | What | Where |
|---|---|---|
| **Architectural context** | Global decisions already taken — not debated, just documented | `ai26/context/DECISIONS.md` |
| **ADR** | Domain modelling, data design, inter-component communication decisions — debated with LLM, documented when taken | `docs/adr/` |

### 5. Artefacts as contracts

Design produces reviewable artefacts before any code is written. No implementation
without a reviewed contract. The format is configurable. The gate is not.

### 6. Standardised implementation, not a menu

Implementation skills encode one opinionated way of writing software. Teams do not
choose their architecture style — they configure paths and conventions. Consistency
across teams is the source of efficiency: an engineer moving between teams finds the
same patterns everywhere.

### 7. Persistent plans, resilient execution

All work in progress is persisted in plan files committed to git. The system recovers
from any interruption — session loss, connection failure, partial execution — by reading
the last committed plan state and continuing from there.

### 8. Every step is a commit

Every completed phase or sub-phase produces a commit and a push. By the time a feature
is done, a branch exists with full history and a PR ready for human review.
Full traceability from business intent (Jira) to code (git).

### 9. Distributed, not coupled

Skills are published to a Claude marketplace. Teams install them without forking.
Each team provides its own configuration and context. The skills adapt to the team.

---

## Repository layout (per team)

```
repo/
  ai26/
    config.yaml               ← team configuration (style, artefacts, stack, conventions)
    context/
      ARCHITECTURE.md         ← architectural constraints and patterns
      DECISIONS.md            ← global architectural decisions (not ADRs)
      DEBT.md                 ← known technical debt with risk levels
      INTEGRATIONS.md         ← inbound/outbound integrations, events, AI/ML services
    domain/
      {module}/
        {aggregate}.md        ← Mermaid diagram + YAML per aggregate
    epics/
      {EPIC-ID}/
        prd.md
        architecture.md
        plan.md
    features/
      {TICKET-ID}/
        plan.md
        subtasks/
        domain-model.yaml
        use-case-flows.yaml
        error-catalog.yaml
        api-contracts.yaml
        events.yaml
        glossary.yaml
        scenarios/
        ops-checklist.yaml
  .claude/
    skills/                   ← optional local overrides of marketplace skills
  docs/
    adr/                      ← Architecture Decision Records
    architecture/
      modules/{module}/       ← permanent promoted documentation
      epics/                  ← promoted epic architecture
      diagrams/               ← generated C1 and C4 Mermaid diagrams
```

---

## The full flow

### Level 1 — Product planning (epic → tickets)

```
/ai26-start-sdlc {EPIC-ID} or new initiative

  Phase 1a — PRD
  PM + LLM
  Input:  business initiative (existing document or conversation from scratch)
  Output: ai26/epics/{EPIC}/prd.md — structured, complete, edge cases identified
  Commit: {EPIC-ID} prd: structured PRD complete

  Phase 1b — Epic Architecture
  Architect + LLM
  Input:  PRD + ai26/context/ + docs/architecture/
  Output: ai26/epics/{EPIC}/architecture.md — affected domain, migrations, debt, decisions
  Commit: {EPIC-ID} architecture: epic technical context complete

  Phase 1c — Decomposition
  PM + Architect + LLM
  Input:  PRD + architecture context
  Output: vertical tickets created in Jira (via MCP)
  Commit: {EPIC-ID} decompose: {N} tickets created in Jira
```

### Level 2 — Feature implementation (ticket → production)

```
/ai26-start-sdlc {TICKET-ID}

  /ai26-design-user-story {TICKET}
  Engineer + LLM (configured interaction style)
  Input:  Jira ticket + ai26/context/ + existing module docs
  Output: ai26/features/{TICKET}/ artefacts + ADRs
  Commit: per artefact as it is written

  /ai26-implement-user-story {TICKET}
  Orchestrator + agents (engineer reviews plan before execution)
  Input:  design artefacts + ai26/config.yaml
  Output: plan.md + subtask files → code, subtask by subtask
  Commit: per subtask completed

  /ai26-validate-user-story {TICKET}   ← automatic gate at end of ai26-implement-user-story
  Input:  code + artefacts + Jira ACs
  Checks: design↔code coherence, test coverage, ticket↔design coherence
  Output: validation report — blocking violations proposed and fixed
  Commit: {TICKET-ID} validate: all checks passing

  /ai26-review-user-story {TICKET}
  LLM (first-pass review)
  Input:  code + artefacts
  Checks: layer rules, DDD patterns, error handling, API/event contract alignment
  Output: review report — human review still required
  Commit: {TICKET-ID} review: automated review passing

  /ai26-promote-user-story {TICKET}
  Input:  artefacts + ADRs + proposed context updates
  Gates:  /ai26-sync-context --report (drift check before commit)
  Output: docs/architecture/modules/{module}/ updated, ai26/context/ updated if needed,
          C1/C4 diagrams regenerated if integrations changed
  Commit: {TICKET-ID} promote: artefacts merged to architecture docs
```

Maintenance skill (can be run at any time):

```
/ai26-sync-context              → detect and fix drift between code and ai26/context/ files
/ai26-sync-context --report     → report only, no writes
```

---

## Entry points

Any flow can start at any point. `/ai26-start-sdlc` routes to the right place:

```
/ai26-start-sdlc                    → asks: new epic, existing epic, new ticket, existing ticket
/ai26-start-sdlc {EPIC-ID}          → detects epic, continues from last completed phase
/ai26-start-sdlc {TICKET-ID}        → detects ticket, bootstrap evaluation, starts design
```

For teams adopting AI26 on existing projects, partial entry is supported —
a ticket can be started without an epic, and existing artefacts are loaded
and continued rather than replaced.

See `entry-points.md` for full detail.

---

## What the system does NOT do

- Make product or architectural decisions
- Write database migration SQL (marks with TODO for human review)
- Configure infrastructure
- Open PRs — the branch is ready, the engineer opens the PR
- Update `ai26/context/` or write ADRs without human confirmation
- Retry failed subtasks silently — failures are visible in git history

---

## Document index

| Document | What it covers |
|---|---|
| `README.md` | This file — vision, principles, full flow |
| `configuration.md` | `ai26/config.yaml` schema, `ai26/context/` files, defaults, local overrides |
| `entry-points.md` | `/ai26-start-sdlc` routing, all entry scenarios, partial adoption |
| `level1-flow.md` | PRD (1a), epic architecture (1b), decomposition (1c) in detail |
| `design-phase.md` | Design conversation — interaction styles, decision detection, artefact writing |
| `decision-model.md` | Two-level decisions — context vs ADR, formats, lifecycle |
| `artefacts.md` | All design artefacts with YAML examples and cross-reference rules |
| `skills-architecture.md` | Three skill layers, distribution model, artefact contract |
| `context-management.md` | Plan files, subtask details, orchestrator behaviour, recovery, parallelism |
| `validation.md` | Three validation responsibilities, automatic gate, proposed corrections |
| `promotion.md` | Single promotion operation — artefacts, ADRs, context, epic promotion |
| `version-control.md` | Branch/commit conventions, automatic commits, interrupted session recovery |
| `onboarding.md` | How a team adopts AI26 from scratch — prerequisites, setup, first run, existing codebases |
| `aggregate-format.md` | Format for `ai26/domain/{module}/{aggregate}.md` files — Mermaid diagram + YAML model |
| `context-files.md` | Format and content guide for all `ai26/context/` files |
| `context-mapping.md` | Integration registry format (`INTEGRATIONS.md`) and C1/C4 diagram generation |

---

## Relationship to previous proposals

| | sdlc/ | sdlc2/ | ai26/ |
|---|---|---|---|
| **Scope** | Feature lifecycle only | Feature lifecycle + context layer | Full: epic → PRD → design → code → production |
| **Human role** | Architect (drives design Q&A) | Reviewer (approves LLM proposals) | Architect (debates with LLM) |
| **LLM interaction** | Structured interview | Autonomous with gates | Configurable: socratic / proactive / reactive |
| **Context layer** | Implicit | Explicit `ai26/context/` | Explicit, versioned, team-owned |
| **Decision documentation** | Manual, post-hoc | Not explicit | Two levels, in the moment, committed immediately |
| **Implementation** | Sequential skills, human orchestrates | Autonomous agents | Persistent plan, orchestrated agents, parallelism via dependency graph |
| **Resilience** | None — session loss loses progress | None | Full — plan persisted in git, deterministic recovery |
| **Version control** | Manual | Manual | Automatic commit+push per phase |
| **Distribution** | Coupled to repo | Coupled to repo | Marketplace, decoupled |
| **Standardisation** | One stack (Kotlin+Spring) | Not explicit | Opinionated default, configurable, escape hatch documented |
