#!/usr/bin/env bash
# generate-coding-rules-doc.sh
# Generates docs/ai26-sdlc/reference/coding-rules.md.
#   - coding_rules (rule IDs + text)  → read from ai26/config.yaml
#   - rule→recipe mapping             → read from docs/coding-standards/recipes/rule-index.yaml
# Requires: python3 (stdlib only — no yq needed)
#
# Usage:
#   ./scripts/generate-coding-rules-doc.sh
#   ./scripts/generate-coding-rules-doc.sh --check   # exits 1 if file would change (CI mode)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO_ROOT/ai26/config.yaml"
RULE_INDEX="$REPO_ROOT/docs/coding-standards/recipes/rule-index.yaml"
OUTPUT="$REPO_ROOT/docs/ai26-sdlc/reference/coding-rules.md"
CHECK_MODE=false

if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=true
fi

python3 - "$CONFIG" "$RULE_INDEX" "$OUTPUT" "$CHECK_MODE" <<'PYEOF'
import sys
import re
from pathlib import Path

config_path    = Path(sys.argv[1])
rule_index_path = Path(sys.argv[2])
output_path    = Path(sys.argv[3])
check_mode     = sys.argv[4].lower() == "true"

# ── parse coding_rules from config.yaml ──────────────────────────────────────
# Reads the nested coding_rules block:
#   coding_rules:
#     cross_cutting:
#       CC-01: "text"
#     domain:
#       D-01: "text"

def parse_coding_rules(text):
    coding_rules = {}
    in_coding_rules = False
    for line in text.splitlines():
        stripped = line.rstrip()
        if stripped == "coding_rules:":
            in_coding_rules = True
            continue
        if in_coding_rules:
            if stripped and not stripped.startswith(" ") and stripped.endswith(":"):
                in_coding_rules = False
                continue
            m = re.match(r'^    ([A-Z]+-\d+): "(.+)"$', stripped)
            if m:
                coding_rules[m.group(1)] = m.group(2)
    return coding_rules

# ── parse rule-index.yaml ─────────────────────────────────────────────────────
# Flat YAML: CC-01: [domain.md]
# Comments and blank lines are ignored.

def parse_rule_index(text):
    rule_recipes = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = re.match(r"^([A-Z]+-\d+): \[(.+)\]$", stripped)
        if m:
            files = [f.strip() for f in m.group(2).split(",")]
            rule_recipes[m.group(1)] = files
    return rule_recipes

coding_rules = parse_coding_rules(config_path.read_text())
rule_recipes  = parse_rule_index(rule_index_path.read_text())

# ── preserve Skills column from existing output ───────────────────────────────
# Skills are hand-maintained in the output file — not derived from SKILL.md files.
# Only lines whose last column contains backticks are captured (avoids matching
# other table rows with single-word values like "HIGH", "MEDIUM").
existing_skill_refs = {}
if output_path.exists():
    for line in output_path.read_text().splitlines():
        m = re.match(r"^\| ([A-Z]+-\d+) \|.*\| (`.+`) \|$", line)
        if m:
            existing_skill_refs[m.group(1)] = m.group(2).strip()

# ── rule ordering (matches config.yaml section order) ───────────────────────
SECTIONS = [
    ("Clean Architecture (CC)", [k for k in coding_rules if k.startswith("CC-")]),
    ("Domain (D)",              [k for k in coding_rules if k.startswith("D-")]),
    ("Application (A)",         [k for k in coding_rules if k.startswith("A-")]),
    ("Infrastructure (I)",      [k for k in coding_rules if k.startswith("I-")]),
    ("Testing (T)",             [k for k in coding_rules if k.startswith("T-")]),
]

def recipe_links(rule_id):
    files = rule_recipes.get(rule_id, [])
    return ", ".join(f"[`{f}`](../../coding-standards/recipes/{f})" for f in files)

def skill_cell(rule_id):
    return existing_skill_refs.get(rule_id, "`ai26-review-user-story`")

# ── build output ─────────────────────────────────────────────────────────────
lines_out = []
lines_out.append("<!-- GENERATED from ai26/config.yaml + docs/coding-standards/recipes/rule-index.yaml")
lines_out.append("     Do not edit manually. Run: ./scripts/generate-coding-rules-doc.sh -->")
lines_out.append("")
lines_out.append("# Coding Rules Reference")
lines_out.append("")
lines_out.append("> Every rule has an ID. Use the ID when discussing violations in code review, in `ai26-review-user-story` output, and in CHECKS.md entries. The ID is stable — the rule text may be refined over time.")
lines_out.append("")
lines_out.append("---")
lines_out.append("")
lines_out.append("## How to use this document")
lines_out.append("")
lines_out.append("- **Implementing a feature** → read the recipe linked in the \"Recipe\" column for the layer you are working in.")
lines_out.append("- **In code review** → reference the rule ID (e.g. `D-01`) so the discussion is unambiguous.")
lines_out.append("- **Updating a rule** → change `ai26/config.yaml` → `coding_rules`, then run `./scripts/generate-coding-rules-doc.sh` to regenerate this file.")
lines_out.append("")
lines_out.append("---")
lines_out.append("")

for section_title, rule_ids in SECTIONS:
    if not rule_ids:
        continue
    lines_out.append(f"## {section_title}")
    lines_out.append("")
    lines_out.append("| ID | Rule | Recipe | Skills |")
    lines_out.append("|---|---|---|---|")
    for rid in rule_ids:
        rule_text = coding_rules.get(rid, "").replace("|", "\\|")
        lines_out.append(f"| {rid} | {rule_text} | {recipe_links(rid)} | {skill_cell(rid)} |")
    lines_out.append("")
    lines_out.append("---")
    lines_out.append("")

content = "\n".join(lines_out).rstrip() + "\n"

if check_mode:
    existing = output_path.read_text() if output_path.exists() else ""
    if existing != content:
        print("ERROR: coding-rules.md is out of date. Run ./scripts/generate-coding-rules-doc.sh")
        sys.exit(1)
    else:
        print("OK: coding-rules.md is up to date.")
else:
    output_path.write_text(content)
    print(f"Written: {output_path}")

PYEOF
