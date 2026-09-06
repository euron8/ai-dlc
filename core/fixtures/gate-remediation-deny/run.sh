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
drive() { # <work> <tool> <file_path> [agent_id] [transcript] [hook-override] [gate-metrics] [cwd]
  local w="$1" tool="$2" fp="$3" agent="${4:-}" tr="${5:-}" h="${6:-$HOOK}" gm="${7:-}" dcwd="${8:-}"
  # AI_DLC_GATE_METRICS is ALWAYS assigned here, empty by default, so no arm can inherit an
  # operator's timeline: arm 7b's carve-out reads it, and a fixture that let it through would
  # count a developer's own gate history toward a seeded suppression's lifetime.
  #
  # THE CWD IS A PARAMETER because it is an INPUT to the verdict. Arm 7b calls the sibling with
  # the project root in the environment and no `--gate-metrics`, and the sibling then locates
  # the timeline for itself; a fixture that only ever ran from a cwd carrying no
  # `_bmad-output/` cannot see which of the two roots that search reached.
  jq -nc --arg t "$tool" --arg f "$fp" --arg a "$agent" --arg tr "$tr" \
    '{session_id:"t", tool_name:$t, transcript_path:$tr, tool_input:{file_path:$f}}
     + (if $a == "" then {} else {agent_id:$a} end)' \
    | ( if [ -n "$dcwd" ]; then cd "$dcwd" || exit 2; fi
        CLAUDE_PROJECT_DIR="$w" AI_DLC_GATE_METRICS="$gm" bash "$h" 2>/dev/null )
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
# ARM 7a — THE DISPATCH BINDING. A clean pass no dispatch produced may not clear.
# =============================================================================
# THE DEFECT. The pick above orders by nonce and nothing else, and the nonce is a field the
# lead writes into a filename it chooses. So a clean verdict written by hand at a round
# timestamp sorts above every real pass and the ORDERING arm's own allow is what lets it
# through. The reference consumer holds one:
# `gate-adjudication/planning-20260902T160000Z.verdict.json`, a 16:00:00Z nonce whose
# adjudicator was dispatched at 13:57:46Z and wrote the file at 14:12:35Z.
#
# THE PAIR THAT DISCRIMINATES is `stale-then-clean` (asserted above, NO ledger, must ALLOW)
# against `forged-clean` (same two verdicts, plus a ledger). If a change makes both deny, it
# has broken ordering rather than added a binding; if both allow, the arm is not firing.
seed forged-clean
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then ok "7a: a clean pass at a nonce no dispatch follows does NOT clear a live FAIL"
else bad "7a: the forged clean pass cleared the deny — a nonce the lead chooses is still the whole freshness anchor"; fi
case "$OUT" in
  *"NOT THIS PASS"*) ok "7a: ...and the deny NAMES the unbound file rather than denying anonymously" ;;
  *) bad "7a: the deny fired but never says which file was refused or why" ;;
esac
if grep -q 'GATE_VERDICT_UNBOUND' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "7a: ...and the substitution is in the flow log, where retro's Rule 25(c) audit reads it"
else
  bad "7a: the guard silently re-adjudicated on another pass. A substitution nobody can see reads exactly like the pick working."
fi
# The FAILING pass must be the one named, not merely 'something failed'.
case "$OUT" in
  *"story-20260811T193044Z"*) ok "7a: ...and it adjudicates on the BOUND pass, naming its nonce" ;;
  *) bad "7a: the deny does not name the bound pass it fell back to" ;;
esac
rm -rf "$W"

# WRONG FIX #1 — the join everyone reaches for first. `adjudicator_agent_id` here is the
# EXACT `name` of the ledger's one gate-adjudicator dispatch, so a binding keyed on that
# field alone reports BOUND and the forgery clears. Measured on the reference consumer: the
# name join accepts 92 of 193 conforming verdicts AND accepts the round-nonce file.
seed forged-clean-named
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then ok "7a: naming a REAL dispatched agent in adjudicator_agent_id does not bind the pass"
else bad "7a: a name join was enough — the binding is keyed on a field whoever writes the file writes"; fi
rm -rf "$W"

# WRONG FIX #2 — a row that exists but is not evidence. Same write-ledger row as the honest
# case with the harness's `agent_id` emptied, which is what a LEAD write leaves behind if the
# recorder records every writer instead of only dispatched ones.
seed forged-clean-leadwrite
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then ok "7a: a write row with an EMPTY agent_id does not bind — the lead's own write is not a dispatch"
else bad "7a: a write row bound the pass without the harness attributing it to any agent"; fi
rm -rf "$W"

# THE ACQUITTING DIRECTION, and this is the one that keeps the arm from being a blanket deny.
# Same forged tree, plus a write row for that exact stem, carrying an agent_id, clocked AFTER
# the nonce. That is what an honest late pass looks like and it must go through.
seed forged-clean-bound
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "7a: a pass bound by a dispatched agent's own write was still refused — the arm denies every honest pass too"
else ok "7a: a clean pass BOUND by a dispatched agent's write clears the deny (the arm is not a blanket refusal)"; fi
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

# =============================================================================
# ARM 7b — THE SUPPRESSED CARVE-OUT. Every case is a TWIN: one property apart
# from the case beside it, and the two verdicts must differ.
# =============================================================================
# EVERY DRIVE BELOW CARRIES A TRANSCRIPT, because arm 7b verifies each covering entry's
# operator citation and fails CLOSED without a corpus. A 7b arm driven with no transcript
# denies for want of a verifier rather than for want of coverage -- the same verdict as a
# working guard, reached without the guard ever reading a suppression.
TRC="sessions-jsonl/current.jsonl"
# A DENY arm alone cannot tell a guard that reads the suppression from one that ignores it,
# and an ALLOW arm alone cannot tell one that reads it from one that lifts on anything. So
# S1 (covered -> allow) is scored against S2..S7 (one property changed -> deny) and never on
# its own, and the reason text is asserted on the deny side so a deny for the WRONG reason is
# visible.

