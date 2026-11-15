#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
#
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
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-gate-remediation-guard.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\\n' "$1"; fails=$((fails+1)); }


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
  SEED_CASE="$1"
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

# ARM (b2) — THE CLOSING WRITER. After gate 3 the lead dispatches one `code-reviewer` to make
# the story's three closing writes (`code-reviewer.md` "As the Closing Writer"), and one of them
# is the story file's `Status:` header, which sits under a guarded root. The newest pass is read
# across ALL stories, so another story's FAIL is live while this one closes. The writer is a
# dispatched agent and must be allowed; the SAME edit from the lead, in the same run, is the
# control that says the pass really is failing for this path — without it an allow here would
# also read green on a workspace where nothing is failing.
STORY="_bmad-output/planning-artifacts/s302/stories/story-302-6-closing.md"
OUT_LEAD="$(drive "$W" Edit "$W/$STORY")"
# An OPAQUE agent_id, as the harness mints them: no role prefix, so an allow keyed on a role name
# (`remediator@*`, `code-reviewer@*`) is killed HERE and not only by arm (b)'s seeded spelling.
OUT_WRITER="$(drive "$W" Edit "$W/$STORY" "a1b2c3")"
if ! denied "$OUT_LEAD"; then
  bad "(b2) CONTROL: the lead's own Edit to a story file was ALLOWED during the FAILing pass, so the writer's allow below proves nothing"
elif denied "$OUT_WRITER"; then
  bad "(b2) the post-gate-3 closing writer (a dispatched code-reviewer) was DENIED its story-file Status edit while the newest pass is FAIL"
else
  ok "(b2) the closing writer's story-file Edit (opaque agent_id a1b2c3) is ALLOWED while the newest pass is FAIL; the lead's identical Edit is DENIED in the same run"
fi

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
if denied "$OUT"; then bad "(c) source code DENIED with NO transcript — arm 3b's (iv) cannot hold without one, and no gate arm guards source"
else ok "(c) source outside the guarded roots, driven with no transcript (so not a pipeline session for arm 3b), is untouched"; fi

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
cmp -s <(printf 'gate_nonce: story-20260811T193044Z\n') "$REC" && bad "FIXTURE BROKEN: the nonce substitution did not apply"
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
#    Fail CLOSED: the transcript is readable and the id is not in it. The id carries a digit and is
#    long enough, so the rid shape floor passes it and corroboration is what refuses (the floor's own
#    deny is RR-D6); the reason is read from the log, so a floor refusal cannot pass for this arm.
cat > "$REC" <<'EOF'
gate_nonce: story-20260811T193044Z
remediator_agent_id: remediator@session-never-dispatched-9
repaired_checks: 7
EOF
OUT="$(drive "$W" Edit "$W/$ART" "" "$TR")"
if denied "$OUT" && grep -qF "remediator_agent_id 'remediator@session-never-dispatched-9' appears in NO dispatch" "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "LIFT: an agent_id that appears in NO dispatch in the transcript does not lift (refused by corroboration, not the floor)"
else bad "LIFT: the lead can lift its own deny by inventing an agent_id, or the deny came from a guard other than corroboration"; fi

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

# NOTHING BOUND. The failing pass is unbound too, so there is no bound pass to fall back to.
# The first cut fell through to ALLOW here and wrote no flow-log event: a forged clean pass
# acquitted a live FAIL, invisibly. An unbound verdict may CONVICT, so the fallback is the
# newest FAILING pass whatever its binding, and the substitution is logged.
seed forged-clean-nobound
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then ok "7a: with NO pass in the directory bound, the forged clean pass still does not clear the unbound FAILING one"
else bad "7a: with nothing bound the guard fell through to ALLOW — a forged clean pass acquitted a live FAIL because the arm found no bound pass to fall back to"; fi
if grep -q 'itself unbound' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "7a: ...and the flow log says the fallback pass is itself unbound"
else
  bad "7a: the no-bound fallback is not in the flow log, or does not say the substitute is unbound"
fi
rm -rf "$W"

# The ALLOW twin: the same ledger, the older pass CLEAN. Nothing records a FAIL, so there is
# nothing to convict on and the arm must not manufacture a deny out of an unbound pair.
seed forged-clean-nobound-allclean
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "7a: two unbound CLEAN passes denied — the no-bound fallback convicts on a pass that records no FAIL"
else ok "7a: two unbound passes that both record no FAIL still ALLOW (the fallback needs a FAIL to convict on)"; fi
rm -rf "$W"

# THE WINDOW'S UPPER BOUND, asserted from both sides one property apart. A gate-adjudicator
# dispatched 901s after the forged nonce does not bind it; 899s after does. Measured before
# this pair existed: the window widened to 10^9 passed every arm and the receipt.
seed forged-clean-latewindow
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then ok "7a: a gate-adjudicator dispatched 901s AFTER the forged nonce does not bind it — the window has an upper bound"
else bad "7a: a dispatch outside the ${DISPATCH_WINDOW_S:-900}s window bound the forged pass — the window is unbounded above"; fi
rm -rf "$W"
seed forged-clean-inwindow
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "7a: a gate-adjudicator dispatched 899s AFTER the nonce did not bind it — the window is narrower than 900s"
else ok "7a: a gate-adjudicator dispatched 899s AFTER the nonce binds it (the bound is 900s, from both sides)"; fi
rm -rf "$W"

# THE SPAWN LEDGER IS A GUARDED ROOT. It is one of the two records a verdict binds by, and a
# denied lead that could rewrite it with Write could mint the dispatch row that binds its own
# forged pass — measured, one hand-written gate-adjudicator row inside the window lifted the
# deny. The ALLOW twin is a dispatched agent's edit of the same file, which exits at arm 2.
seed open-fail
OUT="$(drive "$W" Edit "$W/_bmad-output/spawn-ledger.jsonl")"
if denied "$OUT"; then ok "7a: a denied LEAD may not Write the spawn ledger — the record a verdict binds by is under the guard"
else bad "7a: the lead rewrote spawn-ledger.jsonl while denied — it can mint the dispatch row that binds its own forged pass"; fi
OUT="$(drive "$W" Edit "$W/_bmad-output/spawn-ledger.jsonl" "agate-x-0123456789abcdef")"
if denied "$OUT"; then bad "7a: a DISPATCHED agent's edit of the spawn ledger was denied — arm 2 no longer precedes the guarded roots"
else ok "7a: ...and a dispatched agent's edit of the same file is allowed (arm 2 precedes the guarded roots)"; fi
rm -rf "$W"

# THE SUBAGENT PROBE LEDGER IS A GUARDED ROOT, for the spawn ledger's reason one join over: on a
# consumer whose write rows carry no transcript_path, `merge-adversarial-shards.sh` derives every
# adversary dispatch id from this file, so one lead-written row maps a remediator's shard onto a
# real adversary dispatch — measured, it turned a REFUSED merge into MERGED. Write and Edit are
# both denied; the ALLOW twins are one property apart each: a dispatched agent's Write of the same
# file (arm 2), and the same lead Write with no FAIL on the live pass.
seed open-fail
PROBE_LEDGER="$W/_bmad-output/subagent-context.jsonl"
OUT="$(drive "$W" Write "$PROBE_LEDGER")"
if denied "$OUT"; then ok "7a: a denied LEAD may not Write subagent-context.jsonl — the probe ledger a shard merge joins through is under the guard"
else bad "7a: the lead Wrote subagent-context.jsonl while denied — one row maps a remediator's shard onto an adversary dispatch"; fi
OUT="$(drive "$W" Edit "$PROBE_LEDGER")"
if denied "$OUT"; then ok "7a: ...and may not Edit it either"
else bad "7a: the lead Edited subagent-context.jsonl while denied — the Write deny is bypassed by the other tool"; fi
OUT="$(drive "$W" Write "$PROBE_LEDGER" "agate-x-0123456789abcdef")"
if denied "$OUT"; then bad "7a: a DISPATCHED agent's Write of subagent-context.jsonl was denied — arm 2 no longer precedes the guarded roots"
else ok "7a: ...and a dispatched agent's Write of the same file is allowed (arm 2 precedes the guarded roots)"; fi
rm -rf "$W"
seed pass
OUT="$(drive "$W" Write "$W/_bmad-output/subagent-context.jsonl")"
if denied "$OUT"; then bad "7a: a lead Write of subagent-context.jsonl under an all-PASS gate was DENIED — the probe-ledger root fires with no failure to guard"
else ok "7a: ...and the same lead Write with no FAIL on the live pass is allowed"; fi
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

  # --- WHAT THE CACHED ROWS ARE WORTH IS A PROPERTY OF THE VERIFIER, and no arm could see it --
  # The rows this cache holds are the ones that PASSED the citation verifier, so a cache written
  # by a build whose predicate was weaker must not be readable by one whose predicate is
  # stronger. Every other key term is blind to that: the escalations digest, the metrics file
  # and the sibling are all unmoved when the verification changes. The key carried a
  # hand-written generation tag for this, and a tag only invalidates when somebody remembers to
  # change it -- measured, reverting it left this fixture at exit 0 and the string appeared in
  # no validator, so it was bound by nothing. The verifier's own file key is the term that
  # cannot be forgotten, and this arm is what says it is there.
  #
  # THE WORLD IS THE ARM ABOVE'S, ONE PROPERTY APART. That arm proved a poisoned row IS read
  # back under a matching key; here the same poison sits under a key whose VERIFIER term is
  # stale, so a DENY means the row was reused across a change to the predicate and an ALLOW
  # means the guard treated it as a miss and re-asked. Nothing else about the world moves.
  drive "$W" Edit "$W/$ART" "" "$W/$TRC" >/dev/null 2>&1   # re-warm; the touch above invalidated
  GRD_STEER="$W/scripts/ai-dlc/validate-steering-budget.sh"
  [ -f "$GRD_STEER" ] || GRD_STEER="$W/core/scripts/validate-steering-budget.sh"
  if [ ! -f "$CACHEF" ]; then
    bad "S1-verifier-key: FIXTURE BROKEN — no cache after re-warming, so this arm has nothing to read back"
  elif [ ! -f "$GRD_STEER" ]; then
    bad "S1-verifier-key: FIXTURE BROKEN — the citation verifier is not in this workspace ($GRD_STEER), so its key term cannot be moved"
  else
    VK="$(head -1 "$CACHEF")"
    printf '%s\nnot-this-catalog\t7\t3\t0\t2026-08-01T00:00:00Z | "Operator-suppress this FAIL (Recommended)"\tseeded cache poison\n' "$VK" > "$CACHEF"
    # EDIT THE VERIFIER, do not merely touch it: `fkey` is size AND mtime, and inside one whole
    # second a touch moves neither. A trailing comment moves the size, which no clock can undo.
    printf '\n# fixture: the verifier changed under a warm cache\n' >> "$GRD_STEER"
    OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
    VK2="$(head -1 "$CACHEF")"
    if [ "$VK" = "$VK2" ] && denied "$OUT"; then
      bad "S1-verifier-key: the key did not move when the CITATION VERIFIER changed, and the poisoned row was reused — rows that passed one predicate are being handed to a different one, which is the one direction this cache must not fail in"
    elif denied "$OUT"; then
      bad "S1-verifier-key: the poisoned row was reused although the key moved — the guard is not comparing the key it computes"
    else
      ok "S1-verifier-key: editing the citation verifier invalidates the key and the sibling re-answers — a cache written under one predicate cannot decide a lift under another"
    fi
  fi
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
if grd_world suppressed-expired "$GRD_DOCS"; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
  if denied "$OUT"; then ok "S13b-twin: an EXPIRED entry on the docs layout still DENIES — the fallback timeline is read, not merely found"
  else bad "S13b-twin: an expired entry lifted on the docs layout — the fallback file is being found and not read"; fi
else
  bad "S13b-twin: FIXTURE BROKEN — the expiring timeline did not move to the docs fallback"
fi
rm -rf "$W"


