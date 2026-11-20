#!/usr/bin/env bash
# ai-dlc-recover-gate.sh -- makes the POST-COMPACT RECOVERY mandate MECHANICAL.
#
# WHAT IT ENFORCES. `ai-dlc-recover.sh` injects a block whose first two sentences are, in
# imperative caps, "Your FIRST tool call MUST be `Read _bmad-output/pipeline-snapshot.md` in
# full" and "Your SECOND tool call MUST be `Read <step file>` in full". Until this hook, that
# was advisory: the injector emits `additionalContext` and has no deny path, no hook in the
# tree parsed a `Read` call, and NOTHING anywhere observed whether the mandated Reads
# happened. `ai-dlc-postcompact.sh` records whether the text was INJECTED -- never whether it
# was OBEYED.
#
# WHY ADVISORY WAS NOT ENOUGH. Filed by the reference consumer as
# PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION. One session skipped both Reads
# on the hook's first firing, skipped both again on a second firing in the same session, and
# on the third attempt stopped 773 of 1210 lines into the second Read, reasoning live that
# finishing was "duplicative" of bytes it had just written. Two silent, one rationalized in
# the open, and all three found only because the operator asked directly. The filing's own
# argument is the one that decides the design: a mandate whose whole purpose is to substitute
# for a lead's possibly-wrong belief that it still holds accurate state cannot delegate to
# that same belief the decision of when the belief is accurate enough to skip it. The
# surrounding hook text already says it -- "You cannot find the cut by introspection."
#
# WHY IT CANNOT WEDGE, WHICH IS THE PART THAT HAD TO BE DESIGNED RATHER THAN ASSERTED.
# A gate that denies until an action is taken is safe only if that action is ALWAYS AVAILABLE.
# So this one arms only when every mandated Read is takeable, and re-checks at deny time:
#
#   - `.recover-fired` must exist. Absent = no compaction is pending recovery, and this hook
#     is inert on every ordinary tool call in every ordinary session.
#   - `step_file_resolved=1`. When a snapshot names no current step file the injected mandate
#     names an ACTION rather than a path, and there is no single call this hook could demand.
#   - Both paths must exist on disk, checked HERE and again before any deny. A path that
#     vanished mid-session disarms the gate instead of blocking every call the lead can make.
#
# Under those conditions "comply" is a Read of a file known to exist, and the Read every deny
# names is a bounded chunk: `Read <path> offset=<a> limit=<b>` of at most 16384 bytes and never
# fewer than one line. No size guard refuses it -- the context-mode plugin exempts a Read carrying
# `offset`, `limit` or `view_range`, and the Read tool's token cap is far above a 16 KB chunk. So a
# deny can always be satisfied on the next call. That is the whole safety argument, and it is why this
# hook is a deny rather than the weaker instrumentation option. (The plugin replaces the result of a
# large UNBOUNDED Read with a search pointer, so this gate refuses an unbounded Read of the snapshot,
# the step file or the digest at any size, naming the chunk.)
#
# IN FULL MEANS COVERED, NOT ONE UNBOUNDED CALL. The mandate says "in full" and the first shipped
# version of this gate joined on tool name and path only, so `Read <step file> limit=1` cleared
# the marker exactly as a full Read did; the second demanded a Read with neither field, which the
# plugin denies for the two files that matter (60251 B snapshot, 99600 B step file measured), so
# plugin and gate left no admissible Read. Now every Read of the snapshot or the step file that
# carries `offset` or `limit` is CREDITED with the lines it loads (`offset` to `offset+limit-1`, an
# absent offset 1, an absent limit 2000 lines), and a file is satisfied when the credited ranges are contiguous from line 1 to
# its last line at judge time, a last line with no newline counting. The skip the old test caught,
# stopping partway, is caught instead by the marker staying armed until coverage completes: every
# other call is denied until then, and the deny names the next uncovered range.
#
#   - Credits are per ROLE (`snap`, `step`), one append-only record per call, written only when the
#     call's path (`./` and `//` collapsed) IS the marker-resolved path. No record is ever read,
#     modified and rewritten, so parallel chunk Reads issued together lose none. Each carries the
#     file's size and mtime; a record whose identity no longer matches is ignored, so an edited
#     file is owed again. `ai-dlc-recover.sh` removes all of them with the stage file when a new
#     recovery starts, the satisfying call removes them with the marker, and so does the stand-down.
#   - Stage and satisfaction are re-derived from coverage on EVERY call: the snapshot covered means
#     stage `step` for whichever call this is, and only a Read of the step file satisfies. A step
#     chunk under stage `snapshot` is credited and allowed, never satisfying (BL-687), except for
#     handoff.md, which stays denied there. With the step file covered but unsatisfied, every deny
#     names the LAST chunk, never an offset past the end.
#   - A bounded call is credited only when its range spans at most 16384 bytes (or is one line). A
#     larger one is allowed and credits nothing, and so is a non-integer or non-positive
#     `offset`/`limit`. An UNBOUNDED Read of the snapshot or the step file, at any size, is denied
#     naming the next uncovered chunk and credits nothing, because the plugin replaces an unbounded
#     Read result over a size with a pointer. An unbounded digest Read (either layout), at any size,
#     is denied naming chunk 1. With the snapshot covered, an unbounded snapshot or digest Read is
#     denied naming the step file's next owed chunk (its last once covered), the call that advances
#     the recovery. The digest is never credited; its bounded Reads are allowed at both
#     stages. No size threshold is used: one would key on a single plugin version's internals (2.1.7
#     replaces over 4096 bytes; an installed 2.1.5 differs), and a size-independent rule needs no
#     plugin constant.
#   - A handoff.md step chunk at stage `snapshot` is denied, so it is credited only once the snapshot
#     is covered; a denied chunk advances nothing.
#   - A failed credit write stands the recovery down: the marker is unlinked (BL-725) and a stderr
#     WARN is printed. It never denies.
#
# RESIDUALS, recorded and not fixed. Crediting happens at PreToolUse, which records INTENT, so a
# Read that a later PreToolUse hook denies is still credited. A line over 2000 characters is
# truncated by the Read tool and credited whole. PostToolUse crediting was rejected: a consumer
# whose settings registration lags the hook file would never credit and so wedge every recovery.
# A chunk's byte count is taken over the file's lines, so it ignores the Read tool's line-number
# prefix. A redundant handoff.md chunk whose PreToolUse starts after the satisfying call has finished
# can still leave at the marker re-test with no breadcrumb.
#
# THE BREADCRUMB (handoff.md). `ai-dlc-handoff-entry.sh` arms `.handoff-in-progress` on a Read of
# steps/handoff.md that no breadcrumb marks as compelled. Every Read of a recovery's handoff.md
# step file at stage `step` therefore writes `.recover-satisfied.<tool_use_id>`, and the entry hook
# consumes only its own call's; without an id the call writes the shared `.recover-satisfied` on
# the satisfying call instead, which is also the file the entry hook falls back to. With the snapshot
# covered, the bounded chunk writes its breadcrumb before its credit, so a sibling that satisfies in
# between cannot leave it without one.
#
# WHAT IT DOES NOT DO. It does not police the THIRD mandated Read -- the post-compact digest,
# `.claude/skills/ai-dlc/postcompact-digest.md`, which the injected text asks for and which
# this hook cannot establish the necessity of from outside. Nor does it police the Read of
# SKILL.md the block asks for on top of that, which is CONDITIONAL by design: it is per-rule,
# taken when the lead is about to act on something the digest only indexes, and a gate cannot
# know from a tool call which rule the lead is about to lean on.
#
# THE ADVISOR STAGE (touchpoint R, BL-545). SKILL.md Rule 32 R: "After the
# `postcompact-digest.md` Read ... call the advisor in the same turn, before your first
# dispatch or write." Measured on the reference consumer: a lead read the snapshot, the step
# file and the digest, dispatched 12 remediators, and called the advisor a minute later, in
# its own words "I haven't made the post-recovery advisor call (touchpoint R) yet". The read
# stages above let the first call after the step Read through, and nothing held the dispatch.
#
# So the call that satisfies the step mandate also writes `.recover-advisor-owed` (the
# session id and a deny count), but only when a `postcompact-digest.md` is readable in either
# layout -- that call is always the LEAD's, because a teammate never reaches the read stages; `.recover-satisfied` is still written
# as before. While that file exists and the read marker does not, an `Agent`, `Task`,
# `TaskCreate`, `Write`, `Edit`, `MultiEdit` or `NotebookEdit` call FROM THE LEAD is judged on the lead's
# transcript: if a Read of `skills/ai-dlc/postcompact-digest.md` follows the last
# `compact_boundary` and no advisor attempt follows that Read, it is DENIED. Every other tool
# is untouched -- the wait-beat a teammate row requires is a Bash call, and R puts it BEFORE the
# advisor call. An advisor attempt after the digest Read clears the stage and deletes the file.
#
# THE DETECTION IS THE ADVISOR GATE'S, loaded from the sibling library both gates source,
# `ai-dlc-advisor-detect.sh` (BL-1136): an attempt is a `server_tool_use` named `advisor`, the
# grant is the latest `advisor_tool` attachment, a latest `advisor_tool_result` whose
# `error_code` is `unavailable` means the harness withdrew the tool, a consult is a `tool_use`
# named `mcp__advisor__consult`, and the lead HOLDS the consult when the latest
# `deferred_tools_delta` naming it adds it, or none names it and a consult is on disk. A block is
# credited only on an `assistant` line, so an `api-request-blob` line re-carrying an earlier
# attempt clears nothing (BL-1137). The library unreadable -> a stderr WARN and the call allowed.
# As in the advisor gate, a GRANTED lead is cleared by a built-in attempt only, and a lead with
# NO GRANT that holds the consult is cleared by a consult only; its deny names that tool.
#
# IT CANNOT WEDGE, by the same argument the read stages make: the action that clears it, an
# advisor call, is available whenever it is enforced, and every state where it is not stands
# the stage down. No grant line, or a withdrawn grant, AND no consult held -> the file is
# deleted and the call allowed (a lead on a local model with no advisor owes no R). A granted
# lead's latest result of `unavailable` -> allowed. No
# digest Read since the compaction -> allowed (this stage does not police that Read, the
# injected block does). A teammate (`agent_id` set) -> allowed; R binds the lead. A different
# `session_id` from the one recorded -> the file is stale; deleted, allowed. No readable
# transcript -> allowed. A LEAD THAT HOLDS NEITHER ADVISOR IS NEVER HELD.
#
# THE BOUNDED ESCAPE, because one state is not covered by the grant line: a lead granted the
# tool that then switches to a model without it, where the harness may write no withdrawal.
# Measured on the reference consumer's 174 lead transcripts: 181 grant lines and 0 remove
# lines; 6 transcripts change model, every one local -> Anthropic and none Anthropic -> local
# after a live grant, so the wedge state has 0 recorded instances there -- which is a corpus
# fact, not a guarantee (the advisor gate's header measured a remove line on a `--resume`
# switch to a local model; a `/model` switch was not measured). So the stage refuses at most
# R_MAX_DENIES (3) MESSAGES per recovery and then stands down; each deny says so and names the
# `RECOVERY-SKIP: advisor -- <why>` disclosure for a lead that holds no advisor tool. It counts
# messages, not calls (BL-730, THE RACE below): every call of a refused message is refused, and
# the message spends one of the three.
#
# REGISTRATION. The settings template registers this hook with matcher `*`, so every tool in
# the deny set reaches it; no registration was added.
#
# THE LEAD AND ITS TEAMMATES (BL-590). Both stages bind the lead only. A teammate (`agent_id`
# set) leaves the read path before any stage is read, so it is never refused and its Reads
# never advance or disarm the lead's recovery; the advisor stage has its own stand-down. The
# measurement and the case are at the exit, after the INPUT read.
#
# WHOSE RECOVERY. The read stages used to gate EVERY session in the tree, because the marker
# carried no owner and nothing asked what kind of session was calling. Measured on the reference
# consumer's 179 transcripts: of 78 whose last ai-dlc marker is the updater, 2 were denied the
# snapshot mandate (30 transcripts corpus-wide got it) -- one after real compactions, one with no
# compact_boundary at all, denied 11 seconds after /ai-dlc-update by a marker another session left.
# So the read stages now stand down, WITHOUT deleting the marker (it may be a real lead's pending
# recovery), for (1) a call whose session_id differs from the one the marker records and (2) a
# call whose own transcript's last ai-dlc marker is the updater (the I126 scan). A marker with
# no session_id, or a call with none, keeps the old behaviour. The advisor stage needs neither:
# it is armed only by the call that satisfied the reads, is keyed on that session_id and
# deletes its file for any other, and an update session never satisfies the step Read. The
# teammate exit above (BL-590, `agent_id`) runs first, so the owner key never has to separate a
# teammate from its lead -- which it could not be relied on to do: subagent transcript files record
# the PARENT's sessionId, and what a teammate's PreToolUse stdin carries was never measured.
#
# THE RACE. The incoming call's own message is not on disk when PreToolUse fires, so an advisor
# call in the same message may not be visible yet. MEASURED (BL-730, graph transcript a367e62c):
# one message carried 19 Agent calls; the harness ran each call's PreToolUse as that block
# finished streaming, about 7s apart and overlapping the earlier calls' hooks, while the message
# still streamed; and the message's lines reached disk TOGETHER, at message end. Calls 1-17 each
# hit the old 10s net and were dispatched uncounted; only calls 18 and 19, still waiting at the
# flush around 05:57:24, were refused. So no sibling line lands before a call's own line -- they
# flush together -- and the wait has to outlast the message, not a clock.
#
# So a DENY waits for the incoming call's own `tool_use` line, polled with a cheap `grep -F` of
# its id (0.25s ticks for 2s, then 1s) and re-judged with the full scan only once the id is on
# disk; an ALLOW is final at once. R_NET bounds the wait, default 300s: below the harness's 600s
# default hook timeout, so the hook answers before the harness abandons it, and above graph's
# 131s 19-call message. The net is a BOUND, not a ceiling whose expiry denies: expiry with the
# line still absent stands the stage down for that call, uncounted (BL-630), and two expiries in
# one recovery delete the owed file, which bounds the stall at 2 x R_NET. A call whose input
# carries no `tool_use_id` can never be seen and is let through at once.
#
# ONE DECISION PER MESSAGE. The scan also reports the `message.id` of the incoming call's line,
# and a deny records it as `denied_msg=`. After the wait the hook RE-READS the owed file: a call
# whose message is the one already refused is denied without counting again, and the bounded
# escape is checked there too, so it stands down only for a NEW message. The concurrent hooks of
# one message wake on the same flush and write identical content, so their race is idempotent. A
# line with no message id counts every time. COST: in an owed message the dispatches start when
# the message's lines land, up to R_NET later, rather than as each block streams. A same-message
# advisor call lands in the same flush and acquits as before. LIMIT: at ~7s per streamed block,
# the 300s net covers a message of about 43 calls; past that the first calls expire, and after the
# second expiry the stage stands down for the recovery. The deny reason says to call the advisor
# in a message of its own, which is the shape that never races.
#
# THE KNOB. `RECOVER_GATE_NET=<n>`, an integer 1..300, can only SHORTEN the net; anything else is
# 300. Shortening LOOSENS the stage -- more expiries, so more silent stand-downs -- which departs
# from `ADVISOR_GATE_REREADS` in `ai-dlc-advisor-gate.sh`, whose knob may only make that gate
# stricter. It is acceptable here because every expiry already fails open, so the knob adds no
# deny path; it exists so fixtures do not pay the full net.
#
# It does not read the lead's prose, so the RECOVERY-SKIP disclosure the block
# requires is not verifiable here -- that disclosure covers exactly the cases where this gate
# could not arm, and the block says so.
#
# PROTOCOL. PreToolUse hook: reads the tool call as JSON on stdin, emits a JSON decision on
# stdout. Deny is `permissionDecision: "deny"`, never exit code 2 -- the contract
# `ai-dlc-protect.sh` established and four other guards follow. Silence (exit 0, no output)
# leaves the call to the harness's normal permission flow.
#
# Compatible with bash 3.2. Requires jq; without it the hook exits silently rather than
# guessing at the payload, because a guard that cannot read its input must not deny.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
MARKER="${STATE_DIR}/.recover-fired"
PROGRESS="${STATE_DIR}/.recover-gate-progress"
OWED="${STATE_DIR}/.recover-advisor-owed"
R_MAX_DENIES=3
# The digest the stage keys on, in either layout. Unreadable in both -> the stage never arms.
digest_readable() {
  [ -r "${PROJECT_DIR}/.claude/skills/ai-dlc/postcompact-digest.md" ] \
    || [ -r "${PROJECT_DIR}/core/skills/ai-dlc/postcompact-digest.md" ]
}
# owed_put <session_id> <denies> [denied_msg] [expired] -- the ONE writer of the owed file.
# It writes a sibling temp, `${OWED}.<pid>`, and renames it into place, so the concurrent hooks
# of one message (header: THE RACE) never read a half-written file. A failed write removes the
# temp, warns on stderr naming the hook and the file, and never denies: an unwritten arm leaves
# the stage disarmed (fail open), and an unwritten count leaves the next deny at the same count.
owed_put() {
  { printf 'session_id=%s\ndenies=%s\ndenied_msg=%s\nexpired=%s\n' "$1" "$2" "${3:-}" "${4:-0}" > "${OWED}.$$" \
      && mv -f "${OWED}.$$" "$OWED"; } 2>/dev/null \
    || { rm -f "${OWED}.$$" 2>/dev/null; echo "WARN: ai-dlc-recover-gate: could not write $OWED" >&2; }
}
# owed_get <key> -- one value from the owed file, empty if absent.
owed_get() { sed -n "s/^$1=//p" "$OWED" 2>/dev/null | head -1; }

