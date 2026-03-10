---
name: dev-create-value-object
description: Creates domain value objects with validation, factory methods, and domain-meaningful operations. Use when you need to wrap a primitive with domain meaning and business rules.
argument-hint: [ValueObjectName] wrapping [PrimitiveType] with [validation rules]
---

# Create Value Object

Creates immutable domain value objects that wrap primitives with validation, factory methods, and domain-meaningful operations. Use when a primitive (`String`, `Int`, `UUID`) carries domain significance beyond its raw type.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`, `main_source_root=service/src/main/kotlin`.

## Task

Create a value object `{VALUE_OBJECT_NAME}` in:
- `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{ValueObjectName}.kt`

## Implementation Rules

Apply `coding_rules` from `ai26/config.yaml`: **CC-01, D-08, D-09, D-10, D-11**.

Key: IDs use `data class` with public constructor (D-08, D-09, D-10). Single-field non-ID wrappers use `@JvmInline value class` with private constructor + `of()` factory (D-11). See templates below.

## Factory method decision

| Factory method | Returns | Use when |
|---|---|---|
| `of(raw: T)` / `fromString(raw: String)` | `ValueObject` (throws `IllegalArgumentException`) | **Input boundary** — the caller (controller) is responsible for converting the exception to 400. Do NOT use this inside the domain/use case. |
| Domain method (e.g. `Conversation.close(...)`) | `Either<Error, T>` | **Business logic** — legitimate alternative path (not an input error). |

Rule of thumb: if the invalid input comes from outside the system (HTTP, SQS), parse it in the controller. If the invalidity reflects a domain rule, model it with `Either` in a domain method.

## Example Implementation

### Inline Value Object (simple wrapper)

```kotlin
package {BASE_PACKAGE}.{module}.domain

@JvmInline
value class {ValueObjectName}(val value: {PrimitiveType}) {

    init {
        require({validationExpression}) {
            "{ValueObjectName} {rule description}"
        }
    }

    companion object {
        fun of(raw: {PrimitiveType}): {ValueObjectName} = {ValueObjectName}(raw)
    }

    override fun toString(): String = value.toString()
}
```

### Rich Value Object (multiple fields or complex validation)

```kotlin
package {BASE_PACKAGE}.{module}.domain

data class {ValueObjectName} private constructor(
    val field1: String,
    val field2: Int
) {
    init {
        require(field1.isNotBlank()) { "{ValueObjectName} field1 cannot be blank" }
        require(field2 > 0) { "{ValueObjectName} field2 must be positive" }
    }

    companion object {
        fun of(field1: String, field2: Int): {ValueObjectName} =
            {ValueObjectName}(field1.trim(), field2)
    }

    fun toDisplay(): String = "$field1 ($field2)"
}
```

### ID Value Object (entity identifier)

```kotlin
package {BASE_PACKAGE}.{module}.domain

import java.util.UUID

data class {EntityName}Id(val value: UUID) {

    companion object {
        fun random(): {EntityName}Id = {EntityName}Id(UUID.randomUUID())
        fun fromString(raw: String): {EntityName}Id = {EntityName}Id(UUID.fromString(raw))
    }

    override fun toString(): String = value.toString()
}
```

> `random()` lives in the production companion because a UUID-based ID has no domain constraints — every UUID is valid. Generating a random one has no side effects. This makes it convenient for tests *and* for production code that needs a fresh ID (e.g. `create()` factory methods).

## Anti-Patterns

```kotlin
// ❌ Public constructor bypasses validation
data class Email(val value: String)

// ❌ Mutable state
data class Money(var amount: BigDecimal, var currency: String)

// ❌ No validation — wrapping adds no value
@JvmInline
value class OrderId(val value: UUID)

// ❌ @JvmInline for aggregate/entity IDs — use plain data class instead
@JvmInline value class ConversationId(val value: UUID)  // ← wrong for IDs
// ✅ data class ConversationId(val value: UUID)  // every UUID is valid; public constructor is fine for IDs

// ❌ Framework annotation in domain value object
@Entity
data class Email(@Id val value: String)

// ❌ I/O or side effects in value object
data class Email(val value: String) {
    fun send(message: String) { /* sends email — NOT a value object concern */ }
}
```

## Verification

1. `./gradlew service:compileKotlin` passes
2. Conventions satisfied: CC-01, D-08, D-09, D-10, D-11

## Package Location

Place in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/`
