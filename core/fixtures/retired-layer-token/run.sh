#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# retired-layer-token/run.sh — prove the token detector fires on a status word a release
# retired and a layer file still carries, stays quiet on the four shapes that merely look
# like one, and never emits a zero that cannot be told from a scan that opened nothing.
#
# Usage: run.sh   (from any cwd)
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH. Measured on the reference consumer's 0.373.0 -> 0.378.0
# pull: core renamed a validator status, an override's RENDERED body and a grep control in
# another entry's frontmatter both still named the old word, and every mechanical signal
# was clean — the contract sibling matches SHAPES, the passage sibling matches whole core
# LINES, and a consumer sentence that merely REUSES a retired word is neither. A person
# found it by grepping.
#
# AND THE DEFECT THE SECOND HALF EXISTS TO CATCH. A rulebook-only set difference is not a
# retirement test: over wide spans it calls every emphasis word a status. The two witnesses
# — a JOINED shape, or a core PROGRAM that stopped emitting the word IN THAT FILE — are
# what separate a status from a shout, and each of them has a world below that only it
# survives. The per-file half of the program witness is load-bearing on the motivating pull
# itself, where a second program still prints the word in an unrelated sense.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
# `exit` inside `$( )` ends the subshell and not this script, so a refusing seed hands back
# an empty path. That must read as BROKEN, never as a regression.
[ -n "$WORK" ] && [ -d "$WORK" ] || { echo "FIXTURE ERROR: seed produced no workspace" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

TAB="$(printf '\t')"
L=".claude/skills/ai-dlc"
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
[ -f "$HERE/../lib/inproc.sh" ] || { echo "FIXTURE ERROR: lib/inproc.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: sourcing lib/inproc.sh failed" >&2; exit 2; }

echo "retired-layer-token:"
echo "HERMETIC-CONSUMED $SCRIPT"

# IN PROCESS (BL-878). retired-layer-token.sh is loadable: sourcing it defines rlt_main and returns at its column-0
# guard. It is loaded ONCE (below) and `rlt_eng "$SCRIPT" <args>` answers what `bash "$SCRIPT" <args>` prints, in a
# subshell made to look like a fresh bash. The orphan arm sources its copy inside its own subshell first, so the
# rlt_main that runs there looks for setup-sites.md beside the copy exactly as the program did. A caller's `cd` and
# prefix assignments reach the run as they reached the child.
# THE BLOB MEMO. A CLI run sources lib.sh at the top of its own process and so builds a private memo for that one run;
# in a subshell lib.sh does not (it keys on `$BASH_SUBSHELL` 0). So `rlt_eng` hands each run a FRESH memo, as private
# to that run as the CLI's, unless the caller exported one (the memo cells do).
# KEPT AS PROGRAMS, and why: the cli cells (one per distinct CLI outcome), the forced rename-map run under `ulimit -f`
# (e2e), the driver emit-report.sh's two runs (e2e: the property is the driver reading the detector's exit as a
# separate program; its detector child is the `nested` row), and the `env -i` run, which the counter cannot see (a
# bare environment drops BASH_ENV) and whose property is that bare environment.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped subject, and
# sourcing a pre-wrap subject would run its whole body in this shell. So the shape is checked first, on its two halves:
# neither the `rlt_main() {` line nor the column-0 source guard is a subject that predates the wrap, which prints SKIP
# and exits 0 -- never an ok. Exactly one half is a respelled subject this fixture can no longer drive, which FAILS.
rlt_def=0; rlt_guard=0
grep -q '^rlt_main() {$' "$SCRIPT"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SCRIPT (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || rlt_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$SCRIPT"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SCRIPT (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || rlt_guard=1
if [ "$rlt_def$rlt_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE"; fi
if [ "$rlt_def" = 0 ]; then echo "   FAIL  $SCRIPT carries the column-0 source guard but no \`rlt_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "retired-layer-token: FAIL (1)" >&2; exit 1; fi
if [ "$rlt_guard" = 0 ]; then echo "   FAIL  $SCRIPT defines \`rlt_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run rlt_main in this shell" >&2; echo "retired-layer-token: FAIL (1)" >&2; exit 1; fi
# The subject is loaded once by core/fixtures/lib/inproc.sh and `rlt_eng` answers through its inproc_run: a fresh-bash
# subshell that keeps only the loaded definitions, unsets every UNEXPORTED variable a fresh bash does not start with, and
# logs one fx_inproc pass. Exported variables, prefix assignments included, stay.
inproc_load "$SCRIPT" || { echo "FIXTURE BROKEN: sourcing $SCRIPT defined nothing" >&2; exit 2; }
declare -F rlt_main >/dev/null || { echo "FIXTURE BROKEN: $SCRIPT defined no rlt_main when sourced" >&2; exit 2; }
rlt_eng() { # <engine> [args...] -> what `bash <engine> [args...]` prints and exits with; <engine> must be $SCRIPT
  local _m _rc
  [ "$1" = "$SCRIPT" ] || { echo "rlt_eng: engine $1 is not the loaded subject" >&2; return 125; }
  shift
  case "$(declare -p AI_DLC_RECONCILE_MEMO 2>/dev/null)" in
    "declare -x"*) inproc_run "$SCRIPT" rlt_main "$@"; return ;;
  esac
  _m="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX")" || return 125
  AI_DLC_RECONCILE_MEMO="$_m" inproc_run "$SCRIPT" rlt_main "$@"; _rc=$?
  rm -rf "$_m"
  return "$_rc"
}

ok "resolved detector: $SCRIPT"

# --- the five worlds every scored script is driven through --------------------------------
# EVERY drive names its own cwd. The predicates below must answer the same from the repo
# root and from a scratch directory, and one of them is ABOUT the cwd, so the cwd cannot be
# whatever the suite happened to hand this fixture.
BADREF=0000000000000000000000000000000000000000
# The exit code is part of the contract now — 0 reports, 2 refuses — and the driver renders
# a refusing section as DETECTOR-REFUSED rather than `none`. A world that did not record its
# rc could not tell the two apart, which is the same defect one level up.
drive() {  # cwd script dist base theirs consumer out-prefix
  ( cd "$1" || exit 99
    rlt_eng "$2" "$3" "$4" "$5" "$6" >"$7.out" 2>"$7.err"
    echo $? > "$7.rc" ) &
}
snap() {  # 1=script 2=snapshot dir
  mkdir -p "$2"
  drive "$NEUTRAL"  "$1" "$DIST"  "$BASE"  "$THEIRS"  "$CONSUMER" "$2/main"
  drive "$TRAP_CWD" "$1" "$DIST"  "$BASE"  "$THEIRS"  "$CONSUMER" "$2/trap"
  drive "$NEUTRAL"  "$1" "$DIST"  "$BASE"  "$BASE"    "$CONSUMER" "$2/noop"
  drive "$NEUTRAL"  "$1" "$DIST"  "$BASE"  "$THEIRS"  "$CLEANC"   "$2/clean"
  drive "$NEUTRAL"  "$1" "$DIST2" "$BASE2" "$THEIRS2" "$CLEANC"   "$2/undec"
  drive "$NEUTRAL"  "$1" "$DIST"  "$BASE"  "$BADREF"  "$CONSUMER" "$2/badt"
  wait
}
rc_of() { cat "$1" 2>/dev/null || echo 99; }

# --- the predicates -----------------------------------------------------------------------
# Each is PRESENCE-shaped: it demands a specific row or message. A subject replaced by
# `exit 0` fails every one of them by construction, which is what stops silence scoring as
# a pass. The three absence arms carry `rows_present` as their positive conjunct.
rows_present() { grep -qF 'RETIRED-LAYER-TOKEN' "$1/main.out"; }

# 1. the incident's first line: a retired status word in an override's RENDERED body.
q1()  { grep -qE "^RETIRED-LAYER-TOKEN${TAB}${L}/overrides/body\.md:${BODY_LINE}${TAB}VACUOUS$" "$1/main.out"; }
# 2. the incident's second line: the same word inside a `reason:` above the closing `---`.
q2()  { grep -qE "^RETIRED-LAYER-TOKEN${TAB}${L}/extensions/front\.md:${FRONT_LINE}${TAB}VACUOUS$" "$1/main.out"; }
# 3. the four near-misses. Lowercase, embedded in a longer identifier both ways, joined to a
#    lowercase segment by a hyphen, and a three-letter capital the grammar never derives.
q3()  { rows_present "$1" && ! grep -qE 'nm-(lower|embed|hyphen)\.md' "$1/main.out"; }
# 4. a token that MOVED between two rulebook files is present at theirs and not dropped.
q4()  { rows_present "$1" && ! grep -qF 'moved.md' "$1/main.out"; }
# 5. an emphasis word a release thins out of one sentence and still carries elsewhere.
q5()  { rows_present "$1" && ! grep -qF 'emphasis.md' "$1/main.out"; }
# 6. base == theirs: no rows, and a zero that SAYS it opened no layer file. This is the
#    branch the contract sibling shipped silent for nine releases.
q6()  { [ ! -s "$1/noop.out" ] && [ "$(rc_of "$1/noop.rc")" = "0" ] \
        && grep -qF 'NO layer file was opened' "$1/noop.err" \
        && ! grep -qF 'refusing to report clean' "$1/noop.err"; }
# 7. scanned-but-no-match states BOTH counts, and the two are bound to each other: the
#    printed token count must equal the length of the list it prints, and the file count is
#    read from a world with exactly one layer file, which is a different number.
q7()  {
  local meta n rest nf list
  [ ! -s "$1/clean.out" ] || return 1
  [ "$(rc_of "$1/clean.rc")" = "0" ] || return 1
  meta="$(sed -n 's/^retired-layer-token: NOTE [^0-9]*\([0-9][0-9]*\) retired status token(s) (\([^)]*\)) checked against \([0-9][0-9]*\) layer file(s).*/\1 \3 \2/p' "$1/clean.err")"
  [ -n "$meta" ] || return 1
  n="${meta%% *}"; rest="${meta#* }"; nf="${rest%% *}"; list="${rest#* }"
  [ "$n" -ge 1 ] && [ "$nf" -eq 1 ] \
    && [ "$(printf '%s' "$list" | wc -w | tr -d ' ')" -eq "$n" ]
}
# 8. the rulebook globs are PATHSPECS. Driven from a cwd that carries files matching them
#    under other names, the answer must not move.
q8()  { [ -s "$1/trap.out" ] && cmp -s "$1/trap.out" "$1/main.out"; }
# 9. a .json layer file is scanned; a .txt one is not.
q9()  { grep -qE "^RETIRED-LAYER-TOKEN${TAB}${L}/extensions/layer\.json:${JSON_LINE}${TAB}" "$1/main.out" \
        && ! grep -qF 'notes.txt' "$1/main.out"; }
# 10. a PLAIN word that left the rulebook with no program witness is read as emphasis and
#     is NOT flagged. Its acquittal being NAMED is a separate cell (14) on purpose: a
#     mutation that retires it and one that mislabels it are different defects, and folded
#     into one predicate they produce the same vector.
q10() { rows_present "$1" && ! grep -qF 'never.md' "$1/main.out"; }
# 11. a JOINED token no core program ever printed is retired on its shape alone.
q11() { grep -qE "^RETIRED-LAYER-TOKEN${TAB}${L}/extensions/joined\.md:${JOINED_LINE}${TAB}APPROVED-WITH-FIXES$" "$1/main.out"; }
# 12. the comment strip, in BOTH directions in one cell: a word named only in a program
#     COMMENT at base witnesses nothing, and a word whose only surviving mention at theirs
#     is a comment documenting its removal is still retired.
q12() { grep -qE "^RETIRED-LAYER-TOKEN${TAB}${L}/overrides/deferred\.md:${DEFERRED_LINE}${TAB}DEFERRED$" "$1/main.out" \
        && ! grep -qF 'stale.md' "$1/main.out"; }
# 13. a base at which NO program file could be read cannot witness anything, and that is a
#     limit of the run, not a finding of emphasis.
q13() { [ "$(rc_of "$1/undec.rc")" = "2" ] && [ ! -s "$1/undec.out" ] \
        && grep -qE 'NO program file was readable at base.*NEVER' "$1/undec.err"; }
# 14. the acquitted set is named as an EXACT list. A witness that quietly widens or narrows
#     acquits or convicts a word with no other observable — the rows do not move, and only
#     this line says so.
q14() { grep -qF 'read as emphasis, not status: NEVER STALE.' "$1/clean.err"; }
# 15. the grammar's four-character floor. The three-letter word is PRINTED BY A PROGRAM, so
#     the floor is the only thing keeping it out — a short word with no program behind it is
#     acquitted by the witness and proves nothing about the floor.
q15() { rows_present "$1" && ! grep -qF 'nm-short.md' "$1/main.out"; }
# 16. the second moved token, whose new home is a rulebook file that exists only at theirs.
#     A theirs-side file list taken from the base tree cannot see it.
q16() { rows_present "$1" && ! grep -qF 'mover.md' "$1/main.out"; }
# 17. an unresolvable THEIRS empties the theirs side, which makes EVERY rulebook token look
#     retired — a maximal false report, not a silent one. It must refuse with exit 2 and no
#     rows, and `main` is the control that the same call with a good theirs does report.
q17() { [ "$(rc_of "$1/badt.rc")" = "2" ] && [ ! -s "$1/badt.out" ] \
        && grep -qF 'could not read any rulebook token at theirs' "$1/badt.err"; }

# Each predicate is named literally, never through a variable command word: P2 (validate-fixture-invocations.sh) reads
# a `"$p"` call after the subject's source as a possible unrouted in-process drive (fail-closed).
vec() { local v="" b
  for b in "$(q1 "$1" && echo 1 || echo 0)" "$(q2 "$1" && echo 1 || echo 0)" "$(q3 "$1" && echo 1 || echo 0)" \
           "$(q4 "$1" && echo 1 || echo 0)" "$(q5 "$1" && echo 1 || echo 0)" "$(q6 "$1" && echo 1 || echo 0)" \
           "$(q7 "$1" && echo 1 || echo 0)" "$(q8 "$1" && echo 1 || echo 0)" "$(q9 "$1" && echo 1 || echo 0)" \
           "$(q10 "$1" && echo 1 || echo 0)" "$(q11 "$1" && echo 1 || echo 0)" "$(q12 "$1" && echo 1 || echo 0)" \
           "$(q13 "$1" && echo 1 || echo 0)" "$(q14 "$1" && echo 1 || echo 0)" "$(q15 "$1" && echo 1 || echo 0)" \
           "$(q16 "$1" && echo 1 || echo 0)" "$(q17 "$1" && echo 1 || echo 0)"; do v="$v$b"; done
  printf '%s' "$v"; }

CTL="$WORK/snap-control"
snap "$SCRIPT" "$CTL"

# --- Assertion 0: SANITY ------------------------------------------------------------------
# Every negative assertion below would score a false pass against a detector emitting
# nothing at all, which is exactly how the contract sibling's blind spot survived nine
# releases.
if [ -s "$CTL/main.out" ]; then
  ok "the detector produced output against a layer corpus carrying a retired status token"
else
  bad "FIXTURE BROKEN — no output at all; every assertion below would be a false pass"
  echo; echo "retired-layer-token: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 0b: the absence arms have a SUBJECT ----------------------------------------
# A fixture whose tree cannot EXPRESS the defect proves nothing. Every file an arm below
# asserts is NOT flagged has to exist and carry the word it is a near-miss for.
missing=""
for pair in \
  "overrides/nm-lower.md:vacuous" "overrides/nm-embed.md:fooVACUOUS" \
  "overrides/nm-embed.md:VACUOUS_X" "overrides/nm-embed.md:fooVACUOUSbar" \
  "overrides/nm-hyphen.md:x-VACUOUS" \
  "overrides/nm-short.md:ABC" "extensions/moved.md:LEDGER-ROW" \
  "overrides/mover.md:MOVER-TOKEN" \
  "overrides/emphasis.md:MEASURED" "overrides/never.md:NEVER" \
  "overrides/stale.md:STALE" "overrides/notes.txt:VACUOUS"; do
  f="$CONSUMER/$L/${pair%%:*}"; w="${pair##*:}"
  { [ -f "$f" ] && grep -qF "$w" "$f"; } || missing="$missing ${pair}"
done
[ -z "$missing" ] \
  && ok "every not-flagged file exists and carries its word, so the absence arms have subjects" \
  || bad "seed cannot express the near-misses:$missing"

# --- the thirteen worlds, each as its own arm ----------------------------------------------
q1  "$CTL" && ok "a retired status word in an override's RENDERED body is flagged, with its line" \
           || bad "the rendered-body use of the retired word was NOT flagged"
q2  "$CTL" && ok "  and the same word in a frontmatter reason: line gets its own row" \
           || bad "  the frontmatter use was not flagged — the scan is body-only"
q11 "$CTL" && ok "a JOINED token no core program printed is retired on its shape alone" \
           || bad "a dropped hyphenated verdict token was not flagged — the joined-shape witness is gone"
q12 "$CTL" && ok "a comment is not an emission: base-comment-only acquits, theirs-comment-only still retires" \
           || bad "the comment strip regressed in one of its two directions"
q3  "$CTL" && ok "lowercase, fooVACUOUS, VACUOUS_X, fooVACUOUSbar and x-VACUOUS are NOT flagged" \
           || bad "a near-miss was flagged — the layer side is matching substrings, not words"
q15 "$CTL" && ok "a THREE-letter capital a core program prints is below the grammar's floor" \
           || bad "a three-letter word was flagged — the four-character floor is gone"
q4  "$CTL" && ok "a token that MOVED to another rulebook file is not retired" \
           || bad "a moved token was flagged — retirement is being read per rulebook FILE"
q16 "$CTL" && ok "  and one that moved into a file created AT THEIRS is not retired either" \
           || bad "  a token moved into a theirs-only file was flagged — the theirs file list is the base tree's"
q5  "$CTL" && ok "an emphasis word thinned from one sentence and kept elsewhere is not retired" \
           || bad "a surviving emphasis word was flagged — the dropped set is being read from a diff"
q10 "$CTL" && ok "a plain word with no program witness is acquitted as emphasis, not flagged" \
           || bad "an unwitnessed plain word was flagged — the witness is not gating the retired set"
q14 "$CTL" && ok "  and the acquitted words are named on stderr, as an exact list" \
           || bad "  the acquittal is silent or names the wrong set — a widened witness has no other tell"
q9  "$CTL" && ok "a .json layer file is scanned and a .txt one is not" \
           || bad "the layer corpus is the wrong set of extensions"
q6  "$CTL" && ok "base == theirs reports nothing and SAYS it opened no layer file" \
           || bad "a release retiring nothing produced a silent zero — the sibling's exact defect"
q7  "$CTL" && ok "scanned-but-no-match states both counts, and the token count matches its own list" \
           || bad "the denominator NOTE is missing, or its count disagrees with the list beside it"
q13 "$CTL" && ok "a base with NO readable program file REFUSES with exit 2 and names the words, rather than acquitting them" \
           || bad "an unwitnessable base was reported as though the words had been acquitted"
q8  "$CTL" && ok "driven from a cwd full of rulebook-shaped files, the rows do not move" \
           || bad "the cwd changed the answer — the rulebook pathspecs are being glob-expanded"

q17 "$CTL" && ok "an unresolvable THEIRS refuses with exit 2 and no rows, where the same call with a good theirs reports" \
           || bad "an unresolvable theirs emptied the theirs side and retired the whole rulebook, or refused with the wrong code"

# --- Assertion 14: an unreadable rulebook list REFUSES, with exit 2 ------------------------
# The corpus is read from setup-sites.md beside the script. If that read fails the retired
# set is empty and the run would otherwise be indistinguishable from a release that retired
# nothing. The exit code is the half the DRIVER reads: a 0 renders as `none`.
mkdir -p "$WORK/orphan"
cp "$SCRIPT" "$WORK/orphan/retired-layer-token.sh"
# In process: the copy is sourced inside this arm's own subshell, so the rlt_main it defines is the COPY's, whose
# `${BASH_SOURCE[0]}` -- and so its setup-sites.md -- is the orphan directory; the location stays the property.
ORPHERR="$( cd "$NEUTRAL" && . "$WORK/orphan/retired-layer-token.sh" && rlt_eng "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>&1 >/dev/null )"; ORPHRC=$?
{ grep -qF 'could not read the rulebook list from setup-sites.md' <<<"$ORPHERR" && [ "$ORPHRC" -eq 2 ]; } \
  && ok "a copy with no setup-sites.md beside it refuses, and exits 2" \
  || bad "an unreadable rulebook list produced no warning or did not exit 2 (rc=$ORPHRC) — the driver would render it as 'none'"

