#!/usr/bin/env bash
# Seed the check-24 fixture: adversarial pass-series, idempotently.
#
#   converged            3 -> 1 -> 0 CRITICAL, terminal EXIT_CONDITION_MET   -> PASS
#   nitpicks-remain      terminal 0C/0M but 5 MINOR, EXIT_CONDITION_MET      -> PASS  (the decoy)
#   refused-to-converge  terminal 0C/0M, EXIT_CONDITION_NOT_MET              -> FAIL (B)
#   divergent            CRITICALs 3 -> 6, no DIVERGENT_HARD_BLOCK           -> FAIL (C)
#   no-verdict           a pass with no `verdict:` key                       -> FAIL (A)
#   ... plus the v0.52.0, v0.55.3 and v0.59.0 cases; see each block.
#
# Usage: seed.sh <target-dir>   (default: a temp dir, printed on stdout)
set -eu

TARGET="${1:-$(mktemp -d "${TMPDIR:-/tmp}/check-24-XXXXXX")}"
rm -rf "$TARGET"
mkdir -p "$TARGET"

# $1 file  $2 pass-n  $3 critical  $4 major  $5 minor  $6 verdict-line-or-empty
# $7  findings_critical_prior_scope (OPTIONAL -- omit to seed a pre-v0.52.0 artifact,
#     which is what the five legacy cases do. Their unchanged verdicts are the
#     backward-compat proof: absent field => prior := crit => the old predicate.)
# $8  artifact_sha       (v0.59.0; omit to seed a pre-v0.59.0 artifact)
# $9  resolves_divergence (v0.59.0)
# $10 invoked_at         (defaults to a MONOTONE stamp derived from the pass number)
#
# NOTE the default `invoked_at`. The old seed printed `2026-07-12T0%s:00:00Z`, which at
# pass 10 emits `T010:00:00Z` -- malformed, and lexicographically BEFORE `T09`. Arm G
# (chronology) caught it on its first run. The fixture was carrying a bad timestamp for
# four releases and nothing read it, so nothing complained.
pass() {
  local file="$1" n="$2" crit="$3" major="$4" minor="$5" verdict="$6"
  local prior="${7:-}" sha="${8:-}" resolves="${9:-}" at="${10:-}" underived="${11:-}"
  [ -n "$at" ] || at="$(printf '2026-07-12T%02d:00:00Z' "$n")"
  {
    printf '# Adversarial review — pass %s\n\n' "$n"
    printf 'Findings are recorded above; this fixture carries only the provenance block.\n\n'
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\n'
    printf 'mode: subagent\n'
    printf 'lead_role: research-requirements\n'
    printf 'invoked_at: %s\n' "$at"
    printf 'tool_use_id: toolu_fixture_pass%s\n' "$n"
    [ -n "$sha" ] && printf 'artifact: product-brief.md\n' && printf 'artifact_sha: %s\n' "$sha"
    [ -n "$resolves" ] && printf 'resolves_divergence: %s\n' "$resolves"
    printf 'findings: %s CRITICAL, %s MAJOR, %s MINOR\n' "$crit" "$major" "$minor"
    printf 'findings_critical: %s\n' "$crit"
    [ -n "$prior" ] && printf 'findings_critical_prior_scope: %s\n' "$prior"
    printf 'findings_major: %s\n' "$major"
    [ -n "$underived" ] && printf 'findings_major_underived: %s\n' "$underived"
    printf 'findings_minor: %s\n' "$minor"
    [ -n "$verdict" ] && printf 'verdict: %s\n' "$verdict"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$file"
}

# The RESOLUTION record -- the resume contract, as a file. v0.59.0.
# $1 file  $2 resolves-pass-basename  $3 kind  $4 sha_before  $5 sha_after
# $6 bytes_before  $7 bytes_after  $8 scope_delta  $9 operator_authorization  $10 archive
# $11 adjudication shape (arm F7): "" = well-formed | "no-options" | "one-option" |
#     "no-recommendation". The DEFAULT is well-formed, so every pre-F7 call site keeps
#     passing and the arm's false-positive set inside this fixture stays empty by
#     construction rather than by hand-editing thirteen call sites.
record() {
  local file="$1" resolves="$2" kind="$3" sb="$4" sa="$5" bb="$6" ba="$7"
  local delta="${8:-}" auth="${9:-}" arch="${10:-}" adj="${11:-}"
  {
    printf '# Divergence resolution — %s\n\n' "$kind"
    printf '<!-- ADVERSARIAL_RESOLUTION v1\n'
    printf 'resolves: %s\n' "$resolves"
    printf 'resolution: %s\n' "$kind"
    printf 'adjudicated_by: operator\n'
    printf 'artifact: product-brief.md\n'
    printf 'artifact_sha_before: %s\n' "$sb"
    printf 'artifact_sha_after: %s\n' "$sa"
    printf 'artifact_bytes_before: %s\n' "$bb"
    printf 'artifact_bytes_after: %s\n' "$ba"
    [ -n "$delta" ] && printf 'scope_delta: %s\n' "$delta"
    [ -n "$auth" ] && printf 'operator_authorization: %s\n' "$auth"
    [ -n "$arch" ] && printf 'archive: %s\n' "$arch"
    case "$adj" in
      no-options)        : ;;                                  # neither field
      one-option)        printf 'options_presented: 1\n'
                         printf 'recommended_option: revert\n' ;;
      no-recommendation) printf 'options_presented: 3\n' ;;
      *)                 printf 'options_presented: 3\n'
                         printf 'recommended_option: %s\n' "$kind" ;;
    esac
    printf 'ADVERSARIAL_RESOLUTION_END -->\n'
  } > "$file"
}

