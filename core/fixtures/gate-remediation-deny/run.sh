#!/usr/bin/env bash
# gate-remediation-deny — the lead may not repair a failing gate check itself,
# and it may not write itself a permission slip to do so.
#
# THE DEFECT THIS CATCHES. One `[story]` gate on the reference consumer ran 11
# adjudication passes and stopped. Across that window the lead issued 104 `Edit`
# calls and dispatched the `remediator` ZERO times, while the context sensor fired
# RED twice mid-repair. Rule 28 already forbids this in the strongest prose it has
# ("The lead does NOT get to reason 'this is small, I'll just do it'"), and prose
# produced 104 edits — because the lead has a sanctioned channel for authorizing
# its own deviations and used it after the fact, in the pipeline snapshot, as
# `DECIDED_AUTONOMOUSLY (Rule 12 Tier 2)`.
#
# So the assertions below come in three families and ALL THREE must hold:
#
#   THE DENY FIRES     a lead edit to the corpus during a failing pass is refused
#                      (or the mechanism is decorative)
#   THE DENY PASSES    a dispatched teammate, a clean pass, a Rule 28(a) mutation
#                      and a file outside the corpus all go through
#                      (or the hook wedges the pipeline it protects, gets switched
#                      off, and then nothing is watching at all)
#   THE DENY IS NOT SELF-DISCHARGEABLE
#                      no record the LEAD can author lifts it — not a
#                      DECIDED_AUTONOMOUSLY disposition, not a repair record for a
#                      different pass, not one claiming a check that is not
#                      failing, not one quoting an agent that was never dispatched,
#                      and not an operator citation nothing can verify
#                      (or the opt-out has been rebuilt inside the mechanism)
#
# A guard with only the first family is indistinguishable from a hook that denies
# everything; a guard with only the second is indistinguishable from one that
# denies nothing. The third is the one this change exists for.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook (I10 / I87).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HOOK="$(pick "$HERE/../../hooks/ai-dlc-gate-remediation-guard.sh" \
             "$HERE/../../../.claude/hooks/ai-dlc-gate-remediation-guard.sh" \
             "$HERE/../../../core/hooks/ai-dlc-gate-remediation-guard.sh")"
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-gate-remediation-guard.sh" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq absent; every arm would fail open" >&2; exit 2; }

# The candidate list above spans both install layouts and takes the first that EXISTS, so the
# file this unit drives is not necessarily the one an author just edited. Print it: a mutant
# applied to the other copy leaves every arm green and reads exactly like an arm that cannot
# fire, and `cmp -s` cannot tell those apart.
echo "gate-remediation-deny: resolved subject = $(cd "$(dirname "$HOOK")" && pwd)/$(basename "$HOOK")"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive the PreToolUse hook. `agent` empty => the LEAD (the harness omits agent_id
# on the main thread; `ai-dlc-context-sensor.sh:160` reads exactly that field).
drive() { # <work> <tool> <file_path> [agent_id] [transcript] [hook-override]
  local w="$1" tool="$2" fp="$3" agent="${4:-}" tr="${5:-}" h="${6:-$HOOK}"
  jq -nc --arg t "$tool" --arg f "$fp" --arg a "$agent" --arg tr "$tr" \
    '{session_id:"t", tool_name:$t, transcript_path:$tr, tool_input:{file_path:$f}}
     + (if $a == "" then {} else {agent_id:$a} end)' \
    | CLAUDE_PROJECT_DIR="$w" bash "$h" 2>/dev/null
}
denied() { case "$1" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) return 0 ;; esac; return 1; }

