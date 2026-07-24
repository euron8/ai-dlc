#!/usr/bin/env bash
# Exercise reconcile/ledger-reverify.sh against the ledger-reverify fixture.
#
# THE DIFFERENTIAL. Entry A and Entry B carry identical verify directives except the
# substring; they classify differently ONLY because `theirs` contains MARKER_B and not
# MARKER_A. A closer that probes `base` instead of `theirs` sees neither marker and calls
# both STILL-LIVE — so Entry B's CLOSE-CANDIDATE assertion below goes red. That is the
# mutation proof baked into the pair: the fixture cannot pass a closer that ignores theirs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# Locate the detector in BOTH layouts. Distribution: fixtures at core/fixtures/<name>/,
# detector at core/skills/…. Consumer: install.sh relocates fixtures to tests/fixtures/<name>/
# and the detector to .claude/skills/… — three levels up from the fixture, NOT two. The
# consumer candidate was `../../.claude` (two up → tests/.claude/, which does not exist), so
# every relocated-fixture consumer aborted `cannot locate` and blocked its pre-push suite,
# while the distribution stayed green on the first candidate. Test it as a CONSUMER, not only
# where core/ sits two up.
CLOSER=""
LOOKED=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && CLOSER="$cand" && break
done
[ -n "$CLOSER" ] || { printf 'FAIL: cannot locate ledger-reverify.sh from %s. Looked in:\n%s' "$DIR" "$LOOKED"; exit 1; }

read -r DIST BASE CONS THEIRS < <(bash "$DIR/seed.sh")
trap 'rm -rf "$(dirname "$DIST")"' EXIT

OUT="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"

FAILURES=0
ASSERTIONS=0

# $1 label-substring  $2 expected STATUS (or "ABSENT")  $3 why
row_is() {
  local label="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" '$2 ~ l {print $1; exit}')"
  if [ "$want" = "ABSENT" ]; then
    if [ -z "$got" ]; then
      printf '  ok    %-22s no row  (%s)\n' "$label" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-22s got=%s want=no-row  (%s)\n' "$label" "$got" "$why"
    fi
  elif [ "$got" = "$want" ]; then
    printf '  ok    %-22s %s  (%s)\n' "$label" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s got=%s want=%s  (%s)\n' "$label" "${got:-<none>}" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  fi
}

echo "ledger-reverify fixture"
echo

row_is "Entry A" STILL-LIVE      "theirs still lacks MARKER_A -> entry stays open"
row_is "Entry B" CLOSE-CANDIDATE "theirs now has MARKER_B -> upstream absorbed it"
row_is "Entry C" ABSENT          "already ADOPTED UPSTREAM -> closed, not re-emitted"
row_is "Entry D" ABSENT          "no verify: line -> hand-review, no row"

# THE THIRD DIFFERENTIAL — a declared manual entry vs a malformed one. Both used to land on
# NEEDS-REVIEW, so a deliberate "no mechanical predicate exists" declaration was reported in
# the same breath as a typo, and draining the bucket meant re-reading entries that had already
# said they need no machine check.
row_is "Entry E" HAND-REVIEW     "verify: manual is a declaration, not a malformed line"
row_is "Entry F" HAND-REVIEW     "trailing backtick on the verb is a formatting slip, not a different verb"

# THE FOURTH DIFFERENTIAL — path namespace. G carries Entry B's claim verbatim but filed in
# the consumer install layout. Before the basename fallback it reported NEEDS-REVIEW: the
# substring was never compared, so the closer said nothing about a claim upstream had already
# absorbed. G and B must agree; that they can disagree at all is the defect.
row_is "Entry G" CLOSE-CANDIDATE "consumer-namespace path resolves by basename -> same verdict as Entry B"

# ...and the fallback must REFUSE to guess. H's basename matches two files at theirs, I's
# matches none. A fallback that picked the first match would classify H on the wrong file
# while reading exactly like a correct verdict.
row_is "Entry H" NEEDS-REVIEW    "ambiguous basename (2 matches) -> refuse to guess"
row_is "Entry I" NEEDS-REVIEW    "basename matches nothing at theirs -> nothing to fall back to"

# THE FIFTH DIFFERENTIAL — a close nothing upstream produced. J and K classify CLOSE-CANDIDATE
# on the theirs-side test alone, but neither predicate's STILL-LIVE side was ever reachable:
# J's substring is absent at base AND theirs, K's is present at both. A closer that tests only
# theirs emits a confident close for a claim no upstream change touched, and a drain acts on
# it. Six entries on the reference consumer had exactly this shape, every one a live defect.
row_is "Entry J" NEEDS-REVIEW    "theirs_has on a substring absent at base too -> vacuous, not absorbed"
row_is "Entry K" NEEDS-REVIEW    "theirs_lacks on a substring present at base too -> vacuous, not absorbed"

# THE SIXTH DIFFERENTIAL — more than one substring in a directive. Joined into a single
# literal (quotes included) the pattern matches nothing, so BOTH L and M report "still
# lacks" and only L is right. M is the damage: theirs carries both markers, and the entry
# would sit open forever against an upstream that had already absorbed it. Matching each
# substring separately is what makes the pair disagree, which is what makes the test real.
row_is "Entry L" STILL-LIVE      "two substrings, neither at theirs -> genuinely still live"
row_is "Entry M" CLOSE-CANDIDATE "two substrings, BOTH at theirs -> absorbed, must not stay open"

# THE SECOND DIFFERENTIAL — entry SHAPE. These three carry the same directives as B/C/D but
# in the `## SECTION-ID — title` shape instead of a `- **bullet**`. A parser that treats every
# heading as a pure terminator clears the label, so the directive is parsed and then dropped:
# no row, exit 0, indistinguishable from "nothing to close". Measured on the reference
# consumer, where every entry filed after 2026-07-20 used this shape and the one entry that
# had adopted the verify: convention at all was invisible while upstream had already fixed it.
row_is "PC-FIXTURE-HEADING-ABSORBED"  CLOSE-CANDIDATE "heading entry, theirs has MARKER_B -> same verdict as Entry B"
row_is "PC-FIXTURE-HEADING-CLOSED"    ABSENT          "heading entry annotated ADOPTED UPSTREAM -> closed"
row_is "PC-FIXTURE-HEADING-NO-VERIFY" ABSENT          "heading opens an entry, so it ends the one above -> no inherited directive"

# The closer must NEVER exit nonzero — it is a classifier and a close never blocks apply.
ASSERTIONS=$((ASSERTIONS + 1))
bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  printf '  ok    %-22s exit 0  (classifier never blocks)\n' "exit-code"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s exit=%s want=0  (a close must never block apply)\n' "exit-code" "$rc"
fi

# A consumer with NO ledger: exit 0, no output.
ASSERTIONS=$((ASSERTIONS + 1))
empty="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" 2>&1)"
if [ -z "$empty" ]; then
  printf '  ok    %-22s silent  (no ledger -> nothing to re-verify)\n' "no-ledger"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s emitted output on a missing ledger\n' "no-ledger"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
