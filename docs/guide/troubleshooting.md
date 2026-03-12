# Troubleshooting

FAQ format. Common failures encountered when using AI26 daily, with exact steps to resolve them. Audience: engineers.

---

## Skill failures

### The skill stops mid-execution and does not resume

**Symptom:** You ran a skill and Claude Code session timed out or was interrupted. Now you do not know where it stopped.

**Resolution:** Re-run the same skill with the same ticket ID. Every AI26 skill is designed to be re-entrant — it detects existing artefacts and partial state, and resumes from the right phase.

```
/ai26-implement-user-story SXG-1234
```

or

```
/ai26-design-epic EPIC-123
```

The skill will report what it found:

```
Resuming from phase 3 — monolithic design (phases 1–2 complete)
```

If the skill does not detect existing state correctly, check whether the artefacts were actually committed before the interruption. If they were not, start the skill from the beginning.

---

### The skill produces output that contradicts our architecture

**Symptom:** The AI generates code or design artefacts that violate team conventions — wrong layer, wrong error type, wrong naming pattern.

**Root cause:** Almost always, the context layer is incomplete or stale. The AI can only follow rules that are explicitly stated in `ai26/context/` or `CLAUDE.md`. If a convention is undocumented, the AI will infer from the existing code — which may itself be inconsistent.

**Resolution:**

1. Identify the specific rule the output violated.
2. Check whether the rule exists in `ai26/context/ARCHITECTURE.md`, `ai26/config.yaml` coding rules, or `CLAUDE.md`.
3. If the rule is missing: add it to the appropriate context file. Then re-run the skill.
4. If the rule exists but was ignored: this is a context quality problem — the rule may be ambiguous or buried. Refine the statement. Make it a prohibition, not a preference. Then re-run.

**Do not manually rewrite the generated output without updating the context.** If you rewrite the output and do not update the context, the same violation will occur in the next session. Fix the context, not the output.

---

### `ai26-implement-user-story` generates code that does not compile

**Symptom:** The agent finishes implementation but `./gradlew service:compileKotlin` fails.

**Resolution:**

1. Read the compiler output carefully.
2. If the error is a missing import or a wrong type: this usually means an artefact references a type that does not exist yet (e.g., a domain event payload type). Check `domain-model.yaml` — the missing type should be there. If it is, re-run the skill and check whether the agent missed a step.
3. If the error is a method signature mismatch: check whether the use case artefact in `use-case-flows.yaml` matches what was generated. If there is a discrepancy, run `/ai26-refine-user-story SXG-1234` to correct the artefact, then re-run the implementation.
4. Run tests to confirm nothing else broke:

```bash
./gradlew service:test
```

---

### `ai26-validate-user-story` reports a blocking violation I cannot resolve

**Symptom:** Validation blocks with an error like "CloseConversation implementation not found" but you can see the implementation in the codebase.

**Resolution:** This is usually a naming mismatch. Validation traces elements by name. Check:

- Use case name in `use-case-flows.yaml`: `CloseConversation`
- Kotlin class name in the codebase: `CloseConversation.kt` (must match exactly)

If the names match and the violation persists, tell the AI to explain:

```
Explain why CloseConversation is flagged as not found
```

The AI will walk through its search logic. You may discover the class is in the wrong package or the file is named differently.

To manually re-run validation after fixing:

```
/ai26-validate-user-story SXG-1234
```

---

## Context problems

### Context has drifted — design conversations produce outdated domain models

**Symptom:** The AI proposes aggregate structures or domain terms that do not match what is actually in the codebase. It may propose creating an aggregate that already exists, or use a term that has been renamed.

**Resolution:**

```
/ai26-sync-context
```

The skill scans the codebase and proposes updates to `ai26/context/` to close the gap. Review each proposed update — accept updates where the context is wrong, reject updates where the code is wrong.

After sync, re-run the failing design step.

**Prevention:** Context drift accumulates when PRs are merged without running `ai26-promote-user-story`. Treat promotion as mandatory, not optional.

---

### `ai26/context/DEBT.md` has an `alto` entry that keeps blocking design conversations

**Symptom:** Every design conversation for tickets near a certain area pauses with a warning about a high-risk debt area.

**This is working as intended.** The `alto` risk level means the area is genuinely dangerous to touch carelessly. The pause is the system protecting you.

**Resolution options:**

1. **Address the debt first.** Use the migration flow to clean up the fragile area before building on top of it:
   ```
   /ai26-assess-module {MODULE}
   /ai26-write-migration-prd {MODULE}
   /ai26-decompose-migration {MODULE}
   ```
2. **Proceed with explicit acknowledgement.** Tell the design skill you are aware of the risk and want to proceed. The skill will ask for explicit confirmation and may add guardrails to the design (e.g., requiring a platform team review before merge).
3. **Change the risk level.** If the debt has been partially addressed and `alto` is no longer accurate, update `ai26/context/DEBT.md` with the current risk level and a note about what changed.

---

### The AI keeps re-debating a settled architectural decision

**Symptom:** During a design conversation, the AI proposes an approach that contradicts a decision already in `ai26/context/DECISIONS.md`.

