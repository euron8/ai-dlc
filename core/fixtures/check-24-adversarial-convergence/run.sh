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
# Scrub ambient AI_DLC_* — the live-series arm below reads an expression out of a shipped
# hook, and a consumer that tunes any AI_DLC_* variable in settings.json would otherwise
# fail this fixture against a hook behaving correctly, wedging its pre-push on every push.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
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

# F7: the adjudication's SHAPE. These three carry the same passes, the same anchors and the
# same operator citation as divergent-resolved, which exits 0 -- so the exit code alone
# cannot tell a validator with F7 from one without it, and the messages are the assertion.
expect adjudication-no-options 1 "a resolution recording NO options put to the operator -- FAIL (F7)" s1-adversarial-p
expect_says adjudication-no-options s1-adversarial-p "F7-no-options" \
  "options_presented=<none>" "an operator adjudicates by CHOOSING"
expect adjudication-one-option 1 "one option is a request for approval, not an adjudication -- FAIL (F7)" s1-adversarial-p
expect_says adjudication-one-option s1-adversarial-p "F7-one-option" \
  "options_presented=1" "at least two worked-out"
expect adjudication-no-recommendation 1 "a menu with no recommendation hands the judgment back -- FAIL (F7)" s1-adversarial-p
expect_says adjudication-no-recommendation s1-adversarial-p "F7-no-recommendation" \
  "names no 'recommended_option:'" "who has not read the artifact"

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

# --- v0.355.0: the emphasis pair. Neither of these two can move alone. --------
# repaired-delegated-bold is the FALSE POSITIVE that shipped for nine releases: a complete
# record in the house style, read as UNSTRUCTURED because `[[:space:]-]` has no `*`.
# repair-record-off-label is the floor under the fix: the reader is allowed to tolerate
# EMPHASIS around the taught label and nothing else, so a widening that admits a renamed
# field or a prose line turns this red. Fixing one by breaking the other is not a fix.
expect repaired-delegated-bold   0 "the house style -- '- **disposition:**' is the same field (H)"
expect repair-record-off-label   1 "'edit sites:' / 'derivation (x):' rename the field -- FAIL (H)"
expect_says repair-record-off-label s1-adversarial-pass "H-off-label" \
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

# =============================================================================
# v0.286.0: the LIVE-SERIES DERIVATION the two hooks share (I81)
# =============================================================================
# The validator was never the problem here -- every arm above already worked. What was
# broken is the question asked BEFORE it: "which adversarial cycle is live". Both hooks
# picked the newest glob match and stripped the pass suffix afterwards, so a filename the
# strip could not match became a SERIES that was the whole filename -- which resolves as a
# ONE-PASS series. A one-pass series can never be STALLED or DIVERGENT, so the guard
# returned CONTINUE and the PreToolUse hook allowed the dispatch while a real multi-pass
# series sat stalled. Measured on the reference consumer: 6 of 135 files matching the glob
# defeat the strip.
#
# THIS ARM DRIVES THE SHIPPED EXPRESSION, not a copy of it. The derivation is extracted from
# ai-dlc-acknowledge.sh -- the hook that owns the DENY -- and eval'd. A fixture carrying its
# own copy of the expression would pass while the hook shipped something else, which is the
# defect this whole release is about.
HOOK=""
for cand in \
  "$DIR/../../hooks/ai-dlc-acknowledge.sh" \
  "$DIR/../../../.claude/hooks/ai-dlc-acknowledge.sh" \
  "$DIR/../../core/hooks/ai-dlc-acknowledge.sh"; do
  [ -f "$cand" ] && HOOK="$cand" && break
done

if [ -z "$HOOK" ]; then
  FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  printf '  FAIL  %-28s (cannot locate ai-dlc-acknowledge.sh from %s)\n' "live-series-derivation" "$DIR"
