#!/usr/bin/env bash
# Prove I39 can FAIL.
#
# WHY THIS FIXTURE EXISTS. I39 joins `ledger-reverify.sh`'s emitted status set to the set
# SKILL.md step 3f documents, in both directions, plus the subset emit-report.sh's push-candidate
# heading names, plus — the reader that ACTS — the disposition SKILL.md step 8 gives each status
# that heading announces. It passes on this repo and will pass on every well-formed tree — the
# state this repo names as its recurring defect. Its whole value is the half-done rename it
# rejects, and a green with no mutant behind it is indistinguishable from an extraction that
# stopped matching.
#
# THE MUTANT IS THE INPUT, NOT THE VALIDATOR. I39 resolves both its inputs against $REPO_ROOT,
# which is derived from the validator's own location, so there is no tunable to point it at a
# seeded file — and adding one would be a surface for weakening the gate, because unlike I36
# BOTH of I39's sides are mutable, so an override could hand it two agreeing empty sets. Instead
# the repo's TRACKED files are copied to a temp tree and the mutation is made THERE. Every other
# invariant runs against a complete tree in each copy, which is what lets an assertion attribute
# a failure to I39 rather than to the copy being incomplete.
#
# Each mutant is a COPY guarded by `cmp -s`, asserts a POSITIVE outcome (the specific I39 message
# appears), and asserts the run produced EXACTLY ONE failure line — except half-rename, whose
# subject is a rename that genuinely breaks both directions at once and which therefore asserts
# both tokens by name. That count is how this file proves the assertions are not entangled, and
# a mutant that starts reporting two is a signal about the VALIDATOR, not about this number.
#
# Every assertion is
# PRESENCE-shaped, so none of them can be satisfied by a validator that emits nothing: measured
# with `validate-enforcement-map.sh` replaced by `exit 0`, ten of the eleven fail and only the
# unmutated control passes.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# I10 — a fixture must not inherit an ambient tunable that changes what it measures.
unset AI_DLC_LAYER_CONTRACT

# This validator is distribution-only (scripts/, not core/scripts/), so a consumer tree does not
# have it and the fixture declares itself inapplicable rather than failing.
VAL="$DIR/../../../scripts/validate-enforcement-map.sh"
if [ ! -f "$VAL" ]; then
  echo "ledger-status-vocabulary: SKIP — validate-enforcement-map.sh is distribution-only and is not installed in a consumer tree."
  exit 0
fi
REPO="$(cd "$(dirname "$VAL")/.." && pwd)"

# The mutation surface is the working tree, so the copy is of TRACKED files at their working-tree
# content — the fixture tests the tree it is running in, not the last commit.
if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ledger-status-vocabulary: FIXTURE ERROR — $REPO is not a git checkout, so the tracked-file copy cannot be built. This is an error, not a skip: reporting clean here would be a check that cannot fire." >&2
  exit 2
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ledger-status-vocab-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

BASE="$TMP/base"
mkdir -p "$BASE"
git -C "$REPO" ls-files -z | while IFS= read -r -d '' f; do
  mkdir -p "$BASE/$(dirname "$f")"
  cp "$REPO/$f" "$BASE/$f"
done
COPIED="$(find "$BASE" -type f | wc -l | tr -d ' ')"
if [ "$COPIED" -lt 100 ]; then
  echo "ledger-status-vocabulary: FIXTURE ERROR — copied only $COPIED files; an incomplete tree fails every invariant and would score every mutant as a kill." >&2
  exit 2
fi

LR="core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
SK="core/skills/ai-dlc-update/SKILL.md"
ER="core/skills/ai-dlc-update/reconcile/emit-report.sh"

FAILURES=0
ASSERTIONS=0

echo "ledger-status-vocabulary fixture"
echo

