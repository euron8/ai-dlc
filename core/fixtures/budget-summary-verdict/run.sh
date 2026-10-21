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

set -u

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

rc=0
ok()  { echo "ok: $1"; }
bad() { echo "FAIL: $1" >&2; rc=1; }

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

# --- 1. --warn-only, UNHARDENED BREACH: the run that filed the defect ----------------
# RC is 0 here by contract. The summary must still say what the run reported.
A1="$(arm_dir warnonly-unhardened)"; seed_breach "$A1"
drive warnonly-unhardened "$V" "$A1" --warn-only
if [ "$(status_of warnonly-unhardened)" = "0" ] \
   && has 'WARN  this run reported over-budget artifact(s) and is NOT a clean result.' \
   && has '      Exit status is 0 because --warn-only was passed and no reported artifact was'; then
  ok "--warn-only over an unhardened breach exits 0 and closes with the WARN summary"
else
  bad "--warn-only over an unhardened breach: exit $(status_of warnonly-unhardened), summary line missing"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi

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

# --- 3. NO FLAG, BREACH: the blocking posture is untouched ---------------------------
# Gate Check 14 and the sub-step path drive it this way. The breach is a FAIL, the exit
# is 1, and the summary block is not reached.
A3="$(arm_dir noflag-breach)"; seed_breach "$A3"
drive noflag-breach "$V" "$A3"
if [ "$(status_of noflag-breach)" = "1" ] \
   && has 'FAIL: 1 artifact(s) over the Rule 25(d) budget.'; then
  ok "no flag over a breach exits 1 and reports FAIL, not WARN"
else
  bad "no flag over a breach: exit $(status_of noflag-breach), FAIL line missing"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi

# --- 4. CLEAN: the passing line is BYTE-IDENTICAL to what it has always been ---------
# Asserted with `grep -Fx` against a literal held in this file, in BOTH drive modes. The
# whole point of the fix is that only the runs with something to report changed.
A4="$(arm_dir clean)"; seed_clean "$A4"
drive clean-noflag "$V" "$A4"
if [ "$(status_of clean-noflag)" = "0" ] && has "$PASS_LINE" && ! grep -q '^WARN' "$OUT"; then
  ok "a clean run exits 0 and prints the historical PASS line byte for byte"
else
  bad "a clean run: exit $(status_of clean-noflag), PASS line not byte-identical or a WARN appeared"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi
drive clean-warnonly "$V" "$A4" --warn-only
if [ "$(status_of clean-warnonly)" = "0" ] && has "$PASS_LINE" && ! grep -q '^WARN' "$OUT"; then
  ok "  and --warn-only over the same clean tree prints the same line and exits 0"
else
  bad "  --warn-only over a clean tree: exit $(status_of clean-warnonly), line moved or a WARN appeared"
fi

# --- 5. COVERAGE ONLY: a PASS that states its blind spot -----------------------------
# An ungoverned artifact is UNMEASURED, not over budget, so the clean claim and the
# coverage WARN are both literally true at once. That run keeps the PASS line and adds
# the qualifier -- the one branch where the two coexist legitimately.
A5="$(arm_dir coverage)"; seed_clean "$A5"; seed_ungoverned "$A5"
drive coverage-only "$V" "$A5"
if [ "$(status_of coverage-only)" = "0" ] \
   && has "$PASS_LINE" \
   && has "$QUALIFIER" \
   && hasl 'WARN: read-path artifact(s) over 2000 tok that NO budget governs.'; then
  ok "a coverage-only run exits 0, keeps the PASS line, and qualifies it"
else
  bad "coverage-only run: exit $(status_of coverage-only), PASS and/or qualifier missing"
  grep -E '^(WARN|PASS|FAIL)|Measured is not' "$OUT" | sed 's/^/      /' >&2
fi
# THE CONTROL THAT MAKES THE QUALIFIER ASSERTION MEAN SOMETHING. Remove the ungoverned
# artifact and nothing else: the qualifier must disappear. Without this, an
# unconditional qualifier satisfies the arm above.
rm -f "$A5/_bmad-output/coverage-probe.md"
drive coverage-control "$V" "$A5"
if [ "$(status_of coverage-control)" = "0" ] && has "$PASS_LINE" && ! has "$QUALIFIER"; then
  ok "  control: with the ungoverned artifact removed the PASS line carries no qualifier"
else
  bad "  control: the qualifier survived the ungoverned artifact's removal -- it is unconditional"
fi

# --- 6. THE SCHEMA CHANNEL ------------------------------------------------------------
# An off-schema section is not a budget breach, and it still means the run reported a
# finding about a MEASURED artifact. Same summary branch, different named cause.
A6="$(arm_dir schema)"; seed_clean "$A6"
seed_snapshot "$A6" "$INFLIGHT_CLEAN"
printf '\n## Invented Section\n- lead invention\n' >> "$A6/_bmad-output/pipeline-snapshot.md"
drive schema-warnonly "$V" "$A6" --warn-only
if [ "$(status_of schema-warnonly)" = "0" ] \
   && has 'WARN  this run reported off-schema section(s) and is NOT a clean result.'; then
  ok "--warn-only over an off-schema section exits 0 and names the section in the summary"
else
  bad "off-schema section under --warn-only: exit $(status_of schema-warnonly), summary line missing"
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

