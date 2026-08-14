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

# clone_tree <src> <dst> — one consumer-tree copy, APFS-cloned when the platform allows it.
#
# SEVEN OF THESE RUN PER FIXTURE (one here, six in the pool below) over a ~500-file installed
# consumer, and `cp -c` (clonefile(2)) makes each of them a metadata operation instead of a
# byte copy.
#
# THE FALLBACK IS MANDATORY AND SO IS THE `rm -rf` IN FRONT OF IT. `core/fixtures/` is
# installed into consumer trees: GNU `cp` has no `-c` at all, and macOS `cp -c` FAILS rather
# than degrading when source and destination are on different volumes or on a non-APFS one.
# Either way `cp -c` can die PARTWAY, leaving a half-tree that the gate would then read as a
# consumer missing files — so the destination is removed before the slow path re-copies it.
#
# ONE IMPLEMENTATION, EXPORTED RATHER THAN RESTATED. The pool below runs in a child `bash -c`,
# and a second copy of this logic there is a copy that can drift from this one. `export -f`
# carries the function into the child; if that import ever fails the child's copy step fails,
# the `.done` marker is never written, and the `dropped` arm reports it as a failure — the
# broken state is loud rather than a silently slower path nobody compares.
clone_tree() {
  rm -rf "$2"
  cp -Rc "$1" "$2" 2>/dev/null || { rm -rf "$2"; cp -R "$1" "$2"; }
}
export -f clone_tree

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
clone_tree "$CONS_OLD" "$NOANCHOR"
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
    clone_tree "$c" "$priv" || exit 0
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

# ============================================================================
# THE rc-PAIR TABLE. The gate probes each gating script BARE -- no arguments, no stdin --
# because it cannot know what the hook passes. For a script whose bare form is a usage error
# that probe asks nothing and gets "usage" back from BOTH sides, which used to land on the
# both-non-zero arm and DEFER. Measured across every script the reference consumer's pre-push
# invokes, three of five exit 2 bare (validate-audit-anchors, validate-layer-entries,
# validate-provenance-block; validate-compact-window and validate-fixture-drivability exit 0),
# so any machinery-only pull touching one of those three deferred permanently.
#
# THE WHOLE RISK OF THAT FIX IS THAT IT REMOVES THE GATE, so the table is driven directly here
# rather than inferred: a purpose-built dist and consumer where the changed script is a stub
# whose exit code is the input. `2,2` must now clear; every pair that represents a real change
# in what the hook will run must still defer. `0,2` is the arm that keeps the fix honest --
# an incoming version that NEWLY refuses its own invocation is a change, not a no-op.
RCD="$WORK/rcpair"
mkdir -p "$RCD/dist" "$RCD/consumer/scripts/ai-dlc" "$RCD/consumer/.githooks"
(
  cd "$RCD/dist" && git -c init.defaultBranch=main init -q . \
    && git config user.email f@example.com && git config user.name Fixture \
    && git config commit.gpgsign false && mkdir -p core/scripts
) || { echo "FIXTURE ERROR: rc-pair dist init failed" >&2; exit 2; }
printf 'exit 0\n' > "$RCD/dist/core/scripts/validate-probe.sh"
( cd "$RCD/dist" && git add -A && git commit -q -m base ) || exit 2
RC_BASE="$( cd "$RCD/dist" && git rev-parse HEAD )"
printf 'scripts/ai-dlc/validate-probe.sh\n' > "$RCD/consumer/.githooks/pre-push"

# rcpair <cur-rc> <new-rc> -> the gate's verdict token for validate-probe.sh
rcpair() {
  printf 'exit %s\n' "$1" > "$RCD/consumer/scripts/ai-dlc/validate-probe.sh"
  # THE MARKER IS LOAD-BEARING. The gating set is `invoked AND changed in BASE..THEIRS`, and
  # BASE ships `exit 0`. Without it, the pair `<cur> 0` writes a file byte-identical to BASE,
  # the script is not in the range's changed set, the gate emits nothing for it, and the arm
  # reads as an empty verdict rather than as a result. Every pair must be a real change.
  printf '# pair %s-%s\nexit %s\n' "$1" "$2" "$2" > "$RCD/dist/core/scripts/validate-probe.sh"
  ( cd "$RCD/dist" && git add -A && git commit -q -m "new $2" --allow-empty ) >/dev/null 2>&1
  local theirs; theirs="$( cd "$RCD/dist" && git rev-parse HEAD )"
  bash "${3:-$GATE}" "$RCD/dist" "$RC_BASE" "$theirs" "$RCD/consumer" 2>&1 \
    | grep -oE 'SELF-UPDATE-(OK|DEFER|UNDECIDED)[[:space:]]+validate-probe\.sh' | head -1 \
    | awk '{print $1}'
}

RC_22="$(rcpair 2 2)"; RC_01="$(rcpair 0 1)"; RC_02="$(rcpair 0 2)"; RC_11="$(rcpair 1 1)"
RC_33="$(rcpair 3 3)"; RC_21="$(rcpair 2 1)"; RC_10="$(rcpair 1 0)"
if [ -z "$RC_22$RC_01$RC_02$RC_11$RC_33$RC_21$RC_10" ]; then
  bad "rc-pair harness produced no verdicts at all — the table below would be seven silent passes"
