#!/usr/bin/env bash
# validate-artifact-paths.sh — hold a CONSUMER's real filenames to the declared path grammar.
#
#   validate-artifact-paths.sh [--root <dir>] [--grammar <file>] [--report]
#
# WHAT IT IS FOR, and what it is NOT. `validate-enforcement-map.sh` I82 holds core's own
# PRESCRIPTIONS to `artifact-path-grammar.md`; `migrate-artifact-paths.sh` moves a consumer's
# tree onto it once. Neither of them stops the tree drifting back off it the next sprint, and a
# convention with a one-time migration behind it is a convention with a half-life. This is the
# standing arm: it reads REAL tracked filenames, every push.
#
# THE GRAMMAR ITSELF SAYS THIS READER IS THE ONE THAT CAN SEE WHAT I82 CANNOT. A prescription
# is written with placeholders, so `story-<id>-<slug>.md` conforms syntactically while every
# expansion of it carries a sprint number inside `<id>`. Only a reader looking at expanded
# filenames can tell.
#
# ---------------------------------------------------------------------------------------------
# WHAT BLOCKS A PUSH, AND WHY IT IS NOT "EVERY NON-CONFORMING PATH". Measured on the reference
# consumer the day this shipped, immediately after the migration ran for real:
#
#     paths the migration would still MOVE            0     <- what this arm blocks on
#     REFUSED by the migration, still non-conforming  48     45 ambiguous, 3 with no area
#     under a stories/ directory, DEFERRED             1024
#
# Blocking on all 1072 would wedge first contact on a tree whose operator has already done
# everything core asked of them -- and the stories deferral is CORE's own decision, taken in
# `migrate-artifact-paths.sh` because the sprint is spelled two ways there and one of them is a
# bare number this grammar's own story form uses for the story index. The release that moves
# `stories/` under `s<N>/` is what removes it. A gate that fires on a tree nobody can clean is a
# gate the operator turns off, and then nothing is enforced at all.
#
# So the blocking set is exactly THE SET THE MIGRATION WOULD MOVE: non-conforming, unambiguous,
# with a derivable area, outside `stories/`. That set is empty on a migrated tree and grows the
# moment a sprint writes `s302-foo.md` at an area root -- which is the regrowth this exists to
# stop. Its remedy is one command.
#
# NOTHING IS EXEMPTED BY A LIST. Every non-blocking class is COMPUTED from the path itself, so
# it cannot go stale, cannot be added to by hand, and leaves the class the instant the
# obstruction is removed -- an ambiguous name the operator renames blocks the next push if they
# rename it wrong. A declared exemption ledger is the shape this repo keeps finding defects in;
# there is no list here to fall out of date.
#
# EVERY NON-BLOCKING CLASS IS STILL PRINTED, with its count and its reason. Silence about 1072
# non-conforming files would be this repo's own named defect one layer out.
# ---------------------------------------------------------------------------------------------
#
# --report adds the census -- per-class counts by area, and the story-corpus spelling split that
# the deferral turns on. It does NOT change the verdict or the exit code, deliberately: a
# reporting flag that also relaxes the gate is a gate with an off switch in its own usage line.
#
# Exit codes:
#   0  -- no blocking finding (including NOT-APPLICABLE: nothing tracked under any scan root)
#   1  -- at least one blocking finding
#   2  -- usage error, or the grammar/areas/scan-roots could not be resolved
set -uo pipefail

PROG="validate-artifact-paths.sh"
ROOT="."
GRAMMAR_ARG=""
REPORT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --report) REPORT=1; shift ;;
    --root)   ROOT="${2:-}"; [ -n "$ROOT" ] || { echo "$PROG: --root needs a directory" >&2; exit 2; }; shift 2 ;;
    --grammar) GRAMMAR_ARG="${2:-}"; [ -n "$GRAMMAR_ARG" ] || { echo "$PROG: --grammar needs a file" >&2; exit 2; }; shift 2 ;;
    -h|--help) sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "$PROG: unknown option '$1'" >&2
       echo "usage: $PROG [--root <dir>] [--grammar <file>] [--report]" >&2
       exit 2 ;;
  esac
done

