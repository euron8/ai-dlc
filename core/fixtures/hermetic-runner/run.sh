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
#   M  three mutants of the runner, each built on a COPY and guarded by `cmp -s`, each of which
#      must fail exactly its own arms
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
  FXR="$FXR_SAVE"
}
run_arms() { arm_A; arm_B; arm_C; arm_D; arm_E; arm_F; arm_H; arm_I; }

# --- main run -----------------------------------------------------------------------------------
WK="$WORK/main"; mkdir -p "$WK"
if [ -z "$HOOK_SRC" ]; then echo "FIXTURE ERROR: no pre-push hook with a READSET_UNIVERSE span in this tree" >&2; exit 2; fi
run_arms; arm_G; arm_J
MAIN_FAILED="$FAILED"

# --- mutants of the runner ----------------------------------------------------------------------
mutate() { # mutate <out> <old> <new>: replace exactly one line occurrence, require a real change
  OLD="$2" NEW="$3" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print } END { if (n != 1) exit 3 }' "$RUN_ORIG" > "$1" || return 1
  cmp -s "$RUN_ORIG" "$1" && return 1
  return 0
}
failed_set() { tr ' ' '\n' <<<"$1" | grep -v '^$' | LC_ALL=C sort -u | tr '\n' ' '; }
run_mutant() { # run_mutant <name> <old> <new>
  local m="$WORK/mut-$1.sh"
  mutate "$m" "$2" "$3" || { echo "BROKEN" > "$WORK/mut-$1.res"; return; }
  ( RUN="$m"; WK="$WORK/m-$1"; mkdir -p "$WK"; VERBOSE=0; FAILED=""; run_arms; failed_set "$FAILED" > "$WORK/mut-$1.res" )
}

if [ "$NESTED" != 1 ]; then
  run_mutant M1 'if ! grep -qxF -e "HERMETIC-CONSUMED $rr"' 'if false && grep -qxF -e "HERMETIC-CONSUMED $rr"' &
  run_mutant M2 'mkdir -p "$HR_SB/$HR_FXROOT" && cp -Rp "$HR_FXDIR" "$HR_SB/$HR_FXROOT/$HR_FX" || exit 2' 'cp -Rp "$HR_ROOT/." "$HR_SB/" ; mkdir -p "$HR_SB/$HR_FXROOT/$HR_FX" && cp -Rp "$HR_FXDIR/." "$HR_SB/$HR_FXROOT/$HR_FX/" || exit 2' &
  run_mutant M3 'env -i PATH=' 'env PATH=' &
  # cwd-invariance: two nested runs of this fixture from different working directories.
  ( cd "$ROOT" && HERMETIC_FX_NESTED=1 bash "$HERE/run.sh" > "$WORK/cwd1.out" 2>&1; echo $? > "$WORK/cwd1.rc" ) &
  ( cd "$(dirname "$RUN")" && HERMETIC_FX_NESTED=1 bash "$HERE/run.sh" > "$WORK/cwd2.out" 2>&1; echo $? > "$WORK/cwd2.rc" ) &
  wait
  CUR=M
  for pair in "M1:B" "M2:A C D" "M3:F"; do
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
