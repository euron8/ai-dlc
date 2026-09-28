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

# The deferred-items arms below build scratch git repositories. Git exports GIT_DIR to a
# hook run from a linked worktree, and an inherited one turns `git init` into a silent
# no-op that redirects every later commit onto the caller's index.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

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

# =============================================================================
# ASSERTIONS 33-36: CORPUS IDENTITY.
# =============================================================================
# THE DEFECT. Both inputs are caller-supplied (`--snapshot`, `--answers`) and default to
# paths under a root this script resolves for itself, so a run pointed at the wrong tree
# is a real state. Before the identity lines, `answers_entries_scanned: 3` plus
# `PASS  scope_confirmed: confirmed` was the WHOLE of a passing run's output — no path
# anywhere — so two runs over two different trees holding identical bytes were
# BYTE-IDENTICAL. Nothing on screen separated a verdict about this sprint from a verdict
# about a copy of it.
#
# THE ARM IS KEYED ON DISCRIMINATION, NOT ON A SPELLING. The pair is driven twice over two
# mktemp corpora seeded with the same bytes; the outputs must DIFFER **and** each must
# carry ITS OWN two paths. Those are separate requirements and the second is the load-
# bearing one: a nonce, a PID or a timestamp makes two runs differ while naming nothing,
# and mutant G below is exactly that fix. No label text is grepped, so re-wording
# `snapshot:` leaves this working; what is demanded is the resolved path, and the roots
# are mktemp names, so no implementation can hardcode the literal.
#
# THE ARM IS PRESENCE-SHAPED. It requires two specific paths to APPEAR in a run that
# reached the PASS emitter, so a validator replaced by `exit 0` fails it by construction.
SC_IDENT_WHY=""
sc_ident_corpus() {   # -> prints a fresh corpus root holding a copy of the healthy pair
  local d
  d="$(mktemp -d "$WORK/ident.XXXXXX")" || return 1
  cp "$WORK/snap-good.md" "$d/snapshot.md" || return 1
  cp "$ANSWERS"           "$d/answers.md"  || return 1
  printf '%s\n' "$d"
}
# sc_ident_holds <validator> — 0 iff the run reached PASS, the two runs are
# distinguishable, and each names the snapshot and the answers file it actually read.
sc_ident_holds() {
  local v="$1" a b oa ob ra rb
  SC_IDENT_WHY=""
  a="$(sc_ident_corpus)" || { SC_IDENT_WHY="could not build corpus A"; return 1; }
  b="$(sc_ident_corpus)" || { SC_IDENT_WHY="could not build corpus B"; return 1; }
  oa="$(bash "$v" --snapshot "$a/snapshot.md" --answers "$a/answers.md" 2>&1)"; ra=$?
  ob="$(bash "$v" --snapshot "$b/snapshot.md" --answers "$b/answers.md" 2>&1)"; rb=$?
  if [ "$ra" != "0" ] || [ "$rb" != "0" ]; then
    SC_IDENT_WHY="rc=$ra/$rb, expected 0/0 — the run never reached the PASS emitter"; return 1
  fi
  if ! grep -qF 'PASS  scope_confirmed:' <<<"$oa"; then
    SC_IDENT_WHY="no PASS line — this arm did not reach the emitter it claims to guard"; return 1
  fi
  if [ "$oa" = "$ob" ]; then
    SC_IDENT_WHY="two different trees holding identical bytes produced byte-identical output"
    return 1
  fi
  if ! grep -qF "$a/snapshot.md" <<<"$oa" || ! grep -qF "$a/answers.md" <<<"$oa"; then
    SC_IDENT_WHY="run A names neither the snapshot it read nor the capture file it counted"
    return 1
  fi
  if ! grep -qF "$b/snapshot.md" <<<"$ob" || ! grep -qF "$b/answers.md" <<<"$ob"; then
    SC_IDENT_WHY="run B names neither the snapshot it read nor the capture file it counted"
    return 1
  fi
  if grep -qF "$b" <<<"$oa"; then
    SC_IDENT_WHY="run A's output carries run B's root — the paths are not the ones it resolved"
    return 1
  fi
  return 0
}

# --- Assertion 33: the passing run names both corpora --------------------------
if sc_ident_holds "$VALIDATOR"; then
  ok "a passing run names the snapshot it read and the capture file it counted, and two identical corpora in different trees are distinguishable"
else
  bad "a passing run carries no corpus identity — $SC_IDENT_WHY. Two sprints' worth of identical content produce one verdict, and the operator cannot tell which tree it is about"
