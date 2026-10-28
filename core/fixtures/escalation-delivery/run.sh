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
# Usage: run.sh [--matrix]
#
# THE MUTANT MATRIX (mutant-battery rule). Each mutant drives one inner run of this script, and that run already
# executes every arm, so the matrix is read from it at no extra cost: an arm is KILLED under a mutant when the
# inner run prints that arm's FAIL line, GREEN when it does not. PER PUSH a mutant's DECIDING arm and its named
# TWIN are asserted and nothing else; with --matrix every arm is read and printed as one
# `MATRIX <mutant> <arm> KILLED|GREEN` row per pair. The block below is the one source; a plain run refuses a
# mutant with no row, and a cell that disagrees with its row is a failure. Arm tokens (slug of the FAIL line):
# offender recipient errnote delivered nosuccess nullsuccess stringsuccess othertool legend legendfp
# RE-MEASURE whenever an arm or a mutant is added or changed. hermetic-run.sh runs a fixture under `env -i` and
# forwards no argument, so the matrix is NOT reached through it; run.sh is invoked directly from the repo root.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/escalation-delivery/run.sh --matrix
# MUTANT-MATRIX typestrict decides=stringsuccess twins=nullsuccess
# MUTANT-MATRIX toolgate decides=othertool twins=offender
# A MATRIX row is a measurement and not a second kill emission: its kill goes through mutant_killed behind the
# base-pass flag of the cell's own arm. Mutant names reach mutant_killed as variables in two helpers:
# MUTANT-MATRIX-DYNAMIC run_mutant why=passes each of the two mutant names typestrict and toolgate as a variable and every name keeps its own row
# MUTANT-MATRIX-DYNAMIC mx_cell why=passes each of the two mutant names typestrict and toolgate as a variable and every name keeps its own row
set -uo pipefail
MATRIX=0
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (only --matrix)" >&2; exit 2 ;;
  esac
done

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
if [ "$(events "$W")" -ge 1 ]; then ok "undelivered SendMessage: ESCALATION_UNDELIVERED is logged (the failure leaves an artifact)"; B_offender=1
else bad "undelivered SendMessage: NO event line — a dead escalation channel is silent again"; fi
# Command substitution + here-string, never `entry | grep -q` — I54/I54b. `grep -q` leaves at
# its first match while the writer is still pushing, and under the `pipefail` this file sets
# the pipeline then answers with the writer's EPIPE and reports NOT-FOUND on input that
# contains the pattern. A size threshold, not a race.
ENTRY="$(entry "$W")"
if grep -q 'graph-6b' <<< "$ENTRY"; then ok "...and the entry names the intended recipient, so a reader can tell an escalation from subagent routing"; B_recipient=1
else bad "the entry does not name the recipient — the false-positive classes cannot be separated by reading"; fi
if grep -q 'did NOT error' <<< "$ENTRY"; then ok "...and records that the tool call itself did not error (why an error-flag sensor is blind here)"; B_errnote=1
else bad "the entry omits the not-an-error note, which is the whole reason this hook exists"; fi
rm -rf "$W"

# =============================================================================
# 2. THE NEAR-MISS — a DELIVERED message. Same tool, same shape, success true.
# =============================================================================
# Differs from arm 1 in ONE field. Without this pairing an arm that logged every
# SendMessage would read exactly like one that discriminates.
P_OK='{"session_id":"s1","tool_name":"SendMessage","tool_input":{"to":"adversary","message":"go"},"tool_response":{"success":true,"message":"Message sent to adversary'"'"'s inbox","msg_id":"07689104","routing":{}}}'
W="$(drive "$P_OK")"
if [ "$(events "$W")" -eq 0 ]; then ok "delivered SendMessage: no event (a successful send is not an escalation failure)"; B_delivered=1
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
    case "$name" in string-success) B_fs_string=1 ;; no-success) B_nosuccess=1 ;; null-success) B_nullsuccess=1 ;; esac
  else bad "$name: logged an event from a response shape that never said it failed"; fi
  rm -rf "$W"
