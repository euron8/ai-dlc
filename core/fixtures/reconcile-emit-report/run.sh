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
if grep -q 'templates/classes.md' <<<"$ORIENT"; then
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
if grep -qE 'ONLY IN (THEIRS|OURS) \([0-9]+, complete\)|suppressed' <<<"$ORIENT"; then
  ok "every sample states whether it is complete or how many lines were suppressed"
else
  bad "the orientation sample is neither marked complete nor reports a suppressed count — a truncated side reads as the whole side"
fi

# --- Assertion 7: the escape hatch is present ---------------------------------
if grep -q "full: diff " <<<"$ORIENT"; then
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
if grep -q 'PC-FIXTURE-EMIT-' <<<"$LSEC"; then
  ok "the ledger section renders real rows (positive control — every ledger assertion below depends on it)"
else
  bad "FIXTURE VACUOUS — the ledger section is empty or 'none'; the assertions below would pass on nothing"
  echo; echo "reconcile-emit-report: FIXTURE VACUOUS" >&2; exit 2
fi

# The name column is a join key back into the ledger. Whole id, not a prefix.
if grep -qF 'PC-FIXTURE-EMIT-UNKNOWN-VERB (a parenthetical this long pushes the pre-dash text past seventy characters)' <<<"$LSEC"; then
  ok "a ledger row names the whole entry, not a clipped prefix"
else
  bad "the ledger row's name is clipped — a truncated name cannot be grepped back into the ledger"
fi

# THE ROW MUST SAY WHY. `NEEDS-REVIEW` alone sends the operator back to a tool they must re-run.
# Both named causes, because they are emitted from different branches.
if grep -q 'unresolved: unknown verify verb' <<<"$LSEC"; then
  ok "a NEEDS-REVIEW row carries its cause (unresolved)"
else
  bad "a NEEDS-REVIEW row reached the report naming no cause — the operator must re-run the tool to learn anything"
fi
if grep -q 'vacuous predicate:' <<<"$LSEC"; then
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
elif grep -q '\\`' <<<"$base_line"; then
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

if grep -q '\\`' <<<"$(sha_line_of "$MUTR/emit-report.sh")"; then
  bad "FIXTURE BROKEN — an UNMUTATED copy in the mutant directory already emits backslashes, so the mutation below would score a false kill"
elif cmp -s "$EMIT" "$MUTR/mutant-emit.sh"; then
  bad "FIXTURE BROKEN — the mutation matched nothing, so the assertion above is unproven"
elif grep -q '\\`' <<<"$(sha_line_of "$MUTR/mutant-emit.sh")"; then
  ok "mutation: re-escaping inside the single quotes puts literal backslashes back (the assertion above is load-bearing)"
else
  bad "the mutant emitted no backslashes — the assertion above cannot fail and is vacuous"
fi

# =============================================================================
# THE REF'S SPELLING IS NOT THE REF
# =============================================================================
#
# Every assertion above spells theirs as a SHA, which cannot move. An operator does not: they
# type `origin/main`, or a branch, or let a bare invocation resolve "upstream HEAD". `--verify`
# re-renders from the ref it is handed, and the region rendered only that SPELLING — so with a
# symbolic theirs that moved between the dry run and the apply, the region came back
# byte-identical and `--verify` exited 0. SKILL.md makes that exit the precondition for a write
# to a consumer's core, so a 0 there is an approval given without sight of the finding.
#
# Measured on a consumer built by scripts/install.sh, refs two core files and zero NEW files
# apart: the two regions differed in EXACTLY ONE line, and it was the _base_/_theirs_ line
# naming the spellings. Every other row is a bucket or a status keyed on STATUS+path and
# carries no content digest, so a file whose bucket held and whose CONTENT moved was invisible.
#
# The three arms below run against ONE seeded tree, offender beside near-miss, because a
# nonzero exit on a moved ref and a zero on an unmoved one establish nothing separately: a
# renderer that keys on the COMMIT passes the first and fails the third, and a renderer keying
# on nothing passes the third alone.
DG() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }
verify_ref() { bash "$EMIT" --verify "$1" "$DIST" "$BASE" "$CONSUMER" "$2" >/dev/null 2>&1; RC=$?; }
core_tree_at() { git -C "$DIST" rev-parse "${1}:core" 2>/dev/null; }

# The APPROVED render — theirs spelled symbolically, ref sitting where the operator approved it.
REGION_SYM="$WORK/region-symbolic.md"
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$REGION_SYM" 2>/dev/null
REPORT_SYM="$WORK/report-symbolic.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$REGION_SYM"; } > "$REPORT_SYM"

# POSITIVE CONTROL, and it hard-exits. If the symbolic render is empty or missing the probe's
# bucket row, the ref-move arms below are comparing nothing to nothing — and "no difference"
# is exactly what they are built to reject, so a dead render would score as a pass.
if grep -qF "UPSTREAM-ONLY  $MOVED_PROBE_PATH" "$REGION_SYM"; then
  ok "the region renders with theirs spelled symbolically, carrying the moved-ref probe's bucket row (positive control)"
else
  bad "FIXTURE BROKEN — the symbolic render carries no row for $MOVED_PROBE_PATH; every moved-ref assertion below would compare empty to empty"
  echo; echo "reconcile-emit-report: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion: the region carries a CONTENT key for theirs at all ------------
# PRESENCE-shaped on purpose. "No stale-content finding was rendered" is true of a renderer
# that emits nothing, so the arm demands the line and a resolved 40-hex tree — `absent`, the
# renderer's own fallback, fails this.
if grep -qE '^_theirs_ `core/` tree `[0-9a-f]{40}`\.$' "$REGION_SYM"; then
  ok "the region names what theirs RESOLVES TO (a \`core/\` tree), not only how it was spelled"
else
  bad "the region carries no resolved content key for theirs — a moved symbolic ref renders identically and --verify cannot see it"
fi

# --- Assertion: the region also keys on VERSION, which is OUTSIDE the hashed tree -----
# PRESENCE-shaped for the same reason as the arm above. `VERSION` lives at the repository root, so
# a `core/` tree hash cannot see it move — but `write_stamp()` reads `<theirs>:VERSION` into the
# stamp's `version:` field, so an upstream move that bumps the version and touches nothing under
# `core/` changes what the stamp CLAIMS while the tree hash reports no change. Measured upstream:
# 236 of 400 commits touch no `core/` file, and 16 of those move `VERSION`. Deleting this line
# re-opens exactly those 16 and nothing else, which is why it is asserted separately from the tree.
if grep -qE '^_theirs_ `VERSION` `[^`]+`\.$' "$REGION_SYM"; then
  ok "the region keys on theirs' VERSION as well as its \`core/\` tree — the stamp's version field is written from outside the hashed subtree"
else
  bad "the region carries no VERSION key — a move that bumps VERSION without touching core/ is invisible to --verify, and the stamp then claims a version the approval never covered"
fi

# --- Assertion: a CORE move under a fixed spelling FAILS --verify -------------
git -C "$DIST" checkout -q "$MOVEREF" 2>/dev/null
printf '#!/usr/bin/env bash\necho MOVED-REF-PROBE moved-after-approval\n' > "$DIST/$MOVED_PROBE_PATH"
DG add -A; DG commit -m "upstream core content moves after the operator approved"
REGION_HARM="$WORK/region-core-moved.md"
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$REGION_HARM" 2>/dev/null

# THE DISCRIMINATION GUARD, and it runs BEFORE the verdict is read. If the move also shifted a
# bucket, `--verify` would fail on the bucket and the arm would pass against a renderer with no
# content key whatsoever. Stripping the tree line must leave the two regions IDENTICAL — that
# is the old renderer's whole field of view, and it is blind here.
# Strips BOTH identity lines, not only the tree. `VERSION` is rendered beside the tree because it
# sits at the repo root, outside the hashed subtree, and still reaches the stamp. A strip that
# removed only the tree line would leave this guard reporting FIXTURE BROKEN the first time a seed
# moves the ref across a version bump — which is a true statement about the wrong row.
strip_tree() { grep -vE '^_theirs_ (`core/` tree|`VERSION`) ' "$1"; }
strip_tree "$REGION_SYM"  > "$WORK/stripped-approved.md"
strip_tree "$REGION_HARM" > "$WORK/stripped-moved.md"
if [ ! -s "$WORK/stripped-approved.md" ]; then
  bad "FIXTURE BROKEN — stripping the tree line emptied the approved region"
elif cmp -s "$WORK/stripped-approved.md" "$REGION_SYM"; then
  bad "FIXTURE BROKEN — the strip removed nothing, so the guard below compares the tree line against itself"
elif ! cmp -s "$WORK/stripped-approved.md" "$WORK/stripped-moved.md"; then
  bad "FIXTURE BROKEN — the core move shifted a row OTHER than the tree line, so the arm below would fire on that row and pass against a renderer carrying no content key at all"
else
  ok "the core move leaves every STATUS+path row byte-identical — only the tree line can carry it (near-miss control for the arm below)"
fi

verify_ref "$REPORT_SYM" "$MOVEREF"
if [ "$RC" -ne 0 ]; then
  ok "--verify FAILS an approved report once theirs MOVED across a core change under the same spelling (rc=$RC)"
else
  bad "--verify PASSED (rc=0) a report approved before upstream's core moved — the spelling was re-rendered, the content was not, and SKILL.md reads that 0 as authorisation to write bytes the operator never saw"
fi