fi

# --- Assertion 34: the DEFAULT-RESOLVED paths are named, not the arguments -----
# THE ATTACK THIS CLOSES. Assertion 33 drives both corpora through `--snapshot`/`--answers`,
# so a "fix" that echoed the argument vector — `echo "$@"` on the way out — satisfies it
# while proving nothing about what the script RESOLVED. The interesting case is the one
# with no arguments at all: both inputs default to paths under a root this script walks up
# for, and that root is exactly where a run can silently be about the wrong tree. Nothing
# is passed here, so an argument echo names nothing and this arm fires.
SC_D="$(mktemp -d "$WORK/dflt.XXXXXX")"
mkdir -p "$SC_D/_bmad-output"
cp "$WORK/snap-good.md" "$SC_D/_bmad-output/pipeline-snapshot.md"
cp "$ANSWERS"           "$SC_D/_bmad-output/operator-answers-history.md"
SC_DOUT="$(AI_DLC_PROJECT_ROOT="$SC_D" bash "$VALIDATOR" 2>&1)"; SC_DRC=$?
if [ "$SC_DRC" = "0" ] \
   && grep -qF "$SC_D/_bmad-output/pipeline-snapshot.md" <<<"$SC_DOUT" \
   && grep -qF "$SC_D/_bmad-output/operator-answers-history.md" <<<"$SC_DOUT"; then
  ok "a run with NO path arguments names the two files it resolved for itself — the identity is the resolved value, not an echo of argv"
else
  bad "a defaulted run (rc=$SC_DRC) did not name the snapshot and capture file it resolved — the identity lines could be satisfied by echoing the argument vector, which says nothing about a run that was given no arguments: $SC_DOUT"
fi

# --- Assertion 35: UNMUTATED CONTROL for the identity mutants ------------------
# Positive conjunct included: `sc_ident_holds` demands the PASS line and two paths, so this
# control cannot pass against a copy replaced by `exit 0`.
SC_CTL="$WORK/ident-control.sh"; cp "$VALIDATOR" "$SC_CTL"
SC_CTL_OK=0
if sc_ident_holds "$SC_CTL"; then
  ok "control: an unmutated copy reproduces the identity lines, so a mutant's silence below means mutation and not breakage"
  SC_CTL_OK=1
else
  bad "CONTROL FAILED ($SC_IDENT_WHY) — the two identity mutants below are uninterpretable"
fi

