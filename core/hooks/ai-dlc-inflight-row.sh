#!/usr/bin/env bash
#
# AI/DLC In-Flight Row Hook  (PostToolUse Agent|Task, SubagentStop)
#
# PURPOSE
# Writes the lead's `## In-Flight Teammates` rows in pipeline-snapshot.md, so the lead never
# adds one by Edit or Write. Every write goes through `snapshot-update.sh`, which runs the
# stamp check and holds the snapshot lock; this hook never touches the snapshot itself.
#
#   PostToolUse, the tool_response status async_launched  -> `--row-add ... | in-flight`
#   PostToolUse, status completed (a foreground dispatch)  -> the row as `delivered-reachable`
#                                                             when its deliverable is on disk,
#                                                             otherwise no row
#   SubagentStop, the agent's row in-flight, deliverable on disk -> `--row-status delivered-reachable`
#
# Nothing here ever writes `stopped`. That status stays the lead's TaskStop path, through an op.
#
# THE ROW. `<agentId> <toolu_id> | <role> | <deliverable> | <dispatched-at> | <status>`.
#   - The agent cell carries BOTH ids, so the LATE arm of validate-artifact-budget.sh resolves the
#     row from the spawn ledger alone (the toolu_ candidate) in any session, not only the
#     dispatching one.
#   - dispatched-at is `wait-for-deliverable.sh --dispatch-ts <toolu_id>`: the ledger row's own
#     `ts`, copied, never a clock reading.
#   - role is the ledger row's `role`, which the dispatch guard bound.
#   - deliverable comes from deliverable_of() below, and from the ledger's `mark_file` when the
#     brief carries no parseable path. No path from either means NO ROW: a wrong path makes the
#     waiter wait on the wrong file, which is worse than a missing row.
#
# THE ERA GATE. Registration reaches a consumer at step 3b of the pull, before the reconcile merge
# delivers the step files that stop the lead writing rows itself. Until those step files are
# installed, this hook writes nothing, so a row is never written twice. The gate is ERA_SENTINEL
# below, read with grep -F from the installed `.claude/skills/ai-dlc/steps/_gate-procedures.md`
# (else `core/skills/ai-dlc/steps/_gate-procedures.md`, as in this repo). The full sentence the
# step file carries, on ONE line:
#   In-Flight Teammates rows are written by the ai-dlc-inflight-row hook; the lead never adds one by Edit or Write.
# Neither file readable, or the sentinel absent: exit 0, nothing written.
#
# EXIT SEMANTICS, MEASURED LIVE (CC headless, haiku, a fresh scratch project per probe):
#   - PostToolUse runs AFTER the Agent tool. Exit 2 there put the stderr in front of the model as
#     "PostToolUse:Agent hook blocking error ...". The background agent still ran to completion and
#     wrote its file. A JSON `systemMessage` with exit 0 reached the UI only. It never appeared in
#     the API request, so the lead would never see it. So every failure on this branch is EXIT 2,
#     and the stderr opens by saying the dispatch ran and must not be re-dispatched.
#   - SubagentStop exit 2 BLOCKED the subagent from stopping. The subagent took the stderr as an
#     instruction and acted on it. An `additionalContext` with exit 0 re-fired SubagentStop nine
#     times for one agent. Everything SubagentStop printed landed in the SUBAGENT's transcript and
#     never in the lead's. So the SubagentStop branch ALWAYS exits 0, writes nothing to stdout, and
#     its failures are silent to the lead by construction. The recovery path is the waiter's
#     `--dispatch` beat, which writes the same status on DELIVERED.
#
# SKIPS, each exit 0 with no write:
#   - a payload `agent_id` on PostToolUse: an Agent call made from inside a subagent (a nested
#     spawn), which the lead does not track
#   - no single spawn-ledger row for the `tool_use_id`
#   - no snapshot file: no pipeline run is in progress
#   - jq absent
#
# Installation: registered by templates/settings.json.template on PostToolUse `Agent|Task` and on
# SubagentStop; install.sh copies core/hooks/*.sh by glob.
set -u

