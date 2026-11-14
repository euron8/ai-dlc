#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# install-scaffold-ignored -- scripts/install.sh reports, after its last .gitignore write, every
# create-once scaffold path the target's git ignore rules hide (BL-992).
#
# Usage: run.sh [--matrix]
# Exit:  0 = every assertion holds, 1 = the report regressed, 2 = fixture broken.
#
# THE DEFECT. install.sh created consumer-owned files once and never asked git about them. A
# consumer whose .gitignore matched one (`*.txt` hiding the smoke surface) ran `git add -A`,
# staged nothing, was told nothing, and the file never reached history.
#
# THE SUBJECT IS THREE FILES. scripts/install-scaffold-ignore.sh holds the population
# (ai_dlc_once_paths) and the report (ai_dlc_scaffold_ignore_report); the decision and the remedy
# text are core/skills/ai-dlc-update/reconcile/scaffold-ignore.sh's (scaffold_ignore_state,
# scaffold_ignore_remedy), the file apply.sh reads; scripts/install.sh sources both and calls the
# report once. A missing file of the three is FIXTURE BROKEN, exit 2.
#
# IN-PROCESS CELLS (zero starts): both function files are sourced in a subshell under `set -e`,
# install.sh's own option (it does not set -u), and the report is called against a world built
# once. The subshell's exit is read AFTER it, never by `( ... ) || RC=$?`: bash ignores `set -e`
# inside a subshell that is the left side of `||`, so that harness passes a report `set -e` would
# end. state-unguarded is the mutant only an effective `set -e` kills.
#   P   the population equals the hand list it replaces: the keys install.sh itself reads
#       (`consumer_<k>_file:` spelled in install.sh), resolved, plus the two layer READMEs and the
#       feedback log. Any difference is named.
#   PZ  a layer-contract.yaml with no key: the population returns 2 with nothing on stdout, and so
#       does the report.
#   WM  mixed: `*.md`, `<smoke dir>/*.txt`, an exact `<crosswalk>` line, an exact `/<machinery>`
#       line and a `!<pr-classes>` re-include, with the extensions README tracked. Exact and
#       re-included paths are quiet beside the smoke surface's glob WARNING. Every remedy is
#       byte-equal to scaffold_ignore_remedy's output for the same <rel> and provenance.
#   WQ  a repository with no ignore rule at all: the header alone.
#   WT  the tracked near-miss on ONE path: only the smoke surface exists, ignored by
#       `<smoke dir>/*.txt` and untracked, and the report WARNs for it; then `git add -f` of that
#       same path, nothing else changed, and the report is the header alone.
#   WU  docs/ is a symlink: each docs/ path is `scaffold-ignore-unchecked ... exited 128`.
#   WB  a bare repository holding the files: --git-dir answers, --is-inside-work-tree says false
#       (both asserted first), and the report is exactly the SKIPPED line.
#   WN  a directory inside no repository (asserted first): exactly the SKIPPED line.
#   WS  a subdirectory of a repository whose ROOT .gitignore ignores by glob: every <rel> is
#       relative to the subdirectory and the header names the root's work tree.
#   WG  an inherited GIT_DIR naming another repository whose info/exclude is `*`: the target's own
#       verdict (quiet). The other repository is shown, first, to ignore the smoke surface.
#   WX  `*` ignores every path but only the smoke surface exists: one WARNING, for it (a missing
#       file gives nothing; check-ignore answers 0 for an absent path, asserted first).
#   WE  a stub decision answers the smoke surface `bogus`, the crosswalk an empty word with exit 0,
#       and the machinery file an empty word with exit 3: each is a scaffold-ignore-unchecked
#       WARNING naming the word, the report returns 0 under `set -e`, and no path is acquitted.
#
# END-TO-END INSTALLS, one per distinct outcome (fixture-mutants clause 6), each target a fresh
# mktemp directory with _bmad/:
#   E1  mixed fresh install, run with its cwd an unrelated directory (install.sh locates both
#       function files from its own directory): `*.md`, `*.txt`, an exact `<crosswalk>` line, a
#       `!<overrides README>` re-include, the extensions README pre-created and tracked. Every other
#       path WARNs. The pre-created README is preserved byte for byte, this .dist-only fixture is
#       absent from the installed tests/fixtures/, and the .gitignore the install leaves equals the
#       one BASE leaves in the same seeded world, byte for byte.
#   E2  a re-install into E1's tree: the same WARNINGs, for files that are now present.
#   E4  the late render. A seeded AI_DLC_STATE_PATHS_SCHEMA makes sync-transient-ignore write a
#       `<smoke dir>/*.txt` line; the smoke surface is not ignored before the install (asserted),
#       so it WARNs only if the report runs after the render.
#   E5  a target inside no repository (asserted first): exactly the SKIPPED line.
#   AB1 install.sh with the decision file absent, AB2 with the report file absent. ABSENCE IS
#       MODELLED BY A COPY of install.sh whose path to that one file is renamed to a name asserted
#       absent, so the real tree is never edited. Each must exit non-zero, name the missing file,
#       print no report and no completion line, and leave the target exactly as seeded.
#
# BASE IS SHOWN TO FAIL E1 THIS WAY: BASE is install.sh with its one report call replaced by `:`
# (the call-break mutant below), run on a fresh E1 world seeded identically. It completes with
# exit 0 and prints no line of the report, and E1's set comparison FAILS on it; that run is
# scored as the call-break kill and is the source of the .gitignore E1 is compared against.
#
# MUTANTS. Lib mutants are copies of scripts/install-scaffold-ignore.sh under the work dir,
# sourced in place of it in the in-process cells; a copy that does not source cleanly is a
# failure, never a kill. Install mutants are texts under the work dir, never files in the real
# tree. Each runs as `bash -c <text> <root>/scripts/install.sh <target>`, so its $0 is the real
# install.sh: the own-repository check passes and SCRIPT_DIR still finds both function files. The
# carrier control runs the unmutated text the same way on E1 and E4 and must hold whole before an
# install mutant's kill is scored. An install mutant's kill counts only when the run completed (`Installation
# complete!`) and, except for call-break whose subject IS the missing report, printed the report
# header or the SKIPPED line; a refusal is never a kill.
# The rows below are the --matrix run's measurement (every lib mutant against every in-process
# cell, every install mutant against E1 E2 E4 E5 AB1 AB2; 429s with one counted run beside it, all
# 18 rows as written): decides
# lists every cell that failed under the mutant, twins every cell that held whole. A push runs
# only the FIRST decides cell (both, for no-gate), the cheapest one that kills it: lmut_spec's
# M_CELL and imut_spec's M_WORLD. before-render also fails E1 because the feedback log, written
# after the render, does not exist yet when the moved call runs.
#
# MUTANT-MATRIX no-scrub decides=WG twins=P,PZ,WM,WU,WB,WN,WS,WX,WQ,WT,WE
# MUTANT-MATRIX git-dir-gate decides=WB twins=P,PZ,WM,WU,WN,WS,WG,WX,WQ,WT,WE
# MUTANT-MATRIX no-gate decides=WB,WN twins=P,PZ,WM,WU,WS,WG,WX,WQ,WT,WE
# MUTANT-MATRIX pop-nokeys decides=P,WM,WU,WS,WX,WT,WE twins=PZ,WB,WN,WG,WQ
# MUTANT-MATRIX pop-noreadme decides=P,WM,WS twins=PZ,WU,WB,WN,WG,WX,WQ,WT,WE
# MUTANT-MATRIX pop-nofeedback decides=P,WM,WU,WS twins=PZ,WB,WN,WG,WX,WQ,WT,WE
# MUTANT-MATRIX pop-empty-ok decides=PZ twins=P,WM,WU,WB,WN,WS,WG,WX,WQ,WT,WE
# MUTANT-MATRIX repo-rel decides=WS twins=P,PZ,WM,WU,WB,WN,WG,WX,WQ,WT,WE
# MUTANT-MATRIX fold-unchecked decides=WU twins=P,PZ,WM,WB,WN,WS,WG,WX,WQ,WT,WE
# MUTANT-MATRIX exact-as-ignored decides=WM twins=P,PZ,WU,WB,WN,WS,WG,WX,WQ,WT,WE
# MUTANT-MATRIX drop-exists decides=WX twins=P,PZ,WM,WU,WB,WN,WS,WG,WQ,WT,WE
# MUTANT-MATRIX remedy-noprov decides=WM twins=P,PZ,WU,WB,WN,WS,WG,WX,WQ,WT,WE
# MUTANT-MATRIX fault-quiet decides=WE twins=P,PZ,WM,WU,WB,WN,WS,WG,WX,WQ,WT
# MUTANT-MATRIX state-unguarded decides=WE twins=P,PZ,WM,WU,WB,WN,WS,WG,WX,WQ,WT
# MUTANT-MATRIX call-break decides=E1,E2,E4,E5 twins=AB1,AB2
# MUTANT-MATRIX exit-nonzero decides=E1,E2,E4 twins=E5,AB1,AB2
# MUTANT-MATRIX before-render decides=E4,E1 twins=E2,E5,AB1,AB2
# MUTANT-MATRIX lib-optional decides=AB2,AB1 twins=E1,E2,E4,E5
# MUTANT-MATRIX-DYNAMIC mut-loop why=run_lmut and run_imut pass "$m" from the literal LMUTANTS and IMUTANTS lists to mutant_killed; every entry of those lists has its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/install-scaffold-ignored/run.sh --matrix
#
# DISTRIBUTION-ONLY (.dist-only): the subject is scripts/install.sh and its function file, which
# are not shipped.
set -uo pipefail

