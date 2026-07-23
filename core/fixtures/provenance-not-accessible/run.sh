#!/usr/bin/env bash
# provenance-not-accessible — prove the tool_use_id NOT_ACCESSIBLE sentinel is accepted
# (retro.md mandates it when the Skill/Agent id is not retrievable), that it opens no hole
# (a fabricated id and a placeholder literal still FAIL), and that the acceptance is the
# sentinel bypass and nothing else (removing it flips NOT_ACCESSIBLE back to FAIL).
#
# THE DEFECT THIS EXISTS TO CATCH. retro.md Step 2 tells authors to write
# `tool_use_id: NOT_ACCESSIBLE` rather than invent an id, yet the validator's toolu_ pattern
# rejected that exact literal — the doc mandated a value its own gate failed. A real retro
# after a compact could not pass without either forging an id or failing the gate.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-provenance-block.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-provenance-block.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-provenance-block.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-provenance-block.sh"
else
  echo "FIXTURE ERROR: validate-provenance-block.sh not found in either layout" >&2
  exit 2
fi

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

ART="$WORK/docs/eval.md"   # non-retro path: no retro-specific requirements
mkdir -p "$WORK/docs"

# write_block <tool_use_id>
write_block() {
  cat > "$ART" <<EOF
# Evaluation

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
invoked_at: 2026-01-01T00:00:00Z
tool_use_id: $1
mode: subagent
lead_role: gate-validation.md
findings_critical: 0
findings_major: 0
findings_minor: 1
SKILL_INVOCATION_PROVENANCE_END -->
EOF
}

echo "provenance-not-accessible"

# --- 1. NOT_ACCESSIBLE passes -------------------------------------------------
write_block "NOT_ACCESSIBLE"
bash "$VALIDATOR" "$ART" >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "0" ]; then
  ok "tool_use_id: NOT_ACCESSIBLE is accepted (sanctioned sentinel)"
else
  bad "NOT_ACCESSIBLE was rejected (exit $rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 2. a fabricated id still fails the pattern -------------------------------
write_block "NOPE-not-a-real-id"
bash "$VALIDATOR" "$ART" >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "1" ] && grep -q 'tool_use_id' "$WORK/out.txt"; then
  ok "a fabricated id still FAILs the toolu_ pattern (sentinel opened no hole)"
else
  bad "a fabricated id did not fail (exit $rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 3. a placeholder literal is still forbidden ------------------------------
write_block "toolu_PLACEHOLDER"
bash "$VALIDATOR" "$ART" >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "1" ] && grep -qi 'forbidden' "$WORK/out.txt"; then
  ok "a placeholder literal is still forbidden (not confused with the sentinel)"
else
  bad "a placeholder literal was not rejected (exit $rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 4. MUTATION: remove the sentinel bypass -> NOT_ACCESSIBLE FAILs ----------
MUTANT="$WORK/mutant.sh"
sed 's/value == spec\["sentinel"\]/False/' "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing — the sentinel check was rewritten" >&2
  echo "  update the sed pattern in assertion 4 to match the real comparison" >&2
  exit 2
fi
write_block "NOT_ACCESSIBLE"
bash "$MUTANT" "$ART" >"$WORK/mut.txt" 2>&1
rc=$?
if [ "$rc" = "1" ]; then
  ok "MUTATION: without the sentinel bypass, NOT_ACCESSIBLE FAILs (acceptance was real)"
else
  bad "MUTATION: NOT_ACCESSIBLE still passed without the bypass (exit $rc)"; sed 's/^/        /' "$WORK/mut.txt"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "provenance-not-accessible: PASS"
  exit 0
fi
echo "provenance-not-accessible: FAIL ($fails assertion(s))"
exit 1
