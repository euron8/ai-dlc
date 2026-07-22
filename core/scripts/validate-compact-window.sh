#!/bin/bash
#
# AI/DLC Auto-Compact Window Validator
#
# The context sensor derives every band (yellow / red / imminent) as a CLAMPED
# PERCENTAGE of the resolved effective window. Each band's threshold is:
#
#     clamp(effectiveWindow * PCT/100, ceiling - MAX_LEAD, ceiling - MIN_LEAD)
#
# where ceiling = effectiveWindow - SENSOR_RESERVE. The percentage scales the band
# with the window; the clamp bounds keep the runway before compaction sane (a
# straight percentage fires red ~200 turns early on a 1M window and too late on a
# small one).
#
# Because the bands are anchored to the RESOLVED effective window and the clamp
# ranges do not overlap, the ordering yellow < red < imminent < compaction holds
# by construction for any window -- it no longer depends on a per-row table an
# operator could edit into a state where red never fires before the harness
# compacts. So this validator no longer re-derives thresholds per model row. It:
#
#   1. Reports the resolved autoCompactWindow and the settings layer it came from
#      (env > settings.local.json > project settings.json > user settings), and
#      FAILs on a value outside Claude Code's accepted range [100000, 1000000],
#      which the harness would silently discard back to the model default.
#
#   2. Guards the band constants so a bad override cannot invert the ordering:
#        - each MIN_LEAD in (0, MAX_LEAD)          (valid, positive clamp range)
#        - YELLOW_MIN_LEAD > RED_MAX_LEAD          (yellow range below red range)
#        - RED_MIN_LEAD    > IMMINENT_MAX_LEAD     (red range below imminent range)
#        - 0 < YELLOW_PCT < RED_PCT < IMMINENT_PCT <= 100   (monotonic middle)
#        - red keeps runway: (SENSOR_RESERVE + RED_MIN_LEAD) - COMPACT_RESERVE
#            >= MIN_RUNWAY   (red's closest-to-ceiling case still clears compaction)
#
# WHY RED-BEFORE-COMPACTION. If auto-compact fires at or before red, the lead
# never gets the high-fidelity path (finalize the snapshot, hand off, `/clear` +
# `/ai-dlc resume`), and a threshold near AI/DLC's resident prefix makes every
# post-compact turn refill immediately until the rapid-refill breaker halts the
# session. The runway guard keeps red safely ahead of it.
#
# Constants below are read from the installed Claude Code binary's behaviour and
# are stable across the 2.1.x line:
#   compact threshold = effectiveWindow - 13000
#   API hard block    = effectiveWindow -  3000
#   autoCompactWindow is an integer in [100000, 1000000]; the effective window is
#   min(setting, model max), so the setting can only ever lower the threshold.
#
# USAGE
#   scripts/ai-dlc/validate-compact-window.sh [--settings PATH] [--quiet]
#   (--skill and --row are accepted but ignored; the bands are row-independent.)
#
# EXIT
#   0  window in range and the band constants satisfy the ordering + runway guard
#   1  window out of range, or a band constant violates the guard

set -u

COMPACT_RESERVE=13000
SENSOR_RESERVE="${AI_DLC_SENSOR_RESERVE:-31000}"
YELLOW_PCT="${AI_DLC_SENSOR_YELLOW_PCT:-60}"
RED_PCT="${AI_DLC_SENSOR_RED_PCT:-75}"
IMMINENT_PCT="${AI_DLC_SENSOR_IMMINENT_PCT:-90}"
YELLOW_MIN_LEAD="${AI_DLC_SENSOR_YELLOW_MIN_LEAD:-89000}"
YELLOW_MAX_LEAD="${AI_DLC_SENSOR_YELLOW_MAX_LEAD:-200000}"
RED_MIN_LEAD="${AI_DLC_SENSOR_RED_MIN_LEAD:-49000}"
RED_MAX_LEAD="${AI_DLC_SENSOR_RED_MAX_LEAD:-88000}"
IMMINENT_MIN_LEAD="${AI_DLC_SENSOR_IMMINENT_MIN_LEAD:-20000}"
IMMINENT_MAX_LEAD="${AI_DLC_SENSOR_IMMINENT_MAX_LEAD:-24000}"
MIN_RUNWAY="${AI_DLC_COMPACT_MIN_RUNWAY:-20000}"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SETTINGS_JSON="${PROJECT_DIR}/.claude/settings.json"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --settings) SETTINGS_JSON="$2"; shift 2 ;;
    --skill)    shift 2 ;;   # accepted for compatibility; no longer read
    --row)      shift 2 ;;   # accepted for compatibility; bands are row-independent
    --quiet)    QUIET=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# -----------------------------------------------------------------------------
