#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# The harness block cap clamps the continue hook's EFF_MAX; an exported one moves its counts.
unset CLAUDE_CODE_STOP_HOOK_BLOCK_CAP

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
        "$sd/pipeline-snapshot.md" "$sd/.handoff-guard-armed" "$sd/.handoff-complete"
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
# THE TERSE REQUEST AS THE FINAL SENTENCE OF A LONGER MESSAGE. Producer-derived: this is the
# reference consumer's own `- Prompt (first 120 chars):` row, verbatim, from the episode filed
# as PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING. The standalone alternative
# is anchored to the whole field and cannot see it. The near-miss is a real consumer row too,
# VERBATIM and therefore carrying the operator's CURLY apostrophe: the word trails a VERB with
# no sentence boundary before it, and on the consumer's full history that shape is a question
# or a denial five times in fifteen. The curly form is not decoration -- the row travels
# through the log writer, the awk field extractor and the intent grep, and a multibyte
# character is the class of input a bracket class silently mis-reads. Straightened, the seed
# exercises none of that; `answer-handoff-routing` carries the straightened spelling, so the
# two channels seed one shape apart rather than converging on the same bytes.
P_TERSE="I'm solving this issue. handoff."
P_TERSE_NEAR="I didn’t request handoff"
# A SECOND NEAR-MISS WITH TERMINAL PUNCTUATION, because the first has none. The adversarial hand
# built a trailing-word regression that REQUIRES a terminal period and it passed every arm keyed
# on the unpunctuated denial. This is the consumer's own row (verbatim, 117 chars, so it survives
# the 120-char preview): the operator saying a handoff was NOT wanted, ending in the word and a
# period, with no sentence boundary before the word.
P_TERSE_NEAR2="continue. Note for retro that you weren't supposed to be able to pause the pipeline to ask me if I wanted to handoff."
# PLAIN NOUN MENTIONS, exclusion-clean. The declaration's description says noun mentions are
# not requests and nothing asserted it: the adversarial hand's widenings `|the hand[ -]?off|`
# and `|handoff (is|was|will)|` passed every arm. Three shapes, because one seed guards one
# shape: indefinite article and definite article are the consumer's own rows; the copula form
# has no producer instance in the consumer's history and is SYNTHETIC, said so here.
P_NOUN="why haven't we done a handoff"
P_NOUN2="did all of the handoff steps run?"
P_NOUN3="the handoff was fine yesterday"

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
{ isreq "$P_TERSE" && ! ismech "$P_TERSE"; } || \
  broken "seed premise dead: the declared vocabulary no longer reads '$P_TERSE' as a handoff REQUEST — the final-sentence alternative is gone, and (g4) would report the shipped defect PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING as a fixture failure"
! isreq "$P_TERSE_NEAR" || \
  broken "seed premise dead: '$P_TERSE_NEAR' now reads as a handoff REQUEST — the final-sentence alternative has widened into a trailing-word match, which on the reference consumer's history admits five questions or denials about a handoff"
! isreq "$P_TERSE_NEAR2" || \
  broken "seed premise dead: the punctuated denial '$P_TERSE_NEAR2' now reads as a handoff REQUEST — the final-sentence alternative has widened into a trailing-word-plus-period match, which admits an operator saying a handoff was not wanted"
! ismech "$P_TERSE_NEAR2" || \
  broken "seed premise dead: '$P_TERSE_NEAR2' now matches the mention EXCLUSION, so its near-miss would pass for the wrong reason"
for _n in "$P_NOUN" "$P_NOUN2" "$P_NOUN3"; do
  { ! isreq "$_n" && ! ismech "$_n"; } || \
    broken "seed premise dead: the plain noun mention '$_n' now scores as a request or as mechanism discussion — the declaration's own description says a noun mention is neither, and a widening that admits it is the bare-substring match the description forbids"
done
ok "seed premise: the DECLARED vocabulary scores all fourteen log-prose seeds as this fixture assumes"

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

# (g4) THE TERSE REQUEST AS THE FINAL SENTENCE OF A LONGER MESSAGE, which is what the operator
#      typed in PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING; the row is the
#      reference consumer's own, verbatim. The standalone alternative is anchored to the whole
#      field and cannot see it; the final-sentence alternative can. Driven on a copy of the
#      consumer's real log for the incident session: shipped declaration rc=1, repaired rc=0,
#      and no other session in that log moves. Killed by mutant M25, which removes that
#      alternative from a COPY of the declaration.
log_prompt "$LG" "$SESS_A" "$P_TERSE"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(g4) key 3: '$P_TERSE' -> BLOCK (a terse request trailing unrelated context is a request)" \
                 || bad "(g4) the trailing terse request was ALLOWED ($r) — the incident PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING exactly: the lead improvises the procedure and no Stop is examined"
log_prompt "$LG" "$SESS_A" "$P_TERSE_NEAR"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  near-miss: '$P_TERSE_NEAR', the word trailing a VERB with no sentence boundary before it -> ALLOW (the alternative anchors the sentence, not the word)" \
                 || bad "  a denial that merely ENDS in the word BLOCKED ($r) — the alternative has widened to any trailing 'handoff', which on the reference consumer's history admits five questions or denials"
log_prompt "$LG" "$SESS_A" "$P_TERSE_NEAR2"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  near-miss: the PUNCTUATED denial, the word after a verb and before a period -> ALLOW (the boundary is before the word, not after it)" \
                 || bad "  an operator saying a handoff was NOT wanted BLOCKED ($r) — the alternative has widened to a trailing word plus period, which admits four denials or questions on the consumer's history"
log_prompt "$LG" "$SESS_A" "$P_NOUN"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  near-miss: a plain noun mention '$P_NOUN' -> ALLOW" \
                 || bad "  a plain noun mention BLOCKED ($r) — the declaration matches the noun its own description says it does not"
# AND THROUGH THE TRANSCRIPT CHANNEL, the other reader of the same declaration at this seam.
# The same message as the LAST user turn, no resume block, no log row: a BLOCK here can only
# be Check 0's transcript arm reading the declaration. Both readers resolve one jq line, so
# the two cells must agree -- and M25 moves both, which is that single-source claim measured.
T_TERSE_NOBLK="$ROOT/t_terse_noblk.jsonl"
jq -nc --arg u "$P_TERSE" '{message:{role:"user",content:$u}}' > "$T_TERSE_NOBLK"
jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_TERSE_NOBLK"
T_NEAR_NOBLK="$ROOT/t_near_noblk.jsonl"
jq -nc --arg u "$P_TERSE_NEAR" '{message:{role:"user",content:$u}}' > "$T_NEAR_NOBLK"
jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_NEAR_NOBLK"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_TERSE_NOBLK")")"
[ "$r" = block ] && ok "  and as the transcript's last user message with no resume block -> BLOCK (the transcript reader sees the same declaration)" \
                 || bad "  the same message as the transcript's last user turn was ALLOWED ($r) — the two readers of one declaration disagree"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_NEAR_NOBLK")")"
[ "$r" = allow ] && ok "  near-miss through the transcript: the denial -> ALLOW" \
                 || bad "  the denial BLOCKED through the transcript ($r) — the transcript reader has widened where the on-disk reader has not, or both have"

