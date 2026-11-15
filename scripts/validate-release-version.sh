#!/usr/bin/env bash
# validate-release-version.sh -- the release triple must agree: the commit subject,
# the VERSION file, and the CHANGELOG's top heading.
#
# WHY THIS EXISTS. Three things name the version of a release and nothing joined
# them. Every other consistency claim in this repo has an enforcer; this one was
# a convention, held by whoever remembered.
#
# It failed the first time it was tested. v0.124.1 was committed with the subject
# `fix(v0.124.1):` while VERSION still read `0.124.0` and CHANGELOG.md had no
# 0.124.1 heading at all. Nothing in the repo would have caught it -- pre-push runs
# six gates and none of them read a version -- and it was found only because the
# author happened to re-read the commit afterwards. A release whose three names
# disagree is a release nobody can identify later: the tag says one thing, the
# installed stamp another, and the changelog a third.
#
# check-version.sh does NOT cover this. It compares an INSTALLED consumer's stamp
# against the distribution's VERSION -- a different join, in the other direction,
# and it is silent about the CHANGELOG and about the commit that made the claim.
#
# THE PREDICATES, AND THE POPULATION THEY WERE MEASURED ON.
#
#   A. A subject carrying a `vX.Y.Z` token must match VERSION at that commit. A bare
#      `X.Y.Z` at the very START of the subject (`0.754.0 — ...`) counts too.
#      Measured: 16 of the last 30 version bumps carry the token, and all 16 match.
#      This is the predicate that catches the real defect above. A MISSING token is
#      not a failure -- 14 of those 30 predate the convention entirely.
#
#   B. VERSION must equal the CHANGELOG's top `## [X.Y.Z]` heading. Unconditional,
#      not just at bumps: measured across the last 40 non-merge commits, 40 agree.
#      A commit that adds a heading without bumping, or bumps without adding one,
#      breaks a join that has never been broken.
#
#   Together, A and B pass 62 of 62 non-merge commits in the measured range. The
#   check is silent on every correct commit this repo has ever made and loud on the
#   one that was wrong.
#
# A THIRD PREDICATE WAS BUILT, MEASURED AND REJECTED: "a commit that CHANGES VERSION
# must name it in its subject", which would catch a silent bump. It fired on 21 of
# those 62 commits -- every release at or below v0.114.0, all of them correct under
# the naming convention of their time. Scoping it to "after v0.115.0" would be a
# fitted constant with no derivation, and no observed defect motivated it: predicate
# A caught the only failure that has actually happened. A check that is wrong about a
# third of the history it is pointed at gets turned off, and takes A and B with it.
#
# MERGES ARE SKIPPED, AND THAT IS NOT A LOOPHOLE. A merge commit's VERSION differs
# from its first parent by construction (it is bringing the bump in), and its
# subject is "Merge pull request #N from ..." with no version token. Measured on
# the last 3 merges to main: all 3 differ from parent 1, none carry a token. Without
# this skip the check would fire on every merge, and a gate that fires on every
# correct action is a gate that gets turned off. The commits the merge brings in are
# each checked on their own, which is where the claim is actually authored.
#
# TWO FURTHER JOINS, ADDED AFTER THE TRIPLE WAS DEFEATED BY A SQUASH.
#
# The triple is per-commit, and a squash-merge deletes the commits that could
# disagree. A release branch cut from a local `main` that was fourteen commits
# ahead of `origin/main` took `origin/main` as its PR merge-base, and the squash
# of that PR carried three releases under one `feat(v0.217.0):` subject. The
# surviving commit's subject, VERSION and CHANGELOG heading all agreed, because
# the fourteen commits that could have disagreed were no longer there to. This
# script reported `PASS 15 commit(s)` on the branch and `PASS 1 commit(s)` on the
# squashed main. BOTH ARE PASS.
#
# So the arms below must not key on any agreement between the triple's three
# members: an arm keyed on agreement is satisfied by the collapse it exists to
# catch. They key on the RANGE instead.
#
#   C. A range adds at most one `## [X.Y.Z]` CHANGELOG heading. CLAUDE.md already
#      states the prohibition -- "Squash-merge only single-version branches: a
#      squash of several takes the first version in the subject and breaks the
#      triple" -- and nothing enforced it. A range adding two headings is a
#      multi-version branch by construction, whether or not it has been squashed
#      yet, so this fires at push, BEFORE the squash, which is the earlier seam.
#
#      MEASURED FALSE-POSITIVE SET: all 443 non-merge commits on main, which is
#      one commit per squashed PR. Two add more than one heading, and both are
#      real instances of the prohibition rather than false positives:
#        3288915  v0.95.0, adds 2 -- swallowed v0.94.0, and PASSES the triple.
#        5b5b95c  v0.172.0, adds 8 -- its subject says v0.169.6, so predicate A
#                 already catches that one.
#      One of the two is invisible to every existing predicate, which is why this
#      arm is not redundant with A and B. The retained squash `de1cc21` adds three
#      and likewise passes the triple.
#
#      A RANGE ALSO REMOVES NO HEADING PRESENT AT ITS BASE. A count of ADDED
#      headings is blind to a release that REPLACES the previous release's heading
#      in place: 0.806.0 (581ca289, parent c07dc9d1) turned `## [0.805.0]` into
#      `## [0.806.0]`, the set difference netted to one added, and it passed. The
#      old release's body survived under the new heading with nothing naming it.
#      MEASURED FALSE-POSITIVE SET: a census over 917 first-parent commits that
#      touched CHANGELOG.md found 5 that removed a heading, all true positives.
#      4 were never restored -- 60f776c2, fc957e40 and f2e0403f removed 0.768.0,
#      0.769.0 and 0.770.0; 0cc40283 removed 0.200.0. The fifth, 581ca289, removed
#      0.805.0, which ed0fa33d later restored.
#
#      A RESTORED HISTORICAL HEADING IS NOT A NEW RELEASE. The repair of the shape
#      above re-adds a heading, and a range carrying that repair plus its own
#      release counted two and failed (ed0fa33d restored 0.805.0). So when two or
#      more are added, a heading at or BELOW the base's top heading (numeric per
#      field, in awk -- `sort -V` is not on this box) is exempt iff
#      `git log -1 -S "## [x.y.z]" <range_base> -- CHANGELOG.md` finds it in the
#      base's own history; it is named on a NOTE line, never silently dropped. A
#      heading ABOVE the base top always counts. THE TRAP: the search starts at
#      range_base, NEVER the tip -- from the tip `-S` finds the restoring commit
#      itself and exempts every low-numbered heading anyone writes. The exemption
#      is skipped entirely below two added headings, so a normal one-release push
#      pays no `-S` call; measured cost when it runs, 0.07 s on a recent hit and
#      ~2 s on an old or absent heading.
#
#   D. A branch carries no commit that exists on local `main` but not on
#      `origin/main`. That is the PRECONDITION of the squash above: such commits
#      sit behind the PR's merge-base and ride into it unremarked. Evaluated only
#      in the default range mode, and never when HEAD is `main` itself -- pushing
#      main is how those commits reach origin, and an arm that fires on the remedy
#      is an arm that gets turned off.
#
# A THIRD THING A SQUASH BREAKS, AND IT IS NOT A RANGE PROPERTY AT ALL.
#
#   E. No tracked file at HEAD carries BOTH a `^<<<<<<< ` line and a `^>>>>>>> `
#      line. A conflict resolved by committing the markers is a file that still
#      reads as prose and is wrong in a way no reader notices until they need the
#      section that was cut in half.
#
#      MEASURED, and it is why this arm is here rather than in a lint: the
#      `0.557.0` squash shipped CHANGELOG.md to origin/main carrying `<<<<<<< HEAD`,
#      a `=======` and a `>>>>>>> worktree-agent-...`, with the `## [0.555.0]`
#      heading separated from its own body. Arms A, B and C all read that tree
#      GREEN -- the top heading, VERSION and the subject agreed, and the range
#      added one heading -- because every one of them keys on heading TEXT and a
#      conflict marker is not a heading.
#
#      FALSE-POSITIVE SET, measured over every tracked path at HEAD on the branch
#      that added this arm: ONE file, CHANGELOG.md, and it is the true positive
#      above. The narrowing that got it there:
#
#        - BOTH markers are required, intersected per file. Either alone is a
#          prose shape somebody writes on purpose; the pair is not.
#        - The OPEN marker requires its trailing space, because git always writes
#          a label after it. Without that requirement a bare `<<<<<<<` rule line
#          would join the population.
#        - `^=======$` IS DELIBERATELY NOT IN THE GRAMMAR. It is the setext H1
#          underline, so a markdown file with a title reads as a conflict under a
#          grammar that includes it. The
#          pair above already identifies the file; the middle marker adds nothing
#          to the join and would only widen it.
#
#      TWO THINGS THIS ARM DOES NOT SEE, STATED BECAUSE A BLIND SPOT NOBODY WROTE
#      DOWN IS READ AS COVERAGE.
#
#        - A TRUNCATED conflict, carrying one marker and not the other, is outside
#          the grammar by construction: the intersect requires both.
#        - `core/fixtures/layer-readopt-gate/run.sh:514` writes a whole conflict
#          block -- both markers and the middle one -- as a `printf` argument, and
#          escapes this arm only because none of the three is LINE-LEADING in the
#          file. That exemption rests on position and nothing else, so a fixture
#          that seeds a marker at column 0 of a tracked file becomes a finding
#          here and is expected to move to a heredoc or a built-up string.
#
#      Evaluated in EVERY mode -- an explicit `--range` or `--commit` is a
#      question about those commits, and this arm's subject is the tree that is
#      about to be pushed either way.
#
# A FOURTH JOIN, ON THE MESSAGES THE CONSUMER'S ENGINE READS.
#
#   F. A release that cites a ledger id it did NOT discharge names it on a body
#      line reading exactly `Not-discharged: PC-S<n>` or
#      `Not-discharged: PC-S<n>-<SLUG>` -- the SLUG in the shared id class
#      `[A-Za-z0-9_.-]` of lib.sh `ledger_entry_id()` -- column 0, no backticks, no bullet,
#      never the subject. `ledger-reverify.sh`'s `named_cited_filter` strips that
#      line before asking whether the commit names the id, so the consumer reads
#      the citation as NAMED-UPSTREAM-CITED-ONLY rather than as an absorption.
#      A NEAR-MISS SPELLING IS SILENTLY AN ORDINARY MENTION to that filter, which
#      is the false absorption the form exists to prevent, so this arm refuses any
#      LINE-LEADING `not discharg...` line (case-insensitive, after optional
#      whitespace, `>`, `*`, `-` and one backtick) in a range message that is not
#      exactly canonical, and refuses the form in a SUBJECT outright.
#
#      THE GRAMMAR IS PAIRED, BYTE FOR BYTE, with the canonical regex in
#      `named_cited_filter`. The engine ships to consumers and this validator does
#      not, so they cannot be one file; change both or neither.
#
#      FALSE-POSITIVE SET, measured over all 2001 commit messages on origin/main
#      at the commit that added this arm: ZERO line-leading near-misses, zero
#      canonical lines. Controls in the same run: a synthetic `  - not discharged:`
#      line fires, 1685 `Co-Authored-By:` lines are found, an impossible token
#      returns 0. The narrowing that got it there: the phrase occurs 3 times
#      ANYWHERE in a line, all mid-sentence prose (e.g. 7665d11a, "The candidate
#      is NOT discharged."), so the grammar is LINE-LEADING only -- the engine's own form is
#      column-0, and a mid-line phrase is something neither side treats as a
#      citation.
#
# A FIFTH JOIN, ON WHAT A BUNDLE'S INTEGRATOR REBUILT.
#
#   G. A bundle release (a subject opening `x.y.z ` and carrying `bundle`, or any message
#      with a `Members` paragraph) names each member commit as the first object name on a
#      `- ` line of that paragraph, and its docs/backlog.md, docs/backlog.archive.md and
#      CHANGELOG.md are compared, section by section, against the base (the release's
#      parent) and each member (against its own parent). A section runs from one `## `
#      heading to the next, trailing newlines dropped; a `## BL-<n>` section is keyed by its
#      id across both ledger files, so a rotation that moves it is not a change.
#        - A section no member changed equals the base's. One the release adds and no
#          member carries is a NOTE (an integrator's filing), never silent.
#        - A section one member changed (the top of a stack of members, when a member is
#          another's parent) equals that member's bytes. One substitution is acquitted: a
#          member writes `vVERSION_PLACEHOLDER` on its status line (one opening `**LANDED`
#          or `**PARTIAL`), and the integrator sets it to `v` and the release VERSION.
#          Every other byte compares exactly, that line's included.
#        - A section two members changed, or one member built on a base whose copy
#          differs, carries per line the base's count plus each member's change, blank
#          lines aside. That is where a union drops one of two identical lines.
#        - The release's own CHANGELOG block carries every line its members add to it.
#        - A BL id or release heading twice in the release (and not at the base) fails, as
#          does a bundle subject with no member, or a member that does not resolve.
#
#      MEASURED. The case that motivated it fires: B3 (9cad095fe) and B1 (4c3a82362)
#      rebuilt from their real members by the integrator's `git merge-file --union`, as a
#      commit on the landed tree, read FAIL naming BL-1073's and BL-1058's dropped
#      `verify: manual`. FALSE-POSITIVE SET, over every subject on origin/main at
#      c75a7c323 (2539 commits): 12 bundle subjects and 5 Members paragraphs, none
#      outside a bundle. B2-B5 (0.1125.0-0.1128.0) read 0 FAIL (members 10, 5, 18, 3
#      sections; multi-member 1; one NOTE, B2's BL-1070, filed by its integrator), and so
#      does B6's combine c851405b5 (13 member sections, 1 changed by two members:
#      BL-1056's line merge). ENUMERATED: B1 (4c3a82362) reads 9 FAIL, every one a version
#      its members wrote before the placeholder form: 5 status lines (BL-1052, -1053,
#      -1055, -1056, -1057) whose only difference is the version, and 4 CHANGELOG blocks
#      (0.1116.0, 0.1123.0, 0.1125.0, 0.1126.0) the release folded into its own. The seven
#      earlier bundles (0.1091.0-0.1100.0, 0.1108.0) carry no Members paragraph and read
#      FAIL: a bundle that names no member cannot be compared, which is the refusal the
#      rule intends. Every one of these is history; the arm judges only a pushed range.
#      The narrowing that got it there: a subject merely naming a bundle (3ac0b54d2,
#      `spec the export bundle format`) is out by the leading version.
#
# USAGE
#   scripts/validate-release-version.sh [--range A..B] [--commit SHA]
#                                       [--push-remote NAME --push-refs LINES]
#
#   default range   <base>..HEAD -- the branch's own commits, which is what a push
#                   adds. <base> is origin/main, EXCEPT when a first-parent ancestor
#                   of HEAD^ that origin/main lacks is a release commit (subject opens
#                   `X.Y.Z — `) contained in a remote-tracking ref under
#                   refs/remotes/origin/: then the nearest such commit is <base>, and a
#                   NOTE line names it and the ref. That is a release STACKED on
#                   another release that was pushed for its own gate and has not
#                   landed (`.claude/rules/operator-rulings.md`, "A release never
#                   waits for another release's landing"). Arms A, B and C then judge the
#                   commits above that release only; the pushed release was judged by
#                   its own push. The base cannot be manufactured by committing: a
#                   remote-tracking ref moves only on a fetch or a push, so a LOCAL
#                   branch carrying two unpushed releases still ranges from
#                   origin/main and arm C fails it, and a branch that adds two releases
#                   above a pushed one fails from that base.
#                   THE REFS THIS PUSH NAMES ARE NOT A BASE. One branch collecting two
#                   releases across two pushes leaves origin/<branch> containing the
#                   lower one after its first push, indistinguishable by ancestry from
#                   another branch's release. So the search runs ONLY when the caller
#                   passes the push (--push-remote origin and --push-refs, the stdin
#                   lines git hands a pre-push hook, which .githooks/pre-push forwards
#                   at step 1c), and it skips every refs/remotes/origin/<X> whose
#                   refs/heads/<X> those lines name. With no push refs (a hand run, any
#                   other caller) or another remote it FAILS CLOSED: <base> is
#                   origin/main and a stack fails as before. Arm D keeps
#                   origin/main..HEAD: its question is local main, not the stack.
#                   Falls back to HEAD alone when the range is empty or origin/main is
#                   not present (a fresh clone, a detached head).
#
# EXIT
#   0  every checked commit's three names agree, the range carries one release
#      and removes no heading,
#      the branch inherits nothing unpushed from local main, no tracked file
#      carries conflict markers, and no not-discharged citation is misspelled
#   1  a disagreement, a multi-release range, a removed heading, an unpushed-main inheritance, a
#      committed conflict, a misspelled citation, a bundle whose ledger sections are not its
#      members' and its base's, or a commit that could not be read