# --- Assertion 15: a base ref that does not resolve is a REFUSAL, never the NOTE -----------
BADERR="$( cd "$NEUTRAL" && rlt_eng "$SCRIPT" "$DIST" "$BADREF" "$THEIRS" "$CONSUMER" 2>&1 >/dev/null )"; BADRC=$?
{ grep -qF 'could not read any rulebook token at base' <<<"$BADERR" \
  && ! grep -qF 'NOTE' <<<"$BADERR" && [ "$BADRC" -eq 2 ]; } \
  && ok "an unresolvable base ref refuses with exit 2, and does not print the retired-nothing NOTE" \
  || bad "an unresolvable base ref reported as a release that retired nothing, or did not exit 2 (rc=$BADRC)"

# --- Assertion 16: the DRIVER renders a refusal as DETECTOR-REFUSED, never as `none` -------
# The exit code above only matters because emit-report.sh reads it. Both halves are driven
# here, one property apart: the same command with a resolvable theirs must render ROWS and
# no refusal line, or the arm below would pass against a driver that refuses unconditionally.
EMITSH="$(dirname "$SCRIPT")/emit-report.sh"
if [ -f "$EMITSH" ]; then
  echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/emit-report.sh"
  sect() { awk '/Retired status tokens reused/{f=1;next} f&&/^\*\*/{exit} f'; }
  # KEPT END TO END (cells.decl e2e-emit-ok, e2e-emit-bad): the property is the DRIVER reading this detector's exit
  # code as a separate program; the detector start each makes is covered by the `nested` row.
  EM_OK="$( cd "$NEUTRAL" && FXCELL=e2e-emit-ok bash "$EMITSH" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | sect )"
  EM_BAD="$( cd "$NEUTRAL" && FXCELL=e2e-emit-bad bash "$EMITSH" "$DIST" "$BASE" "$CONSUMER" "$BADREF" 2>/dev/null | sect )"
  { grep -qF 'overrides/body.md' <<<"$EM_OK" && ! grep -qF 'DETECTOR-REFUSED' <<<"$EM_OK"; } \
    && ok "the driver renders this detector's rows into its own section when the detector reports" \
    || bad "the driver rendered no row for a reporting detector — the refusal arm below cannot discriminate"
  { grep -qF 'DETECTOR-REFUSED' <<<"$EM_BAD" && ! grep -qx 'none' <<<"$EM_BAD"; } \
    && ok "  and renders DETECTOR-REFUSED, not 'none', when it refuses" \
    || bad "  a refusing detector rendered as a clean section (got: $(printf '%s' "$EM_BAD" | tr '\n' ' ' | head -c 100))"
