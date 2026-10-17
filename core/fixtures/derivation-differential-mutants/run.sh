#!/usr/bin/env bash
# derivation-differential-mutants -- the mutation battery behind
# core/fixtures/derivation-differential. DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh
# Exit:  0 every mutant applied and was killed by exactly its declared arms,
#        1 a mutant survived, did not apply, or failed an arm it does not declare,
#        2 the harness could not run, so no verdict is readable.
#
# WHAT IT PROVES. Each mutant removes ONE behaviour of reconcile/derivation-differential.sh from a
# COPY of the whole reconcile directory, because the helper lifts vd_join() out of apply.sh and
# map_consumer() out of preclassify.sh beside itself; a lone copy would refuse at the lift and
# every mutant would "die" of that instead. The sibling fixture is then driven against the copy,
# and the set of arms that FAIL must EQUAL the set the mutant declares (compare_sets: declared
# arms that stayed green are a miss, failed arms that are not declared are the other half). A
# mutant that fails nothing SURVIVED. An undeclared failure is EITHER entanglement between two
# arms OR an undeclared consequence of a broad mutation; the battery cannot tell which, and the
# reviewer decides: declare it, narrow the mutant, or re-seed the world. A new arm in any world that
# reaches a verdict reddens R1-R3 until it is declared, and that is the intended review trigger.
# Each mutant's comment names its OWNER arm(s); the declared set is those plus the measured
# consequences, each widened arm carrying a one-line reason.
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

# failed_arms <log> -> sorted arm ids (A1a, A3b, S1c, ...) the driver reported FAIL on. The driver
# carries TWO arm families: A (the differential itself) and S (BL-631's scoped-join worlds, S1-S3).
# Both are accepted, and nothing else: a third prefix, or a seed row such as "S0 seed:" with no
# letter, still fails to parse, so the line-versus-id count below still catches it.
failed_arms() { sed -n 's/^  FAIL  \([AS][0-9]*[a-z]\) .*/\1/p' "$1" | sort -u; }
# parsed_ids <log> -> how many ids the parse above yields, DUPLICATES COUNTED
parsed_ids() { sed -n 's/^  FAIL  \([AS][0-9]*[a-z]\) .*/\1/p' "$1" | awk 'END { print NR + 0 }'; }

# compare_sets <moved-file> <declared-file> -> one line `<verdict>|<declared but green>|<failed but undeclared>`
# verdict: killed (equal sets), entangled (extras only), missed (a declared arm stayed green; any
# extras are still listed). Both inputs are sorted unique, one id per line.
compare_sets() {
  local miss extra v
  miss="$(comm -13 "$1" "$2" | tr '\n' ' ')"
  extra="$(comm -23 "$1" "$2" | tr '\n' ' ')"
  if [ -n "$miss" ]; then v=missed; elif [ -n "$extra" ]; then v=entangled; else v=killed; fi
  printf '%s|%s|%s\n' "$v" "$miss" "$extra"
}

# SELF-PROBE of compare_sets, BEFORE the driver is ever run: all three directions on synthetic sets.
_probe() { # _probe <moved ids> <declared ids> <expected verdict>
  printf '%s\n' $1 | sort -u > "$WORK/probe.moved"
  printf '%s\n' $2 | sort -u > "$WORK/probe.declared"
  local r; r="$(compare_sets "$WORK/probe.moved" "$WORK/probe.declared")"
  [ "${r%%|*}" = "$3" ] || { bad "compare_sets self-probe: moved {$1} vs declared {$2} answered '${r%%|*}', expected '$3'"; exit 2; }
}
_probe "A5b A17b" "A5b" entangled
_probe "A5b" "A5b" killed
_probe "A5b" "A5b A17b" missed
ok "compare_sets self-probe: an extra failed arm reads entangled, equal sets read killed, a green declared arm reads missed"

# ---- the unmutated control --------------------------------------------------------------
C="$(copy_recon control)" || { echo "FIXTURE ERROR: could not copy $RECON" >&2; exit 2; }
for s in apply.sh preclassify.sh derivation-differential.sh; do
  [ -f "$C/$s" ] || { echo "FIXTURE ERROR: the copied reconcile directory lacks $s" >&2; exit 2; }
