#!/usr/bin/env bash
# inflight-row-hook/run.sh -- drive the REAL ai-dlc-inflight-row.sh hook and the waiter's armed
# `--dispatch` row write over seeded worlds, and prove each writes the In-Flight Teammates row the
# lead used to write by hand, and writes nothing where it must not.
#
# THE SUBJECT. A PostToolUse `Agent|Task` payload that launched a background teammate makes the hook
# add `<agentId> <toolu_id> | <role> | <deliverable> | <dispatched-at> | in-flight`, the stamp copied
# from the spawn ledger by `wait-for-deliverable.sh --dispatch-ts`, never read off a clock. A
# SubagentStop whose deliverable is on disk flips the row to `delivered-reachable`, and so does a
# waiter beat armed with `--dispatch <id>` that says DELIVERED. Every write goes through
# snapshot-update.sh. A check that cannot fire reads exactly like one that passed, so every
# no-write arm asserts BOTH the exit code AND that the snapshot is byte-identical, and every
# write arm asserts the exact row line.
#
# THE WORLD is a consumer layout built once and copied per cell: the hook's siblings under
# scripts/ai-dlc/, the step file the era gate reads under .claude/skills/ai-dlc/steps/, a spawn
# ledger whose first row is an epoch row that is NOT the dispatch under test, and a dispatch row
# stamped 2026-11-01T10:00:00Z -- a ts that is not now, so a clock stamp differs from it.
#
# ARMS (each a CELL: it takes a program and answers pass or fail)
#   DISPATCH    async_launched, brief carrying ``Deliverable: write `x/y.md` in your worktree``
#               -> exit 0 and exactly the row `a0123456789abcdef toolu_01abc | dev | x/y.md |
#               2026-11-01T10:00:00Z | in-flight`: agent cell `<agentId> <toolu_id>`, stamp
#               byte-equal to the ledger ts. Era gate, new era: the real step file is installed.
#   ERAOLD      the installed _gate-procedures.md WITHOUT the era sentence -> exit 0, file unchanged
#   NESTED      a payload `agent_id` (an Agent call made inside a subagent) -> exit 0, unchanged
#   UPDATER     an /ai-dlc-update transcript_path -> exit 0, nothing printed, unchanged (twin LEADTR: /ai-dlc writes)
#   NOLEDGER    a tool_use_id with no spawn-ledger row -> exit 0, unchanged
#   DLPARSE     a Deliverable line naming two `.md` paths -> the FIRST path-shaped token, x/y.md
#   DLFALL      no Deliverable line -> the ledger row's mark_file, m/k.md
#   NODL        no Deliverable line and no mark_file -> exit 2, stderr names `--row-add`, unchanged
#   ROWDIFF     a seeded row carrying the dispatch's toolu_ id with DIFFERENT cells (first word not the agentId) ->
#               the hook's --row-add is refused by snapshot-update.sh, exit 2, stderr names --row-replace
#               (not the looping --row-add), unchanged
#   SUBSTOP     SubagentStop, deliverable on disk -> exit 0, NOTHING printed, row delivered-reachable
#   SUBSTOPABS  SubagentStop, deliverable absent -> exit 0, nothing printed, file unchanged
#   WSTATUS     waiter `--status --dispatch toolu_01abc x/y.md` -> says DELIVERED, file unchanged
#   WDTS        waiter `--dispatch-ts toolu_01abc` -> prints the ledger ts, file unchanged
#   WBEAT       waiter beat `--dispatch toolu_01abc x/y.md` -> DELIVERED, row delivered-reachable
#   WBEATOLD    the same armed beat in the OLD era (step file without the era sentence) over a
#               hand-written row whose first word is the bare agentId -> DELIVERED, file unchanged
#
# CLOCK AND BACKGROUND, per arm. No arm runs a background process. No arm reads the clock for its
# verdict: the stamp compared is the seeded ledger ts, and AI_DLC_SNAPSHOT_NOW_EPOCH pins the stamp
# check's "now" to 2030-01-01. The waiter beat delivers on its FIRST check (the file's mtime is past
# the 2026-11-01 join epoch and no --complete is armed), so it never sleeps on a poll. Only the
# m-datestamp mutant reads the clock, and any real clock reading differs from the 2026-11-01 ts.
#
# MUTANTS (each a copy at .../core/hooks/ai-dlc-inflight-row.sh or .../core/scripts/
# wait-for-deliverable.sh, so a counted run sees every start; each must turn its deciding cell red
# and leave its twin green):
#   m-datestamp   dispatched-at from `date` -> DISPATCH red, and the hook's stderr carries the LATE
#                 line of validate-artifact-budget.sh: the stamp check refused the clock reading
#   m-noera       the era gate dropped -> ERAOLD writes a row
#   m-nonested    the agent_id check dropped -> NESTED writes a row
#   m-noupdater   the updater-session gate dropped -> UPDATER writes a row
#   m-noledger    the single-ledger-row check dropped -> NOLEDGER exits 2
#   m-lastmd      the LAST `.md` token of the Deliverable line taken -> DLPARSE gives x/draft.md
#   m-rowadd      the --row-replace remedy branch of say_unwritten dropped -> ROWDIFF's stderr names only --row-add
#   m-substop2    SubagentStop exits 2 on a missing deliverable -> SUBSTOPABS exit 2
#   m-wstatus     the waiter writes the row on `--status` -> WSTATUS changes the file
#   m-wnoera      the waiter's era gate dropped -> WBEATOLD rewrites the lead's hand-written row
# A control drives UNMUTATED copies through the same harness first (DISPATCH on the hook copy,
# WSTATUS on the waiter copy) and requires both to pass, so a copy that cannot run is not read as
# a scored mutant.
#
# MUTANT-MATRIX m-datestamp decides=DISPATCH twins=NESTED
# MUTANT-MATRIX m-noera decides=ERAOLD twins=DISPATCH
# MUTANT-MATRIX m-nonested decides=NESTED twins=DISPATCH
# MUTANT-MATRIX m-noupdater decides=UPDATER twins=LEADTR
# MUTANT-MATRIX m-noledger decides=NOLEDGER twins=DISPATCH
# MUTANT-MATRIX m-lastmd decides=DLPARSE twins=DLFALL
# MUTANT-MATRIX m-rowadd decides=ROWDIFF twins=NODL
# MUTANT-MATRIX m-substop2 decides=SUBSTOPABS twins=SUBSTOP
# MUTANT-MATRIX m-wstatus decides=WSTATUS twins=WBEAT
# MUTANT-MATRIX m-wnoera decides=WBEATOLD twins=WBEAT
# MUTANT-MATRIX-CONTROL control why=the unmutated hook and waiter copies must pass DISPATCH and WSTATUS through the mutant harness so a mutant verdict is attributable to the mutation
# MUTANT-MATRIX-DYNAMIC mutants why=one scoring function takes every mutant name as an argument and every name keeps its own row
# MUTANT-MATRIX-REMEASURE bash core/fixtures/inflight-row-hook/run.sh --matrix
# also trips: m-datestamp -> DLPARSE,DLFALL (every hook write is stamp-checked, so a clock stamp refuses each one)
# also trips: m-noera, m-nonested, m-rowadd, m-noupdater, m-noledger, m-lastmd, m-substop2, m-wstatus, m-wnoera -> none
set -uo pipefail

MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "inflight-row-hook: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_CODE_SESSION_ID CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
pick() { local c; for c in "$@"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done; return 1; }
HOOK="$(pick "$ROOT/core/hooks/ai-dlc-inflight-row.sh" "$ROOT/.claude/hooks/ai-dlc-inflight-row.sh")" \
  || { echo "FIXTURE ERROR: ai-dlc-inflight-row.sh not found in either layout" >&2; exit 2; }
SDIR=""
for d in "$ROOT/core/scripts" "$ROOT/scripts/ai-dlc"; do
  [ -f "$d/wait-for-deliverable.sh" ] && [ -f "$d/snapshot-update.sh" ] && { SDIR="$d"; break; }
done
[ -n "$SDIR" ] || { echo "FIXTURE ERROR: wait-for-deliverable.sh and snapshot-update.sh not found together in either layout" >&2; exit 2; }
WFD="$SDIR/wait-for-deliverable.sh"
GATEPROC="$(pick "$ROOT/core/skills/ai-dlc/steps/_gate-procedures.md" "$ROOT/.claude/skills/ai-dlc/steps/_gate-procedures.md")" \
  || { echo "FIXTURE ERROR: _gate-procedures.md not found in either layout" >&2; exit 2; }
SIBS="snapshot-update.sh validate-artifact-budget.sh wait-for-deliverable.sh validate-adversarial-convergence.sh merge-adversarial-shards.sh wfd-start-of.sh"
for f in $SIBS; do [ -f "$SDIR/$f" ] || { echo "FIXTURE ERROR: $SDIR/$f is absent; the hook and the waiter run it as a sibling" >&2; exit 2; }; done
printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$HOOK" "$WFD" "$GATEPROC"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/inflight-row-hook.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

