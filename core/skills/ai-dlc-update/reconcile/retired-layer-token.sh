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
# declared globs ever printed — it is read as emphasis, and the NOTE names it; measured at
# `origin/main`, 273 of the rulebook's 594 plain capitals have no program witness and would
# be acquitted if retired, `APPROVED` among them, against 321 that do. A vocabulary a layer
# quotes whose OWNER sits outside the rulebook globs — `layer-contract.yaml`'s clause codes,
# `enforcement-map.yaml`'s statuses, the push-candidate ledger's — is seen only where the
# rulebook also spells it; the motivating token reached this corpus because `retro.md` did.
# A SPACE-separated status is matched one word at a time, so a rename that keeps one word
# is reported on the word that changed; a hyphen or underscore CHAIN is one token on both
# sides, so a chain renamed in one segment is retired whole and a layer carrying only its
# prefix or one segment is NOT flagged. And a retired construct the layer file PARAPHRASES
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
# shellcheck source=lib.sh
# NOT `|| exit 1`: every call site below falls back to a direct `git` call when the memo
# helpers are unavailable (see files_at/show_at), matching this script's own contract.
. "$SELF/lib.sh" 2>/dev/null || true
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
# The separator pass is staged ALONE and its status read: in a pipeline under the caller's
# pipefail, a `tr` that died presented as the grep's 1 on empty input, accepted as "no token".
# The grep's 1 is an empty set (status 0); anything above it, or a failed sort, is returned.
toks() {
  local _w _t _rc=0
  _w="$(tr -c 'A-Za-z0-9_-' '\n')" || return
  _t="$(printf '%s\n' "$_w" | grep -E '^[A-Z][A-Z0-9_]{3,}(-[A-Z0-9_]+)*$')" || _rc=$?
  [ "$_rc" -le 1 ] || return "$_rc"
  [ -n "$_t" ] || return 0
  printf '%s\n' "$_t" | sort -u
}
# The same over a program: comment lines are dropped first, because a script's header
# routinely documents the token it just retired (the retirement is WHY the comment is
# there), and a word that survives only in prose about its removal is still retired.
#
# THE COMMENT STRIP'S STATUS IS READ ON ITS OWN. It was `grep -vE … | toks`, read under pipefail
# by a caller accepting 0 or 1: a strip that DIED (2) handed toks empty input, toks' grep returned
# 1, and the dead scan was accepted as "this program carries no token". Its 1 is a program that is
# all comments -- an empty set, status 0 -- and anything above 1 is returned.
code_toks() {
  local _code _rc=0
  _code="$(grep -vE '^[[:space:]]*#')" || _rc=$?
  [ "$_rc" -le 1 ] || return "$_rc"
  [ -n "$_code" ] || return 0
  printf '%s\n' "$_code" | toks
}

# files_at <ref> <glob>... -> every path in the tree at <ref> matching one of the globs.
# `set -f` IS LOAD-BEARING, the same defect both siblings carry a note about: these are
# PATHSPECS, and unquoted in `for` they are subject to shell pathname expansion first, so
# a caller whose cwd contains matching files gets real paths from the WRONG tree and a
# rulebook file that exists at the ref but not in the cwd is silently skipped.
#
# A 125 FROM THE MEMO IS A REFUSAL, NEVER AN EMPTY TREE OR AN EMPTY BLOB. 125 is lib.sh's "the
# cached answer could not be SERVED" sentinel: a `.c` that cannot be read, a `.s` that is empty or
# malformed. Both readers used to swallow it -- `files_at`'s `|| return 0`, `show_at`'s `|| true` --
# and a memo that lost ONE blob then decided the rows. Measured on this fixture's world with one
# key's `.c` unreadable, every run exit 0: a theirs rulebook blob lost printed a FALSE row
# (`MEASURED`, `MOVER-TOKEN`, `LEDGER-ROW`), the base witness program lost deleted five true rows,
# and a base rulebook blob lost printed the retired-nothing NOTE. So 125 returns
# 125 from here and every caller refuses by name, exit 2. Any OTHER failure keeps its old meaning:
# an unresolvable ref lists nothing, and the empty-set guards below refuse that with their own
# message; a blob git could not show is the caller's to read (see the witness loop).
files_at() {
  local ref="$1" glob tree _ft=0; shift
  if command -v memo_ls_tree >/dev/null 2>&1; then tree="$(memo_ls_tree "$DIST" "$ref")" || _ft=$?
  else tree="$(git -C "$DIST" -c core.quotePath=false ls-tree -r --name-only "$ref" 2>/dev/null)" || _ft=$?; fi
  [ "$_ft" -ne 125 ] || return 125
  [ "$_ft" -eq 0 ] || return 0
  set -f
  for glob in "$@"; do
    printf '%s\n' "$tree" \
      | { grep -E "^$(printf '%s' "$glob" | sed 's/\./\\./g; s/\*/[^\/]*/g')$" || true; }
  done
  set +f
}
# show_at <ref> <path> -- the blob on stdout and the reader's own status: 0, git's non-zero for a
# path it could not show, or the memo's 125. Every caller reads it.
show_at() {
  if command -v memo_show >/dev/null 2>&1; then memo_show "$DIST" "$1" "$2"
  else git -C "$DIST" show "${1}:${2}" 2>/dev/null; fi
}

