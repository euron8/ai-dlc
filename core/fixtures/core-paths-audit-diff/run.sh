#!/usr/bin/env bash
# core-paths-audit-diff/run.sh — prove the core-layer-immutability backstop can fail.
#
# WHY THIS EXISTS. Until this release the backstop was a PARAGRAPH: the gate check told an
# adjudicator to diff the sprint range, ask the resolver per path, and apply two carve-outs.
# Core's own CLAUDE.md says a prohibition with no mechanism is a suggestion, and this is the
# prohibition that keeps a consumer's core tree pullable at all — the guard denies the
# keystroke, and this is what is left when the write arrives by a shell redirect, a
# `git push --no-verify`, or a clone with no hook wired.
#
# WHAT THE MUTANTS DEFEND. Every one of the mode's four additions fails SILENTLY and in the
# passing direction:
#   - resolve the manifest from the working tree instead of <base-ref>, and a diff that
#     un-claims the file it edits classifies itself out of scope;
#   - drop the activation rule, and the answer for a tree the check does not cover becomes
#     "no core path touched" — the same words as a clean layered consumer;
#   - drop the reconcile exemption, and every pull FAILs, which is how a real check gets
#     switched off;
#   - return 0 from the FAIL arm, and the finding still prints while the caller reads success.
# None of the four changes the output on a clean range. The CONTENT arm (BL-939) adds four
# more (mutations 7-10): the arm removed, its stamp key dropped, its mode dropped, and the
# range left inside its eligible set -- the first FAILs every squash-merged pull, the other
# three acquit a touch that is not the installed reconcile's content. BL-945 adds seven
# (mutations 11-17): either cwd anchor removed (the activation ls-tree, the batched walk), the
# walk's -c dropped or swapped for -m, its --no-renames dropped, CHANGED's diff.relative=false
# dropped, and the working-tree manifest fallback read from the cwd. Case B (Assertion 20) is the
# walk's declared divergence from the per-path walk it replaced, and is stricter. Mutation 18
# drops the walk's --root, so under log.showRoot=false an unrelated-history root that adds a core
# path lists no file and the range PASSes (Assertion 23). BL-951 adds five (mutations 19-23):
# CHANGED's --no-renames dropped (a rename out of core PASSes), CHANGED's core.quotePath=false
# dropped (a non-ASCII core add is refused, not named), the walk's core.quotePath=false dropped
# (a non-ASCII core add joins to nothing and reads as reconcile-only), the fail-closed refusal
# of a still-quoted core path removed (it PASSes), and that refusal widened to every quoted line
# (a quoted CONSUMER path is refused). Assertions 24-31 are their arms and near-misses. Mutation
# 24 drops tree_keys' core.precomposeunicode=false, so an NFD core path reads ABSENT at both
# commits and is acquitted (Assertion 32). It is scored only where precomposition is in effect
# (seed.sh measures PRECOMPOSE: macOS, this box, the gate); elsewhere, e.g. Linux, the flag is
# inert and it prints SKIP with no kill -- do not widen it into a mutant that cannot fail there.
set -uo pipefail
# Git config pinned to its defaults for the seed and every arm: a user's core.quotePath or
# diff.renames would otherwise decide the BL-951 cells before the script under test does.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
echo "HERMETIC-CONSUMED core/scripts/core-paths.sh"

OUT="$WORK/out.txt"
ESC="$PROJ/docs/escalations/pending.md"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo; echo "core-paths-audit-diff: FIXTURE BROKEN" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# B_M<n>=1 only beside the unmutated arm's own ok: the mutant is scored only if its base arm passed.
B_M1=0; B_M2=0; B_M3=0; B_M4=0; B_M5=0; B_M6=0; B_M7=0; B_M8=0; B_M9=0; B_M10=0
B_M11=0; B_M12=0; B_M13=0; B_M14=0; B_M15=0; B_M16=0; B_M17=0; B_M18=0
B_M19=0; B_M20=0; B_M21=0; B_M22=0; B_M23=0; B_M24=0

# audit <script> <base> <head> — never through a pipe: RC must be the script's own.
audit() {
  local v="$1" b="$2" h="$3"
  ( cd "$PROJ" && bash "$v" --audit-diff "$b" "$h" ) >"$OUT" 2>&1
  RC=$?
}

# audit_at <script> <checkout> <base> <head> — the same, with the WORKING TREE parked on
# <checkout> for the duration. Base-ref resolution and working-tree resolution give the same
# answer unless the tree carries the diff under audit, which is the live gate's arrangement
# and the only one where the difference is observable.
audit_at() {
  local v="$1" c="$2" b="$3" h="$4"
  git -C "$PROJ" checkout -q "$c" >/dev/null 2>&1 || broken "could not park the working tree on $c"
  audit "$v" "$b" "$h"
  git -C "$PROJ" checkout -q "$BASE" >/dev/null 2>&1 || broken "could not restore the working tree to base"
}
says() { grep -qF "$1" "$OUT"; }

# audit_in <script> <dir under PROJ> <base> <head> — the same, run from a SUBDIRECTORY (BL-945).
audit_in() {
  local v="$1" d="$2" b="$3" h="$4"
  ( cd "$PROJ/$d" && bash "$v" --audit-diff "$b" "$h" ) >"$OUT" 2>&1
  RC=$?
}
# audit_rel <script> — DIRTY from docs/ with the repo's diff.relative=true, which makes a plain
# --name-only answer cwd-relative. The config is proved ACTIVE (a plain diff from docs/ names
# nothing) and proved REMOVED afterwards, so no later arm inherits it.
audit_rel() {
  git -C "$PROJ" config diff.relative true || broken "could not set diff.relative"
  [ -z "$( cd "$PROJ/docs" && git diff --name-only "$BASE...$DIRTY" 2>/dev/null)" ] || broken "diff.relative=true is not in effect from docs/"
  audit_in "$1" docs "$BASE" "$DIRTY"
  git -C "$PROJ" config --unset diff.relative || broken "could not unset diff.relative"
  git -C "$PROJ" config --get diff.relative >/dev/null 2>&1 && broken "diff.relative is still set after the arm"
  return 0
}
mkdir -p "$PROJ/docs" || broken "could not make the docs/ subdirectory"

