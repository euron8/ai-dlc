#!/usr/bin/env bash
# Exercise reconcile/ledger-reverify.sh against the ledger-reverify fixture.
#
# THE DIFFERENTIAL. Entry A and Entry B carry identical verify directives except the
# substring; they classify differently ONLY because `theirs` contains MARKER_B and not
# MARKER_A. A closer that probes `base` instead of `theirs` sees neither marker and calls
# both STILL-LIVE — so Entry B's CLOSE-CANDIDATE assertion below goes red. That is the
# mutation proof baked into the pair: the fixture cannot pass a closer that ignores theirs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# Locate the detector in BOTH layouts. Distribution: fixtures at core/fixtures/<name>/,
# detector at core/skills/…. Consumer: install.sh relocates fixtures to tests/fixtures/<name>/
# and the detector to .claude/skills/… — three levels up from the fixture, NOT two. The
# consumer candidate was `../../.claude` (two up → tests/.claude/, which does not exist), so
# every relocated-fixture consumer aborted `cannot locate` and blocked its pre-push suite,
# while the distribution stayed green on the first candidate. Test it as a CONSUMER, not only
# where core/ sits two up.
CLOSER=""
LOOKED=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && CLOSER="$cand" && break
done
[ -n "$CLOSER" ] || { printf 'FAIL: cannot locate ledger-reverify.sh from %s. Looked in:\n%s' "$DIR" "$LOOKED"; exit 1; }

read -r DIST BASE CONS THEIRS < <(bash "$DIR/seed.sh")
trap 'rm -rf "$(dirname "$DIST")"' EXIT

OUT="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"

FAILURES=0
ASSERTIONS=0

# $1 label-substring  $2 expected STATUS (or "ABSENT")  $3 why
row_is() {
  local label="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" '$2 ~ l {print $1; exit}')"
  if [ "$want" = "ABSENT" ]; then
    if [ -z "$got" ]; then
      printf '  ok    %-22s no row  (%s)\n' "$label" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-22s got=%s want=no-row  (%s)\n' "$label" "$got" "$why"
    fi
  elif [ "$got" = "$want" ]; then
    printf '  ok    %-22s %s  (%s)\n' "$label" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s got=%s want=%s  (%s)\n' "$label" "${got:-<none>}" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  fi
}

# NAMED-UPSTREAM is an ADDITIONAL row, so an entry can now carry two. row_is() reports the
# FIRST row for a label and is therefore the wrong instrument for a pair — it would silently
# assert on whichever happened to print first. These two ask whether a specific (label, status)
# pair is present or absent, independently of any other row the entry has.
# $1 label-substring  $2 STATUS  $3 why
row_has() {
  local label="$1" want="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$want" '$2 ~ l && $1 == s {f=1} END{exit !f}'; then
    printf '  ok    %-22s %s present  (%s)\n' "$label" "$want" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s %s MISSING  (%s)\n' "$label" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  fi
}
row_lacks() {
  local label="$1" bad="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$bad" '$2 ~ l && $1 == s {f=1} END{exit !f}'; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s %s present but must not be  (%s)\n' "$label" "$bad" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  else
    printf '  ok    %-22s no %s  (%s)\n' "$label" "$bad" "$why"
  fi
}

echo "ledger-reverify fixture"
echo

row_is "Entry A" STILL-LIVE      "theirs still lacks MARKER_A -> entry stays open"
row_is "Entry B" CLOSE-CANDIDATE "theirs now has MARKER_B -> upstream absorbed it"
row_is "Entry C" ABSENT          "already ADOPTED UPSTREAM -> closed, not re-emitted"
row_is "Entry D" ABSENT          "no verify: line -> hand-review, no row"

# THE THIRD DIFFERENTIAL — a declared manual entry vs a malformed one. Both used to land on
# NEEDS-REVIEW, so a deliberate "no mechanical predicate exists" declaration was reported in
# the same breath as a typo, and draining the bucket meant re-reading entries that had already
# said they need no machine check.
row_is "Entry E" HAND-REVIEW     "verify: manual is a declaration, not a malformed line"
row_is "Entry F" HAND-REVIEW     "trailing backtick on the verb is a formatting slip, not a different verb"

