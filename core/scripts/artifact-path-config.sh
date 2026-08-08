#!/usr/bin/env bash
# artifact-path-config.sh — the ONE resolver for what artifact-path-grammar.md declares.
#
#   artifact-path-config.sh --scan-roots    [--root <dir>] [--grammar <file>]
#   artifact-path-config.sh --areas         [--root <dir>] [--grammar <file>]
#   artifact-path-config.sh --token-re
#   artifact-path-config.sh --grammar-file  [--root <dir>] [--grammar <file>]
#   artifact-path-config.sh --consumer-file [--root <dir>]
#
# WHY THIS EXISTS, and it is a measurement rather than tidiness. Three shipped programs had
# already grown their OWN copy of the same four-line extraction -- `migrate-artifact-paths.sh`,
# `validate-enforcement-map.sh`'s I82, and (as of this release) the conformance validator. The
# awk in the first two was byte-identical, which is what a fork looks like the day before it
# stops being one: widen `areas:` in the grammar and whichever copy nobody edited goes on
# governing a smaller tree while reporting the same clean line. `CLAUDE.md` says to bind two
# files that must agree; the strongest binding available here is that there is only one copy.
#
# WHAT IT RESOLVES:
#
#   --scan-roots    the ```scan-roots fenced block. What the enforcement READS. Wider than the
#                   areas on purpose: rule 2 forbids a sprint token in any basename, including
#                   paths that are not sprint artifacts at all.
#   --areas         core's `areas:` block JOINED with the consumer's, read from the file named
#                   by `consumer_artifact_paths_file:` in layer-contract.yaml. Where an `s<N>/`
#                   directory may live. Sorted and de-duplicated.
#   --token-re      the ERE that decides whether ONE path component carries a sprint token.
#                   Printed rather than defined by each caller, for the same reason as above.
#   --grammar-file  the grammar path this resolver settled on, so a caller can report it.
#   --consumer-file the contract-declared consumer artifact-paths file. Printed whether or not
#                   it exists, because "go write this file" is the correct remedy when it does
#                   not, and only a missing CONTRACT leaves it unnameable.
#
# Exit codes:
#   0  -- resolved; the answer is on stdout
#   2  -- usage error, no readable grammar, or an extraction that came back EMPTY. An empty
#         area set makes every area inferred and an empty scan-root set makes every tree
#         conforming, so both are refusals rather than empty output.
set -uo pipefail

PROG="artifact-path-config.sh"
MODE=""
ROOT="."
GRAMMAR_ARG=""

# THE ERE FOR ONE COMPONENT, defined here and nowhere else. `s`/`S`/`sprint-` followed by
# digits, bounded by a component edge or a `-`/`.` -- the four positions measured in the
# reference consumer's tree. It is deliberately NOT anchored to a whole component: the suffix
# form (`architecture-adversarial-s288-pass2.md`) is the position a whole-component match
# misses, and it was 173 files.
TOKEN_RE='(^|-)(s|S|sprint-)[0-9]+($|[-.])'

while [ $# -gt 0 ]; do
  case "$1" in
    --scan-roots|--areas|--token-re|--grammar-file|--consumer-file)
      [ -z "$MODE" ] || { echo "$PROG: two modes given ('$MODE' and '$1'); it answers one question per call" >&2; exit 2; }
      MODE="$1"; shift ;;
    --root) ROOT="${2:-}"; [ -n "$ROOT" ] || { echo "$PROG: --root needs a directory" >&2; exit 2; }; shift 2 ;;
    --grammar) GRAMMAR_ARG="${2:-}"; [ -n "$GRAMMAR_ARG" ] || { echo "$PROG: --grammar needs a file" >&2; exit 2; }; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "$PROG: unknown option '$1'" >&2
       echo "usage: $PROG --scan-roots|--areas|--token-re|--grammar-file|--consumer-file [--root <dir>] [--grammar <file>]" >&2
       exit 2 ;;
  esac
done

[ -n "$MODE" ] || { echo "$PROG: no mode given" >&2
                    echo "usage: $PROG --scan-roots|--areas|--token-re|--grammar-file|--consumer-file [--root <dir>] [--grammar <file>]" >&2
                    exit 2; }

# --token-re answers before any tree is consulted. It is a property of the grammar's RULES, not
# of a particular checkout, and making it need a readable tree would mean a caller cannot ask
# what a sprint token is without first standing somewhere that has one.
if [ "$MODE" = "--token-re" ]; then printf '%s\n' "$TOKEN_RE"; exit 0; fi

