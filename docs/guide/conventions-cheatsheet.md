# Conventions Cheatsheet

Single-page reference for every coding rule, naming convention, error handling decision, and testing decision. Derived from `ai26/config.yaml` coding rules and `docs/coding-standards/`. Audience: engineers writing code.

---

## Layer Rules

Dependencies flow inward: **Infrastructure → Application → Domain**

| Layer | Path | Can depend on | Cannot depend on | Permitted annotations |
|---|---|---|---|---|
| `domain/` | `…/domain/` | Nothing | application/, infrastructure/, any framework | None |
| `application/` | `…/application/` | domain/ | infrastructure/, HTTP types, ORM types | `@Service`, `@Transactional` |
| `infrastructure/inbound/` | `…/infrastructure/inbound/` | application/, domain/ | infrastructure/outbound/ | Full Spring, Swagger/OpenAPI |
| `infrastructure/outbound/` | `…/infrastructure/outbound/` | application/, domain/ | infrastructure/inbound/ | Full Spring, JOOQ |

**Never:** flat classes in `infrastructure/` — everything must be in `inbound/` or `outbound/`.

---

## Clean Architecture Rules (CC)

| ID | Rule |
|---|---|
| CC-01 | Domain layer: zero framework imports — `org.springframework.*`, `jakarta.*`, `org.jooq.*` are all forbidden |
| CC-02 | Infrastructure classes in `inbound/` or `outbound/` — nothing flat under `infrastructure/` |
| CC-03 | Use `Either` from `de.tech26.valium.shared.kernel` — never `kotlin.Result`, never `arrow.core.Either` |
| CC-04 | Repository and emitter port signatures: plain return types. Nullable for not-found, throws for infra. Never `Either` on port signatures |
| CC-05 | DTO fields: primitives only (`String`, `Int`, `Long`, `Boolean`, `Double`). `UUID→String`, `Instant→String`, `enum→String(.name)` |

---

## Domain Rules (D)

| ID | Rule |
|---|---|
| D-01 | Aggregate root: `class` with private constructor — NOT `data class` |
| D-02 | `companion object` with `create()` for new instances, `from()` for DB rehydration |
| D-03 | `init` block with `require()` for constructor invariants only |
| D-04 | Mutations return new instances via private `copy()` — no `var`, no public setters |
| D-05 | Business methods that can fail return `Either<SealedError, Aggregate>` — never throw |
| D-06 | Sealed error classes nested inside the aggregate |
| D-07 | `toDTO()` for boundary crossing, `toSnapshot()` for domain events |
| D-08 | ID value object: `data class {Name}Id(val value: UUID)` — NOT `@JvmInline value class` |
| D-09 | ID factory method: `random()` — NOT `new()`, NOT `generate()` |
| D-10 | ID has `fromString(raw: String)` for parsing from HTTP/SQS input |
| D-11 | Single-field non-ID value objects: `@JvmInline value class`. Multi-field or IDs: `data class` |
| D-12 | Status enum has behaviour methods — `isActive()`, `canBeCancelled()` — not just constants |
| D-13 | Cross-aggregate references by ID only — never embed another aggregate |
| D-14 | One `Repository` per aggregate root |

---

## Application Rules (A)

| ID | Rule |
|---|---|
| A-01 | Use case returns `Either<SealedError, DTO>` — never raw domain entities |
| A-02 | Entry point: `operator fun invoke()` with primitive parameters — no Command/DTO input objects |
| A-03 | Annotate use cases with `@Service` and `@Transactional` |
| A-04 | One aggregate per transaction |
| A-05 | No infrastructure imports in use cases |
| A-06 | No `try/catch` for expected business outcomes — use `Either` from domain methods |

---

## Infrastructure Rules (I)

| ID | Rule |
|---|---|
| I-01 | Controllers are humble objects — delegate to use case, zero business logic |
| I-02 | Controllers fold `Either` directly — map `Error` to `ResponseStatusException` |
| I-03 | Request bodies have bean validation annotations (`@field:NotBlank`, `@field:Min`, etc.) |
| I-04 | Outbound adapters: implementation prefix (Jooq, Kafka, Http, Stub, InMemory, Logging) |
| I-05 | Outbound adapters: `runCatching` for infrastructure errors |
| I-06 | Outbound adapters: `@Retry` where appropriate |

---

## Testing Rules (T)

