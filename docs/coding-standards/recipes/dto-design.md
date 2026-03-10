---
rules: [CC-05]
---

← [Recipes Index](../how-to.md)

# DTO Design

DTOs are the data contracts at each layer boundary. Two distinct DTO families exist in this codebase: **controller DTOs** (nested inside the controller, annotated for Swagger, represent the HTTP API contract) and **use-case DTOs** (plain data classes in the application layer, no framework annotations, represent the application boundary). They are separate classes that evolve independently.

---

### When

| Situation | Use |
|---|---|
| Shaping the HTTP request body or response body | Controller-nested `RequestDto` / `ResponseDto` inside the controller class |
| Returning data from a use case to any caller | Use-case DTO (in `domain/` or `application/` package, primitives only) |
| Reusing a response DTO across multiple controllers | Still nest it — if two controllers share a response shape, introduce a shared use-case DTO and let each controller map its own `ResponseDto.from(useCaseDto)` |
| Framework-annotated DTOs in the application layer | Never — the application layer must not import Spring or Swagger |

### Template

**Controller with nested request and response DTOs:**
```kotlin
// infrastructure/inbound/CreateOrderController.kt
@RestController
@RequestMapping("/api/v1/orders")
@Tag(name = "Orders", description = "Order management")
class CreateOrderController(
    private val createOrder: CreateOrder,
    private val metrics: MetricService,
) {

    @PostMapping
    @Operation(summary = "Place a new order")
    @ApiResponses(value = [
        ApiResponse(responseCode = "201", description = "Order placed",
            content = [Content(schema = Schema(implementation = ResponseDto::class))]),
        ApiResponse(responseCode = "400", description = "Invalid request"),
        ApiResponse(responseCode = "422", description = "Business rule violation")
    ])
    fun create(@RequestBody @Valid request: RequestDto): ResponseEntity<out Any> =
        when (val result = createOrder(request.customerId, request.amountCents, request.currency)) {
            is Either.Success -> ResponseEntity.status(HttpStatus.CREATED).body(ResponseDto.from(result.value))
            is Either.Error   -> result.value.toResponseEntity()
        }

    @Schema(name = "CreateOrderRequest")
    data class RequestDto(
        @Schema(description = "Customer identifier", example = "CUST-001")
        @field:NotBlank(message = "customerId is required")
        val customerId: String,

        @Schema(description = "Order amount in cents", example = "4999")
        @field:NotNull(message = "amountCents is required")
        val amountCents: Long,

        @Schema(description = "ISO 4217 currency code", example = "EUR")
        @field:NotBlank(message = "currency is required")
        val currency: String,
    )

    @Schema(name = "CreateOrderResponse")
    data class ResponseDto(
        val id: String,
        val customerId: String,
        val amountCents: Long,
        val currency: String,
        val status: String,
        val createdAt: String,
    ) {
        companion object {
            fun from(dto: OrderDTO): ResponseDto =
                ResponseDto(
                    id          = dto.id,
                    customerId  = dto.customerId,
                    amountCents = dto.amountCents,
                    currency    = dto.currency,
                    status      = dto.status,
                    createdAt   = dto.createdAt,
                )
        }
    }
}
```

> **File layout:** one file per controller surface — controller class followed by its nested `RequestDto` and `ResponseDto`. `@Schema(name = ...)` overrides the generated Swagger name so the spec shows `CreateOrderRequest` instead of `CreateOrderController.RequestDto`.

**Use-case DTO (application boundary — primitives only, zero framework imports):**
```kotlin
// domain/OrderDTO.kt  (or application/OrderDTO.kt — never infrastructure/)
data class OrderDTO(
    val id: String,
    val customerId: String,
    val amountCents: Long,
    val currency: String,
    val status: String,
    val createdAt: String,
)
```

The use-case DTO is primitives-only (`String`, `Long`, `Boolean`, `UUID` rendered as `String`) because:
- The application layer must not import framework types or serialisation annotations (CC-01 / A-05).
- The controller `ResponseDto` is free to rename, reorder, or omit fields for API versioning without touching the use case.
- Tests for the use case work with simple equality checks on plain data.

**Mapping — `ResponseDto.from()` companion object:**

The `companion object { fun from(dto: UseCaseDTO): ResponseDto }` pattern keeps the mapping co-located with the type that owns the API contract. The use case never knows about the response DTO shape.

```kotlin
companion object {
    fun from(dto: OrderDTO): ResponseDto = ResponseDto(
        id          = dto.id,
        customerId  = dto.customerId,
        amountCents = dto.amountCents,
        currency    = dto.currency,
        status      = dto.status,
        createdAt   = dto.createdAt,
    )
}
```

### Rules

- Controller `RequestDto` and `ResponseDto` are **nested classes** inside the controller — not top-level classes, not separate files.
- Use `@Schema(name = "ExplicitName")` on every nested DTO so Swagger does not expose the nested class path.
- Use-case DTOs carry **primitives only**: `String`, `Long`, `Int`, `Boolean`, `UUID` (as `String`). No `Instant`, no domain types, no enum types — serialize them all to `String` before crossing the boundary.
- Use-case DTOs have **no framework annotations** — no `@JsonProperty`, no `@Schema`, no `@NotBlank`.
- `ResponseDto.from(useCaseDto)` lives in a `companion object` on `ResponseDto` — the controller method calls it and stays minimal.
- UUIDs cross the HTTP boundary as `String` — the controller parses/formats them; the use case receives `UUID` parameters, not `String`.

### Anti-patterns

```kotlin
// ❌ Request/response DTOs in separate top-level files
// CreateOrderRequest.kt    ← wrong
// OrderResponse.kt         ← wrong
// ✅ Nested inside the controller: class CreateOrderController { data class RequestDto(...) }

// ❌ Missing @Schema(name = ...) on nested DTO — Swagger renders the full nested path
@Schema  // wrong — no name override
data class ResponseDto(...)
// ✅
@Schema(name = "CreateOrderResponse")
data class ResponseDto(...)

// ❌ Spring/Swagger annotations in the use-case DTO
data class OrderDTO(
    @Schema(description = "Order id")  // application layer must not import io.swagger.*
    val id: String,
)

// ❌ Domain type in use-case DTO — crossing the boundary with a rich domain object
data class OrderDTO(val status: OrderStatus)   // enum from the domain model
// ✅ Serialize to String before returning from the aggregate's toDTO()
data class OrderDTO(val status: String)

// ❌ ResponseDto directly returned by the use case — controller loses its own contract
@Service
class CreateOrder(...) {
    operator fun invoke(...): Either<..., CreateOrderController.ResponseDto>  // wrong
}
// ✅ Use case returns OrderDTO; controller maps to ResponseDto.from(dto)

// ❌ Instant or ZonedDateTime in the use-case DTO
data class OrderDTO(val createdAt: Instant)
// ✅ createdAt: String — format (ISO-8601) at the aggregate boundary, not in the controller
```

### See also

- [REST Controllers](./controllers.md#rest-controllers) for the full controller pattern and Swagger annotations
- [Use Cases](./use-cases.md) for primitive-only parameters and `Either<DomainError, DTO>` return types
