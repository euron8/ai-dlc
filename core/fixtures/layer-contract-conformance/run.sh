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
#
# TWO PHASES, AND THE REASON IS MEASURED. Every arm here WAS one full run of
# validate-enforcement-map.sh — 6.45s on the reference box, 62% of it SYSTEM time, which is the
# fork signature rather than work. Thirty of them in a row made this fixture 270.7s of a 276.5s
# suite with ZERO slack: it WAS the suite, and every other unit finished 137s before it. The runs
# are independent by construction — each builds its own contract copy in its own $TMP and points
# the validator at it with AI_DLC_LAYER_CONTRACT — so they were serial only because they were
# written in a row.
#
# EACH RUN NOW EXECUTES ONLY THE ARMS IT IS READ FOR. The validator takes `--arms I<n>,...` and
# every assertion here tests exactly one invariant, so a mutant run that used to execute all
# eighty-one units executes the one its arm reads. The selector is DERIVED from the registries
# below rather than listed; which runs stay on the full validator is derived from arm SHAPE; and
# the fact that selection happened at all is asserted against what the runner recorded. All three
# are stated where they are built, further down.
#
# So: build every mutant serially (cheap), run the validator for each through a pool, then
# evaluate serially IN DECLARATION ORDER. The evaluation order is what keeps stdout deterministic
# and diffable against the serial version; the arms and their comments below are untouched.
#
# A MISSING VERDICT IS A FAILURE, NOT A GAP. Serially, an arm that never ran could not print an
# `ok` — the run and the report were the same statement. With a pool they are two, and an arm
# whose job was dropped produces no output file, which adds nothing to the count. That is exactly
# what a passing arm adds. So the absence is asserted, not assumed — this fixture's own
# EXPECTED_ASSERTIONS floor, one layer out.
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

# ---------------------------------------------------------------------------
# THE SHARD SPLIT, AND IT IS A MEASUREMENT RATHER THAN A PREFERENCE
# ---------------------------------------------------------------------------
# The pre-push suite is POLE-BOUND: its makespan tracks its single longest DIRECTORY,
# because `core/fixtures/*/run.sh` is what the outer pool globs. This directory sat in that
# pole set at 434 recorded pool-seconds, behind only self-update-join-gate and the three
# enforcement-map-sites shards, and an inner pool did not fix it — the inner pool is already
# there and the unit still costs ~100s with the machine entirely to itself. So the fixture is
# SHARDED ACROSS DIRECTORIES, the same move and the same reason as enforcement-map-sites,
# which states the measurement in place.
#
# IT IS PLACED AFTER THE SKIP ABOVE, DELIBERATELY. On a consumer neither directory resolves
# $VAL, so both take that SKIP and exit 0 before any of this runs. Hoisting the shard protocol
# above the SKIP would make a consumer's exit depend on the coverage join below, and therefore
# on whether a sibling directory was installed — a packaging decision decided by statement
# order in a file nobody reading install.sh would think to open.
#
# WHAT IS PARTITIONED IS $RUNS, NOT $ARMS, and that is the whole difference from the sites
# fixture. The registries below are MANY-TO-ONE: three arms read the `control` run and
# i64-vs-i36 reads i64-unemitted's run, so dealing ARMS out would separate an arm from the
# run whose output it reads. Dealing RUNS out keeps every reader with its subject.
SHARDS="a b"

# THE SHARD ARRIVES AS AN ARGUMENT, NOT AS AN ENVIRONMENT VARIABLE. This file unsets
# AI_DLC_LAYER_CONTRACT near the top for I10 — a fixture must not inherit a tunable that
# changes what it measures — and an `AI_DLC_LCC_GROUP` would be the same shape of thing to
# scrub next. An argument cannot be scrubbed: it is not ambient. A fallback-to-'a' design
# would run shard 'a' twice and report two green fixtures.
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac

# THE COVERAGE JOIN. Sharding moves assertions out of this directory, so the failure it
# introduces is a shard whose directory is deleted, renamed, or never installed: the suite
# then runs fewer assertions and reports a shorter green run, which is this repository's
# named recurring defect wearing a new hat. Shard `a` therefore DERIVES the set of shards
# that exist beside it and refuses to pass if any declared shard has no driver.
if [ "$GROUP" = a ]; then
  missing=""
  for _s in $SHARDS; do
    [ "$_s" = a ] && continue
    [ -f "$DIR/../layer-contract-conformance-$_s/run.sh" ] || missing="$missing $_s"
  done
  if [ -n "$missing" ]; then
    echo "FIXTURE ERROR: shard(s)$missing declared in SHARDS have no driver directory beside this one." >&2
    echo "  Their assertions would run NOWHERE, and this suite would report a shorter green run." >&2
    exit 2
  fi
fi

NAME="layer-contract-conformance"
[ "$GROUP" = a ] || NAME="layer-contract-conformance-$GROUP"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/layer-contract-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FAILURES=0
ASSERTIONS=0

OUTD="$TMP/out"; mkdir -p "$OUTD"

# THE TWO REGISTRIES, AND THEY ARE WHAT THE POOL IS DERIVED FROM. A hand-written job list would
# be the check-that-cannot-fire class one level out: an arm dropped from it runs nothing, prints
# nothing, and 32 greens read exactly like 33.
#
#   RUNS  one line per DISTINCT validator run — `label<TAB>contract-file`
#   ARMS  one line per assertion, in DECLARATION order — `kind<TAB>label<TAB>run<TAB>want<TAB>a<TAB>b`
#
# Fields are TAB-separated and every one is written non-empty (`-` where unused) DELIBERATELY:
# TAB is IFS whitespace, so `read` collapses a run of them and an empty field would silently
# shift every field after it.
RUNS="$TMP/runs"; : > "$RUNS"
ARMS="$TMP/arms"; : > "$ARMS"

# reg_run <run-label> <contract-file> — deduped, because several arms read one run's output and
# running the validator twice to learn the same thing costs 6.5s.
reg_run() {
  awk -F'\t' -v l="$1" '$1==l{f=1} END{exit !f}' "$RUNS" \
    || printf '%s\t%s\n' "$1" "$2" >> "$RUNS"
}

