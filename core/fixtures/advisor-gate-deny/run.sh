#!/usr/bin/env bash
# advisor-gate-deny/run.sh — drive the REAL ai-dlc-advisor-gate.sh with synthesized PreToolUse
# JSON over seeded transcripts, then drive a battery of mutants of it through the same arms.
#
# THE DEFECT (BL-459). SKILL.md Rule 32 and every role file name advisor touchpoints, and nothing
# enforced one. The hook denies a gated action while the acting agent holds the advisor tool and
# its own transcript records no advisor attempt since its last gated action.
#
# A wrong deny costs a consumer's push, merge or gate close, so the allow side is pinned as hard
# as the deny side: every deny cell has an allow twin one property apart, named beside it.
#
# ARMS. Each verdict is read from the hook's stdout: DENY (permissionDecision deny), WARN
# (additionalContext saying NOT blocked, no decision) or SILENT (no stdout at all).
#   PUSH         grant, no advisor: `git push -u origin HEAD`, `git -C <d> push ...`,
#                `cd <d> && git push`, `timeout 600 git push` -> DENY
#   REASON       that deny names its remedy: "call the advisor tool, then retry the same command"
#   NOGRANT      the same push with the grant line absent -> SILENT; a teammate whose own file has
#                no grant while its parent's does -> SILENT
#   WITHDRAWN    grant then `available:false` -> SILENT; twin: withdrawn then re-granted -> DENY
#   ORDER        push then advisor -> SILENT; twin: advisor then push -> DENY
#   ERRCLEAR     push, advisor, an errored (non-unavailable) result -> SILENT
#   UNAV         advisor, `unavailable`, push -> WARN; twin REARM: then advisor + success -> DENY
#   MERGE        `gh pr merge 7 --squash --delete-branch` and mcp__github__merge_pull_request -> DENY;
#                twin `gh pr list` -> SILENT
#   CLOSE        `gate-checkpoint.sh ... close` -> DENY; twin `... record 12 PASS` -> SILENT
#   DELETE       `git push origin --delete x`, `-d`, `:x` -> SILENT (twin: PUSH)
#   MENTION      `echo git push origin x`, `grep -c "gh pr merge" log` -> SILENT
#   UPDATE       cwd on `ai-dlc-update/x`: push and merge -> SILENT; twin: same on `sprint/3` -> DENY
#   DETACHED     cwd detached HEAD, cwd not a repository: push -> DENY
#   MATE         teammate, own file grant only, parent HAS an advisor call: verdict write -> DENY;
#                twin: own file with its own advisor call -> SILENT
#   MATEABSENT   teammate whose own file is absent, parent granted, no advisor -> SILENT
#   MATEPUSH     teammate push, own file granted, no advisor -> SILENT (option A)
#   MATEPATH     teammate adversarial pass and repair record -> DENY; twin: the artifact -> SILENT
#   MATEREWRITE  teammate Edit of a verdict it already wrote un-denied -> SILENT; twin: it wrote a
#                DIFFERENT verdict -> DENY
#   DENIED       advisor, push, that push DENIED by this hook -> the retry is SILENT;
#                twin: the same push succeeded -> DENY
#   SELF         advisor, push id tX on disk, incoming tool_use_id tX -> SILENT; twin tY -> DENY
#   TWRITE       NO grant anywhere: Write onto a transcript, `>>`, `tee -a`, `sed -i`, `mv` onto one,
#                via `~` too -> DENY
#   TWRITEREAD   `cat <t> > out`, `cp <t> out`, a Write of a memory `.md` beside it -> SILENT
#   GATELOG      Edit adding a `## Gate Log:` heading, a Write adding one, a Bash append carrying one
#                -> DENY; twins: header-only Write (the rotation), a Write keeping one heading,
#                `tail` of the log -> SILENT
#   FAILOPEN     unparseable input, a missing transcript -> SILENT, and stderr says why
#   EXIT         every call exits 0
#
# MUTANTS. Each is a copy of the hook beside a copy of its provenance sibling, guarded with
# `cmp -s` so a `sed` that matched nothing reports DID NOT APPLY. Each declares the EXACT set of
# arms it must fail, and the battery asserts set equality. An unmutated copy driven the same way
# must fail nothing, and PUSH gives that control its positive conjunct.
set -uo pipefail