# A REPAIR RECORD -- the remediator's deliverable, one per repaired pass (§3a). Arm H
# (v0.103.0) asserts it EXISTS and carries the three structured fields; a converging
# cycle had repairs, so a delegated one leaves these on disk.
# $1 file  $2 (optional) mode:
#   ""             -> the taught form, plain: `- disposition:` (remediator.md's template)
#   "unstructured" -> prose only, to trip arm H's structure arm
#   "bold"         -> the HOUSE STYLE: `- **disposition:**`. v0.355.0. Measured on the
#                     reference consumer, 413 of 977 field lines are written this way and
#                     every one of them read UNSTRUCTURED to arm H, because the bracket
#                     class `[[:space:]-]` does not contain `*`. The seed wrote the plain
#                     form ONLY, which is exactly why the fixture stayed green over it for
#                     nine releases -- a check seeded with what its reader accepts asserts
#                     nothing about what its reader rejects.
#   "off-label"    -> emphasis is fine but the LABEL is not the taught one: `edit sites:`,
#                     `derivation (qualifier):`. Arm H must STILL FAIL here. This is the
#                     boundary case: without it, a later widening that admits any line
#                     containing the word turns arm H off and every arm above still passes.
repair() {
  local file="$1" mode="${2:-}"
  if [ "$mode" = "unstructured" ]; then
    printf 'The findings were addressed. See the artifact.\n' > "$file"
    return
  fi
  if [ "$mode" = "off-label" ]; then
    {
      printf '# Repair record\n\n'
      printf '### F1 — CRITICAL\n'
      printf -- '- **disposition:** repaired\n'
      printf -- '- **edit sites:** product-brief.md:42\n'
      printf -- '- derivation (the restored qualifier — the only factual element):\n'
      printf '    $ grep -c "load-bearing site" product-brief.md\n'
      printf '    3\n'
      printf '### Derivation 1 — the count above is the whole population\n'
    } > "$file"
    return
  fi
  local o="" c=""
  [ "$mode" = "bold" ] && o='**' && c=':**'
  [ "$mode" = "bold" ] || c=':'
  {
    printf '# Repair record\n\n'
    printf '### F1 — CRITICAL\n'
    printf -- '- %sdisposition%s repaired\n' "$o" "$c"
    printf -- '- %sedit%s product-brief.md:42\n' "$o" "$c"
    printf -- '- %sderivation%s\n' "$o" "$c"
    printf '    $ grep -c "load-bearing site" product-brief.md\n'
    printf '    3\n'
    printf -- '- claim now asserted: all three sites are enumerated\n'
  } > "$file"
}

# --- converged: the cycle the machinery is supposed to produce ---------------
mkdir -p "$TARGET/converged"
pass "$TARGET/converged/s1-adversarial-pass1.md" 1 3 4 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/converged/s1-adversarial-pass2.md" 2 1 2 3 EXIT_CONDITION_NOT_MET
pass "$TARGET/converged/s1-adversarial-pass3.md" 3 0 0 1 EXIT_CONDITION_MET
# each falling pass had a delegated repair; arm H requires the record (v0.103.0).
repair "$TARGET/converged/s1-brief-repair-p1.md"
repair "$TARGET/converged/s1-brief-repair-p2.md"

# --- nitpicks-remain: THE DECOY ----------------------------------------------
# Clean of CRITICAL and MAJOR, but five MINORs still open. The step's exit
# condition is "continue until only nitpicks remain", and the ladder puts
# MINOR/NIT in the nitpick bucket -- so this IS met. A validator that blocks on
# any open finding recreates the v0.46.0 bug one layer down.
mkdir -p "$TARGET/nitpicks-remain"
pass "$TARGET/nitpicks-remain/s1-adversarial-pass1.md" 1 2 3 1 EXIT_CONDITION_NOT_MET
pass "$TARGET/nitpicks-remain/s1-adversarial-pass2.md" 2 0 0 5 EXIT_CONDITION_MET
repair "$TARGET/nitpicks-remain/s1-brief-repair-p1.md"

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
# divergence -- the repairs held -- so NOT_MET is the correct stamp.
mkdir -p "$TARGET/scope-grew-converges"
pass "$TARGET/scope-grew-converges/s1-adversarial-pass1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/scope-grew-converges/s1-adversarial-pass2.md" 2 3 1 2 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/scope-grew-converges/s1-adversarial-pass3.md" 3 0 0 2 EXIT_CONDITION_MET     0
# p1->p2 CRITICALs rise (no fall, arm H skips); p2->p3 falls 3C->0C -- its repair is recorded.
repair "$TARGET/scope-grew-converges/s1-brief-repair-p2.md"

# --- repair-injected: real divergence, WITH the field present -----------------
# All 3 of pass 2's CRITICALs are in prior scope (3 > pass 1's 2). This is S289's
# 3 -> 4 -> 7 shape and it must STILL fail (C). The fix must not blunt the check it
# refines -- a scope field that exonerated everything would be a cheat code.
mkdir -p "$TARGET/repair-injected"
pass "$TARGET/repair-injected/s1-adversarial-pass1.md" 1 2 2 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/repair-injected/s1-adversarial-pass2.md" 2 3 2 1 EXIT_CONDITION_NOT_MET 3

# --- scope-grew-unconverged: S290's MOVING-ARTIFACT SHAPE ---------------------
# Every pass subtracts in prior scope (3 -> 1 -> 0) and the sprint keeps growing
# underneath it, so the series never terminates. Check D must name the real remedy
# (freeze the artifact, cut the added scope), not "run another pass".
mkdir -p "$TARGET/scope-grew-unconverged"
pass "$TARGET/scope-grew-unconverged/s1-adversarial-pass1.md" 1 3 2 1 EXIT_CONDITION_NOT_MET 3
pass "$TARGET/scope-grew-unconverged/s1-adversarial-pass2.md" 2 2 1 2 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/scope-grew-unconverged/s1-adversarial-pass3.md" 3 3 2 3 EXIT_CONDITION_NOT_MET 0

# =============================================================================
# v0.55.3 -- numeric pass ordering, and the STALL rung.
# =============================================================================

# --- long-series-p-naming: THE ORDERING REGRESSION ----------------------------
# ELEVEN passes named `-p<N>`. Built so ORDERING alone decides it:
#   true last pass       p11 -> 0C/0M, EXIT_CONDITION_MET     => converged, PASS
#   lexicographic last   p9  -> 2C/1M, EXIT_CONDITION_NOT_MET => Check D fails
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
# repair record for every pass whose findings FELL into its successor (arm H).
for m in 1 3 6 7 9 10; do repair "$TARGET/long-series-p-naming/s1-brief-repair-p$m.md"; done

# --- stalled: S290's brief cycle, passes 11-13 --------------------------------
# ZERO CRITICAL, MAJOR pinned at 1, three passes running. Not converged (MAJOR>0), not
# divergent (CRITICAL=0) -- so before v0.55.3 it fell through every rung into "run another
# pass", forever. Must FAIL (E).
mkdir -p "$TARGET/stalled"
pass "$TARGET/stalled/s1-adversarial-p1.md" 1 2 2 3 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/stalled/s1-adversarial-p2.md" 2 0 1 3 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled/s1-adversarial-p3.md" 3 0 1 4 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled/s1-adversarial-p4.md" 4 0 1 2 EXIT_CONDITION_NOT_MET 0

