#!/usr/bin/env bash
# gate-adjudication/seed.sh — build a pristine, COMPLETE, all-PASS verdict for the
# implementation gate and print the work dir. Idempotent: each call makes a fresh temp tree.
#
# The escalated set is DERIVED here the same way the gate derives it (validate-gate-adjudication.sh
# --expected), never hand-listed — so this fixture cannot silently drift from the map the way a
# hand-maintained coverage list would. run.sh then mutates this pristine state to prove the
# fail-closed contract, and restores it.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the layout. Distribution: HERE=core/fixtures/gate-adjudication; validator/schema/map
# live under core/. Consumer: HERE=tests/fixtures/gate-adjudication; they live under scripts/ and
# .claude/.
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-gate-adjudication.sh" ]; then
  VALIDATOR="$D_ROOT/core/scripts/validate-gate-adjudication.sh"
  SCHEMA="$D_ROOT/core/schemas/gate-adjudication-verdict.json"
  MAP_SRC="$D_ROOT/core/skills/ai-dlc/enforcement-map.yaml"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/ai-dlc/validate-gate-adjudication.sh" ]; then
  VALIDATOR="$C_ROOT/scripts/ai-dlc/validate-gate-adjudication.sh"
  SCHEMA="$C_ROOT/.claude/schemas/gate-adjudication-verdict.json"
  MAP_SRC="$C_ROOT/.claude/skills/ai-dlc/enforcement-map.yaml"
else
  echo "FIXTURE ERROR: validate-gate-adjudication.sh not found in either layout" >&2
  exit 2
fi
for f in "$SCHEMA" "$MAP_SRC"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: missing $f" >&2; exit 2; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gate-adjudication.XXXXXX")" || exit 2
GATE_TYPE="implementation"
NONCE="implementation-20260715T140322Z"
cp "$MAP_SRC" "$WORK/enforcement-map.yaml"
mkdir -p "$WORK/gate-adjudication"
VERDICT="$WORK/gate-adjudication/$NONCE.verdict.json"

IDS="$(AI_DLC_ENFORCEMENT_MAP="$WORK/enforcement-map.yaml" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
        bash "$VALIDATOR" --expected "$GATE_TYPE")" || { echo "FIXTURE ERROR: --expected failed" >&2; exit 2; }

python3 - "$VERDICT" "$NONCE" "$GATE_TYPE" $IDS <<'PY'
import json, sys
out, nonce, gt = sys.argv[1], sys.argv[2], sys.argv[3]
ids = sys.argv[4:]
doc = {
    "schema_id": "GATE_ADJUDICATION_VERDICT v1",
    "gate_type": gt,
    "gate_nonce": nonce,
    "generated_at": "2026-07-15T14:05:07Z",
    "adjudicator_agent_id": "agent-fixture-0001",
    "catalog": "core",
    "verdicts": [
        {"check_id": c, "verdict": "PASS", "evidence": "fixture: check %s satisfied" % c}
        for c in ids
    ],
}
with open(out, "w", encoding="utf-8") as fh:
    fh.write(json.dumps(doc, indent=2) + "\n")
PY

# Hand run.sh everything it needs, so it does not re-resolve the layout.
cat > "$WORK/env.sh" <<ENV
VALIDATOR="$VALIDATOR"
SCHEMA="$SCHEMA"
MAP="$WORK/enforcement-map.yaml"
WORK="$WORK"
GATE_TYPE="$GATE_TYPE"
NONCE="$NONCE"
VERDICT="$VERDICT"
IDS="$IDS"
ENV

printf '%s\n' "$WORK"
