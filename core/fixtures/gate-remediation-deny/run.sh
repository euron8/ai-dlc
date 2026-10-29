#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# THE MUTANT MATRIX. Every mutant below is scored on its DECIDING cell plus one named TWIN on a plain run (what the hook
# and hermetic-run.sh run); `--matrix` also drives every other cell a mutant has and prints one `MATRIX <mutant> <cell>`
# row each. The rows were measured from ONE `--matrix` run of this file from the repo root, and the fixture arm
# `MX:` fails a plain run that executed any matrix-only cell. Re-measure whenever an arm or a mutant is added or changed,
# and re-measure invocations.decl beside it. Several mutants also move cells outside their decides set (a wrong fix that
# is seen by more than one arm): m11 moves forged-clean-leadwrite; wms moves W7; m-fallback-live-alone moves AD-IW-UNPARSE;
# m-unsafe-live-alone moves AD-UNREADABLE, AD-IW-SPACE, AD-IW-NEWLINE and AD-IW-DASH; m-unsafe-dropped moves AD-IW-NEWLINE
# and AD-IW-DASH; m-stems-wordsplit moves AD-NEWLINE, AD-A-SPACE, AD-B-SPACE and AD-W4-SPACE; m-multidoc-drops moves
# AD-A-MULTIDOC and AD-B-MULTIDOC; m-stream-bleed moves AD-TRAIL-LIVE; m1b-role-nothing moves 1b-E2, 1b-E3 and 1b-E4;
# m1b-path-widened moves 1b-A10, 1b-A11 and 1b-A12; m1b-inner-widened moves 1b-A11 and 1b-A12; m1b-absent-denies moves
# 1b-A7; m1b-key-order moves 1b-A8; md-basename moves MD5 and MD9; md-suffix moves MD9. A cell id is the seed case the
# cell drives, or the named arm. Every cell of a mutant that a plain run does not drive is matrix-only.
# MUTANT-MATRIX m-existence-only decides=arm9 twins=arm7
# MUTANT-MATRIX m-no-probe-root decides=probe-ledger twins=spawn-ledger
# MUTANT-MATRIX M10 decides=S13a twins=S13-std
# MUTANT-MATRIX FLOOR-m-both-layers decides=7b-padded twins=7b-whole
# MUTANT-MATRIX m1-no-subtract decides=suppressed twins=suppressed-partial
# MUTANT-MATRIX m5-any-suppression-lifts decides=suppressed-partial twins=suppressed
# MUTANT-MATRIX m6b-key-drops-verifier decides=changed-verifier twins=suppressed
# MUTANT-MATRIX m6-key-drops-escalations decides=emptied-escalations twins=suppressed
# MUTANT-MATRIX m8-no-cite-verification decides=suppressed-forged twins=suppressed
# MUTANT-MATRIX m9-substring-join decides=suppressed-superset twins=suppressed
# MUTANT-MATRIX m2-no-catalog-join decides=suppressed-wrongcat twins=suppressed
# MUTANT-MATRIX m3-bare-is-wildcard decides=suppressed-bare twins=suppressed
# MUTANT-MATRIX m4-absence-is-coverage decides=suppressed-nosibling twins=suppressed
# MUTANT-MATRIX m7-ignore-sibling-rc decides=status twins=verdict,suppressed
# MUTANT-MATRIX wmp-no-kind-partition decides=W10 twins=W9
# MUTANT-MATRIX wme-string-equality decides=W10 twins=W9
# MUTANT-MATRIX wms-substitute-waives decides=W11 twins=W9
# MUTANT-MATRIX wmj-no-waiver-join decides=W2 twins=W1
# MUTANT-MATRIX m11-window-ignores-order decides=forged-clean twins=stale-then-clean
# MUTANT-MATRIX m12-records-every-writer decides=forged-clean-leadwrite twins=stale-then-clean
# MUTANT-MATRIX m13-arm-unreachable decides=fast-path twins=stale-then-clean
# MUTANT-MATRIX m14-write-never-binds decides=forged-clean-bound twins=stale-then-clean
# MUTANT-MATRIX m15-window-unbounded decides=forged-clean-latewindow twins=stale-then-clean
# MUTANT-MATRIX m16-nobound-acquits decides=forged-clean-nobound twins=stale-then-clean
# MUTANT-MATRIX m-fallback-live-alone decides=AD-UNPARSEABLE twins=suppressed-forged-bound
# MUTANT-MATRIX m-unsafe-live-alone decides=AD-DASH twins=suppressed-forged-bound
# MUTANT-MATRIX m-unsafe-dropped decides=AD-IW-SPACE twins=suppressed-forged-bound
# MUTANT-MATRIX m-stems-wordsplit decides=AD-SPACE twins=suppressed-forged-bound
# MUTANT-MATRIX m-multidoc-drops decides=AD-CONVICT-MULTIDOC twins=suppressed-forged-bound
# MUTANT-MATRIX m-nonobj-acquits decides=AD-IW-NONOBJ twins=suppressed-forged-bound
# MUTANT-MATRIX m-empty-doc-acquits decides=AD-IW-ZERO twins=suppressed-forged-bound
# MUTANT-MATRIX m-stream-bleed decides=AD-TRAIL-BOUND twins=suppressed-forged-bound
# MUTANT-MATRIX m-join-drops decides=AD-IW-UNPARSE twins=suppressed-forged-bound
# MUTANT-MATRIX m-livecl-only decides=suppressed-forged-unbound twins=subst-newer-unbound-fail
# MUTANT-MATRIX m-subst-no-failset decides=suppressed-forged-unbound twins=subst-convict-own
# MUTANT-MATRIX m-subst-bound-only decides=subst-crossgate twins=suppressed-forged-unbound
# MUTANT-MATRIX m-subst-boundcat decides=subst-percatalog twins=suppressed-forged-unbound
# MUTANT-MATRIX m-dguard-nostrip decides=name-strip twins=- why=a static binding probe with one cell, which its mutation always trips
# MUTANT-MATRIX m1b-key-order-bind decides=1b-bind twins=- why=a static binding probe with one cell, which its mutation always trips
# MUTANT-MATRIX m-3b-drift decides=3b-bind twins=- why=a static binding probe with one cell, which its mutation always trips
# MUTANT-MATRIX m1b-role-nothing decides=1b-E1 twins=1b-A1
# MUTANT-MATRIX m1b-path-widened decides=1b-A4 twins=1b-A1
# MUTANT-MATRIX m1b-inner-widened decides=1b-A10 twins=1b-A4
# MUTANT-MATRIX m1b-absent-denies decides=1b-A5 twins=1b-A1
# MUTANT-MATRIX m1b-unparseable-denies decides=1b-A6 twins=1b-A1
# MUTANT-MATRIX m1b-key-order decides=1b-E4 twins=1b-A1
# MUTANT-MATRIX mr-no-part-case decides=R-present twins=R-verdict
# MUTANT-MATRIX mr-no-kind decides=R-kind twins=R-present
# MUTANT-MATRIX mr-root-fallback decides=R-root twins=R-kind
# MUTANT-MATRIX md-raw-root decides=MD7 twins=MD1
# MUTANT-MATRIX md-basename decides=MD4 twins=MD1
# MUTANT-MATRIX md-suffix decides=MD5 twins=MD4
# MUTANT-MATRIX md-no-state-spelling decides=MD8 twins=MD6
# MUTANT-MATRIX md-cd-logical decides=MD9 twins=MD9C
# MUTANT-MATRIX m3b-no-iv decides=3b-app.py twins=3b-sib-x.md
# MUTANT-MATRIX m3b-no-worktree decides=3b-sib-app.py twins=3b-app.py
# MUTANT-MATRIX m3b-anchor-anywhere decides=3b-notes.md twins=3b-app.py
# MUTANT-MATRIX m3b-no-iii decides=3b-conflict.py twins=3b-app.py
# MUTANT-MATRIX m3b-after-gate-exit decides=3b-app.py twins=3b-sib-x.md
# MUTANT-MATRIX m3b-no-scanroots decides=3b-r.md twins=3b-app.py
# MUTANT-MATRIX m3b-no-claude-md decides=3b-CLAUDE.md twins=3b-.gitignore
# MUTANT-MATRIX m3b-no-lex decides=3b-nx-app.py twins=3b-app.py
# MUTANT-MATRIX-CONTROL m-crash-control why=a mutant that dies under set -u must be reported BROKEN (rc 2), never decided, so survival of the harness guard is the pass
# MUTANT-MATRIX-CONTROL m-silent-control why=a mutant that exits 0 and logs no event must be reported BROKEN (rc 2), so the event half of the harness guard is what is asserted
# MUTANT-MATRIX-CONTROL m-silent-allow-control why=a silent exit 0 where an allow was expected must be reported BROKEN, so the allow-event guard is what is asserted
# MUTANT-MATRIX-CONTROL m-caller-raw why=the caller still refuses on the normalised length before the predicate is asked, so no verdict moves and survival is the pass
# MUTANT-MATRIX-CONTROL m-predicate-floor-off why=the caller intact refuses first, so the predicate floor removed alone moves no verdict and survival is the pass
# MUTANT-MATRIX-DYNAMIC mx_kill why=every kill goes through the one mx_kill helper whose second argument is the mutant name, each carrying its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/gate-remediation-deny/run.sh --matrix
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
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# MODES. A plain run (what hermetic-run.sh and the hook run) drives each mutant ONLY in its deciding cell(s) plus its
# named twin; `--matrix` also drives every other cell of the mutant's panel and prints one MATRIX row per cell. A cell
# has a ROLE: c = the unmutated control, d = deciding (a kill, routed through mutant_killed), t = a named twin (must
# hold), x = matrix-only and observation-only (never runs on a plain invocation). mx_run is the gate; mx_count is a
# SEPARATE counter the cell's own driver bumps after the gate let it through, so a broken gate cannot hide from the
# arm at the end of this file that fails a plain run which reached an x cell.
MATRIX=0
[ "${1:-}" = "--matrix" ] && MATRIX=1
MX_RAN=0
mx_run() { case "$1" in x) [ "$MATRIX" = 1 ] || return 1 ;; esac; return 0; }
mx_count() { case "$1" in x) MX_RAN=$((MX_RAN + 1)) ;; esac; return 0; }
mx_obs() { # <mutant> <cell> <role> <1 when the cell moved off the unmutated verdict, else 0>
  [ "$MATRIX" = 1 ] || return 0
  printf '  MATRIX %s %s role=%s verdict=%s\n' "$1" "$2" "$3" "$([ "$4" = 1 ] && echo TRIPPED || echo GREEN)"
}
mx_kill() { # <base-pass flag> <mutant> <cell> <hit 0|1> <label> -- the ONE kill emission of this file
  if [ "$4" = 1 ]; then mutant_killed "$1" "$2" "$5"; else bad "$2 SURVIVED: $5"; fi
  mx_obs "$2" "$3" d "$4"
}
mx_hold() { # <role t|x> <mutant> <cell> <hit 0|1: the cell held> <label>
  if [ "$1" = t ]; then if [ "$4" = 1 ]; then ok "$5"; else bad "$5"; fi; fi
  mx_obs "$2" "$3" "$1" "$((1 - $4))"
}

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
else ok "LIFT/EMPTY-CORPUS: an empty corpus falls through to the readable transcript, which verifies"; B_arm9=1; fi

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
  else ok "CONTROL: an unmutated copy of the hook reproduces arm 9's lift"; B_ctl9=1; fi

  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/sessions-plain/current.log" "$MWORK/m-existence-only.sh")"
  mx_kill "$(( ${B_arm9:-0} && ${B_ctl9:-0} ))" m-existence-only arm9 "$(denied "$OUT" && echo 1 || echo 0)" \
    "MUTANT: the pre-fix existence-only predicate DENIES arm 9 — the arm can fire"

  # ...and nothing else moves. A mutant failing more than its own assertion means the arms
  # are entangled and one of them is vacuous.
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/sessions-jsonl/friday.jsonl" "$MWORK/m-existence-only.sh")"
  mx_hold t m-existence-only arm7 "$(denied "$OUT" && echo 0 || echo 1)" \
    "MUTANT: arm 7 (the corpus branch) is UNCHANGED — the mutant moves only its own arm"
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
if denied "$OUT"; then ok "7a: a clean pass at a nonce no dispatch follows does NOT clear a live FAIL"; B_7a=1
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
if denied "$OUT"; then ok "7a: a write row with an EMPTY agent_id does not bind — the lead's own write is not a dispatch"; B_7alw=1
else bad "7a: a write row bound the pass without the harness attributing it to any agent"; fi
rm -rf "$W"

# THE ACQUITTING DIRECTION, and this is the one that keeps the arm from being a blanket deny.
# Same forged tree, plus a write row for that exact stem, carrying an agent_id, clocked AFTER
# the nonce. That is what an honest late pass looks like and it must go through.
seed forged-clean-bound
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then bad "7a: a pass bound by a dispatched agent's own write was still refused — the arm denies every honest pass too"
else ok "7a: a clean pass BOUND by a dispatched agent's write clears the deny (the arm is not a blanket refusal)"; B_7abound=1; fi
rm -rf "$W"

# NOTHING BOUND. The failing pass is unbound too, so there is no bound pass to fall back to.
# The first cut fell through to ALLOW here and wrote no flow-log event: a forged clean pass
# acquitted a live FAIL, invisibly. An unbound verdict may CONVICT, so the fallback is the
# newest FAILING pass whatever its binding, and the substitution is logged.
seed forged-clean-nobound
OUT="$(drive "$W" Edit "$W/$ART")"
if denied "$OUT"; then ok "7a: with NO pass in the directory bound, the forged clean pass still does not clear the unbound FAILING one"; B_7anb=1
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
if denied "$OUT"; then ok "7a: a gate-adjudicator dispatched 901s AFTER the forged nonce does not bind it — the window has an upper bound"; B_7alate=1
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
if denied "$OUT"; then ok "7a: a denied LEAD may not Write subagent-context.jsonl — the probe ledger a shard merge joins through is under the guard"; B_probe=1
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