# --- stall-then-converges: THE DECOY FOR E ------------------------------------
# Holds MAJOR at 1 for two passes -- one short of the threshold -- and then actually
# fixes it. E must NOT fire: a cycle that is slow is not a cycle that is stuck. This is
# the case that decides the threshold; if it goes red, K is too tight.
mkdir -p "$TARGET/stall-then-converges"
pass "$TARGET/stall-then-converges/s1-adversarial-p1.md" 1 2 2 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/stall-then-converges/s1-adversarial-p2.md" 2 0 1 2 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stall-then-converges/s1-adversarial-p3.md" 3 0 1 2 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stall-then-converges/s1-adversarial-p4.md" 4 0 0 2 EXIT_CONDITION_MET     0
# p1->p2 falls (2C->0C) and p3->p4 falls (1M->0M); both repairs recorded (arm H).
repair "$TARGET/stall-then-converges/s1-brief-repair-p1.md"
repair "$TARGET/stall-then-converges/s1-brief-repair-p3.md"

# =============================================================================
# v0.59.0 -- the RESUME CONTRACT: STOP -> ADJUDICATE -> RESOLVE -> VERIFY.
# =============================================================================

# --- stalled-then-diverges: PROVES THE HOIST ----------------------------------
# THE CASE THAT WOULD HAVE CAUGHT D2, AND THE REASON THE HOIST ALONE IS NOT ENOUGH.
#
# The live series held 0C/1M across p11..p14 (stall run = 3, against K=2) and then a
# CRITICAL appeared at p15 and it diverged. Arm E used to live INSIDE the `*)` branch of
# the terminal-verdict case, so a series ending DIVERGENT took arm D's branch and E was
# never evaluated at all. And a naively-hoisted E keyed on STALL_RUN is STILL false here:
# the run RESETS at p5 when the CRITICAL lands. Only the PEAK survives the reset.
#
# So this case fails against three different implementations for three different reasons,
# and only the right one passes it: E must fire, AND name p4 as the pass the cycle should
# have stopped at -- four passes before the divergence.
#
# ASSERT ON THE MESSAGE, NOT THE EXIT CODE. This series exits 1 today (arm D alone) and
# exits 1 after the fix (arm D AND arm E). A fixture that checked only the exit code would
# score a FALSE PASS against the broken validator -- this repo's own defect class, one
# level up, inside the very test written to catch it.
mkdir -p "$TARGET/stalled-then-diverges"
pass "$TARGET/stalled-then-diverges/s1-adversarial-p1.md" 1 2 2 3 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/stalled-then-diverges/s1-adversarial-p2.md" 2 0 1 3 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled-then-diverges/s1-adversarial-p3.md" 3 0 1 4 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled-then-diverges/s1-adversarial-p4.md" 4 0 1 2 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled-then-diverges/s1-adversarial-p5.md" 5 1 0 1 DIVERGENT_HARD_BLOCK   1

# --- divergent-resolved: THE RELEASE ------------------------------------------
# The sanctioned exit, end to end. p2 hard-blocks. The operator adjudicates. The lead
# writes a REVERT_REPAIR record whose artifact_sha_after matches the sha p1 NOTARIZED --
# i.e. the artifact is back at a state that was actually reviewed. p3 is the VERIFICATION
# pass: it declares the record and stamps EXIT_CONDITION_MET.
#
# This is the case that did not exist before v0.59.0. There WAS no legal move here: arm D
# demanded a terminal clean pass and the Stop hook's deny reason said "do NOT dispatch
# another adversarial pass, and do NOT clear the pause flag to get past this." If this case
# ever goes red, the exit is gone and the deadlock is back.
mkdir -p "$TARGET/divergent-resolved"
pass "$TARGET/divergent-resolved/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 aaa1
pass "$TARGET/divergent-resolved/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 bbb2
# artifact_sha_before=bbb2 is the F4 ANCHOR: it must equal what p2 -- the pass being
# resolved -- notarized as the bytes it actually read. A record that starts from a state
# the divergent pass never saw is resolving something else.
# artifact_sha_after=aaa1 is the F5 ANCHOR for REVERT_REPAIR: p1 notarized aaa1, so the
# artifact really is back at a state that was actually reviewed.
record "$TARGET/divergent-resolved/s1-resolution-p2.md" \
  s1-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000 "reverted the p1->p2 repair wholesale" \
  '2026-07-12T03:00:00Z | "revert the p1 to p2 repair wholesale"'
pass "$TARGET/divergent-resolved/s1-adversarial-p3.md" 3 0 0 2 EXIT_CONDITION_MET 0 aaa1 s1-resolution-p2.md

# --- F7: THE ADJUDICATION'S SHAPE ----------------------------------------------
# THE DIFFERENTIAL, and it has to be one. These three cases are byte-identical to
# `divergent-resolved` above except for the two fields recording what the operator was
# actually handed. Every other arm passes on all three -- F4's anchor, F5's revert, F6's
# citation are the same values -- so if the exit code alone were the assertion, a validator
# with F7 deleted would score a FALSE PASS on all of them. run.sh asserts the MESSAGE.
#
# The operator adjudicating `divergent-resolved` chose in 91 seconds. The operator handed
# the `no-options` shape spent four round-trips arriving at the same kind.
for _shape in no-options one-option no-recommendation; do
  mkdir -p "$TARGET/adjudication-$_shape"
  pass "$TARGET/adjudication-$_shape/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 aaa1
  pass "$TARGET/adjudication-$_shape/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 bbb2
  record "$TARGET/adjudication-$_shape/s1-resolution-p2.md" \
    s1-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000 "reverted the p1->p2 repair wholesale" \
    '2026-07-12T03:00:00Z | "revert the p1 to p2 repair wholesale"' "" "$_shape"
  pass "$TARGET/adjudication-$_shape/s1-adversarial-p3.md" 3 0 0 2 EXIT_CONDITION_MET 0 aaa1 s1-resolution-p2.md
done
unset _shape