if [ "$SC_CTL_OK" = "1" ]; then
  # --- Assertion 36: MUTANT F — the identity lines deleted --------------------
  # The state this release replaced. Assertion 33 MUST go red; the arms above must not.
  MUT_F="$WORK/validator-mutant-f.sh"
  anchor_f1='say "  snapshot: '
  anchor_f2='say "  answers:  '
  if [ "$(grep -cF "$anchor_f1" "$VALIDATOR")" != "1" ] \
     || [ "$(grep -cF "$anchor_f2" "$VALIDATOR")" != "1" ]; then
    bad "FIXTURE STALE: mutant F's anchors are not unique in the validator, so the deletion could land on another emitter"
  else
    awk -v s="$anchor_f1" -v n="$anchor_f2" \
      'index($0,s) || index($0,n) { next } { print }' "$VALIDATOR" > "$MUT_F"
    if cmp -s "$VALIDATOR" "$MUT_F"; then
      bad "FIXTURE STALE: mutant F is byte-identical to the original — the identity lines were reworded and the deletion matched nothing"
    elif ! bash -n "$MUT_F" 2>/dev/null; then
      bad "FIXTURE BROKEN: mutant F is not a valid shell script, so a 'kill' below would only mean the copy could not run"
    else
      if sc_ident_holds "$MUT_F"; then
        bad "MUTANT F SURVIVED — a validator that names neither corpus still satisfies assertion 33, so that assertion is not testing the identity lines"
      else
        ok "mutant F: deleting the identity lines makes two different trees indistinguishable ($SC_IDENT_WHY) — assertion 33 has teeth"
      fi
      # And nothing else moves. The identity lines are additive; every verdict arm above
      # must survive their removal, or assertion 33 is entangled with the ones that matter.
      r=$(rc_of "$MUT_F" "$WORK/snap-good.md" "$ANSWERS")
      r2=$(rc_of "$MUT_F" "$WORK/snap-nofield.md" "$ANSWERS")
      r3=$(rc_of "$MUT_F" "$WORK/snap-citenone.md" "$ANSWERS")
      if [ "$r" = "0" ] && [ "$r2" = "1" ] && [ "$r3" = "1" ]; then
        ok "mutant F leaves assertions 1, 2 and 5 intact — corpus identity is asserted by an arm no verdict arm covers"
      else
        bad "mutant F ALSO moved a verdict (rc=$r/$r2/$r3) — the identity lines are not additive and assertion 33 is entangled with the verdict arms"
      fi
      # Assertion 34 gets its teeth from the same mutant. Without this cell that arm is
      # never driven against a subject that fails it, and an arm nothing can falsify reads
      # exactly like one that passed.
      SC_FOUT="$(AI_DLC_PROJECT_ROOT="$SC_D" bash "$MUT_F" 2>&1)"
      if grep -qF "$SC_D/_bmad-output/pipeline-snapshot.md" <<<"$SC_FOUT"; then
        bad "MUTANT F SURVIVED assertion 34 — the defaulted run still names its resolved snapshot with the identity lines deleted, so assertion 34 is reading a path emitted somewhere else"
      else
        ok "mutant F also kills assertion 34 — the defaulted run's resolved paths come from the identity lines and nowhere else"
      fi
    fi
  fi

  # --- Assertion 37: MUTANT G — identity replaced by a per-run NONCE ----------
  # THE FIX THAT DISCRIMINATES WITHOUT NAMING. `$$-$RANDOM` is evaluated by the mutant at
  # run time, so its two runs differ from each other exactly as the real validator's do,
  # and neither carries a path. An arm keyed only on "the outputs differ" passes against
  # it. This is the arm's own false-fix control, and it is why assertion 33 demands the
  # resolved path rather than a difference.
  MUT_G="$WORK/validator-mutant-g.sh"
  awk -v s="$anchor_f1" -v n="$anchor_f2" '
    index($0,s) { print "say \"  snapshot: nonce-$$-$RANDOM\""; next }
    index($0,n) { print "say \"  answers:  nonce-$$-$RANDOM\""; next }
                { print }
  ' "$VALIDATOR" > "$MUT_G"
  if cmp -s "$VALIDATOR" "$MUT_G"; then
    bad "FIXTURE STALE: mutant G is byte-identical to the original — the nonce substitution matched nothing and assertion 33's nonce-resistance is unproved"
  elif ! bash -n "$MUT_G" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant G is not a valid shell script, so a 'kill' below would only mean the copy could not run"
  else
    if sc_ident_holds "$MUT_G"; then
      bad "MUTANT G SURVIVED — a per-run nonce that names no corpus satisfies assertion 33, so that assertion is a differ-check and not a naming check"
    else
      ok "mutant G: a per-run nonce varies the output exactly as the real paths do and still fails assertion 33 ($SC_IDENT_WHY) — the arm demands the corpus be NAMED"
    fi
  fi
fi

# =============================================================================
# ASSERTIONS 38-: scope_deferred_items -- the part of the ask Step 6 deferred is a
# FILED carry-over item, and an absent field is legacy only by a date no agent writes.
# =============================================================================
# THE DEFECT. A sprint's scope confirmation ratified a phase split, and the deferred phase
# was recorded only in the lead-authored question -- no hash covers it and no later step
# reads it. The arm resolves every listed id to a not-CLOSED `### <id>` item in the live
# carry-over backlog or its archive, and decides an ABSENT field by comparing the hook's
# answer timestamp against the commit that first stamped the introducing release.
#
# THE BACKLOG IS SEEDED IN THE CONSUMER'S OWN SHAPES, not the reader's accept-set: both
# status spellings the reference consumer writes (`**Status:** X` 37 times and
# `**Status: X` 52 times in its live backlog), an item whose CURRENT status sits above a
# superseded one, a heading carrying trailing prose, and headings that are a string
# PREFIX of another id.
SD="$WORK/sdi"; mkdir -p "$SD/pa"
cat > "$SD/pa/carry-over-backlog.md" <<'BL'
# Carry-over Backlog

## Open items

### CO-S315-PHASE-2-BACKFILL — the historical backfill phase the operator deferred [P2]
**Status:** OPEN
Filed at route.md Step 6.

### CO-S315-PHASE-3-CUTOVER
**Status: OPEN.** The second status spelling the consumer writes.

### CO-S312-IN-SPRINT-ITEM
**Status:** IN SPRINT (S315, carry-over-evaluation)

### CO-S310-DEFERRAL-ITEM
**Status:** DEFERRAL_REQUESTED

### CO-S309-CLOSED-ITEM
**Status:** CLOSED - delivered in sprint 314 via story-S314-2