A10="$(arm_dir struck)"; seed_clean "$A10"
seed_snapshot "$A10" "$INFLIGHT_STRUCK"
# shellcheck disable=SC2086
drive struck-retro "$V" "$A10" $RETRO_FLAGS
if [ "$(status_of struck-retro)" = "0" ] \
   && has 'WARN: In-Flight Teammates carries struck-through row(s).' \
   && has 'WARN  this run reported struck-through In-Flight row(s) and is NOT a clean result.' \
   && ! has "$PASS_LINE"; then
  ok "a struck In-Flight row under retro's flags exits 0, names the row in the summary, and prints no PASS line"
else
  bad "struck In-Flight row under retro's flags: exit $(status_of struck-retro), qualified summary missing or bare PASS printed"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi

# The marker channel is reachable as a false PASS only under --warn-only WITHOUT the
# snapshot hardened: --fail-on pipeline-snapshot.md turns it into a FAIL and RC=1.
A11="$(arm_dir marker)"; seed_clean "$A11"
seed_snapshot "$A11" "$INFLIGHT_CLEAN"; seed_marker "$A11"
drive marker-warnonly "$V" "$A11" --warn-only
if [ "$(status_of marker-warnonly)" = "0" ] \
   && has 'WARN: pipeline-snapshot.md marks superseded content in place.' \
   && has 'WARN  this run reported superseded content marked in place and is NOT a clean result.' \
   && ! has "$PASS_LINE"; then
  ok "a superseded marker under --warn-only exits 0, names the marker in the summary, and prints no PASS line"
else
  bad "superseded marker under --warn-only: exit $(status_of marker-warnonly), qualified summary missing or bare PASS printed"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi
# The same seed under retro's flags is the hardened posture, and it must NOT move: a FAIL,
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
# MUTANTS. Copies, never in-place edits, each guarded with `cmp -s` so a pattern that
# matched nothing cannot pass as a mutation. Staged in $WORK/bin so a crashed run cannot
# leave a stray script where the core-script-boundary checks would read it.
#
# THE COPY HAS NO SIBLINGS, and that is fine but not free: the pool's live-sprint arm
# resolves through `sprint-status.sh` beside the script, finds nothing, and says so on a
# `note:` line. It changes no verdict -- and the UNMUTATED CONTROL at the end is what
# establishes that, rather than a reading of the code.
# =====================================================================================
MUT_BIN="$WORK/bin"

# --- M1. REVERT BOTH LAYERS: the summary block goes back to being RC-gated ------------
# The historical form, restored whole: the flags stop being consulted and the only line
# a passing RC can print is the PASS line. Reverting only the branch, or only the flag
# assignments, would leave a layer in place and prove that layer instead.
M1="$MUT_BIN/m1-rc-gated.sh"
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
' "$V" > "$M1" || exit 2
if cmp -s "$V" "$M1"; then
  echo "FIXTURE ERROR: M1 matched nothing -- the summary block's anchors were rewritten" >&2
  echo "  expected a line 'if [ \"\$RC\" -eq 0 ]; then' followed by the summary and 'exit \"\$RC\"'" >&2
  exit 2
fi
if grep -q 'WARN  this run reported' "$M1" || [ "$(grep -cF "$PASS_LINE" "$M1")" -ne 1 ]; then
  echo "FIXTURE ERROR: M1 did not produce the RC-gated form (WARN branch survived, or the" >&2
  echo "  PASS line does not appear exactly once)" >&2
  exit 2
fi
seed_breach "$A1"
drive m1-warnonly "$M1" "$A1" --warn-only
# Scored through arm 9's OWN predicate, over the row this drive just appended. Arm 9
# asserts an ABSENCE, so without a run that makes `join_violations` return something it
# is indistinguishable from a join that can never fire.
if [ "$(status_of m1-warnonly)" = "0" ] \
   && [ "$(join_violations m1-warnonly)" = "m1-warnonly" ] \
   && ! grep -q '^WARN  this run' "$OUT"; then
  ok "MUTANT M1 (summary re-gated on RC): the breach run reappears as a join violation -- arms 1 and 9 can fire"
else
  bad "MUTANT M1 SURVIVED: exit $(status_of m1-warnonly), join_violations returned '$(join_violations m1-warnonly)' -- arms 1 and 9 prove nothing"
  grep -E '^(WARN|PASS|FAIL)' "$OUT" | sed 's/^/      /' >&2
fi

# --- M2. REVERT ONE FLAG: SAW_BREACH is never raised ----------------------------------
# Narrower than M1 on purpose. It must kill the breach arms and leave the schema arm
# alive; a mutant that kills everything cannot tell the four channels apart, and the
# subject's whole design is that they are separate verdicts.
M2="$MUT_BIN/m2-no-saw-breach.sh"
sed 's/^  SAW_BREACH=1$/  SAW_BREACH=0/' "$V" > "$M2" || exit 2
if cmp -s "$V" "$M2"; then
  echo "FIXTURE ERROR: M2 matched nothing -- the SAW_BREACH assignment was rewritten" >&2
  exit 2
fi
drive m2-warnonly "$M2" "$A1" --warn-only
drive m2-schema    "$M2" "$A6" --warn-only
m2_killed=0
[ "$(join_violations m2-warnonly)" = "m2-warnonly" ] && m2_killed=1
m2_narrow=0
grep -q '^WARN  this run reported off-schema section(s)' "$WORK/runs/m2-schema.out" && m2_narrow=1
if [ "$m2_killed" -eq 1 ] && [ "$m2_narrow" -eq 1 ]; then
  ok "MUTANT M2 (SAW_BREACH never raised): the breach run prints PASS while the schema run is untouched"
