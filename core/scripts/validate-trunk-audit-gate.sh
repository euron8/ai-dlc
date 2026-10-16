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
# is neither.
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
#   1, first FAIL sha named by an operator-resolved escalation
#                                 re-audit from that sha forward,
#                                 then map THAT run's exit        (loop)
#   1                             FAIL -- findings (file the step-1b
#                                 HARD_BLOCK naming each SHA) or a
#                                 malformed taxonomy              exit 1
#   2, shallow clone              FAIL -- the history the genesis
#                                 needs was never fetched; remedy
#                                 is `git fetch --unshallow`       exit 2
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
# THE EXIT FROM A FINDING. The audit stops at the first finding and the watermark holds
# at the last clean commit BEFORE it, so a fix-forward commit can never clear it: every
# later re-run walks the same range and stops on the same sha. Without an exit, one
# finding hard-blocked every later carry-over planning gate. The exit is the one core
# already uses for a HARD_BLOCK: the step-1b escalation naming that sha, resolved by the
# operator (`**Status:** RESOLVED` or `OVERRIDDEN` with an `**Operator authorization:**`
# citation, escalations.md). When the first FAIL sha is named -- as a hex prefix of 7 or
# more characters -- by such an entry in `docs/escalations/pending.md` or in
# `pending-archive.md` (where retro close moves terminal entries), this script re-runs the
# audit with that sha as its genesis, so the range starts AFTER it, and maps that run.
# The trace is the tracked escalation entry; the watermark is written by the audit, never
# by hand. Whether an entry is resolved and carries a well-formed citation is decided by
# `validate-escalation-resolution.sh --any-authorized`, which owns that grammar; this
# script only selects the entries that name the sha. That mode is SHAPE-only. Check 2a
# verifies a current-sprint citation against the transcript. An entry that names the sha
# for an unrelated reason is accepted too: the key is the sha, as the step-1b HARD_BLOCK
# is filed naming it.
#
# REQUIRES python3 on a carry-over gate with no watermark: the genesis fallback asks
# `validate-audit-anchors.sh`, which is python3, the same dependency Check 18 carries.
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
# step 1a already reads: the prior sprint's `audit-anchors.md` entry, and its REQUIRED `sha`
# field, resolved by `validate-audit-anchors.sh --prior-sprint-sha` -- the program Check 18
# already asks, so this script restates no entry grammar. Not `audit_window:`: the schema marks
# it optional and documentary, retro.md step 5b writes only sprint and closed_at, and the
# schema defines its upper bound as that same sprint's sha, so where it is present it can only
# agree with `sha` or be wrong. The watermark, when present, wins -- it is the audit's own
# record of how far it got.
RUN_GENESIS=""
WM="${AI_DLC_ROOT}/_bmad-output/.audit-watermark"
ANCHORS="${AI_DLC_ROOT}/_bmad-output/audit-anchors.md"
ANCHOR_TOOL="${AI_DLC_SELF_DIR}/validate-audit-anchors.sh"
G_WHY=""
if [ -s "$WM" ]; then
  echo "genesis  : watermark ($(head -1 "$WM" | tr -d '[:space:]'))"
elif [ -n "$SPRINT" ] && [ -r "$ANCHORS" ]; then
  if [ ! -f "$ANCHOR_TOOL" ]; then
    echo "genesis  : none (no watermark, and ${ANCHOR_TOOL} is not installed beside this script to resolve the anchor)"
  else
    G_ERR="$(mktemp 2>/dev/null || echo "/tmp/trunk-audit-gate.$$")"
    G_SHA="$(cd "$AI_DLC_ROOT" && bash "$ANCHOR_TOOL" --prior-sprint-sha "$ANCHORS" "$SPRINT" 2>"$G_ERR")"
    G_RC=$?
    G_WHY="$(grep -E 'FAIL' "$G_ERR" | head -1)"
    rm -f "$G_ERR"
    if [ "$G_RC" -eq 0 ] && [ -n "$G_SHA" ]; then
      RUN_GENESIS="$G_SHA"
      echo "genesis  : audit-anchors.md prior-sprint sha (${G_SHA}); no watermark"
    else
      echo "genesis  : none (no watermark, and the prior sprint's audit-anchors.md sha did not resolve)"
      [ -z "$G_WHY" ] || printf '  | %s\n' "$G_WHY"
    fi
  fi
else
  echo "genesis  : none (no watermark, and no audit-anchors.md or no --sprint)"
fi

# The first `FAIL` sha the audit printed, or empty. The audit stops at the first finding, so
# there is at most one.
first_fail_sha() { printf '%s\n' "$1" | sed -n 's/^  FAIL[[:space:]]*\([0-9a-f]\{7,40\}\)[[:space:]].*/\1/p' | head -1; }

