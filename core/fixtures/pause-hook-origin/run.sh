#!/usr/bin/env bash
# pause-hook-origin/run.sh — prove ai-dlc-pause.sh pauses on operator prose and ONLY on
# operator prose.
#
# THE DEFECT. The hook touched the pause flag on every UserPromptSubmit with no inspection of
# the prompt at all; it read `.prompt` only for a 120-char log preview. The harness raises
# UserPromptSubmit identically when a backgrounded task completes as when a human types, so
# the hook created a pause flag for events carrying no operator prose, and the lead then
# blocked on a pause no human initiated. Five occurrences across two sprints on the reference
# consumer went undiagnosed, because a flag looks the same whoever created it.
#
# THE DIRECTION THAT MATTERS. A false NON-pause means the lead executes straight through a
# real operator steer — the failure Rule 29 exists to prevent. Assertion 3 is therefore the
# load-bearing one: it is the assertion that would catch a predicate scoped too widely.
#
# THE SECOND SUBJECT. Assertion 8 is about the FLOW LOG this hook opens, not about
# the origin predicate, and it reads all five hooks that can open it rather than this one.
# It lives here because assertion 6 is the arm it corrects: it asserts the legend from the
# log THIS hook produced, which is a per-hook reading of a cross-hook property, and it cannot
# see the hooks disagreeing. Their own reasoning is at assertion 8.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a hook while inheriting them tests the CONFIG, not the code — and
# then blocks the consumer's every push against a hook behaving exactly as specified.
# Scrub first (validate-enforcement-map.sh I10 asserts this rather than trusting it).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# The harness block cap clamps the continue hook's EFF_MAX; an exported one moves its counts.
unset CLAUDE_CODE_STOP_HOOK_BLOCK_CAP

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

# Sentinels for the hermetic runner: printed where each declared input is first USED. The
# provenance library and the schema are loaded fail-open by the driven hook, so each is
# guarded on the presence the hook itself would find, beside the RESOLVED hook.
[ -f "$HOOK" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-pause.sh"
[ -f "$(dirname "$HOOK")/ai-dlc-context-provenance.sh" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-context-provenance.sh"
_PRS=""; for _c in "$HERE/../../schemas/pause-routing.json" "$HERE/../../../.claude/schemas/pause-routing.json"; do [ -f "$_c" ] && { _PRS="$(cd "$(dirname "$_c")" && pwd -P)/pause-routing.json"; break; }; done
[ -n "$_PRS" ] && echo "HERMETIC-CONSUMED core/schemas/pause-routing.json"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: cannot source lib/layout.sh" >&2; exit 2; }

# PRE-WRAP GATE. A hook without the wrap would RUN when sourced (reading this shell's stdin and exiting), a silent
# green, so both halves are required before the load. Neither half predates the wrap: SKIP on a consumer, FIXTURE
# BROKEN in the distribution. Exactly one half is a respelled hook this fixture cannot drive, which FAILS. The four
# other hooks this fixture names are only read (copied and legend-compared), never run.
[ -r "$HOOK" ] || { echo "FIXTURE ERROR: cannot read $HOOK -- an unreadable hook is not one that predates the wrap" >&2; exit 2; }
_pw_d=0; _pw_g=0
grep -qxF 'hkpause_main() {' "$HOOK" && _pw_d=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$HOOK" && _pw_g=1
case "$_pw_d$_pw_g" in
  11) : ;;
  00) echo "SKIP: pause-hook-origin: $HOOK predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) echo "  FAIL  $HOOK carries one half of the in-process wrap (hkpause_main line, column-0 source guard: $_pw_d$_pw_g) -- a respelled hook this fixture cannot drive" >&2; echo "pause-hook-origin: 1 assertion(s) FAILED" >&2; exit 1 ;;
esac
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "${HOOK%/*}/ai-dlc-pause.sh" || { echo "FIXTURE BROKEN: sourcing $HOOK defined nothing" >&2; exit 2; }
declare -F hkpause_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $HOOK defined no hkpause_main" >&2; exit 2; }

