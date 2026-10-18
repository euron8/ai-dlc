#!/usr/bin/env bash
# reconcile-region: exempt — builds the private distribution clone that SKILL.md step 1 reads from; it renders no finding.
# dist-clone.sh -- the update skill's PRIVATE, main-only, bare distribution clone, which is the
# `<dist>` every reconcile script reads.
#
# Usage: dist-clone.sh [--theirs <ref>] <consumer> <upstream> [<ref>...]
#   <consumer>   the consumer repo (any worktree of it)
#   <upstream>   the stamp's `upstream:` (a URL, or a local path as the override)
#   --theirs     the operator's target ref; absent, theirs is the fetched upstream `main`
#   <ref>...     further refs that must resolve in the clone: the stamp's base and skill_commit
# Stdout, on exit 0, exactly two lines:
#   <absolute clone path>
#   theirs <40-hex sha>
# Exit: 0 = the clone is current and every ref resolves; 1 = STOP, one `dist-clone: STOP -- <cause>`
#       line on stderr naming the cause and its remedy; 2 = usage.
#
# WHY IT EXISTS. emit-report.sh's recorded `--verify` PASS keys on the dist's refs. A dist that shares
# its ref store with live branches (the operator's own checkout, a worktree of it) moves those refs
# between any two verifies and never records. This clone carries `main`, the refs a pull names, and
# nothing else, and nothing but this script writes it.
#
# WHAT IT NEVER DOES. It never falls back: no consumer repo, an unwritable git-dir, a clone or fetch
# error, a held lock, a dir that is not this clone, or a ref that does not resolve is a STOP, never
# the upstream path or a shared checkout printed as the dist. It never deletes the clone; a corrupt
# one is remedied by moving it aside, as the STOP says.
#
# THE SHAPE, each clause load-bearing:
#   - BARE (`--bare`): a non-bare clone's fetch into its checked-out main exits 128.
#   - `--single-branch --branch main --no-tags`: main only. Other refs arrive only by name.
#   - NO `--shared`, NO `--reference`, NO `--depth`: alternates let a gc in the upstream delete
#     objects this clone needs, and a shallow clone cannot render retired-fixture history. A local
#     path upstream hardlinks its packs instead (git's implicit --local).
#   - a full sha that is not on main is PINNED at refs/ai-dlc-pin/<sha>, so the clone's own gc
#     keeps it and `log --all` sees it.
#   - every git call on the clone is `--git-dir=`, so `safe.bareRepository=explicit` cannot refuse
#     THIS script; the siblings read `<dist>` with `git -C`, so that setting is a named STOP.
set -uo pipefail

export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=
unset SSH_ASKPASS

stop() { echo "dist-clone: STOP -- $*" >&2; exit 1; }
usage() { echo "usage: dist-clone.sh [--theirs <ref>] <consumer> <upstream> [<ref>...]" >&2; exit 2; }

THEIRS_REF=""
if [ "${1:-}" = "--theirs" ]; then
  [ $# -ge 2 ] && [ -n "$2" ] || usage
  THEIRS_REF="$2"; shift 2
fi
[ $# -ge 2 ] || usage
CONSUMER="$1"; UPSTREAM="$2"; shift 2
[ -n "$CONSUMER" ] && [ -n "$UPSTREAM" ] || usage

# --- where the clone lives: the consumer's COMMON git-dir, shared by its worktrees ----------------
[ -d "$CONSUMER" ] || stop "consumer '$CONSUMER' is not a directory"
COMMON="$(cd "$CONSUMER" 2>/dev/null && c="$(git rev-parse --git-common-dir 2>/dev/null)" && cd "$c" && pwd -P)" \
  || stop "consumer '$CONSUMER' is not a git repository; the clone lives in its git-dir, and there is no fallback"
[ -n "$COMMON" ] && [ -d "$COMMON" ] || stop "could not resolve the git common dir of '$CONSUMER'"
[ -w "$COMMON" ] || stop "the consumer's git-dir '$COMMON' is not writable, so the private clone cannot be built or refreshed; make it writable and re-run (there is no fallback to a shared checkout)"
DIR="$COMMON/ai-dlc-dist"
LOCK="$COMMON/ai-dlc-dist.lock"

# --- origin URL normalisation: trailing '/', trailing '.git', file://, a symlinked or /private path --
norm_url() {
  local u="$1" p
  case "$u" in file://*) u="${u#file://}" ;; esac
  while :; do
    case "$u" in */) u="${u%/}" ;; *) break ;; esac
  done
  if [ -d "$u" ]; then
    p="$(cd "$u" 2>/dev/null && pwd -P)" && u="$p"
  elif [ -d "$u.git" ]; then
    p="$(cd "$u.git" 2>/dev/null && pwd -P)" && u="$p"
  fi
  u="${u%.git}"
  printf '%s\n' "$u"
}
# A local upstream is passed to git ABSOLUTE, so the recorded origin does not depend on the cwd.
UP_ARG="$UPSTREAM"
case "$UPSTREAM" in
  *://*|*@*:*) ;;
  *) [ -d "$UPSTREAM" ] && UP_ARG="$(cd "$UPSTREAM" && pwd -P)" ;;
