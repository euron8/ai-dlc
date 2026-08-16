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

# The ENFORCER of the same instruction, resolved on its own path for the same reason. It is
# allowed to be ABSENT: this fixture ships, and a core fixture arrives at a consumer one pull
# ahead of the code it guards. `IS_DIST` is what stops that tolerance from becoming a hole —
# in the distribution the subject must be here, so run.sh turns the SKIP into a FAIL.
GATE=""
if   [ -f "$ROOT/core/hooks/ai-dlc-recover-gate.sh" ]; then GATE="$ROOT/core/hooks/ai-dlc-recover-gate.sh"
elif [ -f "$ROOT/.claude/hooks/ai-dlc-recover-gate.sh" ]; then GATE="$ROOT/.claude/hooks/ai-dlc-recover-gate.sh"
fi
IS_DIST=0; [ -d "$ROOT/core/skills/ai-dlc" ] && IS_DIST=1

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

# THE SNAPSHOT CARRIES A BARE BASENAME AND THE STEP FILE LIVES UNDER THE STEPS DIRECTORY -- the
# reference-consumer layout, `route.md:46-47`: `current_step_file` is resolved as
# `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`. This seed named the basename
# and put the file NOWHERE, which is a tree that cannot occur: the mandate then names a file the
# lead cannot read, and every arm below measured the hook's unresolvable branch while claiming to
# measure its ordinary one. Measured on that seed, the directive carried ONE bolded mandate and
# the grade arm went red.
mkdir -p "$WORK/project/.claude/skills/ai-dlc/steps"
printf '# Architecture\n\nstep body\n' > "$WORK/project/.claude/skills/ai-dlc/steps/architecture.md"

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
VAL="$VAL"
SKILL="$SKILL"
GATE="$GATE"
IS_DIST="$IS_DIST"
PROJECT="$WORK/project"
STEPS_REL=".claude/skills/ai-dlc/steps"
WORK="$WORK"
ENV

printf '%s\n' "$WORK"
