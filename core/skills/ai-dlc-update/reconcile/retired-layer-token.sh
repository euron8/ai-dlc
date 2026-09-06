#!/bin/bash
#
# AI/DLC reconcile — RETIRED STATUS TOKENS REUSED IN A CONSUMER LAYER FILE
#
# WHY THIS EXISTS
# Two siblings bracket this class without covering it. `retired-layer-contract.sh`
# matches contract SHAPES — a labelled directive, a `{token}` placeholder — and a
# status word is neither. `retired-layer-passage.sh` matches whole core LINES deleted
# between base and theirs, and a consumer sentence that merely REUSES a retired word is
# not a reproduced core line. So a release that renames a status token leaves a layer
# file quoting the old one in its own prose, and both siblings print their clean NOTE.
#
# MEASURED on the reference consumer's 0.373.0 -> 0.378.0 pull. v0.378.0 renamed the
# validator status `VACUOUS` to `EXAMINED NOTHING`. An override's RENDERED body — the
# text the lead obeys — still read `or stock exits 78 VACUOUS;`, and a grep control in
# its frontmatter still cited `VACUOUS` as a term core carried. `retired-layer-contract`
# reported "retired NO contract shape", `retired-layer-passage` reported "no match",
# `layer-drift` classified the entry only as section drift, and the readopt dossier
# said "SUPERSEDED CORE TEXT ... (none)" — correctly, since the stale word is the
# consumer's own prose. Every mechanical signal was clean. A person found it by grepping.
#
# WHAT COUNTS AS A STATUS TOKEN
# An ALL-CAPS word of four or more characters, hyphen chains allowed (`VACUOUS`,
# `CLOSE-CANDIDATE`, `HARD-OVERRIDE-DRIFT-SECTION`), bounded by anything outside
# [A-Za-z0-9_-] so `fooVACUOUS` and `x-FAIL` are not split into a capital word. That is
# deliberately the whole grammar. The rulebook also writes emphasis in capitals — NEVER,
# MEASURED — and the reason they do not drown the finding is the retirement test below,
# not a stop-list: an emphasis word is retired only when a release removes its EVERY
# occurrence from the whole rulebook, and a status word is retired exactly then.
#
# DERIVED, NEVER HAND-LISTED. The retired set is
#   (tokens anywhere in the core rulebook at BASE) MINUS (tokens anywhere in it at THEIRS)
# so a token that merely MOVED between rulebook files is not retired, and a release that
# retires nothing reports nothing, with no list to maintain. The rulebook corpus is
# `setup-sites.md`'s `rulebook:` list, the SAME declaration both siblings read, so a
# rulebook file added upstream is covered by all three without editing any.
#
# A PROGRAM-EMITTED narrowing — keep only rulebook words a core script also prints —
# was built first and REFUTED on the motivating pull: `readopt-override.sh` still prints
# the word VACUOUS at theirs in an unrelated sense ("a vacuous anchor"), so the theirs
# side un-retired the very token this exists for. The narrowing is not shipped.
#
# The rulebook side is read BARE, not backticked: at the motivating base the rulebook
# wrote `the run is VACUOUS (exit 78)` with no code span, so a backtick grammar cannot
# derive the very token this exists for. The layer side is read bare for the same
# reason — the stale sentence was `stock exits 78 VACUOUS;`.
#
# WHAT IT DOES NOT CATCH, STATED PLAINLY
# A token the consumer invented that core never had (no retirement to detect). A word
# core still carries ANYWHERE in its rulebook at theirs, even if the layer file's use of
# it is stale. A multi-word status is matched word by word, so a rename that keeps one
# of its words is reported on the word that changed. And a retired construct the layer
# file PARAPHRASES without the literal word. Do not read a clean result as "every layer
# file survived this release."
#
# USAGE
#   retired-layer-token.sh <dist> <base> <theirs> <consumer>
#
# OUTPUT  (TAB-delimited, the same contract as its sibling detectors)
#   RETIRED-LAYER-TOKEN<TAB><consumer-relative-layer-path>:<line><TAB><token>
#
# STDERR
#   Three quiet states and each says which it is, because their stdout is identical:
#   the rulebook list or the rulebook at base could not be read (a refusal, never
#   "clean"); the release retired no token, so no layer file was opened; and every
#   layer file was read against a non-empty retired set and nothing matched, stated
#   with both counts. The program caller (`emit-report.sh`) discards stderr and reads
#   the rows; the NOTE is for the operator running step 3a-vi by hand.
#
# EXIT
#   0  always (a detector reports; the caller decides)

set -u
# Every scan below is byte-wise. The layer corpus carries em-dashes and the rulebook
# carries arrows; under a UTF-8 locale `awk` aborts mid-file on a multibyte conversion
# failure and `tr -c` misclassifies bytes, and both read as a shorter corpus, not an error.
export LC_ALL=C

DIST="${1:?usage: retired-layer-token.sh <dist> <base> <theirs> <consumer>}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"

SELF="$(cd "$(dirname "$0")" && pwd)"
SITES="$SELF/setup-sites.md"
rulebook_globs() {
  awk '/^rulebook:/{on=1;next} on && /^[a-z_]+:/{exit} on && /^  - /{sub(/^  - /,"");print}' \
    "$SITES" 2>/dev/null
}

