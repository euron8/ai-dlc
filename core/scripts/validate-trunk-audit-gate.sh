#!/bin/bash
#
# AI/DLC Trunk-Audit Gate  (Check 36)
#
# WHAT IT DOES. Re-runs the step-1b post-merge trunk audit
# (`validate-cycle-commits.sh --audit-trunk`) AT the planning gate of a carry-over
# sprint, and maps its exit to a gate verdict. The verdict comes from the re-run, never
# from a record of an earlier run.
#
# WHY A RE-RUN AND NOT A READ. `carry-over-evaluation.md` step 1b makes the audit's
# exit 1 a HARD_BLOCK, and no gate check read its result. Measured on the reference
# consumer: since its sprint 303, 7 of 13 carry-over evaluations carry the audit's
# summary line, and two sprints that DID run the audit (one at exit 0, 12 of 12 clean,
# in the lead's transcript) carry none -- the result landed nowhere a gate reads. A
# check keyed on artifact text fails six of thirteen sprints that did nothing wrong, and
# one keyed on the gitignored `_bmad-output/.audit-watermark` reads a file that is not
# written on WORKLIST and absent from a fresh clone. Re-running is the only source that
# is neither. The consumer had already built exactly this as its own extension check;
# this is core absorbing it.
#
# SCOPE. Carry-over variant only, read from the snapshot's `pipeline_variant:`. Step 1b
# lives in `carry-over-evaluation.md` alone, and a project on another variant may never
# have recorded an audit genesis -- running there would exit 2 and wedge a sprint that
# owes no audit. Any other variant is NOT-APPLICABLE, printed with EXAMINED NOTHING.
#
# VERDICTS (the audit's exit, then this script's):
#   0 + `AUDIT-TRUNK: audited=`   PASS                            exit 0
#   0 + `AUDIT-TRUNK: WORKLIST`   WORKLIST -- nothing was audited
#                                 because the project declares no
#                                 PR classes; a backlog item, not
#                                 a gate failure and not a pass   exit 0
#   1                             FAIL -- findings (file the step-1b
#                                 HARD_BLOCK naming each SHA) or a
#                                 malformed taxonomy              exit 1
#   2                             FAIL -- setup error (no genesis,
#                                 no contract); not a clean result exit 2
#   0 with neither line, or any other exit
#                                 FAIL -- a verdict from output the
#                                 producer does not emit           exit 2
#
# THE AUDIT IS NOT READ-ONLY. It advances `_bmad-output/.audit-watermark` to the last
# clean commit, so a re-run at a later gate audits only what reached the trunk since.
# That is the intended interim behaviour, not a side effect to suppress.
#
# USAGE
#   validate-trunk-audit-gate.sh --sprint <sprint_id> [--snapshot PATH]
#   (--sprint selects the prior sprint's audit-anchors.md entry when there is no watermark)
#
# EXIT
#   0  PASS, WORKLIST, or NOT-APPLICABLE (the verdict line says which)
#   1  the audit reported findings or a malformed taxonomy
#   2  no snapshot / no pipeline_variant, the audit could not run, or its output was
#      not a form it emits. A FAIL, never a pass.

set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
# Walk UP for a marker, never count `..` hops: this script runs from
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# core/fixtures/validator-path-resolution asserts the layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

SNAPSHOT="${AI_DLC_ROOT}/_bmad-output/pipeline-snapshot.md"
SPRINT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --snapshot) SNAPSHOT="${2:-}"; shift 2 ;;
    --sprint)   SPRINT="${2:-}";   shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
# The sprint is PASSED IN (the gate's sprint_id), never re-read from the snapshot here:
# I104 holds the snapshot sprint_id reader to three byte-identical copies.
case "$SPRINT" in
  ''|*[!0-9]*) [ -z "$SPRINT" ] || { echo "--sprint takes a number, got '$SPRINT'" >&2; exit 2; } ;;
esac

AUDIT="${AI_DLC_SELF_DIR}/validate-cycle-commits.sh"
echo "root     : ${AI_DLC_ROOT}"
echo "snapshot : ${SNAPSHOT}"

if [ ! -r "$SNAPSHOT" ]; then
  echo "verdict  : FAIL -- no readable pipeline snapshot, so whether this sprint owes the step-1b audit cannot be decided."
  exit 2
fi
VARIANT="$(sed -n 's/^[-*[:space:]]*pipeline_variant:[[:space:]]*\([A-Za-z0-9-]*\).*/\1/p' "$SNAPSHOT" | head -1)"
echo "variant  : ${VARIANT:-<none>}"
if [ -z "$VARIANT" ]; then
  echo "verdict  : FAIL -- the snapshot records no pipeline_variant, so whether this sprint owes the step-1b audit cannot be decided."
  exit 2