### CO-S308-REOPENED-ITEM
**Status:** OPEN — reopened at S315 triage
**Status:** CLOSED (superseded, retained for history)

### CO-S315-bad_id
**Status:** OPEN

### CO-S315-PARTIAL-X
**Status:** OPEN

### CO-S307-NO-STATUS-ITEM
A body with no status line at all.
BL
cat > "$SD/pa/carry-over-backlog-archive.md" <<'AR'
# Carry-over Backlog Archive

### CO-S290-ARCHIVED-OPEN
**Status:** DEFERRAL_REQUESTED

### CO-S290-ARCHIVED-CLOSED
**Status: CLOSED - delivered in sprint 291.**
AR
SD_BL="$SD/pa/carry-over-backlog.md"

# One routing record per value. `-` omits the field entirely (the ABSENT case).
sd_snap() {   # $1 name, $2 value or '-', $3 cite (default $SHA)
  local f="$SD/snap-$1.md"
  {
    echo "# Pipeline Snapshot"; echo; echo "## Pipeline Position"
    echo "- user_request_verbatim: Sprint 315: TELv3 upgrade, phased."
    echo "- scope_confirmed: confirmed"
    echo "- scope_confirmed_cite: ${3:-$SHA}"
    [ "$2" = "-" ] || printf -- '- scope_deferred_items: %s\n' "$2"
  } > "$f"
}
sd_snap none      "none"
sd_snap one       "[CO-S315-PHASE-2-BACKFILL]"
sd_snap spell2    "[CO-S315-PHASE-3-CUTOVER]"
sd_snap two       "[CO-S315-PHASE-2-BACKFILL, CO-S315-PHASE-3-CUTOVER]"
sd_snap second    "[CO-S315-PHASE-2-BACKFILL, CO-S315-NEVER-FILED]"
sd_snap malformed "[CO-S315-bad_id]"
sd_snap closed    "[CO-S309-CLOSED-ITEM]"
sd_snap live      "[CO-S312-IN-SPRINT-ITEM, CO-S310-DEFERRAL-ITEM]"
sd_snap reopened  "[CO-S308-REOPENED-ITEM]"
sd_snap archived  "[CO-S290-ARCHIVED-OPEN]"
sd_snap archclosed "[CO-S290-ARCHIVED-CLOSED]"
sd_snap prefix    "[CO-S315-PARTIAL]"
sd_snap nostatus  "[CO-S307-NO-STATUS-ITEM]"
sd_snap emptylist "[]"
sd_snap unclosed  "[CO-S315-PHASE-2-BACKFILL,"
sd_snap absent    "-"
sd_snap absentnone "-" none
# The producer's bold grammar, a backticked list, and a block list (refused, never empty).
{ echo "# Pipeline Snapshot"; echo "## Pipeline Position"
  echo "- **user_request_verbatim:** Sprint 315."
  echo "- **scope_confirmed:** confirmed — the operator took the phased split."
  echo "- **scope_confirmed_cite:** \`$SHA\`"
  echo "- **scope_deferred_items:** \`[CO-S315-PHASE-2-BACKFILL, CO-S315-PHASE-3-CUTOVER]\` — both filed at Step 6."
} > "$SD/snap-bold.md"
{ echo "# Pipeline Snapshot"; echo "## Pipeline Position"
  echo "- user_request_verbatim: Sprint 315."
  echo "- scope_confirmed: confirmed"
  echo "- scope_confirmed_cite: $SHA"
  echo "- scope_deferred_items:"
  echo "  - CO-S315-PHASE-2-BACKFILL"
} > "$SD/snap-block.md"

# --- the dated worlds: answers and repositories -------------------------------
# The answer heading is the hook's; only its timestamp is varied, and the entry the cite
# resolves to is otherwise the hook's own bytes.
sd_answers() {   # $1 name, $2 ISO-Z timestamp
  sed "s/^## [0-9][0-9T:Z-]* -- AskUserQuestion/## $2 -- AskUserQuestion/" "$ANSWERS" > "$SD/answers-$1.md"
}
sd_answers early   2026-09-26T07:29:05Z
sd_answers late    2026-09-29T00:00:00Z
sd_answers tzgap   2026-09-28T17:00:00Z
sd_answers between 2026-10-02T00:00:00Z
# The hash covers the answer body alone, so a short answer recurs. The reference consumer's
# live cite resolves to three entries whose body is `Confirmed`. Here the same entry appears
# twice: first before the release stamp, then after it. The NEWEST entry dates the answer.
{ cat "$SD/answers-early.md"; echo; sed -n '/^## /,$p' "$SD/answers-late.md"; } > "$SD/answers-dup.md"

