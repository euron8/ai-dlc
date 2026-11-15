#!/usr/bin/env bash
# handoff-resume-guard — assert Check 0 blocks a missed resume prompt, and does NOT
# block one that follows the rulebook.
#
# THE DEFECT THIS FIXTURE EXISTS FOR. The reference consumer carried this guard for
# months matching EXACTLY six hyphens (`^------$`) while `steps/handoff.md` step 4 has
# ALWAYS mandated four (`----`). Six-hyphen appears nowhere in core, at any sha. So the
# guard fired on handoffs that were CORRECT per the rulebook: the lead emitted `----` as
# instructed, was blocked, read a block message telling it to use `------`, and complied
# with the HOOK instead of the RULE.
#
# Assertion 2 is therefore the load-bearing one: it FAILS against the version of this
# guard that was actually running in production.
#
# Usage: run.sh [path-to-ai-dlc-continue.sh]
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook.
#
# A fixture that INHERITS ambient config tests the config, not the code. The hooks honour
# thirteen AI_DLC_* tunables; a consumer that sets any of them in settings.json exports it
# into every session, `git push` inherits it, and the pre-push gate then runs this fixture
# against a hook configured differently from what the assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M (the documented, sanctioned way to
# declare the model row). Its effective window became 300000 instead of 200000, every
# threshold shifted, and SEVEN assertions failed against a sensor that was behaving exactly
# as specified. The gate blocked every push on the repo. The distribution never caught it
# because the distribution sets none of these -- the check could not fire where it was
# authored.
#
# Unset ALL of them, by pattern, so a NEW tunable cannot reintroduce this. Per-command
# assignments (`AI_DLC_MODEL_ROW=1M "$HOOK"`) still work: those are the deliberate tests.
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
echo "HERMETIC-CONSUMED $(cd "$(dirname "$HOOK")" && pwd)/$(basename "$HOOK")"

ROOT="$(bash "$HERE/seed.sh")"
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# Drive the hook exactly as the harness does: JSON on stdin, decision on stdout.
# A fresh state dir per case, so the rapid-fire backoff cannot leak between them.
#
# The optional second argument is a SNAPSHOT to place in the project dir. Without it the
# project has no snapshot at all, which is the shape every pre-existing assertion below was
# written against and the shape the teammate-sweep arm deliberately fails open on.
# The optional third is the hook to drive, defaulting to the resolved one.
#
# A SNAPSHOT ALSO NEEDS THE PAUSE FLAG, and leaving it out is a trap that reads as a guard
# failure. Check 0 is the FIRST check in the hook; Check 1 (pause flag) and Check 2 (no
# active pipeline) are what produce an ALLOW further down. With no snapshot, Check 2 allows
# and Check 0's verdict is the only thing that can block — which is why the five original
# assertions read cleanly without either file. Add a snapshot and the pipeline is ACTIVE, so
# Rule 3 enforcement blocks every Stop regardless of Check 0, and a compliant case comes
# back `block` for a reason that has nothing to do with the arm under test. Measured here:
# three assertions failed that way before the flag was added. The flag is also what really
# happens — ai-dlc-pause.sh created it the moment the operator typed the request.
drive() { # drive <transcript> [snapshot] [hook] -> prints "block" or "allow"
  local t="$1" snap="${2:-}" hk="${3:-$HOOK}" out
  local proj; proj="$(mktemp -d)"; mkdir -p "$proj/_bmad-output/.driver"
  # STEP 4's TOUCH, DONE. Check 0 asserts `.driver/handoff` once the resume, sweep and push
  # arms are satisfied, so an ALLOW case here needs the lead's own touch on disk or it blocks
  # for a reason this fixture does not test. This is the lead's Bash action, not a hook's
  # artifact, so writing it here is seeding the actor's step and not the reader's grammar;
  # handoff-completion-assertion owns the arm.
  # ORDER MATTERS: the driver arm treats a signal OLDER than the snapshot as a previous
  # handoff's, so the snapshot is copied first and the touch comes after it, as step 3 precedes
  # step 4 in the procedure.
  [ -n "$snap" ] && { cp "$snap" "$proj/_bmad-output/pipeline-snapshot.md"
                      touch "$proj/_bmad-output/pipeline-paused.flag"; }
  : > "$proj/_bmad-output/.driver/handoff"
  out="$(jq -nc --arg t "$t" --arg s "fx" '{transcript_path:$t,session_id:$s}' \
        | CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" \
          bash "$hk" 2>/dev/null)"
  rm -rf "$proj"
  if printf '%s' "$out" | jq -e '.decision=="block"' >/dev/null 2>&1; then
    printf 'block'
  else
    printf 'allow'
  fi
}

# --- Assertion 0: THE DECLARATION RESOLVES, and its absence really does disarm the guard --
#
# Check 0's handoff vocabulary is no longer written in the hook. It is read from
# schemas/pause-routing.json, because ai-dlc-answer-capture.sh needs the same set to route a
# handoff that arrives as an AskUserQuestion answer, and two hand-maintained lists of
# handoff phrasings are two lists that drift. The cost of that is a new way for this guard
# to do nothing: an install that lost the schema skips Check 0 entirely and every assertion
# below then passes for the wrong reason -- an ALLOW that means "the guard never ran".
#
# BOTH DIRECTIONS, because either alone is unreadable. First: the declaration is where the
# hook will look for it. Second: with it genuinely unreachable, assertion 1's case -- a
# handoff request with no resume block, which MUST block -- comes back ALLOW. That second
# arm is what makes the first load-bearing; without it, "the file exists" is a fact about
# the tree and not about the guard.
SCHEMA="$(pick "$HERE/../../schemas/pause-routing.json" \
               "$HERE/../../../core/schemas/pause-routing.json" \
               "$HERE/../../../.claude/schemas/pause-routing.json")"
if [ -n "$SCHEMA" ]; then
  ok "pause-routing.json resolves ($SCHEMA)"
else
  bad "FIXTURE BROKEN — schemas/pause-routing.json not found in either layout; Check 0 reads its vocabulary from there and would skip, so every assertion below would pass without the guard running"
  echo ""; echo "handoff-resume-guard: FIXTURE BROKEN" >&2; rm -rf "$ROOT"; exit 2
fi

# The unreachable-declaration probe. A copy of the hook in a directory with no sibling
# schemas/, driven with a project dir that has none either and the env override pointed at a
# path that does not exist.
ISO="$ROOT/isolated"; mkdir -p "$ISO"; cp "$HOOK" "$ISO/ai-dlc-continue.sh"
iso_proj="$(mktemp -d)"; mkdir -p "$iso_proj/_bmad-output"
iso_out="$(jq -nc --arg t "$(cat "$ROOT/.p_miss")" --arg s "fx" '{transcript_path:$t,session_id:$s}' \
          | CLAUDE_PROJECT_DIR="$iso_proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$ROOT/no-such-schema.json" \
            bash "$ISO/ai-dlc-continue.sh" 2>/dev/null)"
rm -rf "$iso_proj"
if printf '%s' "$iso_out" | jq -e '.decision=="block"' >/dev/null 2>&1; then
  bad "the guard BLOCKED with its vocabulary declaration unreachable — it is matching on something written in the hook after all, and the single-source claim is false"
else
  ok "declaration unreachable -> the guard stands down (so assertion 0's first arm is load-bearing, not decoration)"
fi

r="$(drive "$(cat "$ROOT/.p_miss")")"
[ "$r" = block ] && ok "handoff requested, NO resume block -> BLOCK" \
                 || bad "handoff requested with no resume block was ALLOWED ($r) — the guard cannot fire"