# EVERY RUN IS INDEPENDENT, SO THEY GO THROUGH A POOL. Each assertion below copies the tracked
# tree, mutates one file in the copy and runs `validate-enforcement-map.sh` over it — one run
# per assertion, sharing nothing. The pre-push suite is POLE-BOUND: its makespan tracks its
# single longest unit, so an internally-serial fixture sets the wall clock for the whole push
# whatever AI_DLC_FIXTURE_JOBS says.
#
# THE COST STEPS AT EACH MULTIPLE OF LSV_JOBS, NOT PER RUN. Eight runs and eleven runs are one
# wave and two, so the eleventh assertion is free and the ninth was not. Measured standalone
# from the repo root: 31s at seven runs (one wave), 49-53s at eleven (two). Read the LOADED cost
# from `.git/ai-dlc-fixture-durations`, never this comment, and compare it against the top of
# that file before adding a twelfth — a cost recorded there is measured under the 16-way pool
# and is a different number from anything measured here.
#
# Three phases. The call sites in the middle are UNCHANGED from the serial version —
# `mutant_fires` now REGISTERS a run instead of performing it, and a third phase evaluates the
# registry in DECLARATION order, which is what keeps this fixture's stdout byte-comparable
# against the version it replaces.
RUNS="$TMP/runs"; : > "$RUNS"
MUTD="$TMP/seds"; mkdir -p "$MUTD"
OUTD="$TMP/out";  mkdir -p "$OUTD"

# THE UNMUTATED CONTROL, FIRST. Each mutant is a fresh copy of this tree; if the copy itself
# cannot come out clean then every "the mutant fired" result below is a kill it did not earn.
# This is the control that caught a copy missing its manifest on the first draft.
# It is registered like any other run and REPORTED first; an empty sed program is the whole of
# its mutation, so the worker runs the validator over an untouched copy.
ASSERTIONS=$((ASSERTIONS + 1))
: > "$MUTD/control.sed"
printf 'control\t%s\t\t\t\n' "control" >> "$RUNS"

# $1 label  $2 file-to-mutate  $3 sed-expr  $4 substring that MUST appear  $5 expected FAIL count  $6 why
#
# The sed program goes to a FILE rather than into the registry: these programs carry
# backslashes and both quote characters, and one that arrived at the worker subtly re-quoted
# would still apply, still satisfy `cmp -s`, and prove something other than what its call site
# says.
mutant_fires() {
  local label="$1" file="$2" expr="$3" want="$4" want_n="$5" why="$6"
  ASSERTIONS=$((ASSERTIONS + 1))
  printf '%s' "$expr" > "$MUTD/$label.sed"
  printf 'fires\t%s\t%s\t%s\t%s\t%s\n' "$label" "$file" "$want" "$want_n" "$why" >> "$RUNS"
}

# --- Forward: the emitter produces a status step 3f does not document -----------------
# The silent half. The operator is handed a verdict the step governing the ledger does not
# explain, and the pull looks complete.
mutant_fires "emit-undocumented" "$LR" \
  's/^\(  na=""; nam=""\)$/  emit NAMED-PHANTOM "x" "y"\n\1/' \
  "emits 'NAMED-PHANTOM' but SKILL.md step 3f never documents it" 1 \
  "a status with no entry in step 3f reaches the operator with no stated handling"

# --- Reverse: step 3f documents a status nothing emits --------------------------------
mutant_fires "documented-unemitted" "$SK" \
  's/^   - `HAND-REVIEW` → /   - `PHANTOM-STATUS` → nothing emits this.\n   - `HAND-REVIEW` → /' \
  "documents 'PHANTOM-STATUS' but ledger-reverify.sh never emits it" 1 \
  "the step describes a row no run can produce, which an operator reads as nothing to do"

# --- The zero guards. Both sides going empty must FAIL, never agree vacuously ----------
# Two empty sets are equal, so without these the check reports agreement the moment either
# extraction stops matching — the exact shape of a check that cannot fire. The emitter mutation
# widens `emit ` to `emit  `, which bash runs identically and the extraction cannot see.
mutant_fires "emitter-zero" "$LR" \
  's/^\([[:space:]]*\)emit \([A-Z]\)/\1emit  \2/' \
  "I39 found NO statuses in ledger-reverify.sh" 1 \
  "an extraction that stopped matching must fail loudly, not report two empty sets in agreement"

mutant_fires "skill-zero" "$SK" \
  's/^3f\. \*\*/3z. **/' \
  "I39 found NO documented statuses in ai-dlc-update/SKILL.md step 3f" 1 \
  "renumbering the step must fail loudly rather than silently retiring the reverse direction"

