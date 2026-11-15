#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# THE OTHER TOP-OF-HOOK SPANS. Arms S1-S2 hold the SIGPIPE span (BL-999) in both hooks and core/scripts/hermetic-run.sh,
# and D1-D4 the PUSH_DELETE span (BL-1010) in both hooks: D3 drives each REAL hook end to end on a delete-only push,
# D4 cuts each hook at its gate and requires an update and a mixed push to pass it.
#
# DIST-ONLY: the subject is `.githooks/pre-push`, which install.sh never ships.
#
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_SSH_COMMAND GIT_SSH

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$(cd "$HERE/../../.." && pwd)/.githooks/pre-push"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
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
printf '#!/bin/bash\nexec "%s" -F "%s" "$@"\n' "$SSH_BIN" "$BAD_CFG" > "$WRAPBIN/ssh"
printf '#!/bin/bash\nexec "%s" -F "%s" "$@"\n' "$SSH_BIN" "$BAD_CFG" > "$WRAPBIN/myssh-wrapper"
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

# ------------------------------------------------- the other top-of-hook spans: SIGPIPE (BL-999), PUSH_DELETE (BL-1010) --
# Both sit above the first step of BOTH pre-push hooks, as this file's block does, so they are held here. CHOOK is the
# consumer hook as it sits in this repo; HRUN is the sandbox runner, the third carrier of the SIGPIPE span. Every arm
# below asserts a value in both directions; none is satisfied by a span or a hook that emits nothing.
CHOOK="$(cd "$HERE/../.." && pwd)/git-hooks/pre-push"
HRUN="$(cd "$HERE/../.." && pwd)/scripts/hermetic-run.sh"
[ -f "$CHOOK" ] || broken "no core/git-hooks/pre-push at $CHOOK"
[ -f "$HRUN" ] || broken "no core/scripts/hermetic-run.sh at $HRUN"
PERL_BIN="$(command -v perl 2>/dev/null)" || PERL_BIN=""
[ -n "$PERL_BIN" ] || broken "no perl on PATH: the SIGPIPE arms need it to start a bash with SIGPIPE at its DEFAULT"
span() { sed -n "/^# $1_BEGIN\$/,/^# $1_END\$/p" "$2"; }

# S1. The SIGPIPE span is one span: byte-identical in the three carriers, and it carries exactly one ignore line.
span SIGPIPE "$HOOK" > "$WORK/sp.d"; span SIGPIPE "$CHOOK" > "$WORK/sp.c"; span SIGPIPE "$HRUN" > "$WORK/sp.h"
n_ign="$(grep -c "^trap '' PIPE\$" "$WORK/sp.d")" || n_ign=0
if [ "$n_ign" -eq 1 ] && cmp -s "$WORK/sp.d" "$WORK/sp.c" && cmp -s "$WORK/sp.d" "$WORK/sp.h"; then
  ok "S1 the SIGPIPE span is byte-identical in both hooks and hermetic-run.sh, with one \`trap '' PIPE\` line"
else
  bad "S1 SIGPIPE span: ignore lines=$n_ign, hook/consumer equal=$(cmp -s "$WORK/sp.d" "$WORK/sp.c" && echo y || echo n), hook/runner equal=$(cmp -s "$WORK/sp.d" "$WORK/sp.h" && echo y || echo n)"
fi
# S2. The span gives a child writer git's disposition when the caller's is the DEFAULT. perl resets SIGPIPE to the
# default before it execs bash, so both sides are forced whatever this fixture inherited (a push runs it with SIGPIPE
# ignored, a hand run with the default). The writer is `yes` into `head -1`: killed (141) under the default, an EPIPE
# exit under the ignore. The control, the same probe without the span, must read 141, or the probe cannot discriminate.
PROBE="yes | head -1 >/dev/null; echo \"w=\${PIPESTATUS[0]}\""
{ cat "$WORK/sp.d"; printf '%s\n' "$PROBE"; } > "$WORK/sp.with.sh"
printf '%s\n' "$PROBE" > "$WORK/sp.without.sh"
w_ctl="$("$PERL_BIN" -e '$SIG{PIPE} = "DEFAULT"; exec @ARGV' "$BASH_BIN" "$WORK/sp.without.sh" 2>/dev/null)"
w_sub="$("$PERL_BIN" -e '$SIG{PIPE} = "DEFAULT"; exec @ARGV' "$BASH_BIN" "$WORK/sp.with.sh" 2>/dev/null)"
if [ "$w_ctl" != "w=141" ]; then
  broken "S2 control: the probe without the span read [$w_ctl], not w=141, so SIGPIPE was not at its default and the arm cannot discriminate"
elif [ -n "$w_sub" ] && [ "$w_sub" != "w=141" ] && [ "$w_sub" != "w=" ]; then
  ok "S2 under a default SIGPIPE the span makes the writer exit on EPIPE ($w_sub) where the control dies of SIGPIPE (w=141)"
else
  bad "S2 the span did not ignore SIGPIPE for its children: the writer read [$w_sub], the control w=141"
fi

# D1. The PUSH_DELETE span is one span: byte-identical in both hooks and defining push_delete_only.
span PUSH_DELETE "$HOOK" > "$WORK/pd.d"; span PUSH_DELETE "$CHOOK" > "$WORK/pd.c"
n_def="$(grep -c '^push_delete_only() ' "$WORK/pd.d")" || n_def=0
if [ "$n_def" -eq 1 ] && cmp -s "$WORK/pd.d" "$WORK/pd.c"; then
  ok "D1 the PUSH_DELETE span is byte-identical in both hooks and defines push_delete_only once"
