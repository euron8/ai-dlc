#!/usr/bin/env bash
# census-hermetic-coverage -- bind scripts/census-hermetic-coverage.sh: it must score a seeded fixture whose
# skip branch hides an undeclared input as MISMATCH PLAIN-MORE, and stay quiet (EQUAL) on a fixture that agrees
# across the two runs for every reason a careless census would split them.
#
# Every corpus is a mini repository seeded under mktemp (hermetic-runner's mk_probe shape): the real hook,
# suite-content-key.sh, hermetic-run.sh and core-paths.sh copied in, the seeded fixtures beside them, all
# committed, so the census's clean-root check and hermetic-run's work-tree check both hold.
#
# WORLD A (one census run, the discriminating member never first):
#   s-quiet   EQUAL: reads data/a.txt RELATIVE to the cwd, runs a tool that exists only in the hermetic tool
#             farm (a READSET_TOOL_XP dir), prints one ok line on STDERR, and prints the project root and a
#             mktemp path inside ok lines. Each is a reason a wrong census splits the two runs.
#   s-skip    MISMATCH PLAIN-MORE + NO-GIT-DECL: its skip branch hides an undeclared tracked input, and it
#             calls git with no git.decl. This is BL-497 residue (a), the shape the census exists for.
#   s-digit   MISMATCH DIFFER, NO tag: one ok line differs only in a digit; it calls git and declares
#             `git.decl: seed`, so it is the control for the NO-GIT-DECL tag.
#   s-silent  UNCOUNTABLE: no ok line at all, never `0 = 0` EQUAL.
#   s-low     LOW-RES: one ok line, equal.
#   s-absent  REFUSED: its declared input is absent, so hermetic-run exits 2.
#   s-flaky   FLAKY: an extra ok line on its second invocation only, via a counter outside both roots.
#   s-bothfail BOTH-FAIL: exit 1 on both sides over identical lines, never EQUAL.
#   s-rc2     REFUSED, note fixture-rc-2: exits 2 only where `.git` is absent (the sandbox), counted apart in
#             the summary.
#   s-volatile EQUIVALENT DIFFER: one ok line carries a sha that moves on every invocation (counter-driven).
#   s-mixed   MISMATCH DIFFER: the moving sha AND a count that is 13 plain / 12 hermetic in every rep, on ONE
#             line -- the token-level rule keeps it, a line-level rule acquits it.
#   s-repeat  MISMATCH DIFFER: the differing key `ok n=<N>` occurs twice per side, one stable, one moving.
#   s-flicker MISMATCH DIFFER: a count STABLE at 13 on the plain side, 11 or 12 on the hermetic side and
#             moving across reps -- the FA1 shape. "Moves on at least one side" acquitted it; the range rule
#             over three reps keeps it, because {13} and {11,12} do not overlap.
#   s-overlap EQUIVALENT DIFFER: plain 3335/3337 alternating, hermetic 3336 every rep -- validator-fork-budget's
#             shape, the near-miss for s-flicker: a count, moving on one side, whose ranges DO overlap.
#   s-pathlen EQUAL: prints the lengths of TMPDIR and HOME, which differ between the runs unless the plain
#             side's paths are as long as the sandbox's (path-length world only).
#   s-marker  writes `.claude` into the census's scratch base during its own run (end-walk world only).
#   s-selfkill  on the plain side kills its own census worker (its parent, checked to be a `--pair` process),
#             so the run is incomplete and the pair's physical root is left (incomplete-run world only).
# WORLD B: s-dirty writes into the plain root -> REFUSED gitstate:status, and s-after behind it -> NOT-RUN.
# SCRATCH: every census call takes --scratch under a /private/tmp/chcfx.* base the fixture checks is marker-free.
#   keep     a pair dir is a symlink to a physical chc.* root, and --keep prints that root.
#   cleanup  a non-keep run leaves no chc.* root; control: the --keep runs left theirs.
#   preflight a `.claude` above the base refuses the census before any fixture runs.
#   end walk s-marker plants one mid-run; the census exits 2 naming it.
#   incomplete s-selfkill leaves its root; the summary names it by path and counts it, and it is on disk.
# STORE: the census leaves $HOME/.cache/ai-dlc/verdicts empty while its per-pair stores hold entries;
#   control: hermetic-run run directly with AI_DLC_VERDICT_STORE naming that HOME's store writes there.
# Exit: 0 = every assertion holds, 1 = an assertion failed, 2 = the fixture could not run.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
set -uo pipefail
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR
for _v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
# Both layouts named, never a single walk-up (I33c). The subject is distribution-only.
ROOT=""
for cand in "$HERE/../../.." "$HERE/../.."; do
  if [ -f "$cand/scripts/census-hermetic-coverage.sh" ] && [ -f "$cand/core/scripts/hermetic-run.sh" ]; then
    ROOT="$(cd "$cand" && pwd -P)"; break
  fi
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: could not locate scripts/census-hermetic-coverage.sh from $HERE" >&2; exit 2; }
CENSUS="$ROOT/scripts/census-hermetic-coverage.sh"
echo "HERMETIC-CONSUMED scripts/census-hermetic-coverage.sh"
HOOK_SRC=""
for c in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$c" ] && grep -q '^# READSET_UNIVERSE_BEGIN$' "$c" && { HOOK_SRC="$c"; break; }
done
SCK_SRC="$ROOT/scripts/suite-content-key.sh"
for f in "$HOOK_SRC" "$SCK_SRC" "$ROOT/core/scripts/hermetic-run.sh" "$ROOT/core/scripts/core-paths.sh"; do
  [ -n "$f" ] && [ -f "$f" ] || { echo "FIXTURE ERROR: a world input is absent: ${f:-<pre-push hook>}" >&2; exit 2; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/census-fx.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
# THE SCRATCH BASE every census call is handed with --scratch. Not under TMPDIR: in the gate TMPDIR sits under
# a per-user dir with a stray `.claude` above it, which the census's marker walk refuses. /private/tmp's walk is
# clean on this machine, and the fixture checks that itself below.
SCRB=/private/tmp; [ -d "$SCRB" ] || SCRB=/tmp
SCR="$(mktemp -d "$SCRB/chcfx.XXXXXX")" || { echo "FIXTURE ERROR: mktemp under $SCRB failed" >&2; exit 2; }
SCR="$(cd "$SCR" && pwd -P)"
trap 'rm -rf "$WORK"; case "$SCR" in /private/tmp/chcfx.??????|/tmp/chcfx.??????) rm -rf "$SCR" ;; esac' EXIT
mkdir -p "$SCR/keep" "$SCR/nokeep" "$SCR/mark" "$SCR/pre/base" || exit 2
for m in .git .claude core/skills/ai-dlc; do
  d="$SCR"; while [ "$d" != / ]; do
    [ -e "$d/$m" ] && { echo "FIXTURE ERROR: $d/$m sits above the scratch base; the marker arms cannot be told apart from it" >&2; exit 2; }
    d="$(dirname "$d")"
  done
done

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
echo "census-hermetic-coverage:"

# --- worlds -------------------------------------------------------------------------------------
XD="$WORK/xp"; mkdir -p "$XD" && printf '#!/bin/bash\necho farm-ran\n' > "$XD/b223tool" && chmod +x "$XD/b223tool" || exit 2
COUNTER="$WORK/flaky.count"

world_base() { # <dir>: the copied machinery, with the hook's READSET_TOOL_XP pointed at the farm-only tool dir
  local w="$1"
  mkdir -p "$w/.githooks" "$w/scripts" "$w/core/scripts" "$w/core/fixtures" "$w/data" "$w/extra" || exit 2
  sed "s|^READSET_TOOL_XP=\"\"|READSET_TOOL_XP=\"$XD\"|" "$HOOK_SRC" > "$w/.githooks/pre-push" || exit 2
  grep -q "^READSET_TOOL_XP=\"$XD\"\$" "$w/.githooks/pre-push" || { echo "FIXTURE ERROR: READSET_TOOL_XP anchor lost in the hook copy" >&2; exit 2; }
  cp "$SCK_SRC" "$w/scripts/suite-content-key.sh" && cp "$ROOT/core/scripts/hermetic-run.sh" "$ROOT/core/scripts/core-paths.sh" "$w/core/scripts/" || exit 2
  printf 'alpha\n' > "$w/data/a.txt"; printf 'beta\n' > "$w/extra/b.txt"
}
fx() { # <world> <name> <inputs.decl text> <run.sh body> [tools.decl text] [git.decl text]
  local d="$1/core/fixtures/$2"
  mkdir -p "$d" || exit 2
  printf '%s\n' "$3" > "$d/inputs.decl"
  { printf '#!/usr/bin/env bash\nset -u\n'; printf '%s\n' "$4"; } > "$d/run.sh"
  [ -z "${5:-}" ] || printf '%s\n' "$5" > "$d/tools.decl"
  [ -z "${6:-}" ] || printf '%s\n' "$6" > "$d/git.decl"
}
commit_world() {
  ( cd "$1" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm world ) >/dev/null 2>&1 \
    || { echo "FIXTURE ERROR: could not build world $1" >&2; exit 2; }
  [ -d "$1/.git" ] || { echo "FIXTURE ERROR: world $1 is not a repository" >&2; exit 2; }
}

WA="$WORK/world-a"; world_base "$WA"
fx "$WA" s-quiet 'data/a.txt' 'cat data/a.txt >/dev/null && echo "ok cwd-read data/a.txt"
o="$(b223tool 2>/dev/null)" && echo "ok farm-tool $o"
echo "ok stderr-line" >&2
echo "ok root-path $AI_DLC_PROJECT_ROOT/data/a.txt"
t="$(mktemp)" && echo "ok scratch-path $t"
exit 0' $'b223tool\ncat\nmktemp'
fx "$WA" s-skip 'data/a.txt' 'cat data/a.txt >/dev/null && echo "ok declared input read"
if [ -f extra/b.txt ]; then echo "ok extra input checked"; else echo "SKIP extra/b.txt absent"; fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "ok inside a repository"
echo "ok tail line"
echo "ok second tail line"
exit 0' $'cat\ngit'
fx "$WA" s-digit 'data/a.txt' 'n="$(ls core/fixtures | wc -l | tr -d " ")"
echo "ok fixtures=$n"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "ok inside a repository"
echo "ok tail line"
exit 0' $'ls\nwc\ntr\ngit' 'seed'
fx "$WA" s-silent 'data/a.txt' 'echo "checked the data"
exit 0'
fx "$WA" s-low 'data/a.txt' 'echo "ok one"
exit 0'
fx "$WA" s-absent 'data/missing.txt' 'echo "ok never reached"
exit 0'
fx "$WA" s-flaky 'data/a.txt' "c=\"$COUNTER\"; n=0; [ -f \"\$c\" ] && n=\"\$(cat \"\$c\")\"; n=\$((n + 1)); echo \"\$n\" > \"\$c\"
echo \"ok a\"; echo \"ok b\"; echo \"ok c\"
[ \"\$n\" = 2 ] && echo \"ok only on the second invocation\"
exit 0" cat
# The hermetic sandbox holds no .git for a fixture with no git.decl and the plain root does, so `[ -e .git ]`
# is a per-side value that is STABLE across reps; the counter outside both roots is a value that MOVES.
fx "$WA" s-bothfail 'data/a.txt' 'echo "ok a"; echo "ok b"; echo "ok c"
exit 1'
fx "$WA" s-rc2 'data/a.txt' 'echo "ok a"; echo "ok b"; echo "ok c"
[ -e .git ] || exit 2
exit 0'
vol() { # <counter file>: a shell line setting $h to a 7-hex sha that moves on every invocation
  printf 'c="%s"; n=0; [ -f "$c" ] && n="$(cat "$c")"; n=$((n + 1)); echo "$n" > "$c"; h="$(printf %%07x $((0x1a2b3c4 + n * 4097)))"' "$1"
}
fx "$WA" s-volatile 'data/a.txt' "$(vol "$WORK/vol.count")
echo \"ok at \$h the tree is consistent\"
echo \"ok b\"; echo \"ok c\"
exit 0" cat
fx "$WA" s-mixed 'data/a.txt' "$(vol "$WORK/mixed.count")
[ -e .git ] && k=13 || k=12
echo \"ok at \$h counted \$k of \$k\"
echo \"ok b\"; echo \"ok c\"
exit 0" cat
fx "$WA" s-repeat 'data/a.txt' "$(vol "$WORK/repeat.count")
[ -e .git ] && k=1 || k=2
echo \"ok n=\$k\"; echo \"ok n=9\$n\"
echo \"ok b\"; echo \"ok c\"
exit 0" cat
# cnt: a shell line bumping a per-fixture counter outside both roots into $n. Each of a fixture's pairs runs
# hermetic then plain in one worker, so a fixture's three hermetic runs see n0+1, n0+3, n0+5 and its plain
# runs n0+2, n0+4, n0+6; (n/2)%2 therefore alternates across reps on each side, whatever n0 is.
cnt() { printf 'c="%s"; n=0; [ -f "$c" ] && n="$(cat "$c")"; n=$((n + 1)); echo "$n" > "$c"' "$1"; }
fx "$WA" s-flicker 'data/a.txt' "$(cnt "$WORK/flicker.count")
[ -e .git ] && k=13 || k=\$((11 + (n / 2) % 2))
echo \"ok \$k cases scored\"
echo \"ok b\"; echo \"ok c\"
exit 0" cat
fx "$WA" s-overlap 'data/a.txt' "$(cnt "$WORK/overlap.count")
[ -e .git ] && k=\$((3335 + 2 * ((n / 2) % 2))) || k=3336
echo \"ok \$k forks counted\"
echo \"ok b\"; echo \"ok c\"
exit 0" cat
fx "$WA" s-pathlen 'data/a.txt' 'echo "ok tmpdir-len ${#TMPDIR}"
echo "ok home-len ${#HOME}"
echo "ok tail line"
exit 0'
fx "$WA" s-marker 'data/a.txt' 'b="${TMPDIR%%/chc.*}"; [ "$b" != "$TMPDIR" ] && mkdir -p "$b/.claude"
echo "ok a"; echo "ok b"; echo "ok c"
exit 0' mkdir
# s-selfkill kills its parent only when that parent is a census worker (`--pair` in its argv), and only on the
# plain side; a pid it cannot confirm is left alone, and the incomplete-run arm then fails presence-shaped.
fx "$WA" s-selfkill 'data/a.txt' 'echo "ok a"; echo "ok b"; echo "ok c"
if [ -e .git ]; then
  case "$(/bin/ps -o command= -p "$PPID" 2>/dev/null)" in *census-hermetic-coverage*--pair*) kill -9 "$PPID" ;; esac
fi
exit 0'
commit_world "$WA"

WB="$WORK/world-b"; world_base "$WB"
fx "$WB" s-dirty 'data/a.txt' 'echo "ok a"; echo "ok b"; echo "ok c"
: > "$AI_DLC_PROJECT_ROOT/dirt.txt"
exit 0'
fx "$WB" s-after 'data/a.txt' 'echo "ok a"; echo "ok b"; echo "ok c"
exit 0'
commit_world "$WB"

# --- driving the census --------------------------------------------------------------------------
C_RC=0; C_ERR=""; C_TSV=""; C_N=0
# C_KEEP and C_SCR are read by every call: --keep or nothing, and the --scratch base.
C_KEEP=--keep; C_SCR="$SCR/keep"
# census <script> <world> <list> <jobs>: sets C_RC, C_ERR (stderr text), C_TSV (the --out file)
census() {
  C_N=$((C_N + 1)); C_TSV="$WORK/c$C_N.tsv"; mkdir -p "$WORK/cw$C_N" "$WORK/home$C_N"
  C_ERR="$(cd "$2" && HOME="$WORK/home$C_N" bash "$1" --root "$2" --list "$3" --jobs "$4" --work "$WORK/cw$C_N" --scratch "$C_SCR" $C_KEEP --out "$C_TSV" 2>&1 >/dev/null)"; C_RC=$?
  [ -f "$C_TSV" ] || : > "$C_TSV"
}
chc_count() { find "$1" -mindepth 1 -maxdepth 1 -name 'chc.??????' | wc -l | tr -d ' '; } # <scratch base>
cell() { awk -F'\t' -v f="$1" -v c="$2" '$1 == f { print $c; exit }' "$C_TSV"; } # <fixture> <column>
vd() { printf '%s %s' "$(cell "$1" 2)" "$(cell "$1" 3)"; }                   # verdict + direction
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if grep -qF -- "$3" <<<"$2"; then ok "$1"; else bad "$1 (absent: $3)"; fi; }