# THE TOKEN GRAMMAR. Stdin -> one token per line, sorted unique. A token is a maximal run
# of [A-Za-z0-9_-], kept only when the whole run is [A-Z][A-Z0-9_]{3,} with optional
# `-`-joined caps segments. The layer-side split below uses the SAME class, so the two
# sides cannot disagree about where a word ends.
toks() {
  tr -c 'A-Za-z0-9_-' '\n' \
  | grep -E '^[A-Z][A-Z0-9_]{3,}(-[A-Z0-9_]+)*$' \
  | sort -u
}

# collect <ref> -> every token across the rulebook at that ref. `set -f` IS LOAD-BEARING,
# the same defect both siblings carry a note about: the rulebook entries are PATHSPECS,
# and unquoted in `for` they are subject to shell pathname expansion first, so a caller
# whose cwd contains matching files gets real paths from the WRONG tree and a rulebook
# file that exists at the ref but not in the cwd is silently skipped.
collect() {
  local ref="$1" glob tree f
  tree="$(git -C "$DIST" ls-tree -r --name-only "$ref" 2>/dev/null)" || return 0
  set -f
  for glob in $(rulebook_globs); do
    printf '%s\n' "$tree" \
      | { grep -E "^$(printf '%s' "$glob" | sed 's/\./\\./g; s/\*/[^\/]*/g')$" || true; }
  done | { set +f; while IFS= read -r f; do
    [ -n "$f" ] || continue
    git -C "$DIST" show "${ref}:${f}" 2>/dev/null || true
  done; } | toks
  set +f
}

if [ -z "$(rulebook_globs)" ]; then
  echo "retired-layer-token: could not read the rulebook list from setup-sites.md — refusing to report clean, because an empty corpus and a clean corpus are the same output" >&2
  exit 0
fi

BASE_SET="$(collect "$BASE")"
THEIRS_SET="$(collect "$THEIRS")"

count_of() { printf '%s\n' "$1" | sed '/^$/d' | wc -l | tr -d ' '; }

# A release that retires nothing has nothing to report. Distinguish that from a rulebook
# that could not be read at base — an unresolvable ref, an unreadable dist — which would
# silently report "retired NO token" for every release.
if [ -z "$BASE_SET" ]; then
  echo "retired-layer-token: could not read any rulebook token at base ($BASE) — refusing to report clean, because 'no tokens' and 'nothing retired' are the same output" >&2
  exit 0
fi

RETIRED="$(comm -23 <(printf '%s\n' "$BASE_SET") <(printf '%s\n' "$THEIRS_SET"))"

# The limit that a clean run must restate, because the operator reads the RUN and never
# this header. Both quiet paths below carry it.
LIMIT='A token core never had, a word core still carries anywhere in its rulebook at theirs, and a retired construct the layer file PARAPHRASES are outside this detector BY DESIGN — this zero does not cover them.'

# A ZERO THAT NEVER OPENED A FILE MUST NOT READ LIKE A ZERO THAT SCANNED EVERYTHING.
# This is the branch the contract sibling shipped silent for nine releases: the empty
# retired set exits before any layer file is read, and its stdout is byte-identical to
# a full scan that matched nothing.
if [ -z "$RETIRED" ]; then
  echo "retired-layer-token: NOTE — this release retired NO status token ($(count_of "$BASE_SET") rulebook token(s) at base, $(count_of "$THEIRS_SET") at theirs), so NO layer file was opened. This run is SILENT about stale layer tokens, which is not the same as finding none. $LIMIT" >&2
  exit 0
fi

LAYERS="$CONSUMER/.claude/skills/ai-dlc"
NEEDLES="$(mktemp)"; trap 'rm -f "$NEEDLES"' EXIT
printf '%s\n' "$RETIRED" > "$NEEDLES"

# ONE PROCESS FOR THE WHOLE CORPUS. The needle file is read first (FNR==NR), then every
# layer file; each line is split on the same non-token class the derivation used, so a
# word inside `fooVACUOUS` or `x-VACUOUS` does not match, and `VACUOUS;` does. The path
# is reported consumer-relative and the line number is the file's own. Paths travel
# NUL-delimited so a layer file name carrying a space cannot split into two.
layer_files() {
  local dir
  for dir in overrides extensions; do
    [ -d "$LAYERS/$dir" ] || continue
    find "$LAYERS/$dir" -type f \( -name '*.md' -o -name '*.json' \) -print0 2>/dev/null
  done
}
scanned="$(layer_files | tr -dc '\0' | wc -c | tr -d ' ')"

rows=""
if [ "$scanned" -gt 0 ]; then
  rows="$(layer_files | sort -z | xargs -0 awk -v pfx="$CONSUMER/" '
    FNR==NR { if ($0 != "") r[$0]=1; next }
    {
      n = split($0, w, /[^A-Za-z0-9_-]+/)
      seen = ""
      for (i = 1; i <= n; i++) {
        if (w[i] in r && index(seen, "\t" w[i] "\t") == 0) {
          seen = seen "\t" w[i] "\t"
          rel = FILENAME
          if (index(rel, pfx) == 1) rel = substr(rel, length(pfx) + 1)
          printf "RETIRED-LAYER-TOKEN\t%s:%d\t%s\n", rel, FNR, w[i]
        }
      }
    }' "$NEEDLES")"
fi

if [ -n "$rows" ]; then
  printf '%s\n' "$rows"
else
  # The other unqualified zero: tokens WERE retired and every layer file was read, but
  # nothing matched. That is a real result and it still needs its denominator, or it
  # reads the same as a scan that found no files to open.
  echo "retired-layer-token: NOTE — $(count_of "$RETIRED") retired status token(s) checked against $scanned layer file(s); no match. $LIMIT" >&2
fi
exit 0
