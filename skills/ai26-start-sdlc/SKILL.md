---
name: ai26-start-sdlc
description: SDLC3 single entry point. Detects context from a Jira ID or conversation, sets up the branch, and routes to the correct flow. Use this to start any SDLC3 flow — new epic, existing epic, standalone feature, bug fix, or quick fix.
argument-hint: "[JIRA-ID] — epic or ticket ID, or omit to be prompted"
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

## Step 2 — Detect entry point

If a Jira ID was provided as argument, read the issue from Jira via MCP.

Determine the issue type from Jira: **epic** or **ticket**.

### If a Jira ID was provided — auto-detect routing

**Epic ID provided:**
- Check `ai26/epics/{EPIC}/` for existing artefacts
- Route as Option A or B (see below)

**Ticket ID provided:**
- Read ticket: description, ACs, epic link, status, labels
- Read parent epic context if exists: `ai26/epics/{EPIC}/architecture.md`, `ai26/features/` dirs
- Auto-detect fidelity:

| Ticket signals | Route |
|---|---|
| Epic has `architecture.md` + ticket has `ai26/features/{TICKET}/` artefacts | Skip to `/ai26-implement-user-story` |
| Epic has `architecture.md`, ticket has no artefacts yet | Route to `/ai26-implement-user-story` (artefacts already in `ai26/features/{TICKET}/` from epic design) |
| No epic context, ticket type is Bug or labels include `fix` | Route to Option D (fidelity 1) |
| No epic context, ticket is a feature | Route to Option C (fidelity 2) |
| Ticket is trivial (title contains "typo", "bump", "config") | Route to Option E |

Show the auto-detected route and ask for confirmation before proceeding.

### If no Jira ID was provided — show routing menu

    What do you want to work on?

    A. New epic                    → ai26-write-prd → ai26-design-epic
    B. Continue existing epic      → ai26-design-epic (detects progress, resumes)
    C. Standalone feature ticket   → ai26-design-ticket --fidelity 2
    D. Bug fix / small change      → ai26-design-ticket --fidelity 1
    E. Quick fix (no design)       → ai26-implement-fix

    Choose A–E, or provide a Jira ID.

Wait for the engineer's choice before continuing.

---

## Step 3 — Branch setup

Before routing, check the current git branch.

Read the Jira issue title (or use provided description for Option E without a ticket). Convert to kebab-case. Build the expected branch name:
```
{JIRA-ID}-{title-in-kebab-case}
```

**Case 1 — Already on the correct branch:**

    On branch {branch-name}. Continuing.

**Case 2 — On a branch with the correct JIRA-ID prefix:**

    You are on {JIRA-ID}-old-title.
    The Jira title is "{title}" → expected: {JIRA-ID}-{kebab-title}.
    A. Continue on this branch
    B. Create {JIRA-ID}-{kebab-title} from here
    C. Create {JIRA-ID}-{kebab-title} from {main_branch}

**Case 3 — On an unrelated branch or main:**

    You are on {current-branch}.
    I'll create branch {JIRA-ID}-{title} from {current-branch | main_branch}.

    From:
    A. Current branch ({current-branch})
    B. {main_branch}

Confirm branch name before creating:

    I'll create branch: {JIRA-ID}-{kebab-title}
    From: {base}
    Confirm, or provide a different title?

Create the branch and push on confirmation:
```
git checkout -b {branch-name}
git push -u origin {branch-name}
```

---

## Step 4 — Route to correct skill

### Option A — New epic

Invoke `/ai26-write-prd` with `mode: new`.

### Option B — Continue existing epic

Read `ai26/epics/{EPIC}/` to detect what exists:

| What exists | Route |
|---|---|
| Neither prd.md nor architecture.md | `/ai26-write-prd` |
| prd.md exists, no architecture.md | `/ai26-design-epic` (Phase 2 — architecture) |
| prd.md + architecture.md, no design/ | `/ai26-design-epic` (Phase 3 — monolithic design) |
| design/ exists, no features/ | `/ai26-design-epic` (Phase 4 — slice into tickets) |
| features/ exist, no Jira IDs | `/ai26-design-epic` (Phase 5 — materialise Jira) |
| All phases done | Show summary, ask what to do next |

Show what was found before routing:

    Found for {EPIC-ID}:
    ✓ ai26/epics/{EPIC}/prd.md (2026-03-07)
    ✗ ai26/epics/{EPIC}/architecture.md — missing

    Routing to ai26-design-epic (will start from Phase 2).

### Option C — Standalone feature ticket (fidelity 2)

Invoke `/ai26-design-ticket {TICKET-ID} --fidelity 2`.

### Option D — Bug fix / small change (fidelity 1)

Invoke `/ai26-design-ticket {TICKET-ID} --fidelity 1`.

### Option E — Quick fix (no design)

Invoke `/ai26-implement-fix {TICKET-ID}`.

---

## Step 5 — Setup check mode

If invoked as `/ai26-start-sdlc --check`:

Verify:
- `ai26/config.yaml` exists and has required fields (`stack`, `modules`)
- Context files exist: `ai26/context/DOMAIN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `DEBT.md`, `INTEGRATIONS.md`
- Jira MCP is reachable
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
