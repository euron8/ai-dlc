#!/usr/bin/env bash
# handoff-completion-assertion — assert the handoff seam end to end, across the two hooks and
# the one predicate they now share.
#
# THREE SUBJECTS, AND NONE OF THEM IS REACHABLE FROM `handoff-resume-guard`.
#
# 1. ai-dlc-continue.sh's PUSH ARM (steps/handoff.md step 3). Step 3 is the half of the
#    procedure nothing had ever checked, and it is the half that loses work: the resume line
#    and the teammate sweep are both recorded IN the conversation, so a lead that skips them
#    is visible, while an unpushed branch looks exactly like a pushed one from inside the
#    session. It deliberately does NOT fire when no remote is configured -- step 3 names that
#    as one of three environmental causes it forgives -- and that narrowing is the whole
#    false-positive story, so it is asserted here beside the case it must still catch.
#
# 2. ai-dlc-handoff-pending.sh, THE SHARED PREDICATE, through both of its callers. A handoff
#    typed while the lead is working is stored by the harness as a `queue-operation` record
#    and never becomes a `message.role=="user"` entry, so the transcript cannot see it and
#    every transcript-keyed guard was silent. The predicate answers from disk instead, on
#    three keys, gated by the pause flag. Each key gets a seed the other two cannot satisfy --
#    `fixture-mutants.md`'s "two guards that COVER each other" is the failure being avoided,
#    and its symptom is ZERO mutant kills rather than two.
#
# 3. ai-dlc-recover.sh's STEP-FILE OVERRIDE. `current_step_file` is wrong by construction at a
#    handoff: it records the step the handoff INTERRUPTED until step 3 rewrites it, so a
#    compaction lands the recovering lead in the wrong procedure with every downstream check
#    passing. Asserted through the emitted `additionalContext`, and cross-checked against the
#    `.recover-fired` marker -- two independently derived values, because a count read off one
#    rendering is not a derived count.
#
# WHY THE PREDICATE IS DRIVEN THROUGH ITS CALLERS AND NEVER CALLED DIRECTLY. Isolating the
# subject is not running the PROGRAM: a defect in a caller -- a wrong state dir, a session id
# read from the wrong field, a schema that does not resolve in that hook's layout -- stays
# invisible to a fixture that sources the library and calls the function.
#
# EVERY NEGATIVE HERE IS AN EMPTY OR UNCHANGED OUTPUT, AND SO IS A HOOK THAT DIED ON LOAD.
# Every arm is therefore PRESENCE-shaped: a Stop allow is paired with the same tree driven
# with the resume block stripped, which must BLOCK; and a recover negative REQUIRES the
# mandate to name the snapshot's own step file, which an empty block cannot do.
#
# Usage: run.sh [path-to-hooks-directory-or-ai-dlc-continue.sh]
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook. A fixture that INHERITS
# ambient config tests the config, not the code; see handoff-resume-guard's header for the
# consumer that pinned AI_DLC_MODEL_ROW and failed seven assertions against a sensor behaving
# exactly as specified.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# AND SCRUB GIT'S OWN AMBIENT REPO POINTERS, which no other fixture here has had to. `GIT_DIR`
# and friends take precedence over `-C <dir>`, so a runner that exported one would make the
# not-a-git-repo probe below read as a git repo and quietly re-arm the very arm that case
# exists to prove is disarmed. Measured on git 2.54.0 (Apple Git-157): a pre-push hook gets
# `GIT_EXEC_PATH`, `GIT_PREFIX` and `GIT_EDITOR` and no `GIT_DIR` -- so this is defence
# against a different git, and seed.sh carries the same scrub plus a hard abort, because it is
# executable on its own and one run of it with `GIT_DIR` set committed to this repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_NAMESPACE 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
pickd() { for c in "$@"; do [ -n "$c" ] && [ -d "$c" ] && { printf '%s' "$c"; return; }; done; }
pick()  { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }

# THE WHOLE DIRECTORY IS RESOLVED, NOT ONE HOOK. Both hooks source
# ai-dlc-handoff-pending.sh as a SIBLING of themselves, so a mutant copy of either one placed
# on its own finds no library, fails open, and reads exactly like a guard that stood down. The
# mutant battery copies this directory and edits one file inside the copy.
_arg="${1:-}"
[ -n "$_arg" ] && [ -f "$_arg" ] && _arg="$(cd "$(dirname "$_arg")" && pwd)"
HOOKS_DIR="$(pickd "$_arg" "$HERE/../../hooks" "$HERE/../../../core/hooks" "$HERE/../../../.claude/hooks")"
[ -n "$HOOKS_DIR" ] || { echo "FIXTURE ERROR: cannot locate the hooks directory" >&2; exit 2; }
HOOKS_DIR="$(cd "$HOOKS_DIR" && pwd)"
command -v jq  >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq required"  >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git required" >&2; exit 2; }

SCHEMA="$(pick "$HERE/../../schemas/pause-routing.json" \
               "$HERE/../../../core/schemas/pause-routing.json" \
               "$HERE/../../../.claude/schemas/pause-routing.json")"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  %s\n' "$1"; echo ""; echo "handoff-completion-assertion: FIXTURE BROKEN" >&2; exit 2; }

for _f in ai-dlc-continue.sh ai-dlc-recover.sh ai-dlc-handoff-pending.sh; do
  [ -f "$HOOKS_DIR/$_f" ] || broken "$_f is not in the resolved hooks directory ($HOOKS_DIR) — this fixture drives all three and cannot report on any of them"
done
# The vocabulary declaration gates Check 0 entirely and is key 3's whole grammar: with it
# unreachable both callers stand down and every assertion below passes for the wrong reason.
[ -n "$SCHEMA" ] || broken "schemas/pause-routing.json not found in either layout; the handoff vocabulary is read from there and both hooks would skip, so every assertion below would pass without the predicate running"

ROOT="$(bash "$HERE/seed.sh")"
{ [ -n "$ROOT" ] && [ -d "$ROOT" ]; } || broken "seed.sh produced no sandbox root"

printf '        hooks:      %s\n' "$HOOKS_DIR"
printf '        vocabulary: %s\n' "$SCHEMA"

T_REQ_OK="$(cat "$ROOT/.t_req_ok")"
T_REQ_NOBLK="$(cat "$ROOT/.t_req_noblk")"
T_QUIET="$(cat "$ROOT/.t_quiet")"
T_QUIET_OK="$(cat "$ROOT/.t_quiet_ok")"

P_NOGIT="$ROOT/proj-nogit"
P_NOREMOTE="$ROOT/proj-noremote"
P_UNPUSHED="$ROOT/proj-unpushed"
P_PUSHED="$ROOT/proj-pushed"
P_AHEAD="$ROOT/proj-ahead"
P_DISK="$ROOT/proj-disk"
P_REC="$ROOT/proj-recover"
P_REC_CLAUDE="$ROOT/proj-recover-claude"
P_ENTRY="$ROOT/proj-entry"

STEP_IMPL="core/skills/ai-dlc/steps/implementation.md"
STEP_HANDOFF="core/skills/ai-dlc/steps/handoff.md"
STEP_IMPL_C=".claude/skills/ai-dlc/steps/implementation.md"
STEP_HANDOFF_C=".claude/skills/ai-dlc/steps/handoff.md"

SESS_A="sess-alpha-11110000"
SESS_B="sess-bravo-22220000"

# -----------------------------------------------------------------------------
# Driving the hooks
# -----------------------------------------------------------------------------
# THE STATE IS RESET EXPLICITLY BY EACH CASE, never implicitly here, because these trees are
# reused and every case differs from its neighbour in exactly one file. `reset_state` is what
# makes "the same tree" a true statement rather than an aspiration.
#
# The rapid-fire state file is the one exception and is cleared on every drive: Check 0's own
# backoff releases after MAX_RAPID_BLOCKS consecutive blocks, so a tree driven four times
# would start ALLOWING -- a leak that reads exactly like the arm standing down.
reset_state() { # reset_state <projdir>
  local sd="$1/_bmad-output"
  mkdir -p "$sd/.driver"
  rm -f "$sd/handoff-guard-state.txt" "$sd/pipeline-continuation-log.md" \
        "$sd/pipeline-paused.flag" "$sd/.handoff-in-progress" "$sd/.recover-fired" \
        "$sd/pipeline-snapshot.md" "$sd/.handoff-guard-armed"
  # STEP 4's TOUCH IS PART OF THE BASELINE STATE. Check 0 asserts `.driver/handoff` once the
  # resume, sweep and push arms are satisfied, so every ALLOW case in this file needs it on
  # disk or it blocks for the driver arm's reason. It is the LEAD's own Bash action, not a
  # hook's artifact, so seeding it here seeds the actor's step and not a reader's grammar --
  # unlike `.handoff-in-progress`, which only ai-dlc-handoff-entry.sh may write (mkmarker).
  # The driver-arm cases below REMOVE it to reach their subject.
  : > "$sd/.driver/handoff"
  return 0
}

# ai-dlc-continue.sh: JSON on stdin, decision JSON on stdout, exit 0 either way.
#
# NO SNAPSHOT in either Stop battery. Check 0 is the first check in the hook and Check 2 (no
# active pipeline) is what allows the stop further down, so with no snapshot Check 0's verdict
# is the only thing that can block. A snapshot would make the pipeline ACTIVE and Rule 3 would
# block every Stop for a reason unrelated to the arm under test. It also pins TEAMMATES_OK=1,
# which is what isolates the push arm.
drive() { # drive <projdir> <session> <transcript> [hooksdir] -> raw stdout
  local proj="$1" sess="$2" t="$3" hd="${4:-$HOOKS_DIR}"
  mkdir -p "$proj/_bmad-output"
  rm -f "$proj/_bmad-output/handoff-guard-state.txt"
  jq -nc --arg t "$t" --arg s "$sess" '{transcript_path:$t,session_id:$s}' \
  | CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$hd/ai-dlc-continue.sh" 2>/dev/null
}
# ai-dlc-handoff-entry.sh: a PostToolUse payload in, a marker file on disk out. It is the
# PRODUCER of key 1, so every key-1 seed in this fixture is made by driving it -- never by
# touching `.handoff-in-progress` here. A seed a fixture writes itself proves the reader
# accepts the fixture's own spelling; this one proves the two shipped halves agree.
edrive() { # edrive <projdir> <tool> <file-path> [hooksdir] -> hook exit code
  local proj="$1" tool="$2" fp="$3" hd="${4:-$HOOKS_DIR}"
  jq -nc --arg t "$tool" --arg p "$fp" '{tool_name:$t,tool_input:{file_path:$p}}' \
  | CLAUDE_PROJECT_DIR="$proj" bash "$hd/ai-dlc-handoff-entry.sh" >/dev/null 2>&1
  printf '%s' "$?"
}
mkmarker() { # mkmarker <projdir> [hooksdir] -> produce key 1 the way the machinery does
  local p="" c
  for c in ".claude/skills/ai-dlc/steps" "core/skills/ai-dlc/steps"; do
    [ -f "$1/$c/handoff.md" ] && { p="$1/$c/handoff.md"; break; }
  done
  [ -n "$p" ] || p="$1/core/skills/ai-dlc/steps/handoff.md"
  edrive "$1" Read "$p" "${2:-$HOOKS_DIR}" >/dev/null
}
marker_at() { [ -f "$1/_bmad-output/.handoff-in-progress" ]; }

verdict() { if printf '%s' "$1" | jq -e '.decision=="block"' >/dev/null 2>&1; then printf block; else printf allow; fi; }
reason()  { printf '%s' "$1" | jq -r '.reason // ""' 2>/dev/null; }
has()     { grep -qF -- "$2" <<<"$1"; }

