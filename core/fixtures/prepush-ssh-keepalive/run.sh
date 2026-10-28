#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# prepush-ssh-keepalive — the distribution pre-push hook WARNS when the push remote's
# effective ssh config carries no keepalive, and stays silent when it does.
#
# THE SUBJECT. `git push` opens the SSH connection before the hook runs, the suite idles
# it for minutes, GitHub drops it, and the pack write takes SIGPIPE: exit 141, every gate
# green, the ref absent on origin. The measured cure is `ServerAliveInterval` on the
# remote's ssh alias. The hook's KEEPALIVE block reads the value through the ssh command
# git will actually run and prints one warning line when it is 0. This drives that block.
#
# WHAT IT DRIVES. The block between `# KEEPALIVE_BEGIN` and `# KEEPALIVE_END`, extracted
# from the shipping hook and run with the two arguments git hands a pre-push hook. Not the
# whole hook: that would run the whole suite. So the extraction is itself guarded — it
# must be non-empty against an impossible-sentinel control that is empty, the block must
# sit ABOVE the first `step` (so it runs before the long idle, at top level), and its
# invocation line must be at column 0 inside it (a block wrapped in a never-called
# function would extract and pass while never executing in the hook).
#
# HERMETICITY. Nothing here reads the operator's `~/.ssh/config`. Every drive points ssh
# at a seeded config with `-F`, through the same channels git uses: GIT_SSH_COMMAND,
# core.sshCommand, GIT_SSH, and a PATH `ssh` that is a wrapper. Global and system git
# config are switched off so an operator's core.sshCommand cannot answer for a seed.
#
# DIST-ONLY: the subject is `.githooks/pre-push`, which install.sh never ships.
#
# THE MUTANT MATRIX. A cell is one drive of the block (A1-A5 must warn, N1-N5 must stay silent, N6a must stay
# silent and its twin N6b must warn), RED on a mutant when the mutated block's output differs from what the
# unmutated block gives that drive. A mutant's row names the cell that kills it (decides) and the cell it could
# plausibly co-trip but must leave GREEN (twins). A plain run drives each mutant on its deciding cell and its twin
# cell only. The matrix is re-measured whenever an arm or a mutant is added or changed, by the REMEASURE command
# below, run from the repo root. It drives every mutant on every cell and prints one MATRIX line each.
# MUTANT-MATRIX M1 decides=A1 twins=N1
# MUTANT-MATRIX M2 decides=N3 twins=A2
# MUTANT-MATRIX M3 decides=N1 twins=A1
# MUTANT-MATRIX M4 decides=N5 twins=N1
# MUTANT-MATRIX-REMEASURE bash core/fixtures/prepush-ssh-keepalive/run.sh --matrix
set -uo pipefail
# MODE is "matrix" only under the positional `--matrix`; an AI_DLC_* name would be scrubbed below. Anything else
# as an argument is a usage error, never a silent plain run.
MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "prepush-ssh-keepalive: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_SSH_COMMAND GIT_SSH

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF_FILE="$HERE/$(basename "$0")"
HOOK="$(cd "$HERE/../../.." && pwd)/.githooks/pre-push"

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "prepush-ssh-keepalive: FIXTURE BROKEN" >&2; exit 2; }
# The shared mutant-kill helper: a kill is emitted only through mutant_killed, behind a same-run base-pass flag.
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || broken "no lib/mutant.sh beside $HERE"
. "$MUT_LIB"

echo "prepush-ssh-keepalive:"
[ -f "$HOOK" ] || broken "no .githooks/pre-push at $HOOK"
printf '  ..    RESOLVED %s\n' "$HOOK"

