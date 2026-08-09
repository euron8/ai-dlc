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
if [ "$before_entries" -eq 6 ] && grep -q 'PC-CLOSED-A' "$LEDGER" && grep -q 'PC-OPEN-DECOY' "$LEDGER"; then
  ok "before: 6 entries — closed + open + a decoy that only MENTIONS the phrase + one closed-but-unarchivable"
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

# --- THE ENTRIES NEITHER RULE TAKES ---------------------------------------------------
# READ AS HERE-STRINGS, NEVER `… | grep -q`. Under pipefail the reader leaves at its first
# match while the writer is still pushing, so the pipeline answers with the writer's EPIPE and
# reports 'not found' on output that contains the pattern -- a SIZE threshold, not a race, and
# silent once crossed. I54/I54b caught exactly that in the first draft of these three arms.
# reverify skips on `/ADOPTED UPSTREAM/` anywhere; this script archives only on the strict
# `**ADOPTED UPSTREAM (v`. The asymmetry is deliberate, and its stated cost was that a wrongly
# KEPT entry "costs one more pull to notice" — but nothing noticed, because nothing reported
# the gap. Measured on the reference consumer at 0.329.0: 8 such entries, while the same run
# printed "0 closed entries — nothing to rotate".
stuck_out="$(bash "$ROT" "$LEDGER" 2>&1)"
if grep -q 'CLOSED for re-verification but NOT archivable' <<<"$stuck_out"; then
  ok "an entry closed for re-verification but unarchivable is REPORTED, not silently kept"
else
  bad "a closed-but-unarchivable entry produced no row — it is invisible in every future report and never filed"
fi
if grep -q 'Entry STUCK' <<<"$stuck_out"; then
  ok "  and it is NAMED, so the operator can grep it back into the ledger"
else
  bad "  the count fired but the entry is not named — an unnamed count is not actionable"
fi

# THE CONTROL, and without it the two arms above pass on any script that prints the banner
# unconditionally. An archivable entry must NOT appear in the stuck list.
stuck_list="$(awk '/NOT archivable/{on=1;next} /^ledger-rotate:/{on=0} on' <<<"$stuck_out")"
if grep -q 'Entry B' <<<"$stuck_list"; then
  bad "  an ARCHIVABLE entry was reported as stuck — the two predicates are the same one"
else
  ok "  and an archivable entry is not in that list, so the row discriminates"
fi

# --- THE ENTRY THAT QUOTES THE RULE MUST NOT BE ARCHIVED BY IT (PC-S331) -------------------
#
# REPRODUCED ON THE REFERENCE CONSUMER BEFORE THIS EXISTED: `--apply` archived `PC-S330`, a LIVE
# push candidate, because its body quoted the annotation form this script matches on. The test is
# per-ENTRY over every buffered line, and a push candidate ABOUT this script naturally writes the
# form it describes — so the tool matched an entry against its own quotation of the tool.
#
# THE QUOTATION IS INLINE, NOT FENCED, and that is why this seeds both. The report said fenced;
# measured, a fence carrying the ESCAPED awk form does not match at all (`\*\*` is not `**`),
# while inline backticks and bare prose both do. A fence-skipping fix passes a fenced-only
# fixture and leaves the live defect untouched — so the fenced case is seeded as a CONTROL that
# must stay silent for its own reason, and the inline case is the subject.
#
# DEFECT 2 IS SEEDED TOO, and nobody reported it: `\(v` also matches `(verified`, so a close
# carrying NO VERSION satisfied a rule whose banner promises one. It must now be REFUSED and
# reported as stuck, which is the state v0.330.0 added the refusal list to make visible.
Q="$WORK/quoting-ledger.md"
cat > "$Q" <<'QLED'
# Push-candidate ledger

## PC-Q1 — genuinely closed, the positive control
**ADOPTED UPSTREAM (v0.200.0, verified 2026-07-21).** really closed.

## PC-Q2 — LIVE, quotes the strict form INLINE (the live defect)
Filed because rotate archives only on `**ADOPTED UPSTREAM (v` and reverify skips on the loose one.
STATUS: STILL-LIVE.