# --- the mutant: the probe-ledger root removed ----------------------------------------------
# The DENY cells above are presence-shaped, but the docs/ and planning roots are not what they
# exercise, so only a mutant shows the new case is the line that fires. Anchored on the full case
# line (the file's comments also name the file), asserted to match exactly once, built as a copy
# and preceded by an unmutated control. The spawn-ledger cell is the "nothing else moves" arm.
MWORK="$(mktemp -d)"
cp "$HOOK" "$MWORK/control.sh"
PL_ANCHOR='  */${STATE_DIR_NAME}/subagent-context.jsonl|${STATE_DIR_NAME}/subagent-context.jsonl) GUARDED=1 ;;'
PL_N="$(grep -cxF "$PL_ANCHOR" "$HOOK")" || PL_N=0
PL_IMPOSSIBLE="$(grep -cxF "${PL_ANCHOR}#never-a-line" "$HOOK")" || PL_IMPOSSIBLE=0
grep -vxF "$PL_ANCHOR" "$HOOK" > "$MWORK/m-no-probe-root.sh"
if [ "$PL_N" != 1 ] || [ "$PL_IMPOSSIBLE" != 0 ]; then
  bad "MUTANT: the probe-ledger anchor matched ${PL_N} line(s) (want 1; impossible-anchor control ${PL_IMPOSSIBLE}, want 0)"
elif cmp -s "$HOOK" "$MWORK/m-no-probe-root.sh"; then
  bad "MUTANT: removing the probe-ledger root changed no bytes — it would score as a kill"
elif ! bash -n "$MWORK/m-no-probe-root.sh"; then
  bad "MUTANT: the no-probe-root copy does not parse; its silence would score as a kill"
else
  seed open-fail
  OUT="$(drive "$W" Write "$W/_bmad-output/subagent-context.jsonl" "" "" "$MWORK/control.sh")"
  if denied "$OUT"; then ok "CONTROL: an unmutated copy of the hook DENIES the lead's probe-ledger Write"; B_ctlp=1
  else bad "CONTROL: an unmutated copy did not deny the probe-ledger Write — every verdict below is about the copy"; fi
  rm -rf "$W"
  seed open-fail
  OUT="$(drive "$W" Write "$W/_bmad-output/subagent-context.jsonl" "" "" "$MWORK/m-no-probe-root.sh")"
  mx_kill "$(( ${B_probe:-0} && ${B_ctlp:-0} ))" m-no-probe-root probe-ledger "$(denied "$OUT" && echo 0 || echo 1)" \
    "MUTANT: the probe-ledger root removed ALLOWS the lead's Write — the new cell is decided by its own line"
  OUT="$(drive "$W" Edit "$W/_bmad-output/spawn-ledger.jsonl" "" "" "$MWORK/m-no-probe-root.sh")"
  mx_hold t m-no-probe-root spawn-ledger "$(denied "$OUT" && echo 1 || echo 0)" \
    "MUTANT: the spawn-ledger cell is UNCHANGED — the mutant moves only its own arm"
  rm -rf "$W"
fi
rm -rf "$MWORK"

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
else ok "S1: every live FAIL under an in-force suppression -> the edit is ALLOWED"; B_S1=1; fi
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
  if denied "$OUT"; then ok "S1-cache: the cached rows are what the join reads (a poisoned cache changes the verdict)"; B_scache=1
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
  else ok "S1-cache: a changed escalations file invalidates the key and the sibling re-answers"; B_sinv=1; fi

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
      ok "S1-verifier-key: editing the citation verifier invalidates the key and the sibling re-answers — a cache written under one predicate cannot decide a lift under another"; B_vkey=1
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
if denied "$OUT"; then ok "S10: a well-formed, in-force suppression whose quote NO operator said does NOT lift the deny"; B_S10=1
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
if denied "$OUT"; then ok "S11: a suppression naming 3a does not cover a live FAIL on 3"; B_S11=1
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
if denied "$OUT"; then ok "S3: an in-force entry in ANOTHER catalog does not cover this verdict's check"; B_S3=1
else bad "S3: the join dropped the catalog — check 7 of any extension now suppresses core's check 7"; fi
rm -rf "$W"

# --- S4. A BARE id counts as core and nothing else -> DENY against an extension verdict.
seed suppressed-bare
OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC")"
if denied "$OUT"; then ok "S4: a bare (bracketless) **Suppresses:** id covers core only, not an extension catalog"; B_S4=1
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
if denied "$OUT"; then ok "S5: one covered FAIL beside an uncovered one still DENIES"; B_S5=1
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
if denied "$OUT"; then ok "S6: no sibling -> no carve-out, and the deny stands"; B_S6=1
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
if denied "$OUT"; then ok "S9: a sibling that refuses --in-force -> no carve-out, and the deny stands"; B_S9=1
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
else ok "S13a: the carve-out lifts with the timeline at the flat fallback"; B_s13a=1; fi
rm -rf "$W"
# EVERY M10 DRIVE (S13a, S13b, the standard layout) IS A FRESH WORKSPACE, in the plain run and in --matrix alike.
if [ "$M10_OK" = "1" ] && grd_world suppressed "$GRD_FLAT"; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW13/m10.sh")"
  mx_kill "${B_s13a:-0}" M10 S13a "$(denied "$OUT" && echo 1 || echo 0)" \
    "M10 decided by S13a — a guard that names ONE path denies every consumer on the flat layout"
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
else ok "S13b: the carve-out lifts with the timeline under the docs fallback"; B_s13b=1; fi
rm -rf "$W"
if [ "$M10_OK" = "1" ] && mx_run x && grd_world suppressed "$GRD_DOCS"; then
  mx_count x
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW13/m10.sh")"
  mx_hold x M10 S13b "$(denied "$OUT" && echo 1 || echo 0)" \
    "M10 also moves S13b — the same one-path guess denies every consumer on the docs layout too"
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
  mx_hold t M10 S13-std "$(denied "$OUT" && echo 0 || echo 1)" \
    "M10: INVISIBLE in the standard layout — which is why the wrong fix passes every other arm in this file and needs S13a/S13b"
  rm -rf "$W"
fi
rm -rf "$MW13"

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
FL_MW="$(mktemp -d)"
cp "$HOOK" "$FL_MW/control.sh"
FL_WHY=""
fl_sub() {  # <src> <dest> <anchor> <replacement> [<anchor> <replacement>]... -> 0 if applied
  local src="$1" dest="$2" n
  shift 2
  cp "$src" "$dest.work" || { FL_WHY="could not copy $src"; return 1; }
  while [ "$#" -ge 2 ]; do
    n="$(grep -cF -- "$1" "$dest.work")" || n=0
    [ "$n" -eq 1 ] || { FL_WHY="anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm: $1"; return 1; }
    A="$1" R="$2" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["A"])); print }' \
      "$dest.work" > "$dest.next" || { FL_WHY="awk died"; return 1; }
    mv "$dest.next" "$dest.work"
    shift 2
  done
  cmp -s "$src" "$dest.work" && { FL_WHY="changed no bytes -- it would score as a kill"; return 1; }
  bash -n "$dest.work" 2>/dev/null || { FL_WHY="does not parse"; return 1; }
  mv "$dest.work" "$dest"
}
fl_world() {  # <7b|9> <padded|blank|whole> <predicate-floor-off 0|1> -> W, FL_TR; 1 if the world could not be built
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
  if [ "$3" = 1 ]; then
    fl_sub "$W/scripts/ai-dlc/validate-steering-budget.sh" "$W/scripts/ai-dlc/validate-steering-budget.sh.m" \
      '  if (needle.length < CITE_MIN_NORM_CHARS) {' '  if (false) {' || return 1
    mv "$W/scripts/ai-dlc/validate-steering-budget.sh.m" "$W/scripts/ai-dlc/validate-steering-budget.sh"
  fi
}
FL_CELLS=""
fl_cells() {  # <hook> <predicate-floor-off 0|1> [<keys>] -> FL_CELLS, or "BROKEN:<why>"
  local h="$1" off="$2" keys="${3:-7b:padded 7b:blank 7b:whole 9:padded 9:blank 9:whole}" c="" k o lg
  for k in $keys; do
    if ! fl_world "${k%%:*}" "${k#*:}" "$off"; then FL_CELLS="BROKEN:$FL_WHY"; rm -rf "$W"; return; fi
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
fl_report() {  # <label> <want> <hook> <predicate-floor-off>
  fl_cells "$3" "$4"
  if [ "$FL_CELLS" = "$2" ]; then ok "$1: $2 -> $FL_CELLS"
  else bad "$1: scored $FL_CELLS, wanted $2"; fi
}
fl_pick() {  # <keys> <key> -> the letter FL_CELLS holds for <key>
  local i=0 k
  for k in $1; do [ "$k" = "$2" ] && { printf '%s' "${FL_CELLS:$i:1}"; return; }; i=$((i + 1)); done
}
# THE INCIDENT IS NOT THE MEMBER THE READER OPENS FIRST, in either corpus. Asked of the reader's
# own call, because shell glob order and readdirSync order are two different claims.
fl_first() { node -e 'const fs=require("fs");console.log(fs.readdirSync(process.argv[1]).filter(f=>f.endsWith(".jsonl"))[0]||"")' "$1" 2>/dev/null; }
FL_PROBE=""
fl_world 7b whole 0 && FL_PROBE="$(fl_first "$W/sessions-jsonl")"; rm -rf "$W"
fl_world 9 whole 0 && FL_PROBE="$FL_PROBE $(fl_first "$W/sessions-yes")"; rm -rf "$W"
case "$FL_PROBE" in
  *incident*|" "*|*" ") bad "FLOOR-pre: FIXTURE BROKEN — the reader's first members are '$FL_PROBE'; the incident must not be first" ;;
  *) ok "FLOOR-pre: the reader opens '$FL_PROBE' first; the incident turn is in a later member of each corpus" ;;
esac
_fl0="$fails"
fl_report "FLOOR (7b padded/blank/whole, arm 9 padded/blank/whole)" DDSDDL "$HOOK" 0
fl_report "FLOOR-CONTROL: an unmutated copy of the hook" DDSDDL "$FL_MW/control.sh" 0
[ "$fails" = "$_fl0" ] && B_floor=1
# THE CALLER MEASURES RAW BYTES AGAIN, at both sites. The predicate still refuses the short needle
# (NOMATCH-SHORT), so no verdict moves -- the defence in depth, asserted rather than assumed.
FL_C7='  [ "$(cite_nlen "$nq")" -ge 12 ] || return 1'
FL_C9='  if [ "$(cite_nlen "$AUTH_NQUOTE")" -ge 12 ]; then'
if fl_sub "$HOOK" "$FL_MW/m-caller-raw.sh" "$FL_C7" '  [ "${#q}" -ge 12 ] || return 1' \
     "$FL_C9" '  if [ "${#AUTH_QUOTE}" -ge 12 ]; then'; then
  # A KNOCK-OUT CONTROL: its correct outcome is that nothing moves.
  fl_report "CONTROL m-caller-raw: the predicate still refuses, nothing moves" DDSDDL "$FL_MW/m-caller-raw.sh" 0
  # EVERY LAYER REVERTED -- the shipped defect. Padded and blank now LIFT at both arms; the whole
  # quote is unmoved. Decided by 7b-padded, twin 7b-whole; --matrix drives all six cells.
  _flk="7b:padded 7b:whole"
  [ "$MATRIX" = 1 ] && _flk="7b:padded 7b:blank 7b:whole 9:padded 9:blank 9:whole"
  fl_cells "$FL_MW/m-caller-raw.sh" 1 "$_flk"
  case "$FL_CELLS" in
    BROKEN:*) bad "FLOOR-m-both-layers: FIXTURE BROKEN — ${FL_CELLS#BROKEN:}" ;;
    *)
      mx_kill "${B_floor:-0}" FLOOR-m-both-layers 7b-padded "$([ "$(fl_pick "$_flk" 7b:padded)" = S ] && echo 1 || echo 0)" \
        "FLOOR m-both-layers: a padded quote LIFTS at 7b (every layer reverted)"
      mx_hold t FLOOR-m-both-layers 7b-whole "$([ "$(fl_pick "$_flk" 7b:whole)" = S ] && echo 1 || echo 0)" \
        "FLOOR m-both-layers: the whole quote is unmoved at 7b"
      if [ "$MATRIX" = 1 ]; then
        mx_count x; mx_hold x FLOOR-m-both-layers 7b-blank "$([ "$(fl_pick "$_flk" 7b:blank)" = S ] && echo 1 || echo 0)" "FLOOR m-both-layers: a blank quote LIFTS at 7b"
        mx_count x; mx_hold x FLOOR-m-both-layers 9-padded "$([ "$(fl_pick "$_flk" 9:padded)" = L ] && echo 1 || echo 0)" "FLOOR m-both-layers: a padded quote LIFTS at arm 9"
        mx_count x; mx_hold x FLOOR-m-both-layers 9-blank "$([ "$(fl_pick "$_flk" 9:blank)" = L ] && echo 1 || echo 0)" "FLOOR m-both-layers: a blank quote LIFTS at arm 9"
        mx_count x; mx_hold x FLOOR-m-both-layers 9-whole "$([ "$(fl_pick "$_flk" 9:whole)" = L ] && echo 1 || echo 0)" "FLOOR m-both-layers: the whole quote is unmoved at arm 9"
      fi ;;
  esac
