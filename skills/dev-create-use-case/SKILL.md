---
name: dev-create-use-case
description: Creates a use case in the application layer that orchestrates business logic using Either for error handling. Use when you need to implement a specific business operation.
argument-hint: [UseCaseName] that [description of what it does]
---

# Create Use Case

Creates a use case in the application layer that orchestrates domain entities, coordinates repositories, and returns `Either<UCError, DTO>` for expected business outcomes.

**Key contracts:**
- The use case receives **primitives only** (`UUID`, `String`, `Int`, `List<String>`) — never domain types, DTOs, or command objects. Inside the use case, immediately wrap primitives into domain types. `UUID` is the accepted primitive for identities.
- Input parsing (String → enum, String → UUID validation) happens in the controller before calling the use case.
- Repository ports return plain types (`Entity?` for not-found, throws for infra failures) — no `Either` on ports.
- Event emitter ports return `Unit` — infra failures throw exceptions.
- `Either` only where there is a *legitimate alternative business path* (not-found, already-closed, etc.).

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`). From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`; `shared_imports.either` for the Either import path.

Fallback values if file cannot be read: `base_package=de.tech26.valium`, `main_source_root=service/src/main/kotlin`, `either=de.tech26.valium.shared.kernel.Either`.

## Task

Create a use case `{USE_CASE_NAME}` in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/application/{UseCaseName}.kt`
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/errors/{SealedClassName}.kt`

**Error class naming:** Use the `sealedClass` name from `error-catalog.yaml` if provided (e.g. `CreateConversationDomainError`).
If no artefact is available, default to `{UseCaseName}DomainError`.

## Implementation Rules

Apply `coding_rules` from `ai26/config.yaml`: **CC-03, CC-04, A-01 through A-06**.

Key contract: `operator fun invoke()` receives **primitives only** (`UUID`, `String`, `Int`, `List<String>`) — input parsing belongs in the controller. Event emitter port returns `Unit`; call directly (outbox write is in the same DB transaction as `save()`). See templates below.

## Example Implementation

### Pattern 1 — Mutation (load entity, execute action, persist, emit event)

Use this pattern when you load an existing entity, run a business action on it, save, and optionally emit an event.

```kotlin
package {BASE_PACKAGE}.{module}.application

import {sharedImports.either}
import {BASE_PACKAGE}.{module}.domain.{EntityName}
import {BASE_PACKAGE}.{module}.domain.{EntityName}Id
import {BASE_PACKAGE}.{module}.domain.{EntityName}Repository
import {BASE_PACKAGE}.{module}.domain.{EntityName}DTO
import {BASE_PACKAGE}.{module}.domain.errors.{UseCaseName}Error
import {BASE_PACKAGE}.{module}.domain.events.{EntityName}EventEmitter
import {BASE_PACKAGE}.{module}.domain.events.{EntityName}Event
import {sharedImports.logger}
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
@Transactional
class {UseCaseName}(
    private val {entity}Repository: {EntityName}Repository,
    private val eventEmitter: {EntityName}EventEmitter,
) {

    operator fun invoke(
        id: UUID,              // ← primitives only — controller already parsed and validated
        param2: String         // ← String primitive; wrap to domain type inside use case
    ): Either<{UseCaseName}Error, {EntityName}DTO> {

        // 1. Wrap primitive to domain type
        val {entity}Id = {EntityName}Id(id)

        // 2. Load entity — null means not found
        val {entity} = {entity}Repository.findById({entity}Id)
            ?: return Either.Error({UseCaseName}Error.NotFound({entity}Id))

        // 3. Execute domain logic — entity method returns Either for expected alternatives
        val updated = {entity}.performAction()
            .mapError { {UseCaseName}Error.from(it) }
            .getOrElse { return Either.Error(it) }

        // 4. Persist — infra exceptions propagate unchecked to @ControllerAdvice → 500
        val saved = {entity}Repository.save(updated)

        // 5. Emit event (outbox write — same DB transaction as save)
        eventEmitter.emit({EntityName}Event.ActionPerformed(snapshot = saved.toSnapshot()))

        return Either.Success(saved.toDTO())
    }
}
```

### Pattern 2 — Creation with event emission

Use this pattern when creating a new entity and emitting a domain event.