# --- Assertion: a DOCS-ONLY move must NOT fail --verify -----------------------
# THIS ARM EXISTS TO STOP THE KEY BEING "SIMPLIFIED" INTO A COMMIT KEY. The line is keyed on
# the `core/` TREE deliberately. The distribution commits docs and plans between releases, and
# the live incident that surfaced all of this was exactly that shape — the ref advanced by one
# docs-only commit while `core` was untouched. Keyed on the commit, this arm goes red and the
# consumer is wedged: told to re-emit and re-approve a report that was never wrong. Keyed on
# the tree, it fires when and only when the bytes the pull would WRITE have changed.
#
# If you are here because you changed the key and this arm went red: the arm is the finding.
DG reset --hard "$THEIRS"
mkdir -p "$DIST/docs"; printf 'a docs-only commit between releases\n' > "$DIST/docs/note.md"
DG add -A; DG commit -m "docs-only commit — core untouched"
REGION_DOCS="$WORK/region-docs-moved.md"
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$REGION_DOCS" 2>/dev/null

moved_to="$(git -C "$DIST" rev-parse "$MOVEREF" 2>/dev/null)"
if [ "$moved_to" = "$THEIRS" ]; then
  bad "FIXTURE BROKEN — the docs-only commit did not move $MOVEREF, so the arm below passes on a ref that never moved"
elif [ "$(core_tree_at "$MOVEREF")" != "$(core_tree_at "$THEIRS")" ]; then
  bad "FIXTURE BROKEN — the 'docs-only' commit changed the core tree, so the arm below is not testing a docs-only move"
else
  # A NOTE, not an `ok`. This branch is derived entirely from git and says nothing about
  # emit-report.sh, so it reads TRUE against a subject replaced by `exit 0` — and an `ok` line
  # that survives a silent subject is the exact shape this fixture exists to reject. Its
  # failure branches above stay `bad`, because a seed that did not move the ref, or that moved
  # the core tree, makes the assertion below vacuous.
  printf '  --    (near-miss preconditions derived, not assumed: the docs-only commit moved %s and held the core tree)\n' "$MOVEREF"
fi

verify_ref "$REPORT_SYM" "$MOVEREF"
# Presence conjunct: rc=0 alone is what a renderer that emits NOTHING also produces, so a bare
# exit-code arm here would be absence-shaped and would pass against a subject replaced by
# `exit 0`. The render at the moved ref must therefore still carry the tree line and still
# equal the approved region.
#
# THE MISSING-LINE CASE STANDS DOWN rather than reporting: "the region has no tree line" is the
# presence assertion's finding, and it has already failed the fixture by the time control
# reaches here. Reported twice, one of the two arms is vacuous and the run no longer says which
# one is load-bearing — and the message this arm would print (`--verify` rejected a sound
# report) is FALSE in that state, because rc is 0. Standing down prints no `ok`, so a renderer
# emitting nothing still cannot earn a green from this arm.
if ! grep -qE '^_theirs_ `core/` tree `[0-9a-f]{40}`\.$' "$REGION_DOCS"; then
  # SINGLE-quoted, so a backslash before a backtick is a literal backslash, not an escape —
  # the same quoting bug assertion 16 above exists to catch, in this fixture's own output.
  printf '  --    (docs-only near-miss STANDS DOWN — the region renders no `core/` tree line at all, which the presence assertion above owns)\n'
elif [ "$RC" -eq 0 ] && cmp -s "$REGION_SYM" "$REGION_DOCS"; then
  ok "--verify PASSES the same report after a DOCS-ONLY move — the key is the \`core/\` tree, so a docs commit between releases cannot wedge a consumer's pull"
else
  bad "a docs-only upstream commit made --verify reject a sound approved report (rc=$RC) — keyed on the commit rather than the core tree, this sends the consumer back to re-approve a report that was never wrong"
fi

# --- Assertion: MUTANT — delete the tree line and the core move goes invisible --
# Rendered from a COPY of the whole reconcile dir so the mutant's sibling lookups (preclassify,
# retired-tokens, ledger-reverify) resolve exactly as the real script's do; a copy that died
# sourcing a helper emits nothing, and nothing would otherwise score as a kill.
DG reset --hard "$THEIRS"
MUTT="$WORK/mut-reconcile-tree"
rm -rf "$MUTT"; cp -R "$(dirname "$EMIT")" "$MUTT"
# Anchored on the rendered text, which is unique in the file — the prose above it says
# "`core/` TREE" in caps and does not match. The impossible anchor is the control.
anchor_hits="$(grep -c '_theirs_ `core/` tree ' "$EMIT")"
control_hits="$(grep -c 'ZZ-NO-SUCH-ANCHOR-IN-THIS-FILE-ZZ' "$EMIT")"
sed '/_theirs_ `core\/` tree /d' "$EMIT" > "$MUTT/mutant-emit.sh"

CTL_REGION="$WORK/mut-ctl-region.md"; MUT_REGION="$WORK/mut-region.md"
bash "$MUTT/emit-report.sh"  "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$CTL_REGION" 2>/dev/null
bash "$MUTT/mutant-emit.sh"  "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$MUT_REGION" 2>/dev/null
CTL_REPORT="$WORK/mut-ctl-report.md"; MUT_REPORT="$WORK/mut-report.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$CTL_REGION"; } > "$CTL_REPORT"
{ echo "# Reconcile report (fixture)"; echo; cat "$MUT_REGION"; } > "$MUT_REPORT"

# Now move theirs across the same core change both renderers were pointed at.
git -C "$DIST" checkout -q "$MOVEREF" 2>/dev/null
printf '#!/usr/bin/env bash\necho MOVED-REF-PROBE moved-under-the-mutant\n' > "$DIST/$MOVED_PROBE_PATH"
DG add -A; DG commit -m "upstream core content moves under the mutant battery"
bash "$MUTT/emit-report.sh" --verify "$CTL_REPORT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" >/dev/null 2>&1
ctl_rc=$?
bash "$MUTT/mutant-emit.sh" --verify "$MUT_REPORT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" >/dev/null 2>&1
mut_rc=$?

# The UNMUTATED control, with a positive conjunct: a baseline row must be THERE. rc=1 and an
# empty region is what a copy that failed to start also looks like.
if [ "$anchor_hits" -ne 1 ]; then
  bad "FIXTURE BROKEN — the mutation anchor matches $anchor_hits lines in emit-report.sh, not 1; a multi-line edit moves cells this battery does not own"
elif [ "$control_hits" -ne 0 ]; then
  bad "FIXTURE BROKEN — the impossible-anchor control matched $control_hits lines, so the uniqueness count above means nothing"
elif cmp -s "$EMIT" "$MUTT/mutant-emit.sh"; then
  bad "FIXTURE BROKEN — the mutation matched nothing, so the arms above are unproven"
elif ! grep -qF "UPSTREAM-ONLY  $MOVED_PROBE_PATH" "$CTL_REGION"; then
  bad "FIXTURE BROKEN — the UNMUTATED copy rendered no baseline row, so the copied directory is what failed, not the mutation"
elif [ "$ctl_rc" -ne 1 ]; then
  bad "FIXTURE BROKEN — the unmutated copy did NOT reject the moved ref (rc=$ctl_rc); the mutant's silence below would prove nothing"
else
  ok "control: the UNMUTATED copy renders the baseline row and still rejects the moved ref (rc=$ctl_rc)"
fi

# THE MUTANT. Positive conjunct again: it must render a real region that carries the baseline
# row and LACKS the tree line. A renderer replaced by `exit 0` also exits 0 on --verify.
#
# THE NO-OP GUARD IS REPEATED HERE ON PURPOSE, not left to the control's chain above. If the
# tree line is already gone from emit-report.sh — someone reverted the fix — the `sed` matches
# nothing, the "mutant" is a byte-identical copy, and it is blind for the reason the SUBJECT is
# blind rather than for the reason the mutation intends. Measured: without this conjunct that
# state printed `ok` here, a mutation that mutated nothing scoring a kill beside the very
# assertions it had just stopped proving.
if [ "$anchor_hits" -eq 1 ] && ! cmp -s "$EMIT" "$MUTT/mutant-emit.sh" \
   && grep -qF "UPSTREAM-ONLY  $MOVED_PROBE_PATH" "$MUT_REGION" \
   && ! grep -q '^_theirs_ `core/` tree ' "$MUT_REGION" \
   && [ "$mut_rc" -eq 0 ]; then
  ok "mutant: with the tree line deleted the region still renders every bucket, and the core move becomes INVISIBLE to --verify (rc=$mut_rc) — the arms above are load-bearing"
else
  bad "MUTANT DID NOT SURVIVE ITS OWN DELETION (region rows present? / tree line gone? / rc=$mut_rc) — something OTHER than the tree line is carrying the moved-ref arms, so those arms do not test what they claim"
fi

# --- Assertions 12-14: the shadowed-local-validator signal is REACHED by the driver ---
# THE DEFECT. `warn-shadowed-local-validators.sh` shipped in reconcile/, named itself the twin
# of ledger-reverify's CLOSE-CANDIDATE and layer-drift's EXTENSION-RETIRE-CANDIDATE, and both
# of those render here — it did not. SKILL.md named it ZERO times; no step and no driver
# invoked it. `core/fixtures/shadowed-local-validators/` was green over it the whole time,
# which is the trap: a fixture proving a detector WORKS says nothing about whether the shipping
# program RUNS it.
#
# A HEADING PLUS `none` CANNOT CATCH THIS, which is why these arms seed a real row. If the
# driver never called the detector, `sv` would be empty and the section would render `none` —
# byte-identical to a detector that ran and found nothing. The only arm that discriminates is
# one where the detector MUST produce output.
#
# Seeded at the DEFAULT paths, because emit-report.sh passes only `--root`: the ledger at
# `_bmad-output/ai-dlc-update/push-candidate-ledger.md`, forks under `scripts/ai-dlc-local`,
# core twins under `scripts/ai-dlc`. The entry shape is the producer's — a `##` heading and a
# LINE-LEADING `ADOPTED UPSTREAM (…)` annotation, which is what the anchored close grammar in
# ledger-reverify.sh actually accepts.
mkdir -p "$CONSUMER/_bmad-output/ai-dlc-update" "$CONSUMER/scripts/ai-dlc-local" "$CONSUMER/scripts/ai-dlc"
cat > "$CONSUMER/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'SHADLED'
# Push-candidate ledger (fixture)

