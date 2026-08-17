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

# SPLIT BY SHAPE, DELIBERATELY. These were one assertion naming both ids, and a conflated arm
# catches a dead bullet arm without ATTRIBUTING it: the failure message says "closed entries"
# and the operator cannot tell which of the two shapes stopped being a boundary. The mutant at
# the foot of this file kills exactly one of these two, which is what makes it readable.
if grep -q 'PC-CLOSED-A' "$ARCH" 2>/dev/null; then
  ok "closed HEADING entry present in the archive — moved, never deleted"
else
  bad "the closed HEADING entry is not in the archive: rotation LOST it"
fi
if grep -q 'PC-CLOSED-BULLET' "$ARCH" 2>/dev/null; then
  ok "closed BULLET entry present in the archive — the bullet arm of ledger_entry_shape() is live"
else
  bad "the closed BULLET entry is not in the archive: rotation LOST it, or the bullet arm stopped opening entries"
fi

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

# --- THE REFUSE-TO-ROTATE GUARD (BL-032) -------------------------------------------------
#
# THE DEFECT. `ledger_entry_shape()` opens an entry on ANY line-leading `- **`, so an
# ANNOTATION in that shape inside a CLOSED entry ends it: the head is archived and the tail,
# including the entry's `verify:` receipt, is stranded in the live ledger under no heading.
# Nothing in the rotator could see it — the `kept + moved != total` arm is LINE accounting and
# a split conserves every line, the two halves simply land on opposite sides.
#
# THE FALSE-POSITIVE ARMS BELOW MATTER MORE THAN THE POSITIVE ONE, and that is not a slogan
# here. A refusal is the whole of this guard's behaviour, so a guard that refuses too much
# wedges every rotation of a ledger it misreads, and the operator turns it off. The class it
# has to stay silent on is named in `docs/analysis/ledger-entry-boundary-measurement.md`: 49
# of the reference consumer's 123 boundary-matching lines name no `PC-` id and SOME OF THEM
# ARE REAL ENTRIES in an older id-less format. A rule that cannot tell those from annotations
# does not get to refuse on their account.
#
# EVERY LEDGER BELOW IS BUILT FROM THE SAME CLOSED PREAMBLE so the arms differ in exactly the
# line under test, and the differential is asserted rather than assumed.
RG="$WORK/refuse"; rm -rf "$RG"; mkdir -p "$RG"
rg_closed='# Push-candidate ledger

- **PC-CLOSED-ABOVE** — a genuinely closed entry, which is what makes the line below a suspect

  <br>**ADOPTED UPSTREAM (v0.100.0, verified 2026-01-01).** Upstream took it.

'
rg_write() { printf '%s%s' "$rg_closed" "$2" > "$RG/$1.md"; }

# 0 iff the rotator REFUSED (non-zero exit AND the refusal banner). Both halves, because a
# rotator that died sourcing lib.sh also exits non-zero and would score as a refusal.
rg_refused() {
  local out rc
  out="$(bash "$ROT" "$RG/$1.md" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || return 1
  grep -q 'REFUSING to rotate' <<<"$out" || return 1
  return 0
}

# THE SUBJECT: an annotation lead-in inside the closed entry, with the entry's receipt below it.
rg_write splitter '- **Note:** an annotation lead-in, written the way an operator writes one

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
# THE NEAR MISS: byte-identical but for the indentation that stops it being a boundary.
rg_write nearmiss '  - **Note:** an annotation lead-in, written the way an operator writes one

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
if cmp -s "$RG/splitter.md" "$RG/nearmiss.md"; then
  bad "FIXTURE BROKEN — the splitter and its near miss are byte-identical, so the pair below discriminates nothing"
else
  ok "the splitter and its near miss differ only in one bullet's indentation (asserted byte-different)"
fi

if rg_refused splitter; then
  ok "REFUSES a ledger whose boundary rule would split a closed entry, rather than stranding its receipt"
else
  bad "rotated a ledger that splits a closed entry — the head goes to the archive and the receipt is stranded in the live file under no heading, which is irreversible"
fi

if rg_refused nearmiss; then
  bad "refused the INDENTED near miss, which is not a boundary at all — the guard is keyed on the bold, not on the split"
else
  ok "  and stays silent when the same bullet is indented, so the refusal is keyed on the boundary and not on the bold"
fi