# --- divergent-unresolved: F1 --------------------------------------------------
# p2 hard-blocks and p3 runs anyway, declaring nothing. This is the oscillation the live
# consumer ran four times: every repair closes what it was given and opens one new defect
# in scope it already signed off. The next pass is permitted ONLY as a verification pass
# on a RESOLVED artifact.
mkdir -p "$TARGET/divergent-unresolved"
pass "$TARGET/divergent-unresolved/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 aaa1
pass "$TARGET/divergent-unresolved/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 bbb2
pass "$TARGET/divergent-unresolved/s1-adversarial-p3.md" 3 0 0 2 EXIT_CONDITION_MET     0 ccc3

# --- divergent-frozen: F3, AND THE LIVE DEADLOCK -------------------------------
# THE CASE THAT NAMES WHY THE REFERENCE CONSUMER PARKED. The lead's starred recommendation
# was "freeze the brief and ship it"; the operator authorized it, in those words. It could
# not pass the gate -- and no wording of it ever could, because DIVERGENT_HARD_BLOCK means
# CRITICALs rose in text that is ALREADY FROZEN. Freezing it again removes nothing.
#
# Before v0.59.0 no arm said this. The enum containing FREEZE_SCOPE is the bug; the enum
# omitting it is the fix. An enum member that cannot fire reads exactly like one that passes.
mkdir -p "$TARGET/divergent-frozen"
pass "$TARGET/divergent-frozen/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 aaa1
pass "$TARGET/divergent-frozen/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 bbb2
record "$TARGET/divergent-frozen/s1-resolution-p2.md" \
  s1-adversarial-p2.md FREEZE_SCOPE bbb2 bbb2 4200 4200 "froze the brief on operator authority"
pass "$TARGET/divergent-frozen/s1-adversarial-p3.md" 3 0 0 2 EXIT_CONDITION_MET 0 bbb2 s1-resolution-p2.md

# --- divergent-laundered-cut: F5, closed by ARITHMETIC --------------------------
# The record says CUT_SCOPE. The artifact GREW. A repair that rewrites prose cannot claim
# to be a cut, because a cut removes bytes and this one added 200 of them.
# (Measured shape: the live cycle's pass-17 "repair" added 101 lines and deleted 12, on a
# sprint whose theme was SUBTRACTION and whose divergence remedy is "shrink the artifact".)
mkdir -p "$TARGET/divergent-laundered-cut"
pass "$TARGET/divergent-laundered-cut/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 aaa1
pass "$TARGET/divergent-laundered-cut/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 bbb2
record "$TARGET/divergent-laundered-cut/s1-resolution-p2.md" \
  s1-adversarial-p2.md CUT_SCOPE bbb2 ccc3 4000 4200 "cut story 3"
pass "$TARGET/divergent-laundered-cut/s1-adversarial-p3.md" 3 0 0 2 EXIT_CONDITION_MET 0 ccc3 s1-resolution-p2.md

# --- divergent-laundered-revert: F5, closed by CONSTRUCTION ----------------------
# The record says REVERT_REPAIR, but artifact_sha_after matches NO earlier pass in the
# series. A genuine revert lands on a state some pass actually notarized. This one lands
# somewhere new -- which makes it an edit, and an edit is a repair, and a repair is what
# diverged.
mkdir -p "$TARGET/divergent-laundered-revert"
pass "$TARGET/divergent-laundered-revert/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 aaa1
pass "$TARGET/divergent-laundered-revert/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 bbb2
record "$TARGET/divergent-laundered-revert/s1-resolution-p2.md" \
  s1-adversarial-p2.md REVERT_REPAIR bbb2 zzz9 4200 4100 "reverted (allegedly)"
pass "$TARGET/divergent-laundered-revert/s1-adversarial-p3.md" 3 0 0 2 EXIT_CONDITION_MET 0 zzz9 s1-resolution-p2.md

# --- restart-cycle: D4, THE DEAD CYCLE'S TAIL -----------------------------------
# Rule 8's own remedy for a moving artifact is "freeze scope, shrink the sprint, RESTART" --
# and nothing implemented restart. A lead that restarts writes p1, p2, p3 over the dead
# cycle's files. The dead cycle ran to p6. Passes p4, p5, p6 ARE STILL ON DISK.
#
# The glob chains them onto the new passes; arm D reads dead-p6 as the terminal artifact;
# and the gate fails with "the series ends at p6 with DIVERGENT_HARD_BLOCK" -- over a cycle
# that converged cleanly at new-p3. Every artifact named in the failure is real, so the
# lead cannot diagnose it.
#
# Arm G catches it WITHOUT needing any record: the new p3 was written on the 13th, the dead
# p4 on the 12th. A pass cannot follow a pass that was written after it.
mkdir -p "$TARGET/restart-cycle"
pass "$TARGET/restart-cycle/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 n11 "" 2026-07-13T09:00:00Z
pass "$TARGET/restart-cycle/s1-adversarial-p2.md" 2 1 1 1 EXIT_CONDITION_NOT_MET 1 n22 "" 2026-07-13T10:00:00Z
pass "$TARGET/restart-cycle/s1-adversarial-p3.md" 3 0 0 2 EXIT_CONDITION_MET     0 n33 "" 2026-07-13T11:00:00Z
# the corpse:
pass "$TARGET/restart-cycle/s1-adversarial-p4.md" 4 1 2 1 EXIT_CONDITION_NOT_MET 1 d44 "" 2026-07-12T09:00:00Z
pass "$TARGET/restart-cycle/s1-adversarial-p5.md" 5 0 3 1 EXIT_CONDITION_NOT_MET 0 d55 "" 2026-07-12T10:00:00Z
pass "$TARGET/restart-cycle/s1-adversarial-p6.md" 6 2 4 1 DIVERGENT_HARD_BLOCK   2 d66 "" 2026-07-12T11:00:00Z

# --- counts-omitted: arm A, and arm E's free bypass -----------------------------
# A pass that declares a verdict but no derivable MAJOR count. severity_count returns
# empty, the empty count RESETS the stall run, and arm E goes DARK for the whole series --
# silently, with the gate still green. Arm A used to require only `verdict:`.
# A check you can switch off by omitting a field is not a check.
mkdir -p "$TARGET/counts-omitted"
pass "$TARGET/counts-omitted/s1-adversarial-p1.md" 1 2 2 3 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/counts-omitted/s1-adversarial-p2.md" 2 0 1 3 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/counts-omitted/s1-adversarial-p3.md" 3 0 1 4 EXIT_CONDITION_NOT_MET 0
# strip BOTH the structured field and the free-text fallback severity_count reads
sed -i.bak -e '/^findings_major:/d' -e 's/^findings: .*/findings: see prose/' \
  "$TARGET/counts-omitted/s1-adversarial-p3.md"
