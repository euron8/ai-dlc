#!/usr/bin/env bash
# Prove I39 can FAIL.
#
# WHY THIS FIXTURE EXISTS. I39 joins `ledger-reverify.sh`'s emitted status set to the set
# SKILL.md step 3f documents, in both directions, plus the subset emit-report.sh's push-candidate
# heading names. It passes on this repo and will pass on every well-formed tree — the state this
# repo names as its recurring defect. Its whole value is the half-done rename it rejects, and a
# green with no mutant behind it is indistinguishable from an extraction that stopped matching.
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
# appears), and — for the five single-arm mutants — asserts the run produced EXACTLY ONE failure
# line, which is how this file proves the assertions are not entangled.
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

# THE UNMUTATED CONTROL, FIRST. Each mutant is a fresh copy of this tree; if the copy itself
# cannot come out clean then every "the mutant fired" result below is a kill it did not earn.
# This is the control that caught a copy missing its manifest on the first draft.
ASSERTIONS=$((ASSERTIONS + 1))
ctl_out="$(bash "$BASE/scripts/validate-enforcement-map.sh" 2>&1)"; ctl_rc=$?
ctl_fails="$(printf '%s\n' "$ctl_out" | grep -c '^FAIL:' || true)"
if [ "$ctl_rc" -eq 0 ] && [ "$ctl_fails" -eq 0 ]; then
  printf '  ok    %-20s clean copy  (a mutant fire below is attributable to the mutation)\n' "control"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-20s the UNMUTATED copy already fails (rc=%s) — every mutant below is unattributable\n' "control" "$ctl_rc"
  printf '%s\n' "$ctl_out" | grep '^FAIL:' | sed 's/^/          | /' | head -5
fi

# $1 label  $2 file-to-mutate  $3 sed-expr  $4 substring that MUST appear  $5 expected FAIL count  $6 why
mutant_fires() {
  local label="$1" file="$2" expr="$3" want="$4" want_n="$5" why="$6" work out n
  ASSERTIONS=$((ASSERTIONS + 1))
  work="$TMP/$label"
  rm -rf "$work"; cp -R "$BASE" "$work"
  sed "$expr" "$BASE/$file" > "$work/$file"
  if cmp -s "$BASE/$file" "$work/$file"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-20s the mutation matched nothing, so this assertion is unproven\n' "$label"
    return
  fi
  out="$(bash "$work/scripts/validate-enforcement-map.sh" 2>&1)"
  n="$(printf '%s\n' "$out" | grep -c '^FAIL:' || true)"
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
  fi
}

# --- Forward: the emitter produces a status step 3f does not document -----------------
# The silent half. The operator is handed a verdict the step governing the ledger does not
# explain, and the pull looks complete.
mutant_fires "emit-undocumented" "$LR" \
  's/^\(  na=""\)$/  emit NAMED-PHANTOM "x" "y"\n\1/' \
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
mutant_fires "heading-phantom" "$ER" \
  's/Push-candidate ledger — CLOSE-CANDIDATE/Push-candidate ledger — GONE-CANDIDATE/' \
  "heading names 'GONE-CANDIDATE', which ledger-reverify.sh does not emit" 1 \
  "the report promises a section that can never have rows in it"

# --- THE DEFECT THIS INVARIANT SHIPPED FOR: a half-done rename ------------------------
# v0.186.0 renamed the NAMED-* status across five files. Reverting the SKILL.md half alone
# leaves a tree where the emitter and the rulebook speak different vocabularies, and every other
# check in the repo passes on it. TWO failures here is the correct outcome and not entanglement:
# a rename genuinely breaks both directions at once, and an assertion naming only one of them
# would pass on a rename that had been reverted in the other direction.
ASSERTIONS=$((ASSERTIONS + 1))
work="$TMP/half-rename"
rm -rf "$work"; cp -R "$BASE" "$work"
sed 's/NAMED-UPSTREAM/NAMED-ABSORBED/g' "$BASE/$SK" > "$work/$SK"
if cmp -s "$BASE/$SK" "$work/$SK"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-20s the rename revert matched nothing — SKILL.md no longer carries the status this asserts on\n' "half-rename"
else
  out="$(bash "$work/scripts/validate-enforcement-map.sh" 2>&1)"
  fwd=0; rev=0
  grep -qF "emits 'NAMED-UPSTREAM' but SKILL.md step 3f never documents it" <<<"$out" && fwd=1
  grep -qF "documents 'NAMED-ABSORBED' but ledger-reverify.sh never emits it" <<<"$out" && rev=1
  if [ "$fwd" -eq 1 ] && [ "$rev" -eq 1 ]; then
    printf '  ok    %-20s both directions fire and name both tokens  (the half-done rename is rejected)\n' "half-rename"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-20s half-done rename not fully caught (forward=%s reverse=%s)\n' "half-rename" "$fwd" "$rev"
    printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/          | /' | head -4
  fi
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
