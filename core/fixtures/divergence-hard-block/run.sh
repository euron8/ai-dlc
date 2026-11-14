#!/usr/bin/env bash
# divergence-hard-block — Rule 8's STOP states must actually stop the cycle, AND must let
# an adjudicated cycle start again.
#
# THE DEFECT THIS CATCHES, IN TWO HALVES.
#
# STOP. `DIVERGENT_HARD_BLOCK` means the REPAIR is injecting defects into text a previous
# pass had already cleared; a STALL means a blocking MAJOR count above MAJOR_EXIT_CEILING, at
# no more than CRITICAL_EXIT_CEILING CRITICAL, not reduced across more than STALL_THRESHOLD
# consecutive passes. Rule 8: stop, escalate, change approach — never another pass. Check 24 reads both,
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
# The harness block cap clamps the continue hook's EFF_MAX; an exported one moves its counts.
unset CLAUDE_CODE_STOP_HOOK_BLOCK_CAP

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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# Every mutant kill goes through mutant_killed, gated on the base flag of the arm it guards (BL-828).
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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

# Each distinct world is built by seed.sh ONCE per run, into a pristine cache, and every cell that uses it gets
# its own `cp -Rp` copy (mtimes kept: the resolved-then-touched world orders its series by them). No cell ever
# touches the cache, so no cell can mutate a world another cell reads. Called inside $( ), so the cache is on disk.
WORLD_CACHE="$(mktemp -d "${TMPDIR:-/tmp}/divergence-cache-XXXXXX")"
# Removed on EVERY exit, early ones included, and only when it is the mktemp directory made above:
# non-empty, a directory, and directly under the TMPDIR it was made in, with the mktemp prefix.
drop_world_cache() {
  case "$WORLD_CACHE" in "${TMPDIR:-/tmp}"/divergence-cache-??????) ;; *) return 0 ;; esac
  [ -d "$WORLD_CACHE" ] && [ ! -L "$WORLD_CACHE" ] && rm -rf -- "$WORLD_CACHE"
  return 0
}
trap drop_world_cache EXIT
seed_world() { # <case> -> a fresh private copy of the case's world
  local c="$1" w
  if [ ! -d "$WORLD_CACHE/$c" ]; then
    w="$(bash "$HERE/seed.sh" "$c")" || return 1
    [ -d "$w" ] || return 1
    mv "$w" "$WORLD_CACHE/$c" || return 1
  fi
  w="$(mktemp -d "${TMPDIR:-/tmp}/divergence-XXXXXX")" || return 1
  cp -Rp "$WORLD_CACHE/$c/." "$w/" || return 1
  printf '%s' "$w"
}

echo "divergence-hard-block:"

# =============================================================================
# 1. THE TEETH — PreToolUse denies the dispatch. This is the whole point.
# =============================================================================
# Under v0.57.0 the acknowledge hook ALLOWED every one of these: it knew nothing about the
# adversarial cycle, and the pause flag it did know about is cleared by the lead as its
# sanctioned resume. So the dispatch went through and the cycle ran pass 16, and pass 17.
W="$(seed_world divergent)"
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
W="$(seed_world stalled)"
OUT="$(drive_ack "$W" Agent)"
if denied "$OUT"; then
  ok "STALLED: the Agent dispatch is DENIED (a plateau is not a reason for another pass)"
  # The message must state the validator's predicate by constant NAME. The old text said "a
  # nonzero MAJOR held at zero CRITICAL", which a plateau at or below the exit ceiling also
  # satisfies -- and that plateau is a MET exit condition, not a stall.
  case "$OUT" in
    *"(STALLED)"*MAJOR_EXIT_CEILING*STALL_THRESHOLD*) ok "STALLED: the deny names the stall predicate by its constants" ;;
    *) bad "STALLED: the deny does not state the validator's predicate (MAJOR_EXIT_CEILING / STALL_THRESHOLD)" ;;
  esac
else bad "STALLED: dispatch ALLOWED — the cycle held 0C/4M -- above the exit ceiling -- for four passes and nothing stopped it"; fi
rm -rf "$W"

