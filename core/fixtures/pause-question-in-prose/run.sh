#!/usr/bin/env bash
# pause-question-in-prose — assert the Stop hook notices a pause point whose QUESTION went out
# as prose, on BOTH sides of the pause flag, and stays silent on every adjacent shape.
#
# THE DEFECT THIS FIXTURE EXISTS FOR. The lead put a real pending decision to the operator as
# the closing line of a long recap and ended its turn. The operator read narration, not a
# question; the decision was never taken and had to be re-asked. Measured on the reference
# consumer, the burial turn had the pause flag DOWN, so the hook took the DEFAULT BLOCK path
# and that path's reason told the lead to create the pause flag — which it did, then re-asked
# in prose. So the predicate is computed once and read twice, and F2 below is the assertion
# that covers the turn that actually happened.
#
# EVERY FIRING ARM HAS ITS NON-FIRING TWIN ONE PROPERTY APART: A1 adds the tool_use, A2 moves
# the `?` off the final line, A4 puts an AskUserQuestion ANSWER where A3 puts a genuine user
# message, A7 removes the terminal `?`. A firing arm alone cannot tell a predicate that reads
# its input from one that fires on everything.
#
# Usage: run.sh [path-to-ai-dlc-continue.sh]
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook. A fixture that INHERITS
# ambient config tests the config, not the code: a consumer that pins any AI_DLC_* tunable in
# settings.json exports it into every session, `git push` inherits it, and the gate then runs
# this fixture against a hook configured differently from what these assertions assume.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# The harness block cap clamps the continue hook's EFF_MAX; an exported one moves its counts.
unset CLAUDE_CODE_STOP_HOOK_BLOCK_CAP

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HOOK="$(pick "${1:-}" "$HERE/../../hooks/ai-dlc-continue.sh" \
                      "$HERE/../../../core/hooks/ai-dlc-continue.sh" \
                      "$HERE/../../../.claude/hooks/ai-dlc-continue.sh")"
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-continue.sh" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq required" >&2; exit 2; }
SCHEMA="$(pick "$HERE/../../schemas/pause-routing.json" \
               "$HERE/../../../core/schemas/pause-routing.json" \
               "$HERE/../../../.claude/schemas/pause-routing.json")"

ROOT="$(bash "$HERE/seed.sh")"
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: cannot source lib/layout.sh" >&2; exit 2; }

# PRE-WRAP GATE. A hook without the wrap would RUN when sourced (reading this shell's stdin and exiting), a silent
# green, so both halves are required before the load. Neither half predates the wrap: SKIP on a consumer, FIXTURE
# BROKEN in the distribution. Exactly one half is a respelled hook this fixture cannot drive, which FAILS.
[ -r "$HOOK" ] || { echo "FIXTURE ERROR: cannot read $HOOK -- an unreadable hook is not one that predates the wrap" >&2; exit 2; }
_pw_d=0; _pw_g=0
grep -qxF 'hkcont_main() {' "$HOOK" && _pw_d=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$HOOK" && _pw_g=1
case "$_pw_d$_pw_g" in
  11) : ;;
  00) echo "SKIP: pause-question-in-prose: $HOOK predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) echo "  FAIL  $HOOK carries one half of the in-process wrap (hkcont_main line, column-0 source guard: $_pw_d$_pw_g) -- a respelled hook this fixture cannot drive" >&2; echo "pause-question-in-prose: 1 assertion(s) FAILED" >&2; exit 1 ;;
esac
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$HOOK" || { echo "FIXTURE BROKEN: sourcing $HOOK defined nothing" >&2; exit 2; }
declare -F hkcont_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $HOOK defined no hkcont_main" >&2; exit 2; }

