#!/usr/bin/env bash
# layer-reference-resolution — W7, W9, and the form E15 states its remedy in.
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
# W9 — THE THIRD CITATION NAMESPACE, added at contract_version 12 and found the same way: by
# measuring the reference consumer rather than by reading the code. W3 resolves `Step <n>` and
# W7 resolves `Check <n>`; nothing asked the question of the EXECUTABLES an entry tells a
# dispatched agent to run. Two entries there name a script that has never existed in that
# repository's history — a bare command in a step's own command list, and a `Required:` clause
# in a role file — and an agent following either runs nothing.
#
# ITS FOUR SILENT CASES ARE FOUR DIFFERENT REASONS, which is why there is one mutant each:
#
#   scripts/present.sh          the file resolves          -> the arm has something to be quiet about
#   scripts/fenced-missing.sh   inside a fenced block      -> I68's defect, and the skip's stated cost
#   core/scripts/…              not root-relative          -> resolved against the wrong root otherwise
#   extensions/README.md        not a layer entry          -> layer_files() drops it by name
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
# 3 premises + 3 W9 premises + 1 pristine vector + 2 applicability + 1 code-attribution
# + 1 crosswalk-is-load-bearing + 1 exit condition + 9 mutants + 1 unmutated control.
# + 1 W12 premise + 8 W12 mutants
EXPECTED_ASSERTIONS=31

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

# --- W9's premises. Same rule: read out of the seed, never back through the arm. ----------
# The SILENT cell has to be silent for the right reason. If `scripts/present.sh` were absent
# from the seed, `w9ok=-` would mean "the arm did not look" and would read identically.
[ -f "$CONS/scripts/present.sh" ] \
  && ok "premise: scripts/present.sh EXISTS in the seed, so its silent cell is a resolution" \
  || bad "premise BROKEN: scripts/present.sh is not in the seed — its silent cell proves nothing"

# And the REPORTED cell's subject has to be genuinely absent, or the report is the defect.
[ ! -e "$CONS/scripts/missing-tool.sh" ] \
  && ok "premise: scripts/missing-tool.sh is absent from the seed, so its reported cell is a finding" \
  || bad "premise BROKEN: scripts/missing-tool.sh EXISTS — W9 reporting it would be the false positive"

