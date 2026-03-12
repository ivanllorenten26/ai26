# Migration Assessment Format

> Reference for `ai26/migrations/{MODULE}/assessment.yaml` — produced by `ai26-assess-module`.

---

## Top-level structure

```yaml
module: {MODULE}
assessed_at: {YYYY-MM-DD}
status: complete          # pending | complete

file_inventory: [...]
api_contracts: [...]
event_contracts: [...]
database_contracts: [...]
external_contracts: [...]
domain_candidates:
  aggregate_roots: [...]
  bounded_contexts: [...]
gaps: [...]
metrics:
  total_files: {N}
  test_files: {N}
  estimated_coverage: {low|medium|high|unknown}
  dependency_health: {healthy|circular_deps_detected|unknown}
```

---

## `file_inventory`

One entry per Kotlin source file in the module.

```yaml
file_inventory:
  - path: src/main/kotlin/de/tech26/valium/ConversationService.kt
    role: service
    notes: "contains state transition logic that belongs in a use case"

  - path: src/main/kotlin/de/tech26/valium/ConversationController.kt
    role: controller
    notes: ~

  - path: src/main/kotlin/de/tech26/valium/ConversationRepository.kt
    role: repository
    notes: ~
```

**`role` values:**

| Value | Detection signal |
|---|---|
| `controller` | `@RestController`, `@Controller`, `@RequestMapping`, `@GetMapping`, etc. |
| `service` | `@Service`, class name ends in `Service` |
| `repository` | `@Repository`, extends `JpaRepository`/`CrudRepository` |
| `entity` | `@Entity`, `@Table`, or `data class` with JPA annotations |
| `dto` | `data class` with no annotations, used as request/response body |
| `listener` | `@KafkaListener`, `@SqsListener`, `@RabbitListener`, `@EventListener` |
| `publisher` | Uses `KafkaTemplate`, `SqsTemplate`, `ApplicationEventPublisher` |
| `config` | `@Configuration`, `@ConfigurationProperties` |
| `filter` | Implements `Filter`, extends `OncePerRequestFilter` |
| `test` | In `test/` or `testFixtures/` source root |
| `other` | Does not match the above signals |

**`notes`:** Optional. Used to flag issues detected during classification (e.g. business
logic in wrong layer). These notes inform the gap entries below.

---

## `api_contracts`

One entry per HTTP endpoint discovered in controller files.

```yaml
api_contracts:
  - path: POST /api/v1/conversations
    controller: ConversationController
    request_body: CreateConversationRequest
    response_body: ConversationResponse
    status_codes: [201, 400, 409]
    auth: bearer
    notes: "409 returned when conversation already exists for session"

  - path: GET /api/v1/conversations/{id}
    controller: ConversationController
    request_body: ~
    response_body: ConversationResponse
    status_codes: [200, 404]
    auth: bearer
    notes: ~
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `path` | `METHOD /path` | HTTP method + path as a single string |
| `controller` | `ClassName` | Source controller class |
| `request_body` | `TypeName \| ~` | Request body type, null if none |
| `response_body` | `TypeName` | Response body type |
| `status_codes` | `[int]` | All HTTP status codes the endpoint can return |
| `auth` | `none \| bearer \| basic \| custom` | Authentication mechanism |
| `notes` | `string \| ~` | Edge cases, caveats, undocumented behaviour |

**These entries are NON-NEGOTIABLE contracts.** The migrated implementation must
return the same status codes for the same conditions, with the same response shape.

---

## `event_contracts`

One entry per Kafka topic or SQS queue the module produces or consumes.

```yaml
event_contracts:
  - direction: outbound
    topic: conversation.v1.created
    payload_type: ConversationCreatedEvent
    consumer_group: ~
    notes: "payload includes full conversation snapshot (ECST pattern)"

  - direction: inbound
    topic: agent.v1.assigned
    payload_type: AgentAssignedEvent
    consumer_group: valium-service
    notes: "DLQ configured: agent.v1.assigned.dlq, max attempts: 3"
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `direction` | `inbound \| outbound` | Whether this module produces or consumes |
| `topic` | `string` | Full topic or queue name |
| `payload_type` | `TypeName` | Kotlin class used as payload |
| `consumer_group` | `string \| ~` | Kafka consumer group, null for SQS/outbound |
| `notes` | `string \| ~` | DLQ config, retry policy, ordering guarantees |

