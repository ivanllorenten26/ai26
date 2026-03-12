# Compound Feedback

> Fix the context, not the output.

When an AI agent produces wrong output, the instinct is to manually rewrite the result.
That fixes this ticket. It does not fix the next one. Compound feedback is the mechanism
for capturing what went wrong, applying the actual correction (to a context file, a skill,
a coding rule), and archiving the lesson so future agents inherit the fix.

---

## Two files

| File | Location | Lifetime | Purpose |
|------|----------|----------|---------|
| `COMPOUND.md` | `ai26/features/{TICKET}/COMPOUND.md` | Per ticket — deleted after all observations resolved | Active inbox. Accumulates observations during the ticket lifecycle |
| `LEARNINGS.md` | `ai26/context/LEARNINGS.md` | Permanent — never deleted | Institutional memory. Graduated observations read by future agents |

**COMPOUND.md** = working inbox. Accumulates during review of any SDLC step. Cleared when observations are resolved.

**LEARNINGS.md** = permanent archive. Historical record of what went wrong, why, and what was done. Grows over time. Read by `ai26-design-ticket`, `ai26-implement-user-story`, and `ai26-review-user-story` to avoid repeating past mistakes.

---

## Workflow

```
Any SDLC step produces wrong output
          ↓
/ai26-compound {TICKET-ID}          ← capture the observation → COMPOUND.md
          ↓
Apply the correction
(edit context file / artefact / skill / coding rule as appropriate)
          ↓
Re-run the step that produced the issue
          ↓
/ai26-compound-resolve {TICKET-ID}  ← graduate resolved observations → LEARNINGS.md
          ↓
/ai26-promote-user-story {TICKET-ID}
(blocked if COMPOUND.md has pending observations)
```

You can invoke `/ai26-compound` multiple times before resolving — one observation per
invocation. Collect all issues for a step, then apply corrections and re-run once.

---

## Skills

### `/ai26-compound {TICKET-ID}`

Observe-only. Captures what went wrong at any checkpoint (design, implement, validate,
review, PR feedback, production incident) and appends it to `COMPOUND.md`.

Does **not** edit artefacts, code, or context files. Does **not** re-run any step.

**What it asks:**
1. What went wrong? (free text)
2. Which SDLC step produced this? (`design` / `implement` / `validate` / `review` / `pr` / `production` / `other`)
3. What type of correction is needed? (`context` / `artefact` / `skill` / `rule` / `pattern`)
4. What should have happened instead?

**Output — observation entry in `COMPOUND.md`:**

```markdown
## OBS-001 | 2026-03-12 | design | context | pending
**What:** domain-model.yaml had wrong field type for accountId — used String instead of UUID
**Expected:** accountId should be typed as UUID, consistent with the aggregate root's ID VO
```

---

### `/ai26-compound-resolve {TICKET-ID}`

Graduation skill. Processes each `| pending` observation, archives resolved ones to
`ai26/context/LEARNINGS.md`, and optionally proposes a CLAUDE.md rule.

Run after:
1. Collecting observations with `/ai26-compound`
2. Applying corrections (context files, artefacts, skills, coding rules)
3. Re-running the affected step successfully

**Graduated entry in `LEARNINGS.md`:**

```markdown
## OBS-001 | 2026-03-12 | design | context
**Ticket:** SXG-1234
**What:** domain-model.yaml had wrong field type for accountId — used String instead of UUID
**Why:** DOMAIN.md did not document the convention that aggregate IDs are always UUID value objects
**Fix:** Updated DOMAIN.md to document the ID value object convention under the Conversation aggregate
**Step re-run:** ai26-design-ticket
```

---

## COMPOUND.md format

```markdown
# Compound Observations — {TICKET}

## {OBS-ID} | {YYYY-MM-DD} | {step} | {category} | {pending|resolved}
**What:** {description of what went wrong}
**Expected:** {what should have happened instead}
```

- `OBS-ID` — sequential, zero-padded: `OBS-001`, `OBS-002`, ...
- `step` — one of: `design`, `implement`, `validate`, `review`, `pr`, `production`, `other`
- `category` — one of: `context`, `artefact`, `skill`, `rule`, `pattern`
- `status` — `pending` until resolved; changed to `resolved` by `ai26-compound-resolve`

---

## LEARNINGS.md format

```markdown
# Learnings

> Institutional memory from compound feedback. Each entry records what went wrong,
> why, and what was fixed. Read by agents to avoid repeating past mistakes.

---

## {OBS-ID} | {YYYY-MM-DD} | {step} | {category}
**Ticket:** {TICKET-ID}
**What:** {what went wrong}
**Why:** {root cause}
**Fix:** {what was changed — which file, what was added/removed}
**Step re-run:** {skill name}
```

---

## How LEARNINGS.md is consumed

| Skill | When | What it does |
|-------|------|--------------|
| `ai26-design-ticket` | Step 1 — context load | Scans for past `design` and `context` observations relevant to the ticket's domain. Surfaces them before starting the design conversation. |
| `ai26-implement-user-story` | Step 1 — context load | Scans for past `implement`, `rule`, and `pattern` observations. Surfaces relevant ones before generating the implementation plan. |
| `ai26-review-user-story` | Check 7 | Runs each relevant past observation as an additional check against the reviewed files. |
| `ai26-promote-user-story` | Step 1 gate | Reads `COMPOUND.md`. Blocks promotion if pending observations exist. |
| `ai26-onboard-team` | Step 12 | Creates an empty `ai26/context/LEARNINGS.md` so the file exists from day one. |

---

## CLAUDE.md rule proposals

When `ai26-compound-resolve` archives a `context` or `rule` category observation, it asks:

```
The fix involved updating {context file / coding rule}.
Should this also become a hard rule in CLAUDE.md to enforce it on every session?

Proposed rule (one line):
"..."

Add to CLAUDE.md? [yes / no]
```

If yes, the rule is appended to `CLAUDE.md` — shown as a diff first, written only after
explicit confirmation. This is how LEARNINGS.md observations escalate to session-level
enforcement.

---

## Promotion gate

`ai26-promote-user-story` checks for pending observations before allowing promotion:

```
⚠ COMPOUND.md has 2 pending observation(s) for SXG-1234.

Resolve these with /ai26-compound-resolve SXG-1234 before promoting.
```

Promotion is blocked until COMPOUND.md is empty or all observations are resolved.
This ensures lessons are captured before the ticket workspace is closed.

---

## Reference

- Skill: `ai26-compound` — `/Users/ivanllorente/code/ai26/skills/ai26-compound/SKILL.md`
- Skill: `ai26-compound-resolve` — `/Users/ivanllorente/code/ai26/skills/ai26-compound-resolve/SKILL.md`
- See also: [flows.md](flows.md) §7 — The Compound Step
- See also: [engineer-guide.md](../../guide/engineer-guide.md) — "When something goes wrong"