# A mutant is a COPY with one sed, guarded by cmp -s so a pattern that matched nothing
# cannot pass as a mutation.
mutate() {  # mutate <name> <sed-expr>
  local name="$1" expr="$2"
  cp "$CONTROL_VALIDATOR" "$WORK/m-$name.sh" || broken "could not copy for mutant $name"
  sed -i.bak "$expr" "$WORK/m-$name.sh" && rm -f "$WORK/m-$name.sh.bak"
  if cmp -s "$CONTROL_VALIDATOR" "$WORK/m-$name.sh"; then
    broken "mutant $name changed no bytes — its sed matched nothing and it would score as a kill"
  fi
  bash -n "$WORK/m-$name.sh" || broken "mutant $name does not parse; its silence would score as a kill"
  echo "$WORK/m-$name.sh"
}

echo "core-paths-audit-diff:"

# --- Assertion 0: the UNMUTATED CONTROL COPY reproduces the whole baseline -----
# A lone copy that cannot run emits nothing, and nothing scores as a kill for every mutant at
# once. Refuse to believe any mutant until the control has produced all five verdicts.
audit "$CONTROL_VALIDATOR" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] && says "PASS: no core path touched" || broken "control: the clean range did not pass (rc=$RC)"
audit "$CONTROL_VALIDATOR" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || broken "control: an in-place core edit exited $RC, want 1 — every mutant below would inherit a broken baseline"
audit "$CONTROL_VALIDATOR" "$BASE" "$RECONCILE"
[ "$RC" -eq 0 ] || broken "control: a reconcile-authored core edit exited $RC, want 0"
audit "$CONTROL_VALIDATOR" "$PRESPLIT" "$BASE"
says "DORMANT" || broken "control: the pre-layer-split range did not report DORMANT"
audit_at "$CONTROL_VALIDATOR" shrink "$BASE" "$SHRINK"
says "scripts/ai-dlc/verdict.sh" || broken "control: the un-claiming range did not name the un-claimed path"
audit "$CONTROL_VALIDATOR" "$BASE" "$SQUASH"
[ "$RC" -eq 0 ] && says "PASS (content arm)" || broken "control: the squash of a reconcile's tree did not pass by the content arm (rc=$RC)"
ok "the unmutated control copy reproduces all six verdicts"

# --- Assertion 1: a consumer-only change is clean -----------------------------
audit "$VALIDATOR" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] && says "PASS: no core path touched" \
  && ok "a range touching only consumer-owned files passes" \
  || bad "a consumer-only range did not pass cleanly (rc=$RC)"

# --- Assertion 2: an in-place core edit FAILS, and the exit code says so -------
# The exit code alone, because the FAIL text is asserted by Assertion 6 against a different
# range — two assertions on one string is how a mutant kills two arms and one of them turns
# out to have been vacuous.
audit "$VALIDATOR" "$BASE" "$DIRTY"
if [ "$RC" -eq 1 ]; then ok "an in-place core edit by an ordinary commit exits 1"; B_M4=1
else bad "an in-place core edit exited $RC, want 1"; fi

# --- Assertion 3: a reconcile commit is the one legitimate author --------------
audit "$VALIDATOR" "$BASE" "$RECONCILE"
if [ "$RC" -eq 0 ] && says "every touching commit is an /ai-dlc-update reconcile"; then
  ok "the same edit authored by a chore(ai-dlc-update) commit passes"; B_M3=1
else bad "a reconcile-authored core edit did not pass by the reconcile arm (rc=$RC)"; fi

# --- Assertion 4: a real operator citation is an escape hatch, not an exemption --
# The arm delegates to validate-escalation-resolution.sh, which owns the escalations.md
# grammar, so what clears the range is a citation on an entry the OPERATOR dispositioned.
mkdir -p "$(dirname "$ESC")" || broken "could not stage the escalations dir"
cat > "$ESC" <<'RESOLVED_ESC'
## [S1] [Lead] - 2026-01-01T00:00:00Z — core edit needed outside the layer
**Status:** RESOLVED
**Operator authorization:** 2026-01-01T00:10:00Z | "edit the core file directly this once"
RESOLVED_ESC
audit "$VALIDATOR" "$BASE" "$DIRTY"
esc_rc="$RC"
[ "$esc_rc" -eq 0 ] && says "PASS (with citation)" && says "PRESENCE only" \
  && ok "a well-formed citation on an operator-resolved entry clears the range, and the output says it checked presence only" \
  || bad "the citation arm did not fire on a well-formed citation, or did not state what it does not verify (rc=$esc_rc)"

# --- Assertion 4a: the label alone is not a citation ---------------------------
# THIS IS THE SHIPPED DEFECT THIS RELEASE FIXES, kept as an assertion because the old arm
# passed it. `grep -q 'Operator authorization:'` over the whole file counts a bare line that
# belongs to no entry, has no timestamp and quotes no operator. On the reference consumer four
# of the eight lines satisfying that grep were of this kind, one of them a sentence saying that
# no citation exists or is required — the negation of the thing satisfying the check for it.
printf -- '- Operator authorization: S1 core touch, adjudicated.\n' > "$ESC"
audit "$VALIDATOR" "$BASE" "$DIRTY"
if [ "$RC" -eq 1 ]; then ok "a bare 'Operator authorization:' line belonging to no entry does NOT clear the range"; B_M5=1
else bad "a line carrying only the label cleared an in-place core edit (rc=$RC) — the escape hatch is a string search again"; fi

# --- Assertion 4b: the lead's own call is not the operator's -------------------
# Asserted on the STATUS, with the citation itself byte-identical to Assertion 4's, so this
# arm cannot be satisfied by whatever makes 4a pass. escalations.md: DECIDED_AUTONOMOUSLY is
# the honest label for a decision the lead made and needs no citation — so it grants none.
cat > "$ESC" <<'AUTONOMOUS_ESC'
## [S1] [Lead] - 2026-01-01T00:00:00Z — core edit needed outside the layer
**Status:** DECIDED_AUTONOMOUSLY
**Operator authorization:** 2026-01-01T00:10:00Z | "edit the core file directly this once"
AUTONOMOUS_ESC
audit "$VALIDATOR" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] \
  && ok "the same citation on a DECIDED_AUTONOMOUSLY entry does NOT clear the range" \
  || bad "a lead-authored disposition cleared an in-place core edit (rc=$RC) — the operator's escape hatch is available to the lead"

# --- Assertion 4c: the delegate is missing, so nothing is decided --------------
# Not 0 and not 1. "Cannot determine" is this resolver's 2 everywhere else, and a caller that
# reads an unanswerable question as a clean tree is the failure the whole mode exists against.
mv "$WORKDIR/validate-escalation-resolution.sh" "$WORKDIR/esr.parked" || broken "could not park the delegate"
audit "$CONTROL_VALIDATOR" "$BASE" "$DIRTY"
del_rc="$RC"
mv "$WORKDIR/esr.parked" "$WORKDIR/validate-escalation-resolution.sh" || broken "could not restore the delegate"
if [ "$del_rc" -eq 2 ]; then ok "with the delegate absent the mode exits 2 (cannot determine), never 0"; B_M6=1
else bad "the citation delegate was missing and the mode answered $del_rc — an undecidable question came back as a verdict"; fi
rm -f "$ESC"

