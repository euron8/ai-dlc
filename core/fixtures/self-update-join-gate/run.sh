#!/usr/bin/env bash
# self-update-join-gate — prove the self-update gate refuses to cut a branch when the
# machinery slice cannot be green without the rulebook.
#
# THE DEFECT. Step 2 of ai-dlc-update installs MACHINERY and deliberately excludes the
# RULEBOOK, on the stated premise that "a fixture's subject is always machinery". That
# premise is false. Measured on the reference consumer pulling 0.249.0 -> 0.261.0, 7 of
# that tree's 109 fixtures are red in the state step 2 constructs, through two couplings:
# enforcement-map.yaml (machinery) is joined to CHECK_LOADED anchors in gate-validation.md
# (rulebook), and some fixtures assert on the shipped SKILL.md directly. The operator who
# hit this had to cut a branch, write 17 paths and run 43 fixtures to find out.
#
# THE ASSERTION THAT CARRIES THE RELEASE IS 3, NOT 1. An arm that defers whenever a fixture
# merely MENTIONS rulebook would defer on every pull, stranding the machinery slice for no
# reason — the exact false positive self-update-gate.sh's own header warns about. The arm
# is a DIFFERENTIAL: it fires only when the rulebook is ALSO about to change. Assertion 3
# is the one that proves it, and if it ever goes red this release has become the thing it
# was written to prevent.
#
# THE GATE RUNS GO THROUGH A POOL, AND THE REASON IS THE SUITE'S CRITICAL PATH. One gate
# invocation costs ~21s (it extracts each gating script at two refs and runs BOTH against a
# consumer tree), the six invocations below are independent, and run end to end they made
# this fixture the pre-push suite's pole: measured 248s against a 249s makespan, where the
# suite's own floor -- total unit cost over sixteen workers -- is ~159s. A pool's makespan is
# bounded below by its longest single unit, so a fixture that is internally serial sets the
# whole suite's wall clock no matter what AI_DLC_FIXTURE_JOBS is.
#
# ONE CONSUMER COPY PER RUN, which is a correctness requirement and not a tidiness one. The
# gate `cd`s into the consumer root and executes the incoming and current copies of every
# gating validator there. Three of the runs below take the same seeded consumer, so sharing
# one directory would have two of those validator executions writing in the same cwd at the
# same time -- an intermittent red that would look like a gate defect. A consumer copies in
# well under a second; the isolated form is also the cheap one.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"
GATE="$D_ROOT/core/skills/ai-dlc-update/reconcile/self-update-gate.sh"

# Distribution-only, and say WHY accurately. The gate IS shipped to consumers (it lands at
# .claude/skills/ai-dlc-update/reconcile/), so "not present" would be a false reason. What a
# consumer lacks is the distribution's GIT HISTORY: this fixture derives BASE and THEIRS from
# the commit that adds a CHECK_LOADED anchor and installs two consumer trees from those refs.
# A skip whose stated reason is wrong is worse than no skip — it sends the next reader after
# a file that is sitting right there.
if [ ! -f "$GATE" ] || [ ! -d "$D_ROOT/.git" ]; then
  echo "self-update-join-gate: SKIP — distribution-only (needs the distribution's git history to derive a check-adding range)"
  exit 0
fi

WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
echo "self-update-join-gate:"

OUTD="$WORK/out"; mkdir -p "$OUTD"

# ======================= PHASE 1: build the mutants, serially =======================
# Before the pool, because a mutant that did not build must be REPORTED rather than
# scheduled: `cmp -s` proves the sed landed and `bash -n` proves the result is still a
# program. A copy that is not a program dies instantly and its silence would otherwise
# score as a kill.
CTRL="$WORK/gate-control.sh"; cp "$GATE" "$CTRL"

MUT_A="$WORK/mutant-a.sh"
sed 's/^    r1_missing=.*/    r1_missing=""/' "$CTRL" > "$MUT_A"
MUT_A_BUILD=ok
cmp -s "$CTRL" "$MUT_A" && MUT_A_BUILD=vacuous
[ "$MUT_A_BUILD" = ok ] && { bash -n "$MUT_A" 2>/dev/null || MUT_A_BUILD=notaprogram; }

MUT_B="$WORK/mutant-b.sh"
sed 's/^if \[ -n "\$R2_RB" \]; then/if true; then/' "$CTRL" > "$MUT_B"
MUT_B_BUILD=ok
cmp -s "$CTRL" "$MUT_B" && MUT_B_BUILD=vacuous
[ "$MUT_B_BUILD" = ok ] && { bash -n "$MUT_B" 2>/dev/null || MUT_B_BUILD=notaprogram; }

