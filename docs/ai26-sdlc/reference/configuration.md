# Configuration Model

> How teams configure AI26 for their context.

---

## `ai26/config.yaml`

The single configuration file each team maintains at `ai26/config.yaml`.
All skills read this file before executing. If it does not exist, skills use the
defaults listed at the bottom of this document.

This file contains only **configurable values** — things that vary between teams
and projects. Validation gates and required context files are fixed behaviour of
the skills and are not configurable here.

---

## Reference

### `interaction_style`

Default interaction style for design conversations.

| Value | Behaviour |
|---|---|
| `socratic` | LLM asks questions that lead the human to articulate decisions. Best for high-impact architectural decisions where the reasoning matters as much as the outcome. **Default.** |
| `proactive` | LLM makes a reasoned recommendation. Human validates or challenges. Best when `ai26/context/` is well-documented and the team trusts the LLM to propose. |
| `reactive` | LLM presents options with trade-offs and waits for the human to decide. Best for lower-stakes decisions or when the human has a strong prior. |

Can be overridden per invocation:

```
/ai26-design-user-story TICKET-123 --style proactive
```

---

### `stack`

Tells implementation skills which code-generation templates to use.

| Field | Values | Notes |
|---|---|---|
| `language` | `kotlin`, `typescript`, `python`, `go` | Determines template set loaded from the marketplace |
| `framework` | `spring-boot`, `express`, `fastapi`, `gin` | Must be compatible with `language` |
| `build` | `gradle`, `maven`, `npm`, `poetry` | Used to resolve module paths and run commands |

```yaml
stack:
  language: kotlin
  framework: spring-boot
  build: gradle
```

---

### `modules`

One entry per build module (Gradle module, Maven module, or equivalent).
Skills resolve all file paths, base packages, and code conventions from this list.

```yaml
modules:
  - name: service
    path: service/
    purpose: "Active service module — customer conversation management"
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

#### Module fields

| Field | Required | Description |
|---|---|---|
| `name` | yes | Short identifier used in plan files and skill output |
| `path` | yes | Path from repo root to the module directory |
| `purpose` | yes | One-line description — shown to the LLM and in the plan |
| `active` | yes | `true` = target for new features. `false` = legacy, skills warn before touching |
| `base_package` | yes | Root package for source files in this module |
| `conventions` | yes | Per-module code conventions (see below) |
| `flyway` | no | Omit if the module has no database migrations |

#### `conventions` fields

| Field | Values | Description |
|---|---|---|
| `repository_type` | `jooq`, `jpa` | Which persistence library the module uses. Determines which `dev-create-*-repository` skill is invoked. |
| `error_handling` | `either`, `exceptions` | `either` — use cases return `Either<DomainError, T>`. `exceptions` — use cases throw domain exceptions. Determines generated code patterns throughout. |
| `test_containers` | `true`, `false` | Whether integration tests use TestContainers. `false` for legacy modules or modules with no DB. |
| `event_bus` | `kafka`, `sqs`, `none` | Which messaging infrastructure the module uses. Determines which publisher/subscriber skills are invoked. |

#### `flyway` fields

| Field | Values | Description |
|---|---|---|
| `enabled` | `true`, `false` | Whether this module has Flyway migrations |
| `path` | string | Path from repo root to the migration SQL directory |

#### Module resolution

Skills resolve the target module as follows:

1. If only one module has `active: true` — use it without asking.
2. If multiple modules are `active: true` — infer from ticket context, then confirm with the engineer.
3. If a ticket explicitly names a module — use it.
4. If a non-active module is involved — warn before proceeding.

A ticket can span multiple modules. In that case, each subtask in the implementation
plan declares its own target module explicitly.

---

### `adr_triggers`

Which decision categories automatically prompt the LLM to propose an ADR during
the design conversation.

| Value | What it covers |
|---|---|
| `domain_modelling` | Aggregate boundaries, entity relationships, value object design, invariant placement |
| `data_design` | Schema decisions, indexing strategy, migration approach, data ownership |
| `inter_component` | Sync vs async communication, protocol choice, contract design, event schema |
| `infrastructure` | Infrastructure choices — cloud services, deployment model, external dependencies |
| `security` | Authentication, authorisation, data sensitivity, encryption decisions |

```yaml
adr_triggers:
  - domain_modelling
  - data_design
  - inter_component
  # - infrastructure
  # - security
