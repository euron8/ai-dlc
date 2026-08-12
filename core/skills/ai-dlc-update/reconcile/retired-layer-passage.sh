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
#   0  always (a detector reports; the caller decides)

set -u

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
  echo "retired-layer-passage: could not read the rulebook list from setup-sites.md — refusing to report clean, because an empty corpus and a clean corpus are the same output" >&2
  exit 0
fi

# Normalisation is `norm_lines` from lib.sh, which is its ONE home (I21). A private copy
# here is the shape that shipped divergent resolvers before: two tools, two confident
# verdicts, computed from different rules, with nothing comparing them.
# shellcheck source=/dev/null
. "$SELF/lib.sh"

# Structural lines are excluded: a heading, a table row, and a fence carry no directive and
# collide across unrelated files. These three exclusions are load-bearing to the measured
# empty false-positive set; the word-count floor is not, and is deliberately absent.
drop_structural() { grep -vE '^(#|\||```|$)' || true; }

# Every line core DELETED between base and theirs, across the declared rulebook.
#
# `set -f` IS LOAD-BEARING. The rulebook entries are git PATHSPECS (`steps/*.md`), and an
# unquoted expansion in `for` is subject to shell pathname expansion first — so when the
# caller's cwd happens to contain matching files, bash replaces each pathspec with real
# paths from the WRONG tree and git then diffs paths the target repo may not have. It
# fails by reporting nothing, which is the failure mode this whole detector exists to
# refuse. Caught by the fixture, whose seeded repo does not share the caller's layout.
removed_lines() {
  local glob
  set -f
  for glob in $GLOBS; do
    git -C "$DIST" diff "$BASE" "$THEIRS" -- "$glob" 2>/dev/null \
      | { grep -E '^-' || true; } \
      | { grep -vE '^---' || true; } \
      | sed -E 's/^-//'
  done | { set +f; norm_lines | drop_structural | sed '/^$/d' | sort -u; }
  set +f
}

REMOVED="$(removed_lines)"

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
NEEDLES="$(mktemp)"; trap 'rm -f "$NEEDLES"' EXIT
printf '%s\n' "$REMOVED" > "$NEEDLES"

for dir in overrides extensions; do
  [ -d "$LAYERS/$dir" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scanned=$((scanned + 1))
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      rows="$rows$(printf 'RETIRED-LAYER-PASSAGE\t%s:%s\t%s' \
        "${f#"$CONSUMER"/}" "${hit%%:*}" "${hit#*:}")
"
    done < <(norm_lines < "$f" | { grep -nxF -f "$NEEDLES" || true; })
  done < <(find "$LAYERS/$dir" -type f -name '*.md' 2>/dev/null | sort)
done

n_removed="$(printf '%s\n' "$REMOVED" | sed '/^$/d' | wc -l | tr -d ' ')"
if [ -n "$rows" ]; then
  printf '%s' "$rows"
else
  echo "retired-layer-passage: NOTE — $n_removed deleted rulebook line(s) checked against $scanned layer file(s); no match. $LIMIT" >&2
fi