set -uo pipefail

# THE REPOSITORY ENVIRONMENT IS SCRUBBED BEFORE ANY GIT CALL. Git exports GIT_DIR
# absolute into a hook run from a linked worktree, and this program is both
# hook-dispatched and run directly. The corpus reads below take the redirection
# silently. NOTHING ABOVE THIS LINE MAY CALL GIT.
rv_init() {
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "FAIL: not inside a git repository" >&2; exit 1; }

RANGE=""
COMMIT=""
SUBJECT_NOTE=""
STACK_BASE=""
PUSH_REMOTE=""
PUSH_REFS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --range)  RANGE="${2:-}"; shift 2 ;;
    --commit) COMMIT="${2:-}"; shift 2 ;;
    --push-remote) PUSH_REMOTE="${2:-}"; shift 2 ;;
    --push-refs)   PUSH_REFS="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Resolve the commit list. --no-merges is load-bearing; see the header.
if [ -n "$COMMIT" ]; then
  COMMITS="$COMMIT"
elif [ -n "$RANGE" ]; then
  COMMITS="$(git rev-list --no-merges "$RANGE" 2>/dev/null)"
else
  # The stacked-release base; the USAGE block says how it is chosen and why a local
  # commit cannot supply one. Empty means origin/main, exactly as before it existed.
  STACK_BASE="$(stacked_base)"
  if [ -n "$STACK_BASE" ]; then
    echo "NOTE  range base is the pushed release ${STACK_BASE%% *} on ${STACK_BASE#* }, not origin/main -- a release stacked on an unlanded one"
    STACK_BASE="${STACK_BASE%% *}"
    COMMITS="$(git rev-list --no-merges "${STACK_BASE}..HEAD" 2>/dev/null || true)"
  else
    COMMITS="$(git rev-list --no-merges origin/main..HEAD 2>/dev/null || true)"
  fi
  # EMPTY RANGE FALLS BACK TO HEAD, AND THE VERDICT MUST SAY SO. With no commits of
  # its own a branch's HEAD is origin/main's tip -- the PREVIOUS release, whose triple
  # agrees by construction because it was validated when it merged. Reporting that as
  # a bare `PASS 1 commit(s)` is a check that cannot fire reading exactly like one that
  # passed, and it reads that way at the one moment a rehearsal is most likely: before
  # the release commit exists. The fallback stays -- on main it is the intended subject
  # -- but it is now named in the verdict.
  if [ -z "$COMMITS" ]; then
    COMMITS="$(git rev-parse HEAD 2>/dev/null)"
    # Scoped to a BRANCH. On main the fallback is the intended subject -- HEAD is the
    # release that just merged, and `branch-base arm n/a on main` already says where
    # the run is. On a branch with no commits of its own it is somebody else's release.
    if [ "$(git symbolic-ref -q --short HEAD 2>/dev/null)" != "main" ]; then
      SUBJECT_NOTE=" [range origin/main..HEAD was EMPTY -- validated HEAD $(git rev-parse --short HEAD 2>/dev/null), the last merged release, NOT any commit on this branch]"
    fi
  fi
