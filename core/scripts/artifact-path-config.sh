#!/usr/bin/env bash
# artifact-path-config.sh — the ONE resolver for what artifact-path-grammar.md declares.
#
#   artifact-path-config.sh --scan-roots    [--root <dir>] [--grammar <file>]
#   artifact-path-config.sh --areas         [--root <dir>] [--grammar <file>]
#   artifact-path-config.sh --token-re
#   artifact-path-config.sh --token-re-prescribed
#   artifact-path-config.sh --slot-re
#   artifact-path-config.sh --slot-re-prescribed
#   artifact-path-config.sh --conceal-re-prescribed
#   artifact-path-config.sh --grammar-file  [--root <dir>] [--grammar <file>]
#   artifact-path-config.sh --consumer-file [--root <dir>]
#   artifact-path-config.sh --consumer-syntax [--root <dir>]
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
#   --token-re      the ERE that decides whether ONE path component of a REAL FILENAME carries a
#                   sprint token. Digits, because an expanded filename has no other kind.
#                   Printed rather than defined by each caller, for the same reason as above.
#   --token-re-prescribed
#                   the same rule over a path written in PROSE, where the sprint is a placeholder
#                   (`s<N>`, a bare `N`, `*`) and never a digit. Two expressions because they read
#                   two different string sets -- and one home, because the release that gave them
#                   two had a checker matching neither of its own subject's spellings.
#   --slot-re / --slot-re-prescribed
#                   whether ONE component IS the reserved sprint slot -- the exemption every
#                   token check needs and every caller used to hand-list. Anchored to a whole
#                   component, and split into a real-path form (digits) and a prose form
#                   (placeholder or digits) for the same reason the token pair is.
#   --conceal-re-prescribed
#                   whether ONE placeholder in a prescribed BASENAME names a thing whose
#                   expansion carries a sprint. The token pair above reads what a prescription
#                   SPELLS; this reads what it HIDES, and the grammar's own "what a syntactic
#                   check cannot catch" section is the measurement it comes from. Prose only --
#                   an expanded filename has no placeholders, so there is no real-path twin.
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

# THE SAME RULE OVER A PRESCRIPTION, WHICH IS A DIFFERENT STRING SET AND WAS A SECOND HOME.
# `TOKEN_RE` above reads EXPANDED filenames, which is all its callers read, so digits are the
# only sprint it can meet. A path written in PROSE names the sprint with a placeholder --
# `s<N>`, a bare `N`, or `*` -- and none of those is a digit.
#
# THE FORK THIS CLOSES, and it is the exact shape this file was created to stop. I82 in
# `validate-enforcement-map.sh` scans core's prescriptions and had grown its OWN widened copy of
# this expression, beside a header here claiming to be the single home of the sprint-token
# expression. The claim was true of the digits form and false of the rule.
#
# WHY IT MATTERS RATHER THAN BEING TIDY: measured on the reference consumer, the two artifact-path
# defects in its layer entries are written `s<N>-carry-over-evaluation.md` and
# `config-integrity-snapshot-s<N>.json`. A checker built on the digits form matches NEITHER and
# reports a clean zero on its own subject -- this repo's named defect class, reached by picking
# the wrong one of two expressions that both look right.
#
# THE RESERVED SLOT IS NOT A VIOLATION AND IS NOT IN THIS ERE, and the exemption has its own
# home below rather than being restated by each caller. Encoding it here would make the ERE
# answer two questions.
TOKEN_RE_PRESCRIBED='(^|-)(s|S|sprint-)(<N>|N|\*|[0-9]+)($|[-.])'

# THE SLOT ITSELF, and it exists because the sentence above used to end "a caller tests them by
# whole-component equality" -- and every caller that did wrote out a HAND-LIST of the spellings
# it happened to think of.
#
# MEASURED, on the reference consumer, at the release that fixed it: `validate-layer-entries.sh`
# skipped the literal strings `s<N>` and `s*` and nothing else, so a prescription naming a
# CONCRETE slot -- `docs/retro/s294/retro.md` -- was flagged as carrying a sprint token outside
# the slot. That path IS the slot, correctly spelt, and it is the rewrite W11's own message
# prescribes. **All SEVEN of the consumer's remaining W11 rows were that shape**: the clause was
# reporting its own remedy back as the defect, which is the one failure mode that teaches an
# operator to stop reading a check.
#
# TWO EXPRESSIONS, for the same reason as the token pair above: a PROSE path spells the slot with
# a placeholder or with digits, an expanded FILENAME only ever with digits. A caller that reads
# real paths must not accept `s<N>` as a directory that exists.
SLOT_RE_PRESCRIBED='^s(<N>|N|\*|[0-9]+)$'
SLOT_RE='^s[0-9]+$'

