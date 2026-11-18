#!/usr/bin/env bash
# BL-1036 receipt: a full-collection run that changes directory first (`cd <subdir> && pytest -q`) narrows the
# collection to that subdirectory, and the dev gate accepts it as a full-collection run. Usage:
#   bash receipt-bl1036.sh <path to validate-handoff-evidence.sh>
# Drives the validator over one scratch repository whose range touches a test file, with three stories:
#   ctl-pass    `pytest -q` from the repo root: accepted (no REFUSED full-collection-*), or the receipt cannot measure
#   ctl-filter  `pytest -q -k foo`: REFUSED full-collection-filtered, or the gate's filter is not wired and the
#               receipt cannot measure
#   subject     `cd server && pytest -q`: the defect while it is accepted
# 0 = the subject is refused (the fix is present). 1 = the subject is accepted (still reproduces). 9 = a control did not
# answer as above, or the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "REFUSED: usage: bash receipt-bl1036.sh <path to validate-handoff-evidence.sh>" >&2; exit 9; }
HE="$1"
grep -q 'Full-collection run:' "$HE" || { echo "REFUSED: $HE carries no Full-collection run arm" >&2; exit 9; }
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/he-inproc.sh" || { echo "REFUSED: he-inproc.sh is not beside this receipt" >&2; exit 9; }
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/world.sh" || { echo "REFUSED: lib/world.sh is not beside this receipt's fixtures" >&2; exit 9; }
[ -f "$(dirname "$HE")/record-only-diff.sh" ] || { echo "REFUSED: no record-only-diff.sh beside $HE" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl1036.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
W="$R/w"
gw() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 world_git -C "$W" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
mkdir -p "$W/stories" "$W/tests" "$W/server" || exit 9
gw init -q || exit 9
printf 'def test_a():\n    assert True\n' > "$W/tests/test_x.py"
gw add -A && gw commit -qm base || exit 9
B="$(gw rev-parse HEAD)"
printf 'def test_a():\n    assert 1 == 1\n' > "$W/tests/test_x.py"
story() { printf -- '---\nstatus: review\n---\n# %s\n\n## Dev Agent Record\n\nFull-collection run: %s\nDependency setup: none, system pytest.\n' "$1" "$2" > "$W/stories/$1.md"; }
story ctl-pass '`pytest -q` from the repo root: 3 passed'
story ctl-filter '`pytest -q -k foo` from the repo root: 3 passed'
story subject '`cd server && pytest -q` from the repo root: 3 passed'
gw add -A && gw commit -qm work || exit 9
T="$(gw rev-parse HEAD)"
fcref() { he_run "$HE" -C "$W" "stories/$1.md" "$B" "$T" 2>/dev/null | awk '$1 == "REFUSED" && $2 ~ /^full-collection-/ { print $2 }' | sort -u | tr '\n' ' '; }
c1="$(fcref ctl-pass)"; c2="$(fcref ctl-filter)"; s="$(fcref subject)"
[ -z "$c1" ] || { echo "CANNOT MEASURE: ctl-pass refused [$c1]"; exit 9; }
case " $c2" in *" full-collection-filtered "*) ;; *) echo "CANNOT MEASURE: ctl-filter not refused full-collection-filtered [$c2]"; exit 9 ;; esac
if [ -n "$s" ]; then echo "FIXED: \`cd server && pytest -q\` refused [$s]"; exit 0; fi
echo "LIVE: \`cd server && pytest -q\` accepted as a full-collection run"; exit 1
