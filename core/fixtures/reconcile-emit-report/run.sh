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

echo
if [ "$fails" -eq 0 ]; then echo "reconcile-emit-report: PASS"; exit 0; fi
echo "reconcile-emit-report: $fails assertion(s) FAILED" >&2
exit 1
