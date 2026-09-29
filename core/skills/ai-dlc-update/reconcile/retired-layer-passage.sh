#!/bin/bash
#
# AI/DLC reconcile — RETIRED CORE PASSAGES STILL CARRIED BY A CONSUMER LAYER FILE
#
# WHY THIS EXISTS
# `retired-layer-contract.sh`, this file's sibling, catches a layer file still speaking a
# retired CONTRACT SHAPE — a labelled directive or a `{token}` placeholder. Its header
# states its own limit plainly: a layer file that carries a retired construct as ordinary
# PROSE has no literal shape to match and is not covered. That limit is correct and it is
# deliberately not widened there, because widening a shape matcher into bare words flags
# every reworded sentence.
#
# This detector covers that class from the other side. It does not look for shapes at all.
# It asks one question: does a layer file still contain a LINE that core CARRIED at base
# and DELETED by theirs?
#
# THE REFRAME THAT MAKES IT CHEAP. The class was first assumed to need fuzzy or semantic
# comparison. It does not. MEASURED on the two live findings that motivated this detector,
# both of which sat in the reference consumer's `extensions/steps-domain/`: each reproduces
# a deleted core line VERBATIM, differing from core only in list numbering and emphasis.
# One restates core's superseded protocol as its own prose; one quotes core's superseded
# line inside an argument about core. Exact comparison after normalisation catches both.
#
# FALSE-POSITIVE SET: MEASURED AND EMPTY.
# Run across 20 consecutive release pairs against the reference consumer's 45-file layer
# corpus. Total hits: 2 — exactly the two true findings, both on the single release pair
# that retired prose at all. Nineteen pairs removed between 0 and 8 normalisable core
# lines and produced nothing.
#
#   base..theirs        removed lines    hits
#   959e778..932ee10               60       2   <- both true findings
#   every other pair             0..8       0
#
# A MINIMUM WORD COUNT WAS MEASURED AND REJECTED. Floors of 6 and 8 words return the same
# 2 hits as no floor at all, across all 20 pairs. The filter buys nothing measurable, so it
# is not shipped: a knob with no measured benefit is mechanism the finding did not ask for,
# and a floor high enough to matter would have dropped one of the two true findings, which
# is 9 words long. What does the work is exactness plus the three structural exclusions.
#
# WHAT IT DOES NOT CATCH, STATED PLAINLY
# A layer file that PARAPHRASES a retired passage rather than reproducing it — reword any
# clause and the line no longer matches. A retirement spread across several lines, since
# comparison is per-line. And a passage core never carried, which has no retirement to
# detect. Do not read a clean result as "no layer file describes a stale core rule."
#
# WHY PER-LINE AND NOT PER-BLOCK. A block comparison would have to decide how much
# reflowing still counts as the same passage, and every answer to that is a threshold with
# no measurement behind it. A line is the unit both live findings are written in.
#
# USAGE
#   retired-layer-passage.sh <dist> <base> <theirs> <consumer>
#
# OUTPUT  (TAB-delimited, the same contract as its sibling detectors)
#   RETIRED-LAYER-PASSAGE<TAB><consumer-relative-layer-path>:<line><TAB><deleted core line>
#
# EXIT
#   0  always when it ran (a detector reports; the caller decides)
#   2  a producer this detector reads did not run -- a refusal, never a finding or a clean

set -u
# EVERY TEXT STAGE BELOW RUNS UNDER `LC_ALL=C`, byte-wise, as its sibling retired-layer-token.sh
# does. Under a UTF-8 locale BSD `sed` exits 1 on one byte that is not valid UTF-8 -- a Latin-1 `é`
# in a layer file -- so normalising that file failed and it read as carrying no retired line. Both
# sides of the comparison (the deleted core lines and the layer lines) go through the same C-locale
# stages, so the locale cannot manufacture a difference between them. The layer WALK's sort is left
# in the caller's locale: it sets the row order, and C collation would reorder the report.

DIST="${1:?usage: retired-layer-passage.sh <dist> <base> <theirs> <consumer>}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"

# The corpus is the SAME declaration its sibling reads — setup-sites.md's `rulebook:` list —
# so a rulebook file added upstream is covered by both detectors without editing either.
SELF="$(cd "$(dirname "$0")" && pwd)"
SITES="$SELF/setup-sites.md"
rulebook_globs() {
  awk '/^rulebook:/{on=1;next} on && /^[a-z_]+:/{exit} on && /^  - /{sub(/^  - /,"");print}' \
    "$SITES" 2>/dev/null
}

