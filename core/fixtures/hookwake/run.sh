#!/usr/bin/env bash
# hookwake — the UserPromptSubmit hook ai-dlc-hookwake.sh BLOCKS a subagent's completion wake only
# when the lead's own armed beat will wake it with every joined path DELIVERED, and PASSES (exit 0,
# empty stdout) everything else.
#
# Usage: run.sh [<tree root>]
#   <tree root>  where the subject lives; default: walk up from this script. The hook is resolved at
#                <root>/core/hooks/ai-dlc-hookwake.sh (distribution) or <root>/.claude/hooks/ (consumer),
#                wait-for-deliverable.sh and wfd-start-of.sh at <root>/core/scripts/ or
#                <root>/scripts/ai-dlc/, the schema, guard and roles the same way.
# Exit:  0 = every assertion holds, 1 = an assertion failed, 2 = FIXTURE BROKEN (subject cannot run).
#
# OUTPUT. One row per assertion, `  ok    <cell> ...` or `  FAIL  <cell> ...`, cell ids:
#   A0h A0n A0env A0hc A0nc A0cx A0s A0e; A1..A6; A7a A7s A7e A7b; A8; A9a A9b; A10u A10r;
#   A11dev A11qa A11unk A11named; A12schema A12jq A12tr A12s64 A12json A12p0; A13b A13r A13p;
#   A14w A14u; A15.
#
# THE WORLDS. Every cell builds its own project under mktemp: a project dir P (lease, spawn ledger,
# deliverable, argv record), a sandboxed HOME H holding the lead transcript at
# `$H/.claude/projects/<slug>/<sid>.jsonl` and the subagents dir `$H/.claude/projects/<slug>/<sid>/subagents`.
# The hook runs under `env -i` with AI_DLC_HOOKWAKE=1 on its own invocation (fixtures scrub AI_DLC_*).
#
# TWO KINDS OF CELL.
#   REAL-BEAT (A0h A0n A0env, dist layout; A0hc A0nc A0cx, consumer layout). The argv record is
#     WRITTEN BY THE SHIPPED wait-for-deliverable.sh: a real beat is armed in the background with its
#     fd 1 on `$P/tasks/<task id>.output` (the harness's own shape, F9), so the record's task_id comes
#     from the script's own lsof read. Its pid is read from the record and stopped by that pid.
#     A0h runs the hook with CLAUDE_CODE_SESSION_ID UNSET (the hook exports it from the payload),
#     A0env with a WRONG one, the rest with the correct one. AI_DLC_TEAMMATE_DIR is unset in all.
#     The CONSUMER world holds .claude/hooks, .claude/schemas, .claude/team-roles and scripts/ai-dlc/
#     and NO core/ directory, so the hook must find wfd and wfd-start-of.sh beside the record's
#     script; A0cx moves wfd-start-of.sh away after arming and must PASS, which proves A0hc/A0nc
#     reached the helper rather than a fallback.
#   Where wfd cannot read fd 1 (no lsof on PATH and no /proc/self/fd) the record's task_id check and the
#     real-beat cells whose verdict needs it (A0h A0n A0env A0hc A0nc A0cx) SKIP with a reason; every other
#     assertion runs. A0e (always run) is the seeded BLOCK world with the record's task_id EMPTY, one field
#     away from A0s, and must PASS: an unreadable fd 1 fails safe.
#   SEEDED (every other cell). The record is written by this script behind a live `sleep` whose
#     start time is read through the copied wfd-start-of.sh, so a mutant of wfd's record writer
#     moves the A0 cells only. A0s is the seeded BLOCK world and the control for every seeded PASS.
#
# ONE FIELD PER CELL. A seeded world is a set of named fields (FIELDS below). Each cell names its
# overrides; the cell asserts how many differ from the BLOCK world before it runs: 0 for A0s, 1 for
# every PASS cell and for A10r. A7b and A11named are the contract's named exceptions to that rule
# and are built here as one-field cells as well (A7b: the record's task_id is not the transcript
# beat's; A11named: the agent's meta.json carries no toolUseId).
set -uo pipefail

NAME="hookwake"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '%s: FIXTURE BROKEN — %s\n' "$NAME" "$1"; printf '%s: FIXTURE BROKEN — %s\n' "$NAME" "$1" >&2; exit 2; }

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_CODE_SESSION_ID CLAUDE_PROJECT_DIR
BASEPATH="$PATH"

HERE="$(cd "$(dirname "$0")" && pwd)"
layout_of() {  # $1 = dir -> dist|consumer, rc 1 when neither
  if [ -f "$1/core/hooks/ai-dlc-hookwake.sh" ]; then echo dist; return 0; fi
  if [ -f "$1/.claude/hooks/ai-dlc-hookwake.sh" ]; then echo consumer; return 0; fi
  return 1
}
ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  d="$HERE"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    layout_of "$d" >/dev/null && { ROOT="$d"; break; }
    d="$(dirname "$d")"
  done
fi
[ -n "$ROOT" ] && [ -d "$ROOT" ] || broken "no tree holding ai-dlc-hookwake.sh found (walked up from $HERE)"
ROOT="$(cd "$ROOT" && pwd -P)"
LAYOUT="$(layout_of "$ROOT")" || broken "$ROOT holds no core/hooks/ or .claude/hooks/ ai-dlc-hookwake.sh"
case "$LAYOUT" in
  dist)     S_HOOK="$ROOT/core/hooks/ai-dlc-hookwake.sh"; S_GUARD="$ROOT/core/hooks/ai-dlc-dispatch-guard.sh"
            S_SCHEMA="$ROOT/core/schemas/harness-origin.json"; S_ROLES="$ROOT/core/team-roles"; S_SCR="$ROOT/core/scripts" ;;
  consumer) S_HOOK="$ROOT/.claude/hooks/ai-dlc-hookwake.sh"; S_GUARD="$ROOT/.claude/hooks/ai-dlc-dispatch-guard.sh"
            S_SCHEMA="$ROOT/.claude/schemas/harness-origin.json"; S_ROLES="$ROOT/.claude/team-roles"; S_SCR="$ROOT/scripts/ai-dlc" ;;
