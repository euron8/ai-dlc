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
#   A. A subject carrying a `vX.Y.Z` token must match VERSION at that commit.
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
#          grammar that includes it, and the probe below pins that acquittal. The
#          pair above already identifies the file; the middle marker adds nothing
#          to the join and would only widen it.
#
#      TWO THINGS THIS ARM DOES NOT SEE, STATED BECAUSE A BLIND SPOT NOBODY WROTE
#      DOWN IS READ AS COVERAGE.
#
#        - A TRUNCATED conflict, carrying one marker and not the other, is outside
#          the grammar by construction: the intersect requires both. The probe
#          below asserts that silence on a seeded open-marker-only file, which
#          documents the gap rather than acquitting it.
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
# USAGE
#   scripts/validate-release-version.sh [--range A..B] [--commit SHA]
#
#   default range   origin/main..HEAD -- the branch's own commits, which is what a
#                   push adds. Falls back to HEAD alone when that range is empty or
#                   origin/main is not present (a fresh clone, a detached head).
#
# EXIT
#   0  every checked commit's three names agree, the range carries one release,
#      the branch inherits nothing unpushed from local main, and no tracked file
#      carries conflict markers
#   1  a disagreement, a multi-release range, an unpushed-main inheritance, a
#      committed conflict, or a commit that could not be read

set -uo pipefail

# THE REPOSITORY ENVIRONMENT IS SCRUBBED BEFORE ANY GIT CALL. Git exports GIT_DIR
# absolute into a hook run from a linked worktree, and this program is both
# hook-dispatched and run directly. Arm E's self-probe builds a scratch repository
# under mktemp and relies on git's upward DISCOVERY to find it -- the branch git
# takes only when this environment is unset -- and its `git add` would otherwise
# write the CALLER's index. The corpus reads below take the same redirection
# silently. NOTHING ABOVE THIS LINE MAY CALL GIT.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "FAIL: not inside a git repository" >&2; exit 1; }

RANGE=""
COMMIT=""
SUBJECT_NOTE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --range)  RANGE="${2:-}"; shift 2 ;;
    --commit) COMMIT="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Resolve the commit list. --no-merges is load-bearing; see the header.
if [ -n "$COMMIT" ]; then
  COMMITS="$COMMIT"
elif [ -n "$RANGE" ]; then
  COMMITS="$(git rev-list --no-merges "$RANGE" 2>/dev/null)"
else
  COMMITS="$(git rev-list --no-merges origin/main..HEAD 2>/dev/null || true)"
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

semver_of() { printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }

# ---------------------------------------------------------------------------
# C. THE RANGE CARRIES AT MOST ONE RELEASE.
#
# Keyed on the CHANGELOG heading set at each end of the range, never on the
# triple's internal agreement -- see the header for why that distinction is the
# whole point of this arm.
# ---------------------------------------------------------------------------
headings_at() {
  # No `grep -m1`: the first heading is not the question, the SET is. Sorted
  # because comm requires it.
  git show "$1:CHANGELOG.md" 2>/dev/null \
    | grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | sort -u
}

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
elif git rev-parse -q --verify origin/main >/dev/null 2>&1; then
  range_tip="HEAD"
  range_base="$(git merge-base origin/main HEAD 2>/dev/null)" || range_base=""
  [ -n "$range_base" ] || range_why="HEAD and origin/main have no merge base"
else
  range_tip="HEAD"
  range_base="$(git rev-parse -q --verify HEAD^ 2>/dev/null)" || range_base=""
  [ -n "$range_base" ] || range_why="origin/main is absent and HEAD is a root commit"
fi

if [ -n "$range_base" ]; then
  arm_c_ran=1
  added="$(comm -13 <(headings_at "$range_base") <(headings_at "$range_tip"))"
  # `grep -c` prints 0 and exits 1 on no match; it answers this unaided and a
  # `|| echo 0` fallback would fire on exactly the case it appears to cover.
  n_added="$(printf '%s\n' "$added" | grep -c .)"
  if [ "${n_added:-0}" -ge 2 ]; then
    echo "FAIL  this range adds ${n_added} release headings to CHANGELOG.md: $(printf '%s\n' "$added" | tr -d '#[] ' | tr '\n' ' ')" >&2
    range_fail=1
  fi
else
  # Announced rather than skipped: an arm that goes quiet reads exactly like one
  # that passed, which is the defect this whole script exists downstream of.
  echo "NOTE  multi-release arm not evaluated -- $range_why"
fi

# ---------------------------------------------------------------------------
# D. THE BRANCH INHERITS NOTHING UNPUSHED FROM LOCAL main.
#
# Default mode only. An explicit --range or --commit is a question about those
# commits, not about the branch the operator happens to be standing on.
# ---------------------------------------------------------------------------
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

