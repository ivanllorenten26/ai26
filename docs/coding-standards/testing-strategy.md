# Testing Strategy

How Clean Architecture shapes testing in valium — informed by industry-wide best practices.

Testing in a Clean Architecture codebase is different from testing a typical Spring Boot app. Because each layer has a single responsibility, each layer also has a single, well-defined test type. The domain layer is pure Kotlin — tests run without Spring in milliseconds. The application layer (use cases) is the primary subject under test — one test class per use case, mocking only the outbound ports. The infrastructure layer has two test types: `@WebMvcTest` for controllers (fast, no database) and TestContainers integration tests for repositories (real PostgreSQL, no shortcuts). This structure means you never write a test that loads the entire Spring context just to verify a business rule.

This approach draws from several complementary schools of thought:

> "The more your tests resemble the way your software is used, the more confidence they can give you." — Kent C. Dodds

> "A test is not a unit test if it talks to the database, communicates across the network, or touches the file system." — Michael Feathers, *Working Effectively with Legacy Code*

> "The whole point of TDD is that you test the behaviour of the module, not its implementation." — Ian Cooper, *TDD, Where Did It All Go Wrong?*

> "Verify the outcome, not the steps." — Vladimir Khorikov, *Unit Testing: Principles, Practices, and Patterns*

---

## Core Philosophy

1. **Use Case = Natural SUT**: Use Cases represent system intent — they are the primary subject under test.
2. **Domain objects = always real**: Aggregates and value objects are instantiated directly via `create()`/`of()` factories. They are never mocked.
3. **Mock only outbound ports**: Repositories and external gateways are the only things mocked.
4. **Controllers = humble objects**: No business logic in controllers means minimal test surface — but in this project controller tests are **mandatory** to verify HTTP contracts.

> **Why "domain objects = always real"?** If you mock a `Conversation` in a use case test, you are testing that MockK can simulate a `Conversation` — not that the real `Conversation` behaves correctly. Using real domain objects means your use case tests exercise actual business logic. If `Conversation.close()` throws when the status is wrong, the use case test catches it. A mock would silently return whatever you configured.
>
> **Why "mock only outbound ports"?** The outbound port (repository, event emitter) is the only thing that makes a use case depend on infrastructure. Replacing it with a mock makes the test fast and deterministic. Mocking anything else — a domain service, a value object — indicates the code structure has a problem: either the domain object is too coupled to infrastructure, or the use case is doing too much.

---

## Testing Pyramid

| Level | Type | Speed | Quantity | Purpose |
|---|---|---|---|---|
| 1 | Use Case tests (BDD, Gherkin docstring) | Very fast | Many | Business scenarios — primary SUT |
| 2 | Integration tests (gateways) | Slow | Moderate | Infrastructure boundaries, persistence round-trips |
| 3 | Controller tests (`@WebMvcTest`) | Fast | One per endpoint | HTTP contract verification — **mandatory** |
| 4 | Feature tests (BDD, Gherkin docstring, HTTP) | Slow | One per scenario | Acceptance criteria — full stack via HTTP |
| 5 | Architecture tests (ArchUnit) | Fast | Once per module | Layer rule enforcement in CI |
| 6 | E2E smoke tests | Very slow | Very few | Wiring verification |

The pyramid shape matters: many fast use case tests at the base, few slow E2E tests at the top. An inverted pyramid (many slow E2E tests, few unit tests) gives you a test suite that takes minutes to run and tells you nothing precise when it fails. The pyramid ensures fast feedback: a failing use case test tells you exactly which business rule broke, in under a second.

---

## Testing by Layer

For the full breakdown of each layer — what to test, how to structure tests, and code examples for use case tests, feature tests, controller tests, integration tests, and E2E smoke tests — see [Testing by Layer](./testing-by-layer.md).

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

---

## Comparison with Other Schools

| Aspect | London School | Detroit / Classicist School | This project |
|---|---|---|---|
| Unit definition | One class | One behaviour | One use case |
| Domain object testing | Isolated with mocks | Direct with real objects | Indirect via use case |
| Controller testing | Unit test with mocked service | Integration test | `@WebMvcTest` — mandatory |
| Mock boundary | Every collaborator | External systems only | Outbound ports only |
| Key authors | Freeman & Pryce (*GOOS*) | Beck (*TDD by Example*), Meszaros (*xUnit Patterns*) | Martin (*Clean Architecture*), Khorikov (*Unit Testing*) |

