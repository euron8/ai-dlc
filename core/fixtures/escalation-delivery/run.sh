#!/usr/bin/env bash
# escalation-delivery — a SendMessage that did not arrive must leave an artifact.
#
# THE DEFECT THIS ADDRESSES. `SendMessage` to a session that is gone REPORTS SUCCESS AT
# THE TOOL LEVEL and returns a body saying it failed. Measured across 1141 real results:
# 1123 `success:true`, 18 `success:false`, and `is_error` ABSENT ON ALL EIGHTEEN. So
# `PostToolUseFailure` never fires, an error-flag sensor reads clean forever, and on the
# reference consumer's sprint 305 the operator's designated channel was dead for three
# consecutive sessions with nothing anywhere recording it.
#
# THE TRAP THIS FIXTURE EXISTS TO AVOID. The tempting sensor is the tool-error flag, and
# it is DEAD — it is absent on every one of the eighteen. An arm keyed on it would report
# a clean run forever over a corpus made entirely of failures. So the offender arm asserts
# the EVENT LINE APPEARS, never merely that the hook exited 0, which an early exit and a
# crash both satisfy.
#
# EVERY PAYLOAD BELOW IS REAL, lifted from session transcripts rather than composed from
# the hook's own accept-set. A seed derived from what the reader accepts proves only that
# the reader accepts its own grammar.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking the hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HOOK="$(pick "$HERE/../../hooks/ai-dlc-escalation-delivery.sh" \
             "$HERE/../../../.claude/hooks/ai-dlc-escalation-delivery.sh" \
             "$HERE/../../../core/hooks/ai-dlc-escalation-delivery.sh")"
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-escalation-delivery.sh" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "escalation-delivery: SKIP (no jq)"; exit 0; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

LOG='_bmad-output/pipeline-continuation-log.md'
# One event is one `## <timestamp> -- <EVENT>` line. A bare token grep also matches the
# legend, which names every event type — the log's own header says so, and it is how a
# sibling fixture's arm once passed with the detector switched off.
events() { sed -n 's/^## [^ ]* -- //p' "$1/$LOG" 2>/dev/null | grep -c '^ESCALATION_UNDELIVERED$'; }
entry()  { sed -n '/^## [^ ]* -- ESCALATION_UNDELIVERED$/,/^$/p' "$1/$LOG" 2>/dev/null; }

drive() { # <payload-json> -> work dir on stdout
  local w; w="$(mktemp -d "${TMPDIR:-/tmp}/esc-deliv-XXXXXX")"
  mkdir -p "$w/_bmad-output"
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$w" bash "$HOOK" >/dev/null 2>&1
  printf '%s\n' "$w"
}

echo "escalation-delivery:"

# =============================================================================
# 1. THE OFFENDER — the exact sprint-305 failure, verbatim from the transcript.
# =============================================================================
P_FAIL='{"session_id":"s1","tool_name":"SendMessage","tool_input":{"to":"graph-6b","message":"decision needed"},"tool_response":{"success":false,"message":"No agent named '"'"'graph-6b'"'"' is reachable.\nUse ListAgents to see everyone you can message.","display":""}}'
W="$(drive "$P_FAIL")"
if [ "$(events "$W")" -ge 1 ]; then ok "undelivered SendMessage: ESCALATION_UNDELIVERED is logged (the failure leaves an artifact)"
else bad "undelivered SendMessage: NO event line — a dead escalation channel is silent again"; fi
# Command substitution + here-string, never `entry | grep -q` — I54/I54b. `grep -q` leaves at
# its first match while the writer is still pushing, and under the `pipefail` this file sets
# the pipeline then answers with the writer's EPIPE and reports NOT-FOUND on input that
# contains the pattern. A size threshold, not a race.
ENTRY="$(entry "$W")"
if grep -q 'graph-6b' <<< "$ENTRY"; then ok "...and the entry names the intended recipient, so a reader can tell an escalation from subagent routing"
else bad "the entry does not name the recipient — the false-positive classes cannot be separated by reading"; fi
if grep -q 'did NOT error' <<< "$ENTRY"; then ok "...and records that the tool call itself did not error (why an error-flag sensor is blind here)"
else bad "the entry omits the not-an-error note, which is the whole reason this hook exists"; fi
rm -rf "$W"