# THE SUBJECT MAY BE ABSENT, AND THAT MUST NOT READ AS GREEN. A core fixture ships one pull
# ahead of the code it guards, so on the pull that delivers this file the hook beside it may
# still be the pre-arm one. Every arm below is PRESENCE-shaped or paired with one, and this
# sanity arm states the resolved path so a mutation applied to a copy the run never loads
# cannot pass for an arm that could not fire.
printf '        driving: %s\n' "$HOOK"
# The REQUIRED input of inputs.decl: every arm below drives this hook.
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-continue.sh"
# The hook sources its handoff library and loads the schema only if present, and fails open
# without either, so each is REQUIRED and proven present here rather than by a verdict.
HP="$(dirname "$HOOK")/ai-dlc-handoff-pending.sh"
if [ -f "$HP" ]; then echo "HERMETIC-CONSUMED core/hooks/ai-dlc-handoff-pending.sh"; fi
if [ -n "$SCHEMA" ] && [ -f "$SCHEMA" ]; then echo "HERMETIC-CONSUMED core/schemas/pause-routing.json"; fi

# drive <case> <transcript> <flag 0|1> <snapshot 0|1> [hook]
# A fresh project dir per case, so the rapid-fire counter cannot leak between them and turn a
# BLOCKED into a BACKOFF. The project is LEFT ON DISK: the continuation log is half the
# verdict, and the arms below read it by event line.
mkproj() { # <dir> <flag 0|1> <snapshot 0|1> [pending.md to copy under docs/escalations]
  rm -rf "$1"; mkdir -p "$1/_bmad-output"
  if [ -n "${4:-}" ]; then mkdir -p "$1/docs/escalations"; cp "$4" "$1/docs/escalations/pending.md"; fi
  [ "$2" = "1" ] && touch "$1/_bmad-output/pipeline-paused.flag"
  [ "$3" = "1" ] && cp "$ROOT/snapshot.md" "$1/_bmad-output/pipeline-snapshot.md"
  return 0
}
drive() {
  local case="$1" t="$2" flag="$3" snap="$4" hk="${5:-$HOOK}" pend="${6:-}"
  local proj="$ROOT/proj-$case"
  mkproj "$proj" "$flag" "$snap" "$pend"
  jq -nc --arg t "$t" --arg s "fx-$case" '{transcript_path:$t,session_id:$s}' \
    | CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="${SCHEMA:-}" \
      inproc_run "$hk" hkcont_main > "$ROOT/out-$case.json" 2>"$ROOT/err-$case.txt"
  printf '%s' "$?" > "$ROOT/rc-$case"
}

haskey()  { jq -e --arg k "$2" 'has($k)' < "$ROOT/out-$1.json" >/dev/null 2>&1; }
reason()  { jq -r '.reason // ""' < "$ROOT/out-$1.json" 2>/dev/null || printf ''; }
logged()  { grep -q "$2" "$ROOT/proj-$1/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; }
rc()      { cat "$ROOT/rc-$1" 2>/dev/null || printf 'x'; }

RULE11='RULE 11(a) -- THE LAST LINE OF YOUR REPLY IS A QUESTION'

# --- F1: flag UP, question in prose, no AskUserQuestion in the turn -----------------------
drive f1 "$ROOT/fire.jsonl" 1 0
if haskey f1 systemMessage; then
  ok "F1 flag UP + prose question -> systemMessage emitted"
else
  bad "F1 the arm did not fire on its own subject — flag up, the reply's last line is a question, and no AskUserQuestion in the turn. Output: $(cat "$ROOT/out-f1.json")"
fi
if haskey f1 decision; then
  bad "F1 the JSON carries a \`decision\` key. This branch must not touch the stop verdict — an operator warning that also blocks turns every (b)/(c) pause into a wedged pipeline"
else
  ok "F1 no \`decision\` key — the stop stays allowed"
fi
[ "$(rc f1)" = "0" ] && ok "F1 exit 0" || bad "F1 exited $(rc f1), not 0"
logged f1 '^## .*-- PAUSE_QUESTION_IN_PROSE$' \
  && ok "F1 PAUSE_QUESTION_IN_PROSE logged" \
  || bad "F1 nothing logged the event; retro counts these from the log, so a fire nobody records is a fire nobody reviews"
logged f1 '^## .*-- ALLOWED_BY_PAUSE$' \
  && ok "F1 ALLOWED_BY_PAUSE still logged beside it (the pre-existing event is intact)" \
  || bad "F1 the ALLOWED_BY_PAUSE row is GONE — this arm displaced the event Check 1 already wrote"

# --- F2: flag DOWN, same text, snapshot present -> the DEFAULT BLOCK path ------------------
# This is the turn that actually happened. An arm sited only in Check 1 cannot reach it.
drive f2 "$ROOT/fire.jsonl" 0 1
if jq -e '.decision=="block"' < "$ROOT/out-f2.json" >/dev/null 2>&1; then
  ok "F2 flag DOWN -> the block verdict is unchanged"
else
  bad "F2 the default block verdict moved. This branch adds a paragraph to the reason and nothing else: $(cat "$ROOT/out-f2.json")"
fi
case "$(reason f2)" in
  *"$RULE11"*) ok "F2 the block reason carries the Rule 11(a) paragraph" ;;
  *) bad "F2 the block reason does NOT name Rule 11(a). This is the motivating turn: the reason text told the lead to create the pause flag, it did, and the question stayed prose" ;;
