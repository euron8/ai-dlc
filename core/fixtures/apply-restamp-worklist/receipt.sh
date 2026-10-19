#!/usr/bin/env bash
# Receipt: after its blockers are resolved, an approved reconcile report whose region now renders a
# finding the approval never saw (`--verify` exit 3, unseen>0) is applied ONLY on a recorded
# re-approval. Exit 0 only when, in one mktemp world driving the shipping apply.sh, emit-report.sh
# and answer-capture hook:
#   (1) unseen>0 with no record          -> apply refuses, the target file unwritten;
#   (2) a hook-written AskUserQuestion record quoting the printed digest, answered with the
#       printed label                    -> apply proceeds and writes;
#   (3) the same record quoting a DIFFERENT digest -> refuses;
#   (4) unseen=0 with no record          -> proceeds (no wedge).
# Exit 1 = the property does not hold. Exit 2 = the world could not be built. Exit 9 = the subject
# (apply.sh, emit-report.sh, or the answer-capture hook) cannot be found.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
R="$(cd "$(dirname "$0")/../../.." && pwd)"
REC="$R/core/skills/ai-dlc-update/reconcile"; [ -f "$REC/apply.sh" ] || REC="$R/.claude/skills/ai-dlc-update/reconcile"
HOOK="$R/core/hooks/ai-dlc-answer-capture.sh"; [ -f "$HOOK" ] || HOOK="$R/.claude/hooks/ai-dlc-answer-capture.sh"
[ -f "$REC/apply.sh" ] && [ -f "$REC/emit-report.sh" ] && [ -f "$HOOK" ] || { echo "receipt: subject absent" >&2; exit 9; }
W="$(mktemp -d "${TMPDIR:-/tmp}/ra-receipt.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
D="$W/dist"; mkdir -p "$D/core/session-driver" "$D/core/scripts" || exit 2
g() { git -C "$D" -c user.email=r@r -c user.name=receipt "$@"; }
g init -q || exit 2
printf '1.0.0\n' > "$D/VERSION"; printf '#!/usr/bin/env bash\n# driver v1\n' > "$D/core/session-driver/drv.sh"
printf '#!/usr/bin/env bash\necho v\n' > "$D/core/scripts/validate-r.sh"
g add -A && g commit -q -m base || exit 2; B="$(git -C "$D" rev-parse HEAD)"
printf '2.0.0\n' > "$D/VERSION"; printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$D/core/session-driver/drv.sh"
g add -A && g commit -q -m theirs || exit 2; T="$(git -C "$D" rev-parse HEAD)"
ovr() { mkdir -p "$1/.claude/skills/ai-dlc/overrides" && printf -- '---\nshadows: core/rules/nonexistent.md#Nope\nbase_sha: %s\nreason: r\n---\n\n## Nope\n\nbody\n' "$2" > "$1/.claude/skills/ai-dlc/overrides/$3.md"; }
# world <dir> <plain|unseen>: approve with a HARD blocker seeded, resolve it, optionally leave a non-HARD row
world() {
  local c="$1"
  mkdir -p "$c/.claude/session-driver" "$c/scripts/ai-dlc" "$c/_bmad-output/ai-dlc-update" || return 1
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$c/.claude/session-driver/drv.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-r.sh"
  printf 'version: 1.0.0\ncommit: %s\n' "$B" > "$c/.claude/.ai-dlc-version"
  ovr "$c" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef probe || return 1
  { printf '# report\n\n'; bash "$REC/emit-report.sh" "$D" "$B" "$c" "$T" 2>/dev/null; } > "$c/_bmad-output/ai-dlc-update/reconcile-report.md"
  grep -q '^HARD-' "$c/_bmad-output/ai-dlc-update/reconcile-report.md" || return 1
  rm -f "$c/.claude/skills/ai-dlc/overrides/probe.md"
  [ "$2" = unseen ] && { ovr "$c" "$B" absent || return 1; }
  return 0
}
ra() { bash "$REC/emit-report.sh" --verify "$1/_bmad-output/ai-dlc-update/reconcile-report.md" "$D" "$B" "$1" "$T" 2>&1 >/dev/null | sed -n 's/^[[:space:]]*re-approval: //p'; }
answer() { jq -n --arg q "$2" --arg a "$3" '{tool_name:"AskUserQuestion",session_id:"r",tool_use_id:"r",tool_response:{answers:{($q):$a}}}' > "$1/p.json" \
  && CLAUDE_PROJECT_DIR="$1" bash "$HOOK" < "$1/p.json" >/dev/null 2>&1 \
  && grep -q '^## .* -- AskUserQuestion$' "$1/_bmad-output/operator-answers-history.md"; }
written() { grep -q UPSTREAM "$1/.claude/session-driver/drv.sh"; }
applyit() { bash "$REC/apply.sh" "$D" "$B" "$1" "$T" >/dev/null 2>&1; }
# (1)
world "$W/c1" unseen || exit 2
L="$(ra "$W/c1")"
DG="${L#digest=}"; DG="${DG%% *}"; LB="${L#* label=\"}"; LB="${LB%\"}"
case "$L" in *" unseen=0 "*|"") exit 1 ;; esac
[ "${#DG}" -eq 64 ] || exit 1
applyit "$W/c1"; written "$W/c1" && exit 1
# (2)
world "$W/c2" unseen || exit 2
answer "$W/c2" "Re-approve? Region digest $DG." "$LB" || exit 2
applyit "$W/c2" && written "$W/c2" || exit 1
# (3)
world "$W/c3" unseen || exit 2
answer "$W/c3" "Re-approve? Region digest $(printf '%064d' 0)." "$LB" || exit 2
applyit "$W/c3"; written "$W/c3" && exit 1
# (4)
world "$W/c4" plain || exit 2
applyit "$W/c4" && written "$W/c4" || exit 1
echo "re-approval receipt: PASS"