SSH_BIN="$(command -v ssh 2>/dev/null)" || SSH_BIN=""
[ -n "$SSH_BIN" ] || broken "no ssh on PATH — the block's only subject is ssh -G, so nothing here could fire"
BASH_BIN="$(command -v bash)"
SH_BIN="$(command -v sh)"
GIT_BIN="$(command -v git)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/prepush-ssh-keepalive.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- the extraction --
BLOCK="$WORK/block.sh"
sed -n '/^# KEEPALIVE_BEGIN$/,/^# KEEPALIVE_END$/p' "$HOOK" > "$BLOCK"
n_block="$(grep -c . "$BLOCK")" || n_block=0
n_ctl="$(sed -n '/^# KEEPALIVE_ZZQ_NEVER_BEGIN$/,/^# KEEPALIVE_ZZQ_NEVER_END$/p' "$HOOK" | grep -c .)" || n_ctl=0
if [ "$n_block" -gt 0 ] && [ "$n_ctl" -eq 0 ]; then
  ok "the KEEPALIVE block extracts ($n_block lines) and an impossible sentinel extracts 0"
else
  broken "extraction: block=$n_block lines, impossible-sentinel control=$n_ctl — the sentinels moved or the control is not impossible"
fi

l_begin="$(grep -n '^# KEEPALIVE_BEGIN$' "$HOOK" | head -1 | cut -d: -f1)"
l_step="$(grep -n '^step ' "$HOOK" | head -1 | cut -d: -f1)"
if [ -n "$l_begin" ] && [ -n "$l_step" ] && [ "$l_begin" -lt "$l_step" ]; then
  ok "the block (line $l_begin) sits above the first step (line $l_step), so it prints before the suite idles the connection"
else
  bad "the block is at line ${l_begin:-?}, the first step at line ${l_step:-?} — a warning printed after the suite is printed after the drop"
fi
n_call="$(grep -c '^ssh_keepalive_warn "\${1:-}" "\${2:-}"$' "$BLOCK")" || n_call=0
if [ "$n_call" -eq 1 ]; then
  ok "the block invokes itself once at top level with \${1:-}/\${2:-} (safe under set -u when a fixture runs the hook with no args)"
else
  bad "expected exactly one top-level invocation line in the block, found $n_call"
fi

# ---------------------------------------------------------------- the seeds --
BAD_CFG="$WORK/bad.cfg"      # no keepalive anywhere
GOOD_CFG="$WORK/good.cfg"    # keepalive on the alias
: > "$BAD_CFG"
printf 'Host keepalive-probe-alias\n  ServerAliveInterval 60\n  ServerAliveCountMax 30\n' > "$GOOD_CFG"

# A PATH `ssh` that is a wrapper pinned to the bad config — how the DEFAULT branch
# (no GIT_SSH_COMMAND, no core.sshCommand, no GIT_SSH) is driven without reading ~/.ssh.
WRAPBIN="$WORK/wrapbin"; mkdir -p "$WRAPBIN"
printf '#!/bin/sh\nexec "%s" -F "%s" "$@"\n' "$SSH_BIN" "$BAD_CFG" > "$WRAPBIN/ssh"
printf '#!/bin/sh\nexec "%s" -F "%s" "$@"\n' "$SSH_BIN" "$BAD_CFG" > "$WRAPBIN/myssh-wrapper"
chmod +x "$WRAPBIN/ssh" "$WRAPBIN/myssh-wrapper"

# A PATH with bash and sh and NO ssh, plus its twin that differs by one ssh symlink.
NOSSH="$WORK/nossh"; WITHSSH="$WORK/withssh"; mkdir -p "$NOSSH" "$WITHSSH"
for d in "$NOSSH" "$WITHSSH"; do ln -s "$BASH_BIN" "$d/bash"; ln -s "$SH_BIN" "$d/sh"; ln -s "$GIT_BIN" "$d/git"; done
ln -s "$SSH_BIN" "$WITHSSH/ssh"

# A scratch repository with no core.sshCommand, and one with it.
REPO_PLAIN="$WORK/plain"; REPO_CORE="$WORK/core"
git init -q "$REPO_PLAIN" || broken "git init failed"
git init -q "$REPO_CORE"  || broken "git init failed"
[ -d "$REPO_PLAIN/.git" ] && [ -d "$REPO_CORE/.git" ] || broken "scratch repositories were not created"
git -C "$REPO_CORE" config core.sshCommand "ssh -F $BAD_CFG"

SCP_URL="git@keepalive-probe-alias:owner/repo.git"
SSHURL="ssh://git@keepalive-probe-alias:2222/owner/repo.git"
HTTPS_URL="https://keepalive-probe-alias/owner/repo.git"