# ai-dlc-recover.sh: a SessionStart `compact` payload in, additionalContext out. The hook
# exits 0 emitting nothing unless a snapshot exists and `.source` is exactly `compact`.
rdrive() { # rdrive <projdir> <session> [hooksdir] -> additionalContext
  local proj="$1" sess="$2" hd="${3:-$HOOKS_DIR}" out
  out="$(jq -nc --arg s "$sess" '{source:"compact",session_id:$s}' \
        | CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$hd/ai-dlc-recover.sh" 2>/dev/null)"
  printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}

# The three ai-dlc-continue.sh block texts, keyed on a phrase unique to each. The push text
# quotes "resume prompt is well-formed", so the resume marker has to be the longer phrase or
# assertion k would score the push branch as the resume branch.
PUSH_MARK="step 3's push has NOT landed"
TEAM_MARK="still carries a row whose status reads"
RESUME_MARK="WITHOUT a copy-pasteable resume prompt"
DRIVER_MARK="step 4's driver signal was NOT touched"
MARKER_MARK="step 5's entry marker is still present"

# -----------------------------------------------------------------------------
# The continuation-log rows, written in the two REAL producers' shapes
# -----------------------------------------------------------------------------
# SEEDED FROM WHAT THE PRODUCER EMITS, NOT FROM WHAT THE READER ACCEPTS. A row derived from
# the predicate's own awk grammar proves the reader accepts its own spelling and stays green
# through a change to both. These are transcribed from the two emitters: ai-dlc-pause.sh
# (UserPromptSubmit, `- Prompt (first 120 chars):`) and ai-dlc-answer-capture.sh
# (AskUserQuestion, `- Question (lead-authored, NOT the intent signal):` followed by
# `- Answer (first 120 chars):`).
log_open() { cat > "$1" <<'EOF'
# Pipeline Flow Log

---

EOF
}
row_prompt() { # row_prompt <outfile> <session> <ts> <prompt-value>
  cat >> "$1" <<EOF
## $3 -- USER_PAUSE
- Session: $2
- Channel: UserPromptSubmit (typed message)
- Prompt (first 120 chars): $4

EOF
}
row_answer() { # row_answer <outfile> <session> <ts> <question-value> <answer-value>
  cat >> "$1" <<EOF
## $3 -- USER_PAUSE
- Session: $2
- Channel: AskUserQuestion answer (handoff intent)
- Tool-use: toolu_01FIXTURE
- Question (lead-authored, NOT the intent signal): $4
- Answer (first 120 chars): $5

EOF
}
log_prompt() { log_open "$1"; row_prompt "$1" "$2" "2026-08-30T12:00:00Z" "$3"; }
log_answer() { log_open "$1"; row_answer "$1" "$2" "2026-08-30T12:00:00Z" "$3" "$4"; }

# THE TWO-ROW LOG, AND IT IS THE MOST LOAD-BEARING SEED IN THIS FILE.
#
# The predicate's `USER_PAUSE` awk rule ends in `next`, so without a flush before the reset a
# second USER_PAUSE header DISCARDS the first block's prose and only the LAST block of the
# session survives -- silently degenerating into "the most recent row", which is the exact
# reading the predicate's header records as measured and REJECTED (it fires on 1 of the
# consumer's 22 compactions, and not on the episode this exists for). A log with ONE row
# cannot tell the two implementations apart, so a battery built entirely from single-row logs
# would score that mutant green.
#
# The shape is the episode's own: the operator asks for the handoff, then asks ABOUT it four
# minutes later. The second row is newer and is NOT a request.
log_two_row() { # log_two_row <outfile> <session> <first-value> <second-value>
  log_open "$1"
  row_prompt "$1" "$2" "2026-08-30T13:06:31Z" "$3"
  row_prompt "$1" "$2" "2026-08-30T13:10:44Z" "$4"
}

# The operator prose each row carries. Declared once and used by BOTH the premise arms below
# and the log writers, so a seed cannot drift from the premise asserted about it.
P_INTENT="hand off the sprint"
P_BARE="handoff"
P_DISCUSS="why did the handoff guard fire when I typed hand off the sprint"
P_NOINTENT="not yet, keep going"
P_AFTER="Did the full handoff steps run"
Q_INTENT="should I hand off the sprint before I stop?"
Q_NOINTENT="anything else before I stop?"
# THE ROW EVERY RESUMED SESSION CARRIES FIRST. `/ai-dlc` is in the mention exclusion, and the
# exclusion used to be applied to the whole session's prose joined -- so this one row vetoed
# key 3 for the rest of the session, and the reference consumer's `handoff` typed five hours
# later scored NOT PENDING. It is a producer-derived seed: ai-dlc-pause.sh records the slash
# command verbatim as the first USER_PAUSE row of a resumed session.
P_RESUME="/ai-dlc resume"

LG="$ROOT/logs/log.md"

# =============================================================================
# FIXTURE-BROKEN ARMS: prove each probe tree IS the state its assertions assume
# =============================================================================
# Without these the push battery is a check that cannot fire. A `mktemp -d` that is not a git
# repo returns ALLOW from every push case, and ALLOW is what four of the five expect.
if git -C "$P_NOGIT" rev-parse --git-dir >/dev/null 2>&1; then
  broken "the not-a-git-repo probe ($P_NOGIT) READS as a git repo — an ambient GIT_DIR or an enclosing repository is reaching it, so case (a) would assert the fail-safe path while exercising a live one"
fi
ok "probe shape: $P_NOGIT is NOT a git repo (case (a) really exercises the fail-safe path)"

for _p in "$P_NOREMOTE" "$P_UNPUSHED" "$P_PUSHED" "$P_AHEAD"; do
  git -C "$_p" rev-parse --git-dir >/dev/null 2>&1 || \
    broken "probe tree $_p is NOT a git repo — the push arm's outer guard would short-circuit and every verdict below would be the fail-safe one"
done
ok "probe shape: the four git probes are real repositories (the push arm's outer guard is satisfied)"

[ -z "$(git -C "$P_NOREMOTE" remote 2>/dev/null)" ] || \
  broken "the no-remote probe has a remote configured — case (b) would not be testing the environmental narrowing"
ok "probe shape: no-remote probe has zero remotes"

{ [ -n "$(git -C "$P_UNPUSHED" remote 2>/dev/null)" ] \
  && ! git -C "$P_UNPUSHED" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; } || \
  broken "the unpushed probe is not 'remote configured, branch never published' — case (c) is not v0.434.0's state"
ok "probe shape: unpushed probe has a remote and NO upstream (v0.434.0's exact state)"

_pushed_ahead="$(git -C "$P_PUSHED" rev-list --count '@{u}..HEAD' 2>/dev/null)"
{ [ -n "$(git -C "$P_PUSHED" remote 2>/dev/null)" ] && [ "$_pushed_ahead" = "0" ]; } || \
  broken "the pushed probe is not 'upstream set, 0 ahead' (rev-list said '${_pushed_ahead:-<unreadable>}') — case (d) would not be testing the satisfied state"
ok "probe shape: pushed probe has an upstream and is 0 commits ahead"

_ahead_ahead="$(git -C "$P_AHEAD" rev-list --count '@{u}..HEAD' 2>/dev/null)"
[ "$_ahead_ahead" = "1" ] || \
  broken "the ahead probe is ${_ahead_ahead:-<unreadable>} commits ahead, not 1 — case (e) is not the stranded-work state"
ok "probe shape: ahead probe is exactly 1 commit ahead of its upstream"

# The recover battery's trees must carry BOTH step files, or the override has nothing to name
# and every case would fall back for a reason that is not the one under test.
for _pair in "$P_REC:$STEP_IMPL:$STEP_HANDOFF" "$P_REC_CLAUDE:$STEP_IMPL_C:$STEP_HANDOFF_C"; do
  _pd="${_pair%%:*}"; _rest="${_pair#*:}"; _si="${_rest%%:*}"; _sh="${_rest#*:}"
  { [ -r "$_pd/$_si" ] && [ -r "$_pd/$_sh" ]; } || \
    broken "recover probe $_pd is missing $_si or $_sh — the override resolves against those paths, so a fall-back verdict would say nothing about the predicate"
done
ok "probe shape: both recover trees carry a readable implementation.md AND handoff.md (core/ and .claude/ layouts)"

# =============================================================================
# SEED-PREMISE ARMS: the declared vocabulary classifies these seeds as claimed
# =============================================================================
# Every key-3 assertion rests on a claim about how the DECLARED patterns score one string.
# Those patterns live in pause-routing.json and can be edited without touching this file, at
# which point an assertion still passes while testing something else. These arms point the
# grammar at its own subjects and fail loudly instead.
INTENT_RE="$(jq -rj '.handoff_intent_pattern // ""' "$SCHEMA" 2>/dev/null)"
EXCL_RE="$(jq -rj '.handoff_mention_exclusion_pattern // ""' "$SCHEMA" 2>/dev/null)"
{ [ -n "$INTENT_RE" ] && [ -n "$EXCL_RE" ]; } || \
  broken "pause-routing.json declares no handoff_intent_pattern / handoff_mention_exclusion_pattern — key 3 would return 1 unconditionally"

isreq()  { grep -qiE "$INTENT_RE" <<<"$1"; }
ismech() { grep -qiE "$EXCL_RE"   <<<"$1"; }

{ isreq "$P_INTENT" && ! ismech "$P_INTENT"; } || \
  broken "seed premise dead: the declared vocabulary no longer reads '$P_INTENT' as a handoff REQUEST"
{ isreq "$P_BARE" && ! ismech "$P_BARE"; } || \
  broken "seed premise dead: the declared vocabulary no longer reads the bare word '$P_BARE' as a handoff REQUEST — that seed is the only one that can distinguish a field-value match from a whole-line match"
{ isreq "$P_DISCUSS" && ismech "$P_DISCUSS"; } || \
  broken "seed premise dead: '$P_DISCUSS' no longer matches BOTH the intent pattern and the mention exclusion — the exclusion case would pass without exercising the exclusion conjunct at all"
! isreq "$P_NOINTENT" || \
  broken "seed premise dead: '$P_NOINTENT' now reads as a handoff request"
! isreq "$P_AFTER" || \
  broken "seed premise dead: '$P_AFTER' now reads as a handoff REQUEST — it is the SECOND row of the two-row log, and if it is a request then a reader that keeps only the last block scores the same as one that flushes, and the flush mutant cannot be killed"
! ismech "$P_AFTER" || \
  broken "seed premise dead: '$P_AFTER' now matches the mention EXCLUSION — the exclusion is applied to the whole extracted prose, so the second row would veto the first and the two-row log would report NOT pending for the wrong reason"
{ isreq "$Q_INTENT" && ! ismech "$Q_INTENT"; } || \
  broken "seed premise dead: the lead-authored question '$Q_INTENT' no longer reads as a handoff request — the Question-line case could not detect that field being routed"
! isreq "$Q_NOINTENT" || \
  broken "seed premise dead: '$Q_NOINTENT' now reads as a handoff request"
{ ! isreq "$P_RESUME" && ismech "$P_RESUME"; } || \
  broken "seed premise dead: '$P_RESUME' no longer scores as a NON-request that matches the mention EXCLUSION — the per-row case below would then pass without exercising the exclusion's scope at all"
ok "seed premise: the DECLARED vocabulary scores all eight log-prose seeds as this fixture assumes"

# The transcripts' own premises, DERIVED from the seeded files rather than restated.
_req_user="$(jq -rs '[.[]|select(.message.role=="user")|.message.content]|last // ""' "$T_REQ_OK" 2>/dev/null)"
_quiet_user="$(jq -rs '[.[]|select(.message.role=="user")|.message.content]|last // ""' "$T_QUIET" 2>/dev/null)"
{ isreq "$_req_user" && ! ismech "$_req_user"; } || \
  broken "the push battery's transcript no longer carries a handoff request as its last user message ('$_req_user') — Check 0 would never open and all five push cases would ALLOW"
{ ! isreq "$_quiet_user"; } || \
  broken "the on-disk battery's transcript ('$_quiet_user') now reads as a handoff request — the transcript path would fire and no on-disk verdict below would mean anything"
