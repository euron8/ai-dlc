#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# ledger-reverify-unfalsifiable/run.sh — prove ledger-reverify.sh separates a live
# `theirs_lacks` entry from an UNFALSIFIABLE one when both are absent at base and theirs.
#
# The verdict must be driven by consumer reachability and by nothing else, so this asserts
# all four directions: it FIRES on invented prose, it PASSES on a real anchor, the verdict
# FOLLOWS the anchor under mutation, and it REFUSES to decide when the scan set is missing.
# A check proven only to fire is indistinguishable from one that fires on everything.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
verdict() { bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null |
              awk -F'\t' -v l="$1" '$2 ~ l {print $1; exit}'; }

echo "ledger-reverify-unfalsifiable:"

# --- Assertion 0: SANITY — neither substring is at base OR theirs --------------------
# Without this the two entries are not the same case and nothing below is attributable.
s_absent=1
for s in -- "--strict-provenance" "strict provenance enforced by default"; do
  [ "$s" = "--" ] && continue
  for ref in "$BASE" "$THEIRS"; do
    grep -qF -- "$s" <<<"$(git -C "$DIST" show "$ref:core/scripts/validate-thing.sh")" && s_absent=0
  done
done
if [ "$s_absent" -eq 1 ]; then
  ok "before: BOTH substrings absent at base AND theirs (the undecidable-by-two-refs case)"
else
  bad "FIXTURE BROKEN — a substring is present at a ref"; echo
  echo "ledger-reverify-unfalsifiable: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: the check PASSES on a real anchor ----------------------------------
[ "$(verdict PC-GOOD)" = "STILL-LIVE" ] \
  && ok "PC-GOOD (flag the consumer implements) → STILL-LIVE" \
  || bad "PC-GOOD → $(verdict PC-GOOD), expected STILL-LIVE — the check fires on everything"

# --- Assertion 2: the check FIRES on invented prose ----------------------------------
[ "$(verdict PC-BAD)" = "NEEDS-REVIEW" ] \
  && ok "PC-BAD (prose describing the fix) → NEEDS-REVIEW" \
  || bad "PC-BAD → $(verdict PC-BAD), expected NEEDS-REVIEW — unfalsifiable predicate not caught"

# --- Assertion 2b: the NEAR-MISS arm, and it is asserted on the DETAIL, not the verdict --
# PC-NEARMISS and PC-NOMISS are BOTH NEEDS-REVIEW, so a verdict-only arm passes whether the
# new arm exists or not — it would be the vacuous shape this fixture's header warns about.
# What separates them is WHICH cause the row names, and that the mis-anchored row names the
# spelling that would have closed.
detail() { bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null |
             awk -F'\t' -v l="$1" '$2 ~ l {print $3; exit}'; }

# SANITY, because every arm below is unattributable without it: upstream really did move,
# under the HYPHEN spelling, and the receipt's UNDERSCORE spelling is absent at both refs.
#
# NEVER PIPE INTO `grep -q`. It leaves at its first match while the writer is still pushing,
# and under pipefail the pipeline answers with the writer's EPIPE — reporting NOT-FOUND on
# input that contains the pattern. It is a size threshold rather than a race, so it is correct
# until the blob grows past the pipe buffer and then wrong permanently with no symptom. `I54b`
# of `validate-enforcement-map.sh` refuses the shape; the blobs here are small and it would
# have been latent, which is exactly the state that arm exists to prevent. Capture first, feed
# a here-string.
#
# `git show` on a path absent at a ref is a FATAL on stderr and empty on stdout. That is the
# correct state for the BASE arm — the subject is ADDED between base and theirs — so its
# stderr is discarded and the emptiness is what the assertion reads. The THEIRS arm keeps its
# stderr: absence there is a broken fixture, not a precondition.
nm_ok=1
nm_theirs="$(git -C "$DIST" show "${THEIRS}:core/scripts/near-miss-subject.sh")"
nm_base="$(git -C "$DIST" show "${BASE}:core/scripts/near-miss-subject.sh" 2>/dev/null)"
grep -qF 'near-miss-flag:' <<<"$nm_theirs" || nm_ok=0
grep -qF 'near-miss-flag:' <<<"$nm_base"   && nm_ok=0
grep -qF 'near_miss_flag:' <<<"$nm_theirs" && nm_ok=0
grep -qF 'near_miss_flag:' <<<"$nm_base"   && nm_ok=0
# AND THE MASK MUST BE IN PLACE. If the misspelling is NOT reachable in the consumer tree,
# the OLD unfalsifiable guard catches this row and the new arm is scoring a solved case.
# Control in the same arm: an impossible token must not be reachable.
git -C "$CONSUMER" grep -qF 'near_miss_flag:' -- ":(exclude)_bmad-output" || nm_ok=0
git -C "$CONSUMER" grep -qF 'ZZQQ_NO_SUCH_TOKEN:' -- ":(exclude)_bmad-output" && nm_ok=0
if [ "$nm_ok" -eq 1 ]; then
  ok "before: hyphen spelling absent at base / present at theirs, underscore absent at both, and REACHABLE in the consumer (the mask)"