else
  bad "FLOOR m-caller-raw: DID NOT APPLY: $FL_WHY"
fi
# THE PREDICATE'S FLOOR REMOVED, the caller intact: the caller refuses on the normalised length
# before asking, so nothing moves here either.
fl_report "CONTROL m-predicate-floor-off: the caller still refuses, nothing moves" DDSDDL "$FL_MW/control.sh" 1
rm -rf "$FL_MW"

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
  MOK="${MOK}$1 "
  return 0
}
MOK=" "
mok() { case "$MOK" in *" $1 "*) return 0 ;; esac; return 1; }
km_run() { # <name> <workspace> [gate-metrics] -> KM_OUT, KM_RC, KM_EV (the flow-log events it wrote)
  KM_OUT="$(drive "$2" Edit "$2/$ART" "" "$2/$TRC" "$MW/$1.sh" "${3:-}")"; KM_RC=$?
  KM_EV="$(grep -o 'GATE_VERDICT_UNBOUND\|GATE_REMEDIATION_SUPPRESSED\|GATE_REMEDIATION_DENIED\|GATE_REMEDIATION_LIFTED' "$2/_bmad-output/pipeline-continuation-log.md" 2>/dev/null | tr '\n' ' ')"
}
# A MUTANT THAT CRASHES SCORES EXACTLY LIKE ONE THAT ALLOWS: no output reads as allowed. Measured:
# three mutants referenced a variable the fix had removed, died under the hook's `set -u` with rc=1
# and no output, and every one scored its kills that way. The hook exits 0 on every allow and every
# deny, so a non-zero rc is a crash, on any world -- FIXTURE BROKEN, never a kill. KM_NEED_EV=1 also
# demands a flow-log event: every unbound world logs one before any exit it can reach.
KM_NEED_EV=0
# AN ALLOW-EXPECTING KILL ALSO DEMANDS ITS EVENT, because a silent `exit 0` is an allow too: every
# allow that clears a FAIL logs GATE_REMEDIATION_SUPPRESSED, GATE_REMEDIATION_LIFTED, or (the
# unbound residual) GATE_VERDICT_UNBOUND. The one
# allow that legitimately writes nothing is the clean fast path (a bound or no-corpus clean live
# pass exits before any log), and arm 7a's mutants are scored on exactly that; their block sets
# KM_ALLOW_SILENT=1 and says so. m-silent-allow-control below proves this half can fire.
KM_ALLOW_SILENT=0
arm_eval() { # <name> <expect deny|allow> <workspace> <label> [gate-metrics] -> ARM_HIT 1 when the verdict is <expect>; rc 2 when BROKEN
  local nm="$1" want="$2" w="$3" label="$4" gm="${5:-}"
  km_run "$nm" "$w" "$gm"; local o="$KM_OUT"
  if [ "$KM_RC" -ne 0 ]; then bad "$label — FIXTURE BROKEN: the mutant $nm exited rc=$KM_RC (a crash, not a verdict)"; return 2; fi
  if [ "$KM_NEED_EV" -eq 1 ] && [ -z "$KM_EV" ]; then bad "$label — FIXTURE BROKEN: the mutant $nm wrote no flow-log event, so it never reached a decision"; return 2; fi
  if [ "$want" = allow ] && [ "$KM_ALLOW_SILENT" -eq 0 ] && ! denied "$o"; then
    # GATE_VERDICT_UNBOUND counts too: the convict set's residual exit ("nothing to convict on:
    # ALLOWED") is a decision and logs only that event.
    case "$KM_EV" in *GATE_REMEDIATION_SUPPRESSED*|*GATE_REMEDIATION_LIFTED*|*GATE_VERDICT_UNBOUND*) ;;
      *) bad "$label — FIXTURE BROKEN: $nm allowed with no SUPPRESSED/LIFTED/UNBOUND event (events [${KM_EV% }]); a silent exit 0 is not an allow"; return 2 ;; esac
  fi
  ARM_HIT=0
  if [ "$want" = deny ]; then denied "$o" && ARM_HIT=1; else denied "$o" || ARM_HIT=1; fi
  return 0
}
# kill_arm <base-pass flag> <mutant> <mutated verdict deny|allow> <workspace> <label> [gate-metrics] -- the DECIDING cell
kill_arm() {
  arm_eval "$2" "$3" "$4" "$5" "${6:-}" || return 2
  mx_kill "$1" "$2" "$SEED_CASE" "$ARM_HIT" "$5"
}
# hold_arm <role c|t|x> <name> <verdict deny|allow> <workspace> <label> [gate-metrics] -- a cell that must HOLD
# (c = the unmutated control, t = a named twin, x = matrix-only). Returns 0 when it held.
hold_arm() {
  mx_run "$1" || return 0
  mx_count "$1"
  arm_eval "$2" "$3" "$4" "$5" "${6:-}" || return 2
  case "$1" in
    c) if [ "$ARM_HIT" = 1 ]; then ok "$5"; else bad "$5"; fi ;;
    *) mx_hold "$1" "$2" "$SEED_CASE" "$ARM_HIT" "$5" ;;
  esac
  [ "$ARM_HIT" = 1 ]
}

# EVERY DECISION MUTANT IS BUILT HERE, ONCE, BEFORE ITS CELLS ARE DRIVEN, so the S1 world below can carry the named
# twin of each (S1 is green under every one of them) and a plain run drives each mutant in its deciding cell plus that
# one twin. M1 / M5 / M4 are scored on the seeds they are wrong about; each also gets one seed it must NOT move, so a
# mutant that simply breaks the hook cannot score a kill.
mut m8-no-cite-verification 's@if cite_verifies "\${_rauth:-}"; then@if true; then@' || :
mut m9-substring-join 's@if grep -qxF "\$_c" <<<"\$COVERED"; then@if grep -qF "$_c" <<<"$COVERED"; then@' || :
mut m2-no-catalog-join 's@if (c == want) print \$2@print $2@' || :
mut m3-bare-is-wildcard 's@if (c == want) print \$2@if (c == want || $1 == "") print $2@' || :
mut m4-absence-is-coverage 's@elif \[ -z "\$SUPP_DIR" \]; then@elif [ -z "$SUPP_DIR" ]; then FAILED_CHECKS="";@' || :
mut m7-ignore-sibling-rc 's@if \[ "\$SUPP_RC" -eq 0 \]; then@if true; then@' || :
mut m1-no-subtract '/^  FAILED_CHECKS="\$REMAINING"$/d' || :
mut m5-any-suppression-lifts 's@if \[ -z "\$FAILED_CHECKS" \]; then@if [ -n "$SUPPRESSED_CHECKS" ]; then@' || :
mut m6b-key-drops-verifier 's@|\$(ckey "\$STEER_SCRIPT")@@' || :
mut m6-key-drops-escalations 's@|\$(ckey "\$ESC_FILE")@@' || :
seed suppressed
if hold_arm c control allow "$W" "CONTROL: an unmutated COPY of the hook reproduces S1's allow"; then B_ctlS1=1; fi
if mok m1-no-subtract; then
  kill_arm "$(( ${B_S1:-0} && ${B_ctlS1:-0} ))" m1-no-subtract deny "$W" "M1: computing the subtraction and never applying it DENIES S1 — the arm can fire"
fi
if mok m5-any-suppression-lifts; then
  hold_arm t m5-any-suppression-lifts allow "$W" "M5: 'any suppression lifts' is INVISIBLE on S1 — which is why S5 exists"
fi
if mok m6b-key-drops-verifier; then
  hold_arm t m6b-key-drops-verifier allow "$W" "M6b: dropping the VERIFIER term from the cache key does not move S1 itself"
fi
if mok m6-key-drops-escalations; then
  hold_arm t m6-key-drops-escalations allow "$W" "M6: dropping the escalations term from the cache key does not move S1 itself"
fi
if mok m9-substring-join; then
  hold_arm t m9-substring-join allow "$W" "M9: ...and S1 is UNCHANGED under it (the mutant moves only its own arm)"
fi
if mok m2-no-catalog-join; then
  hold_arm t m2-no-catalog-join allow "$W" "M2: ...and S1 is UNCHANGED under it (the mutant moves only its own arm)"
fi
if mok m3-bare-is-wildcard; then
  hold_arm t m3-bare-is-wildcard allow "$W" "M3: ...and S1 is UNCHANGED under it (the mutant moves only its own arm)"
fi
rm -rf "$W"
# THE S1 TWINS OF M8, M4 AND M7 EACH GET A FRESH WORKSPACE. Their mutated lines sit upstream of the cache write and the
# cache key omits the hook, so a twin driven in the control's already-warmed workspace reads the control's cached rows
# and never reaches its own mutation.
for _s1t in m8-no-cite-verification:M8 m4-absence-is-coverage:M4 m7-ignore-sibling-rc:M7; do
  mok "${_s1t%%:*}" || continue
  seed suppressed
  hold_arm t "${_s1t%%:*}" allow "$W" "${_s1t##*:}: ...and S1 is UNCHANGED under it (the mutant moves only its own arm)"
  rm -rf "$W"
done

seed suppressed-partial
if mok m5-any-suppression-lifts; then
  kill_arm "$(( ${B_S5:-0} && ${B_ctlS1:-0} ))" m5-any-suppression-lifts allow "$W" "M5: 'any suppression lifts' ALLOWS S5 — the arm can fire on the fail-open wrong fix"
fi
if mok m1-no-subtract; then
  hold_arm t m1-no-subtract deny "$W" "M1: ...and S5 is UNCHANGED under M1 (the mutants move only their own arms)"
fi
rm -rf "$W"

# M8 is the whole BLOCKER as a mutation: drop the citation verification and every covering row
# is taken on trust, which is the state this fixture's own subject shipped in.
seed suppressed-forged
if mok m8-no-cite-verification; then
  kill_arm "$(( ${B_S10:-0} && ${B_ctlS1:-0} ))" m8-no-cite-verification allow "$W" "M8: dropping the citation check ALLOWS a lead-authored suppression — the verification is what keeps arm 7b out of the lead's reach"
fi
rm -rf "$W"

# M9: the id grain. `-qxF` -> `-qF` is one character and acquits a FAIL on 3 under 3a.
seed suppressed-superset
if mok m9-substring-join; then
  kill_arm "$(( ${B_S11:-0} && ${B_ctlS1:-0} ))" m9-substring-join allow "$W" "M9: a substring covered-set join ALLOWS S11 — the whole-token match is load-bearing"
fi
rm -rf "$W"

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
if w_p1; then ok "W1: FAIL_WAIVED under a real, verified OVERRIDDEN waiver -> ALLOWED, and logged as waived"; B_W1=1
else bad "W1: a FAIL_WAIVED whose waiver_id names a verified OVERRIDDEN entry stayed LOCKED (or allowed silently)"; fi
if w_p2; then ok "W2: FAIL_WAIVED naming a fabricated waiver_id -> DENIED, check 7 named"; B_W2=1
else bad "W2: a FAIL_WAIVED under a waiver_id no escalation entry carries ESCAPED the lock"; fi
if w_p3; then ok "W3: FAIL_WAIVED whose waiver cannot be verified (no citation verifier) -> DENIED"; B_W3=1
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
if w_p6; then ok "W6: an unbound FAIL_WAIVED verdict carrying a PLAIN FAIL on the same check 7 -> DENIED; a waiver never lifts a plain FAIL row"; B_W6=1
else bad "W6: a plain FAIL sharing the waived check's id was lifted by the waiver"; fi
if w_p7; then ok "W7: the same verdict with a plain FAIL whose check_id is null -> DENIED"; B_W7=1
else bad "W7: a null-id plain FAIL vanished and the waiver opened the lock"; fi
if w_p8; then ok "W8: two forged FAIL_WAIVED-only passes, nothing bound -> DENIED, the second forgery adjudicated as a CONVICT-ONLY substitute"; B_W8=1
else bad "W8: the unbound substitute was acquitted by its own waiver"; fi
if w_p9; then ok "W9: the real waiver_id with a trailing TAB -> ALLOWED, as Check 26's rstrip() reads it"; B_W9=1
else bad "W9: a tab-trailing waiver_id the gate accepts stayed LOCKED — the guard and Check 26 disagree about one entry"; fi
if w_p10; then ok "W10: a BOUND verdict carrying a PLAIN FAIL beside its waived check 7 -> DENIED on 7; the waiver lifts only the waived row"; B_W10=1
else bad "W10: on a bound pass the waiver lifted the plain FAIL sharing its check id"; fi
if w_p11; then ok "W11: two forged FAIL_WAIVED-only passes and nothing else -> DENIED on 7; an unbound set takes no waiver"; B_W11=1
else bad "W11: two unbound FAIL_WAIVED-only passes acquitted themselves through their own waiver"; fi
wn_score() { # <mutant> <deciding id> <base-pass flag> <twin id> <label> [matrix-only ids...]
  local m="$1" did="$2" tid="$4" xid hit=0
  "w_p$did" "$MW/$m.sh" || hit=1
  mx_kill "$3" "$m" "W$did" "$hit" "$5"
  hit=0; "w_p$tid" "$MW/$m.sh" && hit=1
  mx_hold t "$m" "W$tid" "$hit" "$m: ...and W$tid is UNCHANGED under it (the mutant moves only its own arm)"
  for xid in "${@:6}"; do
    mx_run x || continue
    mx_count x
    hit=0; "w_p$xid" "$MW/$m.sh" && hit=1
    mx_hold x "$m" "W$xid" "$hit" "-"
  done
}
# W-MP: the partition by KIND removed — plain FAIL ids go through the waiver set by id. Decided by W10; W9 is the twin.
if mut wmp-no-kind-partition 's@^  for _c in \$PLAIN_FAILS; do$@  for _c in ""; do@;s@^  for _c in \$WAIVED_CANDIDATES; do$@  for _c in $FAILED_CHECKS; do@'; then
  wn_score wmp-no-kind-partition 10 "${B_W10:-0}" 9 "W-MP (a waiver lifts a plain FAIL by its check id)" 6 7 8 11
