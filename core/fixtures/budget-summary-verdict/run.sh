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

echo ""
[ "$rc" -eq 0 ] && echo "budget-summary-verdict fixture: PASS"
[ "$rc" -eq 0 ] || echo "budget-summary-verdict fixture: FAIL" >&2
exit "$rc"