rm -f "$TARGET/counts-omitted/s1-adversarial-p3.md.bak"

# --- in-progress: the --cycle-state DECOY ---------------------------------------
# A HEALTHY running cycle. CRITICALs falling, MAJORs falling, terminal NOT_MET -- because
# it is not finished yet. That is what "in progress" looks like.
#
# THIS IS THE CASE THAT MAKES THE SHELL-OUT SAFE. --cycle-state must NOT run arm D. A hook
# that called the validator in gate mode would get exit 1 here -- on every healthy cycle,
# on every turn -- and pause the pipeline continuously. A guard that fires on COMPLIANCE is
# worse than no guard: it gets switched off, and then nothing is watching.
mkdir -p "$TARGET/in-progress"
pass "$TARGET/in-progress/s1-adversarial-p1.md" 1 3 2 1 EXIT_CONDITION_NOT_MET 3
pass "$TARGET/in-progress/s1-adversarial-p2.md" 2 1 1 2 EXIT_CONDITION_NOT_MET 1

# --- divergent-terminal / -resolved: the RESUME, at runtime ----------------------
# The exact moment the reference consumer is parked at: the terminal pass hard-blocks and
# the operator has not yet adjudicated. --cycle-state -> DIVERGENT, exit 3, and the
# PreToolUse hook denies the next dispatch.
#
# Then the operator adjudicates and the lead writes the record -- the ONE write the pause
# is waiting for, and the one the acknowledge hook carves out. --cycle-state -> RESOLVED,
# exit 0, and the verification pass is permitted. Same series, same bytes, one new file.
mkdir -p "$TARGET/divergent-terminal"
pass "$TARGET/divergent-terminal/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 aaa1
pass "$TARGET/divergent-terminal/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 bbb2

mkdir -p "$TARGET/divergent-terminal-resolved"
pass "$TARGET/divergent-terminal-resolved/s1-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2 aaa1
pass "$TARGET/divergent-terminal-resolved/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 bbb2
record "$TARGET/divergent-terminal-resolved/s1-resolution-p2.md" \
  s1-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000 "reverted the p1->p2 repair wholesale" \
  '2026-07-12T03:00:00Z | "revert the p1 to p2 repair wholesale"'

# =============================================================================
# v0.103.0 -- arm H, the repair-record. THREE cases, and the first two are a
# DIFFERENTIAL: identical pass series, differing ONLY in whether the repair records
# exist. A validator that does not stat the record cannot separate them.
# =============================================================================

# --- repaired-inline-no-record: THE S295 DEFECT -- MUST FAIL (H) --------------
# A clean converging series (2C/1M -> 0C/1M -> 0C/0M MET). Findings FELL at p1->p2 and
# p2->p3, so a repair happened before each -- but NO repair record exists. That is the
# lead having repaired the artifact inline: every other arm passes, and only reading the
# record for a file that is not there tells the difference.
mkdir -p "$TARGET/repaired-inline-no-record"
pass "$TARGET/repaired-inline-no-record/s1-adversarial-pass1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET
pass "$TARGET/repaired-inline-no-record/s1-adversarial-pass2.md" 2 0 1 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/repaired-inline-no-record/s1-adversarial-pass3.md" 3 0 0 2 EXIT_CONDITION_MET

# --- repaired-delegated: THE PASS TWIN -- MUST PASS ---------------------------
# Byte-identical pass series to repaired-inline-no-record. The ONLY difference is that
# the two repairs left structured records on disk. Arm H passes; the differential is the
# proof arm H stats the record rather than reading the series.
mkdir -p "$TARGET/repaired-delegated"
pass "$TARGET/repaired-delegated/s1-adversarial-pass1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET
pass "$TARGET/repaired-delegated/s1-adversarial-pass2.md" 2 0 1 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/repaired-delegated/s1-adversarial-pass3.md" 3 0 0 2 EXIT_CONDITION_MET
repair "$TARGET/repaired-delegated/s1-brief-repair-p1.md"
repair "$TARGET/repaired-delegated/s1-brief-repair-p2.md"

# --- repair-record-empty: STRUCTURE, isolated -- MUST FAIL (H) ----------------
# Same series again. p2's record is present and structured; p1's record EXISTS but is
# narrative prose -- no disposition/edit/derivation. Isolates the structure arm from bare
# existence: a stub file is not a repair record.
mkdir -p "$TARGET/repair-record-empty"
pass "$TARGET/repair-record-empty/s1-adversarial-pass1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET
pass "$TARGET/repair-record-empty/s1-adversarial-pass2.md" 2 0 1 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/repair-record-empty/s1-adversarial-pass3.md" 3 0 0 2 EXIT_CONDITION_MET
repair "$TARGET/repair-record-empty/s1-brief-repair-p1.md" unstructured
repair "$TARGET/repair-record-empty/s1-brief-repair-p2.md"

# --- repaired-delegated-bold: THE HOUSE STYLE -- MUST PASS (v0.355.0) ---------
# The SAME byte-identical pass series a third time. Records are structured and complete;
# the only difference from repaired-delegated is that the three field headings carry the
# bold emphasis markdown puts on a field name. A human reads all three fields; arm H before
# v0.355.0 read none of them and blocked the gate.
#
# THIS CASE IS RED AT 0.354.0 AND THAT IS THE POINT. It pairs with repair-record-empty the
# way repaired-delegated pairs with repaired-inline-no-record: if the reader is ever
# re-narrowed to the plain form, this goes red; if it is ever widened to "any line
# mentioning the word", repair-record-off-label below goes red. Neither can move alone.
mkdir -p "$TARGET/repaired-delegated-bold"
pass "$TARGET/repaired-delegated-bold/s1-adversarial-pass1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET
pass "$TARGET/repaired-delegated-bold/s1-adversarial-pass2.md" 2 0 1 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/repaired-delegated-bold/s1-adversarial-pass3.md" 3 0 0 2 EXIT_CONDITION_MET
repair "$TARGET/repaired-delegated-bold/s1-brief-repair-p1.md" bold
repair "$TARGET/repaired-delegated-bold/s1-brief-repair-p2.md" bold

