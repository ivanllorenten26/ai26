# The New Role of the Engineer

> What changes for the people in this system. Not a job description — a description of where engineering judgement goes.

---

## The role does not disappear. It relocates.

The most common anxiety about AI-augmented development is that the engineer's role diminishes. The evidence from AI26 practice points in a different direction: the role becomes **more demanding**, not less. The demand shifts from execution to judgement.

When writing code is the primary activity, engineering skill manifests in many small decisions made continuously: variable names, function boundaries, error handling, test structure. These decisions are not trivial — they accumulate into architecture. But many of them are recoverable. A bad variable name can be renamed. A poorly designed function can be refactored. The feedback loop is tight.

When specifying is the primary activity, engineering skill manifests in fewer, larger decisions made explicitly. The structure of a domain model. The boundary of a use case. The invariants that must hold across state transitions. These decisions are harder to recover from — an ambiguous domain model produces code that passes tests but does the wrong thing, and the error may not surface until a downstream system tries to consume the data.

**A precise specification requires more rigour than writing code**, because the specification cannot lean on the intuitions of the person implementing it. The code will do exactly what the spec says, including what the spec implied but did not state.

---

## The three new core responsibilities

### 1. Defines intention

The engineer's primary responsibility shifts toward translating business needs into specifications precise enough for AI to execute without ambiguity.

This is harder than it sounds. Business requirements are expressed in terms of outcomes and user needs. Specifications must be expressed in terms of system behaviour, invariants, error conditions, and state transitions. The translation from one to the other requires both technical and business understanding.

A well-crafted specification:
- States what the system must do and, equally, what it must not do
- Makes every error condition explicit — not just the happy path
- Documents the invariants that cannot be violated, even in edge cases
- Identifies the decisions that are still open and flags them for human resolution
- Is precise enough that two different implementation agents would produce equivalent code from it

An ambiguous specification produces code that works but does the wrong thing. The failure mode is insidious because the tests will pass — the tests were also generated from the same ambiguous specification.

### 2. Maintains system coherence

As the system grows, someone must ensure that local decisions are coherent with global architecture. This is not new — it is what tech leads have always done. What changes is the surface area.

In an AI-augmented team, the rate of change is higher. More features are implemented per week. More decisions are made per feature. More code is generated per decision. The risk of local coherence at the expense of global coherence increases proportionally.

The engineer's role in maintaining coherence has two components:

**Architectural vigilance** — noticing when a design decision in one feature creates a precedent that is inconsistent with decisions in other features. AI detects inconsistencies within a feature. It is less reliable at detecting inconsistencies across features, especially when those features were implemented in different sessions with different context.

**Context maintenance** — keeping `ai26/context/` accurate. The context layer is the shared knowledge base that all agents consume. If it drifts from reality, all future generated code drifts from the team's actual architecture. Every PR that changes significant behaviour must update the relevant context files in the same commit. This is as important as keeping tests green.

### 3. Manages intention debt

Technical debt is code that is correct but hard to change. Intention debt is code that was correct for a specification that the business no longer endorses.

In a traditional codebase, technical debt accumulates when the implementation diverges from best practices. Intention debt accumulates when the business diverges from the original specification — but the code, and the specification, remain unchanged.

Intention debt is harder to see than technical debt. Tools can detect code smells. No tool reliably detects that a validated, test-covered use case implements a business rule that the business quietly changed eighteen months ago.

The engineer's responsibility is to maintain the connection between current business intent and current specification. This means:
- Revisiting design artefacts when business rules change, not just when code changes
- Marking artefacts as stale when their business assumptions are no longer valid
- Proposing features to clean up intention debt the same way teams propose features to clean up technical debt
- Treating `ai26/context/DECISIONS.md` as a living document, not an archive

---

## The three modes of interaction with AI

Not all decisions warrant the same level of scrutiny. AI26 supports three interaction styles, and the engineer should know which to use when.

### Socratic