fi
# W-ME: the B1 fix reverted WHOLE -- LIVE_CLEAN by string equality of the two id lists AND the
# waiver lifting by check id. Both layers, because on the new fail_sets the string test alone is
# EQUIVALENT to the count (FAILED_CHECKS is built PLAIN then WAIVED, so the lists are equal
# exactly when no plain FAIL exists) and a one-layer revert would change nothing.
if mut wme-string-equality 's@^  case "\$PLAIN_N" in \[1-9\]|\[1-9\]\[0-9\]\*) ;; \*) LIVE_CLEAN=1 ;; esac$@  [ "$FAILED_CHECKS" != "$WAIVED_CANDIDATES" ] || LIVE_CLEAN=1@;s@^  for _c in \$PLAIN_FAILS; do$@  for _c in ""; do@;s@^  for _c in \$WAIVED_CANDIDATES; do$@  for _c in $FAILED_CHECKS; do@'; then
  wn_score wme-string-equality 10 "${B_W10:-0}" 9 "W-ME (B1 reverted: string-equality LIVE_CLEAN and the id-keyed lift)" 6 7 8 11
fi
# W-MS: an unbound convict set keeps its FAIL_WAIVED rows and takes the waiver join. The reset
# sits in the convict-set builder, before arm 7b's fetch, so `--waivers` is asked again under it.
# W8 cannot see it any more (the older plain FAIL denies either way); W11 can, and W9 must hold.
# W7 moves too, and that is the same property rather than an entanglement: W7's pass is unbound,
# so its expected text `null 7` carries the waived 7 read as a plain FAIL, and under the mutant
# the waiver lifts it and the deny names `null` alone. W11 owns the verdict flip; W7 owns the text.
if mut wms-substitute-waives '/^  WAIVED_CANDIDATES=""$/d'; then
  wn_score wms-substitute-waives 11 "${B_W11:-0}" 9 "W-MS (the unbound substitute is acquitted by its own waiver)" 6 7 8 10
fi

# W-MJ: the waiver_id join dropped — any verified waiving entry lifts any FAIL_WAIVED. Decided by W2
# alone (W1 holds: the id is real; W3 holds: nothing verifies, so no entry exists to lift it).
if mut wmj-no-waiver-join 's@{c: \$c, ok: (\$w != null and \$n != null@{c: $c, ok: (true or $w != null and $n != null@'; then
  wn_score wmj-no-waiver-join 2 "${B_W2:-0}" 1 "W-MJ (dropping the waiver_id join lifts a FABRICATED waiver id)" 3
fi


seed suppressed-wrongcat
if mok m2-no-catalog-join; then
  kill_arm "$(( ${B_S3:-0} && ${B_ctlS1:-0} ))" m2-no-catalog-join allow "$W" "M2: dropping the catalog from the join ALLOWS S3 — the catalog half of the key is load-bearing"
fi
rm -rf "$W"

seed suppressed-bare
if mok m3-bare-is-wildcard; then
  kill_arm "$(( ${B_S4:-0} && ${B_ctlS1:-0} ))" m3-bare-is-wildcard allow "$W" "M3: treating a bare bracket as a wildcard ALLOWS S4 — the bare-means-core rule is load-bearing"
fi
# S4 stands down for M2: the catalog join OWNS that case, and M2 reaches S4 too.
rm -rf "$W"

seed suppressed-nosibling
if mok m4-absence-is-coverage; then
  kill_arm "$(( ${B_S6:-0} && ${B_ctlS1:-0} ))" m4-absence-is-coverage allow "$W" "M4: reading an ABSENT sibling as 'everything is covered' ALLOWS S6 — the fail-closed posture is load-bearing"
fi
rm -rf "$W"

# M7 flips no verdict, so it is scored on the status string S9 asserts, not on deny/allow.
seed suppressed-oldsibling
if mok m7-ignore-sibling-rc; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/m7-ignore-sibling-rc.sh")"
  mx_hold t m7-ignore-sibling-rc verdict "$(denied "$OUT" && echo 1 || echo 0)" "M7: ignoring the sibling's return code still DENIES (this check moves no verdict, as declared)"
  case "$OUT" in *"refused:"*) mx_kill "${B_S9:-0}" m7-ignore-sibling-rc status 0 "M7: the mutant still reported 'refused' — S9's status arm cannot see the return-code check at all" ;;
    *) mx_kill "${B_S9:-0}" m7-ignore-sibling-rc status 1 "M7: ...and it reports the refusal as a clean read, which is exactly what S9's status arm catches" ;; esac
fi
rm -rf "$W"

# M6 needs the two-call shape S1's cache arm uses: answer once, change the escalations file,
# answer again. With the escalations term gone from the key the second answer is the stale one.
seed suppressed
if mok m6-key-drops-escalations; then
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/m6-key-drops-escalations.sh")"
  : > "$W/docs/escalations/pending.md"
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/m6-key-drops-escalations.sh")"
  mx_kill "${B_sinv:-0}" m6-key-drops-escalations emptied-escalations "$(denied "$OUT" && echo 0 || echo 1)" "M6: with the escalations term dropped from the key, an EMPTIED escalations file still lifts — the key term is load-bearing"
  OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/control.sh")"
  if denied "$OUT"; then ok "M6: ...and the unmutated copy DENIES on the same emptied file (the two sides differ)"
  else bad "M6: the unmutated copy also lifted on an emptied escalations file — the differential's two sides do not differ, so M6's kill is unearned"; fi
fi
rm -rf "$W"

# M6b -- the VERIFIER term dropped from the key, which is S1-verifier-key's subject. Same
# two-call shape: warm the cache, change the CITATION VERIFIER, answer again. With the term
# gone the second answer is the stale one, so the poisoned row -- which names a catalog this
# verdict is not in -- decides the lift and the edit is DENIED. The unmutated copy must ALLOW
# on the same world, or the two sides do not differ and this kill is unearned.
seed suppressed
if mok m6b-key-drops-verifier; then
  M6B_STEER="$W/scripts/ai-dlc/validate-steering-budget.sh"
  [ -f "$M6B_STEER" ] || M6B_STEER="$W/core/scripts/validate-steering-budget.sh"
  if [ ! -f "$M6B_STEER" ]; then
    bad "M6b: FIXTURE BROKEN — no citation verifier in this workspace, so its key term cannot be moved"
  else
    OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/m6b-key-drops-verifier.sh")"
    M6B_CACHE="$W/_bmad-output/.gate-remediation-in-force"
    if [ ! -f "$M6B_CACHE" ]; then
      bad "M6b: FIXTURE BROKEN — the mutant wrote no cache, so there is nothing for a stale key to read back"
    else
      printf '%s\nnot-this-catalog\t7\t3\t0\t2026-08-01T00:00:00Z | "Operator-suppress this FAIL (Recommended)"\tseeded cache poison\n' "$(head -1 "$M6B_CACHE")" > "$M6B_CACHE"
      printf '\n# fixture: the verifier changed under a warm cache\n' >> "$M6B_STEER"
      OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/m6b-key-drops-verifier.sh")"
      mx_kill "${B_vkey:-0}" m6b-key-drops-verifier changed-verifier "$(denied "$OUT" && echo 1 || echo 0)" "M6b: with the verifier term dropped, a row cached under the OLD predicate is reused after the predicate changed — S1-verifier-key's term is load-bearing"
      OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/control.sh")"
      if denied "$OUT"; then bad "M6b: the unmutated copy ALSO reused the stale row — the differential's two sides do not differ, so M6b's kill is unearned"
      else ok "M6b: ...and the unmutated copy re-answers on the same world (the two sides differ)"; fi
    fi
  fi
fi
rm -rf "$W"

# --- arm 7a's mutants -------------------------------------------------------------------
# Their allow-kills are the CLEAN FAST PATH (a bound or no-ledger clean live pass exits before any
# flow-log write), so the allow-event demand stands down for this block only; the rc guard holds.
KM_ALLOW_SILENT=1
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
  kill_arm "${B_7a:-0}" m11-window-ignores-order allow "$W" "M11: a dispatch window that ignores ORDER binds the forged pass — 'a dispatch near this nonce' is not 'a dispatch after it'"
fi
# M13 FLIPS NO VERDICT SINCE THE BINDING IS ASKED OF EVERY NEWEST PASS: without LIVE_CLEAN a
# forged clean pass is still unbound and still convicts. What the line still gates is the clean
# fast path, so M13 is scored on `forged-clean-bound` below by its flow log, not here.
mut m13-arm-unreachable '/^\[ -n "\$FAILED_CHECKS" \] || LIVE_CLEAN=1$/d' || true
if mut m14-write-never-binds 's@then "bound-write"@then "unbound"@'; then
  hold_arm x m14-write-never-binds deny "$W" "M14: ...and a B1 that never binds leaves this world UNCHANGED (the mutant moves only its own arm)"
fi
rm -rf "$W"

seed forged-clean-leadwrite
if mut m12-records-every-writer 's@select((\.agent_id // "") != "")@select(true)@'; then
  kill_arm "${B_7alw:-0}" m12-records-every-writer allow "$W" "M12: a write ledger that does not require the harness's agent_id lets a LEAD write bind its own verdict"
fi
if mok m11-window-ignores-order; then
  hold_arm x m11-window-ignores-order deny "$W" "M11: ...and W3 acquits this world too — both wrong fixes fail open, in different places"
fi
rm -rf "$W"

# THE ACQUITTING DIRECTION UNDER MUTATION. `forged-clean-bound` must ALLOW, so an arm that
# only ever denies would pass every assertion above. M14 makes B1 unable to bind and this
# world must go red — that is what proves the allow is a measurement and not a default.
seed forged-clean-bound
if hold_arm c control allow "$W" "CONTROL: an unmutated COPY of the hook reproduces 7a's allow on a BOUND clean pass"; then B_ctl7a=1; fi
if mok m14-write-never-binds; then
  kill_arm "$(( ${B_7abound:-0} && ${B_ctl7a:-0} ))" m14-write-never-binds deny "$W" "M14: a B1 arm that never returns bound-write DENIES a legitimately bound pass — the acquitting arm can fire"
fi
if mok m12-records-every-writer; then
  hold_arm x m12-records-every-writer allow "$W" "M12: ...and W4 leaves the honest world UNCHANGED, which is why it needs its own"
fi
rm -rf "$W"
# M13 on its observable. A bound clean pass leaves the guard at the clean fast path, which writes
# NOTHING to the flow log; with LIVE_CLEAN never set it goes on through arm 7b and logs an empty
# partition as GATE_REMEDIATION_SUPPRESSED. Both allow, so the arm is the log, with the unmutated
# copy as the side that must differ.
if mok m13-arm-unreachable; then
  for _m13 in control m13-arm-unreachable; do
    seed forged-clean-bound
    OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "$MW/$_m13.sh")"
    _m13log="$(grep -c 'GATE_REMEDIATION_SUPPRESSED' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)" || _m13log=0
    if denied "$OUT"; then bad "M13 ($_m13): the bound clean pass was DENIED — the observable below is about the wrong outcome"
    elif [ "$_m13" = control ]; then
      if [ "$_m13log" -eq 0 ]; then ok "M13: the unmutated copy clears a bound clean pass at the fast path, logging no GATE_REMEDIATION_SUPPRESSED"; B_m13ctl=1
      else bad "M13: the unmutated copy logged GATE_REMEDIATION_SUPPRESSED on a bound clean pass — the fast path is gone, and M13 has no subject"; fi
    elif [ "$_m13log" -gt 0 ]; then mx_kill "${B_m13ctl:-0}" m13-arm-unreachable fast-path 1 "M13: with LIVE_CLEAN never set, the bound clean pass falls through to arm 7b and logs GATE_REMEDIATION_SUPPRESSED — the line gates the fast path"
    else mx_kill "${B_m13ctl:-0}" m13-arm-unreachable fast-path 0 "M13: deleting the LIVE_CLEAN line changed nothing observable — the line is not load-bearing"; fi
    rm -rf "$W"
  done
fi

# THE WINDOW'S UPPER BOUND UNDER MUTATION. M15 widens the window to 10^9, which is the fifth
# wrong implementation the batch-63 adversary built: every clause and every anchor above
# survives it, and only `forged-clean-latewindow` can see it. `forged-clean` must stay DENIED
# under it (no gate-adjudicator row follows 21:00:00Z at all), which is what says the kill
# came from the bound and not from the arm going dark.
seed forged-clean-latewindow
if mut m15-window-unbounded 's@ and \. <= (\$N + \$win)@ and . <= (\$N + 1000000000)@'; then
  kill_arm "${B_7alate:-0}" m15-window-unbounded allow "$W" "M15: a window with no upper bound binds the forged pass to a dispatch 901s later — the size of the window is a property this fixture holds"
fi
rm -rf "$W"
seed forged-clean
if mok m15-window-unbounded; then
  hold_arm x m15-window-unbounded deny "$W" "M15: ...and with no dispatch after the forged nonce at all, the unbounded window still DENIES (the verdict flip above came from the bound)"
fi
rm -rf "$W"

