#!/usr/bin/env bash
# budget-summary-verdict — validate-artifact-budget.sh's closing summary line must be a
# function of WHAT THE RUN PRINTED, never of its exit code.
#
# Usage: run.sh          (cwd-invariant; the subject is located from $0, not from cwd)
# Exit:  0 = every assertion holds, 1 = the summary regressed, 2 = fixture broken.
#
# THE DEFECT. `RC` is deliberately 0 on the `--warn-only` path when no breaching artifact
# was hardened with `--fail-on`: retro.md depends on that contract, because the sprint has
# already paid for every oversized read and blocking it helps nobody. The summary line was
# gated on `RC`. So one run could print `WARN: N artifact(s) over the Rule 25(d) budget.`,
# list every `OVER` row, and then close with `PASS  every measured living artifact is
# within its Rule 25(d) budget.` -- both statements in the same run, one of them false.
# Filed by the reference consumer as PC-S303-BUDGET-SCRIPT-PASS-LINE-UNCONDITIONAL.
#
# THE EXIT CODE IS THE THING THAT MUST NOT MOVE, which is why every arm asserts it. The
# tempting "fix" is to make the breach exit 1 under --warn-only so the summary can stay
# keyed on RC. That wedges every sprint that has already paid for an oversized artifact,
# and it is a regression this fixture is here to fail loudly on: the summary changed and
# the exit code did not.
#
# THE CO-OCCURRENCE ARM IS THE ONE THAT OWNS THE FILING. Arms 1-8 each assert their own
# run's summary text. Arm 9 joins across every run recorded above and asserts that no run
# which reported a breach also printed the unqualified PASS line -- the exact pair the
# filing names. It carries two controls of its own, because a join over an empty or
# blind ledger passes without observing anything.
#
# WHY THE SUBJECT IS LOCATED BY CANDIDATE LIST AND NOT BY WALKING UP FOR `VERSION`.
# `install.sh` ships no `VERSION` to a consumer root (it stamps `.claude/.ai-dlc-version`
# instead), so a walk-up for that marker resolves nothing on the tree this fixture also
# runs in. The three candidates below are relative to THIS FILE, name both install
# layouts explicitly, and make the fixture independent of cwd entirely.

# EACH MUTANT IS SCORED ON ITS DECIDING ARM PLUS ONE NAMED TWIN. An ARM is one seeded world plus one
# predicate (a1warn, f_five, lg, ...), built fresh for every cell and driven through a validator
# directory and a verdict wrapper. Per push a mutant runs its deciding arm (it must trip) and its twin
# (an arm the measured matrix shows GREEN for it), so the kill is confined to the arm that owns it. The
# full mutant x arm matrix is MEASURED by the --matrix argv mode and is re-measured whenever an arm or a
# mutant is added or changed. The recorded matrix plus the twin replaces the exact-vector assertion
# that a mutant fails only its own assertion. Kills go through mutant_killed behind the same-run pass
# of the unmutated arm (B_<arm>), and an unmutated copy of the LATE validator is asserted green first.
# MUTANT-MATRIX M1 decides=a1warn twins=a3noflag
# MUTANT-MATRIX M2 decides=a1warn twins=a6schema
# MUTANT-MATRIX M3 decides=a5cov twins=a4clean
# MUTANT-MATRIX M4 decides=a10struck twins=a11marker
# MUTANT-MATRIX M5 decides=a11marker twins=a10struck
# MUTANT-MATRIX MF1 decides=f_five twins=- why=the mutated validator trips every arm that drives it, so every one of the 26 arms trips on it and none stays green
# MUTANT-MATRIX MF2 decides=f_range twins=- why=the mutated validator trips every arm that drives it, so every one of the 26 arms trips on it and none stays green
# MUTANT-MATRIX MF3 decides=f_history twins=f_five
# MUTANT-MATRIX MF4 decides=f_spaced twins=- why=the mutated validator trips every arm that drives it, so every one of the 26 arms trips on it and none stays green
# MUTANT-MATRIX MF5 decides=f_dash twins=- why=the mutated validator trips every arm that drives it, so every one of the 26 arms trips on it and none stays green
# MUTANT-MATRIX MF6 decides=f8 twins=f9
# MUTANT-MATRIX MP1 decides=p_basename twins=p_noitem
# MUTANT-MATRIX MP2 decides=p_noitem twins=p_basename
# MUTANT-MATRIX MW1 decides=f8 twins=lg
# MUTANT-MATRIX MW2 decides=f9 twins=f8
# MUTANT-MATRIX MW3 decides=lg twins=f8
# MUTANT-MATRIX MW4 decides=vs twins=vt_under
# MUTANT-MATRIX MW5 decides=vt_more twins=vt_under
# MUTANT-MATRIX MW6 decides=vt_under twins=vt_more
# MUTANT-MATRIX ML1 decides=l1b twins=l0eq
# MUTANT-MATRIX ML2 decides=le_skip twins=l0eq
# MUTANT-MATRIX ML4 decides=lh_clear twins=l0eq
# MUTANT-MATRIX ML5 decides=la_amb twins=l0eq
# MUTANT-MATRIX ML6 decides=ls_same twins=la_amb
# MUTANT-MATRIX-CONTROL ML0 why=the probe-off copy of the LATE validator beside its siblings must stay green on every LATE arm; it survives by design
# MUTANT-MATRIX-REMEASURE bash core/fixtures/budget-summary-verdict/run.sh --matrix
set -u

MATRIX=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; fi
MROWS=0

# THE PRE-PUSH GATE INHERITS EVERY AI_DLC_* TUNABLE A CONSUMER SET IN settings.json, and a
# fixture that drives a validator while inheriting them tests the CONFIG, not the CODE.
# Every threshold this fixture seeds against is one of them -- AI_DLC_BYTES_PER_TOKEN,
# AI_DLC_BUDGET_GRACE_PCT, AI_DLC_BUDGET_GATE_LOG_MD, AI_DLC_UNGOVERNED_FLOOR -- so an
# ambient value does not merely change a number here, it decides whether the seeded
# breach is a breach at all. Arm 0 is the backstop; this loop is the cause.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

DIR="$(cd "$(dirname "$0")" && pwd)"
V=""
for cand in \
  "$DIR/../../scripts/validate-artifact-budget.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-artifact-budget.sh" \
  "$DIR/../../core/scripts/validate-artifact-budget.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-artifact-budget.sh in either layout" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-artifact-budget.sh"