# Drive the hook exactly as the harness does: JSON on stdin, CLAUDE_PROJECT_DIR set.
fire() { # <prompt-json-string>
  rm -f "$FLAG"
  printf '{"session_id":"fixture","prompt":%s}' "$1" \
    | CLAUDE_PROJECT_DIR="$PROJECT" inproc_run "${HOOK%/*}/ai-dlc-pause.sh" hkpause_main >/dev/null 2>&1
}

echo "pause-hook-origin:"

# --- Assertion 0: SANITY — the hook reaches the predicate at all --------------
# Without an active pipeline the hook exits before the predicate, and every assertion below
# would pass for the wrong reason.
if [ -f "$SNAPSHOT" ]; then
  ok "seed: a pipeline snapshot exists, so the hook runs past its no-snapshot early exit"
else
  bad "FIXTURE BROKEN — no snapshot; the hook exits before the predicate"
  echo; echo "pause-hook-origin: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: an EMPTY prompt does not pause ------------------------------
fire '""'
if [ ! -f "$FLAG" ]; then
  ok "empty prompt: no pause flag created"
else
  bad "an empty prompt still created the pause flag — the lead blocks on a pause no human initiated"
fi

# --- Assertion 2: whitespace + a system-reminder does not pause ---------------
# This is the shape a harness-synthetic event actually arrives in: no operator prose, but not
# a bare empty string either.
fire '"  \n<system-reminder>background task finished</system-reminder>\n  "'
if [ ! -f "$FLAG" ]; then
  ok "whitespace + system-reminder only: no pause flag created"
else
  bad "a prompt with no operator prose still created the pause flag"
fi

# --- Assertion 3: REAL OPERATOR PROSE STILL PAUSES ---------------------------
# The load-bearing assertion. Everything above narrows the hook; this is what stops the
# narrowing from swallowing a genuine steer.
fire '"Stop and re-check the gate before you continue."'
if [ -f "$FLAG" ]; then
  ok "operator prose: pause flag created (the narrowing cannot swallow a real steer)"
else
  bad "A REAL OPERATOR STEER DID NOT PAUSE THE PIPELINE. The predicate is scoped too widely; this is the failure direction Rule 29 exists to prevent."
fi

# --- Assertion 4: operator prose ALONGSIDE a system-reminder still pauses ------
# Every real operator turn in this harness carries system-reminder blocks. If stripping them
# ever consumed the prose too, assertion 3 would still pass while every real steer was lost.
fire '"<system-reminder>ctx</system-reminder>Actually, hold on — revert that."'
if [ -f "$FLAG" ]; then
  ok "prose + system-reminder: pause flag created (stripping does not consume the prose)"
else
  bad "a real steer arriving with a system-reminder was discarded — the strip is eating operator text"
fi

# --- Assertion 5: the skip is RECORDED, not silent ----------------------------
# A pause that never happened reads exactly like a pause the lead already cleared. If nothing
# records which, the retro cannot tell an over-firing hook from a well-behaved one.
fire '""'
if grep -q 'PAUSE_SKIPPED' "$LOG" 2>/dev/null; then
  ok "the skip is logged PAUSE_SKIPPED — not silent"
else
  bad "the hook skipped without recording it; a skip indistinguishable from a cleared pause is the same defect one layer down"
fi

# --- Assertion 6: the log legend explains the event it emits -------------------
# The skip path seeds the header too. A first-write that is a SKIP must not produce a log
# whose legend omits the only event type in it.
if grep -q '`PAUSE_SKIPPED`' "$LOG" 2>/dev/null; then
  ok "the log's event-type legend documents PAUSE_SKIPPED"
else
  bad "PAUSE_SKIPPED entries are written into a log whose legend never mentions them"
fi

