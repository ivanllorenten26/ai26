---
name: ai26-assess-module
description: Legacy migration Phase 1. Scans a legacy Spring Boot module top-to-bottom, classifies every file by its actual role, extracts API/event/database/external contracts, discovers domain concepts hidden in raw code, and identifies gaps and risks. Produces ai26/migrations/{MODULE}/assessment.yaml. Use as the mandatory first step before ai26-write-migration-prd when adopting AI26 on an existing service. Invoke as /ai26-assess-module {MODULE}.
argument-hint: "[MODULE] — module name from ai26/config.yaml (e.g. service, application)"
---

# ai26-assess-module

Phase 1 of the legacy migration flow. Reads raw legacy code and produces a structured
understanding of what exists — without assuming Clean Architecture or DDD are already present.

The output (`assessment.yaml`) feeds into `/ai26-write-migration-prd` to produce the
target architecture and migration strategy.

---

## Step 1 — Resolve module

Read `ai26/config.yaml`. Locate the module named `{MODULE}`.

Extract:
- `path` — root directory of the module (e.g. `application/`)
- `base_package` — root Kotlin package
- `main_source_root` — source root

If `{MODULE}` was not provided, list all modules from config and ask which one to assess.

If the module has `migration_status: completed`, warn:

    This module has already been fully assessed and migrated.
    Run anyway? [yes / no]

---

## Step 2 — Scan all source files

Scan every Kotlin file under `{main_source_root}`. For each file, classify its **actual role**
based on content — not package name (legacy code often has wrong package structure):

| Role | Detection signals |
|---|---|
| `controller` | `@RestController`, `@Controller`, `@RequestMapping`, `@GetMapping`, etc. |
| `service` | `@Service`, class name ends in `Service` |
| `repository` | `@Repository`, extends `JpaRepository`/`CrudRepository`, `@Query` |
| `entity` | `@Entity`, `@Table`, or `data class` with JPA annotations |
| `dto` | `data class` with no annotations, used as request/response |
| `listener` | `@KafkaListener`, `@SqsListener`, `@RabbitListener`, `@EventListener` |
| `publisher` | uses `KafkaTemplate`, `SqsTemplate`, `ApplicationEventPublisher` |
| `config` | `@Configuration`, `@ConfigurationProperties`, `SecurityConfig`, etc. |
| `filter` | `implements Filter`, `OncePerRequestFilter`, `@Component` with `doFilter` |
| `test` | in `test/` or `testFixtures/` source root |
| `other` | anything that doesn't match the above |

Produce a summary during the scan:

    Scanning {MODULE} module...
    Found {N} Kotlin files.

    Controllers:   {N}
    Services:      {N}
    Repositories:  {N}
    Entities:      {N}
    DTOs:          {N}
    Listeners:     {N}
    Publishers:    {N}
    Config:        {N}
    Tests:         {N}
    Other:         {N}

---

## Step 3 — Extract contracts

### API contracts (from controllers)

For each controller file, extract:
- HTTP method + path (from mapping annotations)
- Request body type and fields
- Response type, fields, and HTTP status codes
- Authentication/authorisation signals (`@PreAuthorize`, `@Secured`, security filters)
- Swagger/OpenAPI annotations if present (`@Operation`, `@ApiResponse`)

### Event contracts (from listeners and publishers)

For each listener/publisher, extract:
- Topic or queue name
- Payload type and fields
- Consumer group (if Kafka)
- Error handling (DLQ, retry config)

### Database contracts (from entities and repositories)

For each entity, extract:
- Table name (from `@Table` or inferred from class name)
- Columns and types (from fields and `@Column`)
- Relationships (`@OneToMany`, `@ManyToOne`, etc.)
- Indexes and constraints (`@Index`, `@UniqueConstraint`)

Scan Flyway/Liquibase migration files if present:
- List migration versions and descriptions

### External service contracts (from HTTP clients)

For each HTTP client (Retrofit interfaces, `WebClient`, `FeignClient`, `RestTemplate` usage):
- Base URL or service name
- Endpoints called (method + path)
- Request/response types
- Retry and timeout configuration

---

## Step 4 — Discover domain concepts

From the classified files, infer what domain the code is actually modelling:

**Entities with identity and lifecycle:**
- Any class with an ID field + a status/state field is a candidate aggregate root
- List: class name, ID type, states/transitions found

**Business rules:**
- Validation logic in service classes (conditional branches, `if (x) throw`)
- State transition guards
- Calculation logic (pricing, scoring, eligibility)

**Ubiquitous language:**
- Recurring domain terms in class/method/field names
- Business event names (e.g. `OrderPlaced`, `PaymentFailed`)
- Domain-specific enums