ERA_SENTINEL='rows are written by the ai-dlc-inflight-row hook'

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of `..` hops:
# this runs from <root>/core/hooks/ and from a consumer's <root>/.claude/hooks/.
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
[ -n "$AI_DLC_ROOT" ] || exit 0
# --- end AI_DLC_ROOT --------------------------------------------------------
ROOT="$AI_DLC_ROOT"

INPUT="$(cat)"
command -v jq > /dev/null 2>&1 || exit 0

EVENT="$(jq -r '.hook_event_name // empty' <<< "$INPUT" 2> /dev/null)"
case "$EVENT" in PostToolUse|SubagentStop) ;; *) exit 0 ;; esac

# The era gate (header: THE ERA GATE).
era_held() {
  local f
  for f in "$ROOT/.claude/skills/ai-dlc/steps/_gate-procedures.md" "$ROOT/core/skills/ai-dlc/steps/_gate-procedures.md"; do
    [ -r "$f" ] || continue
    grep -qF -- "$ERA_SENTINEL" "$f"; return $?
  done
  return 1
}
era_held || exit 0

case "${AI_DLC_STATE_DIR:-}" in
  /*) STATE_DIR="$AI_DLC_STATE_DIR" ;;
  *)  STATE_DIR="${ROOT}/${AI_DLC_STATE_DIR:-_bmad-output}" ;;
esac
SNAP="$STATE_DIR/pipeline-snapshot.md"
LEDGER="$STATE_DIR/spawn-ledger.jsonl"
[ -f "$SNAP" ] || exit 0

# THE UPDATER GATE. An /ai-dlc-update session dispatches teammates of its own and has a ledger row
# for each, but its snapshot is not a pipeline run's: no row is written and nothing is printed.
# The marker is the transcript's last /ai-dlc or /ai-dlc-update invocation (I126).
TRANSCRIPT="$(jq -r '.transcript_path // empty' <<< "$INPUT" 2> /dev/null)"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
  # >>> I126 SESSION-MARKER SCAN: the next line, byte-identical in every bound hook >>>
  LAST_SKILL=$(grep -oE '"role":"user","content":"<command-message>ai-dlc(-update)?</command-message>\\n<command-name>/ai-dlc(-update)?</command-name>|"name":"Skill","input":\{"skill":"ai-dlc(-update)?"' "$TRANSCRIPT" 2>/dev/null | tail -1)
  case "$LAST_SKILL" in
    *'/ai-dlc-update</command-name>'|*'"skill":"ai-dlc-update"') exit 0 ;;
  esac
fi

# The sibling programs, in the installed layout first and then this repo's.
sibling() {
  local c
  for c in "$ROOT/scripts/ai-dlc/$1" "$ROOT/core/scripts/$1"; do
    [ -f "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}
SU="$(sibling snapshot-update.sh || true)"
WFD="$(sibling wait-for-deliverable.sh || true)"
SU_SHOW="${SU#"$ROOT"/}"; [ -n "$SU_SHOW" ] || SU_SHOW="scripts/ai-dlc/snapshot-update.sh"

SESSION_ID="$(jq -r '.session_id // empty' <<< "$INPUT" 2> /dev/null)"
export AI_DLC_PROJECT_ROOT="$ROOT"
# THE LOCK WAIT. snapshot-update.sh waits AI_DLC_SNAPSHOT_LOCK_TENTHS for its lock (its own default,
# 100, is 10 s). Graph leads were measured sending up to 42 Agent calls together as parallel calls,
# the PostToolUse hooks of those calls run concurrently, and one hook-shaped write measured ~0.72 s on graph-sized files, so
# a fan passes 10 s around its 15th hook and that hook's write exits 3. 450 (45 s) holds a 42-wide
# queue, 42 x 0.72 s ~ 30 s, and stays well under Claude Code's 600 s default command-hook timeout
# for PostToolUse and SubagentStop. It is set here, above both branches, because SubagentStop writes
# contend for the same lock. A value the caller already set is kept, so a fixture keeps control of
# the wait.
[ -n "${AI_DLC_SNAPSHOT_LOCK_TENTHS:-}" ] || export AI_DLC_SNAPSHOT_LOCK_TENTHS=450
[ -n "$SESSION_ID" ] && export CLAUDE_CODE_SESSION_ID="$SESSION_ID"

# deliverable_of: the brief on stdin -> the deliverable path on stdout, or nothing.
# THE GRAMMAR: the FIRST line of the brief that begins `Deliverable:`. Its first path-shaped token
# is the path: backticks stripped, trailing `.,;:)` stripped, and path-shaped meaning it carries a
# `/` or ends in a dotted extension. So `Deliverable: write test-results/x.md in your worktree`
# gives test-results/x.md and never `write`. A token carrying `|` would break the row's cell count
# and is never taken. A `Deliverable:` line with no such token gives nothing; no later line is read.
deliverable_of() {
  LC_ALL=C awk '
    /^Deliverable:/ {
      sub(/^Deliverable:[[:blank:]]*/, "")
      n = split($0, w, /[[:blank:]]+/)
      for (i = 1; i <= n; i++) {
        t = w[i]; gsub(/`/, "", t); sub(/^[(]+/, "", t); sub(/[.,;:)]+$/, "", t)
        if (t == "" || index(t, "|")) continue
        if (t ~ /\// || t ~ /\.[A-Za-z0-9]+$/) { print t; exit }
      }
      exit
    }'
}

# present: the deliverable is on disk and non-empty, root-relative or absolute.
present() {
  case "$1" in
    /*) [ -s "$1" ] ;;
    *)  [ -s "$ROOT/$1" ] ;;
  esac
}

# row_of <agentId>: the In-Flight Teammates row whose agent cell's first word is <agentId>, as
# `<status>\t<deliverable>`, read by header name. Nothing when no such row exists.
row_of() {
  SU_AG="$1" LC_ALL=C awk -F'|' '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^## / { ins = (index($0, "## In-Flight Teammates") == 1); next }
    !ins || index($0, "|") == 0 { next }
    {
      line = $0; sub(/^[ \t]*\|/, "", line); sub(/\|[ \t]*$/, "", line)
      k = split(line, c, "|")
      if (!hdr) {
        for (j = 1; j <= k; j++) { h = trim(c[j]); if (h == "status") sc = j; if (h == "deliverable") dc = j; if (h == "dispatched-at") hdr = 1 }
        next
      }
      a = trim(c[1]); split(a, aw, /[ \t]+/)
      if (aw[1] == ENVIRON["SU_AG"] && sc && dc) { printf "%s\t%s\n", trim(c[sc]), trim(c[dc]); exit }
    }' "$SNAP"
}

if [ "$EVENT" = SubagentStop ]; then
  # Always exit 0, nothing on stdout (header: EXIT SEMANTICS).
  AG="$(jq -r '.agent_id // empty' <<< "$INPUT" 2> /dev/null)"
  [ -n "$AG" ] && [ -n "$SU" ] || exit 0
  ROW="$(row_of "$AG")"
  [ -n "$ROW" ] || exit 0
  ST="${ROW%%	*}"; DL="${ROW#*	}"
  [ "$ST" = in-flight ] || exit 0
  DL="$(printf '%s' "$DL" | tr -d '`')"
  [ -n "$DL" ] && present "$DL" || exit 0
  bash "$SU" --snapshot "$SNAP" --row-status "$AG" delivered-reachable > /dev/null 2>&1 || true
  exit 0
fi

# --- PostToolUse -------------------------------------------------------------
TOOL="$(jq -r '.tool_name // empty' <<< "$INPUT" 2> /dev/null)"
case "$TOOL" in Agent|Task) ;; *) exit 0 ;; esac
[ -z "$(jq -r '.agent_id // empty' <<< "$INPUT" 2> /dev/null)" ] || exit 0
TUI="$(jq -r '.tool_use_id // empty' <<< "$INPUT" 2> /dev/null)"
case "$TUI" in ''|*[!A-Za-z0-9_]*) exit 0 ;; esac
[ -r "$LEDGER" ] || exit 0
LROW="$(grep -F "\"tool_use_id\":\"$TUI\"" "$LEDGER" 2> /dev/null)"
[ "$(printf '%s' "$LROW" | grep -c .)" = 1 ] || exit 0

