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

# ---------------------------------------------------------------------------
# THE PIPELESS ROW SHAPE
# ---------------------------------------------------------------------------
# Every seed above writes the leading `|`, and that is why the sweep arm's
# `/^[[:space:]]*\|/` gate survived: no seed here carried the shape that
# discriminates. Markdown renders a table row with or without the opening delimiter
# and the reference consumer writes the bare form, so on its live snapshot the arm
# found 1 in-flight row where the relaxed form finds 5 -- four live teammates
# invisible to the guard that exists to stop a handoff while they are running.
#
# THE PIPELESS SEEDS ARE THE PRODUCER'S SHAPE. No leading pipe, no trailing pipe, no
# `|---|` separator, no backticks -- what the consumer writes. The header is pipeless
# too, which is the whole reason the relaxation needs a width test rather than a bare
# `/\|/`, and it is seeded as part of every one of these bodies.
#
# THE MATRIX IS FOUR CELLS AND THE PAIRING IS THE POINT. A pipeless BLOCK case alone
# cannot tell a correctly-keyed guard from one that blocks every pipeless section, so
# each pipeless case has its piped twin one property away.

# (d) PIPELESS + in-flight -> must BLOCK. The cell that was dead.
snap plrunning 'agent | role | deliverable | dispatched-at | status
a2b2344be58b99e31 | dev-escalated | /abs/path/report.md | 2026-09-14T04:20:00Z | in-flight' > "$ROOT/.s_pl_running"

# (e) PIPELESS + stopped -> must ALLOW. The near-miss: identical shape, legal token.
#     Without it a BLOCK on (d) reads the same whether the guard reads the token or
#     refuses every bare row it can now see.
snap plstopped 'agent | role | deliverable | dispatched-at | status
a2b2344be58b99e31 | dev-escalated | /abs/path/report.md | 2026-09-14T04:20:00Z | stopped (operator-requested handoff)' > "$ROOT/.s_pl_stopped"

# (f) PIPELESS header, no data rows -> must ALLOW. The header's own last cell is the
#     literal word `status`, and a relaxation that scores it as a data row reads a
#     teammate that does not exist.
snap plheader 'agent | role | deliverable | dispatched-at | status' > "$ROOT/.s_pl_header"

# (g) PROSE carrying a pipe -> must ALLOW. THE MEASURED FALSE POSITIVE. A bare `/\|/`
#     gate reads this line's last pipe-delimited field as a status cell; here that
#     field is `in-flight`, so the guard would block every handoff in the sprint with
#     no row to strike and nothing the lead could do to satisfy it.
snap plprose 'agent | role | deliverable | dispatched-at | status
a2b2344be58b99e31 | dev-escalated | /abs/path/report.md | 2026-09-14T04:20:00Z | stopped

Note: the only teammate that is | in-flight' > "$ROOT/.s_pl_prose"

# (h) PIPED + a stray `|` INSIDE a cell, token in-flight -> must BLOCK.
#     THE SEED THAT KILLS THE MOST PLAUSIBLE WRONG FIX. Applying the header-width test
#     to every row rather than only to pipeless ones acquits this row: the stray pipe
#     splits one field wide, the width test rejects it, and a teammate genuinely still
#     running passes the guard. That is a finding the PRE-fix arm already had.
snap straypipe '| agent | role | deliverable | dispatched-at | status |
|---|---|---|---|---|
| tester-a | qa | docs/reviews/s305|qa.md | 2026-08-25T01:10:00Z | in-flight |' > "$ROOT/.s_straypipe"

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

# ---------------------------------------------------------------------------
# THE IN-FLIGHT ROW ARM: an EMPTY table with a dispatch that has no stop record
# ---------------------------------------------------------------------------
# Every seed above varies the snapshot and holds the transcript fixed, because the
# sweep arm reads the snapshot alone. This arm reads FOUR files that no seed here has
# ever written -- the lead transcript (for `Agent` tool_use records), the spawn ledger,
# the harness meta sidecars beside the transcript, and the subagent-context stop log --
# so each case below is a WORLD, not a snapshot.
#
# THE WORLDS ARE BUILT UNDER `$ROOT/w-<name>/` AND EACH CARRIES ITS OWN FOUR FILES.
# fixture-mutants.md: a fixture with more than one world records each world IN the
# world. A shared `$LEDGER` overwritten per case hands case B case C's ledger, which
# resolves to a set the case never seeded and reads as a withheld verdict rather than
# as an error.
#
# THE TRANSCRIPT IS PADDED PAST 200 RECORDS AND THE DISPATCH SITS AT THE TOP. Measured
# on the reference consumer: across every session in the population the arm was scored
# on, a `tail -n 200` window sees 1 dispatch of 80, because dispatches are spread
# through a session rather than clustered at its end. A seed whose dispatch sits in the
# last 200 records cannot tell a whole-file read from a windowed one, and the windowed
# implementation is the cheap wrong fix somebody will reach for.
#
# THE META SIDECAR PATH IS THE HARNESS'S, NOT A CONVENTION THIS FIXTURE INVENTED:
# `<transcript-without-.jsonl>/subagents/agent-<id>.meta.json`, keyed `.toolUseId`.
# ai-dlc-subagent-probe.sh reads exactly that path to find the join key.
TUI="toolu_01FIXTUREoffender000000000"
TUI2="toolu_01FIXTUREunrelated00000000"

