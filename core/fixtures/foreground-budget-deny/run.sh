#!/usr/bin/env bash
# foreground-budget-deny/run.sh — drive the REAL ai-dlc-foreground-budget.sh hook with
# synthesized PreToolUse JSON on stdin.
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
#               [-a]`, cp/mv/install/ln onto (with flags, and with a trailing redirect run:
#               `2>/dev/null`, `>/dev/null`, `2>&1`, `</dev/null`, `1>&2`, `2>/dev/null; echo`),
#               git checkout/restore, python open(p,'w') and write_text, node
#               writeFileSync, a variable-held path, at 600000 -> deny; reason names
#               pipeline-snapshot.md, snapshot-update.sh and its ops (`--line-replace`,
#               `--row-replace`), and neither the Edit tool nor Write, not the budget
#   SNAPREAD    its allow twins at 5000: cat/grep/sed -n/`<`, git add/show/diff, cp FROM (also
#               with `2>/dev/null` after the other target), a `.bak` copy, `.bak` onto the
#               history file, `>> ...-history.md`, open(p) and open(p,'r'), a redirect to another
#               file, `bash script --write <snapshot>`, and case variants of the `.bak` and history file
#   SNAPSKIP    one segment running snapshot-update.sh or the rotator whose ARGUMENT text reads as a
#               write shape onto the snapshot, at 5000 -> allow (the F3 false refusal); two of them
#               quote the command word in a BALANCED pair, `'...snapshot-update.sh'` and `"..."`,
#               and one carries `$'` inside double quotes (`--activity "a$'b"`), which is literal
#   SNAPCHAIN   its deny twins at 600000: the writer then `; sed -i`, `&& >`, `| tee`, `&`, a newline,
#               a redirect onto the snapshot, a `$(...)` and a backtick argument, the command
#               words `x/not-snapshot-update.sh` and `snapshot-update.sh.bak`, and three UNBALANCED
#               quotes on the command word (`'...sh '; sed -i ...`, the `"` form, `...sh' '; sed -i ...`),
#               which bash runs as a sed of the snapshot, and an ANSI-C `$'x\''` argument hiding
#               `; sed -i ...`, `; cp /dev/null <snapshot>` and the same cp with a trailing
#               `2>/dev/null`, behind a `#'` -> deny, Deny B reason
#   SNAPCASE    `Pipeline-Snapshot.md`, `PIPELINE-SNAPSHOT.MD` and a variable bound to a case
#               variant, written by shell at 600000 -> deny with the Deny B reason
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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# IN PROCESS (BL-878). The hook is SOURCED once (its column-0 guard returns after defining fgb_main) and every call
# runs fgb_main in a subshell with the payload on stdin, so the hook's own `exit`, `set -uo pipefail`, PATH and
# variables stay in that subshell. PROGFAULT's copy with an injected jq compile error is sourced inside its own
# subshell, once per call: that is its own in-process pass.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped hook, and
# sourcing a pre-wrap one would run the whole hook in this shell. So the shape is checked first, on its two halves:
# neither the `fgb_main() {` line nor the column-0 source guard is a subject that predates the wrap, which prints SKIP
# and exits 0 -- never an ok. Exactly one half is a respelled subject this fixture can no longer drive, which FAILS.
# An unreadable subject is FIXTURE ERROR.
fgb_def=0; fgb_guard=0
grep -q '^fgb_main() {$' "$HOOK"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $HOOK (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || fgb_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$HOOK"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $HOOK (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || fgb_guard=1
if [ "$fgb_def$fgb_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$fgb_def" = 0 ]; then echo "   FAIL  $HOOK carries the column-0 source guard but no \`fgb_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "foreground-budget-deny: FAIL (1)" >&2; exit 1; fi
if [ "$fgb_guard" = 0 ]; then echo "   FAIL  $HOOK defines \`fgb_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run fgb_main in this shell" >&2; echo "foreground-budget-deny: FAIL (1)" >&2; exit 1; fi
fx_inproc "$HOOK"
. "$HOOK" || { echo "FIXTURE BROKEN: sourcing $HOOK failed" >&2; exit 2; }
declare -F fgb_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $HOOK defined no fgb_main" >&2; exit 2; }
INF="$WORK/in"


# The arms that own a call of their own. REASON is read off the OVER call, FAILOPEN off the
# WAITER seeds, EXIT off the exit status of whichever calls ran.
ALL_UNITS="OVER PUSHCHAIN BG NOTIMEOUT BOUNDARY ENV DEFAULT NONBASH NODETECTOR UNPARSEABLE SURROGATE PROGFAULT NOJQ PUSH PUSHNEAR AGENT SUBPOLL WAITER WAITERNEAR SNAPWRITE SNAPREAD SNAPSKIP SNAPCHAIN SNAPCASE SCOPE REGEXLIMIT"

OUTF="$WORK/out"; ERRF="$WORK/err"
NCALL=0
FAILED=""; EXITBAD=0; SC_DEAD=""
note() { case " $FAILED " in *" $1 "*) ;; *) FAILED="$FAILED $1" ;; esac; }
chk_rc() { [ "$RC" -eq 0 ] || EXITBAD=1; }
W='scripts/ai-dlc/wait-for-deliverable.sh'; S='_bmad-output/pipeline-snapshot.md'

