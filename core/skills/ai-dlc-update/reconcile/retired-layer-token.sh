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
# An ALL-CAPS word of four or more characters, hyphen or underscore chains allowed
# (`VACUOUS`, `CLOSE-CANDIDATE`, `AI_DLC_MODEL_ROW`), read as a maximal run of
# [A-Za-z0-9_-] so `fooVACUOUS` and `x-FAIL` are not split into a capital word. The
# rulebook corpus is `setup-sites.md`'s `rulebook:` list, the SAME declaration both
# siblings read, so a rulebook file added upstream is covered by all three without
# editing any.
#
# A word is RETIRED when the rulebook carries it at BASE and nowhere at THEIRS, AND ONE
# OF TWO WITNESSES SAYS IT WAS A CONTRACT AND NOT EMPHASIS:
#   - it is JOINED — carries a `-` or `_` — which prose emphasis never is; or
#   - it is PLAIN and some core PROGRAM (the globs in `program_globs` below) emitted it
#     in a non-comment line at base and no longer does in THAT FILE at theirs.
# The witness is what separates a status from a shout. MEASURED across two populations
# against the reference consumer's 48-file layer corpus: over 40 consecutive release
# pairs only two retire anything, so that population cannot tell the grammars apart; over
# 21 wide spans — a consumer's base is many releases behind, which is the shape a real
# reconcile compares — the rulebook-only set difference produced 16 false rows, every one
# a prose emphasis word (ABSENT, CURRENT) still in the rulebook today that one theirs
# revision happened not to use, or a sprint id (S290) the layer cites as its own
# provenance. The per-file program witness alone brought that to zero but ACQUITTED
# `APPROVED-WITH-FIXES` and `CHANGES-REQUIRED`, retired verdict tokens that live only in
# rulebook prose — exactly the class this exists for. The joined-shape witness keeps
# those; the program witness keeps `VACUOUS`; together the false set stayed at zero.
#
# THE PROGRAM WITNESS IS PER FILE, NOT A UNION AT THEIRS. A union — "retired unless any
# program still prints it" — was built first and REFUTED on the motivating pull:
# `readopt-override.sh` still prints the word VACUOUS at theirs in an unrelated sense
# ("a vacuous anchor"), so the union un-retired the very token this exists for. The
# witness file is `validate-ci-gates.sh`, which printed it at base and not at theirs.
#
# The rulebook side is read BARE, not backticked: at the motivating base the rulebook
# wrote `the run is VACUOUS (exit 78)` with no code span, so a backtick grammar cannot
# derive the very token this exists for. The layer side is read bare for the same
# reason — the stale sentence was `stock exits 78 VACUOUS;`.
#
# WHAT IT DOES NOT CATCH, STATED PLAINLY
# A token the consumer invented that core never had (no retirement to detect). A word
# core still carries ANYWHERE in its rulebook at theirs, even if the layer file's use of
# it is stale. A PLAIN word that left the rulebook and that no core program under the
# declared globs ever printed — it is read as emphasis, and the NOTE names it. A
# multi-word status is matched word by word, so a rename that keeps one of its words is
# reported on the word that changed. And a retired construct the layer file PARAPHRASES
# without the literal word. Do not read a clean result as "every layer file survived."
#
# USAGE
#   retired-layer-token.sh <dist> <base> <theirs> <consumer>
#
# OUTPUT  (TAB-delimited, the same contract as its sibling detectors)
#   RETIRED-LAYER-TOKEN<TAB><consumer-relative-layer-path>:<line><TAB><token>
#
# STDERR
#   Three quiet states and each says which it is, because their stdout is identical:
#   the rulebook list, the rulebook at base, or the rulebook at THEIRS could not be read
#   (a refusal, never "clean"); the release retired no token, so no layer file was
#   opened; and every layer file was read against a non-empty retired set and nothing
#   matched, stated with both counts. Every quiet line — and a NOTE after the rows on a
#   run that found something — names the plain words that left the rulebook WITHOUT a
#   witness, so an acquittal is visible rather than silent on every run. A base at which
#   NO program file can be read cannot witness anything and is the fourth refusal.
#   The program caller (`emit-report.sh`) discards stderr and reads the rows and the
#   exit; the NOTE is for the operator running step 3a-vi by hand.
#
#   THE THEIRS GUARD IS NOT SYMMETRY FOR ITS OWN SAKE. An unresolvable theirs ref leaves
#   the theirs set EMPTY, and an empty theirs set retires EVERY rulebook token — measured:
#   1320 rows, zero bytes of stderr, exit 0, into the region the operator approves. "No
#   tokens at theirs" and "the release retired everything" are the same output, with the
#   opposite polarity to the base case, and the base guard alone acquits it.
#
# EXIT
#   0  reported (rows, or a NOTE saying which quiet state this is)
#   2  refused: a corpus could not be read, so nothing was examined. The driver renders
#      DETECTOR-REFUSED for the section rather than `none`.

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
# The programs whose emitted words witness that a plain rulebook capital is a STATUS.
program_globs() {
  printf '%s\n' 'core/scripts/*.sh' 'core/hooks/*.sh' 'core/git-hooks/*' \
                'core/skills/ai-dlc-update/reconcile/*.sh'
}

