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
# THE MUTANT MATRIX. A cell is one expectation about the part-11 drive's output (11a the schema-only change is a
# reclassification, 11c the extension series moves [] -> [B], ran the toy predicate appears at all), RED on a
# mutant when the mutated engine's output no longer meets it. A mutant's row names the cell that kills it (decides)
# and the cell it could plausibly co-trip but must leave GREEN (twins). A plain run scores each mutant on its
# deciding cell and its twin only, off the one drive it already makes. The matrix is re-measured whenever an arm or
# a mutant is added or changed, by the REMEASURE command below, run from the repo root. It scores every mutant on
# every cell of the drive it ran on and prints one MATRIX line each. Three drives carry the mutants: part 11's
# (11a 11c ran), part 16's dist16 drive (UNDEC RECL PASSONLY SILENT0 DASH PARTIAL NONBARE BSILENT NOTETOK) and part 17's shipped
# gate-adjudication drive (GA GAran). No validator unit is selected here, so there is no outside-unit diff.
# MUTANT-MATRIX m-noroot decides=11a twins=ran
# MUTANT-MATRIX m-marker decides=11c twins=11a
# MUTANT-MATRIX m-silent decides=UNDEC twins=RECL
# MUTANT-MATRIX m-exitcode decides=SILENT0 twins=UNDEC
# MUTANT-MATRIX m-npassed decides=PASSONLY twins=UNDEC
# MUTANT-MATRIX m-dash decides=DASH twins=UNDEC
# MUTANT-MATRIX m-emptyout decides=UNDEC twins=SILENT0
# MUTANT-MATRIX m-index decides=NONBARE twins=UNDEC
# MUTANT-MATRIX m-py decides=GA twins=GAran
# MUTANT-MATRIX m-baseside decides=BSILENT twins=UNDEC
# MUTANT-MATRIX m-notesilent decides=NOTETOK twins=RECL
# MUTANT-MATRIX-REMEASURE bash core/fixtures/predicate-reclassification/run.sh --matrix
#
# Exit: 0 = every assertion holds, 1 = something regressed, 2 = the harness could not run.
set -uo pipefail
# MODE is "matrix" only under the positional `--matrix`; an AI_DLC_* name would be scrubbed below. Any other first
# argument is still the optional SUBJECT PATH (picked below), exactly as before.
MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix; shift ;;
esac

# HERMETIC (I87): the subject passes AI_DLC_KNOWN_SKILLS_EXT through when the caller set it, so an
# operator's tuning would otherwise decide part 11's extension cell.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF_FILE="$HERE/${0##*/}"

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
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/predicate-differential.sh"

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

# ok/bad for lib/mutant.sh: a kill is emitted only through mutant_killed, behind a same-run base-pass flag. `bad`
# increments the counter this file exits on. lib/ sits beside this directory (preamble.sh came from it).
ok()  { printf 'ok   %s\n' "${1-}"; }
bad() { printf 'FAIL %s\n' "${1-}"; fails=$((fails + 1)); }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: no lib/mutant.sh beside $HERE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB"