# autoCompactWindow resolution. parse_window() accepts Claude Code's own
# spellings ("auto", "400k", "1m", bare int where 100..1000 means thousands);
# resolve_window() walks the settings layers in Claude Code's precedence order.
#
# NOTE: parse_window() and resolve_window() below are byte-identical to the
# copies in core/hooks/ai-dlc-context-sensor.sh. Hooks install to .claude/hooks/
# and cannot source from scripts/, so they are duplicated deliberately. Keep the
# two in step.
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

# The highest-precedence layer that DEFINES autoCompactWindow wins; a layer that
# does not set the key does not shadow a lower one; a defining layer whose value
# is unparseable ("auto") or otherwise not a plain integer resolves to the model
# default and lower layers are not consulted -- this mirrors Claude Code's own
# config merge.
resolve_window() {
  local raw val
  if [ -n "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}" ]; then
    if val="$(parse_window "$CLAUDE_CODE_AUTO_COMPACT_WINDOW")"; then printf '%s' "$val"; fi
    return 0
  fi
  for f in "$SETTINGS_LOCAL" "$SETTINGS_PROJECT" "$SETTINGS_USER"; do
    [ -r "$f" ] || continue
    raw="$(jq -r '.autoCompactWindow // empty' "$f" 2>/dev/null || true)"
    [ -n "$raw" ] || continue
    if val="$(parse_window "$raw")"; then printf '%s' "$val"; fi
    return 0
  done
}

# --settings overrides the PROJECT layer; local and user layers derive from
# PROJECT_DIR and CLAUDE_CONFIG_DIR/HOME.
SETTINGS_LOCAL="${PROJECT_DIR}/.claude/settings.local.json"
SETTINGS_PROJECT="$SETTINGS_JSON"
SETTINGS_USER="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

WINDOW="$(resolve_window 2>/dev/null || true)"
case "${WINDOW:-}" in ''|*[!0-9]*) WINDOW="" ;; esac

# Report the layer the winning value came from (mirrors resolve_window's order).
WINDOW_SOURCE="unset (model default)"
if [ -n "$WINDOW" ]; then
  if [ -n "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}" ]; then
    WINDOW_SOURCE="env CLAUDE_CODE_AUTO_COMPACT_WINDOW"
  else
    for pair in "settings.local.json:$SETTINGS_LOCAL" "settings.json:$SETTINGS_PROJECT" "user settings:$SETTINGS_USER"; do
      f="${pair#*:}"
      [ -r "$f" ] || continue
      raw="$(jq -r '.autoCompactWindow // empty' "$f" 2>/dev/null || true)"
      [ -n "$raw" ] || continue
      WINDOW_SOURCE="${pair%%:*}"
      break
    done
  fi
fi

if [ -n "$WINDOW" ]; then
  if [ "$WINDOW" -lt 100000 ] || [ "$WINDOW" -gt 1000000 ]; then
    echo "FAIL: autoCompactWindow=${WINDOW} is outside Claude Code's accepted range [100000, 1000000]." >&2
    echo "      Values outside the range are silently discarded, so the model default applies." >&2
    exit 1
  fi
fi

say "auto-compact window : ${WINDOW:-<model default>}  (source: ${WINDOW_SOURCE})"
say "reserves            : compaction ${COMPACT_RESERVE}, sensor ${SENSOR_RESERVE}"
say "band percentages    : yellow ${YELLOW_PCT}% < red ${RED_PCT}% < imminent ${IMMINENT_PCT}%"
say "clamp leads (min..max below ceiling):"
say "  yellow   ${YELLOW_MIN_LEAD}..${YELLOW_MAX_LEAD}"
say "  red      ${RED_MIN_LEAD}..${RED_MAX_LEAD}"
say "  imminent ${IMMINENT_MIN_LEAD}..${IMMINENT_MAX_LEAD}"
say ""

STATUS=0

# -----------------------------------------------------------------------------
# Guard 1: each clamp range is valid and positive (0 < MIN_LEAD < MAX_LEAD).
# -----------------------------------------------------------------------------
range_ok() { # $1 label  $2 min  $3 max
  if [ "$2" -gt 0 ] && [ "$3" -gt "$2" ]; then
    return 0
  fi
  STATUS=1
  say "FAIL  ${1} clamp range invalid: need 0 < MIN_LEAD (${2}) < MAX_LEAD (${3})."
  return 1
}
range_ok "yellow"   "$YELLOW_MIN_LEAD"   "$YELLOW_MAX_LEAD"   && \
range_ok "red"      "$RED_MIN_LEAD"      "$RED_MAX_LEAD"      && \
range_ok "imminent" "$IMMINENT_MIN_LEAD" "$IMMINENT_MAX_LEAD" && \
  say "PASS  each clamp range is valid and positive."