else
  bad "FIXTURE BROKEN — near-miss preconditions do not hold; the arm below would score a solved case"; echo
  echo "ledger-reverify-unfalsifiable: FIXTURE BROKEN" >&2; exit 2
fi

_nm="$(detail PC-NEARMISS)"
if grep -qF 'mis-anchored predicate:' <<<"$_nm" && grep -qF 'near-miss-flag' <<<"$_nm"; then
  ok "PC-NEARMISS (anchor one character off) → mis-anchored, naming the spelling that closes"
else
  bad "PC-NEARMISS detail does not report a mis-anchored predicate naming 'near-miss-flag': $_nm"
fi

# The other direction. An arm that flagged every absent-at-both anchor would pass above and
# fail here, which is the only reason the arm above means anything.
_nomiss="$(detail PC-NOMISS)"
if grep -qF 'unfalsifiable predicate:' <<<"$_nomiss" && ! grep -qF 'mis-anchored' <<<"$_nomiss"; then
  ok "PC-NOMISS (absent at both, no closing variant) → unfalsifiable, NOT claimed by the near-miss arm"
else
  bad "PC-NOMISS was claimed by the near-miss arm or lost its unfalsifiable verdict: $_nomiss"
fi

# --- Assertion 2c: ONE SEED PER WRONG IMPLEMENTATION ----------------------------------
# An independent hand built seven wrong implementations against the arms above and FOUR of them
# passed. Every acceptance was a gap in the SEEDS, not in the arm: the worlds could not express
# the property each wrong implementation drops. These three arms are those worlds, and each one
# names the implementation it exists to kill.
#
# Both-directions controls establish that the arm discriminates between two inputs; they cannot
# establish it discriminates at all, which is why the committed mutant below stays.

# SWAP-ONLY. `PC-NEARMISS`'s closing spelling differs by a separator, so an implementation that
# swaps hyphen/underscore and never strips the trailing colon finds it and passes. Here the
# anchor and the fix differ ONLY by a colon.
_cs="$(detail PC-COLONSTRIP)"
if grep -qF 'mis-anchored predicate:' <<<"$_cs" && grep -qF 'colonstripflag' <<<"$_cs"; then
  ok "PC-COLONSTRIP (colon-strip is the only reaching transform) → mis-anchored (kills a swap-only arm)"
else
  bad "PC-COLONSTRIP was not reported mis-anchored, so half the transform set is unproven: $_cs"
fi

# DROPPED `absent at base` CONJUNCT, and this is the FALSE-ACCUSATION direction. Every other
# near-miss world has its variant absent at base, so an arm testing only "present at theirs"
# passes all of them and accuses a healthy receipt here.
_br="$(detail PC-BOTHREFS)"
if ! grep -qF 'mis-anchored' <<<"$_br"; then
  ok "PC-BOTHREFS (variant at BOTH refs — upstream did not move) → not accused (kills a theirs-only arm)"
else
  bad "PC-BOTHREFS was accused of a mis-anchored predicate, but its variant is present at base too — upstream never moved under it, so this is a false accusation: $_br"
fi

# THE MULTI-SUBSTRING SKIP, whose only subject this is. `$sub` is the whole quoted run, so a
# variant of it is a two-token guess naming something no fix wrote. Without this world the skip
# can be deleted and nothing changes.
_ms="$(detail PC-MULTISUB)"
if ! grep -qF 'mis-anchored' <<<"$_ms"; then
  ok "PC-MULTISUB (two substrings — which one is misspelled is not derivable) → not accused (kills a skip-less arm)"
