#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# self-update-fixture-log — assert step 2's GATE-RECORD CHECKER, the file at
# reconcile/self-update-fixtures.sh that the push wrapper runs before the consumer's pre-push hook.
#
# The file kept its old path and lost its old job: it used to run step 2's covering fixtures
# serially before the commit, and the push then ran them again in the hook's pool (BL-713). It now
# runs NO fixture. The fixture name is historical too. What is asserted here:
#   G1-G23   the recorded gate verdict authorises the push, bound to the range and to the consumer
#            tree, with the delivery-pull NOT-REQUIRED tolerance and the state it must not cover
#   J1-J14   every verdict the gate can write has a SKILL.md bullet claiming its record
#   W1-W9    SKILL.md step 2's fixture-write rule, the gate-write-commit-push order and the RED-PUSH
#            paragraph, scored on the text an agent reads
#   BH       given fixture names, the checker runs NO fixture (0 hermetic-run invocations)
#   D9, D12  the self-update commit's fixture directories: a `.dist-only` one and one with no run.sh
#            are refused, a complete shippable one is not
#   D12x, D12s-lib, D12s-seed, D12u, D12d
#            a driverless directory upstream does not ship is refused, a support directory upstream
#            ships with no run.sh (lib/, a seed-only one) is accepted, an unconfirmable run.sh read
#            or directory read refused
#   D12p     through the real self-update-push.sh, the push is judged by the checker the commit wrote
#   UD1-UD9  a whole-directory write over a consumer edit no preclassify row covers: an undiffed repaired
#            file and a consumer-added file the write took are refused UNDIFFED-OVERWRITE; a copy equal to
#            base or to the HEAD^ skill_commit blob, and a diffed file, are not; an unreadable base read is
#            UNCONFIRMED; the remedy lands through the real push wrapper; the DEFER path's apply.sh keeps the
#            edit; a path git lists C-quoted is UNCONFIRMED
#
# The G arms drive the checker through `ck` (lib.sh), which passes exactly the four arguments the
# checker takes and keeps its stdout as the log the arm reads. Arms written against the old runner
# named fixtures; `ck` drops those names, and BH is the arm that asserts what passing them does.
# Usage: run.sh [path-to-self-update-fixtures.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = the harness could not run.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before reading anything (I10). Part 14 names
# AI_DLC_GATE_IN_SAFE_STOP, the key gate_record_open() reads, so without this the arm
# asserts against whatever the developer's settings.json happens to say.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="self-update-fixture-log"
SUFL_RUNNER_ARG="${1:-}"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; no world exists to assert against" >&2; exit 2; }
# shellcheck source=lib.sh
. "$HERE/lib.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh"
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# IN PROCESS (BL-878). The checker is SOURCED once into this shell (its guard returns after defining suf_main) and every
# arm calls suf_main through suf_run (lib.sh) in a subshell. Each suf_run call (lib.sh) is one fx_inproc pass (the inproc: row); the
# five cli cells at the end run it as a program.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped checker, and
# sourcing a pre-wrap checker would run its argument refusal in this shell. So the shape is checked first, on its two
# halves: neither the `suf_main() {` line nor the column-0 source guard is a checker that predates the wrap, which
# prints SKIP and exits 0 -- never an ok. Exactly one half is a respelled checker this fixture can no longer drive,
# which FAILS. The distribution cannot reach the SKIP unnoticed: C5 (validate-fixture-inprocess.sh) refuses a cli
# subject without the guard, and J3 refuses the start count moving.
suf_def=0; suf_guard=0
grep -q '^suf_main() {$' "$RUNNER"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $RUNNER (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || suf_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$RUNNER"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $RUNNER (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || suf_guard=1
if [ "$suf_def$suf_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$suf_def" = 0 ]; then echo "  FAIL  $RUNNER carries the column-0 source guard but no \`suf_main() {\` line -- a respelled checker this fixture cannot drive" >&2; echo "self-update-fixture-log: FAIL (1)" >&2; exit 1; fi
if [ "$suf_guard" = 0 ]; then echo "  FAIL  $RUNNER defines \`suf_main() {\` but carries no column-0 source guard -- a respelled checker; sourcing it would run suf_main in this shell" >&2; echo "self-update-fixture-log: FAIL (1)" >&2; exit 1; fi
# The operand is the resolved path lib.sh picked, so this source takes its own pairing: one pass (the inproc: row).
fx_inproc "$RUNNER"
. "$RUNNER" || { echo "FIXTURE BROKEN: sourcing $RUNNER failed" >&2; exit 2; }
declare -F suf_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $RUNNER defined no suf_main" >&2; exit 2; }
echo "MODE: PUSH"

# --- Parts G1 to G5: the RECORDED GATE VERDICT is what authorises the cycle ------------------
# Step 2 cuts a branch, writes the machinery slice, pushes and auto-merges with NO operator
# gate, and until this arm existed the only record of the decision that permitted the write was
# the operating agent's narration in a PR body. `self-update-gate.sh` prints TSV and the runner
# ran whatever it was handed, so a cycle that never invoked the gate at all was
# indistinguishable from one the gate cleared.
#
# THE PARTS ARE SPLIT BY WHAT EACH ONE CAN SEE, and no two share an input:
#   G1  no record at all                     the state every cycle starts in
#   G2  a record whose verdict is DEFER      a gate that RAN and said no
#   G3  an OK record for a DIFFERENT range   the input a presence-only check accepts
#   G4  the SHIPPING gate's own record       the only part that proves the two grammars agree
#   G5  a DEFER record NEWER than an OK      the input a first-match-wins reader accepts
#
# EVERY ONE OF THESE USES ITS OWN RECORD SET. A consumer already carrying a seeded OK
# records for every range the parts above drive, and an arm asserting a REFUSAL cannot be run in
# a directory where an acquitting record exists — the refusal would be the seed's absence rather
# than the arm's subject, and seeding is not something a part should have to undo.

# --- Part G1: NO record for this range is a refusal, not a green run --------------------------
# Keyed on the `GATE-RECORD:` line in the runner's OWN LOG as well as the exit code, because
# exit 2 has seven producers in this runner and a part reading only the code cannot say which
# one answered. The named set is wholly legitimate for this range — the only thing wrong here is
# that nothing authorised the cycle.
#
# A RECORD FOR AN UNRELATED RANGE IS SEEDED FIRST, AND IT IS WHAT MAKES THIS PART ITS OWN. An
# EMPTY record directory is the delivery-pull state Part G12 owns, where proceeding is correct;
# with one record present this consumer has demonstrably recorded a verdict before, so the
# requirement binds. The two parts are one property apart and the seed is the property.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 190 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G1's unrelated-range record"
ERRG1="$GCONS/err-g1.txt"; OUTG1="$GCONS/out-g1.txt"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >"$OUTG1" 2>"$ERRG1"
rc=$?
LG1="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG1" ] && grep -qF "GATE-RECORD:" "$LG1"; then
  ok "with NO gate record the runner refuses with exit 2 and a GATE-RECORD line in its own log"
else
  bad "the runner ran the fixtures with no recorded gate verdict at all (rc=$rc, log '${LG1:-none}'). Step 2 pushes and auto-merges autonomously, so the gate's recorded OK is the only artifact of the decision that permitted the write — without this the suite reports green for a cycle nothing authorised"
fi
if grep -qF "self-update-gate.sh" "$ERRG1"; then
  ok "the stderr remedy names the exact gate command, so the operator is not left to derive it"
else
  bad "the refusal did not name the gate command on stderr. A refusal whose remedy the reader has to reconstruct is where a cycle gets rerun with the check switched off"
fi
# ORDERING, both channels in one arm — the refusal must precede the loop, or a green verdict is
# printed above the finding that condemns it.
if [ -n "$LG1" ] && ! grep -qF "===== FIXTURE " "$LG1" && ! grep -qE '^ +(ok|FAIL|MISS) +' "$OUTG1"; then
  ok "the gate-record refusal is ORDERED BEFORE the fixture loop — no per-fixture section and no per-fixture verdict"
else
  bad "the runner reported fixture verdicts before refusing for a missing gate record: sections $(grep -cF '===== FIXTURE ' "$LG1" 2>/dev/null), stdout verdicts $(grep -cE '^ +(ok|FAIL|MISS) +' "$OUTG1" 2>/dev/null)"
fi

# --- Part G2: a DEFER record is a refusal ----------------------------------------------------
# The input a PRESENCE check cannot see. A record exists, its shas match this exact range, and
# the gate said do not proceed — so a reader that only asks whether a record is there acquits
# the one case the gate explicitly refused.
gin_restore
gin_seed_defer 195
ERRG2="$GCONS/err-g2.txt"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>"$ERRG2"
rc=$?
LG2="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG2" ] && grep -qF "GATE-RECORD:" "$LG2" && grep -qF "DEFER" "$LG2"; then
  ok "a gate record for this range whose verdict is DEFER is refused, and the log says which verdict it read"
else
  bad "a DEFER verdict for this exact range did not stop the run (rc=$rc). A reader asking only whether a record EXISTS acquits the one case the gate explicitly refused, which is worse than no check at all"
fi

# --- Part G3: an OK record for a DIFFERENT range is a refusal --------------------------------
# The input only a sha-matching reader can see. The record is real, its verdict is OK, and it
# classified a different pull entirely — a stale artifact from the previous self-update, which is
# the state a consumer's `_bmad-output/` is in on every cycle after the first.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 196 >/dev/null \
  || bad "FIXTURE ERROR: could not seed the wrong-range record for Part G3"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
rc=$?
LG3="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG3" ] && grep -qF "GATE-RECORD:" "$LG3"; then
  ok "an OK record classifying a DIFFERENT range does not authorise this one — the stale artifact of the previous cycle is refused"
else
  bad "an OK record for another range authorised this cycle (rc=$rc). After the first self-update a consumer's _bmad-output/ always holds one, so a reader that does not compare shas is permanently satisfied by an artifact that classified a different pull"
fi

# --- Part G4: THE SHIPPING GATE'S OWN RECORD, not a forged one -------------------------------
# The only part here that establishes the two halves agree. Every other part seeds a record this
# fixture's own author wrote, so they all prove the reader accepts its author's grammar — which
# stays true through a change to BOTH sides. This one runs `self-update-gate.sh` against the
# throwaway distribution and the seeded consumer, then hands the runner whatever it wrote.
#
# THE THROWAWAY DIST CARRIES A `core/git-hooks/pre-push`, and that is required rather than
# decorative: with no hook at the consumer and none in the distribution the gate emits
# SELF-UPDATE-UNDECIDED ("no pre-push hook found") and records a verdict this runner correctly
# refuses — the part would then fail for a reason that has nothing to do with the join.
GATE_SH="$RECONCILE/self-update-gate.sh"
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
if [ ! -f "$GATE_SH" ]; then
  bad "FIXTURE ERROR: self-update-gate.sh is not beside the runner at $RECONCILE, so the record's WRITER cannot be driven and nothing here establishes that the two grammars agree"
else
  G_OUT="$GCONS/out-g4-gate.txt"; G_ERR="$GCONS/err-g4-gate.txt"
  gin_restore
  bash "$GATE_SH" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" >"$G_OUT" 2>"$G_ERR"
  g_rc=$?
  G_REC="$(ls -t "$GLOG"/self-update-gate-*.md 2>/dev/null | head -1)"
  if [ "$g_rc" -eq 0 ] && [ -n "$G_REC" ] && [ -s "$G_REC" ]; then
    ok "the SHIPPING gate writes a record of its own under _bmad-output/ai-dlc-update/"
    # The record has to say OK for the join to be observable at all; if the gate defers on this
    # seed the arm below cannot distinguish a reader defect from a correct refusal, so the
    # verdict is read and reported rather than assumed.
    g_verdict="$(awk 'index($0, "# verdict:") == 1 { s = substr($0, 11); gsub(/[[:space:]]/, "", s); print s; exit }' "$G_REC")"
    if [ "$g_verdict" = "OK" ]; then
      # IN STEP 2'S ORDER: the slice is written between the gate and the runner, so this arm
      # exercises the join on the state a real cycle presents rather than on a tree nothing
      # touched. Driving the two back to back is what let the shipped runner refuse every
      # legitimate self-update while this part stayed green.
      gin_write_slice
      ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
      rc=$?
      LG4="$(newest_glog)"
      # THE COLUMN COUNT IS READ BEFORE THE VERDICT IS SCORED, so "the writer has not landed
      # yet" and "the join is broken" are two different rows rather than one. A record whose
      # input lines carry two fields is the PRE-correction gate: the reader needs the core path
      # to accept a file the slice moved to `theirs`, and without it every line is unevaluable.
      g4_cols="$(awk -F'\t' 'index($0, "# input: ") == 1 { print NF; exit }' "$G_REC" 2>/dev/null)"
      if [ "$rc" -eq 0 ] && [ -n "$LG4" ] && grep -qE "^GATE-RECORD: (OK|NOT-REQUIRED)" "$LG4" \
         && ! grep -qF "GATE-RECORD: refusing" "$LG4"; then
        ok "the runner ACCEPTS the record the shipping gate wrote, in step 2's real order, and reaches the loop — the writer's grammar and the reader's agree, established by running both and not by one author writing both"
      elif [ "${g4_cols:-0}" -lt 3 ]; then
        bad "PENDING the three-column writer: the shipping gate wrote ${g4_cols:-0}-field input lines and this reader requires three (path, digest, CORE PATH). The core path is what lets an input the slice moved to \`theirs\` be accepted, so a two-column record cannot express the legitimate post-write state at all. This is the only arm here that reads the real writer, and it stays red until that half lands"
      else
        bad "the runner refused the record the SHIPPING gate wrote for this exact range (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG4" 2>/dev/null | cut -c1-160). Every other part here seeds a record this fixture authored, so they would all stay green through a change that broke the join; this is the only arm that can see it"
      fi
      if [ -n "$LG4" ] && grep -qF "$(basename "$G_REC")" "$LG4"; then
        ok "the runner's log header CITES the gate record it accepted, so the two artifacts of one cycle name each other"
      else
        bad "the runner ran on a gate record and did not name it in its log. The pair of records is the approval artifact for an autonomous write, and a log that does not say which record authorised it leaves the reader to guess"
      fi
    else
      bad "FIXTURE ERROR: the shipping gate recorded verdict '${g_verdict:-<absent>}' on this seed, not OK, so the acceptance join below could not be scored. Gate stdout: $(head -1 "$G_OUT" 2>/dev/null | cut -c1-160)"
    fi
  else
    bad "PENDING hand-gate: the shipping self-update-gate.sh wrote no record under $GLOG (rc=$g_rc). The record's WRITER is the other half of batch 78 and lands in a separate commit; until it does, this part is the only failing one here and its failure is that absence, not a defect in the reader"
  fi
