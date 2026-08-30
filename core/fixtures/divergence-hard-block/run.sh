#!/usr/bin/env bash
# divergence-hard-block — Rule 8's STOP states must actually stop the cycle, AND must let
# an adjudicated cycle start again.
#
# THE DEFECT THIS CATCHES, IN TWO HALVES.
#
# STOP. `DIVERGENT_HARD_BLOCK` means the REPAIR is injecting defects into text a previous
# pass had already cleared; a STALL means a nonzero MAJOR held at zero CRITICAL, pass after
# pass. Rule 8: stop, escalate, change approach — never another pass. Check 24 reads both,
# but Check 24 runs at the GATE, after the cycle is over.
#
# v0.57.0 put the guard in the Stop hook, and that was the wrong hook. `Stop` fires only
# when the lead YIELDS — and Rule 3, plus the continue hook itself, exist to make the lead
# never yield. It fired on the reference consumer by LUCK. The teeth belong in PreToolUse,
# where a dispatch can actually be denied, so THIS FIXTURE DRIVES BOTH HOOKS.
#
# RESUME. And the other half is the one that cost a pipeline. The Stop hook's deny reason
# said "do NOT dispatch another adversarial pass, and do NOT clear the pause flag to get
# past this" — while Check 24 arm D simultaneously REQUIRED a terminal clean pass. The gate
# demanded the pass the hook forbade, and no wording of any option could satisfy both. The
# lead read both correctly and parked the pipeline on an escalation.
#
# So the assertions below are symmetric, and both halves must hold:
#   a STOPPED cycle cannot dispatch                    (or the hard block is decorative)
#   a RESOLVED cycle CAN dispatch                      (or the deadlock is back)
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
STOP_HOOK="$(pick "$HERE/../../hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../.claude/hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../core/hooks/ai-dlc-continue.sh")"
ACK_HOOK="$(pick "$HERE/../../hooks/ai-dlc-acknowledge.sh" \
                 "$HERE/../../../.claude/hooks/ai-dlc-acknowledge.sh" \
                 "$HERE/../../../core/hooks/ai-dlc-acknowledge.sh")"
[ -n "$STOP_HOOK" ] && [ -n "$ACK_HOOK" ] \
  || { echo "FIXTURE ERROR: cannot locate the hooks" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive the Stop hook. A transcript is required by Check 0 but we give none, so Check 0
# fails open and we land on Check 0b — which is what we are testing.
drive_stop() { # <work> -> stdout
  printf '{"session_id":"t","transcript_path":""}' \
    | CLAUDE_PROJECT_DIR="$1" bash "$STOP_HOOK" 2>/dev/null
}

# Drive the PreToolUse hook as the lead dispatching the next adversarial pass.
drive_ack() { # <work> <tool> [file_path] -> stdout
  local w="$1" tool="$2" fp="${3:-}"
  printf '{"session_id":"t","transcript_path":"","tool_name":"%s","tool_input":{"file_path":"%s"}}' \
    "$tool" "$fp" | CLAUDE_PROJECT_DIR="$w" bash "$ACK_HOOK" 2>/dev/null
}
denied() { case "$1" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) return 0 ;; esac; return 1; }

echo "divergence-hard-block:"

# =============================================================================
# 1. THE TEETH — PreToolUse denies the dispatch. This is the whole point.
# =============================================================================
# Under v0.57.0 the acknowledge hook ALLOWED every one of these: it knew nothing about the
# adversarial cycle, and the pause flag it did know about is cleared by the lead as its
# sanctioned resume. So the dispatch went through and the cycle ran pass 16, and pass 17.
W="$(bash "$HERE/seed.sh" divergent)"
OUT="$(drive_ack "$W" Agent)"
if denied "$OUT"; then ok "DIVERGENT: the Agent dispatch is DENIED (the lead cannot run another pass)"
else bad "DIVERGENT: the Agent dispatch was ALLOWED — the hard block has no teeth"; fi

# The deny must survive the flag being cleared. Otherwise `rm -f pipeline-paused.flag` — the
# deliberate, must-stay-open escape hatch — doubles as a bypass of the hard block, and the
# flag stops being an escape hatch and becomes a back door.
rm -f "$W/_bmad-output/pipeline-paused.flag"
OUT="$(drive_ack "$W" Agent)"
if denied "$OUT"; then ok "the deny SURVIVES clearing the pause flag (the escape hatch is not a bypass)"
else bad "clearing the pause flag walked straight past the hard block"; fi

