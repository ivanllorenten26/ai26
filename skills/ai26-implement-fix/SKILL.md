---
name: ai26-implement-fix
description: SDLC3 Flow C. Direct implementation for typos, dependency bumps, config changes, and obvious bugs — no design phase. Researches codebase, implements, tests, commits. Automatically escalates to ai26-design-ticket if the fix turns out to require domain model changes, new aggregates, or touches DEBT.md RISK:alto areas.
argument-hint: "[TICKET-ID or description]"
---

# ai26-implement-fix

Direct implementation for Fidelity 0 tasks: no design artefacts, no ceremony.

Suitable for:
- Typos, renamed fields, copy changes
- Dependency version bumps
- Config file changes
- Single-file obvious bug fixes (null check, off-by-one, missing condition)
- Test flakiness fixes

**Not suitable for** (auto-escalates instead):
- Fixes that require new domain model elements
- Fixes that introduce new error cases requiring catalog entries
- Fixes in areas marked RISK: alto in DEBT.md
- Fixes that touch more than ~3 files in non-trivial ways

---

## Step 1 — Load context

Read in this order:
1. `ai26/config.yaml`
2. Ticket from Jira via MCP (if a Jira ID was provided) — description, ACs
3. `ai26/context/DEBT.md` — to detect risky areas
4. `ai26/context/DECISIONS.md` — to follow existing patterns

Show a brief summary:

    Fix: {TICKET-ID or description}
    Scope: {inferred from ticket description}

---

## Step 2 — Research codebase

Find the affected files. Use targeted searches — do not read the entire codebase.

Strategies:
- Search for the class, method, or field mentioned in the ticket description
- Search for the error message or log line if it is a runtime bug
- Check `git log --oneline --all -- {path}` for recently changed files if relevant

Show what was found:

    Found:
    - {file}: {reason this file is relevant}
    - {file}: {reason}

**Escalation check — evaluate before touching any code:**

If any of the following are true, escalate immediately (do not implement):

1. Fix requires adding a new method or field to an aggregate → escalate (domain change)
2. Fix introduces a new error case that needs catalog entry → escalate (design needed)
3. Affected file is in an area marked RISK: alto in DEBT.md → escalate (risky area)
4. Fix touches more than 3 files in non-trivial ways → escalate (too broad)
5. Fix requires a Flyway migration → escalate (schema change)
6. Fix requires changes to event payloads or Kafka topics → escalate (contract change)

When escalating:

    This fix requires {reason}.
    Escalating to ai26-design-ticket --fidelity 1.
    Continuing automatically — no action needed.

Then invoke `ai26-design-ticket {TICKET-ID} --fidelity 1` and, once design artefacts are written, invoke `ai26-implement-user-story {TICKET-ID}`.

---

## Step 3 — Implement

Apply the fix directly. Follow all coding rules from `ai26/config.yaml → coding_rules`.

Do not refactor surrounding code unless it is directly necessary for the fix. Do not add comments, docstrings, or error handling for scenarios outside the fix scope.

---

## Step 4 — Test

Run the test suite:
```
./gradlew service:test
```

If tests fail:
- Diagnose the failure — is it caused by the fix or pre-existing?
- If caused by the fix: correct the implementation and re-run
- If pre-existing: note it in the commit message but do not fix unrelated failures
- Do not retry the same failing command repeatedly — diagnose first

---

## Step 5 — Commit

```
git add {affected files}
git commit -m "{TICKET-ID} fix: {description}"
git push
```

Commit message format: `{TICKET-ID} fix: {one-line description of what was fixed}`

Show:

    ✓ Fix committed and pushed.

    {TICKET-ID}: {description}
    Files changed: {list}
    Tests: passed / {N} pre-existing failures noted