fi

fails=0
checked=0
range_fail=0
base_fail=0
conflict_fail=0
arm_c_ran=0
arm_d_ran=0
arm_d_why=""
arm_e_ran=0
# Arm F's flags are declared here as well as in arm_f: a caller that skips arm_f (the fixture's
# sourced drive) still reaches rv_report, which reads both under `set -u`.
form_fail=0
arm_f_ran=0
# Arm G's likewise: the fixture's sourced drive skips arm_g.
ledger_fail=0
arm_g_ran=0
arm_g_why=""
arm_g_stat=""
}

semver_of() { printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }

# push_excluded -> the remote-tracking refs this push names, one per line: refs/remotes/origin/<X>
# for every `<local ref> <local sha> refs/heads/<X> <remote sha>` line of --push-refs, the lines
# git hands a pre-push hook. Nothing when the push remote is not origin or no branch is named.
push_excluded() {
  [ "$PUSH_REMOTE" = origin ] || return 0
  awk '$3 ~ /^refs\/heads\/./ { print "refs/remotes/origin/" substr($3, 12) }' <<<"$PUSH_REFS"
}

# stacked_base -> "<sha> <remote ref>" for the nearest first-parent ancestor of HEAD^, absent
# from origin/main, whose subject opens `X.Y.Z — ` and which some refs/remotes/origin/ ref
# contains OTHER THAN the refs this push names; nothing when there is none. HEAD^, never HEAD:
# a branch's own release commit is not its own base. FAILS CLOSED: with no push refs (a hand
# run, any caller but the distribution pre-push hook) there is no stacked base and the range is
# origin/main's, because without the pushed ref a branch's own earlier push is indistinguishable
# from another branch's release.
stacked_base() {
  local log cands sha ref excl
  excl="$(push_excluded)"
  [ -n "$excl" ] || return 0
  git rev-parse -q --verify origin/main >/dev/null 2>&1 || return 0
  log="$(git log --first-parent --format='%H %s' origin/main..HEAD^ 2>/dev/null)" || return 0
  [ -n "$log" ] || return 0
  cands="$(grep -E '^[0-9a-f]+ [0-9]+\.[0-9]+\.[0-9]+ — ' <<<"$log")" || return 0
  while IFS= read -r sha; do
    sha="${sha%% *}"
    [ -n "$sha" ] || continue
    ref="$(git for-each-ref --format='%(refname)' --contains "$sha" refs/remotes/origin/ 2>/dev/null)"
    [ -n "$ref" ] || continue
    ref="$(grep -vxF -e "$excl" <<<"$ref")" || ref=""
    ref="${ref%%$'\n'*}"
    if [ -n "$ref" ]; then printf '%s %s\n' "$sha" "${ref#refs/remotes/}"; return 0; fi
  done <<<"$cands"
}

# ---------------------------------------------------------------------------
# C. THE RANGE CARRIES AT MOST ONE RELEASE.
#
# Keyed on the CHANGELOG heading set at each end of the range, never on the
# triple's internal agreement -- see the header for why that distinction is the
# whole point of this arm. Two directions: a heading present at the base and gone
# at the tip fails (an in-place replacement), and more than one heading added
# fails once restored historical headings are set aside. The header carries the
# measured false-positive set and the search-from-the-base trap.
#
# THE CONDITIONS ARE SPELLED `[ -n "$removed" ]` AND `-gt 1` ON PURPOSE, for the
# same reason as arm E's below: the fixture neuters this arm's count and arm D's
# by rewriting each one's threshold-and-`then` text, and a new line sharing either
# anchor would move two cells under one mutation.
# ---------------------------------------------------------------------------
headings_at() {
  # No `grep -m1`: the first heading is not the question, the SET is. Sorted
  # because comm requires it.
  git show "$1:CHANGELOG.md" 2>/dev/null \
    | grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | sort -u
}

arm_c_range() {
range_base=""; range_tip=""; range_why=""
if [ -n "$COMMIT" ]; then
  range_tip="$COMMIT"
  range_base="$(git rev-parse -q --verify "${COMMIT}^" 2>/dev/null)" || range_base=""
  [ -n "$range_base" ] || range_why="$COMMIT is a root commit -- there is no base to diff its CHANGELOG against"
elif [ -n "$RANGE" ]; then
  case "$RANGE" in
    *..*)
      range_tip="${RANGE##*..}"
      range_base="$(git merge-base "${RANGE%%..*}" "${RANGE##*..}" 2>/dev/null)" || range_base=""
      [ -n "$range_base" ] || range_why="the two ends of $RANGE have no merge base" ;;
    *)
      range_tip="$RANGE"
      range_base="$(git rev-parse -q --verify "${RANGE}^" 2>/dev/null)" || range_base=""
      [ -n "$range_base" ] || range_why="$RANGE is a root commit" ;;
  esac
elif [ -n "$STACK_BASE" ]; then
  range_tip="HEAD"
  range_base="$STACK_BASE"