_quiet_ok_user="$(jq -rs '[.[]|select(.message.role=="user")|.message.content]|last // ""' "$T_QUIET_OK" 2>/dev/null)"
{ ! isreq "$_quiet_ok_user"; } || \
  broken "the sticky battery's transcript ('$_quiet_ok_user') now reads as a handoff request — the transcript channel would arm the guard and no sticky verdict below would mean anything"
ok "seed premise: the push transcript IS a request and the on-disk transcript is NOT (so an on-disk BLOCK can only have come from disk)"

# =============================================================================
# ai-dlc-continue.sh — THE PUSH ARM
# =============================================================================
push_case() { # push_case <label> <projdir> <expected> <why> <control-why>
  local label="$1" proj="$2" want="$3" why="$4" cwhy="$5" r
  reset_state "$proj"
  r="$(verdict "$(drive "$proj" "$SESS_A" "$T_REQ_OK")")"
  [ "$r" = "$want" ] && ok "$label" || bad "$why (got $r)"
  if [ "$want" = allow ]; then
    reset_state "$proj"
    r="$(verdict "$(drive "$proj" "$SESS_A" "$T_REQ_NOBLK")")"
    [ "$r" = block ] && ok "  control: the same tree BLOCKS once the resume block is stripped — the hook runs here" \
                     || bad "$cwhy (got $r) — the ALLOW above is unreadable, it may be a hook that never ran"
  fi
}

push_case "(a) not a git repo at all -> ALLOW (fail-safe: today's behaviour preserved)" \
  "$P_NOGIT" allow \
  "a handoff in a directory that is not a git repo was BLOCKED — the push arm invented a finding where nothing can be asserted" \
  "the not-a-git-repo tree did not block a missing resume block either"

push_case "(b) git repo, NO remote configured -> ALLOW (step 3 forgives 'no remote configured')" \
  "$P_NOREMOTE" allow \
  "a handoff in a local-only repo was BLOCKED — a repo with no remote can NEVER satisfy a push assertion, so this wedges every handoff in a local tree until the backoff releases" \
  "the no-remote tree did not block a missing resume block either"

push_case "(c) remote exists, branch NEVER pushed -> BLOCK (v0.434.0's exact state)" \
  "$P_UNPUSHED" block \
  "a handoff on an unpublished branch was ALLOWED — the commits it just made exist only on this machine, and from inside the session that looks exactly like a pushed branch" \
  ""

push_case "(d) remote, pushed, 0 commits ahead -> ALLOW (the satisfied state)" \
  "$P_PUSHED" allow \
  "BLOCKED a handoff whose branch is published and up to date — the check fires on COMPLIANCE with step 3" \
  "the pushed tree did not block a missing resume block either"

push_case "(e) remote, pushed, 1 commit AHEAD -> BLOCK (offline / protected branch land here)" \
  "$P_AHEAD" block \
  "a handoff with unpushed commits was ALLOWED — this is the stranded-work state the operator needs told about" \
  ""

# --- (k) the block REASON names the right STEP ------------------------------------------
#
# THE DISPATCH-ORDERING REGRESSION, and the one a careless rewrite reintroduces. With two arms
# the cause could be inferred from RESUME_OK; with three that inference is wrong and answers a
# missing PUSH with the teammate text. A verdict-only assertion cannot see it: the hook still
# blocks, and the lead is simply sent to fix something that is not broken.
reason_case() { # reason_case <label> <projdir>
  local label="$1" rr
  reset_state "$2"
  rr="$(reason "$(drive "$2" "$SESS_A" "$T_REQ_OK")")"
  if [ -z "$rr" ]; then
    bad "(k) $label: the block carried NO reason at all — nothing was dispatched"
  elif ! has "$rr" "$PUSH_MARK"; then
    bad "(k) $label: the emitted reason does NOT name step 3's push. It reads: $(printf '%s' "$rr" | head -c 120)"
  elif has "$rr" "$RESUME_MARK" || has "$rr" "$TEAM_MARK"; then
    bad "(k) $label: the emitted reason names step 3 AND another step — the dispatch is not exclusive"
  else
    ok "(k) $label: only the push arm failed, and the emitted reason is the STEP 3 text (not the teammate or resume-line text)"
  fi
}
# ONE TREE, DELIBERATELY. The ahead-of-upstream tree reaches the identical dispatch through the
# identical PUSH_OK value, so a second reason_case here asserts nothing new -- and it made the
# ahead-test mutant fail TWO arms, which is the entanglement `fixture-mutants.md` warns about:
# assertion (e) OWNS "1 commit ahead -> BLOCK", so this arm stands down for it.
reason_case "unpushed branch" "$P_UNPUSHED"

# =============================================================================
# ai-dlc-continue.sh — THE DRIVER-SIGNAL ARM (step 4) AND THE MARKER ARM (step 5)
# =============================================================================
# Measured on the reference consumer over the 39 handoffs its transcripts can score: step 4's
# `touch _bmad-output/.driver/handoff` skipped on 20, step 5's `rm -f .handoff-in-progress` on
# 4 of the 17 in scope. Neither had an arm. Every case drives the COMPLIANT transcript, so the
# resume arm is satisfied and the only thing that varies is one file under _bmad-output.
#
# (d1) THE PUSHED TREE WITH THE DRIVER SIGNAL REMOVED. Same tree as (d), which is the ALLOW
#      control beside it: steps 1, 3 and the resume line are all recorded, and the only
#      difference is the touch.
reset_state "$P_PUSHED"
rm -f "$P_PUSHED/_bmad-output/.driver/handoff"
rr="$(reason "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK")")"
if [ -z "$rr" ]; then
  bad "(d1) pushed tree, resume block present, driver signal ABSENT -> was ALLOWED — a handoff that skipped step 4's touch ends the session and an attached driver never learns of it"
elif ! has "$rr" "$DRIVER_MARK"; then
  bad "(d1) blocked, but the reason does not name step 4's touch. It reads: $(printf '%s' "$rr" | head -c 120)"
elif has "$rr" "$PUSH_MARK" || has "$rr" "$TEAM_MARK" || has "$rr" "$RESUME_MARK" || has "$rr" "$MARKER_MARK"; then
  bad "(d1) the reason names step 4's touch AND another step — the dispatch is not exclusive"
else
  ok "(d1) pushed tree, resume block present, driver signal ABSENT -> BLOCK, and the reason is the STEP 4 touch text alone"
fi
reset_state "$P_PUSHED"
r="$(verdict "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK")")"
[ "$r" = allow ] && ok "  control: the same tree with the driver signal present -> ALLOW (the arm accepts the state it demands)" \
                 || bad "  the same tree BLOCKED with the signal present ($r) — the arm fires on compliance with step 4"

# (d2) THE MARKER STILL ON DISK AFTER EVERYTHING ELSE. The non-git tree, so the push arm is
#      out of scope; the marker is produced by the REAL entry hook (mkmarker), never touched
#      here. The transcript is the compliant one, so the marker is also key 1 -- which is fine:
#      the key arms the guard and the arm asserts the same file is gone by the end.
reset_state "$P_DISK"
mkmarker "$P_DISK"
marker_at "$P_DISK" || broken "(d2) mkmarker did not produce the entry marker in $P_DISK — the marker arm has no subject"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK")")"
if [ -z "$rr" ]; then
  bad "(d2) resume block present, driver signal present, entry marker STILL PRESENT -> was ALLOWED — the next compaction will route this session back into handoff.md"
elif ! has "$rr" "$MARKER_MARK"; then
  bad "(d2) blocked, but the reason does not name step 5's marker. It reads: $(printf '%s' "$rr" | head -c 120)"
elif has "$rr" "$PUSH_MARK" || has "$rr" "$TEAM_MARK" || has "$rr" "$RESUME_MARK" || has "$rr" "$DRIVER_MARK"; then
  bad "(d2) the reason names step 5's marker AND another step — the dispatch is not exclusive"
else
  ok "(d2) everything recorded but the entry marker still present -> BLOCK, and the reason is the STEP 5 text alone"
fi
reset_state "$P_DISK"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK")")"
[ "$r" = allow ] && ok "  control: the same tree with the marker cleared -> ALLOW" \
                 || bad "  the same tree BLOCKED with the marker cleared ($r) — the marker arm fires on compliance with step 5"

# (d4) THE STALE SIGNAL. The reference consumer's tree: `.driver/handoff` left by a previous
#      handoff, no driver attached to consume it, and THIS handoff finalized its snapshot after
#      that touch. A presence test passes here forever; the arm keys on the snapshot's mtime as
#      the step-3 reference and must BLOCK. `touch -t` back-dates the signal rather than sleeping
#      for a clock tick, so the ordering is by construction and not by timing.
reset_state "$P_PUSHED"
touch -t 202001010000 "$P_PUSHED/_bmad-output/.driver/handoff"
printf '# Pipeline Snapshot\n\n## Pipeline Position\ncurrent_step_file: implementation.md\n\n## In-Flight Teammates\n\n' > "$P_PUSHED/_bmad-output/pipeline-snapshot.md"
touch "$P_PUSHED/_bmad-output/pipeline-paused.flag"
[ "$P_PUSHED/_bmad-output/pipeline-snapshot.md" -nt "$P_PUSHED/_bmad-output/.driver/handoff" ] \
  || broken "(d4) the seed could not make the snapshot newer than the driver signal — the stale case is not constructible on this filesystem"
rr="$(reason "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK")")"
if [ -z "$rr" ]; then
  bad "(d4) a driver signal OLDER than this handoff's finalized snapshot was accepted as step 4 -> ALLOW — on a tree with no driver attached the previous handoff's marker satisfies the arm forever, and the most-skipped step is unguarded exactly where its skip rate was measured"
elif ! has "$rr" "$DRIVER_MARK"; then
  bad "(d4) blocked, but not on the driver arm. It reads: $(printf '%s' "$rr" | head -c 120)"
else
  ok "(d4) a driver signal OLDER than the finalized snapshot -> BLOCK on the step-4 arm (presence is not this turn's touch)"
fi
: > "$P_PUSHED/_bmad-output/.driver/handoff"
rm -f "$P_PUSHED/_bmad-output/handoff-guard-state.txt"
r="$(verdict "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK")")"
[ "$r" = allow ] && ok "  control: the same tree after a FRESH touch -> ALLOW (the arm accepts the state step 4 produces)" \
                 || bad "  the same tree BLOCKED after a fresh touch ($r) — the freshness test rejects a compliant step 4"
reset_state "$P_PUSHED"

# (d3) BOTH MISSING: step 4 is dispatched before step 5, in the procedure's order.
reset_state "$P_DISK"
mkmarker "$P_DISK"
rm -f "$P_DISK/_bmad-output/.driver/handoff"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK")")"
{ has "$rr" "$DRIVER_MARK" && ! has "$rr" "$MARKER_MARK"; } \
  && ok "(d3) driver signal absent AND marker present -> the STEP 4 text, not step 5's (dispatched in procedure order)" \
  || bad "(d3) with both step 4 and step 5 unsatisfied the reason is not step 4's alone — the lead is told the later step first, or both. It reads: $(printf '%s' "$rr" | head -c 120)"

