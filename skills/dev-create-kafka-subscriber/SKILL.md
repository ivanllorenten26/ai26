---
name: dev-create-kafka-subscriber
description: Scaffolds an inbound Kafka listener adapter as a humble object that delegates to a use case, with ExponentialBackOff retry and manual acknowledgment. Use when the service/ module needs to consume messages from a Kafka topic.
argument-hint: [EventName] in [module] — e.g. ConversationClosed in conversation
---

# Create Kafka Subscriber

Scaffolds an inbound Kafka consumer in `infrastructure/inbound/` as a **humble object**: receives the message, deserializes, delegates to a use case, acknowledges on success, rethrows on failure. Uses `ExponentialBackOffWithMaxRetries` with configurable `KafkaRetryBackoffProperties` and manual acknowledgment. Use when the `service/` module needs to consume events from a Kafka topic.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create a Kafka subscriber for `{EventName}` in:

1. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/kafka/KafkaRetryBackoffProperties.kt` — `@ConfigurationProperties` for retry configuration. **Skip if it already exists in the module** (shared across all subscribers in the same module).
2. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{eventName}/{EventName}ConsumerKafkaConfiguration.kt` — `@Configuration` declaring the `ConsumerFactory`, `ConcurrentKafkaListenerContainerFactory`, and `DefaultErrorHandler` with `ExponentialBackOffWithMaxRetries`
3. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{eventName}/{EventName}KafkaSubscriber.kt` — `@Component` humble object with `@KafkaListener`, deserializes the payload, delegates to use case, acknowledges on success, rethrows on failure

Also update:
- `service/src/main/resources/application.yml`: add topic, group-id, and retry backoff placeholders

## Implementation Rules

- ✅ Subscriber is in `infrastructure/inbound/` (it is an entry point, like a REST controller)
- ✅ Humble object: zero business logic — only deserialize, log, delegate, ack/rethrow
- ✅ `@Component` on the subscriber class with `@KafkaListener` on the handler method
- ✅ Topic from `@Value("\${spring.kafka.consumer.{event-name}-stream-in.destination}")`
- ✅ Group-id from `@Value("\${spring.kafka.consumer.{event-name}-stream-in.group-id}")`
- ✅ `containerFactory = "{eventName}KafkaListenerContainerFactory"` — per-event factory bean
- ✅ `ackMode = MANUAL` — call `ack.acknowledge()` on success only
- ✅ **Must rethrow on failure** — so the error handler retries with `ExponentialBackOffWithMaxRetries`
- ✅ `KafkaRetryBackoffProperties` shared at `infrastructure/inbound/kafka/` — one per module, not one per event
- ✅ Error handler: `DefaultErrorHandler(ExponentialBackOffWithMaxRetries(maxRetries))` with `initialInterval`, `multiplier`, and `maxInterval` from `KafkaRetryBackoffProperties`
- ✅ Deserialize: `objectMapper.readValue(record.value(), {EventName}Dto::class.java)` — never pass raw `ByteArray` to use case
- ❌ No business logic in the subscriber — it belongs in the use case
- ❌ Never call `ack.acknowledge()` before the use case succeeds — message must be re-delivered on failure
- ❌ Never swallow exceptions — always rethrow so the error handler retries
- ❌ Subscriber is NOT in `outbound/` — it is an inbound adapter
- ❌ Do not use a single global container factory for all events — create one per event for isolation

### Required dependencies (add to `service/build.gradle.kts` if not present)

```kotlin
implementation(libs.spring.kafka)
```

## Example Implementation

### 1. Shared Retry Properties (one per module)

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound.kafka

import jakarta.validation.constraints.NotNull
import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.Duration

@ConfigurationProperties(prefix = "spring.kafka.retry.backoff")
data class KafkaRetryBackoffProperties(
    @NotNull val initialInterval: Duration,
    @NotNull val multiplier: Double,
    @NotNull val maxInterval: Duration,
    @NotNull val maxRetries: Int,
)
```

### 2. Consumer Configuration

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound.{eventName}

import {BASE_PACKAGE}.{module}.infrastructure.inbound.kafka.KafkaRetryBackoffProperties
import org.apache.kafka.common.serialization.ByteArrayDeserializer
import org.apache.kafka.common.serialization.StringDeserializer
import org.springframework.boot.autoconfigure.kafka.KafkaProperties
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.kafka.annotation.EnableKafka
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory
import org.springframework.kafka.core.DefaultKafkaConsumerFactory
import org.springframework.kafka.listener.ContainerProperties.AckMode.MANUAL
import org.springframework.kafka.listener.DefaultErrorHandler
import org.springframework.kafka.support.ExponentialBackOffWithMaxRetries

