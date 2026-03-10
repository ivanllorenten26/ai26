# Artefacts

> What the design phase produces, in what format, and why.

---

## What artefacts are

Artefacts are the contract between design and implementation. They capture what was decided
during the design conversation in a structured, reviewable form that implementation skills
can consume without ambiguity.

A human reviewer should be able to read the artefacts and understand the full intent of the
feature without reading a single line of code. An implementation skill should be able to
generate correct code from the artefacts without asking additional questions.

---

## Configurable artefact set

Which artefacts are produced is configured in `ai26/config.yaml`:

```yaml
artefacts:
  - domain_model
  - use_cases
  - api_contract       # remove if the feature has no HTTP API
  - events             # remove if the feature emits or consumes no events
  - error_catalog
  - glossary
  - scenarios          # Gherkin BDD
  - ops_checklist
```

Teams that do not have a REST API (e.g. pure event-driven services) remove `api_contract`.
Teams that do not use an event bus remove `events`. The rest are rarely optional.

---

## Artefacts reference

### `domain-model.yaml`

What the domain looks like: aggregates, entities, value objects, states, invariants.

```yaml
aggregates:
  - name: Conversation
    status: new                        # new | modified | existing | deprecated | removed
    id:
      type: ConversationId
      wraps: UUID
    properties:
      - name: customerId
        type: CustomerId
      - name: subject
        type: String
        invariants:
          - "must not be blank"
          - "max 200 characters"
      - name: status
        type: ConversationStatus
    states:
      - OPEN
      - CLOSED
      - ARCHIVED
    methods:
      - name: close
        transitions: OPEN -> CLOSED
        params:
          - name: closedAt
            type: Instant
      - name: archive
        transitions: CLOSED -> ARCHIVED
    domainEvents:
      - ConversationClosed
      - ConversationArchived

valueObjects:
  - name: ConversationId
    wraps: UUID
  - name: CustomerId
    wraps: UUID
```

The `status` field tracks whether this is a new concept or a modification to an existing one.
Implementation skills use it to decide whether to create or update files.

---

### `use-case-flows.yaml`

What operations the feature exposes, their inputs, outputs, and error paths.

```yaml
useCases:
  - name: CloseConversation
    actor: Agent
    input:
      - name: conversationId
        type: String        # primitives only — no domain types in the contract
      - name: closedAt
        type: String        # ISO-8601 instant
    output:
      type: ConversationDTO
    errorCases:
      - condition: "conversation does not exist"
        error: ConversationNotFound
      - condition: "conversation is already closed"
        error: ConversationAlreadyClosed
      - condition: "conversation is archived"
        error: ConversationArchived
    sideEffects:
      - type: event
        name: ConversationClosed
      - type: notification
        description: "notify assigned agent via notification service"
    dependsOn: []           # other use cases that must run first
```

One entry per use case. The error cases here are the source of truth for the error catalog
and for the Gherkin scenarios — both are derived from this file.

---

### `api-contracts.yaml`

The HTTP surface of the feature.

```yaml
endpoints:
  - method: POST
    path: /api/v1/conversations/{id}/close
    status: new                        # new | modified | deprecated | removed
    useCase: CloseConversation
    auth: required
    pathParams:
      - name: id
        type: String
        description: Conversation ID (UUID)
    requestBody:
      fields:
        - name: closedAt
          type: String
          required: true
          description: ISO-8601 instant
    responses:
      - status: 200
        description: Conversation closed
        body: ConversationDTO
      - status: 404
        error: ConversationNotFound
      - status: 409
        error: ConversationAlreadyClosed
      - status: 422
        error: ConversationArchived
```

Every endpoint references a `useCase` from `use-case-flows.yaml`. Implementation skills
validate this reference before generating controller code.

---

### `events.yaml`

Events the feature publishes or consumes.

```yaml
published:
  - name: ConversationClosed
    aggregate: Conversation
    topic: valium.chat.conversation.closed
    trigger: CloseConversation use case
    payload:
      - name: conversationId
        type: String
      - name: customerId
        type: String
      - name: closedAt
        type: String

consumed:
  - name: CustomerDeleted
    sourceService: customer-service
    topic: customer.deleted
    handler: CustomerDeletedEventHandler
    fieldsUsed:
      - customerId
```

---

### `error-catalog.yaml`

All error types the feature introduces, classified by kind.