# reg_arm <kind> <label> <run> <want> <a> <b>
reg_arm() {
  ASSERTIONS=$((ASSERTIONS + 1))
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$ARMS"
}

# $1 mutant-file  $2 invariant id that MUST appear  $3 label  $4 why
#
# THE SIGNATURE AND EVERY CALL SITE BELOW ARE UNCHANGED. Only the timing moved: this now builds
# the job rather than running it. The `cmp -s` guard stays HERE, in the serial phase, because a
# mutation that matched nothing is a fact about the build and must not consume a pool slot.
mutant_fires() {
  local file="$1" want="$2" label="$3" why="$4"
  if cmp -s "$CONTRACT" "$file"; then
    reg_arm unmutated "$label" - - "$why" -
    return
  fi
  reg_run "$label" "$file"
  reg_arm fires "$label" "$label" "$want" "$why" -
}

echo "$NAME fixture"
echo

# THE UNMUTATED CONTROL, FIRST. If the real contract does not come out clean, every "the mutant
# fired" result below is meaningless — the validator would be failing for an unrelated reason and
# each mutant would score a kill it did not earn.
#
# IT IS ALSO THE ONE RUN THAT STAYS SERIAL, AND FIRST, deliberately: it is the run every other
# arm's attributability depends on, so it is settled before the pool spends anything. It is NOT
# skipped when it fails — that would drop the arms below out of the count and turn a dirty
# control into a SHORT report, which is the shape this fixture exists to make impossible.
cp "$CONTRACT" "$TMP/control.yaml"
reg_run control "$TMP/control.yaml"
reg_arm clean control control - \
  "clean  (the real contract passes, so a mutant fire is attributable)" \
  "the UNMUTATED contract already fails — every mutant below is unattributable"

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

# --- I61 arm 1: the prose home states a DIFFERENT severity from the contract ----------
# The arm that caught three live mismatches on the tree it shipped against. LC-N5 was promoted
# to ERROR one release earlier — in a commit that rewrote 24 lines of its own README bullet —
# and the severity word at the head of that bullet stayed WARN. I38 was green throughout,
# because it asks only that the home MENTIONS the id.
#
# The FIRST level: line is flipped between two values the contract itself uses, so the mutation
# stays inside the vocabulary and arm 2 below cannot be what fires. Asserted on this arm's own
# wording — "but layer-contract.yaml declares it" — never on the bare token I61, which three
# arms emit.
awk '
  /^    level: ERROR$/ { if (!done) { done = 1; print "    level: WARN"; next } }
  { print }
' "$CONTRACT" > "$TMP/i61-severity.yaml"
mutant_fires "$TMP/i61-severity.yaml" "but layer-contract.yaml declares it" "i61-severity" \
  "an author reads a severity in the README that their own pre-push does not apply"

# --- I61 arm 2: a bullet whose severity is outside the contract's own vocabulary -------
# The escape hatch this arm closes: a clause bullet that states no severity at all is a bullet
# arm 1 cannot check, so without a membership test the join empties one bullet at a time. The
# vocabulary is DERIVED from the contract's level: values, so the mutation moves the vocabulary
# out from under every bullet rather than editing any bullet — which is the only way to test
# membership from a contract-only mutation.
sed 's/^    level: .*$/    level: NOTALEVEL/' "$CONTRACT" > "$TMP/i61-vocab.yaml"
mutant_fires "$TMP/i61-vocab.yaml" "no severity from the contract's own vocabulary" "i61-vocabulary" \
  "a bullet stating a severity the contract does not use is an unchecked bullet"

# --- I61 arm 3: the vacuity guard -----------------------------------------------------
# Zero bullets found is indistinguishable from every bullet agreeing, which is this repo's named
# defect class applied to I61 itself. Every prose_home is repointed at a core file that carries
# no clause bullets. I38 co-fires on the same mutant — unavoidable, since a home that carries no
# bullet also carries no id — so the assertion is on I61's own zero-guard sentence, which no
# other arm and no other invariant emits.
sed 's|^    prose_home: .*$|    prose_home: core/skills/ai-dlc/core-manifest.md|' "$CONTRACT" > "$TMP/i61-zero.yaml"
mutant_fires "$TMP/i61-zero.yaml" "found ZERO clause bullets" "i61-zero-bullets" \
  "an extraction that finds nothing reports exactly like one where every bullet agrees"

# --- I62 arm 1: prose in a declared HOME names a code and cites the wrong clause ------
# THE SHAPE I38 AND I61 BOTH MISS. I38 iterates clauses and is satisfied by one mention of the
# id anywhere in the file; I61 iterates bullets that ALREADY carry an id. Prose that states a
# duty, names the code enforcing it and carries no clause id is outside both, and it was live in
# eleven places on the tree this shipped against.
#
# The mutation SWAPS two codes between two clauses rather than renaming one. A rename would move
# the code out of every enforcer's vocabulary and fire I36 as well; a swap keeps both codes
# emitted and both claimed, so I36, I37, I38, I41 and I61 all stay silent and this arm fires
# alone. The pair is chosen for isolation too: both are WARN, so no severity moves, and both are
# named ONLY in extensions/README.md, so the pointer arm below cannot be what fires.
sed -e 's/^    code: EXTENSION-RESTATES-CORE$/    code: __SWAP__/' \
    -e 's/^    code: EXTENSION-FIXTURE-UNBOUND$/    code: EXTENSION-RESTATES-CORE/' \
    -e 's/^    code: __SWAP__$/    code: EXTENSION-FIXTURE-UNBOUND/' \
    "$CONTRACT" > "$TMP/i62-home.yaml"
mutant_fires "$TMP/i62-home.yaml" "I62: core/skills/ai-dlc/extensions/README.md" "i62-home" \
  "prose in a declared home names a code while the clause that owns it goes unnamed"

# --- I62 arm 2: the POINTER scope ------------------------------------------------------
# A pointer homes no clause of its own, so the home arm's derived scope is empty for it and a
# separate scope — every code it names — is what puts Rule 27 under the join at all. Without
# this arm the pointer role would be a pin with no reader.
#
# W4 is named by NO pinned file except core SKILL.md, and W2 by none at all, so swapping them
# moves exactly one unit's owed id and cannot reach extensions/README.md.
sed -e 's/^    code: W4$/    code: __SWAP__/' \
    -e 's/^    code: W2$/    code: W4/' \
    -e 's/^    code: __SWAP__$/    code: W2/' \
    "$CONTRACT" > "$TMP/i62-pointer.yaml"
