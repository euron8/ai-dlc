#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# carried-findings/run.sh -- validate-carried-findings.sh, the Check 1 arm that makes a gate-1
# re-review answer every Critical and Important finding of the pass before it.
#
# Usage: run.sh        Exit: 0 every assertion holds, 1 a regression, 2 fixture broken.
#
# WHAT IS AT STAKE. A delta re-review reads only the fix delta, so a prior finding the delta never
# touched drops out of the review silently unless something carries it. The validator's verdicts
# are ABSENCE-shaped (no prior finding left unanswered, no open finding under an approval), so
# every arm below is paired: a seeded offender that must FAIL and a near-miss one property away
# that must PASS. Every mutant at the bottom (a copy of the validator with one rule removed) is
# scored against EVERY arm and must flip exactly the arms it names. A validator replaced by
# `exit 0` fails every arm.
#
# THE SEEDS ARE THE PRODUCER'S GRAMMAR, NOT THE READER'S. The prior files carry what
# merge-review-shards.sh writes for a sharded review (`## Shard: <k>`, the shard's own `# ` title,
# `reviewed-sha:`, its own `## Findings` with `### Critical` / `### Important`), what a serial
# reviewer writes from code-reviewer.md's template (arm T reads that template out of the role
# file itself), and the pre-rule bullet and bold-label forms graph's reviews actually carry; the
# heading text is copied from graph s318 story 2.4's pass-1 review.
#
# THE TOPOLOGY ARMS (P, W, D, S) run in one seeded repository with linked worktrees, the shape a
# consumer reviews in: a story is reviewed in its own worktree and checked by the MAIN checkout's
# copy of the validator. A bound pair carries every finding and must read `PASS:`; a pre-migration
# pair must read `PENDING:`. Keying them on PASS-versus-PENDING rather than on a failure keeps the
# rule mutants (a missing carry not counted, ...) off these arms.
#   P1 a pass 2 committed on the main branch before the pull           -> PENDING
#   P2 a pass 3 committed after the pull                               -> PASS (binds)
#   P3 an untracked pass 4 (being written now)                         -> PASS (binds)
#   W1 a story branch cut BEFORE the pull, reviewed in its own worktree,
#      checked by the main checkout's copy                             -> PENDING
#   W2 the same, on a branch cut AFTER the pull                        -> PASS (binds)
#   D1 a pair committed after the first add, then the program reverted and re-added -> PASS
#   S1 a story spanning the pull: a pre-rule pass 1 (a prose line, a bold `**Evidence:**` line,
#      then `- **I1. stale cache** ...`) and a post-rule pass 2 carrying `I1. stale cache`
#                                                                      -> PASS: 1 prior, NOTE
#   S3 the same bullet prior carrying reviewed-sha:, committed AFTER the pull -> FAIL, not a heading
#   S6 the marked prior committed BEFORE the pull                      -> PASS, read by label
#   L1 the unmarked prior written before the pull, committed after it with pass 2 (graph's lazy
#      persist, 521d4c32f)                                             -> PASS, read by label
#   G1/G2 the program gitignored in the checkout (no commit adds it)   -> binds, with a NOTE
#   H1 a depth-1 clone of the S1 world -> REFUSED (exit 2); H2 a full clone -> PASS
#   QL/QF/QP gate 2: a QA p1/p2 pair (qa.md's Findings Template), keyed on qa.md's
#      `## Carried Findings` at the p2's reviewed-sha: absent there, p2 answering nothing -> LEGACY,
#      exit 0; present, p2 missing one -> FAIL; present, p2 answering both -> PASS
# THE FORM ARMS (S4, S5, S7) take a post-rule heading prior with lead-in prose before its first
# `#### `: prose is a NOTE (S4), a bullet (S5) or a bold finding-id line (S7) there FAILS.
# THE WRAPPED-LABEL ARMS (WR1-WR3) take graph s308 1-code-review.md:67's Critical, a bold
# finding-id label whose closing `**` is on the next line: marked it FAILS and --list exits 1 with
# no carry string (WR1); unmarked it is a NOTE (WR2, the pre-rule price above); marked, a wrapped
# bold span opening with no finding id is lead-in prose (WR3).
# THE MATCHING ARMS (K1-K5): a label prior carried by id alone, I11 never answering I1, trailing
# punctuation dropped, a span that is exactly an id, an id two labels share answering neither.
# LIST: `--list` prints exactly the carry strings on stdout, NOTEs on stderr.
# THE TOP-LEVEL ARMS (TA, TQ, TB, TC) take graph s319 1-2-qa-validation.md's shape, `#### ` directly
# under `## Findings` with no `### `: --list and --classes read both findings (TA), a gate-2 p2
# missing one carry FAILS (TQ); a `#### ` outside `## Findings` (TB) or under `### Notes` (TC) is
# uncounted. False-positive set at gate 1: 0 such headings in graph's 322 tracked
# `*-code-review*.md` files at main 91a665334; control, 37 of its `*-qa-validation.md` p1 files
# carry the shape.
#
# THE FALSE-POSITIVE SET, measured over graph's 58 tracked consecutive gate-1 pass pairs
# (s308-s318, shard files excluded) on a file:// clone at graph 2026-10-14. graph tracks
# scripts/ai-dlc/ (62 files; check-ignore answers 1 for this program's path and for a control).
#   A  the program committed at HEAD, after every review, run in place: 58 PENDING, 0 FAIL.
#      That is the consumer that pulls mid-sprint; the zero is the PENDING rule, not a narrowed
#      grammar.
#   B  per pair, the program committed on the parent of the pass-M commit, then pass M (and its
#      prior, where graph committed both together -- the lazy persist) committed after it: 47
#      FAIL, every one a missing carry (graph has 0 files with a column-0 `carried:` line), and
#      0 on form; 11 exit 0 (3 PASS clean, 8 PASS after NOTE lines). Before the post-rule marker
#      existed this topology failed 26 pairs on FORM: a prior persisted after the pull was held
#      to `#### ` although it was written before it; the marker moved 26 to 0. B cannot see a
#      bullet in a marked prior committed before the pull (that prior is read by label), so the
#      zero is derived by join instead: 28 of the 58 pair priors carry the marker, and M's 3
#      lead-in files and 2 form-fail files (below) join 0 of the 58 priors. Control: the same
#      join against the 58 pass-M files hits 1 (s317 2-5 p2), so the join can fire.
#   B2 a story spanning the pull: the prior committed BEFORE the program, pass M after it: 47
#      FAIL, every one a missing carry and none on form; 11 exit 0 (3 PASS clean, 8 PASS after
#      NOTE lines, 614 NOTEs in 13 pairs). The 8 are priors whose bold label wraps across lines
#      or carries no finding id, so nothing is carried from them: a pre-rule prior's form is
#      never a failure, and that is the price of not wedging a story spanning the pull.
#   M  every one of graph's 145 tracked gate-1 review files (s300-s318, shards excluded) as a
#      prior OUTSIDE any repository, where the marker alone decides (`--list`): 60 carry the
#      marker; 55 lead-in prose lines in 3 of them read as NOTEs (s316/SR1-code-review.md,
#      s317/2-5-code-review-p2.md:44, s318/sprint-review-fix-code-review.md;
#      a line opening `None` is silent, so the adversary's 35-file count of prose shrinks to
#      the 3 the marker makes post-rule); 2 FAIL on form, both enumerated and both real
#      bullet findings in a marked file -- s316/SR1-code-review.md:21 and
#      s318/sprint-review-fix-code-review.md:48. Each is a review written before the rule that
#      carries `reviewed-sha:`; it fails only if persisted after the pull, which B shows no
#      graph pair does.
#   WR the wrapped-label rule adds 0 to both: 58 pairs outside any repository (the marker alone
#      decides, wider than B) read 0 form-fail pairs before and after it, and the 145 files under
#      `--list` read the same 2 form-fail files. A grep for a column-0 bold finding-id span left
#      unclosed finds 2 marked files: s318/sprint-review-fix-code-review.md:61, a bullet already
#      failing above, and s316/FF1-code-review.md:32/59/75 (`**S1.`..`**S3.`), under
#      `### Suggestions`, which is no container. 53 such lines sit in 25 unmarked files (NOTEs). Control:
#      s308/1-code-review.md given the marker reads its line-67 Critical as lead-in before, FAIL after.
#   Every B/B2 failure is a review written before the rule existed, re-committed after it on
#   purpose; none is a false positive against a review written under the rule.
# MUTANT MATRIX. "Each mutant is killed by exactly its own arms" is a test-quality property, not a per-push
# one. Per push each mutant runs its deciding arm (must trip) and its twin (an arm the measured matrix shows
# GREEN under that mutant, must pass). `--matrix` runs every arm against every mutant, enforces the exact vector
# the base asserted (every named arm dead, the rest green) and prints one MATRIX row per mutant and arm.
# That recorded matrix plus the twin replaces the per-push exact-vector assertion. The unmutated pass and the
# exit-0 stub still run every arm. Re-measure whenever an arm or a mutant is added or changed.
# selfloc's vector is W1 S6 G1 G2 H1, not W1 alone, ON PURPOSE: the mutated property is location-dependence (the copy
# returns 1 from locate() when it does not sit under the review's TOP), and one sourced copy -- placed in R -- sits
# under one TOP, so every arm whose review lives in another world trips on it. Do not narrow it back to W1; the
# reason and the vacuity cell that keeps it distinct from an unconditional `return 1` sit at its score call.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/carried-findings/run.sh --matrix
# MUTANT-MATRIX nocarry decides=F1 twins=F2
# MUTANT-MATRIX appr decides=F2 twins=N2
# MUTANT-MATRIX anyopen decides=N2 twins=F2
# MUTANT-MATRIX unparsed decides=F3 twins=S4
# MUTANT-MATRIX boldlead decides=S7 twins=S5
# MUTANT-MATRIX leadfail decides=S3 twins=S5
# MUTANT-MATRIX wrapoff decides=WR1 twins=WR3
# MUTANT-MATRIX wrapany decides=WR3 twins=WR1
# MUTANT-MATRIX nonebul decides=N3 twins=S5
# MUTANT-MATRIX sep decides=F4 twins=F1
# MUTANT-MATRIX cfence decides=F5 twins=F4
# MUTANT-MATRIX sect decides=F6 twins=C
# MUTANT-MATRIX vaddbinds decides=W1 twins=W2
# MUTANT-MATRIX descends decides=P1 twins=P2
# MUTANT-MATRIX untracked decides=P3 twins=P2
# MUTANT-MATRIX pmalways decides=P2 twins=P1
# MUTANT-MATRIX recent decides=D1 twins=P2
# MUTANT-MATRIX selfloc decides=W1 twins=W2
# MUTANT-MATRIX ignpend decides=G1 twins=W1
# MUTANT-MATRIX shallow decides=H1 twins=H2
# MUTANT-MATRIX alwayslabels decides=F3 twins=S6
# MUTANT-MATRIX markonly decides=S6 twins=L1
# MUTANT-MATRIX earlyonly decides=L1 twins=S6
# MUTANT-MATRIX nolabel decides=S1 twins=S4
# MUTANT-MATRIX anybold decides=S1 twins=K1
# MUTANT-MATRIX notefail decides=S1 twins=WR3
# MUTANT-MATRIX exactspan decides=K1 twins=K3
# MUTANT-MATRIX idprefix decides=K2 twins=K1
# MUTANT-MATRIX nopunct decides=K3 twins=K1
# MUTANT-MATRIX dupid decides=K5 twins=K2
# MUTANT-MATRIX listnone decides=LIST twins=K1
# MUTANT-MATRIX nokey decides=QL twins=F1
# MUTANT-MATRIX qaacquit decides=QU1 twins=QU3
# MUTANT-MATRIX noline decides=V1 twins=V4
# MUTANT-MATRIX twoval decides=V3 twins=V2
# MUTANT-MATRIX prefix decides=V5 twins=V1
# MUTANT-MATRIX subonly decides=TA twins=TB
# MUTANT-MATRIX topany decides=TB twins=TA
# MUTANT-MATRIX topnotes decides=TC twins=TA
# MUTANT-MATRIX-DYNAMIC role-loop why=the template-mutation loop passes role-bullet and role-nosha as one variable
# MUTANT-MATRIX-CONTROL unmutated-copy why=an unmutated copy of the validator, installed like every mutant, must pass the arms the mutants are scored on
# MUTANT-MATRIX role-bullet decides=T twins=C
# MUTANT-MATRIX role-nosha decides=T twins=C
# MUTANT-MATRIX-FULL stub worlds=C,F1,F2,N2,F3,N3,F4,F5,F6,T,P1,P2,P3,W1,W2,D1,S1,S3,L1,S4,S5,S6,S7,WR1,WR2,WR3,K1,K2,K3,K4,K5,G1,G2,H1,H2,LIST why=an exit-0 validator must trip every arm, so no single arm decides it
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
V=""; ROLE=""
d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  for c in "$d/core/scripts/validate-carried-findings.sh" "$d/scripts/ai-dlc/validate-carried-findings.sh"; do
    [ -z "$V" ] && [ -f "$c" ] && V="$c"
  done
  for c in "$d/core/team-roles/code-reviewer.md" "$d/.claude/team-roles/code-reviewer.md"; do
    [ -z "$ROLE" ] && [ -f "$c" ] && ROLE="$c"
  done
  [ -n "$V" ] && [ -n "$ROLE" ] && break
  d="$(dirname "$d")"
