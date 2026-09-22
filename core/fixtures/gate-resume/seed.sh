#!/usr/bin/env bash
# gate-resume/seed.sh — resolve the three subjects (gate-slice.sh, gate-checkpoint.sh,
# ai-dlc-recover.sh's gate-resume section) in whichever layout is on disk, and hand back
# a scratch workspace + an env.sh naming them. Modeled on
# postcompact-rulebook-recovery/seed.sh: each artifact is resolved on its OWN candidate
# path list, never by walking up from a sibling (CLAUDE.md / I33 — install.sh splits what
# shares a parent in core/).
#
# SLICE and CKPT (gate-slice.sh, gate-checkpoint.sh) are new scripts and may be ABSENT on
# a consumer that pulled this fixture one release ahead of the code it guards
# (consumer-boundary.md: "a core fixture ships ahead of its subject"). Their absence is
# NOT fatal here — run.sh reads an empty var and reports SKIP, never FAIL, unless IS_DIST
# says this IS the distribution, where the subject MUST be present (fixture-mutants.md /
# consumer-boundary.md). GATEFILE (gate-validation.md) and HOOK (ai-dlc-recover.sh) are
# long-standing shipped files present in every layout and stay a hard FIXTURE ERROR if
# missing — their absence would mean the fixture's own scaffolding is broken, not that a
# new subject has not arrived yet.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: cannot resolve repo root" >&2; exit 2; }

if   [ -f "$ROOT/core/hooks/ai-dlc-recover.sh" ]; then HOOK="$ROOT/core/hooks/ai-dlc-recover.sh"
elif [ -f "$ROOT/.claude/hooks/ai-dlc-recover.sh" ]; then HOOK="$ROOT/.claude/hooks/ai-dlc-recover.sh"
else echo "FIXTURE ERROR: ai-dlc-recover.sh not found in either layout" >&2; exit 2; fi

if   [ -f "$ROOT/core/skills/ai-dlc/steps/gate-validation.md" ]; then GATEFILE="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
elif [ -f "$ROOT/.claude/skills/ai-dlc/steps/gate-validation.md" ]; then GATEFILE="$ROOT/.claude/skills/ai-dlc/steps/gate-validation.md"
else echo "FIXTURE ERROR: gate-validation.md not found in either layout" >&2; exit 2; fi

# Optional subjects. Empty string, never a die, on absence.
SLICE=""
if   [ -f "$ROOT/core/scripts/gate-slice.sh" ]; then SLICE="$ROOT/core/scripts/gate-slice.sh"
elif [ -f "$ROOT/scripts/ai-dlc/gate-slice.sh" ]; then SLICE="$ROOT/scripts/ai-dlc/gate-slice.sh"
fi

CKPT=""
if   [ -f "$ROOT/core/scripts/gate-checkpoint.sh" ]; then CKPT="$ROOT/core/scripts/gate-checkpoint.sh"
elif [ -f "$ROOT/scripts/ai-dlc/gate-checkpoint.sh" ]; then CKPT="$ROOT/scripts/ai-dlc/gate-checkpoint.sh"
fi

# IS_DIST: this repo carries core/skills/ai-dlc; a consumer does not. In the
# distribution SLICE and CKPT must be present — a SKIP here would be this repo's own
# suite staying green over a subject that never arrived (fixture-ship-decl.md).
IS_DIST=0; [ -d "$ROOT/core/skills/ai-dlc" ] && IS_DIST=1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gate-resume.XXXXXX")" || exit 2

cat > "$WORK/env.sh" <<ENV
SLICE="$SLICE"
CKPT="$CKPT"
HOOK="$HOOK"
GATEFILE="$GATEFILE"
ROOT="$ROOT"
IS_DIST="$IS_DIST"
WORK="$WORK"
ENV

printf '%s\n' "$WORK"