# --- THE CITATION FLOOR IS MEASURED ON THE NORMALISED QUOTE, at arm 7b and at arm 9 -------------
# Both sites compared bash `${#q}` against 12 while `--cite` collapses whitespace and trims, so a
# padded `"          yes"` (3 normalised) and twelve spaces (EMPTY normalised, and `includes("")`
# is true of every turn) verified against ANY in-window operator turn -- and lifted a deny. Each
# corpus below holds exactly one such turn, the consumer's typed `1. Yes.\n2. Yes.`, in a member the
# reader does not open first, so the pre-fix build LIFTS on both. The whole quote is the ALLOW twin.
#
# SIX CELLS, ONE STRING, every one PRESENCE-shaped: D = the deny JSON, S = an allow with
# GATE_REMEDIATION_SUPPRESSED in the flow log, L = an allow with "Lifted by VERIFIED operator
# authorization" in it, A = an allow carrying neither (which no correct cell expects).
#   7b padded, 7b blank, 7b whole, arm-9 padded, arm-9 blank, arm-9 whole  ->  D D S D D L
# A FRESH WORKSPACE PER DRIVE: arm 7b caches its rows under a key that does not name the hook, so
# two variants driven in one workspace would read each other's answer.
echo "  gate-remediation-deny: resolved predicate = $STEER"
fl_world() {  # <7b|9> <padded|blank|whole> -> W, FL_TR
  local q
  case "$2" in padded) q="          yes" ;; blank) q="            " ;; *) q="1. Yes. 2. Yes." ;; esac
  if [ "$1" = 7b ]; then
    seed "suppressed-yes-$2"; FL_TR="$W/$TRC"
  else
    seed open-fail
    cp "$STEER" "$W/scripts/ai-dlc/validate-steering-budget.sh"
    mkdir -p "$W/sessions-yes"
    printf '%s\n' '{"type":"user","timestamp":"2026-08-11T19:00:00Z","message":{"content":"/ai-dlc Sprint 302. Kick off."}}' > "$W/sessions-yes/a-monday.jsonl"
    cat > "$W/sessions-yes/b-incident.jsonl" <<'EOF'
{"parentUuid":"9b1f0c2e-0000-4000-8000-000000000001","isSidechain":false,"type":"assistant","timestamp":"2026-08-11T19:55:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Two decisions need you: 1. Re-stamp it yourself? 2. File the follow-up?"}]},"uuid":"9b1f0c2e-0000-4000-8000-000000000002","sessionId":"22e0f5c2-0000-4000-8000-000000000000"}
{"parentUuid":"9b1f0c2e-0000-4000-8000-000000000002","isSidechain":false,"promptId":"9b1f0c2e-0000-4000-8000-000000000003","type":"user","message":{"role":"user","content":"1. Yes.\n2. Yes."},"uuid":"9b1f0c2e-0000-4000-8000-000000000004","timestamp":"2026-08-11T19:55:54.171Z","permissionMode":"bypassPermissions","origin":{"kind":"human"},"promptSource":"typed","turnOrigin":"human","userType":"external","entrypoint":"cli","sessionId":"22e0f5c2-0000-4000-8000-000000000000"}
EOF
    : > "$W/sessions-yes/c-current.jsonl"
    printf 'operator_authorization: 2026-08-11T19:55:54Z | "%s"\n' "$q" \
      > "$W/_bmad-output/gate-adjudication/story-20260811T193044Z.authorization.md"
    FL_TR="$W/sessions-yes/c-current.jsonl"
  fi
}
FL_CELLS=""
fl_cells() {  # <hook> -> FL_CELLS, or "BROKEN"
  local h="$1" keys="7b:padded 7b:blank 7b:whole 9:padded 9:blank 9:whole" c="" k o lg
  for k in $keys; do
    fl_world "${k%%:*}" "${k#*:}" || { FL_CELLS="BROKEN"; rm -rf "$W"; return; }
    o="$(drive "$W" Edit "$W/$ART" "" "$FL_TR" "$h")"
    lg="$(cat "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)"
    if denied "$o"; then c="${c}D"
    elif grep -qF 'GATE_REMEDIATION_SUPPRESSED' <<<"$lg"; then c="${c}S"
    elif grep -qF 'Lifted by VERIFIED operator authorization' <<<"$lg"; then c="${c}L"
    else c="${c}A"; fi
    rm -rf "$W"
  done
  FL_CELLS="$c"
}
fl_report() {  # <label> <want> <hook>
  fl_cells "$3"
  if [ "$FL_CELLS" = "$2" ]; then ok "$1: $2 -> $FL_CELLS"
  else bad "$1: scored $FL_CELLS, wanted $2"; fi
}
# THE INCIDENT IS NOT THE MEMBER THE READER OPENS FIRST, in either corpus. Asked of the reader's
# own call, because shell glob order and readdirSync order are two different claims.
fl_first() { node -e 'const fs=require("fs");console.log(fs.readdirSync(process.argv[1]).filter(f=>f.endsWith(".jsonl"))[0]||"")' "$1" 2>/dev/null; }
FL_PROBE=""
fl_world 7b whole && FL_PROBE="$(fl_first "$W/sessions-jsonl")"; rm -rf "$W"
fl_world 9 whole && FL_PROBE="$FL_PROBE $(fl_first "$W/sessions-yes")"; rm -rf "$W"
case "$FL_PROBE" in
  *incident*|" "*|*" ") bad "FLOOR-pre: FIXTURE BROKEN — the reader's first members are '$FL_PROBE'; the incident must not be first" ;;
  *) ok "FLOOR-pre: the reader opens '$FL_PROBE' first; the incident turn is in a later member of each corpus" ;;
esac
fl_report "FLOOR (7b padded/blank/whole, arm 9 padded/blank/whole)" DDSDDL "$HOOK"

# --- W1-W3. FAIL_WAIVED reads as FAIL unless its waiver verifies. Check 7 is the only failing
# check and NO SUPPRESSED entry exists, so only the waiver join can lift it. Each world is fresh,
# because arm 7b caches its verified rows and a mutant reading the control's cache would never
# reach the join it edits.
w_drive() { # <case> [hook] -> 0 when the lead's edit is ALLOWED
  seed "$1"; local o; o="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "${2:-$HOOK}")"; WLOG="$W/_bmad-output/pipeline-continuation-log.md"
  W_OUT="$o"; ! denied "$o"; }
w_p1() { w_drive waived-real "${1:-}" && grep -q 'FAIL_WAIVED under a verified waiver (7)' "$WLOG" 2>/dev/null; local r=$?; rm -rf "$W"; return $r; }
w_p2() { ! w_drive waived-fabricated "${1:-}" && case "$W_OUT" in *'check(s) `7`'*) true ;; *) false ;; esac; local r=$?; rm -rf "$W"; return $r; }
w_p3() { ! w_drive waived-noverifier "${1:-}" && case "$W_OUT" in *'check(s) `7`'*) true ;; *) false ;; esac; local r=$?; rm -rf "$W"; return $r; }
if w_p1; then ok "W1: FAIL_WAIVED under a real, verified OVERRIDDEN waiver -> ALLOWED, and logged as waived"
else bad "W1: a FAIL_WAIVED whose waiver_id names a verified OVERRIDDEN entry stayed LOCKED (or allowed silently)"; fi
if w_p2; then ok "W2: FAIL_WAIVED naming a fabricated waiver_id -> DENIED, check 7 named"
else bad "W2: a FAIL_WAIVED under a waiver_id no escalation entry carries ESCAPED the lock"; fi
if w_p3; then ok "W3: FAIL_WAIVED whose waiver cannot be verified (no citation verifier) -> DENIED"
else bad "W3: the waiver was taken without its citation being verifiable — the lock failed open"; fi

# W4/W5: arm 7a over a FAIL_WAIVED-only pass, one property apart. The newer verdict records
# check 7 FAIL_WAIVED under the REAL waiver, so arm 7b alone would ALLOW it; only the dispatch
# binding separates the two. Unbound -> it may not acquit: DENY, logged GATE_VERDICT_UNBOUND,
# adjudicated on the older bound FAIL. Bound -> arm 7b verifies the waiver: ALLOW.
seed waived-forged-unbound
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT" && grep -q 'GATE_VERDICT_UNBOUND' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "W4: an UNBOUND round-nonce verdict whose only failing check is FAIL_WAIVED under a real waiver -> DENIED, GATE_VERDICT_UNBOUND logged"
else bad "W4: an unbound FAIL_WAIVED-only verdict ACQUITTED the lead — arm 7a was skipped and arm 7b opened the lock"; fi
rm -rf "$W"
seed waived-forged-bound
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if ! denied "$OUT" && grep -q 'FAIL_WAIVED under a verified waiver (7)' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "W5: the same verdict BOUND by its write row -> ALLOWED through the verified waiver"
else bad "W5: a bound FAIL_WAIVED-only verdict under a verified waiver stayed locked, or allowed without verifying it"; fi
rm -rf "$W"

# --- W6-W9. The near-misses of W4, and the trailing-tab id. Locked: a PLAIN FAIL on the waived
# check's own id (W6), a plain FAIL with a null id (W7), two forged FAIL_WAIVED-only passes where
# the second becomes the unbound substitute (W8). Unlocked: the real waiver_id with a trailing tab,
# which Check 26's rstrip() matches (W9).
wn_locked() { # <case> <hook|""> <the check(s) the deny must name, exactly> -> 0 when so
  seed "$1"; local o; o="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "${2:-$HOOK}")"
  denied "$o" && case "$o" in *"check(s) \`$3\`"*) true ;; *) false ;; esac; local r=$?; rm -rf "$W"; return $r; }
# W6: the plain FAIL on 7 stays; the waived 7 row is lifted, so `7` is the one left standing.
w_p6() { wn_locked waived-forged-dup "${1:-}" 7; }
# W7: the null-id plain FAIL stays failing under the token `null`, never as a word that vanishes.
# The pass is UNBOUND, so no waiver applies to it and its FAIL_WAIVED 7 reads as a plain FAIL too:
# the deny names `null 7`, and the older bound pass's 7 under OTHER PASSES.
w_p7() { wn_locked waived-forged-nullid "${1:-}" "null 7"; }
w_p8() { seed waived-forged-two; local o; o="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "${1:-$HOOK}")"
  denied "$o" && grep -q 'Adjudicating on story-20260811T200000Z' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null
  local r=$?; rm -rf "$W"; return $r; }
w_p9() { w_drive waived-tab "${1:-}" && grep -q 'FAIL_WAIVED under a verified waiver (7)' "$WLOG" 2>/dev/null; local r=$?; rm -rf "$W"; return $r; }
# W10: W6 with the newer pass BOUND. An unbound pass takes no waiver at all, so W6 can no longer
# see a waiver lifting a plain FAIL by id; a bound one takes its waiver, and the plain 7 stays.
w_p10() { wn_locked waived-forged-dup-bound "${1:-}" 7; }
# W11: W8 with the real failing pass removed. The only FAILs recorded are the two forgeries'
# FAIL_WAIVED rows, so only the convict-only reading of a waiver stands between them and an allow.
w_p11() { wn_locked waived-forged-two-only "${1:-}" 7; }
if w_p6; then ok "W6: an unbound FAIL_WAIVED verdict carrying a PLAIN FAIL on the same check 7 -> DENIED; a waiver never lifts a plain FAIL row"
else bad "W6: a plain FAIL sharing the waived check's id was lifted by the waiver"; fi
if w_p7; then ok "W7: the same verdict with a plain FAIL whose check_id is null -> DENIED"
else bad "W7: a null-id plain FAIL vanished and the waiver opened the lock"; fi
if w_p8; then ok "W8: two forged FAIL_WAIVED-only passes, nothing bound -> DENIED, the second forgery adjudicated as a CONVICT-ONLY substitute"
else bad "W8: the unbound substitute was acquitted by its own waiver"; fi
if w_p9; then ok "W9: the real waiver_id with a trailing TAB -> ALLOWED, as Check 26's rstrip() reads it"
else bad "W9: a tab-trailing waiver_id the gate accepts stayed LOCKED — the guard and Check 26 disagree about one entry"; fi
if w_p10; then ok "W10: a BOUND verdict carrying a PLAIN FAIL beside its waived check 7 -> DENIED on 7; the waiver lifts only the waived row"
else bad "W10: on a bound pass the waiver lifted the plain FAIL sharing its check id"; fi
if w_p11; then ok "W11: two forged FAIL_WAIVED-only passes and nothing else -> DENIED on 7; an unbound set takes no waiver"
else bad "W11: two unbound FAIL_WAIVED-only passes acquitted themselves through their own waiver"; fi

# =============================================================================
# ARM 7a AT ACQUITTAL. An UNBOUND live pass that records a FAIL never reached the early binding
# (that runs only when the live pass is clean), so a forged round-nonce pass recording only
# COVERED FAILs was acquitted by arm 7b -- or by a repair record keyed on its own nonce -- and
# the bound pass's uncovered FAIL beneath it was never read. Every world below ALLOWED on the
# base hook except the convict control; the seeds are listed in `seed.sh` beside their cases.
# An unbound pass may CONVICT and may never ACQUIT: each DENY world asserts the deny, the
# `GATE_VERDICT_UNBOUND` flow event, and that the deny names the check the forger could not
# cover. Each ALLOW twin is one property apart, so a guard that denies every unbound pass, or
# every covered one, fails a twin.
# =============================================================================
aq_drive() { # <case> [hook] -> AQ_OUT, AQ_LOG; leaves the workspace at W
  seed "$1"
  AQ_OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "${2:-$HOOK}")"
  AQ_LOG="$(cat "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)"
}
aq_names() { # <ids> -> 0 when the deny names exactly that uncovered set, for the pass it leads
  # with or for another pass still owed (the `OTHER PASSES ... \`<stem>\` (<ids>)` clause)
  case "$AQ_OUT" in *"check(s) \`$1\`"*|*"OTHER PASSES STILL OWED A REPAIR"*"\` ($1)"*) return 0 ;; esac; return 1; }
