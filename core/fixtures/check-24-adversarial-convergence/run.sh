#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
expect stalled              1 "0 CRITICAL, blocking MAJOR pinned at 4 -- ABOVE the exit ceiling of 3 -- for 3 passes: STALLED, FAIL (E)" s1-adversarial-p
expect stall-then-converges 0 "DECOY: holds MAJOR one pass short of K, then clears it -- E must NOT fire" s1-adversarial-p
expect_says stalled s1-adversarial-p "E-remedy" \
  "E -- STALL" "ANOTHER PASS IS NOT THE REMEDY" "VERIFY THE DISPUTED FACT MECHANICALLY"

# E must PRE-EMPT D. A stalled series that merely inherits D's generic "run another pass to
# a clean verdict" is the bug wearing a new error code.
#
# THE TOKEN IS ONE THE MESSAGE ACTUALLY CARRIES ON ONE LINE. Arm D's generic remedy wraps
# between "Either run another pass to a" and "clean verdict", so the obvious phrase spans a
# newline, is absent from the output of EVERY series, and an absence arm keyed on it can
# never fire. Measured: 0 occurrences in the validator against a control of 1 for the line
# below. Both pre-empt arms were keyed that way, and both were dead.
# The POSITIVE control for this token is `D-generic-at-pass1` further down, which requires
# it to APPEAR: without it, an arm D that stopped emitting the remedy passes both arms here.
D_GENERIC="Do not pass the gate by overriding the field in prose."
ASSERTIONS=$((ASSERTIONS + 1))
if bash "$VALIDATOR" --series "$ROOT/stalled/s1-adversarial-p" 2>&1 \
   | grep -qF -- "$D_GENERIC"; then
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

# --- G across the two stamped forms (BL-371): the ordering KEY, not the raw string ---------
# Each pair sits inside ONE second, so a different-second comparison cannot separate them.
expect chrono-fraction-forward 0 "19Z then 19.497Z: 497 ms LATER, so the chain is in order" s1-adversarial-p
expect chrono-fraction-equal   0 "19.000Z then 19Z: the SAME instant, so nothing ran first" s1-adversarial-p
expect chrono-fraction-backward 1 "19.497Z then 19Z: the second pass was written 497 ms FIRST -- FAIL (G)" s1-adversarial-p
expect_says chrono-fraction-backward s1-adversarial-p "G-fraction-backward" "G -- CHRONOLOGY"
expect_silent chrono-fraction-forward "G -- CHRONOLOGY" chrono-fraction-backward \
  "a raw string comparison reads the fractional stamp as EARLIER, because '.' sorts before 'Z'"
expect_silent chrono-fraction-equal "G -- CHRONOLOGY" chrono-fraction-backward \
  "a comparison with the Z stripped reads '19' as earlier than '19.000', a prefix, not a time"

# --- MUTATION: arm G's comparison, one wrong key per cell ---------------------------------
# Three cells, four validators. Each wrong comparison is one an author would write, and each
# moves a DIFFERENT cell, so the three cells together are what pin the key:
#
#                         forward  backward  equal
#   shipped (at_key)      -        G         -
#   raw string            G        -         -       <- the BL-371 defect
#   Z stripped            -        G         G
#   arm G removed         -        -         -
G_ANCHOR='    if [[ "$AT_KEY" < "$PREV_AT_KEY" ]]; then'
G_CASES="chrono-fraction-forward chrono-fraction-backward chrono-fraction-equal"
g_fired() {  # $1 script  $2 case -> G or -
  case "$(bash "$1" --series "$ROOT/$2/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)" in
    *"G -- CHRONOLOGY"*) printf 'G\n' ;;
    *) printf -- '-\n' ;;
  esac
}
g_score() {  # $1 label  $2 script  $3 expected row
  local got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  for c in $G_CASES; do got="$got $(g_fired "$2" "$c")"; done
  if [ "$(echo $got)" = "$3" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$3"
  fi
}
ASSERTIONS=$((ASSERTIONS + 1))
g_n="$(grep -cF -- "$G_ANCHOR" "$VALIDATOR")" || g_n=0
g_ctl="$(grep -cF -- "$G_ANCHOR-no-such-line" "$VALIDATOR")" || g_ctl=0
if [ "$g_n" -ne 1 ] || [ "$g_ctl" -ne 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s the anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0) -- the mutants below prove nothing\n' \
    "MUTATION g-anchor" "$g_n" "$g_ctl"
else
  printf '  ok    %-28s the anchor is unique (impossible-anchor control: 0)\n' "MUTATION g-anchor"
fi
# THE UNMUTATED CONTROL carries a positive cell (backward = G), so a copy that died emitting
# nothing reads [- - -] and fails here rather than scoring as a kill below.
cp "$VALIDATOR" "$ROOT/control-chrono.sh"
g_score "CONTROL chrono copy" "$ROOT/control-chrono.sh" "- G -"
g_mutate() {  # $1 label  $2 replacement line  $3 expected row
  local mut="$ROOT/mutant-$1.sh"
  MUT_OLD="$G_ANCHOR" MUT_NEW="$2" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation matched nothing or is not valid shell -- this assertion proves nothing\n' "MUTATION $1"
    return
  fi
  g_score "MUTATION $1" "$mut" "$3"
}
g_mutate chrono-raw-string '    if [[ "$invoked_at" < "$PREV_AT" ]]; then' "G - -"
g_mutate chrono-strip-z    '    if [[ "${invoked_at%Z}" < "${PREV_AT%Z}" ]]; then' "- G G"
g_mutate chrono-arm-g-off  '    if false; then' "- - -"

# --- F4/F5 on a SHARDED series: artifact_sha compared per stem, not as a hex smear -------
expect sharded-revert-reordered 0 "a genuine revert of a sharded hard block, stories listed in another order -- RESOLVED" s1-adversarial-p
expect sharded-revert-partial 1 "story 2 lands on a sha no pass notarized -- FAIL (F5)" s1-adversarial-p
expect_says sharded-revert-partial s1-adversarial-p "F5-sharded-partial" "matches no" "earlier pass in this series"
expect_state sharded-revert-partial s1-adversarial-p DIVERGENT 3 "a partial revert of a sharded pass is not a release -- deny"

# MUTANT: restore the `tr -cd` read at all three sites (every layer of the fix). The reordered
# case must flip to F4 "never saw"; the partial case must still fail on F5, so the mutant is
# attributable to the reader and not to a validator that fails everything. Built in a directory
# holding the steering validator too: F6 resolves it beside $0, and without it the citation
# arm fails both cases for its own reason.
SH_DIR="$ROOT/mut-sha-key"; mkdir -p "$SH_DIR"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$SH_DIR/" 2>/dev/null
cp "$VALIDATOR" "$SH_DIR/control.sh"
python3 - "$VALIDATOR" "$SH_DIR/mutant.sh" <<'PY'
import sys
s = open(sys.argv[1]).read()
subs = [
  ('  sha_key "$(block_field "$f" \'artifact_sha\')"; P_SHA+=("$SHA_KEY")',
   '  P_SHA+=("$(block_field "$f" \'artifact_sha\' | tr -cd \'0-9a-fA-F\')")'),
  ('  sha_key "$(record_field "$rec" \'artifact_sha_before\')"; sha_b="$SHA_KEY"',
   '  sha_b="$(record_field "$rec" \'artifact_sha_before\' | tr -cd \'0-9a-fA-F\')"'),
  ('  sha_key "$(record_field "$rec" \'artifact_sha_after\')";  sha_a="$SHA_KEY"',
   '  sha_a="$(record_field "$rec" \'artifact_sha_after\'  | tr -cd \'0-9a-fA-F\')"'),
]
for o, n in subs:
    if s.count(o) != 1: sys.exit(3)
    s = s.replace(o, n)
open(sys.argv[2], "w").write(s)
PY
sh_rc=$?
sh_run() {  # $1 script  $2 case -> PASS | NEVER-SAW | F5 | OTHER
  local o
  o="$(bash "$1" --series "$ROOT/$2/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)" && { echo PASS; return; }
  case "$o" in *"never saw"*) echo NEVER-SAW ;; *"matches no"*) echo F5 ;; *) echo OTHER ;; esac
}
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$sh_rc" -ne 0 ] || [ ! -f "$SH_DIR/validate-steering-budget.sh" ] || cmp -s "$VALIDATOR" "$SH_DIR/mutant.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s FIXTURE STALE -- the three sha_key anchors are not each in the validator exactly once, or the sibling is missing\n' "MUTATION sha-key"
else
  c_row="$(sh_run "$SH_DIR/control.sh" sharded-revert-reordered) $(sh_run "$SH_DIR/control.sh" sharded-revert-partial)"
  m_row="$(sh_run "$SH_DIR/mutant.sh" sharded-revert-reordered) $(sh_run "$SH_DIR/mutant.sh" sharded-revert-partial)"
  if [ "$c_row" = "PASS F5" ] && [ "$m_row" = "NEVER-SAW F5" ]; then
    printf '  ok    %-28s control [%s], tr -cd restored [%s]\n' "MUTATION sha-key" "$c_row" "$m_row"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s control [%s] want [PASS F5]; tr -cd restored [%s] want [NEVER-SAW F5]\n' "MUTATION sha-key" "$c_row" "$m_row"
  fi
fi

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

# --- A CORPUS THAT HELD NO RECORD IS THE ABSENT CORPUS, ONE STEP LATER ----------
# `steer_dir_has_transcript` asks whether a `*.jsonl` is READABLE, never whether it holds a
# record. So a directory of empty or sidechain-only transcripts set STEER_FLAG, skipped the
# two-tier fail-open, ran the predicate and DENIED -- while passing NO flag at all failed
# open. Supplying MORE ground truth than the passing case requires wedged the pipeline.
#
# THE NARROWING IS THE ASSERTION, AND IT IS WHY EVERY ARM HERE COMES IN A PAIR. "Held no
# record" fails open; "held operator records that do not carry the quote" keeps denying,
# because that corpus REFUTED the citation and that is S290. A fix that cannot tell the two
# apart acquits the forgery, so each acquitted world below sits beside a denied one that
# differs from it in exactly one property.
CORP="$ROOT/corpora"; mkdir -p "$CORP"
# no-records: a directory holding a transcript FILE with nothing parseable in it. The
# motivating world, kept as its own case: a dir with no `*.jsonl` at all does not reach the
# predicate (steer_dir_has_transcript refuses it), so it cannot exercise this branch.
mkdir -p "$CORP/no-records"; : > "$CORP/no-records/session-a.jsonl"
# sidechain-only: parseable lines, every one dropped by the reader's `!r.isSidechain` filter.
# A subagent's turns are not the operator's, and a corpus made only of them read ZERO.
mkdir -p "$CORP/sidechain"
printf '%s\n' '{"type":"user","isSidechain":true,"timestamp":"2026-07-12T03:00:00Z","message":{"content":"Revert the p1 to p2 repair wholesale — it made the check unfalsifiable."}}' \
  > "$CORP/sidechain/session-a.jsonl"
# assistant-only: THE NEAR-MISS, and it must DENY. Records parse and are read; none of them
# is an operator turn. That is the S290 shape exactly -- the machine spoke, the human did
# not -- and it is one property from `sidechain` above, which is acquitted.
mkdir -p "$CORP/assistant"
printf '%s\n' '{"type":"assistant","timestamp":"2026-07-12T03:00:00Z","message":{"content":[{"type":"text","text":"Revert the p1 to p2 repair wholesale — it made the check unfalsifiable."}]}}' \
  > "$CORP/assistant/session-a.jsonl"
# operator-no-quote: the other near-miss. A real human turn, in the window, that simply does
# not carry the cited words. The ground truth is present and refutes the record.
mkdir -p "$CORP/operator-no-quote"
printf '%s\n' '{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Something this resolution record does not quote, at ample length."}}' \
  > "$CORP/operator-no-quote/session-a.jsonl"
# since-excluded: THE ONE THAT MUST KEEP DENYING, and it is not obvious. The corpus holds the
# GENUINE operator turn; its file's MTIME predates the bound, so `--since` drops the FILE and
# the reader sees zero records. That zero is a fact about the BOUND, not about the corpus --
# and the bound is `invoked_at` from a pass file the LEAD writes. Acquitting it would hand the
# lead a one-field fail-open over ground truth that refutes nothing. The predicate withholds
# the token when the file LIST is empty, which is exactly this state.
mkdir -p "$CORP/since-excluded"
cp "$ROOT/prior-session-transcript.jsonl" "$CORP/since-excluded/session-a.jsonl"
touch -t 200001010000 "$CORP/since-excluded/session-a.jsonl"

# $1 label  $2 corpus-dir  $3 expected STATE  $4 expected rc  $5 stderr expectation (UNVERIFIABLE|quiet)  $6 why
# ASSERTS THE MESSAGE, not only the state. A fail-open that stops SAYING it is unverifiable
# is indistinguishable from a verified citation in the flow log, which is the whole reason
# the no-transcript branch prints one.
corp_state() {
  local label="$1" cdir="$2" want_state="$3" want_rc="$4" want_err="$5" why="$6" out rc state err
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$ROOT/stalled-resolved/s1-adversarial-p" --cycle-state \
         --transcript-dir "$cdir" 2>"$ROOT/corp.err")"
  rc=$?
  state="$(printf '%s' "$out" | cut -f1)"
  err="quiet"
  grep -qF 'ADVERSARIAL_CITATION_UNVERIFIABLE' "$ROOT/corp.err" && err="UNVERIFIABLE"
  if [ "$state" = "$want_state" ] && [ "$rc" -eq "$want_rc" ] && [ "$err" = "$want_err" ]; then
    printf '  ok    %-28s %s/%s %s  (%s)\n' "$label" "$state" "$rc" "$err" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s/%s %s want=%s/%s %s  (%s)\n' \
      "$label" "${state:-<none>}" "$rc" "$err" "$want_state" "$want_rc" "$want_err" "$why"
  fi
}

