#!/usr/bin/env bash
# Mutation battery for the SUPPRESSED carve-out in validate-gate-adjudication.sh and for the
# --in-force query in validate-suppression-lifetime.sh that owns its predicate, scored through
# the SHIPPED `gate-adjudication` fixture.
#
# WHY A BATTERY AND NOT MORE ARMS. Cases S2–S11 of that fixture are, in substance,
# ABSENCE-shaped: each claims the carve-out does NOT fire for an expired entry, a malformed
# one, a foreign catalog, a prose mention, a prefix of the failing id. A both-directions
# control establishes that a check discriminates between two inputs; only a mutant establishes
# that the line doing the discriminating is the line anybody thinks it is. Every one of those
# cases would pass against a carve-out that was never wired up at all — the FAIL blocks, the
# exit is 1, and nothing says why. Each mutant below removes exactly one property of the fix
# and names the case set that must go red for it.
#
# THE MUTANTS ARE SCORED ON WHICH CASE DIES, NOT ON WHETHER THE FIXTURE WENT RED. A fixture
# reporting red for the wrong case is a mutant that killed nothing and reads identically to one
# that worked, which is the defect this directory exists to catch one level up.
set -u
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve the repo root by walking up for a marker; never count `..` hops. The answer has to be
# the same from the repo root, from this directory and from a copied sandbox.
ROOT_DIR="$DIR"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/VERSION" ]; do
  ROOT_DIR="$(dirname "$ROOT_DIR")"
done
CALLER="$ROOT_DIR/core/scripts/validate-gate-adjudication.sh"
SIBLING="$ROOT_DIR/core/scripts/validate-suppression-lifetime.sh"
CONVERGENCE="$ROOT_DIR/core/scripts/validate-adversarial-convergence.sh"
FIXTURE="$ROOT_DIR/core/fixtures/gate-adjudication"
SCHEMA="$ROOT_DIR/core/schemas/gate-adjudication-verdict.json"
MAP="$ROOT_DIR/core/skills/ai-dlc/enforcement-map.yaml"

for p in "$CALLER" "$SIBLING" "$CONVERGENCE" "$SCHEMA" "$MAP" \
         "$FIXTURE/run.sh" "$FIXTURE/seed.sh"; do
  if [ ! -f "$p" ]; then
    echo "FIXTURE BROKEN: cannot locate $p from $DIR (root resolved to $ROOT_DIR)"
    exit 1
  fi
done
# Print the resolved subjects. A mutation applied to a file the run never loads leaves every
# arm green, and `cmp -s` does not catch it — the mutation applied cleanly, to the wrong copy.
# The path is the only thing that says which file was actually scored. TWO subjects here, and
# that is the whole reason it matters: the predicate lives in the sibling and the join lives in
# the caller, so a battery that mutated only one of them would prove half a fix.
echo "caller:   $CALLER"
echo "sibling:  $SIBLING"
echo "fixture:  $FIXTURE/run.sh"

FAILURES=0
SCORED=0
note_fail() { echo "FAIL: $*"; FAILURES=$((FAILURES + 1)); }

# --------------------------------------------------------------------------
# Sandbox. The fixture resolves its validator as `$HERE/../../../core/scripts/…`, the
# validator resolves ITS root by walking up for `core/skills/ai-dlc`, and the carve-out
# resolves the sibling beside itself. The sandbox reproduces exactly that shape, so the
# resolution the fixture performs in the sandbox is the resolution it performs in the repo — a
# battery whose sandbox resolves differently scores a program nobody runs.
# --------------------------------------------------------------------------
build_sandbox() {          # prints the sandbox root
  local sb; sb="$(mktemp -d)"
  mkdir -p "$sb/core/scripts" "$sb/core/schemas" "$sb/core/skills/ai-dlc" \
           "$sb/core/fixtures/gate-adjudication"
  cp "$CALLER" "$SIBLING" "$CONVERGENCE" "$sb/core/scripts/"
  cp "$SCHEMA"  "$sb/core/schemas/"
  cp "$MAP"     "$sb/core/skills/ai-dlc/"
  cp "$FIXTURE/run.sh" "$FIXTURE/seed.sh" "$sb/core/fixtures/gate-adjudication/"
  printf '%s\n' "$sb"
}