# --- THE ADVISOR STAGE (header: THE ADVISOR STAGE) ---------------------------------------
# Runs only once the read stages have disarmed (no marker) and left the owed file behind, so
# it costs one `[ -f ]` on every ordinary call and never overlaps a read stage.
if [ ! -f "$MARKER" ] && [ -f "$OWED" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  R_IN="$(cat 2>/dev/null || true)"
  R_TOOL=""; R_AID=""; R_SID=""; R_TP=""; R_TUID=""
  R_P="$(printf '%s' "$R_IN" | jq -r '@sh "R_TOOL=\((.tool_name // "") | tostring) R_AID=\((.agent_id // "") | tostring) R_SID=\((.session_id // "") | tostring) R_TP=\((.transcript_path // "") | tostring) R_TUID=\((.tool_use_id // "") | tostring)"' 2>/dev/null)" || exit 0
  eval "$R_P"
  case "$R_TOOL" in Agent|Task|TaskCreate|Write|Edit|MultiEdit|NotebookEdit) : ;; *) exit 0 ;; esac
  [ -z "$R_AID" ] || exit 0
  R_OSID="$(sed -n 's/^session_id=//p' "$OWED" 2>/dev/null | head -1)"
  if [ -n "$R_OSID" ] && [ -n "$R_SID" ] && [ "$R_OSID" != "$R_SID" ]; then
    rm -f "$OWED" 2>/dev/null || true
    exit 0
  fi
  [ -n "$R_TP" ] && [ -r "$R_TP" ] || exit 0
  # THE DETECTION IS THE ADVISOR GATE'S, loaded from the one sibling library both gates source.
  _AI_DLC_DETECT="${BASH_SOURCE[0]:-$0}"; case "$_AI_DLC_DETECT" in */*) _AI_DLC_DETECT="${_AI_DLC_DETECT%/*}/ai-dlc-advisor-detect.sh" ;; *) _AI_DLC_DETECT=./ai-dlc-advisor-detect.sh ;; esac
  ADV_DETECT_JQ=""
  { [ -r "$_AI_DLC_DETECT" ] && . "$_AI_DLC_DETECT"; } 2>/dev/null
  [ -n "$ADV_DETECT_JQ" ] || { echo "WARN: ai-dlc-recover-gate: the advisor detection library is unreadable ($_AI_DLC_DETECT); touchpoint R is not enforced on this call" >&2; exit 0; }
  # One pass: grant (latest advisor_tool attachment), dig (line of the last digest Read after
  # the last compact_boundary, 0 if none), adv (line of the last advisor attempt), res (U when
  # the latest advisor result is `unavailable`), seen (the incoming call's own line is on disk),
  # mid (that line's `message.id`; `-` when it carries none or is not on disk), mcp (line of the
  # last `mcp__advisor__consult`), held (1 when the lead holds the consult). Blocks are credited
  # only through `adv_blocks`, so an `api-request-blob` line credits nothing.
  r_scan() {
    jq -n -R -r --arg tuid "$R_TUID" "$ADV_DETECT_JQ"'
      reduce (inputs | (fromjson? // empty) as $l | select(($l | type) == "object") | [input_line_number, $l]) as [$n, $l]
        ({grant: null, dig: 0, adv: 0, res: "-", seen: 0, mid: "-", roster: null, mcp: 0};
         if adv_attach($l) then adv_fold($l)
         elif ($l.type == "system" and $l.subtype == "compact_boundary") then .dig = 0
         else
           reduce adv_blocks($l) as $b (.;
             if ($b | adv_attempt) then .adv = $n
             elif ($b | adv_res) != null then .res = ($b | adv_res)
             elif ($b | adv_consult) then .mcp = $n
             elif ($b.type == "tool_use" and $b.name == "Read"
                   and ((($b.input.file_path // "") | tostring) | test("(^|/)skills/ai-dlc/postcompact-digest\\.md$"))) then .dig = $n
             elif ($b.type == "tool_use" and $tuid != "" and (($b.id // "") | tostring) == $tuid) then
               .seen = 1 | .mid = ((($l.message.id? // "") | tostring | gsub("[[:space:]]"; "")) | if . == "" then "-" else . end)
             else . end)
         end)
      | "\(if .grant == null then "none" elif .grant then "on" else "off" end) \(.dig) \(.adv) \(.res) \(.seen) \(.mid) \(.mcp) \(if adv_held then 1 else 0 end)"' "$R_TP" 2>/dev/null
  }
  # r_judge: sets R_V to allow | clear | owed from R_STATE, and R_ARMED to 1 when the lead holds
  # an advisor the stage can demand: the built-in grant, or (no grant) the MCP consult.
  # A granted lead is cleared by a built-in attempt only and stands down on `unavailable`; a
  # no-grant lead that holds the consult is cleared by a consult only, as in the advisor gate.
  r_judge() {
    read -r R_GRANT R_DIG R_ADV R_RES R_SEEN R_MID R_MCP R_HELD <<<"$R_STATE"
    R_ARMED=0
    if [ "${R_GRANT:-none}" = on ] || [ "${R_HELD:-0}" = 1 ]; then R_ARMED=1; fi
    R_V=owed
    [ "${R_DIG:-0}" -gt 0 ] 2>/dev/null || R_V=allow
    if [ "${R_GRANT:-none}" = on ]; then
      if [ "$R_V" = owed ] && [ "${R_ADV:-0}" -gt "${R_DIG:-0}" ] 2>/dev/null; then R_V=clear; fi
      if [ "$R_V" = owed ] && [ "${R_RES:--}" = U ]; then R_V=allow; fi
    else
      if [ "$R_V" = owed ] && [ "${R_MCP:-0}" -gt "${R_DIG:-0}" ] 2>/dev/null; then R_V=clear; fi
    fi
    return 0
  }
  R_STATE="$(r_scan)" || exit 0
  [ -n "$R_STATE" ] || exit 0
  r_judge
  # THIS CHECK IS A PERFORMANCE FAST-PATH, NOT THE BEHAVIOURAL GUARD: a lead holding neither
  # advisor is let through at once instead of after the wait. The post-wait check below decides
  # the same verdict, and the fixture asserts the cost of this line directly (a_nogrant).
  if [ "$R_ARMED" != 1 ]; then rm -f "$OWED" 2>/dev/null || true; exit 0; fi
  # THE DENY IS DECIDED BY R_SEEN, NEVER BY THE CLOCK (BL-630; header: THE RACE). R_NET bounds the
  # stall and is not a ceiling whose expiry denies: the line being waited for lands when its whole
  # message flushes, and a timed deny refused a correct same-message advisor call. Expiry with the
  # incoming call's own line still absent is a transcript this stage cannot read, and it stands
  # down for that call -- no deny, no count, the file kept, so the next dispatch is judged again --
  # until the recovery's second expiry, which deletes the file. An input with no `tool_use_id` can
  # never be seen, so it is let through at once rather than after the whole net.
  if [ "$R_V" = owed ] && [ -z "$R_TUID" ]; then exit 0; fi
  R_NET=300
  case "${RECOVER_GATE_NET:-}" in
    ''|*[!0-9]*) : ;;
    *) if [ "$RECOVER_GATE_NET" -ge 1 ] 2>/dev/null && [ "$RECOVER_GATE_NET" -le 300 ] 2>/dev/null; then R_NET=$((10#$RECOVER_GATE_NET)); fi ;;
  esac
  # A tick is a `grep -F` of the call's id and forks no jq; the full scan re-runs only once the
  # id is on disk, and the poll continues while that line is not yet parseable (seen still 0).
  # The net is counted in slept quarter seconds (`_rq`), because SECONDS ticks on wall-clock second
  # boundaries and alone can cut the wait up to a second short; SECONDS bounds only a box so loaded
  # that the sleeps themselves overrun, at one second past the net.
  # TEST-ONLY SEAM: AI_DLC_TEST_RECOVER_GATE_NO_WALL=1 (the literal 1, nothing else) DROPS that
  # SECONDS clause, so the wait ends on the slept-tick bound or the verdict alone and a fixture that
  # drives the loop through its own `sleep` shim reaches a fixed tick however loaded the box is. It
  # never widens `_rq` or R_NET. Only fixtures set it; unset, the bounds, output and exit are unchanged.
  _rt0=$SECONDS; _rq=0; _rw=1
  case "${AI_DLC_TEST_RECOVER_GATE_NO_WALL:-}" in 1) _rw=0 ;; esac
  while [ "$R_V" = owed ] && [ "${R_SEEN:-0}" != 1 ] && [ "$_rq" -lt $((R_NET * 4)) ] && { [ "$_rw" = 0 ] || [ $((SECONDS - _rt0)) -le "$R_NET" ]; }; do
    if [ "$_rq" -lt 8 ]; then sleep 0.25; _rq=$((_rq + 1)); else sleep 1; _rq=$((_rq + 4)); fi
    _rn="$(grep -cF -- "$R_TUID" "$R_TP" 2>/dev/null)" || _rn=0
    [ "${_rn:-0}" -gt 0 ] 2>/dev/null || continue
    R_S2="$(r_scan)" || R_S2=""
    [ -n "$R_S2" ] && R_STATE="$R_S2"
    r_judge
  done
  if [ "$R_V" = clear ]; then rm -f "$OWED" 2>/dev/null || true; exit 0; fi
  # A GRANT WITHDRAWN DURING THE WAIT: the loop refreshed R_ARMED through r_judge, so a remove-grant attachment that landed with the call's own line allows the call unless the lead holds the consult.
  [ "$R_ARMED" = 1 ] || { rm -f "$OWED" 2>/dev/null || true; exit 0; }
  [ "$R_V" = owed ] || exit 0
  # RE-READ AFTER THE WAIT. The other hooks of this call's message may have written the owed file
  # while this one waited, or an advisor attempt or a new recovery removed it, so every decision
  # below reads the file as it is NOW, never the values read before the wait.
  [ -f "$OWED" ] || exit 0
  R_DENIES="$(owed_get denies)"; case "$R_DENIES" in ''|*[!0-9]*) R_DENIES=0 ;; esac
  R_EXP="$(owed_get expired)"; case "$R_EXP" in ''|*[!0-9]*) R_EXP=0 ;; esac
  R_DMSG="$(owed_get denied_msg)"
  if [ "${R_SEEN:-0}" != 1 ]; then
    R_EXP=$((R_EXP + 1))
    if [ "$R_EXP" -ge 2 ]; then
      rm -f "$OWED" 2>/dev/null || true
      echo "ai-dlc-recover-gate: the incoming call's own transcript line did not land within the ${R_NET}s safety net ($R_TP) for the second time in this recovery, so touchpoint R stands down for the rest of it" >&2
      exit 0
    fi
    owed_put "$R_OSID" "$R_DENIES" "$R_DMSG" "$R_EXP"
    echo "ai-dlc-recover-gate: the incoming call's own transcript line did not land within the ${R_NET}s safety net ($R_TP); its message may still hold the advisor attempt, so touchpoint R is not enforced on this call" >&2
    exit 0
  fi
  # ONE COUNT PER MESSAGE (header: THE RACE). A call of the message already refused is refused at
  # the same count. A new message meets THE BOUNDED ESCAPE (header: THE ADVISOR STAGE) here, after
  # the wait, and is then counted. A line with no message id (`-`) counts every time and never
  # writes denied_msg.
  if [ "${R_MID:--}" != - ] && [ "$R_MID" = "$R_DMSG" ]; then
    R_N="$R_DENIES"
  else
    if [ "$R_DENIES" -ge "$R_MAX_DENIES" ]; then
      rm -f "$OWED" 2>/dev/null || true
      exit 0
    fi
    R_N=$((R_DENIES + 1))
    [ "${R_MID:--}" = - ] || R_DMSG="$R_MID"
    owed_put "$R_OSID" "$R_N" "$R_DMSG" "$R_EXP"
  fi
  if [ "${R_GRANT:-none}" = on ]; then
    R_ASK="Call the advisor in a message of its own, read its answer, then retry the same call. Any advisor attempt clears this, including one that errors; if the advisor answers 'unavailable' this gate stands down. You hold the built-in advisor tool, so call it; a call to mcp__advisor__consult does not clear this."
  else
    R_ASK="You have no built-in advisor grant but hold mcp__advisor__consult: call mcp__advisor__consult in a message of its own, read its answer, then retry the same call. Any consult clears this, including one that errors."
  fi
  jq -n --arg m "AI/DLC post-compact recovery: SKILL.md Rule 32 touchpoint R is owed. You read postcompact-digest.md after this compaction and have made no advisor call since, so this ${R_TOOL} call -- a dispatch or a write -- is refused (message ${R_N} of ${R_MAX_DENIES}; every call of a refused message is refused, and the message counts once). ${R_ASK} If you hold no advisor tool, say so in one line (RECOVERY-SKIP: advisor -- <why>) and retry: after ${R_MAX_DENIES} refused messages this stage stands down. Arming a wait-beat (Bash) is not refused and belongs before the advisor call." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $m}}'
  exit 0
fi

# Inert unless a compaction is actually pending recovery. This is the common case by a very
# large margin and it must cost nothing.
#
# THIS CHECK IS A PERFORMANCE FAST-PATH, NOT THE BEHAVIOURAL GUARD, and that distinction is
# recorded because a mutant proved it: deleting this line alone changes NO verdict. With the
# marker absent every `mval` returns empty and the key checks below stand the hook down for
# the same cases. What the line actually buys is that an ordinary tool call in an ordinary
# session -- which is nearly all of them, on a hook registered against every tool -- returns
# here without forking `jq`, reading stdin, or running four `sed` passes.
#
# So it is not a vacuous guard to be deleted by the next reader tidying up; its subject is
# cost, and the fixture asserts that subject directly rather than through a verdict flip.
[ -f "$MARKER" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

# THE READ STAGES BIND THE LEAD ONLY (BL-590). The marker is project-wide and the matcher is
# `*`, so before this line a TEAMMATE's call during the lead's pending recovery was refused with
# text addressed to the lead -- measured on the reference consumer: 253 such denials across 113
# subagent transcripts. And a teammate's Reads ADVANCED the lead's stages: in graph session
# d5ba4ec4 a teammate's full Read of the step file cleared the marker, the lead's first
# post-compact calls included an Edit of pipeline-snapshot.md with no deny, and the lead read
# its step file two minutes later. A teammate reading the snapshot reloads nothing into the
# lead's context, so it neither is refused nor counts toward the recovery: it leaves here, before
# any stage is read, advanced or denied. `.agent_id` is set only on a call made inside a
# dispatched teammate, as `ai-dlc-acknowledge.sh` reads it. Below the marker fast-path on
# purpose, so an ordinary call still forks nothing, and below the advisor stage, which carries
# its own teammate stand-down.
RG_AGENT="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)"
[ -z "$RG_AGENT" ] || exit 0

# --- what the injector recorded ----------------------------------------------------------
# Read as key=value lines, never sourced: `.` on a file in the project directory would execute
# whatever a consumer's tree happened to put there.
mval() { sed -n "s/^$1=//p" "$MARKER" 2>/dev/null | head -1; }

# THE UNARMABLE READ IS ONE FORK, NOT THREE, AND THE ORDER IS THE WHOLE REASON. A recovery the
# injector REFUSED -- it names no step file, or its Pipeline Position named more than one and
# ai-dlc-recover.sh declined to pick -- leaves a marker on disk for the rest of the session,
# because that marker is ai-dlc-postcompact.sh's record that the injection happened and deleting
# it would make the compaction log under-report. So `[ -f "$MARKER" ]` above stops being the
# fast path for those sessions: every later tool call reaches here. Reading all three keys
# before testing any of them spent two `sed` forks per call to learn something the first key
# already decided. The stand-down checks are unchanged in effect and each still has its own
# line, which is what keeps them separately mutable.
STEP_RESOLVED="$(mval step_file_resolved)"

# A marker written before this hook existed carries none of these keys. Treat that exactly as
# "cannot arm" -- an older marker is not evidence about a mandate it never recorded.
[ "$STEP_RESOLVED" = "1" ] || exit 0

SNAP_REL="$(mval snapshot_path)"
STEP_REL="$(mval step_file)"

[ -n "$SNAP_REL" ] || exit 0
[ -n "$STEP_REL" ] || exit 0

# TWO STAND-DOWNS FOR A CALL THIS RECOVERY IS NOT OWED TO (header: WHOSE RECOVERY). Both sit
# ABOVE the readability block, because that block deletes the marker and a call that is not the
# lead's must never be the one to clear a recovery the lead still owes. Neither deletes anything.
# Both are keyed on the INCOMING call and fail toward the existing gate: an absent field, an
# unreadable transcript or a marker from before the key existed leaves the deny path as it was.
G_SID=""; G_TP=""
G_P="$(printf '%s' "$INPUT" | jq -r '@sh "G_SID=\((.session_id // "") | tostring) G_TP=\((.transcript_path // "") | tostring)"' 2>/dev/null)" && eval "$G_P"
# 1. A marker another session wrote. Both ids must be present and different.
M_SID="$(mval session_id)"
if [ -n "$M_SID" ] && [ -n "$G_SID" ] && [ "$M_SID" != "$G_SID" ]; then
  exit 0
fi
# 2. An update session, whatever wrote the marker: the recovery mandate is the lead's.
if [ -n "$G_TP" ] && [ -r "$G_TP" ]; then
  TRANSCRIPT="$G_TP"
  # >>> I126 SESSION-MARKER SCAN: the next line, byte-identical in every bound hook >>>
  LAST_SKILL=$(grep -oE '"role":"user","content":"<command-message>ai-dlc(-update)?</command-message>\\n<command-name>/ai-dlc(-update)?</command-name>|"name":"Skill","input":\{"skill":"ai-dlc(-update)?"' "$TRANSCRIPT" 2>/dev/null | tail -1)
  case "$LAST_SKILL" in
    *'/ai-dlc-update</command-name>'|*'"skill":"ai-dlc-update"') exit 0 ;;
  esac
fi

# ARMING PRECONDITION, RE-CHECKED ON EVERY CALL. If either mandated file is not readable now,
# the gate stands down permanently for this recovery: it clears the marker so it does not
# re-arm, and lets the call through. Denying a Read of something absent is the wedge.
# norm collapses `//` and `/./` (and a trailing `/.`), so `./x`, `a//b` and `a/./b` meet the plain form.
norm() {
  local _p="$1" _d='//' _s='/' _dot='/./'
  while :; do
    case "$_p" in
      *//*) _p="${_p//$_d/$_s}" ;;
      */./*) _p="${_p//$_dot/$_s}" ;;
      *) break ;;
    esac
  done
  case "$_p" in */.) _p="${_p%/.}" ;; esac
  printf '%s\n' "$_p"
}
resolve() { case "$1" in /*) norm "$1" ;; *) norm "${PROJECT_DIR}/$1" ;; esac; }
SNAP_ABS="$(resolve "$SNAP_REL")"
STEP_ABS="$(resolve "$STEP_REL")"
if [ ! -r "$SNAP_ABS" ] || [ ! -r "$STEP_ABS" ]; then
  rm -f "$MARKER" "$PROGRESS" "${STATE_DIR}"/.recover-credit* 2>/dev/null || true
  exit 0
fi
# AN UNWRITABLE STATE DIRECTORY STANDS THE GATE DOWN FOR THIS CALL (BL-688). Every way out of a
# recovery is a write under `$STATE_DIR` -- the snapshot Read advances the stage, the step Read
# removes the marker -- so with the directory unwritable the snapshot Read was allowed, advanced
# nothing, and every later call was denied FIRST forever; a directory made unwritable after the
# stage reached `step` wedged the same way at SECOND. Neither clearing the marker nor arming only
# when writable closes it: a removal cannot act in that directory, and an arming-time test cannot
# see a chmod made later. So the test is per call, deletes nothing, and the gate re-arms by itself
# the moment the directory is writable again.
[ -w "$STATE_DIR" ] || exit 0

RG_P="$(printf '%s' "$INPUT" | jq -r '(.tool_input // {}) as $ti | @sh "TOOL=\((.tool_name // "") | tostring) FPATH=\(($ti.file_path // "") | tostring) HAS_OFF=\(if ($ti.offset // null) == null then 0 else 1 end) OFFSET=\(($ti.offset // "") | tostring) HAS_LIM=\(if ($ti.limit // null) == null then 0 else 1 end) LIMIT=\(($ti.limit // "") | tostring) RG_TUID=\((.tool_use_id // "") | tostring)"' 2>/dev/null)" || exit 0
TOOL=""; FPATH=""; HAS_OFF=0; OFFSET=""; HAS_LIM=0; LIMIT=""; RG_TUID=""
eval "$RG_P"
# Normalise the call's path the same way as the mandated ones (`./` and `//` collapsed), so
# `Read _bmad-output/x.md` and an absolute form of the same file are one answer. A gate that matched
# only one spelling would deny a compliant call, which is a wedge wearing a different hat.
FABS=""
[ -n "$FPATH" ] && FABS="$(resolve "$FPATH")"

# COVERAGE, NOT ONE UNBOUNDED CALL (header: IN FULL MEANS COVERED). A Read of a mandated file is
# credited with the lines it loads, as its own record `${STATE_DIR}/.recover-credit.<role>.<pid>.<n>`
# holding `<first> <last> <size>-<mtime>`. The role is `snap` or `step`, never a name derived from
# the path, and a record is written only when the call's normalised path IS the marker-resolved
# path of that role. One file per call, never a read-modify-write of a shared file, so parallel
# chunk Reads issued together lose nothing (the BL-658 shape). A record whose size-mtime no longer
# matches the file is ignored at judge time, so an edited file is owed again.
CHUNK_CAP=16384      # bytes: the context-mode size guard and one chunk's ceiling
READ_DEFAULT=2000    # lines a Read with no limit loads
isint() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; [ "${#1}" -le 9 ] && [ "$((10#$1))" -ge 1 ]; }
fid() { # fid <file> -> "<bytes>-<mtime>"; fails when either is unreadable
  local _s _m
  _s="$(wc -c < "$1" 2>/dev/null)" || return 1
  _s="${_s//[[:space:]]/}"
  _m="$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null)" || return 1
  [ -n "$_s" ] && [ -n "$_m" ] || return 1
  printf '%s-%s' "$_s" "$_m"
}
nlines() { awk 'END { print NR + 0 }' "$1" 2>/dev/null; }
# range_bytes <file> <first> <last> -> the bytes of those lines, newline counted per line
range_bytes() { LC_ALL=C awk -v a="$2" -v b="$3" 'NR >= a && NR <= b { s += length($0) + 1 } NR > b { exit } END { print s + 0 }' "$1" 2>/dev/null; }
# chunk_of <file> <next-uncovered-line | 0> -> "<offset> <limit>": the chunk starting at that line,
# or (0) the file's LAST chunk. At most CHUNK_CAP bytes and READ_DEFAULT lines, never fewer than 1 line.
chunk_of() {
  LC_ALL=C awk -v nx="$2" -v cap="$CHUNK_CAP" -v mx="$READ_DEFAULT" '
    { L[NR] = length($0) + 1 }
    END {
      n = NR; if (n == 0) { print "1 1"; exit }
      b = 0; c = 0
      if (nx > 0) { s = (nx > n) ? n : nx; for (i = s; i <= n; i++) { if (c > 0 && (b + L[i] > cap || c >= mx)) break; b += L[i]; c++ } print s, c }
      else { for (i = n; i >= 1; i--) { if (c > 0 && (b + L[i] > cap || c >= mx)) break; b += L[i]; c++ } print n - c + 1, c }
    }' "$1" 2>/dev/null
}
# cov_next <role> <id> <lines> -> the first line the valid records of that role leave uncovered
# (lines+1 when 1..lines is covered). A record carrying another identity is ignored.
cov_next() {
  cat "${STATE_DIR}"/.recover-credit."$1".* 2>/dev/null | awk -v id="$2" -v n="$3" '
    $3 == id && $1 + 0 >= 1 && $2 + 0 >= $1 + 0 { k++; s[k] = $1 + 0; e[k] = $2 + 0 }
    END { nx = 1; do { ch = 0; for (i = 1; i <= k; i++) if (s[i] <= nx && e[i] >= nx) { nx = e[i] + 1; ch = 1 } } while (ch && nx <= n); print nx }'
}
rm_credits() { rm -f "${STATE_DIR}"/.recover-credit* 2>/dev/null || true; }
# credit <role> <id> <first> <last>: ONE new record, written whole then renamed into place. A failed
# write stands the recovery down (B2): the marker is unlinked, which needs no free space, a WARN goes
# to stderr, and nothing is denied.
credit() {
  local _t="${STATE_DIR}/.recover-credit-tmp.$$.${RANDOM}"
  { printf '%s %s %s\n' "$3" "$4" "$2" > "$_t" && mv -f "$_t" "${STATE_DIR}/.recover-credit.$1.$$.${RANDOM}"; } 2>/dev/null \
    || { rm -f "$_t" "$MARKER" 2>/dev/null || true
         echo "WARN: ai-dlc-recover-gate: could not record a Read credit under ${STATE_DIR}; the recovery gate stands down" >&2
         exit 0; }
}

IS_HO=0
case "$STEP_REL" in */steps/handoff.md|steps/handoff.md) IS_HO=1 ;; esac
DIG1="$(norm "${PROJECT_DIR}/.claude/skills/ai-dlc/postcompact-digest.md")"
DIG2="$(norm "${PROJECT_DIR}/core/skills/ai-dlc/postcompact-digest.md")"
IS_READ=0; [ "$TOOL" = "Read" ] && [ -n "$FABS" ] && IS_READ=1
ON_SNAP=0; ON_STEP=0; ON_DIG=0
if [ "$IS_READ" = 1 ]; then
  [ "$FABS" = "$SNAP_ABS" ] && ON_SNAP=1
  [ "$FABS" = "$STEP_ABS" ] && ON_STEP=1
  { [ "$FABS" = "$DIG1" ] || [ "$FABS" = "$DIG2" ]; } && ON_DIG=1
