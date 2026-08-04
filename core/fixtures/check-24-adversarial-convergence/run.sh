#!/usr/bin/env bash
# Exercise validate-adversarial-convergence.sh against the check-24 fixture.
#
# Exit 0 iff the validator returns the correct verdict on every seeded series.
#
# TWO CASES DECIDE SHIPPABILITY, and they pull in opposite directions:
#
#   nitpicks-remain    must PASS. A naive "the last pass must have zero findings"
#                      implementation fails it, and in doing so makes the exit condition
#                      "continue until only nitpicks remain" unreachable -- the v0.46.0
#                      defect, reintroduced one layer down.
#   divergent-resolved must PASS. It is the SANCTIONED EXIT from a hard block, and before
#                      v0.59.0 it did not exist: arm D demanded a terminal clean pass while
#                      the Stop hook's deny reason said "do NOT dispatch another adversarial
#                      pass, and do NOT clear the pause flag to get past this." If this case
#                      goes red, the deadlock is back.
#
# AND A RULE ABOUT HOW THIS FILE ASSERTS. Several v0.59.0 cases exit 1 BOTH before and after
# the fix -- `stalled-then-diverges` exits 1 today via arm D alone and exits 1 after via arms
# D and E. A fixture that checked only the exit code would score a FALSE PASS against the
# broken validator. That is this repo's own defect class (a check that cannot fire reads
# exactly like one that passed) reproduced inside the test written to catch it. So: every
# v0.59.0 case asserts on the MESSAGE.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-adversarial-convergence.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-adversarial-convergence.sh" \
  "$DIR/../../core/scripts/validate-adversarial-convergence.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "FAIL: cannot locate validate-adversarial-convergence.sh from $DIR"
  exit 1
fi

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT

# The transcript the RESOLUTION citations (arm F6) verify against. Every invocation passes
# it, exactly as the real Check 24 gate and the acknowledge hook do -- a resolution clears an
# operator-gated HARD_BLOCK, so the gate must be handed the ground truth to check the citation.
TRANSCRIPT="$ROOT/operator-transcript.jsonl"

FAILURES=0
ASSERTIONS=0

# $1 case-dir  $2 expected exit (0|1)  $3 why  $4 (optional) series prefix
expect() {
  local case_dir="$1" want="$2" why="$3" prefix="${4:-s1-adversarial-pass}" got out
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$ROOT/$case_dir/$prefix" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ok    %-28s exit=%s  (%s)\n' "$case_dir" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s exit=%s want=%s  (%s)\n' "$case_dir" "$got" "$want" "$why"
    printf '%s\n' "$out" | sed 's/^/          | /'
  fi
}

# $1 case-dir  $2 series prefix  $3 label  $4... required substrings (ALL must appear)
# The exit code is NOT the assertion here -- the message is. See the header.
expect_says() {
  local case_dir="$1" prefix="$2" label="$3"; shift 3
  local out missing=""
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$ROOT/$case_dir/$prefix" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  for want in "$@"; do
    grep -qF -- "$want" <<<"$out" || missing="$missing
            missing: \"$want\""
  done
  if [ -z "$missing" ]; then
    printf '  ok    %-28s %s\n' "$label" "says what it must"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s\n' "$label" "the right exit code for the WRONG reason:$missing"
  fi
}

# $1 case-dir  $2 series prefix  $3 expected STATE  $4 expected exit  $5 why
expect_state() {
  local case_dir="$1" prefix="$2" want_state="$3" want_rc="$4" why="$5" out state rc
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$ROOT/$case_dir/$prefix" --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null)"
  rc=$?
  state="$(printf '%s' "$out" | cut -f1)"
  if [ "$state" = "$want_state" ] && [ "$rc" -eq "$want_rc" ]; then
    printf '  ok    %-28s %s/%s  (%s)\n' "$case_dir" "$state" "$rc" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s/%s want=%s/%s  (%s)\n' \
      "$case_dir" "${state:-<none>}" "$rc" "$want_state" "$want_rc" "$why"
  fi
}

