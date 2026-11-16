# shellcheck shell=bash
# core/fixtures/lib/layout.sh -- the fixture's install layout, read from the fixture's own directory.
#
# A fixture runs from <root>/core/fixtures/<f>/ in the distribution and from <root>/tests/fixtures/<f>/ on a
# consumer; core/scripts/hermetic-run.sh reproduces that relative path inside its sandbox, so the answer is the
# same under the hook, in a plain run and on a consumer. A probe of a subject file (`core/skills/ai-dlc` and the
# like) is not: inside the sandbox it reads absent whenever the fixture declares nothing under it.
#
# fx_dist_layout <fixture dir>   status 0 when the fixture's parent directory is .../core/fixtures, else 1.
# fx_skip_exit <fixture dir>     ends a SKIP the caller has already printed: exit 0 on a consumer, where a core
#                                fixture may arrive before its subject; in the distribution, where the subject is
#                                always present, FIXTURE BROKEN on stderr and exit 2 (fixture-mutants.md
#                                "One run per distinct state", clause 7).
fx_dist_layout() {
  local p
  p="$(cd "$1/.." 2>/dev/null && pwd -P)" || return 1
  case "$p" in */core/fixtures) return 0 ;; esac
  return 1
}
fx_skip_exit() {
  if fx_dist_layout "$1"; then
    echo "FIXTURE BROKEN: ${1%/} took a SKIP in the distribution layout, where its subject must be present" >&2
    exit 2
  fi
  exit 0
}