# The fenced case must actually be fenced. A seed that put the path outside a fence would make
# the fence-skip mutant unkillable while every line still read green.
awk '/^[[:space:]]*```/ { f = 1 - f; next } f && /scripts\/fenced-missing\.sh/ { hit = 1 } END { exit hit ? 0 : 1 }' "$DOMAIN" \
  && ok "premise: scripts/fenced-missing.sh sits INSIDE a fenced block in the seed" \
  || bad "premise BROKEN: scripts/fenced-missing.sh is not inside a fence — the fence mutant cannot fire"

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
  # W9 — the script-citation namespace. Three subjects that must report and four that must
  # not, and each silent cell is silent for a DIFFERENT reason: the file resolves, the path
  # is fenced, the path is not root-relative, the file is not an entry.
  v="$v w9miss=$(grep -q 'roles/dev.md: names `scripts/missing-tool.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9dot=$(grep -q 'roles/dev.md: names `scripts/dot-slash-missing.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9ovr=$(grep -q 'overrides/gate-validation__8.md: names `scripts/override-missing.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9ok=$(grep -q 'names `scripts/present.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9fence=$(grep -q 'names `scripts/fenced-missing.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9dist=$(grep -q 'dist-only-missing.sh' <<<"$out" && echo W || echo -)"
  v="$v w9rdme=$(grep -q 'names `scripts/readme-missing.sh`' <<<"$out" && echo W || echo -)"
  # W12 — the citation that RESOLVES and still names the wrong check. Every silent cell here
  # is silent for a different reason, which is what the six mutants below take apart. The
  # grammar is `cites`, never `references`: W7's message uses the other verb on the same ids,
  # and a cell keyed on the id alone would score W7's finding as this arm's.
  v="$v w12t26=$(grep -q 'cites \"Check 26\"' <<<"$out" && echo W || echo -)"
  v="$v w12g24=$(grep -q 'cites \"Check 24\"' <<<"$out" && echo W || echo -)"
  v="$v w12q17=$(grep -q 'cites \"Check 17\"' <<<"$out" && echo W || echo -)"
  v="$v w12w19b=$(grep -q 'cites \"Check 19b\"' <<<"$out" && echo W || echo -)"
  v="$v w12x34=$(grep -q 'cites \"Check 34\"' <<<"$out" && echo W || echo -)"
  v="$v w12n8=$(grep -q 'cites \"Check 8\"' <<<"$out" && echo W || echo -)"
  v="$v w12p20=$(grep -q 'cites \"Check 20\"' <<<"$out" && echo W || echo -)"
  # The AMBIGUOUS bucket is not a warning, so it cannot be read off the default output. It is
  # a POSITIVE assertion on the listing: a count alone would be satisfied by two rows that are
  # not the two seeded, and the bare-stem case is the one this fixture exists to pin.
  # I54, and it bit here before it was spotted: `grep -q` leaves at its first match, the
  # writer takes the EPIPE, and under `set -o pipefail` the pipeline reports NOT-FOUND on
  # input that contains the pattern. The count cell survived it only because `grep -c` reads
  # to EOF. Run once, capture, and feed both readers a here-string.
  local refs_out
  refs_out="$(bash "$1" "$2" --check-refs 2>&1)"
  v="$v w12amb=$(grep -c '^  ambiguous ' <<<"$refs_out")"
  v="$v w12stem=$(grep -q 'ambiguous.*"Check 30"' <<<"$refs_out" && echo A || echo -)"
  # THE RESTRAINT HALF of the crosswalk rule: a corroborating row removes the EXEMPTION and
  # must not PROMOTE. Asserted on the listing, positively, because "no warning for Check 26"
  # is also what a stood-down subject looks like.
  v="$v w12x26amb=$(grep -q 'ambiguous.*"Check 26"' <<<"$refs_out" && echo A || echo -)"
  # THE COUNT LINE ITSELF. Its whole job is to stop a reader inferring "N genuinely
  # undecidable" from N, so the caveat is the payload and not decoration — a note that keeps
  # the number and loses the sentence is the failure this cell exists to catch.
  v="$v w12note=$(grep -q 'UNADJUDICATED is not UNDECIDABLE' <<<"$out" && echo N || echo -)"
  printf '%s' "$v"
}

W9WANT='w9miss=W w9dot=W w9ovr=W w9ok=- w9fence=- w9dist=- w9rdme=-'
W12WANT='w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=3 w12stem=A w12x26amb=A w12note=N'
WANT="d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT $W12WANT"

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

# The finding NAMES ITS CLAUSE. I64's whole point: a code that reaches only a comment satisfies
# a whole-file grep while no run can attribute a line to it. The vector above matches on message
# text, so it would score green for an arm that emitted the right subjects under the wrong code.
grep -qE '^WARN[[:space:]]+W9[[:space:]]' <<<"$out" \
  && ok "the script-citation findings are emitted under the code W9, so a run can attribute them" \
  || bad "no emitted line carries the code W9 — the subjects report but name no clause"

# --- Part 3: the crosswalk join is load-bearing, proven by removing the row ---------------
# Not a mutation of the code: a mutation of the CONSUMER, which is the operator action the
# clause describes. Removing the row must make the resolved citation reappear.
cp "$CROSSWALK" "$ROOT/crosswalk.orig"
grep -v '^| 34 |' "$CROSSWALK" > "$CROSSWALK.tmp" && mv "$CROSSWALK.tmp" "$CROSSWALK"
if cmp -s "$ROOT/crosswalk.orig" "$CROSSWALK"; then
  bad "fixture BROKEN: removing the 34 crosswalk row changed nothing"
else
  got="$(vector "$LINTER" "$CONS")"
  [ "$got" = "d19b=W r19b=W r11b=W c34=W c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT $W12WANT" ] \
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
[ "$got" = "d19b=- r19b=- r11b=- c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT $W12WANT" ] \
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
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=BAD dotform=OK $W9WANT $W12WANT"