# THE CONTROL FIRST. The real corpus VERIFIES, so every deny below is a deny about the
# citation and not a series that could never resolve.
corp_state corpus-real          "$ROOT"                  RESOLVED 0 quiet        "CONTROL: the genuine operator turn is in this corpus -- the record verifies"
corp_state corpus-no-records    "$CORP/no-records"       RESOLVED 0 UNVERIFIABLE "THE SUBJECT: a present transcript holding zero records could not have verified anything -- fail OPEN, and say so"
corp_state corpus-sidechain     "$CORP/sidechain"        RESOLVED 0 UNVERIFIABLE "every line dropped as a sidechain: FILES were opened and zero records came back, same fact"
corp_state corpus-since-excluded "$CORP/since-excluded"  STALLED  3 quiet        "THE BOUND, NOT THE CORPUS: --since dropped the only FILE, so zero is a fact about a lead-written field -- DENIED"
corp_state corpus-assistant     "$CORP/assistant"        STALLED  3 quiet        "THE NEAR-MISS: records WERE read and none is an operator turn -- the S290 shape, still DENIED"
corp_state corpus-operator-quiet "$CORP/operator-no-quote" STALLED 3 quiet       "THE NEAR-MISS: a real operator turn that does not carry the quote REFUTES the record -- still DENIED"

# THE PROOF THAT since-excluded IS A LIVE ATTACK AND NOT A CURIOSITY. Unbounded, that SAME
# corpus verifies that SAME citation -- so its zero came from the bound, over ground truth
# that refutes nothing. Without this arm the deny above is indistinguishable from a corpus
# that simply never held the words, and the `files.length` conjunct would read as decoration.
ASSERTIONS=$((ASSERTIONS + 1))
STEER_FOR_SINCE="$(cd "$(dirname "$VALIDATOR")" && pwd)/validate-steering-budget.sh"
since_out="$(bash "$STEER_FOR_SINCE" --dir "$CORP/since-excluded" \
  --cite "Cut the claim and re-verify" --authorized-at "" --quiet 2>/dev/null)"
since_rc=$?
if [ "$since_rc" -eq 0 ]; then
  printf '  ok    %-28s %s  (%s)\n' "since-excluded-unbounded" "MATCH" "unbounded, the SAME corpus verifies -- so the deny above came from the BOUND, not from an absent operator"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s got %s/%s want MATCH/0 -- the seed never held the quote, so the since arm above proves nothing\n' \
    "since-excluded-unbounded" "${since_out:-<none>}" "$since_rc"
fi

# THE FORGED BOUND, END TO END, through the SHIPPING validator. The arm above drives the
# predicate directly; this one drives the attack as a lead would actually mount it -- by
# rewriting `invoked_at` on the pass the resolution record resolves, which is the sole source
# of `--since`. It must stay STALLED, and it is the discriminating case: a token emitted
# without the `files.length` conjunct reports RESOLVED/UNVERIFIABLE here over a corpus holding
# the operator's real message, which is a fail-open on a field the lead writes.
ASSERTIONS=$((ASSERTIONS + 1))
FORGE="$ROOT/forged-since"; mkdir -p "$FORGE"
cp -R "$ROOT/stalled-resolved" "$FORGE/series"
cp "$ROOT"/*.jsonl "$FORGE/" 2>/dev/null
sed -i.bak 's/^invoked_at: .*/invoked_at: 2099-01-01T00:00:00Z/' "$FORGE/series/s1-adversarial-p4.md"
rm -f "$FORGE/series/s1-adversarial-p4.md.bak"
forge_out="$(bash "$VALIDATOR" --series "$FORGE/series/s1-adversarial-p" --cycle-state \
  --transcript-dir "$ROOT" 2>/dev/null)"
forge_rc=$?
forge_state="$(printf '%s' "$forge_out" | cut -f1)"
if [ "$forge_state" = "STALLED" ] && [ "$forge_rc" -eq 3 ]; then
  printf '  ok    %-28s %s/%s  (%s)\n' "forged-invoked-at" "$forge_state" "$forge_rc" "a future invoked_at empties the corpus by mtime; the third state must NOT open on a bound the lead controls"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s %s/%s want STALLED/3  (%s)\n' "forged-invoked-at" "${forge_state:-<none>}" "$forge_rc" "a lead-forged invoked_at bought a fail-open over a corpus holding the operator's real message"
fi

# GATE MODE STILL FAILS CLOSED ON THE THIRD STATE. The RELEASE surface must not open on a
# claim nothing checked. `divergent-resolved` is the series used because it PASSES the gate
# on the real corpus -- `stalled-resolved` exits 1 whatever the corpus says, so a deny read
# off it would be non-discriminating and its agreement would mean nothing.
gate_corp() { # $1 label  $2 corpus  $3 want rc  $4 why
  local label="$1" cdir="$2" want="$3" why="$4" got
  ASSERTIONS=$((ASSERTIONS + 1))
  bash "$VALIDATOR" --series "$ROOT/divergent-resolved/s1-adversarial-p" \
    --transcript-dir "$cdir" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ok    %-28s exit=%s  (%s)\n' "$label" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s exit=%s want=%s  (%s)\n' "$label" "$got" "$want" "$why"
  fi
}
gate_corp gate-corpus-real       "$ROOT"            0 "CONTROL: the gate PASSES this series on the real corpus, so the denies below are about the corpus"
gate_corp gate-corpus-no-records "$CORP/no-records" 1 "the gate still fails CLOSED on the third state -- a release never opens on an unverifiable claim"
gate_corp gate-corpus-sidechain  "$CORP/sidechain"  1 "same, by the other route to zero records"

# --- MUTATION: the third state, three ways it goes wrong ------------------------
# THE COPIES NEED THEIR SIBLING. `STEER_SCRIPT` resolves as `$(dirname "$0")/…`, so a lone
# copy finds no predicate, every citation becomes UNVERIFIABLE (rc!=2 branch) and --cycle-state
# fails OPEN on everything -- which would score `corpus-assistant` as acquitted and read as a
# kill it did not earn. m3 mutates the PREDICATE, so its copy needs its own directory with a
# convergence validator beside it.
MWORK="$ROOT/third-state-mutants"; mkdir -p "$MWORK"
SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
cp "$VALIDATOR" "$MWORK/validate-adversarial-convergence.sh"
cp "$SRC_DIR/validate-steering-budget.sh" "$MWORK/validate-steering-budget.sh"

# $1 convergence-script  $2 corpus -> "<STATE>/<rc>/<err>"
ts_probe() {
  local v="$1" cdir="$2" out rc state err
  out="$(bash "$v" --series "$ROOT/stalled-resolved/s1-adversarial-p" --cycle-state \
         --transcript-dir "$cdir" 2>"$ROOT/ts.err")"
  rc=$?
  state="$(printf '%s' "$out" | cut -f1)"
  err="quiet"; grep -qF 'ADVERSARIAL_CITATION_UNVERIFIABLE' "$ROOT/ts.err" && err="UNVERIFIABLE"
  printf '%s/%s/%s' "${state:-NONE}" "$rc" "$err"
}
# The five worlds every mutant is scored on, in order. One acquitted, three denied, plus the
# verifying control -- a mutant that moves only one cell is attributable, and one that moves
# all five is not a finding about this branch. The three denied worlds fail for THREE
# DIFFERENT reasons (no operator turn / the quote is absent / the bound emptied the file
# list), which is what lets each mutant below name its own subject.
TS_CORPORA="$ROOT $CORP/no-records $CORP/assistant $CORP/operator-no-quote $CORP/since-excluded"
TS_REAL="RESOLVED/0/quiet RESOLVED/0/UNVERIFIABLE STALLED/3/quiet STALLED/3/quiet STALLED/3/quiet"

ts_row() { # ts_row <convergence-script> -> the four verdicts, space separated
  local v="$1" c row=""
  for c in $TS_CORPORA; do row="$row $(ts_probe "$v" "$c")"; done
  echo $row
}

# THE UNMUTATED CONTROL, in the mutants' own directory. A partial copy tree makes every
# mutant "survive" and this control pass too, because two inert runs compare equal -- so the
# control carries a POSITIVE conjunct: it must reproduce the acquittal AND both denies.
ASSERTIONS=$((ASSERTIONS + 1))
ts_ctrl="$(ts_row "$MWORK/validate-adversarial-convergence.sh")"
if [ "$ts_ctrl" = "$(echo $TS_REAL)" ]; then
  printf '  ok    %-28s [%s]\n' "CONTROL third-state copy" "$ts_ctrl"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s got [%s] want [%s] -- the copy tree is what fails; every mutant below is vacuous\n' \
    "CONTROL third-state copy" "$ts_ctrl" "$(echo $TS_REAL)"
fi

# $1 label  $2 which-file (conv|pred)  $3 old  $4 new  $5 expected four verdicts  $6 why
ts_mutate() {
  local label="$1" which="$2" old="$3" new="$4" want="$5" why="$6"
  local mdir="$ROOT/tsm-$label"
  ASSERTIONS=$((ASSERTIONS + 1))
  mkdir -p "$mdir"
  cp "$VALIDATOR" "$mdir/validate-adversarial-convergence.sh"
  cp "$SRC_DIR/validate-steering-budget.sh" "$mdir/validate-steering-budget.sh"
  local target="$mdir/validate-adversarial-convergence.sh"
  [ "$which" = pred ] && target="$mdir/validate-steering-budget.sh"
  local src="$VALIDATOR"
  [ "$which" = pred ] && src="$SRC_DIR/validate-steering-budget.sh"
  if ! MUT_OLD="$old" MUT_NEW="$new" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
       "$src" "$target"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation DID NOT APPLY -- a mutant that never existed scores every arm as a kill\n' "MUTATION $label"
    return
  fi
  if cmp -s "$src" "$target"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation matched NOTHING -- this assertion proves nothing\n' "MUTATION $label"
    return
  fi
  # A mutant that is no longer a PROGRAM emits nothing, and nothing scores as a kill.
  if [ "$which" = conv ] && ! bash -n "$target" 2>/dev/null; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutant is not a valid shell script -- its silence is not a kill\n' "MUTATION $label"
    return
  fi
  local got
  got="$(ts_row "$mdir/validate-adversarial-convergence.sh")"
  if [ "$got" = "$(echo $want)" ]; then
    printf '  ok    %-28s [%s]  (%s)\n' "MUTATION $label" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]  (%s)\n' "MUTATION $label" "$got" "$(echo $want)" "$why"
  fi
}

# m1 -- THE OVER-BROAD ACQUITTAL the entry itself warns against: every rc=2 is unverifiable,
# so a corpus that REFUTED the citation acquits it too. Both near-misses must flip; that is
# the fix this branch is deliberately not.
ts_mutate over-broad conv \
  'if [ "$cite_rc" -eq 2 ] && [ "$cite_out" = "NOMATCH-NO-RECORDS" ] && [ "$CYCLE_STATE" -eq 1 ]; then' \
  'if [ "$cite_rc" -eq 2 ] && [ "$CYCLE_STATE" -eq 1 ]; then' \
  "RESOLVED/0/quiet RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE" \
  "treating ALL rc=2 as unverifiable acquits the S290 forgery AND the forged bound -- every deny flips, which is the over-broad fix"

# m2 -- THE FIX DISABLED. The token is never matched, so the third state denies again: the
# shipped defect on demand. Only the zero-records world moves, which is what makes m1's
# two-cell flip attributable to the WIDENING and not to the branch existing.
ts_mutate disabled conv \
  '[ "$cite_out" = "NOMATCH-NO-RECORDS" ]' \
  '[ "$cite_out" = "ZZ-UNREACHABLE-TOKEN-ZZ" ]' \
  "RESOLVED/0/quiet STALLED/3/quiet STALLED/3/quiet STALLED/3/quiet STALLED/3/quiet" \
  "without the branch a present-but-empty corpus DENIES again -- worse off for supplying ground truth"

# m3 -- THE PREDICATE emits the token on BOTH NOMATCH paths, which is the same acquittal as
# m1 reached from the other side of the interface. It proves the branch keys on a distinction
# the PREDICATE draws, not on one the caller invented: mutate the producer and the caller
# widens with it. Anchored on the `console.log` line the no-quote path owns -- the zero-records
# path's own log line is a different string, so this cannot edit both.
ts_mutate token-on-both pred \
  '  console.log("NOMATCH"); process.exit(2);' \
  '  console.log("NOMATCH-NO-RECORDS"); process.exit(2);' \
  "RESOLVED/0/quiet RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE STALLED/3/quiet" \
  "a predicate that cannot tell its two NOMATCHes apart hands the caller the over-broad acquittal. The since-excluded cell is UNMOVED and that is the point: this mutation edits only the records-PRESENT path, so m4 below is the only arm that can see the files.length conjunct"

# m4 -- THE SECURITY CONJUNCT REMOVED, and the reason it needs its own mutant is that the
# three above cannot see it: they all leave `files.length` in place, so an author could delete
# it and every one of them stays green. A zero produced by the BOUND then wears the same token
# as a zero produced by the corpus, and `--since` -- a lead-written `invoked_at` -- becomes a
# one-field fail-open. ONLY the since-excluded cell moves, which is what makes it attributable.
ts_mutate since-acquitted pred \
  'console.log(files.length ? "NOMATCH-NO-RECORDS" : "NOMATCH");' \
  'console.log("NOMATCH-NO-RECORDS");' \
  "RESOLVED/0/quiet RESOLVED/0/UNVERIFIABLE STALLED/3/quiet STALLED/3/quiet RESOLVED/0/UNVERIFIABLE" \
  "without files.length a forged future --since acquits itself over a corpus holding the operator's real message"

