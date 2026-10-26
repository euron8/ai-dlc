#!/usr/bin/env bash
# foreground-budget-deny/run.sh — drive the REAL ai-dlc-foreground-budget.sh hook with
# synthesized PreToolUse JSON on stdin, then drive a battery of mutants of it through the
# same arms.
#
# THE DEFECT. validate-steering-budget.sh Check A counts foreground calls that blocked past
# the steering budget, after the fact, and nothing refused one before it ran. The hook denies
# a foreground Bash call whose DECLARED timeout exceeds the budget and names the re-issue with
# `run_in_background: true`. A wrong deny costs every consumer Bash call, so the allow side is
# pinned as hard as the deny side: every deny cell has an allow twin one property apart.
#
# ARMS. Each is presence-shaped where it can be (a decision or a message must APPEAR), so a
# hook that emits nothing fails them rather than passing them:
#   OVER        foreground, timeout 600000, default budget        -> deny
#   REASON      that deny's reason names `run_in_background: true` and is NOT the push reason
#   PUSHCHAIN   `git push -u origin HEAD > f 2>&1; echo rc=$?`, `git push ... 2>&1 | tail -5`,
#               `git push ... & sleep 900` (a single `&`) and `git push ... && echo done` at 600000 -> deny with the push reason ("starts with a git push", "Drop the
#               chained commands"), and WITHOUT `run_in_background` in it; twin: PUSH
#   BG          the same call with run_in_background true         -> allow
#   NOTIMEOUT   foreground, no timeout declared                   -> allow
#   BOUNDARY    timeout exactly budget*1000 -> allow; one ms over -> deny
#   ENV         AI_DLC_STEERING_BUDGET=600, timeout 300000 -> allow; =60, 90000 -> deny;
#               and =120 with NO detector on disk, 600000 -> deny (the override alone suffices)
#   DEFAULT     no env, the detector's own default moved to 60, timeout 90000 -> deny;
#               90000 against the real detector's 120 -> allow
#   NONBASH     a Read carrying timeout 600000                    -> allow
#   NODETECTOR  no env, no detector, timeout 600000 -> allow, and stderr says why; a subagent
#               poll there -> allow too (its fail-open stderr is asserted under SUBPOLL)
#   UNPARSEABLE truncated JSON, jq present -> deny naming the parse cause and its remedy, and
#               stderr carries no fail-open line
#   SURROGATE   `\ud800` appended to a waiter, a snapshot write and a budget breach -> deny with
#               the PARSE reason (both jq-1.8.1 and jq-1.7.1-apple refuse a lone high surrogate);
#               same-run control: each command without the escape gets no parse deny, and a deny
#               it does get carries its own reason
#   PROGFAULT   a compile error injected into the hook's jq program, `echo hi` -> allow, with the
#               fail-open line on stderr (a program fault is not an unparseable payload)
#   NOJQ        jq absent (PATH=/var/empty, /bin/bash by absolute path) on the OVER payload ->
#               allow, with the fail-open line on stderr
#   PUSH        `git push -u origin HEAD`, `cd /x && git push` and `git push -u origin HEAD 2>&1`
#               (the `&` of a redirection is not a chain), foreground at 600000 -> allow
#               (the pipeline requires a foreground push at that timeout)
#   PUSHNEAR    `echo git push` and `git log --grep=push` at 600000 -> deny
#   AGENT       a subagent's NON-poll calls at 600000 -> allow: `bash scripts/ai-dlc/ci-local.sh`,
#               `sleep 20` (under the poll threshold), the wait-for-deliverable helper's own
#               command, and a non-sleeping loop followed by `sleep 5` after `done;`, `done>out;`,
#               `done</dev/null;` and `done 2>/dev/null;`; the ci-local payload without
#               `agent_id` -> deny
#   SUBPOLL     a subagent's foreground POLL at 600000 -> deny with the poll reason (names the
#               job's own `run_in_background: true` and `wait-for-deliverable.sh --complete`, and
#               not the shorter-timeout remedy): `sleep 200; tail f`, `cd /x && sleep 200`,
#               `sleep 30`, `until grep -q EXIT f; do sleep 5; done`, the prefixed
#               `S=/x; for ...; sleep 10; done`, and two loops whose CONDITION carries a `done`
#               token (`grep -q '^done' f`, `[ -f $S/chain.done ]`). Its allow twins live in the arm owning each
#               shared gate: the loop with `run_in_background` in BG, at 120000 in BOUNDARY, and
#               with no timeout plus a `pg_isready` retry loop with no timeout in NOTIMEOUT
#   WAITER      Deny A: wait-for-deliverable.sh as a command word whose segment ends in a lone `&`
#               (the two graph shapes with `2>&1` right before it, `( wfd x ) &`, `nohup`,
#               `& disown`, `wfd a & wfd b & wait`, ...) at 600000 -> deny. The budget would deny
#               these anyway, so the REASON is the assertion: it names the waiter and
#               `run_in_background: true`, and is not the steering-budget reason
#   WAITERNEAR  its allow twins at 5000: `wfd x; sleep 5 & y`, `2>&1`, `>&2`, `&>f`, `&&`,
#               `|& tee`, a quoted mention, `T=$(wfd ...) && sleep 1 &`. The last two seeds,
#               `bash -c 'wfd x &'` and `w=.../wfd; $w x &`, are KNOWN NON-COVERAGE (23 of
#               graph's 25 backgrounded waiters are denied; these wrappers are the 2 misses), so
#               a widening of the matcher flips them here visibly
#   SNAPWRITE   Deny B: `sed -i` (BSD, GNU, `.bak`, `--in-place`), `perl -pi`, `>`/`>>`, `tee
#               [-a]`, cp/mv onto, git checkout/restore, python open(p,'w') and write_text, node
#               writeFileSync, a variable-held path, at 600000 -> deny; reason names
#               pipeline-snapshot.md and the Edit tool, not the budget
#   SNAPREAD    its allow twins at 5000: cat/grep/sed -n/`<`, git add/show/diff, cp FROM, a
#               `.bak` copy, `>> ...-history.md`, open(p) and open(p,'r'), a redirect to another
#               file, and `bash script --write <snapshot>`
#   SCOPE       both shapes with no detector and no timeout, and under agent_id +
#               run_in_background: true -> deny with each one's own reason
#   REGEXLIMIT  commands long enough to exhaust the regex retry limit: a waiter then 1000 ` >>f` redirects
#               at 600000 (either reason), the same plus `; wfd z &` at 5000 and a waiter then 30000
#               blanks then `y; wfd z &` at 5000 (waiter reason), `sed` with 3000 `-i ` at
#               600000 -> deny, and stderr carries no `jq pass` failure, `not readable` or `Regex failure`
#   FAILOPEN    the WAITER seeds on the shipped hook print no `jq pass` failure, `not readable`, `Regex failure` or
#               fail-open text: a compile error in a shape regex is rethrown by `safetest` and shows
#               up here, where the old broad catch would have swallowed it silently
#   EXIT       every call above exits 0
#
# THE POLL FP SET. Replaying graph's 1,599 foreground over-budget subagent Bash calls (3,227
# transcript files) through the hook denies 198: 152 sleeping loops, 46 long sleeps, 17.0 h of
# tool_use -> tool_result wall clock. All carry a completion test on the agent's own job or an
# artifact; none is a retry loop. The `done`-in-condition seeds are the 25 of those a scan that
# stopped at any word `done` let through.
#
# MUTANTS. Each is a copy of the hook, guarded with `cmp -s` so a `sed` that matched nothing
# reports DID NOT APPLY instead of scoring. Each declares the EXACT set of arms it must fail,
# and the battery asserts set equality, so a mutant killing an arm it should not reach is
# reported as entanglement rather than counted as a kill. An unmutated copy driven the same way
# must fail nothing, and the OVER arm is what gives that control its positive conjunct.
set -uo pipefail

