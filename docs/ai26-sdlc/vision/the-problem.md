# The Problem That AI26 Solves

> Why a new development lifecycle? What is actually broken?

---

## Systems accumulate knowledge that nobody writes down

A system that is modified over years accumulates something more valuable and more fragile than code: decisions. Why this endpoint returns a 200 instead of a 201. Why the retry logic has a 37-second backoff. Why payments go through queue A for amounts below €50 and queue B above. Why the foreign key is missing from that table.

Some of this knowledge is in comments. Most of it is in people's heads.

When people leave, the knowledge disappears. Not suddenly — gradually. The new engineer reads the code, forms a hypothesis about why it works this way, and proceeds. Their hypothesis is sometimes right. Sometimes it is wrong in ways that take six months to manifest.

This is not a new problem. It predates software. But it has always been manageable because the pace of change was bounded by how fast humans could write code. A team of five engineers produces a finite amount of change per week. The knowledge loss is proportional to that pace.

---

## Autonomous AI amplifies the problem by an order of magnitude

When an AI agent can generate a hundred lines of coherent, compilable, test-passing code in thirty seconds, the pace of change is no longer bounded by typing speed. It is bounded only by the quality of the instructions the agent receives.

An agent that does not have access to the *why* behind the system will do what AI does by default: it will find the technically clean solution. It will correct things that were wrong for a reason. It will break invariants that nobody documented. It will take the modern approach that ignores the regulatory constraint that made the old approach necessary in 2019. And it will do all of this confidently, with tests that pass.

The problem is not that AI generates bad code. The problem is that AI generates **coherent code that violates invisible contracts**.

The solution is not longer prompts. It is not better models. It is **knowledge architecture** — making the invisible contracts explicit, versioned, and accessible to every agent that touches the system.

---

## The gap between intention and implementation

There is a structural gap in every software organisation between the people who know *what* the system should do and *why*, and the people who know *how* to make it happen.

PMs hold product intent: the business model, the user needs, the regulatory requirements, the strategic bets. Engineers hold implementation knowledge: the architecture, the constraints, the technical debt, the patterns. These two bodies of knowledge rarely overlap, and they are almost never written down in a way that the other side can consume.

The traditional SDLC manages this gap through conversation — meetings, tickets, PRs, Slack threads. The artefacts that emerge (Jira tickets, design docs, PR descriptions) are narrative documents written by humans for other humans. They are useful. They are not machine-consumable.

When AI enters the development loop, this gap becomes acute. An AI agent reading a Jira ticket gets the *what* — a description of the desired outcome. It does not get the *why* — the constraints, the prior decisions, the things that cannot change. It has to infer them from the code, which means it inherits all the undocumented assumptions embedded in the existing implementation.

---

## Traditional SDLC treats code as the primary artefact

The dominant model of software development — in all its variants, from waterfall to agile — treats **code** as the primary artefact. Everything else (requirements, designs, tests, documentation) is in service of producing code. Code is what ships. Code is what generates value. Code is what gets reviewed.

This made sense when code was the bottleneck. Writing correct, maintainable code was hard. The work was in the writing.

In a world where AI can write code from a precise description, the bottleneck shifts. The work is no longer in the writing — it is in the **specifying**. Getting the description precise enough that the generated code does the right thing. Maintaining that description as the system evolves. Ensuring the description and the code remain coherent over time.

If code is no longer the bottleneck, code should not be the primary artefact. The **specification** should be.

---

## The challenge is continuity of intention over time

The hardest problem is not generating the first version of a feature. It is keeping the system coherent as it grows.

Every feature adds to the system's surface area. Every fix introduces a small compromise. Every refactor changes the structure without changing the behaviour. Over time, the original intention behind each decision becomes harder to recover. The code is there, but the reasoning is gone.

Humans manage this through institutional memory — people who have been around long enough to remember why things are the way they are. This is fragile but it works, up to a point.

AI-augmented development does not naturally have institutional memory. Every session starts fresh. Every agent reads the current state of the code and infers intent from structure. Without a mechanism for capturing and preserving intention over time, each AI session erodes coherence slightly — optimising locally, breaking global invariants that were never made explicit.

AI26 is, at its core, a system for **continuity of intention**. The `ai26/context/` layer is the explicit representation of what the team knows and has decided. The design artefacts (`ai26/features/{TICKET}/`) are the explicit representation of what each feature is supposed to do and why. The promotion process (`ai26-promote-user-story`) ensures that every completed feature enriches the shared knowledge base — so that the next feature starts with more context, not less.

The test suite, read through Gherkin docstrings embedded directly in the test code, becomes the **executable memory of the system's intent**. Not documentation that might be stale. Executable code that fails if the intent is violated.

---

## What AI26 does not claim

AI26 does not solve the underlying problem. Systems will still accumulate undocumented assumptions. Context files will still drift. Intentions will still get lost.

What AI26 does is create **friction against knowledge loss**. Every feature runs through a design phase that makes decisions explicit. Every PR is accompanied by artefacts that capture intent. Every promotion updates the shared knowledge base. Every validation gate checks that the code matches the design.

The goal is not perfect institutional memory. The goal is a system where knowledge loss is **visible**, **localised**, and **recoverable** — rather than silent, diffuse, and permanent.

---

*See also: [The thesis](the-thesis.md) — how AI26 addresses this problem through Spec Driven Development.*
