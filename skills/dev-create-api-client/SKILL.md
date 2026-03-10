---
name: dev-create-api-client
description: Scaffolds outbound HTTP client adapters using Retrofit with configuration, retry, and error mapping. Use when you need to call an external service from the service/ module.
argument-hint: [ServiceName] calling [baseUrl/path] in [module]
---

# Create API Client

Scaffolds a complete outbound HTTP client adapter using Retrofit for HTTP client binding.
Creates 4 files: the domain port, the Retrofit API interface (with nested `Request`/`Response` DTOs),
the implementation class, and Spring configuration using `HttpClientFactory`. Use when the
`service/` module needs to call an external HTTP service.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package=de.tech26.valium`,
`main_source_root=service/src/main/kotlin`.

## Task

Create an outbound HTTP client for `{ServiceName}` in:

1. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/{ServiceName}Client.kt` — domain port interface (zero framework imports)
2. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{serviceName}/{ServiceName}Api.kt` — Retrofit interface with nested `Request` and `Response` data classes
3. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{serviceName}/{ExternalServiceName}{ServiceName}Client.kt` — implements domain port, delegates to Api, maps errors to `Either`, applies `@Retry`. Name the class by prefixing the external service name to the domain port name (e.g., `CaptanChatbotClient` implements `ChatbotClient`)
4. `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{serviceName}/{ServiceName}ClientConfig.kt` — `@Configuration` creating the Retrofit client bean via `HttpClientFactory`, with nested `{ServiceName}Properties` data class

## Implementation Rules

- ✅ Domain port: pure Kotlin interface in `{MODULE}/domain/`, returns `Either<DomainError, {ServiceName}DTO>`, zero framework imports
- ✅ Retrofit API interface: uses `@POST`, `@GET`, etc. with `Call<T>` return types. Contains nested `Request` and `Response` data classes. Works only with HTTP DTOs — no domain types
- ✅ Implementation class: named `{ExternalServiceName}{PortInterfaceName}` (e.g., `CaptanChatbotClient`); calls `api.method().execute()` and checks `response.isSuccessful` — Retrofit does **not** throw for HTTP errors (4xx/5xx), only for network failures (`IOException`). Maps 4xx to `Either.Error`, throws `ExternalServiceException` for 5xx so `@Retry` can handle it
- ✅ Config: uses `HttpClientFactory.createClient({ServiceName}Api::class.java)` to build the Retrofit client; nests `{ServiceName}Properties` as a `@ConfigurationProperties` data class inside the config file implementing `HttpClientProperties`
- ✅ Resilience4j `@Retry(name = "{serviceName}")` on implementation class methods
- ✅ Infrastructure classes in `outbound/{serviceName}/` subdirectory — never flat in `outbound/`
- ✅ HTTP DTOs (`Request`, `Response`) are nested data classes inside `{ServiceName}Api` — they belong to infrastructure only
- ❌ No domain types (`Either`, domain entities) in `{ServiceName}Api.kt` — it is a pure HTTP contract
- ❌ No framework annotations (`@Component`, `@Service`) in domain port interface
- ❌ No business logic in implementation class — orchestration belongs in use cases

### Required dependency (add to `service/build.gradle.kts` if not present)
```kotlin
implementation(libs.resilience4j.spring.boot3)
```

## Example Implementation

### 1. Domain Port
```kotlin
package {BASE_PACKAGE}.{module}.domain

import {BASE_PACKAGE}.shared.kernel.Either

interface {ServiceName}Client {
    fun get{Resource}(id: String): Either<{ServiceName}Error, {ServiceName}DTO>
}
```

### 2. Retrofit API Interface (with nested DTOs)
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{serviceName}

import retrofit2.Call
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface {ServiceName}Api {

    @GET("/api/v1/{resource}/{id}")
    fun get{Resource}(@Path("id") id: String): Call<{ServiceName}Api.Response>

    @POST("/api/v1/{resource}")
    fun create{Resource}(@Body request: {ServiceName}Api.Request): Call<{ServiceName}Api.Response>

    data class Request(
        val field1: String,
        val field2: String
    )

    data class Response(
        val id: String,
        val field1: String,
        val field2: String
    )
}
```

### 3. Implementation Class
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{serviceName}

import {BASE_PACKAGE}.{module}.domain.{ServiceName}Client
import {BASE_PACKAGE}.{module}.domain.{ServiceName}DTO
import {BASE_PACKAGE}.{module}.domain.{ServiceName}Error
import {BASE_PACKAGE}.shared.kernel.Either
import io.github.resilience4j.retry.annotation.Retry
import org.springframework.stereotype.Component

@Component
class {ExternalServiceName}{ServiceName}Client(
    private val api: {ServiceName}Api
) : {ServiceName}Client {

    @Retry(name = "{serviceName}")
    override fun get{Resource}(id: String): Either<{ServiceName}Error, {ServiceName}DTO> {
        val response = api.get{Resource}(id).execute()

        if (!response.isSuccessful) {
            val status = HttpStatus.valueOf(response.code())
            if (status.is4xxClientError) {
                return Either.Error({ServiceName}Error.NotFound(id))
            }
            // 5xx — throw so @Retry can handle it
            throw ExternalServiceException.from(
                serviceName = "{serviceName}",
                httpStatus = status,
                "Failed to get {resource}: $id",
            )
        }

        return Either.Success(response.body()!!.toDomainDTO())
    }

    private fun {ServiceName}Api.Response.toDomainDTO(): {ServiceName}DTO =
        {ServiceName}DTO(
            id = this.id,
            // ... map remaining fields
        )
}
```