# --- The report heading is the third reader -------------------------------------------
# It names a SUBSET by design, so only one direction is checkable: a heading promising a section
# whose status nothing emits promises the operator rows that can never arrive.
#
# THIS MUTANT ONCE FIRED TWO ARMS, AND THE FIX WAS THE VALIDATOR, NOT THE COUNT. When the step-8
# arm landed it iterated the heading set unfiltered, so a phantom heading status was reported
# twice: once as a section that can never have rows, once as a duty with no actor. Reshaping the
# MUTANT could not fix it — derived over this tree, every backtick-delimited status in step 8's
# acting region is also emitted, so no phantom token exists that trips the emitter arm and
# leaves the step-8 arm quiet. The step-8 loop was therefore narrowed to iterate
# `er_sts ∩ lr_emitted`: a status the emitter cannot produce owes the operator no disposition,
# and the arm above already reports it.
#
# SO THE `want_n 1` BELOW IS LOAD-BEARING AND IS NOT A TOLERANCE. Re-widening that loop makes
# this mutant report 2 and fails here. Do not "fix" that by raising the number — the second
# finding is the vacuous one, which is the whole of `fixture-mutants.md`'s two-failures rule.
mutant_fires "heading-phantom" "$ER" \
  's/Push-candidate ledger — CLOSE-CANDIDATE/Push-candidate ledger — GONE-CANDIDATE/' \
  "heading names 'GONE-CANDIDATE', which ledger-reverify.sh does not emit" 1 \
  "the report promises a section that can never have rows in it"

# --- The fourth reader is the one that ACTS: step 8 --------------------------------------
# A status the report puts in front of the operator and step 8 gives no disposition to is a duty
# with no actor, and it fails in the CLOSING direction: the reader executing step 8 literally
# leaves the row unannotated and it re-reports forever. Removing one status from step 8's
# disposition list is the whole defect, in one line.
mutant_fires "step8-undisposed" "$SK" \
  's/, `INPUT-UNRESOLVED`//' \
  "heading puts 'INPUT-UNRESOLVED' in front of the operator, but SKILL.md step 8" 1 \
  "a status the report announces and step 8 never names is a duty with no actor"

# --- THE DECISIVE ARM: the substring near-miss --------------------------------------------
# The step-8 arm matches BACKTICK-DELIMITED, and the delimiters are the whole of its
# false-positive narrowing. They are also invisible: drop them and every other arm in this file
# stays green, because `NAMED-UPSTREAM` is a proper substring of `NAMED-UPSTREAM-AMBIGUOUS` — a
# DIFFERENT status, deliberately not attributed, carrying a different duty.
#
# So this mutant deletes step 8's `NAMED-UPSTREAM` bullet and LEAVES the AMBIGUOUS one standing.
# The mutated tree therefore still contains the bare substring while owing an unfilled duty, and
# a bare-substring predicate is satisfied by it. The delimited predicate is not. The kind gets
# its own evaluator below because half the arm is the PRECONDITION: if a later edit also removes
# the AMBIGUOUS bullet this stops being a near-miss and silently degenerates into a second copy
# of step8-undisposed, so the precondition is asserted rather than assumed.
#
# The address is anchored on FIVE leading spaces. Step 3f's own bullet for the same status sits
# at three, and an unanchored range would swallow it and take out the 3f arms with it — measured
# while building this: the loose form deleted 16 lines of step 3f as well.
NEAR_MISS_SED='/^     - `NAMED-UPSTREAM` /,/^     - `NAMED-UPSTREAM-AMBIGUOUS` /{/^     - `NAMED-UPSTREAM-AMBIGUOUS` /!d;}'
ASSERTIONS=$((ASSERTIONS + 1))
printf '%s' "$NEAR_MISS_SED" > "$MUTD/near-miss.sed"
printf 'near-miss\t%s\t%s\t\t\n' "near-miss" "$SK" >> "$RUNS"

# --- The step-8 arm's two zero guards, each driven -----------------------------------------
# Both are "a zero silently retires the check" guards, and a guard nobody has fired is a guard
# that may not fire. The heading side goes empty by breaking the literal the extraction anchors
# on; the SKILL side goes empty by renumbering the step, exactly as skill-zero does for 3f.
# Neither may be allowed to read as agreement: an empty heading set makes the two arms above
# vacuous, and an empty step-8 region retires the acting-reader check while everything else
# still passes.
mutant_fires "heading-zero" "$ER" \
  's/Push-candidate ledger/Push-candidate LEDGER/' \
  "push-candidate heading yielded NO statuses" 1 \
  "an empty heading set makes both heading arms vacuous, which reads exactly like agreement"