r="$(drive "$(cat "$ROOT/.p_core4")")"
[ "$r" = allow ] && ok "resume block in CORE's mandated '----' form -> ALLOW" \
                 || bad "BLOCKED a handoff that follows steps/handoff.md step 4 verbatim ($r) — the check fires on COMPLIANCE"

r="$(drive "$(cat "$ROOT/.p_six")")"
[ "$r" = allow ] && ok "resume block with six hyphens -> ALLOW (delimiter is -{4,}, not a count)" \
                 || bad "six-hyphen delimiter rejected ($r) — this is what the consumer emits today"

r="$(drive "$(cat "$ROOT/.p_undelim")")"
[ "$r" = block ] && ok "'/ai-dlc resume' present but UNDELIMITED -> BLOCK (format, not substring)" \
                 || bad "an undelimited, non-copy-pasteable mention passed ($r) — presence is not format"

r="$(drive "$(cat "$ROOT/.p_noun")")"
[ "$r" = allow ] && ok "incidental NOUN mention of 'handoff guard' -> no fire" \
                 || bad "fired on a question ABOUT the guard ($r) — spurious block, this spammed a real operator"

# --- The teammate-sweep arm -------------------------------------------------------------
#
# THE DEFECT. A lead read a handoff request correctly and then improvised: one TaskStop, a
# snapshot edit, a touched pause flag, and by its own account afterwards "no full teammate
# sweep, no commit, no push attempt". The resume block was the only thing anything checked,
# so a handoff missing four of its five steps passed the guard. The successor session
# inherits a snapshot whose In-Flight Teammates rows still say `in-flight` for teammates
# that are gone — the one piece of state no later step can reconstruct.
#
# EVERY CASE BELOW DRIVES THE SAME TRANSCRIPT. `.p_sweep` is a fully compliant handoff turn,
# so the resume arm is satisfied in all three and the only thing that varies is the
# snapshot. A case that carried its own transcript could differ on the resume block and the
# verdict would not say which arm produced it.
SWEEP="$(cat "$ROOT/.p_sweep")"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_running")")"
[ "$r" = block ] && { ok "compliant resume block but a row still reads 'in-flight' -> BLOCK"; } \
                 || bad "a handoff whose teammate sweep was never recorded was ALLOWED ($r) — this is the s305 shape, and the successor inherits a snapshot that lies about what is running"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_running_note")")"
[ "$r" = block ] && ok "a running row carrying a trailing note -> BLOCK (leading token, not the whole cell)" \
                 || bad "a row reading 'in-flight, since <ts>' was ALLOWED ($r) — that is the form the reference consumer actually writes, and an equality test lets a handoff proceed with teammates still running"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_stopped")")"
[ "$r" = allow ] && ok "the same row rewritten to 'stopped' -> ALLOW (the arm accepts the state it demands)" \
                 || bad "BLOCKED a handoff that recorded its sweep exactly as steps/handoff.md step 1 mandates ($r) — the check fires on COMPLIANCE, which is worse than no check"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_nosection")")"
[ "$r" = allow ] && ok "snapshot with no In-Flight Teammates section -> ALLOW (route.md says it auto-heals)" \
                 || bad "BLOCKED a snapshot written before the In-Flight section existed ($r) — every pre-v0.50.0 snapshot would wedge at handoff"

# --- THE PIPELESS ROW SHAPE ---------------------------------------------------------
#
# Every case above seeds a row with a leading `|`, which is why the sweep arm's
# `/^[[:space:]]*\|/` gate could not fail: the reference consumer writes the BARE form
# and no seed here carried it. Measured on its live snapshot, this arm found 1 in-flight
# row where the relaxed form finds 5 — four live teammates invisible to the guard whose
# whole job is to stop a handoff while teammates are running.
#
# FOUR CELLS, AND THE PAIRING IS WHAT MAKES ANY OF THEM READABLE. A pipeless BLOCK on
# its own passes identically whether the guard reads the token or simply refuses every
# bare row it can now see; its ALLOW twin, one property away, is what separates those.
r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_running")")"
[ "$r" = block ] && { ok "PIPELESS row reading 'in-flight' -> BLOCK (the cell that was dead)"; } \
                 || bad "a PIPELESS 'in-flight' row was ALLOWED ($r) — this is the shape the reference consumer writes, and the handoff proceeds with teammates still running"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_stopped")")"
[ "$r" = allow ] && ok "PIPELESS row reading 'stopped' -> ALLOW (the relaxation reads the token, it does not refuse the shape)" \
                 || bad "BLOCKED a PIPELESS row that records its sweep exactly as steps/handoff.md step 1 mandates ($r) — the guard now fires on the bare SHAPE, and no edit to that row can satisfy it"

# THE PIPELESS HEADER IS NOT A TEAMMATE. Its own last cell is the literal word
# `status`, and a guard that scores it as a data row reads a teammate that does not exist.
r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_header")")"
[ "$r" = allow ] && ok "PIPELESS header with no data rows -> ALLOW (the header is never a teammate)" \
                 || bad "BLOCKED on a header row alone ($r) — an empty In-Flight table wedges every handoff, and there is no row to strike"

# THE MEASURED FALSE POSITIVE. A bare `/\|/` gate reads this prose line's last
# pipe-delimited field as a status cell, and that field is `in-flight`.
r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_prose")")"
[ "$r" = allow ] && { ok "prose ending '| in-flight' beside a swept row -> ALLOW (the header-width narrowing holds)"; } \
                 || bad "BLOCKED on a PROSE line carrying a pipe ($r) — that is the measured false positive of the bare-pipe form, and it wedges every handoff in the sprint with no row to fix"

# A STRAY `|` INSIDE A CELL OF A PIPED ROW MUST STILL BLOCK.
# THE CASE THAT KILLS THE MOST PLAUSIBLE WRONG FIX: applying the header-width test to
# every row instead of only to pipeless ones acquits this one, because the stray pipe
# splits it one field wide. That is a BLOCK the pre-fix arm already produced, so the
# uniform form is a regression rather than a simplification.
r="$(drive "$SWEEP" "$(cat "$ROOT/.s_straypipe")")"
[ "$r" = block ] && { ok "PIPED 'in-flight' row with a stray pipe inside a cell -> BLOCK (the width test did not leak onto piped rows)"; } \
                 || bad "a piped 'in-flight' row carrying a stray '|' was ALLOWED ($r) — the width test was applied uniformly and the relaxation LOST a block the pre-fix arm had"

