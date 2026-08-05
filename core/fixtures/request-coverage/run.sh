#!/usr/bin/env bash
# request-coverage/run.sh — prove Check 33 catches a sprint that dropped its own topic, and
# that it cannot be satisfied by the PREVIOUS sprint's block saying the same words.
#
# THE DEFECT. Every byte-level guarantee in the pipeline terminates at product-brief.md:
# Check 3b anchors stories to it, Check 30 joins capabilities through it. The brief is the
# LEAD's restatement of an ask it received across a hop with no mechanical join at all. So a
# plan can be perfectly self-consistent from the brief forward while sharing nothing with what
# was asked, and every downstream check reads green. Measured on the reference consumer: a
# request naming six identifiers, a LOCKED block containing none of them, three unrelated
# stories, four consecutive green gates.
#
# THE ASSERTION THAT MATTERS MOST is 2. Briefs accumulate one LOCKED block per sprint and
# blocks cite each other constantly. The first draft of this check read the whole block, scored
# the previous sprint's mentions as coverage, and reported the dropped work as covered — the
# same confusion between REFERRING to work and COMMITTING to it that produced the failure.
# covered/ and dropped/ differ only in sprint 42's bullets; the S41 block is byte-identical,
# and it names every identifier sprint 42 dropped.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Capture output AND exit code without a pipeline: the validator's exit code is the verdict,
# and `run | grep` would replace it with grep's.
OUT=""; RC=0
run() { OUT="$(bash "$1" --requests "$2" --brief "$3" --sprint "${4:-42}" 2>&1)"; RC=$?; }

echo "request-coverage:"

# --- Assertion 1: THE FIX — a dropped epic FAILS ------------------------------
run "$VALIDATOR" "$REQ" "$DROPPED"
if [ "$RC" = "1" ]; then
  ok "a sprint that dropped the identifiers its operator named FAILS (exit 1)"
else
  bad "the dropped epic did not FAIL (exit $RC) — the reference failure passes this check"
fi

# --- Assertion 2: THE TRAP — the PREVIOUS sprint's block cannot satisfy it -----
# Every dropped identifier appears, in this same brief, inside the S41 block.
if grep -q 'CAP-1\.\.6' <<<"$OUT" \
   && grep -q 'Epic-WGS' <<<"$OUT" \
   && grep -q 'LR-S41-0\.\.7' <<<"$OUT"; then
  ok "the prior sprint's block does not satisfy this one — mentions are not commitments"
else
  bad "identifiers present in the PREVIOUS sprint's block were scored as covered. This is the failure the check exists for, reproduced inside the check: $(tr '\n' ' ' <<<"$OUT" | head -c 160)"
fi

# --- Assertion 3: a mention INSIDE a committed bullet is not laundering --------
# dropped/'s LR-S42-0 body mentions LR-S41-2 as background. That is a reference in a committed
# bullet, and it must not cover the whole LR-S41-0..7 span the operator named.
if grep -q 'LR-S41-0\.\.7' <<<"$OUT"; then
  ok "a background mention of LR-S41-2 inside a committed bullet does not cover LR-S41-0..7"
else
  bad "one incidental id reference inside a committed bullet covered the operator's whole span — the series match is too loose to distinguish scope from citation"
fi

# --- Assertion 4: the honest case PASSES --------------------------------------
run "$VALIDATOR" "$REQ" "$COVERED"
if [ "$RC" = "0" ] && grep -q '^PASS:' <<<"$OUT"; then
  ok "a sprint that took the epic and dispositioned the stretch item PASSES"
else
  bad "the faithful brief did not PASS (exit $RC) — a check that cannot go green blocks every sprint: $(tr '\n' ' ' <<<"$OUT" | head -c 160)"
fi

# --- Assertion 5: declining work is allowed; SILENCE is not -------------------
run "$VALIDATOR" "$REQ" "$DISPOSITIONED"
if [ "$RC" = "0" ]; then
  ok "a sprint may decline named work by dispositioning it — the check demands an answer, not a yes"
else
  bad "an explicitly dispositioned identifier still FAILED (exit $RC) — the check would force sprints to take work the operator made optional"
fi

# --- Assertion 6: the ZERO-CONTROL is printed on every path -------------------
# A regex that matched nothing prints the same clean line as full coverage. This is the repo's
# recurring defect, and this check's own report is where it would land.
run "$VALIDATOR" "$REQ_NOIDS" "$COVERED"
if [ "$RC" = "0" ] \
   && grep -q '^identifiers_scanned: 0' <<<"$OUT" \
   && grep -q 'NOT-APPLICABLE' <<<"$OUT"; then
  ok "an ask naming no identifiers reports identifiers_scanned: 0 and NOT-APPLICABLE, not a clean pass"
else
  bad "a request with no identifiers was indistinguishable from full coverage (exit $RC) — 5 of 23 measured asks are this shape"
fi