# The pre-push gate exports every AI_DLC_* tunable a consumer set in settings.json into this
# process. Scrub them so the default-budget arms read the default and not the operator's shell.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
[ -n "$WORK" ] && [ -f "$WORK/env.sh" ] || { echo "FIXTURE ERROR: seed printed no work dir" >&2; exit 2; }
# shellcheck source=/dev/null
. "$WORK/env.sh"

command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq not found; the hook fails open without it, so no arm here could fire" >&2; exit 2; }
# NOJQ's control: under PATH=/var/empty no jq resolves, so that arm really drives the jq-absent path.
if env PATH=/var/empty /bin/bash -c 'command -v jq' >/dev/null 2>&1; then
  echo "FIXTURE ERROR: jq resolves under PATH=/var/empty, so the NOJQ arm cannot reach the jq-absent path" >&2; exit 2
fi

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

OUTF="$WORK/out"; ERRF="$WORK/err"

# call <hook> <project> <budget-or-dash> <json>  -> sets RC, DEC, REASON_TXT, ERR_TXT
call() {
  if [ "$3" = "-" ]; then
    printf '%s' "$4" | env -u AI_DLC_STEERING_BUDGET CLAUDE_PROJECT_DIR="$2" bash "$1" >"$OUTF" 2>"$ERRF"
  else
    printf '%s' "$4" | env AI_DLC_STEERING_BUDGET="$3" CLAUDE_PROJECT_DIR="$2" bash "$1" >"$OUTF" 2>"$ERRF"
  fi
  RC=$?
  DEC="$(jq -r '.hookSpecificOutput.permissionDecision // empty' "$OUTF" 2>/dev/null)"
  [ -n "$DEC" ] || DEC=allow
  REASON_TXT="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' "$OUTF" 2>/dev/null)"
  ERR_TXT="$(cat "$ERRF")"
}

bash_call() { jq -nc --argjson t "$1" --argjson bg "$2" '{tool_name:"Bash", tool_input:({command:"bash scripts/ai-dlc/ci-local.sh"} + (if $t == null then {} else {timeout:$t} end) + (if $bg then {run_in_background:true} else {} end))}'; }
# cmd_call <command> <agent_id-or-empty> -> a foreground Bash call at timeout 600000
cmd_call() { jq -nc --arg c "$1" --arg a "$2" '{tool_name:"Bash", tool_input:{command:$c, timeout:600000}} + (if $a == "" then {} else {agent_id:$a} end)'; }

