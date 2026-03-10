# Context Files

> Format and content guide for `ai26/context/` and `ai26/domain/` files.

---

## Overview

The `ai26/context/` directory is the shared knowledge base that all skills read
before executing. It contains knowledge that lives in engineers' heads but is not
expressed in the code — bounded context ownership, architectural constraints, code
conventions, global decisions, and technical debt.

Skills are only as good as the context they receive. Keeping these files accurate
is a team discipline, not an automated task.

---

## `DOMAIN.md`

**Who reads it:** `ai26-write-prd`, `ai26-design-epic-architecture`, `ai26-design-user-story`,
`ai26-backfill-user-story`

**What the LLM uses it for:**
- Detect which bounded context a ticket belongs to
- Identify existing aggregates before proposing new ones
- Apply the correct vocabulary — reject synonyms, use canonical terms
- Respect context boundaries — not cross ownership lines

**Rule:** if an aggregate is not listed here, the LLM will assume it does not exist
and may create a duplicate. The aggregate table must be complete.

### Format

```markdown
# Domain

---

## Bounded contexts

### {ContextName}

Source: `{module}/src/main/kotlin/{base_package}/{context-package}/`
Owns: {what this context owns and is responsible for.}
Does NOT own: {what explicitly belongs to other contexts}.

#### Aggregates

| Aggregate | Module | File |
|---|---|---|
| {AggregateName} | {module-name} | `ai26/domain/{module}/{aggregate}.md` |

#### Ubiquitous language

| Term | Definition | Avoid |
|---|---|---|
| {Term} | {Definition as a business person would say it} | {Synonyms to reject} |
```

### Example

```markdown
# Domain

---

## Bounded contexts

### Conversations

Source: `service/src/main/kotlin/de/tech26/valium/domain/conversation/`
Owns: full lifecycle of a support conversation — creation, assignment, messaging, escalation, and closure.
Does NOT own: agent identity, routing rules, SLA configuration.

#### Aggregates

| Aggregate | Module | File |
|---|---|---|
| Conversation | service | `ai26/domain/service/conversation.md` |

#### Ubiquitous language

| Term | Definition | Avoid |
|---|---|---|
| Conversation | A support thread between a customer and one or more agents | Ticket, Case, Thread |
| Close | Marking a conversation as resolved by an agent | Resolve, Complete, Finish |
| Escalate | Transferring a conversation to a supervisor or specialist | Escalation, Forward |
| Message | A single communication sent within a conversation | Comment, Note, Reply |

---

### Agents

Source: `service/src/main/kotlin/de/tech26/valium/domain/agent/`
Owns: agent profiles, availability, and skill configuration.
Does NOT own: conversation state, routing decisions.

#### Aggregates

| Aggregate | Module | File |
|---|---|---|
| Agent | service | `ai26/domain/service/agent.md` |

#### Ubiquitous language

| Term | Definition | Avoid |
|---|---|---|
| Agent | A support team member who handles conversations | User, Operator, Rep |
| Availability | Whether an agent can currently receive new conversations | Status, Online, Active |
```

---

## `ARCHITECTURE.md`

**Who reads it:** `ai26-design-epic-architecture`, `ai26-design-user-story`,
`ai26-review-user-story`

**What the LLM uses it for:**
- Apply non-negotiable structural constraints without debating them
- Detect when a proposed design violates a layer rule or structural constraint
- Know where code must and must not live before proposing file locations

**Rule:** only structural constraints belong here — what is prohibited, what layers
exist, what can depend on what. The *why* behind each constraint belongs in
`DECISIONS.md`. Do not duplicate it here.

What does NOT belong here:
- Testing strategy (TestContainers, mocking rules) → `ai26/config.yaml`
- Flyway paths or migration conventions → `ai26/config.yaml`
- Error handling patterns (Either, exceptions) → `ai26/config.yaml` + skills
- The reasoning behind any rule → `DECISIONS.md`

### Format

```markdown
# Architecture

---

## Style

{Architectural style in one sentence. Sets the frame for everything below.}

---

## Layer rules

| Layer | Path | Can depend on | Cannot depend on |
|---|---|---|---|
| domain | `{module}/src/main/kotlin/{pkg}/domain/` | nothing | application, infrastructure, any framework |
| application | `{module}/src/main/kotlin/{pkg}/application/` | domain | infrastructure, any framework except @Service |
| infrastructure/inbound | `{module}/src/main/kotlin/{pkg}/infrastructure/inbound/` | domain, application | — |
| infrastructure/outbound | `{module}/src/main/kotlin/{pkg}/infrastructure/outbound/` | domain | application |

---

## Constraints

- {Structural rule — stated as a prohibition or requirement, not a preference}
- {Another rule}
```

