#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/preamble.sh"
# resume-preflight -- core/scripts/resume-preflight.sh runs route.md Step 0a's mechanical checks (1 budget, 3 sections,
# 4 step file, 5 branch, 6 recency, 7 stranded) and prints one verdict line naming the failing check and the operator's
# reply set.
#
# Usage: run.sh        Exit: 0 = every assertion holds, 1 = a regression, 2 = fixture broken.
#
# ONE WORLD, MANY STATES. A scratch repository on branch main carries a snapshot at retro.md, branch main, a gate dated
# 2026-11-13, and a sprint-status.yaml saying `status: done`; the passing state is that world with --today 2026-11-20
# (a gate exactly 7 days old). Every failing state moves ONE field of it: the recorded branch, today (8 days), the step
# file (deploy-validate.md with status done), a missing heading, a step file absent from disk, an over-budget
# snapshot. The near-misses: exactly 7 days (quiet), `done` at retro.md (quiet; the second clause of check 7),
# deploy-validate.md with status `active` (quiet; the first clause).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ=""
for c in "$HERE/../../scripts/resume-preflight.sh" "$HERE/../../../scripts/ai-dlc/resume-preflight.sh"; do
  [ -f "$c" ] && { SUBJ="$c"; break; }
done
[ -n "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate resume-preflight.sh in either layout" >&2; exit 2; }
SUBJ="$(cd "$(dirname "$SUBJ")" && pwd)/$(basename "$SUBJ")"
echo "HERMETIC-CONSUMED $SUBJ"
[ -f "$(dirname "$SUBJ")/verdict.sh" ] && [ -f "$(dirname "$SUBJ")/validate-artifact-budget.sh" ] \
  || { echo "FIXTURE BROKEN: verdict.sh or validate-artifact-budget.sh is not beside the subject" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "FIXTURE BROKEN: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/report.sh"
. "$HERE/../lib/world.sh" || { echo "FIXTURE BROKEN: cannot source lib/world.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/world.sh"
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

grep -qxF 'rpf_main() {' "$SUBJ"; g1=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$SUBJ"; g2=$?
[ "$g1" -le 1 ] && [ "$g2" -le 1 ] || { echo "FIXTURE BROKEN: cannot read $SUBJ" >&2; exit 2; }
if [ "$g1$g2" != 00 ]; then
  bad "$SUBJ lacks the in-process wrap (rpf_main line: rc $g1, column-0 source guard: rc $g2)"
  report_end resume-preflight
fi
fx_inproc "$SUBJ"
. "$SUBJ" || { echo "FIXTURE BROKEN: sourcing $SUBJ failed" >&2; exit 2; }
declare -F rpf_main >/dev/null || { echo "FIXTURE BROKEN: sourcing $SUBJ defined no rpf_main" >&2; exit 2; }
rpf_ip() {
  fx_inproc "$SUBJ"
  rpf_main "$@"
}

# mk <name> <step-file> <branch> <status> -> a world at $WORK/<name>
mk() {
  local d="$WORK/$1"
  world_repo "$d" >/dev/null || { echo "FIXTURE BROKEN: world_repo failed" >&2; exit 2; }
  mkdir -p "$d/_bmad-output/implementation-artifacts" "$d/.claude/skills/ai-dlc/steps"
  : > "$d/.claude/skills/ai-dlc/steps/retro.md"; : > "$d/.claude/skills/ai-dlc/steps/deploy-validate.md"
  cat > "$d/_bmad-output/pipeline-snapshot.md" <<EOS
# Pipeline Snapshot
## Pipeline Position
- current_step_file: \`$2\`
- branch: $3
- last_gate_passed: sprint-review @ 2026-11-13T10:00:00Z
## Sprint Context
sprint_id: 7
## Recent Activity
- shipped
## Open Items
- none
## Locked Decisions
- none
## Context Reminders
- none
EOS
  printf 'sprint_id: 7\nstatus: %s\n' "$4" > "$d/_bmad-output/implementation-artifacts/sprint-status.yaml"
}
# run <world> [today] -> OUT, RC
run() { OUT="$(rpf_ip --root "$WORK/$1" --today "${2:-2026-11-20}" 2>&1)"; RC=$?; }
# want <label> <rc> <needle...>: rc exact, every needle in OUT
want() {
  local label="$1" rc="$2" n; shift 2
  [ "$RC" = "$rc" ] || { bad "$label: rc=$RC want $rc out=[$OUT]"; return; }
  for n in "$@"; do
    case "$OUT" in *"$n"*) ;; *) bad "$label: output lacks [$n]: [$OUT]"; return ;; esac
  done
  ok "$label"
}

mk good retro.md main done
run good;               want "all six checks pass; done at retro.md stays quiet (check 7 second clause), gate exactly 7 days old stays quiet" 0 "PREFLIGHT OK"
case "$OUT" in *FAIL*) bad "the passing world printed a FAIL: [$OUT]" ;; *) ok "the passing world prints no FAIL line" ;; esac
run good 2026-11-21;    want "an 8-day-old gate fails check 6 naming the days and the reply set" 1 "FAIL check 6 recency" "8 days" "replies: proceed, archive"

mk branch retro.md feature/x done
run branch;             want "a snapshot finalized on another branch fails check 5 with switch, continue-here, abort" 1 "FAIL check 5 branch" "feature/x" "replies: switch" "continue-here" "abort"

mk stranded deploy-validate.md main done
run stranded;           want "deploy-validate.md with status done fails check 7" 1 "FAIL check 7 stranded" "sprint 7" "replies: archive, proceed, abort"
mk active deploy-validate.md main active
run active;             want "deploy-validate.md with status active stays quiet (check 7 first clause)" 0 "PREFLIGHT OK"

mk nostep gone.md main done
run nostep;             want "a current_step_file absent from disk fails check 4" 1 "FAIL check 4 step-file" "gone.md" "override <correct-step-file>"

mk nosec retro.md main done
sed '/^## Locked Decisions/,/^- none/d' "$WORK/nosec/_bmad-output/pipeline-snapshot.md" > "$WORK/nosec/s.tmp" && mv "$WORK/nosec/s.tmp" "$WORK/nosec/_bmad-output/pipeline-snapshot.md"
run nosec;              want "a missing load-bearing section fails check 3 naming it" 1 "FAIL check 3 sections" "Locked Decisions" "replies: archive, edit, abort"

mk big retro.md main done
for i in $(seq 1 450); do echo "- filler line $i filler filler filler filler filler filler filler filler filler"; done >> "$WORK/big/_bmad-output/pipeline-snapshot.md"
run big;                want "an over-budget snapshot fails check 1 first, with the trim reply set" 1 "FAIL check 1 snapshot-budget" "replies: apply the trim remedy"

mkdir -p "$WORK/nowhere"
run nowhere;            want "a root with no snapshot is refused with exit 2" 2 "no readable snapshot"

report_end resume-preflight 10