elif git rev-parse -q --verify origin/main >/dev/null 2>&1; then
  range_tip="HEAD"
  range_base="$(git merge-base origin/main HEAD 2>/dev/null)" || range_base=""
  [ -n "$range_base" ] || range_why="HEAD and origin/main have no merge base"
else
  range_tip="HEAD"
  range_base="$(git rev-parse -q --verify HEAD^ 2>/dev/null)" || range_base=""
  [ -n "$range_base" ] || range_why="origin/main is absent and HEAD is a root commit"
fi
}

semver_le() { # <a> <b> -> 0 when a <= b, compared NUMERICALLY per field
  # `sort -V` is not on this box's BSD userland, and a lexical compare puts
  # 0.10.0 below 0.9.0. awk coerces each field to a number.
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      if (x[i] + 0 < y[i] + 0) exit 0
      if (x[i] + 0 > y[i] + 0) exit 1
    }
    exit 0 }'
}

restored_in_history() { # <"## [x.y.z]"> -> a sha when the heading text ever changed at or before the BASE
  # SEARCHED FROM range_base, NEVER the tip. From the tip, `-S` finds the very
  # commit that restores (or invents) the heading and exempts everything -- the
  # exemption would then acquit every multi-release range carrying a low number.
  git log -1 --format=%H -S "$1" "$range_base" -- CHANGELOG.md 2>/dev/null
}

# The exemption below turns on one numeric comparison (semver_le); a lexical one would read
# 0.10.0 as below 0.9.0 and exempt a release ABOVE the base's top.
arm_c() {
range_removed=0
range_multi=0
if [ -n "$range_base" ]; then
  arm_c_ran=1
  # REMOVAL FIRST. A release that REPLACES the previous release's heading in
  # place nets to one added heading and passed the count below; the heading it
  # destroyed is visible only as a member of the base set missing at the tip.
  removed="$(comm -23 <(headings_at "$range_base") <(headings_at "$range_tip"))"
  if [ -n "$removed" ]; then
    echo "FAIL  this range removes release heading(s) present at its base: $(printf '%s\n' "$removed" | tr -d '#[] ' | tr '\n' ' ')" >&2
    range_fail=1
    range_removed=1
  fi
  added="$(comm -13 <(headings_at "$range_base") <(headings_at "$range_tip"))"
  # `grep -c` prints 0 and exits 1 on no match; it answers this unaided and a
  # `|| echo 0` fallback would fire on exactly the case it appears to cover.
  n_added="$(printf '%s\n' "$added" | grep -c .)"
  # THE RESTORED-HEADING EXEMPTION, computed only when the count could fail, so a
  # normal one-release push pays zero `git log -S` calls. The base's top is read
  # in FILE order the way predicate B reads it, never from `headings_at`, whose
  # lexical sort puts 0.10.0 before 0.9.0. An EMPTY base top (a root, or a
  # headingless parent) exempts nothing: every added heading counts as new.
  if [ "${n_added:-0}" -gt 1 ]; then
    base_top="$(semver_of "$(git show "$range_base:CHANGELOG.md" 2>/dev/null \
                  | grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]')")"
    new_list=""; exempt_list=""
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      hv="$(semver_of "$h")"
      if [ -n "$base_top" ] && semver_le "$hv" "$base_top" && [ -n "$(restored_in_history "$h")" ]; then
        exempt_list="${exempt_list:+$exempt_list }$hv"
      else
        new_list="${new_list}${h}
"
      fi
    done <<<"$added"
    if [ -n "$exempt_list" ]; then
      echo "NOTE  restored historical heading(s), not counted: $exempt_list"
    fi
    added="$new_list"
    n_added="$(printf '%s' "$added" | grep -c .)"
  fi
  if [ "${n_added:-0}" -ge 2 ]; then
    echo "FAIL  this range adds ${n_added} release headings to CHANGELOG.md: $(printf '%s\n' "$added" | tr -d '#[] ' | tr '\n' ' ')" >&2
    range_fail=1
    range_multi=1
  fi
else
  # Announced rather than skipped: an arm that goes quiet reads exactly like one
  # that passed, which is the defect this whole script exists downstream of.
  echo "NOTE  multi-release arm not evaluated -- $range_why"
fi
}

# ---------------------------------------------------------------------------
# D. THE BRANCH INHERITS NOTHING UNPUSHED FROM LOCAL main.
#
# Default mode only. An explicit --range or --commit is a question about those
# commits, not about the branch the operator happens to be standing on.
# ---------------------------------------------------------------------------
arm_d() {
if [ -n "$COMMIT" ] || [ -n "$RANGE" ]; then
  arm_d_why="scoped-out"
else
  cur_branch="$(git symbolic-ref -q --short HEAD 2>/dev/null)" || cur_branch=""
  if [ "$cur_branch" = "main" ]; then
    arm_d_why="on-main"  # pushing main is how unpushed main commits reach origin.
  elif ! git rev-parse -q --verify origin/main >/dev/null 2>&1 \
    || ! git rev-parse -q --verify refs/heads/main >/dev/null 2>&1; then
    echo "NOTE  branch-base arm not evaluated -- origin/main or a local main branch is absent"
  else
    arm_d_ran=1
    inherited="$(comm -12 \
      <(git rev-list origin/main..HEAD 2>/dev/null | sort) \
      <(git rev-list origin/main..refs/heads/main 2>/dev/null | sort) | grep -c .)"
    if [ "${inherited:-0}" -gt 0 ]; then
      echo "FAIL  this branch carries ${inherited} commit(s) that are on local main and not on origin/main" >&2
      base_fail=1
    fi
  fi
fi
}

# ---------------------------------------------------------------------------
# E. NO TRACKED FILE CARRIES A COMMITTED MERGE CONFLICT.
#
# Evaluated in every mode -- see the header for the measurement, for the
# false-positive set, and for why `^=======$` is not in the grammar.
#
# THE CONDITION IS SPELLED `[ -n "$conflict_list" ]` ON PURPOSE. The
# release-version-triple fixture neuters arm C by rewriting `-ge 2 ]; then` and
# arm D by rewriting `-gt 0 ]; then`, each on a copy. A count comparison here
# would share one of those anchors, so a mutation aimed at one arm would move two
# cells and score a kill it did not earn.
# ---------------------------------------------------------------------------
conflict_files_in() { # <repo-dir> -> tracked paths at HEAD carrying BOTH markers
  # BOTH markers, intersected per FILE. `git grep -l <pat> HEAD` prefixes each
  # path with `HEAD:`, which is stripped here; `-e` rather than a bare pattern so
  # a leading `^` can never be read as an option.
  local d="$1"
  comm -12 \
    <(git -C "$d" grep -l -e '^<<<<<<< ' HEAD 2>/dev/null | sed 's|^HEAD:||' | sort -u) \
    <(git -C "$d" grep -l -e '^>>>>>>> ' HEAD 2>/dev/null | sed 's|^HEAD:||' | sort -u)
}

arm_e() {
arm_e_ran=1
conflict_list="$(conflict_files_in .)"
if [ -n "$conflict_list" ]; then
  echo "FAIL  tracked file(s) carry committed merge-conflict markers: $(printf '%s\n' "$conflict_list" | tr '\n' ' ')" >&2
  conflict_fail=1
fi
}