# The pre-push gate exports AI_DLC_* tunables; none is read here, but scrub them all the same.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
[ -n "$WORK" ] && [ -f "$WORK/env.sh" ] || { echo "FIXTURE ERROR: seed printed no work dir" >&2; exit 2; }
# shellcheck source=/dev/null
. "$WORK/env.sh"

command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq not found; the hook is silent without it, so no arm here could fire" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

OUTF="$W/out"; ERRF="$W/err"

# --- transcript lines, in the shapes the harness writes (measured on this repo's transcripts) ---
GRANT='{"type":"attachment","attachment":{"type":"advisor_tool","available":true,"toolChange":"add","model":"m"}}'
GOFF='{"type":"attachment","attachment":{"type":"advisor_tool","available":false,"toolChange":"remove","model":"m"}}'
USER='{"type":"user","message":{"role":"user","content":"go"}}'
ADV='{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"s1","name":"advisor","input":{}}]}}'
OKRES='{"type":"assistant","message":{"content":[{"type":"advisor_tool_result","tool_use_id":"s1","content":{"type":"advisor_redacted_result"}}]}}'
UNAV='{"type":"assistant","message":{"content":[{"type":"advisor_tool_result","tool_use_id":"s1","content":{"type":"advisor_tool_result_error","error_code":"unavailable"}}]}}'
ERRRES='{"type":"assistant","message":{"content":[{"type":"advisor_tool_result","tool_use_id":"s1","content":{"type":"advisor_tool_result_error","error_code":"too_many_requests"}}]}}'
# tu <id> <tool> <input-json>
tu() { jq -cn --arg id "$1" --arg n "$2" --argjson i "$3" '{type:"assistant",message:{content:[{type:"tool_use",id:$id,name:$n,input:$i}]}}'; }
# tr <id> <is_error> <text>
tr_() { jq -cn --arg id "$1" --argjson e "$2" --arg t "$3" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:$id,is_error:$e,content:$t}]}}'; }
PUSHL="$(tu t1 Bash '{"command":"git push -u origin HEAD"}')"
PUSH9="$(tu t9 Bash '{"command":"git push -u origin HEAD"}')"
DENY9="$(tr_ t9 true 'PreToolUse:Bash hook error: ai-dlc-advisor-gate: DENIED -- call the advisor tool, then retry the same command.')"
OK9="$(tr_ t9 false 'Everything up-to-date')"

VERDICT="$SPRINT/_bmad-output/gate-adjudication/implementation-20261006T120000Z.verdict.json"
VERDICT2="$SPRINT/_bmad-output/gate-adjudication/story-20261006T110000Z.verdict.json"
ADVP="$SPRINT/_bmad-output/planning-artifacts/s3/prd-adversarial-p2.md"
REPR="$SPRINT/_bmad-output/planning-artifacts/s3/prd-repair-p2.md"
ARTF="$SPRINT/_bmad-output/planning-artifacts/s3/prd.md"
WV="$(tu w1 Write "$(jq -cn --arg f "$VERDICT" '{file_path:$f,content:"{}"}')")"
WV2="$(tu w1 Write "$(jq -cn --arg f "$VERDICT2" '{file_path:$f,content:"{}"}')")"

