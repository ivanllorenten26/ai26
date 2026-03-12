# AI26 — AI-Augmented Software Development Lifecycle

AI26 is a distributed, configurable AI-augmented development lifecycle that covers the full
spectrum from business initiative to production code. It is built on the thesis that
**the specification, not the code, is the primary artefact** of software development in an
AI-augmented world.

---

## Vision

Why we built AI26, what problem it solves, and what changes for the engineer.

| Document | What it covers |
|---|---|
| [The problem](vision/the-problem.md) | Why a new SDLC? The knowledge crisis, intention gap, and continuity challenge |
| [The thesis](vision/the-thesis.md) | Spec Driven Development — structured artefacts, shift-left, humans at decisions |
| [The engineer](vision/the-engineer.md) | The new role — architect of intention, adoption path, review responsibilities |
| [Risks and mitigations](vision/risks-and-mitigations.md) | What can go wrong and how we mitigate it — named honestly |

---

## Reference

How AI26 works — configuration, artefacts, flows, validation, and distribution.

| Document | What it covers |
|---|---|
| [Overview](reference/README.md) | Principles, full flow, repository layout, document index |
| [Configuration](reference/configuration.md) | `ai26/config.yaml` schema, `ai26/context/` files, defaults, local overrides |
| [Entry points](reference/entry-points.md) | `/ai26-start-sdlc` routing, all entry scenarios, partial adoption |
| [**Flows guide**](reference/flows.md) | **Three flows (A/B/C), when to use each, compound engineering model — start here** |
| [Level 1 flow](reference/level1-flow.md) | PRD (1a), epic architecture (1b), decomposition (1c) — legacy reference |
| [Design phase](reference/design-phase.md) | Design conversation — interaction styles, decision detection, artefact writing |
| [Decision model](reference/decision-model.md) | Two-level decisions — context vs ADR, formats, lifecycle |
| [Artefacts](reference/artefacts.md) | All design artefacts with YAML examples and cross-reference rules |
| [Skills architecture](reference/skills-architecture.md) | Three skill layers, distribution model, artefact contract |
| [Coding rules](reference/coding-rules.md) | Complete rule reference — ID, description, recipe, and enforcing skills |
| [Context management](reference/context-management.md) | Plan files, subtask details, orchestrator behaviour, recovery, parallelism |
| [Validation](reference/validation.md) | Three validation responsibilities, automatic gate, proposed corrections |
| [Promotion](reference/promotion.md) | Single promotion operation — artefacts, ADRs, context, epic promotion |
| [Version control](reference/version-control.md) | Branch/commit conventions, automatic commits, interrupted session recovery |
| [Onboarding](reference/onboarding.md) | How a team adopts AI26 from scratch — prerequisites, setup, first run |
| [Aggregate format](reference/aggregate-format.md) | Format for `ai26/domain/{module}/{aggregate}.md` files |
| [Context files](reference/context-files.md) | Format and content guide for all `ai26/context/` files |
| [Context mapping](reference/context-mapping.md) | Integration registry format and C1/C4 diagram generation |