## PC-CLOSED-SHADOW — validate-shadowprobe.sh: divergence
Prose about core/scripts/validate-shadowprobe.sh.
ADOPTED UPSTREAM (v0.130.0, verified 2026-07-22)

## PC-OPEN-KEEP — validate-keepprobe.sh: divergence
Prose about core/scripts/validate-keepprobe.sh — still diverging.
SHADLED
printf '#!/bin/sh\nexit 0\n' > "$CONSUMER/scripts/ai-dlc-local/validate-shadowprobe.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONSUMER/scripts/ai-dlc/validate-shadowprobe.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONSUMER/scripts/ai-dlc-local/validate-keepprobe.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONSUMER/scripts/ai-dlc/validate-keepprobe.sh"

SHAD_REGION="$WORK/shadow-region.txt"
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$SHAD_REGION" 2>/dev/null

if grep -q 'Shadowed local validators' "$SHAD_REGION"; then
  ok "the driver renders a shadowed-local-validator section at all"
else
  bad "no shadowed-local-validator section in the region — emit-report.sh does not drive warn-shadowed-local-validators.sh, so the detector never runs on a real pull"
fi

# The discriminating arm: a row the detector alone can produce.
if grep -q 'RETIRE-CANDIDATE' "$SHAD_REGION" && grep -q 'scripts/ai-dlc-local/validate-shadowprobe.sh' "$SHAD_REGION"; then
  ok "a CLOSED entry whose fork shadows a core validator reaches the operator as a RETIRE-CANDIDATE row — the detector actually RAN"
else
  bad "the seeded shadowed fork produced no RETIRE-CANDIDATE row in the region. A heading rendering 'none' here is what an uninvoked detector looks like, so this is the arm that separates the two."
fi

# NEGATIVE: the OPEN entry's fork must NOT be flagged. Without this, a detector widened to
# report every fork would satisfy the arm above and look correct.
if grep -q 'validate-keepprobe.sh' "$SHAD_REGION"; then
  bad "the OPEN entry's fork was flagged too — the region is reporting every fork rather than the closed-entry ones, and the arm above would pass on a signal that discriminates nothing"
else
  ok "the OPEN entry's fork is NOT flagged — the rendered signal keeps the CLOSED gate"
fi

# --- Assertion 15: a REFUSING detector renders DETECTOR-REFUSED, never `none` ----------
# The detector's own header: "a caller must be able to tell 'no forks are shadowed' from
# 'this never ran', and those are the same empty output." Exit 2 is a refusal. Rendering
# `none` for it would put a clean line in front of the operator for a check that never
# classified — the failure this whole region exists to prevent, reintroduced by its newest
# section.
#
# The sandbox copies the WHOLE reconcile/ dir: emit-report.sh resolves $SELF beside itself, so
# a copy picks up the stubbed detector, and no shipped file is touched. An UNMUTATED control
# runs through the same sandbox first — a sandbox that simply died also prints no
# RETIRE-CANDIDATE row, and that is indistinguishable from the refusal branch working.
SHADMUT="$WORK/shadow-mutant"
mkdir -p "$SHADMUT"
cp "$(dirname "$EMIT")"/*.sh "$SHADMUT/" 2>/dev/null
cp "$(dirname "$EMIT")"/*.md "$SHADMUT/" 2>/dev/null

ctl_region="$WORK/shadow-ctl-region.txt"
bash "$SHADMUT/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$ctl_region" 2>/dev/null
if grep -q 'scripts/ai-dlc-local/validate-shadowprobe.sh' "$ctl_region"; then
  ok "control: the UNMUTATED sandbox copy renders the RETIRE-CANDIDATE row, so the refusal arm below measures the stub and not a broken sandbox"
else
  bad "FIXTURE BROKEN — the unmutated sandbox copy renders no RETIRE-CANDIDATE row; the refusal arm below would pass for the wrong reason"
fi

printf '#!/usr/bin/env bash\nexit 2\n' > "$SHADMUT/warn-shadowed-local-validators.sh"
mut_region="$WORK/shadow-mut-region.txt"
bash "$SHADMUT/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$mut_region" 2>/dev/null
shad_body="$(awk '/Shadowed local validators/{f=1;next} f&&/^\*\*/{exit} f' "$mut_region")"
if grep -q 'DETECTOR-REFUSED' <<<"$shad_body" && ! grep -qx 'none' <<<"$shad_body"; then
  ok "a detector exiting 2 renders DETECTOR-REFUSED and NOT 'none' — a refusal cannot read as a clean section"
else
  bad "a detector exiting 2 did not produce DETECTOR-REFUSED (got: $(printf '%s' "$shad_body" | tr '\n' ' ' | head -c 120)) — the 0/2 split the detector's contract requires is not preserved by the driver"
fi

# --- Assertion 16: the four classifiers that shipped OUTSIDE the region now render in it ------
# SKILL.md step 5 tells the operator this region carries "every mechanical finding, complete,
# from every detector". It did not: four scripts each declaring themselves "a classifier, not a
# gate" were left to be NARRATED, and `--verify` could not fail on their omission because they
# were never in the region to omit.
#
# `I105` binds the SET — every reconcile/*.sh is invoked here or declares itself exempt with a
# reason. That is a join over file contents and it stays true even if a call is wired to a
# detector that emits nothing usable. This arm is the other half: the sections actually RENDER.
i16_missing=""
for i16_h in "Predicate reclassification" \
             "Retired core fixtures the consumer still carries" \
             "Retired contract shapes in consumer layer files" \
             "Retired core passages still carried" \
             "Retired status tokens reused in a consumer layer file"; do
  grep -qF "$i16_h" "$REGION" || i16_missing="$i16_missing | $i16_h"
done
# CONTROL in the same invocation: a heading that cannot be there must not be found, or a grep
# matching everything would report all four present.
if grep -qF "Retired core passages nobody ever wrote" "$REGION"; then
  bad "FIXTURE BROKEN — the control heading matched, so assertion 16's five positives prove nothing"
elif [ -z "$i16_missing" ]; then
  ok "the five previously-narrated classifiers render as sections of the region (control: an impossible heading is absent)"
else
  bad "these classifier sections are missing from the rendered region:$i16_missing — their findings are back to being narrated, where an omission cannot be caught by --verify"
fi

# =============================================================================
# A MISMATCH IS DECIDED, NOT ONLY REPORTED
# =============================================================================
#
# THE DEFECT. SKILL.md step 7 requires every `HARD-*` blocker resolved BEFORE apply.sh writes,
# and every resolution REWRITES the region the operator approved — a `--stamp readopt` turns
# HARD-OVERRIDE-DRIFT-SECTION into OVERRIDE-OK, a register row removes
# HARD-LAYER-ADJUDICATION-MISSING. So on any pull that had a blocker the approved report lists
# findings that no longer exist, `--verify` fails, and the refusal named two causes that were
# both false. `--verify` now DECIDES: exit 3 with `cause: BLOCKERS-RESOLVED` when the refs are
# unchanged, the approved region carries HARD-* rows the fresh render lacks, the fresh render
# carries none the region lacks, and no detector newly REFUSED; `cause: UPSTREAM-MOVED` when the
# `_base_`/`_theirs_` lines differ; `cause: STAMP-MOVED` when the consumer's own stamp line does;
# else `cause: UNDECIDED`. Every case is still a REFUSAL — only
# the diagnosis moved, and the rows the approval has not seen are counted and listed rather than
# asserted away.
#
# THE SEEDS BELOW ARE SEPARATE WORLDS, each its own copy of the seeded consumer with its own
# approved report rendered AT THAT COPY'S PATH. The region embeds the consumer's absolute path in
# its `full: diff` commands, so a world sharing one report with another is comparing two paths and
# fails for a reason no arm owns; and a world mutated in place is decided by the previous world's
# leftovers.
#
#   V-R  the blocker RESOLVED (the consumer's in-place schema edit reverted to base bytes)
#        -> 3, BLOCKERS-RESOLVED, ONE blocker counted although it renders TWICE, and ZERO
#           unseen rows: the boilerplate a resolution moves into the diff is excluded
#   V-N  resolved AND a NEW HARD row the approval never saw          -> 1, UNDECIDED
#   V-M  resolved AND theirs moved across a core change              -> 1, UPSTREAM-MOVED
#   V-B  a NON-HARD row resolved, refs unchanged                     -> 1, UNDECIDED
#   V-H  the blocker HAND-DROPPED from the region, BOTH copies       -> 1, UNDECIDED
#   V-HA V-H plus a blocker-adjudication file in the consumer        -> 1, UNDECIDED
#   V-S  resolved AND the consumer's STAMP moved                     -> 1, STAMP-MOVED: its own
#           cause, decided between the other two, because the stamp is neither upstream moving
#           nor a finding — and dropped from the key altogether a post-apply re-run read as
#           blockers RESOLVED and was told to re-approve a range already applied
#   V-U  resolved AND a non-HARD row the approval never saw          -> 3, ONE unseen row named
#   V-D  the blocker STILL UNRESOLVED, verified by a copy whose
#        unregistered-drift.sh exits 2                               -> 1, UNDECIDED, one
#           DETECTOR-REFUSED line: an absent HARD row with nobody to vouch for it
#   V-DR the same dead-detector copy with the blocker RESOLVED       -> the same (control: the
#           refusal blocks the cause whatever the disk says)
#   V-HC ONLY the padded blocking-list copy of the HARD row deleted
#        from the report, its detector-section copy left             -> 1, UNDECIDED with BOTH
#           counts ZERO: normalised first, the two sides carry the same row
#   V-HB the blocker unresolved and hard-blockers.sh exiting 2, so
#        the blocking list renders REFUSED                           -> 1, UNDECIDED, one
#           DETECTOR-REFUSED line
#
# V-N, V-H, V-HA, V-D, V-HC and V-HB are the acquittal-side seeds and they are the reason this is
# not one arm. V-R alone is satisfied by "exit 3 whenever anything left the region", which acquits
# a finding the operator never saw; each of the six carries exactly one property V-R lacks.
# V-R and V-U are the discriminating PAIR for the unseen count — same verdict, same cause, and the
# count is 0 on one and 1 on the other, so a count that stopped excluding boilerplate is visible
# as a cell and not as a wording change.
VW="$WORK/vworlds"; mkdir -p "$VW"
V_WORLDS="V-R V-N V-M V-B V-H V-HA V-S V-U V-D V-HC V-HB"
# V-DR is scored under the shipped program only, as a CONTROL on V-D rather than a mutant target:
# its claim is that the refusal blocks the resolved cause whether or not the operator resolved
# anything, which is a statement about the shipped classifier, not about any mutation.
V_CONTROL_WORLD="V-DR"
V_HARD='HARD-UNREGISTERED-CORE-DRIFT'
V_BASELINE='BOTH-ADDED->CLASSIFY  core/skills/ai-dlc/templates/classes.md'
VMD="$WORK/v-mutants"; mkdir -p "$VMD"

