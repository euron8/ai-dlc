#!/usr/bin/env bash
# Receipt: a session that resolves a blocker and then RE-RENDERS the approved report by hand (runs
# emit-report.sh and splices the fresh region over reconcile-report.md, with no answer record) must
# not get apply.sh to write. Before the first-verified region record, the re-render made
# `emit-report.sh --verify` exit 0, the union gate saw "match", and apply wrote without ever asking.
#
# Every world `git init`s the CONSUMER as its own toplevel (the record lives in its git-dir), renders
# with a HARD blocker seeded, runs a plain --verify once (asserting 0, which writes the record), then
# resolves the blocker leaving one non-HARD row the approval never showed. Driving the shipping
# apply.sh and emit-report.sh:
#   control:    no re-render. Plain --verify must still exit 3 after the `git init`; apply refuses
#               with RE-APPROVAL OWED and the tree is unwritten.
#   subject:    re-render, plain --verify (asserting 0; first-wins leaves the record as it was), apply.
#               It must REFUSE, and its output must CONTAIN `RE-APPROVAL OWED` and the full digest of
#               the fresh region, computed here from the report file. An unwritten tree alone is not
#               enough.
#   acceptance: the subject plus an AskUserQuestion record written by the real answer-capture hook
#               from exactly the question and option label apply PRINTED. Apply must write.
# Exit 0 = the defect is fixed. Exit 1 = apply WROTE on the re-render, or refused without saying
# why, or the acceptance arm could not write. Exit 2 = the world could not be built or the control
# did not hold (the receipt cannot discriminate). Exit 9 = the subject cannot be found.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset EMIT_REPORT_VERIFY_CACHE
R="$(cd "$(dirname "$0")/../../.." && pwd)"
REC="$R/core/skills/ai-dlc-update/reconcile"; [ -f "$REC/apply.sh" ] || REC="$R/.claude/skills/ai-dlc-update/reconcile"
HOOK="$R/core/hooks/ai-dlc-answer-capture.sh"; [ -f "$HOOK" ] || HOOK="$R/.claude/hooks/ai-dlc-answer-capture.sh"
[ -f "$REC/apply.sh" ] && [ -f "$REC/emit-report.sh" ] && [ -f "$HOOK" ] || { echo "receipt: subject absent" >&2; exit 9; }
command -v jq >/dev/null 2>&1 && command -v shasum >/dev/null 2>&1 || { echo "receipt: jq and shasum are required" >&2; exit 2; }
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
verify() { bash "$REC/emit-report.sh" --verify "$1/$RPT" "$D" "$B" "$1" "$T" >/dev/null 2>&1; }
written() { grep -q UPSTREAM "$1/.claude/session-driver/drv.sh"; }
applyit() { bash "$REC/apply.sh" "$D" "$B" "$1" "$T" > "$1/apply.out" 2>&1; }
# region_dg <consumer> -- sha256 of the report's GENERATED region as norm_dist leaves it, computed here
region_dg() {
  local r
  r="$(awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$1/$RPT" \
       | sed -E "s|git -C .* show ${T}:|git -C <dist> show ${T}:|g")"
  printf '%s\n' "$r" | shasum -a 256 | cut -d' ' -f1
}
# world <dir>: git toplevel, approve with a HARD blocker seeded (plain --verify 0 writes the record),
# resolve it, leave one non-HARD row the approval never showed
world() {
  local c="$1"
  mkdir -p "$c/.claude/session-driver" "$c/scripts/ai-dlc" "$c/_bmad-output/ai-dlc-update" || return 1
  git -C "$c" init -q || return 1
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$c/.claude/session-driver/drv.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-r.sh"
  printf 'version: 1.0.0\ncommit: %s\n' "$B" > "$c/.claude/.ai-dlc-version"
  ovr "$c" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef probe || return 1
  render "$c"
  grep -q '^HARD-' "$c/$RPT" || return 1
  verify "$c" || return 1
  rm -f "$c/.claude/skills/ai-dlc/overrides/probe.md"
  ovr "$c" "$B" absent || return 1
  return 0
}
# control: no re-render. Re-checked after the `git init`: plain --verify still exits 3, and apply
# refuses with RE-APPROVAL OWED, unwritten.
world "$W/ctl" || exit 2
verify "$W/ctl"; [ "$?" -eq 3 ] || exit 2
applyit "$W/ctl"; written "$W/ctl" && exit 2
grep -q 'RE-APPROVAL OWED' "$W/ctl/apply.out" || exit 2
# subject: same world, report region re-rendered by hand, plain --verify 0, no answer record
world "$W/sub" || exit 2
render "$W/sub"
[ ! -e "$W/sub/_bmad-output/operator-answers-history.md" ] || exit 2
cmp -s "$W/ctl/$RPT" "$W/sub/$RPT" && exit 2
verify "$W/sub" || exit 2
DG="$(region_dg "$W/sub")"
case "$DG" in *[!0-9a-f]*|'') exit 2 ;; esac; [ "${#DG}" -eq 64 ] || exit 2
applyit "$W/sub"
written "$W/sub" && { echo "re-render receipt: apply WROTE on a hand re-render with no re-approval" >&2; exit 1; }
grep -qF 'RE-APPROVAL OWED' "$W/sub/apply.out" && grep -qF -- "$DG" "$W/sub/apply.out" \
  || { echo "re-render receipt: apply refused the re-render without RE-APPROVAL OWED and the fresh region's digest" >&2; exit 1; }
# acceptance: the record the operator's answer writes, from exactly what apply printed
Q="$(sed -n 's/^  question: //p' "$W/sub/apply.out")"; L="$(sed -n 's/^  option label: //p' "$W/sub/apply.out")"
[ -n "$Q" ] && [ -n "$L" ] || { echo "re-render receipt: the refusal printed no question and option label" >&2; exit 1; }
jq -n --arg q "$Q" --arg a "$L" '{tool_name:"AskUserQuestion",session_id:"rcpt",tool_use_id:"rcpt-tu",tool_response:{answers:{($q):$a}}}' > "$W/payload.json" || exit 2
CLAUDE_PROJECT_DIR="$W/sub" bash "$HOOK" < "$W/payload.json" >/dev/null 2>&1
grep -q -- '-- AskUserQuestion$' "$W/sub/_bmad-output/operator-answers-history.md" 2>/dev/null || exit 2
applyit "$W/sub"
written "$W/sub" || { echo "re-render receipt: a re-approval recorded from apply's own question and label did not let it write" >&2; exit 1; }
echo "re-render receipt: PASS"
