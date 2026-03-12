# AI26 in 5 Minutes

---

## What is AI26?

AI26 is the development operating system for N26 engineering teams. It is a set of skills (Claude Code commands) plus a structured context layer that together make AI-assisted development systematic, auditable, and self-improving.

It is not a code generator you prompt ad-hoc. It is a closed loop: every feature you build leaves the codebase smarter than it was before, so the next feature is faster to build correctly.

---

## What problem does it solve?

Left alone, AI-assisted development degrades over time: each AI session starts fresh, re-invents patterns the team already decided, violates constraints nobody documented, and produces code that passes tests but does the wrong thing. This is vibe coding. It produces output but does not compound.

AI26 solves this by making the system's knowledge explicit, versioned, and machine-readable. Every design decision is captured. Every completed feature updates the shared knowledge base. Every future agent starts with accumulated institutional memory — not a blank slate.

---

## What does it actually do?

Three flows cover every type of work:

**Flow A — Epics**
You have a business initiative spanning multiple tickets.
1. `/ai26-write-prd EPIC-123` — co-author the PRD with the AI, approve it
2. `/ai26-design-epic EPIC-123` — AI designs the full domain, slices it into tickets, creates Jira
3. `/ai26-implement-user-story TBD-1` (per ticket) — AI implements from artefacts, validates, reviews, promotes

**Flow B — Standalone tickets**
You have a single ticket that was not part of an epic.
1. `/ai26-design-ticket SXG-456` — design conversation producing YAML artefacts + Gherkin scenarios
2. `/ai26-implement-user-story SXG-456` — AI implements, validates, and promotes automatically

**Flow C — Quick fixes**
You have a typo, dependency bump, or obvious one-file bug.
1. `/ai26-implement-fix SXG-789` — AI implements, runs tests, commits, escalates if it finds complexity

When in doubt, run `/ai26-start-sdlc` — it reads the ticket and routes to the right flow.

---

## What does a day look like?

### As an engineer

You start your morning by running `/ai26-start-sdlc SXG-456`. The AI reads the Jira ticket, checks `ai26/context/` for domain constraints, and opens a design conversation. You answer questions about error cases and edge conditions — the things the AI cannot know without you. Twenty minutes later, you have a set of YAML artefacts and Gherkin scenarios committed to git. You approve the implementation plan, the AI generates the code, tests pass, validation passes. You open the PR. The promotion step has already updated the architecture docs and context files.

Your job that day: decide, approve, and review. Not write syntax.

### As a PM

You work with the AI to write the PRD for an upcoming epic using `/ai26-write-prd`. You answer questions about user goals, success metrics, and constraints. You see the ticket decomposition the AI proposes and approve or adjust the scope. When a ticket is implemented, you can read the Gherkin scenarios to verify the feature matches what you intended — no code required.

### As a tech lead

You maintain `ai26/context/` — the five files that are the team's institutional memory. You review ADRs that surface during design conversations. You run `/ai26-onboard-team` when a new engineer joins. When the AI flags a context drift, you run `/ai26-sync-context` to repair it. You measure the health of the compound loop by watching whether validation blocking rates decrease over time.

---

## The one thing to remember

**The Compound step is what makes it work.**

At the end of every ticket, `ai26-promote-user-story` runs. It merges the feature's knowledge into `docs/architecture/` and updates `ai26/context/`. Skip this step, and you get code — but the system does not improve. The next ticket starts from the same baseline. Run it consistently, and by ticket 50 the AI is producing better first drafts than by ticket 5, because it has 50 tickets worth of accumulated context.

The context layer is the new code. Its quality determines the quality of every output.

---

## Reference

- [Engineer Guide](./engineer-guide.md) — end-to-end tutorial with exact commands
- [PM Guide](./pm-guide.md) — how PMs work with AI26
- [Tech Lead Guide](./tech-lead-guide.md) — context management and team onboarding
- [Director Guide](./director-guide.md) — org-level outcomes and the 80% mandate
- [Skill Catalog](./skill-catalog.md) — every skill, what it does, when to use it
- [Glossary](./glossary.md) — definitions for every AI26 term