# THE TOKEN GRAMMAR. Stdin -> one token per line, sorted unique. Separators are
# normalised to newlines FIRST and the whole run is then matched, so two tokens with one
# separator between them are both seen — a boundary-group `grep -o` consumes the
# separator and loses the second, measured at 550 of 589 tokens on the real rulebook.
toks() {
  tr -c 'A-Za-z0-9_-' '\n' \
  | grep -E '^[A-Z][A-Z0-9_]{3,}(-[A-Z0-9_]+)*$' \
  | sort -u
}
# The same over a program: comment lines are dropped first, because a script's header
# routinely documents the token it just retired (the retirement is WHY the comment is
# there), and a word that survives only in prose about its removal is still retired.
code_toks() {
  grep -vE '^[[:space:]]*#' | toks
}

# files_at <ref> <glob>... -> every path in the tree at <ref> matching one of the globs.
# `set -f` IS LOAD-BEARING, the same defect both siblings carry a note about: these are
# PATHSPECS, and unquoted in `for` they are subject to shell pathname expansion first, so
# a caller whose cwd contains matching files gets real paths from the WRONG tree and a
# rulebook file that exists at the ref but not in the cwd is silently skipped.
files_at() {
  local ref="$1" glob tree; shift
  tree="$(git -C "$DIST" ls-tree -r --name-only "$ref" 2>/dev/null)" || return 0
  set -f
  for glob in "$@"; do
    printf '%s\n' "$tree" \
      | { grep -E "^$(printf '%s' "$glob" | sed 's/\./\\./g; s/\*/[^\/]*/g')$" || true; }
  done
  set +f
}
show_at() { git -C "$DIST" show "${1}:${2}" 2>/dev/null || true; }

# collect <ref> -> every rulebook token at that ref.
collect() {
  local ref="$1" f
  set -f
  # shellcheck disable=SC2046
  files_at "$ref" $(rulebook_globs) | { set +f; while IFS= read -r f; do
    [ -n "$f" ] || continue
    show_at "$ref" "$f"
  done; } | toks
  set +f
}

if [ -z "$(rulebook_globs)" ]; then
  echo "retired-layer-token: could not read the rulebook list from setup-sites.md — refusing to report clean, because an empty corpus and a clean corpus are the same output" >&2
  exit 2
fi

BASE_SET="$(collect "$BASE")"
THEIRS_SET="$(collect "$THEIRS")"

count_of() { printf '%s\n' "$1" | sed '/^$/d' | wc -l | tr -d ' '; }
listed()   { printf '%s\n' "$1" | sed '/^$/d' | tr '\n' ' ' | sed 's/ $//'; }

# A release that retires nothing has nothing to report. Distinguish that from a rulebook
# that could not be read at base — an unresolvable ref, an unreadable dist — which would
# silently report "retired NO token" for every release.
if [ -z "$BASE_SET" ]; then
  echo "retired-layer-token: could not read any rulebook token at base ($BASE) — refusing to report clean, because 'no tokens' and 'nothing retired' are the same output" >&2
  exit 2
fi
# The mirror, with the opposite polarity: an empty THEIRS side retires everything.
if [ -z "$THEIRS_SET" ]; then
  echo "retired-layer-token: could not read any rulebook token at theirs ($THEIRS) — refusing to report, because 'no tokens at theirs' and 'the release retired every token' are the same output and the second would fill the region with false rows" >&2
  exit 2
fi

# Every word the whole rulebook dropped, split by shape.
DROPPED="$(comm -23 <(printf '%s\n' "$BASE_SET") <(printf '%s\n' "$THEIRS_SET"))"
JOINED="$(printf '%s\n' "$DROPPED" | { grep -E '[-_]' || true; })"
PLAIN="$(printf '%s\n' "$DROPPED" | { grep -vE '[-_]' || true; } | sed '/^$/d')"

