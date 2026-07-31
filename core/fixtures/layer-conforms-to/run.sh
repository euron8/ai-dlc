#!/usr/bin/env bash
# layer-conforms-to — prove the per-entry contract receipt (E17 / W6) and the
# LAYER_CONFORMANCE machine footer can FAIL, and prove the one property that is an
# ABSENCE: the receipt never silences a clause.
#
# Usage: run.sh [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed.
#
# THE LOAD-BEARING ASSERTION IS PART 3. `conforms_to` was specified — in the contract's own
# header for eight versions, and in the plan that scheduled this work — as a SKIP: "an entry
# declaring conforms_to: N is held only to clauses with since <= N". Built that way it is a
# one-line-per-file escape hatch from every clause core has allocated since, and the reference
# consumer's 49 band ERRORs sit at since 4 and since 8. So the shipped reader reports scope and
# subtracts nothing, and that is a property no ordinary assertion can see: the code for it is
# absent. MUTANT m2 supplies the missing skip and the assertion catches the entry going quiet.
#
# Every mutant is a COPY guarded by `cmp -s`, is accompanied by an UNMUTATED control copy from
# the same directory, asserts a POSITIVE measured outcome rather than the absence of a message,
# and is scored so that it fails only its own assertion.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "${1:-}" "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/layer-conforms-to-m.XXXXXX")"
trap 'rm -rf "$ROOT" "$TMP"' EXIT
CONS="$ROOT/consumer"; BAD="$ROOT/bad-consumer"; NOLC="$ROOT/no-contract"

