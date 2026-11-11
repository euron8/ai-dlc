#!/usr/bin/env bash
# BL-977 receipt: the CONSUMER pre-push hook's rule-file audit gates only a LOCALLY-OWNED (or
# unresolved) tier-1 finding. A core-owned tier-1 finding prints, enumerated with its `[core]` tag,
# and does not block the consumer's push; a local tier-1 finding does.
#
# usage:  bash receipt-bl977.sh [--root R] [--hook H]
#   --root R  the tree whose audit and hook are judged. Default: walk up from this file to the first
#             directory holding the audit in either layout (core/scripts/ or scripts/ai-dlc/).
#   --hook H  drive H instead of the resolved hook (run.sh passes a mutant copy this way).
# exit 0 PASS, 1 FAIL, 2 the receipt could not run (no audit, no hook, no git).
#
# THE WHOLE HOOK IS DRIVEN, in a scratch consumer git repo holding the audit and its ownership resolver
# at scripts/ai-dlc/ and the hook at .githooks/pre-push. The verdict is the PASS/FAIL line closing the
# hook's `rule-file audit (origin tags` block, never the hook's exit, which other steps also move.
# Three cells, one world each, so no cell's verdict can be satisfied by another cell's seed:
#   core-t1   a tier-1 origin tag in a core-owned file   -> block PASS, and ORIGIN_TAG FLAGGED [core 1
#   local-t1  the same line in a consumer-owned file     -> block FAIL
#   local-t2  a tier-2-only drift line, consumer-owned, run through the audit's own
#             --fail-on=local-deterministic              -> rc 0, and NARRATIVE_DRIFT FLAGGED [core 0 / local 1
# The local-t2 cell is what separates the threshold from `--fail-on=local`, which counts the judgement
# tier and would block that push.
set -uo pipefail
# It git-inits scratch repos: an inherited GIT_DIR (a direct run from a linked worktree) would make `git init`
# create nothing and redirect git onto the caller's repository. The variables lib/preamble.sh unsets.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=""; HOOK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --hook) HOOK="${2:-}"; shift 2 ;;
    *) echo "usage: receipt-bl977.sh [--root R] [--hook H]" >&2; exit 2 ;;
  esac
done
if [ -z "$ROOT" ]; then
  d="$HERE"
  while [ "$d" != "/" ]; do
    if [ -f "$d/core/scripts/audit-rule-files.sh" ] || [ -f "$d/scripts/ai-dlc/audit-rule-files.sh" ]; then ROOT="$d"; break; fi
    d="$(dirname "$d")"
  done
fi
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "receipt-bl977: BROKEN -- no root holding audit-rule-files.sh" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"
if [ -f "$ROOT/core/scripts/audit-rule-files.sh" ]; then
  AUDIT="$ROOT/core/scripts/audit-rule-files.sh"; DEFHOOK="$ROOT/core/git-hooks/pre-push"
else
  AUDIT="$ROOT/scripts/ai-dlc/audit-rule-files.sh"; DEFHOOK="$ROOT/.githooks/pre-push"
fi
RESOLVER="$(dirname "$AUDIT")/core-paths.sh"
[ -n "$HOOK" ] || HOOK="$DEFHOOK"
for f in "$AUDIT" "$RESOLVER" "$HOOK"; do
  [ -f "$f" ] || { echo "receipt-bl977: BROKEN -- $f not found" >&2; exit 2; }
done
command -v git >/dev/null 2>&1 || { echo "receipt-bl977: BROKEN -- git required" >&2; exit 2; }
echo "receipt-bl977: audit $AUDIT"
echo "receipt-bl977: hook  $HOOK"

X="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl977.XXXXXX")" || exit 2
trap 'case "$X" in */receipt-bl977.*) rm -rf -- "$X" ;; esac' EXIT

world() { # <name> -> a scratch consumer git repo with the audit, its resolver and the hook installed
  local p="$X/$1"
  mkdir -p "$p/.claude/skills/ai-dlc" "$p/docs" "$p/scripts/ai-dlc" "$p/.githooks" || return 1
  printf '# Skill\n\nThe lead MUST NOT merge past a red gate.\n' > "$p/.claude/skills/ai-dlc/SKILL.md"
  printf '# Core manifest\n\ncore_manifest:\n  - SKILL.md\n' > "$p/.claude/skills/ai-dlc/core-manifest.md"
  printf '# Conventions\n\nEvery public function MUST carry a docstring.\n' > "$p/docs/coding-conventions.md"
  cp "$AUDIT" "$p/scripts/ai-dlc/audit-rule-files.sh" && cp "$RESOLVER" "$p/scripts/ai-dlc/core-paths.sh" \
    && cp "$HOOK" "$p/.githooks/pre-push" || return 1
  git -c init.defaultBranch=main init -q "$p" >/dev/null 2>&1 || return 1
  printf '%s\n' "$p"
}
block() { # <project> -> the hook's rule-file audit block, header through its closing PASS/FAIL
  local out
  out="$( cd "$1" && env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE AI_DLC_READSET_LIVE_TRACE=0 \
          bash .githooks/pre-push </dev/null 2>&1 )"
  awk '/^── rule-file audit \(origin tags/ {on=1} on {print} on && /^   (PASS|FAIL)$/ {exit}' <<<"$out"
}
verdict() { awk '/^   (PASS|FAIL)$/ {v=$1} END {print (v == "" ? "ABSENT" : v)}' <<<"$1"; }
TAG='The lead MUST re-run the gate; this replaced the v0.42.0 behaviour.'
fail=0

p="$(world core)" || { echo "receipt-bl977: BROKEN -- world core not built" >&2; exit 2; }
echo "$TAG" >> "$p/.claude/skills/ai-dlc/SKILL.md"
b="$(block "$p")"; v="$(verdict "$b")"
c1=no; grep -q 'ORIGIN_TAG: FLAGGED.*\[core 1 / local 0' <<<"$b" && c1=yes
echo "CELL core-t1 block=$v core1=$c1"
{ [ "$v" = PASS ] && [ "$c1" = yes ]; } || fail=1

p="$(world local)" || { echo "receipt-bl977: BROKEN -- world local not built" >&2; exit 2; }
echo "$TAG" >> "$p/docs/coding-conventions.md"
b="$(block "$p")"; v="$(verdict "$b")"
l1=no; grep -q 'ORIGIN_TAG: FLAGGED.*\[core 0 / local 1' <<<"$b" && l1=yes
echo "CELL local-t1 block=$v local1=$l1"
{ [ "$v" = FAIL ] && [ "$l1" = yes ]; } || fail=1

p="$(world drift)" || { echo "receipt-bl977: BROKEN -- world drift not built" >&2; exit 2; }
echo 'The dev MUST comply, because we lost a sprint to this.' >> "$p/docs/coding-conventions.md"
o="$( cd "$p" && bash scripts/ai-dlc/audit-rule-files.sh --fail-on=local-deterministic 2>&1 )"; rc=$?
d1=no; grep -q 'NARRATIVE_DRIFT: FLAGGED.*\[core 0 / local 1' <<<"$o" && d1=yes
echo "CELL local-t2 rc=$rc drift-local=$d1"
{ [ "$rc" = 0 ] && [ "$d1" = yes ]; } || fail=1

if [ "$fail" = 0 ]; then echo "receipt-bl977: PASS"; exit 0; fi
echo "receipt-bl977: FAIL"
exit 1
