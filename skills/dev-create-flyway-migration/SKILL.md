---
name: dev-create-flyway-migration
description: Scaffolds a Flyway SQL migration file with TODO markers for human review. Supports CREATE TABLE (from domain model) and ALTER TABLE (add column, index, constraint). Use when a feature needs database schema changes.
argument-hint: [create-table|alter-table] [EntityName] in [module] [optional: with prop1:Type, prop2:Type] [optional: ticket SXG-1234]
---

# Create Flyway Migration

Scaffolds a Flyway SQL migration file with `-- TODO:` markers where human decisions are required.
This skill is a **scaffolder, not a generator** — the output SQL skeleton must be reviewed and completed before use.
Never apply the generated file to a database without reviewing all `-- TODO:` markers.

---

## Configuration

Read `ai26/config.yaml` → `modules` → find `persistence` module.
From that module read `flyway.migration_root`, `flyway.naming_pattern`.
For `base_package`, read from the active module (default: `service`).
For `table_prefix`, read from the target module's `flyway.table_prefix` (null = no prefix).

Fallback: `migration_root=persistence/src/main/resources/db/migration`,
`base_package=de.tech26.valium`.

---

## Sub-pattern decision table

| Sub-pattern | Use when | Arguments |
|---|---|---|
| `create-table` | New aggregate/entity needs a table | Entity name + properties (or reads from `.features/{TICKET}/domain-model.yaml`) |
| `alter-table` | Existing table needs changes (add column, index, constraint, enum value) | Table name + change description |

---

## Task

Generate **1 file**: `{MIGRATION_ROOT}/V{NNN}__{description}.sql`

- Scan existing files in `{MIGRATION_ROOT}/V*.sql` to compute the next version number (max version + 1, zero-padded to 3 digits).
- Write the file with the SQL skeleton and `-- TODO:` markers where decisions are needed.

---

## Implementation Rules

### Always apply

- ✅ Auto-compute next version number by scanning `{MIGRATION_ROOT}/V*.sql` for existing `V{NNN}__` prefixes
- ✅ Table name for an **aggregate root**: `{TABLE_PREFIX}{aggregate_snake_case}` (e.g. `svc_conversation`, `conversation`)
- ✅ Table name for a **child entity**: `{TABLE_PREFIX}{aggregate_snake_case}_{entity_snake_case}` — aggregate root name always leads, preventing intra-module collisions when two aggregates share a conceptually similar child (e.g. `svc_conversation_message` vs `svc_ticket_message`)
- ✅ Enum type name: `{TABLE_PREFIX}{aggregate_snake_case}_{enum_snake_case}` — same aggregate-root-first rule (e.g. `svc_conversation_status`, `conversation_status`)
- ✅ Standard columns on every new table: `id UUID NOT NULL`, `created TIMESTAMPTZ NOT NULL`, `updated TIMESTAMPTZ NOT NULL`
- ✅ Constraint naming convention:
  - Primary key: `{table}_pkey`
  - Foreign key: `{table}_{col}_fk`
  - Unique constraint: `{table}_{cols}_uk`
  - Index: `{table}_{cols}_idx`
- ✅ Every column must have an explicit `NULL` or `NOT NULL`
- ✅ Add `-- TODO:` markers on: nullable decisions, index selection, default values, precision for NUMERIC
- ✅ For `create-table`: read `.features/{TICKET}/domain-model.yaml` if a ticket argument was provided and the file exists; fall back to argument properties
- ✅ For `alter-table` adding an index: always `CREATE INDEX CONCURRENTLY` (never plain `CREATE INDEX`)
- ✅ For `alter-table` adding a NOT NULL column to an existing table: include a `DEFAULT` value for online safety

### Never do

- ❌ Never use `VARCHAR` — always use `TEXT`
- ❌ Never use `TIMESTAMP` — always use `TIMESTAMPTZ`
- ❌ Never use `CHECK` constraints to model enum values — always use `CREATE TYPE ... AS ENUM`
- ❌ Never include ticket numbers in file names (e.g. `V014__SXG_6670_...` is wrong)