mutant_fires "$TMP/i62-pointer.yaml" "I62: core/skills/ai-dlc/SKILL.md" "i62-pointer" \
  "a pointer that names a code without citing its clause is a second, unbound copy of the rule"

# --- I62 arm 3: the vacuity guard ------------------------------------------------------
# An empty code vocabulary makes every pinned file report clean for the reason a conforming tree
# does. The only contract-only way to empty it is to move the field name out from under the
# triple extractor, and `prose_home:` is read by I61 and I63 as well, so those co-fire. That is
# unavoidable and is the same call this fixture already makes for i61-zero-bullets: the
# assertion is on I62's OWN zero sentence, which no other arm and no other invariant emits.
sed 's/^    prose_home:/    prose_home_x:/' "$CONTRACT" > "$TMP/i62-zero.yaml"
mutant_fires "$TMP/i62-zero.yaml" "triples out of layer-contract.yaml" "i62-zero-vocab" \
  "a scan with no vocabulary reports exactly like a tree where every mention is cited"

# --- I63 arm 1: a pinned HOME that carries no clause ----------------------------------
# The state that ran for nineteen releases with nothing able to say so. core-manifest.md is
# re-pinned home; it is the prose_home of no clause, which is precisely the invisible gap.
awk '
  /^  - path: core\/skills\/ai-dlc\/core-manifest.md$/ { p=1 }
  p && /^    role: none$/ { print "    role: home"; p=0; next }
  { print }
' "$CONTRACT" > "$TMP/i63-home.yaml"
mutant_fires "$TMP/i63-home.yaml" "pinned role: home but is the declared prose_home of NO clause" \
  "i63-home-empty" "a home contributing zero clauses is the gap this pin exists to make loud"

# --- I63 arm 2: a pinned POINTER that points at nothing --------------------------------
awk '
  /^  - path: core\/skills\/ai-dlc\/core-manifest.md$/ { p=1 }
  p && /^    role: none$/ { print "    role: pointer"; p=0; next }
  { print }
' "$CONTRACT" > "$TMP/i63-pointer.yaml"
mutant_fires "$TMP/i63-pointer.yaml" "pinned role: pointer but names NO contract code" \
  "i63-pointer-empty" "a pointer naming no code asserts a relationship the file does not have"

# --- I63 arm 3: a file pinned `none` that has GROWN contract prose ---------------------
# role: none is what keeps a file outside I62's citation join, so a file that quietly acquires
# contract prose under that pin states duties nothing binds. Core SKILL.md names four codes.
awk '
  /^  - path: core\/skills\/ai-dlc\/SKILL.md$/ { p=1 }
  p && /^    role: pointer$/ { print "    role: none"; p=0; next }
  { print }
' "$CONTRACT" > "$TMP/i63-none.yaml"
mutant_fires "$TMP/i63-none.yaml" "pinned role: none but names" "i63-none-grew" \
  "a file pinned as carrying no contract prose has acquired some, outside every join"

# --- I63 arm 4: a pin at a path the tree does not carry --------------------------------
sed 's|^  - path: core/skills/ai-dlc/core-manifest.md$|  - path: core/skills/ai-dlc/nope.md|' \
  "$CONTRACT" > "$TMP/i63-path.yaml"
mutant_fires "$TMP/i63-path.yaml" "absorbed_from pins" "i63-bad-path" \
  "a pin at a missing path silently drops that file from every arm"

# --- I63 arm 5: a role outside the vocabulary ------------------------------------------
# Without this the third role is an escape hatch: an unrecognised value matches no arm, so the
# file is pinned and checked by nothing, which reads exactly like a file that passed.
sed 's/^    role: pointer$/    role: signpost/' "$CONTRACT" > "$TMP/i63-role.yaml"
mutant_fires "$TMP/i63-role.yaml" "not one of home, pointer or none" "i63-bad-role" \
  "an unrecognised role matches no arm, so the file is pinned and checked by nothing"

# --- I63 arm 6: REVERSE — a declared prose_home that is not pinned ----------------------
# The direction that stops the list falling behind the contract. Exactly one entry is dropped:
# the path line and the single role line beneath it.
awk '
  /^  - path: core\/skills\/ai-dlc\/overrides\/README.md$/ { skip=1; next }
  skip == 1 && /^    role:/ { skip=0; next }
  { print }
' "$CONTRACT" > "$TMP/i63-reverse.yaml"
mutant_fires "$TMP/i63-reverse.yaml" "I63 reverse" "i63-reverse" \
  "a home outside the pinned list is checked by no role arm and reduced to a pointer by nothing"

# --- I63 arm 7: the vacuity guard ------------------------------------------------------
# An empty list has no subject, and no subject passes every arm above. It also empties I62,
# whose scope is this list — so this one zero would retire both invariants at once.
awk '
  /^absorbed_from:/ { d=1 }
  d && /^  - path:|^    role:/ { next }
  d && /^clauses:/ { d=0 }
  { print }
' "$CONTRACT" > "$TMP/i63-zero.yaml"
mutant_fires "$TMP/i63-zero.yaml" "ZERO entries out of layer-contract.yaml" "i63-zero-pins" \
  "an empty pin list retires I63 and I62 together, and reports clean doing it"

