#!/usr/bin/env bash
# census-hermetic-coverage -- bind scripts/census-hermetic-coverage.sh: it must score a seeded fixture whose
# skip branch hides an undeclared input as MISMATCH PLAIN-MORE, stay quiet (EQUAL) on a fixture that agrees
# across the two runs for every reason a careless census would split them, and each wrong census
# implementation (M1-M22) must be killed by a presence-shaped assertion.
#
# Every corpus is a mini repository seeded under mktemp (hermetic-runner's mk_probe shape): the real hook,
# suite-content-key.sh, hermetic-run.sh and core-paths.sh copied in, the seeded fixtures beside them, all
# committed, so the census's clean-root check and hermetic-run's work-tree check both hold. Mutants are
# copies OUTSIDE the world, driven with --root, so a mutant never dirties the tree it measures.
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
#   s-marker  writes `.claude` into the census's scratch base during its own run (end-walk world only).
#   s-killed  on the plain side kills its own census worker (its parent, checked to be a `--pair` process),
#             so the run is incomplete and the pair's physical root is left (incomplete-run world only).
# WORLD B: s-dirty writes into the plain root -> REFUSED gitstate:status, and s-after behind it -> NOT-RUN.
# SCRATCH: every census call takes --scratch under a /private/tmp/chcfx.* base the fixture checks is marker-free.
#   keep     a pair dir is a symlink to a physical chc.* root, and --keep prints that root.
#   cleanup  a non-keep run leaves no chc.* root; control: the --keep runs left theirs.
#   preflight a `.claude` above the base refuses the census before any fixture runs.
#   end walk s-marker plants one mid-run; the census exits 2 naming it.
#   probe leak FI, a copy whose self-probe pair link resolves wrong, exits 2 and leaves no chc.* root (M22 drops that
#            cleanup and leaves one).
#   incomplete s-killed leaves its root; the summary names it by path and counts it, and it is on disk.
# STORE: the census leaves $HOME/.cache/ai-dlc/verdicts empty while its per-pair stores hold entries;
#   control: hermetic-run run directly with no AI_DLC_VERDICT_STORE writes under that HOME.
# MUTANTS, each a copy of the census, guarded by an exact replacement count and `cmp -s`:
#   M0 the self-probe call removed alone        -> s-quiet EQUAL, s-skip PLAIN-MORE (the control for M1/M2/M7/M8)
#   M1 rc-only compare                          -> self-probe names P2; with the probe removed s-skip reads EQUAL
#   M2 `0 = 0` EQUAL (no UNCOUNTABLE)           -> self-probe names P3; with the probe removed s-silent reads LOW-RES
#   M3 both runs sandboxed                      -> s-skip reads EQUAL
#   M4 plain run cd's into the fixture dir      -> s-quiet MISMATCH naming the cwd-read line
#   M5 plain run without the tool farm          -> s-quiet MISMATCH naming the farm-tool line
#   M6 stdout only                              -> s-quiet MISMATCH naming the stderr line
#   M7 hermetic exit 2 scored as a mismatch     -> self-probe names P4; with the probe removed s-absent reads MISMATCH
#   M8 digit-normalised multiset                -> self-probe names P5; with the probe removed s-digit reads EQUAL
#   M9 no BOTH-FAIL                             -> self-probe names P11; probe removed, s-bothfail reads EQUAL
#   M10 BOTH-FAIL keyed on the hermetic rc only -> self-probe names P12; probe removed, s-rc2 reads BOTH-FAIL
#   M11 line-level equivalence                  -> self-probe names E2; probe removed, s-mixed reads EQUIVALENT
#   M12 no multiplicity guard                   -> self-probe names E4; probe removed, s-repeat reads EQUIVALENT
#   M13 no token required to move               -> self-probe names E3; probe removed, s-mixed reads EQUIVALENT
#   M14 fixture-rc-2 folded into REFUSED        -> summary reads REFUSED=2 fixture-rc-2=0 (control: 1/1)
#   M15 EQUIVALENT fails the exit test          -> s-quiet + s-volatile exits 1 (control: 0)
#   M16 BOTH-FAIL passes the exit test          -> s-quiet + s-bothfail exits 0 (control: 1)
#   M17 only the pair link removed              -> physical chc.* roots leak under a non-keep run
#   M18 pair dir built in the work tree         -> the pair dir is a plain dir, not a link
#   M19 no preflight marker walk                -> s-low reaches the runner, whose escape guard refuses it
#   M20 no end-of-run marker walk               -> the census exits 0 with s-marker's marker present
#   M21 a count judged "moves on one side"      -> self-probe names FA1; probe removed, s-flicker reads EQUIVALENT
#   M22 the probe's failure path keeps its root -> a self-probe resolve failure leaves one chc.* root
#
# M11 and M13 are re-anchored on the three-rep rule: M11 acquits a line that moves as a whole, M13 checks no
# token at all.
#
# Exit: 0 = every assertion holds, 1 = an assertion failed, 2 = the fixture could not run.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
set -uo pipefail
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
mkdir -p "$SCR/keep" "$SCR/nokeep" "$SCR/kc" "$SCR/mark" "$SCR/pre/base" || exit 2
for m in .git .claude core/skills/ai-dlc; do
  d="$SCR"; while [ "$d" != / ]; do
    [ -e "$d/$m" ] && { echo "FIXTURE ERROR: $d/$m sits above the scratch base; the marker arms cannot be told apart from it" >&2; exit 2; }
    d="$(dirname "$d")"
  done
