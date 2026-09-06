#!/usr/bin/env bash
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
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "retired-layer-token:"
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
    bash "$2" "$3" "$4" "$5" "$6" >"$7.out" 2>"$7.err"
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
# a kill. The three absence arms carry `rows_present` as their positive conjunct — the
# weakest thing no mutant below removes, so they are not entangled with the arm they sit
# beside.
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
q13() { [ ! -s "$1/undec.out" ] && grep -qE 'UNDECIDED, not acquitted: .*NEVER' "$1/undec.err"; }
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

vec() { local v="" p; for p in q1 q2 q3 q4 q5 q6 q7 q8 q9 q10 q11 q12 q13 q14 q15 q16 q17; do
          if "$p" "$1"; then v="${v}1"; else v="${v}0"; fi; done; printf '%s' "$v"; }

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
q13 "$CTL" && ok "a base with NO readable program file reports UNDECIDED, not an acquittal" \
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
ORPHERR="$( cd "$NEUTRAL" && bash "$WORK/orphan/retired-layer-token.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>&1 >/dev/null )"; ORPHRC=$?
{ grep -qF 'could not read the rulebook list from setup-sites.md' <<<"$ORPHERR" && [ "$ORPHRC" -eq 2 ]; } \
  && ok "a copy with no setup-sites.md beside it refuses, and exits 2" \
  || bad "an unreadable rulebook list produced no warning or did not exit 2 (rc=$ORPHRC) — the driver would render it as 'none'"

# --- Assertion 15: a base ref that does not resolve is a REFUSAL, never the NOTE -----------
BADERR="$( cd "$NEUTRAL" && bash "$SCRIPT" "$DIST" "$BADREF" "$THEIRS" "$CONSUMER" 2>&1 >/dev/null )"; BADRC=$?
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
  sect() { awk '/Retired status tokens reused/{f=1;next} f&&/^\*\*/{exit} f'; }
  EM_OK="$( cd "$NEUTRAL" && bash "$EMITSH" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | sect )"
  EM_BAD="$( cd "$NEUTRAL" && bash "$EMITSH" "$DIST" "$BASE" "$CONSUMER" "$BADREF" 2>/dev/null | sect )"
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

# --- MUTANTS -------------------------------------------------------------------------------
# Built as a copy of the WHOLE reconcile directory: the detector resolves setup-sites.md
# beside itself, and a lone copy reads an empty rulebook list and is silent for THAT reason,
# which scores as a kill it never earned. Every mutation is a sed SCRIPT FILE, so a
# replacement carrying quotes or backticks cannot be mangled by the shell on the way in.
MUTD="$WORK/muts"; mkdir -p "$MUTD"

# M1 — the rulebook derivation keys on backticks. The motivating base wrote the word BARE.
# Mutating collect's tokeniser and not `toks` itself keeps the program witness intact, so
# this flips the two incident arms and nothing else.
cat > "$MUTD/m1.sed" <<'SED'
s#^  done; } | toks$#  done; } | grep -o '`[^`]*`' | toks#
SED

# M2 — the layer side matches substrings instead of whole words.
cat > "$MUTD/m2.sed" <<'SED'
s#^      n = split(.*#      n = 0; for (t in r) if (index($0, t) > 0) { n++; w[n] = t }#
SED

# M3 — retirement read per rulebook FILE: a token missing from the file it was in reads as
# dropped even though another rulebook file carries it at theirs.
cat > "$MUTD/m3.sed" <<'SED'
s#^    show_at "$ref" "$f"$#    show_at "$ref" "$f" | toks | sed "s@^@$f~@"#
s#^  done; } | toks$#  done; } | sort -u#
s#"$THEIRS_SET"))"#"$THEIRS_SET") | cut -d~ -f2 | sort -u)"#
SED

# M4 — the empty-retired branch stops saying it opened nothing.
cat > "$MUTD/m4.sed" <<'SED'
s#^  echo "retired-layer-token: NOTE .* this release retired NO status token#  : "#
SED

# M5 — a subject that emits nothing. Every arm above must fall.
cat > "$MUTD/m5.sed" <<'SED'
s#^set -u$#exit 0#
SED