else
  bad "emit-report.sh is not beside the detector — the driver half of the refusal contract is unasserted"
fi

# --- Assertion 16: the row survives a C locale over a line carrying an em-dash -------------
# `env -i` strips the locale the interactive shell supplies; the detector forces LC_ALL=C
# itself, and a multibyte character on the flagged line must not shift the line number or
# swallow the word.
EMOUT="$( cd "$NEUTRAL" && env -i PATH=/usr/bin:/bin bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null )"
grep -qE "^RETIRED-LAYER-TOKEN${TAB}${L}/overrides/emdash\.md:${EMDASH_LINE}${TAB}VACUOUS$" <<<"$EMOUT" \
  && ok "under env -i, a flagged line carrying em-dashes still names the right line" \
  || bad "the em-dash line was lost or renumbered under a bare environment"

CTLVEC="$(vec "$CTL")"
if [ "$CTLVEC" = "11111111111111111" ]; then
  ok "control: every predicate holds (11111111111111111)"
else
  bad "control: $CTLVEC -- expected 11111111111111111"
fi

# --- the cli cells (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome --------------------------
# The outcomes: exit 0 with rows, and exit 2 with the refusal on stderr. One `FXCELL=<id> bash "$SCRIPT"` start per
# outcome, from the same cwd and on the same input as the control snapshot's in-process `main` and `badt` worlds, and
# compared with them: stdout, stderr and exit, byte for byte. Each also asserts its own outcome, so two runs that both
# printed nothing cannot read as equivalent.
( cd "$NEUTRAL" && FXCELL=cli-rows bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" > "$WORK/cli-rows.out" 2> "$WORK/cli-rows.err"; echo $? > "$WORK/cli-rows.rc" )
if [ "$(rc_of "$WORK/cli-rows.rc")" = 0 ] && q1 "$CTL" && grep -qF 'RETIRED-LAYER-TOKEN' "$WORK/cli-rows.out" \
   && cmp -s "$CTL/main.out" "$WORK/cli-rows.out" && cmp -s "$CTL/main.err" "$WORK/cli-rows.err" && cmp -s "$CTL/main.rc" "$WORK/cli-rows.rc"; then
  ok "cli-rows: the program reports the retired-token rows exactly as the in-process call does (stdout, stderr, exit 0)"
else
  bad "cli-rows: the program (rc=$(rc_of "$WORK/cli-rows.rc"), $(grep -c . "$WORK/cli-rows.out") rows) and the in-process call (rc=$(rc_of "$CTL/main.rc"), $(grep -c . "$CTL/main.out") rows) differ, or the outcome is not exit 0 with rows"
fi
( cd "$NEUTRAL" && FXCELL=cli-refuse bash "$SCRIPT" "$DIST" "$BASE" "$BADREF" "$CONSUMER" > "$WORK/cli-refuse.out" 2> "$WORK/cli-refuse.err"; echo $? > "$WORK/cli-refuse.rc" )
if [ "$(rc_of "$WORK/cli-refuse.rc")" = 2 ] && [ ! -s "$WORK/cli-refuse.out" ] && grep -qF 'could not read any rulebook token at theirs' "$WORK/cli-refuse.err" \
   && cmp -s "$CTL/badt.out" "$WORK/cli-refuse.out" && cmp -s "$CTL/badt.err" "$WORK/cli-refuse.err" && cmp -s "$CTL/badt.rc" "$WORK/cli-refuse.rc"; then
  ok "cli-refuse: the program refuses an unresolvable theirs exactly as the in-process call does (stdout, stderr, exit 2)"
else
  bad "cli-refuse: the program (rc=$(rc_of "$WORK/cli-refuse.rc"), err [$(head -1 "$WORK/cli-refuse.err")]) and the in-process call (rc=$(rc_of "$CTL/badt.rc"), err [$(head -1 "$CTL/badt.err")]) differ, or the outcome is not exit 2 with the refusal"
fi

# --- A RENAMED witness file is not a deleted one ---------------------------------------------
# `show_at "$THEIRS" "$f"` on the base path returns empty for a deletion AND for a rename, and
# the two want opposite conclusions: a deleted emitter witnesses the word, a renamed emitter
# that still prints it does not. Found by the adversarial hand on a seeded rename; zero live
# instances across 321 wide spans, closed because it is cheap. This world is its own dist,
# driven as shipped: the copy must NAME the word as acquitted and emit no row.
DIST3="$WORK/dist-rename"
mkdir -p "$DIST3/core/skills/ai-dlc" "$DIST3/core/scripts"
git -C "$DIST3" init -q . 2>/dev/null
git -C "$DIST3" config user.email f@f; git -C "$DIST3" config user.name f
printf '# Engine\n\nThe lead ALWAYS records it. The run is RENAMEDWORD when nothing was read.\n' > "$DIST3/core/skills/ai-dlc/SKILL.md"
printf 'echo "RENAMEDWORD: nothing read" >&2\n' > "$DIST3/core/scripts/validate-a.sh"
git -C "$DIST3" add -A; git -C "$DIST3" commit -qm base
BASE3="$(git -C "$DIST3" rev-parse HEAD)"
printf '# Engine\n\nThe lead ALWAYS records it. The run is EMPTY-READ when nothing was read.\n' > "$DIST3/core/skills/ai-dlc/SKILL.md"
git -C "$DIST3" mv core/scripts/validate-a.sh core/scripts/validate-b.sh
git -C "$DIST3" add -A; git -C "$DIST3" commit -qm theirs
THEIRS3="$(git -C "$DIST3" rev-parse HEAD)"
RENC="$WORK/rename-consumer"
mkdir -p "$RENC/.claude/skills/ai-dlc/overrides"
printf '# Override\n\nstock exits RENAMEDWORD when nothing was read\n' > "$RENC/.claude/skills/ai-dlc/overrides/o.md"
r_out="$(rlt_eng "$SCRIPT" "$DIST3" "$BASE3" "$THEIRS3" "$RENC" 2>"$WORK/rename.err")"
if [ -z "$r_out" ] && grep -qE 'read as emphasis, not status: .*RENAMEDWORD' "$WORK/rename.err"; then
  ok "a witness file RENAMED at theirs that still prints the word does not retire it, and the NOTE names the word as acquitted"
else
  bad "a renamed witness file was read as a deletion: rows='$(printf '%s' "$r_out" | tr '\n' ' ' | head -c 100)' err='$(head -c 160 "$WORK/rename.err")'"
fi

# --- A MEMO THAT CANNOT SERVE ONE KEY REFUSES, IT NEVER DECIDES THE ROWS -------------------------
# lib.sh's memo returns 125 when a cached blob, listing or status cannot be served. The detector
# used to discard it (`files_at`'s `|| return 0`, `show_at`'s `|| true`), and one lost key then
# moved the rows at exit 0. Each cell warms a memo on the main world, damages ONE key, and demands
# the refusal: exit 2, no stdout, the memo named on stderr. The three keys are the three wrong
# answers measured on the pre-fix engine: a theirs rulebook blob lost (a FALSE row, `MEASURED`), a
# base witness program lost (five TRUE rows dropped), a base rulebook blob lost (the retired-NOTHING
# NOTE). The warm HIT with nothing damaged must reproduce the control's rows, or the damaged cells
# would be comparing against a memo that never served anything.
rlt_memo_warm() { local m; m="$(mktemp -d "$WORK/rlt-memo.XXXXXX")" || return 1
  ( cd "$NEUTRAL" && AI_DLC_RECONCILE_MEMO="$m" rlt_eng "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >/dev/null 2>&1 ); printf '%s' "$m"; }
rlt_memo_run() { ( cd "$NEUTRAL" && AI_DLC_RECONCILE_MEMO="$1" rlt_eng "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$WORK/mm.out" 2>"$WORK/mm.err" ); echo $?; }
MM="$(rlt_memo_warm)"
mm_rc="$(rlt_memo_run "$MM")"
if [ "$mm_rc" = 0 ] && cmp -s "$WORK/mm.out" "$CTL/main.out" && [ -s "$WORK/mm.out" ]; then
  ok "a warm memo HIT with nothing damaged reproduces the control's rows at exit 0"
else
  bad "FIXTURE BROKEN — the warm memo hit did not reproduce the control (rc=$mm_rc), so the damaged-key cells below compare against nothing"
fi
for mm_cell in \
  "theirs-blob:$THEIRS:core%2Fskills%2Fai-dlc%2Fsteps%2Fdemo.md:c0:a theirs rulebook blob" \
  "base-witness:$BASE:core%2Fscripts%2Fvalidate-ci-gates.sh:cs:a base witness program" \
  "base-blob:$BASE:core%2Fskills%2Fai-dlc%2Fsteps%2Fdemo.md:cs:a base rulebook blob" \
  "base-blob-status:$BASE:core%2Fskills%2Fai-dlc%2Fsteps%2Fdemo.md:s0:a base rulebook blob's status alone"; do
  IFS=: read -r mm_id mm_ref mm_path mm_mode mm_what <<EOF
$mm_cell
EOF
  MM="$(rlt_memo_warm)"
  mm_n=0
  for mm_f in "$MM"/"s "*" ${mm_ref}:${mm_path}.s"; do
    [ -f "$mm_f" ] || continue
    mm_k="${mm_f%.s}"; mm_n=$((mm_n + 1))
    case "$mm_mode" in
      c0) chmod 000 "$mm_k.c" ;;
      cs) : > "$mm_k.s"; : > "$mm_k.c" ;;
      s0) : > "$mm_k.s" ;;
    esac
  done
  if [ "$mm_n" -ne 1 ]; then
    bad "FIXTURE BROKEN — memo cell $mm_id found $mm_n key(s) for ${mm_path} at ${mm_ref}, not 1; the memo key grammar moved"
    continue
  fi
  mm_rc="$(rlt_memo_run "$MM")"
  chmod -R u+rw "$MM" 2>/dev/null
  if [ "$mm_rc" = 2 ] && [ ! -s "$WORK/mm.out" ] && grep -qF 'could not be served by the reconcile memo' "$WORK/mm.err"; then
    ok "memo cell $mm_id: $mm_what the memo cannot serve REFUSES — exit 2, no rows, the memo named"
  else
    bad "memo cell $mm_id: $mm_what the memo cannot serve gave rc=$mm_rc and $(grep -c . "$WORK/mm.out") row(s) — a lost cached object decided the rows (stderr: $(head -c 140 "$WORK/mm.err" | tr '\n' ' '))"
  fi