# THE FOURTH DIFFERENTIAL — path namespace. G carries Entry B's claim verbatim but filed in
# the consumer install layout. Before the basename fallback it reported NEEDS-REVIEW: the
# substring was never compared, so the closer said nothing about a claim upstream had already
# absorbed. G and B must agree; that they can disagree at all is the defect.
row_is "Entry G" CLOSE-CANDIDATE "consumer-namespace path resolves by basename -> same verdict as Entry B"

# ...and the fallback must REFUSE to guess. H's basename matches two files at theirs, I's
# matches none. A fallback that picked the first match would classify H on the wrong file
# while reading exactly like a correct verdict.
row_is "Entry H" NEEDS-REVIEW    "ambiguous basename (2 matches) -> refuse to guess"
row_is "Entry I" NEEDS-REVIEW    "basename matches nothing at theirs -> nothing to fall back to"

# THE FIFTH DIFFERENTIAL — a close nothing upstream produced. J and K classify CLOSE-CANDIDATE
# on the theirs-side test alone, but neither predicate's STILL-LIVE side was ever reachable:
# J's substring is absent at base AND theirs, K's is present at both. A closer that tests only
# theirs emits a confident close for a claim no upstream change touched, and a drain acts on
# it. Six entries on the reference consumer had exactly this shape, every one a live defect.
row_is "Entry J" NEEDS-REVIEW    "theirs_has on a substring absent at base too -> vacuous, not absorbed"
row_is "Entry K" NEEDS-REVIEW    "theirs_lacks on a substring present at base too -> vacuous, not absorbed"

# THE SIXTH DIFFERENTIAL — more than one substring in a directive. Joined into a single
# literal (quotes included) the pattern matches nothing, so BOTH L and M report "still
# lacks" and only L is right. M is the damage: theirs carries both markers, and the entry
# would sit open forever against an upstream that had already absorbed it. Matching each
# substring separately is what makes the pair disagree, which is what makes the test real.
row_is "Entry L" STILL-LIVE      "two substrings, neither at theirs -> genuinely still live"
# --- the `sh` verb: a MISSING SUBJECT is not a fix -----------------------------
# Three outcomes, because two would let a verb that always reports one thing pass.
row_is "Entry SH-MOVED" NEEDS-REVIEW "exit 127 = subject renamed/deleted, NOT absorbed. A close here records an absorption that never happened, and closing is the direction that loses information permanently"
row_is "Entry SH-REAL"  CLOSE-CANDIDATE "OVER-FIRE CONTROL: a plain non-zero exit still closes, or the guard pins every sh entry open forever"
row_is "Entry SH-LIVE"  STILL-LIVE "exit 0 still means it reproduces"

row_is "Entry M" CLOSE-CANDIDATE "two substrings, BOTH at theirs -> absorbed, must not stay open"

# THE SECOND DIFFERENTIAL — entry SHAPE. These three carry the same directives as B/C/D but
# in the `## SECTION-ID — title` shape instead of a `- **bullet**`. A parser that treats every
# heading as a pure terminator clears the label, so the directive is parsed and then dropped:
# no row, exit 0, indistinguishable from "nothing to close". Measured on the reference
# consumer, where every entry filed after 2026-07-20 used this shape and the one entry that
# had adopted the verify: convention at all was invisible while upstream had already fixed it.
row_is "PC-FIXTURE-HEADING-ABSORBED"  CLOSE-CANDIDATE "heading entry, theirs has MARKER_B -> same verdict as Entry B"
row_is "PC-FIXTURE-HEADING-CLOSED"    ABSENT          "heading entry annotated ADOPTED UPSTREAM -> closed"
row_is "PC-FIXTURE-HEADING-NO-VERIFY" ABSENT          "heading opens an entry, so it ends the one above -> no inherited directive"

