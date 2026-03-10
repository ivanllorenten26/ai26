---
name: dev-create-sqs-redrive
description: Scaffolds a DLQ reprocessor that reads failed messages from a dead-letter queue and reprocesses them via the use case. Use when an SQS operation needs manual or scheduled DLQ replay.
argument-hint: [OperationName] in [module] — e.g. ConversationAnalysis in conversation
---

# Create SQS Redrive

Scaffolds a DLQ reprocessor in `infrastructure/inbound/` that reads failed messages from a dead-letter queue and reprocesses them via the use case. Uses manual acknowledgement so messages are only removed from the DLQ on success. Two sub-patterns are supported: **simple** (extends `SQSRedriveProcessor` base class) for string payloads, and **standalone** (uses `ObjectMapper`) for JSON payloads.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create an SQS redrive processor for `{OperationName}` in:

1. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{operationName}/SQS{OperationName}Redrive.kt` — DLQ reprocessor
2. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/shared/infrastructure/queue/SQSRedriveProcessor.kt` — abstract base class (**created once**, skip if the file already exists)

Also update:
- The module's `@ConfigurationProperties` class: add `{operationName}RedriveQueueName: String` property
- `service/src/main/resources/application.yml`: add `{module}.sqs.{operation-name}-redrive-queue-name: ""` placeholder

## Sub-pattern decision

| Sub-pattern | Use when | Extends base class? |
|---|---|---|
| Simple | Payload is a string (UUID, ID) | Yes — extends `SQSRedriveProcessor` |
| Complex (JSON) | Payload is a JSON object | No — standalone class with `ObjectMapper` |

Ask the user which sub-pattern applies if not specified in the arguments.

## Implementation Rules

### Both patterns
- ✅ Redrive is in `infrastructure/inbound/` (it is an entry point triggered by manual/scheduled action)
- ✅ Uses `@Qualifier("sqsTemplateManualAck")` `SqsTemplate` for manual acknowledgement
- ✅ Acknowledge only on success: `acknowledgement.acknowledgeAsync()` after successful processing
- ✅ On failure: log the error and skip acknowledgement — the message stays in the DLQ
- ✅ DLQ name sourced from `@ConfigurationProperties` — never hardcoded
- ❌ No `@SqsListener` — the redrive is invoked explicitly (e.g. via endpoint or scheduler), not auto-consumed

### Simple pattern (extends `SQSRedriveProcessor`)
- ✅ Extends `SQSRedriveProcessor` abstract base class
- ✅ Override `processMessage(payload: String, acknowledgement: Acknowledgement)`
- ✅ Parse the payload string to domain ID inside `processMessage()`
- ✅ Call use case, then `acknowledgement.acknowledgeAsync()`

### Complex/JSON pattern (standalone)
- ✅ Does NOT extend base class — reads messages with `sqsTemplate.receiveMany()`
- ✅ Uses `ObjectMapper` to deserialize the JSON payload into the message DTO
- ✅ Loops over received messages, processes each, acknowledges individually

### `SQSRedriveProcessor` abstract base class
```kotlin
// shared/infrastructure/queue/SQSRedriveProcessor.kt
// Created ONCE — skip if already exists
```
This class encapsulates `sqsTemplate.receiveMany()` and the loop. Concrete subclasses only override `processMessage()`.

## Example — Simple Pattern (extends base class)

### 1. Abstract Base Class (`shared/infrastructure/queue/SQSRedriveProcessor.kt`)
```kotlin
package {BASE_PACKAGE}.shared.infrastructure.queue

import io.awspring.cloud.sqs.operations.SqsTemplate
import io.awspring.cloud.sqs.operations.SqsReceiveOptions
import org.slf4j.LoggerFactory
import org.springframework.messaging.Message

abstract class SQSRedriveProcessor(
    private val sqsTemplate: SqsTemplate
) {

    private val log = LoggerFactory.getLogger(this::class.java)

    fun redrive(queueName: String, maxMessages: Int = 10) {
        log.info("Starting redrive from queue: {}", queueName)
        val messages = sqsTemplate.receiveMany(
            SqsReceiveOptions::class.java,
            Message::class.java
        ) { it.queue(queueName).maxNumberOfMessages(maxMessages) }

        messages.forEach { message ->
            runCatching {
                processMessage(message.payload.toString(), message.headers["Acknowledgment"] as io.awspring.cloud.sqs.listener.acknowledgement.Acknowledgement)
            }.onFailure { ex ->
                log.error("Failed to redrive message from {}: {}", queueName, message.payload, ex)
            }
        }
        log.info("Redrive complete. Processed {} messages from {}", messages.size, queueName)
    }

    protected abstract fun processMessage(payload: String, acknowledgement: io.awspring.cloud.sqs.listener.acknowledgement.Acknowledgement)
}
```

### 2. Concrete Redrive (simple payload)
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound.{operationName}

import {BASE_PACKAGE}.{module}.application.{TargetUseCase}
import {BASE_PACKAGE}.shared.infrastructure.queue.SQSRedriveProcessor
import {BASE_PACKAGE}.shared.logging.logger
import io.awspring.cloud.sqs.listener.acknowledgement.Acknowledgement
import io.awspring.cloud.sqs.operations.SqsTemplate
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.stereotype.Service