RS="$(jq -r '.tool_response.status // empty' <<< "$INPUT" 2> /dev/null)"
case "$RS" in
  async_launched) STATUS=in-flight ;;
  completed)      STATUS=delivered-reachable ;;
  *)              exit 0 ;;
esac
AG="$(jq -r '.tool_response.agentId // empty' <<< "$INPUT" 2> /dev/null)"
case "$AG" in *[!A-Za-z0-9_@.-]*) AG="" ;; esac
CELL="${AG:+$AG }$TUI"
ROLE="$(jq -r '.role // empty' <<< "$LROW" 2> /dev/null | tr -d '|')"
[ -n "$ROLE" ] || ROLE="$(jq -r '.tool_input.subagent_type // empty' <<< "$INPUT" 2> /dev/null | tr -d '|')"
[ -n "$ROLE" ] || ROLE=unknown

DL="$(jq -r '.tool_input.prompt // empty' <<< "$INPUT" 2> /dev/null | deliverable_of)"
if [ -z "$DL" ]; then
  DL="$(jq -r '.mark_file // empty' <<< "$LROW" 2> /dev/null)"
  case "$DL" in \"*\"|\'*\') DL="${DL#?}"; DL="${DL%?}" ;; esac
  case "$DL" in *'|'*) DL="" ;; esac