# The detector reads its manifest from beside itself, so each case gets its own copy of the
# script with its own manifest. It has no other sibling dependency.
mkrecon() { # $1 = manifest body (empty string = write no manifest at all)
  d="$ROOT/recon.$$.$RANDOM"; mkdir -p "$d"
  cp "$SUBJ" "$d/predicate-differential.sh"
  # The detector SOURCES consumer-read.sh from beside itself; a copy without it exits 2 at that line.
  cp "$(dirname "$SUBJ")/consumer-read.sh" "$d/consumer-read.sh"
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
if grep -qF "PREDICATE-RECLASSIFIES	toy-root-predicate.sh" <<<"$out11"; then
  printf 'ok   %s\n' "11a a schema-only change to a ROOT-resolving predicate is a reclassification"; B_11a=1
else
  printf 'FAIL %s\n  expected to find: %s\n  in: %s\n' "11a a schema-only change to a ROOT-resolving predicate is a reclassification" "PREDICATE-RECLASSIFIES	toy-root-predicate.sh" "$out11"; fails=$((fails + 1))
fi
ck "11b and the crossing series moves [] -> [B]" "verdict tokens [] -> [B,] under toy-root-predicate.sh" "$(row_of crossing-adversarial-pass "$out11")"
# THE EXTENSION CELL. The series names a skill only the CONSUMER's known-skills file lists. A side
# whose root is pinned to its probe root and is not handed that file searches the probe root, finds
# nothing, and fails it as unknown on BOTH sides -- [U] -> [B,U]. Only an explicit per-side value
# keeps it [] -> [B]. A walk-up marker alone cannot pass this cell.
if grep -qF "verdict tokens [] -> [B,] under toy-root-predicate.sh" <<<"$(row_of ext-adversarial-pass "$out11")"; then
  printf 'ok   %s\n' "11c the consumer's known-skills extension reaches both sides ([] -> [B], no U)"; B_11c=1
else
  printf 'FAIL %s\n  expected to find: %s\n  in: %s\n' "11c the consumer's known-skills extension reaches both sides ([] -> [B], no U)" "verdict tokens [] -> [B,] under toy-root-predicate.sh" "$(row_of ext-adversarial-pass "$out11")"; fails=$((fails + 1))
fi
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
# --- THE MATRIX CELLS, single-sourced. A cell is one expectation about a part-11 drive's output; cell_red <cell> <out>
# returns 0 RED (the expectation is NOT met), 1 GREEN, 2 UNKNOWN CELL (an unknown name must never read as GREEN).
#   11a  the schema-only change is reported as a reclassification of the root toy
#   11c  the extension series moves [] -> [B] under the root toy
#   ran  the root toy appears in the output at all (a mutant that never ran proves nothing)
#   UNDEC RECL PASSONLY SILENT0 DASH PARTIAL NONBARE BSILENT NOTETOK  part 16's cells, over one drive of dist16 (cell16)
#   GA    part 17: the shipped manifest's gate-adjudication site, BASE..MID over distga, is not STABLE
#   GAran part 17: that site produced a row at all (a mutant that never ran proves nothing)
# A mutant is scored in --matrix mode against the cells of the DRIVE it was run on (MX_DRIVE), never
# against another drive's cells, whose rows that output cannot carry.
MX_CELLS='11a 11c ran UNDEC RECL PASSONLY SILENT0 DASH PARTIAL NONBARE BSILENT NOTETOK GA GAran'
MX_DRIVE='11a 11c ran'
srow() { awk -F'\t' -v n="$1" '$2 == n { print; exit }' <<<"$2"; } # a site's SUMMARY row
cell16() { # cell16 <cell> <out>: 0 RED, 1 GREEN, 2 unknown
  local r t
  case "$1" in
    UNDEC|SILENT0|BSILENT)
      # GREEN: the site's row is UNDECIDABLE naming the silent side (incoming, or base for BSILENT), AND
      # no RECLASSIFIES row (summary or per-series, which names the site in its detail) mentions the site.
      local sd=incoming rf=$T16
      case "$1" in UNDEC) t=toy-undec.sh ;; SILENT0) t=toy-silent0.sh ;; BSILENT) t=toy-bsilent.sh; sd=base; rf=$B16 ;; esac
      r="$(srow "$t" "$2")"
      case "$r" in "PREDICATE-UNDECIDABLE	"*"the $sd side yielded no verdict on any series"*"no pass line at $rf)"*) ;; *) return 0 ;; esac
      awk -F'\t' -v t="$t" '$1 == "PREDICATE-RECLASSIFIES" && index($0, t) { f = 1 } END { exit !f }' <<<"$2" && return 0
      return 1 ;;
    RECL)     case "$(srow toy-recl.sh "$2")" in PREDICATE-RECLASSIFIES*) return 1 ;; esac; return 0 ;;
    PASSONLY) case "$(srow toy-passonly.sh "$2")" in PREDICATE-RECLASSIFIES*) return 1 ;; esac; return 0 ;;
    DASH)     case "$(srow toy-dash.sh "$2")" in PREDICATE-RECLASSIFIES*) return 1 ;; esac; return 0 ;;
    PARTIAL)  case "$(srow toy-partial.sh "$2")" in PREDICATE-RECLASSIFIES*) return 1 ;; esac; return 0 ;;
    NONBARE)  case "$(srow toy-nb.sh "$2")" in "PREDICATE-STABLE	"*"read-set moved"*) return 1 ;; esac; return 0 ;;
    NOTETOK)  case "$(srow toy-notetok.sh "$2")" in PREDICATE-RECLASSIFIES*) return 1 ;; esac; return 0 ;;
    *) return 2 ;;
  esac
}
cellga() { # cellga <cell> <out>: the shipped gate-adjudication site's summary row
  local r; r="$(srow validate-gate-adjudication.sh "$2")"
  case "$1" in
    GA)    case "$r" in "") return 0 ;; PREDICATE-STABLE*) return 0 ;; esac; return 1 ;;
    GAran) [ -z "$r" ] ;;
    GAU)   case "$r" in "PREDICATE-UNDECIDABLE	"*"the incoming side"*) return 1 ;; esac; return 0 ;;
    *) return 2 ;;
  esac
}
cell_red() {
  case "$1" in
    11a) ! grep -qF "PREDICATE-RECLASSIFIES	toy-root-predicate.sh" <<<"$2" ;;
    11c) ! grep -qF "verdict tokens [] -> [B,] under toy-root-predicate.sh" <<<"$(row_of ext-adversarial-pass "$2")" ;;
    ran) ! grep -qF 'toy-root-predicate.sh' <<<"$2" ;;
    UNDEC|RECL|PASSONLY|SILENT0|DASH|PARTIAL|NONBARE|BSILENT|NOTETOK) cell16 "$1" "$2" ;;
    GA|GAran) cellga "$1" "$2" ;;
    *) return 2 ;;
  esac
}
# The header IS the decides/twins list: nothing else in this file restates it.
mx_row() { # mx_row <mutant> <decides|twins>
  awk -v n="$1" -v f="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n {
      c++; for (i = 4; i <= NF; i++) if (index($i, f "=") == 1) v = substr($i, length(f) + 2)
    }
    END { if (c == 1) print v }' "$SELF_FILE"
}
MXL="$ROOT/mx.ledger"; : > "$MXL"
BROKEN=0; MX_FAILS=0
# mx_twins <mutant> <output>: per-push, every twin cell must stay GREEN on the SAME drive output the kill read.
mx_twins() {
  local m="$1" o="$2" tw t r
  tw="$(mx_row "$m" twins)"
  if [ -z "$tw" ]; then BROKEN=$((BROKEN + 1)); printf 'FIXTURE BROKEN %s: no single MUTANT-MATRIX row names its twins\n' "$m"; return; fi
  printf 'plain-twins %s\n' "$m" >> "$MXL"
  for t in $(printf '%s' "$tw" | tr ',' ' '); do
    cell_red "$t" "$o"; r=$?
    if [ "$r" -eq 2 ]; then BROKEN=$((BROKEN + 1)); printf 'FIXTURE BROKEN %s: twin %s names no cell\n' "$m" "$t"
    elif [ "$r" -eq 0 ]; then bad "$m: its twin $t also went RED on this mutant's output, so the kill is not confined to its own cell"; fi
  done
}
# mx_score <mutant> <output>: MATRIX-ONLY. Scores the mutant's drive output against EVERY cell. It records itself in
# the ledger first (rule 9).
mx_score() {
  local m="$1" o="$2" dec tw c dl="" tl="" uex="" g=0 tot=0
  printf 'mx-score %s\n' "$m" >> "$MXL"
  if grep -qE 'unbound variable|command not found|syntax error' <<<"$o"; then
    BROKEN=$((BROKEN + 1)); printf 'MATRIX BROKEN %s\n' "$m"; return
  fi
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  for c in $(printf '%s' "$dec" | tr ',' ' '); do
    if cell_red "$c" "$o"; then dl="$dl,$c:RED"; else dl="$dl,$c:GREEN"; uex="$uex $c:GREEN"; fi
  done
  for c in $(printf '%s' "$tw" | tr ',' ' '); do
    if cell_red "$c" "$o"; then tl="$tl,$c:RED"; uex="$uex $c:RED"; else tl="$tl,$c:GREEN"; fi
  done
  for c in $MX_DRIVE; do
    case ",$dec,$tw," in *",$c,"*) continue ;; esac
    tot=$((tot + 1)); cell_red "$c" "$o" || g=$((g + 1))
  done
  if [ -n "$uex" ]; then
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d UNEXPECTED=%s\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot" "$(printf '%s' "${uex# }" | tr ' ' ',')"
    MX_FAILS=$((MX_FAILS + 1))
  else
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot"
  fi
}
m_noroot="$(mut11 m-noroot "$PIN" 2 -e "s|$PIN||")"
m_marker="$(mut11 m-marker "$MK" 1 -e "s|$PIN||" -e "s|$EXTP||" -e "s|$MK|&; mkdir -p \"\$TMP/root-\$side/.claude\"|")"
if [ -z "$m_noroot" ] || [ -z "$m_marker" ]; then
  printf 'FAIL 11m a part-11 mutant could not be built, so its cell is unproven\n'; fails=$((fails + 1))
