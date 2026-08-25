#!/usr/bin/env bash
# answer-handoff-routing — assert that a handoff request arriving as an AskUserQuestion
# ANSWER is routed, and that nothing else is.
#
# THE DEFECT THIS FIXTURE EXISTS FOR. At 01:25 the lead asked an AskUserQuestion about a
# gate-3 disposition. At 01:35 the operator answered "handoff". The lead read the intent
# correctly and then improvised -- one TaskStop, a snapshot edit, a touched pause flag --
# without ever loading steps/handoff.md, and confirmed afterwards: "no full teammate sweep,
# no commit, no push attempt, no bare resume line."
#
# The root cause is structural, not a lapse. `ai-dlc-pause.sh` was the only thing in the
# system that routes a handoff request, and it fires on UserPromptSubmit. An AskUserQuestion
# answer NEVER raises that event -- `ai-dlc-answer-capture.sh`'s own header says so -- and
# that hook recorded the answer without routing it. The continuation log carries no
# USER_PAUSE across the whole episode.
#
# ASSERTION 5 IS THE LOAD-BEARING ONE. Routing on an answer is easy to do too widely, and
# the failure direction there is a pipeline that pauses on every AskUserQuestion the lead
# ever asks. Assertion 5 is the one that would catch it.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook. A fixture that INHERITS
# ambient config tests the config, not the code, and the pre-push gate inherits every
# AI_DLC_* tunable a consumer set in settings.json. Unset ALL of them by pattern so a NEW
# tunable cannot reintroduce it; per-command assignments below still work, and those are the
# deliberate tests.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] \
  && { printf '%s/%s' "$(cd "$(dirname "$c")" && pwd)" "$(basename "$c")"; return; }; done; }

# Both install layouts. `../../hooks/` is the distribution (core/fixtures/<x>/ ->
# core/hooks/); `../../../.claude/hooks/` is the consumer (tests/fixtures/<x>/ ->
# .claude/hooks/). Canonicalised by pick(), so the mutant battery below can print a path a
# human can compare against the file they changed.
HOOK="$(pick "$HERE/../../hooks/ai-dlc-answer-capture.sh" \
             "$HERE/../../../.claude/hooks/ai-dlc-answer-capture.sh" \
             "$HERE/../../../core/hooks/ai-dlc-answer-capture.sh")"
PAUSE_HOOK="$(pick "$HERE/../../hooks/ai-dlc-pause.sh" \
                   "$HERE/../../../.claude/hooks/ai-dlc-pause.sh" \
                   "$HERE/../../../core/hooks/ai-dlc-pause.sh")"
SCHEMA="$(pick "$HERE/../../schemas/pause-routing.json" \
               "$HERE/../../../.claude/schemas/pause-routing.json" \
               "$HERE/../../../core/schemas/pause-routing.json")"

command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq required" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "answer-handoff-routing:"

# --- Assertion 0: SANITY — the subject and its declaration both resolve -----------------
# Without these every assertion below passes for the wrong reason: an absent hook produces no
# flag and no stdout, which is exactly what the negative cases assert.
if [ -z "$HOOK" ] || [ -z "$PAUSE_HOOK" ] || [ -z "$SCHEMA" ]; then
  bad "FIXTURE BROKEN — could not resolve hook=${HOOK:-<none>} pause=${PAUSE_HOOK:-<none>} schema=${SCHEMA:-<none>} in either layout"
  echo; echo "answer-handoff-routing: FIXTURE BROKEN" >&2; exit 2
fi
ok "subject and declaration resolve ($HOOK)"