| ID | Rule |
|---|---|
| T-01 | TestContainers only — never H2 |
| T-02 | Mock only outbound ports — never domain entities or value objects |
| T-03 | Mother Objects for test data — no inline construction in test bodies |
| T-04 | `// Scenario:` docstring on every `@Test` method |
| T-05 | Feature tests: `@SpringBootTest(RANDOM_PORT)` + `TestRestTemplate`, NOT MockMvc |
| T-06 | Feature tests: inject real repository adapter, NOT InMemory fakes |
| T-07 | Controller tests and feature tests are mandatory |
| T-08 | `@BeforeEach` cleans DB state in feature tests |

---

## Naming Conventions

| Type | Pattern | Example |
|---|---|---|
| Aggregate root | `{Name}.kt` | `Conversation.kt` |
| ID value object | `{Name}Id.kt` | `ConversationId.kt` |
| Value object | `{Name}.kt` | `Email.kt`, `Money.kt` |
| Status enum | `{Name}Status.kt` | `ConversationStatus.kt` |
| Repository interface | `{Name}Repository.kt` | `ConversationRepository.kt` |
| Domain error | `{Context}DomainError.kt` | `CloseConversationDomainError.kt` |
| Event sealed class | `{Aggregate}Event.kt` | `ConversationEvent.kt` |
| Event snapshot | `{Aggregate}Snapshot.kt` | `ConversationSnapshot.kt` |
| Use case | `{VerbNoun}.kt` | `CloseConversation.kt` |
| Use case input | `{VerbNoun}Command.kt` | `CreateConversationCommand.kt` |
| Use case output | `{Name}Dto.kt` | `ConversationDto.kt` |
| Controller | `{Name}Controller.kt` | `ConversationController.kt` |
| Controller request DTO | Nested `RequestDto` inside controller | `ConversationController.RequestDto` |
| Controller response DTO | Nested `ResponseDto` inside controller | `ConversationController.ResponseDto` |
| JOOQ repository adapter | `Jooq{Name}Repository.kt` | `JooqConversationRepository.kt` |
| DB table (aggregate root) | `{tablePrefix}{aggregate}` | `svc_conversation` |
| DB table (child entity) | `{tablePrefix}{aggregate}_{entity}` | `svc_conversation_message` |
| DB enum type | `{tablePrefix}{aggregate}_{enum}` | `svc_conversation_status` |
| Event emitter port | `{Aggregate}EventEmitter.kt` | `ConversationEventEmitter.kt` |
| Event emitter impl | `Outbox{Aggregate}EventEmitter.kt` | `OutboxConversationEventEmitter.kt` |
| Use case test | `{VerbNoun}UseCaseTest.kt` | `CloseConversationUseCaseTest.kt` |
| Controller test | `{Name}ControllerTest.kt` | `ConversationControllerTest.kt` |
| Integration test | `{Adapter}IntegrationTest.kt` | `JooqConversationRepositoryIntegrationTest.kt` |
| Mother Object | `{Name}Mother.kt` | `ConversationMother.kt` |
| Feature test | `{Name}FeatureTest.kt` | `ConversationFeatureTest.kt` |

**Never use:** `WO` suffix, `VO` suffix, `Impl` suffix (use technology prefix instead).

Package pattern: `de.tech26.valium.{module}.{layer}` — no feature nesting inside packages.

---

## Error Handling Decision Table

| Situation | Mechanism | Location |
|---|---|---|
| Object invariant violated (blank name, negative amount) | `require(...)` → `IllegalArgumentException` | `init` block in aggregate/value object |
| Business rule violation the caller must handle | `Either.Error(SealedError)` | Entity business method |
| Entity not found, orchestration error | `Either.Error(UseCaseDomainError)` | Use case |
| Request field missing or invalid | `MethodArgumentNotValidException` (Spring `@Valid`) | Controller `@Valid` annotation |
| Infrastructure failure (DB down, timeout) | Unchecked exception propagates | `@ControllerAdvice` → 500 |

**Golden rules:**
1. `require` in `init` for object state invariants. Exception: transient factory parameters not stored in the object.
2. Business methods that can fail return `Either<SealedError, Entity>`. Never throw for business outcomes.
3. Use cases return `Either<DomainError, DTO>`.
4. Controllers fold `Either.Error` → `ResponseStatusException`. No intermediate `ApplicationException`.
5. `PersistenceFailure` is never a sealed error variant — infra failures propagate unchecked.
6. Use case parameters are primitives only — never domain types, DTOs, or Command objects.
7. Observability (metrics, logs) lives in infrastructure — never in use cases.

---

## Testing Decision Table

