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

# =============================================================================
# PART 2 — Check 5, `check-stories`
#
# gate-validation.md Check 5 said "compare status values programmatically" and core shipped no
# program, so the comparison was done by hand at every gate. Three consumer-authored versions of it
# each went vacuously green at least once — a story-id glob that matched none of the corpus, a field
# set compared zero times, a body-header grammar the story files no longer carried — and each
# printed its zero beside a success line.
#
# So the battery below asserts the COUNTS and the STATES, not just the verdict, and every assertion
# is driven from ONE function so the same battery can be re-run against a mutated copy of the tool.
# A mutant is accepted only if it fails EXACTLY its own assertion; anything else means two
# assertions are reading the same thing and one of them is proving nothing.
# =============================================================================

CS="$WORK/cs"
CSTORIES="$CS/_bmad-output/planning-artifacts/s291/stories"
CIMPL="$CS/_bmad-output/implementation-artifacts"
CPLAN="$CS/_bmad-output/planning-artifacts"

cs_reset() { rm -rf "$CS"; mkdir -p "$CSTORIES" "$CIMPL" "$CPLAN"; }

story_fm()  { printf -- '---\nstatus: %s\nsprint: 291\n---\n\n# story\n' "$2" > "$CSTORIES/$1.md"; }
story_hdr() { printf -- '# story\n\n**Status:** %s\n' "$2"              > "$CSTORIES/$1.md"; }

# Run the tool under test. The schema is passed explicitly because a mutant COPY lives outside
# core/scripts/ and would otherwise resolve a different schema (or none) than the original.
cs_run() {
  CS_OUT="$(AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA" bash "$1" check-stories --root "$CS" 2>&1)"
  CS_RC=$?
}

# Each assertion prints "<id> PASS" or "<id> FAIL". $1 is the tool to drive.
cs_battery() {
  local T="$1"

  # A13 — a consistent tree PASSES, and says how many comparisons it made.
  cs_reset
  story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done'
  cs_run "$T"
  if [ "$CS_RC" -eq 0 ] && grep -q 'PASS — 1 comparison(s)' <<<"$CS_OUT"; then
    echo "A13 PASS"; else echo "A13 FAIL"; fi

  # A14 — a mismatch is REPORTED, not absorbed.
  cs_reset
  story_fm story-1 review
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done'
  cs_run "$T"
  if [ "$CS_RC" -eq 1 ] && grep -q 'STATUS MISMATCH' <<<"$CS_OUT"; then
    echo "A14 PASS"; else echo "A14 FAIL"; fi

  # A15 — a story file with NO frontmatter is read through its `**Status:**` header and COUNTED.
  # 726 of the reference consumer's 988 story files carry only this spelling; a reader that knows
  # only frontmatter skips them and reports the skip as nothing to do.
  cs_reset
  story_hdr story-1 'done (all three gates green)'
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done'
  cs_run "$T"
  if [ "$CS_RC" -eq 0 ] && grep -q 'PASS — 1 comparison(s)' <<<"$CS_OUT"; then
    echo "A15 PASS"; else echo "A15 FAIL"; fi

  # A16 — THE VACUITY FLOOR. A canonical with no `stories:` key compared nothing, and that is its
  # own exit code. Folding it into 0 is the defect every version of this check has shipped.
  cs_reset
  story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress'
  cs_run "$T"
  if [ "$CS_RC" -eq 4 ]; then echo "A16 PASS"; else echo "A16 FAIL"; fi

  # A17 — but an EMPTY `stories:` block is what `roll` itself writes, so it must not be a finding.
  # Asserted on the absence of a finding, not on the exit code, so it cannot fire for A16's reason.
  cs_reset
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  # populated at stories-test-strategy. A MAPPING keyed by story id
  # (story-291-<M>:), never a list — a list form matches no reader.'
  cs_run "$T"
  if ! grep -q 'FINDING' <<<"$CS_OUT"; then echo "A17 PASS"; else echo "A17 FAIL"; fi

  # A18 — the LIST form. The reference consumer ran a whole sprint on it: its tool compared ZERO
  # fields and reported success, because a list matches no key grammar.
  cs_reset
  story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  - id: story-291-1
    status: done'
  cs_run "$T"
  if [ "$CS_RC" -eq 1 ] && grep -q 'LIST form' <<<"$CS_OUT"; then
    echo "A18 PASS"; else echo "A18 FAIL"; fi

  # A19 — an entry naming a story file that is not there is a FINDING. Skipping it is how a
  # renamed corpus becomes invisible to its own validator.
  cs_reset
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done'
  cs_run "$T"
  if [ "$CS_RC" -eq 1 ] && grep -q 'names no readable story file' <<<"$CS_OUT"; then
    echo "A19 PASS"; else echo "A19 FAIL"; fi

  # A20 — two entries under one id: whichever a reader takes, the other is unenforced.
  cs_reset
  story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done
  story-291-1:
    file: stories/story-1.md
    status: review'
  cs_run "$T"
  if [ "$CS_RC" -eq 1 ] && grep -q 'duplicate story key' <<<"$CS_OUT"; then
    echo "A20 PASS"; else echo "A20 FAIL"; fi

  # A21 — the two canonical copies are BOTH authoritative for an entry. Disagreement between them
  # is route.md Step 6 rule 5 one grain down.
  cs_reset
  story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done'
  # the planning copy is the one that drifts
  put "$CPLAN/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: review'
  cs_run "$T"
  if [ "$CS_RC" -eq 1 ] && grep -q 'canonical copies disagree' <<<"$CS_OUT"; then
    echo "A21 PASS"; else echo "A21 FAIL"; fi

  # A22 — index-prefix collision. Key `story-291-1` must never resolve to `story-10-...`; a
  # `<stem>*` glob compares one story against ANOTHER story's file. Asserted on the identity of the
  # file the tool read, not on the finding text A19 also carries — two assertions reading one
  # string is how one of them ends up proving nothing.
  #
  # THE KEY STILL SPELLS THE SPRINT AND THE FILE NO LONGER DOES, which is the join this release
  # re-derived: the declared sprint is stripped from the key to give the index, so `story-291-1`
  # looks for `story-1-*.md` inside `s291/stories/` and the collision is between INDEXES rather
  # than between whole ids.
  cs_reset
  story_fm story-10-late-arrival review
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    status: done'
  cs_run "$T"
  if ! grep -q 'story-10-late-arrival' <<<"$CS_OUT"; then echo "A22 PASS"; else echo "A22 FAIL"; fi
}