# mk <file> <line>... -- one world's transcript
mk() { local f="$1"; shift; mkdir -p "$(dirname "$f")"; : > "$f"; local l; for l in "$@"; do printf '%s\n' "$l" >> "$f"; done; }
mk "$P1/g.jsonl"        "$USER" "$GRANT"
mk "$P1/none.jsonl"     "$USER"
mk "$P1/off.jsonl"      "$GRANT" "$GOFF"
mk "$P1/regrant.jsonl"  "$GOFF" "$GRANT"
mk "$P1/pa.jsonl"       "$GRANT" "$PUSHL" "$ADV"
mk "$P1/ap.jsonl"       "$GRANT" "$ADV" "$PUSHL"
mk "$P1/err.jsonl"      "$GRANT" "$PUSHL" "$ADV" "$ERRRES"
mk "$P1/unav.jsonl"     "$GRANT" "$ADV" "$UNAV" "$PUSHL"
mk "$P1/rearm.jsonl"    "$GRANT" "$ADV" "$UNAV" "$ADV" "$OKRES" "$PUSHL"
mk "$P1/denied.jsonl"   "$GRANT" "$ADV" "$PUSH9" "$DENY9"
mk "$P1/pushed.jsonl"   "$GRANT" "$ADV" "$PUSH9" "$OK9"
mk "$P1/par.jsonl"      "$GRANT" "$ADV"
mk "$P1/par/subagents/agent-a1.jsonl" "$USER" "$GRANT"
mk "$P1/par/subagents/agent-a2.jsonl" "$USER" "$GRANT" "$ADV" "$OKRES"
mk "$P1/par/subagents/agent-a4.jsonl" "$USER"
mk "$P1/par/subagents/agent-a5.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)"
mk "$P1/par/subagents/agent-a6.jsonl" "$GRANT" "$WV2" "$(tr_ w1 false ok)"
mk "$P1/q.jsonl"        "$GRANT"
mkdir -p "$P1/q/subagents"
for _f in g none off regrant pa ap err unav rearm denied pushed par q; do
  [ -s "$P1/$_f.jsonl" ] || { echo "FIXTURE BROKEN: world $_f was not written" >&2; exit 2; }
done