fails=0
ASSERTIONS=0
ok()  { ASSERTIONS=$((ASSERTIONS+1)); printf '  ok    %s\n' "$1"; }
bad() { ASSERTIONS=$((ASSERTIONS+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }
say() { if [ "$1" = 1 ]; then ok "$2"; else bad "$2"; fi; }

# NO run() HELPER, deliberately. `OUT="$(run ...)"` evaluates the helper in a SUBSHELL, so an
# rc it assigns to a global is discarded and every exit-code assertion below would read a stale
# 0 — the `$( )` swallowing state that cost v0.217.0 a whole silent mutant. Each call site
# captures `$?` on the same line as its own command substitution.

# footer_field <output> <name> -> the value of name= on the LAYER_CONFORMANCE line
# A HERE-STRING, not a pipe, and for I54's reason one reader over: this awk program `exit`s at
# the first match, so under pipefail a large enough value would make the writer die on EPIPE and
# the field read as absent. The redirect goes at the end of the awk command and the pipe is gone.
footer_field() {
  awk -v k="$2" '
    /^LAYER_CONFORMANCE / { for (i=2; i<=NF; i++) { split($i, p, "="); if (p[1] == k) { print p[2]; exit } } }' <<<"$1"
}

echo "layer-conforms-to:"

# ---------------------------------------------------------------------------
# Part 1 — the conforming consumer, and the footer's counts
# ---------------------------------------------------------------------------
CLEAN_OUT="$(bash "$LINTER" "$CONS" 2>&1)"; CLEAN_RC=$?
say "$([ "$CLEAN_RC" -eq 0 ] && echo 1 || echo 0)" \
  "a consumer whose every entry carries a current receipt exits 0"
say "$([ "$(footer_field "$CLEAN_OUT" entries)" = 3 ] && echo 1 || echo 0)" \
  "the footer counts 3 entries — 2 extensions AND the override, so the pass walks both layers"
say "$([ "$(footer_field "$CLEAN_OUT" at_current)" = 3 ] && echo 1 || echo 0)" \
  "the footer counts 3 at_current"
say "$([ "$(footer_field "$CLEAN_OUT" contract_version)" = "$(awk '/^contract_version:/{print $2; exit}' "$CONS/.claude/skills/ai-dlc/layer-contract.yaml")" ] && echo 1 || echo 0)" \
  "the footer's contract_version is READ from the consumer's own installed contract"

# ---------------------------------------------------------------------------
# Part 2 — one arm per malformed receipt
# ---------------------------------------------------------------------------
BAD_OUT="$(bash "$LINTER" "$BAD" 2>&1)"; BAD_RC=$?
has() { grep -Fq "$1" <<<\"$BAD_OUT\"; }

say "$([ "$BAD_RC" -eq 1 ] && echo 1 || echo 0)"  "a malformed receipt exits 1 — the consumer's pre-push refuses"
say "$(has "no-receipt.md: missing 'conforms_to:'" && echo 1 || echo 0)"      "E17 reports a MISSING receipt"
say "$(has "not-a-number.md: conforms_to 'eight' is not" && echo 1 || echo 0)" "E17 reports a NON-NUMERIC receipt"
# DERIVED, not written down. This read `conforms_to 10`, which was one above the contract at
# the release that shipped it and became the contract's OWN version at the next bump — the
# assertion then asked E17 to reject a receipt that had become legal, and went red for a
# reason that had nothing to do with E17. The seed already derives the value as CV+1; this
# side has to derive it from the same place or the pair drifts on every bump.
CV_NOW="$(awk '/^contract_version:/{print $2; exit}' "$CONS/.claude/skills/ai-dlc/layer-contract.yaml")"
[ -n "$CV_NOW" ] || { echo "FIXTURE ERROR: no contract_version in the seeded contract" >&2; exit 2; }
say "$(has "above-cv.md: conforms_to $((CV_NOW + 1)) claims a contract version" && echo 1 || echo 0)" \
  "E17 reports a receipt ABOVE contract_version — a version no distribution has reached"
say "$([ "$(footer_field "$BAD_OUT" undeclared)" = 1 ] && echo 1 || echo 0)" \
  "the footer's undeclared count is the measured 1, not a restatement of the error count"

# W6 — one line per run, and it must name the entry AND the clauses that postdate it.
say "$(has 'W6 1 of 4 layer entr' && echo 1 || echo 0)" \
  "W6 reports the behind entry once per run, against a measured total"
say "$(grep -Fq 'LC-N5' <<<\"$BAD_OUT\" && echo 1 || echo 0)" \
  "W6's worklist names LC-N5 — a clause introduced after the entry's declared version"
say "$([ "$(footer_field "$BAD_OUT" behind)" = 1 ] && echo 1 || echo 0)" "the footer counts 1 behind"

# ---------------------------------------------------------------------------
# Part 3 — THE NON-SILENCING PROPERTY
# ---------------------------------------------------------------------------
# behind-and-in-core-range.md declares conforms_to: 1 and allocates a heading number core
# already defines. LC-N5 was introduced at since 4. Under the skip semantics the contract
# specified for eight versions this entry escapes the band ERROR outright.
say "$(has 'behind-and-in-core-range.md: SECTION ID OUT OF BAND' && echo 1 || echo 0)" \
  "an entry at conforms_to 1 STILL takes the band ERROR from a clause introduced at since 4"

# ---------------------------------------------------------------------------
# Part 4 — the refusal arm: an absent contract is not a clean one
# ---------------------------------------------------------------------------
NOLC_OUT="$(bash "$LINTER" "$NOLC" 2>&1)"; NOLC_RC=$?
say "$([ "$NOLC_RC" -eq 1 ] && echo 1 || echo 0)" \
  "a consumer with no installed layer-contract.yaml exits 1 rather than reporting clean"
say "$(grep -Fq 'went UNCHECKED in this run' <<<\"$NOLC_OUT\" && echo 1 || echo 0)" \
  "the refusal says the receipts were not judged, rather than judging them clean"
say "$([ "$(footer_field "$NOLC_OUT" contract_version)" = '-' ] && echo 1 || echo 0)" \
  "the footer reads contract_version=- when the contract could not be read, never a plausible number"

# ---------------------------------------------------------------------------
# Part 5 — mutants
# ---------------------------------------------------------------------------
mk() { # mk <name> <sed-or-awk-command...>  -- build a mutant copy, guarded by cmp -s
  local name="$1"; shift
  if ! "$@" < "$LINTER" > "$TMP/$name.sh"; then
    bad "MUTANT $name: the mutating command itself failed, so nothing below is a kill"
    return 1
  fi
  if cmp -s "$LINTER" "$TMP/$name.sh"; then
    bad "MUTANT $name: the mutation matched NOTHING, so its kill below would prove nothing"
    return 1
  fi
  # A truncated or unparseable copy dies before it lints anything, and a run that emits no
  # findings is indistinguishable from one the mutation silenced.
  if ! bash -n "$TMP/$name.sh" 2>/dev/null; then
    bad "MUTANT $name: the mutated copy does not parse, so its silence is a syntax error and not a kill"
    return 1
  fi
  return 0
}

# THE UNMUTATED CONTROL, from the same directory as every mutant. A copy that dies for an
# unrelated reason emits nothing, and "no output" otherwise scores as a kill.
cp "$LINTER" "$TMP/control.sh"
CTL_OUT="$(bash "$TMP/control.sh" "$BAD" 2>&1)"; CTL_RC=$?
say "$([ "$CTL_RC" -eq 1 ] && [ "$(footer_field "$CTL_OUT" errors)" = "$(footer_field "$BAD_OUT" errors)" ] && echo 1 || echo 0)" \
  "CONTROL: an unmutated copy reproduces the shipped error count, so a mutant's change is attributable"

# --- m1: the receipt made OPTIONAL ------------------------------------------------------
if mk m1 sed 's@^    ct="$(fm "$f" conforms_to)"$@    ct="$(fm "$f" conforms_to)"; [ -n "$ct" ] || continue@'; then
  M1_OUT="$(bash "$TMP/m1.sh" "$BAD" 2>&1)"
  say "$([ "$(footer_field "$M1_OUT" errors)" = 3 ] && [ "$(footer_field "$M1_OUT" undeclared)" = 0 ] && echo 1 || echo 0)" \
    "MUTANT m1 killed: with the missing-key arm skipped the error count drops 4 -> 3 and undeclared reads 0 on a tree that has one"
fi

# --- m2: THE SKIP. The semantics this release did NOT build. -----------------------------
# `layer_files()` stops yielding an entry whose receipt is below the `since` of the band
# clause — the practical shape of "held only to clauses with since <= N" for that clause. If
# the fixture cannot see the difference, the non-silencing property in Part 3 is decorative.
if mk m2 sed 's|^layer_files() { \[ -d "$1" \] .*$|layer_files() { [ -d "$1" ] \|\| return 0; find "$1" -type f -name "*.md" ! -name "README.md" 2>/dev/null \| sort \| while IFS= read -r _lf; do _lc="$(fm "$_lf" conforms_to)"; case "$_lc" in ""\|*[!0-9]*) printf "%s\\n" "$_lf" ;; *) [ "$_lc" -ge 4 ] \&\& printf "%s\\n" "$_lf" ;; esac; done; }|'; then
  M2_OUT="$(bash "$TMP/m2.sh" "$BAD" 2>&1)"
  say "$(grep -Fq 'behind-and-in-core-range.md: SECTION ID OUT OF BAND' <<<\"$M2_OUT\" && echo 0 || echo 1)" \
    "MUTANT m2 killed: made subtractive, the receipt at version 1 silences the band ERROR that Part 3 asserts still fires"
  say "$(grep -Fq "no-receipt.md: missing 'conforms_to:'" <<<\"$M2_OUT\" && echo 1 || echo 0)" \
    "MUTANT m2 leaves the malformed-receipt arms alive (Part 2 and Part 3 are not entangled)"
fi

# --- m3: the missing-contract refusal removed -------------------------------------------
if mk m3 sed 's|^  err E17 "cannot read the layer contract|  : "cannot read the layer contract|'; then
  M3_OUT="$(bash "$TMP/m3.sh" "$NOLC" 2>&1)"; M3_RC=$?
  say "$([ "$M3_RC" -eq 0 ] && [ "$(footer_field "$M3_OUT" contract_version)" = '-' ] && echo 1 || echo 0)" \
    "MUTANT m3 killed: without the refusal an uninstalled contract exits 0 while the footer still admits it read no version"
fi

# --- m4: the footer's counts detached from the run --------------------------------------
if mk m4 sed 's|^    LC_ENTRIES=$((LC_ENTRIES+1))$|    LC_ENTRIES=$((LC_ENTRIES+0))|'; then
  M4_OUT="$(bash "$TMP/m4.sh" "$CONS" 2>&1)"
  say "$([ "$(footer_field "$M4_OUT" entries)" = 0 ] && echo 1 || echo 0)" \
    "MUTANT m4 killed: the footer reports entries=0 on a tree with three, so its counts are produced by the walk and not by the printf"
fi

# --- m5: the above-version arm removed --------------------------------------------------
if mk m5 sed 's|^    elif \[ "$ct" -gt "$LC_CV" \]; then$|    elif false; then|'; then
  M5_OUT="$(bash "$TMP/m5.sh" "$BAD" 2>&1)"
  # With the arm off, an above-version receipt falls through to the else branch and is COUNTED
  # AS CURRENT — strictly worse than merely unreported, and the footer is what says so.
  say "$([ "$(footer_field "$M5_OUT" errors)" = 3 ] && [ "$(footer_field "$M5_OUT" at_current)" = 1 ] && echo 1 || echo 0)" \
    "MUTANT m5 killed: a receipt above contract_version stops being reported, drops the count 4 -> 3, and is tallied at_current=1"
fi

# THE ASSERTION-COUNT FLOOR. Several arms above run inside `if mk ...; then` blocks, and a
# mutation that silently matched nothing skips its assertion entirely — a shorter green report,
# which reads exactly like a passing one. v0.217.0 shipped that exact shape once already.
EXPECTED_ASSERTIONS=23
echo
if [ "$ASSERTIONS" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf 'layer-conforms-to: FAIL — %d assertions ran, %d expected. An arm did not execute.\n' \
    "$ASSERTIONS" "$EXPECTED_ASSERTIONS"
  exit 1
fi
if [ "$fails" -gt 0 ]; then
  printf 'layer-conforms-to: FAIL (%d of %d assertions)\n' "$fails" "$ASSERTIONS"
  exit 1
fi
printf 'layer-conforms-to: PASS (%d assertions)\n' "$ASSERTIONS"