# --- CEILING is the validator's fourth rc-3 state, and both hooks once described it as a
# STALL: their `case` had DIVERGENT and REOPENED branches and a catch-all asserting STALLED.
# A deny that misnames the state hands the operator the wrong remedy with a confident verdict
# -- another CHANGE_APPROACH record, which is exactly what this state refuses.
# Each message is classified PRESENCE-first, so a copy that died and printed nothing reads
# `none` -- never a kill. `ceiling` = the CEILING text and no stall text; `stalled` = the
# CEILING header carrying the STALL text, which is exactly what the mutant must produce.
ceiling_msg_class() { # <out> -> ceiling | stalled | none
  case "$1" in *"(CEILING)"*) ;; *) echo none; return ;; esac
  case "$1" in *"it is STALLED"*) echo stalled; return ;; esac
  case "$1" in *RESOLUTION_CEILING*CUT_SCOPE*) echo ceiling; return ;; esac
  echo none
}
drive_ceiling() { # <ack-hook> <stop-hook> -> "<ack-verdict> <ack-class> <stop-class>"
  local w a s r=""
  w="$(seed_world ceiling)"
  a="$(printf '{"session_id":"t","transcript_path":"","tool_name":"Agent","tool_input":{"file_path":""}}' \
        | CLAUDE_PROJECT_DIR="$w" bash "$1" 2>/dev/null)"
  s="$(printf '{"session_id":"t","transcript_path":""}' | CLAUDE_PROJECT_DIR="$w" bash "$2" 2>/dev/null)"
  if denied "$a"; then r="deny"; else r="allow"; fi
  r="$r $(ceiling_msg_class "$a") $(ceiling_msg_class "$s")"
  rm -rf "$w"
  printf '%s' "$r"
}
CEIL="$(drive_ceiling "$ACK_HOOK" "$STOP_HOOK")"
case "$CEIL" in
  "deny "*) ok "CEILING: the Agent dispatch is DENIED" ;;
  *) bad "CEILING: dispatch ALLOWED on a series past the resolution ceiling ($CEIL)" ;;
esac
B_CEIL_ACK=0; B_CEIL_STOP=0
case "$CEIL" in
  *" ceiling "*) ok "CEILING: the PreToolUse deny names the resolution ceiling, not a stall"; B_CEIL_ACK=1 ;;
  *) bad "CEILING: the PreToolUse deny misnames the state ($CEIL)" ;;
esac
case "$CEIL" in
  *" ceiling") ok "CEILING: the Stop-hook block names the resolution ceiling, not a stall"; B_CEIL_STOP=1 ;;
  *) bad "CEILING: the Stop-hook block misnames the state ($CEIL)" ;;
esac

# MUTANT: collapse CEILING into STALLED in BOTH hooks. Built in a copy of the WHOLE hooks
# directory, because the continue hook resolves a sibling beside itself; `cmp -s` refuses a
# mutation that matched nothing. The message arms above must both go red.
MUTD="$(mktemp -d "${TMPDIR:-/tmp}/divergence-mut-XXXXXX")"
cp -R "$(dirname "$ACK_HOOK")/." "$MUTD/"
MUT_OK=1
for h in "$(basename "$ACK_HOOK")" "$(basename "$STOP_HOOK")"; do
  sed 's/^\([[:space:]]*\)STALLED)$/\1STALLED|CEILING)/' "$MUTD/$h" > "$MUTD/$h.mut" \
    && mv "$MUTD/$h.mut" "$MUTD/$h" || MUT_OK=0
  cmp -s "$MUTD/$h" "$(dirname "$ACK_HOOK")/$h" && MUT_OK=0
done
if [ "$MUT_OK" -ne 1 ] || [ ! -f "$MUTD/$(basename "$STOP_HOOK")" ]; then
  bad "FIXTURE BROKEN: the ceiling-collapsed-into-stalled mutant did not apply to both hooks"
else
  MCEIL="$(drive_ceiling "$MUTD/$(basename "$ACK_HOOK")" "$MUTD/$(basename "$STOP_HOOK")")"
  case "$MCEIL" in
    "deny stalled stalled") mutant_killed "$(( ${B_CEIL_ACK:-0} && ${B_CEIL_STOP:-0} ))" ceiling-as-stalled "mutant ceiling-as-stalled is KILLED by both message arms (both copies ran and printed the STALL text under a CEILING header)" ;;
    *" none"*) bad "FIXTURE BROKEN: a mutant hook copy printed no CEILING message at all ($MCEIL) -- it did not run, so no kill is scored" ;;
    *) bad "mutant ceiling-as-stalled SURVIVED ($MCEIL) -- the CEILING message arms cannot tell CEILING from STALLED" ;;
  esac