mutant_fires "step8-zero" "$SK" \
  's/^8\. \*\*Deliver/8z. **Deliver/' \
  "I39 could not locate SKILL.md's step 8 acting region" 1 \
  "renumbering step 8 must fail loudly rather than silently retiring the acting-reader check"

# --- THE DEFECT THIS INVARIANT SHIPPED FOR: a half-done rename ------------------------
# v0.186.0 renamed the NAMED-* status across five files. Reverting the SKILL.md half alone
# leaves a tree where the emitter and the rulebook speak different vocabularies, and every other
# check in the repo passes on it. TWO failures here is the correct outcome and not entanglement:
# a rename genuinely breaks both directions at once, and an assertion naming only one of them
# would pass on a rename that had been reverted in the other direction.
ASSERTIONS=$((ASSERTIONS + 1))
printf '%s' 's/NAMED-UPSTREAM/NAMED-ABSORBED/g' > "$MUTD/half-rename.sed"
printf 'half-rename\t%s\t%s\t\t\n' "half-rename" "$SK" >> "$RUNS"

# ==================== PHASE 2: build and drive every copy, in a pool ====================
# The zero guard is this fixture's own subject one level out: a registration grammar that
# stopped filling yields an empty list, and an empty list passes every assertion it never made.
N_RUNS="$(grep -c . "$RUNS" || true)"
if [ "$N_RUNS" -ne "$ASSERTIONS" ]; then
  echo "ledger-status-vocabulary: FIXTURE ERROR — registered $N_RUNS run(s) for $ASSERTIONS assertion(s); the registry and the counter disagree, so the report below would be scoped to whichever is smaller." >&2
  exit 2
fi

# EIGHT, AND FIXED RATHER THAN TUNABLE — the same number and reasoning the sibling pools state
# in place: this pool nests inside the pre-push suite's own, so a knob here multiplies against
# the knob there and the PRODUCT is what lands on the machine.
#
# The `cmp -s` guard stays INSIDE the worker, where the copy is made. It is what stops a sed
# that matched nothing from scoring as a kill, and moving it to the parent would put it on the
# wrong side of the thing it checks.
LSV_JOBS=8
LSV_BASE="$BASE" LSV_MUTD="$MUTD" LSV_OUT="$OUTD" LSV_WORK="$TMP" LSV_RUNS="$RUNS" \
  xargs -P "$LSV_JOBS" -I{} bash -c '
    l="$1"
    f="$(awk -F"\t" -v k="$l" "\$2==k{print \$3}" "$LSV_RUNS")"
    work="$LSV_WORK/w-$l"
    rm -rf "$work"; cp -R "$LSV_BASE" "$work" || exit 0
    if [ -n "$f" ]; then
      sed -f "$LSV_MUTD/$l.sed" "$LSV_BASE/$f" > "$work/$f" 2>/dev/null
      if cmp -s "$LSV_BASE/$f" "$work/$f"; then
        printf UNMUTATED > "$LSV_OUT/$l.state"
        printf done      > "$LSV_OUT/$l.done"
        rm -rf "$work"; exit 0
      fi
    fi
    bash "$work/scripts/validate-enforcement-map.sh" > "$LSV_OUT/$l.out" 2>&1
    printf %s $? > "$LSV_OUT/$l.rc"
    printf done  > "$LSV_OUT/$l.done"
    rm -rf "$work"
  ' _ {} < <(cut -f2 "$RUNS")