esac
case "$(reason f2)" in
  *"AskUserQuestion, every option stating its effect and the value it leaves in force, recommended option first unless an option sets or leaves in force an operator-owned value"*"then no option is badged"*) ok "F2 the paragraph names the tool, the effects clause, the option order and the unbadged case" ;;
  *) bad "F2 the paragraph does not name AskUserQuestion with each option's effect, the recommended option first, and no badge on an operator-owned value — the lead is told it is wrong and not what to do instead" ;;
esac
case "$(reason f2)" in
  *"PRODUCTION VALIDATION CHECKPOINT or the RETRO COMMENTARY PROMPT"*)
    ok "F2 the paragraph carries the (b)/(c) reading too — a prose question at those pause points is correct, and a message that only names Rule 11(a) is false there" ;;
  *) bad "F2 the paragraph names only the Rule 11(a) reading. At the PVC and the retro prompt a prose question is the mandated form, so a one-reading message instructs the lead to break Rule 3" ;;
esac
logged f2 '^- Question in prose: yes$' \
  && ok "F2 the BLOCKED row records the prose question" \
  || bad "F2 the BLOCKED row carries no \`- Question in prose: yes\` line, so the flag-down half of this population is invisible to retro"

# --- F3: an ORDINARY turn -- a Bash tool_use and its result -- still fires -----------------
# THE POPULATION IS THIS SHAPE, NOT F1'S. A turn that calls no tool at all is the exception; a
# predicate keyed on any `tool_use` rather than on the tool's NAME passes F1, A1, A2, A3, A4,
# A5, A6, A7 and every receipt, and acquits most of the real fires. F3 is the only seed that
# can tell the two apart, and A1 is its twin one property away: same shape, AskUserQuestion in
# place of Bash.
drive f3 "$ROOT/othertool.jsonl" 1 0
haskey f3 systemMessage \
  && ok "F3 an ordinary Bash tool_use in the turn -> still fires (the key is the tool's NAME)" \
  || bad "F3 did not fire on a turn that merely called Bash. The predicate is counting ANY tool_use, so it acquits every turn that did some work -- which is nearly all of them -- and the arm is dead on the population it was written for"

# --- A1: same text, but the turn CARRIES an AskUserQuestion tool_use -----------------------
drive a1 "$ROOT/asked.jsonl" 1 0
haskey a1 systemMessage \
  && bad "A1 fired on a turn that DID use AskUserQuestion — the predicate is not reading the tool_use blocks at all, and every fire above is a fire on everything" \
  || ok "A1 AskUserQuestion in the turn -> no systemMessage"
logged a1 '^## .*-- ALLOWED_BY_PAUSE$' \
  && ok "A1 control: the hook ran and allowed the stop (so the silence above is a verdict, not a dead script)" \
  || bad "A1 HARNESS BROKEN — no ALLOWED_BY_PAUSE row, so the hook did not reach Check 1 and A1's silence proves nothing"