echo
echo "sprint-status-lifecycle (Part 2 — Check 5 / check-stories):"

BATTERY="$(cs_battery "$TOOL")"
printf '%s\n' "$BATTERY" | while read -r id verdict; do
  [ "$verdict" = "PASS" ] && printf '  ok    %s consistent-status battery\n' "$id"
done
CS_FAILED="$(printf '%s\n' "$BATTERY" | awk '$2=="FAIL"{printf "%s ", $1}')"
if [ -n "$CS_FAILED" ]; then
  bad "check-stories battery failed on the SHIPPING tool: $CS_FAILED"
else
  ok "check-stories: all 10 assertions pass on the shipping tool"
fi

# --- Mutants -----------------------------------------------------------------
# Each is a COPY (never an in-place edit), guarded by `cmp -s` so a sed that matched nothing cannot
# pass as a mutation, and accepted only if it fails EXACTLY its own assertion.
mutant() {                       # <expected-assertion> <label> <sed-program>
  local want="$1" label="$2" prog="$3"
  local m="$WORK/mutant-$want.sh"
  sed "$prog" "$TOOL" > "$m" 2>/dev/null
  if cmp -s "$TOOL" "$m"; then
    bad "MUTANT $want ($label): the sed changed nothing — the mutation never happened"
    return
  fi
  local out failed
  out="$(cs_battery "$m")"
  failed="$(printf '%s\n' "$out" | awk '$2=="FAIL"{printf "%s ", $1}' | sed 's/ $//')"
  if [ "$failed" = "$want" ]; then
    ok "MUTANT $want ($label) fails exactly $want"
  elif [ -z "$failed" ]; then
    bad "MUTANT $want ($label) was NOT CAUGHT — the battery stayed green on a broken tool"
  else
    bad "MUTANT $want ($label) failed [$failed], expected exactly [$want] — entangled assertions"
  fi
}

# A16: collapse "compared nothing" into a pass. The single most important mutation here.
mutant A16 "compared-nothing exits 0" 's/^        return 4$/        return 0/'
# A17: treat an empty `stories:` block as a content-bearing one, so `roll` output reports a finding.
mutant A17 "empty block reported as a finding" 's/return ("no-entries" if content else "empty", \[\])/return ("no-entries", [])/'
# A14: never report a mismatch.
mutant A14 "mismatch comparison disabled" 's/            if fstatus != ystatus:/            if False:/'
# A15: drop the `**Status:**` fallback, so a file with no frontmatter yields nothing.
mutant A15 "body-header status reader removed" 's/^    m = HDR_STATUS_RE.search(text)$/    m = None/'
# A18: report a keyless block as empty instead of as a finding.
mutant A18 "list form reported as empty" 's/^    if entries:$/    if True:/'
# A19: skip an entry whose file will not resolve.
mutant A19 "unresolvable entry skipped silently" 's/^            if resolved is None:$/            if False and resolved is None:/'
# A20: stop detecting a repeated key.
mutant A20 "duplicate key detection removed" 's/^            if key in seen:$/            if False:/'
# A21: drop the cross-view comparison.
mutant A21 "cross-view arm removed" 's/^        if len(vals) > 1 and len(set(vals.values())) > 1:$/        if False:/'
# A22: widen the index glob to `<stem>*`, the collision that compares story-1 against story-10.
mutant A22 "id glob widened to a prefix match" 's/stories.glob(stem + "-\*.md")/stories.glob(stem + "*.md")/'

# --- Unmutated control -------------------------------------------------------
# A copy in the same directory as the mutants, mutated not at all. If the harness itself is what
# breaks a copy — a resolver that only works in core/scripts/, a schema it cannot find — every
# mutant above "passes" for a reason that has nothing to do with its mutation.
CTRL="$WORK/mutant-control.sh"
cp "$TOOL" "$CTRL"
CTRL_FAILED="$(cs_battery "$CTRL" | awk '$2=="FAIL"{printf "%s ", $1}')"
if [ -z "$CTRL_FAILED" ]; then
  ok "CONTROL: an unmutated copy beside the mutants passes the whole battery"
else
  bad "CONTROL: an unmutated copy failed [$CTRL_FAILED] — the mutant harness, not the mutations, is what those mutants proved"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "sprint-status-lifecycle: PASS"
  exit 0
fi
echo "sprint-status-lifecycle: FAIL ($fails)"
exit 1