# --- S1. Every live FAIL is covered by an in-force SUPPRESSED entry -> ALLOW.
seed suppressed
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then bad "S1: a FAIL under an in-force SUPPRESSED entry still DENIED the lead — the gate passes and the lead stays locked out, which is the whole defect"
else ok "S1: every live FAIL under an in-force suppression -> the edit is ALLOWED"; fi
if grep -q 'GATE_REMEDIATION_SUPPRESSED' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "S1: ...and the allow is LOUD (GATE_REMEDIATION_SUPPRESSED in the flow log)"
else
  bad "S1: the carve-out allowed SILENTLY — retro cannot tell this edit from one no gate was watching"
fi

# --- THE CACHE. It is read, and its key invalidates. Both halves, or a cache that is never
# consulted and a cache that never expires look identical from outside.
#
# THIS BLOCK RUNS BEFORE THE ALTERNATE-TIMELINE TWIN, and that ordering is load-bearing rather
# than tidy. The metrics file is a key term, so a call carrying AI_DLC_GATE_METRICS rewrites
# the cache under a DIFFERENT key; poisoning what that call left behind and then reading it
# back with the default timeline is a guaranteed miss, and the poison is never consulted --
# which reads exactly like a cache nothing reads. Measured: that ordering failed this arm
# against a working cache.
CACHEF="$W/_bmad-output/.gate-remediation-in-force"
if [ -f "$CACHEF" ]; then ok "S1-cache: the carve-out wrote its keyed cache"
else bad "S1-cache: no cache file — every Edit pays the sibling's parse of the escalations corpus"; fi
if [ -f "$CACHEF" ]; then
  # Same key, rows rewritten to a catalog this verdict is not in. If the cache is consulted,
  # the edit is denied; if it is ignored, the sibling re-answers and the edit is allowed.
  CK="$(head -1 "$CACHEF")"
  # SIX fields, because the reader requires six. A short poison row is dropped by the field
  # count and the arm below would then score a DENY that the poison never caused.
  printf '%s\nnot-this-catalog\t7\t3\t0\t2026-08-01T00:00:00Z | "Operator-suppress this FAIL (Recommended)"\tseeded cache poison\n' "$CK" > "$CACHEF"
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
  if denied "$OUT"; then ok "S1-cache: the cached rows are what the join reads (a poisoned cache changes the verdict)"
  else bad "S1-cache: the cache file is written and never read — it costs a write and saves nothing"; fi
  # ...and the key invalidates. Rewriting the escalations file changes its size and mtime.
  # THE EQUAL-SIZE, SAME-SECOND REWRITE — the one a size+mtime key cannot see. `[core] 7`
  # becomes `[core] 9`: identical byte count, and inside one whole second `mtime` has not moved
  # either, so the ONLY thing that has changed is the content. Measured against a size+mtime
  # key: 190 bytes vs 190 bytes, stale ALLOW. Run BEFORE the size-changing probe below, while
  # the cache is still warm from the call above.
  B4="$(wc -c < "$W/docs/escalations/pending.md")"
  sed -i.bak 's/\*\*Suppresses:\*\* \[core\] 7/**Suppresses:** [core] 9/' "$W/docs/escalations/pending.md"
  rm -f "$W/docs/escalations/pending.md.bak"
  AF="$(wc -c < "$W/docs/escalations/pending.md")"
  if [ "$B4" != "$AF" ]; then
    bad "S1-cache: FIXTURE BROKEN — the 7->9 rewrite changed the file SIZE ($B4 -> $AF), so a size key would catch it and this arm cannot see a content key"
  else
    OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
    if denied "$OUT"; then ok "S1-cache: an EQUAL-SIZE, same-second rewrite (7 -> 9) invalidates the key — the cache is keyed on CONTENT"
    else bad "S1-cache: a suppression rewritten to name a different check at the same size in the same second still lifted — the key cannot see an in-place edit, which is the only edit the denied lead can make"; fi
  fi
  sed -i.bak 's/\*\*Suppresses:\*\* \[core\] 9/**Suppresses:** [core] 7/' "$W/docs/escalations/pending.md"
  rm -f "$W/docs/escalations/pending.md.bak"
  printf '\n<!-- key-invalidation touch -->\n' >> "$W/docs/escalations/pending.md"
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
  if denied "$OUT"; then bad "S1-cache: a changed escalations file did NOT invalidate the key — a stale suppression set decides the lock-out forever"
  else ok "S1-cache: a changed escalations file invalidates the key and the sibling re-answers"; fi
fi

# S1's TWIN, same workspace, one property apart: the alternate timeline records enough gates
# to put the same entry past its **Expires after:**. This is also the only arm that proves
# AI_DLC_GATE_METRICS is read at all.
OUT="$(drive "$W" Edit "$W/$ART" "" "" "" "$W/alt-gate-metrics.jsonl")"
if denied "$OUT"; then ok "S1-twin: the SAME entry against a timeline past its expiry DENIES (the lifetime is counted, and AI_DLC_GATE_METRICS is read)"
else bad "S1-twin: an EXPIRED suppression still lifted — the licence has no lifetime here, and the metrics channel may not be read at all"; fi
rm -rf "$W"