# THE PROGRAM WITNESS, per file. Only the plain candidates need one, and there are few,
# so every program file at base is read once and only a file that carries a candidate in
# code is read again at theirs. A file DELETED at theirs witnesses every word it carried —
# the emitter is gone — but a file RENAMED at theirs is byte-identical to a deletion at
# the base path and the opposite conclusion is right, so the rename map is consulted
# first and the new path is read instead. Measured across 321 wide spans: no witness file
# was ever absent at theirs, so this is latent; it is closed because it is cheap.
WITNESSED=""; opened=0
if [ -n "$PLAIN" ]; then
  set -f
  # shellcheck disable=SC2046
  PROGRAMS="$(files_at "$BASE" $(program_globs))"
  set +f
  RENAMES="$(git -C "$DIST" diff -M --name-status --diff-filter=R "$BASE" "$THEIRS" 2>/dev/null | awk -F'\t' '$1 ~ /^R/ {print $2"\t"$3}')"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    b="$(show_at "$BASE" "$f")"
    [ -n "$b" ] || continue
    opened=$((opened + 1))
    hit="$(comm -12 <(printf '%s\n' "$PLAIN") <(printf '%s\n' "$b" | code_toks))"
    [ -n "$hit" ] || continue
    t="$(show_at "$THEIRS" "$f")"
    if [ -z "$t" ]; then
      to="$(printf '%s\n' "$RENAMES" | awk -F'\t' -v f="$f" '$1==f {print $2; exit}')"
      [ -z "$to" ] || t="$(show_at "$THEIRS" "$to")"
    fi
    gone="$(comm -23 <(printf '%s\n' "$hit") <(printf '%s\n' "$t" | code_toks))"
    [ -n "$gone" ] || continue
    WITNESSED="$WITNESSED$gone
"
  done < <(printf '%s\n' "$PROGRAMS")
fi
WITNESSED="$(printf '%s\n' "$WITNESSED" | sed '/^$/d' | sort -u)"
UNWITNESSED="$(comm -23 <(printf '%s\n' "$PLAIN") <(printf '%s\n' "$WITNESSED"))"
RETIRED="$(printf '%s\n%s\n' "$JOINED" "$WITNESSED" | sed '/^$/d' | sort -u)"

# A plain word that left the rulebook is acquitted as emphasis unless a program witnesses
# it. A base at which NO program file could be read cannot witness anything, and that is
# a REFUSAL, not an acquittal: a string the driver discards cannot separate "evaluated and
# found emphasis" from "could not evaluate", so the run exits 2 and the section renders
# DETECTOR-REFUSED like the other unreadable-corpus states.
if [ -n "$PLAIN" ] && [ "$opened" -eq 0 ]; then
  echo "retired-layer-token: $(count_of "$PLAIN") plain word(s) left the rulebook and NO program file was readable at base ($BASE) under $(program_globs | tr '\n' ' ')to witness them — refusing to report, because an unwitnessable word and an acquitted word are the same rows: $(listed "$PLAIN")" >&2
  exit 2
fi
ACQUIT=""
if [ -n "$UNWITNESSED" ]; then
  ACQUIT=" $(count_of "$UNWITNESSED") plain word(s) left the rulebook with no program witness ($opened program file(s) read) and are read as emphasis, not status: $(listed "$UNWITNESSED")."
fi

# The limit that a clean run must restate, because the operator reads the RUN and never
# this header. Both quiet paths below carry it.
LIMIT='A token core never had, a word core still carries anywhere in its rulebook at theirs, a plain word no core program ever printed, and a retired construct the layer file PARAPHRASES are outside this detector BY DESIGN — this zero does not cover them.'

# A ZERO THAT NEVER OPENED A FILE MUST NOT READ LIKE A ZERO THAT SCANNED EVERYTHING.
# This is the branch the contract sibling shipped silent for nine releases: the empty
# retired set exits before any layer file is read, and its stdout is byte-identical to
# a full scan that matched nothing.
if [ -z "$RETIRED" ]; then
  echo "retired-layer-token: NOTE — this release retired NO status token ($(count_of "$BASE_SET") rulebook token(s) at base, $(count_of "$THEIRS_SET") at theirs, $(count_of "$DROPPED") dropped), so NO layer file was opened. This run is SILENT about stale layer tokens, which is not the same as finding none.$ACQUIT $LIMIT" >&2
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
  # A run that found something still says what it declined to look for. Measured on 79
  # row-producing wide spans: 22 also acquitted a plain word, and before this line their
  # stderr was empty — the acquittal was visible exactly on the runs nobody re-reads.
  [ -z "$ACQUIT" ] || echo "retired-layer-token: NOTE —${ACQUIT}" >&2
else
  # The other unqualified zero: tokens WERE retired and every layer file was read, but
  # nothing matched. That is a real result and it still needs its denominator, or it
  # reads the same as a scan that found no files to open.
  echo "retired-layer-token: NOTE — $(count_of "$RETIRED") retired status token(s) ($(listed "$RETIRED")) checked against $scanned layer file(s); no match.$ACQUIT $LIMIT" >&2
fi
exit 0