fi
rm -rf "$MUTD"

# =============================================================================
# 2. THE RESUME — a resolved cycle CAN dispatch. If this fails, the deadlock is back.
# =============================================================================
W="$(seed_world divergent-resolved)"
OUT="$(drive_ack "$W" Agent)"
if denied "$OUT"; then bad "RESOLVED: the verification pass was DENIED — there is no exit and the pipeline is wedged"
else ok "RESOLVED: the verification pass is ALLOWED (the record is the sanctioned exit)"; fi
rm -rf "$W"

# --- and the record itself must be WRITEABLE while paused. Check 2a denies every dispatch
# until the record exists; if the pause flag then denies the record, the two checks lock the
# pipeline against itself and the only way out is to switch off a hook.
W="$(seed_world divergent)"
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
W="$(seed_world divergent)"
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

# --- THE EFFECTS CLAUSE. On a locked entry ADJUDICATE recommends nothing and states each
# option's effect, INCLUDING the value it leaves in force -- the half an unbadged menu needs
# for the operator to see what each option does. Both hooks carry it; each is pinned on its
# own message. Classified PRESENCE-first: `none` = no deny/block to inspect, never a pass.
effects_class() { # <out> -> yes | no | none
  case "$1" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*|*'"decision":"block"'*|*'"decision": "block"'*) ;; *) echo none; return ;; esac
  case "$1" in *"value it leaves in force"*) echo yes ;; *) echo no ;; esac
}
drive_effects() { # <ack-hook> <stop-hook> -> "<ack-class> <stop-class>"
  local w a s
  w="$(seed_world divergent)"
  a="$(printf '{"session_id":"t","transcript_path":"","tool_name":"Agent","tool_input":{"file_path":""}}' \
        | CLAUDE_PROJECT_DIR="$w" bash "$1" 2>/dev/null)"
  rm -f "$w/_bmad-output/pipeline-paused.flag"
  s="$(printf '{"session_id":"t","transcript_path":""}' | CLAUDE_PROJECT_DIR="$w" bash "$2" 2>/dev/null)"
  rm -rf "$w"
  printf '%s %s' "$(effects_class "$a")" "$(effects_class "$s")"
}
EFF="$(drive_effects "$ACK_HOOK" "$STOP_HOOK")"
B_EFF_ACK=0; B_EFF_STOP=0
case "$EFF" in
  "yes "*) ok "ACK_HOOK: the ADJUDICATE step names the value each option leaves in force"; B_EFF_ACK=1 ;;
  *) bad "ACK_HOOK: the dispatch deny does not name the value each option leaves in force ($EFF)" ;;
esac
case "$EFF" in
  *" yes") ok "STOP_HOOK: the ADJUDICATE step names the value each option leaves in force"; B_EFF_STOP=1 ;;
  *) bad "STOP_HOOK: the Stop block does not name the value each option leaves in force ($EFF)" ;;
esac
# MUTANTS: delete the phrase from ONE hook at a time, in a copy of the whole hooks dir. Each
# must flip exactly its own arm; a copy that printed nothing reads `none` and is BROKEN.
for _mh in ACK STOP; do
  MUTD="$(mktemp -d "${TMPDIR:-/tmp}/divergence-eff-XXXXXX")"
  cp -R "$(dirname "$ACK_HOOK")/." "$MUTD/"
  if [ "$_mh" = ACK ]; then _mf="$(basename "$ACK_HOOK")"; _want="no yes"; else _mf="$(basename "$STOP_HOOK")"; _want="yes no"; fi
  sed 's/value it leaves in force/value it chooses/' "$MUTD/$_mf" > "$MUTD/$_mf.mut" && mv "$MUTD/$_mf.mut" "$MUTD/$_mf"
  if cmp -s "$MUTD/$_mf" "$(dirname "$ACK_HOOK")/$_mf"; then
    bad "FIXTURE BROKEN: the effects-clause mutant did not apply to $_mf"
  else
    MEFF="$(drive_effects "$MUTD/$(basename "$ACK_HOOK")" "$MUTD/$(basename "$STOP_HOOK")")"
    case "$MEFF" in
      "$_want") if [ "$_mh" = ACK ]; then mutant_killed "${B_EFF_ACK:-0}" ACK-effects-deleted "mutant ACK-effects-deleted is KILLED by its own arm only ($MEFF)"
                else mutant_killed "${B_EFF_STOP:-0}" STOP-effects-deleted "mutant STOP-effects-deleted is KILLED by its own arm only ($MEFF)"; fi ;;
      *none*) bad "FIXTURE BROKEN: a mutant hook copy printed no deny/block ($MEFF) -- it did not run, so no kill is scored" ;;
      *) bad "mutant $_mh-effects-deleted: got '$MEFF', wanted '$_want'" ;;
    esac
  fi
  rm -rf "$MUTD"
