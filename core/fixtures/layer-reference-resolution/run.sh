#!/usr/bin/env bash
# layer-reference-resolution — W7, and the form E15 states its remedy in.
#
# BOTH MECHANISMS WERE FOUND BY RUNNING THE BAND MIGRATION, not by reading the code, and
# neither is visible from core's own tree: core has no consumer whose ids it can renumber.
#
# W7 — THE RENAME/REFERENCE JOIN. LC-N5 moves an allocation. It does not touch the prose that
# cites the old id, and nothing joined the two. On the reference consumer's migration that
# orphaned three `Check 19b` citations in three files, one of them a group heading `## Check
# 19b` sitting directly above the `### 919b.` that replaced it. W3 caught none of them — its
# grammar is `Step` — and the four dangling pointers W3 DID catch were luck of overlap.
#
# THE FOUR SILENT CASES ARE THE FIXTURE. An arm that reports the three subjects but also
# reports any of these has not passed, because each silent case is a different reason:
#
#   Check 34   a crosswalk row resolves it       -> the row's whole stated purpose
#   Check 7    core still defines it             -> core is the source of truth for its range
#   Check A    a placeholder in a worked example -> no id, no remedy, no finding
#   Check N    the same                          -> the grammar is numeric-leading for this
#
# E15's REMEDY FORM. `defined_anchors` strips the terminator so ids compare as ids, and the
# remedy re-attached a `.` to every one. Two of the reference consumer's 39 section-id subjects
# carry `—` instead (`## Check AP — …`), so for those the remedy named a string absent from the
# file: a pattern built from it matches nothing, the id stays out of band, and the edit count
# still reads right. The assertion here is APPLICABILITY — the emitted form is present in the
# file it is emitted about — because "the message changed" is not the property that failed.
#
# Usage: run.sh [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS. install.sh splits what shares a parent here: core/fixtures/ becomes
# tests/fixtures/ and core/scripts/ becomes scripts/ai-dlc/. Every candidate is rooted at this
# file's own location — I33 fails the build on a fixture that reaches a core subtree by walking
# up from a path some other resolver produced.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "${1:-}" "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh from $HERE" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
CONS="$ROOT/consumer"
DOMAIN="$CONS/.claude/skills/ai-dlc/extensions/checks/domain.md"
CROSSWALK="$CONS/.claude/skills/ai-dlc/extensions/README.md"

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

# EXPECTED_ASSERTIONS is not bookkeeping. A sibling fixture lost a whole mutant to a missing
# space in a helper call: `set -u` killed the `$( )` subshell, `if m="$( … )"` read that as a
# false branch, and the arm silently did not run — green lines and a PASS. Counting what ran is
# what closes it, and the count is a literal here or it disappears with the assertions.
# 3 premises + 1 pristine vector + 2 applicability + 1 crosswalk-is-load-bearing
# + 1 exit condition + 5 mutants + 1 unmutated control.
EXPECTED_ASSERTIONS=14

echo "layer-reference-resolution:"

# --- Part 0: the seed's premises, measured WITHOUT the code under test ------------------
# Reading these back through the arm being tested would make the premise and the finding the
# same measurement. They are read out of the seeded files directly.
grep -q '^## Check AP — ' "$DOMAIN" \
  && ok "premise: the AP heading terminates in an em-dash, not a dot" \
  || bad "premise BROKEN: no em-dash-terminated AP heading in the seed"

grep -q '^### 7\. ' "$DOMAIN" \
  && ok "premise: the 7 heading terminates in a dot" \
  || bad "premise BROKEN: no dot-terminated 7 heading in the seed"

# The group heading the migration leaves behind. It carries no terminator, so `defined_anchors`
# never harvests it and E15 never renames it — it is a CITATION as far as this file is
# concerned, which is exactly why W7 is the arm that sees it.
grep -q '^## Check 19b$' "$DOMAIN" \
  && ok "premise: the orphaned group heading '## Check 19b' is in the seed, terminator-less" \
  || bad "premise BROKEN: no terminator-less '## Check 19b' heading in the seed"

