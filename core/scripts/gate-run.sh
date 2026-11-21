#!/usr/bin/env bash
# gate-run.sh -- run a step-closing gate as ONE program: `arms` runs the gate's script arms
# and opens the checkpoint, `close` adopts the adjudicator's verdict and writes the gate's
# records. The decisions live in gate_run.py beside this file; this wrapper resolves the root.
#
# usage:
#   gate-run.sh arms  --gate <gate-id> --sprint N --step <step.md> [--story FILE]...
#                     [--base SHA] [--sha SHA] [--transcript FILE] [--transcript-dir D]
#                     [--series PREFIX] [--worktree ABS-DIR] [--root P]
#   gate-run.sh close --gate <gate-id> --nonce <n> --sprint N --step <step.md>
#                     [--transcript FILE] [--transcript-dir D] [--verdict PATH] [--root P]
#   gate-run.sh --help | --self-probe
#
# The gate's rows come from gates/<gate-id>.arms (`# gate_type: <type>` header, then
# `<check-id> TAB <kind> TAB <arm> TAB <count> [TAB skip=<tok>[,<tok>]]`).
#   kind   script | rule | judgment | multi | lead
#   count  native | legacy | -
#
# stdout, one line per row:
#   GATE-RESULT <check-id> <PASS|FAIL|SKIP|PENDING> examined=<n|-> evidence=<path:line|reason=tok|-> <message>
# then, in `arms`, either
#   REMEDY <check-id> <text>                (one per FAIL; exit 1; no nonce, no OPEN, no worklist)
#   ADJUDICATE <worklist-path> nonce=<n>    (judgment rows remain)   or   ADJUDICATE none
# and last
#   GATE-RUN <gate-id> <arms|close> <PASS|FAIL|ADJUDICATE> nonce=<n|-> pass=a fail=b skip=c pending=d
# A native arm prints, per id it declares:
#   GATE-ARM <check-id> <PASS|FAIL|SKIP> examined=<n> <path:line|reason=tok> <message>
#
# exit: 0 the phase passed (ADJUDICATE included)   1 refusal, every FAIL reported at once
#       2 could not run (bad usage, missing/empty .arms, unknown gate id, unfilled placeholder)
gr_main() {
set -uo pipefail
# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
GR_SELF="$AI_DLC_SELF_DIR"
case "${1:-}" in
  --help) sed -n '2,/^gr_main/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
  -h) sed -n '2,/^gr_main/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[ -f "$GR_SELF/gate_run.py" ] || { echo "gate-run: gate_run.py is not beside this script at $GR_SELF" >&2; exit 2; }
GR_SELF="$GR_SELF" GR_ROOT="$AI_DLC_ROOT" exec python3 "$GR_SELF/gate_run.py" "$@"
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
gr_main "$@"