# drive <block> <repo> <out> [VAR=val ...] -- <args...>
# Runs the block with global/system git config off and a controlled environment. The
# exit code goes to <out>.rc and stdout+stderr to <out>.
drive() {
  local blk="$1" repo="$2" out="$3"; shift 3
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != -- ]; do envs+=("$1"); shift; done
  [ "$#" -gt 0 ] && shift
  ( cd "$repo" && env -u GIT_SSH_COMMAND -u GIT_SSH GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
      ${envs[@]+"${envs[@]}"} "$BASH_BIN" "$blk" "$@" ) </dev/null > "$out" 2>&1
  echo $? > "$out.rc"
}
fired()  { grep -q 'pre-push: WARNING -- ssh host alias "keepalive-probe-alias" has no keepalive' "$1"; }
silent() { [ ! -s "$1" ]; }
rc0()    { [ "$(cat "$1.rc")" = 0 ]; }

expect_fire() { # expect_fire <label> <out>
  if fired "$2" && rc0 "$2"; then
    n="$(grep -c 'ServerAliveInterval 60.*ServerAliveCountMax 30' "$2")" || n=0
    if [ "$n" -eq 1 ]; then ok "$1: ONE warning naming the alias and both settings, exit 0"; return 0
    else bad "$1: warned but the line does not name both settings (matched $n)"; return 1; fi
  else
    bad "$1: expected the warning, got rc=$(cat "$2.rc") [$(head -c 200 "$2")]"; return 1
  fi
}
expect_silent() { # expect_silent <label> <out>
  if silent "$2" && rc0 "$2"; then ok "$1: silent, exit 0"; return 0
  else bad "$1: expected silence, got rc=$(cat "$2.rc") [$(head -c 200 "$2")]"; return 1; fi
}

# ---------------------------------------------------------------- the arms --
P="PATH=/usr/bin:/bin"
drive "$BLOCK" "$REPO_PLAIN" "$WORK/a"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$SCP_URL"
if expect_fire "A1 GIT_SSH_COMMAND, scp-style URL, config without keepalive" "$WORK/a"; then B_a1=1; fi

drive "$BLOCK" "$REPO_PLAIN" "$WORK/b"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$SSHURL"
expect_fire "A2 ssh:// URL with a port, config without keepalive" "$WORK/b"

drive "$BLOCK" "$REPO_CORE"  "$WORK/c"  "$P" -- origin "$SCP_URL"
expect_fire "A3 core.sshCommand branch, config without keepalive" "$WORK/c"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/d"  "$P" "GIT_SSH=$WRAPBIN/ssh" -- origin "$SCP_URL"
expect_fire "A4 GIT_SSH branch (exec'd directly), config without keepalive" "$WORK/d"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/e"  "PATH=$WRAPBIN:/usr/bin:/bin" -- origin "$SCP_URL"
expect_fire "A5 default branch (plain ssh on PATH), config without keepalive" "$WORK/e"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/f"  "$P" "GIT_SSH_COMMAND=ssh -F $GOOD_CFG" -- origin "$SCP_URL"
if expect_silent "N1 config WITH ServerAliveInterval 60 on the alias" "$WORK/f"; then B_n1=1; fi

drive "$BLOCK" "$REPO_PLAIN" "$WORK/g"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG -o ServerAliveInterval=60" -- origin "$SCP_URL"
expect_silent "N2 same bad config, keepalive given by -o on the command (the EFFECTIVE value is read, not the file)" "$WORK/g"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/h"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$HTTPS_URL"
if expect_silent "N3 https URL with the bad config (not an ssh transport)" "$WORK/h"; then B_n3=1; fi

drive "$BLOCK" "$REPO_PLAIN" "$WORK/i"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" --
expect_silent "N4 no arguments (a hand run, or a fixture driving the hook) under set -u" "$WORK/i"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/j"  "PATH=$WRAPBIN:/usr/bin:/bin" "GIT_SSH_COMMAND=myssh-wrapper" -- origin "$SCP_URL"
if expect_silent "N5 a non-ssh command (a wrapper that WOULD report interval 0 if asked)" "$WORK/j"; then B_n5=1; fi

