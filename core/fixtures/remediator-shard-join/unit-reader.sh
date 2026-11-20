#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-reader.sh -- the SEAM cells for the reader-level conversion. Driven by run.sh.
# join-remediator-shards.sh wraps everything below its source guard in join_main, and
# ai-dlc-gate-remediation-guard.sh wraps its payload parse and dispatched-agent recording in hook_pretool_head.
# Each is called below in a subshell and must answer byte-identically (stdout+stderr, exit) to the CLI, on one
# refusing and one passing input, and the two inputs must answer differently.
# Exit: 0 every cell passed, 1 a cell failed, 2 the fixture could not run.
set -u
NAME="remediator-shard-join-reader"
UR_HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$UR_HERE/lib.sh" ] || { echo "FIXTURE BROKEN: lib.sh is absent beside $0" >&2; exit 2; }
# shellcheck source=/dev/null
. "$UR_HERE/lib.sh" > /dev/null || { echo "FIXTURE BROKEN: sourcing lib.sh failed" >&2; exit 2; }
. "$(cd "$UR_HERE/../lib" && pwd)/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
# each in-process pass of a subject below is logged by fx_inproc (lib/mutant.sh) under its root-relative path
RSJ_J=core/scripts/join-remediator-shards.sh; RSJ_H=core/hooks/ai-dlc-gate-remediation-guard.sh

# `bash <subject>` in lib.sh helpers (world builders) runs in process, as in run.sh; the CLI cells below set RS_CLI=1 and tag their one start.
RS_LEADF="$WORK/rs.lead"; RS_ROOT="$PWD"
rs_scrub() { # -> this subshell's names reduced to a CLI child's
  local _uv _ue
  _ue=" $(compgen -e | tr '\n' ' ') "
  for _uv in $(compgen -v); do
    case "$_uv" in
      BASH*|IFS|OPTIND|OPTERR|OPTARG|PPID|UID|EUID|SHELLOPTS|HISTCMD|LINENO|RANDOM|SECONDS|FUNCNAME|PIPESTATUS|GROUPS|DIRSTACK|HOSTTYPE|MACHTYPE|OSTYPE|HOSTNAME|SHLVL|PWD|OLDPWD|_|SRCDIR|RS_*|_uv|_ue|PS1|PS2|PS4) continue ;;
    esac
    case "$_ue" in *" $_uv "*) continue ;; esac
    unset -v "$_uv" 2>/dev/null; unset -v "$_uv" 2>/dev/null
  done
  for _uv in $(compgen -A function); do
    case " bash fx_inproc rs_scrub " in *" $_uv "*) ;; *) unset -f "$_uv" ;; esac
  done
}
bash() {
  [ -z "${RS_CLI:-}" ] || { command bash "$@"; return; }
  RS_K=""
  case "${1:-}" in
    "${SRCDIR:-/nonexistent/rs}/content-seal.sh") RS_K=seal ;;
    "${SRCDIR:-/nonexistent/rs}/serial-remediation-worklist.sh") RS_K=srw ;;
  esac
  if [ -z "$RS_K" ] && [ -z "${RS_IN:-}" ]; then
    case "${1:-}" in
      "${JOIN:-/nonexistent/rs}") RS_K=join ;;
      */ai-dlc-gate-remediation-guard.sh) RS_K=hook ;;
    esac
  fi
  [ -n "$RS_K" ] || { command bash "$@"; return; }
  RS_F="$1"; shift
  (
    RS_IN=1; set +o pipefail
    case "$RS_K" in
      join) fx_inproc "$RS_ROOT/core/scripts/join-remediator-shards.sh";  rs_scrub; . "$RS_F" || exit 125; join_main "$@" ;;
      hook) fx_inproc "$RS_ROOT/core/hooks/ai-dlc-gate-remediation-guard.sh";  rs_scrub; set --; ( . "$RS_F" || exit 125; grg_config; fx_inproc "$RS_ROOT/core/hooks/ai-dlc-gate-remediation-guard.sh"; hook_pretool_head; : > "$RS_LEADF" ) ;;
      seal) rs_scrub; . "${RS_F%/*}/content-seal.sh" || exit 125; fx_inproc "$RS_ROOT/core/scripts/content-seal.sh"; seal_main "$@" ;;
      srw) rs_scrub; . "${RS_F%/*}/serial-remediation-worklist.sh" || exit 125; fx_inproc "$RS_ROOT/core/scripts/serial-remediation-worklist.sh"; srw_main "$@" ;;
    esac
  )
}