# score <hook> -> prints the space-separated set of arms that FAILED, sorted, or nothing
score() {
  local h="$1" failed="" exitbad=0
  note() { case " $failed " in *" $1 "*) ;; *) failed="$failed $1" ;; esac; }
  chk_rc() { [ "$RC" -eq 0 ] || exitbad=1; }

  call "$h" "$REAL" - "$(bash_call 600000 false)"; chk_rc
  [ "$DEC" = deny ] || note OVER
  # The general (non-push) reason: names the background re-issue, and is not the push reason.
  case "$REASON_TXT" in *'run_in_background: true'*) ;; *) note REASON ;; esac
  case "$REASON_TXT" in *'starts with a git push'*) note REASON ;; esac
  case "$REASON_TXT" in *'do not poll it'*) note REASON ;; esac

  # PUSHCHAIN: a push with something chained or piped after it is denied with the push reason,
  # whose one remedy is to drop the rest; it never offers run_in_background (a backgrounded push
  # loses the exit code the step reads). Twin: the bare push (PUSH, below) is allowed.
  call "$h" "$REAL" - "$(cmd_call 'git push -u origin HEAD > /tmp/p.txt 2>&1; echo rc=$?' '')"; chk_rc
  [ "$DEC" = deny ] || note PUSHCHAIN
  case "$REASON_TXT" in *'starts with a git push'*'Drop the chained commands'*) ;; *) note PUSHCHAIN ;; esac
  case "$REASON_TXT" in *run_in_background*) note PUSHCHAIN ;; esac
  call "$h" "$REAL" - "$(cmd_call 'git push -u origin HEAD 2>&1 | tail -5' '')"; chk_rc
  [ "$DEC" = deny ] || note PUSHCHAIN
  case "$REASON_TXT" in *'starts with a git push'*) ;; *) note PUSHCHAIN ;; esac
  case "$REASON_TXT" in *run_in_background*) note PUSHCHAIN ;; esac
  # A single `&` backgrounds the push and blocks on what follows: a chain, with the push reason.
  call "$h" "$REAL" - "$(cmd_call 'git push -u origin HEAD & sleep 900' '')"; chk_rc
  [ "$DEC" = deny ] || note PUSHCHAIN
  case "$REASON_TXT" in *'starts with a git push'*) ;; *) note PUSHCHAIN ;; esac
  # `&&` after the push is still a chain with the push reason (the single-`&` clause did not move it).
  call "$h" "$REAL" - "$(cmd_call 'git push -u origin HEAD && echo done' '')"; chk_rc
  [ "$DEC" = deny ] || note PUSHCHAIN
  case "$REASON_TXT" in *'starts with a git push'*) ;; *) note PUSHCHAIN ;; esac

  call "$h" "$REAL" - "$(bash_call 600000 true)"; chk_rc
  [ "$DEC" = allow ] || note BG
  call "$h" "$REAL" - "$(jq -nc '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:"until grep -q EXIT f; do sleep 5; done", timeout:600000, run_in_background:true}}')"; chk_rc
  [ "$DEC" = allow ] || note BG

  call "$h" "$REAL" - "$(bash_call null false)"; chk_rc
  [ "$DEC" = allow ] || note NOTIMEOUT
  call "$h" "$REAL" - "$(jq -nc '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:"until grep -q EXIT f; do sleep 5; done"}}')"; chk_rc
  [ "$DEC" = allow ] || note NOTIMEOUT
  call "$h" "$REAL" - "$(jq -nc '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:"for i in $(seq 1 20); do pg_isready && break; sleep 2; done"}}')"; chk_rc
  [ "$DEC" = allow ] || note NOTIMEOUT

  call "$h" "$REAL" - "$(bash_call 120000 false)"; chk_rc
  [ "$DEC" = allow ] || note BOUNDARY
  call "$h" "$REAL" - "$(jq -nc '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:"until grep -q EXIT f; do sleep 5; done", timeout:120000}}')"; chk_rc
  [ "$DEC" = allow ] || note BOUNDARY
  call "$h" "$REAL" - "$(bash_call 120001 false)"; chk_rc
  [ "$DEC" = deny ] || note BOUNDARY

  call "$h" "$REAL" 600 "$(bash_call 300000 false)"; chk_rc
  [ "$DEC" = allow ] || note ENV
  call "$h" "$REAL" 60 "$(bash_call 90000 false)"; chk_rc
  [ "$DEC" = deny ] || note ENV
  call "$h" "$NONE" 120 "$(bash_call 600000 false)"; chk_rc
  [ "$DEC" = deny ] || note ENV

  call "$h" "$SHIFT" - "$(bash_call 90000 false)"; chk_rc
  [ "$DEC" = deny ] || note DEFAULT
  call "$h" "$REAL" - "$(bash_call 90000 false)"; chk_rc
  [ "$DEC" = allow ] || note DEFAULT

  call "$h" "$REAL" - '{"tool_name":"Read","tool_input":{"file_path":"x","timeout":600000}}'; chk_rc
  [ "$DEC" = allow ] || note NONBASH

  call "$h" "$NONE" - "$(bash_call 600000 false)"; chk_rc
  [ "$DEC" = allow ] || note NODETECTOR
  case "$ERR_TXT" in *'validate-steering-budget.sh'*'fail-open'*) ;; *) note NODETECTOR ;; esac
  # A subagent poll inherits the lead arm's fail-open: no detector, no budget, no deny. The
  # decision is NODETECTOR's; the stderr proves the poll REACHED the budget read, which is
  # SUBPOLL's subject (a poll that rode the agent_id exemption exits before it, silently).
  call "$h" "$NONE" - "$(cmd_call 'sleep 200; tail f' 'a1b2c3')"; chk_rc
  [ "$DEC" = allow ] || note NODETECTOR
  case "$ERR_TXT" in *'validate-steering-budget.sh'*'fail-open'*) ;; *) note SUBPOLL ;; esac

  # UNPARSEABLE: jq present and a payload that does not parse -> deny naming the parse cause and
  # its remedy, never the fail-open line.
  call "$h" "$REAL" - '{"tool_name":"Bash","tool_input":{"command":"x","timeout":600000'; chk_rc
  [ "$DEC" = deny ] || note UNPARSEABLE
  case "$REASON_TXT" in *'could not be parsed as JSON'*'Re-issue the command without the unparseable escape'*'check the jq install'*) ;; *) note UNPARSEABLE ;; esac
  case "$ERR_TXT" in *'fail-open'*) note UNPARSEABLE ;; esac

  # SURROGATE: a lone high surrogate escape `\ud800` appended to a waiter, a snapshot write and a
  # budget breach. jq-1.8.1 and jq-1.7.1-apple both refuse it, so each is denied with the PARSE
  # reason, not the subject's own. Same-run control: the identical command without the escape
  # is not a parse deny, and where it is denied its reason is its own.
  local _sc _st _sr
  for _sc in "scripts/ai-dlc/wait-for-deliverable.sh x &|5000|backgrounds wait-for-deliverable.sh" \
             "echo x > _bmad-output/pipeline-snapshot.md|5000|writes pipeline-snapshot.md" \
             "sleep 9|600000|steering budget"; do
    _sr="${_sc##*|}"; _st="${_sc%|*}"; _st="${_st##*|}"; _sc="${_sc%%|*}"
    call "$h" "$REAL" - "$(jq -nc --arg c "$_sc __SURR__" --argjson t "$_st" '{tool_name:"Bash", tool_input:{command:$c, timeout:$t}}' | sed 's/__SURR__/\\ud800/')"; chk_rc
    [ "$DEC" = deny ] || note SURROGATE
    case "$REASON_TXT" in *'could not be parsed as JSON'*'Re-issue the command without the unparseable escape'*) ;; *) note SURROGATE ;; esac
    case "$REASON_TXT" in *"$_sr"*) note SURROGATE ;; esac
    case "$ERR_TXT" in *'fail-open'*) note SURROGATE ;; esac
    call "$h" "$REAL" - "$(jq -nc --arg c "$_sc" --argjson t "$_st" '{tool_name:"Bash", tool_input:{command:$c, timeout:$t}}')"; chk_rc
    case "$REASON_TXT" in *'could not be parsed'*) note SURROGATE ;; esac
    if [ "$DEC" = deny ]; then case "$REASON_TXT" in *"$_sr"*) ;; *) note SURROGATE ;; esac; fi
  done

  # PROGFAULT: a compile error injected into the jq program (a copy of THIS hook, in the push
  # regex every call evaluates) makes jq exit non-zero on `echo hi`. That is a program fault, not
  # an unparseable payload: allow, with the fail-open line on stderr.
  local _pf="$MUT/hook-pf.sh"
  sed 's/def pushfirst: test("/def pushfirst: test("(/' "$h" > "$_pf"
  if cmp -s "$h" "$_pf"; then note PROGFAULT; else
    call "$_pf" "$REAL" - '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'; chk_rc
    [ "$DEC" = allow ] || note PROGFAULT
    case "$ERR_TXT" in *'jq pass'*'fail-open'*) ;; *) note PROGFAULT ;; esac
  fi

  # NOJQ: jq absent -> allow with stderr, on an over-budget call jq-present DENIES (OVER).
  # /usr/bin/jq exists on macOS, so the hook runs under PATH=/var/empty by absolute /bin/bash.
  # Fed from a file, not a pipe: this path exits without reading stdin, and under pipefail a
  # writer that loses that race reports EPIPE as the call's status.
  bash_call 600000 false > "$WORK/nojq.json"
  env PATH=/var/empty CLAUDE_PROJECT_DIR="$REAL" /bin/bash "$h" <"$WORK/nojq.json" >"$OUTF" 2>"$ERRF"
  [ "$?" -eq 0 ] || exitbad=1
  DEC="$(jq -r '.hookSpecificOutput.permissionDecision // empty' "$OUTF" 2>/dev/null)"
  [ -n "$DEC" ] || DEC=allow
  [ "$DEC" = allow ] || note NOJQ
  case "$(cat "$ERRF")" in *'jq not found'*'fail-open'*) ;; *) note NOJQ ;; esac

  call "$h" "$REAL" - "$(cmd_call 'git push -u origin HEAD' '')"; chk_rc
  [ "$DEC" = allow ] || note PUSH
  call "$h" "$REAL" - "$(cmd_call 'cd /x && git push' '')"; chk_rc
  [ "$DEC" = allow ] || note PUSH
  # The near-miss of the single-`&` chain: the `&` of a redirection is not one.
  call "$h" "$REAL" - "$(cmd_call 'git push -u origin HEAD 2>&1' '')"; chk_rc
  [ "$DEC" = allow ] || note PUSH

  call "$h" "$REAL" - "$(cmd_call 'echo git push' '')"; chk_rc
  [ "$DEC" = deny ] || note PUSHNEAR
  call "$h" "$REAL" - "$(cmd_call 'git log --grep=push' '')"; chk_rc
  [ "$DEC" = deny ] || note PUSHNEAR

  # AGENT owns a subagent's over-budget calls that are NOT polls: its job, a short sleep, and
  # the wait helper's own command. Twin: the same ci-local call from the lead is denied.
  call "$h" "$REAL" - "$(cmd_call 'bash scripts/ai-dlc/ci-local.sh' 'a1b2c3')"; chk_rc
  [ "$DEC" = allow ] || note AGENT
  call "$h" "$REAL" - "$(cmd_call 'sleep 20' 'a1b2c3')"; chk_rc
  [ "$DEC" = allow ] || note AGENT
  call "$h" "$REAL" - "$(cmd_call 'bash scripts/ai-dlc/wait-for-deliverable.sh --complete p' 'a1b2c3')"; chk_rc
  [ "$DEC" = allow ] || note AGENT
  # The loop-end near-misses: a loop that does NOT sleep, closed by `done` followed by a
  # separator, a redirect or a blank, then a short sleep. The scan must stop at that `done`, so
  # the trailing `sleep 5` is not read as the loop's body.
  for _c in 'for f in a b; do echo $f; done; sleep 5' 'for f in a b; do echo $f; done>out; sleep 5' \
            'for f in a b; do echo $f; done</dev/null; sleep 5' 'for f in a b; do echo $f; done 2>/dev/null; sleep 5'; do
    call "$h" "$REAL" - "$(cmd_call "$_c" 'a1b2c3')"; chk_rc
    [ "$DEC" = allow ] || note AGENT
  done
  call "$h" "$REAL" - "$(cmd_call 'bash scripts/ai-dlc/ci-local.sh' '')"; chk_rc
  [ "$DEC" = deny ] || note AGENT

  # SUBPOLL: a subagent's foreground poll over the budget is denied with the poll reason. The
  # last two seeds put the poll AFTER a prefix, so a match anchored to the first word misses them;
  # the `for` seed sleeps 10, under the threshold, so only the loop match can catch it. The last
  # two carry a `done` token inside the loop CONDITION (`'^done'`, `chain.done`), which is not
  # the loop's end: a scan that stops at any word `done` misses both.
  for _c in 'sleep 200; tail f' 'cd /x && sleep 200' 'sleep 30' \
            'until grep -q EXIT f; do sleep 5; done' \
            'S=/x; for i in $(seq 1 25); do grep -q EXIT $S/f && break; sleep 10; done' \
            "until grep -q '^done' f; do sleep 5; done" \
            'S=/x; for i in $(seq 1 27); do [ -f $S/chain.done ] && break; sleep 20; done'; do
    call "$h" "$REAL" - "$(cmd_call "$_c" 'a1b2c3')"; chk_rc
    [ "$DEC" = deny ] || note SUBPOLL
    case "$REASON_TXT" in *'re-issue the job itself with `run_in_background: true`'*'do not poll it'*'wait-for-deliverable.sh --complete'*) ;; *) note SUBPOLL ;; esac
    case "$REASON_TXT" in *'declare a timeout of at most'*) note SUBPOLL ;; esac
  done
  # Its allow twins -- the loop backgrounded, at the budget, with no timeout, and a readiness
  # retry with no timeout -- sit in BG, BOUNDARY and NOTIMEOUT: those gates are shared with the
  # lead's arm, so the arm that owns each gate owns its poll twin too.

  # WAITER (Deny A): wait-for-deliverable.sh as a command word whose segment ends in a lone `&`.
  # Driven at 600000 from the lead, so a hook WITHOUT Deny A still denies on budget: the reason
  # is what discriminates -- it must name the waiter and its remedy, never the budget.
  local W='scripts/ai-dlc/wait-for-deliverable.sh' S='_bmad-output/pipeline-snapshot.md'
  for _c in "$W --complete p >/dev/null 2>&1 & echo armed" \
            "$W --complete p > /dev/null 2>&1 & sleep 0; echo" \
            "( $W x ) &" "nohup $W x &" "$W x & disown" "$W a & $W b & wait" \
            "cd /r && $W x &" "$W x 2>&1 &" \
            "$W --since \"\$(date -u +%FT%TZ)\" p >/dev/null 2>&1 & disown; echo" \
            "$W --since t p 2>&1 | head -3 &"; do
    call "$h" "$REAL" - "$(cmd_call "$_c" '')"; chk_rc
    [ "$DEC" = deny ] || note WAITER
    case "$REASON_TXT" in *'backgrounds wait-for-deliverable.sh'*'run_in_background: true'*) ;; *) note WAITER ;; esac
    case "$REASON_TXT" in *'steering budget'*) note WAITER ;; esac
    # FAILOPEN: the jq pass must have run clean -- a printed fail-open or regex error is a failure.
    case "$ERR_TXT" in *'jq pass'*|*'not readable'*|*'Regex failure'*|*'fail-open'*) note FAILOPEN ;; esac
  done
  # WAITERNEAR: the allow twins, at a timeout within budget so only Deny A could refuse them.
  for _c in "$W x; sleep 5 & y" "$W x 2>&1" "$W x >&2" "$W x &>f" "$W x && y" "$W x |& tee f" \
            "grep '$W x &' f" "echo \"run $W x &\"" "grep -n wait-for-deliverable.sh core/x.md &" \
            "T=\$($W --dispatch-ts a1) && sleep 1 &" "T=\$($W --dispatch-ts a1 2>&1 | tail -1); echo \$T" \
            "bash -c '$W x &'" \
            "w=$W; \$w x &"; do
    # The last two are KNOWN NON-COVERAGE, not correct allows: 23 of graph's 25 backgrounded
    # waiters are denied, and these are the 2 misses -- the waiter behind a wrapper (inside a
    # `bash -c` string, and called through a variable). They are seeded so that any widening of
    # the matcher that starts catching a wrapper flips them here, deliberately and visibly.
    call "$h" "$REAL" - "$(jq -nc --arg c "$_c" '{tool_name:"Bash", tool_input:{command:$c, timeout:5000}}')"; chk_rc
    [ "$DEC" = allow ] || note WAITERNEAR
  done

  # SNAPWRITE (Deny B): a shell or interpreter write of pipeline-snapshot.md. Driven at 600000,
  # so the reason discriminates as in WAITER.
  for _c in "sed -i '' 's/a/b/' $S" "sed -i 's/a/b/' $S" "sed -i.bak 's/a/b/' $S" \
            "sed --in-place 's/a/b/' $S" "perl -pi -e 's/a/b/' $S" \
            "echo x > $S" "echo x >> $S" "printf x >\"$S\"" "echo x | tee $S" "echo x | tee -a $S" \
            "cp /tmp/s.md $S" "mv /tmp/s.md $S" "git checkout HEAD -- $S" "git restore $S" \
            "python3 -c \"open('$S','w').write('x')\"" \
            $'python3 - <<\'EOF\'\np=\''"$S"$'\'\nL=open(p).read()\nopen(p,\'w\').write(L)\nEOF' \
            $'python3 - <<\'EOF\'\nfrom pathlib import Path\np=Path(\''"$S"$'\')\np.write_text(\'x\')\nEOF' \
            "node -e \"fs.writeFileSync('$S','x')\"" \
            "S=$S; sed -i '' \"s/a/b/\" \"\$S\""; do
    call "$h" "$REAL" - "$(cmd_call "$_c" '')"; chk_rc
    [ "$DEC" = deny ] || note SNAPWRITE
    case "$REASON_TXT" in *'writes pipeline-snapshot.md'*'Edit tool'*) ;; *) note SNAPWRITE ;; esac
    case "$REASON_TXT" in *'steering budget'*) note SNAPWRITE ;; esac
  done
  # SNAPREAD: the allow twins -- reads, a copy FROM it, an append to the history file, a
  # read-only interpreter open, a script given the path -- within budget, so only Deny B could refuse.
  for _c in "cat $S" "grep -n x $S" "sed -n '1,5p' $S" "wc -l < $S" \
            "git add $S && git commit -m x" "git show HEAD:$S" "git diff -- $S" \
            "cp $S /tmp/s.md" "cp $S $S.bak" "echo x >> _bmad-output/pipeline-snapshot-history.md" \
            $'python3 - <<\'EOF\'\np=\''"$S"$'\'\nh=\'_bmad-output/pipeline-snapshot-history.md\'\nL=open(p).read()\nopen(h,\'a\').write(L)\nEOF' \
            "python3 -c \"print(open('$S').read())\"" "python3 -c \"print(open('$S','r').read())\"" \
            "grep x $S > /tmp/out.txt 2>&1" \
            "scripts/ai-dlc/validate-artifact-budget.sh --only pipeline-snapshot.md 2>&1 | head" \
            "bash scripts/ai-dlc/render-x.sh --write $S"; do
    call "$h" "$REAL" - "$(jq -nc --arg c "$_c" '{tool_name:"Bash", tool_input:{command:$c, timeout:5000}}')"; chk_rc
    [ "$DEC" = allow ] || note SNAPREAD
  done

  # SCOPE: both shapes are denied OUTSIDE every gate the budget deny applies -- no detector on
  # disk and no timeout (every budget read fails open there), and from a subagent with
  # run_in_background: true. A deny moved behind the timeout/agent_id/background scope fails here.
  local _p
  for _p in "$(jq -nc --arg c "$W x &" '{tool_name:"Bash", tool_input:{command:$c}}')" \
            "$(jq -nc --arg c "$W x &" '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:$c, timeout:600000, run_in_background:true}}')"; do
    call "$h" "$NONE" - "$_p"; chk_rc
    [ "$DEC" = deny ] || note SCOPE
    case "$REASON_TXT" in *'backgrounds wait-for-deliverable.sh'*'run_in_background: true'*) ;; *) note SCOPE ;; esac
  done
  for _p in "$(jq -nc --arg c "echo x > $S" '{tool_name:"Bash", tool_input:{command:$c}}')" \
            "$(jq -nc --arg c "echo x > $S" '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:$c, timeout:600000, run_in_background:true}}')"; do
    call "$h" "$NONE" - "$_p"; chk_rc
    [ "$DEC" = deny ] || note SCOPE
    case "$REASON_TXT" in *'writes pipeline-snapshot.md'*'Edit tool'*) ;; *) note SCOPE ;; esac
  done

  # REGEXLIMIT: a valid command (every seed passes bash -n -c) long enough to exhaust the regex engine's retry limit must not
  # turn into a jq error, which the hook reads as unparseable input and ALLOWS -- losing both the
  # shape deny and the budget deny. Each seed asserts its decision and a clean stderr.
  local _g _b
  _g="$(printf '%1000s' '' | sed 's/ / >>f/g')"
  _b="$(printf '%30000s' '')"
  # The in-place verb is assembled so this file carries no literal suffix-less in-place sed (S1).
  local _ip; _ip="$(printf '%3000s' '' | sed 's/ /-i /g')"
  for _p in "$(jq -nc --arg c "$W x$_g" '{tool_name:"Bash", tool_input:{command:$c, timeout:600000}}')" \
            "$(jq -nc --arg c "$W x$_g; $W z &" '{tool_name:"Bash", tool_input:{command:$c, timeout:5000}}')" \
            "$(jq -nc --arg c "$W x ${_b}y; $W z &" '{tool_name:"Bash", tool_input:{command:$c, timeout:5000}}')" \
            "$(jq -nc --arg c "sed $_ip $S.bak" '{tool_name:"Bash", tool_input:{command:$c, timeout:600000}}')"; do
    call "$h" "$REAL" - "$_p"; chk_rc
    [ "$DEC" = deny ] || note REGEXLIMIT
    case "$ERR_TXT" in *'jq pass'*|*'not readable'*|*'Regex failure'*) note REGEXLIMIT ;; esac
    # Every seed at 5000 can only be refused by Deny A, so it must carry the waiter reason.
    case "$_p" in *'"timeout":5000'*) case "$REASON_TXT" in *'backgrounds wait-for-deliverable.sh'*) ;; *) note REGEXLIMIT ;; esac ;; esac
  done

  [ "$exitbad" -eq 0 ] || note EXIT
  printf '%s\n' "$failed" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'
}

