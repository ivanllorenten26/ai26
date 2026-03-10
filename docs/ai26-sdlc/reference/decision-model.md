# Decision Model

> How architectural decisions are captured and classified in AI26.

---

## The problem this solves

In most teams, architectural decisions live in engineers' heads, in Slack threads, or in PRs
that are hard to search. When a new engineer joins, or when a similar problem resurfaces six
months later, nobody knows why a particular approach was chosen.

AI26 treats decision documentation as a first-class activity — not something done after the
fact, but something that happens in the moment the decision is made, as part of the design
conversation.

---

## Two levels of decision

Not every decision has the same scope or weight. Treating them all the same creates noise —
either everything becomes an ADR (overwhelming) or nothing gets documented (useless).

AI26 uses two levels:

### Level 1 — Architectural context

Global decisions already taken by the company or team. These are constraints, not debates.

Examples:
- "We use Kafka for all domain events"
- "We use Either for error handling, not exceptions"
- "All services expose a REST API following our internal API standard"
- "We do not use H2 in tests — TestContainers only"

These live in `ai26/context/DECISIONS.md` and are loaded by the LLM at the start of every
design session. When a topic is already covered here, the LLM does not open debate — it
applies the constraint and moves on.

When a new global decision is made during a design session (something that should apply
to all future features, not just this one), it goes here — not to an ADR.

### Level 2 — ADR (Architecture Decision Record)

Decisions specific to this feature that involve genuine trade-offs: things that could
reasonably have gone a different way, and where the reasoning matters for future engineers.

Categories that produce ADRs (configurable via `adr_triggers` in `ai26/config.yaml`):

| Category | Examples |
|---|---|
| `domain_modelling` | Aggregate boundaries, whether X belongs inside Y or is its own root, lifecycle states |
| `data_design` | Schema strategy, indexing approach, migration approach, soft delete vs hard delete |
| `inter_component` | Sync vs async communication, protocol choice (REST/gRPC/events), contract design |
| `infrastructure` | (optional) Technology choices, deployment strategy |
| `security` | (optional) Auth approach, data access model |

---

## When a decision gets documented

The LLM monitors the conversation for decision moments — points where the human is weighing
options, asking for trade-offs, or expressing uncertainty.

A decision moment is closed when the human commits to a direction. At that point the LLM
proposes to document it:

    LLM: That decision is worth capturing. Should I document it as an ADR?

The human controls what happens next:

    "Yes"
    → LLM drafts the ADR inline, shows it, waits for confirmation, then writes it.

    "No, it's a global policy"
    → LLM proposes adding it to ai26/context/DECISIONS.md instead.

    "No, skip it"
    → Decision is not documented. The LLM notes it was explicitly deferred.
      It will surface it again at the end of the design phase in the completeness check.

    "It's already documented"
    → LLM asks for the reference (file + section) and links to it in the artefact.

The LLM never documents a decision without the human's explicit confirmation.

---

## ADR format

    # ADR-YYYY-MM-DD: [title — one sentence]

    ## Status
    Accepted

    ## Context
    [The situation that required a decision. What was the problem or question.
    Written in past tense — what we knew at the time.]

    ## Decision
    [What we decided. One or two sentences, direct and unambiguous.]

    ## Options considered

    ### Option A — [name]
    [Description]
    Pros: ...
    Cons: ...

    ### Option B — [name]
    [Description]
    Pros: ...
    Cons: ...

    ## Reasons for this decision
    [Why Option X over the others. References to constraints from ai26/context/ if applicable.]

    ## Consequences
    [What changes as a result. What becomes easier. What becomes harder or constrained.]

    ## Ticket
    [TICKET]

ADRs are immutable once written. If a decision is reversed later, a new ADR is written
that supersedes the original — the original is never modified.

    ## Status
    Superseded by ADR-2026-09-12

---

## `ai26/context/DECISIONS.md` format

Simpler than an ADR — no options considered, no trade-off analysis. Just the decision
and why it is a constraint.

    # Architectural Decisions

    ## Event delivery — Kafka, at-least-once
    All domain events are published to Kafka. Consumers must be idempotent.
    Direct synchronous calls between services for event notification are not permitted.
    Rationale: decoupling, replay capability, audit trail.

    ## Error handling — Either
    Use cases return Either<DomainError, DTO>. Domain invariant violations throw exceptions.
    See ADR-2026-01-27 for the full reasoning.

    ## Test infrastructure — TestContainers only
    No H2 or in-memory databases in tests. All infrastructure tests use TestContainers.

Each entry has a short title, the decision in one sentence, and a rationale in one sentence.
If the decision has a full ADR, it links to it.

---

## How the LLM classifies a decision

When a decision moment is resolved, the LLM checks:

1. **Is it already in `ai26/context/DECISIONS.md`?**
   → Apply as constraint. Do not open debate. Do not document again.

2. **Is it already in `docs/adr/`?**
   → Surface the existing ADR. Ask if the current situation deviates from it.

3. **Is it a global policy (applies beyond this feature)?**
   → Propose adding to `ai26/context/DECISIONS.md`.

4. **Does it involve trade-offs specific to this feature?**
   → Propose an ADR.

5. **Is it too minor to document?**
   → The LLM uses the `adr_triggers` list as the threshold.
     If the decision category is not in `adr_triggers`, it does not propose an ADR.

---

## Deferred decisions

If the human defers a decision ("let's come back to this"), the LLM:
- Marks it as open in its working state
- Flags it in the completeness check at the end of the design phase:

      Open decisions not yet documented:
      - Notification delivery model (deferred during use case flows)
      These must be resolved before moving to the plan phase.

The design phase does not close with open decisions unless the engineer explicitly
accepts the risk and says so.

---

## Decision lifecycle

    Proposed (during conversation)
      ↓
    Confirmed (human approves the draft)
      ↓
    Written (to docs/adr/ or ai26/context/DECISIONS.md)
      ↓
    Promoted (included in docs/architecture/ via sdlc-promote)
      ↓
    Superseded (if a later ADR reverses it — original kept, status updated)