# ================= PHASE 3: evaluate, serially, in DECLARATION order =================
while IFS=$'\t' read -r kind label file want want_n why; do
  [ -n "$label" ] || continue

  # A MISSING VERDICT IS A FAILURE, not a gap. `.done` is written after the run, so its
  # absence means the pool dropped the job — which otherwise contributes exactly what a
  # passing assertion contributes: nothing.
  if [ ! -f "$OUTD/$label.done" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-20s produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one\n' "$label"
    continue
  fi

  if [ -f "$OUTD/$label.state" ]; then
    FAILURES=$((FAILURES + 1))
    case "$kind" in
      half-rename) printf '  FAIL  %-20s the rename revert matched nothing — SKILL.md no longer carries the status this asserts on\n' "$label" ;;
      *)           printf '  FAIL  %-20s the mutation matched nothing, so this assertion is unproven\n' "$label" ;;
    esac
    continue
  fi

  out="$(cat "$OUTD/$label.out" 2>/dev/null)"
  rc="$(cat "$OUTD/$label.rc" 2>/dev/null)"
  n="$(printf '%s\n' "$out" | grep -c '^FAIL:' || true)"

  case "$kind" in
    control)
      if [ "$rc" = "0" ] && [ "$n" -eq 0 ]; then
        printf '  ok    %-20s clean copy  (a mutant fire below is attributable to the mutation)\n' "$label"
      else
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-20s the UNMUTATED copy already fails (rc=%s) — every mutant below is unattributable\n' "$label" "$rc"
        printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/          | /' | head -5
      fi ;;

    fires)
      if ! grep -qF "$want" <<<"$out"; then
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-20s I39 did NOT fire  (%s)\n' "$label" "$why"
        printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/          | /' | head -3
      elif [ -n "$want_n" ] && [ "$n" -ne "$want_n" ]; then
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-20s fired, but the run produced %s failures (want %s) — the assertions are entangled and one of them is vacuous\n' "$label" "$n" "$want_n"
        printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/          | /' | head -4
      else
        printf '  ok    %-20s fires  (%s)\n' "$label" "$why"
      fi ;;

    near-miss)
      # THE PRECONDITION IS HALF THE ARM, and it is checked FIRST. Recomputed from the same sed
      # program over the same input the worker mutated, so it describes the tree the validator
      # actually read. The mutated acting region must still CONTAIN the bare substring and must
      # NOT contain it backtick-delimited; that pair is the only thing separating this mutant
      # from step8-undisposed, and neither the validator's output nor `cmp -s` can see it.
      m8="$(sed -f "$MUTD/near-miss.sed" "$BASE/$SK" \
            | awk '/^8\. \*\*Deliver/{on=1} on && /^9\. \*\*Safety/{exit} on')"
      bare=0; delim=0
      grep -qF 'NAMED-UPSTREAM'   <<<"$m8" && bare=1
      grep -qF '`NAMED-UPSTREAM`' <<<"$m8" && delim=1
      # The quotes in the wanted message are load-bearing the same way the backticks are:
      # "puts 'NAMED-UPSTREAM' in front" cannot be satisfied by a message about
      # 'NAMED-UPSTREAM-AMBIGUOUS', because the closing quote follows the token immediately.
      if [ "$bare" -ne 1 ] || [ "$delim" -ne 0 ]; then
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-20s this is no longer a NEAR-MISS (bare substring present=%s, backticked present=%s) — it now proves only what step8-undisposed proves, and the delimiters are unguarded\n' "$label" "$bare" "$delim"
      elif ! grep -qF "heading puts 'NAMED-UPSTREAM' in front of the operator, but SKILL.md step 8" <<<"$out"; then
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-20s I39 did NOT report NAMED-UPSTREAM undispositioned while step 8 disposes only NAMED-UPSTREAM-AMBIGUOUS. If the other arms above fired, the step-8 predicate has lost its backtick delimiters and is now closing on a disposition written for a different row; if they went quiet too, read the control first\n' "$label"
        printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/          | /' | head -3
      elif [ "$n" -ne 1 ]; then
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-20s fired, but the run produced %s failures (want 1) — the assertions are entangled and one of them is vacuous\n' "$label" "$n"
        printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/          | /' | head -4
      else
        printf '  ok    %-20s fires  (a step 8 disposing only NAMED-UPSTREAM-AMBIGUOUS still owes NAMED-UPSTREAM, which a bare-substring predicate cannot say)\n' "$label"
      fi ;;

    half-rename)
      fwd=0; rev=0
      grep -qF "emits 'NAMED-UPSTREAM' but SKILL.md step 3f never documents it" <<<"$out" && fwd=1
      grep -qF "documents 'NAMED-ABSORBED' but ledger-reverify.sh never emits it" <<<"$out" && rev=1
      if [ "$fwd" -eq 1 ] && [ "$rev" -eq 1 ]; then
        printf '  ok    %-20s both directions fire and name both tokens  (the half-done rename is rejected)\n' "$label"
      else
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-20s half-done rename not fully caught (forward=%s reverse=%s)\n' "$label" "$fwd" "$rev"
        printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/          | /' | head -4
      fi ;;
  esac
done < "$RUNS"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
