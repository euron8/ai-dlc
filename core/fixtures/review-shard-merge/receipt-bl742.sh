#!/usr/bin/env bash
# BL-742 receipt (serial pre-return verdict check). Usage: bash receipt-bl742.sh <path to merge-review-shards.sh>
# Drives `--check-serial` on files this fixture's lib.sh writes in its own mktemp WORK, and reads the two
# role files lib.sh resolves for the step that tells each serial seat to run it.
#   qa  '## Verdict' then 'Verdict: PASS' (the BL-741 union) -> REFUSED (2 matches, 2 different values)
#   qa  'Verdict: PASS (all ACs)'                             -> SERIAL-OK (gate 3 reads PASS)
#   qa  two matches both reading PASS                         -> SERIAL-OK (one verdict, gate 3's rule)
#   qa  'Verdict: PASS-pending'                               -> REFUSED (the whole token is the value)
#   qa  '## Verdict' / APPROVED                               -> REFUSED (outside qa.md's set)
#   qa  '## Verdict' / PASS                                   -> SERIAL-OK (control)
#   code-review '## Result' / APPROVED (graph 1.1 p4)         -> REFUSED (0 matches)
#   code-review '## Verdict' / APPROVED                       -> SERIAL-OK (control)
#   qa.md and code-reviewer.md each name the --check-serial call in their serial passage
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl742.sh <path to merge-review-shards.sh>" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$(cd "$(dirname "$1")" && pwd)"
[ -f "$HERE/lib.sh" ] || { echo "REFUSED: no $HERE/lib.sh" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl742.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT

(
  NAME=receipt-bl742
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  one() { # <case> <want: ok|refused> <file> <gate> [token]
    local got
    sr_run "$SD" "$3" "$4"
    if [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK:"; then got=ok
    elif [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ]; then
      got=refused; { [ -z "${5:-}" ] || has "$CO" "$5"; } || got=refused-other
    else got=broken; fi
    printf '%s %s %s\n' "$1" "$2" "$got"
  }
  f="$WORK/r-1-qa-validation.md"; g="$WORK/r-1-code-review.md"
  sr_file "$f" "$(printf '## Verdict\n\nVerdict: PASS')"; one q-union refused "$f" qa "$SR_COUNT"
  sr_file "$f" "$(printf '## Verdict\nAPPROVED')"; one q-set refused "$f" qa "$SR_SET"
  sr_file "$f" "$(printf '## Verdict\nPASS')"; one q-ok ok "$f" qa
  sr_file "$g" "$(printf '## Result\nAPPROVED')"; one cr-renamed refused "$g" code-review "matches Check 1's verdict pattern 0 time(s)"
  sr_file "$g" "$(printf '## Verdict\nAPPROVED')"; one cr-ok ok "$g" code-review
  sr_file "$f" 'Verdict: PASS (all ACs)'; one q-paren ok "$f" qa
  sr_file "$f" "$(printf '**Verdict:** PASS\n\nQA verdict: PASS')"; one q-twosame ok "$f" qa
  sr_file "$f" 'Verdict: PASS-pending'; one q-suffix refused "$f" qa "Check 1 reads 'PASS-pending'"
  if p_serial_role "$QA_MD" "$ROLE_MD"; then echo "roles ok ok"; else echo "roles ok missing"; fi
  exit 0
) > "$R/rows" 2> "$R/err"
rc=$?
[ "$rc" -eq 0 ] || { echo "REFUSED: the receipt did not run (rc=$rc): $(head -1 "$R/err")" >&2; exit 9; }
n="$(grep -c . "$R/rows")" || n=0
[ "$n" = 9 ] || { echo "REFUSED: $n of 9 cases answered" >&2; exit 9; }
fails=0
while read -r case want got; do
  [ "$got" != broken ] || { echo "REFUSED: $case: --check-serial exited other than 0 or 2 with one REFUSED line" >&2; exit 9; }
  [ "$got" = "$want" ] || { echo "FAIL $case: want $want, got $got"; fails=$((fails + 1)); }
done < "$R/rows"
[ "$fails" -eq 0 ] || exit 1
exit 0
