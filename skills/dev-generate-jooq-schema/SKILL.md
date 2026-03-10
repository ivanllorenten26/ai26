````skill
---
name: dev-generate-jooq-schema
description: Regenerates JOOQ type-safe classes from Flyway migrations using the project's code-generation pipeline. Use when you have added or modified a Flyway migration and need fresh JOOQ Table/Record classes before implementing a repository.
argument-hint: [EntityName] in [module] [optional: --from-ticket SXG-1234]
---

# Generate JOOQ Schema

Regenerates JOOQ type-safe Kotlin classes (`Table` + `Record`) from the project's Flyway migrations by running the `persistence:jooqGenerate` Gradle task. The generated files are committed to source control and consumed by JOOQ repository implementations in `service/`.

## How Flyway and jOOQ connect in this project

```
persistence/src/main/resources/db/migration/V{NNN}__*.sql   ← Flyway migrations (source of truth)
              │
              └─ ./gradlew persistence:jooqGenerate
                    │  1. Starts PostgreSQL via TestContainers
                    │  2. Runs all migrations with Flyway
                    │  3. Reads jooq-generator.xml config
                    │  4. Generates Kotlin sources
                    ▼
persistence/src/main/kotlin/de/tech26/valium/persistence/jooq/
        tables/{EntityName}.kt         ← Table DSL class (type-safe column refs)
        tables/records/{EntityName}Record.kt  ← Row record (map to/from domain)
              │
              └─ imported by JOOQ repositories in service/
```

## Configuration

Read `ai26/config.yaml` → `modules` → find `persistence` module for `flyway.migration_root`.
For `base_package`, read from the active module (default: `service`).

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`flyway.migration_root=persistence/src/main/resources/db/migration`.
Fixed values: `{JOOQ_PACKAGE}=de.tech26.valium.persistence.jooq`,
`{JOOQ_SRC}=persistence/src/main/kotlin/de/tech26/valium/persistence/jooq`.

## Task

This skill produces no new source files directly. Instead, it guides you to:

1. Confirm the Flyway migration exists at `{MIGRATION_ROOT}/V{NNN}__{description}.sql`
2. Run the code-generation task
3. Verify the generated output
4. Commit the generated files

The generated artefacts that land on disk are:
- `{JOOQ_SRC}/tables/{EntityName}.kt` — table DSL descriptor
- `{JOOQ_SRC}/tables/records/{EntityName}Record.kt` — row record

## Implementation Rules

### Before running code generation
- ✅ The Flyway migration must exist and be syntactically valid SQL
- ✅ Table name must be self-descriptive snake_case — no module prefix (e.g. `conversation_tag`, `conversation_v2`)
- ✅ Every column must have an explicit `NULL` or `NOT NULL`
- ✅ Enum types must be `CREATE TYPE {entity}_{name} AS ENUM (...)` — never `CHECK` constraints
- ✅ Verify the next version number is sequential (no gaps in `V{NNN}__` prefix)
- ❌ Do not run codegen if any migration has unresolved `-- TODO:` markers

### Running the task
- ✅ Run from the repository root: `./gradlew persistence:jooqGenerate`
- ✅ Requires Docker running locally (the task starts PostgreSQL via TestContainers)
- ✅ The task is idempotent — safe to re-run after migration changes
- ❌ Never edit generated files manually — they are overwritten on every run

### After code generation
- ✅ Commit the generated files together with the migration in the same PR
- ✅ Import table constants via the companion object: `de.tech26.valium.persistence.jooq.tables.{TableClass}.Companion.{TABLE_CONSTANT}` (e.g. `ConversationTag.Companion.CONVERSATION_TAG`)
- ✅ Import record class from `{JOOQ_PACKAGE}.tables.records.{EntityName}Record`
- ❌ Do not add generated source directories (`{JOOQ_SRC}/`) to `.gitignore` — files are version-controlled
- ❌ Do not add JOOQ-generated classes to Detekt analysis (they are already excluded in `build.gradle.kts`)

