#!/usr/bin/env bash
#
# Seed transcripts for check-25 (Rule 29 bounded-join conduct).
#
# Three cases, each a Claude Code session transcript in JSONL. The shapes are
# lifted from the live consumer's S290 planning phase, which is where the real
# 11 violations were measured -- not invented. Eight sib-* cases follow them, for
# the siblings of an AskUserQuestion.
#
# Prints the temp root on the last line.
set -u
ROOT="$(mktemp -d)"

# A tool_use turn followed by its tool_result. The validator derives wall-clock
# from the timestamp delta between the assistant's tool_use and the user's
# tool_result, so BOTH records are required for a call to be measurable at all.
turn() { # turn <file> <id> <tool> <input-json> <t0> <t1>
  printf '%s\n' "{\"type\":\"assistant\",\"timestamp\":\"$5\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"$2\",\"name\":\"$3\",\"input\":$4}]}}" >> "$1"
  printf '%s\n' "{\"type\":\"user\",\"timestamp\":\"$6\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"$2\"}]}}" >> "$1"
}

# --- starves: the exact shape S290 hand-rolled, eight times over ---------------
# An unbounded foreground poll. 600s = the harness Bash cap, which is where these
# actually landed: the loop ran until the harness killed it, and the verdict went
# to a file the lead never read.
mkdir -p "$ROOT/starves"
F="$ROOT/starves/session.jsonl"
: > "$F"
turn "$F" t1 Bash \
  '{"command":"until [ -s _bmad-output/planning-artifacts/s290-brief-adversarial-p1.md ]; do sleep 15; done; echo DELIVERED"}' \
  "2026-07-13T12:00:00.000Z" "2026-07-13T12:10:00.000Z"

# --- clean: the same wait, done correctly -------------------------------------
# One bounded beat through the script. Returns inside the budget, so the operator
# had a tool boundary to be heard at.
mkdir -p "$ROOT/clean"
F="$ROOT/clean/session.jsonl"
: > "$F"
turn "$F" t1 Bash \
  '{"command":"scripts/ai-dlc/wait-for-deliverable.sh _bmad-output/planning-artifacts/s290-brief-adversarial-p1.md"}' \
  "2026-07-13T12:00:00.000Z" "2026-07-13T12:01:50.000Z"

# --- backgrounded: the decoy that must NOT fire -------------------------------
# A long call is only starvation if it is FOREGROUND. run_in_background:true yields
# a tool boundary immediately, so the operator is reachable throughout. A check that
# flagged this would punish the very dispatch shape Rule 29 prescribes -- and would
# be turned off within a sprint.
mkdir -p "$ROOT/backgrounded"
F="$ROOT/backgrounded/session.jsonl"
: > "$F"
turn "$F" t1 Bash \
  '{"command":"npm run build","run_in_background":true}' \
  "2026-07-13T12:00:00.000Z" "2026-07-13T12:30:00.000Z"

# --- sib-*: the siblings of an AskUserQuestion ---------------------------------
# Calls issued in one assistant turn return together, so a Bash sent beside an
# AskUserQuestion gets its result only when the human answers. The HARNESS writes
# ONE record per content block: the siblings sit in SEPARATE records that share
# `message.id` and carry their own `uuid`. Seeded that way, never as one record
# holding both blocks -- a reader keyed on the record would pass that seed.
use_rec() { # use_rec <file> <message-id-or-empty> <uuid> <ts> <tool-id> <tool> <input-json>
  local msg
  if [ -n "$2" ]; then
    msg="{\"id\":\"$2\",\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"$5\",\"name\":\"$6\",\"input\":$7}]}"
  else
    msg="{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"$5\",\"name\":\"$6\",\"input\":$7}]}"
  fi
  printf '%s\n' "{\"type\":\"assistant\",\"uuid\":\"$3\",\"timestamp\":\"$4\",\"message\":$msg}" >> "$1"
}
res_rec() { # res_rec <file> <uuid> <ts> <tool-id> <text>
  printf '%s\n' "{\"type\":\"user\",\"uuid\":\"$2\",\"timestamp\":\"$3\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"$4\",\"content\":\"$5\"}]}}" >> "$1"
}
AUQ='{"questions":[{"question":"Proceed with the merge?","options":[{"label":"yes"},{"label":"no"}]}]}'
BASH_IN='{"command":"git status --short"}'
ANS='User has answered your questions: Proceed with the merge?=yes.'
T0="2026-07-13T13:00:00.000Z"
T0B="2026-07-13T13:00:00.400Z"
TANS="2026-07-13T13:10:00.000Z"      # the answer: 600s of think-time, past the 150s threshold
TSIB="2026-07-13T13:10:00.500Z"      # the sibling's result, delivered WITH the answer

# sib-a: same message.id, the Bash ends at the answer. Charged 0.5s: count 0.
mkdir -p "$ROOT/sib-a"; F="$ROOT/sib-a/session.jsonl"; : > "$F"
use_rec "$F" msg_01SibAlpha u-a1 "$T0"  q1 AskUserQuestion "$AUQ"
use_rec "$F" msg_01SibAlpha u-a2 "$T0B" b1 Bash "$BASH_IN"
res_rec "$F" u-a3 "$TANS" q1 "$ANS"
res_rec "$F" u-a4 "$TSIB" b1 "ok"