# RESOLVE --grammar BEFORE the cd, for migrate-artifact-paths.sh's reason exactly: it is the
# caller's path, relative to where THEY are standing, and this then changes directory.
if [ -n "$GRAMMAR_ARG" ]; then
  case "$GRAMMAR_ARG" in /*) : ;; *) GRAMMAR_ARG="$(pwd)/$GRAMMAR_ARG" ;; esac
fi

[ -d "$ROOT" ] || { echo "$PROG: not a directory: $ROOT" >&2; exit 2; }
cd "$ROOT" || exit 2

# THE CONSUMER LAYOUT FIRST, THE DISTRIBUTION SECOND, and never one located by walking up from
# the other (I33). install.sh splits what shares a parent here.
CONTRACT=""
for c in ".claude/skills/ai-dlc/layer-contract.yaml" "core/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$c" ] && CONTRACT="$c" && break
done

CONSUMER_AREAS_REL=""
if [ -n "$CONTRACT" ]; then
  CONSUMER_AREAS_REL="$(sed -n 's/^consumer_artifact_paths_file:[[:space:]]*//p' "$CONTRACT" \
                        | head -1 | sed 's/[[:space:]]*$//' | tr -d '"')"
fi

if [ "$MODE" = "--consumer-file" ]; then
  [ -n "$CONSUMER_AREAS_REL" ] || { echo "$PROG: layer-contract.yaml declares no consumer_artifact_paths_file:. That is a broken install, not a paperwork gap -- nothing can name where a consumer declares its own areas." >&2; exit 2; }
  printf '%s\n' "$CONSUMER_AREAS_REL"; exit 0
fi

GRAMMAR=""
if [ -n "$GRAMMAR_ARG" ]; then
  [ -f "$GRAMMAR_ARG" ] || { echo "$PROG: --grammar names no readable file: $GRAMMAR_ARG" >&2; exit 2; }
  GRAMMAR="$GRAMMAR_ARG"
else
  for c in ".claude/skills/ai-dlc/artifact-path-grammar.md" \
           "core/skills/ai-dlc/artifact-path-grammar.md"; do
    [ -f "$c" ] && GRAMMAR="$c" && break
  done
fi
[ -n "$GRAMMAR" ] || { echo "$PROG: cannot find artifact-path-grammar.md under $(pwd)." >&2
                       echo "  It declares the scan roots and the areas every caller works from;" >&2
                       echo "  guessing them would govern a tree the grammar never named." >&2; exit 2; }

if [ "$MODE" = "--grammar-file" ]; then printf '%s\n' "$GRAMMAR"; exit 0; fi

if [ "$MODE" = "--scan-roots" ]; then
  out="$(awk '/^```scan-roots$/{f=1;next} f&&/^```/{f=0} f' "$GRAMMAR" | grep -E '.')"
  [ -n "$out" ] || { echo "$PROG: extracted ZERO scan roots from $GRAMMAR. An empty root set reports a fully-conforming tree without reading one file." >&2; exit 2; }
  printf '%s\n' "$out"; exit 0
fi

# ONE EXTRACTOR FOR BOTH FILES. Core's grammar and the consumer's declaration carry the same
# `areas:` block in the same shape, and two copies of this awk is how they start disagreeing
# about what an area is.
areas_of() { awk '/^areas:$/{f=1;next} f&&/^[^ ]/{f=0} f&&/^  [^ ]/{gsub(/^  /,"");print}' "$1"; }

CORE_AREAS="$(areas_of "$GRAMMAR")"
[ -n "$CORE_AREAS" ] || { echo "$PROG: extracted ZERO areas from $GRAMMAR. Without them every area is inferred and every caller reports nothing." >&2; exit 2; }

# THE CONSUMER'S OWN AREAS ARE READ, NOT ONLY POINTED AT. Core prescribes the grammar; the
# CONSUMER declares its own areas. Declaring one is the act that stops it being inferred, and
# that is only true if something reads the declaration -- a remedy pointing at a file no reader
# consults is the inert-mechanism class.
CONSUMER_AREAS=""
if [ -n "$CONSUMER_AREAS_REL" ] && [ -f "$CONSUMER_AREAS_REL" ]; then
  CONSUMER_AREAS="$(areas_of "$CONSUMER_AREAS_REL")"
fi

printf '%s\n%s\n' "$CORE_AREAS" "$CONSUMER_AREAS" | grep -E '.' | sort -u
exit 0
