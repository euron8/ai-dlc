#!/usr/bin/env bash
# held-stories/run.sh -- drive the REAL validate-held-stories.sh, through the REAL sibling
# `sprint-status.sh list-stories`, against seeded sprint worlds.
#
# THE SUBJECT (BL-839). On the reference consumer's s320 the lead held stories 2.1 and 2.2 behind a
# tolerance amendment that never landed. The hold lived only in the lead's context; nothing at a
# wave join or at implementation's exit saw two ready-for-dev stories that were neither in flight nor
# held. The validator's grammar and contract are in its own header; this fixture does not restate
# them.
#
# ARMS (every world is a fresh root; stories 1.1 done, 1.3 and 2.1 ready-for-dev, file stems carry
# `<epic>-<index>` and the yaml keys are story-320-<M>, so the two spellings differ):
#   h1   the s320 shape: 1.3 dispatched (an In-Flight row whose DELIVERABLE carries its file stem),
#        2.1 held by yaml key -> exit 0 and the OK line names 3 stories
#   h2   h1 with the hold line deleted -> exit 1, UNACCOUNTED story-320-4 (2.1)
#   h3   2.1 moved to review, hold kept -> exit 1, STALE-HOLD story-320-4 (2.1)
#   h4   a hold line with no `since` -> exit 1, MALFORMED-HOLD
#   h5   no snapshot -> exit 2; also no `## Open Items` -> exit 2, and no yaml (list-stories exit 2) -> exit 2
#   h6   1.3 accounted by a row whose ROLE names `story 1.3` -> exit 0
#   h6b  the row names `story 1.30` instead -> exit 1, UNACCOUNTED story-320-3 (1.3) (boundary near-miss)
#   h6n  1.3 dispatched in spawn-ledger.jsonl only, no row, no hold -> exit 1, UNACCOUNTED (the ledger is never read)
#   h7   the 2.1 hold is 16h old -> exit 1, AGED-HOLD story-320-4 (2.1) 16h (the amendment that never lands)
#   h7n  the 2.1 hold is 1h old -> exit 0
#   h8   a wave-2 story 2.2 held `until 1.3 passes gate 3` -> exit 0, 4 stories
#   h9   `held: 2.1 ...` matches yaml key story-320-4 whose file is story-2-1-*.md -> exit 0
#   h0   a `stories:` key with no entries (list-stories exit 0, empty output) -> exit 0, 0 stories
#   s3   BL-1015, the sub-step site: the sibling snapshot-update.sh writes one --activity line into the
#        h2 world -> the line is written, exit 0, and its output carries UNACCOUNTED story-320-4 (2.1)
#        and the WAS-written line
#   s3n  the same write into the h1 world -> exit 0 and the OK line, no UNACCOUNTED
#   S1   implementation.md section 7 carries the validator's invocation line
#   S2   ai-dlc-recover.sh's verification turn names every `held:` Open Item
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
VAL=""; SS=""; SCHEMA=""; SU=""; VAB=""
for d in "$ROOT/core/scripts" "$ROOT/scripts/ai-dlc"; do
  if [ -f "$d/validate-held-stories.sh" ] && [ -f "$d/sprint-status.sh" ] && [ -f "$d/snapshot-update.sh" ] && [ -f "$d/validate-artifact-budget.sh" ]; then
    VAL="$d/validate-held-stories.sh"; SS="$d/sprint-status.sh"; SU="$d/snapshot-update.sh"; VAB="$d/validate-artifact-budget.sh"; break
  fi
done
for s in "$ROOT/core/schemas/sprint-status.json" "$ROOT/.claude/schemas/sprint-status.json"; do
  [ -f "$s" ] && { SCHEMA="$s"; break; }