**Why this project follows the classicist / use-case-centric approach?**

The **London School** (Freeman & Pryce, *Growing Object-Oriented Software, Guided by Tests*, 2009) mocks every collaborator and verifies calls between objects. This works for systems with many fine-grained services but creates brittle tests in a DDD codebase: if you refactor how an aggregate internally delegates between methods, all the interaction tests break even though the behaviour is identical. Khorikov calls these "implementation-coupled tests" and warns they erode the test suite's resistance to refactoring.

The **Detroit / Classicist School** (Beck, *TDD by Example*, 2002; Meszaros, *xUnit Test Patterns*, 2007) tests observable state rather than interactions, using real objects wherever possible. This is closer to what this project does — we use real domain objects and assert on outcomes, not on mock interactions.

Our approach adds the **use case as the natural unit** (Martin, *Clean Architecture*, 2017): one use case = one test class = one set of scenarios. The use case boundary is stable even as the internal domain model evolves, which means the tests stay green through refactoring. This aligns with Khorikov's advice to maximise the "resistance to refactoring" dimension of test quality.

Ian Cooper's talk *"TDD, Where Did It All Go Wrong?"* (2013) articulates the same principle from a TDD perspective: the unit in TDD is a unit of **behaviour**, not a unit of code. The public API of a use case is exactly that behavioural boundary — testing at that level avoids the over-specification trap.

---

## Tools

| Tool | Use |
|---|---|
| JUnit 5 | Test runner |
| MockK | Mocking — use only for outbound ports |
| Kotest assertions | `shouldBe`, `shouldNotBe`, `shouldHaveSize`, etc. |
| Gherkin docstrings | BDD specs as `// Scenario:` comments inside JUnit5 test methods |
| TestContainers | Real PostgreSQL in integration, feature, and E2E tests |
| ArchUnit | Layer rule enforcement |
| `@WebMvcTest` | Controller slice tests |

```kotlin
dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("io.mockk:mockk")
    testImplementation("io.kotest:kotest-assertions-core")
    testImplementation("org.testcontainers:testcontainers")
    testImplementation("org.testcontainers:postgresql")
    testImplementation("com.tngtech.archunit:archunit-junit5")
}
```

---

## References

Books, talks, and articles that inform this testing strategy:

| Source | Year | Key contribution to this strategy |
|---|---|---|
| Kent Beck — *Test-Driven Development: By Example* | 2002 | TDD cycle (red-green-refactor), tests as behaviour specification |
| Michael Feathers — *Working Effectively with Legacy Code* | 2004 | Definition of a unit test (no DB, no network, no filesystem) |
| Gerard Meszaros — *xUnit Test Patterns* | 2007 | Test doubles taxonomy (stub, mock, spy, fake, dummy) |
| Steve Freeman & Nat Pryce — *Growing Object-Oriented Software, Guided by Tests* | 2009 | London school (interaction-based testing), outside-in TDD |
| Ian Cooper — *TDD, Where Did It All Go Wrong?* (talk) | 2013 | Unit = unit of behaviour, not unit of code; test at the public API |
| Vaughn Vernon — *Implementing Domain-Driven Design* | 2013 | Testing aggregates and repositories; domain-centric test boundaries |
| Robert C. Martin — *Clean Architecture* | 2017 | Use case as SUT; dependency rule shapes mock boundaries |
| Vladimir Khorikov — *Unit Testing: Principles, Practices, and Patterns* | 2020 | Four pillars of a good test (protection against regressions, resistance to refactoring, fast feedback, maintainability); classicist over London school for DDD |
| Martin Fowler — *Testing Pyramid* (article) | 2012 | Pyramid shape: many fast unit tests, few slow E2E tests |
| Kent C. Dodds — *Testing Trophy* (article) | 2019 | "The more your tests resemble the way your software is used, the more confidence they can give you" |