# M2 — drop the BARE half of the crosswalk join. Only the bare-row citation moves.
# The first cut of this fixture had one mutant for the whole join and seeded only a bare row,
# so deleting the namespaced branch changed a line and changed no verdict: it passed `cmp -s`
# and proved nothing. Two rows, two mutants, one cell each.
mk_mutant no-crosswalk-bare \
  "/grep -Fxq -- \"\\\$ref\" <<<\"\\\$CROSSWALK_IDS\" && continue/d" \
  "d19b=W r19b=W r11b=W c34=W c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT $W12WANT"

# M2b — drop the NAMESPACED half. Only the namespaced-row citation moves.
mk_mutant no-crosswalk-namespaced \
  "/grep -Fxq -- \"Check \\\$ref\" <<<\"\\\$CROSSWALK_IDS\" && continue/d" \
  "d19b=W r19b=W r11b=W c34=- c12=W c7=- alpha=- apform=OK dotform=OK $W9WANT $W12WANT"

# M3 — widen the grammar to alphabetic ids. Only the placeholders move.
mk_mutant alphabetic-grammar \
  "s/grep -Eoh 'Check\[ -\]\[0-9\]\+\[a-z-\]\*'/grep -Eoh 'Check[ -][0-9A-Z]+[a-z-]*'/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=W apform=OK dotform=OK $W9WANT $W12WANT"

# M4 — drop the rulebook resolve. Only core's own check moves.
mk_mutant no-anchor-resolve \
  "/grep -Fxq -- \"\\\$ref\" <<<\"\\\$GLOBAL_CHECK_ANCHORS\" && continue/d" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=W alpha=- apform=OK dotform=OK $W9WANT $W12WANT"

# --- W9's mutants. One per narrowing, and each narrowing exists for a measured reason. ----
# The arm is four decisions, not one: skip fences, normalise `./`, require the path to be
# root-relative, and read overrides as well as extensions. A single mutant over the whole arm
# would go red for any of them and identify none.

# M5 — stop skipping fenced blocks. Only the fenced path moves. This is I68's defect exactly:
# a reader that does not skip fences turns a worked example into a finding.
mk_mutant w9-no-fence-skip \
  "/^[[:space:]]+fence \{ next \}$/d" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK w9miss=W w9dot=W w9ovr=W w9ok=- w9fence=W w9dist=- w9rdme=- $W12WANT"

# M6 — stop normalising the leading `./`. Only the dot-slash path moves, and it goes SILENT:
# the reference consumer's live subject is written in exactly this form, in a step's own
# command list, so without this line the arm misses the case that motivated it.
mk_mutant w9-no-dotslash \
  "/, \"\", t\)/d" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK w9miss=W w9dot=- w9ovr=W w9ok=- w9fence=- w9dist=- w9rdme=- $W12WANT"

# M7 — stop requiring the token to be root-relative. Only the distribution-form path moves.
# Unanchored, the arm resolves a path written against the distribution's layout against the
# CONSUMER's root, where it correctly does not exist — a finding manufactured by the grammar.
mk_mutant w9-no-root-anchor \
  "s/if \(t ~ [^)]*\) print t/print t/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK w9miss=W w9dot=W w9ovr=W w9ok=- w9fence=- w9dist=W w9rdme=- $W12WANT"

# M8 — narrow the subject set to extensions/. Only the override's citation moves, and it goes
# silent: an arm that walked one of the two layer directories would print the same clean line
# on a tree whose overrides tell an agent to run a file that is not there.
mk_mutant w9-extensions-only \
  "s/\{ layer_files \"\\\$EXT_DIR\"; layer_files \"\\\$OVR_DIR\"; \}/layer_files \"\\\$EXT_DIR\"/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK w9miss=W w9dot=W w9ovr=- w9ok=- w9fence=- w9dist=- w9rdme=- $W12WANT"

# --- W12 (LC-R5) ------------------------------------------------------------------------
# THE PREMISE, read out of the seed rather than through the arm. The false-positive pin only
# pins something if the same lowercase-with-digit token really is on both sides.
grep -q 'gate-1 only' "$DOMAIN" && grep -q 'gate-1 is active (Check 20)' "$CONS/.claude/skills/ai-dlc/extensions/roles/dev.md" \
  && ok "premise: 'gate-1' appears in the 920 heading AND on the Check 20 citation line" \
  || bad "premise BROKEN: the gate-1 false-positive pin has no subject on one side or the other"