# --- THE IN-FLIGHT ROW ARM ----------------------------------------------------------
#
# THE DEFECT. `steps/handoff.md` step 1 requires every dispatched teammate to be RECORDED
# in the snapshot's In-Flight Teammates table. The sweep arm above convicts a row that
# still reads `in-flight`; it is silent on a table with no rows at all, which is what a
# handoff that skipped step 1 entirely leaves behind. Measured on the reference consumer:
# 459 role-bound dispatches across sprints 307-311 and ZERO rows recorded over that span.
# Every one of those handoffs passed the sweep arm, correctly -- it can only convict a row
# somebody wrote.
#
# EACH CASE IS A WORLD, NOT A SNAPSHOT. The arm reads four files: the lead transcript
# (Agent/Task tool_use records), `spawn-ledger.jsonl`, the harness meta sidecars under
# `${TRANSCRIPT%.jsonl}/subagents/`, and `subagent-context.jsonl`. seed.sh builds each
# world with its own four, so a case cannot be handed another case's ledger.
#
# THE SCRUB IS WHY THESE ARE FILES AND NOT ENV. This fixture unsets every `AI_DLC_*`
# variable before driving anything (see the header). `AI_DLC_STATE_DIR` is one of them, so
# a world that relocated the ledgers by exporting it would be driving a hook that had
# forgotten the relocation -- the arm would read `_bmad-output/` and find nothing, and
# every case would ALLOW for a reason no assertion states. The worlds therefore write to
# the default `_bmad-output/` and the driver copies them in.
drive_world() { # drive_world <world-dir> [hook] -> "block" or "allow" (stderr: raw reason)
  local w="$1" hk="${2:-$HOOK}" out proj
  proj="$(mktemp -d)"; mkdir -p "$proj/_bmad-output/.driver"
  snap_from_body "$w/snapshot-body.md" > "$proj/_bmad-output/pipeline-snapshot.md"
  touch "$proj/_bmad-output/pipeline-paused.flag"
  cp "$w/_bmad-output/spawn-ledger.jsonl"     "$proj/_bmad-output/" 2>/dev/null || true
  cp "$w/_bmad-output/subagent-context.jsonl" "$proj/_bmad-output/" 2>/dev/null || true
  : > "$proj/_bmad-output/.driver/handoff"
  out="$(jq -nc --arg t "$w/lead.jsonl" --arg s "fx" '{transcript_path:$t,session_id:$s}' \
        | CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" \
          bash "$hk" 2>/dev/null)"
  rm -rf "$proj"
  # THE REASON GOES TO STDERR SO THE VERDICT CAN STAY ON STDOUT, and the redirection
  # ORDER is the whole trap: `2>/dev/null >&2` points stderr at /dev/null FIRST and then
  # duplicates stdout onto that same discarded descriptor, so the reason vanishes and
  # every text assertion below reads an empty file. Measured here — three assertions
  # failed against a hook whose message was correct. Capture into a variable, then write
  # it, rather than chaining redirections on one pipeline.
  local reason; reason="$(printf '%s' "$out" | jq -r '.reason // ""' 2>/dev/null)" || reason=""
  printf '%s\n' "$reason" >&2
  if printf '%s' "$out" | jq -e '.decision=="block"' >/dev/null 2>&1; then
    printf 'block'
  else
    printf 'allow'
  fi
}

# The world seeds carry only the In-Flight BODY; the surrounding snapshot is written
# here from the same seven-section shape seed.sh uses for the sweep cases, so a world
# cannot differ from a sweep case in anything but that body.
snap_from_body() {
  printf '# Pipeline Snapshot\n\n## Pipeline Position\ncurrent_step_file: implementation.md\n\n'
  printf '## Sprint Context\nsprint_id: 311\n\n## Recent Activity\n- gate 3 in progress\n\n'
  printf '## Open Items\n- none\n\n## Locked Decisions\n- none\n\n## In-Flight Teammates\n'
  cat "$1"
  printf '\n\n## Context Reminders\ncontext_reminders_sent: none\n'
}

W_OFF="$(cat "$ROOT/.w_offender")"

# (A) THE OFFENDER. A dispatch with a ledger row, a meta sidecar, no stop record, and an
#     EMPTY table -> BLOCK, and the message must NAME the id: a block that says only
#     "something is open" cannot be acted on, and this is the presence-shaped conjunct
#     that a hook emitting nothing fails by construction.
a_err="$(mktemp)"
r="$(drive_world "$W_OFF" 2>"$a_err")"
[ "$r" = block ] && ok "A: dispatch with no stop record + EMPTY In-Flight table -> BLOCK" \
                 || bad "A: the offender world was ALLOWED ($r) — a handoff leaves an empty table with a teammate whose fate no later step can reconstruct"
if grep -qF 'toolu_01FIXTUREoffender000000000' "$a_err"; then
  ok "A: the block message NAMES the open tool_use_id"
else
  bad "A: the block message does NOT name the open tool_use_id — the lead is told a row is missing and not which row to write"
fi
if grep -qF 'dev-escalated' "$a_err"; then
  ok "A: the block message carries the ledger name/role for the open id"
else
  bad "A: the block message carries no ledger name/role — the lead cannot fill the row's \`agent\` and \`role\` cells"
fi
# THE REMEDY IS THE ROW, NOT TaskStop, AND THAT IS A MEASUREMENT NOT A PREFERENCE. The
# one true positive on the consumer FINISHED cleanly (its tool_result carries no error)
# and wrote no stop record, so TaskStop can neither clear the state nor report anything.
# A message that sent the lead to TaskStop would send it to a call that does nothing.
if grep -qF 'TaskStop' "$a_err" && grep -qF 'Do NOT call' "$a_err"; then
  ok "A: the message tells the lead to WRITE the row and explicitly NOT to call TaskStop"
else
  bad "A: the message does not steer away from TaskStop — a missing stop record is not evidence the teammate is running, and TaskStop cannot clear a record that was never written"
fi
rm -f "$a_err"

# (B) THE TABLE CARRIES A MATCHING ROW -> ALLOW. One property from (A).
r="$(drive_world "$(cat "$ROOT/.w_tablerow")" 2>/dev/null)"
[ "$r" = allow ] && ok "B: the same dispatch RECORDED in the table -> ALLOW" \
                 || bad "B: BLOCKED a handoff that wrote the row step 1 mandates ($r) — the arm fires on COMPLIANCE"

# (C) THE STOP RECORD EXISTS -> ALLOW. The teammate returned and the probe wrote its row,
#     so there is nothing outstanding and the empty table is correct.
r="$(drive_world "$(cat "$ROOT/.w_ctxrow")" 2>/dev/null)"
[ "$r" = allow ] && ok "C: the dispatch HAS a SubagentStop record -> ALLOW (empty table is correct)" \
                 || bad "C: BLOCKED over a teammate that already returned ($r) — the stop-record difference is not being taken, and every completed dispatch would wedge a handoff"

# (D) NEVER SPAWNED -> ALLOW. The guard writes the ledger row at PreToolUse, before
#     anything can deny the call, so a Rule-29 denial and an agent type that does not
#     exist both leave a row with no agent behind it. Measured: of the naive join's 3
#     open ids on the consumer, 2 were Rule-29 denials and the meta narrowing removes
#     exactly those, leaving 1.
r="$(drive_world "$(cat "$ROOT/.w_nospawn")" 2>/dev/null)"
[ "$r" = allow ] && ok "D: ledger row with NO meta sidecar (never spawned) -> ALLOW" \
                 || bad "D: BLOCKED over a dispatch that never spawned ($r) — a Rule-29 denial would wedge the next handoff over a teammate that does not exist"

# (E) A LIVE NAMED TEAMMATE -> ALLOW. THE STATED BLINDNESS, asserted rather than left
#     implicit. A named dispatch routes to the in-process teammate runner, whose meta
#     carries `teamName` and no `toolUseId`; partitioned over the harness corpus the two
#     keys never co-occur (330 toolUseId-only, 672 teamName-only, 0 both, 0 neither). A
#     name-keyed join was built and refuted — 115 false blocks over 303 rows. This cell
#     flips the day somebody adds one, which is the point of asserting it.
r="$(drive_world "$(cat "$ROOT/.w_namedteam")" 2>/dev/null)"
[ "$r" = allow ] && ok "E: live NAMED teammate (no tool_use_id, meta has teamName) -> ALLOW (the stated blindness)" \
                 || bad "E: BLOCKED on a named in-process teammate ($r) — that class carries no join key at all, so a block there is keyed on something the arm's header says it does not read"