# --- S10. THE SELF-DISCHARGE. Arm 6 lets the lead write pending.md while denied, so a
# SUPPRESSED entry is a record the lead CAN author. Its quote is the whole claim.
seed suppressed-forged
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S10: a well-formed, in-force suppression whose quote NO operator said does NOT lift the deny"
else bad "S10: the lead cleared its own lock-out by writing its own suppression — the hook's 'no lead-authored record reaches this' is false"; fi
case "$OUT" in *"unverified-citation"*) ok "S10: ...and the deny says the citation is the thing that failed, not the coverage" ;;
  *) bad "S10: the deny gives no account of the forged citation, so the lead reads it as an uncovered FAIL" ;; esac
# THE TWIN, one property apart: the SAME entry with the quote the corpus really carries. Without
# it, a guard that verified nothing and a guard that rejected everything both pass S10.
sed -i.bak 's/the operator never said this sentence/Operator-suppress this FAIL (Recommended)/' "$W/docs/escalations/pending.md"
rm -f "$W/docs/escalations/pending.md.bak"
if grep -q 'the operator never said' "$W/docs/escalations/pending.md"; then
  bad "S10-twin: FIXTURE BROKEN — the quote substitution did not apply, so the twin re-ran S10"
else
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
  if denied "$OUT"; then bad "S10-twin: a GENUINE operator quote in the seeded corpus did not lift — arm 7b rejects everything and S10 proves nothing"
  else ok "S10-twin: the identical entry quoting a real operator turn DOES lift (the arm verifies rather than refuses)"; fi
fi
rm -rf "$W"

# --- S11. THE ID GRAIN. `3` and `3a` are different checks in the same catalog.
seed suppressed-superset
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S11: a suppression naming 3a does not cover a live FAIL on 3"
else bad "S11: a substring join acquitted check 3 under a suppression for 3a"; fi
rm -rf "$W"
seed suppressed-subset
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S11-mirror: a suppression naming 3 does not cover a live FAIL on 3a"
else bad "S11-mirror: a substring join acquitted check 3a under a suppression for 3"; fi
rm -rf "$W"

# --- S2. The same entry, EXPIRED by the recorded timeline -> DENY.
seed suppressed-expired
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S2: an EXPIRED suppression does not carve out (the deny stands)"
else bad "S2: an expired suppression lifted the deny — an operator's licence with no end"; fi
case "$OUT" in *'check(s) `7`'*) ok "S2: ...and the deny still names check 7 as owed a repair" ;;
  *) bad "S2: the deny does not name the still-failing check" ;; esac
rm -rf "$W"

# --- S3. The entry names a DIFFERENT catalog -> DENY. The join is (catalog, check_id).
seed suppressed-wrongcat
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S3: an in-force entry in ANOTHER catalog does not cover this verdict's check"
else bad "S3: the join dropped the catalog — check 7 of any extension now suppresses core's check 7"; fi
rm -rf "$W"

# --- S4. A BARE id counts as core and nothing else -> DENY against an extension verdict.
seed suppressed-bare
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S4: a bare (bracketless) **Suppresses:** id covers core only, not an extension catalog"
else bad "S4: a bare id was treated as a wildcard — an author error buys wider coverage than writing it correctly"; fi
rm -rf "$W"

# --- S4b. A verdict carrying NO catalog field joins against nothing -> DENY.
seed suppressed-nocat
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S4b: a verdict with no catalog field gets no carve-out (fail-closed, as the gate validator's own join is)"
else bad "S4b: a verdict with no catalog defaulted into core and collected a suppression it never named"; fi
rm -rf "$W"

# --- S5. Two FAILs, one covered -> DENY, naming both halves.
seed suppressed-partial
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S5: one covered FAIL beside an uncovered one still DENIES"
else bad "S5: any suppression at all lifted the deny — a real failing check is now unguarded"; fi
if denied "$OUT"; then
  case "$OUT" in *'check(s) `3a`'*) ok "S5: the deny names ONLY the remaining FAIL (3a), so the dispatch brief is right" ;;
    *) bad "S5: the deny does not name 3a alone — the remediator is briefed on a check nobody is repairing" ;; esac
  case "$OUT" in *"under an in-force suppression"*) ok "S5: ...and says the other FAIL is suppressed, so the lead does not go looking for it" ;;
    *) bad "S5: the deny never mentions the suppressed FAIL — the lead sees 2 FAILs in the verdict and 1 in the deny with no account of the difference" ;; esac
fi
rm -rf "$W"

# --- S6/S7. FAIL CLOSED on every absence, and the status is IN the deny.
seed suppressed-nosibling
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S6: no sibling -> no carve-out, and the deny stands"
else bad "S6: an absent sibling was read as 'everything is covered' — the guard fails OPEN on its own missing dependency"; fi
case "$OUT" in *"no-sibling"*) ok "S6: ...and the deny carries the status, so the lead can tell this from a real FAIL set" ;;
  *) bad "S6: the deny does not say WHY no carve-out was applied" ;; esac
rm -rf "$W"

seed suppressed-noesc
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S7: no escalations file -> no carve-out, and the deny stands"
else bad "S7: a missing escalations file lifted the deny"; fi
case "$OUT" in *"no-escalations-file"*) ok "S7: ...and the deny carries that status" ;;
  *) bad "S7: the deny does not distinguish a missing escalations file from a clean one" ;; esac
rm -rf "$W"