# TWO WAYS TO BE DONE. `ADOPTED UPSTREAM` was the only closure token, so an entry WITHDRAWN
# because its premise was false went on asking for a verdict on every pull — and its receipt
# cannot settle it, since no upstream change can make a defect that never existed stop existing.
# Measured on the reference consumer: two of nine HAND-REVIEW rows were one withdrawn entry,
# counted twice. Matched as loosely as its sibling token, and for the same reason.
row_is "PC-FIXTURE-WITHDRAWN"        ABSENT          "premise was false -> finished, exactly like ADOPTED UPSTREAM"

# A close row must name the version where the substring APPEARED, not theirs' tip.
#
# The row is a permanent provenance annotation — the operator copies its version straight into
# `ADOPTED UPSTREAM (v…)`, and retro and the §8.1 fan-in read it afterwards. It used to print
# VERSION at theirs, which is the tip being pulled and has nothing to do with when the
# absorption happened. On the reference consumer that was three releases off, and a hand
# correction filed against it (derived by sampling the refs already loaded, rather than walking
# the history) was wrong in the same direction.
#
# The seed absorbs MARKER_B at 0.101.0 and moves theirs on to 0.102.0, so naming the tip and
# naming the truth are different strings here. With base->theirs adjacent they would not be.
ASSERTIONS=$((ASSERTIONS + 1))
brow="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /Entry B/ {print $3; exit}')"
if grep -q 'absorbed this at 0\.101\.0' <<<"$brow"; then
  printf '  ok    %-22s names 0.101.0  (the version that absorbed it, not theirs 0.102.0)\n' "absorbing-version"
elif grep -q 'absorbed this at 0\.102\.0' <<<"$brow"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s names theirs 0.102.0 — the tip, not the absorbing release; this string is copied into a permanent ledger annotation\n' "absorbing-version"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no recognisable version in the close row: %s\n' "absorbing-version" "$brow"
fi

# An unresolvable substring must fall back to theirs' VERSION, not print an empty version.
# A close row with no version at all is worse than one carrying the tip's.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="CLOSE-CANDIDATE"' | grep -q 'at \.\|at $\|at  '; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a close row rendered an EMPTY version\n' "version-fallback"
else
  printf '  ok    %-22s no close row rendered an empty version\n' "version-fallback"
fi

# A verb wrapped in backticks is a formatting slip, not a different verb — on BOTH ends.
# `theirs_lacks` with a LEADING backtick used to fall through to `unknown verify verb`, filing
# a markdown habit under the same banner as a typo. Four directives on the reference consumer
# are written that way.
#
# TWO DISTINCT FORMS, and they exercise DIFFERENT code. Wrapping the whole receipt puts the
# stray backtick on the END of the directive, where it glues to the quoted substring. Wrapping
# only the verb puts one on each END OF THE VERB. A single case cannot cover both: the
# whole-span form leaves the verb clean, so it passes even with the old trailing-only verb
# strip in place — which is exactly how the verb half nearly shipped unguarded.
btick="$CONS/_bmad-output/ai-dlc-update/backtick-ledger.md"
mkdir -p "$(dirname "$btick")"
{
  printf -- '- **Entry BT** — the whole receipt wrapped in one inline code span.\n'
  printf -- '  `verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"`\n'
  printf -- '- **Entry BV** — only the verb wrapped, as markdown prose invites.\n'
  printf -- '  verify: `theirs_lacks` core/skills/ai-dlc/SKILL.md "MARKER_B"\n'
} > "$btick"
bt_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$btick" 2>&1)"
for probe in "Entry BT:whole receipt in one code span (trailing backtick on the directive)" \
             "Entry BV:only the verb backticked (a backtick on each end of the verb)"; do
  ASSERTIONS=$((ASSERTIONS + 1))
  plabel="${probe%%:*}"; pwhy="${probe#*:}"
  pstatus="$(printf '%s\n' "$bt_out" | awk -F'\t' -v l="$plabel" '$2 ~ l {print $1; exit}')"
  if [ "$pstatus" = "CLOSE-CANDIDATE" ]; then
    printf '  ok    %-22s %s\n' "backtick:${plabel##* }" "$pwhy"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s got=%s want=CLOSE-CANDIDATE — %s; a formatting habit must not change the verdict\n' "backtick:${plabel##* }" "${pstatus:-<none>}" "$pwhy"
  fi