# --- Assertion 10: only an /ai-dlc session's prose pauses ---------------------
# THE DEFECT. Once the pipeline was active the hook raised the project-wide pause flag for
# operator prose typed in ANY session of the project, so a message typed into a second window
# paused the lead and Rule 29 then denied six of its dispatches. The hook now asks the TYPING
# session's own transcript whether it invoked /ai-dlc (acknowledge.sh's marker: the typed
# command's user record or a structural Skill tool_use, last marker wins). Not an /ai-dlc
# session -> captured, logged PAUSE_SKIPPED, no flag. No readable transcript -> pauses.
#
# SEEDED FROM THE PRODUCER'S SHAPES: the harness writes a typed slash command as a user record
# whose content opens `<command-message>X</command-message>\n<command-name>/X</command-name>`,
# and a skill activation as an assistant tool_use `"name":"Skill","input":{"skill":"X"...`.
# The OTHER transcript carries both strings only as a MENTION inside a tool_result, where JSON
# escapes the quotes -- the shape that turned a session into an "updater" once before.
#
# One fresh project per cell, seven cells, each PRESENCE-shaped on the side that matters (a
# flag, or a PAUSE_SKIPPED row plus a capture).
T_TYPED='{"type":"user","message":{"role":"user","content":"<command-message>ai-dlc</command-message>\n<command-name>/ai-dlc</command-name>\n<command-args>Sprint 9</command-args>"}}'
T_TYPED_UPD='{"type":"user","message":{"role":"user","content":"<command-message>ai-dlc-update</command-message>\n<command-name>/ai-dlc-update</command-name>"}}'
T_SKILL='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"tu-1","name":"Skill","input":{"skill":"ai-dlc","args":"pasted brief"}}]}}'
T_MENTION='{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu-9","content":"ledger says <command-message>ai-dlc</command-message>\\n<command-name>/ai-dlc</command-name> and \"name\":\"Skill\",\"input\":{\"skill\":\"ai-dlc\""}]}}'
T_PLAIN='{"type":"user","message":{"role":"user","content":"READ the analysis doc"}}'
b_fire() { # <hook> <project> <session> <transcript-path|""> <prompt>
  if [ -n "$4" ]; then
    jq -nc --arg s "$3" --arg t "$4" --arg p "$5" '{session_id:$s,transcript_path:$t,prompt:$p}'
  else
    jq -nc --arg s "$3" --arg p "$5" '{session_id:$s,prompt:$p}'
  fi | CLAUDE_PROJECT_DIR="$2" inproc_run "${1%/*}/ai-dlc-pause.sh" hkpause_main >/dev/null 2>&1
}
b_proj() { local p; p="$(mktemp -d "$WORK/bind.XXXXXX")/project"; mkdir -p "$p/_bmad-output"
  cp "$SNAPSHOT" "$p/_bmad-output/pipeline-snapshot.md"; printf '%s' "$p"; }
b_tx() { # <project> <line>... -> transcript path
  local p="$1" t; shift; t="$p/../session.jsonl"; : > "$t"
  for l in "$@"; do printf '%s\n' "$l" >> "$t"; done; printf '%s' "$t"; }