# --- control: the census over world A ---------------------------------------------------
rm -f "$WORK/flaky.count"
PROBE_OK='self-probe: ok (21 cases)'
census "$CENSUS" "$WA" "s-quiet s-skip s-digit s-silent s-low s-absent s-flaky s-bothfail s-rc2 s-volatile s-mixed s-repeat s-flicker s-overlap s-pathlen" 3
if ! grep -qF "$PROBE_OK" <<<"$C_ERR" || [ "$(cell s-quiet 2)" != EQUAL ]; then
  echo "FIXTURE BROKEN: the census did not run cleanly over world A (rc=$C_RC); no verdict below would mean anything" >&2
  printf '%s\n' "$C_ERR" | head -20 >&2; cat "$C_TSV" >&2
  exit 2
fi
if [ "$C_RC" = 1 ] && [ "$(vd s-quiet)" = "EQUAL -" ]; then ok "c: census exits 1 on a world holding a mismatch"; else bad "c: census exits 1 on a world holding a mismatch (got '$C_RC')"; fi
has "c: summary line counts every verdict" "$C_ERR" "fixtures=15 EQUAL=2 EQUIVALENT=2 LOW-RES=1 MISMATCH=5 BOTH-FAIL=1 FLAKY=1 UNCOUNTABLE=1 REFUSED=1 fixture-rc-2=1 NOT-RUN=0 plain-more=1 no-git-decl=1"
eq "c: s-quiet (cwd read, farm tool, stderr line, root and scratch paths) reads EQUAL" "$(vd s-quiet)" "EQUAL -"
eq "c: s-quiet carries no diff" "$(cell s-quiet 13)" "-"
eq "c: s-quiet counted 5 ok lines on each side" "$(cell s-quiet 8)/$(cell s-quiet 9)" "5/5"
eq "c: s-skip reads MISMATCH PLAIN-MORE" "$(vd s-skip)" "MISMATCH PLAIN-MORE"
eq "c: s-skip is tagged NO-GIT-DECL" "$(cell s-skip 4)" "NO-GIT-DECL"
eq "c: s-skip's mismatch was confirmed by a re-pair" "$(cell s-skip 12)" "re-pair confirmed"
has "c: s-skip's diff names the hidden assertion" "$(cell s-skip 13)" "P: ok extra input checked"
eq "c: s-skip's skip-line counts read plain 0, hermetic 1" "$(cell s-skip 14)/$(cell s-skip 15)" "0/1"
eq "c: s-digit reads MISMATCH DIFFER" "$(vd s-digit)" "MISMATCH DIFFER"
eq "c: s-digit (git.decl seed) carries no NO-GIT-DECL tag" "$(cell s-digit 4)" "-"
eq "c: s-silent reads UNCOUNTABLE, never 0 = 0 EQUAL" "$(vd s-silent)" "UNCOUNTABLE -"
eq "c: s-low reads LOW-RES" "$(vd s-low)" "LOW-RES -"
eq "c: s-absent reads REFUSED" "$(vd s-absent)" "REFUSED -"
has "c: s-absent's note quotes the runner's refusal" "$(cell s-absent 12)" "runner-refused: hermetic-run: s-absent: declared file absent: data/missing.txt"
eq "c: s-flaky reads FLAKY" "$(vd s-flaky)" "FLAKY PLAIN-MORE"
eq "c: s-bothfail (exit 1 on both sides, identical lines) reads BOTH-FAIL, never EQUAL" "$(vd s-bothfail)" "BOTH-FAIL -"
eq "c: s-bothfail's note names the shared exit" "$(cell s-bothfail 12)" "both runs exited 1"
eq "c: s-rc2 (exit 2 in the sandbox only) reads REFUSED" "$(vd s-rc2)" "REFUSED -"
eq "c: s-rc2's note is fixture-rc-2, not a runner refusal" "$(cell s-rc2 12)" "fixture-rc-2"
eq "c: s-volatile (a sha moving every run) reads EQUIVALENT" "$(vd s-volatile)" "EQUIVALENT DIFFER"
has "c: s-volatile's note counts its one volatile token" "$(cell s-volatile 12)" "volatile token(s) 1,"
eq "c: s-mixed (moving sha + stable count on ONE line) reads MISMATCH" "$(vd s-mixed)" "MISMATCH DIFFER"
has "c: s-mixed's note names the stable count" "$(cell s-mixed 12)" "MISMATCH disjoint count 13,13,13/12,12,12"
eq "c: s-repeat (a differing key twice per side) reads MISMATCH" "$(vd s-repeat)" "MISMATCH DIFFER"
has "c: s-repeat's note names the repeated key" "$(cell s-repeat 12)" "MISMATCH differing key repeats"
eq "c: s-flicker (13 stable plain, 11/12 moving hermetic) reads MISMATCH" "$(vd s-flicker)" "MISMATCH DIFFER"
has "c: s-flicker's note names the disjoint count" "$(cell s-flicker 12)" "MISMATCH disjoint count 13,13,13/"
eq "c: s-overlap (3335/3337 plain, 3336 hermetic) reads EQUIVALENT" "$(vd s-overlap)" "EQUIVALENT DIFFER"
has "c: s-overlap's note is judged over three reps" "$(cell s-overlap 12)" "each passing its rule over three reps"
# Path length: the plain HOME and TMPDIR are as long as the sandbox's, so a fixture printing their lengths
# reads EQUAL (read from the control census).
eq "pathlen: s-pathlen (prints the lengths of TMPDIR and HOME) reads EQUAL" "$(vd s-pathlen)" "EQUAL -"
eq "pathlen: s-pathlen counted 3 ok lines on each side" "$(cell s-pathlen 8)/$(cell s-pathlen 9)" "3/3"

