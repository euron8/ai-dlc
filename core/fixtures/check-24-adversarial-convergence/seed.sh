#!/usr/bin/env bash
# Seed the check-24 fixture: five adversarial pass-series, idempotently.
#
#   converged            3 -> 1 -> 0 CRITICAL, terminal EXIT_CONDITION_MET   -> PASS
#   nitpicks-remain      terminal 0C/0M but 5 MINOR, EXIT_CONDITION_MET      -> PASS  (the decoy)
#   refused-to-converge  terminal 0C/0M, EXIT_CONDITION_NOT_MET              -> FAIL (B)
#   divergent            CRITICALs 3 -> 6, no DIVERGENT_HARD_BLOCK           -> FAIL (C)
#   no-verdict           a pass with no `verdict:` key                       -> FAIL (A)
#
# Usage: seed.sh <target-dir>   (default: a temp dir, printed on stdout)
set -eu

TARGET="${1:-$(mktemp -d "${TMPDIR:-/tmp}/check-24-XXXXXX")}"
rm -rf "$TARGET"
mkdir -p "$TARGET"

# $1 file  $2 pass-n  $3 critical  $4 major  $5 minor  $6 verdict-line-or-empty
pass() {
  local file="$1" n="$2" crit="$3" major="$4" minor="$5" verdict="$6"
  {
    printf '# Adversarial review — pass %s\n\n' "$n"
    printf 'Findings are recorded above; this fixture carries only the provenance block.\n\n'
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: bmad-review-adversarial-general\n'
    printf 'mode: subagent\n'
    printf 'lead_role: research-requirements\n'
    printf 'invoked_at: 2026-07-12T0%s:00:00Z\n' "$n"
    printf 'tool_use_id: toolu_fixture_pass%s\n' "$n"
    printf 'findings: %s CRITICAL, %s MAJOR, %s MINOR\n' "$crit" "$major" "$minor"
    printf 'findings_critical: %s\n' "$crit"
    printf 'findings_major: %s\n' "$major"
    printf 'findings_minor: %s\n' "$minor"
    [ -n "$verdict" ] && printf 'verdict: %s\n' "$verdict"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$file"
}

# --- converged: the cycle the machinery is supposed to produce ---------------
mkdir -p "$TARGET/converged"
pass "$TARGET/converged/s1-adversarial-pass1.md" 1 3 4 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/converged/s1-adversarial-pass2.md" 2 1 2 3 EXIT_CONDITION_NOT_MET
pass "$TARGET/converged/s1-adversarial-pass3.md" 3 0 0 1 EXIT_CONDITION_MET

# --- nitpicks-remain: THE DECOY ----------------------------------------------
# Clean of CRITICAL and MAJOR, but five MINORs still open. The step's exit
# condition is "continue until only nitpicks remain", and the ladder puts
# MINOR/NIT in the nitpick bucket -- so this IS met. A validator that blocks on
# any open finding recreates the v0.46.0 bug one layer down.
mkdir -p "$TARGET/nitpicks-remain"
pass "$TARGET/nitpicks-remain/s1-adversarial-pass1.md" 1 2 3 1 EXIT_CONDITION_NOT_MET
pass "$TARGET/nitpicks-remain/s1-adversarial-pass2.md" 2 0 0 5 EXIT_CONDITION_MET

# --- refused-to-converge: the S289 pass-4 shape ------------------------------
mkdir -p "$TARGET/refused-to-converge"
pass "$TARGET/refused-to-converge/s1-adversarial-pass1.md" 1 3 3 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/refused-to-converge/s1-adversarial-pass2.md" 2 0 0 2 EXIT_CONDITION_NOT_MET

# --- divergent: the repair step is injecting defects --------------------------
mkdir -p "$TARGET/divergent"
pass "$TARGET/divergent/s1-adversarial-pass1.md" 1 3 3 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/divergent/s1-adversarial-pass2.md" 2 6 8 4 EXIT_CONDITION_NOT_MET

# --- no-verdict: un-adjudicable ----------------------------------------------
mkdir -p "$TARGET/no-verdict"
pass "$TARGET/no-verdict/s1-adversarial-pass1.md" 1 3 3 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/no-verdict/s1-adversarial-pass2.md" 2 0 0 1 ""

printf '%s\n' "$TARGET"