# --- Assertion 5: a tree the check does not cover says so ----------------------
# Not "PASS". A pre-layer-split range and a distribution checkout both have zero paths that
# any consumer-relative glob can match, so a clean-looking pass there is the check-cannot-fire
# shape reported in the words of a check that ran.
audit "$VALIDATOR" "$PRESPLIT" "$BASE"
if says "DORMANT" && ! says "PASS: no core path touched"; then ok "a pre-layer-split range reports DORMANT, not a clean pass"; B_M2=1
else bad "a pre-layer-split range did not report DORMANT (rc=$RC)"; fi

# --- Assertion 6: the manifest is read at <base-ref>, not from the working tree -
# The range edits `scripts/ai-dlc/verdict.sh` AND deletes the manifest entry that claims it,
# in one commit. Classified against the base-ref manifest the file is still core; classified
# against the diff's own manifest it is not, and the diff has defined its own scope.
audit_at "$VALIDATOR" shrink "$BASE" "$SHRINK"
if says "scripts/ai-dlc/verdict.sh"; then ok "a diff that un-claims the file it edits is still classified against the base-ref manifest"; B_M1=1
else bad "the un-claimed path was not named — the manifest is being read from the diff under audit"; fi

# --- Assertions 7-14: the CONTENT arm (BL-939) -----------------------------------
# A squash-merged pull lands a reconcile's tree under a non-reconcile subject. seed.sh asserts
# each cell's discriminating input exists before any of these runs.
NOREF="no chore(ai-dlc-update): reconcile ref carrying the installed stamp was found"
# 7 (cell 1): the squash of X's tree passes, and BY THE CONTENT ARM, not the subject arm.
audit "$VALIDATOR" "$BASE" "$SQUASH"
if [ "$RC" -eq 0 ] && says "PASS (content arm)" && says "== reconcile $XREC" && ! says "every touching commit is an"; then
  ok "a squash-merged pull carrying the reconcile's exact tree passes by the content arm"; B_M7=1
else bad "a squash of the reconcile's own tree did not pass by the content arm (rc=$RC)"; fi
# 8 (cell 2): one byte off the reconcile flags, and R was NOT empty, so no pruned note.
audit "$VALIDATOR" "$BASE" "$BYTE"
[ "$RC" -eq 1 ] && says "scripts/ai-dlc/verdict.sh :: feat: ai-dlc update 0.2.0 (#102)" && ! says "$NOREF" \
  && ok "a squash whose core blob differs from the reconcile's by one byte flags, with no pruned-ref note" \
  || bad "a one-byte blob difference was acquitted or mis-reported (rc=$RC)"
# 9 (cell 4): the update ref deleted, so R is empty: flag, and SAY the refs are missing.
git -C "$PROJ" update-ref -d refs/heads/ai-dlc-update/x || broken "could not delete the side ref"
audit "$VALIDATOR" "$BASE" "$SQUASH"
git -C "$PROJ" update-ref refs/heads/ai-dlc-update/x "$XREC" || broken "could not restore the side ref"
[ "$RC" -eq 1 ] && says "$NOREF" \
  && ok "with the reconcile's update ref pruned the squash flags, and the FAIL names the missing ref" \
  || bad "a squash with its reconcile ref pruned did not flag with the pruned-ref note (rc=$RC)"
# 10 (cell 5): a mode-only chmod of a core path, bytes identical to the reconcile: flag.
audit "$VALIDATOR" "$BASE" "$CHMOD"
if [ "$RC" -eq 1 ] && says "scripts/ai-dlc/verdict.sh :: feat: ai-dlc update 0.2.0 (#103)"; then
  ok "a chmod-only change of a reconcile's blob flags: the mode is part of the content key"; B_M9=1
else bad "a mode-only change was acquitted by the content arm (rc=$RC)"; fi
# 11 (cell 6): an OLD reconcile's blob under the CURRENT stamp: flag.
audit "$VALIDATOR" "$BASE" "$OLDBLOB"
if [ "$RC" -eq 1 ] && says "scripts/ai-dlc/verdict.sh :: feat: ai-dlc update 0.2.0 (#104)"; then
  ok "an older reconcile's blob restored under the current stamp flags: the stamp keys the eligible set"; B_M8=1
else bad "an old reconcile blob under the current stamp was acquitted (rc=$RC)"; fi
# 12 (cell 7): the squash deletes a path the reconcile KEPT: flag.
audit "$VALIDATOR" "$BASE" "$DELKEEP"
[ "$RC" -eq 1 ] && says "scripts/ai-dlc/verdict.sh :: feat: ai-dlc update 0.4.0 (#106)" \
  && ok "a squash deleting a core path the reconcile kept flags" \
  || bad "a deletion the reconcile did not make was acquitted (rc=$RC)"
# 13 (cell 8): a deletion matching the reconcile's own deletion passes, with the edit beside it.
audit "$VALIDATOR" "$BASE" "$DELMATCH"
[ "$RC" -eq 0 ] && says "PASS (content arm)" && says "$DELMATCH $DELPATH == reconcile $YREC" \
  && ok "a squash deleting exactly what the reconcile deleted passes by the content arm" \
  || bad "a deletion matching the reconcile's own was not acquitted (rc=$RC)"
# 14: a reconcile INSIDE the range carries the hand-copy's stamp and blob, and acquits nothing.
audit "$VALIDATOR" "$BASE" "$INRANGE"
if [ "$RC" -eq 1 ] && says "verdict.sh :: feat: hand-copy the 0.3.0 verdict helper"; then
  ok "an in-range reconcile does not acquit the hand copy before it: R excludes <base>..<head>"; B_M10=1
else bad "an in-range reconcile acquitted a commit of its own range (rc=$RC)"; fi

# --- Assertions 15-21: BL-945, the cwd and the one batched walk -------------------
# 15: from docs/, the in-place edit still FAILs (Assertion 2 is the root control). Both the
# activation ls-tree and the walk run from the toplevel; either half un-anchored answered 0.
audit_in "$VALIDATOR" docs "$BASE" "$DIRTY"
if [ "$RC" -eq 1 ] && says "$DIRTY scripts/ai-dlc/verdict.sh :: fix(s1): tweak the verdict helper in place" && ! says "DORMANT"; then
  ok "from docs/ an in-place core edit exits 1, as it does from the project root"; B_M11=1