echo "check-24 adversarial-convergence fixture"
echo

# --- backward compatibility (pre-v0.52.0 artifacts: no prior_scope field) -----
expect converged           0 "clean terminal pass -- the cycle the machinery should produce"
expect nitpicks-remain     0 "THE DECOY: 0C/0M with 5 MINOR open is 'only nitpicks remain' -- MET"
expect refused-to-converge 1 "S289 pass-4 shape: clean residue, still stamps NOT_MET"
expect divergent           1 "no field, CRITICALs 3 -> 6, no DHB: the default is FAIL-CLOSED"
expect no-verdict          1 "a pass with no verdict: key is un-adjudicable"

echo
# --- v0.52.0: the scope-relative predicate ------------------------------------
expect scope-grew-converges   0 "RELEASE: CRIT rise 2->3 but only 1 in prior scope -- NOT divergence"
expect repair-injected        1 "3 of 3 CRIT in PRIOR scope: real divergence still caught"
expect scope-grew-unconverged 1 "never converges on a MOVING artifact -- FAIL (D)"
expect_says scope-grew-unconverged s1-adversarial-pass "D-remedy" \
  "MOVING ARTIFACT" "CUT the added scope"

echo
# --- v0.55.3: numeric ordering + the STALL rung -------------------------------
expect long-series-p-naming 0 "11 passes, -p<N>: ordered NUMERICALLY, so p11 (MET) is terminal, not p9" s1-adversarial-p
expect stalled              1 "0 CRITICAL, MAJOR pinned at 1 for 3 passes -- STALLED, FAIL (E)" s1-adversarial-p
expect stall-then-converges 0 "DECOY: holds MAJOR one pass short of K, then clears it -- E must NOT fire" s1-adversarial-p
expect_says stalled s1-adversarial-p "E-remedy" \
  "E -- STALL" "ANOTHER PASS IS NOT THE REMEDY" "VERIFY THE DISPUTED FACT MECHANICALLY"

# E must PRE-EMPT D. A stalled series that merely inherits D's generic "run another pass to
# a clean verdict" is the bug wearing a new error code.
ASSERTIONS=$((ASSERTIONS + 1))
if bash "$VALIDATOR" --series "$ROOT/stalled/s1-adversarial-p" 2>&1 \
   | grep -q "Either run another pass to a clean verdict"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s a STALLED series still got Check D generic advice. E must pre-empt D.\n' "stall-preempts-d"
else
  printf '  ok    %-28s E pre-empts D: the stalled series is not told to run another pass\n' "stall-preempts-d"
fi

echo
# --- v0.59.0: THE RESUME CONTRACT ---------------------------------------------

# THE RELEASE. If this goes red, the sanctioned exit is gone and the deadlock is back.
expect divergent-resolved 0 "THE RELEASE: hard block -> REVERT_REPAIR record -> verification pass -> MET" s1-adversarial-p

# D2: arm E must be REACHABLE when the series ends DIVERGENT, and must name the PEAK.
# Exits 1 before and after -- only the message distinguishes a fixed validator from a broken one.
expect stalled-then-diverges 1 "plateau at p2-p4, then divergent p5: BOTH D and E must fire" s1-adversarial-p
expect_says stalled-then-diverges s1-adversarial-p "E-reachable-past-D" \
  "E -- STALL" "should have STOPPED at" "s1-adversarial-p4.md"

# F1: a pass ran after a hard block and declared nothing.
expect divergent-unresolved 1 "p3 ran after p2's hard block, declaring no resolution -- FAIL (F)" s1-adversarial-p
expect_says divergent-unresolved s1-adversarial-p "F1-declared" \
  "F -- RESOLUTION" "STOP -> ADJUDICATE -> RESOLVE -> VERIFY" "resolves_divergence"

