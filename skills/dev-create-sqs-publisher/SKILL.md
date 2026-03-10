---
name: dev-create-sqs-publisher
description: Scaffolds an outbound SQS publisher adapter with domain port, SqsTemplate, @Retry, and error mapping. Use when the service/ module needs to send messages to an SQS queue.
argument-hint: [OperationName] in [module] — e.g. ConversationAnalysis in conversation
---

# Create SQS Publisher

Scaffolds an outbound SQS publisher adapter using `SqsTemplate` with resilience and error mapping. Creates the domain port interface (zero framework imports) and the infrastructure adapter. For JSON payloads, also creates the internal message DTO. Use when the `service/` module needs to publish messages to an SQS queue.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create an SQS publisher for `{OperationName}` in:

1. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/port/{OperationName}Submitter.kt` — domain port interface (zero framework imports, parameters are domain types)
2. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{operationName}/SQS{OperationName}Publisher.kt` — `@Service` adapter implementing the domain port; uses `SqsTemplate`, `@Retry`, and `runCatching`
3. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{operationName}/{OperationName}Message.kt` — **JSON payloads only**: `internal data class` carrying the message fields

Also update:
- The module's `@ConfigurationProperties` class: add `{operationName}QueueName: String` property
- `service/src/main/resources/application.yml`: add `{module}.sqs.{operation-name}-queue-name: ""` placeholder

## Payload decision

| Payload type | Use when | Files generated |
|---|---|---|
| Simple (string) | The message is a single ID or opaque string | Domain port + Publisher (2 files) |
| JSON | The message carries structured data | Domain port + Publisher + Message DTO (3 files) |

Ask the user which payload type applies if not specified in the arguments.

## Implementation Rules

- ✅ Domain port: pure Kotlin interface in `{MODULE}/domain/port/`, parameters are domain value types or primitives, zero framework imports, returns `Unit`
- ✅ Publisher: `@Service`, `@EnableConfigurationProperties({Module}SQSProperties::class)`, `SqsTemplate` constructor injection
- ✅ `@Retry(name = "all")` annotated on the `submit()` method
- ✅ Error wrapping: `runCatching { sqsTemplate.send(...) }.onFailure { throw ExternalServiceServerException(...) }`
- ✅ Simple payload: send `id.toString()` or the primitive value directly
- ✅ JSON payload: serialize the `{OperationName}Message` internal data class via `ObjectMapper`; do NOT use domain entities as message payloads
- ✅ Message DTO: `internal data class`, lives in `infrastructure/outbound/{operationName}/` — never exposed outside infrastructure
- ✅ Queue name sourced from `@ConfigurationProperties` — never hardcoded
- ❌ No domain types in `SqsTemplate.send()` — map to string or message DTO first
- ❌ No `@ConfigurationProperties` in the domain port
- ❌ `Either` on the domain port — port returns `Unit`, throws on failure for `@Retry` to handle

### Required dependencies (add to `service/build.gradle.kts` if not present)

```kotlin
implementation(libs.bundles.spring.cloud.aws)
implementation(libs.resilience4j.spring.boot3)
```

## Example — Simple Payload (string)

### 1. Domain Port
```kotlin
package {BASE_PACKAGE}.{module}.domain.port

interface {OperationName}Submitter {
    fun submit({entityId}: {EntityId})
}
```

### 2. Publisher
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{operationName}

import {BASE_PACKAGE}.{module}.domain.port.{OperationName}Submitter
import de.tech26.valium.shared.http.errorhandling.ExternalServiceServerException
import io.awspring.cloud.sqs.operations.SqsTemplate
import io.github.resilience4j.retry.annotation.Retry
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service

@Service
@EnableConfigurationProperties({Module}SQSProperties::class)
class SQS{OperationName}Publisher(
    private val sqsTemplate: SqsTemplate,
    private val properties: {Module}SQSProperties
) : {OperationName}Submitter {

    @Retry(name = "all")
    override fun submit({entityId}: {EntityId}) {
        runCatching {
            sqsTemplate.send {
                it.queue(properties.{operationName}QueueName)
                    .payload({entityId}.value.toString())
            }
        }.onFailure {
            throw ExternalServiceServerException(
                serviceName = "SQS",
                message = "Failed to submit {OperationName}: ${entityId}",
                httpStatus = HttpStatus.INTERNAL_SERVER_ERROR,
                cause = it,
            )
        }
    }
}
```