# call <hook> <project> <budget-or-dash> <json>  -> sets RC, DEC, REASON_TXT, ERR_TXT
call() {
  NCALL=$((NCALL+1))
  printf '%s' "$4" > "$INF"
  ( if [ "$3" = "-" ]; then unset AI_DLC_STEERING_BUDGET; else export AI_DLC_STEERING_BUDGET="$3"; fi
    export CLAUDE_PROJECT_DIR="$2"
    if [ "$1" != "$HOOK" ]; then
      fx_inproc "$1"
      . "$1" || exit 97
      fgb_main
    else
      fx_inproc "$1"
      fgb_main
    fi ) <"$INF" >"$OUTF" 2>"$ERRF"
  RC=$?
  DEC="$(jq -r '.hookSpecificOutput.permissionDecision // empty' "$OUTF" 2>/dev/null)"
  [ -n "$DEC" ] || DEC=allow
  REASON_TXT="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' "$OUTF" 2>/dev/null)"
  ERR_TXT="$(cat "$ERRF")"
}

bash_call() { jq -nc --argjson t "$1" --argjson bg "$2" '{tool_name:"Bash", tool_input:({command:"bash scripts/ai-dlc/ci-local.sh"} + (if $t == null then {} else {timeout:$t} end) + (if $bg then {run_in_background:true} else {} end))}'; }
# cmd_call <command> <agent_id-or-empty> -> a foreground Bash call at timeout 600000
cmd_call() { jq -nc --arg c "$1" --arg a "$2" '{tool_name:"Bash", tool_input:{command:$c, timeout:600000}} + (if $a == "" then {} else {agent_id:$a} end)'; }

# sc_run <hook> <unit>... -> runs those arms against the hook, sets SC_DEAD to the space-separated,
# C-sorted set of columns that FAILED (EXIT included), or empty.
sc_run() {
  local h="$1" u; shift
  FAILED=""; EXITBAD=0
  for u in "$@"; do "arm_$u" "$h"; done
  [ "$EXITBAD" -eq 0 ] || note EXIT
  SC_DEAD="$(printf '%s\n' "$FAILED" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
}
in_set() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }


arm_OVER() {
  local h="$1"
  call "$h" "$REAL" - "$(bash_call 600000 false)"; chk_rc
  [ "$DEC" = deny ] || note OVER
  # The general (non-push) reason: names the background re-issue, and is not the push reason.
  case "$REASON_TXT" in *'run_in_background: true'*) ;; *) note REASON ;; esac
  case "$REASON_TXT" in *'starts with a git push'*) note REASON ;; esac
  case "$REASON_TXT" in *'do not poll it'*) note REASON ;; esac
}

arm_PUSHCHAIN() {
  local h="$1"
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
}

arm_BG() {
  local h="$1"
  call "$h" "$REAL" - "$(bash_call 600000 true)"; chk_rc
  [ "$DEC" = allow ] || note BG
  call "$h" "$REAL" - "$(jq -nc '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:"until grep -q EXIT f; do sleep 5; done", timeout:600000, run_in_background:true}}')"; chk_rc
  [ "$DEC" = allow ] || note BG
}

