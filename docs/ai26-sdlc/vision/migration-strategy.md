# Migration Strategy

> Legacy code is not a problem to solve. It is context waiting to be extracted.

---

## The rewrite trap

Every engineering team inherits legacy code. The instinct is to rewrite it — start clean,
apply patterns correctly from the beginning, and free the team from past mistakes.

The instinct is wrong. Big-bang rewrites have a near-universal failure mode: they take
longer than estimated, introduce regressions that the legacy system had worked around,
and produce a codebase that starts accumulating its own debt before the rewrite is even
complete. The team spent 12 months replacing one form of complexity with another.

The root cause is that rewrites throw away implicit knowledge. Legacy code contains
years of business rules, edge case handling, and production-hardened behaviour — none
of it documented, all of it encoded in conditional branches and comment-free service
methods. A rewrite treats this as noise. It is not. It is the most valuable asset in
the codebase, and it needs to be extracted before it can be reimplemented correctly.

---

## The Strangler Fig pattern

AI26 migration follows the Strangler Fig pattern. The new implementation grows alongside
the legacy code — replacing it piece by piece, using the same contracts, until nothing
remains of the original.

```
Legacy service (running in production)
    │
    ├── New aggregate (extracted, designed, tested)
    │       └── Replaces one slice of the legacy service
    │
    ├── New aggregate (extracted, designed, tested)
    │       └── Replaces another slice
    │
    └── ... until legacy code is empty and can be deleted
```

At every point in the migration, the service is running and deployable. There is no
"migration branch" that cannot be merged. Every ticket is a vertical slice of the
migration that ships independently.

The key constraint that makes this safe: **all contracts extracted in Phase 1 are
non-negotiable**. The new implementation must produce the same HTTP responses, publish
to the same event topics with the same payload structure, and read from the same
database schema. Backward compatibility is an invariant, not a goal.

---

## Extract-then-reimplement, not refactor-in-place

The alternative to Strangler Fig is refactoring in place: moving code between packages,
adding interfaces, extracting use cases, all while the file is live in production.

This approach has two problems:

**It is hard to test.** Refactoring a live service class risks breaking the behaviour
you are trying to preserve. Every change is load-bearing until the refactor is complete.
Tests cannot protect you because they were written for the existing structure.

**It does not make context explicit.** The AI26 migration system's secondary goal —
beyond producing correct code — is to extract the implicit knowledge in legacy code
into the context layer (`ai26/context/`). Refactoring in place produces a better-structured
file; it does not produce `DOMAIN.md` entries, ADRs, or a domain model. Extract-then-
reimplement does, because the design conversation (`ai26-write-migration-prd`) forces
the engineer to articulate what the code is actually doing.

---

## How migration compounds knowledge

Each migrated aggregate produces a richer context layer:

| What is extracted | Where it goes |
|---|---|
| Aggregate root + states | `ai26/context/DOMAIN.md` |
| Business rules | `ai26/features/{TICKET}/domain-model.yaml` → promoted |
| API contracts | `ai26/context/INTEGRATIONS.md` |
| Event contracts | `ai26/context/INTEGRATIONS.md` |
| Architectural decisions | `docs/adr/` |
| Technical debt | `ai26/context/DEBT.md` |

After migrating 8 aggregates from a legacy service, the team has a context set that
represents the full domain. Ticket 9 starts with all of that knowledge already loaded.
Without migration, ticket 9 starts from a legacy service where the domain is buried
in Spring annotations and `@Transactional` service methods.

The compound payoff of migration is not just cleaner code — it is knowledge that
persists across engineers, onboarding sessions, and future AI agent invocations.

---

## The three migration patterns

Not all legacy code migrates the same way. AI26 migration recognises three patterns,
applied per aggregate or per concern:

### Strangler Fig (default)

New aggregate coexists with the legacy service. Requests are routed to the new
implementation as each aggregate is complete. Legacy code is deleted at cutover.

**Use when:** The legacy service is large, migration will take multiple sprints, and
the team cannot afford to stop feature development during migration.

### Branch by Abstraction

A port interface is introduced in front of the legacy implementation. The new
implementation satisfies the same port. A feature flag controls which implementation
is active per environment.

**Use when:** The legacy code is tightly woven into surrounding code that cannot
be left untouched, or when a phased rollout per environment is required.

### Expand-Contract (for database schema changes)

Phase 1 (Expand): add new columns/tables alongside existing ones. Both old and new
code run against the expanded schema.
Phase 2 (Contract): remove old columns/tables once all consumers are migrated.

**Use when:** The target domain model requires schema changes but the old schema
must remain functional during migration. Requires coordination across services
that share the schema.

---

## Reference

- [Migration reference](../reference/migration.md) — end-to-end workflow for engineers
- [Assessment format](../reference/migration-assessment-format.md) — assessment.yaml schema
- [Migration recipe](../../coding-standards/recipes/migration.md) — before/after code patterns
- [flows.md — Flow D](../reference/flows.md) — skill sequence and phase overview
