# Version Control

> How AI26 integrates with git throughout the feature lifecycle.

---

## The principle

Every completed phase or sub-phase produces a commit. Every commit is pushed immediately.
By the time a feature is done, there is already a branch with a full history of the work
and a PR ready for human review.

This gives:
- Full traceability from business intent (Jira) to code (git)
- No lost work — every step is persisted as it completes
- A PR that accumulates naturally, not created in a rush at the end

---

## Branch convention

```
{JIRA-ID}-{ticket-title-in-kebab-case}

Examples:
  TICKET-123-close-conversation
  EPIC-42-unified-agent-inbox
```

The title comes from Jira. The LLM reads it, converts it to kebab-case, and confirms
with the engineer before creating the branch:

    LLM: I'll create branch: TICKET-123-close-conversation
         Based on: "Close Conversation" from Jira
         From: main

         Confirm, or provide a different title?

---

## Commit message convention

```
{JIRA-ID} {message}

Examples:
  TICKET-123 design: domain model and use case flows
  TICKET-123 design: error catalog and API contracts
  TICKET-123 design: Gherkin scenarios and ops checklist
  TICKET-123 implement: CloseConversation use case
  TICKET-123 implement: CloseConversation controller
  TICKET-123 validate: all checks passing
  TICKET-123 promote: artefacts merged to architecture docs
```

---

## Branch setup at session start

When `/ai26-start-sdlc` is invoked, the LLM checks the current branch before doing anything else:

**Case 1 — Already on the correct branch:**

    LLM: You are on branch TICKET-123-close-conversation. Continuing from here.

**Case 2 — On a branch with the correct JIRA-ID prefix but different title:**

    LLM: You are on branch TICKET-123-old-title.
         The Jira ticket is now titled "Close Conversation".
         Do you want to:
         A. Continue on this branch (keep the old name)
         B. Create a new branch TICKET-123-close-conversation from here
         C. Create a new branch TICKET-123-close-conversation from main

**Case 3 — On an unrelated branch:**

    LLM: You are on branch feature/something-else.
         This does not match TICKET-123.
         I'll create branch TICKET-123-close-conversation.
         From:
         A. Current branch (feature/something-else)
         B. main

         Which one?

**Case 4 — On main or develop:**

    LLM: You are on main.
         I'll create branch TICKET-123-close-conversation from main.
         Confirm?

The LLM never creates a branch or switches branches without confirmation.

---

## Commit points

A commit is made after each completed phase or sub-phase. The LLM commits and pushes
automatically — the engineer does not need to remember to do it.

### Level 1 — Product planning

| Event | Commit message |
|---|---|
| PRD written | `{EPIC-ID} prd: structured PRD complete` |
| Epic architecture written | `{EPIC-ID} architecture: epic technical context complete` |
| Tickets created in Jira | `{EPIC-ID} decompose: {N} tickets created in Jira` |

### Level 2 — Feature implementation

| Event | Commit message |
|---|---|
| Domain model artefact written | `{TICKET-ID} design: domain model` |
| Use case flows artefact written | `{TICKET-ID} design: use case flows` |
| Error catalog artefact written | `{TICKET-ID} design: error catalog` |
| API contracts artefact written | `{TICKET-ID} design: API contracts` |
| Events artefact written | `{TICKET-ID} design: events` |
| Scenarios written | `{TICKET-ID} design: Gherkin scenarios` |
| Ops checklist written | `{TICKET-ID} design: ops checklist` |
| ADR written | `{TICKET-ID} adr: {adr-title}` |
| Each implementation unit complete | `{TICKET-ID} implement: {what was implemented}` |
| Validation passing | `{TICKET-ID} validate: all checks passing` |
| Promotion complete | `{TICKET-ID} promote: artefacts merged to architecture docs` |

### ADRs

ADRs are committed immediately when written — not held until the end of the design phase.
A decision that is documented is committed. This ensures the decision is persisted even
if the session is interrupted before the design phase completes.

---

## Push

Every commit is pushed to `origin` immediately after being created. There is no
"push at the end" — each commit is pushed as it happens.

This ensures:
- Work is never lost if the session is interrupted
- The remote branch is always up to date
- Other engineers can see progress in real time

The push target is `origin` by default. Configurable in `ai26/config.yaml`:

```yaml
version_control:
  remote: origin
  main_branch: main
```

---

## Pull Request

AI26 does not open the PR automatically. The branch exists and is pushed — opening
the PR is the engineer's explicit action.

The promotion step reminds the engineer:

    Promotion complete. Your branch TICKET-123-close-conversation is up to date on origin.
    Open the PR when ready for human review.

The PR covers the full history of the feature — design artefacts, ADRs, implementation,
and promotion — all as separate commits with traceable messages.

---

## Interrupted sessions

If a session is interrupted mid-phase, the work committed so far is safe on the remote.
When the engineer resumes with `/ai26-start-sdlc TICKET-123`, the LLM:

1. Detects the existing branch
2. Reads `ai26/features/{TICKET}/` to see what artefacts exist
3. Reads the last commit message to understand where the work stopped
4. Resumes from that point

The LLM does not restart from the beginning. It picks up exactly where the last
commit left off.
