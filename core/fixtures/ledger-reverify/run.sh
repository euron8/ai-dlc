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

# --- CWD INVARIANCE, and it is asserted here because it is not free -------------------------
# A `verify: sh` receipt names CONSUMER-RELATIVE paths and used to be run with `bash -c` from
# whatever directory the caller happened to be standing in. The same receipt, the same ledger and
# the same four arguments then produced DIFFERENT verdicts per cwd. Measured on the reference
# consumer's ledger, one row apart:
#
#   from the CONSUMER root       PC-S331  STILL-LIVE       the receipt found its file
#   from the DISTRIBUTION root   PC-S331  CLOSE-CANDIDATE  grep exited 2, no such file
#
# The wrong-cwd direction is the one that loses data -- it proposes closing a live entry -- and
# the path-existence guard could not see it, because that guard resolves against $CONSUMER and
# correctly reported every path present while the predicate read another tree entirely.
#
# EVERY OTHER ASSERTION IN THIS FILE IS BLIND TO IT: they all read one $OUT, taken from one cwd,
# so they agree with each other no matter which tree the receipts were evaluated against. This
# arm is the only one that can see it, which is why the comparison is byte-for-byte rather than
# per-row.
# THE COMPARISON NEEDS A CWD WHERE THE RECEIPT RESOLVES, and the first draft of this arm did
# not have one: it compared `/` against the fixture's own cwd, and a bare relative subject is
# missing from BOTH, so the mutant produced the same wrong answer twice and the byte-comparison
# passed. One side is now the CONSUMER ROOT itself -- the only directory where a
# consumer-relative path resolves -- which is what makes the two sides able to disagree.
cwd_probe="$(cd / && bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
cwd_atcons="$(cd "$CONS" && bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$cwd_probe" = "$cwd_atcons" ]; then
  printf '  ok    %-22s byte-identical from `/` and from the CONSUMER root — a receipt is evaluated at the consumer root, not wherever the caller stands
' "cwd-invariance"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the verdicts CHANGED with the working directory. A `verify: sh` receipt names consumer-relative paths; run from elsewhere its grep exits non-zero on a missing file and the entry reads as absorbed. That direction closes live entries.
' "cwd-invariance"
  diff <(printf '%s\n' "$cwd_atcons") <(printf '%s\n' "$cwd_probe") | sed 's/^/          | /' | head -12
fi

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

# THE POSITIVE OUTCOME, asserted rather than the absence of the old failure. A receipt naming a
# BARE consumer-relative subject that is PRESENT must read STILL-LIVE from this fixture's cwd,
# which is not the consumer root. The equality above cannot make that claim on its own.
row_is "Entry SH-RELATIVE-SUBJECT" STILL-LIVE "a BARE consumer-relative subject that EXISTS reproduces whatever directory the caller stands in; evaluated elsewhere its grep exits 2 and the entry reads as absorbed"
# A MOVED SUBJECT INSIDE AN && CHAIN IS NOT A FIX, and the exit status cannot say so: the chain
# short-circuits with 1, exactly like a genuine fix. The 126/127 guard cannot reach it, and the
# residue used to be a NOTE in the CLOSE-CANDIDATE detail telling the operator to check the paths
# themselves. SH-REAL above is the paired control: a non-zero exit whose receipt names no
# consumer-relative path at all must still CLOSE, or this guard pins every sh entry open.
row_is "Entry SH-SUBJECT-GONE" NEEDS-REVIEW "an && chain short-circuiting on a MOVED subject must not read as a fix"
# A DISTRIBUTION PATH IS NOT A CONSUMER SUBJECT. The pair with SH-SUBJECT-GONE is the whole
# assertion: that entry names a consumer path that is genuinely absent and must stay flagged,
# this one names a distribution path inside a rev-spec and must not be. An extractor that sees
# neither passes the first arm alone; one that sees both passes the second alone.
row_is "Entry SH-DIST-PATH" CLOSE-CANDIDATE "a `core/scripts/<x>` rev-spec names no consumer subject; reading one out of it withholds the close on a receipt that works"
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
# The seed absorbs MARKER_B at 0.101.0 and moves theirs on to 0.103.0, so naming the tip and
# naming the truth are different strings here. With base->theirs adjacent they would not be.
ASSERTIONS=$((ASSERTIONS + 1))
brow="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /Entry B/ {print $3; exit}')"
if grep -q 'absorbed this at 0\.101\.0' <<<"$brow"; then
  printf '  ok    %-22s names 0.101.0  (the version that absorbed it, not theirs 0.103.0)\n' "absorbing-version"
elif grep -q 'absorbed this at 0\.103\.0' <<<"$brow"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s names theirs 0.103.0 — the tip, not the absorbing release; this string is copied into a permanent ledger annotation\n' "absorbing-version"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no recognisable version in the close row: %s\n' "absorbing-version" "$brow"
fi

# THE OTHER COMMIT SHAPE, and it is the one the version used to be wrong for. `MARKER_B` above
# arrived in a commit that ALSO bumped VERSION, so reading the blob at it is correct and the arm
# above passes either way. `MARKER_C` arrived one commit BEFORE its release: blob-at-the-commit
# says 0.101.0, the tip says 0.103.0, and the release that actually carries it is 0.102.0. Three
# distinct strings, so this arm cannot be satisfied by any of the three behaviours by accident.
# Reported by the graph consumer as PC-S334-ABSORBED-AT-READS-THE-VERSION-BLOB-AT-THE-FIX-COMMIT.
ASSERTIONS=$((ASSERTIONS + 1))
vrow="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /Entry V/ {print $3; exit}')"
case "$vrow" in
  *'absorbed this at 0.102.0'*)
    printf '  ok    %-22s names 0.102.0  (the release CONTAINING the fix, not the blob at it)\n' "release-containing" ;;
  *'absorbed this at 0.101.0'*)
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s names 0.101.0 — the VERSION blob AT the absorbing commit, one release early\n' "release-containing" ;;
  *'absorbed this at 0.103.0'*)
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s names 0.103.0 — theirs, so the walk found nothing and fell back\n' "release-containing" ;;
  *)
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s no recognisable version in Entry V row: %s\n' "release-containing" "$vrow" ;;
esac

# A NAMED-UPSTREAM ROW CARRIES NO VERSION, DELIBERATELY. The join is on the commit MESSAGE, and a
# commit that names an id to record a rejection, a split, a plan or a ledger drain matches
# exactly like one that landed the fix — so a version read off it is a claim about the wrong
# event, and it went into a permanent annotation. Re-derived against `e939a92` and
# `docs/reviews/graph-ledger-adjudication-data/final-disposition.tsv`: 29 ids named, 25
# comparable, 23 disagreeing with the adjudicated disposition.
# PC-S334-NAMED-ABSORBED-JOINS-ON-THE-OLDEST-MESSAGE-MENTION.
#
# BOTH HALVES ASSERTED. "No version" alone is satisfied by a row that lost its content; the row
# must still say WHERE upstream names the id, or the fix deleted the signal instead of the
# false precision.
ASSERTIONS=$((ASSERTIONS + 1))
nrow="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM" {print $3; exit}')"
if [ -z "$nrow" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no NAMED-UPSTREAM row at all — the arms below cannot discriminate\n' "named-no-version"
elif grep -qE 'at v[0-9]+\.[0-9]+\.[0-9]+|\(v[0-9]+\.[0-9]+\.[0-9]+,' <<<"$nrow"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the row still renders a version: %s\n' "named-no-version" "$(printf '%s' "$nrow" | cut -c1-140)"
elif grep -q 'NAMES this entry.s id in ' <<<"$nrow"; then
  printf '  ok    %-22s no version, and it still says where upstream names the id\n' "named-no-version"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no version, but the row no longer says WHERE: %s\n' "named-no-version" "$(printf '%s' "$nrow" | cut -c1-140)"
fi

# MUTATION — put the VERSION blob read back into absorbed_at. Entry V must regress to 0.101.0 and
# Entry B must NOT move: the two shapes are what make this a fix rather than a swap, and a mutant
# that moved both would mean the seed only carries one of them.
MUTV="$(dirname "$DIST")/mut-version"
rm -rf "$MUTV"; mkdir -p "$MUTV"
cp "$(dirname "$CLOSER")"/*.sh "$MUTV/" 2>/dev/null
sed 's@_v="$(release_containing "$_c")"@_v="$(git -C "$DIST" show "${_c}:VERSION" 2>/dev/null | tr -d "[:space:]")"@' \
  "$CLOSER" > "$MUTV/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTV/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the forward walk is unproven\n' "mutation-version"
else
  mv_out="$(bash "$MUTV/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  mv_v="$(printf '%s\n' "$mv_out" | awk -F'\t' '$2 ~ /Entry V/ {print $3; exit}')"
  mv_b="$(printf '%s\n' "$mv_out" | awk -F'\t' '$2 ~ /Entry B/ {print $3; exit}')"
  if [ -z "$mv_out" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant produced NO rows — a dead copy scores every absence as a kill\n' "mutation-version"
  elif ! grep -q 'absorbed this at 0\.101\.0' <<<"$mv_v"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s with the blob read restored Entry V still reads %s — the arm above is not watching the walk\n' "mutation-version" "$(printf '%s' "$mv_v" | sed -n 's/.*absorbed this at \([0-9.]*\).*/\1/p')"
  elif ! grep -q 'absorbed this at 0\.101\.0' <<<"$mv_b"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved Entry B — the fix-is-release shape is not being held fixed\n' "mutation-version"
  else
    printf '  ok    %-22s the blob read regresses Entry V to 0.101.0 and leaves Entry B at 0.101.0\n' "mutation-version"
  fi
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

# --- A CALLER ERROR MUST NOT READ AS A CLEAN CORPUS --------------------------------------
# THIS ARM USED TO ASSERT THE DEFECT. It read "a consumer with NO ledger: exit 0, no output"
# and produced that case by passing an EXPLICIT arg-5 path that does not exist — which is not
# what a consumer with no ledger does. A consumer with no ledger passes no arg 5 at all. So the
# assertion pinned the silence of a caller error, and the fixture would have gone red on the
# fix rather than on the bug.
#
# The genuine case is the DEFAULT path, absent, under a real consumer root. That is the arm
# below, and it is also this change's false-positive control: it is the only shape that stays
# silent, and it must.
ASSERTIONS=$((ASSERTIONS + 1))
NOLED="$(dirname "$DIST")/consumer-with-no-ledger"
rm -rf "$NOLED"; mkdir -p "$NOLED"
empty="$(bash "$CLOSER" "$DIST" "$BASE" "$NOLED" "$THEIRS" 2>&1)"; empty_rc=$?
if [ -z "$empty" ] && [ "$empty_rc" -eq 0 ]; then
  printf '  ok    %-22s silent, exit 0  (real consumer root, default ledger absent -> genuinely nothing to re-verify)\n' "no-ledger"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s rc=%s output=[%s] — a consumer that never filed a candidate must stay silent\n' "no-ledger" "$empty_rc" "$empty"
fi

# ARM 1 — an explicitly-supplied arg-5 path that is not readable. Nothing was re-verified, and
# that used to be spelled as zero rows and rc=0, which is how a clean corpus is spelled.
# Measured at 0.300.0 on the reference consumer: bogus arg 5 gave 0 rows, rc=0 and ZERO bytes of
# stderr, against 74 rows for the correct invocation.
ASSERTIONS=$((ASSERTIONS + 1))
bad5="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" 2>/dev/null)"
bad5_n="$(printf '%s\n' "$bad5" | awk -F'\t' '$1=="INPUT-UNRESOLVED"{c++} END{print c+0}')"
if [ "$bad5_n" -eq 1 ] && grep -qF 'nonexistent-ledger.md' <<<"$bad5"; then
  printf '  ok    %-22s one INPUT-UNRESOLVED row naming the arg-5 path\n' "bad-arg5"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got %s INPUT-UNRESOLVED row(s); an unreadable arg-5 path must not read as a clean corpus\n' "bad-arg5" "$bad5_n"
  printf '%s\n' "$bad5" | sed 's/^/          | /'
fi

# ARM 2 — THE MISTAKE THAT WAS ACTUALLY MADE, and the reason arm 1 alone is not the fix. This
# tool takes consumer THIRD and theirs FOURTH; every sibling in reconcile/ takes
# `<dist> <base> <theirs> <consumer>`, and layer-drift.sh's own usage line is the opposite
# order. Swapping them puts a SHA in the consumer slot, so `$LEDGER` is the DEFAULT path under a
# root that does not exist and an arg-5-only check never fires. The consumer root is therefore
# checked on its own.
ASSERTIONS=$((ASSERTIONS + 1))
swapped="$(bash "$CLOSER" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
sw_n="$(printf '%s\n' "$swapped" | awk -F'\t' '$1=="INPUT-UNRESOLVED"{c++} END{print c+0}')"
if [ "$sw_n" -eq 1 ]; then
  printf '  ok    %-22s swapped args report, though the ledger path is the DEFAULT one\n' "swapped-args"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got %s INPUT-UNRESOLVED row(s) — an arg-5-only check cannot see this case\n' "swapped-args" "$sw_n"
  printf '%s\n' "$swapped" | sed 's/^/          | /'
fi