else
  bad "PC-MULTISUB was accused, so the multi-substring skip is gone and the row quotes a guess spanning two substrings: $_ms"
fi

# THE VERDICT CLASS IS LOAD-BEARING AND NO ARM ABOVE READS IT. `SKILL.md` step 8 closes
# `CLOSE-CANDIDATE` rows and says a `NEEDS-REVIEW` row is never a close, whatever its detail
# says. An implementation emitting the near-miss finding as CLOSE-CANDIDATE therefore puts a
# GUESSED spelling into the set an operator auto-closes — retiring a live entry on a guess,
# which is the false-close this engine exists to refuse. Asserting the detail alone cannot see
# it: the detail text is identical under both verdicts.
_nmv="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null |
          awk -F'\t' '$2 ~ /PC-NEARMISS/ {print $1; exit}')"
[ "$_nmv" = "NEEDS-REVIEW" ] \
  && ok "PC-NEARMISS verdict is NEEDS-REVIEW, not CLOSE-CANDIDATE (a guessed spelling never enters the auto-close set)" \
  || bad "PC-NEARMISS verdict is '$_nmv' — step 8 auto-closes CLOSE-CANDIDATE rows, so a guessed spelling would retire a live entry"

# --- Assertion 3: MUTATION — the verdict follows the anchor, not the entry -----------
# Remove ONLY the anchor. keep.sh survives, so the scan set stays non-empty and the
# undecidable path cannot supply a false pass.
sed -i.bak 's/--strict-provenance/--other-flag/' "$CONSUMER/scripts/thing.sh" && rm -f "$CONSUMER/scripts/thing.sh.bak"
git -C "$CONSUMER" -c user.email=f@f -c user.name=f add -A >/dev/null 2>&1
git -C "$CONSUMER" -c user.email=f@f -c user.name=f commit -qm mutate >/dev/null 2>&1
[ "$(verdict PC-GOOD)" = "NEEDS-REVIEW" ] \
  && ok "mutation: anchor removed from the consumer → PC-GOOD flips to NEEDS-REVIEW" \
  || bad "mutation: PC-GOOD → $(verdict PC-GOOD), expected NEEDS-REVIEW — verdict is not driven by the anchor"

# --- Assertion 4: UNDECIDABLE — no scan set must not manufacture an accusation -------
# A missing input is not evidence of a bad predicate. It must say so, not accuse.
rm -rf "$CONSUMER/.git"
out="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if grep -q "STILL-LIVE.*PC-BAD" <<<"$out" && grep -q "NOT checked" <<<"$out"; then
  ok "no tracked file list → STILL-LIVE + 'reachability NOT checked' (undecidable says so)"
else
  bad "undecidable path did not degrade safely: $(printf '%s' "$out" | awk -F'\t' '{print $1}' | tr '\n' ' ')"
fi

# --- Assertion 5: LARGE FILE — the verdict must be correct and STABLE -----------------
# `grep -q` exits on first match; piping into it under `set -o pipefail` turns the writer's
# SIGPIPE into the pipeline's status, so a match on a >64 KB file reads as "not found".
# Measured before the fix: four consecutive runs of one unchanged entry returned STILL-LIVE,
# NEEDS-REVIEW, STILL-LIVE, CLOSE-CANDIDATE. Assert the verdict AND its stability — a single
# run passes half the time by luck, which is worse than no assertion at all.
big="$(verdict PC-BIG)"
if [ "$big" = "STILL-LIVE" ]; then
  ok "PC-BIG (needle in a >64KB file) → STILL-LIVE"
else
  bad "PC-BIG → $big, expected STILL-LIVE — a match on a large file read as not-found"
fi
stable=1
for _ in 1 2 3 4 5 6; do
  [ "$(verdict PC-BIG)" = "$big" ] || stable=0
done
[ "$stable" -eq 1 ] \
  && ok "PC-BIG verdict identical across 7 runs (no pipe-buffer nondeterminism)" \
  || bad "PC-BIG verdict VARIES between runs — the match test is nondeterministic"

