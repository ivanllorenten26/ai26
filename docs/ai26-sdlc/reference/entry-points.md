# Entry Points

> How to start any AI26 SDLC flow, regardless of where you are in the process.

---

## The single entry point

All flows start with one skill:

    /ai26-start-sdlc [JIRA-ID | flag]

You never need to know which underlying skill to invoke — `ai26-start-sdlc` figures that out.

---

## Three ways to invoke

### 1. Paste a Jira ID (auto-detect)

```
/ai26-start-sdlc SXG-42      ← epic ID  → detects phase, routes to ai26-design-epic
/ai26-start-sdlc SXG-1234    ← ticket ID → auto-detects fidelity, routes accordingly
```

The skill reads the issue from Jira and picks the correct flow automatically. It shows
the detected route and asks for confirmation before proceeding.

**Auto-detect heuristic for tickets:**

| Ticket signals | Route |
|---|---|
| Epic has `architecture.md` + ticket has artefacts in `ai26/features/{TICKET}/` | Skip design → `/ai26-implement-user-story` |
| Epic has `architecture.md`, ticket has no artefacts yet | `/ai26-implement-user-story` (artefacts from epic design) |
| No epic context, ticket type is Bug or label includes `fix` | `/ai26-design-ticket --fidelity 1` |
| No epic context, feature ticket | `/ai26-design-ticket --fidelity 2` |
| Ticket title contains "typo", "bump", or "config" | `/ai26-implement-fix` |

---

### 2. Use a flag (expert shortcut)

Flags bypass the interactive dialogue entirely and go straight to branch setup → route.

| Flag | Routes to | Notes |
|---|---|---|
| `--prd` | `ai26-write-prd` | New epic from scratch or an existing document |
| `--epic {EPIC-ID}` | `ai26-design-epic` | Resume or start an epic design |
| `--ticket {TICKET-ID}` | `ai26-design-ticket` (auto-fidelity) | Fidelity inferred from ticket type |
| `--fix {TICKET-ID}` | `ai26-design-ticket --fidelity 1` | Bug fix / small change |
| `--quickfix [TICKET-ID\|desc]` | `ai26-implement-fix` | Direct implementation, no design |
| `--migrate {MODULE}` | `ai26-assess-module` | Start or resume a legacy module migration |
| `--backfill {TICKET-ID}` | `ai26-backfill-user-story` | Retroactively generate artefacts for existing code |
| `--check` | Setup verification | Verify config, context files, Jira MCP, git remote |

**Examples:**

```
/ai26-start-sdlc --prd
/ai26-start-sdlc --epic SXG-42
/ai26-start-sdlc --ticket SXG-1234
/ai26-start-sdlc --ticket SXG-1234 --fidelity 1   ← override auto-detect
/ai26-start-sdlc --fix SXG-999
/ai26-start-sdlc --quickfix SXG-888
/ai26-start-sdlc --quickfix "bump Spring Boot to 3.4.1"
/ai26-start-sdlc --migrate chat-module
/ai26-start-sdlc --backfill SXG-777
/ai26-start-sdlc --check
```

---

### 3. No argument — guided dialogue (newcomers)

With no Jira ID and no flag, the skill opens a plain-language dialogue:

```
What are you working on?

1. A new business initiative (PRD, epic, ticket breakdown)
2. An existing epic (continue design or decompose into tickets)
3. A ticket to design and build
4. A bug fix or small change
5. A quick fix — no design needed, just implement
6. Migrating a legacy module to AI26 standard

Choose 1–6, or paste a Jira ID.
```

Each option leads to a follow-up question before routing:

| Choice | Follow-up | Routes to |
|---|---|---|
| **1** | "Do you have a document (PRD, brief, email) or starting from scratch?" | `ai26-write-prd` |
| **2** | "What's the epic ID?" | `ai26-design-epic` (resumes from correct phase) |
| **3** | "What's the ticket ID?" | `ai26-design-ticket` (fidelity auto-detected) |
| **4** | "What's the ticket ID?" | `ai26-design-ticket --fidelity 1` |
| **5** | "What's the ticket ID or describe what to fix?" | `ai26-implement-fix` |
| **6** | "Which module?" (lists modules from config) | `ai26-assess-module {MODULE}` |

