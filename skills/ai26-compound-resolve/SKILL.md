---
name: ai26-compound-resolve
description: Compound feedback graduation skill. Processes resolved observations from a ticket's COMPOUND.md, archives each to the permanent ai26/context/LEARNINGS.md record, and optionally proposes a CLAUDE.md rule for systemic fixes. Run after applying corrections and re-running the affected SDLC step — before ai26-promote-user-story. Invoke as /ai26-compound-resolve {TICKET-ID}.
argument-hint: "[TICKET-ID]"
---

# ai26-compound-resolve

Graduates resolved observations from `ai26/features/{TICKET}/COMPOUND.md` to the
permanent institutional memory in `ai26/context/LEARNINGS.md`.

Run this after:
1. Collecting observations with `/ai26-compound`
2. Applying corrections (artefacts, context, skills, rules)
3. Re-running the step that produced the issue successfully

---

## Step 1 — Read COMPOUND.md

Read `ai26/features/{TICKET}/COMPOUND.md`.

If the file does not exist:

    No COMPOUND.md found for {TICKET}. Nothing to resolve.

If the file exists but contains no `| pending` observations:

    All observations for {TICKET} are already resolved. Nothing to do.

List all pending observations:

    Pending observations for {TICKET}:

    OBS-001 | design | context | What: domain-model.yaml had wrong field type for accountId
    OBS-002 | implement | skill | What: dev-create-aggregate generated public constructor

    I'll walk through each one. For each, tell me if it's resolved.

---

## Step 2 — Process each pending observation

For each `| pending` observation, in order:

**Is it resolved?**

    OBS-{N} — {what}
    Resolved? [yes / no / skip]

If **no** or **skip**: leave status as `pending`, move to next observation.

If **yes**: ask for the root cause and fix:

    What was the root cause?
    (Why did the skill / context / rule produce this outcome?)

    What was the fix?
    (What did you change — which file, what was added/removed?)

    Which step did you re-run after the fix? (skill name, e.g. ai26-design-ticket)

Then:
1. Update the observation status in COMPOUND.md from `| pending` to `| resolved`
2. Append a graduated entry to `ai26/context/LEARNINGS.md` (see format below)
3. Check whether a CLAUDE.md rule is warranted (see Step 3)

---

## LEARNINGS.md entry format

```markdown
## {OBS-ID} | {YYYY-MM-DD} | {step} | {category}
**Ticket:** {TICKET}
**What:** {what went wrong}
**Why:** {root cause}
**Fix:** {what was changed}
**Step re-run:** {skill name}
```

If `ai26/context/LEARNINGS.md` does not exist, create it with this header first:

```markdown
# Learnings

> Institutional memory from compound feedback. Each entry records what went wrong,
> why, and what was fixed. Read by agents to avoid repeating past mistakes.

---
```

---

## Step 3 — CLAUDE.md rule proposal

After archiving each resolved `context` or `rule` category observation, ask:

    The fix involved updating {context file / coding rule}.
    Should this also become a hard rule in CLAUDE.md to enforce it on every session?

    Proposed rule (one line):
    "..."

    Add to CLAUDE.md? [yes / no]

If yes, append the rule to the relevant section of `CLAUDE.md`. Show the exact diff
before writing — never modify `CLAUDE.md` without explicit confirmation.

---

## Step 4 — Clean up COMPOUND.md

After processing all observations:

**If all observations are now resolved:**

    All {N} observations for {TICKET} are resolved.
    Deleting COMPOUND.md from the feature workspace...

Delete `ai26/features/{TICKET}/COMPOUND.md`.

**If some observations remain pending:**

    {N} observations resolved, {M} still pending.
    COMPOUND.md kept — {M} pending observation(s) remain for {TICKET}.

    When the remaining observations are fixed, run /ai26-compound-resolve {TICKET} again.

---

## Step 5 — Commit

```
git add ai26/context/LEARNINGS.md
git add ai26/features/{TICKET}/COMPOUND.md   # updated or deleted
git add CLAUDE.md                             # only if a rule was added
git commit -m "{TICKET} compound: graduate {N} observation(s) to LEARNINGS.md"
git push
```

---

## Step 6 — Summary

    Compound resolve complete — {TICKET}
    ──────────────────────────────────────────────────
    Resolved:  {N} observation(s) graduated to LEARNINGS.md
    Pending:   {M} observation(s) still open
    CLAUDE.md: {N rules added / no changes}

    LEARNINGS.md now has {total} entries.
    Future agents will read these to avoid repeating past mistakes.