elif [ "$m2_killed" -ne 1 ]; then
  bad "MUTANT M2 SURVIVED: the breach run still withheld the PASS line with SAW_BREACH pinned to 0"
else
  bad "MUTANT M2 was not narrow: pinning SAW_BREACH also silenced the schema summary -- the channels are entangled"
fi

# --- M3. REVERT THE COVERAGE QUALIFIER ONLY -------------------------------------------
# The coverage branch keeps its PASS line and loses the sentence that says measured is
# not everything. Nothing else moves -- this is the arm that proves assertion 5 measures
# the qualifier rather than the PASS line it sits under.
M3="$MUT_BIN/m3-no-qualifier.sh"
sed -e '/Measured is not everything: this run also reported/d' \
    -e '/NO budget governs\. They are unmeasured, not within budget\./d' "$V" > "$M3" || exit 2
if cmp -s "$V" "$M3"; then
  echo "FIXTURE ERROR: M3 matched nothing -- the coverage qualifier was rewritten" >&2
  exit 2
fi
if [ "$(( $(wc -l < "$V") - $(wc -l < "$M3") ))" -ne 2 ]; then
  echo "FIXTURE ERROR: M3 deleted $(( $(wc -l < "$V") - $(wc -l < "$M3") )) line(s), expected exactly 2" >&2
  exit 2
fi
seed_ungoverned "$A5"
drive m3-coverage "$M3" "$A5"
if [ "$(status_of m3-coverage)" = "0" ] \
   && grep -qxF "$PASS_LINE" "$WORK/runs/m3-coverage.out" \
   && ! grep -qxF "$QUALIFIER" "$WORK/runs/m3-coverage.out"; then
  ok "MUTANT M3 (qualifier deleted): the coverage run prints a bare PASS -- assertion 5 measures the qualifier"
else
  bad "MUTANT M3 SURVIVED: the qualifier still appeared with its say lines deleted"
fi

# --- M4 / M5. REVERT ONE NEW FLAG EACH (BL-020) ---------------------------------------
# Same narrowness discipline as M2: each must bring back the bare PASS on its own channel
# and leave the OTHER new channel's qualified summary intact, or the two flags are
# entangled and one of arms 10/11 is vacuous.
mut_flag() { # mut_flag <out> <flag>
  sed "s/^  $2=1\$/  $2=0/" "$V" > "$1" || exit 2
  if cmp -s "$V" "$1"; then
    echo "FIXTURE ERROR: mutant pinning $2 matched nothing -- the assignment was rewritten" >&2
    exit 2
  fi
}
M4="$MUT_BIN/m4-no-saw-inflight.sh"; mut_flag "$M4" SAW_INFLIGHT
# shellcheck disable=SC2086
drive m4-struck "$M4" "$A10" $RETRO_FLAGS
drive m4-marker "$M4" "$A11" --warn-only
if grep -qxF "$PASS_LINE" "$WORK/runs/m4-struck.out" \
   && grep -q '^WARN  this run reported superseded content marked in place' "$WORK/runs/m4-marker.out"; then
  ok "MUTANT M4 (SAW_INFLIGHT never raised): the struck-row run prints a bare PASS while the marker run is untouched"
else
  bad "MUTANT M4 SURVIVED or was not narrow: struck run PASS=$(grep -cxF "$PASS_LINE" "$WORK/runs/m4-struck.out"), marker summary=$(grep -c '^WARN  this run reported superseded' "$WORK/runs/m4-marker.out")"
fi
M5="$MUT_BIN/m5-no-saw-marker.sh"; mut_flag "$M5" SAW_MARKER
drive m5-marker "$M5" "$A11" --warn-only
# shellcheck disable=SC2086
drive m5-struck "$M5" "$A10" $RETRO_FLAGS
if grep -qxF "$PASS_LINE" "$WORK/runs/m5-marker.out" \
   && grep -q '^WARN  this run reported struck-through In-Flight row(s)' "$WORK/runs/m5-struck.out"; then
  ok "MUTANT M5 (SAW_MARKER never raised): the marker run prints a bare PASS while the struck-row run is untouched"
else
  bad "MUTANT M5 SURVIVED or was not narrow: marker run PASS=$(grep -cxF "$PASS_LINE" "$WORK/runs/m5-marker.out"), struck summary=$(grep -c '^WARN  this run reported struck' "$WORK/runs/m5-struck.out")"
fi

# --- CONTROL. An UNMUTATED copy, staged in the same directory, driven the same way ----
# A lone copy that dies for its own reasons emits nothing, and "no output" scores as a
# kill on every mutant above. This is what separates a mutation from a broken staging --
# and it is the arm that establishes the missing sprint-status.sh sibling changes no
# verdict, rather than a reading of the subject's code.
CTRL="$MUT_BIN/control-unmutated.sh"
cp "$V" "$CTRL" || exit 2
seed_breach "$A1"
drive control-warnonly "$CTRL" "$A1" --warn-only
ctl_ok=0
[ "$(status_of control-warnonly)" = "0" ] \
  && grep -q '^WARN  this run reported over-budget artifact(s)' "$WORK/runs/control-warnonly.out" \
  && ! grep -qxF "$PASS_LINE" "$WORK/runs/control-warnonly.out" && ctl_ok=1
