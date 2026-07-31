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
# TWO PHASES, AND THE REASON IS MEASURED. Every arm here is one full run of
# validate-enforcement-map.sh — 6.45s on the reference box, 62% of it SYSTEM time, which is the
# fork signature rather than work. Thirty of them in a row made this fixture 270.7s of a 276.5s
# suite with ZERO slack: it WAS the suite, and every other unit finished 137s before it. The runs
# are independent by construction — each builds its own contract copy in its own $TMP and points
# the validator at it with AI_DLC_LAYER_CONTRACT — so they were serial only because they were
# written in a row.
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

echo "layer-contract-conformance fixture"
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

# The control is settled FIRST and SERIALLY — see its arm above.
run_one() { # run_one <label> <contract-file>
  AI_DLC_LAYER_CONTRACT="$2" bash "$VAL" 2>&1 | grep '^FAIL' > "$OUTD/$1.txt" || true
  printf done > "$OUTD/$1.done"
}
run_one control "$TMP/control.yaml"

# EIGHT, AND FIXED RATHER THAN TUNABLE — the same number and the same reasoning as
# enforcement-map-sites, which states it in place: this pool nests inside the pre-push suite's
# own, so a knob here multiplies against the knob there and the PRODUCT is what lands on the
# machine. Eight against 18 cores leaves headroom for the sibling fixtures the suite runs beside
# this one.
#
# Measured standalone on the reference box: -P4 60.1s, -P6 45.7s, -P8 41.3s, -P12 35.5s,
# -P16 32.1s. It is still falling at 16 and eight is deliberately NOT the standalone optimum —
# inside the suite this fixture now has 54s of slack, so buying it another 9s standalone would
# be paid for by every unit it contends with. Re-derive both numbers together if the critical
# path moves off enforcement-map-sites.
LCC_JOBS=8
awk -F'\t' '$1!="control"{print $1}' "$RUNS" > "$TMP/pool"
AI_DLC_LCC_VAL="$VAL" AI_DLC_LCC_OUT="$OUTD" AI_DLC_LCC_RUNS="$RUNS" \
  xargs -P "$LCC_JOBS" -I{} bash -c '
    l="$1"
    f="$(awk -F"\t" -v k="$l" "\$1==k{print \$2}" "$AI_DLC_LCC_RUNS")"
    [ -n "$f" ] || exit 0
    AI_DLC_LAYER_CONTRACT="$f" bash "$AI_DLC_LCC_VAL" 2>&1 | grep "^FAIL" > "$AI_DLC_LCC_OUT/$l.txt"
    printf done > "$AI_DLC_LCC_OUT/$l.done"
  ' _ {} < "$TMP/pool"

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
done < "$ARMS"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