# --- the short physical scratch root -------------------------------------------------------------
pl="$(find "$WORK/cw1" -path '*/p.0001/1' | head -1)"
if [ -n "$pl" ] && [ -L "$pl" ]; then ok "scratch: a kept pair dir is a symlink"; else bad "scratch: the pair dir '$pl' is not a symlink"; fi
ph="$(cd "$pl" 2>/dev/null && pwd -P)"
case "$ph" in "$SCR/keep"/chc.??????) ok "scratch: it names a physical chc.* root under the --scratch base" ;;
  *) bad "scratch: the pair dir resolves to '$ph', not $SCR/keep/chc.XXXXXX" ;; esac
has "scratch: --keep prints the physical root" "$C_ERR" "kept scratch root: $SCR/keep/chc."

# --- store: the census never writes the default verdict store -------------------------------------
n="$(find "$WORK/home$C_N" -type f | wc -l | tr -d ' ')"
eq "store: the census wrote nothing under its HOME" "$n" 0
n="$(find "$SCR/keep" -path '*/vs/*' -type f | wc -l | tr -d ' ')"
if [ "$n" -gt 0 ]; then ok "store: the per-pair stores hold the hermetic passes ($n entries)"; else bad "store: no per-pair store entry, so the empty HOME proves nothing"; fi
mkdir -p "$WORK/home-direct"
( cd "$WA" && HOME="$WORK/home-direct" AI_DLC_VERDICT_STORE="$WORK/home-direct/.cache/ai-dlc/verdicts" bash "$WA/core/scripts/hermetic-run.sh" --root "$WA" s-low ) >/dev/null 2>&1
n="$(find "$WORK/home-direct/.cache/ai-dlc/verdicts" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$n" -gt 0 ]; then ok "store control: a direct hermetic-run naming the HOME store writes under HOME"; else bad "store control: a direct hermetic-run naming the HOME store wrote nothing under HOME, so the store arm cannot fire"; fi

