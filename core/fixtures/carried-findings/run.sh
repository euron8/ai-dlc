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
# that must PASS, and each mutant at the bottom (a copy of the validator with one rule removed)
# must flip exactly its own arm. A validator replaced by `exit 0` fails every offender arm.
#
# THE SEEDS ARE THE PRODUCER'S GRAMMAR, NOT THE READER'S. The prior files carry what
# merge-review-shards.sh writes for a sharded review (`## Shard: <k>`, the shard's own `# ` title,
# `reviewed-sha:`, its own `## Findings` with `### Critical` / `### Important`) and what a serial
# reviewer writes from code-reviewer.md's template (`### Critical (must fix before merge)`), and
# the heading text is copied from graph s318 story 2.4's pass-1 review.
#
# THE FALSE-POSITIVE SET, measured over graph's 58 tracked consecutive gate-1 pass pairs
# (s308-s318, shard files excluded) at graph 2026-10-14, the validator run in place (graph does
# not carry it, so nothing is exempt there):
#   29 pairs FAIL on a prior Critical/Important with no `carried:` line -- every one of them,
#      because graph has 0 files with a column-0 `carried:` line (control: 365 files carry a
#      column-0 `reviewed-sha:`). The s318 delta reviews answered their priors in a
#      "Pass-N Finding Disposition" table, the pre-rule form;
#   26 FAIL on a prior finding written as a bullet or bold line rather than a `#### ` heading,
#      all in sprints before s317, where the template still said `- [finding]`;
#    3 PASS: a prior with no Critical/Important finding.
#   That is 55 of 58, and 37 of the 40 APPROVED pairs, every one a review written before the
#   rule. It reached ZERO by the PENDING rule rather than by narrowing the grammar: on a
#   file:// clone of graph with the validator committed after the reviews (a consumer that
#   pulled), all 58 read PENDING, and the same s318 pass-2 re-committed after the pull, or left
#   untracked, binds (exit 1). The arm P below holds both directions on a seeded repository.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
V=""
d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  for c in "$d/core/scripts/validate-carried-findings.sh" "$d/scripts/ai-dlc/validate-carried-findings.sh"; do
    [ -z "$V" ] && [ -f "$c" ] && V="$c"
  done
  [ -n "$V" ] && break
  d="$(dirname "$d")"