# SEED THROUGH HERE, NEVER `$(bash seed.sh ...)` DIRECTLY. A workspace that came out
# unusable makes the guard exit at its no-pipeline-snapshot arm for every call, and the
# fixture then reports ~20 assertion failures that read exactly like the deny having been
# deleted. Measured: a workspace missing only the snapshot fails 20 of 37, against 19 for
# the deny removed outright — indistinguishable in practice. So a broken workspace ABORTS
# the run (exit 2, "FIXTURE ERROR") rather than scoring a single assertion. seed.sh checks
# its own writes too; this is the arm that catches a seed that exited non-zero.
#
# IT SETS THE GLOBAL `W` AND IS CALLED BARE -- `seed open-fail`, NEVER
# `W="$(seed open-fail)"`. That is not style. The first draft of this guard printed the
# path and was called in a command substitution, so its `exit 2` killed the SUBSHELL and
# the parent carried on with an empty `W` and scored all 22 arms anyway. The FIXTURE ERROR
# line was printed and ignored -- a guard that half-fires, which reads even more like a
# pass than one that never fires at all. Assign to a global so `exit` runs in the shell
# that has to stop.
seed() { # <case> -> sets W, or aborts the whole run
  W="$(bash "$HERE/seed.sh" "$1")" || { echo "FIXTURE ERROR: seed.sh '$1' exited non-zero" >&2; exit 2; }
  [ -n "$W" ] && [ -d "$W" ] && [ -s "$W/_bmad-output/pipeline-snapshot.md" ] \
    || { echo "FIXTURE ERROR: seed '$1' produced no usable workspace ('${W}'); every arm would score the guard as denying nothing" >&2; exit 2; }
}

echo "gate-remediation-deny:"

ART="_bmad-output/planning-artifacts/s302/test-strategy.md"

# =============================================================================
# ARM (a) — THE DENY. A lead edit to a planning artifact during a failing pass.
# =============================================================================
seed open-fail
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then ok "(a) lead Edit to a planning artifact during an open FAILing pass is DENIED"
else bad "(a) lead Edit ALLOWED — this is the 104-edit cascade, unimpeded"; fi

# The message must be actionable, and EVERY message assertion is guarded on the
# denial existing first. A grep-for-content over an empty string scores a silent
# pass against a hook that never denies anything — a check that cannot fire,
# living inside the fixture written to catch checks that cannot fire.
if denied "$OUT"; then
  case "$OUT" in *"remediator"*) ok "(a) the deny names the dispatch target (remediator)" ;;
    *) bad "(a) the deny does not name who should do the repair" ;; esac
  case "$OUT" in *".repair.md"*) ok "(a) the deny names the repair-record path that lifts it" ;;
    *) bad "(a) the deny gives no sanctioned exit — a denial with no way out IS the deadlock" ;; esac
  case "$OUT" in *"DECIDED_AUTONOMOUSLY"*) ok "(a) the deny says a self-authored disposition will not lift it" ;;
    *) bad "(a) the deny never rules out DECIDED_AUTONOMOUSLY — the lead's first move will be to write one" ;; esac
  case "$OUT" in *"check(s) \`7 3a\`"*|*'check(s) `7 3a`'*) ok "(a) the deny names the FAILing check_ids (7 3a)" ;;
    *) bad "(a) the deny does not say WHICH checks failed, so the dispatch brief cannot be written from it" ;; esac
  case "$OUT" in *"docs/escalations"*) ok "(a) the deny names escalation as the exit when repair is not a remediator's call" ;;
    *) bad "(a) no escalation route — the remediator refused exactly this once, and the lead edited anyway" ;; esac
else
  bad "(a) no denial to inspect; the five message assertions below prove nothing"
  bad "  (names-the-dispatch-target)"; bad "  (names-the-repair-record)"
  bad "  (rules-out-DECIDED_AUTONOMOUSLY)"; bad "  (names-the-failing-checks)"
  bad "  (names-the-escalation-exit)"
fi

# ...and the same edit reaches every measured target, not just the one arm above.
for t in "_bmad-output/planning-artifacts/s302/traceability-matrix.md" \
         "_bmad-output/implementation-artifacts/s302/e2e-trace-summary.json" \
         "docs/architecture.md"; do
  OUT="$(drive "$W" Write "$W/$t")"
  if denied "$OUT"; then ok "(a) $t is DENIED too"
  else bad "(a) $t was ALLOWED — the guarded root does not cover a measured top edit target"; fi
done
# MultiEdit carries the same field and must not be a hole.
OUT="$(drive "$W" MultiEdit "$W/$ART")"
if denied "$OUT"; then ok "(a) MultiEdit is DENIED (same payload field, same rule)"
else bad "(a) MultiEdit ALLOWED — one tool name is a complete bypass"; fi