fi

# --- Part G5: the NEWEST matching record decides, and it is picked by NAME --------------------
# The input a first-match-wins reader accepts. An OK is written, the operator changes something,
# the gate runs again and DEFERS — and a reader that stops at the first matching record it finds
# revives the superseded OK. Both records match this range exactly, so nothing but the ordering
# separates them.
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
gin_restore
G5_OK="$(SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 100)" \
  || bad "FIXTURE ERROR: could not seed Part G5's OK record"
G5_DEFER="$(SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" DEFER 900)" \
  || bad "FIXTURE ERROR: could not seed Part G5's DEFER record"
# THE SEED IS ASSERTED TO DISCRIMINATE BEFORE IT IS SCORED. Two records written inside the same
# wall-clock second sort identically, and the arm would then pass for either implementation.
if [ -n "${G5_OK:-}" ] && [ -n "${G5_DEFER:-}" ] \
   && [ "$(basename "$G5_DEFER")" \> "$(basename "$G5_OK")" ]; then
  ok "SEED: Part G5's DEFER record sorts strictly AFTER its OK record by name, so the two orderings give different answers"
else
  bad "FIXTURE ERROR: Part G5's two records do not order ('${G5_OK:-none}' then '${G5_DEFER:-none}'). Where the newest and the oldest are the same file, an implementation picking either passes, and the arm below asserts nothing"
fi
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
rc=$?
LG5="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG5" ] && grep -qF "GATE-RECORD:" "$LG5"; then
  ok "with a DEFER record NEWER than an OK for the same range the runner reads the newest and refuses — a superseded OK cannot be revived by reaching further back"
else
  bad "a superseded OK record authorised the cycle (rc=$rc). The gate ran twice and its LAST answer was DEFER; a reader taking the oldest, or the first it happens to encounter, acts on a verdict the gate has already withdrawn"
fi

# --- Parts G6 to G11: the record binds the CONSUMER TREE, and WHICH WAY an input moved --------
# The gate's verdict is a DIFFERENTIAL — it runs the consumer's CURRENT copy of each gating
# script against the incoming one — so the same command over one range answers differently as
# the tree moves. But "nothing moved" is the WRONG rule and it refused every legitimate
# self-update: step 2's order is gate, WRITE THE SLICE, runner, so the files the slice replaced
# are exactly the ones that differ. Measured on the gate's own seed driving both shipping
# programs in that order: 4 of 9 recorded inputs moved, every one to precisely the `theirs` blob
# of its core path.
#
# SO THE DISCRIMINATOR IS WHICH INPUT MOVED AND TOWARD WHAT. `now` equal to the recorded digest
# is untouched; equal to `theirs:<core path>` is the written slice; equal to neither is a third
# hand. And a digest RECORDED as the `theirs` blob, on a path the range changes, is a gate that
# compared the incoming file with itself — the one case where record and tree agree perfectly and
# the verdict is still worthless.
#
# Each part below is the ONE input that separates a reader from a weaker one:
#   G6   a gating script the SLICE wrote           the NORMAL order — a "nothing moved" reader refuses
#   G7   a record naming NO inputs                 a reader looping over zero lines accepts
#   G8   a third-hand edit                         a reader accepting any change accepts
#   G9   a recorded ABSENT that is now PRESENT     a reader skipping ABSENT accepts
#   G10  a recorded digest whose file is now ABSENT  a reader testing only "differs" accepts
#   G11  an input value that is neither hex nor ABSENT  a reader `continue`-ing on the unknown
#   G14  a LATE GATE                               a digest reader cannot see it — the digests agree
#   G15  a forged single-line record               a reader trusting the record's own input list
#   G16  a `-` row naming a non-hook core path     a reader resolving `-` against anything
#
# THE TWO GATING SCRIPTS `seed.sh` WRITES ARE THE SUBJECTS. `gate-changed.sh` moves across
# base..theirs, so it is the one the slice rewrites; `gate-steady.sh` does not, so it must hold
# its recorded digest through every legitimate flow. Both are named by the consumer's own hook,
# which is what the runner derives its required set from.

# --- SEED CONTROL: the two gating scripts must DIFFER across the range in one direction only ---
# `gate-changed.sh` moving and `gate-steady.sh` not moving is the property every part below
# turns on, and where both moved (or neither did) a reader accepting anything and a reader
# accepting only `theirs` would give the same answer on every input here.
gin_cb="$(git -C "$DIST" rev-parse -q --verify "${D_BASE}:core/scripts/gate-changed.sh" 2>/dev/null)"
gin_ct="$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/gate-changed.sh" 2>/dev/null)"
gin_sb="$(git -C "$DIST" rev-parse -q --verify "${D_BASE}:core/scripts/gate-steady.sh" 2>/dev/null)"
gin_st="$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/gate-steady.sh" 2>/dev/null)"
if [ -n "$gin_cb" ] && [ -n "$gin_ct" ] && [ "$gin_cb" != "$gin_ct" ] \
   && [ -n "$gin_sb" ] && [ "$gin_sb" = "$gin_st" ] \
   && [ -f "$GCONS/.githooks/pre-push" ]; then
  ok "SEED: the consumer has its own pre-push hook, and of the two scripts it names exactly ONE changes across base..theirs — so a reader accepting any change and one accepting only \`theirs\` give different answers"
else
  bad "FIXTURE ERROR: the gating-script seed does not discriminate (changed ${gin_cb:-none}->${gin_ct:-none}, steady ${gin_sb:-none}->${gin_st:-none}, hook $([ -f "$GCONS/.githooks/pre-push" ] && echo present || echo ABSENT)). Where both scripts move, or neither does, every arm below passes for a reader that accepts any post-record content"
fi

# --- Part G6: THE NORMAL ORDER — gate, write the slice, runner ACCEPTS ------------------------
# THE LOAD-BEARING ARM, and the one whose absence let the shipped runner refuse every legitimate
# self-update. Step 2 runs the gate on the pre-write tree, writes the slice, then runs this
# runner; the recorded digest of every script the slice replaced is therefore STALE BY DESIGN.
# Measured on the gate's own seed with both shipping programs driven in that order: 4 of 9
# recorded inputs moved, all four to exactly the `theirs` blob. An arm that only ever ran the
# gate and the runner back to back — with nothing written between — could not see it.
gin_restore
gin_seed_clean 200
gin_write_slice
ERRG6="$GCONS/err-g6.txt"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG6"
rc=$?
LG6="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG6" ] && grep -qE "^GATE-RECORD: (OK|NOT-REQUIRED)" "$LG6" \
   && ! grep -qF "GATE-RECORD: refusing" "$LG6"; then
  ok "THE NORMAL ORDER: gate, write the slice, runner — a gating script now holding what this pull SHIPS is the slice the cycle just wrote, and the run reaches the loop"
else
  bad "the legitimate flow was REFUSED (rc=$rc): $(grep -m2 '^GATE-RECORD:' "$LG6" 2>/dev/null | tr '\n' ' ' | cut -c1-200). Step 2 writes the slice BETWEEN the gate and this runner, so the recorded digests of the replaced scripts are stale by design; a rule spelled 'nothing moved' fails closed on every self-update whose range changes a gating script"
fi
# The UNTOUCHED script must still be compared, or the arm above passes for a reader that accepts
# any post-record content whatsoever.
if [ "$(gin_hash "$GIN_STEADY")" = "$gin_sb" ]; then
  ok "...and the script the range does NOT change still holds its recorded content, so the acceptance above is about the slice and not about the check having stopped looking"
else
  bad "gate-steady.sh moved during Part G6, so the acceptance cannot be attributed to the theirs-blob rule. Every arm here would pass for a reader comparing nothing"
fi

# --- Part G7: a record naming NO inputs is malformed ------------------------------------------
# Zero lines to compare is a comparison that cannot fail, and its silence is byte-identical to a
# comparison that passed.
gin_restore
gin_seed "$SR_NO_INPUTS" 210
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG7="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG7" ] && grep -qF "GATE-RECORD:" "$LG7"; then
  ok "a record for this range, verdict OK, naming NO input files is refused — nothing to compare is not the same as nothing changed"
else
  bad "a record naming no inputs authorised the cycle (rc=$rc). A loop over zero input lines reports agreement having compared nothing, which is the silent pass the input binding exists to remove"
fi

# --- Part G8: a THIRD HAND is refused ---------------------------------------------------------
# One property from Part G6: the same script, changed after the record, but to content that is
# neither what was recorded nor what this pull ships. A reader that accepted G6 by dropping the
# comparison altogether accepts this too, and only the pair can tell the two readers apart.
gin_restore
gin_seed_clean 220
printf '%s\n' 'neither the recorded content nor what the pull ships' > "$GCONS/$GIN_CHANGED"
ERRG8="$GCONS/err-g8.txt"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG8"
rc=$?
LG8="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG8" ] && grep -qF "GATE-RECORD: INPUT-MOVED $GIN_CHANGED" "$LG8"; then
  ok "a gating script holding content that is NEITHER the recorded digest NOR what the pull ships is refused as INPUT-MOVED — the acceptance in Part G6 is keyed on the theirs blob, not on 'something changed'"
else
  bad "a third hand edited a file the verdict READ, to content this pull does not ship, and the runner accepted the record (rc=$rc). Then Part G6 passes for a reader that stopped comparing, and the tree binding is gone"
fi
if grep -qF "AS IT NOW STANDS" "$ERRG8"; then
  ok "the remedy tells the operator to re-run the gate against the tree as it now stands, not merely that something is wrong"
else
  bad "the INPUT-MOVED refusal gave the generic missing-record remedy. The operator has a record and will read 'run the gate' as already done"
fi
gin_restore

# --- Part G9: a recorded ABSENT that is now PRESENT, with content the pull does NOT ship -------
# Absence is a recorded VALUE. The gate reads inputs that are not there — a script the hook names
# and the consumer lacks — and its verdict rests on that absence, so a file ARRIVING moves the
# verdict exactly as an edit does. The exception the slice earns is asserted in Part G17.
gin_restore
gin_seed "$(printf '# input: %s\tABSENT\tcore/scripts/gate-steady.sh\n%s' \
  "scripts/ai-dlc/appeared-since.sh" "$(sr_required_inputs "$GCONS")")" 230
mkdir -p "$GCONS/scripts/ai-dlc"
printf '%s\n' 'written after the gate ran, and not what the pull ships' \
  > "$GCONS/scripts/ai-dlc/appeared-since.sh"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG9="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG9" ] && grep -qF "INPUT-MOVED" "$LG9" && grep -qF "appeared-since" "$LG9"; then
  ok "a path the record read as ABSENT and the consumer now holds, with content the pull does not ship, is refused — absence is a value, compared in both directions"
else
  bad "a file that appeared after the gate ran did not move the verdict (rc=$rc). A reader treating ABSENT as 'nothing to check' acquits exactly the direction where a new file arrives between the gate and the run"
fi
rm -f "$GCONS/scripts/ai-dlc/appeared-since.sh"

# --- Part G10: a recorded DIGEST whose file is now ABSENT -------------------------------------
# The mirror of G9, and the input a reader testing only "the hashes differ" cannot see: there is
# no hash to differ from once the file is gone.
gin_restore
gin_seed_clean 240
GIN_SAVED="$(cat "$GCONS/$GIN_STEADY")"
rm -f "$GCONS/$GIN_STEADY"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG10="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG10" ] && grep -qF "INPUT-MOVED $GIN_STEADY" "$LG10"; then
  ok "a path recorded with a digest and now ABSENT from the consumer is refused — a reader comparing only two hashes has none to compare here"
else
  bad "a recorded input file was DELETED after the gate ran and the record was still accepted (rc=$rc). An absent file produces no hash, so a check spelled as 'the hashes differ' passes over it silently"
fi
printf '%s\n' "$GIN_SAVED" > "$GCONS/$GIN_STEADY"; chmod +x "$GCONS/$GIN_STEADY"

# --- Part G11: an input VALUE that is neither a digest nor ABSENT -----------------------------
# A line this reader cannot evaluate. Skipping it is a record silently authorising whatever it
# could not spell, and the skip is invisible — the run goes green with one fewer comparison.
gin_restore
gin_seed "$(printf '# input: %s\tmaybe-changed\tcore/scripts/gate-steady.sh' "$GIN_STEADY")" 250
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG11="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG11" ] && grep -qF "GATE-RECORD:" "$LG11"; then
  ok "an input value that is neither a 40-hex digest nor ABSENT is refused rather than skipped"
else
  bad "an uninterpretable input value was skipped and the record accepted (rc=$rc). A reader that continues past what it cannot spell reports agreement over a line it never evaluated, and nothing announces the missing comparison"
fi

# --- Part G14: A LATE GATE is refused, and NO DIGEST COMPARISON CAN SEE IT --------------------
# The mirror of G6 and the case that makes the whole design necessary. Run the gate AFTER the
# write and every gating script's current copy IS the incoming version, so `cur` and `new` are
# the same bytes, the differential reads OK for the one reason that means nothing, and the record
# it writes carries post-write digests that the runner then re-reads and finds in perfect
# agreement. Record and tree match exactly; the verdict is worthless.
#
# It is keyed on the RANGE instead: a digest recorded as the `theirs` blob, for a path the range
# CHANGES, says the consumer already held the incoming version when the gate ran.
gin_restore
gin_write_slice                      # the slice, written FIRST
gin_seed_clean 270                   # ...and the gate run after it, recording post-write digests
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG14" ] && grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14"; then
  ok "a verdict taken AFTER the slice was written is refused as PRE-WRITTEN — the gate compared the incoming script with a copy of itself, and every digest in that record agrees with the tree"
else
  bad "a gate run on the already-written tree authorised the cycle (rc=$rc). Its OK says only that the file equals itself, and no digest comparison can catch it: the record and the tree agree perfectly. The range is what separates them — recorded == theirs, on a path base..theirs changes"
fi
gin_restore