# F3: THE LIVE DEADLOCK. Freezing cannot clear a hard block, and the message must say why.
expect divergent-frozen 1 "FREEZE_SCOPE cannot resolve a prior-scope hard block -- FAIL (F)" s1-adversarial-p
expect_says divergent-frozen s1-adversarial-p "F3-freeze-is-void" \
  "does not remove a CRITICAL that is already inside the frozen text" \
  "ALREADY FROZEN"

# F5: the two launder paths that close by arithmetic and by construction.
expect divergent-laundered-cut 1 "CUT_SCOPE that GREW: a repair wearing a resolution's name" s1-adversarial-p
expect_says divergent-laundered-cut s1-adversarial-p "F5-cut-arithmetic" \
  "declares CUT_SCOPE but the artifact did not shrink"
expect divergent-laundered-revert 1 "REVERT_REPAIR landing on a sha no pass ever notarized" s1-adversarial-p
expect_says divergent-laundered-revert s1-adversarial-p "F5-revert-construction" \
  "matches no" "earlier pass in this series"

# D4/G: the dead cycle's tail.
expect restart-cycle 1 "restart left p4-p6 of the dead cycle on disk -- FAIL (G)" s1-adversarial-p
# The message must name BOTH causes. Driving this against the reference consumer's live series
# fired G on a pass whose `invoked_at` was simply MIS-TYPED — and the first draft of the message
# confidently diagnosed a dead-cycle tail. An error message that asserts the wrong cause with
# confidence is the exact defect v0.57.0's changelog shipped, in the release that retracts it.
expect_says restart-cycle s1-adversarial-p "G-chronology" \
  "G -- CHRONOLOGY" "DEAD CYCLE'S TAIL" "archive the abandoned series" \
  "A MIS-STAMPED" "Do not back-fit it to make"

# Arm A: the free bypass. Omit findings_major on one pass and arm E used to go dark.
expect counts-omitted 1 "a verdict with no derivable MAJOR count turns arm E OFF -- FAIL (A)" s1-adversarial-p
expect_says counts-omitted s1-adversarial-p "A-counts-required" \
  "severity counts are not derivable" "arm E in particular goes SILENT"

echo
# --- v0.103.0: arm H, the repair-record ---------------------------------------
# THE DIFFERENTIAL. repaired-delegated and repaired-inline-no-record have BYTE-IDENTICAL
# pass series; the only difference on disk is the two repair records. If arm H is
# neutralized (does not stat the record), repaired-inline-no-record flips to exit 0 and
# the assertion below goes red -- the fixture cannot pass a validator that ignores the
# record. That is the mutation proof, baked into the pair.
expect repaired-delegated        0 "converging series WITH repair records -- arm H satisfied"
expect repaired-inline-no-record 1 "S295: same series, NO repair records -- the lead repaired inline (H)"
expect_says repaired-inline-no-record s1-adversarial-pass "H-missing-record" \
  "H -- REPAIR-RECORD" "the lead does not repair the artifact itself"
expect repair-record-empty       1 "a narrative stub is not a structured repair record -- FAIL (H)"
expect_says repair-record-empty s1-adversarial-pass "H-structure" \
  "H -- REPAIR-RECORD" "not a structured record"

echo
# --- v0.59.0: --cycle-state, the mode the hooks call --------------------------
# The hooks hold NO logic. They shell out, read the exit code, and deny on 3. These five
# assertions are the entire contract between the validator and both hooks.
expect_state in-progress               s1-adversarial-p CONTINUE  0 "DECOY: healthy NOT_MET cycle -- arm D must NOT run here"
expect_state converged                 s1-adversarial-pass CONVERGED 0 "terminal MET: nothing to stop"
expect_state stalled                   s1-adversarial-p STALLED   3 "the STOP code: another pass is not the remedy"
expect_state divergent-terminal        s1-adversarial-p DIVERGENT 3 "the reference consumer's parked state, exactly"
expect_state divergent-terminal-resolved s1-adversarial-p RESOLVED 0 "THE RESUME: the record exists, so the verification pass is permitted"