else bad "from docs/ an in-place core edit exited $RC, want 1 (the root run exits 1)"; fi
# 16: a clean range from docs/ gives its root verdict.
audit_in "$VALIDATOR" docs "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] && says "PASS: no core path touched" \
  && ok "from docs/ a consumer-only range passes, as it does from the root" \
  || bad "from docs/ a consumer-only range did not pass cleanly (rc=$RC)"
# 17: an EVIL merge (neither side touches the core path, the merge rewrites it) is an offender.
audit "$VALIDATOR" "$BASE" "$EVIL"
if [ "$RC" -eq 1 ] && says "$EVIL scripts/ai-dlc/verdict.sh :: Merge branch evil-side"; then
  ok "an evil merge that rewrites a core path neither side touched flags the merge"; B_M13=1
else bad "an evil merge's core rewrite was not flagged (rc=$RC)"; fi
# 18: a reconcile merged --no-ff passes by the SUBJECT arm: the merge equals its reconcile parent.
audit "$VALIDATOR" "$BASE" "$NOFF"
if [ "$RC" -eq 0 ] && says "every touching commit is an /ai-dlc-update reconcile"; then
  ok "a reconcile merged --no-ff under a PR subject passes by the reconcile arm"; B_M15=1
else bad "a --no-ff merge of a reconcile was flagged (rc=$RC)"; fi
# 19: a core path renamed out of core, then rewritten, flags the rename commit by the core name.
audit "$VALIDATOR" "$BASE" "$RENREW"
if [ "$RC" -eq 1 ] && says "$RENREW_T $DELPATH :: fix(s1): move the hook out of core"; then
  ok "a rename out of a core path, then a rewrite, flags the rename under the core path's name"; B_M14=1
else bad "a rename-then-rewrite out of core was not flagged by the core path (rc=$RC)"; fi
# 20: CASE B, the declared divergence. An identical edit on both sides: the per-path walk listed R
# only and PASSed; the batched walk lists the sprint commit X too, and FAILs naming it.
audit "$VALIDATOR" "$BASE" "$CASEB"
[ "$RC" -eq 1 ] && says "$CASEB_X scripts/ai-dlc/verdict.sh :: feat(s1): hand-apply the caseb helper" && ! says "$CASEB_R scripts/ai-dlc/verdict.sh" \
  && ok "case B: a sprint commit identical to a reconcile on the other side flags (stricter than the per-path walk)" \
  || bad "case B: the side-branch sprint commit was not flagged, or the reconcile was (rc=$RC)"
# 21: diff.relative=true from docs/. CHANGED and the walk both answer root-relative names.
audit_rel "$VALIDATOR"
if [ "$RC" -eq 1 ] && says "$DIRTY scripts/ai-dlc/verdict.sh"; then
  ok "with diff.relative=true, from docs/ an in-place core edit still exits 1"; B_M12=1; B_M16=1
else bad "with diff.relative=true from docs/ an in-place core edit exited $RC, want 1"; fi
# 22: no manifest at <base-ref>, so the WORKING-TREE fallback answers, read from the toplevel.
audit "$VALIDATOR" "$NOMAN" "$NOMAN_DIRTY"
noman_root="$RC"
audit_in "$VALIDATOR" docs "$NOMAN" "$NOMAN_DIRTY"
if [ "$noman_root" -eq 1 ] && [ "$RC" -eq 1 ] && says "classifying against the working-tree manifest"; then
  ok "with no manifest at the base ref, from docs/ the working-tree fallback gives the root verdict"; B_M17=1
else bad "the working-tree manifest fallback from docs/ exited $RC, root $noman_root (want 1 and 1)"; fi
# 23: an unrelated-history root adding a core path, under log.showRoot=false. The config is
# proved ACTIVE (a plain log of the root lists no file) and proved REMOVED afterwards.
audit_noroot() {
  git -C "$PROJ" config log.showRoot false || broken "could not set log.showRoot"
  [ -z "$(git -C "$PROJ" log -1 --format= --name-only "$UNREL_ROOT" 2>/dev/null)" ] || broken "log.showRoot=false is not in effect"
  audit "$1" "$BASE" "$UNREL"
  git -C "$PROJ" config --unset log.showRoot || broken "could not unset log.showRoot"
  git -C "$PROJ" config --get log.showRoot >/dev/null 2>&1 && broken "log.showRoot is still set after the arm"
  return 0
}
audit_noroot "$VALIDATOR"
if [ "$RC" -eq 1 ] && says "$UNREL_ROOT scripts/ai-dlc/new.sh :: feat: unrelated root"; then
  ok "with log.showRoot=false an unrelated root adding a core path flags the root commit"; B_M18=1
else bad "with log.showRoot=false the unrelated root was not flagged (rc=$RC)"; fi

# --- Assertions 24-31: BL-951, renames and quoted paths in CHANGED --------------------
# seed.sh asserts each cell's defect input is present at git's defaults. Non-ASCII names are
# spelled in octal so this file stays ASCII.
NA_P="$(printf 'scripts/ai-dlc/v\303\251rdict.sh')"
# 24: a rename out of core in one commit flags the rename by the OLD core path's name.
audit "$VALIDATOR" "$BASE" "$RENOUT"
if [ "$RC" -eq 1 ] && says "$RENOUT $DELPATH :: fix(s1): move the hook out of core"; then
  ok "a core path renamed out of core flags, named by its old core path"; B_M19=1
else bad "a rename out of core was not flagged by the old core path (rc=$RC)"; fi
# 25: the same rename to a non-ASCII non-core name.
audit "$VALIDATOR" "$BASE" "$RENOUTNA"
[ "$RC" -eq 1 ] && says "$RENOUTNA $DELPATH :: fix(s1): move the hook out to a non-ascii name" \
  && ok "a core path renamed out to a non-ASCII name flags, named by its old core path" \
  || bad "a rename out of core to a non-ASCII name was not flagged by the old core path (rc=$RC)"
# 26: a non-ASCII core add flags, named as raw bytes on its offender line (the walk's join).
audit "$VALIDATOR" "$BASE" "$NAADD"
if [ "$RC" -eq 1 ] && says "$NAADD $NA_P :: fix(s1): add a non-ascii core script" && ! says '"scripts/ai-dlc/v'; then
  ok "a non-ASCII core add flags, its offender line naming the raw-byte path"; B_M20=1; B_M21=1
