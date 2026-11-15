#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# ITS FOUR SILENT CASES ARE FOUR DIFFERENT REASONS, which is why there is one cell each:
#
#   scripts/present.sh          the file resolves          -> the arm has something to be quiet about
#   scripts/fenced-missing.sh   inside a fenced block      -> I68's defect, and the skip's stated cost
#   core/scripts/…              not root-relative          -> resolved against the wrong root otherwise
#   extensions/README.md        not a layer entry          -> layer_files() drops it by name
#
# Usage: run.sh [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = fixture broken.
set -uo pipefail

# SCRUB AMBIENT AI_DLC_* BEFORE ANYTHING READS IT. This fixture seeds files under
# `.claude/hooks/` for W7's hook namespace, so an operator's own `AI_DLC_*` tunables would be
# testing the CONFIG rather than the code. The enforcement map asserts this of every fixture
# whose run.sh names a hook path, and the reason is a measured one: a consumer that pins a
# tunable in settings.json otherwise fails a fixture — and blocks every push — against code
# that is behaving correctly.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset _v

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
[ -f "$(dirname "$LINTER")/artifact-path-config.sh" ] && echo "HERMETIC-CONSUMED core/scripts/artifact-path-config.sh"

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
CONS="$ROOT/consumer"
DOMAIN="$CONS/.claude/skills/ai-dlc/extensions/checks/domain.md"
CROSSWALK="$CONS/.claude/skills/ai-dlc/extensions/README.md"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

# EXPECTED_ASSERTIONS is not bookkeeping. `set -u` killing a `$( )` subshell inside
# `if m="$( … )"` reads as a false branch, and the arm silently does not run — green lines and a
# PASS. Counting what ran is what closes it, and the count is a literal here or it disappears
# with the assertions.
# 3 premises + 3 W9 premises + 1 W12 premise + 1 pristine vector + 2 applicability
# + 1 code-attribution + 1 crosswalk-is-load-bearing + 1 exit condition.
EXPECTED_ASSERTIONS=13

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
# the fenced cell silent for the wrong reason while every line still read green.
awk '/^[[:space:]]*```/ { f = 1 - f; next } f && /scripts\/fenced-missing\.sh/ { hit = 1 } END { exit hit ? 0 : 1 }' "$DOMAIN" \
  && ok "premise: scripts/fenced-missing.sh sits INSIDE a fenced block in the seed" \
  || bad "premise BROKEN: scripts/fenced-missing.sh is not inside a fence — its silent cell proves nothing"

# THE SCORING FUNCTION IS SOURCED, NOT DEFINED HERE: one definition in `vector.sh`. It reads
# $DOMAIN, set above.
. "$HERE/vector.sh"


W9WANT='w9miss=W w9dot=W w9ovr=W w9ok=- w9fence=- w9dist=- w9rdme=-'
W12WANT='w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=3 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=-'
WANT="d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT"

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
apf="$(grep -oE "SECTION ID OUT OF BAND(, ALREADY COLLIDED)? — '[^']*' allocates" <<<"$out" | grep -oE "'[^']*'" | tr -d "'" | grep -E '^AP' | head -1)"
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
  [ "$got" = "d19b=W r19b=W r11b=W c34=W c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT" ] \
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
[ "$got" = "d19b=- r19b=- r11b=- c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT" ] \
  && ok "exit condition: the prescribed repairs clear every W7 subject" \
  || bad "exit condition: repairs applied and W7 still reports [$got]"
git -C "$CONS" checkout -q -- . 2>/dev/null
rm -f "$DOMAIN.bak" "$CONS/.claude/skills/ai-dlc/extensions/roles/dev.md.bak"

# --- W12 (LC-R5) ------------------------------------------------------------------------
# THE PREMISE, read out of the seed rather than through the arm. The false-positive pin only
# pins something if the same lowercase-with-digit token really is on both sides.
grep -q 'gate-1 only' "$DOMAIN" && grep -q 'gate-1 is active (Check 20)' "$CONS/.claude/skills/ai-dlc/extensions/roles/dev.md" \
  && ok "premise: 'gate-1' appears in the 920 heading AND on the Check 20 citation line" \
  || bad "premise BROKEN: the gate-1 false-positive pin has no subject on one side or the other"

# --- the assertion floor ------------------------------------------------------------------
report_end layer-reference-resolution "$EXPECTED_ASSERTIONS"
