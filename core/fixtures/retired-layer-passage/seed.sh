#!/usr/bin/env bash
# retired-layer-passage/seed.sh — build a throwaway dist repo + consumer tree and echo
# the workspace path. The detector resolves its rulebook list from its OWN directory, so
# the seeded dist must place files at the real declared rulebook paths.
set -euo pipefail

# Resolve the PROJECT ROOT and then name the full path in each layout — never walk up from
# here into a core subtree (I33). Done before any `cd`, or a relative invocation breaks it.
HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/retired-layer-passage.sh" ]; then
  SCRIPT="$D_ROOT/core/skills/ai-dlc-update/reconcile/retired-layer-passage.sh"
elif [ -n "$D_ROOT" ] && [ -f "$D_ROOT/.claude/skills/ai-dlc-update/reconcile/retired-layer-passage.sh" ]; then
  SCRIPT="$D_ROOT/.claude/skills/ai-dlc-update/reconcile/retired-layer-passage.sh"
else
  echo "FIXTURE ERROR: retired-layer-passage.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d)"
DIST="$WORK/dist"
CONS="$WORK/consumer"

mkdir -p "$DIST/core/skills/ai-dlc/steps"
cd "$DIST"
git init -q .
git config user.email f@f; git config user.name f

# --- BASE: core carries two directives that a layer file will go on to reproduce -------
cat > core/skills/ai-dlc/steps/demo.md <<'EOF'
# Demo step

## Failure handling

1. Diagnose the failure before doing anything else.
2. Apply all improvements. Append changelog to the story.
3. If deployment issue: fix the deployment and re-run smoke tests.
4. Record the outcome in the gate log.

| col | col |
|---|---|
EOF
git add -A; git commit -qm base
BASE="$(git rev-parse HEAD)"

# --- THEIRS: both directives are DELETED and replaced -----------------------------------
cat > core/skills/ai-dlc/steps/demo.md <<'EOF'
# Demo step

## Failure handling

1. Diagnose the failure before doing anything else.
2. Dispatch a remediator; the lead owns the disposition, not the edit.
3. If deployment issue: dispatch the ops teammate to fix the deployment.
4. Record the outcome in the gate log.

| col | col |
|---|---|
EOF
git add -A; git commit -qm theirs
THEIRS="$(git rev-parse HEAD)"

# --- the consumer's layer files ---------------------------------------------------------
mkdir -p "$CONS/.claude/skills/ai-dlc/extensions" "$CONS/.claude/skills/ai-dlc/overrides"

# A TRUE positive, written the way the live findings are: the deleted core sentence
# reproduced verbatim but RENUMBERED and EMPHASISED, so only normalisation can match it.
cat > "$CONS/.claude/skills/ai-dlc/extensions/restates.md" <<'EOF'
# Domain extension

Our variant of core's protocol:

7. **Apply all improvements. Append changelog to the story.**
EOF

# A PARAPHRASE of the other deleted line. Reworded, so it must NOT match — this is the
# stated limit, and asserting it keeps the matcher from drifting toward fuzzy comparison.
cat > "$CONS/.claude/skills/ai-dlc/overrides/paraphrase.md" <<'EOF'
# Override

If the deployment is at fault, repair it and run the smoke tests again.
EOF

# A layer file that reproduces NOTHING core deleted.
cat > "$CONS/.claude/skills/ai-dlc/overrides/inert.md" <<'EOF'
# Override

This entry speaks only about its own concerns and quotes no core directive.
EOF

cat > "$WORK/env.sh" <<EOF
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONSUMER="$CONS"
SCRIPT="$SCRIPT"
EOF

echo "$WORK"
