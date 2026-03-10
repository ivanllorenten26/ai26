# Context Management

> How AI26 preserves state, coordinates agents, and recovers from interruptions.

---

## The core problem

A feature implementation involves multiple agents executing multiple tasks across
multiple sessions. Three things must always be true:

1. **Recoverability** — if anything fails or is interrupted, the system resumes
   from exactly the last completed step without repeating work
2. **Minimal context** — each agent receives only what it needs, nothing more
3. **Orchestrator coherence** — the orchestrator always knows what has been done,
   what is in progress, and what comes next

The solution is a **persistent plan** — a structured file that is the single source
of truth for the state of all work in progress.

---

## Two levels of plan

There are two persistent plan files, one per planning level:

### Epic plan — `ai26/epics/{EPIC}/plan.md`

Tracks progress across all stories in the epic.

```markdown
# Epic Plan — {EPIC-ID}

Epic: EPIC-42
Title: Unified Agent Inbox
Status: in_progress
Created: 2026-03-07
Last updated: 2026-03-07

## Stories

| ID | Title | Status | Branch |
|---|---|---|---|
| TICKET-123 | Close conversation | completed | TICKET-123-close-conversation |
| TICKET-124 | Escalate conversation | in_progress | TICKET-124-escalate-conversation |
| TICKET-125 | Supervisor inbox view | pending | — |

## Notes
[Any epic-level notes the orchestrator needs across stories]
```

### Story plan — `ai26/features/{TICKET}/plan.md`

Tracks progress across all subtasks within a single story.
This is the orchestrator's working document during implementation.

```markdown
# Story Plan — {TICKET-ID}

Ticket: TICKET-123
Title: Close Conversation
Status: in_progress
Created: 2026-03-07
Last updated: 2026-03-07

## Subtasks

| ID | Layer | Description | Status | Depends on | Agent |
|---|---|---|---|---|---|
| T1 | domain | Conversation aggregate — add CLOSED state and close() method | completed | — | — |
| T2 | application | CloseConversation use case | in_progress | T1 | agent-7f3a |
| T3 | infrastructure-out | ConversationRepository — persist close | pending | T1 | — |
| T4 | infrastructure-out | ConversationClosedEvent publisher | pending | T1 | — |
| T5 | infrastructure-in | CloseConversation controller | pending | T2 | — |
| T6 | test | Use case tests | pending | T2 | — |
| T7 | test | Controller tests | pending | T5 | — |
| T8 | test | Integration tests | pending | T3 | — |

## Execution notes
[What the orchestrator needs to know about in-progress or blocked subtasks]
```

---

## Subtask detail files

Each subtask in `plan.md` references a detail file. The plan contains the minimum
needed for the orchestrator to coordinate. The details contain everything the
executing agent needs.

```
ai26/features/{TICKET}/
  plan.md                    ← orchestrator state
  subtasks/
    T1-domain.md
    T2-application.md
    T3-infrastructure-out-repository.md
    T4-infrastructure-out-publisher.md
    T5-infrastructure-in-controller.md
    T6-test-use-case.md
    T7-test-controller.md
    T8-test-integration.md
```

### Subtask detail format

```markdown
# Subtask {ID} — {description}

Ticket: TICKET-123
Layer: application
Status: pending

## Context files to load

The agent executing this subtask must load these files and only these:

- `ai26/features/TICKET-123/domain-model.yaml`     ← aggregate contract
- `ai26/features/TICKET-123/use-case-flows.yaml`   ← use case input/output/errors
- `ai26/features/TICKET-123/error-catalog.yaml`    ← error types
- `ai26/config.yaml`                   ← stack configuration

Do NOT load: full conversation history, other subtask details, epic plan.

## What to implement

[Precise description of what this subtask produces. Derived from the artefacts above.
No ambiguity — the agent should not need to ask questions.]

## Output

Files to create or modify:
- `{path}` — [purpose]

## Acceptance

This subtask is complete when:
- [ ] The listed files exist
- [ ] The implementation compiles
- [ ] [Any specific check relevant to this subtask]

## Notes
[Anything the orchestrator captured during planning that is relevant to execution]
```

---

## Orchestrator behaviour

The orchestrator (`ai26-implement-user-story`) reads `plan.md` on every action.
It never holds state in memory — the plan is the state.

### On start

    1. Read plan.md
    2. Find subtasks with status: pending whose dependencies are all completed
    3. If one candidate: execute it
    4. If multiple candidates (parallelisable): execute them concurrently
    5. After each subtask completes: update plan.md, commit, push, find next