esac
S_WFD="$S_SCR/wait-for-deliverable.sh"; S_HELPER="$S_SCR/wfd-start-of.sh"; S_GRAMMAR="$S_SCR/validate-adversarial-convergence.sh"
for _f in "$S_HOOK" "$S_GUARD" "$S_SCHEMA" "$S_WFD" "$S_HELPER" "$S_GRAMMAR"; do
  [ -f "$_f" ] || broken "subject file absent: $_f"
done
[ -d "$S_ROLES" ] || broken "roles dir absent: $S_ROLES"
for _t in jq base64 ps pgrep shasum; do command -v "$_t" >/dev/null 2>&1 || broken "tool not on PATH: $_t"; done
BASH_BIN="$(command -v bash)"
# wfd's argv_task_id reads the beat's fd 1 through lsof (macOS) or /proc (Linux). Where neither exists the
# record's task_id is empty and the subject fails SAFE (PASS, A0e), so the cells that need the id read SKIP.
FD1_OK=0; { command -v lsof >/dev/null 2>&1 || [ -d /proc/self/fd ]; } && FD1_OK=1
skip_fd1() { printf '  SKIP  %s: no lsof and no /proc, wfd cannot read the beat'"'"'s fd 1\n' "$1"; }

FRAME="$(jq -r '.handback.frame // empty' "$S_SCHEMA" 2>/dev/null)"
AMFROM="$(jq -r '.handback.agent_message_from // empty' "$S_SCHEMA" 2>/dev/null)"
[ -n "$FRAME" ] && [ -n "$AMFROM" ] || broken "$S_SCHEMA carries no handback.frame / handback.agent_message_from"
jq -e '.prefixes | index("<task-notification")' "$S_SCHEMA" >/dev/null 2>&1 \
  || broken "$S_SCHEMA does not declare the <task-notification prefix the (N) cells use"

WORK="$(mktemp -d 2>/dev/null)" || broken "mktemp failed"
WORK="$(cd "$WORK" && pwd -P)"
mkdir -p "$WORK/tmp" || broken "cannot create $WORK/tmp"
PIDS=""          # every process this script started: killed by these recorded pids on exit
cleanup() {
  local p
  for p in $PIDS; do kill "$p" 2>/dev/null; done
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "$NAME ($LAYOUT layout, root $ROOT)"

SID="5f1d2c3b-0000-4000-8000-00000000c0de"
WRONG_SID="99999999-0000-4000-8000-000000000bad"
AID="a0123456789abcdef"
OTHER_AID="afedcba9876543210"
AGENT_TU="toolu_01HWAGENTSPAWN"
OTHER_TU="toolu_01HWSIBLINGSPAWN"
BEAT_TU="toolu_01HWBEAT"
DECOY_TU="toolu_01ZZDECOY"        # sorts AFTER BEAT_TU in jq keys (A13b)
TASK="bfx000001"
SLUG="-hookwake-fixture-project"

# ===========================================================================
# THE VERDICT READER, THE FIELD COUNTER AND THE CONTEXT MATCHER, and their self-probes.
# ===========================================================================
verdict_of() {  # $1 = rc, $2 = stdout -> BLOCK | PASS | OTHER
  if [ "$1" -ne 0 ]; then echo OTHER; return; fi
  if [ -z "$2" ]; then echo PASS; return; fi
  if printf '%s' "$2" | jq -e 'type == "object" and .decision == "block"' >/dev/null 2>&1; then echo BLOCK; return; fi
  echo OTHER
}
ctx_has() {  # $1 = stdout, $2.. = fixed strings additionalContext must carry -> rc 0 iff all
  local c s
  c="$(printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)" || return 1
  [ -n "$c" ] || return 1
  shift
  for s in "$@"; do case "$c" in *"$s"*) : ;; *) return 1 ;; esac; done
  return 0
}

FIELDS="prompt=H lease=live recpid=live trbeat=one completion=none hold=none dispatch=self argvx=none role=architect meta=tui schema=present jq=present trread=yes script=wfd json=ok p0=on beats=1 records=1 start=match task=match blockrec=writable sidenv=correct"
default_of() {  # $1 = field -> its BLOCK value, rc 1 when no such field
  local kv
  for kv in $FIELDS; do [ "${kv%%=*}" = "$1" ] && { printf '%s' "${kv#*=}"; return 0; }; done
  return 1
}
diff_count() {  # $@ = k=v overrides -> how many differ from the BLOCK world; rc 2 on an unknown field
  local kv n=0 dv
  for kv in "$@"; do
    dv="$(default_of "${kv%%=*}")" || return 2
    [ "$dv" = "${kv#*=}" ] || n=$((n+1))
  done
  printf '%s' "$n"
}
set_fields() {  # $@ = overrides -> F_<field> variables
  local kv
  for kv in $FIELDS "$@"; do printf -v "F_${kv%%=*}" '%s' "${kv#*=}"; done
}