echo
# --- arm J: RE-OPEN ------------------------------------------------------------
expect reopen-unrecorded 1 "a pass ran after EXIT_CONDITION_MET reporting 1C/2M -- RE-OPEN, FAIL (J)" s1-adversarial-p
expect reopen-same-bytes 0 "THE DECOY: p1 MET -> p2 MET at the SAME artifact_sha -- same bytes, same residue, not a re-open" s1-adversarial-p
expect reopen-moved-clean 1 "p1 MET -> p2 MET at a CHANGED artifact_sha with 0 findings -- the artifact MOVED after sign-off, RE-OPEN, FAIL (J)" s1-adversarial-p
expect reopen-sha-absent 0 "no artifact_sha on either side -- the arm fails OPEN rather than erroring on pre-migration data" s1-adversarial-p
expect reopen-recorded   0 "a re-open DECLARED with resolution: REOPEN_AFTER_MET resumes -- the arm has a door" s1-adversarial-p
expect_state reopen-unrecorded s1-adversarial-p REOPENED  3 "the hooks must deny the dispatch on a live re-open"
# GATE MODE AND HOOK MODE MUST NOT DISAGREE. Each of these failed the gate (exit 1) while
# --cycle-state answered CONVERGED/0, so the hooks were told to proceed on a series the gate
# had already refused. Arm F ran and set nothing the emit block could read.
expect_state divergent-unresolved       s1-adversarial-p    DIVERGENT 3 "a pass ran past a hard block with no resolution -- deny"
expect_state divergent-frozen           s1-adversarial-p    DIVERGENT 3 "FREEZE_SCOPE is not a resolution -- deny"
expect_state divergent-laundered-cut    s1-adversarial-p    DIVERGENT 3 "a repair wearing CUT_SCOPE's name is not a release -- deny"
expect_state divergent-laundered-revert s1-adversarial-p    DIVERGENT 3 "REVERT_REPAIR onto an unnotarized sha is not a release -- deny"
expect_state divergent                  s1-adversarial-pass DIVERGENT 3 "a live divergence denies dispatch"
expect_state repair-injected            s1-adversarial-pass DIVERGENT 3 "a repair injecting defects denies dispatch"
expect_state stalled-then-diverges      s1-adversarial-p    DIVERGENT 3 "divergence outranks the stall it followed"
expect_state restart-cycle              s1-adversarial-p    REOPENED  3 "a RESTART_CYCLE series still owes its declaration"
# Found by the pairing arm below, not by hand: an adjudication that presents no real choice
# denies the dispatch, and none of the three said so.
expect_state adjudication-no-options        s1-adversarial-p DIVERGENT 3 "a record presenting no options denies dispatch"
expect_state adjudication-one-option        s1-adversarial-p DIVERGENT 3 "a menu of one denies dispatch"
expect_state adjudication-no-recommendation s1-adversarial-p DIVERGENT 3 "a menu with no recommendation denies dispatch"
expect_state reopen-same-bytes  s1-adversarial-p CONVERGED 0 "a same-bytes re-review must not be denied"
expect_state reopen-moved-clean s1-adversarial-p REOPENED  3 "the hooks must deny on a re-open even when the successor pass found nothing"
expect_state reopen-sha-absent  s1-adversarial-p CONVERGED 0 "an unevidenced re-open must not be denied"
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
   | grep -qF -- "$D_GENERIC"; then
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
  # THE MAJOR COUNT IS 5, ABOVE MAJOR_EXIT_CEILING, AND IT HAS TO BE. This arm's subject is
  # WHICH SERIES the shipped derivation resolves, and it reads the answer off a STALLED
  # verdict. At or below the ceiling the plateau is a met exit condition, arm E never
  # accumulates, and every expression -- shipped and mutant alike -- reports CONTINUE. The
  # arm would then be green on all five rows while discriminating nothing, which is this
  # repo's own defect class inside the test written to catch it.
  for i in 1 2 3; do prov "$SD/s9/stories-adversarial-p$i.md" "$i" 5 EXIT_CONDITION_NOT_MET; done
  sleep 1
  cp "$SD/s9/stories-adversarial-p3.md" "$SD/s9/adversarial-pass1-discovery.md"
  sleep 1
  prov "$SD/s8/prd-adversarial-p1.md" 1 5 EXIT_CONDITION_NOT_MET
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
expect underived-exits               0 "0C, 7M ALL underived: 0 blocking -- MET is honest" s1-adversarial-p
expect underived-partial-blocks      1 "0C, 7M with 2 underived: FIVE blocking MAJORs, above the ceiling -- MET is a false convergence (B)" s1-adversarial-p
expect underived-exceeds             1 "8 underived of 7 MAJOR: the partition cannot exceed the whole (B)" s1-adversarial-p
expect underived-refuses             1 "0 blocking and still NOT_MET -- the residue IS the exit condition (B)" s1-adversarial-p
expect underived-absent-still-blocks 1 "MIGRATION: same residue, NO field -- absent means ZERO, so 7 blocking still blocks" s1-adversarial-p

# The exit codes above are necessary and not sufficient: three of those four failures are arm
# B, so a message naming the wrong quantity would score identically.
expect_says underived-partial-blocks s1-adversarial-p "B-blocking-count" \
  "5 blocking MAJOR" "7 MAJOR less 2 underived"
expect_says underived-exceeds s1-adversarial-p "B-partition" \
  "findings_major_underived=8" "7 MAJOR"

# --- THE EXIT CEILING: 0 CRITICAL and at most 3 BLOCKING MAJOR ------------------
# The criteria are declared once, at CRITICAL_EXIT_CEILING / MAJOR_EXIT_CEILING in the
# validator, and read by arm B in both directions and by arm E's accumulator. These assert
# the VALUE, not merely that some ceiling exists: at the limit must PASS and one above it
# must FAIL, in the same block, or a validator that dropped arm B's MAJOR half entirely
# would score identically on the first of them.
expect ceiling-at-limit        0 "0C / exactly 3 blocking MAJOR stamped MET -- AT the criteria, converged" s1-adversarial-p
expect ceiling-above-limit     1 "0C / 4 blocking MAJOR stamped MET -- ONE above the ceiling, false convergence (B)" s1-adversarial-p
expect ceiling-midcycle-below  0 "0C / 2 blocking MAJOR stamped NOT_MET mid-cycle -- declining an open exit is legal" s1-adversarial-p

expect_says ceiling-above-limit s1-adversarial-p "B-ceiling-exceeded" \
  "B -- CONSISTENCY" "4 blocking MAJOR" "at most 3"

# THE NOT_MET HALF STILL FIRES AT A FULLY CLEAN RESIDUE, and `refused-to-converge` above is
# its true positive. Asserted here by MESSAGE so that relaxing the ceiling cannot be mistaken
# for deleting the arm: an implementation that dropped the NOT_MET half entirely passes every
# exit-code assertion in this block and fails this one.
expect_says refused-to-converge s1-adversarial-pass "B-notmet-at-clean" \
  "B -- CONSISTENCY" "0 CRITICAL and 0 blocking MAJOR" "stamps"

# TWO ARMS MUST BE SILENT ON A PLATEAU BELOW THE CEILING, and the exit code cannot say so --
# arms C and D fire on the p5 divergence either way. Each negative carries its own positive
# control in the same invocation shape, because an absence is not a finding.
# Arm D, not arm C: p5 DECLARES DIVERGENT_HARD_BLOCK, so C is satisfied and D owns the
# unresolved terminal. Naming the wrong arm here is how a silence assertion below could pass
# against a run that failed for a third reason entirely.
expect_says ceiling-plateau-below s1-adversarial-p "D-owns-plateau-series" \
  "D -- TERMINAL" "DIVERGENT_HARD_BLOCK"
expect_state ceiling-plateau-below s1-adversarial-p DIVERGENT 3 \
  "the hooks must deny on the divergence that ended the plateau"