done
rm -f "$btick"

# A receipt is a LINE; a mention is part of one.
#
# The ledger discusses receipts as well as carrying them, and the directive is a last-match-wins
# scalar — so a prose mention physically AFTER the real receipt silently replaced it with
# whatever followed the word. That is PC-S296-LEDGER-REVERIFY-LAST-MATCH-WINS, filed by the
# consumer and still open. Measured there: 88 unanchored matches for 47 real receipts, and one
# summary section emitted a phantom row off `verify: BOTH source predicates retained`.
#
# The `<br>` case is not decoration: nine of the reference consumer's real receipts are written
# that way, and an anchor that forgets it silently DROPS them — six rows vanished on the first
# attempt here, which is the same failure shape in the other direction.
ASSERTIONS=$((ASSERTIONS + 1))
anch="$CONS/_bmad-output/ai-dlc-update/anchored-ledger.md"
mkdir -p "$(dirname "$anch")"
{
  printf -- '- **Entry PM** — its real receipt, then prose that mentions the word afterwards.\n'
  printf -- '  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"\n'
  printf -- '  Discussion: this entry deliberately carries NO `verify: manual` declaration, and a\n'
  printf -- '  later sentence naming `verify: theirs_has` must not become the directive.\n'
  printf -- '- **Entry BR** — a real receipt written after an HTML break, as the ledger body does.\n'
  printf -- '  <br>verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"\n'
} > "$anch"
an_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$anch" 2>&1)"
pm="$(printf '%s\n' "$an_out" | awk -F'\t' '$2 ~ /Entry PM/ {print $1; exit}')"
br="$(printf '%s\n' "$an_out" | awk -F'\t' '$2 ~ /Entry BR/ {print $1; exit}')"
if [ "$pm" = "CLOSE-CANDIDATE" ]; then
  printf '  ok    %-22s prose after the receipt does not overwrite it\n' "anchor:prose"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got=%s want=CLOSE-CANDIDATE — a mid-sentence mention replaced the real receipt (last-match-wins)\n' "anchor:prose" "${pm:-<none>}"
fi
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$br" = "CLOSE-CANDIDATE" ]; then
  printf '  ok    %-22s a <br>-prefixed receipt still registers\n' "anchor:br"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got=%s want=CLOSE-CANDIDATE — the anchor dropped a real receipt written after an HTML break\n' "anchor:br" "${br:-<none>}"
fi
rm -f "$anch"

# THE LABEL IS A JOIN KEY. Field 2 is what `emit-report.sh` renders as the entry name in the
# operator's report, and what the operator greps back into the ledger to find the entry. Both
# arms used to clip it to seventy characters, and the bullet arm never split on the em dash the
# heading arm splits on — so a real report carried a name cut mid-word inside `(original` and
# another that was a whole sentence. Measured on the reference consumer: ten of forty-one rows
# came out at exactly seventy bytes.
#
# These assert EXACT equality, not the substring match `row_is` uses. A substring assertion
# cannot see a truncation: the clipped prefix still matches.
label_is() {
  local pat="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | awk -F'\t' -v p="$pat" '$2 ~ p {print $2; exit}')"
  if [ "$got" = "$want" ]; then
    printf '  ok    %-22s label is the whole id  (%s)\n' "$pat" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s got=[%s] want=[%s]  (%s)\n' "$pat" "${got:-<none>}" "$want" "$why"
  fi
}

label_is "PC-FIXTURE-BULLET-DASH" "PC-FIXTURE-BULLET-DASH" \
  "bullet arm splits on the em dash, as the heading arm always did"