else
  mo="$(pd "$m_noroot/predicate-differential.sh" "$DIST" "$BASE" "$SCHEMA_ONLY" "$CONS")"
  mm="$(pd "$m_marker/predicate-differential.sh" "$DIST" "$BASE" "$SCHEMA_ONLY" "$CONS")"
  # Each mutant must fail its OWN cell and must have run (a positive row from the same run).
  if cell_red ran "$mo"; then
    printf 'FAIL 11f mutant [m-noroot] never ran: %s\n' "$(head -c 200 <<<"$mo")"; fails=$((fails + 1))
  elif cell_red 11a "$mo"; then
    mutant_killed "${B_11a:-0}" m-noroot "11f mutant [m-noroot] killed: without the per-side root pin the schema-only change reads $(cut -f1 <<<"$mo" | head -1)"
  else
    printf 'FAIL 11f mutant [m-noroot] SURVIVED: %s\n' "$(head -c 200 <<<"$mo")"; fails=$((fails + 1))
  fi
  mx_twins m-noroot "$mo"
  if [ "$MODE" = matrix ]; then mx_score m-noroot "$mo"; fi
  if ! cell_red 11a "$mm" && cell_red 11c "$mm"; then
    mutant_killed "${B_11c:-0}" m-marker "11g mutant [m-marker] killed: a walk-up marker finds the schema but loses the extension ($(row_of ext-adversarial-pass "$mm" | cut -f3 | cut -c1-40))"
  else
    printf 'FAIL 11g mutant [m-marker] SURVIVED or never ran: %s\n' "$(head -c 200 <<<"$mm")"; fails=$((fails + 1))
  fi
  mx_twins m-marker "$mm"
  if [ "$MODE" = matrix ]; then mx_score m-marker "$mm"; fi
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
# `pass: in-verdict`: the verdict grammar captures the PASS line as a token, so steady is COMPARED
# and only garbled is unclassified.
R13v="$(mkrecon "$(sed -e 's|^verdict: .*|pass: in-verdict\
verdict: s/^FAIL \\(([A-Z]+) --.*/\\1/p; s/^(PASS): .*/\\1/p|' <<<"$GOOD")")"
out13v="$(bash "$R13v/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
ck "13g a site whose verdict grammar spells PASS counts only the tokenless as unclassified" "records=5 series=5 compared=4 unclassified=1 (passes are verdict tokens)" "$out13v"

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