# call <hook> <json> -> sets RC, V (DENY|WARN|SILENT|OTHER), REASON_TXT, ERR_TXT
call() {
  printf '%s' "$2" | env HOME="$W" CLAUDE_PROJECT_DIR="$CPD" bash "$1" >"$OUTF" 2>"$ERRF"
  RC=$?
  local out; out="$(cat "$OUTF")"
  REASON_TXT="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' "$OUTF" 2>/dev/null)"
  ERR_TXT="$(cat "$ERRF")"
  if [ -z "$out" ]; then V=SILENT
  elif [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' "$OUTF" 2>/dev/null)" = deny ]; then V=DENY
  elif jq -e '(.hookSpecificOutput.permissionDecision == null) and ((.hookSpecificOutput.additionalContext // "") | contains("NOT blocked"))' "$OUTF" >/dev/null 2>&1; then V=WARN
  else V=OTHER; fi
}
# bash_in <transcript> <cwd> <command> [agent_id] [tool_use_id]
bash_in() { jq -cn --arg t "$1" --arg d "$2" --arg c "$3" --arg a "${4:-}" --arg u "${5:-tNEW}" \
  '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},transcript_path:$t,cwd:$d,tool_use_id:$u} + (if $a == "" then {} else {agent_id:$a} end)'; }
# tool_in <transcript> <tool> <input-json> [agent_id]
tool_in() { jq -cn --arg t "$1" --arg n "$2" --argjson i "$3" --arg a "${4:-}" --arg d "$SPRINT" \
  '{hook_event_name:"PreToolUse",tool_name:$n,tool_input:$i,transcript_path:$t,cwd:$d,tool_use_id:"tNEW"} + (if $a == "" then {} else {agent_id:$a} end)'; }
write_in() { tool_in "$1" Write "$(jq -cn --arg f "$2" --arg c "${4:-x}" '{file_path:$f,content:$c}')" "${3:-}"; }

# score <hook> -> prints the space-separated, C-sorted set of arms that FAILED, or nothing
score() {
  local h="$1" failed="" exitbad=0
  note() { case " $failed " in *" $1 "*) ;; *) failed="$failed $1" ;; esac; }
  want() { [ "$RC" -eq 0 ] || exitbad=1; [ "$V" = "$1" ] || note "$2"; }

  for c in 'git push -u origin HEAD' "git -C $SPRINT push origin HEAD:refs/heads/release/1" "cd $SPRINT && git push" 'timeout 600 git push origin sprint/3'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want DENY PUSH
  done
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'git push -u origin HEAD')"
  case "$REASON_TXT" in *'call the advisor tool, then retry the same command'*) ;; *) note REASON ;; esac

  call "$h" "$(bash_in "$P1/none.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT NOGRANT
  call "$h" "$(write_in "$P1/par.jsonl" "$VERDICT" a4)"; want SILENT NOGRANT

  call "$h" "$(bash_in "$P1/off.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT WITHDRAWN
  call "$h" "$(bash_in "$P1/regrant.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want DENY WITHDRAWN

  call "$h" "$(bash_in "$P1/pa.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT ORDER
  call "$h" "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want DENY ORDER

  call "$h" "$(bash_in "$P1/err.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT ERRCLEAR

  call "$h" "$(bash_in "$P1/unav.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want WARN UNAV
  call "$h" "$(bash_in "$P1/rearm.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want DENY REARM

  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'gh pr merge 7 --squash --delete-branch')"; want DENY MERGE
  call "$h" "$(tool_in "$P1/g.jsonl" mcp__github__merge_pull_request '{"owner":"o","repo":"r","pullNumber":7}')"; want DENY MERGE
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'gh pr list --state merged --limit 3')"; want SILENT MERGE

  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'bash scripts/ai-dlc/gate-checkpoint.sh --nonce implementation-20261006T120000Z close')"; want DENY CLOSE
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'scripts/ai-dlc/gate-checkpoint.sh --nonce implementation-20261006T120000Z record 12 PASS')"; want SILENT CLOSE

  for c in 'git push origin --delete release/0.1.0' 'git push -d origin release/0.1.0' 'git push origin :release/0.1.0'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want SILENT DELETE
  done

  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'echo git push origin x')"; want SILENT MENTION
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'grep -c "gh pr merge" log')"; want SILENT MENTION

  call "$h" "$(bash_in "$P1/g.jsonl" "$UPDATE" 'git push -u origin ai-dlc-update/x')"; want SILENT UPDATE
  call "$h" "$(bash_in "$P1/g.jsonl" "$UPDATE" 'gh pr merge 9 --squash --delete-branch')"; want SILENT UPDATE
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'git push -u origin ai-dlc-update/x')"; want DENY UPDATE
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'gh pr merge 9 --squash --delete-branch')"; want DENY UPDATE

  call "$h" "$(bash_in "$P1/g.jsonl" "$DETACHED" 'git push -u origin HEAD')"; want DENY DETACHED
  call "$h" "$(bash_in "$P1/g.jsonl" "$NOREPO" 'git push -u origin HEAD')"; want DENY DETACHED

  call "$h" "$(write_in "$P1/par.jsonl" "$VERDICT" a1)"; want DENY MATE
  call "$h" "$(write_in "$P1/par.jsonl" "$VERDICT" a2)"; want SILENT MATE

  call "$h" "$(write_in "$P1/q.jsonl" "$VERDICT" a3)"; want SILENT MATEABSENT
  ERR_A3="$ERR_TXT"
  case "$ERR_A3" in *'agent-a3.jsonl'*) ;; *) note MATEABSENT ;; esac

  call "$h" "$(bash_in "$P1/par.jsonl" "$SPRINT" 'git push -u origin HEAD' a1)"; want SILENT MATEPUSH

  call "$h" "$(write_in "$P1/par.jsonl" "$ADVP" a1)"; want DENY MATEPATH
  call "$h" "$(write_in "$P1/par.jsonl" "$REPR" a1)"; want DENY MATEPATH
  call "$h" "$(write_in "$P1/par.jsonl" "$ARTF" a1)"; want SILENT MATEPATH

  call "$h" "$(tool_in "$P1/par.jsonl" Edit "$(jq -cn --arg f "$VERDICT" '{file_path:$f,old_string:"a",new_string:"b"}')" a5)"; want SILENT MATEREWRITE
  call "$h" "$(tool_in "$P1/par.jsonl" Edit "$(jq -cn --arg f "$VERDICT" '{file_path:$f,old_string:"a",new_string:"b"}')" a6)"; want DENY MATEREWRITE

  call "$h" "$(bash_in "$P1/denied.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT DENIED
  call "$h" "$(bash_in "$P1/pushed.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want DENY DENIED

  call "$h" "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD' '' t1)"; want SILENT SELF
  call "$h" "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD' '' tY)"; want DENY SELF

  call "$h" "$(write_in "$P1/none.jsonl" "$P1/none.jsonl")"; want DENY TWRITE
  for c in "echo x >> $P1/none.jsonl" "printf x | tee -a ~/projects/p1/none.jsonl" "sed -i '' s/a/b/ $P1/par/subagents/agent-a1.jsonl" "mv $W/out ~/projects/p1/none.jsonl"; do
    call "$h" "$(bash_in "$P1/none.jsonl" "$SPRINT" "$c")"; want DENY TWRITE
  done
  call "$h" "$(bash_in "$P1/none.jsonl" "$SPRINT" "cat $P1/none.jsonl > $W/copy.txt")"; want SILENT TWRITEREAD
  call "$h" "$(bash_in "$P1/none.jsonl" "$SPRINT" "cp ~/projects/p1/none.jsonl $W/copy.jsonl")"; want SILENT TWRITEREAD
  call "$h" "$(write_in "$P1/none.jsonl" "$P1/memory/MEMORY.md")"; want SILENT TWRITEREAD

  call "$h" "$(tool_in "$P1/g.jsonl" Edit "$(jq -cn --arg f "$GL" '{file_path:$f,old_string:"| check | verdict |\n",new_string:"| check | verdict |\n\n## Gate Log: Sprint 3\nTimestamp: 2026-10-06T12:00Z\n"}')")"; want DENY GATELOG
  call "$h" "$(write_in "$P1/g.jsonl" "$GL" '' "$(printf '# Gate Log\n\n## Gate Log: Sprint 2\n\n## Gate Log: Sprint 3\n')")"; want DENY GATELOG
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "printf '\n## Gate Log: Sprint 3\n' >> _bmad-output/implementation-artifacts/gate-log.md")"; want DENY GATELOG
  call "$h" "$(write_in "$P1/g.jsonl" "$GL" '' "$(printf '# Gate Log\n')")"; want SILENT GATELOG
  call "$h" "$(write_in "$P1/g.jsonl" "$GL" '' "$(printf '# Gate Log\n\n## Gate Log: Sprint 2\nedited\n')")"; want SILENT GATELOG
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'tail -20 _bmad-output/implementation-artifacts/gate-log.md')"; want SILENT GATELOG

  call "$h" '{"tool_name":"Bash","tool_input":{"command":"git push"'; want SILENT FAILOPEN
  case "$ERR_TXT" in *'not readable JSON'*) ;; *) note FAILOPEN ;; esac
  call "$h" "$(bash_in "$P1/absent.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT FAILOPEN
  case "$ERR_TXT" in *'gate skipped'*) ;; *) note FAILOPEN ;; esac

  [ "$exitbad" -eq 0 ] || note EXIT
  printf '%s\n' "$failed" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'
}

