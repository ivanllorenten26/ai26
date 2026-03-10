---
name: dev-create-kafka-publisher
description: Scaffolds an outbound Kafka publisher for a domain event or an aggregate event envelope (sealed class with one variant per transition), using KafkaTemplate<String, ByteArray> and Jackson. Follows the sopranium pattern — one Kafka topic per aggregate, consumers distinguish transitions via the sealed class variant. Use when the service/ module needs to produce messages to a Kafka topic.
argument-hint: [EventName] in [module] — e.g. ConversationClosed in conversation
---

# Create Kafka Publisher

Scaffolds an outbound Kafka publisher for a domain event using `KafkaTemplate<String, ByteArray>` with Jackson serialization. Creates the domain port interface (zero framework imports), the producer `@Configuration`, and the infrastructure adapter. Use when the `service/` module needs to publish events to a Kafka topic.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create a Kafka publisher for `{EventName}` in:

1. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/port/{EventName}Publisher.kt` — domain port interface (zero framework imports, parameter is a domain DTO)
2. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{eventName}/{EventName}ProducerKafkaConfiguration.kt` — `@Configuration` that declares the `KafkaTemplate<String, ByteArray>` bean
3. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{eventName}/{EventName}KafkaPublisher.kt` — `@Service` adapter implementing the domain port; serializes the event with `ObjectMapper`, sends via `KafkaTemplate`

Also update:
- `service/src/main/resources/application.yml`: add topic placeholder under the module section

## Implementation Rules

- ✅ Domain port: pure Kotlin interface in `{MODULE}/domain/port/`, zero framework imports, returns `Unit`
- ✅ Producer config: `@Configuration`, `@EnableConfigurationProperties(KafkaProperties::class)`, builds `KafkaTemplate<String, ByteArray>` via `kafkaProperties.buildProducerProperties()` + `StringSerializer` + `ByteArraySerializer`, sets `CLIENT_ID_CONFIG` to `"{module}-kafka-producer"`
- ✅ Publisher adapter: `@Service`, implements domain port, topic injected via `@Value("\${spring.kafka.producer.{event-name}-stream-out.destination}")`
- ✅ Serialization: `objectMapper.writeValueAsBytes(event)` — Jackson, not Protobuf
- ✅ Message key: use the aggregate ID or a stable business key (e.g. `conversationId.value.toString()`)
- ✅ Error wrapping: `runCatching { kafkaTemplate.send(...) }.onFailure { throw ExternalServiceServerException(...) }`
- ✅ Topic name: always from `@Value` — never hardcoded
- ❌ No framework imports in the domain port
- ❌ No custom `Serializer<T>` class — use `ByteArraySerializer` + Jackson instead
- ❌ No `ACKS`, `RETRIES`, `ENABLE_IDEMPOTENCE` manual config — rely on `buildProducerProperties()` base
- ❌ No `Either` on the domain port — returns `Unit`, throws `ExternalServiceServerException` on failure
- ❌ Do not use `KafkaTemplate<String, EventDto>` — always `KafkaTemplate<String, ByteArray>`

### Required dependencies (add to `service/build.gradle.kts` if not present)

```kotlin
implementation(libs.spring.kafka)
```

## Example Implementation

### 1. Domain Port

```kotlin
package {BASE_PACKAGE}.{module}.domain.port

import {BASE_PACKAGE}.{module}.domain.{EventName}Dto

interface {EventName}Publisher {
    fun publish({event}: {EventName}Dto)
}
```

### 2. Producer Configuration

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{eventName}

import org.apache.kafka.clients.CommonClientConfigs.CLIENT_ID_CONFIG
import org.apache.kafka.common.serialization.ByteArraySerializer
import org.apache.kafka.common.serialization.StringSerializer
import org.springframework.boot.autoconfigure.kafka.KafkaProperties
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.kafka.core.DefaultKafkaProducerFactory
import org.springframework.kafka.core.KafkaTemplate

@Configuration
@EnableConfigurationProperties(KafkaProperties::class)
class {EventName}ProducerKafkaConfiguration {

    @Bean
    fun {eventName}KafkaTemplate(kafkaProperties: KafkaProperties): KafkaTemplate<String, ByteArray> =
        kafkaProperties
            .buildProducerProperties()
            .also { it[CLIENT_ID_CONFIG] = "{module}-kafka-producer" }
            .let { DefaultKafkaProducerFactory(it, StringSerializer(), ByteArraySerializer()) }
            .let { KafkaTemplate(it) }
}
```

### 3. Publisher Adapter

```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{eventName}

import {BASE_PACKAGE}.{module}.domain.port.{EventName}Publisher
import {BASE_PACKAGE}.{module}.domain.{EventName}Dto
import de.tech26.valium.shared.http.errorhandling.ExternalServiceServerException
import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.kafka.core.KafkaTemplate
import org.springframework.stereotype.Service

@Service
class {EventName}KafkaPublisher(
    private val kafkaTemplate: KafkaTemplate<String, ByteArray>,
    private val objectMapper: ObjectMapper,
    @Value("\${spring.kafka.producer.{event-name}-stream-out.destination}")
    private val topic: String,
) : {EventName}Publisher {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun publish({event}: {EventName}Dto) {
        val key = {event}.id.toString()
        runCatching {
            val bytes = objectMapper.writeValueAsBytes({event})
            kafkaTemplate.send(topic, key, bytes)
            log.info("{EventName}KafkaPublisher sent event: key={}", key)
        }.onFailure {
            log.error("{EventName}KafkaPublisher failed to send event: key={}", key, it)
            throw ExternalServiceServerException(
                serviceName = "Kafka",
                message = "Failed to publish {EventName}: $key",
                httpStatus = HttpStatus.INTERNAL_SERVER_ERROR,
                cause = it,
            )
        }
    }
}
```