### On resume (after interruption)

    1. Read plan.md
    2. Find subtasks with status: in_progress — these were interrupted
       - Re-read the subtask detail file
       - Check if output files exist (was the subtask partially complete?)
       - If output exists and compiles: mark completed, continue
       - If output is incomplete: re-execute from the beginning of that subtask
    3. Continue from step 2 of normal start

The orchestrator never assumes an in_progress subtask completed — it always verifies
by checking the output files declared in the subtask detail.

### On failure

If a subtask fails (compilation error, test failure, unexpected state):

    1. Mark subtask as failed in plan.md with error summary
    2. Commit plan.md with message: {TICKET-ID} implement: {subtask} failed — see plan
    3. Push
    4. Surface the error to the engineer with a proposed fix
    5. Wait for engineer input before retrying

The orchestrator does not retry silently. Failures are visible in git history.

---

## Parallelism model

Subtasks are executed sequentially by default. Parallelism is declared explicitly
in the plan via the `depends_on` field — subtasks with no pending dependencies
can run concurrently.

Typical parallelism within a story:

```
T1 (domain)
  ↓
T2 (use case) ──────────────┐
T3 (repository)  ← parallel │
T4 (event publisher) ← parallel
  ↓                         ↓
T5 (controller) ← needs T2  │
  ↓                         │
T6 (use case tests) ← T2    │
T7 (controller tests) ← T5  │
T8 (integration tests) ← T3 ┘
```

T2, T3, and T4 can start as soon as T1 completes — they all depend only on the
domain contract, not on each other.

The orchestrator detects this from the dependency graph and launches them concurrently.

---

## Context passing to agents

Each executing agent receives exactly what its subtask detail file specifies — no more.

The orchestrator builds the agent context from:
1. The subtask detail file
2. The files listed in "Context files to load"

It does not pass:
- The full conversation history from the design phase
- Other subtask detail files
- The epic plan
- Any file not listed in the subtask detail

This is enforced by design — the subtask detail file is the contract between
orchestrator and agent. If an agent needs something not listed, the subtask detail
file must be updated first.

### Agent result format

When a subtask agent completes, it reports back to the orchestrator:

```yaml
subtask: T2
status: completed
files_created:
  - service/src/main/kotlin/.../CloseConversationUseCase.kt
files_modified: []
notes: >
  The use case required an additional validation not in the artefacts —
  checking that the agent performing the close is assigned to the conversation.
  This was derived from the domain model invariants. No artefact change needed.
```

The orchestrator reads this result, updates `plan.md`, commits, and proceeds.
Any `notes` from the agent are appended to the plan's execution notes section —
they may be relevant for subsequent subtasks.

---

## Plan generation

The plan is generated by `ai26-implement-user-story` before execution starts,
as a separate step that the engineer reviews and confirms.

    /ai26-implement-user-story TICKET-123

    LLM: I've read the design artefacts for TICKET-123.
         Here is the implementation plan:

         T1 — domain: Conversation aggregate (close() method + CLOSED state)
         T2 — application: CloseConversation use case
         T3 — infrastructure-out: ConversationRepository (persist close)
         T4 — infrastructure-out: ConversationClosedEvent publisher  [parallel with T2]
         T5 — infrastructure-in: CloseConversation controller
         T6 — test: use case tests
         T7 — test: controller tests
         T8 — test: integration tests

         T3 and T4 can run in parallel after T1.
         Everything else is sequential.

         Shall I proceed?

The engineer can reorder, add, or remove subtasks before confirming.
Once confirmed, the plan is written to `plan.md` and subtask detail files are generated.
From that point, the plan is the source of truth.

---

## Plan persistence and git

Plan files are committed at every state change:

| Event | Commit |
|---|---|
| Plan generated and confirmed | `{TICKET-ID} implement: plan ready — {N} subtasks` |
| Subtask started | `{TICKET-ID} implement: starting {subtask-description}` |
| Subtask completed | `{TICKET-ID} implement: {subtask-description}` |
| Subtask failed | `{TICKET-ID} implement: {subtask-description} failed — see plan` |
| All subtasks complete | `{TICKET-ID} implement: all subtasks complete` |

Because the plan is always committed before execution and after completion of each
subtask, the git history is a full audit trail of the implementation progress.
Recovery after any interruption is deterministic — read the last commit, read plan.md,
continue from there.
