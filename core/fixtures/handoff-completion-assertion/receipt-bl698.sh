#!/bin/bash
# BL-698 receipt. usage: receipt-bl698.sh [<hooks-dir>]; run from the repo root.
#   exit 0   the handoff guard answers in step order with no resume block, and a backgrounded
#            push with no exit record defers it (the fix is present)
#   exit 1   it does not; the failing case is named on stderr
#   exit 9   the receipt cannot measure: no hook, no jq/git, or its world could not be built
#
# A DIRECTORY, NOT A FILE: ai-dlc-continue.sh sources ai-dlc-handoff-pending.sh as a sibling, so
# a lone mutated copy finds no library and fails open. Every case drives the shipping hook on a
# seeded git tree with a bare remote and a handoff transcript; none greps the hook's text.
set -uo pipefail
HD="${1:-core/hooks}"
[ -f "$HD/ai-dlc-continue.sh" ] || HD=.claude/hooks
[ -f "$HD/ai-dlc-continue.sh" ] && [ -f "$HD/ai-dlc-handoff-pending.sh" ] || exit 9
SCH=core/schemas/pause-routing.json; [ -f "$SCH" ] || SCH=.claude/schemas/pause-routing.json
[ -f "$SCH" ] || exit 9
command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || exit 9
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR 2>/dev/null || true
HD="$(cd "$HD" && pwd)"; SCH="$(cd "$(dirname "$SCH")" && pwd)/$(basename "$SCH")"
W="$(mktemp -d)" || exit 9
P="$W/proj"
g() { git -C "$P" "$@" >/dev/null 2>&1; }
git -c init.defaultBranch=main init -q "$P" >/dev/null 2>&1 || exit 9
[ "$(git -C "$P" rev-parse --absolute-git-dir 2>/dev/null)" = "$(cd "$P" && pwd -P)/.git" ] || exit 9
g config user.email r@ai-dlc.invalid; g config user.name r; g config commit.gpgsign false
g config core.hooksPath "$W/no-hooks"
echo s > "$P/s.txt"; g add s.txt; g commit -q --no-verify -m s || exit 9
git -c init.defaultBranch=main init -q --bare "$W/r.git" >/dev/null 2>&1 || exit 9
g remote add origin "$W/r.git" || exit 9