```kotlin
@Service
@Transactional
class Create{EntityName}(
    private val {entity}Repository: {EntityName}Repository,
    private val eventEmitter: {EntityName}EventEmitter,
) {

    operator fun invoke(
        customerId: UUID,      // ← primitive (UUID)
        subject: String        // ← primitive
    ): Either<Create{EntityName}Error, {EntityName}DTO> {

        // Build entity — domain validates invariants in init block via runCatching
        val entity = runCatching { {EntityName}.create(customerId, subject) }
            .getOrElse { return Either.Error(Create{EntityName}Error.InvalidInput(it.message ?: "")) }

        // Persist — exceptions propagate unchecked to @ControllerAdvice → 500
        val saved = {entity}Repository.save(entity)

        // Emit event (outbox write — same DB transaction as save)
        eventEmitter.emit({EntityName}Event.Created(snapshot = saved.toSnapshot()))

        return Either.Success(saved.toDTO())
    }
}
```

### Sealed Use Case Error
```kotlin
package {BASE_PACKAGE}.{module}.domain.errors

// Models only business alternatives — no input validation, no HTTP, no infra failures.
sealed class {UseCaseName}Error {
    data class NotFound(val id: UUID) : {UseCaseName}Error()
    data class AlreadyClosed(val id: UUID) : {UseCaseName}Error()
    // ❌ InvalidUUID, InvalidEndReason  — those are input validation → controller
    // ❌ PersistenceFailure             — infra failure → propagates unchecked to @ControllerAdvice → 500
}
```

## Anti-Patterns

```kotlin
// ❌ String parameters in use case — input parsing (UUID.fromString, enum.valueOf) belongs in controller
operator fun invoke(conversationId: String, endReason: String, closedBy: String): Either<...>
// ✅ Primitives only — controller already validated and converted these
operator fun invoke(conversationId: UUID, endReason: String, closedBy: String): Either<...>
// NOTE: UUID is the accepted primitive for identities; String is fine for simple string inputs.
// The use case wraps them to domain types (ConversationId, EndReason) at the top of invoke().

// ❌ Domain types in use case parameters — breaks the primitives-only rule
operator fun invoke(conversationId: ConversationId, endReason: EndReason, closedBy: ClosedBy): Either<...>
// ✅ Use UUID and String: operator fun invoke(conversationId: UUID, endReason: String, ...)

// ❌ Either on repository port — repository returns plain types
interface ConversationRepository {
    fun findById(id: UUID): Either<DomainError, Conversation?>  // wrong
}
// ✅
interface ConversationRepository {
    fun findById(id: UUID): Conversation?
    fun save(c: Conversation): Conversation
}

// ❌ Either on event emitter — emitter returns Unit
interface ConversationClosedEventEmitter {
    fun emit(c: Conversation): Either<DomainError, Unit>  // wrong
}
// ✅
interface ConversationClosedEventEmitter {
    fun emit(c: Conversation): Unit
}

// ❌ Infrastructure types in use case signature
fun invoke(request: CreateOrderRequest): ResponseEntity<OrderResponse>

// ❌ Input validation error in sealed UC error — those are controller concerns
sealed class CloseConversationError {
    data class InvalidEndReason(val value: String) : CloseConversationError()  // ← not here
    data class InvalidConversationId(val value: String) : CloseConversationError()  // ← not here
}

// ❌ Catching all exceptions silently
operator fun invoke(...) = try { ... } catch (e: Exception) { Either.Error(...) }

// ❌ Event emission failure mapped to Either error variant
val emitResult = eventEmitter.emit(saved)
if (emitResult is Either.Error) { return Either.Error(EmissionFailed) }
// ✅ Direct call — outbox write is in the same DB transaction as save(); failures throw and roll back the tx
eventEmitter.emit({EntityName}Event.ActionPerformed(snapshot = saved.toSnapshot()))

// ❌ runCatching wrapping event emission — hides outbox failures, breaks transactional semantics
runCatching { eventEmitter.emit(saved) }.onFailure { logger.warn("...") }
```

## Typical Next Step

After `dev-create-use-case`, expose it via HTTP with `dev-create-rest-controller`, passing:
- Use case class name: `{UseCaseName}` (e.g., `CloseConversation`)
- Use case error type: `{UseCaseName}Error` (controller folds it directly to `ResponseEntity` via `toResponseEntity()`)
- Returned DTO: `{EntityName}DTO` (controller serializes to JSON response)

To cover the use case with tests, use `test-create-use-case-tests` passing the same `{UseCaseName}`.

## Verification

1. `./gradlew service:compileKotlin` passes
2. Conventions satisfied: CC-03, CC-04, A-01 through A-06

## Package Location

Place in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/application/`
