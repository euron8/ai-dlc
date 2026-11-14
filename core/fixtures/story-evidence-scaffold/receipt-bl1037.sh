#!/usr/bin/env bash
# BL-1037 receipt: on the capture-cite route (`Full-collection run: <capture>, counts: capture-heads block`) the dev gate
# filters only the VALUE's text, never the command line the capture-heads block renders from the capture, so a plain
# cite of a capture that ran `pytest -k foo` is accepted. Usage:
#   bash receipt-bl1037.sh <path to validate-handoff-evidence.sh>
# Drives the validator over one scratch repository whose range touches a test file; each story's block is rendered at
# the work commit and pasted, as the dev pastes it. Stories:
#   ctl-pass    a plain cite of a capture that ran `pytest -q`: accepted, or the receipt cannot measure
#   ctl-filter  the value itself names `pytest -k foo` and cites the narrowed capture: REFUSED full-collection-filtered,
#               or the gate's filter is not wired and the receipt cannot measure
#   subject     a plain cite of the capture that ran `pytest -k foo`: the defect while it is accepted
# Seed control: every pasted block carries its capture's count, so the count route would accept each cite.
# 0 = the subject is refused (the fix is present). 1 = the subject is accepted (still reproduces). 9 = a control did not
# answer as above, or the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "REFUSED: usage: bash receipt-bl1037.sh <path to validate-handoff-evidence.sh>" >&2; exit 9; }
HE="$1"
grep -q 'capture-heads block' "$HE" || { echo "REFUSED: $HE carries no capture-heads count route" >&2; exit 9; }
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/he-inproc.sh" || { echo "REFUSED: he-inproc.sh is not beside this receipt" >&2; exit 9; }
[ -f "$(dirname "$HE")/record-only-diff.sh" ] || { echo "REFUSED: no record-only-diff.sh beside $HE" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl1037.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
W="$R/w"
gw() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$W" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
mkdir -p "$W/stories" "$W/tests" "$W/test-results" || exit 9
gw init -q || exit 9
printf 'def test_a():\n    assert True\n' > "$W/tests/test_x.py"
gw add -A && gw commit -qm base || exit 9
B="$(gw rev-parse HEAD)"
printf 'def test_a():\n    assert 1 == 1\n' > "$W/tests/test_x.py"
printf '$ pytest -q\nhead: %s\n3 passed\n' "$B" > "$W/test-results/full.txt"
printf '$ pytest -k foo\nhead: %s\n3 passed\n' "$B" > "$W/test-results/kf.txt"
story() { printf -- '---\nstatus: review\n---\n# %s\n\n## Dev Agent Record\n\nFull-collection run: %s\nDependency setup: none, system pytest.\n' "$1" "$2" > "$W/stories/$1.md"; }
story ctl-pass '`test-results/full.txt`, counts: capture-heads block'
story ctl-filter '`pytest -k foo`, capture `test-results/kf.txt`, counts: capture-heads block'
story subject '`test-results/kf.txt`, counts: capture-heads block'
gw add -A && gw commit -qm work || exit 9
X="$(gw rev-parse HEAD)"
for s in ctl-pass ctl-filter subject; do
  b="$(he_run "$HE" -C "$W" --render-dar "stories/$s.md" "$X" 2>/dev/null)" || true
  case "$b" in *"3 passed"*) ;; *) echo "CANNOT MEASURE: the block rendered for $s carries no count"; exit 9 ;; esac
  printf '\n%s\n' "$b" >> "$W/stories/$s.md"
done
gw add -A && gw commit -qm blocks || exit 9
T="$(gw rev-parse HEAD)"
fcref() { he_run "$HE" -C "$W" "stories/$1.md" "$B" "$T" 2>/dev/null | awk '$1 == "REFUSED" && $2 ~ /^full-collection-/ { print $2 }' | sort -u | tr '\n' ' '; }
c1="$(fcref ctl-pass)"; c2="$(fcref ctl-filter)"; s="$(fcref subject)"
[ -z "$c1" ] || { echo "CANNOT MEASURE: ctl-pass refused [$c1]"; exit 9; }
case " $c2" in *" full-collection-filtered "*) ;; *) echo "CANNOT MEASURE: ctl-filter not refused full-collection-filtered [$c2]"; exit 9 ;; esac
if [ -n "$s" ]; then echo "FIXED: a plain cite of a capture that ran \`pytest -k foo\` refused [$s]"; exit 0; fi
echo "LIVE: a plain cite of a capture that ran \`pytest -k foo\` accepted as a full-collection run"; exit 1