# And the message must carry the exit. A denial with no sanctioned way out IS the deadlock.
#
# EVERY ONE OF THESE IS GUARDED ON `denied "$OUT"` FIRST, AND THAT GUARD IS NOT CEREMONY.
# A grep-for-absence over an EMPTY string passes. So "the deny reason must not say 'do NOT
# clear the pause flag'" scores a silent ok against a hook that never denies anything at
# all — which is precisely the hook we are replacing. That is a check that cannot fire,
# living inside the fixture written to catch checks that cannot fire. Assert the denial
# exists before asserting anything about what it says.
if denied "$OUT"; then
  case "$OUT" in
    *"STOP -> ADJUDICATE -> RESOLVE -> VERIFY"*) ok "the deny names the EXIT (STOP -> ADJUDICATE -> RESOLVE -> VERIFY)" ;;
    *) bad "the deny gives no sanctioned exit — which is exactly what parked the pipeline" ;;
  esac
  case "$OUT" in
    *"do NOT clear the pause flag"*) bad "the deadlock sentence is BACK. A denial that forbids its own exit is the bug." ;;
    *) ok "does NOT tell the lead to never clear the flag (that sentence WAS the deadlock)" ;;
  esac
  case "$OUT" in
    *"LOAD-BEARING"*) ok "asks whether the repair weakened an AC / predicate / LOCKED entry" ;;
    *) bad "does not ask what the repair broke — a repair that makes a check unfalsifiable is the defect" ;;
  esac
  case "$OUT" in
    *"FREEZE is deliberately NOT on the list"*) ok "says WHY freezing is not an option (it cannot clear a prior-scope block)" ;;
    *) bad "does not rule out FREEZE — the lead recommended it, the operator took it, and it was void" ;;
  esac
else
  bad "no denial to inspect: the four message assertions below cannot fire, so they prove nothing"
  bad "  (deny-names-the-exit)"
  bad "  (deny-does-not-forbid-its-own-exit)"
  bad "  (deny-asks-what-the-repair-broke)"
  bad "  (deny-rules-out-FREEZE)"
fi
rm -rf "$W"

# --- a STALL must deny too. v0.57.0 read only the verdict field, and a stall has no verdict
# of its own — it is a property of the series. So it denied nothing.
W="$(bash "$HERE/seed.sh" stalled)"
OUT="$(drive_ack "$W" Agent)"
if denied "$OUT"; then ok "STALLED: the Agent dispatch is DENIED (a plateau is not a reason for another pass)"
else bad "STALLED: dispatch ALLOWED — the cycle held 0C/4M -- above the exit ceiling -- for four passes and nothing stopped it"; fi
rm -rf "$W"

# =============================================================================
# 2. THE RESUME — a resolved cycle CAN dispatch. If this fails, the deadlock is back.
# =============================================================================
W="$(bash "$HERE/seed.sh" divergent-resolved)"
OUT="$(drive_ack "$W" Agent)"
if denied "$OUT"; then bad "RESOLVED: the verification pass was DENIED — there is no exit and the pipeline is wedged"
else ok "RESOLVED: the verification pass is ALLOWED (the record is the sanctioned exit)"; fi
rm -rf "$W"

# --- and the record itself must be WRITEABLE while paused. Check 2a denies every dispatch
# until the record exists; if the pause flag then denies the record, the two checks lock the
# pipeline against itself and the only way out is to switch off a hook.
W="$(bash "$HERE/seed.sh" divergent)"
drive_stop "$W" >/dev/null                      # raises the pause flag
REC="$W/_bmad-output/planning-artifacts/s7/brief-resolution-p2.md"
OUT="$(drive_ack "$W" Write "$REC")"
if denied "$OUT"; then bad "the resolution record was DENIED while paused — the pause denies its own exit"
else ok "the resolution record is WRITEABLE while paused (the one write the pause waits for)"; fi

# ...but the carve-out must be NARROW. Any other _bmad-output write is still denied.
OUT="$(drive_ack "$W" Write "$W/_bmad-output/planning-artifacts/product-brief.md")"
if denied "$OUT"; then ok "the carve-out is narrow: other _bmad-output writes are still denied while paused"
else bad "the carve-out leaked — every artifact write now bypasses the pause"; fi

# ...and the pipeline SNAPSHOT is writeable while paused. It is a state record (it mirrors an
# already-passed gate / delivered teammate), not a dispatch, and the handoff path raises this
# very flag before Rule 2(c) requires finalizing it — deny it and a handoff cannot write its
# own snapshot (deadlock) and the resume reads stale state.
OUT="$(drive_ack "$W" Edit "$W/_bmad-output/pipeline-snapshot.md")"
if denied "$OUT"; then bad "the pipeline snapshot was DENIED while paused — a handoff that raised the flag cannot finalize its own snapshot, and the resume reads a stale checkpoint"
else ok "the pipeline snapshot is WRITEABLE while paused (a state record, not a dispatch)"; fi