probe() {
  echo "-- self-probes (both directions, before any world)"
  local P_DIR; P_DIR="$(mktemp -d "$WORK/probe.XXXXXX")" || broken "mktemp failed"
  printf '%s' '{"decision":"block","reason":"r"}' > "$P_DIR/blk"
  [ "$(verdict_of 0 "$(cat "$P_DIR/blk")")" = BLOCK ] && ok "probe: a block decision reads BLOCK" \
    || bad "probe: the verdict reader missed a block decision — every BLOCK cell is blind"
  [ "$(verdict_of 0 '{"decision":"blocked"}')" = OTHER ] && [ "$(verdict_of 0 '')" = PASS ] && [ "$(verdict_of 1 '')" = OTHER ] \
    && [ "$(verdict_of 0 '{"hookSpecificOutput":{}}')" = OTHER ] \
    && ok "probe: a near-miss decision, a non-zero exit and a context-only object do not read BLOCK, and only empty+0 reads PASS" \
    || bad "probe: the verdict reader accepts a near-miss — every PASS cell is blind"
  local c='{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"x /p/deliv.md y /s/.subagent-final/a1.txt"}}'
  ctx_has "$c" /p/deliv.md /s/.subagent-final/a1.txt && ok "probe: the context matcher finds both paths when present" \
    || bad "probe: the context matcher missed present paths — A15 is blind"
  ! ctx_has "$c" /p/deliv.md /s/.subagent-final/a2.txt && ! ctx_has '{"decision":"block"}' /p/deliv.md \
    && ok "probe: the context matcher refuses a missing path and an object with no additionalContext" \
    || bad "probe: the context matcher accepts a missing path — A15 cannot fail"
  [ "$(diff_count prompt=H lease=live)" = 0 ] && [ "$(diff_count lease=expired)" = 1 ] && [ "$(diff_count lease=expired role=dev)" = 2 ] \
    && ok "probe: the field counter scores 0, 1 and 2 differing fields correctly" \
    || bad "probe: the field counter miscounts — the one-field assertion is blind"
  diff_count nosuchfield=x >/dev/null; [ $? -eq 2 ] && ok "probe: the field counter refuses an unknown field" \
    || bad "probe: the field counter accepts an unknown field — a typo'd override would count as no change"
}
probe

# ===========================================================================
# WORLD BUILDERS
# ===========================================================================
iso_of() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; }
start_of() {  # $1 = pid -> the copied helper's answer
  ( . "$S_HELPER" >/dev/null 2>&1 && wfd_start_of "$1" )
}
new_sleeper() {  # -> SLEEPER pid, recorded for cleanup
  sleep 900 &
  SLEEPER=$!
  PIDS="$PIDS $SLEEPER"
}
new_sleeper; LIVE1="$SLEEPER"
new_sleeper; LIVE2="$SLEEPER"
# A pid that CANNOT be live: one above the platform's pid ceiling. A reaped child's pid is not that
# -- the kernel reuses it during a long run, and a reused pid reads live with a matching start time.
# Linux publishes the ceiling in /proc/sys/kernel/pid_max; macOS has no sysctl for it and its
# compiled-in PID_MAX is 99999.
PIDMAX="$(cat /proc/sys/kernel/pid_max 2>/dev/null)" || PIDMAX=""
case "$PIDMAX" in ''|*[!0-9]*) PIDMAX=99999 ;; esac
DEADPID=$((PIDMAX + 1))
kill -0 "$DEADPID" 2>/dev/null && broken "the dead-pid control $DEADPID is alive"
[ -z "$(ps -o pid= -p "$DEADPID" 2>/dev/null)" ] || broken "ps reports a process for the dead-pid control $DEADPID"
[ -n "$(start_of "$LIVE1")" ] || broken "wfd-start-of.sh read no start time for live pid $LIVE1"