drive "$BLOCK" "$REPO_PLAIN" "$WORK/k"  "PATH=$NOSSH" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$SCP_URL"
drive "$BLOCK" "$REPO_PLAIN" "$WORK/k2" "PATH=$WITHSSH" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$SCP_URL"
if silent "$WORK/k" && rc0 "$WORK/k" && fired "$WORK/k2"; then
  ok "N6 no ssh on PATH: silent, while the twin PATH differing by one ssh symlink fires"
else
  bad "N6 ssh-absent: k rc=$(cat "$WORK/k.rc") [$(head -c 120 "$WORK/k")], twin fired=$(fired "$WORK/k2" && echo y || echo n)"
fi

# ---------------------------------------------------------------- the mutants --
# Each a COPY of the extracted block, guarded by `cmp -s`, driven on the one input its
# deleted property decides, and required to flip it.
mkmut() { # mkmut <name> <awk program>
  awk "$2" "$BLOCK" > "$WORK/$1.sh" || broken "mutant $1: awk failed — DID NOT APPLY"
  cmp -s "$BLOCK" "$WORK/$1.sh" && broken "mutant $1: byte-identical to the block — DID NOT APPLY"
  return 0
}

# --- the matrix cells, single-sourced. cell_set <cell> sets REPO_C, ENVS_C, ARGS_C and WANT_C (fire|silent) for one
# drive of the block. The unmutated arms above state the same inputs inline; a mutant is driven through these.
# Returns 0, or 2 for an UNKNOWN CELL (an unknown name must never read as GREEN).
MX_CELLS='A1 A2 A3 A4 A5 N1 N2 N3 N4 N5 N6a N6b'
cell_set() {
  REPO_C="$REPO_PLAIN"; ENVS_C=("$P"); ARGS_C=(origin "$SCP_URL"); WANT_C=silent
  case "$1" in
    A1)  ENVS_C+=("GIT_SSH_COMMAND=ssh -F $BAD_CFG"); WANT_C=fire ;;
    A2)  ENVS_C+=("GIT_SSH_COMMAND=ssh -F $BAD_CFG"); ARGS_C=(origin "$SSHURL"); WANT_C=fire ;;
    A3)  REPO_C="$REPO_CORE"; WANT_C=fire ;;
    A4)  ENVS_C+=("GIT_SSH=$WRAPBIN/ssh"); WANT_C=fire ;;
    A5)  ENVS_C=("PATH=$WRAPBIN:/usr/bin:/bin"); WANT_C=fire ;;
    N1)  ENVS_C+=("GIT_SSH_COMMAND=ssh -F $GOOD_CFG") ;;
    N2)  ENVS_C+=("GIT_SSH_COMMAND=ssh -F $BAD_CFG -o ServerAliveInterval=60") ;;
    N3)  ENVS_C+=("GIT_SSH_COMMAND=ssh -F $BAD_CFG"); ARGS_C=(origin "$HTTPS_URL") ;;
    N4)  ENVS_C+=("GIT_SSH_COMMAND=ssh -F $BAD_CFG"); ARGS_C=() ;;
    N5)  ENVS_C=("PATH=$WRAPBIN:/usr/bin:/bin" "GIT_SSH_COMMAND=myssh-wrapper") ;;
    N6a) ENVS_C=("PATH=$NOSSH" "GIT_SSH_COMMAND=ssh -F $BAD_CFG") ;;
    N6b) ENVS_C=("PATH=$WITHSSH" "GIT_SSH_COMMAND=ssh -F $BAD_CFG"); WANT_C=fire ;;
    *)   return 2 ;;
  esac
}
# cell_drive <block> <cell> <out>: drive the block on one cell. Returns 2 for an unknown cell.
cell_drive() {
  cell_set "$2" || return 2
  drive "$1" "$REPO_C" "$3" "${ENVS_C[@]}" -- ${ARGS_C[@]+"${ARGS_C[@]}"}
}
# cell_red <cell> <out>: RED when the drive no longer gives what the UNMUTATED block gives that cell.
cell_red() {
  cell_set "$1" || return 2
  if [ "$WANT_C" = fire ]; then ! { fired "$2" && rc0 "$2"; }; else ! { silent "$2" && rc0 "$2"; }; fi
}
# The header IS the decides/twins list: nothing else in this file restates it.
mx_row() { # mx_row <mutant> <decides|twins>
  awk -v n="$1" -v f="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n {
      c++; for (i = 4; i <= NF; i++) if (index($i, f "=") == 1) v = substr($i, length(f) + 2)
    }
    END { if (c == 1) print v }' "$SELF_FILE"
}
MXL="$WORK/mx.ledger"; : > "$MXL"
BROKEN=0; MX_FAILS=0
# mx_twins <mutant> <block>: per-push, the twin cell is driven on the mutated block and must stay GREEN.
mx_twins() {
  local m="$1" blk="$2" tw t r
  tw="$(mx_row "$m" twins)"
  if [ -z "$tw" ]; then BROKEN=$((BROKEN + 1)); printf '  FIXTURE BROKEN %s: no single MUTANT-MATRIX row names its twins\n' "$m"; return; fi
  printf 'plain-twins %s\n' "$m" >> "$MXL"
  for t in $(printf '%s' "$tw" | tr ',' ' '); do
    cell_drive "$blk" "$t" "$WORK/tw.$m.$t"; r=$?
    if [ "$r" -eq 2 ]; then BROKEN=$((BROKEN + 1)); printf '  FIXTURE BROKEN %s: twin %s names no cell\n' "$m" "$t"; continue; fi
    cell_red "$t" "$WORK/tw.$m.$t"; r=$?
    if [ "$r" -eq 0 ]; then bad "$m: its twin $t also changed on this mutant's block, so the kill is not confined to its own cell"; fi
  done
}
# mx_score <mutant> <block>: MATRIX-ONLY. Drives the mutated block on EVERY cell. It records itself in the ledger first (rule 9).
mx_score() {
  local m="$1" blk="$2" dec tw c r crash uex="" dl="" tl="" g=0 tot=0
  printf 'mx-score %s\n' "$m" >> "$MXL"
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  for c in $MX_CELLS; do
    cell_drive "$blk" "$c" "$WORK/mx.$m.$c" || { BROKEN=$((BROKEN + 1)); printf 'MATRIX BROKEN %s\n' "$m"; return; }
    crash="$(grep -E 'unbound variable|command not found|syntax error' "$WORK/mx.$m.$c")" || crash=""
    if [ -n "$crash" ]; then
      BROKEN=$((BROKEN + 1)); printf 'MATRIX BROKEN %s\n' "$m"; return
    fi
    r="$(cat "$WORK/mx.$m.$c.rc")"
    if [ "$r" != 0 ] && [ "$r" != 1 ]; then BROKEN=$((BROKEN + 1)); printf 'MATRIX BROKEN %s\n' "$m"; return; fi
  done
  for c in $(printf '%s' "$dec" | tr ',' ' '); do
    if cell_red "$c" "$WORK/mx.$m.$c"; then dl="$dl,$c:RED"; else dl="$dl,$c:GREEN"; uex="$uex $c:GREEN"; fi
  done
  for c in $(printf '%s' "$tw" | tr ',' ' '); do
    if cell_red "$c" "$WORK/mx.$m.$c"; then tl="$tl,$c:RED"; uex="$uex $c:RED"; else tl="$tl,$c:GREEN"; fi
  done
  for c in $MX_CELLS; do
    case ",$dec,$tw," in *",$c,"*) continue ;; esac
    tot=$((tot + 1)); cell_red "$c" "$WORK/mx.$m.$c" || g=$((g + 1))
  done
  if [ -n "$uex" ]; then
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d UNEXPECTED=%s\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot" "$(printf '%s' "${uex# }" | tr ' ' ',')"
    MX_FAILS=$((MX_FAILS + 1))
  else
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot"
  fi
}