done
[ -n "$V" ] || { echo "FIXTURE ERROR: validate-carried-findings.sh not found above $HERE in either layout; nothing was asserted" >&2; exit 2; }
[ -n "$ROLE" ] || { echo "FIXTURE ERROR: team-roles/code-reviewer.md not found above $HERE in either layout; nothing was asserted" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-carried-findings.sh"
echo "carried-findings: subject = $V"
echo "carried-findings: role    = $ROLE"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/carried-findings.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
MATRIX=0
if [ "${1:-}" = --matrix ]; then MATRIX=1; fi
MWIDE=0; MROWS=0
. "$HERE/../lib/matrix.sh" || { echo "FIXTURE BROKEN: cannot source lib/matrix.sh" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# IN PROCESS (BL-878). Each copy of the validator -- the real one, each mutant, the unmutated control and the exit-0
# stub -- is SOURCED ONCE into this shell by src (its guard returns after defining vcf_main; one fx_inproc pass each),
# and every arm calls the vcf_main sourced last inside the `$( )` that captures its output, so the validator's `exit`,
# its `set -u`, `export LC_ALL=C` and `unset GIT_DIR ...` stay in that subshell. The validator reads no file beside
# itself (its one self-read is --help), so where a copy sits changes no verdict except the selfloc mutant's, whose
# measured --matrix vector is recorded at its score call. A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a subject with neither the `vcf_main() {`
# line nor the column-0 source guard predates the wrap and reads SKIP (exit 0, never an ok); exactly one half is a
# respelled subject and FAILs. The distribution cannot reach the SKIP unnoticed: C5 (validate-fixture-inprocess.sh)
# refuses a cli subject without the guard, and J3 refuses the start count moving.
# A subject grep cannot READ (exit 2) is no pre-wrap subject: it is FIXTURE ERROR, never the SKIP.
w_def=0; w_guard=0
grep -q '^vcf_main() {$' "$V"; g_def=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$V"; g_guard=$?
if [ "$g_def" -gt 1 ] || [ "$g_guard" -gt 1 ]; then echo "FIXTURE ERROR: cannot read $V (grep exit $g_def/$g_guard), so the in-process wrap cannot be judged; nothing was asserted" >&2; exit 2; fi
[ "$g_def" = 0 ] && w_def=1; [ "$g_guard" = 0 ] && w_guard=1
if [ "$w_def$w_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$w_def" = 0 ]; then echo "  FAIL  $V carries the column-0 source guard but no \`vcf_main() {\` line -- a respelled subject this fixture cannot drive"; echo "carried-findings: 1 FAILED"; exit 1; fi
if [ "$w_guard" = 0 ]; then echo "  FAIL  $V defines \`vcf_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run vcf_main in this shell"; echo "carried-findings: 1 FAILED"; exit 1; fi
src() { # src <copy> -- source one copy of the validator; every arm drives the copy sourced last
  unset -f vcf_main
  fx_inproc "$1"
  . "$1" || { echo "FIXTURE BROKEN: sourcing $1 failed" >&2; exit 2; }
  declare -F vcf_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $1 defined no vcf_main" >&2; exit 2; }
  LOADED="$1"
}
LOADED=""
# own <copy>: an arm names the copy it scores, and refuses to read any other one's verdict.
own() { [ "$1" = "$LOADED" ] || { echo "FIXTURE BROKEN: an arm drove $1 while the vcf_main sourced last is ${LOADED:-none}" >&2; exit 2; }; }
# mcell <mutant> <arm> <result 0 green|1 tripped>: one matrix row, printed by the sourced matrix_row, and only
# under --matrix (a plain run prints none and counts none).
mcell() {
  [ "$MATRIX" = 1 ] || return 0
  MROWS=$((MROWS + 1))
  if [ "$3" = 1 ]; then matrix_row "$1" "$2" 1 TRIPPED yes; else matrix_row "$1" "$2" 0 GREEN no; fi
}
EM="$(printf '\342\200\224')"
H1='The full-suite capture records no command, seed or head sha'
H2='AC6(c) discriminator depends on the process cwd'
H3='No committed RED-run artifact for the AC1, AC2, AC3, AC8 or AC4-restore discriminators'

# ---- seeds ---------------------------------------------------------------------------------
S="$WORK/s"; mkdir -p "$S" || exit 2
# A merged (sharded) pass 1: two shards, each with its own ## Findings. H1 and H2 are Important,
# H3 Critical. A Suggestion, a #### under another ## section, and a fenced #### are NOT findings.
cat > "$S/merged.md" <<EOF
# Code Review: 2-4 (merged from 2 shards)

## Summary

Merged by merge-review-shards.sh from 2 part shards.

## Verdict
NEEDS_REWORK

## Shard: part 1

# Code Review Shard 1/2: story 2-4

shard: 1/2 2-4
reviewed-sha: a6251bc93545095f74f6b5753e09f03ac9e0bfa2
shard-verdict: NEEDS_REWORK

## Findings

### Critical

### Important

#### $H1

parts: 1

\`\`\`
#### a fenced heading is not a finding
\`\`\`

### Suggestions

#### Dead imports left in two test files

parts: 1

## Shard: part 2

# Code Review Shard 2/2: story 2-4

reviewed-sha: a6251bc93545095f74f6b5753e09f03ac9e0bfa2
shard-verdict: NEEDS_REWORK

## Findings

### Critical (must fix before merge)

#### $H3

parts: 2

### Important (should fix, can be follow-up)

#### $H2

parts: 2
EOF
# The same review plus a #### heading under an Important container OUTSIDE ## Findings, the shape
# graph's "Pass-1 Finding Disposition" sections take. Only arm F6 reads it.
{ cat "$S/merged.md"; printf '\n## Pass-1 Finding Disposition\n\n### Important\n\n#### a heading outside any Findings section is not a finding\n'; } > "$S/decoy.md"
# pass 2 writer: <file> <verdict> <carried lines...>
p2() {
  local f="$1" v="$2"; shift 2
  { printf '# Code Review: 2.4 (pass 2, delta review)\n\nreviewed-sha: 7d3889e9e0e07c9699891956be739cb5c9339430\n\n'
    printf '## Summary\n\nDelta review.\n\n## Verdict\n%s\n\n' "$v"
    for l in "$@"; do printf '%s\n' "$l"; done
    printf '\n## Findings\n\n### Critical\n\n### Important\n\n### Suggestions\n'; } > "$f"
}
c_res() { printf 'carried: %s %s resolved' "$1" "$EM"; }
c_open() { printf 'carried: %s %s open' "$1" "$EM"; }
p2 "$S/all.md" APPROVED "$(c_res "$H1")" "$(c_res "$H2")" "$(c_res "$H3")"
p2 "$S/miss.md" APPROVED "$(c_res "$H1")" "$(c_res "$H3")"
p2 "$S/open-appr.md" APPROVED "$(c_res "$H1")" "$(c_open "$H2")" "$(c_res "$H3")"
p2 "$S/open-nr.md" NEEDS_REWORK "$(c_res "$H1")" "$(c_open "$H2")" "$(c_res "$H3")"
p2 "$S/hyphen.md" APPROVED "$(c_res "$H1")" "carried: $H2 - resolved" "$(c_res "$H3")"
# A fenced `open` line beside the real `resolved` answer, under APPROVED: read outside fences the
# review passes; a reader that counts the fenced line sees an open finding under an approval.
p2 "$S/fenced.md" APPROVED "$(c_res "$H1")" '```' "$(c_open "$H2")" '```' "$(c_res "$H2")" "$(c_res "$H3")"
# A POST-RULE serial pass 1 (it carries the template's reviewed-sha: line) whose finding is a
# bullet; and one whose containers say None.
printf '# Code Review: S315-5\n\nreviewed-sha: 7d3889e9e0e07c9699891956be739cb5c9339430\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n### Critical (must fix before merge)\n- **C1. No "Production Integrity Tests" section.** Role rule.\n\n### Important (should fix)\nNone.\n' > "$S/bullet.md"
# Post-rule heading-form priors with lead-in prose before the first ####: graph's real shape
# (s317 2-5 p2 opens its Important container with two sentences). The near-miss is prose; the
# offender adds a dropped finding written as a bullet into that same lead-in.
printf '# Code Review: 2-5\n\nreviewed-sha: 7d3889e9e0e07c9699891956be739cb5c9339430\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n### Critical\n\nNone. The pass-1 Critical is verified closed.\n\n### Important\n\nThese two are pass-1 Importants the fix list did not include.\nNone of them touches the capital path.\n\n#### %s\n\nbody\n\n#### %s\n\nbody\n' "$H1" "$H2" > "$S/leadin.md"
awk -v x='- **I3. Cache TTL outlives the test.** body' '{ print } /^None of them touches/ { print x }' "$S/leadin.md" > "$S/leadin-bullet.md"
awk -v x='**I3. Cache TTL outlives the test.** body' '{ print } /^None of them touches/ { print x }' "$S/leadin.md" > "$S/leadin-bold.md"
p2 "$S/leadin-p2.md" APPROVED "$(c_res "$H1")" "$(c_res "$H2")"
# A WRAPPED bold label, copied from graph s308 1-code-review.md:67: the finding id opens a bold
# span whose closing `**` is on the next line. Marked (post-rule) it FAILS; unmarked (pre-rule) it
# is a NOTE and carries nothing; marked, a wrapped bold span that opens with no finding id is
# lead-in prose.
wrapped_prior() { # <file> <with reviewed-sha: 1|0> <label opening>
  { printf '# Code Review: 1\n\n'
    [ "$2" = 1 ] && printf 'reviewed-sha: 7d3889e9e0e07c9699891956be739cb5c9339430\n\n'
    printf '## Verdict\n\nNEEDS_REWORK\n\n## Findings\n\n### Critical (must fix before merge)\n\n'
    printf '**%s %s AC9'"'"'s recorded derivation of Risk 1(c) is factually wrong, and at `T = 50.0` the new AC11\n' "$3" "$EM"
    printf 'smoke assertion fails whenever the guard fires on the CO-S307 pool shape.**\n\n*Sites:* derivation recorded at the story file.\n\n'
    printf '### Important (should fix, can be follow-up)\n\nNone.\n'; } > "$1"
}
wrapped_prior "$S/wrap-mark.md" 1 C1
wrapped_prior "$S/wrap-nomark.md" 0 C1
wrapped_prior "$S/wrap-prose.md" 1 Evidence
# Label priors (no reviewed-sha:, so read by label): carried by id alone, with trailing
# punctuation dropped, and by a span that is exactly an id. I11 must not answer I1; an id two
# labels share answers neither.
printf '# Code Review: 1\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n### Important\n- **I-1. Staged step cannot restore.** body\n- **I1. Stale cache.** body\n' > "$S/lab.md"
p2 "$S/lab-id.md" APPROVED "$(c_res 'I-1')" "$(c_res 'I1')"
p2 "$S/lab-i11.md" APPROVED "$(c_res 'I-1. Staged step cannot restore.')" "$(c_res 'I11')"
p2 "$S/lab-punct.md" APPROVED "$(c_res 'I-1. Staged step cannot restore')" "$(c_res 'I1. Stale cache')"
printf '# Code Review: 1\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n### Critical\n- **C1**: wallet drained on retry\n' > "$S/lab-c1.md"
p2 "$S/lab-c1-p2.md" APPROVED "$(c_res 'C1')"
printf '# Code Review: 1\n\n## Verdict\nNEEDS_REWORK\n\n## Shard: part 1\n\n## Findings\n\n### Important\n- **I1. Stale cache.** body\n\n## Shard: part 2\n\n## Findings\n\n### Important\n- **I1. Wrong retry count.** body\n' > "$S/lab-dup.md"
p2 "$S/lab-dup-p2.md" APPROVED "$(c_res 'I1')"
printf '# Code Review: S318-1-2\n\nreviewed-sha: 7d3889e9e0e07c9699891956be739cb5c9339430\n\n## Verdict\nAPPROVED\n\n## Findings\n\n### Critical (must fix before merge)\nNone.\n\n### Important (should fix, can be follow-up)\n- None.\n\n### Suggestions\n- tidy a name\n' > "$S/none.md"
p2 "$S/empty.md" APPROVED
# The span-the-pull prior: a prose line and a bold non-id line BEFORE the id-labelled bullet (both
# NOTEs, neither a finding), then the finding and its indented body.
printf '# Code Review: S318-2-1\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n### Important (should fix, can be follow-up)\nOne finding, read by hand.\n**Evidence:** the cache test below.\n- **I1. stale cache** the TTL entry outlives the test.\n  Its body continues here.\n' > "$S/span-prior.md"
p2 "$S/span-p2.md" APPROVED "$(c_res 'I1. stale cache')"
# The same prior carrying the template's reviewed-sha: line (written under the rule).
awk '{ print } NR == 1 { print ""; print "reviewed-sha: 7d3889e9e0e07c9699891956be739cb5c9339430" }' "$S/span-prior.md" > "$S/span-prior-mark.md"
# The serial template, read out of the role file: the fenced block under its heading.
tpl_of() { awk '/^## Review Document Template/ { on = 1; next } on && /^```markdown/ { inb = 1; next } inb && /^```[ \t]*$/ { exit } inb' "$1"; }
tpl_of "$ROLE" > "$S/template.md"
[ -s "$S/template.md" ] || { echo "FIXTURE ERROR: no fenced template under '## Review Document Template' in $ROLE" >&2; exit 2; }
p2 "$S/template-p2.md" APPROVED "$(c_res '<finding title>')"
# TOP-LEVEL findings: graph s319 1-2-qa-validation.md's shape, `#### ` directly under `## Findings`
# with no `### ` container. T1 carries a Class, T2 none (so --classes prints `-`). The near-misses
# each carry one Important-container finding I0 beside a decoy `#### ` that must stay uncounted:
# under a `## ` section other than Findings (TB), and under `### Notes` inside Findings (TC).
T1='Vitest full-run failure in RebalancerPage.test.jsx did not reproduce'
T2='AC1 Decimal path has no committed RED capture'
I0='The capture names no head'
printf '# Gate-2 QA validation: S319-1.2\n\nreviewed-sha: 9d8f14d171cfd4629858bc1315901d89d12e8d80\n\n## Derived tree facts\n\nfacts\n\n## Findings\n\n#### %s\n\nClass: EVIDENCE\nbody\n\n#### %s\n\nbody\n\n## Checklist items not applicable to this story\n\nNone.\n' "$T1" "$T2" > "$S/top.md"
printf '# QA Validation: 1\n\nreviewed-sha: 9d8f14d171cfd4629858bc1315901d89d12e8d80\n\n## Derived tree facts\n\n#### a heading directly under another section is not a finding\n\nbody\n\n## Findings\n\n### Important\n\n#### %s\n\nbody\n' "$I0" > "$S/top-out.md"
printf '# QA Validation: 1\n\nreviewed-sha: 9d8f14d171cfd4629858bc1315901d89d12e8d80\n\n## Findings\n\n### Notes\n\n#### a heading under Notes is not a finding\n\nbody\n\n### Important\n\n#### %s\n\nbody\n' "$I0" > "$S/top-notes.md"
p2 "$S/top-i0-p2.md" APPROVED "$(c_res "$I0")"

run() { own "$1"; out="$(set +o pipefail; vcf_main "$2" "$3" 2>&1)"; rc=$?; }

# ---- the topology repository ----------------------------------------------------------------------
G() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
R="$WORK/main"; mkdir -p "$R" || exit 2
G init -q "$R" || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
[ -d "$R/.git" ] || { echo "FIXTURE ERROR: $R is not a repository after init" >&2; exit 2; }
printf 'x\n' > "$R/a"; G -C "$R" add -A && G -C "$R" commit -qm base || exit 2
C0="$(G -C "$R" rev-parse HEAD)" || exit 2
G -C "$R" branch pre || exit 2                            # a story branch cut BEFORE the pull
mkdir -p "$R/docs/reviews/s1" || exit 2
cp "$S/merged.md" "$R/docs/reviews/s1/1-code-review.md"
cp "$S/miss.md" "$R/docs/reviews/s1/1-code-review-p2.md"
G -C "$R" add -A && G -C "$R" commit -qm "reviews before the pull" || exit 2
mkdir -p "$R/scripts/ai-dlc" || exit 2
cp "$V" "$R/scripts/ai-dlc/validate-carried-findings.sh"
G -C "$R" add -A && G -C "$R" commit -qm pull || exit 2
G -C "$R" branch post || exit 2                           # a story branch cut AFTER the pull
cp "$S/all.md" "$R/docs/reviews/s1/1-code-review-p3.md"
G -C "$R" add -A && G -C "$R" commit -qm "pass 3 after the pull" || exit 2
G -C "$R" branch rr || exit 2
cp "$S/all.md" "$R/docs/reviews/s1/1-code-review-p4.md"  # untracked
VR="$R/scripts/ai-dlc/validate-carried-findings.sh"
# W: the pre-pull story and the post-pull story, each reviewed in its own worktree.
WT="$WORK/wt-pre"; WP="$WORK/wt-post"; WR="$WORK/wt-rr"; WS="$WORK/wt-span"
G -C "$R" worktree add -q "$WT" pre || exit 2
G -C "$R" worktree add -q "$WP" post || exit 2
for w in "$WT" "$WP"; do
  mkdir -p "$w/docs/reviews/s2" || exit 2
  cp "$S/merged.md" "$w/docs/reviews/s2/1-code-review.md"
  cp "$S/all.md" "$w/docs/reviews/s2/1-code-review-p2.md"
  G -C "$w" add -A && G -C "$w" commit -qm "story reviews" || exit 2
done
cp "$S/miss.md" "$WT/docs/reviews/s2/1-code-review-p2.md"   # the pre-pull story drops a carry
G -C "$WT" commit -qam "pre-rule pass 2" || exit 2
[ ! -e "$WT/scripts/ai-dlc/validate-carried-findings.sh" ] || { echo "FIXTURE BROKEN: the pre-pull worktree carries the program" >&2; exit 2; }
# D: a pair committed after the first add, then the program reverted and re-added.
G -C "$R" worktree add -q "$WR" rr || exit 2
mkdir -p "$WR/docs/reviews/s3" || exit 2
cp "$S/merged.md" "$WR/docs/reviews/s3/1-code-review.md"
cp "$S/all.md" "$WR/docs/reviews/s3/1-code-review-p2.md"
G -C "$WR" add -A && G -C "$WR" commit -qm "reviews after the first add" || exit 2
G -C "$WR" rm -q scripts/ai-dlc/validate-carried-findings.sh && G -C "$WR" commit -qm revert || exit 2
mkdir -p "$WR/scripts/ai-dlc" || exit 2
cp "$V" "$WR/scripts/ai-dlc/validate-carried-findings.sh"
G -C "$WR" add -A && G -C "$WR" commit -qm "pull again" || exit 2
# S: a story spanning the pull, on a branch from base: pass 1, then the pull, then pass 2.
G -C "$R" worktree add -q -b span "$WS" "$C0" || exit 2
mkdir -p "$WS/docs/reviews/s4" "$WS/scripts/ai-dlc" || exit 2
cp "$S/span-prior.md" "$WS/docs/reviews/s4/1-code-review.md"
cp "$S/span-prior-mark.md" "$WS/docs/reviews/s4/4-code-review.md"
G -C "$WS" add -A && G -C "$WS" commit -qm "pre-rule pass 1s, one carrying reviewed-sha:" || exit 2
cp "$V" "$WS/scripts/ai-dlc/validate-carried-findings.sh"
G -C "$WS" add -A && G -C "$WS" commit -qm pull || exit 2
cp "$S/span-p2.md" "$WS/docs/reviews/s4/1-code-review-p2.md"
cp "$S/span-prior-mark.md" "$WS/docs/reviews/s4/2-code-review.md"
cp "$S/span-p2.md" "$WS/docs/reviews/s4/2-code-review-p2.md"
# L: a lazily persisted pass 1. Written before the pull with no reviewed-sha: line, left
# uncommitted across it, then committed with pass 2 in one snapshot (graph 521d4c32f).
cp "$S/span-prior.md" "$WS/docs/reviews/s4/3-code-review.md"
cp "$S/span-p2.md" "$WS/docs/reviews/s4/3-code-review-p2.md"
cp "$S/span-p2.md" "$WS/docs/reviews/s4/4-code-review-p2.md"
G -C "$WS" add -A && G -C "$WS" commit -qm "post-rule pass 2, a marked bullet pass 1 written after the pull, and a lazily persisted pass 1" || exit 2
VS="$WS/scripts/ai-dlc/validate-carried-findings.sh"; VD="$WR/scripts/ai-dlc/validate-carried-findings.sh"
# I: a consumer that gitignores scripts/ai-dlc/: the program sits in the checkout and no commit
# adds it. N: the same with the program absent (the PENDING near-miss of I).
RI="$WORK/ign"; mkdir -p "$RI" || exit 2
G init -q "$RI" || exit 2
printf 'scripts/ai-dlc/\n' > "$RI/.gitignore"; G -C "$RI" add -A && G -C "$RI" commit -qm base || exit 2
mkdir -p "$RI/scripts/ai-dlc" "$RI/docs/reviews/s5" || exit 2
cp "$S/merged.md" "$RI/docs/reviews/s5/1-code-review.md"; cp "$S/miss.md" "$RI/docs/reviews/s5/1-code-review-p2.md"
cp "$S/all.md" "$RI/docs/reviews/s5/2-code-review-p2.md"; cp "$S/merged.md" "$RI/docs/reviews/s5/2-code-review.md"
G -C "$RI" add -A && G -C "$RI" commit -qm reviews || exit 2
VI="$RI/scripts/ai-dlc/validate-carried-findings.sh"
G -C "$RI" check-ignore -q scripts/ai-dlc/validate-carried-findings.sh || { echo "FIXTURE BROKEN: the ignore rule does not cover the program path" >&2; exit 2; }
# H: a shallow clone of the span world (the bound S1 pair); a full clone is its near-miss.
G clone -q --depth 1 --branch span "file://$R" "$WORK/shallow" || exit 2
G clone -q --branch span "file://$R" "$WORK/full" || exit 2
[ "$(G -C "$WORK/shallow" rev-parse --is-shallow-repository)" = "true" ] || { echo "FIXTURE BROKEN: the depth-1 clone is not shallow" >&2; exit 2; }
VH="$WORK/shallow/scripts/ai-dlc/validate-carried-findings.sh"; VF="$WORK/full/scripts/ai-dlc/validate-carried-findings.sh"
# Q: gate 2. A consumer that committed the program and qa.md (QA) WITHOUT `## Carried Findings`,
# then qa.md WITH it (QB), then a QA p1 and three p2 files, each p2's reviewed-sha naming the qa.md
# it ran against. The QA files take qa.md's Findings Template containers.
RQ="$WORK/qa"; mkdir -p "$RQ/scripts/ai-dlc" "$RQ/.claude/team-roles" "$RQ/docs/reviews/s6" || exit 2
G init -q "$RQ" || exit 2
cp "$V" "$RQ/scripts/ai-dlc/validate-carried-findings.sh"
printf '# QA\n\n## Finding Class\n\nClass: CODE | TEST | EVIDENCE | BOOKKEEPING\n\n## Validation Checklist\n' > "$RQ/.claude/team-roles/qa.md"
G -C "$RQ" add -A && G -C "$RQ" commit -qm "pull: qa.md without the section" || exit 2
QA="$(G -C "$RQ" rev-parse HEAD)" || exit 2
printf '\n## Carried Findings\n\nA re-validation pass answers every prior finding with a carried: line.\n' >> "$RQ/.claude/team-roles/qa.md"
G -C "$RQ" add -A && G -C "$RQ" commit -qm "pull: qa.md with the section" || exit 2
QB="$(G -C "$RQ" rev-parse HEAD)" || exit 2
Q1='The full-collection capture names no head'; Q2='The Dev Agent Record cites a stale count'
{ printf '# QA Validation: 6\n\nreviewed-sha: %s\nadvisor: called\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n' "$QA"
  printf '### Critical (must fix before PASS)\n\n#### %s\nClass: EVIDENCE\nbody\n\n' "$Q1"
  printf '### Important (should fix, can be follow-up)\n\n#### %s\nClass: BOOKKEEPING\nbody\n\n### Suggestions (optional improvements)\n\nNone.\n' "$Q2"
} > "$RQ/docs/reviews/s6/6-qa-validation.md"
qp2() { # <file> <reviewed-sha> <carried lines...>   (the `## Verdict` heading form, PASS)
  local f="$1" s="$2"; shift 2
  { printf '# QA Validation: 6 (pass 2)\n\nreviewed-sha: %s\nadvisor: called\n\n## Summary\nRe-validation.\n\n' "$s"
    for l in "$@"; do printf '%s\n' "$l"; done
    printf '\n## Verdict\nPASS\n\n## Findings\n\n### Critical (must fix before PASS)\n\nNone.\n\n### Important (should fix, can be follow-up)\n\nNone.\n'; } > "$f"
}
# qp2l: the second seed, qa.md's one-line form (`Verdict: <VALUE>` at column 0, qa.md ## Verdict).
qp2l() { # <file> <reviewed-sha> <verdict value> <carried lines...>
  local f="$1" s="$2" v="$3"; shift 3
  { printf '# QA Validation: 6 (pass 2)\n\nreviewed-sha: %s\nadvisor: called\n\nVerdict: %s\n\n## Summary\nRe-validation.\n\n' "$s" "$v"
    for l in "$@"; do printf '%s\n' "$l"; done
    printf '\n## Findings\n\n### Critical (must fix before PASS)\n\nNone.\n\n### Important (should fix, can be follow-up)\n\nNone.\n'; } > "$f"
}
mkdir -p "$RQ/docs/reviews/s7" "$RQ/docs/reviews/s8" || exit 2
cp "$RQ/docs/reviews/s6/6-qa-validation.md" "$RQ/docs/reviews/s7/6-qa-validation.md"
cp "$RQ/docs/reviews/s6/6-qa-validation.md" "$RQ/docs/reviews/s8/6-qa-validation.md"
qp2 "$RQ/docs/reviews/s6/6-qa-validation-p2.md" "$QA"
qp2 "$RQ/docs/reviews/s7/6-qa-validation-p2.md" "$QB" "$(c_res "$Q1")"
qp2 "$RQ/docs/reviews/s8/6-qa-validation-p2.md" "$QB" "$(c_res "$Q1")" "$(c_res "$Q2")"
# s9: the top-level QA prior at gate 2 with the key present; the p2 answers T1 and not T2.
mkdir -p "$RQ/docs/reviews/s9" || exit 2
cp "$S/top.md" "$RQ/docs/reviews/s9/1-2-qa-validation.md"
qp2 "$RQ/docs/reviews/s9/1-2-qa-validation-p2.md" "$QB" "$(c_res "$T1")"
# s10: a p2 whose reviewed-sha names no commit, so the ON-DISK qa.md (the section present) decides;
# the p2 drops Q2. BADSHA is hex and 40 long, so only the commit lookup can reject it.
BADSHA=0123456789abcdef0123456789abcdef01234567
G -C "$RQ" rev-parse -q --verify "${BADSHA}^{commit}" >/dev/null 2>&1 && { echo "FIXTURE BROKEN: $BADSHA names a commit" >&2; exit 2; }
# s11-s15: the one-line verdict form. s11 NEEDS_REWORK with an open carry; s12 PASS with an open
# carry; s13 two different values (heading NEEDS_REWORK, line PASS); s14 the same value twice;
# s15 a suffixed value, which is its whole token, not its prefix.
for d_ in s10 s11 s12 s13 s14 s15; do
  mkdir -p "$RQ/docs/reviews/$d_" && cp "$RQ/docs/reviews/s6/6-qa-validation.md" "$RQ/docs/reviews/$d_/6-qa-validation.md" || exit 2
done
qp2 "$RQ/docs/reviews/s10/6-qa-validation-p2.md" "$BADSHA" "$(c_res "$Q1")"
qp2l "$RQ/docs/reviews/s11/6-qa-validation-p2.md" "$QB" NEEDS_REWORK "$(c_res "$Q1")" "$(c_open "$Q2")"
qp2l "$RQ/docs/reviews/s12/6-qa-validation-p2.md" "$QB" PASS "$(c_res "$Q1")" "$(c_open "$Q2")"
qp2l "$RQ/docs/reviews/s13/6-qa-validation-p2.md" "$QB" PASS "$(c_res "$Q1")" "$(c_open "$Q2")"
printf '\n## Verdict\nNEEDS_REWORK\n' >> "$RQ/docs/reviews/s13/6-qa-validation-p2.md"
qp2l "$RQ/docs/reviews/s14/6-qa-validation-p2.md" "$QB" NEEDS_REWORK "$(c_res "$Q1")" "$(c_open "$Q2")"
printf '\n## Verdict\nNEEDS_REWORK\n' >> "$RQ/docs/reviews/s14/6-qa-validation-p2.md"
qp2l "$RQ/docs/reviews/s15/6-qa-validation-p2.md" "$QB" NEEDS_REWORK-pending "$(c_res "$Q1")" "$(c_open "$Q2")"
G -C "$RQ" add -A && G -C "$RQ" commit -qm "QA passes" || exit 2
# N: gate 2 with no qa.md in either layout (tracked or on disk); O: qa.md on disk WITHOUT the
# section. Both carry the s10 pair (unresolvable reviewed-sha, Q2 dropped).
for w_ in noqa oldqa; do
  mkdir -p "$WORK/$w_/scripts/ai-dlc" "$WORK/$w_/docs/reviews/s1" || exit 2
  G init -q "$WORK/$w_" || exit 2
  cp "$V" "$WORK/$w_/scripts/ai-dlc/validate-carried-findings.sh" || exit 2
  cp "$RQ/docs/reviews/s10/6-qa-validation.md" "$RQ/docs/reviews/s10/6-qa-validation-p2.md" "$WORK/$w_/docs/reviews/s1/" || exit 2
done
mkdir -p "$WORK/oldqa/.claude/team-roles" || exit 2
G -C "$RQ" show "${QA}:.claude/team-roles/qa.md" > "$WORK/oldqa/.claude/team-roles/qa.md" || exit 2
for w_ in noqa oldqa; do G -C "$WORK/$w_" add -A && G -C "$WORK/$w_" commit -qm "program and QA passes" || exit 2; done
[ ! -e "$WORK/noqa/.claude/team-roles/qa.md" ] && [ ! -e "$WORK/noqa/core/team-roles/qa.md" ] && [ -s "$WORK/oldqa/.claude/team-roles/qa.md" ] &&
  ! grep -q '^## Carried Findings' "$WORK/oldqa/.claude/team-roles/qa.md" && grep -q '^## Carried Findings' "$RQ/.claude/team-roles/qa.md" ||
  { echo "FIXTURE BROKEN: the noqa/oldqa/qa worlds do not hold the qa.md each arm names" >&2; exit 2; }
VN="$WORK/noqa/scripts/ai-dlc/validate-carried-findings.sh"; VO="$WORK/oldqa/scripts/ai-dlc/validate-carried-findings.sh"
QA_OLD="$(G -C "$RQ" show "${QA}:.claude/team-roles/qa.md")" || exit 2
grep -q '^## Carried Findings' "$RQ/.claude/team-roles/qa.md" && [ -n "$QA_OLD" ] && ! grep -q '^## Carried Findings' <<<"$QA_OLD" \
  || { echo "FIXTURE BROKEN: qa.md at $QA carries the section, or the tip lacks it" >&2; exit 2; }
VQ="$RQ/scripts/ai-dlc/validate-carried-findings.sh"
# Every checkout carries the program on disk where its world needs it (committed, or gitignored at $VI, which is
# placed once below); the arms run the copy sourced last, in process, against the reviews in these checkouts.

# ---- arms ------------------------------------------------------------------------------------
# arm_<id> <validator> -> 0 when the arm holds. <validator> must be the copy sourced last (own).
arm_C()  { run "$1" "$S/merged.md" "$S/all.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_F1() { run "$1" "$S/merged.md" "$S/miss.md"; [ "$rc" -eq 1 ] && grep -qF "has no carried: line in $S/miss.md: $H2" <<<"$out"; }
arm_F2() { run "$1" "$S/merged.md" "$S/open-appr.md"; [ "$rc" -eq 1 ] && grep -q 'open carried finding(s) under verdict APPROVED' <<<"$out"; }
arm_N2() { run "$1" "$S/merged.md" "$S/open-nr.md"; [ "$rc" -eq 0 ] && grep -q '1 open, verdict NEEDS_REWORK' <<<"$out"; }
arm_F3() { run "$1" "$S/bullet.md" "$S/empty.md"; [ "$rc" -eq 1 ] && grep -q 'Critical finding that is not a "#### " heading' <<<"$out"; }
arm_N3() { run "$1" "$S/none.md" "$S/empty.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 0 prior' <<<"$out"; }
arm_F4() { run "$1" "$S/merged.md" "$S/hyphen.md"; [ "$rc" -eq 1 ] && grep -q 'does not end in' <<<"$out"; }
arm_F5() { run "$1" "$S/merged.md" "$S/fenced.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior.*(3 resolved, 0 open' <<<"$out"; }
# The section grammar: a #### under an Important container outside ## Findings is not a prior
# finding, so the decoy review still carries exactly three.
arm_F6() { run "$1" "$S/decoy.md" "$S/all.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
# The template a serial reviewer writes from: two placeholder findings it can carry (one per
# Critical/Important container) and a column-0 reviewed-sha line. A bullet template fails here.
arm_T()  { run "$1" "$S/template.md" "$S/template-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 2 prior' <<<"$out" && grep -q '^reviewed-sha: ' "$S/template.md"; }
arm_P1() { run "$1" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PENDING:' <<<"$out"; }
arm_P2() { run "$1" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p3.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_P3() { run "$1" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p4.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_W1() { run "$1" "$WT/docs/reviews/s2/1-code-review.md" "$WT/docs/reviews/s2/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PENDING:.*no commit on the history of HEAD' <<<"$out"; }
arm_W2() { run "$1" "$WP/docs/reviews/s2/1-code-review.md" "$WP/docs/reviews/s2/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_D1() { run "$1" "$WR/docs/reviews/s3/1-code-review.md" "$WR/docs/reviews/s3/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_S1() { run "$1" "$WS/docs/reviews/s4/1-code-review.md" "$WS/docs/reviews/s4/1-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out" && [ "$(grep -c '^NOTE:' <<<"$out")" -eq 2 ]; }
arm_S3() { run "$1" "$WS/docs/reviews/s4/2-code-review.md" "$WS/docs/reviews/s4/2-code-review-p2.md"
           [ "$rc" -eq 1 ] && grep -q 'Important finding that is not a "#### " heading' <<<"$out" && grep -q '^NOTE:.*lead-in prose' <<<"$out"; }

# L1: the lazily persisted pre-rule pass 1 (no marker, committed after the pull) is read by label.
arm_L1() { run "$1" "$WS/docs/reviews/s4/3-code-review.md" "$WS/docs/reviews/s4/3-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out" && [ "$(grep -c '^NOTE:' <<<"$out")" -eq 2 ]; }
# S4/S5: a post-rule heading prior; lead-in prose is a NOTE, a bullet in the lead-in FAILS.
arm_S4() { run "$1" "$S/leadin.md" "$S/leadin-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 2 prior' <<<"$out" && [ "$(grep -c '^NOTE:.*lead-in prose' <<<"$out")" -eq 1 ]; }
arm_S7() { run "$1" "$S/leadin-bold.md" "$S/leadin-p2.md"
           [ "$rc" -eq 1 ] && grep -q 'Important finding that is not a "#### " heading' <<<"$out" && ! grep -q '^FAIL: prior' <<<"$out"; }
# S6: a MARKED prior committed before the pull is still read by label (both conjuncts decide).
arm_S6() { run "$1" "$WS/docs/reviews/s4/4-code-review.md" "$WS/docs/reviews/s4/4-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out" && [ "$(grep -c '^NOTE:' <<<"$out")" -eq 2 ]; }
arm_S5() { run "$1" "$S/leadin-bullet.md" "$S/leadin-p2.md"
           [ "$rc" -eq 1 ] && grep -q 'Important finding that is not a "#### " heading' <<<"$out" && ! grep -q '^FAIL: prior' <<<"$out"; }
# WR: a wrapped bold finding-id label. WR1 marked -> FAIL on form, and --list exits 1 printing no
# carry string; WR2 unmarked (pre-rule) -> PASS with the label as a NOTE; WR3 marked, a wrapped
# bold span with no finding id -> lead-in prose.
arm_WR1() { run "$1" "$S/wrap-mark.md" "$S/empty.md"
            [ "$rc" -eq 1 ] && grep -q 'Critical finding that is not a "#### " heading' <<<"$out" || return 1
            local a; a="$(set +o pipefail; vcf_main --list "$S/wrap-mark.md" 2>/dev/null)"; [ "$?" -eq 1 ] && [ -z "$a" ]; }
arm_WR2() { run "$1" "$S/wrap-nomark.md" "$S/empty.md"
            [ "$rc" -eq 0 ] && grep -q '^PASS: 0 prior' <<<"$out" && grep -q '^NOTE: .*: \*\*C1 .*not carried' <<<"$out"; }
arm_WR3() { run "$1" "$S/wrap-prose.md" "$S/empty.md"
            [ "$rc" -eq 0 ] && grep -q '^PASS: 0 prior' <<<"$out" && grep -q '^NOTE: .*: \*\*Evidence .*lead-in prose' <<<"$out"; }
# K: label matching. K1 id alone; K2 I11 does not answer I1; K3 trailing punctuation dropped;
# K4 a span that is exactly an id; K5 an id two labels share answers neither.
arm_K1() { run "$1" "$S/lab.md" "$S/lab-id.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 2 prior' <<<"$out"; }
arm_K2() { run "$1" "$S/lab.md" "$S/lab-i11.md"; [ "$rc" -eq 1 ] && grep -qF 'has no carried: line in '"$S/lab-i11.md"': I1. Stale cache.' <<<"$out" && [ "$(grep -c '^FAIL: prior' <<<"$out")" -eq 1 ]; }
arm_K3() { run "$1" "$S/lab.md" "$S/lab-punct.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 2 prior' <<<"$out"; }
arm_K4() { run "$1" "$S/lab-c1.md" "$S/lab-c1-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out"; }
arm_K5() { run "$1" "$S/lab-dup.md" "$S/lab-dup-p2.md"; [ "$rc" -eq 1 ] && [ "$(grep -c '^FAIL: prior' <<<"$out")" -eq 2 ]; }
# G1: the program gitignored in the review's checkout binds (a dropped carry FAILS) with a NOTE;
# G2 the same checkout carrying every finding PASSES. W1 (program absent) is the PENDING twin.
arm_G1() { run "$1" "$RI/docs/reviews/s5/1-code-review.md" "$RI/docs/reviews/s5/1-code-review-p2.md"
           [ "$rc" -eq 1 ] && grep -q '^NOTE: .* is gitignored in .*the rule binds' <<<"$out" && grep -q '^FAIL: prior' <<<"$out"; }
arm_G2() { run "$1" "$RI/docs/reviews/s5/2-code-review.md" "$RI/docs/reviews/s5/2-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out" && grep -q '^NOTE: .* is gitignored' <<<"$out"; }
# H1: a shallow repository is refused naming why; H2 the full clone of the same pair PASSES.
arm_H1() { run "$1" "$WORK/shallow/docs/reviews/s4/1-code-review.md" "$WORK/shallow/docs/reviews/s4/1-code-review-p2.md"
           [ "$rc" -eq 2 ] && grep -q '^REFUSED: .* is a shallow repository' <<<"$out"; }
arm_H2() { run "$1" "$WORK/full/docs/reviews/s4/1-code-review.md" "$WORK/full/docs/reviews/s4/1-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out"; }
# Q: gate 2, keyed on qa.md's `## Carried Findings` at the pass's reviewed-sha. QL the section absent
# there and p2 answering nothing -> LEGACY, exit 0; QF present, p2 missing one -> 1; QP present, p2
# answering every finding -> PASS. The tip's qa.md carries the section in all three.
arm_QL() { run "$1" "$RQ/docs/reviews/s6/6-qa-validation.md" "$RQ/docs/reviews/s6/6-qa-validation-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^LEGACY: .*carries no "## Carried Findings" section' <<<"$out"; }
arm_QF() { run "$1" "$RQ/docs/reviews/s7/6-qa-validation.md" "$RQ/docs/reviews/s7/6-qa-validation-p2.md"
           [ "$rc" -eq 1 ] && grep -qF "has no carried: line in $RQ/docs/reviews/s7/6-qa-validation-p2.md: $Q2" <<<"$out" && [ "$(grep -c '^FAIL: prior' <<<"$out")" -eq 1 ]; }
arm_QP() { run "$1" "$RQ/docs/reviews/s8/6-qa-validation.md" "$RQ/docs/reviews/s8/6-qa-validation-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 2 prior' <<<"$out"; }
# LIST: --list prints exactly the carry strings on stdout, in file order, and NOTEs on stderr.
arm_LIST() { local a b; own "$1"
             a="$(set +o pipefail; vcf_main --list "$S/merged.md" 2>/dev/null)" || return 1
             [ "$a" = "$H1$NLF$H3$NLF$H2" ] || return 1
             b="$(set +o pipefail; vcf_main --list "$S/span-prior.md" 2>/dev/null)" || return 1
             [ "$b" = "I1. stale cache" ] || return 1
             [ "$(set +o pipefail; vcf_main --list "$S/span-prior.md" 2>&1 >/dev/null | grep -c '^NOTE:')" -eq 2 ]; }
NLF='
'
# TA: top-level findings are carried. --list prints both, --classes their Class or `-`, in order.
arm_TA() { local a b; own "$1"
           a="$(set +o pipefail; vcf_main --list "$S/top.md" 2>/dev/null)" || return 1
           [ "$a" = "$T1$NLF$T2" ] || return 1
           b="$(set +o pipefail; vcf_main --classes "$S/top.md" 2>/dev/null)" || return 1
           [ "$b" = "EVIDENCE$TAB_$T1$TAB_-$NLF-$TAB_$T2$TAB_-" ]; }
# TQ: the same prior at gate 2, the qa.md key present, a p2 with no carried: line for T2 -> 1.
arm_TQ() { run "$1" "$RQ/docs/reviews/s9/1-2-qa-validation.md" "$RQ/docs/reviews/s9/1-2-qa-validation-p2.md"
           [ "$rc" -eq 1 ] && grep -qF "has no carried: line in $RQ/docs/reviews/s9/1-2-qa-validation-p2.md: $T2" <<<"$out" && [ "$(grep -c '^FAIL: prior' <<<"$out")" -eq 1 ]; }
# TB/TC: the decoy stays uncounted, so the p2 answering I0 alone passes with exactly 1 prior.
arm_TB() { run "$1" "$S/top-out.md" "$S/top-i0-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out"; }
arm_TC() { run "$1" "$S/top-notes.md" "$S/top-i0-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out"; }
TAB_="$(printf '\t')"
# QU1/QU2/QU3: gate 2 with qa.md unreadable at the pass's reviewed-sha (it names no commit). QU1 the
# on-disk qa.md carries the section -> checked, Q2 dropped -> 1. QU2 no qa.md in either layout ->
# checked (an unreadable role file never acquits) -> 1. QU3 the near-miss: on-disk qa.md without
# the section -> LEGACY, 0, naming the on-disk copy.
arm_QU1() { run "$1" "$RQ/docs/reviews/s10/6-qa-validation.md" "$RQ/docs/reviews/s10/6-qa-validation-p2.md"
            [ "$rc" -eq 1 ] && grep -qF "has no carried: line in $RQ/docs/reviews/s10/6-qa-validation-p2.md: $Q2" <<<"$out" && [ "$(grep -c '^FAIL: prior' <<<"$out")" -eq 1 ]; }
arm_QU2() { run "$1" "$WORK/noqa/docs/reviews/s1/6-qa-validation.md" "$WORK/noqa/docs/reviews/s1/6-qa-validation-p2.md"
            [ "$rc" -eq 1 ] && grep -qF "has no carried: line in $WORK/noqa/docs/reviews/s1/6-qa-validation-p2.md: $Q2" <<<"$out" && [ "$(grep -c '^FAIL: prior' <<<"$out")" -eq 1 ]; }
arm_QU3() { run "$1" "$WORK/oldqa/docs/reviews/s1/6-qa-validation.md" "$WORK/oldqa/docs/reviews/s1/6-qa-validation-p2.md"
            [ "$rc" -eq 0 ] && grep -qF "LEGACY: $WORK/oldqa/docs/reviews/s1/6-qa-validation-p2.md is a gate-2 re-validation run against " <<<"$out"; }
# V1-V5: the verdict reader with an open carry. V1 the one-line `Verdict: NEEDS_REWORK` -> 0;
# V2 one-line `Verdict: PASS` -> 1, as the heading form; V3 the heading and the line disagree ->
# refused; V4 they agree -> 0; V5 `NEEDS_REWORK-pending` is its whole token -> 1.
arm_V1() { run "$1" "$RQ/docs/reviews/s11/6-qa-validation.md" "$RQ/docs/reviews/s11/6-qa-validation-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 2 prior.*1 open, verdict NEEDS_REWORK' <<<"$out"; }
arm_V2() { run "$1" "$RQ/docs/reviews/s12/6-qa-validation.md" "$RQ/docs/reviews/s12/6-qa-validation-p2.md"
           [ "$rc" -eq 1 ] && grep -q 'open carried finding(s) under verdict PASS;' <<<"$out"; }
arm_V3() { run "$1" "$RQ/docs/reviews/s13/6-qa-validation.md" "$RQ/docs/reviews/s13/6-qa-validation-p2.md"
           [ "$rc" -eq 2 ] && grep -q '^REFUSED: .*more than one verdict value' <<<"$out"; }
arm_V4() { run "$1" "$RQ/docs/reviews/s14/6-qa-validation.md" "$RQ/docs/reviews/s14/6-qa-validation-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 2 prior.*1 open, verdict NEEDS_REWORK' <<<"$out"; }
arm_V5() { run "$1" "$RQ/docs/reviews/s15/6-qa-validation.md" "$RQ/docs/reviews/s15/6-qa-validation-p2.md"
           [ "$rc" -eq 1 ] && grep -q 'under verdict NEEDS_REWORK-pending;' <<<"$out"; }

ARMS="C F1 F2 N2 F3 N3 F4 F5 F6 T P1 P2 P3 W1 W2 D1 S1 S3 L1 S4 S5 S6 S7 WR1 WR2 WR3 K1 K2 K3 K4 K5 G1 G2 H1 H2 QL QF QP LIST TA TQ TB TC QU1 QU2 QU3 V1 V2 V3 V4 V5"
cp "$V" "$VI" || { echo "FIXTURE ERROR: cannot place the gitignored program at $VI" >&2; exit 2; }
src "$V"
B_all=0; arms_bad=0
for a in $ARMS; do
  if "arm_$a" "$V"; then ok "$a"; else arms_bad=$((arms_bad + 1)); bad "$a: rc=$rc out=$(head -2 <<<"$out" | tr '\n' ' ')"; fi
done
if [ "$arms_bad" -eq 0 ]; then ok "every arm green on the unmutated validator"; B_all=1; fi

# ---- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome ------------------
# Outcomes, exit x output class: 0 a PASS line on stdout; 1 FAIL lines on stdout; 2 a REFUSED usage line on stdout;
# 0 under --list, carry strings on stdout and NOTEs on stderr; 0 under --help, the header (the one self-read, through
# ${BASH_SOURCE[0]}). One `FXCELL=<id> bash "$V"` start per outcome, each compared with the in-process call on the
# same input: stdout, stderr and exit separately, byte for byte. Each cell also asserts its own outcome (a positive
# conjunct, so two runs that both printed nothing cannot read as equivalent), and the pass and fail cells must differ.
EQ="$WORK/eq"; mkdir -p "$EQ" || exit 2
eqv() { # <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  own "$V"
  ( set +o pipefail; cd "$WORK" && vcf_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ( cd "$WORK" && FXCELL="$id" bash "$V" "$@" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(head -3 "$EQ/$1.ip.out")" "$(head -3 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(head -3 "$EQ/$1.cl.out")" "$(head -3 "$EQ/$1.cl.err")"; }
if eqv cli-pass "$S/merged.md" "$S/all.md" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] \
   && grep -q '^PASS: 3 prior' "$EQ/cli-pass.cl.out" && [ ! -s "$EQ/cli-pass.cl.err" ]; then
  ok "cli-pass: the program passes merged.md into all.md exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with PASS: 3 prior ($(eq_twin cli-pass))"; fi
if eqv cli-fail "$S/merged.md" "$S/miss.md" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] \
   && grep -qF "has no carried: line in $S/miss.md: $H2" "$EQ/cli-fail.cl.out" && [ ! -s "$EQ/cli-fail.cl.err" ]; then
  ok "cli-fail: the program refuses miss.md's dropped carry exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 naming the dropped carry ($(eq_twin cli-fail))"; fi
if eqv cli-refuse && [ "$(cat "$EQ/cli-refuse.cl.rc")" = 2 ] \
   && grep -q '^REFUSED: usage: validate-carried-findings.sh ' "$EQ/cli-refuse.cl.out" && [ ! -s "$EQ/cli-refuse.cl.err" ]; then
  ok "cli-refuse: the program refuses no arguments exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-refuse: the program and the in-process call differ, or the outcome is not exit 2 with the usage line ($(eq_twin cli-refuse))"; fi
if eqv cli-list --list "$S/span-prior.md" && [ "$(cat "$EQ/cli-list.cl.rc")" = 0 ] \
   && [ "$(cat "$EQ/cli-list.cl.out")" = "I1. stale cache" ] && [ "$(grep -c '^NOTE:' "$EQ/cli-list.cl.err")" -eq 2 ]; then
  ok "cli-list: the program lists span-prior.md's carry string and NOTEs exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-list: the program and the in-process call differ, or the outcome is not exit 0 with one carry string and two NOTEs ($(eq_twin cli-list))"; fi
if eqv cli-help --help && [ "$(cat "$EQ/cli-help.cl.rc")" = 0 ] \
   && grep -q '^# validate-carried-findings.sh -- a gate-1 re-review' "$EQ/cli-help.cl.out" \
   && grep -qF '#   (core/fixtures/carried-findings).' "$EQ/cli-help.cl.out" && ! grep -q 'vcf_main' "$EQ/cli-help.cl.out"; then
  ok "cli-help: the program prints its header and nothing past it exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-help: the program and the in-process call differ, or the header is cut short or runs into vcf_main ($(eq_twin cli-help))"; fi
if ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-fail.cl.out" && ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-fail.cl.rc"; then
  ok "cli cells discriminate: the passing and the refusing input give different stdout and exit"
else bad "cli cells do not discriminate: cli-pass and cli-fail gave the same stdout or exit"; fi

# ---- mutants: each removes one rule and must flip exactly the arms it names --------------------
M="$WORK/mut"; mkdir -p "$M" || exit 2
# mut <name> <sed expression> -> path of the mutated copy, or empty when the sed matched nothing. The copy sits at
# $M/<name>/core/scripts/validate-carried-findings.sh, the subject's own relative path, so its fx_inproc pass counts
# under the inproc: row; score sources it once.
mut() {
  local dst="$M/$1/core/scripts/validate-carried-findings.sh"
  mkdir -p "${dst%/*}" || { echo ""; return; }
  sed -e "$2" "$V" > "$dst" || { echo ""; return; }
  if cmp -s "$V" "$dst"; then echo ""; else echo "$dst"; fi
}
# mut_after <name> <exact anchor line> <line to insert after it>
mut_after() {
  local dst="$M/$1/core/scripts/validate-carried-findings.sh"
  mkdir -p "${dst%/*}" || { echo ""; return; }
  CF_A="$2" CF_X="$3" awk '{ print } $0 == ENVIRON["CF_A"] { print ENVIRON["CF_X"] }' "$V" > "$dst" || { echo ""; return; }
  if cmp -s "$V" "$dst"; then echo ""; else echo "$dst"; fi
}
same_set() { # <arms a> <arms b> -> 0 when the two blank-separated arm lists name the same arms (no arm repeats)
  local x n=0 m=0
  for x in $1; do n=$((n + 1)); case " $2 " in *" $x "*) ;; *) return 1 ;; esac; done
  for x in $2; do m=$((m + 1)); done
  [ "$n" -eq "$m" ]
}
score() { # <mutant path> "<arms that trip>" <description> <twin arm> <mutant name>
  # Per push: the deciding arm (the first arm named) must trip under the mutant and the twin, an arm the matrix
  # shows GREEN for it, must pass. Under --matrix every arm runs against the mutant, the exact vector is
  # enforced, and a row is printed per arm. The kill is emitted only through mutant_killed, gated on B_all,
  # which is set only when every unmutated arm held in this run.
  local mv="$1" want="$2" desc="$3" twin="$4" name="$5" a dec why="" died=""
  dec="${want%% *}"
  [ -n "$mv" ] || { bad "MUTANT $desc: the mutation did not apply"; return; }
  [ "$mv" = "$LOADED" ] || src "$mv"   # selfloc's copy is sourced (once) before its differ cell, never twice
  if [ "$MATRIX" = 1 ]; then
    MWIDE=$((MWIDE + 1))
    for a in $ARMS; do if "arm_$a" "$mv"; then mcell "$name" "$a" 0; else died="$died $a"; mcell "$name" "$a" 1; fi; done
    # The vector is compared as a SET: want names the per-push deciding arm first, died lists arms in ARMS order.
    if same_set "$died" "$want"; then mutant_killed "$B_all" "$name" "MUTANT $name ($desc): deciding arm $dec dead, twin $twin green, vector exact: $want"
    else bad "MUTANT $name ($desc): arms that died:${died:- none} (want exactly $want)"; fi
    return
  fi
  if "arm_$dec" "$mv"; then why="deciding arm $dec survived"; fi
  "arm_$twin" "$mv" || why="$why twin $twin died"
  if [ -z "$why" ]; then mutant_killed "$B_all" "$name" "MUTANT $name ($desc): deciding arm $dec dead, twin $twin green"
  else bad "MUTANT $name ($desc): $why"; fi
}
# Every arm whose verdict IS a missing carry dies: F1, the id near-misses K2/K5, the ignored G1.
score "$(mut nocarry '/has no carried: line in/{n;s/fails=\$((fails + 1))/:/;}')" "F1 K2 K5 G1 QF TQ QU1 QU2" "a missing carry is not counted" F2 nocarry
# Gate 2: the qa.md key removed, so a pass run against a qa.md without the section is checked.
score "$(mut nokey 's/\*-qa-validation-p\[0-9\]\*\.md) G2=1 ;;/*-qa-validation-p[0-9]*.md) G2=0 ;;/')" "QL QU3" "the gate-2 qa.md key removed" F1 nokey
# Gate 2 fail-closed: qa.md unreadable at the reviewed-sha acquits (the on-disk read and the
# no-qa.md bind both pre-empted). QU1 and QU2 die; the QU3 near-miss is LEGACY either way.
score "$(mut qaacquit 's/^  QA_SRC=""; QA_SEC=""; QWHY=""$/  QA_SRC="none"; QA_SEC=0; QWHY=""/')" "QU1 QU2" "an unreadable qa.md acquits a gate-2 pass" QU3 qaacquit
score "$(mut appr 's/NEEDS_REWORK|BLOCKED) ;;/NEEDS_REWORK|BLOCKED|APPROVED) ;;/')" F2 "an open carried finding under APPROVED is accepted" N2 appr
score "$(mut anyopen 's/^    NEEDS_REWORK|BLOCKED) ;;/    __NEVER__) ;;/')" "N2 V1 V4" "an open carried finding fails under every verdict" F2 anyopen
# The verdict reader: the one-line qa.md form dropped (V1 dies: refused, no verdict read); two
# different values not refused; a suffixed value read as its prefix.
score "$(mut noline 's/^    \/\^Verdict:\/ { rec(val(substr(t, 9))) }/    0 { rec(val(substr(t, 9))) }/')" "V1 V2 V3 V5" "the one-line Verdict: form is not read" V4 noline
score "$(mut twoval 's/^    \*"\$NL"\*) refuse "\$CUR carries \$n_open open carried finding(s) and more than one/    __never__) refuse "\$CUR carries \$n_open open carried finding(s) and more than one/')" V3 "two different verdict values are not refused" V2 twoval
score "$(mut prefix 's/if (c == "" || c ~ \/\[ .,()\*\]\/) return r }/return r }/')" V5 "a suffixed verdict reads as its prefix" V1 prefix
# The UNPARSED rule binds a dropped finding in a post-rule prior: a bullet outside a repository
# (F3), a bullet after the pull (S3), a bullet in a lead-in (S5), a bold id line in a lead-in (S7).
score "$(mut unparsed 's/lab != "") print "UNPARSED\\t" sev/lab != "") print "LEADIN\\t" sev/')" "F3 S3 S5 S7" "a dropped finding in a post-rule prior is read as lead-in prose" S4 unparsed
score "$(mut boldlead 's/ || lab != "") print "UNPARSED/) print "UNPARSED/')" S7 "a bold finding-id line in a post-rule lead-in is prose" S5 boldlead
score "$(mut leadfail 's/else print "LEADIN\\t" sev/else print "UNPARSED\\t" sev/')" "S3 S4 WR3" "lead-in prose in a post-rule prior fails" S5 leadfail
# The wrapped-label rule: reverted, a marked wrapped label is lead-in prose and carries nothing
# (WR1); widened to any unclosed bold span, a wrapped non-id span fails (WR3).
score "$(mut wrapoff 's/else if (wrap) print "UNPARSED/else if (0) print "UNPARSED/')" WR1 "a wrapped finding-id label in a post-rule prior is lead-in prose" WR3 wrapoff
score "$(mut wrapany 's/else if (e == 0 && norm(b) ~ .*) wrap = 1/else if (e == 0) wrap = 1/')" WR3 "any unclosed bold span in a post-rule prior is a wrapped label" WR1 wrapany
# The None rule is read by both a None-only prior (N3) and a lead-in opening with "None." (S4).
score "$(mut nonebul 's/^    if (l ~ \/\^none(\[\^a-z\]|\$)\/) next/    if (0) next/')" "N3 S4" "a None line is read as an unparsed finding" S5 nonebul
score "$(mut sep 's/if (st == "" || h == "") print "BAD/if (0) print "BAD/')" F4 "a malformed carried line is silently ignored" F1 sep
# The fence rule in the CARRIED reader only: the second fence line of the file is that reader's.
score "$(mut cfence '/^carried="/,/^                else print/{/fence != "" {/s/fence != "" {/0 {/;}')" F5 "a fenced carried line counts as an answer" F4 cfence
score "$(mut sect 's/if ((fs && sev != "") || top) { d = norm/if (sev != "" || top) { d = norm/')" F6 "a heading outside ## Findings is a prior finding" C sect
# Top-level findings: the subsection-only read restored (TA, TQ die); a top level opened by every
# `## ` (TB dies); a `### Notes` that keeps the top level open (TC dies).
score "$(mut subonly 's/if ((fs && sev != "") || top) { d = norm/if (fs \&\& sev != "") { d = norm/')" "TA TQ" "a #### directly under ## Findings is not a finding (subsection-only read)" TB subonly
score "$(mut topany 's/sev = ""; top = fs; next }/sev = ""; top = 1; next }/')" TB "a #### directly under any ## section is a finding" TA topany
score "$(mut topnotes 's/sub(\/\^\\\*\*\/, "", h); top = 0$/sub(\/^\\**\/, "", h); top = (h ~ \/^notes\/ ? top : 0)/')" TC "a #### under ### Notes keeps the top level open" TA topnotes
# Pre-migration, one mutant per branch of the rule.
score "$(mut vaddbinds 's/adds validate-carried-findings.sh'"'"' "\$TOP"; return 0; }/adds validate-carried-findings.sh'"'"' "$TOP"; return 1; }/')" W1 "a branch that never received the program binds" W2 vaddbinds
score "$(mut descends 's/^  git -C "\$TOP" merge-base --is-ancestor "\$VADD" "\$r" 2>\/dev\/null && return 1/  return 1/')" P1 "a review committed before the pull binds" P2 descends
score "$(mut untracked 's/^  \[ -n "\$r" \] || return 1/  [ -n "$r" ] || return 0/')" P3 "an untracked review is exempt" P2 untracked
# Exempt every committed review: the ancestry test is the one line every bound, committed arm
# reads, so this mutant names all of them.
score "$(mut pmalways 's/^  git -C "\$TOP" merge-base --is-ancestor "\$VADD" "\$r" 2>\/dev\/null && return 1/  :/')" "P2 W2 D1 S1 S3 L1 S6 H2 QL QF QP TQ QU1 QU2 QU3 V1 V2 V3 V4 V5" "every committed review is exempt" P1 pmalways
score "$(mut recent 's/log --diff-filter=A --reverse --format=%H HEAD/log --diff-filter=A --format=%H HEAD/')" D1 "the MOST RECENT add is the epoch (revert and re-add acquits)" P2 recent
# The unmutated copy: the mutant harness (install of a byte-identical copy) running the shipped behaviour green, on
# C, F1 and K2 and on the topology arms the selfloc cells below read (P1 S6 G1 G2 H1 W1 W2).
CTL="$M/ctl/core/scripts/validate-carried-findings.sh"
mkdir -p "${CTL%/*}" && cp "$V" "$CTL" && cmp -s "$V" "$CTL" || { echo "FIXTURE ERROR: cannot copy the unmutated control" >&2; exit 2; }
src "$CTL"
arm_C "$CTL" && arm_F1 "$CTL" && arm_K2 "$CTL" \
  && ok "CONTROL unmutated-copy: arms C, F1 and K2 pass against a byte-identical installed copy" \
  || bad "CONTROL unmutated-copy: an unmutated installed copy did not pass arms C, F1 and K2"
TOPO="P1 S6 G1 G2 H1 W1 W2"
topo_vec() { local a v=""; for a in $TOPO; do if "arm_$a" "$1"; then v="$v $a:pass"; else v="$v $a:FAIL"; fi; done; printf '%s' "${v# }"; }
CTL_TOPO="$(topo_vec "$CTL")"; own "$CTL"
if [ "$CTL_TOPO" = "P1:pass S6:pass G1:pass G2:pass H1:pass W1:pass W2:pass" ]; then
  ok "CONTROL unmutated-copy: the topology arms P1 S6 G1 G2 H1 W1 W2 all pass against the unmutated copy"
else bad "CONTROL unmutated-copy: the unmutated copy did not pass every topology arm ($CTL_TOPO)"; fi
# selfloc: the running copy must sit inside the review's checkout. Its copy is sourced from R, base VR's checkout, at
# the subject's declared path ($R/core/scripts/validate-carried-findings.sh: R tracks the program at scripts/ai-dlc/,
# so this untracked copy never reaches locate's untracked-program branch). WHY THE WANT IS "W1 S6 G1 G2 H1", NOT W1:
# the mutated property is LOCATION-DEPENDENCE -- the copy returns 1 from locate() whenever it does not sit under the
# review's TOP -- and one sourced copy sits under one TOP. Every arm whose review lives in another world trips on
# exactly that property: W1 (WT), S6 (WS), G1/G2 (RI), H1 (the shallow clone). At the command line each topology arm
# ran a copy installed in its own checkout, which confined it to W1; restoring that needs one copy per world, re-sourced
# as the arms switch worlds, for one mutant. Do not narrow the want back to W1. P1 (TOP = R) is where the mutant
# differs from an unconditional `return 1`, and the vacuity cell after the score holds that by name.
SLR="$R/core/scripts/validate-carried-findings.sh"
SLM="$(mut_after selfloc '  TOP="$(cd "$TOP" && pwd -P)" || return 1' '  case "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/" in "$TOP"/*) ;; *) return 1 ;; esac')"
R1M="$(mut_after ret1 '  TOP="$(cd "$TOP" && pwd -P)" || return 1' '  return 1')"
[ -n "$SLM" ] && [ -n "$R1M" ] && mkdir -p "${SLR%/*}" && cp "$SLM" "$SLR" \
  || { echo "FIXTURE ERROR: the selfloc or return-1 copy did not apply, or could not be placed at $SLR" >&2; exit 2; }
src "$SLR"
SL_TOPO="$(topo_vec "$SLR")"; own "$SLR"
# Before any kill is read: the mutated copy must ANSWER DIFFERENTLY from the unmutated one on the widened control.
if [ "$SL_TOPO" != "$CTL_TOPO" ]; then ok "selfloc differs from the unmutated copy on the topology arms ($SL_TOPO)"
else bad "selfloc answers exactly as the unmutated copy on every topology arm -- a mutant that changes nothing there"; fi
score "$SLR" "W1 S6 G1 G2 H1" "the running copy must sit inside the review's checkout" W2 selfloc
# THE VACUITY CELL: a copy that returns 1 unconditionally after TOP= is resolved, sourced from the SAME path. It must
# FAIL P1 where selfloc PASSES P1 -- named arm against named arm -- or selfloc is indistinguishable from it.
cp "$R1M" "$SLR" || { echo "FIXTURE ERROR: cannot place the return-1 copy at $SLR" >&2; exit 2; }
src "$SLR"
if arm_P1 "$SLR"; then R1_P1=pass; else R1_P1=FAIL; fi
case " $SL_TOPO " in *" P1:pass "*) SL_P1=pass ;; *) SL_P1=FAIL ;; esac
if [ "$SL_P1" = pass ] && [ "$R1_P1" = FAIL ]; then
  ok "VACUITY selfloc: selfloc passes P1 and an unconditional return 1 after TOP= fails P1, both sourced from R's core/scripts/validate-carried-findings.sh"
else bad "VACUITY selfloc: selfloc P1=$SL_P1, return-1 P1=$R1_P1 -- selfloc is not distinguished from an unconditional return 1"; fi
rm -f "$SLR"
# The ignored program binds; the mutant reads it as pre-migration.
score "$(mut ignpend 's/^  \[ -z "\$UNC" \] || return 1$/  :/')" "G1 G2" "a gitignored program reads PENDING" W1 ignpend
score "$(mut shallow 's/= "true" \] &&$/= "__never__" ] \&\&/')" H1 "a shallow repository is read, not refused" H2 shallow
# Which prior is held to the heading form: marker AND not committed before the add.
score "$(mut alwayslabels 's/\[ "\$EARLY" -eq 0 \] && POST=1$/[ "$EARLY" -eq 0 ] \&\& POST=0/')" "F3 S3 S4 S5 S7 WR1 WR3" "every prior is read by label (the post-rule marker ignored)" S6 alwayslabels
score "$(mut markonly 's/^\[ "\$MARK" = "1" \] && \[ "\$EARLY" -eq 0 \] && POST=1$/[ "$MARK" = "1" ] \&\& POST=1/')" S6 "a marked prior committed before the pull is held to the form" L1 markonly
score "$(mut earlyonly 's/^\[ "\$MARK" = "1" \] && \[ "\$EARLY" -eq 0 \] && POST=1$/[ "$EARLY" -eq 0 ] \&\& POST=1/')" "L1 WR2 K1 K2 K3 K4 K5 LIST" "a prior committed after the add is held to the form whatever it carries" S6 earlyonly
# The label reading.
score "$(mut nolabel 's/lab = c; id = substr(c, 1, RLENGTH)/lab = ""; id = ""/')" "S1 L1 S6 S7 K1 K2 K3 K4 K5 H2 LIST" "a bold-labelled finding is not carried" S4 nolabel
# Only the id-boundary guard is removed: match() still runs, so a non-id span gets an empty id.
score "$(mut anybold 's/if (match(c, \/\^\[A-Za-z\]+-?\[0-9\]+\/) && substr(c, RLENGTH + 1, 1) !~ \/\[A-Za-z0-9\]\/)/if (match(c, \/^[A-Za-z]+-?[0-9]+\/) || 1)/')" "S1 L1 S6 H2 LIST" "any bold span is a finding label" K1 anybold
score "$(mut notefail 's/if (!labd) print "NOTE\\t"/if (!labd) print "UNPARSED\\t"/')" "S1 L1 S6 WR2 H2 LIST" "an unlabelled pre-rule line fails" WR3 notefail
score "$(mut exactspan 's/uid="\$id"; fi$/uid=""; fi/')" K1 "a label prior is carried only by its exact span" K3 exactspan
score "$(mut idprefix 's/(ENVIRON\["CF_I"\] != "" && \$3 == ENVIRON\["CF_I"\])/(ENVIRON["CF_I"] != "" \&\& index($3, ENVIRON["CF_I"]) == 1)/')" K2 "an id answers any carried string it prefixes" K1 idprefix
score "$(mut nopunct 's/function key(s) { s = norm(s); sub(\/\[.:;, \\t\]+\$\/, "", s); return s }/function key(s) { return norm(s) }/')" K3 "trailing punctuation is significant" K1 nopunct
score "$(mut dupid 's/if (n\[i\] == 1) print i/print i/')" K5 "an id two labels share answers both" K2 dupid
score "$(mut listnone 's/printf .%s\\n. "\$disp"/:/')" "LIST TA" "--list prints no carry strings" K1 listnone
# A validator replaced by `exit 0` must fail every arm: its vcf_main is `exit 0`, behind the same guard.
STUB="$M/stub/core/scripts/validate-carried-findings.sh"
mkdir -p "${STUB%/*}" || exit 2
printf '#!/usr/bin/env bash\nvcf_main() { exit 0; }\n[ "${BASH_SOURCE[0]}" = "$0" ] || return 0\nvcf_main "$@"\n' > "$STUB"
src "$STUB"
died=""; for a in $ARMS; do if "arm_$a" "$STUB"; then mcell stub "$a" 0; else died="$died $a"; mcell stub "$a" 1; fi; done
src "$V"
if [ "$died" = " $ARMS" ]; then mutant_killed "$B_all" stub "MUTANT exit-0 stub: every arm dies"; else bad "MUTANT exit-0 stub: arms that died:${died:- none}"; fi
# The role file's template, mutated back to the bullet form it had and stripped of reviewed-sha:
# arm T alone reads it, so each must kill T.
for rm_ in bullet nosha; do
  case "$rm_" in
    bullet) sed -e 's/^#### <finding title>$/- [finding]/' "$ROLE" > "$M/role-$rm_.md" ;;
    nosha)  sed -e '/^reviewed-sha: <full frozen sha>$/d' "$ROLE" > "$M/role-$rm_.md" ;;
  esac
  if cmp -s "$ROLE" "$M/role-$rm_.md"; then bad "MUTANT role $rm_: the mutation did not apply"; continue; fi
  tpl_of "$M/role-$rm_.md" > "$S/template.md"
  if arm_T "$V"; then bad "MUTANT role $rm_: arm T survived"; mcell "role-$rm_" T 0
  else
    mcell "role-$rm_" T 1
    if arm_C "$V"; then mutant_killed "$B_all" "role-$rm_" "MUTANT role $rm_: dead by arm T, twin C green"; else bad "MUTANT role $rm_: twin C died"; fi
  fi
done
tpl_of "$ROLE" > "$S/template.md"
arm_T "$V" && ok "T restored" || bad "T did not hold after restoring the template"

# Plain-run arm: a plain run executes no matrix-only cell, and a --matrix run executes some.
if [ "$MATRIX" = 0 ]; then
  if [ "$MWIDE" -eq 0 ] && [ "$MROWS" -eq 0 ]; then ok "plain run: no matrix-only cell ran and no matrix row was printed"; else bad "plain run: matrix-only cells ran (wide=$MWIDE rows=$MROWS)"; fi
else
  if [ "$MWIDE" -gt 0 ] && [ "$MROWS" -gt 0 ]; then ok "matrix run: $MWIDE mutants measured across every arm ($MROWS rows)"; else bad "matrix run: no rows were printed (wide=$MWIDE rows=$MROWS)"; fi
fi

if [ "$fails" -eq 0 ]; then echo "carried-findings: PASS"; exit 0; fi
echo "carried-findings: $fails FAILED"; exit 1
