#!/usr/bin/env bash
# hermetic-runner — drive the REAL hermetic-run.sh against a probe project and assert what the
# sandbox holds, what it refuses, and what its key rows say.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the runner regressed, 2 = fixture broken.
#
# THE SUBJECT is `hermetic-run.sh`: it runs one fixture inside a sandbox holding ONLY the inputs
# that fixture declared. A runner that leaks the project root into the sandbox makes every
# declaration decorative while every fixture it runs stays green, so each arm here is
# PRESENCE-shaped (a specific line must APPEAR) and each absence carries a positive control read
# from the same output.
#
#   A  declared file + directory reach the sandbox; the count line is exact; an undeclared
#      directory is NOT there (control: same stub, directory declared)
#   B  a `!` REQUIRED input the stub never names fails the run (control: stub names it -> 0)
#   C  an undeclared read fails closed (control: the same read declared -> 0)
#   D  an undeclared decoy is absent from the sandbox listing (control: declared name present,
#      and the decoy present once declared)
#   E  a declared path / directory / tool that cannot be honoured is exit 2 (control: a tool that
#      resolves runs from the sandbox)
#   F  the sandbox env is hermetic: AI_DLC_PROJECT_ROOT is the SANDBOX root and a variable the
#      caller exported does not reach the stub
#   G  --key-only rows in the hook grammar; the listing hash moves when an entry is added and
#      does not move when content changes (control: the file row moves)
#   H  --fixture-dir is honoured
#   I  the same runner honours a tests/fixtures/ (consumer) layout
#   P  a declared directory is copied by its git population: an ignored link and an ignored file
#      are absent and do not refuse, the tracked sibling is present, an empty-population declared
#      dir exists, an executable non-.sh file keeps its mode
#   Q  a tracked dir-link and a tracked dangling link are refused (control: a regular sub-directory)
#   R  an untracked-unignored file-link is refused
#   W  an untracked-unignored dir-link is refused
#   S  a gitlink under a declared directory is refused
#   T  the key did not move: with a deleted tracked file, runner rows equal the hook's
#   U  a non-git root is exit 2; --key-only on an unhashable tree is non-zero; a name git quotes
#      under a declared dir is exit 2 (near-miss: the same name outside every declared dir, exit 0)
#   V  version skew: a hook with no READSET_KEYROWS span still runs the fixture through the runner's
#      hr_parse_skew with the store OFF, maps a core/ declaration, honours `?name`; --key-only is exit 2
#      (control: the span-present twin records its pass)
#   X  git.decl: `seed` makes the sandbox a work tree with a HEAD; `pin` imports a commit whose blob
#      differs from the tree's (control: no git.decl -> no repository); a required pin the project
#      lacks is exit 2; `pin?` absent prints and continues; an abbreviated pin and an unknown line are exit 2
#   Y  a declaration carrying bare `core/` copies the fixture's own directory once, never a nested
#      `<fx>/<fx>/` (control: the own run.sh is listed; the count is exact)
#   M  mutants of the runner, each built on a COPY and guarded by `cmp -s`, each of which
#      must fail exactly its own arms. The declaration parse lives in the hook's READSET_KEYROWS
#      span, so M4/M5 mutate a copy of the hook the probes copy (run_hook_mutant), not the runner.
#   cwd  the verdict is the same from two different working directories
#
# The probe is a throwaway git repo under mktemp: the runner's --key-only reads `git ls-files`.
# This fixture carries no inputs.decl of its own.

# Sourced FIRST: a fixture invoked directly from a linked worktree inherits an absolute GIT_DIR,
# and every scratch `git init` below would then silently redirect onto the caller's repository.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
set -uo pipefail
for _v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

NESTED="${HERMETIC_FX_NESTED:-0}"
unset HERMETIC_FX_NESTED

# The repo root: walk up from this script for whichever runner layout is present. No hop count.
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN=""
d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  for cand in "$d/core/scripts/hermetic-run.sh" "$d/scripts/ai-dlc/hermetic-run.sh"; do
    [ -f "$cand" ] && { RUN="$cand"; break 2; }
  done
  d="$(dirname "$d")"
done
if [ -z "$RUN" ]; then
  echo "FIXTURE ERROR: hermetic-run.sh not found walking up from $HERE" >&2
  echo "  looked for: core/scripts/hermetic-run.sh (distribution), scripts/ai-dlc/hermetic-run.sh (consumer)" >&2
  exit 2
fi
ROOT="$d"
cd "$ROOT" || exit 2
echo "hermetic-runner: runner under test: $RUN"
RUN_ORIG="$RUN"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
# EVERY RUN OF THE PROBE FIXTURE THROUGH hermetic-run.sh WRITES A VERDICT ENTRY on a clean pass, so an inherited or
# default store collects one per runner sha per run. The base is pinned inside WORK for the whole fixture; the
# mutant runners and every probe run inherit it.
AI_DLC_VERDICT_STORE="$WORK/verdict-store"; export AI_DLC_VERDICT_STORE

T="$(printf '\t')"
VERBOSE=1
CUR="?"
FAILED=""
ok()  { [ "$VERBOSE" = 1 ] && printf '  ok    %s\n' "$1"; return 0; }
bad() { [ "$VERBOSE" = 1 ] && printf '  FAIL  %s\n' "$1"; FAILED="$FAILED $CUR"; return 0; }
eq()  { if [ "$2" = "$3" ]; then ok "$CUR: $1"; else bad "$CUR: $1 (got '$2', want '$3')"; fi; }
yes() { if grep -qF -- "$3" <<<"$2"; then ok "$CUR: $1"; else bad "$CUR: $1 (line absent: $3)"; fi; }
# no <desc> <haystack> <needle> <control needle>: the control must be PRESENT in the same haystack,
# or the absence proves nothing.
no() {
  if ! grep -qF -- "$4" <<<"$2"; then bad "$CUR: $1 (control '$4' absent, so the absence is unproven)"; return; fi
  if grep -qF -- "$3" <<<"$2"; then bad "$CUR: $1 ('$3' present)"; else ok "$CUR: $1"; fi
}
rowhas() { if grep -qxF -- "$3" <<<"$2"; then ok "$CUR: $1"; else bad "$CUR: $1 (row absent: $3)"; fi; }