# (F) NO ARM CONVICTS WITH NO jq. A PATH stub that exits 127 for every invocation, which is
#     what a consumer without jq looks like from inside the hook. No arm can read its input,
#     so no arm's text may appear -- an arm that convicted here would be reading an absence as
#     a finding. Since BL-700 the world's paused Stop with step 4's driver signal on disk gets
#     the ONE constant fail-closed block instead of a silent allow, so the assertion is that any
#     block text is that constant and names no arm.
JQSTUB="$ROOT/nojq"; mkdir -p "$JQSTUB"
printf '#!/bin/bash\nexit 127\n' > "$JQSTUB/jq"; chmod +x "$JQSTUB/jq"
f_out="$(jq -nc --arg t "$W_OFF/lead.jsonl" --arg s "fx" '{transcript_path:$t,session_id:$s}')"
f_proj="$(mktemp -d)"; mkdir -p "$f_proj/_bmad-output/.driver"
snap_from_body "$W_OFF/snapshot-body.md" > "$f_proj/_bmad-output/pipeline-snapshot.md"
touch "$f_proj/_bmad-output/pipeline-paused.flag"
cp "$W_OFF/_bmad-output/"*.jsonl "$f_proj/_bmad-output/" 2>/dev/null || true
: > "$f_proj/_bmad-output/.driver/handoff"
f_res="$(printf '%s' "$f_out" | PATH="$JQSTUB:$PATH" CLAUDE_PROJECT_DIR="$f_proj" \
         AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$HOOK" 2>/dev/null)"
rm -rf "$f_proj"
# A HERE-STRING, NOT A PIPE INTO `grep -q`. `grep -q` leaves at its first match while the
# writer is still pushing, and under this file's `pipefail` the pipeline then answers with
# the writer's EPIPE and reports NOT-FOUND on input that contains the pattern. I54b of
# validate-enforcement-map.sh fails the push on the piped form.
if [ -z "$f_res" ] || ! grep -qF 'HANDOFF GUARD' <<<"$f_res"; then
  ok "F: jq shadowed by a stub exiting 127 -> no block text"
elif grep -qF 'HANDOFF GUARD (fail-closed)' <<<"$f_res" && grep -qF 'jq is not on PATH' <<<"$f_res" \
     && ! grep -qF 'In-Flight' <<<"$f_res"; then
  ok "F: jq shadowed by a stub exiting 127 -> only the constant fail-closed block (BL-700), naming no arm"
else
  bad "F: the guard emitted an ARM's block text with jq unavailable — it is convicting on an absence it cannot read"
fi
# CONTROL for F, and it is what makes the silence above readable: the stub really does
# shadow jq. Without it "no output" is equally consistent with the stub never being on
# PATH and the hook running normally on a world that happens to allow.
if PATH="$JQSTUB:$PATH" jq --version >/dev/null 2>&1; then
  bad "F CONTROL: the jq stub did NOT shadow the real jq — case F proved nothing about the fail-open path"
else
  ok "F control: the stub genuinely shadows jq (so F's silence is the fail-open path)"
fi

# (G) THE TRANSCRIPT PATH NAMES NO FILE -> fail open. Built from the offender world with
#     its transcript removed, so every other input still convicts.
G_W="$(cat "$ROOT/.w_notranscript")"
rm -f "$G_W/lead.jsonl"
#     The world is paused with step 4's driver signal fresh, so since BL-700 that signal ENTERS
#     Check 0 with no transcript and the In-Flight arm is reached; every disk arm is satisfied
#     (no git repo, a status-free table, the touch after the snapshot), so the only arm that
#     could block is the one under test, and it must not convict on a dispatch set it never read.
r="$(drive_world "$G_W" 2>"$ROOT/.g_reason")"
g_reason="$(cat "$ROOT/.g_reason" 2>/dev/null)"
if [ "$r" = allow ]; then
  ok "G: transcript path names no file -> ALLOW (the In-Flight arm, reached through the driver-signal entry, does not convict)"
else
  bad "G: BLOCKED with no transcript to read ($r): $(printf '%s' "$g_reason" | head -c 100) — the arm is producing a verdict from a set it never derived"
fi

# (H) NO META DIRECTORY beside the transcript -> fail open. A harness build that writes
#     no sidecars, or a session predating them. Without the narrowing this world is the
#     offender, so an arm that skipped the directory check would BLOCK here.
r="$(drive_world "$(cat "$ROOT/.w_nometadir")" 2>/dev/null)"
[ "$r" = allow ] && ok "H: no subagents/ meta directory -> ALLOW (fail-open)" \
                 || bad "H: BLOCKED with no meta sidecars on disk ($r) — a consumer whose harness writes none would wedge at every handoff"

# (I) ONE UNRELATED ROW IN THE TABLE -> ALLOW. THE STATED ACQUITTAL. The check is a
#     PRESENCE test, not an identity join, and one row from any dispatch acquits the
#     turn. The reason is coverage: over 647 tracked snapshot revisions on the reference
#     consumer, 2 of 115 distinct In-Flight first cells resolve to a spawn meta at all
#     and NEITHER reaches a ledger row, so an identity join false-positives on the whole
#     historical population. Asserted so the acquittal is visible rather than latent.
r="$(drive_world "$(cat "$ROOT/.w_unrelatedrow")" 2>/dev/null)"
[ "$r" = allow ] && ok "I: table carries one UNRELATED row -> ALLOW (the stated acquittal: presence, not identity)" \
                 || bad "I: BLOCKED with a row present in the table ($r) — the arm has become an identity join, which the header says it is not and which false-positives on 113 of 115 historical rows"

# --- NESTED DISPATCH: ONE LEVEL (cells N1-N3) ------------------------------
#
# A round-dispatcher subagent spawns the members, so a member's tool_use id is in the
# dispatcher's transcript and never the lead's. Without the one-level extension a handoff
# mid-round reads 0 open teammates. N1 is the offender, N2 and N3 are its twins one
# property apart (member returned; member's parent not dispatched by the lead).
r="$(drive_world "$(cat "$ROOT/.w_nested")" 2>/dev/null)"
[ "$r" = block ] && ok "N1: a member spawned by the lead's role-less dispatcher, no stop row -> BLOCK (counted open through parent_agent_id)" \
                 || bad "N1: ALLOWED ($r) — a handoff mid-round reads 0 open teammates because the dispatcher's members are not in the lead transcript"
r="$(drive_world "$(cat "$ROOT/.w_nestedstop")" 2>/dev/null)"
[ "$r" = allow ] && ok "N2: the same member with a stop row -> ALLOW" \
                 || bad "N2: BLOCKED ($r) with the member's stop row present"
r="$(drive_world "$(cat "$ROOT/.w_nestedforeign")" 2>/dev/null)"
[ "$r" = allow ] && ok "N3: a member whose parent the lead did not dispatch -> ALLOW (not counted)" \
                 || bad "N3: BLOCKED ($r) — a member of an undispatched parent was counted"

# --- THE LIVE-BEAT DEFERRAL ---------------------------------------------------------
#
# THE DEFECT. `steps/handoff.md` step 1 ends the turn on ONE backgrounded
# `wait-for-deliverable.sh` beat before any TaskStop. That Stop reaches Check 0 with every arm
# unsatisfied by construction -- here, a row still reading `in-flight` -- and the block text
# tells the lead to stop every teammate, which is the TaskStop the beat exists to avoid. Check 0
# now DEFERS while `.beat-inflight` holds a future epoch, the same lease Check 2b reads.
#
# EACH WORLD IS ONE PROJECT DIR THE ARM KEEPS, because the arms read what the hook left on disk
# -- the log, the stall-state file, the arming record, the completion stamp -- and `drive`
# removes its project. The stall-state file is SEEDED as three lines so a deferral that writes
# the counter is caught by `cmp`, not inferred from a later count.
LEASE_STATE_SEED="$ROOT/lease-state-seed.txt"
printf '%s\n%s\n%s\n' 1000 1 "fx:none" > "$LEASE_STATE_SEED"
lease_world() { # lease_world <lease|NONE> <snapshot-file> <flag:up|down> -> project dir
  local p; p="$(mktemp -d "$ROOT/lease-XXXXXX")"; mkdir -p "$p/_bmad-output/.driver"
  cp "$2" "$p/_bmad-output/pipeline-snapshot.md"
  [ "$3" = up ] && touch "$p/_bmad-output/pipeline-paused.flag"
  : > "$p/_bmad-output/.driver/handoff"
  cp "$LEASE_STATE_SEED" "$p/_bmad-output/handoff-guard-state.txt"
  [ "$1" = NONE ] || printf '%s' "$1" > "$p/_bmad-output/.beat-inflight"
  printf '%s' "$p"
}
lease_drive() { # lease_drive <proj> <transcript> [hook] -> raw hook stdout
  jq -nc --arg t "$2" --arg s "fx" '{transcript_path:$t,session_id:$s}' \
    | CLAUDE_PROJECT_DIR="$1" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "${3:-$HOOK}" 2>/dev/null
}
LEASE_LOG='_bmad-output/pipeline-continuation-log.md'
lease_ev()  { grep -c -- "^## .* -- $2\$" "$1/$LEASE_LOG" 2>/dev/null || true; }
is_guard()  { case "$1" in *'HANDOFF GUARD'*) return 0 ;; esac; return 1; }
is_block()  { printf '%s' "$1" | jq -e '.decision=="block"' >/dev/null 2>&1; }
live_lease()    { printf '%s' 9999999999; }
expired_lease() { printf '%s' 1; }

