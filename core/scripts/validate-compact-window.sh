#!/bin/bash
#
# AI/DLC Auto-Compact Window Validator
#
# Checks the ordering invariant between Claude Code's auto-compact threshold
# and AI/DLC's own red context reminder:
#
#     red + MIN_SLACK  <  threshold  <  red + MAX_DRIFT
#
# where  threshold = min(autoCompactWindow, modelMax) - COMPACT_RESERVE
#
# WHY THE LOWER BOUND. If auto-compact fires at or before red, the lead never
# gets the chance to take the high-fidelity path (finalize the snapshot, hand
# off, `/clear` + `/ai-dlc resume`). Worse, a threshold near AI/DLC's resident
# prefix makes every post-compact turn refill immediately; Claude Code's
# rapid-refill breaker then halts the session outright after three such refills.
#
# WHY THE UPPER BOUND. If auto-compact fires far past red, an operator who
# ignores the red reminder (unattended run, `auto_handoff_mode: off`) keeps
# working in a degraded context for a very long time before any involuntary net
# catches them. The upper bound caps that blast radius.
#
# Constants below are read from the installed Claude Code binary's behaviour and
# are stable across the 2.1.x line:
#   compact threshold = effectiveWindow - 13000
#   API hard block    = effectiveWindow -  3000
#   autoCompactWindow is an integer in [100000, 1000000]; the effective window is
#   min(setting, model max), so the setting can only ever lower the threshold.
#
# USAGE
#   scripts/validate-compact-window.sh [--skill PATH] [--settings PATH]
#                                      [--row 200K|1M] [--quiet]
#
# Every row is reported. Without --row, every row is also binding on the exit
# status, because the script cannot know which model the project actually runs.
# A project that only ever runs one context size should pass --row (or set
# AI_DLC_MODEL_ROW) so the other row stays informational.
#
# EXIT
#   0  invariant holds for every binding row (warnings may still be printed)
#   1  invariant violated for a binding row, or inputs unreadable

set -u

COMPACT_RESERVE=13000
MIN_SLACK="${AI_DLC_COMPACT_MIN_SLACK:-50000}"
MAX_DRIFT="${AI_DLC_COMPACT_MAX_DRIFT:-100000}"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SKILL_MD="${PROJECT_DIR}/.claude/skills/ai-dlc/SKILL.md"
SETTINGS_JSON="${PROJECT_DIR}/.claude/settings.json"
BINDING_ROW="${AI_DLC_MODEL_ROW:-}"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --skill)    SKILL_MD="$2"; shift 2 ;;
    --settings) SETTINGS_JSON="$2"; shift 2 ;;
    --row)      BINDING_ROW="$2"; shift 2 ;;
    --quiet)    QUIET=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# -----------------------------------------------------------------------------
# Window resolution: env > settings.json > unset (model default)
#
# The env var accepts Claude Code's own spellings: "auto", "400k", "1m", or a
# bare integer (values 100..1000 are read as thousands).
# -----------------------------------------------------------------------------
parse_window() {
  local raw
  raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    ""|auto) return 1 ;;
    *m) awk -v v="${raw%m}" 'BEGIN{printf "%d", v*1000000}' ;;
    *k) awk -v v="${raw%k}" 'BEGIN{printf "%d", v*1000}' ;;
    *[!0-9]*) return 1 ;;
    *)
      if [ "$raw" -ge 100 ] && [ "$raw" -le 1000 ]; then
        awk -v v="$raw" 'BEGIN{printf "%d", v*1000}'
      else
        printf '%d' "$raw"
      fi
      ;;
  esac
}

WINDOW=""
WINDOW_SOURCE="unset (model default)"

if [ -n "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}" ]; then
  if WINDOW="$(parse_window "$CLAUDE_CODE_AUTO_COMPACT_WINDOW")"; then
    WINDOW_SOURCE="env CLAUDE_CODE_AUTO_COMPACT_WINDOW"
  else
    WINDOW=""
  fi
fi

if [ -z "$WINDOW" ] && [ -f "$SETTINGS_JSON" ] && command -v jq >/dev/null 2>&1; then
  raw="$(jq -r '.autoCompactWindow // empty' "$SETTINGS_JSON" 2>/dev/null)"
  if [ -n "$raw" ] && WINDOW="$(parse_window "$raw")"; then
    WINDOW_SOURCE="settings.json autoCompactWindow"
  else
    WINDOW=""
  fi
fi

