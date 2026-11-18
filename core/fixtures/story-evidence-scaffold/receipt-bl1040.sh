#!/usr/bin/env bash
# BL-1040 receipt: four narrowed full-collection runs the dev gate's RUN-FILTER reading accepts. Usage:
#   bash receipt-bl1040.sh <path to validate-handoff-evidence.sh>
# Drives the validator over one scratch repository whose range touches a test file, one story per value:
#   ctl-pass    `pytest -q` from the repo root: accepted (no REFUSED full-collection-*), or the receipt cannot measure
#   ctl-filter  `pytest -q -k foo`: REFUSED full-collection-filtered, or the gate's filter is not wired and the
#               receipt cannot measure
#   s1  `pytest --cov -kfoo`                       (-k glued to its value after a flag)
#   s2  `PYTEST_ADDOPTS="-k foo" pytest -q`        (the filter in an environment assignment)
#   s3  `pytest -o python_functions=test_foo`      (collection narrowed through an ini override)
#   s4  `pytest -q && (pytest -k foo)`             (the narrowed command in a subshell)
#   ctl-prose   pytest -q (all tests) -k foo, 12 passed: REFUSED, a control (the shipping reader already refuses it;
#               accepted again is a regression the receipt cannot score, so 9)
# 0 = every subject s1-s4 refused (the fix is present). 1 = at least one still accepted (still reproduces; each
# accepted one is named). 9 = a control did not answer as above, or the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "REFUSED: usage: bash receipt-bl1040.sh <path to validate-handoff-evidence.sh>" >&2; exit 9; }
HE="$1"
grep -q 'Full-collection run:' "$HE" || { echo "REFUSED: $HE carries no Full-collection run arm" >&2; exit 9; }
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/he-inproc.sh" || { echo "REFUSED: he-inproc.sh is not beside this receipt" >&2; exit 9; }
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/world.sh" || { echo "REFUSED: lib/world.sh is not beside this receipt's fixtures" >&2; exit 9; }
[ -f "$(dirname "$HE")/record-only-diff.sh" ] || { echo "REFUSED: no record-only-diff.sh beside $HE" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl1040.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
W="$R/w"
gw() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 world_git -C "$W" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
mkdir -p "$W/stories" "$W/tests" || exit 9
gw init -q || exit 9
printf 'def test_a():\n    assert True\n' > "$W/tests/test_x.py"
gw add -A && gw commit -qm base || exit 9
B="$(gw rev-parse HEAD)"
printf 'def test_a():\n    assert 1 == 1\n' > "$W/tests/test_x.py"
story() { printf -- '---\nstatus: review\n---\n# %s\n\n## Dev Agent Record\n\nFull-collection run: %s\nDependency setup: none, system pytest.\n' "$1" "$2" > "$W/stories/$1.md"; }
story ctl-pass '`pytest -q` from the repo root: 3 passed'
story ctl-filter '`pytest -q -k foo` from the repo root: 3 passed'
story s1 '`pytest --cov -kfoo` from the repo root: 3 passed'
story s2 '`PYTEST_ADDOPTS="-k foo" pytest -q` from the repo root: 3 passed'
story s3 '`pytest -o python_functions=test_foo` from the repo root: 3 passed'
story s4 '`pytest -q && (pytest -k foo)` from the repo root: 3 passed'
story ctl-prose 'pytest -q (all tests) -k foo, 12 passed'
gw add -A && gw commit -qm work || exit 9
T="$(gw rev-parse HEAD)"
fcref() { he_run "$HE" -C "$W" "stories/$1.md" "$B" "$T" 2>/dev/null | awk '$1 == "REFUSED" && $2 ~ /^full-collection-/ { print $2 }' | sort -u | tr '\n' ' '; }
c1="$(fcref ctl-pass)"; c2="$(fcref ctl-filter)"
[ -z "$c1" ] || { echo "CANNOT MEASURE: ctl-pass refused [$c1]"; exit 9; }
case " $c2" in *" full-collection-filtered "*) ;; *) echo "CANNOT MEASURE: ctl-filter not refused full-collection-filtered [$c2]"; exit 9 ;; esac
[ -n "$(fcref ctl-prose)" ] || { echo "CANNOT MEASURE: ctl-prose (pytest -q (all tests) -k foo) accepted"; exit 9; }
live=""
for s in s1 s2 s3 s4; do [ -n "$(fcref "$s")" ] || live="$live $s"; done
if [ -z "$live" ]; then echo "FIXED: all four narrowed runs refused"; exit 0; fi
echo "LIVE: accepted as a full-collection run:$live"; exit 1
