#!/usr/bin/env bash
#
# Seed transcripts for check-25 (Rule 29 bounded-join conduct).
#
# Three cases, each a Claude Code session transcript in JSONL. The shapes are
# lifted from the live consumer's S290 planning phase, which is where the real
# 11 violations were measured -- not invented.
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

echo "$ROOT"
