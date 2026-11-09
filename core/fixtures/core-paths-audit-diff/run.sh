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
# three acquit a touch that is not the installed reconcile's content.
set -uo pipefail

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
M="$(mutate reconcile "s@'chore(ai-dlc-update):'\*) ;;@'zzz-not-a-real-subject:'*) ;;@")" || exit 2
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

echo
if [ "$fails" -eq 0 ]; then
  echo "core-paths-audit-diff: PASS"
  exit 0
fi
echo "core-paths-audit-diff: FAIL ($fails)" >&2
exit 1