v_copy()    { local d="$VW/$1"; rm -rf "$d"; mkdir -p "$d" && cp -R "$CONSUMER" "$d/consumer"; }
v_approve() { # v_approve <world> <ref-to-render-at>
  local d="$VW/$1"
  printf '%s\n' "$2" > "$d/ref"
  bash "$EMIT" "$DIST" "$BASE" "$d/consumer" "$2" > "$d/region.md" 2>/dev/null
  { echo "# Reconcile report (fixture)"; echo; cat "$d/region.md"; } > "$d/approved.md"
  [ -s "$d/region.md" ]
}
# THE RESOLUTION, and it is the shipping producer's own bytes rather than a hand-written
# near-miss: the consumer's copy is put back to exactly what `git show "<base>:<path>"` holds, as
# a real adjudication does.
v_resolve() { git -C "$DIST" show "${BASE}:core/schemas/thing.json" > "$VW/$1/consumer/.claude/schemas/thing.json"; }
v_render()  { local d="$VW/$1"; bash "${2:-$EMIT}" "$DIST" "$BASE" "$d/consumer" "$(cat "$d/ref")" 2>/dev/null; }

# A COPY OF THE COPY, with one sibling replaced by a refusal. The refusing-detector worlds have to
# be verified by the program UNDER TEST, or E7/E10 would be scored against the shipped classifier
# and could not fail. Derived from whichever directory the emit under test lives in, so every
# mutant gets its own pair.
v_stub() { # v_stub <emit-path> <dest-dir> <sibling-to-refuse> -> prints the emit path inside dest
  local e="$1" d="$2" s="$3"
  rm -rf "$d"; cp -R "$(dirname "$e")" "$d" || return 1
  printf '#!/usr/bin/env bash\nexit 2\n' > "$d/$s"
  printf '%s\n' "$d/$(basename "$e")"
}

# v_score <emit> <world> <tag> -> "<rc>|<cause>|<resolved-lines>|<n1>|<n2>|<unseen-lines>"
#
# PRESENCE-SHAPED IN EVERY FIELD. `rc` alone is what a subject replaced by `exit 1` also produces,
# so the cause word, the two counts the cause line prints IN ORDER (BLOCKERS-RESOLVED: blockers
# gone, unseen rows; UNDECIDED: new HARD rows, new DETECTOR-REFUSED lines) and the number of
# `resolved:`/`unseen:` lines are all part of the cell. A classifier that decides nothing scores
# `1|NONE|0|NA|NA|0` and matches no expected value here.
#
# AND THE COUNTS ARE IN THE CELL BECAUSE TWO OF THE MUTANTS BELOW MOVE NOTHING ELSE. E9 and E10
# cover each other on the VERDICT — measured, and the symptom of that is zero failures, not two —
# so each is killed on the diagnosis fields, and E11 is what shows the pair is load-bearing.
v_score() {
  local e="$1" d="$VW/$2" f="$VW/$2/stderr.$3" rc cause nres nuns c1 c2
  bash "$e" --verify "$d/approved.md" "$DIST" "$BASE" "$d/consumer" "$(cat "$d/ref")" >/dev/null 2>"$f"
  rc=$?
  cause="$(awk '/^  cause: /{print $2; exit}' "$f")"
  nres="$(grep -c '^    resolved: ' "$f")" || nres=0
  nuns="$(grep -c '^    unseen: ' "$f")" || nuns=0
  c1="$(awk '/^  cause: /{n=0; for(i=3;i<=NF;i++) if ($i ~ /^[0-9]+$/) { n++; if (n==1) { print $i; exit } } exit}' "$f")"
  c2="$(awk '/^  cause: /{n=0; for(i=3;i<=NF;i++) if ($i ~ /^[0-9]+$/) { n++; if (n==2) { print $i; exit } } exit}' "$f")"
  printf '%s|%s|%s|%s|%s|%s\n' "$rc" "${cause:-NONE}" "$nres" "${c1:-NA}" "${c2:-NA}" "$nuns"
}
v_emit_of() { # v_emit_of <tag>
  case "$1" in
    ship) printf '%s\n' "$EMIT" ;;
    ctl)  printf '%s\n' "$VMD/ctl/emit-report.sh" ;;
    *)    printf '%s\n' "$VMD/$1/mutant-emit.sh" ;;
  esac
}
v_sig() { # v_sig <tag> — scores every world under that tag's program, writing each score beside
  local t="$1" e n dd dh
  e="$(v_emit_of "$t")"
  dd="$(v_stub "$e" "$VMD/dead-drift-$t" unregistered-drift.sh)" || return 1
  dh="$(v_stub "$e" "$VMD/dead-hb-$t"    hard-blockers.sh)"      || return 1
  for n in $V_WORLDS; do
    case "$n" in
      V-D)  v_score "$dd" "$n" "$t" > "$VW/$n/score.$t" ;;
      V-HB) v_score "$dh" "$n" "$t" > "$VW/$n/score.$t" ;;
      *)    v_score "$e"  "$n" "$t" > "$VW/$n/score.$t" ;;
    esac
  done
}
# THE SIGNATURES ARE COMPUTED IN PARALLEL AND NOTHING IS ASSERTED INSIDE A BACKGROUND JOB.
# Thirteen programs times eleven worlds is 143 full re-renders, and serially that put this unit
# past the budget it was given. Each job writes ONLY paths suffixed with its own tag, so no two
# jobs touch a byte in common; every verdict below is read from those files in the foreground,
# where `bad` still counts. `wait` reaps each wave, so nothing is left running — a bare kill on a
# backgrounded subject leaks its grandchild, and this never kills one.
v_par() { # v_par <tag>...
  local t n=0
  for t in "$@"; do
    ( v_sig "$t" ) &
    n=$((n+1))
    if [ "$n" -ge 4 ]; then wait; n=0; fi
  done
  wait
}
v_sigstr()  { local t="$1" n out=""; for n in $V_WORLDS; do out="$out$n=$(cat "$VW/$n/score.$t" 2>/dev/null) "; done; printf '%s\n' "$out"; }
v_diffset() { # v_diffset <tag-a> <tag-b> — names of the worlds whose score differs
  local n out=""
  for n in $V_WORLDS; do
    cmp -s "$VW/$n/score.$1" "$VW/$n/score.$2" || out="$out$n "
  done
  printf '%s' "${out% }"
}
v_of() { cat "$VW/$1/score.$2" 2>/dev/null; }

VDG() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }

# --- build the worlds ---------------------------------------------------------------------
# V-M FIRST, because it is the only one that commits to the dist repo, and every other world's
# approved report is rendered afterwards against a settled tree.
VMREF="fixture-vm-theirs"
git -C "$DIST" checkout -q -B "$VMREF" "$THEIRS" 2>/dev/null
v_copy V-M && v_approve V-M "$VMREF" || bad "FIXTURE BROKEN — could not build world V-M"
v_resolve V-M
printf '#!/usr/bin/env bash\necho MOVED-REF-PROBE moved-under-the-decided-cause\n' > "$DIST/$MOVED_PROBE_PATH"
VDG add -A; VDG commit -m "upstream core content moves after the blocker was resolved"

v_copy V-R && v_approve V-R "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-R"
v_resolve V-R

# V-N: the same resolution PLUS an override whose base_sha resolves in neither repo, which
# layer-drift.sh renders as HARD-OVERRIDE-BASE-UNRESOLVABLE. A row the approval never saw is
# the state that must NEVER read as "the operator's own work", and it is the one property V-R
# lacks.
v_copy V-N && v_approve V-N "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-N"
v_resolve V-N
mkdir -p "$VW/V-N/consumer/.claude/skills/ai-dlc/overrides"
cat > "$VW/V-N/consumer/.claude/skills/ai-dlc/overrides/probe.md" <<'VNOVR'
---
shadows: core/rules/nonexistent.md#Nope
base_sha: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
reason: probe
---

## Nope

probe body
VNOVR

# V-B: a NON-HARD row resolved and nothing else. The ledger is written by this world and then
# rewritten with one entry removed, so the finding it resolves is seeded here and not inherited
# from an earlier arm's edits to the shared consumer.
v_copy V-B || bad "FIXTURE BROKEN — could not build world V-B"
mkdir -p "$VW/V-B/consumer/_bmad-output/ai-dlc-update"
cat > "$VW/V-B/consumer/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'VBLED'
# Push-candidate ledger (fixture)

## PC-VB-KEEP — the verb is not one of the four

verify: theirs_maybe core/schemas/thing.json "rule"