# M6 — `set -f` dropped from collect, so the rulebook PATHSPECS are glob-expanded against
# the caller's cwd.
cat > "$MUTD/m6.sed" <<'SED'
/^  local ref="$1" f$/{n;s#^  set -f$#  : mutant-nofilter#;}
SED

# M7 — the program witness removed: every plain word the rulebook dropped is retired.
cat > "$MUTD/m7.sed" <<'SED'
s#"$JOINED" "$WITNESSED"#"$JOINED" "$PLAIN"#
SED

# M8 — the witness taken as a UNION at theirs rather than per file. This is G5, refuted on
# the motivating pull by a second program that still prints the word in another sense.
cat > "$MUTD/m8.sed" <<'SED'
s#^    gone="$(comm -23 .*#    gone="$(comm -23 <(printf '%s\n' "$hit") <(printf '%s\n' "$PROGRAMS" | while IFS= read -r g; do show_at "$THEIRS" "$g"; done | code_toks))"#
SED

# M9 — the joined-shape witness removed: only a program can retire anything.
cat > "$MUTD/m9.sed" <<'SED'
s#"$JOINED" "$WITNESSED"#"$WITNESSED" "$WITNESSED"#
SED

# M10 — comment lines no longer stripped from a program.
cat > "$MUTD/m10.sed" <<'SED'
s#^  grep -vE .*#  cat | toks#
SED

# M11 — the theirs-side file list taken from the BASE tree, so a rulebook file created at
# theirs is invisible and a token that moved into it reads as retired.
cat > "$MUTD/m11.sed" <<'SED'
s#--name-only "$ref"#--name-only "$BASE"#
SED

# M12 — the grammar's floor dropped to three characters.
cat > "$MUTD/m12.sed" <<'SED'
s#{3,}#{2,}#
SED

# M13 — the layer corpus narrowed to overrides/, so an extension quoting a retired token is
# never opened.
cat > "$MUTD/m13.sed" <<'SED'
s#^  for dir in overrides extensions; do#  for dir in overrides; do#
SED

# M14 — the dropped set read from the lines a release REMOVED, the way the passage sibling
# reads its corpus, instead of as a set difference over the whole rulebook.
cat > "$MUTD/m14.sed" <<'SED'
s#^DROPPED="$(comm -23 .*#DROPPED="$(git -C "$DIST" diff "$BASE" "$THEIRS" 2>/dev/null | grep -E "^-" | grep -vE "^---" | sed "s@^-@@" | toks)"#
SED

# M15 — an unwitnessable base reported as an acquittal rather than as UNDECIDED.
cat > "$MUTD/m15.sed" <<'SED'
s#^  if \[ "$opened" -eq 0 \]; then#  if false; then#
SED

# M16 — the layer corpus widened to .txt.
cat > "$MUTD/m16.sed" <<'SED'
s#-o -name #-o -name '*.txt' -o -name #
SED

# M17 — the theirs guard removed. An unresolvable theirs then empties the theirs side and
# every rulebook token reads as retired: a MAXIMAL false report with an empty stderr.
cat > "$MUTD/m17.sed" <<'SED'
s#^if \[ -z "$THEIRS_SET" \]; then#if false; then#
SED

mkmut() {  # name [-text|+text ...] -> mutant path on stdout
  local name="$1"; shift
  local d="$WORK/mut-$name" m a t c
  cp -R "$(dirname "$SCRIPT")" "$d" \
    || { echo "FIXTURE ERROR: could not copy the reconcile dir for $name" >&2; exit 2; }
  m="$d/$(basename "$SCRIPT")"
  sed -f "$MUTD/$name.sed" "$SCRIPT" > "$m" \
    || { echo "FIXTURE ERROR: mutation $name DID NOT APPLY (sed died)" >&2; exit 2; }
  cmp -s "$SCRIPT" "$m" \
    && { echo "FIXTURE ERROR: mutation $name matched nothing -- its anchor moved" >&2; exit 2; }
  bash -n "$m" 2>/dev/null \
    || { echo "FIXTURE ERROR: mutant $name does not parse" >&2; exit 2; }
  [ -f "$d/setup-sites.md" ] \
    || { echo "FIXTURE ERROR: mutant $name has no setup-sites.md beside it" >&2; exit 2; }
  # A mutation that APPLIES can still be insufficient, and `cmp -s` cannot see it. Every
  # site of the property must be gone from the mutant and present in the original.
  for a in "$@"; do
    t="${a#?}"
    # `-e` is not optional: an anchor whose text opens with `-` is read as a grep OPTION
    # otherwise, and the run dies with "Invalid argument" instead of scoring anything.
    c="$(grep -cF -e "$t" "$SCRIPT")" || c=0
    case "$a" in
      -*) [ "$c" -gt 0 ] || { echo "FIXTURE ERROR: mutation $name anchor absent from the ORIGINAL: $t" >&2; exit 2; }
          c="$(grep -cF -e "$t" "$m")" || c=0
          [ "$c" -eq 0 ] || { echo "FIXTURE ERROR: mutation $name left $c site(s) of its subject behind: $t" >&2; exit 2; } ;;
      +*) [ "$c" -eq 0 ] || { echo "FIXTURE ERROR: mutation $name's marker already exists in the ORIGINAL: $t" >&2; exit 2; }
          c="$(grep -cF -e "$t" "$m")" || c=0
          [ "$c" -gt 0 ] || { echo "FIXTURE ERROR: mutation $name did not produce: $t" >&2; exit 2; } ;;
    esac
  done
  printf '%s\n' "$m"
}