export AI_DLC_SNAPSHOT_NOW_EPOCH=1893456000      # 2030-01-01T00:00:00Z: the stamp check's "now", pinned
LEDGER_TS="2026-11-01T10:00:00Z"
AGENT="a0123456789abcdef"
ROW_IN="$AGENT toolu_01abc | dev | x/y.md | $LEDGER_TS | in-flight"
ROW_DR="$AGENT toolu_01abc | dev | x/y.md | $LEDGER_TS | delivered-reachable"
# The old-era hand-written row: a bare agentId first word, the shape most hand-written rows carry.
ROW_HAND="$AGENT | dev | x/y.md | $LEDGER_TS | in-flight"
SENTINEL='rows are written by the ai-dlc-inflight-row hook'

# --- the world template, built once ------------------------------------------------------------
TPL="$WORK/tpl"
mkdir -p "$TPL/.claude/skills/ai-dlc/steps" "$TPL/scripts/ai-dlc" "$TPL/_bmad-output" "$TPL/home" "$TPL/td" "$TPL/x" || exit 2
cp "$GATEPROC" "$TPL/.claude/skills/ai-dlc/steps/_gate-procedures.md" || exit 2
for f in $SIBS; do cp "$SDIR/$f" "$TPL/scripts/ai-dlc/$f" || exit 2; done
{
  printf '{"v":1,"ts":"2026-11-01T09:00:00Z","name":"epoch","role":"pm","tool_use_id":"toolu_01epoch"}\n'
  printf '{"v":1,"ts":"%s","name":"dev-1","role":"dev","tool_use_id":"toolu_01abc","mark":"--mark","mark_file":"m/k.md"}\n' "$LEDGER_TS"
  printf '{"v":1,"ts":"2026-11-01T10:05:00Z","name":"dev-2","role":"dev","tool_use_id":"toolu_01nomk"}\n'
} > "$TPL/_bmad-output/spawn-ledger.jsonl"
printf '{"agentType":"dev","toolUseId":"toolu_01abc"}\n' > "$TPL/td/agent-$AGENT.meta.json"
printf '# Pipeline Snapshot\n\n## Pipeline Position\n- current_step_file: implementation.md\n\n## Sprint Context\n- sprint_id: 5\n\n## In-Flight Teammates\nagent | role | deliverable | dispatched-at | status\n' \
  > "$TPL/_bmad-output/pipeline-snapshot.md"
# The old-era step file: the real one with its era sentence removed, which must change it.
grep -vF -- "$SENTINEL" "$GATEPROC" > "$WORK/gate-old.md"
n_sent="$(grep -cF -- "$SENTINEL" "$GATEPROC")" || n_sent=0
if [ "$n_sent" != 1 ] || cmp -s "$GATEPROC" "$WORK/gate-old.md"; then
  echo "FIXTURE BROKEN: the installed _gate-procedures.md carries the era sentence $n_sent time(s), not once on one line; the era arms cannot be built" >&2; exit 2
fi