drive control-coverage "$CTRL" "$A5"
ctl_cov=0
[ "$(status_of control-coverage)" = "0" ] \
  && grep -qxF "$PASS_LINE" "$WORK/runs/control-coverage.out" \
  && grep -qxF "$QUALIFIER" "$WORK/runs/control-coverage.out" && ctl_cov=1
if [ "$ctl_ok" -eq 1 ] && [ "$ctl_cov" -eq 1 ]; then
  ok "CONTROL: an unmutated copy staged the same way reproduces both branches -- M1-M3 died of their edits"
else
  bad "CONTROL: the unmutated copy did not reproduce the subject (breach=$ctl_ok coverage=$ctl_cov) -- every mutant verdict above is unattributable"
  sed 's/^/      /' "$WORK/runs/control-warnonly.out" >&2
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
  ok "F8 through verdict.sh under a co-occurring OVER: the stamp FAIL line carries the remedy and all 5 FUTURE rows survive the 6-line cap"
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
  ok "P1 an over pool under --warn-only, and under --fail-on WHOLE-READ (a label word, not the token), stays rc 0"
else
  bad "P1 warn-only=$(status_of pool-warn), --fail-on WHOLE-READ=$(status_of pool-basename) (want 0 and 0)"
fi
if [ "$(status_of pool-noitem)" = "1" ] && grep -q 'no OPEN carry-over item cites it' "$WORK/runs/pool-noitem.out"; then
  ok "P2 --fail-on whole-read-pool with no OPEN citing item (an OPEN non-citing and a CLOSED citing one present) is rc 1"
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

# --- MUTANTS for F and P. Copies, cmp-guarded, scored against the arm that must kill. --
mk() { # mk <out> <sed-expr>
  sed "$2" "$V" > "$1" || { echo "FIXTURE ERROR: sed died building $1" >&2; exit 2; }
  if cmp -s "$V" "$1"; then echo "FIXTURE ERROR: mutant $1 matched nothing" >&2; exit 2; fi
}
# MF1 threshold 0: the 5-min-ahead near-miss must now be refused (the in-script self-probe
# carries the same near-miss and is what refuses first; either way the run is rc 1).
MF1="$MUT_BIN/mf1-slack0.sh"; mk "$MF1" 's/^FUTURE_SLACK_S=600$/FUTURE_SLACK_S=0/'
seed_stamped "$AF" '- 2026-10-14T11:05Z five minutes ahead' "$IF_HDR"
drive_now mf1 "$MF1" "$AF" --only pipeline-snapshot.md
[ "$(status_of mf1)" = "1" ] && ok "MUTANT MF1 (slack 0) killed: the 5-min stamp is refused" \
  || bad "MUTANT MF1 (slack 0) SURVIVED"
# MF2 range not skipped: the `followed by - or digit` test deleted.
MF2="$MUT_BIN/mf2-range.sh"; mk "$MF2" '/if (substr(str, b, 1) ~ \/\[-0-9\]\/ || wide(b3)) continue/d'
seed_stamped "$AF" '- 2026-10-14T12:00Z-12:45Z planned window' "$IF_HDR"
drive_now mf2 "$MF2" "$AF" --only pipeline-snapshot.md
[ "$(status_of mf2)" = "1" ] && ok "MUTANT MF2 (range not skipped) killed" || bad "MUTANT MF2 (range not skipped) SURVIVED"
# MF3 history file read: the call site re-pointed at pipeline-snapshot-history.md. The live
# snapshot is clean, the history file carries a future stamp; only the mutant reads it.
MF3="$MUT_BIN/mf3-history.sh"
mk "$MF3" 's|check_future_stamps "\$f" "\$rel" "\$SNAP_NOW"|check_future_stamps "${f%.md}-history.md" "$rel" "$SNAP_NOW"|'
seed_stamped "$AF" '- nothing notable' "$IF_HDR"
printf '## Recent Activity\n- 2026-12-01T00:00Z archived future line\n' > "$AF/_bmad-output/pipeline-snapshot-history.md"
drive_now mf3-orig "$V" "$AF" --only pipeline-snapshot.md
drive_now mf3 "$MF3" "$AF" --only pipeline-snapshot.md
if [ "$(status_of mf3-orig)" = "0" ] && [ "$(status_of mf3)" = "1" ]; then
  ok "MUTANT MF3 (history file read) killed: the shipped arm ignores the history file, the mutant refuses it"
else
  bad "MUTANT MF3: shipped=$(status_of mf3-orig) (want 0) mutant=$(status_of mf3) (want 1)"
fi
rm -f "$AF/_bmad-output/pipeline-snapshot-history.md"
# MP1 pool token matched by basename: the WHOLE-READ exclusion deleted.
MP1="$MUT_BIN/mp1-basename.sh"; mk "$MP1" '/\[ "\$brel" = "WHOLE-READ" \] && continue/d'
AI_DLC_READER_WINDOW_TOKENS=200000 drive mp1 "$MP1" "$AP" --warn-only --fail-on WHOLE-READ
[ "$(status_of mp1)" = "1" ] && ok "MUTANT MP1 (pool hardened by basename) killed by P1" \
  || bad "MUTANT MP1 (pool hardened by basename) SURVIVED"