# --- I64 arm 1: a code the enforcer carries but never EMITS attributably ----------------
# THE CASE I36 CANNOT SEE, and the mutation is chosen to prove exactly that rather than to
# trip both. `EXTENSION-OK` is a real token in reconcile/layer-drift.sh — it is the clean-state
# row — so I36 forward's whole-file `grep -qF` FINDS it and stays quiet on this clause. It is
# not a finding vocabulary, so it is excluded from the emitted set and I64 reports it.
#
# Stated rather than smoothed: this mutation also orphans OVERRIDE-LOOSE-ANCHOR, so I36 reverse
# fires too — on a DIFFERENT subject (the code left unclaimed), not on this clause. The
# assertion below is therefore paired with its complement: I36 forward must stay SILENT on
# LC-O12 while I64 speaks about it. Without that pair the arm would prove only that something
# fired, which is what a redundant check looks like from the outside.
sed 's/^    code: OVERRIDE-LOOSE-ANCHOR$/    code: EXTENSION-OK/' "$CONTRACT" > "$TMP/i64-unemitted.yaml"
mutant_fires "$TMP/i64-unemitted.yaml" "I64 LC-O12" "i64-unemitted" \
  "a clause bound to a token its enforcer carries but never emits cannot fire, and reads to I36 exactly like one that passed"

# Reads the SAME run as the arm above rather than repeating it — the question is about two
# invariants' behaviour on one mutant, so one run answers both.
reg_arm nofire i64-vs-i36 i64-unemitted "I36 LC-O12" \
  "I36 forward stays SILENT on LC-O12 — the token IS in the enforcer, so only I64 reports it" \
  "I36 forward ALSO fired on LC-O12, so the arm above is not evidence I64 sees anything I36 misses"

# --- I64 arm 2: the vacuity guard on its own extraction ---------------------------------
# I64 reads the enforcer through a per-enforcer `case`, which is a second extraction beside
# I36's and fails independently of it. If that case stops matching, every clause bound to the
# script passes by having no emitted set to be absent from — so the zero is reported, never
# skipped. (I36 reverse's own vacuity arm fires on this mutation too; the two guard different
# extractions and both going quiet is the state neither could report alone.)
sed 's|^    enforcer: core/skills/ai-dlc-update/reconcile/layer-drift.sh$|    enforcer: core/skills/ai-dlc/extensions/README.md|' \
  "$CONTRACT" > "$TMP/i64-vacuous.yaml"
mutant_fires "$TMP/i64-vacuous.yaml" "I64: found NO attributable emission sites" "i64-vacuity" \
  "an extraction that matches nothing retires this invariant for every clause bound to that enforcer"

# --- I64 arm 3: the control — silent on the shipping contract ---------------------------
# The arms above prove I64 speaks. This proves it is not simply always speaking, which is the
# other way an invariant reads green while meaning nothing.
# Reads the unmutated control's run. It is NOT subsumed by the `control` arm above: that one
# asserts the output is EMPTY, this one asserts I64 specifically is not in it, so a control that
# goes dirty for an unrelated reason still leaves I64's kills attributable or not on their own
# evidence.
reg_arm nofire i64-control control '^FAIL: I64' \
  "CONTROL: I64 is silent on the shipping contract, so its kills are attributable" \
  "I64 fires on the UNMUTATED contract, so its kills above prove nothing"

# --- I65: the clause names the FIXTURE that proves it, and the fixture can prove it -----
#
# FIVE ARMS, ONE PER PART OF THE PREDICATE, because each part was added for a state the ones
# before it accepted. Every arm rewrites the `fixture:` of ONE clause, and no other invariant
# reads that field, so each fires alone.
#
# THE MUTATION TARGETS ARE REAL DIRECTORIES CHOSEN BY MEASUREMENT, not invented names, because
# a nonsense path would be rejected by the first arm and prove nothing about the later ones:
#   check-h1-recursion      exists and has NO run.sh (one of exactly two such dirs)
#   release-version-triple  has a run.sh and names validate-layer-entries.sh ZERO times
#   layer-conforms-to       drives validate-layer-entries.sh and names E1 ZERO times
# Each is asserted below by the arm it feeds; if any of them acquires the property it was
# chosen for lacking, that arm reports the mutation as unproven rather than scoring a kill.

# set_fixture <clause> <value|DELETE> <outfile>
set_fixture() {
  awk -v want="$1" -v val="$2" '
    /^  - id:/ { id=$3 }
    { if (id == want && $1 == "fixture:") { if (val != "DELETE") printf "    fixture: %s\n", val; next } ; print }
  ' "$CONTRACT" > "$3"
}

# ARM 1 — the field itself. A clause with no fixture: is neither a proof nor a declared gap,
# and it is the only one of the three states the invariant cannot report on.
set_fixture LC-O1 DELETE "$TMP/i65-missing.yaml"
mutant_fires "$TMP/i65-missing.yaml" "I65 LC-O1: no 'fixture:' declared" "i65-missing" \
  "an undeclared field is not the same as a declared gap, and only one of them is counted"

# ARM 2 — a driverless directory. The pre-push loop skips a dir with no run.sh in silence, so a
# clause citing one cites a proof that never executes.
set_fixture LC-O3 check-h1-recursion "$TMP/i65-nodriver.yaml"
mutant_fires "$TMP/i65-nodriver.yaml" "I65 LC-O3: fixture 'check-h1-recursion' has no run.sh" "i65-nodriver" \
  "a fixture the suite skips is not evidence, and its silence is identical to a pass"

# ARM 3 — the enforcer scope. Without it a fixture for a DIFFERENT script satisfies the join
# whenever the two vocabularies collide on a token, which W1 and W2 actually do in this repo.
set_fixture LC-O10 release-version-triple "$TMP/i65-wrongenf.yaml"
mutant_fires "$TMP/i65-wrongenf.yaml" "I65 LC-O10: fixture 'release-version-triple' never names" "i65-wrongenf" \
  "a fixture that never drives the clause's enforcer cannot be evidence about that clause"

# ARM 4 — the attributable site. THE ARM THIS INVARIANT EXISTS FOR: a fixture that genuinely
# drives the enforcer but names the code only in a header sentence proves nothing a run can
# join back to the clause. Six fixtures were in exactly that state when this shipped.
set_fixture LC-O1 layer-conforms-to "$TMP/i65-unattributed.yaml"
mutant_fires "$TMP/i65-unattributed.yaml" "I65 LC-O1: fixture 'layer-conforms-to' drives" "i65-unattributed" \
  "prose about the proof is not the proof; the fixture's own output must name the clause it closed"