# mkworld <name> [row] [deliverable 0|1] [old-era 0|1] -> a fresh copy of the template; prints its path
mkworld() {
  local w="$WORK/w-$1"
  cp -R "$TPL" "$w" || { echo "FIXTURE BROKEN: cannot copy the world template" >&2; exit 2; }
  [ -z "${2:-}" ] || printf '%s\n' "$2" >> "$w/_bmad-output/pipeline-snapshot.md"
  [ "${3:-0}" = 1 ] && printf 'the deliverable\n' > "$w/x/y.md"
  [ "${4:-0}" = 1 ] && cp "$WORK/gate-old.md" "$w/.claude/skills/ai-dlc/steps/_gate-procedures.md"
  printf '%s' "$w"
}
post() { # <status> <tool_use_id> <prompt> [agent_id] [transcript_path] -> a PostToolUse Agent payload on stdout
  jq -n --arg st "$1" --arg tu "$2" --arg p "$3" --arg ag "$AGENT" --arg na "${4:-}" --arg tp "${5:-}" '
    {hook_event_name:"PostToolUse", tool_name:"Agent", session_id:"sess-fixture", tool_use_id:$tu,
     tool_input:{prompt:$p, subagent_type:"dev"}, tool_response:{status:$st, agentId:$ag}}
    + (if $na == "" then {} else {agent_id:$na, agent_type:"dev"} end)
    + (if $tp == "" then {} else {transcript_path:$tp} end)'
}
stop_payload() { jq -n --arg ag "$AGENT" '{hook_event_name:"SubagentStop", session_id:"sess-fixture", agent_id:$ag, agent_transcript_path:""}'; }

RC=""; OUT=""; ERR=""
# hook <program> <world> <tag> <payload>: one start of the hook, tagged for the invocation judge
hook() {
  local pr="$1" w="$2" tag="$3"
  printf '%s' "$4" | ( cd "$w" && HOME="$w/home" AI_DLC_PROJECT_ROOT="$w" FXCELL="$tag" bash "$pr" > "$w/.out" 2> "$w/.err" ); RC=$?
  OUT="$(cat "$w/.out")"; ERR="$(cat "$w/.err")"
}
# waiter <program> <world> <tag> <argv...>: one start of the waiter, tagged
waiter() {
  local pr="$1" w="$2" tag="$3"; shift 3
  ( cd "$w" && HOME="$w/home" AI_DLC_PROJECT_ROOT="$w" AI_DLC_TEAMMATE_DIR="$w/td" \
      AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 FXCELL="$tag" \
      bash "$pr" "$@" > "$w/.out" 2>&1 ); RC=$?
  OUT="$(cat "$w/.out")"; ERR=""
}
snap() { printf '%s' "$1/_bmad-output/pipeline-snapshot.md"; }
rows_of() { grep -c '^a[0-9a-f]* toolu_' "$(snap "$1")"; }

BRIEF_DEV=$'You are the dev.\nDeliverable: write `x/y.md` in your worktree\nClose with the seal line.'
BRIEF_TWO=$'You are the dev.\nDeliverable: write `x/y.md` in your worktree, beside its draft x/draft.md\nClose with the seal line.'
BRIEF_NONE=$'You are the dev. Write your findings where the mark says.'