# AN ABSENCE ASSERTION CARRIES ITS CONTROL IN THE SAME INVOCATION -- the token must be
# missing from the subject AND present in a case that must emit it, or a validator that
# stopped emitting the token at all passes every negative arm below.
expect_silent() {  # $1 case-dir  $2 token  $3 control-dir  $4 why-it-must-be-silent
  local out ctl
  out="$(bash "$VALIDATOR" --series "$ROOT/$1/s1-adversarial-p" \
          --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  ctl="$(bash "$VALIDATOR" --series "$ROOT/$3/s1-adversarial-p" \
          --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  ASSERTIONS=$((ASSERTIONS + 1))
  if grep -qF -- "$2" <<<"$out"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s fired where it must be SILENT -- %s\n' "$1" "$2" "$4"
  elif ! grep -qF -- "$2" <<<"$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s CONTROL: %s absent from %s too -- the negative assertion is vacuous\n' "$1" "$2" "$3"
  else
    printf '  ok    %-28s %s silent here, present in %s (control)\n' "$1" "$2" "$3"
  fi
}

expect_silent ceiling-plateau-below "E -- STALL" stalled \
  "E and B's MET half are reading two different ceilings"
expect_silent ceiling-plateau-below "B -- CONSISTENCY" ceiling-above-limit \
  "the biconditional is back and every consumer's mid-cycle NOT_MET is retroactively an error"

# --- ARM K: the shard arm reads the TERMINAL pass --------------------------------------------
# Each case is a stamped git repo built by seed.sh. The recovery cell is the one that separates
# terminal keying from every-pass keying: under the latter it exits 1 on p1 forever, which is
# a remedy the arm prints and the gate cannot accept. The offender cell asserts the MESSAGE,
# because arm K's exit is shared with every other arm.
expect shard-recovered 0 \
  "unsharded p1, then the sharded MET p2 the remedy prescribes: the series CLEARS" stories-adversarial-p
expect shard-terminal-unsharded 1 \
  "sharded p1, whole-subject TERMINAL p2 after the stamp -- FAIL (K)" stories-adversarial-p
expect_says shard-terminal-unsharded stories-adversarial-p "K-names-terminal" \
  "FAIL (K -- SHARD): stories-adversarial-p2.md reviews" "write it as the NEXT" \
  "This arm reads only"
expect_state shard-terminal-unsharded stories-adversarial-p CONVERGED 0 \
  "arm K is GATE-ONLY: the hooks' state is untouched by a missing shard line"
expect shard-legacy 0 \
  "the series opened before the stamp: PENDING, printed and not counted" stories-adversarial-p
expect_says shard-legacy stories-adversarial-p "K-legacy-pending" \
  "PENDING (K -- SHARD): the terminal pass stories-adversarial-p2.md" "Legacy series."

echo
# --- ARM K2: one shardable DOCUMENT, reviewed whole -----------------------------------------
# K2 asks partition-document.sh, a SIBLING of the validator, whether the document partitions.
# That program is owned by another change and may be absent from a tree this fixture runs in;
# a K2 cell scored against a validator with no partitioner reads PENDING everywhere and the
# FAIL cell alone would say so -- but the SERIAL and sharded cells would pass for the wrong
# reason. So its absence is refused HERE, loudly, before any K2 cell is read.
K2_PD="$(cd "$(dirname "$VALIDATOR")" && pwd)/partition-document.sh"
if [ ! -f "$K2_PD" ]; then
  echo "FIXTURE BROKEN: partition-document.sh is not beside $VALIDATOR -- arm K2 cannot be scored"
  exit 1
fi
K2_POST_MSG="FAIL (K2 -- SECTIONS): prd-adversarial-p1.md reviews"
expect k2-shardable-post 1 \
  "a whole-document pass over a 4-part document, series opened after the 0.665.0 stamp -- FAIL (K2)" prd-adversarial-p
expect_says k2-shardable-post prd-adversarial-p "K2-names-document" \
  "$K2_POST_MSG" "splits into" "4 parts" "merge-adversarial-shards.sh --document"
expect_state k2-shardable-post prd-adversarial-p CONVERGED 0 \
  "arm K2 is GATE-ONLY: the hooks' state is untouched by a missing shard line"
expect k2-shardable-pre 0 \
  "the same bytes, series opened before the stamp: PENDING, printed and not counted" prd-adversarial-p
expect_says k2-shardable-pre prd-adversarial-p "K2-legacy-pending" \
  "PENDING (K2 -- SECTIONS): the terminal pass prd-adversarial-p1.md" "Legacy series."
expect k2-serial 0 "one ## section: the map says SERIAL, Rule 28 exception 4 -- one adversary is correct" prd-adversarial-p
expect k2-sharded 0 "the offender with the merge's shard_tool_use_ids: line -- sectioned, passes" prd-adversarial-p
expect k2-sha-moved 0 "the document moved after the pass notarized it: PENDING, never judged on unreviewed bytes" prd-adversarial-p
expect_says k2-sha-moved prd-adversarial-p "K2-sha-moved-pending" \
  "PENDING (K2 -- SECTIONS)" "is not the bytes it notarized"

# THE SILENT CELLS, each against the offender as the control that K2 fires at all.
k2_silent() {  # $1 case  $2 why
  local out ctl
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$ROOT/$1/prd-adversarial-p" 2>&1)"
  ctl="$(bash "$VALIDATOR" --series "$ROOT/k2-shardable-post/prd-adversarial-p" 2>&1)"
  if grep -qF -- "K2 -- SECTIONS" <<<"$out"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s K2 spoke where it must be SILENT -- %s\n' "$1" "$2"
  elif ! grep -qF -- "$K2_POST_MSG" <<<"$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s CONTROL: k2-shardable-post did not FAIL (K2) -- the silence is vacuous\n' "$1"
  else
    printf '  ok    %-28s K2 silent here, FAILs k2-shardable-post (control)\n' "$1"
  fi
}
k2_silent k2-serial  "a SERIAL document is a correct whole-subject review, not a deferral"
k2_silent k2-sharded "a merged pass carries shard_tool_use_ids: and is the dispatch K2 asks for"

# THE PROGRAM ABSENT. A consumer may carry this validator before it carries the partitioner;
# that must read PENDING, naming the program, never FAIL. The copy carries every OTHER sibling
# the validator resolves, so the only thing it lacks is the program under test.
K2_NOPROG="$ROOT/k2-noprog"; mkdir -p "$K2_NOPROG"
cp "$VALIDATOR" "$K2_NOPROG/validate-adversarial-convergence.sh"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$K2_NOPROG/validate-steering-budget.sh"
ASSERTIONS=$((ASSERTIONS + 1))
k2np_out="$(bash "$K2_NOPROG/validate-adversarial-convergence.sh" --series "$ROOT/k2-shardable-post/prd-adversarial-p" 2>&1)"
k2np_rc=$?
if [ -e "$K2_NOPROG/partition-document.sh" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s the copy carries partition-document.sh -- this cell cannot see its absence\n' "k2-program-absent"
elif [ "$k2np_rc" -eq 0 ] && grep -qF -- "is not installed beside this validator" <<<"$k2np_out" \
     && ! grep -qF -- "FAIL (K2" <<<"$k2np_out"; then
  printf '  ok    %-28s %s\n' "k2-program-absent" "the offender reads PENDING naming the missing program, exit 0"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s exit=%s -- an absent partitioner must be PENDING, never FAIL\n' "k2-program-absent" "$k2np_rc"
  printf '%s\n' "$k2np_out" | sed 's/^/          | /'
fi

# --- MUTATION: the three gates that keep K2 off in-flight and legacy work -------------------
# Each gate removed moves exactly ONE cell of five, and a different cell:
#
#                          post   pre      serial   sharded  sha-moved
#   shipped                FAIL   PENDING  SILENT   SILENT   PENDING
#   stamp gate removed     FAIL   FAIL     SILENT   SILENT   PENDING
#   SERIAL check removed   FAIL   PENDING  FAIL     SILENT   PENDING
#   sha gate removed       FAIL   PENDING  SILENT   SILENT   FAIL
#
# Built in a copy of the validator's directory carrying its siblings, with an unmutated control
# from the same directory, so a copy that cannot resolve its partitioner reads as broken.
K2_CASES="k2-shardable-post k2-shardable-pre k2-serial k2-sharded k2-sha-moved"
K2_REAL="FAIL PENDING SILENT SILENT PENDING"
K2_MUT="$ROOT/k2-mutants"; mkdir -p "$K2_MUT"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$K2_MUT/validate-steering-budget.sh"
cp "$K2_PD" "$K2_MUT/partition-document.sh"

k2_cell() {  # $1 script  $2 case -> FAIL | PENDING | SILENT
  local out
  out="$(bash "$1" --series "$ROOT/$2/prd-adversarial-p" 2>&1)"
  case "$out" in
    *"FAIL (K2 -- SECTIONS)"*)    printf 'FAIL\n' ;;
    *"PENDING (K2 -- SECTIONS)"*) printf 'PENDING\n' ;;
    *)                            printf 'SILENT\n' ;;
  esac
}
k2_score() {  # $1 label  $2 script  $3 expected row
  local got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  for c in $K2_CASES; do got="$got $(k2_cell "$2" "$c")"; done
  if [ "$(echo $got)" = "$(echo $3)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
cp "$VALIDATOR" "$K2_MUT/control.sh"
k2_score "CONTROL k2 copy" "$K2_MUT/control.sh" "$K2_REAL"

k2_mutate() {  # $1 label  $2 anchor line (must be unique)  $3 replacement  $4 expected row
  local mut="$K2_MUT/mutant-$1.sh" n ctl
  n="$(grep -cxF -- "$2" "$VALIDATOR")" || n=0
  ctl="$(grep -cxF -- "$2 # no-such-line" "$VALIDATOR")" || ctl=0
  if [ "$n" -ne 1 ] || [ "$ctl" -ne 0 ]; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0)\n' "MUTATION $1" "$n" "$ctl"
    return
  fi
  MUT_OLD="$2" MUT_NEW="$3" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut"; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation DID NOT APPLY -- this assertion proves nothing\n' "MUTATION $1"
    return
  fi
  if ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutant is not a valid shell script -- its silence is not a kill\n' "MUTATION $1"
    return
  fi
  k2_score "MUTATION $1" "$mut" "$4"
}
k2_mutate k2-stamp-gate \
  '  elif [[ "$k2_at" < "$k2_stamp" ]]; then' \
  '  elif false; then' \
  "FAIL FAIL SILENT SILENT PENDING"
k2_mutate k2-serial-check \
  '          if [ "$k2rc" -eq 0 ]; then' \
  '          if [ "$k2rc" -eq 0 ] || [ "$k2rc" -eq 3 ]; then' \
  "FAIL PENDING FAIL SILENT PENDING"
k2_mutate k2-sha-gate \
  '      elif [ "$k2h_lc" != "$k2_disk" ]; then' \
  '      elif false; then' \
  "FAIL PENDING SILENT SILENT FAIL"

# --- ARM K2 asks the partitioner IN FORCE AT THE PASS, not today's --------------------------
# Every world above holds the validator OUTSIDE the world (the distribution layout), so each of
# them is judged by today's copy and must SAY so -- beside a SILENT verdict as much as a FAIL.
expect_says k2-shardable-post prd-adversarial-p "K2-fallback-marked-fail" \
  "FALLBACK (K2 partitioner): prd-adversarial-p1.md is judged by the CURRENT" "the distribution layout"
expect_says k2-serial prd-adversarial-p "K2-fallback-marked-silent" \
  "FALLBACK (K2 partitioner): prd-adversarial-p1.md is judged by the CURRENT" "the distribution layout"
#
# The HISTORY worlds hold the validator INSIDE a stamped git root, beside a partitioner the root
# TRACKS, and commit two copies of it: the shipped one and a stub that maps a two-section probe
# (so it passes K2's map probe) and calls anything larger SERIAL. The stub is self-contained on
# purpose -- a copy derived by editing the shipped partitioner breaks whenever those lines move.
# The document has four sections: the shipped copy maps it (FAIL), the stub calls it SERIAL.
#
#   world          layout          10:00         12:00       pass(es)       in force   today
#   old-serial     scripts/ai-dlc  stub+stamp    shipped     11:00          stub       shipped
#   old-splits     core/scripts    shipped+stamp stub        11:00          shipped    stub
#   terminal       scripts/ai-dlc  stub+stamp    shipped     11:00, 13:00   shipped    shipped
#   untracked      scripts/ai-dlc  stamp only    --          11:00          (none)     shipped
#
# old-serial and old-splits are the two DISAGREEMENT DIRECTIONS (an update, and a downgrade): a
# today's-map read inverts both. terminal pins the TIME KEY: its first pass predates the shipped
# copy and its terminal pass follows it, so keying on the first pass reads the stub. untracked
# cannot resolve a copy and must fall back to today's AND say so.
K2H="$ROOT/k2-hist"; mkdir -p "$K2H"
k2h_commit() {  # $1 world  $2 iso time  $3 message -- every tracked change in the world
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    cd "$1" || exit 1
    git add -A . >/dev/null || exit 1
    GIT_COMMITTER_DATE="$2" GIT_AUTHOR_DATE="$2" \
      git -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false \
          -c core.hooksPath=/dev/null commit -q -m "$3" >/dev/null )
}
k2h_stub() {  # $1 path -- a partitioner that maps exactly two `## ` sections, SERIAL otherwise
  printf '%s\n' '#!/usr/bin/env bash' \
    '[ "${1:-}" = --map ] || exit 2' \
    'n="$(grep -c "^## " "$2")" || n=0' \
    'if [ "$n" -eq 2 ]; then printf "1\t1\t2\t## a\n2\t3\t4\t## b\n"; exit 0; fi' \
    'echo "SERIAL: stub partitioner"; exit 3' > "$1"
}
k2h_pass() {  # $1 file  $2 n  $3 major  $4 verdict  $5 invoked_at  $6 artifact_sha
  {
    printf '# prd -- adversarial pass %s\n\n' "$2"
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\n'
    printf 'invoked_at: %s\n' "$5"
    printf 'tool_use_id: toolu_fixture_k2h%s\n' "$2"
    printf 'mode: subagent\n'
    printf 'lead_role: pm\n'
    printf 'artifact: prd.md\n'
    printf 'artifact_sha: %s\n' "$6"
    printf 'findings_critical: 0\n'
    printf 'findings_critical_prior_scope: 0\n'
    printf 'findings_major: %s\n' "$3"
    printf 'findings_major_underived: 0\n'
    printf 'findings_minor: 0\n'
    printf 'verdict: %s\n' "$4"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$1"
}
k2h_world() {  # $1 world  $2 layout dir  $3 copy at 10:00 (stub|shipped|none)  $4 copy at 12:00 (stub|shipped|none)
  local w="$K2H/$1" l="$K2H/$1/$2" c
  mkdir -p "$w/.claude" "$l" || return 1
  printf 'version: 0.665.0\n' > "$w/.claude/.ai-dlc-version"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; cd "$w" && git init -q . >/dev/null ) || return 1
  for c in "$3:2026-09-29T10:00:00Z" "$4:2026-09-29T12:00:00Z"; do
    case "${c%%:*}" in
      stub)    k2h_stub "$l/partition-document.sh" ;;
      shipped) cp "$K2_PD" "$l/partition-document.sh" ;;
      none)    [ "${c#*:}" = 2026-09-29T10:00:00Z ] || continue ;;
    esac
    k2h_commit "$w" "${c#*:}" "at ${c#*:}" || return 1
  done
  # Untracked from here on: the validator, its steering sibling, the document and the passes.
  # The untracked world's partitioner is today's copy and is never committed.
  [ "$3" = none ] && cp "$K2_PD" "$l/partition-document.sh"
  cp "$VALIDATOR" "$l/validate-adversarial-convergence.sh"
  cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$l/validate-steering-budget.sh"
  printf '# PRD\n\n## One\n\nalpha alpha\n\n## Two\n\nbravo bravo\n\n## Three\n\ncharlie charlie\n\n## Four\n\ndelta delta\n' > "$w/prd.md"
  K2H_SHA="$(shasum -a 256 "$w/prd.md" 2>/dev/null | cut -d' ' -f1)"
  [ -n "$K2H_SHA" ] || K2H_SHA="$(sha256sum "$w/prd.md" | cut -d' ' -f1)"
  printf '%s\n' "$2" > "$w/.layout"
}
K2H_OK=1
k2h_world old-serial scripts/ai-dlc stub shipped || K2H_OK=0
k2h_pass "$K2H/old-serial/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"
k2h_world old-splits core/scripts shipped stub || K2H_OK=0
k2h_pass "$K2H/old-splits/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"
k2h_world terminal scripts/ai-dlc stub shipped || K2H_OK=0
k2h_pass "$K2H/terminal/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"
k2h_pass "$K2H/terminal/prd-adversarial-p2.md" 2 0 EXIT_CONDITION_MET 2026-09-29T13:00:00Z "$K2H_SHA"
k2h_world untracked scripts/ai-dlc none none || K2H_OK=0
k2h_pass "$K2H/untracked/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"

# THE MERGE WORLDS. Main installs the stub at 10:00; a sprint branch installs the shipped copy at
# 10:30, writes the pass (dispatched 11:00) and commits it at 11:05; main then takes the sprint at
# 12:00 by a SQUASH or by a TRUE merge (--no-ff). On main's first-parent chain the shipped copy is
# dated 12:00, after the pass, so the time key alone reads the stub -- SERIAL, an acquittal of a
# dispatch made under the copy that maps the document. The commit that ADDED the pass file
# carries the shipped copy, so the two disagree and K2 must be PENDING, never silent.
k2h_merge_world() {  # $1 world  $2 squash|true
  local w="$K2H/$1" l="$K2H/$1/scripts/ai-dlc" main
  mkdir -p "$w/.claude" "$l" || return 1
  printf 'version: 0.665.0\n' > "$w/.claude/.ai-dlc-version"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; cd "$w" && git init -q . >/dev/null ) || return 1
  printf '# PRD\n\n## One\n\nalpha alpha\n\n## Two\n\nbravo bravo\n\n## Three\n\ncharlie charlie\n\n## Four\n\ndelta delta\n' > "$w/prd.md"
  k2h_stub "$l/partition-document.sh"
  k2h_commit "$w" 2026-09-29T10:00:00Z "install stub" || return 1
  main="$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git -C "$w" symbolic-ref --short HEAD ) )"
  [ -n "$main" ] || return 1
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git -C "$w" checkout -q -b sprint ) || return 1
  cp "$K2_PD" "$l/partition-document.sh"
  k2h_commit "$w" 2026-09-29T10:30:00Z "self-update on sprint" || return 1
  K2H_SHA="$(shasum -a 256 "$w/prd.md" 2>/dev/null | cut -d' ' -f1)"
  [ -n "$K2H_SHA" ] || K2H_SHA="$(sha256sum "$w/prd.md" | cut -d' ' -f1)"
  k2h_pass "$w/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"
  k2h_commit "$w" 2026-09-29T11:05:00Z "pass p1" || return 1
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    cd "$w" || exit 1
    git checkout -q "$main" || exit 1
    if [ "$2" = squash ]; then
      git merge -q --squash sprint >/dev/null 2>&1 || exit 1
      GIT_COMMITTER_DATE=2026-09-29T12:00:00Z GIT_AUTHOR_DATE=2026-09-29T12:00:00Z \
        git -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false \
            -c core.hooksPath=/dev/null commit -q -m "squash sprint" >/dev/null || exit 1
    else
      GIT_COMMITTER_DATE=2026-09-29T12:00:00Z GIT_AUTHOR_DATE=2026-09-29T12:00:00Z \
        git -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false \
            -c core.hooksPath=/dev/null merge -q --no-ff -m "merge sprint" sprint >/dev/null 2>&1 || exit 1
    fi ) || return 1
  cp "$VALIDATOR" "$l/validate-adversarial-convergence.sh"
  cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$l/validate-steering-budget.sh"
  printf 'scripts/ai-dlc\n' > "$w/.layout"
}
k2h_merge_world merge-squash squash || K2H_OK=0
k2h_merge_world merge-true true || K2H_OK=0

# THE WORLDS ARE WHAT THEY CLAIM, or every cell below scores a world nobody built: the two
# directions really do disagree (today's copy on disk answers the opposite of the copy at 10:00),
# and the untracked world tracks no partitioner.
k2h_rc() { bash "$1" --map "$2" >/dev/null 2>&1; echo $?; }
ASSERTIONS=$((ASSERTIONS + 1))
K2H_TMP="$K2H/.probe"; mkdir -p "$K2H_TMP"
k2h_blob() { ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
  git -C "$K2H/$1" cat-file blob "$(git -C "$K2H/$1" rev-list -1 --before=2026-09-29T11:00:00Z HEAD):./$(cat "$K2H/$1/.layout")/partition-document.sh" ) > "$K2H_TMP/$1.sh" 2>/dev/null; }
k2h_blob old-serial; k2h_blob old-splits
k2h_disk() { echo "$K2H/$1/$(cat "$K2H/$1/.layout")/partition-document.sh"; }
k2h_shape="$(k2h_rc "$K2H_TMP/old-serial.sh" "$K2H/old-serial/prd.md")$(k2h_rc "$(k2h_disk old-serial)" "$K2H/old-serial/prd.md")"
k2h_shape="$k2h_shape $(k2h_rc "$K2H_TMP/old-splits.sh" "$K2H/old-splits/prd.md")$(k2h_rc "$(k2h_disk old-splits)" "$K2H/old-splits/prd.md")"
k2h_untr="$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git -C "$K2H/untracked" ls-files -- scripts/ai-dlc ) | grep -c .)" || k2h_untr=0
# The merge worlds: the first-parent copy at the pass's time must be the stub (rc 3) and the copy
# at the commit that added the pass the shipped one (rc 0), or the world cannot express the defect.
k2h_mshape=""
for k2h_mw in merge-squash merge-true; do
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    git -C "$K2H/$k2h_mw" cat-file blob "$(git -C "$K2H/$k2h_mw" rev-list -1 --first-parent --before=2026-09-29T11:00:00Z HEAD):./scripts/ai-dlc/partition-document.sh"
  ) > "$K2H_TMP/$k2h_mw-time.sh" 2>/dev/null
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    git -C "$K2H/$k2h_mw" cat-file blob "$(git -C "$K2H/$k2h_mw" log --diff-filter=A --format=%H HEAD -- prd-adversarial-p1.md | tail -1):./scripts/ai-dlc/partition-document.sh"
  ) > "$K2H_TMP/$k2h_mw-add.sh" 2>/dev/null
  k2h_mshape="$k2h_mshape$(k2h_rc "$K2H_TMP/$k2h_mw-time.sh" "$K2H/$k2h_mw/prd.md")$(k2h_rc "$K2H_TMP/$k2h_mw-add.sh" "$K2H/$k2h_mw/prd.md") "