# THE SUSPECT WITH NOTHING TO STRAND. No receipt below it and no colon: nothing can be lost,
# so refusing would be a refusal with no damage behind it.
rg_write noreceipt '- **Note** an annotation lead-in with no receipt anywhere below it
'
if rg_refused noreceipt; then
  bad "refused a boundary with no receipt below it — nothing could have been stranded, so this refusal has no damage behind it"
else
  ok "  and stays silent when no receipt follows: the predicate is the DAMAGE, not the shape"
fi

# --- THE FALSE-POSITIVE SET: REAL ENTRIES THAT MUST STILL ROTATE --------------------------
# Each of these is a REAL entry that legitimately follows a closed one. `ledger-rotate` sees a
# pre-rotation ledger, where closed and open entries are interleaved by construction — the
# whole reason it is being run — so "a real entry directly below a closed one" is the ordinary
# case and not an edge one. The reference consumer's LIVE ledger reports 0 suspects only
# because it has already been rotated; its ARCHIVE holds 22 boundary-shaped lines inside closed
# entries, and all 22 escape refusal on ONE clause (a later close annotation of their own).
fp_check() { # <name> <tier> <why>
  if rg_refused "$1"; then
    bad "$2 — the guard REFUSES here: $3"
  else
    ok "$3"
  fi
}

# (1) A prose-titled entry whose own close carries no version. The seed above already holds
# this adjacency for `Entry STUCK`, which is where an earlier cut of the guard was caught.
rg_write fp-versionless '- **Entry STUCK is closed for re-verification and unarchivable.** a real entry

  <br>**ADOPTED UPSTREAM (absorbed before base abc1234, verified 2026-01-01).**

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
fp_check fp-versionless "SUBJECT DEFECT" "a real prose-titled entry with a VERSIONLESS close still rotates — the close test that archives is strict, the one that clears a suspect is not"

# (2) THIS ONE IS NOT A FALSE POSITIVE, AND THE ARM REQUIRES THE REFUSAL. Read the reasoning
# before "fixing" it into silence, because the arm looks exactly like the four around it and
# asserts the opposite.
#
# A prose-titled line that is still OPEN, directly below a closed entry, carrying a receipt, is
# the one shape NOTHING can classify. If it is a real entry, nothing is stranded and the
# refusal cost an operator two lines. If it is an annotation, the closed entry`s tail — its
# receipt included — is destroyed, and destroyed is not a state you recover by re-running.
# `docs/analysis/ledger-entry-boundary-measurement.md` IS the finding that no rule separates
# the two: an annotation lead-in and an entry title are byte-indistinguishable.
#
# THE TWO OUTCOMES ARE NOT SYMMETRIC, which is the whole of the argument. A wrong refusal is a
# two-line edit; a wrong rotation is an entry. `scripts/backlog-rotate.sh:101-109` already
# argues this stance for the fence case in this repo`s own tool, and the analysis file closes
# on "the guard belongs in the tool".
#
# AND IT WEDGES NOTHING THAT EXISTS. Measured with the shipping script against copies of all
# four real corpora — the consumer live ledger, the consumer archive, `docs/backlog.md` and
# `docs/backlog.archive.md` — the guard reports ZERO findings. This case arises only in
# constructed input like the ledger below. The arm two further down proves the refusal is
# ESCAPABLE, which is what makes requiring it legitimate rather than a dead end.
rg_write fp-open '- **A real prose-titled entry that is still OPEN** and carries its own receipt

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
if rg_refused fp-open; then
  ok "REFUSES an OPEN prose-titled entry below a closed one — INTENDED: nothing can tell that line from an annotation, and the two errors cost a two-line edit vs a destroyed entry"
else
  bad "the guard rotated a ledger whose boundary line is unclassifiable. If this was a deliberate narrowing, the asymmetry above says why it is the wrong direction: the silent outcome here is a closed entry losing its tail"
fi

# (3) The legacy id-less format the analysis file names by example, whose close sits INSIDE its
# own bold span rather than on a line below it.
rg_write fp-legacy '- **`validate-ci-gates.sh` → ADOPTED UPSTREAM (v0.135.0).** the legacy id-less shape

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
fp_check fp-legacy "SUBJECT DEFECT" "a legacy id-less entry whose close sits in its OWN bold span still rotates — a close on the boundary line is still a close"

