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
#   UPDATEREF    from `sprint/3`, every refspec destination `ai-dlc-update/*` (bare, `HEAD:refs/heads/`,
#                redirected, inside `nohup bash -c 'exec setsid ...'`) -> SILENT; twins `ai-dlc-updated/x`,
#                `HEAD:ai-dlc-update-x`, `sprint/3 ai-dlc-update/x` -> DENY
#   UPDATECUT    `checkout -b`/`switch -c ai-dlc-update/x` then push HEAD, and `B=ai-dlc-update/..;
#                checkout -q -b $B ... push $B` -> SILENT; twins: cut `feature/x`, cut the update
#                branch but push `sprint/3`, `B=sprint/9` -> DENY
#   WRAP STACK BASHC PATHGIT BODY QUOTEDC QUOTEDENV GHREPO MCPNAME
#                the D5 spellings measured in the consumer's commands -> DENY, each with an allow
#                twin carrying the same wrapper around a non-push (`time ls`, `bash -c "echo git
#                push"`, `/usr/bin/git push-status`, `gh -R r pr list`, `mcp__..__merge_pull_request_status`)
#   QUOTEDPAT    `pgrep -fl 'x|git push'` -> SILENT (the bash -c quote shedding must not reach it)
#   PERKIND      advisor, push, then merge -> SILENT; advisor, merge, then push -> SILENT; advisor,
#                push, merge, then the next push -> DENY and the next merge -> DENY; advisor, close,
#                then a Check 12 append -> SILENT; twin: the next close -> DENY
#   REDISPATCH   a teammate's verdict re-write after a user TEXT line (string, text block) -> DENY,
#                also when an advisor call preceded the FIRST write; twin MATEREWRITE -> SILENT
#   ENVELOPE     a push that ran and printed this hook's token in failing output -> still DENY
#   SELFLAST     no tool_use_id, the incoming push is the last line after an advisor -> SILENT;
#                twin: the same push already answered by a tool_result -> DENY
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
# GOFF and GREGRANT are the shapes measured on a `--resume --model` switch away from and back to a
# model carrying the tool (`claude -p` 2.1.291; the hook header records the run).
GOFF='{"type":"attachment","attachment":{"type":"advisor_tool","available":false,"model":"m","toolChange":"remove","byBase":true}}'
GREGRANT='{"type":"attachment","attachment":{"type":"advisor_tool","available":true,"model":"m","abbreviated":true,"toolChange":"add"}}'
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
OK1="$(tr_ t1 false 'Everything up-to-date')"
# The real denial envelope as a text-block array, and a push that RAN, failed, and printed the token.
DENY9A="$(jq -cn '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"t9",is_error:true,content:[{type:"text",text:"PreToolUse:Bash hook error: ai-dlc-advisor-gate: DENIED -- call the advisor tool, then retry the same command."}]}]}}')"
RAN9="$(tr_ t9 true 'Exit code 1
remote: pre-receive said: ai-dlc-advisor-gate: DENIED -- call the advisor tool
error: failed to push some refs')"
# A re-dispatch: a user line carrying TEXT (measured: a string, isMeta on coordinator messages).
UTXT='{"type":"user","message":{"role":"user","content":"The coordinator sent a message while you were working: re-run pass 2"},"isMeta":true}'
UTXTA='{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Adversarial pass 3 of the series."}]}}'

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
mk "$P1/regrant.jsonl"  "$GRANT" "$GOFF" "$GREGRANT"
mk "$P1/pa.jsonl"       "$GRANT" "$PUSHL" "$ADV"
mk "$P1/ap.jsonl"       "$GRANT" "$ADV" "$PUSHL"
mk "$P1/err.jsonl"      "$GRANT" "$PUSHL" "$ADV" "$ERRRES"
mk "$P1/unav.jsonl"     "$GRANT" "$ADV" "$UNAV" "$PUSHL"
mk "$P1/rearm.jsonl"    "$GRANT" "$ADV" "$UNAV" "$ADV" "$OKRES" "$PUSHL"
mk "$P1/denied.jsonl"   "$GRANT" "$ADV" "$PUSH9" "$DENY9"
mk "$P1/pushed.jsonl"   "$GRANT" "$ADV" "$PUSH9" "$OK9"
mk "$P1/deniedarr.jsonl" "$GRANT" "$ADV" "$PUSH9" "$DENY9A"
mk "$P1/ran.jsonl"      "$GRANT" "$ADV" "$PUSH9" "$RAN9"
mk "$P1/apok.jsonl"     "$GRANT" "$ADV" "$PUSHL" "$OK1"
# PER-KIND worlds: one advisor call, then gated actions of different kinds, each answered.
MERGEL="$(tu t2 Bash '{"command":"gh pr merge 7 --squash --delete-branch"}')"
CLOSEL="$(tu t3 Bash '{"command":"bash scripts/ai-dlc/gate-checkpoint.sh --nonce n close"}')"
mk "$P1/apm.jsonl"      "$GRANT" "$ADV" "$PUSHL" "$OK1" "$MERGEL" "$(tr_ t2 false merged)"
mk "$P1/amp.jsonl"      "$GRANT" "$ADV" "$MERGEL" "$(tr_ t2 false merged)"
mk "$P1/ap1.jsonl"      "$GRANT" "$ADV" "$PUSHL" "$OK1"
mk "$P1/ac.jsonl"       "$GRANT" "$ADV" "$CLOSEL" "$(tr_ t3 false closed)"
mk "$P1/par.jsonl"      "$GRANT" "$ADV"
mk "$P1/par/subagents/agent-a1.jsonl" "$USER" "$GRANT"
mk "$P1/par/subagents/agent-a2.jsonl" "$USER" "$GRANT" "$ADV" "$OKRES"
mk "$P1/par/subagents/agent-a4.jsonl" "$USER"
mk "$P1/par/subagents/agent-a5.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)"
mk "$P1/par/subagents/agent-a6.jsonl" "$GRANT" "$WV2" "$(tr_ w1 false ok)"
mk "$P1/par/subagents/agent-a7.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)" "$UTXT"
mk "$P1/par/subagents/agent-a8.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)" "$UTXTA"
mk "$P1/par/subagents/agent-a9.jsonl" "$GRANT" "$ADV" "$WV" "$(tr_ w1 false ok)" "$UTXT"
mk "$P1/q.jsonl"        "$GRANT"
mkdir -p "$P1/q/subagents"
for _f in g none off regrant pa ap err unav rearm denied pushed deniedarr ran apok par q par/subagents/agent-a7 par/subagents/agent-a9; do
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
#   tool_use_id `-` omits the key, the shape of a harness that does not send one
bash_in() { jq -cn --arg t "$1" --arg d "$2" --arg c "$3" --arg a "${4:-}" --arg u "${5:-tNEW}" \
  '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},transcript_path:$t,cwd:$d} + (if $u == "-" then {} else {tool_use_id:$u} end) + (if $a == "" then {} else {agent_id:$a} end)'; }
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

  call "$h" "$(bash_in "$P1/g.jsonl" "$UPDATE" 'git push -u origin HEAD')"; want SILENT UPDATE
  call "$h" "$(bash_in "$P1/g.jsonl" "$UPDATE" 'gh pr merge 9 --squash --delete-branch')"; want SILENT UPDATE
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want DENY UPDATE
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'gh pr merge 9 --squash --delete-branch')"; want DENY UPDATE

  # D3, from the SPRINT cwd: the update branch named as every refspec destination.
  for c in 'git push -u origin ai-dlc-update/x' 'git push -u origin HEAD:refs/heads/ai-dlc-update/x' 'git push -u origin ai-dlc-update/x > /tmp/push.txt 2>&1; echo rc=$?'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want SILENT UPDATEREF
  done
  for c in 'git push -u origin ai-dlc-updated/x' 'git push -u origin HEAD:ai-dlc-update-x' 'git push origin sprint/3 ai-dlc-update/x'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want DENY UPDATEREF
  done
  # D3: the update branch cut in the same command (the real `B=...; checkout -q -b $B` shape too).
  for c in 'git checkout -b ai-dlc-update/x && git commit -qm x && git push -u origin HEAD' 'git switch -c ai-dlc-update/x && git push' 'B=ai-dlc-update/ledger-20260929; git checkout -q -b $B && git add f && git commit -q -m x; git push -u origin $B > /tmp/p 2>&1'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want SILENT UPDATECUT
  done
  for c in 'git checkout -b feature/x && git push -u origin HEAD' 'git checkout -b ai-dlc-update/x && git push origin sprint/3' 'B=sprint/9; git checkout -b $B && git push -u origin $B'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want DENY UPDATECUT
  done

  # D5: every spelling measured in the consumer's commands, each class with its allow twin.
  for c in 'nohup git push -u origin sprint/3 > /tmp/p.txt 2>&1 &' 'exec git push' 'command git push' 'time git push' 'sudo git push' 'caffeinate -i git push' 'gtimeout 600 git push' 'env -u GIT_DIR git push'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want DENY WRAP
  done
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'time ls -la')"; want SILENT WRAP
  for c in "nohup bash -c 'exec setsid git push -u origin sprint/3 > /tmp/p 2>&1' &" 'time nohup git push' 'sudo -E caffeinate -i git push'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want DENY STACK
  done
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "nohup bash -c 'exec setsid git fetch -q origin > /tmp/p 2>&1' &")"; want SILENT STACK
  # The real update-skill spelling of the same stack is excluded by its refspec (UPDATEREF owns why).
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "nohup bash -c 'exec setsid git push -u origin ai-dlc-update/0.622.0-reconcile-20260922T074403Z > /tmp/p 2>&1' &")"; want SILENT UPDATEREF
  for c in 'bash -c "git push"' "sh -c 'git push -u origin HEAD'"; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want DENY BASHC
  done
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'bash -c "echo git push"')"; want SILENT BASHC
  # A quoted alternation carrying `git push` is a pattern, not a push (4 real graph rows).
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "pgrep -fl 'wait-for-deliverable|git push' | grep -v pgrep")"; want SILENT QUOTEDPAT
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" '/usr/bin/git push')"; want DENY PATHGIT
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" '/usr/bin/git push-status')"; want SILENT PATHGIT
  for c in 'if true; then git push; fi' 'for i in 1; do git push; done' '{ git push; }'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want DENY BODY
  done
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'if true; then echo git push; fi')"; want SILENT BODY
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'git -c "user.name=a b" push origin HEAD')"; want DENY QUOTEDC
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'git -c "user.name=a b" log --grep push')"; want SILENT QUOTEDC
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'GIT_SSH_COMMAND="ssh -o X=1" git push')"; want DENY QUOTEDENV
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'MSG="git push" echo hi')"; want SILENT QUOTEDENV
  for c in 'gh -R euron8/graph pr merge 7 --squash' 'gh --repo euron8/graph pr merge 7' 'gh --repo=euron8/graph pr merge 7'; do
    call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$c")"; want DENY GHREPO
  done
  call "$h" "$(bash_in "$P1/g.jsonl" "$SPRINT" 'gh -R euron8/graph pr list')"; want SILENT GHREPO
  call "$h" "$(tool_in "$P1/g.jsonl" mcp__gh2__merge_pull_request '{"owner":"o","repo":"r","pullNumber":7}')"; want DENY MCPNAME
  call "$h" "$(tool_in "$P1/g.jsonl" mcp__github__merge_pull_request_status '{"owner":"o","repo":"r","pullNumber":7}')"; want SILENT MCPNAME

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

  # D4: a re-dispatch (a user TEXT line, string or text block) ends the re-write exemption;
  # twin: a5 has only a tool_result after its write and stays exempt (MATEREWRITE above);
  # a9 called the advisor BEFORE its first write, so the cleared path must not hide that the
  # write is still its last gated action -- an advisor older than it does not clear.
  call "$h" "$(tool_in "$P1/par.jsonl" Edit "$(jq -cn --arg f "$VERDICT" '{file_path:$f,old_string:"PASS",new_string:"FAIL"}')" a7)"; want DENY REDISPATCH
  call "$h" "$(tool_in "$P1/par.jsonl" Edit "$(jq -cn --arg f "$VERDICT" '{file_path:$f,old_string:"PASS",new_string:"FAIL"}')" a8)"; want DENY REDISPATCH
  call "$h" "$(tool_in "$P1/par.jsonl" Edit "$(jq -cn --arg f "$VERDICT" '{file_path:$f,old_string:"PASS",new_string:"FAIL"}')" a9)"; want DENY REDISPATCH

  call "$h" "$(bash_in "$P1/denied.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT DENIED
  call "$h" "$(bash_in "$P1/deniedarr.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT DENIED
  call "$h" "$(bash_in "$P1/pushed.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want DENY DENIED
  # D1: a push that RAN, failed, and printed the token mid-output is still a gated action.
  call "$h" "$(bash_in "$P1/ran.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want DENY ENVELOPE

  call "$h" "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD' '' t1)"; want SILENT SELF
  call "$h" "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD' '' tY)"; want DENY SELF
  # The live wedge: the incoming call is the transcript's LAST line, advisor before it, and the
  # input carries no tool_use_id -> ALLOW. Twin: the same push already ANSWERED (a tool_result
  # after it), so it is a recorded action, not the incoming one -> DENY.
  call "$h" "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD' '' -)"; want SILENT SELFLAST
  call "$h" "$(bash_in "$P1/apok.jsonl" "$SPRINT" 'git push -u origin HEAD' '' -)"; want DENY SELFLAST

  # PER-KIND (operator ruling): one advisor call covers the next action of each kind.
  call "$h" "$(bash_in "$P1/ap1.jsonl" "$SPRINT" 'gh pr merge 7 --squash --delete-branch')"; want SILENT PERKIND
  call "$h" "$(bash_in "$P1/amp.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want SILENT PERKIND
  call "$h" "$(bash_in "$P1/apm.jsonl" "$SPRINT" 'git push -u origin HEAD')"; want DENY PERKIND
  call "$h" "$(bash_in "$P1/apm.jsonl" "$SPRINT" 'gh pr merge 8 --squash')"; want DENY PERKIND
  call "$h" "$(tool_in "$P1/ac.jsonl" Edit "$(jq -cn --arg f "$GL" '{file_path:$f,old_string:"| check | verdict |\n",new_string:"| check | verdict |\n\n## Gate Log: Sprint 3\n"}')")"; want SILENT PERKIND
  call "$h" "$(bash_in "$P1/ac.jsonl" "$SPRINT" 'bash scripts/ai-dlc/gate-checkpoint.sh --nonce m close')"; want DENY PERKIND

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
mut silence "BASHC BODY CLOSE DENIED DETACHED ENVELOPE FAILOPEN GATELOG GHREPO MATE MATEABSENT MATEPATH MATEREWRITE MCPNAME MERGE ORDER PATHGIT PERKIND PUSH QUOTEDC QUOTEDENV REARM REASON REDISPATCH SELF SELFLAST STACK TWRITE UNAV UPDATE UPDATECUT UPDATEREF WITHDRAWN WRAP" -e '2i\
exit 0'
# 2. warn-only: the rejected design, the same text as context with no decision.
#    UNAV survives it by design: the warn path is its own emission and this mutant leaves it intact.
mut warn-only "BASHC BODY CLOSE DENIED DETACHED ENVELOPE GATELOG GHREPO MATE MATEPATH MATEREWRITE MCPNAME MERGE ORDER PATHGIT PERKIND PUSH QUOTEDC QUOTEDENV REARM REASON REDISPATCH SELF SELFLAST STACK TWRITE UPDATE UPDATECUT UPDATEREF WITHDRAWN WRAP" \
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
#    hold an advisor call BEFORE the owed push, so the mutant allows where they warn and deny;
#    so do ENVELOPE, REDISPATCH (a9) and SELFLAST, whose deny cells all sit after an older advisor.
mut any-advisor-clears "DENIED ENVELOPE ORDER PERKIND REARM REDISPATCH SELF SELFLAST UNAV" -e 's/\[ "\${LAST_ADV:-0}" -gt "\${LAST_ACT:-0}" \]/[ "${LAST_ADV:-0}" -gt 0 ]/'
# 9. a branch delete is gated.
mut delete-gated "DELETE" -e 's/gitpush and (isdelete | not)/gitpush/'
# 10. the MCP merge tool escapes.
mut no-mcp-merge "MCPNAME MERGE" -e 's/startswith("mcp__") and endswith("__merge_pull_request")/startswith("mcp__NEVER")/'
# 11. `record` gated alongside `close`.
mut record-gated "CLOSE" -e 's/\\\\sclose(\\\\s|\$)/\\\\s(close|record)(\\\\s|$)/'
# 12. the push match loses its start anchor, so a mention is a push -- including the mentions
#     that are the allow twins of BASHC and BODY.
mut push-unanchored "BASHC BODY MENTION" -e 's/^def gitre: "^/def gitre: "/'
# 13. the update skill's branch is gated.
mut update-gated "UPDATE" -e 's|ai-dlc-update/\*) exit 0 ;;|ai-dlc-update-NEVER/*) exit 0 ;;|'
# 14. a detached HEAD or a git failure is read as the update branch.
mut detached-excluded "DETACHED" -e 's|\|\| _br=""$|\|\| _br="ai-dlc-update/unknown"|'
# 15. a teammate is judged on the handed (parent) transcript. Every teammate world whose parent
#     holds an advisor call dies, which is the point: the parent's call clears the teammate.
mut mate-on-parent "MATE MATEABSENT MATEPATH MATEREWRITE REDISPATCH" -e 's|^\[ -z "\$AID" \] \|\| JUDGED=.*$|:|'
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