# THE NO-BOUND FALLBACK UNDER MUTATION. M16 restores the first cut's fall-through: with no
# bound pass in the directory, exit 0. Only `forged-clean-nobound` can see it, and
# `forged-clean` (which HAS a bound failing pass) must keep denying under it.
seed forged-clean-nobound
if mut m16-nobound-acquits 's@  if \[ -z "\$BOUND_STEM" \]; then$@  if [ -z "$BOUND_STEM" ]; then exit 0;@'; then
  kill_arm "${B_7anb:-0}" m16-nobound-acquits allow "$W" "M16: falling through to ALLOW when nothing is bound acquits a forged clean pass beside an unbound FAIL — the fallback convicts on the newest failing pass"
fi
rm -rf "$W"
seed forged-clean
if mok m16-nobound-acquits; then
  hold_arm x m16-nobound-acquits deny "$W" "M16: ...and where a BOUND failing pass exists the fall-through never runs, so this world still DENIES"
fi
rm -rf "$W"

# THE NO-CORPUS CONTROL. `stale-then-clean` is byte-for-byte this family's tree minus the
# ledger, and it must ALLOW under every mutant above. A change that reddens it has broken the
# nonce ordering rather than added a binding, and the two are indistinguishable from the
# forged world alone.
seed stale-then-clean
for _m7a in m11-window-ignores-order m12-records-every-writer m13-arm-unreachable m14-write-never-binds m15-window-unbounded m16-nobound-acquits; do
  mok "$_m7a" || continue
  hold_arm t "$_m7a" allow "$W" "7a: ${_m7a} leaves the NO-LEDGER world allowing — the arm's subject is the ledger, not the second verdict"
done
KM_ALLOW_SILENT=0
rm -rf "$W"

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
aq_kill() { # <base-pass flag> <mutant> <case> <expect deny|allow> <label> -- the DECIDING cell, a fresh workspace per drive
  seed "$3"; kill_arm "$1" "$2" "$4" "$W" "$5"; rm -rf "$W"; }
aq_hold() { # <role t|x> <mutant> <case> <expect deny|allow> <label> -- a cell that must hold
  mx_run "$1" || return 0
  seed "$3"; hold_arm "$1" "$2" "$4" "$W" "$5"; rm -rf "$W"; }
aq_names() { # <ids> -> 0 when the deny names exactly that uncovered set, for the pass it leads
  # with or for another pass still owed (the `OTHER PASSES ... \`<stem>\` (<ids>)` clause)
  case "$AQ_OUT" in *"check(s) \`$1\`"*|*"OTHER PASSES STILL OWED A REPAIR"*"\` ($1)"*) return 0 ;; esac; return 1; }
aq_unbound() { case "$AQ_LOG" in *GATE_VERDICT_UNBOUND*) return 0 ;; esac; return 1; }
aq_deny() { # <case> <ids the deny must name> <label> -- AQ_OK=1 when all three assertions held
  local _aq0="$fails"
  aq_drive "$1"
  if denied "$AQ_OUT"; then ok "$3 -> DENIED"
  else bad "$3 -> ALLOWED: an unbound pass acquitted the gate"; fi
  if aq_unbound; then ok "$3: ...GATE_VERDICT_UNBOUND is in the flow log"
  else bad "$3: ...no GATE_VERDICT_UNBOUND in the flow log — the substitution is invisible"; fi
  if denied "$AQ_OUT" && aq_names "$2"; then ok "$3: ...and the deny names the uncovered check \`$2\`"
  else bad "$3: ...the deny does not name the uncovered check \`$2\`"; fi
  rm -rf "$W"
  AQ_OK=0; [ "$fails" = "$_aq0" ] && AQ_OK=1
}
aq_allow() { # <case> <flow event that must be logged> <label> -- AQ_OK=1 when both assertions held
  local _aq0="$fails"
  aq_drive "$1"
  if denied "$AQ_OUT"; then bad "$3 -> DENIED: the twin one property apart was refused"
  else ok "$3 -> ALLOWED"; fi
  case "$AQ_LOG" in *"$2"*) ok "$3: ...and $2 is logged" ;; *) bad "$3: ...$2 is not in the flow log" ;; esac
  rm -rf "$W"
  AQ_OK=0; [ "$fails" = "$_aq0" ] && AQ_OK=1
}

aq_deny suppressed-forged-unbound 3a "AQ-A (L2): a bound pass FAILing 3a+7, then an UNBOUND pass FAILing only the suppressed 7"
if [ "$AQ_OK" = 1 ]; then B_AQ_A=1; fi
aq_allow suppressed-forged-bound GATE_REMEDIATION_SUPPRESSED "AQ-A twin: the same newer pass BOUND by its write row"
aq_allow suppressed-unbound-substitute-covered GATE_REMEDIATION_SUPPRESSED "AQ-A twin: every FAIL in the convict set is covered"
aq_drive suppressed-unbound-substitute-covered
if aq_unbound; then ok "AQ-A twin: ...GATE_VERDICT_UNBOUND is still logged on the covered allow (the substitute was re-partitioned, not skipped)"
else bad "AQ-A twin: the covered allow logged no GATE_VERDICT_UNBOUND — the binding was never asked on this exit"; fi
rm -rf "$W"
aq_deny subst-newer-unbound-fail 3a "AQ-B: a bound CLEAN pass, a NEWER unbound pass FAILing 3a, a forged clean live pass"
if [ "$AQ_OK" = 1 ]; then B_AQ_B=1; fi
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
if [ "$AQ_OK" = 1 ]; then B_AQ_L3=1; fi
aq_allow subst-percatalog GATE_REMEDIATION_SUPPRESSED "AQ-CAT: ext-catalog passes FAILing 7 over a bound core CLEAN pass, \`[ext-catalog] 7\` in force"
if [ "$AQ_OK" = 1 ]; then B_AQ_CAT=1; fi
aq_drive subst-percatalog
if aq_unbound; then ok "AQ-CAT: ...GATE_VERDICT_UNBOUND is logged before the suppressed allow"
else bad "AQ-CAT: no GATE_VERDICT_UNBOUND on the per-catalog allow"; fi
rm -rf "$W"
aq_deny subst-repair-unbound 3a "AQ-R8: a repair record keyed on the UNBOUND live nonce, over a bound pass FAILing 3a"
aq_allow subst-repair-both GATE_REMEDIATION_LIFTED "AQ-R8 twin: each contributing pass carries its own repair record"
# THE CONVICT CONTROL. The live pass is unbound and its OWN FAIL on 3a is uncovered; that was a
# deny on the base hook and stays one, on the live pass's own check.
aq_drive subst-convict-own
if denied "$AQ_OUT" && aq_names 3a; then ok "AQ-CONVICT: an unbound live pass with an uncovered FAIL on 3a -> DENIED on its own check"; B_AQ_CONVICT=1
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
ad_mut() { # <mutator> -- applied to the workspace at W
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
ad_drive() { # <case> <mutator> [hook] -> AQ_OUT, AQ_LOG; the workspace stays at W
  seed "$1"; ad_mut "$2"
  AQ_OUT="$(drive "$W" Edit "$W/$ART" "" "$W/$TRC" "${3:-$HOOK}")"
  AQ_LOG="$(cat "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)"
}
ad_clean() { chmod -R u+rw "$W" 2>/dev/null; rm -rf "$W"; }
# THE MALFORMED-INPUT WORLDS, one line each: <label>|<case>|<mutator>|<file the deny must name>.
# Every arm and the mutants below iterate this one list, so a world added here is scored by both.
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
ad_skip() { # <mutator> -> 0 when this world cannot be built here
  case "$1" in nl|iw-nl) [ "$AD_NL" -eq 1 ] && return 1; return 0 ;; esac; return 1; }
# AD-IW-CONTROL: the IW worlds' seed, no decoy. It must ALLOW, or the IW denials are not the decoy's.
ad_drive suppressed-unbound-substitute-covered none
if denied "$AQ_OUT"; then bad "AD-IW-CONTROL: the in-window worlds' seed DENIES with no decoy — the IW arms cannot attribute their deny to the decoy"
else ok "AD-IW-CONTROL: the in-window worlds' seed with NO decoy -> ALLOWED (so each IW deny is the decoy's)"; fi
ad_clean
while IFS='|' read -r _al _ac _am _an; do
  [ -n "$_al" ] || continue
  ! ad_skip "$_am" || continue
  _adf0="$fails"
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
  if [ "$fails" = "$_adf0" ]; then
    case "$_al" in
      AD-UNPARSEABLE) B_ad_unparseable=1 ;;
      AD-DASH) B_ad_dash=1 ;;
      AD-IW-SPACE) B_ad_iwspace=1 ;;
      AD-SPACE) B_ad_space=1 ;;
      AD-CONVICT-MULTIDOC) B_ad_multidoc=1 ;;
      AD-IW-NONOBJ) B_ad_nonobj=1 ;;
      AD-IW-ZERO) B_ad_zero=1 ;;
      AD-IW-UNPARSE) B_ad_iwunparse=1 ;;
      AD-TRAIL-BOUND) B_ad_trailbound=1 ;;
    esac
  fi
  ad_clean
done <<ADEOF
$AD_WORLDS
ADEOF

# --- the malformed-input mutants. Each restores one way the set fell back to, or silently lost a
# pass. A mutant is scored with one kill per world it owns, and on the bound twin, which must
# still ALLOW, plus the convict control, which must still DENY (a dead copy ALLOWS everywhere).
# `_LA` is base's live-only adjudication: drop the set, give the live pass back its own waivers,
# allow a clean live pass, and otherwise send the live pass alone on to arm 7b.
#   m-fallback-live-alone  a pass jq refuses adjudicates the live pass alone instead of convicting
#                          as `(unreadable)`. Owns: AD-UNPARSEABLE, AD-IW-UNPARSE.
#   (`_LA` once restored the live pass's waivers from `_lw`, a variable the fix removed; every
#   `_LA` mutant then died under `set -u` and scored its kills by crashing. It re-reads them now.)
#   m-unsafe-live-alone    an unsafe stem or an unreadable file adjudicates the live pass alone.
#                          Owns: AD-UNREADABLE, AD-DASH, AD-IW-SPACE, AD-IW-NEWLINE, AD-IW-DASH.
#   m-unsafe-dropped       an unsafe stem is DROPPED rather than convicted. Owns the IW worlds
#                          only: the 2020 decoys never reach that check, and AD-DASH sits on
#                          forged-clean, whose bound pass FAILs and denies with the decoy gone.
#   m-stems-wordsplit      the candidates come from the word-split CONFORMING_STEMS with no
#                          timestamp filter, and a word naming no file falls back to the live pass
#                          alone -- the 2a9b768f7 read. Owns: AD-SPACE, AD-NEWLINE, AD-A-SPACE,
#                          AD-B-SPACE, AD-W4-SPACE.
#   m-multidoc-drops       a file carrying a second document drops out of the set (the multi-
#                          document read alone). Owns the three MULTIDOC. The convict set is the
#                          only read of the live pass's FAILs here (no union with arm 5's read),
#                          so dropping the live file drops its own 3a too.
#   m-join-drops           a pass whose per-file read printed nothing is DROPPED instead of
#                          convicted. Owns AD-IW-UNPARSE (a zero-byte file never reaches this line:
#                          jq's own empty check convicts it, which m-empty-doc-acquits owns).
# Only names the hook defines: an `_LA` naming a removed variable dies under the hook's `set -u`.
# Faithful to base's live-only path in all three of its parts: it LOGGED GATE_VERDICT_UNBOUND
# first, it re-read the live pass's own fail sets (so its FAIL_WAIVED rows reach the waiver join
# again), and it exited 0 on a clean live pass. `fail_sets` / `read_fail_sets` are the hook's own.
_LA='log_event GATE_VERDICT_UNBOUND "fixture mutant: the live pass is adjudicated alone."; CONVICT=""; read_fail_sets "$(fail_sets "$LIVE_VERDICT")"; if [ -z "$FAILED_CHECKS" ]; then exit 0; fi; return 0'
ad_kill() { # <mutant> <case> <mutator> -> 0 decided, 1 survived, 2 BROKEN; AD_EV the events
  seed "$2"; ad_mut "$3"; km_run "$1" "$W"; AD_EV="$KM_EV"; local r
  # Every AD world is unbound, so a mutant that reached a decision logged GATE_VERDICT_UNBOUND.
  if [ "$KM_RC" -ne 0 ] || [ -z "$KM_EV" ]; then r=2
  elif denied "$KM_OUT"; then r=1; else r=0; fi
  AD_RC="$KM_RC"; ad_clean; return $r
}
ad_score() { # <mutant> <base-pass flag> <deciding world> [other owned worlds, matrix-only...]
  local m="$1" others=" ${*:4} " al ac am an r hit role
  while IFS='|' read -r al ac am an; do
    [ -n "$al" ] || continue
    if [ "$al" = "$3" ]; then role=d
    else case "$others" in *" $al "*) role=x ;; *) continue ;; esac; fi
    mx_run "$role" || continue
    mx_count "$role"
    ad_skip "$am" && continue
    ad_kill "$m" "$ac" "$am"; r=$?
    case "$r" in
      0) hit=1 ;;
      1) hit=0 ;;
      *) bad "$m: $al — FIXTURE BROKEN: rc=$AD_RC, events [${AD_EV% }]; a dead mutant is not a kill"; continue ;;
    esac
    if [ "$role" = d ]; then mx_kill "$2" "$m" "$al" "$hit" "$m: decided by $al ($ac + $am) — events: ${AD_EV% }"
    else mx_obs "$m" "$al" x "$hit"; fi
  done <<ADEOF2
