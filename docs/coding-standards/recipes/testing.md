---
rules: [T-01, T-02, T-03, T-04, T-05, T-06, T-07, T-08]
---

← [Recipes Index](../how-to.md)

# Testing by Layer

### Decision table

| Layer | Test type | Framework | What to mock |
|---|---|---|---|
| Use case (application) | Unit test (BDD-style) | JUnit 5 + MockK + AssertJ | Only outbound ports (repositories, emitters) |
| Controller (infrastructure/inbound) | `@WebMvcTest` slice | MockMvc + MockK | Only the use case |
| Repository (infrastructure/outbound) | Integration test | TestContainers (PostgreSQL) | Nothing — real DB |
| Full stack | BDD feature test (Gherkin docstring) | JUnit 5 + TestRestTemplate + TestContainers | Nothing |
| Architecture rules | ArchUnit | ArchUnit | Nothing |

**Mandatory tests**: controller tests + BDD feature tests are required for every endpoint, not optional.

### Use case test (mock only outbound ports)

Mock only the outbound ports (repositories, emitters) — never the domain entities themselves. Using real entities means the test exercises actual business logic and catches invariant bugs; using Mother Objects keeps test data readable and consistent. The test verifies both the `Either` return value and the `save()` call to confirm the aggregate was persisted in the correct state.

```kotlin
class CloseConversationUseCaseTest {

    private val conversationRepository = mockk<ConversationRepository>()
    private val sut = CloseConversation(conversationRepository)

    @Test
    fun `should close an open conversation`() {
        // Scenario: Successfully close a conversation
        //   Given an open conversation exists
        //   When I close the conversation
        //   Then the conversation should be closed
        //   And the conversation should be saved

        val conversation = ConversationMother.create()
        every { conversationRepository.findById(conversation.id) } returns conversation
        every { conversationRepository.save(any()) } answers { firstArg() }

        val result = sut(conversation.id)

        val closed = conversation.close().getOrElse { error("unexpected") }
        assertThat(result).isEqualTo(Either.Success(closed.toDTO()))
        verify { conversationRepository.save(match { it.status == ConversationStatus.CLOSED }) }
    }

    @Test
    fun `should return error when conversation not found`() {
        // Scenario: Return error when conversation does not exist
        //   Given no conversation exists with the given ID
        //   When I close the conversation
        //   Then I should receive a ConversationNotFound error

        val id = ConversationId.new()
        every { conversationRepository.findById(id) } returns null

        val result = sut(id.value)

        assertThat(result).isEqualTo(Either.Error(CloseConversationDomainError.ConversationNotFound(id)))
    }
}
```

### Controller test (@WebMvcTest — mock at use case boundary)

`@WebMvcTest` loads only the web layer — no Spring Data, no real database. Mock the use case and feed it `Either.Success` or `Either.Error` returns to verify that the controller translates each outcome into the correct HTTP status and response body. These tests also verify that `@Valid` triggers a 400 when required fields are missing, without any use case involvement.

```kotlin
@WebMvcTest(ConversationController::class)
class ConversationControllerTest {

    @Autowired private lateinit var mockMvc: MockMvc
    @MockkBean private lateinit var createConversation: CreateConversation

    @Test
    fun `should return 201 when conversation is created`() {
        every { createConversation(any(), any()) } returns Either.Success(
            ConversationDTO("conv-123", "CUST-001", "Billing issue", "OPEN", "2026-01-01T00:00:00Z")
        )

        mockMvc.perform(post("/api/conversations")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""{"customerId":"CUST-001","subject":"Billing issue"}"""))
            .andExpect(status().isCreated)
            .andExpect(jsonPath("$.id").value("conv-123"))
    }

    @Test
    fun `should return 422 when input is invalid`() {
        every { createConversation(any(), any()) } returns
            Either.Error(CreateConversationDomainError.InvalidInput("subject is blank"))

        mockMvc.perform(post("/api/conversations")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""{"customerId":"CUST-001","subject":""}"""))
            .andExpect(status().isUnprocessableEntity)
    }
}
```

### Mother Objects (test data factories)

See [Mother Objects](./mother-objects.md) for the full reference — design principles, domain-owned random generation, anti-patterns, and the Mother vs Builder comparison.

### Integration test (TestContainers — real PostgreSQL, never H2)

Integration tests for repositories run against a real PostgreSQL container. H2 has different SQL semantics, type handling, and constraint behaviour — tests that pass on H2 can fail in production on Postgres. We use a custom `@PersistenceIntegrationTest` annotation that wires up TestContainers and the JOOQ `DSLContext`.

```kotlin
@PersistenceIntegrationTest
class JooqConversationRepositoryIntegrationTest {

    @Autowired private lateinit var repository: JooqConversationRepository

    @Test
    fun `should save and retrieve conversation with all fields intact`() {
        val conversation = ConversationMother.create()
        repository.save(conversation)

        val found = repository.findById(conversation.id)

        assertThat(found).isNotNull
        assertThat(found!!.customerId).isEqualTo(conversation.customerId)
        assertThat(found.status).isEqualTo(ConversationStatus.OPEN)
    }
}
```

### Anti-patterns

```kotlin
// ❌ Mocking domain objects
val conversation = mockk<Conversation>()  // use ConversationMother.open() instead

// ❌ H2 in-memory database
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.ANY)  // allows H2

// ❌ Skipping controller tests ("it's just HTTP plumbing")
// Controller tests verify the HTTP contract with clients — they are mandatory

// ❌ Mocking repositories in controller tests
@MockkBean private lateinit var conversationRepository: ConversationRepository  // mock the use case instead
```

### See also

- [Testing Strategy](../testing-strategy.md) — full philosophy, pyramid, and tools