echo "foreground-budget-deny:"
printf '  hook      %s\n' "$HOOK"
printf '  detector  %s\n' "$DETECTOR"
printf 'HERMETIC-CONSUMED %s\n' "$HOOK"
printf 'HERMETIC-CONSUMED %s\n' "$DETECTOR"

# --- the shipped hook ----------------------------------------------------------------------
[ -x "$HOOK" ] || bad "hook is not executable: $HOOK -- settings.json invokes it as a bare path"
GOT="$(score "$HOOK")"
if [ -z "$GOT" ]; then
  ok "shipped hook passes every arm (OVER REASON PUSHCHAIN BG NOTIMEOUT BOUNDARY ENV DEFAULT NONBASH NODETECTOR UNPARSEABLE SURROGATE PROGFAULT NOJQ PUSH PUSHNEAR AGENT SUBPOLL WAITER WAITERNEAR SNAPWRITE SNAPREAD SCOPE REGEXLIMIT FAILOPEN EXIT)"
else
  bad "shipped hook fails arm(s): $GOT"
fi

# The SHIFT world is the only thing that separates "reads the detector's default" from "carries
# its own 120". Prove the two projects really do disagree on the default line.
if cmp -s "$REAL/scripts/ai-dlc/validate-steering-budget.sh" "$SHIFT/scripts/ai-dlc/validate-steering-budget.sh"; then
  bad "FIXTURE BROKEN: the SHIFT detector is byte-identical to the real one, so DEFAULT cannot discriminate"
