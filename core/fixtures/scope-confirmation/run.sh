#!/usr/bin/env bash
# scope-confirmation/run.sh — prove Check 34 can tell a sprint whose scope an operator
# actually saw from one that merely says so.
#
# THE DEFECT. Rule 3's pause points were all downstream of implementation, so a sprint
# that never reached implementation had structurally nowhere to ask. One ran seven days,
# produced zero lines of product code, planned three stories sharing not one identifier
# with the ask, passed four consecutive gates green, and filed all three of its blocking
# questions on day 7 — while breaking no rule at all. Rule 3(d) adds the seam. This check
# is what makes it a requirement rather than a suggestion.
#
# THE ASSERTIONS THAT MATTER MOST are 2 and 5. Both are places where the honest-looking
# reading fails OPEN:
#   2. "no scope_confirmed field" must NOT be read as "this consumer predates the
#      release". That reading is indistinguishable from a lead skipping the pause point,
#      and it excuses precisely the conduct the check exists to catch.
#   5. `scope_confirmed_cite: none` must not pass while the capture file holds entries.
#      Otherwise the cheapest way past the check is to write `none`.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a validator while inheriting them tests the CONFIG, not the code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

sha_of() { printf '%s' "$1" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1; }

# Run a validator against a snapshot/answers pair. Echoes the exit code; stashes output.
LAST_OUT=""
rc_of() {
  LAST_OUT="$(bash "$1" --snapshot "$2" --answers "$3" 2>&1)"
  printf '%s' "$?"
}

echo "scope-confirmation:"

if [ -z "${SHA:-}" ]; then
  bad "SEED BROKEN: the capture hook recorded no SHA256, so every assertion below would be comparing against an empty string"
  echo; echo "scope-confirmation: $fails assertion(s) FAILED" >&2; exit 1
fi

# --- Assertion 1: a well-formed confirmation passes ---------------------------
r=$(rc_of "$VALIDATOR" "$WORK/snap-good.md" "$ANSWERS")
if [ "$r" = "0" ]; then
  ok "a routing record whose cite resolves to a hook-written answer passes"
else
  bad "the healthy case did not pass (rc=$r) — a check that cannot go green wedges every sprint: $LAST_OUT"
fi

