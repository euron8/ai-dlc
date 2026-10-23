#!/usr/bin/env bash
# BL-769 receipt (a QA PASS waits for its canonical run). Usage: bash receipt-bl769.sh <path to merge-review-shards.sh>
# Drives `--check-serial --gate qa` on files this fixture's lib.sh writes, with record-only-diff.sh beside the merge:
#   PASS, run line + counted result                                   -> SERIAL-OK
#   PASS, counts only on a RED replay line                            -> REFUSED (no Canonical run: line)
#   PASS, `pytest -k ...` invocation                                  -> REFUSED (filtered)
#   PASS, NOT FINISHED result                                         -> REFUSED
#   NEEDS_REWORK with no run                                          -> SERIAL-OK
#   PASS, 'Canonical run: none, <reason>' over a record-only range    -> SERIAL-OK
#   PASS, the same none over a range touching a test file             -> REFUSED (not record-only)
#   PASS, the same none over a seat-narrowed rework range (code..rework) -> REFUSED (not a gate-1 base)
#   PASS, 'N/A, ...' over the code range                              -> REFUSED (a no-run claim, not record-only)
#   PASS, `python -m pytest -m unit` (no conventions file)           -> SERIAL-OK
#   PASS, `pytest tests/test_one.py`                                  -> REFUSED (a file argument)
#   PASS, `npx vitest run web/src/foo.test.jsx --root web`            -> REFUSED (a test-file argument)
#   PASS, `pytest tests -x --lf`                                      -> REFUSED (last failures only)
#   PASS, 'none, `pytest -q` is not needed here' over the code range  -> REFUSED (a none, not a run)
#   PASS, no run line, under a root whose qa.md lacks the sentinel    -> SERIAL-OK with a LEGACY: line
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl769.sh <path to merge-review-shards.sh>" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$(cd "$(dirname "$1")" && pwd)"
[ -f "$HERE/lib.sh" ] && [ -f "$SD/record-only-diff.sh" ] || { echo "REFUSED: no lib.sh, or no record-only-diff.sh beside the merge" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl769.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
(
  NAME=receipt-bl769
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  one() { # <case> <want: ok|refused> <file> [token] [extra args...]
    local c="$1" w="$2" f="$3" t="${4:-}" got; shift 3; [ "$#" -gt 0 ] && shift
    cr_run "$SD" "$f" "$@"
    if [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK:"; then got=ok
    elif [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ]; then got=refused; { [ -z "$t" ] || has "$CO" "$t"; } || got=refused-other
    else got=broken; fi
    printf '%s %s %s\n' "$c" "$w" "$got"
  }
  f="$CR_REPO/docs/reviews/s1/r-1-qa-validation.md"; pv="$(printf '## Verdict\nPASS')"
  SR_CANON="$CANON_BLK" sr_file "$f" "$pv"; one counted ok "$f"
  SR_CANON="$(printf 'RED replay: 1 failed, 4 passed')" sr_file "$f" "$pv"; one redonly refused "$f" "$CR_NORUN"
  SR_CANON="$(printf 'Canonical run: `pytest -k test_new` from the root\nCanonical result: 9 passed')" sr_file "$f" "$pv"; one filtered refused "$f" "$CR_FILT"
  SR_CANON="$(printf 'Canonical run: `pytest -q`\nCanonical result: NOT FINISHED, 3801 passed so far')" sr_file "$f" "$pv"; one unfinished refused "$f" "$CR_UNFIN"
  SR_CANON='' sr_file "$f" 'Verdict: NEEDS_REWORK' '' "$(printf '### Important (x)\n\n#### Q-1 the handoff lacks the run\n\nBody.')"; one nr ok "$f"
  SR_CANON='Canonical run: none, the diff is record-only' sr_file "$f" "$pv"
  one exempt-rec ok "$f" '' --story "$CR_STORY" --range "$CR_BASE" "$CR_REC"
  one exempt-code refused "$f" "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"
  one exempt-narrow refused "$f" "$CR_GATE1" --story "$CR_STORY" --range "$CR_CODE" "$CR_P2"
  SR_CANON='Canonical run: N/A, docs-only story' sr_file "$f" "$pv"
  one norun-na refused "$f" "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"
  SR_CANON="$(printf 'Canonical run: `.venv/bin/python -m pytest -m unit` from the root\nCanonical result: 9 passed')" sr_file "$f" "$pv"; one marker ok "$f"
  SR_CANON="$(printf 'Canonical run: `pytest tests/test_one.py`\nCanonical result: 9 passed')" sr_file "$f" "$pv"; one file refused "$f" "$CR_FILE"
  SR_CANON="$(printf 'Canonical run: `npx vitest run web/src/foo.test.jsx --root web`\nCanonical result: 9 passed')" sr_file "$f" "$pv"; one vitest-file refused "$f" "$CR_FILE"
  SR_CANON="$(printf 'Canonical run: `pytest tests -x --lf`\nCanonical result: 9 passed')" sr_file "$f" "$pv"; one lf refused "$f" "re-runs only the last failures"
  SR_CANON='Canonical run: none, `pytest -q` is not needed here' sr_file "$f" "$pv"
  one nonebt refused "$f" "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"
  SR_CANON='' sr_file "$f" "$pv"
  CR_ROOT="$PROJ_CRS" cr_run "$SD" "$f"
  if [ "$SRC" -eq 0 ] && has "$CO" "LEGACY: canonical-run lines not checked:" && has "$CO" "SERIAL-OK:"; then echo "legacy ok ok"; else echo "legacy ok refused"; fi
  exit 0
) > "$R/rows" 2> "$R/err"
rc=$?
[ "$rc" -eq 0 ] || { echo "REFUSED: the receipt did not run (rc=$rc): $(head -1 "$R/err")" >&2; exit 9; }
n="$(grep -c . "$R/rows")" || n=0
[ "$n" = 15 ] || { echo "REFUSED: $n of 15 cases answered" >&2; exit 9; }
fails=0
while read -r case want got; do
  [ "$got" != broken ] || { echo "REFUSED: $case: --check-serial exited other than 0 or 2 with one REFUSED line" >&2; exit 9; }
  [ "$got" = "$want" ] || { echo "FAIL $case: want $want, got $got"; fails=$((fails + 1)); }
done < "$R/rows"
[ "$fails" -eq 0 ] || exit 1
exit 0
