---
name: dev-create-domain-exception
description: Creates the correct error type for a business rule violation per ADR 2026-01-27 — thrown domain exception, Either sealed error, or application exception. Use when a domain entity or use case needs to signal a business rule violation.
argument-hint: [ExceptionName] for [business rule violation description] in [module]
---

# Create Domain Exception

Creates the correct error type for a business rule violation. Each layer uses its natural error mechanism:

- **Domain:** `Either<E, T>` for expected alternative outcomes (e.g. already-closed). `require`/`check` for invariants.
- **Application (Use Case):** sealed `UseCaseError` that groups domain errors + flow errors (not-found, etc.).
- **Infra inbound (Controller):** maps the UC sealed directly to `ResponseEntity`. No intermediate class, no throw.
- **Infra outbound (Repo, Emitter):** plain return type (`T?` for not-found). Infrastructure exceptions for failures.

> **Input validation belongs in the controller, not the domain.** If the caller sends an invalid enum string, the controller parses it and throws `ResponseStatusException(400)` before calling the use case. The use case receives already-typed parameters (`UUID`, `EndReason`, `ClosedBy`).

> **No `ApplicationException` intermediate layer.** `ValiumApplicationException` subclasses are **not generated** by this skill. The controller folds the use case's `Either` directly into `ResponseEntity` — no throw.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create a domain error in one of two locations depending on the error type:

**For invariant violations (thrown by entities in `init` blocks):**
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{ExceptionName}.kt`

**For expected business outcomes (returned as Either by domain methods / use cases):**
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/errors/{ErrorName}.kt`

There is **no** `application/errors/` location. ApplicationException intermediates are not part of the target model.

## Implementation Rules

- ✅ Domain exceptions extend `RuntimeException` (unchecked) — for invariant guards only
- ✅ Sealed classes for domain errors returned via `Either` — for expected business outcomes
- ✅ Sealed error scoped to the aggregate operation, nested or in `domain/errors/`
- ✅ Descriptive names reflecting the business rule: `AlreadyClosed`, `NotFound`
- ✅ Include relevant context (IDs, entity names) as data class fields
- ✅ Suffix with `Error` for `Either` types, `Exception` for thrown types
- ❌ Input validation errors (`InvalidUUID`, `InvalidEndReason`) — these belong in the controller
- ❌ HTTP status codes or `HttpStatus` in sealed error classes — HTTP is an infra concern
- ❌ `ValiumApplicationException` subclasses — no ApplicationException intermediates
- ❌ `Either` on repository or emitter ports — ports return plain types

## When to Use Each Pattern

| Situation | Pattern | Location |
|-----------|---------|----------|
| True invariant — programming error, unreachable in valid flow (e.g. `init` guard) | Throw exception | `domain/` |
| Expected business alternative (e.g. already-closed, not-found) | `Either<SealedError, T>` | `domain/errors/` or nested in aggregate |
| Input parsing failure (invalid UUID, unknown enum) | `ResponseStatusException(400)` in controller | `infrastructure/inbound/` |
| Infrastructure failure (DB down, SQS error) | Unchecked exception propagates to `@ControllerAdvice` → 500 | — |

**Rule of thumb:** `Either` only where there is a *legitimate alternative business path*. Infrastructure failures are never Either variants.

## Example Implementation

### Domain Exception (entity invariant, `init` block guard)

```kotlin
package {BASE_PACKAGE}.{module}.domain

class {ExceptionName}({contextParam}: {Type}) :
    RuntimeException("{Business rule description}: ${contextParam}")
```

### Sealed Domain Error (Either — expected business alternative)

Scope the sealed to the aggregate operation. Nested inside the aggregate is preferred when the error only makes sense in that context:

```kotlin
// Inside the aggregate class:
fun close(closedAt: Instant, endReason: EndReason, closedBy: ClosedBy): Either<CloseError, {AggregateName}> {
    if (status == {AggregateName}Status.CLOSED) {
        return Either.Error(CloseError.AlreadyClosed(id))
    }
    return Either.Success(copy(status = {AggregateName}Status.CLOSED, ...))
}

sealed class CloseError {
    data class AlreadyClosed(val id: UUID) : CloseError()
}
```

Or standalone in `domain/errors/` when shared across multiple operations:

```kotlin
package {BASE_PACKAGE}.{module}.domain.errors

sealed class {Operation}Error {
    data class {EntityName}NotFound(val id: UUID) : {Operation}Error()
    data class AlreadyClosed(val id: UUID) : {Operation}Error()
}
```

### Use Case Error (groups domain + flow errors)

The use case defines its own sealed (in `domain/errors/` or inline) that aggregates everything that can fail:

```kotlin
// Repository returns plain type — no Either
fun findById(id: UUID): {Entity}?
fun save(entity: {Entity}): {Entity}

// Use Case returns Either<UCError, DTO>
@Transactional
operator fun invoke(id: UUID, ...): Either<{Operation}Error, {Entity}DTO> {
    val entity = repository.findById(id)
        ?: return Either.Error({Operation}Error.NotFound(id))

    val updated = entity.close(...)
        .getOrElse { return Either.Error({Operation}Error.AlreadyClosed(id)) }

    val saved = repository.save(updated)
    // Emit event — outbox write is part of the same DB transaction as save()
    emitter.emit({AggregateName}Event.Closed(snapshot = saved.toSnapshot()))

    return Either.Success(saved.toDTO())
}
```

### Controller (folds Either directly — no ApplicationException, no throw)

```kotlin
@PostMapping("/{id}/close")
fun close(@PathVariable id: String, @Valid @RequestBody request: RequestDto): ResponseEntity<out Any> {
    // Input parsing in controller — 400 immediately if invalid
    val uuid = try { UUID.fromString(id) }
               catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST) }
    val endReason = try { EndReason.valueOf(request.endReason) }
                    catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST) }

    return when (val result = useCase(uuid, endReason, ...)) {
        is Either.Success -> ResponseEntity.ok(result.value.toResponseDto())
        is Either.Error -> result.value.toResponseEntity()
    }
}

private fun {Operation}Error.toResponseEntity(): ResponseEntity<out Any> = when (this) {
    is {Operation}Error.NotFound        -> ResponseEntity.status(HttpStatus.NOT_FOUND).build()
    is {Operation}Error.AlreadyClosed   -> ResponseEntity.status(HttpStatus.CONFLICT).build()
}
```

## Anti-Patterns

```kotlin
// ❌ Input validation error in domain sealed — belongs in controller
sealed class CloseConversationError {
    data class InvalidEndReason(val value: String) : CloseConversationError()    // ← 400 in controller!
    data class InvalidConversationId(val value: String) : CloseConversationError()  // ← 400 in controller!
}

// ❌ ApplicationException intermediate — eliminated
sealed class CloseConversationApplicationException(statusCode: HttpStatusCode) :
    ValiumApplicationException(statusCode) { ... }

// ❌ HTTP status in domain sealed — infrastructure concern in domain
sealed class CloseError {
    data class NotFound(val statusCode: Int = 404) : CloseError()  // HTTP in domain!
}

// ❌ Either on repository or emitter port
interface ConversationRepository {
    fun create(c: Conversation): Either<DomainError, Conversation>  // ← plain type or throw
}
interface ConversationClosedEventEmitter {
    fun emit(c: Conversation): Either<DomainError, Unit>  // ← Unit or throw
}

// ❌ Use case parses String input and returns parse errors as Either
operator fun invoke(conversationId: String, endReason: String, ...): Either<CloseError, DTO> {
    val id = UUID.fromString(conversationId) ?: return Either.Error(CloseError.InvalidId(...))
    // ✅ The controller parses UUID/enum before calling the use case
}

// ✅ Use case receives typed inputs, repository is plain:
operator fun invoke(id: UUID, endReason: EndReason, closedBy: ClosedBy): Either<CloseError, DTO> {
    val conversation = repository.findById(id) ?: return Either.Error(CloseError.NotFound(id))
    ...
}
```

## Verification

1. Domain exceptions compile without framework imports
2. Sealed domain errors have no HTTP/infrastructure concerns (no `HttpStatus`, no `ValiumApplicationException`)
3. No `ApplicationException` classes generated — controller maps sealed directly to `ResponseEntity` (no throw)
4. Repository and emitter ports have plain return types — no `Either` in their signatures
5. Input validation errors (`InvalidUUID`, `InvalidEndReason`) are absent from the domain sealed

## Package Location

- Domain exceptions (thrown): `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/`
- Domain errors (Either): `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/errors/` or nested in aggregate