# Each scorer drives one world through the given hook and returns 0 when the arm's property
# holds. LA_MSG is evidence.
#
# TWO LEASE FORMS. `wait-for-deliverable.sh` writes the marker as `<epoch> <pid>`, one holder,
# and the hook's `beat_lease_live` reads its first field. A1-A6 seed the BARE `<epoch>` a beat
# from before that format writes, and stay as the backward-compatibility proof: a consumer
# mid-pull runs the new hook against an old beat's marker. A1p/A2p seed the producer's form.
la_a1() { la_defer_on "$(live_lease)" "${1:-}"; }
la_defer_on() { # la_defer_on <lease> [hook] -> live lease + in-flight row -> ALLOW, token, counter byte-identical, record kept
  local p o; p="$(lease_world "$1" "$(cat "$ROOT/.s_running")" up)"; LA_P="$p"
  o="$(lease_drive "$p" "$SWEEP" "${2:-}")"
  LA_MSG="[block=$(is_block "$o" && echo y || echo n) deferred=$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT) state=$(cmp -s "$LEASE_STATE_SEED" "$p/_bmad-output/handoff-guard-state.txt" && echo same || echo changed) armed=$([ -f "$p/_bmad-output/.handoff-guard-armed" ] && echo y || echo n)]"
  ! is_block "$o" && [ "$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT)" = 1 ] \
    && cmp -s "$LEASE_STATE_SEED" "$p/_bmad-output/handoff-guard-state.txt" \
    && [ -f "$p/_bmad-output/.handoff-guard-armed" ]
}
la_block_on() { # la_block_on <lease> [hook] -> 0 when the guard BLOCKS with its own reason, undeferred
  local p o; p="$(lease_world "$1" "$(cat "$ROOT/.s_running")" up)"
  o="$(lease_drive "$p" "$SWEEP" "${2:-}")"
  LA_MSG="[block=$(is_block "$o" && echo y || echo n) guard=$(is_guard "$o" && echo y || echo n) deferred=$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT) logged=$(lease_ev "$p" 'HANDOFF_GUARD_BLOCK ([0-9]*/[0-9]*)')]"
  is_block "$o" && is_guard "$o" && [ "$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT)" = 0 ] \
    && [ "$(lease_ev "$p" 'HANDOFF_GUARD_BLOCK ([0-9]*/[0-9]*)')" = 1 ]
}
la_a2() { la_block_on "$(expired_lease)" "${1:-}"; }
# A1p -- THE PRODUCER'S FORM, live: it defers exactly as A1 does, and the logged row names the
# EPOCH alone. A row carrying "N 12345" would put a pid where a reader expects a deadline.
la_a1p() {
  local row
  la_defer_on "$(live_lease) 12345" "${1:-}" || return 1
  row="$(sed -n 's/^- Wait-beat lease live until epoch //p' "$LA_P/$LEASE_LOG" 2>/dev/null)"
  LA_MSG="$LA_MSG [row=$row]"
  grep -qE '^[0-9]+ \(now [0-9]+\); guard deferred, not cleared$' <<< "$row"
}
# A2p -- THE PRODUCER'S FORM, expired: blocks exactly as A2 does.
la_a2p() { la_block_on "$(expired_lease) 12345" "${1:-}"; }
la_a3() { la_block_on "not-an-epoch" "${1:-}"; }
# THE FLAG-DOWN CELLS DRIVE A LEAD TRANSCRIPT: `.p_noun` with the harness's typed `/ai-dlc` record
# in front. Check 2a lets a session with no ai-dlc marker stop before Check 2b or the default block,
# so the bare `.p_noun` would reach neither the lease allow nor Rule 3's block it is controlled by.
lead_noun() { # lead_noun <proj> -> path of `.p_noun` prefixed with a typed /ai-dlc record
  local t="$1/lead-noun.jsonl"
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"<command-message>ai-dlc</command-message>\n<command-name>/ai-dlc</command-name>"}}' > "$t"
  cat "$(cat "$ROOT/.p_noun")" >> "$t"; printf '%s' "$t"
}
la_a4() { # NO handoff requested, flag DOWN, live lease -> Check 2b's allow, no guard row at all
  local p o; p="$(lease_world "$(live_lease)" "$(cat "$ROOT/.s_running")" down)"
  o="$(lease_drive "$p" "$(lead_noun "$p")" "${1:-}")"
  LA_MSG="[block=$(is_block "$o" && echo y || echo n) live=$(lease_ev "$p" ALLOWED_BY_LIVE_BEAT) deferred=$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT)]"
  ! is_block "$o" && [ "$(lease_ev "$p" ALLOWED_BY_LIVE_BEAT)" = 1 ] \
    && [ "$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT)" = 0 ]
}
la_a4_ctl() { # the same world with NO lease -> Rule 3's ordinary block, so A4's allow is the lease's
  local p o; p="$(lease_world NONE "$(cat "$ROOT/.s_running")" down)"
  o="$(lease_drive "$p" "$(lead_noun "$p")" "${1:-}")"
  is_block "$o" && ! is_guard "$o"
}
# A5 -- STICKY ARMING SURVIVES THE DEFERRAL. No `.handoff-in-progress`, no `HANDOFF POINT` line and
# no session log row, so the SECOND Stop has no key at all: the transcript's last user record is
# the background task's completion notice, which is not a request. Only the arming record the
# first Stop wrote can arm it. The transcript is the request turn plus that notice, appended.
la_a5() {
  local p t o1 o2
  p="$(lease_world "$(live_lease)" "$(cat "$ROOT/.s_running")" up)"
  t="$p/lead.jsonl"; cp "$SWEEP" "$t"
  o1="$(lease_drive "$p" "$t" "${1:-}")"
  jq -nc '{message:{role:"user",content:"<task-notification><task-id>bwfd01</task-id><status>completed</status><summary>Background command \"scripts/ai-dlc/wait-for-deliverable.sh docs/reviews/s305-qa.md\" completed (exit code 0)</summary></task-notification>"}}' >> "$t"
  expired_lease > "$p/_bmad-output/.beat-inflight"
  o2="$(lease_drive "$p" "$t" "${1:-}")"
  LA_MSG="[stop1 block=$(is_block "$o1" && echo y || echo n) deferred=$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT) | stop2 block=$(is_block "$o2" && echo y || echo n) guard=$(is_guard "$o2" && echo y || echo n)]"
  ! is_block "$o1" && [ "$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT)" = 1 ] \
    && is_block "$o2" && is_guard "$o2"
}
la_a5_premise() { # the notice alone, no arming record, is NOT a request: the same Stop must ALLOW
  local p t o
  p="$(lease_world "$(expired_lease)" "$(cat "$ROOT/.s_running")" up)"
  t="$p/lead.jsonl"; cp "$SWEEP" "$t"
  jq -nc '{message:{role:"user",content:"<task-notification><task-id>bwfd01</task-id><status>completed</status><summary>Background command \"scripts/ai-dlc/wait-for-deliverable.sh docs/reviews/s305-qa.md\" completed (exit code 0)</summary></task-notification>"}}' >> "$t"
  o="$(lease_drive "$p" "$t")"
  ! is_block "$o"
}
# A6 -- EVERY ARM SATISFIED with a live lease: the completion branch, never the deferral.
la_a6() {
  local p o; p="$(lease_world "$(live_lease)" "$(cat "$ROOT/.s_stopped")" up)"
  : > "$p/_bmad-output/.driver/handoff"
  printf 'fx\n' > "$p/_bmad-output/.handoff-guard-armed"
  o="$(lease_drive "$p" "$SWEEP" "${1:-}")"
  LA_MSG="[block=$(is_block "$o" && echo y || echo n) stamp=$([ -f "$p/_bmad-output/.handoff-complete" ] && echo y || echo n) armed=$([ -f "$p/_bmad-output/.handoff-guard-armed" ] && echo y || echo n) deferred=$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT)]"
  ! is_block "$o" && [ -f "$p/_bmad-output/.handoff-complete" ] \
    && [ ! -f "$p/_bmad-output/.handoff-guard-armed" ] \
    && [ "$(lease_ev "$p" HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT)" = 0 ]
}