## Example — JSON Payload

### 1. Domain Port
```kotlin
package {BASE_PACKAGE}.{module}.domain.port

interface {OperationName}Submitter {
    fun submit({entity}: {EntityDTO})
}
```

### 2. Message DTO (internal)
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{operationName}

internal data class {OperationName}Message(
    val id: String,
    val field1: String,
    val field2: String
)
```

### 3. Publisher
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{operationName}

import {BASE_PACKAGE}.{module}.domain.port.{OperationName}Submitter
import {BASE_PACKAGE}.{module}.domain.{EntityDTO}
import de.tech26.valium.shared.http.errorhandling.ExternalServiceServerException
import com.fasterxml.jackson.databind.ObjectMapper
import io.awspring.cloud.sqs.operations.SqsTemplate
import io.github.resilience4j.retry.annotation.Retry
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service

@Service
@EnableConfigurationProperties({Module}SQSProperties::class)
class SQS{OperationName}Publisher(
    private val sqsTemplate: SqsTemplate,
    private val properties: {Module}SQSProperties,
    private val objectMapper: ObjectMapper
) : {OperationName}Submitter {

    @Retry(name = "all")
    override fun submit({entity}: {EntityDTO}) {
        val message = {OperationName}Message(
            id = {entity}.id,
            field1 = {entity}.field1,
            field2 = {entity}.field2
        )
        runCatching {
            sqsTemplate.send {
                it.queue(properties.{operationName}QueueName)
                    .payload(objectMapper.writeValueAsString(message))
            }
        }.onFailure {
            throw ExternalServiceServerException(
                serviceName = "SQS",
                message = "Failed to submit {OperationName}: ${message.id}",
                httpStatus = HttpStatus.INTERNAL_SERVER_ERROR,
                cause = it,
            )
        }
    }
}
```

## Configuration Properties

Add `{operationName}QueueName` to the existing `@ConfigurationProperties` class for the module (create it if it does not exist):

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{operationName}

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "{module}.sqs")
data class {Module}SQSProperties(
    val {operationName}QueueName: String
)
```

Add to `service/src/main/resources/application.yml`:
```yaml
{module}:
  sqs:
    {operation-name}-queue-name: ""
```

## Anti-Patterns

```kotlin
// ❌ Domain type in SqsTemplate.send — infrastructure knows domain internals
sqsTemplate.send { it.queue(queueName).payload(domainEntity) }

// ❌ No @Retry — publisher is not resilient to transient failures
override fun submit(id: ConversationId) {
    sqsTemplate.send { it.queue(queueName).payload(id.toString()) }
}

// ❌ Hardcoded queue name — makes it impossible to configure per environment
sqsTemplate.send { it.queue("my-hardcoded-queue").payload(...) }

// ❌ Catching all exceptions and ignoring — breaks retry behaviour
runCatching { ... }  // no .onFailure — failures silently swallowed

// ❌ Framework annotation in domain port
import org.springframework.stereotype.Component
interface ConversationAnalysisSubmitter : Component  // domain must be framework-free
```

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. Domain port (`{OperationName}Submitter.kt`) has zero framework imports
3. Publisher is in `infrastructure/outbound/{operationName}/` subdirectory
4. `@Retry(name = "all")` annotation is present on `submit()` method
5. Queue name is sourced from `@ConfigurationProperties` — no hardcoded strings
6. `runCatching { }.onFailure { throw ExternalServiceServerException(...) }` is present

## Package Location

Domain port: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/port/`

Infrastructure files: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{operationName}/`
```
