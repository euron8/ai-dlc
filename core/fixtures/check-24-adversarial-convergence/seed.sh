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
#                     $7 findings_critical_prior_scope (OPTIONAL -- omit to seed a
#                        pre-v0.52.0 artifact, which is what the five legacy cases
#                        above do. Their unchanged verdicts are the backward-compat
#                        proof: absent field => prior := crit => the old predicate.)
pass() {
  local file="$1" n="$2" crit="$3" major="$4" minor="$5" verdict="$6" prior="${7:-}"
  {
    printf '# Adversarial review — pass %s\n\n' "$n"
    printf 'Findings are recorded above; this fixture carries only the provenance block.\n\n'
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\n'
    printf 'mode: subagent\n'
    printf 'lead_role: research-requirements\n'
    printf 'invoked_at: 2026-07-12T0%s:00:00Z\n' "$n"
    printf 'tool_use_id: toolu_fixture_pass%s\n' "$n"
    printf 'findings: %s CRITICAL, %s MAJOR, %s MINOR\n' "$crit" "$major" "$minor"
    printf 'findings_critical: %s\n' "$crit"
    [ -n "$prior" ] && printf 'findings_critical_prior_scope: %s\n' "$prior"
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

# =============================================================================
# v0.52.0 -- the scope-relative divergence predicate.
# =============================================================================

# --- scope-grew-converges: THE RELEASE, IN ONE CASE ---------------------------
# Pass 2's CRITICALs RISE (2 -> 3), but only ONE of the three is in text pass 1 had
# already reviewed; the other two are in scope the sprint ADDED. That is not
# divergence -- the repairs held -- so NOT_MET is the correct stamp and the cycle is
# allowed to continue to a clean pass.
#
# This is S290's p6 -> p7 shape. Under the pre-v0.52.0 predicate it FAILS (C), which
# is the false hard block that cost the operator an adjudication. It must PASS now.
mkdir -p "$TARGET/scope-grew-converges"
pass "$TARGET/scope-grew-converges/s1-adversarial-pass1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/scope-grew-converges/s1-adversarial-pass2.md" 2 3 1 2 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/scope-grew-converges/s1-adversarial-pass3.md" 3 0 0 2 EXIT_CONDITION_MET     0

# --- repair-injected: real divergence, WITH the field present -----------------
# All 3 of pass 2's CRITICALs are in prior scope (3 > pass 1's 2). The repair really
# is injecting defects into text that was already clean. This is S289's 3 -> 4 -> 7
# shape, and it must STILL fail (C). The fix must not blunt the check it refines --
# a scope field that exonerated everything would be a cheat code.
mkdir -p "$TARGET/repair-injected"
pass "$TARGET/repair-injected/s1-adversarial-pass1.md" 1 2 2 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/repair-injected/s1-adversarial-pass2.md" 2 3 2 1 EXIT_CONDITION_NOT_MET 3

# --- scope-grew-unconverged: S290's ACTUAL SHAPE ------------------------------
# Every pass subtracts in prior scope (3 -> 1 -> 0) and the sprint keeps growing
# underneath it, so the series never terminates. NO false hard block fires anywhere
# -- and Check D must name the real remedy (freeze the artifact, cut the added
# scope), not "run another pass", which is the advice that produced eight of them.
mkdir -p "$TARGET/scope-grew-unconverged"
pass "$TARGET/scope-grew-unconverged/s1-adversarial-pass1.md" 1 3 2 1 EXIT_CONDITION_NOT_MET 3
pass "$TARGET/scope-grew-unconverged/s1-adversarial-pass2.md" 2 2 1 2 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/scope-grew-unconverged/s1-adversarial-pass3.md" 3 3 2 3 EXIT_CONDITION_NOT_MET 0

# =============================================================================
# v0.55.3 -- numeric pass ordering, and the STALL rung.
# =============================================================================

# --- long-series-p-naming: THE ORDERING REGRESSION ----------------------------
# ELEVEN passes, named `-p<N>` (the reference consumer's convention, which the old
# order_key -- matching only `pass<N>` -- did not recognize AT ALL). Every file fell to
# key 999 and the stable sort left them in glob order: 1 10 11 2 3 4 5 6 7 8 9.
#
# This case is built so that ordering is the ONLY thing that can decide it:
#   true last pass       p11 -> 0C/0M, EXIT_CONDITION_MET   => the cycle converged, PASS
#   lexicographic last   p9  -> 2C/1M, EXIT_CONDITION_NOT_MET => Check D fails
# So it PASSES only if the series is ordered numerically. Under the old code it FAILS,
# and that is the bug: at >=10 passes Check D adjudicated the wrong artifact -- the exact
# "gate passed while the last pass said NOT met" failure Check D was written to prevent,
# just pointed the other way.
mkdir -p "$TARGET/long-series-p-naming"
pass "$TARGET/long-series-p-naming/s1-adversarial-p1.md"   1 5 4 2 EXIT_CONDITION_NOT_MET 5
pass "$TARGET/long-series-p-naming/s1-adversarial-p2.md"   2 4 3 2 EXIT_CONDITION_NOT_MET 4
pass "$TARGET/long-series-p-naming/s1-adversarial-p3.md"   3 4 3 1 EXIT_CONDITION_NOT_MET 4
pass "$TARGET/long-series-p-naming/s1-adversarial-p4.md"   4 3 2 1 EXIT_CONDITION_NOT_MET 3
pass "$TARGET/long-series-p-naming/s1-adversarial-p5.md"   5 3 2 2 EXIT_CONDITION_NOT_MET 3
pass "$TARGET/long-series-p-naming/s1-adversarial-p6.md"   6 3 2 1 EXIT_CONDITION_NOT_MET 3
pass "$TARGET/long-series-p-naming/s1-adversarial-p7.md"   7 2 2 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/long-series-p-naming/s1-adversarial-p8.md"   8 2 1 2 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/long-series-p-naming/s1-adversarial-p9.md"   9 2 1 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/long-series-p-naming/s1-adversarial-p10.md" 10 1 1 1 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/long-series-p-naming/s1-adversarial-p11.md" 11 0 0 3 EXIT_CONDITION_MET     0

# --- stalled: S290's brief cycle, passes 11-13 --------------------------------
# ZERO CRITICAL, MAJOR pinned at 1, three passes running. Not converged (MAJOR>0), not
# divergent (CRITICAL=0) -- so before v0.55.3 it fell through every rung into "run another
# pass", forever. Thirteen passes and ~12 hours on the live consumer, and nothing fired.
# The plateau is repair-induced: each repair rewrites the prose around an unverified
# universal, and the next pass falsifies the rewrite. Must FAIL (E).
mkdir -p "$TARGET/stalled"
pass "$TARGET/stalled/s1-adversarial-p1.md" 1 2 2 3 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/stalled/s1-adversarial-p2.md" 2 0 1 3 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled/s1-adversarial-p3.md" 3 0 1 4 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled/s1-adversarial-p4.md" 4 0 1 2 EXIT_CONDITION_NOT_MET 0

# --- stall-then-converges: THE DECOY FOR E ------------------------------------
# Holds MAJOR at 1 for two passes -- one short of the threshold -- and then actually
# fixes it. E must NOT fire: a cycle that is slow is not a cycle that is stuck, and a rung
# that hard-blocks a cycle about to converge is worse than the disease. This is the case
# that decides the threshold; if it goes red, K is too tight.
# p2 drops MAJOR 2->1 (run resets), p3 HOLDS it at 1 (run = 1 -- exactly one short of the
# K=2 threshold), p4 clears it. The stall run reaches the rung and stops there.
mkdir -p "$TARGET/stall-then-converges"
pass "$TARGET/stall-then-converges/s1-adversarial-p1.md" 1 2 2 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/stall-then-converges/s1-adversarial-p2.md" 2 0 1 2 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stall-then-converges/s1-adversarial-p3.md" 3 0 1 2 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stall-then-converges/s1-adversarial-p4.md" 4 0 0 2 EXIT_CONDITION_MET     0

printf '%s\n' "$TARGET"