# ---------------------------------------------------------------------------------------
# Drive the hook exactly as the harness does: the PostToolUse payload on stdin.
# ---------------------------------------------------------------------------------------
# `.tool_response.answers` is the {question: answer} map the harness actually sends -- the
# hook's own header records that it is identical to the `toolUseResult.answers` the
# transcript stores later, and that reading it from the transcript instead is dead because
# the transcript does not yet carry it when PostToolUse fires.
#
# A FRESH PROJECT DIR PER CASE. The subject writes a pause flag and appends to a log; a
# shared dir lets one case's flag satisfy the next case's assertion and the arm never fires.
#
# THE DIR IS CREATED BY newcase(), NOT BY fire(), and that split is a bug fix rather than a
# style. Every call site captures fire()'s stdout, so fire() runs inside `$( )` -- a
# subshell -- and an assignment made there is discarded at the closing paren. With the
# mktemp inside fire(), $CASE_DIR still held the PREVIOUS case's directory when the
# assertions read it, so five arms inspected a project the run under test had never touched
# and reported the subject doing nothing. Measured here before it was split.
CASE_DIR=""
newcase() { # newcase <with-snapshot: yes|no>
  CASE_DIR="$(mktemp -d)"; mkdir -p "$CASE_DIR/_bmad-output"
  [ "$1" = yes ] && cp "$ROOT/snapshot.md" "$CASE_DIR/_bmad-output/pipeline-snapshot.md"
  return 0
}
fire() { # fire <question> <answer> [hook] -> the hook's stdout on stdout
  local q="$1" a="$2" hk="${3:-$HOOK}"
  jq -nc --arg q "$q" --arg a "$a" \
    '{tool_name:"AskUserQuestion",session_id:"fx",tool_use_id:"tu-fx",
      tool_response:{answers:{($q):$a}}}' \
    | CLAUDE_PROJECT_DIR="$CASE_DIR" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" \
      bash "$hk" 2>/dev/null
}
flag()      { [ -f "$CASE_DIR/_bmad-output/pipeline-paused.flag" ] && echo yes || echo no; }
pauses()    { grep -c '^## .*-- USER_PAUSE' "$CASE_DIR/_bmad-output/pipeline-continuation-log.md" 2>/dev/null || echo 0; }
captured()  { grep -c '^## .*-- AskUserQuestion' "$CASE_DIR/_bmad-output/operator-answers-history.md" 2>/dev/null || echo 0; }

Q_REAL="How should I dispose of gate-3 Check 16?"

# --- Assertion 1: a handoff answer creates the pause flag ------------------------------
newcase yes; OUT="$(fire "$Q_REAL" "handoff")"
[ "$(flag)" = yes ] && ok "answer 'handoff' -> pause flag created" \
  || bad "an answer of 'handoff' left NO pause flag — the pipeline runs on through the operator's request, which is the s305 defect verbatim"

# --- Assertion 2: it is RECORDED, and the record names the channel ---------------------
# The continuation log is what retro.md reads to say whether the operator intervened. An
# episode with no USER_PAUSE row reads as a sprint the operator never touched.
[ "$(pauses)" = "1" ] && ok "USER_PAUSE logged (exactly one row)" \
  || bad "USER_PAUSE rows = $(pauses), expected 1 — a pause nothing recorded is one the retro cannot see"
if grep -q '^- Channel: AskUserQuestion answer' "$CASE_DIR/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "the USER_PAUSE record names its channel"
else
  bad "the USER_PAUSE row does not name its channel — USER_PAUSE now has two producers and the entry is the only thing that can say which one wrote it"
fi

# --- Assertion 3: the routing block reaches the lead -----------------------------------
if printf '%s' "$OUT" | jq -e '.hookSpecificOutput.hookEventName=="PostToolUse"' >/dev/null 2>&1; then
  ok "additionalContext emitted as a PostToolUse hookSpecificOutput"
else
  bad "no valid PostToolUse routing block on stdout — the flag exists but nothing tells the lead why, which is the state the lead improvised its way out of"
fi

