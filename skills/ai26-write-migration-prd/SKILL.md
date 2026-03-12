---
name: ai26-write-migration-prd
description: Legacy migration Phase 2. Reads the module assessment produced by ai26-assess-module and produces a Migration PRD — the target architecture (bounded contexts, aggregates, use cases) and migration strategy (Strangler Fig, Branch by Abstraction, or Expand-Contract per concern). Requires human architect review and approval before proceeding to decomposition. Use after ai26-assess-module, before ai26-decompose-migration. Invoke as /ai26-write-migration-prd {MODULE}.
argument-hint: "[MODULE] — module name from ai26/config.yaml"
---

# ai26-write-migration-prd

Phase 2 of the legacy migration flow. Takes the raw assessment and proposes the
target Clean Architecture + DDD structure, plus the strategy for getting there safely.

This is a design conversation — the engineer and architect must review and approve
the PRD before decomposition begins. Nothing is written without confirmation.

---

## Step 1 — Load context

Read:
1. `ai26/migrations/{MODULE}/assessment.yaml` — the Phase 1 output
2. `ai26/config.yaml` — stack, module conventions
3. `ai26/context/DOMAIN.md` (if exists) — existing bounded contexts
4. `ai26/context/DECISIONS.md` (if exists) — settled design decisions
5. `ai26/context/DEBT.md` (if exists) — known risky areas
6. `ai26/context/LEARNINGS.md` (if exists) — past migration lessons

If `assessment.yaml` does not exist:

    No assessment found for {MODULE}.
    Run /ai26-assess-module {MODULE} first.

---

## Step 2 — Propose target bounded contexts

Based on `domain_candidates.bounded_contexts` in the assessment, propose how the
legacy module should be decomposed (or kept as one bounded context):

    Proposed bounded context decomposition for {MODULE}:

    Context 1: {ContextName}
      Aggregate roots: {list}
      Rationale: {why these belong together — shared lifecycle, shared invariants}
      Current classes: {list of legacy classes mapping to this context}

    Context 2: {ContextName}
      ...

    Alternative: keep as a single context "{ModuleName}Context"
      Rationale: {if the module is small or tightly coupled}

Ask:

    Does this decomposition make sense? Any boundaries to adjust?
    (You can rename contexts, merge them, or split further.)

Wait for confirmation before proceeding.

---

## Step 3 — Propose target aggregates

For each confirmed bounded context, propose the aggregate structure:

    {ContextName} — proposed aggregates:

    Aggregate: {AggregateName}
      Identity: {AggregateId}(UUID)
      States: {list from assessment}
      Children: {child entities, if any}
      Value objects: {value objects, if any}
      Maps from legacy: {LegacyEntityClass}

    Business rules to preserve (from assessment):
      - {rule description from assessment.gaps / domain_candidates}

    Contracts to preserve (NON-NEGOTIABLE — backward-compatible migration):
      API:      {list endpoints from assessment.api_contracts}
      Events:   {list topics from assessment.event_contracts}
      Database: {list tables from assessment.database_contracts}
              ⚠ Schema changes require Flyway migrations and are high-risk

Ask for corrections before moving on. Emphasise that existing API, event, and database
contracts are constraints — the new implementation must honour them.

---

## Step 4 — Propose target use cases

For each aggregate, identify the business operations from the legacy service layer:

    {AggregateName} — proposed use cases:

    UseCase: {UseCaseName}
      Triggered by: {HTTP endpoint | Kafka event | SQS message}
      Business logic from: {LegacyServiceClass.methodName()}
      Returns: Either<{ErrorType}, {DtoType}>

Ask for corrections. The engineer may know of implicit operations not visible in the code.

---

## Step 5 — Define migration strategy per concern

For each aggregate root, propose the migration pattern:

| Pattern | When to use |
|---|---|
| **Strangler Fig** | New implementation runs alongside legacy. Traffic switches via feature flag or proxy. Legacy deleted after cutover. Safe for APIs with stable contracts. |
| **Branch by Abstraction** | Extract an interface in front of the legacy implementation. Swap in the new implementation behind the interface. No traffic switching needed. Good for internal service boundaries. |
| **Expand-Contract** | For database schema changes: add new columns/tables first (expand), migrate data, switch reads/writes, remove old schema (contract). Required when renaming columns or changing types. |

    Proposed migration pattern per aggregate:

    {AggregateName}
      Pattern: Strangler Fig
      Reason: Has stable REST API; easy to route traffic via feature flag
      Cutover risk: {low|medium|high} — {reason from gaps}

    {AggregateName2}
      Pattern: Branch by Abstraction
      Reason: Internal service dependency, no external API contract
      Cutover risk: {low|medium|high}

Ask for confirmation and adjustments.

---

## Step 6 — Propose migration order

Order the aggregates/use cases by: least coupled first, most tested first, highest
business value first. Explain the ordering.

    Proposed migration order:

    1. {AggregateName} — low risk, has tests, no external deps
    2. {AggregateName2} — depends on #1 for ID references
    3. {AggregateName3} — high risk (no tests, implicit contracts) — last

Explicitly flag high-risk aggregates:

    ⚠ {AggregateName3}: assessment found 0 test coverage and 2 implicit contracts.
    Recommend adding characterisation tests before migrating this aggregate.

---

## Step 7 — Write prd.md

On confirmation of all sections, write `ai26/migrations/{MODULE}/prd.md`:

```markdown
# Migration PRD — {MODULE}

> Generated {DATE} by ai26-write-migration-prd
> Status: approved

## Module overview

{one paragraph: what the legacy module does, from assessment}

## Bounded contexts

### {ContextName}
{description, rationale}

## Target aggregates

### {AggregateName}
- **Identity:** {AggregateId}(UUID)
- **States:** {list}
- **Children:** {list or none}
- **Value objects:** {list or none}
- **Maps from:** {LegacyClass}
- **Migration pattern:** {Strangler Fig | Branch by Abstraction}
- **Cutover risk:** {low | medium | high}

## Target use cases

### {UseCaseName}
- **Aggregate:** {AggregateName}
- **Trigger:** {HTTP endpoint | event}
- **Maps from:** {LegacyServiceClass.method()}

## Contract constraints (NON-NEGOTIABLE)

### API contracts
{list from assessment — must be preserved}

### Event contracts
{list from assessment — topics and payload shapes must be preserved}

### Database contracts
{list from assessment — table names and column types must be preserved
unless an Expand-Contract migration is explicitly planned}

## Migration order

| # | Aggregate/UseCase | Pattern | Risk | Notes |
|---|---|---|---|---|
| 1 | {name} | Strangler Fig | low | |
| 2 | {name} | Strangler Fig | medium | depends on #1 |
| ... | | | | |

## Risks and prerequisites

{list from assessment.gaps, especially alto-risk items}
```

---

## Step 8 — Commit

```
git add ai26/migrations/{MODULE}/prd.md
git commit -m "chore({MODULE}): add migration PRD"
git push
```

---

## Step 9 — Next step

    Migration PRD approved for {MODULE}.

    Next step: /ai26-decompose-migration {MODULE}