# --- Part G14b: A SPLIT STAMP IS NOT A SELF-COMPARISON, AND G14's KEY CANNOT TELL THEM APART --
# The false positive in G14's own predicate, and the reason the arm above is not the whole rule.
# A consumer whose `skill_commit` runs ahead of `commit` already holds a PRIOR self-update's
# delivery for some machinery paths. For those, a gate run on its tree records the `theirs` blob
# for a path the range changes — G14's three conjuncts, satisfied honestly — and the cycle is
# refused forever: `commit` advances only under a gated apply, so nothing clears it.
#
# Measured on the reference consumer at 0.542.0 -> 0.547.0 before this arm existed: two machinery
# paths refused, the runner exited 2, and step 2 could not run its fixtures at all.
#
# THE WORLD IS THE SAME AS G14's IN EVERY RESPECT BUT ONE. The slice is written and the record
# carries post-write digests, exactly as above; what differs is a `# skill-commit:` header naming
# an intermediate that already carried that blob. One property apart, in the same run, so the arm
# discriminates between the two cases rather than merely firing on one of them.
gin_write_slice
SR_SKILL_COMMIT="$(git -C "$DIST" rev-parse "${D_SPLIT}^{commit}" 2>/dev/null)" \
  gin_seed_clean 271
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14B="$(newest_glog)"
if [ "$rc" -ne 2 ] || { [ -n "$LG14B" ] && ! grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14B"; }; then
  ok "a split stamp is NOT refused as PRE-WRITTEN — the recorded skill_commit already carried that blob, so the gate read a prior self-update's delivery rather than comparing this pull's file with itself"
else
  bad "a legitimate split-stamp consumer was refused as PRE-WRITTEN (rc=$rc). Its skill_commit already held that blob, so no self-comparison occurred; refusing it wedges every self-update on that consumer permanently, because commit advances only under a gated apply"
fi
gin_restore

# --- Part G14c: THE ACQUITTAL MUST NOT COVER G14's OWN SUBJECT -------------------------------
# The exemption's probe, and the arm that stops G14b from being a hole. Step 2 advances the stamp
# to `theirs` as part of writing the slice, so a gate RE-RUN after the write records
# `skill_commit == theirs` — and a fix keyed on the blob alone then acquits exactly the case G14
# exists to catch, because `theirs:P` trivially equals itself. Driven while building this fix:
# without the equality guard the seeded self-comparison went from REFUSED to ACQUITTED while G14b
# behaved identically, so the blob test could not separate them.
#
# A legitimate split stamp sits at a STRICTLY EARLIER release — `skill_commit` runs ahead of
# `commit`, never ahead of the target — which is what makes excluding equality the right key.
gin_write_slice
SR_SKILL_COMMIT="$(git -C "$DIST" rev-parse "${D_THEIRS}^{commit}" 2>/dev/null)" \
  gin_seed_clean 272
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14C="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG14C" ] && grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14C"; then
  ok "a record whose skill_commit IS theirs is still refused — that is the post-write re-run, not a split stamp, and the blob test alone cannot tell it from one"
else
  bad "a gate re-run after the write was ACQUITTED by the split-stamp exemption (rc=$rc). skill_commit == theirs is what step 2 itself writes, so an exemption that accepts it covers the very case the PRE-WRITTEN arm exists to catch"
fi
gin_restore

# --- Part G14d: AN ABBREVIATED RECORDED SHA IS THE SAME COMMIT -------------------------------
# The comparison is on RESOLVED shas, never on the header string — the rule this file states for
# `base`/`theirs` and which the first cut of the split-stamp field broke. A record carrying an
# abbreviated `skill-commit` names one commit; compared as text against a full sha it differs,
# the equality guard above silently never fires, and G14c's refusal is defeated by a spelling.
gin_write_slice
SR_SKILL_COMMIT="$(git -C "$DIST" rev-parse --short=8 "${D_THEIRS}^{commit}" 2>/dev/null)" \
  gin_seed_clean 273
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14D="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG14D" ] && grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14D"; then
  ok "an ABBREVIATED skill-commit equal to theirs is still refused — the runner peels the recorded value rather than comparing header strings"
else
  bad "an abbreviated skill-commit defeated the equality guard (rc=$rc). '${SR_SKILL_COMMIT:-<short>}' and the full sha name one commit; comparing them as text acquits the post-write re-run"
fi
gin_restore

# --- Part G15: a FORGED record naming inputs of its author's choosing -------------------------
# The record cannot be trusted to declare its own coverage. A single input line satisfies any
# "at least one line" rule, so the required set is DERIVED from the consumer's own hook and the
# scripts it names — both sides of that join come from the same file, and neither is authored.
gin_restore
gin_seed "$(printf '# input: %s\t%s\t-' "$SR_PROBE_REL" "$(git hash-object "$GCONS/$SR_PROBE_REL" 2>/dev/null)")" 280
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG15="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG15" ] && grep -qF "GATE-RECORD: INPUT-MISSING" "$LG15" \
   && grep -qF "$GIN_CHANGED" "$LG15"; then
  ok "a record naming ONE input of its author's choosing is refused: the required set is derived from the consumer's own pre-push hook, and the missing gating scripts are named"
else
  bad "a forged single-line record authorised the cycle (rc=$rc). A reader that trusts the record's own input list can be satisfied by any one line — the coverage has to be derived from the hook, which is the same file the gate derives it from"
fi

# --- Part G16: a `-` row may name ONE core path, and it is the fallback hook -------------------
# Column 1 `-` means "read from the distribution", which exists for exactly one file: the
# fallback hook a consumer without its own cannot name in consumer-relative form. Left
# unconstrained it is an aim-anywhere primitive — a record could point the reader at any
# distribution file that happens to be stable and satisfy its own comparison.
gin_restore
gin_seed "$(printf -- '# input: -\t%s\tcore/scripts/machinery.sh\n%s' \
  "$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/machinery.sh" 2>/dev/null)" \
  "$(sr_required_inputs "$GCONS")")" 290
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG16="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG16" ] && grep -qF "GATE-RECORD:" "$LG16" \
   && grep -qF "core/git-hooks/pre-push" "$LG16"; then
  ok "a distribution-side row naming a core path OTHER than the fallback hook is refused, and the message names the one path that spelling is for"
else
  bad "a \`-\` row naming an arbitrary distribution file was accepted (rc=$rc). That spelling exists for the fallback hook alone; unconstrained it lets a record choose which file its own comparison reads"
fi

# --- Part G17: the slice ADDING a file the pull ships is accepted ------------------------------
# The acquittal for the ABSENT direction, and it is what stops Part G9 from passing for a reader
# that refuses every arrival. A script the hook names, absent when the gate ran, present now with
# exactly the content this pull ships, is the slice — one property from G9's third-hand arrival.
gin_restore
gin_seed "$(printf '# input: %s\tABSENT\tcore/scripts/machinery.sh\n%s' \
  "scripts/ai-dlc/machinery.sh" "$(sr_required_inputs "$GCONS")")" 295
mkdir -p "$GCONS/scripts/ai-dlc"
git -C "$DIST" show "${D_THEIRS}:core/scripts/machinery.sh" > "$GCONS/scripts/ai-dlc/machinery.sh" 2>/dev/null
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG17="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG17" ] && grep -qE "^GATE-RECORD: (OK|NOT-REQUIRED)" "$LG17" \
   && ! grep -qF "GATE-RECORD: refusing" "$LG17"; then
  ok "a path recorded ABSENT and now holding exactly what this pull SHIPS is the slice adding it, and is accepted — G9's refusal is keyed on the content, not on the arrival"
else
  bad "the slice ADDING a file the pull ships was refused (rc=$rc). Then Part G9 passes for a reader that refuses every arrival, and a pull delivering a new gating script wedges"
fi
rm -f "$GCONS/scripts/ai-dlc/machinery.sh"

# --- Parts G18 to G21: the digest column must be LOAD-BEARING ---------------------------------
# ARM 2 accepts an input whose content is now the `theirs` blob, because that is the slice this
# cycle wrote. Taken alone that makes the RECORDED digest decorative: after the write EVERY
# gating script is at `theirs`, so a record whose digests were never read off anything passes.
# Measured on the shipped arm — an all-zero forgery naming the derived required set returned
# rc=0, against a control with one script at a third-hand blob which correctly returned rc=2.
#
# The repair is that a recorded digest differing from `now` must be a content the path actually
# CARRIED in the range: its blob at BASE, or at any commit in `base..theirs` that touches it.
# G21 is why that set is not narrowed to "the base blob" — a split stamp legitimately leaves the
# consumer holding an intermediate release's blob.
#   G18  an all-zero forgery, consumer at theirs   the arm's own subject
#   G19  a decoy digest on the `-` row             the fallback hook always matches theirs
#   G20  the honest normal order                   the acquittal, re-asserted after the narrowing
#   G21  a consumer at an INTERMEDIATE blob        the acquittal a base-only rule would refuse

# --- Part G18: a record whose digests were never read off anything ----------------------------
# The required set is NAMED in full, so arm 1 is satisfied and cannot be what refuses; every
# digest is forty zeroes. The consumer is post-slice, which is the state that makes the forgery
# work: `now` equals `theirs` for the changed script, so a bare theirs-acceptance passes it.
gin_restore
gin_write_slice
gin_seed "$(printf '# input: .githooks/pre-push\t%s\t-\n# input: %s\t%s\tcore/scripts/gate-changed.sh\n# input: %s\t%s\tcore/scripts/gate-steady.sh' \
  "$(git hash-object "$GCONS/.githooks/pre-push")" \
  "$GIN_CHANGED" "$GZERO" "$GIN_STEADY" "$GZERO")" 400
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG18="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG18" ] && grep -qF "GATE-RECORD: INPUT-MOVED $GIN_CHANGED" "$LG18" \
   && grep -qF "is not a content this path carried anywhere" "$LG18"; then
  ok "a record whose digests are content this path NEVER carried is refused, though every file is at theirs — the digest column stays load-bearing after the slice is written"
else
  bad "an all-zero-digest record naming the full required set authorised the cycle (rc=$rc). After the write every gating script IS at theirs, so accepting on that alone makes the recorded digest decorative and a forged record indistinguishable from a gate's"
fi
gin_restore

# --- Part G19: a DECOY digest on the distribution-side row ------------------------------------
# The `-` row's file is the distribution's own copy, which the reader resolves under $DIST — so
# `now` equals the theirs blob by construction on every run, and a theirs-acceptance there would
# accept any digest at all. The slice never writes that file, so strict equality costs nothing.
# The consumer here has NO hook of its own, which is the only state that produces a `-` row.
GH="$(bash "$HERE/seed.sh")"
rm -rf "$GH/.githooks"
GHLOG="$GH/_bmad-output/ai-dlc-update"
mkdir -p "$GHLOG"
SR_INPUTS="$(printf -- '# input: -\t%s\tcore/git-hooks/pre-push\n# input: %s\tABSENT\tcore/scripts/machinery.sh' \
  "$GZERO" "scripts/ai-dlc/machinery.sh")" \
  seed_record "$GHLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 410 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G19's decoy record"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GH" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG19="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG19" ] && grep -qF "INPUT-MOVED" "$LG19" \
   && grep -qF "distribution fallback hook" "$LG19"; then
  ok "a decoy digest on the distribution-side row is refused: that row is compared STRICTLY, because its file is the one the reader itself resolves"
else
  bad "a decoy digest on the \`-\` row was accepted (rc=$rc). The fallback hook's file IS the distribution's copy, so it equals the theirs blob on every run — a theirs-acceptance there accepts forty zeroes as readily as a real digest"
fi
# The ACQUITTAL for the same row, one property apart: the true digest must pass, or the arm
# above would be satisfied by a reader that refuses every `-` row.
SR_INPUTS="$(printf -- '# input: -\t%s\tcore/git-hooks/pre-push\n# input: %s\tABSENT\tcore/scripts/machinery.sh' \
  "$(git hash-object "$DIST/core/git-hooks/pre-push" 2>/dev/null)" "scripts/ai-dlc/machinery.sh")" \
  seed_record "$GHLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 411 >/dev/null
rm -f "$GHLOG"/self-update-fixtures-*.md
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GH" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG19B="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG19B" ] && grep -qE "^GATE-RECORD: (OK|NOT-REQUIRED)" "$LG19B"; then
  ok "...and the row's TRUE digest is accepted, so the refusal above is about the digest and not about the \`-\` spelling"
else
  bad "the distribution-side row was refused with its true digest (rc=$rc). A consumer with no hook of its own would then be refused on every self-update, forever"
fi
rm -rf "$GH"

# --- Part G20: the honest normal order still passes, after the narrowing ----------------------
# Re-asserted here rather than left to Part G6 because the conjunct added for G18 is the one
# thing that could refuse it: the recorded digest is the pre-write content, which must be found
# in the range's history for this path.
gin_restore
gin_seed_clean 420
gin_write_slice
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG20="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG20" ] && grep -qE "^GATE-RECORD: (OK|NOT-REQUIRED)" "$LG20" \
   && ! grep -qF "GATE-RECORD: refusing" "$LG20"; then
  ok "the honest normal order still passes with the carried-content conjunct in place — the pre-write digest IS a content the path carried at base"
else
  bad "the narrowing added for Part G18 refused the legitimate flow (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG20" 2>/dev/null | cut -c1-150). A conjunct that refuses the honest case wedges every self-update, which is worse than the forgery it prevents"
fi
gin_restore

# --- Part G21: a consumer holding an INTERMEDIATE release's blob ------------------------------
# The acquittal a base-only rule would refuse, and the reason the carried-content set is derived
# from `git log` rather than from BASE alone. A split stamp — `skill_commit` ahead of `commit` —
# leaves the consumer at some release BETWEEN base and theirs, which is the normal state after
# any self-update and one this cycle itself creates. Its own three-commit distribution, because
# the shared one has no intermediate commit touching a gating script.
build_i_world
# THE SEED IS ASSERTED TO DISCRIMINATE. Three distinct blobs are what make "carried in the
# range" and "equals the base blob" different answers; where mid equals base or theirs the arm
# below passes for either implementation.
if [ -n "$I_MB" ] && [ "$I_MB" != "$I_BB" ] && [ "$I_MB" != "$I_TB" ]; then
  ok "SEED: the intermediate release's blob differs from BOTH base and theirs, so 'carried anywhere in the range' and 'equals the base blob' give different answers"
else
  bad "FIXTURE ERROR: the intermediate seed's three blobs are not distinct (base ${I_BB:-none}, mid ${I_MB:-none}, theirs ${I_TB:-none}). Part G21 would then pass for a base-only rule and the narrowing is untested"
fi
I_K="$(mktemp -d)"; sufl_tmp "$I_K"
mkdir -p "$I_K/_bmad-output/ai-dlc-update" "$I_K/tests/fixtures/probe" "$I_K/.githooks" "$I_K/scripts/ai-dlc"
printf 'exit 0\n' > "$I_K/tests/fixtures/probe/run.sh"
printf 'bash scripts/ai-dlc/gate-changed.sh\n' > "$I_K/.githooks/pre-push"
# The consumer sits at MID when the gate runs — the split-stamp state.
IG show "${I_M}:core/scripts/gate-changed.sh" > "$I_K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
printf '# base-sha: %s\n# theirs-sha: %s\n# input: .githooks/pre-push\t%s\t-\n# input: scripts/ai-dlc/gate-changed.sh\t%s\tcore/scripts/gate-changed.sh\n\n# verdict: OK\n' \
  "$I_B" "$I_T" "$(git hash-object "$I_K/.githooks/pre-push")" "$I_MB" \
  > "$I_K/_bmad-output/ai-dlc-update/self-update-gate-19700101T000000Z.md"