## PC-VB-DROPPED — the verb is not one of the four

verify: theirs_maybe core/schemas/thing.json "keep"
VBLED
v_approve V-B "$THEIRS" || bad "FIXTURE BROKEN — could not render world V-B"
cat > "$VW/V-B/consumer/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'VBLED2'
# Push-candidate ledger (fixture)

## PC-VB-KEEP — the verb is not one of the four

verify: theirs_maybe core/schemas/thing.json "rule"
VBLED2

v_copy V-H && v_approve V-H "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-H"
{ echo "# Reconcile report (fixture)"; echo; grep -v "$V_HARD" "$VW/V-H/region.md"; } > "$VW/V-H/approved.md"

v_copy V-HA && v_approve V-HA "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-HA"
{ echo "# Reconcile report (fixture)"; echo; grep -v "$V_HARD" "$VW/V-HA/region.md"; } > "$VW/V-HA/approved.md"
mkdir -p "$VW/V-HA/consumer/_bmad-output/ai-dlc-update"
printf 'adjudicated by hand\n' > "$VW/V-HA/consumer/_bmad-output/ai-dlc-update/blocker-adjudication-probe.md"

# V-S: the stamp line renders from the CONSUMER's stamp and moves when the CONSUMER re-stamps.
# Keyed into the refs comparison it made a re-stamped consumer read as "upstream moved" — both
# disjuncts of that message false — and pre-empted the resolved cause on a pull that had one. A
# stamp agreeing with the base renders no line at all, so this world's approved region has none.
v_copy V-S || bad "FIXTURE BROKEN — could not build world V-S"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$VW/V-S/consumer/.claude/.ai-dlc-version"
v_approve V-S "$THEIRS" || bad "FIXTURE BROKEN — could not render world V-S"
v_resolve V-S
printf 'version: 2.0.0\ncommit: %s\n' "$THEIRS" > "$VW/V-S/consumer/.claude/.ai-dlc-version"

# V-U: the resolution leaves a NON-HARD row the approval never saw. The override's `base_sha`
# RESOLVES, so it passes the provenance check V-N fails, and its `shadows:` target is absent at
# theirs — upstream restructured and the shadow points at nothing, which layer-drift.sh renders as
# OVERRIDE-ANCHOR-UNRESOLVED [LC-O8]: a real finding, not a HARD one. (c) still fires, because the
# HARD rule is the blocking contract; what must not happen is the count reporting zero.
#
# IT DIFFERS FROM V-N BY EXACTLY ONE PROPERTY, the base_sha, and that is deliberate: the two
# overrides are otherwise the same file, so the pair separates "a new HARD row" from "a new row"
# and nothing else varies with them.
v_copy V-U && v_approve V-U "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-U"
v_resolve V-U
mkdir -p "$VW/V-U/consumer/.claude/skills/ai-dlc/overrides"
cat > "$VW/V-U/consumer/.claude/skills/ai-dlc/overrides/absent-anchor.md" <<VUOVR
---
shadows: core/rules/nonexistent.md#Nope
base_sha: $BASE
reason: probe
---

## Nope

probe body
VUOVR

# V-D / V-DR: the blocker's own detector REFUSES at verify time. Its rows are simply absent, which
# is exactly the shape (c) keys on — so before DETECTOR-REFUSED reached the classifier a dead
# detector was diagnosed as a blocker the operator had resolved, BY NAME, over a drift still on
# disk. V-D leaves the drift UNRESOLVED; V-DR resolves it, and both must read the same, because
# the refusal is what blocks the cause and not the state of the file.
v_copy V-D && v_approve V-D "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-D"
v_copy V-DR && v_approve V-DR "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-DR"
v_resolve V-DR

# V-HC: THE HALF COPY. One blocker renders twice with different padding — `%-32s %s` in the
# blocking list and `STATUS  path` in its detector's section — and a difference taken over RAW
# lines reports the blocker GONE when only the padded copy is missing while the other still
# renders. The first HARD line in the region is the padded one, and only it is deleted here.
v_copy V-HC && v_approve V-HC "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-HC"
awk -v p="^$V_HARD" '$0 ~ p && !d { d=1; next } { print }' "$VW/V-HC/region.md" > "$VW/V-HC/region-half.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$VW/V-HC/region-half.md"; } > "$VW/V-HC/approved.md"

# V-HB: hard-blockers.sh REFUSES, so the blocking list renders DETECTOR-REFUSED instead of the
# padded copies. It is the wrapper the whole HARD- contract keys on, and its call was the one
# detector pipeline with no exit-code check.
v_copy V-HB && v_approve V-HB "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-HB"

# --- SELF-PROBES, BEFORE ANY VERDICT IS READ ------------------------------------------------
# Every arm below is a differential between an approved region and a fresh render. Both sides
# reading the same rows establishes nothing, so each world's two sides are proved to differ
# FIRST, and each probe carries a positive conjunct so a render that emitted nothing cannot
# satisfy it.
V_BASE_BYTES="$WORK/vp-base-thing.json"
git -C "$DIST" show "${BASE}:core/schemas/thing.json" > "$V_BASE_BYTES" 2>/dev/null
if [ ! -s "$V_BASE_BYTES" ]; then
  bad "FIXTURE BROKEN — base bytes for core/schemas/thing.json did not resolve; the resolution below writes an empty file and every V-arm is meaningless"
elif cmp -s "$V_BASE_BYTES" "$CONSUMER/.claude/schemas/thing.json"; then
  bad "FIXTURE BROKEN — the seeded consumer ALREADY carries the base bytes, so the resolution changes nothing and V-R's exit 3 would be decided by something else"
else
  ok "SP1 the seeded consumer's schema and the base bytes DIFFER, so reverting one to the other is a real resolution (control for every V-arm)"
fi

V_R_AFTER="$WORK/vp-vr-after.md"; v_render V-R > "$V_R_AFTER"
if ! grep -q "$V_HARD" "$VW/V-R/region.md"; then
  bad "FIXTURE BROKEN — V-R's APPROVED region carries no $V_HARD row, so there is no blocker for the resolution to remove"
elif ! grep -qF "$V_BASELINE" "$V_R_AFTER"; then
  bad "FIXTURE BROKEN — the render AFTER the resolution carries no baseline bucket row, so it is an empty or dead render and its missing HARD row proves nothing"
elif grep -q "$V_HARD" "$V_R_AFTER"; then
  bad "FIXTURE BROKEN — the resolution did NOT remove the $V_HARD row from a fresh render, so V-R is not the state it claims to be"
else
  ok "SP2 V-R's two sides differ in the way the arm needs: the approved region carries $V_HARD, the post-resolution render still carries the baseline bucket row and no longer carries the blocker"
fi

V_N_AFTER="$WORK/vp-vn-after.md"; v_render V-N > "$V_N_AFTER"
if grep -q 'HARD-OVERRIDE-BASE-UNRESOLVABLE' "$VW/V-N/region.md"; then
  bad "FIXTURE BROKEN — V-N's APPROVED region already carries HARD-OVERRIDE-BASE-UNRESOLVABLE, so the row is not NEW and V-N is a copy of V-R"
elif ! grep -q 'HARD-OVERRIDE-BASE-UNRESOLVABLE' "$V_N_AFTER"; then
  bad "FIXTURE BROKEN — the probe override rendered no HARD-OVERRIDE-BASE-UNRESOLVABLE row, so V-N carries no new blocker and cannot discriminate the hard_new conjunct"
elif grep -q "$V_HARD" "$V_N_AFTER"; then
  bad "FIXTURE BROKEN — V-N's post-resolution render still carries $V_HARD, so it is not testing 'resolved AND a new row', only 'a new row'"
else
  ok "SP3 V-N's fresh render carries a HARD row the approved region LACKS (HARD-OVERRIDE-BASE-UNRESOLVABLE) while the approved region's blocker is gone — both properties, which is what makes it the discriminating seed"
fi

v_moved_to="$(git -C "$DIST" rev-parse "$VMREF" 2>/dev/null)"
v_tree_moved="$(git -C "$DIST" rev-parse "${VMREF}:core" 2>/dev/null)"
v_tree_appr="$(git -C "$DIST" rev-parse "${THEIRS}:core" 2>/dev/null)"
if [ "$v_moved_to" = "$THEIRS" ]; then
  bad "FIXTURE BROKEN — $VMREF did not move, so V-M's refs are identical and it is a second copy of V-R"
elif [ -z "$v_tree_moved" ] || [ "$v_tree_moved" = "$v_tree_appr" ]; then
  bad "FIXTURE BROKEN — $VMREF moved without changing the core/ tree, so the refs lines still agree and V-M cannot reach UPSTREAM-MOVED"
else
  ok "SP4 V-M's ref moved AND its core/ tree changed, so its refs lines genuinely differ from the approved region's (derived from git, not assumed)"
fi

V_B_AFTER="$WORK/vp-vb-after.md"; v_render V-B > "$V_B_AFTER"
v_b_hard_appr="$(grep -c '^HARD-' "$VW/V-B/region.md")" || v_b_hard_appr=0
v_b_hard_after="$(grep -c '^HARD-' "$V_B_AFTER")" || v_b_hard_after=0
if ! grep -q 'PC-VB-DROPPED' "$VW/V-B/region.md"; then
  bad "FIXTURE BROKEN — V-B's approved region carries no PC-VB-DROPPED row, so the ledger entry it removes was never rendered and V-B resolves nothing"
elif grep -q 'PC-VB-DROPPED' "$V_B_AFTER"; then
  bad "FIXTURE BROKEN — removing the ledger entry did not remove its row from a fresh render, so V-B's two sides do not differ"