## PC-Q3 — LIVE, quotes the ESCAPED awk form in a fence (must be silent for its OWN reason)
```
/\*\*ADOPTED UPSTREAM \(v/ { closed = 1 }
```
STATUS: STILL-LIVE.

## PC-Q4 — closed with NO VERSION, which the rule is not entitled to archive
**ADOPTED UPSTREAM (verified 2026-07-21).** absorbed before base.
QLED
q_out="$(bash "$ROT" "$Q" --archive "$WORK/quoting-archive.md" 2>&1)"
q_moved="$(awk '/closed entries would move/{on=1;next} /^  archive:/{on=0} on' <<<"$q_out")"

if grep -q 'PC-Q1' <<<"$q_moved"; then
  ok "PRECONDITION: a genuine close still moves, so the silences below are a real discrimination"
else
  bad "PRECONDITION FAILED: the genuine close did not move, so every 'is not archived' assertion here passes vacuously ($(printf '%s' "$q_out" | head -1))"
fi
if grep -q 'PC-Q2' <<<"$q_moved"; then
  bad "a LIVE entry that quotes the strict annotation form INLINE was archived by it. That is PC-S331 verbatim: rotate matched the entry against its own quotation, and --apply deletes live work from the file the pull reads"
else
  ok "an entry quoting the strict form INLINE is NOT archived — the match requires a version DIGIT, which a quotation does not carry"
fi
if grep -q 'PC-Q3' <<<"$q_moved"; then
  bad "the fenced ESCAPED form was archived — that is a different match from the live one and means the predicate got looser, not tighter"
else
  ok "  and the fenced escaped form stays too (it never matched: the escaped form is not the literal)"
fi
if grep -q 'PC-Q4' <<<"$q_moved"; then
  bad "a close carrying NO VERSION was archived. The banner promises the version immediately after the parenthesis, and \`\\(v\` matching \`(verified\` is how that promise was unenforced"
else
  ok "a versionless close is REFUSED rather than archived — the rule now enforces the form its own banner states"
fi
q_stuck="$(awk '/NOT archivable/{on=1;next} /^ledger-rotate:/{on=0} on' <<<"$q_out")"
if grep -q 'PC-Q4' <<<"$q_stuck"; then
  ok "  and it is REPORTED as stuck, so refusing it does not make it invisible"
else
  bad "  the versionless close was refused and NOT reported — refused-and-silent is the exact state v0.330.0 exists to end"
fi

# MUTATION — restore the un-anchored pattern. PC-Q2 must come back, and PC-Q1 must not move,
# or the mutant is testing whether the arm RUNS rather than what it matches.
MUTQ="$WORK/rot-mutant"; rm -rf "$MUTQ"; mkdir -p "$MUTQ"
cp "$(dirname "$ROT")"/* "$MUTQ"/ 2>/dev/null
sed 's/ADOPTED UPSTREAM \\(v\[0-9\]/ADOPTED UPSTREAM \\(v/' "$ROT" > "$MUTQ/ledger-rotate.sh"
if cmp -s "$ROT" "$MUTQ/ledger-rotate.sh"; then
  bad "  FIXTURE ERROR: the digit-anchor mutation matched nothing, so the assertions above are unproven"
else
  m_out="$(bash "$MUTQ/ledger-rotate.sh" "$Q" --archive "$WORK/mut-archive.md" 2>&1)"
  m_moved="$(awk '/closed entries would move/{on=1;next} /^  archive:/{on=0} on' <<<"$m_out")"
  if ! grep -q 'PC-Q1' <<<"$m_moved"; then
    bad "  MUTATION: the unmutated-control entry stopped moving under the mutant, so the copy is broken and its verdict is not attributable"
  elif grep -q 'PC-Q2' <<<"$m_moved"; then
    ok "  MUTATION: without the version digit the quoting entry is archived again — the anchor is what stands between a live entry and the archive"
  else
    bad "  MUTATION: removing the digit anchor did NOT re-archive the quoting entry, so these assertions are not measuring the anchor"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "ledger-rotate: PASS"
else
  echo "ledger-rotate: FAIL ($fails)" >&2; exit 1
fi
