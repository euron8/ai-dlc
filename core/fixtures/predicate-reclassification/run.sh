#!/usr/bin/env bash
# predicate-reclassification — assert the pull reports when an incoming release re-renders the
# verdicts it has already given on the consumer's STORED artifacts.
#
# THE DEFECT. A release that moves an adjudication predicate reclassifies artifacts nobody
# touched. Every reconcile bucket is clean because every other detector compares TEXT, and this
# is not a text difference. Filed by the reference consumer as
# `PC-S307-PULL-CANNOT-SEE-WHAT-A-PREDICATE-CHANGE-RECLASSIFIES` after ai-dlc 0.442.0 flipped 33
# of its 105 stored adversarial series from pass to fail with the pull reporting nothing.
#
# THE ASSERTION THAT CARRIES THIS FILE IS PART 2, AND IT IS ABOUT *WHICH* SERIES. The offender
# and a near-miss sit in ONE corpus in ONE run, so the fixture can ask whether the row fires on
# the right series rather than merely whether it fires. A near-miss in a separate run cannot ask
# that question: in the run where the arm fires there is nothing present it should have stayed
# quiet about.
#
# PARTS 4-7 ARE THE FALSE-CLEAN GUARDS AND THEY ARE THE REASON THIS IS NOT A ONE-ARM FIXTURE.
# Every one of them is a state in which the detector produces NO reclassification row while
# having measured nothing at all — a corpus pattern that matches no file, a verdict grammar that
# matches no output, an unparsable manifest, an absent manifest. Each must report UNDECIDABLE.
# A detector that answered STABLE in any of them would be a check that cannot fire, reading
# exactly like one that passed. That is this repo's most-repeated defect and the exit-code
# spelling of this very detector shipped it once already: comparing exit codes over the real
# consumer corpus returned a clean, plausible ZERO because the probe cannot pass the predicate's
# mandatory `--transcript` and both sides therefore failed closed and identically.
#
# Exit: 0 = every assertion holds, 1 = something regressed, 2 = the harness could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SUBJ="$(pick "${1:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/predicate-differential.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/predicate-differential.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/predicate-differential.sh")"

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. The fixture arrives in one pull and the code it
# guards in the next, so an absent subject must SKIP LOUDLY rather than pass — a green run over
# a missing subject is the shape `consumer-boundary.md` names explicitly.
if [ -z "$SUBJ" ]; then
  echo "SKIP: predicate-differential.sh is not present in this tree yet (a core fixture ships ahead of its subject). Nothing was asserted."
  exit 0
fi

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"

BASE="$(git -C "$DIST" rev-list --max-parents=0 HEAD)"
MID="$(git -C "$DIST" rev-parse HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
[ -n "$BASE" ] && [ -n "$MID" ] && [ -n "$THEIRS" ] || { echo "FIXTURE ERROR: seeded refs unresolvable" >&2; exit 2; }

fails=0
# HERE-STRINGS, NEVER `printf | grep -q`. Under pipefail the pipeline reports the WRITER's
# status, so once the value exceeds the pipe buffer the test answers "not found" on input that
# contains the pattern -- permanently, and with no symptom. I54/I54b fail the push on the pipe
# form and caught all three of these on this file's first push.
ck() { # $1 label, $2 expected-substring, $3 actual
  if grep -qF "$2" <<<"$3"; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n  expected to find: %s\n  in: %s\n' "$1" "$2" "$3"; fails=$((fails + 1))
  fi
}
nk() { # negative: $2 must NOT appear
  if grep -qF "$2" <<<"$3"; then
    printf 'FAIL %s\n  must NOT contain: %s\n  in: %s\n' "$1" "$2" "$3"; fails=$((fails + 1))
  else
    printf 'ok   %s\n' "$1"
  fi
}

# The detector reads its manifest from beside itself, so each case gets its own copy of the
# script with its own manifest. It has no other sibling dependency.
mkrecon() { # $1 = manifest body (empty string = write no manifest at all)
  d="$ROOT/recon.$$.$RANDOM"; mkdir -p "$d"
  cp "$SUBJ" "$d/predicate-differential.sh"
  [ -n "$1" ] && printf '%s\n' "$1" > "$d/predicate-sites.md"
  printf '%s' "$d"
}