b_paused() { [ -f "$1/_bmad-output/pipeline-paused.flag" ] && echo y || echo n; }
b_world() { # <hook> -> "LEAD SKILLTU OTHER UPDATER RESUME NOTRANS NEWSESS LOSTDIR UNREADABLE" as y/n (y = correct)
  local h="$1" p t lead skilltu other updater resume notrans newsess lostdir unreadable
  # LEAD: the lead typed /ai-dlc earlier; its later prose pauses.
  p="$(b_proj)"; t="$(b_tx "$p" "$T_PLAIN" "$T_TYPED" "$T_PLAIN")"
  b_fire "$h" "$p" "sess-lead" "$t" "Stop and re-check the gate."
  [ "$(b_paused "$p")" = y ] && lead=y || lead=n
  # SKILLTU: activated through a Skill(ai-dlc) tool_use with no typed command (pasted brief).
  p="$(b_proj)"; t="$(b_tx "$p" "$T_PLAIN" "$T_SKILL")"
  b_fire "$h" "$p" "sess-lead2" "$t" "Hold on, revert that."
  [ "$(b_paused "$p")" = y ] && skilltu=y || skilltu=n
  # OTHER: no marker, only mentions -> captured in full, PAUSE_SKIPPED with reason, no flag,
  # and no USER_PAUSE row (the heading ai-dlc-handoff-pending.sh reads).
  p="$(b_proj)"; t="$(b_tx "$p" "$T_PLAIN" "$T_MENTION")"
  b_fire "$h" "$p" "sess-other" "$t" "unrelated note from a second window"
  if [ "$(b_paused "$p")" = n ] \
     && grep -q '^- Reason: operator prose typed in a session that is not an /ai-dlc session' "$p/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
     && ! grep -q '^## .*-- USER_PAUSE' "$p/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
     && grep -q '^unrelated note from a second window$' "$p/_bmad-output/operator-requests-history.md" 2>/dev/null \
     && grep -q '^- Session: sess-other$' "$p/_bmad-output/operator-requests-history.md" 2>/dev/null; then
    other=y; else other=n; fi
  # UPDATER: an /ai-dlc session that then ran /ai-dlc-update is the updater; no pause.
  p="$(b_proj)"; t="$(b_tx "$p" "$T_TYPED" "$T_TYPED_UPD" "$T_PLAIN")"
  b_fire "$h" "$p" "sess-upd" "$t" "what version are we on now"
  [ "$(b_paused "$p")" = n ] && updater=y || updater=n
  # RESUME: /clear then `/ai-dlc resume` in a NEW session -- its transcript is not written yet
  # (an ABSENT file in an existing directory, the shape the harness produces); the current prompt
  # carries the marker and pauses (the lead's resume branch clears the flag).
  p="$(b_proj)"; t="$p/../absent-resume.jsonl"
  b_fire "$h" "$p" "sess-new" "$t" "/ai-dlc resume"
  [ "$(b_paused "$p")" = y ] && resume=y || resume=n
  # NOTRANS: no transcript_path at all -> the default branch pauses.
  p="$(b_proj)"
  b_fire "$h" "$p" "sess-x" "" "a steer with no transcript path"
  [ "$(b_paused "$p")" = y ] && notrans=y || notrans=n
  # NEWSESS: a new session's FIRST prompt -- transcript_path names a file the harness has not
  # written yet, in a directory that exists. No flag; PRESENCE of the PAUSE_SKIPPED row with the
  # new Reason and of the captured prompt, so a silent skip fails the cell.
  p="$(b_proj)"
  b_fire "$h" "$p" "sess-first" "$p/../absent-first.jsonl" "READ and FOLLOW docs/plans/x.md"
  if [ "$(b_paused "$p")" = n ] \
     && grep -q '^- Reason: operator prose typed in a new session whose transcript is not written yet' "$p/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
     && ! grep -q '^## .*-- USER_PAUSE' "$p/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
     && grep -q '^READ and FOLLOW docs/plans/x.md$' "$p/_bmad-output/operator-requests-history.md" 2>/dev/null \
     && grep -q '^- Session: sess-first$' "$p/_bmad-output/operator-requests-history.md" 2>/dev/null; then
    newsess=y; else newsess=n; fi
  # LOSTDIR: the transcript's directory is absent too -> a lost signal, the default pauses.
  p="$(b_proj)"
  b_fire "$h" "$p" "sess-y" "$p/../nodir/x.jsonl" "a steer whose transcript directory is gone"
  [ "$(b_paused "$p")" = y ] && lostdir=y || lostdir=n
  # UNREADABLE: an existing file nobody can read (mode 000) -> pauses. Root reads mode 000, so the
  # cell cannot be seeded there and reads y by stated skip.
  p="$(b_proj)"; t="$(b_tx "$p" "$T_PLAIN")"; /bin/chmod 000 "$t"
  if [ -r "$t" ]; then unreadable=y; else
    b_fire "$h" "$p" "sess-z" "$t" "a steer whose transcript cannot be read"
    [ "$(b_paused "$p")" = y ] && unreadable=y || unreadable=n
  fi
  printf '%s %s %s %s %s %s %s %s %s\n' "$lead" "$skilltu" "$other" "$updater" "$resume" "$notrans" "$newsess" "$lostdir" "$unreadable"
}
B_EXPECT="y y y y y y y y y"
B_REAL="$(b_world "$HOOK")"
if [ "$B_REAL" = "$B_EXPECT" ]; then
  ok "session test: typed /ai-dlc pauses, Skill(ai-dlc) pauses, a non-ai-dlc session captures without pausing, the updater does not pause, /ai-dlc resume in a new session pauses, a new session's first prompt (transcript not written yet) captures without pausing, no transcript path / lost directory / unreadable file pauses [$B_REAL]"
else
  bad "SESSION TEST WRONG — cells LEAD SKILLTU OTHER UPDATER RESUME NOTRANS NEWSESS LOSTDIR UNREADABLE read [$B_REAL], expected [$B_EXPECT]"
