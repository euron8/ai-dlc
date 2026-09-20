#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# ledger-rotate/run.sh — prove rotation removes CLOSED entries, keeps OPEN ones, loses
# nothing, and does not change what the classifier says about the work still open.
#
# THE ACCEPTANCE TEST IS THE ROW SET, NOT THE BYTES, and `ledger-rotate.sh`'s own header states
# the same projection rather than a second one: ledger-reverify.sh must emit the SAME ROW SET, by
# STATUS and SUBJECT, before and after. Rotation moves exactly the entries reverify already
# skips, so a row that appears or disappears means the split took a live entry — the only
# failure mode that actually costs anything.
#
# THE ROW SET IS THE PROJECTION, AND THE COUNTER IS COUNTED SO THAT THE BYTES HOLD TOO.
# `prefix_entry_count()` in ledger-reverify.sh counts a sprint prefix over the CORPUS — every
# entry line in both files, open or closed — so annotating moves nothing and rotating moves one
# entry between the files, and the number printed inside NAMED-UPSTREAM-AMBIGUOUS details is the
# same on both sides of either step. It used to count OPEN entries unioned with ARCHIVED labels,
# and an entry annotated in the same pass — exactly what annotate-then-rotate prescribes — sat on
# NEITHER side until the move landed, so the count dipped at the annotate and returned at the
# rotate: a changed LINE on an identical ROW SET where the prefix had three members, and a
# changed ROW where it had two, because a dip to ONE crosses from `named_ambiguous()` into
# `named_absorbed()`'s single attribution. Assertion 4 asserts the row set and the stable count
# on the three-member trio, 4b proves the comparison still FAILS on a genuine sweep, and 4c
# walks the two-member pair through annotate and rotate and asserts the row set holds across
# the crossing.
#
# THE OLD ARM COULD NOT FAIL ON THIS, AND ITS SUBJECT WAS UNCONSTRUCTIBLE RATHER THAN UNSEEDED.
# `named_ambiguous()` gates on a `PC-S[0-9]+` prefix shared by two or more entries; seed.sh
# carried no id of that shape at all, so no NAMED-UPSTREAM-AMBIGUOUS row could be produced no
# matter what the code under test did, and the assertion would have stayed green through any
# rewrite of the invariant it existed to guard. The PC-S900 trio in seed.sh is what gives it one.
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

# --- Assertion 2b: A CLOSED ENTRY WHOSE FENCE RECORDS A HEADING-SHAPED LINE ROTATES WHOLE ----
# PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS. The seed's PC-CLOSED-FENCED
# entry carries a `derived` fence whose recorded output is a `## <ts> -- EVENT` line. Under a
# fence-blind boundary rule that line opened an entry, the head stayed live with an unterminated
# fence and the tail archived under a timestamp label -- the reference consumer's live ledger
# holds exactly that residue from its 0.497.0 pull. The property is whole-entry movement AND
# fence balance on both sides; the mutant at the foot of this file re-derives the split.
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
# dropped deliberately: it is where `prefix_entry_count()` prints a number that MOVES on a
# correct rotation. Dropping it is the whole correction; it is not a loosening, because every
# row this fixture cares about losing is identified by its status and subject.
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

# ...AND THE BYTES ARE IDENTICAL TOO, BECAUSE THE COUNT NO LONGER MOVES. This arm used to assert
# the opposite — that the bytes DIFFERED on a correct rotation, with the differing lines carrying
# a prefix count that rose 2 -> 3 — and that was a true description of a defect, not of the
# invariant: `prefix_entry_count()` counted open-live UNION archive, so the closed-but-unrotated
# GAMMA sat on neither side until the move landed. It now counts the ledger CORPUS, both files,
# open or closed, so annotate and rotate both leave it where it was. The dip that arm recorded
# is the same mechanism that, one member fewer, crosses the one-vs-many threshold and flips a
# ROW — assertion 4c below — which is why "the bytes differ" could never have been the property.
#
# STILL PRESENCE-SHAPED: a report with no prefix count at all would satisfy "identical" on
# silence, so the count is read out and asserted at its value on BOTH sides.
if [ "$n_linediff" -eq 0 ]; then
  ok "  and the BYTES are identical across the move on all ${n_rows} rows — the prefix count printed in the AMBIGUOUS detail no longer dips while GAMMA is annotated-but-unrotated"
else
  bad "  the two outputs differ on ${n_linediff} of ${n_rows} lines with an identical row set, so a DETAIL moved across a rotation that moved nothing the classifier reads — prefix_entry_count() is counting a set that changes at annotate or at rotate"
  diff "$WORK/rv-before.txt" "$WORK/rv-after.txt" | sed 's/^/      /' | head -6
fi

# THE NUMBER THAT USED TO MOVE, NAMED AT ITS VALUE. Asserting the specific 3 -> 3 rather than
# "nothing changed" ties the arm to `prefix_entry_count()` counting all three trio members on
# both sides — the closed GAMMA before the move and the archived GAMMA after it. A stub returning
# a constant, or a count that dropped GAMMA on one side, reads differently here. The archive-arm
# mutant at the foot of this file kills the after-side reading; the crossing mutant in 4c kills
# the before-side one.
pfx_n() { sed -n 's/.*and \([0-9][0-9]*\) entries in this ledger carry it.*/\1/p' <<<"$1"; }
b_n="$(pfx_n "$before_verdicts")"; a_n="$(pfx_n "$after_verdicts")"
if [ "$b_n" = "3" ] && [ "$a_n" = "3" ]; then
  ok "  and the PC-S900 prefix count holds 3 -> 3 across the move: the closed sibling is counted while it sits annotated in the live file AND once it is archived"
else
  bad "  the PC-S900 prefix count went '${b_n:-<none>}' -> '${a_n:-<none>}', expected 3 -> 3. A dip on the left means prefix_entry_count() dropped the annotated-but-unrotated sibling; a change on the right means it stopped counting one of the two files"
fi