# ---- PART 16: A SIDE THAT NEVER SPOKE HAS NOT RENDERED A DIFFERENT VERDICT --------------------
# Measured on the reference consumer: gate_adjudication.py was missing from the gate-adjudication
# site's read-set, so the incoming side printed a NOTE and exited 2 on every series, and the row
# read "AT LEAST 14 of 14" RECLASSIFIES. Nine sites over seed.sh's dist16, scored off ONE drive:
#   UNDEC     mixed -> NOTE+exit 2 every series            UNDECIDABLE naming the incoming side
#   RECL      mixed -> FAIL every series                   RECLASSIFIES (a real one, not swallowed)
#   PASSONLY  FAIL every series -> PASS line every series  RECLASSIFIES (the pass line is speech)
#   SILENT0   mixed -> nothing, exit 0, every series       UNDECIDABLE (an exit 0 is not a verdict)
#   DASH      a `pass: -` site, mixed -> PASS every series RECLASSIFIES (the arm abstains there)
#   PARTIAL   mixed -> silent on alpha and beta, FAIL on gamma   RECLASSIFIES (silent on SOME series)
#   NONBARE   the read-set gains helper.py, absent from BASE's tree but in the non-bare dist's index
#             STABLE having run, never "could not materialize"
#   BSILENT   NOTE+exit 2 every series -> mixed           UNDECIDABLE naming the BASE side (the mirror of UNDEC)
#   NOTETOK   mixed -> a NOTE line AND a FAIL token every series   RECLASSIFIES (a warning is not silence)
# Every site but DASH declares a sed `pass:`, the shape whose pass line counts as a side speaking.
D16="$ROOT/dist16"; C16="$ROOT/consumer16"
B16="$(git -C "$D16" rev-list --max-parents=0 HEAD)"; T16="$(git -C "$D16" rev-parse HEAD)"
[ -n "$B16" ] && [ -n "$T16" ] && [ "$B16" != "$T16" ] || { echo "FIXTURE ERROR: dist16 refs unresolvable" >&2; exit 2; }
site16() { # site16 <toy file> <pass line, or empty for a fail-only site> [<extra read-set member>]
  printf 'reads: core/scripts/%s%s\nentry: core/scripts/%s\ncorpus: *pass[0-9]*\nseries: s/pass[0-9]+.*$/pass/\ninvoke: --series {series}\n' "$1" "${3:+ $3}" "$1"
  [ -z "$2" ] || printf 'pass: %s\n' "$2"
  printf 'verdict: s/^FAIL \\(([A-Z]+) --.*/\\1/p\n\n'
}
PL='s/^PASS: .*/PASS/p'
toy_of() { case "$1" in NONBARE) echo toy-nb.sh ;; *) printf 'toy-%s.sh\n' "$(tr 'A-Z' 'a-z' <<<"$1")" ;; esac; }
site_of() { # site_of <cell>... -> the manifest blocks for those cells' sites
  local c
  for c in "$@"; do
    case "$c" in
      DASH)    site16 toy-dash.sh "" ;;
      NONBARE) site16 toy-nb.sh "$PL" core/scripts/helper.py ;;
      *)       site16 "$(toy_of "$c")" "$PL" ;;
    esac
  done
}
C16_ALL='UNDEC RECL PASSONLY SILENT0 DASH PARTIAL NONBARE BSILENT NOTETOK'
# shellcheck disable=SC2086 -- a cell LIST
M16="$(site_of $C16_ALL)"
R16="$(mkrecon "$M16")"
out16="$(pd "$R16/predicate-differential.sh" "$D16" "$B16" "$T16" "$C16")"
# Controls: the dist is non-bare and its index holds the member BASE's tree lacks.
[ -d "$D16/.git" ] && [ -n "$(git -C "$D16" ls-files -- core/scripts/helper.py)" ] && [ -z "$(git -C "$D16" ls-tree --name-only "$B16" -- core/scripts/helper.py)" ] \
  && printf 'ok   16a control -- dist16 is non-bare, its index holds helper.py and BASE does not\n' \
  || { printf 'FAIL 16a the seed does not hold helper.py in the index only; NONBARE asserts nothing\n'; fails=$((fails + 1)); }