# ARM 5 — the REVERSE arm, and it is what stops `none` decaying into an exemption. `none` is a
# counted gap; writing it over a clause a live fixture proves would retire that proof from the
# census with nothing able to say so.
set_fixture LC-O1 none "$TMP/i65-noneforged.yaml"
mutant_fires "$TMP/i65-noneforged.yaml" "I65 LC-O1: declares 'fixture: none' but" "i65-noneforged" \
  "a fixture written without updating the clause it proves would leave the gap on the books forever"

# ARM 6 — the control. The five above prove I65 speaks; this proves it is not simply always
# speaking, which is the other way an invariant reads green while meaning nothing.
#
# THERE IS NO VACUITY MUTANT HERE, and that is a decision rather than an omission. I65's own
# vacuity defence is a PROBE it writes and runs itself each time — four directories whose
# answers must total exactly 1 — so it is unreachable by mutating the contract, which is the
# only thing this fixture mutates. The zero-rows guard is likewise unisolatable: a contract
# with no clauses fails every other invariant here first, so a mutant for it would be entangled
# and would prove nothing about I65. Recorded rather than left as a silent gap.
reg_arm nofire i65-control control '^FAIL: I65' \
  "CONTROL: I65 is silent on the shipping contract, so its kills are attributable" \
  "I65 fires on the UNMUTATED contract, so its kills above prove nothing"

# THE ASSERTION-COUNT FLOOR. A fixture that silently stops running arms prints a shorter green
# report, and a shorter green report reads exactly like a passing one — the lesson v0.217.0
# paid for, where a mis-spaced helper call killed a whole mutant inside a `$( )` subshell and
# left seventeen ok lines and a PASS. Raise this deliberately when an arm is added.
#
# IT IS CHECKED HERE, BEFORE THE POOL, because that is now the earliest point at which it is
# knowable and because a pool sized from a short registry would go on to report a short green run.
EXPECTED_ASSERTIONS=33
if [ "$ASSERTIONS" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "FAIL: $ASSERTIONS assertions registered, $EXPECTED_ASSERTIONS expected — an arm did not execute, and a short green report reads exactly like a passing one."
  exit 1
fi

# THE ARM-RESOLUTION JOIN, AND IT IS WHAT MAKES THE PARTITION A TOTAL FUNCTION.
#
# The shard deal below is round-robin over $RUNS, so every arm whose `run` field names a
# member of $RUNS lands in exactly ONE shard, and every arm reading `control` lands in ALL of
# them (`control` is itself a $RUNS member — it is registered by reg_run above — so it needs
# no clause of its own here). What has no home is an arm naming a run label that was never
# registered: it is dealt to no shard, evaluates NOWHERE, and is simply not printed. That is
# indistinguishable from an arm that passed, and unlike the unsharded file it costs nothing to
# reach — a typo in one reg_arm field is enough.
#
# SO THE BAD STATE IS MADE UNCONSTRUCTIBLE HERE RATHER THAN LOOKED FOR AFTERWARDS. With this
# guard passing, "the union of the shards' arms equals $ARMS" is a THEOREM about the deal, not
# a property worth asserting — a union arm added below this one could not fail, and a check
# that cannot fire reads exactly like one that passed. Do not add it back.
#
# `-` is the run of the `unmutated` kind, which mutant_fires registers when a mutation matched
# nothing. It has no run to be dealt, so it is dealt to shard 'a' by the filter below.
unresolved="$(awk -F'\t' '
  FNR == NR    { known[$1] = 1; next }
  $3 == "-"    { next }
  !($3 in known) { print "    " $2 "  ->  " $3 }
' "$RUNS" "$ARMS")"
if [ -n "$unresolved" ]; then
  echo "FIXTURE ERROR: arm(s) name a run label that is in neither \$RUNS nor the literal '-':" >&2
  printf '%s\n' "$unresolved" >&2
  echo "  The shard deal is round-robin over \$RUNS, so an arm resolving nowhere is dealt to NO shard. It would evaluate nowhere and print nothing, which is exactly what a passing arm adds." >&2
  exit 2
fi

# ================== PHASE 2: run the validator, once per distinct contract ==================
#
# THE JOB LIST IS DERIVED FROM THE REGISTRATIONS ABOVE, with a zero guard. It is never restated:
# a hand-written list is the same defect one level out, and a pool given nothing to do finishes
# instantly and reports every arm as a dropped job rather than saying the list was empty.
N_RUNS="$(grep -c . "$RUNS" || true)"
if [ "$N_RUNS" -lt 25 ]; then
  echo "FIXTURE ERROR: derived $N_RUNS validator run(s) from this file's own registrations — the registry did not fill, so nothing below is evidence" >&2
  exit 2
fi

# ================== THE ARM SELECTOR, DERIVED FROM THE REGISTRIES ==================
#
# EVERY RUN HERE TESTS ONE INVARIANT AND PAYS FOR EIGHTY-ONE. validate-enforcement-map.sh
# now takes `--arms I<n>[,I<n>...]` and executes only the UNITS declaring those ids, plus its
# prologue and its verdict block. A unit is a column-0 arm header through the line before the
# next one; the nine INDENTED arms that sit inside the layer contract's `if [ -f "$lc_file" ]`
# block therefore all resolve to the single unit opened by the `I36 / I37 / I38` header, so
# selecting any one of this fixture's ids selects all of them. Derived here rather than taken
# on trust — `render-invariant-index.sh --arm-lines` joined against the validator's own line
# numbers puts I36/I37/I38, I41, I42, I37, I61, I63, I62, I64, I65 and I58 in one unit.
# Measured on that unit: ~2.9 CPU-seconds against ~19.5 for a full run, uniform across every
# arm this fixture asserts on.
#
# THE SELECTOR IS DERIVED FROM STRINGS THAT ALREADY EXIST, AND A HAND-WRITTEN LIST WOULD BE
# THIS FIXTURE'S OWN DEFECT ONE LEVEL OUT: an id dropped from such a list would select the
# wrong unit, the arm under test would not run, and its `want` would not be found — which is
# indistinguishable from the mutant surviving, i.e. a false FAIL, or worse, for a `nofire`
# arm, a false ok.
#
# THE SOURCE IS THE RUN LABEL, NOT THE `want` COLUMN, AND THAT IS A TOTALITY ARGUMENT. Every
# label here already opens `i<id>-` — `i36-forward`, `i63-zero-pins`, `i65-noneforged` — so
# upcasing the leading segment is total over the registry. The `want` column is NOT: eleven of
# the thirty assertions are deliberately worded on their arm's OWN sentence rather than on the
# bare invariant token — `emits 'GM1'`, `has no since:`, `found ZERO clause bullets`,
# `absorbed_from pins`, `not one of home, pointer or none` — precisely because an assertion on
# a shared token would pass against a reverted fix. Those carry no id at all.
#
# THE `want` COLUMN IS STILL READ, AS AN ADDITION RATHER THAN AS THE SOURCE, AND IT IS WHAT
# KEEPS A CROSS-INVARIANT ARM HONEST. `i64-vs-i36` reads i64-unemitted's run and asserts I36
# forward stays SILENT on LC-O12. Selecting that run on its label alone would ask for I64, and
# an absence asserted over an arm that did not run is the vacuous pass this whole fixture
# exists to make impossible. So a run's selector is the UNION, over every arm reading it, of
# the ids in that arm's label and the ids in its `want`; i64-unemitted comes out {I36,I64}.
# The union is right even today, when the two ids happen to share a unit — the fixture must
# not be green by accident of a boundary it does not control.
#
# WHICH RUNS STAY ON THE FULL VALIDATOR IS DERIVED FROM ARM SHAPE, NOT FROM A NAME. A `clean`
# arm asserts the validator's ENTIRE output is empty — an absence-shaped claim over every arm
# in the file — and a selected run says nothing whatever about the arms it did not run. So a
# run read by any `clean` arm is FULL. Today that is exactly `control`, and every other
# registered run was checked for the same shape: the other two absence-shaped arms,
# `i64-control` and `i65-control`, are `nofire` arms that also read `control` and are covered
# by its full run; `i64-vs-i36` is the only absence-shaped arm on a mutant run, and its claim
# is over ONE named invariant rather than over the whole output, which is what the union above
# makes safe. Every other arm is `fires` — presence-shaped, so a wrong selection can only turn
# it red, never green.
#
# A RUN THAT YIELDS NO ID IS A FIXTURE ERROR, NEVER A FULL RUN. A fallback to the whole
# validator would run everything, print the same green report, and leave nobody able to tell
# that selection had stopped happening — a mechanism that cannot fire, reading exactly like
# one that did.
SEL="$TMP/sel"; : > "$SEL"
sel_bad="$(awk -F'\t' -v out="$SEL" '
  function idsfrom(s,   acc) {
    acc = ""
    while (match(s, /I[0-9]+[a-c]?/)) { acc = acc " " substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH) }
    return acc
  }
  function addids(r, list,   n, i, w) {
    n = split(list, w, /[ \t]+/)
    for (i = 1; i <= n; i++) {
      if (w[i] == "") continue
      if (index(" " sel[r] " ", " " w[i] " ") == 0) sel[r] = (sel[r] == "" ? w[i] : sel[r] " " w[i])
    }
  }
  FNR == NR { order[++nr] = $1; next }
  {
    arun = $3
    if (arun == "-") next
    if ($1 == "clean") full[arun] = 1
    lid = ""
    if (match($2, /^i[0-9]+[a-c]?/)) { lid = substr($2, RSTART, RLENGTH); sub(/^i/, "I", lid) }
    addids(arun, lid)
    wid = idsfrom($4)
    addids(arun, wid)
    if ($1 == "nofire" && wid == "") noid[arun] = noid[arun] " " $2
  }
  END {
    if (nr == 0) { print "    the run registry is empty, so no selector can be derived from it"; exit }
    for (i = 1; i <= nr; i++) {
      r = order[i]
      if (r in full) { print r "\tFULL" > out; continue }
      if (!(r in sel) || sel[r] == "") {
        print "    run " r " -> no invariant id is derivable from any arm label or want field that reads it"
        continue
      }
      if (r in noid) {
        print "    run " r " -> selected, but nofire arm(s)" noid[r] " name no invariant id in their want, so the absence would be asserted over an arm that may not have run"
        continue
      }
      s = sel[r]; gsub(/[ \t]+/, ",", s)
      print r "\t" s > out
    }
    close(out)
  }
