#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# ledger-rotate/run.sh — prove rotation removes CLOSED entries, keeps OPEN ones, loses
# nothing, and does not change what the classifier says about the work still open.
#
# THE ACCEPTANCE TEST IS THE ROW SET, NOT THE BYTES, and `ledger-rotate.sh`'s own header states
# the same projection rather than a second one: ledger-reverify.sh must emit the SAME ROW SET, by
# STATUS and SUBJECT, before and after. Rotation moves exactly the entries reverify already
# skips, so a row that appears or disappears means the split took a live entry — the only
# failure mode that actually costs anything.
#
# THE ROW SET IS THE PROJECTION, AND THE BYTES HOLD TOO, BECAUSE REVERIFY READS NO HISTORY.
# ledger-reverify.sh reads the OPEN entries of the live ledger and nothing else: it never opens
# the rotation archive, and a closed entry emits no row and is counted nowhere. A bare sprint
# prefix gets one NAMED-UPSTREAM-AMBIGUOUS row attributed to no entry, whatever the count, and
# the "N entries in this ledger carry it" number in its detail is over open live entries. Rotation
# moves only closed entries, so it can move neither the row nor its bytes. That is the operator's
# rule: a reader's rows must be the same with all sprint history deleted.
#
# IT USED TO READ THE ARCHIVE, AND THE CROSSING WAS REAL. The count ran over open entries unioned
# with archived labels, and a count of ONE handed the row to a prefix fallback in
# `named_absorbed()` as a single attribution. An entry annotated in the same pass sat on neither
# side until the move landed, so the count dipped at the annotate and returned at the rotate,
# and on a two-member prefix the survivor's row FLIPPED between `NAMED-UPSTREAM <slug>` and
# `NAMED-UPSTREAM-AMBIGUOUS <prefix>`. Assertion 4 asserts the row set and the open-live count on
# the three-member trio, 4b proves the comparison still FAILS on a genuine sweep, 4c walks the
# two-member pair through annotate and rotate.
#
# THE OLD ARM COULD NOT FAIL ON THIS, AND ITS SUBJECT WAS UNCONSTRUCTIBLE RATHER THAN UNSEEDED.
# seed.sh once carried no `PC-S[0-9]+` id at all, so no NAMED-UPSTREAM-AMBIGUOUS row could be
# produced no matter what the code under test did, and the assertion would have stayed green
# through any rewrite of the invariant it existed to guard. The PC-S900 trio in seed.sh is what
# gives it one.
#
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
printf 'HERMETIC-CONSUMED %s\n' "$ROT"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
entries() { grep -cE '^(## |- \*\*)' "$1" 2>/dev/null || echo 0; }

# THE CLOSE VOCABULARY, DERIVED FROM ITS SINGLE HOME AND NEVER SPELLED HERE.
#
# A FIXTURE THAT HAND-LISTS THE TOKEN SET IS THE SUBJECT'S OWN DEFECT, ONE LEVEL UP. The thing
# under test is that `ledger-rotate.sh` stopped keeping a membership opinion of its own and now
# DERIVES rotation's grammar from `ledger-reverify.sh`'s close rule. A seed that writes
# `WITHDRAWN` into a heredoc is a third copy of that list: the day a fourth token is added to
# the single home, this fixture's seed still carries three and the arm proving the two lists
# agree goes quiet about exactly the token that was added. So the tokens come out of the rule
# `ledger_close_awk_pattern()` lifts, at run time, by the same structural grammar `lib.sh` uses
# -- a line-leading pattern rule setting `closed=1` and naming the anchor token -- and NOT by
# spelling the alternation.
#
# IT REFUSES RATHER THAN GUESSING. An empty answer here would make the arms that consume it
# seed entries closed by nothing and read as green, which is the shape of every defect this
# file guards. The caller asserts the two tokens are non-empty and DISTINCT before using them.
q_close_token() { # <n> -> the nth token of reverify's close alternation, on stdout
  LC_ALL=C awk -v want="$1" '
    /^[[:space:]]*\/.*ADOPTED UPSTREAM.*closed=1 \}$/ {
      line = $0
      # The alternation is the LAST parenthesised group before the closing slash.
      if (match(line, /\([^()]*ADOPTED UPSTREAM[^()]*\)\/ \{ closed=1 \}[[:space:]]*$/)) {
        grp = substr(line, RSTART + 1, RLENGTH - 1)
        sub(/\)\/ \{ closed=1 \}[[:space:]]*$/, "", grp)
        n = split(grp, tok, /\|/)
        if (want >= 1 && want <= n) { print tok[want]; found = 1 }
      }
      exit
    }
    END { if (!found) exit 1 }
  ' "$RV"
}

echo "ledger-rotate:"

before_lines="$(wc -l < "$LEDGER" | tr -d ' ')"
before_entries="$(entries "$LEDGER")"
before_verdicts="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$LEDGER" 2>/dev/null)"
# The PRE-ROTATION bytes, kept because assertion 4b needs a second, untouched copy of this
# ledger to rotate a different way. Taken before assertion 1 so a dry run that wrongly wrote
# cannot contaminate it.
ORIG="$WORK/ledger.orig.md"
cp "$LEDGER" "$ORIG"

# --- Assertion 0: SANITY — the seed really holds both kinds ---------------------------
# 11 boundary-SHAPED lines by the fence-blind grep above: 10 entries plus the heading-shaped
# line recorded inside PC-CLOSED-FENCED's fence, which is deliberately not an entry.
if [ "$before_entries" -eq 11 ] && grep -q 'PC-CLOSED-A' "$LEDGER" && grep -q 'PC-OPEN-DECOY' "$LEDGER" \
   && grep -q 'PC-S900-ALPHA' "$LEDGER" && grep -q 'PC-S900-BETA' "$LEDGER" && grep -q 'PC-S900-GAMMA' "$LEDGER" \
   && grep -q 'PC-CLOSED-FENCED' "$LEDGER"; then
  ok "before: 10 entries — closed + open + a decoy that only MENTIONS the phrase + one closed-but-unarchivable + a PC-S900 prefix trio + a closed entry whose fence records a heading-shaped line"
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
# and the operator cannot tell which of the two shapes stopped being a boundary.
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

# --- Assertion 2b: A CLOSED ENTRY WHOSE FENCE RECORDS A HEADING-SHAPED LINE ROTATES WHOLE ----
# PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS. The seed's PC-CLOSED-FENCED
# entry carries a `derived` fence whose recorded output is a `## <ts> -- EVENT` line. Under a
# fence-blind boundary rule that line opened an entry, the head stayed live with an unterminated
# fence and the tail archived under a timestamp label -- the reference consumer's live ledger
# holds exactly that residue from its 0.497.0 pull. The property is whole-entry movement AND
# fence balance on both sides.
# `grep -c` prints 0 AND exits 1 on no match, so `grep -c … || echo 0` prints two lines and the
# arithmetic below aborts the whole `if` with no verdict either way -- measured by the batch-50
# fixture hand on a green run. Capture first, default on failure.
fences() { local n; n="$(grep -cE '^[[:space:]]*```' "$1" 2>/dev/null)" || n=0; printf '%s\n' "${n:-0}"; }
if grep -q 'PC-CLOSED-FENCED' "$ARCH" 2>/dev/null && grep -q 'FENCED-EVENT' "$ARCH" 2>/dev/null \
   && ! grep -q 'PC-CLOSED-FENCED' "$LEDGER" && ! grep -q 'FENCED-EVENT' "$LEDGER"; then
  ok "a closed entry whose fence records a heading-shaped line moved WHOLE: heading and fenced line both in the archive, neither left live"
else
  bad "the fenced closed entry was SPLIT: archive has heading=$(grep -c 'PC-CLOSED-FENCED' "$ARCH" 2>/dev/null) fenced-line=$(grep -c 'FENCED-EVENT' "$ARCH" 2>/dev/null); live has heading=$(grep -c 'PC-CLOSED-FENCED' "$LEDGER") fenced-line=$(grep -c 'FENCED-EVENT' "$LEDGER")"
fi
fl="$(fences "$LEDGER")"; fa="$(fences "$ARCH")"
if [ $((fl % 2)) -eq 0 ] && [ $((fa % 2)) -eq 0 ] && [ "$fa" -ge 2 ]; then
  ok "  fence delimiters are balanced on both sides after the move (live=$fl archive=$fa, archive holds the moved fence)"
else
  bad "  fence delimiters unbalanced after the move (live=$fl archive=$fa) — a split left an unterminated fence on one side"
fi

# --- Assertion 3: NO LINE LOST ---------------------------------------------------------
after_total=$(( $(wc -l < "$LEDGER" | tr -d ' ') + $(grep -c '' "$ARCH" 2>/dev/null || echo 0) ))
[ "$after_total" -ge "$before_lines" ] \
  && ok "no content lost (live + archive >= original ${before_lines} lines)" \
  || bad "content lost: live+archive is $after_total vs $before_lines before"

# --- Assertion 4: THE ACCEPTANCE TEST — the ROW SET is unchanged ------------------------
#
# `emit()` in ledger-reverify.sh writes `<status>\t<subject>\t<detail>`. The projection this
# asserts over is the first two fields — what the classifier SAYS about which work — sorted,
# with multiplicity kept, so a swept entry cannot hide behind a duplicate. The DETAIL column is
# dropped deliberately: it carries an entry count, and a correct ANNOTATE moves that number (an
# annotated entry is no longer open). It is not a loosening, because every row this fixture
# cares about losing is identified by its status and subject; the bytes are asserted separately
# below, across the rotation alone, where nothing may move.
after_verdicts="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$LEDGER" 2>/dev/null)"
rowset() { cut -f1,2 | sort; }   # status + subject, multiplicity kept
before_rows="$(printf '%s\n' "$before_verdicts" | rowset)"
after_rows="$(printf '%s\n' "$after_verdicts" | rowset)"
n_rows="$(printf '%s\n' "$before_verdicts" | grep -c .)"
printf '%s\n' "$before_verdicts" > "$WORK/rv-before.txt"
printf '%s\n' "$after_verdicts"  > "$WORK/rv-after.txt"
n_linediff="$(diff "$WORK/rv-before.txt" "$WORK/rv-after.txt" | grep -c '^[<>]' || true)"