GOOD='predicate: core/scripts/toy-predicate.sh
corpus: *pass[0-9]*
series: s/pass[0-9]+.*$/pass/
invoke: --series {series}
verdict: s/^FAIL \(([A-Z]+) --.*/\1/p'

# ---- PART 1: the run itself is well-formed --------------------------------------------------
R="$(mkrecon "$GOOD")"
out="$(bash "$R/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'ok   1a exit is 0 (a classifier, never a gate)\n'
else
  printf 'FAIL 1a exit was %s, expected 0\n' "$rc"; fails=$((fails + 1))
fi
if [ -n "$out" ]; then
  printf 'ok   1b the run produced rows (an empty run asserts nothing)\n'
else
  printf 'FAIL 1b the run produced NO output at all\n'; fails=$((fails + 1))
fi

# ---- PART 2: THE LOAD-BEARING ARM — it fires, and on the RIGHT series ------------------------
ck "2a reports a reclassification when the predicate moves"      "PREDICATE-RECLASSIFIES" "$out"
ck "2b names the series that CROSSES the moved threshold"        "crossing-adversarial-pass" "$out"
nk "2c stays quiet about the near-miss BESIDE it in the same run" "steady-adversarial-pass" "$out"
ck "2d names the arm token that changed"                          "B" "$out"
ck "2e states the count is a FLOOR, not a count"                  "FLOOR" "$out"
nk "2f does NOT emit a blocking HARD- status"                     "HARD-" "$out"

# ---- PART 3: the two nulls are DIFFERENT answers and must not collapse -----------------------
# A range in which the predicate never moved, and a range in which it moved and nothing crossed.
# Both are STABLE; they are stable for different reasons and the row has to say which.
out_same="$(bash "$R/predicate-differential.sh" "$DIST" "$BASE" "$MID" "$CONS" 2>&1)"
ck "3a predicate untouched in range -> STABLE"        "PREDICATE-STABLE" "$out_same"
ck "3b and it says the sides were byte-identical"     "byte-identical" "$out_same"
nk "3c an unmoved predicate reports no reclassification" "PREDICATE-RECLASSIFIES" "$out_same"

# ---- PART 4: a corpus pattern that matches NOTHING is UNDECIDABLE, never clean ---------------
R4="$(mkrecon "$(printf '%s' "$GOOD" | sed 's|^corpus: .*|corpus: *zzznever[0-9]*|')")"
out4="$(bash "$R4/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
ck "4a corpus matching no file -> UNDECIDABLE" "PREDICATE-UNDECIDABLE" "$out4"
nk "4b and NOT stable"                          "PREDICATE-STABLE" "$out4"
# ASSERT THE DIAGNOSIS, NOT ONLY THE STATUS. A mutant deleting this guard still reports
# UNDECIDABLE, because the empty-grammar guard downstream catches the same input — two guards
# covering each other, where the verdict is right and the operator's remedy names the wrong
# subject. The status alone cannot tell them apart; the DETAIL can.
ck "4c and the row blames the CORPUS PATTERN, not the grammar" "matched NO stored artifact" "$out4"

# ---- PART 5: a verdict grammar that matches NOTHING is UNDECIDABLE ---------------------------
# The sharpest false clean: the predicate runs, the corpus is real, and the grammar cannot spell
# what it hunts — so every series scores as unchanged and the detector reports a confident zero.
R5="$(mkrecon "$(printf '%s' "$GOOD" | sed 's|^verdict: .*|verdict: s/^ZZZNEVER \\(([A-Z]+)\\).*/\\1/p|')")"
out5="$(bash "$R5/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
ck "5a verdict grammar matching nothing -> UNDECIDABLE" "PREDICATE-UNDECIDABLE" "$out5"
nk "5b and NOT stable"                                   "PREDICATE-STABLE" "$out5"

# ---- PART 6: an unparsable manifest is UNDECIDABLE ------------------------------------------
# A site missing its `verdict:` field cannot be compared. Scoring it zero would be a site that
# silently opts out of the check while the run still reads green.
R6="$(mkrecon "$(printf '%s' "$GOOD" | grep -v '^verdict:')")"
out6="$(bash "$R6/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
ck "6a a site with no verdict: field -> UNDECIDABLE" "PREDICATE-UNDECIDABLE" "$out6"
nk "6b and NOT stable"                               "PREDICATE-STABLE" "$out6"

# ---- PART 7: an ABSENT manifest is UNDECIDABLE ----------------------------------------------
R7="$(mkrecon "")"
out7="$(bash "$R7/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
ck "7a absent manifest -> UNDECIDABLE" "PREDICATE-UNDECIDABLE" "$out7"
nk "7b and NOT stable"                  "PREDICATE-STABLE" "$out7"
# Same two-guards-covering-each-other shape as 4c: with this guard deleted the empty-site-set
# guard below it still returns UNDECIDABLE, so only the diagnosis separates them.
ck "7c and the row blames the ABSENT manifest"    "manifest is absent" "$out7"

# ---- PART 8: a predicate ADDED by this pull is STABLE, not UNDECIDABLE -----------------------
# There is no prior verdict for a stored artifact to be reclassified against, so a first-time
# verdict is not a reclassification. Distinguishing this from an unreadable incoming side is the
# difference between a real answer and a harness artifact.
R8="$(mkrecon "$(printf '%s' "$GOOD" | sed 's|^predicate: .*|predicate: core/scripts/added-later.sh|')")"
out8="$(bash "$R8/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
ck "8a a predicate absent at BASE -> STABLE"    "PREDICATE-STABLE" "$out8"
ck "8b and it says the pull ADDS it"            "ADDS it" "$out8"
nk "8c not reported as a reclassification"      "PREDICATE-RECLASSIFIES" "$out8"

# ---- PART 9: the detector never blocks -------------------------------------------------------
for o in "$out" "$out4" "$out5" "$out6" "$out7" "$out8"; do
  grep -qF "HARD-" <<<"$o" && { echo "FAIL 9 a run emitted a blocking HARD- status"; fails=$((fails + 1)); }
done
printf 'ok   9 no run emits a blocking status\n'

if [ "$fails" -ne 0 ]; then
  printf '\n%s assertion(s) FAILED\n' "$fails"; exit 1
fi
printf '\nall assertions hold\n'
exit 0
