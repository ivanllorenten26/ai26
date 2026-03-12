# AI26 User Guides

Guides for everyone who works with AI26 — engineers, product managers, tech leads, and directors. Each guide is self-contained and written for its audience.

---

## Start here

If you are new to AI26, read **[AI26 in 5 Minutes](./ai26-in-5-minutes.md)** first. It answers what AI26 is, what it does, and what your day looks like. Then continue to the guide for your role.

---

## By audience

### Engineers

**[Engineer Guide](./engineer-guide.md)**
End-to-end tutorial: take a Jira ticket from `/ai26-start-sdlc` through design, implement, validate, review, and promote. Includes exact commands, sample artefact snippets, sample generated code, and a commit message format guide. Start here if you are building features with AI26.

**[Conventions Cheatsheet](./conventions-cheatsheet.md)**
Single-page reference for every coding rule (CC-01 through T-08), naming conventions, error handling decision table, testing decision table, and key code patterns. Keep this open while writing code or reviewing PRs.

**[Troubleshooting](./troubleshooting.md)**
FAQ format. Covers skill failures, context drift, mid-session interruptions, wrong artefacts, validation blockers, promotion conflicts, and `COMPOUND.md` pending observations. Start here when something does not work as expected.

---

### Product Managers

**[PM Guide](./pm-guide.md)**
How PMs use AI26: PRD writing with `/ai26-write-prd`, epic decomposition sign-off with `/ai26-design-epic`, and how to read Gherkin scenarios to verify implemented features match product intent. No code required.

---

### Tech Leads and Architects

**[Tech Lead Guide](./tech-lead-guide.md)**
How to onboard a team with `/ai26-onboard-team`, manage the five context files in `ai26/context/`, handle ADRs during design conversations, use the compound feedback loop, detect and repair context drift with `/ai26-sync-context`, and review migration plans.

---

### Engineering Directors

**[Director Guide](./director-guide.md)**
What AI26 delivers at the organisational level: the Compound Loop mechanics, the 80% AI mandate, adoption metrics, and how AI26 connects to the Compound Engineering vision. Zero code. Covers the shift from artisan engineers to renaissance engineers and what that means for performance management.

---

## Reference

**[Skill Catalog](./skill-catalog.md)**
One entry per skill: name, one-line description, when to use, and usage examples. Grouped by category: SDLC orchestration, team setup, migration, dev scaffolding, and testing. Includes the deprecated skill table.

**[Glossary](./glossary.md)**
Every AI26-specific term defined clearly: aggregate, artefact, bounded context, compound loop, context drift, Either, ECST, fidelity, Mother Object, promotion, spec-driven development, vibe coding, and more. Audience: everyone.

---

## Reference documentation (deeper reading)

These are the primary reference documents, linked from the guides above for depth:

| Topic | Reference |
|---|---|
| Flow A/B/C decision tree and full flow descriptions | [flows.md](../ai26-sdlc/reference/flows.md) |
| YAML schemas for every artefact | [artefacts.md](../ai26-sdlc/reference/artefacts.md) |
| Format guide for all five context files | [context-files.md](../ai26-sdlc/reference/context-files.md) |
| Validation logic and severity levels | [validation.md](../ai26-sdlc/reference/validation.md) |
| What promotion does and where things go | [promotion.md](../ai26-sdlc/reference/promotion.md) |
| Team setup from scratch | [onboarding.md](../ai26-sdlc/reference/onboarding.md) |
| Full coding rule table with recipe links | [coding-rules.md](../ai26-sdlc/reference/coding-rules.md) |
| Testing strategy and philosophy | [testing-strategy.md](../coding-standards/testing-strategy.md) |
| Compound Engineering — the intellectual framework | [compound-engineering.md](../ai26-sdlc/vision/compound-engineering.md) |
| From Artisans to Orchestrators — the N26 vision | [vision.md](../ai26-sdlc/vision/vision.md) |
| Spec Driven Development — the AI26 thesis | [the-thesis.md](../ai26-sdlc/vision/the-thesis.md) |
| The new role of the engineer | [the-engineer.md](../ai26-sdlc/vision/the-engineer.md) |