else
  bad "D1 PUSH_DELETE span: definitions=$n_def, hooks equal=$(cmp -s "$WORK/pd.d" "$WORK/pd.c" && echo y || echo n)"
fi
# D2. The predicate on the five shapes git can hand a hook: a delete (sha1 and sha256 widths) is a delete; a new branch
# (all-zero REMOTE sha, the near-miss carrying zeros in the wrong field), a delete beside an update, and an empty
# stdin are not. One bash start reads all five; the answer is a string, so a predicate that answers one way for
# every input cannot produce it.
Z40=0000000000000000000000000000000000000000
Z64=0000000000000000000000000000000000000000000000000000000000000000
H40=1111111111111111111111111111111111111111
{ cat "$WORK/pd.d"
  printf 'v=""\n'
  printf 'push_delete_only "(delete) %s refs/heads/x %s" && v="${v}T" || v="${v}F"\n' "$Z40" "$H40"
  printf 'push_delete_only "(delete) %s refs/heads/x %s" && v="${v}T" || v="${v}F"\n' "$Z64" "$H40"
  printf 'push_delete_only "refs/heads/x %s refs/heads/x %s" && v="${v}T" || v="${v}F"\n' "$H40" "$Z40"
  printf 'push_delete_only "(delete) %s refs/heads/x %s\nrefs/heads/y %s refs/heads/y %s" && v="${v}T" || v="${v}F"\n' "$Z40" "$H40" "$H40" "$H40"
  printf 'push_delete_only "" && v="${v}T" || v="${v}F"\n'
  printf 'echo "$v"\n'; } > "$WORK/pd.cells.sh"
pd_got="$("$BASH_BIN" "$WORK/pd.cells.sh" 2>&1)"
if [ "$pd_got" = TTFFF ]; then
  ok "D2 push_delete_only: delete40 T, delete64 T, new branch F, delete+update F, empty F"
else
  bad "D2 push_delete_only answered [$pd_got] for delete40/delete64/new-branch/mixed/empty, want TTFFF"
fi
# D3. The REAL hooks, end to end, handed a delete-only push the way git hands it (two arguments, the ref line on stdin),
# from a scratch repository: exit 0 and exactly the one line saying no step runs. A hook that lost the early exit runs
# its steps and prints more; one that lost the stdin read prints nothing of the kind.
REPO_DEL="$WORK/del"; git init -q "$REPO_DEL" || broken "git init failed"
for hk in "$HOOK" "$CHOOK"; do
  out="$WORK/del.$(basename "$(dirname "$hk")")"
  printf '(delete) %s refs/heads/gone %s\n' "$Z40" "$H40" \
    | ( cd "$REPO_DEL" && env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
          AI_DLC_READSET_LIVE_TRACE=0 "$BASH_BIN" "$hk" origin "file:///nowhere/x.git" ) > "$out" 2>&1
  r=$?
  case "$hk" in "$HOOK") want='pre-push: every ref in this push is a delete (all-zero local sha): no tree is delivered, so no step runs.' ;;
                *) want='pre-push: every ref in this push is a delete (all-zero local sha): no tree is delivered, so no later step runs.' ;; esac
  if [ "$r" -eq 0 ] && [ "$(cat "$out")" = "$want" ]; then
    ok "D3 ${hk#"$(cd "$HERE/../../.." && pwd)/"} on a delete-only push: exit 0 and only the no-step line"
  else
    bad "D3 ${hk#"$(cd "$HERE/../../.." && pwd)/"} on a delete-only push: rc=$r [$(head -c 300 "$out")]"
  fi
done
# D4. D3's ALLOW twin, through each hook's OWN bytes: line 1 through the gate's closing `fi` (the first `fi` at column 0
# after the PUSH_DELETE_END line), with one marker line appended. An update push and a mixed push must reach the marker;
# the delete must not. A call site that exits on every push passes D1-D3 and fails here.
for hk in "$HOOK" "$CHOOK"; do
  tag="$(basename "$(dirname "$hk")")"; pre="$WORK/gate.$tag.sh"
  awk '{ print } $0 == "# PUSH_DELETE_END" { s = 1 } s && $0 == "fi" { f = 1; exit } END { exit (f ? 0 : 1) }' "$hk" > "$pre" \
    || broken "D4: no column-0 \`fi\` after PUSH_DELETE_END in $hk, so the gate cannot be cut out"
  printf 'echo PAST-THE-GATE\n' >> "$pre"
  d4=""
  for ln in "refs/heads/x $H40 refs/heads/x $Z40" "(delete) $Z40 refs/heads/y $H40
refs/heads/x $H40 refs/heads/x $H40" "(delete) $Z40 refs/heads/y $H40"; do
    o="$(printf '%s\n' "$ln" | ( cd "$REPO_DEL" && env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE GIT_CONFIG_GLOBAL=/dev/null \
          GIT_CONFIG_NOSYSTEM=1 "$BASH_BIN" "$pre" origin "file:///nowhere/x.git" ) 2>&1)"; r=$?
    case "$r:$o" in 0:PAST-THE-GATE) d4="${d4}P" ;; "0:pre-push: every ref"*) d4="${d4}D" ;; *) d4="${d4}?" ;; esac
  done
  if [ "$d4" = PPD ]; then ok "D4 $tag cut at its gate: an update and a mixed push pass it, a delete stops at it"
  else bad "D4 $tag cut at its gate answered [$d4] for update/mixed/delete, want PPD"; fi
done


report_end prepush-ssh-keepalive