# --- S9. The sibling is PRESENT and does not dispatch the mode. A consumer runs its own
# installed engine, so this hook can arrive one pull ahead of the sibling it asks.
seed suppressed-oldsibling
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S9: a sibling that refuses --in-force -> no carve-out, and the deny stands"
else bad "S9: a sibling REFUSAL was read as coverage — the pull that delivers this hook ahead of the mode would unlock the corpus"; fi
case "$OUT" in *"refused:"*) ok "S9: ...and the deny carries 'refused', which is a different repair from a missing file" ;;
  *) bad "S9: a refusal is indistinguishable from a clean read in the deny" ;; esac
rm -rf "$W"

# --- S8. The repair-record arm reads the SUBTRACTED set, not the raw one.
# A record claiming only the SUPPRESSED check has repaired nothing that is still owed. Its
# twin — the same record claiming the REMAINING check — must lift, or this arm is just the
# lift being broken.
seed suppressed-partial
# ONE transcript carrying BOTH claims, and it has to be inside the corpus. Arm 8 greps the
# named FILE for the dispatched agent_id; arm 7b verifies the operator quote over the file's
# DIRECTORY. A transcript outside `sessions-jsonl/` makes arm 7b fail closed, the subtraction
# never happens, and the record then lifts the raw FAIL set — which is the defect this arm
# exists to catch, reached without arm 7b ever running. Measured: that spelling failed S8.
TR8="$W/$TRC"
printf '{"agent_id":"remediator@session-abc123"}\n' > "$TR8"
REC8="$W/_bmad-output/gate-adjudication/story-20260811T193044Z.repair.md"
printf 'gate_nonce: story-20260811T193044Z\nremediator_agent_id: remediator@session-abc123\nrepaired_checks: 7\n' > "$REC8"
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR8")"
if denied "$OUT"; then ok "S8: a repair record claiming only the SUPPRESSED check does not lift"
else bad "S8: the lift read the raw FAIL set — repairing a check nobody was waiting on now clears the block on the one they were"; fi
printf 'gate_nonce: story-20260811T193044Z\nremediator_agent_id: remediator@session-abc123\nrepaired_checks: 3a\n' > "$REC8"
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR8")"
if denied "$OUT"; then bad "S8-twin: a record claiming the REMAINING check did not lift — the subtraction broke the lift arm outright"
else ok "S8-twin: the same record claiming the remaining check (3a) DOES lift"; fi
rm -rf "$W"

# =============================================================================
# S12 — CWD-INVARIANCE. The world the consumer's pre-push runs in.
# =============================================================================
# THE DEFECT. Arm 7b hands the sibling `AI_DLC_PROJECT_ROOT` and, when AI_DLC_GATE_METRICS is
# unset, no `--gate-metrics`. The sibling then locates the timeline itself — and it did so
# from the PROCESS CWD before the root. Every arm above ran from whatever directory the suite
# was driven in, which in this repo carries no `_bmad-output/`, so the search fell through to
# the root by accident and the whole 7b family read green. On the reference consumer, whose
# pre-push runs the suite from a root that DOES carry one, the same arms have been failing.
#
# So the invariance is asserted HERE, in the fixture's own arms, rather than left to the
# caller's choice of directory: `CLAUDE.md` — a unit that is green only from the repo root
# may be green because that is a cwd where its decoy files do not exist.
GRD_DECOY="$(mktemp -d "${TMPDIR:-/tmp}/gate-remediation-decoy.XXXXXX")" || GRD_DECOY=""
GRD_DECOY_GM="$GRD_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
if [ -n "$GRD_DECOY" ]; then
  mkdir -p "$(dirname "$GRD_DECOY_GM")"
  : > "$GRD_DECOY_GM"
  _i=1
  while [ "$_i" -le 9 ]; do
    printf '{"ts":"2026-08-%02dT00:00:00Z","check":"7","verdict":"FAIL"}\n' "$((4 + _i))" >> "$GRD_DECOY_GM"
    _i=$((_i + 1))
  done
fi

seed suppressed
# THE PRECONDITION. Both timelines must exist and DIFFER, or the pair below agrees for a
# reason that has nothing to do with where the sibling looked.
if [ -s "$GRD_DECOY_GM" ] && [ -s "$W/_bmad-output/implementation-artifacts/gate-metrics.jsonl" ] \
   && ! cmp -s "$GRD_DECOY_GM" "$W/_bmad-output/implementation-artifacts/gate-metrics.jsonl"; then
  ok "S12-pre: the decoy cwd carries its own gate timeline, and it DIFFERS from the workspace's"
else
  bad "S12-pre: FIXTURE BROKEN — no decoy timeline, or it is identical to the workspace's; S12 below cannot discriminate"
fi
# ...and it must be a timeline that WOULD change the answer: 9 gates against **Expires after:** 3.
_dn="$(grep -c . "$GRD_DECOY_GM")" || _dn=0
_wn="$(grep -c . "$W/_bmad-output/implementation-artifacts/gate-metrics.jsonl")" || _wn=0
if [ "$_dn" -gt 3 ] && [ "$_wn" -le 3 ]; then
  ok "S12-pre: the decoy records $_dn gates against the entry's 3-gate lifetime, the workspace $_wn — reading the wrong one flips the verdict"
else
  bad "S12-pre: decoy=$_dn workspace=$_wn — the two timelines do not straddle the 3-gate expiry, so S12 would pass under either resolution"
fi

# S12a: S1's ALLOW, driven from a cwd that is a DIFFERENT project with its own gate history.
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "" "" "$GRD_DECOY")"
if denied "$OUT"; then bad "S12a: from a cwd carrying another project's gate timeline the in-force suppression did NOT lift — the licence's lifetime was counted against a stranger's gates, and this is the state the reference consumer's pre-push has been in"
else ok "S12a: the carve-out lifts from a foreign cwd exactly as it does from the workspace — the timeline is resolved from the project root"; fi