aq_unbound() { case "$AQ_LOG" in *GATE_VERDICT_UNBOUND*) return 0 ;; esac; return 1; }
aq_deny() { # <case> <ids the deny must name> <label>
  aq_drive "$1"
  if denied "$AQ_OUT"; then ok "$3 -> DENIED"
  else bad "$3 -> ALLOWED: an unbound pass acquitted the gate"; fi
  if aq_unbound; then ok "$3: ...GATE_VERDICT_UNBOUND is in the flow log"
  else bad "$3: ...no GATE_VERDICT_UNBOUND in the flow log — the substitution is invisible"; fi
  if denied "$AQ_OUT" && aq_names "$2"; then ok "$3: ...and the deny names the uncovered check \`$2\`"
  else bad "$3: ...the deny does not name the uncovered check \`$2\`"; fi
  rm -rf "$W"
}
aq_allow() { # <case> <flow event that must be logged> <label>
  aq_drive "$1"
  if denied "$AQ_OUT"; then bad "$3 -> DENIED: the twin one property apart was refused"
  else ok "$3 -> ALLOWED"; fi
  case "$AQ_LOG" in *"$2"*) ok "$3: ...and $2 is logged" ;; *) bad "$3: ...$2 is not in the flow log" ;; esac
  rm -rf "$W"
}

aq_deny suppressed-forged-unbound 3a "AQ-A (L2): a bound pass FAILing 3a+7, then an UNBOUND pass FAILing only the suppressed 7"
aq_allow suppressed-forged-bound GATE_REMEDIATION_SUPPRESSED "AQ-A twin: the same newer pass BOUND by its write row"
aq_allow suppressed-unbound-substitute-covered GATE_REMEDIATION_SUPPRESSED "AQ-A twin: every FAIL in the convict set is covered"
aq_drive suppressed-unbound-substitute-covered
if aq_unbound; then ok "AQ-A twin: ...GATE_VERDICT_UNBOUND is still logged on the covered allow (the substitute was re-partitioned, not skipped)"
else bad "AQ-A twin: the covered allow logged no GATE_VERDICT_UNBOUND — the binding was never asked on this exit"; fi
rm -rf "$W"
aq_deny subst-newer-unbound-fail 3a "AQ-B: a bound CLEAN pass, a NEWER unbound pass FAILing 3a, a forged clean live pass"
aq_deny subst-nobound-older-fail 3a "AQ-L1: nothing bound, an OLDER unbound pass FAILing 3a, a live pass FAILing only the suppressed 7"
aq_deny subst-two-forged 3a "AQ-2F: nothing bound, a real FAIL on 3a under TWO forged passes FAILing only the suppressed 7"
# With nothing bound, the flow log must say the set it convicted on is itself unbound.
for _aq in subst-nobound-older-fail subst-two-forged; do
  aq_drive "$_aq"
  case "$AQ_LOG" in *"itself unbound"*) ok "AQ ($_aq): ...the flow log says the convict set is itself unbound" ;;
    *) bad "AQ ($_aq): the nothing-bound convict set is not flagged 'itself unbound' in the flow log" ;; esac
  rm -rf "$W"
done
aq_deny subst-crossgate 3a "AQ-L3: planning s301 bound CLEAN, story s302 unbound FAIL 3a, forged implementation s303 FAIL 7 covered"
aq_allow subst-percatalog GATE_REMEDIATION_SUPPRESSED "AQ-CAT: ext-catalog passes FAILing 7 over a bound core CLEAN pass, \`[ext-catalog] 7\` in force"
aq_drive subst-percatalog
if aq_unbound; then ok "AQ-CAT: ...GATE_VERDICT_UNBOUND is logged before the suppressed allow"
else bad "AQ-CAT: no GATE_VERDICT_UNBOUND on the per-catalog allow"; fi
rm -rf "$W"
aq_deny subst-repair-unbound 3a "AQ-R8: a repair record keyed on the UNBOUND live nonce, over a bound pass FAILing 3a"
aq_allow subst-repair-both GATE_REMEDIATION_LIFTED "AQ-R8 twin: each contributing pass carries its own repair record"
# THE CONVICT CONTROL. The live pass is unbound and its OWN FAIL on 3a is uncovered; that was a
# deny on the base hook and stays one, on the live pass's own check.
aq_drive subst-convict-own
if denied "$AQ_OUT" && aq_names 3a; then ok "AQ-CONVICT: an unbound live pass with an uncovered FAIL on 3a -> DENIED on its own check"
else bad "AQ-CONVICT: an unbound live pass's own uncovered FAIL no longer convicts on 3a"; fi
case "$AQ_OUT" in *'Gate pass `story-20260811T210000Z` recorded FAIL on check(s) `3a`'*) ok "AQ-CONVICT: ...and the deny leads with the live nonce" ;;
  *) bad "AQ-CONVICT: the deny does not lead with the live pass that owns 3a" ;; esac
rm -rf "$W"
# AQ-R8, the lead clause: the live pass's own 9 is named first, and the older bound pass's 3a is
# owed by ITS nonce -- a record keyed on the live nonce lifts the live pass and nothing else.
aq_drive subst-repair-unbound
case "$AQ_OUT" in *'OTHER PASSES STILL OWED A REPAIR, newest first: `story-20260811T193044Z` (3a)'*) ok "AQ-R8: ...the deny says the bound pass's 3a is owed a record bound to story-20260811T193044Z" ;;
  *) bad "AQ-R8: the deny does not name the bound pass still owed a repair by its own nonce" ;; esac
rm -rf "$W"

# --- MALFORMED INPUT IN THE GATE DIRECTORY. The convict set reads every pass in one query, so one
# file the query cannot take -- a stem the shell splits (a space, a newline), a stem jq reads as an
# option (`--`), a file nobody can open, a verdict that is two JSON documents -- must not make the
# whole set fall back to the live pass alone. Each world is a shipped seed plus ONE such file or
# edit; every one ALLOWED on the first cut of the fix and must DENY with GATE_VERDICT_UNBOUND.
# A decoy is `{"verdicts":[]}`: it records no FAIL, so its only effect is on how the set is read.
ad_seed() { # <seed> -- applied to the workspace at W
  local gd="$W/_bmad-output/gate-adjudication"
  case "$1" in
    space)  printf '{"verdicts":[]}\n' > "$gd/old decoy-20200101T000000Z.verdict.json" ;;
    nl)     printf '{"verdicts":[]}\n' > "$gd/x
old-20200101T000000Z.verdict.json" ;;
    dash)   printf '{"verdicts":[]}\n' > "$gd/--seq-20260811T205900Z.verdict.json" ;;
    unread) printf '{"verdicts":[]}\n' > "$gd/decoy-20260811T205900Z.verdict.json"
            chmod 000 "$gd/decoy-20260811T205900Z.verdict.json" ;;
    md-live)  printf '{}\n' >> "$gd/story-20260811T210000Z.verdict.json" ;;
    md-bound) printf '{}\n' >> "$gd/story-20260811T193044Z.verdict.json" ;;
    md-mid)   printf '{}\n' >> "$gd/story-20260811T200000Z.verdict.json" ;;
    unparse)  printf '{not json\n' > "$gd/decoy-20260811T205900Z.verdict.json" ;;
    # IN-WINDOW twins of the unsafe-stem shapes: dated between the bound pass (19:30:44Z) and the
    # live one (21:00:00Z), so the window keeps them and only the unsafe-stem check can act. A
    # 2020 decoy is older than the bound pass and the window drops it before that check runs.
    iw-space) printf '{"verdicts":[]}\n' > "$gd/x y-20260811T200000Z.verdict.json" ;;
    iw-nl)    printf '{"verdicts":[]}\n' > "$gd/x
y-20260811T200000Z.verdict.json" ;;
    iw-dash)  printf '{"verdicts":[]}\n' > "$gd/--seq-20260811T200000Z.verdict.json" ;;
    # A safe stem jq prints NOTHING for, by two different paths. Zero bytes: jq reads no input
    # from it and the one-query read SUCCEEDS without a row. Unparseable: the one-query read
    # FAILS, the per-file re-read fails on this file again, and it still has no row. Both reach
    # the join as a candidate with no row, which is the case the join must convict.
    iw-zero)    : > "$gd/story-20260811T200000Z.verdict.json" ;;
    # A forged in-window file ending in a bare scalar and NO newline: in jq's input stream the
    # scalar runs straight into the NEXT file. `planning-` globs before the bound `story-` pass;
    # `story-…T200000Z` globs before the live `story-…T210000Z` one. The honest neighbour must not
    # be the record blamed, and must keep its own FAILs.
    trail-bound) printf '{"catalog":"core","verdicts":[]}\n1' > "$gd/planning-20260811T200000Z.verdict.json" ;;
    trail-live)  printf '{"catalog":"core","verdicts":[]}\n1' > "$gd/story-20260811T200000Z.verdict.json" ;;
    # The same forged file on the all-covered world: there it is the ONLY thing that can deny,
    # through its non-object document.
    iw-nonobj)   printf '{"catalog":"core","verdicts":[]}\n1' > "$gd/story-20260811T200000Z.verdict.json" ;;
    iw-unparse) printf '{not json\n' > "$gd/story-20260811T200000Z.verdict.json" ;;
    none) ;;
  esac
}
ad_drive() { # <case> <seed> [hook] -> AQ_OUT, AQ_LOG; the workspace stays at W
  seed "$1"; ad_seed "$2"
  AQ_OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "${3:-$HOOK}")"
  AQ_LOG="$(cat "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)"
}
ad_clean() { chmod -R u+rw "$W" 2>/dev/null; rm -rf "$W"; }
# THE MALFORMED-INPUT WORLDS, one line each: <label>|<case>|<seed>|<file the deny must name>.
# Every arm below iterates this one list, so a world added here is scored by each of them.
# The name is the deny's own rendering: every byte outside [A-Za-z0-9._-] shown as `?`. The 2020
# decoys carry none -- the window drops them, so on the fix they are never read at all and only
# the old word-split read could trip on them. The IW worlds are on `suppressed-unbound-substitute-
# covered`, which ALLOWS without its decoy (AD-IW-CONTROL), so the decoy is the only thing there
# that can deny.
AD_WORLDS='AD-SPACE|forged-clean|space|
AD-NEWLINE|forged-clean|nl|
AD-UNREADABLE|forged-clean|unread|`decoy-20260811T205900Z.verdict.json`
AD-UNPARSEABLE|forged-clean|unparse|`decoy-20260811T205900Z.verdict.json`
AD-DASH|forged-clean|dash|`--seq-20260811T205900Z.verdict.json`
AD-A-SPACE|suppressed-forged-unbound|space|
AD-B-SPACE|subst-newer-unbound-fail|space|
AD-W4-SPACE|waived-forged-unbound|space|
AD-CONVICT-MULTIDOC|subst-convict-own|md-live|
AD-A-MULTIDOC|suppressed-forged-unbound|md-bound|
AD-B-MULTIDOC|subst-newer-unbound-fail|md-mid|
AD-IW-SPACE|suppressed-unbound-substitute-covered|iw-space|`x?y-20260811T200000Z.verdict.json`
AD-IW-NEWLINE|suppressed-unbound-substitute-covered|iw-nl|`x?y-20260811T200000Z.verdict.json`
AD-IW-DASH|suppressed-unbound-substitute-covered|iw-dash|`--seq-20260811T200000Z.verdict.json`
AD-IW-ZERO|suppressed-unbound-substitute-covered|iw-zero|`story-20260811T200000Z.verdict.json`
AD-IW-UNPARSE|suppressed-unbound-substitute-covered|iw-unparse|`story-20260811T200000Z.verdict.json`
AD-IW-NONOBJ|suppressed-unbound-substitute-covered|iw-nonobj|`story-20260811T200000Z.verdict.json`
AD-TRAIL-BOUND|suppressed-forged-unbound|trail-bound|
AD-TRAIL-LIVE|subst-convict-own|trail-live|'
# The newline world needs a filesystem that takes a newline in a name; say so if this one does not.
_nlprobe="$(mktemp -d)"
if printf 'x' > "$_nlprobe/a
b" 2>/dev/null && [ -f "$_nlprobe/a
b" ]; then AD_NL=1; else AD_NL=0; bad "AD-NEWLINE: FIXTURE BROKEN — this filesystem refuses a newline in a file name, so the newline world cannot be built"; fi
rm -rf "$_nlprobe"
ad_skip() { # <seed> -> 0 when this world cannot be built here
  case "$1" in nl|iw-nl) [ "$AD_NL" -eq 1 ] && return 1; return 0 ;; esac; return 1; }
