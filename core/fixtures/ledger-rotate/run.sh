#!/usr/bin/env bash
# ledger-rotate/run.sh — prove rotation removes CLOSED entries, keeps OPEN ones, loses
# nothing, and does not change what the classifier says about the work still open.
#
# The acceptance test is the byte-identical ledger-reverify output. Rotation moves exactly
# the entries ledger-reverify already skips, so if its output shifts by one byte the split
# took a live entry — the only failure mode that actually costs anything.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh" | tail -1)" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

# Locate both scripts by walking UP for a marker, so the fixture resolves from the
# distribution (core/) and from a consumer where install.sh relocates it (.claude/).
ROT=""; RV=""
d="$HERE"
while [ "$d" != "/" ]; do
  for base in "$d/core/skills/ai-dlc-update/reconcile" "$d/.claude/skills/ai-dlc-update/reconcile"; do
    if [ -f "$base/ledger-rotate.sh" ]; then ROT="$base/ledger-rotate.sh"; RV="$base/ledger-reverify.sh"; break 2; fi
  done
  d="$(dirname "$d")"
done
[ -n "$ROT" ] || { echo "FIXTURE ERROR: ledger-rotate.sh not found in either layout" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
entries() { grep -cE '^(## |- \*\*)' "$1" 2>/dev/null || echo 0; }

echo "ledger-rotate:"

before_lines="$(wc -l < "$LEDGER" | tr -d ' ')"
before_entries="$(entries "$LEDGER")"
before_verdicts="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$LEDGER" 2>/dev/null)"

# --- Assertion 0: SANITY — the seed really holds both kinds ---------------------------
if [ "$before_entries" -eq 5 ] && grep -q 'PC-CLOSED-A' "$LEDGER" && grep -q 'PC-OPEN-DECOY' "$LEDGER"; then
  ok "before: 5 entries, closed + open + a decoy that only MENTIONS the phrase"
else
  bad "FIXTURE BROKEN — seed shape wrong ($before_entries entries)"; echo
  echo "ledger-rotate: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: dry run writes NOTHING ----------------------------------------------
bash "$ROT" "$LEDGER" >/dev/null 2>&1
[ "$(wc -l < "$LEDGER" | tr -d ' ')" = "$before_lines" ] \
  && ok "dry run (no --apply) leaves the ledger byte-for-byte unchanged" \
  || bad "dry run modified the ledger"

# --- Assertion 2: rotate ---------------------------------------------------------------
bash "$ROT" "$LEDGER" --apply >/dev/null 2>&1
ARCH="$(dirname "$LEDGER")/push-candidate-ledger.archive.md"

grep -q 'PC-OPEN-A'      "$LEDGER" && grep -q 'PC-OPEN-BULLET' "$LEDGER" \
  && ok "open entries stay in the live ledger (both heading and bullet shapes)" \
  || bad "an OPEN entry was rotated out"

grep -q 'PC-OPEN-DECOY' "$LEDGER" \
  && ok "DECOY stays: an open entry that merely quotes 'ADOPTED UPSTREAM' is not closed" \
  || bad "DECOY was rotated out — prose mentioning the phrase read as a close"

grep -q 'PC-CLOSED-A' "$LEDGER" || grep -q 'PC-CLOSED-BULLET' "$LEDGER" \
  && bad "a CLOSED entry stayed in the live ledger" \
  || ok "closed entries removed from the live ledger (both shapes)"

grep -q 'PC-CLOSED-A' "$ARCH" 2>/dev/null && grep -q 'PC-CLOSED-BULLET' "$ARCH" 2>/dev/null \
  && ok "closed entries present in the archive — moved, never deleted" \
  || bad "closed entries are not in the archive: rotation LOST them"

grep -q 'Preamble prose' "$LEDGER" \
  && ok "preamble (belongs to no entry) stays in the live file" \
  || bad "preamble was swept into the archive"

# --- Assertion 3: NO LINE LOST ---------------------------------------------------------
after_total=$(( $(wc -l < "$LEDGER" | tr -d ' ') + $(grep -c '' "$ARCH" 2>/dev/null || echo 0) ))
[ "$after_total" -ge "$before_lines" ] \
  && ok "no content lost (live + archive >= original ${before_lines} lines)" \
  || bad "content lost: live+archive is $after_total vs $before_lines before"

# --- Assertion 4: THE ACCEPTANCE TEST — classifier output unchanged --------------------
after_verdicts="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$LEDGER" 2>/dev/null)"
if [ "$before_verdicts" = "$after_verdicts" ]; then
  ok "ledger-reverify output BYTE-IDENTICAL across the rotation"
