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
#
# THE GUARD IS LINE-ANCHORED, AND IT WAS NOT. It read `grep -cF 'field_of() {'`, a
# whole-line-agnostic substring count, while the mutation it guards matches
# `/^field_of\(\) \{$/` -- a WEAKER pattern guarding a STRICTER one, which is a guard that
# can fire on text the mutation could never touch. It went off the moment the validator's
# own comment block quoted `sed -n '/^field_of() {/,/^}/p'` (the receipt's lift boundaries),
# taking the count to 2 and reporting FIXTURE STALE against a validator whose definition
# line is still unique. Measured on that tree: `-cF` = 2, the anchored form = 1.
anchor_c='^field_of\(\) \{$'
if [ "$(grep -cE "$anchor_c" "$VALIDATOR")" != "1" ]; then
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

# =============================================================================
# THE PRODUCER'S GRAMMAR (assertions 19-26) AND THE LAYER BATTERY (27-31).
# =============================================================================
# WHY THESE EXIST. Assertions 1-18 seed exactly the two grammars `field_of` was written to
# accept -- re-derived here rather than taken on trust: 0 bold-form `scope_confirmed` lines
# in seed.sh against a control of 5 total mentions, 0 in run.sh against a control of 9. A
# reader proved against its own accept-set is proved against nothing, and this one was
# misparsing SIX further forms while every arm above stayed green.
#
# WHAT THE SIX ARE, driven over the PRE-FIX function in one invocation rather than restated
# from the filing, which named two:
#     - **scope_confirmed:** confirmed              -> `**`           (malformed-value FAIL)
#     - **scope_confirmed**: confirmed              -> empty          (ACCUSATION)
#     - scope_confirmed: `confirmed`                -> empty          (ACCUSATION)
#     - **scope_confirmed: confirmed**              -> `confirmed**`  (malformed-value FAIL)
#     - __scope_confirmed__: confirmed              -> empty          (ACCUSATION)
#     - **scope_confirmed:** confirmed — prose      -> `**`           (malformed-value FAIL)
# The accusation is the harsher half: a well-formed snapshot carrying a correct value is
# reported as evidence the lead skipped a MANDATORY operator pause point.
#
# EVERY ARM BELOW DRIVES THE SHIPPING VALIDATOR END TO END, not a lifted copy of the
# function. A lift is a second implementation whose bugs nobody finds, and the harm this
# defect does is an exit code and a message reaching an operator -- so that is what is read.

# Assert on the message as well as the code. rc alone cannot separate the pre-fix from the
# fix on a malformed value: both exit 1.
#
# `rc_of` CANNOT BE USED FOR A MESSAGE ARM AND THAT IS NOT OBVIOUS. It is called as
# `r=$(rc_of ...)`, so it runs in a SUBSHELL and the `LAST_OUT` it sets is discarded; the
# variable the caller then reads still holds whatever the last non-substituted call left
# there. Measured while writing these arms: seven of them read the PENDING text from
# assertion 11's final loop iteration and reported a failure the validator had not
# produced — a stale instrument, reading exactly like a real finding. `run_v` sets both
# the code and the output in the CURRENT shell.
LAST_RC=0
run_v() { LAST_OUT="$(bash "$1" --snapshot "$2" --answers "$3" 2>&1)"; LAST_RC=$?; }
out_has() { grep -qF "$1" <<<"$LAST_OUT"; }

# --- Assertion 19: the producer's dominant form -------------------------------
run_v "$VALIDATOR" "$WORK/snap-prod-bold.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: confirmed"; then
  ok "the producer's own grammar passes — bold name, colon inside the span, prose after the value, and a bold+backticked cite that resolves"
else
  bad "the producer's dominant grammar returned rc=$r — this is the form the reference consumer writes on every routing-record field, so the check now reports a malformed value on a well-formed snapshot: $LAST_OUT"
fi

