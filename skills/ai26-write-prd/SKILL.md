---
name: ai26-write-prd
description: SDLC3 Phase 1a. Produces a structured PRD from a business initiative — either refining an existing document or building from scratch through conversation. Use when a PM needs to capture and structure an epic before architectural analysis.
argument-hint: [EPIC-ID] — Jira epic ID
---

# ai26-write-prd

Produces a complete, structured PRD from a business initiative.
Supports two entry points: refining an existing document, or building from scratch.

---

## Step 1 — Load context

Read in this order:
1. `ai26/config.yaml` — interaction style
2. `ai26/context/DOMAIN.md` — existing domain concepts
3. `ai26/context/DECISIONS.md` — global constraints (if exists)
4. `docs/architecture/modules/` — existing module documentation (summary only)

If `ai26/epics/{EPIC}/prd.md` already exists, read it and show:

    Existing PRD found for {EPIC-ID} (last modified {date}).
    Do you want to:
    A. Continue refining it
    B. Start fresh (existing PRD will be overwritten after confirmation)

---

## Step 2 — Entry point

Ask if not already known:

    Do you have an existing document (PRD, brief, spec, email) or do you want
    to start from a description?

    A. I have a document — provide file path or paste content
    B. Start from a description

### Entry A — Existing document

Read the provided document. Then open the conversation:

    I've read your document. Let me ask a few things to make sure we capture everything.

Do NOT present all gaps at once. Engage naturally — gaps emerge through conversation.

### Entry B — From scratch

Using the configured interaction style, open the conversation:

    Tell me about the initiative. What problem are you solving, and for whom?

---

## Step 3 — Conversation

Drive the conversation to produce a complete PRD. Monitor for these gap types and
surface them as the conversation develops — never as a checklist dump:

| Gap type | Trigger question |
|---|---|
| Missing error paths | "What happens if [X condition]?" |
| Ambiguous terms | "When you say '[term]', do you mean...?" |
| Conflict with existing domain | "We already have [concept] — is this the same thing?" |
| Unstated assumptions | "You mention [actor] — what if they are not available?" |
| Missing success criteria | "How will you know this is working correctly in production?" |
| Scope boundary unclear | "Does this include [edge case] or only [main case]?" |
| Missing actors | "Who triggers [action]? Which system sends [thing]?" |
| Non-functional requirements | "Any constraints on volume, latency, or availability?" |

For each use case identified, ensure the conversation covers:
- Happy path
- At least one error path
- Who initiates it
- What changes as a result

**Technical carry-over detection:**
During the conversation the user may reveal technical details that do not belong in a
PRD — for example: technology choices, database design hints, module boundaries,
integration patterns, or architectural constraints. Do NOT incorporate these into the
PRD sections. Instead, collect them silently and include them in the `Technical
carry-over` section when writing the artefact. Acceptable PRD content is:
- Observable behaviour (what the system does for users/actors)
- Non-functional requirements stated in business terms (e.g. "must handle 10k events/s")
- Constraints the business imposes (compliance, SLAs, budget)
Anything that describes *how* the system will be built belongs in carry-over.

---

## Step 4 — Propose closure

When all sections are covered and no open questions remain, propose closing:

    I think we have a complete PRD. Here is what we covered:
    - {N} actors: {list}
    - {N} use cases with error paths
    - Non-functional requirements: {list or "none identified"}
    - Success criteria: {defined / not defined — flag if missing}
    - Open questions: {N remaining}
    - Technical carry-over: {N items captured / none}

    Shall I write prd.md?

If there are open questions, do not close until they are resolved or explicitly deferred.

---

## Step 5 — Write artefact

Write `ai26/epics/{EPIC}/prd.md` with this structure:

```markdown
# PRD — {Epic title}

Epic: {EPIC-ID}
Date: {YYYY-MM-DD}
Status: draft
Author: {from conversation or "unknown"}

---

## Business context

{Why this epic exists. What problem it solves. What changes for users.}

---

## Actors

| Actor | Role |
|---|---|
| {actor} | {role} |

---

## Use cases

### UC-{N} — {Title}
**Actor:** {who initiates}
**Goal:** {what they want to achieve}
**Preconditions:** {what must be true}

**Happy path:**
1. {step}

**Error paths:**
- {condition} → {what happens}

---

## Out of scope

{What is explicitly NOT included.}

---

## Non-functional requirements

- {constraint}

---

## Success criteria

{How we know this works in production. Observable and measurable.}

---

## Open questions

| Question | Owner | Due |
|---|---|---|
| {question} | {owner} | {date or "TBD"} |

---

## Technical carry-over

> This section captures technical decisions and architectural hints mentioned during the
> PRD conversation. They are **not** PRD content. They are preserved here so that
> ai26-design-epic-architecture and ai26-design-user-story can use them as input.

### Architecture hints
{Technology choices, integration patterns, module boundaries, or preferred stack
decisions mentioned by the user. Delete section if empty.}

### Data / persistence hints
{Schema ideas, storage technology preferences, migration notes. Delete if empty.}

### Constraints from engineering
{Performance bounds, security requirements, or operational limits stated in technical
terms (e.g. "must use existing Kafka cluster", "no new databases"). Delete if empty.}
```

Notify the engineer after writing:

    ✓ ai26/epics/{EPIC}/prd.md written.
    You can review it now or continue. Say "show it" or "continue".

Wait for the engineer's response before proceeding.

---

## Step 6 — Commit

After the engineer confirms the PRD:

```
git add ai26/epics/{EPIC}/prd.md
git commit -m "{EPIC-ID} prd: structured PRD complete"
git push
```

Show: `✓ committed and pushed`

---

## Step 7 — Close

    PRD complete for {EPIC-ID}.

    Next step: /ai26-design-epic {EPIC-ID}
    (Architecture analysis, decomposition, and full ticket design in one flow.)