# S12b: THE TWIN, one property apart, from the SAME foreign cwd. Without it, a guard that
# lifted unconditionally would pass S12a, and cwd-invariance would read as coverage.
rm -rf "$W"
seed suppressed-expired
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "" "" "$GRD_DECOY")"
if denied "$OUT"; then ok "S12b: from the same foreign cwd an EXPIRED suppression still DENIES — S12a is coverage, not a blanket lift"
else bad "S12b: an expired suppression lifted from the foreign cwd — the 7b family is allowing on cwd rather than on the entry"; fi
rm -rf "$W"

# =============================================================================
# S13 — THE OTHER TWO LAYOUTS THE SIBLING RESOLVES, AND THE FIX THAT BREAKS THEM.
# =============================================================================
# The sibling offers THREE root-anchored candidates, not one:
# `<root>/_bmad-output/implementation-artifacts/`, `<root>/docs/_bmad-output/
# implementation-artifacts/`, and the flat `<root>/_bmad-output/gate-metrics.jsonl`. A
# consumer on either fallback is a consumer this guard must still carve out for.
#
# THE WRONG FIX THIS EXISTS TO KILL. The obvious repair for the cwd defect is to make the
# GUARD name the file — `--gate-metrics "${LOG_DIR}/implementation-artifacts/
# gate-metrics.jsonl"` on every call. That names ONE of the three, and a named file that does
# not exist is a lifetime that cannot be counted, so both fallback layouts flip from ALLOW to
# DENY. It is invisible in the standard layout, which is the only layout every other arm in
# this file uses, so it needs its own worlds. The gate WRITER emits that literal relative
# path irrespective of AI_DLC_STATE_DIR, so the guard's own LOG_DIR is not even the right
# guess to make.
#
# W2 — "the guard names the file and the sibling is left resolving from the cwd" — is not
# killable here: in every world of this fixture the guard is the only caller, and a guard that
# names the file is right whatever the sibling would have done alone. It is killed where the
# sibling's OTHER two callers live: `suppression-lifetime`'s world A drives it directly with
# no flag, and `gate-adjudication`'s S17 drives it through validate-gate-adjudication.sh,
# which passes no `--gate-metrics` either.
GRD_STD="_bmad-output/implementation-artifacts/gate-metrics.jsonl"
grd_relocate() { # <workspace> <destination relative to the workspace> — move the timeline there
  mkdir -p "$(dirname "$1/$2")" 2>/dev/null
  mv "$1/$GRD_STD" "$1/$2" 2>/dev/null
  [ -s "$1/$2" ] && [ ! -f "$1/$GRD_STD" ]
}

MW13="$(mktemp -d "${TMPDIR:-/tmp}/gate-remediation-m10.XXXXXX")"
# M10 — the wrong fix, built from the SUBJECT'S OWN predicate: every invocation of the sibling
# that carries no `--gate-metrics` gets the guard's one guess appended. A mutation keyed on a
# hand-named line goes vacuous the release somebody rewrites the call.
m10_open_sites() { awk '/--escalations "\$ESC_FILE"/ && !/--gate-metrics/ {n++} END {print n+0}' "$1"; }
M10_PRE="$(m10_open_sites "$HOOK")"
M10_OK=0
if [ "$M10_PRE" -lt 1 ]; then
  bad "M10: the guard has no sibling invocation that leaves --gate-metrics off, so the wrong fix cannot be built — either it has already been applied (and S13 below is the arm that says so) or the call was rewritten and this mutation lost its subject"
else
  awk '
    /--escalations "\$ESC_FILE"/ && !/--gate-metrics/ {
      sub(/--escalations "\$ESC_FILE"/, "--escalations \"$ESC_FILE\" --gate-metrics \"${LOG_DIR}/implementation-artifacts/gate-metrics.jsonl\"")
    }
    { print }
  ' "$HOOK" > "$MW13/m10.sh"
  M10_POST="$(m10_open_sites "$MW13/m10.sh")"
  if cmp -s "$HOOK" "$MW13/m10.sh"; then
    bad "M10: the mutation changed NO bytes — its silence would score as a kill"
  elif [ "$M10_POST" != "0" ]; then
    bad "M10: $M10_POST invocation(s) still leave --gate-metrics off after the mutation (was $M10_PRE) — the mutation is partial and any kill it scores is unearned"
  elif ! bash -n "$MW13/m10.sh" 2>/dev/null; then
    bad "M10: the copy does not parse; a hook that dies emits nothing, which reads as allowed"
  else
    ok "M10: the wrong fix builds — $M10_PRE open invocation(s) now name one explicit path, 0 left open"
    M10_OK=1
  fi
fi

# EVERY M10 DRIVE GETS A FRESH WORKSPACE, and that is not tidiness. Arm 7b's cache key carries
# the escalations file, the sibling and `${AI_DLC_GATE_METRICS:-${LOG_DIR}/…}` — and NOT the
# hook. So the mutant and the unmutated hook compute the SAME key in the same workspace, the
# mutant reads the rows the unmutated call left behind, and it scores ALLOW without ever asking
# the sibling. Measured: both kills below read SURVIVED that way, which is exactly what a
# mutation that changes nothing looks like.
grd_world() { # <case> <destination for the timeline, relative to the workspace>
  seed "$1"
  grd_relocate "$W" "$2"
}

# --- S13a. THE FLAT LAYOUT: <root>/_bmad-output/gate-metrics.jsonl -----------------------
GRD_FLAT="_bmad-output/gate-metrics.jsonl"
if grd_world suppressed "$GRD_FLAT"; then
  ok "S13a-pre: the timeline sits ONLY at the flat fallback, and the standard path is gone"
