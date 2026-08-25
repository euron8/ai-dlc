#!/usr/bin/env bash
# seed.sh — build the sandbox for answer-handoff-routing and print its root on stdout.
#
# Each case gets its OWN project dir, because the subject writes a pause flag and appends to
# a log: a shared dir would let case N's flag satisfy case N+1's assertion, and the run would
# read green with the arm never firing.
set -euo pipefail

ROOT="$(mktemp -d)"

# A minimal pipeline snapshot. Its CONTENT is irrelevant to this fixture -- the hook gates on
# the file EXISTING, which is how it tells an active pipeline from a session that has never
# run /ai-dlc. It is written from route.md's section list anyway, so a later change that made
# the gate parse the file finds something parseable rather than a stub.
cat > "$ROOT/snapshot.md" <<'EOF'
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
| agent | role | deliverable | dispatched-at | status |
|---|---|---|---|---|

## Context Reminders
context_reminders_sent: none
EOF

printf '%s\n' "$ROOT"