# MP2 item-citation check dropped: any backlog counts as recorded. P2's tree is restored
# (the citing item removed) and must stay rc 1.
MP2="$MUT_BIN/mp2-nocite.sh"; mk "$MP2" 's|POOL_ITEM="\$(pool_open_item "\$ROOT/\$_bl")"|POOL_ITEM="$_bl"|'
printf '# Carry-over backlog\n### CO-S1-OTHER\n**Status:** OPEN\nunrelated\n' > "$BL"
AI_DLC_READER_WINDOW_TOKENS=200000 drive mp2-orig "$V" "$AP" --warn-only --fail-on whole-read-pool
AI_DLC_READER_WINDOW_TOKENS=200000 drive mp2 "$MP2" "$AP" --warn-only --fail-on whole-read-pool
if [ "$(status_of mp2-orig)" = "1" ] && [ "$(status_of mp2)" = "0" ]; then
  ok "MUTANT MP2 (item citation dropped) killed by P2"
else
  bad "MUTANT MP2: shipped=$(status_of mp2-orig) (want 1) mutant=$(status_of mp2) (want 0)"
fi
# MF4 spaced-range skip deleted: the `spaced` near-miss must now be refused (the self-probe
# carries the same near-miss and refuses first; either way the run is rc 1, where F2-F6's
# shipped run of that near-miss was rc 0).
MF4="$MUT_BIN/mf4-nospaced.sh"; mk "$MF4" '/^        if (spaced(str, b)) continue$/d'
seed_stamped "$AF" '- 2026-10-14T12:00Z - 12:45Z planned' "$IF_HDR"
drive_now mf4 "$MF4" "$AF" --only pipeline-snapshot.md
[ "$(status_of mf4)" = "1" ] && [ "$(status_of nm-spaced)" = "0" ] \
  && ok "MUTANT MF4 (spaced-range skip deleted) killed" || bad "MUTANT MF4 (spaced-range skip deleted) SURVIVED"
# MF5 spaced skip WITHOUT its digit test: ` - DEPLOY DONE` is acquitted. F1c's dashtext twin
# must lose its FUTURE row (the self-probe's dash offender also dies, so no row at all).
MF5="$MUT_BIN/mf5-nodigit.sh"; mk "$MF5" 's|      return (substr(s, n, 1) ~ /\[0-9\]/)|      return 1|'
seed_stamped "$AF" '- 2026-10-14T12:00Z - DEPLOY DONE' "$IF_HDR"
drive_now mf5 "$MF5" "$AF" --only pipeline-snapshot.md
if ! grep -q '^FUTURE .*2026-10-14T12:00Z' "$OUT" && [ "$(status_of off-dashtext)" = "1" ]; then
  ok "MUTANT MF5 (spaced skip needs no digit) killed: the ' - text' offender loses its FUTURE row"
else
  bad "MUTANT MF5 (spaced skip needs no digit) SURVIVED"
fi
# MF6 ORDER: the stamp verdict printed AFTER the budget verdict (the pre-fix position). F8's
# wrapper run must lose the remedy or rows. Built with awk (a moved line is two edits) and
# cmp-guarded like mk.
MF6="$MUT_BIN/mf6-order.sh"
awk '/^report_future_stamps$/ { next }
     /^rm -f "\$FUTURE_FILE"$/ { next }
     { print }
     /^rm -f "\$MARKER_FILE"$/ { print "report_future_stamps"; print "rm -f \"$FUTURE_FILE\"" }' "$V" > "$MF6" \
  || { echo "FIXTURE ERROR: awk died building $MF6" >&2; exit 2; }
if cmp -s "$V" "$MF6" || [ "$(grep -c '^report_future_stamps$' "$MF6")" != "1" ]; then
  echo "FIXTURE ERROR: mutant $MF6 did not move the call" >&2; exit 2
fi
MF6D="$MUT_BIN/mf6dir"; mkdir -p "$MF6D" || exit 2
cp "$MF6" "$MF6D/validate-artifact-budget.sh" || exit 2
wdrive mf6 "$VW" "$MF6D"
if grep -q '^FAIL  validate-artifact-budget.sh' "$WORK/runs/mf6.out" && ! wcheck mf6; then
  ok "MUTANT MF6 (stamp verdict printed after the budget verdict) killed by F8"
else
  bad "MUTANT MF6 (stamp verdict order) SURVIVED or did not run"
  sed 's/^/      /' "$WORK/runs/mf6.out" >&2
fi
# MW1 verdict.sh WITHOUT `FUTURE` in its alternations: F8 must lose the rows. The mutant
# wrapper lives in MUT_BIN, so AI_DLC_SCRIPTS_DIR points it back at the real validator; the
# positive conjunct (the stamp FAIL line is there) proves the copy ran.
MW1="$MUT_BIN/mw1-verdict.sh"
sed 's/|FUTURE|/|/g' "$VW" > "$MW1" || { echo "FIXTURE ERROR: sed died building $MW1" >&2; exit 2; }
if cmp -s "$VW" "$MW1"; then echo "FIXTURE ERROR: mutant $MW1 matched nothing" >&2; exit 2; fi
wdrive mw1 "$MW1" "$(dirname "$V")"
if grep -q 'FAIL: pipeline-snapshot.md carries stamp(s) later' "$WORK/runs/mw1.out" && ! wcheck mw1; then
  ok "MUTANT MW1 (verdict.sh drops FUTURE) killed by F8"
else
  bad "MUTANT MW1 (verdict.sh drops FUTURE) SURVIVED or did not run"
  sed 's/^/      /' "$WORK/runs/mw1.out" >&2
fi