if [ -n "$WINDOW" ]; then
  if [ "$WINDOW" -lt 100000 ] || [ "$WINDOW" -gt 1000000 ]; then
    echo "FAIL: autoCompactWindow=${WINDOW} is outside Claude Code's accepted range [100000, 1000000]." >&2
    echo "      Values outside the range are silently discarded, so the model default applies." >&2
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# Red thresholds come from the SKILL.md table, which projects are told to edit
# directly. Rows look like:  | 200K | 80K tokens | 120K tokens |
# -----------------------------------------------------------------------------
if [ ! -f "$SKILL_MD" ]; then
  echo "FAIL: cannot read threshold table -- no such file: $SKILL_MD" >&2
  exit 1
fi

ROWS="$(awk -F'|' '
  /^\|[[:space:]]*(200K|1M)[[:space:]]*\|/ {
    gsub(/[[:space:]]/, "", $2); gsub(/[[:space:]]|tokens/, "", $4);
    label = $2; red = $4;
    mult = (red ~ /K$/) ? 1000 : 1;
    sub(/K$/, "", red);
    printf "%s %d\n", label, red * mult;
  }
' "$SKILL_MD")"

if [ -z "$ROWS" ]; then
  echo "FAIL: no 200K/1M rows found in the threshold table of $SKILL_MD" >&2
  exit 1
fi

say "auto-compact window : ${WINDOW:-<model default>}  (source: ${WINDOW_SOURCE})"
say "compact reserve     : ${COMPACT_RESERVE}"
say "invariant           : red + ${MIN_SLACK} < threshold < red + ${MAX_DRIFT}"
say ""

STATUS=0

while read -r LABEL RED; do
  [ -n "$LABEL" ] || continue

  case "$LABEL" in
    200K) MODEL_MAX=200000 ;;
    1M)   MODEL_MAX=1000000 ;;
    *)    continue ;;
  esac

  EFFECTIVE="$MODEL_MAX"
  if [ -n "$WINDOW" ] && [ "$WINDOW" -lt "$MODEL_MAX" ]; then
    EFFECTIVE="$WINDOW"
  fi

  THRESHOLD=$(( EFFECTIVE - COMPACT_RESERVE ))
  LOWER=$(( RED + MIN_SLACK ))
  UPPER=$(( RED + MAX_DRIFT ))

  # A row the project never runs is reported but does not decide the exit status.
  if [ -n "$BINDING_ROW" ] && [ "$BINDING_ROW" != "$LABEL" ]; then
    TAG="info"; BINDING=0
  else
    TAG="FAIL"; BINDING=1
  fi

  if [ "$THRESHOLD" -le "$LOWER" ]; then
    [ "$BINDING" -eq 1 ] && STATUS=1
    say "${TAG}  ${LABEL} model: compaction fires at ${THRESHOLD}, red fires at ${RED}."
    say "      A threshold at or below red + ${MIN_SLACK} denies the handoff its first"
    say "      refusal and risks the rapid-refill breaker halting the session."
    say "      Raise autoCompactWindow to at least $(( LOWER + COMPACT_RESERVE + 1 ))."
  elif [ "$THRESHOLD" -ge "$UPPER" ]; then
    [ "$BINDING" -eq 1 ] && STATUS=1
    say "${TAG}  ${LABEL} model: compaction fires at ${THRESHOLD}, red fires at ${RED}."
    say "      That leaves $(( THRESHOLD - RED )) tokens of degraded running past red before"
    say "      any involuntary net catches an operator who ignored the reminder."
    say "      Set autoCompactWindow between $(( LOWER + COMPACT_RESERVE + 1 )) and $(( UPPER + COMPACT_RESERVE - 1 ))."
  else
    say "PASS  ${LABEL} model: red ${RED} -> compaction ${THRESHOLD} (slack $(( THRESHOLD - RED )))."
  fi

  # Warn-only: the fixed prefix is not knowable from a script. It is the system
  # prompt + tool schemas + MCP schemas + CLAUDE.md + re-attached skills, which
  # survive compaction and are therefore the floor a post-compact turn starts
  # from. `/context` reports it. If it crowds the threshold, every post-compact
  # turn refills immediately and the rapid-refill breaker trips.
  if [ -n "${AI_DLC_FIXED_PREFIX_TOKENS:-}" ]; then
    HEADROOM=$(( THRESHOLD - AI_DLC_FIXED_PREFIX_TOKENS ))
    if [ "$HEADROOM" -lt 60000 ]; then
      say "WARN  ${LABEL} model: fixed prefix ${AI_DLC_FIXED_PREFIX_TOKENS} leaves only ${HEADROOM} tokens"
      say "      of post-compact headroom (want >= 60000). Expect rapid-refill thrash."
    fi
  fi
done <<EOF
$ROWS
EOF

if [ -z "$WINDOW" ]; then
  say ""
  say "NOTE  autoCompactWindow is unset, so each model falls back to its own maximum."
  say "      Set it in .claude/settings.json (integer, 100000-1000000) or via /config."
  say "      Only the row matching the model you actually run is binding."
fi

exit "$STATUS"