@EnableKafka
@Configuration
@EnableConfigurationProperties(KafkaProperties::class, KafkaRetryBackoffProperties::class)
class {EventName}ConsumerKafkaConfiguration(
    private val retryBackoffProperties: KafkaRetryBackoffProperties,
) {

    @Bean
    fun {eventName}KafkaListenerContainerFactory(
        kafkaProperties: KafkaProperties,
    ): ConcurrentKafkaListenerContainerFactory<String, ByteArray> {
        val factory = ConcurrentKafkaListenerContainerFactory<String, ByteArray>()
        factory.consumerFactory = DefaultKafkaConsumerFactory(
            kafkaProperties.buildConsumerProperties(),
            StringDeserializer(),
            ByteArrayDeserializer(),
        )
        factory.containerProperties.ackMode = MANUAL
        factory.setCommonErrorHandler(errorHandler())
        return factory
    }

    private fun errorHandler(): DefaultErrorHandler {
        val backOff = ExponentialBackOffWithMaxRetries(retryBackoffProperties.maxRetries).apply {
            initialInterval = retryBackoffProperties.initialInterval.toMillis()
            multiplier = retryBackoffProperties.multiplier
            maxInterval = retryBackoffProperties.maxInterval.toMillis()
        }
        return DefaultErrorHandler(backOff)
    }
}
```

### 3. Subscriber (Humble Object)

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.inbound.{eventName}

import {BASE_PACKAGE}.{module}.application.{TargetUseCase}
import {BASE_PACKAGE}.{module}.domain.{EventName}Dto
import com.fasterxml.jackson.databind.ObjectMapper
import org.apache.kafka.clients.consumer.ConsumerRecord
import org.slf4j.LoggerFactory
import org.springframework.kafka.annotation.KafkaListener
import org.springframework.kafka.support.Acknowledgment
import org.springframework.stereotype.Component
import org.springframework.beans.factory.annotation.Value

private const val {EVENT_NAME}_LISTENER_ID = "{module}-{event-name}-consumer"

@Component
class {EventName}KafkaSubscriber(
    private val {targetUseCase}: {TargetUseCase},
    private val objectMapper: ObjectMapper,
    @Value("\${spring.kafka.consumer.{event-name}-stream-in.destination}")
    private val topic: String,
    @Value("\${spring.kafka.consumer.{event-name}-stream-in.group-id}")
    private val groupId: String,
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @KafkaListener(
        id = {EVENT_NAME}_LISTENER_ID,
        topics = ["\${spring.kafka.consumer.{event-name}-stream-in.destination}"],
        groupId = "\${spring.kafka.consumer.{event-name}-stream-in.group-id}",
        containerFactory = "{eventName}KafkaListenerContainerFactory",
    )
    fun receive(record: ConsumerRecord<String, ByteArray>, ack: Acknowledgment) {
        val key = record.key()
        log.info("{EventName}KafkaSubscriber received message: key={}", key)
        runCatching {
            val event = objectMapper.readValue(record.value(), {EventName}Dto::class.java)
            {targetUseCase}(event)
        }.onSuccess {
            ack.acknowledge()
            log.info("{EventName}KafkaSubscriber processed successfully: key={}", key)
        }.onFailure { ex ->
            log.error("{EventName}KafkaSubscriber failed to process: key={}", key, ex)
            throw ex
        }
    }
}
```

### 4. application.yml

```yaml
spring:
  kafka:
    consumer:
      {event-name}-stream-in:
        destination: ""       # TODO: set topic name per environment
        group-id: "valium"    # TODO: adjust if isolation required
    retry:
      backoff:
        initial-interval: 1s
        multiplier: 2.0
        max-interval: 30s
        max-retries: 3
```

## Anti-Patterns

```kotlin
// ❌ Business logic in the subscriber — belongs in the use case
@KafkaListener(...)
fun receive(record: ConsumerRecord<String, ByteArray>, ack: Acknowledgment) {
    val event = objectMapper.readValue(record.value(), ConversationClosedDto::class.java)
    if (event.status == "OPEN") return   // domain logic here — wrong
    repository.save(...)
}

// ❌ Acknowledging before the use case completes — message lost if use case fails
runCatching {
    ack.acknowledge()   // wrong: ack before processing
    useCase(event)
}

// ❌ Swallowing the exception — error handler never retries, message is silently dropped
runCatching { useCase(event) }.onSuccess { ack.acknowledge() }
// missing .onFailure { throw ex }

// ❌ Subscriber in outbound/ — it is an inbound entry point, not an outbound adapter
package de.tech26.valium.conversation.infrastructure.outbound.conversationClosed  // wrong
// ✅ Correct
package de.tech26.valium.conversation.infrastructure.inbound.conversationClosed

// ❌ Global shared container factory for all events — no isolation, harder to tune per event
@KafkaListener(containerFactory = "defaultKafkaListenerContainerFactory")

// ❌ Passing raw ByteArray to the use case — use case should not depend on serialization
useCase(record.value())   // wrong: ByteArray leaks infrastructure concern into application layer
```

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. `{EventName}KafkaSubscriber.kt` has zero domain/application logic — only deserialize, delegate, ack/rethrow
3. `ack.acknowledge()` is called only inside `.onSuccess { }` block
4. `.onFailure { throw ex }` is present — exception is always rethrown
5. `containerFactory` references the per-event bean `{eventName}KafkaListenerContainerFactory`
6. `KafkaRetryBackoffProperties` is in `infrastructure/inbound/kafka/` (shared across the module)
7. `ExponentialBackOffWithMaxRetries` is used (not `FixedBackOff`)

## Package Location

Properties: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/kafka/`

Consumer config and subscriber: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/inbound/{eventName}/`