la_a1 && { ok "A1: handoff with an 'in-flight' row and a LIVE beat lease -> ALLOW, HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT logged, stall state byte-identical, arming record kept"; } \
      || bad "A1: the step-1 beat's Stop was not deferred cleanly $LA_MSG — the lead is told to TaskStop the teammates the beat is waiting on"
la_a2 && { ok "A2: the same world with an EXPIRED lease -> BLOCK with the HANDOFF GUARD reason and a HANDOFF_GUARD_BLOCK row (keyed on the lease, not the file)"; } \
      || bad "A2: an expired lease did not block $LA_MSG — a dead beat's marker defers the guard forever"
la_a1p && { ok "A1p: the producer's '<epoch> <pid>' lease, live -> deferred like A1, and the logged row names the epoch alone"; } \
       || bad "A1p: a live '<epoch> <pid>' lease was not deferred cleanly, or its row carries more than the epoch $LA_MSG — the hook does not read the marker wait-for-deliverable.sh writes"
la_a2p && ok "A2p: the producer's '<epoch> <pid>' lease, expired -> BLOCK like A2" \
       || bad "A2p: an expired '<epoch> <pid>' lease did not block $LA_MSG — a dead beat's marker defers the guard"
la_a3 && { ok "A3: the same world with a NON-INTEGER lease -> BLOCK with the HANDOFF GUARD reason"; } \
      || bad "A3: a garbage lease did not block $LA_MSG — the deferral reads the file's existence, not its epoch"
la_a4 && ok "A4: NO handoff requested, flag down, live lease -> ALLOWED_BY_LIVE_BEAT and no deferral row (the change is confined to the handoff path)" \
      || bad "A4: a non-handoff Stop with a live lease is not Check 2b's allow $LA_MSG"
la_a4_ctl && ok "A4 control: the same world with NO lease -> Rule 3's ordinary block, so A4's allow is the lease" \
          || bad "A4 CONTROL BROKEN: the no-lease world did not take Rule 3's block — A4's allow proves nothing about the lease"
la_a5_premise && ok "A5 premise: the task-notification turn alone, no arming record, ALLOWS — it is not a request, so A5's second block can only be the sticky record" \
              || bad "A5 PREMISE BROKEN: the task-notification turn is read as a handoff request on its own, so A5 cannot see the arming record"
la_a5 && { ok "A5: deferred Stop, then the beat's notice and an expired lease -> the next Stop BLOCKS with the guard (sticky arming survived the deferral)"; } \
      || bad "A5: the guard did not re-fire after the deferral $LA_MSG — the deferral disarmed it and the handoff escapes"
la_a6 && { ok "A6: every arm satisfied with a live lease -> stamped complete, arming record cleared, no deferral row (the deferral sits inside the unsatisfied branch)"; } \
      || bad "A6: a satisfied handoff with a live lease was not stamped complete $LA_MSG — the deferral sits before the arm test"

HOOK_DIR_L="$(cd "$(dirname "$HOOK")" && pwd)"
[ -f "$HOOK_DIR_L/ai-dlc-handoff-pending.sh" ] && echo "HERMETIC-CONSUMED $HOOK_DIR_L/ai-dlc-handoff-pending.sh"

# --- Beat-before-stop arm -----------------------------------------------------------
#
# THE DEFECT THIS ARM EXISTS FOR. Measured on the reference consumer: an adversary pass
# was dispatched, the operator typed `handoff`, step 1 called `TaskStop` on every
# in-flight teammate with no join first, and the resumed session dispatched the same
# pass again from scratch — 38 minutes of opus time for a pass that would have landed
# in under one wait beat. `steps/handoff.md` step 1 and its copy in `_gate-procedures.md`
# "Auto-handoff evaluation" step 1 now run ONE `wait-for-deliverable.sh` beat over every
# in-flight row before calling `TaskStop`, and the two copies must carry the SAME clause
# — a copy that drifts is the defect class this whole fixture's header describes.
#
# TOKENS. `wait-for-deliverable.sh` names the beat script; `still absent after the beat`
# is the exact phrase marking which rows still get stopped. Both are asserted in BOTH
# files so a future edit to either cannot silently drop the join or reword it out of
# step with its sibling.
HANDOFF_MD="$(pick "$HERE/../../skills/ai-dlc/steps/handoff.md" \
                    "$HERE/../../../core/skills/ai-dlc/steps/handoff.md" \
                    "$HERE/../../../.claude/skills/ai-dlc/steps/handoff.md")"
GATE_PROC_MD="$(pick "$HERE/../../skills/ai-dlc/steps/_gate-procedures.md" \
                      "$HERE/../../../core/skills/ai-dlc/steps/_gate-procedures.md" \
                      "$HERE/../../../.claude/skills/ai-dlc/steps/_gate-procedures.md")"
if [ -z "$HANDOFF_MD" ] || [ -z "$GATE_PROC_MD" ]; then
  bad "FIXTURE BROKEN — could not locate handoff.md and/or _gate-procedures.md in either layout"
