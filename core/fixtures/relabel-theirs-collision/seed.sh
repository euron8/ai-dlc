#!/usr/bin/env bash
# relabel-theirs-collision/seed.sh — build a fake distribution (theirs) whose core adds `### 26.`
# and a consumer whose INSTALLED core lacks it but whose extension already defines `### 26.`.
# That is a NEW-THIS-PULL collision: invisible to a plain dry-run, visible only with --theirs.
# Idempotent: fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" ]; then
  SCRIPT="$D_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" ]; then
  SCRIPT="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
else
  echo "FIXTURE ERROR: relabel-extension-checks.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/relabel-theirs.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
GV="skills/ai-dlc/steps/gate-validation.md"
mkdir -p "$DIST/core/skills/ai-dlc/steps" \
         "$CONSUMER/.claude/skills/ai-dlc/steps" \
         "$CONSUMER/.claude/skills/ai-dlc/extensions/checks"

# THEIRS (incoming core) — adds `### 26.`.
cat > "$DIST/core/$GV" <<'CORE'
# Gate validation (fixture)
### 25. Existing universal check.
### 26. Core gate-check adjudication verdict.
CORE
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# CONSUMER installed core — the PRE-APPLY state, without 26.
cat > "$CONSUMER/.claude/$GV" <<'CORE'
# Gate validation (fixture)
### 25. Existing universal check.
CORE

# CONSUMER extension — already defines `### 26.`, unlabelled.
cat > "$CONSUMER/.claude/skills/ai-dlc/extensions/checks/mydomain.md" <<'EXT'
---
kind: check
id: mydomain
hooks: steps/gate-validation.md
---
### 26. Ext deployed-ranges consistency gate.
EXT

cat > "$WORK/env.sh" <<ENV
SCRIPT="$SCRIPT"
DIST="$DIST"
THEIRS="$THEIRS"
CONSUMER="$CONSUMER"
EXT="$CONSUMER/.claude/skills/ai-dlc/extensions/checks/mydomain.md"
ENV

printf '%s\n' "$WORK"