**Bounded context candidates:**
- Clusters of classes that reference each other but have few dependencies on other clusters
- Name each candidate with a proposed bounded context name

---

## Step 5 — Identify gaps and risks

| Gap type | Detection |
|---|---|
| Business logic in controllers | Service calls inside controller methods beyond simple delegation |
| Missing test coverage | Controllers with no corresponding test class |
| Framework coupling | Spring annotations (`@Autowired`, `@Value`) inside classes classified as `service` |
| Circular dependencies | Package A imports from B and B imports from A |
| Implicit contracts | Endpoints undocumented in Swagger, event payloads not typed |
| Anemic domain | Entities that are pure data holders with no behaviour methods |
| God services | Service class > 300 lines or > 10 injected dependencies |

---

## Step 6 — Human review

Surface findings before writing:

    Assessment summary for {MODULE}
    ──────────────────────────────────────────────────

    Files scanned: {N}

    Contracts extracted:
      API:       {N} endpoints across {N} controllers
      Events:    {N} topics ({N} published, {N} consumed)
      Database:  {N} tables, {N} entities
      External:  {N} outbound service clients

    Domain candidates:
      Aggregate roots: {list names}
      Bounded contexts: {list candidate names}
      Business rules found: {N}

    Gaps and risks:
      ⚠ Business logic in controllers: {N} controllers affected
      ⚠ Missing test coverage: {N} endpoints with no tests
      ⚠ Anemic domain objects: {N} entities
      ⚠ Framework coupling in services: {N} occurrences

    Does this look accurate? Corrections before I write assessment.yaml?

Wait for confirmation. Apply any corrections the engineer provides.

---

## Step 7 — Write assessment.yaml

Write `ai26/migrations/{MODULE}/assessment.yaml`:

```yaml
# ai26/migrations/{MODULE}/assessment.yaml
# Generated by ai26-assess-module — {DATE}

module: {MODULE}
assessed_at: {DATE}
status: complete  # pending | complete

file_inventory:
  - path: {file_path}
    role: {controller|service|repository|entity|dto|listener|publisher|config|test|other}
    notes: {optional — e.g. "contains business logic that belongs in a use case"}

api_contracts:
  - path: {HTTP_METHOD} {path}
    controller: {ClassName}
    request_body: {TypeName or null}
    response_body: {TypeName}
    status_codes: [{200}, {201}, {400}, {404}]
    auth: {none|bearer|basic|custom}
    notes: {optional}

event_contracts:
  - direction: {inbound|outbound}
    topic: {topic_name}
    payload_type: {TypeName}
    consumer_group: {group or null}
    notes: {optional}

database_contracts:
  - table: {table_name}
    entity: {ClassName}
    columns:
      - name: {column_name}
        type: {sql_type}
        nullable: {true|false}
    relationships:
      - type: {one_to_many|many_to_one|many_to_many}
        target_table: {table_name}

external_contracts:
  - service: {service_name}
    client_class: {ClassName}
    endpoints:
      - method: {HTTP_METHOD}
        path: {path}
    retry: {true|false}
    timeout_ms: {N or null}

domain_candidates:
  aggregate_roots:
    - name: {CandidateName}
      source_class: {ClassName}
      id_field: {field_name}
      states: [{state1}, {state2}]
      business_rules_found: {N}
  bounded_contexts:
    - name: {ContextName}
      classes: [{ClassName1}, {ClassName2}]
      rationale: {why these belong together}

gaps:
  - type: {business_logic_in_controller|missing_tests|framework_coupling|circular_deps|implicit_contract|anemic_domain|god_service}
    location: {ClassName or file path}
    description: {what was found}
    risk: {alto|medio|bajo}

metrics:
  total_files: {N}
  test_files: {N}
  estimated_coverage: {low|medium|high|unknown}
  dependency_health: {healthy|circular_deps_detected|unknown}
```

---

## Step 8 — Update config.yaml

Add `migration_status: in_progress` to the module entry in `ai26/config.yaml`:

```yaml
modules:
  - name: {MODULE}
    migration_status: in_progress
    migration_plan: ai26/migrations/{MODULE}/plan.md
```

Show the diff before writing. Only modify the target module entry.

---

## Step 9 — Commit

```
mkdir -p ai26/migrations/{MODULE}
git add ai26/migrations/{MODULE}/assessment.yaml
git add ai26/config.yaml
git commit -m "chore({MODULE}): add migration assessment"
git push
```

---

## Step 10 — Next step

    Assessment complete for {MODULE}.
    {N} files classified, {N} contracts extracted, {N} gaps identified.

    Next step: /ai26-write-migration-prd {MODULE}