# sd_repo <name> <version@committer-date> ... -- one commit per stamp, oldest first.
sd_repo() {
  local d="$SD/repo-$1" s v t; shift
  mkdir -p "$d/.claude"
  git -C "$d" init -q 2>/dev/null || return 1
  for s in "$@"; do
    v="${s%%@*}"; t="${s#*@}"
    printf 'version: %s\ncommit: 0000000\ninstalled_at: 2026-06-13T13:56:26Z\n' "$v" > "$d/.claude/.ai-dlc-version"
    git -C "$d" add .claude/.ai-dlc-version
    GIT_AUTHOR_DATE="$t" GIT_COMMITTER_DATE="$t" \
      git -C "$d" -c user.name=f -c user.email=f@f -c commit.gpgsign=false commit -q -m "stamp $v" || return 1
  done
}
# The release lands at 15:54:22-04:00 = 19:54:22Z, spelled with an explicit offset.
sd_repo std  "0.658.0@2026-09-20T10:00:00-04:00" "0.659.0@2026-09-28T15:54:22-04:00"
sd_repo old  "0.657.0@2026-09-10T10:00:00Z" "0.658.0@2026-09-20T10:00:00Z"
# 0.7.0 is OLDER than 0.659.0 and string-compares as NEWER.
sd_repo lex  "0.7.0@2026-01-05T10:00:00Z" "0.658.0@2026-09-20T10:00:00Z" "0.659.0@2026-09-28T19:54:22Z"
# Two qualifying stamps: the FIRST one decides.
sd_repo two  "0.659.0@2026-09-28T19:54:22Z" "0.660.0@2026-10-05T10:00:00Z"
mkdir -p "$SD/nogit"

SD_REPO_OK=1
for r in std old lex two; do
  n="$(git -C "$SD/repo-$r" rev-list --count HEAD 2>/dev/null)" || n=0
  [ "${n:-0}" -ge 2 ] || SD_REPO_OK=0
done
if [ "$SD_REPO_OK" = "1" ] && ! git -C "$SD/nogit" rev-parse --git-dir >/dev/null 2>&1; then
  ok "SEED: four dated repositories built with their commits, and the no-git directory is not inside one"
else
  bad "SEED BROKEN: a dated repository has fewer than two commits, or the no-git directory resolves to a repository — every legacy verdict below would be about the wrong history"
fi

SD_OUT=""; SD_RC=0
sd_run() {   # $1 validator, $2 snapshot name, $3 answers path, $4 repo path, [$5 TZ]
  SD_OUT="$(TZ="${5:-UTC}" bash "$1" --snapshot "$SD/snap-$2.md" --answers "$3" \
            --backlog "$SD_BL" --repo "$4" 2>&1)"; SD_RC=$?
}
sd_has() { grep -qF -- "$1" <<<"$SD_OUT"; }
REPO_STD="$SD/repo-std"

