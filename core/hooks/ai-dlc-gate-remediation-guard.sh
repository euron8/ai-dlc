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
#   2. payload carries agent_id      -> RECORD the write, then allow (a dispatched teammate;
#                                       THE remediator, and the only event that names a writer)
#   3. tool is not an edit           -> allow
#   4. no conforming verdict file    -> allow (no gate has ever run here)
#   5. newest pass records no FAIL   -> carry on to 7a; it is 7a that decides whether that
#                                       clean pass is entitled to clear the deny
#   6. target is in the permitted set-> allow (Rule 28(a); enumerated below)
#   7. target is outside the guarded roots -> allow
#  7a. the clean newest pass is bound to a dispatch -> allow (the gate really is not failing);
#      UNBOUND -> fall back to the newest BOUND pass and adjudicate on that instead
#  7b. every live FAIL is under an in-force SUPPRESSED entry
#                                    -> allow, and log GATE_REMEDIATION_SUPPRESSED
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
#   ARM 7b FAILS CLOSED, AND ITS CITATION IS VERIFIED LIKE ARM 9'S.
#   Arm 6 lets the lead write `docs/escalations/pending.md` while denied, so a suppression is
#   a record the lead CAN author -- and the sentence above about no lead-authored record
#   reaching this hook holds only because arm 7b subtracts a check on a VERIFIED operator
#   quote and on nothing else. Same `--cite` predicate as arm 9, same fail-closed posture:
#   no verifier, no corpus, no quote or a quote the operator never said all leave the deny
#   standing. The lifetime and shape half of the predicate stays in the sibling that owns it.
#   A suppressed FAIL is still a recorded FAIL -- the suppression bounds the operator's
#   LICENCE and never the check -- but no repair is coming for a check the operator has
#   dispositioned, so arm 7b PARTITIONS the live FAIL set rather than discarding it. What is
#   left over is what a remediator is still owed; that is what gates the edit, what the
#   repair-record arm must claim, and what the deny names. No escalations file, no sibling,
#   or a sibling refusal all mean NO subtraction and the deny stands exactly as before, with
#   the status printed beside it. Every failure of this arm therefore costs an edit, never a
#   lift.
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
#   (GATE_REMEDIATION_DENIED / GATE_REMEDIATION_LIFTED / GATE_REMEDIATION_SUPPRESSED /
#    GATE_STATE_UNADJUDICABLE / GATE_VERDICT_UNBOUND)
# - Appends to: _bmad-output/gate-adjudication/.verdict-writes.jsonl (arm 7a's own record;
#   durable, because it is evidence about a pass and is read by
#   `validate-gate-adjudication.sh` at the gate as well as by this hook)
# - Rewrites: _bmad-output/.gate-remediation-in-force (arm 7b's one-line-keyed cache;
#   declared transient in schemas/pipeline-state-paths.json, so it renders into the
#   consumer's .gitignore and is never committed)
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
# `core/scripts/validate-escalation-resolution.sh` and
# `core/scripts/validate-gate-adjudication.sh`; invariant I92 holds the four copies to one
# text and refuses a fifth.
steer_dir_has_transcript() { # $1 dir -> 0 if it holds a readable *.jsonl
  [ -n "${1:-}" ] && [ -d "$1" ] || return 1
  for _sdht in "$1"/*.jsonl; do
    [ -r "$_sdht" ] && return 0
  done
  return 1
}

# THE CITED SUBSTRING IS A FIELD, NOT A LINE. The capture here was
# `sed -n 's/.*"\(.*\)".*/\1/p'`, whose leading `.*` is GREEDY, so on a field carrying more
# than one quoted segment it took the LAST one and on an odd quote count it took the
# CONNECTIVE BETWEEN two of them. On THIS reader the fail-open direction LIFTS a gate deny:
# an invented operator authorization verified whenever any genuine operator substring trailed
# it on the same line. These two are byte-identical in
# `core/scripts/validate-escalation-resolution.sh` and
# `core/scripts/validate-adversarial-convergence.sh` and
# `core/scripts/validate-gate-adjudication.sh`; invariant I103 holds the four copies to one
# text and refuses a fifth. Read the escalation validator's header for the measurement.
cite_segments() { # $1 authline -> one quoted segment per line
  printf '%s\n' "$1" | LC_ALL=C awk '
    { n = split($0, p, /"/)
      # split on `"` yields quotecount+1 fields, and the inside-quote ones are the EVEN
      # indices. An odd quote count leaves the final field unterminated; it is even-indexed
      # too, so one loop covers both shapes.
      for (i = 2; i <= n; i += 2) if (p[i] != "") print p[i] }'
}

cite_quote() { # $1 authline
  _cq_segs="$(cite_segments "$1")"
  [ -n "$_cq_segs" ] || _cq_segs="$(printf '%s' "${1#*|}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  _cq_pick=""
  _cq_long=""
  while IFS= read -r _cq_seg; do
    [ "${#_cq_seg}" -gt "${#_cq_long}" ] && _cq_long="$_cq_seg"
    [ "${#_cq_seg}" -ge 12 ] || continue
    [ -n "$_cq_pick" ] || _cq_pick="$_cq_seg"
  done <<CITEEOF
$_cq_segs
CITEEOF
  # Nothing verifiable. Name the LONGEST segment anyway, so the "too short" message quotes
  # something the reader can find in the file instead of a fragment between two quotes.
  [ -n "$_cq_pick" ] || _cq_pick="$_cq_long"
  printf '%s' "$_cq_pick"
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# `AI_DLC_STATE_DIR` may be absolute or relative; the role files and
# `_gate-procedures.md:153` both write it as `${AI_DLC_STATE_DIR:-_bmad-output}`.
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
# The two records arm 7a joins on. Neither is written from the lead's own input:
# `ts` in both comes from `date -u` inside a hook, and `agent_id` in the write
# ledger is the harness's attribution of a tool call to a dispatched agent.
WRITE_LEDGER="${GATE_DIR}/.verdict-writes.jsonl"
SPAWN_LEDGER="${LOG_DIR}/spawn-ledger.jsonl"
# Seconds. The B2 arm's only constant, and it is picked by measurement -- see arm 7a.
DISPATCH_WINDOW_S="${AI_DLC_GATE_DISPATCH_WINDOW_S:-900}"

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

# THE VERDICT-WRITE LEDGER -- the one place the harness says WHO wrote a verdict file.
# A PreToolUse payload carries `agent_id` exactly when a DISPATCHED agent is making the call
# (arm 2 already reads that field for that meaning). The lead's own calls carry none, so a row
# here cannot be produced by the lead typing a filename: it is written from the harness's
# attribution and from `date -u`, never from the tool input's contents.
#
# WHAT IT ATTESTS AND WHAT IT DOES NOT. PreToolUse fires BEFORE the write, so a row is a record
# of a dispatched agent ASKING to write that stem -- intent, not completion -- and a lead that
# afterwards overwrites the same stem leaves no second row. That is the same honest floor arm 8
# declares for the repair record, for the same reason: this hook can prove a dispatch touched
# the path and cannot prove authorship of the bytes. What it removes is the case BL-176's
# subject is made of, where nothing at all binds the file to any dispatch.
record_verdict_write() { # $1 file_path -- silent no-op unless this is a verdict write
  case "$TOOL_NAME" in Edit|Write|MultiEdit) ;; *) return 0 ;; esac
  case "$1" in
    */${STATE_DIR_NAME}/gate-adjudication/*.verdict.json) ;;
    ${STATE_DIR_NAME}/gate-adjudication/*.verdict.json) ;;
    *) return 0 ;;
  esac
  _rvw_stem="$(basename "$1" .verdict.json)"
  # Same conforming-stem filter the pick uses. A non-conforming name is not a pass and must
  # not seed a row that a later, differently-named file could be read against.
  case "$_rvw_stem" in
    *-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
    *) return 0 ;;
  esac
  mkdir -p "$GATE_DIR" 2>/dev/null || return 0
  jq -nc --arg ts "$TIMESTAMP" --arg stem "$_rvw_stem" --arg agent "$AGENT_ID" \
         --arg session "${SESSION_ID:-}" --arg tool "$TOOL_NAME" \
     '{v: 1, ts: $ts, stem: $stem, agent_id: $agent, session: $session, tool: $tool}' \
     >> "$WRITE_LEDGER" 2>/dev/null || true
}

# THE BINDING QUERY. One jq invocation answers both questions arm 7a asks -- the live stem's
# status and the newest stem that is NOT unbound -- because a per-stem shell loop would be one
# jq per verdict and the reference consumer holds 195 of them.
# Reads the stem list on stdin; prints exactly two lines, `live:<status>` and `bound:<stem>`.
BIND_PROG='
def ep(s): (s | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime);
def epn(s): (s | strptime("%Y%m%dT%H%M%SZ") | mktime);
def nts(st): (if (st|length) < 16 then null else (try epn(st[-16:]) catch null) end);
[inputs | select(length > 0)] as $stems
| [ $sl[] | select(type == "object") | select(.ts | type == "string")
    | (try ep(.ts) catch empty) ] as $SALL
| [ $sl[] | select(type == "object") | select((.role // "") == "gate-adjudicator")
    | select(.ts | type == "string") | (try ep(.ts) catch empty) ] as $G
| [ $wl[] | select(type == "object") | select(.ts | type == "string")
    | (try ep(.ts) catch empty) ] as $WALL
| (($SALL + $WALL) | min) as $EPOCH
| def status(st):
    (nts(st)) as $N
    | if $N == null then "unbound-malformed"
      elif $EPOCH == null then "nocorpus"
      elif $N < $EPOCH then "exempt"
      elif ([ $wl[] | select(type == "object") | select(.stem == st)
              | select((.agent_id // "") != "") | select(.ts | type == "string")
              | (try ep(.ts) catch empty) | select(. >= $N) ] | length) > 0
        then "bound-write"
      elif ([ $G[] | select(. >= $N and . <= ($N + $win)) ] | length) > 0
        then "bound-dispatch"
      else "unbound" end;
  "live:" + status($live),
  "bound:" + ([ $stems[] | select(status(.) | startswith("unbound") | not) ]
              | if length == 0 then "" else (max_by(nts(.))) end)
'
verdict_binding() { # $1 live stem; stem list on stdin -> two lines, or nothing on a tool error
  _vb_wl="$WRITE_LEDGER"; [ -f "$_vb_wl" ] || _vb_wl=/dev/null
  _vb_sl="$SPAWN_LEDGER"; [ -f "$_vb_sl" ] || _vb_sl=/dev/null
  jq -Rrn --slurpfile wl "$_vb_wl" --slurpfile sl "$_vb_sl" \
          --argjson win "$DISPATCH_WINDOW_S" --arg live "$1" "$BIND_PROG" 2>/dev/null
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
# The allow is unchanged; on the way out it RECORDS, because this is the only event in the
# harness that names an agent and a file path in the same payload.
if [ -n "$AGENT_ID" ]; then
  record_verdict_write "$FP"
  exit 0
fi

# --- 3. Only edits.
case "$TOOL_NAME" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac
[ -n "$FP" ] || exit 0

# --- 4. Which pass is live? Filter inside the pick; order by nonce, never mtime.
[ -d "$GATE_DIR" ] || exit 0
LIVE_TS=""; LIVE_VERDICT=""; LIVE_NONCE=""; CONFORMING_STEMS=""
for _f in "$GATE_DIR"/*.verdict.json; do
  [ -f "$_f" ] || continue
  _stem="$(basename "$_f" .verdict.json)"
  _ts="${_stem##*-}"
  case "$_ts" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
    *) continue ;;
  esac
  CONFORMING_STEMS="${CONFORMING_STEMS}${_stem}
"
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
# NOT an exit any more. An EMPTY fail set is the state arm 7a exists to interrogate -- it is
# what a forged all-PASS verdict at a later-sorting nonce produces, and exiting here is exactly
# how that file cleared the lead. The two path filters below are pure `case` statements and
# cost nothing, so the expensive question is asked only for a guarded path.
[ -n "$FAILED_CHECKS" ] || LIVE_CLEAN=1
LIVE_CLEAN="${LIVE_CLEAN:-0}"

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
# 7a. THE DISPATCH BINDING -- an UNBOUND verdict may CONVICT but never ACQUIT.
# -----------------------------------------------------------------------------
# WHAT IT CATCHES. The pick above orders passes by nonce and nothing else, and the schema
# requires only that the nonce equal the filename stem -- both of which the lead writes. A file
# assembled by hand at a round timestamp therefore sorts above every real pass and BECOMES the
# live verdict; if it records no FAIL, the exit at arm 5 cleared the lead of a gate that is
# still failing. That file exists: the reference consumer's
# `gate-adjudication/planning-20260902T160000Z.verdict.json`.
#
# THE JOIN KEY, AND WHY IT IS NOT A NAME. `adjudicator_agent_id` is the obvious key and it does
# not work. Measured over the reference consumer's 193 conforming verdicts: it matches a
# spawn-ledger `name` for 92, and the round-nonce file's id is one of the 92 -- a real
# dispatched agent, named correctly, whose own transcript shows it WROTE the file. The field is
# also free-form in practice ("gate-adjudicator (fresh dispatch by team-lead)",
# "MERGED: gate-adjudicator-s307-deploy", "gate-adjudicator@planning-20260810T172728Z"), so a
# name join both accepts the subject and refuses a hundred legitimate passes.
#
# What separates that file is TIME, and time is the half no lead writes. The nonce is minted at
# gate ENTRY, before the dispatch, so on every legitimate pass the work happens AFTER the nonce.
# On the round-nonce file the adjudicator was dispatched at 13:57:46Z and wrote at 14:12:35Z
# under a nonce of 16:00:00Z -- the nonce is 108 minutes into its own future. The forgery that
# MATTERS has to be in that direction: to win the pick it must sort above the newest real pass,
# which is roughly now, so it must postdate the work that produced it.
#
#   B1  a `.verdict-writes.jsonl` row for THIS stem, agent_id non-empty, ts >= nonce.
#   B2  a spawn-ledger `gate-adjudicator` dispatch with nonce <= ts <= nonce + window.
#   EXEMPT  the nonce predates the earliest row in either ledger -- pre-migration, unknowable,
#           and reported as bound so installing this changes no verdict already on disk.
#
# B2 IS THE COMPATIBILITY ARM AND IT IS DELIBERATELY WEAK. It is keyed on a role and a window,
# not on the stem, so it says only "a gate-adjudicator was dispatched just after this nonce".
# It is here because B1 cannot see a verdict written through Bash: measured on the consumer's
# own transcript corpus, 105 verdict stems were written with Write/Edit and at least six more
# through a `python3` heredoc by a dispatched adjudicator, which no PreToolUse Edit matcher
# observes. Without B2 those six would be refused for using a different tool.
# ITS EXEMPTION MUST NOT COVER THE ARM'S OWN SUBJECT, and does not: measured, no
# gate-adjudicator dispatch falls in [16:00:00Z, +15m) for the round-nonce file, and the
# fixture asserts that directly.
#
# THE WINDOW IS 900s AND THE NUMBER IS MEASURED, NOT CHOSEN. Over the 44 post-epoch verdicts B1
# cannot speak for, the gap from nonce to the next gate-adjudicator dispatch is <= 60s for the
# 36 whose ordering is sound; every gap above 169s belongs to a verdict whose own write predates
# its nonce. 900 sits 15x above the largest sound gap and below the smallest unsound one.
#
# THE MEASURED FALSE-REFUSAL SET IS NINE, ENUMERATED, AND NONE OF THEM CAN BE LIVE. Running this
# predicate over the consumer's 195: 119 bound, 56 exempt, 2 non-conforming (already filtered by
# the pick and already rejected by the validator's envelope), 18 unbound. Nine of the eighteen
# are the entry's own defect class -- a nonce minted after the work, four of them at a round
# minute. The other nine are legitimate passes written before this ledger existed, so B1 has no
# row for them and their dispatch sits outside the window. All nine are older than the newest
# bound pass, so the pick reaches none of them and the arm changes no outcome on that tree today.
#
# FAIL POSTURE: MONOTONE, WHICH IS WHY IT CANNOT WEDGE. An unbound verdict's own FAILs still
# count -- the deny stands exactly as before. What it may not do is CLEAR: an unbound pass with
# no FAIL falls back to the newest BOUND pass, so the worst a false refusal costs is that the
# lead stays denied on a FAIL that is genuinely recorded, with the sanctioned remediator exit
# still open. A jq that errors, an absent ledger pair, or a stem the query cannot rank all leave
# the verdict treated as bound: undecidable is never a deny.
if [ "$LIVE_CLEAN" -eq 1 ]; then
  # An absent ledger is `--slurpfile`d from /dev/null and comes back as `nocorpus`, so there is
  # no separate cheap path here. One was written and then REMOVED: an interleaved three-rep A/B
  # of the whole guard fixture with and without it read 7.94/8.14/7.84 against 7.84/7.91/7.94,
  # a spread wider than any effect, and a branch whose removal changes nothing is not
  # load-bearing. The same interleaving against the pre-arm revision reads 9.25s vs 8.50s mean
  # -- this arm costs nothing this fixture can resolve.
  BIND_OUT="$(printf '%s' "$CONFORMING_STEMS" | verdict_binding "$LIVE_NONCE")"
  LIVE_BIND="$(printf '%s\n' "$BIND_OUT" | sed -n 's/^live://p' | head -1)"
  BOUND_STEM="$(printf '%s\n' "$BIND_OUT" | sed -n 's/^bound://p' | head -1)"
  case "${LIVE_BIND:-}" in
    unbound|unbound-malformed) ;;
    *) exit 0 ;;   # bound, exempt, nocorpus, or the query failed -- unchanged behaviour
  esac
  [ -n "$BOUND_STEM" ] || exit 0
  SUBST_VERDICT="${GATE_DIR}/${BOUND_STEM}.verdict.json"
  [ -f "$SUBST_VERDICT" ] || exit 0
  FAILED_CHECKS="$(jq -r '[.verdicts[]? | select(.verdict=="FAIL") | .check_id] | join(" ")' \
                     "$SUBST_VERDICT" 2>/dev/null)" || FAILED_CHECKS=""
  [ -n "$FAILED_CHECKS" ] || exit 0
  UNBOUND_NOTE="$(basename "$LIVE_VERDICT") is the newest pass by nonce and NO dispatch record binds it"
  log_event GATE_VERDICT_UNBOUND \
    "$UNBOUND_NOTE." \
    "It records no FAIL, so it would have cleared the Rule 28 deny; it may not." \
    "Adjudicating on ${BOUND_STEM} instead, whose FAILs are: ${FAILED_CHECKS}." \
    "A verdict binds by a .verdict-writes.jsonl row for its own stem, or by a gate-adjudicator" \
    "dispatch within ${DISPATCH_WINDOW_S}s AFTER its nonce. A nonce minted after the work has neither."
  LIVE_VERDICT="$SUBST_VERDICT"
  LIVE_NONCE="$BOUND_STEM"
else
  UNBOUND_NOTE=""
fi

# -----------------------------------------------------------------------------
# 7b. THE SUPPRESSED CARVE-OUT -- a FAIL the operator has dispositioned is a FAIL
#     no repair is coming for.
# -----------------------------------------------------------------------------
# WHAT IT CATCHES. `escalations.md` defines SUPPRESSED as an operator's authorization to
# proceed past a failing check, with a lifetime, and `validate-gate-adjudication.sh` already
# stops Check 26 blocking on such a FAIL. This hook reads the same verdict for a different
# purpose and did not ask, so the gate passed while the lead stayed locked out of the artifact
# corpus -- the only exit an `<nonce>.authorization.md` that no step tells it to write.
# Measured on the reference consumer while this was built: `implementation-20260905T172547Z`
# is the live pass by nonce, its single FAIL is check 16, and the `[S308-GATE3-STORY-1]` entry
# suppresses `[core] 16` in force. The lead was denied every artifact edit on a gate the
# operator had already dispositioned.
#
# THE PREDICATE IS THE SIBLING'S AND IS NOT RESTATED HERE. Well-formed, catalog-known and
# within lifetime all live in `validate-suppression-lifetime.sh --in-force`, the one owner of
# "in force". This hook consumes its rows and joins them on (catalog, check_id) against the
# verdict's own `catalog`, exactly as the gate validator does -- a row with an EMPTY catalog
# counts as `core` and nothing else, because the sibling resolves bare ids against the core
# catalog alone; and a verdict carrying NO `catalog` field joins against nothing, so it gets
# no carve-out. Measured over the reference consumer's 195 verdict files: 195 carry
# `catalog: core` and 0 carry none, so that strictness has an empty false-positive set there.
#
# THE ENFORCEMENT MAP IS DELIBERATELY NOT PASSED. The sibling resolves it itself from a root
# it walks up to, and that walk starts inside `PROJECT_DIR` because `SUPP_DIR` was derived
# from `PROJECT_DIR` -- so it lands on the same map either way. `AI_DLC_PROJECT_ROOT` is
# handed over so the walk cannot wander out of the project the hook was told about. Copying
# the sibling's three-candidate list into a hook would be a third spelling of one resolver,
# drifting with nothing watching; the gate validator's copy is already the second.
#
# THE CITATION IS VERIFIED HERE, AND THAT IS WHAT KEEPS THIS ARM OUT OF THE LEAD'S REACH.
# Arm 6 lets the lead edit `docs/escalations/pending.md` while denied, deliberately -- the
# escalation is its sanctioned exit. So without this, arm 7b is a self-discharge: the lead
# writes its own SUPPRESSED entry quoting an operator turn that never happened and the next
# edit is allowed. Measured end to end before this existed: DENY, one lead-authored entry,
# ALLOW. The sibling requires only an ISO timestamp on `**Operator authorization:**`; it does
# not and cannot decide whether the words were said.
#
# So every COVERING row's citation is verified against the harness transcript corpus with
# `validate-steering-budget.sh --cite`, the same predicate arm 9 uses one screen down and the
# same one `validate-escalation-resolution.sh` runs for RESOLVED/OVERRIDDEN. FAIL CLOSED: a
# row whose quote does not verify, or that cannot be verified for want of a corpus or a
# verifier, is NOT subtracted and the deny stands. An unverifiable claim never releases
# permission to edit, which is arm 9's rule applied to the same evidence class.
#
# WHY THE VERIFICATION IS HERE AND NOT IN THE SIBLING, WHICH WOULD COVER Check 26 TOO.
# Three measured reasons, in the order they were established. (1) The predicate is
# SATISFIABLE: the reference consumer's genuine `[S308-GATE3-STORY-1]` entry, quote
# "Suppress Check 16 (Recommended)", verifies over its 249-transcript corpus -- MATCH at
# 2026-09-05T17:46:59Z, against a control phrase that returns NOMATCH. (2) The sibling's OTHER
# caller names its corpus by FLAG: `validate-gate-adjudication.sh` now takes `--transcript-dir`
# from the lead's Check 26 call site and verifies the same rows itself, while this hook's corpus
# arrives from the harness on stdin -- two provenances, so a sibling verifying unconditionally
# would have to be handed one of them and would re-block every suppressed FAIL for the caller
# whose flag was missing, a check that wedges live work. (3) The sibling could not host the
# extraction anyway: `cite_quote()` and `cite_segments()` are held to exactly four copies by
# I103, whose site list is DERIVED from every file under core/ that names them, so a fifth copy
# fails the push. This hook is one of the four and already carries both. The sibling therefore
# forwards the auth line verbatim as a row field and parses nothing; each of the two readers
# verifies it against the corpus it was given.
#
# WHY THIS SITS AFTER ARM 7 AND NOT AFTER ARM 5. The subtraction changes exactly three
# things, all downstream of the guarded-root test: the repair record's `repaired_checks`
# join, the deny, and this allow. Running it at arm 5 would pay the sibling's parse on every
# `pipeline-snapshot.md` and `sprint-status.yaml` write the lead makes during remediation, and
# would log GATE_REMEDIATION_SUPPRESSED for each of them. The header already gives the reason
# in the sibling's own words: logging the common path drowns the signal.
#
# WHAT THAT PARSE COSTS, five reps interleaved against a control in the same invocation:
# 0.593s median over the reference consumer's 398582-byte `pending.md`, against 0.039s on a
# 399-byte seed -- roughly fifteen times the control, which is the figure that survives a
# change of machine. A second hand measured 2.92s and 0.20s on the same inputs; every row of
# that run including its own control and baseline is about four times this one, so the
# ABSOLUTE numbers here are load-dependent and the RATIOS are what to read.
#
# THE CACHE EXISTS BECAUSE THAT IS A WALL-CLOCK CHANGE ON AN EDIT. Whole guard, five reps,
# interleaved: base 0.045s median, cold 1.117s, warm 0.057s. A warm guarded edit adds about
# 12ms over the unguarded baseline and a cold one adds a full second; the other hand's run
# reads 0.147s / 3.06s / 0.225s, ~80ms warm, on the same shape.
#
# THE CITATION FILTER RUNS ON THE COLD PATH ONLY, and that siting is worth a second of the
# two. Verified on every read instead, the warm edit measured 0.48s -- eight times the cached
# figure above, because a `--cite` scan crosses the whole transcript corpus. What the cache
# holds is therefore the set that already passed.
#
# THE KEY IS THE ESCALATION FILE'S CONTENT, NEVER ITS SIZE AND MTIME. Measured: an entry
# rewritten from `[core] 7` to `[core] 9` is the same 190 bytes, and inside one whole second
# `mtime` does not move either -- so a size+mtime key returned a stale ALLOW for a suppression
# that no longer names the failing check. `mtime` granularity cannot be raised and the equal
# size is not a coincidence: an id swap is the common edit. A digest costs a few milliseconds
# against a 3s parse. The other terms stay size+mtime, because none of them is edited in place
# by the actor the deny is pointed at. The verification result is folded into the key by a
# `+cite` marker, so rows cached by a build that did not verify can never be read by one that
# does; a verified quote stays verified, transcripts being append-only, so nothing else about
# the corpus needs a key term.
IN_FORCE_STATUS=""
IN_FORCE_ROWS=""
SUPPRESSED_CHECKS=""
UNVERIFIED_CITES=0
ESC_FILE="${PROJECT_DIR}/docs/escalations/pending.md"
CACHE_FILE="${LOG_DIR}/.gate-remediation-in-force"
SUPP_DIR=""
for _sd in "${PROJECT_DIR}/scripts/ai-dlc" "${PROJECT_DIR}/core/scripts"; do
  [ -f "$_sd/validate-suppression-lifetime.sh" ] && { SUPP_DIR="$_sd"; break; }
done

# BSD and GNU `stat` spell this differently, AND THE WRONG FLAG DOES NOT ERROR. `stat -f` is
# `--file-system` on GNU, which answers `?` for an unknown format and exits 0 -- so a flavour
# probe keyed on the exit status detects BSD on Linux, every term of the key becomes the same
# constant, and the cache then never invalidates. That is the one direction this cache must
# not fail in, so the SHAPE of the answer is what selects the spelling, not the exit code.
fkey() { # <path> -> "<size>:<mtime>", "-" when there is no such file, "?" when unreadable
  [ -n "${1:-}" ] && [ -f "$1" ] || { printf '%s' "-"; return 0; }
  _fk="$(stat -f "%z:%m" "$1" 2>/dev/null)"
  case "${_fk:-}" in [0-9]*:[0-9]*) printf '%s' "$_fk"; return 0 ;; esac
  _fk="$(stat -c "%s:%Y" "$1" 2>/dev/null)"
  case "${_fk:-}" in [0-9]*:[0-9]*) printf '%s' "$_fk"; return 0 ;; esac
  printf '%s' "?"
}

# CONTENT, for the one input the denied lead can rewrite in place. `md5`, `md5sum` and
# `cksum` in that order; `cksum` is POSIX and always present, so the last arm cannot fail on
# a tree the other two are missing from.
ckey() { # <path> -> a digest of the bytes, "-" when absent, "?" when nothing could hash it
  [ -n "${1:-}" ] && [ -f "$1" ] || { printf '%s' "-"; return 0; }
  _ck="$(md5 -q "$1" 2>/dev/null)"
  case "${_ck:-}" in [0-9a-f][0-9a-f]*) printf '%s' "$_ck"; return 0 ;; esac
  _ck="$(md5sum "$1" 2>/dev/null | awk '{print $1}')"
  case "${_ck:-}" in [0-9a-f][0-9a-f]*) printf '%s' "$_ck"; return 0 ;; esac
  _ck="$(cksum "$1" 2>/dev/null | awk '{print $1 "-" $2}')"
  case "${_ck:-}" in [0-9]*-[0-9]*) printf '%s' "$_ck"; return 0 ;; esac
  printf '%s' "?"
}

# THE CITATION PREDICATE, asked of the script that owns it. Returns 0 only when the quote on
# this entry's `**Operator authorization:**` line is a genuine operator message in the
# transcript corpus. Every other outcome -- no verifier, no corpus, no quote, a quote too
# short to be evidence, a validator tooling error -- returns non-zero, because this answer
# releases permission to edit and there is no second piece of evidence behind it.
cite_verifies() { # <auth-line> -> 0 verified, 1 not
  local q flag arg
  [ -n "${1:-}" ] || return 1
  [ -f "$STEER_SCRIPT" ] || return 1
  q="$(cite_quote "$1")"
  [ "${#q}" -ge 12 ] || return 1
  flag=""; arg=""
  if [ -n "$TRANSCRIPT" ] && steer_dir_has_transcript "$(dirname "$TRANSCRIPT")"; then
    # THE DIRECTORY, for arm 9's reason: an operator authorizes a suppression in one session
    # and the gate that leans on it runs in another, so `transcript_path` is never the file
    # the words are in.
    flag="--dir"; arg="$(dirname "$TRANSCRIPT")"
  elif [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
    flag="--transcript"; arg="$TRANSCRIPT"
  fi
  [ -n "$flag" ] || return 1
  bash "$STEER_SCRIPT" "$flag" "$arg" --cite "$q" --quiet >/dev/null 2>&1
}

if [ ! -f "$ESC_FILE" ]; then
  IN_FORCE_STATUS="no-escalations-file:${ESC_FILE}"
elif [ -z "$SUPP_DIR" ]; then
  IN_FORCE_STATUS="no-sibling:validate-suppression-lifetime.sh is under neither ${PROJECT_DIR}/scripts/ai-dlc nor ${PROJECT_DIR}/core/scripts"
else
  # AI_DLC_GATE_METRICS is the fixture's channel, the same one the gate validator honours; a
  # live gate lets the sibling locate the timeline itself, under the PROJECT_DIR handed to it
  # below and never under the process cwd. This hook does NOT name the path on the sibling's
  # behalf: the sibling resolves three layouts under that root, and a single path chosen here
  # turned the flat and docs/ layouts from ALLOW into DENY when it was tried, while the gate
  # writer (`gate-validation.md`) writes the literal `_bmad-output/...` path whatever
  # AI_DLC_STATE_DIR says, so LOG_DIR is not where the timeline is under a custom state dir.
  # The cache key below names the standard layout's path for its freshness term, which is a
  # narrower claim than the sibling's resolution -- a timeline at a fallback layout does not
  # refresh this key when it moves.
  CACHE_KEY="${LIVE_NONCE}|+cite|$(ckey "$ESC_FILE")|$(fkey "${AI_DLC_GATE_METRICS:-${LOG_DIR}/implementation-artifacts/gate-metrics.jsonl}")|$(fkey "$SUPP_DIR/validate-suppression-lifetime.sh")"
  # A key with an unreadable term cannot invalidate, so there is no key: pay the parse.
  case "$CACHE_KEY" in *"?"*) CACHE_KEY="" ;; esac
  CACHED_KEY=""
  [ -n "$CACHE_KEY" ] && [ -f "$CACHE_FILE" ] && CACHED_KEY="$(head -1 "$CACHE_FILE" 2>/dev/null)"
  if [ -n "$CACHED_KEY" ] && [ "$CACHED_KEY" = "$CACHE_KEY" ]; then
    IN_FORCE_ROWS="$(sed -n '2,$p' "$CACHE_FILE" 2>/dev/null)"
    IN_FORCE_STATUS="ok:${ESC_FILE}"
  else
    # The sibling is named IN FULL here, never through a variable holding the whole path:
    # I107 in scripts/validate-enforcement-map.sh joins the mode spelled at a call site to the
    # modes that script dispatches, and it reads the literal beside the basename.
    if [ -n "${AI_DLC_GATE_METRICS:-}" ]; then
      IN_FORCE_ROWS="$(AI_DLC_PROJECT_ROOT="$PROJECT_DIR" bash "$SUPP_DIR/validate-suppression-lifetime.sh" --in-force \
        --escalations "$ESC_FILE" --gate-metrics "$AI_DLC_GATE_METRICS" 2>/dev/null)"
    else
      IN_FORCE_ROWS="$(AI_DLC_PROJECT_ROOT="$PROJECT_DIR" bash "$SUPP_DIR/validate-suppression-lifetime.sh" --in-force \
        --escalations "$ESC_FILE" 2>/dev/null)"
    fi
    SUPP_RC=$?
    if [ "$SUPP_RC" -eq 0 ]; then
      IN_FORCE_STATUS="ok:${ESC_FILE}"
      # THE CITATION IS VERIFIED BEFORE THE ROWS ARE CACHED, so what the cache holds is the
      # set that already passed. Verifying on every read instead would put a `--cite` scan of
      # the whole transcript corpus on every guarded edit -- measured at 0.48s warm against
      # 0.09s once the filter moved here. A verified quote stays verified, so caching the
      # survivors is sound; the `+cite` term in the key stops a build that did not verify from
      # ever handing its rows to one that does.
      _VROWS=""
      while IFS= read -r _row; do
        [ -n "${_row:-}" ] || continue
        _rauth="$(printf '%s' "$_row" | LC_ALL=C awk -F'\t' 'NF >= 6 { print $5 }')"
        if cite_verifies "${_rauth:-}"; then
          _VROWS="${_VROWS}${_row}
"
        else
          UNVERIFIED_CITES=$((UNVERIFIED_CITES + 1))
        fi
      done <<VROWEOF
$IN_FORCE_ROWS
VROWEOF
      IN_FORCE_ROWS="$(printf '%s' "$_VROWS")"
      [ -n "$CACHE_KEY" ] && mkdir -p "$LOG_DIR" 2>/dev/null \
        && printf '%s\n%s' "$CACHE_KEY" "$IN_FORCE_ROWS" > "$CACHE_FILE" 2>/dev/null
    else
      IN_FORCE_ROWS=""
      IN_FORCE_STATUS="refused:validate-suppression-lifetime.sh --in-force exited ${SUPP_RC}"
    fi
  fi
fi

if [ -n "$IN_FORCE_ROWS" ]; then
  # `awk -F'\t'` and not `IFS`+`read`: TAB is IFS-whitespace, so a shell read COLLAPSES the
  # empty leading field a bare-catalog row carries and shifts the check id into the catalog.
  #
  # `NF >= 6` is the SAME field count validate-gate-adjudication.sh's parse requires. The two
  # readers of this row must narrow together or one of them starts accepting a shape the other
  # rejects, and the disagreement surfaces as a gate that blocks beside a guard that allows.
  VERDICT_CATALOG="$(jq -r '.catalog // ""' "$LIVE_VERDICT" 2>/dev/null)"
  # Every row reaching here has already had its citation verified, cold or from the cache.
  COVERED="$(printf '%s\n' "$IN_FORCE_ROWS" | LC_ALL=C awk -F'\t' -v want="$VERDICT_CATALOG" '
    NF >= 6 && $2 != "" { c = ($1 == "" ? "core" : $1); if (c == want) print $2 }' | sort -u)"
  REMAINING=""
  for _c in $FAILED_CHECKS; do
    # `-x`, and the mutant that drops it is committed. A substring match acquits a FAIL on `3`
    # under a suppression naming `3a` and the reverse, which is the grain the repair-record
    # join at arm 8 already spells out one screen down.
    if grep -qxF "$_c" <<<"$COVERED"; then
      SUPPRESSED_CHECKS="${SUPPRESSED_CHECKS:+$SUPPRESSED_CHECKS }$_c"
    else
      REMAINING="${REMAINING:+$REMAINING }$_c"
    fi
  done
  FAILED_CHECKS="$REMAINING"
fi

# THE SET IS PARTITIONED, NOT DISCARDED: this exit is reached only when EVERY live FAIL is
# covered, and it is LOUD because retro's Rule 25(c) audit has to be able to tell an edit that
# passed under an operator's disposition from one no gate was watching.
if [ -z "$FAILED_CHECKS" ]; then
  log_event GATE_REMEDIATION_SUPPRESSED \
    "Tool: ${TOOL_NAME} on ${FP}" \
    "Live pass ${LIVE_NONCE}: every recorded FAIL (${SUPPRESSED_CHECKS}) is covered by an in-force SUPPRESSED entry." \
    "Rule 28 does not apply: no repair is owed for a check the operator has dispositioned." \
    "Carve-out source: ${IN_FORCE_STATUS}"
  exit 0
fi

# THE STATUS IS DOWNGRADED ONLY ONCE THE DENY STANDS. An unverifiable entry beside a genuine
# one that covers the whole live FAIL set changes no outcome, and saying "unverified" on an
# allow would point the reader at the wrong record.
[ "$UNVERIFIED_CITES" -eq 0 ] || \
  IN_FORCE_STATUS="unverified-citation:${UNVERIFIED_CITES} in-force entr(y/ies) cite an operator message that is NOT in this session's transcript corpus, so they suppress nothing"

# The sentence the deny and the log both carry. Mirrors validate-gate-adjudication.sh's own
# two reasons, because a lead reading one of these and then the other must not have to work
# out whether they are talking about the same predicate.
SUPP_NOTE=""
case "$IN_FORCE_STATUS" in
  ok:*) [ -n "$SUPPRESSED_CHECKS" ] && SUPP_NOTE=" $(printf '%s' "$SUPPRESSED_CHECKS" | wc -w | tr -d ' ') other FAIL(s) are under an in-force suppression; these are not." ;;
  *)    SUPP_NOTE=" No SUPPRESSED carve-out was applied (${IN_FORCE_STATUS}); a suppression that cannot be read covers nothing." ;;
esac

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
  AUTH_QUOTE="$(cite_quote "$AUTH")"
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
UNBOUND_CLAUSE=""
[ -n "${UNBOUND_NOTE:-}" ] && UNBOUND_CLAUSE="

THE NEWEST FILE IN THE GATE DIRECTORY IS NOT THIS PASS. ${UNBOUND_NOTE}, so it was not allowed to clear this deny -- a verdict binds by a \`.verdict-writes.jsonl\` row for its own stem written when a dispatched agent wrote it, or by a \`gate-adjudicator\` dispatch recorded within ${DISPATCH_WINDOW_S}s AFTER its nonce. A nonce minted after the work it reports has neither. If that file is a real pass, re-run the gate: mint the nonce at gate ENTRY, then dispatch."
REASON="AI/DLC Rule 28: GATE REMEDIATION IS DELEGATED. Gate pass \`${LIVE_NONCE}\` recorded FAIL on check(s) \`${FAILED_CHECKS}\` and no repair has been dispatched, so \`${TOOL_NAME}\` on \`${FP}\` is DENIED.${SUPP_NOTE}${UNBOUND_CLAUSE}

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
  "Live gate pass: ${LIVE_NONCE}; FAILed check(s) still owed a repair: ${FAILED_CHECKS}" \
  "SUPPRESSED carve-out: ${IN_FORCE_STATUS}${SUPPRESSED_CHECKS:+; covered: ${SUPPRESSED_CHECKS}}" \
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