# ---------------------------------------------------------------------------
# F. A NOT-DISCHARGED CITATION IS SPELLED EXACTLY, OR NOT AT ALL.
#
# See the header for the grammar, its pairing with `named_cited_filter`, and the
# measured false-positive set. Evaluated over the same commit list as A and B.
# ---------------------------------------------------------------------------
form_scan() { # <short sha>, one message on stdin -> "<short> <line>" per finding
    C="$1" LC_ALL=C awk '
      # A \001 byte opens a record in the engine`s message stream, so a message carrying one
      # can forge a commit boundary. Refused wherever it appears.
      index($0, "\001") { print ENVIRON["C"] " carries a \\001 byte (the engine record separator) on line " NR; next }
      { l = tolower($0) }
      l ~ /^[[:space:]>*-]*`?not[[:space:]_-]*discharg/ {
        if (NR == 1) { print ENVIRON["C"] " subject: " $0; next }
        if ($0 !~ /^Not-discharged: PC-S[0-9]+(-[A-Za-z0-9_.-]+)*$/) print ENVIRON["C"] " body: " $0
      }'
}

# ONE `git log -z` READS EVERY MESSAGE, never a `log -1` and a `rev-parse --short` per commit.
# Records are NUL-terminated, so a \001 in a message is ordinary data to this read. Whatever the
# stream holds, a record that does not name its own argument as its %H discards the whole pass,
# so a misaligned read can never be scored. The pass is taken only when every
# argument is a full object name, and its answer only when it returned exactly one record per
# argument, in order, each naming that argument as its %H; anything else (`HEAD`, a tag, an
# unreadable sha, a short sha) goes through the per-commit reads below, whose output is the
# reference this pass reproduces -- `%h` is the abbreviation `rev-parse --short` prints.
form_findings_in() { # <repo-dir> <newline-separated shas> -> "<short> <line>" per finding
  local d="$1" c msg rec n=0 got=0 fast=1 found="" hit
  local -a want=()
  for c in $2; do
    want[n]="$c"; n=$((n+1))
    case "${#c}" in 40|64) ;; *) fast=0 ;; esac
    case "$c" in *[!0-9a-f]*) fast=0 ;; esac
  done
  [ "$n" -gt 0 ] || return 0
  if [ "$fast" = 1 ]; then
    while IFS= read -r -d '' rec || [ -n "$rec" ]; do
      c="${rec%%$'\n'*}"
      [ "$got" -lt "$n" ] && [ "${c%% *}" = "${want[got]}" ] || { fast=0; break; }
      msg="${rec#*$'\n'}"
      while [ "${msg%$'\n'}" != "$msg" ]; do msg="${msg%$'\n'}"; done
      hit="$(printf '%s\n' "$msg" | form_scan "${c#* }")"
      [ -z "$hit" ] || found="${found}${hit}
"
      got=$((got+1))
    done < <(git -C "$d" log -z --no-walk=unsorted --format='%H %h%n%B' "${want[@]}" 2>/dev/null)
    if [ "$fast" = 1 ] && [ "$got" = "$n" ]; then
      printf '%s' "$found"
      return 0
    fi
  fi
  for c in $2; do
    msg="$(git -C "$d" log -1 --format=%B "$c" 2>/dev/null)" || { printf '%s <message could not be read>\n' "$c"; continue; }
    printf '%s\n' "$msg" | form_scan "$(git -C "$d" rev-parse --short "$c" 2>/dev/null)"
  done
}

arm_f() {
form_fail=0
arm_f_ran=1
form_list="$(form_findings_in . "$COMMITS")"
if [ -n "$form_list" ]; then
  echo "FAIL  a not-discharged citation is misspelled or misplaced:" >&2
  printf '%s\n' "$form_list" | sed 's/^/        /' >&2
  form_fail=1
fi
}

# ---------------------------------------------------------------------------
# G. A BUNDLE'S LEDGER SECTIONS ARE ITS MEMBERS' BYTES.
#
# See the header for the rule set and the measured false-positive set. Evaluated over the same
# commit list as A and B, and only on a commit whose subject names a bundle or whose message
# carries a `Members` paragraph: a push carrying neither pays one `git log`.
# ---------------------------------------------------------------------------
ledger_members_of() { # one message on stdin -> the first object name on each `- ` line of its Members paragraph
  LC_ALL=C awk '
    /^Members([ ,:]|$)/ { m = 1; next }
    m && /^[[:space:]]*$/ { m = 0; next }
    m && /^- / {
      s = $0
      while (match(s, /[0-9a-f]+/)) {
        pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
        post = substr(s, RSTART + RLENGTH, 1)
        if (RLENGTH >= 7 && RLENGTH <= 64 && pre !~ /[0-9A-Za-z]/ && post !~ /[0-9A-Za-z]/) { print substr(s, RSTART, RLENGTH); break }
        s = substr(s, RSTART + RLENGTH)
      }
    }'
}

# The comparison, one awk over one `git cat-file --batch` stream. ENVIRON: G_ROLES ("<rev> <kind> <blob|->"
# per line; rev R, P, m<i>, b<i>; kind V VERSION, B docs/backlog.md, A docs/backlog.archive.md, C
# CHANGELOG.md), G_NM (member count), G_PAR (per member, the index of the member that is its parent, else
# 0), G_SHORT (per member, its short name). A section is the text from one `## ` heading to the next, its
# trailing newlines dropped; a `## BL-<n>` section is keyed by its id across both ledger files, so a
# rotation that moves it is not a change; a CHANGELOG section is keyed by its `## [x.y.z]` version.
LEDGER_AWK='
function strip(t) { while (substr(t, length(t), 1) == "\n") t = substr(t, 1, length(t) - 1); return t }
function put(b, k, t) {
  t = strip(t)
  if ((b, k) in SEC) { SEC[b, k] = SEC[b, k] "\n\001DUP\001\n" t; DUPN[b, k]++ }
  else { SEC[b, k] = t; NK[b]++; KEYS[b, NK[b]] = k }
}
function line_in(t,   nk) {
  nk = ""
  if (KIND == "B" || KIND == "A") {
    if (match(t, /^## BL-[0-9]+/)) nk = substr(t, 4, RLENGTH - 3)
    else if (t ~ /^## /) { OCC[CUR, t]++; nk = "@" KIND "@" t "@" OCC[CUR, t] }
  } else if (KIND == "C") {
    if (match(t, /^## \[[0-9]+\.[0-9]+\.[0-9]+\]/)) nk = "CL " substr(t, 5, RLENGTH - 5)
  } else if (KIND == "V") { if (!((CUR) in VER)) { VER[CUR] = t; gsub(/[[:space:]]/, "", VER[CUR]) } return }
  if (nk != "") { put(CUR, KEY, BUF); KEY = nk; BUF = "" }
  BUF = BUF t "\n"
}
function look(rev, k,   kinds, x, b) {
  LHAS = 0
  if (k ~ /^CL / || k ~ /^@C@/) kinds = "C"; else if (k ~ /^@B@/) kinds = "B"; else if (k ~ /^@A@/) kinds = "A"; else kinds = "BA"
  for (x = 1; x <= length(kinds); x++) {
    b = BLOB[rev, substr(kinds, x, 1)]
    if (b != "" && b != "-" && ((b, k) in SEC)) { LHAS = 1; return SEC[b, k] }
  }
  return ""
}
# The one substitution the arm acquits: a member writes `vVERSION_PLACEHOLDER` in its status line (a line
# opening `**LANDED` or `**PARTIAL`), and the integrator replaces it with `v` and the release VERSION. Every
# other byte of every member line is compared as written.
function ren(t,   n, x, ln, out, s) {
  if (index(t, "vVERSION_PLACEHOLDER") == 0) return t
  n = split(t, ln, "\n"); out = ""
  for (x = 1; x <= n; x++) {
    s = ln[x]
    if (s ~ /^\*\*(LANDED|PARTIAL)/) gsub(/vVERSION_PLACEHOLDER/, "v" V, s)
    out = out (x > 1 ? "\n" : "") s
  }
  return out
}
function count_lines(t, arr, sign,   n, x, ln) {
  n = split(t, ln, "\n")
  for (x = 1; x <= n; x++) if (ln[x] != "") arr[ln[x]] += sign
}
function cut(t) { gsub(/\001/, "^A", t); return (length(t) > 110) ? substr(t, 1, 110) "..." : t }
function firstdiff(w, g,   a, b, na, nb, x) {
  na = split(w, a, "\n"); nb = split(g, b, "\n")
  for (x = 1; x <= na || x <= nb; x++) if (a[x] != b[x]) return "line " x ": member [" cut(a[x]) "] release [" cut(b[x]) "]"
  return "the same lines, in a different order"
}
function isanc(i, j) { j = PAR[j]; while (j > 0) { if (j == i) return 1; j = PAR[j] } return 0 }
function root(i) { while (PAR[i] > 0) i = PAR[i]; return i }
function lab(k) { return (k ~ /^@/) ? "section [" substr(k, 4) "]" : k }
BEGIN {
  nr = split(ENVIRON["G_ROLES"], RL, "\n")
  for (x = 1; x <= nr; x++) { if (split(RL[x], f, " ") == 3) { BLOB[f[1], f[2]] = f[3]; if (f[3] != "-") BKIND[f[3]] = f[2] } }
  NM = ENVIRON["G_NM"] + 0
  split(ENVIRON["G_PAR"], pp, " "); split(ENVIRON["G_SHORT"], ss, " ")
  for (i = 1; i <= NM; i++) { PAR[i] = pp[i] + 0; SHORT[i] = ss[i] }
  INOBJ = 0
}
INOBJ == 0 {
  if ($0 ~ / missing$/ || split($0, h, " ") != 3) { BROKEN = BROKEN " [" $0 "]"; next }
  CUR = h[1]; SIZE = h[3] + 0; GOT = 0; KIND = BKIND[CUR]; KEY = "@" KIND "@prelude"; BUF = ""; INOBJ = 1
  next
}
{
  GOT += length($0) + 1
  line_in($0)
  if (GOT >= SIZE + 1) { if (KIND != "V") put(CUR, KEY, BUF); INOBJ = 0; LOADED++ }
}
END {
  if (INOBJ) { print "G FAIL - the object stream ended inside an object"; exit }
  if (BROKEN != "") { print "G FAIL - objects the comparison asked for could not be read:" BROKEN; exit }
  V = VER[BLOB["R", "V"]]
  # Each member: the sections it changed, and its text with the status-line placeholder set to the release.
  for (i = 1; i <= NM; i++) {
    m = "m" i; b = "b" i; nch = 0
    for (fk = 1; fk <= 3; fk++) {
      fc = substr("BAC", fk, 1)
      if (BLOB[m, fc] == BLOB[b, fc]) continue
      for (side = 1; side <= 2; side++) {
        bb = BLOB[(side == 1) ? m : b, fc]
        if (bb == "-") continue
        for (x = 1; x <= NK[bb]; x++) {
          k = KEYS[bb, x]
          if ((i, k) in SEEN) continue
          SEEN[i, k] = 1
          tm = look(m, k); hm = LHAS; tb = look(b, k); hb = LHAS
          if (hm == hb && tm == tb) continue
          nch++; CH[i, nch] = k; CHT[i, nch] = tm; CHH[i, nch] = hm; CHB[i, nch] = tb
        }
      }
    }
    NCH[i] = nch
    for (x = 1; x <= nch; x++) {
      k = CH[i, x]
      MT[i, k] = ren(CHT[i, x]); MH[i, k] = CHH[i, x]; RK[i, k] = k
      TL[k] = TL[k] " " i; ALLK[k] = 1
    }
  }
  for (rv = 1; rv <= 2; rv++) for (fk = 1; fk <= 3; fk++) {
    bb = BLOB[(rv == 1) ? "R" : "P", substr("BAC", fk, 1)]
    if (bb == "-") continue
    for (x = 1; x <= NK[bb]; x++) ALLK[KEYS[bb, x]] = 1
  }
  # A BL id twice in the release: within one file, or once in each.
  for (k in ALLK) {
    if (k ~ /^@/) continue
    rb = BLOB["R", "B"]; ra = BLOB["R", "A"]; pb = BLOB["P", "B"]; pa = BLOB["P", "A"]
    if (k ~ /^CL /) { rb = BLOB["R", "C"]; ra = "-"; pb = BLOB["P", "C"]; pa = "-" }
    rd = ((rb, k) in DUPN) + ((ra, k) in DUPN) + (((rb, k) in SEC) && ((ra, k) in SEC))
    pd = ((pb, k) in DUPN) + ((pa, k) in DUPN) + (((pb, k) in SEC) && ((pa, k) in SEC))
    if (rd > 0 && pd == 0) { print "G FAIL " lab(k) ": its heading appears more than once in the release"; FAILS++ }
  }
  for (k in ALLK) {
    pT = look("P", k); pH = LHAS; rT = look("R", k); rH = LHAS
    ne = 0; split("", E); n = split(TL[k], tl, " ")
    for (x = 1; x <= n; x++) {
      sup = 0
      for (y = 1; y <= n; y++) if (y != x && isanc(tl[x] + 0, tl[y] + 0)) sup = 1
      if (!sup) { ne++; E[ne] = tl[x] + 0 }
    }
    if (k == "CL " V && !pH) {
      split("", W); split("", G)
      for (x = 1; x <= ne; x++) {
        j = E[x]; rb = root(j)
        count_lines(MT[j, k], W, 1); count_lines(ren(look("b" rb, RK[j, k])), W, -1)
      }
      count_lines(rT, G, 1)
      for (ln in W) if (W[ln] > 0 && G[ln] < W[ln] && ln !~ /^## \[/) { print "G FAIL " lab(k) ": the release block carries [" cut(ln) "] " (G[ln] + 0) " time(s), its members add it " W[ln]; FAILS++ }
      NTOP++
      continue
    }
    if (ne == 0) {
      if (pH == rH && pT == rT) { NBASE++; continue }
      if (!pH && rH) { print "G NOTE " lab(k) ": added by the release, and no member carries it"; NNOTE++; continue }
      if (pH && !rH) { print "G FAIL " lab(k) ": present at the base, absent from the release, and no member removed it"; FAILS++; continue }
      print "G FAIL " lab(k) ": no member changed it, and the release differs from the base at " firstdiff(pT, rT); FAILS++
      continue
    }
    j = E[1]; rb = root(j)
    bT = ren(look("b" rb, RK[j, k])); bH = LHAS
    if (ne == 1 && bH == pH && bT == ren(pT)) {
      NMEM++
      if (MH[j, k] != rH) { print "G FAIL " lab(k) ": member " SHORT[j] (MH[j, k] ? " carries it and the release does not" : " removed it and the release still carries it"); FAILS++ }
      else if (MT[j, k] != rT) { print "G FAIL " lab(k) ": differs from member " SHORT[j] " at " firstdiff(MT[j, k], rT); FAILS++ }
      continue
    }
    NMULTI++
    split("", W); split("", G)
    count_lines(pT, W, 1)
    who = ""
    for (x = 1; x <= ne; x++) {
      j = E[x]; rb = root(j); who = who " " SHORT[j]
      count_lines(MT[j, k], W, 1); count_lines(ren(look("b" rb, RK[j, k])), W, -1)
    }
    count_lines(rT, G, 1)
    for (ln in W) if (W[ln] != G[ln] + 0) { print "G FAIL " lab(k) ": changed by" who ", and the release carries [" cut(ln) "] " (G[ln] + 0) " time(s) where the base plus each member change gives " W[ln]; FAILS++ }
    for (ln in G) if (!(ln in W)) { print "G FAIL " lab(k) ": changed by" who ", and the release carries [" cut(ln) "], which neither the base nor any member change does"; FAILS++ }
  }
  print "G STAT " (NMEM + 0) " " (NMULTI + 0) " " (NBASE + 0) " " (NNOTE + 0) " " (NTOP + 0) " " (FAILS + 0) " " (LOADED + 0)
}'

# A BUNDLE SUBJECT is a release subject (a leading x.y.z) carrying the word `bundle` in any case. The
# leading version keeps a commit that only mentions a bundle (`spec the export bundle format`) out.
ledger_is_bundle() { # <subject> -> 0 when it names a bundle release
  local re='^[0-9]+\.[0-9]+\.[0-9]+ .*[Bb][Uu][Nn][Dd][Ll][Ee]'
  [[ $1 =~ $re ]]
}

ledger_check() { # <repo-dir> <release sha> <message> -> `G FAIL|G NOTE|G STAT ...` lines on stdout
  local d="$1" r="$2" msg="$3" subj ms info cnt got=0 h p1 rest rsha="" psha="" i j k path rev req="" roles="" loads="" par="" short="" bl
  local -a M=() MP=() REVS=()
  subj="${msg%%$'\n'*}"
  ms="$(printf '%s\n' "$msg" | ledger_members_of)"
  if [ -z "$ms" ]; then
    ledger_is_bundle "$subj" && echo "G FAIL - the subject names a bundle and no Members paragraph names a member commit"
    return 0
  fi
  cnt="$(printf '%s\n' "$ms" | grep -c .)"
  # shellcheck disable=SC2086
  info="$(git -C "$d" log --no-walk=unsorted --format='%H %P' "$r" $ms 2>/dev/null)"
  while IFS=' ' read -r h p1 rest; do
    [ -n "$h" ] || continue
    if [ "$got" = 0 ]; then rsha="$h"; psha="$p1"; else M[got]="$h"; MP[got]="$p1"; fi
    got=$((got+1))
  done <<<"$info"
  if [ "$got" != $((cnt+1)) ]; then
    for k in $ms; do
      git -C "$d" rev-parse -q --verify "${k}^{commit}" >/dev/null 2>&1 \
        || echo "G FAIL - member $k, named in the Members paragraph, does not resolve to a commit here"
    done
    echo "G FAIL - the Members paragraph names $cnt member(s), and $((got > 0 ? got-1 : 0)) resolved to distinct commits"
    return 0
  fi
  i=1
  for k in $ms; do
    case "${M[i]}" in "$k"*) ;; *) echo "G FAIL - member $k resolved out of order, to ${M[i]}"; return 0 ;; esac
    i=$((i+1))
  done
  [ -n "$psha" ] || { echo "G FAIL - the release commit has no parent to compare against"; return 0; }
  REVS=(R P)
  i=1
  while [ "$i" -le "$cnt" ]; do
    REVS[${#REVS[@]}]="m$i"; REVS[${#REVS[@]}]="b$i"
    j=0; k=1
    while [ "$k" -le "$cnt" ]; do [ "${M[k]}" = "${MP[i]}" ] && j="$k"; k=$((k+1)); done
    par="$par $j"; short="$short ${M[i]:0:9}"
    i=$((i+1))
  done
  for rev in "${REVS[@]}"; do
    case "$rev" in R) h="$rsha" ;; P) h="$psha" ;; m*) h="${M[${rev#m}]}" ;; b*) h="${MP[${rev#b}]}" ;; esac
    for k in V B A C; do
      case "$k" in V) path=VERSION ;; B) path=docs/backlog.md ;; A) path=docs/backlog.archive.md ;; C) path=CHANGELOG.md ;; esac
      req="$req$h:$path