# install.sh and the renderer it drives read AI_DLC_* overrides (AI_DLC_STATE_PATHS_SCHEMA among
# them); one leaked into this process would decide E4's render for every world.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
for _v in $(env | sed -n 's/^\(CLAUDE_CODE_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

HERE="$(cd "$(dirname "$0")" && pwd)"
FX_NAME="${HERE##*/}"
# Walk up for scripts/install.sh, never count hops.
ROOT_DIR="$HERE"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/scripts/install.sh" ]; do ROOT_DIR="$(dirname "$ROOT_DIR")"; done
INSTALL="$ROOT_DIR/scripts/install.sh"
SI_LIB="$ROOT_DIR/scripts/install-scaffold-ignore.sh"
N1_LIB="$ROOT_DIR/core/skills/ai-dlc-update/reconcile/scaffold-ignore.sh"
for _f in "$INSTALL" "$SI_LIB" "$N1_LIB"; do
  if [ ! -f "$_f" ]; then
    echo "FIXTURE BROKEN: $_f is absent (root resolved to $ROOT_DIR); this fixture is distribution-only" >&2
    exit 2
  fi
done
echo "HERMETIC-CONSUMED scripts/install.sh"
echo "HERMETIC-CONSUMED scripts/install-scaffold-ignore.sh"
for _t in git jq; do
  command -v "$_t" >/dev/null 2>&1 || { echo "FIXTURE BROKEN: $_t not on PATH" >&2; exit 2; }
done

MATRIX=0
[ "${1-}" != "--matrix" ] || MATRIX=1

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

# No global or system git config, and no XDG ignore file, reaches any world.
mkdir -p "$WORK/xdg" "$WORK/elsewhere" || exit 2
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 XDG_CONFIG_HOME="$WORK/xdg"
unset FXCELL

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

QUIET=0; JF=0
# chk <status> <message>: a passing status is ok, any other a failure; under QUIET only counted.
chk() {
  if [ "$1" = 0 ]; then [ "$QUIET" = 1 ] || ok "$2"
  else JF=$((JF + 1)); [ "$QUIET" = 1 ] || bad "$2"; fi
}
# A seed or a world precondition that does not hold is the fixture's failure, never the subject's.
broken() { echo "FIXTURE BROKEN: $1" >&2; exit 2; }
fresh() { mktemp -d "$WORK/w.XXXXXX"; }
newrepo() { git init -q "$1" && git -C "$1" config core.excludesFile /dev/null; }
seedfile() { mkdir -p "$(dirname "$1")" && printf '%s\n' "$2" > "$1"; }
count_of() { # <haystack> <needle>
  local h="$1" n=0
  while :; do case "$h" in *"$2"*) h="${h#*"$2"}"; n=$((n + 1)) ;; *) break ;; esac; done
  echo "$n"
}
srt() { LC_ALL=C sort "$@"; }