done
unset _mh _mf _want

# =============================================================================
# 4. THE DECOYS — a guard that fires on a working cycle gets ripped out.
# =============================================================================
for c in converged in-progress; do
  W="$(seed_world "$c")"
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
W="$(seed_world resolved-then-touched)"
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
W="$(seed_world divergent)"
drive_stop "$W" >/dev/null
[ -f "$W/_bmad-output/.adversarial-stop" ] || bad "no .adversarial-stop written on a STOP"
# the operator resolves it; the state must self-heal on the next turn
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
W="$(seed_world divergent)"
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
W="$(seed_world divergent)"
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
# ...and that report is the LOUD, mis-declared form: sprint-id fell back to 1, which no s0/ precedes.
if grep -q 'Fix the declared sprint' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "...in the mis-declared form (\"Fix the declared sprint\"), not the pending-sprint form"
else
  bad "an unresolvable sprint was reported WITHOUT the fix-the-sprint remedy — the pending form swallowed a real mis-declaration"
fi
rm -rf "$W"

# =============================================================================
# 9. A SPRINT BEFORE ITS FIRST ARTIFACT is not a mis-declared sprint (BL-571).
# =============================================================================
# The resolved sprint's s<N>/ is absent in TWO states: the declaration is wrong, or the sprint is
# new and has written nothing yet -- the second is every sprint's first hours, and the reference
# consumer logged 67 such entries in one window, each telling the lead to "Fix the declared sprint"
# that was correct. The hooks now tell them apart inside the I81 block: PENDING when s<N-1>/ exists
# and no s<K>/ with K > N does. Every world here is a minimal tree with a stub `sprint-id`, because
# the s<N>/ directory being absent means no series exists to adjudicate -- seed.sh's validator and
# envelope would buy nothing. Each hook is driven alone on a fresh tree and classified PRESENCE-
# first: `none` = no UNADJUDICABLE row, `pending` = the pending form and no fix-the-sprint text,
# `loud` = the fix-the-sprint form, `both` = a row carrying both (a broken emitter).
pend_world() { # <sprint-id> <existing s<K> dirs...> -> work dir
  local n="$1" w k; shift
  w="$(mktemp -d "${TMPDIR:-/tmp}/divergence-pend-XXXXXX")"
  mkdir -p "$w/_bmad-output/planning-artifacts" "$w/scripts/ai-dlc"
  : > "$w/_bmad-output/pipeline-snapshot.md"
  for k in "$@"; do mkdir -p "$w/_bmad-output/planning-artifacts/s$k"; done
  printf '#!/bin/bash\necho %s\n' "$n" > "$w/scripts/ai-dlc/sprint-status.sh"
  chmod +x "$w/scripts/ai-dlc/sprint-status.sh"
  printf '%s' "$w"
}
unadj_class() { # <work> -> none | pending | loud | both
  local log="$1/_bmad-output/pipeline-continuation-log.md" p=0 l=0
  grep -q '^## .*-- ADVERSARIAL_STATE_UNADJUDICABLE$' "$log" 2>/dev/null || { echo none; return; }
  grep -q 'not yet created' "$log" && p=1
  grep -q 'Fix the declared sprint' "$log" && l=1
  case "$p$l" in 10) echo pending ;; 01) echo loud ;; 11) echo both ;; *) echo none ;; esac
}
pend_cells() { # <ack-hook> <stop-hook> -> "<ack class>/<stop class>" for worlds pend skip later present
  local a="$1" s="$2" spec w r="" ca cs
  for spec in "8 7" "9 7" "8 7 9" "8 7 8"; do
    # shellcheck disable=SC2086
    w="$(pend_world $spec)"
    printf '{"session_id":"t","transcript_path":"","tool_name":"Agent","tool_input":{}}' \
      | CLAUDE_PROJECT_DIR="$w" bash "$a" >/dev/null 2>&1
    ca="$(unadj_class "$w")"
    rm -f "$w/_bmad-output/pipeline-continuation-log.md"
    printf '{"session_id":"t","transcript_path":""}' | CLAUDE_PROJECT_DIR="$w" bash "$s" >/dev/null 2>&1
    cs="$(unadj_class "$w")"
    rm -rf "$w"
    r="$r $ca/$cs"
  done
  printf '%s' "${r# }"
}
PEND_WANT="pending/pending loud/loud loud/loud none/none"
PEND="$(pend_cells "$ACK_HOOK" "$STOP_HOOK")"
set -- $PEND
B_PEND=0; B_SKIP=0; B_LATER=0; B_PRES=0
case "$1" in pending/pending) ok "PENDING: sprint-id 8 with s7/ present and no s8/ yet logs the pending form in BOTH hooks — no \"Fix the declared sprint\""; B_PEND=1 ;;
  *) bad "PENDING: a sprint before its first artifact was not reported in the pending form by both hooks (ack/stop '$1')" ;; esac