# --- Assertion 7: absent evidence is a FAIL, not a pass -----------------------
run "$VALIDATOR" "$WORK/nonexistent-requests.md" "$COVERED"
if [ "$RC" = "2" ]; then
  ok "a missing capture file exits 2 — no evidence must never render as no problem"
else
  bad "a missing operator-requests file did not fail closed (exit $RC) — every consumer without the hook would read green"
fi

# --- Assertion 8: no declared scope for the sprint is a FAIL ------------------
run "$VALIDATOR" "$REQ" "$NOSCOPE"
if [ "$RC" = "2" ]; then
  ok "a brief declaring no LR bullet for this sprint exits 2 — an unanswerable question, not a clean one"
else
  bad "a brief with no scope for this sprint returned $RC — the check answered a question it could not evaluate"
fi

# --- Assertion 9: --cite-sha pins the entry ----------------------------------
OUT="$(bash "$VALIDATOR" --requests "$REQ" --brief "$COVERED" --sprint 42 --cite-sha "$SHA" 2>&1)"; RC=$?
if [ "$RC" = "0" ]; then ok "--cite-sha resolves the routing record's hash to the captured entry"
else bad "--cite-sha failed to resolve a hash that is present in the capture file (exit $RC)"; fi
OUT="$(bash "$VALIDATOR" --requests "$REQ" --brief "$COVERED" --sprint 42 --cite-sha deadbeef 2>&1)"; RC=$?
if [ "$RC" = "2" ]; then ok "a hash resolving to no captured request exits 2 — a fabricated citation cannot pass"
else bad "a fabricated --cite-sha did not fail closed (exit $RC) — the routing record could cite anything"; fi

# --- Assertion 10: UNMUTATED CONTROL -----------------------------------------
# The mutants are copies. This validator resolves a sibling script by $0's directory and shells
# into python; a copy placed elsewhere dies resolving that sibling and prints nothing, which
# assertions expecting a FAIL would score as a kill. The copies therefore live BESIDE the
# original, and this proves one behaves identically.
CTL="$(dirname "$VALIDATOR")/.control-$$-validate-request-coverage.sh"
cp "$VALIDATOR" "$CTL"; trap 'rm -rf "$WORK"; rm -f "$CTL" "$(dirname "$VALIDATOR")"/.mutant-$$-*.sh' EXIT
run "$CTL" "$REQ" "$DROPPED"
if [ "$RC" = "1" ]; then
  ok "control: an unmutated copy FAILs the dropped brief identically — the copies below can run"
else
  bad "CONTROL FAILED (exit $RC): an unmutated copy does not behave like the original, so no mutant result below means anything"
fi

# --- Assertion 11: MUTANT A — read the whole block instead of committed bullets
# The first draft's defect, in one line: measure coverage against every block rather than this
# sprint's committed bullets. The dropped brief MUST then pass, because the S41 block names
# everything it dropped.
MUT_A="$(dirname "$VALIDATOR")/.mutant-$$-a.sh"
awk 'index($0,"scope = \"\\n\".join(own_bullets)") { print "scope = \"\\n\".join(blocks)"; next } { print }' \
  "$VALIDATOR" > "$MUT_A"
if cmp -s "$VALIDATOR" "$MUT_A"; then
  bad "FIXTURE STALE: mutant A is byte-identical — the committed-bullet scope line was reworded"
elif ! bash -n "$MUT_A" 2>/dev/null; then
  bad "FIXTURE BROKEN: mutant A is not a valid shell script, so a kill would only mean the copy could not run"
else
  chmod +x "$MUT_A"; run "$MUT_A" "$REQ" "$DROPPED"
  if [ "$RC" = "0" ]; then
    ok "mutant A: reading whole blocks makes the dropped epic PASS — assertions 1-3 have teeth"
  else
    bad "MUTANT A DID NOT FAIL (exit $RC) — the dropped brief fails even when the prior block is in scope, so assertion 2 is not testing the trap"
  fi
  # Must fail ONLY its own assertion: the honest brief still passes.
  run "$MUT_A" "$REQ" "$COVERED"
  if [ "$RC" = "0" ]; then
    ok "mutant A leaves assertion 4 intact — the two assertions are not entangled"
  else
    bad "mutant A ALSO broke assertion 4 (exit $RC) — scope selection and the pass path are entangled, so one assertion is vacuous"
  fi
fi

# --- Assertion 12: MUTANT B — drop the fail-closed arm ------------------------
# Treat an unreadable capture file as nothing to check. Assertion 7 MUST go red.
MUT_B="$(dirname "$VALIDATOR")/.mutant-$$-b.sh"
awk 'index($0,"if [ ! -r \"$REQUESTS\" ]; then") { print "if false; then"; next } { print }' \
  "$VALIDATOR" > "$MUT_B"
if cmp -s "$VALIDATOR" "$MUT_B"; then
  bad "FIXTURE STALE: mutant B is byte-identical — the fail-closed guard was reworded"