# ...and then the slice is written, exactly as step 2 writes it.
IG show "${I_T}:core/scripts/gate-changed.sh" > "$I_K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
ck "$I_D" "$I_B" "$I_T" "$I_K" probe >/dev/null 2>&1
rc=$?
LG21="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG21" ] && grep -qE "^GATE-RECORD: (OK|NOT-REQUIRED)" "$LG21" && ! grep -qF "GATE-RECORD: refusing" "$LG21"; then
  ok "a consumer whose pre-write copy was an INTERMEDIATE release's blob is accepted — the carried-content set is every blob the path held in the range, not the base blob alone"
else
  bad "a split-stamp consumer at an intermediate release's blob was refused (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG21" 2>/dev/null | cut -c1-150). That is the normal state after any self-update and one this cycle itself creates, so narrowing the accepted set to the base blob wedges those consumers"
fi

# --- Part G22: a base gate that DECLARES the record directory and never writes ----------------
# ARM 4's token has to spell the WRITE, not an assignment. Keyed on `GATE_REC_DIR` it scores 1
# on a locally patched old gate that declares the variable and never writes — converting a local
# edit into a refusal whose message says the records were deleted. The composed filename cannot
# be present without the write.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
ck "$DIST" "$D_BASE_DECL" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG22="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG22" ] && grep -qF "GATE-RECORD: NOT-REQUIRED" "$LG22"; then
  ok "a base gate that DECLARES the record directory and never writes is read as non-recording — the token spells the write site, not an assignment"
else
  bad "a gate declaring GATE_REC_DIR without writing was read as a recording gate (rc=$rc), so an empty directory becomes a refusal saying the records were deleted. A local edit that adds the variable then wedges the consumer with a message about a state that never happened"
fi

# --- Part G23: a RECORDING gate whose write site was reflowed is still read as recording -------
# The mirror of G22. G22 guards against a token that OVER-fires (an assignment read as a write);
# this guards against one that UNDER-fires, and under-firing here is the acquittal: the records
# deleted on such a consumer would otherwise reach NOT-REQUIRED and waive the requirement.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
ck "$DIST" "$D_BASE_REFLOW" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG23="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG23" ] && grep -qF "GATE-RECORD: MISSING" "$LG23" \
   && ! grep -qF "NOT-REQUIRED" "$LG23"; then
  ok "a base gate that RECORDS through a reflowed write site is still read as recording, so deleted records are refused as MISSING — the token spells the composed filename, which no reflow removes"
else
  bad "a recording gate whose write site was reflowed was read as NON-recording (rc=$rc), so an operator who deleted the records reached NOT-REQUIRED and the whole requirement was waived. The probe token is keyed on one author's exact spelling of the write, and the acquitting direction is the one that must not fail"
fi

# --- Parts G12 and G13: the DELIVERY-PULL tolerance, and the state it must NOT cover -----------
# A fix to a bootstrapping step can never be delivered by that step. On the pull that DELIVERS
# this requirement the OLD gate runs and records nothing, the slice installs this runner, and a
# hard refusal blocks the self-update carrying the fixed gate — with step 2 requiring green
# before the push, that pull can never land. Measured on the reference consumer: 69 of 87
# self-update commits wrote some `reconcile/` file and 3 wrote this runner, against a control of
# 0 of 87 for an impossible path.
#
# THE EXEMPTION IS KEYED ON THE GATE THE CONSUMER HAD, READ FROM THE DISTRIBUTION AT BASE — not
# on the record directory being empty, which `rm -f` reaches at will. G13 is the probe that it
# does not cover the arm's own subject.

# --- Part G12: no record, and the gate at BASE could not have recorded -------------------------
# `$D_BASE`'s gate carries no record-writing site, so this is the delivery pull.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
ERRG12="$GCONS/err-g12.txt"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG12"
rc=$?
LG12="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG12" ] && grep -qF "GATE-RECORD: NOT-REQUIRED" "$LG12" \
   && grep -qE "^GATE-RECORD: (OK|NOT-REQUIRED)" "$LG12"; then
  ok "no record, and the gate at BASE carries no record-writing site: the run proceeds with NOT-REQUIRED — the pull that delivers recording can still land"
else
  bad "a consumer whose installed gate could not have recorded was refused (rc=$rc). The old gate writes no record, so this is the state of the very pull that installs the recording one; refusing it means the fix can never be delivered by the step that delivers it"
fi
if grep -qF "NOT-REQUIRED" "$ERRG12"; then
  ok "the tolerance is announced on stderr too, so a green run does not silently omit the check"
else
  bad "the run proceeded on the tolerance and said so only in the log. A skipped requirement that reports nothing to the operator's channel reads exactly like one that passed"
fi

# --- Part G13a: records DELETED, with a RECORDING gate at base, still refuses ------------------
# The input an emptiness test cannot see, and the one the adversary reached with `rm -f`. Same
# empty directory as Part G12; the only thing different is which gate the consumer had, which is
# read out of the distribution where a deletion on the consumer cannot touch it.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
ck "$DIST" "$D_BASE_REC" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG13A="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG13A" ] && grep -qF "GATE-RECORD: MISSING" "$LG13A" \
   && ! grep -qF "NOT-REQUIRED" "$LG13A"; then
  ok "an EMPTY record directory with a RECORDING gate at base is refused as MISSING — the tolerance reads which gate the consumer had, not whether the directory happens to be empty"
else
  bad "deleting the records reached the tolerance (rc=$rc). \`rm -f self-update-gate-*.md\` is then the whole bypass, and the requirement is advisory for anyone willing to run it"
fi

# --- Part G13b: ONE record, for a DIFFERENT range, still refuses ------------------------------
# A consumer that HAS recorded a verdict, just not for this range. That is the ordinary
# post-first-cycle state, and an exemption widened to "no record for THIS range" acquits all of them.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 260 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G13b's wrong-range record"
ck "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG13="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG13" ] && grep -qF "GATE-RECORD:" "$LG13" \
   && ! grep -qF "NOT-REQUIRED" "$LG13"; then
  ok "with ONE record present, for a DIFFERENT range, the requirement still binds — the tolerance covers a consumer whose gate could not record, not a range that has not been classified"
else
  bad "a consumer holding a record for another range was let through on the delivery-pull tolerance (rc=$rc). That is the ordinary state after the first cycle, so this widening acquits every subsequent self-update and the exemption defends the defect the arm exists for"
fi

# --- PARTS J1 to J14: EVERY VERDICT THE GATE CAN WRITE MUST HAVE A SKILL BULLET CLAIMING ----
# ---                  THE RECORD IT WROTE                                                 ----
#
# THE DEFECT. `self-update-gate.sh` writes `_bmad-output/ai-dlc-update/self-update-gate-<ts>.md`
# on EVERY verdict -- `gate_record_open()` is guarded by `AI_DLC_GATE_IN_SAFE_STOP` and by
# nothing else, never by the verdict -- and step 2's only instruction naming that record used to
# sit on the OK path, where it names the record and the fixture log as a PAIR and sends both to a
# self-update commit the DEFER path never creates. So the DEFER and UNDECIDED paths wrote an
# approval record no step claimed. Filed by the reference consumer as
# PC-S345, and the operator had been committing that record by hand on the step-7 reconcile.
#
# BOTH SIDES ARE DERIVED, WHICH IS WHAT MAKES THIS AN OBSERVATION RATHER THAN A RESTATEMENT OF
# THE RECEIPT THAT SHIPPED WITH IT. Side A is the gate's own `_rec_v=` assignments; side B is the
# region of `SKILL.md` belonging to each verdict's disposition bullet. Neither is hand-listed, so
# a fourth verdict added to the gate with no bullet fires this arm on its own.
#
# THE SPAN GRAMMAR WAS CHOSEN BY MEASUREMENT AND THE OBVIOUS ONE IS WRONG. A region running to
# the next SIBLING bullet (`^   - `) scores the OK path at ZERO on the fixed tree as well as the
# broken one: the OK bullet is a ONE-LINE bullet and the passage naming the record sits thirty
# lines below it, inside the CARRY bullet's span under that grammar. An arm keyed on it would
# fail the push on a correct tree. Measured at both revisions, per bullet. The grammar that
# discriminates runs each region to the next DISPOSITION bullet (`^   - On \`SELF-UPDATE-`), else
# to the end of the numbered step: base scores 1 of 3 verdicts claimed, the fix scores 3 of 3.
#
# ONE BULLET COVERS TWO VERDICTS, so the join is over VERDICTS and never over bullet COUNT. The
# DEFER bullet opens `On \`SELF-UPDATE-DEFER\` or \`SELF-UPDATE-UNDECIDED\``; a count comparison
# reads three bullets against three verdicts and passes vacuously on a tree where the UNDECIDED
# path is claimed by nothing.
#
# THE REGION IS READ WITH FENCED BLOCKS AND HTML COMMENTS BLANKED, AND THE COMMIT-VERB SCAN IS
# READ WITH INLINE CODE SPANS REMOVED ON TOP OF THAT. A comment is not an instruction and a
# fenced example is not one either. The code-span strip is the narrowing
# that took this arm's false-positive set to zero: `skill_commit` and `version`/`commit` are
# FIELD NAMES, the DEFER bullet at base carries `skill_commit` and nothing else, and without the
# strip the unfixed tree scores its DEFER region as claimed. The record TOKEN is counted BEFORE
# the strip, because the record's path is itself written inside a code span.
#
# THE NEGATION SCAN IS READ WITH THE DISCLAIMER CLAUSE EXCISED, and that subtlety is the one a
# naive scan gets backwards: the correct fix's own disclaimer says `nothing in \`reconcile/\`
# stages or commits anything`, so a scan that discards any line carrying a negation discards the
# fix. The exclusion is anchored on the negation reaching a commit verb within one sentence.
#
# THE FALSE-REJECT SET WAS MEASURED, NOT ASSUMED. Four competent alternate phrasings of the same
# correct fix, written without reference to this predicate, all score CLAIMED. A
# receipt that rejects a competent author's other wording is as broken as one that accepts a
# regression, and the receipt this arm was built beside rejected 3 of 6.
#
# THE SUBJECT CAN BE ABSENT ON A CONSUMER AND THAT MUST NOT READ AS A PASS. This fixture SHIPS,
# a core fixture arrives one pull ahead of the code it guards, and a shipping arm whose subject
# is missing stands down -- which scores as a green unit in the consumer's own suite verdict.
# So the resolve is the same dual-layout `pick()` this file already uses for the runner, both
# candidates named side by side and never a walk up from a resolved path (I33) nor a walk for
# VERSION (I106), and a missing subject prints a SKIP line that is not an `ok`.
J_SKILL="$(pick "$HERE/../../skills/ai-dlc-update/SKILL.md" \
                "$HERE/../../../core/skills/ai-dlc-update/SKILL.md" \
                "$HERE/../../../.claude/skills/ai-dlc-update/SKILL.md")"
J_GATE="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/self-update-gate.sh" \
               "$HERE/../../../core/skills/ai-dlc-update/reconcile/self-update-gate.sh" \
               "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/self-update-gate.sh")"

JW="$(mktemp -d)"
sufl_tmp "$JW"

