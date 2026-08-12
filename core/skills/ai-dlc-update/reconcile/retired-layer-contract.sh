#!/bin/bash
#
# AI/DLC reconcile — RETIRED CONTRACT SHAPES IN CONSUMER LAYER FILES
#
# WHY THIS EXISTS
# `retired-tokens.sh` catches a consumer that still speaks a retired contract from
# INSIDE an upstream-maintained file. Its subject set is the CLASSIFY bucket — core
# files that both sides changed — so it never opens `overrides/` or `extensions/`.
# Those files are consumer-authored, upstream has no copy, and no bucket claims them.
# So a layer file that quotes, shadows, or restates a core construct upstream just
# retired is invisible to every detector in this directory: the pull is clean, the
# apply is clean, and the layer keeps describing a shape core no longer has.
#
# The failure is not cosmetic. An override's body states the core value it shadows;
# an extension's body can restate a core directive verbatim. When core retires the
# construct, that text becomes an instruction to reproduce something that no longer
# parses — and the layer is what the teammate actually reads.
#
# MEASURED on the reference consumer at the release that moved role-file model
# strings into the consumer's `aiDlcModels` settings block. Of its 36 layer files,
# 2 carried the retired `- <Label>: \`/model` shape and both are true findings: a
# consumer-authored `tea` role with two live pin lines, and an extension embedding
# a grep for that shape plus a stale per-role table of its captured output. Neither
# was reported by anything. Two further overrides paraphrase the shape in prose and
# are deliberately NOT flagged — see the limits stated below.
#
# WHAT COUNTS AS A CONTRACT SHAPE
# A LABELLED DIRECTIVE — `- <Label>: \`/<directive>` — which is how the rulebook
# writes a per-role instruction a teammate executes, and `{<token>}` setup
# placeholders. Both are unambiguous to extract and both are contracts something
# downstream parses. Deliberately NOT bare words or headings: widening this would
# flag every reworded sentence and drown the finding.
#
# The label is matched ANYWHERE on the line, not just at its start, and tolerates a
# backslash-escaped backtick. Both forms are load-bearing: a layer file that embeds a
# `grep` for a core line indents its captured output, and one that quotes the pattern
# inside a fenced command escapes the backtick. Anchoring on `^- ` missed exactly that
# file on the reference consumer — an extension carrying both the retired grep pattern
# and a stale per-role table of its output. Measured against all 36 of that consumer's
# layer files, the unanchored form matches 2 and both are true findings.
#
# DERIVED, NEVER HAND-LISTED. The retired set is computed as
#   (shapes in BASE's core rulebook) MINUS (shapes in THEIRS's core rulebook)
# and intersected with what each layer file still references. A release that
# retires nothing reports nothing, with no list to maintain.
#
# WHAT IT DOES NOT CATCH, STATED PLAINLY
# A shape the consumer invented that core never had — there is no retirement to
# detect. And a layer file that describes a retired construct WITHOUT using its
# literal shape (prose paraphrase). Do not read a clean result as "every layer file
# survived this release."
#
# USAGE
#   retired-layer-contract.sh <dist> <base> <theirs> <consumer>
#
# OUTPUT  (TAB-delimited, the same contract as its sibling detectors)
#   RETIRED-LAYER-CONTRACT<TAB><consumer-relative-layer-path><TAB><shape>
#
# EXIT
#   0  always (a detector reports; the caller decides)

set -u

DIST="${1:?usage: retired-layer-contract.sh <dist> <base> <theirs> <consumer>}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"

# The rulebook files whose constructs a layer file can legitimately shadow or
# restate. Derived from setup-sites.md's own `rulebook:` list rather than restated,
# so a rulebook file added upstream is covered without editing this script.
SELF="$(cd "$(dirname "$0")" && pwd)"
SITES="$SELF/setup-sites.md"
rulebook_globs() {
  awk '/^rulebook:/{on=1;next} on && /^[a-z_]+:/{exit} on && /^  - /{sub(/^  - /,"");print}' \
    "$SITES" 2>/dev/null
}

# Contract shapes in a body: labelled directives (`- <Label>: `/<directive>`) and
# `{<token>}` setup placeholders.
shapes_of() {   # shapes_of <body>
  printf '%s\n' "$1" \
    | { grep -oE -- '- [A-Z][A-Za-z-]*: \\?`/[a-z][a-z-]*' || true; } \
    | sed -E 's/^- ([A-Za-z-]*): \\?`\/(.*)$/\1:\/\2/' \
    | sort -u
}
tokens_of() {
  printf '%s\n' "$1" | { grep -oE '\{[a-z][a-z_]*\}' || true; } | sort -u
}