# cell <CELL> <hook program> <waiter program> <tag> -> 0 GREEN, 1 RED; CELL_MSG carries a failure.
CELL_MSG=""
cell() {
  local c="$1" hp="$2" wp="$3" t="$4" w cs
  CELL_MSG=""
  case "$c" in
    DISPATCH)
      w="$(mkworld "$t-dispatch")"
      hook "$hp" "$w" "$t.dispatch" "$(post async_launched toolu_01abc "$BRIEF_DEV")"
      [ "$RC" = 0 ] && [ "$(grep -cxF -- "$ROW_IN" "$(snap "$w")")" = 1 ] && [ "$(rows_of "$w")" = 1 ] && return 0
      CELL_MSG="rc=$RC rows=$(rows_of "$w") err=$(printf '%s' "$ERR" | tr '\n' ' ')"; return 1 ;;
    ERAOLD)
      w="$(mkworld "$t-eraold" "" 0 1)"; cs="$(cksum < "$(snap "$w")")"
      hook "$hp" "$w" "$t.eraold" "$(post async_launched toolu_01abc "$BRIEF_DEV")"
      [ "$RC" = 0 ] && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      CELL_MSG="rc=$RC rows=$(rows_of "$w")"; return 1 ;;
    NESTED)
      w="$(mkworld "$t-nested")"; cs="$(cksum < "$(snap "$w")")"
      hook "$hp" "$w" "$t.nested" "$(post async_launched toolu_01abc "$BRIEF_DEV" aparent00000000001)"
      [ "$RC" = 0 ] && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      CELL_MSG="rc=$RC rows=$(rows_of "$w")"; return 1 ;;
    UPDATER|LEADTR)
      # An updater-marker transcript writes no row and prints nothing; its twin, the same payload over a
      # /ai-dlc (pipeline) transcript, writes the row.
      local mk='"skill":"ai-dlc-update"'; [ "$c" = LEADTR ] && mk='"skill":"ai-dlc"'
      w="$(mkworld "$t-$c")"; cs="$(cksum < "$(snap "$w")")"
      printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{%s}}]}}\n' "$mk" > "$w/transcript.jsonl"
      hook "$hp" "$w" "$t.$(printf '%s' "$c" | tr 'A-Z' 'a-z')" "$(post async_launched toolu_01abc "$BRIEF_DEV" "" "$w/transcript.jsonl")"
      if [ "$c" = LEADTR ]; then
        [ "$RC" = 0 ] && [ "$(grep -cxF -- "$ROW_IN" "$(snap "$w")")" = 1 ] && return 0
        CELL_MSG="rc=$RC rows=$(rows_of "$w") err=$(printf '%s' "$ERR" | tr '\n' ' ')"; return 1
      fi
      [ "$RC" = 0 ] && [ -z "$OUT" ] && [ -z "$ERR" ] && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      CELL_MSG="rc=$RC rows=$(rows_of "$w") printed=[$OUT$ERR]"; return 1 ;;
    NOLEDGER)
      w="$(mkworld "$t-noledger")"; cs="$(cksum < "$(snap "$w")")"
      hook "$hp" "$w" "$t.noledger" "$(post async_launched toolu_01none "$BRIEF_DEV")"
      [ "$RC" = 0 ] && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      CELL_MSG="rc=$RC rows=$(rows_of "$w")"; return 1 ;;
    DLPARSE|DLFALL)
      local br="$BRIEF_TWO" want="x/y.md"
      [ "$c" = DLFALL ] && { br="$BRIEF_NONE"; want="m/k.md"; }
      w="$(mkworld "$t-$c")"
      hook "$hp" "$w" "$t.$(printf '%s' "$c" | tr 'A-Z' 'a-z')" "$(post async_launched toolu_01abc "$br")"
      [ "$RC" = 0 ] && [ "$(grep -cxF -- "$AGENT toolu_01abc | dev | $want | $LEDGER_TS | in-flight" "$(snap "$w")")" = 1 ] && return 0
      CELL_MSG="rc=$RC row=$(grep 'toolu_01abc' "$(snap "$w")" | tr '\n' ' ')"; return 1 ;;
    NODL)
      w="$(mkworld "$t-nodl")"; cs="$(cksum < "$(snap "$w")")"
      hook "$hp" "$w" "$t.nodl" "$(post async_launched toolu_01nomk "$BRIEF_NONE")"
      [ "$RC" = 2 ] && grep -qF -- "--row-add '$AGENT toolu_01nomk | dev | <deliverable path> |" <<<"$ERR" \
        && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      CELL_MSG="rc=$RC err=$(printf '%s' "$ERR" | head -3 | tr '\n' ' ')"; return 1 ;;
    ROWDIFF)
      w="$(mkworld "$t-rowdiff" "toolu_01abc | dev | other.md | $LEDGER_TS | in-flight")"; cs="$(cksum < "$(snap "$w")")"
      hook "$hp" "$w" "$t.rowdiff" "$(post async_launched toolu_01abc "$BRIEF_DEV")"
      [ "$RC" = 2 ] && grep -qF -- "--row-replace" <<<"$ERR" && ! grep -qF -- "--row-add '" <<<"$ERR" \
        && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      CELL_MSG="rc=$RC err=$(printf '%s' "$ERR" | head -4 | tr '\n' ' ')"; return 1 ;;
    SUBSTOP|SUBSTOPABS)
      local dl=1; [ "$c" = SUBSTOPABS ] && dl=0
      w="$(mkworld "$t-$c" "$ROW_IN" "$dl")"; cs="$(cksum < "$(snap "$w")")"
      hook "$hp" "$w" "$t.$(printf '%s' "$c" | tr 'A-Z' 'a-z')" "$(stop_payload)"
      if [ "$RC" != 0 ] || [ -n "$OUT" ] || [ -n "$ERR" ]; then CELL_MSG="rc=$RC printed=[$OUT$ERR]"; return 1; fi
      if [ "$c" = SUBSTOP ]; then
        [ "$(grep -cxF -- "$ROW_DR" "$(snap "$w")")" = 1 ] && return 0
        CELL_MSG="the row was not set delivered-reachable"; return 1
      fi
      [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      CELL_MSG="the snapshot changed with the deliverable absent"; return 1 ;;
    WSTATUS|WDTS)
      w="$(mkworld "$t-$c" "$ROW_IN" 1)"; cs="$(cksum < "$(snap "$w")")"
      if [ "$c" = WSTATUS ]; then
        waiter "$wp" "$w" "$t.wstatus" --status --dispatch toolu_01abc x/y.md
        [ "$RC" = 0 ] && grep -qx 'DELIVERED x/y.md' <<<"$OUT" && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      else
        waiter "$wp" "$w" "$t.wdts" --dispatch-ts toolu_01abc
        [ "$RC" = 0 ] && [ "$OUT" = "$LEDGER_TS" ] && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      fi
      CELL_MSG="rc=$RC changed=$([ "$(cksum < "$(snap "$w")")" = "$cs" ] && echo no || echo yes) out=$(printf '%s' "$OUT" | head -3 | tr '\n' ' ')"; return 1 ;;
    WBEAT)
      w="$(mkworld "$t-wbeat" "$ROW_IN" 1)"
      waiter "$wp" "$w" "$t.wbeat" --dispatch toolu_01abc x/y.md
      grep -q '^DELIVERED x/y.md' <<<"$OUT" && [ "$(grep -cxF -- "$ROW_DR" "$(snap "$w")")" = 1 ] && return 0
      CELL_MSG="rc=$RC out=$(printf '%s' "$OUT" | head -3 | tr '\n' ' ')"; return 1 ;;
    WBEATOLD)
      w="$(mkworld "$t-wbeatold" "$ROW_HAND" 1 1)"; cs="$(cksum < "$(snap "$w")")"
      waiter "$wp" "$w" "$t.wbeatold" --dispatch toolu_01abc x/y.md
      grep -q '^DELIVERED x/y.md' <<<"$OUT" && [ "$(cksum < "$(snap "$w")")" = "$cs" ] && return 0
      CELL_MSG="rc=$RC changed=$([ "$(cksum < "$(snap "$w")")" = "$cs" ] && echo no || echo yes) out=$(printf '%s' "$OUT" | head -3 | tr '\n' ' ')"; return 1 ;;
    *) echo "MATRIX BROKEN unknown cell $c" >&2; exit 2 ;;
  esac
}
CELLS="DISPATCH ERAOLD NESTED UPDATER LEADTR NOLEDGER DLPARSE DLFALL NODL ROWDIFF SUBSTOP SUBSTOPABS WSTATUS WDTS WBEAT WBEATOLD"