fi
SNAP_ID="$(fid "$SNAP_ABS")" || exit 0
STEP_ID="$(fid "$STEP_ABS")" || exit 0
SNAP_N="$(nlines "$SNAP_ABS")"; STEP_N="$(nlines "$STEP_ABS")"

# AN UNBOUNDED READ OF A MANDATED FILE IS REFUSED AT ANY SIZE, because the context-mode plugin
# replaces a large unbounded Read result with a search pointer, so such a Read can load nothing. The
# snapshot, the step file and the digest are all refused unbounded, with no size test, so the rule
# needs no plugin constant. The deny names the next uncovered chunk by number (the digest: chunk 1),
# the remedy the plugin withholds (it recommends a `ctx_*` tool). It credits and advances nothing.
OVER=0
if [ "$IS_READ" = 1 ] && [ "$HAS_OFF" = 0 ] && [ "$HAS_LIM" = 0 ] && [ $((ON_SNAP + ON_STEP + ON_DIG)) -gt 0 ]; then
  OVER=1
fi

# A handoff.md step chunk is credited only once the snapshot is covered, because at stage snapshot it is
# denied below and a denied call must not advance the recovery. A step call writes no snapshot credit,
# so the coverage read here is the live one.
SNAP_NX="$(cov_next snap "$SNAP_ID" "$SNAP_N")"
SNAP_COV=0; [ "${SNAP_NX:-1}" -gt "$SNAP_N" ] 2>/dev/null && SNAP_COV=1
# THE BREADCRUMB RACE: with the snapshot covered, a handoff.md chunk leaves its per-call breadcrumb
# BEFORE its credit, so a sibling chunk that satisfies and removes the marker in between cannot send
# this one out at the marker re-test with no breadcrumb.
_tu0="${RG_TUID//[^A-Za-z0-9_-]/}"
if [ "$IS_READ" = 1 ] && [ "$ON_STEP" = 1 ] && [ "$IS_HO" = 1 ] && [ "$SNAP_COV" = 1 ] && [ -n "$_tu0" ] \
   && { [ "$HAS_OFF" = 1 ] || [ "$HAS_LIM" = 1 ]; }; then
  if ! printf 'step_file=%s\n' "$STEP_REL" > "${STATE_DIR}/.recover-satisfied.${_tu0}" 2>/dev/null; then
    rm -f "${STATE_DIR}/.recover-satisfied.${_tu0}" 2>/dev/null
  fi