# --- Assertion 4: SINGLE-SOURCED — the branch text is the SAME text pause.sh emits -----
# This is the assertion that makes the declaration load-bearing rather than decorative. Two
# hooks now hand the lead a three-way branch; if each carried its own copy they would drift,
# and the lead would get different instructions depending on which channel the operator used.
BRANCH="$(jq -rj '.pause_branch_text // ""' "$SCHEMA")"
A_CTX="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // ""')"
PPROJ="$(mktemp -d)"; mkdir -p "$PPROJ/_bmad-output"
cp "$ROOT/snapshot.md" "$PPROJ/_bmad-output/pipeline-snapshot.md"
P_CTX="$(printf '{"session_id":"fx","prompt":"hand off the sprint please"}' \
         | CLAUDE_PROJECT_DIR="$PPROJ" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" \
           bash "$PAUSE_HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""')"
rm -rf "$PPROJ"
if [ ${#BRANCH} -lt 100 ]; then
  bad "FIXTURE BROKEN — pause_branch_text is ${#BRANCH} bytes; a near-empty needle is contained by everything and this arm would pass against two hooks that share nothing"
elif [ -z "$A_CTX" ] || [ -z "$P_CTX" ]; then
  bad "FIXTURE BROKEN — one side emitted no context (answer=${#A_CTX}B prompt=${#P_CTX}B); two empty strings would compare equal"
else
  case "$A_CTX" in *"$BRANCH") a_has=1 ;; *) a_has=0 ;; esac
  case "$P_CTX" in *"$BRANCH") p_has=1 ;; *) p_has=0 ;; esac
  if [ "$a_has" = 1 ] && [ "$p_has" = 1 ]; then
    ok "both channels close with the SAME ${#BRANCH}-byte branch text from the declaration"
  else
    bad "the two channels do not share the declared branch text (answer=$a_has prompt=$p_has) — one of them is emitting a copy, and copies drift"
  fi
  # The preambles must DIFFER, or the split is doing nothing and a single string would have
  # been the simpler design. This is the arm that keeps the schema honest in the other
  # direction: three fields where one would do is its own defect.
  [ "$A_CTX" != "$P_CTX" ] && ok "the two channels' preambles differ, so the split earns its keep" \
    || bad "the two channels emit byte-identical context — the per-channel preamble is vacuous and the lead cannot tell which event paused it"
fi

# --- Assertion 5: A NON-HANDOFF ANSWER ROUTES NOTHING ----------------------------------
# THE LOAD-BEARING ONE. Everything above widens the hook; this is what stops the widening
# from pausing the pipeline on every question the lead asks.
newcase yes; OUT="$(fire "Which remediation do you want?" "option B — fix the validator first")"
if [ "$(flag)" = no ] && [ "$(pauses)" = "0" ] && [ -z "$OUT" ]; then
  ok "an ordinary answer routes nothing: no flag, no USER_PAUSE, no stdout"
else
  bad "AN ORDINARY ANSWER PAUSED THE PIPELINE (flag=$(flag) pauses=$(pauses) stdout=${#OUT}B) — the predicate is scoped too widely and every AskUserQuestion now stops the sprint"
fi

# --- Assertion 6: an answer ABOUT the mechanism is not a request ------------------------
# The exclusion half of the vocabulary. Without it the injected pipeline-control text, which
# itself contains the word 'handoff', makes the hook fire on its own output.
newcase yes; OUT="$(fire "What does the guard check?" "the handoff guard checks the resume prompt")"
[ "$(flag)" = no ] && ok "an answer DISCUSSING the handoff guard routes nothing" \
  || bad "fired on an answer about the mechanism rather than a request for one — a bare-substring match, and it will fire on the hook's own injected context"

# --- Assertion 7: intent is read from the ANSWER, never the QUESTION --------------------
# The question is text the LEAD authored. A hook that matched on it would route on the
# lead's own words, which is the self-referential provenance hole this hook's header already
# refuses to reopen for the SHA.
newcase yes; OUT="$(fire "Should I hand off the sprint or keep going?" "keep going")"
[ "$(flag)" = no ] && ok "handoff phrasing in the LEAD's question does not route; only the answer does" \
  || bad "routed on the lead's own question text — the lead can now pause the pipeline by phrasing a question, with no operator involved"