esac
UP_NORM="$(norm_url "$UPSTREAM")"

# --- one session at a time: a mkdir lock held across clone, mv and every fetch ---------------------
WAIT="${DIST_CLONE_LOCK_WAIT:-120}"
n=0
until mkdir "$LOCK" 2>/dev/null; do
  [ "$n" -ge "$WAIT" ] && stop "another session holds '$LOCK' (waited ${WAIT}s). If no other /ai-dlc-update is running in this repo or its worktrees, the lock is stale: \`rmdir '$LOCK'\` and re-run"
  sleep 1; n=$((n+1))
done
TMP=""
cleanup() { rmdir "$LOCK" 2>/dev/null; [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"; }
trap cleanup EXIT

G() { git --git-dir="$DIR" "$@"; }
ERR="$(mktemp "${TMPDIR:-/tmp}/dist-clone.err.XXXXXX")" || stop "mktemp failed for the stderr capture (check TMPDIR)"
trap 'cleanup; rm -f "$ERR"' EXIT
gitfail() { # gitfail <what>
  local tail cause="$1 failed"
  tail="$(tail -3 "$ERR" | tr '\n' ' ')"
  if grep -qiE 'terminal prompts disabled|could not read (username|password)|authentication failed|permission denied \(publickey|access denied|repository not found' "$ERR"; then
    cause="$1 failed on AUTHENTICATION (prompts are disabled here): configure a credential helper or ssh key for '$UPSTREAM', or set the stamp's \`upstream:\` to a local path"
  fi
  stop "$cause: $tail"
}

# --- build, or validate and refresh ------------------------------------------------------------
if [ -e "$DIR" ] || [ -L "$DIR" ]; then
  [ "$(G rev-parse --is-bare-repository 2>/dev/null)" = true ] \
    || stop "'$DIR' exists and is not a bare git repository; move it aside (\`mv '$DIR' '$DIR.bad'\`) and re-run to re-clone"
  have="$(G config --get remote.origin.url 2>/dev/null)" || have=""
  [ -n "$have" ] || stop "'$DIR' has no origin; set it with \`git --git-dir='$DIR' remote add origin '$UPSTREAM'\`, or move the dir aside and re-run"
  if [ "$(norm_url "$have")" != "$UP_NORM" ]; then
    stop "'$DIR' clones '$have', not '$UPSTREAM'. If '$UPSTREAM' is the distribution you mean, run \`git --git-dir='$DIR' remote set-url origin '$UPSTREAM'\` and re-run; otherwise correct the stamp's upstream:"
  fi
  G fetch --no-tags --prune origin "+refs/heads/main:refs/heads/main" 2>"$ERR" >/dev/null || gitfail "fetching main from '$UPSTREAM'"
else
  TMP="$(mktemp -d "$COMMON/ai-dlc-dist.tmp.XXXXXX")" || stop "could not create a build dir under '$COMMON'"
  git clone --bare --single-branch --branch main --no-tags "$UP_ARG" "$TMP/c" 2>"$ERR" >/dev/null \
    || gitfail "cloning main from '$UPSTREAM'"
  [ -e "$DIR" ] && stop "'$DIR' appeared while this session held the lock; refusing to overwrite it"
  mv "$TMP/c" "$DIR" || stop "could not move the built clone into '$DIR'"
fi
G rev-parse --verify -q "refs/heads/main^{commit}" >/dev/null || stop "'$DIR' carries no refs/heads/main after the fetch; upstream '$UPSTREAM' has no main branch"
git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1 \
  || stop "git refuses \`git -C '$DIR'\` (safe.bareRepository=explicit?). Every reconcile script reads <dist> with git -C, so the bare clone is unusable under that setting; allow it for this repo or unset it, and re-run"

# --- refs -------------------------------------------------------------------------------------------
NAMED_NOTHING="the ref names nothing in the distribution clone: a typo, a ref upstream does not carry, or a consumer sha passed where a distribution one belongs. Correct it and re-run"
pin_sha() { # pin_sha <full-sha> -- keep a fetched off-main sha against the clone's own gc
  G merge-base --is-ancestor "$1" refs/heads/main 2>/dev/null && return 0
  G update-ref "refs/ai-dlc-pin/$1" "$1" || stop "could not pin $1 at refs/ai-dlc-pin/$1"
}
resolved() { G rev-parse --verify -q "$1^{commit}" 2>/dev/null; }
# resolve_ref <ref> -- prints the full sha, fetching the ref by name once if it is not already there.
resolve_ref() {
  local r="$1" s n
  case "$r" in
    *[!0-9a-fA-F]*|"") ;;
    *)
      if s="$(resolved "$r")"; then
        [ "${#r}" -eq 40 ] && pin_sha "$s"
        printf '%s\n' "$s"; return 0
      fi
      if [ "${#r}" -ne 40 ]; then
        stop "ref '$r' does not resolve in '$DIR': an abbreviated sha cannot be fetched; name the branch or tag, or give the full sha"
      fi
      G fetch --no-tags origin "$r" 2>"$ERR" >/dev/null || stop "ref '$r' does not resolve to a commit after fetching it from '$UPSTREAM': $NAMED_NOTHING"
      s="$(resolved "$r")" || stop "ref '$r' does not resolve to a commit after fetching it: $NAMED_NOTHING"
      pin_sha "$s"; printf '%s\n' "$s"; return 0 ;;
  esac
  case "$r" in
    HEAD|main|refs/heads/main|origin/main|origin/HEAD) resolved refs/heads/main; return 0 ;;
    refs/tags/*) n="${r#refs/tags/}"; G fetch --no-tags origin "+refs/tags/$n:refs/tags/$n" 2>"$ERR" >/dev/null ;;
    refs/heads/*|origin/*)
      n="${r#refs/heads/}"; n="${n#origin/}"
      G fetch --no-tags origin "+refs/heads/$n:refs/heads/$n" 2>"$ERR" >/dev/null && r="refs/heads/$n" ;;
    *) if G fetch --no-tags origin "+refs/tags/$r:refs/tags/$r" 2>"$ERR" >/dev/null; then r="refs/tags/$r"
       elif G fetch --no-tags origin "+refs/heads/$r:refs/heads/$r" 2>"$ERR" >/dev/null; then r="refs/heads/$r"
       fi ;;
  esac
  s="$(resolved "$r")" || stop "ref '$1' does not resolve to a commit after fetching it from '$UPSTREAM' as a tag and as a branch: $NAMED_NOTHING"
  printf '%s\n' "$s"
}

if [ -n "$THEIRS_REF" ]; then THEIRS="$(resolve_ref "$THEIRS_REF")" || exit 1
else THEIRS="$(resolved refs/heads/main)" || stop "refs/heads/main does not resolve in '$DIR'"
fi
for r in "$@"; do
  [ -n "$r" ] || continue
  resolve_ref "$r" >/dev/null || exit 1
done
case "$THEIRS" in
  *[!0-9a-f]*) stop "theirs resolved to '$THEIRS', which is not a full sha" ;;
esac
[ "${#THEIRS}" -eq 40 ] || stop "theirs resolved to '$THEIRS', which is not a 40-hex sha"

printf '%s\n' "$DIR"
printf 'theirs %s\n' "$THEIRS"
exit 0