# =============================================================================
# ARM (b) — THE DISPATCHED TEAMMATE. If this fails the hook wedges the fix.
# =============================================================================
OUT="$(drive "$W" Edit "$W/$ART" "remediator@session-abc123")"
if denied "$OUT"; then bad "(b) a dispatched remediator was DENIED — the hook blocks the repair it demands"
else ok "(b) the IDENTICAL edit with agent_id present is ALLOWED (the remediator repairs freely)"; fi

# =============================================================================
# ARM (c) — THE PERMITTED SET (Rule 28(a)). Enumerated, and each one tested.
# =============================================================================
for p in "_bmad-output/pipeline-snapshot.md" \
         "_bmad-output/pipeline-snapshot-history.md" \
         "_bmad-output/validation-cycle-log.md" \
         "_bmad-output/pipeline-continuation-log.md" \
         "_bmad-output/planning-artifacts/sprint-status.yaml" \
         "_bmad-output/implementation-artifacts/sprint-status.yaml" \
         "docs/escalations/pending.md" \
         "_bmad-output/planning-artifacts/s302/brief-resolution-p2.md" \
         "_bmad-output/ai-dlc-update/reconcile-report.md"; do
  OUT="$(drive "$W" Edit "$W/$p")"
  if denied "$OUT"; then bad "(c) Rule 28(a) path DENIED: $p — the hook wedges the pipeline it protects"
  else ok "(c) permitted: $p"; fi
done
# ...and OUTSIDE the guarded roots entirely.
OUT="$(drive "$W" Edit "$W/src/main.c")"
if denied "$OUT"; then bad "(c) source code DENIED — out of scope by declaration, and denying it has no measurement behind it"
else ok "(c) source outside the guarded roots is untouched"; fi

# ...but the permit list must be NARROW. The lead may not write the verdict, nor
# its own repair record: either one is the opt-out rebuilt one file over.
for n in "_bmad-output/gate-adjudication/story-20260811T193044Z.repair.md" \
         "_bmad-output/planning-artifacts/s302/gate-story-repair-p1.md"; do
  OUT="$(drive "$W" Write "$W/$n")"
  if denied "$OUT"; then ok "(c) the lead may NOT author the repair record itself: $(basename "$n")"
  else bad "(c) the lead can write $(basename "$n") — it can now write its own lift"; fi
done
rm -rf "$W"

# =============================================================================
# ARM (d) — SELF-DISCHARGE. The one this change turns on.
# =============================================================================
seed open-fail
cat >> "$W/_bmad-output/pipeline-snapshot.md" <<'EOF'

## Dispositions
- MINOR-7's direct fix (`test-strategy.md:474-475`) — DECIDED_AUTONOMOUSLY (Rule 12 Tier 2).
  Chose re-stamp over revert (fix independently confirmed correct twice; reverting to
  dodge process friction would restore a known defect). Lead applied that one directly.
EOF
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then ok "(d) a DECIDED_AUTONOMOUSLY (Rule 12 Tier 2) disposition does NOT lift the deny"
else bad "(d) the lead cleared its own block by writing its own record — the opt-out is back, one layer down"; fi

# The disposition is REAL, not a decoy that never landed. Without this control the
# arm above passes on a hook that reads the snapshot and on one that ignores it,
# and on a seed where the write silently failed.
if grep -q 'DECIDED_AUTONOMOUSLY' "$W/_bmad-output/pipeline-snapshot.md"; then
  ok "(d) control: the disposition really is on disk (the arm above is not vacuous)"
else
  bad "(d) FIXTURE BROKEN: no disposition was written, so arm (d) asserted nothing"
fi
rm -rf "$W"

# =============================================================================
# THE LIFT — and its four forgeries.
# =============================================================================
seed open-fail
TR="$W/transcript.jsonl"
printf '{"type":"assistant","content":"dispatching"}\n{"agent_id":"remediator@session-abc123"}\n' > "$TR"
REC="$W/_bmad-output/gate-adjudication/story-20260811T193044Z.repair.md"

# 1. THE GENUINE ONE. Bound to the live nonce, naming a live FAIL, quoting an
#    agent_id that really appears in this session's transcript.
cat > "$REC" <<'EOF'
# Gate repair record
gate_nonce: story-20260811T193044Z
remediator_agent_id: remediator@session-abc123
repaired_checks: 7, 3a
EOF
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR")"
if denied "$OUT"; then bad "LIFT: a genuine dispatched repair record did NOT lift the deny — the pipeline is wedged after the repair"
else ok "LIFT: a bound remediator repair record lifts the deny (the sanctioned exit works)"; fi