else bad "a non-ASCII core add was not flagged with its raw-byte path and sha (rc=$RC)"; fi
# 27: the squash of a reconcile adding that path passes by the content arm.
audit "$VALIDATOR" "$BASE" "$NASQ"
[ "$RC" -eq 0 ] && says "PASS (content arm)" && says "$NASQ $NA_P == reconcile $NAREC" \
  && ok "a squash of a reconcile adding a non-ASCII core path passes by the content arm" \
  || bad "a squash of a non-ASCII reconcile was not acquitted by the content arm (rc=$RC)"
# 28: the same squash one byte off on that path flags.
audit "$VALIDATOR" "$BASE" "$NASQB"
[ "$RC" -eq 1 ] && says "$NASQB $NA_P :: feat: ai-dlc update 0.8.0 (#203)" \
  && ok "a squash one byte off a reconcile's non-ASCII core path flags" \
  || bad "a one-byte-off non-ASCII squash was acquitted or mis-reported (rc=$RC)"
# 29: a core-to-core rename flags under both names.
audit "$VALIDATOR" "$BASE" "$RR"
[ "$RC" -eq 1 ] && says "$RR scripts/ai-dlc/verdict.sh :: fix(s1): rename the verdict helper within core" \
  && says "$RR scripts/ai-dlc/verdict2.sh :: fix(s1): rename the verdict helper within core" \
  && ok "a core-to-core rename flags under both its old and its new name" \
  || bad "a core-to-core rename did not flag under both names (rc=$RC)"
# 30: a core path git still C-quotes is refused, exit 2, naming the quoted line, before any arm.
QREF="refused: git quoted a changed core path"
audit "$VALIDATOR" "$BASE" "$QQ"
if [ "$RC" -eq 2 ] && says "$QREF" && says '  "scripts/ai-dlc/q\"x.sh"' && ! says "PASS"; then
  ok "a changed core path carrying a double quote is refused with exit 2 and named"; B_M22=1
else bad "a C-quoted core path (double quote) was not refused with exit 2 (rc=$RC)"; fi
audit "$VALIDATOR" "$BASE" "$BS"
[ "$RC" -eq 2 ] && says "$QREF" && says '  "scripts/ai-dlc/b\\x.sh"' && ! says "PASS" \
  && ok "a changed core path carrying a backslash is refused with exit 2 and named" \
  || bad "a C-quoted core path (backslash) was not refused with exit 2 (rc=$RC)"
audit "$VALIDATOR" "$BASE" "$TB"
[ "$RC" -eq 2 ] && says "$QREF" && says '  "scripts/ai-dlc/t\tx.sh"' && ! says "PASS" \
  && ok "a changed core path carrying a tab is refused with exit 2 and named" \
  || bad "a C-quoted core path (tab) was not refused with exit 2 (rc=$RC)"
# 31: the near-miss. The same quoting bytes on consumer paths keep today's verdict.
audit "$VALIDATOR" "$BASE" "$QNEAR"
if [ "$RC" -eq 0 ] && says "PASS: no core path touched" && ! says "refused"; then
  ok "C-quoted consumer paths are not refused: the range passes as it did"; B_M23=1
else bad "C-quoted consumer paths changed the verdict (rc=$RC)"; fi
# 32: an NFD-spelled core path added beside a reconcile's tree flags on every platform: tree_keys
# reads it back, so it is not ABSENT at both commits and the deletion acquittal does not fire.
NFD_P="$(printf 'scripts/ai-dlc/ve\314\201rdict9.sh')"
audit "$VALIDATOR" "$BASE" "$NFDADD"
if [ "$RC" -eq 1 ] && says "$NFDADD $NFD_P :: feat: add an nfd-named core script" && ! says "PASS (content arm)"; then
  ok "an NFD-spelled core path beside a reconcile's tree flags (precomposition in effect: $PRECOMPOSE)"; B_M24=1
else bad "an NFD-spelled core path was acquitted or mis-reported (rc=$RC, precomposition in effect: $PRECOMPOSE)"; fi

# --- Mutation 1: resolve the manifest from the working tree --------------------
M="$(mutate base-manifest 's@git show "${BASE_REF}:${c}"@git show "${BASE_REF}:no-such-prefix/${c}"@')" || exit 2
audit_at "$M" shrink "$BASE" "$SHRINK"
if says "scripts/ai-dlc/verdict.sh"; then bad "MUTATION 1 SURVIVED: the un-claimed path is still named with base-ref resolution broken"
else mutant_killed "$B_M1" "mutation 1" "mutation 1 killed: without the base-ref manifest, the un-claiming diff classifies itself out of scope"; fi
audit "$M" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || bad "MUTATION 1 ENTANGLED: it also changed the verdict on an ordinary in-place core edit"

# --- Mutation 2: drop the activation rule -------------------------------------
M="$(mutate dormancy 's@^  if \[ -n "\$dormant_why" \]; then@  if [ -n "" ]; then@')" || exit 2
audit "$M" "$PRESPLIT" "$BASE"
if says "DORMANT"; then bad "MUTATION 2 SURVIVED: DORMANT still reported with the activation rule removed"
else mutant_killed "$B_M2" "mutation 2" "mutation 2 killed: without the activation rule an uncovered tree answers in the words of a covered one"; fi
audit "$M" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] || bad "MUTATION 2 ENTANGLED: it also changed the verdict on a clean layered range"

# --- Mutation 3: drop the reconcile exemption ---------------------------------
M="$(mutate reconcile 's@rec = (index(subj, "chore(ai-dlc-update):") == 1)@rec = (index(subj, "zzz-not-a-real-subject:") == 1)@')" || exit 2
audit "$M" "$BASE" "$RECONCILE"
if [ "$RC" -eq 0 ]; then bad "MUTATION 3 SURVIVED: a pull still passes with the reconcile subject no longer recognized"
else mutant_killed "$B_M3" "mutation 3" "mutation 3 killed: without the exemption every /ai-dlc-update pull FAILs its own consumer"; fi
audit "$M" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] || bad "MUTATION 3 ENTANGLED: it also changed the verdict on a clean layered range"

# --- Mutation 4: the FAIL arm returns success ---------------------------------
M="$(mutate fail-exit 's@^  printf .%s. "\$OFFENDERS"$@  printf "%s" "$OFFENDERS"; exit 0@')" || exit 2
audit "$M" "$BASE" "$DIRTY"
if [ "$RC" -eq 1 ]; then bad "MUTATION 4 SURVIVED: the FAIL arm still exits 1 with its exit replaced"
else mutant_killed "$B_M4" "mutation 4" "mutation 4 killed: a finding that prints while the caller reads success is the whole failure class"; fi
audit "$M" "$BASE" "$RECONCILE"
[ "$RC" -eq 0 ] || bad "MUTATION 4 ENTANGLED: it also changed the verdict on a reconcile-authored edit"