# --- repair-record-off-label: THE BOUNDARY -- MUST FAIL (H) (v0.355.0) --------
# Same series again. p1's record is emphasised the same way repaired-delegated-bold's is,
# but its labels are NOT the taught ones: `edit sites:`, `derivation (qualifier):`, and a
# `### Derivation 1 —` heading in place of the field. remediator.md teaches that the gate
# reads the label literally; a record that renames the field is off-template and arm H is
# RIGHT to fail it. Measured on the reference consumer: 12 of 74 records look like this, and
# admitting them would require a predicate that also matches ordinary prose.
mkdir -p "$TARGET/repair-record-off-label"
pass "$TARGET/repair-record-off-label/s1-adversarial-pass1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET
pass "$TARGET/repair-record-off-label/s1-adversarial-pass2.md" 2 0 1 2 EXIT_CONDITION_NOT_MET
pass "$TARGET/repair-record-off-label/s1-adversarial-pass3.md" 3 0 0 2 EXIT_CONDITION_MET
repair "$TARGET/repair-record-off-label/s1-brief-repair-p1.md" off-label
repair "$TARGET/repair-record-off-label/s1-brief-repair-p2.md" bold

# The harness-owned transcript the RESOLUTION citations verify against (v0.61.0). A resolution
# clears an operator-gated HARD_BLOCK, so its operator_authorization must quote a GENUINE
# operator message at or after the divergent pass (p2 invoked_at 2026-07-12T02:00:00Z). One
# real operator turn here backs both REVERT_REPAIR records above.
cat > "$TARGET/operator-transcript.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 1. Kick off the cycle."}}
{"type":"assistant","timestamp":"2026-07-12T02:00:00Z","message":{"content":[{"type":"text","text":"p2 stamped DIVERGENT_HARD_BLOCK; pausing for your adjudication."}]}}
{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Revert the p1 to p2 repair wholesale — it made the check unfalsifiable."}}
{"type":"assistant","timestamp":"2026-07-12T04:00:00Z","message":{"content":[{"type":"text","text":"A second series has held a nonzero MAJOR at zero CRITICAL for three passes -- arm E calls that a STALL. Another pass is not the remedy."}]}}
JSONL

# A SECOND SESSION'S TRANSCRIPT, in the same directory. The stall was adjudicated HERE,
# not in the session that later asks permission -- which is the whole defect. A resolution
# record outlives the session that wrote it, and `transcript_path` is always the session
# ASKING, never the one in which the operator spoke. A single-file check therefore made
# every record unverifiable across a handoff, /clear or auto-compact.
cat > "$TARGET/prior-session-transcript.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T05:00:00Z","message":{"content":"Cut the claim and re-verify — if it cannot be checked cheaply it is not load-bearing."}}
JSONL

printf '%s\n' "$TARGET"

# --- stalled-resolved: THE SANCTIONED EXIT FROM A STALL ------------------------
# `RESOLVED_TERMINAL` was assigned in ONE place, inside a loop whose first line is
# `[ "${P_VERDICT[$i]}" = "DIVERGENT_HARD_BLOCK" ] || continue`. A stalled terminal pass
# stamps EXIT_CONDITION_NOT_MET, so it was continue'd past and the flag stayed 0 forever
# -- making `RESOLVED` unreachable for a stall and that emit branch dead code.
#
# The cost was a DEADLOCK. Arm E's remedy says "resolve on the record and run ONE
# verification pass"; ai-dlc-acknowledge.sh denies every dispatch on rc 3. So the lead
# wrote the record arm E asked for, the state stayed STALLED/rc 3, and the pass the remedy
# named could not be dispatched. The only way out was forging the terminal verdict.
#
# Identical severity trajectory to `stalled` above -- the ONLY difference is the record.
# That pairing is the assertion: same series, one file, opposite states.
mkdir -p "$TARGET/stalled-resolved"
pass "$TARGET/stalled-resolved/s1-adversarial-p1.md" 1 2 2 3 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/stalled-resolved/s1-adversarial-p2.md" 2 0 1 3 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled-resolved/s1-adversarial-p3.md" 3 0 1 4 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled-resolved/s1-adversarial-p4.md" 4 0 1 2 EXIT_CONDITION_NOT_MET 0 ddd4
record "$TARGET/stalled-resolved/s1-resolution-p4.md" \
  s1-adversarial-p4.md CHANGE_APPROACH ddd4 ddd5 4000 4200 \
  "cut the unverifiable universal the MAJORs kept falsifying" \
  '2026-07-12T05:00:00Z | "Cut the claim and re-verify"'

# --- stalled-record-invalid: an INVALID record legalises NOTHING ----------------
# The over-fire control for the arm above. If a malformed record cleared a stall, the
# resume would be reachable by writing any file at all and the notarization would be
# decoration.
mkdir -p "$TARGET/stalled-record-invalid"
pass "$TARGET/stalled-record-invalid/s1-adversarial-p1.md" 1 2 2 3 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/stalled-record-invalid/s1-adversarial-p2.md" 2 0 1 3 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled-record-invalid/s1-adversarial-p3.md" 3 0 1 4 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/stalled-record-invalid/s1-adversarial-p4.md" 4 0 1 2 EXIT_CONDITION_NOT_MET 0 eee4
record "$TARGET/stalled-record-invalid/s1-resolution-p4.md" \
  s1-adversarial-p4.md CHANGE_APPROACH WRONGSHA eee5 4000 4200 \
  "sha_before does not match the pass it claims to resolve" \
  '2026-07-12T05:00:00Z | "Cut the claim and re-verify"'

# =============================================================================
# ARM J -- RE-OPEN: a pass ran after the series already stamped EXIT_CONDITION_MET.
# =============================================================================

# --- reopen-unrecorded: the measured case ------------------------------------
# One consumer's research-requirements series reached MET at pass 2 and was re-opened by
# an Advanced Elicitation run that edited the artifact AFTER convergence, buying a
# five-pass sub-cycle nobody scheduled. J must fire, and the state must be REOPENED so
# the hooks deny the dispatch.
mkdir -p "$TARGET/reopen-unrecorded"
pass "$TARGET/reopen-unrecorded/s1-adversarial-p1.md" 1 4 2 1 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/reopen-unrecorded/s1-adversarial-p2.md" 2 0 0 0 EXIT_CONDITION_MET     0
pass "$TARGET/reopen-unrecorded/s1-adversarial-p3.md" 3 1 2 1 EXIT_CONDITION_NOT_MET 0
repair "$TARGET/reopen-unrecorded/s1-brief-repair-p1.md"