# sd_verdicts <validator> -> one token per arm, in a fixed order. Every arm below reads its
# own position, and every mutant is scored against the same vector, so a mutant that moves
# a cell it does not own is visible as entanglement rather than hidden as a kill.
SD_CELLS="none one spell2 two second malformed closed live reopened archived archclosed prefix nostatus emptylist unclosed bold block absent-early absent-late nogit nostamp tzgap lex first absentnone duphash"
sd_verdicts() {
  local v="$1" out=""
  sd_cell() { out="$out $1=$SD_RC"; }
  sd_run "$v" none "$ANSWERS" "$REPO_STD"
  sd_has "scope_deferred_items: none" || SD_RC="${SD_RC}x"; sd_cell none
  sd_run "$v" one "$ANSWERS" "$REPO_STD"
  sd_has "deferred_items_checked: 1" || SD_RC="${SD_RC}x"; sd_cell one
  sd_run "$v" spell2 "$ANSWERS" "$REPO_STD"; sd_cell spell2
  sd_run "$v" two "$ANSWERS" "$REPO_STD"
  sd_has "deferred_items_checked: 2" || SD_RC="${SD_RC}x"; sd_cell two
  sd_run "$v" second "$ANSWERS" "$REPO_STD"
  sd_has "CO-S315-NEVER-FILED" || SD_RC="${SD_RC}x"; sd_cell second
  sd_run "$v" malformed "$ANSWERS" "$REPO_STD"
  sd_has "malformed" || SD_RC="${SD_RC}x"; sd_cell malformed
  sd_run "$v" closed "$ANSWERS" "$REPO_STD"; sd_cell closed
  sd_run "$v" live "$ANSWERS" "$REPO_STD"; sd_cell live
  sd_run "$v" reopened "$ANSWERS" "$REPO_STD"; sd_cell reopened
  sd_run "$v" archived "$ANSWERS" "$REPO_STD"; sd_cell archived
  sd_run "$v" archclosed "$ANSWERS" "$REPO_STD"; sd_cell archclosed
  sd_run "$v" prefix "$ANSWERS" "$REPO_STD"; sd_cell prefix
  sd_run "$v" nostatus "$ANSWERS" "$REPO_STD"; sd_cell nostatus
  sd_run "$v" emptylist "$ANSWERS" "$REPO_STD"; sd_cell emptylist
  sd_run "$v" unclosed "$ANSWERS" "$REPO_STD"; sd_cell unclosed
  sd_run "$v" bold "$ANSWERS" "$REPO_STD"
  sd_has "deferred_items_checked: 2" || SD_RC="${SD_RC}x"; sd_cell bold
  sd_run "$v" block "$ANSWERS" "$REPO_STD"; sd_cell block
  sd_run "$v" absent "$SD/answers-early.md" "$REPO_STD"; sd_cell absent-early
  sd_run "$v" absent "$SD/answers-late.md" "$REPO_STD"
  sd_has "no 'scope_deferred_items' field" || SD_RC="${SD_RC}x"; sd_cell absent-late
  sd_run "$v" absent "$SD/answers-late.md" "$SD/nogit"; sd_cell nogit
  sd_run "$v" absent "$SD/answers-late.md" "$SD/repo-old"; sd_cell nostamp
  sd_run "$v" absent "$SD/answers-tzgap.md" "$REPO_STD" America/New_York; sd_cell tzgap
  sd_run "$v" absent "$SD/answers-early.md" "$SD/repo-lex"; sd_cell lex
  sd_run "$v" absent "$SD/answers-between.md" "$SD/repo-two"; sd_cell first
  sd_run "$v" absentnone "$ANSWERS_EMPTY" "$REPO_STD"; sd_cell absentnone
  sd_run "$v" absent "$SD/answers-dup.md" "$REPO_STD"; sd_cell duphash
  printf '%s\n' "${out# }"
}
# The expected vector. An `x` suffix means the rc was right but the owning message was not.
SD_EXPECT="none=0 one=0 spell2=0 two=0 second=1 malformed=1 closed=1 live=0 reopened=0 archived=0 archclosed=1 prefix=1 nostatus=1 emptylist=1 unclosed=1 bold=0 block=1 absent-early=3 absent-late=1 nogit=3 nostamp=3 tzgap=3 lex=3 first=1 absentnone=3 duphash=1"
sd_cell_of() { tr ' ' '\n' <<<"$1" | awk -F= -v k="$2" '$1==k{print $2}'; }

sd_why() {
  case "$1" in
    none)        echo "'none' is the honest empty value; refusing it wedges every sprint that deferred nothing" ;;
    one|spell2)  echo "a filed OPEN item must resolve in either status spelling the consumer writes" ;;
    two|bold)    echo "every id of a multi-id list must be read, in the plain and the producer's bold+backticked grammar" ;;
    second)      echo "a SECOND id that was never filed passed — the extractor reads only the first token" ;;
    malformed)   echo "a token outside CO-S<N>-<DESCRIPTOR> passed because a heading happened to carry it" ;;
    closed|archclosed) echo "a CLOSED item cannot be the part of the ask this sprint just deferred" ;;
    live)        echo "IN SPRINT and DEFERRAL_REQUESTED are live statuses and must resolve" ;;
    reopened)    echo "the CURRENT status is the first one in the item; a superseded line below it must not decide" ;;
    archived)    echo "retro moves items to carry-over-backlog-archive.md; an id resolvable only there must resolve" ;;
    prefix)      echo "an id that is only a string PREFIX of a filed heading resolved to it" ;;
    nostatus)    echo "an item with no status line is not a filed OPEN item" ;;
    emptylist|unclosed|block) echo "a list that reads as nothing must be refused, never read as empty" ;;
    absent-early) echo "an absent field on an answer that predates the release stamp must be PENDING, not FAIL" ;;
    absent-late) echo "an absent field on an answer given after the release stamp is the skipped write and must FAIL" ;;
    nogit|nostamp) echo "no git, or no commit stamping the release, leaves the date undecidable: PENDING" ;;
    tzgap)       echo "the hook timestamp is UTC; read in the caller's zone it lands after the stamp and FAILS a legacy record" ;;
    lex)         echo "0.7.0 is older than 0.659.0; a string compare dates the release to the wrong commit" ;;
    first)       echo "the FIRST commit stamping the release decides; a later one reads a post-release answer as legacy" ;;
    absentnone)  echo "a 'none' cite carries no answer timestamp, so an absent field beside it is PENDING" ;;
    duphash)     echo "a recurring answer hash was dated by its OLDEST entry, reading a post-release skipped write as legacy" ;;
  esac
}