---

## `database_contracts`

One entry per database table the module owns.

```yaml
database_contracts:
  - table: conversations
    entity: ConversationEntity
    columns:
      - name: id
        type: UUID
        nullable: false
      - name: status
        type: VARCHAR(20)
        nullable: false
      - name: created_at
        type: TIMESTAMP WITH TIME ZONE
        nullable: false
      - name: agent_id
        type: UUID
        nullable: true
    relationships:
      - type: one_to_many
        target_table: messages
    flyway_versions: ["V1__create_conversations.sql", "V3__add_agent_id.sql"]
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `table` | `string` | Database table name |
| `entity` | `ClassName` | Legacy JPA entity class |
| `columns` | `[column]` | All columns with type and nullability |
| `relationships` | `[relationship]` | JPA-mapped relationships to other tables |
| `flyway_versions` | `[string]` | Flyway migration files that created/altered this table |

---

## `external_contracts`

One entry per external service the module calls outbound.

```yaml
external_contracts:
  - service: conversation-analysis
    client_class: ConversationAnalysisClient
    base_url_config: services.analysis.url
    endpoints:
      - method: POST
        path: /api/v1/analyses
      - method: GET
        path: /api/v1/analyses/{id}
    retry: true
    timeout_ms: 5000
    notes: "Retrofit interface, @Retry on POST"
```

---

## `domain_candidates`

Inferred domain model from the legacy code — not yet confirmed as the target architecture.

```yaml
domain_candidates:
  aggregate_roots:
    - name: Conversation
      source_class: ConversationEntity
      id_field: id
      states: [PENDING, OPEN, ESCALATED, CLOSED]
      business_rules_found: 4
      notes: "state transition logic split across ConversationService and ConversationController"

    - name: Message
      source_class: MessageEntity
      id_field: id
      states: [SENT, DELIVERED, READ]
      business_rules_found: 1

  bounded_contexts:
    - name: Conversation Management
      classes: [ConversationEntity, ConversationService, ConversationController, MessageEntity]
      rationale: "all classes reference Conversation or Message, no dependencies outside this cluster"

    - name: Agent Assignment
      classes: [AgentAssignmentService, AgentAssignedEventListener]
      rationale: "handles agent lifecycle separately, only joins with Conversation by ID"
```

**`aggregate_roots` fields:**

| Field | Description |
|---|---|
| `name` | Proposed aggregate root name (CamelCase domain term) |
| `source_class` | Legacy class this was inferred from |
| `id_field` | Field used as the identity |
| `states` | State/status values found in the legacy code |
| `business_rules_found` | Count of conditional branches/validations that look like rules |
| `notes` | Observations about where logic is incorrectly placed |

---

## `gaps`

One entry per architectural violation or risk area detected.

```yaml
gaps:
  - type: business_logic_in_controller
    location: ConversationController
    description: "status transition logic inline in POST /api/v1/conversations/close"
    risk: alto

  - type: anemic_domain
    location: ConversationEntity
    description: "pure @Entity data class with no behaviour methods — all logic in service"
    risk: alto

  - type: framework_coupling
    location: ConversationService
    description: "@Autowired and @Value annotations directly in service class"
    risk: medio

  - type: missing_tests
    location: AgentAssignmentService
    description: "no test class found — AgentAssignmentService has 0 test coverage"
    risk: alto

  - type: god_service
    location: ConversationService
    description: "520 lines, 12 injected dependencies"
    risk: medio