done

# --- A NON-ASCII WITNESS FILE RENAMED AT THEIRS IS STILL A RENAME -----------------------------------
# The rename map is a `diff -M --name-status` listing. Under the default `core.quotePath` git
# C-quotes a non-ASCII path, the `$1==f` lookup against the raw path `files_at` listed misses, and
# the renamed witness reads as DELETED -- which retires a word the renamed program still prints.
# The ASCII arm above is this world's near-miss: the same rename with a name the default never quotes.
DIST4="$WORK/dist-rename-cafe"
mkdir -p "$DIST4/core/skills/ai-dlc" "$DIST4/core/scripts"
git -C "$DIST4" init -q . 2>/dev/null
printf '# Engine\n\nThe lead ALWAYS records it. The run is RENAMEDWORD when nothing was read.\n' > "$DIST4/core/skills/ai-dlc/SKILL.md"
printf 'echo "RENAMEDWORD: nothing read" >&2\n' > "$DIST4/core/scripts/validate-café.sh"
git -C "$DIST4" add -A; git -C "$DIST4" -c user.email=f@f -c user.name=f commit -qm base
BASE4="$(git -C "$DIST4" rev-parse HEAD)"
printf '# Engine\n\nThe lead ALWAYS records it. The run is EMPTY-READ when nothing was read.\n' > "$DIST4/core/skills/ai-dlc/SKILL.md"
git -C "$DIST4" mv "core/scripts/validate-café.sh" "core/scripts/validate-crème.sh"
git -C "$DIST4" add -A; git -C "$DIST4" -c user.email=f@f -c user.name=f commit -qm theirs
THEIRS4="$(git -C "$DIST4" rev-parse HEAD)"
c4_q="$(git -C "$DIST4" diff -M --name-status --diff-filter=R "$BASE4" "$THEIRS4" | grep -c '\\303')" || c4_q=0
c4_out="$(rlt_eng "$SCRIPT" "$DIST4" "$BASE4" "$THEIRS4" "$RENC" 2>"$WORK/rename-cafe.err")"; c4_rc=$?
if [ "$c4_q" -lt 1 ]; then
  bad "FIXTURE BROKEN — this git did not C-quote the non-ASCII rename under the default core.quotePath, so the cell cannot express the defect"