# --- the sanctioned exit from a STALL ------------------------------------------
expect_state stalled              s1-adversarial-p STALLED  3 "no record: the stall stands"
expect_state stalled-resolved     s1-adversarial-p RESOLVED 0 "SAME trajectory + a valid record: the verification pass is legal. RESOLVED was unreachable for a stall and the branch was dead code"
expect_state stalled-record-invalid s1-adversarial-p STALLED 3 "OVER-FIRE CONTROL: an INVALID record legalises nothing, or the resume is reachable by writing any file"

# --- MUTATION: the stall call site is what makes RESOLVED reachable ------------
# Neuter ONLY the new terminal-record lookup on the stall path. `stalled-resolved` must go
# back to STALLED/3 -- the shipped defect on demand -- and `stalled` and
# `stalled-record-invalid` must be UNCHANGED, because a mutant that moves all three is too
# broad to attribute.
MUT="$ROOT/mutant-stall-resolution.sh"
MUT_OLD='  terminal_record_resolves "$((N - 1))" && RESOLVED_TERMINAL=1' \
MUT_NEW='  : ' \
python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$VALIDATOR" "$MUT"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$VALIDATOR" "$MUT"; then
  echo "  FAIL  MUTATION matched nothing -- the stalled-resolved assertion proves nothing" >&2
  FAILURES=$((FAILURES + 1))
else
  m_res="$(bash "$MUT" --series "$ROOT/stalled-resolved/s1-adversarial-p" --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null | cut -f1)"
  m_pln="$(bash "$MUT" --series "$ROOT/stalled/s1-adversarial-p"          --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null | cut -f1)"
  m_inv="$(bash "$MUT" --series "$ROOT/stalled-record-invalid/s1-adversarial-p" --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null | cut -f1)"
  if [ "$m_res" = "STALLED" ] && [ "$m_pln" = "STALLED" ] && [ "$m_inv" = "STALLED" ]; then
    printf '  ok    %-28s %s  (%s)\n' "MUTATION stall-resolution" "STALLED" "without the stall call site RESOLVED is unreachable again; the other two are unmoved, so the mutant is attributable"
  else
    echo "  FAIL  MUTATION: expected stalled-resolved to revert to STALLED, got '$m_res' (plain='$m_pln' invalid='$m_inv')" >&2
    FAILURES=$((FAILURES + 1))
  fi
fi

# --- the citation must OUTLIVE the session that wrote it ------------------------
# `stalled-resolved`'s operator adjudication lives in `prior-session-transcript.jsonl`,
# NOT in the current session's transcript. That is the real shape: a resolution record
# outlives its session, and `transcript_path` is always the session ASKING permission,
# never the one in which the operator spoke.
#
# The pair is the assertion. Current transcript alone -> the citation is unfindable, the
# record stops counting and the stall re-deadlocks. Add the DIRECTORY the transcripts
# actually live in and the same record verifies. Same tree, same record, same citation.
cs_state() {  # cs_state <extra-args...> -> prints the state
  bash "$VALIDATOR" --series "$ROOT/stalled-resolved/s1-adversarial-p" --cycle-state \
    --transcript "$TRANSCRIPT" "$@" 2>/dev/null | cut -f1
}
ASSERTIONS=$((ASSERTIONS + 2))
got_nodir="$(cs_state)"
got_dir="$(cs_state --transcript-dir "$ROOT")"
if [ "$got_nodir" = "STALLED" ]; then
  printf '  ok    %-28s %s  (%s)\n' "cross-session (no dir)" "STALLED" "a citation from a PRIOR session is unfindable in one transcript -- the deadlock"
else
  echo "  FAIL  cross-session (no dir): expected STALLED, got '$got_nodir'" >&2; FAILURES=$((FAILURES + 1))
fi
if [ "$got_dir" = "RESOLVED" ]; then
  printf '  ok    %-28s %s  (%s)\n' "cross-session (with dir)" "RESOLVED" "the SAME record verifies against the corpus the citation actually lives in"
else
  echo "  FAIL  cross-session (with dir): expected RESOLVED, got '$got_dir'" >&2; FAILURES=$((FAILURES + 1))