echo "advisor-gate-deny:"
printf '  hook  %s\n' "$HOOK"

# The world the UPDATE arm's twin rests on: the two repositories must really be on different branches.
_bs="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$SPRINT" symbolic-ref --short -q HEAD)"
_bu="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$UPDATE" symbolic-ref --short -q HEAD)"
_bd="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$DETACHED" symbolic-ref --short -q HEAD)"
[ "$_bs" = sprint/3 ] && [ "$_bu" = ai-dlc-update/x ] && [ -z "$_bd" ] \
  || { echo "FIXTURE BROKEN: seeded branches read sprint='$_bs' update='$_bu' detached='$_bd'" >&2; exit 2; }

# --- the shipped hook ------------------------------------------------------------------------
[ -x "$HOOK" ] || bad "hook is not executable: $HOOK -- settings.json invokes it as a bare path"
GOT="$(score "$HOOK")"
if [ -z "$GOT" ]; then
  ok "shipped hook passes every arm (PUSH REASON NOGRANT WITHDRAWN ORDER ERRCLEAR UNAV REARM MERGE CLOSE DELETE MENTION UPDATE DETACHED MATE MATEABSENT MATEPUSH MATEPATH MATEREWRITE DENIED SELF TWRITE TWRITEREAD GATELOG FAILOPEN EXIT)"
else
  bad "shipped hook fails arm(s): $GOT"
fi