arm_NOTIMEOUT() {
  local h="$1"
  call "$h" "$REAL" - "$(bash_call null false)"; chk_rc
  [ "$DEC" = allow ] || note NOTIMEOUT
  call "$h" "$REAL" - "$(jq -nc '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:"until grep -q EXIT f; do sleep 5; done"}}')"; chk_rc
  [ "$DEC" = allow ] || note NOTIMEOUT
  call "$h" "$REAL" - "$(jq -nc '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:"for i in $(seq 1 20); do pg_isready && break; sleep 2; done"}}')"; chk_rc
  [ "$DEC" = allow ] || note NOTIMEOUT
}

arm_BOUNDARY() {
  local h="$1"
  call "$h" "$REAL" - "$(bash_call 120000 false)"; chk_rc
  [ "$DEC" = allow ] || note BOUNDARY
  call "$h" "$REAL" - "$(jq -nc '{tool_name:"Bash", agent_id:"a1b2c3", tool_input:{command:"until grep -q EXIT f; do sleep 5; done", timeout:120000}}')"; chk_rc
  [ "$DEC" = allow ] || note BOUNDARY
  call "$h" "$REAL" - "$(bash_call 120001 false)"; chk_rc
  [ "$DEC" = deny ] || note BOUNDARY
}

arm_ENV() {
  local h="$1"
  call "$h" "$REAL" 600 "$(bash_call 300000 false)"; chk_rc
  [ "$DEC" = allow ] || note ENV
  call "$h" "$REAL" 60 "$(bash_call 90000 false)"; chk_rc
  [ "$DEC" = deny ] || note ENV
  call "$h" "$NONE" 120 "$(bash_call 600000 false)"; chk_rc
  [ "$DEC" = deny ] || note ENV
}

arm_DEFAULT() {
  local h="$1"
  call "$h" "$SHIFT" - "$(bash_call 90000 false)"; chk_rc
  [ "$DEC" = deny ] || note DEFAULT
  call "$h" "$REAL" - "$(bash_call 90000 false)"; chk_rc
  [ "$DEC" = allow ] || note DEFAULT
}

arm_NONBASH() {
  local h="$1"
  call "$h" "$REAL" - '{"tool_name":"Read","tool_input":{"file_path":"x","timeout":600000}}'; chk_rc
  [ "$DEC" = allow ] || note NONBASH
}

arm_NODETECTOR() {
  local h="$1"
  call "$h" "$NONE" - "$(bash_call 600000 false)"; chk_rc
  [ "$DEC" = allow ] || note NODETECTOR
  case "$ERR_TXT" in *'validate-steering-budget.sh'*'fail-open'*) ;; *) note NODETECTOR ;; esac
  # A subagent poll inherits the lead arm's fail-open: no detector, no budget, no deny. The
  # decision is NODETECTOR's; the stderr proves the poll REACHED the budget read, which is
  # SUBPOLL's subject (a poll that rode the agent_id exemption exits before it, silently).
  call "$h" "$NONE" - "$(cmd_call 'sleep 200; tail f' 'a1b2c3')"; chk_rc
  [ "$DEC" = allow ] || note NODETECTOR
}

arm_UNPARSEABLE() {
  local h="$1"
  # UNPARSEABLE: jq present and a payload that does not parse -> deny naming the parse cause and
  # its remedy, never the fail-open line.
  call "$h" "$REAL" - '{"tool_name":"Bash","tool_input":{"command":"x","timeout":600000'; chk_rc
  [ "$DEC" = deny ] || note UNPARSEABLE
  case "$REASON_TXT" in *'could not be parsed as JSON'*'Re-issue the command without the unparseable escape'*'check the jq install'*) ;; *) note UNPARSEABLE ;; esac
  case "$ERR_TXT" in *'fail-open'*) note UNPARSEABLE ;; esac
}

arm_SURROGATE() {
  local h="$1"
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
}