done
printf 'HERMETIC-CONSUMED %s\n' "$SUBJ"
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
  # Every `  FAIL  ` line must parse to an arm id. A seed or control row that failed carries no id,
  # and would otherwise be dropped from the set. Lines are counted against the NON-UNIQUE parse, so
  # a duplicated id is a mismatch too.
  local nfl nid
  nfl="$(grep -c '^  FAIL  ' "$WORK/$label.log")" || nfl=0
  nid="$(parsed_ids "$WORK/$label.log")"
  if [ "$nfl" != "$nid" ]; then
    bad "$label: harness: $nfl FAIL line(s) but $nid parsed id(s)"
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
  local cmp verdict miss extra
  cmp="$(compare_sets "$WORK/$label.moved" "$WORK/$label.declared")"
  verdict="${cmp%%|*}"; miss="${cmp#*|}"; extra="${miss#*|}"; miss="${miss%%|*}"
  case "$verdict" in
    killed)
      ok "$label: KILLED -- its declared arm(s) $(tr '\n' ' ' < "$WORK/$label.declared")all fail, and nothing else does" ;;
    entangled)
      bad "$label: killed, but it failed an arm it does not declare: ${extra}
        failed: $(tr '\n' ' ' < "$WORK/$label.moved")" ;;
    *)
      bad "$label: killed, but NOT by the arm(s) it declares: ${miss}stayed green
        failed: $(tr '\n' ' ' < "$WORK/$label.moved")
        undeclared failures: ${extra:-none}" ;;
  esac
}

# ---- R1: the base side is ignored ------------------------------------------------------------
# Location: the classifier's per-side FAIL recorder. Behaviour: the base side's failures are never
# recorded, so every derivation reads PASS at base. The already-stale derivation then reads as
# broken by this pull, in both the offender world and the clean pair.
# OWNER: A2a A2b A3a A3c. The declared set is MEASURED at the U-a head plus the consequences below.
#   A1c A1d A2c A18c  the NEWLY-FAILING count and verdict wording move with the extra row.
#   A3b               the same clean-pair world as A3a/A3c: the stale derivation is now NEWLY-FAILING.
#   A3d A18b          the STALE-BOTH row is gone (beta reads PASS at base), which both arms assert is present.
#   A9a A9b           the zero-pass guard cannot fire when every base value is empty.
#   A16n              the W16N corpus carries beta, so it breaks the same way.
#   A19a A19b         the same zero-pass guard, over W19's broken root (measured at the BL-588 tip).
#   S3c               BL-631's two-break world: with the base side unread, the PAST file's stale
#                     derivation joins the CURRENT one, so "exactly one NEWLY-FAILING row" moves.
mutate R1-ignore-base-side \
  "A1c A1d A2a A2b A2c A3a A3b A3c A3d A9a A9b A16n A18b A18c A19a A19b S3c" \
  'if (brc == 1) B[k] = v' \
  's/if (brc == 1) B\[k\] = v/if (0) B[k] = v/'

# ---- R2: the stamp-equality refusal is restored ---------------------------------------------
# Location: immediately after the stamps INFO row. Behaviour: refuse when the two roots carry the
# same stamp commit -- which at hand-back they always do, so the helper refuses the one moment it
# exists for.
# OWNER: A1a A3a A8n. The declared set is every arm the driver emits that reaches a verdict through
# a refusal: D:11-17 seeds EVERY world at hand-back shape, so the restored gate fails everywhere.
# DERIVED by grepping the driver's emitted ids (grep -oE '"A[0-9]+[a-z]+ ' run.sh, 80 distinct) and
# classifying each against a world that exits 2 right after the INFO stamps row: rc/ck arms that
# expect a verdict fail; arms that already expect exit 2, nk absences and INFO-row reads stay green.
# That is 38 arms plus A18d, and A19b A19n A19o A19p from W19/W19N (A19a already expects exit 2).
# Measured at the BL-588 tip: the 42 ids that run could parse match exactly; A18d is the renamed seed
# row it could not parse.
#   S1c S1d S2n S2o S3a S3b S3c S3d  BL-631's scoped-join worlds: each expects a verdict over the
#                     CURRENT break (S1c/S1d, S3a-S3d) or over a kept classifier (S2n/S2o), and the
#                     restored gate refuses first. S1a/S1b/S1e and S2a-S2c already expect a refusal.
mutate R2-stamp-equality-refusal \
  "A1a A1b A1c A1d A2a A2c A3a A3c A3d A4a A5b A5n A5o A6n A6p A8b A8n A9b A11a A11b A11n A12a A12b A13a A13b A14n A14o A15a A16a A16b A16n A17b A17c A17n A17o A18a A18b A18c A18d A19b A19n A19o A19p S1c S1d S2n S2o S3a S3b S3c S3d" \
  'Information only -- at hand-back both read <base>."' \
  '/Information only -- at hand-back both read <base>\."$/a\
[ "$(stamp_commit < "$BR/.claude/.ai-dlc-version" 2>/dev/null)" != "$(stamp_commit < "$CONSUMER/.claude/.ai-dlc-version" 2>/dev/null)" ] || refuse stamps "both roots carry the same stamp commit, so the apply has not been run."
'

