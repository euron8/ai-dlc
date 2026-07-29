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
# None of the four changes the output on a clean range.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

OUT="$WORK/out.txt"
ESC="$PROJ/docs/escalations/pending.md"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo; echo "core-paths-audit-diff: FIXTURE BROKEN" >&2; exit 2; }

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
ok "the unmutated control copy reproduces all five verdicts"

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
[ "$RC" -eq 1 ] && ok "an in-place core edit by an ordinary commit exits 1" \
  || bad "an in-place core edit exited $RC, want 1"

# --- Assertion 3: a reconcile commit is the one legitimate author --------------
audit "$VALIDATOR" "$BASE" "$RECONCILE"
[ "$RC" -eq 0 ] && says "every touching commit is an /ai-dlc-update reconcile" \
  && ok "the same edit authored by a chore(ai-dlc-update) commit passes" \
  || bad "a reconcile-authored core edit did not pass by the reconcile arm (rc=$RC)"

# --- Assertion 4: the operator's citation is an escape hatch, not an exemption --
mkdir -p "$(dirname "$ESC")" || broken "could not stage the escalations dir"
printf -- '- Operator authorization: S1 core touch, adjudicated.\n' > "$ESC"
audit "$VALIDATOR" "$BASE" "$DIRTY"
esc_rc="$RC"
rm -f "$ESC"
[ "$esc_rc" -eq 0 ] && says "PASS (with citation)" && says "detects PRESENCE only" \
  && ok "an Operator authorization citation clears the range, and the output says it checked presence only" \
  || bad "the citation arm did not fire, or did not state what it does not verify (rc=$esc_rc)"

# --- Assertion 5: a tree the check does not cover says so ----------------------
# Not "PASS". A pre-layer-split range and a distribution checkout both have zero paths that
# any consumer-relative glob can match, so a clean-looking pass there is the check-cannot-fire
# shape reported in the words of a check that ran.
audit "$VALIDATOR" "$PRESPLIT" "$BASE"
says "DORMANT" && ! says "PASS: no core path touched" \
  && ok "a pre-layer-split range reports DORMANT, not a clean pass" \
  || bad "a pre-layer-split range did not report DORMANT (rc=$RC)"

# --- Assertion 6: the manifest is read at <base-ref>, not from the working tree -
# The range edits `scripts/ai-dlc/verdict.sh` AND deletes the manifest entry that claims it,
# in one commit. Classified against the base-ref manifest the file is still core; classified
# against the diff's own manifest it is not, and the diff has defined its own scope.
audit_at "$VALIDATOR" shrink "$BASE" "$SHRINK"
says "scripts/ai-dlc/verdict.sh" \
  && ok "a diff that un-claims the file it edits is still classified against the base-ref manifest" \
  || bad "the un-claimed path was not named — the manifest is being read from the diff under audit"

# --- Mutation 1: resolve the manifest from the working tree --------------------
M="$(mutate base-manifest 's@git show "${BASE_REF}:${c}"@git show "${BASE_REF}:no-such-prefix/${c}"@')" || exit 2
audit_at "$M" shrink "$BASE" "$SHRINK"
says "scripts/ai-dlc/verdict.sh" \
  && bad "MUTATION 1 SURVIVED: the un-claimed path is still named with base-ref resolution broken" \
  || ok "mutation 1 killed: without the base-ref manifest, the un-claiming diff classifies itself out of scope"
audit "$M" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || bad "MUTATION 1 ENTANGLED: it also changed the verdict on an ordinary in-place core edit"

# --- Mutation 2: drop the activation rule -------------------------------------
M="$(mutate dormancy 's@^  if \[ -n "\$dormant_why" \]; then@  if [ -n "" ]; then@')" || exit 2
audit "$M" "$PRESPLIT" "$BASE"
says "DORMANT" \
  && bad "MUTATION 2 SURVIVED: DORMANT still reported with the activation rule removed" \
  || ok "mutation 2 killed: without the activation rule an uncovered tree answers in the words of a covered one"
audit "$M" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] || bad "MUTATION 2 ENTANGLED: it also changed the verdict on a clean layered range"

# --- Mutation 3: drop the reconcile exemption ---------------------------------
M="$(mutate reconcile "s@'chore(ai-dlc-update):'\*) ;;@'zzz-not-a-real-subject:'*) ;;@")" || exit 2
audit "$M" "$BASE" "$RECONCILE"
[ "$RC" -eq 0 ] \
  && bad "MUTATION 3 SURVIVED: a pull still passes with the reconcile subject no longer recognized" \
  || ok "mutation 3 killed: without the exemption every /ai-dlc-update pull FAILs its own consumer"
audit "$M" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] || bad "MUTATION 3 ENTANGLED: it also changed the verdict on a clean layered range"

# --- Mutation 4: the FAIL arm returns success ---------------------------------
M="$(mutate fail-exit 's@^  printf .%s. "\$OFFENDERS"$@  printf "%s" "$OFFENDERS"; exit 0@')" || exit 2
audit "$M" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] \
  && bad "MUTATION 4 SURVIVED: the FAIL arm still exits 1 with its exit replaced" \
  || ok "mutation 4 killed: a finding that prints while the caller reads success is the whole failure class"
audit "$M" "$BASE" "$RECONCILE"
[ "$RC" -eq 0 ] || bad "MUTATION 4 ENTANGLED: it also changed the verdict on a reconcile-authored edit"

echo
if [ "$fails" -eq 0 ]; then
  echo "core-paths-audit-diff: PASS"
  exit 0
fi
echo "core-paths-audit-diff: FAIL ($fails)" >&2
exit 1
