#!/usr/bin/env bash
# receipt-bl931.sh <world dir> <review dir> -- the BL-931 receipt: at gate 2 pass M >= 2, gate-transition.sh takes
# Rule A's base from the LATEST gate-1 review (highest pass by number) when its verdict is APPROVED and its reviewed
# sha descends from the QA sha inside the frozen history, and its next: line names the index form gate 1 ran under.
#
# It starts no subject. gate-transition/run.sh calls it right after its RA1, RA0, RAN, RAX, RAA and RAM starts of the
# real gate-transition.sh, and it reads what they left in <world dir> (<tag>.rc, <tag>.err, <tag>.plan, <tag>.ls, the
# review files of that start's index), the two standalone --gate1-rerun answers (ra-go.out from the QA sha, ra-g1.out
# from the re-review's sha) and the shas (.GO, .G1). Gate-2 indexes are dash form, gate-1 files dot form.
#
#   ra1  p1 APPROVED, p2 APPROVED at G1 (GO < G1 <= the frozen sha), a p3 .md.draft: exit 0, `gate: 2`,
#        `rule-a-base: gate1 <G1> <p2 file>`, a GATE1-SKIP gate-log line.
#   ra0  the same world without p2: exit 0, `gate: rerun`, `rule-a-base: qa <GO> ...`, next: naming `5.1` and `--pass 2`.
#   ran  p9 APPROVED and p10 NEEDS_REWORK: p10 decides, exit 0, `gate: rerun`, base qa.
#   rax  the re-review on a side commit not ancestor-related to GO: exit 1, `REFUSED gate1-review`, no plan.
#   raa  gate-1 files under both index forms: exit 1, `REFUSED gate1-review` ambiguous, no plan.
#   ram  the re-review a MERGED file (several reviewed-sha and advisor lines): ra1's answer.
#
# Before reading a verdict it asserts the shape discriminates: the ra1 and ra0 listings differ by exactly the one p2
# file, --gate1-rerun from GO answers RERUN, and from G1 answers SKIP.
#
# Prints `receipt-bl931: PASS` and exits 0 when all six hold; prints `receipt-bl931: FAIL <cells>` and exits 1 when one
# does not; exits 9 when it cannot measure.
set -uo pipefail
refuse() { echo "receipt-bl931: cannot measure: $1"; exit 9; }
[ "$#" = 2 ] || refuse "usage: receipt-bl931.sh <world dir> <review dir>"
W="$1"; R="$2"
for t in ra1 ra0 ran rax raa ram; do [ -f "$W/$t.rc" ] && [ -f "$W/$t.err" ] && [ -f "$W/$t.ls" ] || refuse "no output of the $t start in $W"; done
for f in .GO .G1 ra-go.out ra-g1.out; do [ -s "$W/$f" ] || refuse "no $W/$f"; done
GO="$(cat "$W/.GO")"; G1="$(cat "$W/.G1")"
[ -n "$GO" ] && [ -n "$G1" ] && [ "$GO" != "$G1" ] || refuse "the QA sha and the re-review sha are not two shas"
dd="$(diff "$W/ra1.ls" "$W/ra0.ls")"
nd="$(grep -c '^[<>]' <<< "$dd")" || nd=0
[ "$nd" = 1 ] && grep -qx '< 5.1-code-review-p2.md' <<< "$dd" || refuse "the RA1 and RA0 worlds differ by $nd file(s), not by exactly 5.1-code-review-p2.md"
grep -q '^5.1-code-review-p3.md.draft$' "$W/ra1.ls" || refuse "the RA1 world carries no .md.draft beside its review files"
grep -q '^GATE1-RERUN' "$W/ra-go.out" || refuse "--gate1-rerun from the QA sha does not answer RERUN: $(head -1 "$W/ra-go.out")"
grep -q '^GATE1-SKIP' "$W/ra-g1.out" || refuse "--gate1-rerun from the re-review sha does not answer SKIP: $(head -1 "$W/ra-g1.out")"

rc() { cat "$W/$1.rc"; }
pl() { grep -qx -- "$2" "$W/$1.plan" 2> /dev/null; }
bad=""
[ "$(rc ra1)" = 0 ] && pl ra1 'gate: 2' && pl ra1 "rule-a-base: gate1 $G1 $R/5.1-code-review-p2.md" && grep -q '^gate-log: GATE1-SKIP' "$W/ra1.plan" || bad="$bad ra1"
[ "$(rc ra0)" = 0 ] && pl ra0 'gate: rerun' && pl ra0 "rule-a-base: qa $GO $R/5-1-qa-validation.md" \
  && grep -q '^next: gate-transition.sh 5\.1 1 --pass 2 ' "$W/ra0.plan" || bad="$bad ra0"
[ "$(rc ran)" = 0 ] && pl ran 'gate: rerun' && pl ran "rule-a-base: qa $GO $R/6-1-qa-validation.md" || bad="$bad ran"
[ "$(rc rax)" = 1 ] && grep -q 'REFUSED gate1-review: .*not ancestor-related' "$W/rax.err" && [ ! -e "$W/rax.plan" ] || bad="$bad rax"
[ "$(rc raa)" = 1 ] && grep -q 'REFUSED gate1-review: .*ambiguous' "$W/raa.err" && [ ! -e "$W/raa.plan" ] || bad="$bad raa"
[ "$(rc ram)" = 0 ] && pl ram 'gate: 2' && pl ram "rule-a-base: gate1 $G1 $R/9.1-code-review-p2.md" || bad="$bad ram"
if [ -z "$bad" ]; then echo "receipt-bl931: PASS"; exit 0; fi
echo "receipt-bl931: FAIL$bad"
exit 1