kills=0
mkmut m_nocall '!/^ssh_keepalive_warn "\$\{1:-\}" "\$\{2:-\}"$/'
cell_drive "$WORK/m_nocall.sh" A1 "$WORK/m1"
if fired "$WORK/m1"; then bad "M1 invocation deleted: SURVIVED (A1's input still warned)"; else mutant_killed "${B_a1:-0}" M1 "M1 invocation deleted: KILLED (A1's input goes silent)" && kills=$((kills+1)); fi
mx_twins M1 "$WORK/m_nocall.sh"
[ "$MODE" = matrix ] && mx_score M1 "$WORK/m_nocall.sh"

mkmut m_nourlgate '!/^    \*:\/\/\*\) return 0 ;;$/'
cell_drive "$WORK/m_nourlgate.sh" N3 "$WORK/m2"
if grep -q 'pre-push: WARNING' "$WORK/m2"; then mutant_killed "${B_n3:-0}" M2 "M2 non-ssh URL gate deleted: KILLED (N3's shape now warns)" && kills=$((kills+1)); else bad "M2 non-ssh URL gate deleted: SURVIVED"; fi
mx_twins M2 "$WORK/m_nourlgate.sh"
[ "$MODE" = matrix ] && mx_score M2 "$WORK/m_nourlgate.sh"