# One literal flag per cell, set beside its ok: validate-mutant-kills.sh M5 binds each kill's flag to it.
if cell16 UNDEC "$out16"; then bad "16-UNDEC a side silent on every series is not UNDECIDABLE: $out16"; else ok "16-UNDEC"; B_UNDEC=1; fi
if cell16 RECL "$out16"; then bad "16-RECL a real reclassification was not reported: $out16"; else ok "16-RECL"; fi
if cell16 PASSONLY "$out16"; then bad "16-PASSONLY a side printing only pass lines was read as silent: $out16"; else ok "16-PASSONLY"; B_PASSONLY=1; fi
if cell16 SILENT0 "$out16"; then bad "16-SILENT0 a side silent with exit 0 is not UNDECIDABLE: $out16"; else ok "16-SILENT0"; B_SILENT0=1; fi
if cell16 DASH "$out16"; then bad "16-DASH the arm fired on a pass: - site: $out16"; else ok "16-DASH"; B_DASH=1; fi
if cell16 PARTIAL "$out16"; then bad "16-PARTIAL a side silent on SOME series was read as silent: $out16"; else ok "16-PARTIAL"; fi
if cell16 NONBARE "$out16"; then bad "16-NONBARE the index of a non-bare dist leaked into the listing: $out16"; else ok "16-NONBARE"; B_NONBARE=1; fi
if cell16 BSILENT "$out16"; then bad "16-BSILENT a base side silent on every series is not UNDECIDABLE naming the base side: $out16"; else ok "16-BSILENT"; B_BSILENT=1; fi
if cell16 NOTETOK "$out16"; then bad "16-NOTETOK a side printing a NOTE line beside its verdict token was read as silent: $out16"; else ok "16-NOTETOK"; B_NOTETOK=1; fi

