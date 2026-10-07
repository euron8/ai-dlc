#!/usr/bin/env bash
# reconcile-region: exempt — step 2's push. It publishes the self-update branch and its exit decides that cycle's disposition; it renders no finding the operator reads before approving apply.
#
# self-update-push.sh — push step 2's self-update branch, running the consumer's pre-push hook
# EXACTLY ONCE, on the tree and with the hook actually being pushed.
#
# WHY THIS EXISTS. `self-update-gate.sh` used to run the consumer's whole pre-push hook on the tree
# as the operator left it, to catch a push refusal that predates the pull, and step 2's bare
# `git push` then ran the hook again on the WRITTEN tree with the INCOMING hook. Two whole-suite
# runs per self-update, and the first measured the wrong hook on the wrong tree (measured on the
# reference consumer: about 22 minutes for the gate's run alone). Here the hook runs once, and it
# is the run the push would have made.
#
# WHY NOT A PLAIN `git push` CLASSIFIED BY ITS OUTPUT. A refusal by the pre-push hook and a
# rejection by the remote both exit 1 with the same stderr shape, and they need DIFFERENT
# dispositions: a hook refusal is the consumer's own gate refusing this tree (DEFER, the slice goes
# to the gated apply), a transport failure is environmental (UN-SYNCED, re-derive next time). So
# this script runs the hook itself, as git would, and pushes with `--no-verify` ONLY after that one
# run exited 0. `--no-verify` here is not a bypass: the hook it skips is the one that already ran.
#
# Usage:  self-update-push.sh <consumer-root> <remote> <branch> <out>
#   <branch>  the self-update branch, which must be the CHECKED-OUT branch (exit 2 otherwise).
#   <out>     consumer-relative or absolute path of a NEW, untracked file, by convention
#             `_bmad-output/ai-dlc-update/self-update-push-<ts>.md`. Written ONLY on HOOK-REFUSED,
#             and only AFTER the hook ran: an untracked file on disk while the hook runs is a
#             changed path in no fixture's read-set, which defeats a hook's read-set skip. This
#             script never writes a tracked path.
#
# Exit:   0  pushed. The hook ran once and exited 0 (or git runs no hook here), then the push
#            succeeded. That holds when the push url already holds the local sha too: the hook
#            still ran once, on an empty stdin, as git runs it.
#         2  usage or REFUSAL before anything ran: wrong argc, a consumer that is not the top of
#            its own work tree (a subdirectory of an enclosing repository would run THAT
#            repository's hook), an unknown remote, a remote with more than one push url,
#            <branch> not checked out or not a commit, <out> already present or tracked, or the
#            scratch area could not be staged — in all of these nothing ran. Also exit 2 AFTER
#            the hook when the hook moved <branch>. Nothing was pushed in any exit-2 case. A
#            `self-update-push: REFUSED —` line on stderr.
#         3  HOOK-REFUSED. The hook ran once and exited non-zero; NOTHING was pushed. One stdout
#            line `HOOK-REFUSED <rc> <phases>`, and <out> carries `# probe:` lines: the hook,
#            its exit and the ref line it was fed, then the last 60 lines of its output.
#         4  TRANSPORT. The push failed after the hook passed, or the PUSH url could not be read
#            for the ref line. One stdout line `TRANSPORT <rc>`. A push url that cannot be reached
#            is TRANSPORT WITHOUT running the hook, which is what `git push` itself does: it
#            connects before it runs the hook. The FETCH url is never contacted, so an
#            unreachable fetch url beside a valid pushurl pushes, as git does.
#
# THE HOOK IS RUN AS GIT RUNS IT.
#   * Which hook: `git rev-parse --git-path hooks/pre-push`, git's own answer, honouring
#     `core.hooksPath` and a `.git/hooks/` shim. Absent or not executable: git skips it, so this
#     script runs no hook and makes the same pinned push described below.
#   * argv: `$1` the remote NAME, `$2` its PUSH url (`git remote get-url --push`, so a
#     `remote.<r>.pushurl` is what the hook sees, as on a real push).
#   * stdin: the ref line git sends, built here from the branch actually pushed —
#     `refs/heads/<b> <local sha> refs/heads/<b> <remote sha>` — the remote sha read with
#     `git ls-remote` against the PUSH url — never the remote name, which resolves to the FETCH
#     url and answers about a different repository when `remote.<r>.pushurl` is set — matched on
#     the full ref name (its pattern tail-matches), zeros when the remote lacks the branch. Stdin
#     is a FILE.
#   * cwd: the work tree's top. SIGPIPE ignored, because `git push` runs hooks with SIGPIPE
#     ignored; a hook whose pipeline is cut short (`yes | head -1`) sees EPIPE, not a 141.
#   * The environment is left as the caller's, including the hook's detached read-set trace
#     knob AI_DLC_READSET_LIVE_TRACE: this IS the push's own run of the hook.
# If the push url already holds the local sha, git STILL runs the pre-push hook, with an EMPTY
# stdin, and a refusal there still blocks the push. This script does the same: the hook runs once
# on an empty stdin file, and the HOOK-REFUSED / `--no-verify` paths below are unchanged.
#
# THE PUSH IS PINNED: the ref line the hook judges and the push that goes out must be the SAME
# object, so the push is defined here exactly — one ref, one url, no tags, a fixed sha — and git's
# configuration gets no say in what is sent. Three rules follow.
#   * `git push --no-verify --no-follow-tags <remote> <sha>:refs/heads/<b>`, the sha read BEFORE
#     the hook. An explicit refspec overrides `remote.<r>.push` and `push.default`, and
#     `--no-follow-tags` overrides `push.followTags`, so neither can push a ref the hook was never
#     shown. The upstream is then set with `git branch --set-upstream-to`; if that alone fails the
#     push still landed, so it is reported on stderr and the exit stays 0.
#   * A hook that MOVES <branch> (commits, resets) is refused, exit 2, nothing pushed: the hook
#     judged the sha it was fed, and pushing either that sha or the new one would publish a branch
#     that disagrees with the tree the operator now holds.
#   * A remote with MORE THAN ONE push url is refused, exit 2, BEFORE the hook runs: git runs the
#     hook once per url, and one pinned push to one url cannot reproduce that.
#
# bash 3.2 and `set -u` safe: no arrays, no here-strings, no heredocs, no pipeline feeding `while`.