# THE POSITIVE CONTROL, AND WITHOUT IT THE ARM BELOW PASSES ON SILENCE. Two empty outputs are
# equal, so a ledger-reverify that emitted nothing at all — a broken copy, a wrong argument
# order, a parser that opened no entry — would score this as the strongest assertion here. The
# control names the AMBIGUOUS row specifically because that row is the one whose absence made
# the old byte assertion decorative, and a count of rows alone would not notice it missing.
if [ "$n_rows" -ge 7 ] && grep -q 'NAMED-UPSTREAM-AMBIGUOUS' <<<"$before_verdicts" \
   && grep -q 'PC-S900' <<<"$before_verdicts"; then
  ok "PRECONDITION: reverify emits ${n_rows} rows before the rotation, including the NAMED-UPSTREAM-AMBIGUOUS row for PC-S900 — so the comparisons below discriminate rather than compare two silences"
else
  bad "PRECONDITION FAILED: reverify emitted ${n_rows} rows and/or no NAMED-UPSTREAM-AMBIGUOUS row before the rotation, so every comparison below is between two silences and proves nothing"
fi

if [ "$before_rows" = "$after_rows" ]; then
  ok "ledger-reverify emits the SAME ROW SET across the rotation (by status and subject)"
else
  bad "ledger-reverify's ROW SET CHANGED — rotation moved an entry the classifier was using"
  diff <(printf '%s\n' "$before_rows") <(printf '%s\n' "$after_rows") | sed 's/^/      /' | head -8
fi

# ...AND THE BYTES ARE IDENTICAL TOO, BECAUSE NOTHING REVERIFY READS MOVES. This arm once asserted
# the opposite — that the bytes DIFFERED on a correct rotation, with the differing lines carrying
# a prefix count that rose 2 -> 3 — and that was a true description of a defect, not of the
# invariant: the count read open-live UNION archive, so the closed-but-unrotated GAMMA sat on
# neither side until the move landed. Reverify now reads no archive and counts open live entries
# only, so the rotation, which moves only closed entries, leaves every byte where it was.
#
# STILL PRESENCE-SHAPED: a report with no prefix count at all would satisfy "identical" on
# silence, so the count is read out and asserted at its value on BOTH sides.
if [ "$n_linediff" -eq 0 ]; then
  ok "  and the BYTES are identical across the move on all ${n_rows} rows — the entry count printed in the AMBIGUOUS detail is over open live entries, which a rotation does not move"
else
  bad "  the two outputs differ on ${n_linediff} of ${n_rows} lines with an identical row set, so a DETAIL moved across a rotation that moved nothing the classifier reads — ledger-reverify is reading a set that changes at the rotate (the archive, or closed entries)"
  diff "$WORK/rv-before.txt" "$WORK/rv-after.txt" | sed 's/^/      /' | head -6
fi

# THE NUMBER THAT USED TO MOVE, NAMED AT ITS VALUE. Asserting the specific 2 -> 2 rather than
# "nothing changed" ties the arm to the count being over the OPEN live members: ALPHA and BETA,
# never the closed GAMMA — not while it sits annotated in the live file, and not once it is
# archived. A count that took closed entries reads 3 on the left; one that read the archive reads
# 3 on the right; a stub returning a constant other than 2 reads differently on both.
pfx_n() { sed -n 's/.*and \([0-9][0-9]*\) entries in this ledger carry it.*/\1/p' <<<"$1"; }
b_n="$(pfx_n "$before_verdicts")"; a_n="$(pfx_n "$after_verdicts")"
if [ "$b_n" = "2" ] && [ "$a_n" = "2" ]; then
  ok "  and the PC-S900 prefix count holds 2 -> 2 across the move: the two OPEN members are counted, and the closed sibling is counted on neither side"
else
  bad "  the PC-S900 prefix count went '${b_n:-<none>}' -> '${a_n:-<none>}', expected 2 -> 2. A 3 on the left means a closed entry was counted; a 3 on the right means the archive was read"
fi

# --- Assertion 4c: THE ONE-VS-MANY CROSSING, WHICH THE PC-S900 TRIO CANNOT REACH ----------
#
# THE SEQUENCE HAS THREE STATES AND THE ACCEPTANCE TEST COMPARES THE LAST TWO. Annotate-then-
# rotate walks a ledger through (1) pre-annotation, (2) annotated but not yet rotated, and
# (3) rotated. `flush()` in ledger-reverify.sh prints a row only `if (has_verify && !closed …)`,
# so an entry annotated `**ADOPTED UPSTREAM (v…)**` leaves the open set at step 2 and reaches the
# archive at step 3. A count over open entries UNIONED with the archive therefore has the entry
# in NEITHER set between the two, so it DIPS at the annotate and RISES back at the rotate — and
# a count over the archive at all moves at the rotate. Reverify now counts open live entries
# only and gates nothing on the count, so neither step can move the row.
#
# THE PC-S900 TRIO ABOVE CANNOT SEE THAT, WHICH IS WHY THIS IS A SECOND SUBJECT AND NOT A
# SECOND ARM ON THE FIRST. PC-S900 keeps two open members, so under any count it stays above
# one: only the NUMBER inside the detail could move, and assertion 4 drops the detail column by
# design. PC-S910 has TWO members, one of them annotated, so a history-reading count runs 2 -> 1
# -> 2 and CROSSES one-vs-many. Wherever a count gates the row — the old prefix fallback, or a
# `> 1` gate on the AMBIGUOUS row — the row then changes STATUS OR SUBJECT between steps 2 and 3,
# which is exactly what assertion 4's projection KEEPS, and exactly what SKILL.md's acceptance
# test tells the operator means a live entry was swept.
#
# NOTHING IS SWEPT HERE, AND THE ARM ESTABLISHES THAT SEPARATELY RATHER THAN ASSUMING IT. The
# rotation control below requires the annotated sibling to have REACHED the archive and the
# survivor to still be IN the live ledger, so a row-set difference here cannot be explained by
# a lost entry.
#
# THE ARM IS WRITTEN AGAINST THE OBSERVABLE, NOT AGAINST ANY LINE OF THE COUNTER. What must hold
# is a property of the REPORT: the row set at step 2 and the row set at step 3 are the same, by
# status and subject. Any implementation whose row does not depend on the closed or archived
# members satisfies it, and no spelling of that fix is named in the assertion.
XC="$WORK/crossing"; rm -rf "$XC"; mkdir -p "$XC/led" "$XC/mled" "$XC/bin" "$XC/cbin"
TAB="$(printf '\t')"

# The two ledgers differ in ONE LINE -- the annotation -- and that is asserted below rather than
# eyeballed, because a differential whose sides do not differ reads as "no change".
xc_write() { # <path> <2 to annotate the sibling, anything else not to>
  cat > "$1" <<'XCL'
# Push-candidate ledger

## PC-S910-ALPHA — open throughout, and the SURVIVOR whose row flips

verify: theirs_has core/scripts/s910-landed.sh "s910"

## PC-S910-BETA — the sibling: open at state 1, annotated at state 2, archived at state 3

verify: theirs_has core/scripts/thing.sh "MARKER_B"
XCL
  [ "$2" = 2 ] || return 0
  cat > "$1" <<'XCL'
# Push-candidate ledger

## PC-S910-ALPHA — open throughout, and the SURVIVOR whose row flips

verify: theirs_has core/scripts/s910-landed.sh "s910"

## PC-S910-BETA — the sibling: open at state 1, annotated at state 2, archived at state 3

<br>**ADOPTED UPSTREAM (v0.90.0, verified 2026-01-01).** Upstream took it.

verify: theirs_has core/scripts/thing.sh "MARKER_B"
XCL
}

# READ INTO A VARIABLE, THEN PROJECT FROM A HERE-STRING. `bash "$RV" … | rowset` is safe today
# because `cut` drains its input, but the arms below also feed `grep -q`, and that is the
# first-match-EPIPE shape I54/I54b exists for.
xc_verdicts() { bash "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$2" 2>/dev/null; }

xc_walk() { # <reverify> <ledger-dir> -> writes v1/v2/v3 raw verdicts into that dir
  local rv="$1" d="$2" led="$2/push-candidate-ledger.md"
  rm -f "$d/push-candidate-ledger.archive.md"
  xc_write "$led" 1;  xc_verdicts "$rv" "$led" > "$d/v1"
  xc_write "$led" 2;  xc_verdicts "$rv" "$led" > "$d/v2"
  bash "$ROT" "$led" --apply >/dev/null 2>&1
  xc_verdicts "$rv" "$led" > "$d/v3"
}

xc_write "$XC/s1.md" 1
xc_write "$XC/s2.md" 2
if cmp -s "$XC/s1.md" "$XC/s2.md"; then
  bad "FIXTURE BROKEN — the annotated and unannotated ledgers are byte-identical, so states 2 and 3 are the same state and the arms below compare nothing"
else
  ok "the three-state seed differs in exactly the annotation line (asserted byte-different)"
fi

xc_walk "$RV" "$XC/led"
xc_v1="$(cat "$XC/led/v1")"; xc_v2="$(cat "$XC/led/v2")"; xc_v3="$(cat "$XC/led/v3")"
xc_r2="$(rowset <<<"$xc_v2")"; xc_r3="$(rowset <<<"$xc_v3")"

