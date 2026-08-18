#!/bin/bash
#
# AI/DLC Gate-Remediation Delegation Guard (Rule 28)
#
# PURPOSE
# While a gate pass is open carrying a recorded FAIL, the LEAD may not edit the
# artifact corpus. The repair is dispatched to a `remediator`; the lead owns the
# PASS/FAIL decision, the disposition and the escalation, and nothing else.
#
# WHY A PreToolUse DENY AND NOT A RULE, A RETRO FINDING, OR A COUNTER
# Rule 28 already carries the strongest sentence available to prose --
# `SKILL.md:1429-1431`, "The lead does NOT get to reason 'this is small, I'll just
# do it.' When the lead performs any action inline, it MUST name which exclusion
# (a/b/c) authorizes it." Measured against one live gate cascade on the reference
# consumer (11 adjudication passes on one `[story]` gate, 18:36:56Z -> 21:49:36Z):
#
#     main-thread tool     count
#     Bash                 233
#     Edit                 104        <- every one of them the lead
#     Read                  44
#     Agent                 10        (all ten read-only gate-adjudicator dispatches)
#     remediator dispatches  0
#
# Top edit targets: `test-strategy.md` (14), `e2e-trace-summary.json` (14),
# `story-1-....md` (13), `traceability-matrix.md` (13). The context sensor fired
# RED twice (270k, then 317k tokens) DURING the repair sequence -- the lead was
# repairing from a compacted summary, which is the failure mode
# `_gate-procedures.md:409-447` already names in its opening line.
#
# Detection after the fact yields a retro finding, by which time the edits are
# spent and the context is gone. This refuses the call.
#
# NOT SELF-DISCHARGEABLE, AND THAT IS THE POINT
# The lead has a sanctioned channel for authorizing its own deviations, and it
# uses it: a `DECIDED_AUTONOMOUSLY (Rule 12 Tier 2)` disposition written into the
# pipeline snapshot AFTER the act. In this same cascade the dispatched remediator
# REFUSED an edit and said why ("Recomputing the stamp is the one edit that must
# never come from a repair seat"); the lead then made the edit itself and recorded
# the disposition. A delegate that can be overridden by the delegator is not a
# control.
#
# So this hook DOES NOT READ THE SNAPSHOT. There is no input a lead-authored
# disposition can reach -- not a permitted path, not a lift arm, not a log. That
# is stronger than reading the disposition and rejecting it, because there is no
# parser to get wrong and no new phrasing to argue with. Same register as
# `ai-dlc-acknowledge.sh:345` ("Clearing the pause flag does NOT lift this") and
# `gate-validation.md:1367-1370` (Rule 19: "`DECIDED_AUTONOMOUSLY` does NOT clear
# this, and that exclusion is the point: it is the lead dispositioning its own
# violation").
#
# TWO LIFTS, AND ONLY TWO
#   1. A dispatched remediator's REPAIR RECORD, bound to the live failing pass by
#      its `gate_nonce` -- not by proximity, not by mtime, not by filename alone.
#   2. An OPERATOR AUTHORIZATION whose verbatim citation is verified against the
#      harness-owned transcript corpus by `validate-steering-budget.sh --cite`,
#      the same predicate arm F6 uses (`validate-adversarial-convergence.sh:757`).
#
# DECISION ORDER (first match wins)
#   0. jq absent                     -> allow (nothing can be parsed; see posture)
#   1. no pipeline snapshot          -> allow (not an ai-dlc session)
#   2. payload carries agent_id      -> allow (a dispatched teammate; THE remediator)
#   3. tool is not an edit           -> allow
#   4. no conforming verdict file    -> allow (no gate has ever run here)
#   5. newest pass records no FAIL   -> allow (the gate is not in remediation)
#   6. target is in the permitted set-> allow (Rule 28(a); enumerated below)
#   7. target is outside the guarded roots -> allow
#   8. a bound repair record exists  -> allow, and log GATE_REMEDIATION_LIFTED
#   9. a verified operator citation  -> allow, and log GATE_REMEDIATION_LIFTED
#  10. otherwise                     -> DENY, and log GATE_REMEDIATION_DENIED
#
# FAILURE POSTURE -- DECLARED PER ARM, BECAUSE THE TWO HALVES POINT OPPOSITE WAYS
#
#   THE GUARD ARMS FAIL OPEN, WITH A TRACE.
#   Arms 0, 4 and the unparseable-verdict path all allow. A hook that wedges every
#   artifact edit on its own JSON-parse bug gets switched off, and a switched-off
#   hook watches nothing at all -- `ai-dlc-acknowledge.sh:293-296` states this in
#   the same words for the same reason. Where the state was PRESENT but
#   UNREADABLE (a verdict file that exists and does not parse; jq missing while a
#   gate directory exists) the allow is LOUD: `GATE_STATE_UNADJUDICABLE` goes to
#   the flow log, because "a check that cannot fire reads exactly like one that
#   passed" and retro's Rule 25(c) audit reads that log. Where the state is simply
#   ABSENT (no gate-adjudication directory at all) the allow is silent -- that is
#   the common path and logging it would drown the signal.
#
#   THE LIFT ARMS FAIL CLOSED.
#   Arm 9 (operator citation) NEVER lifts on an unverifiable claim: no readable
#   transcript, no `validate-steering-budget.sh`, or a validator tooling error
#   (node absent, rc not in {0,2}) all leave the deny standing. This mirrors F6's
#   GATE tier rather than its hook tier -- `validate-adversarial-convergence.sh:808`
#   ("The gate cannot release an operator-gated HARD_BLOCK on an unverifiable
#   claim"). Here the thing being released is permission to edit, and the citation
#   is the entire claim; there is no second piece of evidence to fall back on.
#
#   ARM 8 IS DELIBERATELY MIXED, AND THIS IS THE ONE JUDGEMENT CALL IN THE FILE.
#   Its STRUCTURAL requirements are mandatory (nonce bound, non-empty
#   `remediator_agent_id`, `repaired_checks` covering at least one live FAIL). Its
#   transcript CORROBORATION -- does that agent_id appear anywhere in the session
#   corpus -- is fail-closed when the transcript is READABLE and the id is absent
#   (that is a forgery signal and must not lift), and fail-open when no transcript
#   is readable at all (refusing every lift on a harness that omitted the field
#   would wedge the pipeline on the honest path). The fail-open case is logged.
#
# WHAT ARM 8 CANNOT PROVE, STATED PLAINLY
# Existence + structure is the honest floor, exactly as
# `validate-adversarial-convergence.sh:1234-1238` declares for its own analogue.
# This hook cannot prove AUTHORSHIP of the repair record: a lead with a real
# dispatched agent_id in its transcript could write the file itself. What it does
# prove is that a remediator was dispatched in this session, that the record names
# the live failing pass, and that it claims a check that is actually failing. The
# corroborating arm raises the forgery cost from "type a sentence" to "quote a
# real dispatch"; it does not eliminate it. A8's fixture-side arm is where
# authorship gets a stronger reader, if one is ever built.
#
# THE PERMITTED SET (Rule 28(a) -- the lead's own non-delegable mutations)
# Enumerated, not inferred. A hook that wedges the pipeline it protects is worse
# than no hook, and each of these is a mutation the rulebook REQUIRES the lead to
# make while a gate is failing:
#   - `pipeline-snapshot.md` and `pipeline-snapshot-history.md` -- state records,
#     and Rule 25(a)'s trim needs both halves (`ai-dlc-acknowledge.sh:426-459`).
#   - `validation-cycle-log.md`, `pipeline-continuation-log.md` -- the loop's logs.
#   - any `sprint-status.yaml` -- both homes (`sprint-status.sh:247-248`) and the
#     `s<N>/` form.
#   - `docs/escalations/**` -- the escalation IS the sanctioned exit from a stalled
#     gate (Rule 12 HARD_BLOCK). Denying it would deny the way out, which is the
#     resolution-record deadlock `ai-dlc-acknowledge.sh:413-424` describes.
#   - `*-resolution-p*.md` -- the adversarial resolution record, same reason.
#   - `_bmad-output/ai-dlc-update/**` -- a different skill with no gate to fail.
# Git operations are Bash and never reach this matcher; they are unaffected.
#
# NOT in the permitted set, on purpose: `gate-adjudication/**` (the adjudicator
# writes verdicts, and it carries an agent_id) and any `gate-*repair*.md` (a lead
# that could write the repair record could write its own lift).
#
# THE GUARDED ROOTS (deliberately narrow -- Rule 26 minimum mechanism)
#   `_bmad-output/planning-artifacts/**`, `_bmad-output/implementation-artifacts/**`,
#   `docs/**`. That is where all four measured top edit targets live, plus the
#   `docs/architecture.md` insertion pass 11 named as the root cause. SOURCE CODE
#   IS OUT OF SCOPE and that is a limit, not an oversight: a `[story]` or
#   `[planning]` gate adjudicates documents, an `[implementation]` gate's repairs
#   run through the dev/qa loop which already has its own delegation, and widening
#   this to the whole tree would deny the lead's Rule 28(a) merge-conflict
#   resolution with no measurement behind it.
#
# ORDERING THE PASSES: THE NONCE, NEVER mtime
# `gate_nonce` is `<gate_type>-<YYYYMMDD>T<HHMMSS>Z` (schema `patterns.gate_nonce`)
# and the schema requires it to equal the verdict filename stem. The trailing
# timestamp sorts lexically == chronologically, so the newest pass is a string
# comparison over the stems. mtime is the WRONG signal here for the reason
# `divergence-hard-block/run.sh:211-229` records: touching an old verdict -- a
# re-read, an editor, a `git checkout` -- would make a settled pass the live one.
# Non-conforming filenames are filtered INSIDE the pick, never picked and then
# rejected (`ai-dlc-acknowledge.sh:221-231`).
#
# OUTPUT
# - Appends to: _bmad-output/pipeline-continuation-log.md
#   (GATE_REMEDIATION_DENIED / GATE_REMEDIATION_LIFTED / GATE_STATE_UNADJUDICABLE)
# - JSON to stdout on deny: permissionDecision + reason
# - Exit 0 in all cases (the deny is in the JSON body)
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-gate-remediation-guard.sh
# 2. chmod +x (validate-enforcement-map.sh fails the push on a non-755 mode)
# 3. Registered by templates/settings.json.template in the PreToolUse
#    "Edit|Write|MultiEdit" matcher block. NotebookEdit is deliberately absent:
#    no ai-dlc artifact is a notebook, and the pause surface already covers it.