# --- Assertion 20: colon OUTSIDE the span, and the value is `corrected` --------
# THE VALUE-FIDELITY ARM. Its expected value is `corrected`, so it cannot pass against a
# parser that answers `confirmed` unconditionally — which is the hole in BL-065's own
# receipt, and mutant E below is that stub.
run_v "$VALIDATOR" "$WORK/snap-prod-boldout.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: corrected"; then
  ok "colon-outside bold passes and reports 'corrected' — the value is read, not assumed, and the cite written before it is not mistaken for it"
else
  bad "colon-outside bold returned rc=$r without reporting 'corrected' — the pre-fix returned EMPTY here and accused the lead of a Rule 3(d) pause point that did not happen: $LAST_OUT"
fi

# --- Assertion 21: a BACKTICKED value -----------------------------------------
run_v "$VALIDATOR" "$WORK/snap-prod-btval.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: confirmed"; then
  ok "a backticked value parses — the value class no longer excludes the character the producer wraps hashes and enums in"
else
  bad "a backticked value returned rc=$r — the pre-fix value class excluded a backtick, so this returned empty and became the same accusation: $LAST_OUT"
fi

# --- Assertion 22: `__underscore bold__` --------------------------------------
run_v "$VALIDATOR" "$WORK/snap-prod-uscore.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: confirmed"; then
  ok "doubled-underscore emphasis parses — the doubled form CAN be normalized even though the single one cannot, and the validator names that boundary"
else
  bad "__scope_confirmed__ returned rc=$r — a second established bold spelling reads as a skipped pause point: $LAST_OUT"
fi

# --- Assertion 23: a bold span wrapping the whole pair ------------------------
run_v "$VALIDATOR" "$WORK/snap-prod-boldpair.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: confirmed"; then
  ok "a bold span wrapping name and value together parses — the pre-fix read the value as 'confirmed**' and called it malformed"
else
  bad "a whole-pair bold span returned rc=$r: $LAST_OUT"
fi

# --- Assertion 24: THE NEGATIVE ARM -------------------------------------------
# A bold routing record with NO scope_confirmed must still be the accusation. Without this,
# every arm above passes against `field_of() { echo confirmed; }` — and the rc is NOT the
# discriminator, because that stub also exits 1 here (the cite comes back 'confirmed', which
# is not hex and not 'none'). The MESSAGE is what separates a missing field from a broken
# parser, so the message is what this reads.
run_v "$VALIDATOR" "$WORK/snap-prod-nofield.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "1" ] && out_has "carries no 'scope_confirmed' field"; then
  ok "a bold routing record with no scope_confirmed FAILS with the missing-field accusation — normalizing wrappers does not manufacture a field that is not there"
else
  bad "a bold record missing scope_confirmed returned rc=$r without the missing-field accusation — either the normalizer invented a value or the FAIL is arriving for the wrong reason, and both read identically from the exit code: $LAST_OUT"
fi

# --- Assertion 25: a malformed value is reported AS ITSELF --------------------
# Pre-fix and fixed both exit 1 on this snapshot. The pre-fix says the value is '**'; the
# fix says it is 'n-a'. An arm reading only the exit code cannot tell a check that read the
# field from one that read the markdown around it.
run_v "$VALIDATOR" "$WORK/snap-prod-badvalue.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "1" ] && out_has "scope_confirmed is 'n-a'" && ! out_has "scope_confirmed is '**'"; then
  ok "a bold field carrying a value outside the closed set is reported as 'n-a', not as '**' — the operator is told what the record actually says"
else
  bad "a bold out-of-set value returned rc=$r and did not name 'n-a' — reporting the markup as the value sends an operator to look for a field that reads correctly: $LAST_OUT"
fi