# 2. WRONG PASS. A record for an earlier nonce must not lift a later one — this is
#    the whole reason the bind is the nonce and not proximity or mtime.
sed 's/story-20260811T193044Z/story-20260810T101010Z/' "$REC" > "$REC.tmp" && mv "$REC.tmp" "$REC"
cmp -s <(printf 'gate_nonce: story-20260811T193044Z\n') "$REC" && bad "MUTANT BROKEN: the nonce substitution did not apply"
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR")"
if denied "$OUT"; then ok "LIFT: a repair record for a DIFFERENT pass does not lift (the bind is the nonce)"
else bad "LIFT: a stale repair record lifted a later pass — every subsequent pass is now free"; fi

# 3. WRONG CHECK. A record that repaired something that is not failing is not a
#    repair of this failure.
cat > "$REC" <<'EOF'
gate_nonce: story-20260811T193044Z
remediator_agent_id: remediator@session-abc123
repaired_checks: 2
EOF
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR")"
if denied "$OUT"; then ok "LIFT: a record claiming only a PASSING check does not lift (token match, not substring)"
else bad "LIFT: any repair record at all lifts, whatever it claims to have repaired"; fi

# 4. FORGED DISPATCH. The lead writes the record itself and invents an agent_id.
#    Fail CLOSED: the transcript is readable and the id is not in it.
cat > "$REC" <<'EOF'
gate_nonce: story-20260811T193044Z
remediator_agent_id: remediator@session-never-dispatched
repaired_checks: 7
EOF
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR")"
if denied "$OUT"; then ok "LIFT: an agent_id that appears in NO dispatch in the transcript does not lift"
else bad "LIFT: the lead can lift its own deny by inventing an agent_id"; fi

# 5. NO agent_id AT ALL — the structural floor must still hold.
printf 'gate_nonce: story-20260811T193044Z\nrepaired_checks: 7\n' > "$REC"
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR")"
if denied "$OUT"; then ok "LIFT: a record with no remediator_agent_id does not lift"
else bad "LIFT: an unattributed record lifts — 'a remediator did it' is then just an assertion"; fi
rm -f "$REC"

# 6. OPERATOR AUTHORIZATION, UNVERIFIABLE. Declared fail-CLOSED: the citation is
#    the entire claim and it is the arm the lead could otherwise author.
cat > "$W/_bmad-output/gate-adjudication/story-20260811T193044Z.authorization.md" <<'EOF'
operator_authorization: 2026-08-11T19:55:54Z | "go ahead and re-stamp it yourself"
EOF
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR")"
if denied "$OUT"; then ok "LIFT: an operator citation with no verifier present does NOT lift (fail CLOSED)"
else bad "LIFT: an unverifiable operator quote lifted the deny — S290 rebuilt in a new place"; fi
rm -rf "$W"

# =============================================================================
# THE LIFT, WITH THE VERIFIER PRESENT — the branch arm 6 above can never reach.
# =============================================================================
# Arm 6 is the `[ -f "$STEER_SCRIPT" ]` guard failing: the seed leaves
# `scripts/ai-dlc/` EMPTY, so the whole authorization block short-circuits and
# the corpus-vs-file resolution below it never executes at all. Every arm above
# this line is therefore blind to it, which is how a defect sat in that
# resolution unmeasured. These arms put the real validator in the workspace.
seed open-fail
STEER="$(pick "$HERE/../../scripts/validate-steering-budget.sh" \
              "$HERE/../../../scripts/ai-dlc/validate-steering-budget.sh" \
              "$HERE/../../core/scripts/validate-steering-budget.sh")"
[ -n "$STEER" ] || { echo "FIXTURE ERROR: cannot locate validate-steering-budget.sh; every arm below would score arm 6's fail-CLOSED as this branch holding" >&2; exit 2; }
cp "$STEER" "$W/scripts/ai-dlc/validate-steering-budget.sh"
[ -f "$W/scripts/ai-dlc/validate-steering-budget.sh" ] \
  || { echo "FIXTURE ERROR: the verifier did not land in the workspace" >&2; exit 2; }