# --- Mutation 5: the citation arm goes back to searching for the label ---------
# The shipped defect, restored. Asserted on the BARE-LABEL range, because a well-formed
# citation clears the range under both the mutant and the fix — a mutant that changes no
# answer on the input an assertion uses is a mutant that assertion cannot see.
printf -- '- Operator authorization: S1 core touch, adjudicated.\n' > "$ESC"
M="$(mutate citation-grep 's@^  if AUTH_OUT=.*--any-authorized.*then$@  if AUTH_OUT="" \&\& grep -q "Operator authorization:" "$ESC"; then@')" || exit 2
audit "$M" "$BASE" "$DIRTY"
if [ "$RC" -eq 0 ]; then mutant_killed "$B_M5" "mutation 5" "mutation 5 killed: with the delegation replaced by a whole-file search, a bare label clears an in-place core edit again"
else bad "MUTATION 5 SURVIVED: the label-only line still failed the range with the arm reverted to a string search (rc=$RC)"; fi
rm -f "$ESC"
audit "$M" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] || bad "MUTATION 5 ENTANGLED: it also changed the verdict on a clean layered range"

# --- Mutation 6: the missing-delegate guard never fires ------------------------
# Asserted on the EXIT CODE against a parked delegate, and the guard is disabled by its
# CONDITION rather than by its exit, so this mutant and mutation 5 cannot both be satisfied by
# one change to the arm.
M="$(mutate delegate-guard 's@^  if \[ ! -f "\$ESC_DIR/validate-escalation-resolution.sh" \]; then@  if [ -f "/no-such-path-ever" ]; then@')" || exit 2
cat > "$ESC" <<'RESOLVED_ESC2'
## [S1] [Lead] - 2026-01-01T00:00:00Z — core edit needed outside the layer
**Status:** RESOLVED
**Operator authorization:** 2026-01-01T00:10:00Z | "edit the core file directly this once"
RESOLVED_ESC2
mv "$WORKDIR/validate-escalation-resolution.sh" "$WORKDIR/esr.parked" || broken "could not park the delegate for mutation 6"
audit "$M" "$BASE" "$DIRTY"
mut6_rc="$RC"
mv "$WORKDIR/esr.parked" "$WORKDIR/validate-escalation-resolution.sh" || broken "could not restore the delegate after mutation 6"
if [ "$mut6_rc" -ne 2 ]; then mutant_killed "$B_M6" "mutation 6" "mutation 6 killed: without the guard, an absent delegate stops answering 'cannot determine' and returns a verdict instead"
else bad "MUTATION 6 SURVIVED: the mode still exited 2 with its missing-delegate guard disabled"; fi
audit "$M" "$BASE" "$DIRTY"
[ "$RC" -eq 0 ] || bad "MUTATION 6 ENTANGLED: with the delegate present it also changed the verdict on a cited range (rc=$RC)"
rm -f "$ESC"

# --- Mutations 7-10: the CONTENT arm's four properties ---------------------------
# Each anchor is unique in the control copy (mutate() refuses a no-op), and each is scored on
# the one cell whose discriminating input that property alone decides, with an entanglement
# twin on a cell the property does not decide.
# 7: the content arm removed. The squash of the reconcile's own tree FAILs again.
M="$(mutate content-arm 's@^  \[ -z "\$OFFENDERS" \] || content_arm$@  [ -z "$OFFENDERS" ] || :@')" || exit 2
audit "$M" "$BASE" "$SQUASH"
if [ "$RC" -eq 0 ]; then bad "MUTATION 7 SURVIVED: a squash still passed with the content arm removed"
else mutant_killed "$B_M7" "mutation 7" "mutation 7 killed: without the content arm every squash-merged pull FAILs its own consumer"; fi
audit "$M" "$BASE" "$RECONCILE"
[ "$RC" -eq 0 ] || bad "MUTATION 7 ENTANGLED: it also changed the subject arm's verdict on a reconcile commit"
# 8: the stamp key dropped. Every reconcile is eligible, so an old one's blob acquits.
M="$(mutate stamp-key 's@\$1 == "R" \&\& \$3 == ts {@$1 == "R" {@')" || exit 2
audit "$M" "$BASE" "$OLDBLOB"
if [ "$RC" -eq 1 ]; then bad "MUTATION 8 SURVIVED: an old reconcile blob under the current stamp still flagged with the stamp key dropped"
else mutant_killed "$B_M8" "mutation 8" "mutation 8 killed: without the stamp key an older reconcile's blob acquits a revert under the current stamp"; fi
audit "$M" "$BASE" "$BYTE"
[ "$RC" -eq 1 ] || bad "MUTATION 8 ENTANGLED: it also acquitted a blob no reconcile carries"
# 9: the mode dropped from the content key. A chmod-only change acquits.
M="$(mutate content-mode 's@print \$2 "\\t" a\[1\] " " a\[3\]@print $2 "\\t" a[3]@')" || exit 2
audit "$M" "$BASE" "$CHMOD"
if [ "$RC" -eq 1 ]; then bad "MUTATION 9 SURVIVED: a chmod-only change still flagged with the mode dropped"
else mutant_killed "$B_M9" "mutation 9" "mutation 9 killed: without the mode in the key a chmod of a core file passes as the reconcile's content"; fi
audit "$M" "$BASE" "$SQUASH"
[ "$RC" -eq 0 ] || bad "MUTATION 9 ENTANGLED: it also changed the verdict on the squash of the reconcile's own tree"
# 10: R includes the range. An in-range reconcile acquits the hand copy before it.
M="$(mutate content-range 's@^    inrange="\$(git rev-list "\${BASE_REF}\.\.\${HEAD_REF}" 2>/dev/null)"$@    inrange=""@')" || exit 2
audit "$M" "$BASE" "$INRANGE"
if [ "$RC" -eq 1 ]; then bad "MUTATION 10 SURVIVED: the hand copy still flagged with R including the range"
else mutant_killed "$B_M10" "mutation 10" "mutation 10 killed: with the range left in R a reconcile acquits the commits of its own range"; fi
audit "$M" "$BASE" "$BYTE"
[ "$RC" -eq 1 ] || bad "MUTATION 10 ENTANGLED: it also acquitted a blob no reconcile carries"