else
  [ "$RC_22" = "SELF-UPDATE-OK" ] \
    && ok "rc 2,2 (both refuse the bare probe) is OK — a usage error on both sides is not a differential signal; two of the seven scripts the pre-push invokes exit 2 bare" \
    || bad "rc 2,2 gave [$RC_22], expected SELF-UPDATE-OK — the three usage-error scripts still strand the machinery slice"
  [ "$RC_01" = "SELF-UPDATE-DEFER" ] \
    && ok "rc 0,1 still DEFERS — an incoming version that newly fails against this tree is the case the gate exists for, and the 2,2 arm did not swallow it" \
    || bad "rc 0,1 gave [$RC_01], expected SELF-UPDATE-DEFER — the fix REMOVED the gate"
  [ "$RC_02" = "SELF-UPDATE-DEFER" ] \
    && ok "rc 0,2 still DEFERS — a version that NEWLY refuses its own invocation changed what the hook runs, so the exemption is scoped to BOTH sides agreeing and not to either side alone" \
    || bad "rc 0,2 gave [$RC_02], expected SELF-UPDATE-DEFER — the arm keyed on one side, so a newly-broken invocation reads as a no-op"
  # 1,1 CHANGED VERDICT IN v0.297.0 AND THE REASON IS MEASURED, NOT PREFERRED. It used to read
  # as "a genuine pre-existing failure, unattributable, defer". `audit-rule-files.sh` is the
  # counter-example: bare it defaults to `--fail-on=any` while the pre-push passes
  # `--fail-on=deterministic`, so it exits 1 while printing `tier-1 findings: 0` — failing a
  # threshold the hook never applies, identically on both sides. Agreement carries no
  # differential information whatever the code; only DISAGREEMENT does.
  [ "$RC_11" = "SELF-UPDATE-OK" ] \
    && ok "rc 1,1 is OK — equal codes are not a differential signal, and deferring on them stranded every pull touching a script whose bare default differs from the hook's flag" \
    || bad "rc 1,1 gave [$RC_11], expected SELF-UPDATE-OK — a pull touching audit-rule-files.sh still folds the machinery slice into the gated apply"
  # Equality, not a whitelist of codes. If the arm were written as a set of blessed exit codes
  # this would fail, and that is the point of testing a code no script in the tree returns.
  [ "$RC_33" = "SELF-UPDATE-OK" ] \
    && ok "rc 3,3 is OK — the exemption is EQUALITY, not a list of blessed codes" \
    || bad "rc 3,3 gave [$RC_33], expected SELF-UPDATE-OK — the arm is keyed on particular values, so the next script with its own exit vocabulary strands again"
  # THE ARMS THAT KEEP THE WIDENING FROM REMOVING THE GATE. Both sides non-zero but DIFFERENT is
  # still a disagreement, and a disagreement is the only thing this gate can read.
  [ "$RC_21" = "SELF-UPDATE-UNDECIDED" ] \
    && ok "rc 2,1 still defers — two non-zero codes that DISAGREE are not agreement, so widening to equality did not swallow the both-non-zero arm" \
    || bad "rc 2,1 gave [$RC_21], expected SELF-UPDATE-UNDECIDED — the widening reaches unequal pairs and the gate is gone"
  [ "$RC_10" = "SELF-UPDATE-OK" ] \
    && ok "rc 1,0 is OK — an incoming version that FIXES a pre-existing failure cannot block the push" \
    || bad "rc 1,0 gave [$RC_10], expected SELF-UPDATE-OK"

  # MUTANT C — the equality arm narrowed back to v0.288.0's `2 and 2`. A copy, cmp -s guarded,
  # driven through the same rc-pair harness. It must move 1,1 and ONLY 1,1: 2,2 was already
  # covered by the narrow form, so a mutant that moved both would mean the two arms are one
  # assertion wearing two labels.
  GATE_C="$WORK/gate-narrow.sh"
  sed 's|^  if \[ "\$rc_cur" -eq "\$rc_new" \]; then|  if [ "$rc_cur" -eq 2 ] \&\& [ "$rc_new" -eq 2 ]; then|' "$GATE" > "$GATE_C"
  if cmp -s "$GATE" "$GATE_C"; then
    bad "FIXTURE STALE: could not build MUTANT C — the equality arm's condition was reworded, so the widening is asserted by nothing"
  elif ! bash -n "$GATE_C" 2>/dev/null; then
    bad "MUTANT C is not a valid program — its silence would have scored as a kill"
  else
    C_11="$(rcpair 1 1 "$GATE_C")"; C_22="$(rcpair 2 2 "$GATE_C")"
    if [ "$C_11" = "SELF-UPDATE-UNDECIDED" ] && [ "$C_22" = "SELF-UPDATE-OK" ]; then
      ok "MUTANT C killed — narrowed back to 2-and-2, rc 1,1 defers again while 2,2 does not move: the widening is what the 1,1 arm tests"
    else
      bad "MUTANT C moved the wrong set — 1,1 gave [$C_11] (expected SELF-UPDATE-UNDECIDED) and 2,2 gave [$C_22] (expected SELF-UPDATE-OK). Either the 1,1 arm is vacuous or it is entangled with the 2,2 arm."
    fi
  fi
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "self-update-join-gate: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "self-update-join-gate: all assertions passed"