elif [ "$c4_rc" = 0 ] && [ -z "$c4_out" ] && grep -qE 'read as emphasis, not status: .*RENAMEDWORD' "$WORK/rename-cafe.err"; then
  ok "a witness file with a NON-ASCII name renamed at theirs is read as a rename: the word is acquitted, not rowed"
else
  bad "a non-ASCII renamed witness was read as a deletion (rc=$c4_rc): rows='$(printf '%s' "$c4_out" | tr '\n' ' ' | head -c 100)'"
fi

# --- THE RENAME MAP THAT CANNOT BE STAGED REFUSES (a full disk, modelled) -----------------------------
# `trap '' XFSZ; ulimit -f N` is the full-disk model: the write fails with EFBIG and the ignored
# signal keeps the script alive. The rename map is calibrated PAST the limit and every other file
# the run writes (the memo's tree listings, the staged sets) BELOW it, so the only write that can
# fail is the map's. /bin/bash, because bash 3.2 stages a here-string to a file and a newer bash may
# feed a small one through a pipe. The cell accepts the complete healthy answer (no row, the word
# acquitted) or the detector's own named refusal at a non-zero exit, and nothing else. The
# pre-fix engine read the map from a `<<<` that could not be staged: an empty lookup, the renamed
# witness read as deleted, and a FALSE row at exit 0.
DIST5="$WORK/dist-rename-big"
mkdir -p "$DIST5/core/skills/ai-dlc" "$DIST5/core/scripts" "$DIST5/core/zz"
git -C "$DIST5" init -q . 2>/dev/null
printf '# Engine\n\nThe lead ALWAYS records it. The run is RENAMEDWORD when nothing was read.\n' > "$DIST5/core/skills/ai-dlc/SKILL.md"
printf 'echo "RENAMEDWORD: nothing read" >&2\n' > "$DIST5/core/scripts/validate-a.sh"
r5_pad="$(printf '%0180d' 0)"
r5_i=0
while [ "$r5_i" -lt 40 ]; do
  printf 'filler %s, unique so the rename pairing is exact\n' "$r5_i" > "$DIST5/core/zz/a${r5_i}-${r5_pad}.md"
  r5_i=$((r5_i + 1))