### Example

```markdown
# Architecture

---

## Style

Clean Architecture + DDD. Domain layer has zero framework dependencies.
Infrastructure is split into inbound (controllers, subscribers) and outbound
(repositories, publishers, clients). Nothing lives flat in `infrastructure/`.

---

## Layer rules

| Layer | Path | Can depend on | Cannot depend on |
|---|---|---|---|
| domain | `service/src/main/kotlin/de/tech26/valium/domain/` | nothing | application, infrastructure, any framework |
| application | `service/src/main/kotlin/de/tech26/valium/application/` | domain | infrastructure, any framework except @Service |
| infrastructure/inbound | `service/src/main/kotlin/de/tech26/valium/infrastructure/inbound/` | domain, application | — |
| infrastructure/outbound | `service/src/main/kotlin/de/tech26/valium/infrastructure/outbound/` | domain | application |

---

## Constraints

- Aggregate roots: private constructor + `companion object { fun create(...) }`. Never `data class`.
- Use cases return `Either<DomainError, T>`. Never throw domain exceptions to callers.
- Repository interfaces are defined in `domain/`. Implementations live in `infrastructure/outbound/`.
- Controllers and subscribers are humble objects — no business logic, no domain decisions.
- Nothing lives flat in `infrastructure/` — all classes are in `inbound/` or `outbound/`.
- The `application/` module is legacy — do not add new code there unless explicitly instructed.
```

---

## `DECISIONS.md`

**Who reads it:** `ai26-design-user-story`, `ai26-write-prd`,
`ai26-design-epic-architecture`

**What the LLM uses it for:**
- Apply domain modelling decisions as constraints — not re-debate them
- Detect when a ticket proposes a design that conflicts with a settled decision
- Understand the reasoning behind bounded context boundaries and aggregate design

**Rule:** system design decisions belong here — why the system is shaped the way
it is. This covers domain modelling, data modelling, inter-component communication,
and infrastructure choices. How code is written belongs in the skills, not here.
Feature-specific decisions belong in ADRs (`docs/adr/`).

### Format

```markdown
# Decisions

---

## {Decision title}

**Decision:** {What was decided, in one sentence.}
**Why:** {The business or domain reason — what problem this solves or what complexity this avoids.}
**Applies to:** {Which bounded context or area of the domain this affects.}
```

### Example

```markdown
# Decisions

---

## Conversation is the aggregate root, not Message

**Decision:** Conversation owns its Messages. Message has no identity or lifecycle
outside of its parent Conversation.
**Why:** The business never operates on a message in isolation — messages are always
read, sent, or deleted in the context of a conversation. Modelling Message as a
separate aggregate would create artificial lifecycle complexity with no business value.
**Applies to:** Conversations bounded context.

---

## Agent and Conversation are separate bounded contexts

**Decision:** Agent identity and availability live in the Agents context.
Conversation only holds a reference to AgentId — it never owns agent data.
**Why:** Agent availability changes at a different frequency than conversation state.
Coupling them caused contention and forced unnecessary coordination between
unrelated operations. A conversation closing should not need to know anything
about the agent beyond their ID.
**Applies to:** All features touching both agents and conversations.

---

## Escalation is a state transition, not a separate aggregate

**Decision:** Escalation is modelled as a transition within Conversation
(ASSIGNED → ESCALATED), not as a separate Escalation aggregate.
**Why:** Escalation has no identity or lifecycle beyond the conversation it belongs to.
It does not need to be queried, persisted, or referenced independently.
Creating a separate aggregate would add indirection without adding expressiveness.
**Applies to:** Conversations bounded context.

---

## Conversation events are published to Kafka, not consumed directly by other services

**Decision:** Any service that needs to react to conversation state changes
consumes Kafka events. No service calls the Conversations API to poll for changes.
**Why:** Polling creates tight coupling and unpredictable load. Event-driven
consumption lets each consumer control its own pace and retry strategy.
**Applies to:** All inter-service communication involving Conversations.

---

## Messages are stored in the same table as Conversations, not a separate schema

**Decision:** The `messages` table lives in the same database schema as `conversations`.
There is no separate messages service or database.
**Why:** Messages have no meaning outside their conversation. Splitting them into a
separate schema would require joins across schema boundaries for the most common
read pattern (load conversation with its messages).
**Applies to:** Conversations data model.
```