# --- Assertions 38-62: every cell against the shipping validator ---------------
SD_GOT="$(sd_verdicts "$VALIDATOR")"
for c in $SD_CELLS; do
  want="$(sd_cell_of "$SD_EXPECT" "$c")"; got="$(sd_cell_of "$SD_GOT" "$c")"
  if [ "$want" = "$got" ]; then
    ok "deferred-items cell '$c': rc=$got as required"
  else
    bad "deferred-items cell '$c': got '$got', expected '$want' — $(sd_why "$c")"
  fi
done

# --- Assertion 63: the two consumer layouts do not change the answer ------------
# The arm reads `carry-over-backlog-archive.md` BESIDE the backlog it was given, never from
# the root, so a backlog passed by path finds its own archive from any working directory.
SD_CWD_OUT="$( cd / && bash "$VALIDATOR" --snapshot "$SD/snap-archived.md" --answers "$ANSWERS" \
                 --backlog "$SD_BL" --repo "$REPO_STD" 2>&1 )"; SD_CWD_RC=$?
if [ "$SD_CWD_RC" = "0" ] && grep -qF "deferred_items_checked: 1" <<<"$SD_CWD_OUT"; then
  ok "run from / the archive beside the given backlog still resolves — the arm is cwd-invariant"
else
  bad "run from / the archived id returned rc=$SD_CWD_RC — the archive is located relative to the working directory: $SD_CWD_OUT"
fi

# --- the deferred-items mutation battery ----------------------------------------
# Each mutant is a COPY with ONE anchored substitution. It must move the cells it OWNS and
# NO other cell, against a control copy that reproduces the whole expected vector. The
# anchors carry no backslash, because `awk -v` would eat one and the mutation would match
# nothing — `cmp -s` refuses that, and so does the anchor-count guard.
SD_MUT_KILLS=0; SD_MUT_BUILT=0
sd_mut() {   # $1 label, $2 anchor, $3 replacement, $4 expected anchor count, $5 owned cells
  local label="$1" anchor="$2" repl="$3" want_n="$4" owned="$5" out n got c w g moved stray
  out="$SD/mutant-$label.sh"
  n="$(grep -cF -- "$anchor" "$VALIDATOR")" || n=0
  if [ "$n" != "$want_n" ]; then
    bad "FIXTURE STALE: mutant $label's anchor occurs $n times, not $want_n — the mutation could land on the wrong line"
    return
  fi
  awk -v a="$anchor" -v r="$repl" '{
      i = index($0, a)
      if (i) { $0 = substr($0, 1, i - 1) r substr($0, i + length(a)) }
      print
    }' "$VALIDATOR" > "$out"
  if cmp -s "$VALIDATOR" "$out"; then
    bad "FIXTURE STALE: mutant $label is byte-identical to the validator — the substitution matched nothing"; return
  fi
  if ! bash -n "$out" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant $label is not a valid shell script, so a kill would only mean the copy could not run"; return
  fi
  SD_MUT_BUILT=$((SD_MUT_BUILT + 1))
  got="$(sd_verdicts "$out")"
  moved=""; stray=""
  for c in $SD_CELLS; do
    w="$(sd_cell_of "$SD_EXPECT" "$c")"; g="$(sd_cell_of "$got" "$c")"
    case " $owned " in
      *" $c "*) [ "$w" != "$g" ] && moved="$moved $c" ;;
      *)        [ "$w" != "$g" ] && stray="$stray $c=$g" ;;
    esac
  done
  if [ -n "$stray" ]; then
    bad "mutant $label moved cells it does not own:$stray — the arms are entangled and one of them is vacuous"
  elif [ "$(echo $moved | wc -w)" -ne "$(echo $owned | wc -w)" ]; then
    bad "MUTANT $label SURVIVED on some of its own cells (moved:${moved:- none}; owned: $owned) — those cells are not testing what this mutant removes"
  else
    SD_MUT_KILLS=$((SD_MUT_KILLS + 1))
    ok "mutant $label killed on exactly its own cells:$moved"
  fi
}

