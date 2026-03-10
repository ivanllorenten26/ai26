---
name: dev-create-sqs-subscriber
description: Scaffolds an inbound SQS listener adapter as a humble object that delegates to a use case. Use when the service/ module needs to consume messages from an SQS queue.
argument-hint: [OperationName] in [module] — e.g. ConversationAnalysis in conversation
---

# Create SQS Subscriber

Scaffolds an inbound SQS listener adapter in `infrastructure/inbound/` using `@SqsListener`. The subscriber is a **humble object**: it receives the message, logs, and delegates to a use case. Zero business logic here. Use when the `service/` module needs to consume messages from an SQS queue.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create an SQS subscriber for `{OperationName}` in:

1. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{operationName}/SQS{OperationName}Subscriber.kt` — `@Service` listener with `@SqsListener`, delegates to use case, logs success/failure, rethrows on failure

Also update:
- The module's `@ConfigurationProperties` class: add `{operationName}QueueName: String` property if not already present (from `dev-create-sqs-publisher`)
- `service/src/main/resources/application.yml`: add `{module}.sqs.{operation-name}-queue-name: ""` placeholder if not already present

## Payload decision

| Payload type | Use when | Message parameter type |
|---|---|---|
| Simple (string) | The message is a single ID or opaque string | `String` — parse UUID/ID inside the listener |
| JSON | The message carries structured data | Data class — Spring's `SqsTemplate` deserializes automatically |

Ask the user which payload type applies if not specified in the arguments.

## Implementation Rules

- ✅ Subscriber is in `infrastructure/inbound/` (it is an entry point, like a controller)
- ✅ `@Service` class with `@SqsListener(value = ["\${module.sqs.{operation-name}-queue-name}"], messageVisibilitySeconds = 30)`
- ✅ Humble object: receives message, delegates to use case, logs, rethrows on failure — zero business logic
- ✅ `runCatching { useCase(...) }.onSuccess { log success }.onFailure { log failure; throw it.exception!! }` — **must rethrow** so SQS makes the message visible again for retry
- ✅ Simple payload: receive `String`, parse to domain ID inside listener
- ✅ JSON payload: receive the data class directly (`SqsTemplate` deserializes using `ObjectMapper`)
- ❌ No business logic in the subscriber — orchestration belongs in the use case
- ❌ Never swallow exceptions — always rethrow on failure so SQS retries the message
- ❌ Subscriber is NOT in `outbound/` — it is an inbound adapter (entry point)

## Example — Simple Payload (string)

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound.{operationName}

import {BASE_PACKAGE}.{module}.application.{TargetUseCase}
import {BASE_PACKAGE}.shared.logging.logger
import io.awspring.cloud.sqs.annotation.SqsListener
import org.springframework.stereotype.Service

@Service
class SQS{OperationName}Subscriber(
    private val {targetUseCase}: {TargetUseCase}
) {

    private val log = logger()

    @SqsListener(value = ["\${module.sqs.{operation-name}-queue-name}"], messageVisibilitySeconds = 30)
    fun receive(payload: String) {
        log.info("SQS{OperationName}Subscriber received message: {}", payload)
        runCatching {
            {targetUseCase}(payload)
        }.onSuccess {
            log.info("SQS{OperationName}Subscriber processed successfully: {}", payload)
        }.onFailure { ex ->
            log.error("SQS{OperationName}Subscriber failed to process: {}", payload, ex)
            throw ex
        }
    }
}
```

## Example — JSON Payload

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound.{operationName}

import {BASE_PACKAGE}.{module}.application.{TargetUseCase}
import {BASE_PACKAGE}.shared.logging.logger
import io.awspring.cloud.sqs.annotation.SqsListener
import org.springframework.stereotype.Service

@Service
class SQS{OperationName}Subscriber(
    private val {targetUseCase}: {TargetUseCase}
) {

    private val log = logger()

    @SqsListener(value = ["\${module.sqs.{operation-name}-queue-name}"], messageVisibilitySeconds = 30)
    fun receive(message: {OperationName}Message) {
        log.info("SQS{OperationName}Subscriber received message: {}", message.id)
        runCatching {
            {targetUseCase}(message.id, message.field1, message.field2)
        }.onSuccess {
            log.info("SQS{OperationName}Subscriber processed successfully: {}", message.id)
        }.onFailure { ex ->
            log.error("SQS{OperationName}Subscriber failed to process: {}", message.id, ex)
            throw ex
        }
    }
}
```

> For JSON payloads, the `{OperationName}Message` data class is typically created by `dev-create-sqs-publisher`. If the subscriber exists without a publisher, create a matching `internal data class` in the `inbound/{operationName}/` package.

## Configuration Properties

Ensure `{operationName}QueueName` exists in the module's `@ConfigurationProperties` class (add it if not already added by `dev-create-sqs-publisher`):

```kotlin
@ConfigurationProperties(prefix = "{module}.sqs")
data class {Module}SQSProperties(
    val {operationName}QueueName: String
)
```

Ensure `application.yml` has:
```yaml
{module}:
  sqs:
    {operation-name}-queue-name: ""
```

## Anti-Patterns

```kotlin
// ❌ Business logic in the subscriber — belongs in the use case
@SqsListener(...)
fun receive(payload: String) {
    val id = UUID.fromString(payload)
    if (repository.findById(id) == null) return  // domain logic in subscriber
    repository.save(...)
}

// ❌ Swallowing exceptions — SQS will not retry, message is silently lost
runCatching { useCase(payload) }  // no .onFailure — failures silently swallowed

// ❌ Subscriber in outbound/ — it is an inbound adapter (entry point), not an outbound adapter
package de.tech26.valium.chat.infrastructure.outbound.analysis  // wrong
// ✅ Correct
package de.tech26.valium.chat.infrastructure.inbound.analysis

// ❌ Hardcoded queue name in @SqsListener
@SqsListener(value = ["my-hardcoded-queue"])  // wrong
// ✅ Correct — use SpEL referencing @ConfigurationProperties
@SqsListener(value = ["\${conversation.sqs.analysis-queue-name}"])
```

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. Subscriber is in `infrastructure/inbound/{operationName}/`
3. `@SqsListener` value uses SpEL (`${...}`) — no hardcoded queue name
4. `runCatching { }.onFailure { throw it }` is present — failure rethrows
5. Zero business logic — only receive, log, delegate, rethrow

## Package Location

Place in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{operationName}/`
```