# vector <linter> <root> -> one line, one cell per case
#
# Scored as a VECTOR rather than per row: several of these cells are served by one branch, and
# per-row scoring reports entanglement on every mutant in that shape. One assertion per mutant,
# stating the complete expected vector positively.
vector() {
  local out v=''
  out="$(bash "$1" "$2" 2>&1)"
  # W7 subjects, by (file, id)
  v="d19b=$(grep -q 'checks/domain.md: references "Check 19b"' <<<"$out" && echo W || echo -)"
  v="$v r19b=$(grep -q 'roles/dev.md: references "Check 19b"' <<<"$out" && echo W || echo -)"
  v="$v r11b=$(grep -q 'roles/dev.md: references "Check 11b"' <<<"$out" && echo W || echo -)"
  v="$v c34=$(grep -q 'references "Check 34"' <<<"$out" && echo W || echo -)"
  v="$v c12=$(grep -q 'references "Check 12"' <<<"$out" && echo W || echo -)"
  v="$v c7=$(grep -q 'references "Check 7"' <<<"$out" && echo W || echo -)"
  v="$v alpha=$(grep -qE 'references "Check (A|N)"' <<<"$out" && echo W || echo -)"
  # APPLICABILITY: is the form E15 emits actually present in the file it is emitted about?
  # This is the property that failed, and it is not the same as "the message changed".
  local apf dotf
  apf="$(grep -oE "SECTION ID OUT OF BAND[^—]*— '[^']*' allocates" <<<"$out" | grep -oE "'[^']*'" | tr -d "'" | grep -E '^AP' | head -1)"
  dotf="$(grep -oE "SECTION ID OUT OF BAND[^—]*— '[^']*' allocates" <<<"$out" | grep -oE "'[^']*'" | tr -d "'" | grep -E '^7' | head -1)"
  v="$v apform=$([ -n "$apf" ] && grep -qF -- "$apf" "$DOMAIN" && echo OK || echo BAD)"
  v="$v dotform=$([ -n "$dotf" ] && grep -qF -- "$dotf" "$DOMAIN" && echo OK || echo BAD)"
  printf '%s' "$v"
}

WANT='d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK'

# --- Part 1: the pristine vector ---------------------------------------------------------
got="$(vector "$LINTER" "$CONS")"
[ "$got" = "$WANT" ] \
  && ok "pristine vector: $WANT" \
  || bad "pristine vector: got [$got] want [$WANT]"