' "$RUNS" "$ARMS")"
if [ -n "$sel_bad" ]; then
  echo "FIXTURE ERROR: the arm selector could not be derived for every registered run:" >&2
  printf '%s\n' "$sel_bad" >&2
  echo "  There is deliberately NO fallback to the full validator here: a fallback that quietly runs everything reports the same green run and makes the loss of selection unobservable." >&2
  exit 2
fi
N_SEL="$(grep -c . "$SEL" || true)"
if [ "$N_SEL" -ne "$N_RUNS" ]; then
  echo "FIXTURE ERROR: derived $N_SEL selector row(s) for $N_RUNS registered run(s) — a run with no row would be dispatched with no selector." >&2
  exit 2
fi

# ONE RUNNER, GENERATED ONCE AND INVOKED BY BOTH THE SERIAL CONTROL AND THE POOL. The two used
# to carry the same invocation twice, which is one place for the `--arms` flag to be added and
# another for it to be forgotten. It also captures the validator's EXIT CODE, which the old
# `bash "$VAL" | grep` shape threw away in the pipe — and exit 2 now means a selection or
# usage failure, which must be reported as a broken fixture rather than scored as a mutant.
RUNNER="$TMP/run-one.sh"
cat > "$RUNNER" <<'LCC_RUNNER'
#!/usr/bin/env bash
# run-one.sh <run-label> — generated by core/fixtures/layer-contract-conformance/run.sh.
# Reads the contract file and the selector for its label out of the two registries, runs the
# validator, and records four facts: the FAIL lines, the exit code, the MODE it actually used,
# and a done marker. The mode is written by the thing that ran, which is what lets the caller
# join what was declared against what happened.
set -u
l="$1"
f="$(awk -F'\t' -v k="$l" '$1==k{print $2}' "$AI_DLC_LCC_RUNS")"
s="$(awk -F'\t' -v k="$l" '$1==k{print $2}' "$AI_DLC_LCC_SEL")"
raw="$AI_DLC_LCC_OUT/$l.raw"
if [ -z "$f" ] || [ -z "$s" ]; then
  printf 'run %s resolved no contract file and/or no selector row out of the registries\n' "$l" > "$raw"
  : > "$AI_DLC_LCC_OUT/$l.txt"
  printf unresolved > "$AI_DLC_LCC_OUT/$l.mode"
  printf 2 > "$AI_DLC_LCC_OUT/$l.rc"
  printf done > "$AI_DLC_LCC_OUT/$l.done"
  exit 0