# --- the population, and the hand list it replaces -----------------------------------------------
LC="$ROOT_DIR/core/skills/ai-dlc/layer-contract.yaml"
[ -f "$LC" ] || broken "$LC absent"
key_val() { sed -n "s/^consumer_$1_file:[[:space:]]*//p" "$LC" | head -1 | sed 's/[[:space:]]*$//'; }
CW="$(key_val crosswalk)"; MA="$(key_val machinery)"; PR="$(key_val pr_class)"; SM="$(key_val smoke_surface)"
RX=".claude/skills/ai-dlc/extensions/README.md"
RO=".claude/skills/ai-dlc/overrides/README.md"
FB="docs/ai-dlc-feedback.md"
for _p in "$CW" "$MA" "$PR" "$SM"; do [ -n "$_p" ] || broken "a named consumer_*_file: key resolved empty"; done
case "$SM" in */*.txt) SMD="${SM%/*}" ;; *) broken "the smoke surface '$SM' is not a .txt under a directory; WM and E4 cannot seed a directory glob" ;; esac
# The hand list: every key install.sh itself reads, resolved, plus the three install.sh scaffolds by name.
HAND_KEYS="$(grep -o 'consumer_[a-z_]*_file:' "$INSTALL" | sed 's/^consumer_//; s/_file:$//' | srt -u)"
n_hk="$(printf '%s\n' "$HAND_KEYS" | grep -c .)" || n_hk=0
[ "$n_hk" -ge 6 ] || broken "install.sh reads $n_hk consumer_*_file: key(s), expected at least 6"
HAND="$(while IFS= read -r _k; do key_val "$_k"; done <<EOF
$HAND_KEYS
EOF
printf '%s\n%s\n%s\n' "$RX" "$RO" "$FB")"
HAND_S="$(printf '%s\n' "$HAND" | grep . | srt)"

# --- the in-process report ------------------------------------------------------------------------
# rep <lib> <decision 1|stub> <root> <dist> <out> [VAR=value ...]: one report call in a subshell
# under set -e, the variables exported first. RC holds its exit, read after the subshell so its
# `set -e` stays in force (see the header); <out>.err holds its stderr. `stub` replaces
# scaffold_ignore_state with si_stub_state after both files are sourced.
RC=0
si_stub_state() { # <root> <rel>: WE's decision
  case "$2" in
    "$SM") printf 'bogus\tstub\n' ;;
    "$CW") : ;;
    "$MA") return 3 ;;
    *) printf 'untracked-ok\t\n' ;;
  esac
}
rep() {
  local lib="$1" n1="$2" root="$3" dist="$4" o="$5"
  shift 5
  ( for _kv in "$@"; do export "$_kv"; done
    set -e
    . "$N1_LIB"
    . "$lib"
    if [ "$n1" = stub ]; then scaffold_ignore_state() { si_stub_state "$@"; }; fi
    ai_dlc_scaffold_ignore_report "$root" "$dist" ) </dev/null >"$o" 2>"$o.err"
  RC=$?
}
# tuples <out>: the report's own lines as a sorted set. Any other line carrying one of its tokens is
# an OTHER row, so a reworded line fails set equality instead of vanishing.
tuples() {
  awk '/^  WARNING scaffold-ignored / { print "IGN " $3; next }
       /^  WARNING scaffold-ignore-unchecked / { r = $NF; sub(/\)$/, "", r); print "UNC " $3 " " r; next }
       /^  scaffold ignore check SKIPPED: / { print "SKIP"; next }
       /^Checking scaffolded files against git ignore rules\.\.\.$/ { print "HDR"; next }
       /^  Run the git commands above from / { print "TRAILER"; next }
       /scaffold-ignored|scaffold-ignore-unchecked|scaffold ignore check|Checking scaffolded files/ { print "OTHER " $0 }' "$1" | srt
}
# setcmp <label> <expected text> <out>
setcmp() {
  local w="$1" e="$2" o="$3" got
  got="$(tuples "$o")"
  if [ "$got" = "$e" ]; then chk 0 "$w: the report's line set equals the expected $(printf '%s\n' "$e" | grep -c .) row(s)"
  else
    chk 1 "$w: the report's line set differs from the expected one"
    [ "$QUIET" = 1 ] || diff <(printf '%s\n' "$e") <(printf '%s\n' "$got") | sed 's/^/        /'
  fi
}
# rcell <label> <lib> <root> <expected> [VAR=value ...]: one report, rc 0, empty stderr, the set.
# DECISION (1, or stub for WE) is passed to rep.
DECISION=1
rcell() {
  local w="$1" lib="$2" root="$3" e="$4" o
  shift 4
  o="$WORK/out.$w.$RANDOM"
  rep "$lib" "$DECISION" "$root" "$ROOT_DIR" "$o" "$@"
  [ "$RC" = 0 ]; chk $? "$w: the report returns 0 under set -e (got $RC)"
  [ ! -s "$o.err" ]; chk $? "$w: the report writes nothing on stderr"
  setcmp "$w" "$e" "$o"
  LASTOUT="$o"
}
LASTOUT=""
exp_of() { # <tag> <path list on stdin> -> sorted rows
  local p; while IFS= read -r p; do [ -n "$p" ] && echo "$1 $p"; done | srt
}
rows() { printf '%s\n' "$@" | grep . | srt; }

# --- the in-process worlds, each built once ------------------------------------------------------
POP0="$( ( set -e; . "$SI_LIB"; ai_dlc_once_paths "$ROOT_DIR" ) 2>/dev/null)" || broken "the unmutated population returned non-zero"
POP0_S="$(printf '%s\n' "$POP0" | grep . | srt)"
n_pop="$(printf '%s\n' "$POP0_S" | grep -c .)" || n_pop=0
[ "$n_pop" -ge 9 ] || broken "the population has $n_pop path(s), expected at least 9"
DOCS="$(printf '%s\n' "$POP0_S" | grep "^$SMD/")" || DOCS=""
n_docs="$(printf '%s\n' "$DOCS" | grep -c .)" || n_docs=0
[ "$n_docs" -ge 2 ] || broken "fewer than two population paths under $SMD/ ($n_docs); WU cannot discriminate"
for _p in $POP0_S; do case "$_p" in *.md|*.txt) ;; *) broken "population path $_p is neither .md nor .txt; the glob worlds cannot cover it" ;; esac; done
populate() { local p; while IFS= read -r p; do [ -n "$p" ] && seedfile "$1/$p" "seeded $p"; done <<EOF
$POP0_S
EOF
}

WM="$WORK/wm"; newrepo "$WM" && populate "$WM" || broken "WM seed failed"
printf '*.md\n%s/*.txt\n%s\n/%s\n!%s\n' "$SMD" "$CW" "$MA" "$PR" > "$WM/.gitignore"
git -C "$WM" add -f -- "$RX" || broken "WM could not track $RX"
# A `case` inside `$( )` misparses on bash 3.2, so each expected set is a function.
exp_wm() {
  local p
  echo HDR; echo TRAILER
  while IFS= read -r p; do
    case "$p" in "$CW"|"$MA"|"$PR"|"$RX") ;; *.md|"$SMD"/*.txt) echo "IGN $p" ;; esac
  done <<EOF
$POP0_S
EOF
}
EXP_WM="$(exp_wm | srt)"

WU="$WORK/wu"; { newrepo "$WU" && mkdir -p "$WU/realdocs" && ln -s realdocs "$WU/$SMD" && populate "$WU"; } || broken "WU seed failed"
_rc=0; git -C "$WU" check-ignore -q -- "$SM" 2>/dev/null || _rc=$?
[ "$_rc" -ge 2 ] || broken "check-ignore under a symlinked $SMD/ exits $_rc, not >= 2"
EXP_WU="$( { echo HDR; printf '%s\n' "$DOCS" | while IFS= read -r p; do echo "UNC $p $_rc"; done; } | srt)"

WB="$WORK/wb"; { git init -q --bare "$WB" && populate "$WB"; } || broken "WB seed failed"
if ! git -C "$WB" rev-parse --git-dir >/dev/null 2>&1 || [ "$(git -C "$WB" rev-parse --is-inside-work-tree 2>/dev/null)" != "false" ]; then
  broken "WB's bare repository does not separate --git-dir from --is-inside-work-tree"
fi

WN="$WORK/wn"; { mkdir -p "$WN" && populate "$WN"; } || broken "WN seed failed"
git -C "$WN" rev-parse --git-dir >/dev/null 2>&1 && broken "WN's directory $WN is inside a git repository"

WSR="$WORK/wsr"; WS="$WSR/sub"; { newrepo "$WSR" && mkdir -p "$WS" && populate "$WS"; } || broken "WS seed failed"
printf '*.md\n*.txt\n' > "$WSR/.gitignore"
WSR_TOP="$(cd "$WSR" && pwd -P)"
EXP_WS="$( { echo HDR; echo TRAILER; printf '%s\n' "$POP0_S" | while IFS= read -r p; do echo "IGN $p"; done; } | srt)"

WG="$WORK/wg"; WGO="$WORK/wgo"; { newrepo "$WG" && populate "$WG" && newrepo "$WGO"; } || broken "WG seed failed"
printf '*\n' > "$WGO/.git/info/exclude"
_own=0; _for=0
git -C "$WG" check-ignore -q -- "$SM" 2>/dev/null || _own=$?
GIT_DIR="$WGO/.git" git -C "$WG" check-ignore -q -- "$SM" 2>/dev/null || _for=$?
[ "$_own" = 1 ] && [ "$_for" = 0 ] || broken "WG cannot discriminate the scrub (own rc $_own, want 1; foreign rc $_for, want 0)"

WX="$WORK/wx"; { newrepo "$WX" && seedfile "$WX/$SM" "seeded"; } || broken "WX seed failed"
printf '*\n' > "$WX/.gitignore"
_rc=0; git -C "$WX" check-ignore -q -- "$CW" 2>/dev/null || _rc=$?
[ "$_rc" = 0 ] && [ ! -e "$WX/$CW" ] || broken "WX: check-ignore does not answer 0 for the absent $CW (rc $_rc), so a dropped exists-guard could not show"

WQ="$WORK/wq"; { newrepo "$WQ" && populate "$WQ"; } || broken "WQ seed failed"
_rc=0; git -C "$WQ" check-ignore -q -- "$SM" 2>/dev/null || _rc=$?
[ "$_rc" = 1 ] || broken "WQ: the smoke surface is not plainly unignored (check-ignore rc $_rc, want 1)"

EXP_WE="$(rows HDR "UNC $SM 'bogus'" "UNC $CW ''" "UNC $MA ''")"

PZD="$WORK/pzd"; seedfile "$PZD/core/skills/ai-dlc/layer-contract.yaml" "schema: 1" || broken "PZ seed failed"

# --- the in-process cells ---------------------------------------------------------------------------
cell_P() { # <lib>
  local pop rc=0 d
  pop="$( ( set -e; . "$1"; ai_dlc_once_paths "$ROOT_DIR" ) 2>/dev/null)" || rc=$?
  pop="$(printf '%s\n' "$pop" | grep . | srt)"
  [ "$rc" = 0 ] && [ -n "$pop" ]; chk $? "P: the population is non-empty and returns 0 (rc $rc)"
  if [ "$pop" = "$HAND_S" ]; then chk 0 "P: the population equals the hand list it replaces ($(printf '%s\n' "$pop" | grep -c .) paths: $n_hk keys install.sh reads, 2 READMEs, the feedback log)"
  else
    d="$(diff <(printf '%s\n' "$HAND_S") <(printf '%s\n' "$pop") | sed -n 's/^</only in the hand list:/p; s/^>/only in the population:/p' | tr '\n' ';')"
    chk 1 "P: the population differs from the hand list: $d"
  fi
}
cell_PZ() { # <lib>
  local pop rc=0 o="$WORK/out.PZ.$RANDOM"
  pop="$( ( set -e; . "$1"; ai_dlc_once_paths "$PZD" ) 2>/dev/null)" || rc=$?
  [ "$rc" = 2 ] && [ -z "$pop" ]; chk $? "PZ: a declaration with no key returns 2 and prints no path (rc $rc)"
  rep "$1" 1 "$WM" "$PZD" "$o"
  [ "$RC" = 2 ] && ! grep -q 'scaffold-ignored' "$o"; chk $? "PZ: the report over an empty population returns 2 and prints no row (rc $RC)"
}
cell_WM() { # <lib>
  local n=0 m=0 line rel rem want st
  rcell WM "$1" "$WM" "$EXP_WM"
  while IFS= read -r line; do
    case "$line" in "  WARNING scaffold-ignored "*) ;; *) continue ;; esac
    n=$((n + 1))
    rel="${line#  WARNING scaffold-ignored }"; rel="${rel%% *}"
    rem="${line#*\"}"; rem="${rem%\"}"
    want="$( ( set -e; . "$N1_LIB"; st="$(scaffold_ignore_state "$WM" "$rel")"; scaffold_ignore_remedy "$rel" "${st#*$'\t'}" ) )"
    [ -n "$want" ] && [ "$rem" = "$want" ] && m=$((m + 1))
  done < "$LASTOUT"
  [ "$n" -gt 0 ] && [ "$m" = "$n" ]; chk $? "WM: $m of $n remedies are byte-equal to scaffold_ignore_remedy for the same rel and provenance"
}
cell_WU() { rcell WU "$1" "$WU" "$EXP_WU"; }
cell_WB() { rcell WB "$1" "$WB" "SKIP"; }
cell_WN() {
  rcell WN "$1" "$WN" "SKIP"
  grep -qxF "  scaffold ignore check SKIPPED: $WN is not a git work tree" "$LASTOUT"; chk $? "WN: the SKIPPED line names the target"
}
cell_WS() {
  rcell WS "$1" "$WS" "$EXP_WS"
  grep -qxF "  (git work tree: $WSR_TOP)" "$LASTOUT"; chk $? "WS: the header names the root's work tree $WSR_TOP"
}
cell_WG() { rcell WG "$1" "$WG" "HDR" GIT_DIR="$WGO/.git"; }
cell_WX() { rcell WX "$1" "$WX" "$(rows HDR TRAILER "IGN $SM")"; }
cell_WQ() { rcell WQ "$1" "$WQ" "HDR"; }
cell_WT() { # <lib>: one fresh world per call, because the second report follows a `git add -f`
  local t
  t="$(fresh)/t"
  { newrepo "$t" && seedfile "$t/$SM" "seeded" && printf '%s/*.txt\n' "$SMD" > "$t/.gitignore"; } || broken "WT seed failed"
  rcell WT:untracked "$1" "$t" "$(rows HDR TRAILER "IGN $SM")"
  git -C "$t" add -f -- "$SM" || broken "WT could not track $SM"
  rcell WT:tracked "$1" "$t" "HDR"
}
cell_WE() { # <lib>
  DECISION=stub; rcell WE "$1" "$WM" "$EXP_WE"; DECISION=1
  grep -qxF "  WARNING scaffold-ignore-unchecked $SM (scaffold_ignore_state answered 'bogus')" "$LASTOUT"
  chk $? "WE: the unknown word is named in the row"
}
ICELLS="P PZ WM WU WB WN WS WG WX WQ WT WE"

B_P=0; B_PZ=0; B_WM=0; B_WU=0; B_WB=0; B_WN=0; B_WS=0; B_WG=0; B_WX=0; B_WQ=0; B_WT=0; B_WE=0
JF=0; cell_P "$SI_LIB";  if [ "$JF" = 0 ]; then B_P=1;  ok "unmutated baseline: P held whole"; fi
JF=0; cell_PZ "$SI_LIB"; if [ "$JF" = 0 ]; then B_PZ=1; ok "unmutated baseline: PZ held whole"; fi
JF=0; cell_WM "$SI_LIB"; if [ "$JF" = 0 ]; then B_WM=1; ok "unmutated baseline: WM held whole"; fi
JF=0; cell_WU "$SI_LIB"; if [ "$JF" = 0 ]; then B_WU=1; ok "unmutated baseline: WU held whole"; fi
JF=0; cell_WB "$SI_LIB"; if [ "$JF" = 0 ]; then B_WB=1; ok "unmutated baseline: WB held whole"; fi
JF=0; cell_WN "$SI_LIB"; if [ "$JF" = 0 ]; then B_WN=1; ok "unmutated baseline: WN held whole"; fi
JF=0; cell_WS "$SI_LIB"; if [ "$JF" = 0 ]; then B_WS=1; ok "unmutated baseline: WS held whole"; fi
JF=0; cell_WG "$SI_LIB"; if [ "$JF" = 0 ]; then B_WG=1; ok "unmutated baseline: WG held whole"; fi
JF=0; cell_WX "$SI_LIB"; if [ "$JF" = 0 ]; then B_WX=1; ok "unmutated baseline: WX held whole"; fi
JF=0; cell_WQ "$SI_LIB"; if [ "$JF" = 0 ]; then B_WQ=1; ok "unmutated baseline: WQ held whole"; fi
JF=0; cell_WT "$SI_LIB"; if [ "$JF" = 0 ]; then B_WT=1; ok "unmutated baseline: WT held whole"; fi
JF=0; cell_WE "$SI_LIB"; if [ "$JF" = 0 ]; then B_WE=1; ok "unmutated baseline: WE held whole"; fi

# --- the end-to-end installs ------------------------------------------------------------------------
# run_inst <installer> <target> <out> <cwd> [VAR=value ...]: one install start; RC holds its exit.
# An installer under the work dir is a mutant text, run with the real install.sh as its $0.
run_inst() {
  local inst="$1" t="$2" o="$3" cwd="$4"
  shift 4
  RC=0
  case "$inst" in
    "$WORK"/*) ( cd "$cwd" && env "$@" bash -c "$(cat "$inst")" "$INSTALL" "$t" ) </dev/null >"$o" 2>&1 || RC=$? ;;
    *) ( cd "$cwd" && env "$@" bash "$inst" "$t" ) </dev/null >"$o" 2>&1 || RC=$? ;;
  esac
}
HDR='Checking scaffolded files against git ignore rules...'
common() { # <world> <out>
  [ "$RC" = 0 ]; chk $? "$1: install exits 0 (got $RC)"
  grep -qF 'Installation complete!' "$2"; chk $? "$1: install prints Installation complete!"
  ! grep -qE 'fatal:|No such file|command not found' "$2"; chk $? "$1: the install output carries none of the three broken-step diagnostics"
}
reached() { { grep -qF "$HDR" "$1" || grep -q '^  scaffold ignore check SKIPPED: ' "$1"; } && grep -qF 'Installation complete!' "$1"; }

seed_e1() { # <dir> -> <dir>/t, the E1 target before install
  local t="$1/t"
  { mkdir -p "$t/_bmad" && newrepo "$t"; } || return 1
  printf '*.md\n*.txt\n%s\n!%s\n' "$CW" "$RO" > "$t/.gitignore"
  seedfile "$t/$RX" "consumer tracked extensions readme" && cp "$t/$RX" "$1/rx.before" || return 1
  git -C "$t" add -f -- "$RX"
}
exp_e1() {
  local p
  echo HDR; echo TRAILER
  while IFS= read -r p; do
    case "$p" in "$CW"|"$RO"|"$RX") ;; *) echo "IGN $p" ;; esac
  done <<EOF
$POP0_S
EOF
}
EXP_E1="$(exp_e1 | srt)"
E1_D=""; E1_T=""
world_e1() { # <installer> <tag>
  local d t o nfx
  d="$(fresh)" && seed_e1 "$d" || broken "E1 seed failed"
  t="$d/t"; o="$d/out"; LASTOUT="$o"; E1_D="$d"; E1_T="$t"
  run_inst "$1" "$t" "$o" "$WORK/elsewhere" ${2:+FXCELL=$2}
  common E1 "$o"
  setcmp E1 "$EXP_E1" "$o"
  cmp -s "$d/rx.before" "$t/$RX"; chk $? "E1: the pre-created tracked README is preserved byte for byte"
  nfx="$(find "$t/tests/fixtures" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -c .)" || nfx=0
  [ "$nfx" -gt 0 ] && [ ! -e "$t/tests/fixtures/$FX_NAME" ]
  chk $? "E1: $FX_NAME is absent from the installed tests/fixtures/ ($nfx shipping fixture dir(s) present)"
  cp "$t/.gitignore" "$d/gitignore.after" 2>/dev/null || :
}
world_e2() { # <installer> <tag> <E1 tree>
  local t="$3" o
  o="$(dirname "$t")/out2"; LASTOUT="$o"
  run_inst "$1" "$t" "$o" "$ROOT_DIR" ${2:+FXCELL=$2}
  common E2 "$o"
  setcmp E2 "$EXP_E1" "$o"
}
world_e4() { # <installer> <tag>
  local d t o pre=0
  d="$(fresh)" || broken "a world seed step failed"
  t="$d/t"; o="$d/out"; LASTOUT="$o"
  { mkdir -p "$t/_bmad" && newrepo "$t"; } || broken "E4 seed failed"
  jq --arg p "$SM" --arg g "$SMD/*.txt" '.paths += [{"path": $p, "transient": true, "ignore": $g}]' \
    "$ROOT_DIR/core/schemas/pipeline-state-paths.json" > "$d/schema.json" || broken "E4 could not seed the declaration"
  git -C "$t" check-ignore -q -- "$SM" 2>/dev/null || pre=$?
  [ "$pre" = 1 ] || broken "E4's smoke surface is ignored before the render (rc $pre), so the world cannot tell before from after"
  run_inst "$1" "$t" "$o" "$ROOT_DIR" AI_DLC_STATE_PATHS_SCHEMA="$d/schema.json" ${2:+FXCELL=$2}
  common E4 "$o"
  setcmp E4 "$(rows HDR TRAILER "IGN $SM")" "$o"
}
world_e5() { # <installer> <tag>
  local d t o
  d="$(fresh)" || broken "a world seed step failed"
  t="$d/t"; o="$d/out"; LASTOUT="$o"
  mkdir -p "$t/_bmad" || broken "a world seed step failed"
  git -C "$t" rev-parse --git-dir >/dev/null 2>&1 && broken "E5's target $t is inside a git repository"
  run_inst "$1" "$t" "$o" "$ROOT_DIR" ${2:+FXCELL=$2}
  common E5 "$o"
  setcmp E5 "SKIP" "$o"
  grep -qxF "  scaffold ignore check SKIPPED: $t is not a git work tree" "$o"; chk $? "E5: the SKIPPED line names the target"
}

B_E1=0; B_E2=0; B_E4=0; B_E5=0; B_AB1=0; B_AB2=0
JF=0; world_e1 "$INSTALL" e1
if [ "$JF" = 0 ]; then B_E1=1; ok "unmutated baseline: E1 held whole"; fi
E1_GI="$E1_D/gitignore.after"
E1_SNAP="$WORK/e1snap"
if [ "$MATRIX" = 1 ]; then cp -Rp "$E1_D" "$E1_SNAP" || broken "could not snapshot E1"; fi
JF=0; world_e2 "$INSTALL" e2 "$E1_T"
if [ "$JF" = 0 ]; then B_E2=1; ok "unmutated baseline: E2 held whole"; fi
JF=0; world_e4 "$INSTALL" e4
if [ "$JF" = 0 ]; then B_E4=1; ok "unmutated baseline: E4 held whole"; fi
JF=0; world_e5 "$INSTALL" e5
if [ "$JF" = 0 ]; then B_E5=1; ok "unmutated baseline: E5 held whole"; fi

# --- copies of install.sh -----------------------------------------------------------------------------
SRC="$(cat "$INSTALL"; printf x)"; SRC="${SRC%x}"
# write_copy <name> <content> -> <work>/imut/install-mut-<name>.sh; rc 1 when it equals install.sh.
write_copy() {
  local p="$WORK/imut/install-mut-$1.sh"
  mkdir -p "$WORK/imut" && printf '%s' "$2" > "$p" || return 1
  cmp -s "$p" "$INSTALL" && return 1
  printf '%s' "$p"
}
# subst <text> <old> <new> -> <text> with its one <old> replaced; rc 1 unless <old> occurs once.
subst() {
  [ "$(count_of "$1" "$2")" = 1 ] || return 1
  printf '%s' "${1%%"$2"*}$3${1#*"$2"}"
}
CALL='ai_dlc_scaffold_ignore_report "$PROJECT_ROOT" "$AI_DLC_ROOT"'
RS='echo "Installing transient-state ignore rules..."'
DONE='echo "Installation complete!"'
N1_REF='"$SCRIPT_DIR/../core/skills/ai-dlc-update/reconcile/scaffold-ignore.sh"'
SI_REF='"$SCRIPT_DIR/install-scaffold-ignore.sh"'
for _a in "$CALL" "$RS" "$DONE" "$N1_REF" "$SI_REF"; do
  [ "$(count_of "$SRC" "$_a")" = 1 ] || broken "anchor '$_a' is not unique in $INSTALL"
done
# Carrier control: install.sh's unmutated text, run the way every install mutant runs, holds E1 and
# E4 whole. An install mutant's kill is scored only on top of it.
CARRIER="$WORK/imut/carrier-control.sh"
{ mkdir -p "$WORK/imut" && printf '%s' "$SRC" > "$CARRIER" && cmp -s "$CARRIER" "$INSTALL"; } || broken "could not write the carrier control"
QUIET=1; JF=0; world_e1 "$CARRIER" ""; world_e4 "$CARRIER" ""; QUIET=0
if [ "$JF" = 0 ]; then ok "carrier control: the unmutated text run as a mutant runs holds E1 and E4 whole"
else bad "carrier control: the unmutated text run as a mutant runs failed $JF E1/E4 assertion(s)"; B_E1=0; B_E4=0; fi

# AB1/AB2: one function file absent. ab_cell <label> <install text> <ref> -- the copy names
# <ref> with -ABSENT spliced in, a name asserted absent, so the real tree is never edited.
ab_cell() {
  local w="$1" txt="$2" ref="$3" absref rest p d t o before after gone
  absref="${ref%.sh\"}-ABSENT.sh\""
  rest="${absref#\"\$SCRIPT_DIR}"; rest="${rest%\"}"
  gone="$ROOT_DIR/scripts$rest"
  [ ! -e "$gone" ] || broken "$w: $gone exists, so the copy would not model an absent file"
  txt="$(subst "$txt" "$ref" "$absref")" || { chk 1 "$w: the absent-file edit did not apply"; return; }
  p="$(write_copy "$w-$RANDOM" "$txt")" || { chk 1 "$w: could not write the copy"; return; }
  d="$(fresh)"; t="$d/t"; o="$d/out"; LASTOUT="$o"
  { mkdir -p "$t/_bmad" && newrepo "$t"; } || broken "$w seed failed"
  before="$(cd "$t" && find . | srt)"
  run_inst "$p" "$t" "$o" "$ROOT_DIR"
  after="$(cd "$t" && find . | srt)"
  [ "$RC" != 0 ]; chk $? "$w: install exits non-zero with a function file absent (got $RC)"
  grep -qF "Error: $gone is missing" "$o"; chk $? "$w: the error names the missing file"
  ! grep -qF 'Installation complete!' "$o" && ! grep -qE 'scaffold-ignored|scaffold ignore check|Checking scaffolded files' "$o"
  chk $? "$w: no completion line and no report line"
  [ "$before" = "$after" ]; chk $? "$w: the target is exactly as seeded (nothing was written)"
}
JF=0; ab_cell AB1 "$SRC" "$N1_REF"
if [ "$JF" = 0 ]; then B_AB1=1; ok "unmutated baseline: AB1 held whole"; fi
JF=0; ab_cell AB2 "$SRC" "$SI_REF"
if [ "$JF" = 0 ]; then B_AB2=1; ok "unmutated baseline: AB2 held whole"; fi

# --- the mutants ---------------------------------------------------------------------------------------
LIB_SRC="$(cat "$SI_LIB"; printf x)"; LIB_SRC="${LIB_SRC%x}"
LMUTANTS="no-scrub git-dir-gate no-gate pop-nokeys pop-noreadme pop-nofeedback pop-empty-ok repo-rel fold-unchecked exact-as-ignored drop-exists remedy-noprov fault-quiet state-unguarded"
IMUTANTS="call-break exit-nonzero before-render lib-optional"
# lmut_spec <name>: M_CELL (its deciding cells), M_OLD -> M_NEW in scripts/install-scaffold-ignore.sh.
lmut_spec() {
  case "$1" in
    no-scrub) M_CELL="WG"; M_OLD='( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY'; M_NEW='( :' ;;
    git-dir-gate) M_CELL="WB"; M_OLD='rev-parse --is-inside-work-tree 2>/dev/null)" != "true"'; M_NEW='rev-parse --git-dir >/dev/null 2>&1 && echo true)" != "true"' ;;
    no-gate) M_CELL="WB WN"; M_OLD='if [ "$(git -C "$root" rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then'; M_NEW='if false; then' ;;
    pop-nokeys) M_CELL="P"; M_OLD='  printf '"'"'%s\n'"'"' "$keys"'; M_NEW='  :' ;;
    pop-noreadme) M_CELL="P"; M_OLD='    printf '"'"'.claude/skills/ai-dlc/%s/README.md\n'"'"' "$layer"'; M_NEW='    :' ;;
    pop-nofeedback) M_CELL="P"; M_OLD='  printf '"'"'%s\n'"'"' "docs/ai-dlc-feedback.md"'; M_NEW='  :' ;;
    pop-empty-ok) M_CELL="PZ"; M_OLD='population." >&2
    return 2'; M_NEW='population." >&2
    return 0' ;;
    repo-rel) M_CELL="WS"; M_OLD='echo "  WARNING scaffold-ignored $rel'; M_NEW='echo "  WARNING scaffold-ignored $(git -C "$root" rev-parse --show-prefix)$rel' ;;
    fold-unchecked) M_CELL="WU"; M_OLD='echo "  WARNING scaffold-ignore-unchecked $rel (git check-ignore exited ${st#unchecked:})" ;;'; M_NEW=': ;;' ;;
    exact-as-ignored) M_CELL="WM"; M_OLD='      ignored)'; M_NEW='      ignored|exact)' ;;
    drop-exists) M_CELL="WX"; M_OLD='[ -e "$root/$rel" ] || continue'; M_NEW=':' ;;
    remedy-noprov) M_CELL="WM"; M_OLD='scaffold_ignore_remedy "$rel" "$prov"'; M_NEW='scaffold_ignore_remedy "$rel" ""' ;;
    fault-quiet) M_CELL="WE"; M_OLD='      exact|untracked-ok) : ;;'; M_NEW='      exact|untracked-ok|*) : ;;' ;;
    state-unguarded) M_CELL="WE"; M_OLD='line="$(scaffold_ignore_state "$root" "$rel")" || line=""'; M_NEW='line="$(scaffold_ignore_state "$root" "$rel")"' ;;
    *) return 1 ;;
  esac
}
# build_lmut <name> -> a sourceable mutated copy under WORK; it must parse and source to 0 bytes.
build_lmut() {
  local p="$WORK/libmut-$1.sh" out
  lmut_spec "$1" || return 1
  out="$(subst "$LIB_SRC" "$M_OLD" "$M_NEW")" || return 1
  printf '%s\n' "$out" > "$p" || return 1
  cmp -s "$p" "$SI_LIB" && return 1
  bash -n "$p" 2>/dev/null || return 1
  [ -z "$( ( set -e; . "$N1_LIB"; . "$p" ) 2>&1)" ] || return 1
  printf '%s' "$p"
}
# imut_spec <name>: M_WORLD, and the edits to install.sh's text (M_OLD -> M_NEW, then M_OLD2 -> M_NEW2,
# then M_OLD3 -> M_NEW3 where set), or M_MOVE=1 (the call moved before the render).
imut_spec() {
  M_MOVE=0; M_OLD2=""; M_NEW2=""; M_OLD3=""; M_NEW3=""
  case "$1" in
    call-break) M_WORLD=E1; M_OLD="$CALL"; M_NEW=':' ;;
    exit-nonzero) M_WORLD=E1
      M_OLD="$CALL"; M_NEW='ai_dlc_si_out="$('"$CALL"')"; printf '"'"'%s\n'"'"' "$ai_dlc_si_out"'
      M_OLD2="$DONE"; M_NEW2="$DONE"'; case "$ai_dlc_si_out" in *scaffold-ignored*) exit 1 ;; esac' ;;
    before-render) M_WORLD=E4; M_MOVE=1 ;;
    lib-optional) M_WORLD=AB2
      M_OLD='  if [ ! -f "$ai_dlc_si_lib" ]; then'; M_NEW='  if false; then'
      M_OLD2='  . "$ai_dlc_si_lib"'; M_NEW2='  if [ -f "$ai_dlc_si_lib" ]; then . "$ai_dlc_si_lib"; fi'
      M_OLD3="$CALL"; M_NEW3="$CALL"' 2>/dev/null || :' ;;
    *) return 1 ;;
  esac
}
# imut_text <name> -> install.sh's text with the mutant applied (stdout); rc 1 when it does not apply.
imut_text() {
  local out
  imut_spec "$1" || return 1
  if [ "$M_MOVE" = 1 ]; then
    out="$(subst "$SRC" "$CALL" ':')" || return 1
    out="$(subst "$out" "$RS" "$CALL
$RS")" || return 1
  else
    out="$(subst "$SRC" "$M_OLD" "$M_NEW")" || return 1
    if [ -n "$M_OLD2" ]; then out="$(subst "$out" "$M_OLD2" "$M_NEW2")" || return 1; fi
    if [ -n "$M_OLD3" ]; then out="$(subst "$out" "$M_OLD3" "$M_NEW3")" || return 1; fi
  fi
  [ "$out" != "$SRC" ] || return 1
  printf '%s\n' "$out"
}
# icell <cell> <install text> <name>: one install-level cell under a mutated copy. E2 installs into a
# fresh copy of the E1 snapshot (--matrix only). AB1/AB2 splice the absent path on top.
icell() {
  local w="$1" txt="$2" m="$3" p s
  LASTOUT=""
  case "$w" in
    AB1) ab_cell AB1 "$txt" "$N1_REF"; return ;;
    AB2) ab_cell AB2 "$txt" "$SI_REF"; return ;;
  esac
  p="$(write_copy "$m-$w" "$txt")" || { chk 1 "mutant $m: could not write the copy"; return; }
  case "$w" in
    E1) world_e1 "$p" "" ;;
    E2) s="$(fresh)" && cp -Rp "$E1_SNAP/t" "$s/t" && world_e2 "$p" "" "$s/t" ;;
    E4) world_e4 "$p" "" ;;
    E5) world_e5 "$p" "" ;;
  esac
}
# A kill: the cell failed under the mutant AND the run completed and reached the report. call-break
# is exempt from the report half because its subject IS the missing report; an absent-file cell
# fails only by COMPLETING, so there completion alone is the reach.
ireached() { # <name> <cell>
  [ -n "$LASTOUT" ] || return 1
  case "$2" in AB1|AB2) grep -qF 'Installation complete!' "$LASTOUT"; return ;; esac
  if [ "$1" = call-break ]; then [ "$RC" = 0 ] && grep -qF 'Installation complete!' "$LASTOUT"; return; fi
  reached "$LASTOUT"
}

run_lmut() { # <name> <the deciding cell's base flag>
  local m="$1" p c
  lmut_spec "$m" || { bad "mutant $m has no spec"; return; }
  p="$(build_lmut "$m")"
  if [ -z "$p" ] || [ ! -f "$p" ]; then bad "mutant $m DID NOT APPLY cleanly (anchor not unique, copy equals the subject, or it does not source to 0 bytes)"; return; fi
  need_base "$2" "$m" || return
  QUIET=1; JF=0
  for c in $M_CELL; do "cell_$c" "$p"; done
  QUIET=0
  if [ "$JF" -gt 0 ]; then mutant_killed "$2" "$m" "mutant $m killed by $M_CELL ($JF assertion(s))"
  else bad "mutant $m SURVIVED $M_CELL"; fi
}
GI_BASE=""
run_imut() { # <name> <the deciding world's base flag>
  local m="$1" txt
  imut_spec "$m" || { bad "mutant $m has no spec"; return; }
  txt="$(imut_text "$m")" || { bad "mutant $m DID NOT APPLY (an anchor is not unique in install.sh, or the copy equals the subject)"; return; }
  need_base "$2" "$m" || return
  QUIET=1; JF=0
  icell "$M_WORLD" "$txt" "$m"
  QUIET=0
  if [ "$m" = call-break ] && [ -n "$E1_D" ]; then GI_BASE="$E1_D/gitignore.after"; fi
  if [ "$JF" = 0 ]; then bad "mutant $m SURVIVED $M_WORLD"
  elif ! ireached "$m" "$M_WORLD"; then bad "mutant $m did not complete and reach the report ($M_WORLD): a refusal is never a kill"
  else mutant_killed "$2" "$m" "mutant $m killed by $M_WORLD ($JF assertion(s))"; fi
}

if [ "$MATRIX" = 1 ]; then
  # Every mutant against every cell of its kind; 1 = the cell failed, R = the run did not reach the report.
  for m in $LMUTANTS; do
    p="$(build_lmut "$m")"; [ -n "$p" ] || { bad "mutant $m DID NOT APPLY"; continue; }
    v=""
    for c in $ICELLS; do QUIET=1; JF=0; "cell_$c" "$p"; QUIET=0; if [ "$JF" -gt 0 ]; then v="$v $c=1"; else v="$v $c=0"; fi; done
    echo "MATRIX $m$v"
  done
  for m in $IMUTANTS; do
    txt="$(imut_text "$m")" || { bad "mutant $m DID NOT APPLY"; continue; }
    v=""
    for c in E1 E2 E4 E5 AB1 AB2; do
      QUIET=1; JF=0; icell "$c" "$txt" "$m"; QUIET=0
      if [ "$JF" = 0 ]; then v="$v $c=0"; elif ireached "$m" "$c"; then v="$v $c=1"; else v="$v $c=R"; fi
    done
    echo "MATRIX $m$v"
  done
else
  for m in $LMUTANTS; do
    lmut_spec "$m" || { bad "mutant $m has no spec"; continue; }
    case "${M_CELL%% *}" in
      P)
        run_lmut "$m" "${B_P:-0}" ;;
      PZ)
        run_lmut "$m" "${B_PZ:-0}" ;;
      WM)
        run_lmut "$m" "${B_WM:-0}" ;;
      WU)
        run_lmut "$m" "${B_WU:-0}" ;;
      WB)
        run_lmut "$m" "$(( ${B_WB:-0} && ${B_WN:-0} ))" ;;
      WS)
        run_lmut "$m" "${B_WS:-0}" ;;
      WG)
        run_lmut "$m" "${B_WG:-0}" ;;
      WX)
        run_lmut "$m" "${B_WX:-0}" ;;
      WE)
        run_lmut "$m" "${B_WE:-0}" ;;
      *) bad "mutant $m names no cell" ;;
    esac
  done
  for m in $IMUTANTS; do
    imut_spec "$m" || { bad "mutant $m has no spec"; continue; }
    case "$M_WORLD" in
      E1)
        run_imut "$m" "${B_E1:-0}" ;;
      E4)
        run_imut "$m" "${B_E4:-0}" ;;
      AB2)
        run_imut "$m" "${B_AB2:-0}" ;;
      *) bad "mutant $m names no world" ;;
    esac
  done
  # BASE: the call-break run is install.sh without its report. It completed (ireached), printed no
  # report line, failed E1 (its kill above), and its .gitignore is the same-world baseline for E1's.
  if [ -n "$GI_BASE" ] && [ -f "$GI_BASE" ] && [ -f "$E1_GI" ]; then
    cmp -s "$E1_GI" "$GI_BASE"; chk $? "E1: the .gitignore the install leaves equals BASE's from the same seeded world, byte for byte"
    [ "$(grep -c . "$GI_BASE")" -gt 4 ]; chk $? "E1: BASE's .gitignore carries the render's block beyond the 4 seeded lines"
  else
    bad "E1: no BASE .gitignore to compare against (the call-break run did not leave one)"
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "PASS: install-scaffold-ignored"; exit 0; fi
echo "FAIL: install-scaffold-ignored ($fails failure(s))"
exit 1
