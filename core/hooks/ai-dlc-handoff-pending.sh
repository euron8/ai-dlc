#!/bin/bash
#
# AI/DLC shared predicate: is a human-requested handoff PENDING right now?
#
# NOT A HOOK. No event invokes this; two hooks `.`-source it as a sibling. Both the
# distribution's I13 and the consumer's validate-hook-registration.sh derive their
# library exemption from the OTHER side of the join -- a file in core/hooks/ is a library
# exactly while some sibling sources it -- so this needs no entry in any skip list and no
# registration in settings.json. Registering it would wire a consumer's settings to a
# command that reads no stdin and decides nothing.
#
# WHY ONE PREDICATE AND NOT TWO COPIES. Two hooks ask this question at two different
# moments -- ai-dlc-continue.sh at the Stop seam (did the handoff actually complete?) and
# ai-dlc-recover.sh after a compaction (which step file is the pending work?). They had
# begun to answer it differently, which is the drift schemas/pause-routing.json already
# exists to prevent one level down. The handoff vocabulary is declared there and read
# here; it is not spelled in this file either.
#
# ------------------------------------------------------------------------------------
# THE THREE KEYS, AND WHY THERE ARE THREE
#
# A handoff is pending when the pipeline is paused AND at least one key holds. They are
# ordered by how much LEAD COOPERATION each requires, and the last one requires none --
# which matters because the episode that produced this predicate is one where the lead
# never loaded steps/handoff.md at all.
#
#   1. THE ENTRY MARKER. steps/handoff.md writes it as its first action, so a compaction
#      landing anywhere inside the 5-step procedure is detectable. Precise, and the only
#      key that positively means "the procedure is in progress" rather than "was asked
#      for". It exists because a marker written at the END records only handoffs that did
#      not need recording.
#   2. THE SNAPSHOT'S HANDOFF SECTION. What real snapshots carry today: a lead that
#      improvises a handoff record writes this heading. Kept as a key because key 1 only
#      starts appearing on the NEXT handoff after this ships, while a consumer mid-handoff
#      at pull time has this one and nothing else.
#   3. THE CONTINUATION LOG, THIS SESSION'S ROWS. ai-dlc-pause.sh and
#      ai-dlc-answer-capture.sh write the operator's request with no lead cooperation at
#      all. This is the key that fires when the lead did nothing.
#
# KEY 3 IS BOUNDED TO THE CURRENT SESSION, AND THAT BOUND IS THE DISCHARGE. The log is
# rotated per sprint (Rule 25(c)), so "any handoff row" stays true for every later session
# in the sprint and would block ordinary work at its first Stop -- a guard that wedges
# correct sessions is worse than the defect it catches. Measured on the reference
# consumer's episode: the request and every turn for the next 37 minutes carry one session
# id, which changes at the next session, so the window closes exactly where it should
# without a new log event and without a new vocabulary member.
#
# AND IT IS NOT "THE MOST RECENT ROW". That spelling was built, measured against the
# consumer's real log at each of its 22 recorded compactions, and REJECTED: it fires on 1
# of 22 and not on the episode this exists for. The operator asked for the handoff, then
# asked ABOUT it four minutes later, and the second row is newer -- asking whether a
# handoff ran is the most likely thing to type just before the compaction that lands
# inside one. Scanning this session's rows finds the request; reading only the newest
# finds the question and reports nothing.
#
# THE OPERATOR-PROSE FIELDS ARE THE SIGNAL, AND `- Question` IS NOT ONE OF THEM.
# ai-dlc-answer-capture.sh labels that field "NOT the intent signal" in the row it writes,
# because it is lead-authored; letting it count would hand the lead a way to route its own
# guard.
#
# THE PATTERNS ARE APPLIED TO THE EXTRACTED FIELD VALUE, NEVER TO THE LOG LINE. The
# declared vocabulary spells a terse request as the anchored `^ *hand[ -]?off *$`, which
# cannot match a line still carrying its `- Prompt (first 120 chars): ` prefix. A line-wise
# grep therefore scores a real request as a non-instance and returns a clean, plausible
# zero -- the failure mode where the search grammar cannot spell its own subject.
#
# FAIL CLOSED TO "NOT PENDING". Every unreadable input returns 1. A false PENDING reroutes
# a mandated Read and blocks a Stop; a false NOT-PENDING leaves today's behaviour standing.
# Only one of those can wedge a correct session.