# Control: an unmutated copy reproduces the whole vector, so a mutant verdict means mutation.
SD_CTL="$SD/control.sh"; cp "$VALIDATOR" "$SD_CTL"
SD_CTL_GOT="$(sd_verdicts "$SD_CTL")"
if [ "$SD_CTL_GOT" = "$SD_EXPECT" ]; then
  ok "control: an unmutated copy reproduces all $(echo $SD_CELLS | wc -w) deferred-items cells, PASS, FAIL and PENDING alike"

  # REGRESSION 1 — field_of reused: it stops at the first space, so a list collapses to its
  # FIRST id once the brackets and comma are stripped, and a second unfiled id rides along.
  sd_mut fieldof 'SDI_RAW="$(deferred_items_of "$SNAPSHOT")"' \
    'SDI_RAW="$(v="$(field_of scope_deferred_items "$SNAPSHOT" | tr -d "[],")"; if [ "$v" = none ]; then echo "@none"; elif [ -n "$v" ]; then echo "@[$v]"; fi)"' \
    1 "two second unclosed bold"
  # REGRESSION 2 — the absent field read as PENDING unconditionally: the FAIL branch
  # reports PENDING instead, so every post-release cell sees it. `duphash` is one of them
  # by construction; `oldestanswer` below is what isolates it.
  sd_mut absentpending 'which owes it." >&2' 'which owes it." >&2; exit 3' 1 "absent-late first duphash"
  # `two` and `bold` each carry a second-spelling id, so they are owned here too — the
  # corpus being faithful, not the arms being entangled: `spell2` isolates the spelling.
  sd_mut spelling 'found && index($0, "**Status: ")' 'found && 0 && index($0, "**Status: ")' 1 "spell2 two bold"
  sd_mut noarchive '[ "$st" = "NOHEAD" ] && [ -f "$ARCHIVE" ]' 'false' 1 "archived"
  sd_mut noclosed '            CLOSED*)' '            CLOSED-NEVER-A-STATUS*)' 1 "closed archclosed"
  sd_mut nogrammar "if ! grep -Eq '^CO-S[0-9]+-[A-Z0-9-]+\$' <<<\"\$tok\"; then" 'if false; then' 1 "malformed"
  sd_mut prefixmatch '!found && $1 == "###" && $2 == id' '!found && $1 == "###" && index($2, id) == 1' 1 "prefix"
  sd_mut emptyok '    if [ "$SDI_N" -eq 0 ]; then' '    if false; then' 1 "emptylist"
  sd_mut strversion 'ge(v, rel) && (best' '(v >= rel) && (best' 1 "lex"
  sd_mut laststamp '(best == "" || t < best)' '(best == "" || t > best)' 1 "first"
  sd_mut oldestanswer '$0 == c { t = h } END { print t }' '$0 == c { print h; exit }' 1 "duphash"
  if TZ=UTC date -j -u -f '%Y-%m-%dT%H:%M:%SZ' 2026-01-01T00:00:00Z +%s >/dev/null 2>&1; then
    # BSD date only: GNU `date -d` honours the trailing Z whatever TZ says, so this mutant
    # cannot express the defect there and is not built.
    sd_mut localzone "TZ=UTC date -j -u -f" "date -j -f" 1 "tzgap"
    SD_MUT_WANT=12
  else
    ok "GNU date: the zone mutant is not built here — GNU parses the trailing Z itself, so the defect it seeds is unconstructible on this platform"
    SD_MUT_WANT=11
  fi
  if [ "$SD_MUT_KILLS" -eq "$SD_MUT_WANT" ]; then
    ok "all $SD_MUT_WANT deferred-items mutants killed against the resolved validator $VALIDATOR"
  else
    bad "only $SD_MUT_KILLS of $SD_MUT_WANT deferred-items mutants were killed ($SD_MUT_BUILT built) — an unkilled mutant is an arm that cannot fire"
  fi
else
  bad "CONTROL FAILED: an unmutated copy returned [$SD_CTL_GOT], expected [$SD_EXPECT] — every mutant verdict below would be uninterpretable"
fi

echo
if [ "$fails" -eq 0 ]; then echo "scope-confirmation: PASS"; exit 0; fi
echo "scope-confirmation: $fails assertion(s) FAILED" >&2
exit 1