# --- Assertion 6: THE VERDICT MUST NOT DEPEND ON HOW THE LEDGER IS ADDRESSED ---------
# The reachability exclusion is a pathspec derived from $LEDGER. It used to be a literal
# prefix strip, `${LEDGER#"$CONSUMER"/}` then `%%/*`, which silently yields "" whenever the two
# arguments are not spelled identically — a ledger outside the tree, a consumer arg with a
# trailing slash, a doubled slash. "" becomes the pathspec `:(exclude)`, which excludes the
# WHOLE TREE, so git grep exits 1 (not 128), consumer_reachable returns "absent" rather than
# "undecidable", and every entry whose substring is absent at both refs is accused of being
# unfalsifiable. Observed on the reference consumer: one entry reported NEEDS-REVIEW through
# arg 5 and STILL-LIVE through the default path, same refs, same bytes.
# A FRESH SEED. Assertion 3 rewrites a consumer file and assertion 4 does `rm -rf .git`, so by
# this point the tree is deliberately unscannable and every reachability verdict degrades to
# "NOT checked". Reusing it here would have scored these assertions against a consumer that
# cannot be scanned at all — which is how a check comes to pass for a reason it is not testing.
W2="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: second seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK" "$W2"' EXIT
# shellcheck source=/dev/null
. "$W2/env.sh"    # re-points CONSUMER/DIST/BASE/THEIRS at the pristine copy

LED="$CONSUMER/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
OUT_COPY="$W2/outside-the-tree-ledger.md"
cp "$LED" "$OUT_COPY"

shape_sig() { # <consumer-arg> [ledger-arg] -> the whole verdict multiset, order-insensitive
  bash "$RV" "$DIST" "$BASE" "$1" "$THEIRS" ${2:+"$2"} 2>/dev/null \
    | awk -F'\t' '{print $1"\t"$2}' | sort
}
base_sig="$(shape_sig "$CONSUMER")"
shapes_agree=1; disagreed=""
for spec in "$CONSUMER/|" "$CONSUMER|$LED" "$CONSUMER|$CONSUMER/./_bmad-output/ai-dlc-update/push-candidate-ledger.md" "$CONSUMER|$OUT_COPY"; do
  c="${spec%%|*}"; l="${spec#*|}"
  [ "$(shape_sig "$c" ${l:+"$l"})" = "$base_sig" ] || { shapes_agree=0; disagreed="$disagreed [$c|$l]"; }
done
[ "$shapes_agree" -eq 1 ] \
  && ok "identical verdicts across 5 invocation shapes (trailing slash, explicit path, /./, out-of-tree copy)" \
  || bad "the verdict depends on how the ledger is addressed:$disagreed"

# --- Assertion 7: …AND THE EXCLUSION IS STILL LOAD-BEARING ---------------------------
# The lazy way to make assertion 6 pass is to drop the exclusion, which would make every
# predicate reachable and turn this whole check vacuous — trading a false accusation for a
# false all-clear, the worse half of the same bug. PC-BAD is reachable ONLY through the
# ledger, so it must still be accused under every shape, including the out-of-tree one where
# the subject file is elsewhere but the consumer's own ledger is still sitting in the tree.
bad_everywhere=1
for spec in "$CONSUMER|" "$CONSUMER|$OUT_COPY"; do
  c="${spec%%|*}"; l="${spec#*|}"
  v="$(bash "$RV" "$DIST" "$BASE" "$c" "$THEIRS" ${l:+"$l"} 2>/dev/null | awk -F'\t' '$2 ~ /PC-BAD/ {print $1; exit}')"
  [ "$v" = "NEEDS-REVIEW" ] || bad_everywhere=0
done
[ "$bad_everywhere" -eq 1 ] \
  && ok "PC-BAD stays NEEDS-REVIEW even when the subject ledger is out of tree (exclusion falls back, not away)" \
  || bad "the ledger exclusion stopped firing — the unfalsifiable check is now vacuous"

