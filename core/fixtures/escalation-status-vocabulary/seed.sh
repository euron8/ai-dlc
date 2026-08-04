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
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/ai-dlc/validate-escalation-status-vocabulary.sh" ]; then
  VALIDATOR="$C_ROOT/scripts/ai-dlc/validate-escalation-status-vocabulary.sh"
  SPEC_SRC="$C_ROOT/.claude/skills/ai-dlc/escalations.md"
else
  echo "FIXTURE ERROR: validate-escalation-status-vocabulary.sh not found in either layout" >&2
  exit 2
fi
[ -f "$SPEC_SRC" ] || { echo "FIXTURE ERROR: escalations.md not found at $SPEC_SRC" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/esc-vocab.XXXXXX")" || exit 2

# ---- CLEAN: every token in the published set, DERIVED ----------------------
# GENERATED FROM THE SPEC, never hand-listed. This block used to enumerate the tokens by
# hand, and the hand-list is what broke: publishing a new terminal status made the clean
# file cover 5 of 6, and — worse — a consumer whose escalations.md predates the token got
# a clean file asserting a status its own spec does not publish, so the fixture went red
# on a pull that broke nothing. That is the machinery-vs-rulebook coupling the self-update
# gate now defers on, reproduced inside a fixture: the seed is machinery, escalations.md
# is rulebook, and a hand-list welds them to each other's versions.
#
# Deriving also makes the POSITIVE CONTROL mean what it claims. "Every published token
# passes" is only true if the file actually carries every published token.
{
  echo "# Pending Escalations"
  echo
  i=0
  awk '
    /^\*\*Status:\*\*/ || /^\*\*Terminal statuses\*\*/ {
      s = $0
      sub(/^[^:]*:[[:space:]]*/, "", s); gsub(/`/, "", s)
      n = split(s, parts, /[|]/)
      for (j = 1; j <= n; j++) { t = parts[j]; gsub(/[^A-Z_]/, "", t); if (t != "") print t }
    }
  ' "$SPEC_SRC" | sort -u | while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    i=$((i + 1))
    echo "## S300-$i Dev - 2026-07-21T10:0${i}Z"
    echo "**Status:** $tok"
    echo "**Context:** derived from the published set"
    echo
  done
} > "$WORK/pending-clean.md"

# A derived file that derived NOTHING is the false zero this fixture would never notice:
# an empty clean file passes the validator trivially and the positive control means nothing.
if [ "$(grep -c '^\*\*Status:\*\*' "$WORK/pending-clean.md")" -lt 2 ]; then
  echo "FIXTURE ERROR: derived fewer than 2 status tokens from $SPEC_SRC; the clean file would pass vacuously" >&2
  exit 2
fi

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
