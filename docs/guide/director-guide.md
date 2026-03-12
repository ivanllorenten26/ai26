# Director Guide

What AI26 delivers at the organisational level: the Compound Loop, the 80% mandate, adoption metrics, and how it connects to the Compound Engineering vision. No code. Audience: engineering directors.

---

## The core bet

Traditional software engineering has a compounding cost curve: every new feature increases the surface area of the system, adds more code to understand, and makes future changes harder. Complexity is the natural direction of travel.

AI26 reverses this. It implements Compound Engineering — a development operating model where each completed feature makes the next feature easier to build, through accumulated machine-readable knowledge rather than accumulated complexity. The system gets smarter with every iteration.

This is the organisational bet: that the teams who build this property deliberately will achieve a productivity advantage that compounds over time, while teams running traditional SDLC will face increasing marginal cost per feature.

The macro evidence for this bet is already visible: AWS compressed 4,500 developer-days of Java upgrade work into 2 days. JPMorgan Chase achieved more than 70% increase in code deployment velocity with 20% reduction in rework. Google reports that more than 25% of all new code is AI-generated and reviewed by engineers.

---

## What AI26 delivers

### Faster feature delivery with fewer surprises

The AI26 design phase forces decisions to be made explicitly before a line of code is written. Constraints surface at design time — not in production. The result: fewer blocked PRs, fewer rework cycles, fewer incidents caused by a feature violating an undocumented architectural rule.

Typical pattern seen at teams with functioning compound loops: by the 20th feature, the time from approved design to working code with passing tests is materially shorter than at feature 5 — because the AI is operating with 20 features worth of accumulated context rather than starting from near-zero.

### Institutional memory that survives turnover

In a traditional engineering organisation, knowledge lives in people's heads. When engineers leave, that knowledge disappears. A new engineer reads the code, forms a hypothesis about why it works this way, and proceeds — sometimes correctly, sometimes not.

AI26 externalises this knowledge into machine-readable context files. Every significant design decision is documented. Every known fragile area is catalogued with a risk level. Every bounded context boundary is explicit. A new engineer — or a new AI agent in a new session — starts from the team's accumulated understanding, not from zero.

### Reduced rework through shift-left

AI26 applies context at the design phase, before implementation. The traditional SDLC applies context late: constraints surface in PR review, integration problems appear in QA, production incidents reveal edge cases that nobody anticipated. Each late discovery costs more to fix than an early one.

By forcing edge cases, error conditions, and invariants to be stated during the design conversation — before any code is written — AI26 moves the cost of discovery to its cheapest point.

### Visible quality gates

Every ticket goes through three automated checks before a PR is opened: design-to-code coherence, test coverage, and Jira acceptance-criteria-to-scenario coherence. These gates are not optional and are not bypassed by deadline pressure. The team always knows whether a feature is complete or not.

---

## The 80% AI mandate

The organisational target: **80% of all Pull Requests must be significantly AI-assisted or generated.**

This is not a metric to be gamed. It is a forcing function.

When a team is below 80%, it is almost always because something in the development process is blocking AI adoption — undocumented conventions that engineers know but the AI does not, a fragile module that cannot be touched safely, an architecture that was never made explicit. The 80% number surfaces these blockers.

**What the mandate changes:**

- Performance is no longer measured by lines of code written or tickets closed. It is measured by architectural orchestration quality, effective context creation, and system reliability.
- Engineers are no longer valued for syntax recall. They are valued for domain expertise, system-level thinking, and the precision of their specifications.
- Leads are accountable for context quality, not throughput.

**What the mandate does not mean:**

- Engineers do not stop making decisions. They make more decisions, not fewer — but at higher leverage points.
- Code quality does not decrease. Implementation skills generate architecturally compliant code by construction. Validation gates verify that what was designed is what was built.
- Speed is not the only goal. The Compound step is 20% of engineer focus — the time invested in context updates is what makes the next feature faster.

---

## The Compound Loop — what you are investing in

```
1. Plan  (40% of engineer focus)
   Agents read existing context, research the codebase,
   and synthesise a detailed implementation plan.
   Engineers approve or challenge the plan.
         ↓
2. Work  (10% of engineer focus)
   Agents implement from the approved plan.
   Engineers direct, not write.
         ↓
3. Assess  (30% of engineer focus)
   Automated gates verify coherence, coverage, and compliance.
   Human reviewers focus on business judgement and strategic implications.
         ↓
4. Compound  (20% of engineer focus)
   Every completed feature updates the shared knowledge base.
   The next agent starts richer than the last.
         ↑
```

The money step is Compound. If teams skip it — because there is deadline pressure, because it feels like overhead, because the feature shipped and everyone has moved on — the loop produces output but does not improve. The 20% investment in Compound is what turns a code generator into a compounding system.

---

## Adoption metrics

These are the signals that tell you whether the compound loop is actually running:

| Metric | What it tells you |
|---|---|
| % PRs with design artefacts committed | Whether the design phase is running |
| % tickets with promotion completed | Whether the Compound step is running |
| Validation blocking rate over time | Whether context quality is improving (should decrease) |
| % of `ai26-backfill-user-story` invocations | Proxy for skipped design phases (should be near zero in steady state) |
| Time from approved design to passing tests | Whether the loop is accelerating (should decrease over time) |
| Context drift frequency (sync-context findings) | Whether context is being maintained |

Do not track lines of code. Do not track AI invocations. Track whether the loop is closed.

---

## The engineer's changing role

The vision document describes a four-part evolution: artisan coder (hand-writes every line) → artisan coder overwhelmed by AI volume → alchemist coder (experimenting with agents, inconsistent results) → **renaissance engineer** (orchestrates fleets of specialised agents, owns constraints and architecture, writes instructions and context rather than syntax).

The target state is the renaissance engineer. The shift it requires is not technical — the skills exist. The shift is in how engineers think about their output:

> "Did I ship the feature?" is the old question.
> "Did I make the next feature easier to ship?" is the new one.

This has implications for hiring, levelling, and performance management. The engineers who thrive in the AI26 model are those with deep domain expertise, strong system-thinking ability, and high precision in articulating constraints. These are the skills you develop and reward.

---

## What AI26 is not

- It is not a code generator you prompt ad-hoc. The value is in the closed loop, not in any individual invocation.
- It is not a way to do the same development faster. It changes what engineers do, not just how fast they do it.
- It is not a silver bullet for technical debt. It helps manage and surface debt — paying it down still requires engineering capacity.
- It is not a replacement for engineering judgement. It automates execution; judgement is what engineers are paid for.

---

## Reference

- [AI26 in 5 Minutes](./ai26-in-5-minutes.md) — what AI26 does in concrete terms
- [Compound Engineering vision](../ai26-sdlc/vision/compound-engineering.md) — the intellectual framework
- [Vision: From Artisans to Orchestrators](../ai26-sdlc/vision/vision.md) — the N26 strategic context
- [Glossary](./glossary.md) — definitions for compound loop, vibe coding, renaissance engineer, 80% mandate
