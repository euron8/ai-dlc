#!/usr/bin/env bash
# escalation-status-vocabulary/seed.sh — escalation files that Check 2 cannot adjudicate.
#
# Check 2 is three branches with no else. An entry whose Status is outside the published
# set satisfies none of them: not blocked, not surfaced, not recorded. No verdict is
# computed for it and the gate reports Check 2 as passing. run.sh proves the validator
# catches that, and — the load-bearing part — that its vocabulary is DERIVED from
# escalations.md rather than restated in the script.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-escalation-status-vocabulary.sh" ]; then
  VALIDATOR="$D_ROOT/core/scripts/validate-escalation-status-vocabulary.sh"
  SPEC_SRC="$D_ROOT/core/skills/ai-dlc/escalations.md"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/validate-escalation-status-vocabulary.sh" ]; then
  VALIDATOR="$C_ROOT/scripts/validate-escalation-status-vocabulary.sh"
  SPEC_SRC="$C_ROOT/.claude/skills/ai-dlc/escalations.md"
else
  echo "FIXTURE ERROR: validate-escalation-status-vocabulary.sh not found in either layout" >&2
  exit 2
fi
[ -f "$SPEC_SRC" ] || { echo "FIXTURE ERROR: escalations.md not found at $SPEC_SRC" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/esc-vocab.XXXXXX")" || exit 2

# ---- CLEAN: every token in the published set -------------------------------
cat > "$WORK/pending-clean.md" <<'MD'
# Pending Escalations

## S300-1 Dev - 2026-07-21T10:00Z
**Status:** HARD_BLOCK
**Context:** needs an operator call

## S300-2 QA - 2026-07-21T11:00Z
**Status:** DECIDED_AUTONOMOUSLY
**Context:** picked the cheaper option

## S300-3 Architect - 2026-07-21T12:00Z
**Status:** DEFERRAL_REQUEST
**Context:** deferred behind an upstream release

## S299-4 Dev - 2026-07-20T09:00Z
**Status:** RESOLVED
**Context:** operator adjudicated at the checkpoint

## S299-5 Dev - 2026-07-20T09:30Z
**Status:** OVERRIDDEN
**Context:** the autonomous call was wrong
MD

# ---- DRIFTED: two tokens core never defined --------------------------------
# FILED and OPEN are the exact tokens the reference consumer accumulated 8 entries on.
cat > "$WORK/pending-drift.md" <<'MD'
# Pending Escalations

## S300-1 Dev - 2026-07-21T10:00Z
**Status:** HARD_BLOCK
**Context:** needs an operator call

## CO-S300-CARRIED-FORWARD - 2026-07-21T13:00Z
**Status:** FILED
**Context:** carried to the next sprint

## CO-S300-STILL-OPEN - 2026-07-21T14:00Z
**Status:** OPEN
**Context:** nobody has looked at it
MD

# ---- MID-ENTRY: the Status field is not at line start -----------------------
# The ledger's own measuring regex anchored `**Status:**` to line start and called its
# count a lower bound for exactly this reason. A token invisible to the naive validator
# anyone writes first is no less invisible to Check 2.
cat > "$WORK/pending-midentry.md" <<'MD'
# Pending Escalations

## S300-6 Dev - 2026-07-21T15:00Z
Carried from the prior sprint. **Status:** TRIAGED — see the triage log.
**Context:** filed against the wrong component
MD

cat > "$WORK/env.sh" <<ENV
VALIDATOR="$VALIDATOR"
SPEC_SRC="$SPEC_SRC"
WORK="$WORK"
CLEAN="$WORK/pending-clean.md"
DRIFT="$WORK/pending-drift.md"
MIDENTRY="$WORK/pending-midentry.md"
ENV

printf '%s\n' "$WORK"