# (d5) STEP 5 BEFORE STEP 4 MUST NOT ESCAPE. The guard is armed by KEY 1 ALONE -- pause flag up,
#      entry marker produced by the real hook, no log row, no snapshot record, and a transcript
#      whose last user message is NOT a request (T_QUIET_OK, which still carries the resume block
#      so the resume arm is satisfied). It blocks on step 4. Then the lead clears the marker WITHOUT
#      touching the driver signal: key 1 is gone, no other key holds, and a guard armed only by
#      the predicate would not examine this Stop at all. The first armed Stop recorded the session,
#      so this one is armed by that record and must still BLOCK on step 4. Then the touch satisfies
#      it and the record is removed. One file per step, and (d3) is NOT reused here because (d3)
#      arms through the transcript, which would mask the very channel under test -- measured: the
#      first cut of this case did reuse it and passed against the mutant that disables the record.
ARMED="$P_DISK/_bmad-output/.handoff-guard-armed"
reset_state "$P_DISK"; touch "$P_DISK/_bmad-output/pipeline-paused.flag"
mkmarker "$P_DISK"; rm -f "$P_DISK/_bmad-output/.driver/handoff"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK")")"
has "$rr" "$DRIVER_MARK" || broken "(d5) the key-1-armed first Stop did not block on the driver arm (got: $(printf '%s' "$rr" | head -c 80)) — the sticky case cannot start"
[ -f "$ARMED" ] || broken "(d5) the armed Stop left no arming record at $ARMED — the sticky arm has no subject"
rm -f "$P_DISK/_bmad-output/.handoff-in-progress" "$P_DISK/_bmad-output/handoff-guard-state.txt"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK")")"
if [ -z "$rr" ]; then
  bad "(d5) marker cleared first, driver signal still untouched -> ALLOW — clearing the marker disarmed the guard, so step 5 before step 4 escapes both new arms"
elif has "$rr" "$DRIVER_MARK"; then
  ok "(d5) marker cleared first, driver signal still untouched -> still BLOCKS on step 4 (the earlier armed Stop keeps the guard armed for this session)"
else
  bad "(d5) blocked, but not on the driver arm. It reads: $(printf '%s' "$rr" | head -c 120)"
fi
grep -qF -- "armed by an earlier Stop" "$P_DISK/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
  && ok "  the block row says the guard was armed by an earlier Stop, not by a key — the record is attributable" \
  || bad "  the block row does not say how the guard was armed; a retro cannot tell a sticky arming from a live key"
: > "$P_DISK/_bmad-output/.driver/handoff"; rm -f "$P_DISK/_bmad-output/handoff-guard-state.txt"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK")")"
[ "$r" = allow ] && ok "  control: the touch satisfies the guard -> ALLOW" \
                 || bad "  BLOCKED after the touch ($r) — the sticky arming does not release on a complete handoff"
[ -f "$ARMED" ] && bad "  the arming record survived a satisfied handoff — the NEXT paused Stop of this session would be examined for a handoff that is over" \
                || ok "  the arming record is removed on the satisfied path"
# A DIFFERENT session with the record on disk must not be armed by it, and must clear it.
reset_state "$P_DISK"; touch "$P_DISK/_bmad-output/pipeline-paused.flag"; printf '%s\n' "$SESS_A" > "$ARMED"
rm -f "$P_DISK/_bmad-output/.driver/handoff"
r="$(verdict "$(drive "$P_DISK" "$SESS_B" "$T_QUIET")")"
[ "$r" = allow ] && ok "  near-miss: another session's arming record does not arm THIS session -> ALLOW" \
                 || bad "  another session's arming record BLOCKED this one ($r) — the record is not session-bound and would wedge the successor at its first paused Stop"
[ -f "$ARMED" ] && bad "  a foreign arming record was left on disk — it will be re-read at every Stop" \
                || ok "  a foreign arming record is cleared"
# And the record must not survive the pause flag coming down (the handoff was abandoned).
reset_state "$P_DISK"; printf '%s\n' "$SESS_A" > "$ARMED"; rm -f "$P_DISK/_bmad-output/.driver/handoff"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_QUIET")")"
{ [ "$r" = allow ] && [ ! -f "$ARMED" ]; } \
  && ok "  near-miss: the pause flag DOWN clears the record and does not arm (an abandoned handoff does not haunt the session)" \
  || bad "  with the pause flag down the record armed the guard or survived ($r, record $([ -f "$ARMED" ] && echo present || echo absent)) — a lead that resumed after abandoning a handoff is blocked on it"

# =============================================================================
# ai-dlc-continue.sh — THE ON-DISK TRIGGER (the predicate, through the Stop caller)
# =============================================================================
# Every case below drives the SAME transcript -- one whose last user message is NOT a request
# -- against the SAME non-git tree, so the push arm is out of scope and the only thing that
# varies is the state under _bmad-output. A BLOCK here can only have come from the predicate.
#
# THE PAUSE FLAG IS PRESENT IN ALL OF THEM, because the predicate requires it. It is also what
# really happens: ai-dlc-pause.sh raised it the moment the operator typed. Check 0 runs BEFORE
# Check 1, so the flag does not itself produce the allow.
dsetup() { # dsetup [log-file|""] [marker: yes|no]
  reset_state "$P_DISK"
  touch "$P_DISK/_bmad-output/pipeline-paused.flag"
  [ -n "${1:-}" ] && cp "$1" "$P_DISK/_bmad-output/pipeline-continuation-log.md"
  [ "${2:-no}" = yes ] && mkmarker "$P_DISK" "${3:-$HOOKS_DIR}"
  return 0
}
disk() { # disk <session> [hooksdir] -> verdict
  verdict "$(drive "$P_DISK" "$1" "$T_QUIET" "${2:-$HOOKS_DIR}")"
}
disk_log() { printf '%s' "$P_DISK/_bmad-output/pipeline-continuation-log.md"; }

# (f) PAUSED, BUT NO KEY AT ALL. The hook seeds its own legend header into an absent log, and
#     that legend NAMES every event type and uses the words "handoff intent" in prose -- so
#     this is also the control that key 3 is anchored on a `## <ts> -- USER_PAUSE` heading and
#     not on a substring of the machinery's own documentation.
dsetup
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "(f) pause flag but NO key -> ALLOW (the pause flag alone is never a pending handoff)" \
                 || bad "(f) the guard fired with no handoff record on disk ($r) — the flag alone is being read as a key, and every paused turn in a sprint would block"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_NOBLK")")"
[ "$r" = block ] && ok "  control: the same tree BLOCKS a transcript-visible request with no resume block — the hook runs here" \
                 || bad "  the on-disk tree did not block a transcript-visible request either ($r) — every ALLOW in this section is unreadable"

# KEY 1 THROUGH THIS CALLER. The recover battery owns the key-1 mutant; this arm exists
# because the two callers pass different state dirs and different session sources, and a
# defect in either is invisible to a fixture that only drives the other.
dsetup "" yes
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(f2) key 1, the entry marker, reaches the Stop caller too -> BLOCK" \
                 || bad "(f2) the entry marker did not block at the Stop seam ($r) — ai-dlc-recover.sh and ai-dlc-continue.sh are answering the same question differently, which is the drift the shared predicate exists to prevent"
_kl="$(disk_log)"
if grep -qF -- "via entry-marker" "$_kl" 2>/dev/null; then
  ok "  the HANDOFF_GUARD_BLOCK row names WHICH key fired (entry-marker) — retro's investigation channel is populated"
else
  bad "  the block row does not name the key that fired; a retro reading these counts cannot tell a queued message from a lead mid-procedure"
fi

# (g) A handoff request recorded against THIS session.
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(g) key 3, a USER_PAUSE row carrying handoff intent, SAME session -> BLOCK" \
                 || bad "(g) a handoff recorded on disk for THIS session was ALLOWED ($r) — this is the queued-message episode, and the guard is silent for exactly the reason the predicate was written"
if grep -qF -- "via log-request" "$(disk_log)" 2>/dev/null; then
  ok "  and the row names key 3 (log-request), not key 1 — the two keys are distinguishable in the record"
else
  bad "  the block row does not name log-request; the key attribution is wrong or missing and a retro cannot tell which channel saw the request"
fi

# (g2) THE SAME REQUEST AS THE BARE WORD, which is what the operator actually typed. It can
#      only match through the ANCHORED `^ *hand[ -]?off *$` alternative, and that alternative
#      cannot match a line still carrying its `- Prompt (first 120 chars): ` prefix. So this
#      case, and only this case, distinguishes a pattern applied to the extracted field VALUE
#      from one applied to the whole log LINE -- a line-wise grep reads a real request as a
#      non-instance and returns a clean, plausible zero.
log_prompt "$LG" "$SESS_A" "$P_BARE"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(g2) the bare word '$P_BARE' as the field VALUE -> BLOCK (the pattern is applied to the value, not the line)" \
                 || bad "(g2) the bare word '$P_BARE' was ALLOWED ($r) — the intent pattern is being applied to the whole log line, where its anchored alternative can never match"

# (g3) KEY 3 IS SCORED PER ROW, AND THIS IS THE EPISODE'S OWN LOG SHAPE. The session was
#      started by `/ai-dlc resume`, which ai-dlc-pause.sh records as its first row, and the
#      operator typed `handoff` hours later. With the exclusion applied to the session's prose
#      JOINED, `/ai-dlc` in row one vetoed the request in row two and the guard allowed the
#      stop -- the incident PC-S308-HANDOFF-PROCEDURE-5-STEP-NOT-FOLLOWED was filed from. Per
#      row, the request stands on its own. Killed by mutant M20 and by nothing else.
log_two_row "$LG" "$SESS_A" "$P_RESUME" "$P_BARE"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(g3) key 3: a '$P_RESUME' row FOLLOWED by a '$P_BARE' row, same session -> BLOCK (the exclusion vetoes its own row, not the session)" \
                 || bad "(g3) the request was ALLOWED ($r) — the mention exclusion is being applied to the whole session's prose, so every session started by the slash command has key 3 disarmed for its whole life; this is the filed incident exactly"
log_two_row "$LG" "$SESS_A" "$P_RESUME" "$P_NOINTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  near-miss: the same first row followed by a NON-request -> ALLOW (per-row scoring did not widen the key)" \
                 || bad "  a resumed session with no request BLOCKED ($r) — per-row scoring is reading the slash command itself as a request"

# (h) THE SESSION BOUND IS THE DISCHARGE. The log is rotated per sprint, so "any handoff row"
#     would stay true for every later session in the sprint and would block ordinary work at
#     its first Stop. Same tree, same log bytes, only the driving session id differs.
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
r="$(disk "$SESS_B")"
[ "$r" = allow ] && ok "(h) the same row read by a DIFFERENT session -> ALLOW (the session bound discharges the row)" \
                 || bad "(h) a handoff recorded for another session BLOCKED this one ($r) — the row never expires and every session for the rest of the sprint wedges at its first Stop"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "  control: the identical row read by ITS OWN session still BLOCKS — the ALLOW above is the session bound, not a dead reader" \
                 || bad "  the identical row did not block its own session either ($r) — (h) proves nothing"

# (i) MECHANISM DISCUSSION IS NOT A REQUEST. The prose matches the intent pattern AND the
#     mention exclusion; the exclusion is a veto, and without it the guard fires on someone
#     asking why it fired.
log_prompt "$LG" "$SESS_A" "$P_DISCUSS"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "(i) prose that DISCUSSES the guard while quoting the request -> ALLOW (the exclusion pattern vetoes it)" \
                 || bad "(i) a question ABOUT the handoff guard BLOCKED ($r) — the exclusion conjunct is not being applied, and the guard now fires on its own subject"
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "  control: the request WITHOUT the mechanism words, same tree and same session, still BLOCKS — (i) is the exclusion firing, not the reader failing" \
                 || bad "  the plain request did not block either ($r) — (i) proves nothing"

