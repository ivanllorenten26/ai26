# Quick Reference

Daily cheat-sheet. For deep-dives see [Architecture Principles](./architecture-principles.md), [Testing Strategy](./testing-strategy.md), [Project Structure](./project-structure.md), [How-To Cookbook](./how-to.md).

---

## Layer Rules

| Layer | Can import | Cannot import | Permitted annotations |
|---|---|---|---|
| `domain/` | Nothing external | `application/`, `infrastructure/`, any framework | None |
| `application/` | `domain/` | `infrastructure/`, HTTP types, ORM types | `@Service`, `@Transactional` |
| `infrastructure/inbound/` | `application/`, `domain/` | `infrastructure/outbound/` | Full Spring, Swagger/OpenAPI |
| `infrastructure/outbound/` | `application/`, `domain/` | `infrastructure/inbound/` | Full Spring, JOOQ |

Dependencies flow inward: **Infrastructure → Application → Domain**.

Active architecture preset: **hybrid** — domain is framework-free, application allows `@Service` + `@Transactional`, infrastructure has full framework access.

**Infrastructure-to-infrastructure coordination:**
When an operation is pure plumbing with no domain logic (redrives, metrics, health, retries), `inbound/` may call `outbound/` directly without a use case. If domain state or business rules are involved → use case is mandatory. See [Infrastructure Services](./recipes/infrastructure.md#infrastructure-services--when-no-use-case-is-needed).

---

## Naming Conventions

| Type | Pattern | Example |
|---|---|---|
| Aggregate root | `{Name}.kt` | `Conversation.kt` |
| Value object (ID) | `{Name}Id.kt` | `ConversationId.kt` |
| Value object | `{Name}.kt` | `Email.kt`, `Money.kt` |
| Status enum | `{Name}Status.kt` | `ConversationStatus.kt` |
| Repository interface | `{Name}Repository.kt` | `ConversationRepository.kt` |
| Domain error | `{Context}DomainError.kt` | `CloseConversationDomainError.kt` |
| Event sealed class | `{Aggregate}Event.kt` | `ConversationEvent.kt` |
| Event snapshot | `{Aggregate}Snapshot.kt` | `ConversationSnapshot.kt` |
| Domain service | `{Name}.kt` (interface) | `DiscountPolicy.kt` |
| Use case | `{VerbNoun}.kt` | `CloseConversation.kt` |
| Input model | `{VerbNoun}Command.kt` | `CreateConversationCommand.kt` |
| Output model | `{Name}Dto.kt` | `ConversationDto.kt` |
| Controller | `{Name}Controller.kt` | `ConversationController.kt` |
| Request DTO | Nested `RequestDto` inside controller | `ConversationController.RequestDto` |
| Response DTO | Nested `ResponseDto` inside controller | `ConversationController.ResponseDto` |
| JOOQ adapter | `Jooq{Name}Repository.kt` | `JooqConversationRepository.kt` |
| DB table (aggregate root) | `{tablePrefix}{aggregate}` | `svc_conversation`, `conversation` |
| DB table (child entity) | `{tablePrefix}{aggregate}_{entity}` | `svc_conversation_message` |
| DB enum type | `{tablePrefix}{aggregate}_{enum}` | `svc_conversation_status` |
| Event emitter (port) | `{Aggregate}EventEmitter.kt` | `ConversationEventEmitter.kt` |
| Event emitter (impl) | `Outbox{Aggregate}EventEmitter.kt` | `OutboxConversationEventEmitter.kt` |
| Outbox configuration | `OutboxConfiguration.kt` | `OutboxConfiguration.kt` |
| Kafka consumer config | `KafkaConsumerConfiguration.kt` | `KafkaConsumerConfiguration.kt` |
| Kafka consumer | `{Aggregate}EventKafkaConsumer.kt` | `ConversationEventKafkaConsumer.kt` |
| Proto mapper | `{Aggregate}EventProtoMapper.kt` | `ConversationEventProtoMapper.kt` |
| Use case test | `{VerbNoun}UseCaseTest.kt` | `CloseConversationUseCaseTest.kt` |
| Controller test | `{Name}ControllerTest.kt` | `ConversationControllerTest.kt` |
| Integration test | `{Adapter}IntegrationTest.kt` | `JooqConversationRepositoryIntegrationTest.kt` |
| Mother Object | `{Name}Mother.kt` | `ConversationMother.kt` |
| Feature test | `{Name}FeatureTest.kt` | `ConversationFeatureTest.kt` |

**Never use:** `WO` suffix, `VO` suffix, `Impl` suffix (use technology prefix instead).

Package pattern: `de.tech26.valium.{module}.{layer}` — no feature nesting inside packages.

---

## Error Handling

| Situation | Mechanism | Where |
|---|---|---|
| Object invariant (blank name, negative amount) | `require(...)` → `IllegalArgumentException` | `init` block; factory only for transient params not stored in the object |
| Business rule violation the caller must handle | `Either.Error(SealedError)` | Entity business method |
| Entity not found, orchestration error | `Either.Error(UseCaseDomainError)` | Use case |
| Request field missing (`@field:NotBlank`) | `MethodArgumentNotValidException` (Spring auto) | Controller `@Valid` |
| Infrastructure failure (DB down, timeout) | Unchecked exception propagates | `@ControllerAdvice` → 500 |

**Golden rules:**
1. `require` in `init` for object state invariants. Only exception: transient factory parameters not stored in the object.
2. Business methods that can fail return `Either<SealedError, Entity>`.
3. Use cases return `Either<DomainError, DTO>` — never throw for business outcomes.
4. Controllers map `Either.Error` → `ResponseStatusException` directly — no intermediate `ApplicationException`.
5. `PersistenceFailure` is never a sealed error variant — infra failures propagate unchecked.
6. Use case parameters are **primitives only** (`String`, `Int`, `UUID`, `List<String>`) — never domain types, DTOs, or command objects.
7. **Observability lives in infrastructure — never in use cases.** Metrics in controllers, request logs in filters, infra errors in adapters.

---

## Testing

| Layer | Test type | Framework | What to mock | Mandatory? |
|---|---|---|---|---|
| Use case | Unit test | JUnit 5 + MockK + Kotest | Only outbound ports (repositories, emitters) | Yes |
| Controller | `@WebMvcTest` slice | MockMvc + MockK | Only the use case | Yes |
| Repository | Integration test | TestContainers (PostgreSQL) | Nothing — real DB | Yes (if new) |
| Full stack | BDD feature test | JUnit 5 + TestContainers + TestRestTemplate | Nothing | Yes |
| Architecture | ArchUnit | ArchUnit | Nothing | Once per module |

**Key rules:**
- Domain objects are always **real** in tests — never mocked. Use Mother Objects.
- TestContainers PostgreSQL only — never H2.
- Test names follow `` `should <action> when <condition>` `` pattern.

---

## Aggregate Root Shape

```kotlin
class Order private constructor(         // ← private constructor
    val id: OrderId,
    val status: OrderStatus,
    ...
) {
    init { require(...) }                // ← invariants here

    fun confirm(): Either<ConfirmError, Order> { ... }  // ← returns Either, not throws
    fun toDTO(): OrderDTO = ...

    private fun copy(...) = Order(...)   // ← private copy, no data class

    companion object {
        fun create(...): Order = ...     // ← factory method
        fun from(...): Order = ...       // ← rehydration from DB
    }
}
```

**Never** `data class` for aggregate roots — exposes `copy()` which bypasses invariants.

---

## Use Case Shape

```kotlin
@Service
@Transactional
class CloseConversation(
    private val repository: ConversationRepository  // ← port, not implementation
) {
    operator fun invoke(conversationId: UUID): Either<CloseDomainError, ConversationDTO> {
        val id = ConversationId(conversationId)
        val conversation = repository.findById(id)
            ?: return Either.Error(CloseDomainError.NotFound(id))

        return conversation.close()
            .map { repository.save(it).toDTO() }
    }
}
```

`@Transactional` belongs here — never on repositories or controllers.

---

## Controller Shape

The controller, its request DTO, and its response DTO all live in the **same file** as **nested classes**. This keeps names short (`RequestDto`, `ResponseDto`) and scopes them naturally (`CreateConversationController.RequestDto`). Use `@Schema(title = "...")` so Swagger shows a human-readable name instead of the nested class path.

```kotlin
@RestController
@RequestMapping("/api/v1/conversations")
class ConversationController(
    private val closeConversation: CloseConversation,
    private val metrics: MetricService          // ← observability belongs here
) {

    @PutMapping("/{id}/close")
    @Operation(summary = "Close a conversation")
    fun close(@PathVariable id: UUID): ResponseEntity<ResponseDto> =
        when (val result = closeConversation(id)) {
            is Either.Success -> {
                metrics.increment("conversation.close.success")
                ResponseEntity.ok(ResponseDto.from(result.value))
            }
            is Either.Error -> {
                metrics.increment("conversation.close.failure")
                throw result.value.toResponseStatusException()
            }
        }

    // ← DTOs are nested inside the controller — never in separate files
    @Schema(title = "CloseConversationResponse")
    data class ResponseDto(val id: String, val status: String) {
        companion object {
            fun from(dto: ConversationDTO): ResponseDto = ResponseDto(dto.id, dto.status)
        }
    }
}
```

Controllers are humble objects — zero business logic. Only: deserialize → call use case → serialize + metrics.

**Never** put request/response DTOs in separate files — nesting them inside the controller scopes them to their only consumer.

---

## Domain Events

Pattern: **Event-Carried State Transfer (ECST)** — every event carries a full aggregate snapshot.

| Concept | Implementation | Location |
|---|---|---|
| Event hierarchy | `sealed class {Aggregate}Event` | `domain/events/` |
| Event variant | `data class Created : {Aggregate}Event()` | Nested inside sealed class |
| Snapshot | `data class {Aggregate}Snapshot` (primitives only) | `domain/events/` |
| Emitter port | `interface {Aggregate}EventEmitter` | `domain/events/` |
| Emitter impl | `Outbox{Aggregate}EventEmitter` | `infrastructure/outbound/` |
| Outbox config | `OutboxConfiguration` | `infrastructure/outbound/` |
| Proto mapper | `{Aggregate}EventProtoMapper` | `infrastructure/outbound/` |
| Consumer config | `KafkaConsumerConfiguration` | `infrastructure/inbound/` |
| Consumer | `{Aggregate}EventKafkaConsumer` | `infrastructure/inbound/` |

**Key rules:**
- One sealed class per aggregate, one emitter per aggregate
- Snapshot = primitives only (`UUID`, `String`, `Instant`) — no domain types
- Aggregate builds snapshot: `entity.toSnapshot()`
- Save first, then emit via **transactional outbox** — both writes in same DB transaction
- Kafka topic: `{service}.{aggregate}.events.v{version}` — partition key = aggregate ID
- Emitters return `Unit` — outbox write cannot fail independently of the transaction
- Consumer: `@KafkaListener` + `DefaultErrorHandler` + backoff + parking lot
- Wire format: Protobuf via `n26/argon`
- Deserialization: `KafkaProtoDeserializerBuilder` (N26 Kafka Starter) or manual `parseFrom`

Full reference: [Domain Events — ECST Pattern](./domain-events.md) · [Domain Events Recipe](./recipes/domain-events.md) · [Proto Appendix](./domain-events-proto-appendix.md)

---

## Persistence

We use **JOOQ** for all persistence. JOOQ generates type-safe Kotlin classes from the database schema. Repository adapters inject `DSLContext` and use private extension functions (`toDomain()`, `toJooq()`) for mapping.

### Table naming

| Entity type | Pattern | Example (no prefix) | Example (`tablePrefix: "svc_"`) |
|---|---|---|---|
| Aggregate root | `{tablePrefix}{aggregate}` | `conversation` | `svc_conversation` |
| Child entity | `{tablePrefix}{aggregate}_{entity}` | `conversation_message` | `svc_conversation_message` |
| Enum type | `{tablePrefix}{aggregate}_{enum}` | `conversation_status` | `svc_conversation_status` |

**Rules:**
- The aggregate root name **always leads** — prevents intra-module collisions when two aggregates share a conceptually similar child (e.g. `conversation_message` vs `ticket_message`).
- `tablePrefix` is set per module in `ai26/config.yaml` under `flyway.tablePrefix`. Null means no prefix — correct for single-module projects or modules with disjoint table names.
- `tablePrefix` applies to every `CREATE TABLE` and `CREATE TYPE` generated by that module.

---

Standards apply to the `service/` module. The legacy `application/` module coexists — do not modify it unless explicitly asked.