---

## `INTEGRATIONS.md`

**Who reads it:** `ai26-design-epic-architecture`, `ai26-design-user-story`,
`ai26-validate-user-story`, `ai26-promote-user-story`

**What the LLM uses it for:**
- Detect when a ticket introduces a new integration not yet registered
- Warn when a ticket modifies an integration that has downstream consumers
- Inform epic architecture analysis with the current integration surface
- Generate and update C1/C4 Mermaid diagrams on promotion

**Rule:** every inbound endpoint, outbound HTTP call, event emitted, event consumed,
and AI/ML service must have an entry. If an integration is not listed, the LLM treats
it as new and flags it for registration.

Full format reference and diagram generation rules: `context-mapping.md`.

### Format

```markdown
# Integrations

---

## Inbound HTTP

| Method | Path | Description | Auth |
|---|---|---|---|
| {METHOD} | {/path} | {What this endpoint does} | {none / jwt / api-key} |

---

## Outbound HTTP

### {ServiceName}

Base URL: `{base URL or config key}`
Purpose: {Why we call this service}

| Method | Path | Description |
|---|---|---|
| {METHOD} | {/path} | {What we use this call for} |

---

## Events emitted

| Event | Topic / Queue | Trigger | Schema file |
|---|---|---|---|
| {EventName} | {topic} | {What causes this event} | `{path}` |

---

## Events consumed

| Event | Topic / Queue | Source service | Handler |
|---|---|---|---|
| {EventName} | {topic} | {Source service} | {Use case or handler} |

---

## AI / ML services

### {ServiceName}

Provider: {bedrock / openai / vertex / ...}
Purpose: {What we use this for}

| Model / Resource | Used for |
|---|---|
| {model-id} | {Specific use} |

---

## Downstream services

| Service | How it depends on us | Impact of breaking change |
|---|---|---|
| {ServiceName} | {calls /path or consumes {EventName}} | {What breaks} |
```

---

## `DEBT.md`

**Who reads it:** `ai26-design-epic-architecture`, `ai26-design-user-story`

**What the LLM uses it for:**
- Surface warnings when a ticket touches a high-risk area
- Recommend pausing for epic architecture analysis when RISK: alto is detected
- Inform ticket risk levels during decomposition

**Rule:** every entry needs a risk level. Without it, the LLM cannot prioritise.
`alto` surfaces immediately and may block the design conversation.

### Format

```markdown
# Debt

---

## {Area name}

Risk: alto | medio | bajo
**What:** {What the problem is.}
**Why it's a risk:** {What could go wrong if this area is touched carelessly.}
**Known workaround:** {How the team currently deals with it, if any.}
**Plan:** {Resolution plan with timeline and tracking reference. Omit if no plan exists.}
```

### Example

```markdown
# Debt

---

## Legacy conversation state machine

Risk: alto
**What:** The `application/` module has a parallel conversation state machine that
partially overlaps with the `service/` module. Both are active in production.
**Why it's a risk:** Changes to conversation states in `service/` may conflict with
state transitions in `application/`. There is no single source of truth for
conversation status.
**Known workaround:** Any ticket touching conversation status must be reviewed by
the platform team before merging.
**Plan:** Migrate fully to `service/` module — tracked in EPIC-89, target Q3 2026.

---

## Missing integration tests for ConversationRepository

Risk: medio
**What:** `ConversationJooqRepository` has no integration tests. Only unit tests
with mocked JOOQ DSL exist.
**Why it's a risk:** Schema changes may break queries silently — no test will catch it.
**Known workaround:** Manual testing on staging before merging schema changes.

---

## Kafka producer not idempotent

Risk: bajo
**What:** The Kafka producer for domain events does not use idempotent configuration.
Duplicate events are possible on retries.
**Why it's a risk:** Consumers must handle duplicate events defensively. Not all
consumers currently do.
**Known workaround:** Documented in consumer onboarding guide.
**Plan:** Accepted as-is — consumers are expected to be idempotent by design.
```
