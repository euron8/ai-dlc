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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo; echo "core-paths-audit-diff: FIXTURE BROKEN" >&2; exit 2; }

# IN PROCESS (BL-878). core-paths.sh is asked through cp_f, which hands the file (the subject, or the control copy in
# the world) to lib/inproc.sh's inproc_run: the file is sourced inside inproc_run's own fresh-bash subshell and cpth_main
# is called there, logged under INPROC_LOADED, so the copy's pass is a pass of the subject it copies. THE OPERAND IS A
# LITERAL TAIL, "${_f%/*}/core-paths.sh": the wrapper refuses (125) a file whose basename is not the subject's, so the
# tail can never substitute a sibling. The program runs as a program only in the cells of cells.decl.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present subject with neither the `<p>_main() {` line nor the column-0
# source guard predates the wrap, and sourcing it would run its whole body: SKIP and exit 0 on a consumer (FIXTURE
# BROKEN in the distribution). Exactly one half is a respelled subject this fixture cannot drive, which FAILS. An
# unreadable subject is FIXTURE ERROR.
cp_halves() { # cp_halves <file> <entry> -> "<def><guard>" (1 present, 0 absent); exit 2 on an unreadable file
  local d=0 g=0 x
  grep -qxF "$2() {" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
_cp_h="$(cp_halves "$VALIDATOR" cpth_main)" || exit 2
case "$_cp_h" in
  11) : ;;
  00) echo "SKIP: core-paths-audit-diff: $VALIDATOR predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) bad "$VALIDATOR carries one half of the in-process wrap (cpth_main line, column-0 source guard: $_cp_h) -- a respelled subject this fixture cannot drive"
     report_end core-paths-audit-diff ;;
esac
cp_f() { # cp_f <dir> <file> [args...] -> cpth_main's stdout, stderr and exit from <dir>, logged as a pass of $VALIDATOR
  local _d="$1" _f="$2"; shift 2
  case "$_f" in */core-paths.sh) ;; *) echo "FIXTURE BROKEN: cp_f was handed $_f, not a core-paths.sh" >&2; return 125 ;; esac
  ( cd "$_d" || exit 99; [ "$_f" = "$VALIDATOR" ] || INPROC_LOADED="$VALIDATOR"; inproc_run "${_f%/*}/core-paths.sh" cpth_main "$@" )
}

# audit <script> <base> <head> — never through a pipe: RC must be the script's own.
audit() {
  local v="$1" b="$2" h="$3"
  cp_f "$PROJ" "$v" --audit-diff "$b" "$h" >"$OUT" 2>&1
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
  cp_f "$PROJ/$d" "$v" --audit-diff "$b" "$h" >"$OUT" 2>&1
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

echo "core-paths-audit-diff:"

# --- Assertion 0: the copy beside the delegate reproduces the whole baseline ---
# Assertion 4c parks that copy's delegate and reads exit 2; a copy that cannot run at all would also
# exit 2, so the copy must first produce every baseline verdict.
audit "$CONTROL_VALIDATOR" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] && says "PASS: no core path touched" || broken "control: the clean range did not pass (rc=$RC)"
audit "$CONTROL_VALIDATOR" "$BASE" "$DIRTY"
[ "$RC" -eq 1 ] || broken "control: an in-place core edit exited $RC, want 1 — the delegate arm below would inherit a broken baseline"
audit "$CONTROL_VALIDATOR" "$BASE" "$RECONCILE"
[ "$RC" -eq 0 ] || broken "control: a reconcile-authored core edit exited $RC, want 0"
audit "$CONTROL_VALIDATOR" "$PRESPLIT" "$BASE"
says "DORMANT" || broken "control: the pre-layer-split range did not report DORMANT"
audit_at "$CONTROL_VALIDATOR" shrink "$BASE" "$SHRINK"
says "scripts/ai-dlc/verdict.sh" || broken "control: the un-claiming range did not name the un-claimed path"
audit "$CONTROL_VALIDATOR" "$BASE" "$SQUASH"
[ "$RC" -eq 0 ] && says "PASS (content arm)" || broken "control: the squash of a reconcile's tree did not pass by the content arm (rc=$RC)"
ok "the control copy reproduces all six verdicts"