done
k2h_mshape="$(echo $k2h_mshape)"
if [ "$K2H_OK" -ne 1 ] || [ "$k2h_shape" != "30 03" ] || [ "$k2h_untr" -ne 0 ] || [ "$k2h_mshape" != "30 30" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN: built=%s, in-force/today rc per direction [%s] want [30 03], untracked tracks %s file(s), merge time/added rc [%s] want [30 30]\n' \
    "k2-history-worlds" "$K2H_OK" "$k2h_shape" "$k2h_untr" "$k2h_mshape"
else
  printf '  ok    %-28s both directions disagree [%s]; untracked tracks nothing; merges: time vs added [%s]\n' "k2-history-worlds" "$k2h_shape" "$k2h_mshape"
fi

# One cell per world: the K2 verdict, suffixed `/FB` when the FALLBACK line printed. Driven by
# a script copied INTO the world's layout dir, because the copy in force is resolved from where
# the validator sits.
K2H_WORLDS="old-serial old-splits terminal untracked merge-squash merge-true"
K2H_REAL="SILENT FAIL FAIL FAIL/FB PENDING PENDING"
k2h_cell() {  # $1 script basename  $2 world
  local out v
  out="$(bash "$K2H/$2/$(cat "$K2H/$2/.layout")/$1" --series "$K2H/$2/prd-adversarial-p" 2>&1)"
  case "$out" in
    *"FAIL (K2 -- SECTIONS)"*)    v=FAIL ;;
    *"PENDING (K2 -- SECTIONS)"*) v=PENDING ;;
    *)                            v=SILENT ;;
  esac
  case "$out" in *"FALLBACK (K2 partitioner)"*) v="$v/FB" ;; esac
  printf '%s\n' "$v"
}
k2h_score() {  # $1 label  $2 script basename  $3 expected row
  local got="" w
  ASSERTIONS=$((ASSERTIONS + 1))
  for w in $K2H_WORLDS; do got="$got $(k2h_cell "$2" "$w")"; done
  if [ "$(echo $got)" = "$(echo $3)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
k2h_score "K2 in-force copy" validate-adversarial-convergence.sh "$K2H_REAL"
expect_says_k2h() {  # $1 world  $2 label  $3... required substrings
  local w="$1" label="$2" out missing="" want; shift 2
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$K2H/$w/$(cat "$K2H/$w/.layout")/validate-adversarial-convergence.sh" --series "$K2H/$w/prd-adversarial-p" 2>&1)"
  for want in "$@"; do grep -qF -- "$want" <<<"$out" || missing="$missing \"$want\""; done
  if [ -z "$missing" ]; then printf '  ok    %-28s %s\n' "$label" "says what it must"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s missing:%s\n' "$label" "$missing"; fi
}
expect_says_k2h old-splits "K2h-names-copy-in-force" \
  "asked of the copy of core/scripts/partition-document.sh in force at"
expect_says_k2h untracked "K2h-untracked-reason" \
  "FALLBACK (K2 partitioner):" "scripts/ai-dlc/partition-document.sh is not tracked at"
expect_says_k2h merge-squash "K2h-squash-ambiguous" \
  "PENDING (K2 -- SECTIONS): in-force partitioner ambiguous ("
expect_says_k2h merge-true "K2h-merge-ambiguous" \
  "PENDING (K2 -- SECTIONS): in-force partitioner ambiguous ("

# MUTANTS, each built from the validator under test and dropped into every history world beside
# the real copy. Each moves only the cells its own clause owns; the revert takes out the WHOLE
# layer (resolution and marker), so a revert leaving the marker in place cannot pass as one.
k2h_mutate() {  # $1 label  $2 anchor (unique)  $3 replacement  $4 expected row
  local mut="$K2H/.mut-$1.sh" n ctl w
  n="$(grep -cF -- "$2" "$VALIDATOR")" || n=0
  ctl="$(grep -cF -- "$2 # no-such-line" "$VALIDATOR")" || ctl=0
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$n" -ne 1 ] || [ "$ctl" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0)\n' "MUTATION $1" "$n" "$ctl"
    return
  fi
  MUT_OLD="$2" MUT_NEW="$3" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation DID NOT APPLY or does not parse -- this assertion proves nothing\n' "MUTATION $1"
    return
  fi
  ASSERTIONS=$((ASSERTIONS - 1))
  for w in $K2H_WORLDS; do cp "$mut" "$K2H/$w/$(cat "$K2H/$w/.layout")/mutant-$1.sh"; done
  k2h_score "MUTATION $1" "mutant-$1.sh" "$4"
}
k2h_mutate k2-current-map-revert \
  '        k2_pd_in_force "$k2_root" "${P_AT[$((N - 1))]:-}" "$LAST_FILE"' \
  '        K2_RUN="$K2_PD"; K2_PD_FROM="the CURRENT ${K2_PD}"; K2_PD_FALLBACK=""; K2_PD_AMBIG=""' \
  "FAIL SILENT FAIL FAIL FAIL FAIL"
k2h_mutate k2-fallback-unmarked \
  '        if [ -n "$K2_PD_FALLBACK" ]; then' \
  '        if false; then' \
  "SILENT FAIL FAIL FAIL PENDING PENDING"
k2h_mutate k2-first-pass-time \
  '        k2_pd_in_force "$k2_root" "${P_AT[$((N - 1))]:-}" "$LAST_FILE"' \
  '        k2_pd_in_force "$k2_root" "${P_AT[0]:-}" "$LAST_FILE"' \
  "SILENT FAIL SILENT FAIL/FB PENDING PENDING"
# The added-commit cross-check dropped: ONLY the two merge worlds move, both to the acquittal.
k2h_mutate k2-added-commit-dropped \
  '  cmp -s "$AC_T/k2-pd-in-force.sh" "$AC_T/k2-pd-at-add.sh" || K2_PD_AMBIG="${c:0:12} vs ${a:0:12}"' \
  '  :' \
  "SILENT FAIL FAIL FAIL/FB SILENT SILENT"

echo
# --- PASS 1 HAS NO PREVIOUS PASS -----------------------------------------------
# THE SEED GAP THESE CLOSE. Every case above declares pass 1 with prior == crit, and that
# is the ONE shape that cannot exercise the pass-1 branch of arm D's SCOPE_GREW counter.
# The reference consumer's dominant pass-1 shape is the other one -- an honest
# `findings_critical_prior_scope: 0`, because there is no previous pass. seed.sh carries
# the census and the three cases.
#
# THE EXIT CODE CANNOT BE THE ASSERTION on the first case: it exits 1 with the MOVING
# ARTIFACT remedy before the guard and exits 1 with the generic remedy after it. Only the
# MESSAGE separates a validator that excludes pass 1 from one that counts it.
expect pass1-honest-zero-unconverged 1 \
  "p1 1C at prior 0, p2 clears it, exit still short on 2 blocking MAJOR -- D fires" s1-adversarial-p
expect_says pass1-honest-zero-unconverged s1-adversarial-p "D-generic-at-pass1" \
  "$D_GENERIC"
expect_silent pass1-honest-zero-unconverged "MOVING ARTIFACT" pass1-honest-zero-then-growth \
  "an honest prior_scope 0 at pass 1 reads as scope the sprint ADDED, and every series whose FIRST pass found a CRITICAL is then told to freeze"
expect_silent pass1-honest-zero-unconverged "CUT the added scope" pass1-honest-zero-then-growth \
  "the remedy names an action this series cannot take: there is no added scope to cut"

# THE NEAR-MISS CONTROL. Byte-identical pass 1; pass 2 converges. Green on both sides of
# the guard -- a terminal EXIT_CONDITION_MET takes arm D's first branch and never reads
# SCOPE_GREW -- so it pins that the guard bought nothing by suppressing a terminal verdict.
expect pass1-honest-zero-converges 0 \
  "NEAR-MISS CONTROL: same p1, p2 converges -- a terminal MET never reads SCOPE_GREW" s1-adversarial-p

# THE OVER-FIRE CONTROL. Growth at a pass that HAS a predecessor is the arm's real subject
# and must be untouched. `scope-grew-unconverged` above is the same claim on a longer series.
expect pass1-honest-zero-then-growth 1 \
  "OVER-FIRE CONTROL: p2 finds 3C against 1 in prior scope -- genuine growth" s1-adversarial-p
expect_says pass1-honest-zero-then-growth s1-adversarial-p "D-moving-at-pass2" \
  "MOVING ARTIFACT" "CUT the added scope"

# GROWTH AT prior == 0 AFTER PASS 1 -- the case that separates "no previous pass exists"
# from "prior is zero". Every case above puts its pass-2 growth at prior > 0, so a guard
# keyed on `[ "$prior" -gt 0 ]` passes all of them and is WRONG: it also drops the purest
# moving-artifact signal there is, a pass none of whose CRITICALs sit in reviewed text.
expect scope-grew-at-zero-prior 1 \
  "p1 declares prior == crit, p2 finds 3C with NONE in prior scope -- the sprint added all of them" s1-adversarial-p
expect_says scope-grew-at-zero-prior s1-adversarial-p "D-moving-at-zero-prior" \
  "MOVING ARTIFACT" "CUT the added scope"

# A SERIES WHOSE FIRST FILE IS NOT PASS 1 -- the case that separates "has no predecessor"
# from "is numbered 1". p2 is the first file on disk; its honest prior 0 is not growth.
expect series-starts-at-pass2 1 \
  "the series starts at p2 -- its first file has no predecessor either, and p3 clears the CRITICAL" s1-adversarial-p
expect_says series-starts-at-pass2 s1-adversarial-p "D-generic-at-first-file" \
  "$D_GENERIC"
expect_silent series-starts-at-pass2 "MOVING ARTIFACT" scope-grew-at-zero-prior \
  "a guard reading the pass NUMBER counts the first file of every series that starts above 1, and five of the consumer's 84 do"

# --- MUTATION: the pass-1 guard, keyed on LOCATION and on BEHAVIOUR -------------
# FOUR cells, four mutants. The last two are WRONG FIXES, not vandalism: each is a guard a
# careful author would write, each satisfies every case the first two cells can see, and
# each is killed by exactly one of the cells added for it. A byte-lock on the shipped
# condition would flag them too -- and an author who re-anchors the mutations, as
# fixture-mutants.md tells them to, is then green on a validator that lost real coverage.
# So the discrimination lives in BEHAVIOUR, and the anchor arm is only the guard on the
# mutations being applied at all.
#
#                                    unconv   growth   zero-prior   starts-p2
#   shipped                          GENERIC  MOVING   MOVING       GENERIC
#   m1  guard removed                MOVING   MOVING   MOVING       MOVING     <- both
#   m2  guard on a wrong variable    GENERIC  GENERIC  GENERIC      GENERIC    <- growth
#   m3  guard on `prior > 0`         GENERIC  MOVING   GENERIC      GENERIC    <- zero-prior
#   m4  guard on the pass NUMBER     GENERIC  MOVING   MOVING       MOVING     <- starts-p2
#
# m3 and m4 move ONE cell each, and it is a different cell. That is the whole assertion:
# "this pass has no PREDECESSOR" is neither "prior is zero" nor "the number is 1".
#
# Anchored on the WHOLE condition line. `[ -n "$crit" ] && [ -n "$prior" ]` opens arm C's
# partition check as well, so a mutation keyed on the shared prefix would edit that instead
# and come out green here.
SG_ANCHOR='  if [ -n "$crit" ] && [ -n "$prior" ] && [ -n "$PREV_CRIT" ] && [ "$crit" -gt "$prior" ]; then'
ASSERTIONS=$((ASSERTIONS + 1))
sg_n="$(grep -cF -- "$SG_ANCHOR" "$VALIDATOR")" || sg_n=0
sg_ctl="$(grep -cF -- "$SG_ANCHOR-no-such-line" "$VALIDATOR")" || sg_ctl=0
if [ "$sg_n" -ne 1 ] || [ "$sg_ctl" -ne 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s the anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0) -- the two mutants below prove nothing\n' \
    "MUTATION sg-anchor" "$sg_n" "$sg_ctl"
else
  printf '  ok    %-28s the anchor is unique in %s (impossible-anchor control: 0)\n' \
    "MUTATION sg-anchor" "$(basename "$VALIDATOR")"
fi

SG_CASES="pass1-honest-zero-unconverged pass1-honest-zero-then-growth scope-grew-at-zero-prior series-starts-at-pass2"
SG_REAL="GENERIC MOVING MOVING GENERIC"

sg_remedy() {  # $1 script  $2 case-dir -> which of arm D's two remedies it emitted
  local out
  out="$(bash "$1" --series "$ROOT/$2/s1-adversarial-p" \
          --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  case "$out" in
    *"MOVING ARTIFACT"*) printf 'MOVING\n' ;;
    *"$D_GENERIC"*)      printf 'GENERIC\n' ;;
    *)                   printf 'NEITHER\n' ;;
  esac
}

sg_score() {  # $1 label  $2 script  $3 expected pair
  local label="$1" script="$2" want="$3" got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  for c in $SG_CASES; do got="$got $(sg_remedy "$script" "$c")"; done
  if [ "$(echo $got)" = "$(echo $want)" ]; then
    printf '  ok    %-28s [%s]\n' "$label" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$label" "$(echo $got)" "$(echo $want)"
  fi
}

# THE UNMUTATED CONTROL, from $ROOT like every mutant. A copy that dies resolving a
# sibling emits nothing, NEITHER is what "no output" scores as, and NEITHER would read
# as a kill on both mutants below.
SG_CTRL="$ROOT/control-scope-grew.sh"
cp "$VALIDATOR" "$SG_CTRL"
sg_score "CONTROL scope-grew copy" "$SG_CTRL" "$SG_REAL"

sg_mutate() {  # $1 label  $2 replacement condition line  $3 expected pair
  local label="$1" new="$2" want="$3"
  local mut="$ROOT/mutant-$label.sh"
  MUT_OLD="$SG_ANCHOR" MUT_NEW="$new" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut"; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation matched NOTHING -- this assertion proves nothing\n' "MUTATION $label"
    return
  fi
  if ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutant is not a valid shell script -- its silence is not a kill\n' "MUTATION $label"
    return
  fi
  sg_score "MUTATION $label" "$mut" "$want"
}