# The reader, in one place so the probe and the corpus score under the
# identical grammar. It prints one line per verdict the gate can write whose SKILL.md region
# does NOT claim the record, and nothing at all when every verdict is claimed.
j_unclaimed() { # $1=a SKILL.md  $2=a gate script -> one unclaimed verdict per line
  j_s="$JW/stripped.$$"
  # Fenced blocks and HTML comments blanked, LINE NUMBERING PRESERVED -- deleting the lines
  # instead would shift every region boundary below a fence and the offsets would be about a
  # file nobody reads.
  awk '
    /^```/ { fence = !fence; print ""; next }
    fence  { print ""; next }
    /<!--/ { incom = 1 }
    incom  { if (index($0, "-->")) incom = 0; print ""; next }
    { print }
  ' "$1" > "$j_s"
  j_verdicts="$(grep -oE '_rec_v=[A-Za-z][A-Za-z0-9_-]*' "$2" | sed 's/.*=//' | sort -u)"
  j_disp="$(grep -nE '^   - On `SELF-UPDATE-' "$j_s" | cut -d: -f1)"
  j_first="$(printf '%s\n' "$j_disp" | head -1)"
  j_end="$(grep -nE '^[0-9]+\. ' "$j_s" | awk -F: -v f="$j_first" '$1 > f { print $1 - 1; exit }')"
  [ -n "$j_end" ] || j_end="$(wc -l < "$j_s")"
  for j_v in $j_verdicts; do
    j_bl="$(grep -nE "^   - On \`SELF-UPDATE-${j_v}\`|^   - On \`SELF-UPDATE-[A-Z-]+\`( or \`SELF-UPDATE-[A-Z-]+\`)* or \`SELF-UPDATE-${j_v}\`" \
            "$j_s" | head -1 | cut -d: -f1)"
    [ -n "$j_bl" ] || { printf '%s\n' "$j_v"; continue; }
    j_re="$(printf '%s\n' "$j_disp" | awk -v b="$j_bl" '$1 > b { print $1 - 1; exit }')"
    [ -n "$j_re" ] || j_re="$j_end"
    j_reg="$(sed -n "${j_bl},${j_re}p" "$j_s")"
    j_rec="$(printf '%s\n' "$j_reg" | grep -cF 'self-update-gate-')" || j_rec=0
    j_pos="$(printf '%s\n' "$j_reg" | sed 's/`[^`]*`/@/g' | grep -E 'commit(s|ted|ting)?' \
             | grep -cviE '(do not|never|nothing[^.]*)[^.]*commit')" || j_pos=0
    { [ "$j_rec" -gt 0 ] && [ "$j_pos" -gt 0 ]; } || printf '%s\n' "$j_v"
  done
  rm -f "$j_s"
}
j_flat() { j_unclaimed "$1" "$2" | sort | tr '\n' ',' ; }

if [ -z "$J_SKILL" ] || [ -z "$J_GATE" ]; then
  # DISTINGUISHABLE, AND DELIBERATELY NOT AN `ok`. This is the mid-pull state: the fixture has
  # landed and its subject has not. `bad` would wedge the consumer's push on a state the pull
  # itself creates; silence would let a unit that checked nothing count toward a green suite.
  printf '  SKIP  the verdict/record join: no ai-dlc-update %s resolves from %s in either layout, so this fixture landed ahead of its subject and asserted nothing here\n' \
    "$([ -z "$J_SKILL" ] && printf 'SKILL.md' || printf 'reconcile/self-update-gate.sh')" "$HERE"
else
  # --- J1 and J2: THE SELF-PROBE, BOTH DIRECTIONS, UNDER mktemp AND BEFORE THE CORPUS --------
  # An arm reporting zero findings without first proving it can produce one has established that
  # it ran. The offender is a tree whose DEFER region names no record; the near-miss is the same
  # tree with a correct fix written in a phrasing this predicate was not built around.
  J_OFF="$JW/probe-offender.md"
  awk '!/^     \*\*The gate wrote `_bmad-output/ &&
       !/^     Carry that record to the step-7 gated apply/ &&
       !/^     \*\*That is an instruction to the operating agent/ &&
       !/^     `reconcile\/` stages or commits anything/ &&
       !/^     agent put it there\.$/' "$J_SKILL" > "$J_OFF"
  J_NEAR="$JW/probe-near-miss.md"
  awk '{ print }
       /^     runs and the flag is what tells them apart/ {
         print "     The gate already wrote `_bmad-output/ai-dlc-update/self-update-gate-<ts>.md` for this"
         print "     verdict; include it in the step-7 gated apply commit alongside the machinery slice." }' \
    "$J_OFF" > "$J_NEAR"
  j_off_flat="$(j_flat "$J_OFF" "$J_GATE")"
  j_near_flat="$(j_flat "$J_NEAR" "$J_GATE")"
  # The offender must have been CONSTRUCTIBLE. A probe built by a pattern that matched nothing is
  # byte-identical to the subject, and an arm that then reports nothing reads exactly like one
  # that discriminates.
  if cmp -s "$J_SKILL" "$J_OFF" || cmp -s "$J_OFF" "$J_NEAR"; then
    bad "FIXTURE ERROR: the J probe trees did not build (offender identical to the subject, or the near-miss identical to the offender). Neither direction of this reader was proven this run, so its verdict on the real corpus says only that it ran"
  elif [ -n "$j_off_flat" ] && [ -z "$j_near_flat" ]; then
    ok "the verdict/record reader REPORTS a seeded offender (a DEFER region naming no record: ${j_off_flat}) and stays QUIET on a seeded near-miss written in a phrasing it was not built around — both directions, on trees under mktemp and never the real corpus"
  else
    bad "the verdict/record reader did not discriminate on its own probe trees (offender read '${j_off_flat:-empty}' and must be non-empty; near-miss read '${j_near_flat:-empty}' and must be empty). An empty offender reading is a reader that cannot spell its own subject; a non-empty near-miss reading is one that rejects a correct fix, which is the defect one row above this one in the same worklist"
  fi

  # --- J3: THE INSTRUMENT ITSELF, before any verdict is read off it --------------------------
  # A derived population of zero on either side reports a clean join having joined nothing.
  j_na="$(grep -oE '_rec_v=[A-Za-z][A-Za-z0-9_-]*' "$J_GATE" | sed 's/.*=//' | sort -u | grep -c .)" || j_na=0
  j_nb="$(grep -cE '^   - On `SELF-UPDATE-' "$J_SKILL")" || j_nb=0
  j_ctl="$(grep -cF 'self-update-gate-ZZQX139' "$J_SKILL")" || j_ctl=0
  j_tok="$(grep -cF 'self-update-gate-' "$J_SKILL")" || j_tok=0
  if [ "$j_na" -ge 2 ] && [ "$j_nb" -ge 1 ] && [ "$j_ctl" -eq 0 ] && [ "$j_tok" -gt 0 ]; then
    ok "both sides of the join derive a non-empty population ($j_na gate verdicts, $j_nb disposition bullets) and the record token scores $j_tok against an impossible-token control of 0 in the same file"
  else
    bad "the join's own instrument is broken (gate verdicts $j_na expected >=2, disposition bullets $j_nb expected >=1, impossible-token control $j_ctl expected 0, record token $j_tok expected >0). A side that derives nothing reports every verdict claimed, or every verdict unclaimed, for a reason that is not about the tree"
  fi

  # --- J4: THE CORPUS ------------------------------------------------------------------------
  j_live="$(j_flat "$J_SKILL" "$J_GATE")"
  if [ -z "$j_live" ]; then
    ok "every verdict \`self-update-gate.sh\` can write has a step-2 disposition region instructing that the record it wrote be committed — the gate records on every verdict, so a verdict whose bullet names no record leaves an approval artifact no step claims"
  else
    bad "these verdicts the gate CAN write have no disposition region instructing that the record be committed: ${j_live}. \`gate_record_open()\` is guarded by AI_DLC_GATE_IN_SAFE_STOP and by nothing else, so the record exists on every one of them; the operator then either loses it or commits it by hand. Name the record ALONE in that verdict's bullet — not as the 'approval artifact', which SKILL.md defines as a PAIR — and name the step-7 gated apply as its destination, never the self-update commit, which the DEFER path never creates"
  fi

  # J12 and J13: TWO COMPETENT ALTERNATE PHRASINGS of the same correct fix, each in its own
  # copy and neither written from this predicate's accept-set. They must NOT fire. This is the
  # measured half of the false-positive set, and it is the half the receipt beside this arm got
  # wrong: it rejected 3 of 6 correct phrasings, which is BL-279's defect one row up.
  j_phrasing() { # $1=label $2=first line $3=second line
    j_p="$JW/m-phrase-$1.md"
    awk -v l1="$2" -v l2="$3" '{ print }
         /^     runs and the flag is what tells them apart/ { print l1; print l2 }' "$J_OFF" > "$j_p"
    if [ ! -s "$j_p" ] || cmp -s "$J_OFF" "$j_p"; then
      bad "PHRASING $1 DID NOT APPLY, so nothing was established about this arm's false-REJECT set"
      return
    fi
    j_pg="$(j_flat "$j_p" "$J_GATE")"
    if [ -z "$j_pg" ]; then
      ok "CONTROL $1 — a competent author's alternate phrasing of the SAME correct fix is ACCEPTED. An arm that rejects a correct fix wedges the work it exists to protect, and its false-REJECT set is the half that goes unmeasured"
    else
      bad "PHRASING $1 was REJECTED: the reader returned '${j_pg}' against a correctly-fixed region written in another wording. That is a false REJECT, and it is the defect filed one row above this one in the same worklist"
    fi
  }
  j_phrasing "J12" \
    "     Include \`_bmad-output/ai-dlc-update/self-update-gate-<ts>.md\`, which the gate wrote here," \
    "     in the commit the step-7 gated apply makes."
  j_phrasing "J13" \
    "     A record exists at \`_bmad-output/ai-dlc-update/self-update-gate-<ts>.md\` even on this path," \
    "     and the operating agent commits it with the step-7 gated apply."

  # J14: THE UNMUTATED CONTROL, PRESENCE-SHAPED AND RUN LAST. Every arm above is
  # presence-shaped, so a reader replaced by `exit 0` fails them by construction -- but the
  # control still has to assert a positive: that the reader names the verdicts it was given and
  # not a fixed string. It is scored on the OFFENDER, where the answer is non-empty, because on
  # the real tree an empty answer is indistinguishable from a reader that returns nothing ever.
  j_ctl_off="$(j_unclaimed "$J_OFF" "$J_GATE" | sort | tr '\n' ' ')"
  case "$j_ctl_off" in
    *DEFER*UNDECIDED*)
      ok "CONTROL — the reader names the specific verdicts it found unclaimed ($j_ctl_off) rather than emitting a fixed string, so the reader is shown to answer from its input" ;;
    *)
      bad "CONTROL — the reader did not name DEFER and UNDECIDED on the offender tree (got '${j_ctl_off:-empty}'). A reader whose output does not depend on its input proves nothing about any verdict above" ;;
  esac
fi

# --- Parts W1-W9: STEP 2's FIXTURE-WRITE RULE, ORDER AND RED-PUSH DISPOSITION, IN THE SHIPPED SKILL.md ----
# No program reads this prose, so the observable is the declared text, whitespace-collapsed (a
# wrapped line cannot hide a phrase):
#   W1 a fixture directory is ONE unit -- and the sentence sits INSIDE the fixture-write rule, between
#      "A derived fixture is a consumer edit when" and "DO NOT DERIVE THE VERDICT BY COMPARING REFS"
#   W2 the gate-set disagreement stop is scoped to MACHINERY paths, fixture paths named outside it
#   W3 the RED-PUSH paragraph: a red push leaves an unpushed local commit, recoverable, and a
#      GATE-RECORD-REFUSED exit takes the HOOK-REFUSED sequence and disposition
#   W4 the REQUIRED pre-commit fixture run is GONE ("require green BEFORE the commit" absent) and the
#      text says there is no separate covering-fixture run before the commit (BL-713)
#   W5 every OLD order ("GATE, THEN WRITE, THEN RUNNER") is ABSENT and the new one,
#      "GATE, THEN WRITE, THEN COMMIT, THEN PUSH", is present
#   W6 the HARD-STOPS clause is ABSENT and that sentence says DEFERS
#   W8 a file with NO preclassify row is a consumer edit when it differs from the base AND skill_commit blobs or
#      was added by the consumer, and holds its directory back (BL-907 subject 2, the rule)
#   W9 the UNDIFFED-OVERWRITE remedy: restore from HEAD^, git rm the added files, amend, re-run the wrapper
#      with a NEW <out> -- all four parts, in order, after the W8 rule (BL-907 subject 2, the remedy)
#   W7 the W phrases are not ONLY inside an HTML comment (the text read is the file with every
#      `<!-- ... -->` span deleted first, so W1-W6 are scored on what an agent actually reads)
# W4, W5 and W6 are absence-shaped, so each sits beside a presence conjunct that only the fixed text
# carries. A consumer whose installed SKILL.md predates the gate-write-
# commit-push order SKIPs the block (the fixture can land one pull ahead of its prose); the
# distribution never does.
w_flat() {
  tr '\n' ' ' < "$1" | tr -s ' \t' '  ' | LC_ALL=C awk '
  { s = $0
    while ((i = index(s, "<!--")) > 0) {
      r = substr(s, i + 4); j = index(r, "-->")
      if (j == 0) { s = substr(s, 1, i - 1); break }
      s = substr(s, 1, i - 1) substr(r, j + 3)
    }
    print s }'
}
wsig() { # <skill.md> -> nine cells
  local t w1=0 w2=0 w3=0 w4=0 w5=0 w6=0 w7=0 w8=0 w9=0
  t="$(w_flat "$1")"
  case "$t" in *"A derived fixture is a consumer edit when"*"A FIXTURE DIRECTORY IS ONE UNIT: if ANY path under a derived fixture directory is held back as a consumer edit, write NONE of that directory and carry ALL of it"*"DO NOT DERIVE THE VERDICT BY COMPARING REFS"*) w1=1 ;; esac
  case "$t" in *"if its set and yours disagree on a machinery path, stop"*"A fixture path is outside that comparison by construction"*) w2=1 ;; esac
  case "$t" in *"A RED PUSH LEAVES AN UNPUSHED LOCAL COMMIT, AND THAT IS RECOVERABLE."*"\`GATE-RECORD-REFUSED\` exit 2"*"takes the HOOK-REFUSED paragraph's sequence and disposition exactly, \`SELF-UPDATE-DEFER\`"*) w3=1 ;; esac
  case "$t" in *"require green BEFORE the commit"*) ;; *"There is no separate covering-fixture run before the commit."*) w4=1 ;; esac
  case "$t" in *"THE ORDER IS GATE, THEN WRITE, THEN RUNNER"*) ;; *"THE ORDER IS GATE, THEN WRITE, THEN COMMIT, THEN PUSH, AND THE GATE RUNS ONCE"*) w5=1 ;; esac
  case "$t" in *"HARD-STOPS"*) ;; *"a red derived fixture DEFERS the cycle"*) w6=1 ;; esac
  case "$(tr '\n' ' ' < "$1" | tr -s ' \t' '  ')" in *"A FIXTURE DIRECTORY IS ONE UNIT"*) [ "$w1" = 1 ] && w7=1 ;; esac
  # W8 the consumer-edit rule for a file with no preclassify row, ordered before its ONE-UNIT consequence (BL-907)
  case "$t" in *'In a directory written whole, a file with NO `preclassify.sh` row'*'is a consumer edit when its consumer copy differs from the distribution blob at `base` AND at the stamp'*'or when the consumer added it (absent upstream at both refs)'*'holds its whole directory back under the ONE-UNIT rule below'*) w8=1 ;; esac
  # W9 the UNDIFFED-OVERWRITE remedy, its four parts in order, after the W8 rule: restore from HEAD^, git rm the
  # added files, amend, re-run the wrapper with a NEW <out>
  case "$t" in *'In a directory written whole, a file with NO `preclassify.sh` row'*'An `UNDIFFED-OVERWRITE` refusal has a sanctioned remedy that lands the cycle'*'restore it from the parent commit with `git checkout HEAD^ -- <dir>`'*'`git rm` any file the commit added under it'*'run `git commit --amend --no-edit`'*'re-run the push wrapper with a NEW `<out>` path'*) w9=1 ;; esac
  printf '%s-%s-%s-%s-%s-%s-%s-%s-%s' "$w1" "$w2" "$w3" "$w4" "$w5" "$w6" "$w7" "$w8" "$w9"
}
W_OK="1-1-1-1-1-1-1-1-1"
W_SKILL="$(pick "$HERE/../../skills/ai-dlc-update/SKILL.md" \
                "$HERE/../../../core/skills/ai-dlc-update/SKILL.md" \
                "$HERE/../../../.claude/skills/ai-dlc-update/SKILL.md")"
W_DIST=0; [ "$W_SKILL" = "$HERE/../../skills/ai-dlc-update/SKILL.md" ] && W_DIST=1
if [ -z "$W_SKILL" ]; then
  # The J arms' convention: the fixture has landed and its subject has not. Never an `ok`.
  echo "  SKIP  Parts W1-W9 -- ai-dlc-update/SKILL.md resolves in neither layout from $HERE, so these assert nothing here"
