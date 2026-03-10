---
rules: [D-13, D-14]
---

← [Recipes Index](../how-to.md)

# Child Entities

A child entity is a domain object with identity that lives entirely inside an aggregate boundary. It has no meaning or lifecycle outside its root. The root owns it: it is loaded together with the root, mutated through the root's methods, and saved via the root's repository. There is no separate repository for child entities.

---

### When

Use this decision table to decide whether a concept is a child entity or a new aggregate root:

| Question | Child entity | New aggregate root |
|---|---|---|
| Does it have an ID that persists over time? | Yes | Yes |
| Does it have a lifecycle **independent** of the parent? | No | Yes |
| Can it be referenced directly by other aggregates? | No | Yes |
| Is it always loaded and saved together with the parent? | Yes | No |
| Does it make business sense outside the parent context? | No | Yes |

**Examples:**
- `ConversationMessage` inside `Conversation` — child entity. A message has no meaning, no lifecycle, and is never referenced from outside `Conversation`.
- `Order` and `Customer` — separate aggregates. An order can be reasoned about and modified independently of the customer.

### Template

**Child entity (no repository, no Spring annotations):**
```kotlin
// domain/ConversationMessage.kt
class ConversationMessage private constructor(
    val id: ConversationMessageId,
    val conversationId: ConversationId,
    val content: String,
    val authorId: String,
    val createdAt: Instant,
) {
    init {
        require(content.isNotBlank()) { "content cannot be blank" }
        require(authorId.isNotBlank()) { "authorId cannot be blank" }
    }

    companion object {
        fun create(
            conversationId: ConversationId,
            content: String,
            authorId: String,
        ): ConversationMessage =
            ConversationMessage(
                id             = ConversationMessageId.random(),
                conversationId = conversationId,
                content        = content,
                authorId       = authorId,
                createdAt      = Instant.now(),
            )

        fun from(
            id: ConversationMessageId,
            conversationId: ConversationId,
            content: String,
            authorId: String,
            createdAt: Instant,
        ): ConversationMessage =
            ConversationMessage(id, conversationId, content, authorId, createdAt)
    }
}
```

```kotlin
// domain/ConversationMessageId.kt
data class ConversationMessageId(val value: UUID) {
    override fun toString(): String = value.toString()

    companion object {
        fun random(): ConversationMessageId = ConversationMessageId(UUID.randomUUID())
        fun fromString(raw: String): ConversationMessageId = ConversationMessageId(UUID.fromString(raw))
    }
}
```

**Aggregate root holding the child entity list (immutable copy pattern):**
```kotlin
// domain/Conversation.kt
class Conversation private constructor(
    val id: ConversationId,
    val customerId: String,
    val status: ConversationStatus,
    val messages: List<ConversationMessage>,   // owned collection — immutable view
    val createdAt: Instant,
) {
    init {
        require(customerId.isNotBlank()) { "customerId cannot be blank" }
    }

    fun addMessage(content: String, authorId: String): Either<AddMessageError, Conversation> {
        if (status == ConversationStatus.CLOSED) {
            return Either.Error(AddMessageError.ConversationClosed(id))
        }
        val message = ConversationMessage.create(id, content, authorId)
        return Either.Success(copy(messages = messages + message))
    }

    sealed class AddMessageError {
        data class ConversationClosed(val conversationId: ConversationId) : AddMessageError()
    }

    private fun copy(
        status: ConversationStatus = this.status,
        messages: List<ConversationMessage> = this.messages,
    ): Conversation = Conversation(id, customerId, status, messages, createdAt)

    companion object {
        fun create(customerId: String): Conversation =
            Conversation(ConversationId.random(), customerId, ConversationStatus.OPEN, emptyList(), Instant.now())

        fun from(
            id: ConversationId,
            customerId: String,
            status: ConversationStatus,
            messages: List<ConversationMessage>,
            createdAt: Instant,
        ): Conversation = Conversation(id, customerId, status, messages, createdAt)
    }
}
```

**Repository — no MessageRepository; messages come through the aggregate:**
```kotlin
// domain/ConversationRepository.kt
interface ConversationRepository {
    fun save(conversation: Conversation): Conversation
    fun findById(id: ConversationId): Conversation?        // loads messages together with root
    // No findMessagesByConversationId — access via conversation.messages
}
```

**Use case — mutations go through the aggregate root:**
```kotlin
// application/AddMessageToConversation.kt
@Service
@Transactional
class AddMessageToConversation(
    private val conversationRepository: ConversationRepository,
) {

    operator fun invoke(
        conversationId: UUID,
        content: String,
        authorId: String,
    ): Either<AddMessageDomainError, ConversationMessageDTO> {
        val id = ConversationId(conversationId)

        val conversation = conversationRepository.findById(id)
            ?: return Either.Error(AddMessageDomainError.ConversationNotFound(id))

        val updated = conversation.addMessage(content, authorId)
            .mapError { AddMessageDomainError.ConversationClosed(id) }
            .getOrElse { return Either.Error(it) }

        val saved = conversationRepository.save(updated)
        val addedMessage = saved.messages.last()
        return Either.Success(addedMessage.toDTO())
    }
}
```