fi

# --- mutants ---------------------------------------------------------------------------------
n_mut=0; n_kill=0
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

# Unmutated control, driven from the same directory the mutants are.
cp "$HOOK" "$MUT/hook-control.sh"
CTL="$(score "$MUT/hook-control.sh")"
[ -z "$CTL" ] && ok "unmutated copy from the mutant directory passes every arm" \
              || bad "unmutated copy fails [$CTL] -- the harness, not a mutant, is what fails"

# Expected sets are written in C-locale sorted order, which is what score() prints.
# Mutants 1 and 12 remove the whole deny channel rather than one guard, so they fail every arm
# holding a deny cell; each of the others fails its own arm alone.
# 1. warning-only: the same text as context, no decision. The rejected design.
mut warn-only "AGENT BOUNDARY DEFAULT ENV OVER PUSHCHAIN PUSHNEAR REASON REGEXLIMIT SCOPE SNAPWRITE SUBPOLL WAITER" \
  -e '/permissionDecision: "deny",/d' -e 's/permissionDecisionReason: \$reason/additionalContext: $reason/'
# 2. denies a call already sent to the background.
mut denies-background "BG" -e '/and \.tool_input\.run_in_background != true/d'
# 3. at-budget is over budget.
mut boundary-ge "BOUNDARY" -e 's/\[ "\$T" -gt "\$LIMIT" \]/[ "$T" -ge "$LIMIT" ]/'
# 4. ignores the override.
mut ignores-env "ENV" -e 's/^B="\${AI_DLC_STEERING_BUDGET:-}"$/B=""/'
# 5. a second 120 instead of the detector's default.
mut literal-default "DEFAULT" -e 's/B="\${line#\*:-}"; B="\${B%%\\}\*}"; break/B=120; break/'
# 6. every tool, not just Bash.
mut any-tool "NONBASH" -e 's/if \.tool_name == "Bash"/if true/'
# 7. no declared timeout read as a long one.
mut no-timeout-is-long "NOTIMEOUT" \
  -e 's/and (\.tool_input\.timeout | type) == "number"/and true/' \
  -e 's/| \.tool_input\.timeout | if/| (.tool_input.timeout \/\/ 600000) | if/'
