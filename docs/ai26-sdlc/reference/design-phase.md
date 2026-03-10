# Design Phase

> How the collaborative design conversation works in AI26.

---

## What this phase produces

The same artefacts as today: domain model, use case flows, API contracts, error catalog,
Gherkin scenarios, ops checklist. The format is configurable per team (see `artefacts.md`).

What is different is **how** the conversation gets there.

---

## The conversation model

The design phase is not a structured interview. The LLM does not walk through a fixed list
of questions phase by phase. Instead, it loads the available context and enters a conversation
with the human architect.

The human describes what they want to build. The LLM engages — asking questions, proposing
models, surfacing implications — until the artefacts are complete and correct.

### Interaction style

Configured in `ai26/config.yaml`. Can be overridden per invocation:

    /ai26-design-user-story TICKET --style socratic
    /ai26-design-user-story TICKET --style proactive
    /ai26-design-user-story TICKET --style reactive

#### Socratic (default)

The LLM asks questions that lead the human to articulate decisions.
It does not propose solutions upfront — it helps the human think.

When the human is unclear, the LLM asks a more precise question rather than filling the gap.
When the human reaches a conclusion, the LLM names and structures it.

Best for: high-impact decisions, new domain concepts, greenfield features.

    Human: I need to send notifications to customers when their conversation is closed.

    LLM:   What guarantees does the notification need?
           If it arrives a few seconds late, is that acceptable?

    Human: No, it needs to be reliable. It can be delayed but not lost.

    LLM:   And if the notification service is temporarily unavailable — should the
           conversation close anyway, or should it wait?

    Human: It should close. Notification is a side effect, not a precondition.

    LLM:   That sounds like an at-least-once async side effect — fire and retry,
           decoupled from the transaction. Does that match what you have in mind?

    Human: Yes, exactly.

    LLM:   That decision is worth capturing. Should I open an ADR for it?


#### Proactive

The LLM reads the available context and makes a reasoned recommendation.
The human validates, challenges, or approves.

Best for: well-understood decisions where context is rich, incremental additions to existing modules.

    LLM:   Based on your architecture context, you already use Kafka for domain events
           with at-least-once delivery. Sending the notification as a domain event
           on conversation close would be consistent with that pattern.
           Does that work, or do you see a reason to deviate here?

    Human: Works for me.


#### Reactive

The LLM presents options with trade-offs and waits for the human to decide.
It does not ask leading questions or make recommendations.

Best for: lower-stakes decisions, when the human already has a strong prior and needs
a structured view of the options.

    LLM:   For delivering the notification, three options:

           A. Synchronous HTTP call to the notification service
              + Simple. - Tight coupling. Conversation close fails if service is down.

           B. Domain event on Kafka (at-least-once)
              + Decoupled, reliable. - Requires consumer on the other side.

           C. Outbox pattern with polling
              + Guaranteed delivery, no Kafka dependency. - More infrastructure to maintain.

    Human: B.

---

## Decision detection

During the conversation, the LLM monitors for decision moments — points where the human
is weighing options, asking for trade-offs, or expressing uncertainty about the right approach.

A decision moment looks like:
- The human asks "what are the options?"
- The human expresses uncertainty: "I'm not sure whether to..."
- The human asks for trade-offs between two approaches
- The human changes their mind mid-conversation

When a decision moment is resolved — when the human commits to a direction — the LLM
recognises the closure and proposes to document it before continuing.

### How the LLM proposes documentation

The LLM does not document automatically. It asks:

    LLM: That decision is worth capturing. Should I document it as an ADR?

The human can say yes, no, or redirect:

    Human: Yes.
    → LLM drafts the ADR inline and asks for confirmation before writing it.

    Human: No, it's already covered in our context.
    → LLM checks ai26/context/DECISIONS.md. If it is not there, it asks:
      "Should I add it to DECISIONS.md then?"

    Human: It's a global policy, not specific to this feature.
    → LLM adds it to ai26/context/DECISIONS.md instead.

### What goes to ADR vs context

| Decision type | Where it goes |
|---|---|
| Domain modelling (aggregate boundaries, entity relationships) | ADR |
| Data design (schema strategy, indexing approach) | ADR |
| Inter-component communication (sync vs async, protocol, contract) | ADR |
| Global company/team policy already decided (e.g. "we use Kafka for events") | ai26/context/DECISIONS.md |

