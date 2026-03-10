---
rules: [T-03]
---

← [Recipes Index](../how-to.md) · [Testing by Layer](./testing.md)

# Mother Objects

Test data factories for domain entities.

- [The problem](#the-problem)
- [The pattern](#the-pattern)
- [Design principles](#design-principles)
- [Domain-owned random generation](#domain-owned-random-generation)
- [Shared utilities for non-domain types](#shared-utilities-for-non-domain-types)
- [Where to place](#where-to-place)
- [Mother vs Builder](#mother-vs-builder-why-kotlin-doesnt-need-a-separate-builder-class)
- [Anti-patterns](#anti-patterns)
- [References](#references)

---

### The problem

Tests need complete, valid domain objects. Building them inline is repetitive and fragile:

```kotlin
// Every test repeats the same construction ceremony
val conversation = Conversation.create(
    id = UUID.randomUUID(),
    customerId = UUID.randomUUID(),
    startedAt = Instant.now(),
    customerPlatform = CustomerPlatform.IOS,
    language = N26Locale.Lang.en,
)
```

When the aggregate's `create()` signature changes — a new required parameter, a renamed field — every test that constructs one breaks. Worse, inline construction obscures test intent: the reader cannot tell which parameters matter for this specific test and which are just noise to satisfy the compiler. This is what Gerard Meszaros calls an **Obscure Test** — the test setup drowns out the test's purpose.

### The pattern

Martin Fowler defines an **ObjectMother** as *"a class that is used in testing to help create example objects that you use for testing."* In Kotlin, a Mother is an `object` with named factory methods that return entities in well-defined states. The name documents the scenario — `create()`, `open()`, `closed()`, `withCustomer(customerId)` — so the test reads like a specification.

The Mother centralizes construction: when the domain factory's signature changes, you fix **one** Mother instead of fifty tests. This is the core value proposition — a single point of change for test data.

### Design principles

**1. Always delegate to domain factories**

A Mother **never constructs domain objects directly** when a factory method exists (`create()`, `from()`). It calls the aggregate's own factory, which enforces `init`-block invariants and sets initial state correctly. The Mother provides parameters; the domain factory enforces rules.

```kotlin
// ✅ Mother delegates to domain factory — invariants are enforced
object ConversationMother {
    fun create(
        id: UUID = UUID.randomUUID(),
        customerId: UUID = UUID.randomUUID(),
        startedAt: Instant = Instant.now(),
        customerPlatform: CustomerPlatform = CustomerPlatform.random(),
        language: N26Locale.Lang = N26Locale.Lang.random(),
    ): Conversation = Conversation.create(
        id = id,
        customerId = customerId,
        startedAt = startedAt,
        customerPlatform = customerPlatform,
        language = language,
    )
}

// ❌ Mother bypasses domain factory — invariants might not run
object ConversationMother {
    fun create(...) = Conversation(id, customerId, ...)  // direct constructor call
}
```

If the aggregate's `create()` signature changes, the Mother breaks at compile time — that's deliberate and desired. It's the single point of change that protects all tests downstream.

**2. Default parameters: random and irrelevant**

When a test writes `ConversationMother.create(customerId = specificId)`, the explicit parameter tells the reader: *"customerId matters for this test."* Every other parameter gets a **random default** — `UUID.randomUUID()` for IDs, `Instant.now()` for timestamps, `CustomerPlatform.random()` for enums — which communicates: *"these don't affect the behavior being tested."*

Random defaults serve a second purpose: they prevent **false positives from accidental coupling**. If every test uses `customerId = "CUST-001"`, a bug that only manifests with other IDs goes unnoticed. Random values make tests robust against coincidental passes.

Critically, random generation must be **owned by the domain type**, not by a generic utility. Just as `UUID.randomUUID()` knows how to produce a valid UUID, `CustomerPlatform.random()` knows which platform values are valid for creation. If a new enum value is added that isn't valid in every context (e.g. a deprecated or internal-only value), the type's `random()` is the single place to exclude it — no Mother needs to change.

**3. Named methods for domain states**

When tests frequently need an entity in a specific state (open, closed, confirmed), add a named method that composes on top of `create()`:

```kotlin
object ConversationMother {
    fun create(
        id: UUID = UUID.randomUUID(),
        customerId: UUID = UUID.randomUUID(),
        startedAt: Instant = Instant.now(),
        customerPlatform: CustomerPlatform = CustomerPlatform.random(),
        language: N26Locale.Lang = N26Locale.Lang.random(),
    ): Conversation = Conversation.create(id, customerId, startedAt, customerPlatform, language)

    // Named states compose on top of create()
    fun closed() = create().close()
    fun withCustomer(customerId: UUID) = create(customerId = customerId)
}
```

The method name describes what the test needs, not how to build it. `ConversationMother.closed()` is instantly readable; the five-line construction is hidden behind a meaningful name.

**4. Connection with domain generation methods**

Value objects like `ConversationId` provide `random()` to generate valid instances. These exist for **production code** — `Conversation.create()` calls `ConversationId.random()` internally. Mothers typically pass raw primitives (`UUID.randomUUID()`) as default parameters because the domain factory wraps them.

When a test needs a **standalone value object** — for example, to stub a `findById` that returns `null` — use the VO's own `random()`:

```kotlin
@Test
fun `should return error when conversation not found`() {
    val id = ConversationId.random()  // standalone VO, not going through a Mother
    every { conversationRepository.findById(id) } returns null

    val result = sut(id.id.toString())

    assertThat(result).isEqualTo(Either.Error(CloseConversationDomainError.ConversationNotFound(id)))
}
```

### Domain-owned random generation

Each domain type that appears as a Mother parameter provides its own `random()` — analogous to `UUID.randomUUID()`. The type encapsulates which values are valid, so Mothers never need to know.

Implement `random()` as a **companion extension function** in `testFixtures/`, keeping production code free of test concerns:

```kotlin
// testFixtures/CustomerPlatformExtensions.kt
fun CustomerPlatform.Companion.random(): CustomerPlatform = entries.random()

// testFixtures/N26LocaleExtensions.kt
fun N26Locale.Lang.Companion.random(): N26Locale.Lang = entries.random()
```

The production enum only needs an empty `companion object` declaration (a lightweight convention):

```kotlin
enum class CustomerPlatform {
    IOS, ANDROID, WEB;
    companion object  // enables companion extensions in testFixtures
}
```

When not all enum values are valid for creation, the extension restricts the set in one place:

```kotlin
// Only OPEN is valid at creation time
fun ConversationStatus.Companion.random(): ConversationStatus =
    listOf(ConversationStatus.OPEN).random()
```

If a new enum constant is added later, tests fail immediately at the type's `random()` boundary — not scattered across dozens of Mothers.

Usage in Mothers:

```kotlin
customerPlatform: CustomerPlatform = CustomerPlatform.random(),
language: N26Locale.Lang = N26Locale.Lang.random(),
```

### Shared utilities for non-domain types

For generic types that have no domain-specific validity rules (random strings, random numbers), one `RandomValueGenerator` in `testFixtures/` covers all needs:

```kotlin
// testFixtures/RandomValueGenerator.kt
object RandomValueGenerator {
    fun String.Companion.random(length: Int = 10): String =
        (1..length).map { ('a'..'z').random() }.joinToString("")
}
```

Avoid duplicating random utilities across modules.

### Where to place

| Location | Use when |
|---|---|
| `testFixtures/` (Gradle) | Mother is shared across modules — e.g. `ConversationMother` used by both `service/` and integration tests |
| `test/` | Mother is local to one module — e.g. `ConversationBlockMother` used only in `application/` tests |

Package mirrors the domain entity's package: if `Conversation` lives in `de.tech26.valium.conversation.domain`, then `ConversationMother` lives in `de.tech26.valium.conversation.domain` under the test source root.

### Mother vs Builder: why Kotlin doesn't need a separate Builder class

Nat Pryce's **Test Data Builder** pattern addresses the combinatorial explosion problem: when a Mother needs dozens of factory methods for every parameter combination, maintenance becomes painful. The Builder solves this with a fluent API where each `with...()` call returns a new builder.

In Kotlin, **default parameters already provide the Builder's flexibility**. `ConversationMother.create(customerId = specificId)` achieves the same selective override as `aConversation().withCustomerId(specificId).build()`, without a separate builder class. Kotlin's named arguments make every parameter independently overridable at the call site.

If a Mother accumulates so many named-state methods that it becomes hard to navigate, that's a signal that the aggregate itself may be doing too much — revisit the domain model before adding a builder layer.

### Anti-patterns

```kotlin
// ❌ Bypassing domain factory when one exists
object ConversationBlockMother {
    fun default(id: UUID = UUID.randomUUID()) =
        ConversationBlock(ConversationBlockId(id), ...)  // bypasses ConversationBlock.from()
}
// ✅ Delegate to factory
object ConversationBlockMother {
    fun create(id: UUID = UUID.randomUUID()) =
        ConversationBlock.from(id, ...)  // factory enforces invariants
}

// ❌ Hardcoded magic values — tests couple to specific value, hide intent
object ConversationMother {
    fun create() = Conversation.create(
        id = UUID.fromString("00000000-0000-0000-0000-000000000001"),  // why this ID?
        customerId = UUID.fromString("00000000-0000-0000-0000-000000000002"),
        customerPlatform = CustomerPlatform.IOS,  // always IOS — is that the behavior we're testing?
    )
}
// ✅ Random defaults — only override what the test cares about

// ❌ mockk<Conversation>() — breaks real invariants, couples to implementation
val conversation = mockk<Conversation>()
every { conversation.id } returns ConversationId.random()
every { conversation.close() } returns mockk()
// ✅ Use ConversationMother.create() — exercises real domain logic

// ❌ Duplicated random utilities across modules
// service/testFixtures/RandomValueGenerator.kt  — random enum
// application/test/RandomsTest.kt              — also random enum, different API
// ✅ One shared RandomValueGenerator in testFixtures/

// ❌ Generic random for domain enums — type doesn't control valid values
customerPlatform: CustomerPlatform = RandomValueGenerator.random(),
// ✅ Domain type owns its random — encapsulates validity rules
customerPlatform: CustomerPlatform = CustomerPlatform.random(),

// ❌ Business logic in Mother — Mothers are data factories, not domain services
object OrderMother {
    fun withDiscount(order: Order, discountPercent: Int): Order {
        val discounted = order.totalAmount() * (100 - discountPercent) / 100  // logic!
        return order.applyDiscount(Money.of(discounted, "EUR"))
    }
}
// ✅ Mother creates data; domain methods apply logic

// ❌ Naming: "default()" obscures the state — what state is "default"?
object ConversationMother {
    fun default(...) = ...  // PENDING? ACTIVE? reader has to inspect the code
}
// ✅ Name describes the state: create() for initial, open(), closed(), withCustomer()
```

### References

- **Martin Fowler, [ObjectMother](https://martinfowler.com/bliki/ObjectMother.html)** (2006) — The original definition: *"a class used in testing to help create example objects."* Explains why centralizing test object creation reduces fragility and improves readability.
- **Peter Schuh & Stephanie Punke, *ObjectMother — Easing Test Object Creation in XP*** (XP/Agile Universe 2002) — The ThoughtWorks conference paper that coined the term. Describes the pattern in the context of large, real-world test suites where duplicated setup became the primary maintenance cost.
- **Gerard Meszaros, *xUnit Test Patterns*** (Addison-Wesley, 2007) — Chapters on **Creation Method**, **Object Mother**, and **Test Data Builder** formalize the vocabulary. The key concepts: *Obscure Test* (the problem where construction noise hides test intent), *Creation Method* (the minimal fix — a factory method per state), *Object Mother* (the centralized factory object). This is the canonical reference for understanding when a Mother is sufficient vs. when a Builder is needed.
- **Nat Pryce, [Test Data Builders: an alternative to the Object Mother pattern](http://www.natpryce.com/articles/000714.html)** (2007) — Explains when the combinatorial explosion of Mother methods justifies switching to a fluent builder. In Kotlin, default parameters cover the Builder's flexibility without a separate class — see *Mother vs Builder* above.