elif ! bash -n "$MUT_B" 2>/dev/null; then
  bad "FIXTURE BROKEN: mutant B is not a valid shell script"
else
  chmod +x "$MUT_B"; run "$MUT_B" "$WORK/nonexistent-requests.md" "$COVERED"
  if [ "$RC" != "2" ]; then
    ok "mutant B: without the fail-closed arm a missing capture stops exiting 2 — assertion 7 has teeth"
  else
    bad "MUTANT B DID NOT FAIL — a missing capture still exits 2 without the guard, so assertion 7 is not testing it"
  fi
  # Must fail ONLY its own assertion.
  run "$MUT_B" "$REQ" "$DROPPED"
  if [ "$RC" = "1" ]; then
    ok "mutant B leaves assertion 1 intact — the guard and the coverage verdict are not entangled"
  else
    bad "mutant B ALSO broke assertion 1 (exit $RC) — one of the two assertions is vacuous"
  fi
fi

# --- A HARNESS-RAISED ENTRY IS NOT THE ASK (v0.265.0) ----------------------------------
# THIS IS THE ONE THAT TURNED THE CHECK OFF. Entry selection took the newest record, and the
# capture hook recorded the events the harness raises when a backgrounded task completes —
# same `(typed)` command, same SHA, same shape. A machine event names no identifier, so the
# check answered NOT-APPLICABLE and exited 0 on a sprint whose real ask named 22 of them.
# Measured against a seeded brief before the fix: newest entry `NOT-APPLICABLE ... rc=0`;
# pinned to the operator's own ask, `rc=1` naming an uncovered CAP-.
#
# The hook no longer writes such entries, and this is STILL not redundant: the file is
# append-only, so every consumer that ran an older hook carries them at the end of its
# history, where they stay newest until the operator happens to type again.
HREQ="$WORK/requests-with-harness-tail.md"
cp "$REQ" "$HREQ"
cat >> "$HREQ" <<'HEOF'

## 2026-08-05T23:59:59Z -- (typed)
- Session: sess-h
- Bytes: 180
- SHA256: dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd

```text
<task-notification>
<task-id>zzz</task-id>
<status>completed</status>
<summary>Background command "beat" completed (exit code 0)</summary>
</task-notification>
```
HEOF

run "$VALIDATOR" "$HREQ" "$DROPPED"
if [ "$RC" = "1" ]; then
  ok "a harness-raised NEWEST entry does not become the ask — the dropped epic still FAILS"
else
  bad "a background event appended after the ask changed the verdict to exit $RC. A task finishing before the gate ran turns this check off, in the quiet direction"
fi

# The pinned path is deliberate, so pointing it AT a machine event must be loud rather than
# silently re-picked: the routing record asserts the operator asked for this.
OUT="$(bash "$VALIDATOR" --requests "$HREQ" --brief "$DROPPED" --sprint 42         --cite-sha dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd 2>&1)"; RC=$?
if [ "$RC" = "2" ] && grep -q 'HARNESS-RAISED' <<<"$OUT"; then
  ok "a routing record pinned to a harness-raised entry ERRORS by name, rather than being quietly re-picked"
else
  bad "pinning the routing record to a background event exited $RC without naming the cause"
fi

# CONTROL: the same file, pinned to the OPERATOR's entry, behaves exactly as before. Without
# it, an implementation that rejected every --cite-sha would satisfy the assertion above.
OUT="$(bash "$VALIDATOR" --requests "$HREQ" --brief "$COVERED" --sprint 42 2>&1)"; RC=$?
if [ "$RC" = "0" ]; then
  ok "CONTROL: a covered brief still passes with the harness entry present — the filter selects, it does not reject"
else
  bad "CONTROL: the covered brief now fails (exit $RC); the harness filter is rejecting entries it should only skip"
fi

# MUTATION: a capture whose entries are ALL harness-raised must not read as NOT-APPLICABLE.
# That is the same zero the defect produced, reached from the other side.
AHREQ="$WORK/requests-all-harness.md"
{ printf '# Operator Requests\n'; sed -n '/^## 2026-08-05T23:59:59Z/,$p' "$HREQ"; } > "$AHREQ"
OUT="$(bash "$VALIDATOR" --requests "$AHREQ" --brief "$DROPPED" --sprint 42 2>&1)"; RC=$?
if [ "$RC" = "2" ] && grep -q 'no operator in it' <<<"$OUT"; then
  ok "a capture holding ONLY harness-raised entries exits 2 — 'nothing was asked' and 'nothing was recorded' are different answers"
else
  bad "a capture with no operator entry exited $RC; an empty ask reading as NOT-APPLICABLE is the defect this release closes"
fi

echo
if [ "$fails" -eq 0 ]; then echo "request-coverage: PASS"; exit 0; fi
echo "request-coverage: $fails assertion(s) FAILED" >&2
exit 1
