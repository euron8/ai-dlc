#!/usr/bin/env bash
# seed.sh — write REAL transcript files (JSONL) to disk and print the sandbox root.
#
# THE SEEDS ARE WRITTEN FROM WHAT THE HARNESS EMITS, not from what the predicate accepts.
# A seed derived from the reader's own accept-set proves the reader accepts its own grammar
# and stays green through a change to both. The three record shapes here are the ones the
# transcript actually carries: a user message whose content is a plain string, an assistant
# message whose content is an array of `text` / `tool_use` blocks, and — the one that matters
# — an AskUserQuestion ANSWER, which arrives as a `message.role=="user"` record holding a
# `tool_result` block and no text block at all.
#
# EVERY CASE SHARES ONE ASSISTANT TEXT where it can, so a difference in verdict cannot come
# from a difference in the question. `$QTEXT` is the firing text; the cases that must NOT fire
# differ from it in exactly one property each.
set -euo pipefail

ROOT="$(mktemp -d)"

u_text()   { jq -nc --arg t "$1" '{message:{role:"user",content:$t}}'; }
a_text()   { jq -nc --arg t "$1" '{message:{role:"assistant",content:[{type:"text",text:$t}]}}'; }
a_auq()    { jq -nc --arg i "$1" '{message:{role:"assistant",content:[{type:"tool_use",id:$i,name:"AskUserQuestion",input:{questions:[]}}]}}'; }
u_result() { jq -nc --arg i "$1" --arg c "$2" '{message:{role:"user",content:[{type:"tool_result",tool_use_id:$i,content:$c}]}}'; }
a_bash()   { jq -nc --arg i "$1" --arg c "$2" '{message:{role:"assistant",content:[{type:"tool_use",id:$i,name:"Bash",input:{command:$c}}]}}'; }

# The BURIAL shape, as it happened: a long recap whose closing line is the decision.
QTEXT="Gate 3 checks 1-9 are green. Checks 10 and 11 both show the same injection pattern,
which is the third time this sprint.

Should I continue through the remaining gate-3 checks, or pause given the pattern?"

# The same two sentences, ORDER REVERSED, so the `?` sits on a middle line and the final line
# is a statement. One property apart from QTEXT and nothing else.
MIDTEXT="Gate 3 checks 1-9 are green.

Should I continue through the remaining gate-3 checks, or pause given the pattern?

Continuing through the remaining checks now."

# QTEXT with the terminal `?` removed. A7's baseline: the arm must not fire, and the block
# reason must come back byte-identical to the pre-arm hook's.
NOQTEXT="Gate 3 checks 1-9 are green. Checks 10 and 11 both show the same injection pattern,
which is the third time this sprint.

Continuing through the remaining gate-3 checks."

ASK="gate 3 is showing an injection pattern in two checks"

# (F1/F2/A5) the firing shape: one genuine user turn, one assistant reply ending on a question.
{ u_text "$ASK"; a_text "$QTEXT"; } > "$ROOT/fire.jsonl"

# (A1) same text, but the turn CARRIES an AskUserQuestion tool_use -> must not fire.
{ u_text "$ASK"; a_auq "tu_a1"; a_text "$QTEXT"; } > "$ROOT/asked.jsonl"

# (A2) the `?` is on a MIDDLE line; the final line is a statement -> must not fire.
{ u_text "$ASK"; a_text "$MIDTEXT"; } > "$ROOT/midq.jsonl"

# (A3) an AskUserQuestion in the PREVIOUS turn only. A genuine-text user record sits between
#      it and the closing question, so the tool_use is outside the turn -> must FIRE.
{ u_text "start gate 3"
  a_auq "tu_a3"
  u_result "tu_a3" "Run all remaining checks"
  a_text "Taking that option."
  u_text "$ASK"
  a_text "$QTEXT"; } > "$ROOT/prevturn.jsonl"

# (A4) the AskUserQuestion ANSWER between the tool_use and the closing question, with NO
#      genuine-text user record between them. The answer does not start a turn, so the
#      tool_use is still IN the turn -> must not fire.
{ u_text "$ASK"
  a_auq "tu_a4"
  u_result "tu_a4" "Pause here"
  a_text "$QTEXT"; } > "$ROOT/answered.jsonl"

# (F3) THE ORDINARY TURN. Same closing question, but the turn does real work first: a `Bash`
#      tool_use and the tool_result it returns. This is what almost every real turn looks like,
#      and it must still FIRE -- the predicate asks whether the OPERATOR was asked with
#      AskUserQuestion, not whether the lead called a tool. A predicate keyed on any `tool_use`
#      would acquit most of the population while passing every other case in this file.
{ u_text "$ASK"
  a_bash "tu_f3" "bash scripts/ai-dlc/gate-check.sh 3"
  u_result "tu_f3" "checks 10 and 11: injection pattern"
  a_text "$QTEXT"; } > "$ROOT/othertool.jsonl"

# (A7) the non-firing flag-down baseline: same reply, no terminal question mark.
{ u_text "$ASK"; a_text "$NOQTEXT"; } > "$ROOT/noq.jsonl"

# A snapshot, so the flag-DOWN cases reach the DEFAULT BLOCK rather than Check 2's allow.
# Written from route.md's section shape, not from anything the hook parses for this arm.
cat > "$ROOT/snapshot.md" <<'EOF'
# Pipeline Snapshot

## Pipeline Position
current_step_file: gate-validation.md

## Sprint Context
sprint_id: 308

## Recent Activity
- gate 3 in progress

## Open Items
- none

## Locked Decisions
- none

## In-Flight Teammates
| agent | role | deliverable | dispatched-at | status |
|---|---|---|---|---|

## Context Reminders
context_reminders_sent: none
EOF

printf '%s\n' "$ROOT"