set -u

# A DIRECTORY IS NOT A CORPUS. `-d` answers whether the path EXISTS, never whether it holds
# any ground truth. Here the dirname of an unreadable `transcript_path` still exists, so the
# `--dir` branch won on a corpus with nothing in it and the readable-file fallback below was
# never reached — a verified authorization then failed to lift the guard for want of a corpus
# rather than for want of a citation. The corpus reader selects `*.jsonl`
# (`validate-steering-budget.sh:427`), so a directory holding only sidecar files is exactly
# as blind as an empty one and this counts what that reader would count. This predicate is
# byte-identical in `core/scripts/validate-adversarial-convergence.sh` and
# `core/scripts/validate-escalation-resolution.sh`; invariant I92 holds the three copies to
# one text and refuses a fourth.
steer_dir_has_transcript() { # $1 dir -> 0 if it holds a readable *.jsonl
  [ -n "${1:-}" ] && [ -d "$1" ] || return 1
  for _sdht in "$1"/*.jsonl; do
    [ -r "$_sdht" ] && return 0
  done
  return 1
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# `AI_DLC_STATE_DIR` may be absolute or relative; the role files and
# `_gate-procedures.md:143` both write it as `${AI_DLC_STATE_DIR:-_bmad-output}`.
# The NAME is what the path patterns below match on (payload paths arrive both
# absolute and relative, exactly as `ai-dlc-acknowledge.sh:403` handles them).
_STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"
STATE_DIR_NAME="$(basename "$_STATE_DIR")"
case "$_STATE_DIR" in
  /*) LOG_DIR="$_STATE_DIR" ;;
  *)  LOG_DIR="${PROJECT_DIR}/${_STATE_DIR}" ;;
esac
SNAPSHOT_FILE="${LOG_DIR}/pipeline-snapshot.md"
LOG_FILE="${LOG_DIR}/pipeline-continuation-log.md"
GATE_DIR="${LOG_DIR}/gate-adjudication"
STEER_SCRIPT="${PROJECT_DIR}/scripts/ai-dlc/validate-steering-budget.sh"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log_event() { # <event> <line>...
  local ev="$1"; shift
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  {
    echo "## ${TIMESTAMP} -- ${ev}"
    echo "- Session: ${SESSION_ID:-<none>}"
    for l in "$@"; do echo "- ${l}"; done
    echo ""
  } >> "$LOG_FILE"
}

# --- 0. jq. Everything below parses JSON; without it nothing can be adjudicated.
if ! command -v jq >/dev/null 2>&1; then
  SESSION_ID=""
  # Only LOUD where a gate actually exists -- otherwise this fires on every edit
  # in every non-ai-dlc repo on the machine.
  [ -d "$GATE_DIR" ] && log_event GATE_STATE_UNADJUDICABLE \
    "jq is not on PATH; the Rule 28 gate-remediation deny is NOT armed." \
    "Failed OPEN. Install jq, or the lead can repair inline unchallenged."
  exit 0
fi

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# --- 1. Not an ai-dlc session. Free, and it precedes every directory read for the
# reason `ai-dlc-acknowledge.sh:122-130` gives: this matcher is hot.
[ -f "$SNAPSHOT_FILE" ] || exit 0

# --- 2. A dispatched teammate. THE WHOLE POINT: the remediator edits freely.
# `agent_id` is the harness's own discriminator; `ai-dlc-context-sensor.sh:160`
# reads exactly this field for exactly this question. Absent == the lead.
[ -z "$AGENT_ID" ] || exit 0

# --- 3. Only edits.
case "$TOOL_NAME" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac
[ -n "$FP" ] || exit 0

# --- 4. Which pass is live? Filter inside the pick; order by nonce, never mtime.
[ -d "$GATE_DIR" ] || exit 0
LIVE_TS=""; LIVE_VERDICT=""; LIVE_NONCE=""
for _f in "$GATE_DIR"/*.verdict.json; do
  [ -f "$_f" ] || continue
  _stem="$(basename "$_f" .verdict.json)"
  _ts="${_stem##*-}"
  case "$_ts" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
    *) continue ;;
  esac
  if [ "$_ts" \> "$LIVE_TS" ]; then LIVE_TS="$_ts"; LIVE_VERDICT="$_f"; LIVE_NONCE="$_stem"; fi
done
[ -n "$LIVE_VERDICT" ] || exit 0

# --- 5. Does the live pass record a FAIL?
# `jq -e` so an unparseable file is distinguishable from a clean one. A verdict
# file that EXISTS and does not parse is the state that must never read as a pass.
FAILED_CHECKS="$(jq -r '[.verdicts[]? | select(.verdict=="FAIL") | .check_id] | join(" ")' \
                   "$LIVE_VERDICT" 2>/dev/null)"
JQ_RC=$?
if [ "$JQ_RC" -ne 0 ]; then
  log_event GATE_STATE_UNADJUDICABLE \
    "$(basename "$LIVE_VERDICT") is the newest gate pass and does NOT parse as JSON." \
    "The Rule 28 gate-remediation deny is NOT armed for this edit. Failed OPEN." \
    "An unreadable verdict must never score as a clean one -- fix or remove the file."
  exit 0
fi
[ -n "$FAILED_CHECKS" ] || exit 0

# --- 6. The permitted set (Rule 28(a)). First match wins; enumerated in the header.
case "$FP" in
  */pipeline-snapshot.md|pipeline-snapshot.md) exit 0 ;;
  */pipeline-snapshot-history.md|pipeline-snapshot-history.md) exit 0 ;;
  */validation-cycle-log.md|validation-cycle-log.md) exit 0 ;;
  */pipeline-continuation-log.md|pipeline-continuation-log.md) exit 0 ;;
  */sprint-status.yaml|sprint-status.yaml) exit 0 ;;
  */docs/escalations/*|docs/escalations/*) exit 0 ;;
  *-resolution-p*.md) exit 0 ;;
  */${STATE_DIR_NAME}/ai-dlc-update/*|${STATE_DIR_NAME}/ai-dlc-update/*) exit 0 ;;
esac

# --- 7. The guarded roots.
GUARDED=0
case "$FP" in
  */${STATE_DIR_NAME}/planning-artifacts/*|${STATE_DIR_NAME}/planning-artifacts/*) GUARDED=1 ;;
  */${STATE_DIR_NAME}/implementation-artifacts/*|${STATE_DIR_NAME}/implementation-artifacts/*) GUARDED=1 ;;
  # THE GATE'S OWN RECORDS, and this arm was ADDED BY THE FIXTURE. Without it the
  # sibling repair-record path sat outside every guarded root, so the lead could
  # write `<nonce>.repair.md` itself and lift its own deny on the next call --
  # the opt-out rebuilt one file over from where it was removed. The verdict files
  # belong here for the same reason: the adjudicator writes them and carries an
  # agent_id, so nothing legitimate is lost.
  */${STATE_DIR_NAME}/gate-adjudication/*|${STATE_DIR_NAME}/gate-adjudication/*) GUARDED=1 ;;
  */docs/*|docs/*) GUARDED=1 ;;
esac
[ "$GUARDED" -eq 1 ] || exit 0

# -----------------------------------------------------------------------------
# LIFT ARM 8 -- a dispatched remediator's repair record, bound to THIS pass.
# -----------------------------------------------------------------------------
# Two accepted homes, one binding. The sibling path is DERIVED from the live
# verdict's own stem, so it cannot be satisfied by a record for an earlier pass.
# The sprint-directory form is A4's grammar; there the bind is the nonce appearing
# in the file's own text, which is the same exactness by a different route. What is
# never accepted is proximity -- the 5-line-window defect `validate-mandatory-rules.sh`
# carries for the self-execution waiver, where any nearby record satisfies the match.
repair_record_lifts() { # -> 0 lifts, 1 does not; sets LIFT_REC / LIFT_WHY
  local cand rid checks c f
  LIFT_REC=""; LIFT_WHY=""
  for cand in "$GATE_DIR/${LIVE_NONCE}.repair.md" \
              "${LOG_DIR}"/planning-artifacts/s*/gate-*repair*.md; do
    [ -f "$cand" ] || continue
    grep -qF "$LIVE_NONCE" "$cand" 2>/dev/null || continue

    rid="$(sed -n 's/^[[:space:]]*remediator_agent_id:[[:space:]]*//p' "$cand" 2>/dev/null | head -1)"
    rid="$(printf '%s' "$rid" | sed 's/[[:space:]]*$//')"
    [ -n "$rid" ] || { LIFT_WHY="${cand}: no remediator_agent_id"; continue; }

    # The record must claim a check that is ACTUALLY failing right now. Token
    # match, not substring: `3` must not satisfy a record that repaired `3a`.
    checks="$(sed -n 's/^[[:space:]]*repaired_checks:[[:space:]]*//p' "$cand" 2>/dev/null | head -1 | tr ',' ' ')"
    f=0
    for c in $checks; do
      case " $FAILED_CHECKS " in *" $c "*) f=1; break ;; esac
    done
    [ "$f" -eq 1 ] || { LIFT_WHY="${cand}: repaired_checks names none of the live FAILs (${FAILED_CHECKS})"; continue; }

    # CORROBORATION. Fail CLOSED when the transcript is readable and the claimed
    # dispatch is not in it; fail OPEN (logged) when there is no transcript at all.
    if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
      if ! grep -qF "$rid" "$TRANSCRIPT" 2>/dev/null; then
        LIFT_WHY="${cand}: remediator_agent_id '${rid}' appears in NO dispatch in this session's transcript"
        continue
      fi
    else
      log_event GATE_REMEDIATION_UNCORROBORATED \
        "$(basename "$cand") lifts the Rule 28 deny on structure alone." \
        "No readable transcript, so remediator_agent_id '${rid}' could not be corroborated." \
        "Failed OPEN on this arm; the structural arms held. Retro should read the record."
    fi
    LIFT_REC="$cand"
    return 0
  done
  return 1
}

