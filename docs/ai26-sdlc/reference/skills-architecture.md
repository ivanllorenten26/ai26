# Skills Architecture

> How skills are structured, distributed, and configured in AI26.

---

## Three layers of skills

Skills in AI26 are separated into three distinct layers. Each layer has a different
concern, a different audience, and a different coupling to stack and organisation.

```
┌─────────────────────────────────────────────────────────┐
│  SDLC skills                                            │
│  Orchestrate the flow. Agnóstic to stack, domain,       │
│  and artefact format. Same for every team.              │
├─────────────────────────────────────────────────────────┤
│  PM + Design skills                                     │
│  Capture intent, model decisions, produce contracts.    │
│  Opinionated but replaceable per team.                  │
├─────────────────────────────────────────────────────────┤
│  Dev + Test skills                                      │
│  Generate code and tests. Coupled to stack.             │
│  Opinionated, standardised, configurable via            │
│  config.yaml — not replaceable per team by default.│
└─────────────────────────────────────────────────────────┘
```

---

## Layer 1 — SDLC skills

These skills define the flow. They know when to invoke other skills, what gates to apply,
and how to move artefacts from one phase to the next. They do not generate code or artefacts
themselves — they orchestrate.

| Skill | Responsibility |
|---|---|
| `ai26-start-sdlc` | Single entry point — detects context, routes to correct phase, manages branch setup |
| `ai26-write-prd` | Phase 1a — PM + LLM produce a structured PRD from intent or existing document |
| `ai26-design-epic-architecture` | Phase 1b — Architect + LLM produce the technical context for an epic |
| `ai26-decompose-epic` | Phase 1c — PM + Architect + LLM decompose the epic into vertical tickets in Jira |
| `ai26-design-user-story` | Phase 2a — Design conversation that produces artefacts for a ticket |
| `ai26-implement-user-story` | Phase 2b — Reads artefacts, builds the implementation plan, orchestrates agents |
| `ai26-validate-user-story` | Phase 2c — Validates code matches artefacts, checks test coverage (automatic gate) |
| `ai26-review-user-story` | Phase 2d — Automated first-pass code review before human review |
| `ai26-promote-user-story` | Phase 2e — Promotes artefacts to permanent architecture documentation |
| `ai26-refine-user-story` | Utility — lightweight artefact editor, updates a single artefact without re-running design |
| `ai26-backfill-user-story` | Utility — generates artefacts from existing code for features built outside the flow |

SDLC skills read `ai26/config.yaml` to know which PM+Design skills and Dev+Test skills
to invoke. They do not hardcode any skill names — they delegate to whatever the team
has configured.

---

## Layer 2 — PM + Design skills

These skills capture intent and produce contracts. They are opinionated about format
and process, but a team can replace them with their own if they have a different way
of working — as long as their output satisfies the contract that SDLC skills expect
(see "The artefact contract" below).

| Skill | Phase | Audience |
|---|---|---|
| `ai26-write-prd` | 1a | PM + LLM |
| `ai26-design-epic-architecture` | 1b | Architect + LLM |
| `ai26-decompose-epic` | 1c | PM + Architect + LLM |
| `ai26-design-user-story` | 2a | Engineer + Architect + LLM |

### What `ai26-write-prd` does

Supports two entry points:

**From an existing document:**
The PM provides a document (upload, paste, or file path). The LLM reads it, identifies
gaps, ambiguities, and missing edge cases, and opens a conversation to refine it.
Output: a structured PRD that is complete and consistent.

**From scratch:**
The PM describes the initiative in natural language. The LLM uses the configured
interaction style (socratic by default) to help the PM articulate scope, actors,
use cases, constraints, and success criteria.
Output: same structured PRD.

The LLM loads `ai26/context/DOMAIN.md` and `ai26/context/DECISIONS.md` before starting —
it uses existing domain knowledge to detect gaps and avoid redefining settled concepts.

### What `ai26-design-epic-architecture` does

The architect reads the PRD and opens a technical conversation with the LLM.
The LLM loads the full `ai26/context/` and existing `docs/architecture/` to detect:

- Which aggregates and bounded contexts are affected
- Whether database migrations are needed
- Which areas in `DEBT.md` the epic touches (RISK: alto surfaces immediately)
- External service dependencies
- Decisions that need an ADR before implementation can start

Output: a technical context document for the epic — not a detailed design,
but enough for informed ticket decomposition.

### What `ai26-decompose-epic` does

Takes the PRD and the epic technical context as input. PM + architect + LLM
decompose the epic into vertical tickets.

**Vertical** means each ticket delivers user-observable value and crosses all layers
(domain, application, infrastructure, API, tests). A ticket is never a single layer.

The LLM applies the efficiency principle from lean thinking: the unit of delivery is
value, not technical work. It will flag decompositions that are too horizontal
(a ticket per layer) or too large (a ticket that contains multiple independent value slices).

Each ticket produced includes:
- Title and description
- Acceptance criteria (business-readable)
- Technical notes (from the epic architecture context)
- Risk level (informed by DEBT.md)
- Dependencies on other tickets

Tickets are created in Jira via MCP on confirmation. The decomposition is iterative —
PM and architect can merge, split, or reorder before committing.

---

## Layer 3 — Dev + Test skills

These skills generate code and tests. They encode the team's opinionated way of writing
software — architecture patterns, naming conventions, test strategy.

**The default set is standardised.** Teams do not choose their architecture style
from a menu. The skills encode one way of doing things, and that consistency is the
source of efficiency — engineers moving between teams find the same patterns everywhere.