# --- reopen-floor-pass: THE DECOY FOR J, and the one Rule 8's FLOOR depends on --
# `full` intensity owes 2+ passes. A series whose p1 already converged still owes p2, and
# that pass finding NOTHING is the floor being met -- not a re-open. Seeded from a REAL
# trajectory (s292-stories p1 MET -> p2 MET, 0 findings). The naive arm fires here; if
# this case ever goes red the `blocking > 0` refinement has been lost and Rule 8's floor
# is being punished as a defect.
mkdir -p "$TARGET/reopen-floor-pass"
pass "$TARGET/reopen-floor-pass/s1-adversarial-p1.md" 1 0 0 2 EXIT_CONDITION_MET 0
pass "$TARGET/reopen-floor-pass/s1-adversarial-p2.md" 2 0 0 1 EXIT_CONDITION_MET 0

# --- reopen-recorded: the sanctioned exit ------------------------------------
# A declared re-open resumes, exactly as a resolved hard block does. Without this case
# the arm would be a trap with no door: every real re-open would need the operator to
# delete a pass file.
mkdir -p "$TARGET/reopen-recorded"
pass "$TARGET/reopen-recorded/s1-adversarial-p1.md" 1 4 2 1 EXIT_CONDITION_NOT_MET 0
pass "$TARGET/reopen-recorded/s1-adversarial-p2.md" 2 0 0 0 EXIT_CONDITION_MET     0
record "$TARGET/reopen-recorded/s1-resolution-p2.md" \
  s1-adversarial-p2.md REOPEN_AFTER_MET ccc1 ccc2 4000 4300 \
  "advanced elicitation edited the artifact after it was notarised" \
  '2026-07-12T03:00:00Z | "re-open the series and carry the elicitation edits"'
pass "$TARGET/reopen-recorded/s1-adversarial-p3.md" 3 1 2 1 EXIT_CONDITION_NOT_MET 0 ccc2 s1-resolution-p2.md
pass "$TARGET/reopen-recorded/s1-adversarial-p4.md" 4 0 0 1 EXIT_CONDITION_MET         0 ccc3
repair "$TARGET/reopen-recorded/s1-brief-repair-p1.md"
repair "$TARGET/reopen-recorded/s1-brief-repair-p3.md"

# =============================================================================
# ARM I -- RESOLUTION CEILING: the sanctioned exit, taken more than once.
# =============================================================================
# All four cases carry the SAME five passes and differ only in the resolution records
# beside them. That is deliberate and it is the assertion: arms C, D and E all read the
# series, and the series is identical across every case here. Only a rung that reads the
# RECORDS can separate them, which is why neutralizing arm I collapses them together.
#
# Each series takes the exit TWICE -- p2 diverges and is resolved, p4 diverges and is
# resolved -- while the divergence contract sanctions ONE. Every record is VALID: this is
# not a malformed-record case (that is `stalled-record-invalid`), it is the sanctioned
# path used repeatedly, which every other rung reports as RESOLVED.

# --- ceiling-unanchored: THE CATCH -------------------------------------------
# Both releases declare CHANGE_APPROACH -- the kind F5 says out loud "cannot be anchored
# arithmetically". Two unanchored releases and the cycle is still not converged.
mkdir -p "$TARGET/ceiling-unanchored"
pass "$TARGET/ceiling-unanchored/s1-adversarial-p1.md" 1 2 1 3 EXIT_CONDITION_NOT_MET 2 c001
pass "$TARGET/ceiling-unanchored/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 c002
record "$TARGET/ceiling-unanchored/s1-resolution-p2.md" \
  s1-adversarial-p2.md CHANGE_APPROACH c002 c003 4000 4100 \
  "reframed the disputed section" \
  '2026-07-12T03:00:00Z | "Revert the p1 to p2 repair wholesale"'
pass "$TARGET/ceiling-unanchored/s1-adversarial-p3.md" 3 1 1 2 EXIT_CONDITION_NOT_MET 1 c003 s1-resolution-p2.md
pass "$TARGET/ceiling-unanchored/s1-adversarial-p4.md" 4 2 1 2 DIVERGENT_HARD_BLOCK   2 c004
record "$TARGET/ceiling-unanchored/s1-resolution-p4.md" \
  s1-adversarial-p4.md CHANGE_APPROACH c004 c005 4100 4200 \
  "reframed it again" \
  '2026-07-12T05:00:00Z | "Cut the claim and re-verify"'
pass "$TARGET/ceiling-unanchored/s1-adversarial-p5.md" 5 1 1 2 EXIT_CONDITION_NOT_MET 1 c005 s1-resolution-p4.md

# --- ceiling-anchored-release: THE DOOR --------------------------------------
# BYTE-IDENTICAL passes to the case above; the ONLY difference on disk is that the
# second release declares CUT_SCOPE, whose bytes must FALL (4100 -> 3900) and cannot be
# obtained by editing the kind field.
#
# WITHOUT THIS CASE THE ARM HAS NO EXIT AND WEDGES EVERY TWICE-RESOLVED CYCLE -- the
# deadlock v0.247.0/v0.248.0 fixed for the stall path, reopened one arm over. It is here
# for the same reason `divergent-resolved` is here for arm C.
mkdir -p "$TARGET/ceiling-anchored-release"
pass "$TARGET/ceiling-anchored-release/s1-adversarial-p1.md" 1 2 1 3 EXIT_CONDITION_NOT_MET 2 c001
pass "$TARGET/ceiling-anchored-release/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 c002
record "$TARGET/ceiling-anchored-release/s1-resolution-p2.md" \
  s1-adversarial-p2.md CHANGE_APPROACH c002 c003 4000 4100 \
  "reframed the disputed section" \
  '2026-07-12T03:00:00Z | "Revert the p1 to p2 repair wholesale"'
pass "$TARGET/ceiling-anchored-release/s1-adversarial-p3.md" 3 1 1 2 EXIT_CONDITION_NOT_MET 1 c003 s1-resolution-p2.md
pass "$TARGET/ceiling-anchored-release/s1-adversarial-p4.md" 4 2 1 2 DIVERGENT_HARD_BLOCK   2 c004
record "$TARGET/ceiling-anchored-release/s1-resolution-p4.md" \
  s1-adversarial-p4.md CUT_SCOPE c004 c005 4100 3900 \
  "dropped the contested clause" \
  '2026-07-12T05:00:00Z | "Cut the claim and re-verify"'