# --- Mutations 11-17: BL-945 ---------------------------------------------------------
# 11: the activation ls-tree un-anchored. From docs/ the layer dir matches nothing: DORMANT.
M="$(mutate anchor-lstree 's@git -C "\$AUDIT_ROOT" ls-tree -d@git ls-tree -d@')" || exit 2
audit_in "$M" docs "$BASE" "$DIRTY"
if [ "$RC" -eq 1 ]; then bad "MUTATION 11 SURVIVED: from docs/ the in-place edit still exits 1 with the ls-tree un-anchored"
else mutant_killed "$B_M11" "mutation 11" "mutation 11 killed: an un-anchored activation probe reads a layered consumer as DORMANT from a subdirectory"; fi
audit "$M" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || bad "MUTATION 11 ENTANGLED: it also changed the root verdict on an in-place core edit"
# 12: the walk un-anchored. It has no pathspec, so only diff.relative=true can move it: from
# docs/ it names nothing outside docs/, and the range reads as reconcile-only.
M="$(mutate anchor-walk 's@ -C "\$AUDIT_ROOT" log -c --no-renames@ log -c --no-renames@')" || exit 2
audit_rel "$M"
if [ "$RC" -eq 1 ]; then bad "MUTATION 12 SURVIVED: with diff.relative=true from docs/ the edit still exits 1 with the walk un-anchored"
elif says "every touching commit is an /ai-dlc-update reconcile"; then mutant_killed "$B_M12" "mutation 12" "mutation 12 killed: an un-anchored walk under diff.relative=true joins nothing and PASSes an in-place core edit"
else bad "MUTATION 12 SURVIVED its own arm: wrong failure: no reconcile-arm PASS (rc=$RC)"; fi
audit "$M" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || bad "MUTATION 12 ENTANGLED: it also changed the root verdict on an in-place core edit"
# 13: -c dropped. A merge then lists no paths, so the evil merge's core rewrite goes unlisted.
M="$(mutate walk-c 's@ log -c --no-renames @ log --no-renames @')" || exit 2
audit "$M" "$BASE" "$EVIL"
if [ "$RC" -eq 1 ]; then bad "MUTATION 13 SURVIVED: the evil merge still flags with -c dropped"
else mutant_killed "$B_M13" "mutation 13" "mutation 13 killed: without -c an evil merge's core rewrite is never listed"; fi
audit "$M" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || bad "MUTATION 13 ENTANGLED: it also changed the verdict on an ordinary in-place core edit"
# 14: --no-renames dropped. The rename commit is listed only under its new, non-core name.
M="$(mutate walk-renames 's@ log -c --no-renames @ log -c @')" || exit 2
audit "$M" "$BASE" "$RENREW"
if [ "$RC" -eq 1 ]; then bad "MUTATION 14 SURVIVED: the rename out of core still flags with renames on"
else mutant_killed "$B_M14" "mutation 14" "mutation 14 killed: with renames on a rename out of a core path joins to nothing"; fi
audit "$M" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || bad "MUTATION 14 ENTANGLED: it also changed the verdict on an ordinary in-place core edit"
# 15: -m for -c. The --no-ff merge is listed against its first parent and FAILs the pull.
M="$(mutate walk-m 's@ log -c --no-renames @ log -m --no-renames @')" || exit 2
audit "$M" "$BASE" "$NOFF"
if [ "$RC" -eq 0 ]; then bad "MUTATION 15 SURVIVED: the --no-ff reconcile merge still passes with -m"
else mutant_killed "$B_M15" "mutation 15" "mutation 15 killed: with -m a --no-ff merge of a reconcile is a false FAIL"; fi
audit "$M" "$BASE" "$RECONCILE"
[ "$RC" -eq 0 ] || bad "MUTATION 15 ENTANGLED: it also changed the verdict on a linear reconcile"
# 16: diff.relative=false dropped. From docs/ CHANGED is empty and the range reads N/A.
M="$(mutate diff-relative 's@git -c diff.relative=false -c core.quotePath=false diff@git -c core.quotePath=false diff@')" || exit 2
audit_rel "$M"
if [ "$RC" -eq 1 ]; then bad "MUTATION 16 SURVIVED: with diff.relative=true from docs/ the edit still exits 1 without diff.relative=false"
elif says "N/A: no diff in range"; then mutant_killed "$B_M16" "mutation 16" "mutation 16 killed: without diff.relative=false a subdirectory sees no diff and reads N/A"
else bad "MUTATION 16 SURVIVED its own arm: wrong failure: no N/A line (rc=$RC)"; fi
audit_in "$M" docs "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || bad "MUTATION 16 ENTANGLED: it also changed the docs/ verdict with diff.relative unset"
# 17: the working-tree fallback read from the cwd. From docs/ no candidate exists: exit 2.
M="$(mutate wt-fallback 's@^WT_PFX="\${AUDIT_ROOT:+\${AUDIT_ROOT}/}"$@WT_PFX=""@')" || exit 2
audit_in "$M" docs "$NOMAN" "$NOMAN_DIRTY"
if [ "$RC" -eq 1 ]; then bad "MUTATION 17 SURVIVED: from docs/ the working-tree fallback still answers with the cwd prefix"
else mutant_killed "$B_M17" "mutation 17" "mutation 17 killed: a cwd-relative working-tree fallback finds no manifest from a subdirectory"; fi
audit "$M" "$NOMAN" "$NOMAN_DIRTY"
[ "$RC" -eq 1 ] || bad "MUTATION 17 ENTANGLED: it also changed the root verdict with no base-ref manifest"
# 18: --root dropped. Under log.showRoot=false the root lists no file and the range PASSes.
M="$(mutate walk-root 's@ --no-renames --root @ --no-renames @')" || exit 2
audit_noroot "$M"
if [ "$RC" -eq 1 ]; then bad "MUTATION 18 SURVIVED: the unrelated root still flags under log.showRoot=false with --root dropped"
elif says "every touching commit is an /ai-dlc-update reconcile"; then mutant_killed "$B_M18" "mutation 18" "mutation 18 scored: without --root an unrelated root's core add lists no file under log.showRoot=false and PASSes"
else bad "MUTATION 18 SURVIVED its own arm: wrong failure: no reconcile-arm PASS (rc=$RC)"; fi
audit "$M" "$BASE" "$UNREL"
[ "$RC" -eq 1 ] || bad "MUTATION 18 ENTANGLED: it also changed the verdict on the unrelated root with log.showRoot unset"