done
[ -n "$V" ] || { echo "FIXTURE ERROR: validate-carried-findings.sh not found above $HERE in either layout; nothing was asserted" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-carried-findings.sh"
echo "carried-findings: subject = $V"

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

run() { out="$(bash "$1" "$2" "$3" 2>&1)"; rc=$?; }

# ---- arms ------------------------------------------------------------------------------------
# arm_<id> <validator> -> 0 when the arm holds against that validator
arm_C()  { run "$1" "$S/merged.md" "$S/all.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }
arm_F1() { run "$1" "$S/merged.md" "$S/miss.md"; [ "$rc" -eq 1 ] && grep -qF "has no carried: line in $S/miss.md: $H2" <<<"$out"; }
arm_F2() { run "$1" "$S/merged.md" "$S/open-appr.md"; [ "$rc" -eq 1 ] && grep -q 'open carried finding(s) under verdict APPROVED' <<<"$out"; }
arm_N2() { run "$1" "$S/merged.md" "$S/open-nr.md"; [ "$rc" -eq 0 ] && grep -q '1 open, verdict NEEDS_REWORK' <<<"$out"; }
arm_F3() { run "$1" "$S/bullet.md" "$S/empty.md"; [ "$rc" -eq 1 ] && grep -q 'Critical finding that is not a "#### " heading' <<<"$out"; }
arm_N3() { run "$1" "$S/none.md" "$S/empty.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 0 prior' <<<"$out"; }
arm_F4() { run "$1" "$S/merged.md" "$S/hyphen.md"; [ "$rc" -eq 1 ] && grep -q 'does not end in' <<<"$out"; }
arm_F5() { run "$1" "$S/merged.md" "$S/fenced.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior.*(3 resolved, 0 open' <<<"$out"; }
# The section grammar: a #### under an Important container outside ## Findings is not a prior
# finding, so the decoy review still carries exactly three. (The fenced heading and the Suggestion
# are already in every seed; arm C's count of 3 holds those.)
arm_F6() { run "$1" "$S/decoy.md" "$S/all.md"; [ "$rc" -eq 0 ] && grep -q '^PASS: 3 prior' <<<"$out"; }

ARMS="C F1 F2 N2 F3 N3 F4 F5 F6"
for a in $ARMS; do
  if "arm_$a" "$V"; then ok "$a"; else bad "$a: rc=$rc out=$(head -2 <<<"$out" | tr '\n' ' ')"; fi
done

# ---- arm P: pre-migration, both directions, on a seeded repository ------------------------------
G() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
R="$WORK/repo"; mkdir -p "$R/docs/reviews/s1" "$R/scripts/ai-dlc" || exit 2
G init -q "$R" || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
[ -d "$R/.git" ] || { echo "FIXTURE ERROR: $R is not a repository after init" >&2; exit 2; }
cp "$S/merged.md" "$R/docs/reviews/s1/1-code-review.md"
cp "$S/miss.md" "$R/docs/reviews/s1/1-code-review-p2.md"
G -C "$R" add -A && G -C "$R" commit -qm reviews || exit 2
cp "$V" "$R/scripts/ai-dlc/validate-carried-findings.sh"
G -C "$R" add -A && G -C "$R" commit -qm pull || exit 2
cp "$S/miss.md" "$R/docs/reviews/s1/1-code-review-p3.md"
G -C "$R" add -A && G -C "$R" commit -qm after || exit 2
cp "$S/miss.md" "$R/docs/reviews/s1/1-code-review-p4.md"
VR="$R/scripts/ai-dlc/validate-carried-findings.sh"
arm_P1() { run "$1" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p2.md"; [ "$rc" -eq 0 ] && grep -q '^PENDING:' <<<"$out"; }
arm_P2() { run "$1" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p3.md"; [ "$rc" -eq 1 ] && ! grep -q '^PENDING:' <<<"$out"; }
arm_P3() { run "$1" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p4.md"; [ "$rc" -eq 1 ] && ! grep -q '^PENDING:' <<<"$out"; }
for a in P1 P2 P3; do
  if "arm_$a" "$VR"; then ok "$a"; else bad "$a: rc=$rc out=$(head -2 <<<"$out" | tr '\n' ' ')"; fi
done
# The validator outside the review's repository (this fixture's own copy) never exempts.
if arm_P2 "$V" && run "$V" "$R/docs/reviews/s1/1-code-review.md" "$R/docs/reviews/s1/1-code-review-p2.md" && [ "$rc" -eq 1 ]; then
  ok "P4: a validator outside the review's repository binds the pre-rule pair"
else bad "P4: rc=$rc out=$(head -1 <<<"$out")"; fi

# ---- mutants: each removes one rule and must flip its own arm, and only that arm ----------------
M="$WORK/mut"; mkdir -p "$M" || exit 2
# mut <name> <sed expression> -> path of the mutated copy, or empty when the sed matched nothing
mut() {
  local dst="$M/$1.sh"
  sed -e "$2" "$V" > "$dst" || { echo ""; return; }
  if cmp -s "$V" "$dst"; then echo ""; else echo "$dst"; fi
}
score() { # <mutant> <arm that must die> <description>
  local mv="$1" want="$2" desc="$3" a died=""
  [ -n "$mv" ] || { bad "MUTANT $want ($desc): the mutation did not apply"; return; }
  for a in $ARMS; do "arm_$a" "$mv" || died="$died $a"; done
  if [ "$died" = " $want" ]; then ok "MUTANT $desc: killed by $want alone"
  else bad "MUTANT $desc: arms that died:${died:- none} (want exactly $want)"; fi
}
score "$(mut nocarry '/has no carried: line in/{n;s/fails=\$((fails + 1))/:/;}')" F1 "a missing carry is not counted"
score "$(mut appr 's/NEEDS_REWORK|BLOCKED) ;;/NEEDS_REWORK|BLOCKED|APPROVED) ;;/')" F2 "an open carried finding under APPROVED is accepted"
score "$(mut anyopen 's/^    NEEDS_REWORK|BLOCKED) ;;/    __NEVER__) ;;/')" N2 "an open carried finding fails under every verdict"
score "$(mut unparsed 's/if (l !~ \/\^none(\[\^a-z\]|\$)\/) print "UNPARSED/if (0) print "UNPARSED/')" F3 "a bullet-form prior finding is read as no finding"
score "$(mut nonebul 's/if (l !~ \/\^none(\[\^a-z\]|\$)\/) print "UNPARSED/print "UNPARSED/')" N3 "a None line is read as an unparsed finding"
score "$(mut sep 's/if (st == "" || h == "") print "BAD/if (0) print "BAD/')" F4 "a malformed carried line is silently ignored"
# The fence rule in the CARRIED reader only: the second fence line of the file is that reader's.
score "$(mut cfence '/^carried="/,/^                else print/{/fence != "" {/s/fence != "" {/0 {/;}')" F5 "a fenced carried line counts as an answer"
# The section rule: a #### outside ## Findings counts. Arm F6 (the decoy review) owns it.
score "$(mut sect 's/if (fs && sev != "") { print sev/if (sev != "") { print sev/')" F6 "a heading outside ## Findings is a prior finding"
# The pre-migration rule, both directions: never exempt (P1 dies), and exempt whenever both
# commits exist (P2 dies; P3, the untracked review, binds before the ancestry test is reached).
pm_never="$(mut pmnever 's/^if why="\$(pending_reason)"; then/if false; then/')"
pm_always="$(mut pmalways 's/^  git -C "\$top" merge-base --is-ancestor "\$v" "\$r" 2>\/dev\/null && return 1/  :/')"
for pair in "never:$pm_never:P1" "always:$pm_always:P2"; do
  nm="${pair%%:*}"; rest="${pair#*:}"; mv="${rest%:*}"; want="${rest##*:}"
  [ -n "$mv" ] || { bad "MUTANT pre-migration $nm: the mutation did not apply"; continue; }
  cp "$mv" "$VR" || exit 2
  died=""; for a in P1 P2 P3; do "arm_$a" "$VR" || died="$died $a"; done
  if [ "$died" = " $want" ]; then ok "MUTANT pre-migration $nm: killed by $want"
  else bad "MUTANT pre-migration $nm: arms that died:${died:- none} (want $want)"; fi
done
cp "$V" "$VR" || exit 2
# A validator replaced by `exit 0` must fail every offender arm.
printf '#!/usr/bin/env bash\nexit 0\n' > "$M/stub.sh"
died=""; for a in $ARMS; do "arm_$a" "$M/stub.sh" || died="$died $a"; done
[ "$died" = " C F1 F2 N2 F3 N3 F4 F5 F6" ] && ok "MUTANT exit-0 stub: every arm dies" || bad "MUTANT exit-0 stub: arms that died:${died:- none}"

if [ "$fails" -eq 0 ]; then echo "carried-findings: PASS"; exit 0; fi
echo "carried-findings: $fails FAILED"; exit 1
