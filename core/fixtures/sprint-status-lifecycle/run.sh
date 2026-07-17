#!/usr/bin/env bash
# sprint-status-lifecycle/run.sh — prove sprint_id is derived MECHANICALLY (not by prose), that the
# freeze+roll is atomic/idempotent/byte-faithful, and that the grammar cannot repeat the reference
# consumer's collision.
#
# THE DEFECT THIS EXISTS TO CATCH. sprint_id had no mechanical source: route.md Step 6 was ~25 lines
# of prose the model executed by hand, with four rules — absent->1, done->N+1, else->N, copies
# disagree->HARD_BLOCK. None of them match a canonical that EXISTS but carries no `sprint:` key,
# which is exactly the state a rotate-at-close leaves behind. The likeliest reading of the prose in
# that state is "greenfield -> 1", which re-stamps a live project's drafts from sprint 1 and,
# per route.md's own warning, silently destroys the prior sprint's work.
#
# AND THE GRAMMAR COLLISION. The reference consumer's rotation tool matches sprint blocks with
# ^sprint[_-]([0-9]+)...: — which matches ZERO lines of the real single-sprint canonical (so its
# --close-sweep no-ops and exits 0 reporting success) while DOES matching `sprint_291_housekeeping:`
# and yielding 291. Assertions 8/9 are the regression lock: our keys must not repeat either half.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

P="$WORK/proj"
IMPL="$P/_bmad-output/implementation-artifacts"
PLAN="$P/_bmad-output/planning-artifacts"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

reset_tree() {
  rm -rf "$IMPL" "$PLAN"
  mkdir -p "$IMPL/sprint-status" "$PLAN/sprint-status"
}
put() { printf '%s\n' "$2" > "$1"; }
sid() { bash "$TOOL" sprint-id --root "$P" 2>/dev/null; }

echo "sprint-status-lifecycle:"

# --- Assertion 0: SANITY — render is non-empty and deterministic -------------
R1="$(bash "$TOOL" --render)"; R2="$(bash "$TOOL" --render)"
[ -n "$R1" ] && [ "$R1" = "$R2" ] && ok "--render is non-empty and deterministic" \
  || bad "--render is empty or non-deterministic"

# --- Assertion 1: greenfield (no file) -> 1 ---------------------------------
reset_tree
[ "$(sid)" = "1" ] && ok "greenfield (no canonical) -> 1" || bad "greenfield did not resolve to 1"

# --- Assertion 2: closed sprint -> N+1 (route rule 3) ------------------------
reset_tree
put "$IMPL/sprint-status.yaml" 'sprint: 290
status: done'
[ "$(sid)" = "291" ] && ok "status: done -> N+1 (rule 3)" || bad "closed sprint did not resolve to N+1"

# --- Assertion 3: in-flight -> N (route rule 4) ------------------------------
reset_tree
put "$IMPL/sprint-status.yaml" 'sprint: 291
status: in_progress'
[ "$(sid)" = "291" ] && ok "in-flight -> N (rule 4, a re-plan not a new sprint)" \
  || bad "in-flight sprint did not resolve to N"

# --- Assertion 4: THE CORE DEFECT — preamble-only -> max_frozen+1, never 1 ---
# The state route.md Step 6 has NO rule for. This assertion is the whole point of the change:
# it must NOT resolve to 1, because 1 destroys the prior sprint's drafts.
reset_tree
put "$IMPL/sprint-status.yaml" '# Sprint Status
# (preamble-only: what a rotate-at-close leaves behind)'
put "$IMPL/sprint-status/sprint-289.yaml" 'sprint: 289
status: done'
put "$IMPL/sprint-status/sprint-290.yaml" 'sprint: 290
status: done'
GOT="$(sid)"
[ "$GOT" = "291" ] && ok "preamble-only -> max_frozen+1 (291), the case the prose has no rule for" \
  || bad "preamble-only resolved to '$GOT', expected 291 (1 would destroy the prior sprint's drafts)"
[ "$GOT" != "1" ] || bad "preamble-only resolved to 1 — the exact silent-destruction defect"

# --- Assertion 5: copies disagree -> HARD_BLOCK exit 3 (route rule 5) --------
reset_tree
put "$IMPL/sprint-status.yaml" 'sprint: 291
status: done'
put "$PLAN/sprint-status.yaml" 'sprint: 290
status: done'
bash "$TOOL" sprint-id --root "$P" >/dev/null 2>&1
[ $? -eq 3 ] && ok "copies disagree -> exit 3 HARD_BLOCK (never guesses)" \
  || bad "disagreeing copies did not HARD_BLOCK with exit 3"

# --- Assertion 6: roll freezes BYTE-FAITHFULLY, then rolls forward -----------
reset_tree
BODY='sprint: 291
status: done
stories:
  story-291-1:
    status: done'
