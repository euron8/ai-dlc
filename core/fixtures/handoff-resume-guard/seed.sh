#!/usr/bin/env bash
# seed.sh — write REAL transcript files (JSONL) and a REAL project dir to disk.
# Prints the sandbox root on stdout.
set -euo pipefail

ROOT="$(mktemp -d)"
mkdir -p "$ROOT/_bmad-output"

# One transcript = one JSONL file of {message:{role,content}} lines, which is the
# shape ai-dlc-continue.sh's jq actually reads.
mk() { # mk <name> <user-text> <assistant-text>
  local f="$ROOT/$1.jsonl"
  jq -nc --arg u "$2" '{message:{role:"user",content:$u}}'      >  "$f"
  jq -nc --arg a "$3" '{message:{role:"assistant",content:$a}}' >> "$f"
  printf '%s' "$f"
}

# (1) handoff REQUESTED, no resume block at all -> must BLOCK
mk miss "hand off the sprint" \
  "Done. I've committed everything and updated the snapshot. Ready when you are." > "$ROOT/.p_miss"

# (2) handoff REQUESTED, resume block in CORE's mandated format (four hyphens)
#     -> must PASS. The reference consumer's copy demanded exactly six and would
#     have BLOCKED this — a check firing on compliance with the rulebook.
mk core4 "hand off the sprint" \
  "Snapshot finalized.

\`\`\`
----
/ai-dlc resume
----
\`\`\`
" > "$ROOT/.p_core4"

# (3) same, six hyphens (what the reference consumer emitted) -> must ALSO pass.
mk six "hand off the sprint" \
  "Snapshot finalized.

\`\`\`
------
/ai-dlc resume
------
\`\`\`
" > "$ROOT/.p_six"

# (4) /ai-dlc resume present but NOT delimited (blockquote prose) -> must BLOCK.
#     Presence is not format; this is the case a substring grep false-greens.
mk undelimited "hand off the sprint" \
  "All set. When you're ready, just run > /ai-dlc resume in a fresh session." > "$ROOT/.p_undelim"

# (5) incidental NOUN mention, NOT a request -> must NOT fire at all.
mk noun "what does the handoff guard actually check?" \
  "It checks that the resume prompt is delimited." > "$ROOT/.p_noun"

# (6) A COMPLIANT handoff turn: request + the mandated resume block. Reused by every
#     teammate-sweep case below, so those cases differ from each other in the SNAPSHOT
#     alone and nothing else. If they each carried their own transcript, a difference in
#     the resume block would be indistinguishable from a difference in the sweep.
mk sweep "hand off the sprint" \
  "Snapshot finalized.

\`\`\`
----
/ai-dlc resume
----
\`\`\`
" > "$ROOT/.p_sweep"

# ---------------------------------------------------------------------------
# Snapshots for the teammate-sweep arm
# ---------------------------------------------------------------------------
# Three snapshots that differ ONLY in the In-Flight Teammates section, so the arm's verdict
# cannot be produced by anything else in the file. Every one carries the other six
# load-bearing sections, because a snapshot the guard cannot parse would fail-open and read
# exactly like a clean sweep.
#
# THE SEED IS WRITTEN FROM route.md's ROW SHAPE, not from the guard's reader. A seed derived
# from what the reader accepts proves the reader accepts its own grammar and stays green
# through a change to both.
snap() { # snap <name> <inflight-section-body>
  cat > "$ROOT/snap-$1.md" <<EOF
# Pipeline Snapshot

## Pipeline Position
current_step_file: implementation.md

## Sprint Context
sprint_id: 305

## Recent Activity
- gate 3 in progress

## Open Items
- none

## Locked Decisions
- none

## In-Flight Teammates
$2

## Context Reminders
context_reminders_sent: none
EOF
  printf '%s' "$ROOT/snap-$1.md"
}

# (a) a teammate is still recorded as running -> the sweep was not done, or was not recorded
snap running '| agent | role | deliverable | dispatched-at | status |
|---|---|---|---|---|
| tester-a | qa | docs/reviews/s305-qa.md | 2026-08-25T01:10:00Z | in-flight |' > "$ROOT/.s_running"

# (b) the same teammate, swept and RECORDED -> the state steps/handoff.md step 1 mandates
snap stopped '| agent | role | deliverable | dispatched-at | status |
|---|---|---|---|---|
| tester-a | qa | docs/reviews/s305-qa.md | 2026-08-25T01:10:00Z | stopped |' > "$ROOT/.s_stopped"

# (b2) STILL RUNNING, but the status cell carries a trailing note. This is the form the
#      reference consumer's live snapshot actually writes -- `in-flight, since <ts>`,
#      `in-flight, retrying Write`, `in-flight (VERIFY pass, ...)`. Seed (a) uses the BARE
#      token, which is the form the guard already accepted, so it could never have caught
#      the equality test this replaced: measured on the four real forms, 1 blocked and 3
#      were ALLOWED with teammates genuinely running.
snap runningnote '| agent | role | deliverable | dispatched-at | status |
|---|---|---|---|---|
| tester-a | qa | docs/reviews/s305-qa.md | 2026-08-25T01:10:00Z | in-flight, since 2026-08-25T01:10:00Z |' > "$ROOT/.s_running_note"

# (c) no In-Flight section at all. route.md says that section AUTO-HEALS, so a snapshot
#     written by an older version legitimately lacks it and must not be blocked.
cat > "$ROOT/snap-nosection.md" <<'EOF'
# Pipeline Snapshot

## Pipeline Position
current_step_file: implementation.md

## Sprint Context
sprint_id: 305

## Recent Activity
- gate 3 in progress

## Open Items
- none

## Locked Decisions
- none

## Context Reminders
context_reminders_sent: none
EOF
printf '%s' "$ROOT/snap-nosection.md" > "$ROOT/.s_nosection"

printf '%s\n' "$ROOT"