# --- Part 2: applicability, stated as its own arm and in both directions ------------------
# The differential the release rests on: the emitted form is present in the file, and the form
# that USED to be emitted for this subject is not. Without the second half "it matches" could
# be true of a change that did nothing.
out="$(bash "$LINTER" "$CONS" 2>&1)"
apf="$(grep -oE "SECTION ID OUT OF BAND[^—]*— '[^']*' allocates" <<<"$out" | grep -oE "'[^']*'" | tr -d "'" | grep -E '^AP' | head -1)"
if [ -n "$apf" ] && grep -qF -- "$apf" "$DOMAIN"; then
  ok "the em-dash subject's emitted form [$apf] occurs in the file it is reported about"
else
  bad "the em-dash subject's emitted form [${apf:-<none>}] does NOT occur in the file"
fi
grep -qF -- 'AP.' "$DOMAIN" \
  && bad "control BROKEN: the dotted form 'AP.' is in the seed, so its absence proves nothing" \
  || ok "control: the dotted form 'AP.' occurs NOWHERE in the file — the old remedy named a string that is not there"

# --- Part 3: the crosswalk join is load-bearing, proven by removing the row ---------------
# Not a mutation of the code: a mutation of the CONSUMER, which is the operator action the
# clause describes. Removing the row must make the resolved citation reappear.
cp "$CROSSWALK" "$ROOT/crosswalk.orig"
grep -v '^| 34 |' "$CROSSWALK" > "$CROSSWALK.tmp" && mv "$CROSSWALK.tmp" "$CROSSWALK"
if cmp -s "$ROOT/crosswalk.orig" "$CROSSWALK"; then
  bad "fixture BROKEN: removing the 34 crosswalk row changed nothing"
else
  got="$(vector "$LINTER" "$CONS")"
  [ "$got" = 'd19b=W r19b=W r11b=W c34=W c12=- c7=- alpha=- apform=OK dotform=OK' ] \
    && ok "removing the 34 crosswalk row makes Check 34 dangle, and moves no other cell" \
    || bad "crosswalk row removal: got [$got]"
fi
cp "$ROOT/crosswalk.orig" "$CROSSWALK"

# --- Part 4: THE EXIT CONDITION — the standard is satisfiable ----------------------------
# Every other assertion here says an arm FIRES. None of them says the consumer can be made
# clean, and a rule an author cannot satisfy is one they turn off. The repairs below are the
# ones the messages prescribe, applied literally: repoint the two orphaned citations and add
# the row for 11b.
sed -i.bak 's/Check 19b/Check 919b/g' "$DOMAIN" "$CONS/.claude/skills/ai-dlc/extensions/roles/dev.md"
printf '| 11b | 911b | Retired, repointed |\n' >> "$CROSSWALK"
got="$(vector "$LINTER" "$CONS")"
[ "$got" = 'd19b=- r19b=- r11b=- c34=- c12=- c7=- alpha=- apform=OK dotform=OK' ] \
  && ok "exit condition: the prescribed repairs clear every W7 subject" \
  || bad "exit condition: repairs applied and W7 still reports [$got]"
git -C "$CONS" checkout -q -- . 2>/dev/null
rm -f "$DOMAIN.bak" "$CONS/.claude/skills/ai-dlc/extensions/roles/dev.md.bak"

# --- Part 5: mutants ----------------------------------------------------------------------
# Each is a COPY of the linter, never an in-place edit, guarded by `cmp -s` so a sed that
# matched nothing cannot pass as a mutation. Each asserts a complete vector distinct from every
# other mutant's, so a mutant that fails two cells is reporting entanglement rather than a kill.
mk_mutant() { # mk_mutant <label> <sed-expr> <expected-vector>
  local label="$1" expr="$2" want="$3" m out
  m="$ROOT/mutant-$label.sh"
  cp "$LINTER" "$m"
  sed -E "$expr" "$m" > "$m.new" && mv "$m.new" "$m"
  if cmp -s "$LINTER" "$m"; then
    bad "mutant $label: the sed matched NOTHING, so this arm proved nothing"
    return
  fi
  out="$(vector "$m" "$CONS")"
  [ "$out" = "$want" ] \
    && ok "mutant $label killed — vector [$out]" \
    || bad "mutant $label SURVIVED or misfired — got [$out] want [$want]"
}

# M1 — put the hardcoded dot back. Only the em-dash subject's applicability moves.
mk_mutant hardcoded-dot \
  "s/a_form=\"\\\$\(anchor_form \"\\\$f\" \"\\\$a\"\)\"/a_form=\"\\\${a}.\"/" \
  'd19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=BAD dotform=OK'

# M2 — drop the BARE half of the crosswalk join. Only the bare-row citation moves.
# The first cut of this fixture had one mutant for the whole join and seeded only a bare row,
# so deleting the namespaced branch changed a line and changed no verdict: it passed `cmp -s`
# and proved nothing. Two rows, two mutants, one cell each.
mk_mutant no-crosswalk-bare \
  "/grep -Fxq -- \"\\\$ref\" <<<\"\\\$CROSSWALK_IDS\" && continue/d" \
  'd19b=W r19b=W r11b=W c34=W c12=- c7=- alpha=- apform=OK dotform=OK'

# M2b — drop the NAMESPACED half. Only the namespaced-row citation moves.
mk_mutant no-crosswalk-namespaced \
  "/grep -Fxq -- \"Check \\\$ref\" <<<\"\\\$CROSSWALK_IDS\" && continue/d" \
  'd19b=W r19b=W r11b=W c34=- c12=W c7=- alpha=- apform=OK dotform=OK'

# M3 — widen the grammar to alphabetic ids. Only the placeholders move.
mk_mutant alphabetic-grammar \
  "s/grep -Eoh 'Check\[ -\]\[0-9\]\+\[a-z-\]\*'/grep -Eoh 'Check[ -][0-9A-Z]+[a-z-]*'/" \
  'd19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=W apform=OK dotform=OK'

# M4 — drop the rulebook resolve. Only core's own check moves.
mk_mutant no-anchor-resolve \
  "/grep -Fxq -- \"\\\$ref\" <<<\"\\\$GLOBAL_CHECK_ANCHORS\" && continue/d" \
  'd19b=W r19b=W r11b=W c34=- c12=- c7=W alpha=- apform=OK dotform=OK'

# THE UNMUTATED CONTROL, from the same directory and run last. A lone copy that dies for a
# reason unrelated to any mutation emits nothing, and "no output" otherwise scores as a kill.
cp "$LINTER" "$ROOT/mutant-control.sh"
got="$(vector "$ROOT/mutant-control.sh" "$CONS")"
[ "$got" = "$WANT" ] \
  && ok "unmutated control: an unedited copy still reports the pristine vector" \
  || bad "unmutated control: an UNEDITED copy reports [$got] — every kill above is suspect"

# --- the assertion floor ------------------------------------------------------------------
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf '  FAIL  assertion count: ran %d, expected %d — an arm did not execute\n' "$made" "$EXPECTED_ASSERTIONS"
  fails=$((fails+1))
fi

if [ "$fails" -eq 0 ]; then
  printf 'PASS  (%d assertions)\n' "$made"; exit 0
fi
printf 'FAIL  (%d of %d assertions)\n' "$fails" "$made"; exit 1
