# Risks and Mitigations

> The failure modes that AI26 introduces, and how the system mitigates them. Named honestly, not minimised.

---

## The risks nobody is naming

Every technology proposal comes with a risks section. Most risks sections describe the obvious failure modes and explain why they are unlikely. This is not that kind of risks section.

These are the structural failure modes of AI-augmented development — the ones that will happen gradually, that are hard to see until they are severe, and that no individual engineer can prevent alone. They require systemic mitigations, not personal vigilance.

---

## 1. Loss of code literacy

**The risk:** If engineers stop reading and writing code, we progressively lose the capacity to understand the systems we build. Skills not exercised degrade. A generation of engineers who primarily specify and review will have less ability to diagnose, debug, and reason about low-level behaviour than a generation that wrote the code.

**The counterargument:** Systems will become too complex for any human to understand in full anyway. What matters is not that the code is readable by humans but that the behaviour is verifiable by tests. We already accept this for compilers, bytecode, and minified JavaScript.

**Why the counterargument is not fully satisfying:** The counterargument requires that verification mechanisms be infallible. If tests are wrong, if the specification is ambiguous, if the validation gate misses a class of errors — then the system produces code that passes all checks and violates the intent. Without the ability to read and reason about the code, the engineer cannot catch this. We are not at infallible verification. We are far from it.

**Mitigation:** Explicit code review responsibility remains with the engineer. AI provides a first-pass review; human review focuses on what AI cannot see. Engineers are expected to read and understand the generated code, not just verify that tests pass. The review gate is not optional — it is a mandatory phase before promotion.

Additionally: the skills that generate code are intentionally opinionated and narrow. They produce code in known patterns. An engineer who understands those patterns can read and reason about generated code efficiently, even if they did not write it.

**Status:** Partially mitigated. The degradation risk is real and long-term. No tooling prevents it. Engineering culture and explicit review expectations slow it.

---

## 2. The lying docstring

**The risk:** A `// Scenario:` docstring in a test method says the test verifies behaviour X. The test actually verifies behaviour Y. The validation skill checks that a docstring exists, not that it accurately describes the test. The specification says X. The test says it tests X. The test actually tests Y. Everything passes. Y is in production.

**Why this matters:** The docstring is the traceability link from specification to implementation. If it is inaccurate, the entire validation chain is broken. The engineer reviewing the PR sees a test with a docstring and assumes the docstring is accurate. The validation skill sees a matching docstring and reports coherence. Neither catch the semantic gap.

**Mitigation:** AI generates the docstring and the test body together, in the same generation pass. The probability of coherence is high when both are generated from the same scenario input. The risk is highest when tests are edited after generation — a test body change that is not accompanied by a docstring update.

PR review sees both the docstring and the test body in the same diff. Reviewers should treat any test body change without a corresponding docstring change as a flag.

**Status:** Partially mitigated. Linters check existence, not semantic accuracy. Human review is the last line of defence.

---

## 3. Context drift

**The risk:** `ai26/context/` files become stale. The team adds features, changes architectural patterns, makes new decisions — and the context files are not updated. Future features are designed against outdated context. AI generates code coherent with the 2024 architecture while the team has moved to a different pattern in 2026. The drift is silent and accumulates.

**Why this is dangerous:** Context drift is self-reinforcing. As files drift, teams trust them less and consult them less. As they are consulted less, they drift faster. The context layer that was the team's most valuable asset becomes a liability — consuming attention without providing accurate information.

**Mitigation:** `ai26-sync-context` detects drift by comparing the actual codebase against the context files. It is run automatically as part of `ai26-promote-user-story` and can be run manually at any time. It produces a diff of detected discrepancies and requires explicit confirmation before writing changes.

The promotion gate (`ai26-promote-user-story`) includes a mandatory sync check before committing promoted artefacts. A promotion that would introduce known context drift is blocked.

**Status:** Actively mitigated. Automated drift detection reduces the problem significantly. Does not prevent drift that `ai26-sync-context` cannot detect — semantic drift, business rule changes not reflected in code changes.

---

## 4. The faithfully wrong implementation

**The risk:** The specification is wrong. The AI implements it faithfully. The tests validate the implementation against the wrong specification and pass. The feature ships. It does the wrong thing, correctly.

This is not a hypothetical. It happens in traditional development too — specs are wrong, implementations are faithful, tests are written against the implementation. The difference in AI-augmented development is scale and speed: more features, faster implementation, less time between specification error and production.