case "$2" in loud/loud) ok "SKIP: sprint-id 9 with only s7/ (no s8/) keeps the mis-declared form in BOTH hooks"; B_SKIP=1 ;;
  *) bad "SKIP: a declaration that skips a sprint was not reported as mis-declared by both hooks (ack/stop '$2')" ;; esac
case "$3" in loud/loud) ok "LATER: sprint-id 8 with s7/ AND s9/ keeps the mis-declared form in BOTH hooks — a later sprint already wrote"; B_LATER=1 ;;
  *) bad "LATER: a sprint behind an existing later sprint was reported as pending (ack/stop '$3')" ;; esac
case "$4" in none/none) ok "PRESENT: sprint-id 8 with s8/ present logs no UNADJUDICABLE row in either hook (the control)"; B_PRES=1 ;;
  *) bad "PRESENT: the sprint's own directory exists and a hook still logged UNADJUDICABLE (ack/stop '$4')" ;; esac

# MUTANTS, each in a copy of the WHOLE hooks dir. The I81 block is byte-identical in both hooks, so a
# predicate mutant is applied to both; an emitter mutant to one. A copy that never ran classifies every
# world `none`, which matches no wanted row.
pend_mutant() { # <label> <want> <sed> <hook basenames...>
  local label="$1" want="$2" prog="$3" d h got applied=1; shift 3
  d="$(mktemp -d "${TMPDIR:-/tmp}/divergence-pmut-XXXXXX")"
  cp -R "$(dirname "$ACK_HOOK")/." "$d/"
  for h in "$@"; do
    sed "$prog" "$d/$h" > "$d/$h.mut" && mv "$d/$h.mut" "$d/$h" || applied=0
    cmp -s "$d/$h" "$(dirname "$ACK_HOOK")/$h" && applied=0
  done
  if [ "$applied" -ne 1 ]; then bad "FIXTURE BROKEN: pending mutant $label did not apply to $*"
  else
    got="$(pend_cells "$d/$(basename "$ACK_HOOK")" "$d/$(basename "$STOP_HOOK")")"
    # A pend mutant is scored on the whole four-world vector, so its base is all four arms holding.
    if [ "$got" = "$want" ]; then mutant_killed "$(( ${B_PEND:-0} && ${B_SKIP:-0} && ${B_LATER:-0} && ${B_PRES:-0} ))" "$label" "mutant $label is KILLED ($got)"
    else bad "mutant $label: got '$got', wanted '$want'"; fi
  fi
  rm -rf "$d"
}
AB="$(basename "$ACK_HOOK")"; SB="$(basename "$STOP_HOOK")"
# The previous-dir test is what separates a NEW sprint from a SKIPPED number: without it sprint-id 9
# over s7/ alone reads as pending. (Arm PENDING reading the loud form is the emitter mutants below.)
pend_mutant previous-dir-test-deleted "pending/pending pending/pending loud/loud none/none" \
  's#&& \[ -d "\${ART_DIR}/s\$((10\#\$SPRINT_N - 1))" \] ##' "$AB" "$SB"
pend_mutant later-dir-test-deleted "pending/pending loud/loud pending/pending none/none" \
  's#&& \[ "\$_later" -eq 0 \] ##' "$AB" "$SB"
pend_mutant ack-emitter-swapped "loud/pending loud/loud loud/loud none/none" \
  's/^    if \[ "\$SPRINT_PENDING" -eq 1 \]; then$/    if false; then/' "$AB"