"
    done
  done
  i=0
  while IFS= read -r bl; do
    rev="${REVS[$((i / 4))]}"
    case "$((i % 4))" in 0) k=V ;; 1) k=B ;; 2) k=A ;; 3) k=C ;; esac
    case "$bl" in *' missing'|'') bl=- ;; esac
    roles="$roles$rev $k $bl
"
    i=$((i+1))
  done < <(printf '%s' "$req" | git -C "$d" cat-file --batch-check='%(objectname)' 2>/dev/null)
  [ "$i" = $(( ${#REVS[@]} * 4 )) ] || { echo "G FAIL - the object lookup answered $i of $(( ${#REVS[@]} * 4 )) requests"; return 0; }
  # Loaded: every file of R and P, each VERSION, each member base's CHANGELOG (its released set), and both
  # sides of each file a member changed. sort -u loads a blob shared by several revisions once.
  loads="$(printf '%s' "$roles" | LC_ALL=C awk '
    { B[$1, $2] = $3; R[NR] = $0 }
    END {
      for (x = 1; x <= NR; x++) {
        split(R[x], f, " "); rev = f[1]; k = f[2]; b = f[3]
        if (b == "-") continue
        if (rev == "R" || rev == "P" || k == "V" || (k == "C" && rev ~ /^b/)) { print b; continue }
        o = (substr(rev, 1, 1) == "m") ? "b" substr(rev, 2) : "m" substr(rev, 2)
        if (B[o, k] != b) print b
      }
    }' | sort -u)"
  # shellcheck disable=SC2086
  printf '%s\n' $loads | git -C "$d" cat-file --batch 2>/dev/null \
    | G_ROLES="$roles" G_NM="$cnt" G_PAR="${par# }" G_SHORT="${short# }" LC_ALL=C awk "$LEDGER_AWK"
}

arm_g() {
ledger_fail=0
arm_g_ran=0
arm_g_why=""
local rec sha msg cands="" out all="" nl=$'\n'
while IFS= read -r -d '' rec || [ -n "$rec" ]; do
  sha="${rec%%$'\n'*}"; msg="${rec#*$'\n'}"
  ledger_is_bundle "${msg%%$'\n'*}" && { cands="$cands $sha"; continue; }
  case "$nl$msg" in *"${nl}Members"*) cands="$cands $sha" ;; esac
done < <(git log -z --no-walk=unsorted --format='%H%n%B' $COMMITS 2>/dev/null)
if [ -z "$cands" ]; then
  arm_g_why="none"
  return 0
fi
arm_g_ran=1
for sha in $cands; do
  msg="$(git log -1 --format=%B "$sha" 2>/dev/null)" || { echo "FAIL  ${sha:0:9}  arm G could not read the message" >&2; ledger_fail=1; continue; }
  out="$(ledger_check . "$sha" "$msg")"
  grep '^G NOTE' <<<"$out" | sed "s/^G NOTE /NOTE  ${sha:0:9}  arm G: /"
  if grep -q '^G FAIL' <<<"$out"; then
    grep '^G FAIL' <<<"$out" | sed "s/^G FAIL /FAIL  ${sha:0:9}  arm G: /" >&2
    ledger_fail=1
  elif ! grep -q '^G STAT ' <<<"$out"; then
    echo "FAIL  ${sha:0:9}  arm G's comparison produced no verdict" >&2
    ledger_fail=1
  else
    all="$all $(grep -m1 '^G STAT ' <<<"$out" | cut -d' ' -f3-6)"
  fi
done
arm_g_stat="$all"
}

# ONE `git log -z` READS EVERY SHORT NAME AND SUBJECT, as `form_findings_in` reads its messages:
# taken only when every member is a full object name, and its answer kept only when it returned
# exactly one record per member, in order, each naming that member as its %H. Anything else
# (`HEAD`, a tag, a short or unreadable sha) runs the two per-commit reads below for the WHOLE
# list, which are the reference this pass reproduces, stderr included. The lookup per commit is
# an array index, never a fork. An empty list makes no git call here at all.
arm_ab() {
local ab_n=0 ab_got=0 ab_i=0 ab_fast=1 ab_rec ab_rest
local -a ab_want=() ab_short=() ab_subj=()
for c in $COMMITS; do
  ab_want[ab_n]="$c"; ab_n=$((ab_n+1))
  case "${#c}" in 40|64) ;; *) ab_fast=0 ;; esac
  case "$c" in *[!0-9a-f]*) ab_fast=0 ;; esac