# Transcripts: the request, then (optionally) a Bash push the harness backgrounded, then an
# assistant turn with or without the resume block.
FENCE='```'
OKTXT="$(printf 'Done.\n\n%s\n----\n/ai-dlc resume\n----\n%s\n' "$FENCE" "$FENCE")"
tx() { # tx <out> <with-resume 0|1> <bg: none|run|enq> <iso-ts> [bash-command]
  local f="$1" a="Snapshot finalized."
  [ "$2" = 1 ] && a="$OKTXT"
  jq -nc '{type:"user",message:{role:"user",content:"hand off the sprint"}}' > "$f"
  if [ "$3" != none ]; then
    jq -nc --arg c "${5:-git push -u origin HEAD}" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"toolu_R698",name:"Bash",input:{command:$c,timeout:600000}}]}}' >> "$f"
    jq -nc --arg ts "$4" '{type:"user",timestamp:$ts,toolUseResult:{stdout:"",stderr:"",backgroundTaskId:"bR698task",timedOutAfterMs:600000},message:{role:"user",content:[{type:"tool_result",tool_use_id:"toolu_R698",content:"Command running in background with ID: bR698task"}]}}' >> "$f"
  fi
  [ "$3" = enq ] && jq -nc '{type:"queue-operation",operation:"enqueue",content:"<task-notification>\n<task-id>bR698task</task-id>\n<tool-use-id>toolu_R698</tool-use-id>\n<status>completed</status>\n</task-notification>"}' >> "$f"
  jq -nc --arg a "$a" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$a}]}}' >> "$f"
}
reset() { # reset [flag]
  local sd="$P/_bmad-output"
  mkdir -p "$sd/.driver"
  rm -f "$sd/handoff-guard-state.txt" "$sd/pipeline-continuation-log.md" "$sd/pipeline-paused.flag" \
        "$sd/.handoff-in-progress" "$sd/.handoff-guard-armed" "$sd/.handoff-complete"
  : > "$sd/.driver/handoff"
  [ "${1:-}" = flag ] && : > "$P/_bmad-output/pipeline-paused.flag"
  return 0
}
drive() { # drive <transcript> -> raw stdout
  jq -nc --arg t "$1" '{transcript_path:$t,session_id:"sess-r698"}' \
  | env -u CLAUDE_CODE_STOP_HOOK_BLOCK_CAP CLAUDE_PROJECT_DIR="$P" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCH" bash "$HD/ai-dlc-continue.sh" 2>/dev/null
}
reason() { printf '%s' "$1" | jq -r '.reason // ""' 2>/dev/null; }
PUSHT="step 3's push has NOT landed"
COMMT="step 2's commit has NOT landed"
RESUT="WITHOUT a copy-pasteable resume prompt"
fail() { echo "BL-698 receipt: $1" >&2; exit 1; }
NOWTS="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
OLDTS="2020-01-01T00:00:00.000Z"
tx "$W/noblk.jsonl" 0 none ""; tx "$W/ok.jsonl" 1 none ""
tx "$W/bg.jsonl" 0 run "$NOWTS"; tx "$W/bgenq.jsonl" 0 enq "$NOWTS"; tx "$W/bgold.jsonl" 0 run "$OLDTS"
MIDTS="$(jq -nr 'now - 1800 | strftime("%Y-%m-%dT%H:%M:%S.000Z")')" || exit 9
tx "$W/bgmid.jsonl" 0 run "$MIDTS"
tx "$W/watch.jsonl" 0 run "$NOWTS" "until grep -q 'git push' push.log; do sleep 5; done; echo \"git push finished\""
deferred() { grep -q 'HANDOFF_GUARD_DEFERRED_BY_PUSH' "$P/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; }

# (1) unpublished branch, no resume block -> the PUSH text. The defect: it answered RESUME.
reset; r="$(reason "$(drive "$W/noblk.jsonl")")"
grep -qF -- "$PUSHT" <<<"$r" && ! grep -qF -- "$RESUT" <<<"$r" || fail "unpushed + no resume did not answer the PUSH text alone"
# (2) dirty AND unpublished, no resume block -> the COMMIT text (step 2 before step 3).
reset; echo dirt >> "$P/s.txt"; r="$(reason "$(drive "$W/noblk.jsonl")")"; g checkout -q -- s.txt
grep -qF -- "$COMMT" <<<"$r" && ! grep -qF -- "$RESUT" <<<"$r" || fail "dirty + unpushed + no resume did not answer the COMMIT text"
# (3) backgrounded push, no enqueue, pause flag up -> ALLOW plus the deferral row.
reset flag; o="$(drive "$W/bg.jsonl")"
[ -z "$(reason "$o")" ] && grep -q 'HANDOFF_GUARD_DEFERRED_BY_PUSH' "$P/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
  || fail "a backgrounded push with no exit record did not defer (ALLOW + HANDOFF_GUARD_DEFERRED_BY_PUSH)"
# (4) the same transcript with the push's enqueue -> the PUSH text, no deferral row.
reset flag; r="$(reason "$(drive "$W/bgenq.jsonl")")"
grep -qF -- "$PUSHT" <<<"$r" && ! grep -q 'HANDOFF_GUARD_DEFERRED_BY_PUSH' "$P/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
  || fail "a backgrounded push WITH its exit record did not answer the PUSH text"
# (5) a backgrounded push past the ceiling -> the PUSH text, never silence.
reset flag; r="$(reason "$(drive "$W/bgold.jsonl")")"
grep -qF -- "$PUSHT" <<<"$r" || fail "a backgrounded push past the ceiling did not answer the PUSH text"
# ...and past the ceiling it must not say "wait": a waiting lead burns the BACKOFF window and
# BACKOFF allows the unpushed handoff.
grep -qF -- "has overrun its ceiling" <<<"$r" && ! grep -qF -- "end the turn and wait" <<<"$r" \
  || fail "past the ceiling the PUSH text told the lead to wait (or lacked the overrun clause)"
# (5b) a backgrounded push 1800 s old -> still deferred: the ceiling is the longest recorded
#      consumer gate (3604 s from push start), not the one 729 s sample.
reset flag; o="$(drive "$W/bgmid.jsonl")"
[ -z "$(reason "$o")" ] && deferred || fail "a backgrounded push 1800 s old was not deferred (the ceiling is shorter than a recorded gate)"
# (5c) a backgrounded WATCHER carrying `git push` only as text -> the PUSH text, no deferral.
reset flag; r="$(reason "$(drive "$W/watch.jsonl")")"
grep -qF -- "$PUSHT" <<<"$r" && ! deferred || fail "a watcher that only mentions git push deferred the guard (substring match)"
# (5d) a push in flight AND uncommitted work -> the COMMIT text, no deferral (PUSH answer only).
reset flag; echo dirt >> "$P/s.txt"; r="$(reason "$(drive "$W/bg.jsonl")")"; g checkout -q -- s.txt
grep -qF -- "$COMMT" <<<"$r" && ! deferred || fail "a push in flight swallowed the COMMIT text (the deferral is not scoped to the PUSH answer)"
# Publish the branch for the satisfied-side cases.
g push -q --no-verify -u origin HEAD || exit 9
# (6) everything landed, no resume block -> the RESUME text (control: the resume arm still runs).
reset; r="$(reason "$(drive "$W/noblk.jsonl")")"
grep -qF -- "$RESUT" <<<"$r" || fail "all steps landed + no resume did not answer the RESUME text"
# (7) everything landed, resume block emitted -> ALLOW.
reset; o="$(drive "$W/ok.jsonl")"
[ -z "$(reason "$o")" ] || fail "a satisfied handoff was blocked"
exit 0