done
[ -n "$VAL" ] && [ -n "$SCHEMA" ] || { echo "FIXTURE ERROR: validate-held-stories.sh, sprint-status.sh, snapshot-update.sh, validate-artifact-budget.sh and sprint-status.json not found together in either layout" >&2; exit 2; }
printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$VAL" "$SS" "$SCHEMA"
printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$SU" "$VAB"
# The sibling resolves its schema script-relative first; a mutant copy carries schemas/ beside it,
# and the override makes both layouts read the one schema this fixture resolved.
export AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/held-stories.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# IN PROCESS (BL-878). validate-held-stories.sh and snapshot-update.sh are the two top-level subjects, loaded once each and
# asked through inproc_run (vhs_drive, snu_drive). Every nested start they make (snapshot-update.sh starts the budget
# validator and the held-stories validator, which starts sprint-status.sh) goes through the `bash` shim below, which runs
# the subject's entry in a subshell made fresh the way inproc_run makes one. A core fixture ships ahead of its subjects: a
# subject with neither the `<p>_main() {` line nor the column-0 source guard predates the wrap and SKIPs (FIXTURE BROKEN in
# the distribution); exactly one half FAILs; an unreadable subject is FIXTURE ERROR.
hs_halves() { # <file> <entry> -> "<def><guard>"
  local d=0 g=0 x
  grep -qxF "$2() {" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
hs_pre=""
hs_gate() { # hs_gate <file>:<entry> -- one call line per wrapped subject, so each carries its own gate
  local _s="$1" _h
  _h="$(hs_halves "${_s%%:*}" "${_s##*:}")" || exit 2
  case "$_h" in
    11) : ;;
    00) hs_pre="$hs_pre ${_s%%:*}" ;;
    *) bad "${_s%%:*} carries one half of the in-process wrap (${_s##*:} line, column-0 source guard: $_h) -- a respelled subject this fixture cannot drive"
       report_end held-stories ;;
  esac
}
hs_gate "$VAL:vhs_main"
hs_gate "$SS:ss_main"
hs_gate "$SU:snu_main"
hs_gate "$VAB:vab_main"
if [ -n "$hs_pre" ]; then echo "SKIP: subject predates the in-process wrap:$hs_pre"; fx_skip_exit "$HERE"; fi

. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found" >&2; exit 2; }
export FX_VAB="$VAB" FX_VHS="$VAL" FX_SS="$SS" # exported: inproc_run keeps exported variables and drops the rest
bash() { # a subject's own `bash <sibling>` start of one of the three validators runs its entry in a fresh-options subshell; any other start is real
  local _p="${1:-}" _e=""
  case "$_p" in
    "$FX_VAB") _e=vab_main ;;
    "$FX_VHS") _e=vhs_main ;;
    "$FX_SS") _e=ss_main ;;
  esac
  if [ -z "$_e" ]; then command bash "$@"; return; fi
  shift
  (
    _x=" $(compgen -e) "; _x="${_x//$'\n'/ }"
    for _v in $(compgen -v); do
      case "$_x" in *" $_v "*) continue ;; esac
      case "$_v" in
        _x|_v|_e|_p) continue ;;
        BASH|BASH_*|BASHOPTS|BASHPID|COMP_WORDBREAKS|DIRSTACK|EUID|FUNCNAME|GROUPS|HISTCMD|HOSTNAME|HOSTTYPE) continue ;;
        IFS|LINENO|MACHTYPE|OPTERR|OPTIND|OSTYPE|PIPESTATUS|PPID|PS4|PWD|OLDPWD|RANDOM|SECONDS|SHELL|SHELLOPTS) continue ;;
        SHLVL|TERM|UID|_) continue ;;
      esac
      unset "$_v" 2>/dev/null
    done
    OPTIND=1; set +eufx +o pipefail; hash -r
    case "$_e" in
      vab_main) ! declare -F fx_inproc >/dev/null 2>&1 || fx_inproc "$_p"; . "$_p" && vab_main "$@" ;;
      vhs_main) ! declare -F fx_inproc >/dev/null 2>&1 || fx_inproc "$_p"; . "$_p" && vhs_main "$@" ;;
      ss_main) ! declare -F fx_inproc >/dev/null 2>&1 || fx_inproc "$_p"; . "$_p" && ss_main "$@" ;;
    esac
  )
}
inproc_load "$VAL" || { echo "FIXTURE ERROR: $VAL defines no vhs_main (not loadable)" >&2; exit 2; }
HS_VHS_FNS="${INPROC_FNS}bash "
inproc_load "$SU" || { echo "FIXTURE ERROR: $SU defines no snu_main (not loadable)" >&2; exit 2; }
HS_SNU_FNS="${INPROC_FNS}bash "
# inproc_run strips every function the loaded subject did not define; use_subj selects which loaded subject is current and
# names the shim with its set (inproc_run then checks the set's definitions are unchanged, and bash is part of it).
use_subj() {
  case "$1" in
    vhs) INPROC_LOADED="$VAL"; INPROC_FNS="$HS_VHS_FNS" ;;
    snu) INPROC_LOADED="$SU"; INPROC_FNS="$HS_SNU_FNS" ;;
  esac
  INPROC_DEFS="$(declare -f $INPROC_FNS)"
}
vhs_drive() { use_subj vhs; inproc_run "$VAL" vhs_main "$@"; } # <validator args> -> its answer, in process
snu_drive() { use_subj snu; inproc_run "$SU" snu_main "$@"; }  # <snapshot-update args> -> its answer, in process

