#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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

# HERMETIC (I87): the subject passes AI_DLC_KNOWN_SKILLS_EXT through when the caller set it, so an
# operator's tuning would otherwise decide part 11's extension cell.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

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
MID="$(git -C "$DIST" rev-parse HEAD~2)"
SCHEMA_ONLY="$(git -C "$DIST" rev-parse HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
[ -n "$BASE" ] && [ -n "$MID" ] && [ -n "$SCHEMA_ONLY" ] && [ -n "$THEIRS" ] || { echo "FIXTURE ERROR: seeded refs unresolvable" >&2; exit 2; }

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

GOOD='reads: core/scripts/toy-predicate.sh
entry: core/scripts/toy-predicate.sh
corpus: *pass[0-9]*
series: s/pass[0-9]+.*$/pass/
invoke: --series {series}
verdict: s/^FAIL \(([A-Z]+) --.*/\1/p'

# The schema-backed site: the script is byte-identical across the schema-only commit, so this
# site is the one that separates a read-set differential from a script differential.
SCHEMA_SITE='reads: core/scripts/toy-schema-predicate.sh core/schemas/toy-schema.yaml
entry: core/scripts/toy-schema-predicate.sh
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
R8="$(mkrecon "$(printf '%s' "$GOOD" | sed 's|^reads: .*|reads: core/scripts/added-later.sh|; s|^entry: .*|entry: core/scripts/added-later.sh|')")"
out8="$(bash "$R8/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
ck "8a a predicate absent at BASE -> STABLE"    "PREDICATE-STABLE" "$out8"
ck "8b and it says the pull ADDS it"            "ADDS it" "$out8"
nk "8c not reported as a reclassification"      "PREDICATE-RECLASSIFIES" "$out8"

# ---- PART 9: the detector never blocks -------------------------------------------------------
for o in "$out" "$out4" "$out5" "$out6" "$out7" "$out8"; do
  grep -qF "HARD-" <<<"$o" && { echo "FAIL 9 a run emitted a blocking HARD- status"; fails=$((fails + 1)); }
done
printf 'ok   9 no run emits a blocking status\n'

# ---- PART 10: A SCHEMA-ONLY CHANGE IS A PREDICATE CHANGE ------------------------------------
# THE ARM THAT SEPARATES A READ-SET DIFFERENTIAL FROM A SCRIPT DIFFERENTIAL. Across
# BASE..SCHEMA_ONLY the toy schema predicate's SCRIPT is byte-identical and only its schema
# moved -- the v0.382.0 shape, where provenance-block.json changed and
# validate-provenance-block.sh did not. A detector comparing scripts reports STABLE here by
# construction, never by measurement, which is the exact false clean this whole file exists for.
R10="$(mkrecon "$SCHEMA_SITE")"
out10="$(bash "$R10/predicate-differential.sh" "$DIST" "$BASE" "$SCHEMA_ONLY" "$CONS" 2>&1)"
# The control that makes the row readable: the ENTRY script really is byte-identical, so a
# STABLE verdict here could only have come from comparing the wrong subject.
sb="$(git -C "$DIST" show "${BASE}:core/scripts/toy-schema-predicate.sh" | md5 -q)"
st="$(git -C "$DIST" show "${SCHEMA_ONLY}:core/scripts/toy-schema-predicate.sh" | md5 -q)"
if [ "$sb" = "$st" ]; then
  printf 'ok   10a control -- the entry script IS byte-identical across the schema-only commit\n'
else
  printf 'FAIL 10a the seed did not hold the script identical; part 10 asserts nothing\n'; fails=$((fails + 1))
fi
ck "10b a SCHEMA-only change is reported as a reclassification" "PREDICATE-RECLASSIFIES" "$out10"
nk "10c and NOT as byte-identical/stable"                       "PREDICATE-STABLE" "$out10"
ck "10d the crossing series is named"                           "crossing-adversarial-pass" "$out10"

# ---- PART 11: A PREDICATE THAT FINDS ITS SCHEMA UNDER ITS PROJECT ROOT ------------------------
# The real schema-backed validators resolve the schema under a PROJECT ROOT, never beside
# themselves, and the probe root carries no marker. With the cwd at the consumer, an unpinned
# side walks up from the cwd and reads the consumer's INSTALLED schema (seeded at the base
# ceiling) on BOTH sides, so a schema-only change compares one schema with itself and reads
# STABLE. Every run here clears the two inherited roots first, so the cell measures the engine.
ROOT_SITE='reads: core/scripts/toy-root-predicate.sh core/schemas/toy-schema.yaml
entry: core/scripts/toy-root-predicate.sh
corpus: *pass[0-9]*
series: s/pass[0-9]+.*$/pass/
invoke: --series {series}
verdict: s/^FAIL \(([A-Z]+) --.*/\1/p'
pd() { env -u CLAUDE_PROJECT_DIR -u AI_DLC_PROJECT_ROOT -u AI_DLC_KNOWN_SKILLS_EXT bash "$@" 2>&1; }
row_of() { grep -F "$1" <<<"$2" | grep -v '^PREDICATE-[A-Z]*	toy' | head -1; }
R11="$(mkrecon "$ROOT_SITE")"
out11="$(pd "$R11/predicate-differential.sh" "$DIST" "$BASE" "$SCHEMA_ONLY" "$CONS")"
ck "11a a schema-only change to a ROOT-resolving predicate is a reclassification" "PREDICATE-RECLASSIFIES	toy-root-predicate.sh" "$out11"
ck "11b and the crossing series moves [] -> [B]" "verdict tokens [] -> [B,] under toy-root-predicate.sh" "$(row_of crossing-adversarial-pass "$out11")"
# THE EXTENSION CELL. The series names a skill only the CONSUMER's known-skills file lists. A side
# whose root is pinned to its probe root and is not handed that file searches the probe root, finds
# nothing, and fails it as unknown on BOTH sides -- [U] -> [B,U]. Only an explicit per-side value
# keeps it [] -> [B]. A walk-up marker alone cannot pass this cell.
ck "11c the consumer's known-skills extension reaches both sides ([] -> [B], no U)" "verdict tokens [] -> [B,] under toy-root-predicate.sh" "$(row_of ext-adversarial-pass "$out11")"
# AN INHERITED ROOT MUST NOT WIN. The pull may run with AI_DLC_PROJECT_ROOT naming the consumer;
# a root found by a walk-up marker loses to that variable, so only a per-side pin survives it.
out11i="$(env -u CLAUDE_PROJECT_DIR AI_DLC_PROJECT_ROOT="$CONS" bash "$R11/predicate-differential.sh" "$DIST" "$BASE" "$SCHEMA_ONLY" "$CONS" 2>&1)"
ck "11d an inherited AI_DLC_PROJECT_ROOT naming the consumer does not pin both sides" "PREDICATE-RECLASSIFIES	toy-root-predicate.sh" "$out11i"
# Control: the root toy really is byte-identical across the schema-only commit.
rb="$(git -C "$DIST" show "${BASE}:core/scripts/toy-root-predicate.sh" | md5 -q)"
rt="$(git -C "$DIST" show "${SCHEMA_ONLY}:core/scripts/toy-root-predicate.sh" | md5 -q)"
[ "$rb" = "$rt" ] && printf 'ok   11e control -- toy-root-predicate.sh IS byte-identical across the schema-only commit\n' \
  || { printf 'FAIL 11e the root toy moved across the schema-only commit; part 11 asserts nothing\n'; fails=$((fails + 1)); }

# THE COMMITTED MUTANTS. Each is a copy of the engine, guarded by an anchor count and `cmp -s`.
#   m-noroot  deletes the per-side AI_DLC_PROJECT_ROOT pin          -> must fail 11a
#   m-marker  deletes both per-side values and gives each probe root a `.claude/` walk-up marker
#             instead -- the fix BL-410's note warns against      -> must fail 11c
mut11() { # mut11 <name> <anchor> <want-hits> <sed-args...> -> prints the mutant dir, or nothing
  local n="$1" a="$2" w="$3" h d; shift 3
  h="$(grep -c -e "$a" "$SUBJ")" || h=0
  [ "$h" -eq "$w" ] || { printf 'FAIL 11m MUTANT STALE [%s]: anchor matches %s lines, not %s -- re-anchor on the same site\n' "$n" "$h" "$w" >&2; return 1; }
  d="$(mkrecon "$ROOT_SITE")"
  sed "$@" "$SUBJ" > "$d/predicate-differential.sh" || return 1
  cmp -s "$SUBJ" "$d/predicate-differential.sh" && { printf 'FAIL 11m MUTANT DID NOT APPLY [%s]\n' "$n" >&2; return 1; }
  bash -n "$d/predicate-differential.sh" 2>/dev/null || return 1
  printf '%s' "$d"
}
PIN='AI_DLC_PROJECT_ROOT="\$TMP/root-[a-z]*" '
EXTP='AI_DLC_KNOWN_SKILLS_EXT="\$PD_EXT" '
MK='rm -rf "\$TMP/root-\$side"; mkdir -p "\$TMP/root-\$side"$'
m_noroot="$(mut11 m-noroot "$PIN" 2 -e "s|$PIN||")"
m_marker="$(mut11 m-marker "$MK" 1 -e "s|$PIN||" -e "s|$EXTP||" -e "s|$MK|&; mkdir -p \"\$TMP/root-\$side/.claude\"|")"
if [ -z "$m_noroot" ] || [ -z "$m_marker" ]; then
  printf 'FAIL 11m a part-11 mutant could not be built, so its cell is unproven\n'; fails=$((fails + 1))
else
  mo="$(pd "$m_noroot/predicate-differential.sh" "$DIST" "$BASE" "$SCHEMA_ONLY" "$CONS")"
  mm="$(pd "$m_marker/predicate-differential.sh" "$DIST" "$BASE" "$SCHEMA_ONLY" "$CONS")"
  # Each mutant must fail its OWN cell and must have run (a positive row from the same run).
  if grep -qF 'toy-root-predicate.sh' <<<"$mo" && ! grep -qF 'PREDICATE-RECLASSIFIES	toy-root-predicate.sh' <<<"$mo"; then
    printf 'ok   11f mutant [m-noroot] KILLED: without the per-side root pin the schema-only change reads %s\n' "$(cut -f1 <<<"$mo" | head -1)"
  else
    printf 'FAIL 11f mutant [m-noroot] SURVIVED or never ran: %s\n' "$(head -c 200 <<<"$mo")"; fails=$((fails + 1))
  fi
  if grep -qF 'PREDICATE-RECLASSIFIES	toy-root-predicate.sh' <<<"$mm" \
     && ! grep -qF 'verdict tokens [] -> [B,] under toy-root-predicate.sh' <<<"$(row_of ext-adversarial-pass "$mm")"; then
    printf 'ok   11g mutant [m-marker] KILLED: a walk-up marker finds the schema but loses the extension (%s)\n' "$(row_of ext-adversarial-pass "$mm" | cut -f3 | cut -c1-40)"
  else
    printf 'FAIL 11g mutant [m-marker] SURVIVED or never ran: %s\n' "$(head -c 200 <<<"$mm")"; fails=$((fails + 1))
  fi
fi

# ---- PART 12: A STORED SUBJECT OUTSIDE _bmad-output/ IS REACHABLE BY `corpus-root:` -----------
# The suppression-lifetime site's subject is docs/escalations/pending.md. Without the field the
# site cannot see it and reports UNDECIDABLE on every consumer that has the file.
ESC_SITE='reads: core/scripts/toy-predicate.sh
entry: core/scripts/toy-predicate.sh
corpus-root: docs/escalations
corpus: pending-pass[0-9]*
series: s/pass[0-9]+.*$/pass/
invoke: --series {series}
verdict: s/^FAIL \(([A-Z]+) --.*/\1/p'
R12="$(mkrecon "$ESC_SITE")"
out12="$(pd "$R12/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS")"
ck "12a a corpus-root outside _bmad-output is compared, not UNDECIDABLE" "PREDICATE-RECLASSIFIES	toy-predicate.sh" "$out12"
ck "12b and the series under docs/escalations is named"                  "docs/escalations/pending-pass" "$out12"
R12n="$(mkrecon "$(grep -v '^corpus-root:' <<<"$ESC_SITE")")"
out12n="$(pd "$R12n/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS")"
ck "12c the same site WITHOUT the field still searches _bmad-output (the default is unchanged)" "matched NO stored artifact under $CONS/_bmad-output." "$out12n"

# ---- PART 13: EVERY ROW CARRIES ITS POPULATION AND ITS COUNTS ---------------------------------
# A figure a second party cannot re-derive is not a measurement. The counts are exact for the
# seed: five records and five series; crossing, always and ext yield a token on some side; steady
# prints the PASS line on both sides; garbled prints neither. Values are backticked so a glob is
# code in a markdown report, so the expected strings are single-quoted.
ck "13a a RECLASSIFIES summary names its population" 'population: root=`_bmad-output` corpus=`*pass[0-9]*` series=`s/pass[0-9]+.*$/pass/`' "$out"
# A SITE WITH NO `pass:` CANNOT TELL A PASS FROM AN UNPARSEABLE OUTPUT, AND SAYS SO.
ck "13b a fail-only grammar prints unclassified as n/a, not a number" "records=5 series=5 compared=3 unclassified=n/a (grammar spells failures only)" "$out"
ck "13c a byte-identical STABLE row names its population" 'population: root=`_bmad-output` corpus=`*pass[0-9]*`' "$out_same"
ck "13d an UNDECIDABLE-for-no-corpus row says records=0"  "records=0" "$out4"
# A SITE DECLARING `pass:` SPLITS THE TOKENLESS SERIES: steady passed, garbled unclassified.
R13="$(mkrecon "$(sed 's|^verdict: |pass: s/^PASS: .*/PASS/p\
verdict: |' <<<"$GOOD")")"
out13="$(bash "$R13/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
ck "13e a site with pass: counts passed and unclassified separately" "records=5 series=5 compared=3 passed=1 unclassified=1" "$out13"
nk "13f and does not print n/a"                                       "unclassified=n/a" "$out13"

# ---- PART 14: A NON-ASCII READ-SET MEMBER MATERIALIZES -----------------------------------------
# Listed under the default core.quotePath, `core/schemas/café.yaml` arrives C-quoted, `git show`
# is handed a path that names nothing, and the whole site reads as unmaterializable.
CAFE_SITE="$(sed 's|^reads: .*|reads: core/scripts/toy-predicate.sh core/schemas/café.yaml|' <<<"$GOOD")"
R14="$(mkrecon "$CAFE_SITE")"
out14="$(pd "$R14/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS")"
[ -n "$(git -C "$DIST" -c core.quotePath=false ls-files -- 'core/schemas/caf*' | grep -F 'café')" ] \
  && printf 'ok   14a control -- the seed tracks core/schemas/café.yaml under its raw name\n' \
  || { printf 'FAIL 14a the seed does not track café.yaml; part 14 asserts nothing\n'; fails=$((fails + 1)); }
nk "14b a non-ASCII member does not make the side unmaterializable" "could not materialize" "$out14"
ck "14c the site is compared"                                       "PREDICATE-RECLASSIFIES	toy-predicate.sh" "$out14"

# ---- PART 15: A corpus-root THAT COULD LEAVE THE CONSUMER OR SPLIT THE ROW IS REFUSED ------------
# Each refused shape reports UNDECIDABLE naming the field. The near-miss `docs/..x` holds two dots
# that are not a parent component, so it is NOT refused: it reaches the corpus search and fails
# there, for the ordinary reason.
for c15 in 'a:../outside' 'b:/etc' 'c:docs/esc alations'; do
  R15="$(mkrecon "$(sed "s|^corpus-root: .*|corpus-root: ${c15#*:}|" <<<"$ESC_SITE")")"
  o15="$(pd "$R15/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS")"
  ck "15${c15%%:*} corpus-root '${c15#*:}' is refused, naming the field" "PREDICATE-UNDECIDABLE	toy-predicate.sh	the site's corpus-root: value is refused" "$o15"
done
R15n="$(mkrecon "$(sed 's|^corpus-root: .*|corpus-root: docs/..x|' <<<"$ESC_SITE")")"
o15n="$(pd "$R15n/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS")"
nk "15d near-miss 'docs/..x' is not refused"                 "corpus-root: value is refused" "$o15n"
ck "15e and it reaches the corpus search"                    "matched NO stored artifact under $CONS/docs/..x." "$o15n"

if [ "$fails" -ne 0 ]; then
  printf '\n%s assertion(s) FAILED\n' "$fails"; exit 1
fi
printf '\nall assertions hold\n'
exit 0