# (g5) A MULTI-LINE MESSAGE IS ONE FIELD, NOT A SET OF LINES. The declared patterns anchor on
#      `^` and `$`, and grep anchors per LINE, so a message whose MIDDLE line ends in the terse
#      form -- an operator pasting the incident's own row into a question -- matched on that
#      line alone and routed the whole message. ai-dlc-pause.sh collapses newlines before it
#      writes the row key 3 reads; the transcript reader now collapses the same way. The
#      sibling BLOCK is the same message with the terse form on its LAST line, which is a
#      request whether or not it is collapsed. Killed by mutant M26.
P_PASTED="$(printf 'Look at this filing:\nRepro row: %s\nIs the fix right?' "$P_TERSE")"
P_LASTLINE="$(printf 'Everything is committed.\n%s' "$P_TERSE")"
T_PASTED_NOBLK="$ROOT/t_pasted_noblk.jsonl"
jq -nc --arg u "$P_PASTED" '{message:{role:"user",content:$u}}' > "$T_PASTED_NOBLK"
jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_PASTED_NOBLK"
T_LASTLINE_NOBLK="$ROOT/t_lastline_noblk.jsonl"
jq -nc --arg u "$P_LASTLINE" '{message:{role:"user",content:$u}}' > "$T_LASTLINE_NOBLK"
jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_LASTLINE_NOBLK"
[ "$(printf '%s' "$P_PASTED" | wc -l | tr -d ' ')" = "2" ] || broken "seed premise dead: the pasted-filing seed is not three lines, so (g5) cannot tell a per-line reader from a per-field one"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_PASTED_NOBLK")")"
[ "$r" = allow ] && ok "(g5) a three-line message whose MIDDLE line ends in the terse form -> ALLOW (the transcript is one field, not a set of lines)" \
                 || bad "(g5) a pasted filing quoting the incident row BLOCKED ($r) — the transcript reader matches per line, so any message that quotes a request on its own line arms the guard"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_LASTLINE_NOBLK")")"
[ "$r" = block ] && ok "  control: the same shape with the terse form on the LAST line -> BLOCK (collapsing did not disarm the final-sentence alternative)" \
                 || bad "  a two-line message ending in the terse request was ALLOWED ($r) — the collapse broke the final-sentence alternative, or the transcript reader is dead and (g5) is unreadable"

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
# KEY 2's LIFECYCLE — the completion stamp, at both ends
# =============================================================================
# THE SUBJECT. Key 2 reads a LINE in the snapshot, and the snapshot's writers only APPEND.
# Key 1 reads a FILE that step 5 deletes, so it is self-clearing by construction; key 2 had
# no discharge at all, and a record once written armed this guard for every later paused Stop
# of every later session. Measured on the reference consumer: one record, two days old, the
# guard firing five times across one maintenance session that owed no handoff protocol.
#
# THE ARM THAT MATTERS IS THE ARMING ONE, NOT THE DISCHARGE. A discharge that is too eager
# produces a handoff whose Stop is never examined -- the whole failure ai-dlc-continue.sh's
# Check 0 exists to catch -- so every ALLOW below is paired, in the same tree, with the case
# that must still BLOCK: no stamp (c1), a stamp OLDER than the record (c3), and a transcript
# request through the stamped tree (c2's control). The discharge changes which SNAPSHOT
# RECORDS are live, and nothing else.
#
# BOTH ENDS ARE DRIVEN, because a reader with no writer discharges nothing and a writer with
# no reader is inert, and each one alone reads exactly like a working pair. (c5) drives the
# WRITER through the Stop hook's own satisfied branch -- never by touching the file here --
# so the stamp these arms read is the one a real completion produces.
#
# THE SEED IS THE PRODUCER-DERIVED ONE, the reference consumer's own bold lead-in -- the only
# instance of this record that exists anywhere. A lifecycle asserted over the reader-derived
# heading alone would be asserted over a shape nothing has been observed writing.
HC() { printf '%s' "$1/_bmad-output/.handoff-complete"; }
SNAP_BOLD_SRC="$ROOT/snap-bold.md"
[ -r "$SNAP_BOLD_SRC" ] || broken "the producer-derived snapshot seed is missing from the sandbox; every key-2 lifecycle case below would run against a tree with no handoff record and pass for the wrong reason"
snap_at() { cp "$SNAP_BOLD_SRC" "$1/_bmad-output/pipeline-snapshot.md"; }

# (c1) THE ARMING CASE. The reference consumer's own record shape, no stamp. This is the state
#      every consumer is in before its first verified completion, and it MUST still block.
dsetup
snap_at "$P_DISK"
rm -f "$(HC "$P_DISK")"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(c1) key 2: a handoff record with NO completion stamp -> BLOCK (a real pending handoff still arms the guard)" \
                 || bad "(c1) a pending handoff record was ALLOWED ($r) — the discharge has disarmed key 2 outright, and a genuine in-flight handoff now ends its session unexamined"

# (c2) THE DISCHARGE. The same bytes on disk, one file apart: a stamp NEWER than the record.
dsetup
snap_at "$P_DISK"
sleep 1
: > "$(HC "$P_DISK")"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "(c2) the SAME record with a completion stamp newer than it -> ALLOW (the record's own completion clears the key)" \
                 || bad "(c2) a COMPLETED handoff still armed the guard ($r) — key 2 has no lifecycle, so the record arms every later paused Stop forever; this is the reference consumer's five blocks in one session"
# AND THE STAMP DISCHARGES THE KEY, NOT THE GUARD. Same stamped tree, a transcript-visible
# request: Check 0 must still block. Without this the ALLOW above is equally consistent with
# a stamp that switches Check 0 off.
dsetup
snap_at "$P_DISK"
sleep 1
: > "$(HC "$P_DISK")"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_NOBLK")")"
[ "$r" = block ] && ok "  control: the stamped tree still BLOCKS a transcript-visible request — the stamp discharges KEY 2, not Check 0" \
                 || bad "  the stamped tree allowed a transcript-visible request too ($r) — the stamp is switching the whole guard off, which is a guard that fails open"

# (c3) THE NEAR-MISS THE DISCHARGE MUST NOT COVER, and it is the exemption's own subject. A
#      LATER handoff writes a NEW record at step 3, after the previous handoff's stamp. The
#      comparison is "snapshot newer than stamp" and never the inverse: bash 3.2's `-nt` is
#      whole-second, so a compliant handoff whose step 3 and step 5 land in one second is
#      `-nt` in NEITHER direction, and the inverse form would disarm it.
dsetup
: > "$(HC "$P_DISK")"
sleep 1
snap_at "$P_DISK"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(c3) a NEW record written AFTER an old stamp -> BLOCK (the exemption does not acquit the next handoff)" \
                 || bad "(c3) the next handoff's record was acquitted by the PREVIOUS handoff's stamp ($r) — one completed handoff disarms key 2 for the rest of the consumer's life"

# (c4) KEY 1 IS UNAFFECTED BY THE STAMP. The two keys must stay separable: a lead INSIDE the
#      procedure arms the guard whatever the last handoff recorded.
dsetup "" yes
: > "$(HC "$P_DISK")"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(c4) the entry marker with a stamp present -> BLOCK (the discharge is scoped to key 2)" \
                 || bad "(c4) the entry marker stopped arming once a stamp existed ($r) — the discharge has leaked into key 1, and a lead mid-procedure is no longer caught"

# (c5) THE WRITER, DRIVEN THROUGH ITS OWN HOOK. The stamp is written on the branch where every
#      Check 0 arm was READ and found satisfied -- never by this fixture, and never on the
#      backoff branch, which allows a Stop it could not verify. Three cells: the unsatisfied
#      Stop leaves no stamp, the satisfied Stop writes one, and the NEXT Stop of that same
#      tree then allows. The third cell is the defect's own shape and it is what the writer
#      and the reader have to agree on.
dsetup
snap_at "$P_DISK"
rm -f "$(HC "$P_DISK")" "$P_DISK/_bmad-output/.driver/handoff"
r="$(disk "$SESS_A")"
_c5a=absent; [ -f "$(HC "$P_DISK")" ] && _c5a=present
[ "$r" = block ] && [ "$_c5a" = absent ] \
  && ok "(c5) an UNSATISFIED Stop blocks and writes NO stamp — an unverified handoff does not discharge its own key" \
  || bad "(c5) an unsatisfied Stop verdict=$r stamp=$_c5a — a handoff that failed its own arms is recording itself complete, and the next Stop is not examined"
