---
rules: [CC-04, D-14]
---

← [Recipes Index](../how-to.md)

# Repositories

### When

Every aggregate root has exactly one repository interface (domain port) and one implementation (infrastructure adapter). No repository for child entities — access them through the aggregate root.

### Template

The repository interface lives in the domain layer and uses only domain types — the domain never sees `Optional` or JOOQ records. `findById` returns a nullable (`Conversation?`) rather than `Optional<Conversation>` because Kotlin's null safety is idiomatic and more concise. The JOOQ adapter injects a `DSLContext` and uses private extension functions (`toDomain()`, `toJooq()`) to translate between domain types and JOOQ's generated records and enums. These mapping functions are co-located with the adapter — they never leak into the domain.

**Interface (domain layer):**
```kotlin
// domain/ConversationRepository.kt
interface ConversationRepository {
    fun save(conversation: Conversation): Conversation
    fun findById(id: ConversationId): Conversation?          // null = not found
    fun findByCustomerId(customerId: String): List<Conversation>
    // No methods for Message — access messages through Conversation
}
```

**JOOQ adapter (infrastructure/outbound):**
```kotlin
// infrastructure/outbound/JooqConversationRepository.kt
@Repository
class JooqConversationRepository(
    private val dsl: DSLContext,
) : ConversationRepository {

    override fun save(conversation: Conversation): Conversation {
        dsl.insertInto(CONVERSATION_V2)
            .set(CONVERSATION_V2.ID, conversation.id)
            .set(CONVERSATION_V2.CUSTOMER_ID, conversation.customerId)
            .set(CONVERSATION_V2.STATUS, conversation.status.toJooq())
            .set(CONVERSATION_V2.CREATED_AT, conversation.createdAt)
            .execute()
        return conversation
    }

    override fun findById(id: ConversationId): Conversation? =
        dsl.selectFrom(CONVERSATION_V2)
            .where(CONVERSATION_V2.ID.eq(id.value))
            .fetchOne()
            ?.toDomain()

    override fun findByCustomerId(customerId: String): List<Conversation> =
        dsl.selectFrom(CONVERSATION_V2)
            .where(CONVERSATION_V2.CUSTOMER_ID.eq(customerId))
            .fetch()
            .map { it.toDomain() }

    // Private mapping functions — translation stays in the adapter
    private fun ConversationV2Record.toDomain() = Conversation.from(
        id = ConversationId(id),
        customerId = customerId,
        status = status.toDomain(),
        createdAt = createdAt,
    )

    private fun ConversationStatus.toJooq() = ConversationV2Status.valueOf(name)
    private fun ConversationV2Status.toDomain() = ConversationStatus.valueOf(name)
}
```

### Rules

- Interface returns domain types — never JOOQ records
- `findById` returns nullable (`Conversation?`) — never `Optional<Conversation>`
- Never return `Either` from a repository — use nullable for not-found, let exceptions propagate for infrastructure failures
- One repository per aggregate root — no `MessageRepository` if `Message` is inside `Conversation`
- Mapping functions (`toDomain()`, `toJooq()`) are private to the adapter

### Anti-patterns

```kotlin
// ❌ JOOQ record leaking into domain (infrastructure leaks into domain)
class Conversation(val record: ConversationV2Record)

// ❌ Optional return type — use Kotlin nullable instead
fun findById(id: ConversationId): Optional<Conversation>

// ❌ Repository for a child entity
interface MessageRepository { fun findByConversationId(id: ConversationId): List<Message> }
// Access messages through conversationRepository.findById(id)?.messages instead
```

### See also

- [Architecture Principles — Repository Pattern](../architecture-principles.md#repository-pattern-per-aggregate)
