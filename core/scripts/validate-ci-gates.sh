#!/usr/bin/env bash
# validate-ci-gates.sh — Shallow dormant-gate detector for CI gates declared in retros.
#
# Tool dependencies: bash ≥3.2, grep, find
# No hard dep on jq/yq/rg (portable subset; each is checked-and-degraded if referenced).
#
# Exit codes:
#   0  — clean scan (no dormant gates)
#   1  — one or more dormant gates detected (declared in a retro, no enforcer match)
#   2  — tool-availability failure
#   78 — VACUOUS: no enforcement surface exists to scan against. A check that CANNOT
#        run must not share an exit code with one that ran and passed (0) or one that
#        ran and found a specific dormant gate (1). A consumer that disabled GitHub
#        Actions and points AI_DLC_CI_SURFACE at a missing/empty directory reaches this.
#
# Contract:
#   Scans docs/retro/**/*.md for declared CI gate names using the patterns below, then
#   checks each name against the enforcement surface (AI_DLC_CI_SURFACE, default
#   .github/workflows/). A declared gate with no enforcer match is flagged as DORMANT.
#   Deeper GHA-API introspection is intentionally out of scope — a file-grep first-line
#   defense.
#
#   The match is COMMENT-AWARE, not a raw substring: a gate name that survives only in a
#   `#` comment (a banner left behind after its enforcing step was deleted) does NOT count
#   as enforced. The old `grep -rqF` was fail-open — any substring anywhere, comments
#   included, read as enforcement, so a gate stayed "enforced" after its detector was cut.
#
#   OPTIONAL two-legged ALIAS TABLE (AI_DLC_CI_ALIAS_TABLE, unset by default): a gate
#   declared under one name may be enforced under another (a differently-named CI step, a
#   local runner). Each row is `declared_gate|enforcer_id|enforcing_file|anchor`, and a
#   row is honoured ONLY when BOTH legs hold: (i) enforcer_id is present in the enforcing
#   file's NON-COMMENT code (the gate is wired), and (ii) the anchor — the literal whose
#   deletion destroys the enforcement, never the gate's name and never a diagnostic
#   string — occurs EXACTLY ONCE in that file's non-comment code (the detection exists).
#   A row failing either leg confers nothing: the table cannot alias a gate that nothing
#   enforces, which is what separates it from a suppression list with one extra hop. The
#   rows are consumer data; the resolution mechanism is here.
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

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

REPO_ROOT="$AI_DLC_ROOT"
RETRO_DIR="${AI_DLC_RETRO_DIR:-${REPO_ROOT}/docs/retro}"
# The enforcement surface is tunable because it is not universal. A consumer whose
# CI lives somewhere other than .github/workflows/ (a local pre-push runner, a
# vendored pipeline dir) had only one way to keep this validator: fork it. Point
# AI_DLC_CI_SURFACE at the directory that actually holds the gates instead.
WORKFLOW_DIR="${AI_DLC_CI_SURFACE:-${REPO_ROOT}/.github/workflows}"

if ! command -v grep >/dev/null 2>&1; then
  echo "ERROR: grep not available" >&2
  exit 2
fi
if ! command -v find >/dev/null 2>&1; then
  echo "ERROR: find not available" >&2
  exit 2
fi

if [ ! -d "${RETRO_DIR}" ]; then
  # Name the resolved root. A wrong root produces this same line, and without the
  # path there is nothing on screen to tell "no retros" from "looked in the wrong tree".
  echo "Scanned 0 retros, 0 gates declared, 0 dormant (no ${RETRO_DIR})"
  exit 0
fi
if [ ! -d "${WORKFLOW_DIR}" ]; then
  # VACUOUS, not FAIL. The check cannot run — there is no surface to scan. exit 78
  # so this never shares an exit code with a clean scan (0) or a specific dormant
  # gate (1). Today's RC=2 was the old guard firing; that conflated "cannot check"
  # with "tool missing", so a consumer who disabled Actions got a permanent FAIL.
  echo "VACUOUS: no enforcement surface to scan — ${WORKFLOW_DIR} does not exist." >&2
  echo "  If this project's gates live elsewhere, set AI_DLC_CI_SURFACE to that directory." >&2
  exit 78
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