sleep 1
: > "$P_DISK/_bmad-output/.driver/handoff"
rm -f "$P_DISK/_bmad-output/handoff-guard-state.txt"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK")")"
_c5b=absent; [ -f "$(HC "$P_DISK")" ] && _c5b=present
[ "$r" = allow ] && [ "$_c5b" = present ] \
  && ok "  and the SATISFIED Stop allows and writes the stamp — the completion record has a producer in the shipped machinery" \
  || bad "  the satisfied Stop verdict=$r stamp=$_c5b — key 2's discharge has no writer, so the reader above can never fire on a real tree"
rm -f "$P_DISK/_bmad-output/handoff-guard-state.txt" "$P_DISK/_bmad-output/.handoff-guard-armed"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  and the NEXT paused Stop of that same tree ALLOWS — the two halves agree, which is the whole defect" \
                 || bad "  the next Stop of the completed tree still BLOCKED ($r) — the writer's stamp is not the file the reader reads, or the comparison is the wrong way round"

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

# (o3) KEY 2's DISCHARGE THROUGH THE OTHER CALLER. The two callers pass different state dirs
#      and different session sources, and a discharge that works at the Stop seam and not here
#      leaves a compaction after a COMPLETED handoff recovering into the handoff procedure --
#      the exact drift the shared predicate exists to prevent. Paired in the same tree with
#      (o), which must still route: the discharge is one file apart from it.
rsetup "$P_REC" "$SNAP_BOLD" yes no
sleep 1
: > "$(HC "$P_REC")"
rassert "(o3) key 2 with a completion stamp newer than the record -> the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(o3) a COMPLETED handoff still routed a post-compact recovery into handoff.md — key 2's discharge does not reach ai-dlc-recover.sh, so the two callers answer one question differently"
rsetup "$P_REC" "$SNAP_BOLD" yes no
: > "$(HC "$P_REC")"
sleep 1
cp "$SNAP_BOLD" "$P_REC/_bmad-output/pipeline-snapshot.md"
rassert "  control: a record NEWER than the stamp still routes to handoff.md — the discharge is the ordering, not the file's presence" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "  a handoff record written after the previous handoff's stamp was acquitted — one completed handoff disarms the recovery override for good"

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
# (e6)-(e13) A RECOVERY-MANDATED READ IS NOT A HANDOFF INITIATION
# =============================================================================
# THE DEFECT. `ai-dlc-recover.sh` MANDATES `Read <step file>` as the second tool call after
# EVERY compaction and points that mandate at handoff.md whenever a handoff is already
# pending; `ai-dlc-recover-gate.sh` then DENIES any other call until that Read happens. So a
# session that merely compacts while paused is COMPELLED to read handoff.md -- and this hook,
# which armed on any Read of that path, wrote the entry marker on the strength of a Read the
# machinery itself forced. The marker means "this session is INSIDE the handoff procedure",
# and it is key 1: the key that arms the Stop guard and reroutes the next compaction. A
# session that never began the procedure has nothing to run step 5, so it persists.
#
# EVERY ARM HERE DRIVES THE SHIPPED HOOK SEQUENCE, AND THAT IS THE WHOLE POINT OF THE
# SECTION. The two hooks run on different events: `ai-dlc-recover-gate.sh` is PreToolUse on
# every tool, `ai-dlc-handoff-entry.sh` is PostToolUse on `Read`. On the call that satisfies
# the second mandate the real order is GATE, then the Read, then ENTRY -- and the gate DELETES
# `.recover-fired` on that call, one hook before the entry hook runs. A seed that invokes the
# entry hook alone with a hand-placed marker reports not-armed, correctly, about a sequence no
# consumer ever executes; it cannot see either of the two defects a tip adversary found here.
#
# THE ORDER IS PARSED OUT OF THE SETTINGS TEMPLATE, NEVER ASSUMED. A fixture that hard-codes
# "gate first" encodes one hand's belief about the registration, and the registration is the
# thing that decides. If the template ever registered the entry hook on PreToolUse, or the
# gate on PostToolUse, this section would be driving a sequence the consumer does not run and
# would keep printing `ok`.
echo ""

_HES_TMPL=""
for _c in "$HERE/../../../templates/settings.json.template" \
          "$HERE/../../templates/settings.json.template"; do
  [ -f "$_c" ] && { _HES_TMPL="$_c"; break; }
done
if [ -z "${_HES_TMPL:-}" ]; then
  # THE DISTRIBUTION-ONLY HALF STANDS DOWN LOUDLY. `templates/` is not installed on a
  # consumer, so this arm cannot run there -- and a stand-down that printed nothing would be
  # indistinguishable from a passing order check.
  ok "(e6-order) the settings template is absent (consumer layout); the registration order is asserted only in the distribution, and the arms below still drive gate-then-entry"

else
  # jq over the template, because the shape is nested and a grep for two filenames cannot say
  # which EVENT each sits under -- which is the only thing this arm is about.
  _HES_GATE_EV="$(jq -r '.hooks | to_entries[] | select(.value[]?.hooks[]?.command // "" | test("ai-dlc-recover-gate\\.sh")) | .key' "$_HES_TMPL" 2>/dev/null | head -1)"
  _HES_ENT_EV="$(jq -r  '.hooks | to_entries[] | select(.value[]?.hooks[]?.command // "" | test("ai-dlc-handoff-entry\\.sh")) | .key' "$_HES_TMPL" 2>/dev/null | head -1)"
  if [ "$_HES_GATE_EV" = "PreToolUse" ] && [ "$_HES_ENT_EV" = "PostToolUse" ]; then
    ok "(e6-order) the template registers the gate on PreToolUse and the entry hook on PostToolUse, so the shipped order on one Read is gate -> Read -> entry (this is what the arms below drive)"
    _HES_ORDER_OK=1
  else
    bad "(e6-order) the template registers the gate on '${_HES_GATE_EV:-<nothing>}' and the entry hook on '${_HES_ENT_EV:-<nothing>}', not PreToolUse/PostToolUse. Every arm below drives gate-then-entry on the strength of that registration; if it moved, this section is driving a sequence no consumer runs and would keep printing ok"
  fi
  # CONTROL, same invocation: a hook name the template does NOT carry must resolve to nothing,
  # or the two answers above came from a query that matches anything.
  _HES_CTL="$(jq -r '.hooks | to_entries[] | select(.value[]?.hooks[]?.command // "" | test("ai-dlc-no-such-hook-141\\.sh")) | .key' "$_HES_TMPL" 2>/dev/null | head -1)"
  [ -z "$_HES_CTL" ] \
    && ok "  control: an impossible hook name resolves to no event, so the two readings above are real" \
    || bad "  control: an impossible hook name resolved to '$_HES_CTL' — the query matches anything and the order reading establishes nothing"
fi