# --- A2: the `?` is on a MIDDLE line; the final line is a statement ------------------------
drive a2 "$ROOT/midq.jsonl" 1 0
haskey a2 systemMessage \
  && bad "A2 fired on a reply whose FINAL line is a statement. The predicate is keyed on \`?\` anywhere in the last assistant text, which fires on any reply that asked a rhetorical question three paragraphs up" \
  || ok "A2 \`?\` on a middle line only -> no systemMessage"
logged a2 '^## .*-- ALLOWED_BY_PAUSE$' \
  && ok "A2 control: the hook ran and allowed the stop" \
  || bad "A2 HARNESS BROKEN — no ALLOWED_BY_PAUSE row"

# --- A3: AskUserQuestion in the PREVIOUS turn only -> must FIRE ----------------------------
drive a3 "$ROOT/prevturn.jsonl" 1 0
haskey a3 systemMessage \
  && ok "A3 tool_use in the PREVIOUS turn only -> still fires (the search is turn-scoped)" \
  || bad "A3 did not fire. The AskUserQuestion sits before a genuine user message, so it belongs to an earlier turn; a whole-transcript search acquits every session that ever used the tool once"

# --- A4: the AskUserQuestion ANSWER between the tool_use and the closing text --------------
# The answer is a `user` record holding only a tool_result. It must NOT start a turn, or the
# turn is cut between the tool_use and the reply the lead wrote after the answer came back.
drive a4 "$ROOT/answered.jsonl" 1 0
haskey a4 systemMessage \
  && bad "A4 fired although the turn's own AskUserQuestion is right there — the tool_result-only user record was taken as a turn boundary, so a question that WAS asked with the tool reads as one that was not" \
  || ok "A4 an AskUserQuestion answer does not start a turn -> no systemMessage"
logged a4 '^## .*-- ALLOWED_BY_PAUSE$' \
  && ok "A4 control: the hook ran and allowed the stop" \
  || bad "A4 HARNESS BROKEN — no ALLOWED_BY_PAUSE row"

# --- A5: flag DOWN, firing text, NO snapshot -> Check 2 allows, nothing is emitted ---------
# Check 1 is not reached, and neither is the default block. The predicate is computed either
# way, so this asserts a computed fire does not leak an operator message onto an allow path
# that never asked for one.
drive a5 "$ROOT/fire.jsonl" 0 0
haskey a5 systemMessage \
  && bad "A5 emitted an operator message on the no-pipeline allow path. The predicate is computed before Check 1 and must be READ only by the two branches that own it" \
  || ok "A5 flag DOWN + no pipeline -> no systemMessage (Check 2's allow is untouched)"
[ "$(rc a5)" = "0" ] && ok "A5 exit 0" || bad "A5 exited $(rc a5), not 0"

# --- A6: the transcript path is absent -> fail open ----------------------------------------
drive a6 "$ROOT/no-such-transcript.jsonl" 1 0
haskey a6 systemMessage \
  && bad "A6 emitted a warning with NO transcript to read. The predicate must fail open: a Stop guard that cannot read a transcript would otherwise warn on every pause in every session" \
  || ok "A6 absent transcript -> no systemMessage"
logged a6 '^## .*-- ALLOWED_BY_PAUSE$' \
  && ok "A6 ALLOWED_BY_PAUSE still logged (the pause path is intact without a transcript)" \
  || bad "A6 the pause path stopped logging when the transcript went missing"
[ "$(rc a6)" = "0" ] && ok "A6 exit 0" || bad "A6 exited $(rc a6), not 0"

# --- A7: flag DOWN, snapshot, same reply with the terminal `?` REMOVED ---------------------
# The near-miss for F2, one character apart. The block still happens; the reason must be the
# reason it always was. An arm that only asserted the paragraph APPEARS would pass against a
# hook that prepends it unconditionally.
drive a7 "$ROOT/noq.jsonl" 0 1
if jq -e '.decision=="block"' < "$ROOT/out-a7.json" >/dev/null 2>&1; then
  ok "A7 no terminal \`?\` -> still blocks (the pre-existing verdict is untouched)"
else
  bad "A7 a reply with no question stopped blocking: $(cat "$ROOT/out-a7.json")"
