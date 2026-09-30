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
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_SSH_COMMAND GIT_SSH

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$(cd "$HERE/../../.." && pwd)/.githooks/pre-push"

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "prepush-ssh-keepalive: FIXTURE BROKEN" >&2; exit 2; }

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
    if [ "$n" -eq 1 ]; then ok "$1: ONE warning naming the alias and both settings, exit 0"
    else bad "$1: warned but the line does not name both settings (matched $n)"; fi
  else
    bad "$1: expected the warning, got rc=$(cat "$2.rc") [$(head -c 200 "$2")]"
  fi
}
expect_silent() { # expect_silent <label> <out>
  if silent "$2" && rc0 "$2"; then ok "$1: silent, exit 0"
  else bad "$1: expected silence, got rc=$(cat "$2.rc") [$(head -c 200 "$2")]"; fi
}

# ---------------------------------------------------------------- the arms --
P="PATH=/usr/bin:/bin"
drive "$BLOCK" "$REPO_PLAIN" "$WORK/a"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$SCP_URL"
expect_fire "A1 GIT_SSH_COMMAND, scp-style URL, config without keepalive" "$WORK/a"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/b"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$SSHURL"
expect_fire "A2 ssh:// URL with a port, config without keepalive" "$WORK/b"

drive "$BLOCK" "$REPO_CORE"  "$WORK/c"  "$P" -- origin "$SCP_URL"
expect_fire "A3 core.sshCommand branch, config without keepalive" "$WORK/c"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/d"  "$P" "GIT_SSH=$WRAPBIN/ssh" -- origin "$SCP_URL"
expect_fire "A4 GIT_SSH branch (exec'd directly), config without keepalive" "$WORK/d"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/e"  "PATH=$WRAPBIN:/usr/bin:/bin" -- origin "$SCP_URL"
expect_fire "A5 default branch (plain ssh on PATH), config without keepalive" "$WORK/e"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/f"  "$P" "GIT_SSH_COMMAND=ssh -F $GOOD_CFG" -- origin "$SCP_URL"
expect_silent "N1 config WITH ServerAliveInterval 60 on the alias" "$WORK/f"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/g"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG -o ServerAliveInterval=60" -- origin "$SCP_URL"
expect_silent "N2 same bad config, keepalive given by -o on the command (the EFFECTIVE value is read, not the file)" "$WORK/g"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/h"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$HTTPS_URL"
expect_silent "N3 https URL with the bad config (not an ssh transport)" "$WORK/h"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/i"  "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" --
expect_silent "N4 no arguments (a hand run, or a fixture driving the hook) under set -u" "$WORK/i"

drive "$BLOCK" "$REPO_PLAIN" "$WORK/j"  "PATH=$WRAPBIN:/usr/bin:/bin" "GIT_SSH_COMMAND=myssh-wrapper" -- origin "$SCP_URL"
expect_silent "N5 a non-ssh command (a wrapper that WOULD report interval 0 if asked)" "$WORK/j"

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
kills=0
mkmut m_nocall '!/^ssh_keepalive_warn "\$\{1:-\}" "\$\{2:-\}"$/'
drive "$WORK/m_nocall.sh" "$REPO_PLAIN" "$WORK/m1" "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "$SCP_URL"
if fired "$WORK/m1"; then bad "M1 invocation deleted: SURVIVED (A1's input still warned)"; else ok "M1 invocation deleted: KILLED (A1's input goes silent)"; kills=$((kills+1)); fi

mkmut m_nourlgate '!/^    \*:\/\/\*\) return 0 ;;$/'
drive "$WORK/m_nourlgate.sh" "$REPO_PLAIN" "$WORK/m2" "$P" "GIT_SSH_COMMAND=ssh -F $BAD_CFG" -- origin "https://keepalive-probe-alias/x"
if grep -q 'pre-push: WARNING' "$WORK/m2"; then ok "M2 non-ssh URL gate deleted: KILLED (N3's shape now warns)"; kills=$((kills+1)); else bad "M2 non-ssh URL gate deleted: SURVIVED"; fi

mkmut m_novalue '{ if ($0 ~ /^  \[ "\$iv" = 0 \] \|\| return 0$/) print "  :"; else print }'
drive "$WORK/m_novalue.sh" "$REPO_PLAIN" "$WORK/m3" "$P" "GIT_SSH_COMMAND=ssh -F $GOOD_CFG" -- origin "$SCP_URL"
if fired "$WORK/m3"; then ok "M3 interval test deleted: KILLED (N1's configured alias now warns)"; kills=$((kills+1)); else bad "M3 interval test deleted: SURVIVED"; fi

mkmut m_nosshname '!/^  \[ "\$\{first##\*\/\}" = ssh \] \|\| return 0$/'
drive "$WORK/m_nosshname.sh" "$REPO_PLAIN" "$WORK/m4" "PATH=$WRAPBIN:/usr/bin:/bin" "GIT_SSH_COMMAND=myssh-wrapper" -- origin "$SCP_URL"
if fired "$WORK/m4"; then ok "M4 ssh-basename guard deleted: KILLED (N5's wrapper is now handed -G)"; kills=$((kills+1)); else bad "M4 ssh-basename guard deleted: SURVIVED"; fi

[ "$kills" -eq 4 ] || bad "kill count $kills of 4"

if [ "$fails" -ne 0 ]; then
  printf 'prepush-ssh-keepalive: FAIL (%s of %s assertions)\n' "$fails" "$asserts"
  exit 1
fi
printf 'prepush-ssh-keepalive: ok (%s assertions)\n' "$asserts"
exit 0
