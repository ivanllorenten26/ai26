# Promotion

> How completed feature work becomes permanent knowledge.

---

## What promotion does

Promotion takes everything produced during the feature lifecycle and integrates it
into the permanent knowledge base of the repository. After promotion, the feature
workspace is no longer needed — the knowledge lives in the right places.

Promotion is a single operation that covers:

```
ai26/features/{TICKET}/          → docs/architecture/modules/{module}/
docs/adr/ (new ADRs)         → already in place, indexed
ai26/context/ updates            → applied if new global decisions emerged
ai26/epics/{EPIC}/ (if present)  → docs/architecture/epics/{EPIC}/
```

---

## When promotion runs

Promotion runs after validation passes. It is the last step before opening a PR.

    /ai26-promote-user-story TICKET-123

The LLM reads the validation report first. If there are unresolved blocking violations,
promotion does not proceed:

    Promotion blocked — TICKET-123 has unresolved blocking violations.
    Run /ai26-validate-user-story TICKET-123 to see the current state.

---

## What gets promoted, and where

### Feature artefacts → module documentation

The artefacts in `ai26/features/{TICKET}/` are merged into the permanent module documentation
at `docs/architecture/modules/{module}/`.

Merging is accumulative — existing entries are preserved and new entries are added.
Nothing is silently overwritten.

The merge follows the `status` field on each artefact entry:

| Status | What happens at promotion |
|---|---|
| `new` | Entry added to the module documentation |
| `modified` | Existing entry updated with the new content |
| `existing` | No change — entry already correct |
| `deprecated` | Entry kept, marked as deprecated with reason and ticket |
| `removed` | Entry deleted from module documentation (git history is the audit trail) |

If a conflict is detected — an entry that was modified both in the feature artefact
and in the module documentation since the feature started — the LLM surfaces it:

    Promotion conflict detected:

    Conversation.status in domain-model.yaml was modified in this feature (added ARCHIVED)
    but the module documentation was also updated by TICKET-118 (added ESCALATED).

    Current module states: OPEN, CLOSED, ESCALATED
    This feature adds:     ARCHIVED

    Merged result would be: OPEN, CLOSED, ESCALATED, ARCHIVED

    Is this correct?

The engineer confirms or corrects before the merge is applied.

### ADRs → permanent

ADRs written during the design phase are already in `docs/adr/` — they were written
there at decision time, not held in the feature workspace. Promotion does not move them.

What promotion does do is update the ADR index if one exists, and verify that every
ADR referenced in the feature artefacts is present in `docs/adr/`.

### Context updates → `ai26/context/`

During the design conversation, the LLM may have identified decisions that belong
in `ai26/context/DECISIONS.md` rather than as ADRs — global constraints that emerged
from this feature but apply beyond it.

These are held as proposed context updates during the feature lifecycle. At promotion
time, the LLM presents them for confirmation:

    Proposed context updates:

    ai26/context/DECISIONS.md — add entry:
    "Conversation notifications are delivered asynchronously via domain events.
     Direct synchronous calls to the notification service are not permitted."

    This was agreed during the design conversation for TICKET-123.
    Confirm to apply?

The engineer confirms each update individually. The LLM never updates `ai26/context/`
without explicit confirmation.

### Epic architecture → permanent (if present)

If `ai26/epics/{EPIC}/architecture.md` exists and this is the last ticket in the epic,
the epic architecture document is promoted to `docs/architecture/epics/{EPIC}.md`.

The LLM checks whether there are other open tickets in the epic (via Jira MCP).
If there are, it notes that epic promotion will happen when the last ticket is promoted:

    Note: EPIC-42 has 2 tickets still open (TICKET-124, TICKET-125).
    Epic architecture will be promoted when the last ticket in the epic is completed.

---

## Promotion report

After promotion completes, the LLM produces a summary:

    Promotion complete — TICKET-123
    ──────────────────────────────────────────────────────

    Module documentation updated:
      docs/architecture/modules/chat/domain-model.yaml
        + Conversation.status: added ARCHIVED state
        ~ Conversation.methods: updated close() signature

      docs/architecture/modules/chat/use-case-flows.yaml
        + CloseConversation (new)

      docs/architecture/modules/chat/error-catalog.yaml
        + CloseConversationDomainError (new)
        + CloseConversationDomainError.ConversationArchived (new)

      docs/architecture/modules/chat/api-contracts.yaml
        + POST /api/v1/conversations/{id}/close (new)

      docs/architecture/modules/chat/glossary.yaml
        + Archive: terminal state for resolved conversations (new term)

    ADRs — already in place:
      docs/adr/2026-03-07-notification-delivery-model.md

    Context updates applied:
      ai26/context/DECISIONS.md: notification delivery policy added

    Epic promotion:
      EPIC-42 has 2 tickets still open — epic promotion deferred.

    Feature workspace:
      ai26/features/TICKET-123/ can be deleted. Keep it? [yes/no]

---

## Feature workspace cleanup

After promotion, the feature workspace in `ai26/features/{TICKET}/` is no longer needed.
The LLM asks whether to delete it.

The default is to delete — the knowledge is now in the permanent documentation and
keeping the workspace adds noise. The engineer can keep it if they have a reason
(e.g. the PR review is still in progress and they want easy reference).

If deleted, git history retains the artefacts if they were ever committed.
If the workspace was gitignored (the default), it is gone — which is fine, because
everything worth keeping has been promoted.

---

## What promotion does not do

- Does not push to remote or open a PR — that is the engineer's action
- Does not modify code — promotion is documentation only
- Does not resolve conflicts automatically — always asks the engineer
- Does not delete ADRs or supersede them — ADR lifecycle is managed separately
