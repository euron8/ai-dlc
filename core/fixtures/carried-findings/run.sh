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
#   S3 the same bullet prior committed AFTER the pull                  -> FAIL, not a heading
#
# THE FALSE-POSITIVE SET, measured over graph's 58 tracked consecutive gate-1 pass pairs
# (s308-s318, shard files excluded) on a file:// clone at graph 2026-10-14. graph tracks
# scripts/ai-dlc/ (62 files; check-ignore answers 1 for this program's path and for a control).
#   A  the program committed at HEAD, after every review, run in place: 58 PENDING, 0 FAIL.
#      That is the consumer that pulls mid-sprint; the zero is the PENDING rule, not a narrowed
#      grammar.
#   B  per pair, the program committed on the parent of the pass-M commit, then pass M (and its
#      prior, where graph committed both together) committed after it -- the rule binding a
#      review written after the pull: 55 FAIL, 3 PASS. 29 FAIL on a prior with no `carried:`
#      line (graph has 0 files with a column-0 `carried:` line; 365 carry `reviewed-sha:`), 26 on
#      a post-rule prior written as a bullet or bold line -- the form the old template's
#      `- [finding]` produced, which the template now replaces with `#### <finding title>`.
#   B2 a story spanning the pull: the prior committed BEFORE the program, pass M after it: 47
#      FAIL, every one a missing carry and none on form; 11 exit 0 (3 PASS clean, 8 PASS after
#      NOTE lines, 614 NOTEs in 13 pairs). The 8 are priors whose bold label wraps across lines
#      or carries no finding id, so nothing is carried from them: a pre-rule prior's form is
#      never a failure, and that is the price of not wedging a story spanning the pull.
#   Every B/B2 failure is a review written before the rule existed, re-committed after it on
#   purpose; none is a false positive against a review written under the rule.
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
# A pre-rule serial pass 1 whose findings are bullets; and one whose containers say None.
printf '# Code Review: S315-5\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n### Critical (must fix before merge)\n- **C1. No "Production Integrity Tests" section.** Role rule.\n\n### Important (should fix)\nNone.\n' > "$S/bullet.md"
printf '# Code Review: S318-1-2\n\n## Verdict\nAPPROVED\n\n## Findings\n\n### Critical (must fix before merge)\nNone.\n\n### Important (should fix, can be follow-up)\n- None.\n\n### Suggestions\n- tidy a name\n' > "$S/none.md"
p2 "$S/empty.md" APPROVED
# The span-the-pull prior: a prose line and a bold non-id line BEFORE the id-labelled bullet (both
# NOTEs, neither a finding), then the finding and its indented body.
printf '# Code Review: S318-2-1\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n### Important (should fix, can be follow-up)\nOne finding, read by hand.\n**Evidence:** the cache test below.\n- **I1. stale cache** the TTL entry outlives the test.\n  Its body continues here.\n' > "$S/span-prior.md"
p2 "$S/span-p2.md" APPROVED "$(c_res 'I1. stale cache')"
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
G -C "$WS" add -A && G -C "$WS" commit -qm "pre-rule pass 1" || exit 2
cp "$V" "$WS/scripts/ai-dlc/validate-carried-findings.sh"
G -C "$WS" add -A && G -C "$WS" commit -qm pull || exit 2
cp "$S/span-p2.md" "$WS/docs/reviews/s4/1-code-review-p2.md"
cp "$S/span-prior.md" "$WS/docs/reviews/s4/2-code-review.md"
cp "$S/span-p2.md" "$WS/docs/reviews/s4/2-code-review-p2.md"
G -C "$WS" add -A && G -C "$WS" commit -qm "post-rule pass 2, and a bullet pass 1 written after the pull" || exit 2
VS="$WS/scripts/ai-dlc/validate-carried-findings.sh"; VD="$WR/scripts/ai-dlc/validate-carried-findings.sh"
# install <validator>: every topology arm runs the copy that sits in its checkout.
install() { cp "$1" "$VR" && cp "$1" "$VS" && cp "$1" "$VD" || { echo "FIXTURE ERROR: install failed" >&2; exit 2; }; }

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
           [ "$rc" -eq 1 ] && grep -q 'Important finding that is not a "#### " heading' <<<"$out" && ! grep -q '^NOTE:' <<<"$out"; }

ARMS="C F1 F2 N2 F3 N3 F4 F5 F6 T P1 P2 P3 W1 W2 D1 S1 S3"
install "$V"
for a in $ARMS; do
  if "arm_$a" "$V"; then ok "$a"; else bad "$a: rc=$rc out=$(head -2 <<<"$out" | tr '\n' ' ')"; fi