else
  bad "S13a-pre: FIXTURE BROKEN — the timeline did not move to the flat fallback; S13a would re-run S1"
fi
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then bad "S13a: a consumer keeping its timeline at the flat <root>/_bmad-output/gate-metrics.jsonl gets NO carve-out — its in-force suppressions do not exist as far as this guard is concerned"
else ok "S13a: the carve-out lifts with the timeline at the flat fallback"; fi
rm -rf "$W"
if [ "$M10_OK" = "1" ] && grd_world suppressed "$GRD_FLAT"; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW13/m10.sh")"
  if denied "$OUT"; then ok "M10 killed by S13a — a guard that names ONE path denies every consumer on the flat layout"
  else bad "M10 SURVIVED S13a — naming one explicit path costs the flat layout nothing here, so this world is not testing the wrong fix"; fi
  rm -rf "$W"
fi
# THE TWIN, one property apart: the same flat layout, the same entry, past its expiry.
if grd_world suppressed-expired "$GRD_FLAT"; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
  if denied "$OUT"; then ok "S13a-twin: an EXPIRED entry on the flat layout still DENIES — S13a's allow is the fallback timeline being COUNTED, not skipped"
  else bad "S13a-twin: an expired entry lifted on the flat layout — the fallback file is being found and not read"; fi
else
  bad "S13a-twin: FIXTURE BROKEN — the expiring timeline did not move to the flat fallback"
fi
rm -rf "$W"

# --- S13b. THE DOCS LAYOUT: <root>/docs/_bmad-output/implementation-artifacts/ ------------
GRD_DOCS="docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
if grd_world suppressed "$GRD_DOCS"; then
  ok "S13b-pre: the timeline sits ONLY under docs/_bmad-output/, and the standard path is gone"
else
  bad "S13b-pre: FIXTURE BROKEN — the timeline did not move to the docs fallback; S13b would re-run S1"
fi
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then bad "S13b: a consumer keeping its timeline under docs/_bmad-output/ gets NO carve-out"
else ok "S13b: the carve-out lifts with the timeline under the docs fallback"; fi
rm -rf "$W"
if [ "$M10_OK" = "1" ] && grd_world suppressed "$GRD_DOCS"; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW13/m10.sh")"
  if denied "$OUT"; then ok "M10 killed by S13b — the same one-path guess denies every consumer on the docs layout too"
  else bad "M10 SURVIVED S13b — this world does not separate 'the sibling resolves' from 'the guard guesses'"; fi
  rm -rf "$W"
fi
if grd_world suppressed-expired "$GRD_DOCS"; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
  if denied "$OUT"; then ok "S13b-twin: an EXPIRED entry on the docs layout still DENIES — the fallback timeline is read, not merely found"
  else bad "S13b-twin: an expired entry lifted on the docs layout — the fallback file is being found and not read"; fi
else
  bad "S13b-twin: FIXTURE BROKEN — the expiring timeline did not move to the docs fallback"
fi
rm -rf "$W"

# --- S13c. THE CONTROL: in the STANDARD layout the wrong fix is INVISIBLE ----------------
# Without this, M10's two kills above are indistinguishable from a mutant that simply broke
# the hook, and the reason the wrong fix is tempting would never be visible.
if [ "$M10_OK" = "1" ]; then
  seed suppressed
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW13/m10.sh")"
  if denied "$OUT"; then bad "M10: the mutant also DENIES the standard layout — either it broke the hook outright, so its kills at S13a/S13b are unearned, or the sibling is still resolving from the process cwd"
  else ok "M10: INVISIBLE in the standard layout — which is why the wrong fix passes every other arm in this file and needs S13a/S13b"; fi
  rm -rf "$W"
fi
rm -rf "$MW13"

# --- THE MUTANTS ------------------------------------------------------------------------
# Every arm above is ABSENCE-shaped in one direction ("not denied"), so a hook replaced by
# `exit 0` passes S1 outright. Only a mutant establishes that these arms discriminate.
#
# THE TWO WRONG FIXES, WRITTEN DOWN BEFORE THE ARMS WERE BUILT, because the absent fix is the
# easy one to kill:
#   (W1) the subtraction is COMPUTED and never USED — `SUPPRESSED_CHECKS` reaches the deny
#        reason for diagnostics and `FAILED_CHECKS` is never reassigned. Every channel keyed
#        on the reason TEXT goes green (the deny now mentions the suppression) and the lead is
#        locked out exactly as before. That is M1.
#   (W2) the allow is decided from the SUPPRESSED set instead of the REMAINDER —
#        `[ -n "$SUPPRESSED_CHECKS" ]` for `[ -z "$FAILED_CHECKS" ]`, i.e. "any suppression at
#        all lifts". It passes S1, S2, S3, S4 and S6 and is wrong only on S5, where a real
#        failing check goes unguarded. That is M5, and a receipt scored on S1 alone takes it.
#
# THE `refused:` RETURN-CODE CHECK MOVES NO VERDICT AND IS STILL LOAD-BEARING, so it is armed
# on what it DOES move. The sibling exits 2 before printing any row, so ignoring its return
# code reads the same empty stdout and denies either way; what changes is the STATUS the deny
# carries, and `refused` and `ok` name different repairs. M7 mutates it and S9's status arm is
# the observable — `fixture-mutants.md`'s "when a guard flips no verdict, arm it on the first
# thing it actually gates".
MW="$(mktemp -d)"
cp "$HOOK" "$MW/control.sh"
mut() { # <name> <sed-expr> -> 0 if a real, parseable mutant landed at $MW/<name>.sh
  cp "$HOOK" "$MW/$1.sh"
  sed -i.bak "$2" "$MW/$1.sh"; rm -f "$MW/$1.sh.bak"
  if cmp -s "$HOOK" "$MW/$1.sh"; then
    bad "MUTANT $1: the sed changed NO bytes — it matched nothing, and its silence would score as a kill"; return 1
  fi
  if ! bash -n "$MW/$1.sh" 2>/dev/null; then
    bad "MUTANT $1: the copy does not parse; a hook that dies emits nothing, which reads as allowed"; return 1
  fi
  return 0
}
kill_arm() { # <name> <expect deny|allow> <workspace> <label> [gate-metrics]
  local nm="$1" want="$2" w="$3" label="$4" gm="${5:-}"
  local o; o="$(drive "$w" Edit "$w/$ART" "" "$w/$TRC" "$MW/$nm.sh" "$gm")"
  if [ "$want" = deny ]; then
    if denied "$o"; then ok "$label"; else bad "$label"; fi
  else
    if denied "$o"; then bad "$label"; else ok "$label"; fi
  fi
}

