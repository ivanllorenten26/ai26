---
rules: [I-05, I-06]
---

← [Recipes Index](../how-to.md)

# Consuming External APIs

### When

Use this recipe when the `service/` module needs to call an external HTTP service (e.g. a payment gateway, a notification service, an internal microservice). This pattern applies whenever you cross a process boundary over HTTP.

### Template

Every outbound HTTP client is a 4-file bundle:

| File | Layer | Purpose                                                            |
|---|---|--------------------------------------------------------------------|
| `{ServiceName}Client.kt` | `domain/` | Domain port interface — zero framework imports                     |
| `{ServiceName}Api.kt` | `infrastructure/outbound/{serviceName}/` | `Retrofit` interface defining the HTTP contract + HTTP DTOs          |
| `{ServiceName}Adapter.kt` | `infrastructure/outbound/{serviceName}/` | Implements domain port; maps errors to `Either`; applies `@Retry`  |
| `{ServiceName}ClientConfig.kt` | `infrastructure/outbound/{serviceName}/` | `@Configuration` building `RestClient` + `HttpServiceProxyFactory` |

**1. Domain port (zero framework imports):**

```kotlin
// domain/PaymentClient.kt
interface PaymentClient {
    fun charge(customerId: String, amount: Long): Either<PaymentError, PaymentDTO>
}
```

**2. `Retrofit` API interface (HTTP contract only — no domain types):**

Request and Response DTOs (infrastructure-only data classes) must be defined as a nested class of the API interface. 

```kotlin
// infrastructure/outbound/payment/PaymentApi.kt
interface PaymentApi {
    @POST("/api/v1/charges")
    fun charge(@Body request: ChargeRequest): Call<ChargeResponse>
    
    data class ChargeRequest(val customerId: String, val amount: Long)
    data class ChargeResponse(val chargeId: String, val status: String)
}
```

**3. Adapter (checks `response.isSuccessful`, maps 4xx to `Either`, lets 5xx propagate for retry):**

Retrofit does **not** throw exceptions for HTTP error responses (4xx, 5xx) — it returns a `Response` where you check `isSuccessful`. Only network failures (`IOException`) throw. Always check `response.isSuccessful` explicitly.

```kotlin
// infrastructure/outbound/payment/PaymentAdapter.kt
@Component
class PaymentAdapter(private val api: PaymentApi) : PaymentClient {

    @Retry(name = "payment")
    override fun charge(customerId: String, amount: Long): Either<PaymentError, PaymentDTO> {
        val response = api.charge(PaymentApi.ChargeRequest(customerId, amount)).execute()

        if (!response.isSuccessful) {
            val status = HttpStatus.valueOf(response.code())
            if (status.is4xxClientError) {
                return Either.Error(PaymentError.Declined(response.code()))
            }
            // 5xx propagates — @Retry handles it
            throw ExternalServiceException.from(
                serviceName = "payment",
                httpStatus = status,
                "Payment charge failed for customer: $customerId",
            )
        }

        return Either.Success(response.body()!!.toDomainDTO())
    }
}
```

**4. Configuration:**

```kotlin
// infrastructure/outbound/payment/PaymentClientConfig.kt
@Configuration
@EnableConfigurationProperties(PaymentClientConfig.PaymentClientProperties::class)
class PaymentClientConfig(private val properties: PaymentClientProperties) {

    @ConfigurationProperties(prefix = "payment.client")
    data class PaymentClientProperties(
        override val url: URL,
        override val connectTimeout: Duration,
        override val readTimeout: Duration,
        override val writeTimeout: Duration,
    ) : HttpClientProperties

    @Bean
    fun paymentApi(factory: HttpClientFactory): PaymentApi = 
        factory.createClient(PaymentApi::class.java)
}
```

### Retry configuration

`@Retry(name = "payment")` references a named instance in `application.yml`. The name ties the annotation to its back-off policy — each external service gets its own instance so timeouts and retry counts can be tuned independently.

```yaml
# application.yml
resilience4j:
  retry:
    instances:
      payment:
        max-attempts: 3
        waitDuration: 500ms
        retryExceptions:
          - java.net.SocketTimeoutException
          - java.net.SocketException
          - de.tech26.valium.shared.http.errorhandling.ExternalServiceServerException
```

`retryExceptions` lists only transient failures — network timeouts and 5xx server errors wrapped in `ExternalServiceServerException`. 4xx client errors are **not** retried: they indicate a bad request that will keep failing.

The adapter throws for 5xx so `@Retry` can intercept it. If you catch everything and return `Either.Error`, the retry never fires:

```kotlin
// ✅ 5xx propagates — @Retry intercepts and retries up to max-attempts
if (status.is5xxServerError) {
    throw ExternalServiceServerException.from(serviceName = "payment", httpStatus = status, ...)
}

// ❌ Caught as Either — @Retry never sees it, no retry happens
} catch (ex: Exception) {
    return Either.Error(PaymentError.Unknown)
}
```

### Contract Testing

Every Retrofit adapter must have contract tests verifying all response scenarios:

```json
// testFixtures/resources/mappings/paymentApi/post-charges-success.json
{
  "request": {
    "method": "POST",
    "urlPath": "/api/v1/charges",
    "bodyPatterns": [
      { "matchesJsonPath": "$[?(@.customerId == 'CUST-001')]" },
      { "matchesJsonPath": "$[?(@.amount == 1000)]" }
    ]
  },
  "response": {
    "status": 200,
    "jsonBody": {"chargeId": "CHARGE-123", "status": "succeeded"}
  }
}
```

```kotlin
@ContractTest
class PaymentAdapterTest {
    
    @Autowired private lateinit var wireMockServer: WireMockServer
    @Autowired private lateinit var adapter: PaymentAdapter

    @Test
    fun `should return Success on 200`() {
        assertDoesNotThrow {
            adapter.charge("CUST-001", 1000)
        }

        wireMockServer.verify(
            1,
            postRequestedFor(urlPathEqualTo("/api/v1/charges"))
                .withRequestBody(matchingJsonPath("$.customerId", equalTo("CUST-001")))
                .withRequestBody(matchingJsonPath("$.amount", equalTo("1000")))
        )
    }

    @Test
    fun `should return Either.Error on 422`() { ... }

    @Test
    fun `should propagate exception on 500 (for @Retry)`() { ... }

    @Test
    fun `should propagate exception on timeout (for @Retry)`() { ... }
}
```

### Anti-Patterns

```kotlin
// ❌ Domain types in Retrofit interface — leaks domain model to HTTP layer
interface PaymentApi {
    @POST("/charges")
    fun charge(request: CreatePaymentCommand): Either<PaymentError, PaymentDTO>  // wrong
}

// ❌ Catch all exceptions as Either — hides 5xx, @Retry never fires
} catch (ex: Exception) {
    Either.Error(PaymentError.Unknown)  // 5xx should propagate for retry
}

// ❌ Framework annotation in domain port
@Component
interface PaymentClient  // domain must be framework-free

// ❌ Adapter placed flat in outbound/ instead of outbound/{serviceName}/
package de.tech26.valium.chat.infrastructure.outbound  // wrong
// ✅ Correct
package de.tech26.valium.chat.infrastructure.outbound.payment

// ❌ Hardcoded WireMock port in contract tests
val wiremock = WireMockServer(8090)  // flaky in CI; use dynamicPort()
```