# --- Equivalence cells: one program run per distinct CLI outcome ---------------
# Each is started as FXCELL=<id> bash from the project root and compared byte for byte (stdout, stderr, exit) with the
# in-process answer on the same input. cells.decl names them. Every other arm asks the function.
EQ="$WORK/eq"; mkdir -p "$EQ" || broken "could not make the equivalence dir"
eqv() { # eqv <cell-id> <base> <head> -> 0 when the in-process answer and the program's agree on stdout, stderr and exit
  local id="$1" b="$2" h="$3"
  cp_f "$PROJ" "$VALIDATOR" --audit-diff "$b" "$h" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ( cd "$PROJ" && FXCELL="$id" bash "$VALIDATOR" --audit-diff "$b" "$h" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
if eqv cli-core-pass "$BASE" "$CLEAN" && [ "$(cat "$EQ/cli-core-pass.cl.rc")" = 0 ] && grep -qF "PASS: no core path touched" "$EQ/cli-core-pass.cl.out"; then
  ok "cli-core-pass: the program passes a consumer-only range, exit 0, exactly as the in-process call does"
else bad "cli-core-pass: the program and the in-process call differ, or the outcome is not a clean pass (rc $(cat "$EQ/cli-core-pass.cl.rc"))"; fi
if eqv cli-core-fail "$BASE" "$DIRTY" && [ "$(cat "$EQ/cli-core-fail.cl.rc")" = 1 ] && grep -qF "FAIL: core path(s) edited in place" "$EQ/cli-core-fail.cl.out"; then
  ok "cli-core-fail: the program flags an in-place core edit, exit 1, exactly as the in-process call does"
else bad "cli-core-fail: the program and the in-process call differ, or the outcome is not exit 1 with the FAIL text (rc $(cat "$EQ/cli-core-fail.cl.rc"))"; fi
if eqv cli-core-refuse "$BASE" "$QQ" && [ "$(cat "$EQ/cli-core-refuse.cl.rc")" = 2 ] && grep -qF "refused: git quoted a changed core path" "$EQ/cli-core-refuse.cl.out"; then
  ok "cli-core-refuse: the program refuses a C-quoted core path, exit 2, exactly as the in-process call does"
else bad "cli-core-refuse: the program and the in-process call differ, or the outcome is not exit 2 with the refusal (rc $(cat "$EQ/cli-core-refuse.cl.rc"))"; fi

# --- Assertion 1: a consumer-only change is clean -----------------------------
audit "$VALIDATOR" "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] && says "PASS: no core path touched" \
  && ok "a range touching only consumer-owned files passes" \
  || bad "a consumer-only range did not pass cleanly (rc=$RC)"

# --- Assertion 2: an in-place core edit FAILS, and the exit code says so -------
# The exit code alone, because the FAIL text is asserted by Assertion 6 against a different
# range — two assertions on one string is how one change satisfies two arms and one of them turns
# out to have been vacuous.
audit "$VALIDATOR" "$BASE" "$DIRTY"
if [ "$RC" -eq 1 ]; then ok "an in-place core edit by an ordinary commit exits 1"
else bad "an in-place core edit exited $RC, want 1"; fi

# --- Assertion 3: a reconcile commit is the one legitimate author --------------
audit "$VALIDATOR" "$BASE" "$RECONCILE"
if [ "$RC" -eq 0 ] && says "every touching commit is an /ai-dlc-update reconcile"; then
  ok "the same edit authored by a chore(ai-dlc-update) commit passes"
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
if [ "$RC" -eq 1 ]; then ok "a bare 'Operator authorization:' line belonging to no entry does NOT clear the range"
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
if [ "$del_rc" -eq 2 ]; then ok "with the delegate absent the mode exits 2 (cannot determine), never 0"
else bad "the citation delegate was missing and the mode answered $del_rc — an undecidable question came back as a verdict"; fi
rm -f "$ESC"

# --- Assertion 5: a tree the check does not cover says so ----------------------
# Not "PASS". A pre-layer-split range and a distribution checkout both have zero paths that
# any consumer-relative glob can match, so a clean-looking pass there is the check-cannot-fire
# shape reported in the words of a check that ran.
audit "$VALIDATOR" "$PRESPLIT" "$BASE"
if says "DORMANT" && ! says "PASS: no core path touched"; then ok "a pre-layer-split range reports DORMANT, not a clean pass"
else bad "a pre-layer-split range did not report DORMANT (rc=$RC)"; fi

# --- Assertion 6: the manifest is read at <base-ref>, not from the working tree -
# The range edits `scripts/ai-dlc/verdict.sh` AND deletes the manifest entry that claims it,
# in one commit. Classified against the base-ref manifest the file is still core; classified
# against the diff's own manifest it is not, and the diff has defined its own scope.
audit_at "$VALIDATOR" shrink "$BASE" "$SHRINK"
if says "scripts/ai-dlc/verdict.sh"; then ok "a diff that un-claims the file it edits is still classified against the base-ref manifest"
else bad "the un-claimed path was not named — the manifest is being read from the diff under audit"; fi

# --- Assertions 7-14: the CONTENT arm (BL-939) -----------------------------------
# A squash-merged pull lands a reconcile's tree under a non-reconcile subject. seed.sh asserts
# each cell's discriminating input exists before any of these runs.
NOREF="no chore(ai-dlc-update): reconcile ref carrying the installed stamp was found"
# 7 (cell 1): the squash of X's tree passes, and BY THE CONTENT ARM, not the subject arm.
audit "$VALIDATOR" "$BASE" "$SQUASH"
if [ "$RC" -eq 0 ] && says "PASS (content arm)" && says "== reconcile $XREC" && ! says "every touching commit is an"; then
  ok "a squash-merged pull carrying the reconcile's exact tree passes by the content arm"
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
  ok "a chmod-only change of a reconcile's blob flags: the mode is part of the content key"
else bad "a mode-only change was acquitted by the content arm (rc=$RC)"; fi
# 11 (cell 6): an OLD reconcile's blob under the CURRENT stamp: flag.
audit "$VALIDATOR" "$BASE" "$OLDBLOB"
if [ "$RC" -eq 1 ] && says "scripts/ai-dlc/verdict.sh :: feat: ai-dlc update 0.2.0 (#104)"; then
  ok "an older reconcile's blob restored under the current stamp flags: the stamp keys the eligible set"
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
  ok "an in-range reconcile does not acquit the hand copy before it: R excludes <base>..<head>"
else bad "an in-range reconcile acquitted a commit of its own range (rc=$RC)"; fi

# --- Assertions 15-21: BL-945, the cwd and the one batched walk -------------------
# 15: from docs/, the in-place edit still FAILs (Assertion 2 is the root control). Both the
# activation ls-tree and the walk run from the toplevel; either half un-anchored answered 0.
audit_in "$VALIDATOR" docs "$BASE" "$DIRTY"
if [ "$RC" -eq 1 ] && says "$DIRTY scripts/ai-dlc/verdict.sh :: fix(s1): tweak the verdict helper in place" && ! says "DORMANT"; then
  ok "from docs/ an in-place core edit exits 1, as it does from the project root"
else bad "from docs/ an in-place core edit exited $RC, want 1 (the root run exits 1)"; fi
# 16: a clean range from docs/ gives its root verdict.
audit_in "$VALIDATOR" docs "$BASE" "$CLEAN"
[ "$RC" -eq 0 ] && says "PASS: no core path touched" \
  && ok "from docs/ a consumer-only range passes, as it does from the root" \
  || bad "from docs/ a consumer-only range did not pass cleanly (rc=$RC)"
# 17: an EVIL merge (neither side touches the core path, the merge rewrites it) is an offender.
audit "$VALIDATOR" "$BASE" "$EVIL"
if [ "$RC" -eq 1 ] && says "$EVIL scripts/ai-dlc/verdict.sh :: Merge branch evil-side"; then
  ok "an evil merge that rewrites a core path neither side touched flags the merge"
else bad "an evil merge's core rewrite was not flagged (rc=$RC)"; fi
# 18: a reconcile merged --no-ff passes by the SUBJECT arm: the merge equals its reconcile parent.
audit "$VALIDATOR" "$BASE" "$NOFF"
if [ "$RC" -eq 0 ] && says "every touching commit is an /ai-dlc-update reconcile"; then
  ok "a reconcile merged --no-ff under a PR subject passes by the reconcile arm"
else bad "a --no-ff merge of a reconcile was flagged (rc=$RC)"; fi
# 19: a core path renamed out of core, then rewritten, flags the rename commit by the core name.
audit "$VALIDATOR" "$BASE" "$RENREW"
if [ "$RC" -eq 1 ] && says "$RENREW_T $DELPATH :: fix(s1): move the hook out of core"; then
  ok "a rename out of a core path, then a rewrite, flags the rename under the core path's name"
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
  ok "with diff.relative=true, from docs/ an in-place core edit still exits 1"
else bad "with diff.relative=true from docs/ an in-place core edit exited $RC, want 1"; fi
# 22: no manifest at <base-ref>, so the WORKING-TREE fallback answers, read from the toplevel.
audit "$VALIDATOR" "$NOMAN" "$NOMAN_DIRTY"
noman_root="$RC"
audit_in "$VALIDATOR" docs "$NOMAN" "$NOMAN_DIRTY"
if [ "$noman_root" -eq 1 ] && [ "$RC" -eq 1 ] && says "classifying against the working-tree manifest"; then
  ok "with no manifest at the base ref, from docs/ the working-tree fallback gives the root verdict"
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
  ok "with log.showRoot=false an unrelated root adding a core path flags the root commit"
else bad "with log.showRoot=false the unrelated root was not flagged (rc=$RC)"; fi

# --- Assertions 24-31: BL-951, renames and quoted paths in CHANGED --------------------
# seed.sh asserts each cell's defect input is present at git's defaults. Non-ASCII names are
# spelled in octal so this file stays ASCII.
NA_P="$(printf 'scripts/ai-dlc/v\303\251rdict.sh')"
# 24: a rename out of core in one commit flags the rename by the OLD core path's name.
audit "$VALIDATOR" "$BASE" "$RENOUT"
if [ "$RC" -eq 1 ] && says "$RENOUT $DELPATH :: fix(s1): move the hook out of core"; then
  ok "a core path renamed out of core flags, named by its old core path"
else bad "a rename out of core was not flagged by the old core path (rc=$RC)"; fi
# 25: the same rename to a non-ASCII non-core name.
audit "$VALIDATOR" "$BASE" "$RENOUTNA"
[ "$RC" -eq 1 ] && says "$RENOUTNA $DELPATH :: fix(s1): move the hook out to a non-ascii name" \
  && ok "a core path renamed out to a non-ASCII name flags, named by its old core path" \
  || bad "a rename out of core to a non-ASCII name was not flagged by the old core path (rc=$RC)"
# 26: a non-ASCII core add flags, named as raw bytes on its offender line (the walk's join).
audit "$VALIDATOR" "$BASE" "$NAADD"
if [ "$RC" -eq 1 ] && says "$NAADD $NA_P :: fix(s1): add a non-ascii core script" && ! says '"scripts/ai-dlc/v'; then
  ok "a non-ASCII core add flags, its offender line naming the raw-byte path"
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
  ok "a changed core path carrying a double quote is refused with exit 2 and named"
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
  ok "C-quoted consumer paths are not refused: the range passes as it did"
else bad "C-quoted consumer paths changed the verdict (rc=$RC)"; fi
# 32: an NFD-spelled core path added beside a reconcile's tree flags on every platform: tree_keys
# reads it back, so it is not ABSENT at both commits and the deletion acquittal does not fire.
NFD_P="$(printf 'scripts/ai-dlc/ve\314\201rdict9.sh')"
audit "$VALIDATOR" "$BASE" "$NFDADD"
if [ "$RC" -eq 1 ] && says "$NFDADD $NFD_P :: feat: add an nfd-named core script" && ! says "PASS (content arm)"; then
  ok "an NFD-spelled core path beside a reconcile's tree flags (precomposition in effect: $PRECOMPOSE)"
else bad "an NFD-spelled core path was acquitted or mis-reported (rc=$RC, precomposition in effect: $PRECOMPOSE)"; fi
echo
report_end core-paths-audit-diff