elif [ "$v_b_hard_appr" -eq 0 ] || [ "$v_b_hard_appr" -ne "$v_b_hard_after" ]; then
  bad "FIXTURE BROKEN — V-B moved a HARD row too ($v_b_hard_appr approved vs $v_b_hard_after rendered), so it is not a NON-HARD resolution and it cannot discriminate the HARD- keying"
else
  ok "SP5 V-B resolves a NON-HARD row only: the PC-VB-DROPPED row leaves the render while all $v_b_hard_appr HARD rows stay put"
fi

if grep -q '^_stamp_ ' "$VW/V-S/region.md"; then
  bad "FIXTURE BROKEN — V-S's APPROVED region already carries a _stamp_ line, so moving the stamp changes nothing and V-S is a second copy of V-R"
else
  V_S_AFTER="$WORK/vp-vs-after.md"; v_render V-S > "$V_S_AFTER"
  if ! grep -q '^_stamp_ ' "$V_S_AFTER"; then
    bad "FIXTURE BROKEN — moving the consumer's stamp rendered no _stamp_ line, so V-S's two sides do not differ on the stamp at all"
  elif grep -q "$V_HARD" "$V_S_AFTER"; then
    bad "FIXTURE BROKEN — V-S's post-move render still carries $V_HARD, so it is not testing 'resolved AND the stamp moved'"
  else
    ok "SP6 V-S's stamp move adds a _stamp_ line the approved region lacks AND its blocker is resolved — both, which is what makes the stamp's exclusion from the refs comparison observable"
  fi
fi

V_U_AFTER="$WORK/vp-vu-after.md"; v_render V-U > "$V_U_AFTER"
v_u_hard_after="$(grep -c '^HARD-' "$V_U_AFTER")" || v_u_hard_after=0
if grep -q 'OVERRIDE-ANCHOR-UNRESOLVED' "$VW/V-U/region.md"; then
  bad "FIXTURE BROKEN — V-U's APPROVED region already carries OVERRIDE-ANCHOR-UNRESOLVED, so the row is not unseen and V-U is a copy of V-R"
elif ! grep -q 'OVERRIDE-ANCHOR-UNRESOLVED' "$V_U_AFTER"; then
  bad "FIXTURE BROKEN — the absent-anchor override rendered no OVERRIDE-ANCHOR-UNRESOLVED row, so V-U carries no unseen finding and cannot discriminate the unseen count"
elif grep -q 'HARD-OVERRIDE-BASE' "$V_U_AFTER"; then
  bad "FIXTURE BROKEN — V-U's override was rejected on its base_sha before the anchor was ever resolved, so it is a second copy of V-N and proves nothing about a NON-HARD unseen row"
elif [ "$v_u_hard_after" -ne 0 ]; then
  bad "FIXTURE BROKEN — V-U's post-resolution render carries $v_u_hard_after HARD row(s), so it would be decided by the HARD conjunct rather than by the unseen count"
else
  ok "SP7 V-U's fresh render carries a NON-HARD row the approved region lacks (OVERRIDE-ANCHOR-UNRESOLVED) and no HARD row at all — the count, not the verdict, is what it discriminates"
fi

V_DEAD_DRIFT="$(v_stub "$EMIT" "$VMD/probe-dead-drift" unregistered-drift.sh)"
V_DEAD_HB="$(v_stub "$EMIT" "$VMD/probe-dead-hb" hard-blockers.sh)"
V_D_AFTER="$WORK/vp-vd-after.md"; v_render V-D "$V_DEAD_DRIFT" > "$V_D_AFTER"
V_D_ALIVE="$WORK/vp-vd-alive.md"; v_render V-D > "$V_D_ALIVE"
if cmp -s "$V_BASE_BYTES" "$VW/V-D/consumer/.claude/schemas/thing.json"; then
  bad "FIXTURE BROKEN — V-D's drift was resolved on disk, so its missing HARD row is a resolution and not a refusal, and it cannot discriminate the DETECTOR-REFUSED conjunct"
elif ! grep -qF 'DETECTOR-REFUSED  unregistered-drift.sh' "$V_D_AFTER"; then
  bad "FIXTURE BROKEN — the stubbed detector rendered no 'DETECTOR-REFUSED  unregistered-drift.sh' line, so V-D's fresh render is not the state it claims and the arm below cannot fire"
elif grep -qF 'DETECTOR-REFUSED  unregistered-drift.sh' "$V_D_ALIVE"; then
  bad "FIXTURE BROKEN — the UNMUTATED copy also renders DETECTOR-REFUSED for that detector, so the two sides do not differ and the stub is not what produced the line"
elif ! grep -q "$V_HARD" "$V_D_ALIVE"; then
  bad "FIXTURE BROKEN — the unmutated render of V-D's consumer carries no $V_HARD row, so the drift the refusal hides was never rendered and there is nothing for the refusal to conceal"
else
  ok "SP8 V-D's drift is STILL ON DISK and still renders as $V_HARD under a live detector, while the stubbed copy renders DETECTOR-REFUSED and no HARD row — the two sides differ, and they differ by the stub"
fi

# SP9: the half copy. The row must be REMOVED from the report, the SURVIVING copy must still be
# there, and the two must be the same row once whitespace is collapsed — otherwise V-HC is not a
# padding difference at all and E9 would be scored against something else.
v_hc_appr="$(grep -c "^$V_HARD" "$VW/V-HC/region-half.md")" || v_hc_appr=0
v_hc_full="$(grep -c "^$V_HARD" "$VW/V-HC/region.md")" || v_hc_full=0
v_hc_a="$(grep -m1 "^$V_HARD" "$VW/V-HC/region-half.md" | sed -E 's/[[:space:]]+/ /g')"
v_hc_b="$(grep -m1 "^$V_HARD" "$VW/V-HC/region.md" | sed -E 's/[[:space:]]+/ /g')"
if [ "$v_hc_full" -ne 2 ]; then
  bad "FIXTURE BROKEN — the region renders $v_hc_full copies of $V_HARD, not 2, so 'delete one copy' is not the state V-HC claims to build"
elif [ "$v_hc_appr" -ne 1 ]; then
  bad "FIXTURE BROKEN — V-HC's report carries $v_hc_appr copies of $V_HARD after the cut, not 1: either nothing was deleted or both copies were"
elif [ "$v_hc_a" != "$v_hc_b" ]; then
  bad "FIXTURE BROKEN — the deleted copy and the surviving copy are DIFFERENT rows once whitespace is collapsed ('$v_hc_b' vs '$v_hc_a'), so V-HC is not a padding difference and E9 would be scored against a real row"
else
  ok "SP9 V-HC deletes one of the region's two copies of the blocker and leaves the other, and the two are the same row once whitespace is collapsed — a padding difference and nothing else"
fi

# SP10: the refusing WRAPPER. The blocking list must go, the detector-section copy must stay —
# that surviving copy is precisely why normalisation alone already prevents the misread, and it
# is what makes E9 and E10 cover each other.
V_HB_AFTER="$WORK/vp-vhb-after.md"; v_render V-HB "$V_DEAD_HB" > "$V_HB_AFTER"
v_hb_hard="$(grep -c "^$V_HARD" "$V_HB_AFTER")" || v_hb_hard=0
if cmp -s "$V_BASE_BYTES" "$VW/V-HB/consumer/.claude/schemas/thing.json"; then
  bad "FIXTURE BROKEN — V-HB's drift was resolved on disk, so its blocking list would be empty anyway and the refusal is not what the arm reads"
elif ! grep -qF 'DETECTOR-REFUSED  hard-blockers.sh' "$V_HB_AFTER"; then
  bad "FIXTURE BROKEN — the stubbed wrapper rendered no 'DETECTOR-REFUSED  hard-blockers.sh' line, so V-HB's fresh render is not the state it claims"
elif [ "$v_hb_hard" -ne 1 ]; then
  bad "FIXTURE BROKEN — V-HB's render carries $v_hb_hard copy(ies) of $V_HARD, not the 1 the detector's own section renders; the wrapper's refusal is not what removed the padded copy"
else
  ok "SP10 V-HB's wrapper refuses, the padded blocking-list copy of the blocker is gone and the detector section's copy remains — which is the state where the padded copy alone looked resolved"
fi

# --- STAGE THE MUTANTS, THEN SCORE EVERY PROGRAM ---------------------------------------------
# Each is a copy of the WHOLE reconcile directory: emit-report.sh resolves $SELF beside itself
# and shells to preclassify.sh, layer-drift.sh, ledger-reverify.sh and more, so a lone script
# copy dies before printing anything and "no cause" would score as a kill on every arm at once.
#
# KILL SETS ARE ASSERTED EXACTLY AND SOME OF THEM HAVE THREE MEMBERS. That is the arms
# OVERLAPPING rather than the mutants being wrong, and it is measured rather than assumed: V-R
# and V-U read exit 3, so every mutation of the resolved-cause BRANCH moves all three.
# What separates those mutants is what they move BEYOND that set — E5 reaches V-HA, E1 does not —
# and the specific wrong verdict each world takes, asserted per world below.
V_APPLIED=""
v_mk() { # v_mk <name> <expected-anchor-hits> <anchor-regex> <sed-arg...>
  local n="$1" want="$2" anch="$3"; shift 3
  local d="$VMD/$n" hits ctl
  rm -rf "$d"; cp -R "$(dirname "$EMIT")" "$d" || return 1
  [ -f "$d/preclassify.sh" ] || { bad "$n did not stage its siblings — a copy missing preclassify.sh emits nothing and its silence would score as a kill"; return 1; }
  hits="$(grep -c -e "$anch" "$EMIT")" || hits=0
  ctl="$(grep -c -e 'ZZ-NO-SUCH-ANCHOR-IN-EMIT-REPORT-ZZ' "$EMIT")" || ctl=0
  if [ "$ctl" -ne 0 ]; then
    bad "$n the impossible-anchor control matched $ctl lines in emit-report.sh, so the uniqueness count below means nothing"; return 1
  fi
  if [ "$hits" -ne "$want" ]; then
    bad "$n's anchor matches $hits line(s) in emit-report.sh, not $want — the subject was respelled and this mutant edits something other than what it names. Re-anchor it; do NOT relax the assertion."; return 1
  fi
  if ! sed "$@" "$EMIT" > "$d/mutant-emit.sh"; then
    bad "$n DID NOT APPLY — sed failed, so no mutant exists and the arm it guards is unproven"; return 1
  fi
  if cmp -s "$EMIT" "$d/mutant-emit.sh"; then
    bad "$n DID NOT APPLY — the sed matched nothing, so the arm it guards is unproven"; return 1
  fi
  V_APPLIED="$V_APPLIED $n"
  return 0
}
V_ELIF='^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$'
V_E9SED='s/| norm_rows)/| LC_ALL=C sort)/g'
V_E10SED='s/^  if \[ "$hb_rc" -eq 0 \]; then /  if true; then /'

