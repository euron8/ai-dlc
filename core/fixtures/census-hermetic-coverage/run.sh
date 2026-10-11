#!/usr/bin/env bash
# census-hermetic-coverage -- bind scripts/census-hermetic-coverage.sh: it must score a seeded fixture whose
# skip branch hides an undeclared input as MISMATCH PLAIN-MORE, stay quiet (EQUAL) on a fixture that agrees
# across the two runs for every reason a careless census would split them, and each of eight wrong census
# implementations (M1-M8) must be killed by a presence-shaped assertion.
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
# WORLD B: s-dirty writes into the plain root -> REFUSED gitstate:status, and s-after behind it -> NOT-RUN.
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
trap 'rm -rf "$WORK"' EXIT

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
# census <script> <world> <list> <jobs>: sets C_RC, C_ERR (stderr text), C_TSV (the --out file)
census() {
  C_N=$((C_N + 1)); C_TSV="$WORK/c$C_N.tsv"; mkdir -p "$WORK/cw$C_N" "$WORK/home$C_N"
  C_ERR="$(cd "$2" && HOME="$WORK/home$C_N" bash "$1" --root "$2" --list "$3" --jobs "$4" --work "$WORK/cw$C_N" --keep --out "$C_TSV" 2>&1 >/dev/null)"; C_RC=$?
  [ -f "$C_TSV" ] || : > "$C_TSV"
}
cell() { awk -F'\t' -v f="$1" -v c="$2" '$1 == f { print $c; exit }' "$C_TSV"; } # <fixture> <column>
vd() { printf '%s %s' "$(cell "$1" 2)" "$(cell "$1" 3)"; }                   # verdict + direction
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if grep -qF -- "$3" <<<"$2"; then ok "$1"; else bad "$1 (absent: $3)"; fi; }

# --- control: the unmutated census over world A ---------------------------------------------------
rm -f "$WORK/flaky.count"
census "$CENSUS" "$WA" "s-quiet s-skip s-digit s-silent s-low s-absent s-flaky" 3
if ! grep -qF 'self-probe: ok (10 cases)' <<<"$C_ERR" || [ "$(cell s-quiet 2)" != EQUAL ]; then
  echo "FIXTURE BROKEN: the unmutated census did not run cleanly over world A (rc=$C_RC); no mutant verdict below would mean anything" >&2
  printf '%s\n' "$C_ERR" | head -20 >&2; cat "$C_TSV" >&2
  exit 2
fi
eq "c: unmutated census exits 1 on a world holding a mismatch" "$C_RC" 1
has "c: summary line counts every verdict" "$C_ERR" "fixtures=7 EQUAL=1 LOW-RES=1 MISMATCH=2 FLAKY=1 UNCOUNTABLE=1 REFUSED=1 NOT-RUN=0 plain-more=1 no-git-decl=1"
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

# --- store: the census never writes the default verdict store -------------------------------------
n="$(find "$WORK/home$C_N" -type f | wc -l | tr -d ' ')"
eq "store: the census wrote nothing under its HOME" "$n" 0
n="$(find "$WORK/cw$C_N" -path '*/vs/*' -type f | wc -l | tr -d ' ')"
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
    has "$id: the self-probe still passes" "$C_ERR" "self-probe: ok (10 cases)"
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

echo
if [ "$FAILS" -eq 0 ]; then echo "census-hermetic-coverage: PASS"; exit 0; fi
echo "census-hermetic-coverage: $FAILS assertion(s) FAILED"; exit 1