fi
case "$(reason a7)" in
  *"$RULE11"*) bad "A7 the Rule 11(a) paragraph was prepended to a reply carrying NO question. The prepend is unconditional, so F2 proves nothing" ;;
  *) ok "A7 the block reason carries no Rule 11(a) paragraph" ;;
esac
case "$(reason a7)" in
  *"Pipeline is active. You ended your turn without a tool call."*)
    ok "A7 the original block reason is intact and unshortened" ;;
  *) bad "A7 the standing block reason is GONE — the prepend replaced it instead of preceding it" ;;
esac
logged a7 '^- Question in prose: yes$' \
  && bad "A7 the BLOCKED row claims a prose question on a reply that has none" \
  || ok "A7 the BLOCKED row carries no prose-question line"
logged a7 '^## .*-- BLOCKED' \
  && ok "A7 control: a BLOCKED row was written (the hook reached the default path)" \
  || bad "A7 HARNESS BROKEN — no BLOCKED row, so the two absences above prove nothing"

# --- S1-S4: Check 2a -- a session that is not an /ai-dlc session may STOP ---------------------
# THE DEFECT. The snapshot is project-wide, so once a pipeline exists every session in the
# project reaches the default block. That was masked while ai-dlc-pause.sh raised the pause flag
# for prose typed in ANY session; once it stopped doing so for side sessions, a plain session and
# an /ai-dlc-update session were each forced to continue three times per turn end, by a reason
# that tells them to touch the project-wide flag -- which pauses the real lead. All four cells
# below are flag DOWN with a snapshot present, the configuration where Check 2a is the only
# difference between an allow and the default block. Each is presence-shaped on its own side.
blocked() { jq -e '.decision=="block"' < "$ROOT/out-$1.json" >/dev/null 2>&1; }
drive s1 "$ROOT/plain.jsonl" 0 1
if ! blocked s1 && logged s1 '^- This session.s transcript.s last ai-dlc marker: none; stop allowed$'; then
  ok "S1 a plain session (no ai-dlc marker) may stop, and ALLOWED_NOT_AIDLC_SESSION names why"
else
  bad "S1 a session that never invoked /ai-dlc was BLOCKED (or allowed with no record): $(cat "$ROOT/out-s1.json") — every side session in a project with a live pipeline is forced to continue and told to pause the lead"
fi
drive s2 "$ROOT/updater.jsonl" 0 1
if ! blocked s2 && logged s2 '^- This session.s transcript.s last ai-dlc marker: ai-dlc-update; stop allowed$'; then
  ok "S2 an /ai-dlc-update session (last marker) may stop"
else
  bad "S2 the updater session was BLOCKED (or allowed with no record): $(cat "$ROOT/out-s2.json") — a pull is forced to continue as though it were the lead"
fi
drive s3 "$ROOT/noq.jsonl" 0 1
if blocked s3 && ! logged s3 'ALLOWED_NOT_AIDLC_SESSION'; then
  ok "S3 the /ai-dlc lead, flag down, is still BLOCKED (Rule 3 holds for the lead)"
else
  bad "S3 the /ai-dlc lead was allowed to stop with the flag down: $(cat "$ROOT/out-s3.json") — Check 2a is acquitting the session it exists to leave alone"
fi
drive s4 "$ROOT/no-such-transcript.jsonl" 0 1
if blocked s4 && ! logged s4 'ALLOWED_NOT_AIDLC_SESSION'; then
  ok "S4 an unreadable transcript keeps today's answer: BLOCKED"
else
  bad "S4 a Stop whose transcript cannot be read was ALLOWED: $(cat "$ROOT/out-s4.json") — a lost transcript path now lets a stalled lead end its turn"
fi