pend_mutant stop-emitter-swapped "pending/loud loud/loud loud/loud none/none" \
  's/^  if \[ "\$SPRINT_PENDING" -eq 1 \]; then$/  if false; then/' "$SB"
set --

# =============================================================================
# 10. THE CAP AND ITS ERA (BL-911) -- a series is bounded at p3, and the bound reaches the hooks.
# =============================================================================
# A pass numbered 3 or more that does not stamp EXIT_CONDITION_MET STOPS the series (`--cycle-state` CAPPED,
# rc 3) until a resolution record resolving it exists; a later pass that walked past it without a valid one
# keeps it CAPPED. Both hooks shell out to the SAME validator, so each cell drives the world's own
# scripts/ai-dlc/ copy and reads three things: the PreToolUse dispatch (`capped` = denied AND naming
# "CAPPED at p3", `allow`, `other` = denied for some other reason), the Stop hook's message (`capped` = it names
# "CAPPED at p3", `none` otherwise -- the Stop hook blocks every active pipeline that yields, so its decision
# is not the signal), and, for the era worlds, the GATE's arms M and N (`pending` = both PENDING lines and no
# FAIL (M/N), `fail` = a FAIL (M or (N, `none`). Every deny cell has an ALLOW twin one property apart:
#   cap-notoken   the real rulebook with the token sentence reworded; no git     allow none
#   cap-bound     p1 p2 p3(NOT_MET), token committed 2026-07-01 before the series capped capped
#   cap-from-p2   p2 p3(NOT_MET): p3 is the SECOND pass; the cap keys on NUMBER   capped capped
#   cap-inprog    p1 p2(NOT_MET): no p3                                            allow none
#   cap-norecord  p4 MET walked past the capped p3 with no resolves_divergence:    capped capped fail
#   cap-record    the same p4 declaring a valid record resolving p3               allow none none
#   cap-badrecord the same p4 declaring a record that resolves p9, which is absent capped capped fail
#                 (the three record worlds read the GATE too, handed the seeded operator transcript, so the
#                 gate is shown ACCEPTING the valid record, not only the fail-open --cycle-state path)
#   era-between   engine committed 07-01, the token committed 07-20, the series   allow none pending
#                 opened 07-12: the era is the token's commit, so it is LEGACY at the gate AND at the hooks
#   era-bound     the same, token committed 07-05: bound, and its sharded p2 lacks capped capped fail
#                 shard_set_derived_from: (arm N)
#   era-merge-before  the token committed on main 07-05, --no-ff merged into the  allow none pending
#                 sprint branch 07-20, the series opened 07-10: dated by the merge (first parent), LEGACY
#   era-merge-after   the same topology, the series opened 07-21: bound            capped capped fail
# All dates are literal (BL-868); seed.sh commits with fixed GIT_COMMITTER_DATE.
cap_cell() { # <validator copy or -> <case> [gate] -> "<ack> <stop>[ <gate>]"
  local w a s ac sc gc g
  w="$(seed_world "$2")" || { printf 'SEED SEED SEED'; return 0; }
  [ "$1" = - ] || cp "$1" "$w/scripts/ai-dlc/validate-adversarial-convergence.sh"
  a="$(drive_ack "$w" Agent)"
  rm -f "$w/_bmad-output/pipeline-paused.flag"
  s="$(drive_stop "$w")"
  if denied "$a"; then case "$a" in *"CAPPED at p3"*) ac=capped ;; *) ac=other ;; esac; else ac=allow; fi
  case "$s" in *"CAPPED at p3"*) sc=capped ;; *) sc=none ;; esac
  if [ "${3:-}" = gate ]; then
    # The record worlds carry the operator transcript the gate verifies their citation against (F6); a gate run
    # without one fails CLOSED on the citation, which would read as the cap refusing a valid record.
    g="$(bash "$w/scripts/ai-dlc/validate-adversarial-convergence.sh" --series "$w/_bmad-output/planning-artifacts/s7/brief-adversarial-p" \
          ${4:+--transcript "$w/operator-transcript.jsonl"} 2>&1)"
    case "$g" in
      *"adversarial convergence --"*) ;;
      *) printf '%s %s norun' "$ac" "$sc"; rm -rf "$w"; return 0 ;;
    esac
    case "$g" in
      *"FAIL (M -- CAP)"*|*"FAIL (N -- WIDTH)"*) gc=fail ;;
      *"PENDING (M -- CAP)"*"PENDING (N -- WIDTH)"*) gc=pending ;;
      *) gc=none ;;
    esac
    printf '%s %s %s' "$ac" "$sc" "$gc"
  else
    printf '%s %s' "$ac" "$sc"
  fi
  rm -rf "$w"
}
cap_want() { # <case> -> the shipped validator's row
  case "$1" in
    cap-notoken|cap-inprog) echo "allow none" ;;
    cap-bound|cap-from-p2) echo "capped capped" ;;
    cap-norecord|cap-badrecord) echo "capped capped fail" ;;
    cap-record) echo "allow none none" ;;
    era-between|era-merge-before) echo "allow none pending" ;;
    era-bound|era-merge-after) echo "capped capped fail" ;;
  esac
}
# The era worlds and the three record worlds also read the GATE; the record worlds hand it their transcript.
cap_gate() { case "$1" in era-*) echo gate ;; cap-norecord|cap-record|cap-badrecord) echo "gate t" ;; esac; }
CAP_CASES="cap-notoken cap-bound cap-from-p2 cap-inprog cap-norecord cap-record cap-badrecord era-between era-bound era-merge-before era-merge-after"
CAP_N=0; B_CAPROW=0; CAP_WANT_N=0
for _c in $CAP_CASES; do CAP_WANT_N=$((CAP_WANT_N + 1)); done
for _c in $CAP_CASES; do
  _g="$(cap_cell - "$_c" $(cap_gate "$_c"))"; _w="$(cap_want "$_c")"
  if [ "$_g" = "$_w" ]; then ok "CAP $_c: dispatch/stop$([ -n "$(cap_gate "$_c")" ] && echo /gate) = $_g"; CAP_N=$((CAP_N + 1))
  else bad "CAP $_c: dispatch/stop$([ -n "$(cap_gate "$_c")" ] && echo /gate) = '$_g', want '$_w'"; fi