label_is "PC-FIXTURE-HEADING-LONG-BEFORE-DASH" \
  "PC-FIXTURE-HEADING-LONG-BEFORE-DASH (a parenthetical this long pushes the pre-dash text past seventy characters on its own)" \
  "pre-dash text over seventy characters survives whole"

# No label may come out at exactly the old cap. A single row at that width is the clip back.
ASSERTIONS=$((ASSERTIONS + 1))
clipped="$(printf '%s\n' "$OUT" | awk -F'\t' 'length($2)==70{n++} END{print n+0}')"
if [ "$clipped" -eq 0 ]; then
  printf '  ok    %-22s no label lands on the old seventy-character cap\n' "label-width"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s label(s) are exactly 70 bytes — the clip is back\n' "label-width" "$clipped"
fi

# The closer must NEVER exit nonzero — it is a classifier and a close never blocks apply.
ASSERTIONS=$((ASSERTIONS + 1))
bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  printf '  ok    %-22s exit 0  (classifier never blocks)\n' "exit-code"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s exit=%s want=0  (a close must never block apply)\n' "exit-code" "$rc"
fi

# A consumer with NO ledger: exit 0, no output.
ASSERTIONS=$((ASSERTIONS + 1))
empty="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" 2>&1)"
if [ -z "$empty" ]; then
  printf '  ok    %-22s silent  (no ledger -> nothing to re-verify)\n' "no-ledger"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s emitted output on a missing ledger\n' "no-ledger"
fi

# --- THE CLOSE PREDICATE IS ANCHORED, like the verify: predicate beside it -------------
# Unanchored, a PROSE MENTION of the vocabulary closed a live entry, and the failure was silent
# in the worse direction: no row at all rather than a wrong one. Measured on the reference
# consumer, four entries with live receipts were invisible. The discriminator is line-leading
# STRUCTURE — an annotation opens its line (bare, or opening a bold span, optionally behind the
# <br> the entry bodies use); a mention sits inside a sentence.
row_is "PROSE-MENTIONS-THE-VOCABULARY" STILL-LIVE \
  "an OPEN entry quoting the close markers in prose, a blockquote and a code span still reports"
row_is "BOLD-ANNOTATION-WITH-A-PREFIX" ABSENT \
  "a real annotation whose bold span opens with words before the marker still closes"
row_is "retained for the record" ABSENT \
  "the copy a withdrawal supersedes carries no marker of its own and must not re-report forever"