### Type mapping (Flyway SQL → generated Kotlin)
| SQL type | Generated Kotlin type | Notes |
|---|---|---|
| `UUID` | `UUID` | |
| `TEXT` | `String` | |
| `TIMESTAMPTZ` | `Instant` | via `OffsetDateTimeToInstantConverter` in `jooq-generator.xml` |
| `BOOLEAN` | `Boolean` | |
| `BIGINT` | `Long` | |
| `INTEGER` | `Int` | |
| `NUMERIC` | `BigDecimal` | |
| `TEXT[]` | `Array<String>` | |
| `JSONB` | `JSON` (jOOQ type) | |
| `CREATE TYPE ... AS ENUM` | `String` | No Kotlin enum generated; use `.name` when mapping |

## Example Implementation

### Step 1 — Verify the migration exists

```
{MIGRATION_ROOT}/V046__{description}.sql
```

Example for `ConversationTag` in module `conversation`:

```sql
-- V046__conversation_tag.sql
CREATE TABLE conversation_tag
(
    id              UUID        NOT NULL,
    conversation_id UUID        NOT NULL,
    name            TEXT        NOT NULL,
    created         TIMESTAMPTZ NOT NULL,
    updated         TIMESTAMPTZ NOT NULL,

    CONSTRAINT conversation_tag_pkey PRIMARY KEY (id),
    CONSTRAINT conversation_tag_conversation_id_fk
        FOREIGN KEY (conversation_id) REFERENCES conversation (id)
);
```

### Step 2 — Run code generation

```bash
./gradlew persistence:jooqGenerate
```

Expected output (truncated):

```
> Task :persistence:jooqGenerate
...
[jooq-codegen] Generating tables     : ConversationTag.kt
[jooq-codegen] Generating records    : ConversationTagRecord.kt
BUILD SUCCESSFUL
```

### Step 3 — Verify generated files

After the task succeeds, the following files must exist:

```
{JOOQ_SRC}/tables/ConversationTag.kt
{JOOQ_SRC}/tables/records/ConversationTagRecord.kt
```

Each generated `*Record.kt` exposes one nullable field per column:

```kotlin
// Generated — do NOT edit
class ConversationTagRecord : TableRecordImpl<ConversationTagRecord> {
    var id: UUID?
    var conversationId: UUID?
    var name: String?
    var created: Instant?
    var updated: Instant?
}
```

### Step 4 — Use generated classes in a JOOQ repository

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound

import {BASE_PACKAGE}.{module}.domain.{EntityName}
import {BASE_PACKAGE}.{module}.domain.{EntityName}Id
import {BASE_PACKAGE}.{module}.domain.{EntityName}Repository
import de.tech26.valium.persistence.jooq.tables.{TableClass}.Companion.{TABLE_CONSTANT}  // ← generated
import de.tech26.valium.persistence.jooq.tables.records.{EntityName}Record               // ← generated
import org.jooq.DSLContext
import org.springframework.stereotype.Repository

@Repository  // No @Transactional — belongs on the use case, not the repository
class {EntityName}JooqRepository(
    private val dsl: DSLContext
) : {EntityName}Repository {

    override fun findById(id: {EntityName}Id): {EntityName}? =
        dsl.selectFrom({TABLE_CONSTANT})
            .where({TABLE_CONSTANT}.ID.eq(id.value))
            .fetchOne()
            ?.toDomainEntity()

    override fun save({entity}: {EntityName}): {EntityName} {
        val record = dsl.insertInto({TABLE_CONSTANT})
            .set({TABLE_CONSTANT}.ID, {entity}.id.value)
            .set({TABLE_CONSTANT}.NAME, {entity}.name)
            .set({TABLE_CONSTANT}.CREATED, {entity}.createdAt)
            .set({TABLE_CONSTANT}.UPDATED, {entity}.updatedAt)
            .onDuplicateKeyUpdate()
            .set({TABLE_CONSTANT}.NAME, {entity}.name)
            .set({TABLE_CONSTANT}.UPDATED, {entity}.updatedAt)
            .returning()
            .fetchOne()
            ?: throw IllegalStateException("Failed to save {entity}")

        return record.toDomainEntity()
    }
}