# M1 / M5 / M4 are scored on the seeds they are wrong about; each also gets one seed it must
# NOT move, so a mutant that simply breaks the hook cannot score a kill.
seed suppressed
kill_arm control allow "$W" "CONTROL: an unmutated COPY of the hook reproduces S1's allow"
if mut m1-no-subtract '/^  FAILED_CHECKS="\$REMAINING"$/d'; then
  kill_arm m1-no-subtract deny "$W" "M1: computing the subtraction and never applying it DENIES S1 — the arm can fire"
fi
if mut m5-any-suppression-lifts 's@if \[ -z "\$FAILED_CHECKS" \]; then@if [ -n "$SUPPRESSED_CHECKS" ]; then@'; then
  kill_arm m5-any-suppression-lifts allow "$W" "M5: 'any suppression lifts' is INVISIBLE on S1 — which is why S5 exists"
fi
if mut m6-key-drops-escalations 's@|\$(ckey "\$ESC_FILE")@@'; then
  kill_arm m6-key-drops-escalations allow "$W" "M6: dropping the escalations term from the cache key does not move S1 itself"
fi
rm -rf "$W"

seed suppressed-partial
if [ -f "$MW/m5-any-suppression-lifts.sh" ]; then
  kill_arm m5-any-suppression-lifts allow "$W" "M5: 'any suppression lifts' ALLOWS S5 — the arm can fire on the fail-open wrong fix"
fi
if [ -f "$MW/m1-no-subtract.sh" ]; then
  kill_arm m1-no-subtract deny "$W" "M1: ...and S5 is UNCHANGED under M1 (the mutants kill only their own arms)"
fi
rm -rf "$W"

# M8 is the whole BLOCKER as a mutation: drop the citation verification and every covering row
# is taken on trust, which is the state this fixture's own subject shipped in.
seed suppressed-forged
if mut m8-no-cite-verification 's@if cite_verifies "\${_rauth:-}"; then@if true; then@'; then
  kill_arm m8-no-cite-verification allow "$W" "M8: dropping the citation check ALLOWS a lead-authored suppression — the verification is what keeps arm 7b out of the lead's reach"
fi
rm -rf "$W"

# M9: the id grain. `-qxF` -> `-qF` is one character and acquits a FAIL on 3 under 3a.
seed suppressed-superset
if mut m9-substring-join 's@if grep -qxF "\$_c" <<<"\$COVERED"; then@if grep -qF "$_c" <<<"$COVERED"; then@'; then
  kill_arm m9-substring-join allow "$W" "M9: a substring covered-set join ALLOWS S11 — the whole-token match is load-bearing"
fi
rm -rf "$W"
seed suppressed
if [ -f "$MW/m9-substring-join.sh" ]; then
  kill_arm m9-substring-join allow "$W" "M9: ...and S1 is UNCHANGED under it (the mutant kills only its own arm)"
fi
rm -rf "$W"

seed suppressed-wrongcat
if mut m2-no-catalog-join 's@if (c == want) print \$2@print $2@'; then
  kill_arm m2-no-catalog-join allow "$W" "M2: dropping the catalog from the join ALLOWS S3 — the catalog half of the key is load-bearing"
fi
rm -rf "$W"

seed suppressed-bare
if mut m3-bare-is-wildcard 's@if (c == want) print \$2@if (c == want || $1 == "") print $2@'; then
  kill_arm m3-bare-is-wildcard allow "$W" "M3: treating a bare bracket as a wildcard ALLOWS S4 — the bare-means-core rule is load-bearing"
fi
if [ -f "$MW/m2-no-catalog-join.sh" ]; then
  : # S4 stands down for M2: the catalog join OWNS that case, and M2 reaches S4 too.
fi
rm -rf "$W"

seed suppressed-nosibling
if mut m4-absence-is-coverage 's@elif \[ -z "\$SUPP_DIR" \]; then@elif [ -z "$SUPP_DIR" ]; then FAILED_CHECKS="";@'; then
  kill_arm m4-absence-is-coverage allow "$W" "M4: reading an ABSENT sibling as 'everything is covered' ALLOWS S6 — the fail-closed posture is load-bearing"
fi
rm -rf "$W"