PLAN="$WORK/plan.tsv"; : > "$PLAN"
plan() {  # name path expected-vector -> queued for one parallel wave
  # mkmut runs inside `$( )`, so its `exit 2` ends the subshell and not this fixture; an
  # empty path here IS that refusal, and it must read as BROKEN, never as a regression
  # (`bash ""` fails every predicate and prints seventeen zeros).
  [ -n "$2" ] || { echo "FIXTURE ERROR: mutant $1 was not built -- see the FIXTURE ERROR above; a lost anchor is a lost subject, not a regression" >&2; exit 2; }
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$PLAN"
}
run_plan() {  # snapshot every queued mutant, three scripts at a time, then score in order
  local nm path exp i=0 got
  while IFS="$TAB" read -r nm path exp; do
    [ -n "$nm" ] || continue
    ( snap "$path" "$WORK/snap-$nm" ) &
    i=$((i + 1)); [ "$((i % 3))" -eq 0 ] && wait
  done < "$PLAN"
  wait
  while IFS="$TAB" read -r nm path exp; do
    [ -n "$nm" ] || continue
    got="$(vec "$WORK/snap-$nm")"
    if [ "$got" = "$exp" ]; then ok "MUTATION $nm: flips exactly $exp"
    else bad "MUTATION $nm: expected $exp got $got (q1..q17)"; fi
  done < "$PLAN"
}

CTLVEC="$(vec "$CTL")"
if [ "$CTLVEC" = "11111111111111111" ]; then
  ok "unmutated control: every predicate holds (11111111111111111)"
else
  bad "unmutated control: $CTLVEC -- every mutant score below is meaningless"
fi

# WHERE TWO CELLS FALL TOGETHER IT IS BY CONSTRUCTION, AND IT IS STATED HERE.
#   m1/m8  take q1 AND q2: the incident's two lines carry the SAME word, so any mutation
#          that stops deriving it takes both. q11 is derived by the OTHER witness and stays
#          up, which is what separates a broken derivation from a silenced detector.
#   m3     takes q4 AND q16: per-FILE retirement breaks both moved-token worlds. m11 breaks
#          only the second, which is how the two are told apart.
#   m7     takes q10 AND q12: removing the witness convicts both acquitted words at once. It
#          leaves the acquittal LIST alone, where m10 changes the list and not q10.
#   m13    takes q2, q9 AND q11: narrowing the corpus to overrides/ closes the whole
#          extensions/ half, and three subjects live there.
plan m1  "$(mkmut m1  '-done; } | toks')"                                 "00111111111111111"
plan m2  "$(mkmut m2  '-n = split(')"                                     "11011111111111111"
plan m3  "$(mkmut m3  '-done; } | toks' '-"$THEIRS_SET"))"' '+cut -d~ -f2')" "11101111111111101"
plan m4  "$(mkmut m4  '-this release retired NO status token')"           "11111011111111111"
plan m5  "$(mkmut m5  '-set -u')"                                         "00000000000000000"
plan m6  "$(mkmut m6  '+: mutant-nofilter')"                              "11111110111111111"
plan m7  "$(mkmut m7  '-"$JOINED" "$WITNESSED"')"                         "11111111101011111"
plan m8  "$(mkmut m8  '-show_at "$THEIRS" "$f"' '+while IFS= read -r g')"  "00111111111110111"
plan m9  "$(mkmut m9  '-"$JOINED" "$WITNESSED"')"                          "11111111110111111"
plan m10 "$(mkmut m10 "-'^[[:space:]]*#'")"                               "11111111111010111"
plan m11 "$(mkmut m11 '-ls-tree -r --name-only "$ref"')"                   "11111111111111101"
plan m12 "$(mkmut m12 '-{3,}')"                                           "11111111111111011"
plan m13 "$(mkmut m13 '-for dir in overrides extensions; do')"            "10111111010111111"
plan m14 "$(mkmut m14 '-DROPPED="$(comm -23')"                            "11100111111111101"
plan m15 "$(mkmut m15 '-if [ "$opened" -eq 0 ]; then')"                   "11111111111101111"
# the leading `-` is the direction marker, so the anchor text itself starts at the second.
plan m16 "$(mkmut m16 "--name '*.md' -o -name '*.json'")"                 "11111111011111111"
plan m17 "$(mkmut m17 '-if [ -z "$THEIRS_SET" ]; then')"                  "11111111111111110"

run_plan

echo
if [ "$fails" -eq 0 ]; then echo "retired-layer-token: PASS"; exit 0; fi
echo "retired-layer-token: $fails assertion(s) FAILED" >&2
exit 1