### 4. application.yml

```yaml
spring:
  kafka:
    producer:
      {event-name}-stream-out:
        destination: ""   # TODO: set topic name per environment
```

## Publishing an Aggregate Event Envelope

> **Pattern origin:** Sopranium publishes all `InternalPayment` transitions (created, captured, failed, refunded…) to a single Kafka topic using `InternalPaymentEvent` — a sealed/`oneof` wrapper. See `n26/proto/app/sopranium/internalpayment/v1/internal_payment_events.proto` in argon.

When your aggregate emits multiple event types wrapped in a `sealed class {Aggregate}Event`, the publisher receives the **envelope** — not individual variants.

**Why one topic per aggregate?**
- Consumers interested in all lifecycle events of a `Conversation` subscribe to one topic.
- If you published to separate topics (`conversation.created.v1`, `conversation.closed.v1`, …), a consumer who needs to reconstruct state would have to subscribe to N topics and handle ordering across partitions.
- The sealed class variant tells the consumer exactly which transition happened — no separate topic needed.

**Domain port for an envelope publisher:**

```kotlin
// domain/port/ConversationEventPublisher.kt
interface ConversationEventPublisher {
    fun publish(event: ConversationEvent)  // sealed class — covers all variants
}
```

**Infrastructure adapter:**

```kotlin
// infrastructure/outbound/conversationevent/ConversationEventKafkaPublisher.kt
@Service
class ConversationEventKafkaPublisher(
    private val kafkaTemplate: KafkaTemplate<String, ByteArray>,
    private val objectMapper: ObjectMapper,
    @Value("\${spring.kafka.producer.conversation-event-stream-out.destination}")
    private val topic: String,
) : ConversationEventPublisher {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun publish(event: ConversationEvent) {
        val key = event.snapshot.id.toString()    // stable key = aggregate ID
        runCatching {
            val bytes = objectMapper.writeValueAsBytes(event)
            kafkaTemplate.send(topic, key, bytes)
            log.info("ConversationEventKafkaPublisher sent {} key={}",
                event::class.simpleName, key)
        }.onFailure {
            log.error("ConversationEventKafkaPublisher failed key={}", key, it)
            throw ExternalServiceServerException(
                serviceName = "Kafka",
                message = "Failed to publish ConversationEvent: $key",
                httpStatus = HttpStatus.INTERNAL_SERVER_ERROR,
                cause = it,
            )
        }
    }
}
```

> **Jackson tip:** Jackson serializes a `sealed class` by default as the subtype's fields. To preserve the type discriminator for consumers, configure the `ObjectMapper` with `@JsonTypeInfo` on the sealed class, or use a Jackson module that handles Kotlin sealed classes. The simplest option is to add `@JsonTypeInfo(use = NAME, property = "eventType")` on the sealed class — that way the JSON payload always includes the variant name.

## Anti-Patterns

```kotlin
// ❌ Custom Serializer class — unnecessary with ByteArraySerializer + Jackson
class ConversationClosedSerializer : Serializer<ConversationClosedDto> { ... }

// ❌ KafkaTemplate<String, EventDto> — couples infrastructure to domain type
@Bean fun kafkaTemplate(): KafkaTemplate<String, ConversationClosedDto> = ...

// ❌ Hardcoded topic — impossible to configure per environment
kafkaTemplate.send("valium.conversation.closed.v1", key, bytes)

// ❌ Manual producer properties — bypasses team-standard buildProducerProperties() base
props[ProducerConfig.ACKS_CONFIG] = "all"
props[ProducerConfig.RETRIES_CONFIG] = Int.MAX_VALUE

// ❌ Framework annotation in domain port
import org.springframework.stereotype.Component
interface ConversationClosedPublisher : Component   // domain must be framework-free

// ❌ Swallowing failures — runCatching with no .onFailure
runCatching { kafkaTemplate.send(topic, key, bytes) }  // silent failure

// ❌ One Kafka topic per event variant — forces consumers to subscribe to N topics
// for the same aggregate and handle cross-partition ordering
kafkaTemplate.send("conversation.created.v1",    key, bytes)   // ❌
kafkaTemplate.send("conversation.agent-assigned.v1", key, bytes) // ❌
kafkaTemplate.send("conversation.closed.v1",     key, bytes)   // ❌
// ✅ One topic, sealed class discriminates the variant
kafkaTemplate.send("conversation.events.v1",     key, bytes)   // ✅

// ❌ Publishing individual variants directly instead of the envelope
interface ConversationCreatedPublisher { fun publish(e: ConversationEvent.ConversationCreated) }
interface ConversationClosedPublisher  { fun publish(e: ConversationEvent.ConversationClosed) }
// ✅ One publisher for the whole aggregate
interface ConversationEventPublisher   { fun publish(event: ConversationEvent) }
```

## Verification

1. File compiles: `./gradlew service:compileKotlin`
2. Domain port (`{EventName}Publisher.kt`) has zero framework imports
3. `{EventName}ProducerKafkaConfiguration.kt` uses `KafkaTemplate<String, ByteArray>`
4. Topic sourced from `@Value("${...}")` — no hardcoded strings
5. `runCatching { }.onFailure { throw ExternalServiceServerException(...) }` is present
6. Publisher is in `infrastructure/outbound/{eventName}/` subdirectory

## Package Location

Domain port: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/port/`

Infrastructure files: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{eventName}/`
