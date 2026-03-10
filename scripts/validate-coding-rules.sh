#!/usr/bin/env bash
# validate-coding-rules.sh
# Checks bidirectional consistency between:
#   - coding_rules IDs in ai26/config.yaml
#   - rule→recipe mapping in docs/coding-standards/recipes/rule-index.yaml
#   - YAML front matter in docs/coding-standards/recipes/*.md
#
# Exits 0 if everything is consistent, 1 on any violation.
# Requires: python3 (stdlib only)
#
# Usage:
#   ./scripts/validate-coding-rules.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO_ROOT/ai26/config.yaml"
RULE_INDEX="$REPO_ROOT/docs/coding-standards/recipes/rule-index.yaml"
RECIPES_DIR="$REPO_ROOT/docs/coding-standards/recipes"

python3 - "$CONFIG" "$RULE_INDEX" "$RECIPES_DIR" <<'PYEOF'
import sys
import re
from pathlib import Path

config_path     = Path(sys.argv[1])
rule_index_path = Path(sys.argv[2])
recipes_dir     = Path(sys.argv[3])
errors = []

# ── parse coding_rules from config.yaml ──────────────────────────────────────
coding_rule_ids = set()
in_coding_rules = False
for line in config_path.read_text().splitlines():
    stripped = line.rstrip()
    if stripped == "coding_rules:":
        in_coding_rules = True
        continue
    if in_coding_rules:
        if stripped and not stripped.startswith(" ") and stripped.endswith(":"):
            in_coding_rules = False
            continue
        m = re.match(r'^    ([A-Z]+-\d+): ".+"$', stripped)
        if m:
            coding_rule_ids.add(m.group(1))

# ── parse rule-index.yaml ─────────────────────────────────────────────────────
rule_recipes = {}  # {rule_id: [file, ...]}
for line in rule_index_path.read_text().splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    m = re.match(r"^([A-Z]+-\d+): \[(.+)\]$", stripped)
    if m:
        files = [f.strip() for f in m.group(2).split(",")]
        rule_recipes[m.group(1)] = files

# ── check 1: every coding_rule has a rule_recipes entry ─────────────────────
for rid in sorted(coding_rule_ids):
    if rid not in rule_recipes:
        errors.append(f"[MISSING RECIPE MAPPING] {rid} is in coding_rules but has no entry in rule-index.yaml")

# ── check 2: every rule_recipes entry refers to an existing file ─────────────
for rid, files in sorted(rule_recipes.items()):
    for fname in files:
        fpath = recipes_dir / fname
        if not fpath.exists():
            errors.append(f"[MISSING FILE] rule-index.yaml[{rid}] references '{fname}' but {fpath} does not exist")

# ── check 3: every rule_recipes entry has a known rule ID ────────────────────
for rid in sorted(rule_recipes):
    if rid not in coding_rule_ids:
        errors.append(f"[ORPHANED MAPPING] rule-index.yaml[{rid}] has no matching entry in coding_rules")

# ── check 4: parse recipe front matter and compare ───────────────────────────
recipe_to_rules = {}
for rid, files in rule_recipes.items():
    for fname in files:
        recipe_to_rules.setdefault(fname, set()).add(rid)

FRONT_MATTER_RE = re.compile(r"^---\s*\nrules:\s*\[([^\]]*)\]\s*\n---", re.MULTILINE)

for recipe_file in sorted(recipes_dir.glob("*.md")):
    content = recipe_file.read_text()
    fname   = recipe_file.name
    m = FRONT_MATTER_RE.match(content)

    if not m:
        errors.append(f"[MISSING FRONT MATTER] {fname} has no YAML front matter with rules:")
        continue

    fm_rules = set(r.strip() for r in m.group(1).split(",") if r.strip())

    for rid in sorted(fm_rules):
        if rid not in coding_rule_ids:
            errors.append(f"[UNKNOWN RULE IN FRONT MATTER] {fname} lists rule '{rid}' which is not in coding_rules")

    expected_rules = recipe_to_rules.get(fname, set())
    for rid in sorted(fm_rules - expected_rules):
        errors.append(
            f"[FRONT MATTER DRIFT] {fname} front matter lists '{rid}' "
            f"but rule-index.yaml[{rid}] does not include this file"
        )
    for rid in sorted(expected_rules - fm_rules):
        errors.append(
            f"[FRONT MATTER DRIFT] {fname} is listed in rule-index.yaml[{rid}] "
            f"but its front matter does not include '{rid}'"
        )

# ── check 5: orphaned recipe front matter ────────────────────────────────────
for recipe_file in sorted(recipes_dir.glob("*.md")):
    fname = recipe_file.name
    m = FRONT_MATTER_RE.match(recipe_file.read_text())
    if m:
        fm_rules = set(r.strip() for r in m.group(1).split(",") if r.strip())
        if fm_rules and not any(fname in files for files in rule_recipes.values()):
            errors.append(
                f"[ORPHANED RECIPE] {fname} has front matter rules {sorted(fm_rules)} "
                f"but is not referenced in rule-index.yaml"
            )

# ── report ────────────────────────────────────────────────────────────────────
if errors:
    print(f"validate-coding-rules: FAILED — {len(errors)} error(s)\n")
    for e in errors:
        print(f"  {e}")
    sys.exit(1)
else:
    rule_count   = len(coding_rule_ids)
    recipe_count = len(list(recipes_dir.glob("*.md")))
    print(f"validate-coding-rules: OK — {rule_count} rules, {recipe_count} recipes, all consistent")
    sys.exit(0)

PYEOF