# AD-IW-CONTROL: the IW worlds' seed, no decoy. It must ALLOW, or the IW denials are not the decoy's.
ad_drive suppressed-unbound-substitute-covered none
if denied "$AQ_OUT"; then bad "AD-IW-CONTROL: the in-window worlds' seed DENIES with no decoy — the IW arms cannot attribute their deny to the decoy"
else ok "AD-IW-CONTROL: the in-window worlds' seed with NO decoy -> ALLOWED (so each IW deny is the decoy's)"; fi
ad_clean
while IFS='|' read -r _al _ac _am _an; do
  [ -n "$_al" ] || continue
  ! ad_skip "$_am" || continue
  ad_drive "$_ac" "$_am"
  # chmod 000 does not stop a reader that bypasses permissions (root, some sandboxes); then the
  # decoy is just a readable clean pass and this world asserts nothing about an unreadable one.
  if [ "$_am" = unread ] && [ -r "$W/_bmad-output/gate-adjudication/decoy-20260811T205900Z.verdict.json" ]; then
    bad "$_al: FIXTURE BROKEN — the chmod-000 decoy is still readable here, so the unreadable world was not built"
    ad_clean; continue
  fi
  if denied "$AQ_OUT"; then ok "$_al ($_ac + $_am): DENIED"
  else bad "$_al ($_ac + $_am): ALLOWED — one malformed file made the convict set fall back to the live pass alone"; fi
  if aq_unbound; then ok "$_al: ...GATE_VERDICT_UNBOUND is in the flow log"
  else bad "$_al: ...no GATE_VERDICT_UNBOUND in the flow log"; fi
  if [ -n "$_an" ]; then
    case "$AQ_OUT" in *"UNREADABLE GATE RECORDS: "*"$_an"*) ok "$_al: ...and the deny names $_an as an unreadable record" ;;
      *) bad "$_al: the deny does not name $_an under UNREADABLE GATE RECORDS" ;; esac
  fi
  # THE TRAILING-SCALAR WORLDS: the deny names the honest pass's own 3a, and never blames that
  # honest file as an unreadable record (the forged neighbour may be named; it is the bad one).
  case "$_al" in
    AD-TRAIL-BOUND|AD-TRAIL-LIVE)
      _honest=story-20260811T193044Z; [ "$_al" = AD-TRAIL-LIVE ] && _honest=story-20260811T210000Z
      if denied "$AQ_OUT" && aq_names 3a; then ok "$_al: ...and the deny names the honest pass's uncovered 3a"
      else bad "$_al: the deny does not name 3a — the honest pass lost its FAIL to the forged neighbour"; fi
      # The WHOLE record list, never its first entry: the forged neighbour is usually listed
      # first, and a capture that stops at the first `.verdict.json` never reaches the honest one.
      _ur="$(printf '%s' "$AQ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null \
        | grep '^UNREADABLE GATE RECORDS:' | sed 's/ in `.*//' | head -1)"
      case "$_ur" in *"$_honest"*) bad "$_al: UNREADABLE GATE RECORDS blames the HONEST file $_honest ($_ur)" ;;
        *) ok "$_al: ...and no UNREADABLE GATE RECORDS line names the honest file $_honest" ;; esac ;;
  esac
  if [ "$_al" = AD-W4-SPACE ]; then
    case "$AQ_LOG" in *"under a verified waiver"*) bad "AD-W4-SPACE: the flow log records the unbound pass's waiver as verified — its FAIL_WAIVED was lifted" ;;
      *) ok "AD-W4-SPACE: ...and no waiver of the unbound pass was taken (no 'under a verified waiver' in the flow log)" ;; esac
  fi
  ad_clean
done <<ADEOF
$AD_WORLDS
ADEOF

# ...and the no-FAIL-anywhere residual stays an ALLOW: an unbound pass may convict, but only on
# something recorded.
aq_drive forged-clean-nobound-allclean
if denied "$AQ_OUT"; then bad "AQ-RESIDUAL: no pass records a FAIL and the guard still denied"
else ok "AQ-RESIDUAL: no pass anywhere records a FAIL -> ALLOWED (the named limit)"; fi
rm -rf "$W"

# =============================================================================
# ARM 1b — A REMEDIATOR DOES NOT WRITE THE ESCALATION RECORD. The role comes from the harness's
# meta sidecar, never from the agent_id, so every id below is opaque except the one cell that
# puts a role NAME in the id and a different role in the meta. Every DENY has an ALLOW twin one
# property apart, in this one workspace.
# =============================================================================
seed open-fail
E1_TR="$W/sess/lead.jsonl"
E1_SUB="$W/sess/lead/subagents"
mkdir -p "$E1_SUB"
printf '%s\n' '{"type":"user","message":{"content":"dispatching"}}' > "$E1_TR"
e1_meta() { printf '%s\n' "$2" > "$E1_SUB/agent-$1.meta.json"; }
# SEVERAL METAS, AND THE REMEDIATOR'S IS NOT THE FIRST MEMBER: an arm that read the first meta in
# the directory instead of the one named by agent_id would read `dev` here and allow.
# SEEDED FROM WHAT THE PRODUCER EMITS. The harness writes the role in `agentType` and never writes
# `customAgentType` (0 of 3216 graph metas, 0 of 1797 ai-dlc metas); the keys below are a real
# graph remediator meta's, ids replaced. Every DENY cell rests on these producer-shaped metas.
e1_meta a0dev    '{"agentType":"dev","description":"Dev seat","toolUseId":"toolu_e1dev","spawnDepth":1,"requestShape":"background","requestNonInteractive":true}'
e1_meta b0arch   '{"agentType":"architect","description":"Architect seat","toolUseId":"toolu_e1arch","spawnDepth":1,"requestShape":"background","requestNonInteractive":true}'
# READER ACCEPT-SET ONLY: c0named and d0swap carry `customAgentType`, which no producer emits. They
# are kept, with cells E4 and A8 and mutant m1b-key-order, solely to cover the reader's key order,
# which the `1b-bind` arm binds to the subagent probe's copy. No deny verdict depends on them.
e1_meta c0named  '{"agentType":"general-purpose","customAgentType":"remediator","teamName":"t"}'
e1_meta d0swap   '{"agentType":"remediator","customAgentType":"dev","teamName":"t"}'
e1_meta e0bad    '{"agentType":"remediator",'
# THE PRODUCER'S NAMED SHAPE, NOT STRIPPED: a named teammate's meta carries its spawn NAME in
# `agentType`. Cell A13 asserts this ALLOWS. It is the KNOWN GAP, held shut by
# `ai-dlc-dispatch-guard.sh` deleting `name` on role-bound dispatches; `1b-name-strip` binds that.
e1_meta f0named  '{"agentType":"remediator-serial-cross","description":"Serial cross-section repair","name":"x","spawnDepth":0,"requestShape":"background","requestNonInteractive":true,"taskKind":"in_process_teammate","teamName":"t"}'
e1_meta remediator-x '{"agentType":"dev","description":"Dev seat","toolUseId":"toolu_e1named","spawnDepth":1,"requestShape":"background","requestNonInteractive":true}'
e1_meta z9rem    '{"agentType":"remediator","description":"Serial cross-section repair","toolUseId":"toolu_e1rem","spawnDepth":1,"requestShape":"background","requestNonInteractive":true}'
E1_FIRST=""; E1_NMETA=0
for _e1m in "$E1_SUB"/*.meta.json; do [ -n "$E1_FIRST" ] || E1_FIRST="${_e1m##*/}"; E1_NMETA=$((E1_NMETA+1)); done
case "$E1_FIRST" in
  agent-a0dev.meta.json) ok "1b-pre: the remediator's meta is not the first of the $E1_NMETA in subagents/ (first: $E1_FIRST)" ;;
  *) bad "1b-pre: FIXTURE BROKEN — the first meta is '$E1_FIRST', so the not-first property is not seeded" ;;
esac
[ ! -e "$E1_SUB/agent-y9rem.meta.json" ] || bad "1b-pre: FIXTURE BROKEN — y9rem must have NO meta"
E1_PEND="$W/docs/escalations/pending.md"
e1() { # <expect deny|allow> <label> <tool> <file_path> <agent> <transcript> [hook]
  local o; o="$(drive "$W" "$3" "$4" "$5" "$6" "${7:-$HOOK}")"
  if [ "$1" = deny ]; then
    if denied "$o"; then ok "$2"; else bad "$2"; fi
  else
    if denied "$o"; then bad "$2"; else ok "$2"; fi
  fi
}
# The cells, as one list so the unmutated hook and each mutant are driven over the same set.
# Fields: id|expect|tool|path|agent|transcript ("-" = no transcript_path)|label
E1_CELLS="E1|deny|Edit|$E1_PEND|z9rem|$E1_TR|a remediator's Edit to pending.md (PROJECT_DIR spelling) is DENIED
E2|deny|Write|docs/escalations/pending.md|z9rem|$E1_TR|a remediator's Write to the RELATIVE docs/escalations/pending.md is DENIED
E3|deny|MultiEdit|$W/src/../docs/escalations/pending.md|z9rem|$E1_TR|a remediator's MultiEdit to an absolute spelling through src/.. is DENIED
E4|deny|Edit|$E1_PEND|c0named|$E1_TR|READER ACCEPT-SET ONLY: customAgentType remediator over agentType general-purpose is DENIED (no producer emits customAgentType)
A1|allow|Edit|$E1_PEND|a0dev|$E1_TR|a dev's identical Edit to pending.md is ALLOWED (role, not tool or path, decides)
A2|allow|Edit|$E1_PEND|b0arch|$E1_TR|an architect's identical Edit to pending.md is ALLOWED
A3|allow|Edit|$E1_PEND||$E1_TR|the LEAD's identical Edit (no agent_id) to pending.md is ALLOWED
A4|allow|Edit|$W/docs/escalations/resolved.md|z9rem|$E1_TR|the remediator's Edit to another docs/escalations file is ALLOWED
A5|allow|Edit|$E1_PEND|y9rem|$E1_TR|FAIL-OPEN: a dispatch with NO meta file is ALLOWED
A6|allow|Edit|$E1_PEND|e0bad|$E1_TR|FAIL-OPEN: a meta that does not parse is ALLOWED
A7|allow|Edit|$E1_PEND|z9rem|-|FAIL-OPEN: the remediator with no transcript_path (so no meta path) is ALLOWED
A8|allow|Edit|$E1_PEND|d0swap|$E1_TR|READER ACCEPT-SET ONLY: agentType remediator under customAgentType dev is ALLOWED (customAgentType is read first)
A9|allow|Edit|$E1_PEND|remediator-x|$E1_TR|an agent_id spelling 'remediator' whose meta says dev is ALLOWED (the id is opaque)
A10|allow|Edit|$W/docs/notes/pending.md|z9rem|$E1_TR|NEAR-MISS past the prefilter: the remediator's Edit to docs/notes/pending.md is ALLOWED
A11|allow|Write|$W/docs/escalations/pending.md.draft|z9rem|$E1_TR|NEAR-MISS past the prefilter: the remediator's Write to docs/escalations/pending.md.draft is ALLOWED
A12|allow|Edit|$W/_bmad-output/planning-artifacts/s1/pending.md|z9rem|$E1_TR|NEAR-MISS past the prefilter: the remediator's Edit to a planning-artifacts pending.md is ALLOWED
A13|allow|Edit|$E1_PEND|f0named|$E1_TR|KNOWN GAP, held shut by the dispatch guard's name deletion: an UNSTRIPPED named remediator meta (agentType = spawn name) is ALLOWED"
e1_drive_all() { # [hook] -> one ok/bad per cell
  while IFS='|' read -r _id _want _tool _fp _ag _tr _lab; do
    [ -n "$_id" ] || continue
    [ "$_tr" = "-" ] && _tr=""
    e1 "$_want" "1b $_id: $_lab" "$_tool" "$_fp" "$_ag" "$_tr" "${1:-$HOOK}"
  done <<E1EOF
$E1_CELLS
E1EOF
}
e1_drive_all "$HOOK"
# The deny's TEXT, guarded on the deny existing.
OUT="$(drive "$W" Edit "$E1_PEND" z9rem "$E1_TR")"
if denied "$OUT"; then
  case "$OUT" in *'`escalated` entry in YOUR OWN repair record'*'The lead reads your record and applies'*) ok "1b: the deny's remedy is an escalated entry in the remediator's own record, which the lead applies" ;;
    *) bad "1b: the deny does not give the escalated-entry remedy" ;; esac
  grep -qF 'REMEDIATOR_ESCALATION_EDIT_DENIED' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
    && ok "1b: the deny is logged as REMEDIATOR_ESCALATION_EDIT_DENIED" \
    || bad "1b: the deny wrote no REMEDIATOR_ESCALATION_EDIT_DENIED event"