else
  # Seed, under the artifact path grammar: the sprint is the DIRECTORY.
  #   s9/  the LIVE sprint -- a STALLED 3-pass series, plus a NEWER file that matches the
  #        glob and DEFEATS the pass-suffix strip. The decoy keeps the shape of a real
  #        reference-consumer filename (`...adversarial-pass1-...`), not an invented one.
  #   s8/  a DIFFERENT, older sprint whose files are NEWEST by mtime and whose series has
  #        CONVERGED. Nothing about the live sprint is wrong; s8 exists only so that a
  #        reader which forgets to scope by sprint has somewhere wrong to land.
  SD="$ROOT/live-series"; mkdir -p "$SD/s9" "$SD/s8"
  prov() { # <path> <hour> <major-count> <verdict>
    printf '# pass\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\nmode: subagent\nlead_role: stories-test-strategy\ninvoked_at: 2026-08-07T0%s:00:00Z\ntool_use_id: toolu_ls%s\nfindings: 0 CRITICAL, %s MAJOR, 0 MINOR\nfindings_critical: 0\nfindings_major: %s\nfindings_minor: 0\nverdict: %s\nSKILL_INVOCATION_PROVENANCE_END -->\n' \
      "$2" "$2" "$3" "$3" "$4" > "$1"
  }
  for i in 1 2 3; do prov "$SD/s9/stories-adversarial-p$i.md" "$i" 2 EXIT_CONDITION_NOT_MET; done
  sleep 1
  cp "$SD/s9/stories-adversarial-p3.md" "$SD/s9/adversarial-pass1-discovery.md"
  sleep 1
  prov "$SD/s8/prd-adversarial-p1.md" 1 2 EXIT_CONDITION_NOT_MET
  prov "$SD/s8/prd-adversarial-p2.md" 2 0 EXIT_CONDITION_MET

  # $1 label  $2 the derivation expression  $3 expected STATE  $4 expected rc  $5 why
  # SPRINT_N is the DECLARED sprint, supplied here the way the hook supplies it from
  # `sprint-status.sh sprint-id`. An expression that ignores it is exactly the unscoped
  # regression the second mutant below drives.
  ls_expect() {
    local label="$1" expr="$2" want_state="$3" want_rc="$4" why="$5"
    local ART_DIR="$SD" SPRINT_N="9" SERIES="" out state rc
    ASSERTIONS=$((ASSERTIONS + 1))
    eval "$expr"
    if [ -z "$SERIES" ]; then
      state="(empty)"; rc="-"
    else
      out="$(bash "$VALIDATOR" --series "$SERIES" --cycle-state 2>/dev/null)"; rc=$?
      state="$(printf '%s' "$out" | cut -f1)"
    fi
    if [ "$state" = "$want_state" ] && [ "$rc" = "$want_rc" ]; then
      printf '  ok    %-28s %s rc=%s  (%s)\n' "$label" "$state" "$rc" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-28s %s rc=%s  want %s rc=%s  (%s)\n' "$label" "$state" "$rc" "$want_state" "$want_rc" "$why"
    fi
  }

  # THE WHOLE MARKED BLOCK, not one line of it. The derivation stopped being a single
  # assignment when it gained a sprint scope, and a fixture that kept extracting only the
  # `SERIES=` line would eval it with `$SPRINT_DIR` unset -- resolving nothing, every arm
  # reporting `(empty)`, and the mutants below "differing" from a shipped form that never ran.
  #
  # ONE LINE IS DROPPED: the `sprint-status.sh` shell-out. This fixture's subject is what the
  # hook does WITH a declared sprint -- the glob's scope and its filter. Resolving the sprint
  # from an envelope is `divergence-hard-block`'s subject, and it drives the real hooks
  # end-to-end to do it. Supplying SPRINT_N here is the same substitution this harness already
  # makes for ART_DIR.
  SHIPPED="$(awk '/>>> I81 LIVE-SERIES BLOCK >>>/{f=1;next} /<<< I81 LIVE-SERIES BLOCK <<</{f=0} f' "$HOOK" \
             | grep -v 'sprint-status.sh' | sed 's/^[[:space:]]*//')"
  case "$SHIPPED" in
    *adversarial*) : ;;
    *) SHIPPED="" ;;   # extracted something, but not the glob -- treat as no extraction
  esac
  if [ -z "$SHIPPED" ]; then
    FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
    printf '  FAIL  %-28s (extracted no derivation from %s -- the arm below would test nothing)\n' "live-series-derivation" "$(basename "$HOOK")"
  else
    # THE ASSERTION: the shipped expression sees past the decoy to the stalled series.
    ls_expect "live-series-shipped" "$SHIPPED" "STALLED" "3" \
      "the shipped derivation reaches the 3-pass stalled series despite a newer non-conforming file"

    # MUTANT 1 -- REVERT THE FILTER. Scoped correctly, but newest-then-strip. Without it the
    # arm above is consistent with a decoy that never mattered. CONTINUE rc=0 is exactly the
    # silent allow this whole line of work exists to remove.
    ls_expect "live-series-unfiltered" \
      'SERIES="$(ls -t "${ART_DIR}/s${SPRINT_N}"/*adversarial*p*.md 2>/dev/null | head -1 | sed -E '"'"'s/(pass|p)[0-9]+\.md$//'"'"')"' \
      "CONTINUE" "0" \
      "MUTANT: newest-then-strip resolves the decoy as a one-pass series and reports a clean cycle"

    # MUTANT 2 -- REVERT THE SCOPE. Filters correctly, but asks every sprint instead of the
    # declared one, so mtime hands it s8's CONVERGED series while s9 sits stalled. This is
    # the defect both hooks confessed to in their own comments for four releases: a clean
    # verdict read off a cycle that is not the live one.
    ls_expect "live-series-unscoped" \
      'SERIES="$(ls -t "${ART_DIR}"/s*/*adversarial*p*.md 2>/dev/null | sed -E -n '"'"'s/(pass|p)[0-9]+\.md$//p'"'"' | head -1)"' \
      "CONVERGED" "0" \
      "MUTANT: an unscoped glob adjudicates the newest sprint on disk (s8, converged), not the declared one"

    # UNMUTATED CONTROL. Remove BOTH variables -- the decoy and the other sprint -- and all
    # three forms must agree. That is what pins each difference above on its own variable
    # rather than on three expressions that disagree about everything.
    rm -f "$SD/s9/adversarial-pass1-discovery.md"; rm -rf "$SD/s8"
    ls_expect "live-series-control-shipped" "$SHIPPED" "STALLED" "3" \
      "CONTROL: one sprint, no decoy — the shipped form is correct here too"
    ls_expect "live-series-control-unfiltered" \
      'SERIES="$(ls -t "${ART_DIR}/s${SPRINT_N}"/*adversarial*p*.md 2>/dev/null | head -1 | sed -E '"'"'s/(pass|p)[0-9]+\.md$//'"'"')"' \
      "STALLED" "3" \
      "CONTROL: with no decoy the unfiltered form is correct too, so the decoy is the variable"
    ls_expect "live-series-control-unscoped" \
      'SERIES="$(ls -t "${ART_DIR}"/s*/*adversarial*p*.md 2>/dev/null | sed -E -n '"'"'s/(pass|p)[0-9]+\.md$//p'"'"' | head -1)"' \
      "STALLED" "3" \
      "CONTROL: with only one sprint on disk the unscoped form is correct too, so s8 is the variable"
  fi
