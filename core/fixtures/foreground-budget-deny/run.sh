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
#   NODETECTOR  no env, no detector, timeout 600000 -> allow, and stderr says why
#   MALFORMED   unparseable stdin -> allow, and stderr says fail-open
#   PUSH        `git push -u origin HEAD`, `cd /x && git push` and `git push -u origin HEAD 2>&1`
#               (the `&` of a redirection is not a chain), foreground at 600000 -> allow
#               (the pipeline requires a foreground push at that timeout)
#   PUSHNEAR    `echo git push` and `git log --grep=push` at 600000 -> deny
#   AGENT       a payload carrying `agent_id`, 600000 -> allow; the same payload without it
#               -> deny (Check A never counts a sidechain call)
#   EXIT        every call above exits 0
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

  call "$h" "$REAL" - "$(bash_call null false)"; chk_rc
  [ "$DEC" = allow ] || note NOTIMEOUT

  call "$h" "$REAL" - "$(bash_call 120000 false)"; chk_rc
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

  call "$h" "$REAL" - '{"tool_name":"Bash","tool_input":{"command":"x","timeout":600000'; chk_rc
  [ "$DEC" = allow ] || note MALFORMED
  case "$ERR_TXT" in *'not readable JSON'*'fail-open'*) ;; *) note MALFORMED ;; esac

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

  call "$h" "$REAL" - "$(cmd_call 'bash scripts/ai-dlc/ci-local.sh' 'a1b2c3')"; chk_rc
  [ "$DEC" = allow ] || note AGENT
  call "$h" "$REAL" - "$(cmd_call 'bash scripts/ai-dlc/ci-local.sh' '')"; chk_rc
  [ "$DEC" = deny ] || note AGENT

  [ "$exitbad" -eq 0 ] || note EXIT
  printf '%s\n' "$failed" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'
}

echo "foreground-budget-deny:"
printf '  hook      %s\n' "$HOOK"
printf '  detector  %s\n' "$DETECTOR"

# --- the shipped hook ----------------------------------------------------------------------
[ -x "$HOOK" ] || bad "hook is not executable: $HOOK -- settings.json invokes it as a bare path"
GOT="$(score "$HOOK")"
if [ -z "$GOT" ]; then
  ok "shipped hook passes every arm (OVER REASON PUSHCHAIN BG NOTIMEOUT BOUNDARY ENV DEFAULT NONBASH NODETECTOR MALFORMED PUSH PUSHNEAR AGENT EXIT)"
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
# holding a deny cell; each of the other fourteen fails its own arm alone.
# 1. warning-only: the same text as context, no decision. The rejected design.
mut warn-only "AGENT BOUNDARY DEFAULT ENV OVER PUSHCHAIN PUSHNEAR REASON" \
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
  -e 's/then \.tool_input\.timeout | if/then (.tool_input.timeout \/\/ 600000) | if/'
# 8. malformed input allowed silently.
mut silent-malformed "MALFORMED" -e '/not readable JSON/d'
# 9. no detector: fall back to a literal and deny.
mut no-detector-literal "NODETECTOR" -e 's/allowing it (fail-open)"; exit 0$/allowing it (fail-open)"; B=120; SRC=\/dev\/null/'
# 10. the reason stops naming the background re-issue.
mut reason-drops-background "REASON" -e 's/Re-issue the same call with run_in_background: true and collect its result when it completes, or/Re-issue it with a shorter timeout, or/'
# 11. the deny path exits non-zero.
mut deny-exits-nonzero "EXIT" -e '$s/^exit 0$/exit 2/'
# 12. the whole subject replaced by silence: every presence-shaped arm must fail.
mut silence "AGENT BOUNDARY DEFAULT ENV MALFORMED NODETECTOR OVER PUSHCHAIN PUSHNEAR REASON" -e '2i\
exit 0'
# 13. no push allowance: the pipeline's required foreground push is denied.
mut drop-push "PUSH" -e '/and (is_push | not)/d'
# 14. the push match loses its start anchor, so `echo git push` rides the exemption.
mut push-unanchored "PUSHNEAR" -e 's/test("^\[ \\t\]\*(cd/test("(cd/'
# 15. no agent_id exit: a teammate's call is denied though Check A never counts it.
mut drop-agent "AGENT" -e '/and ((\.agent_id \/\/ "") | tostring) == ""/d'
# 16. the PUSHCHAIN field dropped: a chained push gets the general reason, run_in_background and all.
mut drop-pushchain "PUSHCHAIN" -e 's/^PUSHCHAIN="\${T##\* }"$/PUSHCHAIN=0/'

[ "$n_mut" -gt 0 ] && [ "$n_kill" -eq "$n_mut" ] \
  && ok "$n_kill of $n_mut mutants killed" \
  || bad "$n_kill of $n_mut mutants killed"

# Clean up by name: the seed's files and directories, never a recursive delete of a variable.
rm -f "$OUTF" "$ERRF" "$WORK/env.sh" "$MUT"/hook-*.sh \
      "$REAL/scripts/ai-dlc/validate-steering-budget.sh" "$SHIFT/scripts/ai-dlc/validate-steering-budget.sh"
rmdir "$REAL/scripts/ai-dlc" "$REAL/scripts" "$REAL" "$SHIFT/scripts/ai-dlc" "$SHIFT/scripts" "$SHIFT" \
      "$NONE" "$MUT" "$WORK" 2>/dev/null

echo
if [ "$fails" -eq 0 ]; then echo "foreground-budget-deny: PASS"; exit 0; fi
echo "foreground-budget-deny: $fails assertion(s) FAILED" >&2
exit 1