# collect <ref> -> every rulebook token at that ref; 125 when the listing or a listed file could
# not be served by the memo. Runs inside `$( )`, so it RETURNS the status and the caller refuses:
# an exit here would end only the capture. The two PRODUCER stages are read by index and the
# last stage's status is the function's otherwise, as it always was -- this file does not set
# `pipefail`, and a filter stage's "no match" is not a read failure.
collect() {
  local ref="$1" f
  set -f
  local _cs _ps
  # shellcheck disable=SC2046
  files_at "$ref" $(rulebook_globs) | { set +f; while IFS= read -r f; do
    [ -n "$f" ] || continue
    show_at "$ref" "$f"
    _cs=$?; [ "$_cs" -ne 125 ] || exit 125
  done; } | toks
  _ps=("${PIPESTATUS[@]}")
  set +f
  [ "${_ps[0]}" -ne 125 ] || return 125
  [ "${_ps[1]}" -ne 125 ] || return 125
  return "${_ps[${#_ps[@]}-1]}"
}

if [ -z "$(rulebook_globs)" ]; then
  echo "retired-layer-token: could not read the rulebook list from setup-sites.md — refusing to report clean, because an empty corpus and a clean corpus are the same output" >&2
  exit 2
fi

# rlt_read_refuse <what> <status> -- a corpus read that failed. 125 is named as the memo's.
rlt_read_refuse() {
  if [ "$2" -eq 125 ]; then
    echo "retired-layer-token: REFUSED — $1 could not be served by the reconcile memo (lib.sh exit 125: a cached blob or status that cannot be read); refusing, because a corpus with a file missing reports rows that are not there and drops rows that are" >&2
  else
    echo "retired-layer-token: REFUSED — $1 could not be read (exit $2); refusing, because a corpus with a file missing reports rows that are not there and drops rows that are" >&2
  fi
  exit 2
}
_cs=0; BASE_SET="$(collect "$BASE")" || _cs=$?
[ "$_cs" -eq 0 ] || rlt_read_refuse "the rulebook at base ($BASE)" "$_cs"
_cs=0; THEIRS_SET="$(collect "$THEIRS")" || _cs=$?
[ "$_cs" -eq 0 ] || rlt_read_refuse "the rulebook at theirs ($THEIRS)" "$_cs"