arm_PROGFAULT() {
  local h="$1"
  # PROGFAULT: a compile error injected into the jq program (a copy of THIS hook, in the push
  # regex every call evaluates) makes jq exit non-zero on `echo hi`. That is a program fault, not
  # an unparseable payload: allow, with the fail-open line on stderr.
  local _pf="$MUT/core/hooks/ai-dlc-foreground-budget.sh"
  mkdir -p "$MUT/core/hooks"
  sed 's/def pushfirst: test("/def pushfirst: test("(/' "$h" > "$_pf"
  if cmp -s "$h" "$_pf"; then note PROGFAULT; else
    call "$_pf" "$REAL" - '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'; chk_rc
    [ "$DEC" = allow ] || note PROGFAULT
    case "$ERR_TXT" in *'jq pass'*'fail-open'*) ;; *) note PROGFAULT ;; esac
  fi
}

arm_NOJQ() {
  local h="$1"
  # NOJQ: jq absent -> allow with stderr, on an over-budget call jq-present DENIES (OVER).
  # /usr/bin/jq exists on macOS, so the in-process call runs under PATH=/var/empty, where `command -v jq` finds none.
  # Fed from a file, not a pipe: this path exits without reading stdin, and under pipefail a
  # writer that loses that race reports EPIPE as the call's status.
  bash_call 600000 false > "$WORK/nojq.json"
  ( PATH=/var/empty; export CLAUDE_PROJECT_DIR="$REAL"; fx_inproc "$HOOK"; fgb_main ) <"$WORK/nojq.json" >"$OUTF" 2>"$ERRF"
  [ "$?" -eq 0 ] || EXITBAD=1
  DEC="$(jq -r '.hookSpecificOutput.permissionDecision // empty' "$OUTF" 2>/dev/null)"
  [ -n "$DEC" ] || DEC=allow
  [ "$DEC" = allow ] || note NOJQ
  case "$(cat "$ERRF")" in *'jq not found'*'fail-open'*) ;; *) note NOJQ ;; esac
}

arm_PUSH() {
  local h="$1"
  call "$h" "$REAL" - "$(cmd_call 'git push -u origin HEAD' '')"; chk_rc
  [ "$DEC" = allow ] || note PUSH
  call "$h" "$REAL" - "$(cmd_call 'cd /x && git push' '')"; chk_rc
  [ "$DEC" = allow ] || note PUSH
  # The near-miss of the single-`&` chain: the `&` of a redirection is not one.
  call "$h" "$REAL" - "$(cmd_call 'git push -u origin HEAD 2>&1' '')"; chk_rc
  [ "$DEC" = allow ] || note PUSH
}

arm_PUSHNEAR() {
  local h="$1"
  call "$h" "$REAL" - "$(cmd_call 'echo git push' '')"; chk_rc
  [ "$DEC" = deny ] || note PUSHNEAR
  call "$h" "$REAL" - "$(cmd_call 'git log --grep=push' '')"; chk_rc
  [ "$DEC" = deny ] || note PUSHNEAR
}

arm_AGENT() {
  local h="$1"
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
  # A round-dispatcher's beat: the foreground wait-for-deliverable.sh call at 600000, with the
  # beat prefix and a real --dispatch, from a subagent (agent_id set) is allowed. Control: the same
  # payload with no agent_id is the lead's and is denied on budget.
  _wb='AI_DLC_WAIT_BEAT_SECS=540 scripts/ai-dlc/wait-for-deliverable.sh --complete --since 1700000000 --dispatch a0123456789abcdef _bmad-output/planning-artifacts/s1/shards/x-p1/1.md'
  call "$h" "$REAL" - "$(jq -nc --arg c "$_wb" --arg a a1b2c3 '{tool_name:"Bash", agent_id:$a, tool_input:{command:$c, timeout:600000, run_in_background:false}}')"; chk_rc
  [ "$DEC" = allow ] || note AGENT
  call "$h" "$REAL" - "$(jq -nc --arg c "$_wb" '{tool_name:"Bash", tool_input:{command:$c, timeout:600000, run_in_background:false}}')"; chk_rc
  [ "$DEC" = deny ] || note AGENT
}

