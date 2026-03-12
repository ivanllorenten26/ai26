---
name: ai26-promote-user-story
description: SDLC3 Phase 2e. Promotes design artefacts, ADRs, and context updates from a completed ticket to permanent architecture documentation. Runs after ai26-validate-user-story passes. Single operation covering artefacts, context updates, and epic plan tracking.
argument-hint: [TICKET-ID] — Jira ticket ID
---

# ai26-promote-user-story

Promotes everything produced during a feature's lifecycle to permanent documentation.
Single operation. Covers artefacts, context updates, and epic progress tracking.

---

## Step 1 — Pre-flight check

Read `ai26/features/{TICKET}/plan.md`. Verify `status: completed`.

If not completed:

    Promotion blocked — implementation is not complete for {TICKET-ID}.
    Run /ai26-implement-user-story {TICKET-ID} first.

Check validation status. If last validation did not pass:

    Promotion blocked — {TICKET-ID} has unresolved blocking violations.
    Run /ai26-validate-user-story {TICKET-ID} to see current state.

Check for pending compound observations. Read `ai26/features/{TICKET}/COMPOUND.md` if it exists.
If the file exists and contains any `| pending` observations, block promotion:

    Promotion blocked — {TICKET-ID} has {N} unresolved compound observation(s):

    OBS-001 | design | context | pending — {what}
    OBS-003 | implement | skill | pending — {what}

    Resolve these with /ai26-compound-resolve {TICKET-ID} before promoting.
    (Observations capture known problems found during review — promoting with open observations
    means the system does not learn from this ticket.)

---

## Step 2 — Load artefacts

Read all files in `ai26/features/{TICKET}/`:
- `domain-model.yaml`
- `use-case-flows.yaml`
- `error-catalog.yaml`
- `api-contracts.yaml` (if exists)
- `events.yaml` (if exists)
- `glossary.yaml` (if exists)
- `ops-checklist.yaml` (if exists)

Read existing module documentation at:
`docs/architecture/modules/{module}/`

Determine module from `ai26/config.yaml` or infer from artefacts.

---

## Step 3 — Merge artefacts into module documentation

For each artefact file, merge into the corresponding module documentation file.
Merging is accumulative — existing entries are preserved.

Apply the `status` field on each entry:

| Status | Action |
|---|---|
| `new` | Add entry to module documentation |
| `modified` | Update existing entry with new content |
| `existing` | No change |
| `deprecated` | Keep entry, add `deprecated: true`, `deprecatedReason`, `deprecatedInTicket` |
| `removed` | Delete entry from module documentation |

### Conflict detection

If an entry was modified both in the feature artefact AND in the module documentation
since the feature branch started, surface the conflict:

    Conflict detected in domain-model.yaml:

    Conversation.status in this feature adds: ARCHIVED
    Module documentation was updated by another ticket adding: ESCALATED

    Current module states: OPEN, CLOSED, ESCALATED
    Merged result:         OPEN, CLOSED, ESCALATED, ARCHIVED

    Is this correct?

Do not proceed until the engineer confirms or corrects the merge.

---

## Step 4 — Verify ADRs

ADRs written during design are already in `docs/adr/`. Verify they are present:

For each ADR referenced in the feature artefacts, check it exists in `docs/adr/`.
If any is missing, warn — do not block promotion, but flag it.

---

## Step 5 — Apply context updates

During the design phase, the LLM may have proposed updates to `ai26/context/`.
These are stored as pending proposals in `ai26/features/{TICKET}/context-updates.md` (if exists).

If the file exists, present each proposed update for confirmation:

    Proposed context update:

    ai26/context/DECISIONS.md — add entry:
    "Conversation notifications are delivered asynchronously via domain events."

    Confirm?

Apply each confirmed update. Never update `/context/` without explicit confirmation.

---

## Step 6 — Sync context files

Run `ai26-sync-context --report` to detect any drift between the context files
and the codebase introduced by this ticket.

