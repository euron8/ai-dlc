#!/usr/bin/env bash
# retro-gate.sh [--nonce <gate_nonce>] --sprint <N> -- the retro gate's scripted arms (retro.md Step 5c
# checks 2-5, plus validate-artifact-paths.sh), run in order, one line per arm:
#
#   GATE-ARM <check-id> <PASS|FAIL|SKIP> examined=<n> <path:line|reason=<token>> <message>
#
# `examined=` counts what the arm actually scanned. An arm whose validator scanned nothing is never a
# PASS: it is a SKIP with a reason, or a FAIL. After the arms one `GATE-COUNTS` line carries the
# derived counts the gate entry quotes. Each arm is recorded with
# `gate-checkpoint.sh --nonce <n> record <check-id> <verdict>`; the nonce is the gate's own, minted and
# opened as gate-validation.md "At gate entry" says before this runs.
# Without --nonce (the form gate-run.sh calls: it mints the nonce after the arms and records each arm itself)
# nothing is recorded here.
#
# Check ids are retro-2 (provenance block), retro-3 (mandatory rules), retro-4 (audit anchors),
# retro-5 (artifact budget / whole-read pool) and retro-artifact-paths: retro.md's own Step 5c numbering,
# never the universal catalog ids 2-5, which are different checks. A SKIP carries one of two fixed
# reason tokens: `validator-absent` (the validator is not installed beside this script) or
# `examined-nothing` (the validator exited 0 having scanned nothing).
#
# It writes NO gate-log entry and NO GATE_METRIC row: Check 12 writes the entry. The judgment checks
# (every id `validate-gate-adjudication.sh --expected retro` prints) are not here; one adjudicator covers them.
#
# exit: 0 every arm PASS (or SKIP with a reason); 1 at least one arm FAIL; 2 the gate could not run
#       (bad usage, no sprint doc, gate-checkpoint.sh absent, a record refused).
# Locates its siblings beside itself (core/scripts/ and scripts/ai-dlc/), resolves the repository root by walking up
# for a marker and runs there from any working directory; AI_DLC_STATE_DIR names the state directory.

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. Inline on purpose: a shared lib cannot fix this, because locating the lib is the
# same unsolved problem. core/fixtures/validator-path-resolution asserts the layouts agree.
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
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "retro-gate: cannot resolve the project root from ${AI_DLC_SELF_DIR}; set AI_DLC_PROJECT_ROOT" >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
RG_HERE="${BASH_SOURCE[0]:-$0}"
RG_DIR="$AI_DLC_SELF_DIR"
cd "$AI_DLC_ROOT" || exit 2
SD="${AI_DLC_STATE_DIR:-_bmad-output}"
NONCE=""; SPRINT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --nonce)  NONCE="${2:-}"; shift 2 ;;
    --sprint) SPRINT="${2:-}"; shift 2 ;;
    *) echo "usage: retro-gate.sh [--nonce <gate_nonce>] --sprint <N>" >&2; exit 2 ;;
  esac
done
case "$SPRINT" in ''|*[!0-9]*) echo "usage: retro-gate.sh [--nonce <gate_nonce>] --sprint <N>" >&2; exit 2 ;; esac
GC="$RG_DIR/gate-checkpoint.sh"
[ -f "$GC" ] || { echo "retro-gate: gate-checkpoint.sh not found beside $RG_HERE" >&2; exit 2; }
DOC="docs/retro/s${SPRINT}/retro.md"
[ -f "$DOC" ] || { echo "retro-gate: $AI_DLC_ROOT/$DOC is absent; the retro document is written before the gate" >&2; exit 2; }

N_PASS=0; N_FAIL=0; N_SKIP=0; N_EXAM=0; RG_RC=0
OUT="$(mktemp)" || exit 2
trap 'rm -f "$OUT"' EXIT

# arm <check-id> <validator-basename> <examined-fn-or-empty> -- <validator args...>
arm() {
  local id="$1" v="$2" exam="$3" rc verdict loc msg first n
  shift 4
  if [ ! -f "$RG_DIR/$v" ]; then
    verdict=SKIP; n=0; loc="reason=validator-absent"; msg="$v is not installed beside retro-gate.sh"
  else
    bash "$RG_DIR/$v" "$@" > "$OUT" 2>&1; rc=$?
    n="$($exam)"; case "$n" in ''|*[!0-9]*) n=0 ;; esac
    first="$(grep -m1 -E '^[^ ]+:[0-9]+' "$OUT")"
    msg="$v exit $rc: $(grep -m1 -v '^[[:space:]]*$' "$OUT" | cut -c1-160)"
    if [ "$rc" != 0 ]; then
      verdict=FAIL; loc="reason=exit-$rc"; [ -n "$first" ] && loc="${first%% *}"
    elif [ "$n" = 0 ]; then
      verdict=SKIP; loc="reason=examined-nothing"
    else
      verdict=PASS; loc="reason=ok"
    fi
  fi
  printf 'GATE-ARM %s %s examined=%s %s %s\n' "$id" "$verdict" "$n" "$loc" "$msg"
  [ -z "$NONCE" ] || bash "$GC" --nonce "$NONCE" record "$id" "$verdict" "examined=$n" >/dev/null || { echo "retro-gate: gate-checkpoint.sh refused to record $id" >&2; exit 2; }
  N_EXAM=$((N_EXAM + n))
  case "$verdict" in
    PASS) N_PASS=$((N_PASS + 1)) ;;
    SKIP) N_SKIP=$((N_SKIP + 1)) ;;
    FAIL) N_FAIL=$((N_FAIL + 1)); RG_RC=1 ;;
  esac
}

ex_provenance() { grep -c 'SKILL_INVOCATION_PROVENANCE v1' "$DOC"; }
ex_rules() { grep -c '^\[Check [0-9]' "$OUT"; }
ex_anchors() { grep -c '^- sprint: ' "$SD/audit-anchors.md" 2>/dev/null; }
# The budget validator prints one `  <ok|OVER|WARN>  <artifact> ...` line per measured artifact beside the pool line.
ex_budget() { grep -E '^  [A-Za-z]+  ' "$OUT" | grep -vc 'WHOLE-READ POOL'; }
# The path validator prints `under the scan roots:   <n>`, the files it judged.
ex_paths() { sed -n 's/^  under the scan roots:  *\([0-9][0-9]*\).*/\1/p' "$OUT" | head -n 1; }

arm retro-2 validate-provenance-block.sh ex_provenance -- "$DOC" --require-skill bmad-party-mode
arm retro-3 validate-mandatory-rules.sh ex_rules -- "$SPRINT"
arm retro-4 validate-audit-anchors.sh ex_anchors -- "$SD/audit-anchors.md"
arm retro-5 validate-artifact-budget.sh ex_budget -- --warn-only --fail-on pipeline-snapshot.md --fail-on whole-read-pool
arm retro-artifact-paths validate-artifact-paths.sh ex_paths --

printf 'GATE-COUNTS arms=%s pass=%s fail=%s skip=%s examined=%s\n' "$((N_PASS + N_FAIL + N_SKIP))" "$N_PASS" "$N_FAIL" "$N_SKIP" "$N_EXAM"
exit "$RG_RC"