**Why specification errors are hard to catch:** A specification error that produces working code with passing tests is invisible to automated gates. It requires a human who understands the business intent to read the specification and say "this is not what we want." That human review must happen before implementation, not after. After implementation, the sunk cost of a passing test suite makes challenging the specification harder.

**Mitigation:** Multiple review gates operate at different levels:

1. **Design review** — the `ai26-design-user-story` conversation is designed to surface ambiguities. The Socratic interaction style asks questions that expose hidden assumptions. But this only works if the engineer participates actively, not passively.

2. **Automated validation** — `ai26-validate-user-story` checks design-to-code coherence and Gherkin-to-test coherence. It does not validate that the design matches business intent.

3. **Human PR review** — the last gate. A reviewer who understands the business intent reads the specification artefacts and the code. This is the gate that can catch "works as specified, wrong intent."

4. **Context layer** — `ai26/context/DOMAIN.md` contains business invariants. The design phase checks proposed domain models against these invariants. A specification that violates a documented invariant is flagged.

**Status:** Partially mitigated. The problem is fundamental: verifying intent requires human understanding of business context. No automated system can provide this.

---

## 5. Tooling before method

**The risk:** A team adopts the AI26 tooling (skills, pipelines, automated validation) before internalising the underlying method (specification-first, context-as-discipline, humans at decision points). The tooling becomes the goal. Teams run `ai26-design-user-story` as ceremony — providing minimal answers to move through the phases — rather than as a genuine design conversation. The artefacts are complete but shallow. The implementation is coherent with the shallow artefacts. The system produces technically correct code that is architecturally incoherent.

**Why this is the most dangerous risk:** It produces the appearance of success while delivering none of the value. Metrics look good (artefacts generated, tests passing, features shipped). Quality degrades silently.

**Mitigation:** The adoption path described in [The engineer](the-engineer.md) is intentionally progressive. The method must precede the tooling. Context layer first — no automated implementation, just AI in the IDE getting better answers. Specification as primary artefact — no automated generation, just engineers writing specs with AI assistance. Only after these habits are established does automated implementation add value.

No tooling enforces this. It requires engineering leadership to recognise the difference between AI26 as discipline and AI26 as ceremony, and to name the difference explicitly when it occurs.

**Status:** Not mitigated by tooling. Requires team discipline and leadership awareness.

---

## 6. The context layer as single point of failure

**The risk:** `ai26/context/` files accumulate errors. A single incorrect statement in `ARCHITECTURE.md` — "all state changes are synchronous" when the actual system uses asynchronous events for some transitions — propagates to every feature designed against it. Every AI agent that reads the context inherits the error. The incorrect statement is authoritative because it is in the context layer.

**Why this is hard to prevent:** Context files are maintained by humans under time pressure. Errors are introduced not through carelessness but through imprecision — the statement is true in most cases, but the exception is not documented. The AI reads it as universally true.

**Mitigation:** `ai26-sync-context` detects discrepancies between context files and actual code. Ownership of specific context files is explicit: `ARCHITECTURE.md` is owned by the tech lead; `DOMAIN.md` by PM + tech lead. ADRs are the authoritative source for architectural decisions — context files summarise them; if there is a conflict, the ADR takes precedence.

New engineers reading `ai26/context/` should cross-check claims against the code for the first few months. Discrepancies found during this process should be reported as context drift issues, not silently worked around.

**Status:** Partially mitigated. Ownership and automated drift detection reduce risk. No mechanism prevents subtle imprecision from entering context files.

---

## Summary

| Risk | Severity | Mitigation status |
|---|---|---|
| Loss of code literacy | High, long-term | Partially mitigated — requires culture |
| The lying docstring | Medium | Partially mitigated — requires review discipline |
| Context drift | High | Actively mitigated — automated detection |
| The faithfully wrong implementation | High | Partially mitigated — requires human review |
| Tooling before method | High | Not mitigated by tooling — requires leadership |
| Context as single point of failure | Medium | Partially mitigated — ownership + drift detection |

None of these risks are eliminated. They are managed through a combination of automated gates, review discipline, and team culture. The goal is not a risk-free system — it is a system where risks are **named, visible, and bounded**.

---

*See also: [The engineer](the-engineer.md) — the human responsibilities that make these mitigations work.*