# --- Assertion 4b: MUTATION — A GENUINE SWEEP MUST STILL FAIL THE ROW-SET TEST ----------
#
# WITHOUT THIS, ASSERTION 4 IS A LAXER ASSERTION THAN THE ONE IT REPLACES AND NOTHING SAYS SO.
# Dropping the detail column removes real information, so the question the reshape has to answer
# is whether the projection that remains still catches an entry being swept. It does, and the
# reason is structural: a swept entry stops being extracted as open, so it stops emitting a row
# at all — status and subject are exactly what disappears.
#
# THE MUTATION IS THE ONE THAT PRODUCES THE REAL DEFECT (PC-S331): make the archive grammar
# stop requiring a LINE START, and the rotator matches an entry against its own INLINE quotation
# of the annotation form. `PC-SW-OPEN` below is that entry, and it carries a receipt so
# ledger-reverify emits a row for it — the quoting entry in the PC-S331 ledger further down does
# not, which is why this needs its own seed rather than reusing that one.
#
# THE SUBJECT MOVED WITH THE GRAMMAR, AND THE ANCHOR HAD TO MOVE WITH IT. This mutation used to
# delete the version DIGIT from a literal `**ADOPTED UPSTREAM (v[0-9]` written out in
# `ledger-rotate.sh`. That literal is GONE: rotation's grammar is now DERIVED in `lib.sh`'s
# `ledger_archive_awk()` by promoting reverify's optional bold span to a mandatory one, and the
# digit was retired deliberately because a close that genuinely has no version is a real close.
# Measured at this tip: the old sed matched 0 lines (control, same invocation: a sed on
# `ledger_body_archives` matched), so it scored a kill for a mutation that never applied.
#
# THE NEW ANCHOR IS THE PREDICATE THAT DECIDES, NOT A SPELLING. `_lar_head` is the line-leading
# `^[ \t]*(<br…>)?[ \t]*` prefix that `ledger_archive_awk()` carries across from the skip rule.
# Emptying it leaves the bold span and the token set exactly as they are and removes only the
# requirement that the annotation OPEN its line — which is precisely what lets a mid-sentence
# quotation match. Measured on the seed below: 1 entry moves unmutated, 2 mutated, and the extra
# one is PC-SW-OPEN.
#
# THE MUTATION IS IN `lib.sh`, WHICH BOTH COPIES SOURCE, so the control and the mutant need
# SEPARATE program directories — mutating the shared `lib.sh` in one directory would move the
# control too, and two identically-swept runs compare equal.
#
# THE QUOTATION IS MID-LINE, DELIBERATELY. reverify's body-close rule is ANCHORED, so a phrase
# in the middle of a sentence does not close the entry there; an unanchored archive rule matches
# the same line. That asymmetry is what lets one seed be both live to the classifier and
# archivable by a broken rotator.
SW="$WORK/sweep"; rm -rf "$SW"; mkdir -p "$SW/ctl" "$SW/mut" "$SW/bin" "$SW/mbin"
cat > "$SW/led.md" <<'SWLED'
# Push-candidate ledger

## PC-SW-OPEN — LIVE, and its body quotes the strict annotation form INLINE

Filed because rotate archives only on `**ADOPTED UPSTREAM (v` while reverify skips on the loose form.

verify: theirs_has core/scripts/thing.sh "MARKER_A"

## PC-SW-CLOSED — genuinely closed, so the rotation has real work to do either way

<br>**ADOPTED UPSTREAM (v0.96.0, verified 2026-01-01).** Upstream took it.

verify: theirs_has core/scripts/thing.sh "MARKER_B"
SWLED