arm_SUBPOLL() {
  local h="$1"
  # A subagent poll with no detector on disk reaches the budget read and fails open there; the
  # stderr proves it did (a poll that rode the agent_id exemption exits before it, silently).
  # Its decision is NODETECTOR's.
  call "$h" "$NONE" - "$(cmd_call 'sleep 200; tail f' 'a1b2c3')"; chk_rc
  case "$ERR_TXT" in *'validate-steering-budget.sh'*'fail-open'*) ;; *) note SUBPOLL ;; esac
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
  # The beat wrapped in a sleep loop is a poll again: the dispatcher exception is the bare call only.
  call "$h" "$REAL" - "$(cmd_call "until AI_DLC_WAIT_BEAT_SECS=540 $W --complete --dispatch a0123456789abcdef x.md; do sleep 5; done" 'a1b2c3')"; chk_rc
  [ "$DEC" = deny ] || note SUBPOLL
  # Its allow twins -- the loop backgrounded, at the budget, with no timeout, and a readiness
  # retry with no timeout -- sit in BG, BOUNDARY and NOTIMEOUT: those gates are shared with the
  # lead's arm, so the arm that owns each gate owns its poll twin too.
}

arm_WAITER() {
  local h="$1"
  # WAITER (Deny A): wait-for-deliverable.sh as a command word whose segment ends in a lone `&`.
  # Driven at 600000 from the lead, so a hook WITHOUT Deny A still denies on budget: the reason
  # is what discriminates -- it must name the waiter and its remedy, never the budget.
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
}

arm_WAITERNEAR() {
  local h="$1"
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
}

arm_SNAPWRITE() {
  local h="$1"
  # SNAPWRITE (Deny B): a shell or interpreter write of pipeline-snapshot.md. Driven at 600000,
  # so the reason discriminates as in WAITER.
  for _c in "sed -i '' 's/a/b/' $S" "sed -i 's/a/b/' $S" "sed -i.bak 's/a/b/' $S" \
            "sed --in-place 's/a/b/' $S" "perl -pi -e 's/a/b/' $S" \
            "echo x > $S" "echo x >> $S" "printf x >\"$S\"" "echo x | tee $S" "echo x | tee -a $S" \
            "cp /tmp/s.md $S" "mv /tmp/s.md $S" "cp /dev/null $S #'" "git checkout HEAD -- $S" "git restore $S" \
            "cp /dev/null $S 2>/dev/null" "cp x $S >/dev/null" "mv x $S 2>&1" "cp a $S 2>/dev/null; echo" \
            "cp a $S </dev/null" "cp a $S 1>&2" "cp -f a $S" "install -m 644 a $S" "ln -sf a $S" \
            "python3 -c \"open('$S','w').write('x')\"" \
            $'python3 - <<\'EOF\'\np=\''"$S"$'\'\nL=open(p).read()\nopen(p,\'w\').write(L)\nEOF' \
            $'python3 - <<\'EOF\'\nfrom pathlib import Path\np=Path(\''"$S"$'\')\np.write_text(\'x\')\nEOF' \
            "node -e \"fs.writeFileSync('$S','x')\"" \
            "S=$S; sed -i '' \"s/a/b/\" \"\$S\""; do
    call "$h" "$REAL" - "$(cmd_call "$_c" '')"; chk_rc
    [ "$DEC" = deny ] || note SNAPWRITE
    snap_reason_ok || note SNAPWRITE
    case "$REASON_TXT" in *'steering budget'*) note SNAPWRITE ;; esac
  done
}

# snap_reason_ok: the Deny B reason names the snapshot write, the sanctioned writer and an op
# (presence), and never routes the write to a file tool (the old remedy).
snap_reason_ok() {
  case "$REASON_TXT" in *'writes pipeline-snapshot.md'*'snapshot-update.sh'*'--line-replace'*'--row-replace'*) ;; *) return 1 ;; esac
  case "$REASON_TXT" in *'Edit tool'*|*'(or Write)'*) return 1 ;; esac
  return 0
}