# --- Assertion 8: MUTATION — restore the literal prefix strip -------------------------
# The mutant runs from a COPY OF THE WHOLE reconcile/ directory: this script sources lib.sh
# from its own dirname, so a lone copy dies on the source line and emits nothing — and "no
# output" would have scored as a kill for a harness failure. The control below is what makes
# that distinguishable.
MUTD="$W2/mut-reconcile"; rm -rf "$MUTD"
cp -R "$(dirname "$RV")" "$MUTD" 2>/dev/null
CTL="$MUTD/$(basename "$RV")"
MUT="$MUTD/mutant-reverify.sh"
# ALL THREE PARTS OF THE FIX MUST GO, and finding that out is the useful part of writing this.
# The fix is (1) path arithmetic instead of a literal prefix strip, (2) a fallback to the
# conventional in-tree ledger when the subject is elsewhere, and (3) a call-site guard that
# never emits a bare `:(exclude)`. Revert any two and the third still repairs the run: the
# first draft reverted only (1), the second only (1)+(2), and both mutants came out green
# against a defect that is trivially reproducible by hand. A partial revert of a layered fix
# is a mutant that proves the layer you left in place.
sed -e 's@^LEDGER_TOP="$(ledger_top_dir "$LEDGER")"$@LEDGER_TOP="${LEDGER#"$CONSUMER"/}"; LEDGER_TOP="${LEDGER_TOP%%/*}"@' \
    -e '/^\[ -n "\$LEDGER_TOP" \] || LEDGER_TOP="\$(ledger_top_dir "\$LEDGER_DEFAULT")"$/d' \
  "$RV" \
  | awk '
      /^    if \[ -n "\$LEDGER_TOP" \]; then$/ { inblk=1
        print "    git -C \"$CONSUMER\" grep -qF -e \"$_one\" -- \\"
        print "      \":(exclude)$LEDGER_TOP\" \":(exclude)*/$SELF_BASE\" >/dev/null 2>&1"
        next }
      inblk && /^    fi$/ { inblk=0; next }
      inblk { next }
      { print }
  ' > "$MUT"
# Every edit must have landed. A partial mutation is not a weaker test, it is a green one.
m_strip="$(grep -c 'LEDGER_TOP%%/\*' "$MUT")"
m_fall="$(grep -c 'LEDGER_DEFAULT")' "$MUT")"
m_guard="$(grep -c 'if \[ -n "\$LEDGER_TOP" \]; then' "$MUT")"
if [ "$m_strip" -ne 1 ] || [ "$m_fall" -ne 0 ] || [ "$m_guard" -ne 0 ]; then
  bad "FIXTURE BROKEN — partial mutation (strip=$m_strip want 1, fallback=$m_fall want 0, guard=$m_guard want 0); a half-reverted fix repairs itself and scores green"
fi
pcgood() { bash "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" ${2:+"$2"} 2>/dev/null \
             | awk -F'\t' '$2 ~ /PC-GOOD/ {print $1; exit}'; }

if [ "$(pcgood "$CTL")" != "STILL-LIVE" ] || [ "$(pcgood "$CTL" "$OUT_COPY")" != "STILL-LIVE" ]; then
  bad "FIXTURE BROKEN — the UNMUTATED copy in the mutant directory does not reproduce the fixed behaviour (got '$(pcgood "$CTL")' / '$(pcgood "$CTL" "$OUT_COPY")'), so the mutation below would score a false kill"
elif cmp -s "$RV" "$MUT"; then
  bad "FIXTURE BROKEN — the mutation matched nothing, so assertions 6-7 are unproven"
else
  cv="$(pcgood "$MUT")"; mv2="$(pcgood "$MUT" "$OUT_COPY")"
  if [ "$cv" = "STILL-LIVE" ] && [ "$mv2" = "NEEDS-REVIEW" ]; then
    ok "mutation: the old strip clears PC-GOOD through the default path and accuses it through an out-of-tree ledger (assertions 6-7 are real)"
  else
    bad "mutation did not reproduce the defect (default=$cv out-of-tree=$mv2; expected STILL-LIVE / NEEDS-REVIEW)"
  fi
fi

