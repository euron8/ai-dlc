#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# THE FORM ARMS (S4, S5, S7) take a post-rule heading prior with lead-in prose before its first
# `#### `: prose is a NOTE (S4), a bullet (S5) or a bold finding-id line (S7) there FAILS.
# THE WRAPPED-LABEL ARMS (WR1-WR3) take graph s308 1-code-review.md:67's Critical, a bold
# finding-id label whose closing `**` is on the next line: marked it FAILS and --list exits 1 with
# no carry string (WR1); unmarked it is a NOTE (WR2, the pre-rule price above); marked, a wrapped
# bold span opening with no finding id is lead-in prose (WR3).
# THE MATCHING ARMS (K1-K5): a label prior carried by id alone, I11 never answering I1, trailing
# punctuation dropped, a span that is exactly an id, an id two labels share answering neither.
# LIST: `--list` prints exactly the carry strings on stdout, NOTEs on stderr.
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
. "$HERE/../lib/matrix.sh"
. "$HERE/../lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
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

run() { out="$(bash "$1" "$2" "$3" 2>&1)"; rc=$?; }

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
# install <validator>: every topology arm runs the copy that sits in its checkout.
install() { mkdir -p "$RI/scripts/ai-dlc" && cp "$1" "$VR" && cp "$1" "$VS" && cp "$1" "$VD" && cp "$1" "$VI" && cp "$1" "$VH" && cp "$1" "$VF" ||
  { echo "FIXTURE ERROR: install failed" >&2; exit 2; }; }