v_mk E1 1 '^\[ "$cause" = BLOCKERS-RESOLVED \] && exit 3$' -e '/^\[ "$cause" = BLOCKERS-RESOLVED \] && exit 3$/d'
v_mk E2 1 '^if \[ "$refs_render" != "$refs_report" \]; then$' \
  -e 's/^if \[ "$refs_render" != "$refs_report" \]; then$/if [ 1 -eq 0 ]; then/'
v_mk E3 1 "$V_ELIF" \
  -e 's/^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$/elif [ "$hard_gone" -gt 0 ] \&\& [ "$refused_new" -eq 0 ]; then/'
v_mk E4 1 "$V_ELIF" \
  -e 's/^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$/elif [ -n "$only_report" ] \&\& [ "$hard_new" -eq 0 ] \&\& [ "$refused_new" -eq 0 ]; then/'
v_mk E5 1 "$V_ELIF" \
  -e 's|^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$|elif ls "$CONSUMER"/_bmad-output/ai-dlc-update/blocker-adjudication-*.md >/dev/null 2>\&1; then|'
v_mk E6 1 '^elif \[ "$stamp_render" != "$stamp_report" \]; then$' \
  -e 's/^elif \[ "$stamp_render" != "$stamp_report" \]; then$/elif [ 1 -eq 0 ]; then/'
v_mk E7 1 "$V_ELIF" \
  -e 's/^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$/elif [ "$hard_gone" -gt 0 ] \&\& [ "$hard_new" -eq 0 ]; then/'
v_mk E8 1 "^unseen_rows() { grep -Ev '" -e "s|^unseen_rows() { grep -Ev '.*\$|unseen_rows() { grep -Ev '^HARD-\|^\$'; }|"
v_mk E9  2 '| norm_rows)' -e "$V_E9SED"
v_mk E10 1 '^  if \[ "$hb_rc" -eq 0 \]; then ' -e "$V_E10SED"
v_mk E11 2 '| norm_rows)' -e "$V_E9SED" -e "$V_E10SED"

rm -rf "$VMD/ctl"; cp -R "$(dirname "$EMIT")" "$VMD/ctl"
v_par ship ctl $V_APPLIED
v_score "$V_DEAD_DRIFT" "$V_CONTROL_WORLD" ship > "$VW/$V_CONTROL_WORLD/score.ship"
V_SHIP="$(v_sigstr ship)"
V_CTL="$(v_sigstr ctl)"

# --- THE CORPUS ARMS ------------------------------------------------------------------------
v_vr="$(v_of V-R ship)"
if [ "$v_vr" = "3|BLOCKERS-RESOLVED|1|1|0|0" ] && grep -q "resolved: $V_HARD" "$VW/V-R/stderr.ship"; then
  ok "V-R a blocker RESOLVED after the render exits 3 with cause BLOCKERS-RESOLVED, names the row it decided from, counts ONE blocker although the region renders it twice, and counts ZERO unseen rows"
else
  bad "V-R the resolved-blocker case scored $v_vr (want 3|BLOCKERS-RESOLVED|1|1|0|0) — either the cause is not decided, or the blocker count is a LINE count rather than a blocker count, or the unseen count is counting the boilerplate a plain resolution moves into the diff, which makes it useless for telling that resolution from one hiding a finding"
fi

v_vn="$(v_of V-N ship)"
case "$v_vn" in
  "1|UNDECIDED|"*) ok "V-N a NEW HARD row beside the resolved one is NOT read as the operator's own work — exit 1, cause UNDECIDED" ;;
  *) bad "V-N scored $v_vn (want 1|UNDECIDED|...) — a finding the approval never saw is being diagnosed as BLOCKERS-RESOLVED, which is the acquitting direction and the one this cause must never take" ;;
esac

v_vm="$(v_of V-M ship)"
case "$v_vm" in
  "1|UPSTREAM-MOVED|"*) ok "V-M upstream moving across a core change is decided BEFORE the resolved-blocker case — exit 1, cause UPSTREAM-MOVED" ;;
  *) bad "V-M scored $v_vm (want 1|UPSTREAM-MOVED|...) — a moved range makes every other line incomparable, so a region diffed against a different upstream must never be diagnosed from its HARD rows" ;;
esac

v_vb="$(v_of V-B ship)"
case "$v_vb" in
  "1|UNDECIDED|"*) ok "V-B a NON-HARD row that stopped rendering is not a resolved blocker — exit 1, cause UNDECIDED" ;;
  *) bad "V-B scored $v_vb (want 1|UNDECIDED|...) — the cause is keyed on 'something left the region' rather than on the HARD- prefix SKILL.md binds" ;;
esac

v_vh="$(v_of V-H ship)"
case "$v_vh" in
  "1|UNDECIDED|"*) ok "V-H a blocker HAND-DROPPED from the region still exits 1 with cause UNDECIDED — the unsafe direction cannot borrow the safe one's diagnosis" ;;
  *) bad "V-H scored $v_vh (want 1|UNDECIDED|...) — a region edited to hide a finding the detectors still render is being reported as the adjudication loop's own work" ;;
esac

v_vha="$(v_of V-HA ship)"
case "$v_vha" in
  "1|UNDECIDED|"*) ok "V-HA a blocker-adjudication file in the consumer does not turn a hand-dropped row into a resolved one — the cause is decided from the ROWS" ;;
  *) bad "V-HA scored $v_vha (want 1|UNDECIDED|...) — the diagnosis is reading a file the consumer can create rather than the two regions, so an operator writing an adjudication note acquits a dropped finding" ;;
esac

# THE STAMP IS ITS OWN CAUSE, and the arm reads all three of its outputs. Folded in with
# `_base_`/`_theirs_` it made a re-stamped consumer read as UPSTREAM-MOVED, whose two disjuncts
# are both false; dropped from the key entirely it made a post-apply re-run — stamp legitimately
# at theirs — read as blockers RESOLVED and be told to re-approve and apply a range already
# applied. So the verdict, the cause word, and the HARD counts the cause line carries beside the
# stamp are all in the cell, and the changed line must still reach the operator in the diff.
v_vs="$(v_of V-S ship)"
if [ "$v_vs" = "1|STAMP-MOVED|0|0|1|0" ] && grep -qE '^[<>] _stamp_ records ' "$VW/V-S/stderr.ship"; then
  ok "V-S a moved CONSUMER stamp is neither upstream moving nor a resolved blocker: it is decided on its own line, exit 1 with cause STAMP-MOVED, the blocker it also resolved is still counted beside it, and the changed line reaches the operator in the forwarded diff"
else
  bad "V-S scored $v_vs (want 1|STAMP-MOVED|0|0|1|0 with the _stamp_ line in the diff) — a stamp folded into the base/theirs key reads as UPSTREAM-MOVED with both disjuncts false, and a stamp left out of every key reads as BLOCKERS-RESOLVED on a post-apply re-run, which tells the operator to re-approve and apply a range this tree already carries"
fi

v_vu="$(v_of V-U ship)"
if [ "$v_vu" = "3|BLOCKERS-RESOLVED|1|1|1|1" ] && grep -q '^    unseen: OVERRIDE-ANCHOR-UNRESOLVED' "$VW/V-U/stderr.ship"; then
  ok "V-U a resolution that leaves a NON-HARD row the approval never saw still refuses, and the row is COUNTED and NAMED rather than asserted away — one, against V-R's zero on the same verdict"
else
  bad "V-U scored $v_vu (want 3|BLOCKERS-RESOLVED|1|1|1|1 with OVERRIDE-ANCHOR-UNRESOLVED listed as unseen) — the message tells the operator no finding is hidden from the approval while one is, and the count cannot tell a plain resolution from a resolution carrying a row"
fi

v_vd="$(v_of V-D ship)"
if [ "$v_vd" = "1|UNDECIDED|0|0|1|0" ] && grep -q '1 DETECTOR-REFUSED line(s)' "$VW/V-D/stderr.ship"; then
  ok "V-D a detector that REFUSED is not a blocker resolved: its rows are absent with nobody to vouch for them, so the cause stays UNDECIDED and the message counts the refusal"
else
  bad "V-D scored $v_vd (want 1|UNDECIDED|0|0|1|0 naming 1 DETECTOR-REFUSED line) — a dead detector is being diagnosed as the operator's own resolution, BY NAME, over a drift still on disk, and the remedy it offers is a re-render that would bake that absence into an approved report"
fi

v_vdr="$(v_of "$V_CONTROL_WORLD" ship)"
if [ "$v_vdr" = "$v_vd" ]; then
  ok "V-DR CONTROL the same dead-detector copy reaches the same verdict with the drift RESOLVED on disk — the refusal is what blocks the cause, not the state of the file, so V-D is not passing because of what its consumer happens to hold"
else
  bad "V-DR CONTROL the dead-detector verdict changed with the drift resolved (unresolved: $v_vd / resolved: $v_vdr) — V-D is being decided by its consumer's contents rather than by the refusal, so it does not test the DETECTOR-REFUSED conjunct"