GLOBS="$(rulebook_globs)"
if [ -z "$GLOBS" ]; then
  # EXIT 2, THE REFUSAL CODE THIS SCRIPT'S HEADER DECLARES. It printed this line and exited 0,
  # and `apply.sh` reads this detector's EXIT, so the refusal reached it as a clean run with no
  # row. The words were right and the status contradicted them.
  echo "retired-layer-passage: could not read the rulebook list from setup-sites.md — refusing to report clean, because an empty corpus and a clean corpus are the same output" >&2
  exit 2
fi

# Normalisation is `norm_lines` from lib.sh, which is its ONE home (I21). A private copy
# here is the shape that shipped divergent resolvers before: two tools, two confident
# verdicts, computed from different rules, with nothing comparing them.
# shellcheck source=/dev/null
. "$SELF/lib.sh"

# EVERY STAGE BELOW IS STAGED TO A FILE AND ITS STATUS IS READ, the deleted-line side as much as
# the layer side. This file does not set `pipefail`, so a pipeline reports its LAST stage: the
# deleted-line set used to be one pipeline ending in `sort -u`, and a normalisation or filter that
# died upstream of it read as "this release deleted no comparable line" -- the quiet NOTE below,
# exit 0, no layer file opened. A producer that did not run exits 2, which emit-report.sh renders
# as DETECTOR-REFUSED. One directory per run; the needle file lives in it, so this is the file's
# only trap.
RLP_T="$(mktemp -d "${TMPDIR:-/tmp}/retired-layer-passage.XXXXXX")" || {
  echo "retired-layer-passage: the staging directory did not run (mktemp failed); no verdict" >&2
  exit 2
}
trap 'rm -rf "$RLP_T"' EXIT
rlp_refuse() { # rlp_refuse <what> <status>
  echo "retired-layer-passage: $1 did not run (exit $2); no verdict" >&2
  exit 2
}

# The raw text of every line core DELETED between base and theirs, across the declared rulebook:
# a `-` line of the diff that is not its `---` header, the `-` stripped. Returns the status of the
# first extraction that failed. git's own status is NOT read: an unresolvable ref has always read
# as a release that deleted nothing, and that NOTE says in words that no layer file was opened.
#
# `set -f` IS LOAD-BEARING. The rulebook entries are git PATHSPECS (`steps/*.md`), and an
# unquoted expansion in `for` is subject to shell pathname expansion first — so when the
# caller's cwd happens to contain matching files, bash replaces each pathspec with real
# paths from the WRONG tree and git then diffs paths the target repo may not have. It
# fails by reporting nothing, which is the failure mode this whole detector exists to
# refuse. Caught by the fixture, whose seeded repo does not share the caller's layout.
removed_raw() {
  local glob rc=0 st
  set -f
  for glob in $GLOBS; do
    git -C "$DIST" diff "$BASE" "$THEIRS" -- "$glob" 2>/dev/null \
      | LC_ALL=C sed -n -e '/^---/d' -e 's/^-//p'
    st="${PIPESTATUS[1]}"
    [ "$st" -eq 0 ] || [ "$rc" -ne 0 ] || rc="$st"
  done
  set +f
  return "$rc"
}
_rlp_rc=0
removed_raw > "$RLP_T/removed-raw" || _rlp_rc=$?
[ "$_rlp_rc" -eq 0 ] || rlp_refuse "extracting the deleted rulebook lines" "$_rlp_rc"
# norm_lines' status is its FIRST failed stage's (lib.sh), not its last stage's.
norm_lines < "$RLP_T/removed-raw" > "$RLP_T/removed-norm" || _rlp_rc=$?
[ "$_rlp_rc" -eq 0 ] || rlp_refuse "normalising the deleted rulebook lines" "$_rlp_rc"
# Structural lines are excluded: a heading, a table row, and a fence carry no directive and
# collide across unrelated files. These three exclusions are load-bearing to the measured
# empty false-positive set; the word-count floor is not, and is deliberately absent. Blank
# lines go with them. grep's 1 is a deleted set that was all structure, which is healthy.
LC_ALL=C grep -vE '^(#|\||```|$)' "$RLP_T/removed-norm" > "$RLP_T/removed-kept" || _rlp_rc=$?
case "$_rlp_rc" in 0|1) _rlp_rc=0 ;; *) rlp_refuse "filtering the deleted rulebook lines" "$_rlp_rc" ;; esac
sort -u "$RLP_T/removed-kept" > "$RLP_T/removed" || rlp_refuse "sorting the deleted rulebook lines" "$?"
REMOVED="$(cat "$RLP_T/removed")" || rlp_refuse "reading the deleted rulebook lines" "$?"

