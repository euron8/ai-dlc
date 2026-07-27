#!/usr/bin/env bash
# reconcile-emit-report/run.sh — prove the reconcile report's mechanical sections are driver-owned:
# emit-report.sh renders them, and --verify fails a report whose region is missing OR hand-edited.
#
# THE DEFECT THIS EXISTS TO CATCH. The report was LLM-authored; a mechanical HARD finding was silently
# dropped from it, twice. Rendering the region is only half — the LLM could still omit it or edit it.
# --verify byte-compares the report's region against a fresh render, so neither omission nor a
# dropped-blocker edit survives.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

verify() { bash "$EMIT" --verify "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1; RC=$?; }

# The orientation block for the BOTH-ADDED template, as rendered.
ORIENT="$(awk '/Semantic worklist orientation/,/^\*\*Deletions/' "$REGION")"
# Which side is the line attributed to? Prints THEIRS or OURS, or nothing.
side_of() { printf '%s\n' "$ORIENT" | awk -v pat="$1" '
  /ONLY IN THEIRS/{s="THEIRS"} /ONLY IN OURS/{s="OURS"} $0 ~ pat {print s; exit}'; }

echo "reconcile-emit-report:"

# --- Assertion 0: SANITY — the rendered region carries the HARD blocker -------
if grep -q "reconcile-mechanical" "$REGION" && grep -q "HARD-UNREGISTERED-CORE-DRIFT" "$REGION" && grep -q "thing.json" "$REGION"; then
  ok "the driver renders a mechanical region carrying the HARD schema blocker"
else
  bad "FIXTURE BROKEN — the rendered region lacks the HARD blocker; negatives below are meaningless"
  echo; echo "reconcile-emit-report: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: --verify PASSES a report carrying the region verbatim -------
verify "$REPORT_GOOD"
[ "$RC" -eq 0 ] && ok "--verify PASSES a report whose region matches the driver (exit 0)" \
  || bad "--verify failed a correct report (rc=$RC) — false positive"

# --- Assertion 2: --verify FAILS a report with NO region (the narrated bug) ---
verify "$REPORT_MISSING"
[ "$RC" -eq 1 ] && ok "--verify FAILS a report with no rendered region (exit 1)" \
  || bad "--verify did NOT fail a report missing the region (rc=$RC) — a narrated report could drop everything"

# --- Assertion 3: --verify FAILS a region hand-edited to DROP the blocker ------
verify "$REPORT_STALE"
[ "$RC" -eq 1 ] && ok "--verify FAILS a region hand-edited to drop the HARD blocker (exit 1) — an edited render cannot hide a finding" \
  || bad "--verify did NOT catch a dropped-blocker edit (rc=$RC) — the region could still be doctored"

# --- Assertion 4: a CLASSIFY file gets an ORIENTATION block -------------------
# The bucket list alone names the file; it says nothing about which side holds what. That
# claim used to live only in LLM prose, and on the 0.106.1 -> 0.113.1 pull it came out
# INVERTED, taking the recommended action down with it.
if printf '%s\n' "$ORIENT" | grep -q 'templates/classes.md'; then
  ok "the BOTH-ADDED file gets an orientation block in the rendered region"
else
  bad "no orientation block for the CLASSIFY file — which side holds what is unstated again"
fi

# --- Assertion 5: THE DEFECT — each side's line is attributed to THAT side -----
t_side="$(side_of 'SENTINEL-THEIRS-ONLY')"
o_side="$(side_of 'SENTINEL-OURS-ONLY')"
if [ "$t_side" = "THEIRS" ] && [ "$o_side" = "OURS" ]; then
  ok "orientation attributes each side's exclusive line to the correct side (theirs->THEIRS, ours->OURS)"
else
  bad "ORIENTATION INVERTED: upstream's line reported under '$t_side', consumer's under '$o_side'. This is the defect the block exists to prevent, in the block itself."
fi

# --- Assertion 6: a truncated side never reads as complete --------------------
# The sample is capped. A cap that does not say so turns a partial list into an apparent
# full one — and the resolution is written from it.
if printf '%s\n' "$ORIENT" | grep -qE 'ONLY IN (THEIRS|OURS) \([0-9]+, complete\)|suppressed'; then
  ok "every sample states whether it is complete or how many lines were suppressed"
else
  bad "the orientation sample is neither marked complete nor reports a suppressed count — a truncated side reads as the whole side"
fi

# --- Assertion 7: the escape hatch is present ---------------------------------
if printf '%s\n' "$ORIENT" | grep -q "full: diff "; then
  ok "each file carries a full-diff command, so a truncated sample is never the only source"
else
  bad "no full-diff command emitted — a suppressed tail would be unreachable from the report"
fi

# --- Assertion 8: MUTANT — orientation lives INSIDE the verified region --------
# If the block sat outside the GENERATED markers, the LLM could edit or drop it and --verify
# would still pass, which is exactly how the narrated report dropped findings before.
MUT="$WORK/report-orient-doctored.md"
{ echo "# Reconcile report (fixture)"; echo; grep -v 'SENTINEL-OURS-ONLY' "$REGION"; } > "$MUT"
verify "$MUT"
[ "$RC" -eq 1 ] && ok "mutant: deleting an orientation line FAILS --verify — the block is inside the verified region" \
  || bad "MUTANT DID NOT FAIL (rc=$RC) — orientation can be doctored without --verify noticing, so it is decoration"

# --- Assertion 9: --verify is PORTABLE across distribution checkouts ----------
# The region embeds the absolute dist path in each `full: diff <(git -C … show …)` command.
# The path must stay concrete — a command the operator has to edit before running is a path
# out they cannot walk — but it made the region unequal across checkouts, and --verify
# byte-compares.
#
# Measured: a consumer generated a report from a scratch clone under /private/tmp; verifying
# that same sound report from a normal checkout failed with "STALE or HAND-EDITED" on nothing
# but the path. A false accusation that sends the operator to regenerate a good report — and
# it defeats the reason --verify is offered to operators at all, since they could only trust
# reports generated at their own dist path.
#
# The alias is a symlink: same repository, different literal path, which is exactly the
# difference that used to break it.
ALIAS="$WORK/dist-alias"
ln -sf "$DIST" "$ALIAS" 2>/dev/null
if [ -e "$ALIAS" ]; then
  bash "$EMIT" --verify "$REPORT_GOOD" "$ALIAS" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
  if [ "$?" -eq 0 ]; then
    ok "--verify PASSES a sound report from a DIFFERENT dist checkout (path-independent)"
  else
    bad "--verify FAILED a sound report merely because the dist checkout is at another path — the operator is told a good report is STALE or HAND-EDITED, and can only verify reports generated at their own path"
  fi

  # And normalization must not have blunted it: a real edit still fails from the other path.
  MUT2="$WORK/report-dropped-line.md"
  { echo "# Reconcile report (fixture)"; echo; grep -v 'HARD-UNREGISTERED-CORE-DRIFT' "$REGION"; } > "$MUT2"
  bash "$EMIT" --verify "$MUT2" "$ALIAS" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
  if [ "$?" -eq 1 ]; then
    ok "a dropped HARD row STILL fails from the other path (normalization did not blunt the check)"
  else
    bad "a dropped HARD blocker passed --verify from another dist path — path-independence was bought by weakening the check that stops a report hiding a finding"
  fi
else
  bad "FIXTURE STALE: could not create a symlink alias for the dist checkout"
fi

# --- The push-candidate ledger section --------------------------------------------------
#
# THIS SECTION WAS UNREACHABLE FROM THIS FIXTURE. The seed never wrote a ledger,
# `ledger-reverify.sh` short-circuits on a missing one, and the section rendered `none` — so an
# assertion of the form "no row here is truncated" passed on an empty string. Two label defects
# and a dropped DETAIL field shipped behind exactly that shape of green.
#
# The POSITIVE CONTROL comes first and hard-exits. Every assertion after it is meaningless
# against a `none` section, and a fixture that reports PASS on a section it never rendered is
# the defect it is supposed to catch, wearing the fixture's own badge.
LSEC="$(awk '/Push-candidate ledger —/{f=1;next} f&&/^\*\*/{f=0} f' "$REGION")"
if printf '%s\n' "$LSEC" | grep -q 'PC-FIXTURE-EMIT-'; then
  ok "the ledger section renders real rows (positive control — every ledger assertion below depends on it)"
else
  bad "FIXTURE VACUOUS — the ledger section is empty or 'none'; the assertions below would pass on nothing"
  echo; echo "reconcile-emit-report: FIXTURE VACUOUS" >&2; exit 2
fi

# The name column is a join key back into the ledger. Whole id, not a prefix.
if printf '%s\n' "$LSEC" | grep -qF 'PC-FIXTURE-EMIT-UNKNOWN-VERB (a parenthetical this long pushes the pre-dash text past seventy characters)'; then
  ok "a ledger row names the whole entry, not a clipped prefix"
else
  bad "the ledger row's name is clipped — a truncated name cannot be grepped back into the ledger"
fi

# THE ROW MUST SAY WHY. `NEEDS-REVIEW` alone sends the operator back to a tool they must re-run.
# Both named causes, because they are emitted from different branches.
if printf '%s\n' "$LSEC" | grep -q 'unresolved: unknown verify verb'; then
  ok "a NEEDS-REVIEW row carries its cause (unresolved)"
else
  bad "a NEEDS-REVIEW row reached the report naming no cause — the operator must re-run the tool to learn anything"
fi
if printf '%s\n' "$LSEC" | grep -q 'vacuous predicate:'; then
  ok "a NEEDS-REVIEW row carries its cause (vacuous)"
else
  bad "the vacuous-predicate cause did not reach the report"
fi

# --- Assertion: the sha line is markdown, not shell-escaped markdown ----------
# The region is specified to be pasted VERBATIM into a markdown report, so a literal
# backslash before a backtick renders as an escaped backtick — the shas show wrapped in two
# backslashes instead of as inline code, on the one line the whole report is about. And
# because --verify byte-matches the region against a fresh render, a consumer who writes
# correct markdown gets a FAIL and is pushed back to the malformed text.
base_line="$(grep -m1 '^_base_ ' "$REGION")"
if [ -z "$base_line" ]; then
  bad "FIXTURE BROKEN — the region has no '_base_' line, so the assertion below tests nothing"
elif printf '%s' "$base_line" | grep -q '\\`'; then
  bad "the region's sha line carries literal backslash-backticks: $base_line"
else
  ok "the region's _base_/_theirs_ line wraps both shas in real backticks (renders as inline code)"
fi

# --- Assertion: MUTATION — restore the escapes inside the single quotes --------
# Rendered from a COPY of the whole reconcile dir, so the mutant's helper lookups resolve
# exactly as the real script's do and a missing helper cannot masquerade as a kill.
MUTR="$WORK/mut-reconcile"
rm -rf "$MUTR"; cp -R "$(dirname "$EMIT")" "$MUTR"
sha_line_of() { bash "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | grep -m1 '^_base_ '; }
sed 's@_base_ `%s` → _theirs_ `%s`.@_base_ \\`%s\\` → _theirs_ \\`%s\\`.@' "$EMIT" > "$MUTR/mutant-emit.sh"

if printf '%s' "$(sha_line_of "$MUTR/emit-report.sh")" | grep -q '\\`'; then
  bad "FIXTURE BROKEN — an UNMUTATED copy in the mutant directory already emits backslashes, so the mutation below would score a false kill"
elif cmp -s "$EMIT" "$MUTR/mutant-emit.sh"; then
  bad "FIXTURE BROKEN — the mutation matched nothing, so the assertion above is unproven"
elif printf '%s' "$(sha_line_of "$MUTR/mutant-emit.sh")" | grep -q '\\`'; then
  ok "mutation: re-escaping inside the single quotes puts literal backslashes back (the assertion above is load-bearing)"
else
  bad "the mutant emitted no backslashes — the assertion above cannot fail and is vacuous"
fi

echo
if [ "$fails" -eq 0 ]; then echo "reconcile-emit-report: PASS"; exit 0; fi
echo "reconcile-emit-report: $fails assertion(s) FAILED" >&2
exit 1
