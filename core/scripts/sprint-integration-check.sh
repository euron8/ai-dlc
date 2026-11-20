#!/usr/bin/env bash
# sprint-integration-check.sh -- story-to-sprint integration, run in the sprint tree at implementation close
# (and again at sprint-review Step 0).
#
# USAGE
#   sprint-integration-check.sh [--onto <sprint-branch|sha>] [--base <ref>] [--append-only <path>]...
#                               [--story-file <path>]... [--registry <path>]
#                               [--suite <command> --suite-summary <path>] [<story-branch>...]
#     <story-branch>       each is merged into the checked-out sprint branch unless it is already an
#                          ancestor of HEAD; a conflicting merge is aborted and reported, never resolved here
#     --onto <ref>         required with any <story-branch>: the sprint branch name or sha the merges land on; the
#                          script refuses (exit 2) unless the checked-out branch is that name or HEAD is that sha
#     --base <ref>         the sprint's base; required by --append-only
#     --append-only <p>    a log the sprint only appends to: every line of <base>:<p> must still be in HEAD:<p>
#     --story-file <p>     a story file: exactly one `## Dev Agent Record` heading
#     --registry <path>    the test registry (`ci-local`): every test file added in <base>..HEAD (a path whose basename
#                          matches test_*, *_test.*, *.test.* or *.spec.*) must be named in it; needs --base
#     --suite <command>    run once after the merges with `bash -c`; a non-zero exit is a failure
#     --suite-summary <p>  required with --suite: the short summary file written there (suite exit code, pass and fail
#                          line counts, up to 40 failing lines), never the suite's log; the caller commits it
# OUTPUT  one line per finding, then `RESULT PASS examined ...` or `RESULT FAIL <n> examined ...` where examined
#         names the counts of branches, story files, append-only logs, new test files and suites it looked at:
#     ANCESTOR <b> | MERGED <b> | CONFLICT <b> <files> | NO-REF <b> | LOST-LINE <path> <line>
#     DUP-RECORD <file> <count> | NO-RECORD <file> | UNREGISTERED <test-file> | SUITE-FAIL <rc>
# EXIT    0 = no finding, 1 = at least one finding, 2 = refusal (not a git tree, dirty tree, bad option, nothing
#         supplied to examine, --onto missing or not the checked-out sprint tree).
# The sprint tree is the working directory; a clean tree is required because a merge needs one.
set -uo pipefail

base=""; suite=""; registry=""; onto=""; sumfile=""; ntests=0
appends=(); stories=(); branches=()
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="${2:-}"; shift 2 || exit 2 ;;
    --append-only) appends+=("${2:-}"); shift 2 || exit 2 ;;
    --story-file) stories+=("${2:-}"); shift 2 || exit 2 ;;
    --registry) registry="${2:-}"; shift 2 || exit 2 ;;
    --suite) suite="${2:-}"; shift 2 || exit 2 ;;
    --suite-summary) sumfile="${2:-}"; shift 2 || exit 2 ;;
    --onto) onto="${2:-}"; shift 2 || exit 2 ;;
    --) shift; while [ $# -gt 0 ]; do branches+=("$1"); shift; done ;;
    -*) echo "sprint-integration-check: unknown option $1" >&2; exit 2 ;;
    *) branches+=("$1"); shift ;;
  esac
done

top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "sprint-integration-check: not a git tree" >&2; exit 2; }
cd "$top" || exit 2
if { [ "${#appends[@]}" -gt 0 ] || [ -n "$registry" ]; } && [ -z "$base" ]; then echo "sprint-integration-check: --append-only and --registry need --base" >&2; exit 2; fi
if [ "${#branches[@]}" -eq 0 ] && [ "${#stories[@]}" -eq 0 ] && [ "${#appends[@]}" -eq 0 ] && [ -z "$registry" ]; then
  echo "sprint-integration-check: EXAMINED NOTHING: no story branch, --story-file, --append-only or --registry was given; a PASS here would have looked at nothing" >&2; exit 2