# ---- R3: the sides are swapped -------------------------------------------------------------
# Location: the stream-to-side binding the classifier reads by FILENAME. Behaviour: the base run's
# failures are scored as the consumer's and vice versa, so a derivation this pull broke reads as
# one it repaired.
# OWNER: A1a A1b A5o. MEASURED at the BL-588 tip (31 parsed ids; A18d is the renamed seed row that
# run could not parse). A18b IS declared although the tip adversary predicted it green: the swap
# leaves W18's beta row no longer STALE-BOTH, and the measurement read it red. Do not remove it
# on a reading. A19a A19b A19n A19o A19p move with W19/W19N as the other worlds do. Originally
# text-derived from the b.err/t.err classification: A broken-by-this-pull derivation reads NEWLY-PASSING, a world
# whose consumer side alone fails refuses (the consumer run exited 1 and named no FAIL line the
# reader parses), and one awk serves every world, so A18d moves too. A9c stays green: on the broken
# root the swap scores the base side's lone stale-only-at-base derivation (gamma) NEWLY-FAILING, so
# the run exits 1 without the refusal and never prints the clear. The derivation yields 25 arms plus A18d.
#   S1c S1d S2n S2o S3a S3b S3c  BL-631's scoped-join worlds: the CURRENT break reads repaired once
#                     the sides swap, so each arm expecting it NEWLY-FAILING (or an exit 1) moves. S3d
#                     (the dropped file's out-of-scope row) is printed before the comparison and holds.
mutate R3-side-swap \
  "A1a A1b A1c A1d A2c A5n A5o A6n A6p A9a A9b A11a A11b A12a A13a A13b A14n A14o A15a A16a A16b A17n A17o A18a A18b A18c A18d A19a A19b A19n A19o A19p S1c S1d S2n S2o S3a S3b S3c" \
  '-v fB="$TMP/b.err" -v fT="$TMP/t.err"' \
  's|-v fB="$TMP/b.err" -v fT="$TMP/t.err"|-v fB="$TMP/t.err" -v fT="$TMP/b.err"|'

# ---- R4: the broken-root refusal is dropped ------------------------------------------------
# Location: the zero-pass-at-base guard after classification. Behaviour: a base root on which
# nothing reproduces is compared anyway, every derivation reads stale at base, and the run clears.
# OWNER: A9a A9b. A9c is declared too: it asserts the run does not clear, and with the refusal dropped
# it clears, which is what separates R4 from R1 (R1 leaves the zero-pass guard unable to fire but
# does not clear the broken root). A19a A19b: W19 is a second broken-root world, refused by the same
# guard (measured at the BL-588 tip).
mutate R4-drop-broken-root-refusal \
  "A9a A9b A9c A19a A19b" \
  '[ "$N_BP" -gt 0 ] || [ "$N_TP" -eq 0 ] \' \
  's/^\[ "\$N_BP" -gt 0 \] || \[ "\$N_TP" -eq 0 \] \\$/true || [ "$N_TP" -eq 0 ] \\/'

# ---- R5: the self-update skip is dropped -----------------------------------------------------
# Location: the default walk's per-commit accept test. Behaviour: a commit is accepted on its
# `commit:` alone, so the self-update commit (commit: <base>, skill_commit: theirs) is taken as the
# base root. It already carries the range's machinery, a derivation this range broke reads
# STALE-BOTH, and the run clears.
# OWNER: A11a A11b A11c A11d A11e A11o A13n A13o A15a A15b (measured; exact set at the U-a head).
mutate R5-drop-self-update-skip \
  "A11a A11b A11c A11d A11e A11o A13n A13o A15a A15b" \
  'if resolves_to_base "$_sc" && skill_commit_ok "$_st"; then' \
  's/if resolves_to_base "\$_sc" && skill_commit_ok "\$_st"; then/if resolves_to_base "$_sc"; then/'