fi
if [ "$VARIANT" != "carry-over" ]; then
  echo "verdict  : NOT-APPLICABLE -- EXAMINED NOTHING -- pipeline_variant is '${VARIANT}'; step 1b runs only in the carry-over variant."
  exit 0
fi

if [ ! -f "$AUDIT" ]; then
  echo "verdict  : FAIL -- ${AUDIT} is not installed beside this script, so the audit cannot run."
  exit 2
fi

# GENESIS. The audit's range starts at the gitignored `_bmad-output/.audit-watermark`, which
# a fresh clone does not carry. Without a fallback a carry-over sprint on a fresh clone would
# exit 2 here with no remedy but hand-writing an untracked file. The tracked source is the one
# step 1a already reads: the prior sprint's `audit-anchors.md` entry, whose `audit_window:`
# end is where the prior sprint's audit window closed. The watermark, when present, wins --
# it is the audit's own record of how far it got.
GENESIS_ARGS=()
WM="${AI_DLC_ROOT}/_bmad-output/.audit-watermark"
ANCHORS="${AI_DLC_ROOT}/_bmad-output/audit-anchors.md"
if [ -s "$WM" ]; then
  echo "genesis  : watermark ($(head -1 "$WM" | tr -d '[:space:]'))"
elif [ -n "$SPRINT" ] && [ -r "$ANCHORS" ]; then
  PRIOR=$((10#$SPRINT - 1))
  G_END="$(awk -v p="$PRIOR" '
    /^- sprint:[[:space:]]*/ { s=$0; sub(/^- sprint:[[:space:]]*/, "", s); sub(/[[:space:]].*$/, "", s); in_e=(s==p); next }
    in_e && /^[[:space:]]+audit_window:[[:space:]]*/ {
      w=$0; sub(/^[[:space:]]+audit_window:[[:space:]]*/, "", w); sub(/[[:space:]].*$/, "", w)
      n=index(w, ".."); if (n>0) { print substr(w, n+2); exit } }' "$ANCHORS")"
  if [ -n "$G_END" ]; then
    GENESIS_ARGS=("$G_END")
    echo "genesis  : audit-anchors.md sprint ${PRIOR} audit_window end (${G_END}); no watermark"
  else
    echo "genesis  : none (no watermark, and audit-anchors.md has no sprint ${PRIOR} audit_window)"
  fi
else
  echo "genesis  : none (no watermark, and no audit-anchors.md or no --sprint)"
fi

OUT="$(cd "$AI_DLC_ROOT" && bash "$AUDIT" --audit-trunk ${GENESIS_ARGS[@]+"${GENESIS_ARGS[@]}"} 2>&1)"
RC=$?
LINE="$(printf '%s\n' "$OUT" | grep -E '^AUDIT-TRUNK: ' | tail -1)"
echo "audit_rc : ${RC}"
echo "recorded : ${LINE:-<no AUDIT-TRUNK line>}"

case "$RC" in
  0)
    case "$LINE" in
      "AUDIT-TRUNK: audited="*)
        echo "verdict  : PASS -- the trunk audit re-ran clean at this gate."
        exit 0 ;;
      "AUDIT-TRUNK: WORKLIST"*)
        echo "verdict  : WORKLIST -- nothing was audited: this project declares no PR classes. File the backlog item; this is not a clean trunk."
        exit 0 ;;
    esac
    echo "verdict  : FAIL -- the audit exited 0 without a line it emits; a verdict from that output would be about nothing."
    printf '%s\n' "$OUT" | tail -5 | sed 's/^/  | /'
    exit 2 ;;
  1)
    printf '%s\n' "$OUT" | grep -E '^  FAIL |^ERROR ' | head -20 | sed 's/^/  | /'
    echo "verdict  : FAIL -- the trunk audit reported findings or a malformed taxonomy. File the step-1b HARD_BLOCK naming each FAIL sha; the watermark holds at the last clean commit."
    exit 1 ;;
  2)
    printf '%s\n' "$OUT" | grep -E '^audit-trunk: ' | head -3 | sed 's/^/  | /'
    echo "verdict  : FAIL -- the trunk audit could not run (setup error). The genesis comes from _bmad-output/.audit-watermark, else from the prior sprint's audit_window end in _bmad-output/audit-anchors.md (step 1a's entry). Fix that source and re-run; this is not a clean result."
    exit 2 ;;
  *)
    printf '%s\n' "$OUT" | tail -5 | sed 's/^/  | /'
    echo "verdict  : FAIL -- the trunk audit exited ${RC}, which it does not emit."
    exit 2 ;;
esac
