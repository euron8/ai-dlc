#!/usr/bin/env bash
# seed.sh — a REAL distribution git repo and a REAL consumer tree for the layer conformance
# adjudication (`level: ADJUDICATED`, LC-A1, LC-A2).
#
# Everything below is written to disk and committed. A seed that PRINTS a description of a
# fixture instead of writing one cannot fail, and v0.48.0 shipped three of those.
#
# THE SEED CARRIES ITS OWN CONTRACT AND ITS OWN SCHEMA, and that is the point of the whole
# fixture. `layer-drift.sh` derives which clauses are adjudicable by reading `layer-contract.yaml`
# at THEIRS, and derives the verdict vocabulary by reading the register schema at THEIRS. A
# fixture that pointed at the distribution's real copies would be asserting against the tree it
# lives in; pointing at seeded copies is what lets Part 5 flip a clause's LEVEL and watch the
# blocking row appear and disappear. If the reader ever stops consulting the contract, that part
# fails — which no assertion about the shipped contract could detect.
#
# The distribution carries two commits, and ONLY the hooked file's body moves:
#
#   BASE    steps/demo.md defines Alpha and Gamma
#   THEIRS  Gamma's body is rewritten
#
# Prints the sandbox root on stdout.
set -euo pipefail

ROOT="$(mktemp -d)"
DIST="$ROOT/dist"
CONS="$ROOT/consumer"

SKILL_REL="core/skills/ai-dlc"
mkdir -p "$DIST/$SKILL_REL/steps" "$DIST/core/schemas"
git -C "$DIST" init -q
git -C "$DIST" config user.email f@x
git -C "$DIST" config user.name f

# ---------------------------------------------------------------------------
# The contract. Two clauses, one adjudicable and one NOT, so every assertion
# below has a same-run control: a status that must never acquire the duty.
# The field ORDER matters — `level:` precedes `code:`, which is what lets the
# reader's single pass carry a level forward onto the code it belongs to.
# ---------------------------------------------------------------------------
cat > "$DIST/$SKILL_REL/layer-contract.yaml" <<'EOF'
# LAYER_CONTRACT (seeded)
contract_version: 7

clauses:

  - id: LC-E4
    subject: extension
    level: ADJUDICATED
    since: 1
    normative: >-
      Seeded stand-in for the re-read duty.
    prose_home: core/skills/ai-dlc/extensions/README.md
    enforcer: core/skills/ai-dlc-update/reconcile/layer-drift.sh
    code: EXTENSION-HOOK-DRIFT

  - id: LC-E3
    subject: extension
    level: WARN
    since: 1
    normative: >-
      Seeded stand-in for a report-only clause. This one must NEVER acquire the recorded-verdict
      duty, and it is the control for every assertion that a blocking row appeared.
    prose_home: core/skills/ai-dlc/extensions/README.md
    enforcer: core/skills/ai-dlc-update/reconcile/layer-drift.sh
    code: EXTENSION-HOOK-MISSING
EOF

# ---------------------------------------------------------------------------
# The register schema. The verdict vocabulary lives in its `verdict` enum and
# nowhere else; the reader parses THIS, so a fixture that hard-coded the three
# strings would pass against a reader that had stopped consulting the schema.
# ONE VALUE PER LINE is load-bearing for that parse.
# ---------------------------------------------------------------------------
cat > "$DIST/core/schemas/layer-adjudication-register.json" <<'EOF'
{
  "type": "object",
  "required": ["clause", "entry", "subject_digest", "verdict", "recorded_utc", "reason"],
  "properties": {
    "verdict": {
      "type": "string",
      "enum": [
        "still-additive",
        "contradicts-core",
        "retire"
      ]
    }
  }
}
EOF

cat > "$DIST/$SKILL_REL/steps/demo.md" <<'EOF'
# Demo step

## Alpha gate

Alpha's body, unchanged across the range.

## Gamma review

Gamma's body at BASE.
EOF

git -C "$DIST" add -A
git -C "$DIST" commit -qm "base"

cat > "$DIST/$SKILL_REL/steps/demo.md" <<'EOF'
# Demo step

## Alpha gate

Alpha's body, unchanged across the range.

## Gamma review

Gamma's body at THEIRS — REWRITTEN. This is the change the re-read duty fires on.
EOF

git -C "$DIST" add -A
git -C "$DIST" commit -qm "theirs: rewrite Gamma"

# ---------------------------------------------------------------------------
# The consumer. One entry hooking the changed file, so exactly one row of the
# adjudicable clause exists and a count is an unambiguous assertion.
# ---------------------------------------------------------------------------
CSKILL="$CONS/.claude/skills/ai-dlc"
mkdir -p "$CSKILL/extensions" "$CSKILL/overrides" "$CSKILL/steps" \
         "$CONS/_bmad-output/ai-dlc-update"
git -C "$DIST" show "HEAD~1:$SKILL_REL/steps/demo.md" > "$CSKILL/steps/demo.md"

cat > "$CSKILL/extensions/adjudicable.md" <<'EOF'
---
kind: check
hooks: steps/demo.md
reason: seeded entry whose hooked core file moves across the range
---

### 901. [ext:adjudicable] Consumer entry.

Body.
EOF

printf '%s\n' "$ROOT"