# REACHABILITY FIRST, AND IT IS PRESENCE-SHAPED. An arm that reads two row sets and finds no
# flip is indistinguishable from an arm whose seed could never emit the row at all -- that is
# the state PC-S334 records against the consumer's installed copy of this fixture. So the
# specific row must APPEAR at state 1 before anything below is read.
if grep -q "^NAMED-UPSTREAM-AMBIGUOUS${TAB}PC-S910${TAB}" <<<"$xc_v1" \
   && grep -q "^STILL-LIVE${TAB}PC-S910-ALPHA${TAB}" <<<"$xc_v1"; then
  ok "REACHABILITY: at state 1 the PC-S910 pair emits the NAMED-UPSTREAM-AMBIGUOUS row and the survivor's own STILL-LIVE row, so the crossing below has a subject"
else
  bad "FIXTURE BROKEN — state 1 emits no NAMED-UPSTREAM-AMBIGUOUS row for PC-S910, so this seed cannot express the crossing and every arm below passes on an absence"
fi

# THE ROTATION CONTROL, and it is what turns "the row set changed" into "the row set changed
# WITHOUT a sweep". Presence on both sides: the sibling reached the archive, the survivor is
# still in the live file, and the survivor is still being classified at BOTH states compared.
XCA="$XC/led/push-candidate-ledger.archive.md"
if ! grep -q 'PC-S910-BETA' "$XCA" 2>/dev/null; then
  bad "FIXTURE BROKEN — the annotated sibling did not reach the archive, so state 3 is not a rotated state and the comparison below is between two copies of state 2"
elif ! grep -q 'PC-S910-ALPHA' "$XC/led/push-candidate-ledger.md"; then
  bad "FIXTURE BROKEN — the SURVIVOR was rotated out, so this ledger really did lose a live entry and the arm below would be reporting a genuine sweep"
elif ! grep -q "^STILL-LIVE${TAB}PC-S910-ALPHA${TAB}" <<<"$xc_v2" \
   || ! grep -q "^STILL-LIVE${TAB}PC-S910-ALPHA${TAB}" <<<"$xc_v3"; then
  bad "FIXTURE BROKEN — the survivor stops being classified at one of the two states compared, so the difference below would be a sweep after all and this arm does not own the case"
else
  ok "  CONTROL: the annotated sibling is in the archive, the survivor is still in the live ledger, and reverify classifies the survivor at BOTH states — so any difference below is NOT a sweep"
fi

if [ "$xc_r2" = "$xc_r3" ]; then
  ok "ACCEPTANCE TEST HOLDS ACROSS THE CROSSING: annotate-then-rotate on a two-member sprint prefix leaves the ROW SET unchanged by status and subject"
else
  bad "ACCEPTANCE TEST FALSE-FAILS: rotating an annotated-but-unrotated sibling changed the ROW SET while nothing was swept. The prefix row depends on a count that moves at the rotate — closed or archived members are being read — so it crossed one-vs-many between the two states. An operator following SKILL.md reads this as a swept live entry and unwinds correct work"
  diff <(printf '%s\n' "$xc_r2") <(printf '%s\n' "$xc_r3") | sed 's/^/      /' | head -8
fi

# --- Assertion 5: IDEMPOTENT -----------------------------------------------------------
second="$(bash "$ROT" "$LEDGER" --apply 2>&1)"
grep -q '0 closed entries' <<<"$second" \
  && ok "second run is a no-op (0 closed entries — rotation is idempotent)" \
  || bad "second run moved something: not idempotent — $second"

# --- Assertion 7: the nothing-to-rotate guard FIRES on the nothing-to-rotate case -------
# Assertion 5 cannot see this. The broken form printed `ledger-rotate: 0` + newline +
# `0 closed entries would move (…)`, which CONTAINS the substring the idempotency check
# greps for — so that check passed while the guard beside it was inoperative. What separates
# a fired guard from a fall-through is the early-exit line, a clean stderr, and an archive
# the run never had a reason to create.
mkdir -p "$WORK/noop"
printf '# Push-candidate ledger\n\n## PC-OPEN-ONLY — nothing in this file is closed\n\nBody.\n' \
  > "$WORK/noop/push-candidate-ledger.md"

# noop_facts runs the rotator ONCE on the nothing-to-rotate ledger and sets four facts, each 1 when
# the guard's property HOLDS: NF_RC (exit 0), NF_MSG (early-exit line), NF_ERR (clean stderr), NF_ARCH
# (no archive created). noop_guard_holds is their conjunction.
noop_facts() { # <rotate-script>
  local rot="$1" dir out rc
  dir="$WORK/noop-run"
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$WORK/noop/push-candidate-ledger.md" "$dir/push-candidate-ledger.md"
  out="$(bash "$rot" "$dir/push-candidate-ledger.md" --apply 2>"$dir/stderr")"
  rc=$?
  NF_RC=0; NF_MSG=0; NF_ERR=1; NF_ARCH=1
  [ "$rc" -eq 0 ] && NF_RC=1
  grep -q 'nothing to rotate' <<<"$out" && NF_MSG=1
  grep -q 'integer expression expected' "$dir/stderr" && NF_ERR=0
  [ -f "$dir/push-candidate-ledger.archive.md" ] && NF_ARCH=0
  return 0
}
noop_guard_holds() { # <rotate-script> -> 0 iff the no-op guard fired cleanly
  noop_facts "$1"
  [ "$NF_RC$NF_MSG$NF_ERR$NF_ARCH" = 1111 ]
}

if noop_guard_holds "$ROT"; then
  ok "nothing to rotate: exits early, writes no archive, no 'integer expression expected'"
else
  bad "the nothing-to-rotate guard did not fire — the run fell through to the write path"
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
# unconditionally. An archivable entry must NOT appear in the stuck list, and neither must an
# OPEN one.
#
# THIS CONTROL WAS DECORATIVE FOR ITS WHOLE LIFE. It grepped the stuck list for `Entry B`, and
# `Entry B` appears nowhere in this fixture except in the assertion itself — measured, one hit
# across the directory, against `Entry STUCK` which is present in both seed.sh and run.sh. So it
# took its `else` branch on every run since it was written and would have reported a passing
# control against a rotator that named every entry in the ledger as stuck. It is replaced with
# the two ids the seed actually distinguishes.
stuck_list="$(awk '/NOT archivable/{on=1;next} /^ledger-rotate:/{on=0} on' <<<"$stuck_out")"
# The positive control comes FIRST: an empty stuck list satisfies both absences below, and an
# empty list is exactly what a rotator that stopped classifying produces.
if grep -q 'Entry STUCK' <<<"$stuck_list"; then
  ok "  the stuck list is non-empty and names the genuinely-stuck entry, so the two absences below are discriminations rather than an empty grep"
else
  bad "  the stuck list does not name the entry the seed built for it, so the absences below hold over an empty list and prove nothing"
fi
if grep -q 'PC-CLOSED-A' <<<"$stuck_list"; then
  bad "  an ARCHIVABLE entry was reported as stuck — the two predicates are the same one"
else
  ok "  and PC-CLOSED-A, which this same run reports as moving, is NOT in that list: archivable and stuck are different questions"
fi
if grep -q 'PC-OPEN-DECOY' <<<"$stuck_list"; then
  bad "  an OPEN entry that merely NARRATES the phrase was reported as closed-but-unarchivable — that is the unanchored body rule back, and it files live work as stuck"
else
  ok "  and the OPEN decoy is not in it either, so the stuck predicate is keyed on an annotation and not on the phrase appearing"
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
# THE VERSIONLESS CASE IS SEEDED AND ITS VERDICT IS THE OPPOSITE OF WHAT IT WAS. `\(v` also
# matched `(verified`, and the digit anchor added to close that turned a GENUINE close into a
# stuck row. A close that has no version -- a withdrawal, an absorption predating the pull`s
# base, a rejection adjudicated by date -- is a real close, and demanding a digit left the
# operator two exits: leave the entry live forever, or write a version that is not true. The
# derived grammar asks for the annotation FORM and says nothing about the parenthetical, so
# PC-Q4 now ARCHIVES. PC-Q5 below is what still lands in the stuck list, and it is a repairable
# annotation rather than a token this file never heard of.
#
# THE TOKEN SET IS NOT SPELLED HERE, IT IS DERIVED. PC-Q6 and PC-Q7 are built from the tokens
# `ledger-reverify.sh` actually honours, read out of the single home at run time, so a token
# added there arrives in this seed in the same edit. A hand-written list of tokens in a fixture
# is the same defect the subject under test just removed, one level up.
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

## PC-Q4 — closed with NO VERSION, a genuine close the rule must now archive
**ADOPTED UPSTREAM (verified 2026-07-21).** absorbed before base.

## PC-Q5 — closed with no BOLD SPAN at all: skipped by reverify, and not archivable
<br>ADOPTED UPSTREAM (v0.201.0, verified 2026-07-21). no bold anywhere on this line.

## PC-Q6 — LIVE, and its body NARRATES a close token at the start of a line
QLED
# THE NARRATIVE LINE CARRIES A REAL TOKEN AND NO BOLD SPAN, which is the whole discrimination:
# line-leading is not enough, the annotation form is. Built from the derived token set so a new
# token is narrated here too. `ledger-rotate.sh`'s header at :22 names this class by example.
q_tok1="$(q_close_token 1)"
q_tok2="$(q_close_token 2)"
{
  printf '%s in v0.135.0 is what the sentinel got, but this entry is still open.\n' "$q_tok1"
  printf 'STATUS: STILL-LIVE.\n\n'
  printf '## PC-Q7 — closed by the SECOND token reverify honours, which rotate must archive too\n'
  printf '**%s (v0.202.0, verified 2026-07-21).** closed by a token no literal in this file spells.\n' "$q_tok2"
} >> "$Q"
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
  ok "an entry quoting the strict form INLINE is NOT archived — the derived grammar is line-leading, and a quotation sits inside a sentence"
fi
if grep -q 'PC-Q3' <<<"$q_moved"; then
  bad "the fenced ESCAPED form was archived — that is a different match from the live one and means the predicate got looser, not tighter"
else
  ok "  and the fenced escaped form stays too (it never matched: the escaped form is not the literal)"