# m1 -- REMOVE THE GUARD. This is the shipped defect on demand: pass 1's honest zero is
# counted as growth and the unconverged series is handed the freeze-and-cut remedy.
sg_mutate scope-grew-unguarded \
  '  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$crit" -gt "$prior" ]; then' \
  "MOVING MOVING MOVING MOVING"

# m2 -- GUARD ON THE WRONG VARIABLE. STALL_FROM is also empty at pass 1, so it looks like
# "a previous pass exists" and is not: it is empty on every pass of a series that never
# stalls, which kills the increment outright. The unconverged case is GREEN against this
# mutant -- right answer, no working guard -- and only the growth case says so.
sg_mutate scope-grew-wrong-var \
  '  if [ -n "$crit" ] && [ -n "$prior" ] && [ -n "$STALL_FROM" ] && [ "$crit" -gt "$prior" ]; then' \
  "GENERIC GENERIC GENERIC GENERIC"

# m3 -- A WRONG FIX: "there is no previous pass" spelled as "prior is zero". It excludes
# pass 1 in every case seeded before `scope-grew-at-zero-prior` existed, and it also
# excludes a mid-cycle pass whose CRITICALs are ALL in added scope -- the strongest
# moving-artifact evidence the field can carry.
sg_mutate scope-grew-prior-zero \
  '  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$prior" -gt 0 ] && [ "$crit" -gt "$prior" ]; then' \
  "GENERIC MOVING GENERIC GENERIC"

# m4 -- A WRONG FIX: "there is no previous pass" spelled as "the pass number is not 1".
# True of pass 1 and false of nothing else, so it counts the FIRST FILE of every series
# that starts above pass 1 -- which is the state the guard exists to exclude. The pass
# number is read off `$f` the way order_key does, so the mutant is the guard an author
# would actually write.
sg_mutate scope-grew-pass-number \
  '  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$(printf "%s" "$f" | sed -E "s/.*[^0-9]([0-9]+)\.md$/\1/")" != "1" ] && [ "$crit" -gt "$prior" ]; then' \
  "GENERIC MOVING MOVING MOVING"

echo
# --- ARM J's DOOR: a re-open is sanctioned by a VALID record, not by naming one ------------
expect reopen-record-missing 1 "resolves_divergence names a record that was never written -- FAIL (J)" s1-adversarial-p
expect_says reopen-record-missing s1-adversarial-p "J-door-validates" \
  "FAIL (J -- REOPEN)" "the record it names does not exist"
expect_state reopen-record-missing s1-adversarial-p REOPENED 3 "a citation of nothing is not a sanctioned exit -- deny"
expect drift-spec-no-cap 1 "a SPEC.md re-open whose scope_delta names no CAP-<n> or FR-S<N>-<n> -- FAIL (J, F5)" s1-adversarial-p
expect_says drift-spec-no-cap s1-adversarial-p "F5-reopen-spec" \
  "FAIL (J -- REOPEN)" "names no CAP-<n>"
expect_state drift-spec-no-cap s1-adversarial-p REOPENED 3 "a spec amendment naming nothing it moved is not a release -- deny"
expect drift-spec-cap 0 "NEAR-MISS: the same SPEC.md record naming CAP-2 -- PASS" s1-adversarial-p

echo
# --- ARM J2: TERMINAL DRIFT --------------------------------------------------------------
# Each case is a stamped repo built by seed.sh with TWO stamp commits (0.663.0 at 09:00, 0.669.0
# at 10:00); its series lives under `_bmad-output/planning-artifacts/s1/`, where the gate reads it.
J2P=_bmad-output/planning-artifacts/s1/spec-adversarial-p
expect drift-unrecorded 1 "SPEC.md moved after MET, nothing on the record -- FAIL (J2)" "$J2P"
expect_says drift-unrecorded "$J2P" "J2-names-both-remedies" \
  "FAIL (J2 -- DRIFT): spec-adversarial-p1.md stamps EXIT_CONDITION_MET" "REPAIR" "REOPEN" \
  "artifact_sha_before:"
expect_state drift-unrecorded "$J2P" CONVERGED 0 "arm J2 is GATE-ONLY: --cycle-state stays CONVERGED under drift"
expect drift-same-bytes 0 "DECOY: the bytes on disk are the notarized bytes" "$J2P"
expect drift-pre-stamp 0 "the series opened before J2's stamp (after K's): PENDING, not counted" "$J2P"
expect_says drift-pre-stamp "$J2P" "J2-legacy-pending" "PENDING (J2 -- DRIFT)" "Legacy series."
expect drift-repair-linked 0 "one structured repair link from the notarized sha to the disk sha -- PASS" "$J2P"
expect drift-repair-chain-two-links 0 "two links v1->v2->v3, the first link in the second-read record -- PASS" "$J2P"
expect drift-chain-broken 1 "only the v2->v3 link: no chain from the notarized sha -- FAIL (J2)" "$J2P"
expect drift-repair-fork 1 "two links from the same sha -- FAIL (J2), even though one of them reaches the disk sha" "$J2P"
expect_says drift-repair-fork "$J2P" "J2-fork-names-both" \
  "FAIL (J2 -- DRIFT)" "gate-planning-repair-p1.md gate-planning-repair-p2.md"
expect drift-repair-unstructured 1 "a link with both shas and no derivation: arm H would refuse it -- FAIL (J2)" "$J2P"
expect drift-reopen-verified 0 "REOPEN_AFTER_MET record + ONE verify pass: the verify pass is terminal -- PASS" "$J2P"
expect drift-reopen-no-verify 1 "the REOPEN record without the verify pass is not a link -- FAIL (J2)" "$J2P"
expect drift-reopen-after-not-disk 1 "verified at v2, then moved to v3 with no record -- FAIL (J2)" "$J2P"
expect drift-cumulative 0 "RESIDUE: prd.md is cumulative and not in the subject -- J2 silent" "$J2P"
expect drift-list 0 "RESIDUE: a comma list is not one file, even when its first member moved -- J2 silent" "$J2P"

# THE SKIP IS IN THE PROCEDURE BECAUSE A BARE --series MATCHING NOTHING FAILS. gate-validation.md
# tells the gate to skip a sprint dir holding no *-adversarial-p series; this pins why.
ASSERTIONS=$((ASSERTIONS + 1))
es_out="$(bash "$VALIDATOR" --series "$ROOT/drift-empty-sprint/$J2P" 2>&1)"; es_rc=$?
if [ "$es_rc" -eq 1 ] && grep -qF -- "matched nothing" <<<"$es_out"; then
  printf '  ok    %-28s exit=1 "matched nothing" (%s)\n' "drift-empty-sprint" "the procedure skips such a sprint rather than running the check"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s exit=%s -- a --series over an empty sprint dir must exit 1 naming the empty match\n' "drift-empty-sprint" "$es_rc"
fi

