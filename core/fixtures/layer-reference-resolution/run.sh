#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# + 1 W12 premise + 12 W12 mutants + 3 HOOK-namespace mutants + 1 pool-accounting arm + 3 collector self-probes
EXPECTED_ASSERTIONS=42

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

# THE SCORING FUNCTION IS SOURCED, NOT DEFINED HERE. The mutants run under an inner pool
# (Part 5), so the worker is a separate process that cannot inherit a function from this file.
# One definition in `vector.sh`, sourced by both readers — restating it in the worker would be
# two copies of one grammar free to drift. It reads $DOMAIN, set above.
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

# --- Part 5: mutants ----------------------------------------------------------------------
# Each is a COPY of the linter, never an in-place edit, guarded by `cmp -s` so a sed that
# matched nothing cannot pass as a mutation. Each asserts a complete vector distinct from every
# other mutant's, so a mutant that fails two cells is reporting entanglement rather than a kill.
#
# THE MUTANTS RUN UNDER AN INNER POOL, AND THAT IS A COST FIX, NOT A BEHAVIOUR CHANGE. This
# fixture was the suite's POLE — the single longest directory, which is what the pool's wall
# clock tracks. Measured: it is fork/exec-bound (~5200 spawns per linter run, 85% system time)
# and was consuming 1.22 cores while the box had 18, so it was serial for no reason. Under the
# outer pool (`.githooks/pre-push`, `AI_DLC_FIXTURE_JOBS` default 12) an inner pool at P=6
# measured 4.4-4.8x on the mutant phase, interleaved, with P=8 run FIRST so the ordering
# confound ran against the change. Re-derive the loaded cost from `.git/ai-dlc-fixture-durations`
# after any edit here; a solo timing of this directory answers a different question and the two
# must never be compared.
#
# WHY P=6 AND NOT THE 8 THAT MEASURED FASTEST. An inner width multiplies against the outer
# one, and both existing inner pools in this suite fix theirs as a narrow constant for exactly
# that reason (`enforcement-map-sites/run.sh`, `validator-arm-selection/run.sh`). The
# measurement justifies a pool; it does not justify 8.
#
# THE POOL IS WHY THE COLLECTOR EXISTS. `made=$((made+1))` inside a pooled child is lost to
# the subshell, so a child cannot assert. Each worker writes a verdict FILE and the collector
# below walks the DISPATCHED LIST to read them — see its own header for why the list and not
# the directory listing.
MUT_DIR="$ROOT/mutants"
mkdir -p "$MUT_DIR"
MUT_JOBS="6"
: > "$ROOT/mutant-list"

mk_mutant() { # mk_mutant <label> <sed-expr> <expected-vector>
  local label="$1" expr="$2" want="$3"
  # printf '%s' and not echo: these expressions carry backslashes and `-e`-shaped leading
  # text, both of which echo is free to interpret. The worker reads the file verbatim.
  printf '%s' "$expr" > "$MUT_DIR/$label.expr"
  printf '%s' "$want" > "$MUT_DIR/$label.want"
  printf '%s\n' "$label" >> "$ROOT/mutant-list"
}

# M1 — put the hardcoded dot back. Only the em-dash subject's applicability moves.
mk_mutant hardcoded-dot \
  "s/a_form=\"\\\$\(anchor_form \"\\\$f\" \"\\\$a\"\)\"/a_form=\"\\\${a}.\"/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=BAD dotform=OK $W9WANT $W12WANT"

# M2 — drop the BARE half of the crosswalk join. Only the bare-row citation moves.
# The first cut of this fixture had one mutant for the whole join and seeded only a bare row,
# so deleting the namespaced branch changed a line and changed no verdict: it passed `cmp -s`
# and proved nothing. Two rows, two mutants, one cell each.
mk_mutant no-crosswalk-bare \
  "/grep -Fxq -- \"\\\$ref\" <<<\"\\\$CROSSWALK_IDS\" && continue/d" \
  "d19b=W r19b=W r11b=W c34=W c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT"

# M2b — drop the NAMESPACED half. Only the namespaced-row citation moves.
mk_mutant no-crosswalk-namespaced \
  "/grep -Fxq -- \"Check \\\$ref\" <<<\"\\\$CROSSWALK_IDS\" && continue/d" \
  "d19b=W r19b=W r11b=W c34=- c12=W c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT"

# M3 — widen the grammar to alphabetic ids. Only the placeholders move.
mk_mutant alphabetic-grammar \
  "s/grep -Eoh 'Check\[ -\]\[0-9\]\+\[a-z-\]\*'/grep -Eoh 'Check[ -][0-9A-Z]+[a-z-]*'/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=W hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT"