Teams configure the skills for their repository structure via `ai26/config.yaml`.
They do not replace the skills.

| Category | Skills |
|---|---|
| Domain | `dev-create-aggregate`, `dev-create-entity`, `dev-create-value-object`, `dev-create-domain-service`, `dev-create-domain-event`, `dev-create-domain-exception` |
| Application | `dev-create-use-case` |
| Infrastructure | `dev-create-rest-controller`, `dev-create-jpa-repository`, `dev-create-jooq-repository`, `dev-create-api-client`, `dev-create-kafka-publisher`, `dev-create-kafka-subscriber`, `dev-create-sqs-publisher`, `dev-create-sqs-subscriber` |
| Database | `dev-create-flyway-migration`, `dev-generate-jooq-schema` |
| Testing | `test-create-use-case-tests`, `test-create-controller-tests`, `test-create-feature-tests`, `test-create-integration-tests`, `test-create-architecture-tests`, `test-create-contract-tests`, `test-create-mother-object` |

### What teams configure

Dev + Test skills read `ai26/config.yaml` for repository-specific values.
All path and convention resolution goes through the `modules` list:

```yaml
stack:
  language: kotlin
  framework: spring-boot
  build: gradle

modules:
  - name: service
    path: service/
    active: true
    base_package: de.tech26.myservice
    conventions:
      repository_type: jooq
      error_handling: either
      test_containers: true
      event_bus: kafka
    flyway:
      enabled: true
      path: service/src/main/resources/db/migration
```

Skills resolve `base_package`, `repository_type`, `error_handling`, and `flyway`
from the target module entry. The target module is determined per subtask —
a ticket spanning two modules produces subtasks with different module targets.
Skills never hardcode paths or package names.

### The escape hatch

If a team has a genuinely exceptional case — a legacy service, a non-standard stack,
a specific constraint — they can override an individual skill by placing a local
version at `.claude/skills/{skill-name}/SKILL.md`. The skill loader checks the local
path first.

This is an escape hatch, not a feature. It should be documented in `DEBT.md` with a
reason and a plan to converge back to the standard.

---

## The artefact contract

SDLC skills do not care how artefacts were produced — they care that the artefacts
exist and are valid. This is the contract that any PM+Design skill must satisfy
for `ai26-implement-user-story` to work:

```
ai26/features/{TICKET}/
  domain-model.yaml         required
  use-case-flows.yaml       required
  error-catalog.yaml        required
  scenarios/                required (at least one .feature file)
  api-contracts.yaml        required if artefacts.api_contract: true
  events.yaml               required if artefacts.events: true
  glossary.yaml             optional
  ops-checklist.yaml        optional
```

If a team replaces `ai26-design-user-story` with their own skill, their skill must produce
this directory structure. `ai26-validate-user-story` will check it before implementation
proceeds.

The schemas for each file are published alongside the marketplace skills.
Teams using the default `ai26-design-user-story` skill get them automatically.
Teams using a custom design skill must conform to the same schemas or provide their own
and configure `ai26-validate-user-story` to use them.

---

## Distribution model

Skills are published to the Claude marketplace as a package.

```
marketplace package: ai26
  └── skills/
        sdlc-*              SDLC orchestration skills
        design-*            PM + Design skills
        dev-*               Dev skills (default stack: kotlin-spring)
        test-*              Test skills (default stack: kotlin-spring)
```

Teams install the package. Each skill reads `ai26/config.yaml` from the repository
where it executes. No coupling to any specific repository.

Future stack packages (e.g. `ai26-node-express`, `ai26-python-fastapi`) would provide
alternative `dev-*` and `test-*` skills for different stacks, while reusing the same
SDLC and Design skills unchanged.

---

## The complete flow

```
LEVEL 1 — Product planning (epic → tickets)

  /ai26-write-prd {EPIC}
    PM + LLM
    Input:  business initiative (document or conversation)
    Output: structured PRD in ai26/epics/{EPIC}/prd.md

  /ai26-design-epic-architecture {EPIC}
    Architect + LLM
    Input:  PRD + ai26/context/ + docs/architecture/
    Output: technical context in ai26/epics/{EPIC}/architecture.md
            ADRs if epic-level decisions are made

  /ai26-decompose-epic {EPIC}
    PM + Architect + LLM
    Input:  PRD + architecture context
    Output: vertical tickets created in Jira via MCP


LEVEL 2 — Feature implementation (ticket → production)

  /ai26-start-sdlc {TICKET}  →  routes to ai26-design-user-story
  /ai26-design-user-story {TICKET}
    Engineer (+ Architect if needed) + LLM
    Input:  Jira ticket (read via MCP) + ai26/context/ + existing module docs
    Output: ai26/features/{TICKET}/ artefacts + ADRs

  /ai26-implement-user-story {TICKET}
    Orchestrator + agents (engineer reviews plan before execution)
    Input:  ai26/features/{TICKET}/ artefacts + ai26/config.yaml
    Output: plan.md + subtask files → code via dev-* and test-* skills

  /ai26-validate-user-story {TICKET}   ← automatic gate at end of ai26-implement-user-story
    Input:  generated code + artefacts + Jira ACs
    Output: validation report — proposed corrections for any violations

  /ai26-review-user-story {TICKET}
    LLM (first-pass review)
    Input:  generated code + artefacts
    Output: review report — human review still required

  /ai26-promote-user-story {TICKET}
    LLM
    Input:  ai26/features/{TICKET}/ artefacts + ADRs + proposed context updates
    Output: docs/architecture/modules/{module}/ updated
            ai26/context/ updated if new global constraints emerged
```