done
# Every cap mutant is gated on the WHOLE shipped row having held in this run (each mutant reads two of its cells).
if [ "$CAP_N" -eq "$CAP_WANT_N" ]; then ok "CAP row: all $CAP_WANT_N cap/era cells hold on the shipped validator and hooks"; B_CAPROW=1
else bad "CAP row: $CAP_N of $CAP_WANT_N cap/era cells hold; no cap mutant can be scored"; fi
# MUTANTS of the validator, each a copy of the shipped file with every anchor applied exactly once (python
# refuses a missing or repeated anchor), copied into the world's scripts/ai-dlc/ in place of the shipped one.
# Each runs only its DECIDING case and one TWIN case that must keep the shipped row. The kill is gated on both
# cases' base rows having held in this run.
cap_mut() { # <label> <deciding case> <twin case> <old> <new> [<old> <new>]...
  local label="$1" dec="$2" twin="$3" d f gd gt wd wt; shift 3
  d="$(mktemp -d "${TMPDIR:-/tmp}/divergence-cmut-XXXXXX")"; f="$d/validate-adversarial-convergence.sh"
  if ! python3 - "$W_VALIDATOR" "$f" "$@" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read(); a = sys.argv[3:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1: sys.exit(3)
    s = s.replace(a[i], a[i + 1])
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
  then bad "FIXTURE STALE: mutant $label -- an anchor is not in the validator exactly once"; rm -rf "$d"; return; fi
  if cmp -s "$W_VALIDATOR" "$f" || ! bash -n "$f" 2>/dev/null; then bad "FIXTURE STALE: mutant $label DID NOT APPLY or is not valid shell"; rm -rf "$d"; return; fi
  wd="$(cap_want "$dec")"; wt="$(cap_want "$twin")"
  gd="$(cap_cell "$f" "$dec" $(cap_gate "$dec"))"; gt="$(cap_cell "$f" "$twin" $(cap_gate "$twin"))"
  if [ "$gt" != "$wt" ]; then bad "mutant $label: its twin $twin moved too ('$gt', want '$wt') -- the kill is not its own arm's"
  elif [ "$gd" = "$wd" ]; then bad "mutant $label SURVIVED: $dec still reads '$gd'"
  else mutant_killed "${B_CAPROW:-0}" "$label" "mutant $label is KILLED by CAP $dec ('$gd', shipped '$wd'); twin $twin holds"; fi
  rm -rf "$d"
}
W_VALIDATOR="$(pick "$HERE/../../scripts/validate-adversarial-convergence.sh" \
                    "$HERE/../../../scripts/ai-dlc/validate-adversarial-convergence.sh" \
                    "$HERE/../../core/scripts/validate-adversarial-convergence.sh")"
if [ -z "$W_VALIDATOR" ]; then bad "FIXTURE BROKEN: the validator is not found; no cap mutant is scored"
else
  # Cap at p4, the self-probe moved with it (a cap_capped mutant alone exits 2 on that probe, no verdict).
  cap_mut cap-at-p4 cap-bound cap-inprog \
    'cap_capped() { case "${1:-}" in ""|*[!0-9]*) return 1 ;; esac; [ "$1" -ge 3 ]' \
    'cap_capped() { case "${1:-}" in ""|*[!0-9]*) return 1 ;; esac; [ "$1" -ge 4 ]' \
    'if ! cap_capped 3 EXIT_CONDITION_NOT_MET || cap_capped 3 EXIT_CONDITION_MET || cap_capped 2 EXIT_CONDITION_NOT_MET' \
    'if ! cap_capped 4 EXIT_CONDITION_NOT_MET || cap_capped 4 EXIT_CONDITION_MET || cap_capped 3 EXIT_CONDITION_NOT_MET'
  # Cap by POSITION in the series instead of by pass number.
  cap_mut cap-by-position cap-from-p2 cap-bound \
    'for ((i = 0; i < N; i++)); do cap_capped "${P_NUM[$i]}"' 'for ((i = 0; i < N; i++)); do cap_capped "$((i + 1))"' \
    '      cap_capped "${P_NUM[$i]}" "${P_VERDICT[$i]}" || continue' '      cap_capped "$((i + 1))" "${P_VERDICT[$i]}" || continue' \
    'if cap_capped "${P_NUM[$((N - 1))]}" "$LAST_VERDICT"' 'if cap_capped "$N" "$LAST_VERDICT"'
  # Accept any record FILE a walked-past pass names, whatever pass it resolves (one that does not exist).
  cap_mut cap-accepts-nonexistent-pass cap-badrecord cap-norecord \
    'if ! validate_record "$cap_rec" "${P_FILE[$i]}" "$i"; then' 'if [ ! -f "$cap_rec" ]; then'
  # The era: the token check dropped (a tree whose rulebook carries no token is bound anyway).
  cap_mut era-token-check-dropped cap-notoken cap-bound \
    'grep -qF -- "$ERA_TOKEN" "$ERA_ROOT/.claude/skills/ai-dlc/steps/_gate-procedures.md" 2>/dev/null || return 0' ':'
  # The era: the date gate dropped (a token committed AFTER the series opened binds it anyway).
  cap_mut era-date-gate-dropped era-between era-bound \
    'era_cmp "${2:-}" "$ERA_STAMP" || ERA_STATE=legacy ;;' ': ;;'
  # Legacy keyed on the field's ABSENCE: a bound sharded pass without shard_set_derived_from: is skipped.
  cap_mut legacy-on-field-absence era-bound era-between \
    '      if [ -z "$n_from" ]; then' '      if [ -z "$n_from" ]; then continue; fi; if false; then'
  # The era keyed on the ENGINE's install commit, not the rulebook's: `-S` over the validator, which carries
  # the ERA_TOKEN literal, finds the 07-01 engine commit and binds a series the rulebook did not yet carry.
  cap_mut era-on-engine-commit era-between era-bound \
    '      -- .claude/skills/ai-dlc/steps/_gate-procedures.md 2>/dev/null | tail -n 1)"' \
    '      -- scripts/ai-dlc/validate-adversarial-convergence.sh 2>/dev/null | tail -n 1)"'
  # The era dated by the token's ORIGINAL commit, not its first-parent arrival: without --first-parent the 07-05
  # commit on main dates a token the sprint branch carried only from its 07-20 merge, and binds the 07-10 series.
  # The era-merge cells exercise only the hooks and the gate, not era_resolve.
  cap_mut era-not-first-parent era-merge-before era-merge-after \
    'log --first-parent --diff-merges=first-parent --no-patch' 'log --diff-merges=first-parent --no-patch'
fi
unset _c _g _w
drop_world_cache

echo
report_end divergence-hard-block