# M4 — drop the rulebook resolve. Only core's own check moves.
mk_mutant no-anchor-resolve \
  "/grep -Fxq -- \"\\\$ref\" <<<\"\\\$GLOBAL_CHECK_ANCHORS\" && continue/d" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=W alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT"

# --- The HOOK namespace's mutants. Two, because the resolver makes two decisions and one
# mutant over both would go red for either and identify neither.
#
# M5 — drop the hook resolve entirely. This is the DEFECT AS FILED: a correct citation of a
# hook-implemented check reports as dangling. Only hk61 moves, because it is the only cell
# whose silence the hook branch owns — hk62/hk64/hk65 report either way, which is what makes
# them controls for this mutant rather than passengers.
mk_mutant no-hook-resolve \
  "/hook_resolves_ref \"\\\$f\" \"\\\$ref\" && continue/d" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=W hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT"

# M6 — RESOLVE ON ANY HOOK RATHER THAN THE ONE THE LINE NAMES. The plausible wrong fix, and
# the one the candidate's own suggested shape describes: grep the registered hooks for the id.
# It silences the true subject exactly as the correct fix does, so every cell except hk62
# agrees with the pristine vector — hk62 is the ONLY input that separates the two
# implementations, which is why the seed puts it in its own file.
mk_mutant hook-resolve-any \
  "s@ids=\"\\\$\(hook_declared_ids \"\\\$HOOKS_DIR/\\\$hook_base\"\)\"@ids=\"\$(for _h in \"\$HOOKS_DIR\"/ai-dlc-*.sh; do hook_declared_ids \"\$_h\"; done)\"@" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=- hk64=W hk65=W apform=OK dotform=OK $W9WANT $W12WANT"

# M7 — RESOLVE ON A MENTION RATHER THAN A DECLARATION. The other plausible wrong fix, and the
# one with a LATENT acquittal: core hooks mention 15 check ids and declare 8, and all 7 in the
# difference resolve in the rulebook today — so on the real tree this mutant changes nothing
# and would ship invisibly. Only hk64 separates them, and it exists for that reason alone.
mk_mutant hook-resolve-mention \
  "s@grep -hoE '\\^# Check \[0-9\]\+\[a-z-\]\*:'@grep -hoE 'Check [0-9]+[a-z-]*'@; s@sed -E 's/\\^# Check //; s/:\\\$//'@sed -E 's/^Check //'@" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=- hk65=W apform=OK dotform=OK $W9WANT $W12WANT"

# --- W9's mutants. One per narrowing, and each narrowing exists for a measured reason. ----
# The arm is four decisions, not one: skip fences, normalise `./`, require the path to be
# root-relative, and read overrides as well as extensions. A single mutant over the whole arm
# would go red for any of them and identify none.

# M5 — stop skipping fenced blocks. Only the fenced path moves. This is I68's defect exactly:
# a reader that does not skip fences turns a worked example into a finding.
mk_mutant w9-no-fence-skip \
  "/^[[:space:]]+fence \{ next \}$/d" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK w9miss=W w9dot=W w9ovr=W w9ok=- w9fence=W w9dist=- w9rdme=- $W12WANT"

# M6 — stop normalising the leading `./`. Only the dot-slash path moves, and it goes SILENT:
# the reference consumer's live subject is written in exactly this form, in a step's own
# command list, so without this line the arm misses the case that motivated it.
mk_mutant w9-no-dotslash \
  "/, \"\", t\)/d" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK w9miss=W w9dot=- w9ovr=W w9ok=- w9fence=- w9dist=- w9rdme=- $W12WANT"

# M7 — stop requiring the token to be root-relative. Only the distribution-form path moves.
# Unanchored, the arm resolves a path written against the distribution's layout against the
# CONSUMER's root, where it correctly does not exist — a finding manufactured by the grammar.
mk_mutant w9-no-root-anchor \
  "s/if \(t ~ [^)]*\) print t/print t/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK w9miss=W w9dot=W w9ovr=W w9ok=- w9fence=- w9dist=W w9rdme=- $W12WANT"

# M8 — narrow the subject set to extensions/. Only the override's citation moves, and it goes
# silent: an arm that walked one of the two layer directories would print the same clean line
# on a tree whose overrides tell an agent to run a file that is not there.
mk_mutant w9-extensions-only \
  "s/\{ layer_files \"\\\$EXT_DIR\"; layer_files \"\\\$OVR_DIR\"; \}/layer_files \"\\\$EXT_DIR\"/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK w9miss=W w9dot=W w9ovr=- w9ok=- w9fence=- w9dist=- w9rdme=- $W12WANT"

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
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=- w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=-"

