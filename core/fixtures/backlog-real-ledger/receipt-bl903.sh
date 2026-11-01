#!/usr/bin/env bash
# receipt-bl903.sh -- BL-903: validate-mutant-kills.sh M1 reads a lowercase `killed` that names a
# killed RUN or PROCESS GROUP as prose, not as an unrouted mutant kill, and still refuses a real
# kill beside it. Exit 0 = the fix is present; 1 = the defect is live; 9 = the subject moved.
#
# It drives the shipping validator, never a copy of its grammar: a scratch tree carrying a VERSION
# marker, the repo's scripts/ and 102 run.sh (the corpus floor is 100), one holding the BL-903 instance text
# (core/fixtures/readset-skip/run.sh:5339 at 1a973b957, byte for byte) and one a real lowercase kill,
# the same-invocation control. `--derive` exits after the self-probe and the corpus read, before the
# allowlist arms, so the tree needs no allowlist. The fix lists `off` and `mfn` (a mutant named before
# a deny-sense `killed`) and not `prs`; the old grammar lists all three; a mask that ignores the named
# mutant drops `mfn`; a validator whose self-probe fails exits 2.
set -uo pipefail
# The root is found by walking up for the SUBJECT, never for VERSION: VERSION is outside the
# suite's content key (scripts/suite-content-key.sh EXCLUDE), so reading it is refused by I55.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/validate-mutant-kills.sh" ]; do ROOT="$(dirname "$ROOT")"; done
V="$ROOT/scripts/validate-mutant-kills.sh"
[ -f "$V" ] || { echo "receipt-bl903: no scripts/validate-mutant-kills.sh above $0" >&2; exit 9; }
grep -q 'function m1line' "$V" || exit 9

T="$(mktemp -d)" || exit 9
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/core/fixtures/prs" "$T/core/fixtures/off" "$T/core/fixtures/mfn" || exit 9
printf '0.0.0\n' > "$T/VERSION" || exit 9   # the validator's root marker; its value is never read
cp -R "$ROOT/scripts" "$T/scripts" || exit 9
i=0
while [ "$i" -lt 100 ]; do
  mkdir -p "$T/core/fixtures/stub$i" && printf '%s\n' 'ok "stub"' > "$T/core/fixtures/stub$i/run.sh"
  i=$((i + 1))
done
printf '%s\n' '      ok "INTERRUPTED GROUP: each killed run'\''s recorded process group was alive before the kill and empty after the reap ('\''1|0 1|0'\'', before|after for the run and the endonly run), so no orphan reaches IU'\''s trace root"' \
  > "$T/core/fixtures/prs/run.sh"
printf '%s\n' 'ok "mutant m3 killed by C1"' > "$T/core/fixtures/off/run.sh"
# a mutant named BEFORE a deny-sense `killed`: the mask must not acquit it
printf '%s\n' 'ok "mutant m4 killed runs past the cap"' > "$T/core/fixtures/mfn/run.sh"

out="$(bash "$T/scripts/validate-mutant-kills.sh" --derive 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "receipt-bl903: the validator exited $rc on the scratch tree:" >&2
  printf '%s\n' "$out" | sed 's/^/    /' >&2
  exit 1
fi
off_n="$(grep -cx 'off' <<< "$out")" || off_n=0
prs_n="$(grep -cx 'prs' <<< "$out")" || prs_n=0
mfn_n="$(grep -cx 'mfn' <<< "$out")" || mfn_n=0
if [ "$mfn_n" -ne 1 ]; then
  echo "receipt-bl903: a kill naming a mutant before a deny sense (ok \"mutant m4 killed runs past the cap\") was acquitted by the mask" >&2
  exit 1
fi
if [ "$off_n" -ne 1 ]; then
  echo "receipt-bl903: the control kill (ok \"mutant m3 killed by C1\") was not refused -- M1 accepts a real kill" >&2
  exit 1
fi
if [ "$prs_n" -ne 0 ]; then
  echo "receipt-bl903: the BL-903 prose (each killed run's recorded process group) is still read as an unrouted kill" >&2
  exit 1
fi
echo "receipt-bl903: fixed -- the killed-run prose is quiet and the control kill is refused"
exit 0