---

## Kotlin → SQL type mapping

| Kotlin | PostgreSQL | Notes |
|---|---|---|
| `UUID` | `UUID` | |
| `String` | `TEXT` | Never VARCHAR |
| `Instant` | `TIMESTAMPTZ` | Never TIMESTAMP |
| `Boolean` | `BOOLEAN` | |
| `Long` | `BIGINT` | |
| `Int` | `INTEGER` | |
| `BigDecimal` | `NUMERIC` | `-- TODO: specify precision and scale, e.g. NUMERIC(19, 4)` |
| Enum (states) | `CREATE TYPE {entity}_{name} AS ENUM (...)` | Defined before the table; never CHECK |
| `List<String>` | `TEXT[]` | |
| JSON / Map | `JSONB` | |

---

## Example — CREATE TABLE

Without `tablePrefix` (null — single module or no collision risk):

```sql
-- V047__create_conversation.sql
-- Migration: create conversation table
-- Review all TODO markers before applying.

CREATE TYPE conversation_status AS ENUM (
    'OPEN',
    'CLOSED'
    -- TODO: add additional status values if needed
);

CREATE TABLE conversation (
    id              UUID                NOT NULL,
    customer_id     UUID                NOT NULL,
    subject         TEXT                NOT NULL,
    status          conversation_status NOT NULL DEFAULT 'OPEN',
    -- TODO: decide whether assignee_id should be nullable (NULL = unassigned)
    assignee_id     UUID                NULL,
    created         TIMESTAMPTZ         NOT NULL,
    updated         TIMESTAMPTZ         NOT NULL,

    CONSTRAINT conversation_pkey PRIMARY KEY (id)
    -- TODO: add foreign key on customer_id if customers table exists in this schema
    -- CONSTRAINT conversation_customer_id_fk FOREIGN KEY (customer_id) REFERENCES customer(id)
);

-- TODO: add index on customer_id if queries filter by customer frequently
-- CREATE INDEX CONCURRENTLY conversation_customer_id_idx ON conversation (customer_id);

-- TODO: add index on status if queries filter by status at scale
-- CREATE INDEX CONCURRENTLY conversation_status_idx ON conversation (status);
```

With `tablePrefix: "svc_"` (multi-module project, prefix avoids table name collisions):

```sql
-- V047__create_svc_conversation.sql
-- Migration: create svc_conversation table (module prefix: svc_)
-- Review all TODO markers before applying.

-- Aggregate root table: {TABLE_PREFIX}{aggregate} = svc_conversation
-- Enum type:            {TABLE_PREFIX}{aggregate}_{enum} = svc_conversation_status

CREATE TYPE svc_conversation_status AS ENUM (
    'OPEN',
    'CLOSED'
    -- TODO: add additional status values if needed
);

CREATE TABLE svc_conversation (
    id              UUID                    NOT NULL,
    customer_id     UUID                    NOT NULL,
    subject         TEXT                    NOT NULL,
    status          svc_conversation_status NOT NULL DEFAULT 'OPEN',
    created         TIMESTAMPTZ             NOT NULL,
    updated         TIMESTAMPTZ             NOT NULL,

    CONSTRAINT svc_conversation_pkey PRIMARY KEY (id)
);

-- TODO: add index on customer_id if queries filter by customer frequently
-- CREATE INDEX CONCURRENTLY svc_conversation_customer_id_idx ON svc_conversation (customer_id);
```

Child entity table (child entity `Message` owned by aggregate `Conversation`):