else
  bad "1b: no denial to inspect"; bad "  (remedy)"; bad "  (log event)"
fi
# ARM 2 STILL RECORDS FOR THE SAME REMEDIATOR on a path this arm does not own.
E1_AL="$W/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
rm -f "$E1_AL"
OUT="$(drive "$W" Edit "$W/$ART" z9rem "$E1_TR")"
_e1n=0; [ -f "$E1_AL" ] && { _e1n="$(jq -n --arg p "$ART" '[inputs | select(.path == $p and .agent_id == "z9rem")] | length' "$E1_AL" 2>/dev/null)" || _e1n=0; }
if ! denied "$OUT" && [ "$_e1n" = 1 ]; then ok "1b: the remediator's planning-artifact Edit is ALLOWED and arm 2 records exactly 1 row for it"
else bad "1b: the remediator's planning-artifact Edit: denied=$(denied "$OUT" && echo y || echo n), rows=$_e1n (want n, 1)"; fi

# THE ROLE EXPRESSION IS ONE TEXT IN TWO HOOKS. Extracted from the probe's DEFINITION line, asserted
# present exactly once in the guard, and a one-token drift (the two keys swapped) is reported.
PROBE="$(pick "$HERE/../../hooks/ai-dlc-subagent-probe.sh" \
              "$HERE/../../../.claude/hooks/ai-dlc-subagent-probe.sh" \
              "$HERE/../../../core/hooks/ai-dlc-subagent-probe.sh")"
E1_EXPR=""
[ -n "$PROBE" ] && E1_EXPR="$(sed -n "s/^  DEFINITION=\"\\\$(jq -r '\\([^']*\\)'.*/\\1/p" "$PROBE" | head -1)"
case "$E1_EXPR" in
  *customAgentType*agentType*)
    _e1c="$(grep -cF -- "jq -r '$E1_EXPR'" "$HOOK")" || _e1c=0
    if [ "$_e1c" = 1 ]; then ok "1b-bind: the probe's role expression ($E1_EXPR) occurs exactly once in the guard"
    else bad "1b-bind: the probe's role expression occurs $_e1c time(s) in the guard (want 1) — the two reads have FORKED"; fi ;;
  *) bad "1b-bind: no role expression extracted from the subagent probe ('$E1_EXPR') — the binding is vacuous" ;;
esac

# 1b-name-strip -- ARM 1b DEPENDS ON THE DISPATCH GUARD DELETING `name`. A JOIN to the emission that
# `dispatch-model-guard` asserts behaviourally ("`name` is DELETED"), not a second copy of that
# assertion: this arm only proves the emission this fixture's A13 gap relies on is still THERE.
# Keyed on the role-bound rewrite's whole jq program, the line that emits the stripped payload.
DGUARD="$(pick "$HERE/../../hooks/ai-dlc-dispatch-guard.sh" \
               "$HERE/../../../.claude/hooks/ai-dlc-dispatch-guard.sh" \
               "$HERE/../../../core/hooks/ai-dlc-dispatch-guard.sh")"
E1_STRIP="'. + {subagent_type: \$t} | del(.name) | del(.model)'"
E1_NONE="'. + {subagent_type: \$t} | del(.nameZq7Never) | del(.model)'"
e1_strip_count() { local n; n="$(grep -cF -- "$2" "$1")" || n=0; printf '%s' "$n"; }
if [ -z "$DGUARD" ]; then
  bad "1b-name-strip: cannot locate ai-dlc-dispatch-guard.sh — the dependency arm 1b rests on is unchecked"
else
  _e1s="$(e1_strip_count "$DGUARD" "$E1_STRIP")"
  _e1z="$(e1_strip_count "$DGUARD" "$E1_NONE")"
  if [ "$_e1s" = 1 ] && [ "$_e1z" = 0 ]; then
    ok "1b-name-strip: the dispatch guard's role-bound rewrite deletes \`name\` (emission count 1; impossible-anchor control 0)"
  else
    bad "1b-name-strip: the dispatch guard's \`del(.name)\` emission count is $_e1s (want 1; control $_e1z, want 0) — a named remediator's meta then carries its spawn name in agentType, and arm 1b ALLOWS it"
  fi
fi

rm -rf "$W"

# =============================================================================
# THE RECORDER — a gate adjudicator's PART FILE is an artifact-write row, never a verdict-ledger
# row. Three spellings of one file, one writer; the verdict ledger holds a NON-ZERO baseline so
# "unchanged" is a number, not an empty file staying empty.
# =============================================================================
seed open-fail
R_NONCE="story-20260811T193044Z"
R_REL="_bmad-output/gate-adjudication/${R_NONCE}.part-1of3.jsonl"
R_VL="$W/_bmad-output/gate-adjudication/.verdict-writes.jsonl"
R_AL="$W/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
r_world() { # resets both ledgers to the baseline
  printf '%s\n' \
    '{"v":1,"ts":"2026-08-11T19:31:00Z","stem":"story-20260811T193044Z","agent_id":"g0seed","session":"t","tool":"Write"}' \
    '{"v":1,"ts":"2026-08-11T19:32:00Z","stem":"story-20260811T193044Z","agent_id":"g0seed","session":"t","tool":"Edit"}' > "$R_VL"
  rm -f "$R_AL"
}
r_count() { # <file> <jq filter over one row> -> count
  [ -f "$1" ] || { printf '0'; return; }
  jq -n "[inputs | select($2)] | length" "$1" 2>/dev/null || printf 'ERR'
}
r_drive() { # [hook] -> drives the three spellings and the near-miss as adjudicator g7adj
  local h="${1:-$HOOK}"
  drive "$W" Write "$W/$R_REL" g7adj "" "$h" >/dev/null
  drive "$W" Write "$R_REL" g7adj "" "$h" >/dev/null
  drive "$W" Edit "/elsewhere/$R_REL" g7adj "" "$h" >/dev/null
  drive "$W" Write "$W/_bmad-output/gate-adjudication/${R_NONCE}.repair.md" g7adj "" "$h" >/dev/null
}
R_WP="$(cd "$W" && pwd -P)"
r_score() { # <label prefix> -> sets R_PRESENT R_KIND R_AGENT R_TWIN R_VN R_RH R_RE
  R_PRESENT="$(r_count "$R_AL" ".path == \"$R_REL\"")"
  # BL-596: the tree each write landed in -- this workspace for the LOG_DIR and relative spellings,
  # the spelled prefix for the foreign-absolute one, which does not resolve and is kept as spelled.
  R_RH="$(r_count "$R_AL" ".path == \"$R_REL\" and .root == \"$R_WP\"")"
  R_RE="$(r_count "$R_AL" ".path == \"$R_REL\" and .root == \"/elsewhere\"")"
  R_KIND="$(r_count "$R_AL" ".path == \"$R_REL\" and .kind == \"artifact-write\"")"
  R_AGENT="$(r_count "$R_AL" ".path == \"$R_REL\" and .agent_id == \"g7adj\"")"
  R_TWIN="$(r_count "$R_AL" "(.path // \"\") | endswith(\".repair.md\")")"
  R_VN="$(r_count "$R_VL" "true")"
}
r_world
R_V0="$(r_count "$R_VL" "true")"
[ "$R_V0" = 2 ] || bad "R-pre: FIXTURE BROKEN — the verdict-ledger baseline is $R_V0, not 2"
r_drive "$HOOK"; r_score
if [ "$R_PRESENT" = 3 ]; then ok "R: all three spellings of the part file record one artifact-write row each, under ONE normalised path (3)"
else bad "R: $R_PRESENT row(s) for $R_REL (want 3: LOG_DIR, relative and foreign-absolute spellings)"; fi
if [ "$R_PRESENT" != 0 ]; then
  if [ "$R_KIND" = "$R_PRESENT" ]; then ok "R: every part-file row carries kind artifact-write ($R_KIND/$R_PRESENT)"
  else bad "R: $R_KIND of $R_PRESENT part-file rows carry kind artifact-write — every reader filters on kind"; fi
  [ "$R_AGENT" = "$R_PRESENT" ] && ok "R: every part-file row names the adjudicator's agent_id g7adj" \
    || bad "R: $R_AGENT of $R_PRESENT part-file rows name g7adj"
  if [ "$R_RH" = 2 ] && [ "$R_RE" = 1 ]; then ok "R: root names the tree each write landed in: 2 rows this workspace, 1 /elsewhere (BL-596)"
  else bad "R: root rows this workspace=$R_RH /elsewhere=$R_RE (want 2, 1)"; fi
fi
[ "$R_TWIN" = 0 ] && ok "R: the same adjudicator's Write to <nonce>.repair.md (not a part file) records NO artifact row" \
  || bad "R: a non-part gate-adjudication write recorded $R_TWIN artifact row(s)"
if [ "$R_VN" = "$R_V0" ]; then ok "R: the verdict ledger still holds exactly $R_V0 rows — no part row entered it"
else bad "R: the verdict ledger went from $R_V0 to $R_VN rows"; fi
rm -rf "$W"

# =============================================================================
# ARM MD — A SECTIONS ROUND'S DOCUMENT (BL-802). A dispatched agent's write to the `document` a sections
# split manifest under THIS state dir names records ONE artifact-write row, spelled project-relative
# outside the state dir and `<state basename>/...` inside it. Every manifest is written by the REAL
# splitter, `partition-document.sh --split`, never by hand. Each cell drives its own agent id, so a cell's
# count is its own. The world, per state layout (x = the state dir's parent below the project, empty by default):
#   <x>docs/design-notes.md     split TWICE (a party and an elicitation repair dir): two manifests, one document
#   <x>other/design-notes.md    the same basename in another directory, named by no manifest
#   wt/<x>docs/design-notes.md  the same relative path in another tree inside the project (BL-596's shape)
#   <state>/notes/handoff.md    a document INSIDE the state dir but outside planning-artifacts/, specs/s<N>/
#                               and the gate part files: the only input that enters the state-spelling branch
#   lnk -> <x>docs              a directory symlink, so one payload spells the document non-physically
# The workspace itself sits under TMPDIR (`/var/...` or `/tmp`, both links to `/private/...`), and the
# manifest records the physical path, so every absolute payload below is a non-physical spelling too.
# =============================================================================
PARTITION="$(pick "$HERE/../../scripts/partition-document.sh" \
                  "$HERE/../../../scripts/ai-dlc/partition-document.sh")"
