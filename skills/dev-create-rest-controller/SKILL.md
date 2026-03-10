---
name: dev-create-rest-controller
description: Creates a REST controller in infrastructure/inbound as a humble object with Swagger/OpenAPI. Use when you need to expose a use case via HTTP API.
argument-hint: [ControllerName] at [/api/endpoint]
---

# Create REST Controller

Creates a REST controller in `infrastructure/inbound/` following the humble object pattern — controllers only translate between HTTP and use cases. Includes Swagger/OpenAPI annotations.

**Key responsibilities of the controller:**
1. **Parse and validate input** (String → `UUID`, String → enum). On failure: throw `ResponseStatusException(HttpStatus.BAD_REQUEST)` immediately. The use case never receives raw Strings for typed domain inputs.
2. **Call the use case** with typed parameters.
3. **Fold the `Either`** directly: `Either.Success` → response body, `Either.Error` → `ResponseEntity` with the correct status via `toResponseEntity()`.

There is **no** `ApplicationException` intermediate class and **no `throw`** on the error path. The controller maps the use case's sealed error directly to `ResponseEntity`.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.
Also resolve `shared_imports.either` (fallback: `de.tech26.valium.shared.kernel.Either`).

## Task

Create a REST controller `{CONTROLLER_NAME}` in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{ControllerName}.kt`

Request and response DTOs are inner classes/data classes within the controller file unless they are reused. **Do not** create `application/errors/{ApplicationException}.kt` — that file is eliminated.

## Implementation Rules

- ✅ Located in `infrastructure/inbound/` (not flat `infrastructure/`)
- ✅ Humble object — only HTTP ↔ Use Case translation
- ✅ Parses input from String → domain types (`UUID`, enums) with `ResponseStatusException(BAD_REQUEST)` on failure
- ✅ Calls use case with typed parameters, receives `Either<UCError, DTO>`
- ✅ Folds `Either` directly: `Either.Success` → response body, `Either.Error` → `ResponseEntity` via `toResponseEntity()`
- ✅ Return type `ResponseEntity<out Any>` when error path returns different body type
- ✅ Swagger/OpenAPI annotations on endpoints — `@ApiResponse` for 2xx includes `content = [Content(schema = Schema(implementation = ResponseDto::class))]`
- ✅ Request DTOs with `@field:NotBlank` / `@field:NotNull` validation for structural fields
- ✅ Response classes convert from DTOs returned by use case
- ❌ No business logic or conditionals beyond input parsing and error mapping
- ❌ No direct domain entity usage — only DTOs from use case
- ❌ No `throw` on `Either.Error` — return `ResponseEntity` directly
- ❌ `ValiumApplicationException` subclasses — eliminated
- ❌ `application/errors/` package — that layer is eliminated

## Example Implementation

### Controller
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound

import {BASE_PACKAGE}.{module}.application.{UseCaseName}
import {BASE_PACKAGE}.{module}.domain.errors.{UseCaseName}Error
import {sharedImports.either}
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.responses.ApiResponse
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.util.UUID

@RestController
@RequestMapping("/api/{resource}")
class {ControllerName}(
    private val {useCase}: {UseCaseName}
) {

    @PostMapping("/{id}/close")
    @Operation(
        summary = "Close a {resource}",
        responses = [
            ApiResponse(responseCode = "200", description = "{Resource} closed"),
            ApiResponse(responseCode = "400", description = "Invalid input"),
            ApiResponse(responseCode = "404", description = "{Resource} not found"),
            ApiResponse(responseCode = "409", description = "{Resource} already closed"),
        ]
    )
    fun close(
        @PathVariable id: String,
        @Valid @RequestBody request: RequestDto,
    ): ResponseDto {
        // Input parsing in controller — 400 immediately if invalid
        val resourceId = try { UUID.fromString(id) }
            catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid id: $id") }
        val param = try { {DomainEnum}.valueOf(request.param) }
            catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid param: ${request.param}") }

        return when (val result = {useCase}(resourceId, param)) {
            is Either.Success -> ResponseEntity.ok(result.value.toResponseDto())
            is Either.Error   -> result.value.toResponseEntity()
        }
    }

    private fun {UseCaseName}Error.toResponseEntity(): ResponseEntity<out Any> = when (this) {
        is {UseCaseName}Error.NotFound      -> ResponseEntity.status(HttpStatus.NOT_FOUND).build()
        is {UseCaseName}Error.AlreadyClosed -> ResponseEntity.status(HttpStatus.CONFLICT).build()
    }

    @Schema(name ="{ControllerName}Request")
    data class RequestDto(
        @field:Schema(description = "Param description", example = "VALUE")
        @field:NotBlank(message = "param is required")
        @field:JsonProperty("param")
        val param: String,
    )

    @Schema(name ="{ControllerName}Response")
    data class ResponseDto(
        @field:JsonProperty("id") val id: UUID,
        @field:JsonProperty("status") val status: String,
        // ... remaining fields from DTO
    )

    private fun {EntityName}DTO.toResponseDto(): ResponseDto = ResponseDto(id = id, status = status)
}
```

## Anti-Patterns

```kotlin
// ❌ Use case receives raw Strings — parsing belongs in controller
return when (val result = useCase(conversationId, request.endReason, request.closedBy)) { ... }
// ✅ Parse first, then call use case with typed values
val endReason = try { EndReason.valueOf(request.endReason) }
    catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST) }
return when (val result = useCase(conversationId, endReason, closedBy)) { ... }

// ❌ ApplicationException intermediate — eliminated
throw result.value.toApplicationException()  // no longer used
// ✅ Direct ResponseEntity fold — no throw
result.value.toResponseEntity()

// ❌ Business logic in controller
fun create(request: Request): ResponseEntity<*> {
    if (request.items.isEmpty()) return ResponseEntity.badRequest()... // belongs in entity
}

// ❌ Returning domain entities directly
fun findById(id: String): ResponseEntity<Order> // leaks domain

// ❌ Controller in flat infrastructure/ (not inbound/)
package {BASE_PACKAGE}.chat.infrastructure // wrong
package {BASE_PACKAGE}.chat.infrastructure.inbound // correct
```

## Typical Next Step

After `dev-create-rest-controller`, cover the HTTP contract with `test-create-controller-tests`, passing:
- Controller class name: `{ControllerName}`
- Endpoint path: `/api/{resource}`
- Use case name for mocking: `{UseCaseName}`

For full end-to-end acceptance coverage, use `test-create-feature-tests` with the same feature name.

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. Controller is in `infrastructure/inbound/` package
3. No domain entity imports — only DTOs
4. All `Either.Error` paths return `ResponseEntity` via `toResponseEntity()` — no `throw`
5. No `application/errors/` file generated
6. Use case called with typed domain types, not raw Strings
7. Input parsing (String → UUID, String → enum) present with `ResponseStatusException(BAD_REQUEST)` on failure
8. `@ApiResponse` for 2xx includes `content = [Content(schema = Schema(implementation = ResponseDto::class))]`

## Package Location

- Controller (with inner request/response DTOs): `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/`