fi

v_vhc="$(v_of V-HC ship)"
if [ "$v_vhc" = "1|UNDECIDED|0|0|0|0" ]; then
  ok "V-HC a blocker whose padded copy is missing from the report while its detector-section copy still renders is NOTHING gone and NOTHING new — normalised before the difference, the two sides carry the same row and both counts are zero"
else
  bad "V-HC scored $v_vhc (want 1|UNDECIDED|0|0|0|0) — the difference is being taken over RAW lines, so one blocker rendered twice with different padding is scored as a row that moved, and a still-rendered blocker cannot be told from a resolved one"
fi

v_vhb="$(v_of V-HB ship)"
if [ "$v_vhb" = "1|UNDECIDED|0|0|1|0" ] && grep -q '1 DETECTOR-REFUSED line(s)' "$VW/V-HB/stderr.ship"; then
  ok "V-HB the WRAPPER the HARD- contract keys on gets the same refusal treatment as the detectors it drives: an empty blocking list from a wrapper that did not run is not '0 HARD blockers.'"
else
  bad "V-HB scored $v_vhb (want 1|UNDECIDED|0|0|1|0 naming 1 DETECTOR-REFUSED line) — hard-blockers.sh exiting non-zero renders an empty blocking list that reads as a clean one, on the single line the whole HARD- contract is keyed to"
fi

# --- THE KILL SETS --------------------------------------------------------------------------
# v_kill <name> <expected-kill-set> <world:expected-score> ...
v_kill() {
  local n="$1" want="$2"; shift 2
  local got spec w exp act allok=1
  case " $V_APPLIED " in *" $n "*) : ;; *) return 1 ;; esac
  got="$(v_diffset ship "$n")"
  if [ "$got" != "$want" ]; then
    bad "$n moved the worlds [${got:-none}] and had to move exactly [$want] — a mutant that fails more than its own arms means two of them are entangled, and one that fails fewer means the arm it guards is carried by something else"
    allok=0
  fi
  for spec in "$@"; do
    w="${spec%%:*}"; exp="${spec#*:}"; act="$(v_of "$w" "$n")"
    if [ "$act" != "$exp" ]; then
      bad "$n on $w scored $act, not the specific wrong verdict $exp — the cell moved for some reason other than the one this mutation names, so the kill is unattributed"
      allok=0
    fi
  done
  [ "$allok" = 1 ]
}

if [ "$V_CTL" = "$V_SHIP" ] && [ "$(v_of V-R ctl)" = "3|BLOCKERS-RESOLVED|1|1|0|0" ]; then
  ok "CONTROL(V) an unmutated copy in a fresh directory reproduces every verdict INCLUDING the positive one (V-R exits 3 and names its row), so a mutant's changed cell is the mutation and not the copy — and the two were computed in different parallel slots, so it is also the arm that would catch the scoring racing with itself"
else
  bad "CONTROL(V) the unmutated copy did not reproduce the shipped verdicts — every mutant below is unreadable. shipped: $V_SHIP / copy: $V_CTL"
fi

# E1: the classification deleted — the program as it stood before this change, which reported the
# mismatch and exited 1 for every cause. Moves every world that reads 3 and nothing else.
v_kill E1 "V-R V-U" "V-R:1|BLOCKERS-RESOLVED|1|1|0|0" \
  && ok "E1 (exit 3 deleted): the three worlds that read 3 go red and no other — the resolved-blocker case falls back to the undifferentiated refusal and apply.sh cannot tell it from a hand-edit"

# E2: the refs comparison disarmed. A moved upstream must be decided FIRST, because it makes every
# other line incomparable. Now that `_stamp_` has left the comparison, V-M is the only world whose
# refs lines differ — which is what E6 exists to keep honest in the other direction.
v_kill E2 "V-M" \
  && ok "E2 (refs check disarmed): V-M alone goes red — a MOVED upstream is diagnosed from HARD rows that describe another tree"

# E3: the `hard_new` conjunct dropped — the count-based wrong fix, "resolved whenever HARD rows
# vanished". V-N is the only seed that carries the property it drops.
v_kill E3 "V-N" "V-N:3|BLOCKERS-RESOLVED|1|1|0|0" \
  && ok "E3 (hard_new conjunct dropped): V-N alone goes red — a blocker resolved beside a NEW one is acquitted as the operator's own work"

# E4: the HARD- keying dropped while the rest of the shape is kept — exit 3 whenever the region
# carries rows the render lacks. V-B is the only seed whose resolution is not a blocker.
v_kill E4 "V-B" \
  && ok "E4 (HARD- keying dropped): V-B alone goes red — a non-HARD row that stopped rendering is reported as a resolved blocker"

# E5: the cause decided from a FILE the consumer can create rather than from the two regions.
# Killed in BOTH directions deliberately: the worlds with no such file lose their diagnosis and
# V-HA, which has one, gains it. A one-directional arm cannot tell a correctly-keyed decision from
# one that reads the wrong input.
v_kill E5 "V-R V-HA V-U" "V-R:1|UNDECIDED|0|0|0|0" \
  && ok "E5 (cause read off a consumer file): BOTH directions go red — every world with no such file loses its diagnosis and the hand-dropped one that has a file gains it, which a single-direction arm could not separate"

# E6: the STAMP-MOVED branch removed, so the stamp falls through to the resolved cause. V-S is
# the only world whose stamp moved; V-M must stay put, or the mutant is moving the refs arm
# generally rather than the stamp branch that sits between the other two.
v_kill E6 "V-S" "V-S:3|BLOCKERS-RESOLVED|1|1|0|0" \
  && ok "E6 (the STAMP-MOVED branch removed): V-S alone goes red and V-M does not — a tree whose recorded position moved under the report is diagnosed as blockers the operator resolved, and the remedy offered is to re-approve and apply a range the stamp says is already applied"

# E7: the `refused_new` conjunct dropped. A detector that refused leaves exactly the row absence
# (c) keys on.
v_kill E7 "V-D" "V-D:3|BLOCKERS-RESOLVED|1|1|0|0" \
  && ok "E7 (DETECTOR-REFUSED conjunct dropped): V-D alone goes red — a refusing detector is reported as a blocker the operator resolved, by name, over a drift still on disk"

# E8: `unseen_rows()` reduced to "everything that is not HARD and not blank". The count is what
# separates a plain resolution from one carrying a row the approval never saw, and boilerplate is
# what destroys it: a resolution replaces a HARD row with `none` or `0 HARD blockers.`, so the
# plain case counts those and reads exactly like the carrying one.
v_kill E8 "V-R V-U" \
  && ok "E8 (unseen_rows reduced to non-HARD): the plain resolution's unseen count stops being zero — the count no longer separates a resolution that hid nothing from one that hid a finding, and the VERDICT does not move at all"

# E9/E10/E11: TWO GUARDS THAT COVER EACH OTHER, AND THE ARM THAT SAYS SO.
#
# MEASURED, not reasoned: with the normalisation in place a dead wrapper leaves the blocker's
# detector-section copy rendering, so nothing is gone and the refusal never has to block anything;
# with the refusal in place a raw difference is blocked before it can misread the padded copy.
# Each alone therefore changes NO verdict, which is the silent shape — zero failures rather than
# two — and each is given a subject the other cannot see: E9 makes V-HC count a HARD row as new
# when both sides carry it, E10 makes V-HB stop counting the refusal. E11 applies both and is the
# only one that reaches the defect itself, on V-HB: a wrapper that did not run, reported as a
# blocker the operator resolved, over a drift still on disk.
# E9's KILL SET IS SEVEN WORLDS AND THAT IS THE MUTATION'S REACH, NOT AN ENTANGLEMENT. The
# normalisation is a property of the COMPARISON, so removing it perturbs the counts of every world
# whose two sides differ by padding anywhere — measured, seven of eleven. What E9 OWNS is V-HC,
# the only world built so that a blocker's two copies differ by padding alone, and the arm asserts
# that cell exactly. The second conjunct is the load-bearing half: no VERDICT moves anywhere, so
# without the counts in the cell this mutant would come back green.
if v_kill E9 "V-R V-N V-H V-HA V-S V-U V-HC" "V-HC:1|UNDECIDED|0|1|0|0"; then
  case "$(v_of V-R E9)" in
    "3|BLOCKERS-RESOLVED|"*) ok "E9 (normalised AFTER the difference): V-HC counts a HARD row as new when both sides carry it, and no verdict moves anywhere — V-R still reads 3 — so the counts are the only record that the guard is gone" ;;
    *) bad "E9 flipped V-R's verdict as well as the counts ($(v_of V-R E9)) — the mutation is not confined to the counting and its attribution to V-HC is unearned" ;;
  esac
fi

v_kill E10 "V-HB" "V-HB:1|UNDECIDED|0|0|0|0" \
  && ok "E10 (the wrapper's REFUSED arm removed): V-HB alone goes red — the refusal stops being counted, and with the normalisation still in place the verdict does not move, so nothing but this cell records that the guard is gone"

# E11 reaches what neither alone can: V-HB's VERDICT, not its counts.
if v_kill E11 "V-R V-N V-H V-HA V-S V-U V-HC V-HB" "V-HB:3|BLOCKERS-RESOLVED|1|1|0|0" "V-HC:1|UNDECIDED|0|1|0|0"; then
  ok "E11 (both guards removed together): V-HB reads BLOCKERS-RESOLVED — a wrapper that did not run is named as the operator's own resolution over a drift still on disk, which is the defect the pair exists to prevent and which neither mutant alone can reach"
fi
echo
if [ "$fails" -eq 0 ]; then echo "reconcile-emit-report: PASS"; exit 0; fi
echo "reconcile-emit-report: $fails assertion(s) FAILED" >&2
exit 1