# =============================================================================
# 2. THE NEAR-MISS — a DELIVERED message. Same tool, same shape, success true.
# =============================================================================
# Differs from arm 1 in ONE field. Without this pairing an arm that logged every
# SendMessage would read exactly like one that discriminates.
P_OK='{"session_id":"s1","tool_name":"SendMessage","tool_input":{"to":"adversary","message":"go"},"tool_response":{"success":true,"message":"Message sent to adversary'"'"'s inbox","msg_id":"07689104","routing":{}}}'
W="$(drive "$P_OK")"
if [ "$(events "$W")" -eq 0 ]; then ok "delivered SendMessage: no event (a successful send is not an escalation failure)"
else bad "delivered SendMessage: logged ESCALATION_UNDELIVERED — every send would be reported as a failure"; fi
rm -rf "$W"

# =============================================================================
# 3. FAIL-SAFE — a shape the hook has never seen must produce SILENCE, not a verdict.
# =============================================================================
# The subject is a LOG, not a gate, so inventing an escalation report out of a harness
# change is the worse direction. `false` only; absent/null/non-boolean stays quiet.
for c in 'no-success:{"success_absent":true}' 'null-success:{"success":null}' 'string-success:{"success":"false"}'; do
  name="${c%%:*}"; body="${c#*:}"
  W="$(drive "{\"session_id\":\"s1\",\"tool_name\":\"SendMessage\",\"tool_input\":{\"to\":\"x\"},\"tool_response\":$body}")"
  if [ "$(events "$W")" -eq 0 ]; then ok "$name: no event (an unrecognized response shape does not manufacture a report)"
  else bad "$name: logged an event from a response shape that never said it failed"; fi
  rm -rf "$W"
done

# =============================================================================
# 4. GATING — the hook is scoped to SendMessage and ignores every other tool.
# =============================================================================
W="$(drive '{"session_id":"s1","tool_name":"Bash","tool_input":{},"tool_response":{"success":false,"message":"exit 1"}}')"
if [ "$(events "$W")" -eq 0 ]; then ok "other tool: a failing Bash is not an undelivered escalation"
else bad "other tool: a failing Bash was logged as ESCALATION_UNDELIVERED — the matcher is not load-bearing"; fi
rm -rf "$W"

# =============================================================================
# 5. THE LEGEND EXPLAINS THE EVENT THIS HOOK EMITS.
# =============================================================================
# A count is read against the legend and nothing else. `pause-hook-origin` assertion 8
# binds all FOUR seeding hooks byte-identically; this arm checks the event is actually IN
# the body, which agreement alone does not establish — four identical legends that all
# omit it agree perfectly.
W="$(drive "$P_FAIL")"
if grep -q '^- `ESCALATION_UNDELIVERED`:' "$W/$LOG" 2>/dev/null; then
  ok "the log's event-type legend documents ESCALATION_UNDELIVERED"
else
  bad "ESCALATION_UNDELIVERED entries are written into a log whose legend never mentions them"
fi
if grep -q 'a failure to reach `parent` is subagent routing' "$W/$LOG" 2>/dev/null; then
  ok "...and the legend states the measured false-positive class, where the count is read"
else
  bad "the legend does not name the false-positive class; a retro would read the count as all-escalations"
fi
rm -rf "$W"