mkmut m_novalue '{ if ($0 ~ /^  \[ "\$iv" = 0 \] \|\| return 0$/) print "  :"; else print }'
cell_drive "$WORK/m_novalue.sh" N1 "$WORK/m3"
if fired "$WORK/m3"; then mutant_killed "${B_n1:-0}" M3 "M3 interval test deleted: KILLED (N1's configured alias now warns)" && kills=$((kills+1)); else bad "M3 interval test deleted: SURVIVED"; fi
mx_twins M3 "$WORK/m_novalue.sh"
[ "$MODE" = matrix ] && mx_score M3 "$WORK/m_novalue.sh"

mkmut m_nosshname '!/^  \[ "\$\{first##\*\/\}" = ssh \] \|\| return 0$/'
cell_drive "$WORK/m_nosshname.sh" N5 "$WORK/m4"
if fired "$WORK/m4"; then mutant_killed "${B_n5:-0}" M4 "M4 ssh-basename guard deleted: KILLED (N5's wrapper is now handed -G)" && kills=$((kills+1)); else bad "M4 ssh-basename guard deleted: SURVIVED"; fi
mx_twins M4 "$WORK/m_nosshname.sh"
[ "$MODE" = matrix ] && mx_score M4 "$WORK/m_nosshname.sh"

[ "$kills" -eq 4 ] || bad "kill count $kills of 4"

# RULE 9: a plain run executes NO matrix-only cell. Every matrix-only score appends `mx-score` to the ledger before
# anything else; the per-push twin check appends `plain-twins` to the SAME ledger. That second line is the CONTROL:
# it must be present, so a zero count of matrix-only cells cannot come from a ledger nothing writes.
mx_only="$(grep -c '^mx-score ' "$MXL")" || mx_only=0
mx_ctl="$(grep -c '^plain-twins ' "$MXL")" || mx_ctl=0
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells would mean nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9: a plain run executed $mx_only matrix-only cell(s), so the --matrix measurement leaked into the per-push run"
  else ok "rule-9: a plain run executed no matrix-only cell, while its $mx_ctl per-push twin check(s) wrote to the same ledger"; fi
else
  mx_hdr="$(awk '$1 == "#" && $2 == "MUTANT-MATRIX" { print $3 }' "$SELF_FILE" | LC_ALL=C sort | tr '\n' ' ')"
  [ "$mx_hdr" = "M1 M2 M3 M4 " ] || { BROKEN=$((BROKEN + 1)); echo "MATRIX BROKEN: the header rows are [$mx_hdr]"; }
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran, $mx_ctl per-push twin check(s)"
  fails=$((fails + MX_FAILS))
fi
if [ "$BROKEN" -ne 0 ]; then echo "prepush-ssh-keepalive: FIXTURE BROKEN: $BROKEN mutant arm(s) could not be scored" >&2; exit 2; fi

if [ "$fails" -ne 0 ]; then
  printf 'prepush-ssh-keepalive: FAIL (%s of %s assertions)\n' "$fails" "$asserts"
  exit 1
fi
printf 'prepush-ssh-keepalive: ok (%s assertions)\n' "$asserts"
exit 0