arm_SNAPSKIP() {
  local h="$1"
  # SNAPSKIP (F3, the false refusal): ONE segment running snapshot-update.sh or the rotator, whose
  # ARGUMENT text reads as a write shape onto the snapshot. At 5000, so only Deny B could refuse.
  for _c in "bash scripts/ai-dlc/snapshot-update.sh --snapshot $S --activity 'fixed the > $S redirect'" \
            "bash scripts/ai-dlc/snapshot-update.sh --snapshot $S --open-item \"tee $S was used\"" \
            "AI_DLC_STATE_DIR=x bash scripts/ai-dlc/snapshot-update.sh --snapshot $S --activity 'perl -pi on $S'" \
            "scripts/ai-dlc/snapshot-update.sh --snapshot $S --activity 'echo y >> $S'" \
            "bash core/scripts/rotate-snapshot-archive.sh h.md --absorb $S --apply --note 'x > $S'" \
            "'scripts/ai-dlc/snapshot-update.sh' --snapshot $S --activity 'echo y > $S'" \
            "\"scripts/ai-dlc/snapshot-update.sh\" --snapshot $S --activity 'echo y > $S'" \
            "bash scripts/ai-dlc/snapshot-update.sh --snapshot $S --activity \"a\$'b\" --open-item 'tee $S'"; do
    call "$h" "$REAL" - "$(jq -nc --arg c "$_c" '{tool_name:"Bash", tool_input:{command:$c, timeout:5000}}')"; chk_rc
    [ "$DEC" = allow ] || note SNAPSKIP
  done
}

arm_SNAPCHAIN() {
  local h="$1"
  # SNAPCHAIN: the skip's deny twins. Each starts with the sanctioned writer, then writes the
  # snapshot by shell: chained, piped, backgrounded, on a new line, redirected, or inside a `$(...)`
  # or backtick argument, and a command word that only resembles the writer. Driven at 600000.
  for _c in "bash scripts/ai-dlc/snapshot-update.sh --activity x; sed -i '' 's/a/b/' $S" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity x && echo y > $S" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity x | tee $S" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity x & echo y > $S" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity x"$'\n'"echo y > $S" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity x > $S" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity \"\$(echo y > $S)\"" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity \"\`echo y > $S\`\"" \
            "bash x/not-snapshot-update.sh --activity 'echo y > $S'" \
            "bash scripts/ai-dlc/snapshot-update.sh.bak --activity 'echo y > $S'" \
            "'scripts/ai-dlc/snapshot-update.sh '; sed -i '' s/a/b/ $S #'" \
            "\"scripts/ai-dlc/snapshot-update.sh \"; sed -i '' s/a/b/ $S #\"" \
            "scripts/ai-dlc/snapshot-update.sh' '; sed -i '' s/a/b/ $S #'" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity \$'x\\''; sed -i '' s/a/b/ $S #'" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity \$'x\\''; cp /dev/null $S #'" \
            "bash scripts/ai-dlc/snapshot-update.sh --activity \$'x\\''; cp /dev/null $S 2>/dev/null #'"; do
    call "$h" "$REAL" - "$(cmd_call "$_c" '')"; chk_rc
    [ "$DEC" = deny ] || note SNAPCHAIN
    snap_reason_ok || note SNAPCHAIN
  done
}

arm_SNAPCASE() {
  local h="$1"
  # SNAPCASE (F4): a case variant of the snapshot name is the snapshot on a case-insensitive
  # filesystem. Driven at 600000; its allow twins (case variants of .bak and the history file)
  # are in SNAPREAD.
  for _c in "sed -i '' 's/a/b/' _bmad-output/Pipeline-Snapshot.md" \
            "echo x > _bmad-output/PIPELINE-SNAPSHOT.MD" \
            "p=_bmad-output/Pipeline-Snapshot.md; echo x > \"\$p\""; do
    call "$h" "$REAL" - "$(cmd_call "$_c" '')"; chk_rc
    [ "$DEC" = deny ] || note SNAPCASE
    case "$REASON_TXT" in *'writes pipeline-snapshot.md'*) ;; *) note SNAPCASE ;; esac
  done
}