# M11 — the tag-join off. The mirror of M10, and the count moves because a demoted FINDING
# lands in AMBIGUOUS rather than vanishing: this arm never drops a subject, it re-tiers it.
mk_mutant w12-tag-off \
  "s/verdict=\"tag\"/verdict=\"ambiguous\"/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=- w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=-"

# M12 — drop the UPPERCASE half of the provenance-token filter. `gate-1` becomes a token, the
# 920 heading and the Check 20 citation line share it, and the arm reports a mislabel on a
# citation nothing is wrong with. This is the measured false positive, armed as a mutant so
# the filter cannot be simplified back out.
mk_mutant w12-token-loose \
  "s/\\| grep -E '\\[A-Z\\]' \\| grep -E '\\[0-9\\]'/| grep -E '[0-9]'/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=W w12amb=2 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=-"

# M13 — accept a bare `gate-validation` stem as a core qualifier, which is the signal the
# reference consumer originally proposed. The bare-stem row leaves AMBIGUOUS and goes silent —
# and that consumer adjudicated that exact row as a real mislabel. A false QUIET, on demand.
mk_mutant w12-stem-quiet \
  "s/gate-validation\\\\\\.md\\)\\[/gate-validation)[/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=2 w12stem=- w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=-"

# M14 — drop the stand-down for a citation core does not define. The vector is derived, not
# observed: the three baseline AMBIGUOUS rows stay, `Check 19b` on the dev.md gate-1 line joins
# them (its `gate-1` token carries no uppercase, so nothing reaches it), and the `## Check 19b`
# group heading joins them too because at that point the enclosing section is still 917. The
# fourth 19b citation sits INSIDE `### 919b.` and reports as a self-reference, which is why
# `w12w19b` moves to W rather than staying quiet. `Check 34` stays stood down by its
# non-corroborating crosswalk row. Three plus two ambiguous, one finding. W7 already reports those as
# dangling; without this gate both arms fire on one subject and one of them is vacuous.
mk_mutant w12-core-gate-off \
  "s/\\[ -n \"\\\$ctitle\" \\] \\|\\| continue/: ; #/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=W w12x34=- w12n8=- w12p20=- w12amb=5 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=-"

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
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=-"

# M16 — restore the UNCONDITIONAL crosswalk stand-down that shipped in v0.390.0, by making
# the corroboration test never fire. The seed's `26` row is a `(label adoption)` row whose own
# title IS this project's 926 title, so under the old rule one row silences a title-join
# FINDING and an AMBIGUOUS row together, before any signal is evaluated. That is the defect
# the reference consumer found by running the shipped arm against its own tree — not by
# review here, and not by this fixture, which did not have a corroborating row until now.
mk_mutant w12-crosswalk-unconditional \
  "s/\\[ -n \"\\\$_x\" \\] \\|\\| return 1/return 1/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=- w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=2 w12stem=A w12x26amb=- w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=-"

# M17 — drop the caveat from the count line, keeping the count. The number survives and the
# sentence that stops it being misread does not. This is the only arm that would catch a
# future author trimming that line for length, and the line is long on purpose: the reference
# consumer has read five of its ambiguous rows closely and all five were findings.
mk_mutant w12-note-uncaveated \
  "s/UNADJUDICATED is not UNDECIDABLE[^\\\\]*//" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=3 w12stem=A w12x26amb=A w12note=- w12self=W w12shadow5=- w12wrap21=- w12sect23=-"

# M18 — disable the `shadows:` branch. The override declares `#5. Story status consistency?`
# and cites `Check 5` in its body; without the branch that citation is a subject with no
# evidence and falls to AMBIGUOUS. The cell moves `-` -> A rather than vanishing, which is why
# it is three-state: a two-state cell cannot tell quiet-by-declaration from never-reached.
mk_mutant w12-shadow-off \
  "s/\\[ -n \"\\\$shadow_anc\" \\] && \\[ \"\\\$\\{shadow_anc#\\\"\\\$ref\\\"\\}\" != \"\\\$shadow_anc\" \\]/false/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=A w12wrap21=- w12sect23=-"