$AD_WORLDS
ADEOF2
  KM_NEED_EV=1
  aq_hold t "$m" suppressed-forged-bound allow "$m: ...and the bound twin is unchanged (still ALLOW)"
  aq_hold x "$m" subst-convict-own deny "$m: ...and the convict control is unchanged (still DENY)"
  KM_NEED_EV=0
}
# THE CRASH GUARD'S SEEDED CONTROL. The `_LA` that shipped crashed: it named `_lw`, which the fix
# removed. Kept here once, on purpose, so the guard above is shown to fire: it must come back
# BROKEN (2), never killed (0).
# THE PER-FILE READ LINE every jq-failure mutant below anchors on, captured in two halves so no
# replacement has to retype its `&&` (an `&` in a sed replacement is the whole match).
_RD='^\(    \[ -r "\$_f" \] && { _n="\$(jq -rn "\$CONVICT_PROG" "\$_f" 2>/dev/null)"\) || _n=""; }$'
if mut m-crash-control "s@${_RD}@\\1 || { CONVICT=\"\"; WAIVED_CANDIDATES=\"\$_lw\"; return 0; }; }@"; then
  ad_kill m-crash-control suppressed-unbound-substitute-covered iw-unparse; _cr=$?
  if [ "$_cr" -eq 2 ]; then ok "CONTROL m-crash-control: a mutant dying on an unbound variable (rc=$AD_RC) is reported BROKEN, not scored as a kill"
  else bad "CRASH GUARD: a mutant that dies under set -u scored $_cr (0=decided, 1=survived) — a dead mutant can pass again"; fi
fi
# ...and the guard's OTHER half: a mutant that exits 0 having decided nothing. `exit 0` in place
# of the convict set allows with rc=0 and writes no event; it must come back BROKEN too.
if mut m-silent-control 's@^  unbound|unbound-malformed) unbound_convict_set ;;$@  unbound|unbound-malformed) exit 0 ;;@'; then
  ad_kill m-silent-control suppressed-unbound-substitute-covered iw-unparse; _cr=$?
  if [ "$_cr" -eq 2 ] && [ "$AD_RC" -eq 0 ]; then ok "CONTROL m-silent-control: a mutant that exits 0 and logs no event is reported BROKEN, not scored as a kill"
  else bad "CRASH GUARD: a silent rc=0 mutant scored $_cr (rc=$AD_RC) — the event half of the guard cannot fire"; fi
fi
if mut m-fallback-live-alone "s@${_RD}@\\1 || { ${_LA}; }; }@"; then
  ad_score m-fallback-live-alone "${B_ad_unparseable:-0}" AD-UNPARSEABLE AD-IW-UNPARSE
fi
if mut m-unsafe-live-alone "s@^        continue ;;\$@        ${_LA} ;;@;s@^    \\[ -r \"\\\$_f\" \\] && {@    [ -r \"\$_f\" ] || { ${_LA}; }; [ -r \"\$_f\" ] \\&\\& {@"; then
  ad_score m-unsafe-live-alone "${B_ad_dash:-0}" AD-DASH AD-UNREADABLE AD-IW-SPACE AD-IW-NEWLINE AD-IW-DASH
fi
if mut m-unsafe-dropped 's@^        _bad="\$(printf .*$@        continue@'; then
  ad_score m-unsafe-dropped "${B_ad_iwspace:-0}" AD-IW-SPACE AD-IW-NEWLINE AD-IW-DASH
fi
if mut m-stems-wordsplit 's@^  for _f in "\$GATE_DIR"/\*\.verdict\.json; do$@  for _f in $(printf "%s" "$CONFORMING_STEMS" | sed "s|^|$GATE_DIR/|;s|$|.verdict.json|"); do@;s@^    \[ -f "\$_f" \] || continue$@    if [ ! -f "$_f" ]; then '"$_LA"'; fi@;s@^      \*) continue ;;$@      *) ;;@'; then
  ad_score m-stems-wordsplit "${B_ad_space:-0}" AD-SPACE AD-NEWLINE AD-A-SPACE AD-B-SPACE AD-W4-SPACE
fi
if mut m-multidoc-drops 's@^\[inputs\] as \$docs$@([inputs] | if length > 1 then [{}] else . end) as $docs@'; then
  ad_score m-multidoc-drops "${B_ad_multidoc:-0}" AD-CONVICT-MULTIDOC AD-A-MULTIDOC AD-B-MULTIDOC
fi
#   m-nonobj-acquits       a file with a non-object document reads as a pass with NO FAILs rather
#                          than `(unreadable)`. Owns AD-IW-NONOBJ. It cannot see the TRAIL worlds:
#                          each file is read alone, so a forger's unterminated scalar stays in the
#                          forger's own file and never reaches the honest one either way.
if mut m-nonobj-acquits 's@^  then \["(unreadable)", "(unreadable)", "(unreadable)", ""\]$@  then ["", "", "", ""]@'; then
  ad_score m-nonobj-acquits "${B_ad_nonobj:-0}" AD-IW-NONOBJ
fi
#   m-empty-doc-acquits    a file holding NO document reads as a pass with no FAILs. Owns
#                          AD-IW-ZERO (jq's own empty check, not the join, is what catches it now).
if mut m-empty-doc-acquits 's@(\$docs | length) == 0 or @@'; then
  ad_score m-empty-doc-acquits "${B_ad_zero:-0}" AD-IW-ZERO
fi
#   m-stream-bleed         the cross-file read the fix removed: each file is piped to jq after the
#                          one before it, so a forger's unterminated scalar is completed by the
#                          honest neighbour's bytes. The deny still stands, so this is scored on
#                          what it NAMES: the honest pass's 3a lost, or the honest file blamed as
#                          an unreadable record. Owns AD-TRAIL-BOUND and AD-TRAIL-LIVE.
if mut m-stream-bleed "s@^\\(    \\[ -r \"\\\$_f\" \\] && { _n=\"\\\$(\\)jq -rn \"\\\$CONVICT_PROG\" \"\\\$_f\"\\( 2>/dev/null)\" || _n=\"\"; }\\)\$@\\1cat \${_pv:+\"\$_pv\"} \"\$_f\" | jq -rn \"\$CONVICT_PROG\"\\2; _pv=\"\$_f\"@"; then
  while IFS='|' read -r _al _ac _am _an; do
    case "$_al" in AD-TRAIL-BOUND) _sbrole=d ;; AD-TRAIL-LIVE) _sbrole=x ;; *) continue ;; esac
    mx_run "$_sbrole" || continue
    mx_count "$_sbrole"
    _honest=story-20260811T193044Z; [ "$_al" = AD-TRAIL-LIVE ] && _honest=story-20260811T210000Z
    seed "$_ac"; ad_mut "$_am"; km_run m-stream-bleed "$W"; AQ_OUT="$KM_OUT"
    _ur="$(printf '%s' "$KM_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null | grep '^UNREADABLE GATE RECORDS:' | sed 's/ in `.*//' | head -1)"
    _sbhit=0
    if [ "$KM_RC" -ne 0 ] || [ -z "$KM_EV" ]; then bad "m-stream-bleed: $_al — FIXTURE BROKEN: rc=$KM_RC, events [${KM_EV% }]"; ad_clean; continue
    elif ! aq_names 3a; then _sbhit=1; _sbwhy="the honest pass's 3a is no longer named (events: ${KM_EV% })"
    else case "$_ur" in *"$_honest"*) _sbhit=1; _sbwhy="the honest file $_honest is blamed as unreadable (events: ${KM_EV% })" ;; *) _sbwhy="$_al names 3a and does not blame $_honest under the mutant — the arm does not see the bleed" ;; esac
    fi
    if [ "$_sbrole" = d ]; then mx_kill "${B_ad_trailbound:-0}" m-stream-bleed "$_al" "$_sbhit" "m-stream-bleed: decided by $_al — $_sbwhy"
    else mx_obs m-stream-bleed "$_al" x "$_sbhit"; fi
    ad_clean
  done <<ADEOF3
$AD_WORLDS
ADEOF3
  KM_NEED_EV=1
  aq_hold t m-stream-bleed suppressed-forged-bound allow "m-stream-bleed: ...and the bound twin is unchanged (still ALLOW)"
  aq_hold x m-stream-bleed subst-convict-own deny "m-stream-bleed: ...and the convict control is unchanged (still DENY)"
  KM_NEED_EV=0
fi
# THE ALLOW-EVENT GUARD'S SEEDED CONTROL: a silent `exit 0` where an allow was expected. On S1
# (`suppressed`, a bound pass whose FAIL is covered) the real allow logs SUPPRESSED; this one logs
# nothing and must be reported BROKEN, not scored as the allow it imitates.
if mut m-silent-allow-control 's@^if \[ -z "\$FAILED_CHECKS" \]; then$@if true; then exit 0; fi; if [ -z "$FAILED_CHECKS" ]; then@'; then
  seed suppressed
  _sab="$fails"; hold_arm c m-silent-allow-control allow "$W" "m-silent-allow-control (must be reported BROKEN)" >/dev/null
  if [ "$fails" -gt "$_sab" ]; then fails="$_sab"; ok "CONTROL m-silent-allow-control: a mutant that allows by a silent exit 0 is reported BROKEN, not scored as an allow"
  else bad "ALLOW-EVENT GUARD: a silent exit 0 scored as the expected allow — the guard cannot fire"; fi
  rm -rf "$W"
fi
if mut m-join-drops 's@^    \[ -n "\$_n" \] || _n="(unreadable).*$@    [ -n "$_n" ] || continue@'; then
  ad_score m-join-drops "${B_ad_iwunparse:-0}" AD-IW-UNPARSE
fi

# --- arm 7a at acquittal, under mutation. Each mutant is scored on the seed it owns and on one
# twin it must NOT move; every anchor is a line the at-acquittal fix introduced.
#   m-livecl-only       the binding asked only of a CLEAN pass again (BL-837 itself): the forged
#                       covered pass is acquitted by 7b. Twin: world B, whose live pass is clean.
#   m-subst-no-failset  the convict set built and logged, and only the LIVE pass partitioned: the
#                       other passes' FAILs are never read. Twin: the convict control (DENY).
#   m-subst-bound-only  the set narrowed to the bound pass and the live one (the :1228 read): an
#                       unbound FAIL newer than a clean bound pass is skipped. Owns L3 and world B.
#                       Twin: world A, whose bound pass itself fails.
#   m-subst-boundcat    every pass partitioned under the BOUND pass's catalog. Owns the per-catalog
#                       allow. Twin: world A, all one catalog.
# Each drive is a fresh workspace: arm 7b caches its rows, and these edits sit below that read.
if mut m-livecl-only 's@^  unbound|unbound-malformed) unbound_convict_set ;;$@  unbound|unbound-malformed) [ "$LIVE_CLEAN" -eq 1 ] \&\& unbound_convict_set ;;@'; then
  aq_kill "${B_AQ_A:-0}" m-livecl-only suppressed-forged-unbound allow "m-livecl-only: asking the binding of a clean pass only ALLOWS world A — the at-acquittal question is load-bearing"
  aq_hold t m-livecl-only subst-newer-unbound-fail deny "m-livecl-only: ...and world B, a clean live pass, still DENIES under it"
fi
if mut m-subst-no-failset 's@^    partition_pass "\$_pc" "\${GATE_DIR}/\${_ps}.verdict.json"$@    [ "$_ps" = "$LIVE_STEM" ] || continue; partition_pass "$_pc" "${GATE_DIR}/${_ps}.verdict.json"@'; then
  aq_kill "${B_AQ_A:-0}" m-subst-no-failset suppressed-forged-unbound allow "m-subst-no-failset: substituting without reading the set's other FAILs ALLOWS world A (L2)"
  # The twin is a DENY: an allow twin cannot move under a mutant that never runs (a dead copy
  # allows on both sides). The convict control denies on the live pass's own 3a, which this
  # mutant still partitions.
  aq_hold t m-subst-no-failset subst-convict-own deny "m-subst-no-failset: ...and the convict control is unchanged (still DENY on the live pass's own FAIL)"
fi
if mut m-subst-bound-only 's@^    \[ "\${_s##\*-}" \\< "\$_b" \] && continue$@    [ -z "$_b" ] || [ "$_s" = "$BOUND_STEM" ] || [ "$_s" = "$LIVE_NONCE" ] || continue@'; then
  aq_kill "${B_AQ_L3:-0}" m-subst-bound-only subst-crossgate allow "m-subst-bound-only: reading only the bound pass ALLOWS L3 — the unbound story FAIL above a clean bound planning pass goes unread"
  aq_hold x m-subst-bound-only subst-newer-unbound-fail allow "m-subst-bound-only: ...and ALLOWS world B (the :1228 hole)"
  aq_hold t m-subst-bound-only suppressed-forged-unbound deny "m-subst-bound-only: ...and world A, whose bound pass fails 3a itself, still DENIES"
fi
if mut m-subst-boundcat 's@^    partition_pass "\$_pc" "\${GATE_DIR}/\${_ps}.verdict.json"$@    partition_pass "$(jq -r ".catalog // \\"\\"" "${GATE_DIR}/${BOUND_STEM:-$LIVE_STEM}.verdict.json" 2>/dev/null)" "${GATE_DIR}/${_ps}.verdict.json"@'; then
  aq_kill "${B_AQ_CAT:-0}" m-subst-boundcat subst-percatalog deny "m-subst-boundcat: partitioning under the bound pass's catalog DENIES the per-catalog allow — each pass's own catalog is load-bearing"
  aq_hold t m-subst-boundcat suppressed-forged-unbound deny "m-subst-boundcat: ...and world A, one catalog throughout, is unchanged (still DENY)"