# --- mutants ---------------------------------------------------------------------------------
n_mut=0; n_kill=0
[ -f "$PROV" ] && cp "$PROV" "$MUT/ai-dlc-context-provenance.sh"
# mut <name> <expected-failing-arms> <sed-expr>...
mut() {
  local name="$1" want="$2"; shift 2
  local m="$MUT/hook-$name.sh"
  if ! sed "$@" "$HOOK" > "$m"; then bad "mutant $name: sed failed -- DID NOT APPLY"; return; fi
  if cmp -s "$HOOK" "$m"; then bad "mutant $name: sed matched nothing -- DID NOT APPLY (the anchor moved)"; return; fi
  n_mut=$((n_mut+1))
  local got; got="$(score "$m")"
  if [ "$got" = "$want" ]; then
    n_kill=$((n_kill+1)); ok "mutant $name killed by exactly: $want"
  elif [ -z "$got" ]; then
    bad "mutant $name SURVIVED every arm (expected to fail: $want)"
  else
    bad "mutant $name failed [$got], expected exactly [$want]"
  fi
}

cp "$HOOK" "$MUT/hook-control.sh"
CTL="$(score "$MUT/hook-control.sh")"
[ -z "$CTL" ] && ok "unmutated copy from the mutant directory passes every arm" \
              || bad "unmutated copy fails [$CTL] -- the harness, not a mutant, is what fails"

# Expected sets are C-locale sorted, which is what score() prints.
# 1. the whole subject replaced by silence: every arm holding a DENY, WARN or stderr cell fails.
mut silence "CLOSE DENIED DETACHED FAILOPEN GATELOG MATE MATEABSENT MATEPATH MATEREWRITE MERGE ORDER PUSH REARM REASON SELF TWRITE UNAV UPDATE WITHDRAWN" -e '2i\
exit 0'
# 2. warn-only: the rejected design, the same text as context with no decision.
#    UNAV survives it by design: the warn path is its own emission and this mutant leaves it intact.
mut warn-only "CLOSE DENIED DETACHED GATELOG MATE MATEPATH MATEREWRITE MERGE ORDER PUSH REARM REASON SELF TWRITE UPDATE WITHDRAWN" \
  -e 's/permissionDecision: "deny", permissionDecisionReason: \$m/additionalContext: $m/'
# 3. no grant test: a hook with a knob-free default of ON.
mut no-grant-test "NOGRANT WITHDRAWN" -e '/^\[ "\${GRANT:-none}" = on \] || exit 0$/d'
# 4. a withdrawn grant still counts as granted.
mut withdrawn-ignored "WITHDRAWN" -e 's/\.grant = ((\$l\.attachment\.available != false) and (\$l\.attachment\.toolChange != "remove"))/.grant = true/'
# 5. the unavailable carve-out removed: the deny nothing can clear.
mut no-unavailable-warn "UNAV" -e 's/if \[ "\${LAST_RES:--}" = U \]; then/if [ "${LAST_RES:--}" = NEVER ]; then/'
# 6. a later success does not re-arm.
mut no-rearm "REARM" -e 's/then "U" else "R" end)/then "U" else .res end)/'
# 7. only a SUCCESSFUL attempt clears: an errored attempt is discarded.
mut error-does-not-clear "ERRCLEAR" \
  -e 's/elif \$b\.type == "advisor_tool_result" then/elif $b.type == "advisor_tool_result" and ((($b.content | if type == "object" then .error_code else null end) \/\/ "unavailable") != "unavailable") then .adv = 0 elif $b.type == "advisor_tool_result" then/'