# --- stubs: the fake fixture's run.sh bodies --------------------------------------------------
stub_read_all()  { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
echo "read data/a.txt"
echo "HERMETIC-CONSUMED data/a.txt"
for f in lib/*; do cat "$f" >/dev/null || exit 1; echo "read $f"; done
EOF
}
stub_named()     { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
echo "read data/a.txt"
echo "HERMETIC-CONSUMED data/a.txt"
EOF
}
stub_nosuch()    { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
echo "No such file: data/a.txt"
EOF
}
stub_bak()       { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
echo "HERMETIC-CONSUMED data/a.txt.bak"
EOF
}
stub_d_mention() { cat <<'EOF'
cat d/f.txt >/dev/null || exit 1
echo "looked at d and found nothing to say"
EOF
}
stub_d_consumed() { cat <<'EOF'
cat d/f.txt >/dev/null || exit 1
echo "HERMETIC-CONSUMED d/"
EOF
}
stub_mktemp()    { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
t="$(mktemp)" || exit 1
td="$(mktemp -d)" || exit 1
[ -f "$t" ] && [ -d "$td" ] && [ -d "$HOME" ] && echo "mktemp-ok home-ok"
case "$TMPDIR$HOME$td" in *//*) echo "DOUBLE-SLASH $TMPDIR $HOME $td" ;; *) echo "slashes-ok" ;; esac
EOF
}
stub_unnamed()   { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
echo "quiet"
EOF
}
stub_decoy()     { cat <<'EOF'
cat decoy/secret.txt >/dev/null || exit 1
echo "read decoy/secret.txt"
EOF
}
stub_ls()        { cat <<'EOF'
find . -type f | LC_ALL=C sort
EOF
}
stub_env()       { cat <<'EOF'
printf 'ROOTVAR=%s\n' "${AI_DLC_PROJECT_ROOT:-}"
printf 'PWDVAR=%s\n' "$(pwd -P)"
env
EOF
}
stub_tool()      { cat <<'EOF'
case "$(command -v jq 2>/dev/null)" in
  '') printf 'tool-out=%s\n' "$(awk 'BEGIN { print 1 }')" ;;
  *) printf 'tool-out=%s\n' "$(printf '{"a":1}\n' | jq -r .a)" ;;
esac
EOF
}

stub_k()         { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
b207tool
EOF
}
stub_knode()     { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
node -e 'console.log("node-ran-b207")'
EOF
}
stub_lcons()     { cat <<'EOF'
cat scripts/ai-dlc/x.sh >/dev/null || exit 1
echo "HERMETIC-CONSUMED scripts/ai-dlc/x.sh"
find . -type f | LC_ALL=C sort
EOF
}
stub_ldist()     { cat <<'EOF'
cat core/scripts/x.sh >/dev/null || exit 1
echo "HERMETIC-CONSUMED core/scripts/x.sh"
find . -type f | LC_ALL=C sort
EOF
}

FXR="core/fixtures"
# The hook the runner's --key-only sources its universe from, and the content-key declaration whose
# EXCLUDE span names the excluded tops. Taken from the repo under test, whichever layout it is.
HOOK_SRC=""; SCK_SRC=""
for cand in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  if [ -f "$cand" ] && grep -q '^# READSET_UNIVERSE_BEGIN$' "$cand"; then HOOK_SRC="$cand"; break; fi
done
for cand in "$ROOT/scripts/suite-content-key.sh"; do
  if [ -f "$cand" ] && grep -q '^# EXCLUDE_BEGIN$' "$cand"; then SCK_SRC="$cand"; fi
done
[ -n "$HOOK_SRC" ] && echo "hermetic-runner: universe hook: $HOOK_SRC" || echo "hermetic-runner: no hook with a READSET_UNIVERSE span here; arm G is skipped"
# mk_probe <dir> <stub function> <inputs.decl text> [tools.decl text]
mk_probe() {
  local p="$1" stub="$2" decl="$3" tools="${4:-}"
  mkdir -p "$p/data" "$p/lib" "$p/decoy" "$p/d" "$p/docs" "$p/$FXR/probe" || exit 2
  printf 'f\n' > "$p/d/f.txt"
  printf 'n\n' > "$p/docs/n.md"
  if [ "${PROBE_HOOK:-1}" = 1 ] && [ -n "$HOOK_SRC" ]; then
    mkdir -p "$p/.githooks" "$p/scripts" && cp "$HOOK_SRC" "$p/.githooks/pre-push" || exit 2
    [ -z "$SCK_SRC" ] || cp "$SCK_SRC" "$p/scripts/suite-content-key.sh" || exit 2
  fi
  printf 'alpha\n' > "$p/data/a.txt"
  printf 'x\n' > "$p/lib/x.txt"
  printf 'y\n' > "$p/lib/y.txt"
  printf 'secret\n' > "$p/decoy/secret.txt"
  { printf '#!/usr/bin/env bash\nset -u\n'; "$stub"; } > "$p/$FXR/probe/run.sh"
  printf '%s\n' "$decl" > "$p/$FXR/probe/inputs.decl"
  [ -z "$tools" ] || printf '%s\n' "$tools" > "$p/$FXR/probe/tools.decl"
  ( cd "$p" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm probe ) >/dev/null 2>&1 \
    || { echo "FIXTURE ERROR: could not build probe repo $p" >&2; exit 2; }
}
OUT=""; RC=0
# run_hr <probe> [runner options...]: sets OUT and RC.
run_hr() { local p="$1"; shift; OUT="$(bash "$RUN" --root "$p" "$@" probe 2>&1)"; RC=$?; }
nfiles() { find "$1" -type f | wc -l | tr -d ' '; }
# edit_hook <probe> <sed script>: rewrite the probe's COPIED hook (never the real one), no `sed -i`.
edit_hook() { sed "$2" "$1/.githooks/pre-push" > "$1/.githooks/pre-push.new" && mv "$1/.githooks/pre-push.new" "$1/.githooks/pre-push"; }
# hook_dump <probe> <hook file> <out dir>: run the hook's own readset_keys for fixture `probe` and leave
# its work files (.k/probe, .dunres, .dtools) in <out dir>. $FXR must be the hook's own fixture root.
hook_dump() {
  local blk="$3.blk"
  sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$2" > "$blk"
  ( cd "$1" && export AI_DLC_READSET_LIVE_TRACE=0 && . "$blk" && o="$3" && mkdir -p "$o" \
    && printf '%s\n' "$FXR/probe/" > "$o/list" && readset_manifest "$o" && readset_local_validate "$o/list" "$o" \
    && readset_keys "$o/list" "$o" ) >/dev/null 2>&1
}
hook_fxroot() { sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$HOOK_SRC" | head -1; }
# mutate_file <in> <out> <old> <new>: replace exactly one occurrence, require a real change.
mutate_file() {
  OLD="$3" NEW="$4" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print } END { if (n != 1) exit 3 }' "$1" > "$2" || return 1
  cmp -s "$1" "$2" && return 1
  return 0
}

# --- the arms ---------------------------------------------------------------------------------
arm_A() {
  CUR=A
  local P="$WK/A1" P2="$WK/A2" exp exp2
  mk_probe "$P" stub_read_all $'data/a.txt\nlib/'
  run_hr "$P"
  exp=$((1 + $(nfiles "$P/lib") + $(nfiles "$P/$FXR/probe")))
  eq "declared file+dir: exit 0" "$RC" 0
  yes "count line is exact ($exp files)" "$OUT" "rc=0 sandbox_files=$exp required_missing=0"
  yes "stub reached the declared file" "$OUT" "read data/a.txt"
  yes "stub reached the declared dir" "$OUT" "read lib/y.txt"
  mk_probe "$P2" stub_read_all 'data/a.txt'
  run_hr "$P2"
  exp2=$((1 + $(nfiles "$P2/$FXR/probe")))
  eq "dir undeclared: the stub fails" "$RC" 1
  yes "dir undeclared: count drops to $exp2" "$OUT" "rc=1 sandbox_files=$exp2 required_missing=0"
  # A declared FILE inside a declared DIRECTORY must not nest the directory copy (BSD cp copies INTO
  # an existing target): the sandbox holds lib/x.txt once and no lib/lib/.
  local P3="$WK/A3"
  mk_probe "$P3" stub_ls $'lib/x.txt\nlib/'
  run_hr "$P3"
  eq "file-inside-dir declaration: exit 0" "$RC" 0
  yes "file-inside-dir: lib/x.txt present once" "$OUT" "./lib/x.txt"
  no "file-inside-dir: no nested lib/lib/" "$OUT" "./lib/lib/" "./lib/y.txt"
  local exp3; exp3=$(( $(nfiles "$P3/lib") + $(nfiles "$P3/$FXR/probe") ))
  yes "file-inside-dir: count is exact ($exp3, lib copied once)" "$OUT" "sandbox_files=$exp3 "
}
arm_B() {
  CUR=B
  mk_probe "$WK/B1" stub_named '!data/a.txt'
  run_hr "$WK/B1"
  eq "REQUIRED named: exit 0" "$RC" 0
  yes "REQUIRED named: required_missing=0" "$OUT" "required_missing=0"
  mk_probe "$WK/B2" stub_unnamed '!data/a.txt'
  run_hr "$WK/B2"
  eq "REQUIRED not named: exit 1" "$RC" 1
  yes "REQUIRED not named: the line appears" "$OUT" "REQUIRED input data/a.txt was never consumed"
  yes "REQUIRED not named: stub itself passed" "$OUT" "rc=0 "
  mk_probe "$WK/B3" stub_unnamed 'data/a.txt'
  run_hr "$WK/B3"
  eq "same stub, input not REQUIRED: exit 0" "$RC" 0
  mk_probe "$WK/B4" stub_nosuch '!data/a.txt'
  run_hr "$WK/B4"
  eq "near-miss 'No such file: <path>' only: exit 1" "$RC" 1
  yes "near-miss 'No such file': the REQUIRED line appears" "$OUT" "REQUIRED input data/a.txt was never consumed"
  mk_probe "$WK/B5" stub_bak '!data/a.txt'
  run_hr "$WK/B5"
  eq "near-miss sentinel for <path>.bak: exit 1" "$RC" 1
  yes "near-miss .bak: the REQUIRED line appears" "$OUT" "REQUIRED input data/a.txt was never consumed"
  mk_probe "$WK/B6" stub_d_mention '!d/'
  run_hr "$WK/B6"
  eq "one-letter dir mentioned without a sentinel: exit 1" "$RC" 1
  yes "one-letter dir: the REQUIRED line appears" "$OUT" "REQUIRED input d/ was never consumed"
  mk_probe "$WK/B7" stub_d_consumed '!d/'
  run_hr "$WK/B7"
  eq "one-letter dir with its sentinel: exit 0" "$RC" 0
}
arm_C() {
  CUR=C
  mk_probe "$WK/C1" stub_decoy 'data/a.txt'
  run_hr "$WK/C1"
  eq "undeclared read: exit 1" "$RC" 1
  yes "undeclared read: the cat errored" "$OUT" "No such file"
  mk_probe "$WK/C2" stub_decoy $'data/a.txt\ndecoy/secret.txt'
  run_hr "$WK/C2"
  eq "same read declared: exit 0" "$RC" 0
  yes "same read declared: stub read it" "$OUT" "read decoy/secret.txt"
}
arm_D() {
  CUR=D
  mk_probe "$WK/D1" stub_ls 'data/a.txt'
  run_hr "$WK/D1"
  yes "declared file listed" "$OUT" "./data/a.txt"
  no "decoy file absent from the sandbox" "$OUT" "secret.txt" "./data/a.txt"
  no "undeclared sibling dir absent" "$OUT" "lib/y.txt" "./data/a.txt"
  mk_probe "$WK/D2" stub_ls $'data/a.txt\ndecoy/secret.txt'
  run_hr "$WK/D2"
  yes "decoy present once declared" "$OUT" "./decoy/secret.txt"
}
arm_E() {
  CUR=E
  local tool="awk" dd
  for dd in /opt/homebrew/bin /usr/local/bin /usr/bin /bin; do
    [ -x "$dd/jq" ] && { tool="jq"; break; }
  done
  mk_probe "$WK/E1" stub_named 'data/nope.txt'
  run_hr "$WK/E1"
  eq "declared file absent: exit 2" "$RC" 2
  yes "declared file absent: message" "$OUT" "declared file absent: data/nope.txt"
  mk_probe "$WK/E2" stub_named 'nodir/'
  run_hr "$WK/E2"
  eq "declared dir absent: exit 2" "$RC" 2
  yes "declared dir absent: message" "$OUT" "declared directory absent: nodir/"
  mk_probe "$WK/E5" stub_named ''
  run_hr "$WK/E5"
  eq "empty inputs.decl: exit 2" "$RC" 2
  yes "empty inputs.decl: message" "$OUT" "inputs.decl is empty"
  mk_probe "$WK/E6" stub_named '# nothing but a comment'
  run_hr "$WK/E6"
  eq "comment-only inputs.decl: exit 2" "$RC" 2
  yes "comment-only inputs.decl: message" "$OUT" "inputs.decl is empty"
  mk_probe "$WK/E3" stub_tool 'data/a.txt' 'no-such-tool-b205'
  run_hr "$WK/E3"
  eq "declared tool absent: exit 2" "$RC" 2
  yes "declared tool absent: message" "$OUT" "declared tool no-such-tool-b205 resolves in none"
  # A symlink under a declared directory reaches outside the declaration: refused with exit 2
  # naming the link. Control in the same arm: the identical probe with the link removed exits 0.
  mk_probe "$WK/E5" stub_read_all $'data/a.txt\nlib/'
  ( cd "$WK/E5" && ln -s /etc/hosts lib/lnk && git add -A && git -c user.name=t -c user.email=t@t commit -qm lnk ) >/dev/null 2>&1
  run_hr "$WK/E5"
  eq "symlink under declared dir: exit 2" "$RC" 2
  yes "symlink under declared dir: message names the link" "$OUT" "lib/lnk is a symlink"
  ( cd "$WK/E5" && rm lib/lnk && git add -A && git -c user.name=t -c user.email=t@t commit -qm unlnk ) >/dev/null 2>&1
  run_hr "$WK/E5"
  eq "control: same probe without the link: exit 0" "$RC" 0
  mk_probe "$WK/E4" stub_tool 'data/a.txt' "$tool"
  run_hr "$WK/E4"
  eq "declared tool ($tool) present: exit 0" "$RC" 0
  yes "declared tool ($tool) ran in the sandbox" "$OUT" "tool-out=1"
}
arm_F() {
  CUR=F
  local P="$WK/F1" rv pv
  mk_probe "$P" stub_env 'data/a.txt'
  ( export HERMETIC_PROBE_LEAK=1; bash "$RUN" --root "$P" probe > "$WK/F1.out" 2>&1 )
  OUT="$(cat "$WK/F1.out")"
  rv="$(sed -n 's/^ROOTVAR=//p' <<<"$OUT" | head -1)"
  pv="$(sed -n 's/^PWDVAR=//p' <<<"$OUT" | head -1)"
  [ -n "$rv" ] && ok "$CUR: stub reports a root" || bad "$CUR: stub reported no AI_DLC_PROJECT_ROOT"
  eq "root equals pwd -P inside the sandbox, exactly" "$rv" "$pv"
  [ "$rv" != "$P" ] && ok "$CUR: root is not the probe root" || bad "$CUR: root equals the probe root"
  yes "env dump carries the runner's own variable (control)" "$OUT" "AI_DLC_PROJECT_ROOT="
  no "caller-exported variable does not leak" "$OUT" "HERMETIC_PROBE_LEAK" "AI_DLC_PROJECT_ROOT="
  # The leak is real at the caller: without this the absence above could mean it was never exported.
  local n
  n="$( ( export HERMETIC_PROBE_LEAK=1; env ) | grep -c '^HERMETIC_PROBE_LEAK=')" || n=0
  eq "variable was exported at the caller" "$n" 1
  mk_probe "$WK/F2" stub_mktemp 'data/a.txt'
  run_hr "$WK/F2"
  eq "stub calling mktemp and using HOME: exit 0" "$RC" 0
  yes "mktemp and HOME worked in the sandbox" "$OUT" "mktemp-ok home-ok"
  # THE INVOKER'S TMPDIR CARRIES A TRAILING SLASH ON macOS, and the runner builds HOME and TMPDIR for
  # the sandbox under a mktemp taken in it: without a squeeze the sandboxed fixture mints every scratch
  # path with an EMBEDDED `//` that a plain run never sees. Forced here, so the arm fires on every box.
  ( export TMPDIR="${TMPDIR:-/tmp}/"; bash "$RUN" --root "$WK/F2" probe > "$WK/F3.out" 2>&1 ); RC=$?
  OUT="$(cat "$WK/F3.out")"
  eq "trailing-slash TMPDIR at the invoker: exit 0" "$RC" 0
  yes "sandbox TMPDIR, HOME and a minted path carry no //" "$OUT" "slashes-ok"
  no "no DOUBLE-SLASH report" "$OUT" "DOUBLE-SLASH" "slashes-ok"
}
arm_G() {
  CUR=G
  local P="$WK/G1" fsha lsha lsha2 lsha3 fsha2 rows rsha
  mk_probe "$P" stub_read_all $'data/a.txt\nlib/'
  fsha="$(shasum -a 256 "$P/data/a.txt" | awk '{ print $1 }')"
  lsha="$(printf 'x.txt\ny.txt\n' | shasum -a 256 | awk '{ print $1 }')"
  rsha="$(shasum -a 256 "$P/$FXR/probe/run.sh" | awk '{ print $1 }')"
  rows="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  rowhas "declared file row" "$rows" "data/a.txt${T}${fsha}"
  rowhas "declared dir listing row" "$rows" "lib/${T}#listing:${lsha}"
  rowhas "fixture's own run.sh row" "$rows" "$FXR/probe/run.sh${T}${rsha}"
  yes "declared dir member row" "$rows" "lib/x.txt${T}"
  no "no row for the decoy" "$rows" "decoy" "data/a.txt"
  printf 'z\n' > "$P/lib/z.txt"
  ( cd "$P" && git add -A && git -c user.name=t -c user.email=t@t commit -qm add-z ) >/dev/null 2>&1
  lsha2="$(printf 'x.txt\ny.txt\nz.txt\n' | shasum -a 256 | awk '{ print $1 }')"
  rows="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  rowhas "listing row moves when an entry is added" "$rows" "lib/${T}#listing:${lsha2}"
  [ "$lsha" != "$lsha2" ] && ok "$CUR: the two listings differ (the comparison can resolve)" || bad "$CUR: listings identical"
  no "old listing row gone" "$rows" "#listing:${lsha}" "#listing:${lsha2}"
  printf 'changed\n' >> "$P/lib/x.txt"
  ( cd "$P" && git add -A && git -c user.name=t -c user.email=t@t commit -qm edit-x ) >/dev/null 2>&1
  fsha2="$(shasum -a 256 "$P/lib/x.txt" | awk '{ print $1 }')"
  rows="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  rowhas "listing row stable under a content change" "$rows" "lib/${T}#listing:${lsha2}"
  rowhas "control: the changed file's own row moved" "$rows" "lib/x.txt${T}${fsha2}"
  lsha3="$(sed -n "s/^lib\/${T}#listing://p" <<<"$rows")"
  eq "listing unchanged across the content edit" "$lsha3" "$lsha2"
  # file rows are the shas of the files themselves
  rowhas "file row sha equals shasum -a 256 of the file (a.txt)" "$rows" "data/a.txt${T}$(shasum -a 256 "$P/data/a.txt" | awk '{ print $1 }')"
  # a git-ignored file under a declared dir yields no row
  printf 'lib/ign.txt\n' > "$P/.gitignore"
  printf 'ignored\n' > "$P/lib/ign.txt"
  rows="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  no "git-ignored file under a declared dir has no row" "$rows" "lib/ign.txt" "lib/x.txt${T}"
  # a declared dir under an excluded top (docs) yields no rows, with the control that the
  # exclusion declaration is what did it
  if [ -n "$SCK_SRC" ]; then
    mk_probe "$WK/G2" stub_named $'data/a.txt\ndocs/'
    rows="$(bash "$RUN" --root "$WK/G2" --key-only probe 2>/dev/null)"
    no "declared dir under an excluded top (docs/) yields no rows" "$rows" "docs/" "data/a.txt${T}"
    PROBE_HOOK=1 SCK_SRC_SAVE="$SCK_SRC"; SCK_SRC=""
    mk_probe "$WK/G3" stub_named $'data/a.txt\ndocs/'
    SCK_SRC="$SCK_SRC_SAVE"
    rows="$(bash "$RUN" --root "$WK/G3" --key-only probe 2>/dev/null)"
    yes "control: with no content-key declaration docs/ IS keyed" "$rows" "docs/n.md${T}"
  else
    # A consumer has no scripts/suite-content-key.sh (install.sh does not ship it; the hook's
    # exclusion set is EMPTY there by design), so the exclusion arm has no subject on a consumer.
    # It SKIPs visibly rather than failing, and the skip line is itself asserted present so a
    # silent fall-through cannot read as a pass.
    echo "  SKIP  $CUR: exclusion arm -- no scripts/suite-content-key.sh with an EXCLUDE span here (consumer layout); the hook's exclusion set is empty on this tree"
  fi
  # no hook -> exit 2
  PROBE_HOOK=0 mk_probe "$WK/G4" stub_named 'data/a.txt'
  run_hr "$WK/G4" --key-only
  eq "no pre-push hook in the probe: --key-only exit 2" "$RC" 2
  yes "no hook: message" "$OUT" "needs a pre-push hook"
}
arm_H() {
  CUR=H
  local P="$WK/H1" ovr="$WK/H1ovr"
  mk_probe "$P" stub_named 'data/a.txt'
  run_hr "$P"
  no "original run.sh lacks the marker" "$OUT" "OVERRIDE-MARKER-b205" "read data/a.txt"
  mkdir -p "$ovr" && cp -R "$P/$FXR/probe" "$ovr/probe" || exit 2
  printf 'echo OVERRIDE-MARKER-b205\n' >> "$ovr/probe/run.sh"
  run_hr "$P" --fixture-dir "$ovr/probe"
  eq "override: exit 0" "$RC" 0
  yes "override: the copied run.sh ran" "$OUT" "OVERRIDE-MARKER-b205"
}
arm_I() {
  CUR=I
  local save="$FXR"
  FXR="tests/fixtures"
  mk_probe "$WK/I1" stub_read_all $'data/a.txt\nlib/'
  run_hr "$WK/I1"
  FXR="$save"
  eq "consumer layout: exit 0" "$RC" 0
  yes "consumer layout: stub ran from the sandbox root" "$OUT" "read lib/x.txt"
}
arm_J() {
  CUR=J
  local P="$WK/J1" blk="$WK/J.blk" hk hr hk2 hr2 hk3 hr3 n lsha lsha2 lsha3 FXR_SAVE="$FXR"
  # THE PROBE FIXTURE LIVES UNDER THE HOOK'S OWN FIXTURE ROOT, read out of the copied hook, not under
  # this fixture's current layout: on a consumer the hook says tests/fixtures/ while the main pass
  # here builds probes under core/fixtures/, and a hook keying a fixture dir the probe does not
  # hold reports no listing, no tool row and no agreement -- measured on an install.sh-built tree.
  FXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$HOOK_SRC" | head -1)"
  [ -n "$FXR" ] || { bad "$CUR: cannot read FXROOT from $HOOK_SRC"; FXR="$FXR_SAVE"; return; }
  mk_probe "$P" stub_named $'data/a.txt\nlib/\n!data/a.txt' 'awk'
  mkdir -p "$P/lib/sub" && printf 's\n' > "$P/lib/sub/s.txt"
  ( cd "$P" && git add -A && git -c user.name=t -c user.email=t@t commit -qm sub ) >/dev/null 2>&1
  sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$P/.githooks/pre-push" > "$blk"
  [ -s "$blk" ] && ok "$CUR: pool block extracted" || bad "$CUR: pool block empty"
  hook_rows() { # <probe>: the hook's row set for the probe fixture, the three # header lines dropped
    ( cd "$1" && export AI_DLC_READSET_LIVE_TRACE=0 && . "$blk" && o="$(mktemp -d)" \
      && printf '%s\n' "$FXR/probe/" > "$o/list" && readset_manifest "$o" && readset_local_validate "$o/list" "$o" \
      && readset_keys "$o/list" "$o" && grep -v '^#' "$o/.k/probe" ) 2>/dev/null
  }
  hk="$(hook_rows "$P")"; hr="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  n="$(grep -c . <<<"$hk")" || n=0
  [ -n "$hk" ] && ok "$CUR: hook row set is non-empty" || bad "$CUR: hook row set empty"
  [ "$n" -ge 6 ] && ok "$CUR: hook row count >= 6 ($n)" || bad "$CUR: hook row count $n < 6"
  if [ "$hk" = "$hr" ]; then ok "$CUR: hook and runner rows agree byte-for-byte"; else bad "$CUR: hook and runner rows differ"; diff <(printf '%s\n' "$hk") <(printf '%s\n' "$hr") | head -20; fi
  rowhas "hook has the declared file row" "$hk" "data/a.txt${T}$(shasum -a 256 "$P/data/a.txt" | awk '{ print $1 }')"
  yes "hook has the dir listing row" "$hk" "lib/${T}#listing:"
  yes "hook has the nested file row" "$hk" "lib/sub/s.txt${T}"
  yes "hook has a tool row" "$hk" "awk"
  lsha="$(sed -n "s/^lib\/${T}#listing://p" <<<"$hk")"
  printf 'z\n' > "$P/lib/z.txt"
  ( cd "$P" && git add -A && git -c user.name=t -c user.email=t@t commit -qm add-z ) >/dev/null 2>&1
  hk2="$(hook_rows "$P")"; hr2="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  lsha2="$(sed -n "s/^lib\/${T}#listing://p" <<<"$hk2")"; lsha3="$(sed -n "s/^lib\/${T}#listing://p" <<<"$hr2")"
  [ -n "$lsha2" ] && [ "$lsha" != "$lsha2" ] && ok "$CUR: hook listing moved on add" || bad "$CUR: hook listing did not move"
  [ "$lsha2" = "$lsha3" ] && ok "$CUR: runner listing moved identically" || bad "$CUR: listings differ hook=$lsha2 runner=$lsha3"
  if [ "$hk2" = "$hr2" ]; then ok "$CUR: rows still agree after the add"; else bad "$CUR: rows differ after the add"; diff <(printf '%s\n' "$hk2") <(printf '%s\n' "$hr2") | head -20; fi
  ( cd "$P" && git rm -q "$FXR/probe/tools.decl" && git -c user.name=t -c user.email=t@t commit -qm no-tools ) >/dev/null 2>&1
  hk3="$(hook_rows "$P")"; hr3="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  if [ "$hk3" = "$hr3" ]; then ok "$CUR: rows agree with no tools.decl"; else bad "$CUR: rows differ with no tools.decl"; diff <(printf '%s\n' "$hk3") <(printf '%s\n' "$hr3") | head -20; fi
  yes "control: before the drop both sides carried the tool row" "$hr2" "awk"
  no "tool row gone on the hook side" "$hk3" "awk" "data/a.txt"
  no "tool row gone on the runner side" "$hr3" "awk" "data/a.txt"
  echo "  J rows: with-tools=$(grep -c . <<<"$hk2") without-tools=$(grep -c . <<<"$hk3") fxroot=$FXR"
  # --- J, new grammars. Each probe is judged by the hook and by the runner on the SAME tree.
  local mapper PJ PQ PM PA hm hq rq hj hn
  mapper="$(dirname "$RUN_ORIG")/core-paths.sh"
  # (1) `?b207tool`: both sides carry the same rows as the probe without the line (control: a bare awk
  # line adds a row on BOTH sides), and the hook's decision is not `tool unresolved`. A hook copy that
  # treats `?` as a keyed name disagrees: it leaves the fixture unresolved.
  mkdir -p "$WK/J.sb" && printf '#!/bin/sh\necho b207tool-ran\n' > "$WK/J.sb/b207tool" && chmod +x "$WK/J.sb/b207tool"
  PQ="$WK/J2"; mk_probe "$PQ" stub_named 'data/a.txt' '?b207tool'
  edit_hook "$PQ" 's/^READSET_UNKEYED_TOOLS="/&b207tool /'
  hook_dump "$PQ" "$PQ/.githooks/pre-push" "$WK/J2.o"
  rq="$(PATH="$WK/J.sb:$PATH" bash "$RUN" --root "$PQ" --key-only probe 2>/dev/null)"
  hj="$(grep -v '^#' "$WK/J2.o/.k/probe" 2>/dev/null)"
  if [ "$hj" = "$rq" ] && [ -n "$hj" ]; then ok "$CUR: ?b207tool: hook and runner rows agree"; else bad "$CUR: ?b207tool: hook and runner rows differ"; fi
  no "?b207tool: the hook's decision is not 'tool unresolved'" "$(cat "$WK/J2.o/.kdec" 2>/dev/null)" "tool unresolved" "probe"
  # hook copy with `?` ignored (treated as a keyed name): it must DISAGREE with the runner.
  mutate_file "$PQ/.githooks/pre-push" "$PQ/.githooks/pre-push.mut" "'?'*)" "'NEVER?'*)" && \
    hook_dump "$PQ" "$PQ/.githooks/pre-push.mut" "$WK/J2m.o"
  hn="$(cat "$WK/J2m.o/.dunres" 2>/dev/null)"
  yes "mutant hook (? ignored) is caught: it puts ?b207tool in .dunres" "$hn" "?b207tool"
  no "control: the unmutated hook has no .dunres row for it" "$(cat "$WK/J2.o/.dunres" 2>/dev/null)x" "?b207tool" "x"
  # (2) a consumer-layout probe: declaration in distribution coordinates, mapped on both sides.
  PM="$WK/J3"; mk_probe "$PM" stub_named $'core/scripts/x.sh\ndata/a.txt'
  mkdir -p "$PM/scripts/ai-dlc" && printf 'x\n' > "$PM/scripts/ai-dlc/x.sh" && cp "$mapper" "$PM/scripts/ai-dlc/core-paths.sh"
  ( cd "$PM" && git add -A && git -c user.name=t -c user.email=t@t commit -qm cons ) >/dev/null 2>&1
  hook_dump "$PM" "$PM/.githooks/pre-push" "$WK/J3.o"
  hm="$(grep -v '^#' "$WK/J3.o/.k/probe" 2>/dev/null)"
  rq="$(bash "$RUN" --root "$PM" --key-only probe 2>/dev/null)"
  yes "consumer layout: the runner keys the mapped path" "$rq" "scripts/ai-dlc/x.sh${T}"
  if [ "$hm" = "$rq" ] && [ -n "$hm" ]; then ok "$CUR: consumer layout: hook and runner rows agree on the mapped path"; else bad "$CUR: consumer layout: hook and runner rows differ"; diff <(printf '%s\n' "$hm") <(printf '%s\n' "$rq") | head -10; fi
  # hook copy with the IDENTITY map: it keys core/scripts/x.sh (absent) and so DISAGREES with the runner.
  mutate_file "$PM/.githooks/pre-push" "$PM/.githooks/pre-push.mut" '| bash "$mp" --map >' '| cat >' && \
    hook_dump "$PM" "$PM/.githooks/pre-push.mut" "$WK/J3m.o"
  hn="$(grep -v '^#' "$WK/J3m.o/.k/probe" 2>/dev/null)"
  if [ -n "$hn" ] && [ "$hn" != "$rq" ]; then ok "$CUR: mutant hook (identity map) disagrees with the runner"; else bad "$CUR: mutant hook (identity map) was not caught"; fi
  # (3) a declared mapped file ABSENT in both: runner exit 2 (declared file absent), hook no row and no error.
  PA="$WK/J4"; mk_probe "$PA" stub_named $'core/scripts/gone.sh\ndata/a.txt'
  mkdir -p "$PA/scripts/ai-dlc" && cp "$mapper" "$PA/scripts/ai-dlc/core-paths.sh"
  ( cd "$PA" && git add -A && git -c user.name=t -c user.email=t@t commit -qm cons ) >/dev/null 2>&1
  hook_dump "$PA" "$PA/.githooks/pre-push" "$WK/J4.o"
  hn="$(grep -v '^#' "$WK/J4.o/.k/probe" 2>/dev/null)"
  run_hr "$PA"
  eq "mapped file absent: runner exit 2" "$RC" 2
  no "mapped file absent: the hook writes no row for it" "$hn" "gone.sh" "data/a.txt${T}"
  yes "mapped file absent: the hook's .dunres says why" "$(cat "$WK/J4.o/.dunres" 2>/dev/null)" "declared file absent scripts/ai-dlc/gone.sh"
  no "control: the present sibling is not reported absent" "$(cat "$WK/J4.o/.dunres" 2>/dev/null)" "absent data/a.txt" "gone.sh"
  yes "mapped file absent: the hook decision is run (a fresh probe's reason is 'unrecorded'; the .dunres row above carries the cause)" "$(cat "$WK/J4.o/.kdec" 2>/dev/null)" "probe${T}run${T}"
  no "control: the present sibling gets no .dunres row" "$(cat "$WK/J4.o/.dunres" 2>/dev/null)" "data/a.txt" "gone.sh"
  # (3b) near-miss: a declared file that is ON DISK but outside the universe (docs/ is an excluded top
  # where the content-key declaration exists). No .dunres row, runner exit 0. The offender above is the
  # same probe shape with the file missing on disk.
  local PE="$WK/J6"
  mk_probe "$PE" stub_named $'data/a.txt\ndocs/n.md'
  hook_dump "$PE" "$PE/.githooks/pre-push" "$WK/J6.o"
  run_hr "$PE"
  eq "near-miss, declared docs/n.md present on disk: runner exit 0" "$RC" 0
  eq "near-miss: the hook writes no .dunres row" "$(grep -c . "$WK/J6.o/.dunres")" 0
  if [ -n "$SCK_SRC" ]; then
    no "near-miss: docs/n.md is outside the universe, so it has no key row" "$(grep -v '^#' "$WK/J6.o/.k/probe" 2>/dev/null)" "docs/n.md" "data/a.txt${T}"
  fi
  # (4) `..` shapes: refused by the runner before it maps, and by the hook before its mapper pre-pass.
  local dd dn
  for dd in '../x' 'core/scripts/../x' '/abs/x'; do
    dn="J5$(printf '%s' "$dd" | cksum | cut -d' ' -f1)"
    mk_probe "$WK/$dn" stub_named $'data/a.txt\n'"$dd"
    mkdir -p "$WK/$dn/scripts/ai-dlc" && cp "$mapper" "$WK/$dn/scripts/ai-dlc/core-paths.sh"
    ( cd "$WK/$dn" && git add -A && git -c user.name=t -c user.email=t@t commit -qm cons ) >/dev/null 2>&1
    hook_dump "$WK/$dn" "$WK/$dn/.githooks/pre-push" "$WK/$dn.o"
    yes "'$dd': the hook writes a .dunres row" "$(cat "$WK/$dn.o/.dunres" 2>/dev/null)" "absolute or contains .."
    run_hr "$WK/$dn"
    eq "'$dd': runner exit 2" "$RC" 2
  done
  no "control: a clean declaration writes no such row" "$(cat "$WK/J4.o/.dunres" 2>/dev/null)x" "absolute or contains .." "x"
  FXR="$FXR_SAVE"
}
# --- K: an UNKEYED-REACHABLE tool (`?name`) ------------------------------------------------------
# A synthetic tool `b207tool`, an executable stub in a mktemp dir that the arm prepends to PATH when it
# invokes the runner, and which the PROBE's copied hook lists in READSET_UNKEYED_TOOLS (never the real hook).
arm_K() {
  CUR=K
  local FXR_SAVE="$FXR" sb="$WK/K.bin" P0="$WK/K0" P1="$WK/K1" PB="$WK/K2" r0 r1 rb f hk n
  FXR="$(hook_fxroot)"
  [ -n "$FXR" ] || { bad "$CUR: cannot read FXROOT from $HOOK_SRC"; FXR="$FXR_SAVE"; return; }
  mkdir -p "$sb" && printf '#!/bin/sh\necho b207tool-ran\n' > "$sb/b207tool" && chmod +x "$sb/b207tool" || exit 2
  mk_probe "$P0" stub_k 'data/a.txt'
  mk_probe "$P1" stub_k 'data/a.txt' '?b207tool'
  edit_hook "$P1" 's/^READSET_UNKEYED_TOOLS="/&b207tool /'
  mk_probe "$PB" stub_k 'data/a.txt' 'awk'
  OUT="$(PATH="$sb:$PATH" bash "$RUN" --root "$P1" probe 2>&1)"; RC=$?
  eq "?b207tool with the tool on PATH: exit 0" "$RC" 0
  yes "?b207tool: the stub ran from the sandbox" "$OUT" "b207tool-ran"
  r0="$(bash "$RUN" --root "$P0" --key-only probe 2>/dev/null)"
  r1="$(PATH="$sb:$PATH" bash "$RUN" --root "$P1" --key-only probe 2>/dev/null)"
  rb="$(bash "$RUN" --root "$PB" --key-only probe 2>/dev/null)"
  [ -n "$r0" ] && ok "$CUR: baseline key rows are non-empty" || bad "$CUR: baseline key rows empty"
  # The key rows carry no b207tool row and match the probe WITHOUT the line byte for byte. The hook copy
  # and the fixture's own files differ between P0 and P1 only by the tools.decl file, so compare row
  # sets after dropping the tools.decl row, and assert the control: a bare tool line adds a row.
  eq "?b207tool: --key-only equals the same probe without the line" "$(grep -v '/tools\.decl' <<<"$r1" | grep -v '\.githooks/' )" "$(grep -v '/tools\.decl' <<<"$r0" | grep -v '\.githooks/')"
  no "?b207tool: no key row names the tool" "$r1" "b207tool" "data/a.txt${T}"
  yes "control: a bare awk line adds a /awk row" "$rb" "/awk${T}"
  no "control: the baseline has no /awk row" "$r0" "/awk${T}" "data/a.txt${T}"
  OUT="$(bash "$RUN" --root "$P1" probe 2>&1)"; RC=$?
  if grep -qxF b207tool-ran <<<"$OUT"; then bad "$CUR: the stub ran with no PATH prepend (control broken)"; fi
  eq "?b207tool without the PATH prepend: exit 2" "$RC" 2
  yes "?b207tool without the PATH prepend: the unkeyed message" "$OUT" "declared tool name (unkeyed) is not on PATH"
  # Refused forms. The runner exits 2; the probe hook writes a .dunres row for each.
  for f in '?awk' '?' '?/x' '?a/b' '?a b'; do
    n="K$(printf '%s' "$f" | cksum | cut -d' ' -f1)"
    mk_probe "$WK/$n" stub_k 'data/a.txt' "$f"
    run_hr "$WK/$n"
    eq "refused '$f': runner exit 2" "$RC" 2
    hook_dump "$WK/$n" "$WK/$n/.githooks/pre-push" "$WK/$n.o"
    hk="$(cat "$WK/$n.o/.dunres" 2>/dev/null)"
    [ -n "$hk" ] && ok "$CUR: refused '$f': the hook wrote a .dunres row" || bad "$CUR: refused '$f': hook .dunres empty"
  done
  # Hook side: `?b207tool` in the vocabulary writes no .dtools, .tools or .dunres row (control: bare awk does).
  hook_dump "$P1" "$P1/.githooks/pre-push" "$WK/K1.o"
  hook_dump "$PB" "$PB/.githooks/pre-push" "$WK/K2.o"
  eq "hook: ?b207tool writes no .dunres row" "$(grep -c . "$WK/K1.o/.dunres")" 0
  eq "hook: ?b207tool writes no .dtools row" "$(grep -c . "$WK/K1.o/.dtools")" 0
  no "hook: ?b207tool adds no .tools row" "$(cat "$WK/K1.o/.tools" 2>/dev/null)" "b207tool" "/"
  yes "control, hook: a bare awk line writes a .dtools row" "$(cat "$WK/K2.o/.dtools" 2>/dev/null)" "/awk"
  # Duplicate lines: the same resolved path twice is ONE tool (exit 0, rows unchanged; control: one line).
  # Two DIFFERENT paths sharing a basename (bare b207tool from a probe exec-path dir, plus ?b207tool from
  # PATH) are refused by the runner and recorded in the hook's .dunres.
  local PD1="$WK/K4" PD2="$WK/K5" PD3="$WK/K6" PD4="$WK/K7" xd="$WK/K.xp"
  mk_probe "$PD1" stub_named 'data/a.txt' $'awk\nawk'
  r0="$(bash "$RUN" --root "$PD1" --key-only probe 2>/dev/null)"
  run_hr "$PD1"; eq "duplicated 'awk' line: exit 0" "$RC" 0
  eq "duplicated 'awk' line: the awk row equals the single-line probe's row" "$(grep '/awk' <<<"$r0")" "$(grep '/awk' <<<"$rb")"
  eq "duplicated 'awk' line: exactly one awk row" "$(grep -c '/awk' <<<"$r0")" 1
  hook_dump "$PD1" "$PD1/.githooks/pre-push" "$WK/K4.o"
  eq "duplicated 'awk' line: the hook writes no .dunres row" "$(grep -c . "$WK/K4.o/.dunres")" 0
  eq "duplicated 'awk' line: the hook writes one .dtools row" "$(grep -c . "$WK/K4.o/.dtools")" 1
  mk_probe "$PD2" stub_k 'data/a.txt' $'?b207tool\n?b207tool'
  edit_hook "$PD2" 's/^READSET_UNKEYED_TOOLS="/&b207tool /'
  OUT="$(PATH="$sb:$PATH" bash "$RUN" --root "$PD2" probe 2>&1)"; RC=$?
  eq "duplicated ?b207tool line: exit 0" "$RC" 0
  yes "duplicated ?b207tool line: the stub ran" "$OUT" "b207tool-ran"
  hook_dump "$PD2" "$PD2/.githooks/pre-push" "$WK/K5.o"
  eq "duplicated ?b207tool line: the hook writes no .dunres row" "$(grep -c . "$WK/K5.o/.dunres")" 0
  mkdir -p "$xd" && printf '#!/bin/sh\necho other-b207tool\n' > "$xd/b207tool" && chmod +x "$xd/b207tool"
  mk_probe "$PD3" stub_k 'data/a.txt' $'b207tool\n?b207tool'
  edit_hook "$PD3" 's/^READSET_UNKEYED_TOOLS="/&b207tool /'
  edit_hook "$PD3" "s|^READSET_TOOL_XP=\"\"|READSET_TOOL_XP=\"$xd\"|"
  OUT="$(PATH="$sb:$PATH" bash "$RUN" --root "$PD3" probe 2>&1)"; RC=$?
  eq "two different b207tool paths: runner exit 2" "$RC" 2
  yes "two different b207tool paths: the basename message" "$OUT" "share the basename b207tool"
  hook_dump "$PD3" "$PD3/.githooks/pre-push" "$WK/K6.o"
  yes "two different b207tool paths: the hook writes a .dunres row" "$(cat "$WK/K6.o/.dunres" 2>/dev/null)" "duplicate basename b207tool"
  mk_probe "$PD4" stub_k 'data/a.txt' $'?b207tool\nb207tool'
  edit_hook "$PD4" 's/^READSET_UNKEYED_TOOLS="/&b207tool /'
  edit_hook "$PD4" "s|^READSET_TOOL_XP=\"\"|READSET_TOOL_XP=\"$xd\"|"
  hook_dump "$PD4" "$PD4/.githooks/pre-push" "$WK/K7.o"
  yes "two different paths, unkeyed line first: the hook writes a .dunres row" "$(cat "$WK/K7.o/.dunres" 2>/dev/null)" "duplicate basename b207tool"
  # ?node with a node -e stub: runs if node is on PATH, else SKIP.
  if command -v node >/dev/null 2>&1; then
    mk_probe "$WK/K3" stub_knode 'data/a.txt' '?node'
    run_hr "$WK/K3"
    eq "?node with node on PATH: exit 0" "$RC" 0
    yes "?node: node ran in the sandbox" "$OUT" "node-ran-b207"
  else
    echo "  SKIP  $CUR: ?node -- node is not on this PATH, so the ?node run has no subject"
    ok "$CUR: ?node skipped visibly"
  fi
  # The runner holds no copy of the tool dirs: it takes them from the hook's READSET_TOOLS span.
  n="$(/usr/bin/grep -c '/opt/homebrew/bin' "$RUN_ORIG")" || n=0
  eq "the runner carries no literal /opt/homebrew/bin line" "$n" 0
  n="$(/usr/bin/grep -c '/opt/homebrew/bin' "$HOOK_SRC")" || n=0
  [ "$n" -gt 0 ] && ok "$CUR: control: the hook does carry it" || bad "$CUR: control: the hook carries no /opt/homebrew/bin"
  FXR="$FXR_SAVE"
}
# --- L: DISTRIBUTION coordinates mapped on a CONSUMER ---------------------------------------------
arm_L() {
  CUR=L
  local FXR_SAVE="$FXR" P="$WK/L1" PD="$WK/L2" PM="$WK/L3" PX="$WK/L4" PA="$WK/L5" mapper rows nm
  mapper="$(dirname "$RUN_ORIG")/core-paths.sh"
  [ -f "$mapper" ] || { bad "$CUR: no core-paths.sh beside the runner under test"; return; }
  FXR="tests/fixtures"
  mk_probe "$P" stub_lcons '!core/scripts/x.sh'
  printf 'x\n' > "$P/scripts/ai-dlc/x.sh" 2>/dev/null || { mkdir -p "$P/scripts/ai-dlc" && printf 'x\n' > "$P/scripts/ai-dlc/x.sh"; }
  ( cd "$P" && git add -A && git -c user.name=t -c user.email=t@t commit -qm x ) >/dev/null 2>&1
  run_hr "$P"
  eq "consumer layout, core/ declaration: exit 0" "$RC" 0
  yes "consumer layout: the mapped spelling is listed in the sandbox" "$OUT" "./scripts/ai-dlc/x.sh"
  no "consumer layout: the declared spelling is NOT in the sandbox" "$OUT" "./core/scripts/x.sh" "./scripts/ai-dlc/x.sh"
  rows="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  yes "consumer layout: --key-only carries the mapped path" "$rows" "scripts/ai-dlc/x.sh${T}"
  no "consumer layout: --key-only carries no declared-spelling row" "$rows" "core/scripts/x.sh" "scripts/ai-dlc/x.sh${T}"
  # Distribution layout, same declaration: NOT mapped (control).
  FXR="core/fixtures"
  mk_probe "$PD" stub_ldist '!core/scripts/x.sh'
  mkdir -p "$PD/core/scripts" "$PD/scripts/ai-dlc" && printf 'x\n' > "$PD/core/scripts/x.sh" && printf 'm\n' > "$PD/scripts/ai-dlc/x.sh"
  ( cd "$PD" && git add -A && git -c user.name=t -c user.email=t@t commit -qm x ) >/dev/null 2>&1
  run_hr "$PD"
  eq "distribution layout, same declaration: exit 0" "$RC" 0
  yes "distribution layout: the declared spelling is listed" "$OUT" "./core/scripts/x.sh"
  no "distribution layout: the mapped spelling is NOT listed (not mapped)" "$OUT" "./scripts/ai-dlc/x.sh" "./core/scripts/x.sh"
  # The mapper's own controls.
  nm="$(printf 'core/skills/ai-dlc/steps/x.md\ncore/hooks/y.sh\ncore/schemas/z.json\ndocs/n.md\ncore/scripts/\n' | bash "$mapper" --map 2>&1)"
  rowhas "map: skills -> .claude/skills/" "$nm" ".claude/skills/ai-dlc/steps/x.md"
  rowhas "map: hooks -> .claude/hooks/" "$nm" ".claude/hooks/y.sh"
  rowhas "map: schemas -> .claude/schemas/" "$nm" ".claude/schemas/z.json"
  rowhas "map: a non-core path is unchanged" "$nm" "docs/n.md"
  rowhas "map: a directory keeps its trailing slash" "$nm" "scripts/ai-dlc/"
  printf 'core/ci-templates/x\n' | bash "$mapper" --map >/dev/null 2>&1; eq "map: an unrecognised top is exit 2" "$?" 2
  printf 'core\n' | bash "$mapper" --map >/dev/null 2>&1; eq "map: bare core is exit 2" "$?" 2
  # A mapped path absent on the consumer is `declared file absent`, naming both spellings.
  FXR="tests/fixtures"
  mk_probe "$PA" stub_lcons $'core/scripts/x.sh\ncore/scripts/missing.sh'
  mkdir -p "$PA/scripts/ai-dlc" && printf 'x\n' > "$PA/scripts/ai-dlc/x.sh"
  ( cd "$PA" && git add -A && git -c user.name=t -c user.email=t@t commit -qm x ) >/dev/null 2>&1
  run_hr "$PA"
  eq "mapped path absent: exit 2" "$RC" 2
  yes "mapped path absent: names both spellings" "$OUT" "declared file absent: scripts/ai-dlc/missing.sh (declared as core/scripts/missing.sh)"
  mk_probe "$PX" stub_lcons 'core/ci-templates/x.md'
  run_hr "$PX"
  eq "unrecognised core/ top in a declaration: exit 2" "$RC" 2
  # The runner copied beside NO mapper: exit 2 `mapper absent`.
  mkdir -p "$WK/L.nomap" && cp "$RUN" "$WK/L.nomap/hermetic-run.sh"
  OUT="$(bash "$WK/L.nomap/hermetic-run.sh" --root "$P" probe 2>&1)"; RC=$?
  eq "no mapper beside the runner: exit 2" "$RC" 2
  yes "no mapper beside the runner: mapper absent" "$OUT" "mapper absent"
  # control for the line above: the same probe through a copy that HAS the mapper beside it is exit 0.
  mkdir -p "$WK/L.map" && cp "$RUN" "$WK/L.map/hermetic-run.sh" && cp "$mapper" "$WK/L.map/core-paths.sh"
  OUT="$(bash "$WK/L.map/hermetic-run.sh" --root "$P" probe 2>&1)"; RC=$?
  eq "control: the same copy with the mapper beside it: exit 0" "$RC" 0
  FXR="$FXR_SAVE"
}
# --- N: a bare `git` is keyed on the binary that runs --------------------------------------------
arm_N() {
  CUR=N
  local FXR_SAVE="$FXR" P="$WK/N1" xp rows
  xp="$(/usr/bin/env -u DEVELOPER_DIR -u GIT_EXEC_PATH /usr/bin/git --exec-path 2>/dev/null)"
  if [ -z "$xp" ] || [ ! -x "$xp/git" ] || [ "$xp/git" = /usr/bin/git ]; then
    echo "  SKIP  $CUR: no exec-path git distinct from /usr/bin/git on this box ($xp), so the keyed binary and the shim cannot be told apart"
    ok "$CUR: skipped visibly"; return
  fi
  FXR="$(hook_fxroot)"
  mk_probe "$P" stub_named 'data/a.txt' $'awk\ngit\ngit-upload-pack'
  rows="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  yes "control: the awk row is present" "$rows" "/awk${T}"
  yes "bare git keys the exec-path binary" "$rows" "$xp/git${T}"
  no "bare git does not key /usr/bin/git" "$rows" "/usr/bin/git${T}" "/awk${T}"
  if [ -x "$xp/git-upload-pack" ]; then yes "git-upload-pack keys in the exec-path dir" "$rows" "$xp/git-upload-pack${T}"
  else echo "  SKIP  $CUR: $xp has no git-upload-pack"; ok "$CUR: git-upload-pack skipped visibly"; fi
  FXR="$FXR_SAVE"
}
# --- P..W: a declared directory is copied by its GIT POPULATION, links in it are refused ----------
# The key covers tracked plus untracked-unignored files; the sandbox must hold exactly those. A
# whole-directory copy carried every IGNORED file too, and one ignored link (the reference consumer's
# `.claude/skills/swap-integration`) refused every fixture declaring `core/skills/`.
stub_pop()       { cat <<'EOF'
printf 'SBROOT=%s\n' "$(pwd -P)"
find . -type f | LC_ALL=C sort
[ -d emp ] && echo "EMPTY-DIR-PRESENT"
[ -x lib/tool ] && echo "EXEC-MODE-KEPT"
EOF
}
commit_all() { ( cd "$1" && git add -A && git -c user.name=t -c user.email=t@t commit -qm "$2" ) >/dev/null 2>&1; }
# P: ignored link and ignored file under a declared dir are neither copied nor refused; the tracked
# sibling is there (control); a declared dir whose population is empty still exists; a tracked
# executable non-.sh file keeps its mode.
arm_P() {
  CUR=P
  local P="$WK/P1" sb
  mk_probe "$P" stub_pop $'data/a.txt\nlib/\nemp/'
  mkdir -p "$P/emp" && printf 'i\n' > "$P/emp/only.log"
  printf 'lib/ign.txt\nlib/ilnk\nemp/\n' > "$P/.gitignore"
  printf 'ignored\n' > "$P/lib/ign.txt"
  ln -s /etc/hosts "$P/lib/ilnk"
  printf '#!/bin/sh\necho t\n' > "$P/lib/tool" && chmod 755 "$P/lib/tool"
  commit_all "$P" pop
  mkdir -p "$WK/P.tmp"
  OUT="$(TMPDIR="$WK/P.tmp" AI_DLC_HERMETIC_KEEP=1 bash "$RUN" --root "$P" probe 2>&1)"; RC=$?
  sb="$(sed -n 's/^SBROOT=//p' <<<"$OUT" | head -1)"
  eq "ignored link + ignored file under a declared dir: exit 0" "$RC" 0
  [ -n "$sb" ] && [ -d "$sb" ] && ok "$CUR: the kept sandbox is on disk" || bad "$CUR: no kept sandbox ($sb)"
  [ -n "$sb" ] && [ -f "$sb/lib/x.txt" ] && ok "$CUR: control: tracked sibling lib/x.txt is in the sandbox" || bad "$CUR: tracked sibling lib/x.txt absent"
  [ -n "$sb" ] && [ ! -e "$sb/lib/ilnk" ] && [ ! -L "$sb/lib/ilnk" ] && ok "$CUR: ignored link lib/ilnk is ABSENT from the sandbox" || bad "$CUR: ignored link lib/ilnk reached the sandbox"
  [ -n "$sb" ] && [ ! -e "$sb/lib/ign.txt" ] && ok "$CUR: ignored file lib/ign.txt is ABSENT from the sandbox" || bad "$CUR: ignored file lib/ign.txt reached the sandbox"
  yes "declared dir with an empty population exists in the sandbox" "$OUT" "EMPTY-DIR-PRESENT"
  yes "executable non-.sh file keeps its mode" "$OUT" "EXEC-MODE-KEPT"
  [ -x "$P/lib/tool" ] && ok "$CUR: control: lib/tool is executable at the source" || bad "$CUR: lib/tool not executable at the source"
  [ -L "$P/lib/ilnk" ] && [ -f "$P/lib/ign.txt" ] && ok "$CUR: control: both ignored paths exist at the source" || bad "$CUR: an ignored path is missing at the source"
}
# Q: a TRACKED link that is not a regular file -- to a directory, or dangling -- is refused. `-f`
# follows links, so a check placed after an `-f` filter would never see either of these.
arm_Q() {
  CUR=Q
  mk_probe "$WK/Q1" stub_read_all $'data/a.txt\nlib/'
  ln -s ../data "$WK/Q1/lib/dlnk"; commit_all "$WK/Q1" dlnk
  run_hr "$WK/Q1"
  eq "tracked dir-link under a declared dir: exit 2" "$RC" 2
  yes "tracked dir-link: message names it" "$OUT" "lib/dlnk is a symlink"
  mk_probe "$WK/Q2" stub_read_all $'data/a.txt\nlib/'
  ln -s no-such-target "$WK/Q2/lib/dang"; commit_all "$WK/Q2" dang
  run_hr "$WK/Q2"
  eq "tracked dangling link under a declared dir: exit 2" "$RC" 2
  yes "tracked dangling link: message names it" "$OUT" "lib/dang is a symlink"
  # Near-miss: a tracked regular sub-directory in the same place is copied (exit 0).
  mk_probe "$WK/Q3" stub_ls $'data/a.txt\nlib/'
  mkdir -p "$WK/Q3/lib/sub2" && printf 's\n' > "$WK/Q3/lib/sub2/s.txt"; commit_all "$WK/Q3" sub2
  run_hr "$WK/Q3"
  eq "control: a tracked regular sub-directory: exit 0" "$RC" 0
  yes "control: the sub-directory's file is copied" "$OUT" "./lib/sub2/s.txt"
}
# R: an untracked, unignored link to a FILE is in the population and is refused.
arm_R() {
  CUR=R
  mk_probe "$WK/R1" stub_read_all $'data/a.txt\nlib/'
  ln -s /etc/hosts "$WK/R1/lib/uflnk"
  [ -z "$(cd "$WK/R1" && git ls-files lib/uflnk)" ] && ok "$CUR: control: lib/uflnk is untracked" || bad "$CUR: lib/uflnk is tracked"
  run_hr "$WK/R1"
  eq "untracked-unignored file-link under a declared dir: exit 2" "$RC" 2
  yes "untracked-unignored file-link: message names it" "$OUT" "lib/uflnk is a symlink"
}
# W: an untracked, unignored link to a DIRECTORY -- both an -f-ordered check and a tracked-only
# check miss it, so it has its own arm.
arm_W() {
  CUR=W
  mk_probe "$WK/W1" stub_read_all $'data/a.txt\nlib/'
  ln -s ../data "$WK/W1/lib/udlnk"
  run_hr "$WK/W1"
  eq "untracked-unignored dir-link under a declared dir: exit 2" "$RC" 2
  yes "untracked-unignored dir-link: message names it" "$OUT" "lib/udlnk is a symlink"
}
# S: a gitlink (mode 160000) under a declared directory is refused.
arm_S() {
  CUR=S
  local P="$WK/S1" h
  mk_probe "$P" stub_read_all $'data/a.txt\nlib/'
  h="$(cd "$P" && git rev-parse HEAD)"
  ( cd "$P" && git update-index --add --cacheinfo "160000,$h,lib/sub" && git -c user.name=t -c user.email=t@t commit -qm gl ) >/dev/null 2>&1
  [ "$(cd "$P" && git ls-files -s lib/sub | cut -c1-6)" = 160000 ] && ok "$CUR: control: lib/sub is a gitlink in the index" || bad "$CUR: the gitlink was not recorded"
  run_hr "$P"
  eq "gitlink under a declared dir: exit 2" "$RC" 2
  yes "gitlink: message names it" "$OUT" "lib/sub is a gitlink"
}
# T: THE KEY DID NOT MOVE. A tracked file deleted from the working tree is in the copy population
# (.paths) and not in the key (.now); the runner's rows must equal the hook's own and the listing must
# be the one the key population implies.
arm_T() {
  CUR=T
  local FXR_SAVE="$FXR" P="$WK/T1" hk hr lsha want
  FXR="$(hook_fxroot)"
  mk_probe "$P" stub_named $'data/a.txt\nlib/'
  rm "$P/lib/y.txt"
  [ -n "$(cd "$P" && git ls-files lib/y.txt)" ] && ok "$CUR: control: lib/y.txt is still tracked" || bad "$CUR: lib/y.txt is not tracked"
  hook_dump "$P" "$P/.githooks/pre-push" "$WK/T1.o"
  hk="$(grep -v '^#' "$WK/T1.o/.k/probe" 2>/dev/null)"
  hr="$(bash "$RUN" --root "$P" --key-only probe 2>/dev/null)"
  [ -n "$hk" ] && ok "$CUR: hook row set is non-empty" || bad "$CUR: hook row set empty"
  if [ "$hk" = "$hr" ]; then ok "$CUR: runner rows equal the hook's with a deleted tracked file"; else bad "$CUR: runner rows differ from the hook's"; fi
  want="$(printf 'x.txt\n' | shasum -a 256 | awk '{ print $1 }')"
  lsha="$(sed -n "s/^lib\/${T}#listing://p" <<<"$hr")"
  eq "lib/ listing is the key population's (x.txt only)" "$lsha" "$want"
  FXR="$FXR_SAVE"
}
# U: a root git cannot list is exit 2 with a named message, and --key-only on a tree whose hashing
# fails exits non-zero (control: the same tree without the unhashable name prints rows at 0).
arm_U() {
  CUR=U
  local P="$WK/U1" P2="$WK/U2" rows
  mk_probe "$P" stub_named 'data/a.txt'
  mv "$P/.git" "$P/.git.off"
  run_hr "$P"
  eq "non-git root: exit 2" "$RC" 2
  yes "non-git root: message" "$OUT" "needs a git work tree"
  mk_probe "$P2" stub_named 'data/a.txt'
  rows="$(bash "$RUN" --root "$P2" --key-only probe 2>/dev/null)"; RC=$?
  eq "control: --key-only on a hashable tree: exit 0" "$RC" 0
  yes "control: --key-only printed the declared row" "$rows" "data/a.txt${T}"
  printf 'q\n' > "$P2/data/q\"x.txt"
  OUT="$(bash "$RUN" --root "$P2" --key-only probe 2>&1)"; RC=$?
  [ "$RC" -ne 0 ] && ok "$CUR: --key-only on an unhashable tree exits non-zero ($RC)" || bad "$CUR: --key-only on an unhashable tree exited 0"
  yes "unhashable tree: the hashing message" "$OUT" "could not hash the working tree"
  # Near-miss for the copy-path refusal below: the quoted name sits under an UNDECLARED directory,
  # so it is in no declared population and the sandbox run is exit 0.
  run_hr "$P2"
  eq "near-miss: quoted name outside every declared dir: sandbox run exit 0" "$RC" 0
  # A name git quotes UNDER a declared directory cannot be copied by its listed spelling: exit 2.
  local P3="$WK/U3"
  mk_probe "$P3" stub_read_all $'data/a.txt\nlib/'
  printf 'q\n' > "$P3/lib/q\"x.txt"
  run_hr "$P3"
  eq "quoted name under a declared dir: exit 2" "$RC" 2
  yes "quoted name under a declared dir: message" "$OUT" "is a name git quotes"
}
# --- V: VERSION SKEW -- a hook with no READSET_KEYROWS span ----------------------------------------
# A consumer mid-pull runs this runner against an older hook. The sandbox run still runs, through the
# runner's own hr_parse_skew, with the verdict store OFF; --key-only refuses. The span-present twin (V0)
# is the control that the OFF line and the empty store are the skew path's doing, and hr_parse_skew's
# `?name` and mapping branches each get a world only they can pass (killed by M5 and M4).
arm_V() {
  CUR=V
  local FXR_SAVE="$FXR" sb="$WK/V.bin" P1="$WK/V1" P0="$WK/V0" PC="$WK/V2" mapper n
  mapper="$(dirname "$RUN")/core-paths.sh"
  mkdir -p "$sb" && printf '#!/bin/sh\necho b207tool-ran\n' > "$sb/b207tool" && chmod +x "$sb/b207tool" || exit 2
  FXR="$(hook_fxroot)"
  # V1: skew, `?b207tool` reachable on PATH.
  mk_probe "$P1" stub_k 'data/a.txt' '?b207tool'
  edit_hook "$P1" 's/^READSET_UNKEYED_TOOLS="/&b207tool /'
  edit_hook "$P1" '/^# READSET_KEYROWS_BEGIN$/,/^# READSET_KEYROWS_END$/d'
  n="$(grep -c '^readset_decl_parse()' "$P1/.githooks/pre-push")" || n=0
  eq "control: the skew probe's hook carries no readset_decl_parse" "$n" 0
  n="$(grep -c '^# READSET_TOOLS_BEGIN$' "$P1/.githooks/pre-push")" || n=0
  eq "control: the skew probe's hook still carries its READSET_TOOLS span" "$n" 1
  commit_all "$P1" skew
  mkdir -p "$WK/V1.store"
  OUT="$(PATH="$sb:$PATH" AI_DLC_VERDICT_STORE="$WK/V1.store" bash "$RUN" --root "$P1" probe 2>&1)"; RC=$?
  eq "skew, ?b207tool on PATH: sandbox run exit 0" "$RC" 0
  yes "skew: the stub ran from the sandbox" "$OUT" "b207tool-ran"
  yes "skew: the run says the store is OFF for want of the span" "$OUT" "carries no READSET_KEYROWS span (an older hook)"
  eq "skew: no verdict store entry was written" "$(ls "$WK/V1.store" | wc -l | tr -d ' ')" 0
  OUT="$(PATH="$sb:$PATH" bash "$RUN" --root "$P1" --key-only probe 2>&1)"; RC=$?
  eq "skew: --key-only exit 2" "$RC" 2
  yes "skew: --key-only names the missing span" "$OUT" "so there are no key rows to print"
  # V0: the same probe WITH the span: no OFF line, and the pass IS recorded.
  mk_probe "$P0" stub_k 'data/a.txt' '?b207tool'
  edit_hook "$P0" 's/^READSET_UNKEYED_TOOLS="/&b207tool /'
  commit_all "$P0" span
  mkdir -p "$WK/V0.store"
  OUT="$(PATH="$sb:$PATH" AI_DLC_VERDICT_STORE="$WK/V0.store" bash "$RUN" --root "$P0" probe 2>&1)"; RC=$?
  eq "control: span present: exit 0" "$RC" 0
  no "control: span present: no store-OFF line" "$OUT" "carries no READSET_KEYROWS span" "b207tool-ran"
  eq "control: span present: the pass IS recorded" "$(ls "$WK/V0.store" | wc -l | tr -d ' ')" 1
  # V2: skew in a CONSUMER layout: a core/ declaration mapped by hr_parse_skew's own mapper call.
  FXR="tests/fixtures"
  mk_probe "$PC" stub_lcons '!core/scripts/x.sh'
  mkdir -p "$PC/scripts/ai-dlc" && printf 'x\n' > "$PC/scripts/ai-dlc/x.sh"
  edit_hook "$PC" '/^# READSET_KEYROWS_BEGIN$/,/^# READSET_KEYROWS_END$/d'
  commit_all "$PC" skewcons
  [ -f "$mapper" ] && ok "$CUR: control: core-paths.sh is beside the runner under test" || bad "$CUR: no core-paths.sh beside $RUN"
  OUT="$(bash "$RUN" --root "$PC" probe 2>&1)"; RC=$?
  eq "skew, consumer layout, core/ declaration: exit 0" "$RC" 0
  yes "skew, consumer layout: the store-OFF line (the skew path ran)" "$OUT" "carries no READSET_KEYROWS span (an older hook)"
  yes "skew, consumer layout: the mapped spelling is in the sandbox" "$OUT" "./scripts/ai-dlc/x.sh"
  no "skew, consumer layout: the declared spelling is NOT" "$OUT" "./core/scripts/x.sh" "./scripts/ai-dlc/x.sh"
  FXR="$FXR_SAVE"
}
# --- X: git.decl -- a seeded repository and pinned commits inside the sandbox ---------------------
# The stub reads the pinned commit's blob, which DIFFERS from the working tree's, so a pin answered
# from the tree (or from a repository the sandbox should not see) cannot pass.
stub_git()       { cat <<'EOF'
cat data/a.txt >/dev/null || exit 1
printf 'TREE=%s\n' "$(cat data/a.txt)"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "INSIDE=yes"; else echo "INSIDE=no"; fi
if git cat-file -e "@@PIN@@^{commit}" 2>/dev/null; then printf 'PINNED=%s\n' "$(git show "@@PIN@@:data/a.txt")"; else echo "PIN-ABSENT"; fi
if git rev-parse -q --verify HEAD >/dev/null 2>&1; then echo "HEAD-OK"; else echo "HEAD-NONE"; fi
EOF
}
# mk_git_probe <dir> <git.decl text, @@PIN@@ substituted>: a probe whose FIRST commit holds data/a.txt
# `alpha` (the pin) and whose working tree and HEAD hold `beta`. Sets PIN.
mk_git_probe() {
  local p="$1"
  mk_probe "$p" stub_named 'data/a.txt'
  PIN="$(cd "$p" && git rev-parse HEAD)"
  printf 'beta\n' > "$p/data/a.txt"
  { printf '#!/usr/bin/env bash\nset -u\n'; stub_git | sed "s/@@PIN@@/$PIN/g"; } > "$p/$FXR/probe/run.sh"
  [ -z "$2" ] || printf '%s\n' "$2" | sed "s/@@PIN@@/$PIN/g" > "$p/$FXR/probe/git.decl"
  commit_all "$p" beta
}
arm_X() {
  CUR=X
  local absent="0123456789abcdef0123456789abcdef01234567"
  mk_git_probe "$WK/X1" $'seed\npin @@PIN@@'
  [ -n "$(cd "$WK/X1" && git cat-file -t "$absent" 2>/dev/null)" ] && bad "$CUR: control: the absent sha exists in the probe" || ok "$CUR: control: the absent sha is in no probe"
  run_hr "$WK/X1"
  eq "seed + pin: exit 0" "$RC" 0
  yes "control: the stub read the working tree" "$OUT" "TREE=beta"
  yes "seed: the sandbox root is a work tree" "$OUT" "INSIDE=yes"
  yes "seed: the sandbox has a HEAD" "$OUT" "HEAD-OK"
  yes "pin: the PINNED blob is the commit's, not the tree's" "$OUT" "PINNED=alpha"
  mk_git_probe "$WK/X2" ''
  run_hr "$WK/X2"
  eq "no git.decl: exit 0" "$RC" 0
  no "no git.decl: no repository in the sandbox" "$OUT" "INSIDE=yes" "TREE=beta"
  yes "no git.decl: the pin is not reachable" "$OUT" "PIN-ABSENT"
  mk_git_probe "$WK/X3" 'seed'
  run_hr "$WK/X3"
  eq "seed only: exit 0" "$RC" 0
  yes "seed only: HEAD exists" "$OUT" "HEAD-OK"
  no "seed only: no pin was imported" "$OUT" "PINNED=" "HEAD-OK"
  mk_git_probe "$WK/X4" "pin $absent"
  run_hr "$WK/X4"
  eq "required pin absent from the project: exit 2" "$RC" 2
  yes "required pin absent: message names it" "$OUT" "declared pin $absent is not a commit"
  mk_git_probe "$WK/X5" $'seed\npin? '"$absent"
  mkdir -p "$WK/X5.store"
  OUT="$(AI_DLC_VERDICT_STORE="$WK/X5.store" bash "$RUN" --root "$WK/X5" probe 2>&1)"; RC=$?
  eq "optional pin absent: exit 0" "$RC" 0
  yes "optional pin absent: says it was not imported" "$OUT" "optional pin $absent is not in this project"
  yes "optional pin absent: the fixture's own absent branch ran" "$OUT" "PIN-ABSENT"
  eq "optional pin absent: the pass is NOT recorded in the verdict store" "$(ls "$WK/X5.store" | wc -l | tr -d ' ')" 0
  mk_git_probe "$WK/X6" $'pin? @@PIN@@'
  mkdir -p "$WK/X6.store"
  OUT="$(AI_DLC_VERDICT_STORE="$WK/X6.store" bash "$RUN" --root "$WK/X6" probe 2>&1)"; RC=$?
  eq "optional pin present: exit 0" "$RC" 0
  yes "optional pin present: imported" "$OUT" "PINNED=alpha"
  eq "control: optional pin present: the pass IS recorded" "$(ls "$WK/X6.store" | wc -l | tr -d ' ')" 1
  mk_git_probe "$WK/X7" 'pin abc123'
  run_hr "$WK/X7"
  eq "abbreviated pin: exit 2" "$RC" 2
  yes "abbreviated pin: message" "$OUT" "must be a full 40-hex sha"
  mk_git_probe "$WK/X8" 'clone everything'
  run_hr "$WK/X8"
  eq "unknown git.decl line: exit 2" "$RC" 2
  yes "unknown git.decl line: message" "$OUT" "neither seed, pin <sha> nor pin? <sha>"
}
# Y: a fixture whose declaration carries bare `core/` has its own directory copied in TWICE -- once by
# that population, once by the own-directory copy. The second must land on the first, never inside it.
# Presence-shaped: the own run.sh must be LISTED (control) and the count must be exact, so a runner that
# copied nothing cannot pass by also listing no nested directory.
arm_Y() {
  CUR=Y
  local P="$WK/Y1" expy
  mk_probe "$P" stub_ls $'data/a.txt\ncore/'
  run_hr "$P"
  eq "bare core/ declared: exit 0" "$RC" 0
  yes "bare core/: the fixture's own run.sh is in the sandbox" "$OUT" "./$FXR/probe/run.sh"
  no "bare core/: no nested <fx>/<fx>/ directory" "$OUT" "./$FXR/probe/probe/" "./$FXR/probe/run.sh"
  expy=$((1 + $(nfiles "$P/core")))
  yes "bare core/: count is exact ($expy, the fixture dir copied once)" "$OUT" "rc=0 sandbox_files=$expy required_missing=0"
}
run_arms() { arm_A; arm_B; arm_C; arm_D; arm_E; arm_F; arm_H; arm_I; arm_K; arm_L; arm_N; }

# --- main run -----------------------------------------------------------------------------------
WK="$WORK/main"; mkdir -p "$WK"
if [ -z "$HOOK_SRC" ]; then echo "FIXTURE ERROR: no pre-push hook with a READSET_UNIVERSE span in this tree" >&2; exit 2; fi
# The main pass runs its arms in parallel subshells, each with its own output and FAILED file, then
# replays the output in arm order so the transcript reads as before.
mkdir -p "$WORK/par"
for _a in A B C D E F H I K L N G J P Q R S T U V W X Y; do
  ( "arm_$_a" > "$WORK/par/$_a.out" 2>&1; printf '%s' "$FAILED" > "$WORK/par/$_a.failed" ) &
done
wait
for _a in A B C D E F H I K L N G J P Q R S T U V W X Y; do
  cat "$WORK/par/$_a.out"
  [ -f "$WORK/par/$_a.failed" ] || { echo "FIXTURE ERROR: arm $_a produced no verdict" >&2; exit 2; }
  FAILED="$FAILED$(cat "$WORK/par/$_a.failed")"
done
MAIN_FAILED="$FAILED"

# --- mutants of the runner ----------------------------------------------------------------------
mutate() { # mutate <out> <old> <new>: replace exactly one line occurrence, require a real change
  OLD="$2" NEW="$3" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print } END { if (n != 1) exit 3 }' "$RUN_ORIG" > "$1" || return 1
  cmp -s "$RUN_ORIG" "$1" && return 1
  return 0
}
failed_set() { tr ' ' '\n' <<<"$1" | grep -v '^$' | LC_ALL=C sort -u | tr '\n' ' '; }
# run_mutant <name> <arms> <old> <new>: only the mutant's expected arms plus ONE control arm run, so the
# verdict is "the expected arms fail and the control arm passes".
run_mutant() {
  # The mutant lives in its own directory WITH the mapper beside it: the runner resolves core-paths.sh
  # from its own directory, so a lone copy would fail arm L as `mapper absent` and score every mutant
  # as an L failure it did not earn. The sibling is asserted present (a mutant verdict is evidence only
  # about a subject that ran).
  local m="$WORK/mutdir-$1/hermetic-run.sh"
  mkdir -p "$WORK/mutdir-$1" && cp "$(dirname "$RUN_ORIG")/core-paths.sh" "$WORK/mutdir-$1/core-paths.sh" || { echo "BROKEN" > "$WORK/mut-$1.res"; return; }
  mutate "$m" "$3" "$4" || { echo "BROKEN" > "$WORK/mut-$1.res"; return; }
  ( RUN="$m"; WK="$WORK/m-$1"; mkdir -p "$WK"; VERBOSE=0; FAILED=""; for _a in $2; do "arm_$_a"; done; failed_set "$FAILED" > "$WORK/mut-$1.res" )
}
# run_hook_mutant <name> <arms> <old> <new>: the same, but the mutation is applied to a copy of the HOOK
# every probe copies (HOOK_SRC, the file the runner under test sources its READSET_KEYROWS span from), and
# the runner is the unmutated one. The declaration parse lives in that span, so a mutant of the parse the
# runner OBSERVES has to be built there; a runner mutant cannot reach it.
run_hook_mutant() {
  local h="$WORK/hmutdir-$1/pre-push"
  mkdir -p "$WORK/hmutdir-$1" || { echo "BROKEN" > "$WORK/mut-$1.res"; return; }
  mutate_file "$HOOK_SRC" "$h" "$3" "$4" || { echo "BROKEN" > "$WORK/mut-$1.res"; return; }
  ( HOOK_SRC="$h"; WK="$WORK/m-$1"; mkdir -p "$WK"; VERBOSE=0; FAILED=""; for _a in $2; do "arm_$_a"; done; failed_set "$FAILED" > "$WORK/mut-$1.res" )
}

if [ "$NESTED" != 1 ]; then
  run_mutant M1 "B D" 'if ! grep -qxF -e "HERMETIC-CONSUMED $rr"' 'if false && grep -qxF -e "HERMETIC-CONSUMED $rr"' &
  run_mutant M2 "A C D L B" 'mkdir -p "$HR_SB/$HR_FXROOT" || exit 2' 'cp -Rp "$HR_ROOT/." "$HR_SB/" ; mkdir -p "$HR_SB/$HR_FXROOT" || exit 2' &
  run_mutant M3 "F B" 'env -i PATH=' 'env PATH=' &
  # M4: the span's mapper call made the identity, in the hook the runner sources: a core/ declaration on a
  # consumer is not mapped, so the runner refuses it as absent.
  run_hook_mutant M4 "L A" '| bash "$mp" --map >' '| cat >' &
  # M5: the span's `?name` branch never taken, in the hook the runner sources: `?b207tool` is resolved as a
  # keyed tool name and refused.
  run_hook_mutant M5 "K A" "'?'*)" "'NEVER?'*)" &
  # M17/M18: the same two properties in the runner's own skew parser, which runs only when the hook carries
  # no READSET_KEYROWS span, so only arm V (span removed) can see them.
  run_mutant M17 "V A" "'?'*) printf" "'NEVER?'*) printf" &
  run_mutant M18 "V A" '| bash "$4" --map >' '| cat >' &
  # M19: the runner hands the span the DISTRIBUTION layout on a consumer: no mapping, the declaration refused.
  run_mutant M19 "L A" 'hr_lay=cons; [ "$HR_LAYOUT" = distribution ] && hr_lay=dist' 'hr_lay=dist' &
  run_mutant M6 "F B" 'HR_WORK="$(cd "$HR_WORK" && pwd -P)" || exit 2' 'HR_WORK="$HR_WORK"' &
  # M7: a declared directory copied whole again (`cp -Rp`): the ignored link and file reach the sandbox.
  run_mutant M7 "P Q" '  mkdir -p "$HR_SB/$d" || exit 2' '  { mkdir -p "$HR_SB/$(dirname "$d")" && { [ -e "$HR_SB/$d" ] || cp -Rp "$HR_ROOT/$d" "$HR_SB/$d"; }; } || exit 2' &
  # M8: the link test placed behind an `-f` filter: a dir-link and a dangling link pass.
  run_mutant M8 "Q W R" '    if [ -L "$HR_ROOT/$e" ]; then' '    if [ -f "$HR_ROOT/$e" ] && [ -L "$HR_ROOT/$e" ]; then' &
  # M9: the link test scoped to TRACKED entries: untracked-unignored links pass.
  run_mutant M9 "R W Q" '    if [ -L "$HR_ROOT/$e" ]; then' '    if [ -L "$HR_ROOT/$e" ] && ( cd "$HR_ROOT" && git ls-files --error-unmatch -- "$e" >/dev/null 2>&1 ); then' &
  # M10: the copy population fed into the key: a deleted tracked file moves the listing row.
  run_mutant M10 "T G" 'cut -f1 "$HR_WORK/m/.now" > "$HR_WORK/m/.is"' 'cat "$o/.paths" > "$HR_WORK/m/.is"' &
  # M11: the key subshell's exit lost again: an unhashable tree prints nothing at exit 0.
  run_mutant M11 "U G" ') > "$HR_WORK/krows"; hr_kr=$?' ') > "$HR_WORK/krows"; hr_kr=0' &
  # M12: the pin pack never reaches the sandbox: a pinned blob is unreadable there.
  run_mutant M12 "X" 'pack-objects -q "$HR_SB/.git/objects/pack/pack"' 'pack-objects -q "$HR_WORK/pack"' &
  # M13: a required pin absent from the project is treated as optional: no exit 2.
  run_mutant M13 "X" 'elif [ "${line%% *}" = pin ]; then' 'elif false; then' &
  # M14: the seed commit skipped: the sandbox repository has no HEAD.
  run_mutant M14 "X" '  if [ "$hr_seed" = 1 ]; then' '  if false; then' &
  # M15: an abbreviated pin accepted: the full-sha guard removed.
  run_mutant M15 "X" '[ "${#hr_ps}" -eq 40 ] ||' 'true ||' &
  # M16: a pass with an optional pin skipped is recorded anyway, so a shallow clone's pass is reused by a full one.
  run_mutant M16 "X" '[ "${hr_pin_skipped:-0}" = 0 ] || return 0' ':' &
  # M20: the own-directory copy restored to `cp -Rp <dir> <dest>`, which nests onto a dest `core/` already made.
  run_mutant M20 "Y A" 'mkdir -p "$HR_SB/$HR_FXROOT/$HR_FX" && cp -Rp "$HR_FXDIR/." "$HR_SB/$HR_FXROOT/$HR_FX/" || exit 2' 'cp -Rp "$HR_FXDIR" "$HR_SB/$HR_FXROOT/$HR_FX" || exit 2' &
  # cwd-invariance: two nested runs of this fixture from different working directories.
  ( cd "$ROOT" && HERMETIC_FX_NESTED=1 bash "$HERE/run.sh" > "$WORK/cwd1.out" 2>&1; echo $? > "$WORK/cwd1.rc" ) &
  ( cd "$(dirname "$RUN")" && HERMETIC_FX_NESTED=1 bash "$HERE/run.sh" > "$WORK/cwd2.out" 2>&1; echo $? > "$WORK/cwd2.rc" ) &
  wait
  CUR=M
  for pair in "M1:B" "M2:A C D L" "M3:F" "M4:L" "M5:K" "M6:F" "M7:P" "M8:Q W" "M9:R W" "M10:T" "M11:U" "M12:X" "M13:X" "M14:X" "M15:X" "M16:X" "M17:V" "M18:V" "M19:L" "M20:Y"; do
    mname="${pair%%:*}"; want="$(failed_set "${pair#*:}")"
    got="$(cat "$WORK/mut-$mname.res" 2>/dev/null)"
    if [ "$got" = "BROKEN" ] || [ -z "$got" ] && [ "$want" != "" ] && [ "$got" = "BROKEN" ]; then
      echo "FIXTURE ERROR: mutant $mname did not apply to $RUN_ORIG (the target line moved)" >&2; exit 2
    fi
    eq "$mname fails exactly its own arms [$want]" "$got" "$want"
  done
  CUR=cwd
  eq "from the root: exit 0" "$(cat "$WORK/cwd1.rc" 2>/dev/null)" 0
  eq "from the runner's dir: exit 0" "$(cat "$WORK/cwd2.rc" 2>/dev/null)" 0
  a="$(grep '^  ok' "$WORK/cwd1.out" | sed 's/ [0-9]*$//' | shasum | awk '{ print $1 }')"
  b="$(grep '^  ok' "$WORK/cwd2.out" | sed 's/ [0-9]*$//' | shasum | awk '{ print $1 }')"
  na="$(grep -c '^  ok' "$WORK/cwd1.out")" || na=0
  [ "$na" -gt 0 ] && ok "cwd: the nested run produced $na ok lines (control)" || bad "cwd: nested run produced no ok lines"
  eq "same ok lines from both working directories" "$a" "$b"
fi

if [ -n "$(failed_set "$FAILED")" ]; then
  echo "hermetic-runner: FAIL arms:$(failed_set "$FAILED")"
  exit 1
fi
echo "hermetic-runner: every arm holds"
exit 0