# --- MUTATION: J2's walk, fork check, subject, stamp rebinding; J's door ------------------
#                         unrec  pre      linked  chain2  fork   cumul   reopen-ver
#   shipped               FAIL   PENDING  SILENT  SILENT  FAIL   SILENT  SILENT
#   chain walk removed    FAIL   PENDING  FAIL    FAIL    FAIL   SILENT  SILENT
#   fork check removed    FAIL   PENDING  SILENT  SILENT  SILENT SILENT  SILENT
#   subject widened       FAIL   PENDING  SILENT  SILENT  FAIL   FAIL    SILENT
#   stamp not rebound     FAIL   FAIL     SILENT  SILENT  FAIL   SILENT  SILENT
# Built in a copy of the validator's directory carrying both siblings, with an unmutated control.
J2_CASES="drift-unrecorded drift-pre-stamp drift-repair-linked drift-repair-chain-two-links drift-repair-fork drift-cumulative drift-reopen-verified"
J2_REAL="FAIL PENDING SILENT SILENT FAIL SILENT SILENT"
J2_MUT="$ROOT/j2-mutants"; mkdir -p "$J2_MUT"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$J2_MUT/validate-steering-budget.sh"
cp "$(dirname "$VALIDATOR")/partition-document.sh" "$J2_MUT/partition-document.sh"
j2_cell() {  # $1 script  $2 case -> FAIL | PENDING | SILENT
  local out
  out="$(bash "$1" --series "$ROOT/$2/$J2P" --transcript-dir "$ROOT" 2>&1)"
  case "$out" in
    *"FAIL (J2 -- DRIFT)"*)    printf 'FAIL\n' ;;
    *"PENDING (J2 -- DRIFT)"*) printf 'PENDING\n' ;;
    *)                         printf 'SILENT\n' ;;
  esac
}
j2_score() {  # $1 label  $2 script  $3 expected row
  local got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  for c in $J2_CASES; do got="$got $(j2_cell "$2" "$c")"; done
  if [ "$(echo $got)" = "$(echo $3)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
cp "$VALIDATOR" "$J2_MUT/control.sh"
j2_score "CONTROL j2 copy" "$J2_MUT/control.sh" "$J2_REAL"

# $1 label  $2 expected row  $3.. old/new pairs, EACH anchor exactly once in the validator.
# Every layer of a layered subject is reverted. The fork mutant removes the fork verdict AND the
# single-hit guard below it, which on its own also stops a two-hit walk as incomplete (measured:
# with only the first layer removed the fork cell still read FAIL). It also drops the fork
# conjunct of the self-probe, which would otherwise refuse the mutant with exit 2.
j2_mut_build() {  # $1 out  $2.. old/new pairs -> 0 applied, 1 an anchor was not unique
  local out="$1"; shift
  python3 - "$VALIDATOR" "$out" "$@" <<'PY'
import sys
s = open(sys.argv[1]).read()
a = sys.argv[3:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1: sys.exit(1)
    s = s.replace(a[i], a[i + 1])
open(sys.argv[2], "w").write(s)
PY
}
j2_mutate() {  # $1 label  $2 expected row  $3.. old/new pairs
  local label="$1" want="$2" mut="$J2_MUT/mutant-$1.sh"; shift 2
  if ! j2_mut_build "$mut" "$@" || cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s an anchor is not unique, the mutation DID NOT APPLY, or the mutant is not valid shell\n' "MUTATION $label"
    return
  fi
  j2_score "MUTATION $label" "$mut" "$want"
}
j2_mutate j2-chain-walk "FAIL PENDING FAIL FAIL FAIL SILENT SILENT" \
  '      j2_walk "$j2_sha" "$j2_disk" "$AC_T/j2-links"' '      J2_END=incomplete'
j2_mutate j2-fork-check "FAIL PENDING SILENT SILENT SILENT SILENT SILENT" \
  '    if [ "$hits" -ge 2 ]; then J2_END=fork; return 0; fi' '    :' \
  '    [ "$hits" -eq 1 ] || return 0' '    [ "$hits" -ge 1 ] || return 0' \
  '[ "$j2p3" != fork ]' '[ -z "$j2p3" ]'
j2_mutate j2-subject "FAIL PENDING SILENT SILENT FAIL FAIL SILENT" \
  '  if [ -n "$j2_file" ] && j2_is_sha "$j2_sha" && j2_in_subject "$j2_file"; then' \
  '  if [ -n "$j2_file" ] && j2_is_sha "$j2_sha"; then'
j2_mutate j2-stamp-rebind "FAIL FAIL SILENT SILENT FAIL SILENT SILENT" \
  '          j2_stamp="$(K_RELEASE="$J2_RELEASE" k_stamp_parse < "$STAMP_LOG")"' \
  '          j2_stamp="$(k_stamp_parse < "$STAMP_LOG")"'

# J's door, scored on its own four cells in --cycle-state, the mode the hooks read.
JD_CASES="reopen-recorded reopen-record-missing drift-spec-no-cap drift-spec-cap"
JD_REAL="CONVERGED REOPENED REOPENED CONVERGED"
jd_score() {  # $1 label  $2 script  $3 expected row
  local got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  for c in $JD_CASES; do
    got="$got $(bash "$2" --series "$ROOT/$c/s1-adversarial-p" --cycle-state --transcript-dir "$ROOT" 2>/dev/null | cut -f1)"
  done
  if [ "$(echo $got)" = "$(echo $3)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
jd_score "CONTROL j-door copy" "$J2_MUT/control.sh" "$JD_REAL"
jd_mutate() {  # $1 label  $2 expected row  $3.. old/new pairs
  local label="$1" want="$2" mut="$J2_MUT/mutant-$1.sh"; shift 2
  if ! j2_mut_build "$mut" "$@" || cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s an anchor is not unique, the mutation DID NOT APPLY, or the mutant is not valid shell\n' "MUTATION $label"
    return
  fi
  jd_score "MUTATION $label" "$mut" "$want"
}
# The door accepting the field again -- the shipped defect on demand. Both invalid records pass.
jd_mutate j-citation "CONVERGED CONVERGED CONVERGED CONVERGED" \
  '    if validate_record "$j_rec" "${P_FILE[$i]}" "$i"; then' '    if true; then'
# F5's SPEC rule alone. Only the SPEC.md cell with no CAP moves, so the door mutant above is not
# the only thing standing between a spec amendment and an unnamed scope change.
jd_mutate f5-reopen-spec "CONVERGED REOPENED CONVERGED CONVERGED" \
  '      if [ "${r_art##*/}" = "SPEC.md" ] && ! [[ "$delta" =~ $r_re ]]; then' '      if false; then'

echo
# --- ARM H: the record is named by its SERIES, behind a stamp -------------------------------
# Every arm-H case above sits in no stamped repo and names its records `s1-brief-repair-p<M>`
# against the stem `s1`, so each one is a FOREIGN record that reads PENDING (no stamp). These
# worlds are stamped git repos, one property apart. The series is `prd-adversarial-p1/p2`, 3 MAJOR
# falling to 0, so arm H owes `prd-repair-p1.md`. The release is READ from the validator, so a
# renumbered H_RELEASE moves the worlds with it. Five worlds, one cell each (`<class>/<exit>`):
#   stem-post     owed name present, series opened after the stamp     -> SILENT/0
#   foreign-post  only `arch-repair-p1.md` (another series' record)     -> FOREIGN/1
#   foreign-pre   the same record, series opened BEFORE the stamp       -> PENDING/0
#   pred-stamp    the same record, repo stamped only at H_RELEASE's
#                 predecessor (but above K_RELEASE)                      -> PENDING/0
#   none-post     no record at all                                      -> MISSING/1 (unchanged)
H_REL="$(sed -n 's/^H_RELEASE="\([0-9.]*\)"$/\1/p' "$VALIDATOR")"
IFS=. read -r h_ma h_mi h_pa <<EOF
$H_REL
EOF
H_PRED="${h_ma}.$((h_mi - 1)).${h_pa}"
HW="$ROOT/.h-worlds"
h_world() {  # $1 world  $2 stamp version  $3 first invoked_at  $4 record name ("" = none)
  local w="$HW/$1" n
  mkdir -p "$w/.claude" || return 1
  printf 'version: %s\n' "$2" > "$w/.claude/.ai-dlc-version"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    cd "$w" || exit 1
    git init -q . >/dev/null || exit 1
    git add .claude/.ai-dlc-version || exit 1
    GIT_COMMITTER_DATE=2026-09-29T10:00:00Z GIT_AUTHOR_DATE=2026-09-29T10:00:00Z \
      git -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false \
          -c core.hooksPath=/dev/null commit -q -m stamp >/dev/null ) || return 1
  for n in 1 2; do
    {
      printf '# prd -- adversarial pass %s\n\n' "$n"
      printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
      printf 'skill: ai-dlc-adversary-review\n'
      if [ "$n" = 1 ]; then printf 'invoked_at: %s\n' "$3"; else printf 'invoked_at: 2026-09-29T12:00:00Z\n'; fi
      printf 'tool_use_id: toolu_fixture_h%s\n' "$n"
      printf 'mode: subagent\nlead_role: pm\nartifact: prd.md\n'
      printf 'artifact_sha: %s\n' 0000000000000000000000000000000000000000000000000000000000000000
      printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\n'
      if [ "$n" = 1 ]; then printf 'findings_major: 3\nverdict: EXIT_CONDITION_NOT_MET\n'
      else printf 'findings_major: 0\nverdict: EXIT_CONDITION_MET\n'; fi
      printf 'findings_major_underived: 0\nfindings_minor: 0\n'
      printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
    } > "$w/prd-adversarial-p$n.md"
  done
  [ -z "$4" ] || printf '# Repair record\n\n### F1 -- MAJOR\n- disposition: repaired\n- edit: prd.md:4\n- derivation:\n    $ grep -c x prd.md\n    1\n' > "$w/$4"
}
H_WORLDS="stem-post foreign-post foreign-pre pred-stamp none-post"
H_REAL="SILENT/0 FOREIGN/1 PENDING/0 PENDING/0 MISSING/1"
H_OK=1
[ -n "$H_REL" ] && [ "$h_mi" -ge 1 ] 2>/dev/null || H_OK=0
h_world stem-post    "$H_REL"  2026-09-29T11:00:00Z prd-repair-p1.md  || H_OK=0
h_world foreign-post "$H_REL"  2026-09-29T11:00:00Z arch-repair-p1.md || H_OK=0
h_world foreign-pre  "$H_REL"  2026-09-29T09:00:00Z arch-repair-p1.md || H_OK=0
h_world pred-stamp   "$H_PRED" 2026-09-29T11:00:00Z arch-repair-p1.md || H_OK=0
h_world none-post    "$H_REL"  2026-09-29T11:00:00Z ""                || H_OK=0
# Not in the row: the consumer's commonest misname, this series' OWN record under its pass stem.
# It fails like foreign-post and must hand the opposite remedy (rename it, not leave it).
h_world misnamed-post "$H_REL" 2026-09-29T11:00:00Z prd-adversarial-repair-p1.md || H_OK=0
# THE WORLDS ARE WHAT THEY CLAIM: the release was read, every world built, the predecessor
# still satisfies K_RELEASE (so a stamp read that forgot to rebind WOULD date pred-stamp), and
# the BASE glob would accept the foreign record -- or the FOREIGN cells test a name nobody uses.
ASSERTIONS=$((ASSERTIONS + 1))
h_krel="$(sed -n 's/^K_RELEASE="\([0-9.]*\)"$/\1/p' "$VALIDATOR")"
h_glob=0; for h_c in "$HW/foreign-post"/*-repair-p1.md; do [ -f "$h_c" ] && h_glob=$((h_glob + 1)); done
if [ "$H_OK" -ne 1 ] || [ -z "$h_krel" ] || [ "$(printf '%s\n%s\n' "$h_krel" "$H_PRED" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" != "$h_krel" ] || [ "$h_glob" -ne 1 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN: built=%s release=%s pred=%s K_RELEASE=%s old-glob hits=%s (want 1)\n' \
    "h-worlds" "$H_OK" "$H_REL" "$H_PRED" "$h_krel" "$h_glob"
else
  printf '  ok    %-28s release %s, predecessor %s >= K_RELEASE %s; the old glob takes the foreign record\n' \
    "h-worlds" "$H_REL" "$H_PRED" "$h_krel"
fi
h_cell() {  # $1 script  $2 world -> <class>/<exit>
  local out rc v
  out="$(bash "$1" --series "$HW/$2/prd-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"; rc=$?
  case "$out" in
    *"The only structured record for pass"*)  v=FOREIGN ;;
    *"PENDING (H -- REPAIR-RECORD)"*)         v=PENDING ;;
    *"the lead having repaired inline"*)      v=MISSING ;;
    *"FAIL ("*)                               v=OTHER ;;
    *"adversarial convergence -- 2 pass"*)    v=SILENT ;;
    *)                                        v=NORUN ;;
  esac
  printf '%s/%s\n' "$v" "$rc"
}
h_score() {  # $1 label  $2 script  $3 expected row
  local got="" w
  ASSERTIONS=$((ASSERTIONS + 1))
  for w in $H_WORLDS; do got="$got $(h_cell "$2" "$w")"; done
  if [ "$(echo $got)" = "$(echo $3)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
h_score "H series-named record" "$VALIDATOR" "$H_REAL"
# The unmutated copy in the mutant directory, siblings beside it. SILENT is a positive cell: it
# requires the validator's own header line, so a copy that never ran reads NORUN, not SILENT.
h_score "CONTROL h copy" "$J2_MUT/control.sh" "$H_REAL"
expect_says_h() {  # $1 world  $2 label  $3... required substrings
  local w="$1" label="$2" out missing="" want; shift 2
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$HW/$w/prd-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  for want in "$@"; do grep -qF -- "$want" <<<"$out" || missing="$missing \"$want\""; done
  if [ -z "$missing" ]; then printf '  ok    %-28s %s\n' "$label" "says what it must"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s missing:%s\n' "$label" "$missing"; fi
}
expect_says_h foreign-post "H-foreign-names-both" "prd-repair-p1.md, is absent" "The only structured record for pass 1 is arch-repair-p1.md" \
  "do not rename a record that belongs to a different repair"
expect_says_h misnamed-post "H-misnamed-own-rename" "The only structured record for pass 1 is prd-adversarial-repair-p1.md" \
  "If it records THIS series' repair, rename it to the owed path"
expect_silent_h() {  # $1 world  $2 token that must be absent  $3 world where it is present (control)
  local out ctl
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$HW/$1/prd-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  ctl="$(bash "$VALIDATOR" --series "$HW/$3/prd-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  if grep -qF -- "$2" <<<"$out"; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s "%s" fired in %s\n' "H-remedy-$1" "$2" "$1"
  elif ! grep -qF -- "$2" <<<"$ctl"; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s CONTROL: "%s" absent from %s too\n' "H-remedy-$1" "$2" "$3"
  else printf '  ok    %-28s the other remedy is silent here, present in %s\n' "H-remedy-$1" "$3"; fi
}
expect_silent_h misnamed-post "do not rename a record" foreign-post
expect_silent_h foreign-post "rename it to the owed path" misnamed-post
expect_says_h foreign-pre  "H-foreign-legacy" "is satisfied only by arch-repair-p1.md, not by" "prd-repair-p1.md" "Legacy series."
expect_says_h pred-stamp   "H-foreign-not-owed" "at ${H_REL} or later -- not owed yet."
h_mutate() {  # $1 label  $2 expected row  $3.. old/new pairs
  local label="$1" want="$2" mut="$J2_MUT/mutant-$1.sh"; shift 2
  if ! j2_mut_build "$mut" "$@" || cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s an anchor is not unique, the mutation DID NOT APPLY, or the mutant is not valid shell\n' "MUTATION $label"
    return
  fi
  h_score "MUTATION $label" "$mut" "$want"
}
# The stamp gate removed: every foreign record is owed, legacy or not.
h_mutate h-stamp-gate "SILENT/0 FOREIGN/1 FOREIGN/1 FOREIGN/1 MISSING/1" \
  '  [ -n "$H_GATE" ] && return 0' '  H_GATE=owed; H_GATE_MSG=mutant; return 0'
# The glob restored, every layer: the owed-name test and the foreign branch both gone, so any
# `*-repair-p<M>.md` satisfies the pass again -- the pre-fix arm.
h_mutate h-glob-restored "SILENT/0 SILENT/0 SILENT/0 SILENT/0 MISSING/1" \
  '  if [ -n "$H_STEM" ] && [ -f "$h_own" ] && [ -s "$h_own" ] && repair_field disposition "$h_own" \' \
  '  if false && [ -f "$h_own" ] && [ -s "$h_own" ] && repair_field disposition "$h_own" \' \
  '    [ -n "$rec" ] && h_foreign="$rec"' '    :'
# The stamp read without the rebinding: K_RELEASE's stamp dates pred-stamp, which then FAILS.
h_mutate h-stamp-rebind "SILENT/0 FOREIGN/1 PENDING/0 FOREIGN/1 MISSING/1" \
  '    h_stamp="$(K_RELEASE="$H_RELEASE" k_stamp_parse < "$STAMP_LOG")"' \
  '    h_stamp="$(k_stamp_parse < "$STAMP_LOG")"'
# The stem keeps `-adversarial`: the owed name becomes `prd-adversarial-repair-p1.md`, and the
# series' own correctly-named record reads as foreign. The self-probe conjunct goes with it.
h_mutate h-stem-unstripped "FOREIGN/1 FOREIGN/1 PENDING/0 PENDING/0 MISSING/1" \
  '  H_STEM="${b%-adversarial}"' '  H_STEM="$b"' \
  '  if [ "$hp1" != prd ] || [ "$hp2" != s289-rr ] || [ "$hp3" != x-p1 ] \' '  if false \'

echo
# --- ARM K3: the requirements series reviews the SUBJECT ------------------------------------
# Every K3 world is its own git repository (trunk main, sprint 9 on a branch) carrying the
# requirements subject, a `.claude/.ai-dlc-version` stamp commit, and passes written by the REAL
# producers: partition-subject.sh's first map writes the manifest, merge-adversarial-shards.sh
# --subject (or --document) writes the pass. Built OUTSIDE $ROOT so the derived pairing loop below
# never walks them (K3 is gate-only; nothing here denies).
#   k3-subject    a sharded subject merge, post-stamp                      exit 0, K3 silent
#   k3-document   terminal pass = a `--document prd.md` merge, post-stamp exit 1, FAIL (K3
#   k3-wrongset   same shard COUNT, other ordinal SET, post-stamp         exit 1, FAIL (K3
#   k3-serial     a one-part subject, one adversary naming the manifest   exit 0, K3 and K2 silent
#   k3-pre        k3-document's shape, series opened BEFORE the stamp     exit 0, PENDING Legacy
#   k3-moved      k3-document's shape, prd.md moved after the pass        exit 0, PENDING bytes
#   k3-pin        installed layout; the copy in force has no --scope-ref  exit 0, PENDING; its
#                 control world, the real copy in force, FAILs (K3
#   k3-armh       a party record beside a fallen pass 1 -> pass 1 still owes requirements-repair-p1
K3W="$(mktemp -d "${TMPDIR:-/tmp}/check24-k3.XXXXXX")" || exit 2
trap 'rm -rf "$ROOT" "$K3W"' EXIT
K3S="$(cd "$(dirname "$VALIDATOR")" && pwd)"
k3g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
k3lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
k3sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
K3PA=_bmad-output/planning-artifacts
# k3_world <name> <stamp-date> [serial] [scripts-dir] -> the world path. serial: only the SPEC changes.
k3_world() {
  local w="$K3W/$1" pa; pa="$w/$K3PA"
  mkdir -p "$pa/s9" "$w/_bmad-output/specs/s9/kernel" "$w/.claude" || return 1
  { ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
      k3g "$w" init -q . && k3g "$w" checkout -q -b main
      { printf '# Brief\n\n## Vision\n\n'; k3lorem vision 10; } > "$pa/product-brief.md"
      { printf '# PRD\n\n## Current state\n\n'; k3lorem current 20; printf '\n## Sprint 8\n\n'; k3lorem s8 20; printf '\n'; } > "$pa/prd.md"
      printf -- '- FR-S8-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md"
      if [ -n "${4:-}" ]; then mkdir -p "$w/scripts/ai-dlc" && cp "$4"/*.sh "$w/scripts/ai-dlc/"; fi
      printf 'version: 9.0.0\n' > "$w/.claude/.ai-dlc-version"
      k3g "$w" add -A && GIT_COMMITTER_DATE="$2" GIT_AUTHOR_DATE="$2" k3g "$w" commit -q -m stamp && k3g "$w" checkout -q -b sprint-9 ); } >/dev/null 2>&1 || return 1
  printf '# SPEC\n\ncap-1: THE system SHALL x.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"
  if [ "${3:-}" != serial ]; then
    printf 'A new brief line.\n' >> "$pa/product-brief.md"
    { printf '## Sprint 9\n\n### Goals\n\n'; k3lorem s9g 30; printf '\n### Requirements\n\n'; k3lorem s9r 30; } >> "$pa/prd.md"
    printf -- '- FR-S9-1: architecture_impact: none\n' >> "$pa/s9/architecture-impact.md"
  fi
  printf '%s' "$w"
}
k3_shard() { # <dir> <key> <cite> <minute> <artifact> <artifact_sha> [n-major]
  local i=0
  { printf '# shard %s\n\n## Findings\n\n' "$2"
    while [ "$i" -lt "${7:-0}" ]; do i=$((i + 1)); printf '### M%s — MAJOR — finding\n\nsections: %s\n\n' "$i" "$3"; done
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: 2026-10-01T10:%02d:00Z\n' "$4"
    printf 'tool_use_id: toolu_k3%s%s\nmode: subagent\nlead_role: requirements\nartifact: %s\nartifact_sha: %s\n' "$2" "$4" "$5" "$6"
    printf 'findings_critical: 0\nfindings_major: %s\nverdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n' "${7:-0}"; } > "$1/$2.md"
}
k3_stems() { local w="$1"
  printf 'product-brief=%s SPEC=%s prd=%s architecture-impact=%s' "$(k3sha "$w/$K3PA/product-brief.md")" \
    "$(k3sha "$w/_bmad-output/specs/s9/kernel/SPEC.md")" "$(k3sha "$w/$K3PA/prd.md")" "$(k3sha "$w/$K3PA/s9/architecture-impact.md")"; }
k3_subject_pass() { # <world> <scripts dir> -> s9/requirements-adversarial-p1.md by merge --subject
  local w="$1" d="$1/$K3PA/s9/shards/requirements-p1" m=0 o sl
  AI_DLC_PROJECT_ROOT="$w" bash "$2/partition-subject.sh" --map 9 > "$w/subject.map" 2>&1 || return 1
  mkdir -p "$d"; sl="$(k3_stems "$w")"
  for o in $(cut -f1 "$w/subject.map"); do m=$((m + 1)); k3_shard "$d" "$o" "$o" "$m" "$K3PA/s9/requirements-subject.md" "$sl"; done
  k3_shard "$d" cross "1, 2" 59 "$K3PA/s9/requirements-subject.md" "$sl"
  bash "$2/merge-adversarial-shards.sh" --subject 9 "$d" >/dev/null 2>&1
}
k3_document_pass() { # <world> <scripts dir> -> the consumer's shape: a --document prd.md merge in the series
  local w="$1" d="$1/$K3PA/s9/shards/prd-p1" m=0 o sl
  AI_DLC_PROJECT_ROOT="$w" bash "$2/partition-subject.sh" --map 9 >/dev/null 2>&1   # the manifest exists, as in a real sprint
  mkdir -p "$d"; sl="$(k3sha "$w/$K3PA/prd.md")"
  for o in $(bash "$2/partition-document.sh" --map "$w/$K3PA/prd.md" | cut -f1); do m=$((m + 1)); k3_shard "$d" "$o" "$o" "$m" "$K3PA/prd.md" "$sl"; done
  k3_shard "$d" cross "1, 2" 59 "$K3PA/prd.md" "$sl"
  bash "$2/merge-adversarial-shards.sh" --document "$w/$K3PA/prd.md" "$d" >/dev/null 2>&1 \
    && mv "$w/$K3PA/s9/prd-adversarial-p1.md" "$w/$K3PA/s9/requirements-adversarial-p1.md"
}
K3_OUT="$K3W/out"
k3_run() { # <validator> <world> -> K3_RC, $K3_OUT
  bash "$1" --series "$2/$K3PA/s9/requirements-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" > "$K3_OUT" 2>&1; K3_RC=$?
}
k3_cell() { # <label> <validator> <world> <want rc> <must-say | -> <must-not-say | ->
  ASSERTIONS=$((ASSERTIONS + 1))
  k3_run "$2" "$3"
  if [ "$K3_RC" -eq "$4" ] && { [ "$5" = - ] || grep -qF -- "$5" "$K3_OUT"; } && { [ "$6" = - ] || ! grep -qF -- "$6" "$K3_OUT"; }; then
    printf '  ok    %-28s exit=%s %s\n' "$1" "$K3_RC" "${5#-}"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s exit=%s want=%s, must say [%s], must not say [%s]\n' "$1" "$K3_RC" "$4" "$5" "$6"
    sed 's/^/          | /' "$K3_OUT"
  fi
}
K3_POST=2026-01-01T00:00:00Z; K3_LATE=2026-12-01T00:00:00Z
K3_BUILT=1
w="$(k3_world k3-subject "$K3_POST")" && k3_subject_pass "$w" "$K3S" || K3_BUILT=0
w="$(k3_world k3-document "$K3_POST")" && k3_document_pass "$w" "$K3S" || K3_BUILT=0
w="$(k3_world k3-wrongset "$K3_POST")" && k3_subject_pass "$w" "$K3S" \
  && awk '/^shard_tool_use_ids:/ { sub(/ 1=/, " 99=") } { print }' "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/p1.n" \
  && mv "$w/p1.n" "$w/$K3PA/s9/requirements-adversarial-p1.md" || K3_BUILT=0
w="$(k3_world k3-serial "$K3_POST" serial)" && { AI_DLC_PROJECT_ROOT="$w" bash "$K3S/partition-subject.sh" --map 9 > "$w/serial.map" 2>&1; [ $? -eq 3 ]; } \
  && k3_shard "$w/$K3PA/s9" requirements-adversarial-p1 x 0 "$K3PA/s9/requirements-subject.md" "$(k3_stems "$w")" \
  && sed -i.b 's/^tool_use_id: .*/tool_use_id: toolu_k3serial/' "$w/$K3PA/s9/requirements-adversarial-p1.md" && rm -f "$w/$K3PA/s9/"*.b || K3_BUILT=0
w="$(k3_world k3-pre "$K3_LATE")" && k3_document_pass "$w" "$K3S" || K3_BUILT=0
w="$(k3_world k3-moved "$K3_POST")" && k3_document_pass "$w" "$K3S" && printf 'moved\n' >> "$w/$K3PA/prd.md" || K3_BUILT=0
# k3-pin: an installed layout whose tracked partition-document.sh has no --scope-ref; the working
# copy (what would run TODAY) is the real one. Control: the same world with the real copy tracked.
K3_STUB="$K3W/stub-scripts"; K3_REAL="$K3W/real-scripts"; mkdir -p "$K3_STUB" "$K3_REAL"
cp "$K3S"/validate-adversarial-convergence.sh "$K3S"/validate-steering-budget.sh "$K3S"/partition-document.sh \
   "$K3S"/partition-subject.sh "$K3S"/merge-adversarial-shards.sh "$K3_REAL/" && cp "$K3_REAL"/*.sh "$K3_STUB/" \
  && awk '{ gsub(/scope-ref/, "scope-XXX"); print }' "$K3_REAL/partition-document.sh" > "$K3_STUB/partition-document.sh" || K3_BUILT=0
# The pin only matters where a MAP is asked -- a manifest pass -- so both worlds carry k3-wrongset's
# pass: the real copy in force FAILs it (count right, set wrong), the stub in force is PENDING.
for v in pin:"$K3_STUB" pinctl:"$K3_REAL"; do
  w="$(k3_world "k3-${v%%:*}" "$K3_POST" "" "${v#*:}")" && cp "$K3_REAL"/*.sh "$w/scripts/ai-dlc/" \
    && k3_subject_pass "$w" "$K3_REAL" \
    && awk '/^shard_tool_use_ids:/ { sub(/ 1=/, " 99=") } { print }' "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/p1.n" \
    && mv "$w/p1.n" "$w/$K3PA/s9/requirements-adversarial-p1.md" || K3_BUILT=0
done
# k3-armh: pass 1 has 2 MAJOR, pass 2 has 0, and only a PARTY record sits beside them.
w="$(k3_world k3-armh "$K3_POST")" && k3_subject_pass "$w" "$K3S" || K3_BUILT=0
if [ "$K3_BUILT" -eq 1 ]; then
  sed -i.b 's/^findings_major: 0$/findings_major: 2/; s/^verdict: .*/verdict: EXIT_CONDITION_NOT_MET/' "$w/$K3PA/s9/requirements-adversarial-p1.md"
  awk '/^## Findings/ { print; print ""; print "### M1 — MAJOR — a"; print ""; print "### M2 — MAJOR — b"; next } { print }' \
    "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/p1.n" && mv "$w/p1.n" "$w/$K3PA/s9/requirements-adversarial-p1.md"
  sed 's/invoked_at: 2026-10-01T10:00:00Z/invoked_at: 2026-10-02T10:00:00Z/; s/^findings_major: 2$/findings_major: 0/; s/^verdict: .*/verdict: EXIT_CONDITION_MET/; /^### M[12] — MAJOR/d' \
    "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/$K3PA/s9/requirements-adversarial-p2.md"
  sed -i.b 's/^invoked_at: 2026-10-01T/invoked_at: 2026-10-02T/' "$w/$K3PA/s9/requirements-adversarial-p2.md"
  rm -f "$w/$K3PA/s9/"*.b
  printf -- '- disposition: repaired\n- edit: prd.md:3\n- derivation: the party round\n' > "$w/$K3PA/s9/requirements-party-repair.md"
fi

echo
echo "--- arm K3 (SUBJECT)"
if [ "$K3_BUILT" -ne 1 ]; then
  FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN -- a K3 world did not build (worlds under %s)\n' "k3-worlds" "$K3W"
else
  K3_DOC_FAIL="FAIL (K3 -- SUBJECT): requirements-adversarial-p1.md: it reviews"
  k3_cell k3-subject  "$VALIDATOR" "$K3W/k3-subject"  0 - "K3 -- SUBJECT"
  k3_cell k3-document "$VALIDATOR" "$K3W/k3-document" 1 "$K3_DOC_FAIL" -
  k3_cell k3-wrongset "$VALIDATOR" "$K3W/k3-wrongset" 1 "is not the subject map's ordinals plus cross" -
  k3_cell k3-serial   "$VALIDATOR" "$K3W/k3-serial"   0 - "K2 -- SECTIONS"
  k3_cell k3-serial-k3 "$VALIDATOR" "$K3W/k3-serial"  0 - "K3 -- SUBJECT): requirements"
  k3_cell k3-pre      "$VALIDATOR" "$K3W/k3-pre"      0 "Legacy series." "FAIL (K3"
  k3_cell k3-moved    "$VALIDATOR" "$K3W/k3-moved"    0 "PENDING (K3 -- SUBJECT)" "FAIL (K3"
  k3_cell k3-pin      "$K3W/k3-pin/scripts/ai-dlc/validate-adversarial-convergence.sh" "$K3W/k3-pin" 0 "has no --scope-ref" "FAIL (K3"
  k3_cell k3-pin-ctl  "$K3W/k3-pinctl/scripts/ai-dlc/validate-adversarial-convergence.sh" "$K3W/k3-pinctl" 1 "asked of the copy in force at" "FALLBACK (K3"
  k3_cell k3-armh     "$VALIDATOR" "$K3W/k3-armh"     1 "no repair" -
  # MUTATION: count-not-identity, and the stamp gate deleted. A copy of the validator's directory
  # with its siblings, and an unmutated control from the same directory scoring all four cells.
  k3_mut_row() { # <validator> -> "<subject> <document> <wrongset> <pre>" rc's
    local r="" c; for c in k3-subject k3-document k3-wrongset k3-pre; do k3_run "$1" "$K3W/$c"; r="$r $K3_RC"; done; printf '%s' "${r# }"; }
  k3_mut() { # <label> <expected row> <old> <new>
    local d; d="$(mktemp -d "$K3W/mut.XXXXXX")"; cp "$K3_REAL"/*.sh "$d/"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [ -n "$3" ]; then
      M_OLD="$3" M_NEW="$4" python3 - "$d/validate-adversarial-convergence.sh" <<'PY' || { FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- anchor not unique\n' "$1"; return; }
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
      cmp -s "$VALIDATOR" "$d/validate-adversarial-convergence.sh" && { FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- byte-identical copy\n' "$1"; return; }
    fi
    got="$(k3_mut_row "$d/validate-adversarial-convergence.sh")"
    if [ "$got" = "$2" ]; then printf '  ok    %-28s row [%s]\n' "$1" "$got"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s row [%s], want [%s]\n' "$1" "$got" "$2"; fi
  }
  k3_mut "K3X0 control (unmutated)" "0 1 1 0" "" ""
  k3_mut "K3X1 count, not identity" "0 1 0 0" \
    '          [ "$k3_have" = "$k3_want_s" ] \' \
    '          [ "$(printf "%s" "$k3_have" | wc -w)" = "$(printf "%s" "$k3_want_s" | wc -w)" ] \'
  k3_mut "K3X2 stamp gate deleted" "0 1 1 1" \
    '    elif [[ "$k3_at" < "$k3_stamp" ]]; then' \
    '    elif false; then'
fi

# --- PAIRING: a case that DENIES must assert the state the hooks read -------------
# THE MECHANISM FOR A DEFECT CLASS THIS FIXTURE HAS NOW HIT TWICE. Gate mode and
# --cycle-state are different code paths with different branch ordering, and the second one
# is what the hooks call to deny a dispatch. A case asserted only in gate mode leaves that
# path untested, which is how `reopen-moved-clean` passed while the state machine reported
# CONVERGED, and how four divergence cases sat green for their whole lifetime while telling
# the hooks to proceed on a series the gate refused.
#
# It is DERIVED, not a hand list: any seeded case whose --cycle-state exits 3 must carry an
# expect_state naming it. Cases that do not deny are exempt, because arms D and H are
# gate-only by design and pairing them would fire on correct cases -- of the 39 cases
# carrying a gate expect, 15 deny and 24 are quiet, so a blanket pairing rule would have
# been wrong 24 times.
#
# ELEVEN OF THOSE FIFTEEN WERE UNPAIRED WHEN THIS ARM WAS WRITTEN, and three of the eleven
# were found BY the arm rather than by the hand-census that preceded it -- that census had
# been run without --transcript/--transcript-dir, so the adjudication cases answered
# CONVERGED and looked exempt. Run this arm the way the harness runs the validator, or it
# measures a different program.
PAIR_MISSING=""
for _d in "$ROOT"/*/; do
  [ -d "$_d" ] || continue
  _c="$(basename "$_d")"
  _pfx=""
  for _f in "$_d"*adversarial*p*.md; do
    [ -f "$_f" ] || continue
    case "$_f" in *-repair-p*) continue ;; esac
    _pfx="$_d$(basename "$_f" | sed 's/[0-9]*\.md$//')"
    break
  done
  [ -n "$_pfx" ] || continue
  bash "$VALIDATOR" --series "$_pfx" --cycle-state --transcript "$TRANSCRIPT" \
    --transcript-dir "$ROOT" >/dev/null 2>&1
  [ $? -eq 3 ] || continue
  grep -qE "^expect_state[[:space:]]+${_c}([[:space:]]|\$)" "$DIR/run.sh" \
    || PAIR_MISSING="$PAIR_MISSING $_c"
done
ASSERTIONS=$((ASSERTIONS + 1))
if [ -n "$PAIR_MISSING" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s case(s) deny via --cycle-state but assert only gate mode:%s\n' \
    "state-mode-pairing" "$PAIR_MISSING"
else
  printf '  ok    %-28s every denying case asserts the state the hooks read\n' "state-mode-pairing"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
