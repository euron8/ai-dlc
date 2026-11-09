#!/usr/bin/env bash
# receipt-bl938.sh <world dir> <seed dir> -- the BL-938 receipt: `sprint-status.sh roll` relocates a BMAD copy out
# of a view's freeze slot and freezes over it, decides every view before any write, completes the tree an older
# engine half-rolled, and refuses (exit 1) a preamble-only view beside a view it would write.
#
# It starts no subject. sprint-status-lifecycle/run.sh calls it after the shipping tool's R12-R23 worlds, each of
# which ran ONE `roll --sprint 322` and left, in <world dir>/<arm>/: rc, out, err, and before.ls / after.ls (every
# file under _bmad-output as `<relpath> <mode> <md5>`). R16 also left sid.rc / sid.out from its sprint-id. The
# world trees themselves are gone (each arm resets the tree), so bytes are read off the listings' md5s and
# compared against the md5s of the seed files in <seed dir> (plan321, impl321, bmad, ...).
#
#   r12  rc 0; after: planning-artifacts/s321/sprint-status.yaml == plan321, .../bmad-sprint-status.yaml == bmad,
#        implementation-artifacts/s321/sprint-status.yaml == impl321; before: the slot held bmad.
#   r14  rc 3; after.ls == before.ls whole; no implementation-artifacts/s321/sprint-status.yaml in after; stderr
#        names the planning slot and carries `Remedy:`.
#   r16  rc 0; sprint-id rc 0 printing 322; the planning freeze == plan321 and the BMAD copy relocated.
#   r23  rc 1; after.ls == before.ls; stderr carries `Restore`.
#
# Before reading a verdict it asserts the shape discriminates: R12's before-listing holds the BMAD seed in the
# slot, R14's before-listing holds no implementation freeze, and the plan321 and bmad seeds differ.
#
# Prints `receipt-bl938: PASS` and exits 0 when all four hold; prints `receipt-bl938: FAIL <cells>` and exits 1
# when one does not; exits 9 when it cannot measure.
set -uo pipefail
refuse() { echo "receipt-bl938: cannot measure: $1"; exit 9; }
[ "$#" = 2 ] || refuse "usage: receipt-bl938.sh <world dir> <seed dir>"
W="$1"; S="$2"
for t in R12 R14 R16 R23; do
  for f in rc err before.ls after.ls; do [ -f "$W/$t/$f" ] || refuse "no $f of the $t roll in $W"; done
done
[ -f "$W/R16/sid.rc" ] && [ -f "$W/R16/sid.out" ] || refuse "no sprint-id output of the R16 world in $W"
md5_of() { python3 -I -c 'import hashlib, sys; print(hashlib.md5(open(sys.argv[1], "rb").read()).hexdigest())' "$1"; }
for s in plan321 impl321 bmad; do [ -s "$S/$s" ] || refuse "no seed $S/$s"; done
MP="$(md5_of "$S/plan321")"; MI="$(md5_of "$S/impl321")"; MB="$(md5_of "$S/bmad")"
[ -n "$MP" ] && [ -n "$MB" ] && [ "$MP" != "$MB" ] && [ "$MP" != "$MI" ] || refuse "the seeds do not differ (plan321=$MP impl321=$MI bmad=$MB)"
SLOT=planning-artifacts/s321/sprint-status.yaml
RELO=planning-artifacts/s321/bmad-sprint-status.yaml
IFRZ=implementation-artifacts/s321/sprint-status.yaml
has() { grep -q "^$2 [0-7]* $3\$" "$W/$1"; }   # <arm/listing> <relpath> <md5>
has R12/before.ls "$SLOT" "$MB" || refuse "R12's world did not hold the BMAD seed in the planning slot before the roll"
grep -q "^$IFRZ " "$W/R14/before.ls" && refuse "R14's world already held an implementation freeze before the roll"

rc() { cat "$W/$1/rc"; }
bad=""
[ "$(rc R12)" = 0 ] && has R12/after.ls "$SLOT" "$MP" && has R12/after.ls "$RELO" "$MB" && has R12/after.ls "$IFRZ" "$MI" || bad="$bad r12"
[ "$(rc R14)" = 3 ] && cmp -s "$W/R14/before.ls" "$W/R14/after.ls" && ! grep -q "^$IFRZ " "$W/R14/after.ls" \
  && grep -qF "$SLOT" "$W/R14/err" && grep -q 'Remedy:' "$W/R14/err" || bad="$bad r14"
[ "$(rc R16)" = 0 ] && [ "$(cat "$W/R16/sid.rc")" = 0 ] && [ "$(cat "$W/R16/sid.out")" = 322 ] \
  && has R16/after.ls "$SLOT" "$MP" && has R16/after.ls "$RELO" "$MB" || bad="$bad r16"
[ "$(rc R23)" = 1 ] && cmp -s "$W/R23/before.ls" "$W/R23/after.ls" && grep -q 'Restore' "$W/R23/err" || bad="$bad r23"
if [ -z "$bad" ]; then echo "receipt-bl938: PASS"; exit 0; fi
echo "receipt-bl938: FAIL$bad"
exit 1
