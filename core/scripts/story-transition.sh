#!/usr/bin/env bash
# story-transition.sh -- one call per story transition during implementation: the snapshot row and
# the Seam C auto-handoff check. The lead runs it where it ran two separate steps (a snapshot update,
# an auto-handoff evaluation). It writes no gate-log line: the snapshot activity row is the record.
#
# usage:
#   story-transition.sh <story-id> <from-status> <to-status> <teammate> [--no-seam] [-- <snapshot-update.sh op> ...]
#   --no-seam  write the snapshot row only; Seam C is not evaluated and no SEAM-C line is printed (the caller
#              evaluates it itself; dispatch-story.sh passes it, the lead's per-transition check follows the Agent call).
#
# 1. SNAPSHOT. `snapshot-update.sh --activity '<utc> story <id> <from>-><to> (<teammate>)'` plus every op
#    after `--`, in ONE call. snapshot-update.sh is the only snapshot writer; this program never edits the
#    snapshot, and a refusal of that call (exit 1 or 2) is this program's exit, with nothing else written.
# 2. SEAM C. Preconditions 1-3 of `_gate-procedures.md` "Auto-handoff evaluation" that a program can read:
#    the mode gate (`AI_DLC_AUTO_HANDOFF_MODE` in `.claude/settings.json` env; only `safe-seam` reaches Seam C),
#    the seam exclusion (`AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED`), and a current snapshot (step 1 just wrote it).
#    The LAST output line is `SEAM-C: CONTINUE <reason>` or `SEAM-C: FIRE`. FIRE means preconditions 1-3
#    hold; the lead then checks 6 (no teammate awaiting a response) and 7 (no Rule 3 pause point) and runs
#    the Rule 2(a) handoff; this program never ends the session itself.
#
# exit 0 written (read the SEAM-C line); 1 the snapshot call refused on a finding; 2 usage or environment.
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
refuse() { printf 'story-transition.sh: %s\n' "$*" >&2; exit 2; }

[ "$#" -ge 4 ] || refuse "usage: story-transition.sh <story-id> <from-status> <to-status> <teammate> [--no-seam] [-- <snapshot-update.sh op> ...]"
STORY="$1"; FROM="$2"; TO="$3"; TEAMMATE="$4"; shift 4
NO_SEAM=0
if [ "$#" -gt 0 ] && [ "$1" = "--no-seam" ]; then NO_SEAM=1; shift; fi
for v in "$STORY" "$FROM" "$TO" "$TEAMMATE"; do
  case "$v" in '' | *[!A-Za-z0-9._-]*) refuse "'$v' is not a plain token (letters, digits, . _ -)" ;; esac
done
if [ "$#" -gt 0 ]; then
  [ "$1" = "--" ] || refuse "extra ops follow a literal --; got '$1'"
  shift
fi

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of `..` hops
# (distribution, consumer scripts/ai-dlc/, and older consumer layouts all run this script).
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
ST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ST_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$ST_ROOT" ] || ST_ROOT="$(ai_dlc_resolve_root "$ST_SCRIPT_DIR" || true)"
[ -n "$ST_ROOT" ] || ST_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$ST_ROOT" ] || ST_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
ST_ROOT="${ST_ROOT:-/nonexistent}"
# --- end AI_DLC_ROOT --------------------------------------------------------
[ -d "$ST_ROOT" ] || refuse "no project root: none found above $ST_SCRIPT_DIR or $(pwd); set AI_DLC_PROJECT_ROOT"
ROOT="$ST_ROOT"
STATE="$ROOT/${AI_DLC_STATE_DIR:-_bmad-output}"
case "${AI_DLC_STATE_DIR:-}" in /*) STATE="$AI_DLC_STATE_DIR" ;; esac
SNAP="$STATE/pipeline-snapshot.md"
SU="$SELF_DIR/snapshot-update.sh"
[ -f "$SU" ] || refuse "snapshot-update.sh is not beside this program ($SELF_DIR)"
[ -f "$SNAP" ] || refuse "no snapshot at $SNAP"

TS="$(date -u +%Y-%m-%dT%H:%MZ)"
bash "$SU" --snapshot "$SNAP" --activity "$TS story $STORY $FROM->$TO ($TEAMMATE)" "$@"
rc=$?
[ "$rc" -eq 0 ] || { printf 'story-transition.sh: snapshot-update.sh exited %s; Seam C not evaluated\n' "$rc" >&2; exit "$rc"; }

[ "$NO_SEAM" -eq 0 ] || exit 0

# Seam C, preconditions 1-3.
settings_env() {
  [ -f "$ROOT/.claude/settings.json" ] || return 0
  command -v jq > /dev/null 2>&1 || return 0
  jq -r --arg k "$1" '.env[$k] // empty' "$ROOT/.claude/settings.json" 2> /dev/null
}
MODE="$(settings_env AI_DLC_AUTO_HANDOFF_MODE)"
EXCL="$(settings_env AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED)"
case "$MODE" in
  safe-seam) ;;
  deploy-only) echo "SEAM-C: CONTINUE mode deploy-only reaches Seam A only"; exit 0 ;;
  *) echo "SEAM-C: CONTINUE auto_handoff_mode is off (AI_DLC_AUTO_HANDOFF_MODE='${MODE}')"; exit 0 ;;
esac
case ",$(printf '%s' "$EXCL" | tr -d ' ')," in
  *,C,*) echo "SEAM-C: CONTINUE Seam C is in AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED"; exit 0 ;;
esac
echo "SEAM-C: FIRE"