# 8. the parse deny loses its remedy: a deny with no remedy reads as a hook bug.
mut parse-drops-remedy "SURROGATE UNPARSEABLE" -e 's/ Re-issue the command without the unparseable escape\. If this recurs on an ordinary command, check the jq install (`jq --version`)\.//'
# 9. no detector: fall back to a literal and deny.
mut no-detector-literal "NODETECTOR" -e 's/allowing it (fail-open)"; exit 0$/allowing it (fail-open)"; B=120; SRC=\/dev\/null/'
# 10. the reason stops naming the background re-issue.
mut reason-drops-background "REASON" -e 's/Re-issue the same call with run_in_background: true and collect its result when it completes, or/Re-issue it with a shorter timeout, or/'
# 11. the deny path exits non-zero.
mut deny-exits-nonzero "EXIT" -e '$s/^exit 0$/exit 2/'
# 12. the whole subject replaced by silence: every presence-shaped arm must fail.
mut silence "AGENT BOUNDARY DEFAULT ENV NODETECTOR NOJQ OVER PROGFAULT PUSHCHAIN PUSHNEAR REASON REGEXLIMIT SCOPE SNAPWRITE SUBPOLL SURROGATE UNPARSEABLE WAITER" -e '2i\
exit 0'
# 13. no push allowance: the pipeline's required foreground push is denied.
mut drop-push "PUSH" -e '/and (is_push | not)/d'
# 14. the push match loses its start anchor, so `echo git push` rides the exemption.
mut push-unanchored "PUSHNEAR" -e 's/test("^\[ \\t\]\*(cd/test("(cd/'
# 15. no agent_id exit: a teammate's non-poll call is denied though it is its job, not a wait.
mut drop-agent "AGENT" -e 's/| select(\$agent == "" or \$poll)/| select(true)/'
# 16. the PUSHCHAIN field dropped: a chained push gets the general reason, run_in_background and all.
mut drop-pushchain "PUSHCHAIN" -e 's/^PUSHCHAIN="\${T##\* }"$/PUSHCHAIN=0/'
# 17. the poll predicate removed: a subagent's poll rides the agent_id exemption again.
mut drop-poll "SUBPOLL" -e 's/| select(\$agent == "" or \$poll)/| select($agent == "")/'
# 18. the loop match anchored to word 1: a poll loop after `S=/x;` is no longer seen.
mut loop-word1 "SUBPOLL" -e 's/def loopsleep: test(cmdpos + "(until/def loopsleep: test("^[ \\t]*(until/'
# 19. the long-sleep match anchored to word 1: `cd /x && sleep 200` is no longer seen.
mut sleep-word1 "SUBPOLL" -e 's/match(cmdpos + "sleep\[/match("^[ \\t]*sleep[/'
# 20. the sleep threshold dropped to 0: a subagent's short `sleep 20` is denied as a poll.
mut threshold-zero "AGENT" -e 's/any(\. >= 30)/any(. >= 0)/'
# 21. the poll reason never chosen: a denied poll gets the lead's shorter-timeout remedy.
mut drop-poll-reason "SUBPOLL" -e 's/^POLL="\${T##\* }"$/POLL=0/'
# 22. the loop scan stops at ANY word `done`: a `done` in the loop condition hides the poll.
mut loopend-word "SUBPOLL" -e 's/(?!" + loopend + ")/(?!\\\\bdone\\\\b)/'
# 23. the loop end without the redirect characters: `done>out; sleep 5` reads as a poll.
mut loopend-no-redirect "AGENT" -e 's/done(\[ \\t;&|)<>\\n\]|\$)/done([ \\t;\&|)\\n]|$)/'
# 24. m-amp: the waiter's redirect alternative stops consuming the `&` of `2>&1`/`>&2`, so that
#     `&` reads as the lone one and `wfd x 2>&1` is denied.
mut m-amp "WAITERNEAR" -e 's/(?>\[<>\]+)(?:&\[0-9-\]\*|(?!&))/(?>[<>]+)/'
# 25. m-scope: Deny A moved behind the timeout and agent_id scope, so a waiter with no timeout, or
#     from a subagent, rides the gates that exempted exactly the calls that carried this shape.
mut m-scope "SCOPE" -e 's/and (\$cmd | safetest(wfdbg)) then "DENY A"/and ($cmd | safetest(wfdbg)) and (.tool_input.timeout | type) == "number" and (.agent_id \/\/ "") == "" then "DENY A"/'
# 26. m-append: the redirect write drops `>>`, so an append onto the snapshot is not seen.
mut m-append "SNAPWRITE" -e 's/\[0-9\]\*>>?\[|\]?/[0-9]*>(?!>)[|]?/'
# 27. m-read: Deny B made fail-closed on any mention of the snapshot, so a read is refused.
mut m-read "SNAPREAD" -e 's/ and (\$cmd | snapwrite) then "DENY B"/ then "DENY B"/'
# 28. m-noatomic: the redirect run loses its atomic group, so a waiter segment of 1000 `>` that
#     ends in `;` exhausts the retry limit and, caught, hides the LATER waiter's lone `&`.
mut m-noatomic "REGEXLIMIT" -e 's/|(?>\[<>\]+)(?:&/|[<>]+(?:\&/'
# 29. m-blanktail: the tail's blank run may start after a blank, so a 30000-blank run followed by
#     no `&` re-scans quadratically and the later waiter is missed.
mut m-blanktail "REGEXLIMIT" -e 's/)\*?(?<!\[ \\t\])\[ \\t\]\*(?:/)*?[ \\t]*(?:/'
# 30. m-notry: the shape tests lose their catch, so a regex error is a jq error and the call fails open.
mut m-notry "REGEXLIMIT" -e 's/def safetest(\$re): try test(\$re) catch (if (tostring | test("retry-limit")) then false else error end);/def safetest($re): test($re);/'
# 31. m-badre: a compile error injected into wfdbg. The narrowed catch rethrows it, the jq pass fails
# and the hook prints its fail-open message and allows: WAITER, SCOPE, REGEXLIMIT (no deny) and FAILOPEN (printed error)
# both go red. The OLD broad catch with the same injection would print nothing and redden the no-deny arms (WAITER, SCOPE, REGEXLIMIT) but never FAILOPEN.
mut m-badre "FAILOPEN REGEXLIMIT SCOPE WAITER" -e 's/wait-for-deliverable\\\\\.sh/&(/'
# 32. m-failopen: the parse sentinel allowed, as before the fix -- a lone surrogate appended to any
#     refused command loses every deny again.
mut m-failopen "SURROGATE UNPARSEABLE" -e "s/^  '@PARSEFAIL@') printf .*; exit 0 ;;\$/  '@PARSEFAIL@') exit 0 ;;/"
# 33. m-anyfail: the deny keyed on jq's exit status, which is 5 for a program fault as for a parse
#     error, so a fault in the program denies every call.
mut m-anyfail "PROGFAULT" -e 's/^if \[ "\$PARSE_RC" -ne 0 \]; then$/if [ "$PARSE_RC" -ne 0 ]; then T=@PARSEFAIL@; elif false; then/'
# 34. m-nojqdeny: the jq-absent path denies, which would refuse every Bash call in the session.
mut m-nojqdeny "NOJQ" -e '/^command -v jq/s/exit 0; }$/echo "{\\"hookSpecificOutput\\":{\\"permissionDecision\\":\\"deny\\"}}"; exit 0; }/'

[ "$n_mut" -gt 0 ] && [ "$n_kill" -eq "$n_mut" ] \
  && ok "$n_kill of $n_mut mutants killed" \
  || bad "$n_kill of $n_mut mutants killed"

# Clean up by name: the seed's files and directories, never a recursive delete of a variable.
rm -f "$OUTF" "$ERRF" "$WORK/env.sh" "$WORK/nojq.json" "$MUT"/hook-*.sh \
      "$REAL/scripts/ai-dlc/validate-steering-budget.sh" "$SHIFT/scripts/ai-dlc/validate-steering-budget.sh"
rmdir "$REAL/scripts/ai-dlc" "$REAL/scripts" "$REAL" "$SHIFT/scripts/ai-dlc" "$SHIFT/scripts" "$SHIFT" \
      "$NONE" "$MUT" "$WORK" 2>/dev/null

echo
if [ "$fails" -eq 0 ]; then echo "foreground-budget-deny: PASS"; exit 0; fi
echo "foreground-budget-deny: $fails assertion(s) FAILED" >&2
exit 1