# `ledger_close_awk()` in lib.sh LIFTS the close grammar out of ledger-reverify.sh at run time,
# so a rotator copy needs its SIBLING beside it, not just lib.sh. Copy the .sh files and no more:
# a sandbox that mirrors the whole directory would keep working when the program grows a read of
# something else, and this fixture's job is to notice that.
cp "$(dirname "$ROT")"/*.sh "$SW/bin"/ 2>/dev/null
cp "$(dirname "$ROT")"/*.sh "$SW/mbin"/ 2>/dev/null
LIB="$(dirname "$ROT")/lib.sh"
# DROP THE LINE-LEADING ANCHOR from the DERIVED archive grammar. `_lar_head` holds it; the bold
# span and the token alternation are untouched, so this is one property and not a widening of
# the whole rule.
sed 's@^  _lar_head="${_lar_pat%%"$_lar_opt"\*}"$@  _lar_head=""@' "$LIB" > "$SW/mbin/lib.sh"

sw_rows() { # <rotator> <dir> -> writes "<before-rows>|<after-rows>|<before-has-open>|<after-has-open>"
  local rot="$1" d="$2" b a
  cp "$SW/led.md" "$d/push-candidate-ledger.md"
  rm -f "$d/push-candidate-ledger.archive.md"
  b="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$d/push-candidate-ledger.md" 2>/dev/null | rowset)"
  bash "$rot" "$d/push-candidate-ledger.md" --apply >/dev/null 2>&1
  a="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$d/push-candidate-ledger.md" 2>/dev/null | rowset)"
  printf '%s\n--\n%s\n' "$b" "$a" > "$d/rows.txt"
}

if cmp -s "$LIB" "$SW/mbin/lib.sh"; then
  bad "FIXTURE BROKEN — the line-anchor mutation matched nothing in lib.sh, so the sweep assertions below are unproven"
else
  sw_rows "$SW/bin/ledger-rotate.sh"  "$SW/ctl"
  sw_rows "$SW/mbin/ledger-rotate.sh" "$SW/mut"
  ctl_b="$(sed -n '1,/^--$/p' "$SW/ctl/rows.txt" | grep -v '^--$')"
  ctl_a="$(sed -n '/^--$/,$p'  "$SW/ctl/rows.txt" | grep -v '^--$')"
  mut_b="$(sed -n '1,/^--$/p' "$SW/mut/rows.txt" | grep -v '^--$')"
  mut_a="$(sed -n '/^--$/,$p'  "$SW/mut/rows.txt" | grep -v '^--$')"

  # THE UNMUTATED CONTROL, from the same sandbox, AND IT ASSERTS A POSITIVE OUTCOME. A copy that
  # dies sourcing lib.sh rotates nothing, so "the row set did not change" is exactly what a
  # program that never ran produces — the same trap `rg_refused()` further down avoids by
  # requiring the banner as well as the exit code. So the control requires the closed entry to
  # have REACHED the archive, which only a working rotator can do.
  if ! grep -q 'PC-SW-CLOSED' "$SW/ctl/push-candidate-ledger.archive.md" 2>/dev/null; then
    bad "FIXTURE BROKEN — the UNMUTATED rotator in the sandbox archived nothing, so it is not a working rotator and every comparison below is between two runs that did not happen"
  elif ! grep -q 'PC-SW-OPEN' <<<"$ctl_b"; then
    bad "FIXTURE BROKEN — the sweep seed's OPEN entry emits no row even before rotation, so its disappearance below could not be observed"
  elif [ "$ctl_b" != "$ctl_a" ]; then
    bad "FIXTURE BROKEN — the UNMUTATED rotator in the sandbox already changes the row set on this seed, so the mutant's verdict below is not attributable to the mutation"
  else
    ok "  CONTROL: the unmutated rotator in the sandbox archives the closed entry and leaves the row set alone"
  fi

  if [ "$mut_b" = "$mut_a" ]; then
    bad "  MUTATION: a rotator that archived a LIVE entry produced the SAME row set — the reshaped acceptance test cannot see a sweep, which is the one thing it exists to see"
  elif grep -q 'PC-SW-OPEN' <<<"$mut_a"; then
    bad "  MUTATION: the row set changed but the swept entry is still present, so the difference is not the sweep and this arm is measuring something else"
  else
    ok "  MUTATION: without the line-leading anchor the rotator archives the quoting LIVE entry, its row disappears, and the ROW-SET comparison FAILS — the reshaped test is not laxer about a sweep"
  fi
fi

# --- Assertion 4c: THE ONE-VS-MANY CROSSING, WHICH THE PC-S900 TRIO CANNOT REACH ----------
#
# THE SEQUENCE HAS THREE STATES AND THE ACCEPTANCE TEST COMPARES THE LAST TWO. Annotate-then-
# rotate walks a ledger through (1) pre-annotation, (2) annotated but not yet rotated, and
# (3) rotated. `flush()` in ledger-reverify.sh prints a row only `if (has_verify && !closed …)`,
# so an entry annotated `**ADOPTED UPSTREAM (v…)**` leaves `$ENTRIES` at step 2 and does not
# join `$ARCHIVE_LABELS` until step 3. Between those two it is in NEITHER set, and
# `prefix_entry_count()` counts the union of exactly those two — so the count DIPS at the
# annotate and RISES back at the rotate.
#
# THE PC-S900 TRIO ABOVE CANNOT SEE THAT, WHICH IS WHY THIS IS A SECOND SUBJECT AND NOT A
# SECOND ARM ON THE FIRST. PC-S900 has THREE members, two of them open, so its dip runs 3 -> 2
# and never leaves the `> 1` branch: only the NUMBER inside the detail moves, and assertion 4
# drops the detail column by design. PC-S910 has TWO members, one of them annotated, so the same
# dip runs 2 -> 1 and CROSSES the threshold that separates `named_ambiguous()` from
# `named_absorbed()`'s prefix fallback. The row then changes STATUS AND SUBJECT --
# `NAMED-UPSTREAM <full-slug>` becomes `NAMED-UPSTREAM-AMBIGUOUS <prefix>` -- which is exactly
# what assertion 4's projection KEEPS, and exactly what SKILL.md's acceptance test tells the
# operator means a live entry was swept.
#
# NOTHING IS SWEPT HERE, AND THE ARM ESTABLISHES THAT SEPARATELY RATHER THAN ASSUMING IT. The
# rotation control below requires the annotated sibling to have REACHED the archive and the
# survivor to still be IN the live ledger, so a row-set difference here cannot be explained by
# a lost entry.
#
# THE ARM IS WRITTEN AGAINST THE OBSERVABLE, NOT AGAINST ANY LINE OF THE COUNTER. What must hold
# is a property of the REPORT: the row set at step 2 and the row set at step 3 are the same, by
# status and subject. Any implementation that makes an annotated-but-unrotated entry countable
# satisfies it, and no spelling of that fix is named in the assertion.
XC="$WORK/crossing"; rm -rf "$XC"; mkdir -p "$XC/led" "$XC/mled" "$XC/bin" "$XC/cbin"
TAB="$(printf '\t')"

# The two ledgers differ in ONE LINE -- the annotation -- and that is asserted below rather than
# eyeballed, because a differential whose sides do not differ reads as "no change".
xc_write() { # <path> <2 to annotate the sibling, anything else not to>
  cat > "$1" <<'XCL'
# Push-candidate ledger

## PC-S910-ALPHA — open throughout, and the SURVIVOR whose row flips

verify: theirs_has core/scripts/thing.sh "MARKER_A"

## PC-S910-BETA — the sibling: open at state 1, annotated at state 2, archived at state 3

verify: theirs_has core/scripts/thing.sh "MARKER_B"
XCL
  [ "$2" = 2 ] || return 0
  cat > "$1" <<'XCL'
# Push-candidate ledger

## PC-S910-ALPHA — open throughout, and the SURVIVOR whose row flips

verify: theirs_has core/scripts/thing.sh "MARKER_A"

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
  bad "ACCEPTANCE TEST FALSE-FAILS: rotating an annotated-but-unrotated sibling changed the ROW SET while nothing was swept. The prefix count dipped to 1 at the annotate and returned at the rotate, so the survivor's row crossed between named_absorbed()'s single attribution and named_ambiguous(). An operator following SKILL.md reads this as a swept live entry and unwinds correct work"
  diff <(printf '%s\n' "$xc_r2") <(printf '%s\n' "$xc_r3") | sed 's/^/      /' | head -8
fi

# --- MUTATION: REVERT prefix_entry_count() TO ITS TWO-SOURCE BODY -------------------------
#
# ANCHORED ON THE FUNCTION, NOT ON A LIST OF LINES. The property above is satisfied by counting
# live-but-skipped entries somewhere, and where that lands inside `prefix_entry_count()` is the
# implementer's choice; a `sed` naming one of its lines goes vacuous the moment the fix is
# respelled and nothing announces it. So the WHOLE function is replaced by the two-source union
# it had before -- open `$ENTRIES` labels and `$ARCHIVE_LABELS`, nothing else -- which reverts
# every layer of any fix living inside it.
#
# AND THE REVERT IS PROVED TO BITE, WHICH `cmp -s` CANNOT DO. A mutation that applies cleanly and
# removes no property is the failure mode `cmp` is blind to, and here it has a specific meaning:
# if the mutant and the shipping copy agree on state 2, the counter has no live-but-skipped
# source to remove and the arm above is red for the subject's own reason. That is asserted
# before either verdict below is read.
cp "$(dirname "$RV")"/*.sh "$XC/bin"/  2>/dev/null
cp "$(dirname "$RV")"/*.sh "$XC/cbin"/ 2>/dev/null
cat > "$XC/prefix-body.sh" <<'XCB'
prefix_entry_count() { # MUTANT BODY: open entries UNION archive labels, and nothing else
  { printf '%s\n' "$ENTRIES" | awk -F'\t' 'NF{print $1}'
    printf '%s\n' "${ARCHIVE_LABELS:-}"
  } | sort -u | grep -cE "^$1-" 2>/dev/null || true
}
XCB
awk -v BODY="$XC/prefix-body.sh" '
  /^prefix_entry_count\(\) \{/ { inf=1; while ((getline l < BODY) > 0) print l; close(BODY); next }
  inf && /^\}[[:space:]]*$/    { inf=0; next }
  inf                          { next }
  { print }
' "$RV" > "$XC/bin/ledger-reverify.sh"

if cmp -s "$RV" "$XC/bin/ledger-reverify.sh"; then
  bad "FIXTURE BROKEN — the prefix_entry_count() replacement DID NOT APPLY: the function header was not found, so the mutation below is a no-op and the arm above is unproven"
elif [ "$(grep -c '^prefix_entry_count() {' "$XC/bin/ledger-reverify.sh")" -ne 1 ]; then
  bad "FIXTURE BROKEN — the mutated copy carries $(grep -c '^prefix_entry_count() {' "$XC/bin/ledger-reverify.sh") definitions of prefix_entry_count(), expected exactly 1; a duplicated or deleted definition makes any verdict below unattributable"
else
  xc_walk "$XC/cbin/ledger-reverify.sh" "$XC/mled"   # unmutated control, same sandbox
  xc_c2="$(rowset < "$XC/mled/v2")"; xc_c3="$(rowset < "$XC/mled/v3")"
  xc_walk "$XC/bin/ledger-reverify.sh"  "$XC/mled"
  xc_m1="$(cat "$XC/mled/v1")"; xc_m2="$(cat "$XC/mled/v2")"; xc_m3="$(cat "$XC/mled/v3")"
  xc_mr2="$(rowset <<<"$xc_m2")"; xc_mr3="$(rowset <<<"$xc_m3")"

  # THE UNMUTATED CONTROL ASSERTS FIDELITY, NOT THE PROPERTY. Restating the property here would
  # make this arm a second copy of the one above -- two cells moving on one subject, which is the
  # entanglement the mutant rules name. What the control owes is that the sandbox copy answers the
  # same as the shipping run, so a difference below belongs to the mutation and not to the copy.
  # THE POSITIVE CONJUNCT IS SEPARATE AND COMES FIRST: a copy that dies sourcing lib.sh emits
  # nothing, and two empty outputs are equal, so equality alone would score silence as fidelity.
  if ! grep -q "^NAMED-UPSTREAM-AMBIGUOUS${TAB}PC-S910${TAB}" "$XC/mled/v1"; then
    bad "  FIXTURE BROKEN — the UNMUTATED reverify copy in the sandbox emits no AMBIGUOUS row even at state 1, so it is not a working classifier and the mutant's verdict is not attributable"
  elif [ "$xc_c2" != "$xc_r2" ] || [ "$xc_c3" != "$xc_r3" ]; then
    bad "  FIXTURE BROKEN — the UNMUTATED copy in the sandbox does not reproduce the shipping run's row sets, so the mutant's difference below is not attributable to the mutation"
  else
    ok "  CONTROL: an unmutated reverify copy in the sandbox emits the AMBIGUOUS row and reproduces the shipping run's row sets at both compared states"
  fi

  if [ "$xc_mr2" = "$xc_c2" ]; then
    bad "  MUTATION DID NOT BITE — reverting prefix_entry_count() to open-UNION-archive changed no verdict at state 2. Either the fix that makes an annotated-but-unrotated entry countable is not in this tree, or it lives outside prefix_entry_count() and this revert does not reach it"
  elif ! grep -q "^STILL-LIVE${TAB}PC-S910-ALPHA${TAB}" <<<"$xc_m3"; then
    bad "  MUTATION: the mutated copy stops classifying the survivor altogether, so it is a broken classifier and its row-set difference is not attributable to the counter"
  elif [ "$xc_mr2" = "$xc_mr3" ]; then
    bad "  MUTATION: with the live-but-skipped source removed the row set STILL matched across the rotation, so the arm above is not measuring what keeps it stable"
  elif grep -q "^NAMED-UPSTREAM${TAB}PC-S910-ALPHA${TAB}" <<<"$xc_m2" \
    && grep -q "^NAMED-UPSTREAM-AMBIGUOUS${TAB}PC-S910${TAB}" <<<"$xc_m3"; then
    ok "  MUTATION: with prefix_entry_count() back to open-UNION-archive the survivor's row flips NAMED-UPSTREAM -> NAMED-UPSTREAM-AMBIGUOUS across --apply and the arm above fires — it is bound to the count's live-but-skipped source"
  else
    bad "  MUTATION: the row set changed but not into the reported flip, so this arm is measuring some other difference"
  fi
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
#
# THE SANDBOX CARRIES WHAT THE PROGRAM READS, AND THAT SET GREW. `lib.sh`'s `ledger_close_awk()`
# LIFTS the close grammar out of `${SELF}/ledger-reverify.sh` at run time rather than restating
# it, so a rotator copy now reads a SIBLING and a dir holding only `lib.sh` dies before it
# rotates anything. The unmutated control below is what caught that — it started reporting
# FIXTURE BROKEN the moment the dependency landed, which is the arm working, not noise.
#
# NAMED FILES, NOT THE WHOLE DIRECTORY. Mirroring `$(dirname "$ROT")` wholesale would keep this
# sandbox green through the NEXT new read too, and the loud failure is the only thing that
# reports one.
MUTD="$WORK/mut-noop"; mkdir -p "$MUTD"
cp "$(dirname "$ROT")/lib.sh" "$MUTD/lib.sh" 2>/dev/null
cp "$(dirname "$ROT")/ledger-reverify.sh" "$MUTD/ledger-reverify.sh" 2>/dev/null
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

# MUTATION — DROP THE LINE-LEADING ANCHOR from the derived archive grammar. PC-Q2 must come
# back, and PC-Q1 must not stop moving, or the mutant is testing whether the arm RUNS rather
# than what it matches.
#
# RE-ANCHORED: this used to delete the version DIGIT from a literal in `ledger-rotate.sh`. That
# literal is gone — the grammar is derived in `lib.sh` — and the sed matched nothing while
# scoring a kill. The subject is `_lar_head`, the line-leading prefix the derivation carries
# across from the skip rule; emptying it leaves the bold span and the token set untouched, so
# the mutant changes exactly one property. The mutation is in `lib.sh`, which every copy in the
# directory sources, so the unmutated control lives in its OWN directory.
MUTQ="$WORK/rot-mutant"; rm -rf "$MUTQ"; mkdir -p "$MUTQ"
cp "$(dirname "$ROT")"/*.sh "$MUTQ"/ 2>/dev/null
sed 's@^  _lar_head="${_lar_pat%%"$_lar_opt"\*}"$@  _lar_head=""@' "$LIB" > "$MUTQ/lib.sh"
CTLQ="$WORK/rot-control"; rm -rf "$CTLQ"; mkdir -p "$CTLQ"
cp "$(dirname "$ROT")"/*.sh "$CTLQ"/ 2>/dev/null
if cmp -s "$LIB" "$MUTQ/lib.sh"; then
  bad "  FIXTURE ERROR: the line-anchor mutation matched nothing in lib.sh, so the assertions above are unproven"
else
  # THE UNMUTATED CONTROL RUNS FROM THE SAME KIND OF SANDBOX AND ASSERTS A POSITIVE OUTCOME. A
  # copy that dies sourcing lib.sh archives nothing, and "PC-Q2 did not move" is exactly what a
  # program that never ran produces.
  c_out="$(bash "$CTLQ/ledger-rotate.sh" "$Q" --archive "$WORK/ctl-archive.md" 2>&1)"
  c_moved="$(awk '/closed entries would move/{on=1;next} /^  archive:/{on=0} on' <<<"$c_out")"
  m_out="$(bash "$MUTQ/ledger-rotate.sh" "$Q" --archive "$WORK/mut-archive.md" 2>&1)"
  m_moved="$(awk '/closed entries would move/{on=1;next} /^  archive:/{on=0} on' <<<"$m_out")"
  if ! grep -q 'PC-Q1' <<<"$c_moved" || grep -q 'PC-Q2' <<<"$c_moved"; then
    bad "  FIXTURE BROKEN: the UNMUTATED copy in a sandbox does not reproduce the shipped verdict (Q1 moves, Q2 does not), so the mutant's verdict is not attributable to the mutation"
  else
    ok "  mutation control: an unmutated copy in its own sandbox archives PC-Q1 and leaves PC-Q2 alone"
  fi
  if ! grep -q 'PC-Q1' <<<"$m_moved"; then
    bad "  MUTATION: the unmutated-control entry stopped moving under the mutant, so the copy is broken and its verdict is not attributable"
  elif grep -q 'PC-Q2' <<<"$m_moved"; then
    ok "  MUTATION: without the line-leading anchor the quoting entry is archived again — the anchor is what stands between a live entry and the archive"
  else
    bad "  MUTATION: removing the line anchor did NOT re-archive the quoting entry, so these assertions are not measuring the anchor"
  fi
fi

# --- MUTATION: MAKE THE PROMOTED BOLD SPAN OPTIONAL AGAIN ----------------------------------
# THE OTHER HALF OF THE DERIVATION, AND IT HAS A SUBJECT THE ANCHOR MUTANT CANNOT REACH.
# `ledger_archive_awk()` is one transform — take reverify's grammar and make its OPTIONAL bold
# span MANDATORY — so there are exactly two properties to break and each needs its own mutant.
# The anchor mutant above reaches PC-Q2 (mid-line) and not PC-Q6 (line-leading, no bold); this
# one reaches PC-Q6 and not PC-Q2. Measured both ways before shipping: neither mutant moves the
# other's subject, so neither is covered by the other and a third is not needed.
MUTB="$WORK/rot-mutant-bold"; rm -rf "$MUTB"; mkdir -p "$MUTB"
cp "$(dirname "$ROT")"/*.sh "$MUTB"/ 2>/dev/null
sed "s@^  _lar_req='\\\\\\*\\\\\\*\\[^\`\\]\\*'\$@  _lar_req='(\\\\*\\\\*[^\`]*)?'@" "$LIB" > "$MUTB/lib.sh"
if cmp -s "$LIB" "$MUTB/lib.sh"; then
  bad "  FIXTURE ERROR: the mandatory-bold-span mutation matched nothing in lib.sh, so the narrative arm above is unproven"
else
  b_out="$(bash "$MUTB/ledger-rotate.sh" "$Q" --archive "$WORK/mutb-archive.md" 2>&1)"
  b_moved="$(awk '/closed entries would move/{on=1;next} /^  archive:/{on=0} on' <<<"$b_out")"
  if ! grep -q 'PC-Q1' <<<"$b_moved"; then
    bad "  MUTATION bold-span: the unmutated-control entry stopped moving, so the copy is broken and its verdict is not attributable"
  elif ! grep -q 'PC-Q6' <<<"$b_moved"; then
    bad "  MUTATION bold-span: with the span optional again the NARRATED token was still not archived, so the narrative arm above is not measuring the span"
  elif grep -q 'PC-Q2' <<<"$b_moved"; then
    bad "  MUTATION bold-span: it also archived the MID-LINE quotation, so it is not a clean mutation of the span alone and it overlaps the anchor mutant"
  else
    ok "  MUTATION bold-span: with the span optional the line-leading NARRATIVE is archived as live work, and the mid-line quotation is not — one property, its own subject"
  fi
  if grep -q 'PC-Q5' <<<"$b_moved"; then
    ok "  MUTATION bold-span: and the no-bold CLOSE leaves the stuck list by being archived — the span is what puts it there"
  else
    bad "  MUTATION bold-span: the no-bold close still did not archive, so the stuck arm above is not keyed on the span either"
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

# (5) An entry that merely QUOTES the annotation form. The strict close test already refuses to
# archive on a quotation (PC-S331 above); the refusal guard must not read one as a close either.
rg_write fp-quotes '- **A real entry that QUOTES the annotation form** in its own body

  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero.

  verify: theirs_has core/scripts/thing.sh "MARKER_A"
'
fp_check fp-quotes "SUBJECT DEFECT" "an entry that merely QUOTES the annotation form still rotates"

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
# `if (0) return "bullet"` is the remedy `ledger-entry-boundary-measurement.md`
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
# RE-ANCHORED when the shape rule became fence-aware: the bullet branch is now an assignment
# (`if (…) sh = "bullet"`) rather than a bare `return`. Same location, same observable.
sed 's@if (l ~ /\^- \\\*\\\*/) *sh = "bullet"@if (0) sh = "bullet"@' \
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

