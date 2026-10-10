#!/usr/bin/env bash
# advisor-gate-deny/seed.sh — build the worlds run.sh drives the REAL ai-dlc-advisor-gate.sh with.
#
# Four working trees, because the hook reads the branch checked out in the hook input's `cwd`:
#   SPRINT    a repository on `sprint/3`            -- a pipeline push, gated
#   UPDATE    a repository on `ai-dlc-update/x`     -- the update skill's branch, excluded
#   DETACHED  a repository with a detached HEAD     -- no branch, NOT excluded
#   NOREPO    a plain directory                     -- git fails, NOT excluded
# A projects directory `projects/p1/` holds the seeded transcripts; run.sh writes those per world.
# HOME is pointed at the work dir by run.sh, so `~/projects/...` names the seeded transcripts.
#
# Both layouts are named: the distribution (core/hooks/) and a consumer (.claude/hooks/).
# Prints the WORK dir on stdout. A fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-advisor-gate.sh" ]; then
  HOOK="$ROOT/core/hooks/ai-dlc-advisor-gate.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/hooks/ai-dlc-advisor-gate.sh" ]; then
  HOOK="$ROOT/.claude/hooks/ai-dlc-advisor-gate.sh"
else
  echo "FIXTURE ERROR: ai-dlc-advisor-gate.sh not found in either layout" >&2
  exit 2
fi
PROV="$(dirname "$HOOK")/ai-dlc-context-provenance.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/advisor-gate.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd)"

# The pre-push hook runs fixtures with GIT_DIR and friends exported; a seed `git` must not
# write into the repository being pushed.
g() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE git -c user.name=f -c user.email=f@f -c init.defaultBranch=main "$@"; }

mkdir -p "$WORK/sprint" "$WORK/update" "$WORK/detached" "$WORK/norepo" "$WORK/projects/p1" "$WORK/mut" "$WORK/cpd" || exit 2
for r in sprint update detached; do
  g -C "$WORK/$r" init -q || exit 2
  printf 'x\n' > "$WORK/$r/f"
  g -C "$WORK/$r" add f && g -C "$WORK/$r" commit -q -m seed || exit 2
done
g -C "$WORK/sprint" checkout -q -b sprint/3 || exit 2
g -C "$WORK/update" checkout -q -b ai-dlc-update/x || exit 2
g -C "$WORK/detached" checkout -q --detach || exit 2

# L3: three repositories with a remote-tracking target and no remote (`refs/remotes/origin/HEAD`
# -> `origin/main`), each on a branch whose outgoing commits are:
#   BMAD      one commit touching only `_bmad-output/`                     -- exempt
#   CODE      a `_bmad-output/` commit and one touching `src/`             -- gated
#   EMPTYOUT  none                                                         -- gated
for r in bmad code emptyout; do
  mkdir -p "$WORK/$r" || exit 2
  g -C "$WORK/$r" init -q || exit 2
  printf 'x\n' > "$WORK/$r/f"
  g -C "$WORK/$r" add f && g -C "$WORK/$r" commit -q -m seed || exit 2
  g -C "$WORK/$r" update-ref refs/remotes/origin/main HEAD || exit 2
  g -C "$WORK/$r" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main || exit 2
  g -C "$WORK/$r" checkout -q -b sprint/4 || exit 2
done
for r in bmad code; do
  mkdir -p "$WORK/$r/_bmad-output" && printf 'p\n' > "$WORK/$r/_bmad-output/pipeline-snapshot.md" || exit 2
  g -C "$WORK/$r" add _bmad-output && g -C "$WORK/$r" commit -q -m snapshot || exit 2
done
mkdir -p "$WORK/code/src" && printf 'echo\n' > "$WORK/code/src/a.sh" || exit 2
g -C "$WORK/code" add src && g -C "$WORK/code" commit -q -m code || exit 2
#   UPSTREAM  a sprint branch already pushed with `-u` (code included), then one `_bmad-output/`
#             commit: exempt through `@{u}`, gated through `origin/HEAD` (the range holds the code).
mkdir -p "$WORK/upstream" && g -C "$WORK/upstream" init -q || exit 2
printf 'x\n' > "$WORK/upstream/f" && g -C "$WORK/upstream" add f && g -C "$WORK/upstream" commit -q -m seed || exit 2
g -C "$WORK/upstream" update-ref refs/remotes/origin/main HEAD || exit 2
g -C "$WORK/upstream" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main || exit 2
g -C "$WORK/upstream" checkout -q -b sprint/4 || exit 2
mkdir -p "$WORK/upstream/src" && printf 'echo\n' > "$WORK/upstream/src/a.sh" || exit 2
g -C "$WORK/upstream" add src && g -C "$WORK/upstream" commit -q -m code || exit 2
g -C "$WORK/upstream" update-ref refs/remotes/origin/sprint/4 HEAD || exit 2
# `@{u}` resolves only through a fetch refspec; the url names nothing and is never contacted.
g -C "$WORK/upstream" config remote.origin.url "$WORK/upstream-none.git" || exit 2
g -C "$WORK/upstream" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' || exit 2
g -C "$WORK/upstream" config branch.sprint/4.remote origin || exit 2
g -C "$WORK/upstream" config branch.sprint/4.merge refs/heads/sprint/4 || exit 2
mkdir -p "$WORK/upstream/_bmad-output" && printf 'p\n' > "$WORK/upstream/_bmad-output/pipeline-snapshot.md" || exit 2
g -C "$WORK/upstream" add _bmad-output && g -C "$WORK/upstream" commit -q -m snapshot || exit 2

GL="$WORK/sprint/_bmad-output/implementation-artifacts/gate-log.md"
mkdir -p "$(dirname "$GL")" || exit 2
printf '# Gate Log\n\n## Gate Log: Sprint 2\nTimestamp: 2026-10-01T00:00Z\n| check | verdict |\n' > "$GL" || exit 2

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
PROV="$PROV"
W="$WORK"
SPRINT="$WORK/sprint"
UPDATE="$WORK/update"
DETACHED="$WORK/detached"
NOREPO="$WORK/norepo"
BMAD="$WORK/bmad"
CODE="$WORK/code"
EMPTYOUT="$WORK/emptyout"
UPSTREAM="$WORK/upstream"
P1="$WORK/projects/p1"
MUT="$WORK/mut"
CPD="$WORK/cpd"
GL="$GL"
ENV

printf '%s\n' "$WORK"