[ -n "$PARTITION" ] || { echo "FIXTURE ERROR: cannot locate partition-document.sh; arm MD seeds its manifests with the real splitter" >&2; exit 2; }
md_doc() { printf '# %s\n\n## Goals\nThe first goal, in one line of prose.\nThe second goal, in one line of prose.\n\n## Scope\nThe first scope item, in one line of prose.\nThe second scope item, in one line of prose.\n\n## Risks\nThe first risk, in one line of prose.\nThe second risk, in one line of prose.\n' "$1"; }
md_world() { # <state rel> -> sets MD_W (bare call, never in $( ): a FIXTURE ERROR must stop the run)
  local s="$1" x="" w pa
  case "$s" in */*) x="${s%/*}/" ;; esac
  MD_W="$(mktemp -d "${TMPDIR:-/tmp}/grd-md.XXXXXX")" || { echo "FIXTURE ERROR: arm MD could not create a workspace" >&2; exit 2; }
  w="$MD_W"; pa="$w/$s/planning-artifacts/s5/shards"
  mkdir -p "$w/$s/notes" "$w/${x}docs" "$w/${x}other" "$w/wt/${x}docs" "$pa" || { echo "FIXTURE ERROR: arm MD mkdir failed" >&2; exit 2; }
  printf '# Pipeline Snapshot\n' > "$w/$s/pipeline-snapshot.md"
  md_doc "Design notes" > "$w/${x}docs/design-notes.md"
  cp "$w/${x}docs/design-notes.md" "$w/${x}other/design-notes.md"
  cp "$w/${x}docs/design-notes.md" "$w/wt/${x}docs/design-notes.md"
  md_doc "Handoff" > "$w/$s/notes/handoff.md"
  bash "$PARTITION" --split "$w/${x}docs/design-notes.md" "$pa/design-notes-party-repair-p1" >/dev/null 2>&1 \
    && bash "$PARTITION" --split "$w/${x}docs/design-notes.md" "$pa/design-notes-elicitation-repair-p1" >/dev/null 2>&1 \
    && bash "$PARTITION" --split "$w/$s/notes/handoff.md" "$pa/handoff-repair-p1" >/dev/null 2>&1 \
    || { echo "FIXTURE ERROR: arm MD: partition-document.sh --split failed; no manifest exists and every MD cell would read as recording nothing" >&2; exit 2; }
  ln -s "$w/${x}docs" "$w/lnk" || { echo "FIXTURE ERROR: arm MD could not create the directory symlink" >&2; exit 2; }
  # MD9's decoy: lnkup -> else/a, so `lnkup/..` is `else` to the kernel and the project root to the text,
  # and else/docs/design-notes.md is a document no manifest names.
  mkdir -p "$w/else/a" "$w/else/docs" && cp "$w/${x}docs/design-notes.md" "$w/else/docs/design-notes.md" \
    && ln -s "$w/else/a" "$w/lnkup" || { echo "FIXTURE ERROR: arm MD could not build MD9's decoy" >&2; exit 2; }
  MD_UP="$(cd -P "$w/lnkup/.." 2>/dev/null && pwd -P)"; MD_ELSE="$(cd -P "$w/else" 2>/dev/null && pwd -P)"
  MD_PROJ="$(cd -P "$w" 2>/dev/null && pwd -P)"
  # Two manifests name the document, by its physical path: the precondition of the one-row cell.
  MD_NMAN="$(awk -F'\t' -v d="$(cd -P "$w/${x}docs" && pwd -P)/design-notes.md" '$1 == "document" && $2 == d { n++ } END { print n + 0 }' "$pa"/*/sections/.manifest)"
}
md_cell() { # <ledger> <agent> -> "<rows>:<paths, space-joined>"
  [ -f "$1" ] || { printf '0:'; return; }
  printf '%s:%s' "$(jq -n --arg a "$2" '[inputs | select(.kind == "artifact-write" and .agent_id == $a)] | length' "$1" 2>/dev/null || printf ERR)" \
    "$(jq -r --arg a "$2" 'select(.kind == "artifact-write" and .agent_id == $a) | .path' "$1" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
}
md_run() { # <hook> [cells...] -> the requested MD cells (default all); a world is built only when one of its cells is requested
  local h="${1:-$HOOK}" L
  MD_WANT=" ${*:2} "; [ "$#" -ge 2 ] || MD_WANT=" MD1 MD2 MD3 MD4 MD5 MD6 MD9 MD9C MD7 MD8 "
  MD1=""; MD2=""; MD3=""; MD4=""; MD5=""; MD6=""; MD7=""; MD8=""; MD9=""; MD9C=""
  case "$MD_WANT" in *" MD1 "*|*" MD2 "*|*" MD3 "*|*" MD4 "*|*" MD5 "*|*" MD6 "*|*" MD9 "*|*" MD9C "*)
    md_world _bmad-output; MD_NMAN_D="$MD_NMAN"
    L="$MD_W/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
    case "$MD_WANT" in *" MD1 "*) drive "$MD_W" Edit "$MD_W/docs/design-notes.md" md1abs "" "$h" >/dev/null; MD1="$(md_cell "$L" md1abs)" ;; esac
    case "$MD_WANT" in *" MD2 "*) drive "$MD_W" Edit "docs/design-notes.md" md2rel "" "$h" "" "$MD_W" >/dev/null; MD2="$(md_cell "$L" md2rel)" ;; esac
    case "$MD_WANT" in *" MD3 "*) drive "$MD_W" Edit "$MD_W/lnk/design-notes.md" md3lnk "" "$h" >/dev/null; MD3="$(md_cell "$L" md3lnk)" ;; esac
    case "$MD_WANT" in *" MD4 "*) drive "$MD_W" Edit "$MD_W/other/design-notes.md" md4near "" "$h" >/dev/null; MD4="$(md_cell "$L" md4near)" ;; esac
    case "$MD_WANT" in *" MD5 "*) drive "$MD_W" Edit "$MD_W/wt/docs/design-notes.md" md5tree "" "$h" >/dev/null; MD5="$(md_cell "$L" md5tree)" ;; esac
    case "$MD_WANT" in *" MD6 "*) drive "$MD_W" Write "$MD_W/_bmad-output/notes/handoff.md" md6gap "" "$h" >/dev/null; MD6="$(md_cell "$L" md6gap)" ;; esac
    case "$MD_WANT" in *" MD9 "*) drive "$MD_W" Edit "$MD_W/lnkup/../docs/design-notes.md" md9up "" "$h" >/dev/null; MD9="$(md_cell "$L" md9up)" ;; esac
    case "$MD_WANT" in *" MD9C "*) drive "$MD_W" Edit "$MD_W/docs/design-notes.md" md9ctl "" "$h" >/dev/null; MD9C="$(md_cell "$L" md9ctl)" ;; esac
    MD_UP_D="$MD_UP"; MD_ELSE_D="$MD_ELSE"; MD_PROJ_D="$MD_PROJ"
    rm -rf "$MD_W" ;;
  esac
  case "$MD_WANT" in *" MD7 "*|*" MD8 "*)
    md_world x/_bmad-output; MD_NMAN_N="$MD_NMAN"
    L="$MD_W/x/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
    case "$MD_WANT" in *" MD7 "*) AI_DLC_STATE_DIR=x/_bmad-output drive "$MD_W" Edit "$MD_W/x/docs/design-notes.md" md7nest "" "$h" >/dev/null; MD7="$(md_cell "$L" md7nest)" ;; esac
    case "$MD_WANT" in *" MD8 "*) AI_DLC_STATE_DIR=x/_bmad-output drive "$MD_W" MultiEdit "$MD_W/x/_bmad-output/notes/handoff.md" md8gapn "" "$h" >/dev/null; MD8="$(md_cell "$L" md8gapn)" ;; esac
    rm -rf "$MD_W" ;;
  esac
}

MD1_W="1:docs/design-notes.md"; MD4_W="0:"; MD5_W="0:"; MD6_W="1:_bmad-output/notes/handoff.md"
MD7_W="1:x/docs/design-notes.md"; MD8_W="1:_bmad-output/notes/handoff.md"; MD9_W="0:"
md_run "$HOOK"
[ "$MD_NMAN_D" = 2 ] && [ "$MD_NMAN_N" = 2 ] || bad "MD-pre: FIXTURE BROKEN — the splitter wrote $MD_NMAN_D / $MD_NMAN_N manifests naming the document (want 2 / 2)"
# MD9 discriminates a physical from a textual `..` only where the two differ: the kernel must resolve
# lnkup/.. to else/, never to the project root. Without that the cell reads 0: under either resolution.
[ -n "$MD_UP_D" ] && [ "$MD_UP_D" = "$MD_ELSE_D" ] && [ "$MD_UP_D" != "$MD_PROJ_D" ] \
  && ok "MD9-pre: the kernel resolves lnkup/.. to the decoy's parent ($MD_UP_D), not the project root" \
  || bad "MD9-pre: FIXTURE BROKEN — lnkup/.. resolved to '$MD_UP_D' (want '$MD_ELSE_D', not '$MD_PROJ_D'); MD9 cannot discriminate"
if [ "$MD1" = "$MD1_W" ]; then ok "MD1: one absolute write to a document TWO split manifests name -> exactly ONE row, project-relative ($MD1)"
else bad "MD1: the sections document recorded '$MD1' (want '$MD1_W')"; fi
[ "$MD2" = "$MD1_W" ] && ok "MD2: the same document by a RELATIVE payload path -> ONE row, the same spelling" \
  || bad "MD2: the relative spelling recorded '$MD2' (want '$MD1_W')"
[ "$MD3" = "$MD1_W" ] && ok "MD3: the same document through a directory symlink -> ONE row, the same spelling (the directory is resolved physically)" \
  || bad "MD3: the symlinked spelling recorded '$MD3' (want '$MD1_W')"
if [ "$MD4" = "$MD4_W" ]; then ok "MD4: the same BASENAME in another directory, named by no manifest -> NO row (MD1 is its twin)"
else bad "MD4: a same-basename near-miss recorded '$MD4'"; fi
if [ "$MD5" = "$MD5_W" ]; then ok "MD5: the same RELATIVE path in another tree inside the project (BL-596) -> NO row"
else bad "MD5: the other-tree near-miss recorded '$MD5'"; fi
if [ "$MD6" = "$MD6_W" ]; then ok "MD6: a manifest's document INSIDE the state dir outside planning-artifacts/ -> ONE row in the state spelling ($MD6)"
else bad "MD6: the in-state document recorded '$MD6' (want '$MD6_W')"; fi
if [ "$MD7" = "$MD7_W" ]; then ok "MD7: AI_DLC_STATE_DIR=x/_bmad-output, the document at x/docs/ -> ONE row, project-relative ($MD7), never relative to the state dir's parent"
else bad "MD7: the nested-layout document recorded '$MD7' (want '$MD7_W')"; fi
if [ "$MD8" = "$MD8_W" ]; then ok "MD8: nested, a document inside the state dir outside planning-artifacts/ -> the state-spelling branch: '$MD8', not x/_bmad-output/..."
else bad "MD8: the nested in-state document recorded '$MD8' (want '$MD8_W')"; fi
if [ "$MD9" = "$MD9_W" ]; then ok "MD9: a payload <project>/lnkup/../docs/design-notes.md, which the kernel writes to else/docs/, -> NO row"
else bad "MD9: the lnkup/.. payload recorded '$MD9' (the kernel writes the decoy else/docs/design-notes.md)"; fi
if [ "$MD9C" = "$MD1_W" ]; then ok "MD9-ctl: the same run's direct <project>/docs/design-notes.md write -> ONE row ($MD9C)"
else bad "MD9-ctl: the direct write recorded '$MD9C' (want '$MD1_W')"; fi

# =============================================================================
# ARM 3b — THE LEAD'S PRODUCT EDIT, with NO gate directory at all. Every DENY cell has an
# ALLOW twin one property apart, and every conjunct has a mutant that kills its own cell
# while a cell it must not reach stays put.
# =============================================================================
# A pre-push run exports GIT_DIR into this process; the hook's `git worktree list` must ask
# about the seeded repo, which is what a consumer session (no GIT_DIR) asks about.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
seed product
SIB="$W.sib"
TA="$W/sessions-jsonl/aidlc.jsonl"; TP="$W/sessions-jsonl/plain.jsonl"; TU="$W/sessions-jsonl/updater.jsonl"
[ -d "$SIB/src" ] && [ ! -d "$W/_bmad-output/gate-adjudication" ] \
  || { echo "FIXTURE ERROR: seed 'product' has no sibling worktree, or HAS a gate directory" >&2; exit 2; }
lpe() { # <expect deny|allow> <label> <file_path> [transcript] [agent] [hook]
  local o; o="$(drive "$W" Edit "$3" "${5:-}" "${4:-}" "${6:-$HOOK}")"
  if [ "$1" = deny ]; then
    if denied "$o"; then ok "$2"; else bad "$2"; fi
  else
    if denied "$o"; then bad "$2"; else ok "$2"; fi
  fi
}

OUT="$(drive "$W" Edit "$W/src/app.py" "" "$TA")"
if denied "$OUT"; then
  ok "3b: a lead Edit to src/app.py in an /ai-dlc session with NO gate directory is DENIED"
  case "$OUT" in *"THE LEAD DOES NOT EDIT PRODUCT CODE"*) ok "3b: ...by arm 3b, not by a gate arm" ;;
    *) bad "3b: the deny is not arm 3b's — a gate arm fired with no gate directory" ;; esac
  case "$OUT" in *'`dev` teammate'*dev-escalated*) ok "3b: the deny names the dev seat (dev / dev-escalated)" ;;
    *) bad "3b: the deny does not name the dev seat to dispatch" ;; esac
  case "$OUT" in *'Rule 28: \"The lead MUST delegate any action a subagent can service.\"'*) ok "3b: the deny quotes Rule 28" ;;
    *) bad "3b: the deny does not quote Rule 28" ;; esac
else
  bad "3b: lead product Edit ALLOWED in an /ai-dlc session — the 8 measured edits walk through"
  bad "  (by-arm-3b)"; bad "  (names-dev-seat)"; bad "  (quotes-rule-28)"