# --- MUTATION: MAKE THE BOUNDARY RULE FENCE-BLIND AGAIN ---------------------------------------
# THE SUBJECT OF PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS, rotate side.
# `ledger_entry_shape()` in lib.sh ignores a non-id entry-shaped line inside a fence. Blinding
# it to the fence -- `if (0)` on the in-fence branch -- opens an entry on the fenced
# `## <ts> -- EVENT` line, so the closed entry's HEAD (heading + opening fence, no annotation
# yet) stays live with an unterminated fence while its TAIL (closer, annotation) archives under
# the timestamp label. That is the residue the reference consumer's live ledger carries today.
# The open entry after it is the control: it must stay live under both copies, or the mutant
# broke the parser rather than the fence.
FM="$WORK/fence-blind"; rm -rf "$FM"; mkdir -p "$FM"
cat > "$FM/led.md" <<'FMLED'
# Push-candidate ledger

## PC-FM-CLOSED-FENCED — closed, and its fence records a heading-shaped output line

```derived
$ grep '^## ' pipeline-continuation-log.md | head -1
## 2000-01-01T00:00:00Z -- FM-EVENT
```

<br>**ADOPTED UPSTREAM (v0.101.0, verified 2026-01-01).** Upstream took it.

## PC-FM-OPEN — open, the control that must stay live under both copies