NOW=1793200000
export AI_DLC_NOW="$NOW"
SP="_bmad-output/planning-artifacts/s320/stories"

# world <dir> <2.1 status> [extra yaml entry: 2.2] -> a root with .claude/ and the implementation yaml
world() {
  local w="$1"
  mkdir -p "$w/.claude" "$w/_bmad-output/implementation-artifacts"
  {
    printf 'sprint: 320\nname: "s"\nvariant: carry-over\nstatus: in_progress\nstories:\n'
    printf '  story-320-1:\n    status: done\n    file: %s/story-1-1-a-sweep-row.md\n' "$SP"
    printf '  story-320-3:\n    status: ready-for-dev\n    file: %s/story-1-3-each-dated-monitor.md\n' "$SP"
    printf '  story-320-4:\n    status: %s\n    file: %s/story-2-1-read-one-active-position.md\n' "$2" "$SP"
    [ "${3:-}" = with22 ] && printf '  story-320-5:\n    status: ready-for-dev\n    file: %s/story-2-2-correct-the-aggregator.md\n' "$SP"
  } > "$w/_bmad-output/implementation-artifacts/sprint-status.yaml"
}
# snap <dir> <open-items lines (\n-separated, may be empty)> <in-flight rows (may be empty)>
snap() {
  {
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n- current_step_file: implementation.md\n\n'
    printf '## Recent Activity\n\n'
    printf '## Open Items\n- fan-out round story-320-3 since 2026-10-27T21:14Z\n'
    [ -n "$2" ] && printf '%s\n' "$2"
    printf '\n## In-Flight Teammates\nteammate | role | deliverable | dispatched-at | status\n--- | --- | --- | --- | ---\n'
    [ -n "$3" ] && printf '%s\n' "$3"
    printf '\n## Context Reminders\n- context_reminders_sent: none\n'
  } > "$1/_bmad-output/pipeline-snapshot.md"
}
ROW_DELIV='a18da3c11dffb05ab | ops reads (AC1/2/3) | /w/graph-s320-story-1-3/_bmad-output/implementation-artifacts/s320/dev-report-story-1-3.md | 2026-10-27T19:54:23Z | delivered-reachable'
ROW_ROLE='ae0266c9c421f266a | code-reviewer gate 1 story 1.3 part 1/4 | /w/shards/1.md | 2026-10-27T21:14:47Z | in-flight'
ROW_130='ae0266c9c421f266a | code-reviewer gate 1 story 1.30 part 1/4 | /w/shards/1.md | 2026-10-27T21:14:47Z | in-flight'
HOLD_KEY="- held: story-320-4 until the 2.1 tolerance amendment lands since $((NOW - 600))"

RC=""; OUT=""
drive() { OUT="$(AI_DLC_PROJECT_ROOT="$2" vhs_drive --root "$2" 2>&1)"; RC=$?; }
has() { grep -qxF -- "$1" <<<"$OUT"; }
# su_drive <validator path> <world>: snapshot-update.sh (in process) writes one
# --activity line into the world's snapshot (the sub-step site's story-transition write)
ACT_LINE='2026-10-27T21:20Z story 2.1 transition observed'
su_drive() {
  OUT="$(AI_DLC_PROJECT_ROOT="$2" snu_drive --snapshot "$2/_bmad-output/pipeline-snapshot.md" --activity "$ACT_LINE" 2>&1)"; RC=$?
  grep -qxF -- "- $ACT_LINE" "$2/_bmad-output/pipeline-snapshot.md"
}

