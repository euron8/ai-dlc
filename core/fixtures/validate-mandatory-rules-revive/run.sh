#!/usr/bin/env bash
# validate-mandatory-rules-revive/run.sh — prove the retro-compliance validator no longer
# self-poisons, and that Check 3 genuinely enforces the closed envelope.
#
# THE DEFECT THIS EXISTS TO CATCH. validate-mandatory-rules.sh delegated Checks 2 and 4 to sibling
# scripts, and Check 5 keyed on a "## Gate Log: Sprint N" header no core artifact produces. Each
# FAILED on a clean tree, so the whole validator exited 1 on every real retro — a wired CI gate that
# could never pass, enforcing nothing. Check 3 additionally read a shape (sprint_<N>_housekeeping)
# that no producer wrote until sprint-status.sh `close`.
#
# The fix: each check SKIPs loudly when its input is absent (un-poison), and Check 3 reads the
# canonical envelope `close` writes. Check 2 now ships in core and keys its SKIP on the PRODUCER
# (no validation-cycle-log.md -> SKIP), not on the validator's presence; Check 4's sibling stays
# consumer-provided (SKIP when absent). Regression lock below: the SKIPs must hold, Check 3 must
# PASS on a closed envelope, and the MUTANT (un-closed) must FAIL Check 3 — else the check is vacuous.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

P="$WORK/proj"
export AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA"
IMPL_YAML="$P/_bmad-output/implementation-artifacts/sprint-status.yaml"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "validate-mandatory-rules-revive:"

# Compliant tree: roll then close the envelope (Check 3's producer writes the housekeeping block).
bash "$SS" roll  --sprint 900 --intensity full --root "$P" >/dev/null 2>&1
bash "$SS" close --evidence "fixture: PR merged, deploy green, smoke pass" --root "$P" >/dev/null 2>&1

OUT="$(cd "$P" && bash "$VMR" 900 2>/dev/null)"

echo "$OUT" | grep -q 'CHECK 2: SKIP' \
  && ok "Check 2 SKIPs when no validation-cycle-log.md (per-artifact-changelog model)" \
  || bad "Check 2 did not SKIP — the no-log gate regressed"
echo "$OUT" | grep -q 'CHECK 4: SKIP' \
  && ok "Check 4 SKIPs when its consumer-provided sibling is absent (un-poison)" \
  || bad "Check 4 did not SKIP"
echo "$OUT" | grep -q 'CHECK 5: SKIP' \
  && ok "Check 5 SKIPs (no audit-anchors.md — diff base unresolvable on this clean tree)" \
  || bad "Check 5 did not SKIP"
echo "$OUT" | grep -q 'CHECK 3: PASS' \
  && ok "Check 3 PASSes on a closed envelope (close wrote the housekeeping block)" \
  || bad "Check 3 did not PASS on a closed envelope"

# MUTANT: un-close the envelope -> Check 3 must FAIL (proves it is not vacuous).
sed 's/^status: done/status: in_progress/' "$IMPL_YAML" > "$IMPL_YAML.tmp" && mv "$IMPL_YAML.tmp" "$IMPL_YAML"
MUT="$(cd "$P" && bash "$VMR" 900 2>/dev/null)"
echo "$MUT" | grep -q 'CHECK 3: FAIL' \
  && ok "MUTANT: an un-closed envelope FAILS Check 3 (enforcement is real, not vacuous)" \
  || bad "MUTANT: Check 3 did not FAIL on an un-closed envelope"

echo
if [ "$fails" -eq 0 ]; then
  echo "validate-mandatory-rules-revive: PASS"
  exit 0
fi
echo "validate-mandatory-rules-revive: FAIL ($fails)"
exit 1