done
git -C "$DIST5" add -A; git -C "$DIST5" -c user.email=f@f -c user.name=f commit -qm base
BASE5="$(git -C "$DIST5" rev-parse HEAD)"
printf '# Engine\n\nThe lead ALWAYS records it. The run is EMPTY-READ when nothing was read.\n' > "$DIST5/core/skills/ai-dlc/SKILL.md"
git -C "$DIST5" mv core/scripts/validate-a.sh core/scripts/validate-b.sh
r5_i=0
while [ "$r5_i" -lt 40 ]; do
  git -C "$DIST5" mv "core/zz/a${r5_i}-${r5_pad}.md" "core/zz/b${r5_i}-${r5_pad}.md"
  r5_i=$((r5_i + 1))
done
git -C "$DIST5" add -A; git -C "$DIST5" -c user.email=f@f -c user.name=f commit -qm theirs
THEIRS5="$(git -C "$DIST5" rev-parse HEAD)"
r5_map="$(git -C "$DIST5" -c core.quotePath=false diff -M --name-status --diff-filter=R "$BASE5" "$THEIRS5" | awk -F'\t' '$1 ~ /^R/ {print $2"\t"$3}' | wc -c | tr -d ' ')"
r5_ls="$(git -C "$DIST5" ls-tree -r --name-only "$THEIRS5" | wc -c | tr -d ' ')"
r5_blk="$( ( trap '' XFSZ; ulimit -f 1; printf '%08192d' 0 > "$WORK/r5-blk" ) 2>/dev/null; wc -c < "$WORK/r5-blk" | tr -d ' ')"
r5_lim=""
case "$r5_blk" in ''|*[!0-9]*|0) ;; *) r5_lim=$(( (r5_ls + (r5_map - r5_ls) / 2) / r5_blk )) ;; esac
# THE CALIBRATION: under the limit a here-string of the map's size must fail, and a write of the
# listing's size must land whole. Either one not holding means this host cannot express the cell.
r5_cal=""
if [ -n "$r5_lim" ] && [ "$r5_lim" -gt 0 ]; then
  r5_hs="$(/bin/bash -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; wc -c <<<"$2"' _ "$r5_lim" "$(printf "%0${r5_map}d" 0)" 2>/dev/null)"
  /bin/bash -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; printf "%0${2}d" 0 > "$3"' _ "$r5_lim" "$r5_ls" "$WORK/r5-cal" 2>/dev/null
  r5_w="$(wc -c < "$WORK/r5-cal" 2>/dev/null | tr -d ' ')"
  case "$r5_hs" in *[1-9]*) ;; *) [ "$r5_w" = "$r5_ls" ] && r5_cal=ok ;; esac