done
if [ "$ab_n" = 0 ]; then
  ab_fast=0
elif [ "$ab_fast" = 1 ]; then
  while IFS= read -r -d '' ab_rec || [ -n "$ab_rec" ]; do
    [ "$ab_got" -lt "$ab_n" ] && [ "${ab_rec%% *}" = "${ab_want[ab_got]}" ] || { ab_fast=0; break; }
    ab_rest="${ab_rec#* }"
    case "$ab_rest" in
      *' '*) ab_short[ab_got]="${ab_rest%% *}"; ab_rest="${ab_rest#* }" ;;
      *) ab_short[ab_got]="$ab_rest"; ab_rest="" ;;
    esac
    while [ "${ab_rest%$'\n'}" != "$ab_rest" ]; do ab_rest="${ab_rest%$'\n'}"; done
    ab_subj[ab_got]="$ab_rest"
    ab_got=$((ab_got+1))
  # ITS STDERR IS CAPTURED, NEVER DISCARDED: any byte there (git's `refname is ambiguous` warning
  # for a branch named after a full sha is one) is a warning the per-commit reads would print, so
  # it appends a NUL and a stray record, the count check above rejects the pass, and the per-commit
  # reads run and print it. Records still reach this loop on the pipe; only stderr is captured.
  done < <({ ab_err="$(git log -z --no-walk=unsorted --format='%H %h %s' "${ab_want[@]}" 2>&1 >&3)"
             [ -z "$ab_err" ] || printf '\0stderr'; } 3>&1)
  [ "$ab_fast" = 1 ] && [ "$ab_got" = "$ab_n" ] || ab_fast=0
