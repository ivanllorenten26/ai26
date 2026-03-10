---
name: ai26-start-sdlc
description: SDLC3 single entry point. Detects context from a Jira ID or conversation, sets up the branch, and routes to the correct phase. Use this to start any SDLC3 flow — new epic, existing epic, new ticket, or existing ticket.
argument-hint: [JIRA-ID] — epic or ticket ID, or omit to be prompted
---

# ai26-start-sdlc

Single entry point for all SDLC3 flows. Detects where you are and routes to the right place.

---

## Step 1 — Load configuration

Read `ai26/config.yaml`. If it does not exist:

    ai26/config.yaml not found.
    Run /ai26-start-sdlc --check to verify your setup, or create the file following docs/ai26-sdlc/reference/onboarding.md.

Extract:
- `stack.build` — used to derive the test command
- `modules` — active modules and their conventions

Defaults (not in config — hardcoded):
- git remote: `origin`
- main branch: `master` (check `git symbolic-ref refs/remotes/origin/HEAD` to confirm)
- interaction style: `socratic`

---

## Step 2 — Detect Jira ID type

If a Jira ID was provided as argument, read the issue from Jira via MCP.

Determine whether it is an **epic** or a **ticket** from the Jira issue type field.

If no argument was provided, ask:

    What do you want to work on?

    A. New epic       — I have a business initiative to decompose into tickets
    B. Existing epic  — I have an epic in Jira already (provide ID)
    C. New ticket     — I have an epic and want to create a new ticket for it
    D. Existing ticket — I have a ticket to design and implement (provide ID)

Wait for the engineer's choice before continuing.

---

## Step 3 — Branch setup

Before doing anything else, check the current git branch.

Read the Jira issue title. Convert to kebab-case. Build the expected branch name:
```
{JIRA-ID}-{title-in-kebab-case}
```

**Case 1 — Already on the correct branch:**

    On branch TICKET-123-close-conversation. Continuing.

**Case 2 — On a branch with the correct JIRA-ID prefix:**

    You are on TICKET-123-old-title.
    The Jira title is "Close Conversation" → expected: TICKET-123-close-conversation.
    Do you want to:
    A. Continue on this branch
    B. Create TICKET-123-close-conversation from here
    C. Create TICKET-123-close-conversation from {main_branch}

**Case 3 — On an unrelated branch or {main_branch}:**

    You are on {current-branch}.
    I'll create branch {JIRA-ID}-{title} from {current-branch | main_branch}.

    From:
    A. Current branch ({current-branch})
    B. {main_branch}

Confirm branch name with the engineer before creating:

    I'll create branch: TICKET-123-close-conversation
    Based on Jira title: "Close Conversation"
    From: main

    Confirm, or provide a different title?

Create the branch and push to remote on confirmation:
```
git checkout -b {branch-name}
git push -u {remote} {branch-name}
```

---

## Step 4 — Route to correct phase

### Option A — New epic

    /ai26-write-prd

Pass: `mode: new`

### Option B — Existing epic

Read `ai26/epics/{EPIC}/` to detect what exists:

| What exists | Action |
|---|---|
| Neither prd.md nor architecture.md | Start from Phase 1a → `/ai26-write-prd` |
| prd.md exists, no architecture.md | Start from Phase 1b → `/ai26-design-epic-architecture` |
| Both exist, open tickets in Jira | Start from Phase 1c → `/ai26-decompose-epic` |
| All phases done | Show summary, ask what to do next |

Show the engineer what was found before routing:

    Found for EPIC-42:
    ✓ ai26/epics/EPIC-42/prd.md (2026-03-07)
    ✗ ai26/epics/EPIC-42/architecture.md — missing

    Continuing from Phase 1b (Epic Architecture).

### Option C — New ticket

Read the epic context (`ai26/epics/{EPIC}/prd.md` and `ai26/epics/{EPIC}/architecture.md` if they exist).
Create a new Jira ticket under the epic (via MCP) after defining scope with the engineer.
Then route to `ai26-design-user-story` with the new ticket ID.

### Option D — Existing ticket

**Bootstrap evaluation.** Read in this order:
1. Ticket from Jira (description, ACs, epic link, status)
2. Parent epic context (`ai26/epics/{EPIC}/` if exists)
3. `ai26/context/` — all files present
4. `docs/architecture/modules/` — existing module docs
5. `docs/adr/` — existing ADRs
6. `ai26/features/{TICKET}/` — existing artefacts if any

Evaluate what exists against the required artefact set from `ai26/config.yaml`:

```
Evaluating TICKET-123...

Jira ticket:          ✓ read (3 ACs, no error paths defined)
Epic context:         ✗ no epic architecture found
/context/DOMAIN.md:   ✓
Existing artefacts:   ✗ none

Ready to start design conversation.
Notes:
- Ticket has no error paths — we will work those out together
- No epic architecture — lightweight analysis will run during design
```

If `ai26/features/{TICKET}/` already has some artefacts:

    Found existing design workspace for TICKET-123:
    ✓ domain-model.yaml
    ✓ use-case-flows.yaml
    ✗ error-catalog.yaml — missing
    ✗ scenarios/ — missing

    Do you want to:
    A. Continue from where this left off
    B. Review existing artefacts first
    C. Start fresh (existing artefacts will be overwritten after confirmation)

Route to `ai26-design-user-story` after bootstrap.

---

## Step 5 — Setup check mode

If invoked as `/ai26-start-sdlc --check`:

Verify:
- `ai26/config.yaml` exists and has required fields (`stack`, `modules`)
- The following context files exist in `ai26/context/`: `DOMAIN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `DEBT.md`, `INTEGRATIONS.md`
- Jira MCP is reachable (read a test issue or project info)
- Git remote is configured

    SDLC3 setup check
    ─────────────────────────────────────────
    ✓ ai26/config.yaml — valid
    ✓ ai26/context/DOMAIN.md — found
    ✓ ai26/context/ARCHITECTURE.md — found
    ✓ ai26/context/DECISIONS.md — found
    ✓ ai26/context/DEBT.md — found
    ✓ ai26/context/INTEGRATIONS.md — found
    ✓ Jira MCP — connected
    ✓ Git remote — origin configured

    Setup complete.

Report any missing items with instructions to fix them.