# (j) THE LEAD MUST NOT ROUTE ITS OWN GUARD. `- Question` is lead-authored and
#     ai-dlc-answer-capture.sh labels it "NOT the intent signal" in the row itself. The pair
#     below is the same row shape with the handoff words moved between the two fields.
log_answer "$LG" "$SESS_A" "$Q_INTENT" "$P_NOINTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "(j) handoff words in the lead-authored '- Question' line only -> ALLOW (the lead cannot route its own guard)" \
                 || bad "(j) the lead-authored question BLOCKED ($r) — a lead can now trigger the handoff guard by phrasing its own AskUserQuestion, and the operator's answer is not what is read"
log_answer "$LG" "$SESS_A" "$Q_NOINTENT" "$P_INTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "  control: the same row with the handoff words in the OPERATOR's '- Answer' field BLOCKS — (j) is the field bound, not a dead reader" \
                 || bad "  the operator's answer field did not block either ($r) — (j) proves nothing, and the AskUserQuestion channel is unguarded"

# =============================================================================
# ai-dlc-recover.sh — THE STEP-FILE OVERRIDE (the predicate, through the compact caller)
# =============================================================================
# TWO INDEPENDENTLY DERIVED VALUES, COMPARED. The mandate is read out of the emitted
# additionalContext; `.recover-fired`'s `step_file=` is written by a different statement in the
# same run and is what `ai-dlc-recover-gate.sh` actually arms on. Reading only one of them
# would leave a hook that emits a correct mandate and arms the gate on a different file
# indistinguishable from a working one.
rsetup() { # rsetup <projdir> <snapshot> <flag: yes|no> <marker: yes|no> [log]
  reset_state "$1"
  cp "$2" "$1/_bmad-output/pipeline-snapshot.md"
  [ "$3" = yes ] && touch "$1/_bmad-output/pipeline-paused.flag"
  [ "$4" = yes ] && mkmarker "$1"
  [ -n "${5:-}" ] && cp "$5" "$1/_bmad-output/pipeline-continuation-log.md"
  return 0
}
rassert() { # rassert <label> <projdir> <session> <expected-relpath> <failmsg> [hooksdir]
  local ctx sp mk
  ctx="$(rdrive "$2" "$3" "${6:-$HOOKS_DIR}")"
  if [ -z "$ctx" ]; then
    bad "$1: the recover hook emitted NO additionalContext at all — it did not run, and every negative in this section would read the same way"
    return
  fi
  sp="$(printf '%s' "$ctx" | sed -n 's/.*Your SECOND tool call MUST be `Read \([^`]*\)` in full.*/\1/p' | head -1)"
  if [ -z "$sp" ]; then
    bad "$1: the emitted block names NO second-mandate path — it took the unresolved branch, so this case says nothing about the override"
    return
  fi
  mk="$(sed -n 's/^step_file=//p' "$2/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
  if [ "$sp" != "$mk" ]; then
    bad "$1: the mandate names '$sp' but .recover-fired records '$mk' — the lead and the gate are being pointed at different files"
    return
  fi
  [ "$sp" = "$4" ] && ok "$1" || bad "$5 (the mandate named '$sp', expected '$4')"
}

SNAP_PLAIN="$ROOT/snap-plain.md"
SNAP_HEADING="$ROOT/snap-heading.md"
SNAP_BOLD="$ROOT/snap-bold.md"
SNAP_MENTION="$ROOT/snap-mention.md"

# (l) Nothing pending. The baseline, and it is PRESENCE-shaped: it requires the mandate to
#     name the snapshot's own step file, which a hook that emitted nothing cannot do.
rsetup "$P_REC" "$SNAP_PLAIN" no no
rassert "(l) nothing pending -> the mandate names the snapshot's own current_step_file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(l) a recovery with NO pending handoff was routed to handoff.md — every compaction in the sprint now recovers into the wrong procedure"

# (m) The pause flag on its own. It is raised by every Rule 3 pause point and by every operator
#     message, and steps/handoff.md step 5 creates it too, so on its own it is as true after a
#     completed handoff as during a pending one.
rsetup "$P_REC" "$SNAP_PLAIN" yes no
rassert "(m) pause flag alone, no key -> still the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(m) the pause flag alone routed the recovery to handoff.md — every paused compaction in a sprint would recover into the handoff procedure"

# (n) KEY 1, the entry marker, alone: no HANDOFF POINT heading and no continuation log, so
#     neither of the other two keys can reach this case.
rsetup "$P_REC" "$SNAP_PLAIN" yes yes
rassert "(n) key 1 (.handoff-in-progress) -> the mandate names handoff.md" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(n) a compaction landing INSIDE the handoff procedure was routed back to the interrupted step — the marker steps/handoff.md exists to leave is not being read"

# (s) THE SAME PENDING STATE WITH steps/handoff.md UNREADABLE. A mandate must name something
#     the lead can actually read; a lead that cannot comply learns that these MUSTs are
#     negotiable. Beside (n) in the same tree, differing in one file.
# The marker is produced BEFORE handoff.md is moved away, so this case is genuinely "the
# procedure was entered and the file has since become unreadable" rather than a marker the
# fixture invented for a file that was never there.
rsetup "$P_REC" "$SNAP_PLAIN" yes yes
mv "$P_REC/$STEP_HANDOFF" "$P_REC/${STEP_HANDOFF}.hidden"
rassert "(s) pending, but steps/handoff.md is ABSENT -> falls back to the snapshot's step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(s) the override named handoff.md in a tree where it does not exist — the mandate cannot be complied with, and ai-dlc-recover-gate.sh would arm on a path that resolves nowhere"
mv "$P_REC/${STEP_HANDOFF}.hidden" "$P_REC/$STEP_HANDOFF"
[ -r "$P_REC/$STEP_HANDOFF" ] || broken "failed to restore $STEP_HANDOFF after case (s) — every later recover case would be testing an absent file"

# (o) KEY 2, the snapshot's handoff record, alone: no entry marker and no continuation log.
#
# TWO POSITIVE SHAPES AND ONE NEGATIVE, ordered by PROVENANCE, because this key is the one
# whose grammar came from the reader rather than from a producer and that is exactly how it
# first went wrong. Nothing in core WRITES this record -- a lead does, by hand -- so the first
# grammar demanded a markdown heading and scored ZERO on the only instance that exists
# anywhere. (o) is the found shape and is primary; (o-synth) is the imagined one and is kept
# only because it is a legal spelling the key must still accept. A battery carrying (o-synth)
# alone passes against the grammar that shipped broken.
rsetup "$P_REC" "$SNAP_BOLD" yes no
rassert "(o) key 2 as the reference consumer ACTUALLY wrote it — a bold lead-in, no '#' -> handoff.md" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(o) the ONE real handoff record that exists scores as a non-instance — a grammar that demands a heading misses the very record this key was added to detect, and a consumer mid-handoff at pull time has this key and nothing else"

rsetup "$P_REC" "$SNAP_HEADING" yes no
rassert "(o-synth) key 2 as a markdown HEADING, the reader-derived shape -> handoff.md" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(o-synth) a snapshot carrying a handoff record as a heading was routed back to the interrupted step"

# (o2) THE SAME WORDS MID-LINE, which is discussion and not a record. Beside both positives in
#      the same tree, differing only in where on the line the words sit.
rsetup "$P_REC" "$SNAP_MENTION" yes no
rassert "(o2) the same words as a MENTION mid-line -> the snapshot's own step file (a mention is not a record)" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(o2) a snapshot merely DISCUSSING the handoff record was treated as carrying one — the key is a bare substring and any snapshot whose prose names the section reroutes every compaction"

# (p) KEY 3, this session's request rows, alone: no entry marker and no HANDOFF POINT heading.
#     TWO ROWS, request first and a question about it second. See log_two_row's header.
log_two_row "$LG" "$SESS_A" "$P_INTENT" "$P_AFTER"
rsetup "$P_REC" "$SNAP_PLAIN" yes no "$LG"
rassert "(p) key 3 (this session's request row, with a LATER non-request row after it) -> handoff.md" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(p) the operator's recorded request was not found — either key 3 is dead, or the reader keeps only the LAST block of the session, which is the 'most recent row' reading measured at 1 of 22 and rejected"

# (q) The same two-row log read by a DIFFERENT session. Beside (p) in the same tree, same
#     bytes on disk, differing only in the session id the harness supplies.
rsetup "$P_REC" "$SNAP_PLAIN" yes no "$LG"
rassert "(q) the same rows read by a DIFFERENT session -> the snapshot's own step file" \
  "$P_REC" "$SESS_B" "$STEP_IMPL" \
  "(q) another session's handoff rows rerouted this recovery — the log is rotated per sprint, so every compaction for the rest of the sprint would recover into handoff.md"

# (r) EVERY KEY PRESENT AND THE PAUSE FLAG GONE. This is the state a resumed session is in:
#     the resume path removed the flag, and a stale marker or an old log row must not fire.
log_two_row "$LG" "$SESS_A" "$P_INTENT" "$P_AFTER"
rsetup "$P_REC" "$SNAP_HEADING" no yes "$LG"
rassert "(r) all three keys present but NO pause flag -> the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(r) a stale key fired with the pipeline unpaused — a session that has already resumed would be dragged back into the handoff procedure on its next compaction"

# The consumer layout. `install.sh` splits what shares a parent here, and a path that resolves
# in this tree can resolve nowhere in an installed one; the override's candidate loop tries
# `.claude/...` FIRST, so the distribution layout above exercises only its second branch.
rsetup "$P_REC_CLAUDE" "$SNAP_PLAIN" yes yes
rassert "(n-consumer) key 1 in a .claude/ INSTALLED layout -> the mandate names .claude/…/handoff.md" \
  "$P_REC_CLAUDE" "$SESS_A" "$STEP_HANDOFF_C" \
  "(n-consumer) the override did not resolve in the consumer layout — it would name nothing on every installed tree, which is where this hook actually runs"
rsetup "$P_REC_CLAUDE" "$SNAP_PLAIN" no no
rassert "  control: the same consumer tree with nothing pending -> .claude/…/implementation.md" \
  "$P_REC_CLAUDE" "$SESS_A" "$STEP_IMPL_C" \
  "  the consumer tree does not resolve its own step file either — the layout arm above proves nothing"

# =============================================================================
# ai-dlc-handoff-entry.sh — THE PRODUCER OF KEY 1
# =============================================================================
# Key 1 is the only key with a shipped writer, and until this section existed every key-1 seed
# in this fixture was a file the fixture touched itself -- which proves the reader accepts the
# fixture's own spelling and nothing about whether the two halves agree. `mkmarker` now drives
# this hook for every key-1 seed above, so those arms and these share one producer.
#
# WHY A HOOK AND NOT THE STEP FILE: I95 rejected the step-file version, because
# pipeline-state-paths.json's `producer` field requires a shipped file that CONSTRUCTS the path
# on a non-comment line, and a file that tells a lead to construct it does not. The defect this
# whole change exists for is a lead that did not execute the procedure at all, so a marker whose
# only writer is that same procedure is absent in precisely the motivating case.
#
# THE NEGATIVES ARE ABSENCE-SHAPED AND A CRASHED HOOK PRODUCES THE SAME ABSENCE, so each one is
# followed IN THE SAME TREE by the positive, which must create the marker.
eassert() { # eassert <label> <tool> <path> <want: marker|no-marker> <failmsg>
  local rc
  rm -f "$P_ENTRY/_bmad-output/.handoff-in-progress"
  rc="$(edrive "$P_ENTRY" "$2" "$3")"
  if [ "$rc" != "0" ]; then
    bad "$1: the hook exited $rc — it is PostToolUse, it runs after the call has returned, and every path must exit 0 or the pipeline's ability to READ a step file depends on its ability to write one"
    return
  fi
  if [ "$4" = marker ]; then
    marker_at "$P_ENTRY" && ok "$1" || bad "$5"
  else
    marker_at "$P_ENTRY" && bad "$5" || ok "$1"
  fi
}
econtrol() { # econtrol — the positive, in the same tree, after a negative
  rm -f "$P_ENTRY/_bmad-output/.handoff-in-progress"
  local rc; rc="$(edrive "$P_ENTRY" Read "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md")"
  { [ "$rc" = 0 ] && marker_at "$P_ENTRY"; } \
    && ok "  control: a Read of steps/handoff.md in the same tree DOES create the marker — the hook runs here" \
    || bad "  the hook does not create the marker in this tree either (exit $rc) — the absence above is a dead hook, not a guard"
}