# --- Assertion 26: both install layouts were NAMED, and one resolved ----------
# I33: install.sh lands core/scripts/<x> at scripts/ai-dlc/<x>. seed.sh names both
# candidates and resolves by walking UP for the hook itself rather than counting `..` hops —
# the hop count is 3 in both layouts today by coincidence, and a coincidence resolves
# nothing the moment either tree moves a level.
if [ -n "${CAND_DIST:-}" ] && [ -n "${CAND_CONS:-}" ] && [ "$VALIDATOR" = "$CAND_DIST" -o "$VALIDATOR" = "$CAND_CONS" ]; then
  ok "both layout candidates named and one resolved: $VALIDATOR"
else
  bad "the resolved validator '$VALIDATOR' is neither named candidate ('${CAND_DIST:-}' | '${CAND_CONS:-}') — a fixture that resolves somewhere it did not name is asserting against a file nobody chose"
fi

# --- the field_of mutation harness --------------------------------------------
# Mutants are COPIES with the body of `field_of` swapped for a replacement read from a
# file. The body arrives through a FILE rather than through `awk -v`: mutant C's first
# version passed a regex through `awk -v`, which processes escape sequences in an assigned
# value, so `\{` and the escaped backtick reached index() as `{` and a bare backtick and
# matched nothing. Only `cmp -s` caught it. A path carries no backslashes.
MUT_PATH=""
build_field_of_mutant() {   # $1 = label, $2 = file holding the replacement body
  MUT_PATH=""
  _out="$WORK/validator-mutant-$1.sh"
  # Line-anchored, matching the awk program below. A substring count would go off on the
  # validator's own comment quoting the receipt's `/^field_of() {/,/^}/p` lift boundaries.
  if [ "$(grep -cE '^field_of\(\) \{$' "$VALIDATOR")" != "1" ]; then
    bad "FIXTURE STALE: mutant $1's anchor '^field_of() {' is not unique in the validator, so the mutation could land somewhere else"
    return 1
  fi
  awk -v bf="$2" '
    /^field_of\(\) \{$/ { print; while ((getline l < bf) > 0) print l; close(bf); skip=1; next }
    skip && /^\}$/      { print; skip=0; next }
    skip                { next }
                        { print }
  ' "$VALIDATOR" > "$_out"
  if cmp -s "$VALIDATOR" "$_out"; then
    bad "FIXTURE STALE: mutant $1 is byte-identical to the original — the mutation matched nothing and a green run below would prove only that"
    return 1
  fi
  if ! bash -n "$_out" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant $1 is not a valid shell script, so a 'kill' below would only mean the copy could not run"
    return 1
  fi
  # The swap must be confined to the function. Everything else has to survive, or a kill
  # below could be a truncated file rather than a changed parser.
  if ! grep -qF "carries no 'scope_confirmed' field" "$_out" \
     || ! grep -qF 'cite resolves to a hook-written answer record' "$_out"; then
    bad "FIXTURE BROKEN: mutant $1 lost text outside field_of — the mutation is not confined to the function body"
    return 1
  fi
  MUT_PATH="$_out"
  return 0
}

kills=0

# --- Assertion 27: MUTANT D — the PRE-FIX field_of, restored verbatim ---------
# Lifted from the blob this remediation replaced. Assertions 19-25 MUST go red; assertions
# 1 and 17 -- the two grammars the pre-fix was written to accept -- MUST stay green. That
# second half is the fixture's own blindness, made executable: it is exactly the state in
# which this directory shipped green over six misparsed grammars.
cat > "$WORK/body-d.sh" <<'BODY'
  grep -o "\`\{0,1\}$1\`\{0,1\}[[:space:]]*:[[:space:]]*[^[:space:]\`]\{1,\}" "$2" 2>/dev/null \
    | head -1 \
    | sed -e "s/^.*$1\`\{0,1\}[[:space:]]*:[[:space:]]*//" -e 's/[`.,;:]\{1,\}$//'