mkworld() { # mkworld <name> <ledger-jsonl> <ctx-jsonl> <meta-spec> <snapshot-body>
  local name="$1" ledger="$2" ctx="$3" metaspec="$4" body="$5"
  local w="$ROOT/w-$name"
  mkdir -p "$w/_bmad-output"
  local t="$w/lead.jsonl"

  # THE DISPATCH RECORD FIRST, then 400 padding records, then the handoff turn. The
  # hook reads the LAST user and LAST assistant message for the resume arm, so the
  # padding must not carry either role's text -- it is `progress` records the reader
  # skips, which is what a real session's tool_result traffic looks like to this jq.
  jq -nc --arg id "$TUI" '{message:{role:"assistant",content:[
      {type:"tool_use", id:$id, name:"Agent", input:{subagent_type:"dev-escalated"}}]}}' > "$t"
  # ONE awk, NOT 400 `jq -n` calls. Eight worlds times four hundred records is 3200
  # processes, and that loop measured 12.3s of the fixture wall clock against a 2.2s
  # base -- a fixture that costs six times what it did is a change to the suite, and the
  # padding records are literal JSON whose shape no jq expression is needed to produce.
  awk 'BEGIN { for (i = 0; i < 400; i++) printf "{\"type\":\"progress\",\"n\":%d}\n", i }' >> "$t"
  jq -nc '{message:{role:"user",content:"hand off the sprint"}}' >> "$t"
  jq -nc '{message:{role:"assistant",content:"Snapshot finalized.\n\n```\n----\n/ai-dlc resume\n----\n```\n"}}' >> "$t"

  [ -n "$ledger" ] && printf '%s\n' "$ledger" > "$w/_bmad-output/spawn-ledger.jsonl"
  [ -n "$ctx" ]    && printf '%s\n' "$ctx"    > "$w/_bmad-output/subagent-context.jsonl"
  # `${TRANSCRIPT%.jsonl}/subagents/` -- the harness's own path, the one
  # ai-dlc-subagent-probe.sh reads to find the join key. The transcript here is
  # `<w>/lead.jsonl`, so the sidecar dir is `<w>/lead/subagents/`.
  if [ "$metaspec" != "NONE" ]; then
    mkdir -p "$w/lead/subagents"
    printf '%s\n' "$metaspec" > "$w/lead/subagents/agent-afixture0000000001.meta.json"
  fi
  printf '%s\n' "$body" > "$w/snapshot-body.md"
  printf '%s' "$w"
}

# The snapshot body each world places in `## In-Flight Teammates`. Written in the
# reference consumer's own PIPELESS shape, which is what its live snapshot carries.
EMPTY_TABLE='agent | role | deliverable | dispatched-at | status'
FILLED_TABLE='agent | role | deliverable | dispatched-at | status
dev-escalated | dev-escalated | /abs/path/report.md | 2026-09-14T05:28:04Z | stopped'
UNRELATED_TABLE='agent | role | deliverable | dispatched-at | status
some-other-hand | qa | docs/reviews/other.md | 2026-09-14T01:00:00Z | stopped'

LEDGER_ROW="$(jq -nc --arg t "$TUI" '{v:1, ts:"2026-09-14T05:28:04Z", name:"dev-escalated",
   role:"dev-escalated", model_bound:"opus", definition_bound:true, tool_use_id:$t}')"
CTX_ROW="$(jq -nc --arg t "$TUI" '{v:3, ts:"2026-09-14T05:31:00Z", agent_id:"afixture0000000001",
   role:"dev-escalated", peak_tokens:1000, tool_use_id:$t}')"