# (4) The closed entry's receipt sits ABOVE the offending line, so the split strands nothing.
# `ledger-reverify.sh`'s conjunction has exactly this clause (`!prev_id_hadv`); this one does
# not, and the two tools are supposed to share one account of the harm.
printf '%s' '# Push-candidate ledger

- **PC-CLOSED-ABOVE** — closed, and its OWN receipt sits above the boundary below

  verify: theirs_has core/scripts/thing.sh "MARKER_A"

  <br>**ADOPTED UPSTREAM (v0.100.0, verified 2026-01-01).** Upstream took it.

- **A real prose-titled entry with its own receipt** below a closed entry that kept its own

  verify: theirs_has core/scripts/thing.sh "MARKER_B"
' > "$RG/fp-receipt-above.md"
fp_check fp-receipt-above "SUBJECT DEFECT" "a closed entry that carries its OWN receipt above the boundary still rotates — nothing can be stranded, so there is no damage to refuse on"

# (5) An entry that merely QUOTES the annotation form. The strict close test already refuses to
# archive on a quotation (PC-S331 above); the refusal guard must not read one as a close either.
rg_write fp-quotes '- **A real entry that QUOTES the annotation form** in its own body

  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero.

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
fp_check fp-quotes "SUBJECT DEFECT" "an entry that merely QUOTES the annotation form still rotates"

# THE EXIT CONDITION. A refusal is only legitimate if it can be SATISFIED, and the guard's own
# remedy line offers exactly one way out — re-indent the annotation or drop its bold — which is
# destructive advice when the line is in fact a real entry. This is the second way out, and it
# is the one that works for both readings: give the line an id and the boundary stops being
# ambiguous. Asserting the entry condition alone would leave a standard nobody can meet.
rg_write fp-given-an-id '- **PC-GIVEN-AN-ID** — the same line as fp-open, given an id so the boundary is unambiguous

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
if cmp -s "$RG/fp-open.md" "$RG/fp-given-an-id.md"; then
  bad "FIXTURE BROKEN — the id-bearing form is byte-identical to fp-open, so this arm discriminates nothing"
elif rg_refused fp-given-an-id; then
  bad "SUBJECT DEFECT — the refusal has NO exit: giving the line an id, the one remedy that is correct whichever reading is right, does not satisfy the guard"
else
  ok "  and giving that line an id SATISFIES the guard — the refusal is escapable without editing a real entry's shape"
fi

# ...AND THE REFUSAL HAS TO SAY SO. The exit above exists but the message does not name it: it
# offers only "re-indent the annotation, or drop its bold", both of which are corrections to an
# ANNOTATION. An operator whose line is a real entry is told to deform it, and the arm above is
# the proof that a correct remedy exists. A remedy line that names only one of two exits sends
# the operator down the destructive one whenever the guard's reading is the wrong one.
# THE JOIN IS TO THE ARM ABOVE, NOT TO THE PROSE. What must hold is that the remedy the
# fixture has just PROVEN works — give the line an entry id — is one the banner actually
# offers. Anchoring on the annotation half alone would pass a banner that names only the
# destructive exit, which is the state this arm was written for.
rg_msg="$(bash "$ROT" "$RG/fp-open.md" 2>&1)"
rg_msg_check() { # <text> -> 0 iff it carries the annotation remedy AND the entry-id exit
  grep -q 're-indent it so it does not start a line' <<<"$1" || return 2
  grep -q 'an entry id' <<<"$1" || return 1
  return 0
}
rg_msg_check "$rg_msg"; rg_msg_rc=$?
if [ "$rg_msg_rc" -eq 2 ]; then
  bad "FIXTURE BROKEN — the refusal banner did not carry its annotation remedy at all, so this arm asserts nothing about the message"
elif [ "$rg_msg_rc" -eq 0 ]; then
  ok "  the refusal names BOTH exits — re-indent the annotation, or give a real entry its own id"
else
  bad "SUBJECT DEFECT — the refusal names only the annotation remedy. When the line is a real entry that advice destroys it, and the exit the arm above proves works is not offered"
fi