echo "inflight-row-hook:"

# --- the shipped hook and waiter -------------------------------------------------------------
say_cell() { # <cell> <ok text>
  if cell "$1" "$HOOK" "$WFD" ship; then ok "$1: $2"; else bad "$1: $CELL_MSG"; fi
}
say_cell DISPATCH "an async launch writes \`$ROW_IN\` with no lead call, stamp byte-equal to the ledger ts"
say_cell ERAOLD "with the installed step file lacking the era sentence the hook writes nothing and exits 0"
say_cell NESTED "a nested spawn (payload agent_id) writes nothing and exits 0"
say_cell UPDATER "an /ai-dlc-update transcript: the dispatch writes no row, prints nothing and exits 0"
say_cell LEADTR "the same dispatch over an /ai-dlc transcript still writes the row"
say_cell NOLEDGER "a dispatch with no spawn-ledger row writes nothing and exits 0"
say_cell DLPARSE "a Deliverable line naming two .md paths yields its FIRST path, x/y.md"
say_cell DLFALL "a brief with no Deliverable line falls back to the ledger's mark_file, m/k.md"
say_cell NODL "no Deliverable line and no mark_file: no row, exit 2, stderr names the exact --row-add call"
say_cell ROWDIFF "an existing row with the same toolu_ id and different cells: no write, exit 2, the remedy names --row-replace and not --row-add"
say_cell SUBSTOP "SubagentStop with the deliverable on disk prints nothing and sets the row delivered-reachable"
say_cell SUBSTOPABS "SubagentStop with the deliverable absent prints nothing, exits 0 and writes nothing"
say_cell WSTATUS "the waiter's --status on a --dispatch-armed target says DELIVERED and leaves the file byte-identical"
say_cell WDTS "the waiter's --dispatch-ts prints the ledger ts and leaves the file byte-identical"
say_cell WBEAT "a --dispatch-armed beat that says DELIVERED sets the row delivered-reachable"
say_cell WBEATOLD "in the old era the same armed beat says DELIVERED and leaves the lead's bare-agentId row byte-identical"