fi

TS=""
[ -n "$WFD" ] && TS="$(bash "$WFD" --dispatch-ts "$TUI" 2> /dev/null)" || TS=""

# A foreground dispatch whose deliverable is not on disk gets no row: nothing is in flight.
if [ "$STATUS" = delivered-reachable ] && { [ -z "$DL" ] || ! present "$DL"; }; then exit 0; fi

say_unwritten() {  # $1 = why; exit 2 (header: EXIT SEMANTICS)
  {
    printf 'AI/DLC in-flight row NOT written for dispatch %s. The dispatch ran and the agent is running: do NOT re-dispatch it.\n' "$CELL"
    printf 'Why: %s\n' "$1"
    printf 'Write the row with this one call:\n'
    case "$1" in
      # --row-add refuses an existing row that carries this id with different cells, and a repeat of it loops.
      *--row-replace*) printf "  bash %s --row-replace <agent: the first word of the existing row> '%s | %s | %s | %s | %s'\n" "$SU_SHOW" "$CELL" "$ROLE" "${DL:-<deliverable path>}" "${TS:-<wait-for-deliverable.sh --dispatch-ts $TUI>}" "$STATUS" ;;
      *) printf "  bash %s --row-add '%s | %s | %s | %s | %s'\n" "$SU_SHOW" "$CELL" "$ROLE" "${DL:-<deliverable path>}" "${TS:-<wait-for-deliverable.sh --dispatch-ts $TUI>}" "$STATUS" ;;
    esac
  } >&2
  exit 2
}

[ -n "$DL" ] || say_unwritten "the brief carries no \`Deliverable: <path>\` line with a path, and the spawn ledger row carries no mark_file."
[ -n "$TS" ] || say_unwritten "wait-for-deliverable.sh --dispatch-ts $TUI printed no ledger ts${WFD:- (wait-for-deliverable.sh is not installed)}."
[ -n "$SU" ] || say_unwritten "snapshot-update.sh is not installed under scripts/ai-dlc/."

# A row this dispatch already has (a SubagentStop or a concurrent call wrote nothing, but a
# re-fired hook or the lead may have): set its status instead of adding a second.
FIRST="${CELL%% *}"
if [ -n "$(row_of "$FIRST")" ]; then
  [ "$STATUS" = delivered-reachable ] || exit 0
  OUT="$(bash "$SU" --snapshot "$SNAP" --row-status "$FIRST" "$STATUS" 2>&1)" \
    || say_unwritten "snapshot-update.sh --row-status exited $?: $(printf '%s' "$OUT" | head -3 | tr '\n' ' ')"
  exit 0
fi
OUT="$(bash "$SU" --snapshot "$SNAP" --row-add "$CELL | $ROLE | $DL | $TS | $STATUS" 2>&1)" \
  || say_unwritten "snapshot-update.sh --row-add exited $?: $(printf '%s' "$OUT" | head -3 | tr '\n' ' ')"
exit 0
