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
P1="$WORK/projects/p1"
MUT="$WORK/mut"
CPD="$WORK/cpd"
GL="$GL"
ENV

printf '%s\n' "$WORK"