fi

# --- arm J: RE-OPEN ------------------------------------------------------------
expect reopen-unrecorded 1 "a pass ran after EXIT_CONDITION_MET reporting 1C/2M -- RE-OPEN, FAIL (J)" s1-adversarial-p
expect reopen-floor-pass 0 "THE DECOY: p1 MET -> p2 MET with 0 findings is the intensity FLOOR, not a re-open" s1-adversarial-p
expect reopen-recorded   0 "a re-open DECLARED with resolution: REOPEN_AFTER_MET resumes -- the arm has a door" s1-adversarial-p
expect_state reopen-unrecorded s1-adversarial-p REOPENED  3 "the hooks must deny the dispatch on a live re-open"
expect_state reopen-floor-pass s1-adversarial-p CONVERGED 0 "the floor pass must not be denied"
expect_state reopen-recorded   s1-adversarial-p CONVERGED 0 "a declared re-open ran its sub-cycle to convergence -- never denied"
echo
# --- arm I: RESOLUTION CEILING -------------------------------------------------
# The four cases carry the SAME five-pass series and differ only in the records beside
# it. Any rung that reads the series cannot separate them; that is the point.
expect_state ceiling-unanchored        s1-adversarial-p CEILING   3 "the exit taken TWICE, second release unanchored -- the hooks must deny"
expect_state ceiling-anchored-release  s1-adversarial-p CONTINUE  0 "THE DOOR: same series, second release CUT_SCOPE (bytes fell) -- without this the arm wedges every twice-resolved cycle"
expect_state ceiling-single-resolution s1-adversarial-p CONTINUE  0 "THE DECOY: ONE unanchored release is the SANCTIONED exit and must cost nothing"
expect_state ceiling-converged         s1-adversarial-p CONVERGED 0 "two unanchored releases but the cycle TERMINATED -- no gate fails retroactively"

expect ceiling-unanchored 1 "gate: a cycle released twice without an anchor does not pass" s1-adversarial-p
expect ceiling-converged  0 "gate: it converged; the arm is suppressed by the terminal verdict" s1-adversarial-p
expect_says ceiling-unanchored s1-adversarial-p "I-remedy" \
  "I -- CEILING" "RELEASED too cheaply" "CUT_SCOPE" "REVERT_REPAIR"

# I must PRE-EMPT D, for the same reason E does: a series told to "run another pass to a
# clean verdict" has been handed the advice that produced the passes.
ASSERTIONS=$((ASSERTIONS + 1))
if bash "$VALIDATOR" --series "$ROOT/ceiling-unanchored/s1-adversarial-p" \
     --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1 \
   | grep -q "Either run another pass to a clean verdict"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s a CEILING series still got Check D generic advice. I must pre-empt D.\n' "ceiling-preempts-d"
else
  printf '  ok    %-28s I pre-empts D: the released-twice series is not told to run another pass\n' "ceiling-preempts-d"
fi

# --- MUTATION: each conjunct of arm I, one at a time ---------------------------
# THE COPIES NEED A SIBLING. `STEER_SCRIPT` is resolved as `$(dirname "$0")/…`, so a
# validator copied into $ROOT cannot find validate-steering-budget.sh, every
# operator_authorization becomes UNVERIFIABLE, and --cycle-state FAILS OPEN on it. A
# mutant that cannot check a citation is not testing this arm -- it is testing the copy.
# Hence the sibling, and hence the unmutated control below, which must reproduce all four
# real verdicts before any mutant's changed verdict is attributable to its mutation.
cp "$(cd "$(dirname "$VALIDATOR")" && pwd)/validate-steering-budget.sh" "$ROOT/validate-steering-budget.sh" 2>/dev/null

mstate() {  # mstate <script> <case-dir> -> the --cycle-state STATE
  bash "$1" --series "$ROOT/$2/s1-adversarial-p" --cycle-state \
    --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null | cut -f1
}

