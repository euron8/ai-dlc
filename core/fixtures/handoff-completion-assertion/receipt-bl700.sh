#!/bin/bash
# BL-700 receipt. usage: receipt-bl700.sh [<hooks-dir>]; run from the repo root.
#   exit 0   a handoff request whose transcript is malformed (truncated last line, non-JSON line
#            mid-file) or absent, or a hook run with no jq on PATH, still gets a HANDOFF GUARD
#            block on an unpublished branch (the fix is present)
#   exit 1   at least one of the four is allowed silently; the cases are named on stderr
#   exit 9   the receipt cannot measure: no hook, no jq/git, its world could not be built, or
#            the well-formed CONTROL transcript does not produce a HANDOFF GUARD block
#
# Every case drives the shipping hook on one seeded tree: a git repo with a bare remote and an
# unpublished branch, the pause flag up and step 4's driver signal on disk.
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

U='{"type":"user","message":{"role":"user","content":"hand off the sprint"}}'
A='{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Snapshot finalized."}]}}'
printf '%s\n%s\n' "$U" "$A" > "$W/ok.jsonl"
printf '%s\n%s\n' "$U" "${A:0:40}" > "$W/trunc.jsonl"
printf '%s\n%s\n%s\n' "$U" '{"broken":' "$A" > "$W/garbage.jsonl"

# A PATH with every /bin and /usr/bin tool EXCEPT jq, plus git. The shim is asserted below.
NJ="$W/nojq"; mkdir -p "$NJ" || exit 9
for d in /bin /usr/bin; do for t in "$d"/*; do b="${t##*/}"; [ "$b" = jq ] && continue; [ -e "$NJ/$b" ] || ln -s "$t" "$NJ/$b" 2>/dev/null; done; done
ln -sf "$(command -v git)" "$NJ/git" 2>/dev/null
[ ! -e "$NJ/jq" ] && [ -n "$(PATH="$NJ" command -v git)" ] && [ -n "$(PATH="$NJ" command -v sed)" ] || exit 9

reset() {
  local sd="$P/_bmad-output"
  mkdir -p "$sd/.driver"
  rm -f "$sd/handoff-guard-state.txt" "$sd/pipeline-continuation-log.md" "$sd/pipeline-paused.flag" \
        "$sd/.handoff-in-progress" "$sd/.handoff-guard-armed" "$sd/.handoff-complete"
  : > "$sd/.driver/handoff"; : > "$sd/pipeline-paused.flag"
}
drive() { # drive <transcript-path> [PATH] -> 0 when the hook emitted a HANDOFF GUARD block
  local in o
  in="$(jq -nc --arg t "$1" '{transcript_path:$t,session_id:"sess-r700"}')" || return 9
  reset
  o="$(printf '%s' "$in" | env -u CLAUDE_CODE_STOP_HOOK_BLOCK_CAP PATH="${2:-$PATH}" CLAUDE_PROJECT_DIR="$P" \
        AI_DLC_PAUSE_ROUTING_SCHEMA="$SCH" /bin/bash "$HD/ai-dlc-continue.sh" 2>/dev/null)"
  grep -q '"decision" *: *"block"' <<<"$o" && grep -q 'HANDOFF GUARD' <<<"$o"
}

# CONTROL: the well-formed transcript must block, or nothing below is readable.
drive "$W/ok.jsonl" || exit 9

f=""
drive "$W/trunc.jsonl"            || f="$f truncated-last-line"
drive "$W/garbage.jsonl"          || f="$f non-json-line-mid-file"
drive "$W/absent.jsonl"           || f="$f missing-transcript"
drive "$W/ok.jsonl" "$NJ"         || f="$f no-jq-on-PATH"
[ -z "$f" ] && exit 0
echo "BL-700 receipt: allowed silently:$f" >&2
exit 1
