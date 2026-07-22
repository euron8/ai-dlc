#!/bin/bash
#
# AI/DLC Post-Compact Re-attach Budget Validator
#
# Claude Code re-attaches only the first ~5,000 tokens of an invoked SKILL.md
# after a compaction. The POST-COMPACT RECOVERY PROTOCOL — the section that
# tells a just-compacted lead what to do (read the snapshot, acknowledge, run
# the verification turn) — MUST fall entirely inside that window, or the very
# instructions for recovering from a compaction are the ones a compaction drops.
#
# This happened once (v0.35.0): the protocol began at ~4,834 tokens and ran ~566
# long, so ~400 tokens of it were themselves discarded. The fix moved the handoff
# triggers / thresholds / auto-compact prose BELOW the protocol; the protocol then
# ended at ~4,439 tokens with ~561 tokens of slack. `retro.md`'s self-check asserts
# this at retro time, but nothing caught it at commit time — a single edit ABOVE
# the protocol could silently push its tail past 5,000 between retros. This script
# is that commit-time guard.
#
# WHAT IT MEASURES. Bytes from the start of SKILL.md through the END of the
# `## POST-COMPACT RECOVERY PROTOCOL` section (the line before the next `## `
# heading, which by design is `## HANDOFF PROTOCOL -- TRIGGERS AND CONTEXT
# THRESHOLDS`). Bytes are converted to an estimated token count at a ratio
# calibrated against the v0.35.0 measurement (17,990 bytes ≈ 4,439 tokens by
# Claude's own tokenizer → ~4.05 bytes/token; the default divisor 4 is slightly
# conservative, i.e. it over-counts tokens). The check FAILS if the estimate
# exceeds the budget minus a safety margin, so it trips BEFORE the real 5,000
# cliff, leaving room for tokenizer variance.
#
# THAT RATIO IS A PROPERTY OF THIS TEXT, NOT OF THE DIVISOR. Do not carry the
# "slightly conservative" conclusion to another population without re-measuring it:
# the ratio is content-dependent and the DIRECTION of the error reverses. Prose-heavy
# planning artifacts measure 3.62-3.84 bytes/token, where bytes/4 UNDER-counts by
# 5-11% — the opposite of the sentence above. validate-artifact-budget.sh copied this
# conclusion to exactly that population and carried it backwards for four releases;
# its header now documents the reversal. Same divisor, same number, opposite error.
#
# USAGE
#   core/scripts/validate-reattach-budget.sh [--skill PATH] [--quiet]
#
# ENV OVERRIDES
#   AI_DLC_REATTACH_BUDGET   re-attach window in tokens          (default 5000)
#   AI_DLC_REATTACH_MARGIN   safety margin below the window      (default 250)
#   AI_DLC_BYTES_PER_TOKEN   bytes-per-token divisor             (default 4)
#
# EXIT
#   0  protocol end is within (budget - margin)
#   1  protocol end exceeds the ceiling, an anchor is missing, or input unreadable

set -u

BUDGET="${AI_DLC_REATTACH_BUDGET:-5000}"
MARGIN="${AI_DLC_REATTACH_MARGIN:-250}"
BPT="${AI_DLC_BYTES_PER_TOKEN:-4}"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SKILL_MD="${PROJECT_DIR}/.claude/skills/ai-dlc/SKILL.md"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --skill) SKILL_MD="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

if [ ! -f "$SKILL_MD" ]; then
  echo "FAIL: cannot read SKILL.md -- no such file: $SKILL_MD" >&2
  exit 1
fi

CEILING=$(( BUDGET - MARGIN ))

# -----------------------------------------------------------------------------
# Anchors. The critical section is `## POST-COMPACT RECOVERY PROTOCOL`; its end
# is the line before the next top-level `## ` heading. Both must be present and
# in order, or the structure moved and the measurement is undefined -> FAIL.
# -----------------------------------------------------------------------------
START_LINE="$(grep -n '^## POST-COMPACT RECOVERY PROTOCOL' "$SKILL_MD" | head -1 | cut -d: -f1)"
if [ -z "$START_LINE" ]; then
  echo "FAIL: '## POST-COMPACT RECOVERY PROTOCOL' heading not found in $SKILL_MD." >&2
  echo "      The critical section was renamed or removed; re-measure before shipping." >&2
  exit 1
fi

# First top-level heading strictly after the protocol heading = its end boundary.
END_LINE="$(awk -v s="$START_LINE" 'NR>s && /^## / { print NR; exit }' "$SKILL_MD")"
if [ -z "$END_LINE" ]; then
  echo "FAIL: no '## ' section found after the POST-COMPACT RECOVERY PROTOCOL." >&2
  echo "      Cannot bound the protocol; re-measure before shipping." >&2
  exit 1
fi

# Bytes from file start through the last line of the protocol (END_LINE - 1).
PROTO_END=$(( END_LINE - 1 ))
BYTES="$(head -n "$PROTO_END" "$SKILL_MD" | wc -c | tr -d ' ')"
EST_TOKENS=$(( BYTES / BPT ))
# Slack is measured against the ceiling that actually FAILS this script, not
# against the raw window. Reporting it against BUDGET overstates the headroom by
# exactly MARGIN, and a reader budgeting the next addition against the larger
# figure spends a margin that is not there: at 4747 tokens the honest headroom is
# 3, and the old message read "253 tokens of slack".
SLACK=$(( CEILING - EST_TOKENS ))

say "re-attach window    : ${BUDGET} tokens (Claude Code re-attaches the first ~${BUDGET})"
say "safety margin       : ${MARGIN} tokens  (ceiling ${CEILING})"
say "protocol section    : lines ${START_LINE}..${PROTO_END}"
say "protocol end offset : ${BYTES} bytes ~= ${EST_TOKENS} tokens (at ${BPT} bytes/token)"
say ""

if [ "$EST_TOKENS" -gt "$CEILING" ]; then
  echo "FAIL: POST-COMPACT RECOVERY PROTOCOL ends at ~${EST_TOKENS} tokens, past the" >&2
  echo "      ${CEILING}-token ceiling (${BUDGET} re-attach window - ${MARGIN} margin)." >&2
  echo "      Content ABOVE the protocol grew and is pushing its tail toward the 5K" >&2
  echo "      cliff, where a compaction would drop the recovery instructions." >&2
  echo "      Fix: move non-critical prose BELOW the protocol (into the HANDOFF" >&2
  echo "      TRIGGERS section) or relocate rationale out of the resident region." >&2
  exit 1
fi

say "PASS  protocol ends at ~${EST_TOKENS} tokens; ${SLACK} tokens of slack under the ${CEILING}-token ceiling (${BUDGET} window - ${MARGIN} margin)."
exit 0