# --- Assertion 8b: MUTATION — delete the near-miss arm --------------------------------
# Assertions 2b are PRESENCE-shaped (they demand a specific detail string), so a subject that
# emits nothing fails them by construction. What they cannot establish on their own is that
# the arm is what produces the row rather than something upstream of it: remove the call site
# and PC-NEARMISS must fall back to the OLD verdict, which is the DECIDED STILL-LIVE this
# whole release exists to eliminate. That is the observable, and it is the defect itself.
#
# The whole reconcile/ directory is copied, as assertion 8 does and for the same reason: this
# script sources lib.sh from its own dirname, so a lone copy emits nothing and "no output"
# would score as a kill.
MUTD2="$W2/mut-nearmiss"; rm -rf "$MUTD2"
cp -R "$(dirname "$RV")" "$MUTD2" 2>/dev/null
CTL2="$MUTD2/$(basename "$RV")"
MUT2="$MUTD2/mutant-nearmiss.sh"
# Delete the CALL SITE, not the helper: a fix whose helper survives while nothing invokes it
# is precisely the vacuous shape, and this mutant must reproduce it.
awk '
  /^            _nm="\$\(near_miss_spelling "\$path" "\$sub" "\$subs"\)"$/ { inblk=1; next }
  inblk && /^            fi$/ { inblk=0; next }
  inblk { next }
  { print }
' "$CTL2" > "$MUT2"
nm_detail() { bash "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null |
                awk -F'\t' '$2 ~ /PC-NEARMISS/ {print $1"\t"$3; exit}'; }
if cmp -s "$CTL2" "$MUT2"; then
  bad "FIXTURE BROKEN — the near-miss mutation matched nothing, so assertion 2b is unproven"
elif [ "$(grep -c 'near_miss_spelling "\$path"' "$MUT2")" -ne 0 ]; then
  bad "FIXTURE BROKEN — partial mutation: the call site survives, so the mutant proves nothing"
else
  # UNMUTATED CONTROL, with a POSITIVE conjunct: the copy must reproduce the fixed row, not
  # merely fail to crash. A control asserting only "nothing went wrong" passes against a
  # subject replaced by `exit 0`.
  _cd="$(nm_detail "$CTL2")"
  if ! grep -qF 'mis-anchored predicate:' <<<"$_cd"; then
    bad "FIXTURE BROKEN — the UNMUTATED copy does not reproduce the mis-anchored row (got '$_cd'), so the mutant below would score a false kill"
  else
    _md="$(nm_detail "$MUT2")"
    if grep -qF 'STILL-LIVE' <<<"$_md" && ! grep -qF 'mis-anchored' <<<"$_md"; then
      ok "mutation: with the near-miss call site removed, PC-NEARMISS reverts to a DECIDED STILL-LIVE (the defect reproduces)"
    else
      bad "mutation did not reproduce the defect (got '$_md'; expected a STILL-LIVE row with no mis-anchored detail)"
    fi
  fi
fi

# --- The same guard on the `verify: sh` arm -------------------------------------------
# The theirs_* verbs have carried this guard since they were written; `sh` did not, and it is
# the verb that runs arbitrary consumer-side commands. A receipt anchored on what a
# HYPOTHESISED fix would introduce reports STILL-LIVE forever, and nothing reported it.
#
# SANITY FIRST, because every arm below is a claim about these bytes and is unattributable
# without them. The subject must map through map_consumer() and exist in the consumer, or the
# guard is undecidable and the arms pass while testing nothing.
if [ -f "$CONSUMER/scripts/ai-dlc/validate-thing.sh" ] \
   && ! grep -qF 'theirs moved' "$CONSUMER/scripts/ai-dlc/validate-thing.sh" \
   && grep -qF 'theirs moved' <<<"$(git -C "$DIST" show "${THEIRS}:core/scripts/validate-thing.sh")" \
   && ! grep -qF 'theirs moved' <<<"$(git -C "$DIST" show "${BASE}:core/scripts/validate-thing.sh")"; then
  ok "before: sh subject exists, token absent in consumer and at base, PRESENT at theirs"
else
  bad "FIXTURE BROKEN — sh subject/token preconditions do not hold"; echo
  echo "ledger-reverify-unfalsifiable: FIXTURE BROKEN" >&2; exit 2
fi

# Bucket 1: consults THEIRS, so a pull can settle it and the guard must stand down.
[ "$(verdict PC-SH-UPSTREAM)" = "STILL-LIVE" ] \
  && ok "PC-SH-UPSTREAM (reads THEIRS) → STILL-LIVE (bucket 1, guard stands down)" \
  || bad "PC-SH-UPSTREAM → $(verdict PC-SH-UPSTREAM), expected STILL-LIVE — the guard fires on receipts that DO consult upstream"

