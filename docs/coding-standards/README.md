# Coding Standards — valium

Clean Architecture and DDD involve patterns that are not obvious the first time you encounter them — why the constructor is private, why the use case returns `Either` instead of throwing, why the controller has no `if` statements. Without written standards, these decisions get rediscovered (and sometimes reversed) by each new engineer, and the codebase drifts toward inconsistency. The cost is real: longer PR reviews arguing about patterns, regressions from violations that CI didn't catch, and onboarding that depends on finding the right person to ask.

These documents record the decisions **once**, with reasoning and code examples, so that "why does this code look like this?" always has an answer — whether the question comes from a human or from an AI assistant.

## AI-first design

AI assistants write a significant and growing share of the code in this project. That makes them a first-class audience for these standards — not an afterthought.

Every rule and convention is evaluated against a question: **can an AI assistant follow this consistently without human intervention?** If a rule requires implicit knowledge, tribal context, or judgment calls that can't be expressed in writing, it's a bad rule — for humans too, but especially for AI. Good standards are explicit, unambiguous, and mechanical enough that a machine can apply them. The fact that they're also easier for new engineers to learn is not a coincidence.

This criterion shapes the decisions we make:

- **No ambiguity.** When there are two valid approaches, we pick one and document it. Ambiguity in the standards becomes inconsistency in the generated code — and in human code too, but AI amplifies it faster.
- **Naming conventions are rules, not suggestions.** `VerbNounUseCase`, `{Entity}Repository`, `{Name}DTO` — rigid naming lets the AI place code correctly and lets grep-based tooling verify it. If the name is predictable, the AI doesn't have to guess.
- **Exhaustive anti-patterns.** Showing what *not* to do is as important as showing the correct shape. A clear ❌ / ✅ boundary eliminates grey areas where both humans and AI drift.
- **Explicit over implicit.** If a decision depends on "you just know" or "ask someone", it's not a standard yet. Writing it down is what makes it enforceable — by a reviewer, by ArchUnit, or by an AI assistant.

## What you get out of this

- **Faster PRs.** When everyone follows the same patterns, review feedback is about logic, not structure. No more "this should be an `Either`" conversations.
- **Less cognitive load.** You don't need to decide *how* to structure a use case, a controller, or a repository — the template exists. Focus on the business problem.
- **Safer refactoring.** Architecture tests in CI catch layer violations automatically. You can move fast without accidentally breaking the dependency rule.
- **Smoother onboarding.** Whether you're new to the team or new to Clean Architecture, the documents build your understanding from quick reference to deep principles.

None of this is about restricting creativity. Domain modeling, algorithm design, and problem decomposition are where engineering judgment matters most — the standards free you to focus there by removing decisions that should be consistent across the team.

## Documents

| Document | What it contains | When to read it |
|---|---|---|
| [Quick Reference](./quick-reference.md) | Layer rules, naming conventions, error handling decision table, testing decision table, code shape templates | **Start here** — daily reference |
| [Architecture Principles](./architecture-principles.md) | Layers, dependency rule, DDD patterns (aggregate, entity, value object, repository, domain events), anti-patterns, and how to evolve the model | When implementing a new domain concept or reviewing for architectural correctness |
| [Domain Events — ECST Pattern](./domain-events.md) | Event-Carried State Transfer, sealed hierarchy, snapshot design, single emitter, Kafka contract, anti-patterns | When designing or implementing domain events |
| [Domain Events — Proto Appendix](./domain-events-proto-appendix.md) | Protobuf conventions, `oneof` variant discrimination, `n26/argon` reference, mapper template | When writing the Kafka serialization layer |
| [Testing Strategy](./testing-strategy.md) | Testing pyramid, what to test at each layer, what to mock, Gherkin patterns, TestContainers setup, comparison with London/Detroit schools | When writing tests or deciding what type of test to add |
| [Project Structure](./project-structure.md) | Source and test folder layout, package naming conventions, file naming rules | When creating a new file and needing to know where it goes |
| [How-To Cookbook](./how-to.md) | Copy-paste templates for every pattern: error handling, domain events, aggregates, value objects, use cases, controllers, repositories, SQS queues, Flyway migrations, Mother Objects | When you need the exact code shape for a specific pattern |

**Reading order for newcomers:** Quick Reference → Architecture Principles → How-To Cookbook (as needed).

## Getting up to speed

Reading is necessary but not sufficient — the patterns stick when you use them on real code. A few ways to accelerate:

1. **Your first PR.** Pick a small feature or bug fix. Open the How-To Cookbook and use the templates. The code should look structurally identical to the examples — layer placement, naming, error handling shape. If it doesn't, that's the conversation to have in the review.
2. **Pair on a review.** Review a teammate's PR with the Quick Reference open. Flag one pattern deviation and discuss it — not to gatekeep, but to calibrate shared understanding. Teaching a pattern is the fastest way to internalize it.
3. **Write a Mother Object.** When your test needs a domain entity, create a Mother that delegates to the domain factory with random defaults. This small exercise touches factories, value objects, and the testing conventions in one shot.
4. **Break something on purpose.** Write a test that puts infrastructure code in the domain layer and watch ArchUnit fail in CI. Understanding *why* the guardrails exist makes them intuitive instead of arbitrary.
5. **Use AI as a sparring partner.** The project feeds these standards to AI assistants (Copilot, Claude Code, and others) through instruction files and skills, so generated code already follows the patterns — layer placement, `Either` error handling, Mother Objects, primitive-only use case signatures. Use that as a starting point, not a final answer. The value is in reviewing what it produces: when the AI generates something that looks wrong, figure out *why* before you change it. Sometimes the AI applied a rule you hadn't internalized yet; sometimes it got it wrong. Both cases teach you something.

## How AI consumes these standards

These documents are the **single source of truth**. From them, we derive compact instruction files and skills that AI assistants consume as context. The goal is that when you ask Copilot or Claude to write a use case, the output already respects the dependency rule, returns `Either`, uses primitive signatures, and places the file in the right layer — without you having to explain any of that in the prompt.

This works through three layers:

| Layer | What it does | Example |
|---|---|---|
| `docs/coding-standards/` | Full principles, reasoning, templates, anti-patterns — the source of truth | This document, Architecture Principles, How-To Cookbook |
| Instruction files | Compact project summary — architecture, conventions, available skills. One per assistant (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`) | Small file, equivalent to `CLAUDE.md` |
| Skills | Step-by-step workflows for complex tasks — implement a feature, review a PR, plan a spike. Defined per assistant (`.claude/skills/`, `.github/skills/`) | `/developer`, `/pr-reviewer`, `/planner` |

Instruction files and skills are **derived artifacts** — when a coding standard changes, the corresponding files update too. If you find an AI assistant generating code that contradicts the standards, the fix belongs in the instruction or skill definition, not in a prompt workaround.

What this means for day-to-day work:

- **AI-generated code is held to the same standard as human code.** It goes through the same PR review with the same architectural checks.
- **Review AI output critically.** Generated code that follows the patterns is a good sign; generated code that doesn't is either a bug in the instructions or an edge case worth discussing.
- **Don't encode knowledge only in prompts.** If you find yourself repeatedly correcting the AI on the same pattern, the instruction file is missing a rule. Fix it there so everyone benefits — humans and machines.

## How the standards stay alive

These are working documents, not museum pieces.

- **PR reviews** are the primary feedback loop. Every review checks architectural alignment — not as gatekeeping, but as teaching. When you explain *why* a pattern exists, you reinforce it for both author and reviewer.
- **Architecture tests (ArchUnit)** run in CI and enforce layer violations automatically. They never pass by accident and never need human attention for the rules they cover.
- **Boy-Scout Rule.** Whenever you touch code, leave the surrounding module cleaner than you found it. Small, incremental improvements compound.
- **AI instructions evolve with the standards.** When a coding standard changes, the derived instruction files and skills update in the same PR. If the AI gets something wrong, the instruction or skill definition needs a fix — treat it like any other bug.
- **Propose changes.** If a rule doesn't fit a real scenario, open a discussion — the resolution becomes an ADR in [`docs/adr/`](../adr/) and the standards update. Blindly following rules you disagree with erodes trust; proposing changes strengthens them.
- **No blame for mistakes.** When a violation ships, it becomes a learning opportunity: add the failing test first, then fix. The standard improves if the violation revealed an unclear rule.

## Related

| Resource | Description |
|---|---|
| [N26 Hexagonal Architecture Onboarding Guide](https://backstage.tech26.de/docs/default/component/backend-docs/onboarding/guides-and-procedures/on-boarding-hexagonal-architecture/) | Company-wide introduction to Hexagonal Architecture (Ports & Adapters) — recommended reading for engineers new to the pattern |

## Technologies

| Category | Technology |
|---|---|
| Language | Kotlin |
| Framework | Spring Boot |
| Persistence | JOOQ |
| Database | PostgreSQL |
| Unit testing | JUnit 5 + MockK + Kotest |
| BDD | Gherkin docstrings (no framework) |
| Integration testing | TestContainers |
| Architecture testing | ArchUnit |

---

**Scope:** standards apply to the `service/` module. The `application/` module is legacy (do not modify unless explicitly asked). The `persistence/` module is temporary and will be absorbed into `service/` — see [Project Structure](./project-structure.md) for details. The target state is a single module.