fi

# --- A VERSIONLESS CLOSE ARCHIVES ----------------------------------------------------------
# The inverse of what this arm asserted for its whole previous life, and the inversion is the
# point of the change it now covers. Read the block header before "fixing" this back.
if grep -q 'PC-Q4' <<<"$q_moved"; then
  ok "a close carrying NO VERSION is ARCHIVED — the grammar asks for the annotation FORM, so a withdrawal or a pre-base absorption closes on its own terms instead of living forever"
else
  bad "a versionless close was NOT archived. Demanding a digit leaves the operator two exits — leave the entry live forever, or write a version that is not true — and the entry is then skipped by every re-verification AND refused by every rotation"
fi

# --- WHAT IS STILL STUCK, AND IT IS REPAIRABLE ----------------------------------------------
# The two grammars differ by exactly one property, so exactly one class can still land here: a
# close written with NO BOLD SPAN. Asserting this is what says the stuck report did not retire
# with its largest class — a report that lost its subject reads identically to one whose corpus
# is clean.
q_stuck="$(awk '/NOT archivable/{on=1;next} /^ledger-rotate:/{on=0} on' <<<"$q_out")"
if grep -q 'PC-Q5' <<<"$q_stuck"; then
  ok "a close written with NO BOLD SPAN is reported as stuck — the one class the two grammars still separate, and the remedy the banner offers can actually be satisfied"
else
  bad "the no-bold close was neither archived nor reported — that is the invisible state the stuck list exists to end, surviving in the only shape that can still reach it"
fi
if grep -q 'PC-Q5' <<<"$q_moved"; then
  bad "  the no-bold close was ARCHIVED — the mandatory bold span is what separates an annotation from a mention, and without it a narrated token sweeps live work"
else
  ok "  and it is NOT archived: rotation is still the stricter of the two grammars"
fi
if grep -q 'PC-Q4' <<<"$q_stuck"; then
  bad "  the versionless close is ALSO in the stuck list while being archived — one entry cannot be both, so the two predicates disagree about it"
else
  ok "  and PC-Q4 is not in that list: archived and stuck stay disjoint"
fi

# --- AN INSTRUCTION OR NARRATIVE OCCURRENCE DOES NOT ARCHIVE AN OPEN ENTRY -------------------
# `ledger-rotate.sh`'s header at :22 states why this discrimination exists: the phrase occurs in
# open entries as instruction and as narrative, measured at 15 of 47 occurrences on the
# reference consumer. PC-Q2 covers the mid-line quotation; this covers the LINE-LEADING
# narrative, which is the harder half — line position alone does not separate it, only the bold
# span does.
if grep -q 'PC-Q6' <<<"$q_moved"; then
  bad "an OPEN entry whose body NARRATES a close token at the start of a line was archived — that is live work deleted from the file the pull reads, and the bold span is the only thing that separates the two"
else
  ok "an OPEN entry that NARRATES a close token line-leading is NOT archived — line position is not the discriminator, the annotation's bold span is"
fi

# --- A TOKEN REVERIFY HONOURS THAT ROTATE CANNOT ARCHIVE MUST BE IMPOSSIBLE ------------------
# THE DEFECT'S OWN SHAPE. `ledger-reverify.sh` honoured a SET; `ledger-rotate.sh` archived on one
# hand-written literal. An entry closed by a token rotate could not spell was SKIPPED by every
# re-verification AND REFUSED by every rotation at once — invisible in the report and permanently
# resident in the live ledger. This arm is keyed on the token set DERIVED from reverify's own
# rule, so it cannot go stale the way the literal did: the day a fourth token is added to the
# single home, this seed carries it and this arm decides whether rotation followed.
if [ -z "$q_tok2" ] || [ "$q_tok2" = "$q_tok1" ]; then
  bad "PRECONDITION FAILED: the derived close vocabulary yielded no distinct second token ('${q_tok1:-<none>}' / '${q_tok2:-<none>}'), so the arm below is about one token twice and cannot see the two lists diverging"
elif grep -q 'PC-Q7' <<<"$q_moved"; then
  ok "an entry closed by the SECOND token reverify honours is ARCHIVED — the close vocabulary is one grammar, and a token cannot reach one tool alone"
else
  bad "an entry closed by '${q_tok2}' — a token ledger-reverify.sh honours — was NOT archived. It is skipped by every re-verification and refused by every rotation at once: invisible in the report and permanently resident in the live ledger"
fi
if grep -q 'PC-Q7' <<<"$q_stuck"; then
  bad "  and it is in the STUCK list, which is the report of exactly that class — so the two lists have diverged again"
else
  ok "  and it is not in the stuck list either, which is the report that class used to be the whole of"
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
# has to stay silent on is named in `ledger-entry-boundary-measurement.md`: 49
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
# because it has already been rotated; its ARCHIVE holds 27 suspect boundary lines inside closed
# entries (distribution 0.674.0), and all 27 escape refusal on ONE clause (a close of their own).
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
# `ledger-entry-boundary-measurement.md` IS the finding that no rule separates
# the two: an annotation lead-in and an entry title are byte-indistinguishable.
#
# THE TWO OUTCOMES ARE NOT SYMMETRIC, which is the whole of the argument. A wrong refusal is a
# two-line edit; a wrong rotation is an entry. `scripts/backlog-rotate.sh:101-109` already
# argues this stance for the fence case in this repo`s own tool, and the analysis file closes
# on "the guard belongs in the tool".
#
# AND IT WEDGES NOTHING THAT EXISTS. Measured with the shipping script against copies of all
# four real corpora — the consumer live ledger, the consumer archive, and the distribution's own
# backlog and its archive — the guard reports ZERO findings. This case arises only in
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

# (5) THIS ONE IS NOT A FALSE POSITIVE EITHER, AND THE ARM REQUIRES THE REFUSAL, on fp-open`s
# rationale above. A colon-less line inside a closed entry, whose body only QUOTES the
# annotation form in backticks, carries no close of its own: a quotation is not a close. That
# leaves it exactly fp-open`s shape -- a prose-titled line with a receipt below it, which
# nothing can tell from an annotation lead-in -- and the same asymmetry decides it: a wrong
# refusal costs a two-line edit, a wrong rotation strands the closed entry`s receipt. The
# escape is the one the refusal text names: give the entry a close or an id. This arm used to
# require silence; the guard read the backticked quotation as a close, which is the defect.
rg_write fp-quotes '- **A real entry that QUOTES the annotation form** in its own body

  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero.

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
# THIS ARM SHIPS AHEAD OF THE ROTATOR IT GUARDS, as the BL-071 block below does, and is gated on
# the same key: the loose suppressor reading the line with its inline code removed. A consumer
# whose installed rotator predates that SKIPS it; in the distribution a missing key is a failure,
# because a key that matches nothing would otherwise skip these arms on every consumer forever.
case "$ROT" in */core/skills/ai-dlc-update/reconcile/ledger-rotate.sh) C71_ISDIST=1 ;; *) C71_ISDIST=0 ;; esac
C71_KEY='ledger_entry_line_closes(ledger_strip_inline_code($0))'
C71_RUN=1
if ! grep -qF "$C71_KEY" "$ROT"; then
  if [ "$C71_ISDIST" = 0 ]; then
    printf '  SKIP  BL-071 inline-code arms -- the installed ledger-rotate.sh predates the inline-code strip; it lands with the pull that carries this fixture\n'
  else
    bad "BL-071: the distribution ledger-rotate.sh does not carry the ship-ahead key '$C71_KEY' -- re-anchor the key on the fixed line, or every consumer SKIPS these arms forever"
  fi
  C71_RUN=0
fi
if [ "$C71_RUN" = 0 ]; then
  :
elif rg_refused fp-quotes; then
  ok "REFUSES a colon-less entry whose body only QUOTES the annotation form — INTENDED: a quotation is not a close, so the line is as unclassifiable as fp-open"
else
  bad "the guard rotated a ledger whose colon-less suspect is silenced only by a backticked QUOTATION of the close form — the quotation was read as a close and the split strands the receipt"
fi

# --- THE CLOSE VOCABULARY REACHES BOTH SIDES OF THIS GUARD, AND THEY FAIL OPPOSITE WAYS ------
#
# THE GUARD HAS TWO CLOSE TESTS AND THEY ARE DELIBERATELY DIFFERENT PREDICATES.
# `ledger_body_archives()` decides whether the entry ABOVE is closed, which is what makes a
# non-id boundary inside it a refusal candidate at all -- it ARMS the refusal.
# `ledger_entry_line_closes()` decides whether the SUSPECT LINE carries a close of its own,
# which SUPPRESSES the refusal. `ledger-rotate.sh:242-247` and `:257-276` state why one is the
# archive grammar and the other the loose skip rule: they fail in opposite directions, so one
# rule cannot serve both.
#
# BOTH USED TO CARRY A MEMBERSHIP OPINION AND BOTH WERE WRONG, IN OPPOSITE DIRECTIONS. The
# arming side was the hand-written `(v[0-9]` literal, which could not spell a withdrawal at all,
# so an entry closed that way was never seen as CLOSED and a split of it drew no refusal -- the
# one outcome this guard exists to prevent. The suppressing side hand-listed the alternation, so
# a suspect line closed as WITHDRAWN suppressed nothing and the guard refused a REAL entry,
# which wedges a rotation that would have been correct. Both now come from the single home, and
# both directions are asserted here because a fix to either alone reads identically on the other.
#
# THE TOKENS ARE DERIVED, NEVER SPELLED, for the reason `q_close_token()` gives at its
# definition: a fixture that writes the alternation into a heredoc is the third copy of the list
# the subject under test just deleted.
rg_tok2="$(q_close_token 2)" || rg_tok2=""
if [ -z "$rg_tok2" ] || [ "$rg_tok2" = "$(q_close_token 1)" ]; then
  bad "PRECONDITION FAILED: no distinct second close token could be derived from ledger-reverify.sh ('${rg_tok2:-<none>}'), so the two arms below are about ADOPTED UPSTREAM twice and cannot see the vocabularies diverging"