fi
if [ "$s" = FULL ]; then
  m=full
  AI_DLC_LAYER_CONTRACT="$f" bash "$AI_DLC_LCC_VAL" > "$raw" 2>&1
else
  m=sel
  AI_DLC_LAYER_CONTRACT="$f" bash "$AI_DLC_LCC_VAL" --arms "$s" > "$raw" 2>&1
fi
rc=$?
grep '^FAIL' "$raw" > "$AI_DLC_LCC_OUT/$l.txt" || :
printf '%s' "$m" > "$AI_DLC_LCC_OUT/$l.mode"
printf '%s' "$rc" > "$AI_DLC_LCC_OUT/$l.rc"
printf done > "$AI_DLC_LCC_OUT/$l.done"
exit 0
LCC_RUNNER

# The control is settled FIRST and SERIALLY — see its arm above.
AI_DLC_LCC_VAL="$VAL" AI_DLC_LCC_OUT="$OUTD" AI_DLC_LCC_RUNS="$RUNS" AI_DLC_LCC_SEL="$SEL" \
  bash "$RUNNER" control

# FOUR, AND FIXED RATHER THAN TUNABLE — the same reasoning as enforcement-map-sites, which
# states it in place: this pool nests inside the pre-push suite's own, so a knob here
# multiplies against the knob there and the PRODUCT is what lands on the machine.
#
# THE ARITHMETIC IS THE SHARD SPLIT, AND IT IS THE WHOLE REASON THE NUMBER MOVED. This was
# EIGHT while the assertions lived in one directory. There are now TWO directories, both
# dispatched by the same outer pool and both eligible to run at once, so 2 x 4 keeps this
# fixture family's demand on the machine exactly where it was. Raising it back to 8 would
# double that demand without adding a core.
#
# THE STANDALONE SWEEP THAT USED TO SIT HERE IS GONE RATHER THAN CARRIED FORWARD. It was
# measured on the unsharded directory (-P4 60.1s ... -P16 32.1s) against a critical path that
# was enforcement-map-sites, and it named that condition itself: re-derive both numbers
# together if the critical path moves off it. It has moved — the pole is now a six-fixture set
# this directory is a member of — so those figures describe a machine state that no longer
# exists, and a superseded sweep beside a changed constant is a rationale that argues for the
# wrong number. The joint re-derivation of the outer width and all nine inner widths is its
# own measured step; it is not restated here.
LCC_JOBS=4

# DEAL THE NON-CONTROL RUNS OUT TO THE SHARDS IN TURN. ROUND-ROBIN, NOT CONTIGUOUS HALVES:
# these runs are one full validator invocation each, but the CONTRACTS differ — several
# mutants delete whole clause blocks and shorten the corpus every arm scans — so a contiguous
# cut can put the expensive neighbours in one shard and rebuild the pole inside it. Dealing
# them out in turn spreads that without anyone maintaining a cost table that would go stale the
# first time a mutant changed.
awk -F'\t' '$1!="control"{print $1}' "$RUNS" \
  | awk -v g="$GROUP" -v shards="$SHARDS" '
      BEGIN { n = split(shards, S, " ") }
      { if (S[((NR - 1) % n) + 1] == g) print }
    ' > "$TMP/pool"

# THE EMPTY-SHARD GUARD, AND THE FLOOR ABOVE DOES NOT COVER IT. `N_RUNS -lt 25` is a statement
# about the REGISTRY, which is identical in every shard, so it passes unchanged on a shard that
# was dealt nothing — and a shard dealt nothing runs no validator, evaluates only the control
# arms, and reports a green run.
N_MINE="$(grep -c . "$TMP/pool" || true)"
if [ "$N_MINE" -eq 0 ]; then
  echo "$NAME: FIXTURE ERROR — shard '$GROUP' was dealt no validator runs out of the $((N_RUNS - 1)) non-control runs registered. An empty shard passes every assertion it never made." >&2
  exit 2
fi

# THE ARM FILTER. A shard evaluates: every arm whose run was dealt to it, every arm reading the
# `control` run — EVERY SHARD RUNS THE CONTROL, because a shard without it reports its own
# mutant kills as earned against a contract nobody checked — and, in shard 'a' only, the arms
# whose run is `-`, which have no run to be dealt.
ARMS_MINE="$TMP/arms.mine"
awk -F'\t' -v g="$GROUP" '
  FNR == NR       { mine[$1] = 1; next }
  $3 == "control" { print; next }
  $3 == "-"       { if (g == "a") print; next }
  ($3 in mine)    { print }
' "$TMP/pool" "$ARMS" > "$ARMS_MINE"

# ASSERTIONS IS SHARD-LOCAL FROM HERE, AND THIS LINE IS LOAD-BEARING. reg_arm counted EVERY
# registered arm during Phase 1 — it has to, because the EXPECTED_ASSERTIONS floor above is a
# statement about the whole registry — so leaving it alone would make each shard print
# "all 33 assertions correct" after evaluating about half of them. That is a check wearing a
# pass: the count is the thing the floor exists to make trustworthy, and a shard reporting a
# number it did not compute retires the floor for both shards at once.
ASSERTIONS="$(grep -c . "$ARMS_MINE" || true)"

AI_DLC_LCC_VAL="$VAL" AI_DLC_LCC_OUT="$OUTD" AI_DLC_LCC_RUNS="$RUNS" AI_DLC_LCC_SEL="$SEL" \
  xargs -P "$LCC_JOBS" -I{} bash "$RUNNER" {} < "$TMP/pool"

# THE RUNS THIS SHARD ACTUALLY EXECUTED: the serial control plus whatever it was dealt. Both
# guards below are scoped to it, because a shard must not report on a run it never started.
MINE_RUNS="$TMP/mine.runs"
{ echo control; cat "$TMP/pool"; } > "$MINE_RUNS"