# `gdrive` runs the PreToolUse gate exactly as the harness does: JSON on stdin, decision on
# stdout. `seq_read` then runs the SHIPPED SEQUENCE for one Read -- gate, then entry -- and
# reports marker|no-marker. Nothing here hand-places `.recover-satisfied`: the gate writes it
# on the satisfying call and the entry hook consumes it, which is the only form of this
# assertion that can catch the two halves disagreeing about the breadcrumb.
gdrive() { # gdrive <projdir> <tool> <file-path> [hooksdir] -> raw decision JSON
  local proj="$1" tool="$2" fp="$3" hd="${4:-$HOOKS_DIR}"
  jq -nc --arg t "$tool" --arg p "$fp" '{tool_name:$t,tool_input:{file_path:$p}}' \
  | CLAUDE_PROJECT_DIR="$proj" bash "$hd/ai-dlc-recover-gate.sh" 2>/dev/null
}
gdenied() { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; }
# `reset_state` PREDATES BOTH OF THESE FILES AND DOES NOT CLEAR THEM, and that leak is not
# cosmetic: measured while building this section, a stale `.recover-gate-progress` from the
# previous case put a freshly-reset tree at the gate's SECOND mandate before any snapshot Read
# had happened, so (e8) was building a window it then asserted it could not build — and (e6)
# read a breadcrumb an earlier case had caused. Every case here differs from its neighbour in
# one file, which is only a true statement if the residue is removed.
#
# IT IS A SEPARATE HELPER RATHER THAN A CHANGE TO `reset_state`, because that function is
# called by roughly a hundred arms in this file whose subject is the Stop seam; widening it
# would change what every one of them is seeded with, and the two files are this section's.
rclean() { rm -f "$1/_bmad-output/.recover-gate-progress" "$1/_bmad-output/.recover-satisfied" \
                 "$1/_bmad-output/.recover-fired" 2>/dev/null || true; }
seq_read() { # seq_read <projdir> <read-path> [hooksdir] -> marker|no-marker
  local proj="$1" fp="$2" hd="${3:-$HOOKS_DIR}"
  rm -f "$proj/_bmad-output/.handoff-in-progress"
  gdrive "$proj" Read "$fp" "$hd" >/dev/null   # PreToolUse
  edrive "$proj" Read "$fp" "$hd" >/dev/null   # the Read happens, then PostToolUse
  if [ -f "$proj/_bmad-output/.handoff-in-progress" ]; then printf marker; else printf no-marker; fi
}
# Puts a tree into the state where the gate's SECOND mandate is outstanding: a recovery has
# fired and the snapshot Read has already been made. Built by driving the real hooks.
arm_to_step() { # arm_to_step <projdir> <session>
  rdrive "$1" "$2" >/dev/null                                   # ai-dlc-recover.sh writes .recover-fired
  local _sn; _sn="$(sed -n 's/^snapshot_path=//p' "$1/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
  [ -n "$_sn" ] && gdrive "$1" Read "$1/$_sn" >/dev/null        # satisfy mandate 1 through the gate
}

# --- (e6) THE SUPPRESSED STATE, DRIVEN AS THE CONSUMER RUNS IT ---------------------------
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC"                    # a handoff IS pending, so the mandate points at handoff.md
arm_to_step "$P_REC" "$SESS_A"
_E6_STEP="$(sed -n 's/^step_file=//p' "$P_REC/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
_E6_STAGE="$(cat "$P_REC/_bmad-output/.recover-gate-progress" 2>/dev/null || true)"
# THE PRECONDITIONS ARE ASSERTED BEFORE THE ARM. A tree whose mandate names another file, or
# whose gate is still on stage 1, is in a DIFFERENT world -- one where arming is correct -- and
# (e6) would then pass for the opposite reason to the one it claims.
case "$_E6_STEP" in
  */steps/handoff.md|steps/handoff.md) _e6_ok=1 ;;
  *) _e6_ok=0 ;;
esac
if [ "$_e6_ok" -ne 1 ]; then
  bad "(e6-pre) the recovery recorded step_file='${_E6_STEP:-<nothing>}', which does not name handoff.md — this tree is in (e8)'s world and (e6) would pass by arming correctly rather than by suppressing"
elif [ "$_E6_STAGE" != "step" ]; then
  bad "(e6-pre) after the snapshot Read the gate is at stage '${_E6_STAGE:-<none>}', not 'step'. The second mandate is not outstanding, so the Read below is not the one the recovery demands and (e6) measures nothing"
else
  ok "(e6-pre) the recovery mandates handoff.md and the gate is at its SECOND mandate — the Read below is the compelled one"
  # The gate must ALLOW this Read; if it denied, no consumer would ever reach the entry hook
  # with this input and the arm would be about an unreachable sequence.
  _E6_DEC="$(gdrive "$P_REC" Read "$P_REC/$STEP_HANDOFF")"
  if gdenied "$_E6_DEC"; then
    bad "(e6-pre) the gate DENIED the very Read it mandated, so the sequence under test is unreachable and (e6)'s verdict is about a call no consumer makes"
  else
    ok "  and the gate ALLOWS that Read, so the shipped sequence reaches the entry hook"
  fi
  # RE-ARM, AND `rclean` IS WHAT MAKES THE RE-ARM REAL. The gate probe above satisfied the
  # second mandate, so it WROTE a breadcrumb; `reset_state` predates that file and does not
  # remove it. Left in place, `mkmarker`'s own Read consumes it and is suppressed, key 1 is
  # never created, the recovery then mandates the INTERRUPTED step instead of handoff.md, and
  # the sequence below arms — reported as (e6) failing, which is a true statement about a
  # world the fixture built wrong rather than about the hook. Measured exactly that way.
  reset_state "$P_REC"; rclean "$P_REC"
  cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
  touch "$P_REC/_bmad-output/pipeline-paused.flag"
  mkmarker "$P_REC"; arm_to_step "$P_REC" "$SESS_A"
  if [ "$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")" = no-marker ]; then
    ok "(e6) driven in SHIPPED ORDER (gate -> Read -> entry), a recovery-mandated Read does NOT write the entry marker"
  else
    bad "(e6) a recovery-mandated Read wrote the entry marker when the two hooks are driven in shipped order. The gate deletes .recover-fired on this very call, one hook before the entry hook runs, so a suppression keyed on that marker is UNREACHABLE on a consumer — it tests a file that is already gone"
  fi
fi

# --- (e7) THE SEED THAT SEPARATES A CORRECT FIX FROM A BROKEN ONE -------------------------
# No recovery at all: a lead opening the procedure of their own accord, where the marker is
# REQUIRED. A fix keyed on anything other than the satisfying call agrees with the correct one
# on (e6) and diverges only here.
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
if [ "$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")" = marker ]; then
  ok "(e7) with NO recovery in flight the same sequence DOES write the marker — a genuine initiation still arms"
else
  bad "(e7) a genuine handoff initiation no longer writes the marker. The suppression has swallowed the mandate rather than one distinguishable state, and the routing this hook exists to provide is gone: a compaction now sends the successor to the interrupted step instead of to the procedure"
fi

# --- (e8) A RECOVERY IN FLIGHT THAT HAS NOT REACHED ITS SECOND MANDATE --------------------
# THE SECOND DEFECT THE BREADCRUMB EXISTS FOR, and no arm above can see it. A lead that has
# satisfied only the FIRST mandated Read and then opens handoff.md of its own accord is a
# GENUINE INITIATION with `.recover-fired` still on disk. A suppression keyed on the marker's
# existence silences it and loses the routing; one keyed on the SATISFYING CALL does not,
# because no breadcrumb has been written yet.
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC"
rdrive "$P_REC" "$SESS_A" >/dev/null     # a recovery fires; mandate 1 is NOT satisfied
_E8_STAGE="$(cat "$P_REC/_bmad-output/.recover-gate-progress" 2>/dev/null || printf 'snapshot')"
if [ -f "$P_REC/_bmad-output/.recover-fired" ] && [ "$_E8_STAGE" != step ]; then
  ok "(e8-pre) a recovery is in flight and the gate is still at its FIRST mandate — the marker exists, no satisfying call has happened"
  if [ "$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")" = marker ]; then
    ok "(e8) a voluntary open during that window still ARMS — the key is the satisfying call, not the marker's existence"
  else
    bad "(e8) a lead opening handoff.md while a recovery was in flight but UNSATISFIED was suppressed. That Read was compelled by nothing, so the suppression is keyed on 'a recovery exists' rather than on 'this Read is the one it demanded' — and losing the routing is the worse direction by this hook's own reasoning"
  fi
