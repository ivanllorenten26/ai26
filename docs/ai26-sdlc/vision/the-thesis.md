# Spec Driven Development — The AI26 Thesis

> The intellectual framework behind AI26: what we believe about software development in an AI-augmented world, and how those beliefs shaped the system.

---

## The shift from code to specification

The central claim of AI26 is simple: **when AI can generate code from a precise description, the primary artefact of software development is the description, not the code**.

This is not a claim about AI quality. It is a claim about where value is created.

When writing code is the bottleneck, the engineer's judgement is exercised through code. Every naming decision, every abstraction, every error path is a micro-decision made in the act of writing. The accumulated wisdom of that process lives in the code.

When AI writes the code, the engineer's judgement must be exercised earlier — in the specification. What the system should do. What invariants it must preserve. What errors it must handle. What it explicitly does not do. A well-crafted specification contains the decisions that matter. A vague specification defers those decisions to the AI, which will make them — but without business context.

The shift is not from engineering to writing. It is from **coding as thinking** to **specifying as thinking**. Both require the same underlying skills: understanding the domain, anticipating edge cases, designing for failure, thinking about the system as a whole. The medium changes. The rigour required increases.

---

## Structured artefacts over documents

The first principle of Spec Driven Development is that every output from the design phase is a **structured object with a schema**, not a free-form document.

This distinction matters enormously in practice. A Confluence page describing a feature can be read and understood by a human. It cannot be reliably consumed by a downstream system. An implementation agent reading a prose description of a feature must infer structure — what are the error cases? what are the domain entities? what is the API contract? — and that inference introduces ambiguity.

AI26 design artefacts are YAML files with defined schemas:

- `domain-model.yaml` — aggregates, entities, value objects, invariants
- `use-case-flows.yaml` — each use case with input, steps, and outcomes
- `error-catalog.yaml` — every error with its domain reason and HTTP mapping
- `api-contracts.yaml` — request/response shapes, status codes, authentication
- `events.yaml` — domain events with payload and consumer contracts
- `scenarios/` — Gherkin scenarios as the acceptance contract

These are not documentation artefacts that happen to have structure. They are **contracts** that implementation agents read directly. The implementation skill consumes `domain-model.yaml` to generate aggregate scaffolding. The validation skill reads `error-catalog.yaml` to verify test coverage. The promotion skill merges `scenarios/` into the permanent architecture documentation.

Structure is what makes the pipeline reliable. An ambiguous prose description produces inconsistent implementation across sessions. A schema-validated YAML produces deterministic scaffolding.

---

## Shift-left of context

The second principle is that knowledge should be made explicit and moved to the phase where it has the most leverage.

In a traditional SDLC, context accumulates as the feature progresses. The engineer learns about edge cases while writing code. Constraints surface in PR review. Integration problems appear in QA. Each discovery has a cost proportional to how late it arrives: a constraint discovered in PR review requires rework; a constraint discovered during Gherkin design costs a five-minute conversation.

AI26 makes context explicit at the design phase — before a line of code is written. The `ai26-design-user-story` conversation forces decisions that would otherwise be deferred:

- What happens when the external service is unavailable?
- What is the domain error when a business rule is violated?
- Who owns the aggregate state after this operation?
- What does the consumer of this event need to know?

These are not implementation details. They are specification decisions. By forcing them into the design phase, AI26 makes them visible to the engineer before they are embedded in code, and makes them available to the implementation agent as explicit constraints rather than inferences.

The context layer (`ai26/context/`) extends this principle across features. It is the accumulated knowledge of every past decision, available to every future session. An implementation agent that reads `ai26/context/ARCHITECTURE.md` before generating code is not starting from scratch — it is starting from the team's accumulated understanding of how the system is supposed to work.

---

## Humans at decision points, not execution points

The third principle is that human attention is a scarce resource and should be applied where it has the most leverage.

In a traditional development workflow, human attention is spread across both decision-making and execution. The engineer decides *and* writes. The PM decides *and* writes acceptance criteria. The reviewer decides *and* types comments.

In an AI-augmented workflow, execution is cheap. AI generates code, writes tests, produces scaffolding, formats output. The human's comparative advantage is in decision-making — understanding the business context, evaluating trade-offs, maintaining system coherence.

AI26 is designed around this principle:

- The PM does not write stories from scratch. The AI produces a structured draft from the epic and business initiative. The PM **approves or challenges** the draft.
- The engineer does not architect features in isolation. The AI runs a design conversation, asks questions, surfaces constraints, and drafts artefacts. The engineer **debates, decides, and approves**.
- The tech lead does not generate ADRs. The AI identifies a decision point during design, drafts the ADR with options and trade-offs, and asks for a decision. The tech lead **chooses and documents the reasoning**.
- The reviewer does not generate the review. The AI runs a first-pass automated review checking artefact-to-code coherence and architectural compliance. The human reviewer **focuses on what AI cannot see**: business judgement, team dynamics, strategic implications.

This is not about removing humans from the loop. It is about **moving humans to the moments where their judgement is irreplaceable** and removing them from moments where their presence is execution overhead.

---

## The spec as living documentation

AI26 uses Gherkin scenarios — in `.feature` files and as `// Scenario:` docstrings embedded directly in test code — as the acceptance contract for every feature.

This is a deliberate choice. The alternatives are:

1. **Prose acceptance criteria in Jira** — human-readable, not machine-verifiable, often stale within weeks of implementation
2. **Cucumber feature files** — human-readable, executable, but require a separate step-definition layer that introduces drift between the scenario and the test
3. **Test names and docstrings in code** — directly co-located with the implementation, visible in PR diffs, verified by the linter

AI26 uses option 3. The `// Scenario:` docstring in a test method is the design artefact. The test body is the implementation. The validation skill checks that every Gherkin scenario in the design has a corresponding docstring in the test suite. If the test changes, the docstring is in the same file and the same diff. There is no framework in between — no step definitions to maintain, no Cucumber runner to configure.

The design Gherkin and the implementation Gherkin are the same file, read in two different contexts: by the engineer during review, and by the validation agent during quality gates.

---

## How AI26 implements these principles

The principles above are not aspirational. They are implemented through specific mechanisms:

| Principle | Mechanism |
|---|---|
| Structured artefacts | YAML schemas with defined fields; validation fails if required fields are missing |
| Shift-left of context | `ai26-design-user-story` forces decision conversations before implementation starts |
| Humans at decision points | Every ADR requires explicit human confirmation; design phase does not proceed without sign-off |
| Living documentation | `// Scenario:` docstrings in test code; `ai26-validate-user-story` checks coherence |
| Context continuity | Promotion (`ai26-promote-user-story`) merges every feature's knowledge into `ai26/context/` |
| Intention visibility | Every phase produces a committed artefact; git history is the audit trail |

The pipeline is:

```
Design (ai26-design-user-story)
  → structured artefacts committed to git

Implementation (ai26-implement-user-story)
  → reads artefacts → generates code → commits per subtask

Validation (ai26-validate-user-story)
  → verifies code matches artefacts → blocks on violations

Review (ai26-review-user-story)
  → automated first-pass → human review focuses on residual

Promotion (ai26-promote-user-story)
  → merges artefacts into permanent docs → updates context layer
```

Each step produces committed artefacts. Nothing is ephemeral. The full history from business intent to production code is recoverable from git.

---

*See also: [The problem](the-problem.md) — why this approach is necessary. [The engineer](the-engineer.md) — what changes for the people in this system.*