The AI asks questions that lead the engineer to articulate a decision. The AI does not recommend — it probes, challenges, and surfaces implications.

Use this for: high-impact architectural decisions where the reasoning matters as much as the outcome. Domain model design. Bounded context boundaries. State machine design for complex aggregates. Decisions that will constrain many future features.

The value of the Socratic mode is that it forces explicit reasoning. The engineer who has been asked "what happens if the payment fails after the inventory is reserved?" and has answered that question explicitly will produce a more robust specification than the engineer who trusted their intuition.

### Proactive

The AI makes a reasoned recommendation based on the context layer and prior decisions. The engineer validates or challenges.

Use this for: well-documented areas where the team's patterns are clear and consistent. If `ai26/context/ARCHITECTURE.md` describes how errors are handled and the current feature needs error handling, the AI can recommend the appropriate pattern. The engineer confirms it fits or explains why this case is different.

The proactive mode is efficient in mature codebases where the context layer accurately reflects team conventions. It degrades as the context layer drifts.

### Reactive

The AI presents options with trade-offs and waits for a decision. No recommendation is made.

Use this for: decisions where the AI does not have enough context to recommend, or where the engineer has a strong prior and wants options as a sanity check. New integration patterns. Features in areas with high intention debt. Decisions that involve business trade-offs the AI cannot evaluate.

---

## The adoption path

AI26 is progressive. No team should adopt the full system on day one. The value is in the method, not the tooling. If the tooling arrives before the method is internalised, the tooling becomes the goal and the method disappears.

### Stage 1: Make knowledge explicit (context layer first)

Before running any AI-driven flows, create `ai26/context/` with honest, accurate representations of what the team knows and has decided. This is the hardest stage because it requires acknowledging what is undocumented. It is also the highest-leverage stage: AI in the IDE already starts giving coherent answers instead of generic ones.

Success signal: an engineer new to the codebase can read `ai26/context/` and understand the architecture, the constraints, and the things not to do — without reading the code first.

### Stage 2: Specification as the primary artefact

Before implementing a feature, write a specification. Use `ai26-design-user-story` to structure the conversation. The specification does not need to be perfect. It needs to make decisions explicit that would otherwise be implicit in the code.

Success signal: the engineer can describe the complete behaviour of a feature — including all error cases and edge cases — before writing a line of code.

### Stage 3: Tests as contract

Write acceptance tests from the specification, before the implementation. The tests define what the system must do. The implementation makes them pass.

Success signal: the test suite reads like a description of the system's behaviour. Someone reading only the test names and Gherkin docstrings can understand what the system does without reading the implementation.

### Stage 4: Autonomous development

The specification is the input. The AI generates the implementation. The engineer reviews the output, not the process.

Success signal: **time from approved specification to working code with passing tests**. If this number decreases month over month, the method is working. If it increases or stays flat, the method is being applied as ceremony rather than discipline.

---

## What the engineer reviews

In the full AI26 flow, the engineer's review responsibilities are:

**During design** — the artefacts before implementation starts. Are the domain model and the business rules coherent? Are the error cases complete? Are the invariants correctly stated? Are the Gherkin scenarios testing the right things?

**After implementation** — the generated code against the specification. Does the implementation reflect the design? Are there gaps? Are there over-implementations (code that works but does something not in the spec)? Are the test docstrings accurate representations of what the tests actually test?

**During promotion** — the context updates proposed for `ai26/context/`. Are the updates accurate? Do they capture what was actually decided? Are there decisions that were made during implementation that are not reflected in the proposed context update?

In each case, the engineer is reviewing **output** — a finished artefact that can be accepted, challenged, or corrected. This is different from reviewing **process** — being present for every step of execution. The cognitive load is different. Reviewing a complete, coherent artefact is faster and more effective than supervising incremental generation.

---

*See also: [The thesis](the-thesis.md) — the principles that shaped these responsibilities. [Risks and mitigations](risks-and-mitigations.md) — what can go wrong with this model.*