arm_SNAPREAD() {
  local h="$1"
  # SNAPREAD: the allow twins -- reads, a copy FROM it, an append to the history file, a
  # read-only interpreter open, a script given the path -- within budget, so only Deny B could refuse.
  for _c in "cat $S" "grep -n x $S" "sed -n '1,5p' $S" "wc -l < $S" \
            "git add $S && git commit -m x" "git show HEAD:$S" "git diff -- $S" \
            "cp $S /tmp/s.md" "cp $S /tmp/s.md #c" "cp $S $S.bak" "echo x >> _bmad-output/pipeline-snapshot-history.md" \
            "cp $S /tmp/x 2>/dev/null" "cp $S.bak _bmad-output/pipeline-snapshot-history.md" \
            $'python3 - <<\'EOF\'\np=\''"$S"$'\'\nh=\'_bmad-output/pipeline-snapshot-history.md\'\nL=open(p).read()\nopen(h,\'a\').write(L)\nEOF' \
            "python3 -c \"print(open('$S').read())\"" "python3 -c \"print(open('$S','r').read())\"" \
            "grep x $S > /tmp/out.txt 2>&1" \
            "echo x > _bmad-output/Pipeline-Snapshot.md.bak" "echo x >> _bmad-output/PIPELINE-SNAPSHOT-HISTORY.md" \
            "scripts/ai-dlc/validate-artifact-budget.sh --only pipeline-snapshot.md 2>&1 | head" \
            "bash scripts/ai-dlc/render-x.sh --write $S"; do
    call "$h" "$REAL" - "$(jq -nc --arg c "$_c" '{tool_name:"Bash", tool_input:{command:$c, timeout:5000}}')"; chk_rc
    [ "$DEC" = allow ] || note SNAPREAD
  done
}

arm_SCOPE() {
  local h="$1"
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
    snap_reason_ok || note SCOPE
  done
}

arm_REGEXLIMIT() {
  local h="$1"
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
}

echo "foreground-budget-deny:"
printf '  hook      %s\n' "$HOOK"
printf '  detector  %s\n' "$DETECTOR"
printf 'HERMETIC-CONSUMED %s\n' "$HOOK"
printf 'HERMETIC-CONSUMED %s\n' "$DETECTOR"

# --- the shipped hook: every arm once ---------------------------------------------------------
[ -x "$HOOK" ] || bad "hook is not executable: $HOOK -- settings.json invokes it as a bare path"
sc_run "$HOOK" $ALL_UNITS
GOT="$SC_DEAD"
if [ -z "$GOT" ]; then
  ok "shipped hook passes every arm (OVER REASON PUSHCHAIN BG NOTIMEOUT BOUNDARY ENV DEFAULT NONBASH NODETECTOR UNPARSEABLE SURROGATE PROGFAULT NOJQ PUSH PUSHNEAR AGENT SUBPOLL WAITER WAITERNEAR SNAPWRITE SNAPREAD SNAPSKIP SNAPCHAIN SNAPCASE SCOPE REGEXLIMIT FAILOPEN EXIT)"
else
  bad "shipped hook fails arm(s): $GOT"
fi

# The SHIFT world is the only thing that separates "reads the detector's default" from "carries
# its own 120". Prove the two projects really do disagree on the default line.
if cmp -s "$REAL/scripts/ai-dlc/validate-steering-budget.sh" "$SHIFT/scripts/ai-dlc/validate-steering-budget.sh"; then
  bad "FIXTURE BROKEN: the SHIFT detector is byte-identical to the real one, so DEFAULT cannot discriminate"
fi