# -----------------------------------------------------------------------------
# Guard 2: the clamp ranges do not overlap, which makes yellow < red < imminent
# hold for every window. A larger lead is further below the ceiling (earlier).
# -----------------------------------------------------------------------------
if [ "$YELLOW_MIN_LEAD" -gt "$RED_MAX_LEAD" ] && [ "$RED_MIN_LEAD" -gt "$IMMINENT_MAX_LEAD" ]; then
  say "PASS  clamp ranges ordered and disjoint: yellow_min(${YELLOW_MIN_LEAD}) > red_max(${RED_MAX_LEAD}), red_min(${RED_MIN_LEAD}) > imminent_max(${IMMINENT_MAX_LEAD})."
else
  STATUS=1
  say "FAIL  clamp ranges overlap, so band ordering is not guaranteed. Need"
  say "      YELLOW_MIN_LEAD (${YELLOW_MIN_LEAD}) > RED_MAX_LEAD (${RED_MAX_LEAD}) and"
  say "      RED_MIN_LEAD (${RED_MIN_LEAD}) > IMMINENT_MAX_LEAD (${IMMINENT_MAX_LEAD})."
fi

# -----------------------------------------------------------------------------
# Guard 3: percentages are monotonic and in range, so the proportional middle of
# each band is ordered too (the disjoint clamps already guarantee the extremes).
# -----------------------------------------------------------------------------
if [ "$YELLOW_PCT" -gt 0 ] && [ "$YELLOW_PCT" -lt "$RED_PCT" ] \
   && [ "$RED_PCT" -lt "$IMMINENT_PCT" ] && [ "$IMMINENT_PCT" -le 100 ]; then
  say "PASS  percentages monotonic: 0 < ${YELLOW_PCT} < ${RED_PCT} < ${IMMINENT_PCT} <= 100."
else
  STATUS=1
  say "FAIL  percentages not monotonic. Need 0 < YELLOW_PCT (${YELLOW_PCT}) < RED_PCT (${RED_PCT}) < IMMINENT_PCT (${IMMINENT_PCT}) <= 100."
fi

# -----------------------------------------------------------------------------
# Guard 4: runway. red's closest-to-ceiling case fires at ceiling - RED_MIN_LEAD;
# the harness compacts at ceiling + (SENSOR_RESERVE - COMPACT_RESERVE). The gap is
# window-independent: (SENSOR_RESERVE + RED_MIN_LEAD) - COMPACT_RESERVE.
# -----------------------------------------------------------------------------
GAP=$(( SENSOR_RESERVE + RED_MIN_LEAD - COMPACT_RESERVE ))
if [ "$GAP" -ge "$MIN_RUNWAY" ]; then
  say "PASS  red fires at least ${GAP} tokens before compaction (>= ${MIN_RUNWAY} runway)."
else
  STATUS=1
  say "FAIL  red's tightest case fires only ${GAP} tokens before compaction (want >= ${MIN_RUNWAY})."
  say "      Raise AI_DLC_SENSOR_RED_MIN_LEAD so the handoff gets first refusal."
fi

# Warn-only: the fixed prefix is not knowable from a script. It is the system
# prompt + tool schemas + MCP schemas + CLAUDE.md + re-attached skills, which
# survive compaction and are therefore the floor a post-compact turn starts from.
# `/context` reports it. If it crowds the threshold, every post-compact turn
# refills immediately and the rapid-refill breaker trips. Only computable when a
# window is resolved (it caps the effective window regardless of model row).
if [ -n "$WINDOW" ] && [ -n "${AI_DLC_FIXED_PREFIX_TOKENS:-}" ]; then
  THRESHOLD=$(( WINDOW - COMPACT_RESERVE ))
  HEADROOM=$(( THRESHOLD - AI_DLC_FIXED_PREFIX_TOKENS ))
  if [ "$HEADROOM" -lt 60000 ]; then
    say "WARN  fixed prefix ${AI_DLC_FIXED_PREFIX_TOKENS} leaves only ${HEADROOM} tokens of"
    say "      post-compact headroom (want >= 60000). Expect rapid-refill thrash."
  fi
fi

if [ -z "$WINDOW" ]; then
  say ""
  say "NOTE  autoCompactWindow is unset, so each model falls back to its own maximum;"
  say "      the bands scale with whichever ceiling applies, clamped to the leads above."
fi

exit "$STATUS"