verify: theirs_has core/scripts/thing.sh "MARKER_A"
FMLED

cp "$(dirname "$ROT")"/*.sh "$FM"/ 2>/dev/null
sed 's@if (__lef_in && sh != "") {@if (0) {@' "$(dirname "$ROT")/lib.sh" > "$FM/lib.sh"
FMC="$WORK/fence-blind-control"; rm -rf "$FMC"; mkdir -p "$FMC"
cp "$(dirname "$ROT")"/*.sh "$FMC"/ 2>/dev/null

fm_run() { # <dir> -> rotates a fresh copy of the seed with that dir's rotator
  local d="$1"
  rm -f "$d/arc.md"; cp "$FM/led.md" "$d/run.md"
  bash "$d/ledger-rotate.sh" "$d/run.md" --archive "$d/arc.md" --apply >/dev/null 2>&1
}
fm_run "$FMC"; fm_run "$FM"

if cmp -s "$(dirname "$ROT")/lib.sh" "$FM/lib.sh"; then
  bad "FIXTURE BROKEN — the fence-blind mutation matched nothing in lib.sh, so the fenced-entry arm above is unproven"
elif ! grep -q 'PC-FM-CLOSED-FENCED' "$FMC/arc.md" 2>/dev/null || grep -q 'FM-EVENT' "$FMC/run.md" || ! grep -q 'PC-FM-OPEN' "$FMC/run.md"; then
  bad "FIXTURE BROKEN — the UNMUTATED copy did not rotate the fenced closed entry whole (or lost the open control), so the mutant's verdict is not attributable"
elif ! grep -q 'PC-FM-CLOSED-FENCED' "$FM/run.md"; then
  bad "  MUTATION: with the boundary rule fence-blind the closed entry STILL rotated whole — the fenced-entry arm above is vacuous"
elif ! grep -q 'PC-FM-OPEN' "$FM/run.md"; then
  bad "  MUTATION: the open control was ALSO rotated out, so the mutant broke the parser outright and the kill is not attributable to fence tracking"
else
  ok "  MUTATION: fence-blind, the closed entry's head is stranded live with an unterminated fence while its tail archives under the timestamp label, and the open control survives — the fence-aware boundary is load-bearing"
fi

# --- MUTATION: DELETE THE ARCHIVE ARM OF prefix_entry_count() -----------------------------
#
# WHY THIS GUARD LIVES IN THE ROTATE FIXTURE AND NOT IN `ledger-reverify`. The arm being guarded
# is one line inside `prefix_entry_count()`: the sprint prefix is counted over the OPEN entries
# UNIONED with the ARCHIVED labels. Its whole purpose is to survive a ROTATION — an archived
# sibling must keep counting, so that moving it cannot make a shared prefix look unique. That
# harm therefore needs an archive file holding a sibling, which is a state only a rotation
# produces, and this is the only fixture that rotates. `core/fixtures/ledger-reverify` passes
# 88/88 with the line present and 88/88 with it deleted, because its own ambiguity pair is two
# LIVE entries and its seed writes no archive at all; giving it one would mean teaching that
# fixture to rotate, which is this fixture.
#
# THE HARM IS NOT A CHANGED NUMBER, IT IS A CHANGED VERDICT, and the seed is built to show that
# rather than a count. Two entries share PC-S901; one is closed and rotates. With the archive arm
# the prefix still names 2 entries, so the survivor stays NAMED-UPSTREAM-AMBIGUOUS — "upstream
# cites this prefix, more than one entry carries it, read the commit and decide". Without it the
# prefix names 1, `named_absorbed()`'s fallback fires, and the operator is told upstream absorbed
# THIS entry, by name, on a commit that says no such thing. A confidently wrong single attribution
# is worse than the silence it replaces, which is why the arm exists.
#
# NOTE THE ROW-SET ARM ABOVE CANNOT COVER THIS. The count it moves lives in the DETAIL column,
# which that arm drops by design; only when the count crosses 1 does a STATUS change. Two
# assertions, two subjects.
PC="$WORK/prefix-counter"; rm -rf "$PC"; mkdir -p "$PC/led" "$PC/ctl" "$PC/mut"
cat > "$PC/led/push-candidate-ledger.md" <<'PCLED'
# Push-candidate ledger

## PC-S901-ALPHA — open, and the only LIVE member of its prefix once the sibling is archived

verify: theirs_has core/scripts/thing.sh "MARKER_A"

## PC-S901-BETA — closed and archivable: the sibling the rotation moves

<br>**ADOPTED UPSTREAM (v0.95.0, verified 2026-01-01).** Upstream took it.

verify: theirs_has core/scripts/thing.sh "MARKER_B"
PCLED
bash "$ROT" "$PC/led/push-candidate-ledger.md" --apply >/dev/null 2>&1

cp "$(dirname "$RV")"/*.sh "$PC/ctl"/ 2>/dev/null
cp "$(dirname "$RV")"/*.sh "$PC/mut"/ 2>/dev/null
# ONE LINE, REPLACED BY A NO-OP RATHER THAN DELETED, so the brace group it sits in still parses
# and the mutant is a working classifier whose ONLY difference is the archive side of the union.
sed 's@^\( *\)printf .*ARCHIVE_LABELS.*@\1:@' "$RV" > "$PC/mut/ledger-reverify.sh"
pc_rows() { bash "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" "$PC/led/push-candidate-ledger.md" 2>/dev/null; }

pc_ndiff="$(diff "$RV" "$PC/mut/ledger-reverify.sh" | grep -c '^[<>]' || true)"
if [ ! -s "$PC/led/push-candidate-ledger.archive.md" ] || grep -q 'PC-S901-BETA' "$PC/led/push-candidate-ledger.md"; then
  bad "FIXTURE BROKEN — the PC-S901 sibling did not reach the archive, so the counter guard below has no archived label to count and would pass for the wrong reason"
elif cmp -s "$RV" "$PC/mut/ledger-reverify.sh"; then
  bad "FIXTURE BROKEN — the prefix_entry_count mutation matched nothing, so the counter assertions below are unproven"
elif [ "$pc_ndiff" -ne 2 ]; then
  bad "FIXTURE BROKEN — the prefix_entry_count mutation changed $((pc_ndiff / 2)) lines, expected exactly 1; a wider mutation makes any kill unattributable"
else
  pc_ctl="$(pc_rows "$PC/ctl/ledger-reverify.sh")"
  pc_mut="$(pc_rows "$PC/mut/ledger-reverify.sh")"
  # THE CONTROL, TWICE OVER. An unmutated copy in the sandbox must reproduce the real answer, and
  # the mutant must still be a working classifier — both arms below are ABSENCE-shaped on the
  # mutant side, and a copy that died sourcing lib.sh emits nothing, which satisfies an absence.
  if ! grep -q 'NAMED-UPSTREAM-AMBIGUOUS' <<<"$pc_ctl" || ! grep -q 'PC-S901' <<<"$pc_ctl"; then
    bad "FIXTURE BROKEN — an UNMUTATED reverify copy does not report PC-S901 as ambiguous after the rotation, so the mutant's silence below is not attributable to the deleted arm"
  elif ! grep -q 'STILL-LIVE' <<<"$pc_mut" || ! grep -q 'PC-S901-ALPHA' <<<"$pc_mut"; then
    bad "  MUTATION: the mutated copy emits no verdict for the surviving entry at all, so it is a broken classifier and its silence is not a kill"
  elif grep -q 'NAMED-UPSTREAM-AMBIGUOUS' <<<"$pc_mut"; then
    bad "  MUTATION: PC-S901 is still reported AMBIGUOUS with the archive arm of prefix_entry_count() deleted — nothing in this repo notices that deletion, and the archived sibling is not what keeps the prefix shared"
  elif grep -q 'NAMED-UPSTREAM	PC-S901-ALPHA' <<<"$pc_mut"; then
    ok "  MUTATION: deleting the archive arm of prefix_entry_count() turns the correct AMBIGUOUS row into a confident NAMED-UPSTREAM attribution of PC-S901-ALPHA — the arm is load-bearing across a rotation"
  else
    bad "  MUTATION: the AMBIGUOUS row vanished but no single attribution replaced it, so the mutant changed the count in some other way and this arm is not measuring the union's archive side"
  fi
  # AND THE CORRECT ANSWER IS ASSERTED POSITIVELY, not merely as the mutant's opposite: the
  # survivor must NOT be attributed to a commit that names only the prefix.
  if grep -q 'NAMED-UPSTREAM	PC-S901-ALPHA' <<<"$pc_ctl"; then
    bad "  the shipping reverify attributes PC-S901-ALPHA to upstream by NAME after its sibling was archived — that is the anti-monotonic count the archive arm exists to prevent"
  else
    ok "  and the shipping reverify makes no single attribution for the surviving entry, which is the verdict the archive arm buys"
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

# THE UNMUTATED CONTROL FIRST, AND IT IS PRESENCE-SHAPED. A sandbox copy that cannot run emits
# nothing, and "no archive rule" is satisfied by silence — so the control must show the shipped
# verdict, not merely a zero exit.
dv_ctl="$(dv_run ctl)"; dv_ctl_rc=$?
if [ "$dv_ctl_rc" -eq 0 ] && grep -q 'PC-DV-CLOSED' <<<"$dv_ctl" && ! grep -q 'PC-DV-OPEN' <<<"$dv_ctl"; then
  ok "CONTROL: an unmutated copy in the sandbox derives its grammar and archives the closed entry only (rc=$dv_ctl_rc)"
else
  bad "FIXTURE BROKEN — the unmutated sandbox copy did not reproduce the shipped verdict (rc=$dv_ctl_rc), so the two verdicts below are not attributable"
fi

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
# Written one line down in the BODY, the body-side loose rule reports it and the arm passes with
# the entry-line flags deleted -- measured exactly that way here, as the mutant below surviving.
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

# --- MUTANT: restore the defect by reverting ONLY the boundary-line flag setting -----------
# Both added lines are reverted together. Reverting one leaves the other proving its own half,
# and the arm comes back green on a subject that is still half broken -- the layered-fix trap.
BLM="$WORK/blmut"; rm -rf "$BLM"; mkdir -p "$BLM"
cp "$(dirname "$ROT")"/*.sh "$BLM/" 2>/dev/null || true

cp "$ROT" "$BLM/ledger-rotate.sh"
bl_ctl="$(bash "$BLM/ledger-rotate.sh" "$BLW/onboundary.md" --archive "$BLM/arch.md" 2>&1 | grep -c 'would move')"
if [ "$bl_ctl" -eq 1 ]; then
  ok "  mutation control: an unmutated copy still archives the boundary-line close"
else
  bad "  mutation control: the unmutated copy archived nothing — a copy that cannot run scores as a kill below"
fi

# BOTH ADDED LINES ARE COUNTED AND BOTH MUST GO. This mutation is a two-layer revert and the
# `cmp -s` guard cannot see a PARTIAL one -- deleting either line alone changes the file, so
# `cmp` reports a mutation and the arm scores a kill for the layer that is still reverted while
# the other half sits unproven. Caught exactly that way here: the loose line was rewritten from
# `ledger_body_closes` to `ledger_entry_line_closes` and the mutation's second pattern silently
# stopped matching. So the deletions are COUNTED, and a count other than 2 is a broken mutation.
#
# AND IT HAPPENED AGAIN, IN THE OTHER PATTERN, WHICH IS WHY NEITHER SPELLS A GRAMMAR NOW. The
# archive line was rewritten from the literal `$0 ~ /\*\*ADOPTED UPSTREAM \(v[0-9]/` to the
# derived call `ledger_entry_line_archives($0)`, and this pattern went from matching one line to
# matching zero while the OTHER still matched -- exactly the partial revert this count exists to
# catch, reported as `reverted 1 of 2`. Both patterns are now keyed on the CALL each line makes
# and on nothing about the grammar behind it, which is the property that actually distinguishes
# these two lines from everything else in the file.
bl_deleted="$(awk '/if \(ledger_entry_line_archives\(\$0\)\) closed = 1/ { n++; next }
     /if \(ledger_entry_line_closes\(\$0\)\) loose = 1/ { n++; next }
     { print > "/dev/stderr" }
     END { print n+0 }' "$ROT" 2>"$BLM/ledger-rotate.sh")"
if [ "$bl_deleted" -ne 2 ]; then
  bad "  mutation boundary-flags: reverted $bl_deleted of 2 added lines — a partial revert proves only the layer it left in place"
elif cmp -s "$ROT" "$BLM/ledger-rotate.sh"; then
  bad "  mutation boundary-flags: the mutation matched nothing, so the boundary-line assertions are unproven"
else
  m_on="$(bash "$BLM/ledger-rotate.sh" "$BLW/onboundary.md" --archive "$BLM/arch.md" 2>&1 | grep -c 'would move')"
  m_in="$(bash "$BLM/ledger-rotate.sh" "$BLW/inbody.md"     --archive "$BLM/arch.md" 2>&1 | grep -c 'would move')"
  m_ls="$(bash "$BLM/ledger-rotate.sh" "$BLW/nobold.md"     --archive "$BLM/arch.md" 2>&1 | grep -c 'NOT archivable')"
  if [ "$m_on" -eq 0 ]; then
    ok "  mutation boundary-flags: without them the boundary-line close goes unseen again (the arm can fire)"
  else
    bad "  mutation boundary-flags: the mutant still archived the boundary-line close, so the arm above proves nothing"
  fi
  if [ "$m_ls" -eq 0 ]; then
    ok "  mutation boundary-flags: and the NO-BOLD boundary close stops being reported — the loose half is load-bearing too"
  else
    bad "  mutation boundary-flags: the no-bold case was still reported under the mutant, so the loose half proves nothing"
  fi
  if [ "$m_in" -eq 1 ]; then
    ok "  mutation boundary-flags: and the BODY case survives the mutant — the two paths are not entangled"
  else
    bad "  mutation boundary-flags: the mutant also killed the body case, so it is testing whether the script RUNS, not the boundary rule"
  fi
fi
rm -rf "$BLM" "$BLW"

echo
if [ "$fails" -eq 0 ]; then
  echo "ledger-rotate: PASS"
else
  echo "ledger-rotate: FAIL ($fails)" >&2; exit 1
fi