eassert "(e1) Read of steps/handoff.md -> the entry marker is created" \
  Read "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md" marker \
  "(e1) a Read of the handoff step file left NO marker — the only on-disk trace that the lead ENTERED the procedure is missing, and a compaction inside the five steps recovers into the interrupted step"

eassert "(e1c) the same file by its CONSUMER spelling (.claude/…) -> the marker is created" \
  Read "$P_ENTRY/.claude/skills/ai-dlc/steps/handoff.md" marker \
  "(e1c) the consumer spelling did not match — the hook is anchored on a distribution-only path and would never fire on an installed tree, which is where it actually runs"

eassert "(e2) Read of a DIFFERENT step file -> no marker" \
  Read "$P_ENTRY/core/skills/ai-dlc/steps/implementation.md" no-marker \
  "(e2) reading an ordinary step file created the handoff marker — every step in the pipeline would then look like a handoff in progress"
econtrol

eassert "(e2b) Read of a consumer's OWN unrelated docs/handoff.md -> no marker" \
  Read "$P_ENTRY/docs/handoff.md" no-marker \
  "(e2b) a file merely NAMED handoff.md, outside steps/, created the marker — the match is on the basename alone and any consumer document with that name arms the guard"
econtrol

eassert "(e3) EDIT of steps/handoff.md -> no marker" \
  Edit "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md" no-marker \
  "(e3) editing the step file created the marker — the marker means the lead is EXECUTING the procedure, and an author changing the file is not"
econtrol

# (e4) NO _bmad-output DIRECTORY. A plain file read must not manufacture pipeline state, and
#      the hook must still exit 0: it is PostToolUse, so a failure here cannot be allowed to
#      surface as a tool error.
rm -rf "$P_ENTRY/_bmad-output"
_e4rc="$(edrive "$P_ENTRY" Read "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md")"
if [ "$_e4rc" != "0" ]; then
  bad "(e4) with no _bmad-output directory the hook exited $_e4rc — a marker hook that can fail makes reading a step file depend on writing a file"
elif [ -d "$P_ENTRY/_bmad-output" ]; then
  bad "(e4) the hook CREATED _bmad-output on a tree that has never run the pipeline — a plain file read now manufactures pipeline state"
else
  ok "(e4) no _bmad-output directory -> no marker, no directory created, and exit 0"
fi
mkdir -p "$P_ENTRY/_bmad-output"
econtrol

# (e5) THE PRODUCER/CONSUMER JOIN, END TO END. Nothing below hand-writes the marker: the entry
#      hook writes it and the recover hook reads it through the shared predicate. Two shipped
#      halves, one file, no fixture-authored spelling in between -- which is the only form of
#      this assertion that could catch the two disagreeing about the path or the filename.
reset_state "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
_e5rc="$(edrive "$P_REC" Read "$P_REC/$STEP_HANDOFF")"
if [ "$_e5rc" != "0" ] || ! marker_at "$P_REC"; then
  bad "(e5) the entry hook did not write a marker into the recover tree (exit $_e5rc) — the join below cannot be read"
else
  rassert "(e5) the marker the ENTRY hook wrote routes a recovery to handoff.md (no hand-written seed anywhere)" \
    "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
    "(e5) the writer and the reader disagree about the entry marker — each half works against a seed the fixture wrote, and neither works against the other"
fi

# =============================================================================
# MUTANTS
# =============================================================================
# Both-directions seeding establishes that an arm discriminates between two inputs; only a
# mutant establishes that it discriminates AT ALL.
#
# EACH MUTANT IS A COPY OF THE WHOLE HOOKS DIRECTORY with one file edited inside it, because
# both hooks source the predicate as a SIBLING: a lone mutated copy finds no library, fails
# open, and reads exactly like a guard that stood down. Guarded with `cmp -s` so a `sed` that
# matched nothing reports FIXTURE STALE instead of scoring a kill, and with `bash -n` so a kill
# cannot be a syntax error. Every one is driven with a control -- a case it does not touch,
# which must still produce its baseline output -- because several kills are ALLOW-shaped and a
# copy that died on load also emits nothing.
echo ""
echo "  --- mutants (hooks resolved from: $HOOKS_DIR) ---"

MUT_DIR=""
mkmut() { # mkmut <name> <target-basename> <sed-arg>... -> sets MUT_DIR
  local name="$1" tgt="$2"; shift 2
  MUT_DIR=""
  local d="$ROOT/mut-$name"
  rm -rf "$d"; mkdir -p "$d"
  cp "$HOOKS_DIR"/*.sh "$d"/ 2>/dev/null || true
  if [ ! -f "$d/$tgt" ]; then
    bad "FIXTURE STALE: $tgt is not in the resolved hooks directory — mutation '$name' has no subject"
    return 1
  fi
  sed "$@" "$HOOKS_DIR/$tgt" > "$d/$tgt"
  if cmp -s "$HOOKS_DIR/$tgt" "$d/$tgt"; then
    bad "FIXTURE STALE: mutation '$name' matched nothing in $tgt — the subject was reworded, so this battery is editing a file it does not understand"
    return 1
  fi
  if ! bash -n "$d/$tgt" 2>/dev/null; then
    bad "FIXTURE STALE: mutant '$name' ($tgt) does not parse — a kill would be a syntax error rather than a disarmed guard"
    return 1
  fi
  MUT_DIR="$d"
  return 0
}

# Every mutant's control: the unpushed-branch Stop case, which no mutation below touches. It is
# PRESENCE-shaped (a block carrying the step-3 text), so a copy that died on load fails it.
mut_ctl() { # mut_ctl <name> <mutdir>
  reset_state "$P_UNPUSHED"
  local rr; rr="$(reason "$(drive "$P_UNPUSHED" "$SESS_A" "$T_REQ_OK" "$2")")"
  { [ -n "$rr" ] && has "$rr" "$PUSH_MARK"; } \
    && ok "  control [$1]: the copy still BLOCKS the unpushed case with the step-3 text — it loads and runs" \
    || bad "MUTANT HARNESS BROKEN [$1]: the copy no longer produces the step-3 block ($([ -n "$rr" ] && echo "different text" || echo "no output")); it is not running and the kill above is unreadable"
}

# A Stop-seam kill: expect a verdict from the mutated copy.
kill_stop() { # kill_stop <name> <mutdir> <want> <killmsg>
  local r; r="$(disk "$SESS_A" "$2")"
  [ "$r" = "$3" ] && ok "  mutant [$1] KILLED by $4" \
                  || bad "MUTANT SURVIVED [$1]: expected $3, got $r — $4 does not depend on the mutated code, so that assertion proves nothing"
}
# A recover-seam kill: expect a named path from the mutated copy.
kill_rec() { # kill_rec <name> <mutdir> <projdir> <session> <want-relpath> <killmsg>
  local ctx sp
  ctx="$(rdrive "$3" "$4" "$2")"
  sp="$(printf '%s' "$ctx" | sed -n 's/.*Your SECOND tool call MUST be `Read \([^`]*\)` in full.*/\1/p' | head -1)"
  [ "$sp" = "$5" ] && ok "  mutant [$1] KILLED by $6" \
                   || bad "MUTANT SURVIVED [$1]: the mandate named '${sp:-<nothing>}', expected '$5' — $6 does not depend on the mutated code"
}

LIBF="ai-dlc-handoff-pending.sh"
CONF="ai-dlc-continue.sh"
RECF="ai-dlc-recover.sh"

