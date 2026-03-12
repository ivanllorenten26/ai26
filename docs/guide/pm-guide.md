# PM Guide

How product managers use AI26: PRD writing, epic decomposition, ticket review, and sign-off at each gate. Audience: product managers.

---

## Your role in AI26

AI26 is built around the principle that human attention belongs at decision points, not execution points. As a PM, your decisions are the ones that engineers and AI agents cannot make: what the product should do, who it serves, what success looks like, and what constraints come from the business.

You do not need to write code, read YAML, or understand the technical architecture. You do need to be present and precise at three points in the flow: PRD authoring, epic sign-off, and scenario review.

---

## Where you engage

```
Business initiative
      ↓
1. PRD authoring         /ai26-write-prd {EPIC-ID}       ← you are here
      ↓
2. Epic design sign-off  /ai26-design-epic {EPIC-ID}      ← you approve architecture
      ↓
3. Ticket decomposition  (part of ai26-design-epic)        ← you review ticket list
      ↓
Engineering implements (engineers only)
      ↓
4. Scenario review       read scenarios/*.feature          ← you verify intent was preserved
```

---

## Step 1 — Writing the PRD

When the team is ready to start an epic, you run:

```
/ai26-write-prd EPIC-123
```

The skill opens a structured conversation. It asks you to describe the business initiative, the user problems it solves, the goals, the constraints, and how success will be measured. You answer in plain language — the AI structures the output.

**What it asks you:**

- What is the business problem this epic solves?
- Who are the users affected, and what do they currently struggle with?
- What does success look like, and how will you measure it?
- What are the hard constraints? (Regulatory, timeline, budget, technical boundaries)
- What is explicitly out of scope?

**What it produces:**

A structured PRD committed to `ai26/epics/EPIC-123/prd.md`. This document is the input to the technical design phase — the more precise it is, the better the technical design will be.

**Sample PRD structure:**

```markdown
# PRD — Conversation Analysis

## Problem
Agents currently have no visibility into conversation quality after closure.
Support leads must manually review transcripts to identify coaching opportunities.

## Goals
- Surface analysis results to agents within 5 minutes of conversation closure
- Allow support leads to filter conversations by quality score

## Success metrics
- 80% of agents view their own analysis at least once per week within 60 days of launch
- Support lead review time reduced by 40%

## Constraints
- Analysis runs in an async pipeline (results are not immediate)
- Must not expose raw transcript content outside the agent's own conversations
- Must comply with BaFin data retention requirements

## Out of scope
- Real-time analysis during active conversations
- Automated coaching recommendations
```

**Your job:** Review the AI's draft. Push back on anything that misrepresents the business intent. The AI may ask follow-up questions — answer them. Approve when the PRD accurately captures what the team is building and why.

---

## Step 2 — Epic design sign-off

After the PRD is approved, the tech lead or an engineer runs:

```
/ai26-design-epic EPIC-123
```

This skill has five internal phases. You are involved in phase 2: the architecture conversation. The AI will present a high-level design — which bounded contexts are affected, which new aggregates or domain events are proposed, which integration patterns will be used — and ask for architectural sign-off.

**Your role in phase 2:**

You are not reviewing the technical architecture for correctness — the tech lead does that. You are reviewing for business alignment:

- Does the proposed scope match the PRD?
- Are any business constraints missing or mis-stated?
- Does the proposed design reflect the actual user flows?

You do not need to understand what a bounded context is in technical detail. You do need to confirm that the system the engineers are designing is the one you intended.

Phase 3 (monolithic design) and phase 5 (Jira ticket creation) run autonomously. You do not need to be present.

---

## Step 3 — Ticket decomposition review

At the end of phase 4 of `ai26-design-epic`, the AI proposes a ticket decomposition: a list of tickets, each with a title, acceptance criteria, and estimated complexity.

**What to review:**

- Does the ticket list cover everything in the PRD?
- Are there any tickets that represent scope you did not intend?
- Are the acceptance criteria for each ticket correct from a product perspective?
- Is there any ticket that should be a separate epic or deferred to a later phase?

You do not need to review the technical implementation details of each ticket — the engineers own that. You are reviewing scope and acceptance criteria.

Once you approve, the AI creates the Jira tickets and names the feature directories.

---

## Step 4 — Scenario review

After engineering implements a ticket, you can verify that the implemented behaviour matches your intent by reading the Gherkin scenarios:

```
ai26/features/SXG-456/scenarios/fetch-analysis.feature
```

Gherkin is written in plain language. A scenario looks like:

```gherkin
Scenario: Successfully fetch analysis for a closed conversation
  Given analysis results exist for conversation "conv-123"
  When I fetch analysis for conversation "conv-123"
  Then the response is 200
  And the analysis results are returned

Scenario: Cannot fetch analysis when it is not yet available
  Given no analysis exists for conversation "conv-123"
  When I fetch analysis for conversation "conv-123"
  Then the response is 422
```

These scenarios are the executable acceptance tests. If they pass, the feature behaves exactly as described. If a scenario is missing or wrong from a product perspective, raise it before the PR is merged.

**What to look for:**

- Does each acceptance criterion from the Jira ticket have a corresponding scenario?
- Are the scenarios accurate? (The happy path is correct, the error cases match what you intended)
- Is there any scenario that tests something you did not intend?

You do not need to read code. Scenarios are the bridge between business intent and technical implementation.

---

## What you do not do

- You do not write YAML artefacts. The AI writes them from the design conversation.
- You do not review code. Engineers and `ai26-review-user-story` handle that.
- You do not trigger the implement, validate, review, or promote steps. Engineers own those.
- You do not maintain `ai26/context/`. That is the tech lead's responsibility.

---

## PRD quality tips

The quality of the PRD directly determines the quality of the technical design. Vague PRDs produce vague designs — the AI will make assumptions, and those assumptions may not match your intent.

**Write precisely:**
- "Users should be able to filter by quality score" is vague. "Agents can filter their own conversation list by analysis quality score, which is a value between 0 and 100" is precise.

**Make constraints explicit:**
- If there is a regulatory constraint, a data retention rule, or a performance requirement, write it in the PRD. The AI applies it as a design constraint.

**State what is out of scope:**
- Explicit out-of-scope items prevent the AI from proposing scope you do not want. "No real-time analysis during active conversations" saves a design conversation.

**Describe error cases from the user's perspective:**
- "What should happen if the analysis is not yet available when the agent opens the page?" is a product decision, not a technical one. Answer it in the PRD.

---

## Reference

- [AI26 in 5 Minutes](./ai26-in-5-minutes.md) — what AI26 is and what it does
- [Glossary](./glossary.md) — definitions for terms like "bounded context", "aggregate", "artefact"
- [Engineer Guide](./engineer-guide.md) — what happens during implementation (for context)
- [Skill Catalog](./skill-catalog.md) — `ai26-write-prd` and `ai26-design-epic` details