# ---------------------------------------------------------------------------
# EXIT 2 IS A BROKEN FIXTURE, AND IT IS NEITHER A KILL NOR A SURVIVAL
# ---------------------------------------------------------------------------
# The validator exits 2 for an unknown arm id, a malformed flag, or a generated subprogram
# that did not reach its verdict block. None of those is an invariant violation, and none is
# evidence about the mutant: the run under a bad selector produces NO FAIL lines at all, which
# would score a `fires` arm as the mutant surviving and a `nofire` arm as a clean pass. So it
# is caught HERE, before a single arm is evaluated, and it aborts rather than being counted.
rc2=""
while read -r _l; do
  [ -n "$_l" ] || continue
  [ "$(cat "$OUTD/$_l.rc" 2>/dev/null || true)" = 2 ] || continue
  rc2="$rc2
    run '$_l' — $(head -2 "$OUTD/$_l.raw" 2>/dev/null | tr '\n' ' ')"
done < "$MINE_RUNS"
if [ -n "$rc2" ]; then
  echo "$NAME: FIXTURE ERROR — validate-enforcement-map.sh exited 2, which is a selection or usage failure and never an invariant violation:$rc2" >&2
  echo "  Nothing below was scored: a run with a broken selector emits no FAIL lines, so it would read as every mutant surviving and every nofire arm passing." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# THE POSITIVE CONTROL ON SELECTION ITSELF
# ---------------------------------------------------------------------------
# Selection is invisible in the report — a selected run and a full run print the same `ok`
# line, so a conversion that quietly stopped selecting would stay green and only get slower.
# BOTH SIDES ARE DERIVED. The left is the registry-derived $SEL table; the right is the `.mode`
# file each run wrote FROM INSIDE THE RUNNER, so it records what was executed rather than what
# was intended. A third clause joins their sum to the run population this shard dispatched, so
# a $SEL table that has quietly lost a row cannot balance by shrinking both sides together.
#
# NEITHER EXISTING GUARD COVERS THIS. `N_RUNS -lt 25` is a floor on the REGISTRY, identical in
# every shard and blind to how a run is invoked; the empty-shard guard asks only that this
# shard was dealt something. Both pass unchanged on a fixture that selects nothing.
exp_sel=0; exp_full=0; got_sel=0; got_full=0
while read -r _l; do
  [ -n "$_l" ] || continue
  case "$(awk -F'\t' -v k="$_l" '$1==k{print $2}' "$SEL")" in
    FULL) exp_full=$((exp_full + 1)) ;;
    ?*)   exp_sel=$((exp_sel + 1)) ;;
  esac
  case "$(cat "$OUTD/$_l.mode" 2>/dev/null || true)" in
    full) got_full=$((got_full + 1)) ;;
    sel)  got_sel=$((got_sel + 1)) ;;
  esac
done < "$MINE_RUNS"
POP=$((N_MINE + 1))
if [ "$exp_sel" -eq 0 ] || [ "$got_sel" -ne "$exp_sel" ] || [ "$got_full" -ne "$exp_full" ] \
   || [ $((exp_sel + exp_full)) -ne "$POP" ] || [ $((got_sel + got_full)) -ne "$POP" ]; then
  echo "$NAME: FIXTURE ERROR — the selection control does not close in shard '$GROUP'." >&2
  echo "  declared by the registries : $exp_sel selected + $exp_full full" >&2
  echo "  observed from the runner    : $got_sel selected + $got_full full" >&2
  echo "  runs this shard dispatched  : $POP (1 serial control + $N_MINE dealt)" >&2
  echo "  A run that stopped passing --arms executes every arm in the validator and prints exactly the same report, only slower — which is why this is asserted rather than assumed." >&2
  exit 2
fi

# ================== PHASE 3: evaluate, serially, in DECLARATION order ==================
#
# Rendered from ARMS rather than from completion order, so this fixture's stdout is byte-
# comparable against the serial version it replaces — which is the differential this refactor
# was required to produce, and it is only available because the order is declaration order.
while IFS=$'\t' read -r kind label run want a b; do
  case "$kind" in
    unmutated)
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-18s the mutation matched nothing, so this assertion is unproven\n' "$label"
      continue ;;
  esac
  # A MISSING VERDICT IS A FAILURE. `.done` is written after the run, so its absence means the
  # job was dropped — which otherwise adds exactly what a passing arm adds: nothing.
  if [ ! -f "$OUTD/$run.done" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-18s run %s produced no verdict — the pool dropped work, and a short green report reads exactly like a passing one\n' "$label" "$run"
    continue
  fi
  case "$kind" in
    fires)
      if grep -q "$want" "$OUTD/$run.txt"; then
        printf '  ok    %-18s %s fires  (%s)\n' "$label" "$want" "$a"
      else
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-18s %s did NOT fire  (%s)\n' "$label" "$want" "$a"
        sed 's/^/          | /' "$OUTD/$run.txt" | head -5
      fi ;;
    nofire)
      if grep -q "$want" "$OUTD/$run.txt"; then
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-18s %s\n' "$label" "$b"
      else
        printf '  ok    %-18s %s\n' "$label" "$a"
      fi ;;
    clean)
      if [ ! -s "$OUTD/$run.txt" ]; then
        printf '  ok    %-18s %s\n' "$label" "$a"
      else
        FAILURES=$((FAILURES + 1))
        printf '  FAIL  %-18s %s\n' "$label" "$b"
        sed 's/^/          | /' "$OUTD/$run.txt" | head -5
      fi ;;
    *)
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-18s unknown arm kind %s — an arm registered a shape this loop cannot evaluate\n' "$label" "$kind" ;;
  esac
done < "$ARMS_MINE"

echo
# BOTH LINES READ THE SHARD-LOCAL COUNT, and both name the shard. A reader comparing this
# run against the unsharded file's "33" has to be able to see that the smaller number is a
# partition rather than a regression; without the shard name the two are the same sentence.
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong in shard '$GROUP' of '$SHARDS'."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct in shard '$GROUP' of '$SHARDS'."
exit 0
