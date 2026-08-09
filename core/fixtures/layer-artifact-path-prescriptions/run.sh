#!/usr/bin/env bash
# layer-artifact-path-prescriptions — LC-R4 / W11: an artifact path a layer entry PRESCRIBES is
# held to artifact-path-grammar.md.
#
# THE CLAUSE EXISTS BECAUSE OF A PATH THAT RESOLVED. The reference consumer reported
# `tea-consumer.md:18` as a stale path; it named the directory a story migration left behind
# while the live corpus moved under `s<N>/`. An agent following that entry reads a residue of
# earlier sprints and NOTHING FAILS — which is why no arm in this validator tests existence, and
# why this fixture writes none of the artifacts its entries name. A fixture that made a verdict
# depend on whether the file is there would be testing the check the derivation refuted (a
# resolver: 157 false positives out of 309, and it misses its own subject).
#
# THE LOAD-BEARING MUTANT IS M1, and it is why v0.332.0 shipped before this clause. There are two
# sprint-token expressions and only one of them can see a prescription: `--token-re` is
# digits-only, correct for the expanded filenames its other callers read, and
# `--token-re-prescribed` covers the `s<N>` / `N` / `*` placeholders prose is written in. Swap
# them and the placeholder finding disappears while the digits one survives — a checker that
# reports SOME of its subject and reads complete.
#
# EVERY SILENT CASE GETS ITS OWN ASSERTION, because each is silent for a different reason and a
# single "3 findings" count is satisfied by an arm that found the right number of wrong things.
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

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

run()  { bash "$LINTER" "$CONS" 2>/dev/null; }
w11()  { run | grep '^WARN   W11' || true; }
# The count line the arm prints is its own control: this arm's answer is normally an absence,
# and an absence is what a broken extractor and a conforming layer both print.
seen() { run | sed -n 's/^ *\([0-9][0-9]*\) artifact-path prescription(s) read.*/\1/p' | head -1; }
hit()  { run | sed -n 's/.*prescription(s) read across [0-9]* scan root(s); \([0-9][0-9]*\) non-conforming.*/\1/p' | head -1; }
says() { w11 | grep -qF -- "$1"; }

echo "layer-artifact-path-prescriptions:"

# --- Part 0: the arm ran at all ------------------------------------------------------------
# Every absence assertion below is measured against this. An arm that read nothing satisfies all
# of them, and the seed's own conforming paths are what make the corpus non-trivial.
S="$(seen)"; H="$(hit)"
if [ -n "$S" ] && [ "$S" -ge 6 ]; then
  ok "the arm read $S artifact-path prescription(s) from the seed — the silence assertions below are measured against a non-empty corpus"
else
  bad "the arm reported '${S:-<no count line>}' prescriptions read. It printed no usable count, or read almost nothing; either way every 'is silent about' assertion in this file would pass vacuously"
fi

# --- Part 1: the three firing cases, one per reason ------------------------------------------
if says 's<N>-carry-over-evaluation.md'; then
  ok "PLACEHOLDER sprint token in a basename is reported — the form prose is written in, and the one a digits-only expression cannot see"
else
  bad "\`_bmad-output/planning-artifacts/s<N>-carry-over-evaluation.md\` was not reported. This is the form every prescription uses; an arm blind to it is blind to almost the whole clause"
fi

if says 'docs/retro/sprint-249.md'; then
  ok "DIGITS sprint token under a SECOND scan root is reported — the corpus is the whole declared root set, not one root"
else
  bad "\`docs/retro/sprint-249.md\` was not reported. Either the digits spelling or the second scan root is outside the corpus, and an arm that reads one root reports part of its subject while reading complete"
fi

if says 'planning-artifacts/stories/'; then
  ok "the story corpus written off its declared location is reported — it carries NO sprint token, so the first arm cannot see it and this is a second predicate"
else
  bad "\`_bmad-output/planning-artifacts/stories/\` was not reported. That is the citation the clause was filed for, and its defect is a MISSING slot rather than a misplaced one — an arm with only the sprint-token predicate reports everything except the case that produced it"
fi

if [ "${H:-0}" -eq 3 ]; then
  ok "exactly 3 non-conforming, matching the three seeded defects — nothing extra fired"
else
  bad "the arm reported ${H:-<none>} non-conforming against 3 seeded. Extra findings are false positives on this seed's own conforming paths; fewer means one of the assertions above is passing on the wrong row"
fi

