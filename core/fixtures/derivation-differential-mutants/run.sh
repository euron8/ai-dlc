#!/usr/bin/env bash
# derivation-differential-mutants -- the mutation battery behind
# core/fixtures/derivation-differential. DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh
# Exit:  0 every mutant applied and was killed by exactly its declared arms,
#        1 a mutant survived, did not apply, or moved an arm it does not own,
#        2 the harness could not run, so no verdict is readable.
#
# WHAT IT PROVES. Each mutant removes ONE behaviour of reconcile/derivation-differential.sh from a
# COPY of the whole reconcile directory, because the helper lifts vd_join() out of apply.sh and
# map_consumer() out of preclassify.sh beside itself; a lone copy would refuse at the lift and
# every mutant would "die" of that instead. The sibling fixture is then driven against the copy,
# and the set of arms that FAIL must EQUAL the set the mutant declares. A mutant that fails
# nothing SURVIVED; one that fails an arm it does not own means two arms are entangled.
#
# EVERY MUTATION IS ANCHORED ON A LOCATION AND A BEHAVIOUR, and each anchor is asserted UNIQUE in
# the pristine helper before it is used, against an impossible-anchor control that must count 0.
#
# THE CONTROL IS THE UNMUTATED COPY, driven through the same copied directory, and it carries a
# POSITIVE conjunct: exit 0 is not enough, the run must print `all assertions hold` and the A1b
# row. A copy that died at startup prints neither.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

# ROOT BY WALKING UP FOR `scripts/install.sh`, not VERSION: VERSION sits in suite-content-key.sh's
# EXCLUDE set, so a fixture reading it has an input the suite skip cannot see (I55).
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/install.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/install.sh" ] \
  || { echo "FIXTURE ERROR: no scripts/install.sh above $HERE -- cannot resolve the distribution root" >&2; exit 2; }