# ---- PART 17: THE SHIPPED MANIFEST'S GATE-ADJUDICATION SITE READS ITS MODULE -------------------
# Driven with the SHIPPED differential and the SHIPPED predicate-sites.md, found beside the subject
# (the consumer layout puts both under .claude/skills/ai-dlc-update/reconcile/), over seed.sh's
# distga, where only core/scripts/gate_adjudication.py moves. A manifest that leaves the module
# out of `reads:` materializes byte-identical sides and reads STABLE by construction.
#   GA   BASE -> MID, the module PASS -> FAIL      not STABLE (a reclassification)
#   GAU  BASE -> HEAD, the module no longer imports  UNDECIDABLE naming the incoming side
MAN="$(dirname "$SUBJ")/predicate-sites.md"
[ -f "$MAN" ] || { echo "predicate-reclassification: FIXTURE BROKEN: no predicate-sites.md beside $SUBJ" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/predicate-sites.md"
DG="$ROOT/distga"; CG="$ROOT/consga"
BG="$(git -C "$DG" rev-list --max-parents=0 HEAD)"; MG="$(git -C "$DG" rev-parse HEAD~1)"; TG="$(git -C "$DG" rev-parse HEAD)"
[ -n "$BG" ] && [ -n "$MG" ] && [ -n "$TG" ] || { echo "FIXTURE ERROR: distga refs unresolvable" >&2; exit 2; }
mkga() { d="$(mkrecon "")"; cp "$1" "$d/predicate-sites.md"; printf '%s' "$d"; }
RG="$(mkga "$MAN")"
outga="$(pd "$RG/predicate-differential.sh" "$DG" "$BG" "$MG" "$CG")"
outgu="$(pd "$RG/predicate-differential.sh" "$DG" "$BG" "$TG" "$CG")"
# Control: the entry is byte-identical across BASE..MID, so only the module can move the verdict.
[ "$(git -C "$DG" rev-parse "${BG}:core/scripts/validate-gate-adjudication.sh")" = "$(git -C "$DG" rev-parse "${MG}:core/scripts/validate-gate-adjudication.sh")" ] \
  && printf 'ok   17a control -- the entry is byte-identical across BASE..MID\n' \
  || { printf 'FAIL 17a the seed moved the entry; GA asserts nothing\n'; fails=$((fails + 1)); }
if cellga GA "$outga"; then printf 'FAIL 17-GA the module moving PASS -> FAIL is not compared\n  in: %s\n' "$(srow validate-gate-adjudication.sh "$outga")"; fails=$((fails + 1))
else ok "17-GA a gate_adjudication.py-only change is compared, not STABLE"; B_GA=1; fi
if cellga GAU "$outgu"; then printf 'FAIL 17-GAU a module that no longer imports is not UNDECIDABLE\n  in: %s\n' "$(srow validate-gate-adjudication.sh "$outgu")"; fails=$((fails + 1))
else printf 'ok   17-GAU a module that no longer imports is UNDECIDABLE naming the incoming side\n'; fi

# THE PART 16-17 MUTANTS. Each sed program is a file, so its text reaches sed verbatim.
cat > "$ROOT/m-silent.sed" <<'SED'
s/^    if \[ -n "\$pd_silent" \]; then$/    if false; then/
SED
cat > "$ROOT/m-exitcode.sed" <<'SED'
s/> "\$TMP\/out-base" 2>&1$/&; rc_b=$?/
s/> "\$TMP\/out-theirs" 2>&1$/&; rc_t=$?/
s/"\$rel" "\$sp_b" "\$sp_t"/"$rel" "$((rc_b == 0))" "$((rc_t == 0))"/
SED
cat > "$ROOT/m-npassed.sed" <<'SED'
s/'\$4!=0 {b=1} \$5!=0 {t=1}/-v np="$n_passed" '$4==1||np>0 {b=1} $5==1||np>0 {t=1}/
SED
cat > "$ROOT/m-dash.sed" <<'SED'
s/^  if \[ "\$P_PASS" != - \]; then$/  if true; then/
SED
cat > "$ROOT/m-emptyout.sed" <<'SED'
s/^    \[ -z "\$a_base" \] || sp_b=1$/    [ ! -s "$TMP\/out-base" ] || sp_b=1/
s/^    \[ -z "\$a_theirs" \] || sp_t=1$/    [ ! -s "$TMP\/out-theirs" ] || sp_t=1/
SED
cat > "$ROOT/m-index.sed" <<'SED'
s/GIT_INDEX_FILE="\$TMP\/no-index" //
SED
cat > "$ROOT/m-baseside.sed" <<'SED'
s/ else if (t \&\& !b) print "base"//
SED
cat > "$ROOT/m-notesilent.sed" <<'SED'
s/^    \[ -z "\$a_base" \] || sp_b=1$/&; ! grep -q "^NOTE" "$TMP\/out-base" || sp_b=0/
s/^    \[ -z "\$a_theirs" \] || sp_t=1$/&; ! grep -q "^NOTE" "$TMP\/out-theirs" || sp_t=0/
SED
cat > "$ROOT/m-py.sed" <<'SED'
/^reads: core\/scripts\/validate-gate-adjudication\.sh /s/ core\/scripts\/gate_adjudication\.py//
SED
# mut16 <name> <file> <anchor> <want-hits> -> the mutant dir (part-16 manifest), or nothing
mut16() {
  local n="$1" f="$2" a="$3" w="$4" h d
  h="$(grep -c -e "$a" "$f")" || h=0
  [ "$h" -eq "$w" ] || { printf 'FAIL 16m MUTANT STALE [%s]: anchor matches %s lines, not %s\n' "$n" "$h" "$w" >&2; return 1; }
  if [ "$n" = m-py ]; then d="$(mkga "$MAN")"; sed -f "$ROOT/$n.sed" "$MAN" > "$d/predicate-sites.md" || return 1
    cmp -s "$MAN" "$d/predicate-sites.md" && { printf 'FAIL 16m MUTANT DID NOT APPLY [%s]\n' "$n" >&2; return 1; }
  else
    # A PLAIN run drives only the mutant's deciding site and its twins (clause 2); --matrix drives every site.
    if [ "$MODE" = matrix ]; then d="$(mkrecon "$M16")"
    else d="$(mkrecon "$(site_of $(tr ',' ' ' <<<"$(mx_row "$n" decides),$(mx_row "$n" twins)"))")"; fi
    sed -f "$ROOT/$n.sed" "$SUBJ" > "$d/predicate-differential.sh" || return 1
    cmp -s "$SUBJ" "$d/predicate-differential.sh" && { printf 'FAIL 16m MUTANT DID NOT APPLY [%s]\n' "$n" >&2; return 1; }
    bash -n "$d/predicate-differential.sh" 2>/dev/null || { printf 'FAIL 16m MUTANT DOES NOT PARSE [%s]\n' "$n" >&2; return 1; }
  fi
  [ -f "$d/consumer-read.sh" ] || return 1
  printf '%s' "$d"
}
# run16 <mutant> <deciding cell> <anchor> <want-hits>: build, drive, and score the twins (and the matrix
# under --matrix). Returns 0 when the deciding cell went RED, so the caller emits the kill with a literal
# name and the cell's own flag; 1 after reporting a mutant that SURVIVED, never ran, or could not be built.
run16() {
  local mn="$1" mc="$2" mf=$SUBJ md mo mt
  [ "$mn" = m-py ] && mf="$MAN"
  md="$(mut16 "$mn" "$mf" "$3" "$4")"
  if [ -z "$md" ]; then bad "16m mutant [$mn] could not be built, so its cell is unproven"; return 1; fi
  if [ "$mn" = m-py ]; then mo="$(pd "$md/predicate-differential.sh" "$DG" "$BG" "$MG" "$CG")"
  else mo="$(pd "$md/predicate-differential.sh" "$D16" "$B16" "$T16" "$C16")"; fi
  # It ran: the deciding cell's site has a summary row in the mutant's output.
  [ "$mn" = m-py ] && mt=validate-gate-adjudication.sh || mt="$(toy_of "$mc")"
  if [ -z "$(srow "$mt" "$mo")" ]; then bad "16m mutant [$mn] never ran: $(head -c 200 <<<"$mo")"; return 1; fi
  mx_twins "$mn" "$mo"
  [ "$mn" = m-py ] && MX_DRIVE='GA GAran' || MX_DRIVE='UNDEC RECL PASSONLY SILENT0 DASH PARTIAL NONBARE BSILENT NOTETOK'
  if [ "$MODE" = matrix ]; then mx_score "$mn" "$mo"; fi
  cell_red "$mc" "$mo" && return 0
  bad "16m mutant [$mn] SURVIVED on $mc"; return 1
}
run16 m-silent UNDEC '^    if \[ -n "\$pd_silent" \]; then$' 1 \
  && mutant_killed "${B_UNDEC:-0}" m-silent "16m mutant [m-silent] killed by UNDEC"
run16 m-exitcode SILENT0 '"\$rel" "\$sp_b" "\$sp_t"' 1 \
  && mutant_killed "${B_SILENT0:-0}" m-exitcode "16m mutant [m-exitcode] killed by SILENT0"
run16 m-npassed PASSONLY '\$4!=0 {b=1} \$5!=0 {t=1}' 1 \
  && mutant_killed "${B_PASSONLY:-0}" m-npassed "16m mutant [m-npassed] killed by PASSONLY"
run16 m-dash DASH '^  if \[ "\$P_PASS" != - \]; then$' 1 \
  && mutant_killed "${B_DASH:-0}" m-dash "16m mutant [m-dash] killed by DASH"
run16 m-emptyout UNDEC '\[ -z "\$a_[bt][a-z]*" \] || sp_[bt]=1$' 2 \
  && mutant_killed "${B_UNDEC:-0}" m-emptyout "16m mutant [m-emptyout] killed by UNDEC"
run16 m-index NONBARE 'GIT_INDEX_FILE="\$TMP/no-index" ' 1 \
  && mutant_killed "${B_NONBARE:-0}" m-index "16m mutant [m-index] killed by NONBARE"
run16 m-baseside BSILENT ' else if (t && !b) print "base"' 1 \
  && mutant_killed "${B_BSILENT:-0}" m-baseside "16m mutant [m-baseside] killed by BSILENT"
run16 m-notesilent NOTETOK '\[ -z "\$a_[bt][a-z]*" \] || sp_[bt]=1$' 2 \
  && mutant_killed "${B_NOTETOK:-0}" m-notesilent "16m mutant [m-notesilent] killed by NOTETOK"
run16 m-py GA '^reads: core/scripts/validate-gate-adjudication\.sh .*core/scripts/gate_adjudication\.py' 1 \
  && mutant_killed "${B_GA:-0}" m-py "16m mutant [m-py] killed by GA"

# RULE 9: a plain run executes NO matrix-only cell. Every matrix-only score appends `mx-score` to the ledger before
# anything else; the per-push twin check appends `plain-twins` to the SAME ledger. That second line is the CONTROL:
# it must be present, so a zero count of matrix-only cells cannot come from a ledger nothing writes.
mx_only="$(grep -c '^mx-score ' "$MXL")" || mx_only=0
mx_ctl="$(grep -c '^plain-twins ' "$MXL")" || mx_ctl=0
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9 the matrix ledger control is EMPTY, so a zero count of matrix-only cells would mean nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9 a plain run executed $mx_only matrix-only cell(s), so the --matrix measurement leaked into the per-push run"
  else ok "rule-9 a plain run executed no matrix-only cell, while its $mx_ctl per-push twin check(s) wrote to the same ledger"; fi
else
  mx_hdr="$(awk '$1 == "#" && $2 == "MUTANT-MATRIX" { print $3 }' "$SELF_FILE" | LC_ALL=C sort | tr '\n' ' ')"
  [ "$mx_hdr" = "m-baseside m-dash m-emptyout m-exitcode m-index m-marker m-noroot m-notesilent m-npassed m-py m-silent " ] || { BROKEN=$((BROKEN + 1)); echo "MATRIX BROKEN: the header rows are [$mx_hdr]"; }
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran, $mx_ctl per-push twin check(s)"
  fails=$((fails + MX_FAILS))
fi
if [ "$BROKEN" -ne 0 ]; then echo "predicate-reclassification: FIXTURE BROKEN: $BROKEN mutant arm(s) could not be scored" >&2; exit 2; fi

if [ "$fails" -ne 0 ]; then
  printf '\n%s assertion(s) FAILED\n' "$fails"; exit 1
fi
printf '\nall assertions hold\n'
exit 0
