# Adoption Metrics

> Adoption without data is a guess. Metrics close the feedback loop.

---

## Why measure

The AI26 SDLC loop produces structured output at every checkpoint. Capturing that
output makes it possible to answer questions that teams actually care about:

- What fraction of PRs went through the full AI26 loop?
- How often does validation pass on the first run vs. requiring fixes?
- Which review checks generate the most blocking violations?
- Are design-first tickets faster to implement than backfilled ones?

Without persistent, machine-readable records these questions can only be answered
by reading commit messages or asking engineers — both unreliable. The metrics system
collects the data that already exists inside the SDLC skills so aggregation is a
later, straightforward step.

---

## Data sources

| Source | Where | Written by | What it captures |
|--------|-------|------------|-----------------|
| `validation-report.json` | `ai26/features/{TICKET}/` | `ai26-validate-user-story` | Design↔code coherence, test coverage, ticket↔design coherence, pass/fail, violation counts |
| `review-report.json` | `ai26/features/{TICKET}/` | `ai26-review-user-story` | Layer rule checks, DDD pattern checks, error handling, test quality, API/event contract alignment, pass/fail, violation counts |
| Jira label `ai26-promoted` | Jira ticket | `ai26-promote-user-story` | Whether a ticket completed the full AI26 loop (filterable in any dashboard or JQL query) |
| `ai26/context/LEARNINGS.md` | Repository | `ai26-compound-resolve` | Graduated observations from past tickets — qualitative institutional memory |

All JSON reports are committed into the feature branch alongside the design artefacts.
They survive as long as the branch is open and can be aggregated from git history after merge.

---

## Metrics catalog

### Adoption rate

| Metric | Source | Healthy signal |
|--------|--------|---------------|
| % of merged PRs with `ai26-promoted` Jira label | Jira JQL | > 80% of feature PRs |
| % of tickets with `validation-report.json` in git history | git + JSON reports | Matches or exceeds adoption rate |
| Design-first vs. backfill ratio | Presence of `domain-model.yaml` before first commit | > 70% design-first |

### Validation health

| Metric | Source | Healthy signal |
|--------|--------|---------------|
| Validation pass rate (first run) | `validation-report.json` → `status` | > 75% PASS on first run |
| Average blocking violations on fail | `validation-report.json` → `blocking_violations` | Trending down over time |
| Most-violated check | `validation-report.json` → `checks[*].status` | No single check > 30% fail rate |

### Review health

| Metric | Source | Healthy signal |
|--------|--------|---------------|
| Review pass rate (first run) | `review-report.json` → `status` | > 70% PASS on first run |
| Most-violated review check | `review-report.json` → `checks[*].violations` | Trending down after LEARNINGS additions |
| Warning-to-blocking ratio | `review-report.json` → `warnings` / `blocking_violations` | Blocking violations near zero; warnings acceptable |
| Known-mistakes hits | `review-report.json` → `checks.known_mistakes.violations` | Should converge to 0 as LEARNINGS grows |

---

## Report JSON schemas

### validation-report.json

Written by `ai26-validate-user-story` to `ai26/features/{TICKET}/validation-report.json`.
Committed alongside `plan.md` in the validate commit.

```json
{
  "ticket": "SXG-1234",
  "timestamp": "2026-03-12T14:30:00Z",
  "status": "PASS",
  "checks": {
    "design_code_coherence": { "status": "pass", "traced": 12, "total": 12 },
    "test_coverage": {
      "status": "pass",
      "scenarios": 8,
      "error_paths": 5,
      "tests_passing": true
    },
    "ticket_design_coherence": { "status": "pass", "acs_covered": 3, "acs_total": 3 }
  },
  "blocking_violations": 0,
  "warnings": 1
}
```

`status` values: `"PASS"` | `"FAIL"`
Check-level `status` values: `"pass"` | `"warn"` | `"fail"`

Always written — including when validation fails. Failure data is as valuable as
success data for trend analysis.

### review-report.json

Written by `ai26-review-user-story` to `ai26/features/{TICKET}/review-report.json`.
Committed alongside `plan.md` in the review commit.

```json
{
  "ticket": "SXG-1234",
  "timestamp": "2026-03-12T15:00:00Z",
  "status": "PASS",
  "checks": {
    "clean_architecture": { "status": "pass", "files_checked": 14, "violations": 0 },
    "ddd_patterns": { "status": "pass", "aggregates": 2, "use_cases": 3, "violations": 0 },
    "error_handling": { "status": "pass", "violations": 0 },
    "test_quality": {
      "status": "warn",
      "blocking": 0,
      "warnings": 2,
      "rules": ["T-03", "T-08"]
    },
    "api_contracts": { "status": "pass", "endpoints": 4, "violations": 0 },
    "event_contracts": { "status": "pass", "events": 2, "violations": 0 },
    "known_mistakes": { "status": "pass", "learnings_checked": 5, "violations": 0 }
  },
  "blocking_violations": 0,
  "warnings": 2
}
```

`status` values: `"PASS"` | `"FAIL"`
Check-level `status` values: `"pass"` | `"warn"` | `"fail"`

Always written — including on failure.

---

## Jira label

Label name: **`ai26-promoted`**

Added by `ai26-promote-user-story` (Step 7c) to the Jira ticket via MCP after promotion
completes. The label is additive — it does not overwrite existing labels.

### JQL examples

```
# All tickets that completed the full AI26 loop
labels = "ai26-promoted"

# AI26-promoted tickets in a specific project
project = SXG AND labels = "ai26-promoted"

# AI26-promoted tickets in the last 30 days
labels = "ai26-promoted" AND updated >= -30d

# Tickets NOT yet promoted (no AI26 loop)
project = SXG AND labels not in ("ai26-promoted") AND issuetype = Story
```

These queries can be saved as Jira dashboard gadgets or board filters to give
product leads a real-time view of AI26 adoption.

---

## Future: aggregation script

**Deferred** until enough JSON reports have accumulated to make aggregation meaningful
(target: ≥ 20 tickets with both validation and review reports).

When the time comes, the intended script (`scripts/ai26-metrics.sh` or equivalent) will:

1. Walk the git log for merged feature branches
2. Extract `validation-report.json` and `review-report.json` from each
3. Aggregate per-metric statistics (pass rates, average violation counts, trends)
4. Output a markdown summary to `docs/ai26-sdlc/metrics/latest.md`

The script will not require any new data collection — everything it needs is already
being written by the skills today.

---

## What is NOT measured and why

### Git log parsing

Detecting AI26 usage from commit message patterns (e.g., grepping for `validate:` or
`review:`) was rejected because:

- Engineers sometimes amend or reword commits
- Squash merges lose individual commit messages
- A passing commit message does not mean the check actually passed

The JSON reports are authoritative. Git log parsing is a heuristic at best.

### PR description checkboxes

Asking engineers to tick "I ran ai26-validate" in a PR template was rejected because:

- Honor-system data degrades under deadline pressure
- It measures intention, not execution
- It produces no structured data for trend analysis

The Jira label is set programmatically by the skill — not by the engineer.

### Quality scores

Composite "quality score" metrics (e.g., score out of 100 per ticket) were deferred
because:

- The weights are arbitrary without baseline data
- They invite gaming rather than improvement
- Counts of violations per check are more actionable and less gameable

Scores can be revisited once raw violation data has accumulated and weight calibration
is evidence-based.