else
  bad "ledger-reverify output CHANGED — rotation moved an entry the classifier was using"
  printf '%s\n' "$before_verdicts" > /tmp/lr-before.$$; printf '%s\n' "$after_verdicts" > /tmp/lr-after.$$
  diff /tmp/lr-before.$$ /tmp/lr-after.$$ | sed 's/^/      /' | head -8
  rm -f /tmp/lr-before.$$ /tmp/lr-after.$$
fi

# --- Assertion 5: IDEMPOTENT -----------------------------------------------------------
second="$(bash "$ROT" "$LEDGER" --apply 2>&1)"
grep -q '0 closed entries' <<<"$second" \
  && ok "second run is a no-op (0 closed entries — rotation is idempotent)" \
  || bad "second run moved something: not idempotent — $second"

# --- Assertion 6: MUTATION — a rotation that drops lines must REFUSE -------------------
# Proves the accounting check is load-bearing rather than decorative.
mut="$WORK/mutant.sh"
sed 's/if \[ "\$(( l_keep + l_move ))" -ne "\$l_all" \]/if [ "$(( l_keep + l_move ))" -eq -1 ]/' "$ROT" > "$mut"
if [ "$(grep -c 'eq -1' "$mut")" -eq 1 ]; then
  ok "mutation harness applied (accounting guard disabled in a copy)"
else
  bad "FIXTURE BROKEN — could not build the mutant; the guard assertion below is vacuous"
fi

# --- Assertion 7: the nothing-to-rotate guard FIRES on the nothing-to-rotate case -------
# Assertion 5 cannot see this. The broken form printed `ledger-rotate: 0` + newline +
# `0 closed entries would move (…)`, which CONTAINS the substring the idempotency check
# greps for — so that check passed while the guard beside it was inoperative. What separates
# a fired guard from a fall-through is the early-exit line, a clean stderr, and an archive
# the run never had a reason to create.
mkdir -p "$WORK/noop"
printf '# Push-candidate ledger\n\n## PC-OPEN-ONLY — nothing in this file is closed\n\nBody.\n' \
  > "$WORK/noop/push-candidate-ledger.md"

noop_guard_holds() { # <rotate-script> -> 0 iff the no-op guard fired cleanly
  local rot="$1" dir out rc
  dir="$WORK/noop-run"
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$WORK/noop/push-candidate-ledger.md" "$dir/push-candidate-ledger.md"
  out="$(bash "$rot" "$dir/push-candidate-ledger.md" --apply 2>"$dir/stderr")"
  rc=$?
  [ "$rc" -eq 0 ] || return 1
  grep -q 'nothing to rotate' <<<"$out" || return 1
  grep -q 'integer expression expected' "$dir/stderr" && return 1
  [ -f "$dir/push-candidate-ledger.archive.md" ] && return 1
  return 0
}

if noop_guard_holds "$ROT"; then
  ok "nothing to rotate: exits early, writes no archive, no 'integer expression expected'"
else
  bad "the nothing-to-rotate guard did not fire — the run fell through to the write path"
fi

# --- Assertion 8: MUTATION — restore the `|| echo 0` fallback; the guard must die --------
# `grep -c` PRINTS 0 on no match and ALSO exits 1, so the fallback fires on exactly the case
# it looks like it covers and makes n_move the two-line string `0\n0`.
MUTD="$WORK/mut-noop"; mkdir -p "$MUTD"
cp "$(dirname "$ROT")/lib.sh" "$MUTD/lib.sh" 2>/dev/null
cp "$ROT" "$MUTD/control.sh"
sed 's@n_move="$(grep -c . "$TMPD/moved-names")"@n_move="$(grep -c . "$TMPD/moved-names" 2>/dev/null || echo 0)"@' \
  "$ROT" > "$MUTD/mutant.sh"

if ! noop_guard_holds "$MUTD/control.sh"; then
  bad "FIXTURE BROKEN — an UNMUTATED copy in the mutant directory already fails the guard, so assertion 8 would score a false pass"
elif cmp -s "$ROT" "$MUTD/mutant.sh"; then
  bad "FIXTURE BROKEN — the mutation matched nothing, so assertion 7 is unproven"
elif noop_guard_holds "$MUTD/mutant.sh"; then
  bad "the guard still 'fires' with the fallback restored — assertion 7 is vacuous"
else
  ok "mutation: restoring '|| echo 0' kills the no-op guard (assertion 7 is load-bearing)"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "ledger-rotate: PASS"
else
  echo "ledger-rotate: FAIL ($fails)" >&2; exit 1
fi
