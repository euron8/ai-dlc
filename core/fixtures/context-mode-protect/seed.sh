#!/usr/bin/env bash
# context-mode-protect/seed.sh — build the trees run.sh drives the REAL
# ai-dlc-protect.sh hook against.
#
# Three trees, because the hook has three states:
#   PLAIN   — no consumer layer file; the core protected set only.
#   LAYERED — extensions/protected-paths.json declaring a consumer path
#             (docs/architecture.md, the graph consumer's real SoR location)
#             and a consumer exclusion.
#   BROKEN  — the same file, malformed; the hook must fail CLOSED.
#
# Also prints a WORKTREE root: a sibling directory that is NOT the project dir,
# standing in for the story worktrees a consumer runs. The hook must protect a
# rule file reached through one, which is the s292 fail-open this fixture pins.
#
# Prints the WORK dir on stdout. Idempotent: a fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the hook in either layout (distribution core/, or consumer .claude/).
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/hooks/ai-dlc-protect.sh" ]; then
  HOOK="$D_ROOT/core/hooks/ai-dlc-protect.sh"
elif [ -n "$D_ROOT" ] && [ -f "$D_ROOT/.claude/hooks/ai-dlc-protect.sh" ]; then
  HOOK="$D_ROOT/.claude/hooks/ai-dlc-protect.sh"
else
  echo "FIXTURE ERROR: ai-dlc-protect.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/context-mode-protect.XXXXXX")" || exit 2
# Resolve to a stable absolute path (macOS /tmp is a symlink). The hook must
# cope with either spelling, but the fixture should not be the thing testing it
# by accident — assertion 4 tests worktree/symlink tolerance deliberately.
WORK="$(cd "$WORK" && pwd)"

PLAIN="$WORK/plain"
LAYERED="$WORK/layered"
BROKEN="$WORK/broken"
WORKTREE="$WORK/plain-story-1"     # sibling of PLAIN, never the project dir

for t in "$PLAIN" "$LAYERED" "$BROKEN" "$WORKTREE"; do
  mkdir -p "$t/.claude/skills/ai-dlc/extensions" "$t/docs" "$t/_bmad-output"
done

cat > "$LAYERED/.claude/skills/ai-dlc/extensions/protected-paths.json" <<'EOF'
{
  "protected_paths": ["docs/architecture.md", "docs/architecture-index.md"],
  "excluded_paths":  ["docs/architecture-drafts/*"]
}
EOF

# Malformed on SHAPE, not syntax: valid JSON, wrong type. A syntax-error file is
# the easy case; the shape check is the one a consumer actually trips.
cat > "$BROKEN/.claude/skills/ai-dlc/extensions/protected-paths.json" <<'EOF'
{ "protected_paths": "docs/architecture.md" }
EOF

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
PLAIN="$PLAIN"
LAYERED="$LAYERED"
BROKEN="$BROKEN"
WORKTREE="$WORKTREE"
ENV

printf '%s\n' "$WORK"