# MUTATION — restore the unanchored predicate. The prose entry must vanish, and it must be the
# ONLY thing that changes: an anchor that also drops a real close is a different bug.
MUTD="$(dirname "$DIST")/mut-closer"
rm -rf "$MUTD"; mkdir -p "$MUTD"
cp "$(dirname "$CLOSER")"/*.sh "$MUTD/" 2>/dev/null
sed 's@^  /\^\[ \\t\]\*(<br\[ \\t\]\*\\/?\[ \\t\]\*>)?\[ \\t\]\*(\\\*\\\*\[^`\]\*)?(ADOPTED UPSTREAM|WITHDRAWN)/ { closed=1 }@  /ADOPTED UPSTREAM|WITHDRAWN/ { closed=1 }@' \
  "$CLOSER" > "$MUTD/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTD/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the anchor assertions above are unproven\n' "mutation"
else
  mut_out="$(bash "$MUTD/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mut_prose="$(printf '%s\n' "$mut_out" | awk -F'\t' '$2 ~ /PROSE-MENTIONS-THE-VOCABULARY/ {print $1; exit}')"
  mut_bold="$(printf '%s\n' "$mut_out" | awk -F'\t' '$2 ~ /BOLD-ANNOTATION-WITH-A-PREFIX/ {print $1; exit}')"
  if [ -n "$mut_prose" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the unanchored predicate did NOT swallow the prose entry — the assertion above is vacuous\n' "mutation"
  elif [ -n "$mut_bold" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also un-closed a REAL annotation, so it is not a clean mutation of the anchor alone\n' "mutation"
  else
    printf '  ok    %-22s unanchoring swallows the prose entry and nothing else\n' "mutation"
  fi
fi

# --- EVERY RECEIPT, NOT THE LAST ONE ---------------------------------------------------
# `directive` was a scalar assigned inside a per-line awk rule, so a second line-leading `verify:`
# silently overwrote the first. Measured on the reference consumer AFTER the fix: 2 entries carry
# multiple receipts (one with two, one with four), so FOUR receipts were being discarded on every
# pull. Their surviving verdicts happened to agree there, which is precisely how the defect went
# unnoticed — the row was never wrong, the question was never asked.
#
# This pair disagrees on purpose: a close and a still-live in one entry. The scalar kept the close.
row_has "PC-FIXTURE-TWO-RECEIPTS" STILL-LIVE \
  "receipt 1 of 2 is genuinely live and must not be swallowed by the close that follows it"
row_has "PC-FIXTURE-TWO-RECEIPTS" CLOSE-CANDIDATE \
  "receipt 2 of 2 is a real close and must still report"

# The ordinal has to be on the row, or two rows for one entry are unattributable.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | grep -F 'PC-FIXTURE-TWO-RECEIPTS' | grep -q '\[receipt 1/2\]'; then
  printf '  ok    %-22s rows carry their receipt ordinal\n' "receipt-ordinal"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s two rows for one entry with no ordinal to tell them apart\n' "receipt-ordinal"
fi

# A SINGLE-receipt entry must be byte-unchanged — no ordinal suffix. Otherwise the fix rewrites
# every row in every consumer report to buy a two-entry improvement.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | grep -F 'Entry A' | grep -q '\[receipt '; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a single-receipt entry grew an ordinal suffix\n' "single-unchanged"
else
  printf '  ok    %-22s single-receipt rows unchanged (no suffix)\n' "single-unchanged"
fi

# MUTATION — restore the scalar handoff. The still-live half must vanish, and ONLY that.
MUTS="$(dirname "$DIST")/mut-scalar"
rm -rf "$MUTS"; mkdir -p "$MUTS"
cp "$(dirname "$CLOSER")"/*.sh "$MUTS/" 2>/dev/null
awk '
  /^    dn\+\+; dv\[dn\]=directive$/ { next }
  /^      for \(di = 1; di <= dn; di\+\+\)$/ { skip=1; next }
  skip { print "      printf \"%s\\t%s\\t%s\\n\", label, \"1/1\", directive"; skip=0; next }
  { print }
' "$CLOSER" > "$MUTS/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTS/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the accumulation assertions are unproven\n' "mutation-scalar"
else
  ms="$(bash "$MUTS/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  ms_live="$(printf '%s\n' "$ms" | awk -F'\t' '$2 ~ /TWO-RECEIPTS/ && $1 == "STILL-LIVE" {c++} END{print c+0}')"
  ms_close="$(printf '%s\n' "$ms" | awk -F'\t' '$2 ~ /TWO-RECEIPTS/ && $1 == "CLOSE-CANDIDATE" {c++} END{print c+0}')"
  if [ "$ms_live" -eq 0 ] && [ "$ms_close" -gt 0 ]; then
    printf '  ok    %-22s the scalar handoff swallows the live receipt and keeps the close\n' "mutation-scalar"
  elif [ "$ms_live" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant still emitted the live receipt, so the assertions above are vacuous\n' "mutation-scalar"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost BOTH rows, so it is not a clean mutation of the handoff alone\n' "mutation-scalar"
  fi
fi

# --- THE NAME IS THE THIRD SIGNAL ------------------------------------------------------
# Every predicate above tests the RECEIPT, which is the wrong instrument when the receipt is
# what is broken. A receipt anchored on a token present at both refs, or an inverted verb, or
# `verify: manual`, can never close its entry no matter how many pulls run it. The entry id in
# upstream's own commit message is the one signal a rewording cannot defeat.
#
# Measured on the reference consumer: 51 heading labels, 37 id-shaped, 4 named — all four true
# positives, each invisible to every other predicate in this file, and 33 id-shaped labels
# silent. That 33 is the control that this discriminates rather than rubber-stamps.
row_has "PC-FIXTURE-NAMED-BUT-RECEIPT-STUCK" NAMED-UPSTREAM \
  "upstream's history names the id -> the absorption is visible even though the receipt cannot see it"
row_has "PC-FIXTURE-NAMED-BUT-RECEIPT-STUCK" STILL-LIVE \
  "the receipt's own verdict still prints — the pair IS the finding, and suppressing either half loses a fact"
row_has "PC-FIXTURE-NAMED-MANUAL" NAMED-UPSTREAM \
  "fires for verify: manual, the shape with no other mechanical signal at all"
row_has "PC-FIXTURE-NAMED-MANUAL" HAND-REVIEW \
  "manual is still a declaration, not downgraded by the extra row"

# THE CONTROLS. An id-shaped label upstream never named must stay silent, or the row means
# nothing; and a PROSE label must stay silent even though the pre-base commit quotes it verbatim.
row_lacks "PC-FIXTURE-HEADING-ABSORBED" NAMED-UPSTREAM \
  "id-shaped but never named upstream -> silent, so the signal is a discriminator"
row_lacks "Entry A" NAMED-UPSTREAM \
  "prose label quoted verbatim in the history -> the id-shape guard refuses to join on words"

# MUTATION 2 — drop the id-shape guard. Entry A's prose label then matches the pre-base commit
# that quotes it, and a wall of word-matched rows is exactly the lint an operator switches off.
#
# BOTH LAYERS GO. The guard is two conditions — the label contains only [A-Z0-9-], and it
# contains at least one hyphen — and stripping either alone leaves the other still rejecting a
# prose label. The first draft of this mutant removed only the charset arm, came out green, and
# was therefore proving the layer it had left in place rather than the guard.
MUTG="$(dirname "$DIST")/mut-guard"
rm -rf "$MUTG"; mkdir -p "$MUTG"
cp "$(dirname "$CLOSER")"/*.sh "$MUTG/" 2>/dev/null
sed -e '/not id-shaped: prose label/d' -e '/a single word is not an id/d' \
  "$CLOSER" > "$MUTG/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTG/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the id-shape guard assertion is unproven\n' "mutation-guard"
else
  mg_out="$(bash "$MUTG/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  if printf '%s\n' "$mg_out" | awk -F'\t' '$2 ~ /Entry A/ && $1 == "NAMED-UPSTREAM" {f=1} END{exit !f}'; then
    printf '  ok    %-22s without the guard a prose label word-matches — the guard is load-bearing\n' "mutation-guard"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s guardless closer did NOT match the prose label, so row_lacks above is vacuous\n' "mutation-guard"
  fi
fi

# MUTATION 3 — re-bound the search to BASE..THEIRS. The naming commit is before base, so the
# row disappears: the unbounded search is the whole reason the signal survives past its pull.
MUTB="$(dirname "$DIST")/mut-bound"
rm -rf "$MUTB"; mkdir -p "$MUTB"
cp "$(dirname "$CLOSER")"/*.sh "$MUTB/" 2>/dev/null
sed 's@--grep="$_id" --format=%H "$THEIRS"@--grep="$_id" --format=%H "${BASE}..${THEIRS}"@' \
  "$CLOSER" > "$MUTB/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTB/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the unbounded-search assertion is unproven\n' "mutation-bound"
else
  mb_out="$(bash "$MUTB/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mb_named="$(printf '%s\n' "$mb_out" | awk -F'\t' '$1 == "NAMED-UPSTREAM" {c++} END{print c+0}')"
  mb_still="$(printf '%s\n' "$mb_out" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-BUT-RECEIPT-STUCK/ && $1 == "STILL-LIVE" {f=1} END{print f+0}')"
  if [ "$mb_named" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s bounding to base..theirs still found %s named row(s) — the assertions above are vacuous\n' "mutation-bound" "$mb_named"
  elif [ "$mb_still" -ne 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also lost the receipt verdict, so it is not a clean mutation of the search bound alone\n' "mutation-bound"
  else
    printf '  ok    %-22s bounding the search loses the pre-base absorption and nothing else\n' "mutation-bound"
  fi
fi

# THE UNMUTATED CONTROL. Both mutants are copies into a fresh directory; if a copy cannot even
# source lib.sh it emits nothing, and "no rows" would otherwise score as a kill for BOTH of the
# assertions above. This copy is byte-identical to the detector, so it must behave identically.
ASSERTIONS=$((ASSERTIONS + 1))
CTLD="$(dirname "$DIST")/ctl-closer"
rm -rf "$CTLD"; mkdir -p "$CTLD"
cp "$(dirname "$CLOSER")"/*.sh "$CTLD/" 2>/dev/null
cp "$CLOSER" "$CTLD/ledger-reverify.sh"
ctl_named="$(bash "$CTLD/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1 | awk -F'\t' '$1 == "NAMED-UPSTREAM" {c++} END{print c+0}')"
if [ "$ctl_named" -eq 2 ]; then
  printf '  ok    %-22s unmutated copy in the same directory emits both named rows (harness is sound)\n' "mutation-control"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s unmutated copy emitted %s named rows, want 2 — a copy that cannot run scores as a kill\n' "mutation-control" "$ctl_named"
fi

# --- ENTRY-SWALLOWED: a bold-bullet annotation that became its own entry -----------------
# THE DEFECT. A line-leading `- **…**` annotation inside an entry opens a NEW entry, so it
# truncates the one it annotates and captures its receipt. The real entry then emits no row
# under its own id — a silent disappearance that reads exactly like an entry with nothing to
# report. The reference consumer hit it while annotating an entry; two runs read clean.
row_has "The derivation:" ENTRY-SWALLOWED \
  "an annotation lead-in that opened its own entry is REPORTED, not silently obeyed"

# It must name WHICH entry went dark, or the operator has a complaint and no subject.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $3 ~ /PC-FIXTURE-SWALLOWED-BY-ANNOTATION/{f=1} END{exit !f}'; then
  printf '  ok    %-22s names the entry it truncated, and that it captured the receipt\n' "swallowed-names-entry"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s reported a swallow without naming the entry that went silent\n' "swallowed-names-entry"
fi

# THE CONTROL SET, and both must be able to fail. Without them the assertion above is satisfied
# by a detector that flags every entry, or every entry carrying a colon anywhere.
row_lacks "PC-FIXTURE-COLON-CONTROL" ENTRY-SWALLOWED \
  "a normal entry in the same section stays silent"
row_lacks "a-real-entry.sh" ENTRY-SWALLOWED \
  "a PROSE-titled entry legitimately carrying a receipt stays silent — the measured 6-of-7 false-positive class"

# MUTATION — drop the colon discriminator. The prose-titled control must then be reported,
# which is the exact false-positive set that killed the earlier predicate. Nothing else changes.
MUTC="$(dirname "$DIST")/mut-colon"
rm -rf "$MUTC"; mkdir -p "$MUTC"
cp "$(dirname "$CLOSER")"/*.sh "$MUTC/" 2>/dev/null
sed 's@label ~ /:\$/ && !idshape(label)@!idshape(label)@' "$CLOSER" > "$MUTC/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTC/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the colon discriminator is unproven\n' "mutation-colon"
else
  mc_out="$(bash "$MUTC/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  if printf '%s\n' "$mc_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /a-real-entry/{f=1} END{exit !f}'; then
    printf '  ok    %-22s without the colon test a prose-titled entry is falsely reported — it is load-bearing\n' "mutation-colon"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s dropping the colon test did NOT re-fire the prose entry, so the control above is vacuous\n' "mutation-colon"
  fi
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