RECON="$ROOT/core/skills/ai-dlc-update/reconcile"
SUBJ="$RECON/derivation-differential.sh"
DRIVER="$ROOT/core/fixtures/derivation-differential/run.sh"
[ -f "$SUBJ" ]   || { echo "FIXTURE ERROR: $SUBJ not found -- this battery is distribution-only" >&2; exit 2; }
[ -f "$DRIVER" ] || { echo "FIXTURE ERROR: $DRIVER not found" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

echo "derivation-differential-mutants:"
printf '  subject: %s\n' "$SUBJ"
printf '  driver:  %s\n' "$DRIVER"

# copy_recon <label> -> path of a fresh copy of the WHOLE reconcile directory
copy_recon() {
  local d="$WORK/$1"
  mkdir -p "$d"
  cp -R "$RECON/." "$d/" 2>/dev/null || return 1
  printf '%s' "$d"
}

# anchor_count <fixed-string> -> occurrences in the pristine helper (0 prints 0)
anchor_count() { awk -v a="$1" 'index($0, a) { n++ } END { print n + 0 }' "$SUBJ"; }

# The anchor counter must be able to return 0, or "unique" below means nothing.
if [ "$(anchor_count 'ZQXJ-no-such-anchor-in-this-helper')" = 0 ] && [ "$(anchor_count 'set -uo pipefail')" = 1 ]; then
  ok "anchor control: an impossible anchor counts 0 and a known line counts 1"
else
  bad "anchor control: the counter cannot tell 0 from 1 -- every uniqueness claim below is unreadable"
  exit 2
fi

# failed_arms <log> -> sorted arm ids (A1a, A3b, ...) the driver reported FAIL on
failed_arms() { sed -n 's/^  FAIL  \(A[0-9]*[a-z]\) .*/\1/p' "$1" | sort -u; }

# ---- the unmutated control --------------------------------------------------------------
C="$(copy_recon control)" || { echo "FIXTURE ERROR: could not copy $RECON" >&2; exit 2; }
for s in apply.sh preclassify.sh derivation-differential.sh; do
  [ -f "$C/$s" ] || { echo "FIXTURE ERROR: the copied reconcile directory lacks $s" >&2; exit 2; }
done
bash "$DRIVER" "$C/derivation-differential.sh" > "$WORK/control.log" 2>&1; crc=$?
if [ "$crc" -eq 0 ] && grep -q '^  all assertions hold$' "$WORK/control.log" \
   && grep -q '^  ok    A1b ' "$WORK/control.log" \
   && grep -qF "subject: $C/derivation-differential.sh" "$WORK/control.log"; then
  ok "control: the unmutated copy passes every arm, the A1b row is present, and the driver resolved the COPY"
else
  bad "control: the unmutated copy did not pass cleanly (exit $crc) -- no mutant verdict below is readable"
  sed 's/^/        | /' "$WORK/control.log" | head -40
  exit 2
fi

# mutate <label> <declared arms, space-separated> <anchor> <sed script>
mutate() {
  local label="$1" declared="$2" anchor="$3" script="$4" d n
  n="$(anchor_count "$anchor")"
  if [ "$n" != 1 ]; then
    bad "$label: DID NOT APPLY -- its anchor occurs $n time(s) in the helper, expected exactly 1: $anchor"
    return
  fi
  d="$(copy_recon "$label")" || { bad "$label: could not copy the reconcile directory"; return; }
  if ! sed "$script" "$SUBJ" > "$d/derivation-differential.sh.mut" 2>"$WORK/$label.sed.err"; then
    bad "$label: DID NOT APPLY -- sed failed: $(head -2 "$WORK/$label.sed.err" | tr '\n' ' ')"
    return
  fi
  if cmp -s "$SUBJ" "$d/derivation-differential.sh.mut"; then
    bad "$label: DID NOT APPLY -- the sed matched nothing, the copy is byte-identical"
    return
  fi
  mv "$d/derivation-differential.sh.mut" "$d/derivation-differential.sh"
  ok "$label: applied ($(diff "$SUBJ" "$d/derivation-differential.sh" | grep -c '^[<>]') changed line(s))"
  bash "$DRIVER" "$d/derivation-differential.sh" > "$WORK/$label.log" 2>&1
  local rc=$?
  if ! grep -qF "subject: $d/derivation-differential.sh" "$WORK/$label.log"; then
    bad "$label: the driver did not resolve the mutated copy -- its verdict is about another file"
    return
  fi
  failed_arms "$WORK/$label.log" > "$WORK/$label.moved"
  printf '%s\n' $declared | sort -u > "$WORK/$label.declared"
  if [ "$rc" -eq 0 ] || [ ! -s "$WORK/$label.moved" ]; then
    bad "$label: SURVIVED -- the driver exited $rc with no arm failing"
    return
  fi
  if [ "$rc" -ne 1 ]; then
    bad "$label: the driver exited $rc, not 1 -- the harness broke rather than an arm"
    return
  fi
  local missed
  missed="$(comm -13 "$WORK/$label.moved" "$WORK/$label.declared" | tr '\n' ' ')"
  if [ -z "$missed" ]; then
    ok "$label: KILLED -- its owning arm(s) $(tr '\n' ' ' < "$WORK/$label.declared")all fail (full failed set: $(tr '\n' ' ' < "$WORK/$label.moved"))"
  else
    bad "$label: killed, but NOT by the arm(s) that own this behaviour: ${missed}stayed green
        failed: $(tr '\n' ' ' < "$WORK/$label.moved")"
  fi
}

# ---- R1: the base side is ignored ------------------------------------------------------------
# Location: the classifier's per-side FAIL recorder. Behaviour: the base side's failures are never
# recorded, so every derivation reads PASS at base. The already-stale derivation then reads as
# broken by this pull, in both the offender world and the clean pair.
mutate R1-ignore-base-side \
  "A2a A2b A3a A3c" \
  'if (brc == 1) B[k] = v' \
  's/if (brc == 1) B\[k\] = v/if (0) B[k] = v/'

# ---- R2: the stamp-equality refusal is restored ---------------------------------------------
# Location: immediately after the stamps INFO row. Behaviour: refuse when the two roots carry the
# same stamp commit -- which at hand-back they always do, so the helper refuses the one moment it
# exists for.
mutate R2-stamp-equality-refusal \
  "A1a A3a A8n" \
  'Information only -- at hand-back both read <base>."' \
  '/Information only -- at hand-back both read <base>\."$/a\
[ "$(stamp_commit < "$BR/.claude/.ai-dlc-version" 2>/dev/null)" != "$(stamp_commit < "$CONSUMER/.claude/.ai-dlc-version" 2>/dev/null)" ] || refuse stamps "both roots carry the same stamp commit, so the apply has not been run."
'

# ---- R3: the sides are swapped -------------------------------------------------------------
# Location: the stream-to-side binding the classifier reads by FILENAME. Behaviour: the base run's
# failures are scored as the consumer's and vice versa, so a derivation this pull broke reads as
# one it repaired.
mutate R3-side-swap \
  "A1a A1b A5o" \
  '-v fB="$TMP/b.err" -v fT="$TMP/t.err"' \
  's|-v fB="$TMP/b.err" -v fT="$TMP/t.err"|-v fB="$TMP/t.err" -v fT="$TMP/b.err"|'

# ---- R4: the broken-root refusal is dropped ------------------------------------------------
# Location: the zero-pass-at-base guard after classification. Behaviour: a base root on which
# nothing reproduces is compared anyway, every derivation reads stale at base, and the run clears.
mutate R4-drop-broken-root-refusal \
  "A9a A9b" \
  '[ "$N_BP" -gt 0 ] || [ "$N_TP" -eq 0 ] \' \
  's/^\[ "\$N_BP" -gt 0 \] || \[ "\$N_TP" -eq 0 \] \\$/true || [ "$N_TP" -eq 0 ] \\/'

# ---- R5: the self-update skip is dropped -----------------------------------------------------
# Location: the default walk's per-commit accept test. Behaviour: a commit is accepted on its
# `commit:` alone, so the self-update commit (commit: <base>, skill_commit: theirs) is taken as the
# base root. It already carries the range's machinery, a derivation this range broke reads
# STALE-BOTH, and the run clears.
mutate R5-drop-self-update-skip \
  "A11a A11b A11c A11d A11e A11o A13n A13o A15a A15b" \
  'if resolves_to_base "$_sc" && skill_commit_ok "$_st"; then' \
  's/if resolves_to_base "\$_sc" && skill_commit_ok "\$_st"; then/if resolves_to_base "$_sc"; then/'

# ---- R6: the walk's skill_commit: test reverts to EQUALITY -------------------------------------
# Location: the default walk's per-commit accept test. Behaviour: the pre-fix rule -- skill_commit:
# absent-or-EMPTY, or resolving to <base>. A pre-pull commit whose skill_commit: is legitimately
# behind <base> is rejected and the walk refuses (A13), and a self-update commit that wrote an
# EMPTY value is taken as the base root (A15).
mutate R6-skill-commit-equality \
  "A13a A13b A13c A15a A15b" \
  'if resolves_to_base "$_sc" && skill_commit_ok "$_st"; then' \
  's/if resolves_to_base "\$_sc" && skill_commit_ok "\$_st"; then/if resolves_to_base "$_sc" \&\& { _sk="$(stamp_skill_commit <<<"$_st")"; [ -z "$_sk" ] || resolves_to_base "$_sk"; }; then/'

# ---- R7: --base-root is checked on commit: alone ---------------------------------------------
# Location: the --base-root branch, the guard after the commit: check. Behaviour: a checkout of the
# self-update commit passes, and a derivation this range broke reads STALE-BOTH.
mutate R7-base-root-skips-skill-commit \
  "A14a A14b A14c" \
  '  skill_commit_ok "$_bst" \' \
  's/^  skill_commit_ok "\$_bst" \\$/  true \\/'

# ---- R8: the walk takes the OLDEST matching commit -------------------------------------------
# Location: the default walk's accept test. Behaviour: the walk keeps going after a match, so the
# last (oldest) accepted commit wins. A consumer commit above the pull that edits an operand is
# then outside the base root, and a derivation written against it reads STALE-BOTH.
mutate R8-oldest-matching-commit \
  "A16a A16b A16c A16d A16o" \
  'if resolves_to_base "$_sc" && skill_commit_ok "$_st"; then BASE_COMMIT="$_c"; break; fi' \
  's/skill_commit_ok "\$_st"; then BASE_COMMIT="\$_c"; break; fi/skill_commit_ok "$_st"; then BASE_COMMIT="$_c"; continue; fi/'

# ---- R9: the leak NOTE stops asking whether the run is dead -----------------------------------
# Location: the leaked-worktree loop. Behaviour: any other run's worktree carrying a PID is named,
# including a CONCURRENT live run's, with a removal remedy that would pull its tree out from under it.
# A12e reddens too: the PID-1 worktree is a live run as well, owned by another uid.
mutate R9-drop-pid-liveness \
  "A12l A12e" \
  'ps -p "$_pid" >/dev/null 2>&1 && continue' \
  's/ps -p "\$_pid" >\/dev\/null 2>&1 \&\& continue/:/'

# ---- R10: liveness asked with `kill -0`, the EPERM-blind test ----------------------------------
# Location: the leaked-worktree loop. Behaviour: a live process owned by another uid fails `kill -0`
# with EPERM and reads as dead, so a concurrent run by a different user is named for removal.
mutate R10-kill-0-liveness \
  "A12e" \
  'ps -p "$_pid" >/dev/null 2>&1 && continue' \
  's/ps -p "\$_pid" >\/dev\/null 2>&1 \&\& continue/kill -0 "$_pid" 2>\/dev\/null \&\& continue/'

if [ "$fails" -gt 0 ]; then
  printf '  %s mutation check(s) did not behave\n' "$fails"
  exit 1
fi
printf '  every mutant applied and was killed by exactly its declared arms\n'
exit 0