done

FAILS=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
echo "census-hermetic-coverage:"

# --- worlds -------------------------------------------------------------------------------------
XD="$WORK/xp"; mkdir -p "$XD" && printf '#!/bin/sh\necho farm-ran\n' > "$XD/b223tool" && chmod +x "$XD/b223tool" || exit 2
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
exit 0' 'b223tool'
fx "$WA" s-skip 'data/a.txt' 'cat data/a.txt >/dev/null && echo "ok declared input read"
if [ -f extra/b.txt ]; then echo "ok extra input checked"; else echo "SKIP extra/b.txt absent"; fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "ok inside a repository"
echo "ok tail line"
echo "ok second tail line"
exit 0'
fx "$WA" s-digit 'data/a.txt' 'n="$(ls core/fixtures | wc -l | tr -d " ")"
echo "ok fixtures=$n"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "ok inside a repository"
echo "ok tail line"
exit 0' '' 'seed'
fx "$WA" s-silent 'data/a.txt' 'echo "checked the data"
exit 0'
fx "$WA" s-low 'data/a.txt' 'echo "ok one"
exit 0'
fx "$WA" s-absent 'data/missing.txt' 'echo "ok never reached"
exit 0'
fx "$WA" s-flaky 'data/a.txt' "c=\"$COUNTER\"; n=0; [ -f \"\$c\" ] && n=\"\$(cat \"\$c\")\"; n=\$((n + 1)); echo \"\$n\" > \"\$c\"
echo \"ok a\"; echo \"ok b\"; echo \"ok c\"
[ \"\$n\" = 2 ] && echo \"ok only on the second invocation\"
exit 0"
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
exit 0"
fx "$WA" s-mixed 'data/a.txt' "$(vol "$WORK/mixed.count")
[ -e .git ] && k=13 || k=12
echo \"ok at \$h counted \$k of \$k\"
echo \"ok b\"; echo \"ok c\"
exit 0"
fx "$WA" s-repeat 'data/a.txt' "$(vol "$WORK/repeat.count")
[ -e .git ] && k=1 || k=2
echo \"ok n=\$k\"; echo \"ok n=9\$n\"
echo \"ok b\"; echo \"ok c\"
exit 0"
# cnt: a shell line bumping a per-fixture counter outside both roots into $n. Each of a fixture's pairs runs
# hermetic then plain in one worker, so a fixture's three hermetic runs see n0+1, n0+3, n0+5 and its plain
# runs n0+2, n0+4, n0+6; (n/2)%2 therefore alternates across reps on each side, whatever n0 is.
cnt() { printf 'c="%s"; n=0; [ -f "$c" ] && n="$(cat "$c")"; n=$((n + 1)); echo "$n" > "$c"' "$1"; }
fx "$WA" s-flicker 'data/a.txt' "$(cnt "$WORK/flicker.count")
[ -e .git ] && k=13 || k=\$((11 + (n / 2) % 2))
echo \"ok \$k mutants killed\"
echo \"ok b\"; echo \"ok c\"
exit 0"
fx "$WA" s-overlap 'data/a.txt' "$(cnt "$WORK/overlap.count")
[ -e .git ] && k=\$((3335 + 2 * ((n / 2) % 2))) || k=3336
echo \"ok \$k forks counted\"
echo \"ok b\"; echo \"ok c\"
exit 0"
fx "$WA" s-marker 'data/a.txt' 'b="${TMPDIR%%/chc.*}"; [ "$b" != "$TMPDIR" ] && mkdir -p "$b/.claude"
echo "ok a"; echo "ok b"; echo "ok c"
exit 0'
# s-killed kills its parent only when that parent is a census worker (`--pair` in its argv), and only on the
# plain side; a pid it cannot confirm is left alone, and the incomplete-run arm then fails presence-shaped.
fx "$WA" s-killed 'data/a.txt' 'echo "ok a"; echo "ok b"; echo "ok c"
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

# --- control: the unmutated census over world A ---------------------------------------------------
rm -f "$WORK/flaky.count"
PROBE_OK='self-probe: ok (21 cases)'
census "$CENSUS" "$WA" "s-quiet s-skip s-digit s-silent s-low s-absent s-flaky s-bothfail s-rc2 s-volatile s-mixed s-repeat s-flicker s-overlap" 3
if ! grep -qF "$PROBE_OK" <<<"$C_ERR" || [ "$(cell s-quiet 2)" != EQUAL ]; then
  echo "FIXTURE BROKEN: the unmutated census did not run cleanly over world A (rc=$C_RC); no mutant verdict below would mean anything" >&2
  printf '%s\n' "$C_ERR" | head -20 >&2; cat "$C_TSV" >&2
  exit 2
fi
eq "c: unmutated census exits 1 on a world holding a mismatch" "$C_RC" 1
has "c: summary line counts every verdict" "$C_ERR" "fixtures=14 EQUAL=1 EQUIVALENT=2 LOW-RES=1 MISMATCH=5 BOTH-FAIL=1 FLAKY=1 UNCOUNTABLE=1 REFUSED=1 fixture-rc-2=1 NOT-RUN=0 plain-more=1 no-git-decl=1"
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
( cd "$WA" && env -u AI_DLC_VERDICT_STORE HOME="$WORK/home-direct" bash "$WA/core/scripts/hermetic-run.sh" --root "$WA" s-low ) >/dev/null 2>&1
n="$(find "$WORK/home-direct/.cache/ai-dlc/verdicts" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$n" -gt 0 ]; then ok "store control: a direct hermetic-run with no store override writes under HOME"; else bad "store control: a direct hermetic-run wrote nothing under HOME, so the store arm cannot fire"; fi