fi
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
_e10="$fails"
e1_drive_all "$HOOK"
[ "$fails" = "$_e10" ] && B_e1=1
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
    if [ "$_e1c" = 1 ]; then ok "1b-bind: the probe's role expression ($E1_EXPR) occurs exactly once in the guard"; B_e1bind=1
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
    ok "1b-name-strip: the dispatch guard's role-bound rewrite deletes \`name\` (emission count 1; impossible-anchor control 0)"; B_nstrip=1
  else
    bad "1b-name-strip: the dispatch guard's \`del(.name)\` emission count is $_e1s (want 1; control $_e1z, want 0) — a named remediator's meta then carries its spawn name in agentType, and arm 1b ALLOWS it"
  fi
  # The arm can fire: a copy with `del(.name) | ` removed must score 0.
  cp "$DGUARD" "$MW/dguard-nostrip.sh"
  sed -i.bak 's@del(\.name) | @@' "$MW/dguard-nostrip.sh"; rm -f "$MW/dguard-nostrip.sh.bak"
  if cmp -s "$DGUARD" "$MW/dguard-nostrip.sh"; then
    bad "MUTANT dguard-nostrip: the sed changed NO bytes — it matched nothing, and its silence would score as a kill"
  elif ! bash -n "$MW/dguard-nostrip.sh" 2>/dev/null; then
    bad "MUTANT dguard-nostrip: the copy does not parse"
  else
    _e1m="$(e1_strip_count "$MW/dguard-nostrip.sh" "$E1_STRIP")"
    mx_kill "${B_nstrip:-0}" m-dguard-nostrip name-strip "$([ "$_e1m" = 0 ] && echo 1 || echo 0)" "1b-name-strip: a dispatch guard with \`del(.name)\` removed is reported (emission count 0) — the binding can fire"
  fi
fi

# --- arm 1b's mutants. Each moves only its own cells; every other cell must hold.
e1_cell_hit() { # <hook> <id> -> prints 1 when the cell's verdict differs from the unmutated verdict
  local o w
  while IFS='|' read -r _id _want _tool _fp _ag _tr _lab; do
    [ "$_id" = "$2" ] || continue
    [ "$_tr" = "-" ] && _tr=""
    o="$(drive "$W" "$_tool" "$_fp" "$_ag" "$_tr" "$1")"
    if denied "$o"; then w=deny; else w=allow; fi
    [ "$w" != "$_want" ] && printf 1 || printf 0
    return
  done <<E1EOF
$E1_CELLS
E1EOF
  printf ERR
}
e1_mut() { # <mutant> <ids that FLIP, matrix-checked> <deciding id> <twin id> <label>
  local m="$1" flips=" $2 " did="$3" tid="$4" h x ids=""
  h="$(e1_cell_hit "$MW/$m.sh" "$did")"; mx_kill "${B_e1:-0}" "$m" "1b-$did" "$([ "$h" = 1 ] && echo 1 || echo 0)" "$5"
  h="$(e1_cell_hit "$MW/$m.sh" "$tid")"; mx_hold t "$m" "1b-$tid" "$([ "$h" = 0 ] && echo 1 || echo 0)" "$m: ...and the twin cell $tid is UNCHANGED"
  if mx_run x; then
    mx_count x
    while IFS='|' read -r x _r; do
      [ -n "$x" ] || continue
      h="$(e1_cell_hit "$MW/$m.sh" "$x")"
      [ "$x" = "$did" ] || [ "$x" = "$tid" ] || mx_obs "$m" "1b-$x" x "$([ "$h" = 1 ] && echo 1 || echo 0)"
      [ "$h" = 1 ] && ids="$ids$x "
    done <<E1EOF
$E1_CELLS
E1EOF
    if [ " $ids" = "$flips" ]; then ok "$m: the full cell vector flipped exactly '${ids% }' (matrix)"
    else bad "$m: the full cell vector flipped '${ids% }', wanted '${2}'"; fi
  fi
}

if mut m1b-role-nothing 's@^                remediator)$@                remediator-matches-nothing)@'; then
  e1_mut m1b-role-nothing "E1 E2 E3 E4" E1 A1 "M1b-role: a role test that matches nothing ALLOWS the remediator's deny cell"
fi
if mut m1b-path-widened 's@^        \*pending\.md\*)$@        *)@;s@^            \*/docs/escalations/pending\.md)$@            *)@'; then
  e1_mut m1b-path-widened "A4 A10 A11 A12" A4 A1 "M1b-path: both path tests widened to every path DENY the remediator's other-docs Edit"
fi
# THE INNER EXACT TEST ALONE. A4 fails the `*pending.md*` prefilter, so only A10-A12 -- which pass
# it -- can see a widening of the exact test. Anchored on the 12-space indent the inner line has
# and the prefilter's 8-space line does not; A4 staying put is what separates it from m1b-path.
if mut m1b-inner-widened 's@^            \*/docs/escalations/pending\.md)$@            *)@'; then
  e1_mut m1b-inner-widened "A10 A11 A12" A10 A4 "M1b-inner: the exact test widened alone DENIES a pending.md past the prefilter"
fi
if mut m1b-absent-denies 's@^              DEFINITION=""$@              DEFINITION="remediator"@'; then
  e1_mut m1b-absent-denies "A5 A7" A5 A1 "M1b-open: reading an UNREADABLE meta as remediator DENIES the no-meta cell — fail-open is asserted"
fi
if mut m1b-unparseable-denies 's@"\$META" 2>/dev/null || true)"@"$META" 2>/dev/null || echo remediator)"@'; then
  e1_mut m1b-unparseable-denies "A6" A6 A1 "M1b-parse: reading an UNPARSEABLE meta as remediator DENIES the unparseable cell"
fi
if mut m1b-key-order "s@jq -r '.customAgentType // .agentType // empty' \"\\\$META\"@jq -r '.agentType // .customAgentType // empty' \"\$META\"@"; then
  e1_mut m1b-key-order "E4 A8" E4 A1 "M1b-order: agentType read first ALLOWS the named remediator"
  _e1c="$(grep -cF -- "jq -r '$E1_EXPR'" "$MW/m1b-key-order.sh")" || _e1c=0
  mx_kill "${B_e1bind:-0}" m1b-key-order-bind 1b-bind "$([ -n "$E1_EXPR" ] && [ "$_e1c" = 0 ] && echo 1 || echo 0)" "1b-bind: the key-order drift in a copy is reported (expression count 0) — the binding can fire"
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
if [ "$R_PRESENT" = 3 ]; then ok "R: all three spellings of the part file record one artifact-write row each, under ONE normalised path (3)"; B_Rpresent=1
else bad "R: $R_PRESENT row(s) for $R_REL (want 3: LOG_DIR, relative and foreign-absolute spellings)"; fi
if [ "$R_PRESENT" != 0 ]; then
  if [ "$R_KIND" = "$R_PRESENT" ]; then ok "R: every part-file row carries kind artifact-write ($R_KIND/$R_PRESENT)"; B_Rkind=1
  else bad "R: $R_KIND of $R_PRESENT part-file rows carry kind artifact-write — every reader filters on kind"; fi
  [ "$R_AGENT" = "$R_PRESENT" ] && ok "R: every part-file row names the adjudicator's agent_id g7adj" \
    || bad "R: $R_AGENT of $R_PRESENT part-file rows name g7adj"
  if [ "$R_RH" = 2 ] && [ "$R_RE" = 1 ]; then ok "R: root names the tree each write landed in: 2 rows this workspace, 1 /elsewhere (BL-596)"; B_Rroot=1
  else bad "R: root rows this workspace=$R_RH /elsewhere=$R_RE (want 2, 1)"; fi
fi
[ "$R_TWIN" = 0 ] && ok "R: the same adjudicator's Write to <nonce>.repair.md (not a part file) records NO artifact row" \
  || bad "R: a non-part gate-adjudication write recorded $R_TWIN artifact row(s)"
if [ "$R_VN" = "$R_V0" ]; then ok "R: the verdict ledger still holds exactly $R_V0 rows — no part row entered it"
else bad "R: the verdict ledger went from $R_V0 to $R_VN rows"; fi
# Mutants: (i) the three part-file lines deleted; (ii) the kind dropped from the row. Each owns one
# assertion: (i) the row-present count, (ii) the kind count. The kind and agent arms stand down
# when no row is present, so (i) fails exactly one.
if mut mr-no-part-case '/gate-adjudication\/\*\.part-\*\.jsonl) _raw_rel=/d'; then
  r_world; r_drive "$MW/mr-no-part-case.sh"; r_score
  mx_kill "${B_Rpresent:-0}" mr-no-part-case R-present "$([ "$R_PRESENT" = 0 ] && echo 1 || echo 0)" "MR-case: without the part-file lines no row is recorded (0)"
  mx_hold t mr-no-part-case R-verdict "$([ "$R_TWIN" = 0 ] && [ "$R_VN" = "$R_V0" ] && echo 1 || echo 0)" "MR-case: ...and the twin and verdict-ledger arms hold"
fi
if mut mr-no-kind 's@{v: 1, kind: "artifact-write", ts: \$ts, path: \$path@{v: 1, ts: $ts, path: $path@'; then
  r_world; r_drive "$MW/mr-no-kind.sh"; r_score
  mx_kill "${B_Rkind:-0}" mr-no-kind R-kind "$([ "$R_KIND" = 0 ] && echo 1 || echo 0)" "MR-kind: rows without kind are present and the kind arm reads 0"
  mx_hold t mr-no-kind R-present "$([ "$R_PRESENT" = 3 ] && [ "$R_AGENT" = 3 ] && [ "$R_VN" = "$R_V0" ] && echo 1 || echo 0)" "MR-kind: ...and the present, agent and verdict-ledger arms hold"
fi
# (iii) the fallback spelling's root dropped, so a foreign-absolute write takes this tree's root: the
# root arm alone moves, 3 rows this workspace and none /elsewhere.
if mut mr-root-fallback 's@; _raw_root="\${1%%/\${STATE_DIR_NAME}/\*}" ;;@ ;;@g'; then
  r_world; r_drive "$MW/mr-root-fallback.sh"; r_score
  mx_kill "${B_Rroot:-0}" mr-root-fallback R-root "$([ "$R_RH" = 3 ] && [ "$R_RE" = 0 ] && echo 1 || echo 0)" "MR-root: without the fallback's root every row names this workspace (3) and none /elsewhere"
  mx_hold t mr-root-fallback R-kind "$([ "$R_PRESENT" = 3 ] && [ "$R_KIND" = 3 ] && echo 1 || echo 0)" "MR-root: ...and the present and kind arms hold"