command -v node >/dev/null 2>&1 || { echo "FIXTURE ERROR: node absent; the verifier exits non-zero for every arm and each would read as fail-CLOSED" >&2; exit 2; }

AUTHF="$W/_bmad-output/gate-adjudication/story-20260811T193044Z.authorization.md"
cat > "$AUTHF" <<'EOF'
operator_authorization: 2026-08-11T19:55:54Z | "go ahead and re-stamp it yourself"
EOF

# The operator spoke on Monday, in a session this gate call cannot name. The corpus is where
# the words are; `transcript_path` names Friday's file.
mkdir -p "$W/sessions-jsonl" "$W/sessions-plain"
cat > "$W/sessions-jsonl/monday.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-08-11T19:55:54Z","message":{"content":"Go ahead and re-stamp it yourself, I have looked at it."}}
EOF
: > "$W/sessions-jsonl/friday.jsonl"
# The SAME operator turn, in a readable file the corpus reader would never open: it selects
# `*.jsonl` and only those (`validate-steering-budget.sh:427`). Its directory holds no
# transcript at all, so it is the shape where a corpus EXISTS and is EMPTY.
cp "$W/sessions-jsonl/monday.jsonl" "$W/sessions-plain/current.log"

# 7. THE CORPUS BRANCH WORKS. A genuine, verified citation lifts. This is the positive
#    control for arms 8 and 9: without it, a verifier that failed for any reason at all
#    would make both of them pass by denying.
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/sessions-jsonl/friday.jsonl")"
if denied "$OUT"; then bad "LIFT/CORPUS: a VERIFIED operator citation in a sibling session did NOT lift — the gate is wedged on a real authorization"
else ok "LIFT/CORPUS: a verified operator citation in a sibling session lifts the deny"; fi

# 8. THE TEETH. Same corpus, a quote no operator typed. Fail-open on an empty corpus must
#    never widen into fail-open on a corpus.
cat > "$AUTHF" <<'EOF'
operator_authorization: 2026-08-11T19:55:54Z | "zzz no operator ever typed this phrase zzz"
EOF
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/sessions-jsonl/friday.jsonl")"
if denied "$OUT"; then ok "LIFT/CORPUS: a fabricated quote over the same corpus does NOT lift"
else bad "LIFT/CORPUS: the lead can lift its own deny by inventing an operator quote — S290 rebuilt"; fi
cat > "$AUTHF" <<'EOF'
operator_authorization: 2026-08-11T19:55:54Z | "go ahead and re-stamp it yourself"
EOF

# 9. THE DEFECT AT THIS SITE. `transcript_path` is readable and carries the operator's words,
#    but its DIRECTORY holds no `*.jsonl`, so the corpus the `--dir` branch would scan is
#    empty. `-d` on the dirname was true anyway, that branch won, and the readable-file
#    fallback under it was unreachable — a verified authorization failed to lift for want of
#    a corpus rather than for want of a citation. Measured: this is the ONLY input at this
#    site whose verdict the narrowing changes. Every `*.jsonl` transcript_path puts at least
#    itself in the dirname, so the two predicates agree; a transcript_path that is not
#    readable at all denies under both.
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/sessions-plain/current.log")"
if denied "$OUT"; then bad "LIFT/EMPTY-CORPUS: a readable transcript in a directory with no *.jsonl did NOT lift — the empty corpus outranked the file that holds the words"
else ok "LIFT/EMPTY-CORPUS: an empty corpus falls through to the readable transcript, which verifies"; fi

# --- the mutant --------------------------------------------------------------------------
# Arms 7 and 9 are ABSENCE-shaped: "not denied". A hook replaced by `exit 0` emits nothing,
# is not denied, and passes both. Only a mutant establishes that they discriminate at all.
# Built as a COPY and guarded by `cmp -s`, and the control copy is driven first — a lone copy
# that died on startup would also emit nothing.
MWORK="$(mktemp -d)"
cp "$HOOK" "$MWORK/control.sh"
cp "$HOOK" "$MWORK/m-existence-only.sh"
sed -i.bak 's@\[ -n "$TRANSCRIPT" \] && steer_dir_has_transcript "$(dirname "$TRANSCRIPT")"@[ -n "$TRANSCRIPT" ] \&\& [ -d "$(dirname "$TRANSCRIPT")" ]@' "$MWORK/m-existence-only.sh"
rm -f "$MWORK/m-existence-only.sh.bak"
if cmp -s "$HOOK" "$MWORK/m-existence-only.sh"; then
  bad "MUTANT: the existence-only sed changed no bytes — it matched nothing and would score as a kill"