```

Decisions in categories not listed here are still surfaced during design — the
engineer can always choose to document them as ADRs. This list controls which
categories trigger an automatic ADR prompt.

---

### `artefacts`

Which design artefacts are produced during the design phase. Remove entries
your team does not need.

| Value | File produced | When to remove |
|---|---|---|
| `domain_model` | `domain-model.yaml` | Never — always required |
| `use_cases` | `use-case-flows.yaml` | Never — always required |
| `error_catalog` | `error-catalog.yaml` | Never — always required |
| `api_contract` | `api-contracts.yaml` | Remove for pure event-driven services with no HTTP surface |
| `events` | `events.yaml` | Remove for services that neither publish nor consume events |
| `glossary` | `glossary.yaml` | Remove only if the team maintains a glossary elsewhere |
| `scenarios` | `scenarios/*.feature` | Never — BDD scenarios are mandatory |
| `ops_checklist` | `ops-checklist.yaml` | Remove for internal-only services with no operational concerns |

```yaml
artefacts:
  - domain_model
  - use_cases
  - error_catalog
  - api_contract
  - events
  - glossary
  - scenarios
  - ops_checklist
```

---

### `version_control`

Controls how skills interact with git.

| Field | Default | Description |
|---|---|---|
| `remote` | `origin` | Git remote to push to after each commit |
| `main_branch` | `main` | Branch used as base when creating feature branches |

```yaml
version_control:
  remote: origin
  main_branch: main
```

---

### `coding_rules`

The coding rules enforced by skills and reviewed by `ai26-review-user-story`.
Pre-filled by `ai26-onboard-team` from the plugin — teams edit only when their
project intentionally deviates from the standard.

Rules are grouped by layer. Each entry is a rule ID and a one-liner description:

```yaml
coding_rules:
  cross_cutting:
    CC-01: "Domain layer: zero framework imports (org.springframework.*, jakarta.*, org.jooq.*)"
    CC-02: "Infrastructure classes in inbound/ or outbound/ — nothing flat in infrastructure/"
    # ...
  domain:
    D-01: "Aggregate root: class with private constructor — NOT data class"
    # ...
  application:
    A-01: "Use case returns Either<SealedError, DTO> — never raw domain entities"
    # ...
  infrastructure:
    I-01: "Controllers are humble objects — delegate to use case, no business logic"
    # ...
  testing:
    T-01: "TestContainers only — never H2"
    # ...
```

**Rule IDs are stable** — the text may be refined but the ID never changes.
Skills reference rule IDs (e.g. `CC-01`, `D-09`) to cite which rule a generated
pattern satisfies. `ai26-review-user-story` uses the full list to check compliance.

#### Relationship to the plugin

`coding_rules` in `config.yaml` is the **project-side** half of a two-part system:

| File | Owner | Purpose |
|---|---|---|
| `ai26/config.yaml → coding_rules` | Project (developer's repo) | Defines which rules exist and their text. Customizable per team. |
| `docs/coding-standards/recipes/rule-index.yaml` | Plugin | Maps each rule ID to the recipe file(s) that explain it. Identical across all teams. |

The generator script (`scripts/generate-coding-rules-doc.sh`) reads both files
and produces `docs/ai26-sdlc/reference/coding-rules.md`. See
[Coding Rules Maintenance](#coding-rules-maintenance) below.

#### Adding or changing a rule

1. Edit `coding_rules` in `ai26/config.yaml` — add, change, or remove a rule ID.
2. If adding a new rule, add it to `docs/coding-standards/recipes/rule-index.yaml`
   and to the `rules:` front matter of the relevant recipe file(s).
3. Run `./scripts/generate-coding-rules-doc.sh` to regenerate the reference table.
4. Run `./scripts/validate-coding-rules.sh` to confirm everything is consistent.

---

### `coding_rules` maintenance scripts

Two scripts in `scripts/` keep the coding rules system consistent.

#### `scripts/generate-coding-rules-doc.sh`

Generates `docs/ai26-sdlc/reference/coding-rules.md` from `ai26/config.yaml`
and `docs/coding-standards/recipes/rule-index.yaml`.

```bash
# Regenerate the reference table
./scripts/generate-coding-rules-doc.sh

# CI mode — exits 1 if the file would change (use in pre-merge checks)
./scripts/generate-coding-rules-doc.sh --check
```

The output file has a `<!-- GENERATED -->` header — do not edit it manually.

#### `scripts/validate-coding-rules.sh`

Checks bidirectional consistency across all three layers. Run after any change
to `coding_rules`, `rule-index.yaml`, or recipe front matter.

```bash
./scripts/validate-coding-rules.sh
```

Checks performed:

| Check | What it catches |
|---|---|
| Every rule has a recipe mapping | Rule added to config.yaml but not to rule-index.yaml |
| Every recipe file exists | Typo in rule-index.yaml pointing to a non-existent file |
| Every mapping has a valid rule ID | Orphaned entry in rule-index.yaml |
| Front matter matches mapping (both directions) | Recipe front matter out of sync with rule-index.yaml |
| No orphaned front matter | Recipe has `rules:` front matter but is not in rule-index.yaml |

---

### `promotion`

Controls where promoted artefacts land.

| Field | Default | Description |
|---|---|---|
| `architecture_docs_path` | `docs/architecture/modules` | Directory where module documentation is written after promotion |
| `adr_path` | `docs/adr` | Directory where ADR files are written |
| `keep_feature_workspace` | `false` | If `false`, `ai26/features/{TICKET}/` is deleted after successful promotion. Set `true` to keep artefacts for reference. |

```yaml
promotion:
  architecture_docs_path: docs/architecture/modules
  adr_path: docs/adr
  keep_feature_workspace: false
```

---

## Defaults

If `ai26/config.yaml` is absent, skills apply these defaults:

| Setting | Default |
|---|---|
| `interaction_style` | `socratic` |
| `stack` | detected from repo (build.gradle → kotlin/spring-boot/gradle, package.json → typescript/express/npm, …) |
| `modules` | single entry inferred from repo root, `active: true`, conventions detected from code |
| `adr_triggers` | `domain_modelling`, `data_design`, `inter_component` |
| `artefacts` | all |
| `version_control.remote` | `origin` |
| `version_control.main_branch` | `main` |
| `promotion.architecture_docs_path` | `docs/architecture/modules` |
| `promotion.adr_path` | `docs/adr` |
| `promotion.keep_feature_workspace` | `false` |

---

## Minimal configuration

The smallest valid config for a single-module project:

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

Everything else uses defaults.

---

## Local skill overrides

If a team needs to customise a marketplace skill without forking it, they place
an override in `.claude/skills/{skill-name}/SKILL.md`. The skill loader checks
the local path first.

This allows teams to:
- Add company-specific constraints to a skill
- Change the output format for a specific artefact
- Extend a step with project-specific logic

Overrides are local only — they do not affect other teams using the same
marketplace skill.