# ---- R6: the walk's skill_commit: test reverts to EQUALITY -------------------------------------
# Location: the default walk's per-commit accept test. Behaviour: the pre-fix rule -- skill_commit:
# absent-or-EMPTY, or resolving to <base>. A pre-pull commit whose skill_commit: is legitimately
# behind <base> is rejected and the walk refuses (A13), and a self-update commit that wrote an
# EMPTY value is taken as the base root (A15).
# OWNER: A13a A13b A13c A15a A15b (measured; exact set at the U-a head).
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
# OWNER: A16a A16b A16c A16d A16o. A15n used to fail too, entangled: WS3N's pre-pull commit (built
# by build_su) carried a matching stamp, so walking past the absent-line self-update commit still
# found a base. build_su's fourth argument now gives WS3N alone a pre-pull skill_commit: that
# skill_commit_ok rejects, so A15n stands down here (text-derived from that re-seed; the slot measures).
mutate R8-oldest-matching-commit \
  "A16a A16b A16c A16d A16o" \
  'if resolves_to_base "$_sc" && skill_commit_ok "$_st"; then BASE_COMMIT="$_c"; break; fi' \
  's/skill_commit_ok "\$_st"; then BASE_COMMIT="\$_c"; break; fi/skill_commit_ok "$_st"; then BASE_COMMIT="$_c"; continue; fi/'

# ---- R9: the leak NOTE stops asking whether the run is dead -----------------------------------
# Location: the leaked-worktree loop. Behaviour: any other run's worktree carrying a PID is named,
# including a CONCURRENT live run's, with a removal remedy that would pull its tree out from under it.
# A12e reddens too: the PID-1 worktree is a live run as well, owned by another uid.
# OWNER: A12l; A12e is a measured consequence.
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

# ---- R11: the recorded/actual output is never captured -------------------------------------
# Location: the consumer-stream continuation reader. Behaviour: the recorded output lands under an
# empty key, so a NEWLY-FAILING row names the command and never what it printed.
mutate R11-no-capture \
  "A18a" \
  'REC[ck] = r; next }' \
  's/REC\[ck\] = r; next }/REC[""] = r; next }/'

# ---- R12: the output is appended to every status ---------------------------------------------
# Location: the row printer. Behaviour: a STALE-BOTH row also carries recorded/actual, which reads
# as this pull having moved a figure it did not.
mutate R12-all-statuses \
  "A18b" \
  'if (status == "NEWLY-FAILING" && (k in REC))' \
  's/if (status == "NEWLY-FAILING" \&\& (k in REC))/if ((k in REC))/'

# ---- diffnosup: the classifier stops skipping SUPERSEDED derivations ---------------------------
# Location: the END loop's SUP skip. Behaviour: a record command the validator superseded has no
# FAIL on either side, so it scores PASS at base, and over a broken root that one pass keeps the
# zero-pass refusal from firing -- the run clears. The INFO row's count falls to 0 as well.
mutate diffnosup \
  "A19a A19b A19o" \
  'if (k in SUP) { nsup++; continue }' \
  '/if (k in SUP) { nsup++; continue }/d'

# ---- R13: an absent skill_commit: line is no longer accepted --------------------------------------
# Location: skill_commit_ok's absent-line branch. Behaviour: a stamp with no skill_commit: line at all
# (the pre-migration shape) is REJECTED instead of accepted, so the walk skips the self-update commit
# that carries none and, with WS3N's HEAD~1 stamped past <base>, finds no base root.
# OWNER: A15n alone. If the slot shows R13 failing more than A15n, R13 is DROPPED and A15n is stated
# unowned; an arm that only a mutant entangled with others can reach is not owned by it.
mutate R13-absent-skill-commit-rejected \
  "A15n" \
  'case "$NL$1" in *"${NL}skill_commit:"*) ;; *) return 0 ;; esac' \
  '/case "\$NL\$1" in/s/\*) return 0 ;; esac/*) return 1 ;; esac/'

# ---- R14: the base-side refusal wording changes ---------------------------------------------------
# Location: the base-side status refusal. Behaviour: the message reads `the base side exited` instead
# of `the base-side run exited`. OWNER: A5b and A17b assert the same refusal text from two worlds
# (a validator exiting 2, and a comparison diff that could not run); that overlap is real and is
# recorded here rather than hidden: a wording change reddens both, so neither arm discriminates the
# other's world through this text.
mutate R14-base-side-refusal-wording \
  "A5b A17b" \
  'the base-side run exited ${BRC} (only 0 and 1 are verdicts)' \
  's/the base-side run exited \${BRC}/the base side exited ${BRC}/'

if [ "$fails" -gt 0 ]; then
  printf '  %s mutation check(s) did not behave\n' "$fails"
  exit 1
fi
printf '  every mutant applied and was killed by exactly its declared arms\n'
exit 0