fi
if [ "$r5_cal" != ok ]; then
  bad "FIXTURE BROKEN — calibration: under ulimit -f ${r5_lim:-?} (block ${r5_blk:-?} B) a ${r5_map}-byte here-string did not fail or a ${r5_ls}-byte write did not land whole, so the forced cell below cannot discriminate"
else
  r5_u="$(rlt_eng "$SCRIPT" "$DIST5" "$BASE5" "$THEIRS5" "$RENC" 2>"$WORK/r5-u.err")"; r5_urc=$?
  if [ "$r5_urc" = 0 ] && [ -z "$r5_u" ] && grep -qE 'read as emphasis, not status: .*RENAMEDWORD' "$WORK/r5-u.err"; then
    ok "unforced control: the ${r5_map}-byte rename map pairs the witness and the word is acquitted"
  else
    bad "FIXTURE BROKEN — unforced control: rc=$r5_urc rows='$(printf '%s' "$r5_u" | head -c 80)'; the forced cell has no healthy answer to accept"
  fi
  # KEPT END TO END (cells.decl e2e-forced-map): the file-size limit binds every write of the process it is set in,
  # and an in-process pass's fx_inproc append under it is lost (validate-fixture-invocations.sh, THE COUNTER). The tag
  # is set inside the `-c` wrapper, just before the exec, so it lands on the subject's own start.
  r5_f="$(/bin/bash -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; FXCELL="$2"; export FXCELL; shift 2; exec /bin/bash "$@"' _ "$r5_lim" e2e-forced-map "$SCRIPT" "$DIST5" "$BASE5" "$THEIRS5" "$RENC" 2>"$WORK/r5-f.err")"; r5_frc=$?
  if { [ "$r5_frc" = 0 ] && [ -z "$r5_f" ] && grep -qE 'read as emphasis, not status: .*RENAMEDWORD' "$WORK/r5-f.err"; } \
     || { [ "$r5_frc" -ne 0 ] && [ "$r5_frc" -ne 97 ] && [ -z "$r5_f" ] && grep -q '^retired-layer-token: staging the rename map did not run' "$WORK/r5-f.err"; }; then
    ok "forced: a rename map that cannot be staged under ulimit -f $r5_lim gives the healthy answer or the named refusal (rc=$r5_frc)"
  else
    bad "forced: a rename map that cannot be staged under ulimit -f $r5_lim gave rc=$r5_frc rows='$(printf '%s' "$r5_f" | tr '\n' ' ' | head -c 100)' — an unstaged map read as empty"
  fi
fi

echo
report_end retired-layer-token