fi
lpe deny  "3b: a RELATIVE src/app.py is the same file and DENIED"                         "src/app.py" "$TA"
lpe allow "3b: the same edit in a session with NO /ai-dlc invocation (only a mention) is ALLOWED" "$W/src/app.py" "$TP"
lpe allow "3b: the same edit with no transcript at all is ALLOWED"                         "$W/src/app.py" ""
lpe allow "3b: the same edit after a later /ai-dlc-update invocation is ALLOWED (last skill decides)" "$W/src/app.py" "$TU"
lpe allow "3b: a dispatched teammate's identical product Edit is ALLOWED"                  "$W/src/app.py" "$TA" "a1b2c3"
lpe allow "3b: a scratchpad path outside every tree is ALLOWED"                            "$W.scratch/notes.md" "$TA"
lpe allow "3b: a sibling worktree's _bmad-output/ path is ALLOWED"                         "$SIB/_bmad-output/planning-artifacts/x.md" "$TA"
lpe deny  "3b: a sibling worktree's src/app.py is DENIED (the worktree is the repo's tree)" "$SIB/src/app.py" "$TA"
lpe allow "3b: docs/coding-conventions.md is ALLOWED"                                     "$W/docs/coding-conventions.md" "$TA"
lpe allow "3b: a repo-root dotfile (.gitignore) is ALLOWED"                               "$W/.gitignore" "$TA"
lpe deny  "3b: a dotfile NOT at the repo root (src/.env) is DENIED"                        "$W/src/.env" "$TA"
lpe allow "3b: a file carrying a <<<<<<< conflict marker is ALLOWED (Rule 28(a))"         "$W/src/conflict.py" "$TA"
# Retro Step 4 tells the lead to edit repo-root CLAUDE.md; a nested one is not that file.
lpe allow "3b: repo-root CLAUDE.md (retro Step 4 sends the lead there) is ALLOWED"         "$W/CLAUDE.md" "$TA"
lpe allow "3b: repo-root AGENTS.md is ALLOWED"                                             "$W/AGENTS.md" "$TA"
lpe deny  "3b: a CLAUDE.md NOT at the repo root (src/CLAUDE.md) is DENIED"                 "$W/src/CLAUDE.md" "$TA"
# `..` through a directory that does NOT exist must not keep the allowed prefix.
[ ! -e "$W/docs/nx" ] || bad "3b: seed precondition — docs/nx must not exist for the traversal cell"
lpe deny  "3b: docs/nx/../../src/app.py (nx absent) is src/app.py and DENIED"             "$W/docs/nx/../../src/app.py" "$TA"
lpe deny  "3b: relative _bmad-output/nx/../../src/app.py is DENIED"                         "_bmad-output/nx/../../src/app.py" "$TA"
lpe allow "3b: src/../docs/x.md (a .. that lands in docs/) is ALLOWED"                      "$W/src/../docs/x.md" "$TA"
# A resolver that HANGS must not hang the edit: the bounded wait gives up and adds no roots.
mkdir -p "$W.hang/scripts/ai-dlc"
cp -R "$W/." "$W.hang/" 2>/dev/null
# THE HUNG RESOLVER IS ONE PROCESS BLOCKED ON A FIFO THE FIXTURE OPENS ONLY AFTER THE VERDICT (BL-868).
# It records its pid, blocks in `read` on a fresh fifo, and -- only if it is ever released -- writes a
# `released` marker. Nothing but a signal ends it before the fixture releases it, so no elapsed time
# can stand in for the hook's bound (an `exec sleep 600` target ended by itself once 600s passed).
#
# THE VERDICT IS BINARY, NEVER A WALL-CLOCK FIGURE. The hook gives up after LPE_RESOLVER_TICKS ticks,
# an iteration bound. The proof that the bound fired: the edit is DENIED, the resolver's recorded pid
# is DEAD, and its marker is ABSENT -- it was killed, not released. A hook with no bound would wait on
# the resolver forever, and hd_run detects that as a FACT, never a timeout: the resolver and the hook
# both blocked with no signal pending and the hook holding no other live child (its watcher gone).
# Only then is the fifo released, so a hung hook is reported as a verdict instead of wedging the run.
hd_blocked() { # <pid>: alive, in state S/I/T, no signal pending
  local st pd
  kill -0 "$1" 2>/dev/null || return 1
  st="$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')"; pd="$(ps -o pending= -p "$1" 2>/dev/null | tr -d ' ')"
  [ -n "$st" ] || return 1
  case "$st" in S*|I*|T*) ;; *) return 1 ;; esac
  case "$pd" in ''|*[!0]*) return 1 ;; esac
}
HD="$W.hang.hd"; mkdir -p "$HD"
hd_run() { # <hook> <tag> -> HD_OUT, HD_PID, HD_HUNG (1: seen waiting on the blocked resolver), HD_REL (1: marker)
  local h="$1" f="$HD/$2.fifo" pf="$HD/$2.pid" mk="$HD/$2.released" dp r hp k st kids
  rm -f "$pf" "$mk" "$f"; mkfifo "$f" && [ -p "$f" ] || { echo "FIXTURE ERROR: cannot make $f" >&2; exit 2; }
  printf '#!/bin/bash\necho "$$" > "%s"\nread -r _ < "%s"\necho released > "%s"\n' "$pf" "$f" "$mk" > "$W.hang/scripts/ai-dlc/artifact-path-config.sh"
  drive "$W.hang" Edit "$W.hang/src/app.py" "" "$TA" "$h" > "$HD/$2.out" &
  dp=$!
  HD_HUNG=0
  while kill -0 "$dp" 2>/dev/null; do
    r="$(cat "$pf" 2>/dev/null)"
    case "$r" in ''|*[!0-9]*) sleep 0.05; continue ;; esac
    hp="$(ps -o ppid= -p "$r" 2>/dev/null | tr -d ' ')"
    # ORDER IS THE PROOF. The watcher is read gone FIRST, and the resolver blocked with nothing pending
    # AFTER: a watcher that left by killing the resolver has already sent the signal, so from then on
    # the resolver is dead, exiting or carries it pending -- never read blocked. Read the other way
    # round, the resolver's state could predate a kill the watcher then made, at any load.
    [ -n "$hp" ] || { sleep 0.05; continue; }
    kids=0
    for k in $(pgrep -P "$hp" 2>/dev/null); do
      [ "$k" = "$r" ] && continue
      st="$(ps -o stat= -p "$k" 2>/dev/null)"; case "$st" in ''|*Z*) ;; *) kids=$((kids + 1)) ;; esac
    done
    if [ "$kids" = 0 ] && hd_blocked "$r" && hd_blocked "$hp"; then HD_HUNG=1; break; fi
    sleep 0.05
  done
  exec 9<>"$f"; exec 9>&-
  wait "$dp"
  HD_OUT="$(cat "$HD/$2.out")"; HD_PID="$(cat "$pf" 2>/dev/null)"
  HD_REL=0; [ -f "$mk" ] && HD_REL=1
  return 0
}
hd_run "$HOOK" base
if denied "$HD_OUT" && [ "$HD_HUNG" = 0 ]; then ok "3b: a hung scan-roots resolver is abandoned and the product edit is still DENIED"
else bad "3b: a hung scan-roots resolver: the product edit was not DENIED by a hook that gave up (hung=$HD_HUNG)"; fi
# THE RESOLVER IS GONE, by the pid it recorded -- never by a process-table grep -- and it was KILLED:
# its marker is absent, so the fifo release after the verdict is not what ended it. A missing pid file
# means the resolver never ran, and then the bound above was never exercised.
case "$HD_PID" in
  ''|*[!0-9]*) bad "3b: the hung resolver never recorded its pid, so the bound above was never exercised" ;;
  *) if kill -0 "$HD_PID" 2>/dev/null; then
       kill "$HD_PID" 2>/dev/null
       bad "3b: the hung resolver (pid $HD_PID) was still alive after the hook returned -- abandoned but not reaped"
     elif [ "$HD_REL" = 1 ]; then
       bad "3b: the hung resolver (pid $HD_PID) ended only when the fixture released it -- the hook's bound never ended it"
     else ok "3b: the hung resolver (pid $HD_PID) was ended by the hook's bound and reaped, not left running"
     fi ;;
esac

# (iv) IS ONE RULE: the `LAST_SKILL=` statement and its `case` are byte-identical in this hook
# and `ai-dlc-acknowledge.sh`. Both directions: the two shipped blocks agree, and a one-byte
# drift in a copy is reported.
ACK="$(pick "$HERE/../../hooks/ai-dlc-acknowledge.sh" \
            "$HERE/../../../.claude/hooks/ai-dlc-acknowledge.sh" \
            "$HERE/../../../core/hooks/ai-dlc-acknowledge.sh")"
skill_block() { sed -n '/^  LAST_SKILL=/,/^  esac$/p' "$1"; }
if [ -z "$ACK" ]; then bad "3b-bind: cannot locate ai-dlc-acknowledge.sh"
else
  B_ACK="$(skill_block "$ACK")"; B_HOOK="$(skill_block "$HOOK")"
  if [ -z "$B_ACK" ] || [ "$(printf '%s\n' "$B_ACK" | wc -l | tr -d ' ')" -lt 7 ]; then
    bad "3b-bind: no 7-line LAST_SKILL block extracted from ai-dlc-acknowledge.sh — the binding is vacuous"
  elif [ "$B_ACK" = "$B_HOOK" ]; then ok "3b-bind: the session-class scan is byte-identical in both hooks"
  else bad "3b-bind: the session-class scan has FORKED between ai-dlc-acknowledge.sh and this hook"; fi
fi

git -C "$W" worktree remove --force "$SIB" >/dev/null 2>&1
rm -rf "$W" "$SIB" "$W.hang" "$W.hang.hd"

# =============================================================================
# ARM RR -- THE REPAIR RECORD'S FIELD GRAMMAR IS THE PROJECT'S ONE REPAIR-RECORD GRAMMAR (BL-989).
# =============================================================================
# Lift arm 8 reads `remediator_agent_id` and `repaired_checks` through `repair_value` / `repair_list`,
# arm H's reader in `validate-adversarial-convergence.sh`. A remediator following its own role file
# writes bullets, and the column-0-only reader this replaced read a `- repaired_checks: 3` row as no
# row at all, so a genuine repair left the lead locked out. Cells, each presence-shaped (a deny must
# log its named reason; a lift must log GATE_REMEDIATION_LIFTED), each driven in a FRESH copy of one
# never-driven base workspace:
#   RR-A  bullet rows lift            RR-A2 emphasised labels lift      RR-C  remediator.md's own example lifts
#   RR-D1 a `> ` blockquote with genuine values does not lift (`>` is not in the prefix class)
#   RR-D2 a prose row `- the remediator_agent_id:` does not lift (the label must lead the row)
#   RR-D3 a renamed label `- repaired_check:` does not lift
#   RR-D4 a bullet record whose agent id is in no dispatch does not lift (corroboration binds)
#   RR-D5 a bullet record for another nonce does not lift (the nonce binds)
#   RR-D6 `none available (...)` fails the shape floor; RR-D6-allow, a real id plus a parenthetical, lifts
#   RR-E-deny / RR-E-lift  the FIRST row bearing a label is the one read, in both orders
#   RR-arm4 arm 4's own column-0 forgery, re-driven here so its corroboration mutant has a cell
# The transcript names `none` on purpose: first-token extraction turns the s322 prose into `none`,
# so the floor, not corroboration, is the only guard RR-D6 has -- and RR-D4/RR-arm4's id passes the
# floor, so corroboration is the only guard they have. Each guard has a subject the other cannot see.
# RR-B binds the two readers to the validator's bytes; RR-C-window holds the consumer window, where an
# installed remediator.md older than this release carries no example and RR-C prints PENDING.
# M-allrows: with the first-match `exit` gone a record with two rid rows makes the rid a
# newline-separated value, which `grep -qF` then reads as a PATTERN LIST -- any one line corroborates.
RR_N_REC="_bmad-output/gate-adjudication/story-20260811T193044Z.repair.md"
RR_NONCE="story-20260811T193044Z"
RR_VAL="$(pick "$HERE/../../scripts/validate-adversarial-convergence.sh" \
               "$HERE/../../../scripts/ai-dlc/validate-adversarial-convergence.sh")"
[ -n "$RR_VAL" ] || { echo "FIXTURE BROKEN: cannot locate validate-adversarial-convergence.sh in either layout (core/scripts/, scripts/ai-dlc/); RR-B would bind nothing" >&2; exit 2; }
RR_DOC=""; RR_LAYOUT=""
if [ -f "$HERE/../../team-roles/remediator.md" ]; then RR_DOC="$HERE/../../team-roles/remediator.md"; RR_LAYOUT=core
elif [ -f "$HERE/../../../.claude/team-roles/remediator.md" ]; then RR_DOC="$HERE/../../../.claude/team-roles/remediator.md"; RR_LAYOUT=claude; fi
[ -n "$RR_DOC" ] || { echo "FIXTURE BROKEN: cannot locate remediator.md in either layout (core/team-roles/, .claude/team-roles/); RR-C would read nothing" >&2; exit 2; }
echo "gate-remediation-deny: RR validator = $RR_VAL; RR role file = $RR_DOC ($RR_LAYOUT layout)"
RR="$(mktemp -d)"