**Root cause:** The decision entry is either missing, ambiguous, or scoped too narrowly.

**Resolution:**

1. Check `ai26/context/DECISIONS.md` — is the decision actually there?
2. If it is: read the entry. Does it have a `Why` field? Decisions without reasoning are weak — the AI may override them when it infers a "better" answer. Add the reasoning.
3. If the decision applies narrowly: broaden the `Applies to` field.
4. Re-run the design skill. The decision should now be applied as a constraint, not re-debated.

---

## Mid-flow interruptions

### Session interrupted during `ai26-design-epic` — don't know which phase completed

**Resolution:** Re-run the skill. It detects what exists and resumes:

```
/ai26-design-epic EPIC-123
```

The skill checks for:
- `ai26/epics/EPIC-123/prd.md` (phase 1 complete)
- `ai26/epics/EPIC-123/architecture.md` (phase 2 complete)
- `ai26/epics/EPIC-123/design/` directory (phase 3 complete)
- `ai26/features/TBD-N/` directories (phase 4 complete)
- Jira tickets created (phase 5 complete)

It reports which phases are done and starts from the next one.

---

### Session interrupted during `ai26-implement-user-story` — partial code in git

**Resolution:** Check what was committed:

```bash
git log --oneline origin/main..HEAD
```

Identify which subtasks are done. Re-run the implementation skill:

```
/ai26-implement-user-story SXG-1234
```

The skill reads the artefacts, compares them to what is already implemented in the codebase, and generates only what is missing. It will not regenerate code that already exists.

---

## Artefact problems

### Artefacts are wrong — I approved them but now see mistakes

**Resolution:** Use the refine skill to make targeted edits:

```
/ai26-refine-user-story SXG-1234
```

Tell the skill what needs to change: "The error case `AnalysisNotAvailable` should return HTTP 422, not 404" or "The `FetchConversationAnalysis` use case is missing a side effect — it should emit a `AnalysisViewed` event."

The skill updates the affected artefacts and validates cross-references. After refining, re-run implementation for the affected subtask.

---

### Artefacts are missing for a ticket that was already implemented

**Symptom:** Code exists but there are no design artefacts in `ai26/features/{TICKET}/`. This typically happens when code was written without going through the AI26 design phase.

**Resolution:**

```
/ai26-start-sdlc SXG-1234 --backfill
```

or directly:

```
/ai26-backfill-user-story SXG-1234
```

The skill reads the existing code and generates design artefacts from it. Review the generated artefacts carefully — the AI infers intent from code, which may not perfectly reflect original intent.

Use this only as a corrective measure. Routinely skipping the design phase and backfilling afterwards means the Compound Loop is not running.

---

## Validation and promotion blockers

### Validation passes but `ai26-promote-user-story` is blocked

**Symptom:**

```
Promotion blocked — SXG-1234 has unresolved blocking violations.
```

**Resolution:** Re-run validation to see current state:

```
/ai26-validate-user-story SXG-1234
```

Validation may have passed at one point, then a subsequent change broke coherence. Validation is re-checked at the start of every promotion attempt. Resolve the reported violations and retry promotion.

---

### `COMPOUND.md` has pending observations before promotion

**Symptom:** During the promote flow, the AI reports that there are unresolved observations in `COMPOUND.md` (a compound feedback file).

**Resolution:** Read the observations listed. Each one is a pattern identified during the design or implementation phase that should be incorporated into the context before promotion.

The AI will present them for confirmation:

```
Pending observations for context update:

1. Pattern identified: controllers should always emit metrics before returning.
   Proposed addition to ARCHITECTURE.md constraints.
   Apply? [yes / no / defer]

2. Pattern identified: AnalysisNotAvailable should be treated as a 422, not 404.
   Proposed addition to DECISIONS.md.
   Apply? [yes / no / defer]
```

Confirm each observation individually. Deferring is allowed — but deferred observations are recorded and must be acknowledged before the next promotion.

---

### Promotion conflict detected

**Symptom:**

```
Promotion conflict detected:
Conversation.status was modified in this feature (added ESCALATED)
but the module documentation was also updated by SXG-450 (added ARCHIVED).
```

**Resolution:** Read the proposed merged result carefully:

```
Current module states: OPEN, CLOSED, ARCHIVED
This feature adds:     ESCALATED
Merged result would be: OPEN, CLOSED, ARCHIVED, ESCALATED

Is this correct?
```

If the merged result is correct: confirm. If the merge is wrong (e.g., ARCHIVED was from a different aggregate): correct the merge manually by editing the relevant artefact before confirming.

---

## Reference

- [Validation reference](../ai26-sdlc/reference/validation.md) — full validation logic and severity levels
- [Promotion reference](../ai26-sdlc/reference/promotion.md) — what promotion does and where things go
- [Context Files reference](../ai26-sdlc/reference/context-files.md) — format guide for `ai26/context/`
- [Engineer Guide](./engineer-guide.md) — full step-by-step tutorial
- [Glossary](./glossary.md) — context drift, compound step, intention debt definitions