# 8. any advisor call ever clears, whatever came after it. UNAV and REARM die too: both worlds
#    hold an advisor call BEFORE the owed push, so the mutant allows where they warn and deny.
mut any-advisor-clears "DENIED ORDER REARM SELF UNAV" -e 's/\[ "\${LAST_ADV:-0}" -gt "\${LAST_ACT:-0}" \]/[ "${LAST_ADV:-0}" -gt 0 ]/'
# 9. a branch delete is gated.
mut delete-gated "DELETE" -e 's/gitpush and (isdelete | not)/gitpush/'
# 10. the MCP merge tool escapes.
mut no-mcp-merge "MERGE" -e 's/if \.name == "mcp__github__merge_pull_request" then "merge"/if .name == "mcp__NEVER" then "merge"/'
# 11. `record` gated alongside `close`.
mut record-gated "CLOSE" -e 's/\\\\sclose(\\\\s|\$)/\\\\s(close|record)(\\\\s|$)/'
# 12. the push match loses its start anchor, so a mention is a push.
mut push-unanchored "MENTION" -e 's/def gitpush: test("^(timeout/def gitpush: test("(timeout/'
# 13. the update skill's branch is gated.
mut update-gated "UPDATE" -e 's|ai-dlc-update/\*) exit 0 ;;|ai-dlc-update-NEVER/*) exit 0 ;;|'
# 14. a detached HEAD or a git failure is read as the update branch.
mut detached-excluded "DETACHED" -e 's|\|\| _br=""$|\|\| _br="ai-dlc-update/unknown"|'
# 15. a teammate is judged on the handed (parent) transcript. Every teammate world whose parent
#     holds an advisor call dies, which is the point: the parent's call clears the teammate.
mut mate-on-parent "MATE MATEABSENT MATEPATH MATEREWRITE" -e 's|^\[ -z "\$AID" \] \|\| JUDGED=.*$|:|'
# 16. an absent teammate file falls back to the handed path (the operator's local hook).
mut mate-fallback "MATEABSENT" -e 's/^\[ -r "\$JUDGED" \] || {/[ -r "$JUDGED" ] || JUDGED="$TP"; [ -r "$JUDGED" ] || {/'
# 17. a teammate's push is gated like the lead's.
mut mate-push-gated "MATEPUSH" -e 's/def kind(\$role): if \$role == "lead" then leadkind else matekind end;/def kind($role): leadkind + matekind;/'
# 18. every teammate write is a verdict.
mut mate-any-write "MATEPATH" -e 's/then "verdict" else "" end/then "verdict" else "verdict" end/'
# 19. a re-write of the agent's own deliverable is a new gated action.
mut no-rewrite-exemption "MATEREWRITE" -e 's/\[ "\${SAME:-0}" -gt 0 \]/[ "${SAME:-0}" -gt 99999 ]/'
# 20. a call this hook denied is counted as a gated action.
mut denied-counted "DENIED" -e 's/\.g |= del(\.\[(\$b\.tool_use_id \/\/ "") | tostring\])/./'
# 21. the incoming call, already on disk, is counted against itself.
mut self-counted "SELF" -e 's/and ((\$b\.id | tostring) != \$tuid)/and true/'
# 22. the transcript-write deny is conditioned on the grant (deleting the grant line disables it).
mut twrite-needs-grant "TWRITE" -e 's/^if \[ "\$KIND" = twrite \]; then$/if [ "$KIND" = twrite ] \&\& grep -q advisor_tool "$TP" 2>\/dev\/null; then/'
# 23. the projects directory is assumed at ~/.claude/projects rather than derived.
mut twrite-fixed-dir "TWRITE" -e 's|(\$tp \| if test("^.+/\[^/\]+/\[^/\]+\\\\.jsonl\$") then sub("/\[^/\]+/\[^/\]+\$"; "") else "" end) as \$proj|($home + "/.claude/projects") as $proj|'
# 24. a mention of the transcript plus any `>` is read as a write.
mut twrite-any-redirect "TWRITEREAD" -e 's/((\$c | redirs | map(expand(\$home) | under(\$proj)) | any)/((($c | contains($proj + "\/")) and ($c | contains(">")))/'
# 25. any Write to gate-log.md is Check 12, the header-only rotation included.
mut gatelog-by-path "GATELOG" -e 's/then (if ((\.input\.content \/\/ "") | tostring | heads) > 0 then "gatelogw" else "" end)/then "gatelog"/'

[ "$n_mut" -gt 0 ] && [ "$n_kill" -eq "$n_mut" ] \
  && ok "$n_kill of $n_mut mutants killed" \
  || bad "$n_kill of $n_mut mutants killed"

echo
if [ "$fails" -eq 0 ]; then echo "advisor-gate-deny: PASS"; exit 0; fi
echo "advisor-gate-deny: $fails assertion(s) FAILED" >&2
exit 1