# Apply one literal, exact-count replacement. Python and not sed: the targets carry `(`, `)`,
# `[`, `]`, `$`, `"` and `*`, every one of which means something different in BRE than in ERE,
# and a BSD sed whose expression matched nothing exits 0. A literal replace with an asserted
# occurrence COUNT cannot half-apply and cannot silently no-op.
mutate() {                 # $1 src  $2 dest  $3 old  $4 new  ($3 empty -> whole-file stub)
  local src="$1" dest="$2" old="$3" new="$4"
  if [ -z "$old" ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$dest"
    return 0
  fi
  OLD="$old" NEW="$new" python3 - "$src" "$dest" <<'PY'
import os, sys
src, dest = sys.argv[1], sys.argv[2]
old, new = os.environ["OLD"], os.environ["NEW"]
t = open(src, encoding="utf-8").read()
n = t.count(old)
if n != 1:
    sys.stderr.write("ANCHOR MATCHED %d TIMES, EXPECTED 1\n" % n)
    sys.exit(3)
open(dest, "w", encoding="utf-8").write(t.replace(old, new))
PY
}

# $1 label  $2 target basename under core/scripts/  $3 expected-dead SET, space separated
# ('' = control, must stay green; 'ANY' = at least one, used only where the mutation removes
# the program)  $4 old  $5 new  $6 why
#
# THE SET IS COMPARED FOR EQUALITY, not membership. A mutant that also kills a case it does not
# own has an entangled assertion somewhere, and a mutant scored on membership alone hides that:
# it goes green whether it killed one case or all of them. Where an overlap is structural —
# m1 removes the carve-out's INPUT, so every case asserting the carve-out fired notices — the
# set names all of them and the equality still holds.
score() {
  local label="$1" target="$2" dead="$3" old="$4" new="$5" why="$6"
  local sb out rc got want nlab nrow
  SCORED=$((SCORED + 1))
  sb="$(build_sandbox)"
  if ! mutate "$ROOT_DIR/core/scripts/$target" "$sb/core/scripts/$target" "$old" "$new"; then
    note_fail "$label: the mutation did not apply — its anchor is not in $target, or is in it
  more than once. The battery cannot score a mutant it did not build, and an unapplied
  mutation produces a green run that reads exactly like a surviving arm."
    rm -rf "$sb"; return
  fi
  # A mutation that changed no bytes is the same failure wearing a different hat.
  if [ -n "$old" ] && cmp -s "$ROOT_DIR/core/scripts/$target" "$sb/core/scripts/$target"; then
    note_fail "$label: the mutated copy of $target is byte-identical to the subject."
    rm -rf "$sb"; return
  fi
  out="$(bash "$sb/core/fixtures/gate-adjudication/run.sh" 2>&1)"; rc=$?
  rm -rf "$sb"

  if [ -z "$dead" ]; then
    # THE CONTROL, AND IT CARRIES A POSITIVE CONJUNCT. rc=0 with no output is what a subject
    # replaced by `exit 0` looks like too, so "nothing went wrong" is not the assertion — the
    # fixture's own S1 row, the one that demands the SUPPRESSED line, must be THERE.
    if [ "$rc" -ne 0 ] || ! grep -q '^gate-adjudication: PASS' <<<"$out" \
       || ! grep -q '^  ok    S1: ' <<<"$out"; then
      note_fail "$label: a copy declared INERT did not pass, or passed without S1 asserting the
  SUPPRESSED line. For the unmutated control that makes every kill below unattributable — the
  battery may be scoring a broken harness rather than a mutation. For a mutation declared inert
  it is the stronger reading: the edit was NOT behaviour-preserving after all, and whichever
  case went red is telling you what the property really was.
  rc=$rc
  $out"
    fi
    return
  fi

  if [ "$rc" -eq 0 ]; then
    note_fail "$label SURVIVED. $why
  The fixture passed against a subject with that property removed, so no assertion in it is
  watching the line the mutation edited."
    return
  fi
  # Which cases died, derived from the fixture's own failure rows. Never piped into a
  # first-match reader: under pipefail a `grep -q` that leaves early answers with the writer's
  # EPIPE and reports NOT-FOUND on input that contains the pattern.
  got="$(sed -n 's/^  FAIL  \([A-Za-z0-9][A-Za-z0-9-]*\):.*/\1/p' <<<"$out" | sort -u | tr '\n' ' ')"
  got="${got% }"
  # An UNLABELLED failure row is one of the fixture's older arms going red, which no mutant
  # here has any business touching. Counting rows against labels is what makes that visible;
  # the label-derived set alone would silently drop it.
  nrow="$(grep -c '^  FAIL  ' <<<"$out")" || nrow=0
  nlab="$(sed -n 's/^  FAIL  \([A-Za-z0-9][A-Za-z0-9-]*\):.*/\1/p' <<<"$out" | grep -c .)" || nlab=0
  if [ "$dead" = "ANY" ]; then
    if [ "$nrow" -eq 0 ]; then
      note_fail "$label went red with no case-level failure row, so the fixture died for a
  reason it cannot name — most likely FIXTURE BROKEN rather than a kill. $why
  fixture said: $out"
    fi
    return
  fi
  # NOPASS is the weaker verdict, and it is used in exactly one place: where the mutation
  # removes the program the SEED derives its input from, so the fixture cannot build a case to
  # fail. "Did not report PASS" is all that is available there, and it is stated as such rather
  # than dressed up as a kill.
  if [ "$dead" = "NOPASS" ]; then
    if grep -q '^gate-adjudication: PASS' <<<"$out"; then
      note_fail "$label reported PASS. $why
  fixture said: $out"
    fi
    return
  fi
  if [ "$nrow" -ne "$nlab" ]; then
    note_fail "$label produced $nrow failure row(s) but only $nlab carry a case label, so at
  least one arm that predates the carve-out went red. A mutant that disturbs an unrelated
  assertion has not established the one it claims. $why
  fixture said: $out"
    return
  fi
  want="$(tr ' ' '\n' <<<"$dead" | sort -u | tr '\n' ' ')"; want="${want% }"
  if [ "$got" != "$want" ]; then
    note_fail "$label killed [$got], expected exactly [$want] — so either it was killed by an
  assertion other than the one that owns this property, or it reached a case it has no business
  reaching and that case's assertion is entangled. $why
  fixture said: $out"
  fi
}

# --------------------------------------------------------------------------
# M0 — the unmutated control. A trailing space on a shell assignment: different bytes, same
# program. If this does not pass, nothing below is attributable.
# --------------------------------------------------------------------------
score "M0 control (unmutated)" validate-gate-adjudication.sh "" \
  'GA_IN_FORCE_STATUS="not-asked"' \
  'GA_IN_FORCE_STATUS="not-asked" ' \
  ""

# --------------------------------------------------------------------------
# m1 — the caller never asks the sibling. The rows arrive empty while the STATUS still reads
# `ok:`, which is the pre-fix validator with the plumbing left in: every FAIL blocks and the
# block text offers no reason, because as far as the caller knows there was nothing to apply.
# --------------------------------------------------------------------------
score "m1 caller never asks the sibling (rows blanked)" validate-gate-adjudication.sh \
  "S1 S2b S6-idonly S13" \
  '        if [ "$supp_rc" -eq 0 ]; then
            GA_IN_FORCE_STATUS="ok:$ESC"' \
  '        if [ "$supp_rc" -eq 0 ]; then
            GA_IN_FORCE=""
            GA_IN_FORCE_STATUS="ok:$ESC"' \
  "The carve-out has no input, so a FAIL under a well-formed in-force suppression blocks
  exactly as it did before the fix. FOUR cases are named because the mutation removes the
  carve-out's INPUT rather than a property of the join: S1, S2b, S6-idonly and S13 are the four
  that assert it FIRED. Every case that asserts it did NOT fire is unaffected, which is the
  point — those cases cannot tell this validator from the fixed one on their own, and that is
  what the rest of this battery is for."

# --------------------------------------------------------------------------
# m2 — the catalog compare dropped. The join keys on the check id alone, which is the shape
# anyone writes first: `if cid in suppressed_ids`. Check ids are per-catalog and collide by
# design, so this makes an extension's suppression an authorization against core's gate.
# --------------------------------------------------------------------------
score "m2 caller keys on the check id alone" validate-gate-adjudication.sh \
  "S6-mismatch S9 S12" \
  '    hit = in_force.get((catalog, cid))
    if hit:' \
  '    hit = (in_force.get((catalog, cid))
           or next((v for (c, i), v in in_force.items() if i == cid), None))
    if hit:' \
  "An entry filed under [extension:foo] now covers core's check of the same id, a core entry
  covers an extension's verdict, and a bare id covers both. THREE cases because the mutation
  deletes the comparison itself rather than one direction of it — every case whose two catalogs
  disagree is acquitted at once, and a join tested from one side only reads as working while
  comparing nothing."

# --------------------------------------------------------------------------
# m3 — the SIBLING's lifetime test always passes. The entry stays listed forever, so
# `**Expires after:**` becomes decorative and a suppression is an OVERRIDDEN with a new name.
# Mutated in the sibling, not the caller, because that is where "in force" is defined; a fix
# that re-implemented the lifetime in the caller would survive this and is exactly the
# restatement the design avoids.
# --------------------------------------------------------------------------
score "m3 sibling's lifetime test always true" validate-suppression-lifetime.sh \
  "S3" \
  '        if [ "$elapsed" -le "$expires" ]; then' \
  '        if [ "$elapsed" -le "$expires" ] || [ 1 -eq 1 ]; then' \
  "An expired suppression is listed as in force, so the gate adopts it. Only S3 can see this:
  every other case's entry is either inside its lifetime already or excluded for a different
  reason, which is what makes S3 the owner rather than a duplicate."

# --------------------------------------------------------------------------
# m4 — the SIBLING stops excluding a malformed entry from the in-force list. The shape
# diagnostic is still printed, which is the trap: the run LOOKS identical on stderr and the
# entry is now listed. An entry with no operator citation is not an authorization, and the one
# case that can tell is S4.
# --------------------------------------------------------------------------
score "m4 sibling lists a malformed entry in --in-force" validate-suppression-lifetime.sh \
  "S4" \
  '        echo "      expire, and what make the expiry checkable." >&2
        continue' \
  '        echo "      expire, and what make the expiry checkable." >&2
        [ "$IN_FORCE" -eq 1 ] || continue' \
  "A SUPPRESSED entry missing **Operator authorization:** is listed and the gate adopts it, so
  an operator citation stops being what makes a suppression one. S5 is deliberately NOT in this
  set: its entry never reaches the shape check at all, because its status token is
  DECIDED_AUTONOMOUSLY and the case branches on status. Two different exclusions, one case
  each — if both died here they would be one assertion written twice."

# --------------------------------------------------------------------------
# m5 — the fail-closed default inverted. When the escalations file cannot be read, every FAIL
# is treated as covered. This is the direction that is invisible in normal operation: on a tree
# with a readable pending.md the mutant and the fix are the same program.
# --------------------------------------------------------------------------
score "m5 caller fails OPEN when the sibling cannot be asked" validate-gate-adjudication.sh \
  "S7" \
  '    hit = in_force.get((catalog, cid))
    if hit:' \
  '    hit = (in_force.get((catalog, cid))
           or (None if in_force_status.startswith("ok:") else ("?", "?", "(unreadable)")))
    if hit:' \
  "A missing escalations file becomes a blanket authorization, so deleting pending.md is a way
  to pass any gate. Fail-closed is asserted by S7 alone; every other case supplies a readable
  file and cannot distinguish the two programs."

# --------------------------------------------------------------------------
# m6 — the check id matched by prefix. `cid.startswith(entry_id)` is what a hand-written join
# degenerates into when the ids are strings and somebody has been bitten by a type mismatch.
# One short suppression then covers every longer id that begins with it.
# --------------------------------------------------------------------------
score "m6 caller matches the check id by prefix" validate-gate-adjudication.sh \
  "S11" \
  '    hit = in_force.get((catalog, cid))
    if hit:' \
  '    hit = (in_force.get((catalog, cid))
           or next((v for (c, i), v in in_force.items()
                    if cid.startswith(i) and c == catalog), None))
    if hit:' \
  "An entry naming the one-character check now covers every escalated check whose id starts
  with it. S11 is the only case whose two ids stand in that relation, and the seed DERIVES that
  pair from the escalated set rather than naming it, so a map that renumbers cannot leave this
  arm pointing at a pair with no prefix relation."

# --------------------------------------------------------------------------
# m7 — the empty catalog restored as a WILDCARD. This is the first cut of the fix, and it is
# the mutation that looks like a widening rather than a hole: a row with no bracket matched on
# the id alone, on the reading that the bracket is optional. It is not a widening — it makes a
# DROPPED required field buy coverage that writing the field correctly could never buy. Both
# lines are replaced in one anchor because either alone leaves a program neither cut intended.
# --------------------------------------------------------------------------
score "m7 caller reads an empty catalog as EVERY catalog" validate-gate-adjudication.sh \
  "S12" \
  '    in_force.setdefault((cat or "core", cid_s), (expires, elapsed, header))
catalog = str(V.get("catalog", ""))
suppressed = []
blocking = []
for cid in fails:
    hit = in_force.get((catalog, cid))' \
  '    in_force.setdefault((cat, cid_s), (expires, elapsed, header))
catalog = str(V.get("catalog", ""))
suppressed = []
blocking = []
for cid in fails:
    hit = in_force.get((catalog, cid)) or in_force.get(("", cid))' \
  "A **Suppresses:** line written without its bracket now covers that id in EVERY catalog.
  S6-idonly still passes and must — the bare id against a core verdict is legitimate — so this
  mutant is invisible to every case except S12, which is the whole reason S12 exists."

# --------------------------------------------------------------------------
# m8 — the SIBLING refuses the whole FILE when any entry drew a diagnostic. The strict reading
# of "--in-force never exits 1", inverted: one malformed entry anywhere in pending.md and the
# caller sees a refusal, so a well-formed suppression somewhere else in the same file covers
# nothing. A consumer's pending.md is hundreds of entries long and always has a bad one.
# --------------------------------------------------------------------------
score "m8 sibling refuses the file when any entry drew a diagnostic" \
  validate-suppression-lifetime.sh "S13" \
  'if [ "$IN_FORCE" -eq 1 ]; then
  echo "IN-FORCE: entries_scanned=' \
  'if [ "$IN_FORCE" -eq 1 ]; then
  [ "$bad" -eq 0 ] || exit 1
  echo "IN-FORCE: entries_scanned=' \
  "One malformed entry withdraws every other entry's authorization. S13 is the only case whose
  file holds more than one entry, and that is exactly what makes it the owner: S4 and S5 hold a
  malformed entry ALONE, so for them 'this entry is excluded' and 'this file is refused' have
  the same observable and neither can separate the two implementations."

# --------------------------------------------------------------------------
# m9 — the caller captures the sibling's STDERR into its rows. It was declared inert and it is
# NOT, and the shape of the kill is the finding: the ROW PARSER is exactly as tolerant as
# intended — S1, S2b, S6-idonly survive and S13 still exits 0, so a stderr line with fewer than
# five tab fields never became a row and no coverage decision moved. What the redirection
# destroys is the OPERATOR'S EXPLANATION: every diagnostic the sibling wrote about why an entry
# did not count is swallowed into a variable and never reaches the gate's stderr. Nine cases
# notice, and each one notices through its TOKEN rather than its exit code — which is the
# clearest evidence available that the presence checks are doing work the exit codes cannot.
# --------------------------------------------------------------------------
score "m9 caller folds the sibling's stderr into its rows" \
  validate-gate-adjudication.sh \
  "S3 S4 S5 S6-mismatch S8 S9 S11 S12 S13" \
  '            GA_IN_FORCE="$(bash "$SUPP_DIR/validate-suppression-lifetime.sh" --in-force \
                --escalations "$ESC" --enforcement-map "$MAP" --gate-metrics "$AI_DLC_GATE_METRICS")"' \
  '            GA_IN_FORCE="$(bash "$SUPP_DIR/validate-suppression-lifetime.sh" --in-force \
                --escalations "$ESC" --enforcement-map "$MAP" --gate-metrics "$AI_DLC_GATE_METRICS" 2>&1)"' \
  "The sibling's reasons stopped reaching the operator. A lead leaning on a suppression that
  did not count would see the block and no explanation of why the entry was excluded. If
  instead a COVERAGE case (S1, S2b, S6-idonly) is in the kill set, the reading is the opposite
  one and worse: a stderr line became a ROW, and the parser's five-field guard is not holding."

# --------------------------------------------------------------------------
# m10 — the SIBLING emits nothing. The question `.claude/rules/fixture-mutants.md` puts to every
# new arm: would this pass against a program that never ran? Eleven of the fifteen carve-out
# cases expect exit 1, which is exactly what a gate gets when the predicate it asks is a stub —
# so on exit codes alone this mutant would score eleven survivals. The set below is the answer:
# it is twelve cases wide because every one of them demands a TOKEN the sibling is the only
# source of (`in_force=`, the malformed diagnostic, the misclassified-fields diagnostic, the
# terminal-naming diagnostic, the SUPPRESSED line the rows produce). S2, S7 and S10 survive and
# should: S2 and S10 assert the carve-out stayed OUT of the way, and S7's absent file means the
# sibling is never invoked at all.
# --------------------------------------------------------------------------
score "m10 sibling replaced by 'exit 0'" validate-suppression-lifetime.sh \
  "S1 S2b S3 S4 S5 S6-idonly S6-mismatch S8 S9 S11 S12 S13" "" "" \
  "A sibling that emits nothing and exits 0 satisfied a case, which means that case is
  asserting an ABSENCE and would certify a predicate that never ran."

# --------------------------------------------------------------------------
# m11 — the CALLER emits nothing. Scored NOPASS and not as a kill, deliberately. The fixture
# derives its entire input from this program: seed.sh calls `--expected` to build the verdict
# and to derive the three check ids the entries name. A caller replaced by `exit 0` therefore
# leaves the seed with an empty escalated set and the fixture cannot construct a case at all —
# it reports FIXTURE ERROR before any arm runs. That is the honest outcome and it is still the
# answer to the question ("no, it does not pass"), but calling it a kill would credit an
# assertion that never executed.
# --------------------------------------------------------------------------
score "m11 caller replaced by 'exit 0'" validate-gate-adjudication.sh NOPASS "" "" \
  "A validator that emits nothing and exits 0 was reported as PASS by the fixture, which means
  the fixture would certify a program that never ran."

# --------------------------------------------------------------------------
# The kill count itself. A battery whose mutants all applied and killed nothing reports zero
# failures, which is byte-identical to a battery that worked.
# --------------------------------------------------------------------------
if [ "$SCORED" -lt 12 ]; then
  note_fail "only $SCORED mutant(s) were scored; this battery declares 12. A mutant that never
  ran cannot have been survived or killed."
fi

if [ "$FAILURES" -eq 0 ]; then
  echo "ok: gate-adjudication-mutants — $SCORED mutant(s) scored across both subjects; the"
  echo "    unmutated control passes with S1's SUPPRESSED line present, and removing the"
  echo "    sibling's rows, the catalog compare, the lifetime test, the malformed-shape"
  echo "    exclusion, the fail-closed default, the exact-id match, the empty-catalog rule,"
  echo "    the per-ENTRY exclusion, the sibling's stderr channel, or either script itself"
  echo "    each kills exactly the case set that owns that property."
  exit 0
fi
echo "FAILED: gate-adjudication-mutants — $FAILURES finding(s) across $SCORED mutant(s)"
exit 1
