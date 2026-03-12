---
name: dev-migrate-to-standard
description: Scans a module's Kotlin files, diagnoses violations of Clean Architecture + DDD patterns, and offers file-by-file fixes. Use when existing code needs to conform to the project's standards.
argument-hint: [module] [optional: --layer domain|application|infrastructure|test]
---

# Migrate to Standard

Scans all Kotlin source files in a module, classifies them by architectural layer, diagnoses
violations of the project's Clean Architecture + DDD patterns, and offers selective file-by-file
fixes. Use when code was written manually or incorrectly by a skill and needs to be brought into
conformance with project standards.

The full check catalogue is defined in `.claude/skills/dev-migrate-to-standard/CHECKS.md`.

---

## Task

Given argument `{MODULE}` (e.g. `conversation`), inspect and optionally fix files in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/` (all subdirectories)
- `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/` (all subdirectories)

An optional `--layer` flag narrows the scope to a single layer:
`domain`, `application`, `infrastructure`, or `test`.

---

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`, `build_command=./gradlew service:compileKotlin`,
`test_command=./gradlew service:test`.

---

## Phase 0 — Pre-flight

1. Verify that `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/` exists; abort with a clear
   message if not.
2. If `--layer` is provided, validate it is one of `domain`, `application`,
   `infrastructure`, or `test`. Abort if not.
3. Print:
   ```
   dev-migrate-to-standard: scanning module {MODULE}
   Source root : {MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/
   Test root   : {TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/
   Scope       : {layer | all layers}
   ```

---

## Phase 1 — Scan and Classify

Recursively list all `.kt` files under the module source and test roots.

Classify each file by its package path:

| Layer class | Package pattern |
|---|---|
| Domain Aggregate | `…​.{module}.domain.{ClassName}` — contains `companion object` |
| Domain Event | `…​.{module}.domain.*Event` or `…​.{module}.domain.*Emitter` (interface) |
| Domain Error | `…​.{module}.domain.errors.*` |
| Application Use Case | `…​.{module}.application.*UseCase` |
| Infrastructure Inbound | `…​.{module}.infrastructure.inbound.*` |
| Infrastructure Outbound | `…​.{module}.infrastructure.outbound.*` |
| BDD Feature Test | `…​.{module}.*FeatureTest` |
| Use Case Test | `…​.{module}.application.*Test` |
| Architecture Test | `…​.{module}.ArchitectureTest` |
| Other Test | `…​.{module}.*Test` outside application/ |

Print a discovery summary:
```
Scan complete:
  domain/               {N} aggregates, {M} error classes
  application/          {N} use cases
  infrastructure/inbound/  {N} controllers
  infrastructure/outbound/ {N} repositories / emitters
  test — BDD feature tests: {N} feature test files
  test — use case:     {N} use case test files

Total: {T} files to diagnose
```

If `--layer` is specified, retain only the files matching that layer and print:
```
Layer filter applied: only {layer} files will be diagnosed
```

---

## Phase 2 — Diagnose

For each file retained from Phase 1, run the checks for its layer as defined in
`.claude/skills/dev-migrate-to-standard/CHECKS.md`.

Classify each check result as:
- **FAIL** — pattern rule is violated and must be fixed
- **WARN** — heuristic concern that may need human review
- **PASS** — check is satisfied

Record results per file as a list of `{ID}: {FAIL|WARN|PASS} — {short reason}` tuples.

---

## Phase 3 — Report

Print the full migration report before asking to fix anything:

```
Migration report for module: {MODULE}
══════════════════════════════════════

Domain Layer
  ✓ Conversation.kt — all checks pass
  ✗ Order.kt
      D01 FAIL — declared as `data class`, must be `class` with private constructor
      D05 FAIL — missing `fun toDTO()`
  ⚠ Product.kt
      D04 WARN — init block present but no require() / check() calls found

Application Layer
  ✗ CreateOrderUseCase.kt
      A01 FAIL — returns `Result<…>` instead of `Either<…,…>`
      A03 WARN — parameter `command: CreateOrderCommand` looks like a Command object

Infrastructure Inbound
  ✓ ConversationController.kt — all checks pass

Infrastructure Outbound
  ✓ InMemoryConversationRepository.kt — all checks pass

BDD Tests
  ✗ CloseConversationSteps.kt
      B01 FAIL — uses @Testcontainers

Use Case Tests
  ✓ CreateConversationUseCaseTest.kt — all checks pass

──────────────────────────────────────
Summary: {T} files scanned
  {F} files with FAIL violations  ({N} FAIL checks)
  {W} files with WARN only         ({M} WARN checks)
  {P} files fully compliant
```

If no violations are found across all files:
```
✓ Module {MODULE} is fully compliant — no violations found.
```
Stop here (skip Phases 4 and 5).

---

## Phase 4 — Interactive Fix

For each file that has at least one **FAIL** check, in the order they appeared in the
report:

1. Print the violations for that file.
2. Show the **diff** of the proposed fix as a fenced diff block.
3. Ask:
   ```
   Fix {FileName}? [y / n / skip-all]
   ```
   - `y` — apply the fix immediately, then continue to the next file.
   - `n` — skip this file; it remains with violations.
   - `skip-all` — stop asking; leave remaining files untouched.

### Fix strategy

Apply **surgical edits**, not regeneration via atomic skills. Rationale: the file may
contain correct business logic that would be lost if regenerated. Only the structural
pattern violation is corrected.

Typical surgical fixes per check:

| Check | Fix |
|---|---|
| D01 | Replace `data class {Name}(` with `class {Name} private constructor(` |
| D02 | Add empty `companion object { fun create(…): {Name} = TODO() }` and note that the developer must implement it |
| D03 | Replace `var ` with `val ` in constructor parameters |
| D04 | Add `init { /* TODO: add invariant validation */ }` block |
| D05 | Add `fun toDTO(): {Name}DTO = TODO("implement toDTO")` stub |
| D06 | Remove offending framework import lines |
| E01 | Replace `sealed interface` or `enum class` with `sealed class` |
| A01 | Replace return type with `Either<{ErrorClass}, {DTO}>` — keep body as-is with TODO |
| A02 | Rename entry method to `operator fun invoke(` |
| A04 | Add missing `@Service` and/or `@Transactional` annotation |
| A05 | Remove infrastructure import lines |
| I01 | Add note: file must be moved to `infrastructure/inbound/` — cannot be fixed in-place |
| O01 | Add note: file must be moved to `infrastructure/outbound/` — cannot be fixed in-place |
| B01 | Add `@Testcontainers` annotation; add `webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT` |
| U03 | Wrap existing assertions with `is Either.Success` / `is Either.Error` destructuring |

For checks that require a file move (I01, O01), print:
```
⚠ {FileName} must be moved to {target-package}.
  Cannot be fixed automatically — move the file manually, then re-run dev-migrate-to-standard.
```
and skip to the next file.

WARN checks are shown in the report but are **not offered for automatic fix**. They are
listed as manual review items at the end.

---

## Phase 5 — Verify

After all fixes are applied, run the build and tests:

```bash
{BUILD_CMD}
{TEST_CMD}
```

If compilation fails:
```
✗ Compilation failed. Error output:
{error excerpt}

Review the changes above and fix manually, then re-run dev-migrate-to-standard {MODULE}.
```

If tests fail:
```
✗ Tests failed. Failing tests:
{test names}

The fixes may have introduced regressions. Review and correct manually.
```

If both pass:
```
✓ Compilation: OK
✓ Tests: OK

Migration complete for module {MODULE}.
  Fixed : {N} files
  Skipped: {M} files
  Remaining violations: {K} (either skipped or require manual moves)
```

List any remaining WARN items:
```
Manual review items (WARN):
  {FileName}: {ID} — {description}
```

Finally, suggest next steps:
```
Next steps:
  If no .features/{TICKET}/ workspace exists:
    /ai26-backfill-user-story {TICKET} in {MODULE}
  If a workspace already exists:
    /ai26-validate-user-story {TICKET}
```

---

## Implementation Rules

- ✅ Read `ai26/config.yaml` → `modules` → active module before resolving any path.
- ✅ Read `.claude/skills/dev-migrate-to-standard/CHECKS.md` for the full check catalogue.
- ✅ Apply surgical edits — never regenerate a file wholesale via an atomic skill.
- ✅ Show a diff before asking the user to approve each fix.
- ✅ WARN checks are reported but never auto-fixed.
- ✅ File-move violations (I01, O01) are reported as manual tasks.
- ✅ Run the build and tests after applying fixes.
- ❌ Do not modify files in `application/` (legacy module) — only `service/`.
- ❌ Do not fix WARN items automatically.
- ❌ Do not run `ai26-validate-user-story` or `ai26-backfill-user-story` automatically — suggest them.
- ❌ Do not modify design artefacts in `.features/{TICKET}/`.

---

## Anti-Patterns

```kotlin
// ❌ Regenerating the whole file instead of a surgical fix
// Bad: deleting Order.kt and running /dev-create-aggregate Order — business logic is lost

// ✅ Surgical fix for D01
// Before:
data class Order(val id: OrderId, val status: OrderStatus)

// After:
class Order private constructor(val id: OrderId, val status: OrderStatus) {
    companion object {
        fun create(id: OrderId, status: OrderStatus): Order = Order(id, status)
    }
}
```

```kotlin
// ❌ Auto-fixing WARN items silently
// A03 WARN: parameter looks like a Command object — fix without asking
// → WARN items require human judgment; never fix them automatically

// ✅ Correct: report WARN in summary and leave for manual review
```

---

## Verification

1. Run Phase 5: `{BUILD_CMD}` and `{TEST_CMD}` both pass.
2. Re-run `dev-migrate-to-standard {MODULE}` — report should show zero FAIL checks.
3. Each fixed file contains only structural changes; business logic is preserved.

## Package Location

Operates on: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/` and `{TEST_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/`