# ai_dlc_handoff_pending <state_dir> <session_id> <pause_routing_schema>
# Exit 0 = a handoff is pending. Exit 1 = it is not, or the question could not be answered.
# Sets AI_DLC_HANDOFF_KEY to the key that fired, for the caller's log line.
ai_dlc_handoff_pending() {
  local _sd="${1:-}" _sess="${2:-}" _schema="${3:-}"
  AI_DLC_HANDOFF_KEY=""

  [ -n "$_sd" ] || return 1
  # THE PAUSE FLAG IS NECESSARY AND NOWHERE NEAR SUFFICIENT. It is raised by every Rule 3
  # pause point and by every operator message, and steps/handoff.md step 5 creates it
  # itself -- so on its own it is as true after a completed handoff as during a pending
  # one. It is here only to bound the keys below to a pipeline that is actually paused;
  # the resume path removes it, which is what stops a stale key firing in a later turn.
  [ -f "${_sd}/pipeline-paused.flag" ] || return 1

  # Key 1 -- the entry marker.
  if [ -f "${_sd}/.handoff-in-progress" ]; then
    AI_DLC_HANDOFF_KEY="entry-marker"
    return 0
  fi

  # Key 2 -- a handoff record in the snapshot. Anchored to the START OF A LINE so a MENTION in
  # prose ("see the HANDOFF POINT section below") is not a key; the record opens its own line.
  #
  # THE HEADING IS OPTIONAL, AND REQUIRING IT SCORED ZERO ON THE ONLY REAL INSTANCE THAT EXISTS.
  # The first cut demanded `^#{1,6}`. The reference consumer's live record is a BOLD PARAGRAPH
  # LEAD-IN with no `#` at all -- `**HANDOFF POINT (operator-requested, mid gate-3 ...).**` --
  # so the grammar missed the very record this key was added to detect, against a control of 1
  # on a synthetic heading. Isolated by prepending `## ` to that one line and nothing else,
  # which flipped it to PENDING.
  #
  # THE CAUSE IS THAT THE SHAPE CAME FROM THE READER. Nothing in this tree PRODUCES this record
  # -- a lead writes it, by hand, improvising -- so there was no producer to seed from and the
  # first grammar was written from the same imagination as its own test case. It matched
  # everything I invented and nothing a consumer had actually written.
  if [ -r "${_sd}/pipeline-snapshot.md" ] \
     && grep -qiE '^[[:space:]]*(#{1,6}[[:space:]]*)?(\*\*)?HANDOFF POINT' "${_sd}/pipeline-snapshot.md" 2>/dev/null; then
    AI_DLC_HANDOFF_KEY="snapshot-section"
    return 0
  fi

  # Key 3 -- this session's request rows in the continuation log.
  local _log="${_sd}/pipeline-continuation-log.md"
  [ -n "$_sess" ] && [ -r "$_log" ] && [ -n "$_schema" ] && [ -r "$_schema" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local _hi _hm _prose
  _hi="$(jq -rj '.handoff_intent_pattern // ""' "$_schema" 2>/dev/null)"
  _hm="$(jq -rj '.handoff_mention_exclusion_pattern // ""' "$_schema" 2>/dev/null)"
  [ -n "$_hi" ] && [ -n "$_hm" ] || return 1

  # THE USER_PAUSE RULE FLUSHES BEFORE IT RESETS, and leaving that out is not a style point:
  # this rule ends in `next`, so without the flush a second USER_PAUSE header discards the
  # first block's prose and only the LAST block of the session survives. That degenerates
  # into exactly the "most recent row" reading this predicate exists to avoid, silently, and
  # a log with one row cannot tell the two apart. Caught by a probe seeding two rows where
  # the request is first and a question about it is second -- the episode's own shape.
  _prose="$(awk -v sess="$_sess" '
    /^##[[:space:]].*--[[:space:]]USER_PAUSE[[:space:]]*$/ { if (inb && mine) out = out buf; inb=1; mine=0; buf=""; next }
    /^##[[:space:]]/ { if (inb && mine) out = out buf; inb=0 }
    inb && /^-[[:space:]]+Session:[[:space:]]/ { if (index($0, sess) > 0) mine=1 }
    inb && /^-[[:space:]]+(Prompt|Answer)[[:space:]]*\(first[[:space:]]+120[[:space:]]+chars\)[[:space:]]*:/ {
      line=$0; sub(/^[^:]*:[[:space:]]*/, "", line); buf = buf line "\n"
    }
    END { if (inb && mine) out = out buf; printf "%s", out }' "$_log" 2>/dev/null)"

  [ -n "$_prose" ] || return 1
  # Fed by here-strings, never a pipe: `grep -q` leaves at its first match and the writer
  # then takes EPIPE, which under pipefail reports NOT-FOUND on input that matches.
  if grep -qiE "$_hi" <<<"$_prose" && ! grep -qiE "$_hm" <<<"$_prose"; then
    AI_DLC_HANDOFF_KEY="log-request"
    return 0
  fi
  return 1
}