else
  # ARMING SIDE. The entry above is closed by the SECOND token, which the retired literal could
  # not spell. A suspect boundary sits inside it with the entry's receipt below. The guard must
  # REFUSE -- under the old literal this entry read as OPEN, the refusal never armed, and the
  # split shipped silently.
  printf '%s' "# Push-candidate ledger

- **PC-TOK-CLOSED-ABOVE** — closed by a token no literal in ledger-rotate.sh ever spelled

  <br>**${rg_tok2} 2026-07-25 — done.**

- **Note:** an annotation lead-in, written the way an operator writes one

  verify: theirs_has core/scripts/thing.sh \"MARKER_A\"
" > "$RG/susp-armed.md"
  if rg_refused susp-armed; then
    ok "the refusal ARMS on an entry closed by '${rg_tok2}' — the close test that decides CLOSED is the archive grammar, so a token the old literal could not spell no longer means a split ships with no refusal"
  else
    bad "the guard did NOT refuse a split of an entry closed by '${rg_tok2}'. That entry reads as OPEN to the arming test, so rotation archives its head and strands its receipt in the live ledger under no heading — silently, and irreversibly"
  fi

  # THE ARMING CONTROL, one property apart: the entry above is OPEN. Without it the arm above
  # passes against a guard that refuses unconditionally, which is the DENY-without-its-ALLOW-twin
  # shape — and an unconditional refusal wedges every rotation there is.
  printf '%s' "# Push-candidate ledger

- **PC-TOK-OPEN-ABOVE** — not closed at all, so nothing below it can be stranded

  Body text carrying no annotation.

- **Note:** an annotation lead-in, written the way an operator writes one

  verify: theirs_has core/scripts/thing.sh \"MARKER_A\"
" > "$RG/susp-unarmed.md"
  if rg_refused susp-unarmed; then
    bad "  the guard refuses the same shape below an OPEN entry — it is not keyed on the entry above being closed at all, so it refuses unconditionally and wedges every rotation"
  else
    ok "  and stays silent when the entry above is OPEN: the arming test reads the entry, not the shape of the line below it"
  fi

  # SUPPRESSING SIDE. The SUSPECT line carries a close of its own, written in the legacy id-less
  # form that puts it in the boundary line's own bold span, using that same second token. This is
  # a REAL entry closed in its own right: nothing of the entry above can be stranded by it, and
  # refusing here wedges a correct rotation.
  rg_write susp-suppressed "- **\`thing.sh\` → ${rg_tok2} 2026-07-25, closed in its own right.** legacy id-less

  verify: theirs_has core/scripts/thing.sh \"MARKER_A\"
"
  if rg_refused susp-suppressed; then
    bad "SUBJECT DEFECT — the guard refuses a REAL entry whose own close is written as '${rg_tok2}'. The suppressor does not honour the whole close vocabulary, so every legacy id-less entry closed that way wedges the rotation of the ledger it sits in"
  else
    ok "a suspect line closed IN ITS OWN RIGHT by '${rg_tok2}' suppresses the refusal — the suppressor is the loose skip rule from the single home, so it honours every token reverify does"
  fi

  # THE SUPPRESSION CONTROL, one property apart: the same line with no close marker at all. This
  # is the guard's actual subject and it MUST still refuse, or the suppressor has widened into
  # "never refuse" and the arm above is measuring nothing.
  rg_write susp-unsuppressed '- **`thing.sh` carries no close marker of its own.** legacy id-less

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
  if rg_refused susp-unsuppressed; then
    ok "  and the same line with NO close marker still refuses — the suppressor reads the marker, it has not widened into silence"
  else
    bad "  the same line with no close marker of its own was NOT refused, so the suppressor acquits everything and the arm above proves nothing"
  fi
fi

# --- THE ARMING TEST IS THE ARCHIVE GRAMMAR AND NOT THE LOOSE ONE ---------------------------
#
# THE TWO TESTS ASK A SIMILAR QUESTION AND FAIL IN OPPOSITE DIRECTIONS, so routing the arming
# side through the loose rule is a mutation every arm above survives -- measured, scored ZERO
# findings across this whole file until this arm existed. `ledger-rotate.sh:264-276` says it was
# BUILT and MEASURED that way and that it WEDGES rotation; nothing in the fixture could see that.
#
# THE DISCRIMINATING INPUT WAS MISSING, NOT THE PROPERTY. Every seed above whose entry is closed
# is closed by a real ANNOTATION, which BOTH rules take -- so both rules arm and the two sides
# compare equal. The input that separates them is an entry that the LOOSE rule reads as closed
# and the ARCHIVE grammar does not: a line-leading NARRATIVE mention carrying no bold span, in
# an entry that is still open. Measured, this ledger, shipped vs the loose-armed mutant:
# rc=0 no refusal against rc=1 REFUSING, with an annotation-closed control at rc=1 both ways.
#
# THE COST IS A WEDGE, NOT A MISSED FINDING, which is why the assertion is a SILENCE. Refusal is
# the whole of this guard's behaviour; a guard that refuses a ledger whose entry is merely
# DISCUSSING the vocabulary stops every rotation of that ledger, and the operator turns it off.
# The OPEN entry that narrates has to be the one the suspect sits inside, so this seed replaces
# the shared closed preamble rather than appending to it.
printf '%s' '# Push-candidate ledger

- **PC-LIVE-NARRATES** — an OPEN entry whose body narrates the close vocabulary line-leading

  ADOPTED UPSTREAM in v0.135.0 is what the sentinel got, but this entry is still open.

- **Note:** an annotation lead-in, written the way an operator writes one

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
' > "$RG/fp-narrated.md"
if rg_refused fp-narrated; then
  bad "SUBJECT DEFECT — the guard refuses a ledger whose entry merely NARRATES the vocabulary. The arming test is the loose skip rule rather than the archive grammar, so it reads OPEN work as closed and WEDGES every rotation of that ledger; refusal writes nothing at all, so there is no partial result either"
else
  ok "a suspect line below an entry that only NARRATES the vocabulary draws NO refusal — the arming test is the ARCHIVE grammar, which is the one that decides the move this guard protects"
fi
# AND THE DISCRIMINATION IS ASSERTED, not assumed: the same shape below a genuinely ANNOTATED
# entry must still refuse. Without this the arm above passes against a guard that never refuses.
if rg_refused splitter; then
  ok "  and the same shape below a genuinely ANNOTATED close still refuses — the two ledgers differ in how the entry above is closed, and only that"
else
  bad "  the annotated control stopped refusing, so the silence above is a guard that refuses nothing rather than a guard reading the right predicate"
fi

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

# --- THE PREFIX ROW IS THE SAME WITH THE ROTATION ARCHIVE DELETED ---------------------------
#
# THE OPERATOR'S RULE, ASSERTED ON THE ONE STATE ONLY A ROTATION PRODUCES. A reader's rows must
# be the same with all sprint history deleted. The history ledger-reverify could once read is
# the rotation archive, and an archive holding a sibling is a state only a rotation produces;
# this is the only fixture that rotates, which is why the arm lives here and not in
# `core/fixtures/ledger-reverify`, whose seed writes no archive at all.
#
# THE HARM IS A CHANGED VERDICT, NOT A CHANGED NUMBER. Two entries share PC-S901; one is closed
# and rotates. The survivor's upstream citation is the BARE prefix, and the row for it is one
# NAMED-UPSTREAM-AMBIGUOUS PC-S901 row attributed to no entry. The count it used to be gated on
# was open-live UNION archive, so deleting the archive changed the count from 2 to 1 and the row
# with it — exactly what the rule forbids. So: the shipping reverify must print BYTE-IDENTICAL
# output with the archive present and with it deleted, AND that output must carry the AMBIGUOUS
# row, AND it must not attribute the survivor by name.
#
# NOTE THE ROW-SET ARM ABOVE CANNOT COVER THIS. It compares before and after a rotation, and the
# archive is present on the after side only; it never compares a tree against the same tree with
# its history gone. Two assertions, two subjects.
PC="$WORK/prefix-counter"; rm -rf "$PC"; mkdir -p "$PC/led" "$PC/ctl"
cat > "$PC/led/push-candidate-ledger.md" <<'PCLED'
# Push-candidate ledger

## PC-S901-ALPHA — open, and the only LIVE member of its prefix once the sibling is archived

verify: theirs_has core/scripts/s900-landed.sh "s900"

## PC-S901-BETA — closed and archivable: the sibling the rotation moves

<br>**ADOPTED UPSTREAM (v0.95.0, verified 2026-01-01).** Upstream took it.

verify: theirs_has core/scripts/thing.sh "MARKER_B"
PCLED
bash "$ROT" "$PC/led/push-candidate-ledger.md" --apply >/dev/null 2>&1
# THE HISTORY-DELETED TWIN: the same rotated live ledger, with no archive beside it.
mkdir -p "$PC/nohist"
cp "$PC/led/push-candidate-ledger.md" "$PC/nohist/push-candidate-ledger.md"