# --- the cli cells (cells.decl): the hook run as a PROGRAM once per distinct CLI outcome ---------------------------
# The hook always exits 0, so the outcomes are output classes: a deny on stdout (the budget reason), silence, silence
# with the fail-open line on stderr (no detector on disk), the printf-built parse-failure deny, and the jq-absent
# fail-open (PATH=/var/empty, /bin/bash by absolute path). One `FXCELL=<id> bash "$HOOK"` start per outcome, each
# compared with the in-process call on the same payload, project and environment: stdout, stderr and exit separately,
# byte for byte. A cell also asserts its own outcome (a positive conjunct, so two runs that both printed nothing
# cannot read as equivalent).
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <project> <budget|-> <nojq 0|1> <json> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1" proj="$2" bud="$3" nojq="$4"; printf '%s' "$5" > "$EQ/$id.in"
  ( if [ "$bud" = - ]; then unset AI_DLC_STEERING_BUDGET; else export AI_DLC_STEERING_BUDGET="$bud"; fi
    export CLAUDE_PROJECT_DIR="$proj"; [ "$nojq" = 0 ] || PATH=/var/empty
    fx_inproc "$HOOK"
    fgb_main ) < "$EQ/$id.in" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  if [ "$nojq" = 0 ]; then
    if [ "$bud" = - ]; then env -u AI_DLC_STEERING_BUDGET CLAUDE_PROJECT_DIR="$proj" FXCELL="$id" bash "$HOOK" < "$EQ/$id.in" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"
    else env AI_DLC_STEERING_BUDGET="$bud" CLAUDE_PROJECT_DIR="$proj" FXCELL="$id" bash "$HOOK" < "$EQ/$id.in" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; fi
  else
    if [ "$bud" = - ]; then env -u AI_DLC_STEERING_BUDGET PATH=/var/empty CLAUDE_PROJECT_DIR="$proj" FXCELL="$id" /bin/bash "$HOOK" < "$EQ/$id.in" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"
    else env AI_DLC_STEERING_BUDGET="$bud" PATH=/var/empty CLAUDE_PROJECT_DIR="$proj" FXCELL="$id" /bin/bash "$HOOK" < "$EQ/$id.in" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; fi
  fi
  echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
cellspec() { # <file> <spec>: `-` the file is empty, `~text` it contains text
  case "$2" in
    -)  [ ! -s "$1" ] ;;
    ~*) grep -qF -e "${2#\~}" "$1" ;;
    *)  return 1 ;;
  esac
}
cell() { # <id> <stdout spec> <stderr spec> <why> <eqv args...>
  local id="$1" op="$2" ep="$3" why="$4"; shift 4
  if eqv "$id" "$@" && [ "$(cat "$EQ/$id.cl.rc")" = 0 ] && cellspec "$EQ/$id.cl.out" "$op" && cellspec "$EQ/$id.cl.err" "$ep"; then
    ok "$id: $why: the program answers exactly as the in-process call does (stdout, stderr, exit 0)"
  else bad "$id: $why: the program and the in-process call differ, or the outcome is not the expected class ($(eq_twin "$id"))"; fi
}
echo "== cli cells"
cell cli-deny '~"permissionDecision": "deny"' - "a foreground call over the budget is denied" "$REAL" - 0 "$(bash_call 600000 false)"
cell cli-allow - - "a call run in the background is allowed in silence" "$REAL" - 0 "$(bash_call 600000 true)"
cell cli-failopen - '~fail-open' "no detector and no override: allowed, with the fail-open line" "$NONE" - 0 "$(bash_call 600000 false)"
cell cli-parsefail '~could not be parsed as JSON' - "a payload that does not parse is denied by the printf-built reason" "$REAL" - 0 '{"tool_name":"Bash","tool_input":{"command":"x","timeout":600000'
cell cli-nojq - '~jq not found' "jq absent: allowed, with the fail-open line" "$REAL" - 1 "$(bash_call 600000 false)"
if ! cmp -s "$EQ/cli-deny.cl.out" "$EQ/cli-allow.cl.out"; then
  ok "cli cells discriminate: the denying and the allowing call give different stdout"
else bad "cli cells do not discriminate: cli-deny and cli-allow gave the same stdout"; fi

printf '  hook invocations  %s\n' "$NCALL"

# Clean up by name: the seed's files and directories, never a recursive delete of a variable.
rm -f "$OUTF" "$ERRF" "$INF" "$EQ"/cli-* "$WORK/env.sh" "$WORK/nojq.json" "$MUT/core/hooks/ai-dlc-foreground-budget.sh" \
      "$REAL/scripts/ai-dlc/validate-steering-budget.sh" "$SHIFT/scripts/ai-dlc/validate-steering-budget.sh"
rmdir "$MUT/core/hooks" "$MUT/core" "$EQ" "$REAL/scripts/ai-dlc" "$REAL/scripts" "$REAL" "$SHIFT/scripts/ai-dlc" "$SHIFT/scripts" "$SHIFT" \
      "$NONE" "$MUT" "$WORK" 2>/dev/null

echo
report_end foreground-budget-deny