```sql
-- V048__create_svc_conversation_message.sql
-- Migration: create svc_conversation_message table (module prefix: svc_)
-- Child entity table: {TABLE_PREFIX}{aggregate}_{entity} = svc_conversation_message
-- Note: a hypothetical SupportTicket aggregate in the same module would use
--       svc_ticket_message — aggregate name leads, preventing intra-module collision.

CREATE TABLE svc_conversation_message (
    id              UUID        NOT NULL,
    conversation_id UUID        NOT NULL,
    content         TEXT        NOT NULL,
    created         TIMESTAMPTZ NOT NULL,
    updated         TIMESTAMPTZ NOT NULL,

    CONSTRAINT svc_conversation_message_pkey PRIMARY KEY (id),
    CONSTRAINT svc_conversation_message_conversation_id_fk
        FOREIGN KEY (conversation_id) REFERENCES svc_conversation(id)
);

-- CREATE INDEX CONCURRENTLY svc_conversation_message_conversation_id_idx
--     ON svc_conversation_message (conversation_id);
```

---

## Example — ALTER TABLE add column

```sql
-- V048__add_priority_to_conversation.sql
-- Migration: add priority column to conversation
-- Review all TODO markers before applying.

-- TODO: choose the correct default value for existing rows
ALTER TABLE conversation
    ADD COLUMN priority TEXT NOT NULL DEFAULT 'NORMAL';

-- TODO: drop the default after backfill if you do not want a permanent default
-- ALTER TABLE conversation ALTER COLUMN priority DROP DEFAULT;

-- TODO: add index if queries filter or sort by priority
-- CREATE INDEX CONCURRENTLY conversation_priority_idx ON conversation (priority);
```

---

## Example — ALTER TABLE add enum value

```sql
-- V049__add_pending_to_conversation_status.sql
-- Migration: add PENDING value to conversation_status enum
-- IMPORTANT: ALTER TYPE ... ADD VALUE cannot run inside a transaction block.
-- Run this migration with flyway.mixed=true or outside a transaction if your
-- Flyway configuration uses transactions per migration.

ALTER TYPE conversation_status ADD VALUE IF NOT EXISTS 'PENDING';

-- TODO: verify that application code handles PENDING before deploying this migration
```

---

## Anti-patterns

```sql
-- ❌ VARCHAR instead of TEXT
name VARCHAR(255) NOT NULL   -- use TEXT

-- ❌ TIMESTAMP instead of TIMESTAMPTZ
created TIMESTAMP NOT NULL   -- use TIMESTAMPTZ

-- ❌ CHECK for enum values instead of CREATE TYPE
status TEXT CHECK (status IN ('OPEN', 'CLOSED'))   -- use CREATE TYPE ... AS ENUM

-- ❌ Ticket number in file name
V014__SXG_6670_add_liveperson_token_table.sql   -- use V014__add_liveperson_token_table.sql

-- ❌ Missing NULL / NOT NULL
customer_id TEXT   -- always explicit

-- ❌ Plain CREATE INDEX (locks table)
CREATE INDEX conversation_customer_id_idx ON ...   -- use CREATE INDEX CONCURRENTLY

-- ❌ NOT NULL column without DEFAULT on existing table (locks or fails on large tables)
ALTER TABLE conversation ADD COLUMN priority TEXT NOT NULL   -- add DEFAULT
```

---

## Verification checklist

Before committing the generated file, confirm:

```
[ ] File exists at {MIGRATION_ROOT}/V{NNN}__{description}.sql
[ ] Version number is sequential (no gaps, no duplicates)
[ ] File name contains no ticket numbers (e.g. no SXG-1234)
[ ] Table and enum type names include module prefix if tablePrefix is set in ai26/config.yaml
[ ] No VARCHAR — only TEXT
[ ] No TIMESTAMP — only TIMESTAMPTZ
[ ] No CHECK for enum values — CREATE TYPE used instead
[ ] Every column has explicit NULL or NOT NULL
[ ] All TODO markers reviewed and resolved or explicitly accepted
[ ] ALTER TABLE indexes use CREATE INDEX CONCURRENTLY
[ ] NOT NULL ALTER columns include a DEFAULT value
```

---

## File location

`{MIGRATION_ROOT}/` (resolved from `persistence` module `flyway.migration_root` in `ai26/config.yaml`)
```