cp "$(dirname "$RV")"/*.sh "$PC/ctl"/ 2>/dev/null
pc_rows() { bash "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$2/push-candidate-ledger.md" 2>/dev/null; }

if [ ! -s "$PC/led/push-candidate-ledger.archive.md" ] || grep -q 'PC-S901-BETA' "$PC/led/push-candidate-ledger.md"; then
  bad "FIXTURE BROKEN — the PC-S901 sibling did not reach the archive, so there is no history to delete and the twin below compares two identical trees"
elif [ -e "$PC/nohist/push-candidate-ledger.archive.md" ] || ! cmp -s "$PC/led/push-candidate-ledger.md" "$PC/nohist/push-candidate-ledger.md"; then
  bad "FIXTURE BROKEN — the history-deleted twin is not the same live ledger without its archive, so the comparison below is not the one the rule names"
else
  pc_hist="$(pc_rows "$PC/ctl/ledger-reverify.sh" "$PC/led")"
  pc_nohist="$(pc_rows "$PC/ctl/ledger-reverify.sh" "$PC/nohist")"
  # PRESENCE FIRST: two empty outputs are byte-identical, so equality alone would score a
  # classifier that never ran as one that ignores history.
  if ! grep -q "^NAMED-UPSTREAM-AMBIGUOUS${TAB}PC-S901${TAB}" <<<"$pc_hist" \
     || ! grep -q "^STILL-LIVE${TAB}PC-S901-ALPHA${TAB}" <<<"$pc_hist"; then
    bad "FIXTURE BROKEN — the shipping reverify emits no NAMED-UPSTREAM-AMBIGUOUS PC-S901 row (or no verdict for the survivor) with the archive present, so the twin below compares silences"
  elif [ "$pc_hist" = "$pc_nohist" ]; then
    ok "the shipping reverify prints BYTE-IDENTICAL output with the rotation archive present and deleted, including the unattributed NAMED-UPSTREAM-AMBIGUOUS PC-S901 row — no row depends on sprint history"
  else
    bad "ledger-reverify's output CHANGED when the rotation archive was deleted — a row depends on sprint history, which the operator ruled out"
    diff <(printf '%s\n' "$pc_hist") <(printf '%s\n' "$pc_nohist") | sed 's/^/      /' | head -6
  fi
  # AND THE CORRECT ANSWER IS ASSERTED POSITIVELY: the survivor is never attributed by name on a
  # commit that cites only the prefix, with or without history.
  if grep -q "^NAMED-UPSTREAM${TAB}PC-S901-ALPHA${TAB}" <<<"$pc_hist$pc_nohist"; then
    bad "  the shipping reverify attributes PC-S901-ALPHA to upstream BY NAME on a bare-prefix citation — a bare prefix does not say which entry it means"
  else
    ok "  and it makes no single attribution for the surviving entry, with the archive or without it"
  fi
fi

echo "== DERIV. the archive grammar is DERIVED, and the derivation refuses audibly =="

# WHAT IS BEING GUARDED HERE IS THE JOIN ITSELF, NOT A VERDICT.
#
# `lib.sh`'s `ledger_archive_awk()` builds rotation's grammar by taking the close rule out of
# `ledger-reverify.sh` and promoting its OPTIONAL bold span to a MANDATORY one. That transform
# has a precondition: the close rule must CONTAIN an optional bold span to promote. If the rule
# is reworded so it does not, there is no archive rule to derive.
#
# THE QUIET FAILURE IS THE ONLY ONE THAT MATTERS. Interpolated into an awk program, an empty
# predicate makes awk die on an undefined function -- or, worse, makes it decide that NOTHING is
# closed. Rotation would then move nothing and exit 0, which reads EXACTLY like a ledger with
# nothing closed in it. The refusal is what stands between those two states, and a refusal that
# is not asserted is a refusal nobody notices leaving.
#
# BOTH DIRECTIONS, SEEDED UNDER $WORK AND NEVER AGAINST THE REAL CORPUS. The OFFENDER is a
# reverify copy whose close rule has lost its optional bold span; the NEAR-MISS is a copy whose
# rule keeps the span and merely gains a token, which must derive cleanly -- that is the case a
# refusal keyed on the wrong property would also reject, and it is the one that happens.
DV="$WORK/deriv"; rm -rf "$DV"; mkdir -p "$DV/off" "$DV/near" "$DV/ctl"
for d in off near ctl; do cp "$(dirname "$ROT")"/*.sh "$DV/$d/" 2>/dev/null; done
cat > "$DV/led.md" <<'DVLED'
# Push-candidate ledger

## PC-DV-CLOSED — a genuine close, so a working rotator has something to report
**ADOPTED UPSTREAM (v0.210.0, verified 2026-07-21).** really closed.

## PC-DV-OPEN — an open entry, so a rotator that moved everything would read differently
Body text carrying no annotation.
DVLED

# THE OFFENDER: the optional bold span removed from the close rule. Keyed on the span's own
# literal bytes -- the same `(\*\*[^`]*)?` `ledger_archive_awk()` searches for -- so this seeds
# exactly the precondition the refusal names and not some adjacent breakage.
sed 's@(\\\*\\\*\[\^`\]\*)?@@' "$RV" > "$DV/off/ledger-reverify.sh"
# THE NEAR-MISS: the span kept, one token added to the alternation. Built from a token that is
# NOT already in the rule, so this is a real change to the vocabulary and not a no-op.
#
# BOTH PREDICATES GAIN IT, WHICH IS WHAT A REAL TOKEN ADDITION LOOKS LIKE. `ledger-reverify.sh`
# carries the vocabulary on two lines -- the body rule and the entry-line rule -- and the commit
# that added `CLOSED AS REJECTED` edited both. Seeding only one would make this near-miss a
# HALF-edit nobody writes, and the derivation would then be acquitted on an input it never sees.
# The insertion is anchored on the FIRST derived token so nothing here spells the alternation.
sed "s@$(q_close_token 1)|@$(q_close_token 1)|SUPERSEDED BY THE FIXTURE|@" "$RV" > "$DV/near/ledger-reverify.sh"

dv_run() { bash "$DV/$1/ledger-rotate.sh" "$DV/led.md" --archive "$DV/$1/arch.md" 2>&1; }

if cmp -s "$RV" "$DV/off/ledger-reverify.sh"; then
  bad "FIXTURE BROKEN — removing the optional bold span from the close rule matched nothing, so the refusal arm below is unproven"
else
  dv_off="$(dv_run off)"; dv_off_rc=$?
  if [ "$dv_off_rc" -eq 0 ]; then
    bad "the derivation SURVIVED a close grammar with no optional bold span (rc=0). With nothing to promote the archive predicate is empty, rotation decides that nothing is closed, and the run is byte-indistinguishable from a ledger with nothing closed in it"
  elif grep -q 'cannot find the optional bold span' <<<"$dv_off"; then
    ok "the derivation REFUSES AUDIBLY when the close grammar loses its optional bold span (rc=$dv_off_rc), naming the span it could not find — rotation's extra strictness IS that promotion, so with nothing to promote there is no rule to derive"
  else
    bad "the derivation exited $dv_off_rc but said nothing about the missing bold span, so the operator is told a rotation failed and not which join came apart: $(printf '%s' "$dv_off" | head -1)"
  fi
  if grep -q 'PC-DV-CLOSED' <<<"$dv_off"; then
    bad "  and it reported an entry as moving anyway — a refusal that still rotates is not a refusal"
  else
    ok "  and it rotates nothing while refusing, so the refusal is not survivable"
  fi
fi

if cmp -s "$RV" "$DV/near/ledger-reverify.sh"; then
  bad "FIXTURE BROKEN — the token-addition near-miss matched nothing, so the acquittal below is vacuous"
else
  dv_near="$(dv_run near)"; dv_near_rc=$?
  if [ "$dv_near_rc" -ne 0 ]; then
    bad "NEAR-MISS: the derivation refused a close rule that merely gained a TOKEN (rc=$dv_near_rc). The refusal is keyed on the wrong property — adding a token to the single home is the ordinary case, and refusing it wedges every rotation on the day the vocabulary grows: $(printf '%s' "$dv_near" | head -1)"
  elif grep -q 'PC-DV-CLOSED' <<<"$dv_near" && ! grep -q 'PC-DV-OPEN' <<<"$dv_near"; then
    ok "  NEAR-MISS: a close rule that gains a TOKEN derives cleanly and reaches the same verdict — the refusal is keyed on the bold span, not on the alternation's membership"
  else
    bad "  NEAR-MISS: the derivation succeeded but the verdict moved, so adding a token to the single home changed what rotation archives about entries that do not use it"
  fi
fi

echo "== BL. a close on the entry's OWN boundary line is seen by the archive predicate =="

# The boundary-line rule ends in `next`, which used to skip every flag-setting rule below it:
# the archive test, the lifted loose test and the retained-copy test alike. An entry whose
# close annotation sat on its own opening line was therefore ARCHIVED BY NOTHING AND REPORTED
# BY NOTHING -- it fell through `started && !closed && loose` into `keep`, silently. That is
# the state the stuck list exists to eliminate, surviving in the one shape the stuck list
# could not see.
#
# THE TWO LEDGERS DIFFER IN ONE VARIABLE AND NOTHING ELSE: where the identical, correctly
# spelled annotation sits. Anything else moving between them would make this a comparison of
# two ledgers rather than of two line positions.
#
# THE BODY CASE IS THE NON-VACUITY CONTROL, and it is the half that says the fix widened the
# SUBJECT rather than loosening the RULE. A change that made everything archivable would move
# both rows and read exactly like this arm passing.
BLW="$WORK/bl"; rm -rf "$BLW"; mkdir -p "$BLW"
bl_ledger() { # $1 path, $2 the entry's opening line, $3 its body line
  cat > "$1" <<EOF
# Push Candidate Ledger

Preamble that always stays.

- **PC-BL-OPEN** — an open entry with no close anywhere.
  Body text carrying no annotation.

$2
$3
EOF
}
bl_ledger "$BLW/onboundary.md" \
  '- **ADOPTED UPSTREAM (v0.135.0, verified 2026-08-25).** validate-ci-gates.sh' \
  '  Body line carrying no annotation of its own.'
bl_ledger "$BLW/inbody.md" \
  '- **validate-ci-gates.sh** legacy id-less entry' \
  '  **ADOPTED UPSTREAM (v0.135.0, verified 2026-08-25).**'

bl_moves() { bash "$ROT" "$1" --archive "$BLW/arch.md" 2>&1 | grep -c 'would move'; }
bl_on="$(bl_moves "$BLW/onboundary.md")"
bl_in="$(bl_moves "$BLW/inbody.md")"

if [ "$bl_on" -eq 1 ]; then
  ok "a strict close on the entry's own boundary line is archivable"
else
  bad "a correctly spelled close on the boundary line was NOT seen — the entry is archived by nothing and reported by nothing, which is invisible in both directions"
fi
if [ "$bl_in" -eq 1 ]; then
  ok "CONTROL: the same close one line down in the body still archives (the body path did not regress)"
else
  bad "CONTROL: the BODY case stopped archiving — this change broke the path that already worked"
fi

# THE LOOSE HALF. Setting only the archive flag from the boundary line would leave a close the
# ARCHIVE grammar does not take exactly as invisible as before -- no archive, and no stuck row
# either. Such an entry must become a REPORTED stuck row, which is a presence assertion.
#
# THE SUBJECT MOVED, AND THE SEED MOVED WITH IT. This seeded a VERSIONLESS close, because the
# archive rule was a literal demanding a digit after `(v`. That literal is gone: rotation's
# grammar is derived from the skip grammar by promoting the bold span, and it says nothing about
# the parenthetical -- so a versionless close is now a real close and ARCHIVES. Asserting it as
# stuck would be asserting the defect the change removed. The class that still reaches the stuck
# list is the one the two grammars genuinely separate: a close with NO BOLD SPAN, which reverify
# skips on and rotation will not move. Measured at this tip on the old seed: 0 stuck rows, 1
# would-move -- which is the CORRECT answer and read as the loose half being missing.
#
# THE CLOSE SITS ON THE BOUNDARY LINE, AND THAT IS WHAT MAKES THIS ARM ABOUT THE BOUNDARY PATH.
# Written one line down in the BODY, the body-side loose rule reports it and the arm passes without
# the entry-line flags.
# A HEADING shape is used because the bullet shape opens on `- **`, so a bullet entry always
# carries a bold span and cannot express "line-leading close, no bold span" at all.
printf '%s\n' \
  '# Push Candidate Ledger' '' 'Preamble that always stays.' '' \
  '- **PC-BL-OPEN** — an open entry with no close anywhere.' \
  '  Body text carrying no annotation.' '' \
  '## PC-BL-NOBOLD — ADOPTED UPSTREAM (absorbed before base acdae7a, verified 2026-07-24), no bold span' \
  '  Body line carrying no annotation of its own.' > "$BLW/nobold.md"
bl_nb_out="$(bash "$ROT" "$BLW/nobold.md" --archive "$BLW/arch.md" 2>&1)"
bl_stuck="$(grep -c 'NOT archivable' <<<"$bl_nb_out")" || bl_stuck=0
bl_nb_moved="$(grep -c 'would move' <<<"$bl_nb_out")" || bl_nb_moved=0
if [ "$bl_stuck" -eq 1 ] && [ "$bl_nb_moved" -eq 0 ]; then
  ok "a close with NO BOLD SPAN is reported as stuck rather than vanishing (stuck=$bl_stuck moved=$bl_nb_moved) — the loose test still fires where the archive test does not"
else
  bad "a no-bold close was neither archived nor reported (stuck=$bl_stuck moved=$bl_nb_moved) — the loose half of the boundary fix is missing, so the quiet case is still invisible"
fi

# AND THE VERSIONLESS BOUNDARY CLOSE ARCHIVES, which is the half that USED to be stuck. Seeded
# here rather than only in the PC-Q block because the boundary line is its own code path --
# `ledger_entry_line_archives()`, derived from reverify's ENTRY-LINE rule rather than its body
# one -- and an entry-line grammar that kept a version opinion would be invisible to a body-line
# assertion.
bl_ledger "$BLW/versionless.md" \
  '- **ADOPTED UPSTREAM (absorbed before base acdae7a, verified 2026-07-24).** thing' \
  '  Body line carrying no annotation of its own.'
bl_vl_out="$(bash "$ROT" "$BLW/versionless.md" --archive "$BLW/arch.md" 2>&1)"
bl_vl_moved="$(grep -c 'would move' <<<"$bl_vl_out")" || bl_vl_moved=0
bl_vl_stuck="$(grep -c 'NOT archivable' <<<"$bl_vl_out")" || bl_vl_stuck=0
if [ "$bl_vl_moved" -eq 1 ] && [ "$bl_vl_stuck" -eq 0 ]; then
  ok "  and a VERSIONLESS close on the boundary line ARCHIVES (moved=$bl_vl_moved stuck=$bl_vl_stuck) — the entry-line grammar asks for the annotation form, not for a version"
else
  bad "  a versionless boundary-line close did not archive (moved=$bl_vl_moved stuck=$bl_vl_stuck) — demanding a digit on the entry-line path leaves a withdrawal or a pre-base absorption resident forever"
fi

# --- AND THE ENTRY-LINE PATH HONOURS THE WHOLE VOCABULARY, WHICH IS ITS OWN ASSERTION -------
#
# TWO ARCHIVE PREDICATES, TWO POPULATIONS, AND THE PC-Q BLOCK REACHES ONLY ONE OF THEM.
# `ledger_body_archives()` decides a close sitting in the BODY; `ledger_entry_line_archives()`
# decides one sitting on the entry's OWN boundary line, and `lib.sh` derives the second from
# reverify's ENTRY-LINE rule rather than its body rule because the two do not honour the same
# set. Every token-set arm in the PC-Q block seeds its close in a BODY, so a body predicate
# alone satisfies all of them. Measured: rotation's entry-line rule hand-written back to a
# one-token literal moves this ledger from 1 archived / 0 stuck to 0 / 1 and changes NOTHING
# else in this file -- the class this whole change exists to empty, surviving in the one
# predicate nobody was asserting about.
#
# THE TOKEN IS DERIVED, for the reason `q_close_token()` states at its definition: spelling it
# here would be another copy of a list the subject under test just reduced to one.
bl_tok2="$(q_close_token 2)" || bl_tok2=""
if [ -z "$bl_tok2" ] || [ "$bl_tok2" = "$(q_close_token 1)" ]; then
  bad "PRECONDITION FAILED: no distinct second close token derived ('${bl_tok2:-<none>}'), so the entry-line arm below cannot see the two grammars diverging"
else
  printf '%s\n' \
    '# Push Candidate Ledger' '' 'Preamble that always stays.' '' \
    '- **PC-BL-OPEN** — an open entry with no close anywhere.' \
    '  Body text carrying no annotation.' '' \
    "- **${bl_tok2} 2026-07-25 — done.** legacy id-less, closed on its OWN boundary line" \
    '  Body line carrying no annotation of its own.' > "$BLW/tokboundary.md"
  bl_tk_out="$(bash "$ROT" "$BLW/tokboundary.md" --archive "$BLW/arch.md" 2>&1)"
  bl_tk_moved="$(grep -c 'would move' <<<"$bl_tk_out")" || bl_tk_moved=0
  bl_tk_stuck="$(grep -c 'NOT archivable' <<<"$bl_tk_out")" || bl_tk_stuck=0
  if [ "$bl_tk_moved" -eq 1 ] && [ "$bl_tk_stuck" -eq 0 ]; then
    ok "  and a close by '${bl_tok2}' on the entry's OWN boundary line ARCHIVES (moved=$bl_tk_moved stuck=$bl_tk_stuck) — the entry-line grammar is derived from reverify's entry-line rule, so it honours every token that rule does"
  else
    bad "  a close by '${bl_tok2}' on the boundary line was not archived (moved=$bl_tk_moved stuck=$bl_tk_stuck). The entry-line predicate keeps a membership opinion of its own, so an entry closed that way is skipped by every re-verification AND refused by every rotation — and no body-line assertion can see it"
  fi
fi

rm -rf "$BLW"

# --- BL-071: A QUOTATION IS NOT A CLOSE, FOR EITHER SUSPECT SHAPE ---------------------------
#
# The suppressor that clears a suspect used to be the LOOSE close rule for every suspect, so a
# lead-in inside a closed entry, whose body only QUOTES the annotation form, scored as carrying
# its own close and the split shipped. Two branches now. A label ending in a colon is a lead-in
# by shape, so its suppressor is the archive grammar, unstripped. Every other suspect keeps the
# loose rule, read against the line with its inline code removed: balanced double-backtick
# spans, then balanced single ones, then a lone backtick to end of line.
#
# EVERY SEED BELOW HAS A SUBJECT NO OTHER SEED COVERS. Gated on C71_RUN, which arm (5) above computes from the
# ship-ahead key, so a consumer on a pre-fix rotator SKIPS this block with one line.
if [ "$C71_RUN" = 1 ]; then
  C71_V='  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
  rg_write colon-mention '- **Note:** an annotation lead-in whose body QUOTES the annotation form

  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero.

'"$C71_V"
  rg_write colon-closed '- **Note:** a colon-titled line that carries a genuine bolded close of its own

  **ADOPTED UPSTREAM (v0.100.0, verified 2026-01-01).** Upstream took it.

'"$C71_V"
  rg_write nocolon '- **Note** a lead-in with no colon

  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero.

'"$C71_V"
  # A LONE BACKTICK BEFORE THE TOKEN: the span never closes on this line, so only the
  # lone-backtick-to-end-of-line deletion removes the token.
  rg_write nocolon-odd '- **Note** a lead-in with no colon

  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>) once the grep is non-zero.

'"$C71_V"
  # THE MENTION WRAPPED ACROSS TWO LINES: the opening backtick is on the line carrying the token.
  rg_write nocolon-twoline '- **Note** a lead-in with no colon

  Annotate it `ADOPTED UPSTREAM (vX.Y.Z,
  verified <date>)` once the grep is non-zero.

'"$C71_V"
  rg_write nocolon-dbl '- **Note** a lead-in with no colon

  Annotate it ``ADOPTED UPSTREAM (vX.Y.Z, verified <date>)`` once the grep is non-zero.

'"$C71_V"
  # A REAL BOLDED CLOSE BELOW A QUOTED MENTION: the strip removes the quotation and must leave
  # the bold span, or a genuinely closed entry is refused.
  rg_write realclose-afterquote '- **A real entry that QUOTES the form and then closes** in its own right

  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero.

  **ADOPTED UPSTREAM (v0.2.0, verified 2026-01-02).** closed in its own right

'"$C71_V"
  # A COLON SUSPECT WHOSE BOLD SPAN OPENS ON A BACKTICKED NAME. The archive grammar rejects it,
  # because its bold span may not contain a backtick; stripping the colon branch would delete the
  # name and leave `**  ADOPTED UPSTREAM`, which the archive grammar accepts. The colon branch is
  # therefore NOT stripped, and this seed is the one that says so.
  rg_write colon-btbold '- **Note:** a colon lead-in whose bold span opens on a backticked name

  **`foo.sh` ADOPTED UPSTREAM (v0.2.0, verified 2026-01-02).** a name, not a close

'"$C71_V"
  # A QUOTATION ON THE SUSPECT BOUNDARY LINE ITSELF, for each label shape. The boundary line is
  # read with its inline code removed too, so neither is silenced by the span it carries.
  rg_write title-nocolon '- **Note** annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero

'"$C71_V"
  rg_write title-colon '- **Note:** annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero

'"$C71_V"
  # A REAL BARE CLOSE AFTER A SPAN ON THE SAME LINE, in the reference consumer`s own legacy body
  # shape. The balanced single-span removal must delete the NAME and leave the close; deleting
  # nothing there lets the lone-backtick rule eat the close and refuses a real entry.
  rg_write close-after-span '- **A real entry** in the legacy body shape

- `validate-provenance-block.sh` → ADOPTED UPSTREAM (v0.135.0). Stock carries it.

'"$C71_V"
  # A REAL BARE CLOSE BETWEEN TWO SPANS. Each span is removed on its own; a greedy span from the
  # first backtick to the last would swallow the close.
  rg_write close-between-spans '- **A real entry** with spans around a close

  `a.sh` ADOPTED UPSTREAM (v0.2.0, verified 2026-01-02). `b.sh`

'"$C71_V"
  C71_SEEDS="splitter colon-mention nocolon nocolon-odd nocolon-twoline nocolon-dbl fp-quotes colon-closed fp-legacy fp-versionless realclose-afterquote colon-btbold title-nocolon title-colon close-after-span close-between-spans"
  C71_WANT=RRRRRRRSSSSRRRSS
  c71_one() { # <rotator> <seed> -> one letter (R refused, S rotates, E died)
    local out rc
    out="$(bash "$1" "$RG/$2.md" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ] && grep -q 'REFUSING to rotate' <<<"$out"; then printf R
    elif [ "$rc" -eq 0 ]; then printf S
    else printf E; fi
  }
  c71_cells() { # <rotator> -> one letter per seed in C71_SEEDS order
    local r="" f
    set -f
    for f in $C71_SEEDS; do r="${r}$(c71_one "$1" "$f")"; done
    set +f
    printf '%s\n' "$r"
  }
  c71_ship="$(c71_cells "$ROT")"
  c71_i=0
  set -f
  for c71_f in $C71_SEEDS; do
    c71_i=$((c71_i + 1))
    c71_w="$(printf '%s' "$C71_WANT" | cut -c"$c71_i")"
    c71_g="$(printf '%s' "$c71_ship" | cut -c"$c71_i")"
    case "$c71_w" in R) c71_say="REFUSED" ;; *) c71_say="rotates" ;; esac
    if [ "$c71_g" = "$c71_w" ]; then
      ok "BL-071 cell $c71_f: $c71_say, as ruled"
    else
      bad "BL-071 cell $c71_f: expected $c71_w and read $c71_g (cells $c71_ship, want $C71_WANT) — a quotation silenced the guard, or a real close stopped silencing it"
    fi
  done
  set +f
fi

# --- BL-006: AN ENTRY-COUNT CEILING THAT WARNS AND STILL ROTATES -----------------------------
#
# The rotator is the ONLY thing that shrinks the ledger, so the ceiling on what STAYS after
# rotation must warn and never refuse. Every arm below drives the shipping rotator. The ceiling is
# READ from the rotator, never spelled here, so the at-ceiling near miss tracks it.
# Entries are BULLETS, which is how the reference consumer writes most of them: a count of
# `^## ` headings reads 0 on these ledgers, so a heading-keyed ceiling cannot pass the over arm.
case "$ROT" in */core/skills/ai-dlc-update/reconcile/ledger-rotate.sh) C6_ISDIST=1 ;; *) C6_ISDIST=0 ;; esac
C6_RUN=1
C6_MAX="$(sed -n 's/^LEDGER_MAX_OPEN_ENTRIES=\([0-9][0-9]*\)$/\1/p' "$ROT")"
if [ -z "$C6_MAX" ]; then
  if [ "$C6_ISDIST" = 0 ]; then
    printf '  SKIP  BL-006 ceiling arms -- the installed ledger-rotate.sh predates the entry-count ceiling; it lands with the pull that carries this fixture\n'
    C6_RUN=0
  else
    bad "BL-006: ledger-rotate.sh declares no LEDGER_MAX_OPEN_ENTRIES ceiling — the live ledger is unbounded in what stays open"
    C6_RUN=0
  fi