if repair_record_lifts; then
  log_event GATE_REMEDIATION_LIFTED \
    "Tool: ${TOOL_NAME} on ${FP}" \
    "Live pass ${LIVE_NONCE} FAILs: ${FAILED_CHECKS}" \
    "Lifted by repair record: ${LIFT_REC}"
  exit 0
fi

# -----------------------------------------------------------------------------
# LIFT ARM 9 -- an operator authorization, verified against the transcript corpus.
# -----------------------------------------------------------------------------
# FAIL CLOSED throughout. The citation is the whole claim; there is no second
# piece of evidence, and this is the arm a lead could otherwise author for itself.
AUTH_FILE="$GATE_DIR/${LIVE_NONCE}.authorization.md"
if [ -f "$AUTH_FILE" ] && [ -f "$STEER_SCRIPT" ]; then
  AUTH="$(sed -n 's/^[[:space:]]*operator_authorization:[[:space:]]*//p' "$AUTH_FILE" 2>/dev/null | head -1)"
  AUTH_QUOTE="$(printf '%s' "$AUTH" | sed -n 's/.*"\(.*\)".*/\1/p')"
  [ -z "$AUTH_QUOTE" ] && AUTH_QUOTE="$(printf '%s' "${AUTH#*|}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  if [ "${#AUTH_QUOTE}" -ge 12 ]; then
    STEER_FLAG=""; STEER_ARG=""
    if [ -n "$TRANSCRIPT" ] && steer_dir_has_transcript "$(dirname "$TRANSCRIPT")"; then
      # THE DIRECTORY, not the file. An authorization outlives the session that
      # recorded it; `transcript_path` is always THIS session, never the one the
      # operator spoke in. Same reasoning as `ai-dlc-acknowledge.sh:268-272`.
      STEER_FLAG="--dir"; STEER_ARG="$(dirname "$TRANSCRIPT")"
    elif [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
      STEER_FLAG="--transcript"; STEER_ARG="$TRANSCRIPT"
    fi
    if [ -n "$STEER_FLAG" ]; then
      bash "$STEER_SCRIPT" "$STEER_FLAG" "$STEER_ARG" --cite "$AUTH_QUOTE" --quiet >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        log_event GATE_REMEDIATION_LIFTED \
          "Tool: ${TOOL_NAME} on ${FP}" \
          "Live pass ${LIVE_NONCE} FAILs: ${FAILED_CHECKS}" \
          "Lifted by VERIFIED operator authorization: ${AUTH_FILE}"
        exit 0
      fi
    fi
  fi
fi

# -----------------------------------------------------------------------------
# DENY. The gate is failing and you are the lead.
# -----------------------------------------------------------------------------
REASON="AI/DLC Rule 28: GATE REMEDIATION IS DELEGATED. Gate pass \`${LIVE_NONCE}\` recorded FAIL on check(s) \`${FAILED_CHECKS}\` and no repair has been dispatched, so \`${TOOL_NAME}\` on \`${FP}\` is DENIED.

You are the lead. You own PASS/FAIL, the disposition and the escalation. You do not own the edit.

WHY YOU AND NOT SOMEONE ELSE. You are the most context-saturated agent in the pipeline -- \`_gate-procedures.md\` opens its repair-dispatch procedure with exactly that sentence. Repairing from a compacted summary rather than the document is how a one-check failure becomes an eleven-pass cascade: each pass fixes the hop it remembers and the dependents it cannot see re-fail.

DO THIS INSTEAD:
1. DISPATCH a \`remediator\` (\`.claude/team-roles/remediator.md\`), one per failing check or one for the set, with the failing check_ids, the verdict's own evidence strings, and the artifact paths. The dispatch procedure is \`_gate-procedures.md\` -- 'Adversarial repair dispatch', which covers gate remediation too.
2. JOIN it on its deliverable, the bounded file-wait beat (Rule 29). Do not block on a foreground Agent call.
3. The remediator writes the REPAIR RECORD at:
     ${STATE_DIR_NAME}/gate-adjudication/${LIVE_NONCE}.repair.md
   naming \`${LIVE_NONCE}\`, its own \`remediator_agent_id:\`, and \`repaired_checks:\`. That record is what lifts this denial. A dispatched teammate carries an \`agent_id\` and is never denied by this hook -- it can edit anything.
4. THEN re-run the derivations before the next pass, and re-run the failed check PLUS every check whose inputs the repair touched.

WHAT DOES NOT LIFT THIS:
- A \`DECIDED_AUTONOMOUSLY\` record. A Rule 12 Tier 2 citation. Any disposition you write yourself. This hook does not read the snapshot at all -- there is no field you can write that reaches it, and that exclusion is the point: it is the lead dispositioning its own violation.
- Deciding the edit is small, or that dispatching costs more than doing it. Rule 28 inverts the burden: you must name the exclusion that authorizes an inline act, and (a)/(b)/(c) do not contain 'repairing a failed gate check'.
- Writing the repair record yourself. It is bound to a real dispatched \`agent_id\` from this session's transcript.

STILL ALLOWED right now: the pipeline snapshot and its history, the gate and continuation logs, any \`sprint-status.yaml\`, everything under \`docs/escalations/\` (the HARD_BLOCK escalation is your sanctioned exit), any \`*-resolution-p*.md\`, all git operations, and every read-only tool.

IF THE REPAIR IS GENUINELY NOT A REMEDIATOR'S CALL -- a provenance re-stamp, a governance judgment, a rule rewrite -- that is an ESCALATION, not an exception. Write it to \`docs/escalations/pending.md\` and put it to the operator. An operator authorization recorded at ${STATE_DIR_NAME}/gate-adjudication/${LIVE_NONCE}.authorization.md, carrying \`operator_authorization: <ISO ts> | \"<verbatim quote>\"\`, lifts this once the quote is verified against the harness transcript. A quote the operator never said does not."

log_event GATE_REMEDIATION_DENIED \
  "Tool denied: ${TOOL_NAME}" \
  "Target: ${FP}" \
  "Live gate pass: ${LIVE_NONCE}; FAILed check(s): ${FAILED_CHECKS}" \
  "No bound remediator repair record and no verified operator authorization${LIFT_WHY:+ (${LIFT_WHY})}"

jq -n --arg reason "$REASON" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'

exit 0