# arm <program> <name> -> builds the arm's world, drives it, sets A_<name>=1 on the expected outcome
arm() {
  local pr="$1" n="$2" w="$WORK/$3-$2"
  case "$n" in
    h1)  world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" ;;
    h2)  world "$w" ready-for-dev; snap "$w" "" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'UNACCOUNTED story-320-4 (2.1)' && ! grep -q 'story-320-3' <<<"$OUT" ;;
    h3)  world "$w" review; snap "$w" "$HOLD_KEY" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'STALE-HOLD story-320-4 (2.1)' ;;
    h4)  world "$w" ready-for-dev; snap "$w" "- held: story-320-4 until the 2.1 tolerance amendment lands" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'MALFORMED-HOLD - held: story-320-4 until the 2.1 tolerance amendment lands' ;;
    h6)  world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_ROLE"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" ;;
    h6b) world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_130"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'UNACCOUNTED story-320-3 (1.3)' ;;
    h6n) world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" ""
         printf '{"agent_id":"a18da3c11dffb05ab","role":"dev","story":"story-1-3","deliverable":"dev-report-story-1-3.md"}\n' > "$w/_bmad-output/spawn-ledger.jsonl"
         drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'UNACCOUNTED story-320-3 (1.3)' ;;
    h7)  world "$w" ready-for-dev; snap "$w" "- held: story-320-4 until the 2.1 tolerance amendment lands since $((NOW - 16 * 3600))" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'AGED-HOLD story-320-4 (2.1) 16h' ;;
    h7n) world "$w" ready-for-dev; snap "$w" "- held: story-320-4 until the 2.1 tolerance amendment lands since $((NOW - 3600))" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" ;;
    h8)  world "$w" ready-for-dev with22
         snap "$w" "$HOLD_KEY"$'\n'"- held: story-320-5 until 1.3 passes gate 3 since $((NOW - 600))" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 4 stories' <<<"$OUT" ;;
    h0)  mkdir -p "$w/.claude" "$w/_bmad-output/implementation-artifacts"
         printf 'sprint: 321\nname: "s"\nvariant: carry-over\nstatus: in_progress\nstories:\n' > "$w/_bmad-output/implementation-artifacts/sprint-status.yaml"
         snap "$w" "" ""; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 0 stories' <<<"$OUT" ;;
    h9)  world "$w" ready-for-dev; snap "$w" "- held: 2.1 until the 2.1 tolerance amendment lands since $((NOW - 600))" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" ;;
    s3)  world "$w" ready-for-dev; snap "$w" "" "$ROW_DELIV"; su_drive "$pr" "$w" \
           && [ "$RC" = 0 ] && has 'UNACCOUNTED story-320-4 (2.1)' \
           && grep -q '^snapshot-update: the snapshot WAS written; do not re-run this call' <<<"$OUT" ;;
    s3n) world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_DELIV"; su_drive "$pr" "$w" \
           && [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" && ! grep -q 'UNACCOUNTED' <<<"$OUT" ;;
    *)   return 1 ;;
  esac
}

echo "held-stories:"
echo "  subject: $VAL"

for spec in \
  "h1|the s320 shape (1.3 by a row's deliverable stem, 2.1 held by key) is clean" \
  "h2|the hold deleted reports UNACCOUNTED story-320-4 (2.1) and nothing for the dispatched 1.3" \
  "h3|a hold on a story at review reports STALE-HOLD" \
  "h4|a hold with no since is MALFORMED-HOLD" \
  "h6|a row whose role names story 1.3 accounts it" \
  "h6b|a row naming story 1.30 does not account 1.3" \
  "h6n|a ledger-only dispatch is still UNACCOUNTED" \
  "h7|a 16h-old hold reports AGED-HOLD 16h" \
  "h7n|a 1h-old hold is quiet" \
  "h8|a wave-2 story held until 1.3 passes gate 3 is accounted" \
  "h9|held: 2.1 matches yaml key story-320-4 through its file stem" \
  "h0|a sprint with no story entries (list-stories exit 0, empty) is clean with 0 stories" \
  "s3|snapshot-update.sh --activity on the h2 world writes the line, exits 0 and prints UNACCOUNTED story-320-4 (2.1)" \
  "s3n|snapshot-update.sh --activity on the h1 world writes the line and prints the OK line, no UNACCOUNTED"; do
  n="${spec%%|*}"; msg="${spec#*|}"
  if arm "$VAL" "$n" ship; then ok "$n: $msg"; eval "A_$n=1"
  else bad "$n: $msg (rc=$RC: $(tr '\n' ' ' <<<"$OUT"))"; eval "A_$n=0"; fi