If drift is detected, surface the report and ask:

    Context drift detected. Fix now before promotion, or continue and fix later?
    A. Fix now  — run /ai26-sync-context interactively, then return to promotion
    B. Continue — promotion will proceed with current context files

If the engineer chooses A, pause promotion. Resume after `ai26-sync-context` completes.
If no drift is detected, continue silently.

---

## Step 7 — Regenerate C1/C4 diagrams

Check whether `ai26/context/INTEGRATIONS.md` or `ai26/context/DOMAIN.md` changed
(either via Step 5 context updates or Step 6 sync fixes).

**If neither changed**, skip diagram regeneration:

    No integration changes detected for {TICKET-ID}. Diagrams are up to date.

**If either changed**, regenerate:

    Integration changes detected — regenerating C1/C4 diagrams.

    Reading ai26/context/INTEGRATIONS.md and ai26/context/DOMAIN.md...

Regenerate `docs/architecture/diagrams/c1-system-context.md` and
`docs/architecture/diagrams/c4-components.md` following the format in
`docs/ai26-sdlc/reference/context-mapping.md`.

Show the diff for each diagram — only what changed, not the full content.
Wait for confirmation before writing:

    Updated C1 diagram — diff:

    + System_Ext(bedrock, "Amazon Bedrock", "AI summarisation")
    + Rel(service, bedrock, "Summarises conversations", "AWS SDK")

    Confirm?

Apply confirmed updates. Never overwrite diagrams without confirmation.

---

## Step 7 — Epic plan update

Read `ai26/epics/{EPIC}/plan.md` (if exists). Mark this ticket as `completed`:

```markdown
| {TICKET-ID} | {title} | completed | {branch} |
```

Check Jira via MCP for remaining open tickets in the epic.

If this is the last ticket:

    All tickets in {EPIC-ID} are now complete.
    Promoting epic architecture to permanent documentation...

Promote `ai26/epics/{EPIC}/architecture.md` to `docs/architecture/epics/{EPIC}.md`.

---

## Step 7c — Label Jira ticket

Add the label `ai26-promoted` to the Jira ticket via MCP.

This label makes AI26-completed tickets filterable in Jira dashboards and JQL queries:

    labels = "ai26-promoted"

The label is additive — it does not replace any existing labels on the ticket.

If the MCP call fails, log a warning and continue — do not block the promotion commit:

    ⚠ Could not add label ai26-promoted to {TICKET-ID}. Add manually in Jira if needed.

---

## Step 8 — Commit promotion

```
git add docs/architecture/modules/{module}/
git add docs/architecture/epics/       (if epic promotion happened)
git add docs/architecture/diagrams/    (if diagrams were regenerated)
git add ai26/context/                  (if context updates were applied)
git add ai26/epics/{EPIC}/plan.md
git commit -m "{TICKET-ID} promote: artefacts merged to architecture docs"
git push
```

---

## Step 9 — Feature workspace cleanup

    Promotion complete. The design workspace ai26/features/{TICKET-ID}/ is no longer needed.
    Delete it? [yes / no]

Default: yes — all knowledge is now in permanent documentation.
If the engineer keeps it, it stays as-is.

---

## Step 10 — Promotion report

    Promotion complete — {TICKET-ID}
    ──────────────────────────────────────────────────────

    Module documentation updated:
      docs/architecture/modules/{module}/domain-model.yaml
        + {new entries}
        ~ {modified entries}

      docs/architecture/modules/{module}/use-case-flows.yaml
        + {new entries}

      [etc.]

    ADRs — already in place:
      {list or "none"}

    Context updates applied:
      {list or "none"}

    Diagrams:
      {regenerated: c1-system-context.md, c4-components.md / "no changes"}

    Epic progress:
      {N}/{M} tickets complete in {EPIC-ID}
      {or: "All tickets complete — epic promoted to docs/architecture/epics/{EPIC}.md"}

    Feature workspace:
      {deleted / kept}

    Your branch {branch-name} is up to date on origin.
    Open the PR when ready for human review.