BODY
if build_field_of_mutant d "$WORK/body-d.sh"; then
  red=0
  for s in bold boldout btval uscore boldpair; do
    run_v "$MUT_PATH" "$WORK/snap-prod-$s.md" "$ANSWERS"; r=$LAST_RC
    [ "$r" = "0" ] || red=$((red+1))
  done
  run_v "$MUT_PATH" "$WORK/snap-prod-badvalue.md" "$ANSWERS"; r=$LAST_RC
  out_has "scope_confirmed is '**'" && red=$((red+1))
  if [ "$red" -eq 6 ]; then
    kills=$((kills+1))
    ok "mutant D: the pre-fix extractor fails all five producer grammars and reports the markup as the value — assertions 19-25 have teeth"
  else
    bad "MUTANT D KILLED ONLY $red OF 6 — the pre-fix extractor still satisfies assertions 19-25, so they are not testing the extractor"
  fi
  run_v "$MUT_PATH" "$WORK/snap-good.md" "$ANSWERS"; r=$LAST_RC
  run_v "$MUT_PATH" "$WORK/snap-inline.md" "$ANSWERS"; r2=$LAST_RC
  run_v "$MUT_PATH" "$WORK/snap-prod-nofield.md" "$ANSWERS"; r3=$LAST_RC
  if [ "$r" = "0" ] && [ "$r2" = "0" ] && [ "$r3" = "1" ]; then
    ok "mutant D leaves assertions 1, 17 and 24 intact — the pre-fix accepted its own two grammars and correctly refused a missing field, which is why this fixture shipped green over the defect"
  else
    bad "mutant D ALSO broke assertion 1, 17 or 24 (rc=$r/$r2/$r3) — the new arms are entangled with the old ones and one of them is vacuous"
  fi
fi

# --- Assertion 28: MUTANT D2 — the `**`/`__` normalization layer removed ------
# THE FIX IS LAYERED AND EVERY LAYER IS REVERTED SEPARATELY. A partial revert that left a
# layer in place would prove that layer and come out green. Layer 1 is the emphasis strip.
# Assertions 19, 20 and 22 MUST go red; 21 must NOT — the backtick layer is still there.
cat > "$WORK/body-d2.sh" <<'BODY'
  sed -e 's/`//g' "$2" 2>/dev/null \
    | grep -o "$1[[:space:]]*:[[:space:]]*[^[:space:]]\{1,\}" \
    | head -1 \
    | sed -e "s/^.*$1[[:space:]]*:[[:space:]]*//" -e 's/[.,;:]\{1,\}$//'
BODY
if build_field_of_mutant d2 "$WORK/body-d2.sh"; then
  red=0
  for s in bold boldout uscore; do
    run_v "$MUT_PATH" "$WORK/snap-prod-$s.md" "$ANSWERS"; r=$LAST_RC
    [ "$r" = "0" ] || red=$((red+1))
  done
  if [ "$red" -eq 3 ]; then
    kills=$((kills+1))
    ok "mutant D2: dropping the emphasis strip breaks all three bold spellings — that layer is separately load-bearing"
  else
    bad "MUTANT D2 KILLED ONLY $red OF 3 — the emphasis-strip layer is not what assertions 19, 20 and 22 are testing"
  fi
  run_v "$MUT_PATH" "$WORK/snap-prod-btval.md" "$ANSWERS"; r=$LAST_RC
  run_v "$MUT_PATH" "$WORK/snap-inline.md" "$ANSWERS"; r2=$LAST_RC
  if [ "$r" = "0" ] && [ "$r2" = "0" ]; then
    ok "mutant D2 leaves assertions 21 and 17 intact — the backtick layer is asserted separately from the emphasis layer"
  else
    bad "mutant D2 ALSO broke assertion 21 or 17 (rc=$r/$r2) — the two layers are asserted by one arm and neither is independently proved"
  fi
fi