> The use case accesses the new message via `saved.messages.last()` — there is no separate `messageRepository.findById(...)`. The root and all its children are one unit of persistence.

### Rules

- Child entities have **no repository** — load and save them only through the aggregate root's repository.
- Mutations on child entities go through a **method on the aggregate root** — never mutate a child entity directly from the use case.
- The aggregate root holds children as `List<ChildEntity>` — **immutable**. Business methods return a new aggregate with the updated list (`copy(messages = messages + newMessage)`).
- Child entity IDs follow the same convention as aggregate IDs: `data class ConversationMessageId(val value: UUID)` with `random()` and `fromString()`.
- The child entity's constructor is private — enforce invariants in `init`, use `create()` / `from()` factory methods.
- Cross-aggregate references from child entities are by ID only — `ConversationMessage` holds `conversationId: ConversationId`, not `conversation: Conversation`.

### Anti-patterns

```kotlin
// ❌ Separate repository for a child entity
interface ConversationMessageRepository {
    fun findByConversationId(id: ConversationId): List<ConversationMessage>
}
// ✅ conversationRepository.findById(id)?.messages

// ❌ Mutating a child entity directly from the use case — bypasses aggregate invariants
val conversation = conversationRepository.findById(id)!!
conversation.messages[0].content = "edited"   // mutable child, bypasses Conversation.addMessage()
conversationRepository.save(conversation)
// ✅ Call conversation.editMessage(messageId, newContent) — route all mutations through the root

// ❌ Returning a mutable list — callers can bypass the aggregate boundary
class Conversation(...) {
    val messages: MutableList<ConversationMessage> = mutableListOf()  // leaks interior
}
// ✅ val messages: List<ConversationMessage>  — callers cannot add directly

// ❌ Lazy-loading children in a separate query — root and children must be one load
override fun findById(id: ConversationId): Conversation? {
    val record = dsl.selectFrom(CONVERSATION).where(...).fetchOne() ?: return null
    // Wrong: separate query for messages breaks the "one unit of persistence" rule
    val messages = dsl.selectFrom(CONVERSATION_MESSAGE).where(...).fetch()
    return record.toDomain(messages)   // technically works but signals a design smell
}
// Note: the JOOQ query may physically be two SQL statements joined in the adapter —
// what must NOT happen is a LazyInitializationException-style on-demand load outside
// the repository boundary.

// ❌ data class for child entity — exposes public copy(), callers bypass invariants
data class ConversationMessage(val id: ConversationMessageId, var content: String)
// ✅ class ConversationMessage private constructor(...) with factory methods
```

---

### Exception: unbounded collections

The pattern above assumes the child entity collection is bounded in size. When a collection
can grow without a practical limit — e.g. messages in a conversation — loading the full list
on every aggregate hydration becomes a performance problem.

In this case, promote the child entity to a **separate aggregate root** linked by the parent's ID.
This is a deliberate deviation from the child entity pattern, not a modelling mistake.

**Decision table:**

| Question | Child entity | Separate aggregate root |
|---|---|---|
| Is the collection bounded in size? | Yes | No — can grow indefinitely |
| Does it need its own lifecycle or direct references? | No | No — still no independent lifecycle |
| Is hydration performance a concern? | No | Yes — loading the list is expensive |

**Rules when promoting a child entity to aggregate root for hydration reasons:**

- The promoted aggregate root has **no independent business lifecycle** — it still only makes sense in the context of the parent.
- It has its **own repository** with queries scoped to the parent ID (`findByConversationId`).
- The **parent aggregate does not hold the list** — it never loads the children unless a specific use case requires it.
- Document the reason explicitly in `ai26/domain/{module}/{aggregate}.md` so future engineers understand this is a performance decision, not a domain modelling decision.

**Example — `Message` in Valium:**

```kotlin
// Message is a separate aggregate root only to avoid loading the full message
// list when hydrating Conversation. It has no lifecycle outside a Conversation.

class Message private constructor(
    val id: UUID,
    val conversationId: UUID,   // reference to parent by ID — not the full Conversation
    val content: MessageContent,
    val sentBy: Participant,
    val sentAt: Instant,
) {
    companion object {
        fun create(...): Message = ...
        fun from(...): Message = ...
    }
}

interface MessageRepository {
    fun findById(messageId: UUID): Message?
    fun create(message: Message): Message
}

// Conversation does NOT hold a List<Message>
class Conversation private constructor(
    val id: UUID,
    val customerId: UUID,
    val status: ConversationStatus,
    // no messages: List<Message> here
) { ... }
```

> **Note:** this is the only case where a `MessageRepository` is acceptable alongside
> `ConversationRepository`. In all other cases, a child entity has no repository.

---

### See also

- [Domain Building Blocks](./domain.md#aggregate-roots) for the aggregate root pattern and private constructor convention
- [Repositories](./repositories.md) for the JOOQ adapter pattern and one-repository-per-aggregate rule
