#!/usr/bin/env bash
# resume-preflight.sh -- the mechanical snapshot-integrity checks of route.md Step 0a, run as one program.
#
# Usage: resume-preflight.sh [--root P] [--today YYYY-MM-DD]
#   --root P    project root holding _bmad-output/ (default: the working directory)
#   --today D   the date check 6 measures against (default: today, UTC)
#
# Checks, in order; the first failing one prints its verdict line and stops the run:
#   1 budget    verdict.sh validate-artifact-budget --only pipeline-snapshot.md exits 0
#   3 sections  the snapshot carries the six load-bearing headings (In-Flight Teammates is the seventh and
#               auto-heals; it is not checked here)
#   4 step-file current_step_file names a file that exists under .claude/skills/ai-dlc/steps/
#   5 branch    the branch the snapshot records equals `git branch --show-current` (quiet when none is recorded)
#   6 recency   last_gate_passed is no more than 7 days older than --today (quiet when no date is recorded)
#   7 stranded  NOT (sprint-status.yaml `status: done` AND current_step_file is deploy-validate.md)
# Check 2 (load the snapshot in full) is the lead's native chunked Read; this script reads the file for its own greps only.
#
# Output (stdout):
#   PREFLIGHT FAIL check <n> <name>: <detail> | replies: <the operator's reply set>
#   PREFLIGHT INFO <text>
#   PREFLIGHT OK checks 1,3,4,5,6,7 passed
# Exit: 0 every check passed; 1 a check failed (the operator's reply directs the next action); 2 refused (bad
# argument, no root, no readable snapshot).

rpf_main() {
  local ROOT="." TODAY="" here SNAP step_dir
  here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  while [ $# -gt 0 ]; do
    case "$1" in
      --root) ROOT="${2:-}"; [ -n "$ROOT" ] || { echo "resume-preflight: --root needs a value" >&2; return 2; }; shift 2 ;;
      --today) TODAY="${2:-}"; shift 2 ;;
      *) echo "usage: resume-preflight.sh [--root P] [--today YYYY-MM-DD]" >&2; return 2 ;;
    esac
  done
  [ -d "$ROOT" ] || { echo "resume-preflight: root is not a directory: $ROOT" >&2; return 2; }
  ROOT="$(cd "$ROOT" && pwd)"
  SNAP="$ROOT/_bmad-output/pipeline-snapshot.md"
  [ -r "$SNAP" ] || { echo "resume-preflight: no readable snapshot at $SNAP" >&2; return 2; }
  [ -n "$TODAY" ] || TODAY="$(date -u +%Y-%m-%d)"
  step_dir="$ROOT/.claude/skills/ai-dlc/steps"

  # --- check 1: budget
  local bv brc
  bv="$(cd "$ROOT" && bash "$here/verdict.sh" validate-artifact-budget --root "$ROOT" --only pipeline-snapshot.md 2>&1)"; brc=$?
  if [ "$brc" -ne 0 ]; then
    echo "PREFLIGHT FAIL check 1 snapshot-budget: validate-artifact-budget exited $brc: $(printf '%s\n' "$bv" | grep -v 'SKIP' | sed -n '1,4p' | tr '\n' ' ') | replies: apply the trim remedy the verdict names yourself and re-run this script; if it still fails: archive, abort, or name what to move"
    return 1
  fi

  # --- check 3: the six sections, by heading
  local sec missing=""
  for sec in 'Pipeline Position' 'Sprint Context' 'Recent Activity' 'Open Items' 'Locked Decisions' 'Context Reminders'; do
    grep -qiE "^#{1,6}[[:space:]]+[*\`]*${sec}" "$SNAP" || missing="${missing:+$missing, }$sec"
  done
  if [ -n "$missing" ]; then
    echo "PREFLIGHT FAIL check 3 sections: snapshot is missing section(s): $missing | replies: archive, edit, abort"
    return 1
  fi

  # --- check 4: current_step_file names a file on disk (same key grammar and reduction as ai-dlc-recover.sh)
  local pos bullets val base
  pos="$(awk '/^## Pipeline Position/{f=1;next} /^## /{f=0} f' "$SNAP")"
  bullets="$(printf '%s\n' "$pos" | grep -iE '^[[:space:]]*-[^:]*current.step.file[^:]*:' | grep -ivE '^[^:]*(prior|superseded|retained history)')"
  local bl bb distinct=""
  while IFS= read -r bl; do
    [ -n "$bl" ] || continue
    bb="$(printf '%s\n' "$bl" | sed -E 's/^[^:]*://; s/^[-*[:space:]]+//' | sed -E 's/^`([^`]+)`.*/\1/; s/^[`*]+//' | awk '{print $1}' | sed 's/[`*,.;:)]*$//; s|^.*/||')"
    case " $distinct " in *" $bb "*) ;; *) distinct="$distinct $bb" ;; esac
  done <<EOF