# SEAM-JOIN: the same argv through bash "$JOIN" and through join_main in a subshell that sourced the join.
w="$(new_world)"; three_writers "$w"; part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1; stamp "$w"
until="$(jnow)"
pass_args=(--sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" --since 2000-01-01T00:00:00Z --until "$until")
bad_args=(--sprint 305 --artifact stories --pass 1 --since 2000-01-01T00:00:00Z --until "$until")  # no --artifact-path
sj_cli() { # <world> <cell tag> args... -> $SJ_OUT, $SJ_RC (the world's output record removed first so both runs write alike)
  local d; d="$(mktemp -d "$WORK/sj.XXXXXX")" && cp -R "$1" "$d/w" || return 1
  local t="$2"; shift 2
  SJ_OUT="$(RS_CLI=1 FXCELL="cli-join-$t" AI_DLC_PROJECT_ROOT="$d/w" bash "$JOIN" "$@" 2>&1)"; SJ_RC=$?
  SJ_OUT="${SJ_OUT//$d/WORLD}"
}
sj_inproc() {
  local d; d="$(mktemp -d "$WORK/sj.XXXXXX")" && cp -R "$1" "$d/w" || return 1
  shift
  SJ_OUT="$( ( fx_inproc $RSJ_J; export AI_DLC_PROJECT_ROOT="$d/w"; . "$JOIN"; join_main "$@" ) 2>&1)"; SJ_RC=$?
  SJ_OUT="${SJ_OUT//$d/WORLD}"
}
sj_cli "$w" pass "${pass_args[@]}"; p_o="$SJ_OUT"; p_rc=$SJ_RC
sj_inproc "$w" "${pass_args[@]}"; pi_o="$SJ_OUT"; pi_rc=$SJ_RC
sj_cli "$w" refuse "${bad_args[@]}"; r_o="$SJ_OUT"; r_rc=$SJ_RC
sj_inproc "$w" "${bad_args[@]}"; ri_o="$SJ_OUT"; ri_rc=$SJ_RC
if [ "$p_rc" -eq 0 ] && [ "$r_rc" -eq 2 ] && [ "$p_o" != "$r_o" ] && [ "$p_rc" = "$pi_rc" ] && [ "$p_o" = "$pi_o" ] \
   && [ "$r_rc" = "$ri_rc" ] && [ "$r_o" = "$ri_o" ]; then
  ok "SEAM-JOIN: join_main called in process answers byte-identically to the CLI on a passing join (rc 0) and a refusing one (rc 2), and the two differ"
else
  bad "SEAM-JOIN: pass cli rc=$p_rc inproc rc=$pi_rc equal=$([ "$p_o" = "$pi_o" ] && echo y || echo n); refuse cli rc=$r_rc inproc rc=$ri_rc equal=$([ "$r_o" = "$ri_o" ] && echo y || echo n); differ=$([ "$p_o" != "$r_o" ] && echo y || echo n)"
fi

# SEAM-HOOK: hook_pretool_head fed the same payload as the CLI hook records the same ledger row (ts removed).
hk_row() { # <mode cli|inproc> <world> <agent> <cell tag> -> prints the ledger rows with ts removed, "|rc"
  local pl="$WORK/seam.payload" rc
  jq -nc --arg f "$2/$REL/$S21" --arg a "$3" '{session_id:"t", tool_name:"Edit", transcript_path:"", tool_input:{file_path:$f}} + (if $a == "" then {} else {agent_id:$a} end)' > "$pl"
  if [ "$1" = cli ]; then RS_CLI=1 FXCELL="cli-hook-$4" CLAUDE_PROJECT_DIR="$2" bash "$HOOK" < "$pl" >/dev/null 2>&1; rc=$?
  else ( fx_inproc $RSJ_H; export CLAUDE_PROJECT_DIR="$2"; . "$HOOK"; grg_config; fx_inproc $RSJ_H; hook_pretool_head < "$pl" ) >/dev/null 2>&1; rc=$?; fi
  jq -c 'del(.ts)' "$2/_bmad-output/planning-artifacts/.artifact-writes.jsonl" 2>/dev/null | sed "s#$2#WORLD#g"
  echo "rc=$rc"
}
a="$(new_world)"; b="$(new_world)"; c="$(new_world)"; d="$(new_world)"
hc="$(hk_row cli "$a" "$AG1" agent)"; hi="$(hk_row inproc "$b" "$AG1" agent)"
lc="$(hk_row cli "$c" "" lead)"; li="$(hk_row inproc "$d" "" lead)"
if [ "$hc" = "$hi" ] && [ "$lc" = "$li" ] && [ "$hc" != "$lc" ] && grep -q "\"agent_id\":\"$AG1\"" <<<"$hc"; then
  ok "SEAM-HOOK: hook_pretool_head called in process records the same ledger row as the CLI hook for a dispatched agent's Edit, and none (as the CLI) for the lead's, and the two differ"
else
  bad "SEAM-HOOK: dispatched cli=[$hc] inproc=[$hi]; lead cli=[$lc] inproc=[$li]"
fi
[ "$fails" -eq 0 ] && exit 0 || exit 1