// Record-to-domain mapper — same file, below the repository class
fun {EntityName}Record.toDomainEntity(): {EntityName} = {EntityName}.from(
    id = {EntityName}Id(id!!),
    name = name!!,
    createdAt = created!!,
    updatedAt = updated!!
)
```

### How to reference column constants

The table constant name is the `UPPER_SNAKE_CASE` form of the SQL table name:

| SQL table name | Kotlin import | Column constant |
|---|---|---|
| `conversation_tag` | `import de.tech26.valium.persistence.jooq.tables.ConversationTag.Companion.CONVERSATION_TAG` | `CONVERSATION_TAG.NAME` |
| `conversation_message` | `import de.tech26.valium.persistence.jooq.tables.ConversationMessage.Companion.CONVERSATION_MESSAGE` | `CONVERSATION_MESSAGE.CONTENT` |
| `post_conversation_analysis` | `import de.tech26.valium.persistence.jooq.tables.PostConversationAnalysis.Companion.POST_CONVERSATION_ANALYSIS` | `POST_CONVERSATION_ANALYSIS.STATUS` |

## Anti-Patterns

```kotlin
// ❌ Importing table by constructing the class directly
val CONVERSATION_TAG = ConversationTag("conversation_tag", ...) // wrong

// ✅ Always import via the companion object constant
import de.tech26.valium.persistence.jooq.tables.ConversationTag.Companion.CONVERSATION_TAG   // correct

// ❌ Editing generated files manually
// {JOOQ_SRC}/tables/ConversationTag.kt  ← never edit this

// ❌ Committing migration without regenerating JOOQ classes
// V046__conversation_tag.sql added, but ConversationTag.kt is absent in the PR

// ❌ Reading from a Record field without null-asserting
fun {EntityName}Record.toDomainEntity(): {EntityName} = {EntityName}.from(
    id = {EntityName}Id(id),    // ❌ id is UUID? — must use id!!
    name = name                 // ❌ name is String? — must use name!!
)

// ❌ Using raw SQL strings instead of JOOQ DSL
dsl.fetch("SELECT * FROM conversation_tag WHERE id = ?", id.value)

// ❌ Mapping TIMESTAMPTZ column to OffsetDateTime — always Instant
var created: OffsetDateTime?   // wrong; jooq-generator.xml forces Instant for TIMESTAMPTZ
```

## Verification

```
[ ] Migration file exists at {MIGRATION_ROOT}/V{NNN}__*.sql with sequential version number
[ ] All -- TODO: markers resolved before running codegen
[ ] Docker is running (TestContainers needs it for jooqGenerate)
[ ] ./gradlew persistence:jooqGenerate completes with BUILD SUCCESSFUL
[ ] {JOOQ_SRC}/tables/{EntityName}.kt exists after the task
[ ] {JOOQ_SRC}/tables/records/{EntityName}Record.kt exists after the task
[ ] Repository imports via `{TableClass}.Companion.{TABLE_CONSTANT}` from `de.tech26.valium.persistence.jooq.tables`, not the table class directly
[ ] Record mapper uses !! (non-null assertion) on every record field
[ ] Generated files are staged for commit alongside the migration
[ ] No generated file is listed in .gitignore
```

## Related skills

| Next step | Skill |
|---|---|
| Write the Flyway migration | `dev-create-flyway-migration` |
| Implement the JOOQ repository | `dev-create-jooq-repository` |
| Write integration tests for the repository | `test-create-integration-tests` |
````
