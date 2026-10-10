#!/usr/bin/env bash
# advisor-gate-deny/lib.sh — the worlds, the cells and the scorer, sourced by the shipped
# fixture beside it and by its distribution-only mutation battery (advisor-gate-deny-mutants*).
# One copy, so a mutant is scored over the very cells the shipped arms run.
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
#   REASON       that deny names its remedy: "call the advisor in a message of its own, read its
#                answer, then retry the same command" (the one shape that never races; REREAD)
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
#                push"`, `/usr/bin/git push-status`, `gh -R r pr list`, `mcp__..__merge_pull_request_status`).
#                STACK holds a stack FIVE wrappers deep, so a strip loop bounded at four dies.
#   QUOTEDPAT    `pgrep -fl 'x|git push'` -> SILENT (the bash -c quote shedding must not reach it)
#   PERKIND      advisor, push, then merge -> SILENT; advisor, merge, then push -> SILENT; advisor,
#                push, merge, then the next push -> DENY and the next merge -> DENY; advisor, close,
#                then a Check 12 append -> SILENT; twin: the next close -> DENY. Every lead-kind pair
#                has a SILENT cell: after a push, a close and a Check 12 append; after a merge, the
#                same two. A build that collapses any one pair dies on that pair's cell alone.
#   REDISPATCH   a teammate's verdict re-write after a user TEXT line (string, text block, an
#                `isMeta` coordinator message, a string that merely MENTIONS a notification, a
#                human turn and a peer session's message -- both carrying an `origin` of their own
#                kind) -> DENY, also when an advisor call preceded the FIRST write; twins: after
#                only a background-task line (`origin.kind` "task-notification", both measured text
#                forms) -> SILENT, and MATEREWRITE -> SILENT
#   ENVELOPE     a push that ran, failed with NO ref-update line, and printed this hook's token in
#                its output -> SILENT, including the FULL envelope on an output's second line. Both
#                cells FLIPPED from DENY at batch 208: operator ruling BL-486 removes every gated
#                call that did not ship, which subsumes the old anchored-envelope rule (FAILED)
#   FAILED       BL-486 seeds, each an advisor call, a gated call that failed, then the retry:
#                a 404 merge -> SILENT (twin: the merge succeeded -> DENY); an errored `gh pr merge
#                --delete-branch` whose text carries `✓ Squashed and merged` (gh merged, then the
#                local branch delete failed) -> DENY (twin: errored with a 404 -> SILENT); a user-rejected push, a
#                safety-check deny, ANOTHER hook's PreToolUse deny envelope, a red-suite push with no
#                ref-update line -> SILENT; twins, each a push that SHIPPED -> DENY: exit 141 whose
#                text carries `* [new branch]`, an is_error push carrying `<old>..<new>`, one
#                carrying `(forced update)`, a ran-OK push carrying `<old>..<new>`, and a ran-OK
#                `Everything up-to-date` (the cell the is_error test alone holds)
#   REREAD       THE RACE: the advisor line and the incoming push are appended to the transcript
#                APPEND_DELAY (3s, past the old fixed 2 x 1s) after the hook starts -> SILENT, with
#                ADVISOR_GATE_REREADS unset (the 10s poll ceiling); twin: nothing appended -> DENY,
#                at 1 (2s ceiling). Every other cell runs with it 0, so a deny cell pays no ceiling
#   QUOTEDALT    a quoted alternation holding `git push -u origin HEAD --no-verify` (the graph row
#                that was denied) and a heredoc body carrying one -> SILENT; twin: `echo 'a;b' &&
#                git push origin HEAD` -> DENY. QUOTEDPAT's qp-dashc holds the `-c`-flag carve-out
#   WINDOW       an advisor attempt 3 assistant turns back with two shipped pushes since, then a push
#                -> SILENT (WINDOW-IN); twin: the advisor 11 turns back -> DENY (WINDOW-OUT). Both run
#                with ADVISOR_GATE_WINDOW unset (the default 10); every other cell runs with it 0, an
#                empty window, so they hold the per-kind test the window loosens
#   BMADONLY     L3: outgoing commits touching only `_bmad-output/` (bare, after a `cd` into the
#                cwd, a named current branch piped to `tail`, and a second push judged through
#                `@{u}` where `origin/HEAD` would include code) -> SILENT; twins -> DENY: a code path
#                in the set, an empty set, a commit in the same command, another refspec, a `cd`
#                into another checkout
#   SELFLAST     no tool_use_id, the incoming push is the last line after an advisor -> SILENT;
#                twin: the same push already answered by a tool_result -> DENY
#   DETACHED     cwd detached HEAD, cwd not a repository: push -> DENY
#   MATE         teammate, own file grant only, parent HAS an advisor call: verdict write -> DENY;
#                twin: own file with its own advisor call -> SILENT
#   MATEABSENT   teammate whose own file is absent, parent granted, no advisor -> SILENT
#   MATEPUSH     teammate push, own file granted, no advisor -> SILENT (option A)
#   MATEPATH     teammate adversarial pass, repair record, `.part-<i>of<N>.jsonl`, `SR1-code-review.md`,
#                `SR2-qa-validation.md` and a file in each review's shard directory -> DENY; twins:
#                the artifact, `SR1-summary.md`, a non-review shard directory, `.part-1of3.json` -> SILENT
#   MATEREWRITE  teammate Edit of a verdict it already wrote un-denied -> SILENT; twin: it wrote a
#                DIFFERENT verdict -> DENY
#   DENIED       advisor, push, that push DENIED by this hook -> the retry is SILENT;
#                twins: the same push succeeded -> DENY; a NON-error result carrying the envelope -> DENY
#   SELF         advisor, push id tX on disk, incoming tool_use_id tX -> SILENT; twin tY -> DENY
#   TWRITE       NO grant anywhere: Write onto a transcript, `>>`, `tee -a`, `sed -i`, `mv` onto one,
#                via `~` too -> DENY
#   TWRITEREAD   `cat <t> > out`, `cp <t> out`, a Write of a memory `.md` beside it -> SILENT
#   GATELOG      Edit adding a `## Gate Log:` heading, a Write adding one, a Bash `>>` and a `tee -a`
#                carrying one, a MultiEdit adding one -> DENY; twins: header-only Write (the rotation),
#                a Write keeping one heading, `tail` of the log, a `tee -a` and a MultiEdit adding no
#                heading -> SILENT
#   FAILOPEN     unparseable input, a missing transcript -> SILENT, and stderr says why
#   EXIT         every call exits 0
#
# COST. Every cell's hook input is built ONCE per run into `$W/cells/<n>.json`, listed in one
# manifest, and every score drives the same files; each decision is parsed with ONE jq. A cell
# rebuilt per score is a jq fork per cell per mutant, and parsing with several is more.
#
# Sourced, never run: it resolves seed.sh beside ITSELF, so a battery in a sibling directory
# builds the same worlds. It exits 2 on any broken world, cell or seeded branch.
set -uo pipefail

