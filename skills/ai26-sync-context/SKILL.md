---
name: ai26-sync-context
description: Detects drift between ai26/context/ files and the actual codebase. Scans controllers, aggregates, publishers, and listeners, then compares findings against INTEGRATIONS.md and ai26/domain/ files. Shows a diff of each discrepancy and applies confirmed fixes. Use when you suspect context files are stale, before running ai26-promote-user-story, or as a periodic maintenance check.
argument-hint: [--report] — optional flag to report drift without applying fixes
---

# ai26-sync-context

Detects and fixes drift between the ai26 context files and the actual codebase.
Surgical — it only shows what changed, never rewrites files from scratch.

Two modes:
- **Interactive** (default) — shows each discrepancy, proposes a fix, engineer confirms
- **Report** (`--report`) — shows all discrepancies without writing anything, exits

---

## Step 1 — Load context files

Read all context files silently:

- `ai26/config.yaml` — module list and base packages
- `ai26/context/DOMAIN.md` — bounded contexts, aggregates, ubiquitous language
- `ai26/context/INTEGRATIONS.md` — inbound HTTP, outbound HTTP, events emitted, events consumed, AI/ML, downstream
- `ai26/domain/{module}/*.md` — all aggregate docs

If `ai26/config.yaml` does not exist, stop:

    ai26/config.yaml not found. Run /ai26-onboard-team first.

---

## Step 2 — Scan codebase

For each active module in `ai26/config.yaml`, scan silently:

### Inbound HTTP
- Find all `@RestController` classes
- Extract `@RequestMapping` + `@GetMapping` / `@PostMapping` / `@PutMapping` / `@DeleteMapping` / `@PatchMapping` values
- Extract auth mechanism (look for `@CommonHeaders`, `@RequestHeader`, security annotations)

### Outbound HTTP
- Find all Retrofit `@POST` / `@GET` annotated interfaces, `WebClient`, `FeignClient` usages
- Extract service name (class name or config property), base URL config key, method + path

### Events emitted
- Find all classes extending `AbstractOutboxEventEmitter` — extract the `@param:Value` / `@Value` annotation to get the property key, then resolve the actual topic name from `application.yml` (`kafka.outbox.*` section)
- Find all `KafkaTemplate.send(...)` calls — extract topic and payload type (fallback for services not using the outbox pattern)
- Find all `SqsTemplate.send(...)` calls — extract queue and payload type
- Find all classes that implement an event emitter port (look for `emit(...)` methods)

### Events consumed
- Find all `@KafkaListener` — extract `topics` and handler method name
- Find all `@SqsListener` — extract `queueNames` and handler method name

### AI/ML services
- Find imports or usages of `BedrockRuntimeClient`, `InvokeModelRequest`, `ConverseRequest`
- Find imports or usages of OpenAI, Vertex, or similar AI SDK classes

### Aggregates
- Find classes with `companion object { fun create(` — these are aggregate roots
- For each: extract properties, status enum (if any), domain methods, repository interface

---

## Step 3 — Diff

Compare scan results against context files. For each category, build a list of discrepancies:

### Discrepancy types

| Type | Description |
|---|---|
| `missing_in_context` | Found in code, not in context file |
| `missing_in_code` | In context file, not found in code — may be deleted or renamed |
| `value_mismatch` | Entry exists in both but values differ (e.g. path changed, topic renamed) |
| `status_stale` | Context marks as `in progress` / `TODO` but implementation now exists in code |

Only surface discrepancies. If everything matches, report clean:

    Context sync — all files up to date. No drift detected.

---

## Step 4 — Report

Show a structured report before proposing any fix:

    Context drift report
    ──────────────────────────────────────────────────────────

    INTEGRATIONS.md — 2 discrepancies

      [missing_in_context] Inbound HTTP
        Found in code:   DELETE /api/v2/conversations/{conversationId}
        Not in context:  —

      [status_stale] Events emitted — ConversationCreated
        Context says:    "in progress"
        Found in code:   OutboxConversationEventEmitter extends AbstractOutboxEventEmitter
                         topic = kafka.outbox.conversation-events.topic → "valium.conversation.events.v1"

    ai26/domain/service/conversation.md — 1 discrepancy

      [value_mismatch] properties
        In context:  updatedAt (nullable: true)
        In code:     updatedAt type changed to Instant (non-nullable)

    ──────────────────────────────────────────────────────────
    3 discrepancies found.

If `--report` flag was passed, stop here. Do not propose fixes.

    Run /ai26-sync-context to apply fixes interactively.

---

## Step 5 — Apply fixes interactively

For each discrepancy, propose the minimal fix and wait for confirmation:

    Fix 1 of 3 — INTEGRATIONS.md / Inbound HTTP

    Add entry:
    | DELETE | /api/v2/conversations/{conversationId} | Close a conversation | N26 headers |

    Confirm? [yes / no / edit]

**`edit`** — engineer provides the correct value inline before the fix is applied.

Apply each confirmed fix as a targeted edit to the file — never rewrite the whole file.

For `missing_in_code` discrepancies (entry in context but not in code), ask before removing:

    Fix 2 of 3 — INTEGRATIONS.md / Outbound HTTP

    Entry exists in context but not found in code:
    "IdentityService — GET /agents/{id}"

    Options:
    A. Remove from context (implementation was deleted)
    B. Keep — it exists but wasn't detected (e.g. dynamic call, generated client)
    C. Mark as planned — add a comment that implementation is pending

Wait for engineer's choice before acting.

---

## Step 6 — Commit

After all confirmed fixes are applied:

    Applied 2 of 3 fixes (1 skipped).

    Changes:
      ai26/context/INTEGRATIONS.md — 2 edits
      ai26/domain/service/conversation.md — 0 edits (skipped)

    Commit these changes?

On confirmation:

```
git add ai26/context/
git add ai26/domain/
git commit -m "chore: sync context files with codebase"
git push
```

If no fixes were applied, skip the commit silently.

---

## Integration points

This skill is invoked automatically by `ai26-promote-user-story` at Step 6 (before diagram
regeneration) when a ticket touches integration-relevant code. In that context it runs in
`--report` mode — it surfaces drift but does not apply fixes autonomously. The engineer
decides whether to fix before or after promotion.

It can also be invoked manually at any time:

```
/ai26-sync-context           # interactive — detect and fix
/ai26-sync-context --report  # report only — no writes
```

---

## What this skill does NOT do

- Does not rewrite context files from scratch — use `ai26-onboard-team` for that
- Does not update `DECISIONS.md` or `DEBT.md` — those are not derivable from code
- Does not create new aggregate docs — use `dev-create-aggregate` for new aggregates
- Does not resolve conflicts between two valid states — it surfaces them, the engineer decides