done

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
score() { # <mutant> "<arms that must die>" <description>
  local mv="$1" want="$2" desc="$3" a died=""
  [ -n "$mv" ] || { bad "MUTANT $desc: the mutation did not apply"; return; }
  install "$mv"
  for a in $ARMS; do "arm_$a" "$mv" || died="$died $a"; done
  install "$V"
  if [ "$died" = " $want" ]; then ok "MUTANT $desc: killed by $want alone"
  else bad "MUTANT $desc: arms that died:${died:- none} (want exactly $want)"; fi
}
score "$(mut nocarry '/has no carried: line in/{n;s/fails=\$((fails + 1))/:/;}')" F1 "a missing carry is not counted"
score "$(mut appr 's/NEEDS_REWORK|BLOCKED) ;;/NEEDS_REWORK|BLOCKED|APPROVED) ;;/')" F2 "an open carried finding under APPROVED is accepted"
score "$(mut anyopen 's/^    NEEDS_REWORK|BLOCKED) ;;/    __NEVER__) ;;/')" N2 "an open carried finding fails under every verdict"
# The UNPARSED rule is what binds a bullet prior both outside a repository (F3) and after the pull
# (S3); the two arms share that one line, so the mutant names both.
score "$(mut unparsed 's/^    print "UNPARSED\\t" sev/    if (0) print "UNPARSED\\t" sev/')" "F3 S3" "a bullet-form prior finding is read as no finding"
score "$(mut nonebul 's/^    if (l ~ \/\^none(\[\^a-z\]|\$)\/) next/    if (0) next/')" N3 "a None line is read as an unparsed finding"
score "$(mut sep 's/if (st == "" || h == "") print "BAD/if (0) print "BAD/')" F4 "a malformed carried line is silently ignored"
# The fence rule in the CARRIED reader only: the second fence line of the file is that reader's.
score "$(mut cfence '/^carried="/,/^                else print/{/fence != "" {/s/fence != "" {/0 {/;}')" F5 "a fenced carried line counts as an answer"
score "$(mut sect 's/if (fs && sev != "") { print sev/if (sev != "") { print sev/')" F6 "a heading outside ## Findings is a prior finding"
# Pre-migration, one mutant per branch of the rule.
score "$(mut vaddbinds 's/adds validate-carried-findings.sh'"'"' "\$TOP"; return 0; }/adds validate-carried-findings.sh'"'"' "$TOP"; return 1; }/')" W1 "a branch that never received the program binds"
score "$(mut descends 's/^  git -C "\$TOP" merge-base --is-ancestor "\$VADD" "\$r" 2>\/dev\/null && return 1/  return 1/')" P1 "a review committed before the pull binds"
score "$(mut untracked 's/^  \[ -n "\$r" \] || return 1/  [ -n "$r" ] || return 0/')" P3 "an untracked review is exempt"
# Exempt every committed review: the ancestry test is the one line every bound, committed arm
# reads, so this mutant names all of them.
score "$(mut pmalways 's/^  git -C "\$TOP" merge-base --is-ancestor "\$VADD" "\$r" 2>\/dev\/null && return 1/  :/')" "P2 W2 D1 S1 S3" "every committed review is exempt"
score "$(mut recent 's/log --diff-filter=A --reverse --format=%H HEAD/log --diff-filter=A --format=%H HEAD/')" D1 "the MOST RECENT add is the epoch (revert and re-add acquits)"
score "$(mut_after selfloc '  TOP="$(cd "$TOP" && pwd -P)" || return 1' '  case "$(cd "$(dirname "$0")" && pwd -P)/" in "$TOP"/*) ;; *) return 1 ;; esac')" W1 "the running copy must sit inside the review's checkout"
# The pre-rule prior reading.
score "$(mut lenoff 's/then PRE=1; fi$/then PRE=0; fi/')" S1 "a pre-rule prior is held to the heading form"
score "$(mut preanc 's/if \[ -n "\$pr" \] && ! git -C "\$TOP" merge-base --is-ancestor "\$VADD" "\$pr" 2>\/dev\/null; then PRE=1; fi/if [ -n "$pr" ]; then PRE=1; fi/')" S3 "a prior written after the pull is read as pre-rule"
score "$(mut nolabel 's/if (lab ~ \/\^\[A-Za-z\]+-?\[0-9\]+\[\^A-Za-z0-9\]\/)/if (0)/')" S1 "a bold-labelled pre-rule finding is not carried"
score "$(mut anybold 's/if (lab ~ \/\^\[A-Za-z\]+-?\[0-9\]+\[\^A-Za-z0-9\]\/)/if (lab != "")/')" S1 "any bold span is a pre-rule finding label"
score "$(mut notefail 's/if (!labd) print "NOTE\\t"/if (!labd) print "UNPARSED\\t"/')" S1 "an unlabelled pre-rule line fails"
# A validator replaced by `exit 0` must fail every arm.
printf '#!/usr/bin/env bash\nexit 0\n' > "$M/stub.sh"
install "$M/stub.sh"
died=""; for a in $ARMS; do "arm_$a" "$M/stub.sh" || died="$died $a"; done
install "$V"
[ "$died" = " $ARMS" ] && ok "MUTANT exit-0 stub: every arm dies" || bad "MUTANT exit-0 stub: arms that died:${died:- none}"
# The role file's template, mutated back to the bullet form it had and stripped of reviewed-sha:
# arm T alone reads it, so each must kill T.
for rm_ in bullet nosha; do
  case "$rm_" in
    bullet) sed -e 's/^#### <finding title>$/- [finding]/' "$ROLE" > "$M/role-$rm_.md" ;;
    nosha)  sed -e '/^reviewed-sha: <full frozen sha>$/d' "$ROLE" > "$M/role-$rm_.md" ;;
  esac
  if cmp -s "$ROLE" "$M/role-$rm_.md"; then bad "MUTANT role $rm_: the mutation did not apply"; continue; fi
  tpl_of "$M/role-$rm_.md" > "$S/template.md"
  if arm_T "$V"; then bad "MUTANT role $rm_: arm T survived"; else ok "MUTANT role $rm_: killed by T"; fi
done
tpl_of "$ROLE" > "$S/template.md"
arm_T "$V" && ok "T restored" || bad "T did not hold after restoring the template"

if [ "$fails" -eq 0 ]; then echo "carried-findings: PASS"; exit 0; fi
echo "carried-findings: $fails FAILED"; exit 1