fi
for c in $COMMITS; do
  if [ "$ab_fast" = 1 ]; then
    short="${ab_short[ab_i]}"
    subject="${ab_subj[ab_i]}"
    ab_i=$((ab_i+1))
  else
  short="$(git rev-parse --short "$c")"
  subject="$(git log -1 --format=%s "$c" 2>/dev/null)"
  fi

  version="$(git show "$c:VERSION" 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$version" ]; then
    echo "FAIL  $short  VERSION is missing or empty at this commit" >&2
    fails=$((fails+1)); continue
  fi

  changelog="$(semver_of "$(git show "$c:CHANGELOG.md" 2>/dev/null \
                | grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]')")"
  subj_ver="$(printf '%s' "$subject" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  subj_ver="${subj_ver#v}"
  # THE BARE LEADING FORM IS A CLAIM TOO. Release subjects since the GitHub-squash
  # era read `0.754.0 — ...` with no `v`, so the v-grammar above bound none of them
  # and predicate A could not fire on a single current release. Measured over all
  # 1865 non-merge commits on origin/main: the v-grammar alone binds 657, with this
  # fallback 898, and the mismatch set is the SAME 7 commits under both -- zero new
  # false positives. Anchored at the subject START: a bare version mid-subject
  # (`docs: plan for 0.755.0`) is a mention, not the commit's claim about itself.
  [ -n "$subj_ver" ] || subj_ver="$(printf '%s' "$subject" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)"

  checked=$((checked+1))
  bad=0

  # A. A stated version must be the real one.
  if [ -n "$subj_ver" ] && [ "$subj_ver" != "$version" ]; then
    echo "FAIL  $short  subject says v$subj_ver, VERSION says $version" >&2
    bad=1
  fi

  # B. VERSION and the changelog's top heading name the same release.
  if [ -z "$changelog" ]; then
    echo "FAIL  $short  CHANGELOG.md has no '## [X.Y.Z]' heading" >&2
    bad=1
  elif [ "$changelog" != "$version" ]; then
    echo "FAIL  $short  VERSION says $version, CHANGELOG's top heading says $changelog" >&2
    bad=1
  fi

  [ "$bad" -eq 0 ] || fails=$((fails+1))
done
}

rv_report() {
if [ "$fails" -ne 0 ]; then
  cat >&2 <<'EOF'

      The three names of a release must agree: the commit subject, VERSION, and the
      CHANGELOG's top heading. When they do not, the release cannot be identified
      afterwards -- the tag, the installed stamp and the changelog each say something
      different, and there is no way to tell which one is the release.

      Remedy: bump VERSION and add the matching '## [X.Y.Z]' CHANGELOG heading in the
      SAME commit that names the version in its subject. If the commit is already
      made, `git commit --amend` it; the three are one claim, not three.
EOF
  echo "FAIL: ${fails} of ${checked} commit(s) disagree." >&2
fi

if [ "$range_removed" -ne 0 ]; then
  cat >&2 <<'EOF'

      A release heading that existed at the range's base is gone at its tip. The
      usual shape is a release that edited the previous heading's version in place
      instead of inserting its own above it: the old release's body survives, now
      filed under the new release's heading, and nothing names it any more. A
      count of added headings cannot see this, because the replacement nets to one.

      Remedy: put the removed heading line back above its own body and insert this
      release's heading above it. `git show <base>:CHANGELOG.md` has the original.
EOF
fi

if [ "$range_multi" -ne 0 ]; then
  cat >&2 <<'EOF'

      A range that adds more than one release heading is a multi-version branch,
      and CLAUDE.md permits squash-merging single-version branches only: a squash
      of several takes the first version in its subject and the rest become
      unattributable. The triple cannot see this -- the commits that would have
      disagreed are the ones the squash removes, so it reports PASS on the branch
      and PASS on the squash.

      Remedy: put each release on its own branch off origin/main and merge them in
      order. If a branch has already collected several, cut the later ones onto
      fresh branches rather than squashing them together.
EOF
fi

if [ "$base_fail" -ne 0 ]; then
  cat >&2 <<'EOF'

      Those commits are behind this branch's merge-base with origin/main, so a PR
      from here carries them and a squash folds them into the release commit. This
      is how three releases once shipped under one subject: local main was fourteen
      commits ahead, the branch was cut from it, and nothing compared the two.

      Remedy: push main first, then rebase this branch onto origin/main. Confirm
      with `git rev-list --left-right --count main...origin/main` reading 0 0.
EOF
fi

if [ "$conflict_fail" -ne 0 ]; then
  cat >&2 <<'EOF'

      A conflict resolved by committing its markers leaves a file that still reads
      as prose. The 0.557.0 squash shipped CHANGELOG.md to origin/main that way,
      with one release's heading separated from its own body, and the three arms
      above all read it GREEN -- they key on heading text, and a conflict marker is
      not a heading.

      Remedy: open each file named above, resolve the sections by hand, and delete
      every `<<<<<<<`, `=======` and `>>>>>>>` line. `git grep -n -e '^<<<<<<< '
      HEAD` locates them.
EOF
fi

if [ "$form_fail" -ne 0 ]; then
  cat >&2 <<'EOF'

      The consumer's ledger-reverify.sh reads a not-discharged citation only in its
      exact form. Any other spelling is an ordinary mention to it, and an ordinary
      mention reads as NAMED-UPSTREAM -- the false absorption the form exists to
      prevent.

      Remedy: put each cited id on its own BODY line, column 0, exactly
      `Not-discharged: PC-S<n>` or `Not-discharged: PC-S<n>-<SLUG>` (SLUG in the
      id class [A-Za-z0-9_.-], so a dotted or underscored id is written as-is) --
      no backticks, no bullet, never in the subject -- and amend the commit.
EOF
fi

if [ "$ledger_fail" -ne 0 ]; then
  cat >&2 <<'EOF'

      A bundle's ledger sections must be its members' bytes: each `## BL-` entry and each
      CHANGELOG block a member changed is the member's text (a `vVERSION_PLACEHOLDER` on
      its `**LANDED`/`**PARTIAL` line set to the release's version), an entry two members changed carries every line each of them added,
      and an entry no member changed is the base's. A three-way union of the members'
      appends can drop one of two identical lines where they meet, and no count notices.

      Remedy: rebuild docs/backlog.md, docs/backlog.archive.md and CHANGELOG.md from the
      base and each member's commit, entry by entry, never by a union merge, and amend.
      `git show <member>:docs/backlog.md` has each member's text.
EOF
fi

if [ "$fails" -ne 0 ] || [ "$range_fail" -ne 0 ] || [ "$base_fail" -ne 0 ] \
  || [ "$conflict_fail" -ne 0 ] || [ "$form_fail" -ne 0 ] || [ "$ledger_fail" -ne 0 ]; then
  exit 1
fi

# The PASS line enumerates the arms that ACTUALLY RAN, and says so per arm. A
# fixed summary would report an unevaluated arm as a green one, which is the
# failure mode this file is a response to.
summary="PASS  ${checked} commit(s)${SUBJECT_NOTE}: subject, VERSION and CHANGELOG heading agree"
if [ "$arm_c_ran" -eq 1 ]; then summary="$summary; one release in the range, no heading removed"
else                            summary="$summary; MULTI-RELEASE ARM NOT EVALUATED"; fi
if [ "$arm_d_ran" -eq 1 ]; then summary="$summary; no unpushed main commits inherited"
elif [ "$arm_d_why" = "on-main" ]; then summary="$summary; branch-base arm n/a on main"
elif [ "$arm_d_why" = "scoped-out" ]; then summary="$summary; branch-base arm n/a for an explicit range"
else                            summary="$summary; BRANCH-BASE ARM NOT EVALUATED"; fi
if [ "$arm_e_ran" -eq 1 ]; then summary="$summary; no committed conflict markers"
else                            summary="$summary; CONFLICT-MARKER ARM NOT EVALUATED"; fi
if [ "$arm_f_ran" -eq 1 ]; then summary="$summary; no misspelled not-discharged citation"
else                            summary="$summary; CITATION-FORM ARM NOT EVALUATED"; fi
if [ "$arm_g_ran" -eq 1 ]; then summary="$summary; every bundle's ledger sections match its members (member, multi-member, base, release-added:$arm_g_stat)"
elif [ "$arm_g_why" = "none" ]; then summary="$summary; bundle-ledger arm n/a, no bundle in the range"
else                            summary="$summary; BUNDLE-LEDGER ARM NOT EVALUATED"; fi
echo "$summary."
exit 0
}

# THE MAIN BODY IS A FUNCTION SEQUENCE, AND IT RUNS ONLY WHEN THIS FILE IS EXECUTED. The
# release-version-triple fixture sources a copy and calls rv_init, arm_c_range, arm_c, arm_d and
# arm_ab directly. Sourcing defines the functions and runs nothing; the guard
# is the idiom core/scripts/content-seal.sh uses. Every `exit` is unchanged: executed, it ends the
# script as before; in a sourced subshell it ends that subshell with the arm's own status.
rv_main() {
  rv_init "$@"
  arm_c_range
  arm_c
  arm_d
  arm_e
  arm_f
  arm_g
  arm_ab
  rv_report
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  rv_main "$@"
fi