# THE SELF-PROBE RUNS BEFORE THE CORPUS, and it fires in both directions. An arm
# reporting no offenders without first proving it can produce one has established
# that it ran, not that the tree is clean. Built under mktemp, never on the real
# corpus.
#
# EACH NEAR-MISS IS ONE PROPERTY FROM THE OFFENDER, never two. `setext.md` is the
# rejected widening -- an H1 underline, quiet only because `^=======$` is not in
# the grammar. `nospace.md` carries a REAL close marker, so the only thing keeping
# it quiet is the open marker's missing trailing space. `openonly.md` carries a
# real open marker WITH its trailing space, so the only thing keeping it quiet is
# the intersection -- and that silence is the TRUNCATED-conflict blind spot named
# in the header, pinned here so a later author reads it as a measured limit rather
# than as coverage. A near-miss short of two properties discriminates against
# neither.
probe_e="$(mktemp -d 2>/dev/null)" || {
  echo "FAIL: arm E could not create its probe directory" >&2; exit 1; }
trap 'rm -rf "$probe_e"' EXIT
(
  cd "$probe_e" || exit 1
  git init -q . || exit 1
  git config user.email probe@example.com
  git config user.name probe
  git config commit.gpgsign false
  printf '<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> other-branch\n' > offender.md
  # A setext H1 underline. This is the shape that would join the population if
  # `^=======$` were in the grammar, and it is why it is not.
  printf 'A Heading\n=======\n\nbody text\n'                          > setext.md
  printf '<<<<<<<\nours\n>>>>>>> other-branch\n'                      > nospace.md
  # A TRUNCATED conflict: a real open marker, trailing space and all, with no
  # closing marker. The arm is silent on it BY CONSTRUCTION, and that silence is
  # asserted so the gap is on the record.
  printf '<<<<<<< HEAD\nours\n'                                       > openonly.md
  git add -A
  git commit -q -m 'probe corpus'
) >/dev/null 2>&1

probe_hits="$(conflict_files_in "$probe_e")"
probe_bad=""
grep -qxF 'offender.md' <<<"$probe_hits" \
  || probe_bad="the seeded offender was NOT reported"
for nm in setext.md nospace.md openonly.md; do
  if grep -qxF "$nm" <<<"$probe_hits"; then
    probe_bad="${probe_bad:+$probe_bad; }the near-miss $nm WAS reported"
  fi
done

if [ -n "$probe_bad" ]; then
  echo "FAIL  arm E's own probe did not discriminate -- $probe_bad. Every conflict verdict below would then be an empty set produced by a scan that cannot find an offender, which reads exactly like a clean tree." >&2
  conflict_fail=1
else
  arm_e_ran=1
  conflict_list="$(conflict_files_in .)"
  if [ -n "$conflict_list" ]; then
    echo "FAIL  tracked file(s) carry committed merge-conflict markers: $(printf '%s\n' "$conflict_list" | tr '\n' ' ')" >&2
    conflict_fail=1
  fi
fi

for c in $COMMITS; do
  short="$(git rev-parse --short "$c")"
  subject="$(git log -1 --format=%s "$c" 2>/dev/null)"

  version="$(git show "$c:VERSION" 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$version" ]; then
    echo "FAIL  $short  VERSION is missing or empty at this commit" >&2
    fails=$((fails+1)); continue
  fi

  changelog="$(semver_of "$(git show "$c:CHANGELOG.md" 2>/dev/null \
                | grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]')")"
  subj_ver="$(printf '%s' "$subject" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  subj_ver="${subj_ver#v}"

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

if [ "$range_fail" -ne 0 ]; then
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

if [ "$fails" -ne 0 ] || [ "$range_fail" -ne 0 ] || [ "$base_fail" -ne 0 ] \
  || [ "$conflict_fail" -ne 0 ]; then
  exit 1
fi

# The PASS line enumerates the arms that ACTUALLY RAN, and says so per arm. A
# fixed summary would report an unevaluated arm as a green one, which is the
# failure mode this file is a response to.
summary="PASS  ${checked} commit(s)${SUBJECT_NOTE}: subject, VERSION and CHANGELOG heading agree"
if [ "$arm_c_ran" -eq 1 ]; then summary="$summary; one release in the range"
else                            summary="$summary; MULTI-RELEASE ARM NOT EVALUATED"; fi
if [ "$arm_d_ran" -eq 1 ]; then summary="$summary; no unpushed main commits inherited"
elif [ "$arm_d_why" = "on-main" ]; then summary="$summary; branch-base arm n/a on main"
elif [ "$arm_d_why" = "scoped-out" ]; then summary="$summary; branch-base arm n/a for an explicit range"
else                            summary="$summary; BRANCH-BASE ARM NOT EVALUATED"; fi
if [ "$arm_e_ran" -eq 1 ]; then summary="$summary; no committed conflict markers (probe fired both ways)"
else                            summary="$summary; CONFLICT-MARKER ARM NOT EVALUATED"; fi
echo "$summary."
exit 0