else
  # Extract step 1 of a "Stop all in-flight teammates" procedure: from the opening bold
  # line to the line before the next numbered "2. " step. Two occurrences can exist in
  # one file (handoff.md's own procedure, and a second copy if one is ever pasted in);
  # this greps every such block in the file, which is a superset of the single block
  # each of today's two files carries and still correct if that ever changes.
  extract_step1() {
    awk '
      /^1\. \*\*Stop all in-flight teammates first\.\*\*/ { f=1 }
      f { print }
      f && /^2\. / && !/^1\. / { exit }
    ' "$1"
  }
  check_beat_clause() { # check_beat_clause <label> <text>
    local label="$1" text="$2"
    if grep -qF 'wait-for-deliverable.sh' <<<"$text" \
       && grep -qF 'still absent after the beat' <<<"$text"; then
      ok "$label carries the beat-before-stop clause"
    else
      bad "$label is missing 'wait-for-deliverable.sh' and/or 'still absent after the beat' in its step 1 — the two-file clause has drifted or been dropped"
    fi
  }

  # THE SELF-PROBE, run BEFORE the corpus checks below so a check that cannot fire is
  # not mistaken for one that passed: a scratch copy of handoff.md with the clause
  # deleted (reverted to the pre-fix wording) must FAIL the same assertion. Built as a
  # copy per fixture-mutants.md, guarded by cmp -s.
  DECOY="$ROOT/handoff-nobeat.md"
  awk '
    /^1\. \*\*Stop all in-flight teammates first\.\*\*/ {
      print "1. **Stop all in-flight teammates first.** Call `TaskStop` on"
      print "   every `in_progress` task. Halt any Agent-spawned teammate not"
      print "   bound to a task. Wait until every teammate has returned before"
      print "   proceeding. Record stopped teammates and in-flight artifacts"
      print "   in the snapshot'"'"'s Open Items in Step 3, and set each stopped"
      print "   teammate'"'"'s **In-Flight Teammates** row `status` to `stopped`."
      skip=1
      next
    }
    skip && /^2\. / { skip=0 }
    skip { next }
    { print }
  ' "$HANDOFF_MD" > "$DECOY"
  if cmp -s "$HANDOFF_MD" "$DECOY"; then
    bad "FIXTURE STALE: the decoy rewrite produced a byte-identical copy of handoff.md — the self-probe cannot discriminate anything"
  else
    decoy_step1="$(extract_step1 "$DECOY")"
    if grep -qF 'wait-for-deliverable.sh' <<<"$decoy_step1" \
       && grep -qF 'still absent after the beat' <<<"$decoy_step1"; then
      bad "SELF-PROBE FAILED: a decoy with the beat clause deleted still matched the assertion — it cannot discriminate, so the two ok's above are not evidence"
    else
      ok "self-probe: a decoy with the beat clause removed correctly FAILS the assertion"
    fi
  fi

  # Only now, with the self-probe having shown the assertion can fail, run it on the
  # real corpus.
  h_step1="$(extract_step1 "$HANDOFF_MD")"
  g_step1="$(extract_step1 "$GATE_PROC_MD")"
  check_beat_clause "handoff.md step 1" "$h_step1"
  check_beat_clause "_gate-procedures.md step 1" "$g_step1"
fi

# --- Step-5 marker-clear arm --------------------------------------------------------
#
# THE DEFECT THIS ARM EXISTS FOR. `handoff.md` step 5 touches the pause flag AND clears the
# entry marker `_bmad-output/.handoff-in-progress`; its auto-handoff twin in
# `_gate-procedures.md` touched the flag and never cleared the marker (measured: the file
# named `handoff-in-progress` 0 times against 1 for `pipeline-paused.flag`). An interrupted
# manual handoff leaves the marker behind, a later auto-handoff then ends with it present,
# and Check 0's marker arm blocks that stop.
#
# THE ASSERTION IS A SPAN, KEYED ON THE STEP-5 EMISSION LINE. Both tokens must sit inside the
# step whose line opens `5. Create the pause flag`, ending at the next column-0 line. A
# whole-file grep would be satisfied by the marker being named anywhere -- this comment, a
# hook pointer, step 4 -- and that is not the step that finishes the handoff. The pause flag
# is the span's positive control: a span that extracted nothing cannot carry it.
step5_span() { # step5_span <file> [<section heading regex>] -> the step-5 block
  awk -v sec="${2:-}" '
    sec != "" && /^## / { insec = ($0 ~ sec) }
    sec != "" && !insec { next }
    /^5\. Create the pause flag/ { f=1; print; next }
    f && /^[^ ]/ { exit }
    f { print }
  ' "$1"
}
check_step5() { # check_step5 <label> <span text> -> 0 iff both tokens are in the span
  grep -qF 'touch _bmad-output/pipeline-paused.flag' <<<"$2" \
    && grep -qF 'rm -f _bmad-output/.handoff-in-progress' <<<"$2"
}
if [ -z "${HANDOFF_MD:-}" ] || [ -z "${GATE_PROC_MD:-}" ]; then
  bad "FIXTURE BROKEN — handoff.md/_gate-procedures.md unresolved, so the step-5 marker-clear arm asserted nothing"
else
  S5W="$(mktemp -d)"
  AUTO_SEC='^## Auto-handoff evaluation'
  # SELF-PROBE, offender: the pre-fix text, rebuilt from the subject by deleting the clearing
  # line, must FAIL.
  S5_OFF="$S5W/gp-nomarker.md"
  grep -vF 'rm -f _bmad-output/.handoff-in-progress' "$GATE_PROC_MD" > "$S5_OFF"
  # SELF-PROBE, near-miss: the clearing command is still in the file, moved OUT of step 5 to
  # the paragraph after the procedure. A whole-file grep passes it; the span must not.
  S5_NEAR="$S5W/gp-moved.md"
  awk '
    /rm -f _bmad-output\/\.handoff-in-progress/ { next }
    /^A FIRE outcome does not return control/ { print "Afterwards run `rm -f _bmad-output/.handoff-in-progress`." ; print "" }
    { print }
  ' "$GATE_PROC_MD" > "$S5_NEAR"
  if cmp -s "$GATE_PROC_MD" "$S5_OFF" || cmp -s "$GATE_PROC_MD" "$S5_NEAR"; then
    bad "FIXTURE STALE: a step-5 decoy is byte-identical to _gate-procedures.md — the clearing line is gone from the subject or the near-miss anchor moved, and the self-probe cannot discriminate"
  elif ! grep -qF 'rm -f _bmad-output/.handoff-in-progress' "$S5_NEAR"; then
    bad "FIXTURE STALE: the near-miss decoy lost the clearing command entirely, so it probes the offender twice rather than the span"
  else
    s5_off="$(step5_span "$S5_OFF" "$AUTO_SEC")"
    s5_near="$(step5_span "$S5_NEAR" "$AUTO_SEC")"
    if ! grep -qF 'touch _bmad-output/pipeline-paused.flag' <<<"$s5_off"; then
      bad "SELF-PROBE BROKEN: the offender decoy's step-5 span does not carry the pause flag — the extractor found no step 5, so its failure below would be the span's, not the marker's"
    elif check_step5 x "$s5_off"; then
      bad "SELF-PROBE FAILED: a step 5 with no marker clear still passed — the arm cannot fire"
    elif check_step5 x "$s5_near"; then
      bad "SELF-PROBE FAILED: a marker clear moved OUTSIDE step 5 still passed — the arm is a whole-file grep, not a span"
    else
      ok "self-probe: step 5 with the marker clear removed FAILS, and with it moved out of step 5 also FAILS"
    fi
  fi
  g_s5="$(step5_span "$GATE_PROC_MD" "$AUTO_SEC")"
  h_s5="$(step5_span "$HANDOFF_MD")"
  if check_step5 x "$g_s5"; then
    ok "_gate-procedures.md auto-handoff step 5 touches the pause flag AND clears .handoff-in-progress, as handoff.md step 5 does"
  else
    bad "_gate-procedures.md auto-handoff step 5 does not both touch pipeline-paused.flag and rm -f _bmad-output/.handoff-in-progress — a marker left by an interrupted manual handoff survives the auto-handoff and Check 0 blocks the stop on it"
  fi
  if check_step5 x "$h_s5"; then
    ok "handoff.md step 5 touches the pause flag AND clears .handoff-in-progress"
  else
    bad "handoff.md step 5 no longer both touches pipeline-paused.flag and clears .handoff-in-progress — the canonical copy the auto-handoff is spelled from has drifted"
  fi
  rm -rf "$S5W"
fi