# --- Assertion 29: MUTANT D3 — the `__` half of the emphasis strip removed ----
# Layer 1 splits again. Assertion 22 MUST go red and NOTHING else may.
cat > "$WORK/body-d3.sh" <<'BODY'
  sed -e 's/\*\*//g' -e 's/`//g' "$2" 2>/dev/null \
    | grep -o "$1[[:space:]]*:[[:space:]]*[^[:space:]]\{1,\}" \
    | head -1 \
    | sed -e "s/^.*$1[[:space:]]*:[[:space:]]*//" -e 's/[.,;:]\{1,\}$//'
BODY
if build_field_of_mutant d3 "$WORK/body-d3.sh"; then
  run_v "$MUT_PATH" "$WORK/snap-prod-uscore.md" "$ANSWERS"; r=$LAST_RC
  if [ "$r" = "1" ]; then
    kills=$((kills+1))
    ok "mutant D3: dropping only the __ strip breaks only the underscore spelling — assertion 22 owns a layer of its own"
  else
    bad "MUTANT D3 DID NOT FAIL — __scope_confirmed__ still returns rc=$r without the __ strip, so assertion 22 is proved by the ** strip and is vacuous"
  fi
  red=0
  for s in bold boldout btval boldpair; do
    run_v "$MUT_PATH" "$WORK/snap-prod-$s.md" "$ANSWERS"; r=$LAST_RC
    [ "$r" = "0" ] || red=$((red+1))
  done
  if [ "$red" -eq 0 ]; then
    ok "mutant D3 leaves assertions 19, 20, 21 and 23 intact — it fails only its own assertion"
  else
    bad "mutant D3 ALSO broke $red of assertions 19, 20, 21, 23 — the arms are entangled and some of them are vacuous"
  fi
fi

# --- Assertion 30: MUTANT D4 — the backtick layer reverted to its pre-fix form -
# Layer 2, reverted alone: no backtick strip, the pre-fix's backtick-EXCLUDING value class,
# and the backtick back in the trailing-strip class. Assertion 21 MUST go red and nothing
# else — including assertion 17, whose inline grammar survives on the excluding value class
# exactly as it did before the fix.
#
# THE THIRD LAYER HAS NO MUTANT, DELIBERATELY, AND THAT IS A MEASUREMENT. Reverting the
# widened value class ALONE while keeping the backtick strip changes NO answer on any of
# the nine grammars driven here — the strip removes the character the class excluded, so
# the exclusion has nothing left to exclude. It is subsumed, not separable, and a mutant
# for it would kill nothing and read exactly like an arm that cannot fire.
cat > "$WORK/body-d4.sh" <<'BODY'
  sed -e 's/\*\*//g' -e 's/__//g' "$2" 2>/dev/null \
    | grep -o "$1[[:space:]]*:[[:space:]]*[^[:space:]\`]\{1,\}" \
    | head -1 \
    | sed -e "s/^.*$1[[:space:]]*:[[:space:]]*//" -e 's/[`.,;:]\{1,\}$//'
