#!/usr/bin/env bash
# receipt-bl926.sh <world dir> <lead checkout> <plan dir> -- the BL-926 receipt: gate-transition.sh at pass 2 reads a
# merged (sharded) prior, which carries one column-0 `reviewed-sha:` line per shard, by its ONE distinct value.
#
# It starts no subject. gate-transition/run.sh calls it right after its PRIORM, PRIORD, QAM and QAD starts of the
# real gate-transition.sh, and it reads what those four starts left in <world dir> (<tag>.rc, <tag>.err) and in
# <plan dir> (the plans), with the priors they read under <lead checkout>/docs/reviews/s1/:
#
#   pm  gate 1 pass 2 over 1-1-code-review.md, a real merge-review-shards.sh output with >= 2 reviewed-sha lines
#       naming one sha: exit 0, a 1-1-g1-p2.plan whose `prior:` line names that file, no `REFUSED prior-review`.
#   pd  the same file with one line naming another sha (1-2-code-review.md): exit 1, `REFUSED prior-review` naming
#       2 distinct values, no 1-2-g1-p2.plan.
#   qm  gate 2 pass 2 over 4-1-qa-validation.md, three lines naming one sha: exit 0, a `gate: 2` 4-1-g2-p2.plan.
#   qd  4-2-qa-validation.md, two distinct values: exit 1, `REFUSED prior-validation` naming 2, no plan.
#
# Before reading a verdict it asserts the two code-review priors differ and the identical one carries more than one
# reviewed-sha line, so the pair can separate a line count from a distinct-value count.
#
# Prints `receipt-bl926: PASS` and exits 0 when all four hold; prints `receipt-bl926: FAIL <cells>` and exits 1
# when one does not; exits 9 when it cannot measure (an argument, a prior or a start's output is missing).
set -uo pipefail
refuse() { echo "receipt-bl926: cannot measure: $1"; exit 9; }
[ "$#" = 3 ] || refuse "usage: receipt-bl926.sh <world dir> <lead checkout> <plan dir>"
W="$1"; L="$2"; P="$3"; R="$L/docs/reviews/s1"
for f in "$R/1-1-code-review.md" "$R/1-2-code-review.md" "$R/4-1-qa-validation.md" "$R/4-2-qa-validation.md"; do
  [ -f "$f" ] || refuse "no prior $f"
done
for t in pm pd qm qd; do [ -f "$W/$t.rc" ] && [ -f "$W/$t.err" ] || refuse "no output of the $t start in $W"; done
! cmp -s "$R/1-1-code-review.md" "$R/1-2-code-review.md" || refuse "the identical and distinct code-review priors are byte-identical"
n="$(grep -c '^reviewed-sha:' "$R/1-1-code-review.md")" || n=0
[ "$n" -ge 2 ] || refuse "the merged prior carries $n reviewed-sha line(s); one line cannot separate a line count from a distinct count"

bad=""
[ "$(cat "$W/pm.rc")" = 0 ] && ! grep -q 'REFUSED prior-review' "$W/pm.err" \
  && grep -qxF "prior: $R/1-1-code-review.md" "$P/1-1-g1-p2.plan" 2> /dev/null || bad="$bad pm"
[ "$(cat "$W/pd.rc")" = 1 ] && grep -q 'REFUSED prior-review: .* carries 2 distinct' "$W/pd.err" && [ ! -e "$P/1-2-g1-p2.plan" ] || bad="$bad pd"
[ "$(cat "$W/qm.rc")" = 0 ] && grep -qx 'gate: 2' "$P/4-1-g2-p2.plan" 2> /dev/null || bad="$bad qm"
[ "$(cat "$W/qd.rc")" = 1 ] && grep -q 'REFUSED prior-validation: .* carries 2 distinct' "$W/qd.err" && [ ! -e "$P/4-2-g2-p2.plan" ] || bad="$bad qd"
if [ -z "$bad" ]; then echo "receipt-bl926: PASS"; exit 0; fi
echo "receipt-bl926: FAIL$bad"
exit 1