set -uo pipefail

refuse() {
  printf 'self-update-push: REFUSED — %s\n' "$1" >&2
  exit 2
}

[ "$#" -eq 4 ] || refuse "usage: self-update-push.sh <consumer-root> <remote> <branch> <out>"
CONSUMER="$1"; REMOTE="$2"; BRANCH="$3"; OUT="$4"
[ -n "$CONSUMER" ] && [ -n "$REMOTE" ] && [ -n "$BRANCH" ] && [ -n "$OUT" ] \
  || refuse "every argument must be non-empty"
[ -d "$CONSUMER" ] || refuse "consumer root $CONSUMER is not a directory"
git -C "$CONSUMER" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || refuse "consumer root $CONSUMER is not a git work tree; there is nothing to push"
SU_PREFIX="$(git -C "$CONSUMER" rev-parse --show-prefix 2>/dev/null)" \
  || refuse "git could not report the consumer's position in its work tree"
[ -z "$SU_PREFIX" ] \
  || refuse "consumer $CONSUMER is a subdirectory ($SU_PREFIX) of an enclosing repository; a push from here runs that repository's hook. AI/DLC installs at a repository's top."
ROOT="$(git -C "$CONSUMER" rev-parse --show-toplevel 2>/dev/null)" && [ -n "$ROOT" ] \
  || refuse "git could not resolve the consumer's work-tree top"

