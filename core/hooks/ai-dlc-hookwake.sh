#!/bin/bash
#
# ai-dlc-hookwake.sh -- UserPromptSubmit: suppress a lead wake that carries a subagent's
# completion when the lead's OWN armed wait-for-deliverable beat will wake it anyway and every
# path that beat joins is already DELIVERED, so the lead wakes once (from the beat).
#
# OPT-IN, DEFAULT OFF. Nothing happens unless AI_DLC_HOOKWAKE=1 is in the hook's environment.
# The settings template registers the hook and sets no env, and settings-merge.sh never writes
# `env`, so turning it on is the consumer's own edit.
#
# FAILS OPEN, EVERYWHERE. Every unrecognised shape, every harness-format change, every missing
# file, tool or helper, and every error ends in exit 0 with EMPTY stdout -- the prompt goes
# through untouched. The decision runs in a subshell whose output is printed only when it
# returned 0 AND is one valid JSON object, so a `set -u` abort, a jq failure or a partial
# write can never leak a block.
#
# THE PREDICATE, cheapest first. The prompt is BLOCKED only if every step holds:
#   P0  AI_DLC_HOOKWAKE=1, else stdin is drained and the hook exits before reading the prompt.
#   P5  exactly one channel, every harness literal read from schemas/harness-origin.json
#       (`handback.agent_message_from`, `handback.frame`, `prefixes`); a missing schema or key
#       PASSES:
#         (H) the prompt starts with handback.agent_message_from + `a`<16 hex> + `">`, and its
#             SECOND line starts with handback.frame at column zero;
#         (N) the prompt starts with a declared prefix + `>` LF `<task-id>a<16 hex></task-id>`,
#             and its first `<status>` line is `completed`.
#       A `b`<8> task id in the (N) shape is the beat's own Bash wake: it is never blocked, and
#       it carries C5's emission (below).
#   LEASE  `_bmad-output/.beat-inflight` names a future epoch; else PASS. A fast path only --
#       it is never sufficient.
#   P4  the agent's role, agent id -> `agent-<id>.meta.json` `toolUseId` -> spawn-ledger row
#       `role`, is in the blockable-role vocabulary below AND its role file exists.
#   J1  the lead transcript's bounded tail holds EXACTLY ONE outstanding beat: a background
#       Bash tool_use running wait-for-deliverable.sh whose tool_use id appears in no
#       `<tool-use-id>` of any later record (enqueue, delivered notification, attachment).
#       Its task id is the `toolUseResult.backgroundTaskId` of its tool_result.
#   J2  exactly ONE live `.beat-argv-<pid>` record for this session: pid alive and its start
#       time (wfd_start_of) equal to the recorded one.
#   J1=J2  the record's `task_id` is non-empty and equals J1's task id (the task-id join).
#   J3  the prompt's agent id is in the record's --dispatch set (from its argv, never from the
#       transcript's command text). The decoder also skips wait-for-deliverable.sh's other
#       value-taking flags, --since, --progress-path and --shard-header, together with their
#       value, so the value is not collected as a target path. They are the beat's flags, passed
#       through to J4's --status; none is a mode of this hook.
#   J4  wait-for-deliverable.sh --status, run with the record's argv minus --reset and
#       --quiet, its cwd and settings, and CLAUDE_CODE_SESSION_ID exported from the PAYLOAD's
#       session_id, exits 0 and reports every path DELIVERED.
#   P2  ai-dlc-dispatch-guard.sh --hold-status reports no live rejected-spawn hold (exit 0).
#       Exit 1 or 2, or a guard without the mode, PASSES.
#
# THE BLOCK RECORD. One JSON line per block to ${STATE_DIR}/.hookwake-blocks.jsonl:
# {ts, channel, agent_id, beat_task_id, record_pid, paths}. `paths` is the beat's deliverable
# targets (absolute), carried so C5 can name them after the beat's own record is gone. A write
# failure never changes the decision.
#
# C5 -- THE LEAD IS TOLD WHAT IT DID NOT SEE. On the beat's own `b…` wake, which is never
# blocked, the hook emits additionalContext naming every agent it blocked under that beat's
# task id: the deliverable path(s) and `.subagent-final/<agent_id>.txt`, and the instruction to
# read them before treating a missing report as non-delivery.
#
# INSTALL: wired by templates/settings.json.template (UserPromptSubmit, beside ai-dlc-pause.sh).