elif ! bash -n "$MWORK/m-existence-only.sh"; then
  bad "MUTANT: the existence-only copy does not parse; its silence would score as a kill"
else
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/sessions-plain/current.log" "$MWORK/control.sh")"
  if denied "$OUT"; then bad "CONTROL: an unmutated copy of the hook DENIES arm 9 — every verdict below is about the copy, not the mutation"
  else ok "CONTROL: an unmutated copy of the hook reproduces arm 9's lift"; fi

  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/sessions-plain/current.log" "$MWORK/m-existence-only.sh")"
  if denied "$OUT"; then ok "MUTANT: the pre-fix existence-only predicate DENIES arm 9 — the arm can fire"
  else bad "MUTANT: the pre-fix predicate still lifted arm 9 — the arm asserts nothing"; fi

  # ...and nothing else moves. A mutant failing more than its own assertion means the arms
  # are entangled and one of them is vacuous.
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/sessions-jsonl/friday.jsonl" "$MWORK/m-existence-only.sh")"
  if denied "$OUT"; then bad "MUTANT: arm 7 also went red — the corpus arm and the fallthrough arm are entangled"
  else ok "MUTANT: arm 7 (the corpus branch) is UNCHANGED — the mutant kills only its own arm"; fi
fi
rm -rf "$MWORK"
rm -rf "$W"

# =============================================================================
# THE DECOYS — a guard that fires when no gate is failing gets ripped out.
# =============================================================================
seed pass
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "DECOY: an all-PASS pass DENIED the edit — the guard fires with no failure to guard"
else ok "DECOY: a clean gate pass does not deny (the gate is not in remediation)"; fi
rm -rf "$W"

seed no-gate
[ -f "$W/_bmad-output/pipeline-snapshot.md" ] \
  || bad "FIXTURE BROKEN: no snapshot in the no-gate case, so it would exit at arm 1 regardless"
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "DECOY: a project that has never run a gate was DENIED"
else ok "DECOY: no gate-adjudication directory -> allow (the common path stays free)"; fi
rm -rf "$W"

# =============================================================================
# ORDERING — the nonce picks the live pass, never mtime.
# =============================================================================
# `divergence-hard-block/run.sh:211-229` records this defect in the sibling hook:
# touching an old pass — a re-read, an editor, a `git checkout` — made a settled
# pass the live one. Here the FAILing pass is the older nonce and the clean pass
# is the newer, so an mtime pick re-raises a block on a gate that has cleared.
seed stale-then-clean
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "ORDERING: a superseded FAILing pass still denies — the newest pass is not the one being read"
else ok "ORDERING: the newest NONCE is the live pass, and it is clean"; fi
touch "$W/_bmad-output/gate-adjudication/story-20260811T193044Z.verdict.json"
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "ORDERING: touching the old FAILing verdict re-raised the deny — mtime picked the pass"
else ok "ORDERING: touching the old FAILing verdict changes nothing (mtime is not consulted)"; fi
rm -rf "$W"

# =============================================================================
# FAILURE POSTURE — unreadable gate state fails OPEN, and says so.
# =============================================================================
# A hook that wedges every artifact edit on its own JSON-parse bug gets switched
# off, after which nothing is watching. But a silently disarmed guard reads
# exactly like one that passed, so the allow must leave a trace retro reads.
seed unparseable
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "POSTURE: an unparseable verdict DENIED the edit — the hook wedges on its own read failure"
else ok "POSTURE: an unparseable verdict fails OPEN"; fi
if grep -q 'GATE_STATE_UNADJUDICABLE' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "POSTURE: ...and says so in the flow log — a disarmed guard must never be silent"
else
  bad "POSTURE: the guard was disarmed SILENTLY. A check that cannot fire reads exactly like one that passed."
fi
rm -rf "$W"

echo
if [ "$fails" -eq 0 ]; then echo "gate-remediation-deny: PASS"; exit 0; fi
echo "gate-remediation-deny: $fails assertion(s) FAILED" >&2
exit 1