# --- Assertion 2: a MISSING field fails, it does not excuse itself as legacy ---
r=$(rc_of "$VALIDATOR" "$WORK/snap-nofield.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "a missing scope_confirmed FAILS when the capture hook is installed — it is a skipped pause point, not a legacy consumer"
else
  bad "a missing scope_confirmed returned rc=$r instead of 1 — the check reads a skipped pause point as a consumer that predates the release, which is the fail-open direction and excuses the exact conduct it exists to catch"
fi

# --- Assertion 3: there is no third value -------------------------------------
r=$(rc_of "$VALIDATOR" "$WORK/snap-badvalue.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "scope_confirmed: n-a is rejected — the pause point is unconditional, so 'not applicable' is a claim it did not happen"
else
  bad "scope_confirmed: n-a returned rc=$r instead of 1 — an n-a escape makes the mandate optional in one word"
fi

# --- Assertion 4: the boolean alone is not enough ------------------------------
r=$(rc_of "$VALIDATOR" "$WORK/snap-nocite.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "scope_confirmed without a cite FAILS — the field alone is the lead's account of its own conversation"
else
  bad "an uncited scope_confirmed returned rc=$r instead of 1 — the self-declaration hole is open"
fi

# --- Assertion 5: `none` cannot paper over a capture file that has entries -----
r=$(rc_of "$VALIDATOR" "$WORK/snap-citenone.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "cite 'none' FAILS while the capture file holds entries — 'none' is not a way past the check"
else
  bad "cite 'none' returned rc=$r against a NON-empty capture file — the cheapest route past this check is now to write 'none', and every fabrication takes it"
fi

# --- Assertion 6: ...but `none` is honest against an empty capture file --------
r=$(rc_of "$VALIDATOR" "$WORK/snap-citenone.md" "$ANSWERS_EMPTY")
if [ "$r" = "0" ]; then
  ok "cite 'none' PASSES against an empty capture file — a dismissed prompt reported honestly is not a failure"
else
  bad "cite 'none' against an empty capture file returned rc=$r instead of 0 — an operator who dismissed the prompt now wedges the gate, and the remedy is to fabricate a hash"
fi

# --- Assertion 7: a fabricated hash resolves to nothing and is caught ----------
r=$(rc_of "$VALIDATOR" "$WORK/snap-fabricated.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "a well-formed hash that resolves to no entry FAILS — the cite must resolve, not merely look like a hash"
else
  bad "a fabricated hash returned rc=$r instead of 1 — the cite is decorative and the check is a spell-checker for hex"
fi

# --- Assertion 8: a snapshot with no routing record is PENDING, not FAIL -------
r=$(rc_of "$VALIDATOR" "$WORK/snap-premigration.md" "$ANSWERS")
if [ "$r" = "3" ]; then
  ok "a snapshot carrying no routing record reports PENDING — it predates the record, and blaming it would wedge an in-flight sprint"
else
  bad "a pre-migration snapshot returned rc=$r instead of 3 — this is the fourth unreachable hard block the plan warns about"
fi

# --- Assertion 9: no capture hook is PENDING, not FAIL -------------------------
r=$(rc_of "$VALIDATOR" "$WORK/snap-good.md" "$WORK/no-such-answers.md")
if [ "$r" = "3" ]; then
  ok "a consumer with no capture file reports PENDING — nothing could have recorded the answer, so a FAIL would blame the lead for a missing hook"
else
  bad "an absent capture file returned rc=$r instead of 3 — a consumer mid-upgrade is failed for the installer's state"
fi

# --- Assertion 10: an absent snapshot is a FAIL, never a clean pass ------------
r=$(rc_of "$VALIDATOR" "$WORK/no-such-snapshot.md" "$ANSWERS")
if [ "$r" = "2" ]; then
  ok "an absent snapshot exits 2 — a verdict computed against a file that is not there is a verdict about nothing"
else
  bad "an absent snapshot returned rc=$r instead of 2 — an unreadable input renders as no problem"
fi

# --- Assertion 11: the zero-control prints on EVERY path ----------------------
# A regex that matched nothing must not print the same clean line as full coverage.
missing=""
for pair in "snap-good.md:$ANSWERS" "snap-nofield.md:$ANSWERS" "snap-citenone.md:$ANSWERS_EMPTY" \
            "snap-premigration.md:$ANSWERS" "snap-good.md:$WORK/no-such-answers.md"; do
  s="${pair%%:*}"; a="${pair#*:}"
  rc_of "$VALIDATOR" "$WORK/$s" "$a" >/dev/null
  grep -q 'answers_entries_scanned:' <<<"$LAST_OUT" || missing="$missing $s"
done
if [ -z "$missing" ]; then
  ok "answers_entries_scanned: prints on every path — PASS, FAIL and PENDING alike"
else
  bad "answers_entries_scanned: is missing on:$missing — a run that scanned an empty capture file reads exactly like one that scanned forty healthy entries"
fi

# --- Assertion 12: the recorded SHA resolves to the ANSWER bytes ---------------
# This is what makes the cite a citation grade rather than a checksum. Recomputed here
# independently of the hook.
if [ "$SHA" = "$(sha_of "$ANSWER")" ]; then
  ok "the hook's recorded SHA256 is the hash of the operator's answer, recomputed independently"
else
  bad "the recorded SHA256 does not match a hash of the answer it labels — every cite built on it resolves to nothing"
fi

# --- Assertion 13: the hash covers the ANSWER ONLY ----------------------------
# The question is text the LEAD authored. A hash spanning it would let a lead cite words
# it wrote itself and pass a provenance check by talking to itself — the S290
# fabrication, reintroduced through the fix for its mirror image.
Q='Is this the scope you asked for?'
if [ "$SHA" != "$(sha_of "$Q")" ] && [ "$SHA" != "$(sha_of "$Q$ANSWER")" ] \
   && ! grep -q "^- SHA256: $(sha_of "$Q")\$" "$ANSWERS"; then
  ok "the hash covers the answer alone — neither the lead-authored question nor question+answer hashes to it"
else
  bad "the recorded hash spans the lead-authored question — a lead can now cite its own words as operator provenance"
fi

# --- Assertion 14: UNMUTATED CONTROL ------------------------------------------
# The mutants below are copies. This validator resolves its own root by walking up for a
# marker, so a copy placed in a temp tree could resolve somewhere unexpected and die
# before asserting anything — and "no output" would otherwise score as a kill.
CTL="$WORK/validator-control.sh"; cp "$VALIDATOR" "$CTL"
r=$(rc_of "$CTL" "$WORK/snap-good.md" "$ANSWERS")
r2=$(rc_of "$CTL" "$WORK/snap-nofield.md" "$ANSWERS")
if [ "$r" = "0" ] && [ "$r2" = "1" ]; then
  ok "control: an unmutated copy reproduces both verdicts — the copies below can actually run"
else
  bad "CONTROL FAILED: an unmutated copy returned rc=$r/$r2 instead of 0/1, so neither mutant result means anything"
fi

# --- Assertion 15: MUTANT A — the fail-open migration reading -----------------
# Read a missing scope_confirmed as "predates the release" instead of "skipped". This is
# the single most tempting wrong design, and it is one exit code away. Assertion 2 MUST go
# red and nothing else.
MUT_A="$WORK/validator-mutant-a.sh"
anchor_a='pause point that did not happen rather than a consumer that predates it.'
if [ "$(grep -cF "$anchor_a" "$VALIDATOR")" != "1" ]; then
  bad "FIXTURE STALE: mutant A's anchor is not unique in the validator, so the mutation could land on another arm and come out green"
else
  awk -v a="$anchor_a" 'index($0,a){seen=1} seen && /^  exit 1$/ && !done {print "  exit 3"; done=1; next} {print}' \
    "$VALIDATOR" > "$MUT_A"
  if cmp -s "$VALIDATOR" "$MUT_A"; then
    bad "FIXTURE STALE: mutant A is byte-identical to the original — the missing-field arm was reworded"
  elif ! bash -n "$MUT_A" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant A is not a valid shell script, so a 'kill' below would only mean the copy could not run"
  else
    r=$(rc_of "$MUT_A" "$WORK/snap-nofield.md" "$ANSWERS")
    if [ "$r" = "3" ]; then
      ok "mutant A: excusing a missing field as legacy makes it PENDING — assertion 2 has teeth"
    else
      bad "MUTANT A DID NOT FAIL — a missing field still returns rc=$r, so assertion 2 is not testing the migration discriminator"
    fi
    r=$(rc_of "$MUT_A" "$WORK/snap-good.md" "$ANSWERS")
    r2=$(rc_of "$MUT_A" "$WORK/snap-citenone.md" "$ANSWERS")
    if [ "$r" = "0" ] && [ "$r2" = "1" ]; then
      ok "mutant A leaves assertions 1 and 5 intact — the arms are not entangled"
    else
      bad "mutant A ALSO broke assertion 1 or 5 (rc=$r/$r2) — two failures mean the assertions are entangled and one of them is vacuous"
    fi
  fi
fi

# --- Assertion 16: MUTANT B — `none` becomes an unconditional escape ----------
# Drop the guard that makes `none` honest only against an empty capture file. Assertion 5
# MUST go red and assertion 6 must NOT.
MUT_B="$WORK/validator-mutant-b.sh"
anchor_b='  if [ "$ENTRIES" -gt 0 ]; then'
if [ "$(grep -cF "$anchor_b" "$VALIDATOR")" != "1" ]; then
  bad "FIXTURE STALE: mutant B's anchor is not unique in the validator, so the mutation could silently land on another arm"
else
  awk -v a="$anchor_b" 'index($0,a)==1{print "  if false; then"; next} {print}' "$VALIDATOR" > "$MUT_B"
  if cmp -s "$VALIDATOR" "$MUT_B"; then
    bad "FIXTURE STALE: mutant B is byte-identical to the original — the none-guard was reworded"
  elif ! bash -n "$MUT_B" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant B is not a valid shell script, so a 'kill' below would only mean the copy could not run"
  else
    r=$(rc_of "$MUT_B" "$WORK/snap-citenone.md" "$ANSWERS")
    if [ "$r" = "0" ]; then
      ok "mutant B: without the guard 'none' passes against a populated capture file — assertion 5 has teeth"
    else
      bad "MUTANT B DID NOT FAIL — 'none' still returns rc=$r against entries, so assertion 5 is not testing the guard"
    fi
    r=$(rc_of "$MUT_B" "$WORK/snap-citenone.md" "$ANSWERS_EMPTY")
    if [ "$r" = "0" ]; then
      ok "mutant B leaves assertion 6 intact — the guard and the honest-none path are not entangled"
    else
      bad "mutant B ALSO broke assertion 6 (rc=$r) — the two assertions are entangled and one of them is vacuous"
    fi
  fi
fi

# --- Assertion 17: the grammar the real consumer writes ------------------------
# The first version of this check parsed only the line-anchored `- field: value` form
# that the synthetic snapshots above use, and reported "no routing record" against the
# reference consumer's live snapshot, which writes the fields inline and backticked in a
# prose bullet. That is the fail-OPEN direction — PENDING instead of a verdict — and no
# assertion written against this fixture's own synthetic grammar could have caught it.
r=$(rc_of "$VALIDATOR" "$WORK/snap-inline.md" "$ANSWERS")
if [ "$r" = "0" ]; then
  ok "the inline backticked grammar the reference consumer actually writes is parsed, cite and value both"
else
  bad "the consumer's real inline grammar returned rc=$r instead of 0 — the check is anchored to a grammar only this fixture uses, and reads every real snapshot as having no routing record: $LAST_OUT"
fi

# --- Assertion 18: MUTANT C — re-anchor the extractor to line starts -----------
# Assertion 17 MUST go red and the line-anchored cases must NOT.
MUT_C="$WORK/validator-mutant-c.sh"
# The anchor carries NO backslash, deliberately. The first version of this mutant
# anchored on the extractor's own regex, which is dense with them, and passed the string
# through `awk -v` — which processes escape sequences in an assigned value, so `\{` and
# the escaped backtick arrived at index() as `{` and a bare backtick and matched nothing.
# The mutation was a silent no-op and `cmp -s` is what caught it. Anchor on the function
# header and rewrite the line after it.
anchor_c='field_of() {'
if [ "$(grep -cF "$anchor_c" "$VALIDATOR")" != "1" ]; then
  bad "FIXTURE STALE: mutant C's anchor is not unique in the validator, so the mutation could land on another arm"
else
  awk '/^field_of\(\) \{$/ {
         print; getline
         print "  grep -o \"^[[:space:]]*[-*][[:space:]]*$1[[:space:]]*:[[:space:]]*[^[:space:]]\\{1,\\}\" \"$2\" 2>/dev/null \\"
         next
       } {print}' "$VALIDATOR" > "$MUT_C"
  if cmp -s "$VALIDATOR" "$MUT_C"; then
    bad "FIXTURE STALE: mutant C is byte-identical to the original — the extractor was reworded"
  elif ! bash -n "$MUT_C" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant C is not a valid shell script, so a 'kill' below would only mean the copy could not run"
  else
    r=$(rc_of "$MUT_C" "$WORK/snap-inline.md" "$ANSWERS")
    if [ "$r" = "1" ]; then
      ok "mutant C: anchoring the extractor to line starts blinds it to the consumer's real grammar — assertion 17 has teeth"
    else
      bad "MUTANT C DID NOT FAIL — the inline grammar still returns rc=$r when the extractor is anchored, so assertion 17 is not testing the extractor"
    fi
    r=$(rc_of "$MUT_C" "$WORK/snap-good.md" "$ANSWERS")
    if [ "$r" = "0" ]; then
      ok "mutant C leaves the line-anchored cases intact — the two grammars are separately asserted"
    else
      bad "mutant C ALSO broke assertion 1 (rc=$r) — the assertions are entangled and one of them is vacuous"
    fi
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "scope-confirmation: PASS"; exit 0; fi
echo "scope-confirmation: $fails assertion(s) FAILED" >&2
exit 1
