#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"
# The linter loads artifact-path-config.sh beside itself and FAILS OPEN (W11) when it is absent.
[ -f "$(dirname "$LINTER")/artifact-path-config.sh" ] && echo "HERMETIC-CONSUMED core/scripts/artifact-path-config.sh"

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
CONS="$ROOT/consumer"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

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

echo
report_end layer-artifact-path-prescriptions