The `adr_triggers` list in `ai26/config.yaml` configures which categories produce ADRs.
Teams can extend or restrict the defaults.

### ADR format

ADRs are drafted inline during the conversation and written to `docs/adr/` on confirmation.

    # ADR-YYYY-MM-DD: [title]

    ## Status
    Accepted

    ## Context
    [what was the situation that required a decision]

    ## Decision
    [what was decided]

    ## Trade-offs considered
    [options that were weighed and why they were rejected]

    ## Consequences
    [what changes as a result of this decision]

    ## Ticket
    [TICKET]

---

## What the LLM loads before the conversation starts

1. `ai26/config.yaml` — interaction style, ADR triggers, configured artefacts
2. `ai26/context/DOMAIN.md` — existing domain concepts (to detect overlaps)
3. `ai26/context/ARCHITECTURE.md` — constraints (to apply as non-negotiables)
4. `ai26/context/DECISIONS.md` — global decisions (to avoid re-debating closed questions)
5. `ai26/context/DEBT.md` — known risk areas (to flag when the feature touches them)
6. Existing module documentation in `docs/architecture/modules/{module}/` (if present)
7. Existing ADRs in `docs/adr/` (to surface conflicts early)

If a required context file is missing, the LLM notifies the engineer before starting:

    Context file ai26/context/DOMAIN.md not found.
    The design conversation can proceed, but decisions may lack domain context.
    Do you want to create it first, or continue without it?

---

## Artefact writing

Artefacts are written progressively as each domain area is resolved — not all at the end.
When a topic is settled, the LLM writes the relevant section immediately and notifies the
engineer so they can review it before the conversation moves on.

The LLM does not ask "shall I write the domain model now?" — it writes when the conversation
has produced enough confirmed information to do so:

    LLM: The domain model is settled. Writing domain-model.yaml...
         ✓ domain-model.yaml written.
         You can review it now if you want before we continue to use cases.
         Just say "show it" or "continue".

The engineer can inspect the artefact immediately, request corrections, or let the
conversation proceed. The LLM does not continue until the engineer responds.

If the human revisits a settled topic via conversation, the LLM updates the artefact,
shows what changed, and asks for confirmation before overwriting:

    LLM: That changes the aggregate boundary we settled earlier.
         I'll update domain-model.yaml — here is the diff:

         - status: OPEN | CLOSED
         + status: OPEN | CLOSED | ARCHIVED

         Confirm?

### Direct file edits

The engineer can also edit artefact files directly in their editor, outside the conversation.
This is allowed and expected — the engineer owns the files.

When this happens, the engineer must inform the LLM explicitly:

    Human: I edited domain-model.yaml directly. Please re-read it.

The LLM then:
1. Reads the current file
2. Diffs it against what it had in memory from the conversation
3. Summarises what changed:

       LLM: I see the following changes in domain-model.yaml:
            - Added state ARCHIVED to ConversationStatus
            - Renamed field `closedAt` to `resolvedAt`

            Consequences:
            - use-case-flows.yaml references `closedAt` in the CloseConversation output — needs update
            - error-catalog.yaml is unaffected
            - api-contracts.yaml response schema uses `closedAt` — needs update

            Should I apply those updates now, or do you want to handle them?

The LLM does not assume the edit is isolated. It always checks for downstream artefacts
that reference the changed element and surfaces the consequences before proceeding.

The engineer is responsible for notifying the LLM of direct edits. If they do not,
the LLM will be working from a stale mental model. This is a known trade-off —
the alternative (polling files for changes) is outside the scope of a conversational skill.

---

## When the design phase ends

The design phase ends when:
1. All configured artefacts are written and confirmed
2. All open ADR moments have been resolved (documented or explicitly deferred)
3. The LLM has run the completeness check (cross-references between artefacts)

The LLM presents a final summary:

    Design complete for TICKET.

    Artefacts written:
      domain-model.yaml
      use-case-flows.yaml
      api-contracts.yaml
      error-catalog.yaml
      glossary.yaml
      behavior/send-notification.feature
      ops-checklist.yaml

    ADRs written:
      docs/adr/2026-03-06-notification-delivery-model.md

    Context updates:
      none

    Next step: /ai26-implement-user-story TICKET