fi

# CREDIT THIS CALL. Only a call carrying `offset` or `limit` is credited, and only when its range spans
# at most CHUNK_CAP bytes (or is one line); a larger one, and a non-integer, zero or negative
# offset/limit, is ALLOWED and credits nothing. An unbounded call never reaches here (OVER). A
# handoff.md step chunk is credited only with the snapshot covered. The digest is never credited.
if [ "$IS_READ" = 1 ] && [ "$OVER" = 0 ] && [ $((ON_SNAP + ON_STEP)) -gt 0 ]; then
  for _role in snap step; do
    if [ "$_role" = snap ]; then [ "$ON_SNAP" = 1 ] || continue; _f="$SNAP_ABS"; _id="$SNAP_ID"; _n="$SNAP_N"
    else [ "$ON_STEP" = 1 ] || continue; { [ "$IS_HO" = 0 ] || [ "$SNAP_COV" = 1 ]; } || continue; _f="$STEP_ABS"; _id="$STEP_ID"; _n="$STEP_N"; fi
    _a=1; _e="$_n"; _ok=1
    if [ "$HAS_OFF" = 0 ] && [ "$HAS_LIM" = 0 ]; then
      _ok=0
    else
      if [ "$HAS_OFF" = 1 ]; then isint "$OFFSET" && _a=$((10#$OFFSET)) || _ok=0; fi
      if [ "$HAS_LIM" = 1 ]; then isint "$LIMIT" && _l=$((10#$LIMIT)) || _ok=0; else _l="$READ_DEFAULT"; fi
      if [ "$_ok" = 1 ]; then
        _e=$((_a + _l - 1)); [ "$_e" -gt "$_n" ] && _e="$_n"
        [ "$_a" -le "$_n" ] || _ok=0
      fi
      if [ "$_ok" = 1 ] && [ "$_e" -gt "$_a" ] && [ "$(range_bytes "$_f" "$_a" "$_e")" -gt "$CHUNK_CAP" ] 2>/dev/null; then _ok=0; fi
    fi
    if [ "$_ok" = 1 ] && [ "$_e" -ge "$_a" ]; then credit "$_role" "$_id" "$_a" "$_e"; fi
  done
fi

# STAGE AND SATISFACTION ARE RE-DERIVED FROM COVERAGE ON EVERY CALL. The snapshot covered means stage
# `step`, whichever call this is; the step file covered at stage `step` is satisfaction, taken only
# by a Read of the step file. `$PROGRESS` is kept as the record of the advance and decides nothing.
SNAP_NX="$(cov_next snap "$SNAP_ID" "$SNAP_N")"
STEP_NX="$(cov_next step "$STEP_ID" "$STEP_N")"
SNAP_COV=0; [ "${SNAP_NX:-1}" -gt "$SNAP_N" ] 2>/dev/null && SNAP_COV=1
STEP_COV=0; [ "${STEP_NX:-1}" -gt "$STEP_N" ] 2>/dev/null && STEP_COV=1
# THE MARKER IS RE-TESTED AFTER THE CREDITS ARE READ (BL-658): the satisfying call removes the marker
# first and the credits after, so a marker still on disk here proves the credits read above were
# the live ones. Before the read, a concurrent satisfaction empties them and this call is denied FIRST.
[ -f "$MARKER" ] || exit 0
STAGE=snapshot
if [ "$SNAP_COV" = 1 ]; then
  STAGE=step
  [ "$(cat "$PROGRESS" 2>/dev/null)" = step ] \
    || { printf 'step\n' >"${PROGRESS}.$$" && mv -f "${PROGRESS}.$$" "$PROGRESS"; } 2>/dev/null \
    || rm -f "${PROGRESS}.$$" 2>/dev/null || true
fi

# PROVENANCE MARKER -- PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL. The
# library is a SIBLING in both layouts (core/hooks/, .claude/hooks/), so this is a
# same-directory read and never a walk up from a resolved path. Fail-open: a hook
# that cannot mark its output still emits it.
_AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi

deny() {
  jq -n --arg reason "$1" --arg context "$(ai_dlc_provenance_wrap ai-dlc-recover-gate PreToolUse "$2")" \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason,
        additionalContext: $context
      }
    }'
  exit 0
}
# read_cmd <rel> <file> <next-uncovered-line | 0> -> the exact Read call the deny names
read_cmd() { local _o _l; read -r _o _l <<<"$(chunk_of "$2" "$3")"; printf 'Read %s offset=%s limit=%s' "$1" "$_o" "$_l"; }

if [ "$OVER" = 1 ]; then
  _on=1
  if { [ "$ON_SNAP" = 1 ] || [ "$ON_DIG" = 1 ]; } && [ "$SNAP_COV" = 1 ]; then _orel="$STEP_REL"; _of="$STEP_ABS"; if [ "$STEP_COV" = 1 ]; then _on=0; else _on="$STEP_NX"; fi
  elif [ "$ON_SNAP" = 1 ]; then _orel="$SNAP_REL"; _of="$SNAP_ABS"; _on="$SNAP_NX"
  elif [ "$ON_STEP" = 1 ] && [ "$STAGE" = snapshot ] && [ "$IS_HO" = 1 ]; then _orel="$SNAP_REL"; _of="$SNAP_ABS"; _on="$SNAP_NX"
  elif [ "$ON_STEP" = 1 ]; then _orel="$STEP_REL"; _of="$STEP_ABS"; if [ "$STEP_COV" = 1 ]; then _on=0; else _on="$STEP_NX"; fi
  else _orel="$FPATH"; _of="$FABS"; fi
  deny "AI/DLC post-compact recovery: an unbounded Read of \`${FPATH}\` is refused -- the context-mode plugin replaces the result of a Read with neither \`offset\` nor \`limit\` with a search pointer when the file is large, so it can load nothing. Read in consecutive chunks of at most ${CHUNK_CAP} bytes, next: \`$(read_cmd "$_orel" "$_of" "$_on")\`." \
"Use the native Read tool with offset and limit, never a \`ctx_*\` tool. The chunk is named above; each later chunk starts at the line after the previous one's last. This call credited nothing."
fi

case "$STAGE" in
  snapshot)
    # A snapshot chunk is allowed and was credited above; the stage advances on the call that covers it.
    [ "$ON_SNAP" = 1 ] && exit 0
    # THE DIGEST READ IS ALLOWED WITHOUT CREDIT AND WITHOUT ADVANCING (BL-658): the injected block
    # asks for it, and a lead that issues the Reads in parallel can have this call's hook run first.
    [ "$ON_DIG" = 1 ] && exit 0
    # A STEP READ AT STAGE `snapshot` IS ALLOWED AND CREDITED, NEVER SATISFYING (BL-687): a lead that
    # issues the snapshot and step Reads in parallel can have this call's hook run before the
    # snapshot is covered. EXCEPT handoff.md, which stays denied, chunks included:
    # `ai-dlc-handoff-entry.sh` arms `.handoff-in-progress` on a Read of it that no breadcrumb marks
    # as compelled, and a call at this stage writes none.
    if [ "$ON_STEP" = 1 ] && [ "$IS_HO" = 0 ]; then exit 0; fi
    deny "AI/DLC post-compact recovery: your FIRST tool call must be \`Read ${SNAP_REL}\` in full. This conversation was compacted and the summary is not the authoritative pipeline state. Next chunk: \`$(read_cmd "$SNAP_REL" "$SNAP_ABS" "$SNAP_NX")\`." \
"The snapshot is a verbatim-load file and the Read is the attention interrupt that
defeats reconstructing state from the summary. Read it with the native Read tool,
in consecutive offset/limit chunks of at most ${CHUNK_CAP} bytes covering line 1 to
the end -- never a \`ctx_*\` tool. Then \`Read ${STEP_REL}\` the same way. Both files
were confirmed present before this gate armed, and the chunk above is always
allowed, so complying is available to you on the next call; there is nothing here
to weigh."
    ;;
  step)
    if [ "$ON_STEP" = 1 ]; then
      # THE PER-CALL BREADCRUMB (header: THE BREADCRUMB). For handoff.md, every Read at this stage is
      # the recovery's own, so each call leaves `.recover-satisfied.<tool_use_id>` for the entry hook
      # that runs after it, which consumes only its own call's.
      _tu="${RG_TUID//[^A-Za-z0-9_-]/}"
      if [ "$IS_HO" = 1 ] && [ -n "$_tu" ]; then
        if ! printf 'step_file=%s\n' "$STEP_REL" > "${STATE_DIR}/.recover-satisfied.${_tu}" 2>/dev/null; then
          rm -f "${STATE_DIR}/.recover-satisfied.${_tu}" 2>/dev/null   # unwritten crumb: the entry hook arms (fail open)
        fi
      fi
      if [ "$STEP_COV" = 1 ]; then
        # SATISFIED. Clear all, so the gate is inert for the rest of the session until the next
        # compaction writes a fresh marker.
        #
        # THE BREADCRUMB IS WRITTEN BEFORE THE CLEAR, AND IT EXISTS FOR A HOOK THAT RUNS AFTER THIS
        # ONE. `ai-dlc-handoff-entry.sh` is PostToolUse on `Read`; this gate is PreToolUse on every
        # tool, and it removes the marker. The entry hook therefore cannot decide from `$MARKER`: it
        # would arm the handoff marker on a Read the recovery COMPELLED. So the state is handed
        # forward explicitly, and ONLY by a call this gate admitted. A lead that satisfied only the
        # first mandate and then opened the step file of its own accord is a genuine initiation and
        # must still arm, which the marker alone cannot tell apart.
        #
        # The shared `.recover-satisfied` is written for a step other than handoff.md (the entry
        # hook's gate-checkpoint rebind reads it) and for a handoff.md call that carried no
        # `tool_use_id`; the entry hook reads it as key=value, never sources it.
        if [ "$IS_HO" = 0 ] || [ -z "$_tu" ]; then
          if ! printf 'step_file=%s\n' "$STEP_REL" > "${STATE_DIR}/.recover-satisfied" 2>/dev/null; then
            rm -f "${STATE_DIR}/.recover-satisfied" 2>/dev/null   # unwritten crumb: the entry hook arms (fail open)
          fi
        fi
        # THE ADVISOR STAGE ARMS HERE (header: THE ADVISOR STAGE). Keyed on the session that
        # satisfied the reads, so another session's call in the same project stands it down.
        # Only the lead reaches this line (a teammate left at the BL-590 exit above), and a tree
        # with no readable digest does not arm it: R follows the digest Read, so without the
        # file R is not owed.
        if digest_readable; then
          owed_put "$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)" 0
        fi
        rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true
        rm_credits
        exit 0
      fi
      exit 0   # a step chunk, credited above, with the file not yet covered
    fi
    # Re-reading the snapshot is not progress, but it is not a violation either. Allow it.
    [ "$ON_SNAP" = 1 ] && exit 0
    # The digest Read: allowed without credit, as in the snapshot arm (BL-658).
    [ "$ON_DIG" = 1 ] && exit 0
    # A COVERED STEP FILE IS NEVER NAMED PAST ITS END: the deny names the last chunk, and the Read
    # of it satisfies.
    if [ "$STEP_COV" = 1 ]; then _sn=0; else _sn="$STEP_NX"; fi
    deny "AI/DLC post-compact recovery: your SECOND tool call must be \`Read ${STEP_REL}\` in full. Compaction cleared the harness's record of every file previously read, so the step file is not loaded no matter how recently you read it. Next chunk: \`$(read_cmd "$STEP_REL" "$STEP_ABS" "$_sn")\`." \
"Measured across 265 real compactions, this Read lands 41% of the time against the
snapshot Read's 66% -- it is the one most often skipped and the one this gate
exists for. Read it with the native Read tool in consecutive offset/limit chunks of
at most ${CHUNK_CAP} bytes covering line 1 to the end: stopping partway because the
remainder looks duplicative is a judgment made from inside the state the Read
exists to replace, and the marker stays armed until every line is covered. The
chunk above is always allowed. The file was confirmed present before this gate
armed."
    ;;
esac
