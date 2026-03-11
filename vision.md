# Vision — From Artisans to Orchestrators

Source: N26 internal deck "From Artisans to Orchestrators"
Date captured: 2026-03-12

---

## The core thesis

We are living through the Gutenberg moment for software. The printing press did not make
writers obsolete — it made hand-copying monks obsolete. AI does not make engineers
obsolete; it makes the *artisan model* of engineering obsolete.

> "The monastery is closed. Writing standard logic is a commodity; building secure systems is not."

The engineer's role shifts from **hand-crafting every line of code** (linear output, valued
for syntax memorisation, cannot scale) to **directing intelligence** (exponential leverage,
valued for deep domain expertise and system architecture).

> "We are no longer writing code — we are directing intelligence."

---

## The arithmetic of survival

The macro numbers that make this shift irreversible:

| Stat | Source |
|---|---|
| >25% of all new code at Google is AI-generated and reviewed by engineers | Google |
| 4,500 developer-days of work compressed into 2 days | AWS (upgrading 1,000 production Java apps) |
| >70% increase in code deployment velocity, 20% reduction in rework | JPMorgan Chase |

**The key insight:** Syntax is free. Understanding the problem is the scarce asset.

---

## The evolution in four acts

### The artisan coder (ca. 2024)
Hand-writes every line. Valued for memorising APIs and syntax. Output is linear — more
engineers = more code. The monk copying manuscripts by candlelight.

### The artisan coder (ca. 2025)
Same model, overwhelmed. The stack of generated code outpaces their ability to review
and reason about it. Paralysed by the volume of what AI can produce without guidance.

### The alchemist coder (ca. early 2026)
Experimenting with agents. Using AI as a tool but without a system — ad-hoc prompting,
inconsistent results. Productive in bursts, brittle under complexity.

### The renaissance engineer (ca. 2026)
Orchestrates fleets of specialised agents. Owns constraints, domain expertise, and
architecture. Writes instructions and context, not syntax. This is the target state.

---

## Traditional Engineering vs Compound Engineering

| Dimension | Traditional Engineering (Linear) | Compound Engineering (Exponential) |
|---|---|---|
| Code generation | 100% manual | 100% agentic |
| Complexity curve | Each new feature makes the next harder to build | Each new feature makes the next easier to build |
| Knowledge | Human context lost over time | AI knowledge of the codebase grows permanently |
| Scaling input | More engineers | Better context |

---

## The trap: Vibe Coding

```
Prompt → AI guesses → 3 hours of debugging
```

Vibe coding relies on hope. It solves today's problem but teaches the system nothing.
Every failure is forgotten. Every new agent starts from zero.

## The fix: Agentic Planning

```
Prompt → AI researches codebase → Proposes 3 approaches → 10 mins of flawless execution
```

Good planning requires building a shared mental model. Agents scour current repository
structures, read existing best practices, and output a strict architectural document
**before writing a single line of logic**.

---

## Introducing Compound Engineering

> "Key Principle: We are not automating thinking. We are automating typing."

**Core definition:** A self-improving development system where the engineer acts as
supervisor and orchestrator of specialised AI agents running in parallel.

### The human orchestrator directs:
- Planning Agent
- Testing Agent
- Refactoring Agent
- Security Agent

### The secure toolkit (at N26):
- **claude26 / p26** — Terminal orchestration
- **GitHub Copilot** — Real-time generation
- **Gemini** — Specification drafting

---

## The Compound Loop

The four-step cycle where every interaction makes the system smarter:

```
1. Plan (40% of engineer focus)
   Agents read issues, research commit history,
   synthesise detailed implementation plans.
         ↓
2. Work (10% of engineer focus)
   Agents write code and create tests based
   entirely on the agreed-upon plan.
         ↓
3. Assess (30% of engineer focus)
   Autonomous CI/CD verification agents and
   human orchestrators review output for
   security and compliance.
         ↓
4. Compound (20% of engineer focus)
   Engineer feeds bugs, failed tests, and
   architectural insights back into the
   system's permanent memory.
         ↑ (loop repeats)
```

**The money step is Compound.** Every pull request rejection, bug, and code review is
recorded as a permanent rule in `CLAUDE.md`. Every new agent inherits the full
institutional memory. A brand-new hire gets an AI that automatically avoids every
category of past organisational mistake.

---

## The Three Fidelities of Planning

Not all tasks need the same planning investment:

| Fidelity | Human planning required | Examples | Approach |
|---|---|---|---|
| **Fidelity 1 — The Quick Fix** | ~20% | Typos, obvious bug fixes, dependency migrations | Lightweight. Provide the error message and let the agent isolate and ship the fix. |
| **Fidelity 2 — The Sweet Spot** | ~60% | Multi-file refactoring, background jobs, new API tools | High-ROI planning. Force parallel agents to research edge cases and API rate limits before execution. |
| **Fidelity 3 — The Big Uncertain** | ~100% | Core architecture rebuilds, complex multi-account support | Hybrid vibe-planning. Rapidly build disposable prototypes to find failure points, then rigorously plan the actual implementation. |

---

## Context is the New Code

The bottleneck is no longer how fast we write code — it is how accurately we describe
what the code should do.

**The lifecycle of context:**

```
Generate → Evaluate → Distribute → Observe & Correct
```

### Spec-Driven Development
Translate implicit organisational knowledge into explicit, strict rules that drastically
reduce AI hallucination. Context is treated as a versioned artefact.

### Fix the Context, Not the Output
> "When an agent fails, do not manually rewrite the code. Debug why the agent failed
> and update the system prompt so it never makes the mistake again."

This is the CLAUDE.md / ai26 model. Every failure is an investment in the system.

---

## Execution and Autonomous Verification

> "I don't trust AI" is not a strategy. Trust is enforced by supervision.

**The Work:** Agents have all the context they need — engineering guidelines,
specifications, access to documentation through MCP — to build, navigate the app,
and iterate on the UI as if they were real users.

**The Assess:** Autonomous CI/CD verification agents live directly inside pipelines.
They independently audit code for security vulnerabilities, context leakage, and
architectural compliance before a human ever reviews it.

---

## The Renaissance Developer — four new roles

The engineer in 2026 is not one thing. They are four things simultaneously:

### The Architect (The Polymath)
Owns the **constraints**. Determines if serverless is more cost-effective than
containerised for peak loads. Makes architectural trade-offs. Writes the rules
AI operates within.

### The Verifier (The Risk Manager)
Audits non-deterministic AI generation. Ensures cryptography isn't using deprecated,
vulnerable libraries. Security and compliance ownership.

### The Systems Thinker (The Diplomat)
Aligns API contracts across fragmented teams. Navigates cross-team dependencies.
Turns organisational complexity into coherent system design.

### The Domain Expert (The Specialist)
Embeds deep business logic, regulatory compliance (e.g., BaFin KYC), and empathy
for the end user into the system. The context that AI cannot invent.

---

## Redefining Organisational Roles

### Product Engineer
True T-shaped engineers. The line between PM and Engineer blurs. Mandate: deliver
end-to-end features using AI to bridge syntax gaps across the entire stack.

### Platform Engineer (formerly DevOps/SRE)
Mandate: build an AI-friendly platform. Design internal APIs and CI/CD verification
agents to be seamlessly consumed by autonomous fleets.

### Principal & Lead Vanguards
Define what good looks like. Responsible for pushing the frontier of AI orchestration,
meta-prompting, and advanced repository context.

---

## The 80% AI Mandate

> **The Target: 80% of all Pull Requests must be significantly AI-assisted or generated.**

This is not a micromanagement tool. It is a systemic forcing function to break old habits
and surface tech debt that is blocking AI adoption.

**Redefining performance:** Engineering managers must revamp performance goals to reflect
the new AI reality. Success is now measured by:
- Architectural orchestration quality
- Effective context creation for AI agents
- Overall system reliability

Not lines of code written. Not tickets closed. The quality of the instructions you give.

---

## Summary: What this means for ai26

The ai26 SDLC system is a direct implementation of Compound Engineering:

- **`CLAUDE.md` + `ai26/context/`** = the permanent institutional memory (the Compound step)
- **Skills (`ai26-design-user-story`, `ai26-implement-user-story`, etc.)** = the specialised agents in the Planning and Work steps
- **`ai26-validate-user-story` + `ai26-review-user-story`** = the Assess step
- **`ai26-promote-user-story`** = closing the Compound loop, feeding insights back into context
- **Every ADR, every DEBT.md entry, every ops-checklist** = institutional memory that makes the next feature easier to build than the last

The bottleneck is never the code. It is always the quality of the context.

> "Artisans no more: we write instructions. We engineer context."
> "The shift is not just technical; it's a fundamental reimagining of how we build, deploy, and compound value."