```

**`type` values:**

| Value | Meaning |
|---|---|
| `business_logic_in_controller` | Domain logic in `@RestController` methods |
| `missing_tests` | Controller or service with no corresponding test class |
| `framework_coupling` | Spring annotations in classes that should be domain or application layer |
| `circular_deps` | Package A imports from B and B imports from A |
| `implicit_contract` | Endpoint with no Swagger docs, event with untyped payload |
| `anemic_domain` | Entity that holds data but has no behaviour methods |
| `god_service` | Service class >300 lines or >10 injected dependencies |

**`risk` values:**

| Value | Meaning |
|---|---|
| `alto` | Blocks migration — must be addressed in a dedicated ticket |
| `medio` | Should be addressed but can be done alongside adjacent tickets |
| `bajo` | Code smell — note it, clean it up opportunistically |

---

## `metrics`

Aggregate counts for quick health assessment.

```yaml
metrics:
  total_files: 24
  test_files: 9
  estimated_coverage: medium   # low | medium | high | unknown
  dependency_health: healthy   # healthy | circular_deps_detected | unknown
  files_by_role:
    controller: 3
    service: 5
    repository: 4
    entity: 4
    dto: 6
    listener: 1
    publisher: 1
    config: 2
    test: 9
    other: 2
```

**`estimated_coverage`:**

| Value | Meaning |
|---|---|
| `low` | Test files < 30% of total files |
| `medium` | Test files 30–60% of total files |
| `high` | Test files > 60% of total files |
| `unknown` | Could not determine (e.g. tests in a separate module) |

---

## Complete example

A realistic assessment for a small legacy conversation service:

```yaml
module: service
assessed_at: 2026-03-12
status: complete

file_inventory:
  - path: src/main/kotlin/de/tech26/valium/ConversationController.kt
    role: controller
    notes: "contains close() method with state transition logic"
  - path: src/main/kotlin/de/tech26/valium/ConversationService.kt
    role: service
    notes: "god service — 420 lines, 9 injected deps"
  - path: src/main/kotlin/de/tech26/valium/ConversationRepository.kt
    role: repository
    notes: ~
  - path: src/main/kotlin/de/tech26/valium/ConversationEntity.kt
    role: entity
    notes: "anemic — no behaviour methods"
  - path: src/main/kotlin/de/tech26/valium/ConversationCreatedEvent.kt
    role: publisher
    notes: ~

api_contracts:
  - path: POST /api/v1/conversations
    controller: ConversationController
    request_body: CreateConversationRequest
    response_body: ConversationResponse
    status_codes: [201, 400]
    auth: bearer
    notes: ~
  - path: POST /api/v1/conversations/{id}/close
    controller: ConversationController
    request_body: ~
    response_body: ConversationResponse
    status_codes: [200, 404, 409]
    auth: bearer
    notes: "409 if already closed"

event_contracts:
  - direction: outbound
    topic: conversation.v1.created
    payload_type: ConversationCreatedEvent
    consumer_group: ~
    notes: ~

database_contracts:
  - table: conversations
    entity: ConversationEntity
    columns:
      - name: id
        type: UUID
        nullable: false
      - name: status
        type: VARCHAR(20)
        nullable: false
      - name: created_at
        type: TIMESTAMP WITH TIME ZONE
        nullable: false
    relationships: []
    flyway_versions: ["V1__create_conversations.sql"]

external_contracts: []

domain_candidates:
  aggregate_roots:
    - name: Conversation
      source_class: ConversationEntity
      id_field: id
      states: [OPEN, CLOSED]
      business_rules_found: 2
      notes: "close() logic in controller should move to aggregate"
  bounded_contexts:
    - name: Conversation Management
      classes: [ConversationEntity, ConversationService, ConversationController]
      rationale: "single cohesive cluster, no cross-cutting dependencies"

gaps:
  - type: business_logic_in_controller
    location: ConversationController.close()
    description: "state transition guard (throws 409 if already CLOSED) in controller"
    risk: alto
  - type: anemic_domain
    location: ConversationEntity
    description: "pure @Entity, no behaviour — all logic in ConversationService"
    risk: alto
  - type: god_service
    location: ConversationService
    description: "420 lines, 9 injected dependencies"
    risk: medio

metrics:
  total_files: 5
  test_files: 2
  estimated_coverage: low
  dependency_health: healthy
  files_by_role:
    controller: 1
    service: 1
    repository: 1
    entity: 1
    publisher: 1
    test: 2
    other: 0
```

---

## Reference

- [migration.md](migration.md) — end-to-end workflow
- Skill: `ai26-assess-module` — Step 7 is the authoritative source for this format
