#!/usr/bin/env bash
# Receipt: a session that resolves a blocker and then RE-RENDERS the approved report by hand (runs
# emit-report.sh and splices the fresh region over reconcile-report.md, with no answer record) must
# not get apply.sh to write when that fresh region carries a finding row the approval never showed.
# Today the re-render makes `emit-report.sh --verify` exit 0, the union gate sees "match", and apply
# writes without ever asking. In one mktemp world driving the shipping apply.sh and emit-report.sh:
#   control: the same world WITHOUT the re-render -> apply refuses with RE-APPROVAL OWED, tree unwritten;
#   subject: the world WITH the re-render, no record -> apply must refuse, tree unwritten.
# Exit 0 = apply refuses the re-rendered report (the defect is fixed). Exit 1 = apply WRITES (the
# defect is present). Exit 2 = the world could not be built or the control did not refuse (the receipt
# cannot discriminate). Exit 9 = the subject (apply.sh or emit-report.sh) cannot be found.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
R="$(cd "$(dirname "$0")/../../.." && pwd)"
REC="$R/core/skills/ai-dlc-update/reconcile"; [ -f "$REC/apply.sh" ] || REC="$R/.claude/skills/ai-dlc-update/reconcile"
[ -f "$REC/apply.sh" ] && [ -f "$REC/emit-report.sh" ] || { echo "receipt: subject absent" >&2; exit 9; }
W="$(mktemp -d "${TMPDIR:-/tmp}/ra-rerender.XXXXXX")" || exit 2
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
RPT="_bmad-output/ai-dlc-update/reconcile-report.md"
render() { { printf '# report\n\n'; bash "$REC/emit-report.sh" "$D" "$B" "$1" "$T" 2>/dev/null; } > "$1/$RPT"; }
# world <dir>: approve with a HARD blocker seeded, resolve it, leave one non-HARD row the approval never showed
world() {
  local c="$1"
  mkdir -p "$c/.claude/session-driver" "$c/scripts/ai-dlc" "$c/_bmad-output/ai-dlc-update" || return 1
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$c/.claude/session-driver/drv.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-r.sh"
  printf 'version: 1.0.0\ncommit: %s\n' "$B" > "$c/.claude/.ai-dlc-version"
  ovr "$c" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef probe || return 1
  render "$c"
  grep -q '^HARD-' "$c/$RPT" || return 1
  rm -f "$c/.claude/skills/ai-dlc/overrides/probe.md"
  ovr "$c" "$B" absent || return 1
  return 0
}
verify() { bash "$REC/emit-report.sh" --verify "$1/$RPT" "$D" "$B" "$1" "$T" >/dev/null 2>&1; }
written() { grep -q UPSTREAM "$1/.claude/session-driver/drv.sh"; }
applyit() { bash "$REC/apply.sh" "$D" "$B" "$1" "$T" > "$1/apply.out" 2>&1; }
# control: no re-render -> verify exit 3 and apply refuses with RE-APPROVAL OWED, unwritten
world "$W/ctl" || exit 2
verify "$W/ctl"; [ "$?" -eq 3 ] || exit 2
applyit "$W/ctl"; written "$W/ctl" && exit 2
grep -q 'RE-APPROVAL OWED' "$W/ctl/apply.out" || exit 2
# subject: same world, report region re-rendered by hand, no answer record
world "$W/sub" || exit 2
render "$W/sub"
[ ! -e "$W/sub/_bmad-output/operator-answers-history.md" ] || exit 2
cmp -s "$W/ctl/$RPT" "$W/sub/$RPT" && exit 2
applyit "$W/sub"
written "$W/sub" && { echo "re-render receipt: apply WROTE on a hand re-render with no re-approval" >&2; exit 1; }
echo "re-render receipt: PASS"