# mk_tree <P> <dist|consumer> : copy the subject into a project of that layout.
mk_tree() {
  local P="$1" L="$2" hk sc scr rl
  case "$L" in
    dist)     hk="$P/core/hooks"; sc="$P/core/schemas"; scr="$P/core/scripts"; rl="$P/core/team-roles" ;;
    consumer) hk="$P/.claude/hooks"; sc="$P/.claude/schemas"; scr="$P/scripts/ai-dlc"; rl="$P/.claude/team-roles" ;;
  esac
  mkdir -p "$hk" "$sc" "$scr" "$rl" "$P/_bmad-output" "$P/tasks" || broken "cannot build $P"
  cp "$S_HOOK" "$S_GUARD" "$hk/" && cp "$S_SCHEMA" "$sc/" && cp "$S_WFD" "$S_HELPER" "$S_GRAMMAR" "$scr/" \
    && cp "$S_ROLES"/*.md "$rl/" || broken "cannot copy the subject into $P"
  W_HOOK="$hk/ai-dlc-hookwake.sh"; W_GUARD="$hk/ai-dlc-dispatch-guard.sh"; W_SCHEMA="$sc/harness-origin.json"
  W_WFD="$scr/wait-for-deliverable.sh"; W_HELPER="$scr/wfd-start-of.sh"
}

# mk_home <H> <role> <meta> : sandboxed HOME, subagents dir, the agent's meta.json; sets TR.
mk_home() {
  local H="$1" sub
  sub="$H/.claude/projects/$SLUG/$SID/subagents"
  mkdir -p "$sub" || broken "cannot build $sub"
  TR="$H/.claude/projects/$SLUG/$SID.jsonl"
  case "$3" in
    tui)   printf '{"agentType":"%s","toolUseId":"%s"}\n' "$2" "$AGENT_TU" > "$sub/agent-$AID.meta.json" ;;
    notui) printf '{"agentType":"%s"}\n' "$2" > "$sub/agent-$AID.meta.json" ;;
  esac
  # A real SIBLING dispatch in every world, so a beat joining OTHER_AID (A9a) resolves in J4 exactly
  # as the BLOCK world's beat does, and J3 is the only join that separates them.
  printf '{"agentType":"%s","toolUseId":"%s"}\n' "$2" "$OTHER_TU" > "$sub/agent-$OTHER_AID.meta.json"
}
mk_ledger() {  # <P> <role>
  local ts; ts="$(iso_of $(( $(date +%s) - 60 )))"
  printf '{"v":1,"ts":"%s","name":"hw","role":"%s","tool_use_id":"%s"}\n{"v":1,"ts":"%s","name":"hw2","role":"%s","tool_use_id":"%s"}\n' \
    "$ts" "$2" "$AGENT_TU" "$ts" "$2" "$OTHER_TU" \
    > "$1/_bmad-output/spawn-ledger.jsonl" || broken "cannot write the ledger"
}
tr_beat() {  # <transcript> <tool_use id> <task id> <command> : one background wfd Bash call and its tool_result
  jq -cn --arg id "$2" --arg cmd "$4" \
    '{type:"assistant",message:{id:("msg_" + $id),role:"assistant",content:[{type:"tool_use",id:$id,name:"Bash",input:{command:$cmd,description:"beat",run_in_background:true}}]}}' >> "$1"
  jq -cn --arg id "$2" --arg t "$3" \
    '{type:"user",message:{role:"user",content:[{tool_use_id:$id,type:"tool_result",content:("Command running in background with ID: " + $t + ".")}]},toolUseResult:{stdout:"",stderr:"",interrupted:false,backgroundTaskId:$t}}' >> "$1"
}
tr_head() {  # <transcript>
  jq -cn '{type:"user",message:{role:"user",content:"run the round"}}' > "$1"
}
tr_enqueue() {  # <transcript> : the beat's completion, enqueued only
  jq -cn --arg c "$(printf '<task-notification>\n<task-id>%s</task-id>\n<tool-use-id>%s</tool-use-id>\n<status>completed</status>\n</task-notification>' "$TASK" "$BEAT_TU")" \
    '{type:"queue-operation",operation:"enqueue",content:$c}' >> "$1"
}
tr_cap() {  # <transcript> : a live rejected-spawn hold
  jq -cn '{type:"assistant",message:{id:"msg_rej",role:"assistant",content:[{type:"tool_use",id:"toolu_01REJ",name:"Agent",input:{description:"held spawn",prompt:"p"}}]}}' >> "$1"
  jq -cn '{type:"user",message:{role:"user",content:[{tool_use_id:"toolu_01REJ",type:"tool_result",is_error:true,content:"Concurrent subagent limit reached (4). Do not retry."}]}}' >> "$1"
}

b64_argv() { printf '%s\0' "$@" | base64 | tr -d '\n'; }
# put_record <P> <pid> <start> <script> <task> <argv...>
put_record() {
  local P="$1" pid="$2" st="$3" scr="$4" tk="$5"; shift 5
  {
    printf 'session_id=%s\npid=%s\nstart=%s\nscript=%s\ncwd=%s\ntask_id=%s\n' "$SID" "$pid" "$st" "$scr" "$P" "$tk"
    printf 'AI_DLC_MAX_WAIT_BEATS=\nAI_DLC_PROJECT_ROOT=%s\nAI_DLC_STATE_DIR=\nAI_DLC_TEAMMATE_DIR=\n' "$P"
    printf 'AI_DLC_TEAMMATE_IDLE_SECS=\nAI_DLC_WAIT_BEAT_SECS=\nAI_DLC_WAIT_MARGIN_SECS=\nAI_DLC_WAIT_POLL_SECS=\nAI_DLC_WAIT_SETTLE_SECS=\nCLAUDE_PROJECT_DIR=\n'
    printf 'argv=%s\n' "$(b64_argv "$@")"
  } > "$P/_bmad-output/.wait-beats/.beat-argv-$pid" || broken "cannot write the record"
}

# --- prompts -------------------------------------------------------------------------------
p_note() {  # <task id> <tool-use id> <status> <summary>
  printf '<task-notification>\n<task-id>%s</task-id>\n<tool-use-id>%s</tool-use-id>\n<output-file>/x/tasks/%s.output</output-file>\n<status>%s</status>\n<summary>%s</summary>\n</task-notification>' "$1" "$2" "$1" "$3" "$4"
}
REWORD="${FRAME/hand-back/handoff}"
[ "$REWORD" != "$FRAME" ] || REWORD="${FRAME%?}x"
prompt_of() {  # $1 = prompt field
  case "$1" in
    H)       printf '%s%s">\n%s The text below is the final report.\nreport body' "$AMFROM" "$AID" "$FRAME" ;;
    nofr)    printf '%s%s">\nstill working, halfway through the shard' "$AMFROM" "$AID" ;;
    l3)      printf '%s%s">\nheader line\n%s report' "$AMFROM" "$AID" "$FRAME" ;;
    indent)  printf '%s%s">\n  %s report' "$AMFROM" "$AID" "$FRAME" ;;
    body)    printf '%s%s">\nsee %s report' "$AMFROM" "$AID" "$FRAME" ;;
    reword)  printf '%s%s">\n%s report' "$AMFROM" "$AID" "$REWORD" ;;
    N)       p_note "$AID" "$AGENT_TU" completed 'Agent "hw" finished' ;;
    Nfailed) p_note "$AID" "$AGENT_TU" failed 'Agent "hw" failed' ;;
    Nkilled) p_note "$AID" "$AGENT_TU" killed 'Agent "hw" was stopped' ;;
    B)       p_note "$TASK" "$BEAT_TU" completed 'Background command "beat" completed (exit code 0)' ;;
  esac
}

# run_hook <hook> <P> <H> <prompt text> <sidenv: correct|unset|wrong> [<p0: on|off>] [<json: ok|garbled>] [<path>]
run_hook() {
  local hk="$1" P="$2" H="$3" pt="$4" se="$5" p0="${6:-on}" js="${7:-ok}" pth="${8:-$BASEPATH}" pl
  local -a ev
  ev=(PATH="$pth" HOME="$H" TMPDIR="$WORK/tmp" CLAUDE_PROJECT_DIR="$P")
  [ "$p0" = on ] && ev[${#ev[@]}]="AI_DLC_HOOKWAKE=1"
  case "$se" in
    correct) ev[${#ev[@]}]="CLAUDE_CODE_SESSION_ID=$SID" ;;
    wrong)   ev[${#ev[@]}]="CLAUDE_CODE_SESSION_ID=$WRONG_SID" ;;
    unset)   : ;;
  esac
  HOOK_ENV="${ev[*]}"
  if [ "$js" = ok ]; then
    pl="$(jq -cn --arg s "$SID" --arg t "$TR" --arg p "$pt" --arg c "$P" \
          '{session_id:$s,transcript_path:$t,cwd:$c,hook_event_name:"UserPromptSubmit",prompt:$p}')"
  else
    pl='{"session_id":"'"$SID"'","transcript_path":"'"$TR"'","prompt":"<agent-message from='
  fi
  OUT="$(cd "$P" && printf '%s' "$pl" | env -i "${ev[@]}" "$BASH_BIN" "$hk" 2>/dev/null)"; RC=$?
  V="$(verdict_of "$RC" "$OUT")"
}
env_says() {  # $1 = correct|unset|wrong -> rc 0 iff HOOK_ENV carries that session-id setting
  case "$1" in
    unset)   case " $HOOK_ENV " in *" CLAUDE_CODE_SESSION_ID="*) return 1 ;; esac ;;
    correct) case " $HOOK_ENV " in *" CLAUDE_CODE_SESSION_ID=$SID "*) : ;; *) return 1 ;; esac ;;
    wrong)   case " $HOOK_ENV " in *" CLAUDE_CODE_SESSION_ID=$WRONG_SID "*) : ;; *) return 1 ;; esac ;;
  esac
  case " $HOOK_ENV " in *" AI_DLC_TEAMMATE_DIR="*) return 1 ;; esac
  return 0
}

# ===========================================================================
# THE SEEDED WORLD: build from F_<field>, run the hook. Sets C (cell dir), P, H, TR, OUT, RC, V.
# ===========================================================================
seed_world() {
  C="$(mktemp -d "$WORK/cell.XXXXXX")" || broken "mktemp failed"
  P="$C/proj"; H="$C/home"
  mk_tree "$P" dist
  mkdir -p "$P/_bmad-output/.wait-beats" || broken "cannot make the lease dir"
  mk_home "$H" "$F_role" "$F_meta"
  mk_ledger "$P" "$F_role"
  printf 'deliverable body\n' > "$P/deliv.md"
  local now; now="$(date +%s)"
  case "$F_lease" in
    live)    printf '%s %s' "$((now + 600))" "$LIVE1" > "$P/_bmad-output/.beat-inflight" ;;
    expired) printf '%s %s' "$((now - 10))" "$LIVE1" > "$P/_bmad-output/.beat-inflight" ;;
  esac
  tr_head "$TR"
  [ "$F_trbeat" = one ] && tr_beat "$TR" "$BEAT_TU" "$TASK" "bash core/scripts/wait-for-deliverable.sh $P/deliv.md --dispatch $AID"
  [ "$F_beats" = 2 ] && tr_beat "$TR" "$DECOY_TU" "bzzdecoy1" "bash core/scripts/wait-for-deliverable.sh $P/other.md"
  [ "$F_completion" = enqueue ] && tr_enqueue "$TR"
  [ "$F_hold" = cap ] && tr_cap "$TR"
  local -a av; av=("$P/deliv.md")
  case "$F_dispatch" in self) av[${#av[@]}]=--dispatch; av[${#av[@]}]="$AID" ;;
                        other) av[${#av[@]}]=--dispatch; av[${#av[@]}]="$OTHER_AID" ;; esac
  case "$F_argvx" in complete) av[${#av[@]}]=--complete ;; reset) av[${#av[@]}]=--reset ;; esac
  local scr="$W_WFD" pid="$LIVE1" st tk="$TASK"
  if [ "$F_script" = stub64 ]; then
    scr="$P/stub-status.sh"
    printf '#!/bin/bash\necho "DELIVERED %s"\necho "STATUS -- 1 delivered, 0 not. Nothing slept."\nexit 64\n' "$P/deliv.md" > "$scr"
  fi
  [ "$F_recpid" = dead ] && pid="$DEADPID"
  st="$(start_of "$pid")"
  [ "$F_start" = wrong ] && st="Thu Jan 1 00:00:00 1970"
  [ "$F_task" = other ] && tk="bsubag001"
  [ "$F_task" = empty ] && tk=""
  put_record "$P" "$pid" "$st" "$scr" "$tk" "${av[@]}"
  if [ "$F_records" = 2 ]; then
    put_record "$P" "$LIVE2" "$(start_of "$LIVE2")" "$scr" "$tk" "${av[@]}"
  fi
  [ "$F_schema" = absent ] && rm -f "$W_SCHEMA"
  [ "$F_blockrec" = unwritable ] && mkdir -p "$P/_bmad-output/.hookwake-blocks.jsonl"
  [ "$F_trread" = no ] && chmod 000 "$TR"
  local pth="$BASEPATH"
  if [ "$F_jq" = absent ]; then
    pth="$C/nojq-bin"; mkdir -p "$pth"
    local t tp
    for t in awk base64 basename bash cat cksum cmp cp cut date dirname env find grep head kill ln ls mkdir mktemp mv ps readlink rm sed shasum sleep sort stat tail touch tr wc; do
      tp="$(command -v "$t" 2>/dev/null)" && ln -s "$tp" "$pth/$t"
    done
    tp="$(command -v lsof 2>/dev/null)" && ln -s "$tp" "$pth/lsof"
  fi
  run_hook "$W_HOOK" "$P" "$H" "$(prompt_of "$F_prompt")" "$F_sidenv" "$F_p0" "$F_json" "$pth"
}

# cell <id> <expect BLOCK|PASS> <want-diff> <label> [overrides...]
cell() {
  local id="$1" want="$2" wd="$3" label="$4" n; shift 4
  n="$(diff_count "$@")" || broken "$id names an unknown field: $*"
  if [ "$n" != "$wd" ]; then bad "$id differs from the BLOCK world in $n field(s), not $wd: $*"; return; fi
  set_fields "$@"
  seed_world
  env_says "$F_sidenv" || { bad "$id: the hook's env does not carry sidenv=$F_sidenv ($HOOK_ENV)"; return; }
  if [ "$V" = "$want" ]; then ok "$id $want: $label [${*:-no field changed}]"
  else bad "$id expected $want, got $V (rc $RC, stdout: $(printf '%s' "$OUT" | head -c 200)): $label [$*]"; fi
}

# ===========================================================================
# A0 REAL-BEAT CELLS
# ===========================================================================
# arm_beat <P> <H> <layout> : a real beat from the copied wfd, fd 1 on $P/tasks/$TASK.output.
arm_beat() {
  local P="$1" H="$2" i
  mk_home "$H" architect tui
  mk_ledger "$P" architect
  tr_head "$TR"
  tr_beat "$TR" "$BEAT_TU" "$TASK" "bash scripts/ai-dlc/wait-for-deliverable.sh $P/deliv.md --dispatch $AID"
  ( cd "$P" && env -i PATH="$BASEPATH" HOME="$H" TMPDIR="$WORK/tmp" CLAUDE_CODE_SESSION_ID="$SID" \
      AI_DLC_PROJECT_ROOT="$P" AI_DLC_WAIT_BEAT_SECS=400 AI_DLC_WAIT_POLL_SECS=200 AI_DLC_WAIT_MARGIN_SECS=0 \
      AI_DLC_MAX_WAIT_BEATS=5 "$BASH_BIN" "$W_WFD" "$P/deliv.md" --dispatch "$AID" > "$P/tasks/$TASK.output" 2>&1; : ) &
  PIDS="$PIDS $!"
  BEAT_PID=""; BEAT_REC=""
  for i in $(seq 1 100); do
    for BEAT_REC in "$P/_bmad-output/.wait-beats"/.beat-argv-*; do [ -f "$BEAT_REC" ] && break; BEAT_REC=""; done
    [ -n "$BEAT_REC" ] && break
    sleep 0.2
  done
  [ -n "$BEAT_REC" ] || return 1
  BEAT_PID="$(sed -n 's/^pid=//p' "$BEAT_REC")"
  case "$BEAT_PID" in ''|*[!0-9]*) return 1 ;; esac
  PIDS="$PIDS $BEAT_PID"
  BEAT_SLEEP=""
  for i in $(seq 1 150); do
    BEAT_SLEEP="$(pgrep -P "$BEAT_PID" sleep 2>/dev/null | head -1)"
    [ -n "$BEAT_SLEEP" ] && break
    kill -0 "$BEAT_PID" 2>/dev/null || return 1
    sleep 0.2
  done
  [ -n "$BEAT_SLEEP" ] || return 1
  PIDS="$PIDS $BEAT_SLEEP"
  printf 'deliverable body\n' > "$P/deliv.md"
  return 0
}
stop_beat() { kill "$BEAT_PID" 2>/dev/null; kill "$BEAT_SLEEP" 2>/dev/null; }

real_cell() {  # <id> <want> <sidenv> <prompt> <label>
  if [ "$FD1_OK" != 1 ]; then skip_fd1 "$1"; return; fi
  run_hook "$W_HOOK" "$P" "$H" "$(prompt_of "$4")" "$3"
  env_says "$3" || { bad "$1: the hook's env does not carry sidenv=$3 ($HOOK_ENV)"; return; }
  if [ "$V" = "$2" ]; then ok "$1 $2: $5"
  else bad "$1 expected $2, got $V (rc $RC, stdout: $(printf '%s' "$OUT" | head -c 200)): $5"; fi
}
rec_shape() {  # <id> : the record the shipped beat wrote carries a start time and the harness task id
  local st tk
  st="$(sed -n 's/^start=//p' "$BEAT_REC")"; tk="$(sed -n 's/^task_id=//p' "$BEAT_REC")"
  [ -n "$st" ] && [ "$st" = "$(start_of "$BEAT_PID")" ] \
    && ok "$1 record: the shipped beat wrote start=$st, equal to wfd_start_of of its pid" \
    || bad "$1 record: the shipped beat's start= is '$st', not its pid's start time"
  if [ "$FD1_OK" != 1 ]; then skip_fd1 "$1 record task_id"; return; fi
  [ "$tk" = "$TASK" ] && ok "$1 record: task_id=$tk read from the beat's own fd 1" \
    || bad "$1 record: task_id is '$tk', not $TASK (the lsof read of fd 1 failed)"
}

echo "-- A0 real-beat cells, distribution layout"
echo "HERMETIC-CONSUMED $S_HOOK"
echo "HERMETIC-CONSUMED $S_WFD"
echo "HERMETIC-CONSUMED $S_HELPER"
echo "HERMETIC-CONSUMED $S_GUARD"
echo "HERMETIC-CONSUMED $S_SCHEMA"
echo "HERMETIC-CONSUMED $S_GRAMMAR"
C="$(mktemp -d "$WORK/real-dist.XXXXXX")" || broken "mktemp failed"
P="$C/proj"; H="$C/home"; mk_tree "$P" dist
if arm_beat "$P" "$H"; then
  rec_shape A0h
  if [ "$FD1_OK" != 1 ]; then skip_fd1 A0h
  else run_hook "$W_HOOK" "$P" "$H" "$(prompt_of H)" unset
  if env_says unset && [ "$V" = BLOCK ]; then
    printf '%s\n' "  ok    A0h BLOCK: (H) hand-back, dist layout, record written by the shipped wait-for-deliverable.sh"
  else bad "A0h expected BLOCK, got $V (rc $RC, stdout: $(printf '%s' "$OUT" | head -c 200)): (H) hand-back, dist layout, CLAUDE_CODE_SESSION_ID unset"; fi
  fi
  real_cell A0n BLOCK correct N "(N) completed notification, dist layout, CLAUDE_CODE_SESSION_ID correct"
  real_cell A0env BLOCK wrong H "(H) hand-back, dist layout, CLAUDE_CODE_SESSION_ID WRONG in the hook env (the payload's id is used)"
  stop_beat
else
  bad "A0h: the shipped wait-for-deliverable.sh wrote no argv record, or its beat did not reach its sleep"
  bad "A0n: no real beat (see A0h)"; bad "A0env: no real beat (see A0h)"
fi

echo "-- A0 real-beat cells, consumer layout (.claude/hooks, .claude/schemas, scripts/ai-dlc/, no core/)"
C="$(mktemp -d "$WORK/real-cons.XXXXXX")" || broken "mktemp failed"
P="$C/proj"; H="$C/home"; mk_tree "$P" consumer
[ ! -e "$P/core" ] || broken "the consumer world carries a core/ directory"
if arm_beat "$P" "$H"; then
  rec_shape A0hc
  case "$(sed -n 's/^script=//p' "$BEAT_REC")" in
    "$P/scripts/ai-dlc/wait-for-deliverable.sh") ok "A0hc record: script= names the consumer path scripts/ai-dlc/wait-for-deliverable.sh" ;;
    *) bad "A0hc record: script= does not name $P/scripts/ai-dlc/wait-for-deliverable.sh" ;;
  esac
  real_cell A0hc BLOCK correct H "(H) hand-back, consumer layout, helper found at scripts/ai-dlc/wfd-start-of.sh"
  real_cell A0nc BLOCK correct N "(N) completed notification, consumer layout"
  mv "$W_HELPER" "$C/helper-aside" || broken "cannot move the consumer helper aside"
  real_cell A0cx PASS correct H "consumer layout with scripts/ai-dlc/wfd-start-of.sh removed: no helper, no block (A0hc reached the helper)"
  mv "$C/helper-aside" "$W_HELPER"
  stop_beat
else
  bad "A0hc: the shipped wait-for-deliverable.sh wrote no argv record in the consumer layout, or its beat did not sleep"
  bad "A0nc: no real beat (see A0hc)"; bad "A0cx: no real beat (see A0hc)"
fi

# ===========================================================================
# SEEDED CELLS
# ===========================================================================
echo "-- seeded cells (record written by this fixture behind a live pid)"
echo "HERMETIC-CONSUMED $S_ROLES"
cell A0s BLOCK 0 "the seeded BLOCK world: live lease, one outstanding beat, one live record, agent in --dispatch, path DELIVERED"
cell A0e PASS 1 "the record's task_id is EMPTY (an unreadable fd 1): the task-id join fails safe, no block" task=empty
cell A1 PASS 1 "agent-message with no hand-back frame (a mid-report message)" prompt=nofr
cell A2 PASS 1 "hand-back frame on line 3" prompt=l3
cell A2 PASS 1 "hand-back frame indented on line 2" prompt=indent
cell A2 PASS 1 "hand-back frame inside line 2's body" prompt=body
cell A3 PASS 1 "hand-back frame reworded" prompt=reword
cell A4 PASS 1 "lease expired" lease=expired
cell A4 PASS 1 "no lease" lease=absent
cell A5 PASS 1 "(N) status failed" prompt=Nfailed
cell A5 PASS 1 "(N) status killed" prompt=Nkilled
cell A6 PASS 1 "a b… (Bash) notification with no block recorded" prompt=B
cell A7a PASS 1 "the record's pid is dead" recpid=dead
cell A7s PASS 1 "the lease's beat is absent from the lead transcript" trbeat=none
cell A7e PASS 1 "the lead beat's completion is ENQUEUED (no user record yet)" completion=enqueue
cell A7b PASS 1 "orphan: the transcript's one outstanding beat is not the live record's beat (record task_id differs)" task=other

echo "-- A8 control: the guard itself reports the seeded hold"
set_fields hold=cap; seed_world
bash "$W_GUARD" --hold-status --transcript "$TR" < /dev/null > /dev/null 2>&1; g_rc=$?
[ "$g_rc" -eq 1 ] && ok "A8 control: ai-dlc-dispatch-guard.sh --hold-status exits 1 on the seeded hold" \
  || bad "A8 control: the guard exits $g_rc, not 1, on the seeded hold — A8 would pass for another reason"
cell A8 PASS 1 "a live rejected-spawn hold" hold=cap
echo "-- A9a control: J4's --status answers on A9a's argv exactly as in the BLOCK world"
set_fields dispatch=other; seed_world
st_out="$(cd "$P" && env -i PATH="$BASEPATH" HOME="$H" TMPDIR="$WORK/tmp" CLAUDE_CODE_SESSION_ID="$SID" \
          AI_DLC_PROJECT_ROOT="$P" "$BASH_BIN" "$W_WFD" "$P/deliv.md" --dispatch "$OTHER_AID" --status < /dev/null 2>&1)"; st_rc=$?
case "$st_rc:$st_out" in
  "0:"*"STATUS -- 1 delivered, 0 not."*) ok "A9a control: --status on A9a's argv (--dispatch $OTHER_AID) exits 0 with 'STATUS -- 1 delivered, 0 not.', not 64 — J4 holds, so J3 decides the cell" ;;
  *) bad "A9a control: --status on A9a's argv exits $st_rc ($(printf '%s' "$st_out" | tail -1 | head -c 200)) — J4 would acquit A9a before J3" ;;
esac
cell A9a PASS 1 "the agent id is not in the record's --dispatch set" dispatch=other
cell A9b PASS 1 "the beat carries no --dispatch" dispatch=absent
cell A10u PASS 1 "the path is not DELIVERED (--complete, no marker: UNFINISHED)" argvx=complete
cell A10r BLOCK 1 "argv carrying --reset is evaluated without it and still BLOCKS" argvx=reset
cell A11dev PASS 1 "role dev" role=dev
cell A11qa PASS 1 "role qa" role=qa
cell A11unk PASS 1 "unknown role" role=zzunknown
cell A11named PASS 1 "named teammate: meta.json without toolUseId" meta=notui
cell A12schema PASS 1 "harness-origin.json missing" schema=absent
cell A12jq PASS 1 "jq not on PATH" jq=absent
if [ "$V" = PASS ]; then
  env -i PATH="$C/nojq-bin" "$BASH_BIN" -c 'command -v jq' >/dev/null 2>&1 && bad "A12jq: jq is still reachable on the cell's PATH" \
    || ok "A12jq control: jq is unreachable on the cell's PATH"
fi
cell A12tr PASS 1 "transcript unreadable" trread=no
[ -r "$TR" ] && bad "A12tr: the transcript is still readable (running as root?) — the cell tested nothing"
cell A12s64 PASS 1 "--status prints a full-delivered STATUS line and exits 64" script=stub64
cell A12json PASS 1 "garbled payload JSON" json=garbled
cell A12p0 PASS 1 "AI_DLC_HOOKWAKE unset" p0=off
cell A13b PASS 1 "two outstanding lead beats (the decoy's tool_use id sorts after the real one)" beats=2
cell A13r PASS 1 "two live records (faithful copy behind a second live pid)" records=2
cell A13p PASS 1 "record start time mismatched (pid reuse)" start=wrong

echo "-- A14 block record"
set_fields; seed_world
if [ "$V" = BLOCK ] && [ -f "$P/_bmad-output/.hookwake-blocks.jsonl" ]; then
  if jq -e --arg a "$AID" --arg t "$TASK" --argjson p "$LIVE1" --arg d "$P/deliv.md" \
      'select(.channel == "H" and .agent_id == $a and .beat_task_id == $t and .record_pid == $p
              and (.ts | type == "string" and length > 0) and (.paths | index($d)))' \
      "$P/_bmad-output/.hookwake-blocks.jsonl" >/dev/null 2>&1 \
     && [ "$(grep -c . "$P/_bmad-output/.hookwake-blocks.jsonl")" = 1 ]; then
    ok "A14w BLOCK: one block-record line {ts, channel H, agent_id, beat_task_id $TASK, record_pid, paths}"
  else bad "A14w: the block record does not carry {ts, channel, agent_id, beat_task_id, record_pid, paths}: $(head -c 300 "$P/_bmad-output/.hookwake-blocks.jsonl")"; fi
else bad "A14w: no BLOCK, or no block record written (verdict $V)"; fi
cell A14u BLOCK 1 "the block-record path is unwritable and the hook still BLOCKS" blockrec=unwritable

echo "-- A15 the C5 emission on the beat's own b-wake"
set_fields; seed_world
if [ "$V" = BLOCK ]; then
  run_hook "$W_HOOK" "$P" "$H" "$(prompt_of B)" correct
  if [ "$RC" -eq 0 ] && ctx_has "$OUT" "$P/deliv.md" "$P/_bmad-output/.subagent-final/$AID.txt" \
     && ! printf '%s' "$OUT" | jq -e '.decision? == "block"' >/dev/null 2>&1; then
    ok "A15: the b-wake is not blocked and its additionalContext names $P/deliv.md and .subagent-final/$AID.txt"
  else bad "A15: the b-wake after a block did not emit additionalContext naming the deliverable and .subagent-final/$AID.txt (rc $RC, stdout: $(printf '%s' "$OUT" | head -c 300))"; fi
else bad "A15: the preceding block did not happen (verdict $V)"; fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED"; exit 1
