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
# strings into the consumer's `aiDlcModels` settings block. Six layer files
# referenced the retired `- Personal:`/`- Bedrock:` `/model` line shape: a
# consumer-authored `tea` role carrying two of them live, two `/effort` overrides
# whose prose explained which sibling model lines they did NOT cover, and two
# extensions restating a per-role model table. None was reported by anything.
#
# WHAT COUNTS AS A CONTRACT SHAPE
# A LABELLED DIRECTIVE — `- <Label>: \`/<directive>` — which is how the rulebook
# writes a per-role instruction a teammate executes, and `{<token>}` setup
# placeholders. Both are unambiguous to extract and both are contracts something
# downstream parses. Deliberately NOT bare words or headings: widening this would
# flag every reworded sentence and drown the finding.
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
    | { grep -oE '^- [A-Z][A-Za-z-]*: `/[a-z][a-z-]*' || true; } \
    | sed -E 's/^- ([A-Za-z-]*): `\/(.*)$/\1:\/\2/' \
    | sort -u
}
tokens_of() {
  printf '%s\n' "$1" | { grep -oE '\{[a-z][a-z_]*\}' || true; } | sort -u
}

collect() {     # collect <ref> -> every shape+token across the rulebook at that ref
  local ref="$1" glob body all=""
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

RETIRED="$(comm -23 <(printf '%s\n' "$BASE_SET") <(printf '%s\n' "$THEIRS_SET"))"
[ -n "$RETIRED" ] || exit 0

LAYERS="$CONSUMER/.claude/skills/ai-dlc"
for dir in overrides extensions; do
  [ -d "$LAYERS/$dir" ] || continue
  find "$LAYERS/$dir" -type f \( -name '*.md' -o -name '*.json' \) 2>/dev/null \
  | sort \
  | while IFS= read -r f; do
      body="$(cat "$f" 2>/dev/null || true)"
      [ -n "$body" ] || continue
      mine="$( { shapes_of "$body"; tokens_of "$body"; } | sort -u )"
      comm -12 <(printf '%s\n' "$RETIRED") <(printf '%s\n' "$mine") \
      | while IFS= read -r shape; do
          [ -n "$shape" ] || continue
          printf 'RETIRED-LAYER-CONTRACT\t%s\t%s\n' "${f#"$CONSUMER"/}" "$shape"
        done
    done
done
