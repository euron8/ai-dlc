#!/usr/bin/env bash
# retro-audit-scans/seed.sh — build a minimal INSTALLED-PROJECT tree for the two
# scans retro Step 4 runs, resolve both real scripts, and print the WORK dir.
#
# The tree is synthetic on purpose: the assertions must be able to mutate it.
# Running the scans against the real repo can only ever show the current state,
# and a green run on an unmutated tree is not evidence that the scan can fail.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# core/fixtures/<name>/ upstream, tests/fixtures/<name>/ in a consumer — both three dirs below root.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/audit-rule-files.sh" ]; then
  AUDIT="$ROOT/core/scripts/audit-rule-files.sh"
  MANIFEST="$ROOT/core/scripts/validate-gate-manifest.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/audit-rule-files.sh" ]; then
  AUDIT="$ROOT/scripts/ai-dlc/audit-rule-files.sh"
  MANIFEST="$ROOT/scripts/ai-dlc/validate-gate-manifest.sh"
else
  echo "FIXTURE ERROR: audit-rule-files.sh not found in either layout" >&2
  exit 2
fi
[ -f "$MANIFEST" ] || { echo "FIXTURE ERROR: validate-gate-manifest.sh not found beside it" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/retro-audit-scans.XXXXXX")" || exit 2
P="$WORK/proj"
# The layer dirs exist and are EMPTY in the clean corpus. That is the unlayered
# state, and assertion 24 asserts the resolve is byte-identical to a pure-core one
# there — an empty layer dir must not change the answer, or every layered
# assertion below is reading a difference the layers did not cause.
mkdir -p "$P/.claude/skills/ai-dlc/steps" "$P/.claude/skills/ai-dlc/extensions" \
         "$P/.claude/skills/ai-dlc/overrides" \
         "$P/.claude/team-roles" "$P/docs"

# --- A CLEAN corpus. Every assertion mutates a copy of this. -----------------
cat > "$P/CLAUDE.md" <<'EOF'
# Project rules

The lead MUST run the gate before merging. A missing gate FAILs the PR.
EOF

cat > "$P/docs/coding-conventions.md" <<'EOF'
# Conventions

Every public function MUST carry a docstring. A missing docstring FAILs review.
EOF

cat > "$P/.claude/skills/ai-dlc/SKILL.md" <<'EOF'
# Skill

### Rule 1 -- Gates are non-negotiable

The lead MUST NOT merge past a red gate. Rule text lives in `rule-authoring.md`.

**Minimum mechanism (Rule 26(c)).** Failure caught: a red gate merged anyway.
False-positive cost: one re-read per blocked merge. Removal condition: retire
once the merge tool refuses a red gate structurally.
EOF

cat > "$P/.claude/skills/ai-dlc/rule-authoring.md" <<'EOF'
# Rule authoring
Rules are imperative.

**Style:**

- Give a rule a stable identifier a later rule can cite, and carry it in
  the rule's own heading: `Rule <n>` for a rule, `Step <n>` for a step-file
  section. An identifier is a name and MUST NOT encode a sprint, story,
  version, or date.
- No sprint or story references.
- No parenthetical origin notes after a directive.
EOF

cat > "$P/.claude/skills/ai-dlc/steps/example.md" <<'EOF'
# Example step

The lead MUST record the outcome. Procedure is defined in `steps/example.md`.
EOF

cat > "$P/.claude/team-roles/dev.md" <<'EOF'
# Dev
The dev MUST attach evidence to every submission.
EOF

# --- gate-validation.md with a well-formed manifest + matching anchors -------
cat > "$P/.claude/skills/ai-dlc/steps/gate-validation.md" <<'EOF'
# Gate validation

<!-- GATE_MANIFEST v1
| gate type | checks |
|-----------|--------|
| universal | 1, 2 |
| retro     | 3 |
GATE_MANIFEST_END -->

### 1. First
<!-- CHECK_LOADED: 1 -->

### 2. Second
<!-- CHECK_LOADED: 2 -->

### 3. Third
<!-- CHECK_LOADED: 3 -->
EOF

# --- core-manifest.md, so OWNERSHIP can resolve in this tree ------------------
# The audit tags every finding `[core]` or `[local]` by asking `core-paths.sh`,
# which derives the core set from this file. Without it the resolver cannot
# answer, every finding scores `unknown`, and the ownership arms would be
# measuring a broken resolver rather than the split. Entries are skill-relative
# bare paths -- the parser strips `- ` and nothing else, so a backticked or
# project-relative entry yields a corrupted glob that matches nothing and reads
# as a clean `local` for the whole tree.
#
# `docs/coding-conventions.md` is deliberately NOT listed: it is the LOCAL half,
# and an arm that seeds an offender there is what separates the two verdicts.
cat > "$P/.claude/skills/ai-dlc/core-manifest.md" <<'EOF'
# Core manifest

core_manifest:
  - SKILL.md
  - steps/*.md
  - rule-authoring.md
EOF

# The resolver the audit shells to for ownership. It is a SIBLING of the audit in
# both layouts (`core/scripts/*` is a derived glob in install.sh), so it is
# resolved beside $AUDIT rather than under the project tree.
RESOLVER="$(dirname "$AUDIT")/core-paths.sh"
[ -f "$RESOLVER" ] || { echo "FIXTURE ERROR: core-paths.sh not found beside audit-rule-files.sh" >&2; exit 2; }

cat > "$WORK/env.sh" <<EOF
AUDIT="$AUDIT"
MANIFEST="$MANIFEST"
RESOLVER="$RESOLVER"
PROJ="$P"
export AUDIT MANIFEST RESOLVER PROJ
EOF

echo "$WORK"
