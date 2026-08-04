#!/usr/bin/env bash
# postcompact-rulebook-recovery/seed.sh — the two ends of one guarantee, in both layouts.
#
# The recovery hook and the budget validator are the WRITER and the CHECKER of the same
# instruction: the hook delivers "re-read the rulebook" at the moment of a compaction, and
# the validator refuses to ship a SKILL.md whose protocol does not carry it. A fixture that
# resolved only one of them would prove half a join.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: cannot resolve repo root" >&2; exit 2; }

# Two layouts (CLAUDE.md): core/<x> here, .claude/<x> and scripts/ai-dlc/<x> installed.
# Resolve each artifact on its OWN path — never by walking up from a sibling, which is the
# shape invariant I33 fails the build on.
if   [ -f "$ROOT/core/hooks/ai-dlc-recover.sh" ]; then HOOK="$ROOT/core/hooks/ai-dlc-recover.sh"
elif [ -f "$ROOT/.claude/hooks/ai-dlc-recover.sh" ]; then HOOK="$ROOT/.claude/hooks/ai-dlc-recover.sh"
else echo "FIXTURE ERROR: ai-dlc-recover.sh not found in either layout" >&2; exit 2; fi

if   [ -f "$ROOT/core/scripts/validate-reattach-budget.sh" ]; then VAL="$ROOT/core/scripts/validate-reattach-budget.sh"
elif [ -f "$ROOT/scripts/ai-dlc/validate-reattach-budget.sh" ]; then VAL="$ROOT/scripts/ai-dlc/validate-reattach-budget.sh"
else echo "FIXTURE ERROR: validate-reattach-budget.sh not found in either layout" >&2; exit 2; fi

if   [ -f "$ROOT/core/skills/ai-dlc/SKILL.md" ]; then SKILL="$ROOT/core/skills/ai-dlc/SKILL.md"
elif [ -f "$ROOT/.claude/skills/ai-dlc/SKILL.md" ]; then SKILL="$ROOT/.claude/skills/ai-dlc/SKILL.md"
else echo "FIXTURE ERROR: SKILL.md not found in either layout" >&2; exit 2; fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/postcompact-rulebook.XXXXXX")" || exit 2
mkdir -p "$WORK/project/_bmad-output"

# The hook exits 0 before building its directive when no snapshot exists, so without this
# every hook assertion below would pass on an empty string.
cat > "$WORK/project/_bmad-output/pipeline-snapshot.md" <<'MD'
# Pipeline Snapshot

## Pipeline Position
current_step_file: `architecture.md`
last_gate_passed: planning-gate-2 @ 2026-08-04T10:00:00Z
current_branch: main

## Sprint Context
sprint_id: 300
MD

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
VAL="$VAL"
SKILL="$SKILL"
PROJECT="$WORK/project"
WORK="$WORK"
ENV

printf '%s\n' "$WORK"