# --- world B: a plain run that changes the root's git state stops the census ----------------------
census "$CENSUS" "$WB" "s-dirty s-after" 1
eq "gitstate: the census exits 2" "$C_RC" 2
eq "gitstate: s-dirty reads REFUSED" "$(vd s-dirty)" "REFUSED -"
eq "gitstate: s-dirty's note names the status snapshot" "$(cell s-dirty 12)" "gitstate:status"
eq "gitstate: s-after, behind it, reads NOT-RUN" "$(cell s-after 2)" "NOT-RUN"

census "$CENSUS" "$WA" "s-rc2 s-absent" 2
has "split control: the summary splits fixture-rc-2 from a runner refusal" "$C_ERR" "REFUSED=1 fixture-rc-2=1"

# Exit test: EQUIVALENT passes the census, BOTH-FAIL fails it. Each control is one verdict apart from EQUAL.
census "$CENSUS" "$WA" "s-bothfail" 1
eq "exit: a census holding a BOTH-FAIL row exits 1" "$C_RC/$(cell s-bothfail 2)" "1/BOTH-FAIL"

# --- the scratch root: links, cleanup, and the marker walk ------------------------------------------
# A non-keep run removes every physical chc.* root it made. s-volatile is re-paired, so it makes two.
C_KEEP=""; C_SCR="$SCR/nokeep"
census "$CENSUS" "$WA" "s-quiet s-volatile" 2
eq "cleanup: a non-keep run exits 0 and leaves no chc.* root under the scratch base" "$C_RC/$(chc_count "$SCR/nokeep")" "0/0"
eq "exit: a census whose only non-EQUAL row is EQUIVALENT exits 0" "$C_RC/$(cell s-volatile 2)" "0/EQUIVALENT"
n="$(chc_count "$SCR/keep")"
if [ "$n" -ge 12 ]; then ok "cleanup control: the --keep runs left their chc.* roots ($n)"; else bad "cleanup control: the --keep runs left $n chc.* roots, want at least 12, so a zero above proves nothing"; fi
C_KEEP=--keep