# BOTH ARMS STILL EXIT 0. This is a classifier and its callers depend on that; the ROW is the
# signal, not the status code. An arm that reported by exiting non-zero would block `apply`.
ASSERTIONS=$((ASSERTIONS + 1))
bash "$CLOSER" "$DIST" "$BASE" "$THEIRS" "$CONS" >/dev/null 2>&1; sw_rc=$?
bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" >/dev/null 2>&1; b5_rc=$?
if [ "$sw_rc" -eq 0 ] && [ "$b5_rc" -eq 0 ]; then
  printf '  ok    %-22s both caller-error arms exit 0  (classifier never blocks)\n' "input-exit-code"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s swapped=%s bad-arg5=%s want 0/0 — reporting by exit code blocks apply\n' "input-exit-code" "$sw_rc" "$b5_rc"
fi

# --- THE CONSUMER ROOT IS NORMALIZED, AND THE FAILURE WAS A FALSE CLOSE -------------------
# `.` is a valid consumer root and callers routinely pass it. It is the only one of the four
# exported values a receipt reads AS A PATH, so a receipt whose own claim is about absolute-path
# handling has its subject handed to it in the wrong form and its `&&` chain inverts. Entry
# SH-CWD in the seed is exactly that shape; without it this differential cannot fail.
#
# THE ASSERTION IS BYTE-IDENTITY ACROSS THE TWO FORMS, not a verdict on one of them: the claim
# is that the form of the argument does not decide any row. Measured on the reference consumer
# at 0.300.0 — 74 rows either way, ONE differing, a CLOSE-CANDIDATE against a STILL-LIVE.
ASSERTIONS=$((ASSERTIONS + 1))
rel_out="$(cd "$CONS" && bash "$CLOSER" "$DIST" "$BASE" . "$THEIRS" 2>/dev/null | sort)"
abs_out="$(printf '%s\n' "$OUT" | sort)"
rel_n="$(printf '%s\n' "$rel_out" | grep -c . )"
abs_n="$(printf '%s\n' "$abs_out" | grep -c . )"
if [ "$rel_n" -eq 0 ] || [ "$abs_n" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s one side produced NO rows (rel=%s abs=%s) — two empty sets agree, which proves nothing\n' "consumer-form" "$rel_n" "$abs_n"
elif [ "$rel_out" = "$abs_out" ]; then
  printf '  ok    %-22s %s rows, byte-identical whether the root arrives as "." or absolute\n' "consumer-form" "$rel_n"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the ROOT ARGUMENT decided a verdict:\n' "consumer-form"
  diff <(printf '%s\n' "$rel_out") <(printf '%s\n' "$abs_out") | sed 's/^/          | /'
fi

# SH-CWD must be STILL-LIVE in the normal run, or the differential above could be satisfied by
# a closer that drops the entry on both sides.
row_is "Entry SH-CWD" STILL-LIVE "an absolute root makes the absolute arm behave as the entry claims -> stays open"

# MUTATION — remove the normalization. The relative run must then diverge, and SH-CWD must flip
# to the FALSE CLOSE. Both halves are asserted: a mutant that merely changes the output proves
# nothing about which direction the defect ran in.
MUTN="$(dirname "$DIST")/mut-norm"
rm -rf "$MUTN"; mkdir -p "$MUTN"
cp "$(dirname "$CLOSER")"/*.sh "$MUTN/" 2>/dev/null
sed '/^\[ -n "\$_abs_consumer" \] && CONSUMER="\$_abs_consumer"$/d' "$CLOSER" > "$MUTN/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTN/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the normalization assertions are unproven\n' "mutation-normalize"
else
  mn_rel="$(cd "$CONS" && bash "$MUTN/ledger-reverify.sh" "$DIST" "$BASE" . "$THEIRS" 2>/dev/null | sort)"
  mn_abs="$(bash "$MUTN/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null | sort)"
  mn_cwd="$(printf '%s\n' "$mn_rel" | awk -F'\t' '$2 ~ /Entry SH-CWD/ {print $1; exit}')"
  # THE "NOTHING ELSE MOVED" ARM COMPARES VERDICTS, NOT RENDERED TEXT, AND THE REASON IS
  # MEASURED. `$CONSUMER` is printed verbatim into the reachability DETAIL, and this seed's own
  # root arrives as `$TMPDIR/…` where TMPDIR ends in a slash — a DOUBLED slash, which is one of
  # the four spellings this closer's header already names as breaking its containment test.
  # Normalizing collapses it, so ten DETAIL strings change while not one verdict does. Comparing
  # raw output here would score a correct fix as an unclean mutation; comparing (status, label)
  # asserts the property the arm is actually about.
  # RECEIPTS-UNDECIDED IS EXCLUDED HERE, AND IT IS THE ONE ROW THAT MUST BE. Its ENTRY column is
  # the LEDGER PATH, which is derived from the consumer root — so normalization rewrites it by
  # design, and comparing it would score the fix as an unclean mutation for doing exactly what
  # it exists to do. That the mutant still emits the row at all is asserted on its own below,
  # so excluding it here cannot hide the row going missing.
  mn_abs_v="$(printf '%s\n' "$mn_abs" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"{print $1"\t"$2}')"
  abs_out_v="$(printf '%s\n' "$abs_out" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"{print $1"\t"$2}')"
  mn_und="$(printf '%s\n' "$mn_abs" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
  if [ "$mn_rel" = "$mn_abs" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s without normalization the two forms still agreed — the differential above is vacuous\n' "mutation-normalize"
  elif [ "$mn_cwd" != "CLOSE-CANDIDATE" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the unnormalized run moved SH-CWD to %s, not the FALSE CLOSE the defect produces\n' "mutation-normalize" "${mn_cwd:-<none>}"
  elif [ "$mn_und" -ne 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant emitted %s RECEIPTS-UNDECIDED row(s), want 1 — the row excluded from the comparison below must still be there\n' "mutation-normalize" "$mn_und"
  elif [ "$mn_abs_v" != "$abs_out_v" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved the ABSOLUTE run, so it is not a clean mutation of the normalization alone\n' "mutation-normalize"
  else
    printf '  ok    %-22s without normalization "." produces a FALSE CLOSE on SH-CWD, and nothing else moves\n' "mutation-normalize"
  fi
fi

# MUTATION — widen receipt_absent_subjects' prefix test to a substring test, which is the shape
# the defect had. SH-DIST-PATH must flip to NEEDS-REVIEW and SH-SUBJECT-GONE must stay
# NEEDS-REVIEW: a mutant that reddens both is telling you the extractor went blind rather than
# that it stopped anchoring.
#
# THE TOKENIZER IS NOT THE SIGNAL, AND THE MUTANT IS HOW THAT WAS SETTLED. The obvious mutation
# was the `tr` keep-set — put `:` back in it so a rev-spec stays one token — and it SURVIVES,
# measured: the token is then `$THEIRS:core/scripts/<x>`, which fails the prefix test anyway.
# What carries the fix is that a candidate is a WHOLE TOKEN judged by its first characters, so
# that is what this mutation removes.
MUTP="$(dirname "$DIST")/mut-prefix"
rm -rf "$MUTP"; mkdir -p "$MUTP"
cp "$(dirname "$CLOSER")"/*.sh "$MUTP/" 2>/dev/null
sed 's@      docs/\*|_bmad-output/\*|scripts/\*|\.claude/\*) ;;@      *docs/*|*_bmad-output/*|*scripts/*|*.claude/*) ;;@' \
  "$CLOSER" > "$MUTP/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTP/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the anchoring assertion is unproven\n' "mutation-prefix"
else
  mp_out="$(bash "$MUTP/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  mp_dist="$(printf '%s\n' "$mp_out" | awk -F'\t' '$2 ~ /Entry SH-DIST-PATH/ {print $1; exit}')"
  mp_gone="$(printf '%s\n' "$mp_out" | awk -F'\t' '$2 ~ /Entry SH-SUBJECT-GONE/ {print $1; exit}')"
  if [ -z "$mp_out" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant produced NO rows — a dead copy scores every absence as a kill\n' "mutation-prefix"
  elif [ "$mp_dist" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s SH-DIST-PATH read %s under the substring test, so the arm above is not watching the anchoring\n' "mutation-prefix" "${mp_dist:-<none>}"
  elif [ "$mp_gone" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved SH-SUBJECT-GONE to %s — it blinded the extractor instead of widening it\n' "mutation-prefix" "${mp_gone:-<none>}"
  else
    printf '  ok    %-22s a substring prefix test reads a consumer subject out of a distribution rev-spec, and only SH-DIST-PATH moves\n' "mutation-prefix"
  fi
fi

# MUTATION — restore the unconditional bail. Both caller-error arms must go silent, and the
# genuine no-ledger arm must be unaffected: the defect was that ONE line answered three
# questions, so a mutant that also silenced the real case would be mutating the wrong thing.
MUTL="$(dirname "$DIST")/mut-bail"
rm -rf "$MUTL"; mkdir -p "$MUTL"
cp "$(dirname "$CLOSER")"/*.sh "$MUTL/" 2>/dev/null
awk '
  /^if \[ ! -d "\$CONSUMER" \]; then$/ { skip=1 }
  skip && /^fi$/ && !done_d { done_d=1; skip=0; next }
  /^if \[ ! -f "\$LEDGER" \]; then$/ { skipl=1; print "[ -f \"$LEDGER\" ] || exit 0"; next }
  skipl && /^fi$/ { skipl=0; next }
  skip || skipl { next }
  { print }
' "$CLOSER" > "$MUTL/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTL/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the caller-error arms are unproven\n' "mutation-bail"
else
  ml_sw="$(bash "$MUTL/ledger-reverify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null | grep -c . )"
  ml_b5="$(bash "$MUTL/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" 2>/dev/null | grep -c . )"
  ml_ok="$(bash "$MUTL/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null | grep -c . )"
  if [ "$ml_sw" -ne 0 ] || [ "$ml_b5" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the unconditional bail still reported (swapped=%s arg5=%s) — the arms above are vacuous\n' "mutation-bail" "$ml_sw" "$ml_b5"
  elif [ "$ml_ok" -eq 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant produced no rows on a GOOD invocation either, so it is not a clean mutation of the bail alone\n' "mutation-bail"
  else
    printf '  ok    %-22s the unconditional bail silences both caller errors and nothing else (%s rows on a good run)\n' "mutation-bail" "$ml_ok"
  fi
fi

# --- RECEIPTS-UNDECIDED: how much of the STILL-LIVE column this pull actually measured ----
# Both entries are STILL-LIVE, so the status alone cannot separate them. TH-UNDECIDED's
# substring is at BOTH refs (this pull moved neither side of the predicate); TH-DECIDED's
# arrived inside base..theirs. The pair is what makes the tally a finding rather than a count
# of still-live rows.
row_is "Entry TH-UNDECIDED" STILL-LIVE "present at theirs -> stays open, exactly like the control below"
row_is "Entry TH-DECIDED"   STILL-LIVE "also STILL-LIVE, so the STATUS cannot be what distinguishes them"

# The numerator and the denominator are both asserted. A row saying "4 of 4" would be a count of
# still-live theirs_has receipts wearing this row's name; the claim is specifically about the
# subset whose predicate did not move in range.
#
# THE DENOMINATOR IS FIVE, AND WHICH FIVE IS THE POINT. TH-UNDECIDED, TH-DECIDED, the vacuous
# MARKER_A entry, PC-FIXTURE-BARE-BACKTICK's close and PC-FIXTURE-CLEAN-PATH's close. The six
# receipts carrying a backslash (ESCAPED-BACKTICK, LITERAL-BACKSLASH, SECOND-SUBSTRING,
# ESCAPED-QUOTE, ESCAPED-PATH, and REGEX-ANCHOR's theirs_lacks) are REFUSED before the tally and
# must not be in it -- a refused receipt is not a measurement -- so a guard placed after the
# tally increment reads a larger denominator here and fails this arm (built and driven by the
# batch-56 scope hand on the four-seed version: 1 of 6 against a wanted 1 of 4).
ASSERTIONS=$((ASSERTIONS + 1))
und="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{print $3; exit}')"
if grep -q "^1 of 5 'theirs_has' receipt" <<<"$und"; then
  printf '  ok    %-22s 1 of 5 — the control is excluded, the vacuous entry still counts in the total, and the refused anchors do not\n' "undecided-tally"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s want "1 of 5", got: %s\n' "undecided-tally" "${und:-<no row>}"
fi

# It must reach the operator, which means NOT being STILL-LIVE: emit-report.sh filters that one
# status out, and that filter is exactly why this confidence has been invisible.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{n++} END{exit !(n==1)}'; then
  printf '  ok    %-22s exactly one run-scoped row, and its status is not STILL-LIVE\n' "undecided-once"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s want exactly one RECEIPTS-UNDECIDED row\n' "undecided-once"
fi

# SILENT AT ZERO. A ledger whose receipts are all well-anchored must say nothing, or the row is
# decoration on every pull and the operator learns to skip it.
ASSERTIONS=$((ASSERTIONS + 1))
zled="$CONS/_bmad-output/ai-dlc-update/well-anchored-ledger.md"
mkdir -p "$(dirname "$zled")"
printf -- '- **Entry ZA** — anchored on a token that arrived inside base..theirs.\n  verify: theirs_has core/skills/ai-dlc/SKILL.md "MARKER_B"\n' > "$zled"
z_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$zled" 2>/dev/null)"
z_n="$(printf '%s\n' "$z_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
z_live="$(printf '%s\n' "$z_out" | awk -F'\t' '$1=="STILL-LIVE"{c++} END{print c+0}')"
if [ "$z_n" -eq 0 ] && [ "$z_live" -eq 1 ]; then
  printf '  ok    %-22s no row when every receipt moved in range (control: the run still emitted its STILL-LIVE)\n' "undecided-silent"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got %s undecided row(s) and %s still-live on a well-anchored ledger; want 0 and 1\n' "undecided-silent" "$z_n" "$z_live"
fi
rm -f "$zled"

# MUTATION — drop the base-side test, so the tally counts every still-live theirs_has receipt.
# The control entry is then swept in and the row reads "2 of 5": a number that still looks like
# a finding, which is what makes this mutant worth having.
MUTU="$(dirname "$DIST")/mut-undecided"
rm -rf "$MUTU"; mkdir -p "$MUTU"
cp "$(dirname "$CLOSER")"/*.sh "$MUTU/" 2>/dev/null
sed 's@^          base_holds "\$path" "\$subs" && th_undecided=@          th_undecided=@' \
  "$CLOSER" > "$MUTU/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTU/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the tally assertions are unproven\n' "mutation-undecided"
else
  mu_out="$(bash "$MUTU/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  mu_det="$(printf '%s\n' "$mu_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{print $3; exit}')"
  mu_rest="$(printf '%s\n' "$mu_out" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"' | sort)"
  ok_rest="$(printf '%s\n' "$OUT" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"' | sort)"
  if ! grep -q "^2 of 5 'theirs_has' receipt" <<<"$mu_det"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s without the base test the tally read: %s — want "2 of 5", so the control above is vacuous\n' "mutation-undecided" "${mu_det:-<no row>}"
  elif [ "$mu_rest" != "$ok_rest" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved a non-tally row, so it is not a clean mutation of the base test alone\n' "mutation-undecided"
  else
    printf '  ok    %-22s without the base test the control is swept in ("2 of 5") and nothing else moves\n' "mutation-undecided"
  fi
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

# --- THE SHORT ID IS THE FORM UPSTREAM WRITES (PC-S328) ---------------------------------
# The join asked only for the FULL SLUG, and upstream's commits cite `PC-S<n>`. Measured on the
# reference consumer at 0.328.0: the slug search found 20 of 128 entries, while 20 of the 29
# distinct prefixes appeared in upstream's history. Among the misses were three entries that
# consumer had filed and upstream had just fixed — so on the entries where the third signal was
# most needed, it was silent.
row_has "PC-S901-SHORT-ID-UNIQUE-PREFIX" NAMED-UPSTREAM \
  "upstream cites the SHORT id and one entry carries that prefix -> attributed, though the full slug appears nowhere"

# AND THE NAIVE VERSION OF THAT FIX IS WRONG, WHICH IS WHY BOTH HALVES ARE ASSERTED. Of the 20
# cited prefixes on the reference consumer, 11 were shared by two or more entries. Matching the
# prefix regardless would name every entry the sprint filed.
row_lacks "PC-S902-SHARED-PREFIX-FIRST" NAMED-UPSTREAM \
  "a prefix carried by two entries is NOT attributed to either — a wrong close is worse than the silence it replaces"
row_lacks "PC-S902-SHARED-PREFIX-SECOND" NAMED-UPSTREAM \
  "and not to the other one either — the refusal is symmetric, not first-wins"
row_has "PC-S902" NAMED-UPSTREAM-AMBIGUOUS \
  "the shared prefix is reported ONCE, keyed on the prefix itself, because the prefix is the subject"

# ONE ROW, NOT ONE PER ENTRY. Per-entry emission produced 45 rows from 11 prefixes on the
# reference consumer, all saying the same unresolvable thing — noise added by the fix for a
# signal that was missing, which is the trade the naive prefix-match makes one level along.
ambig_n="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM-AMBIGUOUS"{n++} END{print n+0}')"
ASSERTIONS=$((ASSERTIONS+1))
if [ "$ambig_n" = "1" ]; then
  printf '  ok    %-22s exactly one ambiguous row for the two entries sharing PC-S902\n' "ambiguous-collapse"
else
  printf '  FAIL  %-22s %s ambiguous row(s) — the prefix fact is being repeated per entry\n' "ambiguous-collapse" "$ambig_n"
  FAILURES=$((FAILURES+1))
fi

# THE CONTROL, and without it the two arms above only prove the code runs. An id-shaped label
# with a unique prefix that upstream names in NEITHER form must stay silent.
row_lacks "PC-S903-NEVER-CITED-AT-ALL" NAMED-UPSTREAM \
  "never cited in either form -> silent, so the prefix arm joins on evidence and not on shape"
row_lacks "PC-S903-NEVER-CITED-AT-ALL" NAMED-UPSTREAM-AMBIGUOUS \
  "and not reported as ambiguous either — an uncited prefix is not an unresolvable one"

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
# EVERY SEARCH, and KEYED ON THE THING BEING BOUNDED rather than on the grep expression.
# `named_absorbed` falls back to the SHORT id when the full slug finds nothing, `named_ambiguous`
# asks the same two questions again, and each is its own `git log`. Bounding only some of them is a
# PARTIAL revert, which proves the layer left in place and comes out looking like a surviving
# mutant — the failure mode this arm's predecessor actually hit.
#
# THE EARLIER FORM MATCHED ON `--grep="$_pfx"` AND A FIX TO THE GREP EXPRESSION SILENTLY DODGED IT.
# When the prefix searches were anchored (`-E --grep="${_pfx}([^0-9A-Za-z-]|\$)"`), the sed pattern
# stopped matching, the prefix arms stayed unbounded in the mutant, and this arm reported a
# surviving named row. It failed LOUDLY, which is why the mutant is keyed on the REF ARGUMENT of
# a `--format=` search — the ref IS what bounding changes, it is identical at every search site,
# and it does not move when a grep expression is rewritten. `git log -S` at :269 is already
# range-bounded and carries no bare `"$THEIRS"`, so it is untouched.
#
# AND THE FORMAT LETTER IS NOT PART OF THE ANCHOR, WHICH IS A SECOND INSTANCE OF THE SAME LESSON.
# The pattern was `--format=%H "$THEIRS"` spelled out. When `named_absorbed`'s two searches moved
# to `--format=%h` — because the function now emits abbreviated shas directly instead of walking
# them through `rev-parse --short` — the sed stopped matching THOSE TWO lines while still matching
# `named_ambiguous`'s. `MUTB_LEFT` counted the same spelling, so it read 0 and the guard passed:
# a HALF-bounded mutant, reported by this arm as six surviving named rows. The class is the one
# the paragraph above already names, caught a second time by its own leftover-count guard. `%[hH]`
# is what the site means — a `git log` asking for shas at the tip — and the leftover count is now
# keyed the same way, so the two cannot drift apart.
sed -E -e 's@(--format=%[hH]) "\$THEIRS"@\1 "\$\{BASE\}\.\.\$\{THEIRS\}"@g' \
  "$CLOSER" > "$MUTB/ledger-reverify.sh"
# The mutation must have hit EVERY search, or a partial revert reads as a surviving mutant again.
MUTB_HITS="$(LC_ALL=C grep -c -E -- '--format=%[hH] "\$\{BASE\}\.\.\$\{THEIRS\}"' "$MUTB/ledger-reverify.sh" || true)"
MUTB_LEFT="$(LC_ALL=C grep -c -E -- '--format=%[hH] "\$THEIRS"' "$MUTB/ledger-reverify.sh" || true)"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTB/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the unbounded-search assertion is unproven\n' "mutation-bound"
elif [ "${MUTB_LEFT:-1}" -ne 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s search(es) left UNBOUNDED by the mutation (%s bounded) — a partial revert proves the layer left in place\n' \
    "mutation-bound" "$MUTB_LEFT" "${MUTB_HITS:-0}"
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
# COMPARED TO THE IN-PLACE RUN, NOT TO A LITERAL, and with a FLOOR beside it. The literal was 3
# and it went stale the moment the seed grew the PC-S904/905/906 trio below; a hand-written total
# in a control is a number that decays silently and then reads as a real kill. Equality is the
# property being asserted — a byte-identical copy must agree with the detector in place — and the
# floor is what stops two silences agreeing.
own_named="$(printf '%s\n' "$OUT" | awk -F'\t' '$1 == "NAMED-UPSTREAM" {c++} END{print c+0}')"
if [ "$ctl_named" -eq "$own_named" ] && [ "$own_named" -ge 3 ]; then
  printf '  ok    %-22s unmutated copy in the same directory emits the same %s named rows (harness is sound)\n' "mutation-control" "$own_named"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s unmutated copy emitted %s named rows against %s in place (want equal, and >= 3) — a copy that cannot run scores as a kill\n' "mutation-control" "$ctl_named" "$own_named"
fi

# --- EVERY NAMING COMMIT IS LISTED, AND NO END IS ELECTED --------------------------------
# THE DEFECT. The row reported the NEWEST and the OLDEST commit whose message names the id and
# nothing between them, so for n > 2 the middle commits were never shown — and the two ends are
# the WORST pair to elect. The oldest mention of an id is the commit that FILED it, or a plan;
# the newest is the withdrawal or the docs commit written after the fix landed. Measured over the
# reference consumer's 65 live ledger ids against this distribution's history: 21 have at least
# one naming commit, 12 have more than one, and in 5 of those 12 NEITHER advertised end is a
# `fix`/`feat` commit. Control in the same run: an impossible id returns 0 commits.
#
# THE EXPECTED SET IS DERIVED FROM THE REPO, NEVER READ OFF THE ROW. A count taken from a
# rendering is not a derived count, and an arm that parses the row it is testing agrees with
# itself whatever the row says. `named_set` asks git the question the subject asks and
# abbreviates each sha the way the subject does, so what follows compares two independently
# computed sets.
named_set() { # <id> -> newline-separated SHORT shas, newest first
  local _h
  for _h in $(git -C "$DIST" log -F --grep="$1" --format=%H "$THEIRS" 2>/dev/null); do
    git -C "$DIST" rev-parse --short "$_h" 2>/dev/null
  done
}
named_detail() { # <rows> <id> -> field 3 of that id's NAMED-UPSTREAM row, or empty
  printf '%s\n' "$1" | awk -F'\t' -v l="^$2\$" '$1=="NAMED-UPSTREAM" && $2 ~ l {print $3; exit}'
}
# <rows> <id> -> how many of that id's naming shas are ABSENT from its row, or NOROW.
# NOROW is distinguished from 0 deliberately: a row that never appeared hides nothing and reports
# nothing, and scoring it as "no shas missing" is how a subject emitting silence sweeps an
# absence-shaped arm clean.
named_missing() {
  local _detail _s _miss=0
  _detail="$(named_detail "$1" "$2")"
  [ -n "$_detail" ] || { printf 'NOROW'; return 0; }
  for _s in $(named_set "$2"); do
    case "$_detail" in *"$_s"*) : ;; *) _miss=$((_miss + 1)) ;; esac
  done
  printf '%s' "$_miss"
}
# Does this id's row carry this sha? Used to say WHICH sha a mutant kept, so two mutants that
# both drop one sha are scored on different observables instead of on the same one.
named_has_sha() { case "$(named_detail "$1" "$2")" in *"$3"*) return 0 ;; *) return 1 ;; esac; }

# PRECONDITION — THE MOTIVATING SHAPE, ASSERTED AGAINST THE REPO AND NOT AGAINST ANY ROW.
# Three commits must name PC-S904, the MIDDLE one must be the commit that touched a subject, and
# NEITHER end may have. Without that shape the arm below still prints ok while testing nothing:
# at n <= 2 there is no middle commit to hide and the two-ends form and the whole-set form are the
# same string, so a seed that drifts to n = 2 would silently retire the case it exists for.
#
# THIS IS THE ONE ARM HERE THAT READS NO OUTPUT OF THE SUBJECT, which is why it is labelled a
# precondition: it would print ok against a subject replaced by `exit 0`. What stops that from
# mattering is that every other arm in this block is PRESENCE-shaped — each requires a specific
# row and a specific sha to appear — so silence fails them by construction.
s904_id=PC-S904-ABSORBED-IN-THE-MIDDLE-COMMIT
s905_id=PC-S905-ONE-NAMING-COMMIT-ONLY
s906_id=PC-S906-TWO-NAMING-COMMITS-NOTHING-HIDDEN
s904_shas="$(named_set "$s904_id")"
s904_n="$(printf '%s\n' "$s904_shas" | grep -c . )"
s904_new="$(printf '%s\n' "$s904_shas" | sed -n '1p')"
s904_mid="$(printf '%s\n' "$s904_shas" | sed -n '2p')"
s904_old="$(printf '%s\n' "$s904_shas" | sed -n '3p')"
s906_shas="$(named_set "$s906_id")"
s906_new="$(printf '%s\n' "$s906_shas" | sed -n '1p')"
s906_old="$(printf '%s\n' "$s906_shas" | sed -n '2p')"
# NO PIPE INTO `grep -q`. `git show --name-only` is fed into a command substitution and matched
# with `case`, per this repo's standing rule about a reader that leaves before the writer has
# finished; the output is small here, and the point is that the shape is correct anywhere.
s904_touched() { case "$(git -C "$DIST" show --format= --name-only "$1" 2>/dev/null)" in
    *core/scripts/s904-subject.sh*) return 0 ;; *) return 1 ;; esac; }
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$s904_n" -ne 3 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s commit(s) name %s, want 3 — below three there is no middle commit, and the two forms are the same string\n' "named-seed-shape" "$s904_n" "$s904_id"
elif s904_touched "$s904_new" || s904_touched "$s904_old"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s an END of the range is the absorbing commit, so electing the two ends would have been RIGHT here and the arm below tests nothing\n' "named-seed-shape"
elif ! s904_touched "$s904_mid"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the MIDDLE commit %s did not touch core/scripts/s904-subject.sh, so no commit in this range absorbed the entry\n' "named-seed-shape" "${s904_mid:-<none>}"
else
  printf '  ok    %-22s 3 commits name PC-S904; the MIDDLE one (%s) absorbed it and NEITHER end (%s newest, %s oldest) did\n' "named-seed-shape" "$s904_mid" "$s904_new" "$s904_old"
fi

# THE ARM. Every sha that names an id must appear in that id's row. The offender and BOTH
# near-misses are read out of the SAME `$OUT`: PC-S904 at n=3 with one commit the two ends cannot
# reach, PC-S906 at n=2 where the two ends ARE the whole set, and PC-S905 at n=1. The three carry
# byte-identical receipts and emit two rows each, so the run is the same size whichever is being
# read — an implementation that branches on `n > 1` and never reads a sha treats PC-S904 and
# PC-S906 identically and cannot pass this. Held in one arm on purpose: each mutant below is then
# a single failure rather than three entangled ones.
ASSERTIONS=$((ASSERTIONS + 1))
m904="$(named_missing "$OUT" "$s904_id")"
m905="$(named_missing "$OUT" "$s905_id")"
m906="$(named_missing "$OUT" "$s906_id")"
if [ "$m904" = NOROW ] || [ "$m905" = NOROW ] || [ "$m906" = NOROW ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a NAMED-UPSTREAM row is MISSING (904=%s 905=%s 906=%s) — a row that never appeared hides nothing and reports nothing, so this arm cannot discriminate\n' "named-lists-all" "$m904" "$m905" "$m906"
elif [ "$m904" -eq 0 ] && [ "$m905" -eq 0 ] && [ "$m906" -eq 0 ]; then
  printf '  ok    %-22s every naming sha is on its row — 3 for PC-S904 (the middle one included), 2 for PC-S906, 1 for PC-S905\n' "named-lists-all"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s naming shas ABSENT from their rows: PC-S904 %s of 3, PC-S906 %s of 2, PC-S905 %s of 1. A commit the row does not name is a commit the operator never reads\n' "named-lists-all" "$m904" "$m906" "$m905"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM"{print $2"  "substr($3,1,120)}' | sed 's/^/          | /'
fi

# AND THE STATED COUNT MUST AGREE WITH THE LIST. A row saying "in 3 commits" while carrying two
# shas sends the operator looking for a commit the row does not name, which is the same injury in
# the other direction. Both spellings the row uses are accepted — the assertion is that the two
# NUMBERS agree, not that either is phrased a particular way — and a row that states no count at
# all fails, because "is this list complete" is then unanswerable from the row.
ASSERTIONS=$((ASSERTIONS + 1))
stated_count() { # <rows> <id> -> integer, or empty when the row states no count
  local _d
  _d="$(named_detail "$1" "$2")"
  case "$_d" in
    *"in one commit"*) printf '1' ;;
    *) printf '%s' "$_d" | sed -n 's/.*NAMES this entry.s id in \([0-9][0-9]*\) commits.*/\1/p' ;;
  esac
}
c904="$(stated_count "$OUT" "$s904_id")"
c905="$(stated_count "$OUT" "$s905_id")"
c906="$(stated_count "$OUT" "$s906_id")"
if [ -z "$c904" ] || [ -z "$c905" ] || [ -z "$c906" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a row states no commit count at all (904=[%s] 905=[%s] 906=[%s]) — without one the operator cannot tell a complete list from a truncated one\n' "named-count-agrees" "$c904" "$c905" "$c906"
elif [ "$c904" = "3" ] && [ "$c906" = "2" ] && [ "$c905" = "1" ]; then
  printf '  ok    %-22s the stated counts are 3 / 2 / 1 and each matches the number of shas the row carries\n' "named-count-agrees"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s stated counts 904=%s 906=%s 905=%s against derived 3 / 2 / 1 — the row is telling the operator to read a different number of commits than it names\n' "named-count-agrees" "$c904" "$c906" "$c905"
fi

# --- FOUR MUTANTS, ALL ANCHORED ON THE SLUG SEARCH --------------------------------------------
# KEYED ON LOCATION, NOT ON A SPELLING, and on the ONE line that decides which commits exist as
# far as this row is concerned. Everything downstream — the count, the list, the branch, the
# sentence — is a rendering of that line's output, so a mutant here cannot be dodged by rewording
# the row, and it survives the row being reworded. Each is a PIPELINE spliced into that line, so
# each states its election as a behaviour rather than as a form of words.
#
# THE ANCHOR IS RESOLVED OUT OF THE FILE, NOT SPELLED OUT HERE, and that is a measurement rather
# than a preference. The first draft of this block spelled the line
# `--format=%H "$THEIRS"`; the detector then moved its two `named_absorbed` searches to
# `--format=%h` — same query, abbreviated shas asked of git instead of walked through
# `rev-parse --short` — and all three mutants below stopped applying in the same run. `cmp -s`
# caught it, which is the guard working, but a mutant that stops mutating on a REWORDING is a
# mutant keyed on a spelling, and this file's own `mutation-bound` arm was carrying the identical
# defect twenty lines up. So the line is located by what it IS — the assignment of `_hits` from a
# fixed-string `git log --grep` on the entry's own id — and whatever bytes that line currently
# holds are the anchor.
#
# THE PATTERN SEPARATES THREE NEARLY IDENTICAL LINES. `named_ambiguous` runs the same query and
# assigns it to `_slug_hit`; the prefix fallback in this same function assigns `_hits` from an
# `-E` search on the SHORT id. The assignment target and `-F --grep="$_id"` together pick exactly
# one, and the arm below asserts that it picked exactly one before any mutant is built.
NAMED_ANCHOR="$(LC_ALL=C awk '/^  _hits="\$\(git .*log -F --grep="\$_id"/' "$CLOSER")"
anchor_n="$(printf '%s\n' "$NAMED_ANCHOR" | grep -c . )"
ASSERTIONS=$((ASSERTIONS + 1))
# AND IT MUST END IN `)"`, because the three mutants below splice a pipeline in just before that
# close. Asserted rather than assumed: a line ending some other way would be truncated by two
# characters and every mutant would be a syntax error, which emits nothing — and "no rows" is
# what a kill looks like.
case "$NAMED_ANCHOR" in *')"') anchor_tail=ok ;; *) anchor_tail=no ;; esac
if [ "$anchor_n" -eq 1 ] && [ "$anchor_tail" = ok ]; then
  printf '  ok    %-22s the slug search resolves to exactly one line, ending in )" as the mutants require: %s\n' "named-anchor-unique" "$(printf '%s' "$NAMED_ANCHOR" | sed 's/^  //')"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the slug search resolved to %s line(s) (want 1) with a spliceable tail=%s — the three mutants below would edit the wrong site, or nothing at all\n' "named-anchor-unique" "$anchor_n" "$anchor_tail"
