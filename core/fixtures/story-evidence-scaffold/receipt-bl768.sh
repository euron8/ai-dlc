#!/usr/bin/env bash
# BL-768 receipt (the full-collection and dependency-setup lines, enforced). Usage:
#   bash receipt-bl768.sh <path to validate-handoff-evidence.sh>
# Drives the validator, and the record-only-diff.sh beside it, over one scratch repository:
#   rec      `Full-collection run: none, <reason>` over a diff of the story, both sprint-status yamls,
#            a docs/reviews file and a test-results capture                      -> exit 0
#   code     the same none over the same diff plus one test file                -> exit 1 full-collection-none
#   missing  no Full-collection run: line                                       -> exit 1 full-collection-missing
#   present  both lines carrying a run and a setup, over the code diff          -> exit 0
#   na       `Full-collection run: N/A, <reason>` over the code diff             -> exit 1 full-collection-none
#   fence    an empty label over a fenced `$ pytest -q` / `1 passed` block       -> exit 0
#   bold     an empty label whose next line is `**Dependency setup:** ...`      -> exit 1 full-collection-none
#   nonebt   `none, see \`dev report\`` over the code diff                       -> exit 1 full-collection-none
#   evil     a none over a record diff plus test-results/test_evil.py            -> exit 1 full-collection-none
#   legacy   dev.md installed at <frozen> without the label, no lines at all      -> exit 0 with a LEGACY: line
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = validate-handoff-evidence.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl768.sh <path to validate-handoff-evidence.sh>" >&2; exit 9; }
HE="$1"
[ -f "$(dirname "$HE")/record-only-diff.sh" ] || { echo "REFUSED: no record-only-diff.sh beside $HE" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl768.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$R/w" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
S=stories/story-1.md
story() { # <full-collection line or empty> <dependency line>
  { printf -- '---\nstatus: review\n---\n# Story 1\n\n## Dev Agent Record\n\n'
    [ -z "$1" ] || printf '%s\n' "$1"
    printf '%s\n' "$2"
  } > "$R/w/$S"
}
mkdir -p "$R/w/stories" "$R/w/tests" || exit 9
g init -q || exit 9
printf 'def test_a():\n    assert True\n' > "$R/w/tests/test_a.py"
story '' ''
g add -A && g commit -qm base || exit 9
B="$(g rev-parse HEAD)"
mkdir -p "$R/w/_bmad-output/implementation-artifacts" "$R/w/_bmad-output/planning-artifacts" "$R/w/docs/reviews/s1" "$R/w/test-results" || exit 9
printf 'sprint: 1\n' > "$R/w/_bmad-output/implementation-artifacts/sprint-status.yaml"
printf 'sprint: 1\n' > "$R/w/_bmad-output/planning-artifacts/sprint-status.yaml"
printf '# Code Review: 1\n' > "$R/w/docs/reviews/s1/1-code-review.md"
printf '$ pytest -q\n1 passed\n' > "$R/w/test-results/full.txt"
NONE='Full-collection run: none, a record-only rework'
DS='Dependency setup: none, system pytest'
fails=0
one() { # <case> <want rc> <want token or empty>
  local o rc
  o="$(bash "$HE" -C "$R/w" "$S" "$B" "$(g rev-parse HEAD)" 2>/dev/null)"; rc=$?
  if [ "$rc" = "$2" ] && { [ -z "$3" ] || grep -q "^REFUSED $3 " <<<"$o"; }; then :
  else echo "FAIL $1: rc=$rc $(grep '^REFUSED' <<<"$o" | head -2 | tr '\n' ' ')"; fails=$((fails + 1)); fi
}
story "$NONE" "$DS"; g add -A && g commit -qm rec || exit 9
one rec 0 ''
printf 'def test_a():\n    assert 1\n' > "$R/w/tests/test_a.py"; g add -A && g commit -qm code || exit 9
one code 1 full-collection-none
story '' "$DS"; g add -A && g commit -qm missing || exit 9
one missing 1 full-collection-missing
story 'Full-collection run: `pytest -q` from the root: 1 passed, 0 failed, 0 deselected' 'Dependency setup: `pip install -r requirements.txt` at the root'
g add -A && g commit -qm present || exit 9
one present 0 ''
story 'Full-collection run: N/A, docs-only story' "$DS"; g add -A && g commit -qm na || exit 9
one na 1 full-collection-none
story "$(printf 'Full-collection run:\n\n```\n$ pytest -q\n1 passed\n```')" "$DS"; g add -A && g commit -qm fence || exit 9
one fence 0 ''
story "$(printf 'Full-collection run:\n**Dependency setup:** `pip install -r requirements.txt`')" "$DS"; g add -A && g commit -qm bold || exit 9
one bold 1 full-collection-none
story 'Full-collection run: none, see `dev report`' "$DS"; g add -A && g commit -qm nonebt || exit 9
one nonebt 1 full-collection-none
g checkout -q -b evil "$(g rev-list --max-parents=0 HEAD)" || exit 9
story "$NONE" "$DS"; mkdir -p "$R/w/test-results" && printf 'def test_evil():\n    assert False\n' > "$R/w/test-results/test_evil.py"
g add -A && g add -f test-results/test_evil.py && g commit -qm evil || exit 9
one evil 1 full-collection-none
story '' ''; mkdir -p "$R/w/.claude/team-roles" && printf '# Dev\n\nRecord the full-collection run.\n' > "$R/w/.claude/team-roles/dev.md"
g add -A && g commit -qm legacy || exit 9
o="$(bash "$HE" -C "$R/w" "$S" "$B" "$(g rev-parse HEAD)" 2>/dev/null)"; rc=$?
{ [ "$rc" = 0 ] && grep -q '^LEGACY: full-collection and dependency-setup lines not checked' <<<"$o"; } \
  || { echo "FAIL legacy: rc=$rc $(head -2 <<<"$o" | tr '\n' ' ')"; fails=$((fails + 1)); }
[ "$fails" -eq 0 ] || exit 1
exit 0
