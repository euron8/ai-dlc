#!/usr/bin/env bash
# validate-ci-gates.sh — Shallow dormant-gate detector for CI gates declared in retros.
#
# Tool dependencies: bash ≥3.2, grep, find
# No hard dep on jq/yq/rg (portable subset; each is checked-and-degraded if referenced).
#
# Exit codes:
#   0 — clean scan (no dormant gates)
#   1 — one or more dormant gates detected (declared in a retro but no workflow reference)
#   2 — tool-availability failure
#
# Contract:
#   Scans docs/retro/**/*.md for declared CI gate names using the patterns below, then
#   grep's .github/workflows/** for each gate name. A declared gate with zero workflow
#   matches is flagged as DORMANT. Deeper GHA-API introspection is intentionally out of
#   scope — this is a file-grep first-line defense.
#
# Declaration pattern (case-insensitive, canonical form):
#   - "CI gate `<NAME>`"  — backtick-quoted gate name after the explicit
#                           "CI gate" phrase.
#
# Only backtick-quoted gate names after the explicit "CI gate" phrase are
# harvested. This deliberately narrows the surface from free-form prose to
# the explicit declaration retros MUST use when adding a new gate. Test
# names, generic noun-phrase "the gate", and free-form mentions are out of
# scope — this is a shallow first-line defense, not full semantic parsing.
#
# Rule authored per FR-S153-1.2 (Sprint 153 Story 153-1); rule text lives in
# .claude/skills/ai-dlc/steps/retro.md under "Empirical gate validation".

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RETRO_DIR="${REPO_ROOT}/docs/retro"
WORKFLOW_DIR="${REPO_ROOT}/.github/workflows"

if ! command -v grep >/dev/null 2>&1; then
  echo "ERROR: grep not available" >&2
  exit 2
fi
if ! command -v find >/dev/null 2>&1; then
  echo "ERROR: find not available" >&2
  exit 2
fi

if [ ! -d "${RETRO_DIR}" ]; then
  echo "Scanned 0 retros, 0 gates declared, 0 dormant (no docs/retro/ directory)"
  exit 0
fi
if [ ! -d "${WORKFLOW_DIR}" ]; then
  echo "ERROR: .github/workflows/ directory missing" >&2
  exit 2
fi

retro_count=0
dormant_count=0
# Match backtick-quoted gate name preceded by the explicit "CI gate"
# declaration phrase. Only this form is harvested to avoid false positives on
# test-function mentions, generic prose, or "the gate" noun phrases.
declare_pattern='CI gate `[^`]+`'

# Collect declared gate names (portable: avoid mapfile for bash 3.2 compat).
declared_gates=""
while IFS= read -r retro_file; do
  retro_count=$((retro_count + 1))
  # Use sed/awk to pull backtick-delimited tokens after a declaration phrase.
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    declared_gates="${declared_gates}${name}
"
  done < <(grep -hoEi "$declare_pattern" "$retro_file" 2>/dev/null \
           | sed -E 's/^[^`]*`([^`]+)`.*$/\1/' \
           || true)
done < <(find "${RETRO_DIR}" -type f -name '*.md' 2>/dev/null)

# Deduplicate.
unique_gates=$(printf '%s' "$declared_gates" | awk 'NF' | sort -u)

if [ -z "$unique_gates" ]; then
  echo "Scanned ${retro_count} retros, 0 gates declared, 0 dormant"
  exit 0
fi

# For each unique declared gate, grep workflows/ for the name.
while IFS= read -r gate; do
  [ -z "$gate" ] && continue
  if ! grep -rqF -- "$gate" "${WORKFLOW_DIR}" 2>/dev/null; then
    echo "DORMANT: gate '${gate}' declared in retro but no match in .github/workflows/" >&2
    dormant_count=$((dormant_count + 1))
  fi
done <<EOF
$unique_gates
EOF

# Recount gate_count as unique for reporting.
unique_count=$(printf '%s\n' "$unique_gates" | awk 'NF' | wc -l | tr -d ' ')

echo "Scanned ${retro_count} retros, ${unique_count} gates declared, ${dormant_count} dormant"

if [ "$dormant_count" -gt 0 ]; then
  exit 1
fi
exit 0