# ---- arms ------------------------------------------------------------------------------------
# arm_<id> <validator> -> 0 when the arm holds. The topology arms read the installed copies.
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
arm_P1() { run "$VR" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PENDING:' <<<"$out"; }
arm_P2() { run "$VR" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p3.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_P3() { run "$VR" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p4.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_W1() { run "$VR" "$WT/docs/reviews/s2/1-code-review.md" "$WT/docs/reviews/s2/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PENDING:.*no commit on the history of HEAD' <<<"$out"; }
arm_W2() { run "$VR" "$WP/docs/reviews/s2/1-code-review.md" "$WP/docs/reviews/s2/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_D1() { run "$VD" "$WR/docs/reviews/s3/1-code-review.md" "$WR/docs/reviews/s3/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_S1() { run "$VS" "$WS/docs/reviews/s4/1-code-review.md" "$WS/docs/reviews/s4/1-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out" && [ "$(grep -c '^NOTE:' <<<"$out")" -eq 2 ]; }
arm_S3() { run "$VS" "$WS/docs/reviews/s4/2-code-review.md" "$WS/docs/reviews/s4/2-code-review-p2.md"
           [ "$rc" -eq 1 ] && grep -q 'Important finding that is not a "#### " heading' <<<"$out" && grep -q '^NOTE:.*lead-in prose' <<<"$out"; }

# L1: the lazily persisted pre-rule pass 1 (no marker, committed after the pull) is read by label.
arm_L1() { run "$VS" "$WS/docs/reviews/s4/3-code-review.md" "$WS/docs/reviews/s4/3-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out" && [ "$(grep -c '^NOTE:' <<<"$out")" -eq 2 ]; }
# S4/S5: a post-rule heading prior; lead-in prose is a NOTE, a bullet in the lead-in FAILS.
arm_S4() { run "$1" "$S/leadin.md" "$S/leadin-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 2 prior' <<<"$out" && [ "$(grep -c '^NOTE:.*lead-in prose' <<<"$out")" -eq 1 ]; }
arm_S7() { run "$1" "$S/leadin-bold.md" "$S/leadin-p2.md"
           [ "$rc" -eq 1 ] && grep -q 'Important finding that is not a "#### " heading' <<<"$out" && ! grep -q '^FAIL: prior' <<<"$out"; }
# S6: a MARKED prior committed before the pull is still read by label (both conjuncts decide).
arm_S6() { run "$VS" "$WS/docs/reviews/s4/4-code-review.md" "$WS/docs/reviews/s4/4-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out" && [ "$(grep -c '^NOTE:' <<<"$out")" -eq 2 ]; }
arm_S5() { run "$1" "$S/leadin-bullet.md" "$S/leadin-p2.md"
           [ "$rc" -eq 1 ] && grep -q 'Important finding that is not a "#### " heading' <<<"$out" && ! grep -q '^FAIL: prior' <<<"$out"; }
# WR: a wrapped bold finding-id label. WR1 marked -> FAIL on form, and --list exits 1 printing no
# carry string; WR2 unmarked (pre-rule) -> PASS with the label as a NOTE; WR3 marked, a wrapped
# bold span with no finding id -> lead-in prose.
arm_WR1() { run "$1" "$S/wrap-mark.md" "$S/empty.md"
            [ "$rc" -eq 1 ] && grep -q 'Critical finding that is not a "#### " heading' <<<"$out" || return 1
            local a; a="$(bash "$1" --list "$S/wrap-mark.md" 2>/dev/null)"; [ "$?" -eq 1 ] && [ -z "$a" ]; }
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
arm_G1() { run "$VI" "$RI/docs/reviews/s5/1-code-review.md" "$RI/docs/reviews/s5/1-code-review-p2.md"
           [ "$rc" -eq 1 ] && grep -q '^NOTE: .* is gitignored in .*the rule binds' <<<"$out" && grep -q '^FAIL: prior' <<<"$out"; }
arm_G2() { run "$VI" "$RI/docs/reviews/s5/2-code-review.md" "$RI/docs/reviews/s5/2-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out" && grep -q '^NOTE: .* is gitignored' <<<"$out"; }
# H1: a shallow repository is refused naming why; H2 the full clone of the same pair PASSES.
arm_H1() { run "$VH" "$WORK/shallow/docs/reviews/s4/1-code-review.md" "$WORK/shallow/docs/reviews/s4/1-code-review-p2.md"
           [ "$rc" -eq 2 ] && grep -q '^REFUSED: .* is a shallow repository' <<<"$out"; }
arm_H2() { run "$VF" "$WORK/full/docs/reviews/s4/1-code-review.md" "$WORK/full/docs/reviews/s4/1-code-review-p2.md"
           [ "$rc" -eq 0 ] && grep -q '^PASS: 1 prior' <<<"$out"; }
# LIST: --list prints exactly the carry strings on stdout, in file order, and NOTEs on stderr.
arm_LIST() { local a b
             a="$(bash "$1" --list "$S/merged.md" 2>/dev/null)" || return 1
             [ "$a" = "$H1$NLF$H3$NLF$H2" ] || return 1
             b="$(bash "$1" --list "$S/span-prior.md" 2>/dev/null)" || return 1
             [ "$b" = "I1. stale cache" ] || return 1
             [ "$(bash "$1" --list "$S/span-prior.md" 2>&1 >/dev/null | grep -c '^NOTE:')" -eq 2 ]; }
NLF='
'

ARMS="C F1 F2 N2 F3 N3 F4 F5 F6 T P1 P2 P3 W1 W2 D1 S1 S3 L1 S4 S5 S6 S7 WR1 WR2 WR3 K1 K2 K3 K4 K5 G1 G2 H1 H2 LIST"
install "$V"
B_all=0; f_base=$fails
for a in $ARMS; do
  if "arm_$a" "$V"; then ok "$a"; else bad "$a: rc=$rc out=$(head -2 <<<"$out" | tr '\n' ' ')"; fi
done
if [ "$fails" -eq "$f_base" ]; then B_all=1; fi

# ---- mutants: each removes one rule and must flip exactly the arms it names --------------------
M="$WORK/mut"; mkdir -p "$M" || exit 2
# mut <name> <sed expression> -> path of the mutated copy, or empty when the sed matched nothing
mut() {
  local dst="$M/$1.sh"
  sed -e "$2" "$V" > "$dst" || { echo ""; return; }
  if cmp -s "$V" "$dst"; then echo ""; else echo "$dst"; fi
}
# mut_after <name> <exact anchor line> <line to insert after it>
mut_after() {
  local dst="$M/$1.sh"
  CF_A="$2" CF_X="$3" awk '{ print } $0 == ENVIRON["CF_A"] { print ENVIRON["CF_X"] }' "$V" > "$dst" || { echo ""; return; }
  if cmp -s "$V" "$dst"; then echo ""; else echo "$dst"; fi
}
score() { # <mutant path> "<arms that trip>" <description> <twin arm> <mutant name>
  # Per push: the deciding arm (the first arm named) must trip under the mutant and the twin, an arm the matrix
  # shows GREEN for it, must pass. Under --matrix every arm runs against the mutant, the exact vector is
  # enforced, and a row is printed per arm. The kill is emitted only through mutant_killed, gated on B_all,
  # which is set only when every unmutated arm held in this run.
  local mv="$1" want="$2" desc="$3" twin="$4" name="$5" a dec why="" died=""
  dec="${want%% *}"
  [ -n "$mv" ] || { bad "MUTANT $desc: the mutation did not apply"; return; }
  install "$mv"
  if [ "$MATRIX" = 1 ]; then
    MWIDE=$((MWIDE + 1))
    for a in $ARMS; do if "arm_$a" "$mv"; then mcell "$name" "$a" 0; else died="$died $a"; mcell "$name" "$a" 1; fi; done
    install "$V"
    if [ "$died" = " $want" ]; then mutant_killed "$B_all" "$name" "MUTANT $name ($desc): deciding arm $dec dead, twin $twin green, vector exact: $want"
    else bad "MUTANT $name ($desc): arms that died:${died:- none} (want exactly $want)"; fi
    return
  fi
  if "arm_$dec" "$mv"; then why="deciding arm $dec survived"; fi
  "arm_$twin" "$mv" || why="$why twin $twin died"
  install "$V"
  if [ -z "$why" ]; then mutant_killed "$B_all" "$name" "MUTANT $name ($desc): deciding arm $dec dead, twin $twin green"
  else bad "MUTANT $name ($desc): $why"; fi
}
# Every arm whose verdict IS a missing carry dies: F1, the id near-misses K2/K5, the ignored G1.
score "$(mut nocarry '/has no carried: line in/{n;s/fails=\$((fails + 1))/:/;}')" "F1 K2 K5 G1" "a missing carry is not counted" F2 nocarry
score "$(mut appr 's/NEEDS_REWORK|BLOCKED) ;;/NEEDS_REWORK|BLOCKED|APPROVED) ;;/')" F2 "an open carried finding under APPROVED is accepted" N2 appr
score "$(mut anyopen 's/^    NEEDS_REWORK|BLOCKED) ;;/    __NEVER__) ;;/')" N2 "an open carried finding fails under every verdict" F2 anyopen
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
score "$(mut sect 's/if (fs && sev != "") { d = norm/if (sev != "") { d = norm/')" F6 "a heading outside ## Findings is a prior finding" C sect
# Pre-migration, one mutant per branch of the rule.
score "$(mut vaddbinds 's/adds validate-carried-findings.sh'"'"' "\$TOP"; return 0; }/adds validate-carried-findings.sh'"'"' "$TOP"; return 1; }/')" W1 "a branch that never received the program binds" W2 vaddbinds
score "$(mut descends 's/^  git -C "\$TOP" merge-base --is-ancestor "\$VADD" "\$r" 2>\/dev\/null && return 1/  return 1/')" P1 "a review committed before the pull binds" P2 descends
score "$(mut untracked 's/^  \[ -n "\$r" \] || return 1/  [ -n "$r" ] || return 0/')" P3 "an untracked review is exempt" P2 untracked
# Exempt every committed review: the ancestry test is the one line every bound, committed arm
# reads, so this mutant names all of them.
score "$(mut pmalways 's/^  git -C "\$TOP" merge-base --is-ancestor "\$VADD" "\$r" 2>\/dev\/null && return 1/  :/')" "P2 W2 D1 S1 S3 L1 S6 H2" "every committed review is exempt" P1 pmalways
score "$(mut recent 's/log --diff-filter=A --reverse --format=%H HEAD/log --diff-filter=A --format=%H HEAD/')" D1 "the MOST RECENT add is the epoch (revert and re-add acquits)" P2 recent
score "$(mut_after selfloc '  TOP="$(cd "$TOP" && pwd -P)" || return 1' '  case "$(cd "$(dirname "$0")" && pwd -P)/" in "$TOP"/*) ;; *) return 1 ;; esac')" W1 "the running copy must sit inside the review's checkout" W2 selfloc
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
score "$(mut listnone 's/printf .%s\\n. "\$disp"/:/')" LIST "--list prints no carry strings" K1 listnone
# The unmutated copy: the mutant harness (install of a byte-identical copy) running the shipped behaviour green.
cp "$V" "$M/ctl.sh" && cmp -s "$V" "$M/ctl.sh" && install "$M/ctl.sh" && arm_C "$M/ctl.sh" && arm_F1 "$M/ctl.sh" && arm_K2 "$M/ctl.sh" \
  && ok "CONTROL unmutated-copy: arms C, F1 and K2 pass against a byte-identical installed copy" \
  || bad "CONTROL unmutated-copy: an unmutated installed copy did not pass arms C, F1 and K2"
install "$V"
# A validator replaced by `exit 0` must fail every arm.
printf '#!/usr/bin/env bash\nexit 0\n' > "$M/stub.sh"
install "$M/stub.sh"
died=""; for a in $ARMS; do if "arm_$a" "$M/stub.sh"; then mcell stub "$a" 0; else died="$died $a"; mcell stub "$a" 1; fi; done
install "$V"
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