---

## The 6 flows

### Flow 1 — New epic (PRD → design → decompose)

You have a business initiative. No epic in Jira yet.

```
/ai26-start-sdlc --prd
```

Produces `ai26/epics/{EPIC}/prd.md`, then flows into `/ai26-design-epic`.

See `flows.md` — Flow A for the full phase breakdown.

---

### Flow 2 — Continue existing epic

You have an epic in Jira. Work may have already started.

```
/ai26-start-sdlc --epic SXG-42
# or
/ai26-start-sdlc SXG-42
```

The skill reads `ai26/epics/SXG-42/` and detects where to resume:

```
Found for SXG-42:
✓ ai26/epics/SXG-42/prd.md (2026-03-07)
✗ ai26/epics/SXG-42/architecture.md — missing

Routing to ai26-design-epic (will start from Phase 2).
```

See `flows.md` — Flow A for the phase table.

---

### Flow 3 — Ticket to design and build (fidelity 2)

Full design conversation producing the complete artefact set, followed by implementation.

```
/ai26-start-sdlc --ticket SXG-1234
# or
/ai26-start-sdlc SXG-1234      ← if auto-detect picks fidelity 2
```

Produces `ai26/features/SXG-1234/` with all artefacts (domain model, use case flows,
error catalog, API contracts, events, scenarios, ops checklist).

See `flows.md` — Flow B (fidelity 2).

---

### Flow 4 — Bug fix / small change (fidelity 1)

Minimal design artefacts: `scenarios/` + `error-catalog.yaml` + `domain-model.yaml`
(only if domain changes). Lighter design conversation, same implementation flow.

```
/ai26-start-sdlc --fix SXG-999
# or
/ai26-start-sdlc SXG-999       ← if auto-detect picks fidelity 1
```

**Auto-escalation:** if the fix turns out to need new aggregates, events, API endpoints,
or migrations, the agent escalates to fidelity 2 automatically.

See `flows.md` — Flow B (fidelity 1).

---

### Flow 5 — Quick fix (no design)

For typos, dependency bumps, config changes, and obvious single-file bugs.

```
/ai26-start-sdlc --quickfix SXG-888
# or
/ai26-start-sdlc --quickfix "bump Spring Boot to 3.4.1"
```

The agent implements directly, runs tests, and commits. If it discovers the fix is
more complex than expected, it escalates to fidelity 1 automatically.

See `flows.md` — Flow C.

---

### Flow 6 — Migrate legacy module

Six-phase migration flow from assessment through per-ticket implementation.

```
/ai26-start-sdlc --migrate chat-module
```

If a migration plan already exists in `ai26/migrations/{MODULE}/plan.md`, the skill
detects progress and offers to resume:

```
Found migration plan for chat-module. Progress: 3/8 tickets complete.
Next ticket: SXG-1102 — migrate ConversationRepository

A. Continue from next migration ticket (SXG-1102)
B. Start from the beginning (/ai26-assess-module chat-module)
```

See `flows.md` — Flow D for the full 6-phase breakdown.

---

## Fidelity

Fidelity controls how much design work is done before implementation:

| Fidelity | When | Artefacts |
|---|---|---|
| **2** (full) | New features, domain changes | Complete set: domain model, use case flows, error catalog, API contracts, events, scenarios, ops checklist |
| **1** (minimal) | Bug fixes, small changes | Minimal set: scenarios + error catalog + domain model (only if domain changes) |

`ai26-start-sdlc` infers fidelity from the Jira ticket type. You can override with
`--fidelity 1` or `--fidelity 2` when using `--ticket`.

---

## Branch setup

Before routing to a skill, `ai26-start-sdlc` always sets up the correct branch:

1. Reads the Jira issue title and converts it to kebab-case
2. Checks current branch against expected `{JIRA-ID}-{kebab-title}`
3. Creates the branch (from current or main) if not already on it
4. Pushes with `-u origin`

You confirm the branch name before it is created.

---

## Setup verification

```
/ai26-start-sdlc --check
```

Verifies: `ai26/config.yaml`, all `ai26/context/` files, Jira MCP connectivity, and
git remote configuration. Run this once after onboarding or when something seems off.