# ...and so is the snapshot's ARCHIVE half. Rule 25(a) and Check 14's `trim` remedy both say to
# MOVE superseded snapshot prose here rather than delete it, so denying this file denies half of
# a write the rulebook mandates — and the lead compresses in place instead, which is not what
# the rule prescribes. Measured live on the reference consumer at a handoff seam.
OUT="$(drive_ack "$W" Edit "$W/_bmad-output/pipeline-snapshot-history.md")"
if denied "$OUT"; then bad "the snapshot HISTORY was DENIED while paused — the Rule 25(a) trim has nowhere to move to, so an over-budget snapshot can only be compressed in place"
else ok "the snapshot history is WRITEABLE while paused (the archive half of the file above)"; fi

# ...and so is the UPDATER's own scratch space. /ai-dlc-update is a different skill from
# /ai-dlc: it advances no sprint and runs precisely when the pipeline is not running, so
# denying its reconcile report blocks a skill that has no pipeline to pause. Observed live: the
# updater was denied mid-reconcile on its own ledger. This arm shipped with NO fixture naming
# it — it could be deleted whole and the entire suite stayed green.
OUT="$(drive_ack "$W" Write "$W/_bmad-output/ai-dlc-update/reconcile-report.md")"
if denied "$OUT"; then bad "the updater's reconcile report was DENIED while paused — a skill with no pipeline to pause was stopped by a pipeline pause"
else ok "the updater's own scratch space is WRITEABLE while paused (not pipeline output)"; fi
rm -rf "$W"

# =============================================================================
# 3. SURFACING — the Stop hook still raises the flag and blocks, so a human hears about it.
# =============================================================================
W="$(bash "$HERE/seed.sh" divergent)"
OUT="$(drive_stop "$W")"
if [ -f "$W/_bmad-output/pipeline-paused.flag" ]; then
  ok "raises the pause flag so the operator is asked to adjudicate"
else
  bad "no pause flag — the divergence never reaches a human"
fi
case "$OUT" in
  *'"decision":"block"'*|*'"decision": "block"'*) ok "blocks the stop so the lead must surface the escalation" ;;
  *) bad "the hook did not block — the lead ends its turn and the divergence goes unreported" ;;
esac
case "$OUT" in
  *"ANOTHER PASS IS NOT THE REMEDY"*) ok "names the remedy (not 'run another pass')" ;;
  *) bad "the block message does not say another pass is wrong — the advice that produced p16 and p17" ;;
esac
rm -rf "$W"

# =============================================================================
# 4. THE DECOYS — a guard that fires on a working cycle gets ripped out.
# =============================================================================
for c in converged in-progress; do
  W="$(bash "$HERE/seed.sh" "$c")"
  drive_stop "$W" >/dev/null
  OUT="$(drive_ack "$W" Agent)"
  if [ -f "$W/_bmad-output/pipeline-paused.flag" ]; then
    bad "$c raised the pause flag — the guard fires on a cycle that is working"
  else
    ok "$c does not pause the pipeline"
  fi
  if denied "$OUT"; then bad "$c: the dispatch was denied on a healthy cycle"
  else ok "$c: the dispatch is allowed"; fi
  rm -rf "$W"
done

# =============================================================================
# 5. ORDERING — mtime picks the SERIES, never the PASS.
# =============================================================================
# The old hook chose the "newest" pass with `ls -t`. Touch an already-adjudicated divergent
# pass in a cycle that has since CONVERGED — a re-read, an editor, a `git checkout` — and it
# becomes the newest file, its verdict is DIVERGENT_HARD_BLOCK, and the hook re-raised the
# hard block on a finished cycle. This is order_key()'s original bug, whose own comment reads
# "THIS FUNCTION WAS THE BUG, AND IT FAILED EXACTLY WHERE IT MATTERED" — reintroduced in a
# hook nine releases later, in the one file that documents it.
W="$(bash "$HERE/seed.sh" resolved-then-touched)"
drive_stop "$W" >/dev/null
OUT="$(drive_ack "$W" Agent)"
if [ -f "$W/_bmad-output/pipeline-paused.flag" ]; then
  bad "touching an old divergent pass re-raised the block on a CONVERGED cycle (mtime picked the pass)"
else
  ok "touching an old divergent pass does not re-raise: the VALIDATOR orders the series, not mtime"
fi
if denied "$OUT"; then bad "a converged cycle was denied because an old pass had a fresh mtime"
else ok "a converged cycle still dispatches after an old pass is touched"; fi
rm -rf "$W"

