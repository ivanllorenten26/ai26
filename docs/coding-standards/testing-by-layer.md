← [Testing Strategy](./testing-strategy.md)

# Testing by Layer

How each architectural layer is tested — what to write, how to structure it, and why.

- [Domain Layer — Indirect Testing](#domain-layer--indirect-testing)
- [Application Layer — Use Case Tests (BDD)](#application-layer--use-case-tests-bdd)
- [Feature Tests — BDD Acceptance Tests (HTTP)](#feature-tests--bdd-acceptance-tests-http)
- [Infrastructure Layer — Controller Tests](#infrastructure-layer--controller-tests)
- [Infrastructure Layer — Gateway Integration Tests](#infrastructure-layer--gateway-integration-tests)
- [E2E Smoke Tests](#e2e-smoke-tests)
- [Engineer Responsibilities per Test Level](#engineer-responsibilities-per-test-level)

For recipes with full code templates, see [Testing by Layer (recipes)](./recipes/testing.md) · [Mother Objects](./recipes/mother-objects.md).

---

## Domain Layer — Indirect Testing

Domain objects are tested **through use case tests**. Direct domain tests are added only for complex algorithms that would otherwise be untestable via use cases.

This is a key principle. Testing domain objects directly (e.g. `ConversationTest` that calls `Conversation.create()` and asserts on the result) is not wrong, but it is redundant if the use case test already exercises the same path. The exception is complex, self-contained algorithms (financial calculations, routing logic) where the number of cases would make the use case test unreadable. For those, a direct domain test is appropriate.

```kotlin
// YES — complex financial algorithm deserves direct testing
class LoanAmortizationScheduleTest {
    @Test
    fun `should calculate correct payment schedule for 12-month loan`() {
        val schedule = LoanAmortizationSchedule.calculate(
            principal = Money.of(12_000),
            annualRate = Rate.of(0.06),
            months = 12
        )
        schedule shouldHaveSize 12
        schedule.sumOf { it.principal } shouldBe Money.of(12_000)
    }
}

// NO — simple validation: covered by use case tests
class Conversation private constructor(...) {
    init {
        require(customerId.isNotBlank()) { "Customer ID cannot be blank" }
    }
    companion object {
        fun create(customerId: String, subject: String): Conversation { ... }
        // The init block require is exercised by every use case test — no direct test needed
    }
}
```

---

## Application Layer — Use Case Tests (BDD)

Use cases are the natural system under test. Each test method expresses one complete business behaviour, executed directly against the use case — no Spring context, no HTTP layer, no database. Tests instantiate the use case with mocked outbound ports and assert on the `Either` result.

Rules:
- Scenarios are documented as Gherkin docstring comments (`// Scenario: ...`) above each `@Test` method
- Test methods call the use case directly (not through HTTP)
- Outbound ports (repositories, event emitters) are mocked via MockK
- Domain objects are always real — never mock aggregates or value objects
- Every acceptance criterion from the design artefact maps to a test method
- Every error path in the error catalog has a test method
- Each `@Test` method starts with a `// Scenario:` block matching the scenario name in the `.features/{TICKET}/scenarios/` design artefact

BDD (Behaviour-Driven Development) means writing tests in the language of the business, not the language of the implementation. A scenario docstring that says "Given a customer with ID CUST-001, When I create a conversation with subject Billing issue, Then the conversation should be created with status OPEN" is readable by a product manager, a QA engineer, and a developer. The test implementation can change completely — the docstring captures the intent. This separation of business language from implementation is what makes BDD scenarios durable.

Because test methods call the use case directly, these tests run in milliseconds. They are the base of the pyramid: many fast tests covering every business scenario.

```kotlin
class CreateConversationUseCaseTest {

    private val repository = mockk<ConversationRepository>()
    private val eventEmitter = mockk<ConversationCreatedEventEmitter>(relaxed = true)
    private val clock = Clock.fixed(Instant.parse("2025-01-01T00:00:00Z"), ZoneOffset.UTC)

    private val createConversation = CreateConversation(repository, eventEmitter, clock)

    @Test
    fun `should create conversation when valid data provided`() {
        // Scenario: Successfully create a conversation
        //   Given a customer with ID "CUST-001" exists
        //   When I create a conversation with subject "Billing issue"
        //   Then the conversation should be created with status "OPEN"

        every { repository.save(any()) } answers { firstArg() }

        val result = createConversation(UUID.randomUUID(), "CUST-001")

        result.shouldBeInstanceOf<Either.Success<*>>()
        verify { repository.save(match { it.status == ConversationStatus.OPEN }) }
    }

    @Test
    fun `should return error when customer ID is blank`() {
        // Scenario: Reject blank customer ID
        //   When I create a conversation with customer ID "" and subject "Billing issue"
        //   Then I should receive an InvalidCustomer error

        val result = createConversation(UUID.randomUUID(), "")

        result.shouldBeInstanceOf<Either.Error<*>>()
        (result as Either.Error).value shouldBe CreateConversationError.InvalidCustomer
        verify(exactly = 0) { repository.save(any()) }
    }
}
```

Note the difference with level-4 feature tests (below): use case tests exercise the use case directly with mocked ports; feature tests drive the same scenarios through the HTTP API with real infrastructure. Both use Gherkin docstrings, but at different levels of the pyramid.

---

## Feature Tests — BDD Acceptance Tests (HTTP)

Feature tests verify the same business scenarios as use case tests, but driven through the full stack via the HTTP API. They confirm that the wiring between controller, use case, and infrastructure is correct. Because they start a Spring context and hit a real database (TestContainers), they are slower — use them to cover the happy path and the most critical error paths, not every permutation.

Rules:
- Test methods call the HTTP layer (controllers) via `TestRestTemplate`, never use cases directly
- Real infrastructure (PostgreSQL via TestContainers)
- One test method per acceptance criterion — not one per edge case
- Assertions check HTTP status codes, response bodies, and database state
- Each `@Test` method starts with a `// Scenario:` docstring matching the scenario name in the `.features/{TICKET}/scenarios/` design artefact

```kotlin
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@ActiveProfiles("test")
class CreateConversationFeatureTest {

    @Autowired private lateinit var restTemplate: TestRestTemplate
    @Autowired private lateinit var repository: JooqConversationRepository

    @BeforeEach
    fun setUp() { /* clean DB state between tests if needed */ }

    @Test
    fun `should open conversation via API`() {
        // Scenario: Successfully open a conversation via API
        //   Given a customer with ID "CUST-001" exists
        //   When I POST to /api/conversations with subject "Billing issue"
        //   Then I should receive a 201 response
        //   And the response body should contain status "OPEN"

        val response = restTemplate.postForEntity(
            "/api/conversations",
            mapOf("customerId" to "CUST-001", "subject" to "Billing issue"),
            ConversationResponse::class.java
        )

        response.statusCode shouldBe HttpStatus.CREATED
        response.body?.status shouldBe "OPEN"
    }

    @Test
    fun `should reject blank customer ID via API`() {
        // Scenario: Reject blank customer ID via API
        //   When I POST to /api/conversations with customer ID "" and subject "Billing issue"
        //   Then I should receive a 422 response

        val response = restTemplate.postForEntity(
            "/api/conversations",
            mapOf("customerId" to "", "subject" to "Billing issue"),
            Any::class.java
        )

        response.statusCode shouldBe HttpStatus.UNPROCESSABLE_ENTITY
    }
}
```

---

## Infrastructure Layer — Controller Tests

Controllers are humble objects. In a strict Clean Architecture interpretation they barely need tests — they contain no logic. However, in this project **controller tests are mandatory** because:
- They verify HTTP status codes and response shape (the contract with clients)
- They verify that `Either` left/right values map to the correct HTTP responses
- They catch serialisation/deserialisation regressions — a field renamed in the response DTO is a breaking change for consumers, and the controller test is the first place that regression surfaces.

Use `@WebMvcTest` — mock at the use case level, not at the repository level.

The controller maps `Either.Error` variants directly to `ResponseStatusException` — there is no intermediate `ApplicationException` class. The test verifies that the correct HTTP status code comes back for each `Either.Error` variant.

```kotlin
@WebMvcTest(ConversationController::class)
class ConversationControllerTest {

    @Autowired private lateinit var mockMvc: MockMvc
    @MockkBean private lateinit var createConversation: CreateConversationUseCase

    @Test
    fun `should return 201 when conversation is created`() {
        every { createConversation(any()) } returns Either.Success(
            ConversationDto(id = "conv-123", customerId = "CUST-001", subject = "Billing issue", status = "OPEN")
        )

        mockMvc.perform(
            post("/api/conversations")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"customerId":"CUST-001","subject":"Billing issue"}""")
        )
            .andExpect(status().isCreated)
            .andExpect(jsonPath("$.id").value("conv-123"))
    }

    @Test
    fun `should return 422 when use case returns a domain error`() {
        every { createConversation(any()) } returns Either.Error(ConversationError.InvalidCustomer)

        mockMvc.perform(
            post("/api/conversations")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"customerId":"","subject":"Billing issue"}""")
        )
            .andExpect(status().isUnprocessableEntity)
    }
}
```

---

## Infrastructure Layer — Gateway Integration Tests

Repositories are humble objects: they translate between domain objects and persistence. Integration tests verify this translation is correct.

These tests are the only place in the suite that runs against a real database. They verify three things: that the domain-to-persistence mapping is correct on save, that the persistence-to-domain mapping is correct on load, and that not-found cases return null (not an exception). We use a custom `@PersistenceIntegrationTest` annotation that wires up TestContainers and the JOOQ `DSLContext`.

Use TestContainers with a real PostgreSQL instance — never H2.

```kotlin
@PersistenceIntegrationTest
class JooqConversationRepositoryIntegrationTest {

    @Autowired private lateinit var repository: JooqConversationRepository

    @Test
    fun `should save and retrieve conversation with all fields intact`() {
        val conversation = ConversationMother.create()

        repository.save(conversation)
        val retrieved = repository.findById(conversation.id)

        retrieved shouldNotBe null
        retrieved!!.customerId shouldBe conversation.customerId
        retrieved.status shouldBe ConversationStatus.OPEN
    }

    @Test
    fun `should return null when conversation does not exist`() {
        val result = repository.findById(ConversationId.new())
        result shouldBe null
    }
}
```

---

## E2E Smoke Tests

Very few tests that verify the system is wired correctly end-to-end. These are not comprehensive — they exist to catch wiring failures that unit and integration tests cannot detect.

```kotlin
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class ConversationCreationE2ETest {

    @Container
    companion object {
        @JvmField val postgres = PostgreSQLContainer("postgres:15")
    }

    @Autowired private lateinit var testRestTemplate: TestRestTemplate

    @Test
    fun `should complete conversation creation end to end`() {
        val response = testRestTemplate.postForEntity(
            "/api/conversations",
            mapOf("customerId" to "CUST-001", "subject" to "Billing issue"),
            ConversationResponse::class.java
        )

        response.statusCode shouldBe HttpStatus.CREATED
        response.body?.id shouldNotBe null
    }
}
```

---

## Engineer Responsibilities per Test Level

The AI generates test scaffolding. You are responsible for the quality of the tests. Generated tests are starting points — they cover the happy path and the obvious error paths. Your job is to check completeness: are all error variants from the error catalog covered? Does the controller test verify every HTTP status code the endpoint can return? A test that always passes regardless of the implementation is worse than no test.

**Mother Objects deserve extra scrutiny.** Verify that:

- Every Mother **delegates to the domain factory** (`Conversation.create()`, `ConversationBlock.from()`) — never calls the constructor directly when a factory exists.
- Default parameter values are **random** (`UUID.randomUUID()`, `RandomValueGenerator.random<Enum>()`) — not hardcoded magic strings or zero IDs. Random defaults communicate that the parameter is irrelevant to the test.
- Only the parameter that matters for the specific test is overridden explicitly — this makes intent visible at the call site.
- **Domain entities are never mocked** (`mockk<Conversation>()`) — use `ConversationMother.create()` to exercise real invariants and business logic.

See [Mother Objects](./recipes/mother-objects.md) for the full template, anti-patterns, and references.

| Test level | What to review |
|---|---|
| Use case tests (BDD) | Gherkin docstring comments cover all happy paths and all error paths; test methods call the use case directly with mocked ports; assertions check `Either` result, not HTTP status |
| Integration tests | Tests cover save/find round-trip and not-found; data integrity is fully verified (all fields, not just ID) |
| Controller tests | Every HTTP status the controller can return has a test; response shape matches the API contract |
| Feature tests (BDD, HTTP) | Gherkin docstring comments match the acceptance criteria from the design documents; test methods exercise the full HTTP stack with TestContainers |
| Architecture tests | Generated once; do not modify — they enforce rules automatically in CI |