git -C "$ROOT" remote get-url "$REMOTE" >/dev/null 2>&1 || refuse "no remote named '$REMOTE' on this consumer"
URLS="$(git -C "$ROOT" remote get-url --push --all "$REMOTE" 2>/dev/null)" && [ -n "$URLS" ] \
  || refuse "the push url of remote '$REMOTE' could not be read"
su_n="$(printf '%s\n' "$URLS" | grep -c .)" || su_n=0
[ "$su_n" -eq 1 ] \
  || refuse "remote '$REMOTE' has $su_n push urls ($(printf '%s\n' "$URLS" | tr '\n' ' ' | sed 's/ $//')); git would run the hook once per url and this wrapper pushes to exactly one. Give the remote a single push url, then re-run."
URL="$URLS"

SU_HEAD="$(git -C "$ROOT" symbolic-ref -q HEAD 2>/dev/null)" || SU_HEAD=""
[ "$SU_HEAD" = "refs/heads/$BRANCH" ] \
  || refuse "'$BRANCH' is not the checked-out branch (HEAD is ${SU_HEAD:-detached}); step 2 pushes the branch it just committed on"
LOCAL_SHA="$(git -C "$ROOT" rev-parse -q --verify "refs/heads/${BRANCH}^{commit}" 2>/dev/null)" && [ -n "$LOCAL_SHA" ] \
  || refuse "refs/heads/$BRANCH does not resolve to a commit"