# --- Mutations 19-23: BL-951 ---------------------------------------------------------
# 19: CHANGED's --no-renames dropped. A rename out of core lists only the new name: PASS.
M="$(mutate changed-renames 's@ diff --no-renames --name-only@ diff --name-only@')" || exit 2
audit "$M" "$BASE" "$RENOUT"
if [ "$RC" -eq 1 ]; then bad "MUTATION 19 SURVIVED: the rename out of core still flags with CHANGED's renames on"
elif says "PASS: no core path touched"; then mutant_killed "$B_M19" "mutation 19" "mutation 19 killed: with renames on in CHANGED a core path renamed out of core is never classified"
else bad "MUTATION 19 SURVIVED its own arm: wrong failure: no clean PASS line (rc=$RC)"; fi
audit "$M" "$BASE" "$NAADD"
[ "$RC" -eq 1 ] || bad "MUTATION 19 ENTANGLED: it also changed the verdict on a non-ASCII core add"
# 20: CHANGED's core.quotePath=false dropped. The non-ASCII core add is C-quoted: refused, not named.
M="$(mutate changed-quotepath 's@-c core.quotePath=false diff --no-renames@diff --no-renames@')" || exit 2
audit "$M" "$BASE" "$NAADD"
if [ "$RC" -eq 1 ]; then bad "MUTATION 20 SURVIVED: the non-ASCII core add still flags with CHANGED quoting it"
elif says "$QREF"; then mutant_killed "$B_M20" "mutation 20" "mutation 20 killed: with CHANGED quoting a non-ASCII core path it is refused instead of classified"
else bad "MUTATION 20 SURVIVED its own arm: wrong failure: no refusal line (rc=$RC)"; fi
audit "$M" "$BASE" "$RENOUT"
[ "$RC" -eq 1 ] || bad "MUTATION 20 ENTANGLED: it also changed the verdict on an ASCII rename out of core"
# 21: the walk's core.quotePath=false dropped. Its key is quoted, the join is empty: reconcile PASS.
M="$(mutate walk-quotepath 's@git -c core.quotePath=false -C "\$AUDIT_ROOT" log@git -C "$AUDIT_ROOT" log@')" || exit 2
audit "$M" "$BASE" "$NAADD"
if [ "$RC" -eq 1 ]; then bad "MUTATION 21 SURVIVED: the non-ASCII core add still flags with the walk quoting it"
elif says "every touching commit is an /ai-dlc-update reconcile"; then mutant_killed "$B_M21" "mutation 21" "mutation 21 killed: a walk quoting a non-ASCII path joins nothing and PASSes the core add as reconcile-only"
else bad "MUTATION 21 SURVIVED its own arm: wrong failure: no reconcile-arm PASS (rc=$RC)"; fi
audit "$M" "$BASE" "$RENOUT"
[ "$RC" -eq 1 ] || bad "MUTATION 21 ENTANGLED: it also changed the verdict on an ASCII rename out of core"
# 22: the fail-closed refusal removed. The still-quoted core path matches no glob: PASS.
M="$(mutate quoted-refusal 's@^  if \[ -n "\$QUOTED" \]; then$@  if [ -n "" ]; then@')" || exit 2
audit "$M" "$BASE" "$QQ"
if [ "$RC" -eq 2 ]; then bad "MUTATION 22 SURVIVED: the double-quoted core path is still refused with the refusal removed"
elif says "PASS: no core path touched"; then mutant_killed "$B_M22" "mutation 22" "mutation 22 killed: without the refusal a core path git still quotes PASSes as untouched"
else bad "MUTATION 22 SURVIVED its own arm: wrong failure: no clean PASS line (rc=$RC)"; fi
audit "$M" "$BASE" "$QNEAR"
[ "$RC" -eq 0 ] || bad "MUTATION 22 ENTANGLED: it also changed the verdict on quoted consumer paths"
# 23: the refusal widened to every quoted line, core or not. The consumer near-miss is refused.
M="$(mutate quoted-any 's@^        \$g) if \[ -n "\$QREL" \]; then@        $g|${QREL:+*}) if [ -n "$QREL" ]; then@')" || exit 2
audit "$M" "$BASE" "$QNEAR"
if [ "$RC" -eq 0 ]; then bad "MUTATION 23 SURVIVED: quoted consumer paths still pass with the refusal widened to every quoted line"
elif says "$QREF"; then mutant_killed "$B_M23" "mutation 23" "mutation 23 killed: a refusal ignoring the core globs refuses a consumer range git merely quotes"
else bad "MUTATION 23 SURVIVED its own arm: wrong failure: no refusal line (rc=$RC)"; fi
audit "$M" "$BASE" "$QQ"
[ "$RC" -eq 2 ] || bad "MUTATION 23 ENTANGLED: it also changed the verdict on a quoted core path"
# 24: tree_keys' core.precomposeunicode=false dropped. Where git precomposes a command-line
# pathspec (seed.sh measured PRECOMPOSE), the NFD path lists nothing and is acquitted. Where it
# does not, the setting is inert, the mutant has no observable, and it is not scored: the same
# two runs are made (so invocations.decl holds on both platforms) and must give the tip's verdict.
M="$(mutate tree-keys-precompose 's@git -c core.precomposeunicode=false -c core.quotePath=false ls-tree@git -c core.quotePath=false ls-tree@')" || exit 2
audit "$M" "$BASE" "$NFDADD"
if [ "$PRECOMPOSE" = 1 ]; then
  if [ "$RC" -eq 1 ]; then bad "MUTATION 24 SURVIVED: the NFD core path still flags with precomposition left on"
  elif says "PASS (content arm)"; then mutant_killed "$B_M24" "mutation 24" "mutation 24 killed: with precomposition on an NFD core path reads ABSENT at both commits and is acquitted"
  else bad "MUTATION 24 SURVIVED its own arm: wrong failure: no content-arm PASS (rc=$RC)"; fi
else
  [ "$RC" -eq 1 ] || bad "mutation 24 is not inert on a git that does not precompose: the NFD path gave rc=$RC, want the tip's 1"
  echo "  SKIP  mutation 24 not scored: this git does not precompose a command-line pathspec, so the pin is inert here"
fi
audit "$M" "$BASE" "$NASQB"
[ "$RC" -eq 1 ] || bad "MUTATION 24 ENTANGLED: it also changed the verdict on a one-byte-off NFC squash"

echo
if [ "$fails" -eq 0 ]; then
  echo "core-paths-audit-diff: PASS"
  exit 0
fi
echo "core-paths-audit-diff: FAIL ($fails)" >&2
exit 1