CEIL_CASES="ceiling-unanchored ceiling-anchored-release ceiling-single-resolution ceiling-converged"
CEIL_REAL="CEILING CONTINUE CONTINUE CONVERGED"

# THE UNMUTATED CONTROL. A lone copy that dies sourcing or mis-resolves a sibling emits
# nothing, and "no output" otherwise scores as a kill on every mutant below.
CTRL="$ROOT/control-unmutated.sh"
cp "$VALIDATOR" "$CTRL"
ASSERTIONS=$((ASSERTIONS + 1))
ctrl_got=""
for c in $CEIL_CASES; do ctrl_got="$ctrl_got $(mstate "$CTRL" "$c")"; done
if [ "$(echo $ctrl_got)" = "$(echo $CEIL_REAL)" ]; then
  printf '  ok    %-28s %s\n' "CONTROL unmutated copy" "reproduces all four verdicts from \$ROOT, so a mutant's change is the mutation"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s got [%s] want [%s] -- the harness itself is what fails; every mutant below is vacuous\n' \
    "CONTROL unmutated copy" "$(echo $ctrl_got)" "$(echo $CEIL_REAL)"
fi

# $1 label  $2 old-text  $3 new-text  $4 expected four states (space separated)
# A mutant must fail ONLY its own assertion: two moved cases mean the conjuncts are
# entangled and one of them is vacuous.
mutate_ceiling() {
  local label="$1" old="$2" new="$3" want="$4" got="" c
  # `mut` on its own line: bash 3.2 expands every word of a `local` before assigning any
  # of them, so `mut="$ROOT/mutant-$label.sh"` on the line above reads $label UNSET and
  # dies under `set -u`.
  local mut="$ROOT/mutant-$label.sh"
  ASSERTIONS=$((ASSERTIONS + 1))
  MUT_OLD="$old" MUT_NEW="$new" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation matched NOTHING -- this assertion proves nothing\n' "MUTATION $label"
    return
  fi
  # cmp proves bytes moved; bash -n proves the mutant is still a PROGRAM. A mutant that
  # dies on a syntax error emits nothing, and nothing scores as a kill.
  if ! bash -n "$mut" 2>/dev/null; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutant is not a valid shell script -- its silence is not a kill\n' "MUTATION $label"
    return
  fi
  for c in $CEIL_CASES; do got="$got $(mstate "$mut" "$c")"; done
  if [ "$(echo $got)" = "$(echo $want)" ]; then
    printf '  ok    %-28s [%s]\n' "MUTATION $label" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "MUTATION $label" "$(echo $got)" "$(echo $want)"
  fi
}

# (1) The KIND conjunct. Anchored on `case "$CEILING_KIND" in`, which is UNIQUE --
#     `CHANGE_APPROACH|RESTART_CYCLE)` alone appears TWICE in this file (validate_record's
#     F5 arm is the other), and a bare replace would silently mutate that instead and
#     come out green here.
mutate_ceiling kind \
  'case "$CEILING_KIND" in
    CHANGE_APPROACH|RESTART_CYCLE)' \
  'case "$CEILING_KIND" in
    *)' \
  "CEILING CEILING CONTINUE CONVERGED"

# (2) The COUNT conjunct: the sanctioned single resolution stops being free.
mutate_ceiling count \
  'if [ "$CEILING_COUNT" -gt "$RESOLUTION_CEILING" ] && [ "$LAST_VERDICT" != "EXIT_CONDITION_MET" ]; then' \
  'if [ "$CEILING_COUNT" -gt 0 ] && [ "$LAST_VERDICT" != "EXIT_CONDITION_MET" ]; then' \
  "CEILING CONTINUE CEILING CONVERGED"

# (3) The arm itself: no record is ever counted, so it can never fire. This is the mutant
#     that proves arm I can fire at all -- without it the three cases above are consistent
#     with an arm that is simply absent.
mutate_ceiling counter \
  '    CEILING_COUNT=$((CEILING_COUNT + 1))' \
  '    : ' \
  "CONTINUE CONTINUE CONTINUE CONVERGED"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