# Preflight: a marker above the scratch base refuses the census before any fixture runs.
mkdir -p "$SCR/pre/.claude" || exit 2
C_SCR="$SCR/pre/base"
census "$CENSUS" "$WA" "s-low" 1
eq "walk: a .claude above the scratch base refuses the census (exit 2)" "$C_RC" 2
has "walk: the refusal names the marker" "$C_ERR" "has a project marker above it ($SCR/pre/.claude)"
eq "walk: no fixture ran" "$(cell s-low 2)" ""

# End walk: s-marker writes a .claude above the scratch base during its own run; s-low beside it is the control.
C_SCR="$SCR/mark"
census "$CENSUS" "$WA" "s-low s-marker" 1
eq "walk: a marker appearing during the run fails the census (exit 2)" "$C_RC" 2
has "walk: the end-of-run walk names it" "$C_ERR" "a project marker appeared above the scratch base during the run ($SCR/mark/.claude)"
eq "walk: the rows still read (s-marker EQUAL)" "$(vd s-marker)" "EQUAL -"

# Incomplete run: s-selfkill kills its own worker on the plain side, so no row is written and the worker's
# cleanup never runs. The summary must name the physical root it left, by path, and count it.
mkdir -p "$SCR/inc" || exit 2; C_SCR="$SCR/inc"; C_KEEP=""
census "$CENSUS" "$WA" "s-selfkill" 1
has "incomplete: the run reports itself incomplete, naming s-selfkill" "$C_ERR" "the run is incomplete"
has "incomplete: no row for s-selfkill" "$C_ERR" "no row for: s-selfkill"
eq "incomplete: one chc.* root is left on disk" "$(chc_count "$SCR/inc")" 1
left="$(find "$SCR/inc" -mindepth 1 -maxdepth 1 -name 'chc.??????' | head -1)"
has "incomplete: the summary names that root by its path" "$C_ERR" "left scratch root: ${left:-<none on disk>}"
has "incomplete: the summary counts it" "$C_ERR" "1 physical scratch root(s) left under $SCR/inc"
C_KEEP=--keep

echo
report_end census-hermetic-coverage