# --- P1-P6: a DECISION PENDING block whose token joins one open entry stops the warning ----------
# The entries are written in the shape escalations.md gives (## header, **Status:** line,
# **Decision/Question:** line, **Veto window:** line). Each silent arm has a firing twin one property
# apart, and every case ends on a `?` so the base predicate fires on all of them.
DASH="$(printf '\342\200\224')"
mkentry() { # <file> <status> <window text>
  { echo "# Pending escalations"; echo ""
    echo "## [S308-1] lead - 2026-11-20 10:00"
    echo "**Status:** $2"
    echo "**Decision/Question:** source: recommendation -- keep the 30-day window"
    echo "**Veto window:** $3"
    echo ""; } > "$1"
}
mkentry "$ROOT/p-open.md" DECIDED_AUTONOMOUSLY "open $DASH DP-308-1"
mkentry "$ROOT/p-closed.md" DECIDED_AUTONOMOUSLY "closed $DASH _bmad-output/operator-requests-history.md:## 2026-11-20 -- /ai-dlc"
mkentry "$ROOT/p-other.md" DECIDED_AUTONOMOUSLY "open $DASH DP-308-2"
{ cat "$ROOT/p-open.md"; sed -n '3,$p' "$ROOT/p-open.md"; } > "$ROOT/p-two.md"

drive p1 "$ROOT/dpopen.jsonl" 1 0 "$HOOK" "$ROOT/p-open.md"
haskey p1 systemMessage \
  && bad "P1 a headed DECISION PENDING block with one open entry still raised the prose-question warning" \
  || ok "P1 headed block + one open entry (flag UP) -> no systemMessage"
logged p1 '^## .*-- ALLOWED_BY_PAUSE$' \
  && ok "P1 control: the hook reached Check 1 and allowed the stop (the silence is a verdict)" \
  || bad "P1 HARNESS BROKEN — no ALLOWED_BY_PAUSE row"
logged p1 '^## .*-- PAUSE_QUESTION_IN_PROSE$' \
  && bad "P1 PAUSE_QUESTION_IN_PROSE was logged for a joined open decision" \
  || ok "P1 no PAUSE_QUESTION_IN_PROSE row"

drive p1b "$ROOT/dpopen.jsonl" 0 1 "$HOOK" "$ROOT/p-open.md"
case "$(reason p1b)" in
  *"$RULE11"*) bad "P1b flag DOWN: the Rule 11(a) paragraph rode on the block reason of a joined open decision" ;;
  *) ok "P1b flag DOWN + open entry -> block reason carries no Rule 11(a) paragraph" ;;
esac
blocked p1b && ok "P1b the default block verdict is unchanged (no new stop-allow branch)" \
  || bad "P1b the verdict is no longer block: $(cat "$ROOT/out-p1b.json")"
case "$(reason p1b)" in
  *"Pipeline is active. You ended your turn without a tool call."*) ok "P1b the standing block reason is intact" ;;
  *) bad "P1b the standing block reason is gone" ;;
esac

drive p2 "$ROOT/dpnohead.jsonl" 1 0 "$HOOK" "$ROOT/p-open.md"
haskey p2 systemMessage \
  && ok "P2 an UNHEADED question with an open entry on disk -> still fires" \
  || bad "P2 an unheaded question went silent: the join keys on the entry, not on the heading"
drive p3 "$ROOT/dpopen.jsonl" 1 0 "$HOOK" "$ROOT/p-other.md"
haskey p3 systemMessage \
  && ok "P3 headed block, no entry for ITS token -> fires" \
  || bad "P3 a headed block with no recorded decision went silent"
drive p3b "$ROOT/dpopen.jsonl" 1 0
haskey p3b systemMessage \
  && ok "P3b headed block, pending.md absent -> fires (fail closed)" \
  || bad "P3b a missing pending.md silenced the warning"
drive p4 "$ROOT/dpopen.jsonl" 1 0 "$HOOK" "$ROOT/p-closed.md"
haskey p4 systemMessage \
  && ok "P4 stale: same token, window closed -> fires" \
  || bad "P4 a closed window still silences the warning"
drive p5 "$ROOT/dptrail.jsonl" 1 0 "$HOOK" "$ROOT/p-open.md"
haskey p5 systemMessage \
  && ok "P5 a different trailing question after the block -> fires" \
  || bad "P5 a trailing question after the block went silent"
drive p6 "$ROOT/dpopen.jsonl" 1 0 "$HOOK" "$ROOT/p-two.md"
haskey p6 systemMessage \
  && ok "P6 two entries naming the token -> fires (fail closed)" \
  || bad "P6 two matching entries went silent"