# F9 BACKDATED THROUGH verdict.sh. The FAIL line says "re-stamp each row below"; the wrapper
# must surface the row it names, alongside a co-firing FUTURE row, within its 6-line cap.
AB="$(arm_dir backdated)"; seed_clean "$AB"
seed_stamped "$AB" '- 2026-10-14T12:00Z DEPLOY DONE' "$IF_HDR
fold | pm-escalated | d1 | 2026-10-14T10:15:40Z | in-flight"
printf '{"ts":"2026-10-14T10:17:32Z","name":"pm-escalated","role":"pm"}\n' > "$AB/_bmad-output/spawn-ledger.jsonl"
bdrive() { # bdrive <label> <wrapper>
  OUT="$WORK/runs/$1.out"
  ( cd "$AB" && AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW_PIN" AI_DLC_SCRIPTS_DIR="$(dirname "$V")" \
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
  ok "F9 a back-dated in-flight row is refused through verdict.sh, its row and a co-firing FUTURE row both shown"
else
  bad "F9 back-dated row through verdict.sh: exit $(status_of backdated), headline, row or FUTURE row missing"
  sed 's/^/      /' "$WORK/runs/backdated.out" >&2
fi
# MW2 verdict.sh WITHOUT `BACKDATED`: F9 must lose the row while the headline survives.
MW2="$MUT_BIN/mw2-verdict.sh"
sed 's/|BACKDATED|/|/g' "$VW" > "$MW2" || { echo "FIXTURE ERROR: sed died building $MW2" >&2; exit 2; }
if cmp -s "$VW" "$MW2"; then echo "FIXTURE ERROR: mutant $MW2 matched nothing" >&2; exit 2; fi
bdrive mw2 "$MW2"
if grep -q 'earlier than its dispatch' "$WORK/runs/mw2.out" && ! bcheck mw2; then
  ok "MUTANT MW2 (verdict.sh drops BACKDATED) killed by F9"
else
  bad "MUTANT MW2 (verdict.sh drops BACKDATED) SURVIVED or did not run"
  sed 's/^/      /' "$WORK/runs/mw2.out" >&2
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
  ok "L1a a bare agentId stamped 57 s late is LATE at the gate (rc 1), named with its ledger ts"
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
  ok "L1b' a row 1 s EARLY is LATE while BACKDATED stays quiet (inside its tolerance)"
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
  ok "L0 bare, decorated and toolu_ rows stamped equal to their ts are quiet (rc 0, PASS, every row judged)"
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
  ok "LE three unresolvable rows (bare name, no meta.json, a commit sha) print the SKIP count 3; delivered and stopped rows are not judged"
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
  ok "LA a cell with two ids of different dispatches ($LA_T1, $LA_T2) SKIPs as ambiguous (2 distinct ts), not judged"
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
  ok "LS an agentId beside its own toolu_ id (one dispatch) stamped 57 s late is LATE (rc 1), named by the agentId"
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
  ok "LH the printed remedy clears: 2 LATE (rc 1), each cell rewritten from its own LATE line, then 0 LATE (rc 0)"
else
  bad "LH remedy: first $LH_FIRST LATE rc $(status_of late-clear-1) (want 2, 1), rewrite changed=$LH_CHANGED, second $LH_SECOND LATE rc $(status_of late-clear-2) (want 0, 0)"
  sed 's/^/      /' "$(lout late-clear-2)" >&2
fi

# --- LG (g). THROUGH verdict.sh: the LATE headline and its row reach the lead within the cap.
late_world late-wrap "a7ffc8dcd555207b8 | remediator | r1 | 2026-10-14T10:01:00Z | in-flight"
LGW="$LW"
gdrive() { # gdrive <label> <wrapper>
  OUT="$WORK/runs/$1.out"
  ( cd "$LGW" && AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW_PIN" AI_DLC_SCRIPTS_DIR="$VD" AI_DLC_TEAMMATE_DIR="$LGW/sub" \
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
  ok "LG a LATE row is refused through verdict.sh, its headline and its row both shown"
else
  bad "LG LATE through verdict.sh: exit $(status_of late-verdict), headline or row missing"
  sed 's/^/      /' "$WORK/runs/late-verdict.out" >&2
fi
MW3="$MUT_BIN/mw3-verdict.sh"
[ "$(grep -c '|LATE)' "$VW")" = 2 ] || { echo "FIXTURE ERROR: verdict.sh no longer carries |LATE) in both alternations" >&2; exit 2; }
sed 's/|LATE)/)/g' "$VW" > "$MW3" || { echo "FIXTURE ERROR: sed died building $MW3" >&2; exit 2; }
if cmp -s "$VW" "$MW3"; then echo "FIXTURE ERROR: mutant $MW3 matched nothing" >&2; exit 2; fi
gdrive mw3 "$MW3"
if grep -qF "$LATE_HEAD" "$WORK/runs/mw3.out" && ! gcheck mw3; then
  ok "MUTANT MW3 (verdict.sh drops LATE) killed by LG"
else
  bad "MUTANT MW3 (verdict.sh drops LATE) SURVIVED or did not run"
  sed 's/^/      /' "$WORK/runs/mw3.out" >&2
fi

# --- VS / VT. verdict.sh never hides a SKIP behind PASS, and says when its cap cut a match set.
# verdict.sh prefixes each surfaced line with six spaces and its `grep -n` line number, so the
# validator's own line is read back by stripping `^      <n>:`, never by an anchored token grep.
vdrive() { # vdrive <label> <wrapper> <world> -- verdict.sh over the snapshot, now pinned
  # --root is load-bearing: without it the validator walks up from the world to $WORK's own
  # .claude marker and measures an empty tree, so every arm below reads a bare PASS.
  OUT="$WORK/runs/$1.out"
  ( cd "$3" && AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW_PIN" AI_DLC_SCRIPTS_DIR="$VD" AI_DLC_TEAMMATE_DIR="$3/sub" \
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
  ok "VS an rc-0 run carrying a SKIP line renders PASS through verdict.sh WITH the SKIP line, verbatim, and no notice"
else
  bad "VS SKIP through verdict.sh: exit $(status_of vs), PASS or the SKIP line missing, or a notice under the cap"
  sed 's/^/      /' "$WORK/runs/vs.out" >&2
fi
MW4="$MUT_BIN/mw4-verdict.sh"
vmut "$MW4" 'OVER|FUTURE|BACKDATED|SKIP|LATE)' 'OVER|FUTURE|BACKDATED|LATE)'
vdrive mw4 "$MW4" "$VSW"
if grep -qxF 'PASS  validate-artifact-budget.sh' "$WORK/runs/mw4.out" && vline mw4 "$PASS_LINE" && ! vline mw4 "$VSKIP"; then
  ok "MUTANT MW4 (verdict.sh drops SKIP from the rc=0 set) killed by VS"
else
  bad "MUTANT MW4 (verdict.sh drops SKIP) SURVIVED or did not run"
  sed 's/^/      /' "$WORK/runs/mw4.out" >&2
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
  ok "VT-more $VT_SEED LATE rows through verdict.sh: 6 lines shown and the notice names the $VT_N cut, counted off the direct run"
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
  ok "VT-at-or-under a match set of exactly 6 (rc 1) and VS's rc-0 run ($(vmatched vskip-direct) matched) print no notice"
else
  bad "VT-at-or-under: matched $(vmatched vtunder-direct) (want 6), exit $(status_of vtunder), shown $(vshown vtunder), or a notice printed"
  sed 's/^/      /' "$WORK/runs/vtunder.out" >&2
fi
MW5="$MUT_BIN/mw5-verdict.sh"
vmut "$MW5" '[ "$_n" -le "$LINES" ] || printf' '[ "$_n" -le "$LINES" ] || true || printf'
vdrive mw5 "$MW5" "$VTW"
if [ "$(vshown mw5)" = 6 ] && ! vmore mw5; then
  ok "MUTANT MW5 (truncation notice removed) killed by VT-more"
else
  bad "MUTANT MW5 (truncation notice removed) SURVIVED or did not run"
  sed 's/^/      /' "$WORK/runs/mw5.out" >&2
fi
MW6="$MUT_BIN/mw6-verdict.sh"
vmut "$MW6" '[ "$_n" -le "$LINES" ] || printf' 'printf'
vdrive mw6 "$MW6" "$VUW"
if [ "$(vshown mw6)" = 6 ] && vmore mw6; then
  ok "MUTANT MW6 (truncation notice printed unconditionally) killed by VT-at-or-under"
else
  bad "MUTANT MW6 (notice unconditional) SURVIVED or did not run"
  sed 's/^/      /' "$WORK/runs/mw6.out" >&2
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

# --- LATE MUTANTS. Each is a copy of the validator in its own directory WITH the siblings it
# resolves, so a mutant that finds no resolver cannot score a kill by silence. Every copy also
# carries the probe-off layer (the LATE self-probe block never runs), because the self-probe would
# otherwise refuse each mutant first and the kill would not be read off its own arm. ML0 is that
# layer ALONE and must pass every arm a mutant is scored on: it proves the copies run and the
# probe-off layer kills nothing by itself. A mutation edits the ONE line holding its anchor (count
# checked) and is cmp-guarded; a failed copy or edit is FIXTURE ERROR (exit 2), never a kill.
LMUT="$WORK/lmut"
lmut() { # lmut <name> [<find> <replace>] -> LMV, a mutated copy beside its siblings
  _md="$LMUT/$1"; mkdir -p "$_md" || { echo "FIXTURE ERROR: mkdir $_md" >&2; exit 2; }
  cp "$VD/wait-for-deliverable.sh" "$VD/validate-adversarial-convergence.sh" "$_md/" \
    || { echo "FIXTURE ERROR: cannot copy the LATE siblings into $_md" >&2; exit 2; }
  if [ -f "$VD/wfd-start-of.sh" ]; then cp "$VD/wfd-start-of.sh" "$_md/" || { echo "FIXTURE ERROR: cp wfd-start-of.sh" >&2; exit 2; }; fi
  LMV="$_md/validate-artifact-budget.sh"
  lmsub "$V" "$LMV.0" 'if [ -z "$STAMPS_ONLY" ]; then' 'if false; then'
  if [ $# -ge 3 ]; then lmsub "$LMV.0" "$LMV" "$2" "$3"; else cp "$LMV.0" "$LMV" || exit 2; fi
  rm -f "$LMV.0"
}
lmsub() { # lmsub <in> <out> <find> <replace> -- the find text must sit on exactly one line
  _c="$(F="$3" awk 'index($0, ENVIRON["F"]) { c++ } END { print c + 0 }' "$1")" || _c=0
  [ "$_c" = 1 ] || { echo "FIXTURE ERROR: mutation anchor on $_c line(s), want 1: $3" >&2; exit 2; }
  F="$3" R="$4" awk '{ i = index($0, ENVIRON["F"]) } i { $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["F"])) } { print }' \
    "$1" > "$2" || { echo "FIXTURE ERROR: awk died building $2" >&2; exit 2; }
  if cmp -s "$1" "$2"; then echo "FIXTURE ERROR: mutation did not apply: $3" >&2; exit 2; fi
}
# ML0 the probe-off layer alone: (b'), (e), (i3), LS and (h) all hold.
lmut m0
ldrive m0-off "$LMV" "$L1W"; ldrive m0-skip "$LMV" "$LEW"; ldrive m0-amb "$LMV" "$LAW"; ldrive m0-same "$LMV" "$LSW"
late_clear m0-clear "$LMV"
if haslate m0-off 17 a1111111111111111 2026-10-14T10:27:45Z 2026-10-14T10:27:46Z && [ "$(nlate m0-off)" = 5 ] \
   && grep -qxF "$LSKIP" "$(lout m0-skip)" && grep -qxF "$LAMB" "$(lout m0-amb)" \
   && [ "$(nlate m0-same)" = 1 ] && haslate m0-same 14 a7ffc8dcd555207b8 2026-10-14T10:01:00Z 2026-10-14T10:00:03Z \
   && [ "$LH_FIRST" = 2 ] && [ "$LH_SECOND" = 0 ]; then
  ok "ML0 control: the probe-off copy beside its siblings passes L1, LE, LA, LS and LH"
else
  bad "ML0 control: the probe-off copy failed an arm (L1 $(nlate m0-off)/5, LS $(nlate m0-same)/1, LH $LH_FIRST->$LH_SECOND) -- every LATE mutant verdict below is void"
fi
# ML1 the predicate becomes "later than": the 1 s early row (b') goes quiet; the late rows still fire.
lmut m1 '[ "$dc" = "$ts" ] || printf "LATE  ' '[[ ! "$dc" > "$ts" ]] || printf "LATE  '
ldrive m1 "$LMV" "$L1W"
if haslate m1 14 a7ffc8dcd555207b8 2026-10-14T10:01:00Z 2026-10-14T10:00:03Z \
   && ! haslate m1 17 a1111111111111111 2026-10-14T10:27:45Z 2026-10-14T10:27:46Z; then
  ok "MUTANT ML1 (LATE means later-than) killed by L1b': the 1 s early row loses its LATE line"
else
  bad "MUTANT ML1 (LATE means later-than) SURVIVED or did not run"
fi
# ML2 unresolvable rows are quiet: no SKIP count line.
lmut m2 '[ "$k" -eq 0 ] || printf '"'"'SKIP  %s: %d in-flight' '[ "$k" -eq 0 ] || true || printf '"'"'SKIP  %s: %d in-flight'
ldrive m2 "$LMV" "$LEW"
if [ "$(status_of m2)" = 0 ] && grep -qxF "$PASS_LINE" "$(lout m2)" && ! grep -qxF "$LSKIP" "$(lout m2)"; then
  ok "MUTANT ML2 (unresolvable rows silent) killed by LE: the run passes with no SKIP count"
else
  bad "MUTANT ML2 (unresolvable rows silent) SURVIVED or did not run"
fi
# ML4 the LATE line prints the row's own stamp where the ledger ts belongs: the remedy cannot clear.
lmut m4 '"$id" "$dc" "$ts"' '"$id" "$dc" "$dc"'
late_clear m4-clear "$LMV"
if [ "$LH_FIRST" = 2 ] && [ "$LH_SECOND" = 2 ]; then
  ok "MUTANT ML4 (LATE names the stamp, not the ts) killed by LH: after the printed rewrite, still 2 LATE"
else
  bad "MUTANT ML4 (LATE names the stamp) SURVIVED or did not run: $LH_FIRST -> $LH_SECOND (want 2 -> 2)"
fi
# ML5 judge on the FIRST resolving candidate instead of one distinct ts: the ambiguous cell reads LATE.
lmut m5 '{ id="$c"; ts="$t"; }' '{ id="$c"; ts="$t"; }; m=1; break'
ldrive m5 "$LMV" "$LAW"
if ! grep -qxF "$LAMB" "$(lout m5)" && haslate m5 14 a7ffc8dcd555207b8 2026-10-14T10:27:46Z 2026-10-14T10:00:03Z; then
  ok "MUTANT ML5 (first resolving candidate) killed by LA: no ambiguous SKIP, the first id read LATE"
else
  bad "MUTANT ML5 (first resolving candidate) SURVIVED or did not run"
fi
# ML6 the old rule: count resolving IDS, not distinct ts. The same-dispatch pair reads ambiguous.
lmut m6 'if [ "$m" -gt 1 ]; then' 'if [ "$n" -gt 1 ]; then'
ldrive m6 "$LMV" "$LSW"
if [ "$(nlate m6)" = 0 ] \
   && grep -qxF 'SKIP  _bmad-output/pipeline-snapshot.md line 14: ambiguous agent cell (2 ids resolve to 1 distinct ts), not judged for LATE' "$(lout m6)"; then
  ok "MUTANT ML6 (count resolving ids, not distinct ts) killed by LS: the one-dispatch pair SKIPs as ambiguous, no LATE"
else
  bad "MUTANT ML6 (count resolving ids) SURVIVED or did not run"
  sed 's/^/      /' "$(lout m6)" >&2
fi

echo ""
[ "$rc" -eq 0 ] && echo "budget-summary-verdict fixture: PASS"
[ "$rc" -eq 0 ] || echo "budget-summary-verdict fixture: FAIL" >&2
exit "$rc"
