#!/usr/bin/env bash
# Prove I36/I37/I38/I41/I42 can FAIL.
#
# WHY THIS FIXTURE EXISTS. The invariants pass on this repo, and they will pass on every
# well-formed tree — which is exactly the state this repo names as its recurring defect: a check
# that cannot fire reads exactly like one that passed. I38 was observed firing 22 times while the
# contract was being landed (the clause ids did not yet exist in the READMEs). I36 and I37 have
# NEVER fired against real input, so without the mutants below their green is worth nothing.
#
# I41 AND I42 ARE THE COUNTEREXAMPLE TO THAT LAST SENTENCE, AND THEY ARRIVED LATE. Both fired on
# the contract as it actually shipped: two clauses were declared `LC-O12` (v0.187.0, then again
# v0.192.0) and three declared `since: 3` against `contract_version: 2`. The build was green
# through all of it, because every invariant already here keys on something else — I36 on `code:`,
# I37 on field presence, I38 on a SUBSTRING grep of the prose home that two clauses sharing an id
# both satisfy. The mutants below re-create each defect one at a time.
#
# THE MUTANT IS THE CONTRACT, NOT THE VALIDATOR. Every other option was worse. Mutating
# `validate-enforcement-map.sh` would test the assertion's wording rather than the join, and
# mutating the contract in place would leave the repo dirty if an assertion aborted. So the
# contract is COPIED to a temp file, edited there, and the validator is pointed at it with
# AI_DLC_LAYER_CONTRACT. Enforcers and prose homes still resolve against the real repo, so each
# mutant isolates one side of one join.
#
# Each mutant is a COPY guarded by `cmp -s`, asserts a POSITIVE outcome (the specific invariant
# id appears in the output), and must fail ONLY its own assertion.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# I10 — a fixture must not inherit an ambient tunable that changes what it measures.
unset AI_DLC_LAYER_CONTRACT

# Locate the validator and the contract in BOTH layouts. This validator is
# distribution-only (scripts/, not core/scripts/), so a consumer tree has neither and the
# fixture declares itself inapplicable rather than failing — the same posture the
# distribution-only fixtures take.
VAL=""; CONTRACT=""
for cand in "$DIR/../../../scripts/validate-enforcement-map.sh"; do
  [ -f "$cand" ] && VAL="$cand"
done
for cand in "$DIR/../../skills/ai-dlc/layer-contract.yaml" \
            "$DIR/../../../core/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$cand" ] && CONTRACT="$cand" && break
done
if [ -z "$VAL" ] || [ -z "$CONTRACT" ]; then
  echo "layer-contract-conformance: SKIP — validate-enforcement-map.sh is distribution-only and is not installed in a consumer tree."
  exit 0
fi
REPO="$(cd "$(dirname "$VAL")/.." && pwd)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/layer-contract-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FAILURES=0
ASSERTIONS=0

# Run the validator against a given contract file; print only its FAIL lines.
run_with() { AI_DLC_LAYER_CONTRACT="$1" bash "$VAL" 2>&1 | grep '^FAIL' || true; }

# $1 mutant-file  $2 invariant id that MUST appear  $3 label  $4 why
mutant_fires() {
  local file="$1" want="$2" label="$3" why="$4" out
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$CONTRACT" "$file"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-18s the mutation matched nothing, so this assertion is unproven\n' "$label"
    return
  fi
  out="$(run_with "$file")"
  if grep -q "$want" <<<"$out"; then
    printf '  ok    %-18s %s fires  (%s)\n' "$label" "$want" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-18s %s did NOT fire  (%s)\n' "$label" "$want" "$why"
    printf '%s\n' "$out" | sed 's/^/          | /' | head -5
  fi
}

echo "layer-contract-conformance fixture"
echo

# THE UNMUTATED CONTROL, FIRST. If the real contract does not come out clean, every "the mutant
# fired" result below is meaningless — the validator would be failing for an unrelated reason and
# each mutant would score a kill it did not earn.
ASSERTIONS=$((ASSERTIONS + 1))
cp "$CONTRACT" "$TMP/control.yaml"
ctl="$(run_with "$TMP/control.yaml")"
if [ -z "$ctl" ]; then
  printf '  ok    %-18s clean  (the real contract passes, so a mutant fire is attributable)\n' "control"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-18s the UNMUTATED contract already fails — every mutant below is unattributable\n' "control"
  printf '%s\n' "$ctl" | sed 's/^/          | /' | head -5
fi

# --- I36 forward: a clause naming a code its enforcer does not emit -------------------
# The clause becomes unfireable while still reading like a rule with teeth. `E99` is chosen
# because it is shaped exactly like a real code, so nothing but the join can reject it.
sed 's/^    code: E1$/    code: E99/' "$CONTRACT" > "$TMP/i36-forward.yaml"
mutant_fires "$TMP/i36-forward.yaml" "I36 LC-O1" "i36-forward" \
  "a clause pointing at a code no enforcer emits cannot fire, and reads exactly like one that passed"

# --- I36 reverse: an emitted code no clause claims ------------------------------------
# THE DIRECTION THAT CATCHES DRIFT. Delete the clause that claims OVERRIDE-DELEGATES-INTO-SHADOW
# and the status still ships — an operator receives that verdict with no stated rule behind it.
# This is the half a forward-only join cannot see, and the half the 17-clause gap grew through.
awk '
  /^  - id: LC-O9$/ { skip=1; next }
  skip && /^  - id: /   { skip=0 }
  skip && /^clauses:/   { skip=0 }
  !skip