# --- Enforcement matching ---------------------------------------------------
# code_hits <file-or-dir> <literal> — count occurrences of <literal> in NON-COMMENT
# code. A whole-line comment (optional leading whitespace + '#') is stripped first,
# because a gate name that survives only in a comment banner is not enforcement.
# For a directory, every file under it is scanned. Prints an integer.
code_hits() {
  local target="$1" literal="$2" f total=0 n
  if [ -d "$target" ]; then
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      n="$(sed -e 's/^[[:space:]]*#.*$//' "$f" 2>/dev/null | grep -cF -- "$literal" 2>/dev/null || true)"
      total=$((total + ${n:-0}))
    done < <(find "$target" -type f 2>/dev/null)
  elif [ -f "$target" ]; then
    n="$(sed -e 's/^[[:space:]]*#.*$//' "$target" 2>/dev/null | grep -cF -- "$literal" 2>/dev/null || true)"
    total=${n:-0}
  fi
  printf '%s' "$total"
}

# Optional two-legged alias table (AI_DLC_CI_ALIAS_TABLE, unset by default). Rows:
#   declared_gate|enforcer_id|enforcing_file|anchor
# A blank line or one beginning with '#' is skipped; enforcing_file is resolved
# relative to REPO_ROOT when not absolute. See the header for the two legs.
ALIAS_TABLE_FILE="${AI_DLC_CI_ALIAS_TABLE:-}"

# alias_resolves <declared_gate> — 0 iff some row for this gate satisfies BOTH legs.
alias_resolves() {
  local gate="$1" a_gate a_enf a_file a_anchor resolved_file
  [ -n "$ALIAS_TABLE_FILE" ] && [ -f "$ALIAS_TABLE_FILE" ] || return 1
  while IFS='|' read -r a_gate a_enf a_file a_anchor; do
    case "$a_gate" in ''|\#*) continue ;; esac
    [ "$a_gate" = "$gate" ] || continue
    [ -n "$a_enf" ] && [ -n "$a_file" ] && [ -n "$a_anchor" ] || continue
    case "$a_file" in
      /*) resolved_file="$a_file" ;;
      *)  resolved_file="${REPO_ROOT}/${a_file}" ;;
    esac
    [ -f "$resolved_file" ] || continue
    # Leg (i): the enforcer is wired — its id is present in non-comment code.
    [ "$(code_hits "$resolved_file" "$a_enf")" -ge 1 ] || continue
    # Leg (ii): the detection exists — the anchor occurs EXACTLY ONCE in non-comment
    # code. Not the gate name, not a diagnostic string, not a paths trigger.
    [ "$(code_hits "$resolved_file" "$a_anchor")" -eq 1 ] && return 0
  done < "$ALIAS_TABLE_FILE"
  return 1
}

# For each unique declared gate: a comment-aware match in the surface, then the
# both-legged alias table. No match under either -> DORMANT.
dormant_gates=""
while IFS= read -r gate; do
  [ -z "$gate" ] && continue
  if [ "$(code_hits "${WORKFLOW_DIR}" "$gate")" -ge 1 ]; then
    :  # enforced under its own name, in non-comment code
  elif alias_resolves "$gate"; then
    :  # aliased: enforcer wired AND anchor present exactly once (both legs)
  else
    echo "DORMANT: gate '${gate}' declared in retro but no non-comment match in ${WORKFLOW_DIR} or a both-legged alias row" >&2
    dormant_gates="${dormant_gates}${gate}
"
    dormant_count=$((dormant_count + 1))
  fi
done <<EOF
$unique_gates
EOF

# Recount gate_count as unique for reporting.
unique_count=$(printf '%s\n' "$unique_gates" | awk 'NF' | wc -l | tr -d ' ')

echo "Scanned ${retro_count} retros, ${unique_count} gates declared, ${dormant_count} dormant"

if [ "$dormant_count" -gt 0 ]; then
  dormant_enum="$(printf '%s\n' "$dormant_gates" | awk 'NF' | tr '\n' ',' | sed 's/,$//')"
  echo "Dormant gates n=[${dormant_enum}]" >&2
  exit 1
fi
exit 0