else
  w_got="$(wsig "$W_SKILL")"
  if [ "$w_got" = "$W_OK" ]; then
    ok "Parts W1-W9: the shipped SKILL.md carries a fixture directory as one unit inside the fixture-write rule, scopes the gate-set stop to machinery, spells the RED-PUSH paragraph, requires no pre-commit fixture run, orders gate-write-commit-push, and keeps the HARD-STOPS clause out"
  elif [ "$W_DIST" = 0 ] && { [ "$w_got" = "1-1-0-0-0-1-1-0-0" ] || [ "$w_got" = "0-0-0-0-0-0-0-0-0" ] || [ "$w_got" = "1-1-1-1-1-1-1-0-0" ]; }; then
    echo "  SKIP  Parts W1-W9 -- the installed SKILL.md predates the gate-write-commit-push order ($w_got); they land with the pull that carries it"
  else
    bad "Parts W1-W9: vector $w_got, want $W_OK (cells: W1 dir-is-a-unit in place, W2 disagree-scoped, W3 red-push paragraph, W4 no pre-commit run, W5 old order gone, W6 HARD-STOPS gone, W7 not comment-only, W8 undiffed-file consumer-edit rule, W9 UNDIFFED-OVERWRITE remedy with its four parts)"
  fi
fi

# --- Part BH: GIVEN FIXTURE NAMES, THE CHECKER RUNS NO FIXTURE (BL-713) ----------------------------
# The behavioural half of BL-713's receipt. The receipt keys on SKILL.md's wording, which a reword
# could close; this arm keys on what the program DOES. A consumer is seeded with a hook that carries
# the hermetic dispatch, a declared fixture, and a `scripts/ai-dlc/hermetic-run.sh` SHIM that appends
# one line to a sentinel per invocation and exits 0 — the state in which the deleted runner chose
# the hermetic dispatch and ran the fixture through it. The checker is then handed that fixture's
# name. It must refuse (exit 2) and the sentinel must count 0.
#   BH-ctl   the same checker with its four arguments only reaches a verdict (exit 0, NOT-REQUIRED)
#            and still counts 0 -- so the refusal above is about the extra argument
BH_C="$(mktemp -d)"; sufl_tmp "$BH_C"
BH_S="$BH_C/.bh-sentinel"
mkdir -p "$BH_C/.githooks" "$BH_C/scripts/ai-dlc" "$BH_C/tests/fixtures/bh-fx"
printf '# READSET_TOOLS_BEGIN\n    if [ -f "$d/inputs.decl" ]; then\n' > "$BH_C/.githooks/pre-push"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\nexit 0\n' "$BH_S" > "$BH_C/scripts/ai-dlc/hermetic-run.sh"
printf 'exit 0\n' > "$BH_C/tests/fixtures/bh-fx/run.sh"
printf 'tests/fixtures/bh-fx/run.sh\n' > "$BH_C/tests/fixtures/bh-fx/inputs.decl"
chmod +x "$BH_C/.githooks/pre-push" "$BH_C/scripts/ai-dlc/hermetic-run.sh" "$BH_C/tests/fixtures/bh-fx/run.sh"
bh_n() { local n; n="$(grep -c . "$BH_S" 2>/dev/null)" || n=0; printf '%s' "$n"; }
bh_run() { # bh_run <checker> [names...] -> "rc=<n> runs=<n>"
  local c="$1" rc=0; shift
  rm -f "$BH_S"
  suf_run "$DIST" "$D_BASE" "$D_THEIRS" "$BH_C" "$@" > "$BH_C.out" 2>&1 || rc=$?
  printf 'rc=%s runs=%s' "$rc" "$(bh_n)"
}
bh_got="$(bh_run "$RUNNER" bh-fx)"
if [ "$bh_got" = "rc=2 runs=0" ] && grep -qF 'runs NO fixture' "$BH_C.out"; then
  ok "Part BH: handed a fixture name on a consumer whose hook dispatches it to hermetic-run.sh, the checker REFUSES (exit 2) and makes 0 hermetic-run invocations"
else
  bad "Part BH: handed a fixture name, the checker read '$bh_got', want 'rc=2 runs=0' with its refusal line. The pre-commit covering run BL-713 removed is back"
fi
bh_got="$(bh_run "$RUNNER")"
if [ "$bh_got" = "rc=0 runs=0" ] && grep -qF 'GATE-RECORD: NOT-REQUIRED' "$BH_C.out"; then
  ok "Part BH-ctl: the same checker with its four arguments reaches the gate-record verdict (NOT-REQUIRED) and still makes 0 invocations"
else
  bad "Part BH-ctl: four arguments read '$bh_got', want 'rc=0 runs=0' and a NOT-REQUIRED line"
fi

# --- Parts D9 and D12: THE SELF-UPDATE COMMIT'S FIXTURE DIRECTORIES ---------------------------------
# Two duties the deleted runner carried by side effect, now asked of the commit itself, before the
# push. Each consumer is its own git repo with a self-update commit on top (`sc_consumer`), over the
# range `$D_BASE..$D_THEIRS`, with no record and a base gate that records nothing — so the gate-record
# arm takes NOT-REQUIRED and the slice check is the only thing that can refuse.
#   D9   the commit writes `named-distonly`, which carries `.dist-only` at theirs (preclassify's
#        DIST-ONLY-SKIP bucket)                                         -> refused, DIST-ONLY
#   D12  the commit writes `green-one/` holding only an inputs.decl  -> refused, NO-DRIVER
#   ctl  the commit writes `green-one/run.sh`, shippable at theirs     -> exit 0
sc_run() { # sc_run <consumer> -> "rc=<n>"; output in <consumer>.out
  local rc=0
  suf_run "$DIST" "$D_BASE" "$D_THEIRS" "$1" > "$1.out" 2>&1 || rc=$?
  printf 'rc=%s' "$rc"
}
SC9="$(mktemp -d)"; sufl_tmp "$SC9"; SC12="$(mktemp -d)"; sufl_tmp "$SC12"; SCC="$(mktemp -d)"; sufl_tmp "$SCC"
if sc_consumer "$SC9/c" tests/fixtures/named-distonly/run.sh \
   && sc_consumer "$SC12/c" tests/fixtures/green-one/inputs.decl \
   && sc_consumer "$SCC/c" tests/fixtures/green-one/run.sh; then
  sc_got="$(sc_run "$SC9/c")"
  if [ "$sc_got" = rc=2 ] && grep -q '^GATE-RECORD: SLICE named-distonly — DIST-ONLY' "$SC9/c.out"; then
    ok "Part D9: a self-update commit that wrote a fixture directory carrying .dist-only at theirs is refused before the push"
  else
    bad "Part D9: a commit writing a .dist-only fixture directory read '$sc_got' without a SLICE DIST-ONLY line. The DIST-ONLY-SKIP subtraction is unenforced and the RETIRED-FIXTURE-ORPHAN reaches the consumer"
  fi
  sc_got="$(sc_run "$SC12/c")"
  if [ "$sc_got" = rc=2 ] && grep -q '^GATE-RECORD: SLICE green-one — NO-DRIVER' "$SC12/c.out"; then
    ok "Part D12: a self-update commit that wrote a fixture directory with no run.sh is refused before the push"
  else
    bad "Part D12: a commit writing a driverless fixture directory read '$sc_got' without a SLICE NO-DRIVER line"
  fi
  sc_got="$(sc_run "$SCC/c")"
  if [ "$sc_got" = rc=0 ] && ! grep -q '^GATE-RECORD: SLICE' "$SCC/c.out"; then
    ok "Part D9/D12 control: a self-update commit that wrote a complete, shippable fixture directory is accepted"
  else
    bad "Part D9/D12 control: a complete shippable directory read '$sc_got' — the slice check refuses correct slices"
  fi
else
  bad "FIXTURE ERROR: the D9/D12 consumers did not build, so neither slice duty was asserted"
fi

# --- Parts D12x, D12s-lib, D12s-seed, D12u: WHICH driverless directory the slice may write ------------
# A directory the self-update commit holds with no run.sh is asked at THEIRS. Upstream ships it with
# no run.sh (the shared `lib/`, a seed-only directory): a SUPPORT directory, accepted. Upstream ships
# a run.sh for it: NO-DRIVER (D12 above). Upstream does not ship it at all: NO-DRIVER. A read that
# answers neither present nor confirmed absent: UNCONFIRMED.
#   D12x       the commit writes `absent-at-theirs/README.md` alone              -> rc 2, ONE SLICE line, NO-DRIVER
#   D12s-lib   the commit writes `lib/inproc.sh` AND `absent-at-theirs/README.md` -> rc 2, ONE SLICE line naming
#              the absent directory and none naming lib
#   D12s-seed  the same with the seed-only `theirs-only-nodriver/seed.sh` in place of lib
#   D12u       the commit writes `unreadable-driver/README.md`, judged against a COPY of the distribution
#              whose `unreadable-driver/run.sh` BLOB is removed, so the run.sh read at theirs answers
#              neither 0 nor a confirmed 128                                     -> rc 2, ONE SLICE line, UNCONFIRMED
#   D12d       the commit writes `flat-entry/README.md`, judged against the same COPY, where `flat-entry` is
#              a BLOB whose object is removed: the `.dist-only` and run.sh reads confirm an absence and the
#              directory read answers neither 0 nor 128            -> rc 2, ONE SLICE line, UNCONFIRMED: its directory
# THE ACCEPT CELLS ARE COMBINED WORLDS ON PURPOSE. A world writing only a support directory exits 0
# with no SLICE line, which is also what a checker that never reached the loop prints; beside a
# directory the loop MUST refuse, exactly one SLICE line proves the loop ran and passed over lib.
# Every cell also requires the NOT-REQUIRED line, so a copy that died before the gate-record arm
# reads as broken.
SCX="$(mktemp -d)"; sufl_tmp "$SCX"
D12_ABS=absent-at-theirs
DIST_U="$(mktemp -d)"; sufl_tmp "$DIST_U"
d12_built=0
if sc_consumer "$SCX/x" "tests/fixtures/$D12_ABS/README.md" \
   && sc_consumer "$SCX/slib" tests/fixtures/lib/inproc.sh "tests/fixtures/$D12_ABS/README.md" \
   && sc_consumer "$SCX/sseed" tests/fixtures/theirs-only-nodriver/seed.sh "tests/fixtures/$D12_ABS/README.md" \
   && sc_consumer "$SCX/u" tests/fixtures/unreadable-driver/README.md \
   && sc_consumer "$SCX/d" tests/fixtures/flat-entry/README.md \
   && cp -R "$DIST/." "$DIST_U/"; then
  d12_built=1
  for d12_p in core/fixtures/unreadable-driver/run.sh core/fixtures/flat-entry; do
    d12_t="$(git -C "$DIST_U" rev-parse -q --verify "${D_THEIRS}:${d12_p}" 2>/dev/null)" || d12_t=""
    d12_o="$DIST_U/.git/objects/${d12_t:0:2}/${d12_t:2}"
    if [ -n "$d12_t" ] && [ -f "$d12_o" ] && rm -f "$d12_o" \
       && ! git -C "$DIST_U" cat-file -e "$d12_t" 2>/dev/null && git -C "$DIST" cat-file -e "$d12_t" 2>/dev/null; then :
    else d12_built=0; fi
  done
fi
[ "$d12_built" = 1 ] || bad "FIXTURE ERROR: the D12x/D12s/D12u/D12d worlds did not build (or the unreadable-driver or flat-entry blob was not a removable loose object), so no support-directory cell was asserted"
d12_cell() { # d12_cell <checker> <cell> -> 1 when the cell's assertion holds, 0 when not, X when the checker did not reach its gate-record arm
  local r="$1" c="$2" dist="$DIST" cons rc=0 o n
  case "$c" in
    D12) cons="$SC12/c" ;;
    D12x) cons="$SCX/x" ;;
    D12s-lib) cons="$SCX/slib" ;;
    D12s-seed) cons="$SCX/sseed" ;;
    D12u) cons="$SCX/u"; dist="$DIST_U" ;;
    D12d) cons="$SCX/d"; dist="$DIST_U" ;;
    *) printf X; return ;;
  esac
  o="$SCX/$c.$(basename "$(dirname "$(dirname "$r")")").out"
  suf_run "$dist" "$D_BASE" "$D_THEIRS" "$cons" > "$o" 2>&1 || rc=$?
  grep -q '^GATE-RECORD: NOT-REQUIRED' "$o" || { printf X; return; }
  n="$(grep -c '^GATE-RECORD: SLICE' "$o")" || n=0
  case "$c" in
    D12) [ "$rc" = 2 ] && grep -q '^GATE-RECORD: SLICE green-one — NO-DRIVER' "$o" ;;
    D12x) [ "$rc" = 2 ] && [ "$n" = 1 ] && grep -q "^GATE-RECORD: SLICE $D12_ABS — NO-DRIVER" "$o" ;;
    D12s-lib) [ "$rc" = 2 ] && [ "$n" = 1 ] && grep -q "^GATE-RECORD: SLICE $D12_ABS — NO-DRIVER" "$o" \
                && ! grep -q '^GATE-RECORD: SLICE lib ' "$o" ;;
    D12s-seed) [ "$rc" = 2 ] && [ "$n" = 1 ] && grep -q "^GATE-RECORD: SLICE $D12_ABS — NO-DRIVER" "$o" \
                 && ! grep -q '^GATE-RECORD: SLICE theirs-only-nodriver ' "$o" ;;
    D12u) [ "$rc" = 2 ] && [ "$n" = 1 ] && grep -q '^GATE-RECORD: SLICE unreadable-driver — UNCONFIRMED: its run.sh' "$o" ;;
    D12d) [ "$rc" = 2 ] && [ "$n" = 1 ] && grep -q '^GATE-RECORD: SLICE flat-entry — UNCONFIRMED: its directory' "$o" ;;
  esac && printf 1 || printf 0
}
if [ "$d12_built" = 1 ]; then
  if [ "$(d12_cell "$RUNNER" D12x)" = 1 ]; then ok "Part D12x: a self-update commit that wrote a driverless directory upstream does not ship is refused NO-DRIVER, one SLICE line"
  else bad "Part D12x: a driverless directory absent at theirs was not refused with exactly one SLICE NO-DRIVER line ($SCX/D12x.*.out)"; fi
  if [ "$(d12_cell "$RUNNER" D12s-lib)" = 1 ]; then ok "Part D12s-lib: the shared lib/ upstream ships with no run.sh is written whole and not refused; the absent directory beside it is the one SLICE line"
  else bad "Part D12s-lib: a commit writing lib/inproc.sh beside an absent directory did not give rc 2 with one SLICE line naming only the absent directory. The shared lib/ is treated as a fixture"; fi
  if [ "$(d12_cell "$RUNNER" D12s-seed)" = 1 ]; then ok "Part D12s-seed: a seed-only directory upstream ships with no run.sh is not refused; the absent directory beside it is the one SLICE line"
  else bad "Part D12s-seed: a commit writing a seed-only directory beside an absent directory did not give rc 2 with one SLICE line naming only the absent directory"; fi
  if [ "$(d12_cell "$RUNNER" D12u)" = 1 ]; then ok "Part D12u: a theirs read that can confirm neither presence nor absence is UNCONFIRMED, one SLICE line, never accepted"
  else bad "Part D12u: with the unreadable-driver run.sh blob unreadable at theirs the checker did not refuse it UNCONFIRMED with one SLICE line"; fi
  if [ "$(d12_cell "$RUNNER" D12d)" = 1 ]; then ok "Part D12d: a directory read at theirs that can confirm neither presence nor absence is UNCONFIRMED, one SLICE line, never accepted"
  else bad "Part D12d: with the flat-entry blob unreadable at theirs the checker did not refuse it UNCONFIRMED (its directory) with one SLICE line ($SCX/D12d.*.out)"; fi