# --- the cli cells (cells.decl): the hook started as a PROGRAM once per distinct outcome -----------------------
# The hook exits 0 on every path; its outcomes are a block verdict, an allow carrying an operator systemMessage, and
# a silent allow. Each is started as FXCELL=<id> bash "$HOOK" on a seeded project and compared with the in-process
# call on another copy of it: stdout, stderr, exit and the project tree (timestamps and the copy's path normalised).
# Each cell asserts its own outcome, so two runs that both did nothing cannot read as equal.
EQ="$ROOT/eq"; rm -rf "$EQ"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir $EQ" >&2; exit 2; }
proj_sig() { # <dir> -> the tree's file list and contents, timestamps and the dir path normalised
  ( cd "$1" && find . -type f | sort | while read -r f; do printf '== %s\n' "$f"; cat "$f"; done ) \
    | sed -E -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?/TS/g' -e 's/^TS [0-9a-f]{16}$/TS NONCE/' -e 's/[0-9]{10}/EPOCH/g' -e "s|$1|DIR|g"
}
cli_cell() { # <id> <transcript> <flag> <snapshot> <outcome test on $EQ/<id>/cl.out> <outcome words>
  local id="$1" ip="$EQ/$1/ip" cl="$EQ/$1/cl" pl
  mkdir -p "$EQ/$id" && mkproj "$ip" "$3" "$4" && mkproj "$cl" "$3" "$4" || { bad "$id: could not seed the project"; return; }
  pl="$(jq -nc --arg t "$2" --arg s "fx-$id" '{transcript_path:$t,session_id:$s}')"
  printf '%s' "$pl" | CLAUDE_PROJECT_DIR="$ip" AI_DLC_PAUSE_ROUTING_SCHEMA="${SCHEMA:-}" inproc_run "$HOOK" hkcont_main > "$EQ/$id/ip.out" 2> "$EQ/$id/ip.err"; echo "$?" > "$EQ/$id/ip.rc"
  printf '%s' "$pl" | CLAUDE_PROJECT_DIR="$cl" AI_DLC_PAUSE_ROUTING_SCHEMA="${SCHEMA:-}" FXCELL="$id" bash "$HOOK" > "$EQ/$id/cl.out" 2> "$EQ/$id/cl.err"; echo "$?" > "$EQ/$id/cl.rc"
  proj_sig "$ip" > "$EQ/$id/ip.sig"; proj_sig "$cl" > "$EQ/$id/cl.sig"
  if cmp -s "$EQ/$id/ip.out" "$EQ/$id/cl.out" && cmp -s "$EQ/$id/ip.err" "$EQ/$id/cl.err" && cmp -s "$EQ/$id/ip.rc" "$EQ/$id/cl.rc" \
     && cmp -s "$EQ/$id/ip.sig" "$EQ/$id/cl.sig" && [ "$(cat "$EQ/$id/cl.rc")" = 0 ] && [ -s "$EQ/$id/cl.sig" ] && eval "$5"; then
    ok "$id: the program $6 exactly as the in-process call does (stdout, stderr, exit 0 and the project tree)"
  else
    bad "$id: the program and the in-process call differ, or the outcome is not: $6"
  fi
}
cli_cell cli-block "$ROOT/noq.jsonl" 0 1 \
  'jq -e ".decision==\"block\"" "$EQ/$id/cl.out" >/dev/null 2>&1' "blocks the stop with a decision on stdout"
cli_cell cli-warn "$ROOT/fire.jsonl" 1 0 \
  'jq -e "has(\"systemMessage\") and (has(\"decision\")|not)" "$EQ/$id/cl.out" >/dev/null 2>&1' "allows the stop with an operator systemMessage and no decision"
cli_cell cli-allow "$ROOT/fire.jsonl" 0 0 \
  '[ ! -s "$EQ/$id/cl.out" ]' "allows the stop silently with no pipeline"

rm -rf "$ROOT"
echo ""
report_end pause-question-in-prose
