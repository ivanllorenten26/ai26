---
name: ai26-compound
description: Compound feedback observer. Captures what went wrong at any SDLC checkpoint — after design review, code review, validation, PR feedback, or a production incident — and appends it to the ticket's COMPOUND.md inbox. Does NOT edit artefacts, code, or context files; does NOT re-run any step. Use immediately whenever the engineer spots something wrong with AI26 output so the observation is not lost. Invoke as /ai26-compound {TICKET-ID}.
argument-hint: "[TICKET-ID]"
---

# ai26-compound

Captures negative feedback at any SDLC checkpoint into `ai26/features/{TICKET}/COMPOUND.md`.
Observe-only — never corrects, never re-runs. The engineer collects all observations for a
step, applies corrections manually, re-runs the step, then graduates resolved observations
with `/ai26-compound-resolve`.

---

## Step 1 — Identify ticket

If `{TICKET-ID}` was not provided as an argument, ask:

    Which ticket does this observation belong to? (e.g. TBD-42)

---

## Step 2 — Collect the observation

Ask three questions in sequence:

**What went wrong?**

    What went wrong? Describe the problem — free text, as much or as little detail as you have.

**Which SDLC step produced this?**

    Which step produced this issue?
      design      — ai26-design-ticket / ai26-design-user-story
      implement   — ai26-implement-user-story
      validate    — ai26-validate-user-story
      review      — ai26-review-user-story
      pr          — human PR review
      production  — post-release incident or monitoring
      other       — anything else

**What type of correction is needed?**

    What needs to change to prevent this recurring?
      context   — a context file (DECISIONS.md, ARCHITECTURE.md, DEBT.md, DOMAIN.md)
      artefact  — a design artefact (domain-model.yaml, api-contracts.yaml, etc.)
      skill     — a skill produced wrong output (the skill's SKILL.md needs updating)
      rule      — a coding rule is missing or wrong (ai26/config.yaml coding_rules)
      pattern   — a coding pattern or recipe needs to be added or corrected

Also ask for the expected behaviour:

    What should have happened instead? (one sentence is fine)

---

## Step 3 — Assign observation ID

Read `ai26/features/{TICKET}/COMPOUND.md` if it exists.

Count existing `## OBS-` headers to determine the next sequential ID.
If the file does not exist, start at `OBS-001`.

Format: `OBS-NNN` zero-padded to three digits.

---

## Step 4 — Append to COMPOUND.md

If `ai26/features/{TICKET}/COMPOUND.md` does not exist, create it with this header:

```markdown
# Compound Observations — {TICKET}
```

Append the new observation:

```markdown
## {OBS-ID} | {YYYY-MM-DD} | {step} | {category} | pending
**What:** {description}
**Expected:** {expected behavior}
```

Do not modify any other file.

---

## Step 5 — Commit

```
git add ai26/features/{TICKET}/COMPOUND.md
git commit -m "{TICKET} compound: add {OBS-ID} ({step}/{category})"
git push
```

---

## Step 6 — Confirm and prompt next action

    Observation {OBS-ID} recorded for {TICKET}.

    COMPOUND.md now has {N} pending observation(s).

    When you have finished collecting observations for this step:
    1. Apply your corrections (edit artefacts / context / skills as needed)
    2. Re-run the step that produced the issue
    3. Run /ai26-compound-resolve {TICKET} to graduate resolved observations to LEARNINGS.md

---

## What this skill does NOT do

- Does not edit artefacts, code, or any context file
- Does not re-run any SDLC step
- Does not fix the issue — it records it so the engineer can fix it deliberately