# The escalation entries (a `##`/`###` header and its body) that name $1 by a hex token of 7+
# characters that is a prefix of it. Selection only; resolution is decided by the owner.
entries_naming() { # $1 sha, $2.. files
  local sha="$1"; shift
  awk -v sha="$sha" '
    function flush() { if (hdr != "" && hit) printf "%s", buf; buf = ""; hit = 0 }
    /^#{2,3} / { flush(); hdr = $0 }
    hdr != "" {
      buf = buf $0 "\n"
      s = $0
      while (match(s, /[0-9a-f]+/)) {
        t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        if (length(t) >= 7 && index(sha, t) == 1) hit = 1
      }
    }
    END { flush() }' "$@" 2>/dev/null
}

ESC_DIR="${AI_DLC_ROOT}/docs/escalations"
ESC_TOOL="${AI_DLC_SELF_DIR}/validate-escalation-resolution.sh"
ROUND=0
while :; do
  ROUND=$((ROUND + 1))
  OUT="$(cd "$AI_DLC_ROOT" && bash "$AUDIT" --audit-trunk ${RUN_GENESIS:+"$RUN_GENESIS"} 2>&1)"
  RC=$?
  LINE="$(printf '%s\n' "$OUT" | grep -E '^AUDIT-TRUNK: ' | tail -1)"
  echo "audit_rc : ${RC}"
  echo "recorded : ${LINE:-<no AUDIT-TRUNK line>}"
  [ "$RC" -eq 1 ] || break
  F_SHA="$(first_fail_sha "$OUT")"
  [ -n "$F_SHA" ] || break
  [ "$ROUND" -le 200 ] || break
  ESC_FILES=()
  for f in "$ESC_DIR/pending.md" "$ESC_DIR/pending-archive.md"; do
    [ -f "$f" ] && ESC_FILES+=("$f")
  done
  [ "${#ESC_FILES[@]}" -gt 0 ] || { echo "exit     : none -- no docs/escalations/pending.md or pending-archive.md names ${F_SHA}"; break; }
  [ -f "$ESC_TOOL" ] || { echo "exit     : none -- ${ESC_TOOL} is not installed beside this script, so no resolution can be read"; break; }
  SEL="$(mktemp 2>/dev/null || echo "/tmp/trunk-audit-gate-esc.$$")"
  entries_naming "$F_SHA" "${ESC_FILES[@]}" > "$SEL"
  if [ ! -s "$SEL" ]; then
    rm -f "$SEL"
    echo "exit     : none -- no escalation entry names ${F_SHA}"
    break
  fi
  AUTH_OUT="$(bash "$ESC_TOOL" --any-authorized "$SEL" 2>&1)"
  AUTH_RC=$?
  rm -f "$SEL"
  if [ "$AUTH_RC" -ne 0 ]; then
    echo "exit     : none -- an escalation names ${F_SHA}, but none is RESOLVED/OVERRIDDEN with a well-formed Operator authorization:"
    printf '%s\n' "$AUTH_OUT" | head -2 | sed 's/^/  | /'
    break
  fi
  echo "exit     : ${F_SHA} -- $(printf '%s\n' "$AUTH_OUT" | sed -n 's/.*First: //p' | head -1); re-auditing from it"
  RUN_GENESIS="$F_SHA"
done

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
    echo "verdict  : FAIL -- the trunk audit reported findings or a malformed taxonomy. File the step-1b HARD_BLOCK naming each FAIL sha in docs/escalations/pending.md. A fix-forward does not clear it: the audit stops at the finding, so the watermark holds before it. The exit is the operator's: once that entry is **Status:** RESOLVED (or OVERRIDDEN) with an **Operator authorization:** citation, re-run this check and it re-audits from that sha forward."
    exit 1 ;;
  2)
    printf '%s\n' "$OUT" | grep -E '^audit-trunk: ' | head -3 | sed 's/^/  | /'
    if [ "$(git -C "$AI_DLC_ROOT" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
      echo "verdict  : FAIL -- the trunk audit could not run, and this is a SHALLOW clone: the genesis commit is outside the fetched history, so it cannot resolve whatever the anchor says. Run 'git fetch --unshallow' and re-run; the anchor entry is not the cause. This is not a clean result."
      exit 2
    fi
    echo "verdict  : FAIL -- the trunk audit could not run (setup error). The genesis comes from _bmad-output/.audit-watermark, else from the prior sprint's sha in _bmad-output/audit-anchors.md (step 1a's entry). Fix that source and re-run; this is not a clean result."
    exit 2 ;;
  *)
    printf '%s\n' "$OUT" | tail -5 | sed 's/^/  | /'
    echo "verdict  : FAIL -- the trunk audit exited ${RC}, which it does not emit."
    exit 2 ;;
esac