# --- Part 2: the silent cases, each for its own reason ---------------------------------------
# THE CONCRETE SLOT, and this arm exists because the clause used to fail it. The exemption was a
# hand-list of two spellings — `s<N>` and `s*` — so `docs/retro/s294/retro.md` was reported as
# carrying a sprint token outside the slot. That path IS the slot, and it is precisely the rewrite
# the W11 message asks for, so the clause was handing back its own remedy as the defect. Measured
# on the reference consumer at the time: 7 of 7 remaining rows were this shape.
if says 'docs/retro/s294'; then
  bad "the CONCRETE slot \`docs/retro/s294/retro.md\` was reported. That is the spelling this clause's own remedy prescribes, so an entry that took the advice is told to change it back — a check that cannot be silenced by following it teaches the operator to stop reading it"
else
  ok "SILENT: a CONCRETE slot \`docs/retro/s294/retro.md\` is not reported — the exemption is the slot RULE, not a hand-list of the two placeholder spellings"
fi

if says 's<N>/stories/'; then
  bad "the CORRECTLY SLOTTED story corpus was reported. The story arm fires on the declared location itself, so a consumer that has done exactly what the schema says is told to change it"
else
  ok "SILENT: the correctly slotted \`s<N>/stories/\` is not reported — the arm discriminates rather than firing on every path containing 'stories'"
fi

if says 'planning-artifacts/prd.md'; then
  bad "an area-root durable (\`prd.md\`) was reported. It carries no sprint token and is not the story corpus; reporting it means the predicate fires on membership of the area rather than on the grammar"
else
  ok "SILENT: an area-root durable is not reported — it has no sprint to misplace"
fi

if says 'pipeline-snapshot.md'; then
  bad "a \`_bmad-output/\` root singleton was reported. artifact-path-grammar.md says in as many words that these are NOT artifact paths — a singleton whose whole point is that there is exactly one, and a sprint slot would create a second"
else
  ok "SILENT: a root singleton the grammar explicitly excludes is not reported"
fi

if says 's<N>-retro-draft.md'; then
  bad "a non-conforming path inside a FENCED block was reported. LC-R3 skips fences and states the cost; this arm claims the same skip, and an arm that reads fences imports every worked example an entry quotes"
else
  ok "SILENT: a non-conforming path inside a fenced block is not reported — the skip LC-R3 states is real here too"
fi

if says 'docs/coding-conventions.md'; then
  bad "a path outside every scan root was reported. The corpus is the declared roots; anything else is not this clause's subject and the operator has no grammar to bring it into line with"
else
  ok "SILENT: a path outside every declared scan root is not reported"
fi

# --- Part 3: MUTATION M1 — the digits-only expression ----------------------------------------
# THE MUTANT IS A COPY OF THE WHOLE scripts/ DIRECTORY, never a lone file. This linter resolves
# artifact-path-config.sh BESIDE itself; a copy anywhere else finds no resolver, takes the loud
# refusal branch, and reports zero findings — which reads exactly like the mutation working.
# The unmutated control from the same copied directory is what separates the two.
MUTDIR="$ROOT/scripts-mutant"; mkdir -p "$MUTDIR"
cp "$(dirname "$LINTER")"/* "$MUTDIR"/ 2>/dev/null
MUT="$MUTDIR/validate-layer-entries.sh"
CTL="$MUTDIR/validate-layer-entries-unmutated.sh"; cp "$LINTER" "$CTL" 2>/dev/null
sed 's/--token-re-prescribed 2>\/dev\/null/--token-re 2>\/dev\/null/' "$LINTER" > "$MUT"

ctl_hit="$(bash "$CTL" "$CONS" 2>/dev/null | sed -n 's/.*scan root(s); \([0-9][0-9]*\) non-conforming.*/\1/p' | head -1)"
if [ ! -s "$MUT" ] || cmp -s "$LINTER" "$MUT"; then
  bad "FIXTURE ERROR: the token-expression mutation matched nothing, so Part 3 proves nothing. Update the sed to match how this arm resolves its predicate"
elif [ "${ctl_hit:-x}" != "3" ]; then
  bad "FIXTURE ERROR: the UNMUTATED copy in $MUTDIR reports ${ctl_hit:-<nothing>} non-conforming against 3 in place — the copied directory is not a working harness, so no verdict below is attributable"