### 4. Configuration (with nested Properties)
```kotlin
package {BASE_PACKAGE}.{module}.infrastructure.outbound.{serviceName}

import {BASE_PACKAGE}.shared.http.client.HttpClientFactory
import {BASE_PACKAGE}.shared.http.client.HttpClientProperties
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.net.URL
import java.time.Duration

@Configuration
@EnableConfigurationProperties({ServiceName}ClientConfig.{ServiceName}Properties::class)
class {ServiceName}ClientConfig(
    private val properties: {ServiceName}Properties
) {

    @Bean
    fun {serviceName}Api(factory: HttpClientFactory): {ServiceName}Api =
        factory.createClient({ServiceName}Api::class.java)

    @ConfigurationProperties(prefix = "{module}.client.{service-name}")
    data class {ServiceName}Properties(
        override val url: URL,
        override val connectTimeout: Duration = Duration.ofSeconds(5),
        override val readTimeout: Duration = Duration.ofSeconds(30),
        override val writeTimeout: Duration = Duration.ofSeconds(30),
    ) : HttpClientProperties
}
```

## Anti-Patterns

```kotlin
// ❌ Domain types in Retrofit interface — leaks domain model to HTTP layer
interface PaymentApi {
    @POST("/charges")
    fun charge(request: CreatePaymentCommand): Call<Either<PaymentError, PaymentDTO>>  // wrong
}

// ❌ Domain port with framework annotation
import org.springframework.stereotype.Component

@Component  // ← infrastructure concern in domain
interface PaymentClient {
    fun getPayment(id: String): Either<PaymentError, PaymentDTO>
}

// ❌ Adapter placed flat in outbound/ instead of outbound/{serviceName}/
package de.tech26.valium.chat.infrastructure.outbound  // wrong
// ✅ Correct
package de.tech26.valium.chat.infrastructure.outbound.payment

// ❌ Catching all exceptions and wrapping as Either — hides 5xx so @Retry never fires
} catch (ex: Exception) {
    Either.Error(PaymentError.Unknown)  // 5xx should propagate for retry
}

// ❌ Separate DTO files for request/response — nest them inside the Api interface instead
// {ServiceName}ApiRequest.kt  ← wrong: separate file
// {ServiceName}ApiResponse.kt ← wrong: separate file
// ✅ Correct: nest as data classes inside {ServiceName}Api

// ❌ Separate properties file — nest Properties inside the Config class instead
// {ServiceName}ClientProperties.kt ← wrong: separate file
// ✅ Correct: nest as {ServiceName}Properties data class inside {ServiceName}ClientConfig

// ❌ Generic "Adapter" suffix that hides which external service is being called
class PaymentAdapter(...)  // wrong: which payment provider?
// ✅ Correct: prefix with external service name to make it self-documenting
class StripePaymentClient(...)
```

## Verification

1. Exactly 4 files created: `{ServiceName}Client.kt`, `{ServiceName}Api.kt`, `{ExternalServiceName}{ServiceName}Client.kt`, `{ServiceName}ClientConfig.kt`
2. No separate `{ServiceName}ApiRequest.kt`, `{ServiceName}ApiResponse.kt`, or `{ServiceName}ClientProperties.kt` files exist
3. `{ServiceName}Api.kt` contains nested `Request` and `Response` data classes using `Call<T>` return types
4. `{ServiceName}ClientConfig.kt` contains nested `{ServiceName}Properties` implementing `HttpClientProperties`
5. Implementation class is named `{ExternalServiceName}{PortInterfaceName}` (e.g., `CaptanChatbotClient`)
6. Domain port (`{ServiceName}Client.kt`) has zero framework imports
7. `@Retry` annotation is present on implementation class methods
8. File compiles: `./gradlew service:compileKotlin`

## Package Location

Place all infrastructure files in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/infrastructure/outbound/{serviceName}/`

Domain port in: `{MAIN_SRC}/{BASE_PACKAGE_PATH}/{MODULE}/domain/`