BODY
#
# D4 KILLS TWO ARMS AND THE OVERLAP IS DECLARED, NOT DISCOVERED. Assertion 19's snapshot is
# the producer's own routing record, and the producer writes a BACKTICKED value for cite
# fields under a BOLD name — `- **user_request_cite:** ` + backticked hex — so that one
# snapshot depends on both layers at once. That is the corpus being faithful, not the arms
# being entangled: assertion 21 ISOLATES the backtick layer (D4 kills it, D2 leaves it
# green) and assertions 20/22/23 isolate the emphasis layer (D2 kills them, D4 leaves them
# green), so each layer still has an arm that only it can kill. Assertion 21 OWNS the
# backtick case; assertion 19 stands with it rather than instead of it.
if build_field_of_mutant d4 "$WORK/body-d4.sh"; then
  run_v "$MUT_PATH" "$WORK/snap-prod-btval.md" "$ANSWERS"; r=$LAST_RC
  run_v "$MUT_PATH" "$WORK/snap-prod-bold.md" "$ANSWERS"; r2=$LAST_RC
  if [ "$r" = "1" ] && [ "$r2" = "1" ]; then
    kills=$((kills+1))
    ok "mutant D4: reverting the backtick handling alone breaks the backticked value and the producer's backticked cite — assertion 21 owns a layer of its own and assertion 19 stands with it"
  else
    bad "MUTANT D4 DID NOT FAIL (rc=$r/$r2) — a backticked value or cite still parses with the pre-fix backtick handling, so assertion 21 is proved by the emphasis strip and is vacuous"
  fi
  red=0
  for s in boldout uscore boldpair; do
    run_v "$MUT_PATH" "$WORK/snap-prod-$s.md" "$ANSWERS"; r=$LAST_RC
    [ "$r" = "0" ] || red=$((red+1))
  done
  run_v "$MUT_PATH" "$WORK/snap-inline.md" "$ANSWERS"; r=$LAST_RC
  [ "$r" = "0" ] || red=$((red+1))
  if [ "$red" -eq 0 ]; then
    ok "mutant D4 leaves assertions 20, 22, 23 and 17 intact — the emphasis layer is asserted by arms the backtick layer cannot reach"
  else
    bad "mutant D4 ALSO broke $red of assertions 20, 22, 23, 17 — those carry no backtick, so the two layers are not separately asserted"
  fi
fi

# --- Assertion 31: MUTANT E — the constant-return stub ------------------------
# `field_of() { echo confirmed; }` is a "fix" that closes the check by breaking it, and
# BL-065's own receipt ACCEPTS it: the receipt asserts only that the two bold forms yield
# `confirmed`, which a parser that always says `confirmed` satisfies perfectly. This arm is
# the negative half that receipt lacks.
#
# ARM OWNERSHIP IS DECLARED RATHER THAN ASSUMED. A constant-return parser breaks the file
# globally, so several arms go red together; that is genuine overlap, not entanglement.
# Assertion 20 (the value must read `corrected`) and assertion 24 (a missing field must
# still be the missing-field accusation) OWN this case, and they are the two read here.
cat > "$WORK/body-e.sh" <<'BODY'
  echo confirmed
BODY
if build_field_of_mutant e "$WORK/body-e.sh"; then
  run_v "$MUT_PATH" "$WORK/snap-prod-boldout.md" "$ANSWERS"; r=$LAST_RC
  out20=0; { [ "$r" = "0" ] && out_has "scope_confirmed: corrected"; } || out20=1
  run_v "$MUT_PATH" "$WORK/snap-prod-nofield.md" "$ANSWERS"; r=$LAST_RC
  out24=0; { [ "$r" = "1" ] && out_has "carries no 'scope_confirmed' field"; } || out24=1
  if [ "$out20" -eq 1 ] && [ "$out24" -eq 1 ]; then
    kills=$((kills+1))
    ok "mutant E: a parser that answers 'confirmed' unconditionally is caught by assertion 20 (the value must read 'corrected') and by assertion 24 (a missing field must stay a missing field)"
  else
    bad "MUTANT E SURVIVED assertion 20 and/or 24 ($out20/$out24) — this fixture accepts a fix that closes the check by breaking the parser, which is the hole in BL-065's own receipt"
  fi
fi

# --- Assertion 32: the battery killed something -------------------------------
# A mutant that kills nothing reads exactly like an arm that cannot fire, and `cmp -s` does
# not separate them: the mutation applies cleanly to a file the run never loaded.
if [ "$kills" -eq 5 ]; then
  ok "all 5 field_of mutants were killed against the resolved validator $VALIDATOR — the arms above are running against the code they name"
else
  bad "only $kills of 5 field_of mutants were killed — an unkilled mutant means either the arm cannot fire or the mutation landed on a copy this run never executed"
fi

echo
if [ "$fails" -eq 0 ]; then echo "scope-confirmation: PASS"; exit 0; fi
echo "scope-confirmation: $fails assertion(s) FAILED" >&2
exit 1