fi

echo
# =============================================================================
# v0.355.0 -- H-BIND. The reader and the taught form are ONE decision in two files.
#
# The cases above prove arm H accepts the bold form and rejects a renamed field. They do
# NOT prove the form arm H accepts is the form remediator.md TEACHES -- and for nine
# releases it was not: the template wrote `- disposition:`, the reader read exactly that,
# the seed seeded exactly that, and every record the reference consumer actually wrote
# used the bold form that none of the three admitted. Three files agreeing with each other
# and disagreeing with reality is what a fixture seeded from its own reader cannot see.
#
# So this arm runs the validator's OWN repair_field on the template's OWN field lines,
# both extracted from their files at run time. It evals the definition rather than
# restating the regex: a copy here could be wrong in the fixture and right in the
# validator, and the join would report clean.
# =============================================================================
bind_fail() { FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s %s\n' "H-BIND" "$1"; }
bind_ok()   { printf '  ok    %-28s %s\n' "H-BIND" "$1"; }

# Both layouts, rooted at this fixture's own self-location (I33) -- never walked up from
# $VALIDATOR, whose parent is `core/scripts` here and `scripts/ai-dlc` on a consumer.
REMEDIATOR=""
for cand in \
  "$DIR/../../team-roles/remediator.md" \
  "$DIR/../../../.claude/team-roles/remediator.md"; do
  [ -f "$cand" ] && REMEDIATOR="$cand" && break
done
GATEDOC=""
for cand in \
  "$DIR/../../skills/ai-dlc/steps/gate-validation.md" \
  "$DIR/../../../.claude/skills/ai-dlc/steps/gate-validation.md"; do
  [ -f "$cand" ] && GATEDOC="$cand" && break
done

ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$REMEDIATOR" ] || [ -z "$GATEDOC" ]; then
  bind_fail "FIXTURE BROKEN: remediator.md=${REMEDIATOR:-<not found>} gate-validation.md=${GATEDOC:-<not found>} from $DIR"
else
  # --- extract the reader ----------------------------------------------------
  # Exactly one one-line definition, or the eval below silently binds the wrong thing.
  n_fn="$(grep -c '^repair_field() {' "$VALIDATOR")"
  fn="$(grep -m1 '^repair_field() {' "$VALIDATOR")"
  # --- extract the taught form ----------------------------------------------
  # The three field lines of remediator.md's per-finding template, as written there.
  # sed -E, not BRE: `\|` alternation is a GNU extension and matches nothing under the
  # BSD sed on macOS. The first draft used it, extracted 0 lines, and was caught by the
  # count guard below rather than by every assertion quietly passing over an empty set.
  tmpl="$(sed -E -n 's/^(- (disposition|edit|derivation):).*/\1/p' "$REMEDIATOR" | sort -u)"
  n_tmpl="$(printf '%s\n' "$tmpl" | grep -c .)"

  if [ "$n_fn" -ne 1 ] || [ "$n_tmpl" -ne 3 ]; then
    # A ZERO HERE IS NOT A FINDING. If the definition were renamed or the template
    # reworded, every assertion below would pass over an empty set and report clean.
    bind_fail "FIXTURE BROKEN: extracted $n_fn repair_field definitions (want 1) from $VALIDATOR and $n_tmpl template field lines (want 3) from $REMEDIATOR"
  else
    eval "$fn"
    BT="$ROOT/bind"; mkdir -p "$BT"
    bind_miss=""
    # Every taught line must read, as written AND with the emphasis the house style adds.
    printf '%s\n' "$tmpl" | while IFS= read -r line; do
      [ -n "$line" ] || continue
      lbl="${line#- }"; lbl="${lbl%%:*}"
      printf '%s repaired\n' "$line"                     > "$BT/plain-$lbl.md"
      printf -- '- **%s:** repaired\n' "$lbl"            > "$BT/bold-$lbl.md"
      printf -- '  _%s:_ repaired\n' "$lbl"              > "$BT/ital-$lbl.md"
      for form in plain bold ital; do
        repair_field "$lbl" "$BT/$form-$lbl.md" || printf '%s\n' "$form:$lbl" >> "$BT/misses"
      done
    done
    # CONTROL, and it is the one that matters: the eval'd reader must still REJECT. A
    # function that returned 0 unconditionally would pass every assertion above.
    printf 'The disposition was recorded and the edit made; see the derivation.\n' > "$BT/prose.md"
    printf -- '- **edit sites:** a.md:4\n- derivation (why): x\n### Derivation 1 — y\n' > "$BT/offlabel.md"
    for lbl in disposition edit derivation; do
      repair_field "$lbl" "$BT/prose.md"    && printf '%s\n' "control-prose:$lbl"    >> "$BT/misses"
      repair_field "$lbl" "$BT/nonexistent" 2>/dev/null && printf '%s\n' "control-absent:$lbl" >> "$BT/misses"
    done
    repair_field edit       "$BT/offlabel.md" && printf 'control-offlabel:edit\n'       >> "$BT/misses"
    repair_field derivation "$BT/offlabel.md" && printf 'control-offlabel:derivation\n' >> "$BT/misses"
    bind_miss="$(cat "$BT/misses" 2>/dev/null | tr '\n' ' ')"
    if [ -n "$bind_miss" ]; then
      bind_fail "the reader in $VALIDATOR and the template in $REMEDIATOR disagree: $bind_miss"
    else
      bind_ok "reader accepts all 3 taught labels plain/bold/italic and rejects prose + renamed fields"
    fi
  fi

  # --- the third statement of the same three labels --------------------------
  # gate-validation.md teaches arm H to the lead. It is prose, so this is a token join,
  # not a grammar one -- but a label dropped from it is a label nobody is taught.
  ASSERTIONS=$((ASSERTIONS + 1))
  gv_miss=""
  for lbl in disposition edit derivation; do
    grep -qF "\`$lbl:\`" "$GATEDOC" || gv_miss="$gv_miss $lbl"
  done
  gv_ctl="$(grep -c 'REPAIR-RECORD\|arm H' "$GATEDOC")"
  if [ "$gv_ctl" -eq 0 ]; then
    bind_fail "FIXTURE BROKEN: $GATEDOC names no arm H at all, so the label check below reads a file that moved"
  elif [ -n "$gv_miss" ]; then
    bind_fail "$GATEDOC teaches arm H but no longer names:$gv_miss (control: $gv_ctl arm-H mentions in the same file)"
  else
    bind_ok "gate-validation.md names all 3 labels the reader reads"
  fi
fi

# --- the MAJOR split: findings_major_underived --------------------------------
# UNPROVEN used to block the exit exactly as hard as WRONG, because the exit condition reads
# findings_major and adversary.md grades an underived claim a MAJOR "whether or not you can
# yet falsify it". These five are a partition of the ways the split can be got wrong, and the
# last one is the migration proof.
expect underived-exits               0 "0C, 3M ALL underived: 0 blocking -- MET is honest" s1-adversarial-p
expect underived-partial-blocks      1 "0C, 3M with 2 underived: ONE blocking MAJOR -- MET is a false convergence (B)" s1-adversarial-p
expect underived-exceeds             1 "4 underived of 3 MAJOR: the partition cannot exceed the whole (B)" s1-adversarial-p
expect underived-refuses             1 "0 blocking and still NOT_MET -- the residue IS the exit condition (B)" s1-adversarial-p
expect underived-absent-still-blocks 1 "MIGRATION: same residue, NO field -- absent means ZERO, so it still blocks" s1-adversarial-p

# The exit codes above are necessary and not sufficient: three of those four failures are arm
# B, so a message naming the wrong quantity would score identically.
expect_says underived-partial-blocks s1-adversarial-p "B-blocking-count" \
  "1 blocking MAJOR" "3 MAJOR less 2 underived"
expect_says underived-exceeds s1-adversarial-p "B-partition" \
  "findings_major_underived=4" "3 MAJOR"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