# 26. D1: any error result CONTAINING the token removes the call, so a push that ran is erased.
mut envelope-unanchored "ENVELOPE" -e 's/| test("^PreToolUse:\[A-Za-z_\]+ hook error: ai-dlc-advisor-gate: DENIED")/| contains("ai-dlc-advisor-gate: DENIED")/'
# 27. D4: a re-dispatch does not end the re-write exemption.
mut no-redispatch "REDISPATCH" -e 's/then \.g |= map_values(\.\[1\] = "") else \. end)/then . else . end)/'
# 28. D4 done wrong: a re-dispatch forgets the gated action itself, so an older advisor clears it.
mut redispatch-drops-action "REDISPATCH" -e 's/then \.g |= map_values(\.\[1\] = "") else \. end)/then .g = {} else . end)/'
# 29. the incoming call on the transcript's last line is counted against itself (the live wedge).
mut selflast-counted "SELFLAST" -e 's/(if \$tuid == "" then \.g |= with_entries(select(\.value\[0\] != \$last)) else \. end)/./'
# 30. D3: a push naming the update branch as its refspec is not excluded.
mut refspec-not-excluded "UPDATEREF" -e 's/((\$r | length) > 0 and (\$r | all(upd)))/false/'
# 31. D3: a branch cut in the same command is not read.
mut cut-not-excluded "UPDATECUT" -e 's/(\$s | map(cutupd(\$v)) | any) as \$cut/false as $cut/'
# 32. D3: a `$B` refspec is not resolved through its assignment.
mut no-var-resolution "UPDATECUT" -e 's/(if (\$c | test("ai-dlc-update\/")) then (\$c | vars) else {} end) as \$v/{} as $v/'
# 33. D5: no wrapper word is stripped. PUSH dies too: its `timeout 600 git push` cell is a wrapper.
mut no-wrappers "PUSH STACK WRAP" -e 's/(nohup|exec|command|time|sudo|setsid|caffeinate|then/(then/' -e 's/|g?timeout(\\\\s+-\\\\S+)\*\\\\s+\[0-9.\]+\[smhd\]?|env(\\\\s+(-u|--unset)\\\\s+\\\\S+|\\\\s+-\\\\S+)\*)/)/'
# 34. D5: wrappers strip once, not in a loop.
mut no-strip-loop "STACK" -e 's/then (\$n | strip) elif/then $n elif/'
# 35. D5: the string argument of `bash -c` is not read.
mut no-bashc "BASHC STACK" -e 's/elif test(bashc) then (sub(bashc; "") | strip)/elif false then ./'
# 36. D5: `git` must be bare, so `/usr/bin/git push` escapes.
mut no-path-git "PATHGIT" -e 's|^def gitre: "^(\\\\S\*/)?git|def gitre: "^git|'
# 37. D5: `if`/`for`/`{ }` bodies are not entered.
mut no-bodies "BODY" -e 's/|then|do|else|if|while|until|!|\\\\{)(/)(/'
# 38. D5: `git -c` takes an unquoted value only.
mut no-quoted-c "QUOTEDC" -e 's/--namespace)\\\\s+(\\"\[^\\"\]\*\\"|\\\\x27\[^\\\\x27\]\*\\\\x27|\\\\S+)/--namespace)\\\\s+(\\\\S+)/'
# 39. D5: an environment assignment takes an unquoted value only.
mut no-quoted-env "QUOTEDENV" -e 's/^def envre: .*$/def envre: "^[A-Za-z_][A-Za-z0-9_]*=\\\\S*\\\\s+";/'
# 40. D5: `gh -R <repo> pr merge` escapes.
mut no-gh-repo "GHREPO" -e 's/gh(\\\\s+(-R|--repo)(\\\\s+|=)\\\\S+)\*\\\\s+pr/gh\\\\s+pr/'
# 43. the kinds collapse back to one: any gated action owes the next.
mut kinds-collapsed "PERKIND" -e 's/(\[\.g\[\] | select(\.\[2\] == \$kind) | \.\[0\]\] | max \/\/ 0) as \$act/([.g[] | .[0]] | max \/\/ 0) as $act/'
# 42. the closing quote is shed from every segment, so a quoted pattern reads as a push.
mut quote-shed-always "QUOTEDPAT" -e 's/^def csegs: segs as \$s | if test(.*$/def csegs: segs as $s | if true/'
# 41. the template's regex is not mirrored: only the github server's tool is a merge.
mut mcp-exact-name "MCPNAME" -e 's/startswith("mcp__") and endswith("__merge_pull_request")/. == "mcp__github__merge_pull_request"/'

[ "$n_mut" -gt 0 ] && [ "$n_kill" -eq "$n_mut" ] \
  && ok "$n_kill of $n_mut mutants killed" \
  || bad "$n_kill of $n_mut mutants killed"

echo
if [ "$fails" -eq 0 ]; then echo "advisor-gate-deny: PASS"; exit 0; fi
echo "advisor-gate-deny: $fails assertion(s) FAILED" >&2
exit 1