```yaml
eitherErrors:
  - sealedClass: CloseConversationDomainError
    status: new
    variants:
      - name: ConversationNotFound
        httpStatus: 404
        message: "Conversation {id} not found"
      - name: ConversationAlreadyClosed
        httpStatus: 409
        message: "Conversation {id} is already closed"
      - name: ConversationArchived
        httpStatus: 422
        message: "Conversation {id} is archived and cannot be closed"

domainExceptions:
  - name: InvalidSubject
    thrownBy: Conversation.init
    condition: "subject is blank or exceeds 200 characters"
    httpStatus: 400

applicationExceptions:
  - name: CloseConversationApplicationException
    thrownBy: CloseConversationUseCase
    condition: "unexpected infrastructure failure"
    httpStatus: 500
```

The three kinds map to different error handling patterns:
- `eitherErrors` — business rule violations returned as `Either.Left`
- `domainExceptions` — invariant violations thrown in aggregate constructors or methods
- `applicationExceptions` — infrastructure or unexpected failures

Which patterns are available depends on the team's stack configuration.

---

### `glossary.yaml`

Domain terms introduced or used in this feature.

```yaml
terms:
  - term: Conversation
    definition: "A support thread between a customer and one or more agents"
    synonymsToAvoid:
      - ticket
      - case
  - term: Close
    definition: "Terminal state transition indicating the conversation is resolved"
    note: "Distinct from Archive — closed conversations can still be read"
```

New terms are merged into the module glossary at promotion time.
Terms already in the module glossary are not re-defined here — only new ones.

---

### `scenarios.feature` (Gherkin)

One `.feature` file per use case. These are the acceptance tests — derived from
`use-case-flows.yaml` error cases and the happy path.

```gherkin
Feature: Close a conversation
  As an agent
  I want to close a conversation
  So that it is marked as resolved and the customer is notified

  Background:
    Given a conversation exists with id "conv-123" and status OPEN

  Scenario: Successfully close an open conversation
    When I close conversation "conv-123"
    Then the conversation status is CLOSED
    And a ConversationClosed event is emitted

  Scenario: Cannot close a conversation that does not exist
    When I close conversation "unknown-id"
    Then the response is 404

  Scenario: Cannot close a conversation that is already closed
    Given conversation "conv-123" has status CLOSED
    When I close conversation "conv-123"
    Then the response is 409

  Scenario: Cannot close an archived conversation
    Given conversation "conv-123" has status ARCHIVED
    When I close conversation "conv-123"
    Then the response is 422
```

One scenario per error case in `use-case-flows.yaml`. One scenario for the happy path.
No technical jargon — business-readable language only.

---

### `ops-checklist.yaml`

Operational concerns that must be handled outside the skill system.

```yaml
ticket: TICKET-123
dbMigration:
  required: true
  notes: "Add closed_at column to conversations table"
featureFlag:
  required: false
observability:
  newAlert: false
  newRunbookEntry: true
  notes: "Add runbook entry for conversation close failures"
```

This file is not promoted to architecture documentation. It is a checklist for the engineer
to complete before or alongside the PR.

---

## Artefact dependencies

Artefacts are not independent — they reference each other. The LLM validates these
cross-references at the end of the design phase:

```
use-case-flows.yaml
  ↓ error cases → error-catalog.yaml (every error case must have an entry)
  ↓ use case names → api-contracts.yaml (every endpoint must reference an existing use case)
  ↓ error cases + happy path → scenarios.feature (every case must have a scenario)
  ↓ side effects of type event → events.yaml (every event side effect must be defined)

domain-model.yaml
  ↓ aggregate names → use-case-flows.yaml (actor and output types must exist)
  ↓ domain terms → glossary.yaml (every term used must be defined)
```

If a cross-reference is broken, the LLM reports it as a validation error before closing
the design phase. The engineer must resolve it — the plan phase does not start with
broken references.

---

## Format is configurable

The YAML schemas shown above are the defaults. Teams can configure:

- **Which artefacts are produced** — via `artefacts` in `ai26/config.yaml`
- **Schema overrides** — by placing a custom schema in `.claude/skills/ai26-design-user-story/schemas/`
- **Artefact location** — by default `ai26/features/{TICKET}/`, configurable via `workspace_path`

What is not configurable is the principle: design produces structured, reviewable contracts
before implementation starts. The format can change. The gate cannot be removed.