| Layer | Test type | Framework | What to mock | Mandatory? |
|---|---|---|---|---|
| Use case | Unit test with Gherkin docstrings | JUnit 5 + MockK + Kotest | Only outbound ports (repositories, emitters) | Yes |
| Controller | `@WebMvcTest` slice | MockMvc + MockK | Only the use case | Yes |
| Repository | Integration test | TestContainers (PostgreSQL) | Nothing — real DB | Yes (if new repository) |
| Full stack | BDD feature test | JUnit 5 + TestContainers + TestRestTemplate | Nothing | Yes |
| Architecture | ArchUnit | ArchUnit | Nothing | Once per module |

**Key rules:**
- Domain objects are always **real** in tests — never mocked. Use Mother Objects.
- TestContainers PostgreSQL only — never H2.
- Test names: `` `should <action> when <condition>` `` pattern.

---

## Aggregate Root Shape

```kotlin
class Conversation private constructor(    // private constructor — D-01
    val id: ConversationId,
    val status: ConversationStatus
) {
    init { require(status != ConversationStatus.UNKNOWN) { "..." } }  // D-03

    fun close(): Either<CloseDomainError, Conversation> {             // D-05
        if (status == ConversationStatus.CLOSED)
            return Either.Error(CloseDomainError.AlreadyClosed(id))
        return Either.Success(copy(status = ConversationStatus.CLOSED))
    }

    fun toDTO(): ConversationDTO = ConversationDTO(id.value.toString(), status.name)  // D-07

    private fun copy(status: ConversationStatus) = Conversation(id, status)  // D-04

    companion object {
        fun create(id: ConversationId): Conversation = Conversation(id, ConversationStatus.OPEN)  // D-02
        fun from(id: ConversationId, status: ConversationStatus): Conversation = Conversation(id, status)
    }
}

data class ConversationId(val value: UUID) {       // D-08
    companion object {
        fun random() = ConversationId(UUID.randomUUID())  // D-09
        fun fromString(raw: String) = ConversationId(UUID.fromString(raw))  // D-10
    }
}
```

---

## Use Case Shape

```kotlin
@Service
@Transactional                                  // A-03
class CloseConversation(
    private val repository: ConversationRepository  // port, not implementation — A-05
) {
    operator fun invoke(                            // A-02
        conversationId: String                      // primitive parameter — A-02
    ): Either<CloseDomainError, ConversationDTO> {  // A-01
        val id = ConversationId.fromString(conversationId)
        val conversation = repository.findById(id)
            ?: return Either.Error(CloseDomainError.NotFound(id))
        return conversation.close()
            .map { updated -> repository.save(updated).toDTO() }
    }
}
```

---

## Controller Shape

```kotlin
@RestController
@RequestMapping("/api/v1/conversations")
class ConversationController(
    private val closeConversation: CloseConversation
) {
    @PutMapping("/{id}/close")
    fun close(@PathVariable id: String): ResponseEntity<ResponseDto> =
        when (val result = closeConversation(id)) {         // I-01: delegate only
            is Either.Success -> ResponseEntity.ok(ResponseDto.from(result.value))
            is Either.Error   -> throw result.value.toResponseStatusException()  // I-02
        }

    @Schema(title = "CloseConversationResponse")
    data class ResponseDto(val id: String, val status: String) {    // nested — I-01
        companion object { fun from(dto: ConversationDTO) = ResponseDto(dto.id, dto.status) }
    }
}
```

---

## Domain Event Shape (ECST pattern)

```kotlin
// domain/events/ConversationEvent.kt
sealed class ConversationEvent {
    data class Closed(val snapshot: ConversationSnapshot) : ConversationEvent()
}

data class ConversationSnapshot(        // primitives only — no domain types
    val id: String,
    val customerId: String,
    val closedAt: String
)

interface ConversationEventEmitter {    // port defined in domain/
    fun emit(event: ConversationEvent)
}

// infrastructure/outbound/OutboxConversationEventEmitter.kt
class OutboxConversationEventEmitter(...) : ConversationEventEmitter {
    override fun emit(event: ConversationEvent) { /* outbox write */ }
}
```

Kafka topic: `{service}.{aggregate}.events.v{version}`. Partition key: aggregate ID. Save first, then emit — both in same DB transaction.

---

## Commit Message Format

All commits must start with the Jira ticket ID:

```
SXG-1234 implement CloseConversation use case
SXG-1234 add POST /conversations/{id}/close endpoint
SXG-1234 promote artefacts and update context
```

---

## Reference

- [Full coding rules](../coding-standards/quick-reference.md) — detailed rules with code examples
- [Testing strategy](../coding-standards/testing-strategy.md) — testing philosophy and tool selection
- [Coding rules reference](../ai26-sdlc/reference/coding-rules.md) — full rule table with recipe links
- [Glossary](./glossary.md) — definitions for aggregate, use case, value object, Either, ECST
