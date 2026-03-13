# AI26

AI26 is the development operating system for N26 engineering teams. It is a collection of Claude Code skills plus a structured context layer that make AI-assisted development systematic, auditable, and self-improving.

**Key idea:** every feature you build leaves the codebase smarter than before — the AI accumulates institutional memory across tickets, so the next feature is faster to build correctly.

---

## Quick start

### As an engineer

Start from the entry point that matches your situation:

| Flow | When | Entry point |
|------|------|-------------|
| **Epic** | New business initiative → multiple tickets | `/ai26-write-prd EPIC-123` then `/ai26-design-epic EPIC-123` |
| **Ticket** | Single feature or bug ticket | `/ai26-start-sdlc SXG-1234` |
| **Quick fix** | Obvious bug, typo, dependency bump | `/ai26-start-sdlc --quickfix SXG-888` |

For tickets, `ai26-start-sdlc` reads Jira, checks the team's context files, and routes automatically.

**Every ticket lifecycle:**
```
Design → Implement → Validate (auto) → Review → Promote → Open PR
```

**Shortcuts if you know what you want:**

```bash
/ai26-start-sdlc --ticket SXG-123   # Design + build a feature
/ai26-start-sdlc --fix SXG-456      # Fix a bug
/ai26-start-sdlc --quickfix SXG-888 # Quick fix, no design
/ai26-start-sdlc --migrate chat     # Migrate a legacy module
/ai26-start-sdlc --check            # Verify your setup
```

---

### As a PM

You engage at three points:

1. **PRD authoring** — co-author the epic with the AI in plain language
   ```
   /ai26-write-prd EPIC-123
   ```
2. **Epic sign-off** — review the domain design and ticket decomposition
   ```
   /ai26-design-epic EPIC-123
   ```
3. **Scenario review** — read `scenarios/*.feature` files to verify the feature matches your intent (no code required)

---

## Setup (new team)

```
/ai26-onboard-team
```

Creates `ai26/config.yaml`, builds the five context files (`DOMAIN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `DEBT.md`, `INTEGRATIONS.md`), and generates C1/C4 diagrams.

**Prerequisites:**
- Claude Code installed and configured
- AI26 skills installed (`/marketplace install ai26`)
- Jira MCP connected to your project

---

## How the compound loop works

```
Design artefacts
      ↓
Implement (AI reads artefacts, generates code)
      ↓
Validate (checks design-to-code coherence + test coverage)
      ↓
Promote ← this is what makes the system improve
      ↓
ai26/context/ updated + docs/architecture/ updated
      ↓
Next ticket starts with accumulated memory
```

Skip the promote step and you get code. Run it consistently and the AI gets measurably better with each ticket.

---

## Guides

Full documentation in [`docs/guide/`](./docs/guide/):

| Audience | Guide |
|----------|-------|
| New to AI26 | [ai26-in-5-minutes.md](./docs/guide/ai26-in-5-minutes.md) |
| Engineers | [engineer-guide.md](./docs/guide/engineer-guide.md) |
| Product Managers | [pm-guide.md](./docs/guide/pm-guide.md) |
| Tech Leads | [tech-lead-guide.md](./docs/guide/tech-lead-guide.md) |
| Directors | [director-guide.md](./docs/guide/director-guide.md) |
| All skills reference | [skill-catalog.md](./docs/guide/skill-catalog.md) |
| Glossary | [glossary.md](./docs/guide/glossary.md) |
| Something broke | [troubleshooting.md](./docs/guide/troubleshooting.md) |