fi
if [ -n "$suite" ] && [ -z "$sumfile" ]; then echo "sprint-integration-check: --suite needs --suite-summary <path>" >&2; exit 2; fi
if [ "${#branches[@]}" -gt 0 ]; then
  [ -n "$onto" ] || { echo "sprint-integration-check: merging story branches needs --onto <sprint-branch|sha>" >&2; exit 2; }
  cur_br="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || cur_br=""
  onto_sha="$(git rev-parse --verify --quiet "${onto}^{commit}" 2>/dev/null)" || onto_sha=""
  head_sha="$(git rev-parse HEAD 2>/dev/null)" || head_sha=""
  if [ "$cur_br" != "$onto" ] && { [ -z "$onto_sha" ] || [ "$onto_sha" != "$head_sha" ]; }; then
    echo "sprint-integration-check: HEAD (${cur_br:-detached} at ${head_sha:-none}) is not --onto $onto; refusing to merge into the wrong tree" >&2; exit 2
  fi
fi
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "sprint-integration-check: the sprint tree has uncommitted changes" >&2; exit 2
fi

nfind=0
finding() { echo "$*"; nfind=$((nfind + 1)); }

for b in ${branches[@]+"${branches[@]}"}; do
  if ! git rev-parse --verify --quiet "${b}^{commit}" >/dev/null; then finding "NO-REF $b"; continue; fi
  if git merge-base --is-ancestor "$b" HEAD; then echo "ANCESTOR $b"; continue; fi
  if git merge --no-ff --no-edit -m "Merge $b into sprint branch" "$b" >/dev/null 2>&1; then
    echo "MERGED $b"
  else
    files="$(git diff --name-only --diff-filter=U | tr '\n' ' ')"
    git merge --abort >/dev/null 2>&1
    finding "CONFLICT $b ${files% }"
  fi
done

tmp="$(mktemp -d)" || exit 2
for p in ${appends[@]+"${appends[@]}"}; do
  if ! git cat-file -e "${base}:${p}" 2>/dev/null; then echo "ABSENT-AT-BASE $p"; continue; fi
  git show "${base}:${p}" | LC_ALL=C sort -u > "$tmp/base"
  if git cat-file -e "HEAD:${p}" 2>/dev/null; then git show "HEAD:${p}" | LC_ALL=C sort -u > "$tmp/head"; else : > "$tmp/head"; fi
  while IFS= read -r l; do finding "LOST-LINE $p $l"; done < <(LC_ALL=C comm -23 "$tmp/base" "$tmp/head")
done

for f in ${stories[@]+"${stories[@]}"}; do
  if [ ! -f "$f" ]; then finding "NO-RECORD $f"; continue; fi
  n="$(grep -c '^## Dev Agent Record[[:space:]]*$' "$f")" || n=0
  if [ "$n" -eq 0 ]; then finding "NO-RECORD $f"
  elif [ "$n" -gt 1 ]; then finding "DUP-RECORD $f $n"; fi
done

if [ -n "$registry" ]; then
  if [ ! -f "$registry" ]; then finding "NO-REGISTRY $registry"; else
    while IFS= read -r t; do
      b="${t##*/}"
      case "$b" in test_*|*_test.*|*.test.*|*.spec.*) ;; *) continue ;; esac
      ntests=$((ntests + 1))
      grep -qF -- "$t" "$registry" || grep -qF -- "$b" "$registry" || finding "UNREGISTERED $t"
    done < <(git diff --name-only --diff-filter=A "$base" HEAD)
  fi
fi

if [ -n "$suite" ]; then
  slog="$tmp/suite.log"
  bash -c "$suite" > "$slog" 2>&1; src=$?
  npass="$(grep -cE '^(ok |PASS|[[:space:]]+ok )' "$slog")" || npass=0
  nfail="$(grep -cE '^(not ok |FAIL|FAILED)' "$slog")" || nfail=0
  mkdir -p "$(dirname "$sumfile")" || exit 2
  { echo "suite_exit: $src"; echo "pass_lines: $npass"; echo "fail_lines: $nfail"
    grep -E '^(not ok |FAIL|FAILED)' "$slog" | head -n 40 | cut -c1-200 | sed 's/^/failing: /'; } > "$sumfile" || exit 2
  echo "SUITE-SUMMARY $sumfile"
  [ "$src" -eq 0 ] || finding "SUITE-FAIL $src"
fi

rm -f "$tmp/base" "$tmp/head" "$tmp/suite.log"; rmdir "$tmp" 2>/dev/null
ex="examined branches=${#branches[@]} story-files=${#stories[@]} logs=${#appends[@]} test-files=$ntests suites=$([ -n "$suite" ] && echo 1 || echo 0)"
if [ "$nfind" -eq 0 ]; then echo "RESULT PASS $ex"; exit 0; fi
echo "RESULT FAIL $nfind $ex"; exit 1