# Bucket 3: the defect the reference consumer hit.
[ "$(verdict PC-SH-INSTALLED)" = "NEEDS-REVIEW" ] \
  && ok "PC-SH-INSTALLED (installed copy, upstream ships the subject) → NEEDS-REVIEW (bucket 3)" \
  || bad "PC-SH-INSTALLED → $(verdict PC-SH-INSTALLED), expected NEEDS-REVIEW — a receipt that can never observe the fix was not caught"

# Bucket 2, AND THE ONLY ARM THAT SEPARATES IT FROM BUCKET 3. Both receipts are
# consumer-side-only with the same verb, negation and token; only the subject's upstream
# existence differs. A guard that skips the mapping entirely, or resolves it wrongly, collapses
# the two and convicts this one — which is the difference between reporting a defect and
# libelling a standing consumer-side invariant. Nothing else here can catch that.
[ "$(verdict PC-SH-CONSUMER-OWNED)" = "STILL-LIVE" ] \
  && ok "PC-SH-CONSUMER-OWNED (no upstream counterpart) → STILL-LIVE (bucket 2, not accused)" \
  || bad "PC-SH-CONSUMER-OWNED → $(verdict PC-SH-CONSUMER-OWNED), expected STILL-LIVE — a consumer-owned subject was reported as a defective receipt; no pull can settle it and that is not the receipt's fault"

# Bucket 2 must be DISTINGUISHABLE from bucket 1, not merely un-accused. Both are STILL-LIVE,
# so the verdict alone cannot tell an operator that no pull will ever settle this entry. Without
# this the whole consumer-owned branch could be a no-op and every arm above would still pass.
_co="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
       | awk -F"\t" '$2 ~ /PC-SH-CONSUMER-OWNED/ {print $3}')"
_up="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
       | awk -F"\t" '$2 ~ /PC-SH-UPSTREAM/ {print $3}')"
if [ -n "$_co" ] && [ "$_co" != "$_up" ]; then
  ok "bucket 2 detail differs from bucket 1's — an operator can tell 'no pull can settle this' from an ordinary still-live"
else
  bad "bucket 2 and bucket 1 emit the SAME detail, so the consumer-owned branch says nothing an operator can act on"
fi

# The exemption, and the assertion is NOT-NEEDS-REVIEW rather than a named verdict.
#
# MEASURED WHILE WRITING THIS ARM, and it corrected the expectation: a watchdog scanning
# tree-wide finds its own retired token IN THE LEDGER ENTRY THAT NAMES IT, so `! git grep`
# fails and the shape reports CLOSE-CANDIDATE today, not the permanent STILL-LIVE it was
# described as having. `consumer_reachable` already excludes the ledger for exactly this
# self-reference; a bare `git grep` in a receipt does not.
#
# So the exemption's real contract is that the unfalsifiability guard must not CLAIM this
# shape — whatever the arm concludes about it otherwise is a separate question, and pinning a
# specific verdict here would make this arm fail on an unrelated change.
_wd="$(verdict PC-SH-WATCHDOG)"
[ "$_wd" != "NEEDS-REVIEW" ] \
  && ok "PC-SH-WATCHDOG (tree-wide, no named subject) → $_wd, not claimed by the guard (exempt)" \
  || bad "PC-SH-WATCHDOG → NEEDS-REVIEW — a STAYS-RETIRED watchdog was libelled as unfalsifiable; its exit 0 is the healthy steady state"

# The detail must join the EXISTING vocabulary, not invent a synonym. A verdict alone does not
# tell the reader which of the three NEEDS-REVIEW causes this is.
# `grep -q` is fed a HERE-STRING, never a pipe: it exits at the first match while the writer
# is still pushing, and under pipefail the pipeline then answers with the writer's EPIPE and
# reports NOT-FOUND on input that contains the pattern. It is a size threshold, not a race.
_sh_detail="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
              | awk -F'\t' '$2 ~ /PC-SH-INSTALLED/ {print $3}')"
if grep -qF 'unfalsifiable predicate:' <<<"$_sh_detail"; then
  ok "PC-SH-INSTALLED detail carries 'unfalsifiable predicate:' (same vocabulary as the theirs_* arms)"
else
  bad "PC-SH-INSTALLED detail does not say 'unfalsifiable predicate:' — the sh arm invented its own wording"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "ledger-reverify-unfalsifiable: PASS"
else
  echo "ledger-reverify-unfalsifiable: FAIL ($fails)" >&2; exit 1
fi