done

# h5: unevaluable inputs are exit 2, never a pass
w="$WORK/h5-nosnap"; world "$w" ready-for-dev; drive "$VAL" "$w"
[ "$RC" = 2 ] && grep -q 'no snapshot' <<<"$OUT" && ok "h5: no snapshot is exit 2" || bad "h5: no snapshot rc=$RC $OUT"
w="$WORK/h5-nooi"; world "$w" ready-for-dev
printf '# Pipeline Snapshot\n\n## In-Flight Teammates\nteammate | role | deliverable | dispatched-at | status\n--- | --- | --- | --- | ---\n' > "$w/_bmad-output/pipeline-snapshot.md"
drive "$VAL" "$w"
[ "$RC" = 2 ] && grep -q 'Open Items' <<<"$OUT" && ok "h5: no Open Items section is exit 2" || bad "h5: no Open Items rc=$RC $OUT"
w="$WORK/h5-noyaml"; world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_DELIV"
rm "$w/_bmad-output/implementation-artifacts/sprint-status.yaml"
drive "$VAL" "$w"
[ "$RC" = 2 ] && grep -q 'list-stories exited 2' <<<"$OUT" && ok "h5: list-stories unevaluable (no yaml) is exit 2" || bad "h5: no yaml rc=$RC $OUT"

# --- S-arms: the two prose carriers this validator relies on ----------------
# Each resolves its subject in both layouts and first proves its section was found, so a moved
# heading reads FIXTURE BROKEN rather than a clean absence.
IMPL_MD=""; RECOVER=""
for f in "$ROOT/core/skills/ai-dlc/steps/implementation.md" "$ROOT/.claude/skills/ai-dlc/steps/implementation.md"; do [ -f "$f" ] && { IMPL_MD="$f"; break; }; done
for f in "$ROOT/core/hooks/ai-dlc-recover.sh" "$ROOT/.claude/hooks/ai-dlc-recover.sh"; do [ -f "$f" ] && { RECOVER="$f"; break; }; done
if [ -z "$IMPL_MD" ] || [ -z "$RECOVER" ]; then
  bad "FIXTURE BROKEN: implementation.md or ai-dlc-recover.sh not found in either layout"
else
  printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$IMPL_MD" "$RECOVER"
  S7="$(awk '/^### 7\. All Gates Passed$/ { on = 1 } on && /^\*\*READ AND FOLLOW:\*\*/ { exit } on { print }' "$IMPL_MD")"
  if [ -z "$S7" ]; then bad "FIXTURE BROKEN: implementation.md has no '### 7. All Gates Passed' section"
  elif grep -qxF 'Run `scripts/ai-dlc/validate-held-stories.sh`; a STALE-HOLD blocks the exit.' <<<"$S7"; then
    ok "S1: implementation.md section 7 runs validate-held-stories.sh before its exit"
  else bad "S1: implementation.md section 7 no longer runs validate-held-stories.sh"; fi
  VT="$(awk '/^Before acting, emit a verification turn naming:/ { on = 1 } on && /^$/ { exit } on { print }' "$RECOVER" | tr '\n' ' ')"
  if [ -z "$VT" ]; then bad "FIXTURE BROKEN: ai-dlc-recover.sh has no verification-turn paragraph"
  elif grep -qF 'state below, \`held:\`, and' <<<"$VT"; then
    ok "S2: ai-dlc-recover.sh's verification turn names every held: Open Item"
  else bad "S2: ai-dlc-recover.sh's verification turn no longer names the held: Open Items"; fi
fi