# THE PLACEHOLDER THAT HIDES A SPRINT. `TOKEN_RE_PRESCRIBED` above reads what a prescription
# SPELLS; a prescription can also DECLINE to spell it, and `<story-id>-review.md` matches nothing
# in that expression while expanding to `S292-ff-s3-...-review.md` on a real sprint. Two sprints
# apart, the same consumer filed the same defect from that one prescription, each time found at
# push time in a real filename rather than at prescription time.
#
# THE NARROWING, and it is the whole content of this expression. Not every placeholder hides a
# sprint: over core's own prescriptions the basename placeholders are `<artifact>`, `<M>`, `<N>`,
# `<type>`, `<slug>`, `<story-id>` and `<story-index>`, and only two of those name something the
# pipeline mints sprint-scoped. So the match is on the placeholder's NAME, by hyphen-delimited
# segment: `sprint` names the sprint, `N` is this grammar's own spelling of the sprint number, and
# `id` is the segment every sprint-scoped identifier in the pipeline ends on. Segment equality and
# not substring is load-bearing -- `<candidate>` and `<identifier>` contain `id` and name nothing
# sprint-scoped, and a substring match would report both.
#
# A CALLER MUST STILL SUBTRACT `TOKEN_RE_PRESCRIBED`'s OWN SUBJECT. `sprint-<N>.md` matches this
# too, and it is a VISIBLE token that the token expression already owns; reporting it here would
# make one defect two findings and put the remedy in two places.
CONCEAL_RE_PRESCRIBED='<([^>]*-)?(id|N|sprint)(-[^>]*)?>'

while [ $# -gt 0 ]; do
  case "$1" in
    --scan-roots|--areas|--token-re|--token-re-prescribed|--slot-re|--slot-re-prescribed|--conceal-re-prescribed|--grammar-file|--consumer-file|--consumer-syntax)
      [ -z "$MODE" ] || { echo "$PROG: two modes given ('$MODE' and '$1'); it answers one question per call" >&2; exit 2; }
      MODE="$1"; shift ;;
    --root) ROOT="${2:-}"; [ -n "$ROOT" ] || { echo "$PROG: --root needs a directory" >&2; exit 2; }; shift 2 ;;
    --grammar) GRAMMAR_ARG="${2:-}"; [ -n "$GRAMMAR_ARG" ] || { echo "$PROG: --grammar needs a file" >&2; exit 2; }; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "$PROG: unknown option '$1'" >&2
       echo "usage: $PROG --scan-roots|--areas|--token-re|--token-re-prescribed|--slot-re|--slot-re-prescribed|--conceal-re-prescribed|--grammar-file|--consumer-file|--consumer-syntax [--root <dir>] [--grammar <file>]" >&2
       exit 2 ;;
  esac
done

[ -n "$MODE" ] || { echo "$PROG: no mode given" >&2
                    echo "usage: $PROG --scan-roots|--areas|--token-re|--token-re-prescribed|--slot-re|--slot-re-prescribed|--conceal-re-prescribed|--grammar-file|--consumer-file|--consumer-syntax [--root <dir>] [--grammar <file>]" >&2
                    exit 2; }

# --token-re answers before any tree is consulted. It is a property of the grammar's RULES, not
# of a particular checkout, and making it need a readable tree would mean a caller cannot ask
# what a sprint token is without first standing somewhere that has one.
if [ "$MODE" = "--token-re" ]; then printf '%s\n' "$TOKEN_RE"; exit 0; fi
if [ "$MODE" = "--token-re-prescribed" ]; then printf '%s\n' "$TOKEN_RE_PRESCRIBED"; exit 0; fi
if [ "$MODE" = "--slot-re" ]; then printf '%s\n' "$SLOT_RE"; exit 0; fi
if [ "$MODE" = "--slot-re-prescribed" ]; then printf '%s\n' "$SLOT_RE_PRESCRIBED"; exit 0; fi
if [ "$MODE" = "--conceal-re-prescribed" ]; then printf '%s\n' "$CONCEAL_RE_PRESCRIBED"; exit 0; fi

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

# --consumer-syntax -- ONE line naming an UNREADABLE declaration, or nothing.
#
# WHY THIS EXISTS AS A SEPARATE MODE. The template shipped `area: <path>` one per line for seven
# releases while `areas_of()` above has only ever read an `areas:` block, so a consumer following
# its own scaffolded documentation declared nothing and was told, on every run, to declare it.
# The template is now correct and that fixes NOTHING for a consumer that already has one:
# `install.sh` scaffolds this file only when it is ABSENT and preserves it otherwise, by design,
# because it is consumer-owned. So the correction cannot arrive by pull and the diagnosis has to.
#
# THE PREDICATE IS THE CONJUNCTION, AND EACH HALF ALONE IS A FALSE POSITIVE. A file with a
# readable `areas:` block that ALSO mentions `area:` in its prose is fine and must stay silent;
# a file with neither is an undeclared set, which is a legal answer here and not an error. Only
# `area:`-shaped lines present WITH nothing readable is the unreadable-declaration state.
#
# ANCHORED AT COLUMN 0 AND REQUIRING THE VALUE, so the template's own indented worked example --
# which is deliberately inert and which a consumer is told to de-indent -- cannot trip it.
if [ "$MODE" = "--consumer-syntax" ]; then
  [ -n "$CONSUMER_AREAS_REL" ] || exit 0
  [ -f "$CONSUMER_AREAS_REL" ] || exit 0
  if [ -z "$(areas_of "$CONSUMER_AREAS_REL")" ] \
     && grep -qE '^area:[[:space:]]*[^[:space:]]' "$CONSUMER_AREAS_REL"; then
    printf '%s\n' "UNREADABLE DECLARATION: ${CONSUMER_AREAS_REL} carries $(grep -cE '^area:[[:space:]]*[^[:space:]]' "$CONSUMER_AREAS_REL") 'area:' line(s) and no readable 'areas:' block, so NONE of them is being read. The one reader takes an 'areas:' header at column 0 with each area indented exactly two spaces beneath it. Rewrite the block in that shape; the areas below are inferred only because the declaration could not be parsed."
  fi
  exit 0
fi

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