# =============================================================================
# 6. MUTATION BATTERY — the absence-shaped arms above must be shown to discriminate.
# =============================================================================
# ARMS 2, 3 AND 4 ASSERT A ZERO. Every one of them passes against a hook replaced by
# `exit 0`, because "no event" is exactly what a program that never ran produces. A
# both-directions seed shows an arm separates two inputs; only a mutant shows it is
# reading the subject at all. Each mutant is a COPY, guarded with `cmp -s` so an edit
# that matched nothing cannot pass as a mutation, and the resolved path is printed.
#
# M2 IS THE DEFECT THIS HOOK ACTUALLY SHIPPED WITH. `jq`'s alternative operator treats
# `false` as absent, so `.tool_response.success // empty` yields nothing on the one input
# the hook exists for. It was written that way, and arm 1 is what caught it.
#
# NOT RE-ENTERED BY THE MUTANT RUNS. Each mutant drives THIS SAME SCRIPT, so without this
# guard the inner run executes the battery too: its failures are counted by the outer one
# and every expected kill count is inflated (measured: 9 and 4 instead of 1 and 1). The
# battery is the one section that must not recurse.
#
# THE SENTINEL IS A FILE, NOT AN ENV VAR, and that is not a style choice: the hermetic loop
# at the top of this script unsets every `AI_DLC_*` variable before anything reads one, so
# an env-var guard is erased by this fixture's own first action. Measured — the guard was
# written that way first and changed nothing.
if [ -e "$HERE/.no-battery" ]; then
  :
else
# `$MB/fixtures/escalation-delivery/run.sh` resolves `$HERE/../../hooks/...` to
# `$MB/hooks/`, so the copy the run LOADS is the copy this battery mutates. Mutating a file
# the run never opens leaves every arm green and reads exactly like an arm that cannot fire.
MB="$(mktemp -d "${TMPDIR:-/tmp}/esc-mut-XXXXXX")"
mkdir -p "$MB/hooks" "$MB/fixtures/escalation-delivery"
cp "$HERE/run.sh" "$MB/fixtures/escalation-delivery/run.sh"
touch "$MB/fixtures/escalation-delivery/.no-battery"
kills=0; expected=0

mutate() { # <name> <sed-program> ; builds $MB/hooks/<name>.sh from the resolved hook
  sed "$2" "$HOOK" > "$MB/hooks/$1.sh"
  cmp -s "$HOOK" "$MB/hooks/$1.sh" && return 1
  return 0
}
run_mutant() { # <name> <expected-kills> <what it proves>
  local name="$1" want="$2" what="$3" got
  expected=$((expected+1))
  cp "$MB/hooks/$name.sh" "$MB/hooks/ai-dlc-escalation-delivery.sh"
  got=$(bash "$MB/fixtures/escalation-delivery/run.sh" 2>&1 | grep -c '^  FAIL')
  if [ "$got" -eq "$want" ]; then
    kills=$((kills+1)); ok "mutant $name: killed $got arm(s) as expected — $what"
  else
    bad "MUTANT $name KILLED $got ARMS, EXPECTED $want — $what is not what the arm is reading"
  fi
}

# TYPE-LOOSE, NOT NEVER-FIRES. The first version of this mutation replaced the whole jq
# expression with `tostring`, which left the `= "true"` comparison below it — so the hook
# stopped firing at all and killed SIX arms, scoring as a broken subject rather than as the
# one property under test. The mutation has to keep the predicate shape and widen only what
# it accepts.
if mutate typestrict 's@== false)@== false or .tool_response.success == "false")@'; then
  printf '        mutant typestrict edits: %s\n' "$MB/hooks/typestrict.sh"
  run_mutant typestrict 1 "the string \"false\" must not count as a failed send"
else
  bad "FIXTURE STALE: the type-strictness mutation matched nothing — the jq comparison was reworded"
fi
if mutate toolgate 's|\[ "\$TOOL_NAME" = "SendMessage" \]|[ -n "$TOOL_NAME" ]|'; then
  printf '        mutant toolgate edits: %s\n' "$MB/hooks/toolgate.sh"
  run_mutant toolgate 1 "the SendMessage matcher must be load-bearing"
else
  bad "FIXTURE STALE: the tool-name mutation matched nothing — the gate was reworded"
fi

if [ "$kills" -eq "$expected" ] && [ "$expected" -ge 2 ]; then
  ok "mutation battery: $kills of $expected mutants killed exactly their own arm"
else
  bad "MUTATION BATTERY KILLED $kills OF $expected — a mutant that killed nothing reads exactly like an arm that cannot fire"
fi
rm -rf "$MB"
fi

echo
if [ "$fails" -eq 0 ]; then echo "escalation-delivery: PASS"; exit 0; fi
echo "escalation-delivery: $fails assertion(s) FAILED" >&2
exit 1