fi

# --- Assertion 8: the THREE hooks seed the SAME legend -------------------------
# WHY THIS LIVES HERE, AND WHY ASSERTION 6 IS NOT ENOUGH. Assertion 6 reads the log this
# fixture's own run produced, so it sees whichever legend `ai-dlc-pause.sh` happens to carry.
# `_bmad-output/pipeline-continuation-log.md` is opened by whichever of THREE hooks fires
# first — `ai-dlc-continue.sh`, `ai-dlc-acknowledge.sh` and this one — each seeding its own
# heredoc into an absent-or-empty file. A per-hook assertion is therefore structurally unable
# to see a disagreement BETWEEN them: assertion 6 stayed green across the entire life of one,
# in which `BACKOFF` carried two different stated causes, `PAUSE_SKIPPED` was documented in
# one legend of three, and the retro-guidance block was missing from a third. `retro.md` §4b
# counts events out of this log and the legend is the reader's ONLY statement of what a count
# means, so which legend a sprint got was decided by hook firing order.
#
# ANTI-VACUITY. Three EMPTY strings compare equal. Extraction breaking silently would close
# this arm on a dead instrument, which is the exact shape assertion 6 already failed in. The
# verdict function refuses to compare until each hook has exactly ONE legend opener and a
# NON-EMPTY body, and the byte counts are printed so a human can see the arm had a subject.
# Canonicalised, because a path carrying `../..` is not one a human can compare against the
# file they changed.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] \
  && { printf '%s/%s' "$(cd "$(dirname "$c")" && pwd)" "$(basename "$c")"; return; }; done; }
CONT_HOOK="$(pick "$HERE/../../hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../.claude/hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../core/hooks/ai-dlc-continue.sh")"
ACK_HOOK="$(pick "$HERE/../../hooks/ai-dlc-acknowledge.sh" \
                 "$HERE/../../../.claude/hooks/ai-dlc-acknowledge.sh" \
                 "$HERE/../../../core/hooks/ai-dlc-acknowledge.sh")"
PAUSE_HOOK="$(pick "$HERE/../../hooks/ai-dlc-pause.sh" \
                   "$HERE/../../../.claude/hooks/ai-dlc-pause.sh" \
                   "$HERE/../../../core/hooks/ai-dlc-pause.sh")"
ESC_HOOK="$(pick "$HERE/../../hooks/ai-dlc-escalation-delivery.sh" \
                 "$HERE/../../../.claude/hooks/ai-dlc-escalation-delivery.sh" \
                 "$HERE/../../../core/hooks/ai-dlc-escalation-delivery.sh")"
# The FIFTH seeder. `ai-dlc-answer-capture.sh` began writing USER_PAUSE when a handoff
# request arriving as an AskUserQuestion answer was routed, and any hook that can open this
# log seeds its own legend. It is in the comparison for the same reason the fourth is: a
# hook that is guarded but left out of the verdict drifts silently, and the arm goes on
# reporting agreement among the others.
ANS_HOOK="$(pick "$HERE/../../hooks/ai-dlc-answer-capture.sh" \
                 "$HERE/../../../.claude/hooks/ai-dlc-answer-capture.sh" \
                 "$HERE/../../../core/hooks/ai-dlc-answer-capture.sh")"