fi
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
md_moved() { # <cell> -> 1 when the cell's recorded value differs from its unmutated value
  case "$1" in
    MD1) [ "$MD1" != "$MD1_W" ] ;; MD2) [ "$MD2" != "$MD1_W" ] ;; MD3) [ "$MD3" != "$MD1_W" ] ;;
    MD4) [ "$MD4" != "$MD4_W" ] ;; MD5) [ "$MD5" != "$MD5_W" ] ;; MD6) [ "$MD6" != "$MD6_W" ] ;;
    MD7) [ "$MD7" != "$MD7_W" ] ;; MD8) [ "$MD8" != "$MD8_W" ] ;; MD9) [ "$MD9" != "$MD9_W" ] ;;
    MD9C) [ "$MD9C" != "$MD1_W" ] ;;
  esac && printf 1 || printf 0
}
md_mut() { # <mutant> <deciding cell> <base-pass flag> <twin cell> <label> -- one world pair, the deciding and twin cells only; --matrix drives all ten
  local m="$1" x
  if [ "$MATRIX" = 1 ]; then md_run "$MW/$m.sh"; else md_run "$MW/$m.sh" "$2" "$4"; fi
  mx_kill "$3" "$m" "$2" "$(md_moved "$2")" "$5"
  mx_hold t "$m" "$4" "$([ "$(md_moved "$4")" = 0 ] && echo 1 || echo 0)" "$m: ...and $4 is UNCHANGED"
  if mx_run x; then
    mx_count x
    for x in MD1 MD2 MD3 MD4 MD5 MD6 MD7 MD8 MD9 MD9C; do
      [ "$x" = "$2" ] || [ "$x" = "$4" ] || mx_obs "$m" "$x" x "$(md_moved "$x")"
    done
  fi
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
if [ "$MD1" = "$MD1_W" ]; then ok "MD1: one absolute write to a document TWO split manifests name -> exactly ONE row, project-relative ($MD1)"; B_MD1=1
else bad "MD1: the sections document recorded '$MD1' (want '$MD1_W')"; fi
[ "$MD2" = "$MD1_W" ] && ok "MD2: the same document by a RELATIVE payload path -> ONE row, the same spelling" \
  || bad "MD2: the relative spelling recorded '$MD2' (want '$MD1_W')"
[ "$MD3" = "$MD1_W" ] && ok "MD3: the same document through a directory symlink -> ONE row, the same spelling (the directory is resolved physically)" \
  || bad "MD3: the symlinked spelling recorded '$MD3' (want '$MD1_W')"
if [ "$MD4" = "$MD4_W" ]; then ok "MD4: the same BASENAME in another directory, named by no manifest -> NO row (MD1 is its twin)"; B_MD4=1
else bad "MD4: a same-basename near-miss recorded '$MD4'"; fi
if [ "$MD5" = "$MD5_W" ]; then ok "MD5: the same RELATIVE path in another tree inside the project (BL-596) -> NO row"; B_MD5=1
else bad "MD5: the other-tree near-miss recorded '$MD5'"; fi
if [ "$MD6" = "$MD6_W" ]; then ok "MD6: a manifest's document INSIDE the state dir outside planning-artifacts/ -> ONE row in the state spelling ($MD6)"; B_MD6=1
else bad "MD6: the in-state document recorded '$MD6' (want '$MD6_W')"; fi
if [ "$MD7" = "$MD7_W" ]; then ok "MD7: AI_DLC_STATE_DIR=x/_bmad-output, the document at x/docs/ -> ONE row, project-relative ($MD7), never relative to the state dir's parent"; B_MD7=1
else bad "MD7: the nested-layout document recorded '$MD7' (want '$MD7_W')"; fi
if [ "$MD8" = "$MD8_W" ]; then ok "MD8: nested, a document inside the state dir outside planning-artifacts/ -> the state-spelling branch: '$MD8', not x/_bmad-output/..."; B_MD8=1
else bad "MD8: the nested in-state document recorded '$MD8' (want '$MD8_W')"; fi
if [ "$MD9" = "$MD9_W" ]; then ok "MD9: a payload <project>/lnkup/../docs/design-notes.md, which the kernel writes to else/docs/, -> NO row"; B_MD9=1
else bad "MD9: the lnkup/.. payload recorded '$MD9' (the kernel writes the decoy else/docs/design-notes.md)"; fi
if [ "$MD9C" = "$MD1_W" ]; then ok "MD9-ctl: the same run's direct <project>/docs/design-notes.md write -> ONE row ($MD9C)"; B_MD9C=1
else bad "MD9-ctl: the direct write recorded '$MD9C' (want '$MD1_W')"; fi
# MD's mutants, each a copy guarded by cmp -s and bash -n in mut(), each killing its own cell while a named
# control cell holds. md-raw-root: the project dir replaced by the state dir's parent (`_raw_root`), which is the
# project dir in the default layout, so only MD7 separates them. md-basename: the full comparison dropped, so a
# basename hit records. md-suffix: the comparison on the last two path components, which MD4 cannot see and MD5
# can. md-no-state-spelling: the state-dir case deleted, which in the default layout spells the same string.
if mut md-raw-root 's@_mdr_pp="\$(cd -P "\$PROJECT_DIR" @_mdr_pp="$(cd -P "${LOG_DIR%/*}" @'; then
  md_mut md-raw-root MD7 "${B_MD7:-0}" MD1 "MD-m2 spelled relative to _raw_root: decided by MD7"
fi
if mut md-basename 's@\[ "\$_mdr_l" = "\$_mdr_abs" \] && _mdr_hit=1@_mdr_hit=1@'; then
  md_mut md-basename MD4 "${B_MD4:-0}" MD1 "MD-m3 basename-only match: decided by MD4"
fi
if mut md-suffix 's@\[ "\$_mdr_l" = "\$_mdr_abs" \] && _mdr_hit=1@[ "${_mdr_l#"${_mdr_l%/*/*}"/}" = "${_mdr_abs#"${_mdr_abs%/*/*}"/}" ] \&\& _mdr_hit=1@'; then
  md_mut md-suffix MD5 "${B_MD5:-0}" MD4 "MD-m3b dir/basename suffix match: decided by MD5"
fi
if mut md-no-state-spelling '/^    "\$_mdr_sp"\/\*) _mdr_rel=/d'; then
  md_mut md-no-state-spelling MD8 "${B_MD8:-0}" MD6 "MD-mgap the state-spelling case deleted: decided by MD8"
fi
# md-cd-logical: the written file's directory resolved by a logical `cd`, which folds lnkup/.. textually
# into the project root, so the decoy write records the manifest's document. Only manifest_doc_rel's line.
if mut md-cd-logical 's@_mdr_d="\$(cd -P @_mdr_d="$(cd @'; then
  md_mut md-cd-logical MD9 "${B_MD9:-0}" MD9C "MD-mcd logical cd: decided by MD9"
fi

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
    if denied "$o"; then ok "$2"; B_lpe=1; else bad "$2"; fi
  else
    if denied "$o"; then bad "$2"; else ok "$2"; B_lpe=1; fi
  fi
}
lpe_hit() { # <expect deny|allow> <file_path> <transcript> <hook> -> prints 1 when the verdict is <expect>
  local o; o="$(drive "$W" Edit "$2" "" "$3" "$4")"
  if [ "$1" = deny ]; then denied "$o" && printf 1 || printf 0; else denied "$o" && printf 0 || printf 1; fi
}
lpe_lbl() { # <path> -> a cell id unique across the 3b cells: the basename, qualified by the sibling worktree or the nx traversal
  local l="${1##*/}"
  case "$1" in "$SIB"/*) l="sib-$l" ;; esac
  case "$1" in */nx/*) l="nx-$l" ;; esac
  printf '3b-%s' "$l"
}
lpe_mut() { # <mutant> <flag> <deciding expect> <deciding path> <deciding tx> <twin expect> <twin path> <twin tx> <label>
  local m="$1" h
  h="$(lpe_hit "$3" "$4" "$5" "$MW/$m.sh")"; mx_kill "$2" "$m" "$(lpe_lbl "$4")" "$h" "$9"
  h="$(lpe_hit "$6" "$7" "$8" "$MW/$m.sh")"; mx_hold t "$m" "$(lpe_lbl "$7")" "$h" "$m: ...and the twin cell is UNCHANGED"
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
lpe allow "3b: a path under a grammar scan root (seeded: reports/) is ALLOWED"             "$W/reports/r.md" "$TA"
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
# `exec`, so the pid the hook kills IS the sleeper; it records that pid first, so this arm can
# prove the sleeper was reaped rather than assume it.
#
# THE VERDICT IS BINARY, NEVER A WALL-CLOCK FIGURE. The hook gives up after 50 ticks of `sleep 0.1`,
# and a tick is slower than 0.1s on a loaded box, so any elapsed-time threshold is a property of the
# load. The proof that the bound fired is two attributes: the edit is DENIED, and the sleeper's
# recorded pid is DEAD when `drive` returns. A hook with no bound would still be waiting on a live
# 600s sleeper, so a dead pid cannot be reached without abandoning it. Elapsed is printed, not judged.
_hpid="$W.hang.sleeper.pid"
rm -f "$_hpid"
printf '#!/bin/bash\necho "$$" > "%s"\nexec sleep 600\n' "$_hpid" > "$W.hang/scripts/ai-dlc/artifact-path-config.sh"
_h0=$(date +%s)
OUT="$(drive "$W.hang" Edit "$W.hang/src/app.py" "" "$TA")"
_h1=$(date +%s)
if denied "$OUT"; then ok "3b: a hung scan-roots resolver is abandoned and the product edit is still DENIED (elapsed $((_h1 - _h0))s, not judged)"
else bad "3b: a hung scan-roots resolver: the product edit was not DENIED (elapsed $((_h1 - _h0))s)"; fi
# THE SLEEPER IS GONE, by the pid it recorded -- never by a process-table grep. The hook `wait`s the
# pid it killed before returning, so it is dead by the time `drive` returns. A missing pid file means
# the resolver never ran, and then the bound above was never exercised.
_hs="$(cat "$_hpid" 2>/dev/null)"
case "$_hs" in
  ''|*[!0-9]*) bad "3b: the hung resolver never recorded its pid, so the bound above was never exercised" ;;
  *) if kill -0 "$_hs" 2>/dev/null; then
       kill "$_hs" 2>/dev/null
       bad "3b: the hung resolver (pid $_hs) was still alive after the hook returned -- abandoned but not reaped"
     else ok "3b: the hung resolver (pid $_hs) was reaped, not left running"
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
  elif [ "$B_ACK" = "$B_HOOK" ]; then ok "3b-bind: the session-class scan is byte-identical in both hooks"; B_3bbind=1
  else bad "3b-bind: the session-class scan has FORKED between ai-dlc-acknowledge.sh and this hook"; fi
  cp "$HOOK" "$MW/drift.sh"
  sed -i.bak '/^  LAST_SKILL=/s/| tail -1)$/| tail -n 1)/' "$MW/drift.sh"; rm -f "$MW/drift.sh.bak"
  if cmp -s "$HOOK" "$MW/drift.sh"; then bad "3b-bind: the drift seed changed no bytes"
  else mx_kill "${B_3bbind:-0}" m-3b-drift 3b-bind "$([ "$(skill_block "$MW/drift.sh")" = "$B_ACK" ] && echo 0 || echo 1)" "3b-bind: a one-token drift in the copy is reported (the binding can fire)"; fi
fi

# --- arm 3b's mutants. Each moves its own cell; each leaves P1 (or, for M3b-gate, the
# sibling-_bmad-output allow) unchanged so a mutant that breaks the hook cannot score.
B_3b=0
_3b0="$fails"
lpe deny "3b base: P1 (a lead product Edit with an /ai-dlc transcript) is DENIED" "$W/src/app.py" "$TA"
lpe allow "3b base: the sibling worktree's _bmad-output/ path is ALLOWED" "$SIB/_bmad-output/planning-artifacts/x.md" "$TA"
[ "$fails" = "$_3b0" ] && B_3b=1
if mut m3b-no-iv 's@^    if \[ "\$AIDLC_SESSION" -eq 1 \]; then$@    if true; then@'; then
  lpe_mut m3b-no-iv "${B_3b:-0}" deny "$W/src/app.py" "$TP" allow "$SIB/_bmad-output/planning-artifacts/x.md" "$TA" "M3b-iv: dropping (iv) DENIES the non-pipeline session's product edit — (iv) is load-bearing"
fi
if mut m3b-no-worktree 's@_lpe_wts="\$(git -C "\$LPE_PROJ" worktree list --porcelain 2>/dev/null | sed -n .s/^worktree //p.)"@_lpe_wts=""@'; then
  lpe_mut m3b-no-worktree "${B_3b:-0}" allow "$SIB/src/app.py" "$TA" deny "$W/src/app.py" "$TA" "M3b-wt: without worktree anchoring the sibling worktree's src/app.py is ALLOWED — anchoring is load-bearing"
fi
if mut m3b-anchor-anywhere 's@^if \[ -n "\$LPE_ROOT" \]; then$@[ -n "$LPE_ROOT" ] || LPE_ROOT="${LPE_TARGET%/*}"; if true; then@'; then
  lpe_mut m3b-anchor-anywhere "${B_3b:-0}" deny "$W.scratch/notes.md" "$TA" deny "$W/src/app.py" "$TA" "M3b-anchor: treating any directory as a tree DENIES the scratchpad path — (i) is load-bearing"
fi
if mut m3b-no-iii "s@grep -q '^<<<<<<< ' \"\$LPE_TARGET\" 2>/dev/null@false@"; then
  lpe_mut m3b-no-iii "${B_3b:-0}" deny "$W/src/conflict.py" "$TA" deny "$W/src/app.py" "$TA" "M3b-iii: dropping (iii) DENIES the conflict-marked file — (iii) is load-bearing"
fi
if mut m3b-after-gate-exit 's@^case "\$FP" in /\*) LPE_ABS=@[ -d "$GATE_DIR" ] || exit 0; case "$FP" in /*) LPE_ABS=@'; then
  lpe_mut m3b-after-gate-exit "${B_3b:-0}" allow "$W/src/app.py" "$TA" allow "$SIB/_bmad-output/planning-artifacts/x.md" "$TA" "M3b-gate: the arm placed after the GATE_DIR exit ALLOWS P1 with no gate directory — the placement is load-bearing"
fi
if mut m3b-no-scanroots 's@case "\$LPE_REL" in "\$_lpe_sr"/\*|"\$_lpe_sr") LPE_PRODUCT=0 ;; esac@:@'; then
  lpe_mut m3b-no-scanroots "${B_3b:-0}" deny "$W/reports/r.md" "$TA" deny "$W/src/app.py" "$TA" "M3b-roots: ignoring the grammar's scan roots DENIES reports/r.md — the resolver read is load-bearing"
fi
if mut m3b-no-claude-md 's@^    CLAUDE.md|CLAUDE.local.md|AGENTS.md) LPE_PRODUCT=0 ;;$@    CLAUDE.md|CLAUDE.local.md|AGENTS.md) ;;@'; then
  lpe_mut m3b-no-claude-md "${B_3b:-0}" deny "$W/CLAUDE.md" "$TA" allow "$W/.gitignore" "$TA" "M3b-claude: without the allowance repo-root CLAUDE.md is DENIED — the allowance is load-bearing"
fi
if mut m3b-no-lex 's@^LPE_ABS="\$(lpe_lex "\$LPE_ABS")"$@:@'; then
  lpe_mut m3b-no-lex "${B_3b:-0}" allow "$W/docs/nx/../../src/app.py" "$TA" deny "$W/src/app.py" "$TA" "M3b-lex: without the lexical collapse docs/nx/../../src/app.py is ALLOWED — the collapse is load-bearing"
fi
git -C "$W" worktree remove --force "$SIB" >/dev/null 2>&1
rm -rf "$W" "$SIB" "$W.hang"

rm -rf "$MW"
[ -n "$GRD_DECOY" ] && rm -rf "$GRD_DECOY"

# MX -- a plain run executes NO matrix-only cell, and --matrix executes at least one. MX_RAN is bumped by every
# matrix-only driver AFTER its mx_run gate let it through, so it is a count of what RAN, not of what was selected.
if [ "$MATRIX" = 0 ]; then
  if [ "$MX_RAN" -eq 0 ]; then ok "MX: a plain run executed no matrix-only cell (matrix-only cells run: 0)"
  else bad "MX: a plain run executed $MX_RAN matrix-only cell(s)"; fi
else
  if [ "$MX_RAN" -gt 0 ]; then ok "MX: the matrix run executed $MX_RAN matrix-only cell(s)"
  else bad "MX: --matrix executed no matrix-only cell"; fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "gate-remediation-deny: PASS"; exit 0; fi
echo "gate-remediation-deny: $fails assertion(s) FAILED" >&2
exit 1
