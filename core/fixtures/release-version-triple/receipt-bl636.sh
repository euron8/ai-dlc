#!/bin/bash
# BL-636/BL-637 receipt. usage: receipt-bl636.sh [<validator>]; run from the repo root, stdin closed.
#   exit 0   the validator fails a release that replaces the previous heading in place, passes a
#            restored historical heading plus one new release (and says it did not count it), and
#            still fails a below-top heading the base's history never carried (the fix is present)
#   exit 1   it does not
#   exit 9   the receipt cannot measure: no validator, or its seeded repo could not be built
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
V="${1:-scripts/validate-release-version.sh}"
case "$V" in /*) ;; *) V="$(pwd -P)/$V" ;; esac
[ -f "$V" ] || exit 9
T="$(mktemp -d)" || exit 9
trap '[ -n "$T" ] && rm -rf "$T"' EXIT
cd "$T" && git init -q . && git config user.email r@x && git config user.name r && git config commit.gpgsign false || exit 9
snap() { local v="$1"; shift; printf '%s' "$v" > VERSION || return 1
  { printf '# Changelog\n'; for h in "$@"; do printf '\n## [%s] - 2026-01-01\n\n- e\n' "$h"; done; } > CHANGELOG.md || return 1
  git add -A && git commit -q -m "$v — r" || return 1; git rev-parse HEAD; }
snap 0.1.0 0.1.0 >/dev/null || exit 9
c2="$(snap 0.2.0 0.2.0 0.1.0)" || exit 9
r1="$(snap 0.3.0 0.3.0 0.1.0)" || exit 9                       # replaces 0.2.0 in place
git checkout -q -b b3 "$r1" || exit 9
r3="$(snap 0.4.0 0.4.0 0.3.0 0.2.0 0.1.0)" || exit 9          # restores 0.2.0 + one new
git checkout -q -b b5 "$r1" || exit 9
r5="$(snap 0.4.0 0.4.0 0.3.0 0.2.5 0.1.0)" || exit 9          # invents a below-top heading
[ -n "$c2" ] && [ -n "$r1" ] && [ -n "$r3" ] && [ -n "$r5" ] || exit 9
o1="$(bash "$V" --commit "$r1" 2>&1 </dev/null)"; e1=$?
o3="$(bash "$V" --commit "$r3" 2>&1 </dev/null)"; e3=$?
o5="$(bash "$V" --commit "$r5" 2>&1 </dev/null)"; e5=$?
[ "$e1" = 1 ] && grep -q 'removes release heading(s) present at its base: 0.2.0' <<<"$o1" \
 && [ "$e3" = 0 ] && grep -q 'not counted: 0.2.0' <<<"$o3" \
 && [ "$e5" = 1 ] && grep -q 'adds 2 release headings' <<<"$o5"