# M19 — disable the self-reference branch, and ONLY it. The section-rebuttal branch opens with
# the byte-identical condition, so a mutation keyed on that text alone kills both and the
# rebuttal's own subject moves too — two cells for one mutant, which means one of the two arms
# is proving nothing. Measured here on the first run. The `; then` is what separates them: the
# rebuttal continues onto the next line, the self branch does not.
# M19 — disable the self-reference branch. The `Check-28` citation inside the `### 928.`
# section carries no title and no provenance token, so nothing else can reach it and it falls
# to AMBIGUOUS. Two of the reference consumer's seven real mislabels are exactly this shape.
mk_mutant w12-self-off \
  "s/\\[ -n \"\\\$sec\" \\] && \\[ \"\\\$sec\" = \"\\\$band\" \\]; then/false; then/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N w12self=- w12shadow5=- w12wrap21=- w12sect23=-"

# M20 — put the qualifier back on a one-line window. Its subject sits OUTSIDE any band
# section, deliberately: inside one, the section rebuttal joins the whole body and reaches the
# same wrapped qualifier, so the two guards mask each other and NEITHER mutant can be killed
# on its own. That is how this arm was first written and both mutants survived — the seed had
# one subject that both guards covered, which reads exactly like two guards that do not work.
#
# The shape is the reference consumer's: prose wrapping at ~76 columns puts `core` at the end
# of one line and the citation at the start of the next. Line-scoped, no quiet signal fires;
# on their tree the position signal then convicted a citation whose own sentence said it meant
# core's, and its remedy would have INVERTED the clause it edits.
mk_mutant w12-window-one-line \
  "s/printf '%s %s' \"\\\$prevline\" \"\\\$text\"/printf '%s' \"\\\$text\"/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=4 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=A w12sect23=-"

# M21 — disable the section rebuttal. Its subject needs THREE lines of separation between the
# qualified mention and the bare citation, for the mirror of M20's reason: at one line the
# window reaches the qualifier and the rebuttal is never the thing deciding. Separated, only
# the section-level read can see it, and without the rebuttal position convicts.
mk_mutant w12-section-rebuttal-off \
  "s/inb { printf \"%s \", \\\$0 }/inb { }/" \
  "d19b=W r19b=W r11b=W c34=- c12=- c7=- alpha=- hk61=- hk62=W hk64=W hk65=W apform=OK dotform=OK $W9WANT w12t26=W w12g24=W w12q17=- w12w19b=- w12x34=- w12n8=- w12p20=- w12amb=3 w12stem=A w12x26amb=A w12note=N w12self=W w12shadow5=- w12wrap21=- w12sect23=W"

# --- Part 5b: DISPATCH the mutants through the inner pool, then COLLECT by name ------------
# THE DISPATCH LIST IS THE POPULATION, AND THE COLLECTOR WALKS IT RATHER THAN THE DIRECTORY.
# A worker that died — killed, aborted under `set -u`, a `sed` that segfaulted — writes no
# file. Reading the directory listing would then simply not see it, and a lost mutant would
# score as a shorter green run, which is this repo's named recurring defect. Walking the list
# makes the absence a FINDING with the label attached.
#
# TWO LOSSES, TWO ARMS, AND EACH MUST BE ABLE TO FIRE WITHOUT THE OTHER. The precedent in
# `.githooks/pre-push` has a count assertion that cannot fire unless its per-file branch
# already has — the count increments only on the path the branch skips — so the count arm
# there is unreachable-by-construction. Here they are independent: the per-label arm below
# reports a MISSING verdict and does not touch `dispatched`, and the count arm compares the
# dispatched total against the number of labels the pool was GIVEN, so a list that lost an
# entry between writing and dispatch fails the count while every file that does exist reads
# fine.
#
# THE SELF-PROBE RUNS BEFORE THE CORPUS, AND IT IS COMMITTED RATHER THAN HAND-RUN. Measured
# while building this: a receipt asserting only that the pool-accounting arm reports OK was
# closed by a collector reading the DIRECTORY instead of the list — the precise defect this
# section exists to prevent — and by a pool at P=1. Both non-fixes produce an identical green
# line, because a collector that never loses anything cannot tell the two apart. So the arm's
# ability to FIRE is asserted here, on a seeded absence, before any real verdict is read.
# THE PROBE DRIVES THE SHIPPING COLLECTOR, NOT A COPY OF IT. A probe that re-implements the
# walk is a second implementation agreeing with itself: measured here, the first cut asserted
# its OWN loop and the directory-reading non-fix still closed the receipt, because the probe
# never touched the collector that non-fix had changed. `collect_into` is the one walk, called
# once by the probe against a seeded 1-absent/1-present list and once against the real one.
# Change it to read the directory and the probe's `missing` falls to 0 in the same run.
collect_into() { # collect_into <listfile> <verdict-dir> -> sets c_seen, c_missing, c_labels
  c_seen=0; c_missing=0; c_labels=''
  local _l
  while IFS= read -r _l; do
    [ -n "$_l" ] || continue
    if [ ! -f "$2/$_l" ]; then c_missing=$((c_missing+1)); c_labels="$c_labels $_l"; continue; fi
    c_seen=$((c_seen+1))
  done < "$1"
}

