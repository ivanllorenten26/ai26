---
name: ai26-backfill-user-story
description: SDLC3 utility. Retroactively generates ai26/features/{TICKET}/ design artefacts by reading existing Kotlin code. Use when a feature was implemented without running ai26-design-user-story first — to enable ai26-validate-user-story and ai26-promote-user-story on that feature.
argument-hint: [TICKET-ID] — Jira ticket ID
---

# ai26-backfill-user-story

Generates design artefacts from existing code. The direction is reversed from the
normal flow: code → artefacts instead of artefacts → code.

The output is a `ai26/features/{TICKET}/` workspace that is as complete and accurate as
the code allows. It will not contain decisions that were made verbally and not encoded
in the code. Those gaps are surfaced for the engineer to fill.

---

## Step 1 — Load context

Read:
1. `ai26/config.yaml` — base package, module structure, artefact config
2. `ai26/context/DOMAIN.md` — domain vocabulary
3. Jira ticket via MCP — title, description, acceptance criteria

If the Jira ticket cannot be read, ask the engineer to provide the ticket description.

---

## Step 2 — Resolve module and locate implementation files

From `ai26/config.yaml`, read the `modules` list. Identify which module(s) this
ticket belongs to:

1. If only one module is `active: true` — use it.
2. If multiple active modules — infer from ticket context and confirm with engineer.
3. If the ticket involves a legacy module (`active: false`) — warn before scanning it.

From the resolved module(s), use `path` and `base_package` to build the search paths.

Search for files related to this ticket. Use the ticket title and Jira description
as hints for class names. Look in each module's:

- `{path}/src/main/kotlin/{base_package}/domain/`
- `{path}/src/main/kotlin/{base_package}/application/`
- `{path}/src/main/kotlin/{base_package}/infrastructure/inbound/`
- `{path}/src/main/kotlin/{base_package}/infrastructure/outbound/`
- `{path}/src/test/`

List found files and ask for confirmation:

    Found files likely related to {TICKET-ID}:

    Domain:
      Conversation.kt
      ConversationId.kt
      ConversationStatus.kt

    Application:
      SendCustomerMessageUseCase.kt

    Infrastructure:
      SendCustomerMessageController.kt
      ConversationJooqRepository.kt
      CustomerMessageSentKafkaPublisher.kt

    Tests:
      SendCustomerMessageUseCaseTest.kt
      SendCustomerMessageControllerTest.kt
      SendCustomerMessageFeatureTest.kt

    Is this the full scope? Add or remove files before I proceed.

---

## Step 3 — Extract artefacts from code

Read each file and extract the information needed for each artefact.

### `domain-model.yaml`

From aggregate and entity classes:
- Class name → aggregate/entity name
- Constructor parameters and properties → aggregate properties
- Status enum values → states
- Domain event fields emitted → domainEvents list
- `init` block or factory method guards → invariants

From value object classes:
- Class name and wrapped type → valueObjects list
- Validation in `init` → constraints

Mark all entries as `status: existing`.

### `use-case-flows.yaml`

From use case classes:
- Class name → use case name
- Execute/invoke method parameter type → input fields
- Return type (Either right) → output type
- Either left variants returned → errorCases
- Domain events published or side effects triggered → sideEffects

### `error-catalog.yaml`

From the Either left sealed class or domain exception hierarchy:
- Sealed class variant names → errorVariant names
- HTTP status mapping (from controller advice or `@ResponseStatus`) → httpStatus
- Error message strings → description

### `api-contracts.yaml`

From controller classes:
- `@RequestMapping` / `@GetMapping` / `@PostMapping` etc. → method + path
- Request body DTO fields → request schema
- Response body DTO fields → response schema
- `@ResponseStatus` or `ResponseEntity` → success status code
- Controller advice mappings → error response codes

### `events.yaml`

From publisher classes and domain event classes:
- Topic/queue name from configuration → topic
- Event class name → name
- Event class fields → payload
- Publisher direction → `published`

From subscriber/listener classes:
- Topic/queue name → topic
- Event class consumed → name
- Direction → `consumed`

### `scenarios/`

From existing test files (BDD feature files if present, or use case tests):
- Extract scenario names and their Given/When/Then steps if feature files exist
- If only unit tests exist, generate Gherkin scenarios that describe the same behaviour

One `.feature` file per use case.

---

## Step 4 — Surface gaps

After extracting, identify what could not be determined from code alone:

    Gaps found — engineer input required:

    1. domain-model.yaml — Conversation.invariants:
       The code validates subject length in the constructor but the max length
       could not be determined (magic number not found).
       → What is the maximum subject length?

    2. error-catalog.yaml — ConversationNotFound.httpStatus:
       No HTTP mapping found for this error in the controller advice.
       → What HTTP status should ConversationNotFound return?

    3. use-case-flows.yaml — SendCustomerMessage.actor:
       Could not determine the actor from the code.
       → Who invokes this use case? (e.g. Customer, Agent, System)

    4. scenarios/ — No feature files found.
       Generated scenarios from unit tests — please review for accuracy.

Ask each gap. Do not proceed to write artefacts until all blocking gaps are answered.
Non-blocking gaps (e.g. glossary descriptions) can be marked as TODO.

---

## Step 5 — Write artefacts

Once gaps are resolved, write the artefact files to `ai26/features/{TICKET}/`:

For each artefact file:
1. Show a preview of what will be written
2. Write after confirmation (or proceed directly if engineer said "proceed with all")

Create `ai26/features/{TICKET}/` directory if it does not exist.

Do not create `ops-checklist.yaml` from backfill — it requires human knowledge of
operational requirements that cannot be inferred from code.

---

## Step 6 — Write plan.md

Write `ai26/features/{TICKET}/plan.md` with `status: completed` to mark the feature
as having a complete artefact set:

```markdown
# Story Plan — {TICKET-ID}

Ticket: {TICKET-ID}
Title: {title from Jira}
Status: completed
Created: {date}
Last updated: {date}
Note: artefacts generated via backfill from existing code

## Subtasks

| ID | Layer | Description | Status |
|---|---|---|---|
| T1 | backfill | Artefacts generated from existing code | completed |
```

---

## Step 7 — Commit

```
git add ai26/features/{TICKET}/
git commit -m "{TICKET-ID} backfill: design artefacts generated from existing code"
git push
```

---

## Step 8 — Report

    Backfill complete — {TICKET-ID}
    ──────────────────────────────────────────────────────

    Artefacts written:
      domain-model.yaml      — {N} aggregates, {N} value objects
      use-case-flows.yaml    — {N} use cases
      error-catalog.yaml     — {N} error variants
      api-contracts.yaml     — {N} endpoints
      events.yaml            — {N} events
      scenarios/             — {N} feature files, {N} scenarios

    Gaps resolved:           {N}
    TODOs remaining:         {N} (see artefacts for TODO markers)

    ops-checklist.yaml was not generated — create it manually if needed.

    Next steps:
      /ai26-validate-user-story {TICKET-ID}  — verify artefacts match code
      /ai26-promote-user-story {TICKET-ID}   — promote to architecture docs