else
  bad "(e8-pre) could not build the in-flight-but-unsatisfied window (marker present? stage='$_E8_STAGE'), so (e8) would assert against a state that is not the one it names"
fi

# --- (e9) FAIL OPEN: a breadcrumb with no step_file key ----------------------------------
# Every unreadable or ambiguous input falls through and arms. The two errors are not
# symmetric: a marker written wrongly is a Stop guard the lead clears with `rm`, a marker
# MISSED while the lead really is mid-handoff loses the routing. WRITTEN DIRECTLY, because
# the gate cannot be driven into emitting a keyless breadcrumb -- it writes the key or nothing.
reset_state "$P_REC"
printf 'satisfied_at=2026-09-21T00:00:00Z\n' > "$P_REC/_bmad-output/.recover-satisfied"
if [ "$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")" = marker ]; then
  ok "(e9) a breadcrumb carrying no step_file key FAILS OPEN to arming"
else
  bad "(e9) an ambiguous breadcrumb suppressed the arming. A marker written wrongly is cleared with rm; a marker missed loses the routing this hook exists to provide, so every unreadable input must arm"
fi

# --- (e10) THE BREADCRUMB IS ONE-SHOT ----------------------------------------------------
# It describes ONE call. Left on disk it would answer for a LATER Read of the same file, so a
# voluntary re-open moments after the mandated one would be read as the mandated one and
# silently fail to arm. The consumer deletes it as it reads it; this asserts that directly by
# running the sequence TWICE against a single breadcrumb.
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC"; arm_to_step "$P_REC" "$SESS_A"
_E10_FIRST="$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")"
_E10_SECOND="$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")"
if [ "$_E10_FIRST" = no-marker ] && [ "$_E10_SECOND" = marker ]; then
  ok "(e10) the breadcrumb is CONSUMED: the mandated Read is suppressed and an immediate re-open of the same file arms"
else
  bad "(e10) the two Reads scored '$_E10_FIRST' then '$_E10_SECOND', expected no-marker then marker. A breadcrumb left on disk answers for a later call, so a voluntary re-open right after the mandated one is read as the mandated one and silently fails to arm"
fi

# --- (e11) CONTROL FOR (e6): the SAME state, a DIFFERENT file read ------------------------
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC"; arm_to_step "$P_REC" "$SESS_A"
if [ "$(seq_read "$P_REC" "$P_REC/$STEP_IMPL")" = no-marker ]; then
  ok "(e11) control: in (e6)'s exact state, a Read of a DIFFERENT step file is also unmarked"
else
  bad "(e11) reading an ordinary step file in the suppressed state wrote the marker — the path match and the suppression are interacting, and (e6)'s silence cannot be attributed to either"
fi