set -u

# --- P0: off unless opted in. Drain stdin first so the harness never sees a broken pipe. ---
if [ "${AI_DLC_HOOKWAKE:-}" != "1" ]; then
  cat >/dev/null 2>&1 || true
  exit 0
fi

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
case "${AI_DLC_STATE_DIR:-}" in
  /*) STATE_DIR="$AI_DLC_STATE_DIR" ;;
  *)  STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}" ;;
esac
BLOCKS_FILE="${STATE_DIR}/.hookwake-blocks.jsonl"
LEASE_HOME="${PROJECT_DIR}/_bmad-output"     # where wait-for-deliverable.sh writes the lease
LEASE_DIR="${LEASE_HOME}/.wait-beats"
HW_SELF="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0

# SIBLING RESOLUTION: self-relative first (core/hooks -> core/schemas upstream, .claude/hooks ->
# .claude/schemas in a consumer), then the two PROJECT_DIR layouts, as ai-dlc-pause.sh does.
HW_SCHEMA=""
for _c in "${HW_SELF}/../schemas/harness-origin.json" \
          "${PROJECT_DIR}/.claude/schemas/harness-origin.json" \
          "${PROJECT_DIR}/core/schemas/harness-origin.json"; do
  [ -f "$_c" ] && { HW_SCHEMA="$_c"; break; }
done
HW_ROLES_DIR=""
for _c in "${HW_SELF}/../team-roles" "${PROJECT_DIR}/.claude/team-roles" "${PROJECT_DIR}/core/team-roles"; do
  [ -d "$_c" ] && { HW_ROLES_DIR="$_c"; break; }
done

# --- P4's vocabulary ---------------------------------------------------------------------
# vocabulary: hookwake blockable roles
# vocabulary-owner: core/hooks/ai-dlc-hookwake.sh
# Each member is BOUND to an existing team-roles/<role>.md at run time (hw_role_ok): a member
# whose role file is absent is not blockable. These are the roles whose every return item the
# deliverable carries (HANDOFF), so a blocked wake loses no report. `*-escalated` variants are
# named explicitly. dev, dev-escalated, qa, code-reviewer, code-reviewer-escalated,
# protected-path-editor, ops, ux, an empty role and any unknown role PASS: their report is
# folded from the final message, not from a deliverable. Named teammates (no toolUseId) PASS.
HW_BLOCKABLE_ROLES="adversary analyst architect cis gate-adjudicator pm pm-escalated remediator sm tea"

hw_role_ok() {  # $1 = role -> 0 when blockable
  local r
  [ -n "$HW_ROLES_DIR" ] || return 1
  for r in $HW_BLOCKABLE_ROLES; do
    [ "$r" = "$1" ] && [ -f "${HW_ROLES_DIR}/${r}.md" ] && return 0
  done
  return 1
}

# A helper beside the RECORD's script first (the record names the absolute path of the beat that
# actually ran, so this is right in both layouts), then the installed and the distribution path.
hw_sibling() {  # $1 = record script path (may be empty), $2 = basename -> the first existing file
  local c d=""
  [ -n "$1" ] && d="$(dirname "$1")"
  for c in ${d:+"$d/$2"} "${PROJECT_DIR}/scripts/ai-dlc/$2" "${PROJECT_DIR}/core/scripts/$2"; do
    [ -f "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

hw_start_of() {  # $1 = helper file, $2 = pid -> wfd_start_of's answer, whitespace-normalised
  ( export LC_ALL=C   # v4 C1: both sides read `ps` under LC_ALL=C, or the start times never match
    . "$1" >/dev/null 2>&1 || exit 1
    command -v wfd_start_of >/dev/null 2>&1 || exit 1
    wfd_start_of "$2" ) 2>/dev/null | tr -s ' \t' ' ' | sed 's/^ //; s/ $//'
}

hw_b64d() {  # stdin base64 -> stdout bytes; GNU and current BSD spell decode -d, older BSD -D
  local s; s="$(cat)"
  printf '%s' "$s" | base64 -d 2>/dev/null && return 0
  printf '%s' "$s" | base64 -D 2>/dev/null
}

hw_main() {
  local sid transcript prompt cls channel agent_id now lease lease_ep
  sid="$(printf '%s' "$INPUT" | jq -r '.session_id // empty | strings' 2>/dev/null)" || return 1
  transcript="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty | strings' 2>/dev/null)" || return 1
  prompt="$(printf '%s' "$INPUT" | jq -r '.prompt // empty | strings' 2>/dev/null)" || return 1
  [ -n "$prompt" ] && [ -n "$HW_SCHEMA" ] || return 0

  # --- P5: classify. Prints `H <id>`, `N <id>`, `B <id>` or `PASS`. -----------------------
  cls="$(jq -rn --slurpfile s "$HW_SCHEMA" --arg p "$prompt" '
    ($s[0] // {}) as $S
    | ($S.handback.frame // "" | strings) as $fr
    | ($S.handback.agent_message_from // "" | strings) as $am
    | (($S.prefixes // []) | map(strings | select(length > 0))) as $px
    | if $fr == "" or $am == "" then "PASS"
      elif ($p | startswith($am)) then
        ($p[($am | length):]) as $r
        | if ($r | test("^a[0-9a-f]{16}\">\n"))
             and (($r | split("\n") | .[1] // "") | startswith($fr))
          then "H " + $r[0:17] else "PASS" end
      else
        ([ $px[] | . as $q | select($p | startswith($q + ">\n<task-id>")) ] | .[0]) as $q
        | if $q == null then "PASS"
          else
            ($p[($q | length):]) as $r
            | ((($r | capture("^>\n<task-id>(?<id>[^<\n]*)</task-id>\n")?) // {id: ""}) | .id) as $id
            | ((($r | capture("\n<status>(?<st>[^<\n]*)</status>(\n|$)")?) // {st: ""}) | .st) as $st
            | if ($id | test("^a[0-9a-f]{16}$")) and $st == "completed" then "N " + $id
              elif ($id | test("^b[0-9a-z]{8}$")) then "B " + $id
              else "PASS" end
          end
      end' 2>/dev/null)" || return 0
  channel="${cls%% *}"; agent_id="${cls#* }"
  case "$channel" in H|N|B) ;; *) return 0 ;; esac

  # --- C5: the beat's own wake is never blocked; it names what this hook blocked under it. ---
  if [ "$channel" = B ]; then
    [ -r "$BLOCKS_FILE" ] || return 0
    local ctx
    ctx="$(jq -Rrn --arg t "$agent_id" --arg sd "$STATE_DIR" '
      [ inputs | fromjson? | select(type == "object" and (.beat_task_id // "") == $t
                                    and ((.agent_id // "") | test("^a[0-9a-f]{16}$"))) ]
      | unique_by(.agent_id)
      | if length == 0 then empty else
          ("ai-dlc-hookwake: while beat " + $t + " was outstanding this hook suppressed the completion wake of "
            + (map("agent " + .agent_id + " (deliverable: "
                   + ((.paths // []) | map(strings) | if length == 0 then "the path(s) that beat joined" else join(", ") end)
                   + "; final message: " + $sd + "/.subagent-final/" + .agent_id + ".txt)") | join("; "))
            + ". Its report did not reach you as a message. Read the deliverable, and the final-message file, before treating any of these as non-delivery or re-dispatching.")
        end' < "$BLOCKS_FILE" 2>/dev/null)" || return 0
    [ -n "$ctx" ] || return 0
    # PROVENANCE MARKER. The library is a SIBLING in both layouts (core/hooks/, .claude/hooks/),
    # so this is a same-directory read. Fail-open: a hook that cannot mark its output still
    # emits it.
    _AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
    if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
    else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi
    ctx="$(ai_dlc_provenance_wrap ai-dlc-hookwake UserPromptSubmit "$ctx")"
    jq -cn --arg c "$ctx" \
      '{ hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: $c } }' \
      2>/dev/null || return 0
    return 0
  fi

  case "$sid" in ''|*[!A-Za-z0-9-]*) return 0 ;; esac
  [ -n "$transcript" ] && [ -r "$transcript" ] || return 0

  # --- LEASE GATE: fast path only. ----------------------------------------------------------
  lease="$(cat "${LEASE_HOME}/.beat-inflight" 2>/dev/null)" || return 0
  lease_ep="${lease%% *}"
  case "$lease_ep" in ''|*[!0-9]*) return 0 ;; esac
  now="$(date +%s)"
  [ "$lease_ep" -gt "$now" ] || return 0

  # --- P4: agent id -> meta toolUseId -> ledger role. ---------------------------------------
  local meta="" td tui role
  [ -f "${transcript%.jsonl}/subagents/agent-${agent_id}.meta.json" ] \
    && meta="${transcript%.jsonl}/subagents/agent-${agent_id}.meta.json"
  if [ -z "$meta" ]; then
    for td in "${HOME:-/nonexistent}"/.claude/projects/*/"${sid}"/subagents; do
      [ -f "$td/agent-${agent_id}.meta.json" ] && meta="$td/agent-${agent_id}.meta.json"
      break
    done
  fi
  [ -n "$meta" ] || return 0
  tui="$(jq -r '.toolUseId // empty | strings' "$meta" 2>/dev/null)" || return 0
  [ -n "$tui" ] || return 0
  [ -r "${STATE_DIR}/spawn-ledger.jsonl" ] || return 0
  role="$(jq -Rrn --arg t "$tui" '[ inputs | fromjson? | select(type == "object" and (.tool_use_id // "") == $t) ]
                                  | last // {} | .role // empty | strings' \
          < "${STATE_DIR}/spawn-ledger.jsonl" 2>/dev/null)" || return 0
  hw_role_ok "$role" || return 0

  # --- J1: exactly one outstanding lead beat in the bounded tail, and its task id. ----------
  local j1 beat_task beat_tu
  j1="$(tail -c "${AI_DLC_HOOKWAKE_TAIL_BYTES:-1048576}" "$transcript" 2>/dev/null | jq -Rrn '
    def txt: if type == "string" then .
             elif type == "array" then map(if type == "object"
                   then ((.text // "" | strings) + "\n" + (.content | if type == "string" then .
                         elif type == "array" then map(if type == "object" then (.text // "" | strings) else "" end) | join("\n")
                         else "" end))
                   else "" end) | join("\n")
             else "" end;
    reduce (inputs | fromjson? | select(type == "object" and .isSidechain != true)) as $r
      ({beats: {}, task: {}, done: {}};
       ($r.message | if type == "object" then .content else null end) as $c
       | (if $r.type == "assistant" and ($c | type) == "array" then
            reduce ($c[] | select(type == "object" and .type == "tool_use" and .name == "Bash"
                                  and (.input.run_in_background? == true)
                                  and ((.input.command? // "") | tostring | contains("wait-for-deliverable.sh")))) as $u
              (.; .beats[($u.id // "" | tostring)] = 1)
          else . end)
       | (if $r.type == "user" and ($c | type) == "array"
             and (($r.toolUseResult? | type) == "object")
             and (($r.toolUseResult.backgroundTaskId? | type) == "string") then
            reduce ($c[] | select(type == "object" and .type == "tool_result")) as $t
              (.; .task[($t.tool_use_id // "" | tostring)] = $r.toolUseResult.backgroundTaskId)
          else . end)
       | ([$r.content?, ($c | txt), $r.attachment.prompt?] | map(strings) | join("\n")) as $s
       | reduce ($s | [scan("<tool-use-id>([A-Za-z0-9_]+)</tool-use-id>")] | .[] | .[0]) as $d
           (.; .done[$d] = 1))
    | . as $S
    | [ $S.beats | keys[] | select(. != "" and ($S.done[.] // 0) != 1) ] as $out
    | if ($out | length) == 1 and (($S.task[$out[0]] // "") != "")
      then $S.task[$out[0]] + " " + $out[0] else "" end' 2>/dev/null)" || return 0
  [ -n "$j1" ] || return 0
  beat_task="${j1%% *}"; beat_tu="${j1#* }"
  case "$beat_task" in ''|*[!A-Za-z0-9_]*) return 0 ;; esac

  # --- J2: exactly one live record for this session. ----------------------------------------
  local rf rec="" n_live=0 k v r_sid r_pid r_start r_script r_cwd r_task r_argv lib cur
  for rf in "$LEASE_DIR"/.beat-argv-*; do
    [ -f "$rf" ] || continue
    r_sid=""; r_pid=""; r_start=""; r_script=""
    while IFS= read -r k || [ -n "$k" ]; do
      v="${k#*=}"; k="${k%%=*}"
      case "$k" in
        session_id) r_sid="$v" ;; pid) r_pid="$v" ;; start) r_start="$v" ;; script) r_script="$v" ;;
      esac
    done < "$rf"
    [ "$r_sid" = "$sid" ] || continue
    case "$r_pid" in ''|*[!0-9]*) continue ;; esac
    [ "${rf##*/.beat-argv-}" = "$r_pid" ] || continue
    kill -0 "$r_pid" 2>/dev/null || continue
    lib="$(hw_sibling "$r_script" wfd-start-of.sh)" || return 0   # no helper -> PASS
    cur="$(hw_start_of "$lib" "$r_pid")"
    r_start="$(printf '%s' "$r_start" | tr -s ' \t' ' ' | sed 's/^ //; s/ $//')"
    [ -n "$cur" ] && [ "$cur" = "$r_start" ] || continue
    n_live=$((n_live + 1)); rec="$rf"
  done
  [ "$n_live" -eq 1 ] || return 0

  # Read the one live record in full: settings, cwd, task id, argv.
  local settings_file argv_file
  settings_file="$(mktemp "${TMPDIR:-/tmp}/ai-dlc-hookwake-env.XXXXXX" 2>/dev/null)" || return 0
  argv_file="$(mktemp "${TMPDIR:-/tmp}/ai-dlc-hookwake-argv.XXXXXX" 2>/dev/null)" || { rm -f "$settings_file"; return 0; }
  r_pid=""; r_script=""; r_cwd=""; r_task=""; r_argv=""
  while IFS= read -r k || [ -n "$k" ]; do
    v="${k#*=}"; k="${k%%=*}"
    case "$k" in
      pid) r_pid="$v" ;; script) r_script="$v" ;; cwd) r_cwd="$v" ;; task_id) r_task="$v" ;;
      argv) r_argv="$v" ;;
      CLAUDE_PROJECT_DIR|AI_DLC_*)
        case "$k" in *[!A-Za-z0-9_]*) ;; *) printf '%s=%s\n' "$k" "$v" >> "$settings_file" ;; esac ;;
    esac
  done < "$rec"

  # --- THE TASK-ID JOIN: the record's own harness task id is the lead's outstanding beat. ---
  [ -n "$r_task" ] && [ "$r_task" = "$beat_task" ] || { rm -f "$settings_file" "$argv_file"; return 0; }

  # --- J3: decode argv (NUL-separated, base64), collect --dispatch, drop --reset/--quiet. ---
  [ -n "$r_argv" ] || { rm -f "$settings_file" "$argv_file"; return 0; }
  printf '%s' "$r_argv" | hw_b64d > "$argv_file" || { rm -f "$settings_file" "$argv_file"; return 0; }
  [ -s "$argv_file" ] || { rm -f "$settings_file" "$argv_file"; return 0; }
  local -a args
  local a want="" in_dispatch=0 paths_json="[]" p
  args=()
  while IFS= read -r -d '' a || [ -n "$a" ]; do
    if [ -n "$want" ]; then
      [ "$want" = dispatch ] && [ "$a" = "$agent_id" ] && in_dispatch=1
      want=""; args[${#args[@]}]="$a"; continue
    fi
    case "$a" in
      --reset|--quiet) continue ;;
      --dispatch) want=dispatch ;;
      --since|--progress-path|--shard-header) want=value ;;
      -*) ;;
      *)
        # A script path recorded as the first element ($0) is not a target.
        if [ "${#args[@]}" -eq 0 ] && [ "${a##*/}" = wait-for-deliverable.sh ]; then continue; fi
        case "$a" in /*) p="$a" ;; *) p="${r_cwd%/}/$a" ;; esac
        paths_json="$(printf '%s' "$paths_json" | jq -c --arg p "$p" '. + [$p]' 2>/dev/null)" || { rm -f "$settings_file" "$argv_file"; return 0; } ;;
    esac
    args[${#args[@]}]="$a"
  done < "$argv_file"
  [ "$in_dispatch" -eq 1 ] || { rm -f "$settings_file" "$argv_file"; return 0; }
  [ "$(printf '%s' "$paths_json" | jq 'length' 2>/dev/null)" -ge 1 ] 2>/dev/null || { rm -f "$settings_file" "$argv_file"; return 0; }

  # --- J4: --status with the record's argv, cwd and settings; session id from the PAYLOAD. ---
  local wfd st_out st_rc
  if [ -n "$r_script" ] && [ -f "$r_script" ]; then wfd="$r_script"
  else wfd="$(hw_sibling "" wait-for-deliverable.sh)" || { rm -f "$settings_file" "$argv_file"; return 0; }
  fi
  [ -n "$r_cwd" ] && [ -d "$r_cwd" ] || { rm -f "$settings_file" "$argv_file"; return 0; }
  st_out="$(
    cd "$r_cwd" || exit 64
    # Every AI_DLC_* the hook inherited is dropped; the record's own settings are the beat's.
    for k in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$k"; done
    while IFS= read -r k; do
      v="${k#*=}"; k="${k%%=*}"
      [ -n "$v" ] && export "$k=$v"
    done < "$settings_file"
    export CLAUDE_CODE_SESSION_ID="$sid"
    bash "$wfd" ${args[@]+"${args[@]}"} --status < /dev/null 2>/dev/null
  )"; st_rc=$?
  rm -f "$settings_file" "$argv_file"
  [ "$st_rc" -eq 0 ] || return 0
  local n_paths n_del
  n_paths="$(printf '%s' "$paths_json" | jq 'length' 2>/dev/null)" || return 0
  n_del="$(printf '%s\n' "$st_out" | sed -n 's/^STATUS -- \([0-9][0-9]*\) delivered, 0 not\..*/\1/p' | tail -1)"
  [ -n "$n_del" ] && [ "$n_del" -ge 1 ] && [ "$n_del" -eq "$n_paths" ] || return 0

  # --- P2: no live rejected-spawn hold. A guard without --hold-status cannot report one, so
  # the mode is proved present first: with no transcript it must answer 2 ("cannot tell"). ---
  local guard g_rc
  guard="${HW_SELF}/ai-dlc-dispatch-guard.sh"
  [ -f "$guard" ] || return 0
  ( unset AI_DLC_HOLD_TRANSCRIPT; bash "$guard" --hold-status < /dev/null > /dev/null 2>&1 ); g_rc=$?
  [ "$g_rc" -eq 2 ] || return 0
  bash "$guard" --hold-status --transcript "$transcript" < /dev/null > /dev/null 2>&1; g_rc=$?
  [ "$g_rc" -eq 0 ] || return 0

  # --- BLOCK. Compose the output first, then the record, then print. ------------------------
  local out
  out="$(jq -cn --arg ch "$channel" --arg id "$agent_id" --arg t "$beat_task" \
    '{decision: "block",
      reason: ("ai-dlc-hookwake: the completion wake of agent " + $id + " (" + $ch + ") was suppressed; the lead beat " + $t + " joining its deliverable has every path DELIVERED and will wake the lead.")}' \
    2>/dev/null)" || return 0
  [ -n "$out" ] || return 0
  # The record is best-effort and the hook fails open: a failed append is captured and named on
  # stderr, and the block is printed either way.
  local rec_rc=0
  { jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg ch "$channel" --arg id "$agent_id" \
       --arg t "$beat_task" --arg pid "$r_pid" --arg tu "$beat_tu" --argjson paths "$paths_json" \
       '{ts: $ts, channel: $ch, agent_id: $id, beat_task_id: $t, record_pid: ($pid | tonumber? // $pid), paths: $paths}' \
       >> "$BLOCKS_FILE"; } 2>/dev/null || rec_rc=$?
  [ "$rec_rc" -eq 0 ] || printf 'ai-dlc-hookwake: block record not appended to %s (rc %s)\n' "$BLOCKS_FILE" "$rec_rc" >&2
  printf '%s\n' "$out"
  return 0
}

HW_OUT="$(hw_main 2>/dev/null)" || exit 0
[ -n "$HW_OUT" ] || exit 0
printf '%s' "$HW_OUT" | jq -e 'type == "object"' >/dev/null 2>&1 || exit 0
printf '%s\n' "$HW_OUT"
exit 0