# EVERY SET OPERAND AND LOOP FEED BELOW IS STAGED TO A FILE AND ITS PRODUCER'S STATUS IS READ.
# They used to read `comm <(…) <(…)` and `done < <(…)`, which discard the producer's status: a
# failed `comm` over the two rulebook sets read as an empty retired set and took the quiet NOTE
# path, exit 0, over a release that retired some -- a false clear -- and a failed side of a program-witness
# intersection read as "no program witnesses this word", which acquits a status as emphasis.
# This file does not set `pipefail`; the token pipelines are staged inside `( set -o pipefail;
# … )`, where `code_toks`' grep exits 1 on a program carrying no token -- a healthy empty set --
# so 0 and 1 are accepted there and anything else refuses. Exit 2 is this detector's existing
# refusal, which the driver renders as DETECTOR-REFUSED. One directory per run, one file per
# site; the needle file below moves into it, so the file's one EXIT trap stays one.
RLT_T="$(mktemp -d "${TMPDIR:-/tmp}/retired-layer-token.XXXXXX")" || {
  echo "retired-layer-token: the staging directory did not run (mktemp failed); no verdict" >&2
  exit 2
}
trap 'rm -rf "$RLT_T"' EXIT
rlt_refuse() { # rlt_refuse <what> <status>
  echo "retired-layer-token: $1 did not run (exit $2); refusing, because a set that was never computed and an empty one are the same rows" >&2
  exit 2
}
# rlt_toks <text> <out> -- code_toks of <text> into <out>; 0 and 1 accepted (see above).
rlt_toks() {
  local rc=0
  ( set -o pipefail; printf '%s\n' "$1" | code_toks ) > "$2" || rc=$?
  case "$rc" in 0|1) return 0 ;; esac
  rlt_refuse "the program token scan" "$rc"
}

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
printf '%s\n' "$BASE_SET" > "$RLT_T/set-base" || rlt_refuse "staging the base token set" "$?"
printf '%s\n' "$THEIRS_SET" > "$RLT_T/set-theirs" || rlt_refuse "staging the theirs token set" "$?"
DROPPED="$(comm -23 "$RLT_T/set-base" "$RLT_T/set-theirs")" || rlt_refuse "the dropped-token subtraction" "$?"
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
  _cs=0; PROGRAMS="$(files_at "$BASE" $(program_globs))" || _cs=$?
  set +f
  [ "$_cs" -eq 0 ] || rlt_read_refuse "the program file list at base ($BASE)" "$_cs"
  # `core.quotePath=false`: under the default a renamed non-ASCII path arrives C-quoted, the
  # `$1==f` join below never matches the raw path `files_at` listed, and a renamed witness reads
  # as a DELETED one -- which retires a word the renamed program still prints.
  RENAMES="$(git -C "$DIST" -c core.quotePath=false diff -M --name-status --diff-filter=R "$BASE" "$THEIRS" 2>/dev/null | awk -F'\t' '$1 ~ /^R/ {print $2"\t"$3}')"
  # Staged, never a here-string: a `<<<` that could not be staged fed the lookup EMPTY, so a
  # renamed witness read as deleted. The write's status is read.
  printf '%s\n' "$RENAMES" > "$RLT_T/renames" || rlt_refuse "staging the rename map" "$?"
  printf '%s\n' "$PLAIN" > "$RLT_T/plain" || rlt_refuse "staging the plain candidate set" "$?"
  printf '%s\n' "$PROGRAMS" > "$RLT_T/programs" || rlt_refuse "staging the program file list" "$?"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # Only the memo's 125 refuses in this loop. A program git cannot show keeps its old reading
    # -- skipped here, and the opened-nothing refusal below catches a base where every one was.
    _cs=0; b="$(show_at "$BASE" "$f")" || _cs=$?
    [ "$_cs" -ne 125 ] || rlt_read_refuse "the program $f at base ($BASE)" 125
    [ -n "$b" ] || continue
    opened=$((opened + 1))
    rlt_toks "$b" "$RLT_T/prog-base-toks"
    hit="$(comm -12 "$RLT_T/plain" "$RLT_T/prog-base-toks")" || rlt_refuse "the witness intersection for $f" "$?"
    [ -n "$hit" ] || continue
    # A program ABSENT at theirs is git's 128 and an empty text -- the deletion this loop reads
    # as a witness. Only the memo's 125 refuses.
    _cs=0
    t="$(show_at "$THEIRS" "$f")" || _cs=$?
    [ "$_cs" -ne 125 ] || rlt_read_refuse "the program $f at theirs ($THEIRS)" 125
    if [ -z "$t" ]; then
      to="$(awk -F'\t' -v f="$f" '$1==f {print $2; exit}' "$RLT_T/renames")" || rlt_refuse "the rename lookup for $f" "$?"
      _cs=0; [ -z "$to" ] || t="$(show_at "$THEIRS" "$to")" || _cs=$?
      [ "$_cs" -ne 125 ] || rlt_read_refuse "the program $to at theirs ($THEIRS)" 125
    fi
    printf '%s\n' "$hit" > "$RLT_T/prog-hit" || rlt_refuse "staging the witnessed candidates for $f" "$?"
    rlt_toks "$t" "$RLT_T/prog-theirs-toks"
    gone="$(comm -23 "$RLT_T/prog-hit" "$RLT_T/prog-theirs-toks")" || rlt_refuse "the witness subtraction for $f" "$?"
    [ -n "$gone" ] || continue
    WITNESSED="$WITNESSED$gone
"
  done < "$RLT_T/programs"
fi
WITNESSED="$(printf '%s\n' "$WITNESSED" | sed '/^$/d' | sort -u)"
printf '%s\n' "$PLAIN" > "$RLT_T/plain-all" || rlt_refuse "staging the plain candidate set" "$?"
printf '%s\n' "$WITNESSED" > "$RLT_T/witnessed" || rlt_refuse "staging the witnessed set" "$?"
UNWITNESSED="$(comm -23 "$RLT_T/plain-all" "$RLT_T/witnessed")" || rlt_refuse "the unwitnessed subtraction" "$?"
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
NEEDLES="$RLT_T/needles"
printf '%s\n' "$RETIRED" > "$NEEDLES" || rlt_refuse "staging the retired token set" "$?"

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