# M10 — the title-join off. Only the titled citation moves; the tag-join one is untouched,
# which is what makes these two signals rather than one written twice.
mk_mutant w12-title-off \
  "s/verdict=\"title\"/verdict=\"ambiguous\"/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT w12t26=- w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N"

# M11 — the tag-join off. The mirror of M10, and the count moves because a demoted FINDING
# lands in AMBIGUOUS rather than vanishing: this arm never drops a subject, it re-tiers it.
mk_mutant w12-tag-off \
  "s/verdict=\"tag\"/verdict=\"ambiguous\"/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT w12t26=W w12g24=- w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N"

# M12 — drop the UPPERCASE half of the provenance-token filter. `gate-1` becomes a token, the
# 920 heading and the Check 20 citation line share it, and the arm reports a mislabel on a
# citation nothing is wrong with. This is the measured false positive, armed as a mutant so
# the filter cannot be simplified back out.
mk_mutant w12-token-loose \
  "s/\\| grep -E '\\[A-Z\\]' \\| grep -E '\\[0-9\\]'/| grep -E '[0-9]'/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=W w12amb=2 w12stem=A w12x26amb=A w12note=N"

# M13 — accept a bare `gate-validation` stem as a core qualifier, which is the signal the
# reference consumer originally proposed. The bare-stem row leaves AMBIGUOUS and goes silent —
# and that consumer adjudicated that exact row as a real mislabel. A false QUIET, on demand.
mk_mutant w12-stem-quiet \
  "s/gate-validation\\\\\\.md\\)\\[/gate-validation)[/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=2 w12stem=- w12x26amb=A w12note=N"

# M14 — drop the stand-down for a citation core does not define. W7 already reports those as
# dangling; without this gate both arms fire on one subject and one of them is vacuous.
mk_mutant w12-core-gate-off \
  "s/\\[ -n \"\\\$ctitle\" \\] \\|\\| continue/: ; #/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=7 w12stem=A w12x26amb=A w12note=N"

# M15 — drop the crosswalk stand-down. `Check 34` is resolved by the row that exists for
# exactly that purpose, so reporting it is the arm firing on its own contract remedy. This is
# the load-bearing silent case W7 already has, in the second namespace.
# M15 — delete the crosswalk gate entirely. `Check 22` carries a row whose title is nothing
# like this project's 922, so the row genuinely does license the citation and the clause must
# stay silent; without the gate it lands in AMBIGUOUS. That subject exists only because the
# corroboration split created a second branch — before it, "a non-corroborating row exempts"
# had nothing in the seed that could exercise it, which is a clause nobody could have caught
# breaking.
#
# ANCHORED ON THIS ARM'S OWN INDENT. W7 carries a byte-identical crosswalk line four spaces
# in; a mutation keyed on the text alone edits both and flips a W7 cell, which is a kill
# scored by the wrong arm. Measured here, on the first run of this mutant.
mk_mutant w12-crosswalk-off \
  "s/^      if grep -Fxq -- \"\\\$ref\" <<<\"\\\$CROSSWALK_IDS\"/      if false/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N"

# M16 — restore the UNCONDITIONAL crosswalk stand-down that shipped in v0.390.0, by making
# the corroboration test never fire. The seed's `26` row is a `(label adoption)` row whose own
# title IS this project's 926 title, so under the old rule one row silences a title-join
# FINDING and an AMBIGUOUS row together, before any signal is evaluated. That is the defect
# the reference consumer found by running the shipped arm against its own tree — not by
# review here, and not by this fixture, which did not have a corroborating row until now.
mk_mutant w12-crosswalk-unconditional \
  "s/\\[ -n \"\\\$_x\" \\] \\|\\| return 1/return 1/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT w12t26=- w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=2 w12stem=A w12x26amb=- w12note=N"

# M17 — drop the caveat from the count line, keeping the count. The number survives and the
# sentence that stops it being misread does not. This is the only arm that would catch a
# future author trimming that line for length, and the line is long on purpose: the reference
# consumer has read five of its ambiguous rows closely and all five were findings.
mk_mutant w12-note-uncaveated \
  "s/UNADJUDICATED is not UNDECIDABLE[^\\\\]*//" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=3 w12stem=A w12x26amb=A w12note=-"

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