# A ZERO THAT NEVER OPENED A FILE MUST NOT READ LIKE A ZERO THAT SCANNED EVERYTHING.
# This is the defect its sibling shipped for nine releases and 0.359.0 repaired: the
# empty-set branch exited silently, and its output was byte-identical to a full scan that
# matched nothing. Both quiet paths here carry their denominator from the start.
LIMIT='A layer file that PARAPHRASES rather than reproduces a retired passage carries no matching line and is outside this detector'"'"'s reach — this zero does not cover it.'

if [ -z "$REMOVED" ]; then
  echo "retired-layer-passage: NOTE — this release DELETED no comparable rulebook line between $BASE and $THEIRS, so NO layer file was opened. This run is SILENT about stale layer passages, which is not the same as finding none. $LIMIT" >&2
  exit 0
fi

LAYERS="$CONSUMER/.claude/skills/ai-dlc"
scanned=0
rows=""

# ONE PROCESS PER FILE, NOT PER LINE. The first working version normalised each layer line
# in its own subshell and took minutes on a 45-file corpus; a validator's runtime is the
# suite's wall clock, so the comparison is done with a single `grep -nxF -f` per file
# against the retired set. `norm` is line-preserving, so grep's line numbers are the
# file's own. Structural lines are filtered out of the RETIRED set only -- a layer heading
# cannot match a set that contains no headings, so filtering the layer side too would cost
# a process and buy nothing.
#
# EVERY LOOP FEED IS STAGED TO A FILE AND ITS PRODUCER'S STATUS IS READ. The two loops below
# used to read `done < <(…)`, which discards the status: a layer walk that failed read as an
# empty directory, `scanned` stayed 0, and the run printed its "no match" NOTE and exited 0 --
# a false clear. Each fallible stage is staged ALONE, into the directory made above.
NEEDLES="$RLP_T/needles"
printf '%s\n' "$REMOVED" > "$NEEDLES" || rlp_refuse "staging the retired line set" "$?"

for dir in overrides extensions; do
  [ -d "$LAYERS/$dir" ] || continue
  _rlp_rc=0
  find "$LAYERS/$dir" -type f -name '*.md' 2>/dev/null > "$RLP_T/walk-$dir" || _rlp_rc=$?
  [ "$_rlp_rc" -eq 0 ] || rlp_refuse "the layer walk of $LAYERS/$dir" "$_rlp_rc"
  sort "$RLP_T/walk-$dir" > "$RLP_T/walk-$dir.sorted" || rlp_refuse "sorting the layer walk of $LAYERS/$dir" "$?"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scanned=$((scanned + 1))
    # norm_lines staged alone, then grep over it: grep's 1 is a file carrying no retired line.
    # norm_lines' status is its FIRST failed stage's (lib.sh), not its last stage's.
    _rlp_rc=0
    norm_lines < "$f" > "$RLP_T/layer-norm" || _rlp_rc=$?
    [ "$_rlp_rc" -eq 0 ] || rlp_refuse "normalising ${f#"$CONSUMER"/}" "$_rlp_rc"
    LC_ALL=C grep -nxF -f "$NEEDLES" "$RLP_T/layer-norm" > "$RLP_T/layer-hits" || _rlp_rc=$?
    case "$_rlp_rc" in 0|1) ;; *) rlp_refuse "the retired-line match over ${f#"$CONSUMER"/}" "$_rlp_rc" ;; esac
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      rows="$rows$(printf 'RETIRED-LAYER-PASSAGE\t%s:%s\t%s' \
        "${f#"$CONSUMER"/}" "${hit%%:*}" "${hit#*:}")
"
    done < "$RLP_T/layer-hits"
  done < "$RLP_T/walk-$dir.sorted"
done

n_removed="$(printf '%s\n' "$REMOVED" | sed '/^$/d' | wc -l | tr -d ' ')"
if [ -n "$rows" ]; then
  printf '%s' "$rows"
else
  echo "retired-layer-passage: NOTE — $n_removed deleted rulebook line(s) checked against $scanned layer file(s); no match. $LIMIT" >&2
fi