fi


# --- Part D12p: STEP 2'S PUSH IS JUDGED BY THE CHECKER THE SLICE JUST WROTE ------------------------------
# Driven through the REAL reconcile/self-update-push.sh in a consumer that is its own repository with a
# bare origin and no pre-push hook. The consumer's installed reconcile directory is the shipped one; the
# self-update commit writes lib/inproc.sh and overwrites the checker with a copy carrying one stderr
# MARK line. The wrapper resolves its checker beside itself, so the push lands (rc 0) and the mark
# appears once.
#   D12p-mark    the written checker's mark is on the wrapper's stderr, exactly once
#   D12p-landed  rc 0 and origin's su is the local sha
PP="$(mktemp -d)"; sufl_tmp "$PP"
pp_build() { # pp_build <name> <push-wrapper-source> -> 0 when built
  local c="$PP/$1/c" r
  (
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    pg() { git -c init.templateDir= -c user.name=ai-dlc-fixture -c user.email=fixture@invalid -c commit.gpgsign=false "$@"; }
    pg init -q --bare "$PP/$1/o.git" && pg init -q "$c" || exit 1
    r="$c/.claude/skills/ai-dlc-update/reconcile"
    mkdir -p "$r" && cp -R "$RECONCILE/." "$r/" && printf 'base\n' > "$c/README" || exit 1
    pg -C "$c" add -A && pg -C "$c" commit -q --no-verify -m installed || exit 1
    pg -C "$c" remote add origin "$PP/$1/o.git" && pg -C "$c" checkout -q -b su || exit 1
    mkdir -p "$c/tests/fixtures/lib" && printf 'exit 0\n' > "$c/tests/fixtures/lib/inproc.sh" || exit 1
    { sed -n 1p "$RUNNER"; echo 'echo "CHECKER-MARK written-by-the-slice" >&2'; sed -n '2,$p' "$RUNNER"; } > "$r/self-update-fixtures.sh" || exit 1
    cp "$2" "$r/self-update-push.sh" || exit 1
    pg -C "$c" add -A && pg -C "$c" commit -q --no-verify -m self-update || exit 1
  ) >/dev/null 2>&1
}
pp_drive() { # pp_drive <name> -> "mark=<n> landed=<0|1> rc=<n>"
  local c="$PP/$1/c" rc=0 n l=0
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    cd / && bash "$c/.claude/skills/ai-dlc-update/reconcile/self-update-push.sh" "$c" origin su \
      _bmad-output/ai-dlc-update/self-update-push-pp.md "$DIST" "$D_BASE" "$D_THEIRS" ) > "$PP/$1.out" 2> "$PP/$1.err" || rc=$?
  n="$(grep -c '^CHECKER-MARK written-by-the-slice$' "$PP/$1.err")" || n=0
  [ "$(git --git-dir="$PP/$1/o.git" rev-parse -q --verify refs/heads/su 2>/dev/null)" = "$(git -C "$c" rev-parse -q --verify refs/heads/su 2>/dev/null)" ] \
    && [ -n "$(git -C "$c" rev-parse -q --verify refs/heads/su 2>/dev/null)" ] && l=1
  printf 'mark=%s landed=%s rc=%s' "$n" "$l" "$rc"
}
PP_PUSH="$RECONCILE/self-update-push.sh"
if [ -f "$PP_PUSH" ] && pp_build shipped "$PP_PUSH"; then
  pp_got="$(pp_drive shipped)"
  if [ "$pp_got" = "mark=1 landed=1 rc=0" ]; then
    ok "Part D12p: through the real self-update-push.sh, step 2's push is judged by the checker the self-update commit wrote (its mark appears once) and lands"
  else
    bad "Part D12p: the real push wrapper read '$pp_got', want 'mark=1 landed=1 rc=0' ($PP/shipped.err)"
  fi
else
  bad "FIXTURE ERROR: Part D12p's consumer did not build, or self-update-push.sh is not beside the checker ($PP_PUSH)"
fi

# --- Parts UD1-UD9: A WHOLE-DIRECTORY WRITE OVER A CONSUMER EDIT THE DIFF NEVER SAW --------------------
# Step 2 writes each covered directory WHOLE from theirs and asks preclassify's bucket whether a file is
# a consumer edit; a file upstream did not change has no bucket, so a consumer repair to it was
# overwritten silently (the reference consumer's `artifact-path-conformance/seed.sh`, kept by hand). Its
# own distribution, so no other part's range moves: `udx/seed.sh` is equal at base and theirs and holds a
# third content at the intermediate SK; `udx/run.sh` moves base -> theirs. Each consumer is its own repo
# whose installed commit carries a stamp naming its skill_commit, and whose self-update commit writes the
# directory whole from theirs and advances the stamp.
#   UD1  the consumer repaired seed.sh                          -> rc 2, ONE SLICE UNDIFFED-OVERWRITE naming seed.sh,
#                                                                  the remedy's supersession sentence on stderr
#   UD2  seed.sh equal to base, the write changes only its mode -> rc 0, no SLICE line
#   UD3  seed.sh equal to the skill_commit (SK) blob            -> rc 0, no SLICE line
#   UD4  the remedy through the real push wrapper: same <out> refuses `already exists`, a new <out> exits 0
#        with GATE-RECORD: OK and the push lands
#   UD5  UD1's consumer against a dist COPY whose base udx TREE is removed -> rc 2, UNCONFIRMED, no UNDIFFED line
#   UD6  the DEFER path: apply.sh --carried-machinery-slice over the pre-write tree leaves seed.sh's bytes and
#        writes run.sh at theirs
#   UD7  the consumer edited the DIFFED run.sh                  -> rc 0, no SLICE line (preclassify's question)
#   UD8  a consumer-added local.sh the write deleted            -> rc 2, ONE SLICE UNDIFFED-OVERWRITE naming local.sh
#   UD9  the write also adds `q"x.sh`, which git lists C-quoted  -> rc 2, ONE SLICE UNCONFIRMED naming the quoted line
# The seed control asserts every world's commit lists its subject file, so no silent cell is silent for
# want of being asked. UD2 needs a mode-only change for that: an equal-bytes write lists nothing.
UDW="$(mktemp -d)"; sufl_tmp "$UDW"
UDD="$UDW/dist"
udg() { ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
          export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
          git -c init.templateDir= -c user.name=ai-dlc-fixture -c user.email=fixture@invalid -c commit.gpgsign=false "$@" ) >/dev/null 2>&1; }
udput() { mkdir -p "$(dirname "$1/$2")" && printf '%s\n' "$3" > "$1/$2"; }
UD_SEED='udx seed, never changed upstream'
ud_built=1
{ udg init -q "$UDD" && udput "$UDD" core/fixtures/udx/run.sh 'udx run at base' && udput "$UDD" core/fixtures/udx/seed.sh "$UD_SEED" \
  && udg -C "$UDD" add -A && udg -C "$UDD" commit -q --no-verify -m base \
  && udput "$UDD" core/fixtures/udx/seed.sh 'udx seed at the skill_commit release' \
  && udg -C "$UDD" add -A && udg -C "$UDD" commit -q --no-verify -m sk \
  && udput "$UDD" core/fixtures/udx/seed.sh "$UD_SEED" && udput "$UDD" core/fixtures/udx/run.sh 'udx run at theirs' \
  && udg -C "$UDD" add -A && udg -C "$UDD" commit -q --no-verify -m theirs; } || ud_built=0
UD_B="$(git -C "$UDD" rev-parse -q --verify HEAD~2 2>/dev/null)" || UD_B=""
UD_SK="$(git -C "$UDD" rev-parse -q --verify HEAD~1 2>/dev/null)" || UD_SK=""
UD_T="$(git -C "$UDD" rev-parse -q --verify HEAD 2>/dev/null)" || UD_T=""
[ -n "$UD_B" ] && [ -n "$UD_SK" ] && [ -n "$UD_T" ] || ud_built=0
ud_world() { # ud_world <dir> <skill_commit> <seed-before> <run-before> <local-before|-> <write: 1 or 0> [chmod]
  local c="$1" fx="$1/tests/fixtures/udx"
  udg init -q "$c" || return 1
  printf 'base\n' > "$c/README" || return 1
  udput "$c" .claude/.ai-dlc-version "version: 1.0.0
commit: $UD_B
skill_commit: $2" && udput "$c" tests/fixtures/udx/seed.sh "$3" && udput "$c" tests/fixtures/udx/run.sh "$4" || return 1
  [ "$5" = - ] || udput "$c" tests/fixtures/udx/local.sh "$5" || return 1
  udg -C "$c" add -A && udg -C "$c" commit -q --no-verify -m installed || return 1
  [ "$6" = 1 ] || return 0
  rm -f "$fx/run.sh" "$fx/seed.sh" "$fx/local.sh" || return 1
  git -C "$UDD" show "${UD_T}:core/fixtures/udx/run.sh" > "$fx/run.sh" && git -C "$UDD" show "${UD_T}:core/fixtures/udx/seed.sh" > "$fx/seed.sh" || return 1
  [ "${7:-}" != chmod ] || chmod 755 "$fx/seed.sh" || return 1
  udput "$c" .claude/.ai-dlc-version "version: 1.0.0
commit: $UD_B
skill_commit: $UD_T" || return 1
  udg -C "$c" add -A && udg -C "$c" commit -q --no-verify -m self-update
}
if [ "$ud_built" = 1 ] \
   && ud_world "$UDW/c1" "$UD_B" 'udx seed, REPAIRED by the consumer' 'udx run at base' - 1 \
   && ud_world "$UDW/c2" "$UD_B" "$UD_SEED" 'udx run at base' - 1 chmod \
   && ud_world "$UDW/c3" "$UD_SK" 'udx seed at the skill_commit release' 'udx run at base' - 1 \
   && ud_world "$UDW/c4" "$UD_B" 'udx seed, REPAIRED by the consumer' 'udx run at base' - 1 \
   && ud_world "$UDW/c6" "$UD_B" 'udx seed, REPAIRED by the consumer' 'udx run at base' - 0 \
   && ud_world "$UDW/c7" "$UD_B" "$UD_SEED" 'udx run, edited by the consumer' - 1 \
   && ud_world "$UDW/c8" "$UD_B" "$UD_SEED" 'udx run at base' 'a consumer-added helper' 1 \
   && ud_world "$UDW/c9" "$UD_B" "$UD_SEED" 'udx run at base' - 1 \
   && udput "$UDW/c9" 'tests/fixtures/udx/q"x.sh' 'a file whose name git C-quotes' \
   && udg -C "$UDW/c9" add -A && udg -C "$UDW/c9" commit -q --amend --no-edit --no-verify; then :; else ud_built=0; fi
# Seed control: each checker world's commit lists the file its cell is about; c9's listing carries a line
# that opens with `"` under the checker's own quotePath=false, or UD9 asks nothing.
for _ud in c1:seed.sh c2:seed.sh c3:seed.sh c7:run.sh c8:local.sh; do
  _udl="$(git -C "$UDW/${_ud%%:*}" diff --name-only 'HEAD^' HEAD -- tests/fixtures/udx/ 2>/dev/null)" || _udl=""
  case "$_udl" in *"tests/fixtures/udx/${_ud#*:}"*) ;; *) ud_built=0 ;; esac
done
_udl="$(git -C "$UDW/c9" -c core.quotePath=false diff --name-only 'HEAD^' HEAD -- tests/fixtures/udx/ 2>/dev/null)" || _udl=""
case "$_udl" in '"tests/fixtures/udx/q\"x.sh"'*|*'
"tests/fixtures/udx/q\"x.sh"'*) ;; *) ud_built=0 ;; esac
# UD5's dist COPY: the base-only udx tree removed, proved unique to base and gone from the copy only.
UDDU="$UDW/dist-u"
if [ "$ud_built" = 1 ] && mkdir -p "$UDDU" && cp -R "$UDD/." "$UDDU/"; then
  _udtr="$(git -C "$UDD" rev-parse -q --verify "${UD_B}:core/fixtures/udx" 2>/dev/null)" || _udtr=""
  if [ -n "$_udtr" ] && [ "$_udtr" != "$(git -C "$UDD" rev-parse -q --verify "${UD_T}:core/fixtures/udx" 2>/dev/null)" ] \
     && [ "$_udtr" != "$(git -C "$UDD" rev-parse -q --verify "${UD_SK}:core/fixtures/udx" 2>/dev/null)" ] \
     && [ -f "$UDDU/.git/objects/${_udtr:0:2}/${_udtr:2}" ] && rm -f "$UDDU/.git/objects/${_udtr:0:2}/${_udtr:2}" \
     && ! git -C "$UDDU" cat-file -e "$_udtr" 2>/dev/null && git -C "$UDD" cat-file -e "$_udtr" 2>/dev/null; then :
  else ud_built=0; fi