# A ctx row for a DIFFERENT dispatch. Every world needs the stop log to be non-empty,
# or an arm that reads zero rows cannot be told from one that read a file that is not
# there -- and the set difference against an empty set is the identity, which is the
# same answer the broken reader gives.
CTX_OTHER="$(jq -nc '{v:3, ts:"2026-09-13T00:00:00Z", agent_id:"aother000000000001",
   role:"qa", peak_tokens:1000, tool_use_id:"toolu_01FIXTUREsomeoneelse00000"}')"
META_TUI="$(jq -nc --arg t "$TUI" '{agentType:"dev-escalated", toolUseId:$t}')"
# The NAMED in-process teammate: `teamName` and NO `toolUseId`. Partitioned over the
# harness corpus the two keys never co-occur, so this is the producer's real shape.
META_TEAM='{"agentType":"general-purpose","teamName":"party-dev"}'

# (A) OFFENDER: dispatch in the transcript, a role-bound ledger row carrying its
#     tool_use_id, a meta sidecar keyed on the same id, NO stop record, empty table.
mkworld offender "$LEDGER_ROW" "$CTX_OTHER" "$META_TUI" "$EMPTY_TABLE" > "$ROOT/.w_offender"

# (B) The table carries a MATCHING row -> ALLOW. One property from (A).
mkworld tablerow "$LEDGER_ROW" "$CTX_OTHER" "$META_TUI" "$FILLED_TABLE" > "$ROOT/.w_tablerow"

# (C) The stop record EXISTS -> ALLOW. The teammate returned and the probe wrote its row.
mkworld ctxrow "$LEDGER_ROW" "$(printf '%s\n%s' "$CTX_OTHER" "$CTX_ROW")" "$META_TUI" "$EMPTY_TABLE" > "$ROOT/.w_ctxrow"

# (D) NEVER SPAWNED: the ledger row exists (the guard writes it at PreToolUse, before
#     anything can deny the call) and NO meta sidecar was ever created. This is the
#     Rule-29-denied and agent-type-not-found class, and it is the reason the meta
#     narrowing exists -- without it these block a handoff over a teammate that does
#     not exist. The sidecar dir is present but holds a meta for an UNRELATED id, so
#     the case discriminates the narrowing from a missing directory.
mkworld nospawn "$LEDGER_ROW" "$CTX_OTHER" '{"agentType":"qa","toolUseId":"toolu_01FIXTUREunrelated00000000"}' "$EMPTY_TABLE" > "$ROOT/.w_nospawn"

# (E) A LIVE NAMED TEAMMATE -> ALLOW, and this one is the STATED BLINDNESS rather than a
#     case the arm handles. Its ledger row carries a `name` and a `role` and NO
#     `tool_use_id`; its meta carries `teamName` and no `toolUseId`. Nothing joins, the
#     open set is empty, and the empty table does not block. A future name-keyed join
#     would flip this cell, which is why it is asserted rather than left implicit.
mkworld namedteam \
  "$(jq -nc '{v:1, ts:"2026-09-14T05:28:04Z", name:"party-dev", role:"dev",
              model_bound:"opus", definition_bound:false, tool_use_id:null}')" \
  "$CTX_OTHER" "$META_TEAM" "$EMPTY_TABLE" > "$ROOT/.w_namedteam"

# (G) The transcript path names no file -> fail open. Built from (A) and then the
#     transcript is removed, so every other input is the offender's.
GW="$(mkworld notranscript "$LEDGER_ROW" "$CTX_OTHER" "$META_TUI" "$EMPTY_TABLE")"
printf '%s' "$GW" > "$ROOT/.w_notranscript"

# (H) No meta directory beside the transcript at all -> fail open. A consumer whose
#     harness build does not write sidecars, or a session predating them.
mkworld nometadir "$LEDGER_ROW" "$CTX_OTHER" "NONE" "$EMPTY_TABLE" > "$ROOT/.w_nometadir"

# (I) The table carries ONE UNRELATED row -> ALLOW. THE STATED ACQUITTAL, seeded so it
#     is asserted rather than discovered. The check is a PRESENCE test on the table and
#     one row from any dispatch acquits the turn; a future identity join would flip this
#     cell, and the header says why it is not one (2 of 115 historical first cells
#     resolve to a spawn meta, and neither of those reaches a ledger row).
mkworld unrelatedrow "$LEDGER_ROW" "$CTX_OTHER" "$META_TUI" "$UNRELATED_TABLE" > "$ROOT/.w_unrelatedrow"

printf '%s\n' "$ROOT"