# MUTATION — strip the entry-id sentence from the banner. An arm that greps a message is one
# `sed` away from being satisfied by any wording at all, so it needs a mutant like every other
# absence-shaped assertion here. The annotation half must survive, or the mutant deleted the
# whole banner and the kill is not attributable to the exit it removed.
MUTM="$WORK/rot-msg-mutant"; rm -rf "$MUTM"; mkdir -p "$MUTM"
cp "$(dirname "$ROT")"/*.sh "$MUTM"/ 2>/dev/null
sed 's@annotation, or an entry id, so the two stop being indistinguishable@annotation so the two stop being indistinguishable@' \
  "$ROT" > "$MUTM/ledger-rotate.sh"
if cmp -s "$ROT" "$MUTM/ledger-rotate.sh"; then
  bad "  FIXTURE BROKEN — the banner mutation matched nothing, so the message arm above is unproven"
else
  mm_out="$(bash "$MUTM/ledger-rotate.sh" "$RG/fp-open.md" 2>&1)"
  rg_msg_check "$mm_out"; mm_rc=$?
  if [ "$mm_rc" -eq 2 ]; then
    bad "  MUTATION: the mutant lost the annotation remedy too, so it is not a clean removal of the entry-id exit alone"
  elif [ "$mm_rc" -eq 1 ]; then
    ok "  MUTATION: with the entry-id exit deleted the arm above fires — it is bound to the remedy, not to the banner existing"
  else
    bad "  MUTATION: deleting the entry-id exit did NOT trip the arm above, so that arm is satisfied by any wording"
  fi
fi

# --- MUTATION: DELETE THE REFUSAL, and the subject must rotate again ----------------------
# An ABSENCE-shaped arm — "these ledgers are NOT refused" — is the shape that requires a
# mutant. Five of the seven assertions above are absences, and against a rotator whose guard
# emits nothing every one of them passes. The mutant makes the guard find nothing at all
# rather than widening it, because a widened guard produces the same refusal text and would
# score a kill it did not earn.
MUTR="$WORK/rot-refuse-mutant"; rm -rf "$MUTR"; mkdir -p "$MUTR"
cp "$(dirname "$ROT")"/*.sh "$MUTR"/ 2>/dev/null
sed 's@^if \[ -n "\$SPLIT_FINDINGS" \]; then@if [ -n "" ]; then@' "$ROT" > "$MUTR/ledger-rotate.sh"
if cmp -s "$ROT" "$MUTR/ledger-rotate.sh"; then
  bad "FIXTURE BROKEN — the refusal mutation matched nothing, so every 'is NOT refused' assertion above is unproven"
else
  m_out="$(bash "$MUTR/ledger-rotate.sh" "$RG/splitter.md" 2>&1)"; m_rc=$?
  # THE CONTROL: the mutant must still be a working rotator. A copy that dies sourcing lib.sh
  # also stops refusing, and "no refusal" would then score as a kill of a guard that never ran.
  if [ "$m_rc" -ne 0 ] || ! grep -q 'closed entries would move' <<<"$m_out"; then
    bad "  MUTATION: the mutated copy is not a working rotator (rc=$m_rc), so its silence is not attributable to the guard"
  elif grep -q 'REFUSING to rotate' <<<"$m_out"; then
    bad "  MUTATION: the guard still refused with SPLIT_FINDINGS emptied — the refusal assertion is measuring something else"
  else
    ok "  MUTATION: with the refusal removed the splitter rotates again, so the arms above are load-bearing"
  fi
fi

# THE UNMUTATED CONTROL from the same directory, for the same reason as the mutant's own.
CTLR="$WORK/rot-refuse-control"; rm -rf "$CTLR"; mkdir -p "$CTLR"
cp "$(dirname "$ROT")"/*.sh "$CTLR"/ 2>/dev/null
c_out="$(bash "$CTLR/ledger-rotate.sh" "$RG/splitter.md" 2>&1)"
if grep -q 'REFUSING to rotate' <<<"$c_out"; then
  ok "  unmutated copy in the same directory still refuses (the mutant above ran a sound harness)"
else
  bad "  unmutated copy stopped refusing — a copy that cannot run scores as a kill for every arm here"
fi

# --- MUTATION: DELETE THE BULLET ARM OF ledger_entry_shape() -------------------------------
# `if (0) return "bullet"` is the remedy `docs/analysis/ledger-entry-boundary-measurement.md`
# rules out as WORSE THAN THE DEFECT — it makes the rotator stop seeing every bulleted entry,
# which is silent non-archival rather than a visible refusal. It was measured to satisfy an
# earlier form of BL-032's receipt, i.e. a FALSE CLOSE for a destructive change.
#
# IT IS NOT AN UNCAUGHT MUTANT — MEASURED, IT TRIPS 8 ASSERTIONS HERE AND 47 IN
# `ledger-reverify` — AND THAT IS THE PROBLEM IT HAS. A mutant that fails forty-seven
# assertions establishes that the fixture notices a catastrophically broken parser and nothing
# narrower; `fixture-mutants.md` calls that entanglement, and every one of those failures reads
# as a different regression. This arm exists to make ONE assertion own the case: a closed
# BULLET entry stops reaching the archive while a closed HEADING entry still does.
#
# THE BULLET SITS IN THE PREAMBLE, AND THE FIRST DRAFT OF THIS LEDGER GOT IT WRONG IN A WAY
# THAT SCORED NO KILL. With the bullet arm dead the bullet stops being a boundary and its text
# joins whatever entry contains it — INCLUDING its own `ADOPTED UPSTREAM` line, which then
# closes that entry. Put the bullet after an OPEN heading and the absorbed annotation closes
# the open entry, the whole block archives, and the arm reports the id present in the archive:
# a surviving mutant that is really a bad seed. Measured, not reasoned — the first cut of this
# arm did exactly that.
#
# So the bullet goes BEFORE the first heading. Everything above the first boundary is the
# file's preamble and always stays in the live file, so under the mutant the closed bullet is
# stranded there — never archived, never reported — which is the actual defect the deleted arm
# produces. The closed heading below it is untouched by the mutation and is the control.
BM="$WORK/bullet-arm"; rm -rf "$BM"; mkdir -p "$BM"
cat > "$BM/led.md" <<'BMLED'
# Push-candidate ledger

- **PC-BM-CLOSED-BULLET** — closed, bullet shape, the subject

  <br>**ADOPTED UPSTREAM (v0.101.0, verified 2026-01-01).** Upstream took it.

## PC-BM-CLOSED-HEADING — closed, heading shape, the shape the mutation does NOT touch

<br>**ADOPTED UPSTREAM (v0.100.0, verified 2026-01-01).** Upstream took it.
BMLED

cp "$(dirname "$ROT")"/*.sh "$BM"/ 2>/dev/null
sed 's@if (l ~ /\^- \\\*\\\*/) *return "bullet"@if (0)      return "bullet"@' \
  "$(dirname "$ROT")/lib.sh" > "$BM/lib.sh"