# --- the cli cells (cells.decl): each program run as a PROGRAM once per distinct CLI outcome ----------------------
# One `FXCELL=<id> bash <subject>` start per outcome, compared with the in-process answer on the same input (stdout+stderr
# merged, exit, and for snapshot-update the resulting snapshot), each reading the SAME world path restored between the two runs.
EQ="$WORK/eq"; mkdir -p "$EQ"
cell_vhs() { # <id> <world>
  local id="$1" w="$2"
  ( AI_DLC_PROJECT_ROOT="$w" vhs_drive --root "$w" ) > "$EQ/$id.ip.out" 2>&1; echo "$?" > "$EQ/$id.ip.rc"
  ( AI_DLC_PROJECT_ROOT="$w" FXCELL="$id" command bash "$VAL" --root "$w" ) > "$EQ/$id.cl.out" 2>&1; echo "$?" > "$EQ/$id.cl.rc"
}
cell_snu() { # <id> <world>
  local id="$1" w="$2" snapf="$2/_bmad-output/pipeline-snapshot.md"
  cp "$snapf" "$EQ/$id.pre"
  ( AI_DLC_PROJECT_ROOT="$w" snu_drive --snapshot "$snapf" --activity "$ACT_LINE" ) > "$EQ/$id.ip.out" 2>&1; echo "$?" > "$EQ/$id.ip.rc"
  cp "$snapf" "$EQ/$id.ip.snap"; cp "$EQ/$id.pre" "$snapf"
  ( AI_DLC_PROJECT_ROOT="$w" FXCELL="$id" command bash "$SU" --snapshot "$snapf" --activity "$ACT_LINE" ) > "$EQ/$id.cl.out" 2>&1; echo "$?" > "$EQ/$id.cl.rc"
  cp "$snapf" "$EQ/$id.cl.snap"
}
same_cell() { cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"; }
w="$WORK/cell-vhs-ok"; world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_DELIV"; cell_vhs cli-vhs-ok "$w"
w="$WORK/cell-vhs-fail"; world "$w" ready-for-dev; snap "$w" "" "$ROW_DELIV"; cell_vhs cli-vhs-fail "$w"
w="$WORK/cell-vhs-unev"; world "$w" ready-for-dev; cell_vhs cli-vhs-unev "$w"
w="$WORK/cell-snu-ok"; world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_DELIV"; cell_snu cli-snu-ok "$w"
w="$WORK/cell-snu-warn"; world "$w" ready-for-dev; snap "$w" "" "$ROW_DELIV"; cell_snu cli-snu-warn "$w"
for c in "cli-vhs-ok 0 held-stories: OK" "cli-vhs-fail 1 UNACCOUNTED story-320-4" "cli-vhs-unev 2 no snapshot"; do
  set -- $c; id="$1"; rc="$2"; shift 2
  if same_cell "$id" && [ "$(cat "$EQ/$id.cl.rc")" = "$rc" ] && grep -qF -- "$*" "$EQ/$id.cl.out"; then ok "$id: validate-held-stories.sh as a program matches the in-process answer (exit $rc, names '$*')"
  else bad "$id: the program and the in-process call disagree (rc cl=$(cat "$EQ/$id.cl.rc") ip=$(cat "$EQ/$id.ip.rc"))"; fi
done
for c in "cli-snu-ok held-stories: OK" "cli-snu-warn UNACCOUNTED story-320-4"; do
  set -- $c; id="$1"; shift
  if same_cell "$id" && cmp -s "$EQ/$id.ip.snap" "$EQ/$id.cl.snap" && [ "$(cat "$EQ/$id.cl.rc")" = 0 ] && grep -qF -- "$*" "$EQ/$id.cl.out" \
     && grep -qxF -- "- $ACT_LINE" "$EQ/$id.cl.snap"; then ok "$id: snapshot-update.sh as a program matches the in-process answer and snapshot (exit 0, names '$*')"
  else bad "$id: the program and the in-process call disagree (rc cl=$(cat "$EQ/$id.cl.rc") ip=$(cat "$EQ/$id.ip.rc"))"; fi
done
if ! cmp -s "$EQ/cli-snu-ok.cl.out" "$EQ/cli-snu-warn.cl.out"; then ok "the snapshot-update cells differ"; else bad "the snapshot-update cells are identical"; fi

report_end held-stories