# --- ai-dlc-continue.sh: the push arm --------------------------------------------------
# M1 — drop the `remote exists` conjunct. The arm then blocks in a local-only repo, which is
#      the false positive the narrowing exists to prevent. Killed by (b).
if mkmut m1-no-remote-conjunct "$CONF" \
     -e 's|^      if \[ -n "$(git -C "$PROJECT_DIR" remote 2>/dev/null)" \]; then$|      if true; then|'; then
  reset_state "$P_NOREMOTE"
  r="$(verdict "$(drive "$P_NOREMOTE" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  [ "$r" = block ] && ok "  mutant [m1] KILLED by assertion (b): with the remote conjunct gone, a local-only repo now BLOCKS" \
                   || bad "MUTANT SURVIVED [m1]: the local-only repo still returned $r"
  mut_ctl m1 "$MUT_DIR"
fi

# M2a — the ahead test inverted, first half: a branch that is up to date now blocks. Killed by
#       (d). Split from M2b so each half fails exactly one assertion; a single inverting mutant
#       would move two cells and neither would own the case.
if mkmut m2a-zero-ahead-blocks "$CONF" -e 's|^            0) : ;;$|            0) PUSH_OK=0 ;;|'; then
  reset_state "$P_PUSHED"
  r="$(verdict "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  [ "$r" = block ] && ok "  mutant [m2a] KILLED by assertion (d): a published, up-to-date branch now BLOCKS" \
                   || bad "MUTANT SURVIVED [m2a]: the up-to-date branch still returned $r"
  mut_ctl m2a "$MUT_DIR"
fi

# M2b — the ahead test inverted, second half: unpushed commits now pass. Killed by (e). This
#       kill is ALLOW-shaped, which is exactly why the control beside it is not optional.
if mkmut m2b-ahead-allowed "$CONF" -e 's|^            \*) PUSH_OK=0 ;;$|            *) : ;;|'; then
  reset_state "$P_AHEAD"
  r="$(verdict "$(drive "$P_AHEAD" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  [ "$r" = allow ] && ok "  mutant [m2b] KILLED by assertion (e): a branch 1 commit ahead is now ALLOWED" \
                   || bad "MUTANT SURVIVED [m2b]: the branch 1 ahead still returned $r"
  mut_ctl m2b "$MUT_DIR"
fi

# M3 — restore the OLD two-arm dispatch, which inferred the cause from RESUME_OK. The verdict
#      is unchanged, so only assertion (k) can see this: the lead is blocked and handed the
#      teammate remedy for a push that did not land.
if mkmut m3-old-dispatch "$CONF" \
     -e 's|^        if \[ "$PUSH_OK" != "1" \] && \[ "$TEAMMATES_OK" = "1" \] && \[ "$RESUME_OK" = "1" \]; then$|        if false; then|' \
     -e 's|^        if \[ "$TEAMMATES_OK" != "1" \]; then$|        if [ "$RESUME_OK" = "1" ]; then|'; then
  reset_state "$P_UNPUSHED"
  _m3="$(reason "$(drive "$P_UNPUSHED" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  if [ -n "$_m3" ] && has "$_m3" "$TEAM_MARK" && ! has "$_m3" "$PUSH_MARK"; then
    ok "  mutant [m3] KILLED by assertion (k): the old dispatch answers a missing PUSH with the TEAMMATE text, and the verdict never changes"
  else
    bad "MUTANT SURVIVED [m3]: the old two-arm dispatch still emitted the step-3 text (or nothing) — assertion (k) is not reading the dispatch"
  fi
  # This mutant's own control cannot be mut_ctl, which reads the step-3 text it deliberately
  # removes. The teammate text above IS the presence conjunct.
  ok "  control [m3]: the kill is PRESENCE-shaped — it required the teammate text to appear, which a copy emitting nothing cannot do"
fi

# --- ai-dlc-handoff-pending.sh: the shared predicate -------------------------------------
# M4 — THE FLUSH. The USER_PAUSE rule ends in `next`, so without a flush before the reset a
#      second header discards the first block and only the LAST block of the session survives.
#      That is the "most recent row" reading, measured on the consumer at 1 of 22 and rejected.
#      Killed by (p) alone: (p) is the only arm whose log carries two rows.
if mkmut m4-no-flush "$LIBF" \
     -e 's|USER_PAUSE\[\[:space:\]\]\*$/ { if (inb && mine) out = out buf; inb=1|USER_PAUSE[[:space:]]*$/ { inb=1|'; then
  log_two_row "$LG" "$SESS_A" "$P_INTENT" "$P_AFTER"
  rsetup "$P_REC" "$SNAP_PLAIN" yes no "$LG"
  kill_rec m4 "$MUT_DIR" "$P_REC" "$SESS_A" "$STEP_IMPL" \
    "assertion (p): with the flush gone only the LAST row survives, and the request in the FIRST row is lost"
  mut_ctl m4 "$MUT_DIR"
fi

# M5 — drop the pause-flag conjunct. Killed by (r): a stale key with the pipeline unpaused.
if mkmut m5-no-pause-flag "$LIBF" \
     -e 's@^  \[ -f "${_sd}/pipeline-paused.flag" \] || return 1$@  : # pause-flag conjunct removed@'; then
  log_two_row "$LG" "$SESS_A" "$P_INTENT" "$P_AFTER"
  rsetup "$P_REC" "$SNAP_HEADING" no yes "$LG"
  kill_rec m5 "$MUT_DIR" "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
    "assertion (r): keys now fire with the pipeline unpaused, so a resumed session is dragged back into the handoff"
  mut_ctl m5 "$MUT_DIR"
fi

# M6 — disable key 1. Killed by (n), whose seed carries no snapshot heading and no log, so
#      neither of the other two keys can cover it.
if mkmut m6-no-key1 "$LIBF" -e 's|^  if \[ -f "${_sd}/.handoff-in-progress" \]; then$|  if false; then|'; then
  rsetup "$P_REC" "$SNAP_PLAIN" yes yes
  kill_rec m6 "$MUT_DIR" "$P_REC" "$SESS_A" "$STEP_IMPL" \
    "assertion (n): the entry marker no longer routes a compaction landing inside the procedure"
  mut_ctl m6 "$MUT_DIR"
fi

# M7 — disable key 2. Killed by (o), whose seed carries no entry marker and no log.
if mkmut m7-no-key2 "$LIBF" \
     -e 's|^  if \[ -r "${_sd}/pipeline-snapshot.md" \] \\$|  if false \&\& [ -r "${_sd}/pipeline-snapshot.md" ] \\|'; then
  rsetup "$P_REC" "$SNAP_HEADING" yes no
  kill_rec m7 "$MUT_DIR" "$P_REC" "$SESS_A" "$STEP_IMPL" \
    "assertion (o): the snapshot's own handoff record no longer routes the recovery"
  mut_ctl m7 "$MUT_DIR"
fi

# M8 — disable key 3. Killed by (p), whose seed carries no entry marker and no snapshot heading.
if mkmut m8-no-key3 "$LIBF" -e 's|^  \[ -n "$_sess" \] && \[ -r "$_log" \].*|  return 1|'; then
  log_two_row "$LG" "$SESS_A" "$P_INTENT" "$P_AFTER"
  rsetup "$P_REC" "$SNAP_PLAIN" yes no "$LG"
  kill_rec m8 "$MUT_DIR" "$P_REC" "$SESS_A" "$STEP_IMPL" \
    "assertion (p): the continuation log is no longer read, so the key that needs no lead cooperation is gone"
  mut_ctl m8 "$MUT_DIR"
fi

# M9 — key 2 loses its line anchor and matches the words ANYWHERE. Killed by (o2).
#
# THE SED DELIMITER IS `@`, NOT `|`, AND THAT IS NOT COSMETIC. Written as `s|...|...|` this
# line reads to I54b as a shell pipeline feeding `grep -q` under pipefail, and the arm failed
# the push on it -- a false positive, because the `|` here are sed delimiters inside a quoted
# argument and there is no pipeline on this line at all. The arm's grammar cannot tell the two
# apart, and it is right to be that blunt: the real idiom it hunts is silent and size-dependent.
# Any mutation whose replacement text mentions a reader belongs on a non-pipe delimiter.
if mkmut m9-key2-mention "$LIBF" \
     -e "s@grep -qiE '\^\[\[:space:\]\]\*(#{1,6}\[\[:space:\]\]\*)?(\\\\\*\\\\\*)?HANDOFF POINT'@grep -qiE 'HANDOFF POINT'@"; then
  rsetup "$P_REC" "$SNAP_MENTION" yes no
  kill_rec m9 "$MUT_DIR" "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
    "assertion (o2): a snapshot merely DISCUSSING the record is now treated as carrying one"
  mut_ctl m9 "$MUT_DIR"
fi

# M9b — THE REGRESSION MUTANT FOR THE DEFECT THIS FIXTURE FOUND. Make the heading group
#       mandatory again, which is the grammar key 2 shipped with. It scores ZERO on the only
#       real handoff record in existence while looking perfectly reasonable and passing every
#       synthetic seed. Killed by (o) and by nothing else in this file — which is the whole
#       argument for keeping a producer-derived seed rather than an invented one.
if mkmut m9b-key2-requires-heading "$LIBF" \
     -e "s|(#{1,6}\[\[:space:\]\]\*)?(|#{1,6}[[:space:]]*(|"; then
  rsetup "$P_REC" "$SNAP_BOLD" yes no
  kill_rec m9b "$MUT_DIR" "$P_REC" "$SESS_A" "$STEP_IMPL" \
    "assertion (o): requiring a markdown heading again loses the reference consumer's real record"
  # And the READER-DERIVED shape must be UNAFFECTED. This arm demonstrates the seeding lesson
  # mechanically: under this mutant (o-synth) still passes, so a battery seeded only from the
  # reader would have reported the grammar that shipped broken as correct.
  rsetup "$P_REC" "$SNAP_HEADING" yes no
  _m9b="$(printf '%s' "$(rdrive "$P_REC" "$SESS_A" "$MUT_DIR")" | sed -n 's/.*Your SECOND tool call MUST be `Read \([^`]*\)` in full.*/\1/p' | head -1)"
  [ "$_m9b" = "$STEP_HANDOFF" ] && ok "  control [m9b]: the reader-derived HEADING seed still passes under the same mutant — a battery seeded only from the reader would have called the broken grammar correct" \
                               || bad "MUTANT TOO BROAD [m9b]: the heading seed stopped routing too ('${_m9b:-<nothing>}') — key 2 is off entirely and (o)'s kill is unattributable"
  mut_ctl m9b "$MUT_DIR"
fi

# M10 — drop the session-id conjunct in the awk. Killed by (q).
if mkmut m10-any-session "$LIBF" -e 's|if (index(.0, sess) > 0) mine=1|mine=1|'; then
  log_two_row "$LG" "$SESS_A" "$P_INTENT" "$P_AFTER"
  rsetup "$P_REC" "$SNAP_PLAIN" yes no "$LG"
  kill_rec m10 "$MUT_DIR" "$P_REC" "$SESS_B" "$STEP_HANDOFF" \
    "assertion (q): another session's rows now reroute this recovery"
  mut_ctl m10 "$MUT_DIR"
fi

# M11 — let the lead-authored `- Question` line feed the intent text. Killed by (j).
if mkmut m11-question-feeds-intent "$LIBF" \
     -e 's|^    inb && /\^-.*(Prompt.*{$|    inb \&\& /^-[[:space:]]+(Prompt\|Answer\|Question)[^:]*:/ {|'; then
  log_answer "$LG" "$SESS_A" "$Q_INTENT" "$P_NOINTENT"
  dsetup "$LG"
  kill_stop m11 "$MUT_DIR" block "assertion (j): the lead's own question now routes the guard"
  mut_ctl m11 "$MUT_DIR"
fi

# M12 — drop the exclusion-pattern conjunct. Killed by (i).
if mkmut m12-no-exclusion "$LIBF" \
     -e 's|&& ! grep -qiE "$_hm" <<<"$_row"; then$|\&\& true; then|'; then
  log_prompt "$LG" "$SESS_A" "$P_DISCUSS"
  dsetup "$LG"
  kill_stop m12 "$MUT_DIR" block "assertion (i): mechanism discussion now BLOCKS"
  mut_ctl m12 "$MUT_DIR"
fi

# M20 — THE REGRESSION MUTANT FOR THE INCIDENT THIS RELEASE FIXES. Apply the exclusion to the
#       session's prose JOINED instead of to the row, which is the shipped predicate before
#       v0.498.0. Killed by (g3) alone -- every other key-3 seed is a single-row log or a two-row
#       log whose rows both pass the exclusion, so only the `/ai-dlc resume` + `handoff` pair
#       can see the scope of the veto. ALLOW-shaped kill, so the control below asserts the
#       single-row request still BLOCKS under the same mutant: the mutation widened the veto's
#       scope and did not disable the key.
if mkmut m20-session-wide-exclusion "$LIBF" \
     -e 's|&& ! grep -qiE "$_hm" <<<"$_row"; then$|\&\& ! grep -qiE "$_hm" <<<"$_prose"; then|'; then
  log_two_row "$LG" "$SESS_A" "$P_RESUME" "$P_BARE"
  dsetup "$LG"
  kill_stop m20 "$MUT_DIR" allow "assertion (g3): the slash-command row vetoes the request row again, and the resumed session's handoff is ALLOWED to end incomplete"
  log_prompt "$LG" "$SESS_A" "$P_BARE"
  dsetup "$LG"
  r="$(disk "$SESS_A" "$MUT_DIR")"
  [ "$r" = block ] && ok "  control [m20]: the single-row request still BLOCKS under the same mutant — it widened the veto's scope, it did not disable key 3" \
                   || bad "MUTANT TOO BROAD [m20]: the single-row request stopped blocking too ($r) — the mutation disabled key 3 outright and (g3)'s kill is unattributable"
  mut_ctl m20 "$MUT_DIR"
fi

# --- ai-dlc-continue.sh: the driver-signal and marker arms -------------------------------
# M21 — the driver arm never fires. Killed by (d1) alone: the pushed tree with the signal
#       removed must BLOCK with the step-4 text, and under this mutant it ALLOWS.
if mkmut m21-no-driver-arm "$CONF" \
     -e 's|^    if \[ ! -f "$_drv" \]; then$|    if false; then|'; then
  reset_state "$P_PUSHED"
  rm -f "$P_PUSHED/_bmad-output/.driver/handoff"
  r="$(verdict "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  [ "$r" = allow ] && ok "  mutant [m21] KILLED by assertion (d1): with the driver arm gone a handoff that skipped step 4's touch ends the session" \
                   || bad "MUTANT SURVIVED [m21]: expected allow, got $r — (d1) does not depend on the driver arm, so that assertion proves nothing"
  # The marker arm must be UNAFFECTED, or the two new arms are one arm wearing two names.
  reset_state "$P_DISK"; mkmarker "$P_DISK"
  rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  has "$rr" "$MARKER_MARK" && ok "  control [m21]: the marker arm still BLOCKS with the step-5 text under the same mutant — the two arms are separable" \
                           || bad "MUTANT TOO BROAD [m21]: the marker case no longer blocks on step 5 either — removing the driver arm took the marker arm with it, so (d2) is entangled with (d1)"
  mut_ctl m21 "$MUT_DIR"
fi

# M23 — the driver arm accepts a STALE signal (the `-nt` clause removed). Killed by (d4) alone:
#       every other driver case removes or creates the file, so only the back-dated one sees it.
if mkmut m23-driver-presence-only "$CONF" \
     -e 's|^    elif \[ -f "$SNAPSHOT_FILE" \] && \[ "$SNAPSHOT_FILE" -nt "$_drv" \]; then$|    elif false; then|'; then
  reset_state "$P_PUSHED"
  touch -t 202001010000 "$P_PUSHED/_bmad-output/.driver/handoff"
  printf '# Pipeline Snapshot\n\n## Pipeline Position\ncurrent_step_file: implementation.md\n\n## In-Flight Teammates\n\n' > "$P_PUSHED/_bmad-output/pipeline-snapshot.md"
  touch "$P_PUSHED/_bmad-output/pipeline-paused.flag"
  r="$(verdict "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  [ "$r" = allow ] && ok "  mutant [m23] KILLED by assertion (d4): a presence-only arm accepts the previous handoff's stale signal" \
                   || bad "MUTANT SURVIVED [m23]: expected allow, got $r — (d4) does not depend on the freshness clause, so that assertion proves nothing"
  reset_state "$P_PUSHED"; rm -f "$P_PUSHED/_bmad-output/.driver/handoff"
  r="$(verdict "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  [ "$r" = block ] && ok "  control [m23]: the ABSENT signal still BLOCKS under the same mutant — it removed freshness, not presence" \
                   || bad "MUTANT TOO BROAD [m23]: the absent signal stopped blocking too ($r) — the mutation disabled the whole driver arm and (d4)'s kill is unattributable"
  reset_state "$P_PUSHED"
  mut_ctl m23 "$MUT_DIR"
fi

# M24 — the sticky arming never reads its record. Killed by (d5) alone: (d3)'s state, then the
#       marker cleared with the driver signal untouched, must still block, and under this mutant
#       nothing arms the second Stop.
if mkmut m24-no-sticky-arm "$CONF" -e 's|^      HANDOFF_STICKY=1$|      HANDOFF_STICKY=0|'; then
  reset_state "$P_DISK"; touch "$P_DISK/_bmad-output/pipeline-paused.flag"
  mkmarker "$P_DISK"; rm -f "$P_DISK/_bmad-output/.driver/handoff"
  drive "$P_DISK" "$SESS_A" "$T_QUIET_OK" "$MUT_DIR" >/dev/null       # the first, key-1-armed Stop
  rm -f "$P_DISK/_bmad-output/.handoff-in-progress" "$P_DISK/_bmad-output/handoff-guard-state.txt"
  r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK" "$MUT_DIR")")"
  [ "$r" = allow ] && ok "  mutant [m24] KILLED by assertion (d5): with the record unread, clearing the marker first escapes both new arms" \
                   || bad "MUTANT SURVIVED [m24]: expected allow, got $r — (d5) does not depend on the sticky arming, so that assertion proves nothing"
  reset_state "$P_DISK"; touch "$P_DISK/_bmad-output/pipeline-paused.flag"
  mkmarker "$P_DISK"; rm -f "$P_DISK/_bmad-output/.driver/handoff"
  r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK" "$MUT_DIR")")"
  [ "$r" = block ] && ok "  control [m24]: the key-1-armed first Stop still BLOCKS under the same mutant — it removed the sticky arming, not the keys" \
                   || bad "MUTANT TOO BROAD [m24]: the key-1 Stop stopped blocking too ($r)"
  reset_state "$P_DISK"
  mut_ctl m24 "$MUT_DIR"
fi

# M22 — the marker arm never fires. Killed by (d2) alone.
if mkmut m22-no-marker-arm "$CONF" \
     -e 's|^    \[ -f "${LOG_DIR}/.handoff-in-progress" \] && MARKER_OK=0$|    : # marker arm removed|'; then
  reset_state "$P_DISK"; mkmarker "$P_DISK"
  r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  [ "$r" = allow ] && ok "  mutant [m22] KILLED by assertion (d2): with the marker arm gone a handoff that never cleared its entry marker ends the session" \
                   || bad "MUTANT SURVIVED [m22]: expected allow, got $r — (d2) does not depend on the marker arm, so that assertion proves nothing"
  reset_state "$P_PUSHED"; rm -f "$P_PUSHED/_bmad-output/.driver/handoff"
  rr="$(reason "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  has "$rr" "$DRIVER_MARK" && ok "  control [m22]: the driver arm still BLOCKS with the step-4 text under the same mutant — the two arms are separable" \
                           || bad "MUTANT TOO BROAD [m22]: the driver case no longer blocks on step 4 either — removing the marker arm took the driver arm with it"
  mut_ctl m22 "$MUT_DIR"
fi

# M13 — apply the intent regex to the whole log LINE rather than the extracted field VALUE.
#       Killed by (g2) alone: every other seed's prose matches as a substring anywhere in the
#       line, so only the anchored bare word can see this. ALLOW-shaped kill.
if mkmut m13-line-not-value "$LIBF" -e 's|^      line=.0; sub(.*$|      line=$0; buf = buf line "\\n"|'; then
  log_prompt "$LG" "$SESS_A" "$P_BARE"
  dsetup "$LG"
  kill_stop m13 "$MUT_DIR" allow "assertion (g2): the bare-word request is now read as a non-instance"
  # AND THE SAME MUTANT ON THE PHRASE SEED, which it does NOT change. Without this the kill
  # above is equally consistent with a mutant that disabled key 3 outright.
  log_prompt "$LG" "$SESS_A" "$P_INTENT"
  dsetup "$LG"
  r="$(disk "$SESS_A" "$MUT_DIR")"
  [ "$r" = block ] && ok "  control [m13]: the phrase seed still BLOCKS under the same mutant — it broke the ANCHORED alternative specifically, not the key" \
                   || bad "MUTANT TOO BROAD [m13]: the phrase seed stopped blocking too ($r) — the mutation disabled key 3 outright and (g2)'s kill is unattributable"
  mut_ctl m13 "$MUT_DIR"
fi

# --- ai-dlc-recover.sh: the override ------------------------------------------------------
# M14 — the readability guard tests the step DIRECTORY instead of the handoff.md FILE, so the
#       override names a file that is not there. Killed by (s).
#
#       THE OBVIOUS MUTATION -- `if true` -- WAS BUILT FIRST AND REJECTED ON MEASUREMENT. That
#       guard is also the candidate SELECTOR: pinning it open makes the loop take
#       `.claude/...` unconditionally, which moves (n), (o) and (p) as well, and a mutant
#       failing four arms establishes none of them. Anchoring on `-r <file>` -> `-d <dir>`
#       keeps the selection intact and isolates the existence requirement, which is the
#       property (s) is about.
if mkmut m14-override-dir-not-file "$RECF" \
     -e 's|^      if \[ -r "${PROJECT_DIR}/${_hcand}/handoff.md" \]; then$|      if [ -d "${PROJECT_DIR}/${_hcand}" ]; then|'; then
  rsetup "$P_REC" "$SNAP_PLAIN" yes yes
  mv "$P_REC/$STEP_HANDOFF" "$P_REC/${STEP_HANDOFF}.hidden"
  kill_rec m14 "$MUT_DIR" "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
    "assertion (s): the mandate now names a handoff.md that is not on disk"
  mv "$P_REC/${STEP_HANDOFF}.hidden" "$P_REC/$STEP_HANDOFF"
  mut_ctl m14 "$MUT_DIR"
fi

# --- ai-dlc-handoff-entry.sh: the producer of key 1 ---------------------------------------
# Each of these is driven with the mutated copy and then, in the same tree, with a Read of
# steps/handoff.md that must still create the marker -- so a copy that died on load cannot
# score a kill on an absence.
ment() { # ment <name> <mutdir> <tool> <path> <want: marker|no-marker> <killmsg>
  rm -f "$P_ENTRY/_bmad-output/.handoff-in-progress"
  local rc; rc="$(edrive "$P_ENTRY" "$3" "$4" "$2")"
  local got=no-marker; marker_at "$P_ENTRY" && got=marker
  if [ "$rc" != "0" ]; then
    bad "MUTANT HARNESS BROKEN [$1]: the copy exited $rc — it is not running and the kill is unreadable"
  elif [ "$got" = "$5" ]; then
    ok "  mutant [$1] KILLED by $6"
  else
    bad "MUTANT SURVIVED [$1]: expected $5, got $got — $6 does not depend on the mutated code"
  fi
  rm -f "$P_ENTRY/_bmad-output/.handoff-in-progress"
  rc="$(edrive "$P_ENTRY" Read "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md" "$2")"
  { [ "$rc" = 0 ] && marker_at "$P_ENTRY"; } \
    && ok "  control [$1]: the same copy still marks a Read of steps/handoff.md — it loads and runs" \
    || bad "MUTANT HARNESS BROKEN [$1]: the copy no longer marks its own subject either (exit $rc)"
}
ENTF="ai-dlc-handoff-entry.sh"

# M15 — the path match loses its `steps/` segment, so any file NAMED handoff.md arms the guard.
#       Killed by (e2b). Anchored on the basename rather than widened to `*)`, which would move
#       (e2) as well and leave neither arm owning the case.
if mkmut m15-any-handoff-basename "$ENTF" -e 's|^  \*/steps/handoff.md) : ;;$|  *handoff.md) : ;;|'; then
  ment m15 "$MUT_DIR" Read "$P_ENTRY/docs/handoff.md" marker \
    "assertion (e2b): a consumer's own docs/handoff.md now arms the handoff guard"
fi

# M16 — the path match loses its BASENAME, so any step file arms the guard. Killed by (e2).
if mkmut m16-any-step-file "$ENTF" -e 's|^  \*/steps/handoff.md) : ;;$|  */steps/*) : ;;|'; then
  ment m16 "$MUT_DIR" Read "$P_ENTRY/core/skills/ai-dlc/steps/implementation.md" marker \
    "assertion (e2): reading an ordinary step file now writes the handoff marker"
fi

# M17 — drop the tool-name check, so an Edit counts as entering the procedure. Killed by (e3).
if mkmut m17-any-tool "$ENTF" -e 's@^\[ "$TOOL" = "Read" \] || exit 0$@: # tool check removed@'; then
  ment m17 "$MUT_DIR" Edit "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md" marker \
    "assertion (e3): editing the step file now writes the marker"
fi

# THE UNMUTATED CONTROL, built by the same copy-the-directory machinery as every mutant. A copy
# whose siblings did not come with it finds no predicate, fails open, and every on-disk kill
# above would then be a property of the COPY rather than of the mutation. This asserts an
# unedited copy still blocks at the Stop seam AND still routes a recovery to handoff.md.
CTLD="$ROOT/mut-control-unmutated"
rm -rf "$CTLD"; mkdir -p "$CTLD"; cp "$HOOKS_DIR"/*.sh "$CTLD"/ 2>/dev/null || true
dsetup "" yes
r="$(disk "$SESS_A" "$CTLD")"
[ "$r" = block ] && ok "  control [unmutated]: an unedited directory copy still BLOCKS the Stop on key 1 — the sibling predicate came with it" \
                 || bad "MUTANT HARNESS BROKEN: an UNEDITED copy does not block on key 1 ($r) — the copy is missing the sourced predicate and every on-disk kill above is a property of the copy"
rsetup "$P_REC" "$SNAP_PLAIN" yes yes
_cs="$(printf '%s' "$(rdrive "$P_REC" "$SESS_A" "$CTLD")" | sed -n 's/.*Your SECOND tool call MUST be `Read \([^`]*\)` in full.*/\1/p' | head -1)"
[ "$_cs" = "$STEP_HANDOFF" ] && ok "  control [unmutated]: the same copy still routes a pending recovery to handoff.md" \
                             || bad "MUTANT HARNESS BROKEN: an UNEDITED copy routes a pending recovery to '${_cs:-<nothing>}' — every recover kill above is a property of the copy"

rm -rf "$ROOT"
echo ""
[ "$fails" -eq 0 ] && { echo "handoff-completion-assertion: PASS"; exit 0; }
echo "handoff-completion-assertion: FAIL ($fails)"; exit 1