case "$OUT" in
  /*) OUT_ABS="$OUT" ;;
  *)  OUT_ABS="$ROOT/$OUT" ;;
esac
[ ! -e "$OUT_ABS" ] || refuse "$OUT already exists; this script writes a NEW record and never over another"
if git -C "$ROOT" ls-files --error-unmatch -- "$OUT_ABS" >/dev/null 2>&1; then
  refuse "$OUT is a tracked path; this script never writes one"
fi

ZERO=0000000000000000000000000000000000000000

# pinned_push — the ONE push this script makes: LOCAL_SHA to refs/heads/<b> on <remote>, no tags,
# no configured refspec, no hook (it already ran, or git would run none). git's own output goes to
# stderr; stdout carries only this script's status lines. Exits the script.
pinned_push() {
  git -C "$ROOT" push --no-verify --no-follow-tags "$REMOTE" "$LOCAL_SHA:refs/heads/$BRANCH" >&2
  su_rc=$?
  if [ "$su_rc" -ne 0 ]; then
    printf 'TRANSPORT %s\n' "$su_rc"
    exit 4
  fi
  if ! git -C "$ROOT" branch --set-upstream-to="$REMOTE/$BRANCH" "$BRANCH" >&2; then
    printf 'self-update-push: pushed %s to %s, but its upstream could not be set to %s/%s; the push landed.\n' "$LOCAL_SHA" "refs/heads/$BRANCH" "$REMOTE" "$BRANCH" >&2
  fi
  exit 0
}

# THE HOOK GIT WOULD RUN. Resolved from the work-tree top, so a relative answer is relative to it.
HOOK="$(cd "$ROOT" && git rev-parse --git-path hooks/pre-push 2>/dev/null)" || HOOK=""
case "$HOOK" in
  ""|/*) ;;
  *) HOOK="$ROOT/$HOOK" ;;
esac

if [ -z "$HOOK" ] || [ ! -x "$HOOK" ]; then
  printf 'self-update-push: git runs no pre-push hook here (%s is absent or not executable); pushing.\n' "${HOOK:-unresolvable}" >&2
  pinned_push
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/self-update-push-XXXXXX" 2>/dev/null)" && [ -n "$TMP" ] && [ -d "$TMP" ] \
  || refuse "a scratch directory could not be created"
trap '[ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"' EXIT

# THE REMOTE SIDE OF THE REF LINE, read from the PUSH url: that is the repository the push writes,
# and with `remote.<r>.pushurl` set the remote NAME would answer for the fetch url instead.
# `ls-remote` exits 0 with no output when the branch is absent, and non-zero when the push url
# cannot be read; only the second is TRANSPORT.
git -C "$ROOT" ls-remote "$URL" "refs/heads/$BRANCH" > "$TMP/ls-remote" 2> "$TMP/ls-remote.err"
su_rc=$?
if [ "$su_rc" -ne 0 ]; then
  cat "$TMP/ls-remote.err" >&2
  printf 'self-update-push: the push url could not be read (git ls-remote exited %s); git push would fail before its hook ran.\n' "$su_rc" >&2
  printf 'TRANSPORT %s\n' "$su_rc"
  exit 4
fi
REMOTE_SHA="$(awk -F'\t' -v r="refs/heads/$BRANCH" '$2 == r {print $1; exit}' "$TMP/ls-remote")" \
  || refuse "the ls-remote answer could not be read"
[ -n "$REMOTE_SHA" ] || REMOTE_SHA="$ZERO"

# UP TO DATE IS NOT EXEMPT: git sends no ref line but still runs the hook, on an empty stdin.
if [ "$REMOTE_SHA" = "$LOCAL_SHA" ]; then
  : > "$TMP/refline" || refuse "the empty ref line could not be staged"
else
  printf 'refs/heads/%s %s refs/heads/%s %s\n' "$BRANCH" "$LOCAL_SHA" "$BRANCH" "$REMOTE_SHA" > "$TMP/refline" \
    || refuse "the ref line could not be staged"
fi

printf 'self-update-push: running the pre-push hook git would run (%s), once; this is the consumer'\''s own gate and can take minutes\n' "$HOOK" >&2
( trap '' PIPE; cd "$ROOT" && exec "$HOOK" "$REMOTE" "$URL" < "$TMP/refline" ) > "$TMP/hook.out" 2>&1
HOOK_RC=$?
cat "$TMP/hook.out" >&2

if [ "$HOOK_RC" -ne 0 ]; then
  # WHICH PHASES REFUSED, from the shipped hook's own output grammar — a `── <phase>` header
  # followed by `   FAIL` — falling back to the last non-blank line for a hook that speaks
  # differently. `sub()` rather than a byte offset: the header's dash is multibyte.
  su_why="$(awk '/^── /{h=$0; sub(/^── /, "", h)} /^   FAIL/{printf "%s; ", h}' "$TMP/hook.out" 2>/dev/null | sed 's/; $//')" || su_why=""
  [ -n "$su_why" ] || su_why="$(grep -v '^[[:space:]]*$' "$TMP/hook.out" 2>/dev/null | tail -1 | tr '\t' ' ')" || su_why=""
  su_w=0
  mkdir -p "$(dirname "$OUT_ABS")" 2>/dev/null || su_w=1
  if [ "$su_w" -eq 0 ]; then
    {
      printf '# ai-dlc-update step-2 self-update — push wrapper record (HOOK-REFUSED; nothing was pushed)\n'
      printf '# probe: %s exit %s, fed: %s\n' "$HOOK" "$HOOK_RC" "$(cat "$TMP/refline")"
      tail -n 60 "$TMP/hook.out" | tr '\t' ' ' | sed 's/^/# probe: /'
    } > "$OUT_ABS" 2>/dev/null || su_w=1
  fi
  [ "$su_w" -eq 0 ] || printf 'self-update-push: the record %s could not be written; the hook output is above.\n' "$OUT" >&2
  printf 'HOOK-REFUSED %s %s\n' "$HOOK_RC" "${su_why:-<no output>}"
  exit 3
fi

# THE HOOK MUST NOT HAVE MOVED THE BRANCH: it judged LOCAL_SHA, and that is all this may push.
su_after="$(git -C "$ROOT" rev-parse -q --verify "refs/heads/${BRANCH}^{commit}" 2>/dev/null)" || su_after=""
[ "$su_after" = "$LOCAL_SHA" ] \
  || refuse "the pre-push hook moved $BRANCH (from $LOCAL_SHA to ${su_after:-<unresolvable>}); it judged the first and this wrapper pushes nothing it did not judge. Nothing was pushed."

pinned_push