# verdict.sh ships beside the validator in both layouts (core/scripts/, scripts/ai-dlc/).
VW="$(dirname "$V")/verdict.sh"
[ -f "$VW" ] || { echo "run.sh: could not locate verdict.sh beside $V" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/verdict.sh"


MUT_LIB="$DIR/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found at $MUT_LIB" >&2; exit 2; }
rc=0
ok()  { echo "ok: $1"; }
bad() { echo "FAIL: $1" >&2; rc=1; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
[ -f "$DIR/../lib/matrix.sh" ] || { echo "FIXTURE ERROR: lib/matrix.sh not found" >&2; exit 2; }
. "$DIR/../lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"
VD="$(dirname "$V")"

WORK="$(mktemp -d 2>/dev/null)" || { echo "run.sh: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
# A marker at the scratch root so a validator COPY staged under $WORK/bin resolves its
# root by walking up to $WORK rather than to whatever tree the cwd happens to sit in.
# Every arm still passes --root explicitly; this only removes the pre-parse resolution
# as a source of difference between the mutants and the unmutated subject.
mkdir -p "$WORK/.claude" "$WORK/bin" "$WORK/runs" || exit 2

# THE STRING IS PINNED AS A LITERAL, BYTE FOR BYTE. The clean line is the one anything
# downstream may already match on -- verdict.sh pastes it into gate logs, and Check 15
# reads those cells back. A fix that moves the passing output is a fix nobody can adopt
# quietly, so the clean run's line is asserted with `grep -Fx`, not by pattern.
PASS_LINE='PASS  every measured living artifact is within its Rule 25(d) budget.'
QUALIFIER='      Measured is not everything: this run also reported read-path artifact(s) that'

# -----------------------------------------------------------------------------------
# The sandbox. One directory per arm, so no arm inherits another's seed.
#
# gate-log.md carries a 25000-tok budget at 4 bytes/token with a 10% grace band, so the
# block ceiling is 110,000 bytes. 200,000 bytes is 50,000 tok -- 200% of budget, past the
# ceiling, and reported as `OVER ... -> rotate`. It is chosen over pipeline-snapshot.md
# deliberately: the snapshot drags in four more verdict channels (schema, struck rows,
# unknown status, in-place markers) and an arm about the BREACH channel must not be
# satisfied by one of those firing instead.
# -----------------------------------------------------------------------------------
arm_dir() { # arm_dir <name> -> prints a fresh sandbox path
  d="$WORK/$1"
  rm -rf "$d"
  mkdir -p "$d/_bmad-output" "$d/.claude" || exit 2
  printf '%s\n' "$d"
}
seed_breach()  { head -c 200000 /dev/zero | tr '\0' 'x' > "$1/_bmad-output/gate-log.md"; }
seed_clean()   { printf 'tiny\n' > "$1/_bmad-output/gate-log.md"; }

# An artifact a STEP FILE names and no budget governs, over the 2000-tok floor. This is
# the coverage arm's only input, and it fires only when a steps directory exists under
# the root and no --only was passed.
seed_ungoverned() {
  mkdir -p "$1/.claude/skills/ai-dlc/steps" || exit 2
  printf 'The lead reads `_bmad-output/coverage-probe.md` before dispatching.\n' \
    > "$1/.claude/skills/ai-dlc/steps/probe.md"
  head -c 40000 /dev/zero | tr '\0' 'x' > "$1/_bmad-output/coverage-probe.md"
}

# A schema-clean, well-under-budget snapshot; `$2` is dropped in whole so only the seeded
# defect varies between arms and a failure cannot be the byte ceiling instead.
seed_snapshot() { # seed_snapshot <dir> <extra-block>
  printf '## Pipeline Position\n- at retro\n## Sprint Context\n- sprint 1\n## Recent Activity\n- nothing notable\n## Open Items\n- none\n## Locked Decisions\n- keep the threshold\n## In-Flight Teammates\n%s\n## Context Reminders\n- keep it small\n' \
    "$2" > "$1/_bmad-output/pipeline-snapshot.md"
}
INFLIGHT_CLEAN='| teammate | deliverable | dispatched-at | note | status |
| --- | --- | --- | --- | --- |
| dev-a | story-1 | 2026-01-01 | none | in-flight |'
INFLIGHT_BAD_STATUS='| teammate | deliverable | dispatched-at | note | status |
| --- | --- | --- | --- | --- |
| dev-a | story-1 | 2026-01-01 | none | finished |'

# -----------------------------------------------------------------------------------
# THE RUN LEDGER. Every drive below writes one row, and arm 9 joins over it. The row is
# derived from the run's own output and status -- never from what the arm expected --
# so a mis-stated expectation above cannot make the join agree with itself.
#   label | exit | saw_breach_row | saw_pass_line
# -----------------------------------------------------------------------------------
LEDGER="$WORK/ledger.tsv"
: > "$LEDGER"
OUT=""
drive() { # drive <label> <script> <root> [args...]
  _label="$1"; _script="$2"; _root="$3"; shift 3
  OUT="$WORK/runs/$_label.out"
  bash "$_script" --root "$_root" "$@" > "$OUT" 2>&1
  _st=$?
  _b=0; grep -q '^OVER  ' "$OUT" && _b=1
  _p=0; grep -qxF "$PASS_LINE" "$OUT" && _p=1
  printf '%s\t%s\t%s\t%s\n' "$_label" "$_st" "$_b" "$_p" >> "$LEDGER"
  return "$_st"
}
status_of() { awk -F'\t' -v l="$1" '$1==l{print $2}' "$LEDGER"; }
has()  { grep -qxF "$1" "$OUT"; }
hasl() { grep -qF  "$1" "$OUT"; }

echo "budget-summary-verdict"

# --- 0. THE SEED IS ACTUALLY MEASURED ------------------------------------------------
# A tree that cannot express the defect proves nothing, and every arm below is a claim
# about a run that reported a breach. If the seed does not appear as an OVER row -- a
# budget retuned, a divisor changed, a find path moved -- everything after this is
# vacuously green, so this is a FIXTURE BROKEN, not a failed assertion.
A0="$(arm_dir seed)"; seed_breach "$A0"
drive seed-proof "$V" "$A0" --warn-only
if ! grep -q '^OVER  _bmad-output/gate-log\.md' "$OUT"; then
  echo "FIXTURE ERROR: the seeded 200000-byte gate-log.md was not reported as a breach" >&2
  echo "  the budget, the divisor or the search path moved; re-derive the seed size" >&2
  sed 's/^/  /' "$OUT" >&2
  exit 2
fi
# The other direction, in the same invocation: the clean seed must NOT produce one, or
# the arm above is satisfied by a validator that reports everything.
A0C="$(arm_dir seed-clean)"; seed_clean "$A0C"
drive seed-control "$V" "$A0C" --warn-only
if grep -q '^OVER  ' "$OUT"; then
  echo "FIXTURE ERROR: a 5-byte gate-log.md was ALSO reported as a breach" >&2
  exit 2
fi
ok "SEED: 200000 bytes of gate-log.md is an OVER row and 5 bytes is not"
# --- 2. --warn-only --fail-on <the breacher>: the exit code moves, the contract holds -
# The hardened artifact makes THIS run block while --warn-only still governs the rest.
# RC is 1, so the summary block does not run at all -- the arm's own message is the
# --fail-on line, and the exit code is the half a future "fix" would break.
A2="$(arm_dir warnonly-hardened)"; seed_breach "$A2"
drive warnonly-hardened "$V" "$A2" --warn-only --fail-on gate-log.md
if [ "$(status_of warnonly-hardened)" = "1" ] \
   && hasl 'is over budget and was hardened with --fail-on, so this run blocks despite --warn-only.'; then
  ok "--warn-only --fail-on gate-log.md exits 1 and names the hardening as the reason"
else
  bad "--warn-only --fail-on gate-log.md: exit $(status_of warnonly-hardened), --fail-on line missing"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi
# --- 7. THE IN-FLIGHT STATUS CHANNEL --------------------------------------------------
A7="$(arm_dir status)"; seed_clean "$A7"
seed_snapshot "$A7" "$INFLIGHT_BAD_STATUS"
drive status-warnonly "$V" "$A7" --warn-only
if [ "$(status_of status-warnonly)" = "0" ] \
   && has 'WARN  this run reported unrecognised In-Flight status row(s) and is NOT a clean result.'; then
  ok "--warn-only over an unrecognised In-Flight status exits 0 and names it in the summary"
else
  bad "unrecognised status under --warn-only: exit $(status_of status-warnonly), summary line missing"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi

# --- 8. ALL THREE AT ONCE: the summary enumerates, it does not pick one ---------------
# A run that reported three different findings and named one of them would send the lead
# to one remedy and hide two. The channels are not interchangeable -- that is why they
# are four separate verdicts in the subject -- so the summary must carry all of them.
A8="$(arm_dir combined)"; seed_breach "$A8"
seed_snapshot "$A8" "$INFLIGHT_BAD_STATUS"
printf '\n## Invented Section\n- lead invention\n' >> "$A8/_bmad-output/pipeline-snapshot.md"
drive combined-warnonly "$V" "$A8" --warn-only
if [ "$(status_of combined-warnonly)" = "0" ] \
   && has 'WARN  this run reported over-budget artifact(s), off-schema section(s), unrecognised In-Flight status row(s) and is NOT a clean result.'; then
  ok "three channels in one --warn-only run are all enumerated in one summary line"
else
  bad "combined --warn-only run: exit $(status_of combined-warnonly), the summary did not enumerate all three"
  grep -E '^WARN  this run' "$OUT" | sed 's/^/      /' >&2
fi

# --- 10-14. THE TWO CHANNELS THAT USED TO SET NO FLAG (BL-020) ------------------------
# The marked-superseded block and the struck-row block each print a `WARN:` under
# --warn-only, and neither raised a SAW_* flag, so a run whose only finding came from one
# of them fell through to the bare PASS line. Arm 9's join keys on `^OVER  ` rows and
# cannot see either channel, so these arms assert the summary directly.
#
# THE STRUCK ROW IS DRIVEN UNDER retro.md's LITERAL FLAGS, `--warn-only --fail-on
# pipeline-snapshot.md`, because that is the shipped invocation that reached the false
# PASS: --fail-on does not harden the struck-row channel, so RC stays 0 and the summary
# runs. Its status cell is `in-flight`, a member of the closed set, so the status channel
# cannot co-fire and supply the qualified line on its own.
INFLIGHT_STRUCK='| teammate | deliverable | dispatched-at | note | status |
| --- | --- | --- | --- | --- |
| ~~dev-a~~ | story-1 | 2026-01-01 | none | in-flight |'
RETRO_FLAGS="--warn-only --fail-on pipeline-snapshot.md"
seed_marker() { printf -- '- the old plan SUPERSEDED\n' >> "$1/_bmad-output/pipeline-snapshot.md"; }

# =====================================================================================
# ARMS, MUTANTS, TWINS AND THE MATRIX.
#
# An ARM is one seeded world plus one predicate, run through a validator directory MD (the validator
# and the siblings it resolves) and a verdict wrapper MW. Every arm builds its OWN fresh world, so a
# mutant is driven over exactly the state the unmutated arm saw and no arm inherits another's seed.
# An arm returns 0 when the behaviour HOLDS (GREEN) and non-zero when it TRIPS. Per push each mutant
# runs its DECIDING arm (it must trip) and ONE named TWIN (it must stay green); the --matrix argv mode
# runs every mutant over every arm. The unmutated arm's pass in THIS run is the flag B_<arm>, set by
# the base block above that asserts the same behaviour, and a kill is emitted only through
# mutant_killed behind that flag.
# =====================================================================================
MUTS="$WORK/muts"; mkdir -p "$MUTS" || exit 2
MREG=""
AXC=0
ARMS="a1warn a3noflag a4clean a5cov a6schema a10struck a11marker f_five f_range f_history f_spaced f_dash f_past f8 f9 p_basename p_noitem lg vs vt_more vt_under l1b l0eq le_skip la_amb ls_same lh_clear"
axw() { AXD="$(mktemp -d "$WORK/aw.XXXXXX")"; mkdir -p "$AXD/_bmad-output" "$AXD/.claude" || exit 2; }
axl() { AXC=$((AXC + 1)); AXL="$1.$AXC"; }
vtool() { printf '%s/validate-artifact-budget.sh' "$1"; }

# --- the arms (each: $1 = validator dir, $2 = verdict wrapper) --------------------------
arm_a1warn() { axw; seed_breach "$AXD"; axl a1warn; drive "$AXL" "$(vtool "$1")" "$AXD" --warn-only
  [ "$(status_of "$AXL")" = 0 ] && has 'WARN  this run reported over-budget artifact(s) and is NOT a clean result.' \
    && has '      Exit status is 0 because --warn-only was passed and no reported artifact was' && ! has "$PASS_LINE"; }
arm_a3noflag() { axw; seed_breach "$AXD"; axl a3noflag; drive "$AXL" "$(vtool "$1")" "$AXD"
  [ "$(status_of "$AXL")" = 1 ] && has 'FAIL: 1 artifact(s) over the Rule 25(d) budget.'; }
arm_a4clean() { axw; seed_clean "$AXD"; axl a4clean; drive "$AXL" "$(vtool "$1")" "$AXD"
  [ "$(status_of "$AXL")" = 0 ] && has "$PASS_LINE" && ! grep -q '^WARN' "$OUT" || return 1
  axl a4warn; drive "$AXL" "$(vtool "$1")" "$AXD" --warn-only
  [ "$(status_of "$AXL")" = 0 ] && has "$PASS_LINE" && ! grep -q '^WARN' "$OUT"; }
arm_a5cov() { axw; seed_clean "$AXD"; seed_ungoverned "$AXD"; axl a5cov; drive "$AXL" "$(vtool "$1")" "$AXD"
  [ "$(status_of "$AXL")" = 0 ] && has "$PASS_LINE" && has "$QUALIFIER" && hasl 'WARN: read-path artifact(s) over 2000 tok that NO budget governs.' || return 1
  rm -f "$AXD/_bmad-output/coverage-probe.md"; axl a5ctl; drive "$AXL" "$(vtool "$1")" "$AXD"
  [ "$(status_of "$AXL")" = 0 ] && has "$PASS_LINE" && ! has "$QUALIFIER"; }
arm_a6schema() { axw; seed_clean "$AXD"; seed_snapshot "$AXD" "$INFLIGHT_CLEAN"
  printf '\n## Invented Section\n- lead invention\n' >> "$AXD/_bmad-output/pipeline-snapshot.md"
  axl a6schema; drive "$AXL" "$(vtool "$1")" "$AXD" --warn-only
  [ "$(status_of "$AXL")" = 0 ] && has 'WARN  this run reported off-schema section(s) and is NOT a clean result.'; }
arm_a10struck() { axw; seed_clean "$AXD"; seed_snapshot "$AXD" "$INFLIGHT_STRUCK"; axl a10struck
  # shellcheck disable=SC2086
  drive "$AXL" "$(vtool "$1")" "$AXD" $RETRO_FLAGS
  [ "$(status_of "$AXL")" = 0 ] && has 'WARN: In-Flight Teammates carries struck-through row(s).' \
    && has 'WARN  this run reported struck-through In-Flight row(s) and is NOT a clean result.' && ! has "$PASS_LINE"; }
arm_a11marker() { axw; seed_clean "$AXD"; seed_snapshot "$AXD" "$INFLIGHT_CLEAN"; seed_marker "$AXD"; axl a11marker
  drive "$AXL" "$(vtool "$1")" "$AXD" --warn-only
  [ "$(status_of "$AXL")" = 0 ] && has 'WARN: pipeline-snapshot.md marks superseded content in place.' \
    && has 'WARN  this run reported superseded content marked in place and is NOT a clean result.' && ! has "$PASS_LINE"; }
# the stamp arms: one snapshot line, driven with now pinned. farm_ok = accepted (rc 0, no FUTURE row).
farm_ok() { axw; seed_clean "$AXD"; seed_stamped "$AXD" "$2" "$IF_HDR"; axl "$3"
  drive_now "$AXL" "$(vtool "$1")" "$AXD" --only pipeline-snapshot.md
  [ "$(status_of "$AXL")" = 0 ] && ! grep -q '^FUTURE ' "$OUT"; }
arm_f_five() { farm_ok "$1" '- 2026-10-14T11:05Z five minutes ahead' f_five; }
arm_f_range() { farm_ok "$1" '- 2026-10-14T09:55-10:45Z window, and 2026-10-14T12:00Z-12:45Z planned' f_range; }
arm_f_spaced() { farm_ok "$1" '- 2026-10-14T12:00Z - 12:45Z, 2026-10-14T12:00Z to 12:45Z, 2026-10-14T12:00Z → 12:45Z, 2026-10-14T12:00Z – 12:45Z planned' f_spaced; }
arm_f_past() { farm_ok "$1" '- 2026-10-14T10:59Z just now' f_past; }
arm_f_dash() { axw; seed_clean "$AXD"; seed_stamped "$AXD" '- 2026-10-14T12:00Z - DEPLOY DONE' "$IF_HDR"; axl f_dash
  drive_now "$AXL" "$(vtool "$1")" "$AXD" --only pipeline-snapshot.md
  [ "$(status_of "$AXL")" = 1 ] && grep -q '^FUTURE .*2026-10-14T12:00Z' "$OUT"; }
arm_f_history() { axw; seed_clean "$AXD"; seed_stamped "$AXD" '- nothing notable' "$IF_HDR"
  printf '## Recent Activity\n- 2026-12-01T00:00Z archived future line\n' > "$AXD/_bmad-output/pipeline-snapshot-history.md"
  axl f_history; drive_now "$AXL" "$(vtool "$1")" "$AXD" --only pipeline-snapshot.md
  [ "$(status_of "$AXL")" = 0 ]; }
arm_f8() { axw; AW="$AXD"; seed_breach "$AW"
  seed_stamped "$AW" '- 2026-10-14T12:00Z DEPLOY DONE
- 2026-10-14T12:05Z MERGED
- 2026-10-14T12:10Z HANDOFF
- 2026-10-14T12:15Z DISPATCHED dev
- 2026-10-14T12:20Z GATE PASS' "$IF_HDR"
  axl f8; wdrive "$AXL" "$2" "$1"; wcheck "$AXL"; }
arm_f9() { axw; AB="$AXD"; seed_clean "$AB"
  seed_stamped "$AB" '- 2026-10-14T12:00Z DEPLOY DONE' "$IF_HDR
fold | pm-escalated | d1 | 2026-10-14T10:15:40Z | in-flight"
  printf '{"ts":"2026-10-14T10:17:32Z","name":"pm-escalated","role":"pm"}\n' > "$AB/_bmad-output/spawn-ledger.jsonl"
  axl f9; BDIR="$1"; bdrive "$AXL" "$2"; BDIR=""; bcheck "$AXL"; }
pool_world() { axw; seed_clean "$AXD"; mkdir -p "$AXD/_bmad-output/planning-artifacts" || exit 2
  head -c 300000 /dev/zero | tr '\0' 'x' > "$AXD/_bmad-output/planning-artifacts/prd.md"
  printf '# Carry-over backlog\n### CO-S1-OTHER\n**Status:** OPEN\nunrelated\n### CO-S1-WHOLE-READ-POOL-OLD\n**Status:** CLOSED\nold breach\n' \
    > "$AXD/_bmad-output/planning-artifacts/carry-over-backlog.md"; }
arm_p_basename() { pool_world; axl p_basename
  AI_DLC_READER_WINDOW_TOKENS=200000 drive "$AXL" "$(vtool "$1")" "$AXD" --warn-only --fail-on WHOLE-READ
  [ "$(status_of "$AXL")" = 0 ]; }
arm_p_noitem() { pool_world; axl p_noitem
  AI_DLC_READER_WINDOW_TOKENS=200000 drive "$AXL" "$(vtool "$1")" "$AXD" --warn-only --fail-on whole-read-pool
  [ "$(status_of "$AXL")" = 1 ] && grep -q 'no OPEN carry-over item cites it' "$OUT"; }
# the LATE arms
arm_l1b() { late_world "lx$AXC" "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:01:00Z | in-flight
$DECO | remediator | r2 | 2026-10-14T10:01:00Z | in-flight
a1111111111111111 | dev | d1 | 2026-10-14T10:30Z | in-flight
a1111111111111111 | dev | d2 | 2026-10-14T10:27:45Z | in-flight
toolu_01LateSubjectBBBBBBBBB | remediator | r3 | 2026-10-14T10:01:00Z | in-flight"
  axl l1b; ldrive "$AXL" "$(vtool "$1")" "$LW"
  [ "$(status_of "$AXL")" = 1 ] && grep -qF "$LATE_HEAD" "$(lout "$AXL")" && [ "$(nlate "$AXL")" = 5 ] \
    && haslate "$AXL" 14 a7ffc8dcd555207b8 2026-10-14T10:01:00Z 2026-10-14T10:00:03Z \
    && haslate "$AXL" 17 a1111111111111111 2026-10-14T10:27:45Z 2026-10-14T10:27:46Z && ! grep -q '^BACKDATED ' "$(lout "$AXL")"; }
arm_l0eq() { late_world "lx$AXC" "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:00:03Z | in-flight
$DECO | remediator | r2 | 2026-10-14T10:00:03Z | in-flight
toolu_01LateSubjectBBBBBBBBB | remediator | r3 | 2026-10-14T10:00:03Z | in-flight"
  axl l0eq; ldrive "$AXL" "$(vtool "$1")" "$LW"
  [ "$(status_of "$AXL")" = 0 ] && [ "$(nlate "$AXL")" = 0 ] && grep -qxF "$PASS_LINE" "$(lout "$AXL")" && ! grep -q 'not judged for LATE' "$(lout "$AXL")"; }
arm_le_skip() { late_world "lx$AXC" "fold-x | pm | p1 | 2026-10-14T10:00:03Z | in-flight
afffffffffffffff0 | qa | q1 | 2026-10-14T10:00:03Z | in-flight
fix (commit 1a2b3c4d) | qa | q2 | 2026-10-14T10:00:03Z | in-flight
a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:09:00Z | delivered-reachable
a7ffc8dcd555207b8 | remediator | r2 | 2026-10-14T10:09:00Z | stopped
a7ffc8dcd555207b8 | remediator | r3 | 2026-10-14T10:00:03Z | in-flight"
  axl le_skip; ldrive "$AXL" "$(vtool "$1")" "$LW"
  [ "$(status_of "$AXL")" = 0 ] && grep -qxF "$LSKIP" "$(lout "$AXL")" && [ "$(nlate "$AXL")" = 0 ]; }
arm_la_amb() { late_world "lx$AXC" "remediator (a7ffc8dcd555207b8 then a1111111111111111) | remediator | r1 | 2026-10-14T10:27:46Z | in-flight"
  axl la_amb; ldrive "$AXL" "$(vtool "$1")" "$LW"
  [ "$(status_of "$AXL")" = 0 ] && grep -qxF "$LAMB" "$(lout "$AXL")" && [ "$(nlate "$AXL")" = 0 ]; }
arm_ls_same() { late_world "lx$AXC" "$LSCELL | remediator | r1 | 2026-10-14T10:01:00Z | in-flight"
  axl ls_same; ldrive "$AXL" "$(vtool "$1")" "$LW"
  [ "$(status_of "$AXL")" = 1 ] && [ "$(nlate "$AXL")" = 1 ] \
    && haslate "$AXL" 14 a7ffc8dcd555207b8 2026-10-14T10:01:00Z 2026-10-14T10:00:03Z && ! grep -q 'ambiguous agent cell' "$(lout "$AXL")"; }
arm_lh_clear() { AXC=$((AXC + 1)); late_clear "lc$AXC" "$(vtool "$1")"
  [ "$LH_FIRST" = 2 ] && [ "$(status_of "lc$AXC-1")" = 1 ] && [ "$LH_CHANGED" = 1 ] && [ "$LH_SECOND" = 0 ] \
    && [ "$(status_of "lc$AXC-2")" = 0 ] && ! grep -qF "$LATE_HEAD" "$(lout "lc$AXC-2")"; }
arm_lg() { late_world "lx$AXC" "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:01:00Z | in-flight"
  LGW="$LW"; axl lg; gdrive "$AXL" "$2"; gcheck "$AXL"; }
arm_vs() { late_world "lx$AXC" "fold-x | pm | p1 | 2026-10-14T10:00:03Z | in-flight"
  axl vs; vdrive "$AXL" "$2" "$LW"
  [ "$(status_of "$AXL")" = 0 ] && grep -qxF 'PASS  validate-artifact-budget.sh' "$WORK/runs/$AXL.out" && vline "$AXL" "$VSKIP" && ! vmore "$AXL"; }
vt_rows() { local n="$1" i=1 rows=""
  while [ "$i" -le "$n" ]; do rows="${rows}${rows:+
}a7ffc8dcd555207b8 | remediator | r$i | 2026-10-14T10:0$i:00Z | in-flight"; i=$((i + 1)); done
  printf '%s' "$rows"; }
arm_vt_more() { late_world "lx$AXC" "$(vt_rows 8)"; local vw="$LW" d v n
  axl vtd; d="$AXL"; ldrive "$d" "$(vtool "$1")" "$vw"; n=$(( $(vmatched "$d") - 6 ))
  axl vtm; v="$AXL"; vdrive "$v" "$2" "$vw"
  [ "$(nlate "$d")" = 8 ] && [ "$n" -gt 0 ] && [ "$(status_of "$v")" = 1 ] && [ "$(vshown "$v")" = 6 ] \
    && grep -qxF "      … $n more matching line(s); run scripts/ai-dlc/validate-artifact-budget.sh directly for all" "$WORK/runs/$v.out"; }
arm_vt_under() { late_world "lx$AXC" "$(vt_rows 5)"; local vw="$LW" d v
  axl vud; d="$AXL"; ldrive "$d" "$(vtool "$1")" "$vw"
  axl vuu; v="$AXL"; vdrive "$v" "$2" "$vw"
  [ "$(vmatched "$d")" = 6 ] && [ "$(status_of "$v")" = 1 ] && [ "$(vshown "$v")" = 6 ] && ! vmore "$v"; }

# --- 1, 3, 4, 5, 6, 10, 11. THE BASE: each arm on the UNMUTATED validator, in this run. ----------
# The mutant block below scores its mutants on these same arm functions, and a kill is emitted only
# behind the flag set here. Arm 1 is the run that filed the defect (--warn-only over an unhardened
# breach); 3 the blocking posture; 4 the byte-identical PASS line in both drive modes; 5 the coverage
# qualifier and its control; 6 the schema channel; 10 the struck row under retro's literal flags; 11 the
# superseded marker under --warn-only.
for _a in a1warn a3noflag a4clean a5cov a6schema a10struck a11marker; do
  if "arm_$_a" "$VD" "$VW"; then ok "[$_a] the unmutated validator holds this arm"; eval "B_$_a=1"
  else bad "[$_a] the unmutated validator tripped this arm: exit $(status_of "$AXL")"; sed 's/^/      /' "$OUT" >&2; fi
done
# The same seed under retro's flags is the hardened posture, and it must NOT move: a FAIL,
A11="$(arm_dir marker)"; seed_clean "$A11"
seed_snapshot "$A11" "$INFLIGHT_CLEAN"; seed_marker "$A11"
# RC=1, and the summary block unreached. A fix that flagged the channel by softening the
# hardening would pass arm 11 and fail here.
# shellcheck disable=SC2086
drive marker-retro "$V" "$A11" $RETRO_FLAGS
if [ "$(status_of marker-retro)" = "1" ] \
   && has 'FAIL: pipeline-snapshot.md marks superseded content in place.' \
   && ! has "$PASS_LINE" && ! grep -q '^WARN  this run' "$OUT"; then
  ok "  and under retro's flags the same marker still FAILs with exit 1 and reaches no summary"
else
  bad "  superseded marker under retro's flags: exit $(status_of marker-retro), the hardened FAIL moved"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi
# THE NEAR-MISSES, one per channel, each carrying the token the channel keys on. A `~~`
# strike OUTSIDE the dispatch ledger is out of scope by default, and lowercase
# "superseded" is ordinary prose. Both must leave the bare PASS line intact under retro's
# flags -- otherwise arms 10 and 11 are satisfied by a summary that qualifies everything.
A12="$(arm_dir nearmiss)"; seed_clean "$A12"
seed_snapshot "$A12" "$INFLIGHT_CLEAN"
printf -- '- ~~an old entry~~ superseded by the short form\n' >> "$A12/_bmad-output/pipeline-snapshot.md"
# shellcheck disable=SC2086
drive nearmiss-retro "$V" "$A12" $RETRO_FLAGS
if [ "$(status_of nearmiss-retro)" = "0" ] && has "$PASS_LINE" && ! grep -q '^WARN' "$OUT"; then
  ok "  near-miss: an out-of-ledger strike and lowercase 'superseded' leave the bare PASS line under retro's flags"
else
  bad "  near-miss: exit $(status_of nearmiss-retro), a WARN appeared or the PASS line moved on a snapshot neither channel covers"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi

# --- 13. ALL FIVE MEASURED-ARTIFACT CHANNELS AT ONCE, in block order ------------------
A13="$(arm_dir combined5)"; seed_breach "$A13"
seed_snapshot "$A13" "$INFLIGHT_STRUCK
| dev-b | story-2 | 2026-01-01 | none | finished |"
printf '\n## Invented Section\n- lead invention\n' >> "$A13/_bmad-output/pipeline-snapshot.md"
seed_marker "$A13"
drive combined5-warnonly "$V" "$A13" --warn-only
if [ "$(status_of combined5-warnonly)" = "0" ] \
   && has 'WARN  this run reported over-budget artifact(s), off-schema section(s), superseded content marked in place, struck-through In-Flight row(s), unrecognised In-Flight status row(s) and is NOT a clean result.'; then
  ok "five channels in one --warn-only run are all enumerated in one summary line"
else
  bad "five-channel --warn-only run: exit $(status_of combined5-warnonly), the summary did not enumerate all five"
  grep -E '^WARN  this run' "$OUT" | sed 's/^/      /' >&2
fi
# --- 9. THE FILED DEFECT, AS A JOIN OVER EVERY RUN ABOVE ------------------------------
# PC-S303-BUDGET-SCRIPT-PASS-LINE-UNCONDITIONAL is a CO-OCCURRENCE: one run that printed
# an OVER row and also printed the unqualified PASS line. Arms 1-3 and 8 each assert
# their own message; this asserts the pair, over every row the ledger holds, including
# the ones whose expected text this fixture never states.
#
# BOTH CONTROLS ARE LOAD-BEARING. A join over a ledger with no breaching run passes
# without observing anything, and a join whose PASS-line detector never matches passes
# the same way. The two controls below are the difference between "no violation" and
# "nothing was looked at".
#
# THE PREDICATE IS A FUNCTION, AND M1 BELOW CALLS THE SAME ONE. An absence-shaped arm
# needs a mutant, and a mutant that is scored by a hand-written second copy of the
# predicate proves the copy, not the arm. `join_violations` is the only implementation.
join_violations() { # join_violations [label-filter]  -> prints violating labels
  awk -F'\t' -v want="${1:-}" '$3==1 && $4==1 && (want=="" || $1==want) {print $1}' "$LEDGER"
}
n_breach="$(awk -F'\t' '$3==1' "$LEDGER" | wc -l | tr -d ' ')"
n_pass="$(awk -F'\t' '$4==1' "$LEDGER" | wc -l | tr -d ' ')"
viol="$(join_violations)"
if [ "$n_breach" -lt 3 ]; then
  bad "JOIN CONTROL: only $n_breach run(s) in the ledger reported an OVER row -- the join is near-vacuous"
elif [ "$n_pass" -lt 2 ]; then
  bad "JOIN CONTROL: only $n_pass run(s) printed the PASS line -- the detector cannot fire"
elif [ -n "$viol" ]; then
  bad "a run reported a breach AND printed the unqualified PASS line: $(printf '%s' "$viol" | tr '\n' ' ')"
else
  ok "JOIN: across $n_breach breaching and $n_pass passing runs, none did both (PC-S303)"
fi
# =====================================================================================
# BL-517 -- THE FUTURE-STAMP VERDICT, and BL-511 -- THE POOL'S RETRO VERDICT.
#
# NOW IS PINNED through AI_DLC_SNAPSHOT_NOW_EPOCH (set per drive, after the scrub above),
# to 2026-10-14T11:00:00Z = 1791975600, so no arm depends on the host clock.
# =====================================================================================
NOW_PIN=1791975600
IF_HDR='agent | role | deliverable | dispatched-at | status
--- | --- | --- | --- | ---'
seed_stamped() { # seed_stamped <dir> <recent-activity line> <in-flight body>
  printf '## Pipeline Position\n- at retro since 2026-10-14T23:00Z (mid-line, not checked)\n## Sprint Context\n- sprint 1\n## Recent Activity\n%s\n## Open Items\n- none\n## Locked Decisions\n- keep the threshold\n## In-Flight Teammates\n%s\n## Context Reminders\n- keep it small\n' \
    "$2" "$3" > "$1/_bmad-output/pipeline-snapshot.md"
}
drive_now() { # drive_now <label> <script> <root> [args...]  -- drive with now pinned
  _l="$1"; shift
  AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW_PIN" drive "$_l" "$@"
}

# --- F1-F6. ONE offender and five near-misses, each its own tree and its own run ------
# F1 offender (60 min ahead, Recent Activity) -> refused, rc 1, the remedy is printed.
AF="$(arm_dir future)"; seed_clean "$AF"
seed_stamped "$AF" '- 2026-10-14T12:00Z DEPLOY DONE' "$IF_HDR"
drive_now future-ra "$V" "$AF" --only pipeline-snapshot.md
if [ "$(status_of future-ra)" = "1" ] && hasl 'FUTURE  _bmad-output/pipeline-snapshot.md line 6: 2026-10-14T12:00Z is 60 min ahead' \
   && hasl 'CLOCK CORRECTION'; then
  ok "F1 a Recent Activity stamp 60 min ahead is refused (rc 1) and the CLOCK CORRECTION remedy is named"
else
  bad "F1 future Recent Activity stamp: exit $(status_of future-ra), FUTURE row or remedy missing"
  sed 's/^/      /' "$OUT" >&2
fi
# F1b the same offender in a dispatched-at CELL, and a future `since` in the STATUS cell
# beside a past dispatched-at (the latter must stay quiet: only the declared column is read).
seed_stamped "$AF" '- nothing notable' "$IF_HDR
dev-a | dev | s1 | 2026-10-14T12:00Z | in-flight"
drive_now future-if "$V" "$AF" --only pipeline-snapshot.md
f1b=0; [ "$(status_of future-if)" = "1" ] && hasl '(In-Flight Teammates dispatched-at)' && f1b=1
seed_stamped "$AF" '- nothing notable' "$IF_HDR
dev-a | dev | s1 | 2026-10-14T10:00Z | in-flight, since 2026-10-14T23:00Z"
drive_now future-status "$V" "$AF" --only pipeline-snapshot.md
if [ "$f1b" -eq 1 ] && [ "$(status_of future-status)" = "0" ]; then
  ok "F1b a future dispatched-at cell is refused; a future 'since' in the status cell is not read"
else
  bad "F1b dispatched-at=$(status_of future-if) (want 1), status-cell since=$(status_of future-status) (want 0)"
fi
# F2-F6 near-misses, one property each: rc 0 and no FUTURE row.
nm_ok=1
while IFS='|' read -r nlabel nline; do
  [ -n "$nlabel" ] || continue
  seed_stamped "$AF" "$nline" "$IF_HDR"
  drive_now "nm-$nlabel" "$V" "$AF" --only pipeline-snapshot.md
  if [ "$(status_of "nm-$nlabel")" != "0" ] || grep -q '^FUTURE ' "$OUT"; then
    nm_ok=0; bad "near-miss '$nlabel' was refused: $(grep '^FUTURE ' "$OUT" | head -1)"
  else
    eval "B_f_$nlabel=1"
  fi
done <<'NEAR'
range|- 2026-10-14T09:55-10:45Z window, and 2026-10-14T12:00Z-12:45Z planned
dateonly|- 2026-10-15 tomorrow
xplace|- 2026-10-14Txx:xxZ placeholder and ~2026-10-14T13:00Z approx
five|- 2026-10-14T11:05Z five minutes ahead
past|- 2026-10-14T10:59Z just now
spaced|- 2026-10-14T12:00Z - 12:45Z, 2026-10-14T12:00Z to 12:45Z, 2026-10-14T12:00Z → 12:45Z, 2026-10-14T12:00Z – 12:45Z planned
correction|- 2026-10-14T10:58Z CLOCK CORRECTION: rewrote 2 future stamp(s) to date -u: 12:00Z, 12:45Z
fulliso|- 2026-10-14T10:58Z CLOCK CORRECTION: rewrote 1 future stamp(s) to date -u: 2026-10-14T12:00Z
deadline|- 2026-10-14T10:59Z operator set the monitor deadline 2026-10-21T16:08:54Z
NEAR
[ "$nm_ok" -eq 1 ] && ok "F2-F6 range, spaced range, date-only, x/~ placeholder, 5-min-ahead, past, bare-HH:MMZ and full-ISO CLOCK CORRECTION, and a body deadline on a stamp-led line are all accepted"

# F1c OFFENDER TWINS of near-misses above, each one property apart: a single stamp followed
# by ` - ` and TEXT (the spaced-range skip needs a digit); a stamp MID-LINE in a line with no
# leading stamp, which is read whole because the legacy `gate PASSED -- <stamp>` form puts the
# entry stamp last; a full-ISO CLOCK CORRECTION body with NO leading stamp of its own (twin of
# `fulliso`); and a FUTURE leading stamp beside a body deadline (twin of `deadline`).
f1c_ok=1
while IFS='|' read -r olabel oline; do
  [ -n "$olabel" ] || continue
  seed_stamped "$AF" "$oline" "$IF_HDR"
  drive_now "off-$olabel" "$V" "$AF" --only pipeline-snapshot.md
  if [ "$(status_of "off-$olabel")" != "1" ] || ! grep -q '^FUTURE .*2026-10-14T12:00Z' "$OUT"; then
    f1c_ok=0; bad "offender twin '$olabel' was accepted: exit $(status_of "off-$olabel")"
  elif [ "$olabel" = dashtext ]; then
    B_f_dash=1
  fi
done <<'OFF'
dashtext|- 2026-10-14T12:00Z - DEPLOY DONE
midline|- DEPLOY DONE at 2026-10-14T12:00Z
fullisonolead|- CLOCK CORRECTION: rewrote 1 future stamp(s) to date -u: 2026-10-14T12:00Z
leaddeadline|- 2026-10-14T12:00Z DONE, operator deadline 2026-10-21T16:08:54Z
OFF
[ "$f1c_ok" -eq 1 ] && ok "F1c ' - text', a mid-line stamp, a full-ISO CLOCK CORRECTION line with no leading stamp, and a future leading stamp beside a body deadline are each refused"
# F8 THROUGH verdict.sh, WITH A CO-OCCURRING BUDGET OVER. Every lead-facing call site reads this
# validator through the wrapper, which shows at most 6 matching lines. Five future stamps plus a
# gate-log breach: printed after the budget verdict, the stamp FAIL line and its rows fall past
# the cap; printed first, the wrapper shows the FAIL line carrying the remedy and every row.
AW="$(arm_dir wrapper)"; seed_breach "$AW"
seed_stamped "$AW" '- 2026-10-14T12:00Z DEPLOY DONE
- 2026-10-14T12:05Z MERGED
- 2026-10-14T12:10Z HANDOFF
- 2026-10-14T12:15Z DISPATCHED dev
- 2026-10-14T12:20Z GATE PASS' "$IF_HDR"
wdrive() { # wdrive <label> <wrapper> <validator-dir>
  OUT="$WORK/runs/$1.out"
  ( cd "$AW" && AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW_PIN" AI_DLC_SCRIPTS_DIR="$3" \
      bash "$2" validate-artifact-budget --root "$AW" ) > "$OUT" 2>&1
  printf '%s\t%s\t0\t0\n' "$1" "$?" >> "$LEDGER"
}
wcheck() { # wcheck <label> -> 0 when the wrapper output carries the remedy and all five rows
  _o="$WORK/runs/$1.out"
  [ "$(status_of "$1")" = "1" ] || return 1
  grep -q 'FAIL: pipeline-snapshot.md carries stamp(s) later than the current UTC time -- rewrite each FUTURE stamp' "$_o" || return 1
  grep -q 'CLOCK CORRECTION: rewrote <n> future stamp(s) to date -u: <old stamps as bare HH:MMZ>' "$_o" || return 1
  [ "$(grep -c 'FUTURE  _bmad-output/pipeline-snapshot.md line' "$_o")" = "5" ] || return 1
  grep -q 'OVER  ' "$_o" && return 1   # the cap is spent on the stamp verdict: proves co-occurrence was cut, not absent
  return 0
}
wdrive f8 "$VW" "$(dirname "$V")"
if wcheck f8; then
  ok "F8 through verdict.sh under a co-occurring OVER: the stamp FAIL line carries the remedy and all 5 FUTURE rows survive the 6-line cap"; B_f8=1
else
  bad "F8 through verdict.sh: stamp remedy or FUTURE rows missing (exit $(status_of f8))"
  sed 's/^/      /' "$WORK/runs/f8.out" >&2
fi
# F8 control: the raw validator on the same tree reports the breach too, so the OVER absent above
# was cut by the cap and not missing from the run.
drive_now f8-raw "$V" "$AW"
grep -q '^OVER  ' "$WORK/runs/f8-raw.out" && grep -q '^FUTURE ' "$WORK/runs/f8-raw.out" \
  && ok "F8 control: the raw run carries both the OVER row and the FUTURE rows" \
  || bad "F8 control: the raw run lacks the OVER row or the FUTURE rows -- F8 is not testing co-occurrence"

# F7 posture: --warn-only alone warns (rc 0, summary names it); retro's flags harden it.
seed_stamped "$AF" '- 2026-10-14T12:00Z DEPLOY DONE' "$IF_HDR"
drive_now future-warn "$V" "$AF" --warn-only
drive_now future-retro "$V" "$AF" --warn-only --fail-on pipeline-snapshot.md
if [ "$(status_of future-warn)" = "0" ] \
   && grep -q 'WARN  this run reported future-stamped snapshot entr(ies)' "$WORK/runs/future-warn.out" \
   && [ "$(status_of future-retro)" = "1" ]; then
  ok "F7 --warn-only reports the stamp in the summary (rc 0); --fail-on pipeline-snapshot.md blocks (rc 1)"
else
  bad "F7 warn-only=$(status_of future-warn) (want 0 + summary), retro=$(status_of future-retro) (want 1)"
fi

# --- P1-P4. THE POOL'S RETRO VERDICT -------------------------------------------------
# 300,000 bytes of prd.md is 75,000 tok against a 66,000 pool (200K window pinned), past
# the 72,600 ceiling. The backlog is varied; the pool is not.
AP="$(arm_dir pool)"; seed_clean "$AP"
mkdir -p "$AP/_bmad-output/planning-artifacts" || exit 2
head -c 300000 /dev/zero | tr '\0' 'x' > "$AP/_bmad-output/planning-artifacts/prd.md"
BL="$AP/_bmad-output/planning-artifacts/carry-over-backlog.md"
pool_drive() { AI_DLC_READER_WINDOW_TOKENS=200000 drive "$@"; }
printf '# Carry-over backlog\n### CO-S1-OTHER\n**Status:** OPEN\nunrelated\n### CO-S1-WHOLE-READ-POOL-OLD\n**Status:** CLOSED\nold breach\n' > "$BL"
pool_drive pool-warn "$V" "$AP" --warn-only
pool_drive pool-basename "$V" "$AP" --warn-only --fail-on WHOLE-READ
pool_drive pool-noitem "$V" "$AP" --warn-only --fail-on whole-read-pool
p_seed=0; grep -q '^OVER  WHOLE-READ POOL' "$WORK/runs/pool-warn.out" && p_seed=1
if [ "$p_seed" -ne 1 ]; then
  echo "FIXTURE ERROR: the 300000-byte prd.md was not reported as an OVER pool row" >&2; exit 2
fi
if [ "$(status_of pool-warn)" = "0" ] && [ "$(status_of pool-basename)" = "0" ]; then
  ok "P1 an over pool under --warn-only, and under --fail-on WHOLE-READ (a label word, not the token), stays rc 0"; B_p_basename=1
else
  bad "P1 warn-only=$(status_of pool-warn), --fail-on WHOLE-READ=$(status_of pool-basename) (want 0 and 0)"
fi
if [ "$(status_of pool-noitem)" = "1" ] && grep -q 'no OPEN carry-over item cites it' "$WORK/runs/pool-noitem.out"; then
  ok "P2 --fail-on whole-read-pool with no OPEN citing item (an OPEN non-citing and a CLOSED citing one present) is rc 1"; B_p_noitem=1
else
  bad "P2 pool with no OPEN citing item: exit $(status_of pool-noitem) (want 1 and the remedy)"
fi
printf '### CO-S1-POOL-OVER pool 75000 tok\n**Filed:** retro. **Status:** OPEN.\nWHOLE-READ-POOL over; artifact-consolidation.md owed before route.\n' >> "$BL"
pool_drive pool-item "$V" "$AP" --warn-only --fail-on whole-read-pool
if [ "$(status_of pool-item)" = "0" ] && grep -q 'pool breach recorded: OPEN carry-over item ### CO-S1-POOL-OVER' "$WORK/runs/pool-item.out"; then
  ok "P3 the same run with an OPEN item citing WHOLE-READ-POOL is rc 0 and names the item"
else
  bad "P3 pool with an OPEN citing item: exit $(status_of pool-item) (want 0 + recorded line)"
fi
# F9 BACKDATED THROUGH verdict.sh. The FAIL line says "re-stamp each row below"; the wrapper
# must surface the row it names, alongside a co-firing FUTURE row, within its 6-line cap.
AB="$(arm_dir backdated)"; seed_clean "$AB"
seed_stamped "$AB" '- 2026-10-14T12:00Z DEPLOY DONE' "$IF_HDR
fold | pm-escalated | d1 | 2026-10-14T10:15:40Z | in-flight"
printf '{"ts":"2026-10-14T10:17:32Z","name":"pm-escalated","role":"pm"}\n' > "$AB/_bmad-output/spawn-ledger.jsonl"
bdrive() { # bdrive <label> <wrapper>
  OUT="$WORK/runs/$1.out"
  ( cd "$AB" && AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW_PIN" AI_DLC_SCRIPTS_DIR="${BDIR:-$(dirname "$V")}" \
      bash "$2" validate-artifact-budget --root "$AB" ) > "$OUT" 2>&1
  printf '%s\t%s\t0\t0\n' "$1" "$?" >> "$LEDGER"
}
bcheck() { # bcheck <label> -> 0 when the wrapper shows the BACKDATED headline AND its row
  _o="$WORK/runs/$1.out"
  [ "$(status_of "$1")" = "1" ] || return 1
  grep -q 'FAIL: pipeline-snapshot.md carries an in-flight dispatched-at earlier than its dispatch' "$_o" || return 1
  grep -q 'BACKDATED .*pm-escalated dispatched-at 2026-10-14T10:15:40Z is 112 s' "$_o" || return 1
  grep -q 'FUTURE .*2026-10-14T12:00Z' "$_o"
}
bdrive backdated "$VW"
if bcheck backdated; then
  ok "F9 a back-dated in-flight row is refused through verdict.sh, its row and a co-firing FUTURE row both shown"; B_f9=1
else
  bad "F9 back-dated row through verdict.sh: exit $(status_of backdated), headline, row or FUTURE row missing"
  sed 's/^/      /' "$WORK/runs/backdated.out" >&2
fi
# =====================================================================================
# L. THE LATE ARM (check_late_dispatch): an in-flight dispatched-at that is not its OWN
# dispatch's spawn-ledger ts. The validator resolves each candidate token of the agent cell
# through the SIBLING wait-for-deliverable.sh --dispatch-ts, so those siblings must sit beside
# it; their absence is a broken fixture, never a pass. Every world seeds the producer's shapes:
# a compact ledger row as the dispatch guard writes it (an epoch row first, so the subject is not
# the earliest), and a subagents-dir agent-<id>.meta.json carrying the dispatch's tool_use_id.
# Now is pinned (NOW_PIN, 11:00:00Z), so no stamp below is FUTURE.
# =====================================================================================
unset CLAUDE_CODE_SESSION_ID
VD="$(dirname "$V")"
for _s in wait-for-deliverable.sh validate-adversarial-convergence.sh; do
  [ -f "$VD/$_s" ] || { echo "FIXTURE ERROR: the LATE arms need $_s beside $V" >&2; exit 2; }
done
echo "HERMETIC-CONSUMED core/scripts/wait-for-deliverable.sh"
echo "HERMETIC-CONSUMED core/scripts/validate-adversarial-convergence.sh"
# THE FORK COUNTER. A `bash` shim first on PATH logs every `bash .../wait-for-deliverable.sh
# --dispatch-ts <tok>` as `<AI_DLC_STATE_DIR>\t<tok>` and execs the real bash, so a change in the
# arm's cost is an assertion, not a guess. The self-probe's calls carry its own state dir
# (`.../probe-late/state`), which is how they are told apart from a world's.
REALBASH="$(command -v bash)" || { echo "FIXTURE ERROR: no bash on PATH" >&2; exit 2; }
SHIM="$WORK/shim"; FORKLOG="$WORK/forks.log"; mkdir -p "$SHIM" || exit 2
{ printf '#!%s\n' "$REALBASH"
  printf 'FORKLOG=%q\nREALBASH=%q\n' "$FORKLOG" "$REALBASH"
  cat <<'SHIMEOF'
case "${1:-}" in */wait-for-deliverable.sh)
  [ "${2:-}" = --dispatch-ts ] && printf '%s\t%s\n' "${AI_DLC_STATE_DIR:-}" "${3:-}" >> "$FORKLOG" ;; esac
exec "$REALBASH" "$@"
SHIMEOF
} > "$SHIM/bash" && chmod +x "$SHIM/bash" || { echo "FIXTURE ERROR: cannot write the bash shim" >&2; exit 2; }
forks_world() { # forks_world <arm name> -> resolver calls made for that world's state dir
  awk -F'\t' -v s="/$1/_bmad-output" 'substr($1, length($1) - length(s) + 1) == s { n++ } END { print n + 0 }' "$FORKLOG" 2>/dev/null || echo 0
}
forks_probe() { awk -F'\t' '$1 ~ /\/probe-late\/state$/ { n++ } END { print n + 0 }' "$FORKLOG" 2>/dev/null || echo 0; }

LH='agent | role | deliverable | dispatched-at | status
--- | --- | --- | --- | ---'
late_world() { # late_world <name> <in-flight rows> -> sets LW; ledger + meta seeded beside it
  LW="$(arm_dir "$1")"; seed_clean "$LW"
  seed_stamped "$LW" '- nothing notable' "$LH
$2"
  printf '%s\n' \
    '{"ts":"2026-10-14T09:58:41Z","name":"arch-epoch","role":"architect","tool_use_id":"toolu_01LateEpochRowAAAAAAAAA"}' \
    '{"ts":"2026-10-14T10:00:03Z","name":"","role":"remediator","tool_use_id":"toolu_01LateSubjectBBBBBBBBB"}' \
    '{"ts":"2026-10-14T10:27:46Z","name":"","role":"dev","tool_use_id":"toolu_01LateMinuteCCCCCCCCC"}' \
    > "$LW/_bmad-output/spawn-ledger.jsonl"
  mkdir -p "$LW/sub" || exit 2
  printf '{"agentType":"remediator","toolUseId":"toolu_01LateSubjectBBBBBBBBB"}\n' > "$LW/sub/agent-a7ffc8dcd555207b8.meta.json"
  printf '{"agentType":"dev","toolUseId":"toolu_01LateMinuteCCCCCCCCC"}\n' > "$LW/sub/agent-a1111111111111111.meta.json"
}
ldrive() { # ldrive <label> <validator> <world> [args...] -- the gate, teammate dir set, forks counted
  _ll="$1"; _lv="$2"; _lw="$3"; shift 3
  AI_DLC_TEAMMATE_DIR="$_lw/sub" PATH="$SHIM:$PATH" drive_now "$_ll" "$_lv" "$_lw" --only pipeline-snapshot.md "$@"
}
lout() { printf '%s' "$WORK/runs/$1.out"; }
nlate() { _n="$(grep -c '^LATE ' "$(lout "$1")")" || _n=0; printf '%s' "$_n"; }
haslate() { # haslate <label> <line> <id> <stamp> <ts> -> the exact LATE line is in the run
  grep -qxF "LATE  _bmad-output/pipeline-snapshot.md line $2: $3 dispatched-at $4 is not its dispatch's ledger ts $5" "$(lout "$1")"
}
LATE_HEAD="FAIL: pipeline-snapshot.md carries an in-flight dispatched-at that is not its dispatch's ledger ts"
DECO='remediator (serial, pass 1 cross-part, a7ffc8dcd555207b8)'

# --- L1. Offenders, one world, one row per shape, each named by its line (14-18) ---------------
#   14 (a)  a bare agentId stamped 57 s after its dispatch
#   15 (i1) the motivating decorated cell, the same 57 s, named by its one resolving id
#   16 (c)  minute-only 10:30Z against 10:27:46Z
#   17 (b') 1 s EARLY: inside BACKDATED's tolerance, so only LATE can see it
#   18 (d)  the toolu_ spelling of 14's dispatch: the same ledger ts
late_world late-off "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:01:00Z | in-flight
$DECO | remediator | r2 | 2026-10-14T10:01:00Z | in-flight
a1111111111111111 | dev | d1 | 2026-10-14T10:30Z | in-flight
a1111111111111111 | dev | d2 | 2026-10-14T10:27:45Z | in-flight
toolu_01LateSubjectBBBBBBBBB | remediator | r3 | 2026-10-14T10:01:00Z | in-flight"
L1W="$LW"
ldrive late-off "$V" "$L1W"
if [ "$(status_of late-off)" = 1 ] && grep -qF "$LATE_HEAD" "$(lout late-off)" && [ "$(nlate late-off)" = 5 ] \
   && haslate late-off 14 a7ffc8dcd555207b8 2026-10-14T10:01:00Z 2026-10-14T10:00:03Z; then
  ok "L1a a bare agentId stamped 57 s late is LATE at the gate (rc 1), named with its ledger ts"; B_l1a=1
else
  bad "L1a late bare agentId: exit $(status_of late-off), $(nlate late-off) LATE line(s) (want 1 and 5)"
  sed 's/^/      /' "$(lout late-off)" >&2
fi
haslate late-off 15 a7ffc8dcd555207b8 2026-10-14T10:01:00Z 2026-10-14T10:00:03Z \
  && ok "L1i1 the decorated motivating cell is LATE, and its line names the resolved id, not the cell" \
  || bad "L1i1 the decorated cell '$DECO' was not LATE by its one resolving id"
haslate late-off 16 a1111111111111111 2026-10-14T10:30Z 2026-10-14T10:27:46Z \
  && ok "L1c a minute-only 10:30Z against a 10:27:46Z dispatch is LATE" \
  || bad "L1c the minute-only stamp was not LATE"
if haslate late-off 17 a1111111111111111 2026-10-14T10:27:45Z 2026-10-14T10:27:46Z \
   && ! grep -q '^BACKDATED ' "$(lout late-off)"; then
  ok "L1b' a row 1 s EARLY is LATE while BACKDATED stays quiet (inside its tolerance)"; B_l1b="${B_l1a:-0}"
else
  bad "L1b' the 1 s early row: LATE missing, or BACKDATED fired: $(grep '^BACKDATED ' "$(lout late-off)" | head -1)"
fi
haslate late-off 18 toolu_01LateSubjectBBBBBBBBB 2026-10-14T10:01:00Z 2026-10-14T10:00:03Z \
  && ok "L1d a toolu_ cell resolves to the same ledger ts as its agentId" \
  || bad "L1d the toolu_ cell did not resolve to 10:00:03Z"

# --- L0 (b)/(i2). The same shapes stamped EQUAL to their ts: quiet, rc 0, nothing on the SKIP count.
late_world late-eq "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:00:03Z | in-flight
$DECO | remediator | r2 | 2026-10-14T10:00:03Z | in-flight
toolu_01LateSubjectBBBBBBBBB | remediator | r3 | 2026-10-14T10:00:03Z | in-flight"
ldrive late-eq "$V" "$LW"
if [ "$(status_of late-eq)" = 0 ] && [ "$(nlate late-eq)" = 0 ] && grep -qxF "$PASS_LINE" "$(lout late-eq)" \
   && ! grep -q 'not judged for LATE' "$(lout late-eq)"; then
  ok "L0 bare, decorated and toolu_ rows stamped equal to their ts are quiet (rc 0, PASS, every row judged)"; B_l0eq=1
else
  bad "L0 equal rows: exit $(status_of late-eq), $(nlate late-eq) LATE line(s), or a SKIP count (want 0, 0, none)"
  sed 's/^/      /' "$(lout late-eq)" >&2
fi

# --- LE (e)/(i4)/(f). Three unresolvable in-flight rows (a bare name, an agentId with no meta.json,
# a decorated cell whose only hex run is a commit sha), two LATE-stamped rows that are delivered
# and stopped, and one judged equal row. k = 3, not 1, so a hardcoded count cannot pass.
late_world late-skip "fold-x | pm | p1 | 2026-10-14T10:00:03Z | in-flight
afffffffffffffff0 | qa | q1 | 2026-10-14T10:00:03Z | in-flight
fix (commit 1a2b3c4d) | qa | q2 | 2026-10-14T10:00:03Z | in-flight
a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:09:00Z | delivered-reachable
a7ffc8dcd555207b8 | remediator | r2 | 2026-10-14T10:09:00Z | stopped
a7ffc8dcd555207b8 | remediator | r3 | 2026-10-14T10:00:03Z | in-flight"
LEW="$LW"
ldrive late-skip "$V" "$LEW"
LSKIP='SKIP  _bmad-output/pipeline-snapshot.md: 3 in-flight row(s) not judged for LATE (agent cell does not resolve in this session)'
if [ "$(status_of late-skip)" = 0 ] && grep -qxF "$LSKIP" "$(lout late-skip)" && [ "$(nlate late-skip)" = 0 ]; then
  ok "LE three unresolvable rows (bare name, no meta.json, a commit sha) print the SKIP count 3; delivered and stopped rows are not judged"; B_le_skip=1
else
  bad "LE skip world: exit $(status_of late-skip), $(nlate late-skip) LATE line(s); want rc 0, no LATE, and: $LSKIP"
  sed 's/^/      /' "$(lout late-skip)" >&2
fi

# --- LA (i3). A cell holding TWO resolvable ids of two DIFFERENT dispatches, stamped equal to the
# SECOND's ts: not judged, its own ambiguous SKIP line. A rule that took the first resolving id
# would read it LATE. The two seeded ts are read back from the ledger by each id's tool_use_id and
# asserted DIFFERENT by value, so this arm cannot decay into a same-dispatch pair (LS's shape).
late_world late-amb "remediator (a7ffc8dcd555207b8 then a1111111111111111) | remediator | r1 | 2026-10-14T10:27:46Z | in-flight"
LAW="$LW"
la_ts() { sed -n "s/^{\"ts\":\"\([^\"]*\)\".*\"tool_use_id\":\"$1\"}\$/\1/p" "$LAW/_bmad-output/spawn-ledger.jsonl"; }
LA_T1="$(la_ts toolu_01LateSubjectBBBBBBBBB)"; LA_T2="$(la_ts toolu_01LateMinuteCCCCCCCCC)"
[ "$LA_T1" = 2026-10-14T10:00:03Z ] && [ "$LA_T2" = 2026-10-14T10:27:46Z ] && [ "$LA_T1" != "$LA_T2" ] \
  || { echo "FIXTURE ERROR: LA's two ids must seed two DIFFERENT ts (got '$LA_T1' and '$LA_T2')" >&2; exit 2; }
ldrive late-amb "$V" "$LAW"
LAMB='SKIP  _bmad-output/pipeline-snapshot.md line 14: ambiguous agent cell (2 ids resolve to 2 distinct ts), not judged for LATE'
if [ "$(status_of late-amb)" = 0 ] && grep -qxF "$LAMB" "$(lout late-amb)" && [ "$(nlate late-amb)" = 0 ]; then
  ok "LA a cell with two ids of different dispatches ($LA_T1, $LA_T2) SKIPs as ambiguous (2 distinct ts), not judged"; B_la_amb=1
else
  bad "LA ambiguous cell: exit $(status_of late-amb), $(nlate late-amb) LATE line(s); want rc 0, no LATE, and: $LAMB"
  sed 's/^/      /' "$(lout late-amb)" >&2
fi

# --- LS. ONE dispatch, TWO spellings: an agentId beside its own toolu_ id resolves to one ts, so
# the row IS judged. Stamped 57 s late it is LATE, named by the first resolving candidate (the
# agentId); stamped equal (the control) it is quiet, with no ambiguous SKIP and no SKIP count.
LSCELL='a7ffc8dcd555207b8 (toolu_01LateSubjectBBBBBBBBB)'
late_world late-same "$LSCELL | remediator | r1 | 2026-10-14T10:01:00Z | in-flight"
LSW="$LW"
ldrive late-same "$V" "$LSW"
if [ "$(status_of late-same)" = 1 ] && [ "$(nlate late-same)" = 1 ] \
   && haslate late-same 14 a7ffc8dcd555207b8 2026-10-14T10:01:00Z 2026-10-14T10:00:03Z \
   && ! grep -q 'ambiguous agent cell' "$(lout late-same)"; then
  ok "LS an agentId beside its own toolu_ id (one dispatch) stamped 57 s late is LATE (rc 1), named by the agentId"; B_ls_same=1
else
  bad "LS same-dispatch pair: exit $(status_of late-same), $(nlate late-same) LATE line(s); want rc 1 and exactly the line 14 LATE naming a7ffc8dcd555207b8"
  sed 's/^/      /' "$(lout late-same)" >&2
fi
late_world late-same-eq "$LSCELL | remediator | r1 | 2026-10-14T10:00:03Z | in-flight"
LSEW="$LW"
ldrive late-same-eq "$V" "$LSEW"
if [ "$(status_of late-same-eq)" = 0 ] && [ "$(nlate late-same-eq)" = 0 ] && ! grep -q 'not judged for LATE' "$(lout late-same-eq)"; then
  ok "LS control: the same pair stamped equal to its ts is quiet (rc 0, judged, no SKIP)"
else
  bad "LS control: exit $(status_of late-same-eq), $(nlate late-same-eq) LATE line(s), or a SKIP (want 0, 0, none)"
  sed 's/^/      /' "$(lout late-same-eq)" >&2
fi

# --- LH (h). THE REMEDY CLEARS. Two clock-stamped rows FAIL with 2 LATE lines (the control). Each
# row's dispatched-at is then rewritten with EXACTLY the ts its LATE line printed, parsed from this
# run's output and never from the seed. The re-run must read 0 LATE and pass the LATE verdict. A
# printed remedy that does not clear is a wedge.
late_clear() { # late_clear <label> <validator> -> LH_FIRST, LH_SECOND (LATE counts), LH_CHANGED
  late_world "$1" "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:01:00Z | in-flight
a1111111111111111 | dev | d1 | 2026-10-14T10:29:00Z | in-flight"
  _hw="$LW"; _snap="$_hw/_bmad-output/pipeline-snapshot.md"
  ldrive "$1-1" "$2" "$_hw"; LH_FIRST="$(nlate "$1-1")"
  cp "$_snap" "$WORK/runs/$1.before" || exit 2
  sed -n "s/^LATE  [^ ]* line \([0-9][0-9]*\): [^ ]* dispatched-at \([^ ]*\) is not its dispatch's ledger ts \([^ ]*\)\$/\1 \2 \3/p" \
    "$(lout "$1-1")" > "$WORK/runs/$1.fix" || exit 2
  while read -r _n _dc _ts; do
    DC="$_dc" TS="$_ts" awk -v n="$_n" 'FNR == n { i = index($0, ENVIRON["DC"])
        if (i) $0 = substr($0, 1, i - 1) ENVIRON["TS"] substr($0, i + length(ENVIRON["DC"])) } { print }' \
      "$_snap" > "$_snap.new" && mv "$_snap.new" "$_snap" || exit 2
  done < "$WORK/runs/$1.fix"
  LH_CHANGED=1; cmp -s "$_snap" "$WORK/runs/$1.before" && LH_CHANGED=0
  ldrive "$1-2" "$2" "$_hw"; LH_SECOND="$(nlate "$1-2")"
}
late_clear late-clear "$V"
if [ "$LH_FIRST" = 2 ] && [ "$(status_of late-clear-1)" = 1 ] && [ "$LH_CHANGED" = 1 ] && [ "$LH_SECOND" = 0 ] \
   && [ "$(status_of late-clear-2)" = 0 ] && ! grep -qF "$LATE_HEAD" "$(lout late-clear-2)"; then
  ok "LH the printed remedy clears: 2 LATE (rc 1), each cell rewritten from its own LATE line, then 0 LATE (rc 0)"; B_lh_clear=1
else
  bad "LH remedy: first $LH_FIRST LATE rc $(status_of late-clear-1) (want 2, 1), rewrite changed=$LH_CHANGED, second $LH_SECOND LATE rc $(status_of late-clear-2) (want 0, 0)"
  sed 's/^/      /' "$(lout late-clear-2)" >&2
fi

# --- LG (g). THROUGH verdict.sh: the LATE headline and its row reach the lead within the cap.
late_world late-wrap "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:01:00Z | in-flight"
LGW="$LW"
gdrive() { # gdrive <label> <wrapper>
  OUT="$WORK/runs/$1.out"
  ( cd "$LGW" && AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW_PIN" AI_DLC_SCRIPTS_DIR="${ADIR:-$VD}" AI_DLC_TEAMMATE_DIR="$LGW/sub" \
      bash "$2" validate-artifact-budget --root "$LGW" ) > "$OUT" 2>&1
  printf '%s\t%s\t0\t0\n' "$1" "$?" >> "$LEDGER"
}
gcheck() { # gcheck <label> -> 0 when the wrapper shows the LATE headline AND its row
  _o="$WORK/runs/$1.out"
  [ "$(status_of "$1")" = 1 ] || return 1
  grep -qF "$LATE_HEAD" "$_o" || return 1
  grep -q "LATE .*line 14: a7ffc8dcd555207b8 dispatched-at 2026-10-14T10:01:00Z is not its dispatch's ledger ts 2026-10-14T10:00:03Z" "$_o"
}
gdrive late-verdict "$VW"
if gcheck late-verdict; then
  ok "LG a LATE row is refused through verdict.sh, its headline and its row both shown"; B_lg=1
else
  bad "LG LATE through verdict.sh: exit $(status_of late-verdict), headline or row missing"
  sed 's/^/      /' "$WORK/runs/late-verdict.out" >&2
fi

# --- VS / VT. verdict.sh never hides a SKIP behind PASS, and says when its cap cut a match set.
# verdict.sh prefixes each surfaced line with six spaces and its `grep -n` line number, so the
# validator's own line is read back by stripping `^      <n>:`, never by an anchored token grep.
vdrive() { # vdrive <label> <wrapper> <world> -- verdict.sh over the snapshot, now pinned
  # --root is load-bearing: without it the validator walks up from the world to $WORK's own
  # .claude marker and measures an empty tree, so every arm below reads a bare PASS.
  OUT="$WORK/runs/$1.out"
  ( cd "$3" && AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW_PIN" AI_DLC_SCRIPTS_DIR="${ADIR:-$VD}" AI_DLC_TEAMMATE_DIR="$3/sub" \
      bash "$2" validate-artifact-budget --root "$3" --only pipeline-snapshot.md ) > "$OUT" 2>&1
  printf '%s\t%s\t0\t0\n' "$1" "$?" >> "$LEDGER"
}
vline() { sed -n 's/^      [0-9][0-9]*://p' "$WORK/runs/$1.out" | grep -qxF "$2"; } # vline <label> <validator line>
vshown() { _n="$(grep -cE '^      [0-9]+:' "$WORK/runs/$1.out")" || _n=0; printf '%s' "$_n"; }
vmore() { grep -q '^      … [0-9-]* more matching line(s); run scripts/ai-dlc/validate-artifact-budget.sh directly for all$' "$WORK/runs/$1.out"; }
vmut() { # vmut <out> <find> <replace> -- a verdict.sh copy; the find text sits on exactly one line
  _c="$(F="$2" awk 'index($0, ENVIRON["F"]) { c++ } END { print c + 0 }' "$VW")" || _c=0
  [ "$_c" = 1 ] || { echo "FIXTURE ERROR: verdict.sh mutation anchor on $_c line(s), want 1: $2" >&2; exit 2; }
  F="$2" R="$3" awk '{ i = index($0, ENVIRON["F"]) } i { $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["F"])) } { print }' \
    "$VW" > "$1" || { echo "FIXTURE ERROR: awk died building $1" >&2; exit 2; }
  if cmp -s "$VW" "$1"; then echo "FIXTURE ERROR: verdict.sh mutation did not apply: $2" >&2; exit 2; fi
}
# The validator's match set, counted on the DIRECT run, for the expected notice count: the
# rc!=0 alternation for a failing run, the rc=0 one for a passing run, as verdict.sh picks.
vmatched() {
  if [ "$(status_of "$1")" = 0 ]; then _re='^[[:space:]]*(ok|warn|OK:|PASS|WARN|OVER|FUTURE|BACKDATED|SKIP|LATE)'
  else _re='^[[:space:]]*(FAIL|ERROR|OVER|WARN|warn|FUTURE|BACKDATED|SKIP|LATE)'; fi
  _n="$(grep -cE "$_re" "$(lout "$1")")" || _n=0; printf '%s' "$_n"
}

# VS: rc 0 with one SKIP line (an in-flight row whose agent cell does not resolve, nothing else).
late_world vskip "fold-x | pm | p1 | 2026-10-14T10:00:03Z | in-flight"
VSW="$LW"
VSKIP='SKIP  _bmad-output/pipeline-snapshot.md: 1 in-flight row(s) not judged for LATE (agent cell does not resolve in this session)'
ldrive vskip-direct "$V" "$VSW"
[ "$(status_of vskip-direct)" = 0 ] && grep -qxF "$VSKIP" "$(lout vskip-direct)" \
  || { echo "FIXTURE ERROR: the VS world does not exit 0 with its one SKIP line run directly" >&2; sed 's/^/      /' "$(lout vskip-direct)" >&2; exit 2; }
vdrive vs "$VW" "$VSW"
if [ "$(status_of vs)" = 0 ] && grep -qxF 'PASS  validate-artifact-budget.sh' "$WORK/runs/vs.out" && vline vs "$VSKIP" \
   && ! vmore vs; then
  ok "VS an rc-0 run carrying a SKIP line renders PASS through verdict.sh WITH the SKIP line, verbatim, and no notice"; B_vs=1
else
  bad "VS SKIP through verdict.sh: exit $(status_of vs), PASS or the SKIP line missing, or a notice under the cap"
  sed 's/^/      /' "$WORK/runs/vs.out" >&2
fi

# VT-more: 8 LATE rows (AI_DLC_VERDICT_LINES is the default 6; the env scrub above unsets it).
# The validator's match set is the headline plus the 8 rows, so verdict.sh shows 6 and names
# the rest. Expected n is read off the DIRECT run, and its LATE count is asserted to be the seed.
VT_SEED=8; VT_ROWS=""; _i=1
while [ "$_i" -le "$VT_SEED" ]; do
  VT_ROWS="${VT_ROWS}${VT_ROWS:+
}a7ffc8dcd555207b8 | remediator | r$_i | 2026-10-14T10:0$_i:00Z | in-flight"; _i=$((_i + 1))
done
late_world vtmore "$VT_ROWS"
VTW="$LW"
ldrive vtmore-direct "$V" "$VTW"
VT_N=$(( $(vmatched vtmore-direct) - 6 ))
vdrive vtmore "$VW" "$VTW"
if [ "$(nlate vtmore-direct)" = "$VT_SEED" ] && [ "$VT_N" -gt 0 ] && [ "$(status_of vtmore)" = 1 ] \
   && [ "$(vshown vtmore)" = 6 ] \
   && grep -qxF "      … $VT_N more matching line(s); run scripts/ai-dlc/validate-artifact-budget.sh directly for all" "$WORK/runs/vtmore.out"; then
  ok "VT-more $VT_SEED LATE rows through verdict.sh: 6 lines shown and the notice names the $VT_N cut, counted off the direct run"; B_vt_more=1
else
  bad "VT-more: direct LATE $(nlate vtmore-direct) (want $VT_SEED), n $VT_N, exit $(status_of vtmore) (want 1), shown $(vshown vtmore) (want 6), or the notice is missing or wrong"
  sed 's/^/      /' "$WORK/runs/vtmore.out" >&2
fi
# VT-at-or-under: the same world shape with 5 LATE rows (headline + 5 = exactly the cap, rc 1),
# and VS's rc-0 world, each counted on its direct run first: no notice in either branch.
VT_ROWS="$(printf '%s\n' "$VT_ROWS" | sed -n '1,5p')"
late_world vtunder "$VT_ROWS"
VUW="$LW"
ldrive vtunder-direct "$V" "$VUW"
vdrive vtunder "$VW" "$VUW"
if [ "$(vmatched vtunder-direct)" = 6 ] && [ "$(status_of vtunder)" = 1 ] && [ "$(vshown vtunder)" = 6 ] && ! vmore vtunder \
   && [ "$(vmatched vskip-direct)" -le 6 ] && ! vmore vs; then
  ok "VT-at-or-under a match set of exactly 6 (rc 1) and VS's rc-0 run ($(vmatched vskip-direct) matched) print no notice"; B_vt_under=1
else
  bad "VT-at-or-under: matched $(vmatched vtunder-direct) (want 6), exit $(status_of vtunder), shown $(vshown vtunder), or a notice printed"
  sed 's/^/      /' "$WORK/runs/vtunder.out" >&2
fi

# --- LC. COST, asserted. One --dispatch-ts fork per distinct candidate token of a judged row: the
# motivating cell is 6 (remediator, serial, pass, 1, cross-part, a7ffc8dcd555207b8), a no-id cell
# 4, a bare id 1. The gate path runs the self-probe (its forks are the control); --stamps-only runs
# none, so a snapshot Edit pays only for the rows its payload carries.
lcost() { # lcost <label> <row> -> LC_W (world forks), LC_P (probe forks) for one gate run
  : > "$FORKLOG"; late_world "$1" "$2"; ldrive "$1" "$V" "$LW"
  LC_W="$(forks_world "$1")"; LC_P="$(forks_probe)"
}
lcost cost-deco "$DECO | remediator | r1 | 2026-10-14T10:00:03Z | in-flight"; c_deco="$LC_W"; c_probe="$LC_P"
lcost cost-noid "remediator (serial, pass 1) | remediator | r1 | 2026-10-14T10:00:03Z | in-flight"; c_noid="$LC_W"
lcost cost-bare "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:00:03Z | in-flight"; c_bare="$LC_W"
if [ "$c_deco" = 6 ] && [ "$c_noid" = 4 ] && [ "$c_bare" = 1 ] && [ "$c_probe" -ge 1 ]; then
  ok "LC resolver forks per row: decorated 6, no-id 4, bare 1 (gate self-probe $c_probe, the control)"
else
  bad "LC resolver forks: decorated $c_deco (want 6), no-id $c_noid (want 4), bare $c_bare (want 1), probe $c_probe (want >= 1)"
fi
: > "$FORKLOG"
SPAY="$WORK/runs/stamps.payload"
printf '%s\n' 'a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:00:03Z | in-flight' > "$SPAY"
AI_DLC_TEAMMATE_DIR="$LW/sub" PATH="$SHIM:$PATH" drive_now cost-stamps "$V" "$LW" \
  --stamps-only "$LW/_bmad-output/pipeline-snapshot.md" --payload "$SPAY"
s_w="$(forks_world cost-bare)"; s_p="$(forks_probe)"
if [ "$(status_of cost-stamps)" = 0 ] && [ "$s_w" = 1 ] && [ "$s_p" = 0 ]; then
  ok "LC --stamps-only makes 0 self-probe forks and 1 for the written bare-id row (rc 0)"
else
  bad "LC --stamps-only: exit $(status_of cost-stamps) (want 0), row forks $s_w (want 1), self-probe forks $s_p (want 0)"
fi

# --- mutant builders (each leaves the mutated validator in a directory beside its siblings) ---
mutdir() { # mutdir <name> -> MDIR, MV (an unedited copy of the validator beside the LATE siblings)
  MDIR="$MUTS/$1"; mkdir -p "$MDIR" || { echo "FIXTURE ERROR: mkdir $MDIR" >&2; exit 2; }
  cp "$VD/wait-for-deliverable.sh" "$VD/validate-adversarial-convergence.sh" "$MDIR/" \
    || { echo "FIXTURE ERROR: cannot copy the LATE siblings into $MDIR" >&2; exit 2; }
  if [ -f "$VD/wfd-start-of.sh" ]; then cp "$VD/wfd-start-of.sh" "$MDIR/" || { echo "FIXTURE ERROR: cp wfd-start-of.sh" >&2; exit 2; }; fi
  MV="$MDIR/validate-artifact-budget.sh"
  cp "$V" "$MV" || { echo "FIXTURE ERROR: cp validator" >&2; exit 2; }
}
mut_sed() { # mut_sed <sed-expr> -- edit MV in place, refusing a sed that dies or matches nothing
  sed "$1" "$MV" > "$MV.n" || { echo "FIXTURE ERROR: sed died building $MV" >&2; exit 2; }
  if cmp -s "$MV" "$MV.n"; then echo "FIXTURE ERROR: mutant $MV matched nothing: $1" >&2; exit 2; fi
  cp "$MV.n" "$MV" && rm -f "$MV.n"
}
lmsub() { # lmsub <in> <out> <find> <replace> -- the find text must sit on exactly one line
  _c="$(F="$3" awk 'index($0, ENVIRON["F"]) { c++ } END { print c + 0 }' "$1")" || _c=0
  [ "$_c" = 1 ] || { echo "FIXTURE ERROR: mutation anchor on $_c line(s), want 1: $3" >&2; exit 2; }
  F="$3" R="$4" awk '{ i = index($0, ENVIRON["F"]) } i { $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["F"])) } { print }' \
    "$1" > "$2" || { echo "FIXTURE ERROR: awk died building $2" >&2; exit 2; }
  if cmp -s "$1" "$2"; then echo "FIXTURE ERROR: mutation did not apply: $3" >&2; exit 2; fi
}
# lmut carries the probe-off layer (the LATE self-probe block never runs), because the self-probe would
# otherwise refuse each LATE mutant first and the kill would not be read off its own arm.
lmut() { # lmut <name> [<find> <replace>]
  mutdir "$1"
  lmsub "$V" "$MV.0" 'if [ -z "$STAMPS_ONLY" ]; then' 'if false; then'
  if [ $# -ge 3 ]; then lmsub "$MV.0" "$MV" "$2" "$3"; else cp "$MV.0" "$MV" || exit 2; fi
  rm -f "$MV.0"
}
wmut() { # wmut <name> -> MWF, a verdict.sh copy
  MWD="$MUTS/$1"; mkdir -p "$MWD" || exit 2; MWF="$MWD/verdict.sh"
}
wsed() { # wsed <expr> -- build MWF from VW, refusing a sed that dies or matches nothing
  sed "$1" "$VW" > "$MWF" || { echo "FIXTURE ERROR: sed died building $MWF" >&2; exit 2; }
  if cmp -s "$VW" "$MWF"; then echo "FIXTURE ERROR: mutant $MWF matched nothing" >&2; exit 2; fi
}

# score_mut <id> <validator dir> <wrapper> <deciding arm> <twin arm> -- 0 when the deciding arm TRIPPED.
# The twin runs every time and must stay green: that is what confines the kill to its deciding arm.
score_mut() {
  local id="$1" md="$2" mw="$3" da="$4" tw="$5" trip=1
  MREG="${MREG}${id}|${md}|${mw}
"
  ADIR="$md"
  if "arm_$da" "$md" "$mw"; then trip=1; else trip=0; fi
  DLBL="$AXL"
  if [ "$tw" = "-" ]; then :
  elif "arm_$tw" "$md" "$mw"; then ok "[$tw] twin of $id stays green: the effect of $id is confined to [$da]"
  else bad "[$tw] twin of $id TRIPPED: the effect of $id is not confined to [$da]"; fi
  ADIR=""
  return "$trip"
}

# the unmutated arm f_history has no base block above, so it is asserted here and sets its own flag
if arm_f_history "$VD" "$VW"; then ok "F-history a future stamp in the history file is not read by the shipped arm (rc 0)"; B_f_history=1
else bad "F-history the shipped arm refused a snapshot whose history file carries a future stamp"; fi

# --- M1. REVERT BOTH LAYERS: the summary block goes back to being RC-gated ------------
# The historical form, restored whole: the flags stop being consulted and the only line a passing RC
# can print is the PASS line. Reverting only the branch, or only the flag assignments, would leave a
# layer in place and prove that layer instead.
mutdir M1
awk -v pass="$PASS_LINE" '
  skip && /^exit "\$RC"$/ { skip=0 }
  skip { next }
  /^if \[ "\$RC" -eq 0 \]; then$/ {
    print
    print "  say \"\""
    printf "  say \"%s\"\n", pass
    print "fi"
    skip=1
    next
  }
  { print }
' "$V" > "$MV.n" || exit 2
if cmp -s "$V" "$MV.n"; then
  echo "FIXTURE ERROR: M1 matched nothing -- the summary block's anchors were rewritten" >&2; exit 2
fi
if grep -q 'WARN  this run reported' "$MV.n" || [ "$(grep -cF "$PASS_LINE" "$MV.n")" -ne 1 ]; then
  echo "FIXTURE ERROR: M1 did not produce the RC-gated form" >&2; exit 2
fi
cp "$MV.n" "$MV" && rm -f "$MV.n"
if score_mut M1 "$MDIR" "$VW" a1warn a3noflag; then
  # Arm 9 asserts an ABSENCE: its own predicate must return this run's label, or it cannot fire.
  if [ "$(join_violations "$DLBL")" = "$DLBL" ]; then
    mutant_killed "${B_a1warn:-0}" M1 "MUTANT M1 (summary re-gated on RC): the breach run reappears as a join violation -- arms 1 and 9 can fire"
  else bad "MUTANT M1: the deciding arm tripped but join_violations returned '$(join_violations "$DLBL")' -- arm 9 cannot fire"; fi
else bad "MUTANT M1 SURVIVED: the re-gated summary still withheld the PASS line on a breach run"; fi

# --- M2. REVERT ONE FLAG: SAW_BREACH is never raised -----------------------------------
mutdir M2; mut_sed 's/^  SAW_BREACH=1$/  SAW_BREACH=0/'
if score_mut M2 "$MDIR" "$VW" a1warn a6schema; then
  mutant_killed "${B_a1warn:-0}" M2 "MUTANT M2 (SAW_BREACH never raised): the breach run prints PASS while the schema run is untouched"
else bad "MUTANT M2 SURVIVED: the breach run still withheld the PASS line with SAW_BREACH pinned to 0"; fi

# --- M3. REVERT THE COVERAGE QUALIFIER ONLY ---------------------------------------------
mutdir M3
sed -e '/Measured is not everything: this run also reported/d' \
    -e '/NO budget governs\. They are unmeasured, not within budget\./d' "$V" > "$MV.n" || exit 2
if cmp -s "$V" "$MV.n"; then echo "FIXTURE ERROR: M3 matched nothing -- the coverage qualifier was rewritten" >&2; exit 2; fi
if [ "$(( $(wc -l < "$V") - $(wc -l < "$MV.n") ))" -ne 2 ]; then
  echo "FIXTURE ERROR: M3 deleted $(( $(wc -l < "$V") - $(wc -l < "$MV.n") )) line(s), expected exactly 2" >&2; exit 2
fi
cp "$MV.n" "$MV" && rm -f "$MV.n"
if score_mut M3 "$MDIR" "$VW" a5cov a4clean; then
  mutant_killed "${B_a5cov:-0}" M3 "MUTANT M3 (qualifier deleted): the coverage run prints a bare PASS -- assertion 5 measures the qualifier"
else bad "MUTANT M3 SURVIVED: the qualifier still appeared with its say lines deleted"; fi

# --- M4 / M5. REVERT ONE NEW FLAG EACH (BL-020) -----------------------------------------
mutdir M4; mut_sed 's/^  SAW_INFLIGHT=1$/  SAW_INFLIGHT=0/'
if score_mut M4 "$MDIR" "$VW" a10struck a11marker; then
  mutant_killed "${B_a10struck:-0}" M4 "MUTANT M4 (SAW_INFLIGHT never raised): the struck-row run prints a bare PASS while the marker run is untouched"
else bad "MUTANT M4 SURVIVED: the struck-row run still withheld the PASS line"; fi
mutdir M5; mut_sed 's/^  SAW_MARKER=1$/  SAW_MARKER=0/'
if score_mut M5 "$MDIR" "$VW" a11marker a10struck; then
  mutant_killed "${B_a11marker:-0}" M5 "MUTANT M5 (SAW_MARKER never raised): the marker run prints a bare PASS while the struck-row run is untouched"
else bad "MUTANT M5 SURVIVED: the marker run still withheld the PASS line"; fi

# --- MF1-MF6, MP1-MP2: the future-stamp and pool mutants -------------------------------
mutdir MF1; mut_sed 's/^FUTURE_SLACK_S=600$/FUTURE_SLACK_S=0/'
if score_mut MF1 "$MDIR" "$VW" f_five -; then
  mutant_killed "${B_f_five:-0}" MF1 "MUTANT MF1 (slack 0) killed: the 5-min stamp is refused"
else bad "MUTANT MF1 (slack 0) SURVIVED"; fi
mutdir MF2; mut_sed '/if (substr(str, b, 1) ~ \/\[-0-9\]\/ || wide(b3)) continue/d'
if score_mut MF2 "$MDIR" "$VW" f_range -; then
  mutant_killed "${B_f_range:-0}" MF2 "MUTANT MF2 (range not skipped) killed"
else bad "MUTANT MF2 (range not skipped) SURVIVED"; fi
mutdir MF3; mut_sed 's|check_future_stamps "\$f" "\$rel" "\$SNAP_NOW"|check_future_stamps "${f%.md}-history.md" "$rel" "$SNAP_NOW"|'
if score_mut MF3 "$MDIR" "$VW" f_history f_five; then
  mutant_killed "${B_f_history:-0}" MF3 "MUTANT MF3 (history file read) killed: the shipped arm ignores the history file, the mutant refuses it"
else bad "MUTANT MF3 (history file read) SURVIVED"; fi
mutdir MF4; mut_sed '/^        if (spaced(str, b)) continue$/d'
if score_mut MF4 "$MDIR" "$VW" f_spaced -; then
  mutant_killed "${B_f_spaced:-0}" MF4 "MUTANT MF4 (spaced-range skip deleted) killed"
else bad "MUTANT MF4 (spaced-range skip deleted) SURVIVED"; fi
mutdir MF5; mut_sed 's|      return (substr(s, n, 1) ~ /\[0-9\]/)|      return 1|'
if score_mut MF5 "$MDIR" "$VW" f_dash -; then
  mutant_killed "${B_f_dash:-0}" MF5 "MUTANT MF5 (spaced skip needs no digit) killed: the ' - text' offender loses its FUTURE row"
else bad "MUTANT MF5 (spaced skip needs no digit) SURVIVED"; fi
# MF6 ORDER: the stamp verdict printed AFTER the budget verdict (the pre-fix position). F8's wrapper
# run must lose the remedy or rows. Built with awk (a moved line is two edits) and cmp-guarded.
mutdir MF6
awk '/^report_future_stamps$/ { next }
     /^rm -f "\$FUTURE_FILE"$/ { next }
     { print }
     /^rm -f "\$MARKER_FILE"$/ { print "report_future_stamps"; print "rm -f \"$FUTURE_FILE\"" }' "$V" > "$MV.n" \
  || { echo "FIXTURE ERROR: awk died building $MV" >&2; exit 2; }
if cmp -s "$V" "$MV.n" || [ "$(grep -c '^report_future_stamps$' "$MV.n")" != "1" ]; then
  echo "FIXTURE ERROR: mutant MF6 did not move the call" >&2; exit 2
fi
cp "$MV.n" "$MV" && rm -f "$MV.n"
if score_mut MF6 "$MDIR" "$VW" f8 f9; then
  mutant_killed "${B_f8:-0}" MF6 "MUTANT MF6 (stamp verdict printed after the budget verdict) killed by F8"
else bad "MUTANT MF6 (stamp verdict order) SURVIVED"; fi
mutdir MP1; mut_sed '/\[ "\$brel" = "WHOLE-READ" \] && continue/d'
if score_mut MP1 "$MDIR" "$VW" p_basename p_noitem; then
  mutant_killed "${B_p_basename:-0}" MP1 "MUTANT MP1 (pool hardened by basename) killed by P1"
else bad "MUTANT MP1 (pool hardened by basename) SURVIVED"; fi
mutdir MP2; mut_sed 's|POOL_ITEM="\$(pool_open_item "\$ROOT/\$_bl")"|POOL_ITEM="$_bl"|'
if score_mut MP2 "$MDIR" "$VW" p_noitem p_basename; then
  mutant_killed "${B_p_noitem:-0}" MP2 "MUTANT MP2 (item citation dropped) killed by P2"
else bad "MUTANT MP2 (item citation dropped) SURVIVED"; fi

# --- MW1-MW6: mutants of the verdict.sh wrapper, driven over the REAL validator -----------
wmut MW1; wsed 's/|FUTURE|/|/g'
if score_mut MW1 "$VD" "$MWF" f8 lg; then
  mutant_killed "${B_f8:-0}" MW1 "MUTANT MW1 (verdict.sh drops FUTURE) killed by F8"
else bad "MUTANT MW1 (verdict.sh drops FUTURE) SURVIVED"; fi
wmut MW2; wsed 's/|BACKDATED|/|/g'
if score_mut MW2 "$VD" "$MWF" f9 f8; then
  mutant_killed "${B_f9:-0}" MW2 "MUTANT MW2 (verdict.sh drops BACKDATED) killed by F9"
else bad "MUTANT MW2 (verdict.sh drops BACKDATED) SURVIVED"; fi
wmut MW3
[ "$(grep -c '|LATE)' "$VW")" = 2 ] || { echo "FIXTURE ERROR: verdict.sh no longer carries |LATE) in both alternations" >&2; exit 2; }
wsed 's/|LATE)/)/g'
if score_mut MW3 "$VD" "$MWF" lg f8; then
  mutant_killed "${B_lg:-0}" MW3 "MUTANT MW3 (verdict.sh drops LATE) killed by LG"
else bad "MUTANT MW3 (verdict.sh drops LATE) SURVIVED"; fi
wmut MW4; vmut "$MWF" 'OVER|FUTURE|BACKDATED|SKIP|LATE)' 'OVER|FUTURE|BACKDATED|LATE)'
if score_mut MW4 "$VD" "$MWF" vs vt_under; then
  mutant_killed "${B_vs:-0}" MW4 "MUTANT MW4 (verdict.sh drops SKIP from the rc=0 set) killed by VS"
else bad "MUTANT MW4 (verdict.sh drops SKIP) SURVIVED"; fi
wmut MW5; vmut "$MWF" '[ "$_n" -le "$LINES" ] || printf' '[ "$_n" -le "$LINES" ] || true || printf'
if score_mut MW5 "$VD" "$MWF" vt_more vt_under; then
  mutant_killed "${B_vt_more:-0}" MW5 "MUTANT MW5 (truncation notice removed) killed by VT-more"
else bad "MUTANT MW5 (truncation notice removed) SURVIVED"; fi
wmut MW6; vmut "$MWF" '[ "$_n" -le "$LINES" ] || printf' 'printf'
if score_mut MW6 "$VD" "$MWF" vt_under vt_more; then
  mutant_killed "${B_vt_under:-0}" MW6 "MUTANT MW6 (truncation notice printed unconditionally) killed by VT-at-or-under"
else bad "MUTANT MW6 (notice unconditional) SURVIVED"; fi

# --- LATE MUTANTS. Each is a copy of the validator beside its siblings WITH the probe-off layer. ML0
# is that layer ALONE and must pass every LATE arm a mutant is scored on: it proves the copies run and
# the probe-off layer kills nothing by itself. A failed copy or edit is FIXTURE ERROR, never a kill.
lmut ML0
ml0_bad=""
for _a in l1b le_skip la_amb ls_same lh_clear; do "arm_$_a" "$MDIR" "$VW" || ml0_bad="$ml0_bad $_a"; done
if [ -z "$ml0_bad" ]; then ok "CONTROL ML0: the probe-off copy beside its siblings is green on l1b, le_skip, la_amb, ls_same and lh_clear (no arm tripped)"; B_ml0=1
else bad "CONTROL ML0: the probe-off copy tripped these LATE arms:$ml0_bad -- every LATE mutant verdict below is void"; fi
lmut ML1 '[ "$dc" = "$ts" ] || printf "LATE  ' '[[ ! "$dc" > "$ts" ]] || printf "LATE  '
if score_mut ML1 "$MDIR" "$VW" l1b l0eq; then
  mutant_killed "${B_ml0:-0}" ML1 "MUTANT ML1 (LATE means later-than) killed by L1b': the 1 s early row loses its LATE line"
else bad "MUTANT ML1 (LATE means later-than) SURVIVED"; fi
lmut ML2 '[ "$k" -eq 0 ] || printf '"'"'SKIP  %s: %d in-flight' '[ "$k" -eq 0 ] || true || printf '"'"'SKIP  %s: %d in-flight'
if score_mut ML2 "$MDIR" "$VW" le_skip l0eq; then
  mutant_killed "${B_ml0:-0}" ML2 "MUTANT ML2 (unresolvable rows silent) killed by LE: the run passes with no SKIP count"
else bad "MUTANT ML2 (unresolvable rows silent) SURVIVED"; fi
lmut ML4 '"$id" "$dc" "$ts"' '"$id" "$dc" "$dc"'
if score_mut ML4 "$MDIR" "$VW" lh_clear l0eq; then
  mutant_killed "${B_ml0:-0}" ML4 "MUTANT ML4 (LATE names the stamp, not the ts) killed by LH: after the printed rewrite, still LATE"
else bad "MUTANT ML4 (LATE names the stamp) SURVIVED"; fi
lmut ML5 '{ id="$c"; ts="$t"; }' '{ id="$c"; ts="$t"; }; m=1; break'
if score_mut ML5 "$MDIR" "$VW" la_amb l0eq; then
  mutant_killed "${B_ml0:-0}" ML5 "MUTANT ML5 (first resolving candidate) killed by LA: no ambiguous SKIP, the first id read LATE"
else bad "MUTANT ML5 (first resolving candidate) SURVIVED"; fi
lmut ML6 'if [ "$m" -gt 1 ]; then' 'if [ "$n" -gt 1 ]; then'
if score_mut ML6 "$MDIR" "$VW" ls_same la_amb; then
  mutant_killed "${B_ml0:-0}" ML6 "MUTANT ML6 (count resolving ids, not distinct ts) killed by LS: the one-dispatch pair SKIPs as ambiguous, no LATE"
else bad "MUTANT ML6 (count resolving ids) SURVIVED"; fi

# --- THE MATRIX: every mutant over every arm, only in --matrix mode -----------------------------
if [ "$MATRIX" = 1 ]; then
  while IFS='|' read -r mid mmd mmw; do
    [ -n "$mid" ] || continue
    for a in $ARMS; do
      ADIR="$mmd"
      if "arm_$a" "$mmd" "$mmw"; then matrix_row "$mid" "$a" 0 GREEN no; else matrix_row "$mid" "$a" 1 TRIPPED yes; fi
      MROWS=$((MROWS + 1))
    done
  done <<EOF
$MREG
EOF
  n_mut="$(printf '%s' "$MREG" | grep -c .)"; n_arm="$(printf '%s\n' $ARMS | grep -c .)"
  if [ "$n_mut" -eq 24 ] && [ "$MROWS" -eq $((n_mut * n_arm)) ]; then ok "[MX] the matrix run measured $MROWS cells for $n_mut mutants over $n_arm arms"
  else bad "[MX] matrix rows=$MROWS for $n_mut mutants over $n_arm arms"; fi
else
  if [ "$MROWS" -eq 0 ]; then ok "[MX] a plain run executed no matrix-only cell (rows=0)"; else bad "[MX] a plain run executed $MROWS matrix rows"; fi
fi

echo ""
[ "$rc" -eq 0 ] && echo "budget-summary-verdict fixture: PASS"
[ "$rc" -eq 0 ] || echo "budget-summary-verdict fixture: FAIL" >&2
exit "$rc"
