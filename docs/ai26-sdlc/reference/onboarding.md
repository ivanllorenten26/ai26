# Onboarding

> How a team adopts AI26 from scratch.

---

## Prerequisites

- Claude Code installed and configured
- AI26 skills installed from the Claude marketplace
- Jira MCP configured and connected to your project
- Git repository initialised

---

## Step 1 — Install the skills

Install the AI26 skill package from the Claude marketplace.

    /marketplace install ai26

This installs all three skill layers:
- SDLC orchestration skills (`sdlc-*`)
- PM + Design skills (`design-*`)
- Dev + Test skills (`dev-*`, `test-*`) for the default stack

If your team uses a non-default stack, install the corresponding stack package:

    /marketplace install ai26-node-express
    /marketplace install ai26-python-fastapi

---

## Step 2 — Create `ai26/config.yaml`

Create `ai26/config.yaml` in your repository.

Start from the minimal configuration and expand as needed:

```yaml
# ai26/config.yaml

stack:
  language: kotlin
  framework: spring-boot
  build: gradle

modules:
  - name: service
    path: service/
    purpose: "Service module"
    active: true
    base_package: com.yourcompany.yourservice
    conventions:
      repository_type: jooq
      error_handling: either
      test_containers: true
      event_bus: kafka
    flyway:
      enabled: true
      path: service/src/main/resources/db/migration
```

This is the minimal configuration. Everything else uses defaults.
For the full schema and all available parameters, see `configuration.md`.


---

## Step 3 — Build the context

The `ai26/context/` directory is the shared knowledge base that all skills read.
It must exist before any AI26 flow can run.

Create the following files. Full format reference and examples: `context-files.md`.

### `ai26/context/DOMAIN.md`

One bounded context per section. Each section contains the aggregates and
ubiquitous language that belong to that context — not a global list.

```markdown
# Domain

---

## Bounded contexts

### {ContextName}

Source: `{module}/src/main/kotlin/{base_package}/{context-package}/`
Owns: {what this context owns.}
Does NOT own: {what belongs to other contexts}.

#### Aggregates

| Aggregate | Module | File |
|---|---|---|
| {AggregateName} | {module} | `ai26/domain/{module}/{aggregate}.md` |

#### Ubiquitous language

| Term | Definition | Avoid |
|---|---|---|
| {Term} | {Definition} | {Synonyms to reject} |
```

### `ai26/context/ARCHITECTURE.md`

Non-negotiable architectural constraints and layer rules.

```markdown
# Architecture

---

## Style

{Architectural style in one sentence.}

---

## Layer rules

| Layer | Can depend on | Cannot depend on |
|---|---|---|
| domain | nothing | application, infrastructure, frameworks |
| application | domain | infrastructure, frameworks (except @Service) |
| infrastructure | domain, application | — |

---

## Constraints

- {Non-negotiable rule}
- {Another rule}
```

### `ai26/context/DECISIONS.md`

Global decisions already taken. The LLM applies these as constraints — it will
not re-debate them. Include the *why* — without it the constraint has no weight.

```markdown
# Decisions

---

## {Decision title}

**Decision:** {What was decided.}
**Why:** {The reason.}
**Applies to:** {Scope.}
```

### `ai26/context/DEBT.md`

Known technical debt with risk levels. `alto` surfaces immediately during design
and may pause the conversation. If no debt exists, create the file with a placeholder.

```markdown
# Debt

---

## {Area name}

Risk: alto | medio | bajo
**What:** {What the problem is.}
**Why it's a risk:** {What could go wrong.}
**Known workaround:** {How the team currently deals with it.}
**Plan:** {Resolution plan with timeline and tracking reference. Omit if no plan exists.}
```

### `ai26/context/INTEGRATIONS.md`

The integration surface of the service: inbound endpoints, outbound HTTP calls,
events emitted, events consumed, AI/ML services, and downstream dependents.
If the service has no integrations yet, create the file with placeholder sections.

```markdown
# Integrations

---

## Inbound HTTP

| Method | Path | Description | Auth |
|---|---|---|---|

---

## Outbound HTTP

---

## Events emitted

| Event | Topic / Queue | Trigger | Schema file |
|---|---|---|---|

---

## Events consumed

| Event | Topic / Queue | Source service | Handler |
|---|---|---|---|

---

## AI / ML services

---

## Downstream services

| Service | How it depends on us | Impact of breaking change |
|---|---|---|
```

Full format reference and diagram generation: `context-mapping.md`.

### `ai26/domain/{module}/{aggregate}.md`

One file per aggregate. Format: Mermaid class diagram + YAML model.
Full format reference: `aggregate-format.md`.

---

Start with what your team knows implicitly and make it explicit. A minimal but
honest context is better than a detailed but incomplete one. The system improves
as the context improves.

---

## Step 4 — Verify the setup

Run the setup check:

    /ai26-start-sdlc --check

The LLM verifies:
- `ai26/config.yaml` exists and is valid
- All required `ai26/context/` files exist
- Jira MCP is connected and reachable
- Git remote is configured

Example output:

    AI26 setup check
    ─────────────────────────────────────────
    ✓ ai26/config.yaml — valid
    ✓ ai26/context/DOMAIN.md — found
    ✓ ai26/context/ARCHITECTURE.md — found
    ✓ ai26/context/DECISIONS.md — found
    ✓ ai26/context/DEBT.md — found
    ✓ Jira MCP — connected (project: YOUR-PROJECT)
    ✓ Git remote — origin configured

    Setup complete. Ready to start:
      /ai26-start-sdlc              — start from a business initiative
      /ai26-start-sdlc {TICKET-ID}  — start from an existing ticket

---

## Step 5 — First run

For a new project with no existing tickets:

    /ai26-start-sdlc

The LLM will ask whether you want to start from an epic or a ticket,
and guide you through the rest.

For an existing project with tickets already in Jira:

    /ai26-start-sdlc {TICKET-ID}

The LLM reads the ticket, does a bootstrap evaluation of what context is available,
and starts the design conversation.

---

## Adopting on an existing codebase

If your team has existing code that was written without AI26, you do not need to
retroactively document everything before starting. Start with the next feature.

For the first feature, the LLM will:
1. Read your ticket from Jira
2. Read `ai26/context/` (which you just created)
3. Scan the existing codebase to detect patterns and existing domain concepts
4. Surface what it found and what it inferred before starting the design conversation

After a few features, the `ai26/context/` files will be richer and the design conversations
will require less clarification. The system improves as the context improves.

If you want to document existing code retroactively to enable validation and promotion
on features already implemented, use the backfill flow:

    /ai26-start-sdlc {TICKET-ID} --backfill

This generates design artefacts from existing code rather than from a design conversation.

---

## Context maintenance

The `ai26/context/` directory is a living document. It degrades if not maintained.

After each feature is promoted, review:
- Did new domain concepts emerge? → update `DOMAIN.md`
- Were new global decisions made? → update `DECISIONS.md`
- Was new technical debt introduced? → update `DEBT.md`

The promotion step surfaces proposed updates to `ai26/context/` for confirmation.
The team is responsible for keeping the context honest.

A stale `ai26/context/` produces worse design conversations and worse code.
Treat it with the same discipline as keeping tests green.