probe_dir="$ROOT/collector-probe"
mkdir -p "$probe_dir"
printf 'present\nabsent\n' > "$probe_dir/list"
printf 'KILL probe\n' > "$probe_dir/present"      # one verdict exists, one deliberately does not
# THE PROBE'S SEED IS ITSELF ASSERTED. A seed that quietly gains a second verdict file leaves
# the probe reporting on a world with nothing missing — it still passes, and it discriminates
# against nothing. Measured: seeding both files closed this receipt. The seed's discriminating
# property is that `absent` is ABSENT, so that is stated before the walk reads it.
{ [ -f "$probe_dir/present" ] && [ ! -e "$probe_dir/absent" ]; } \
  && ok "self-probe seed: 'present' has a verdict file and 'absent' has none, so the walk below has something to discriminate" \
  || bad "self-probe seed BROKEN: the 1-absent/1-present world is not what is on disk, so the walk below discriminates against nothing"
collect_into "$probe_dir/list" "$probe_dir"
[ "$c_missing" -eq 1 ] && [ "$c_seen" -eq 1 ] \
  && ok "self-probe: the list-walk reports a seeded missing verdict (1 absent, 1 present) — a directory listing would report 1 and 0 findings" \
  || bad "self-probe BROKEN: the list-walk scored $c_seen present / $c_missing missing on a 1-and-1 seed — the collector below cannot be trusted"

# AND THE POOL MUST ACTUALLY BE CONCURRENT. P=1 satisfies every correctness arm above while
# buying nothing, and a serial pool is indistinguishable from a parallel one by verdict alone.
# The subject here is the WIDTH, asserted as a number, because that is what a P=1 regression
# changes and nothing else can see.
[ "${MUT_JOBS:-0}" -ge 2 ] \
  && ok "self-probe: the mutant pool is dispatched at width $MUT_JOBS, so it is concurrent" \
  || bad "self-probe: MUT_JOBS=${MUT_JOBS:-<unset>} — the pool is serial and this fixture is the suite pole again"

dispatched="$(wc -l < "$ROOT/mutant-list" | tr -d ' ')"
if [ "$dispatched" -eq 0 ]; then
  bad "fixture BROKEN: no mutants were dispatched — the list is empty, so every kill below is vacuous"
else
  # I54: no `printf | xargs`. The list is a file; feed the pool from the file.
  xargs -P "$MUT_JOBS" -I{} bash "$HERE/worker.sh" \
      {} "$MUT_DIR/{}.expr" "$MUT_DIR/{}.want" "$LINTER" "$CONS" "$DOMAIN" "$MUT_DIR" \
      < "$ROOT/mutant-list"

  # THE SAME WALK THE PROBE JUST EXERCISED. `collect_into` decides what is present and what
  # is missing; this loop only reads the verdicts it found. Point the walk at the directory
  # instead of the list and the probe above goes red in the same run.
  collect_into "$ROOT/mutant-list" "$MUT_DIR"
  collected="$c_seen"
  for label in $c_labels; do
    bad "mutant $label: NO VERDICT — the worker produced no file, so this mutant was never scored"
  done
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    [ -f "$MUT_DIR/$label" ] || continue
    verdict="$(cat "$MUT_DIR/$label")"
    case "$verdict" in
      KILL*)     ok  "mutant $label killed — vector [${verdict#KILL }]" ;;
      SURVIVED*) bad "mutant $label SURVIVED or misfired — ${verdict#SURVIVED }" ;;
      *)         bad "mutant $label: ${verdict}" ;;
    esac
  done < "$ROOT/mutant-list"

  # The count arm, independent of the per-label arm above: it compares what the pool was
  # given against what the walk actually read a file for.
  if [ "$collected" -ne "$dispatched" ]; then
    bad "pool accounting: $dispatched mutant(s) dispatched, $collected verdict(s) collected"
  else
    ok "pool accounting: all $dispatched dispatched mutants produced a verdict"
  fi
fi

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