[ -f "$CONT_HOOK" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-continue.sh"
[ -f "$ACK_HOOK" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-acknowledge.sh"
[ -f "$ESC_HOOK" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-escalation-delivery.sh"
[ -f "$ANS_HOOK" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-answer-capture.sh"

# The heredoc body between `cat > "$LOG_FILE" <<'EOF'` and its terminator. Keyed on the
# EMITTING line, not on a mention of the log elsewhere in the file. LC_ALL=C because the
# legend carries a multibyte em-dash and awk aborts mid-file on it under a UTF-8 locale.
legend_body() { # <hook-path> -> body on stdout
  LC_ALL=C awk '
    /^[[:space:]]*cat > "\$LOG_FILE" <<.EOF.$/ { inb=1; next }
    inb && /^EOF$/                             { inb=0; next }
    inb                                        { print }
  ' "$1"
}
legend_openers() { # <hook-path> -> count of legend-emitting lines
  LC_ALL=C grep -c '^[[:space:]]*cat > "\$LOG_FILE" <<.EOF.$' "$1"
}
# One word on stdout: SAME, DIFFER, or a guard verdict naming which hook tripped it. The
# guards run over EVERY hook passed before any comparison, so an empty extraction can never
# reach the `cmp` and pass as agreement.
#
# VARIADIC IN THE COMPARISON TOO, not just in the guards. The guard loop always walked `$@`
# while the comparison hard-coded `legend.1..3`, so a FOURTH seeding hook would have been
# guarded and then silently left out of the only assertion that matters — the arm would have
# gone on reporting agreement among three while a fourth drifted. `ai-dlc-escalation-delivery.sh`
# is that fourth hook.
legend_verdict() { # <scratch-dir> <hook>... -> verdict
  local d="$1"; shift
  local n=0 h opens i
  for h in "$@"; do
    n=$((n+1))
    [ -f "$h" ] || { printf 'MISSING:%s\n' "$n"; return; }
    opens="$(legend_openers "$h")"
    [ "$opens" = "1" ] || { printf 'NO-SINGLE-OPENER:%s:%s\n' "$n" "$opens"; return; }
    legend_body "$h" > "$d/legend.$n"
    [ -s "$d/legend.$n" ] || { printf 'EMPTY-LEGEND:%s\n' "$n"; return; }
  done
  # Fewer than two bodies cannot disagree, so a shrunken caller must not read as SAME.
  [ "$n" -ge 2 ] || { printf 'TOO-FEW:%s\n' "$n"; return; }
  i=2
  while [ "$i" -le "$n" ]; do
    cmp -s "$d/legend.1" "$d/legend.$i" || { printf 'DIFFER\n'; return; }
    i=$((i+1))
  done
  printf 'SAME\n'
}

V8="UNRESOLVED"
if [ -z "$CONT_HOOK" ] || [ -z "$ACK_HOOK" ] || [ -z "$PAUSE_HOOK" ] || [ -z "$ESC_HOOK" ] || [ -z "$ANS_HOOK" ]; then
  bad "FIXTURE BROKEN — cannot locate all five log-seeding hooks in either layout"
else
  LEG="$WORK/legend"; mkdir -p "$LEG"
  printf '        legend sources: %s | %s | %s | %s | %s\n' "$CONT_HOOK" "$ACK_HOOK" "$PAUSE_HOOK" "$ESC_HOOK" "$ANS_HOOK"
  V8="$(legend_verdict "$LEG" "$CONT_HOOK" "$ACK_HOOK" "$PAUSE_HOOK" "$ESC_HOOK" "$ANS_HOOK")"
  printf '        legend bytes:   continue=%s acknowledge=%s pause=%s escalation-delivery=%s answer-capture=%s\n' \
    "$(wc -c < "$LEG/legend.1" 2>/dev/null | tr -d ' ')" \
    "$(wc -c < "$LEG/legend.2" 2>/dev/null | tr -d ' ')" \
    "$(wc -c < "$LEG/legend.3" 2>/dev/null | tr -d ' ')" \
    "$(wc -c < "$LEG/legend.4" 2>/dev/null | tr -d ' ')" \
    "$(wc -c < "$LEG/legend.5" 2>/dev/null | tr -d ' ')"
  if [ "$V8" = "SAME" ]; then
    ok "all five hooks seed a byte-identical log legend"
  elif [ "$V8" = "DIFFER" ]; then
    bad "THE SEEDED LEGENDS DISAGREE ($V8). Which legend a sprint gets is decided by hook firing order, and retro.md §4b reads it as the definition of every count it reports."
  else
    bad "FIXTURE BROKEN — legend extraction returned no subject ($V8); this arm was about to compare empty strings and pass"
  fi
fi

# --- Assertion 10: the resume CLEAR is its own call, and its absence is VERIFIED --------------
# A denied Bash call runs none of its parts. A pause-flag rm chained into a compound call that
# another hook refused for its OTHER part never ran, the flag stayed, and nothing told the lead
# to check. Two emitters prescribe the resume: this hook's REASON item 3(a), and SKILL.md's
# INITIALIZATION. They are a shell string and a markdown rule, so they stay two emitters, and
# this arm binds them: each must carry the separate `[ ! -e ... ]` verify and the own-call
# clause, and the two spans must be byte-identical once the hook's escaped backticks are
# unescaped and line wraps are collapsed.
#
# LAYOUT. In the distribution both files sit at one revision, so a disagreement is a FAIL. On
# a consumer mid-pull the hook lands at step 3 and SKILL.md at the reconcile merge, so a
# disagreement there is PENDING, never FAIL.
#
# The span runs from the backticked rm to the reason sentence, so both steps and the clause
# between them are inside it. Whitespace runs collapse to one space, because SKILL.md wraps.
resume_span() { # <hook|skill> <file> -> the normalised span on stdout, empty if absent
  LC_ALL=C awk -v kind="$1" '
    kind == "hook"  && /\(a\) Resume intent/ { txt = $0; done = 1 }
    kind == "skill" && /^## INITIALIZATION$/ { inside = 1; next }
    kind == "skill" && inside && /^[[:space:]]*$/ { if (txt != "") { inside = 0; done = 1 } ; next }
    kind == "skill" && inside && !done { txt = txt " " $0 }
    END {
      gsub(/\\`/, "`", txt)
      gsub(/[[:space:]]+/, " ", txt)
      s = index(txt, "`rm -f _bmad-output/pipeline-paused.flag`")
      if (s == 0) exit
      rest = substr(txt, s)
      endm = "A denied call runs none of its parts."
      e = index(rest, endm)
      if (e == 0) exit
      print substr(rest, 1, e + length(endm) - 1)
    }' "$2"
}
resume_verdict() { # <scratch-dir> <hook> <skill> -> verdict
  local d="$1" h="$2" s="$3" k f
  for k in hook skill; do
    case "$k" in hook) f="$h" ;; *) f="$s" ;; esac
    [ -f "$f" ] || { printf 'MISSING:%s\n' "$k"; return; }
    resume_span "$k" "$f" > "$d/resume.$k"
    [ -s "$d/resume.$k" ] || { printf 'NO-SPAN:%s\n' "$k"; return; }
    grep -qF '`[ ! -e _bmad-output/pipeline-paused.flag ]`' "$d/resume.$k" || { printf 'NO-VERIFY:%s\n' "$k"; return; }
    grep -qF 'as its own Bash call, with nothing chained before or after it' "$d/resume.$k" || { printf 'NO-OWNCALL:%s\n' "$k"; return; }
  done
  cmp -s "$d/resume.hook" "$d/resume.skill" && printf 'SAME\n' || printf 'DIFFER\n'
}
SKILL_DIST="$HERE/../../skills/ai-dlc/SKILL.md"
SKILL_FILE="$(pick "$SKILL_DIST" "$HERE/../../../.claude/skills/ai-dlc/SKILL.md")"
if [ -f "$SKILL_DIST" ] && [ -f "$HERE/../../hooks/ai-dlc-acknowledge.sh" ]; then R_LAYOUT=distribution; else R_LAYOUT=consumer; fi
if [ -z "$ACK_HOOK" ] || [ -z "$SKILL_FILE" ]; then
  bad "FIXTURE BROKEN — cannot locate ai-dlc-acknowledge.sh and SKILL.md in either layout"
else
  echo "HERMETIC-CONSUMED core/skills/ai-dlc/SKILL.md"
  RS="$WORK/resume"; mkdir -p "$RS"
  printf '        resume sources (%s): %s | %s\n' "$R_LAYOUT" "$ACK_HOOK" "$SKILL_FILE"
  V10="$(resume_verdict "$RS" "$ACK_HOOK" "$SKILL_FILE")"
  if [ "$V10" = "SAME" ]; then
    ok "the hook and SKILL.md prescribe one byte-identical two-step resume: the rm alone, then a separate [ ! -e ] verify"
  elif [ "$R_LAYOUT" = "consumer" ]; then
    printf '  PENDING  the hook and SKILL.md resume spans disagree (%s) on a consumer -- mid-pull, the hook lands before the rulebook merge\n' "$V10"
  else
    bad "THE RESUME CLEAR IS NOT BOUND ($V10): both emitters must carry the rm as its own call and the separate [ ! -e ] verify, byte-identically"
  fi
fi

# --- the cli cells (cells.decl): the hook started as a PROGRAM once per distinct outcome -----------------------
# The hook exits 0 and prints nothing on every path; what differs is what it writes into the project: a typed steer
# raises the pause flag, an empty prompt is skipped with its reason logged. Each is started as FXCELL=<id> bash
# "$HOOK" on a copy of the seeded project and compared with the in-process call on another copy: stdout, stderr, exit
# and the project tree (timestamps, epochs and the copy's path normalised). Each cell asserts its own outcome, so two
# runs that both did nothing cannot read as equal.
EQ="$WORK/eq"; rm -rf "$EQ"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir $EQ" >&2; exit 2; }
proj_sig() { # <dir> -> the tree's file list and contents, timestamps, epochs and the dir path normalised
  ( cd "$1" && find . -type f | sort | while read -r f; do printf '== %s\n' "$f"; cat "$f"; done ) \
    | sed -E -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?/TS/g' -e 's/^TS [0-9a-f]{16}$/TS NONCE/' -e 's/[0-9]{10}/EPOCH/g' -e "s|$1|DIR|g"
}
cli_cell() { # <id> <prompt-json-string> <outcome test on $cl> <outcome words>
  local id="$1" ip="$EQ/$1/ip" cl="$EQ/$1/cl" pl d
  pl="$(printf '{"session_id":"fixture","prompt":%s}' "$2")"
  for d in "$ip" "$cl"; do mkdir -p "$d/_bmad-output" && cp "$SNAPSHOT" "$d/_bmad-output/pipeline-snapshot.md" || { bad "$id: could not seed the project"; return; }; done
  printf '%s' "$pl" | CLAUDE_PROJECT_DIR="$ip" inproc_run "${HOOK%/*}/ai-dlc-pause.sh" hkpause_main > "$EQ/$id/ip.out" 2> "$EQ/$id/ip.err"; echo "$?" > "$EQ/$id/ip.rc"
  printf '%s' "$pl" | CLAUDE_PROJECT_DIR="$cl" FXCELL="$id" bash "$HOOK" > "$EQ/$id/cl.out" 2> "$EQ/$id/cl.err"; echo "$?" > "$EQ/$id/cl.rc"
  # the provenance block carries a fresh nonce per start; the rest of stdout must be byte-equal
  for _s in ip cl; do sed -E 's/nonce=[0-9a-f]+/nonce=N/g' "$EQ/$id/$_s.out" > "$EQ/$id/$_s.out.n" && mv "$EQ/$id/$_s.out.n" "$EQ/$id/$_s.out"; done
  proj_sig "$ip" > "$EQ/$id/ip.sig"; proj_sig "$cl" > "$EQ/$id/cl.sig"
  if cmp -s "$EQ/$id/ip.out" "$EQ/$id/cl.out" && cmp -s "$EQ/$id/ip.err" "$EQ/$id/cl.err" && cmp -s "$EQ/$id/ip.rc" "$EQ/$id/cl.rc" \
     && cmp -s "$EQ/$id/ip.sig" "$EQ/$id/cl.sig" && [ "$(cat "$EQ/$id/cl.rc")" = 0 ] && [ -s "$EQ/$id/cl.sig" ] && eval "$3"; then
    ok "$id: the program $4 exactly as the in-process call does (stdout, stderr, exit 0 and the project tree)"
  else
    bad "$id: the program and the in-process call differ, or the outcome is not: $4"
  fi
}
cli_cell cli-pause '"Stop and re-check the gate before you continue."' \
  '[ -f "$cl/_bmad-output/pipeline-paused.flag" ] && grep -q "USER_PAUSE" "$cl/_bmad-output/pipeline-continuation-log.md"' "raises the pause flag and logs USER_PAUSE for operator prose"
cli_cell cli-skip '""' \
  '[ ! -f "$cl/_bmad-output/pipeline-paused.flag" ] && grep -q "PAUSE_SKIPPED" "$cl/_bmad-output/pipeline-continuation-log.md"' "skips an empty prompt and logs PAUSE_SKIPPED"

echo
report_end pause-hook-origin