# =============================================================================
# 6. GC — the stop state must not outlive the stop.
# =============================================================================
# `.divergence-raised` was written and never removed by anything: not the hook, not the
# retro rotation. State that only accumulates is a stale-flag bug waiting for its turn.
W="$(bash "$HERE/seed.sh" divergent)"
drive_stop "$W" >/dev/null
[ -f "$W/_bmad-output/.adversarial-stop" ] || bad "no .adversarial-stop written on a STOP"
# the operator resolves it; the state must self-heal on the next turn
bash "$HERE/seed.sh" divergent-resolved >/dev/null 2>&1 || true
cat > "$W/_bmad-output/planning-artifacts/s7/brief-resolution-p2.md" <<'EOF'
<!-- ADVERSARIAL_RESOLUTION v1
resolves: brief-adversarial-p2.md
resolution: REVERT_REPAIR
adjudicated_by: operator
artifact: product-brief.md
artifact_sha_before: bbb2
artifact_sha_after: aaa1
artifact_bytes_before: 4200
artifact_bytes_after: 4000
scope_delta: reverted the p1->p2 repair wholesale
operator_authorization: 2026-07-12T03:00:00Z | "revert the p1 to p2 repair wholesale"
ADVERSARIAL_RESOLUTION_END -->
EOF
drive_stop "$W" >/dev/null
if [ -f "$W/_bmad-output/.adversarial-stop" ]; then
  bad ".adversarial-stop survived the resolution — stop state that only accumulates is the next stale flag"
else
  ok "the stop state self-heals once the cycle is resolved (no manual GC, no stale flag)"
fi
rm -rf "$W"

# =============================================================================
# 7. PARTIAL INSTALL — must not SILENTLY disarm.
# =============================================================================
# The `core/git-hooks/` failure: an enforcer shipped to a path nothing reads, and nothing
# said so for two minor releases. If the validator is missing the hooks fail OPEN (a hook
# that wedges the pipeline on its own bug gets switched off) — but they must leave a trace.
W="$(bash "$HERE/seed.sh" divergent)"
rm -f "$W/scripts/ai-dlc/validate-adversarial-convergence.sh"
OUT="$(drive_ack "$W" Agent)"
if denied "$OUT"; then bad "a missing validator DENIED the dispatch — hooks must fail OPEN on their own breakage"
else ok "a missing validator fails OPEN (a hook that wedges the pipeline gets switched off)"; fi
if grep -q 'ADVERSARIAL_STATE_UNADJUDICABLE' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "...but says so in the flow log — a disarmed guard must never be silent"
else
  bad "the hard block was disarmed SILENTLY. A check that cannot fire reads exactly like one that passed."
fi
rm -rf "$W"

# =============================================================================
# 8. NO DECLARED SPRINT — the other way this guard can go quiet.
# =============================================================================
# Both hooks now scope the live-series glob to `s<sprint-id>/`, and the sprint comes from
# `sprint-status.sh sprint-id`. That buys the scope the old mtime pick could not have, and
# it buys a NEW way to resolve nothing: an unreadable envelope. The tempting repair is a
# fallback to the unscoped glob, which is exactly the defect the scope replaced — so there
# is deliberately none, and the state is reported instead.
#
# THE SERIES IS INTACT IN EVERY OTHER RESPECT. Only the envelope is removed, so a hook that
# quietly widened its glob would still find the DIVERGENT series and still deny. An arm that
# also deleted the pass files could not tell "found nothing because unscoped-and-empty" from
# "found nothing because correctly scoped".
W="$(bash "$HERE/seed.sh" divergent)"
rm -f "$W/_bmad-output/implementation-artifacts/sprint-status.yaml" \
      "$W/_bmad-output/planning-artifacts/sprint-status.yaml"
[ -f "$W/_bmad-output/planning-artifacts/s7/brief-adversarial-p2.md" ] \
  || bad "FIXTURE BROKEN: the pass series was removed along with the envelope; this arm proves nothing"
OUT="$(drive_ack "$W" Agent)"
if denied "$OUT"; then bad "an unresolvable sprint DENIED the dispatch — hooks must fail OPEN on their own breakage"
else ok "an unresolvable sprint fails OPEN (as a missing validator does)"; fi
if grep -q 'ADVERSARIAL_STATE_UNADJUDICABLE' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "...and says so in the flow log — no silent fallback to an unscoped glob"
else
  bad "no sprint resolved, nothing scoped, nothing logged: the guard went quiet exactly where the old mtime pick did"
fi
rm -rf "$W"

echo
if [ "$fails" -eq 0 ]; then echo "divergence-hard-block: PASS"; exit 0; fi
echo "divergence-hard-block: $fails assertion(s) FAILED" >&2
exit 1