# The anchor-stripped consumer for assertion 5, also built here: its absence is a FIXTURE
# BROKEN verdict rather than an assertion, so it must be settled before anything schedules.
NOANCHOR="$WORK/cons-noanchors"
rm -rf "$NOANCHOR"; cp -R "$CONS_OLD" "$NOANCHOR"
GVC="$NOANCHOR/.claude/skills/ai-dlc/steps/gate-validation.md"
NOANCHOR_BUILD=ok
if [ -f "$GVC" ]; then
  sed 's/^<!-- CHECK_LOADED:/<!-- XX_LOADED:/' "$GVC" > "$GVC.mut" && mv "$GVC.mut" "$GVC"
else
  NOANCHOR_BUILD=missing
fi

# ============================ PHASE 2: run the gates in a pool ============================
# The registry is <label>\t<gate-script>\t<consumer-source>. Runs are declared here and
# rendered in this order below, so the output is byte-comparable against the serial version
# this replaces — which is the differential the refactor had to produce.
RUNS="$WORK/runs"
: > "$RUNS"
printf '%s\t%s\t%s\n' r_old      "$GATE"  "$CONS_OLD"     >> "$RUNS"
printf '%s\t%s\t%s\n' r_current  "$GATE"  "$CONS_CURRENT" >> "$RUNS"
[ "$NOANCHOR_BUILD" = ok ] && printf '%s\t%s\t%s\n' r_noanchor "$GATE" "$NOANCHOR" >> "$RUNS"
printf '%s\t%s\t%s\n' r_control  "$CTRL"  "$CONS_OLD"     >> "$RUNS"
[ "$MUT_A_BUILD" = ok ] && printf '%s\t%s\t%s\n' r_muta "$MUT_A" "$CONS_OLD"     >> "$RUNS"
[ "$MUT_B_BUILD" = ok ] && printf '%s\t%s\t%s\n' r_mutb "$MUT_B" "$CONS_CURRENT" >> "$RUNS"

N_RUNS="$(grep -c . "$RUNS" || true)"
if [ "$N_RUNS" -lt 4 ]; then
  echo "FIXTURE ERROR: registered only $N_RUNS gate run(s) — the registry did not fill, so nothing below is evidence" >&2
  exit 2
fi

# SIX, and fixed rather than tunable for the reason the sibling pools state in place: this
# pool nests inside the pre-push suite's own, so a knob here multiplies against the knob
# there and the PRODUCT is what lands on the machine. Six is the run count — there is no
# gain from a wider pool than there is work, and every slot beyond it is contention the
# sibling fixtures pay for.
SUJG_JOBS=6
AI_DLC_SUJG_OUT="$OUTD" AI_DLC_SUJG_RUNS="$RUNS" \
  AI_DLC_SUJG_DIST="$DIST" AI_DLC_SUJG_BASE="$BASE" AI_DLC_SUJG_THEIRS="$THEIRS" \
  xargs -P "$SUJG_JOBS" -I{} bash -c '
    l="$1"
    g="$(awk -F"\t" -v k="$l" "\$1==k{print \$2}" "$AI_DLC_SUJG_RUNS")"
    c="$(awk -F"\t" -v k="$l" "\$1==k{print \$3}" "$AI_DLC_SUJG_RUNS")"
    [ -n "$g" ] && [ -n "$c" ] || exit 0
    priv="$AI_DLC_SUJG_OUT/$l.consumer"
    cp -R "$c" "$priv" || exit 0
    bash "$g" "$AI_DLC_SUJG_DIST" "$AI_DLC_SUJG_BASE" "$AI_DLC_SUJG_THEIRS" "$priv" \
      > "$AI_DLC_SUJG_OUT/$l.txt" 2>&1
    printf done > "$AI_DLC_SUJG_OUT/$l.done"
    rm -rf "$priv"
  ' _ {} < <(cut -f1 "$RUNS")

# verdict <label> — the captured output, or the empty string if the job was dropped.
# A MISSING VERDICT IS A FAILURE, not a gap: serially a run that never happened could not
# produce a grep hit either, but it also could not be mistaken for one that did. `.done` is
# written after the run, so its absence means the pool dropped work.
have() { [ -f "$OUTD/$1.done" ]; }
verdict() { cat "$OUTD/$1.txt" 2>/dev/null; }
dropped() { bad "$1 produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one"; }

# ===================== PHASE 3: evaluate, serially, in declaration order =====================

out="$(verdict r_old)"

# --- Assertion 1: a rulebook-joined pull DEFERS --------------------------------
if ! have r_old; then dropped r_old
elif grep -q 'SELF-UPDATE-DEFER' <<<"$out"; then
  ok "a pull whose map declares checks the consumer has no anchor for DEFERS"
else
  bad "the gate returned no DEFER for a rulebook-joined pull — step 2 would cut a branch, write the slice, run the fixtures and revert"
  printf '%s\n' "$out" | sed 's/^/        /' | head -4
fi