else ud_built=0; fi
[ "$ud_built" = 1 ] || bad "FIXTURE ERROR: the UD worlds did not build, a world's commit does not list its subject file, or the base udx tree was not a removable loose object unique to base, so no UNDIFFED-OVERWRITE cell was asserted"
ud_cell() { # ud_cell <checker> <cell> -> 1 when the cell's assertion holds, 0 when not, X when the checker never reached its gate-record arm
  local r="$1" c="$2" dist="$UDD" cons rc=0 o n
  case "$c" in
    UD1) cons="$UDW/c1" ;; UD2) cons="$UDW/c2" ;; UD3) cons="$UDW/c3" ;;
    UD5) cons="$UDW/c1"; dist="$UDDU" ;; UD7) cons="$UDW/c7" ;; UD8) cons="$UDW/c8" ;; UD9) cons="$UDW/c9" ;;
    *) printf X; return ;;
  esac
  o="$UDW/$c.$(basename "$(dirname "$(dirname "$r")")").out"
  suf_run "$dist" "$UD_B" "$UD_T" "$cons" > "$o" 2>&1 || rc=$?
  grep -q '^GATE-RECORD: NOT-REQUIRED' "$o" || { printf X; return; }
  n="$(grep -c '^GATE-RECORD: SLICE' "$o")" || n=0
  case "$c" in
    UD1) [ "$rc" = 2 ] && [ "$n" = 1 ] && grep -q '^GATE-RECORD: SLICE udx — UNDIFFED-OVERWRITE: tests/fixtures/udx/seed.sh — upstream left it unchanged' "$o" \
           && grep -qF "supersedes the installed SKILL.md's GATE-RECORD-REFUSED disposition for this tag only; DEFER remains a safe fallback" "$o" \
           && grep -qF 'git checkout HEAD^ -- "tests/fixtures/udx"' "$o" ;;
    UD2|UD3|UD7) [ "$rc" = 0 ] && [ "$n" = 0 ] ;;
    UD5) [ "$rc" = 2 ] && grep -q '^GATE-RECORD: SLICE udx — UNCONFIRMED: core/fixtures/udx/seed.sh could not be confirmed' "$o" \
           && ! grep -q 'UNDIFFED-OVERWRITE' "$o" ;;
    UD8) [ "$rc" = 2 ] && [ "$n" = 1 ] && grep -q '^GATE-RECORD: SLICE udx — UNDIFFED-OVERWRITE: tests/fixtures/udx/local.sh — it is absent at both' "$o" ;;
    UD9) [ "$rc" = 2 ] && [ "$n" = 1 ] && grep -qF 'GATE-RECORD: SLICE "tests/fixtures/udx/q\"x.sh" — UNCONFIRMED: git listed this path C-quoted' "$o" ;;
  esac && printf 1 || printf 0
}
if [ "$ud_built" = 1 ]; then
  if [ "$(ud_cell "$RUNNER" UD1)" = 1 ]; then ok "Part UD1: a whole-directory write over a consumer repair to a file upstream did not change is refused UNDIFFED-OVERWRITE naming the file, with the remedy that supersedes the old disposition"
  else bad "Part UD1: a consumer-repaired undiffed seed.sh overwritten by the write was not refused with one SLICE UNDIFFED-OVERWRITE line and the remedy text ($UDW/UD1.*.out)"; fi
  if [ "$(ud_cell "$RUNNER" UD2)" = 1 ]; then ok "Part UD2: a listed undiffed file whose consumer copy equals base is not refused"
  else bad "Part UD2: a seed.sh equal to base (mode-only change) was refused or the run did not exit 0 ($UDW/UD2.*.out)"; fi
  if [ "$(ud_cell "$RUNNER" UD3)" = 1 ]; then ok "Part UD3: a consumer copy equal to the blob at its own HEAD^ skill_commit is upstream's bytes and is not refused"
  else bad "Part UD3: a seed.sh equal to the skill_commit blob was refused ($UDW/UD3.*.out)"; fi
  if [ "$(ud_cell "$RUNNER" UD5)" = 1 ]; then ok "Part UD5: a base read that can confirm neither presence nor absence is UNCONFIRMED, never an acquittal"
  else bad "Part UD5: with the base udx tree unreadable the checker did not refuse seed.sh UNCONFIRMED ($UDW/UD5.*.out)"; fi
  if [ "$(ud_cell "$RUNNER" UD7)" = 1 ]; then ok "Part UD7: a consumer edit to a file upstream DID change is preclassify's question and emits no UNDIFFED-OVERWRITE line"
  else bad "Part UD7: a consumer-edited diffed run.sh was refused by the undiffed arm ($UDW/UD7.*.out)"; fi
  if [ "$(ud_cell "$RUNNER" UD8)" = 1 ]; then ok "Part UD8: a consumer-added file absent at base and theirs that the write deleted is refused UNDIFFED-OVERWRITE"
  else bad "Part UD8: a consumer-added local.sh deleted by the write was not refused with one SLICE UNDIFFED-OVERWRITE line ($UDW/UD8.*.out)"; fi
  if [ "$(ud_cell "$RUNNER" UD9)" = 1 ]; then ok "Part UD9: a fixture path git lists C-quoted (a name carrying a double quote) is UNCONFIRMED, never skipped"
  else bad "Part UD9: a C-quoted fixture path in the self-update commit was not refused with one SLICE UNCONFIRMED line ($UDW/UD9.*.out)"; fi

  # UD4: the remedy, through the real push wrapper, on a consumer with a bare origin and a matching OK record.
  UD4C="$UDW/c4"; UD4_PUSH="$RECONCILE/self-update-push.sh"
  echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/self-update-push.sh"
  ud4_push() { # ud4_push <out> <tag> -> the wrapper's exit; stdout/stderr in $UDW/ud4-<tag>.{out,err}
    local rc=0
    ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
      export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
      cd / && FXCELL="ud4-$2" bash "$UD4_PUSH" "$UD4C" origin su "$1" "$UDD" "$UD_B" "$UD_T" ) > "$UDW/ud4-$2.out" 2> "$UDW/ud4-$2.err" || rc=$?
    printf '%s' "$rc"
  }
  ud4_ok=0
  # The write also ADDS new.sh, so the remedy's `git rm` step is exercised and the restored tree is compared whole.
  if udg init -q --bare "$UDW/o4.git" && udg -C "$UD4C" remote add origin "$UDW/o4.git" && udg -C "$UD4C" checkout -q -b su \
     && udput "$UD4C" tests/fixtures/udx/new.sh 'a file the write added' && udg -C "$UD4C" add -A \
     && udg -C "$UD4C" commit -q --amend --no-edit --no-verify \
     && SR_INPUTS="$(printf '# input: README\t%s\t-' "$(git hash-object "$UD4C/README")")" \
          seed_record "$UD4C/_bmad-output/ai-dlc-update" "$UDD" "$UD_B" "$UD_T" OK ud4 >/dev/null; then
    r1="$(ud4_push _bmad-output/ai-dlc-update/self-update-push-1.md first)"
    udg -C "$UD4C" checkout 'HEAD^' -- tests/fixtures/udx
    ud4_added="$(git -C "$UD4C" diff --diff-filter=A --name-only 'HEAD^' HEAD -- tests/fixtures/udx/ 2>/dev/null)"
    [ -z "$ud4_added" ] || udg -C "$UD4C" rm -q -- $ud4_added
    udg -C "$UD4C" commit -q --amend --no-edit --no-verify
    r2="$(ud4_push _bmad-output/ai-dlc-update/self-update-push-1.md same)"
    r3="$(ud4_push _bmad-output/ai-dlc-update/self-update-push-2.md new)"
    ud4_l=0
    [ -n "$(git -C "$UD4C" rev-parse -q --verify refs/heads/su 2>/dev/null)" ] \
      && [ "$(git --git-dir="$UDW/o4.git" rev-parse -q --verify refs/heads/su 2>/dev/null)" = "$(git -C "$UD4C" rev-parse -q --verify refs/heads/su 2>/dev/null)" ] && ud4_l=1
    ud4_trk=0; git -C "$UD4C" ls-files --error-unmatch -- _bmad-output/ai-dlc-update/self-update-push-1.md >/dev/null 2>&1 && ud4_trk=1
    if [ "$r1" = 2 ] && grep -q '^GATE-RECORD-REFUSED GATE-RECORD: SLICE udx — UNDIFFED-OVERWRITE' "$UDW/ud4-first.out" \
       && grep -qF 'supersedes the installed SKILL.md' "$UDW/ud4-first.err" \
       && [ "$r2" = 2 ] && grep -q 'already exists' "$UDW/ud4-same.err" \
       && [ "$r3" = 0 ] && grep -q '^GATE-RECORD: OK ' "$UDW/ud4-new.err" && [ "$ud4_l" = 1 ] && [ "$ud4_trk" = 0 ] \
       && [ -n "$ud4_added" ] && [ "$(git -C "$UD4C" rev-parse -q --verify 'HEAD:tests/fixtures/udx')" = "$(git -C "$UD4C" rev-parse -q --verify 'HEAD^:tests/fixtures/udx')" ]; then
      ud4_ok=1
    fi
    if [ "$ud4_ok" = 1 ]; then ok "Part UD4: the remedy (restore the directory from HEAD^, amend, re-run the wrapper) lands: the same <out> refuses 'already exists', a new <out> exits 0 with GATE-RECORD: OK, the first record stays untracked"
    else bad "Part UD4: the remedy read first=$r1 same=$r2 new=$r3 landed=$ud4_l first-record-tracked=$ud4_trk added='$ud4_added', want 2/2/0 landed=1 tracked=0, a non-empty added list and the udx tree equal to HEAD^'s ($UDW/ud4-*.err)"; fi
  else
    bad "FIXTURE ERROR: Part UD4's origin, branch or gate record did not build"
  fi

  # UD6: the DEFER path. apply.sh drives preclassify's rows only, so a file with no row is never written.
  UD6_APPLY="$RECONCILE/apply.sh"
  if [ -f "$UD6_APPLY" ]; then
    echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/apply.sh"
    ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
      export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
      bash "$UD6_APPLY" --carried-machinery-slice "$UDD" "$UD_B" "$UDW/c6" "$UD_T" ) > "$UDW/ud6.out" 2>&1
    if [ "$(git hash-object "$UDW/c6/tests/fixtures/udx/run.sh" 2>/dev/null)" = "$(git -C "$UDD" rev-parse -q --verify "${UD_T}:core/fixtures/udx/run.sh")" ] \
       && [ "$(cat "$UDW/c6/tests/fixtures/udx/seed.sh" 2>/dev/null)" = 'udx seed, REPAIRED by the consumer' ]; then
      ok "Part UD6: the DEFER path's apply.sh writes the diffed run.sh at theirs and leaves the consumer's undiffed seed.sh repair in place"
    else
      bad "Part UD6: apply.sh over the pre-write tree did not write run.sh at theirs with seed.sh's repair intact ($UDW/ud6.out)"
    fi
  else
    bad "FIXTURE ERROR: Part UD6 has no apply.sh beside the checker ($UD6_APPLY)"
  fi

fi

# --- the cli cells (cells.decl): the checker run as a PROGRAM once per distinct CLI outcome -----------------------
# The outcomes are exit x output class: 0 with the `GATE-RECORD: OK` line, 0 with NOT-REQUIRED, 2 with the argument
# refusal on stderr, 2 with the no-record refusal on stdout and its remedy on stderr, 2 with a SLICE line on stdout.
# One `FXCELL=<id> bash "$RUNNER"` start per outcome, each compared with the in-process call on the same world: stdout,
# stderr and exit separately, byte for byte. A cell also asserts its own outcome (a positive conjunct, so two runs that
# both printed nothing cannot read as equivalent), and the cells must differ from one another.
EQ="$(mktemp -d)"; sufl_tmp "$EQ"
eqv() { # <cell-id> <dist> <base> <theirs> <consumer> [extra...] -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  suf_run "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$RUNNER" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(head -c 300 "$EQ/$1.ip.out")" "$(head -c 300 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(head -c 300 "$EQ/$1.cl.out")" "$(head -c 300 "$EQ/$1.cl.err")"; }
echo "== cli cells"
gin_restore
gin_seed_clean 300
gin_write_slice
if eqv cli-ok "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" && [ "$(cat "$EQ/cli-ok.cl.rc")" = 0 ] && grep -q '^GATE-RECORD: OK ' "$EQ/cli-ok.cl.out"; then
  ok "cli-ok: the program accepts the recorded OK verdict exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-ok: the program and the in-process call differ, or the outcome is not exit 0 with a GATE-RECORD: OK line ($(eq_twin cli-ok))"; fi
if eqv cli-notrequired "$DIST" "$D_BASE" "$D_THEIRS" "$SCC/c" && [ "$(cat "$EQ/cli-notrequired.cl.rc")" = 0 ] \
   && grep -q '^GATE-RECORD: NOT-REQUIRED' "$EQ/cli-notrequired.cl.out"; then
  ok "cli-notrequired: the program takes the delivery-pull tolerance exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-notrequired: the program and the in-process call differ, or the outcome is not exit 0 with NOT-REQUIRED ($(eq_twin cli-notrequired))"; fi
if eqv cli-usage "$DIST" "$D_BASE" "$D_THEIRS" "$BH_C" bh-fx && [ "$(cat "$EQ/cli-usage.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-usage.cl.out" ] \
   && grep -qF 'runs NO fixture' "$EQ/cli-usage.cl.err"; then
  ok "cli-usage: the program refuses a fifth argument exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not the exit-2 argument refusal ($(eq_twin cli-usage))"; fi
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 301 >/dev/null || bad "FIXTURE ERROR: could not seed the cli-refused unrelated-range record"
if eqv cli-refused "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" && [ "$(cat "$EQ/cli-refused.cl.rc")" = 2 ] && grep -q '^GATE-RECORD:' "$EQ/cli-refused.cl.out" \
   && grep -qF 'self-update-gate.sh' "$EQ/cli-refused.cl.err"; then
  ok "cli-refused: the program refuses a consumer with no record for the range exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-refused: the program and the in-process call differ, or the outcome is not exit 2 with a GATE-RECORD line and the gate remedy ($(eq_twin cli-refused))"; fi
if eqv cli-slice "$DIST" "$D_BASE" "$D_THEIRS" "$SC9/c" && [ "$(cat "$EQ/cli-slice.cl.rc")" = 2 ] \
   && grep -q '^GATE-RECORD: SLICE named-distonly — DIST-ONLY' "$EQ/cli-slice.cl.out"; then
  ok "cli-slice: the program refuses a .dist-only fixture directory exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-slice: the program and the in-process call differ, or the outcome is not exit 2 with a SLICE DIST-ONLY line ($(eq_twin cli-slice))"; fi
cli_same=0
for _a in cli-ok cli-notrequired cli-usage cli-refused cli-slice; do for _b in cli-ok cli-notrequired cli-usage cli-refused cli-slice; do
  [ "$_a" \< "$_b" ] || continue
  cmp -s "$EQ/$_a.cl.out" "$EQ/$_b.cl.out" && cmp -s "$EQ/$_a.cl.err" "$EQ/$_b.cl.err" && cmp -s "$EQ/$_a.cl.rc" "$EQ/$_b.cl.rc" && cli_same=$((cli_same + 1))
done; done
if [ "$cli_same" = 0 ]; then ok "cli cells discriminate: no two of the five outcomes gave the same stdout, stderr and exit"
else bad "cli cells do not discriminate: $cli_same pair(s) of cells gave the same stdout, stderr and exit"; fi

echo
if [ "$fails" -eq 0 ]; then
  echo "self-update-fixture-log: PASS"
  exit 0
fi
echo "self-update-fixture-log: FAIL ($fails)"
exit 1