' "$CONTRACT" > "$TMP/i36-reverse.yaml"
mutant_fires "$TMP/i36-reverse.yaml" "I36 reverse" "i36-reverse" \
  "layer-drift.sh still emits the status, so dropping its clause must fail the build"

# --- I36 reverse, SECOND enforcer: the extraction arm for a new vocabulary -------------
# A code vocabulary reaches the reverse join only through a `case` arm naming its script.
# Without one the arm falls to `*) emitted=""`, and the zero guard reports "found NO codes"
# — a DIFFERENT sentence. So this asserts on the emitted-code wording, not on "I36 reverse":
# an assertion on the shared prefix would pass against a build where the arm was never added
# and GM1/GM2 were simply invisible to this direction, which is the state it exists to catch.
awk '
  /^  - id: LC-E17$/ { skip=1; next }
  skip && /^  - id: /   { skip=0 }
  skip && /^clauses:/   { skip=0 }
  !skip
' "$CONTRACT" > "$TMP/i36-reverse-gm.yaml"
mutant_fires "$TMP/i36-reverse-gm.yaml" "emits 'GM1'" "i36-reverse-gm" \
  "validate-gate-manifest.sh still emits GM1, so dropping its clause must fail the build rather than reporting an unreadable vocabulary"

# --- I37: a clause with no mechanism --------------------------------------------------
# The exact state the contract was created to end: 17 clauses that read as rules and could not
# fail anything. Removing one clause's enforcer must be rejected, not tolerated as incomplete.
sed '/^    enforcer: core\/scripts\/validate-layer-entries.sh$/{x;/./d;x;h;s/.*/    reason: pending/;}' \
  "$CONTRACT" > "$TMP/i37.yaml"
if cmp -s "$CONTRACT" "$TMP/i37.yaml"; then
  # The sed above is deliberately fragile across awks/seds; fall back to a plain deletion of
  # the FIRST enforcer line, which is the property under test either way.
  awk 'BEGIN{done=0} /^    enforcer: /{ if(!done){done=1; next} } {print}' "$CONTRACT" > "$TMP/i37.yaml"
fi
mutant_fires "$TMP/i37.yaml" "I37" "i37-no-mechanism" \
  "a clause with no enforcer is prose pretending to be a rule"

# --- I38 forward: a clause id absent from its declared prose home ---------------------
# Renaming an id in the contract alone splits the enforced side from the side a human reads.
sed 's/^  - id: LC-R1$/  - id: LC-R9/' "$CONTRACT" > "$TMP/i38.yaml"
mutant_fires "$TMP/i38.yaml" "I38 LC-R9" "i38-prose-home" \
  "the contract and the README have diverged, so the reader is pointed at a clause that is not there"

# --- I41: two clauses under one id ----------------------------------------------------
# THE DEFECT AS IT SHIPPED, re-created exactly: fold LC-O14 back onto LC-O12, which is what
# v0.192.0 did by counting forward from LC-O11 in a file that is not in numeric order.
#
# This must fail I41 and NOTHING ELSE, which is why the fold is onto an id the prose home
# already carries: I38 greps `overrides/README.md` for each id as a substring, so a collision
# satisfies it on the surviving clause's line. That is the entanglement to avoid AND the reason
# I38 could never have caught this.
sed 's/^  - id: LC-O14$/  - id: LC-O12/' "$CONTRACT" > "$TMP/i41.yaml"
mutant_fires "$TMP/i41.yaml" "I41" "i41-duplicate-id" \
  "two clauses under one id make every citation of it ambiguous, and I38 passes on the other's prose"

# --- I42 arm 1: a clause introduced above the contract's own version ------------------
# Raise the FIRST clause's since to contract_version + 1 rather than lowering contract_version.
# Lowering it would only fire if some clause happened to sit exactly at the current version, so a
# later release that bumps the version without adding a clause at it would turn this mutant into
# a byte-different no-op — the kind `cmp -s` passes because bytes DID change.
awk '
  /^contract_version:/ { cv = $2 + 1; print; next }
  /^    since:/        { if (!done) { done = 1; printf "    since: %d\n", cv; next } }
  { print }
' "$CONTRACT" > "$TMP/i42-above.yaml"
mutant_fires "$TMP/i42-above.yaml" "> contract_version" "i42-above-version" \
  "a clause above contract_version binds no conforming entry — it cannot fire, wearing a version number"

# --- I42 arm 2: a clause with no since: at all ----------------------------------------
# The vacuity guard. Without it, dropping the field is how a clause exits I42's subject set
# while still reading like a versioned rule. Asserted on THIS arm's wording, not on "I42" —
# three arms can emit that string and an assertion on the shared token would pass against a
# reverted fix.
awk 'BEGIN{done=0} /^    since:/{ if(!done){done=1; next} } {print}' "$CONTRACT" > "$TMP/i42-missing.yaml"
mutant_fires "$TMP/i42-missing.yaml" "has no since:" "i42-missing-since" \
  "a clause with no since: silently leaves the comparison's subject set"

# --- I42 arm 3: an unreadable contract_version ----------------------------------------
# The other vacuity guard: every since: is compared against this one value, so an unparseable
# one would retire the whole check while the build stayed green.
sed 's/^contract_version: .*$/contract_version: three/' "$CONTRACT" > "$TMP/i42-unparseable.yaml"
mutant_fires "$TMP/i42-unparseable.yaml" "cannot read a numeric contract_version" "i42-unparseable" \
  "an unreadable version would make every since: comparison pass by finding nothing"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