done

# =============================================================================
# 4. GATING — the hook is scoped to SendMessage and ignores every other tool.
# =============================================================================
W="$(drive '{"session_id":"s1","tool_name":"Bash","tool_input":{},"tool_response":{"success":false,"message":"exit 1"}}')"
if [ "$(events "$W")" -eq 0 ]; then ok "other tool: a failing Bash is not an undelivered escalation"; B_toolgate=1
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
  ok "the log's event-type legend documents ESCALATION_UNDELIVERED"; B_legend=1
else
  bad "ESCALATION_UNDELIVERED entries are written into a log whose legend never mentions them"
fi
if grep -q 'a failure to reach `parent` is subagent routing' "$W/$LOG" 2>/dev/null; then
  ok "...and the legend states the measured false-positive class, where the count is read"; B_legendfp=1
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
# Sourced HERE, past the .no-battery check: the inner runs execute a copy of this script under $MB, where
# ../lib/mutant.sh does not exist, and they never score a mutant.
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
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
run_mutant() { # <name> <expected-failed-arms> <what it proves> <base-pass flag>
  local name="$1" want="$2" what="$3" got
  expected=$((expected+1))
  cp "$MB/hooks/$name.sh" "$MB/hooks/ai-dlc-escalation-delivery.sh"
  bash "$MB/fixtures/escalation-delivery/run.sh" > "$MB/out.$name" 2>&1
  got=$(grep -c '^  FAIL' "$MB/out.$name")
  if [ "$got" -eq "$want" ]; then
    mutant_killed "$4" "$name" "mutant $name: failed $got arm(s) as expected — $what" && kills=$((kills+1))
  else
    bad "MUTANT $name SURVIVED: it failed $got arm(s), expected $want — $what is not what the arm is reading"
  fi
  mx_all "$name"
}

# --- the matrix, read off the inner run's FAIL lines (no extra run) ----------------------------
MX_SRC="$HERE/run.sh"; MX_CELLS=0; MX_RUN=0; MX_SEEN=""
mx_row() { grep -m 1 -F -- "# MUTANT-MATRIX $1 decides=" "$MX_SRC"; } # the tool farm of this fixture declares no awk
mx_role() { # <mutant> <arm> -> D (decides), T (twin) or - (neither), read from the header block
  local line d tw; line="$(mx_row "$1")"
  [ -n "$line" ] || { echo -; return; }
  d="${line#*decides=}"; d="${d%% *}"; tw="${line#*twins=}"; tw="${tw%% *}"
  case ",$d," in *",$2,"*) echo D; return ;; esac
  case ",$tw," in *",$2,"*) echo T; return ;; esac
  echo -
}
mx_has_row() { [ -n "$(mx_row "$1")" ]; }
arm_pat() { # <arm> -> the text its bad() line carries
  case "$1" in
    offender) echo "NO event line" ;;
    recipient) echo "does not name the recipient" ;;
    errnote) echo "omits the not-an-error note" ;;
    delivered) echo "delivered SendMessage: logged" ;;
    nosuccess) echo "no-success: logged" ;;
    nullsuccess) echo "null-success: logged" ;;
    stringsuccess) echo "string-success: logged" ;;
    othertool) echo "other tool: a failing Bash was logged" ;;
    legend) echo "whose legend never mentions them" ;;
    legendfp) echo "does not name the false-positive class" ;;
  esac
}
# mx_cell <mutant> <arm> <the arm's base-pass flag>
mx_cell() {
  local m="$1" t="$2" fl="$3" role v
  case " $MX_SEEN " in
    *" $m "*) ;;
    *) MX_SEEN="$MX_SEEN $m"
       if ! mx_has_row "$m"; then bad "mutant $m has no MUTANT-MATRIX row in $MX_SRC -- a per-push run cannot know its deciding arm or its twins"; fi ;;
  esac
  role="$(mx_role "$m" "$t")"
  if [ "$MATRIX" != 1 ] && [ "$role" = - ]; then return 0; fi
  [ "$role" = - ] && MX_CELLS=$((MX_CELLS + 1))
  MX_RUN=$((MX_RUN + 1))
  fl_lines="$(grep '^  FAIL' "$MB/out.$m")"
  if grep -qF -- "$(arm_pat "$t")" <<<"$fl_lines"; then
    mutant_killed "$fl" "$m" "MATRIX $m $t KILLED"
    if [ "$MATRIX" != 1 ] && [ "$role" = T ]; then bad "mutant $m failed arm $t, which the header names as its twin"; fi
  else
    v=GREEN; ok "MATRIX $m $t $v"
    if [ "$MATRIX" != 1 ] && [ "$role" = D ]; then bad "mutant $m SURVIVED its deciding arm $t"; fi
  fi
}
mx_all() { # <mutant>
  mx_cell "$1" offender      "${B_offender:-0}"
  mx_cell "$1" recipient     "${B_recipient:-0}"
  mx_cell "$1" errnote       "${B_errnote:-0}"
  mx_cell "$1" delivered     "${B_delivered:-0}"
  mx_cell "$1" nosuccess     "${B_nosuccess:-0}"
  mx_cell "$1" nullsuccess   "${B_nullsuccess:-0}"
  mx_cell "$1" stringsuccess "${B_fs_string:-0}"
  mx_cell "$1" othertool     "${B_toolgate:-0}"
  mx_cell "$1" legend        "${B_legend:-0}"
  mx_cell "$1" legendfp      "${B_legendfp:-0}"
}

