# How-To — Recipes for Common Patterns

Practical recipes for the patterns you encounter most often in this codebase.
Each recipe: **When** to use it / **Template** (copy-paste starting point) / **Anti-patterns** / **See also**.

For the architectural *why* behind each decision, see [Architecture Principles](./architecture-principles.md).

---

## Domain Layer

| Recipe | When to use |
|---|---|
| [Aggregate Roots](./recipes/domain.md#aggregate-roots) | Model a concept with identity, lifecycle, and consistency boundary |
| [Value Objects](./recipes/domain.md#value-objects) | Wrap a primitive with domain meaning and validation |
| [Domain Services](./recipes/domain.md#domain-services) | Business logic spanning multiple aggregates |
| [Domain Events](./recipes/domain-events.md) | Notify other contexts of aggregate state changes |
| [Error Handling](./recipes/error-handling.md) | Choose `require`, `Either`, or exception per situation |

## Application Layer

| Recipe | When to use |
|---|---|
| [Use Cases](./recipes/use-cases.md) | One class per business operation with `operator fun invoke` |
| [Transactions](./recipes/use-cases.md#transactions) | Where `@Transactional` belongs and cross-aggregate consistency |

## Infrastructure Layer

| Recipe | When to use |
|---|---|
| [REST Controllers](./recipes/controllers.md#rest-controllers) | Expose a use case over HTTP as a humble object |
| [Global Error Handler](./recipes/controllers.md#global-error-handler--controlleradvice) | Central `@ControllerAdvice` for uncaught exceptions |
| [Repositories](./recipes/repositories.md) | JOOQ adapter for an aggregate root |
| [Consuming External APIs](./recipes/external-apis.md) | 5-file bundle for outbound HTTP clients |
| [SQS Queues — DLQ and Redrive](./recipes/messaging.md) | Publisher, subscriber, and redrive patterns |
| [Infrastructure Services](./recipes/infrastructure.md#infrastructure-services--when-no-use-case-is-needed) | Pure plumbing with no domain logic |
| [Observability — Logs and Metrics](./recipes/infrastructure.md#observability--logs-and-metrics) | Where metrics and logging live per layer |
| [Database Migrations with Flyway](./recipes/infrastructure.md#database-migrations-with-flyway) | Schema changes with safety guidelines |

## Cross-Cutting

| Recipe | When to use |
|---|---|
| [Adding a New Endpoint](./recipes/controllers.md#adding-a-new-endpoint-end-to-end) | End-to-end checklist for a complete feature |
| [Testing by Layer](./recipes/testing.md) | Test type, framework, and mocking strategy per layer |