# --- Beat-is-backgrounded arms ------------------------------------------------------
#
# THE DEFECT THESE ARMS EXIST FOR. The `## Bounded-join beat` section of
# `_gate-procedures.md` prescribes the call form, both exit codes, why a waiting beat
# exits 0, the mtime rule, `--since`, wave batching and four named prohibitions — and
# never said the beat is BACKGROUNDED. Measured in one invocation over the two slices
# before the fix: the Gate-adjudication dispatch slice carried `run_in_background` once,
# the Bounded-join beat slice zero times.
#
# A FOREGROUND BEAT IS NOT A SLOW BEAT, IT IS A DEAD ONE. `ai-dlc-continue.sh` enumerates
# four ways to believe you have a beat and not have one, and names this as the second: a
# foreground call's exit trap clears the marker before the turn ends, so the join the lead
# believes is armed is not, and the turn-end hook reports no live wait over a teammate that
# has not delivered. `wait-for-deliverable.sh` states the premise the section dropped.
# The section calls itself the ONLY sanctioned way to wait for a teammate and three sites
# delegate to it BY NAME, so the duty is sited here rather than at any one caller.
#
# WHY THE ANCHOR IS THE CALL FORM AND NOT THE BARE PARAMETER NAME. The bare token
# `run_in_background` in the slice is reachable by a sentence FORBIDDING backgrounding —
# measured, a seeded "Never pass `run_in_background: true` to this beat" scores a bare-token
# anchor CLOSED while asserting the opposite of the fix. Arm `beat-bg-polarity` convicts
# that shape on its own, so a token-presence pass cannot be earned by a prohibition.
#
# A PROSE-ONLY SPELLING SCORES AS NOT-FIXED, AND THAT IS A DELIBERATE CHOICE. A correct
# statement in the section's own register — "the beat is ALWAYS BACKGROUNDED" — carries the
# property and not the token, and these arms report it STILL-LIVE. The alternative anchor,
# keyed on `backgrounded`, false-CLOSES: that word already appears once in the slice at tip
# ("a nonzero exit from a backgrounded command"), so it would pass against the pre-fix file.
# The token is therefore mandated, the neighbouring dispatch site already spells it that
# way, and this comment is here so a future author reading a red arm over competent prose
# knows it is a choice rather than an oversight.
#
# THE SLICE LENGTH IS ASSERTED because the slicer terminates on a heading, and any edit that
# removes or demotes the NEXT heading grows the slice until it reads the neighbour's call
# form as the beat's own. Measured on copies: demoting the neighbour to setext grows the
# beat slice from 46 lines to 93 and the subject arm then reads a token from the neighbour.
# Derived with THIS slicer on the subject at tip: 46 lines. Band max 60.
BEAT_BAND_MAX=60
# BEGIN bg-scoring (extracted by BL-830's verify receipt; keep self-contained)
bg_cF() { local n; n="$(grep -cF -- "$1" <<<"$2")" || n=0; printf '%s' "$n"; }
bg_cE() { local n; n="$(grep -cE -- "$1" <<<"$2")" || n=0; printf '%s' "$n"; }
# Both slicers key on the heading TEXT at any level and terminate on the next heading at
# `###` or shallower. Keying the CONTROL on text rather than on `^## ` is deliberate: an
# ordinary prose demote of the neighbouring heading is not this work, and reporting it as a
# dead control would spend the one signal that separates a restructure from a live defect.
beat_slice() { awk '/^#+ Bounded-join beat/{f=1;print;next} f&&/^#{1,3} /{exit} f{print}' "$1"; }
disp_slice() { awk '/^#+ Gate-adjudication dispatch/{f=1;print;next} f&&/^#{1,3} /{exit} f{print}' "$1"; }

# score_bg <file> -> "<beat-lines> <ctl> <subj> <proh>"
score_bg() {
  local f="$1" b d bl ctl subj proh
  b="$(beat_slice "$f")"; d="$(disp_slice "$f")"
  bl="$(printf '%s\n' "$b" | wc -l | tr -d ' ')"
  ctl="$(bg_cF 'run_in_background: true' "$d")"
  subj="$(bg_cF 'run_in_background: true' "$b")"
  proh="$(bg_cE '(Never|never|Do not|do not|must not|Avoid|avoid) [^.]*run_in_background' "$b")"
  printf '%s %s %s %s' "$bl" "$ctl" "$subj" "$proh"
}
bg_band_ok() { [ "$1" -gt 0 ] && [ "$1" -le "$BEAT_BAND_MAX" ]; }
# END bg-scoring

if [ -z "${GATE_PROC_MD:-}" ]; then
  bad "FIXTURE BROKEN — _gate-procedures.md unresolved, so the beat-backgrounded arms asserted nothing"
else
  set -- $(score_bg "$GATE_PROC_MD")
  BG_L="$1"; BG_CTL="$2"; BG_SUBJ="$3"; BG_PROH="$4"

  # ARM 1 — the slice is in band. Out of band, every content arm below it is being
  # satisfied by a neighbouring section rather than by the beat.
  if bg_band_ok "$BG_L"; then
    ok "beat-slice-band: the Bounded-join beat slice is $BG_L lines (band 1..$BEAT_BAND_MAX)"
  else
    bad "beat-slice-band: the slice is $BG_L lines, outside 1..$BEAT_BAND_MAX — it has run past its terminating heading and is reading a neighbouring section's prose as its own"
  fi

  # ARM 2 — the CONTROL, in the same invocation, over the thing the verdict claims is
  # present elsewhere. Its loss is a RESTRUCTURE and is reported separately: an ordinary
  # reword of the dispatch call form is not this work and must not read as a live defect.
  if [ "$BG_CTL" -gt 0 ]; then
    ok "beat-bg-control: the Gate-adjudication dispatch slice still spells the call form ($BG_CTL) — the slicer and the grep both ran"
  else
    bad "beat-bg-control: the dispatch slice spells 'run_in_background: true' $BG_CTL times. At zero this is a restructure of the neighbouring section, not a live defect in the beat — the subject arm below is unanchored and its reading proves nothing either way."
  fi

  # ARM 3 — the SUBJECT.
  if [ "$BG_SUBJ" -gt 0 ]; then
    ok "beat-is-backgrounded: the Bounded-join beat slice spells 'run_in_background: true' ($BG_SUBJ)"
  else
    bad "beat-is-backgrounded: the Bounded-join beat prescribes the call and never says it is backgrounded. A foreground beat's exit trap clears the in-flight marker before the turn ends, so the join reads as armed and is not — and this section is the ONLY sanctioned way to wait for a teammate, so every join delegating to it by name inherits the omission."
  fi

  # ARM 4 — POLARITY. A prohibition carries the token and asserts the opposite.
  if [ "$BG_PROH" -eq 0 ]; then
    ok "beat-bg-polarity: no sentence in the slice forbids the backgrounded call"
  else
    bad "beat-bg-polarity: the slice FORBIDS passing run_in_background to this beat ($BG_PROH). That contradicts wait-for-deliverable.sh's own premise and ai-dlc-continue.sh's enumeration of dead beats, and it satisfies a bare token-presence anchor while inverting the property."
  fi
fi

# BL-574/BL-562: the directed-handoff authorisation sentence sits beside the prescribed push in
# steps/handoff.md step 3, steps/_gate-procedures.md auto-handoff step 3 and steps/retro.md 6b, and
# the --no-verify prohibition beside the first two (proximity-keyed; push-authorised.sh owns why).
# Its own ok lines are counted here too, so the summary equals the ok lines printed.
_pa="$(bash "$HERE/push-authorised.sh")"; _parc=$?
printf '%s\n' "$_pa"
_no="$(grep -c '^  ok    ' <<< "$_pa")" || _no=0
oks=$((oks + _no))
if [ "$_parc" -eq 0 ]; then ok "push-authorised: all three push sites carry the authorisation sentence, and two carry the --no-verify prohibition"
else bad "push-authorised: a prescribed handoff push lacks the authorisation sentence beside it"; fi

rm -rf "$ROOT"
echo ""
report_end handoff-resume-guard
