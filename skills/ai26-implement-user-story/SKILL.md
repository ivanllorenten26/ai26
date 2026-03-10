---
name: ai26-implement-user-story
description: SDLC3 Phase 2b. Reads design artefacts for a ticket, generates an implementation plan with subtasks, and orchestrates agents to implement each subtask. Recovers from interruptions by reading the persisted plan. Use after ai26-design-user-story.
argument-hint: [TICKET-ID] — Jira ticket ID
---

# ai26-implement-user-story

Reads the design artefacts, produces a confirmed implementation plan, and orchestrates
agents to execute it subtask by subtask. The plan is persisted to git at every state
change — the system recovers from any interruption deterministically.

---

## Step 1 — Load context

Read:
1. `ai26/config.yaml` — stack, modules (with conventions per module)
2. `ai26/features/{TICKET}/plan.md` — if it exists, this is a resume scenario
3. `ai26/features/{TICKET}/domain-model.yaml`
4. `ai26/features/{TICKET}/use-case-flows.yaml`
5. `ai26/features/{TICKET}/error-catalog.yaml`
6. `ai26/features/{TICKET}/api-contracts.yaml` (if exists)
7. `ai26/features/{TICKET}/events.yaml` (if exists)
8. `ai26/features/{TICKET}/scenarios/` — list of feature files

### Resume scenario

If `plan.md` exists and has `status: in_progress`:

    Found an in-progress implementation plan for {TICKET-ID}.

    Progress:
    ✓ T1 — domain: {description}
    ⚡ T2 — application: {description} (was in progress — verifying...)
    ○ T3 — infrastructure-out: {description}
    ...

For any subtask marked `in_progress`, check whether its declared output files exist
and compile. If they do, mark as `completed`. If not, re-execute from the start of
that subtask.

Continue from the first non-completed subtask. Do not repeat completed work.

---

## Step 1b — Resolve target module(s)

From `ai26/config.yaml`, determine which module(s) this ticket targets:

1. If only one module has `active: true` — use it without asking.
2. If multiple active modules exist — infer from artefacts and confirm:

       Target module inferred: {name} ({path})
       Is this correct, or does this ticket also touch another module?

3. If a non-active module is involved — warn before proceeding.

The resolved module determines `base_package`, `conventions` (repository_type,
error_handling, test_containers, event_bus), and `flyway` settings used when
building subtask detail files. If the ticket spans two modules, each subtask
declares its own target module explicitly.

---

## Step 2 — Generate implementation plan

Analyse the artefacts and produce the subtask list. Apply these rules:

- One subtask per technical concern (one aggregate method, one use case, one adapter, one test suite)
- Layer order: domain → application → infrastructure-out → infrastructure-in → tests
- Identify parallelism: subtasks with no dependency on each other can run concurrently
- Flag subtasks that touch DEBT.md RISK: alto areas

Show the plan to the engineer before executing:

    Implementation plan for {TICKET-ID}:

    T1  [domain]            {description}               depends on: —
    T2  [application]       {description}               depends on: T1
    T3  [infra-out]         {description}               depends on: T1  ⟵ parallel with T2
    T4  [infra-out]         {description}               depends on: T1  ⟵ parallel with T2
    T5  [infra-in]          {description}               depends on: T2
    T6  [test]              {description}               depends on: T2
    T7  [test]              {description}               depends on: T5
    T8  [test]              {description}               depends on: T3

    T3 and T4 can run in parallel after T1.
    Estimated: {N} sequential steps, {M} parallelisable.

    Shall I proceed?

The engineer can reorder, add, or remove subtasks before confirming.

---

## Step 3 — Write plan and subtask detail files

On confirmation, write `ai26/features/{TICKET}/plan.md`:

```markdown
# Story Plan — {TICKET-ID}

Ticket: {TICKET-ID}
Title: {title from Jira}
Status: in_progress
Created: {date}
Last updated: {date}

## Subtasks

| ID | Layer | Description | Status | Depends on | Agent |
|---|---|---|---|---|---|
| T1 | domain | {desc} | pending | — | — |
| T2 | application | {desc} | pending | T1 | — |
...
```

Write one detail file per subtask to `ai26/features/{TICKET}/subtasks/T{N}-{layer}.md`:

```markdown
# Subtask T{N} — {description}

Ticket: {TICKET-ID}
Layer: {layer}
Module: {module-name}           ← from modules list in ai26/config.yaml
Status: pending

## Context files to load

- `ai26/features/{TICKET}/domain-model.yaml`
- `ai26/features/{TICKET}/use-case-flows.yaml`
- `ai26/features/{TICKET}/error-catalog.yaml`
- `ai26/config.yaml`    ← read conventions for the module declared above
[only the files this subtask actually needs]

## What to implement

{precise description derived from the artefacts — no ambiguity}

## Output files

- `{path}` — {purpose}

## Acceptance

This subtask is complete when:
- [ ] Output files exist
- [ ] Code compiles
- [ ] {any specific check}
```

Commit:
```
git add ai26/features/{TICKET}/plan.md ai26/features/{TICKET}/subtasks/
git commit -m "{TICKET-ID} implement: plan ready — {N} subtasks"
git push
```

---

## Step 4 — Execute subtasks

Execute subtasks in dependency order. For subtasks that can run in parallel (no
dependency on each other and both unblocked), launch as concurrent agents.

### For each subtask:

**4a. Mark in_progress and commit:**
```
git add ai26/features/{TICKET}/plan.md
git commit -m "{TICKET-ID} implement: starting {subtask description}"
git push
```

**4b. Build agent context:**
Read only the files listed in the subtask detail file. Do not pass the full
conversation history or other subtask details.

**4c. Execute:**
Invoke the appropriate `dev-*` or `test-*` skill for this layer, passing the
subtask context as input.

**4d. Receive result:**
The agent reports:
- `status`: completed / failed
- `files_created`: list of created files
- `files_modified`: list of modified files
- `notes`: any decisions or unexpected findings

**4e. On success:**
Update `plan.md` — mark subtask `completed`. Append any notes to plan execution notes.

Commit:
```
git add {files_created} {files_modified} ai26/features/{TICKET}/plan.md
git commit -m "{TICKET-ID} implement: {subtask description}"
git push
```

**4f. On failure:**
Mark subtask `failed` in plan.md with error summary. Commit:
```
git commit -m "{TICKET-ID} implement: {subtask description} failed — see plan"
git push
```

Surface the error to the engineer with a proposed fix. Do not retry automatically.
Wait for engineer input before continuing.

---

## Step 5 — All subtasks complete

When all subtasks are completed:

Update `plan.md` — set `status: completed`.

Commit:
```
git add ai26/features/{TICKET}/plan.md
git commit -m "{TICKET-ID} implement: all subtasks complete"
git push
```

---

## Step 6 — Trigger validation

Automatically invoke `ai26-validate-user-story {TICKET-ID}`.

Do not announce this — validation is a gate, not an optional step.
If validation passes, report success. If it fails, surface violations with proposed fixes.