# sib-b: the SAME timing, the Bash in a DIFFERENT message. It ends 0.5s after an
# answer it never waited on, which is what a timestamp-proximity key would acquit.
mkdir -p "$ROOT/sib-b"; F="$ROOT/sib-b/session.jsonl"; : > "$F"
use_rec "$F" msg_01SibAlpha u-b1 "$T0"  q1 AskUserQuestion "$AUQ"
use_rec "$F" msg_01SibBravo u-b2 "$T0B" b1 Bash "$BASH_IN"
res_rec "$F" u-b3 "$TANS" q1 "$ANS"
res_rec "$F" u-b4 "$TSIB" b1 "ok"

# sib-c: same message, but the Bash keeps blocking 600s AFTER the answer.
mkdir -p "$ROOT/sib-c"; F="$ROOT/sib-c/session.jsonl"; : > "$F"
use_rec "$F" msg_01SibAlpha u-c1 "$T0"  q1 AskUserQuestion "$AUQ"
use_rec "$F" msg_01SibAlpha u-c2 "$T0B" b1 Bash "$BASH_IN"
res_rec "$F" u-c3 "$TANS" q1 "$ANS"
res_rec "$F" u-c4 "2026-07-13T13:20:00.000Z" b1 "ok"

# sib-d: sib-a's timing with NO message.id key on either record. Joins nothing.
mkdir -p "$ROOT/sib-d"; F="$ROOT/sib-d/session.jsonl"; : > "$F"
use_rec "$F" "" u-d1 "$T0"  q1 AskUserQuestion "$AUQ"
use_rec "$F" "" u-d2 "$T0B" b1 Bash "$BASH_IN"
res_rec "$F" u-d3 "$TANS" q1 "$ANS"
res_rec "$F" u-d4 "$TSIB" b1 "ok"

# sib-e: TWO AskUserQuestions in one message, answered at +300s and +600s; the Bash
# ends at the LATER answer. Charged from the latest answer: 0.5s. From the first: 300.5s.
mkdir -p "$ROOT/sib-e"; F="$ROOT/sib-e/session.jsonl"; : > "$F"
use_rec "$F" msg_01SibAlpha u-e1 "$T0"  q1 AskUserQuestion "$AUQ"
use_rec "$F" msg_01SibAlpha u-e2 "2026-07-13T13:00:00.200Z" q2 AskUserQuestion "$AUQ"
use_rec "$F" msg_01SibAlpha u-e3 "$T0B" b1 Bash "$BASH_IN"
res_rec "$F" u-e4 "2026-07-13T13:05:00.000Z" q1 "$ANS"
res_rec "$F" u-e5 "$TANS" q2 "$ANS"
res_rec "$F" u-e6 "$TSIB" b1 "ok"

# sib-f: sib-a with a READ sibling. The motivating transcript's sibling is a Read, so a join
# that admits only a Bash sibling must fail here. Charged 0.5s: count 0.
mkdir -p "$ROOT/sib-f"; F="$ROOT/sib-f/session.jsonl"; : > "$F"
use_rec "$F" msg_01SibAlpha u-f1 "$T0"  q1 AskUserQuestion "$AUQ"
use_rec "$F" msg_01SibAlpha u-f2 "$T0B" r1 Read '{"file_path":"docs/plan.md"}'
res_rec "$F" u-f3 "$TANS" q1 "$ANS"
res_rec "$F" u-f4 "$TSIB" r1 "ok"

# sib-g: the sibling's record is written BEFORE the AskUserQuestion's in the same message --
# 4 of 10 real sibling messages are ordered that way. A single pass that registers an answer
# only when it reaches the AskUserQuestion record never joins this sibling. Count 0.
mkdir -p "$ROOT/sib-g"; F="$ROOT/sib-g/session.jsonl"; : > "$F"
use_rec "$F" msg_01SibAlpha u-g1 "$T0"  b1 Bash "$BASH_IN"
use_rec "$F" msg_01SibAlpha u-g2 "$T0B" q1 AskUserQuestion "$AUQ"
res_rec "$F" u-g3 "$TANS" q1 "$ANS"
res_rec "$F" u-g4 "$TSIB" b1 "ok"

# sib-h: an UNANSWERED AskUserQuestion (no tool_result at all) beside a Bash that blocks 600s.
# No answer exists to charge from, so the Bash is charged in full: count 1, STARVATION.
mkdir -p "$ROOT/sib-h"; F="$ROOT/sib-h/session.jsonl"; : > "$F"
use_rec "$F" msg_01SibAlpha u-h1 "$T0"  q1 AskUserQuestion "$AUQ"
use_rec "$F" msg_01SibAlpha u-h2 "$T0B" b1 Bash "$BASH_IN"
res_rec "$F" u-h3 "$TSIB" b1 "ok"

echo "$ROOT"