# The pre-push gate exports AI_DLC_* tunables; none is read here, but scrub them all the same.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

LIBDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(bash "$LIBDIR/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
[ -n "$WORK" ] && [ -f "$WORK/env.sh" ] || { echo "FIXTURE ERROR: seed printed no work dir" >&2; exit 2; }
# shellcheck source=/dev/null
. "$WORK/env.sh"

command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq not found; the hook is silent without it, so no arm here could fire" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

OUTF="$W/out"; ERRF="$W/err"; VF="$W/verdict"

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
# The envelope an OLDER transcript carries (the deny text before batch 208): a seed, not an expectation.
ENV9='PreToolUse:Bash hook error: ai-dlc-advisor-gate: DENIED -- call the advisor tool, then retry the same command.'
PUSHL="$(tu t1 Bash '{"command":"git push -u origin HEAD"}')"
PUSH9="$(tu t9 Bash '{"command":"git push -u origin HEAD"}')"
DENY9="$(tr_ t9 true "$ENV9")"
OK9="$(tr_ t9 false 'Everything up-to-date')"
OK1="$(tr_ t1 false 'Everything up-to-date')"
# The real denial envelope as a text-block array, and a push that RAN, failed, and printed the token.
DENY9A="$(jq -cn --arg t "$ENV9" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"t9",is_error:true,content:[{type:"text",text:$t}]}]}}')"
RAN9="$(tr_ t9 true 'Exit code 1
remote: pre-receive said: ai-dlc-advisor-gate: DENIED -- call the advisor tool
error: failed to push some refs')"
# The FULL envelope, but on the second line of a push that ran: only a match anchored at the
# start of the content can tell it from a real denial.
RAN9F="$(tr_ t9 true "Exit code 1
$ENV9
error: failed to push some refs")"
# The envelope as the content of a NON-error result: the call ran, so it stays a gated action.
OKENV9="$(tr_ t9 false "$ENV9")"
# A re-dispatch: a user line carrying TEXT (measured: a string, isMeta on coordinator messages).
UTXT='{"type":"user","message":{"role":"user","content":"The coordinator sent a message while you were working: re-run pass 2"},"isMeta":true}'
UTXTA='{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Adversarial pass 3 of the series."}]}}'
# A background-task event is NOT a re-dispatch. Both shapes as measured in graph's transcripts:
# `user` string lines carrying `origin.kind` "task-notification".
SYSNOTIF='{"type":"user","message":{"role":"user","content":"[SYSTEM NOTIFICATION - NOT USER INPUT]\nThis is an automated background-task event, NOT a message from the user."},"isMeta":true,"origin":{"kind":"task-notification"}}'
TASKNOTIF='{"type":"user","message":{"role":"user","content":"<task-notification>\n<task-id>b1</task-id>\n<status>completed</status>\n</task-notification>"},"origin":{"kind":"task-notification"}}'
# Near-miss: a real re-dispatch that merely MENTIONS the notification prefix.
UTXTMID='{"type":"user","message":{"role":"user","content":"Re-run pass 2; ignore any [SYSTEM NOTIFICATION - NOT USER INPUT] line above."}}'
# A real instruction that DOES carry an origin, of a kind other than task-notification. Shapes as
# measured in graph's transcripts: a human turn (786 lines) and a peer session's message (45 user
# lines, isMeta true). A notif test keyed on "has an origin" reads both as background noise.
UHUMAN='{"type":"user","message":{"role":"user","content":"Flip it to FAIL, the AC7 evidence is stale."},"origin":{"kind":"human"}}'
UPEER='{"type":"user","message":{"role":"user","content":"Another Claude session sent a message:\n<agent-message from=\"a1\">\nRe-adjudicate: the AC7 probe is stale.\n</agent-message>"},"isMeta":true,"origin":{"kind":"peer","fromMode":null}}'

VERDICT="$SPRINT/_bmad-output/gate-adjudication/implementation-20261006T120000Z.verdict.json"
VERDICT2="$SPRINT/_bmad-output/gate-adjudication/story-20261006T110000Z.verdict.json"
PART="$SPRINT/_bmad-output/gate-adjudication/implementation-20261006T120000Z.part-1of3.jsonl"
PARTX="$SPRINT/_bmad-output/gate-adjudication/implementation-20261006T120000Z.part-1of3.json"
ADVP="$SPRINT/_bmad-output/planning-artifacts/s3/prd-adversarial-p2.md"
REPR="$SPRINT/_bmad-output/planning-artifacts/s3/prd-repair-p2.md"
ARTF="$SPRINT/_bmad-output/planning-artifacts/s3/prd.md"
# The review deliverables under their real names (code-reviewer.md:92, qa.md:325), and a file in
# each review's shard directory (implementation.md:296, :349).
REVCR="$SPRINT/docs/reviews/s3/SR1-code-review.md"
REVQA="$SPRINT/docs/reviews/s3/SR2-qa-validation.md"
REVSHQ="$SPRINT/docs/reviews/s3/shards/SR2-qa-validation-0123456789ab/1.md"
REVSHC="$SPRINT/docs/reviews/s3/shards/SR1-code-review-0123456789ab/cross.md"
REVX="$SPRINT/docs/reviews/s3/SR1-summary.md"
REVSHX="$SPRINT/docs/reviews/s3/shards/SR1-notes/1.md"
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
mk "$P1/ranfull.jsonl"  "$GRANT" "$ADV" "$PUSH9" "$RAN9F"
mk "$P1/okenv.jsonl"    "$GRANT" "$ADV" "$PUSH9" "$OKENV9"
mk "$P1/apok.jsonl"     "$GRANT" "$ADV" "$PUSHL" "$OK1"
# FAILED (BL-486): advisor, a gated call that failed, then the retry. The result texts are the
# shapes the fix hand measured (a 404 merge result on this repo's own transcript, exit 141 with the
# ref moved, the harness's user-rejection text) and the PreToolUse envelope another hook produces.
MERGE9="$(tu t9 mcp__github__merge_pull_request '{"owner":"o","repo":"r","pullNumber":1056}')"
mk "$P1/f404.jsonl"     "$GRANT" "$ADV" "$OKRES" "$MERGE9" "$(tr_ t9 true 'failed to merge pull request: PUT https://api.github.com/repos/euron8/ai-dlc/pulls/1056/merge: 404 Not Found []')"
mk "$P1/fmergeok.jsonl" "$GRANT" "$ADV" "$OKRES" "$MERGE9" "$(tr_ t9 false 'Pull request successfully merged')"
# gh merged, then the local branch delete failed (retro.md:1252 instructs --delete-branch): the
# result is is_error:true and the merge HAPPENED. Twin: an errored gh merge that did not (404).
GHMERGE9="$(tu t9 Bash '{"command":"gh pr merge 1056 --squash --delete-branch"}')"
mk "$P1/fmergedel.jsonl" "$GRANT" "$ADV" "$OKRES" "$GHMERGE9" "$(tr_ t9 true 'Exit code 1
✓ Squashed and merged pull request euron8/ai-dlc#1056 (b208 r1)
failed to delete local branch b208-r1: failed to run git: error: cannot delete branch '"'"'b208-r1'"'"' used by worktree')"
mk "$P1/fmerge404.jsonl" "$GRANT" "$ADV" "$OKRES" "$GHMERGE9" "$(tr_ t9 true 'Exit code 1
GraphQL: Could not resolve to a PullRequest with the number of 1056. (repository.pullRequest)
HTTP 404: Not Found')"
mk "$P1/f141.jsonl"     "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$(tr_ t9 true 'Exit code 141
pre-push: all gates green
To github.com:euron8/ai-dlc.git
 * [new branch]      HEAD -> b208-gate')"
mk "$P1/fdots.jsonl"    "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$(tr_ t9 true 'Exit code 1
To github.com:x/y.git
   2a6f5992..53c415ee  HEAD -> main
error: something after')"
mk "$P1/fforced.jsonl"  "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$(tr_ t9 true 'Exit code 141
To github.com:x/y.git
 + 2a6f5992...53c415ee HEAD -> main (forced update)')"
mk "$P1/frej.jsonl"     "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$(tr_ t9 true "The user doesn't want to proceed with this tool use. The tool use was rejected (eg. if it was a file edit, the new_string was NOT written to the file). STOP what you are doing and wait for the user to tell you how to proceed.")"
mk "$P1/fsafe.jsonl"    "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$(tr_ t9 true 'This command requires approval: safety check denied the push to a protected branch')"
mk "$P1/fhook.jsonl"    "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$(tr_ t9 true 'PreToolUse:Bash hook error: AI/DLC steering budget: this FOREGROUND Bash call declares timeout 600000 ms')"
mk "$P1/fred.jsonl"     "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$(tr_ t9 true 'Exit code 1
FAIL  fixture x
pre-push: 1 gate(s) failed
error: failed to push some refs')"
mk "$P1/fokref.jsonl"   "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$(tr_ t9 false 'To github.com:x/y.git
   2a6f5992..53c415ee  HEAD -> main')"
mk "$P1/fokutd.jsonl"   "$GRANT" "$ADV" "$OKRES" "$PUSH9" "$OK9"
# REREAD: a release already pushed, no advisor since. score() copies the template over the judged
# transcript before EVERY run, so a line one score appended never leaks into the next.
mk "$P1/rr.tmpl"        "$GRANT" "$PUSHL" "$(tr_ t1 false 'To x
   1111111..2222222  HEAD -> main')"
mk "$P1/rr.add"         "$ADV" "$(tu tNEW Bash '{"command":"git push -u origin HEAD"}')"
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
mk "$P1/par/subagents/agent-a10.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)" "$SYSNOTIF"
mk "$P1/par/subagents/agent-a11.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)" "$TASKNOTIF"
mk "$P1/par/subagents/agent-a12.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)" "$UTXTMID"
mk "$P1/par/subagents/agent-a13.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)" "$UHUMAN"
mk "$P1/par/subagents/agent-a14.jsonl" "$GRANT" "$WV" "$(tr_ w1 false ok)" "$UPEER"
mk "$P1/q.jsonl"        "$GRANT"
mkdir -p "$P1/q/subagents"
# WINDOW worlds. Real assistant lines carry `message.id`, and one message spans several lines; these
# helpers stamp it, so a turn is a message and not a line. Every push after the advisor SHIPPED, so
# the per-kind test owes the next push and only the window can acquit it.
# tum <msg-id> <id> <tool> <input-json>;  advm/okm <msg-id>;  shipm <id>
tum() { jq -cn --arg m "$1" --arg id "$2" --arg n "$3" --argjson i "$4" '{type:"assistant",message:{id:$m,content:[{type:"tool_use",id:$id,name:$n,input:$i}]}}'; }
advm() { jq -cn --arg m "$1" '{type:"assistant",message:{id:$m,content:[{type:"server_tool_use",id:"s1",name:"advisor",input:{}}]}}'; }
okm() { jq -cn --arg m "$1" '{type:"assistant",message:{id:$m,content:[{type:"advisor_tool_result",tool_use_id:"s1",content:{type:"advisor_redacted_result"}}]}}'; }
shipm() { tr_ "$1" false 'To x
   1111111..2222222  HEAD -> main'; }
PUSHC='{"command":"git push -u origin HEAD"}'
# WINDOW-IN: advisor in m1, a shipped push in m2 and in m3; the incoming push is m4 (turn 1), so the
# advisor is turn 4, three turns back.
mk "$P1/win-in.jsonl"   "$GRANT" "$USER" "$(advm m1)" "$(okm m1)" \
  "$(tum m2 p2 Bash "$PUSHC")" "$(shipm p2)" "$(tum m3 p3 Bash "$PUSHC")" "$(shipm p3)"
# WINDOW-OUT: advisor in m1, a shipped push in m2, then nine more turns m3..m11; the incoming push is
# m12 (turn 1), so the advisor is turn 12, eleven turns back.
_wo=""; _i=3
while [ "$_i" -le 11 ]; do
  _wo="$_wo$(tum "m$_i" "x$_i" Bash '{"command":"ls"}')
$(tr_ "x$_i" false ok)
"
  _i=$((_i+1))
done
mk "$P1/win-out.jsonl"  "$GRANT" "$USER" "$(advm m1)" "$(okm m1)" "$(tum m2 p2 Bash "$PUSHC")" "$(shipm p2)"
printf '%s' "$_wo" >> "$P1/win-out.jsonl"
_wt="$(jq -r '.message.id? // empty' "$P1/win-out.jsonl" | sort -u | grep -c .)" || _wt=0
[ "$_wt" -eq 11 ] || { echo "FIXTURE BROKEN: WINDOW-OUT holds $_wt assistant turns (want 11)" >&2; exit 2; }
for _f in g none off regrant pa ap err unav rearm denied pushed deniedarr ran ranfull okenv apok apm amp ap1 ac par q \
          win-in win-out \
          f404 fmergeok fmergedel fmerge404 f141 fdots fforced frej fsafe fhook fred fokref fokutd \
          par/subagents/agent-a7 par/subagents/agent-a9 par/subagents/agent-a10 par/subagents/agent-a11 par/subagents/agent-a12 \
          par/subagents/agent-a13 par/subagents/agent-a14; do
  [ -s "$P1/$_f.jsonl" ] || { echo "FIXTURE BROKEN: world $_f was not written" >&2; exit 2; }
done
_nt="$(grep -c . "$P1/rr.tmpl")" || _nt=0
_na="$(grep -c . "$P1/rr.add")" || _na=0
[ "$_nt" -eq 3 ] && [ "$_na" -eq 2 ] || { echo "FIXTURE BROKEN: the REREAD template holds $_nt lines (want 3) and its append $_na (want 2)" >&2; exit 2; }

# bash_in <transcript> <cwd> <command> [agent_id] [tool_use_id]
#   tool_use_id `-` omits the key, the shape of a harness that does not send one
bash_in() { jq -cn --arg t "$1" --arg d "$2" --arg c "$3" --arg a "${4:-}" --arg u "${5:-tNEW}" \
  '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},transcript_path:$t,cwd:$d} + (if $u == "-" then {} else {tool_use_id:$u} end) + (if $a == "" then {} else {agent_id:$a} end)'; }
# tool_in <transcript> <tool> <input-json> [agent_id]
tool_in() { jq -cn --arg t "$1" --arg n "$2" --argjson i "$3" --arg a "${4:-}" --arg d "$SPRINT" \
  '{hook_event_name:"PreToolUse",tool_name:$n,tool_input:$i,transcript_path:$t,cwd:$d,tool_use_id:"tNEW"} + (if $a == "" then {} else {agent_id:$a} end)'; }
write_in() { tool_in "$1" Write "$(jq -cn --arg f "$2" --arg c "${4:-x}" '{file_path:$f,content:$c}')" "${3:-}"; }
edit_in() { tool_in "$1" Edit "$(jq -cn --arg f "$2" --arg o "$3" --arg n "$4" '{file_path:$f,old_string:$o,new_string:$n}')" "${5:-}"; }

# --- the cells, built ONCE ---------------------------------------------------------------------
# cell <arm> <want> <check> <tag> <json>
#   check: `-`, `R:<text>` (the deny reason must contain it) or `E:<text>` (stderr must contain it)
#   tag:   `-` numbers the cell; a name makes it addressable from a mutant's expected cell set
CELLS="$W/cells"; MAN="$W/manifest"
mkdir -p "$CELLS" || { echo "FIXTURE ERROR: cannot create $CELLS" >&2; exit 2; }
: > "$MAN"; nc=0
cell() {
  nc=$((nc+1))
  local tag="$4"; [ "$tag" = - ] && tag="$nc"
  printf '%s' "$5" > "$CELLS/$nc.json"
  printf '%s\t%s:%s\t%s\t%s\t%s\n' "$nc" "$1" "$tag" "$3" "$1" "$2" >> "$MAN"
}
# c <arm> <want> <json>  /  ct <arm> <want> <tag> <json>
c()  { cell "$1" "$2" - - "$3"; }
ct() { cell "$1" "$2" - "$3" "$4"; }
B()  { c "$1" "$2" "$(bash_in "$P1/g.jsonl" "$SPRINT" "$3")"; }

for x in 'git push -u origin HEAD' "git -C $SPRINT push origin HEAD:refs/heads/release/1" "cd $SPRINT && git push" 'timeout 600 git push origin sprint/3'; do
  B PUSH DENY "$x"
done
cell REASON DENY 'R:call the advisor in a message of its own, read its answer, then retry the same command' - "$(bash_in "$P1/g.jsonl" "$SPRINT" 'git push -u origin HEAD')"

c NOGRANT SILENT "$(bash_in "$P1/none.jsonl" "$SPRINT" 'git push -u origin HEAD')"
c NOGRANT SILENT "$(write_in "$P1/par.jsonl" "$VERDICT" a4)"

c WITHDRAWN SILENT "$(bash_in "$P1/off.jsonl" "$SPRINT" 'git push -u origin HEAD')"
c WITHDRAWN DENY "$(bash_in "$P1/regrant.jsonl" "$SPRINT" 'git push -u origin HEAD')"

c ORDER SILENT "$(bash_in "$P1/pa.jsonl" "$SPRINT" 'git push -u origin HEAD')"
c ORDER DENY "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD')"

c ERRCLEAR SILENT "$(bash_in "$P1/err.jsonl" "$SPRINT" 'git push -u origin HEAD')"

c UNAV WARN "$(bash_in "$P1/unav.jsonl" "$SPRINT" 'git push -u origin HEAD')"
c REARM DENY "$(bash_in "$P1/rearm.jsonl" "$SPRINT" 'git push -u origin HEAD')"

B MERGE DENY 'gh pr merge 7 --squash --delete-branch'
c MERGE DENY "$(tool_in "$P1/g.jsonl" mcp__github__merge_pull_request '{"owner":"o","repo":"r","pullNumber":7}')"
B MERGE SILENT 'gh pr list --state merged --limit 3'

B CLOSE DENY 'bash scripts/ai-dlc/gate-checkpoint.sh --nonce implementation-20261006T120000Z close'
B CLOSE SILENT 'scripts/ai-dlc/gate-checkpoint.sh --nonce implementation-20261006T120000Z record 12 PASS'

for x in 'git push origin --delete release/0.1.0' 'git push -d origin release/0.1.0' 'git push origin :release/0.1.0'; do
  B DELETE SILENT "$x"
done

B MENTION SILENT 'echo git push origin x'
B MENTION SILENT 'grep -c "gh pr merge" log'

c UPDATE SILENT "$(bash_in "$P1/g.jsonl" "$UPDATE" 'git push -u origin HEAD')"
c UPDATE SILENT "$(bash_in "$P1/g.jsonl" "$UPDATE" 'gh pr merge 9 --squash --delete-branch')"
B UPDATE DENY 'git push -u origin HEAD'
B UPDATE DENY 'gh pr merge 9 --squash --delete-branch'

# D3, from the SPRINT cwd: the update branch named as every refspec destination.
for x in 'git push -u origin ai-dlc-update/x' 'git push -u origin HEAD:refs/heads/ai-dlc-update/x' 'git push -u origin ai-dlc-update/x > /tmp/push.txt 2>&1; echo rc=$?'; do
  B UPDATEREF SILENT "$x"
done
for x in 'git push -u origin ai-dlc-updated/x' 'git push -u origin HEAD:ai-dlc-update-x' 'git push origin sprint/3 ai-dlc-update/x'; do
  B UPDATEREF DENY "$x"
done
# D3: the update branch cut in the same command (the real `B=...; checkout -q -b $B` shape too).
for x in 'git checkout -b ai-dlc-update/x && git commit -qm x && git push -u origin HEAD' 'git switch -c ai-dlc-update/x && git push' 'B=ai-dlc-update/ledger-20260929; git checkout -q -b $B && git add f && git commit -q -m x; git push -u origin $B > /tmp/p 2>&1'; do
  B UPDATECUT SILENT "$x"
done
for x in 'git checkout -b feature/x && git push -u origin HEAD' 'git checkout -b ai-dlc-update/x && git push origin sprint/3' 'B=sprint/9; git checkout -b $B && git push -u origin $B'; do
  B UPDATECUT DENY "$x"
done

# D5: every spelling measured in the consumer's commands, each class with its allow twin.
# The wrapper word is spelled through a variable: these are command STRINGS the hook parses,
# never run, and arm S4 of validate-shell-portability.sh reads the bare word as a call.
SETSID_WORD=setsid
for x in 'nohup git push -u origin sprint/3 > /tmp/p.txt 2>&1 &' 'exec git push' 'command git push' 'time git push' 'sudo git push' 'caffeinate -i git push' 'gtimeout 600 git push' 'env -u GIT_DIR git push'; do
  B WRAP DENY "$x"
done
B WRAP SILENT 'time ls -la'
for x in "nohup bash -c 'exec ${SETSID_WORD} git push -u origin sprint/3 > /tmp/p 2>&1' &" 'time nohup git push' 'sudo -E caffeinate -i git push'; do
  B STACK DENY "$x"
done
B STACK SILENT "nohup bash -c 'exec ${SETSID_WORD} git fetch -q origin > /tmp/p 2>&1' &"
# Five wrappers deep: a strip loop bounded at four leaves `gtimeout 60 git push` unread.
ct STACK DENY f-five "$(bash_in "$P1/g.jsonl" "$SPRINT" 'time nohup sudo -E caffeinate -i gtimeout 60 git push')"
ct STACK SILENT f-five-fetch "$(bash_in "$P1/g.jsonl" "$SPRINT" 'time nohup sudo -E caffeinate -i gtimeout 60 git fetch')"
# The real update-skill spelling of the same stack is excluded by its refspec (UPDATEREF owns why).
B UPDATEREF SILENT "nohup bash -c 'exec ${SETSID_WORD} git push -u origin ai-dlc-update/0.622.0-reconcile-20260922T074403Z > /tmp/p 2>&1' &"
for x in 'bash -c "git push"' "sh -c 'git push -u origin HEAD'"; do
  B BASHC DENY "$x"
done
B BASHC SILENT 'bash -c "echo git push"'
# A quoted alternation carrying `git push` is a pattern, not a push (4 real graph rows).
B QUOTEDPAT SILENT "pgrep -fl 'wait-for-deliverable|git push' | grep -v pgrep"
# The quote after a `-c` flag is NOT masked (it may be a bash -c body), so it splits; its closing
# quote must still not be shed when the command holds no bash -c body.
ct QUOTEDPAT SILENT qp-dashc "$(bash_in "$P1/g.jsonl" "$SPRINT" "grep -c 'x|git push'")"
# QUOTEDALT: a quoted string holding a separator is one word (the graph row that was denied), and
# a heredoc body is data. Twin: a quoted separator BEFORE a real chained push still splits there.
ct QUOTEDALT SILENT qa-alt "$(bash_in "$P1/g.jsonl" "$SPRINT" "grep -n -E 'X|git push -u origin HEAD --no-verify|Y' f")"
ct QUOTEDALT SILENT qa-heredoc "$(bash_in "$P1/g.jsonl" "$SPRINT" "cat <<'EOF' > notes.txt
then run:
git push -u origin HEAD
EOF")"
ct QUOTEDALT DENY qa-twin "$(bash_in "$P1/g.jsonl" "$SPRINT" "echo 'a;b' && git push origin HEAD")"
B PATHGIT DENY '/usr/bin/git push'
B PATHGIT SILENT '/usr/bin/git push-status'
for x in 'if true; then git push; fi' 'for i in 1; do git push; done' '{ git push; }'; do
  B BODY DENY "$x"
done
B BODY SILENT 'if true; then echo git push; fi'
B QUOTEDC DENY 'git -c "user.name=a b" push origin HEAD'
B QUOTEDC SILENT 'git -c "user.name=a b" log --grep push'
B QUOTEDENV DENY 'GIT_SSH_COMMAND="ssh -o X=1" git push'
B QUOTEDENV SILENT 'MSG="git push" echo hi'
for x in 'gh -R euron8/graph pr merge 7 --squash' 'gh --repo euron8/graph pr merge 7' 'gh --repo=euron8/graph pr merge 7'; do
  B GHREPO DENY "$x"
done
B GHREPO SILENT 'gh -R euron8/graph pr list'
c MCPNAME DENY "$(tool_in "$P1/g.jsonl" mcp__gh2__merge_pull_request '{"owner":"o","repo":"r","pullNumber":7}')"
c MCPNAME SILENT "$(tool_in "$P1/g.jsonl" mcp__github__merge_pull_request_status '{"owner":"o","repo":"r","pullNumber":7}')"

c DETACHED DENY "$(bash_in "$P1/g.jsonl" "$DETACHED" 'git push -u origin HEAD')"
c DETACHED DENY "$(bash_in "$P1/g.jsonl" "$NOREPO" 'git push -u origin HEAD')"

c MATE DENY "$(write_in "$P1/par.jsonl" "$VERDICT" a1)"
c MATE SILENT "$(write_in "$P1/par.jsonl" "$VERDICT" a2)"

cell MATEABSENT SILENT 'E:agent-a3.jsonl' - "$(write_in "$P1/q.jsonl" "$VERDICT" a3)"

c MATEPUSH SILENT "$(bash_in "$P1/par.jsonl" "$SPRINT" 'git push -u origin HEAD' a1)"

c MATEPATH DENY "$(write_in "$P1/par.jsonl" "$ADVP" a1)"
c MATEPATH DENY "$(write_in "$P1/par.jsonl" "$REPR" a1)"
c MATEPATH SILENT "$(write_in "$P1/par.jsonl" "$ARTF" a1)"
ct MATEPATH DENY l-part "$(write_in "$P1/par.jsonl" "$PART" a1)"
ct MATEPATH SILENT l-part-json "$(write_in "$P1/par.jsonl" "$PARTX" a1)"
ct MATEPATH DENY k-cr "$(write_in "$P1/par.jsonl" "$REVCR" a1)"
ct MATEPATH DENY k-qa "$(write_in "$P1/par.jsonl" "$REVQA" a1)"
ct MATEPATH DENY k-sh-qa "$(write_in "$P1/par.jsonl" "$REVSHQ" a1)"
ct MATEPATH DENY k-sh-cr "$(write_in "$P1/par.jsonl" "$REVSHC" a1)"
ct MATEPATH SILENT k-summary "$(write_in "$P1/par.jsonl" "$REVX" a1)"
ct MATEPATH SILENT k-sh-notes "$(write_in "$P1/par.jsonl" "$REVSHX" a1)"

ct MATEREWRITE SILENT n-mate-same "$(edit_in "$P1/par.jsonl" "$VERDICT" a b a5)"
c MATEREWRITE DENY "$(edit_in "$P1/par.jsonl" "$VERDICT" a b a6)"

# D4: a re-dispatch (a user TEXT line, string or text block) ends the re-write exemption;
# twin: a5 has only a tool_result after its write and stays exempt (MATEREWRITE above);
# a9 called the advisor BEFORE its first write, so the cleared path must not hide that the
# write is still its last gated action -- an advisor older than it does not clear.
ct REDISPATCH DENY rd-meta "$(edit_in "$P1/par.jsonl" "$VERDICT" PASS FAIL a7)"
c REDISPATCH DENY "$(edit_in "$P1/par.jsonl" "$VERDICT" PASS FAIL a8)"
ct REDISPATCH DENY rd-meta-adv "$(edit_in "$P1/par.jsonl" "$VERDICT" PASS FAIL a9)"
# A background-task event between the writes is not a re-dispatch (measured: 2 real repair-record
# re-writes); a re-dispatch that merely MENTIONS the prefix still is.
ct REDISPATCH SILENT rd-sys "$(edit_in "$P1/par.jsonl" "$VERDICT" PASS FAIL a10)"
ct REDISPATCH SILENT rd-task "$(edit_in "$P1/par.jsonl" "$VERDICT" PASS FAIL a11)"
ct REDISPATCH DENY rd-mid "$(edit_in "$P1/par.jsonl" "$VERDICT" PASS FAIL a12)"
# A human's and a peer's instruction carry an origin too, of another kind: both are re-dispatches.
ct REDISPATCH DENY rd-human "$(edit_in "$P1/par.jsonl" "$VERDICT" PASS FAIL a13)"
ct REDISPATCH DENY rd-peer "$(edit_in "$P1/par.jsonl" "$VERDICT" PASS FAIL a14)"

c DENIED SILENT "$(bash_in "$P1/denied.jsonl" "$SPRINT" 'git push -u origin HEAD')"
c DENIED SILENT "$(bash_in "$P1/deniedarr.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct DENIED DENY n-pushed "$(bash_in "$P1/pushed.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct DENIED DENY h-noerr "$(bash_in "$P1/okenv.jsonl" "$SPRINT" 'git push -u origin HEAD')"
# A push that RAN, failed with no ref-update line, and printed the token mid-output did not ship.
# FLIPPED from DENY at batch 208 (BL-486): the anchored-envelope rule these pinned is subsumed.
ct ENVELOPE SILENT a-ran "$(bash_in "$P1/ran.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct ENVELOPE SILENT a-midline "$(bash_in "$P1/ranfull.jsonl" "$SPRINT" 'git push -u origin HEAD')"

# FAILED (BL-486): a gated call that did not ship does not consume the advisor call before it.
# Each SILENT cell has a DENY cell one property apart: the call shipped.
ct FAILED SILENT f-404 "$(tool_in "$P1/f404.jsonl" mcp__github__merge_pull_request '{"owner":"o","repo":"r","pullNumber":1056}')"
ct FAILED DENY f-merge-ok "$(tool_in "$P1/fmergeok.jsonl" mcp__github__merge_pull_request '{"owner":"o","repo":"r","pullNumber":1056}')"
# is_error, but the text shows gh merged before the branch delete failed: it SHIPPED -> DENY.
# Twin one property apart: the errored gh merge whose text carries no merged line -> SILENT.
ct FAILED DENY f-merge-errdel "$(bash_in "$P1/fmergedel.jsonl" "$SPRINT" 'gh pr merge 1057 --squash --delete-branch')"
ct FAILED SILENT f-merge-err404 "$(bash_in "$P1/fmerge404.jsonl" "$SPRINT" 'gh pr merge 1057 --squash --delete-branch')"
ct FAILED SILENT f-rejected "$(bash_in "$P1/frej.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct FAILED SILENT f-safety "$(bash_in "$P1/fsafe.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct FAILED SILENT f-hookdeny "$(bash_in "$P1/fhook.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct FAILED SILENT f-red "$(bash_in "$P1/fred.jsonl" "$SPRINT" 'git push -u origin HEAD')"
# is_error, but the text shows the remote moved: it SHIPPED (twins of f-red, one per ref-line form).
ct FAILED DENY f-141-newbranch "$(bash_in "$P1/f141.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct FAILED DENY f-err-dots "$(bash_in "$P1/fdots.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct FAILED DENY f-err-forced "$(bash_in "$P1/fforced.jsonl" "$SPRINT" 'git push -u origin HEAD')"
# Ran OK (twins of f-rejected, f-safety, f-hookdeny): with a ref line, and without one.
ct FAILED DENY f-ok-ref "$(bash_in "$P1/fokref.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct FAILED DENY f-ok-uptodate "$(bash_in "$P1/fokutd.jsonl" "$SPRINT" 'git push -u origin HEAD')"

# REREAD (THE RACE). The judged transcript is rebuilt from rr.tmpl before each score; a
# `$CELLS/<n>.app` file tells score() to do that, to run the hook with ADVISOR_GATE_REREADS set to
# its fourth field (`-` = unset, the default 10s ceiling), and (for the appender cell) to append
# rr.add APPEND_DELAY seconds after the hook starts. 3s: past the old fixed 2 x 1s re-read (graph's
# advisor line landed >2s after PreToolUse), so a fixed-2s loop judges before the append and denies,
# and well inside the 10s ceiling, where the poll sees it within 0.25s and stops (rr.add carries the
# incoming call's own line). rr-none appends nothing and runs at 1 (2s ceiling) so its DENY does not
# pay 10s on every score.
APPEND_DELAY=3
ct REREAD SILENT rr-late "$(bash_in "$P1/rr-late.jsonl" "$SPRINT" 'git push -u origin HEAD')"
printf '%s\t%s\t%s\t%s\n' "$P1/rr-late.jsonl" "$P1/rr.add" "$APPEND_DELAY" - > "$CELLS/$nc.app"
ct REREAD DENY rr-none "$(bash_in "$P1/rr-none.jsonl" "$SPRINT" 'git push -u origin HEAD')"
printf '%s\t%s\t%s\t%s\n' "$P1/rr-none.jsonl" - - 1 > "$CELLS/$nc.app"

# THE WINDOW (operator ruling): an advisor attempt within the last 10 assistant turns clears the
# call, however many pushes shipped since. A `$CELLS/<n>.win` file runs the cell with
# ADVISOR_GATE_WINDOW unset (the default); every other cell runs with it 0.
ct WINDOW SILENT win-in "$(bash_in "$P1/win-in.jsonl" "$SPRINT" 'git push -u origin HEAD')"
: > "$CELLS/$nc.win"
ct WINDOW DENY win-out "$(bash_in "$P1/win-out.jsonl" "$SPRINT" 'git push -u origin HEAD')"
: > "$CELLS/$nc.win"

# L3: outgoing commits touching only `_bmad-output/` -> SILENT; one code path -> DENY; and every
# command shape the hook cannot read before it runs stays gated.
ct BMADONLY SILENT l3-bmad "$(bash_in "$P1/g.jsonl" "$BMAD" 'git push -u origin HEAD')"
ct BMADONLY SILENT l3-bmad-cd "$(bash_in "$P1/g.jsonl" "$BMAD" "cd $BMAD && git push origin HEAD")"
ct BMADONLY SILENT l3-bmad-branch "$(bash_in "$P1/g.jsonl" "$BMAD" 'git push origin sprint/4 2>&1 | tail -3')"
ct BMADONLY SILENT l3-upstream "$(bash_in "$P1/g.jsonl" "$UPSTREAM" 'git push')"
ct BMADONLY DENY l3-code "$(bash_in "$P1/g.jsonl" "$CODE" 'git push -u origin HEAD')"
ct BMADONLY DENY l3-empty "$(bash_in "$P1/g.jsonl" "$EMPTYOUT" 'git push -u origin HEAD')"
ct BMADONLY DENY l3-commit "$(bash_in "$P1/g.jsonl" "$BMAD" 'git commit -qam x && git push -u origin HEAD')"
ct BMADONLY DENY l3-otherref "$(bash_in "$P1/g.jsonl" "$BMAD" 'git push origin release/9')"
ct BMADONLY DENY l3-cd-elsewhere "$(bash_in "$P1/g.jsonl" "$BMAD" "cd $CODE && git push -u origin HEAD")"

c SELF SILENT "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD' '' t1)"
c SELF DENY "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD' '' tY)"
# The live wedge: the incoming call is the transcript's LAST line, advisor before it, and the
# input carries no tool_use_id -> ALLOW. Twin: the same push already ANSWERED (a tool_result
# after it), so it is a recorded action, not the incoming one -> DENY.
c SELFLAST SILENT "$(bash_in "$P1/ap.jsonl" "$SPRINT" 'git push -u origin HEAD' '' -)"
ct SELFLAST DENY n-selflast-answered "$(bash_in "$P1/apok.jsonl" "$SPRINT" 'git push -u origin HEAD' '' -)"

# PER-KIND (operator ruling): one advisor call covers the next action of each kind.
GLADD="$(edit_in "$P1/ac.jsonl" "$GL" '| check | verdict |
' '| check | verdict |

## Gate Log: Sprint 3
')"
c PERKIND SILENT "$(bash_in "$P1/ap1.jsonl" "$SPRINT" 'gh pr merge 7 --squash --delete-branch')"
c PERKIND SILENT "$(bash_in "$P1/amp.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct PERKIND DENY n-pk-push "$(bash_in "$P1/apm.jsonl" "$SPRINT" 'git push -u origin HEAD')"
ct PERKIND DENY n-pk-merge "$(bash_in "$P1/apm.jsonl" "$SPRINT" 'gh pr merge 8 --squash')"
c PERKIND SILENT "$GLADD"
ct PERKIND DENY n-pk-close "$(bash_in "$P1/ac.jsonl" "$SPRINT" 'bash scripts/ai-dlc/gate-checkpoint.sh --nonce m close')"
# The four lead-kind pairs no cell above separates: after a push, and after a merge, the next
# close and the next Check 12 append each owe nothing.
ct PERKIND SILENT pk-push-close "$(bash_in "$P1/ap1.jsonl" "$SPRINT" 'bash scripts/ai-dlc/gate-checkpoint.sh --nonce m close')"
ct PERKIND SILENT pk-push-gatelog "$(printf '%s' "$GLADD" | jq -c --arg t "$P1/ap1.jsonl" '.transcript_path = $t')"
ct PERKIND SILENT pk-merge-close "$(bash_in "$P1/amp.jsonl" "$SPRINT" 'bash scripts/ai-dlc/gate-checkpoint.sh --nonce m close')"
ct PERKIND SILENT pk-merge-gatelog "$(printf '%s' "$GLADD" | jq -c --arg t "$P1/amp.jsonl" '.transcript_path = $t')"

c TWRITE DENY "$(write_in "$P1/none.jsonl" "$P1/none.jsonl")"
for x in "echo x >> $P1/none.jsonl" "printf x | tee -a ~/projects/p1/none.jsonl" "sed -i '' s/a/b/ $P1/par/subagents/agent-a1.jsonl" "mv $W/out ~/projects/p1/none.jsonl"; do
  c TWRITE DENY "$(bash_in "$P1/none.jsonl" "$SPRINT" "$x")"
done
c TWRITEREAD SILENT "$(bash_in "$P1/none.jsonl" "$SPRINT" "cat $P1/none.jsonl > $W/copy.txt")"
c TWRITEREAD SILENT "$(bash_in "$P1/none.jsonl" "$SPRINT" "cp ~/projects/p1/none.jsonl $W/copy.jsonl")"
c TWRITEREAD SILENT "$(write_in "$P1/none.jsonl" "$P1/memory/MEMORY.md")"

c GATELOG DENY "$(edit_in "$P1/g.jsonl" "$GL" '| check | verdict |
' '| check | verdict |

## Gate Log: Sprint 3
Timestamp: 2026-10-06T12:00Z
')"
c GATELOG DENY "$(write_in "$P1/g.jsonl" "$GL" '' "$(printf '# Gate Log\n\n## Gate Log: Sprint 2\n\n## Gate Log: Sprint 3\n')")"
B GATELOG DENY "printf '\n## Gate Log: Sprint 3\n' >> _bmad-output/implementation-artifacts/gate-log.md"
ct GATELOG DENY i-tee "$(bash_in "$P1/g.jsonl" "$SPRINT" "printf '\n## Gate Log: Sprint 3\n' | tee -a _bmad-output/implementation-artifacts/gate-log.md")"
ct GATELOG SILENT i-tee-noentry "$(bash_in "$P1/g.jsonl" "$SPRINT" "printf 'Timestamp: x\n' | tee -a _bmad-output/implementation-artifacts/gate-log.md")"
ct GATELOG DENY j-multi "$(tool_in "$P1/g.jsonl" MultiEdit "$(jq -cn --arg f "$GL" '{file_path:$f,edits:[{old_string:"Timestamp: 2026-10-01T00:00Z\n",new_string:"Timestamp: 2026-10-01T00:00Z\n"},{old_string:"| check | verdict |\n",new_string:"| check | verdict |\n\n## Gate Log: Sprint 3\n"}]}')")"
ct GATELOG SILENT j-multi-noentry "$(tool_in "$P1/g.jsonl" MultiEdit "$(jq -cn --arg f "$GL" '{file_path:$f,edits:[{old_string:"| check | verdict |\n",new_string:"| check | verdict |\n| 12 | PASS |\n"}]}')")"
c GATELOG SILENT "$(write_in "$P1/g.jsonl" "$GL" '' "$(printf '# Gate Log\n')")"
c GATELOG SILENT "$(write_in "$P1/g.jsonl" "$GL" '' "$(printf '# Gate Log\n\n## Gate Log: Sprint 2\nedited\n')")"
B GATELOG SILENT 'tail -20 _bmad-output/implementation-artifacts/gate-log.md'

cell FAILOPEN SILENT 'E:not readable JSON' - '{"tool_name":"Bash","tool_input":{"command":"git push"'
cell FAILOPEN SILENT 'E:gate skipped' - "$(bash_in "$P1/absent.jsonl" "$SPRINT" 'git push -u origin HEAD')"

# Every cell file must hold its input: a builder that failed writes an empty file, and an empty
# input is SILENT, which is what half the cells want.
_i=1
while [ "$_i" -le "$nc" ]; do
  [ -s "$CELLS/$_i.json" ] || { echo "FIXTURE BROKEN: cell $_i has no input" >&2; exit 2; }
  _i=$((_i+1))
done
_mn="$(grep -c . "$MAN")" || _mn=0
[ "$nc" -gt 0 ] && [ "$_mn" -eq "$nc" ] || { echo "FIXTURE BROKEN: manifest lists $_mn of $nc cells" >&2; exit 2; }

# The decision, parsed with ONE jq: DENY<TAB>reason, WARN, or OTHER.
DECIDE='.hookSpecificOutput as $h
  | if (($h.permissionDecision? // "") == "deny") then "DENY\t\($h.permissionDecisionReason // "")"
    elif (($h.permissionDecision? == null) and (($h.additionalContext? // "") | tostring | contains("NOT blocked"))) then "WARN\t-"
    else "OTHER\t-" end'

# score <hook> <cell-log> -> prints the space-separated, C-sorted set of arms that FAILED, or
# nothing; writes the id of every failing cell to <cell-log>.
score() {
  local h="$1" log="$2" failed="" exitbad=0 n id check arm want V REASON_TXT ERR_TXT
  : > "$log"
  local tgt add dly rrk apid
  while IFS=$'\t' read -r n id check arm want <&3; do
    if [ -f "$CELLS/$n.app" ]; then
      apid=""
      IFS=$'\t' read -r tgt add dly rrk < "$CELLS/$n.app"
      if ! cp "$P1/rr.tmpl" "$tgt"; then
        printf '%s\n' "$id" >> "$log"; case " $failed " in *" $arm "*) ;; *) failed="$failed $arm" ;; esac; continue
      fi
      if [ "$add" != - ]; then ( sleep "$dly"; cat "$add" >> "$tgt" ) & apid=$!; fi
      if [ "${rrk:--}" = - ]; then
        env -u ADVISOR_GATE_REREADS ADVISOR_GATE_WINDOW=0 HOME="$W" CLAUDE_PROJECT_DIR="$CPD" bash "$h" < "$CELLS/$n.json" > "$OUTF" 2> "$ERRF" || exitbad=1
      else
        ADVISOR_GATE_REREADS="$rrk" ADVISOR_GATE_WINDOW=0 HOME="$W" CLAUDE_PROJECT_DIR="$CPD" bash "$h" < "$CELLS/$n.json" > "$OUTF" 2> "$ERRF" || exitbad=1
      fi
      [ -z "$apid" ] || wait "$apid"
    elif [ -f "$CELLS/$n.win" ]; then
      env -u ADVISOR_GATE_WINDOW ADVISOR_GATE_REREADS=0 HOME="$W" CLAUDE_PROJECT_DIR="$CPD" bash "$h" < "$CELLS/$n.json" > "$OUTF" 2> "$ERRF" || exitbad=1
    else
      ADVISOR_GATE_REREADS=0 ADVISOR_GATE_WINDOW=0 HOME="$W" CLAUDE_PROJECT_DIR="$CPD" bash "$h" < "$CELLS/$n.json" > "$OUTF" 2> "$ERRF" || exitbad=1
    fi
    if [ ! -s "$OUTF" ]; then V=SILENT; REASON_TXT=""
    else
      jq -r "$DECIDE" "$OUTF" > "$VF" 2>/dev/null || printf 'OTHER\t-\n' > "$VF"
      IFS=$'\t' read -r V REASON_TXT < "$VF" || V=OTHER
    fi
    local miss=0
    [ "$V" = "$want" ] || miss=1
    case "$check" in
      R:*) case "$REASON_TXT" in *"${check#R:}"*) ;; *) miss=1 ;; esac ;;
      E:*) ERR_TXT=""; IFS= read -r -d '' ERR_TXT < "$ERRF" || true
           case "$ERR_TXT" in *"${check#E:}"*) ;; *) miss=1 ;; esac ;;
    esac
    if [ "$miss" -eq 1 ]; then
      printf '%s\n' "$id" >> "$log"
      case " $failed " in *" $arm "*) ;; *) failed="$failed $arm" ;; esac
    fi
  done 3< "$MAN"
  [ "$exitbad" -eq 0 ] || failed="$failed EXIT"
  printf '%s\n' "$failed" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'
}
# sorted, space-joined content of a cell log
cells_of() { LC_ALL=C sort "$1" | tr '\n' ' ' | sed 's/ $//'; }

# The world the UPDATE arm's twin rests on: the two repositories must really be on different branches.
_bs="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$SPRINT" symbolic-ref --short -q HEAD)"
_bu="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$UPDATE" symbolic-ref --short -q HEAD)"
_bd="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$DETACHED" symbolic-ref --short -q HEAD)"
[ "$_bs" = sprint/3 ] && [ "$_bu" = ai-dlc-update/x ] && [ -z "$_bd" ] \
  || { echo "FIXTURE BROKEN: seeded branches read sprint='$_bs' update='$_bu' detached='$_bd'" >&2; exit 2; }

