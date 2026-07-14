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
  local prior="${7:-}" sha="${8:-}" resolves="${9:-}" at="${10:-}"
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
    printf 'findings_minor: %s\n' "$minor"
    [ -n "$verdict" ] && printf 'verdict: %s\n' "$verdict"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$file"
}

# The RESOLUTION record -- the resume contract, as a file. v0.59.0.
# $1 file  $2 resolves-pass-basename  $3 kind  $4 sha_before  $5 sha_after
# $6 bytes_before  $7 bytes_after  $8 scope_delta  $9 operator_authorization  $10 archive
record() {
  local file="$1" resolves="$2" kind="$3" sb="$4" sa="$5" bb="$6" ba="$7"
  local delta="${8:-}" auth="${9:-}" arch="${10:-}"
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
    printf 'ADVERSARIAL_RESOLUTION_END -->\n'
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
# divergence -- the repairs held -- so NOT_MET is the correct stamp.
mkdir -p "$TARGET/scope-grew-converges"
pass "$TARGET/scope-grew-converges/s1-adversarial-pass1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET 2
pass "$TARGET/scope-grew-converges/s1-adversarial-pass2.md" 2 3 1 2 EXIT_CONDITION_NOT_MET 1
pass "$TARGET/scope-grew-converges/s1-adversarial-pass3.md" 3 0 0 2 EXIT_CONDITION_MET     0

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
  s1-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000 "reverted the p1->p2 repair wholesale"
pass "$TARGET/divergent-resolved/s1-adversarial-p3.md" 3 0 0 2 EXIT_CONDITION_MET 0 aaa1 s1-resolution-p2.md

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
  s1-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000 "reverted the p1->p2 repair wholesale"

printf '%s\n' "$TARGET"