# TYPE-LOOSE, NOT NEVER-FIRES. The first version of this mutation replaced the whole jq
# expression with `tostring`, which left the `= "true"` comparison below it — so the hook
# stopped firing at all and killed SIX arms, scoring as a broken subject rather than as the
# one property under test. The mutation has to keep the predicate shape and widen only what
# it accepts.
if mutate typestrict 's@== false)@== false or .tool_response.success == "false")@'; then
  printf '        mutant typestrict edits: %s\n' "$MB/hooks/typestrict.sh"
  run_mutant typestrict 1 "the string \"false\" must not count as a failed send" "${B_fs_string:-0}"
else
  bad "FIXTURE STALE: the type-strictness mutation matched nothing — the jq comparison was reworded"
fi
if mutate toolgate 's|\[ "\$TOOL_NAME" = "SendMessage" \]|[ -n "$TOOL_NAME" ]|'; then
  printf '        mutant toolgate edits: %s\n' "$MB/hooks/toolgate.sh"
  run_mutant toolgate 1 "the SendMessage matcher must be load-bearing" "${B_toolgate:-0}"
else
  bad "FIXTURE STALE: the tool-name mutation matched nothing — the gate was reworded"
fi

if [ "$kills" -eq "$expected" ] && [ "$expected" -ge 2 ]; then
  ok "mutation battery: $kills of $expected mutants scored on exactly their own arm"
else
  bad "MUTATION BATTERY SCORED $kills OF $expected — a mutant that moved nothing reads exactly like an arm that cannot fire"
fi
# MX0: a plain run executes no matrix-only cell; --matrix scores every cell and says how many.
if [ "$MATRIX" = 1 ]; then
  echo "MATRIX MODE: $MX_RUN cells"
  if [ "$MX_RUN" -gt 0 ]; then ok "MX0 matrix mode: $MX_RUN cells scored"; else bad "MX0 matrix mode: --matrix scored no cell"; fi
elif [ "$MX_CELLS" -eq 0 ]; then ok "MX0 per-push run: matrix-only cells run = 0 (cells scored: $MX_RUN)"
else bad "MX0 per-push run: $MX_CELLS matrix-only cell(s) ran"; fi
rm -rf "$MB"
fi

echo
if [ "$fails" -eq 0 ]; then echo "escalation-delivery: PASS"; exit 0; fi
echo "escalation-delivery: $fails assertion(s) FAILED" >&2
exit 1
