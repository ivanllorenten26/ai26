---
name: ai26-start-sdlc
description: SDLC3 single entry point. Detects context from a Jira ID or conversation, sets up the branch, and routes to the correct flow. Use this to start any SDLC3 flow — new epic, existing epic, standalone feature, bug fix, or quick fix.
argument-hint: "[JIRA-ID] or [--prd | --epic ID | --ticket ID | --fix ID | --quickfix | --migrate MODULE | --backfill ID | --check]"
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

## Flags — expert shortcuts

If any flag was provided, skip Step 2 (guided dialogue) entirely and go straight to Step 3 (branch setup) → Step 4 (route).

| Flag | Routes to | Notes |
|---|---|---|
| `--prd` | `ai26-write-prd` | Start a new epic from scratch or an existing document |
| `--epic {EPIC-ID}` | `ai26-design-epic` (resume) | Resume or start an epic design |
| `--ticket {TICKET-ID}` | `ai26-design-ticket` (auto-fidelity) | Fidelity inferred from ticket type (see Step 2 heuristic) |
| `--fix {TICKET-ID}` | `ai26-design-ticket --fidelity 1` | Bug fix / small change, minimal artefact set |
| `--quickfix [TICKET-ID\|desc]` | `ai26-implement-fix` | No design, direct implementation |
| `--migrate {MODULE}` | `ai26-assess-module` | Start or resume a legacy module migration |
| `--backfill {TICKET-ID}` | `ai26-backfill-user-story` | Retroactively generate artefacts for existing code |
| `--check` | Setup verification (Step 5) | Verify config, context files, Jira MCP, git remote |

`--ticket` uses the same fidelity inference as the Jira ID auto-detect path (Bug/fix → fidelity 1, feature → fidelity 2). Pass `--fidelity 1` or `--fidelity 2` to override.

---

## Step 2 — Detect entry point

If a Jira ID was provided as argument, read the issue from Jira via MCP.

Determine the issue type from Jira: **epic** or **ticket**.

### If a Jira ID was provided — auto-detect routing

**Epic ID provided:**
- Check `ai26/epics/{EPIC}/` for existing artefacts
- Route as Option 2 or 1 (see below)

**Ticket ID provided:**
- Read ticket: description, ACs, epic link, status, labels
- Read parent epic context if exists: `ai26/epics/{EPIC}/architecture.md`, `ai26/features/` dirs
- Auto-detect fidelity:

| Ticket signals | Route |
|---|---|
| Epic has `architecture.md` + ticket has `ai26/features/{TICKET}/` artefacts | Skip to `/ai26-implement-user-story` |
| Epic has `architecture.md`, ticket has no artefacts yet | Route to `/ai26-implement-user-story` (artefacts already in `ai26/features/{TICKET}/` from epic design) |
| No epic context, ticket type is Bug or labels include `fix` | Route to Option 4 (fidelity 1) |
| No epic context, ticket is a feature | Route to Option 3 (fidelity 2) |
| Ticket is trivial (title contains "typo", "bump", "config") | Route to Option 5 |

Show the auto-detected route and ask for confirmation before proceeding.

### If no Jira ID and no flag — guided dialogue

    What are you working on?

    1. A new business initiative (PRD, epic, ticket breakdown)
    2. An existing epic (continue design or decompose into tickets)
    3. A ticket to design and build
    4. A bug fix or small change
    5. A quick fix — no design needed, just implement
    6. Migrating a legacy module to AI26 standard

    Choose 1–6, or paste a Jira ID.

Wait for the engineer's choice before continuing. Then ask the appropriate follow-up:

| Choice | Follow-up | Routes to |
|---|---|---|
| **1** | "Do you already have a document (PRD, brief, email) or starting from scratch?" | `ai26-write-prd` |
| **2** | "What's the epic ID?" → read Jira, detect phase | `ai26-design-epic` (resumes from correct phase) |
| **3** | "What's the ticket ID?" → read Jira, auto-detect fidelity | `ai26-design-ticket` |
| **4** | "What's the ticket ID?" | `ai26-design-ticket --fidelity 1` |
| **5** | "What's the ticket ID or describe what to fix?" | `ai26-implement-fix` |
| **6** | "Which module? (list from `modules` in config)" | `ai26-assess-module {MODULE}` |

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

### Option 1 — New business initiative (PRD)

Invoke `/ai26-write-prd` with `mode: new`.

### Option 2 — Continue existing epic

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

### Option 3 — Ticket to design and build (fidelity 2)

Invoke `/ai26-design-ticket {TICKET-ID} --fidelity 2`.

### Option 4 — Bug fix / small change (fidelity 1)

Invoke `/ai26-design-ticket {TICKET-ID} --fidelity 1`.

### Option 5 — Quick fix (no design)

Invoke `/ai26-implement-fix {TICKET-ID}`.

### Option 6 — Migrate legacy module

Invoke `/ai26-assess-module {MODULE}`.

If a migration plan already exists in `ai26/migrations/{MODULE}/plan.md`, check for
the next `pending` ticket and offer to resume:

    Found migration plan for {MODULE}. Progress: {N}/{M} tickets complete.
    Next ticket: {title} ({JIRA-ID or "not yet created"})

    A. Continue from next migration ticket ({JIRA-ID})
    B. Start from the beginning (/ai26-assess-module {MODULE})

Also check: if any module in `ai26/config.yaml` has `migration_status: in_progress`,
surface it proactively before the guided dialogue even if the engineer did not choose 6:

    ⚠ Module {MODULE} has a migration in progress ({N}/{M} tickets complete).
    Run /ai26-start-sdlc --migrate {MODULE} to continue, or choose a different flow.

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