fi

# $1 tag, $2 a pipeline spliced into the resolved line just inside its closing `)"` -> prints the
# mutant's output on stdout, or nothing if the mutation did not apply. The caller checks the empty
# case, and `cmp -s` is what makes a substitution that matched nothing fail rather than pass.
named_mutant() {
  local _tag="$1" _pipe="$2" _d
  _d="$(dirname "$DIST")/mut-named-$_tag"
  rm -rf "$_d"; mkdir -p "$_d"
  cp "$(dirname "$CLOSER")"/*.sh "$_d/" 2>/dev/null
  awk -v anchor="$NAMED_ANCHOR" -v pipe="$_pipe" '
    $0 == anchor { print substr($0, 1, length($0) - 2) " " pipe ")\""; next }
    { print }' "$CLOSER" > "$_d/ledger-reverify.sh"
  cmp -s "$CLOSER" "$_d/ledger-reverify.sh" && return 1
  bash "$_d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1
}

# MUTANT A — `| head -1`, the newest-only election. PC-S906 must lose its OLDER sha and KEEP its
# newest; PC-S905 must be untouched, or the mutant blinded the search rather than truncating it.
ASSERTIONS=$((ASSERTIONS + 1))
ma_out="$(named_mutant head '| head -1')" || ma_out=""
if [ -z "$ma_out" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation did not apply, or the mutant emitted nothing — either way the list assertion is unproven\n' "mutation-named-head"
elif [ "$(named_missing "$ma_out" "$s905_id")" != "0" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutant also dropped the single-commit id PC-S905, so it broke the search instead of truncating it\n' "mutation-named-head"
elif [ "$(named_missing "$ma_out" "$s906_id")" = "1" ] && named_has_sha "$ma_out" "$s906_id" "$s906_new" ; then
  printf '  ok    %-22s newest-only: PC-S906 keeps %s and loses %s, PC-S905 unmoved — the arm sees a dropped sha\n' "mutation-named-head" "$s906_new" "$s906_old"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s newest-only left PC-S906 missing %s sha(s) and newest-present=%s (want 1 and yes) — named-lists-all cannot see an election\n' \
    "mutation-named-head" "$(named_missing "$ma_out" "$s906_id")" "$(named_has_sha "$ma_out" "$s906_id" "$s906_new" && echo yes || echo no)"
fi

# MUTANT B — `| tail -1`, the OLDEST-only election, which is the shape this code actually shipped.
# Scored on the OPPOSITE observable to mutant A: the sha PC-S906 keeps must be its OLDEST. Without
# that half the two mutants would be graded on one fact and one of them would be proving nothing.
ASSERTIONS=$((ASSERTIONS + 1))
mb2_out="$(named_mutant tail '| tail -1')" || mb2_out=""
if [ -z "$mb2_out" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation did not apply, or the mutant emitted nothing — the oldest-only election is unproven\n' "mutation-named-tail"
elif [ "$(named_missing "$mb2_out" "$s905_id")" != "0" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutant also dropped the single-commit id PC-S905, so it broke the search instead of truncating it\n' "mutation-named-tail"
elif [ "$(named_missing "$mb2_out" "$s906_id")" = "1" ] && named_has_sha "$mb2_out" "$s906_id" "$s906_old" ; then
  printf '  ok    %-22s oldest-only (the shipped defect): PC-S906 keeps %s and loses %s, PC-S905 unmoved\n' "mutation-named-tail" "$s906_old" "$s906_new"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s oldest-only left PC-S906 missing %s sha(s) and oldest-present=%s (want 1 and yes)\n' \
    "mutation-named-tail" "$(named_missing "$mb2_out" "$s906_id")" "$(named_has_sha "$mb2_out" "$s906_id" "$s906_old" && echo yes || echo no)"
fi

# MUTANT C — `| head -2`, which is THE TWO-ENDS DEFECT ITSELF wearing a different hat: it reports
# two commits for an id that has three and says nothing about the third. It is the only one of the
# three the NEAR-MISS cannot see — PC-S906 has exactly two naming commits, so its row is
# byte-unchanged — and that asymmetry is the point. An arm satisfiable by the n=2 case alone would
# score this mutant green, and the whole reason PC-S904 is in the seed is that at n=3 a truncation
# to two becomes visible at all.
ASSERTIONS=$((ASSERTIONS + 1))
mc2_out="$(named_mutant maxcount '| head -2')" || mc2_out=""
if [ -z "$mc2_out" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation did not apply, or the mutant emitted nothing — the n>2 case is unproven\n' "mutation-named-maxcount"
elif [ "$(named_missing "$mc2_out" "$s906_id")" != "0" ] || [ "$(named_missing "$mc2_out" "$s905_id")" != "0" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s truncating at two also moved PC-S906 (%s missing) or PC-S905 (%s missing) — it is not a clean mutation of the n>2 case alone\n' \
    "mutation-named-maxcount" "$(named_missing "$mc2_out" "$s906_id")" "$(named_missing "$mc2_out" "$s905_id")"
elif [ "$(named_missing "$mc2_out" "$s904_id")" = "1" ] && ! named_has_sha "$mc2_out" "$s904_id" "$s904_old" ; then
  printf '  ok    %-22s truncating at two loses PC-S904'"'"'s oldest naming commit %s while PC-S906 and PC-S905 do not move — only n>2 can see this\n' "mutation-named-maxcount" "$s904_old"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s PC-S904 lost %s sha(s) under a two-commit truncation (want 1, and it must be the oldest %s) — the n>2 half of the arm is vacuous\n' \
    "mutation-named-maxcount" "$(named_missing "$mc2_out" "$s904_id")" "$s904_old"
fi

# MUTANT D — `| sed -n '1p;$p'`, WHICH IS THE DEFECT ITSELF. Keeping only the first and last line
# of the match set is exactly what "newest X and oldest Y" reported, expressed as a behaviour on
# the search rather than as a form of words in the row, so this mutant survives every future
# rewording of the sentence. It is the case the whole block exists for: the sha it hides is the
# MIDDLE one, which is the commit that actually absorbed the entry, and PC-S906 and PC-S905 are
# byte-unchanged because at n <= 2 the two ends ARE the whole set.
#
# THIS IS THE ONE MUTANT THE NEAR-MISS ALONE COULD NEVER KILL. Run against PC-S906 by itself it
# changes nothing at all — which is what makes PC-S904's presence in the same ledger, at the same
# receipt and in the same run, the thing being tested rather than a decoration.
ASSERTIONS=$((ASSERTIONS + 1))
md2_out="$(named_mutant twoends "| sed -n '1p;\$p'")" || md2_out=""
if [ -z "$md2_out" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation did not apply, or the mutant emitted nothing — the two-ends election is unproven and this arm has never been shown to fire\n' "mutation-named-twoends"
elif [ "$(named_missing "$md2_out" "$s906_id")" != "0" ] || [ "$(named_missing "$md2_out" "$s905_id")" != "0" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s electing the two ends also moved PC-S906 (%s missing) or PC-S905 (%s missing), where the ends ARE the whole set — the mutant broke the search rather than electing\n' \
    "mutation-named-twoends" "$(named_missing "$md2_out" "$s906_id")" "$(named_missing "$md2_out" "$s905_id")"
elif [ "$(named_missing "$md2_out" "$s904_id")" = "1" ] && ! named_has_sha "$md2_out" "$s904_id" "$s904_mid" \
     && named_has_sha "$md2_out" "$s904_id" "$s904_new" && named_has_sha "$md2_out" "$s904_id" "$s904_old" ; then
  printf '  ok    %-22s the two-ends election hides exactly the ABSORBING commit %s while advertising the withdrawal %s and the handoff %s — PC-S906 and PC-S905 do not move\n' "mutation-named-twoends" "$s904_mid" "$s904_new" "$s904_old"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s PC-S904 lost %s sha(s) under the two-ends election and middle-present=%s (want 1 missing, and it must be the middle %s) — the arm is not watching the commit that did the work\n' \
    "mutation-named-twoends" "$(named_missing "$md2_out" "$s904_id")" "$(named_has_sha "$md2_out" "$s904_id" "$s904_mid" && echo yes || echo no)" "$s904_mid"
fi

# NO TWO OF THE FOUR MUTANTS MAY PRODUCE THE SAME OUTPUT. Two mutants with byte-identical output
# are one mutant counted twice, and the second one proves nothing while reading as extra coverage.
# `| head -2` and `| sed -n '1p;$p'` differ ONLY at n > 2 and would have collapsed into one here if
# PC-S904 were not in the seed; `| head -1` and `| tail -1` differ only in WHICH sha survives. The
# unmutated control is compared too: a mutant that agrees with it did not mutate anything
# observable.
# THE UNMUTATED SIDE IS `$OUT` ITSELF, not a fourth invocation. The three mutants are copies of
# the detector run against this same seed with the same four arguments, so `$OUT` is exactly what
# each of them would have printed had its `sed` matched nothing — which is the comparison being
# made, and it costs no extra run of the subject.
ASSERTIONS=$((ASSERTIONS + 1))
mdist_ctl="$OUT"
mdist_dupe=""
[ "$ma_out"  = "$mb2_out"   ] && mdist_dupe="${mdist_dupe} head=tail"
[ "$ma_out"  = "$mc2_out"   ] && mdist_dupe="${mdist_dupe} head=head2"
[ "$ma_out"  = "$md2_out"   ] && mdist_dupe="${mdist_dupe} head=twoends"
[ "$mb2_out" = "$mc2_out"   ] && mdist_dupe="${mdist_dupe} tail=head2"
[ "$mb2_out" = "$md2_out"   ] && mdist_dupe="${mdist_dupe} tail=twoends"
[ "$mc2_out" = "$md2_out"   ] && mdist_dupe="${mdist_dupe} head2=twoends"
[ "$ma_out"  = "$mdist_ctl" ] && mdist_dupe="${mdist_dupe} head=unmutated"
[ "$mb2_out" = "$mdist_ctl" ] && mdist_dupe="${mdist_dupe} tail=unmutated"
[ "$mc2_out" = "$mdist_ctl" ] && mdist_dupe="${mdist_dupe} head2=unmutated"
[ "$md2_out" = "$mdist_ctl" ] && mdist_dupe="${mdist_dupe} twoends=unmutated"
if [ -z "$mdist_ctl" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the unmutated control emitted nothing, so "every mutant differs from it" is satisfied by wreckage\n' "named-mutants-distinct"
elif [ -z "$mdist_dupe" ]; then
  printf '  ok    %-22s the four mutants and the unmutated control produce five different outputs\n' "named-mutants-distinct"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s byte-identical output between:%s — a duplicated mutant reads as coverage and is not\n' "named-mutants-distinct" "$mdist_dupe"
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
#
# RE-ANCHORED, AND THE OLD ANCHOR'S DEATH IS THE POINT. The arm used to key on
# `label ~ /:$/ && !idshape(label)`, one conjunction inside a single `if`. The colon test is
# now a BRANCH SELECTOR — `if (label ~ /:$/)` picks the colon row and `else if (…)` picks the
# capture row — so the old anchor matched nothing and this arm went red rather than quiet.
# That is the `cmp -s` guard working exactly as designed and it is deliberately kept: the
# alternative reading of a vanished anchor is a mutation that silently stops mutating, which
# reads identically to a discriminator that is load-bearing.
MUTC="$(dirname "$DIST")/mut-colon"
rm -rf "$MUTC"; mkdir -p "$MUTC"
cp "$(dirname "$CLOSER")"/*.sh "$MUTC/" 2>/dev/null
sed 's@if (label ~ /:\$/)@if (1)@' "$CLOSER" > "$MUTC/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTC/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the colon discriminator is unproven\n' "mutation-colon"
else
  mc_out="$(bash "$MUTC/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  # BOTH HALVES. Without the second the arm scores a kill for a mutant that broke the whole
  # ENTRY-SWALLOWED block — an emitter that died prints no prose row either, and "no row for
  # a-real-entry" would then read as the colon test doing its job.
  mc_fp="$(printf '%s\n' "$mc_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /a-real-entry/{f=1} END{print f+0}')"
  mc_tp="$(printf '%s\n' "$mc_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /The derivation/{f=1} END{print f+0}')"
  if [ "$mc_fp" = 1 ] && [ "$mc_tp" = 1 ]; then
    printf '  ok    %-22s without the colon test a prose-titled entry is falsely reported — it is load-bearing\n' "mutation-colon"
  elif [ "$mc_tp" != 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost the genuine colon row too, so it is not a clean mutation of the colon test alone\n' "mutation-colon"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s dropping the colon test did NOT re-fire the prose entry, so the control above is vacuous\n' "mutation-colon"
  fi
fi

# --- BL-013: THE NO-COLON SWALLOW, WHICH THE COLON SIGNAL CANNOT SEE ----------------------
# The colon gate fires ZERO times on every corpus available — the reference consumer's live
# ledger and archive, and both distribution backlog files — while those same corpora carry
# annotation bullets that really are swallowing entries. An annotation whose bold span does
# NOT end in a colon truncates the entry above it exactly as a colon one does, captures its
# receipt, and produced no row anywhere until the second signal existed.
row_has "False CLOSE-CANDIDATE" ENTRY-SWALLOWED \
  "a NO-COLON annotation that captured a receipt is REPORTED — the colon signal is blind to this one"

ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /False CLOSE-CANDIDATE/ && $3 ~ /PC-FIXTURE-NO-COLON-SWALLOWED/{f=1} END{exit !f}'; then
  printf '  ok    %-22s names the entry that went dark, so the operator has a subject and not just a complaint\n' "no-colon-names-entry"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s reported the no-colon swallow without naming PC-FIXTURE-NO-COLON-SWALLOWED\n' "no-colon-names-entry"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"' | sed 's/^/          | /'
fi

# AND IT MUST DISCRIMINATE, or the arm above is satisfied by a detector that reports every
# non-id bullet carrying a receipt. Predicate (2) ALONE — a receipt under a non-id label —
# reports 11 rows on the reference consumer's live ledger; the conjunction reports 1. These
# three are the classes the conjunction subtracts, and each is a REAL entry.
row_lacks "Second no-colon prose bullet" ENTRY-SWALLOWED \
  "the entry above emitted its OWN row (its receipt sits ABOVE the annotation) — nothing was lost, so nothing is reported"
row_lacks "legacy-entry.sh" ENTRY-SWALLOWED \
  "a real id-less entry below a CLOSED one stays silent: a closed entry emits no row BY DESIGN, so 'no row above' is true of every entry that follows a close"
row_lacks "PC-FIXTURE-ID_WITH.PUNCT-AT-0.242.0" ENTRY-SWALLOWED \
  "an id carrying '_' and '.' is an ID, not an annotation — the two shapes the reference consumer really files"

# ...and that last one is a REAL entry, so it must still report its own verdict. A silence
# bought by the entry disappearing from the classifier is not the silence being asserted.
row_is "PC-FIXTURE-ID_WITH.PUNCT-AT-0.242.0" STILL-LIVE \
  "and it is classified normally — the id rule keeps it visible rather than merely unreported"

# MUTATION — the ID RULE'S ANCHOR. `idshape()` required `^[A-Z0-9-]+$`: a FULL-STRING match
# that admits neither `_` nor `.`. Restoring it makes a real entry read as an annotation and
# the capture arm fires on it.
#
# THE MUTATION IS ON THE ANCHOR, NOT ON THE CHARACTER CLASS, AND THAT IS A MEASUREMENT AND NOT
# A PREFERENCE. `ledger_entry_id()` is a PREFIX match, so narrowing its class back to
# `[A-Z0-9-]` still matches `PC-S330-PREPUSH-LEAKS-GIT` and still returns non-empty — the id
# verdict does not move. Measured over 349 boundary lines in the reference consumer's live
# ledger and archive, its degradation ledger and both distribution backlog files: reverting
# the class alone changes ZERO verdicts, while reverting to the anchored old rule changes 3.
# A class-only mutant would have survived, and a surviving mutant reads exactly like an arm
# that cannot fire.
MUTI="$(dirname "$DIST")/mut-idrule"
rm -rf "$MUTI"; mkdir -p "$MUTI"
cp "$(dirname "$CLOSER")"/*.sh "$MUTI/" 2>/dev/null
sed 's@if (match(label, /\^`?(PC|BL)-\[A-Za-z0-9_\.-\]+/))@if (match(label, /^[A-Z0-9-]+$/))@' \
  "$(dirname "$CLOSER")/lib.sh" > "$MUTI/lib.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$(dirname "$CLOSER")/lib.sh" "$MUTI/lib.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing in lib.sh, so the id rule is unproven\n' "mutation-idrule"
else
  mi_out="$(bash "$MUTI/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mi_hit="$(printf '%s\n' "$mi_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-ID_WITH.PUNCT/{f=1} END{print f+0}')"
  mi_ctl="$(printf '%s\n' "$mi_out" | awk -F'\t' '$2 ~ /Entry B/ && $1=="CLOSE-CANDIDATE"{f=1} END{print f+0}')"
  if [ "$mi_ctl" != 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutated lib.sh broke the classifier outright (Entry B lost its verdict), so its silence is not attributable\n' "mutation-idrule"
  elif [ "$mi_hit" = 1 ]; then
    printf '  ok    %-22s the anchored id rule reads a real _-bearing entry as an annotation — the fix is load-bearing\n' "mutation-idrule"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s restoring the anchored id rule did NOT misread the _-bearing entry, so the id assertion is vacuous\n' "mutation-idrule"
  fi
fi

# MUTATION — drop `!prev_id_closed` from the conjunction, and ONLY that clause. A closed entry
# is skipped by the classifier, so it emits no row by design; without this clause every real
# entry that follows a close is reported as an annotation that ate its neighbour's receipt.
# This is a REVERT OF ONE LAYER of a layered change, which is why it is its own mutant rather
# than a second assertion on the one above.
MUTP="$(dirname "$DIST")/mut-prevclosed"
rm -rf "$MUTP"; mkdir -p "$MUTP"
cp "$(dirname "$CLOSER")"/*.sh "$MUTP/" 2>/dev/null
sed 's@ && !prev_id_closed)@)@' "$CLOSER" > "$MUTP/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTP/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the !prev_id_closed clause is unproven\n' "mutation-prevclosed"
else
  mp_out="$(bash "$MUTP/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mp_hit="$(printf '%s\n' "$mp_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /legacy-entry/{f=1} END{print f+0}')"
  mp_tp="$(printf '%s\n' "$mp_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /False CLOSE-CANDIDATE/{f=1} END{print f+0}')"
  if [ "$mp_tp" != 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost the genuine no-colon row too, so it is not a clean revert of the clause alone\n' "mutation-prevclosed"
  elif [ "$mp_hit" = 1 ]; then
    printf '  ok    %-22s without !prev_id_closed a real entry below a close is falsely reported — the clause is load-bearing\n' "mutation-prevclosed"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s dropping !prev_id_closed did NOT re-fire the entry below the close, so that control is vacuous\n' "mutation-prevclosed"
  fi
fi

# MUTATION — drop `!prev_id_hadv`, the clause that keeps the BENIGN direction quiet. Without it
# an entry whose own receipt sits ABOVE an annotation — which loses nothing — is reported.
MUTH="$(dirname "$DIST")/mut-prevhadv"
rm -rf "$MUTH"; mkdir -p "$MUTH"
cp "$(dirname "$CLOSER")"/*.sh "$MUTH/" 2>/dev/null
sed 's@ && !prev_id_hadv@@' "$CLOSER" > "$MUTH/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTH/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the !prev_id_hadv clause is unproven\n' "mutation-prevhadv"
else
  mh_out="$(bash "$MUTH/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mh_hit="$(printf '%s\n' "$mh_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /Second no-colon prose bullet/{f=1} END{print f+0}')"
  mh_tp="$(printf '%s\n' "$mh_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /False CLOSE-CANDIDATE/{f=1} END{print f+0}')"
  if [ "$mh_tp" != 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost the genuine no-colon row too, so it is not a clean revert of the clause alone\n' "mutation-prevhadv"
  elif [ "$mh_hit" = 1 ]; then
    printf '  ok    %-22s without !prev_id_hadv the benign direction is falsely reported — the clause is load-bearing\n' "mutation-prevhadv"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s dropping !prev_id_hadv did NOT re-fire the benign case, so that control is vacuous\n' "mutation-prevhadv"
  fi
fi

# THE UNMUTATED CONTROL FOR THIS BATTERY. Four mutant directories above are COPIES; a copy that
# cannot source lib.sh emits nothing at all, and "no ENTRY-SWALLOWED row" would score as a kill
# for every false-positive assertion here. This copy is byte-identical, so it must agree with
# $OUT exactly.
ASSERTIONS=$((ASSERTIONS + 1))
CTLS="$(dirname "$DIST")/ctl-swallow"
rm -rf "$CTLS"; mkdir -p "$CTLS"
cp "$(dirname "$CLOSER")"/*.sh "$CTLS/" 2>/dev/null
ctl_sw="$(bash "$CTLS/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1 | awk -F'\t' '$1=="ENTRY-SWALLOWED"{c++} END{print c+0}')"
own_sw="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"{c++} END{print c+0}')"
if [ "$ctl_sw" = "$own_sw" ] && [ "$own_sw" -ge 2 ]; then
  printf '  ok    %-22s unmutated copy emits the same %s ENTRY-SWALLOWED rows (the four mutants above ran a working harness)\n' "swallow-control" "$own_sw"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s unmutated copy emitted %s rows against %s in place (want equal, and >= 2) — a copy that cannot run scores as a kill\n' "swallow-control" "$ctl_sw" "$own_sw"
fi


# MUTATION — remove the moved-subject guard. Entry SH-SUBJECT-GONE must fall back to
# CLOSE-CANDIDATE, and Entry SH-REAL must stay CLOSE-CANDIDATE either way: without the second
# half, a mutant that broke the sh branch outright would score as a kill of the first.
MUTG="$(dirname "$DIST")/mut-subject-guard"
rm -rf "$MUTG"; mkdir -p "$MUTG"
cp "$(dirname "$CLOSER")"/*.sh "$MUTG/" 2>/dev/null
sed 's/^          _gone="$(receipt_absent_subjects "$rest")"$/          _gone=""/' "$CLOSER" > "$MUTG/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTG/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the moved-subject assertion is unproven\n' "mutation-subject"
else
  mg="$(bash "$MUTG/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mg_gone="$(printf '%s\n' "$mg" | awk -F'\t' '$2 ~ /SH-SUBJECT-GONE/ {print $1; exit}')"
  mg_real="$(printf '%s\n' "$mg" | awk -F'\t' '$2 ~ /SH-REAL/ {print $1; exit}')"
  if [ "$mg_gone" = "CLOSE-CANDIDATE" ] && [ "$mg_real" = "CLOSE-CANDIDATE" ]; then
    printf '  ok    %-22s guard removed: the moved subject proposes a close again, and only it moved\n' "mutation-subject"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s guard removed but SH-SUBJECT-GONE=%s SH-REAL=%s (want CLOSE-CANDIDATE/CLOSE-CANDIDATE) — the assertion is vacuous or the mutant broke the whole branch\n' "mutation-subject" "${mg_gone:-none}" "${mg_real:-none}"
  fi
fi


# --- NO UNICODE ESCAPE SURVIVES INTO A DETAIL FIELD --------------------------------------
# THE DEFECT. emit() writes its three fields with a printf whose format is three %s
# conversions, and a %s conversion does NOT interpret escapes. A six-character
# backslash-u-2026 typed into a detail string therefore reaches stdout VERBATIM and is
# rendered into the region `emit-report.sh --verify` byte-compares, so the operator reads the
# escape where the author meant an ellipsis. One emit site carried exactly that, beside a real
# em-dash in the same sentence.
#
# THE SUBJECT IS THE OUTPUT, NOT THE SOURCE. A grep of ledger-reverify.sh for the escape is a
# presence anchor on text ABOUT the program: it is satisfied by a comment, and it is blind to
# an escape that arrives from the ledger or through a variable. This arm reads field 3 of what
# the shipping program actually printed.
#
# POPULATION: field 3 of EVERY emitted row, not the ENTRY-SWALLOWED rows alone. Every detail in
# this file goes through that one printf, so the defect is available to all two dozen emit sites
# equally; scoping the arm to the site that happened to carry it would leave the rest unwatched
# and read green through the next one.
#
# THE PATTERN DISCRIMINATES ON LENGTH, not on the backslash. It is backslash-u followed by
# EXACTLY four hex digits. A lone backslash, the bare token u2026, and backslash-u with three
# hex digits are all legitimate detail content — a ledger substring is echoed into field 3
# verbatim, so a receipt may legally name any of them. PC-FIXTURE-UESCAPE-NEAR-MISS in seed.sh
# carries all three in ONE substring that the real producer copies into a detail, and this arm
# requires that row to be PRESENT in the corpus it scanned: a near-miss control that is absent
# proves nothing. Since the backslash refusal shipped, that entry's row IS the refusal row —
# its anchor carries a backslash — and it still qualifies because the refusal echoes the anchor
# into the detail. A refusal that stopped quoting the anchor would silently drop this control.
#
# THE POSITIVE CONTROL is the row and ENTRY-SWALLOWED counts. This is an absence-shaped arm, so
# a subject that emits nothing sweeps it clean — the exact failure fixture-mutants.md measures.
# Zero offenders is a finding only over a corpus that has rows in it AND still carries a row
# from the emit site the defect was on.
#
# TYPING THE ESCAPE IS ITSELF A HAZARD. The backlog entry this arm discharges reports three
# attempts to put the six characters into a probe — through a heredoc, through an editor and
# inline — each arriving as a single U+2026 character with the probe then reporting "no match".
# THAT IS THE ENTRY'S MEASUREMENT AND NOT THIS ARM'S: the design here avoided the hazard from the
# first line rather than reproducing it, so nothing in this file confirms or refutes it. Recorded
# as inherited, because a comment that says "measured while this was written" about someone
# else's measurement is the provenance defect this repo keeps finding in its own prose.
# Nothing below spells the backslash: awk builds it from its character code, so no layer between
# this file and the regex engine can fold it.
#
# WHAT THIS ARM DOES NOT COVER, stated because a coverage proof cannot see outside its own
# population. It scans the rows in `$OUT` — the main corpus this fixture drives — and nothing
# else. The caller-error probes further up capture their output in separate variables, so an
# escape typed into an emit site only THEY reach (`INPUT-UNRESOLVED` is the live example) would
# not be seen here. Widening it means hand-listing that join, which is why it was not done
# quietly; the population is named instead.
#
# stdin: emitted rows. stdout: "<offenders> <rows> <swallowed> <nearmiss>"
uescape_scan() {
  awk -F'\t' '
    BEGIN { BS = sprintf("%c", 92) }
    {
      rows++
      if ($1 == "ENTRY-SWALLOWED") sw++
      s = $3; isoff = 0
      while ((p = index(s, BS "u")) > 0) {
        t = substr(s, p + 2, 4)
        if (length(t) == 4 && t ~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) { isoff = 1; break }
        s = substr(s, p + 2)
      }
      # THE NEAR-MISS COUNT EXCLUDES OFFENDERS, and it did not until a probe forced it to. A row
      # carrying a REAL escape also carries a backslash and the token u2026, so counting both
      # shapes independently let an offending row satisfy the near-miss precondition — measured
      # on a hoisted-message mutant, where nm went 1 -> 3 as the escape came back. The mutant
      # arm below requires the near-miss row to SURVIVE the mutation; that requirement is only
      # a requirement if the offending rows cannot supply it.
      if (isoff) off++
      else if (index($3, "u2026") > 0 && index($3, BS) > 0) nm++
    }
    END { printf "%d %d %d %d\n", off + 0, rows + 0, sw + 0, nm + 0 }
  '
}
# The offender dump, kept beside the scanner so both read field 3 by the same rule.
uescape_offenders() {
  awk -F'\t' '
    BEGIN { BS = sprintf("%c", 92) }
    {
      s = $3
      while ((p = index(s, BS "u")) > 0) {
        t = substr(s, p + 2, 4)
        if (length(t) == 4 && t ~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) { print $1 "  " $2; break }
        s = substr(s, p + 2)
      }
    }
  '
}

ASSERTIONS=$((ASSERTIONS + 1))
read -r ue_off ue_rows ue_sw ue_nm < <(printf '%s\n' "$OUT" | uescape_scan)
if [ "$ue_rows" -eq 0 ] || [ "$ue_sw" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s scanned %s row(s), %s of them ENTRY-SWALLOWED — a zero over an empty corpus is not a finding, and this arm would have passed against a subject that printed nothing\n' "detail-no-uescape" "$ue_rows" "$ue_sw"
elif [ "$ue_nm" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the PC-FIXTURE-UESCAPE-NEAR-MISS detail is not among the %s scanned rows, so a zero here does not establish that the pattern separates a real escape from an adjacent one\n' "detail-no-uescape" "$ue_rows"
elif [ "$ue_off" -eq 0 ]; then
  printf '  ok    %-22s no detail in %s rows (%s ENTRY-SWALLOWED) carries backslash-u-HHHH, and the near-miss row carrying a lone backslash, the token u2026 and a 3-hex backslash-u did NOT trip it\n' "detail-no-uescape" "$ue_rows" "$ue_sw"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s detail field(s) carry a literal backslash-u-HHHH escape. emit() prints a detail through a %%s conversion, which does not interpret escapes, so those six characters reach the operator and the byte-compared report verbatim. Write the character itself\n' "detail-no-uescape" "$ue_off"
  printf '%s\n' "$OUT" | uescape_offenders | sed 's/^/          | /'
fi

# MUTATION — put the escape back on the emitting line of a COPY. The mutant rewrites the bold
# span inside the ENTRY-SWALLOWED detail from the literal ellipsis to the six characters, by
# index and substr rather than by sub(): a backslash in a sub() REPLACEMENT is reprocessed, and
# backslash-u there is undefined across awk implementations, which would make the mutation the
# one thing in this file whose bytes are not knowable.
#
# BOTH HALVES ARE ASSERTED. The kill is "the arm reports an offender"; on its own that is also
# what a mutant which broke the emitter into garbage would produce, so the second half requires
# the mutant to still emit its ENTRY-SWALLOWED rows and to still carry the near-miss row.
MUTE="$(dirname "$DIST")/mut-uescape"
rm -rf "$MUTE"; mkdir -p "$MUTE"
cp "$(dirname "$CLOSER")"/*.sh "$MUTE/" 2>/dev/null
awk '
  BEGIN { BS = sprintf("%c", 92) }
  /emit ENTRY-SWALLOWED/ {
    p = index($0, "**")
    if (p > 0) {
      q = index(substr($0, p + 2), "**")
      if (q > 0) $0 = substr($0, 1, p + 1) BS "u2026" substr($0, p + 2 + q - 1)
    }
  }
  { print }
' "$CLOSER" > "$MUTE/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTE/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the escape arm is unproven — it has never been shown to fire\n' "mutation-uescape"
else
  mu_out="$(bash "$MUTE/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  read -r mu_off mu_rows mu_sw mu_nm < <(printf '%s\n' "$mu_out" | uescape_scan)
  if [ "$mu_off" -gt 0 ] && [ "$mu_sw" -gt 0 ] && [ "$mu_nm" -gt 0 ]; then
    printf '  ok    %-22s the escape restored on the emitting line is REPORTED (%s offending detail(s)), while the mutant still emits %s ENTRY-SWALLOWED row(s) and the near-miss row — the arm fires, and it fired on the mutation rather than on wreckage\n' "mutation-uescape" "$mu_off" "$mu_sw"
  elif [ "$mu_sw" -eq 0 ] || [ "$mu_nm" -eq 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant emitted %s ENTRY-SWALLOWED row(s) and %s near-miss row(s) over %s rows — it broke the emitter rather than restoring the escape, so any verdict from it is about wreckage\n' "mutation-uescape" "$mu_sw" "$mu_nm" "$mu_rows"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the escape is back on the emitting line and the arm reported ZERO offenders over %s rows — the arm above cannot fire and its clean run means nothing\n' "mutation-uescape" "$mu_rows"
  fi
fi

# --- FENCED ENTRY-SHAPED LINES — PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS -
# THE DEFECT. `ledger_entry_shape()` opened an entry on every heading-shaped line and tracked no
# fence state, so a `derived` block whose recorded output carried `## <ts> -- EVENT` lines split
# the entry that carried it: the receipt was reported under a timestamp label and the real id
# emitted no row. Measured on the reference consumer, and its 0.497.0 pull then ROTATED such an
# entry in pieces, leaving two orphan fragments in its live ledger.
#
# THE RULE, AND WHY THE ARMS BELOW COME IN FOUR SHAPES. lib.sh now tracks fences by the
# CommonMark opener/closer grammar and ignores a fenced entry-shaped line whose label is NOT
# id-keyed. An id-keyed one still opens an entry and RESETS the fence -- an unterminated fence
# can hide nothing that carries an id -- and the reset is reported here as ENTRY-SWALLOWED with
# the `fence` signal. The closer of a quoted heading's fence is then consumed as a stray closer
# rather than read as a new opener. Each of those four clauses has its own seed, its own arm and
# its own mutant, because a battery that seeds only the filed shape proves the rule accepts the
# filed shape and nothing else.
row_is "PC-FIXTURE-FENCED-NON-ID-HEADING" STILL-LIVE \
  "the entry reports under its OWN id — the fenced timestamp headings did not open an entry"
row_is "FENCED-TS-EVENT" ABSENT \
  "no row is labelled with a fenced timestamp heading (any of the three seeded)"
row_is "PC-FIXTURE-INLINE-SPAN-LINE" STILL-LIVE \
  "an entry whose body opens a line with an inline code span still reports"
row_is "inline-span-control.sh" STILL-LIVE \
  "the PROSE-titled entry after that inline-span line still reports — the span did not open a fence"
row_has "PC-FIXTURE-QUOTED-INSIDE-FENCE" ENTRY-SWALLOWED \
  "an id-keyed heading QUOTED inside a fence is REPORTED — it still opens an entry, and the operator is told"
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-QUOTED-INSIDE-FENCE/ && $3 ~ /PC-FIXTURE-QUOTING-ENTRY/ && $3 ~ /fenced code block/{f=1} END{exit !f}'; then
  printf '  ok    %-22s the fence row names the entry it truncated and says the line sits inside a fence\n' "fence-names-entry"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the fence row does not name PC-FIXTURE-QUOTING-ENTRY as the truncated entry, or does not say the line is fenced\n' "fence-names-entry"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"' | sed 's/^/          | /'
fi
row_lacks "PC-FIXTURE-AFTER-QUOTE" ENTRY-SWALLOWED \
  "the entry AFTER a quoted heading is NOT reported — the quotation's closing fence was consumed as a stray closer, not read as a new opener"
# THE TWO-QUOTATION FENCE, PINNED AS THE STATED COST rather than dodged by seed ordering. If
# `after-two-quotes-cost` ever FAILS because the false row disappeared while every other arm
# holds, that is an improvement: update this arm, do not restore the row.
row_has "PC-FIXTURE-QUOTED-TWICE-A" ENTRY-SWALLOWED \
  "the first of two quoted headings is reported"
row_has "PC-FIXTURE-AFTER-TWO-QUOTES" STILL-LIVE \
  "the entry after a two-quotation fence is never HIDDEN — its receipt reports (row_has: two rows)"
row_has "PC-FIXTURE-AFTER-TWO-QUOTES" ENTRY-SWALLOWED \
  "after-two-quotes-cost: and it carries the ONE false fence row the stray rule costs on this shape (the measured alternative cost seven false resets on the consumer archive)"
row_has "PC-FIXTURE-EOF-FENCE" STILL-LIVE \
  "an entry whose fence is still open at end of file still reports its receipt (row_has: two rows)"
row_has "PC-FIXTURE-EOF-FENCE" ENTRY-SWALLOWED \
  "and the fence left open at end of file is REPORTED by the END rule — the shape a rotation split leaves behind"
row_is "PC-FIXTURE-AFTER-QUOTE" STILL-LIVE \
  "and it is classified normally"
row_has "PC-FIXTURE-AFTER-UNTERMINATED" STILL-LIVE \
  "an id-keyed entry after an UNTERMINATED fence still reports — the fence cannot hide it (row_has: this entry emits two rows)"
row_is "PC-FIXTURE-TILDE-FENCE" STILL-LIVE \
  "a ~~~ fence is a fence too: the heading-shaped line inside it did not open an entry"
row_is "PC-FIXTURE-INDENTED-FENCE" STILL-LIVE \
  "a fence indented two spaces (the consumer's second-commonest delimiter shape) is a fence: the column-0 heading inside it did not open an entry"
row_is "INDENTED-TS-EVENT" ABSENT \
  "no row is labelled with the heading inside the indented fence"
row_has "PC-FIXTURE-AFTER-UNTERMINATED" ENTRY-SWALLOWED \
  "and the reset through the unterminated fence is REPORTED, naming the entry whose fence never closed"

# FIVE MUTANTS, ONE CLAUSE EACH, ALL ON lib.sh COPIES. Every mutant copies the reconcile
# directory and rewrites ONE clause of the shape rule; the `cmp -s` guard refuses a sed that
# matched nothing, and each kill requires a control row to SURVIVE so a mutant that broke the
# parser outright cannot score as a clean kill.
#
# THE ARMS OVERLAP, AND THAT IS DECLARED RATHER THAN DISCOVERED. Measured by the batch-50 fixture
# hand over every row_* assertion against each mutant's real output: fence-blind flips four arms,
# no-reset and naive-opener three each, no-stray one. Every extra flip is a TRUE finding about
# the same broken clause, so the overlap is in the arms and not in the mutants; each kill below
# names the ONE arm it owns. Two arms are controls with no mutant of their own -- the id-keyed
# entry after the inline-span line, and the STILL-LIVE half of the entry after a quotation --
# and they are kept as controls, not counted as proven.
fence_mutant() { # <name> <sed-expr>  -> dir on stdout, empty if the sed matched nothing
  local n="$1" expr="$2" d
  d="$(dirname "$DIST")/mut-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  sed "$expr" "$(dirname "$CLOSER")/lib.sh" > "$d/lib.sh"
  if cmp -s "$(dirname "$CLOSER")/lib.sh" "$d/lib.sh"; then return 1; fi
  printf '%s' "$d"
}
fence_kill() { # <name> <dir-or-empty> <kill-awk> <control-awk> <kill-msg> <ctl-msg>
  local n="$1" d="$2" kill="$3" ctl="$4" kmsg="$5" cmsg="$6" out
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation matched nothing in lib.sh, so the arm it targets is unproven\n' "$n"
    return
  fi
  out="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  if ! printf '%s\n' "$out" | awk -F'\t' "$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the control row is gone too (%s) — the mutant broke the parser rather than the clause, so its verdict is wreckage\n' "$n" "$cmsg"
  elif printf '%s\n' "$out" | awk -F'\t' "$kill"; then
    printf '  ok    %-22s %s\n' "$n" "$kmsg"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the clause was removed and the arm it guards did NOT change verdict — that arm cannot fire\n' "$n"
    printf '%s\n' "$out" | awk -F'\t' '$2 ~ /FENCED|QUOTE|UNTERMINATED|inline-span/' | sed 's/^/          | /'
  fi
}
# m-fence-blind: the in-fence branch removed. The fenced timestamp heading opens an entry again
# and captures the receipt: a row appears under a FENCED-TS-EVENT label.
fence_kill mutation-fence-blind "$(fence_mutant fence-blind 's@if (__lef_in && sh != "") {@if (0) {@')" \
  '$2 ~ /FENCED-TS-EVENT/ {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-COLON-CONTROL/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "fence-blind, a receipt is reported under a fenced timestamp label again — fence tracking is load-bearing" \
  "PC-FIXTURE-COLON-CONTROL STILL-LIVE"
# m-naive-opener: the backtick-in-info-string clause removed, so the inline-span line opens a
# fence. The prose-titled entry after it goes silent while the id-keyed one survives by reset.
fence_kill mutation-naive-opener "$(fence_mutant naive-opener 's@if (substr(t, 1, 1) == "~" || index(rest, "`") == 0) {@if (1) {@')" \
  '$2 ~ /inline-span-control/ {f=1} END{exit f}' \
  '$2 ~ /PC-FIXTURE-INLINE-SPAN-LINE/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "with three bare backticks treated as an opener, the prose-titled entry after the inline-span line vanishes — the CommonMark info-string clause is load-bearing" \
  "PC-FIXTURE-INLINE-SPAN-LINE STILL-LIVE"
# m-no-stray: the stray-closer rule removed. The quotation's closing fence becomes an opener and
# the NEXT entry is falsely reported as fenced.
fence_kill mutation-no-stray "$(fence_mutant no-stray 's@if (__lef_stray && rest ~ @if (0 \&\& rest ~ @')" \
  '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-AFTER-QUOTE/ {f=1} END{exit !f}' \
  '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-QUOTED-INSIDE-FENCE/ {f=1} END{exit !f}' \
  "without the stray-closer rule the entry AFTER a quoted heading is accused of being fenced too — one quotation, two rows" \
  "the QUOTED-INSIDE-FENCE fence row"
# m-no-tilde: the tilde arm of the opener grammar removed. A ~~~ fence then opens nothing and
# the heading-shaped line inside it opens an entry that captures the receipt. Without this the
# tilde branch had no subject anywhere: zero ~~~ lines on all four real corpora.
fence_kill mutation-no-tilde "$(fence_mutant no-tilde 's@if (match(t, /^```+/) || match(t, /^~~~+/)) {@if (match(t, /^```+/)) {@')" \
  '$2 ~ /TILDE-TS-EVENT/ {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-FENCED-NON-ID-HEADING/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "with the tilde arm removed a ~~~ fence is not a fence and its heading-shaped line captures the receipt — the tilde clause is load-bearing" \
  "PC-FIXTURE-FENCED-NON-ID-HEADING STILL-LIVE"
# m-no-reset: the id-keyed escape removed, so an unterminated fence swallows id-keyed lines. The
# entry after the unterminated fence vanishes; the entry after the properly closed quotation
# survives, which is what makes this a clean mutation of the reset alone.
fence_kill mutation-no-reset "$(fence_mutant no-reset 's@if (ledger_entry_id(line) != "") {@if (0) {@')" \
  '$2 ~ /PC-FIXTURE-AFTER-UNTERMINATED/ {f=1} END{exit f}' \
  '$2 ~ /PC-FIXTURE-AFTER-QUOTE/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "without the id-keyed reset an unterminated fence hides the id-keyed entry after it — the 47-entry desync, reproduced" \
  "PC-FIXTURE-AFTER-QUOTE STILL-LIVE"

# --- A BACKSLASH IN THE ANCHOR — PC-S308-LEDGER-REVERIFY-READS-ESCAPED-BACKTICKS-LITERALLY -----
# THE DEFECT. The substring grammar is literal and has no escape mechanism, and nothing said so:
# a receipt whose backticks were markdown-escaped was searched for WITH its backslashes, found at
# neither ref, and reported "vacuous predicate" on an entry upstream had just fixed. The reference
# consumer's own archive carries the SAME spelling meaning the opposite -- a shell printf whose
# backslashes were the defect text -- so the reader refuses any backslash and says why, rather
# than unescaping. Four seeds, one per shape, and the near-miss is the same text with its
# backticks bare, which must CLOSE: that is both the control that backticks are not what is
# refused and the proof the seed's refs discriminate on this text.
#
# THE DETAIL IS ASSERTED, NOT ONLY THE STATUS. The old behaviour was ALSO a NEEDS-REVIEW row, so
# a status-only arm cannot tell the fix from the defect; what separates them is whether the row
# names the backslash or calls the predicate vacuous.
# $1 label-substring  $2 fixed string the DETAIL must contain  $3 why
detail_has() {
  local label="$1" want="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$want" '$2 ~ l && index($3, s) > 0 {f=1} END{exit !f}'; then
    printf '  ok    %-22s detail names "%s"  (%s)\n' "$label" "$want" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s no row for this label carries "%s" in its detail  (%s)\n' "$label" "$want" "$why"
    printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" '$2 ~ l' | sed 's/^/          | /'
  fi
}
detail_lacks() {
  local label="$1" bad="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$bad" '$2 ~ l && index($3, s) > 0 {f=1} END{exit !f}'; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s a row for this label still carries "%s"  (%s)\n' "$label" "$bad" "$why"
    printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" '$2 ~ l' | sed 's/^/          | /'
  else
    printf '  ok    %-22s no row carries "%s"  (%s)\n' "$label" "$bad" "$why"
  fi
}
row_is "PC-FIXTURE-ESCAPED-BACKTICK" NEEDS-REVIEW \
  "a markdown-escaped backtick in the anchor is refused, not searched for"
detail_has "PC-FIXTURE-ESCAPED-BACKTICK" "contains a backslash" \
  "the row names the backslash as the reason"
detail_lacks "PC-FIXTURE-ESCAPED-BACKTICK" "vacuous predicate" \
  "the filed defect's wrong reason is gone — the predicate was never vacuous, its spelling was"
row_is "PC-FIXTURE-BARE-BACKTICK" CLOSE-CANDIDATE \
  "the same text with bare backticks closes: backticks are fine, and base/theirs discriminate on this line"
row_is "PC-FIXTURE-LITERAL-BACKSLASH" NEEDS-REVIEW \
  "an anchor whose backslashes are the source text is refused too — the stated limit, pinned"
detail_has "PC-FIXTURE-LITERAL-BACKSLASH" "contains a backslash" \
  "and it is refused for the backslash, with the re-anchor remedy"
row_is "PC-FIXTURE-REGEX-ANCHOR" NEEDS-REVIEW \
  "a regex escape is a backslash like any other — theirs_lacks is refused on the same rule"
detail_has "PC-FIXTURE-REGEX-ANCHOR" "contains a backslash" \
  "and says so"
# THE THREE SHAPES THE ADVERSARIAL HAND ADDED, each the seed that separates the shipped guard
# from a narrower one that passed every single-anchor arm above.
row_is "PC-FIXTURE-SECOND-SUBSTRING" NEEDS-REVIEW \
  "a backslash in the SECOND of two anchors is refused — the whole quoted run is covered, not its first member"
detail_has "PC-FIXTURE-SECOND-SUBSTRING" "contains a backslash" \
  "and for the backslash, not for the multi-anchor shape"
row_is "PC-FIXTURE-ESCAPED-QUOTE" NEEDS-REVIEW \
  "a backslash before a double quote is refused — the rule is any backslash, not the two escapes the other seeds use"
detail_has "PC-FIXTURE-ESCAPED-QUOTE" "contains a backslash" \
  "and says so"
row_is "PC-FIXTURE-ESCAPED-PATH" NEEDS-REVIEW \
  "a markdown-escaped PATH is refused before the basename fallback can guess it right"
detail_has "PC-FIXTURE-ESCAPED-PATH" "the path" \
  "and the row names the PATH as the field at fault"
row_is "PC-FIXTURE-CLEAN-PATH" CLOSE-CANDIDATE \
  "the same receipt with the path bare closes: the underscore is not what is refused, and the token discriminates"
row_is "PC-FIXTURE-ESCAPED-ON-MISSING-PATH" NEEDS-REVIEW \
  "an escaped anchor on an unresolvable path is still a refusal"
detail_has "PC-FIXTURE-ESCAPED-ON-MISSING-PATH" "contains a backslash" \
  "and it is refused for the BACKSLASH — the guard sits before path resolution, so the missing path does not pre-empt it"
detail_has "Entry I" "does not resolve" \
  "the near-miss: a clean anchor on a missing path still reads as an unresolvable path"
# THE REMEDY IS PART OF THE ROW. A refusal that names the fault and not the fix sends the author
# to guess, and the adversarial hand's one-clause variant passed every arm above.
detail_has "PC-FIXTURE-ESCAPED-BACKTICK" "Write backticks and quotes bare" \
  "the anchor row carries its remedy"
detail_has "PC-FIXTURE-ESCAPED-BACKTICK" "verify: sh" \
  "and names the escape hatch for text that genuinely contains a backslash"
detail_has "PC-FIXTURE-ESCAPED-PATH" "Write the path bare" \
  "the path row carries its remedy"
# THE ESCAPE HATCH IS PINNED. The scope hand built a guard refusing a backslash for EVERY verb;
# the receipt as first written accepted it, and it would silence fifteen of the reference
# consumer's thirty-six live `sh` receipts. An `sh` receipt is a program and its backslashes
# are its own.
row_is "PC-FIXTURE-SH-WITH-BACKSLASH" STILL-LIVE \
  "an sh receipt carrying a backslash is EVALUATED, not refused — the remedy the refusal row offers exists"

# SIX MUTANTS ON A TINY LEDGER. Each runs the closer over ONLY the eight backslash entries, cut
# from the seeded ledger by heading so the receipts are not restated here, because a full-ledger
# run is what makes this fixture the suite's third-longest unit. Each mutation is anchored on
# one of the two `case` SUBJECT lines (`case "$path" in`, `case "$sub" in`), asserted UNIQUE
# below so a second copy cannot be edited by accident — the pattern line beneath them is shared
# by both guards and is reached by state, never matched on its own. `cmp -s` refuses a program
# that changed nothing; and each kill requires a control row to SURVIVE, so a mutant that broke
# the parser cannot score as a kill.
LED_SEEDED="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
TINY="$(dirname "$DIST")/tiny-backslash-ledger.md"
awk '/^## PC-FIXTURE-ESCAPED-BACKTICK/{p=1} /^## PC-FIXTURE-EOF-FENCE/{p=0} p' "$LED_SEEDED" > "$TINY"
ASSERTIONS=$((ASSERTIONS + 1))
tiny_n="$(grep -c '^## PC-FIXTURE-' "$TINY")" || tiny_n=0
if [ "$tiny_n" -eq 10 ]; then
  printf '  ok    %-22s the tiny ledger carries exactly the ten backslash entries\n' "tiny-ledger"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the tiny ledger carries %s entries, not 10 — the mutants below would run over the wrong corpus\n' "tiny-ledger" "$tiny_n"
fi
ASSERTIONS=$((ASSERTIONS + 1))
sub_n="$(grep -c '^ *case "\$sub" in$' "$CLOSER")" || sub_n=0
path_n="$(grep -c '^ *case "\$path" in$' "$CLOSER")" || path_n=0
if [ "$sub_n" -eq 1 ] && [ "$path_n" -eq 1 ]; then
  printf '  ok    %-22s the two guard case-subject lines are each unique in the closer (the mutation anchors)\n' "guard-anchor"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s `case "$sub" in` and %s `case "$path" in` lines; the mutations below anchor on them and need exactly one each\n' "guard-anchor" "$sub_n" "$path_n"
fi
# THE UNMUTATED CONTROL, with a positive conjunct: the same tiny ledger through the shipped closer
# must produce the refusal row AND the close, or every kill below is scored against wreckage.
tiny_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$TINY" 2>&1)"
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$tiny_out" | awk -F'\t' '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && $1=="NEEDS-REVIEW" && index($3,"contains a backslash")>0 {a=1} $2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {b=1} END{exit !(a && b)}'; then
  printf '  ok    %-22s unmutated closer on the tiny ledger: escaped refused with the backslash reason, bare closes\n' "tiny-control"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the unmutated closer does not reproduce the two baseline rows on the tiny ledger — the mutant kills below are unreadable\n' "tiny-control"
  printf '%s\n' "$tiny_out" | sed 's/^/          | /'
fi
bs_mutant() { # <name> <awk-program>  -> dir on stdout, empty if the program changed nothing
  local n="$1" prog="$2" d
  d="$(dirname "$DIST")/mut-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  awk "$prog" "$CLOSER" > "$d/ledger-reverify.sh" || return 1
  if cmp -s "$CLOSER" "$d/ledger-reverify.sh"; then return 1; fi
  printf '%s' "$d"
}
bs_kill() { # <name> <dir-or-empty> <kill-awk> <control-awk> <kill-msg> <ctl-msg>
  local n="$1" d="$2" kill="$3" ctl="$4" kmsg="$5" cmsg="$6" out
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation DID NOT APPLY (matched nothing, or awk died), so the arm it targets is unproven\n' "$n"
    return
  fi
  out="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$TINY" 2>&1)"
  if ! printf '%s\n' "$out" | awk -F'\t' "$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the control row is gone too (%s) — the mutant broke the closer rather than the guard, so its verdict is wreckage\n' "$n" "$cmsg"
    printf '%s\n' "$out" | sed 's/^/          | /'
  elif printf '%s\n' "$out" | awk -F'\t' "$kill"; then
    printf '  ok    %-22s %s\n' "$n" "$kmsg"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the guard was changed and the arm it protects did NOT change verdict — that arm cannot fire\n' "$n"
    printf '%s\n' "$out" | sed 's/^/          | /'
  fi
}
# THE ARM'S OWN MUTANT: the anchor guard's subject emptied, so its pattern can never match. The
# escaped receipt is searched for literally again and the filed wrong reason comes back.
bs_kill mutation-bs-no-guard \
  "$(bs_mutant bs-no-guard '/^ *case "\$sub" in$/ { $0 = "      case \"\" in" } { print }')" \
  '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && index($3,"vacuous predicate")>0 {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  "with the anchor guard disarmed the escaped receipt reads \"vacuous predicate\" again — the refusal is load-bearing" \
  "PC-FIXTURE-BARE-BACKTICK CLOSE-CANDIDATE"
# THE FIRST WRONG FIX: unescape backslash-backtick and drop the guard. The escaped receipt then
# CLOSES, which is the filing's reading (b) -- and the shape the literal-backslash entry shows to
# be a guess. The inserted line is passed through ENVIRON so no layer reprocesses its backslash.
UNESC_LINE='      sub="$(printf '"'"'%s'"'"' "$sub" | sed '"'"'s/\\`/`/g'"'"')"'
export UNESC_LINE
bs_kill mutation-bs-unescape \
  "$(bs_mutant bs-unescape '/^ *case "\$sub" in$/ { $0 = "      case \"\" in" } /^      subs="\$\(printf/ { print ENVIRON["UNESC_LINE"] } { print }')" \
  '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  "an unescaping reader closes the escaped receipt — the arm sees the guess the fix refuses to make" \
  "PC-FIXTURE-BARE-BACKTICK CLOSE-CANDIDATE"
# THE SECOND WRONG FIX: refuse only backslash-BACKTICK. The pattern line is reached by state from
# the anchor guard's subject line, so the path guard's identical pattern is left alone. The regex
# anchor is then searched for literally, matches nothing at either ref, and theirs_lacks reads
# STILL-LIVE with reachability unchecked (this consumer root has no tracked-file list) — a
# positive verdict, not an absence.
bs_kill mutation-bs-backtick-only \
  "$(bs_mutant bs-backtick-only 'BEGIN { BS = sprintf("%c", 92); BT = sprintf("%c", 96) } /^ *case "\$sub" in$/ { f = 1 } f && $0 ~ /^ *\*\\\\\*\)$/ { $0 = "        *" BS BS BS BT "*)"; f = 0 } { print }')" \
  '$2 ~ /PC-FIXTURE-REGEX-ANCHOR/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && $1=="NEEDS-REVIEW" && index($3,"contains a backslash")>0 {f=1} END{exit !f}' \
  "a backtick-only guard lets the regex anchor through and it reads STILL-LIVE forever — any backslash is the rule" \
  "PC-FIXTURE-ESCAPED-BACKTICK refused with the backslash reason"
# THE THIRD WRONG FIX, the adversarial hand's BLOCKER: a guard that tests only the FIRST quoted
# substring. It passed every single-anchor arm and the receipt as first shipped, and on the
# two-anchor seed it manufactures a CLOSE-CANDIDATE on an anchor the rule says cannot be decided.
bs_kill mutation-bs-first-only \
  "$(bs_mutant bs-first-only 'BEGIN { BS = sprintf("%c", 92) } /^ *case "\$sub" in$/ { $0 = "      case \"${sub%%" BS "\"*}\" in" } { print }')" \
  '$2 ~ /PC-FIXTURE-SECOND-SUBSTRING/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  "a first-substring-only guard CLOSES the two-anchor entry whose second anchor carries the backslash — the whole run is what the guard reads" \
  "PC-FIXTURE-BARE-BACKTICK CLOSE-CANDIDATE"
# THE FOURTH WRONG FIX: refuse only the two escapes the first four seeds happen to use (backtick
# and dot). The escaped-quote receipt is searched for literally and reads vacuous.
bs_kill mutation-bs-two-escapes \
  "$(bs_mutant bs-two-escapes 'BEGIN { BS = sprintf("%c", 92); BT = sprintf("%c", 96) } /^ *case "\$sub" in$/ { f = 1 } f && $0 ~ /^ *\*\\\\\*\)$/ { $0 = "        *" BS BS BS BT "*|*" BS BS ".*)"; f = 0 } { print }')" \
  '$2 ~ /PC-FIXTURE-ESCAPED-QUOTE/ && index($3,"vacuous predicate")>0 {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-REGEX-ANCHOR/ && $1=="NEEDS-REVIEW" && index($3,"contains a backslash")>0 {f=1} END{exit !f}' \
  "a backtick-or-dot guard lets the escaped quote through and it reads vacuous — the rule is any backslash" \
  "PC-FIXTURE-REGEX-ANCHOR still refused"
# THE PATH GUARD'S OWN MUTANT: its subject emptied. The escaped path falls to the basename
# fallback, whose awk -v strips the backslash, and the entry CLOSES on a path nobody wrote.
bs_kill mutation-bs-no-path-guard \
  "$(bs_mutant bs-no-path-guard '/^ *case "\$path" in$/ { $0 = "      case \"\" in" } { print }')" \
  '$2 ~ /PC-FIXTURE-ESCAPED-PATH/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-CLEAN-PATH/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  "without the path guard the escaped path is guessed right by basename and the entry CLOSES — the guard is what stops the guess" \
  "PC-FIXTURE-CLEAN-PATH CLOSE-CANDIDATE"
echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
