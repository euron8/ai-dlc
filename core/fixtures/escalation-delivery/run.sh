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
#
# Usage: run.sh
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking the hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HOOK="$(pick "$HERE/../../hooks/ai-dlc-escalation-delivery.sh" \
             "$HERE/../../../.claude/hooks/ai-dlc-escalation-delivery.sh" \
             "$HERE/../../../core/hooks/ai-dlc-escalation-delivery.sh")"
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-escalation-delivery.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED $(cd "$(dirname "$HOOK")" && pwd)/${HOOK##*/}"

command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: escalation-delivery needs jq and it is not on PATH -- a SKIP here would record a pass over an unrun fixture" >&2; exit 2; }

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# IN PROCESS (BL-878). The hook is SOURCED once into this shell (its guard returns after defining esd_main), and every
# drive pipes its payload into esd_main inside a `( )` subshell with CLAUDE_PROJECT_DIR exported there, which is what
# `printf | CLAUDE_PROJECT_DIR=w bash HOOK` gave the program: the same stdin, the same environment, and the hook's
# `set -u`, assignments and `exit` stay in that subshell.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a hook with neither the `esd_main() {` line nor the column-0 source guard
# predates the wrap and reads SKIP (exit 0, never an ok); exactly one half is a respelled hook and FAILs. The
# distribution cannot reach the SKIP unnoticed: C5 (validate-fixture-inprocess.sh) refuses a cli subject without the
# guard, and J3 refuses the start count moving.
# A hook grep cannot READ (exit 2) is no pre-wrap hook: it is FIXTURE ERROR, never the SKIP.
w_def=0; w_guard=0
grep -q '^esd_main() {$' "$HOOK"; g_def=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$HOOK"; g_guard=$?
if [ "$g_def" -gt 1 ] || [ "$g_guard" -gt 1 ]; then echo "FIXTURE ERROR: cannot read $HOOK (grep exit $g_def/$g_guard), so the in-process wrap cannot be judged; nothing was asserted" >&2; exit 2; fi
[ "$g_def" = 0 ] && w_def=1; [ "$g_guard" = 0 ] && w_guard=1
if [ "$w_def$w_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$w_def" = 0 ]; then bad "$HOOK carries the column-0 source guard but no \`esd_main() {\` line -- a respelled hook this fixture cannot drive"; echo "escalation-delivery: $fails assertion(s) FAILED" >&2; exit 1; fi
if [ "$w_guard" = 0 ]; then bad "$HOOK defines \`esd_main() {\` but carries no column-0 source guard -- a respelled hook; sourcing it would run esd_main in this shell"; echo "escalation-delivery: $fails assertion(s) FAILED" >&2; exit 1; fi
fx_inproc "$HOOK"
. "$HOOK" || { echo "FIXTURE BROKEN: sourcing $HOOK failed" >&2; exit 2; }
declare -F esd_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $HOOK defined no esd_main" >&2; exit 2; }

LOG='_bmad-output/pipeline-continuation-log.md'
# One event is one `## <timestamp> -- <EVENT>` line. A bare token grep also matches the
# legend, which names every event type — the log's own header says so, and it is how a
# sibling fixture's arm once passed with the detector switched off.
events() { sed -n 's/^## [^ ]* -- //p' "$1/$LOG" 2>/dev/null | grep -c '^ESCALATION_UNDELIVERED$'; }
entry()  { sed -n '/^## [^ ]* -- ESCALATION_UNDELIVERED$/,/^$/p' "$1/$LOG" 2>/dev/null; }

drive() { # <payload-json> -> work dir on stdout
  local w; w="$(mktemp -d "${TMPDIR:-/tmp}/esc-deliv-XXXXXX")"
  mkdir -p "$w/_bmad-output"
  printf '%s' "$1" | ( set +o pipefail; export CLAUDE_PROJECT_DIR="$w"; esd_main ) >/dev/null 2>&1
  printf '%s\n' "$w"
}

echo "escalation-delivery:"

# =============================================================================
# 1. THE OFFENDER — the exact sprint-305 failure, verbatim from the transcript.
# =============================================================================
P_FAIL='{"session_id":"s1","tool_name":"SendMessage","tool_input":{"to":"graph-6b","message":"decision needed"},"tool_response":{"success":false,"message":"No agent named '"'"'graph-6b'"'"' is reachable.\nUse ListAgents to see everyone you can message.","display":""}}'
W="$(drive "$P_FAIL")"
if [ "$(events "$W")" -ge 1 ]; then ok "undelivered SendMessage: ESCALATION_UNDELIVERED is logged (the failure leaves an artifact)";
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
  if [ "$(events "$W")" -eq 0 ]; then
    ok "$name: no event (an unrecognized response shape does not manufacture a report)"
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
# 5b. THE CLI CELLS (cells.decl): the hook run as a PROGRAM once per distinct outcome.
# =============================================================================
# Every path exits 0 with nothing on stdout, so the outcome is what the hook LEAVES: an ESCALATION_UNDELIVERED entry
# (a failed send) or no log at all (a delivered one). One `FXCELL=<id> bash "$HOOK"` start per outcome, its payload
# piped on stdin exactly as drive() pipes it into esd_main, compared with the in-process call on the same payload:
# stdout, stderr, exit and the log, byte for byte, with only the entry's `## <UTC second> --` stamp normalised (the two
# calls need not land in the same second). Each cell asserts its own outcome too, and the two must differ.
EQ="$(mktemp -d "${TMPDIR:-/tmp}/esc-eq-XXXXXX")"
eqv() { # <cell-id> <payload> -> $EQ/<id>.{ip,cl}.{out,err,rc,log}
  local id="$1" p="$2" s
  mkdir -p "$EQ/$id.ip.w/_bmad-output" "$EQ/$id.cl.w/_bmad-output"
  printf '%s' "$p" | ( set +o pipefail; export CLAUDE_PROJECT_DIR="$EQ/$id.ip.w"; esd_main ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  printf '%s' "$p" | CLAUDE_PROJECT_DIR="$EQ/$id.cl.w" FXCELL="$id" bash "$HOOK" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  for s in ip cl; do
    if [ -f "$EQ/$id.$s.w/$LOG" ]; then sed 's/^## [0-9TZ:-]* -- /## <stamp> -- /' "$EQ/$id.$s.w/$LOG" > "$EQ/$id.$s.log"
    else echo "<no log>" > "$EQ/$id.$s.log"; fi
  done
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc" \
    && cmp -s "$EQ/$id.ip.log" "$EQ/$id.cl.log"
}
if eqv cli-event "$P_FAIL" && [ "$(cat "$EQ/cli-event.cl.rc")" = 0 ] && [ ! -s "$EQ/cli-event.cl.out" ] \
   && [ "$(events "$EQ/cli-event.cl.w")" -eq 1 ] && grep -q 'Intended recipient: graph-6b' "$EQ/cli-event.cl.log"; then
  ok "cli-event: the program logs the undelivered send exactly as the in-process call does (stdout, stderr, exit 0, log)"
else bad "cli-event: the program and the in-process call differ, or the program logged no ESCALATION_UNDELIVERED entry (rc=$(cat "$EQ/cli-event.cl.rc")/$(cat "$EQ/cli-event.ip.rc"))"; fi
if eqv cli-silent "$P_OK" && [ "$(cat "$EQ/cli-silent.cl.rc")" = 0 ] && [ ! -s "$EQ/cli-silent.cl.out" ] \
   && [ "$(cat "$EQ/cli-silent.cl.log")" = "<no log>" ]; then
  ok "cli-silent: the program leaves no log for a delivered send exactly as the in-process call does (stdout, stderr, exit 0, log)"
else bad "cli-silent: the program and the in-process call differ, or the program wrote a log for a delivered send (rc=$(cat "$EQ/cli-silent.cl.rc")/$(cat "$EQ/cli-silent.ip.rc"))"; fi
if ! cmp -s "$EQ/cli-event.cl.log" "$EQ/cli-silent.cl.log"; then
  ok "cli cells discriminate: the failed and the delivered send leave different logs"
else bad "cli cells do not discriminate: cli-event and cli-silent left the same log"; fi
rm -rf "$EQ"

echo
report_end escalation-delivery 13