@Service
@EnableConfigurationProperties({Module}SQSProperties::class)
class SQS{OperationName}Redrive(
    @Qualifier("sqsTemplateManualAck") sqsTemplate: SqsTemplate,
    private val properties: {Module}SQSProperties,
    private val {targetUseCase}: {TargetUseCase}
) : SQSRedriveProcessor(sqsTemplate) {

    private val log = logger()

    fun redrive() = redrive(properties.{operationName}RedriveQueueName)

    override fun processMessage(payload: String, acknowledgement: Acknowledgement) {
        log.info("Redriving {OperationName} message: {}", payload)
        {targetUseCase}(payload)
        acknowledgement.acknowledgeAsync()
        log.info("Redrive acknowledged for {OperationName}: {}", payload)
    }
}
```

## Example — Complex/JSON Pattern (standalone)

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound.{operationName}

import {BASE_PACKAGE}.{module}.application.{TargetUseCase}
import {BASE_PACKAGE}.shared.logging.logger
import com.fasterxml.jackson.databind.ObjectMapper
import io.awspring.cloud.sqs.operations.SqsTemplate
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.stereotype.Service

@Service
@EnableConfigurationProperties({Module}SQSProperties::class)
class SQS{OperationName}Redrive(
    @Qualifier("sqsTemplateManualAck") private val sqsTemplate: SqsTemplate,
    private val properties: {Module}SQSProperties,
    private val {targetUseCase}: {TargetUseCase},
    private val objectMapper: ObjectMapper
) {

    private val log = logger()

    fun redrive() {
        log.info("Starting {OperationName} redrive from: {}", properties.{operationName}RedriveQueueName)
        val messages = sqsTemplate.receiveMany(String::class.java) {
            it.queue(properties.{operationName}RedriveQueueName).maxNumberOfMessages(10)
        }
        messages.forEach { message ->
            runCatching {
                val payload = objectMapper.readValue(message.payload, {OperationName}Message::class.java)
                {targetUseCase}(payload.id, payload.field1, payload.field2)
                message.headers["Acknowledgment"]
                    .let { it as io.awspring.cloud.sqs.listener.acknowledgement.Acknowledgement }
                    .acknowledgeAsync()
            }.onFailure { ex ->
                log.error("Failed to redrive {OperationName} message: {}", message.payload, ex)
            }
        }
    }
}
```

## Configuration Properties

Add `{operationName}RedriveQueueName` to the module's `@ConfigurationProperties`:

```kotlin
@ConfigurationProperties(prefix = "{module}.sqs")
data class {Module}SQSProperties(
    val {operationName}QueueName: String,         // from dev-create-sqs-publisher (if present)
    val {operationName}RedriveQueueName: String   // added by this skill
)
```

Add to `application.yml`:
```yaml
{module}:
  sqs:
    {operation-name}-queue-name: ""           # from dev-create-sqs-publisher (if present)
    {operation-name}-redrive-queue-name: ""   # added by this skill
```

The `sqsTemplateManualAck` bean must be configured in shared infrastructure. Add if not present:

```kotlin
// shared/infrastructure/queue/SQSAutoConfiguration.kt
@Configuration
class SQSAutoConfiguration {

    @Bean("sqsTemplateManualAck")
    fun sqsTemplateManualAck(sqsAsyncClient: SqsAsyncClient): SqsTemplate =
        SqsTemplate.builder()
            .sqsAsyncClient(sqsAsyncClient)
            .configure { it.acknowledgementMode(AcknowledgementMode.MANUAL) }
            .build()
}
```

## Anti-Patterns

```kotlin
// ❌ Auto-acknowledge (default) — message removed from DLQ even if processing fails
// Use @Qualifier("sqsTemplateManualAck") SqsTemplate for manual ack

// ❌ Using @SqsListener on redrive — redrive is explicitly triggered, not auto-consumed
@SqsListener(value = ["\${queue.name}"])  // wrong for redrive
fun redrive(payload: String) { ... }

// ❌ Hardcoded queue name
sqsTemplate.receiveMany { it.queue("my-dlq-hardcoded") }

// ❌ Acknowledging before successful processing — message lost on failure
acknowledgement.acknowledgeAsync()
useCase(payload)  // if this throws, message is already gone from DLQ

// ❌ Redrive placed in outbound/ — it is an inbound adapter (entry point)
package de.tech26.valium.chat.infrastructure.outbound.analysis  // wrong
// ✅ Correct
package de.tech26.valium.chat.infrastructure.inbound.analysis
```

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. Redrive is in `infrastructure/inbound/{operationName}/`
3. `@Qualifier("sqsTemplateManualAck")` is present on the `SqsTemplate` parameter
4. `acknowledgement.acknowledgeAsync()` is called **after** successful use case execution
5. On failure: error is logged, acknowledgement is skipped (message stays in DLQ)
6. Queue name sourced from `@ConfigurationProperties` — no hardcoded strings
7. `SQSRedriveProcessor.kt` exists in `shared/infrastructure/queue/` (simple pattern only)

## Package Location

Redrive: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{operationName}/`

Shared base: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/shared/infrastructure/queue/`
```