# --- mutants ---------------------------------------------------------------------------------
# mkmut <src> <dst> <old> <new> [<old> <new> ...]: <dst> is <src> with each literal replaced once, in
# order; an <old> beginning `=` matches a WHOLE line. Each replacement must change the file (cmp -s).
mkmut() {
  local src="$1" dst="$2" cur="$WORK/mk.cur" nxt="$WORK/mk.nxt"; shift 2
  cp "$src" "$cur" || return 1
  while [ $# -ge 2 ]; do
    MM_OLD="$1" MM_NEW="$2" awk 'BEGIN { o = ENVIRON["MM_OLD"]; n = ENVIRON["MM_NEW"]; whole = (substr(o, 1, 1) == "="); if (whole) o = substr(o, 2) }
      { if (!done && whole && $0 == o) { $0 = n; done = 1 }
        else if (!done && !whole && index($0, o)) { i = index($0, o); $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); done = 1 }
        print }' "$cur" > "$nxt" || return 1
    cmp -s "$cur" "$nxt" && { echo "DID NOT APPLY: $1" >&2; return 1; }
    mv "$nxt" "$cur"; shift 2
  done
  mkdir -p "$(dirname "$dst")" && mv "$cur" "$dst"
}
# The waiter resolves its siblings beside itself, so its copies are whole directories.
wfd_dir() { mkdir -p "$1"; local f; for f in $SIBS; do cp "$SDIR/$f" "$1/$f" || return 1; done; }

CH="$WORK/mut-control/core/hooks/ai-dlc-inflight-row.sh"; mkdir -p "$(dirname "$CH")"; cp "$HOOK" "$CH"
CW="$WORK/mut-control/core/scripts"; wfd_dir "$CW"
if cell DISPATCH "$CH" "$WFD" control && cell WSTATUS "$HOOK" "$CW/wait-for-deliverable.sh" control; then
  ok "control: the unmutated hook copy writes DISPATCH's row and the unmutated waiter copy passes WSTATUS"; B_ctl=1
else bad "control: an unmutated copy fails ($CELL_MSG) -- no mutant verdict below can be read"; fi

mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  local n="$1" f="$2" l w c=0 v=""
  while IFS= read -r l; do
    case "$l" in "# MUTANT-MATRIX $n "*) c=$((c + 1)); for w in ${l#"# MUTANT-MATRIX $n "}; do case "$w" in "$f="*) v="${w#"$f="}" ;; esac; done ;; esac
  done < "$HERE/run.sh"
  [ "$c" -eq 1 ] && printf '%s' "$v"
}
# score <mutant> <hook|waiter> <old> <new> [...]: build the mutant, run its deciding cell and its twin.
score() {
  local name="$1" kind="$2" hp="$HOOK" wp="$WFD" dec tw d t dmsg a g tot rd u; shift 2
  if [ "$kind" = hook ]; then
    hp="$WORK/mut-$name/core/hooks/ai-dlc-inflight-row.sh"
    mkmut "$HOOK" "$hp" "$@" || { bad "$name: mutation did not apply"; return; }
  else
    wfd_dir "$WORK/mut-$name/core/scripts" || { bad "$name: cannot copy the waiter's directory"; return; }
    wp="$WORK/mut-$name/core/scripts/wait-for-deliverable.sh"
    mkmut "$WFD" "$wp" "$@" || { bad "$name: mutation did not apply"; return; }
  fi
  dec="$(mx_row "$name" decides)"; tw="$(mx_row "$name" twins)"
  if [ -z "$dec" ] || [ -z "$tw" ]; then bad "$name: no single MUTANT-MATRIX row names its deciding cell and twin"; return; fi
  if cell "$dec" "$hp" "$wp" "$name"; then d=GREEN; dmsg=""; else d=RED; dmsg="$CELL_MSG"; fi
  # m-datestamp is killed only when the STAMP CHECK refused the clock reading: its LATE line is in the hook's stderr.
  if [ "$name" = m-datestamp ] && [ "$d" = RED ] && ! grep -q 'LATE  ' <<<"$ERR"; then
    bad "$name: DISPATCH went red, but not by the LATE arm (stderr: $(printf '%s' "$ERR" | head -2 | tr '\n' ' '))"; d=GREEN
  fi
  if cell "$tw" "$hp" "$wp" "$name"; then t=GREEN; else t=RED; fi
  if [ "$d" = RED ]; then
    mutant_killed "${B_ctl:-0}" "$name" "$name: scored by $dec ($dec failed on the mutant: $dmsg) with twin $tw GREEN"
  else bad "$name: SURVIVED -- $dec still holds on the mutant"; fi
  [ "$t" = GREEN ] || bad "$name: its twin $tw also failed -- the mutant is not confined to its own cell"
  if [ "$MODE" = matrix ]; then
    g=0; tot=0; rd=""
    for a in $CELLS; do
      { [ "$a" = "$dec" ] || [ "$a" = "$tw" ]; } && continue
      tot=$((tot + 1)); if cell "$a" "$hp" "$wp" "$name-mx"; then g=$((g + 1)); else rd="$rd,$a"; fi
    done
    u=""; [ "$d" = GREEN ] && u=" UNEXPECTED=$dec:GREEN"; [ "$t" = RED ] && u="$u UNEXPECTED=$tw:RED"
    printf 'MATRIX %s decides=%s:%s twins=%s:%s others=%d/%d%s%s\n' "$name" "$dec" "$d" "$tw" "$t" "$g" "$tot" "${rd:+ red=${rd#,}}" "$u"
  fi
}

score m-datestamp hook 'TS="$(bash "$WFD" --dispatch-ts "$TUI" 2> /dev/null)"' 'TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"'
score m-noera hook 'era_held || exit 0' 'era_held || :'
score m-nonested hook '[ -z "$(jq -r '"'"'.agent_id // empty'"'"' <<< "$INPUT" 2> /dev/null)" ] || exit 0' ':'
score m-noupdater hook '*'"'"'"skill":"ai-dlc-update"'"'"') exit 0 ;;' '*'"'"'"skill":"zz-never"'"'"') exit 0 ;;'
score m-noledger hook '[ "$(printf '"'"'%s'"'"' "$LROW" | grep -c .)" = 1 ] || exit 0' ':'
score m-lastmd hook 'if (t ~ /\// || t ~ /\.[A-Za-z0-9]+$/) { print t; exit }' 'if (t ~ /\.md$/) last = t' \
  '=      exit' '      if (last != "") print last; exit'
score m-rowadd hook '*--row-replace*) printf' '*zz-never*) printf'
score m-substop2 hook '[ -n "$DL" ] && present "$DL" || exit 0' '[ -n "$DL" ] && present "$DL" || exit 2'
score m-wstatus waiter '  S_DONE=0; S_OUT=0' '  S_DONE=0; S_OUT=0; for _t in $TARGETS; do row_on_delivery "$_t"; done'
score m-wnoera waiter 'rd_era_held || return 0' ':'

report_end inflight-row-hook