else
  ok "CONTROL: an unmutated copy in the same directory reports the same 3 — the mutant verdicts below are its edit, not the copy"
  mut_out="$(bash "$MUT" "$CONS" 2>/dev/null | grep '^WARN   W11' || true)"
  if grep -qF 's<N>-carry-over-evaluation.md' <<<"$mut_out"; then
    bad "MUTATION M1 — the digits-only expression still reported the PLACEHOLDER form. The two expressions are not distinguishable here, so this fixture cannot tell a clause built on the right one from a clause built on the wrong one"
  else
    ok "MUTATION M1 — with the digits-only expression the placeholder finding disappears: resolving --token-re-prescribed is load-bearing, not decorative"
  fi
  # PAIRING. A mutant that lost EVERYTHING would satisfy the assertion above while testing
  # nothing about which expression was resolved.
  if grep -qF 'docs/retro/sprint-249.md' <<<"$mut_out"; then
    ok "MUTATION M1 PAIRING — the same mutant still reports the DIGITS form: it lost the placeholder case specifically, not the arm"
  else
    bad "MUTATION M1 PAIRING — the mutant lost the digits form too, so its silence is a broken arm rather than the narrower expression, and M1 attributes nothing"
  fi
fi

# --- Part 3b: MUTATION M3 — the exemption is the slot RULE, not a hand-list ------------------
# Revert the exemption to the two literal spellings it used to carry. The CONCRETE slot must
# start being reported: that is the regression this arm exists for, and it shipped once.
MUT3="$MUTDIR/validate-layer-entries-handlist.sh"
sed 's|\[ -n "\$LC_SLOTRE" \] && grep -qE "\$LC_SLOTRE" <<<"\$c" \&\& continue|[ "$c" = '"'"'s<N>'"'"' ] \&\& continue; [ "$c" = '"'"'s*'"'"' ] \&\& continue|' "$LINTER" > "$MUT3"
if [ ! -s "$MUT3" ] || cmp -s "$LINTER" "$MUT3"; then
  bad "FIXTURE ERROR: the slot-exemption mutation matched nothing, so M3 proves nothing about where the exemption comes from"
else
  m3="$(bash "$MUT3" "$CONS" 2>/dev/null | grep '^WARN   W11' || true)"
  if grep -qF 'docs/retro/s294' <<<"$m3"; then
    ok "MUTATION M3 — with the exemption back to a hand-list, the CONCRETE slot IS reported: resolving --slot-re-prescribed is what stops the clause returning its own remedy as a defect"
  else
    bad "MUTATION M3 — the hand-list mutant stayed silent on \`docs/retro/s294/retro.md\`, so the concrete-slot arm above passes for some other reason and the resolver call is not what carries it"
  fi
  # PAIRING, same reason as M1's: a mutant that lost the whole arm would satisfy M3 while
  # proving nothing about the exemption.
  if grep -qF 'docs/retro/sprint-249.md' <<<"$m3"; then
    ok "MUTATION M3 PAIRING — the same mutant still reports a genuine violation: it gained the false positive specifically, rather than breaking the arm"
  else
    bad "MUTATION M3 PAIRING — the mutant lost the genuine finding too, so M3's extra row is a broken arm rather than the narrower exemption"
  fi
fi

# --- Part 4: MUTATION M2 — the story location is READ, not restated --------------------------
# Move `stories_dir` in the seeded schema. The correctly-slotted path must START being reported
# and the off-template one must STOP: a reader with the location baked in passes Part 1 and
# fails only here.
SCHEMA="$CONS/.claude/schemas/sprint-status.json"
cp "$SCHEMA" "$ROOT/schema.bak"
sed 's#_bmad-output/planning-artifacts/s{sprint}/stories#_bmad-output/planning-artifacts/relocated-s{sprint}/stories#' \
  "$ROOT/schema.bak" > "$SCHEMA"
if cmp -s "$ROOT/schema.bak" "$SCHEMA"; then
  bad "FIXTURE ERROR: the stories_dir mutation matched nothing in the seeded schema, so Part 4's silence proves nothing about where the location comes from"
else
  m2="$(w11)"
  if grep -qF 's<N>/stories/' <<<"$m2"; then
    ok "MUTATION M2 — with stories_dir moved, the previously-conforming slotted path IS reported: the location is read from the schema, not baked into the reader"
  else
    bad "MUTATION M2 — the slotted path stayed silent after stories_dir moved, so this arm carries its own copy of the story corpus location and schemas/sprint-status.json is decoration"
  fi
fi
cp "$ROOT/schema.bak" "$SCHEMA"

echo
if [ "$fails" -eq 0 ]; then
  echo "layer-artifact-path-prescriptions: PASS"
  exit 0
fi
echo "layer-artifact-path-prescriptions: FAIL ($fails)"
exit 1