pass "$TARGET/ceiling-anchored-release/s1-adversarial-p5.md" 5 1 1 2 EXIT_CONDITION_NOT_MET 1 c005 s1-resolution-p4.md

# --- ceiling-single-resolution: THE DECOY ------------------------------------
# ONE unanchored release, still unconverged. This is the SANCTIONED exit, and it must
# cost nothing. A naive "an unanchored resolution is suspicious" reading fails it and
# turns the contract's own single sanctioned resolution into a violation.
mkdir -p "$TARGET/ceiling-single-resolution"
pass "$TARGET/ceiling-single-resolution/s1-adversarial-p1.md" 1 2 1 3 EXIT_CONDITION_NOT_MET 2 c001
pass "$TARGET/ceiling-single-resolution/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 c002
record "$TARGET/ceiling-single-resolution/s1-resolution-p2.md" \
  s1-adversarial-p2.md CHANGE_APPROACH c002 c003 4000 4100 \
  "reframed the disputed section" \
  '2026-07-12T03:00:00Z | "Revert the p1 to p2 repair wholesale"'
pass "$TARGET/ceiling-single-resolution/s1-adversarial-p3.md" 3 1 1 2 EXIT_CONDITION_NOT_MET 1 c003 s1-resolution-p2.md

# --- ceiling-converged: SUPPRESSED BY THE TERMINAL VERDICT -------------------
# The `ceiling-unanchored` series plus a sixth pass that converges. Two unanchored
# releases, and the arm stays silent -- it exists to stop cycles that do not terminate,
# not to punish one that did. Without this, every already-shipped cycle that used the
# exit twice would fail its gate retroactively.
mkdir -p "$TARGET/ceiling-converged"
pass "$TARGET/ceiling-converged/s1-adversarial-p1.md" 1 2 1 3 EXIT_CONDITION_NOT_MET 2 c001
pass "$TARGET/ceiling-converged/s1-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   3 c002
record "$TARGET/ceiling-converged/s1-resolution-p2.md" \
  s1-adversarial-p2.md CHANGE_APPROACH c002 c003 4000 4100 \
  "reframed the disputed section" \
  '2026-07-12T03:00:00Z | "Revert the p1 to p2 repair wholesale"'
pass "$TARGET/ceiling-converged/s1-adversarial-p3.md" 3 1 1 2 EXIT_CONDITION_NOT_MET 1 c003 s1-resolution-p2.md
pass "$TARGET/ceiling-converged/s1-adversarial-p4.md" 4 2 1 2 DIVERGENT_HARD_BLOCK   2 c004
record "$TARGET/ceiling-converged/s1-resolution-p4.md" \
  s1-adversarial-p4.md CHANGE_APPROACH c004 c005 4100 4200 \
  "reframed it again" \
  '2026-07-12T05:00:00Z | "Cut the claim and re-verify"'
pass "$TARGET/ceiling-converged/s1-adversarial-p5.md" 5 1 1 2 EXIT_CONDITION_NOT_MET 1 c005 s1-resolution-p4.md
pass "$TARGET/ceiling-converged/s1-adversarial-p6.md" 6 0 0 1 EXIT_CONDITION_MET      0 c006
repair "$TARGET/ceiling-converged/s1-brief-repair-p5.md"

# =============================================================================
# THE MAJOR SPLIT -- findings_major_underived.
#
# `adversary.md` grades an underived factual claim a MAJOR "whether or not you can yet
# falsify it", and the exit condition reads findings_major. So UNPROVEN blocked the exit
# exactly as hard as WRONG, and the discharge for unproven is to ADD a derivation -- an
# edit, which is what the next pass reviews. The split lets an underived-but-unfalsified
# MAJOR be RECORDED without blocking; a MAJOR shown WRONG still blocks.
#
# THE FIVE CASES ARE A PARTITION OF THE WAYS THIS CAN GO WRONG, and the last one is the
# migration proof.
# =============================================================================

# All three MAJORs are underived: 0 blocking, so MET is the honest verdict.
mkdir -p "$TARGET/underived-exits"
pass "$TARGET/underived-exits/s1-adversarial-p1.md" 1 2 3 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/underived-exits/s1-adversarial-p2.md" 2 0 3 1 EXIT_CONDITION_MET     0 "" "" "" 3
repair "$TARGET/underived-exits/s1-brief-repair-p1.md"

# TWO of three underived: ONE blocking MAJOR remains, so MET is a false convergence.
# This is the arm that stops the split becoming a free exit.
mkdir -p "$TARGET/underived-partial-blocks"
pass "$TARGET/underived-partial-blocks/s1-adversarial-p1.md" 1 2 3 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/underived-partial-blocks/s1-adversarial-p2.md" 2 0 3 1 EXIT_CONDITION_MET     0 "" "" "" 2
repair "$TARGET/underived-partial-blocks/s1-brief-repair-p1.md"

# The partition EXCEEDS the whole: 4 underived of 3 MAJOR. Refused rather than clamped --
# inflating this field is the single edit that would buy EXIT_CONDITION_MET outright.
mkdir -p "$TARGET/underived-exceeds"
pass "$TARGET/underived-exceeds/s1-adversarial-p1.md" 1 2 3 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/underived-exceeds/s1-adversarial-p2.md" 2 0 3 1 EXIT_CONDITION_MET     0 "" "" "" 4
repair "$TARGET/underived-exceeds/s1-brief-repair-p1.md"

# 0 blocking and it still stamps NOT_MET -- the S289 pass-4 shape, one level down. The
# residue IS the exit condition and the field the gate reads must say so.
mkdir -p "$TARGET/underived-refuses"
pass "$TARGET/underived-refuses/s1-adversarial-p1.md" 1 2 3 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/underived-refuses/s1-adversarial-p2.md" 2 0 3 1 EXIT_CONDITION_NOT_MET 0 "" "" "" 3
repair "$TARGET/underived-refuses/s1-brief-repair-p1.md"

# THE MIGRATION PROOF: the SAME residue with NO field at all still blocks. Absent means
# ZERO here -- the opposite of prior_scope's default, and the reason no block written
# before this field existed can change verdict.
mkdir -p "$TARGET/underived-absent-still-blocks"
pass "$TARGET/underived-absent-still-blocks/s1-adversarial-p1.md" 1 2 3 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/underived-absent-still-blocks/s1-adversarial-p2.md" 2 0 3 1 EXIT_CONDITION_MET     0
repair "$TARGET/underived-absent-still-blocks/s1-brief-repair-p1.md"