# --- (e12) BOTH LAYOUTS ------------------------------------------------------------------
# The comparison is on the BASENAME UNDER ITS steps/ PARENT because the gate records a
# project-relative path while the Read may arrive absolute; a whole-path compare fails to
# suppress in exactly the layouts this hook spans. Driven on the CONSUMER tree, whose step
# files live under `.claude/`, with the breadcrumb written by the gate itself.
reset_state "$P_REC_CLAUDE"; rclean "$P_REC_CLAUDE"
cp "$SNAP_PLAIN" "$P_REC_CLAUDE/_bmad-output/pipeline-snapshot.md"
touch "$P_REC_CLAUDE/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC_CLAUDE"; arm_to_step "$P_REC_CLAUDE" "$SESS_A"
_E12_STEP="$(sed -n 's/^step_file=//p' "$P_REC_CLAUDE/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
case "$_E12_STEP" in
  .claude/*)
    ok "(e12-pre) on the consumer tree the gate records a .claude/-spelled mandate ($_E12_STEP)"
    if [ "$(seq_read "$P_REC_CLAUDE" "$P_REC_CLAUDE/$STEP_HANDOFF_C")" = no-marker ]; then
      ok "(e12) the suppression holds in the INSTALLED layout, which is the only layout this hook runs in"
    else
      bad "(e12) the consumer layout did not suppress. The hook is comparing whole paths or is anchored on the distribution spelling, so on every installed tree a compaction still arms the Stop guard over a procedure that was never begun"
    fi
    ;;
  *)
    bad "(e12-pre) the consumer tree recorded step_file='${_E12_STEP:-<nothing>}', which is not consumer-spelled — the layout arm would assert about the distribution spelling twice"
    ;;
esac
# POSITIVE CONTROL for (e12): the same tree with no breadcrumb must still arm, or (e12) is a
# dead hook rather than a suppression.
reset_state "$P_REC_CLAUDE"; rclean "$P_REC_CLAUDE"
cp "$SNAP_PLAIN" "$P_REC_CLAUDE/_bmad-output/pipeline-snapshot.md"
touch "$P_REC_CLAUDE/_bmad-output/pipeline-paused.flag"
if [ "$(seq_read "$P_REC_CLAUDE" "$P_REC_CLAUDE/$STEP_HANDOFF_C")" = marker ]; then
  ok "  control: the same consumer tree with no breadcrumb DOES arm"
else
  bad "  the entry hook does not arm in the consumer tree even with no breadcrumb — (e12) is a dead hook, not a suppression"
fi

# --- (e13) THE BREADCRUMB IS PARSED AS KEY=VALUE, NEVER SOURCED --------------------------
# `.` on a file under the project directory executes whatever a consumer's tree put there,
# and this hook runs on EVERY Read. Seeded with a value that is a command substitution:
# sourcing it creates the canary, parsing it does not.
CANARY="$P_ENTRY/_bmad-output/.sourced-canary"
rm -f "$CANARY" "$P_ENTRY/_bmad-output/.handoff-in-progress"
printf 'step_file=$(touch %s)\n' "$CANARY" > "$P_ENTRY/_bmad-output/.recover-satisfied"
edrive "$P_ENTRY" Read "$P_ENTRY/$STEP_HANDOFF" >/dev/null
if [ -f "$CANARY" ]; then
  bad "(e13) the hook SOURCED .recover-satisfied — a file under the project directory, whose content a consumer's tree supplies, was executed as shell by a PostToolUse hook that runs on every Read"
else
  ok "(e13) the breadcrumb is parsed as key=value, never sourced (a command-substitution payload did not execute)"
fi
rm -f "$P_ENTRY/_bmad-output/.recover-satisfied" "$CANARY" "$P_ENTRY/_bmad-output/.handoff-in-progress"

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
     -e 's|^        if \[ "$PUSH_OK" != "1" \] && \[ "$TEAMMATES_OK" = "1" \] && \[ "$INFLIGHT_OK" = "1" \] \\$|        if false \\|' \
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

# M9c — KEY 2 LOSES ITS DISCHARGE, which is the shipped predicate before this release: the
#       record arms the key on presence alone and nothing ever clears it. Killed by (c2) and
#       by nothing else -- every other key-2 seed in this file carries no stamp, so only the
#       stamped tree can see the conjunct. ALLOW-shaped kill, so the control asserts the
#       UNSTAMPED record still blocks under the same mutant: the mutation removed the
#       discharge, it did not disable key 2.
#
# THE SED DELIMITER IS `@`, for the reason M9's header states: a `|` here reads to I54b as a
# pipeline feeding a reader.
if mkmut m9c-key2-no-discharge "$LIBF" \
     -e 's@^     && { \[ ! -f "${_sd}/.handoff-complete" \] \\$@     \&\& { true \\@'; then
  dsetup
  snap_at "$P_DISK"
  sleep 1
  : > "$(HC "$P_DISK")"
  r="$(disk "$SESS_A" "$MUT_DIR")"
  [ "$r" = block ] && ok "  mutant [m9c] KILLED by assertion (c2): with the discharge gone a COMPLETED handoff arms the guard again, permanently" \
                   || bad "MUTANT SURVIVED [m9c]: expected block, got $r — (c2) does not depend on the discharge conjunct, so that assertion proves nothing"
  dsetup
  snap_at "$P_DISK"
  rm -f "$(HC "$P_DISK")"
  r="$(disk "$SESS_A" "$MUT_DIR")"
  [ "$r" = block ] && ok "  control [m9c]: the UNSTAMPED record still BLOCKS under the same mutant — it removed the discharge, not key 2" \
                   || bad "MUTANT TOO BROAD [m9c]: the unstamped record stopped blocking too ($r) — the mutation disabled key 2 outright and (c2)'s kill is unattributable"
  mut_ctl m9c "$MUT_DIR"
fi

# M9d — THE COMPARISON INVERTED, stamp-newer-than-snapshot rather than snapshot-newer-than-
#       stamp. This is the plausible spelling and it is wrong in the direction that matters:
#       it acquits the NEXT handoff's record on the PREVIOUS handoff's stamp. Killed by (c3)
#       alone -- (c2)'s tree has the stamp newer, where both spellings agree, so only the
#       ordering (c3) seeds can separate them. ALLOW-shaped kill; the control is (c2)'s tree,
#       which must still ALLOW, proving the mutation inverted the test rather than deleting it.
if mkmut m9d-discharge-inverted "$LIBF" \
     -e 's@|| \[ "${_sd}/pipeline-snapshot.md" -nt "${_sd}/.handoff-complete" \]; }; then@|| [ "${_sd}/.handoff-complete" -nt "${_sd}/pipeline-snapshot.md" ]; }; then@'; then
  dsetup
  : > "$(HC "$P_DISK")"
  sleep 1
  snap_at "$P_DISK"
  r="$(disk "$SESS_A" "$MUT_DIR")"
  [ "$r" = allow ] && ok "  mutant [m9d] KILLED by assertion (c3): inverted, one completed handoff's stamp acquits every record written after it" \
                   || bad "MUTANT SURVIVED [m9d]: expected allow, got $r — (c3) does not depend on the comparison's direction, so that assertion proves nothing"
  dsetup
  snap_at "$P_DISK"
  rm -f "$(HC "$P_DISK")"
  r="$(disk "$SESS_A" "$MUT_DIR")"
  [ "$r" = block ] && ok "  control [m9d]: the UNSTAMPED record still BLOCKS under the same mutant — it inverted the comparison, it did not delete the key" \
                   || bad "MUTANT TOO BROAD [m9d]: the unstamped record stopped blocking too ($r) — (c3)'s kill is unattributable"
  mut_ctl m9d "$MUT_DIR"
fi

# M9e — THE WRITER NEVER WRITES. The reader is intact and the stamp is never produced, which
#       is a reader with no writer: inert on every real tree and green against every seed this
#       fixture writes by hand. Killed by (c5)'s second and third cells, which drive the Stop
#       hook's own satisfied branch. The control is (c1), which must still block: the mutation
#       removed the producer, not the guard.
if mkmut m9e-no-stamp-writer "$CONF" \
     -e 's@^      : > "${LOG_DIR}/.handoff-complete" 2>/dev/null || true$@      : # stamp writer removed@'; then
  dsetup
  snap_at "$P_DISK"
  rm -f "$(HC "$P_DISK")" "$P_DISK/_bmad-output/.driver/handoff"
  drive "$P_DISK" "$SESS_A" "$T_REQ_OK" "$MUT_DIR" >/dev/null
  sleep 1
  : > "$P_DISK/_bmad-output/.driver/handoff"
  rm -f "$P_DISK/_bmad-output/handoff-guard-state.txt"
  r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK" "$MUT_DIR")")"
  _st=absent; [ -f "$(HC "$P_DISK")" ] && _st=present
  { [ "$r" = allow ] && [ "$_st" = absent ]; } \
    && ok "  mutant [m9e] KILLED by assertion (c5): the satisfied Stop allows and leaves NO stamp — key 2's reader has no producer and can never fire" \
    || bad "MUTANT SURVIVED [m9e]: satisfied Stop verdict=$r stamp=$_st — (c5) does not read the writer, so that assertion proves nothing"
  dsetup
  snap_at "$P_DISK"
  rm -f "$(HC "$P_DISK")"
  r="$(disk "$SESS_A" "$MUT_DIR")"
  [ "$r" = block ] && ok "  control [m9e]: the pending record still BLOCKS under the same mutant — it removed the writer, not the guard" \
                   || bad "MUTANT TOO BROAD [m9e]: the pending record stopped blocking too ($r) — the mutation reached Check 0 itself"
  mut_ctl m9e "$MUT_DIR"
fi

# M9f — THE STAMP MOVES TO THE BACKOFF BRANCH, where the guard ALLOWS a Stop it could not
#       verify. That discharges key 2 on exactly the handoffs that failed their own arms, and
#       it reads as a working writer on every tree where the handoff succeeded. Killed by
#       (c5)'s first cell, which is the only seed whose Stop is unsatisfied. Control: the
#       satisfied branch must still stamp, so the mutation MOVED the writer rather than
#       deleting it -- which is what separates this mutant from m9e.
if mkmut m9f-stamp-on-backoff "$CONF" \
     -e 's@^      rm -f "$HANDOFF_STATE" "$HANDOFF_ARMED_FILE"   # backoff exhausted@      : > "${LOG_DIR}/.handoff-complete" 2>/dev/null || true; rm -f "$HANDOFF_STATE" "$HANDOFF_ARMED_FILE"   # backoff exhausted@'; then
  dsetup
  snap_at "$P_DISK"
  rm -f "$(HC "$P_DISK")" "$P_DISK/_bmad-output/.driver/handoff"
  # MAX_RAPID_BLOCKS consecutive blocks inside the rapid window, so the backoff releases.
  #
  # `drive` CANNOT REACH THIS BRANCH AND THAT IS DELIBERATE ON ITS PART: it clears
  # handoff-guard-state.txt before every call, because a tree driven four times by the ordinary
  # cases would start ALLOWING and read exactly like an arm standing down. Here the counter IS
  # the subject, so this one mutant drives the hook raw. Without the raw form the mutant
  # survives against a correct fixture -- measured -- which reads as an arm that cannot fire.
  _i=0
  while [ "$_i" -lt 5 ]; do
    jq -nc --arg t "$T_REQ_OK" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' \
    | CLAUDE_PROJECT_DIR="$P_DISK" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" \
      bash "$MUT_DIR/ai-dlc-continue.sh" >/dev/null 2>&1
    _i=$((_i + 1))
  done
  _st=absent; [ -f "$(HC "$P_DISK")" ] && _st=present
  [ "$_st" = present ] && ok "  mutant [m9f] KILLED by assertion (c5): the BACKOFF branch now stamps, so a handoff that failed every arm records itself complete" \
                       || bad "MUTANT SURVIVED [m9f]: the backoff branch left no stamp — (c5)'s unsatisfied cell does not read the writer's siting, so that assertion proves nothing"
  dsetup
  snap_at "$P_DISK"
  rm -f "$(HC "$P_DISK")"
  sleep 1
  : > "$P_DISK/_bmad-output/.driver/handoff"
  drive "$P_DISK" "$SESS_A" "$T_REQ_OK" "$MUT_DIR" >/dev/null
  _st=absent; [ -f "$(HC "$P_DISK")" ] && _st=present
  [ "$_st" = present ] && ok "  control [m9f]: the SATISFIED branch still stamps under the same mutant — the writer was moved, not duplicated away" \
                       || bad "MUTANT TOO BROAD [m9f]: the satisfied branch stopped stamping too — the mutation removed the writer and the kill above is m9e's, not this one's"
  mut_ctl m9f "$MUT_DIR"
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

# M25 — THE REGRESSION MUTANT FOR PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING.
#       The subject is the DECLARATION, not a hook: remove the final-sentence alternative from a
#       COPY of pause-routing.json and drive the unmodified hooks against it. `rtrimstr` is a
#       literal strip, so the copy is byte-identical to the original -- and `cmp -s` refuses the
#       mutant -- the day that alternative stops being the LAST one in the pattern; that is a
#       lost subject and the repair is re-anchoring, never a relaxed assertion. Killed by (g4)'s
#       on-disk arm; the transcript arm moves with it BY CONSTRUCTION, because both readers
#       resolve the same jq line (I94), and that second cell is asserted rather than left to be
#       read as entanglement. Control: the VERB-PHRASE seed still BLOCKS under the same copy, so
#       the mutation removed one alternative and not key 3. The bare word cannot be the control:
#       the final-sentence alternative's start-of-field branch is what carries it now (the old
#       whole-field alternative was subsumed and removed), so under this copy the bare word is
#       a non-instance and a bare-word control would misreport the mutation as a total disarm.
ALT_TERSE='(^|[.!?][[:space:]]*)[[:space:]]*hand[ -]?off[[:space:]]*[.!]?[[:space:]]*$'
MUT_SCHEMA="$ROOT/mut-m25-pause-routing.json"
jq --arg alt "|$ALT_TERSE" '.handoff_intent_pattern |= rtrimstr($alt)' "$SCHEMA" > "$MUT_SCHEMA" 2>/dev/null
_m25_re="$(jq -rj '.handoff_intent_pattern // ""' "$MUT_SCHEMA" 2>/dev/null)"
if [ -z "$_m25_re" ]; then
  bad "MUTANT HARNESS BROKEN [m25]: the declaration copy did not parse or carries no pattern — the kill below is unreadable"
elif cmp -s "$SCHEMA" "$MUT_SCHEMA"; then
  bad "FIXTURE STALE: mutation m25 matched nothing — handoff_intent_pattern no longer ENDS with the byte-exact alternative ALT_TERSE names (it was respelled, moved, or followed by another alternative). This is a byte-lock on the shipped spelling, not a claim that the fix is wrong: re-anchor ALT_TERSE on the declaration as shipped and re-run the seed-premise arms, never relax this assertion"
else
  ok "  mutant [m25] built: the declaration copy differs from the shipped one and still parses"
  log_prompt "$LG" "$SESS_A" "$P_TERSE"
  dsetup "$LG"
  _m25_saved="$SCHEMA"; SCHEMA="$MUT_SCHEMA"
  r="$(disk "$SESS_A")"
  SCHEMA="$_m25_saved"
  [ "$r" = allow ] && ok "  mutant [m25] KILLED by assertion (g4): with the final-sentence alternative gone the trailing terse request is a non-instance again" \
                   || bad "MUTANT SURVIVED [m25]: expected allow, got $r — (g4) does not depend on the final-sentence alternative, so that assertion proves nothing"
  dsetup
  SCHEMA="$MUT_SCHEMA"
  r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_TERSE_NOBLK")")"
  SCHEMA="$_m25_saved"
  [ "$r" = allow ] && ok "  and the transcript reader moves with it (ALLOW) — one declaration, two readers, one mutation" \
                   || bad "MUTANT SURVIVED [m25] on the transcript reader: expected allow, got $r — the transcript arm is matching on something other than the declaration"
  # THE SAME COPY ON THE VERB-PHRASE SEED, which it does NOT change. Without this the kills
  # above are equally consistent with a copy that disabled key 3 or the vocabulary outright.
  log_prompt "$LG" "$SESS_A" "$P_INTENT"
  dsetup "$LG"
  SCHEMA="$MUT_SCHEMA"
  r="$(disk "$SESS_A")"
  SCHEMA="$_m25_saved"
  [ "$r" = block ] && ok "  control [m25]: the verb phrase '$P_INTENT' still BLOCKS under the same copy — it removed one alternative, not key 3" \
                   || bad "MUTANT TOO BROAD [m25]: the verb phrase stopped blocking too ($r) — the copy disabled the vocabulary outright and (g4)'s kill is unattributable"
  # AND THE BARE WORD IS A NON-INSTANCE UNDER THIS COPY, BY CONSTRUCTION: its only carrier is
  # the start-of-field branch of the alternative the copy strips. Asserted so that a later
  # reinstatement of a separate whole-field alternative is noticed here rather than silently
  # doubling the grammar.
  log_prompt "$LG" "$SESS_A" "$P_BARE"
  dsetup "$LG"
  SCHEMA="$MUT_SCHEMA"
  r="$(disk "$SESS_A")"
  SCHEMA="$_m25_saved"
  [ "$r" = allow ] && ok "  and the bare word is ALLOWED under the copy — the final-sentence alternative is the bare word's only carrier, so the two forms are one alternative" \
                   || bad "  the bare word still BLOCKED under the copy ($r) — a second whole-field alternative has been reinstated beside the final-sentence one, and the grammar now spells the terse form twice"
  # AND THE SAME COPY THROUGH THE TRANSCRIPT CHANNEL. The control above drives KEY 3 and is
  # blind to the other reader, while the transcript kill is ALLOW-shaped -- so a hook whose
  # transcript arm is dead satisfies that cell and the fixture prints "one declaration, two
  # readers" over a single reader. MEASURED: with the transcript arm's intent grep replaced by
  # `false` in a copy of ai-dlc-continue.sh, the on-disk control still passed and the
  # transcript cell still scored a kill. This arm is PRESENCE-shaped in that channel, on the
  # verb phrase the mutation does not touch, so the ALLOW above can only be the mutation.
  T_PHRASE_NOBLK="$ROOT/t_phrase_noblk.jsonl"
  jq -nc --arg u "$P_INTENT" '{message:{role:"user",content:$u}}' > "$T_PHRASE_NOBLK"
  jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_PHRASE_NOBLK"
  dsetup
  SCHEMA="$MUT_SCHEMA"
  r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_PHRASE_NOBLK")")"
  SCHEMA="$_m25_saved"
  [ "$r" = block ] && ok "  control [m25] through the TRANSCRIPT: the verb phrase as the last user turn still BLOCKS under the same copy — that reader is alive, so its ALLOW above is the mutation and not a dead channel" \
                   || bad "MUTANT HARNESS BROKEN [m25]: the transcript reader did not block the verb phrase either ($r) — it is not reading, and the transcript kill above is unreadable"
fi

# M26 — the transcript reader matches PER LINE again: strip the newline collapse from
#       LAST_USER in a copy of ai-dlc-continue.sh. Killed by (g5): the pasted filing whose
#       middle line ends in the terse form BLOCKS under the copy. Control: (g5)'s last-line
#       sibling still BLOCKS, so the copy reads the transcript and the kill is the anchor's.
if mkmut m26-per-line-transcript "$CONF" -e "s/; } | tr '\\\\n' ' ')\$/; })/"; then
  dsetup
  r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_PASTED_NOBLK" "$MUT_DIR")")"
  [ "$r" = block ] && ok "  mutant [m26] KILLED by assertion (g5): with the collapse gone the middle line matches on its own and the pasted filing BLOCKS" \
                   || bad "MUTANT SURVIVED [m26]: expected block, got $r — (g5) does not depend on the newline collapse, so that assertion proves nothing"
  dsetup
  r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_LASTLINE_NOBLK" "$MUT_DIR")")"
  [ "$r" = block ] && ok "  control [m26]: the last-line request still BLOCKS under the same copy — the copy runs and reads the transcript" \
                   || bad "MUTANT HARNESS BROKEN [m26]: the last-line request stopped blocking ($r) — the copy is not reading the transcript, and the kill above is unreadable"
  mut_ctl m26 "$MUT_DIR"
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

# --- THE RECOVERY SUPPRESSION (e6)-(e13) --------------------------------------------------
#
# EVERY ARM IN THAT SECTION EXCEPT (e7)-(e9) IS ABSENCE-SHAPED, and an absence-shaped arm is
# the one that REQUIRES a mutant: the seeded pairs establish that the arms discriminate
# between two inputs, and only a mutant establishes that they discriminate AT ALL.
#
# EACH MUTANT IS DRIVEN THROUGH THE SHIPPED SEQUENCE, not through the entry hook alone. Two
# of these four (m28, m29) key on state the GATE writes, so a battery that drove only the
# PostToolUse half would score them against a breadcrumb the fixture had placed itself -- the
# seed shape that made the pre-fix defect invisible to seven seeds.
#
# `mseq` runs gate-then-entry against the mutant's hooks directory and follows every verdict
# with a PRESENCE-shaped control in the same tree: a copy that died on load, or one that
# simply stopped writing markers, produces the identical absence and would score every
# no-marker expectation for free.
mseq() { # mseq <name> <mutdir> <projdir> <read-path> <want> <killmsg>
  local got
  got="$(seq_read "$3" "$4" "$2")"
  if [ "$got" = "$5" ]; then
    ok "  mutant [$1] KILLED by $6"
  else
    bad "MUTANT SURVIVED [$1]: expected $5, got $got — $6 does not depend on the mutated code"
  fi
  # The control: same copy, same tree, NO recovery state at all, which must arm.
  #
  # `rclean` IS LOAD-BEARING HERE AND m30 IS WHY. That mutant's whole defect is that it does
  # NOT consume the breadcrumb, so the file its own verdict was scored against is still on
  # disk when the control runs — and the control then reads a suppressed state and reports
  # MUTANT HARNESS BROKEN over a mutant that had just been killed correctly. A control that
  # inherits the residue of the case it is controlling for is not a control.
  reset_state "$3"; rclean "$3"
  cp "$SNAP_PLAIN" "$3/_bmad-output/pipeline-snapshot.md"
  touch "$3/_bmad-output/pipeline-paused.flag"
  [ "$(seq_read "$3" "$3/$STEP_HANDOFF" "$2")" = marker ] \
    && ok "  control [$1]: the same copy still marks an unsuppressed Read — it loads and runs" \
    || bad "MUTANT HARNESS BROKEN [$1]: the copy marks nothing at all; the verdict above is a property of the copy rather than of the mutation"
}
# Rebuilds the suppressed world (recovery in flight, gate at its SECOND mandate) using the
# MUTANT's hooks, so a mutation to the gate's breadcrumb write is exercised where it lives.
mseq_arm() { # mseq_arm <projdir> <mutdir>
  reset_state "$1"
  cp "$SNAP_PLAIN" "$1/_bmad-output/pipeline-snapshot.md"
  touch "$1/_bmad-output/pipeline-paused.flag"
  mkmarker "$1" "$2"
  rdrive "$1" "$SESS_A" "$2" >/dev/null
  local _sn; _sn="$(sed -n 's/^snapshot_path=//p' "$1/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
  [ -n "$_sn" ] && gdrive "$1" Read "$1/$_sn" "$2" >/dev/null
  return 0
}
GATEF="ai-dlc-recover-gate.sh"

# M27 — THE SUPPRESSION IS REMOVED, which is the pre-fix hook. Killed by (e6): a
#       recovery-mandated Read arms again. ANCHORED ON THE `case` ARM'S EXIT, because that
#       exit IS the suppression and it survives any rewording of the breadcrumb's name.
if mkmut m27-no-recovery-suppression "$ENTF" -e 's@^        exit 0 ;;$@        : ;;@'; then
  _M27="$MUT_DIR"; mseq_arm "$P_REC" "$_M27"
  mseq m27 "$_M27" "$P_REC" "$P_REC/$STEP_HANDOFF" marker \
    "assertion (e6): with the suppression gone a Read the recovery COMPELLED writes the entry marker again, so a session that merely compacted while paused arms the Stop guard over a procedure it never began"
fi

# M28 — THE KEY GOES BACK TO `.recover-fired`, WHICH IS THE FIRST CUT'S DEFECT IN FULL and
#       the one no single-hook seed can see. The gate DELETES that marker on the satisfying
#       call, one hook BEFORE this hook runs, so the test falls through and the marker is
#       written from a compelled Read. Killed by (e6) — and only when the sequence is driven
#       in shipped order, which is what makes this mutant the receipt for `seq_read`.
if mkmut m28-key-on-the-deleted-marker "$ENTF" \
     -e 's@^_RS="${STATE_DIR}/\.recover-satisfied"$@_RS="${STATE_DIR}/.recover-fired"@'; then
  _M28="$MUT_DIR"; mseq_arm "$P_REC" "$_M28"
  mseq m28 "$_M28" "$P_REC" "$P_REC/$STEP_HANDOFF" marker \
    "assertion (e6): keyed on .recover-fired the suppression is UNREACHABLE — the gate removed that file one PreToolUse earlier, so on a real consumer the test reads a file that is already gone"
fi

# M29 — THE GATE STOPS WRITING THE BREADCRUMB. The entry hook is untouched; the state it
#       needs is simply never handed forward. Killed by (e6), and it is the arm proving the
#       two hooks are joined rather than each correct in isolation. MUTATES THE GATE, which
#       is why `mseq_arm` rebuilds the world with the mutant's own hooks.
if mkmut m29-gate-writes-no-breadcrumb "$GATEF" \
     -e 's@^        printf .step_file=%s\\n. "\$STEP_REL" > "\${STATE_DIR}/\.recover-satisfied" 2>/dev/null || true$@        : # breadcrumb not written@'; then
  _M29="$MUT_DIR"; mseq_arm "$P_REC" "$_M29"
  mseq m29 "$_M29" "$P_REC" "$P_REC/$STEP_HANDOFF" marker \
    "assertion (e6): with the gate no longer handing the satisfying call forward, the entry hook has nothing to decide from and arms on a compelled Read"
fi

# M30 — THE BREADCRUMB IS NOT CONSUMED. It stays on disk and answers for a LATER Read of the
#       same file, so a voluntary re-open moments after the mandated one is read as the
#       mandated one and silently fails to arm. Killed by (e10)'s second half, which is the
#       only arm that reads the file twice.
if mkmut m30-breadcrumb-not-consumed "$ENTF" \
     -e 's@^  rm -f "\$_RS" 2>/dev/null || true$@  : # breadcrumb left on disk@'; then
  _M30="$MUT_DIR"; mseq_arm "$P_REC" "$_M30"
  seq_read "$P_REC" "$P_REC/$STEP_HANDOFF" "$_M30" >/dev/null   # the mandated Read
  mseq m30 "$_M30" "$P_REC" "$P_REC/$STEP_HANDOFF" no-marker \
    "assertion (e10): the breadcrumb survives its own read, so an immediate voluntary re-open is taken for the mandated call and the lead's real initiation is silently unmarked"
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
