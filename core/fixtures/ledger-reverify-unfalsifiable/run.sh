#!/usr/bin/env bash
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
    git -C "$DIST" show "$ref:core/scripts/validate-thing.sh" | grep -qF -- "$s" && s_absent=0
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

echo
if [ "$fails" -eq 0 ]; then
  echo "ledger-reverify-unfalsifiable: PASS"
else
  echo "ledger-reverify-unfalsifiable: FAIL ($fails)" >&2; exit 1
fi