put "$IMPL/sprint-status.yaml" "$BODY"
bash "$TOOL" roll --sprint 292 --root "$P" >/dev/null 2>&1
FROZEN="$IMPL/sprint-status/sprint-291.yaml"
if [ -f "$FROZEN" ] && [ "$(cat "$FROZEN")" = "$BODY" ]; then
  ok "roll freezes the closed sprint byte-faithfully (no-loss)"
else
  bad "roll did not freeze byte-faithfully"
fi
grep -q '^sprint: 292' "$IMPL/sprint-status.yaml" && grep -q '^status: in_progress' "$IMPL/sprint-status.yaml" \
  && ok "roll writes the new envelope (sprint 292, in_progress)" || bad "roll did not write the new envelope"
[ "$(sid)" = "292" ] && ok "round-trip: sprint-id after roll -> 292" || bad "roll does not round-trip"

# --- Assertion 7: roll is IDEMPOTENT — a re-run must not re-freeze -----------
# The reference consumer's ADR called this out as a data-loss guard: a second run that re-freezes a
# pruned canonical overwrites the real archive with an empty one.
B="$(cat "$FROZEN")"
bash "$TOOL" roll --sprint 292 --root "$P" >/dev/null 2>&1
[ "$(cat "$FROZEN")" = "$B" ] && ok "roll is idempotent (re-run does not re-freeze/destroy)" \
  || bad "re-running roll overwrote the frozen archive — data loss"

# --- Assertion 7b: roll CREATES the file on greenfield, and mints no twin ----
# The artifact never had a creator: no step file, no template, no installer seed.
reset_tree
rm -f "$IMPL/sprint-status.yaml" "$PLAN/sprint-status.yaml"
bash "$TOOL" roll --sprint 1 --root "$P" >/dev/null 2>&1
[ -f "$IMPL/sprint-status.yaml" ] && ok "roll creates the canonical on greenfield (the missing creator)" \
  || bad "roll did not create the canonical on greenfield"
[ ! -f "$PLAN/sprint-status.yaml" ] && ok "greenfield creation mints NO second copy" \
  || bad "greenfield creation minted a planning twin — the two-view drift, seeded fresh"

# --- Assertion 8: MUTANT/REGRESSION — housekeeping is NOT read as a sprint ---
# `sprint_291_housekeeping:` matches the reference tool's sprint-block regex and yields 291. If our
# grammar ever repeats that, a housekeeping block alone would look like a sprint envelope.
reset_tree
put "$IMPL/sprint-status.yaml" 'sprint_291_housekeeping:
  envelope_status: done
  closure_evidence: "x"'
GOT="$(sid)"
[ "$GOT" != "291" ] && ok "MUTANT: a housekeeping block alone is NOT parsed as sprint 291" \
  || bad "housekeeping block parsed AS a sprint envelope — the reference tool's exact collision"

# --- Assertion 9: MUTANT — a real canonical WITH housekeeping still reads N --
# The inverse: once the close envelope exists, `sprint:` must still win and the housekeeping key
# must not shadow it.
reset_tree
put "$IMPL/sprint-status.yaml" 'sprint: 290
status: done
stories:
  story-290-1:
    status: done
sprint_290_housekeeping:
  envelope_status: done
  closure_evidence: "merged, deployed, validated"'
[ "$(sid)" = "291" ] && ok "MUTANT: canonical WITH housekeeping still derives N+1 correctly" \
  || bad "housekeeping block broke sprint_id derivation"

# --- Assertion 10: roll REFUSES to roll over a sprint that is not closed -----
reset_tree
put "$IMPL/sprint-status.yaml" 'sprint: 291
status: in_progress'
bash "$TOOL" roll --sprint 292 --root "$P" >/dev/null 2>&1
[ $? -eq 3 ] && ok "roll refuses an unclosed sprint (exit 3) — never freezes live state" \
  || bad "roll froze a sprint that was still in flight"

# --- Assertion 11: fail-closed on an unreadable schema ----------------------
reset_tree
put "$IMPL/sprint-status.yaml" 'sprint: 291
status: in_progress'
# A NON-EXISTENT override path falls back to the real schema by design (the resolver skips it), so
# that would prove nothing. Point it at a REAL but corrupt file — the state that actually fails.
printf 'not json{' > "$WORK/corrupt.json"
if AI_DLC_SPRINT_STATUS_SCHEMA="$WORK/corrupt.json" bash "$TOOL" sprint-id --root "$P" >/dev/null 2>&1; then
  bad "a corrupt schema did not fail closed"
else
  ok "fail-closed on an unreadable schema (never guesses the grammar)"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "sprint-status-lifecycle: PASS"
  exit 0
fi
echo "sprint-status-lifecycle: FAIL ($fails)"
exit 1