fi
if [ "$C6_RUN" = 1 ]; then
  C6="$WORK/c6"; rm -rf "$C6"; mkdir -p "$C6"
  c6_ledger() { # <path> <open entries> <closed entries>
    { printf '# Push-candidate ledger\n\nPreamble prose that belongs to no entry.\n\n'
      awk -v o="$2" -v c="$3" 'BEGIN{
        for (i = 1; i <= c; i++) printf "- **PC-S900-C%04d** — a closed push candidate\n\n  **ADOPTED UPSTREAM (v0.1.0, verified 2026-01-01).** Upstream took it.\n\n", i
        for (i = 1; i <= o; i++) printf "- **PC-S900-O%04d** — an open push candidate\n\n  Body text.\n\n", i }'
    } > "$1"
  }
  c6_ledger "$C6/over.md"  "$((C6_MAX + 1))" 3
  c6_ledger "$C6/at.md"    "$C6_MAX"         3
  c6_ledger "$C6/over0.md" "$((C6_MAX + 1))" 0
  # 0 iff: rc 0, WARN present, and the ledger rotates (dry: would move; apply: archive gains the
  # closed entries and the ledger loses them). <rotator> <ledger> <mode: dry|apply|none>
  c6_check() {
    local out rc
    cp "$2" "$C6/run.md"; rm -f "$C6/arch.md"
    if [ "$3" = apply ]; then out="$(bash "$1" "$C6/run.md" --archive "$C6/arch.md" --apply 2>&1)"; rc=$?
    else out="$(bash "$1" "$C6/run.md" --archive "$C6/arch.md" 2>&1)"; rc=$?; fi
    [ "$rc" -eq 0 ] || return 3
    grep -q "WARN — .* entries stay in the live ledger after rotation, above the ceiling of ${C6_MAX}" <<<"$out" || return 1
    case "$3" in
      dry)   grep -q '3 closed entries would move' <<<"$out" || return 2 ;;
      apply) [ "$(grep -c 'PC-S900-C' "$C6/arch.md" 2>/dev/null)" = 3 ] || return 2
             [ "$(grep -c 'PC-S900-C' "$C6/run.md")" = 0 ] || return 2 ;;
      none)  grep -q 'nothing to rotate' <<<"$out" || return 2 ;;
    esac
    return 0
  }
  c6_quiet() { # <rotator> <ledger> -> 0 iff rc 0 and NO warning
    local out rc
    out="$(bash "$1" "$2" --archive "$C6/arch.md" 2>&1)"; rc=$?
    [ "$rc" -eq 0 ] && ! grep -q 'WARN' <<<"$out" && grep -q 'closed entries would move' <<<"$out"
  }
  c6_cells() { # <rotator> -> four letters: over-dry over-apply over-zero-closed at-quiet (P pass, F fail)
    local r=""
    c6_check "$1" "$C6/over.md" dry   && r="${r}P" || r="${r}F"
    c6_check "$1" "$C6/over.md" apply && r="${r}P" || r="${r}F"
    c6_check "$1" "$C6/over0.md" none && r="${r}P" || r="${r}F"
    c6_quiet "$1" "$C6/at.md"         && r="${r}P" || r="${r}F"
    printf '%s\n' "$r"
  }
  c6_ship="$(c6_cells "$ROT")"
  case "$c6_ship" in P???) ok "BL-006: a ledger with $((C6_MAX + 1)) open entries WARNS on a dry run, exits 0, and still reports the closed entries it would move" ;;
    *) bad "BL-006: the over-ceiling dry run did not WARN-and-rotate (cells $c6_ship)" ;; esac
  case "$c6_ship" in ?P??) ok "  and under --apply it WARNS, exits 0, and the closed entries MOVE — the ceiling never refuses the one lever that shrinks the ledger" ;;
    *) bad "  under --apply the over-ceiling ledger did not warn, exit 0 AND move its closed entries (cells $c6_ship) — a refusing ceiling blocks the only thing that shrinks the ledger" ;; esac
  case "$c6_ship" in ??P?) ok "  and a ledger over the ceiling with NOTHING closed still warns — the warning precedes the nothing-to-rotate exit" ;;
    *) bad "  an over-ceiling ledger with zero closed entries did not warn (cells $c6_ship) — the unrotatable case, the one the ceiling exists for, is silent" ;; esac
  case "$c6_ship" in ???P) ok "  and a ledger AT the ceiling (${C6_MAX} open) rotates with no warning — the bound is strictly-above" ;;
    *) bad "  a ledger exactly at the ceiling warned or failed (cells $c6_ship) — the comparison is off by one" ;; esac

  rm -rf "$C6"
fi

echo
report_end ledger-rotate