# --- Assertion 2: it NAMES the missing anchors ---------------------------------
# The operator who hit this had to derive the collapsed ordering by hand. A defer that
# does not say which checks are unanchored costs exactly that again.
# Do not hardcode WHICH check: the seed derives its range from history, so the unanchored
# id moves as releases land. Require that the message names at least one concrete id.
if ! have r_old; then dropped r_old
elif grep -q 'whose CHECK_LOADED anchor lives in' <<<"$out" && grep -qE 'check\(s\) \[[A-Za-z0-9]' <<<"$out"; then
  ok "the defer NAMES the unanchored check ids rather than only announcing a conflict"
else
  bad "the defer does not name the unanchored checks — the operator must re-derive them by hand"
fi

# --- Assertion 3: A MACHINERY-ONLY PULL STILL PROCEEDS -------------------------
# The false positive that would make this release worse than the defect. If the rulebook
# is not changing, no fixture can break on it, and step 2 must stay autonomous.
out_mo="$(verdict r_current)"
if ! have r_current; then dropped r_current
elif grep -q 'SELF-UPDATE-DEFER' <<<"$out_mo"; then
  bad "a pull with NO rulebook change DEFERRED — the arm is static, not differential, and it strands the machinery slice on every pull"
  printf '%s\n' "$out_mo" | sed 's/^/        /' | head -3
else
  ok "a pull that changes no rulebook file does NOT defer — the arm is a differential"
fi

# --- Assertion 4: the fixture-coupling arm names its subjects ------------------
if ! have r_old; then dropped r_old
elif grep -q 'rulebook-coupled-fixtures' <<<"$out"; then
  ok "the fixture-coupling arm fires and names itself"
else
  bad "the fixture-coupling arm never fired — postcompact-rulebook-recovery is exactly the case it exists for"
fi

# --- Assertion 5: an unparseable anchor side REFUSES, never agrees -------------
# A zero must not be a false zero: if the anchor grammar moves, an empty set compares
# equal to anything and the gate would report agreement it never computed.
if [ "$NOANCHOR_BUILD" != ok ]; then
  bad "FIXTURE BROKEN — no gate-validation.md in the seeded consumer, so assertion 5 tests nothing"
elif ! have r_noanchor; then dropped r_noanchor
elif grep -q 'SELF-UPDATE-UNDECIDED' <<<"$(verdict r_noanchor)"; then
  ok "an unparseable anchor side returns UNDECIDED — an empty set does not read as agreement"
else
  bad "a consumer with no parseable anchors did not return UNDECIDED — a false zero would read as a clean join"
fi

# ------------------------------------------------------------------------------
# MUTANTS. Copies, never in-place edits; built and guarded in phase 1. The unmutated
# control comes first: this gate shells out to git, and a copy that fails for its own
# reasons would score every mutant below as a kill.
# ------------------------------------------------------------------------------
if ! have r_control; then
  dropped r_control
  CONTROL_OK=0
elif grep -q 'SELF-UPDATE-DEFER' <<<"$(verdict r_control)"; then
  ok "UNMUTATED CONTROL reproduces the real verdict from a copy"
  CONTROL_OK=1
else
  bad "UNMUTATED CONTROL did not reproduce — every mutant below is uninterpretable"
  CONTROL_OK=0
fi

if [ "${CONTROL_OK:-0}" = "1" ]; then
  # MUTANT A: the anchor join stops comparing. Assertion 1's ANCHOR half must go quiet.
  if [ "$MUT_A_BUILD" = vacuous ]; then
    bad "MUTANT A changed nothing — the anchor is stale and the mutant is a no-op"
  elif [ "$MUT_A_BUILD" = notaprogram ]; then
    bad "MUTANT A is not a valid program — its silence would have scored as a kill"
  elif ! have r_muta; then
    dropped r_muta
  elif grep -q 'whose CHECK_LOADED anchor lives in' <<<"$(verdict r_muta)"; then
    bad "MUTANT A DID NOT silence the anchor arm — assertion 2 is not testing the join"
  else
    ok "MUTANT A killed — without the anchor comparison the unanchored checks go unreported"
  fi

  # MUTANT B: the fixture arm stops being differential — drop the rulebook-changed guard.
  # It must then defer on the machinery-only pull, which is assertion 3's whole point.
  if [ "$MUT_B_BUILD" = vacuous ]; then
    bad "MUTANT B changed nothing — anchor stale"
  elif [ "$MUT_B_BUILD" = notaprogram ]; then
    bad "MUTANT B is not a valid program"
  elif ! have r_mutb; then
    dropped r_mutb
  elif grep -q 'SELF-UPDATE-DEFER' <<<"$(verdict r_mutb)"; then
    ok "MUTANT B killed — dropping the differential guard defers a machinery-only pull (assertion 3 has teeth)"
  else
    bad "MUTANT B DID NOT defer the machinery-only pull — assertion 3 is not testing the differential"
  fi
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "self-update-join-gate: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "self-update-join-gate: all assertions passed"