# --- world B: a plain run that changes the root's git state stops the census ----------------------
census "$CENSUS" "$WB" "s-dirty s-after" 1
eq "gitstate: the census exits 2" "$C_RC" 2
eq "gitstate: s-dirty reads REFUSED" "$(vd s-dirty)" "REFUSED -"
eq "gitstate: s-dirty's note names the status snapshot" "$(cell s-dirty 12)" "gitstate:status"
eq "gitstate: s-after, behind it, reads NOT-RUN" "$(cell s-after 2)" "NOT-RUN"

# --- mutants --------------------------------------------------------------------------------------
mkdir -p "$WORK/mut"
# mut <name> [<count> <old> <new>]... -> prints the mutant path; each <old> must occur exactly <count> times.
mut() {
  local name="$1" dst c; shift
  dst="$WORK/mut/$name.sh"; cp "$CENSUS" "$dst" || return 1
  while [ $# -ge 3 ]; do
    c="$(MO="$2" MN="$3" awk 'BEGIN { o = ENVIRON["MO"]; n = ENVIRON["MN"] }
      { s = $0; out = ""; while ((i = index(s, o)) > 0) { out = out substr(s, 1, i - 1) n; s = substr(s, i + length(o)); k++ } print out s }
      END { print k + 0 > "/dev/stderr" }' "$dst" 2>&1 >"$dst.t")" || { echo "DID NOT APPLY: $name (awk failed)" >&2; return 1; }
    [ "$c" = "$1" ] || { echo "DID NOT APPLY: $name (anchor matched $c times, want $1): $2" >&2; return 1; }
    mv "$dst.t" "$dst"; shift 3
  done
  cmp -s "$CENSUS" "$dst" && { echo "DID NOT APPLY: $name (copy unchanged)" >&2; return 1; }
  printf '%s' "$dst"
}
# Each mutation is a (count, old, new) triple; NP is the self-probe removal appended to make the -np twin.
NP_O='census_selfprobe || exit 2'; NP_N=': census_selfprobe skipped'

# M0: the probe removed alone changes no cell, and its line vanishes.
if P="$(mut M0 1 "$NP_O" "$NP_N")"; then
  census "$P" "$WA" "s-quiet s-skip" 2
  if grep -qF 'self-probe: ok' <<<"$C_ERR"; then bad "M0: the self-probe line survived its own removal"; else ok "M0: no self-probe line once the call is removed"; fi
  eq "M0: s-quiet still EQUAL" "$(vd s-quiet)" "EQUAL -"
  eq "M0: s-skip still MISMATCH PLAIN-MORE" "$(vd s-skip)" "MISMATCH PLAIN-MORE"
else bad "M0: DID NOT APPLY"; fi

# probe-killed mutants: as-is the self-probe refuses naming its case; with the probe removed a world cell flips.
probe_killed() { # <id> <probe case> <fixture> <want verdict+direction> <count> <old> <new>
  local id="$1" pc="$2" f="$3" want="$4" P; shift 4
  if P="$(mut "$id" "$@")"; then
    census "$P" "$WA" "s-quiet" 1
    eq "$id: the census refuses (exit 2)" "$C_RC" 2
    has "$id: the self-probe names case $pc" "$C_ERR" "self-probe FAILED: case $pc"
  else bad "$id: DID NOT APPLY"; fi
  if P="$(mut "$id-np" "$@" 1 "$NP_O" "$NP_N")"; then
    census "$P" "$WA" "s-quiet $f" 2
    eq "$id (probe removed): s-quiet still EQUAL, so the mutant ran" "$(vd s-quiet)" "EQUAL -"
    eq "$id (probe removed): $f reads $want" "$(vd "$f")" "$want"
  else bad "$id-np: DID NOT APPLY"; fi
}
probe_killed M1 P2 s-skip "EQUAL -" \
  1 'elif [ "$2" = "$3" ] && [ "$po" -eq 0 ] && [ "$ho" -eq 0 ]; then' 'elif [ "$2" = "$3" ]; then'
probe_killed M2 P3 s-silent "LOW-RES -" \
  1 'elif [ "$pn" -eq 0 ]; then v=UNCOUNTABLE' 'elif false; then v=UNCOUNTABLE'
probe_killed M7 P4 s-absent "MISMATCH PLAIN-MORE" \
  1 'if [ "$1" = 2 ]; then v=REFUSED' 'if false; then v=REFUSED'
# M8 folds digits AFTER the path swaps, so the paths still normalise and s-quiet stays its control.
probe_killed M8 P5 s-digit "EQUAL -" \
  1 '      print s' '      gsub(/[0-9]+/, "N", s); print s'

# world-killed mutants: the self-probe passes, and a world cell names the reason.
world_killed() { # <id> <fixture> <want verdict+direction> <diff needle or -> <count> <old> <new>...
  local id="$1" f="$2" want="$3" needle="$4" P; shift 4
  if P="$(mut "$id" "$@")"; then
    census "$P" "$WA" "s-quiet s-skip" 2
    has "$id: the self-probe still passes" "$C_ERR" "$PROBE_OK"
    eq "$id: $f reads $want" "$(vd "$f")" "$want"
    [ "$needle" = - ] || has "$id: the diff names the line" "$(cell "$f" 13)" "$needle"
  else bad "$id: DID NOT APPLY"; fi
}
world_killed M3 s-skip "EQUAL -" - 1 'PLAIN_ROOT="$CENSUS_ROOT"' 'PLAIN_ROOT="$SB"'
world_killed M4 s-quiet "MISMATCH HERMETIC-MORE" "H: ok cwd-read data/a.txt" \
  1 '( cd "$PLAIN_ROOT" && exec' '( cd "$PLAIN_ROOT/$CENSUS_FXREL/$fx" && exec' \
  1 'bash "$CENSUS_FXREL/$fx/run.sh" )' 'bash run.sh )'
world_killed M5 s-quiet "MISMATCH HERMETIC-MORE" "H: ok farm-tool farm-ran" 1 'PATH="$CENSUS_TOOLDIRS:$B"' 'PATH="$CENSUS_TOOLDIRS"'
world_killed M6 s-quiet "MISMATCH HERMETIC-MORE" "H: ok stderr-line" 1 '"$T/p.raw" 2>&1' '"$T/p.raw" 2>/dev/null'

# --- BOTH-FAIL, the fixture-rc-2 split, and the token-level equivalence -----------------------------
probe_killed M9 P11 s-bothfail "EQUAL -" \
  1 'if [ "$2" = "$3" ] && [ "$3" != 0 ]; then v=BOTH-FAIL' 'if false; then v=BOTH-FAIL'
# M10 keys BOTH-FAIL on the hermetic rc alone, so a sandbox-only exit 2 is swallowed as a shared failure.
probe_killed M10 P12 s-rc2 "BOTH-FAIL -" \
  1 'if [ "$2" = "$3" ] && [ "$3" != 0 ]; then v=BOTH-FAIL' 'if [ "$2" != - ] && [ "$2" != 0 ]; then v=BOTH-FAIL'
# The token rule's two branches, as mutation anchors: NUM opens the count (range) branch, STB the
# non-numeric "stable on both sides" branch.
NUM_O='if ((a[i] c[i] g[i] b[i] e[i] h[i]) ~ /^[0-9]+$/) {'
STB_O='} else if (a[i] == c[i] && a[i] == g[i] && b[i] == e[i] && b[i] == h[i]) {'
# M11 the line-level rule: a differing line is acquitted when the line as a whole moves across reps.
probe_killed M11 E2 s-mixed "EQUIVALENT DIFFER" \
  1 "$NUM_O" 'if (0) {' \
  1 "$STB_O" '} else if (tk[1, k] == tk[3, k] && tk[1, k] == tk[5, k] && tk[2, k] == tk[4, k] && tk[2, k] == tk[6, k]) {'
# M12 no multiplicity guard: a repeated differing key pairs whichever of its lines sorts last.
probe_killed M12 E4 s-repeat "EQUIVALENT DIFFER" \
  1 'if (cnt[1, k] != 1 || cnt[2, k] != 1 || cnt[3, k] != 1 || cnt[4, k] != 1 || cnt[5, k] != 1 || cnt[6, k] != 1) {' 'if (0) {'
# M13 any masked match is acquitted: no token is ever required to move or to overlap.
probe_killed M13 E3 s-mixed "EQUIVALENT DIFFER" \
  1 "$NUM_O" 'if (0) {' 1 "$STB_O" '} else if (0) {'
# M21 the reverted reading: a count is judged like a sha, EQUIVALENT when it moves on at least one side.
# E3 and E2 still pass under it (their counts hold still on both sides), so FA1 is what names it.
probe_killed M21 FA1 s-flicker "EQUIVALENT DIFFER" \
  1 "$NUM_O" 'if (0) {'

# M14 the summary folds fixture-rc-2 back into REFUSED.
if P="$(mut M14 1 'if ($2 == "REFUSED" && $12 ~ /^fixture-rc-/) frc++' '')"; then
  census "$P" "$WA" "s-quiet s-rc2 s-absent" 2
  has "M14: the self-probe still passes" "$C_ERR" "$PROBE_OK"
  eq "M14: s-rc2 still reads REFUSED" "$(vd s-rc2)" "REFUSED -"
  has "M14: the summary no longer splits fixture-rc-2" "$C_ERR" "REFUSED=2 fixture-rc-2=0"
else bad "M14: DID NOT APPLY"; fi
census "$CENSUS" "$WA" "s-quiet s-rc2 s-absent" 2
has "split control: the unmutated summary splits fixture-rc-2 from a runner refusal" "$C_ERR" "REFUSED=1 fixture-rc-2=1"

# Exit test: EQUIVALENT passes the census, BOTH-FAIL fails it. Each control is one verdict apart from EQUAL.
census "$CENSUS" "$WA" "s-quiet s-volatile" 2
eq "exit: a census whose only non-EQUAL row is EQUIVALENT exits 0" "$C_RC/$(cell s-volatile 2)" "0/EQUIVALENT"
census "$CENSUS" "$WA" "s-quiet s-bothfail" 2
eq "exit: a census holding a BOTH-FAIL row exits 1" "$C_RC/$(cell s-bothfail 2)" "1/BOTH-FAIL"
if P="$(mut M15 1 '$2 != "LOW-RES" && $2 != "EQUIVALENT" { f = 1 }' '$2 != "LOW-RES" { f = 1 }')"; then
  census "$P" "$WA" "s-quiet s-volatile" 2
  eq "M15 (EQUIVALENT fails the exit test): the census exits 1" "$C_RC/$(cell s-volatile 2)" "1/EQUIVALENT"
else bad "M15: DID NOT APPLY"; fi
if P="$(mut M16 1 '$2 != "LOW-RES" && $2 != "EQUIVALENT" { f = 1 }' '$2 != "LOW-RES" && $2 != "EQUIVALENT" && $2 != "BOTH-FAIL" { f = 1 }')"; then
  census "$P" "$WA" "s-quiet s-bothfail" 2
  eq "M16 (BOTH-FAIL passes the exit test): the census exits 0" "$C_RC/$(cell s-bothfail 2)" "0/BOTH-FAIL"
else bad "M16: DID NOT APPLY"; fi

# --- the scratch root: links, cleanup, and the marker walk ------------------------------------------
# A non-keep run removes every physical chc.* root it made. s-volatile is re-paired, so it makes two.
C_KEEP=""; C_SCR="$SCR/nokeep"
census "$CENSUS" "$WA" "s-quiet s-volatile" 2
eq "cleanup: a non-keep run exits 0 and leaves no chc.* root under the scratch base" "$C_RC/$(chc_count "$SCR/nokeep")" "0/0"
n="$(chc_count "$SCR/keep")"
if [ "$n" -ge 12 ]; then ok "cleanup control: the --keep runs left their chc.* roots ($n)"; else bad "cleanup control: the --keep runs left $n chc.* roots, want at least 12, so a zero above proves nothing"; fi
if P="$(mut M17 1 'case "$ph" in "$CENSUS_SCRATCH"/chc.??????) rm -rf "$ph" ;; esac' ': physical root left')"; then
  census "$P" "$WA" "s-quiet s-volatile" 2
  n="$(chc_count "$SCR/nokeep")"
  if [ "$C_RC" = 0 ] && [ "$n" -ge 3 ]; then ok "M17 (only the pair link removed): the physical roots leak ($n)"; else bad "M17: rc=$C_RC with $n chc.* roots left, want rc 0 and at least 3"; fi
else bad "M17: DID NOT APPLY"; fi
C_KEEP=--keep

# M18: the pair dir built in the work tree, no physical root and no link.
C_SCR="$SCR/kc"
if P="$(mut M18 1 '    ln -s "$T" "$2" || return 2' '    mkdir -p "$2" || return 2')"; then
  census "$P" "$WA" "s-quiet" 1
  eq "M18: s-quiet still EQUAL, so the mutant ran" "$(vd s-quiet)" "EQUAL -"
  pl="$(find "$WORK/cw$C_N" -path '*/p.0001/1' | head -1)"
  if [ -n "$pl" ] && [ ! -L "$pl" ] && [ -d "$pl" ]; then ok "M18: the pair dir is a plain dir, not a link to a chc.* root"; else bad "M18: the pair dir '$pl' is still a link"; fi
else bad "M18: DID NOT APPLY"; fi

# Preflight: a marker above the scratch base refuses the census before any fixture runs.
mkdir -p "$SCR/pre/.claude" || exit 2
C_SCR="$SCR/pre/base"
census "$CENSUS" "$WA" "s-low" 1
eq "walk: a .claude above the scratch base refuses the census (exit 2)" "$C_RC" 2
has "walk: the refusal names the marker" "$C_ERR" "has a project marker above it ($SCR/pre/.claude)"
eq "walk: no fixture ran" "$(cell s-low 2)" ""
if P="$(mut M19 1 'if hit="$(census_marker_walk "$CENSUS_SCRATCH")"; then' 'if false; then')"; then
  census "$P" "$WA" "s-low" 1
  # Without the census's own walk the pair reaches hermetic-run.sh, whose escape guard refuses it: a row exists
  # (the unmutated census leaves none) and its note is the runner's refusal.
  eq "M19 (no preflight walk): s-low reaches the runner and reads REFUSED" "$(vd s-low)" "REFUSED -"
  has "M19: the runner's escape guard is what refused it" "$(cell s-low 12)" "sandbox escape"
else bad "M19: DID NOT APPLY"; fi

# End walk: s-marker writes a .claude above the scratch base during its own run; s-low beside it is the control.
C_SCR="$SCR/mark"
census "$CENSUS" "$WA" "s-low s-marker" 1
eq "walk: a marker appearing during the run fails the census (exit 2)" "$C_RC" 2
has "walk: the end-of-run walk names it" "$C_ERR" "a project marker appeared above the scratch base during the run ($SCR/mark/.claude)"
eq "walk: the rows still read (s-marker EQUAL)" "$(vd s-marker)" "EQUAL -"
mkdir -p "$SCR/mark2" || exit 2; C_SCR="$SCR/mark2"
if P="$(mut M20 1 'if end_hit="$(census_marker_walk "$CENSUS_SCRATCH")"; then' 'if false; then')"; then
  census "$P" "$WA" "s-low s-marker" 1
  if [ -e "$SCR/mark2/.claude" ] && [ "$C_RC" = 0 ]; then ok "M20 (no end walk): the marker appeared and the census exits 0"
  else bad "M20: rc=$C_RC, marker $( [ -e "$SCR/mark2/.claude" ] && echo present || echo absent), want rc 0 with the marker present"; fi
else bad "M20: DID NOT APPLY"; fi

# Probe leak: a self-probe failure after its chc.* root exists must remove that root. The failure is injected
# (FI: the resolve check made unmatchable, in a copy); M22 is FI with that exit path's cleanup dropped.
PRB_O='case "$PROBE_X" in "$CENSUS_SCRATCH"/chc.??????) ;;'
PRB_N='case "$PROBE_X" in "$CENSUS_SCRATCH"/never-a-pair) ;;'
C_KEEP=""
mkdir -p "$SCR/pl1" "$SCR/pl2" || exit 2
C_SCR="$SCR/pl1"
if P="$(mut FI 1 "$PRB_O" "$PRB_N")"; then
  census "$P" "$WA" "s-low" 1
  eq "probe leak: the injected resolve failure refuses the census" "$C_RC" 2
  has "probe leak: the refusal is the self-probe's resolve check" "$C_ERR" "self-probe FAILED: the pair link resolved to $SCR/pl1/chc."
  eq "probe leak: the failing self-probe left no chc.* root" "$(chc_count "$SCR/pl1")" 0
else bad "FI: DID NOT APPLY"; fi
C_SCR="$SCR/pl2"
if P="$(mut M22 1 "$PRB_O" "$PRB_N" 1 'not a chc.* root under $CENSUS_SCRATCH"; probe_px_rm; return 2 ;; esac' 'not a chc.* root under $CENSUS_SCRATCH"; return 2 ;; esac')"; then
  census "$P" "$WA" "s-low" 1
  has "M22 (the failure path keeps its root): the census still refuses on the resolve check" "$C_ERR" "self-probe FAILED: the pair link resolved to"
  eq "M22: the failing self-probe leaks its chc.* root" "$(chc_count "$SCR/pl2")" 1
else bad "M22: DID NOT APPLY"; fi

# Incomplete run: s-killed kills its own worker on the plain side, so no row is written and the worker's
# cleanup never runs. The summary must name the physical root it left, by path, and count it.
mkdir -p "$SCR/inc" || exit 2; C_SCR="$SCR/inc"
census "$CENSUS" "$WA" "s-killed" 1
has "incomplete: the run reports itself incomplete, naming s-killed" "$C_ERR" "the run is incomplete"
has "incomplete: no row for s-killed" "$C_ERR" "no row for: s-killed"
eq "incomplete: one chc.* root is left on disk" "$(chc_count "$SCR/inc")" 1
left="$(find "$SCR/inc" -mindepth 1 -maxdepth 1 -name 'chc.??????' | head -1)"
has "incomplete: the summary names that root by its path" "$C_ERR" "left scratch root: ${left:-<none on disk>}"
has "incomplete: the summary counts it" "$C_ERR" "1 physical scratch root(s) left under $SCR/inc"
C_KEEP=--keep

echo
if [ "$FAILS" -eq 0 ]; then echo "census-hermetic-coverage: PASS"; exit 0; fi
echo "census-hermetic-coverage: $FAILS assertion(s) FAILED"; exit 1
