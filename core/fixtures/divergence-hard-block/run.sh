#!/usr/bin/env bash
# divergence-hard-block — Rule 8's DIVERGENT_HARD_BLOCK must actually STOP the cycle.
#
# THE DEFECT THIS CATCHES. `DIVERGENT_HARD_BLOCK` means the REPAIR is injecting defects into
# text a previous pass had already cleared. Rule 8: stop, escalate, change approach — never
# another pass. Nothing enforced it. Check 24 reads the verdict, but Check 24 runs at the
# GATE, after the cycle is over, so the one signal that means STOP had no teeth at the only
# moment it mattered.
#
# Measured on the reference consumer: a cycle stamped DIVERGENT_HARD_BLOCK at pass 15 and the
# lead ran pass 16; it stamped DIVERGENT_HARD_BLOCK again at pass 17. Between them MAJORs went
# 1 -> 4 and CRITICALs began appearing in PRIOR scope — the divergence compounding for two
# passes after the machinery had said stop.
#
# The guard raises the EXISTING pause flag (Rule 26: no new mechanism). That flag already has
# teeth: ai-dlc-acknowledge.sh then DENIES every pipeline-advancing tool call, so the lead
# cannot dispatch the next pass.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HOOK="$(pick "${1:-}" "$HERE/../../hooks/ai-dlc-continue.sh" \
                      "$HERE/../../../.claude/hooks/ai-dlc-continue.sh" \
                      "$HERE/../../../core/hooks/ai-dlc-continue.sh")"
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-continue.sh" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive the Stop hook against a seeded tree. A transcript is required by Check 0 but we give
# none, so Check 0 fails open and we land on Check 0b — which is what we are testing.
drive() { # drive <work> -> hook stdout
  printf '{"session_id":"t","transcript_path":""}' \
    | CLAUDE_PROJECT_DIR="$1" "$HOOK" 2>/dev/null
}

echo "divergence-hard-block:"

# --- 1. It FIRES on DIVERGENT_HARD_BLOCK -------------------------------------
W="$(bash "$HERE/seed.sh" DIVERGENT_HARD_BLOCK 15)"
OUT="$(drive "$W")"
if [ -f "$W/_bmad-output/pipeline-paused.flag" ]; then
  ok "raises the pause flag (the lead can no longer dispatch another pass)"
else
  bad "no pause flag — a DIVERGENT_HARD_BLOCK verdict did not stop the cycle. This is the bug."
fi
case "$OUT" in
  *'"decision":"block"'*|*'"decision": "block"'*) ok "blocks the stop so the lead must surface the escalation" ;;
  *) bad "the hook did not block — the lead ends its turn and the divergence goes unreported" ;;
esac
case "$OUT" in
  *"ANOTHER PASS IS NOT THE REMEDY"*) ok "names the remedy (not 'run another pass')" ;;
  *) bad "the block message does not say another pass is wrong — which is the advice that produced p16 and p17" ;;
esac
case "$OUT" in
  *"LOAD-BEARING"*|*"load-bearing"*) ok "asks whether the repair deleted something load-bearing (AC / predicate / LOCKED)" ;;
  *) bad "does not ask what the repair broke — a repair that makes a check unfalsifiable is the defect" ;;
esac
rm -rf "$W"

# --- 2. It does NOT fire on a healthy verdict --------------------------------
# The decoy. A guard that pauses on every pass is a guard that gets ripped out.
for v in EXIT_CONDITION_MET EXIT_CONDITION_NOT_MET; do
  W="$(bash "$HERE/seed.sh" "$v" 3)"
  drive "$W" >/dev/null
  if [ -f "$W/_bmad-output/pipeline-paused.flag" ]; then
    bad "$v raised the pause flag — the guard fires on a cycle that is working"
  else
    ok "$v does not pause the pipeline"
  fi
  rm -rf "$W"
done

# --- 3. Idempotent: the operator's adjudication wins --------------------------
# Once the operator clears the flag, the SAME artifact must not re-raise it — otherwise the
# guard fights the decision it exists to request, and the pipeline can never resume.
W="$(bash "$HERE/seed.sh" DIVERGENT_HARD_BLOCK 15)"
drive "$W" >/dev/null                                    # raises
rm -f "$W/_bmad-output/pipeline-paused.flag"             # operator adjudicates and clears
drive "$W" >/dev/null                                    # same artifact, second turn
if [ -f "$W/_bmad-output/pipeline-paused.flag" ]; then
  bad "re-raised on the SAME pass after the operator cleared it — the pipeline can never resume"
else
  ok "does not re-raise for an artifact already adjudicated (the operator's clear wins)"
fi

# --- 4. ...but a NEW divergent pass raises again -------------------------------
# Idempotency must be per-ARTIFACT, not a one-shot latch: p17 diverging after p15 was
# adjudicated is a fresh hard block, and the whole failure was two of them being ignored.
sleep 1
bash "$HERE/seed.sh" DIVERGENT_HARD_BLOCK 17 >/dev/null   # seed writes to its own dir; copy in
cat > "$W/_bmad-output/planning-artifacts/s1-brief-adversarial-p17.md" <<'EOF'
<!-- SKILL_INVOCATION_PROVENANCE v1
findings_critical: 1
findings_critical_prior_scope: 1
verdict: DIVERGENT_HARD_BLOCK
SKILL_INVOCATION_PROVENANCE_END -->
EOF
drive "$W" >/dev/null
if [ -f "$W/_bmad-output/pipeline-paused.flag" ]; then
  ok "a NEW divergent pass raises again (idempotency is per-artifact, not a one-shot latch)"
else
  bad "p17 diverged after p15 was adjudicated and nothing fired — the second hard block is exactly what was ignored"
fi
rm -rf "$W"

echo
if [ "$fails" -eq 0 ]; then echo "divergence-hard-block: PASS"; exit 0; fi
echo "divergence-hard-block: $fails assertion(s) FAILED" >&2
exit 1