# --- Assertion 8: no snapshot means no pipeline — but the CAPTURE still happens ---------
# The gate is the same one ai-dlc-pause.sh uses. The capture is deliberately NOT behind it:
# the first /ai-dlc of a project has no snapshot by definition, and that is the one request
# no later artifact can reconstruct.
newcase no; OUT="$(fire "$Q_REAL" "handoff")"
if [ "$(flag)" = no ] && [ "$(captured)" = "1" ]; then
  ok "no snapshot: no flag dropped into a non-AI/DLC session, and the answer is still captured"
else
  bad "the no-pipeline gate misbehaved (flag=$(flag) captured=$(captured)) — either a flag was littered into a session with no pipeline, or the capture was lost to the routing gate"
fi

# --- Assertion 9: the capture is ADDITIVE, not replaced by the routing ------------------
# The routing arm was bolted onto a hook whose whole job was provenance. If it ever short-
# circuits the record, the operator's own words stop reaching disk and the field that cites
# them becomes a lead's account again.
newcase yes; OUT="$(fire "$Q_REAL" "handoff")"
[ "$(captured)" = "1" ] && ok "a ROUTED answer is still written to operator-answers-history.md" \
  || bad "the routed answer was not captured (rows=$(captured)) — routing has displaced provenance, which is the thing this hook was built for"

# --- Assertion 10: MUTANT — remove the routing and assertion 1 must fail ---------------
# Assertions 5 through 8 are ABSENCE-shaped: they assert nothing happened. Both-directions
# seeding shows the hook discriminates between two inputs; only a mutant shows it discriminates
# at all. Built as a COPY, guarded with `cmp -s` so a `sed` that matched nothing reports
# FIXTURE STALE rather than scoring a kill, and the edited path is printed.
#
# ANCHORED ON THE ASSIGNMENT INSIDE THE CAPTURE LOOP, not on the arm's `|| exit 0` entry
# condition. That condition is a one-line `[ ... ] || exit 0`, and a `sed` expression
# carrying `||` on both sides needs a delimiter that is not `|` -- which is a way to get the
# expression subtly wrong and score a kill from a mutation that did something else. The
# assignment is one line, unique, and disabling it is exactly "the hook saw no handoff".
MUT="$ROOT/answer-capture-noroute.sh"
sed 's#^    HANDOFF_ANSWER="\$ANSWER"$#    HANDOFF_ANSWER=""#' "$HOOK" > "$MUT"
if cmp -s "$HOOK" "$MUT"; then
  bad "FIXTURE STALE: the routing-arm mutation matched nothing in $HOOK — the arm's entry condition was reworded, so this battery is editing a file it does not understand"
elif ! bash -n "$MUT" 2>/dev/null; then
  bad "FIXTURE STALE: the routing mutant does not parse — a kill would be a syntax error rather than a disarmed arm"
else
  printf '        mutant edits: %s (from %s)\n' "$MUT" "$HOOK"
  newcase yes; OUT="$(fire "$Q_REAL" "handoff" "$MUT")"
  if [ "$(flag)" = no ] && [ -z "$OUT" ]; then
    ok "mutant: with the routing arm pinned shut, 'handoff' creates no flag — the arm is what produced assertions 1-4"
  else
    bad "MUTANT DID NOT FAIL — 'handoff' still routed (flag=$(flag) stdout=${#OUT}B) with the arm disabled, so assertions 1-4 are measuring something else"
  fi
  # CONTROL, with a POSITIVE conjunct. A copy that died on load emits nothing and writes no
  # flag, which is byte-for-byte what the kill above looks like. Requiring that the mutant
  # still CAPTURES the answer is what separates a disarmed arm from a dead script.
  [ "$(captured)" = "1" ] && ok "mutant control: the same copy still captures the answer — it loads and runs, so the kill above is real" \
    || bad "MUTANT HARNESS BROKEN — the copy captured nothing either (rows=$(captured)); it is not running, and the kill above is unreadable"
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "answer-handoff-routing: PASS"; exit 0; fi
echo "answer-handoff-routing: $fails assertion(s) FAILED" >&2
exit 1