$bullets
EOF
  case "${distinct# }" in *" "*)
    echo "PREFLIGHT FAIL check 4 step-file: the Pipeline Position names two different step files:${distinct} | replies: archive, override <correct-step-file>, abort"
    return 1 ;;
  esac
  base="${distinct# }"
  if [ -z "$base" ] || [ ! -f "$step_dir/$base" ]; then
    echo "PREFLIGHT FAIL check 4 step-file: snapshot references current_step_file: ${base:-<none>} but $step_dir/${base:-<none>} does not exist | replies: archive, override <correct-step-file>, abort"
    return 1
  fi

  # --- check 5: recorded branch equals the current branch
  local rec cur
  rec="$(printf '%s\n' "$pos"; awk '/^## Recent Activity/{f=1;next} /^## /{f=0} f' "$SNAP")"
  rec="$(printf '%s\n' "$rec" | grep -m1 -iE '^[[:space:]]*[-*]*[[:space:]]*[*`]*(current_|git_|finalized_)?branch[*`]*[[:space:]]*:' \
    | sed -E 's/^[^:]*://; s/^[[:space:]*`]+//; s/[[:space:]*`].*$//')"
  if [ -n "$rec" ]; then
    cur="$(git -C "$ROOT" branch --show-current 2>/dev/null)"
    if [ "$cur" != "$rec" ]; then
      echo "PREFLIGHT FAIL check 5 branch: snapshot was finalized on branch $rec but the current branch is ${cur:-<detached>} | replies: switch (git checkout $rec and resume), continue-here (resume here and record it with snapshot-update.sh --set branch ${cur:-<branch>} 'Pipeline Position'), abort"
      return 1
    fi
  else
    echo "PREFLIGHT INFO check 5 branch: the snapshot records no branch; the check is skipped"
  fi

  # --- check 6: last_gate_passed older than 7 days
  local gd ge te days
  gd="$(grep -m1 -iE 'last_gate_passed' "$SNAP" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sed -n '1p')"
  if [ -n "$gd" ]; then
    ge="$(date -u -j -f '%Y-%m-%d' "$gd" +%s 2>/dev/null || date -u -d "$gd" +%s 2>/dev/null)"
    te="$(date -u -j -f '%Y-%m-%d' "$TODAY" +%s 2>/dev/null || date -u -d "$TODAY" +%s 2>/dev/null)"
    if [ -z "$ge" ] || [ -z "$te" ]; then
      echo "resume-preflight: cannot parse date (gate $gd, today $TODAY)" >&2
      return 2
    fi
    days=$(( (te - ge) / 86400 ))
    if [ "$days" -gt 7 ]; then
      echo "PREFLIGHT FAIL check 6 recency: the snapshot's last gate was $days days ago; pipeline state may be stale relative to the code and external systems | replies: proceed, archive, or provide additional context"
      return 1
    fi
  else
    echo "PREFLIGHT INFO check 6 recency: the snapshot records no last_gate_passed date; the check is skipped"
  fi

  # --- check 7: stranded at deploy-validate.md on a closed sprint (BOTH clauses are required)
  local st spr
  if [ -f "$ROOT/_bmad-output/implementation-artifacts/sprint-status.yaml" ]; then
    st="$(sed -n 's/^status:[[:space:]]*//p' "$ROOT/_bmad-output/implementation-artifacts/sprint-status.yaml" | sed -n '1p' | sed -E "s/[[:space:]]*#.*$//; s/[\"' ]//g")"
    if [ "$st" = done ] && [ "$base" = deploy-validate.md ]; then
      spr="$(grep -m1 -iE '^(sprint_id|sprint):' "$ROOT/_bmad-output/implementation-artifacts/sprint-status.yaml" | sed -E 's/^[^:]*:[[:space:]]*//; s/[^0-9A-Za-z._-]//g')"
      echo "PREFLIGHT FAIL check 7 stranded: current_step_file is deploy-validate.md but sprint-status.yaml records sprint ${spr:-?} as status: done; the sprint shipped and the snapshot was never advanced | replies: archive, proceed, abort"
      return 1
    fi
  fi

  echo "PREFLIGHT OK checks 1,3,4,5,6,7 passed"
  return 0
}
# Executed, it runs; sourced, it has defined rpf_main and returns.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
rpf_main "$@"
exit $?