# BESIDE THIS SCRIPT, never located by walking up from it. install.sh splits what shares a
# parent in this repo (`core/scripts/<x>` -> `scripts/ai-dlc/<x>`), and I33 fails the build on a
# core file reached by walking up from another.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SELF_DIR/artifact-path-config.sh"
[ -f "$CONFIG" ] || { echo "$PROG: no artifact-path-config.sh beside this script at '$CONFIG'." >&2
                      echo "  It is the single home of the scan roots, the areas and the sprint-token" >&2
                      echo "  expression. Without it this would have to guess all three, and a guessed" >&2
                      echo "  empty root set reports a fully-conforming tree without reading a file." >&2
                      exit 2; }

# Resolve --grammar before the cd, for the reason migrate-artifact-paths.sh states: it is the
# caller's path, relative to where they are standing.
if [ -n "$GRAMMAR_ARG" ]; then
  case "$GRAMMAR_ARG" in /*) : ;; *) GRAMMAR_ARG="$(pwd)/$GRAMMAR_ARG" ;; esac
fi

[ -d "$ROOT" ] || { echo "$PROG: not a directory: $ROOT" >&2; exit 2; }
cd "$ROOT" || exit 2
ROOT_ABS="$(pwd)"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "$PROG: $ROOT_ABS is not a git work tree. The subject is the TRACKED artifact set;" >&2
       echo "  scanning the filesystem instead would judge build output and scratch files the" >&2
       echo "  grammar never governed." >&2; exit 2; }

cfg() { # <mode> -> the resolver's answer, or die with its own message
  local out rc
  if [ -n "$GRAMMAR_ARG" ]; then out="$(bash "$CONFIG" "$1" --grammar "$GRAMMAR_ARG" 2>&1)"; rc=$?
  else                           out="$(bash "$CONFIG" "$1" 2>&1)"; rc=$?; fi
  if [ "$rc" -ne 0 ]; then
    echo "$PROG: artifact-path-config.sh $1 failed (rc=$rc):" >&2
    printf '%s\n' "$out" >&2
    exit 2
  fi
  printf '%s\n' "$out"
}

GRAMMAR="$(cfg --grammar-file)"
SCAN_ROOTS="$(cfg --scan-roots)"
AREAS="$(cfg --areas)"
TOKEN_RE="$(cfg --token-re)"

N_AREAS="$(printf '%s\n' "$AREAS" | grep -c .)"
N_ROOTS="$(printf '%s\n' "$SCAN_ROOTS" | grep -c .)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/apval-XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
printf '%s\n' "$AREAS" > "$TMP/areas"

# THE SUBJECT IS TRACKED FILES UNDER THE SCAN ROOTS. `git ls-files` with a pathspec per root, so
# a root that matches nothing contributes nothing rather than erroring the whole read.
: > "$TMP/paths"
SCANNED_ALL="$(git ls-files 2>/dev/null | grep -c . || true)"
while IFS= read -r r; do
  [ -n "$r" ] || continue
  git ls-files -- "$r" 2>/dev/null >> "$TMP/paths"
done <<EOF
$SCAN_ROOTS
EOF
sort -u -o "$TMP/paths" "$TMP/paths"
N_SUBJECT="$(grep -c . "$TMP/paths" || true)"

# --- the classification -------------------------------------------------------
#
# ONE PASS, NO SUBPROCESS PER FILE. The migration spawns several per component and takes
# minutes on a 5000-file consumer; that is fine for a thing the operator runs once and
# disqualifying for a thing that runs on every push.
#
# TOKEN DETECTION USES THE RESOLVER'S EXPRESSION VERBATIM. Enumerating the sprint NUMBERS a
# component names needs a second reading of the same component, and the two are asserted to
# agree on every component this reads -- a component the expression flags but the enumeration
# finds no number in would silently become "unambiguous" and get queued for a move.
#
# ONE CLASSIFIER, USED BY THE PROBE BELOW AND BY THE REAL RUN. A probe that exercises a COPY of
# the predicate proves the copy.
classify() { # <paths-file> -> CLASS<TAB>path<TAB>detail, one row per path
awk -v areas_file="$TMP/areas" -v tokenre="$TOKEN_RE" -v roots="$(printf '%s ' $SCAN_ROOTS)" '
function comp_numbers(comp,   norm, f, m, j, out) {
  # `sprint-247` and `s247` are one token in two spellings; normalising collapses them so the
  # split below sees one form. `sprint-status` normalises to `sstatus` and matches nothing,
  # which is the answer: a token needs digits.
  norm = comp; gsub(/sprint-/, "s", norm)
  m = split(norm, f, /[-.]/)
  out = ""
  for (j = 1; j <= m; j++) if (f[j] ~ /^[sS][0-9]+$/) out = out " " (substr(f[j], 2) + 0)
  return out
}
BEGIN {
  while ((getline a < areas_file) > 0) if (a != "") areas[++na] = a
  nr = split(roots, rootv, " ")
}
{
  p = $0
  if (p == "") next
  n = split(p, c, "/")

  # THE ANCHOR IS THE AREA, DECLARED OR INFERRED, AND INFERRED COUNTS. Resolving the slot against
  # DECLARED areas alone reported 92 false positives on the reference consumer -- every
  # already-conforming `_bmad-output/brainstorming/s166/…` read as a violation, against a
  # migration that planned zero moves on the same tree. An area nobody has declared yet is still
  # the area the migration anchors the slot to, so it is the area this must anchor to as well.
  # Undeclared is a paperwork gap the migration reports; it is not a path defect.
  area = ""
  for (k = 1; k <= na; k++)
    if (index(p, areas[k] "/") == 1 && length(areas[k]) > length(area)) area = areas[k]

  noarea = ""
  if (area == "") {
    # The migration derives one from the scan root -- unless the first component under a
    # CONTAINER root is purely a sprint token, in which case there is nothing to anchor the slot
    # to and it refuses rather than composing `_bmad-output//s177/…`.
    for (k = 1; k <= nr; k++) {
      r = rootv[k]
      if (r == "" || index(p, r "/") != 1) continue
      rest = substr(p, length(r) + 2)
      if (index(rest, "/") == 0) { area = r; break }       # sits directly in the scan root
      if (index(r, "/") > 0)     { area = r; break }       # `docs/retro` IS an area
      first = rest; sub(/\/.*$/, "", first)
      if (first ~ /^(s|S|sprint-)[0-9]+$/) { noarea = r "/" first; break }
      area = r "/" first                                    # the UNSTRIPPED prefix, so the slot
      break                                                 # index counts real components
    }
  }
  slotidx = 0
  if (area != "") { split(area, ac, "/"); slotidx = length(ac) + 1 }

  bad = ""; nbad = 0; nums = ""; delete seen; ndistinct = 0; mismatch = 0
  for (i = 1; i <= n; i++) {
    if (c[i] !~ tokenre) continue
    got = comp_numbers(c[i])
    if (got == "") mismatch = 1
    m = split(got, gv, " ")
    for (j = 1; j <= m; j++) if (!(gv[j] in seen)) { seen[gv[j]] = 1; ndistinct++; nums = nums " " gv[j] }
    if (i == slotidx && c[i] ~ /^s[0-9]+$/) continue      # the one legal slot, correctly spelt
    nbad++
    if (bad == "") bad = c[i]
  }
  if (nbad == 0 && noarea == "") { print "CONFORMING\t" p "\t"; next }

  if (mismatch) { print "SELF-CHECK\t" p "\tcomponent carries a sprint token the number enumeration could not read"; next }

  # THE ORDER MIRRORS migrate-artifact-paths.sh AND MUST. It defers stories/ before it reads the
  # sprint at all, so a two-sprint story path is DEFERRED there and has to be DEFERRED here, or
  # the two disagree about a file neither of them will touch.
  if (p ~ /(^|\/)stories\//) { print "DEFERRED-STORIES\t" p "\t" substr(nums, 2); next }
  if (ndistinct > 1)         { print "AMBIGUOUS\t" p "\tnames" nums; next }
  if (noarea != "")          { print "NO-AREA\t" p "\t" noarea " is a sprint directory directly under a scan root that is not an area"; next }
  print "NONCONFORMING\t" p "\tcomponent " bad
}
' "$1"
}

# --- PROVE THE PREDICATE CAN FIRE, EVERY RUN ----------------------------------
#
# This reports an ABSENCE, and its whole answer rides on one expression resolved at runtime from
# a file on disk. An expression that matched nothing would return the same empty blocking set as
# a fully-migrated tree, and the operator cannot tell those apart from the output. So the
# classifier is asked, every run, about six paths whose answers are known -- composed under the
# FIRST DECLARED AREA, so the probe exercises the real areas rather than an invented one.
PA="$(printf '%s\n' "$AREAS" | head -1)"
{ printf '%s/s7/kind.md\tCONFORMING\n'     "$PA"
  printf '%s/prd.md\tCONFORMING\n'         "$PA"
  printf '%s/s7-kind.md\tNONCONFORMING\n'  "$PA"
  printf '%s/sprint-7-kind.md\tNONCONFORMING\n' "$PA"
  printf '%s/s7/s7-kind.md\tNONCONFORMING\n'    "$PA"
  printf '%s/s7/kind-s8.md\tAMBIGUOUS\n'   "$PA"; } > "$TMP/probe.expect"
cut -f1 "$TMP/probe.expect" > "$TMP/probe.paths"
classify "$TMP/probe.paths" | cut -f1,2 > "$TMP/probe.got"

probe_bad=""
while IFS=$'\t' read -r pp pexp; do
  pgot="$(awk -F'\t' -v P="$pp" '$2==P{print $1}' "$TMP/probe.got")"
  [ "$pgot" = "$pexp" ] || probe_bad="${probe_bad}
    $pp   expected $pexp, got ${pgot:-<no row>}"
done < "$TMP/probe.expect"
if [ -n "$probe_bad" ]; then
  echo "$PROG: the classifier failed its OWN probe, so nothing it says about the tree can be" >&2
  echo "  believed. A predicate that matches nothing reports a fully-conforming tree:$probe_bad" >&2
  exit 2
fi

classify "$TMP/paths" > "$TMP/rows"

cls() { awk -F'\t' -v C="$1" '$1==C' "$TMP/rows"; }
n_of() { cls "$1" | grep -c . || true; }

N_BLOCK="$(n_of NONCONFORMING)"
N_AMBIG="$(n_of AMBIGUOUS)"
N_NOAREA="$(n_of NO-AREA)"
N_STORY="$(n_of DEFERRED-STORIES)"
N_CONF="$(n_of CONFORMING)"
N_SELF="$(n_of SELF-CHECK)"
# The whole story corpus, conforming rows included. It is the denominator the deferral is
# stated against, and printing the flagged count alone would read as the corpus size.
N_STORY_CORPUS="$(awk -F'\t' '$2 ~ /(^|\/)stories\//' "$TMP/rows" | grep -c . || true)"

echo "$PROG: root $ROOT_ABS"
echo "  grammar:                $GRAMMAR"
echo "  scan roots:             $(printf '%s ' $SCAN_ROOTS) ($N_ROOTS)"
echo "  areas (core+consumer):  $N_AREAS"
echo "  tracked files:          $SCANNED_ALL"
echo "  under the scan roots:   $N_SUBJECT   <- the subject. A zero here with a green verdict"
echo "                                          would mean the roots resolved to nothing."
echo ""

# A TREE WITH NOTHING TO JUDGE IS NOT A TREE THAT PASSED, and it must not be spelled like one.
# A greenfield consumer has no artifacts on its first push; failing it would make the grammar
# unadoptable, and printing PASS would be the zero-verification pass this repo keeps finding.
if [ "$N_SUBJECT" -eq 0 ]; then
  echo "NOT-APPLICABLE: no tracked file sits under any scan root, so no path was judged."
  echo "  This is not a pass. It is the correct answer for a consumer that has produced no"
  echo "  artifact yet, and it becomes a real verdict as soon as one exists."
  exit 0
fi

# The self-check fires on this script's OWN reading, not on the tree, so it is a defect in the
# validator rather than a finding about the consumer. It is fatal for that reason: the number
# enumeration is what decides AMBIGUOUS, and a component it cannot read becomes "unambiguous"
# and is queued for a move under whichever sprint it happened to see.
if [ "$N_SELF" -ne 0 ]; then
  echo "$PROG: SELF-CHECK FAILED on $N_SELF path(s). The sprint-token expression and the number" >&2
  echo "  enumeration disagree, so this run cannot tell an ambiguous path from a movable one:" >&2
  cls SELF-CHECK | awk -F'\t' '{printf "    %s\n      %s\n", $2, $3}' >&2
  exit 2
fi

if [ "$N_AMBIG" -gt 0 ] || [ "$N_NOAREA" -gt 0 ] || [ "$N_STORY" -gt 0 ]; then
  echo "REPORTED — non-conforming, and NOT blocking this push. Each class is computed from the"
  echo "path, never from a list, so an entry leaves it the moment the obstruction is removed:"
  [ "$N_AMBIG" -gt 0 ] && {
    echo "  AMBIGUOUS         $N_AMBIG  path names more than one sprint; which owns it is not derivable."
    echo "                        Rename the basename to name one sprint, then the next push judges it."
  }
  [ "$N_NOAREA" -gt 0 ] && {
    echo "  NO-AREA           $N_NOAREA  a sprint directory sits directly under a scan root that is not"
    echo "                        an area. Declare the area in $(bash "$CONFIG" --consumer-file 2>/dev/null || echo 'your artifact-paths file'), or move it under one."
  }
  [ "$N_STORY" -gt 0 ] && {
    echo "  DEFERRED-STORIES  $N_STORY  of $N_STORY_CORPUS file(s) under a stories/ directory — and the GAP between"
    echo "                        those two numbers is the finding, not a rounding: the rest spell the sprint"
    echo "                        as a bare leading number this expression cannot see at all."
    echo "                        CORE defers the whole directory: the sprint is spelled"
    echo "                        two ways there and one is a bare number indistinguishable from the story"
    echo "                        index this grammar itself prescribes. The release that moves stories/"
    echo "                        under s<N>/ is what removes this class; nothing here can."
  }
  echo ""
fi

if [ "$REPORT" -eq 1 ]; then
  echo "REPORT — census by area (the before/after the migration is measured on):"
  awk -F'\t' '$1!="CONFORMING" { p=$2; sub("/[^/]*$", "", p); print $1 "\t" p }' "$TMP/rows" \
    | sort | uniq -c | sort -rn | head -25 | sed 's/^/    /'
  echo ""
  echo "  Story-corpus spelling split (what the deferral is about):"
  awk -F'\t' '$2 ~ /(^|\/)stories\// { b=$2; sub(/.*\//, "", b)
        if (b ~ /^story-[sS][0-9]+-/)      k="story-S<N>-… (explicit token)"
        else if (b ~ /^story-[0-9]+-[0-9]+-/) k="story-<N>-<M>-… (bare leading number)"
        else if (b ~ /^[sS][0-9]+-/)        k="s<N>-… (no story- prefix)"
        else                                k="other"
        n[k]++ } END { for (k in n) printf "    %6d  %s\n", n[k], k }' "$TMP/rows" | sort -rn
  echo ""
  echo "  A bare leading number is why this grammar cannot judge the story corpus syntactically:"
  echo "  story-297-1-slug.md and story-<index>-<slug>.md are the same shape."
  echo ""
fi

if [ "$N_BLOCK" -eq 0 ]; then
  echo "VERDICT: PASS — no MIGRATABLE non-conforming path under the scan roots."
  echo "  $N_CONF conforming, $N_AMBIG ambiguous, $N_NOAREA with no area, $N_STORY deferred stories,"
  echo "  out of $N_SUBJECT tracked file(s) read. The zero above is a zero over that corpus, not"
  echo "  over an empty one."
  exit 0
fi

echo "BLOCKING — $N_BLOCK path(s) carry a sprint token outside the reserved \`s<N>/\` slot, and"
echo "every one of them is migratable today:"
cls NONCONFORMING | awk -F'\t' '{printf "  %s\n      (%s)\n", $2, $3}' | head -60
[ "$N_BLOCK" -gt 30 ] && echo "  … first 30 of $N_BLOCK shown."
echo ""
echo "The directory is the only sprint slot. A basename that carries one makes the reader search,"
echo "and search means mtime — which is how both hooks came to pick the live adversarial series"
echo "across 56 sprints in one directory."
echo ""
echo "  scripts/ai-dlc/migrate-artifact-paths.sh              # plan, writes nothing"
echo "  scripts/ai-dlc/migrate-artifact-paths.sh --apply      # git mv, verified per file"
echo ""
echo "VERDICT: FAIL — $N_BLOCK blocking, $N_AMBIG ambiguous, $N_NOAREA with no area, $N_STORY deferred."
exit 1