# M7 flips no verdict, so it is scored on the status string S9 asserts, not on deny/allow.
seed suppressed-oldsibling
if mut m7-ignore-sibling-rc 's@if \[ "\$SUPP_RC" -eq 0 \]; then@if true; then@'; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/m7-ignore-sibling-rc.sh")"
  if denied "$OUT"; then ok "M7: ignoring the sibling's return code still DENIES (this check moves no verdict, as declared)"
  else bad "M7: ignoring the return code changed the VERDICT — then the declaration above is wrong and this needs a verdict arm"; fi
  case "$OUT" in *"refused:"*) bad "M7: the mutant still reported 'refused' — S9's status arm cannot see the return-code check at all" ;;
    *) ok "M7: ...and it reports the refusal as a clean read, which is exactly what S9's status arm catches" ;; esac
fi
rm -rf "$W"

# M6 needs the two-call shape S1's cache arm uses: answer once, change the escalations file,
# answer again. With the escalations term gone from the key the second answer is the stale one.
seed suppressed
if [ -f "$MW/m6-key-drops-escalations.sh" ]; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/m6-key-drops-escalations.sh")"
  : > "$W/docs/escalations/pending.md"
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/m6-key-drops-escalations.sh")"
  if denied "$OUT"; then bad "M6: emptying the escalations file still DENIED under the mutant — the cache-invalidation arm asserts nothing"
  else ok "M6: with the escalations term dropped from the key, an EMPTIED escalations file still lifts — the key term is load-bearing"; fi
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/control.sh")"
  if denied "$OUT"; then ok "M6: ...and the unmutated copy DENIES on the same emptied file (the two sides differ)"
  else bad "M6: the unmutated copy also lifted on an emptied escalations file — the differential's two sides do not differ, so M6's kill is unearned"; fi
fi
rm -rf "$W"

# --- arm 7a's mutants -------------------------------------------------------------------
# THE TWO WRONG FIXES FOR THIS ARM, written down before the arms were built:
#   (W3) bind to a dispatch and ignore ORDER — "some gate-adjudicator ran near this nonce" is
#        the obvious reading of "bind the verdict to a dispatch", and it is the one that fails
#        silently: the forged pass's own gate DID dispatch an adjudicator, just before the
#        invented nonce rather than after it. That is M11.
#   (W4) record every writer instead of only DISPATCHED ones. Dropping `agent_id` from the
#        recorder's predicate makes the ledger a list of writes, and a lead that writes its own
#        verdict then binds it with the row its own write left. That is M12.
# M13 is the arm present but unreachable, and M14 is the acquitting half — without it, every
# arm above is satisfied by a binding that never binds anything.
seed forged-clean
if mut m11-window-ignores-order 's@\. >= \$N and @@'; then
  kill_arm m11-window-ignores-order allow "$W" "M11: a dispatch window that ignores ORDER binds the forged pass — 'a dispatch near this nonce' is not 'a dispatch after it'"
fi
if mut m13-arm-unreachable '/^\[ -n "\$FAILED_CHECKS" \] || LIVE_CLEAN=1$/d'; then
  kill_arm m13-arm-unreachable allow "$W" "M13: with LIVE_CLEAN never set, arm 7a never runs and the forgery clears — the arm is reachable"
fi
if mut m14-write-never-binds 's@then "bound-write"@then "unbound"@'; then
  kill_arm m14-write-never-binds deny "$W" "M14: ...and a B1 that never binds leaves this world UNCHANGED (the mutant kills only its own arm)"
fi
rm -rf "$W"

seed forged-clean-leadwrite
if mut m12-records-every-writer 's@select((\.agent_id // "") != "")@select(true)@'; then
  kill_arm m12-records-every-writer allow "$W" "M12: a write ledger that does not require the harness's agent_id lets a LEAD write bind its own verdict"
fi
if [ -f "$MW/m11-window-ignores-order.sh" ]; then
  kill_arm m11-window-ignores-order allow "$W" "M11: ...and W3 acquits this world too — both wrong fixes fail open, in different places"
fi
rm -rf "$W"

# THE ACQUITTING DIRECTION UNDER MUTATION. `forged-clean-bound` must ALLOW, so an arm that
# only ever denies would pass every assertion above. M14 makes B1 unable to bind and this
# world must go red — that is what proves the allow is a measurement and not a default.
seed forged-clean-bound
kill_arm control allow "$W" "CONTROL: an unmutated COPY of the hook reproduces 7a's allow on a BOUND clean pass"
if [ -f "$MW/m14-write-never-binds.sh" ]; then
  kill_arm m14-write-never-binds deny "$W" "M14: a B1 arm that never returns bound-write DENIES a legitimately bound pass — the acquitting arm can fire"
fi
if [ -f "$MW/m12-records-every-writer.sh" ]; then
  kill_arm m12-records-every-writer allow "$W" "M12: ...and W4 leaves the honest world UNCHANGED, which is why it needs its own"
fi
rm -rf "$W"

# THE NO-CORPUS CONTROL. `stale-then-clean` is byte-for-byte this family's tree minus the
# ledger, and it must ALLOW under every mutant above. A change that reddens it has broken the
# nonce ordering rather than added a binding, and the two are indistinguishable from the
# forged world alone.
seed stale-then-clean
for _m7a in m11-window-ignores-order m12-records-every-writer m14-write-never-binds; do
  [ -f "$MW/$_m7a.sh" ] || continue
  kill_arm "$_m7a" allow "$W" "7a: ${_m7a} leaves the NO-LEDGER world allowing — the arm's subject is the ledger, not the second verdict"
done
rm -rf "$W"

rm -rf "$MW"
[ -n "$GRD_DECOY" ] && rm -rf "$GRD_DECOY"

echo
if [ "$fails" -eq 0 ]; then echo "gate-remediation-deny: PASS"; exit 0; fi
echo "gate-remediation-deny: $fails assertion(s) FAILED" >&2
exit 1