# --- RR-B: one grammar, by bytes. ------------------------------------------------------------
rr_fn()    { awk '/^repair_value\(\) \{/,/^\}/' "$1"; }
rr_valm()  { rr_fn "$1" | grep -F 'match($0, '; }
rr_listm() { awk '/^repair_list\(\) \{/,/^\}/' "$1" | grep -F 'match($0, '; }
rr_bind() { # <hook copy> -> RR_BV (1: repair_value byte-identical), RR_BL (1: repair_list's match line is repair_value's)
  local a b
  RR_BV=0; RR_BL=0
  a="$(rr_fn "$1")"; b="$(rr_fn "$RR_VAL")"
  [ -n "$a" ] && [ "$a" = "$b" ] && RR_BV=1
  a="$(rr_listm "$1")"; b="$(rr_valm "$RR_VAL")"
  [ -n "$a" ] && [ "$(printf '%s\n' "$a" | wc -l | tr -d ' ')" = 1 ] && [ "$a" = "$b" ] && RR_BL=1
  return 0
}
n_hv="$(grep -c '^repair_value() {' "$HOOK")" || n_hv=0
n_vv="$(grep -c '^repair_value() {' "$RR_VAL")" || n_vv=0
n_hl="$(grep -c '^repair_list() {' "$HOOK")" || n_hl=0
n_vm="$(rr_valm "$RR_VAL" | wc -l | tr -d ' ')"
n_fl="$(rr_fn "$RR_VAL" | wc -l | tr -d ' ')"
if [ "$n_hv" = 1 ] && [ "$n_vv" = 1 ] && [ "$n_hl" = 1 ] && [ "$n_vm" = 1 ] && [ "$n_fl" -ge 5 ]; then
  ok "RR-B-pre: exactly one repair_value definition in the hook and in the validator, one repair_list, one match line ($n_fl-line body)"
  rr_bind "$HOOK"
  if [ "$RR_BV" = 1 ]; then ok "RR-B-value: the hook's repair_value is byte-identical to validate-adversarial-convergence.sh's"
  else bad "RR-B-value: the hook's repair_value has FORKED from validate-adversarial-convergence.sh's"; fi
  if [ "$RR_BL" = 1 ]; then ok "RR-B-list: repair_list's match line is repair_value's, byte for byte"
  else bad "RR-B-list: repair_list reads rows by a different match line than repair_value"; fi
else
  bad "RR-B-pre: FIXTURE BROKEN: want one repair_value in each file, one repair_list and one match line (hook $n_hv, validator $n_vv, repair_list $n_hl, match lines $n_vm, body $n_fl lines)"
fi

# --- RR-C's source: remediator.md's own example block, as the producer is told to write it. -----
rr_block() { # <role file> -> the fenced block after the gate repair record paragraph
  awk '/^\*\*A gate repair record carries/ { p = 1; next }
       p == 1 && /^```/ { p = 2; next }
       p == 2 && /^```/ { exit }
       p == 2 { print }' "$1"
}
rr_cstate() { # <role file> <layout core|claude> -> RR_CSTATE ok|PENDING|FAIL, RR_CBLOCK
  RR_CBLOCK="$(rr_block "$1")"
  if [ "$(printf '%s\n' "$RR_CBLOCK" | grep -c .)" = 3 ] \
     && case "$RR_CBLOCK" in *'<live gate nonce>'*) true ;; *) false ;; esac \
     && case "$RR_CBLOCK" in *'<your agent id>'*) true ;; *) false ;; esac \
     && case "$RR_CBLOCK" in *'<check id>'*) true ;; *) false ;; esac; then RR_CSTATE=ok
  elif [ "$2" = claude ] && ! grep -q 'remediator_agent_id' "$1" 2>/dev/null; then RR_CSTATE=PENDING
  else RR_CSTATE=FAIL; fi
}
rr_csub() { printf '%s\n' "$1" | sed -e "s/<live gate nonce>/$RR_NONCE/" -e 's/<your agent id>/remediator@session-abc123/' -e 's/<check id>/7/'; }
# RR-C-window: a role file older than the example (no remediator_agent_id token) is PENDING only in the
# installed layout; in core/ it is FAIL; and the real file is ok. Seeded, both directions, before the real read.
printf '# Remediator\n\n## Contract\nRepair what the gate names.\n' > "$RR/legacy-remediator.md"
rr_cstate "$RR/legacy-remediator.md" claude; _w1="$RR_CSTATE"
rr_cstate "$RR/legacy-remediator.md" core;   _w2="$RR_CSTATE"
if [ "$_w1" = PENDING ] && [ "$_w2" = FAIL ]; then ok "RR-C-window: a legacy installed remediator.md reads PENDING in .claude/, the same text reads FAIL in core/"
else bad "RR-C-window: legacy role file read [$_w1] in .claude/ and [$_w2] in core/ (want PENDING, FAIL)"; fi
rr_cstate "$RR_DOC" "$RR_LAYOUT"
RR_CREC=""
case "$RR_CSTATE" in
  ok) RR_CREC="$(rr_csub "$RR_CBLOCK")"; ok "RR-C-extract: remediator.md's gate repair record example is three lines carrying the three placeholders" ;;
  PENDING) printf '  PENDING: RR-C -- the installed %s carries no remediator_agent_id example yet (role text older than the engine); RR-C waits for the reconcile merge\n' "$RR_DOC" ;;
  *) bad "RR-C-extract: no three-line gate repair record example after remediator.md's 'A gate repair record carries' paragraph -- the documented form is unpinned" ;;
esac

rr_rec() { # <cell> -> the record text
  local h="# Gate repair record" n="$RR_NONCE"
  case "$1" in
    RR-A)        printf '%s\n- gate_nonce: %s\n- remediator_agent_id: remediator@session-abc123\n- repaired_checks: 7, 3a\n' "$h" "$n" ;;
    RR-A2)       printf '%s\n- **gate_nonce:** %s\n**remediator_agent_id**: remediator@session-abc123\n- **repaired_checks:** 7\n' "$h" "$n" ;;
    RR-C)        printf '%s\n' "$RR_CREC" ;;
    RR-D1)       printf '%s\n> gate_nonce: %s\n> remediator_agent_id: remediator@session-abc123\n> repaired_checks: 7, 3a\n' "$h" "$n" ;;
    RR-D2)       printf '%s\n- gate_nonce: %s\n- the remediator_agent_id: remediator@session-abc123\n- repaired_checks: 7, 3a\n' "$h" "$n" ;;
    RR-D3)       printf '%s\n- gate_nonce: %s\n- remediator_agent_id: remediator@session-abc123\n- repaired_check: 7\n' "$h" "$n" ;;
    RR-D4)       printf '%s\n- gate_nonce: %s\n- remediator_agent_id: remediator@session-never-dispatched-9\n- repaired_checks: 7\n' "$h" "$n" ;;
    RR-D5)       printf '%s\n- gate_nonce: story-20260810T101010Z\n- remediator_agent_id: remediator@session-abc123\n- repaired_checks: 7, 3a\n' "$h" ;;
    RR-D6)       printf '%s\n- gate_nonce: %s\n- remediator_agent_id: none available (no spawn-ledger.jsonl was written for this dispatch)\n- repaired_checks: 7\n' "$h" "$n" ;;
    RR-D6-allow) printf '%s\n- gate_nonce: %s\n- remediator_agent_id: a02970b6937a11032 (supplied by the lead after the fact; the dispatch transcript shows it)\n- repaired_checks: 7\n' "$h" "$n" ;;
    RR-E-deny)   printf '%s\ngate_nonce: %s\nremediator_agent_id: remediator@session-abc123\n- repaired_checks: 2\nrepaired_checks: 7\n' "$h" "$n" ;;
    RR-E-lift)   printf '%s\ngate_nonce: %s\nremediator_agent_id: remediator@session-abc123\nrepaired_checks: 7\n- repaired_checks: 2\n' "$h" "$n" ;;
    RR-arm4)     printf 'gate_nonce: %s\nremediator_agent_id: remediator@session-never-dispatched-9\nrepaired_checks: 7\n' "$n" ;;
    *) return 1 ;;
  esac
}
rr_want() { # <cell> -> "<lift|deny>|<reason the log must carry>"
  case "$1" in
    RR-A|RR-A2|RR-C|RR-D6-allow|RR-E-lift) echo "lift|Lifted by repair record" ;;
    RR-D1|RR-D2)        echo "deny|: no remediator_agent_id" ;;
    RR-D3|RR-E-deny)    echo "deny|repaired_checks names none of the live FAILs" ;;
    RR-D4|RR-arm4)      echo "deny|remediator_agent_id 'remediator@session-never-dispatched-9' appears in NO dispatch" ;;
    RR-D5)              echo "deny|No bound remediator repair record and no verified operator authorization" ;;
    RR-D6)              echo "deny|remediator_agent_id 'none' is not an agent id" ;;
  esac
}

# The base: open-fail (live FAILs 7 and 3a, check 2 PASS), a transcript that dispatched
# remediator@session-abc123 and a02970b6937a11032 and mentions `none`, never driven.
seed open-fail
RR_BASE="$W"
printf '%s\n' '{"type":"assistant","content":"dispatching"}' '{"agent_id":"remediator@session-abc123"}' \
  '{"type":"user","content":"spawn ledger: none"}' '{"agent_id":"a02970b6937a11032"}' > "$RR_BASE/transcript.jsonl"
RR_N=0
rr_drive() { # <cell> <hook> -> RR_V lift|deny, RR_LOG; rc 2 when BROKEN (a crash, or an allow with no lift logged)
  local w o rc
  RR_N=$((RR_N + 1)); w="$RR/d$RR_N"
  cp -R "$RR_BASE" "$w" && rr_rec "$1" > "$w/$RR_N_REC" || { bad "$1 -- FIXTURE BROKEN: the cell's workspace could not be built"; return 2; }
  o="$(drive "$w" Edit "$w/$ART" "" "$w/transcript.jsonl" "$2")"; rc=$?
  RR_LOG="$(cat "$w/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)"
  [ "$rc" -eq 0 ] || { bad "$1 -- FIXTURE BROKEN: $(basename "$2") exited rc=$rc (a crash, not a verdict)"; return 2; }
  if denied "$o"; then
    case "$RR_LOG" in *GATE_REMEDIATION_DENIED*) RR_V=deny ;; *) bad "$1 -- FIXTURE BROKEN: denied with no GATE_REMEDIATION_DENIED logged"; return 2 ;; esac
  else
    case "$RR_LOG" in *GATE_REMEDIATION_LIFTED*) RR_V=lift ;; *) bad "$1 -- FIXTURE BROKEN: allowed with no GATE_REMEDIATION_LIFTED logged; a silent exit 0 is not a lift"; return 2 ;; esac
  fi
  return 0
}

# --- the unmutated cells. Each must give its verdict AND log its own reason. --------------------
for rr_c in RR-A RR-A2 RR-C RR-D1 RR-D2 RR-D3 RR-D4 RR-D5 RR-D6 RR-D6-allow RR-E-deny RR-E-lift RR-arm4; do
  [ "$rr_c" = RR-C ] && [ "$RR_CSTATE" != ok ] && continue
  _w="$(rr_want "$rr_c")"
  rr_drive "$rr_c" "$HOOK" || continue
  case "$RR_LOG" in *"${_w#*|}"*) _r=1 ;; *) _r=0 ;; esac
  if [ "$RR_V" = "${_w%%|*}" ] && [ "$_r" = 1 ]; then
    ok "$rr_c: $( [ "$RR_V" = lift ] && echo LIFTS || echo 'does NOT lift') -- logged [${_w#*|}]"
  else bad "$rr_c: verdict $RR_V, reason logged=$_r (want ${_w%%|*} with [${_w#*|}])"; fi
done

# --- BL-989's receipt, against the hook and validator this unit resolved.
_rb="$(bash "$HERE/receipt-bl989.sh" "$HOOK" "$RR_VAL" 2>&1)"; _rbrc=$?
[ "$_rbrc" = 0 ] && ok "receipt-bl989.sh passes: a bound bullet record lifts and repair_value is the validator's, byte for byte" \
  || bad "receipt-bl989.sh exited $_rbrc: $(printf '%s\n' "$_rb" | grep FAIL | tr '\n' ' ')"

rm -rf "$RR" "$RR_BASE"

[ -n "$GRD_DECOY" ] && rm -rf "$GRD_DECOY"


echo
if [ "$fails" -eq 0 ]; then echo "gate-remediation-deny: PASS"; exit 0; fi
echo "gate-remediation-deny: $fails assertion(s) FAILED" >&2
exit 1