bm_archived() { # <dir> <id> -> 0 iff that id reaches the archive
  local d="$1" id="$2"
  rm -f "$d/arc.md"
  cp "$BM/led.md" "$d/run.md"
  bash "$d/ledger-rotate.sh" "$d/run.md" --archive "$d/arc.md" --apply >/dev/null 2>&1
  grep -q "$id" "$d/arc.md" 2>/dev/null
}

BMC="$WORK/bullet-arm-control"; rm -rf "$BMC"; mkdir -p "$BMC"
cp "$(dirname "$ROT")"/*.sh "$BMC"/ 2>/dev/null

if cmp -s "$(dirname "$ROT")/lib.sh" "$BM/lib.sh"; then
  bad "FIXTURE BROKEN — the bullet-arm mutation matched nothing in lib.sh, so the shape arms above are unproven"
elif ! bm_archived "$BMC" PC-BM-CLOSED-BULLET || ! bm_archived "$BMC" PC-BM-CLOSED-HEADING; then
  bad "FIXTURE BROKEN — an UNMUTATED copy did not archive both shapes, so the mutant's verdict is not attributable"
elif bm_archived "$BM" PC-BM-CLOSED-BULLET; then
  bad "  MUTATION: the closed BULLET entry still reached the archive with the bullet arm deleted — the shape arm above is vacuous"
elif ! bm_archived "$BM" PC-BM-CLOSED-HEADING; then
  bad "  MUTATION: the closed HEADING entry ALSO stopped being archived, so the mutant broke the parser outright and the kill is not attributable to the bullet arm"
else
  ok "  MUTATION: deleting the bullet arm strands the closed BULLET entry in the live file while the HEADING entry still archives — one assertion, one shape"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "ledger-rotate: PASS"
else
  echo "ledger-rotate: FAIL ($fails)" >&2; exit 1
fi