collect() {     # collect <ref> -> every shape+token across the rulebook at that ref
  local ref="$1" glob body all=""
  # `set -f` IS LOAD-BEARING, same defect its sibling retired-layer-passage.sh carries a
  # note about. These entries are PATHSPECS; unquoted in `for` they are subject to shell
  # pathname expansion first, so when the caller's cwd contains matching files bash
  # substitutes real paths from the WRONG tree. A rulebook file that exists at the ref but
  # not in the caller's working tree is then silently skipped, and this detector reports a
  # smaller corpus with the same clean line.
  set -f
  for glob in $(rulebook_globs); do
    # git ls-tree expands the glob against the tree at <ref>.
    for f in $(git -C "$DIST" ls-tree -r --name-only "$ref" 2>/dev/null \
               | { grep -E "^$(printf '%s' "$glob" | sed 's/\./\\./g; s/\*/[^\/]*/g')$" || true; }); do
      body="$(git -C "$DIST" show "$ref:$f" 2>/dev/null || true)"
      [ -n "$body" ] || continue
      all="$all$(shapes_of "$body")
$(tokens_of "$body")
"
    done
  done
  set +f
  printf '%s\n' "$all" | sed '/^$/d' | sort -u
}

BASE_SET="$(collect "$BASE")"
THEIRS_SET="$(collect "$THEIRS")"

# A release that retires nothing has nothing to report. Distinguish that from an
# unresolvable rulebook list, which would silently report clean for every release.
if [ -z "$BASE_SET" ]; then
  echo "retired-layer-contract: could not read any rulebook contract shape at base ($BASE) — refusing to report clean, because 'no shapes' and 'nothing retired' are the same output" >&2
  exit 0
fi

count_of() { printf '%s\n' "$1" | sed '/^$/d' | wc -l | tr -d ' '; }

# The limit that a clean run must restate, because the operator reads the RUN and never
# this header. Both quiet paths below carry it.
LIMIT='Prose restatements of retired core text carry no literal shape and are outside this detector'"'"'s vocabulary BY DESIGN — this zero does not cover them.'

RETIRED="$(comm -23 <(printf '%s\n' "$BASE_SET") <(printf '%s\n' "$THEIRS_SET"))"

# A ZERO THAT NEVER OPENED A FILE MUST NOT READ LIKE A ZERO THAT SCANNED EVERYTHING.
# The guard above refuses to report clean when the rulebook is unreadable, on the ground
# that "no shapes" and "nothing retired" are the same output. The empty-retired-set case
# has the SAME ambiguity and had no such guard: the script exited here, silently, having
# opened no layer file, and its output was byte-identical to a full scan that matched
# nothing. MEASURED on the 0.356.0 -> 0.357.0 consumer pull: the retired set was empty,
# this branch was taken, and the run was read as evidence that no layer file carried
# retired core text while two of them did.
if [ -z "$RETIRED" ]; then
  echo "retired-layer-contract: NOTE — this release retired NO contract shape ($(count_of "$BASE_SET") at base, $(count_of "$THEIRS_SET") at theirs), so NO layer file was opened. This run is SILENT about layer drift, which is not the same as finding none. $LIMIT" >&2
  exit 0
fi

LAYERS="$CONSUMER/.claude/skills/ai-dlc"
scanned=0
rows=""
for dir in overrides extensions; do
  [ -d "$LAYERS/$dir" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scanned=$((scanned + 1))
    body="$(cat "$f" 2>/dev/null || true)"
    [ -n "$body" ] || continue
    mine="$( { shapes_of "$body"; tokens_of "$body"; } | sort -u )"
    while IFS= read -r shape; do
      [ -n "$shape" ] || continue
      rows="$rows$(printf 'RETIRED-LAYER-CONTRACT\t%s\t%s' "${f#"$CONSUMER"/}" "$shape")
"
    done < <(comm -12 <(printf '%s\n' "$RETIRED") <(printf '%s\n' "$mine"))
  done < <(find "$LAYERS/$dir" -type f \( -name '*.md' -o -name '*.json' \) 2>/dev/null | sort)
done

if [ -n "$rows" ]; then
  printf '%s' "$rows"
else
  # The other unqualified zero: shapes WERE retired and every layer file was read, but
  # nothing matched. That is a real result and it still needs its denominator, or it
  # reads the same as a scan that found no files to open.
  echo "retired-layer-contract: NOTE — $(count_of "$RETIRED") retired shape(s) checked against $scanned layer file(s); no match. $LIMIT" >&2
fi
