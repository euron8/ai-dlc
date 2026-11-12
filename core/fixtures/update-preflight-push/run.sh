#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# update-preflight-push — prove the ai-dlc-update step-1 AUTO-PUSH failure path is NOT fatal,
# that an UN-SYNCED branch reaches the dry-run with step 2 DEFERRED, and that step 6's
# re-confirm bullet never pushes and is the one place `apply` is refused.
#
# WHAT THE SUBJECT IS, AND WHAT THIS CANNOT OBSERVE. The subject is prose in
# `ai-dlc-update/SKILL.md`, eight units: the two AUTO-PUSH bullets of step 1's git preflight
# (no-upstream, ahead-only), step 1's detect paragraph, step 1's UN-SYNCED paragraph, step 2's
# UN-SYNCED DEFER paragraph, step 2's cycle bullet and its push-failure discard paragraph, and
# step 6's "Re-confirm the step-1 git preflight" bullet; BL-986 adds six more (arms R1-R4, below:
# step 1's skill-branch bullet, step 2's return bullet and the re-invoke bullet it must precede, step 8's
# named-base and RETURN PROCEDURE bullets, and step 9's return clause). No executable reads that text, so
# nothing here observes whether a running update actually continued past a failed push. The
# observable is the declared text, and every assertion is scoped to it.
#
# THE DEFECT THIS EXISTS TO CATCH. A failed step-1 push STOPPED the whole run ("do not proceed
# on an un-synced branch"), so an auth or protected-branch rejection cost the operator the
# dry-run report as well as the apply; and step 6 AUTO-PUSHED "to re-sync exactly as in step
# 1" immediately before cutting the reconcile branch — a write to origin from inside the
# isolation step. The fix: a failed step-1 push marks the branch UN-SYNCED and continues to
# the dry-run, step 2 DEFERS on that branch (a local self-update commit there is the orphan
# the step-2 gate paragraph describes), and step 6 pushes nothing and STOPs `apply` on an
# out-of-sync or UN-SYNCED branch. `offender.md` in this directory is the pre-fix text, cut
# byte-for-byte from the release that shipped the defect.
#
# BL-391, THREE MORE UNITS. Step 2's cycle bullet said "If there is no remote / push fails,
# commit locally and note it", which keeps a commit advancing `skill_version` on a branch that
# never merges. A push that fails (since the push wrapper, a TRANSPORT exit after the consumer's
# pre-push hook passed in the wrapper's single run) now discards the cycle: stage by
# pathspec only, check out the original branch, list the self-update branch's files, delete it
# only when every file is one this cycle wrote (else STOP naming it), DEFER step 2, mark the
# branch UN-SYNCED, leave the stamp. Arm 8 forbids the failed-push/commit-locally pairing in the
# cycle bullet; arm 9 REQUIRES the discard paragraph, because deleting the old sentence alone
# satisfies arm 8. Arm 7 holds step 1's detect paragraph to the truth: step 1 has no porcelain
# check, so it must not claim a clean tree. Arm 4 additionally requires step 2 as a source of the
# step-6 refusal. A consumer whose installed SKILL.md predates BL-391 SKIPs arms 7-9 and the
# arm-4 conjunct; the distribution never does.
#
# WHY EVERY ARM HAS A POSITIVE KEY. The first grammar keyed on a closed list of fatal words and
# on the literal `git push`, so "halt the run", "abort", "push it to re-sync" and "push anyway"
# all passed as correct, while "does NOT stop the run" and a step 6 naming its remedy command
# failed as wrong. Each arm now REQUIRES the phrase the contract demands (non-fatal plus
# continue; the no-push sentence; UN-SYNCED and the refusal in one clause; DEFER in the step-2
# clause), keeps a widened forbidden list beside it, and a negated fatal verb ("not stop", "not a
# halt") is normalised to the token `negfatal` before either list runs. `git push` is not
# forbidden in step 6: naming the remedy command is allowed. BL-389's archived receipt carried
# the arm 1-6 regexes; BL-391's `verify: sh` receipt carries arms 4 and 7-9. Change the live
# receipt with the arms it restates.
#
# WHY BULLET-SCOPED. The BEHIND and DIVERGED bullets sit beside the AHEAD bullet and say STOP,
# correctly, in the fixed text too. A list- or file-scoped grep for STOP flags the fixed text
# on their account. Probe direction 3 asserts that false finding is excluded.
#
# WHY WHITESPACE-COLLAPSED. A bullet is joined across its continuation lines before any
# pattern runs, so an anchor or a forbidden phrase split by a line wrap is still seen.
# `nearmiss.md` wraps all eight unit anchors, and probe direction 4 asserts it really is wrapped.
#
# THE MUTANT MATRIX. A CELL is one of the thirteen ARMS (the nine below plus R1-R4, described after the
# BL-391 rows), each a text predicate over one file: noup (step 1 no-upstream
# AUTO-PUSH), ahead (step 1 ahead-only AUTO-PUSH), nopush (step 6 carries the no-push sentence), refuse (step 6
# refuses apply on an UN-SYNCED branch), para (step 1's UN-SYNCED paragraph), step2 (step 2's UN-SYNCED paragraph),
# detect (step 1's detect paragraph), cycle (step 2's cycle bullet) and discard (step 2's discard paragraph).
# PER PUSH a mutant is scored on its DECIDING arm, which must find it, and its named TWIN, a different arm it could
# plausibly co-trip but must leave compliant: two predicate runs over the mutant copy where the full vector took
# thirteen. `run.sh --matrix` scores each mutant on every arm in scope and prints one MATRIX line per mutant. The four
# BL-391 rows decide arms 7-9, which a consumer predating BL-391 skips. The matrix is re-measured whenever an arm
# or a mutant is added or changed, by the REMEASURE command below, run from the repo root.
# MUTANT-MATRIX wrong1 decides=ahead twins=noup
# MUTANT-MATRIX wA-halt decides=ahead twins=noup
# MUTANT-MATRIX wrong2 decides=nopush twins=refuse
# MUTANT-MATRIX wC-push decides=nopush twins=refuse
# MUTANT-MATRIX wG-nosentence decides=nopush twins=refuse
# MUTANT-MATRIX wD-negate decides=refuse twins=nopush
# The pre-BL-391 copy of the subject exists because the distribution's SKILL.md postdates BL-391, so without it
# wD-negate-pre could never fire here: its anchor line is the step-6 clause as it read before step 2 became a second
# source of the UN-SYNCED marking. The copy is the distribution text with that one clause reverted, built in both
# modes; only wD-negate-pre runs on it, with the BL-391 conjunct of the refuse arm off, and an unmutated control on
# the same copy gates the kill.
# MUTANT-MATRIX wD-negate-pre decides=refuse twins=nopush
# MUTANT-MATRIX wF-para decides=para twins=step2
# MUTANT-MATRIX wE-step2 decides=step2 twins=para
# MUTANT-MATRIX wH-nocontinue decides=noup twins=ahead
# MUTANT-MATRIX wI-nononfatal decides=noup twins=ahead
# MUTANT-MATRIX wJ-nodryrun decides=para twins=step2
# MUTANT-MATRIX wK-nodefer decides=step2 twins=para
# MUTANT-MATRIX wY-nostep2 decides=refuse twins=nopush
# MUTANT-MATRIX wL-cleanclaim decides=detect twins=cycle
# MUTANT-MATRIX wM-nocheckline decides=detect twins=cycle
# MUTANT-MATRIX wN-failcommit decides=cycle twins=detect
# MUTANT-MATRIX wO-nofailcase decides=cycle twins=detect
# MUTANT-MATRIX wW-nopathspec decides=discard twins=cycle
# MUTANT-MATRIX wX-keepcommit decides=discard twins=cycle
# MUTANT-MATRIX wP-nocheckout decides=discard twins=cycle
# MUTANT-MATRIX wQ-nofilelist decides=discard twins=cycle
# MUTANT-MATRIX wR-uncondelete decides=discard twins=cycle
# MUTANT-MATRIX wS-nostop decides=discard twins=cycle
# MUTANT-MATRIX wT-nodefer decides=discard twins=cycle
# MUTANT-MATRIX wU-nounsynced decides=discard twins=cycle
# MUTANT-MATRIX wV-stampmoves decides=discard twins=cycle
#
# BL-986, ARMS R1-R4. A merge left the consumer's checkout on the merged skill branch: step 8 had no return to the
# working branch, step 2's success path re-invoked with none, and step 1 read a merged-and-kept skill branch as
# reconcilable. Every conjunct keys on text that EMITS behaviour (a literal command, an echo, a STOP sentence).
# R1 holds step 8's RETURN PROCEDURE bullet, ABANDON included: (a) working from baseRefName and skill branch from
# headRefName with its not-MERGED and skill-branch-base STOPs; (b) the +refspec fetch and its STOP; (c) the NAMED
# working-tree check, the NUL-delimited block line by line (toplevel cd, both ref guards, the -z union, sort -zu,
# read -d '', the :(literal) DIRTY test, the ON-DISK test) and its remedy split by tag; (d) a checkout with no
# -f/stash/discard and a STOP on its refusal; (e) ff-only and the ahead-gated remedy; (f) the CASE-SENSITIVE
# `branch -D` tip gate and its STOP, then the remote-delete block (REMOTE-KEPT for no local branch, an unreadable
# or a moved remote tip, a 422 as deleted, REMOTE-DELETE-FAILED never a STOP), ORDERED after (a)'s MERGED test and
# the tip gate and never inside ABANDON; ABANDON without (a) or (f), whose failed fetch skips (b) and (e); the
# state-keyed no-op. R2 holds step 2: the return bullet ORDERED before the re-invoke bullet, the merge with
# --delete-branch=false, the procedure, no-remote through ABANDON, --base <original-branch> and its baseRefName
# STOP, a STOP that stops the re-invoke, a not-merged STOP that never says landed, and both discard paragraphs
# citing ABANDON's (d) run once with an ABANDON STOP stopping the invocation. R3 holds step 1's skill-branch bullet
# (its grammar EXECUTED against the three skill cuts and two near-miss names, ORDERED before both AUTO-PUSH bullets,
# the one --state all classifier, the four ordered tests with the tip gate and the reflog-base test, the own-branch
# OPEN STOP, re-invoke after the return, the else-STOP reading .claude/.ai-dlc-applying, the one oldest
# fixed-suffix reflog derivation) and the no-remote STOP through ABANDON. R4 holds step 9's wording, step 8's
# `gh pr create --base <cut-from>` from the reflog with its refusal, and step 8's literal merge.
# The two run-as-written blocks (the working-tree check and the remote-delete block) are also pinned BYTE FOR BYTE
# against block-worktree-check.txt and block-remote-delete.txt in this directory, because a per-line substring test
# passes an additive or reordering edit; merge_ok refuses `-d` as well as a bare or `=true` `--delete-branch`.
# Three seeds, three input SHAPES: `return-offender.md` is the pre-fix text cut byte-for-byte from e3d2dfc35
# (every unit ABSENT) and must score 1111; `return-nearmiss.md` is a respelled, wrapped correct text and must score
# 0000; `return-wrong.md` has every unit PRESENT with one clause per arm altered and must score 1111. The SKIP
# needs EVERY R anchor absent in a consumer layout; a partial set FAILs, and the distribution never skips.
# Their mutants run from a separate table through mutate_r, which matches by ENVIRON (the grammar line carries
# backslashes that awk -v would strip) and can MOVE a whole bullet after another for the ORDER mutants.
# MUTANT-MATRIX r1-upstream decides=r1 twins=r4
# MUTANT-MATRIX r1-memory decides=r1 twins=r4
# MUTANT-MATRIX r1-headref decides=r1 twins=r4
# MUTANT-MATRIX r1-noplus decides=r1 twins=r4
# MUTANT-MATRIX r1-checkoutfirst decides=r1 twins=r4
# MUTANT-MATRIX r1-force decides=r1 twins=r4
# MUTANT-MATRIX r1-stash decides=r1 twins=r4
# MUTANT-MATRIX r1-discard decides=r1 twins=r4
# MUTANT-MATRIX r1-nonegf decides=r1 twins=r4
# MUTANT-MATRIX r1-nonegstash decides=r1 twins=r4
# MUTANT-MATRIX r1-nonegdiscard decides=r1 twins=r4
# MUTANT-MATRIX r1-norefusal decides=r1 twins=r4
# MUTANT-MATRIX r1-noffonly decides=r1 twins=r4
# MUTANT-MATRIX r1-remedyalways decides=r1 twins=r4
# MUTANT-MATRIX r1-ungated decides=r1 twins=r4
# MUTANT-MATRIX r1-noop decides=r1 twins=r4
# MUTANT-MATRIX r2-stopreinvoke decides=r2 twins=r1
# MUTANT-MATRIX r2-landed decides=r2 twins=r1
# MUTANT-MATRIX r2-notmergedreinvoke decides=r2 twins=r1
# MUTANT-MATRIX r2-afterreinvoke decides=r2 twins=r1
# MUTANT-MATRIX r3-widegrammar decides=r3 twins=r2
# MUTANT-MATRIX r3-afterautopush decides=r3 twins=r2
# MUTANT-MATRIX r3-mergedonly decides=r3 twins=r2
# MUTANT-MATRIX r3-skillbase decides=r3 twins=r2
# MUTANT-MATRIX r3-noreinvoke decides=r3 twins=r2
# MUTANT-MATRIX r3-elsenote decides=r3 twins=r2
# MUTANT-MATRIX r3-noapplying decides=r3 twins=r2
# MUTANT-MATRIX r4-delete decides=r4 twins=r1
# MUTANT-MATRIX r4-nobase decides=r4 twins=r1
# MUTANT-MATRIX r1-nomergedstop decides=r1 twins=r4
# MUTANT-MATRIX r1-noskillbase decides=r1 twins=r4
# MUTANT-MATRIX r1-nofetchstop decides=r1 twins=r4
# MUTANT-MATRIX r1-unnamed decides=r1 twins=r4
# MUTANT-MATRIX r1-nocd decides=r1 twins=r4
# MUTANT-MATRIX r1-originonly decides=r1 twins=r4
# MUTANT-MATRIX r1-nolocalguard decides=r1 twins=r4
# MUTANT-MATRIX r1-noorigguard decides=r1 twins=r4
# MUTANT-MATRIX r1-nonul decides=r1 twins=r4
# MUTANT-MATRIX r1-noread0 decides=r1 twins=r4
# MUTANT-MATRIX r1-noliteral decides=r1 twins=r4
# MUTANT-MATRIX r1-noondisk decides=r1 twins=r4
# MUTANT-MATRIX r1-ondiskremedy decides=r1 twins=r4
# MUTANT-MATRIX r1-commitremedy decides=r1 twins=r4
# MUTANT-MATRIX r1-checkbeforefetch decides=r1 twins=r4
# MUTANT-MATRIX r1-lowerd decides=r1 twins=r4
# MUTANT-MATRIX r1-notipstop decides=r1 twins=r4
# MUTANT-MATRIX r1-nolocalkept decides=r1 twins=r4
# MUTANT-MATRIX r1-unreadable decides=r1 twins=r4
# MUTANT-MATRIX r1-nomoved decides=r1 twins=r4
# MUTANT-MATRIX r1-no422 decides=r1 twins=r4
# MUTANT-MATRIX r1-deletefailstop decides=r1 twins=r4
# MUTANT-MATRIX r1-deletebeforea decides=r1 twins=r4
# MUTANT-MATRIX r1-deleteinabandon decides=r1 twins=r4
# MUTANT-MATRIX r1-abandonf decides=r1 twins=r4
# MUTANT-MATRIX r1-abandonfetchstop decides=r1 twins=r4
# MUTANT-MATRIX r2-delbranch decides=r2 twins=r1
# MUTANT-MATRIX r2-nofalse decides=r2 twins=r1
# MUTANT-MATRIX r2-noreturn decides=r2 twins=r1
# MUTANT-MATRIX r2-noremote decides=r2 twins=r1
# MUTANT-MATRIX r2-nobase decides=r2 twins=r1
# MUTANT-MATRIX r2-nobasestop decides=r2 twins=r1
# MUTANT-MATRIX r2-discardextra decides=r2 twins=r1
# MUTANT-MATRIX r2-discardgoeson decides=r2 twins=r1
# MUTANT-MATRIX r2-hookextra decides=r2 twins=r1
# MUTANT-MATRIX r2-hookgoeson decides=r2 twins=r1
# MUTANT-MATRIX r3-openstop decides=r3 twins=r2
# MUTANT-MATRIX r3-openfrombase decides=r3 twins=r2
# MUTANT-MATRIX r3-no4stop decides=r3 twins=r2
# MUTANT-MATRIX r3-4noabandon decides=r3 twins=r2
# MUTANT-MATRIX r3-notipgate decides=r3 twins=r2
# MUTANT-MATRIX r3-newest decides=r3 twins=r2
# MUTANT-MATRIX r3-head1 decides=r3 twins=r2
# MUTANT-MATRIX r3-pattern decides=r3 twins=r2
# MUTANT-MATRIX r3-noremotecheckout decides=r3 twins=r2
# MUTANT-MATRIX r3-noremotenostop decides=r3 twins=r2
# MUTANT-MATRIX r4-step9delbranch decides=r4 twins=r1
# MUTANT-MATRIX r4-mergedelbranch decides=r4 twins=r1
# MUTANT-MATRIX r4-mergenofalse decides=r4 twins=r1
# MUTANT-MATRIX r4-norefuse decides=r4 twins=r1
# MUTANT-MATRIX r4-fromlog decides=r4 twins=r1
# MUTANT-MATRIX r4-noreflog decides=r4 twins=r1
# MUTANT-MATRIX r1-headc0 decides=r1 twins=r4
# MUTANT-MATRIX r1-breakloop decides=r1 twins=r4
# MUTANT-MATRIX r1-deletefirst decides=r1 twins=r4
# MUTANT-MATRIX r1-deletebeforegate decides=r1 twins=r4
# MUTANT-MATRIX r2-dshort decides=r2 twins=r1
# Every row of the mutant table reaches mutant_killed through one helper, as a variable:
# MUTANT-MATRIX-DYNAMIC score_row why=passes the mutant name of every table row as a variable and every name keeps its own row
# MUTANT-MATRIX-REMEASURE bash core/fixtures/update-preflight-push/run.sh --matrix
#
# Usage: run.sh [--matrix]
# Exit:  0 = every assertion holds (or the subject is absent: SKIP), 1 = the subject regressed,
#        2 = fixture broken.
set -uo pipefail

MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "update-preflight-push: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="update-preflight-push"

# THE SUBJECT IN BOTH LAYOUTS, candidates named side by side off the fixture's own location.
# Never a walk for VERSION (I106): a consumer has no VERSION at its root. HERE comes from $0,
# not from the process cwd, so the resolution is cwd-invariant; the last arm asserts that.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SUBJ="$(pick "$HERE/../../skills/ai-dlc-update/SKILL.md" \
             "$HERE/../../../core/skills/ai-dlc-update/SKILL.md" \
             "$HERE/../../../.claude/skills/ai-dlc-update/SKILL.md")"

# A core fixture can arrive one pull ahead of its subject. That is a SKIP, never a pass: no
# `ok` line is printed, so nothing reads as a checked subject.
if [ -z "$SUBJ" ]; then
  echo "$NAME:"
  echo "  SKIP  ai-dlc-update/SKILL.md resolves from $HERE in neither layout, so this fixture landed ahead of its subject and asserted nothing"
  echo
  echo "$NAME: SKIP (subject absent)"
  exit 0
fi

echo "HERMETIC-CONSUMED $(cd "$(dirname "$SUBJ")" && pwd -P)/$(basename "$SUBJ")"

OFF="$HERE/offender.md"
NEAR="$HERE/nearmiss.md"
ROFF="$HERE/return-offender.md"
RNEAR="$HERE/return-nearmiss.md"
RWRONG="$HERE/return-wrong.md"
for f in "$OFF" "$NEAR" "$ROFF" "$RNEAR" "$RWRONG" "$HERE/block-worktree-check.txt" "$HERE/block-remote-delete.txt"; do
  [ -s "$f" ] || { echo "$NAME: FIXTURE BROKEN — seed $f is missing or empty" >&2; exit 2; }
done

WORK="$(mktemp -d)" || { echo "$NAME: FIXTURE BROKEN — mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
B391=1   # every probe runs the full BL-391 predicate; the corpus may lower it, see below
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  FIXTURE BROKEN — %s\n' "$1"; echo; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }

MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || broken "lib/mutant.sh not found beside $HERE"
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

echo "$NAME:"

# --- THE EXTRACTOR -------------------------------------------------------------------------
# Prints every UNIT of a file on ONE line. A unit is a `- ` bullet or an indented paragraph:
# continuation lines (indented, non-bullet) are joined, `*` is dropped, whitespace runs
# collapse to one space, and the result is lowercased. A unit ends at the next bullet, a blank
# line, or an unindented line (a numbered step heading, which is how step 1's UN-SYNCED
# paragraph ends). Then a NEGATED fatal verb ("not stop", "not a halt", "never abort") becomes
# the token `negfatal`, so a sentence denying a stop is not read as a stop. The rewrite has no
# trailing boundary on purpose: one would consume the next character, and a consumed period
# merges two clauses for the clause-scoped arms below ("not stopped" becomes "negfatalped"). LC_ALL=C because the
# subject carries multibyte characters and a BSD awk otherwise aborts mid-file, which would
# read as "the unit says nothing".
units() { # units <file>
  LC_ALL=C awk '
    function fin() {
      if (t == "") return
      gsub(/[*]/, "", t); gsub(/[ \t]+/, " ", t); t = tolower(t)
      gsub(/(not|never|no|nor) (a )?(stop|halt|abort|end|terminate)/, "negfatal", t)
      print t; t = ""
    }
    /^[ \t]*- / { fin(); t = $0; next }
    /^[ \t]+[^ \t]/ { t = (t == "" ? $0 : t " " $0); next }
    { fin() }
    END { fin() }
  ' "$1"
}

# The ONE unit whose joined text carries the anchor. rc 3 unless exactly one does: an
# anchor that selects nothing, or two units, is a stale fixture and never a verdict. rc 4
# when it selects nothing, so an arm whose subject is a sentence the fix ADDED can score the
# pre-fix text (where that sentence does not exist) as a finding rather than as stale.
unit() { # unit <file> <lowercase anchor>
  _all="$(units "$1")"
  _n="$(grep -cF -- "$2" <<<"$_all")" || _n=0
  [ "$_n" -eq 0 ] && return 4
  [ "$_n" -eq 1 ] || return 3
  grep -F -- "$2" <<<"$_all"
}

A_NOUP='remote exists but the current branch has no upstream'
A_AHEAD='branch ahead of its upstream'
A_BEHIND='branch behind its upstream'
A_RECONF='re-confirm the step-1 git preflight'
A_PARA='one whose step-1 auto-push failed'
A_STEP2='on a branch step 1 left un-synced'
A_DETECT='detect with'
A_CYCLE='run the self-update cycle autonomously'
A_DISCARD='a push that fails here discards the cycle'

# THE GRAMMAR, stated once. BL-389's archived receipt carried the same five regexes.
FATAL='(^|[^a-z])(stop|stops|stopped|halt|halts|halted|abort|aborts|terminate|terminates)([^a-z]|$)|run ends|ends the run|end the run|do not proceed|does not proceed'
NONFATAL='not fatal|non-fatal|negfatal'
CONT='continue|keep going|carry on|carries on|(proceed|proceeds|continues) to the dry-run'
NOPUSH='do not push|does not push|never push|no push|nothing is pushed|nothing is published|pushes nothing|publishes nothing'
PUSHES='auto-push|push it|push the branch|to re-sync|push anyway|pushes anyway'

# THE PREDICATES, applied to probe, corpus and mutant alike. Each returns 0 = compliant,
# 1 = finding, 3 = unit not located (or located twice).
#
# arms 1-2, a step-1 push-failure bullet: carries a non-fatal phrase AND a continue phrase,
# names its failure path and UN-SYNCED, and carries no fatal phrase.
push_fail_ok() { # push_fail_ok <file> <anchor>
  _b="$(unit "$1" "$2")" || return 3
  grep -qE "$FATAL" <<<"$_b" && return 1
  grep -qE "$NONFATAL" <<<"$_b" || return 1
  grep -qE "$CONT" <<<"$_b" || return 1
  grep -qE 'fail|reject' <<<"$_b" || return 1
  grep -qF 'un-synced' <<<"$_b" || return 1
  return 0
}
# arm 3, step 6: carries the no-push sentence and no instruction to push. Naming the remedy
# command (`git push -u origin <branch>`) is allowed and is not in PUSHES.
reconf_nopush_ok() { # reconf_nopush_ok <file>
  _b="$(unit "$1" "$A_RECONF")" || return 3
  grep -qE "$PUSHES" <<<"$_b" && return 1
  grep -qE "$NOPUSH" <<<"$_b" || return 1
  return 0
}
# arm 4, step 6: UN-SYNCED and a stop/refuse of apply in ONE clause. Clause-scoped because the
# bullet also STOPs apply on a failed fetch, which would satisfy a bullet-wide test after the
# un-synced refusal itself had been negated.
#
# BL-391 added a second source of the marking: a step-2 push that failed and was discarded
# leaves the branch UN-SYNCED too, so the refusing clause must name step 2 as a source. That
# conjunct is skipped only where B391=0 (a consumer whose installed text predates BL-391).
reconf_refuse_ok() { # reconf_refuse_ok <file>
  _b="$(unit "$1" "$A_RECONF")" || return 3
  grep -qE 'un-synced[^.;]*(stop|refuse)[^.;]*apply' <<<"$_b" || return 1
  [ "$B391" = 1 ] || return 0
  grep -qE 'step 2[^.;]*un-synced' <<<"$_b" || return 1
  return 0
}
# arm 5, step 1's UN-SYNCED paragraph: proceeds to the dry-run, names step 2's DEFER, and does
# not end the run. Absent (the pre-fix text) is a finding.
para_ok() { # para_ok <file>
  _b="$(unit "$1" "$A_PARA")"; _r=$?
  [ "$_r" -eq 4 ] && return 1
  [ "$_r" -eq 0 ] || return 3
  grep -qE "$FATAL" <<<"$_b" && return 1
  grep -qE '(proceed|proceeds|continue|continues) to the dry-run' <<<"$_b" || return 1
  grep -qF 'defer' <<<"$_b" || return 1
  return 0
}
# arm 6, step 2's UN-SYNCED paragraph: the anchoring clause itself says DEFER, and nothing in
# the unit pushes or commits locally. Absent (the pre-fix text) is a finding.
step2_ok() { # step2_ok <file>
  _b="$(unit "$1" "$A_STEP2")"; _r=$?
  [ "$_r" -eq 4 ] && return 1
  [ "$_r" -eq 0 ] || return 3
  grep -qE 'left un-synced[^.;]*defer' <<<"$_b" || return 1
  grep -qE "$PUSHES|commits? (it )?locally" <<<"$_b" && return 1
  return 0
}
# arm 7, step 1's detect paragraph: it must not claim a CLEAN tree is checked, because step 1
# has no porcelain check, and it must say so and name step 6 as where a dirty tree is refused.
# The pre-fix text said "A clean tree on a branch in sync ... is the only state that proceeds"
# while nothing in step 1 looked at the tree.
detect_ok() { # detect_ok <file>
  _b="$(unit "$1" "$A_DETECT")" || return 3
  grep -qF 'clean tree on a branch' <<<"$_b" && return 1
  grep -qE '(not|never)[^.;]*(check|inspect)[^.;]*working tree|working tree[^.;]*(not|never)[^.;]*(check|inspect)' <<<"$_b" || return 1
  grep -qF 'step 6' <<<"$_b" || return 1
  return 0
}
# arm 8, step 2's cycle bullet: it still names the push-failure case, and no clause of it pairs
# a failed push with a local commit. The no-remote commit-locally path is allowed.
FAILCOMMIT='push (that )?fails?[^.;]*commits?[^.;]*locally|commits? locally[^.;]*push (that )?fails?'
cycle_ok() { # cycle_ok <file>
  _b="$(unit "$1" "$A_CYCLE")" || return 3
  grep -qE "$FAILCOMMIT" <<<"$_b" && return 1
  grep -qE 'push (that )?fails?|failed push' <<<"$_b" || return 1
  return 0
}
# arm 9, the discard paragraph: ABSENT IS A FINDING. Deleting the commit-locally sentence
# satisfies arm 8's forbidden half; only this arm requires the procedure that replaces it:
# pathspec-only staging, checkout of the original branch BEFORE a delete, the file-list check,
# a delete that is conditional on it, a STOP naming the branch otherwise, step 2's DEFER, the
# UN-SYNCED marking, and the stamp left where it was. Nothing in it may commit locally.
# THE MARKING NEEDS AN UN-SYNCED THAT IS NOT NEGATED. The paragraph also says a hook refusal is
# "not UN-SYNCED", so a bare `un-synced` match let wU delete the marking and survive; keying on
# one spelling ("mark the branch") instead broke probe 2, whose correct text says "branch as".
discard_ok() { # discard_ok <file>
  _b="$(unit "$1" "$A_DISCARD")"; _r=$?
  [ "$_r" -eq 4 ] && return 1
  [ "$_r" -eq 0 ] || return 3
  grep -qE 'commits? (it )?locally' <<<"$_b" && return 1
  grep -qF 'pathspec' <<<"$_b" || return 1
  grep -qE 'git checkout <original.*branch -d' <<<"$_b" || return 1
  grep -qF 'git diff --name-only' <<<"$_b" || return 1
  grep -qE 'only (when|if)[^.;]*branch -d' <<<"$_b" || return 1
  grep -qE '(stop|refuse)[^.;]*name the branch|name the branch[^.;]*(stop|refuse)' <<<"$_b" || return 1
  grep -qE 'step 2 defer' <<<"$_b" || return 1
  _u="$(grep -oE '(not )?un-synced' <<<"$_b")" || return 1
  grep -qvx 'not un-synced' <<<"$_u" || return 1
  grep -qE 'stay where (they|it) w(ere|as)|stamp unchanged' <<<"$_b" || return 1
  return 0
}

# The nine-arm vector for one file: noupstream ahead nopush refuse para step2 detect cycle
# discard, each digit the rc.
vector() { # vector <file>
  push_fail_ok "$1" "$A_NOUP"; r1=$?
  push_fail_ok "$1" "$A_AHEAD"; r2=$?
  reconf_nopush_ok "$1"; r3=$?
  reconf_refuse_ok "$1"; r4=$?
  para_ok "$1"; r5=$?
  step2_ok "$1"; r6=$?
  detect_ok "$1"; r7=$?
  cycle_ok "$1"; r8=$?
  discard_ok "$1"; r9=$?
  printf '%s%s%s%s%s%s%s%s%s' "$r1" "$r2" "$r3" "$r4" "$r5" "$r6" "$r7" "$r8" "$r9"
}

# --- ARMS R1-R4 (BL-986): the return to the working branch --------------------------------
# Pure text predicates over joined units, like arms 1-9. An absent unit is a FINDING (rc 4 becomes 1), because
# the pre-fix text has none of these units; a doubled anchor is rc 3 (stale), never a verdict. Every conjunct keys
# on text that EMITS behaviour (a literal command, an echo, a STOP sentence), never on a comment.
A_R1='after every merge, return the checkout to the working branch'
A_ABANDON='its abandon form moves the checkout off an unmerged skill branch'
A_R2='after the auto-merge, return the checkout before the re-invoke'
A_REINV='then stop this invocation and re-invoke `/ai-dlc-update` automatically'
A_HOOKREF='on a `hook-refused` exit the branch is discarded the same way'
A_R3='current branch is a skill branch'
A_NOREM='no remote configured (`git remote` empty)'
A_R4A='the return procedure in step 8 is the only move onto a working branch'
A_R4B="the pr's base is named, never defaulted"
A_R4M='the merge command is literal:'
# The SKIP decision reads these: a consumer SKIPs R1-R4 only when EVERY one is absent; a partial set FAILs.
R_ANCHORS="A_R1 A_R2 A_R3 A_R4A A_R4B A_R4M"

# pos <text> <needle> -> _P, the offset of the first occurrence, or -1. A builtin, so no fork per call.
pos() { _P=-1; case "$1" in *"$2"*) _t="${1%%"$2"*}"; _P="${#_t}" ;; esac; }
# uidx <units text> <anchor> -> _I, the 1-based index of the one unit carrying the anchor (the caller has already
# established it is exactly one through unit()).
uidx() { _I="$(grep -nF -- "$2" <<<"$1")"; _I="${_I%%:*}"; }
# rget <file> <anchor> -> _b, with rc 1 when the unit is absent and 3 when it is not located exactly once.
rget() { _b="$(unit "$1" "$2")"; _r=$?; [ "$_r" -eq 4 ] && return 1; [ "$_r" -eq 0 ] || return 3; return 0; }
# units_cs <file>: the same units with their CASE KEPT and no negfatal rewrite, for the one token whose case is the
# behaviour (`branch -D` against `-d`). unit_cs <file> <lowercase anchor> -> that one unit, rc as unit().
units_cs() {
  LC_ALL=C awk '
    function fin() { if (t == "") return; gsub(/[*]/, "", t); gsub(/[ \t]+/, " ", t); print t; t = "" }
    /^[ \t]*- / { fin(); t = $0; next }
    /^[ \t]+[^ \t]/ { t = (t == "" ? $0 : t " " $0); next }
    { fin() }
    END { fin() }
  ' "$1"
}
unit_cs() {
  _ac="$(units_cs "$1")" || return 3
  _nc="$(grep -ciF -- "$2" <<<"$_ac")" || _nc=0
  [ "$_nc" -eq 0 ] && return 4
  [ "$_nc" -eq 1 ] || return 3
  grep -iF -- "$2" <<<"$_ac"
}
# merge_ok <unit text>: the unit carries the literal merge with `--delete-branch=false` and no backticked
# `gh pr merge` that carries a delete-branch flag gh reads as true: `--delete-branch` bare or `=true`, or its short
# form `-d` (either reads true and runs gh's local checkout). The unit is lowercased, so `-D` reads as `-d` here.
merge_ok() {
  grep -qF -- '`gh pr merge <n> --squash --delete-branch=false --match-head-commit <sha>`' <<<"$1" || return 1
  grep -qE -- '`gh pr merge [^`]*(--delete-branch([^=]|=true)| -d( |`))' <<<"$1" && return 1
  return 0
}

# blk_check <file>: the two run-as-written blocks of step 8's RETURN PROCEDURE, cut from between their ``` fences
# and identified by their first line, must equal the pinned copies in this directory BYTE FOR BYTE, so an
# additive or reordering edit inside a block (a filter after `sort -zu`, a `break`, the DELETE moved above the
# lookup) is a finding that no per-line substring test could make. rc 0 both equal; 1 a block differs, with _BLK
# naming it; 3 a block is not found between fences exactly once (FIXTURE STALE).
BLK_WT="$HERE/block-worktree-check.txt"
BLK_RD="$HERE/block-remote-delete.txt"
# A block is identified by a placeholder ANY of its lines carries (`<working>` for the check, `<skill-branch>` for
# the remote delete), never by its first line, so a mutant of the first line is a byte mismatch and not a lost block.
blk_cut() { # blk_cut <file> <placeholder> <out>
  MK="$2" LC_ALL=C awk 'BEGIN { k = ENVIRON["MK"] }
    /^[ \t]*```[ \t]*$/ { if (!inb) { inb = 1; n = 0; h = 0; next } inb = 0
      if (h) { for (i = 1; i <= n; i++) print B[i]; c++ } next }
    inb { B[++n] = $0; if (index($0, k)) h = 1 }
    END { exit (c == 1 ? 0 : 3) }' "$1" > "$3"
}
blk_check() { # blk_check <file>
  _BLK=""
  blk_cut "$1" '<working>' "$WORK/blk-wt.txt" || { _BLK="the working-tree check is not between fences exactly once"; return 3; }
  blk_cut "$1" '<skill-branch>' "$WORK/blk-rd.txt" || { _BLK="the remote-delete block is not between fences exactly once"; return 3; }
  cmp -s "$WORK/blk-wt.txt" "$BLK_WT" || { _BLK="the working-tree check differs from block-worktree-check.txt"; return 1; }
  cmp -s "$WORK/blk-rd.txt" "$BLK_RD" || { _BLK="the remote-delete block differs from block-remote-delete.txt"; return 1; }
  return 0
}

# R1, step 8's RETURN PROCEDURE bullet, ABANDON included (one unit). Negations are removed before each forbidden
# list runs, so "never remembered values", "never `-f`" and "no stash" do not read as the thing they forbid. The
# ORDER conjuncts compare first occurrences: fetch < working-tree check < checkout < ff-only, and the remote DELETE
# after (a)'s MERGED test and after the local tip gate, and never inside the ABANDON text.
r1_ok() { # r1_ok <file>
  rget "$1" "$A_R1" || return $?
  # (a): the two sources, and both STOPs of the post-merge form
  grep -qE '`<working>` is (its|the pr.s) `baserefname`' <<<"$_b" || return 1
  _nz="$(sed -E 's/(never|not|no) (a |an |the )?(remembered( values?)?|`@\{u\}`)//g' <<<"$_b")" || return 3
  grep -qE '@\{u\}|remember' <<<"$_nz" && return 1
  grep -qE '`<skill-branch>` is (its|the pr.s) `headrefname`' <<<"$_b" || return 1
  grep -qE 'stop, naming the state and the base, when the state is not `merged`' <<<"$_b" || return 1
  grep -qE 'when the state is not `merged` or when `<working>` matches step 1.s skill-branch grammar' <<<"$_b" || return 1
  # (b): the refspec fetch and its STOP
  grep -qF 'git fetch origin "+refs/heads/<working>:refs/remotes/origin/<working>"' <<<"$_b" || return 1
  grep -qF 'a failed fetch stops with its error' <<<"$_b" || return 1
  # (c): the NAMED working-tree check, its output contract, and the NUL-delimited block line by line
  grep -qF 'run the working-tree check, a named, self-contained block' <<<"$_b" || return 1
  grep -qF 'its output contract is that any output line is a stop' <<<"$_b" || return 1
  grep -qF -- '( cd "$(git rev-parse --show-toplevel)" || { echo "stop cannot cd to the repository toplevel"; exit; }' <<<"$_b" || return 1
  grep -qF -- 'git rev-parse -q --verify "refs/heads/<working>" >/dev/null && git diff -z --name-only --no-renames head <working>' <<<"$_b" || return 1
  grep -qF -- 'git rev-parse -q --verify "refs/remotes/origin/<working>" >/dev/null && git diff -z --name-only --no-renames head origin/<working>; } |' <<<"$_b" || return 1
  grep -qF -- 'sort -zu |' <<<"$_b" || return 1
  grep -qF -- "while ifs= read -r -d '' p; do" <<<"$_b" || return 1
  grep -qF -- 'if ! git diff --quiet head -- ":(literal)$p"; then echo "dirty $p"' <<<"$_b" || return 1
  grep -qF -- 'elif ! git cat-file -e "head:$p" 2>/dev/null && { [ -e "$p" ] || [ -l "$p" ]; }; then echo "on-disk $p"' <<<"$_b" || return 1
  # the remedy is split by tag: ON-DISK moves the file aside, DIRTY copies it and restores it
  grep -qE '`on-disk <path>`: move the file aside' <<<"$_b" || return 1
  grep -qF -- '`dirty <path>`: copy the file elsewhere, then run `git restore --staged --worktree -- <path>`' <<<"$_b" || return 1
  pos "$_b" 'git fetch origin "+refs/heads/'; _pf="$_P"
  pos "$_b" '( cd "$(git rev-parse --show-toplevel)"'; _pw="$_P"
  pos "$_b" '`git checkout <working>`'; _pc="$_P"
  pos "$_b" '`git merge --ff-only origin/<working>`'; _pm="$_P"
  [ "$_pc" -ge 0 ] && [ "$_pm" -ge 0 ] || return 1
  [ "$_pf" -lt "$_pw" ] && [ "$_pw" -lt "$_pc" ] && [ "$_pc" -lt "$_pm" ] || return 1
  # (d): the prohibitions are REQUIRED as well as their violations forbidden
  # scoped to the checkout clause, (d) up to (e): the block's "never stashes or forces" must not stand in for them
  _sd="${_b:$_pc:$((_pm - _pc))}"
  grep -qE '(never|no|not|without) (a |an )?`-f`' <<<"$_sd" || return 1
  grep -qE '(never|no|not|without) (a |an )?stash' <<<"$_sd" || return 1
  grep -qE '(never|no|not|without) `git switch --discard-changes`' <<<"$_sd" || return 1
  _nz="$(sed -E 's/(never|not|no|without) (a |an )?(`[^`]*`|stash(es)?|force[s]?)//g; s/never stashes or forces//g' <<<"$_b")" || return 3
  grep -qE 'stash|`-f`|checkout -f|--force|--discard-changes' <<<"$_nz" && return 1
  grep -qE 'refus[^.;]*stop' <<<"${_b:$_pc:$((_pm - _pc))}" || return 1
  # (e)
  grep -qE 'diverged remedy only (when|if) ahead (is above|is greater than|exceeds|>) 0' <<<"$_b" || return 1
  # (f): the local tip gate, CASE-SENSITIVE on `-D`, and its STOP
  _bc="$(unit_cs "$1" "$A_R1")" || return 3
  grep -qE 'git branch -D <skill-branch>` ONLY when `git rev-parse <skill-branch>` equals the PR.s `headRefOid`' <<<"$_bc" || return 1
  grep -qF 'otherwise stop naming it' <<<"$_b" || return 1
  # (f): the remote delete, its two REMOTE-KEPT cases, the 422-as-deleted test, and never a STOP
  grep -qF 'when the local branch is already gone, print `remote-kept <skill-branch>: no local branch to gate on` and delete nothing' <<<"$_b" || return 1
  # the remote-tip block: the lookup's own exit read first, a 404 silent and any other failure REMOTE-KEPT
  # unreadable, a moved tip REMOTE-KEPT, and only a match runs the DELETE, whose 422 counts as deleted
  grep -qF -- 'if ! gh api "repos/{owner}/{repo}/git/ref/heads/<skill-branch>" --jq .object.sha >"$o" 2>"$e"; then' <<<"$_b" || return 1
  grep -qF -- "grep -qf '(http 404)' \"\$e\" || echo \"remote-kept <skill-branch>: remote tip unreadable: \$(tail -1 \"\$e\")\"" <<<"$_b" || return 1
  grep -qF -- 'elif [ "$(cat "$o")" != "<headrefoid>" ]; then echo "remote-kept <skill-branch>: remote tip moved"' <<<"$_b" || return 1
  grep -qF -- 'elif ! gh api -x delete "repos/{owner}/{repo}/git/refs/heads/<skill-branch>" >/dev/null 2>"$e"; then' <<<"$_b" || return 1
  grep -qF -- "grep -qf 'reference does not exist' \"\$e\" || echo \"remote-delete-failed <skill-branch>: \$(tail -1 \"\$e\")\"" <<<"$_b" || return 1
  grep -qF '`remote-delete-failed` line is never silent and negfatal' <<<"$_b" || return 1
  pos "$_b" 'gh api -x delete "repos/{owner}/{repo}/git/refs/heads/<skill-branch>"'; _pdl="$_P"
  pos "$_b" 'when the state is not `merged`'; _pa="$_P"
  pos "$_b" 'git branch -d <skill-branch>` only when'; _pg="$_P"
  pos "$_b" "$A_ABANDON"; _pab="$_P"
  [ "$_pdl" -ge 0 ] && [ "$_pab" -ge 0 ] || return 1
  [ "$_pa" -lt "$_pdl" ] && [ "$_pg" -lt "$_pdl" ] && [ "$_pdl" -lt "$_pab" ] || return 1
  # ABANDON, defined once in this unit: without (a) or (f), and a failed fetch skips (b) and (e), never a STOP
  _ab="${_b:$_pab}"
  grep -qF 'gh api -x delete' <<<"$_ab" && return 1
  grep -qF 'it skips (a) and never runs (f)' <<<"$_ab" || return 1
  grep -qF "when (b)'s fetch fails, abandon reports the fetch error as a note, skips (b) and (e)" <<<"$_ab" || return 1
  grep -qF 'a failed fetch is never an abandon stop' <<<"$_ab" || return 1
  # the state-keyed no-op
  grep -qF 'no-op' <<<"$_b" || return 1
  grep -qF '"already on <working> at origin/<working>"' <<<"$_b" || return 1
  # LAST, so the per-line conjuncts above stay observed and name the broken line: the byte pin of the two
  # run-as-written blocks catches only what no per-line test can (an additive or reordering edit)
  blk_check "$1" || return $?
  return 0
}
# R2, step 2. The return bullet sits BEFORE the re-invoke bullet, merges with the literal `--delete-branch=false`
# command, runs the procedure, has a no-remote branch through ABANDON, opens the PR with `--base
# <original-branch>` and STOPs on another baseRefName, STOPs the re-invoke on a procedure STOP, and its not-merged
# STOP never says landed. The TRANSPORT and HOOK-REFUSED discard paragraphs cite ABANDON and say the checkout
# on the next line is its (d), run once.
r2_ok() { # r2_ok <file>
  _x="$(unit "$1" "$A_REINV")" || return 3
  rget "$1" "$A_R2" || return $?
  _all="$(units "$1")" || return 3
  uidx "$_all" "$A_R2"; _i2="$_I"; uidx "$_all" "$A_REINV"; _ir="$_I"
  [ "$_i2" -lt "$_ir" ] || return 1
  merge_ok "$_b" || return 1
  grep -qF "then run step 8's return procedure for that pr" <<<"$_b" || return 1
  grep -qF "with no remote configured there is no pr: run step 8's return procedure in its abandon form to \`<original-branch>\`" <<<"$_b" || return 1
  grep -qF -- '`git merge --ff-only <self-update-branch>`' <<<"$_b" || return 1
  grep -qF -- '`gh pr create --base <original-branch>`' <<<"$_b" || return 1
  grep -qE 'the return after the merge stops when the pr.s `baserefname` is not `<original-branch>`' <<<"$_b" || return 1
  grep -qE 'stop[^.]*stops the re-invoke' <<<"$_b" || return 1
  grep -qE 'not `?merged`?' <<<"$_b" || return 1
  _nz="$(sed -E 's/(never|not) that it landed//g' <<<"$_b")" || return 3
  grep -qF 'landed' <<<"$_nz" && return 1
  grep -qF 'do not re-invoke' <<<"$_b" || return 1
  for _an in "$A_DISCARD" "$A_HOOKREF"; do
    _d="$(unit "$1" "$_an")"; _r=$?; [ "$_r" -eq 4 ] && return 1; [ "$_r" -eq 0 ] || return 3
    grep -qF "make the next move as step 8's return procedure in its abandon form" <<<"$_d" || return 1
    grep -qF "the checkout on the next line is that form's (d), run once" <<<"$_d" || return 1
    grep -qF 'abandon stops and so does this invocation' <<<"$_d" || return 1
  done
  return 0
}
# R3, step 1's skill-branch bullet and its no-remote clause. The grammar is EXECUTED: the backticked
# `^ai-dlc-update/...` literal must match a reconcile, a self-update and an untangle cut, and must NOT match the
# operator-named near-miss nor a name that merely contains the prefix. The bullet must sit before BOTH AUTO-PUSH
# bullets (unit order). Four ordered tests, the OPEN STOP's own-branch continuation, the reflog derivation
# (oldest, fixed-string suffix, tail -1), and the no-remote STOP routed through ABANDON.
R3_YES='ai-dlc-update/0.1049.0-reconcile-20261111t100700z ai-dlc-update/self-update-20261111 ai-dlc-update/untangle-20261111'
R3_NO='ai-dlc-update/pc-update-deliver-no-return-20261111 feature/ai-dlc-update/self-update-20261111'
r3_ok() { # r3_ok <file>
  _x="$(unit "$1" "$A_NOUP")" || return 3
  _x="$(unit "$1" "$A_AHEAD")" || return 3
  rget "$1" "$A_R3" || return $?
  _all="$(units "$1")" || return 3
  uidx "$_all" "$A_R3"; _i3="$_I"; uidx "$_all" "$A_NOUP"; _in="$_I"; uidx "$_all" "$A_AHEAD"; _ia="$_I"
  [ "$_i3" -lt "$_in" ] && [ "$_i3" -lt "$_ia" ] || return 1
  _g="$(grep -oE '`\^ai-dlc-update/[^`]*`' <<<"$_b")" || return 1
  _g="${_g%%$'\n'*}"; _g="${_g//\`/}"
  for _nm in $R3_YES; do grep -qE -- "$_g" <<<"$_nm" || return 1; done
  for _nm in $R3_NO; do grep -qE -- "$_g" <<<"$_nm" && return 1; done
  grep -qF -- 'gh pr list --head <b> --state all --json number,state,baserefname,headrefoid,iscrossrepository' <<<"$_b" || return 1
  grep -qF -- '--state merged' <<<"$_b" && return 1
  grep -qE '\(1\)[^(]*`open`[^(]*stop' <<<"$_b" || return 1
  grep -qF 'merge or close it, then re-invoke from this branch' <<<"$_b" || return 1
  grep -qE '\(2\)[^(]*distinct `baserefname` set[^(]*exactly one branch[^(]*not match[^(]*skill-branch grammar' <<<"$_b" || return 1
  grep -qE '\(3\)[^(]*`git rev-parse head`[^(]*`headrefoid`' <<<"$_b" || return 1
  grep -qE "\\(4\\)[^(]*\`baserefname\` equals it; otherwise stop naming both" <<<"$_b" || return 1
  grep -qF "offer step 8's return procedure to that \`baserefname\` or its abandon form" <<<"$_b" || return 1
  grep -qE 'when \(2\) and \(3\) both hold and \(4\) passed' <<<"$_b" || return 1
  grep -qE 'return procedure[^()]*stop this invocation and re-invoke `/ai-dlc-update`' <<<"$_b" || return 1
  grep -qE '(anything else|any other (result|case|outcome)) \([^)]*\) is a stop' <<<"$_b" || return 1
  grep -qF '.claude/.ai-dlc-applying' <<<"$_b" || return 1
  # the one reflog derivation: the OLDEST line, matched as a fixed-string suffix, taken with tail -1
  grep -qF 'take the oldest line that begins with `checkout: moving from ` and ends with the fixed string ` to <skill-branch>`' <<<"$_b" || return 1
  grep -qF -- "git reflog --format=%gs | awk -v s=\" to <skill-branch>\" 'index(\$0, \"checkout: moving from \") == 1 && length(\$0) > length(s) && substr(\$0, length(\$0) - length(s) + 1) == s' | tail -1" <<<"$_b" || return 1
  # the no-remote clause: a skill branch STOPs, and its remedy moves through ABANDON
  _d="$(unit "$1" "$A_NOREM")"; _r=$?; [ "$_r" -eq 4 ] && return 1; [ "$_r" -eq 0 ] || return 3
  grep -qE 'on a skill branch[^.]*: stop, name the branch' <<<"$_d" || return 1
  grep -qF "local merge remedy: step 8's return procedure in its abandon form to \`<cut-from>\`" <<<"$_d" || return 1
  return 0
}
# R4, step 9's wording, step 8's named PR base with its skill-branch refusal, and step 8's literal merge.
r4_ok() { # r4_ok <file>
  rget "$1" "$A_R4B" || return $?
  _cz="$_b"
  rget "$1" "$A_R4M" || return $?
  _mz="$_b"
  rget "$1" "$A_R4A" || return $?
  grep -qF 'both literal `gh pr merge` commands pass `--delete-branch=false`' <<<"$_b" || return 1
  grep -qF 'only a tip the merge took' <<<"$_b" || return 1
  grep -qF -- '`gh pr create --base <cut-from>`' <<<"$_cz" || return 1
  grep -qF "derived from head's reflog exactly as step 1's skill-branch bullet states, never remembered" <<<"$_cz" || return 1
  grep -qF -- 'cut-from:' <<<"$_cz" && return 1
  grep -qE 'before any merge, refuses? to create the pr (when|if) `<cut-from>` matches[^.;]*skill-branch grammar' <<<"$_cz" || return 1
  merge_ok "$_mz" || return 1
  return 0
}
vector_r() { # vector_r <file> -> four digits, R1..R4
  r1_ok "$1"; q1=$?; r2_ok "$1"; q2=$?; r3_ok "$1"; q3=$?; r4_ok "$1"; q4=$?
  printf '%s%s%s%s' "$q1" "$q2" "$q3" "$q4"
}

# --- SELF-PROBE, BEFORE THE CORPUS, IN BOTH DIRECTIONS ------------------------------------
# On mktemp copies of the shipped seeds, so no probe reads the fixture directory in place.
P_OFF="$WORK/offender.md";  cp "$OFF" "$P_OFF"   || broken "could not copy the offender seed"
P_NEAR="$WORK/nearmiss.md"; cp "$NEAR" "$P_NEAR" || broken "could not copy the near-miss seed"

# Direction 0: the extractor locates each anchor exactly once in both seeds. The three added
# paragraphs' anchors are absent from the offender by construction (the pre-fix text has none
# of them), and that absence must read rc 4, not 3.
for f in "$P_OFF" "$P_NEAR"; do
  for a in "$A_NOUP" "$A_AHEAD" "$A_RECONF" "$A_DETECT" "$A_CYCLE"; do
    unit "$f" "$a" >/dev/null || broken "anchor '$a' did not select exactly one unit in $(basename "$f"); every direction below would be a false pass"
  done
done
for a in "$A_PARA" "$A_STEP2" "$A_DISCARD"; do
  unit "$P_NEAR" "$a" >/dev/null || broken "anchor '$a' did not select exactly one unit in the near-miss"
  unit "$P_OFF" "$a" >/dev/null; rc=$?
  [ "$rc" -eq 4 ] || broken "anchor '$a' returned rc $rc on the offender, not 4 (absent)"
done
ok "probe 0: every anchor selects exactly one unit in the near-miss; the five pre-existing anchors do in the offender, and the three added-paragraph anchors read absent there"

# Direction 0b: two anchors extract two different bodies (an extractor returning the whole
# list for every anchor would pass direction 0 and score every arm identically).
if [ "$(unit "$P_NEAR" "$A_PARA")" != "$(unit "$P_NEAR" "$A_STEP2")" ] &&
   [ "$(unit "$P_OFF" "$A_NOUP")" != "$(unit "$P_OFF" "$A_AHEAD")" ] &&
   [ "$(unit "$P_NEAR" "$A_CYCLE")" != "$(unit "$P_NEAR" "$A_DISCARD")" ]; then
  ok "probe 0b: adjacent anchors extract different bodies (bullets and paragraphs)"
else
  broken "two anchors extracted the same text; the extractor is not unit-scoped"
fi

# Direction 1 (REPORTS the offender): the pre-fix text scores a finding on all nine arms.
V_OFF="$(vector "$P_OFF")"
if [ "$V_OFF" = 111111111 ]; then
  ok "probe 1: the pre-fix text is flagged on all nine arms (vector $V_OFF)"
else
  bad "probe 1: the pre-fix text scored $V_OFF, not 111111111 — a predicate cannot see the defect it exists for"
fi

# Direction 2 (QUIET on the near-miss): a correct text sharing no sentence with the shipped
# fix. It says "does NOT stop the run" (a negated fatal verb), "refuse apply" where the fix
# says "STOP apply", "nothing is pushed" where the fix says "Do not push here", names the
# remedy command `git push -u origin <branch>` in step 6, and carries `git push` in the step-1
# bullets, so a predicate keyed on the old closed list, or leaking across units, fires here.
# Its cycle bullet keeps a no-remote "commit locally" beside the push-failure sentence, so
# arm 8 must tell the allowed path from the forbidden pairing; its discard paragraph says
# "only if" and "refuse, name the branch" where the fix says "only when" and "STOP and name".
V_NEAR="$(vector "$P_NEAR")"
if [ "$V_NEAR" = 000000000 ]; then
  ok "probe 2: a respelled correct text is quiet on all nine arms (not vocabulary-bound)"
else
  bad "probe 2: a respelled correct text scored $V_NEAR, not 000000000 — a predicate is keyed on a spelling or leaks across units"
fi

# Direction 3 (the list-scoped false finding): the BEHIND bullet DOES say STOP in the
# near-miss, and the ahead-only bullet beside it is still scored compliant.
B_BEHIND="$(unit "$P_NEAR" "$A_BEHIND")" || broken "the near-miss BEHIND bullet did not extract, so direction 3 tests nothing"
if grep -qE "$FATAL" <<<"$B_BEHIND"; then
  if push_fail_ok "$P_NEAR" "$A_AHEAD"; then
    ok "probe 3: the adjacent BEHIND bullet carries STOP and did not leak into the ahead-only verdict"
  else
    bad "probe 3: the ahead-only bullet was flagged by its STOP-carrying neighbour — the predicate is list-scoped"
  fi
else
  broken "the near-miss BEHIND bullet carries no STOP, so direction 3 tests nothing"
fi

# Direction 4: the near-miss really is wrapped — no anchor sits whole on one raw line — so
# direction 2 proved the join, not a lucky line layout.
_raw="$(LC_ALL=C tr 'A-Z' 'a-z' < "$P_NEAR" | LC_ALL=C tr -d '*')"
_w=0
for a in "$A_NOUP" "$A_AHEAD" "$A_RECONF" "$A_PARA" "$A_STEP2" "$A_DETECT" "$A_CYCLE" "$A_DISCARD"; do
  grep -qF -- "$a" <<<"$_raw" && _w=$((_w+1))
done
_c="$(grep -cF -- 'branch behind its upstream' <<<"$_raw")" || _c=0
if [ "$_w" -eq 0 ] && [ "$_c" -eq 1 ]; then
  ok "probe 4: all eight anchors are split across a line wrap in the near-miss (control: an unwrapped anchor reads 1)"
else
  broken "the near-miss is not wrapped as seeded (unwrapped anchors $_w, control $_c), so the join is unproven"
fi

# Direction 5: an anchor that selects no unit is rc 3 on the bullet arms, never the rc 0/1 of
# a verdict; and a duplicated paragraph anchor is rc 3 on the paragraph arms.
push_fail_ok "$P_OFF" 'no such bullet anywhere zq'; rc=$?
_dup="$WORK/dup.md"; cat "$P_NEAR" "$P_NEAR" > "$_dup"
step2_ok "$_dup"; rc2=$?
discard_ok "$_dup"; rc3=$?
if [ "$rc" -eq 3 ] && [ "$rc2" -eq 3 ] && [ "$rc3" -eq 3 ]; then
  ok "probe 5: an absent bullet anchor and a doubled paragraph anchor both return rc 3, told apart from a verdict"
else
  bad "probe 5: absent anchor rc $rc, doubled anchors rc $rc2/$rc3 — indistinguishable from a verdict"
fi

# Direction R (BL-986), on mktemp copies of the three return seeds, three distinct input SHAPES. The pre-fix text
# cut from e3d2dfc35 (every unit ABSENT) must be flagged on all four arms; the respelled near-miss must be quiet on
# all four; the PRESENT-BUT-WRONG seed (every unit present, one clause per arm altered) must be flagged on all four
# with every anchor still selecting exactly one unit, so a predicate that only asks "is the unit there" cannot pass
# it; and the near-miss must really be wrapped (no R anchor whole on one raw line), with an unwrapped control.
P_ROFF="$WORK/return-offender.md";  cp "$ROFF" "$P_ROFF"   || broken "could not copy the return offender seed"
P_RNEAR="$WORK/return-nearmiss.md"; cp "$RNEAR" "$P_RNEAR" || broken "could not copy the return near-miss seed"
P_RWRONG="$WORK/return-wrong.md";   cp "$RWRONG" "$P_RWRONG" || broken "could not copy the return present-but-wrong seed"
R_UNITS="$A_R1|$A_R2|$A_REINV|$A_R3|$A_R4A|$A_R4B|$A_R4M|$A_NOREM|$A_DISCARD|$A_HOOKREF|$A_NOUP|$A_AHEAD"
_oifs="$IFS"; IFS='|'
for a in $R_UNITS; do
  unit "$P_RNEAR" "$a" >/dev/null || broken "anchor '$a' did not select exactly one unit in return-nearmiss.md"
  unit "$P_RWRONG" "$a" >/dev/null || broken "anchor '$a' did not select exactly one unit in return-wrong.md, so it is not a present-but-wrong seed"
done
IFS="$_oifs"
VR_OFF="$(vector_r "$P_ROFF")"
if [ "$VR_OFF" = 1111 ]; then
  ok "probe R1: the pre-fix return text (e3d2dfc35) is flagged on all four return arms (vector $VR_OFF)"
else
  bad "probe R1: the pre-fix return text scored $VR_OFF, not 1111 -- a return arm cannot see the defect it exists for"
fi
VR_NEAR="$(vector_r "$P_RNEAR")"
if [ "$VR_NEAR" = 0000 ]; then
  ok "probe R2: a respelled, wrapped correct return text is quiet on all four return arms"
else
  bad "probe R2: a respelled correct return text scored $VR_NEAR, not 0000 -- a return arm is keyed on a spelling or leaks across units"
fi
VR_WRONG="$(vector_r "$P_RWRONG")"
if [ "$VR_WRONG" = 1111 ]; then
  ok "probe R4: a present-but-wrong return text (every unit present, one clause per arm altered) is flagged on all four return arms"
else
  bad "probe R4: the present-but-wrong return text scored $VR_WRONG, not 1111 -- an arm reads presence, not the clause"
fi
_raw="$(LC_ALL=C tr 'A-Z' 'a-z' < "$P_RNEAR" | LC_ALL=C tr -d '*')"
_w=0
_oifs="$IFS"; IFS='|'
for a in $R_UNITS; do
  case "$a" in "$A_NOUP"|"$A_AHEAD") continue ;; esac
  grep -qF -- "$a" <<<"$_raw" && _w=$((_w+1))
done
IFS="$_oifs"
_c="$(grep -cF -- 'branch ahead of its upstream' <<<"$_raw")" || _c=0
if [ "$_w" -eq 0 ] && [ "$_c" -eq 1 ]; then
  ok "probe R3: all ten return anchors are split across a line wrap in the return near-miss (control: an unwrapped anchor reads 1)"
else
  broken "the return near-miss is not wrapped as seeded (unwrapped anchors $_w, control $_c), so the join is unproven"
fi

# --- THE CORPUS ---------------------------------------------------------------------------
echo "  ..    subject: $SUBJ"

# BL-391's three arms (7-9) and its mutant rows arrive in the same pull as the text they read,
# but a consumer's installed SKILL.md may predate it. In a CONSUMER layout with no discard
# paragraph those arms SKIP, print no `ok`, and the six older arms and their mutants still run
# with the pre-BL-391 step-6 anchor. In the DISTRIBUTION they always run, so deleting the
# paragraph here goes red rather than skipping.
# The layout is WHICH candidate resolved, not a pattern on the path: $SUBJ keeps the `..`
# segments it was built from, so a `*/core/skills/...` glob never matches it.
ISDIST=0; [ "$SUBJ" = "$HERE/../../skills/ai-dlc-update/SKILL.md" ] && ISDIST=1
unit "$SUBJ" "$A_DISCARD" >/dev/null; _dr=$?
if [ "$_dr" -eq 4 ] && [ "$ISDIST" = 0 ]; then
  B391=0
  printf '  SKIP  BL-391 arms 7-9 -- the installed SKILL.md predates the step-2 discard paragraph; they land with the pull that carries it\n'
fi
LAYOUT_B391="$B391"   # the installed layout, before any single row lowers B391 for itself
V_SUBJ="$(vector "$SUBJ")"
arm() { # arm <digit> <ok text> <fail text> <arm name>
  case "$1" in
    0) ok "$2"
       case "$4" in
         noup) B_noup=1 ;; ahead) B_ahead=1 ;; nopush) B_nopush=1 ;; refuse) B_refuse=1 ;; para) B_para=1 ;;
         step2) B_step2=1 ;; detect) B_detect=1 ;; cycle) B_cycle=1 ;; discard) B_discard=1 ;;
         r1) B_r1=1 ;; r2) B_r2=1 ;; r3) B_r3=1 ;; r4) B_r4=1 ;;
       esac ;;
    3) bad "FIXTURE STALE: an anchor did not select exactly one unit in $SUBJ — the text moved or was renamed" ;;
    *) bad "$3" ;;
  esac
}
arm "$(printf '%s' "$V_SUBJ" | cut -c1)" \
  "step 1 no-upstream AUTO-PUSH: a failed push is non-fatal, continues, and marks the branch UN-SYNCED" \
  "step 1 no-upstream AUTO-PUSH: the push-failure path is fatal, or no longer says non-fatal + continue + UN-SYNCED" "noup"
arm "$(printf '%s' "$V_SUBJ" | cut -c2)" \
  "step 1 ahead-only AUTO-PUSH: a rejected or failed push is non-fatal, continues, and marks the branch UN-SYNCED" \
  "step 1 ahead-only AUTO-PUSH: the push-failure path is fatal, or no longer says non-fatal + continue + UN-SYNCED" "ahead"
arm "$(printf '%s' "$V_SUBJ" | cut -c3)" \
  "step 6 re-confirm: carries the no-push sentence and no push instruction" \
  "step 6 re-confirm: instructs a push, or lost its no-push sentence — a write to origin from inside the isolation step" "nopush"
arm "$(printf '%s' "$V_SUBJ" | cut -c4)" \
  "step 6 re-confirm: stops apply on an UN-SYNCED branch" \
  "step 6 re-confirm: no longer refuses apply on an UN-SYNCED branch" "refuse"
arm "$(printf '%s' "$V_SUBJ" | cut -c5)" \
  "step 1 UN-SYNCED paragraph: proceeds to the dry-run, names step 2's defer, does not end the run" \
  "step 1 UN-SYNCED paragraph: absent, ends the run, or no longer sends the branch to the dry-run with step 2 deferred" "para"
arm "$(printf '%s' "$V_SUBJ" | cut -c6)" \
  "step 2 UN-SYNCED paragraph: step 2 defers, and nothing in it pushes or commits locally" \
  "step 2 UN-SYNCED paragraph: absent, does not defer, or pushes / commits locally — the orphaned self-update branch" "step2"
if [ "$B391" = 1 ]; then
arm "$(printf '%s' "$V_SUBJ" | cut -c7)" \
  "step 1 detect paragraph: claims no clean-tree check, says step 1 does not check the working tree, names step 6" \
  "step 1 detect paragraph: claims a clean tree step 1 never checks, or no longer says where a dirty tree is refused" "detect"
arm "$(printf '%s' "$V_SUBJ" | cut -c8)" \
  "step 2 cycle bullet: names the push-failure case and pairs no failed push with a local commit" \
  "step 2 cycle bullet: a failed push commits locally, or the push-failure case vanished from the bullet" "cycle"
arm "$(printf '%s' "$V_SUBJ" | cut -c9)" \
  "step 2 discard paragraph: pathspec staging, checkout original, file-list check gating the delete, STOP naming the branch, DEFER, UN-SYNCED, stamp unmoved" \
  "step 2 discard paragraph: absent, keeps a local commit, or lost a conjunct of the discard procedure" "discard"
fi

# BL-986's four arms. The SKIP is keyed on ALL the R anchors: in a CONSUMER layout whose installed SKILL.md carries
# NONE of them, R1-R4 and their mutants SKIP and print no `ok`. A partial set (some present, some absent) is a FAIL,
# never a SKIP, and in the DISTRIBUTION they always run, so deleting any R unit there is a FAIL.
RFIX=1
_rpresent=0
for _ra in $R_ANCHORS; do
  eval "_rv=\"\$$_ra\""
  unit "$SUBJ" "$_rv" >/dev/null; [ "$?" -eq 4 ] || _rpresent=$((_rpresent + 1))
done
if [ "$_rpresent" -eq 0 ] && [ "$ISDIST" = 0 ]; then
  RFIX=0
  printf '  SKIP  BL-986 arms R1-R4 -- the installed SKILL.md predates the step-8 RETURN PROCEDURE; they land with the pull that carries it\n'
fi
if [ "$RFIX" = 1 ]; then
  VR_SUBJ="$(vector_r "$SUBJ")"
  arm "${VR_SUBJ:0:1}" \
    "R1 step 8 RETURN PROCEDURE: (a) baseRefName/headRefName and its not-MERGED and skill-branch-base STOPs, +refspec fetch and its STOP, the named NUL-delimited working-tree check with both ref guards, :(literal) DIRTY and ON-DISK, a remedy split by tag, checkout with no -f or stash, ff-only, ahead-gated remedy, case-sensitive branch -D tip gate, the remote delete only after MERGED and the gate with REMOTE-KEPT/422/REMOTE-DELETE-FAILED, ABANDON without (a) or (f), state-keyed no-op" \
    "R1 step 8 RETURN PROCEDURE: absent, or lost a conjunct of (a)-(f), the working-tree check, the remote delete and its order, or the ABANDON form" "r1"
  # name the run-as-written block when one of the two is what failed R1
  if [ "${VR_SUBJ:0:1}" != 0 ]; then
    blk_check "$SUBJ"; _rbk=$?
    if [ "$_rbk" -eq 1 ]; then bad "R1 run-as-written block: $_BLK, byte for byte"
    elif [ "$_rbk" -eq 3 ]; then bad "FIXTURE STALE: $_BLK in $SUBJ"; fi
  fi
  arm "${VR_SUBJ:1:1}" \
    "R2 step 2: return bullet before the re-invoke, merge with --delete-branch=false, RETURN PROCEDURE, no-remote through ABANDON, --base <original-branch> with its baseRefName STOP, a STOP that stops the re-invoke, a not-merged STOP that never says landed, and both discard paragraphs citing ABANDON's (d) run once" \
    "R2 step 2: absent, after the re-invoke, a bare --delete-branch, or lost the procedure, the ABANDON no-remote branch, --base, the baseRefName STOP, the STOP-stops-re-invoke, the not-merged STOP or a discard citation" "r2"
  arm "${VR_SUBJ:2:1}" \
    "R3 step 1 skill-branch bullet: grammar matches the three skill cuts and rejects the operator-named near-miss, sits before both AUTO-PUSH bullets, one --state all classifier, four ordered tests with the tip gate and the reflog-base test, own-branch OPEN STOP, re-invoke after the return, else-STOP checks .claude/.ai-dlc-applying, the one oldest fixed-suffix reflog derivation, and the no-remote STOP through ABANDON" \
    "R3 step 1 skill-branch bullet: absent, after an AUTO-PUSH bullet, a grammar that misses a skill cut or matches the near-miss, keyed on --state merged, or lost a test, the tip gate, test (4), the re-invoke, the applying check, the reflog derivation or the ABANDON no-remote remedy" "r3"
  arm "${VR_SUBJ:3:1}" \
    "R4 step 9 wording (both merges pass --delete-branch=false, the only move onto a working branch, delete only a tip the merge took), step 8 gh pr create --base <cut-from> from the reflog refusing a skill-branch base before any merge, and step 8's literal merge with --delete-branch=false" \
    "R4 step 9 wording, step 8's named PR base or step 8's literal merge: absent, or lost a conjunct" "r4"
fi

# --- MUTANTS, EACH MUST FAIL ONLY ITS OWN ARM ---------------------------------------------
# Built as copies of the RESOLVED subject. The replace is a literal whole-line substitution
# that counts its matches: exactly one, or the mutant DID NOT APPLY and the fixture is stale.
mutate() { # mutate <src> <dst> <old line> <new line>
  LC_ALL=C awk -v o="$3" -v n="$4" '
    $0 == o { print n; c++; next } { print } END { exit (c == 1 ? 0 : 3) }
  ' "$1" > "$2"
}
M0="$WORK/control.md"; cp "$SUBJ" "$M0" || broken "could not copy the subject for the unmutated control"

# scope|name|old line|new line|want vector. scope: `all` runs on every subject, `post` only
# where BL-391's text is present (always in the distribution), `pre` only where it is not. awk -v strips one level of backslash escaping; no line
# below carries a backslash. wrong2 KEEPS the no-push sentence and adds a push instruction
# (the forbidden list alone kills it); wC deletes the sentence AND adds a push (the adversary's
# variant); wG deletes the sentence and adds nothing (the required phrase alone kills it).
# wH, wI, wJ and wK carry no forbidden word and remove one REQUIRED phrase each (continue,
# non-fatal, to the dry-run, the step-2 clause's defer), so each positive conjunct is shown
# load-bearing on its own. The paragraph's "defer" conjunct has no single-line mutant: the
# word sits on three lines of that paragraph.
#
# BL-391's rows: wY drops step 2 as a source of the step-6 refusal; wL restores the false
# clean-tree claim and wM drops the statement that step 1 does not check the tree; wN pairs a
# failed push with a local commit and wO deletes the push-failure case outright (the wrong fix
# that deletes the sentence); wW..wV each remove ONE conjunct of the discard procedure
# (pathspec staging, no local commit, checkout of the original branch, the file-list check,
# the condition on the delete, the STOP naming the branch, the DEFER, the UN-SYNCED marking,
# the stamp left in place), so every required phrase is shown load-bearing alone.
MUTANTS="all|wrong1|     NOT fatal**: report the \`git push\` error in one line, mark the branch|     NOT fatal**: report the \`git push\` error in one line and STOP the run, mark the branch|010000000
all|wA-halt|     **UN-SYNCED** for this invocation, and continue. A rejection because the|     **UN-SYNCED** for this invocation, and halt the run. A rejection because the|010000000
all|wrong2|     its upstream. **Do not push here, ever.** Time may have passed since the|     its upstream. **Do not push here, ever.** If it drifted AHEAD, **auto-push** to re-sync. Time may have passed since the|001000000
all|wC-push|     its upstream. **Do not push here, ever.** Time may have passed since the|     its upstream. If it drifted AHEAD, push it to re-sync as step 1 does and continue. Time may have passed since the|001000000
all|wG-nosentence|     its upstream. **Do not push here, ever.** Time may have passed since the|     its upstream. Time may have passed since the|001000000
post|wD-negate|     upstream-less — or step 1 or step 2 left it UN-SYNCED on this invocation, **STOP|     upstream-less — or step 1 or step 2 left it UN-SYNCED on this invocation, do **not STOP|000100000
pre|wD-negate-pre|     upstream-less — or step 1 left it UN-SYNCED on this invocation, **STOP|     upstream-less — or step 1 left it UN-SYNCED on this invocation, do **not STOP|000100000
all|wF-para|   proceeds to the dry-run only.** Step 2 DEFERS on it: it cuts no self-update|   ends the run here.** Step 2 DEFERS on it: it cuts no self-update|000010000
all|wE-step2|   **On a branch step 1 left UN-SYNCED, step 2 DEFERS a non-empty slice, before the gate.**|   **On a branch step 1 left UN-SYNCED, step 2 pushes anyway, before the gate.**|000001000
all|wH-nocontinue|     **UN-SYNCED** for this invocation, and continue — see the UN-SYNCED paragraph|     **UN-SYNCED** for this invocation, and re-invoke — see the UN-SYNCED paragraph|100000000
all|wI-nononfatal|     push is NOT fatal** (auth, network, protected branch, remote rejected): report|     push is reported** (auth, network, protected branch, remote rejected): report|100000000
all|wJ-nodryrun|   proceeds to the dry-run only.** Step 2 DEFERS on it: it cuts no self-update|   proceeds to the report only.** Step 2 DEFERS on it: it cuts no self-update|000010000
all|wK-nodefer|   **On a branch step 1 left UN-SYNCED, step 2 DEFERS a non-empty slice, before the gate.**|   **On a branch step 1 left UN-SYNCED, step 2 handles a non-empty slice, before the gate.**|000001000
post|wY-nostep2|     upstream-less — or step 1 or step 2 left it UN-SYNCED on this invocation, **STOP|     upstream-less — or step 1 left it UN-SYNCED on this invocation, **STOP|000100000
post|wL-cleanclaim|   operator knows what to run, then re-invoke. A branch in sync with its|   operator knows what to run, then re-invoke. A clean tree on a branch in sync with its|000000100
post|wM-nocheckline|   proceeds to step 2's push or to \`apply\`. **Step 1 does not check the working|   proceeds to step 2's push or to \`apply\`. **Step 1 reads the working|000000100
post|wN-failcommit|     note it. A push that fails is the next paragraph's case and never ends in a kept commit.|     note it. If the push fails, commit locally and note it.|000000010
post|wO-nofailcase|     note it. A push that fails is the next paragraph's case and never ends in a kept commit.|     note it.|000000010
post|wW-nopathspec|     each named by explicit pathspec:|     each named:|000000001
post|wX-keepcommit|     line and the push error above it in one line;|     line and the push error above it in one line, and commit locally;|000000001
post|wP-nocheckout|     run \`git checkout <original-branch>\`, the branch step 1 confirmed in sync;|     run \`git status\`, the branch step 1 confirmed in sync;|000000001
post|wQ-nofilelist|     list every file the self-update branch's commits touch with \`git diff --name-only <original-branch> <self-update-branch>\`;|     list every file the self-update branch's commits touch;|000000001
post|wR-uncondelete|     only when every listed path is in the written set above, delete it with \`git branch -D <self-update-branch>\`.|     delete it with \`git branch -D <self-update-branch>\`.|000000001
post|wS-nostop|     If any path falls outside that set, do NOT delete it: STOP and name the branch,|     If any path falls outside that set, delete it anyway,|000000001
post|wT-nodefer|     report that step 2 DEFERRED because its push failed,|     report that step 2 finished,|000000001
post|wU-nounsynced|     and mark the branch UN-SYNCED for this invocation exactly as a failed step-1 push does:|     and continue exactly as a failed step-1 push does:|000000001
post|wV-stampmoves|     \`skill_version\`/\`skill_commit\` stay where they were, because the stamp rewrite lived only on the discarded commit.|     \`skill_version\`/\`skill_commit\` advance to theirs.|000000001"

mut_ok=1
kills=0
_n=0
_want_n=27; [ "$B391" = 1 ] || _want_n=12

# ---- matrix plumbing. The header rows are the only source of a mutant's deciding arm and twin. ----
# MXL is the rule-9 ledger: a deciding or twin cell appends "dec", a matrix-only cell appends "mx".
MXL="$WORK/mx.ledger"; : > "$MXL"
ARMS="noup ahead nopush refuse para step2 detect cycle discard r1 r2 r3 r4"
mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  awk -v n="$1" -v f="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n {
      c++; for (i = 4; i <= NF; i++) if (index($i, f "=") == 1) v = substr($i, length(f) + 2)
    }
    END { if (c == 1) print v }' "$HERE/run.sh"
}
mx_count() { local n; n="$(grep -c "^$1 " "$MXL")" || n=0; printf '%s' "$n"; }
# cell_rc <arm> <file> -> that one arm's predicate: 0 compliant (GREEN), 1 finding (RED), 3 unit not located.
cell_rc() {
  case "$1" in
    noup)    push_fail_ok "$2" "$A_NOUP" ;;
    ahead)   push_fail_ok "$2" "$A_AHEAD" ;;
    nopush)  reconf_nopush_ok "$2" ;;
    refuse)  reconf_refuse_ok "$2" ;;
    para)    para_ok "$2" ;;
    step2)   step2_ok "$2" ;;
    detect)  detect_ok "$2" ;;
    cycle)   cycle_ok "$2" ;;
    discard) discard_ok "$2" ;;
    r1)      r1_ok "$2" ;;
    r2)      r2_ok "$2" ;;
    r3)      r3_ok "$2" ;;
    r4)      r4_ok "$2" ;;
    *) return 9 ;;
  esac
}
# score_row <base-pass flag> <mutant> <deciding arm> <twin arm> <want vector> <mutant file> -- the deciding arm and
# the twin per push, every other arm under --matrix.
score_row() {
  local fl="$1" m="$2" dec="$3" tw="$4" want="$5" f="$6" r a g=0 tot=0 u="" d t
  printf 'dec %s %s\ndec %s %s\n' "$m" "$dec" "$m" "$tw" >> "$MXL"
  cell_rc "$dec" "$f"; r=$?; d=GREEN
  if [ "$r" -eq 3 ]; then bad "FIXTURE STALE: an anchor of arm $dec did not select exactly one unit in the mutant $m"
  elif [ "$r" -eq 1 ]; then
    d=RED
    if mutant_killed "$fl" "$m" "mutant $m scored by its deciding arm $dec"; then kills=$((kills+1)); fi
  else bad "mutant $m SURVIVED: its deciding arm $dec still passed"; fi
  cell_rc "$tw" "$f"; r=$?; t=GREEN
  if [ "$r" -eq 1 ]; then t=RED; bad "mutant $m is entangled: its twin arm $tw also failed"
  elif [ "$r" -ne 0 ]; then bad "FIXTURE STALE: an anchor of twin arm $tw did not select exactly one unit in the mutant $m"; fi
  if [ "$MODE" = matrix ]; then # mx-all-cells
    local k=0
    for a in $ARMS; do
      k=$((k + 1))
      if [ "$a" = "$dec" ] || [ "$a" = "$tw" ]; then continue; fi
      if [ "$LAYOUT_B391" != 1 ] && [ "$k" -gt 6 ]; then continue; fi
      if [ "$RFIX" != 1 ] && [ "$k" -gt 9 ]; then continue; fi
      printf 'mx %s %s\n' "$m" "$a" >> "$MXL"
      tot=$((tot + 1)); cell_rc "$a" "$f"; r=$?
      if [ "$r" -eq 0 ]; then g=$((g + 1)); elif [ "$r" -ne 1 ]; then echo "MATRIX BROKEN $m"; exit 2; fi
    done
    if [ "$d" = GREEN ]; then u=" UNEXPECTED=$dec:GREEN"; fi
    if [ "$t" = RED ]; then u="$u UNEXPECTED=$tw:RED"; fi
    printf 'MATRIX %s decides=%s:%s twins=%s:%s others=%d/%d%s\n' "$m" "$dec" "$d" "$tw" "$t" "$g" "$tot" "$u"
  fi
}
# THE PRE-BL-391 COPY, built in BOTH modes. In the distribution it is the subject with the step-6 clause reverted to
# its pre-BL-391 spelling (the wY mutation's own line pair); in a consumer whose installed text predates BL-391 the
# subject already is that text. Its unmutated control must pass with the BL-391 conjunct off, or the copy is not sound.
PRE="$WORK/pre-bl391.md"
PRE_OLD='     upstream-less — or step 1 or step 2 left it UN-SYNCED on this invocation, **STOP'
PRE_NEW='     upstream-less — or step 1 left it UN-SYNCED on this invocation, **STOP'
if [ "$B391" = 1 ]; then
  if ! mutate "$SUBJ" "$PRE" "$PRE_OLD" "$PRE_NEW" || cmp -s "$SUBJ" "$PRE"; then
    bad "FIXTURE STALE: the pre-BL-391 copy did not build -- its anchor line is not in $SUBJ exactly once"
  fi
else
  cp "$SUBJ" "$PRE" || broken "could not copy the subject as the pre-BL-391 copy"
fi
_k391="$B391"; B391=0
cell_rc refuse "$PRE"; _pr1=$?; cell_rc nopush "$PRE"; _pr2=$?
B391="$_k391"
if [ -s "$PRE" ] && [ "$_pr1" -eq 0 ] && [ "$_pr2" -eq 0 ]; then
  ok "control: the unmutated pre-BL-391 copy passes the refuse and no-push arms with the BL-391 conjunct off"; B_refpre=1
else
  bad "control: the unmutated pre-BL-391 copy did not pass refuse/no-push (rc $_pr1/$_pr2) -- wD-negate-pre proves nothing"
fi
while IFS='|' read -r mscope mname mold mnew mwant; do
  [ -n "$mname" ] || continue
  case "$mscope:$B391" in all:*|post:1|pre:*) ;; *) continue ;; esac
  _n=$((_n+1))
  mf="$WORK/mut-$mname.md"
  msrc="$SUBJ"; if [ "$mscope" = pre ]; then msrc="$PRE"; fi
  if ! mutate "$msrc" "$mf" "$mold" "$mnew" || cmp -s "$msrc" "$mf"; then
    bad "mutant $mname DID NOT APPLY — its anchor line is not in $msrc exactly once"; mut_ok=0; continue
  fi
  # The table's one `1` digit names the deciding arm; the header row must agree, so the two cannot drift apart.
  mdec=""; mi=0
  for _a in $ARMS; do
    mi=$((mi+1))
    if [ "$(printf '%s' "$mwant" | cut -c"$mi")" = 1 ]; then mdec="$_a"; fi
  done
  hdec="$(mx_row "$mname" decides)"; htw="$(mx_row "$mname" twins)"
  if [ -z "$hdec" ] || [ -z "$htw" ] || [ "$hdec" != "$mdec" ]; then
    bad "FIXTURE BROKEN: mutant $mname has no single MUTANT-MATRIX row, or its decides=${hdec:-?} disagrees with the table's deciding arm ${mdec:-?}"; continue
  fi
  _k391="$B391"; if [ "$mscope" = pre ]; then B391=0; fi
  case "$mscope:$hdec" in
    pre:refuse) { score_row "${B_refpre:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *:noup)    { score_row "${B_noup:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *:ahead)   { score_row "${B_ahead:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *:nopush)  { score_row "${B_nopush:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *:refuse)  { score_row "${B_refuse:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *:para)    { score_row "${B_para:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *:step2)   score_row "${B_step2:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf" ;;
    *:detect)  { score_row "${B_detect:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *:cycle)   { score_row "${B_cycle:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *:discard) { score_row "${B_discard:-0}" "$mname" "$hdec" "$htw" "$mwant" "$mf"; } ;;
    *) bad "FIXTURE BROKEN: mutant $mname names an arm $hdec that is not one of the nine" ;;
  esac
  B391="$_k391"
done <<<"$MUTANTS"
[ "$_n" -eq "$_want_n" ] || bad "the mutant table parsed $_n rows in scope, not $_want_n"

# Control for the mutator itself: an anchor that is nowhere must refuse, not pass through.
if mutate "$SUBJ" "$WORK/nomatch.md" 'zq no such line anywhere zq' 'x'; then
  bad "the mutator reported success on an anchor that matches nothing — every DID-NOT-APPLY guard above is vacuous"
fi

# Unmutated control, with a POSITIVE conjunct: the copy scores 000000000 (every unit located and
# compliant) and the kill count is the table size, so a harness that ran nothing cannot pass.
V0="$(vector "$M0")"
[ "$B391" = 1 ] || V0="$(printf '%s' "$V0" | cut -c1-6)000"
if [ "$V0" = 000000000 ] && [ "$kills" -eq "$_n" ]; then
  ok "control: the unmutated copy scores 000000000 through the mutant harness, and $kills of $_n mutants were scored"
else
  bad "control: the unmutated copy scored $V0 with $kills of $_n scored mutants — the mutant verdicts above mean nothing"
fi

# --- BL-986 MUTANTS, EACH MUST FAIL ONLY ITS OWN R ARM -------------------------------------
# mutate_r <src> <dst> <old line> <new line> [<previous line>]: a whole-line literal replace read through ENVIRON
# (no escape processing, so the grammar line's backslashes survive), exactly one match or rc 3. A fifth argument
# also requires the line before the match to equal it, for a line the file carries twice. A new line spelled
# `>>after:<line>` instead MOVES the whole unit headed by <old line> to just after the unit headed by <line>.
mutate_r() {
  MO="$3" MN="$4" MP="${5:-}" LC_ALL=C awk '
    BEGIN { o = ENVIRON["MO"]; n = ENVIRON["MN"]; p = ENVIRON["MP"]; mv = (index(n, ">>after:") == 1); if (mv) t = substr(n, 9) }
    { L[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (L[i] == o && (p == "" || (i > 1 && L[i-1] == p))) { c++; s = i }
        if (mv && L[i] == t) { tc++; ti = i }
      }
      if (c != 1 || (mv && tc != 1)) exit 3
      if (!mv) { for (i = 1; i <= NR; i++) print (i == s ? n : L[i]); exit 0 }
      e = s;  while (e < NR && L[e+1] ~ /^[ \t]+[^ \t]/ && L[e+1] !~ /^[ \t]*- /) e++
      te = ti; while (te < NR && L[te+1] ~ /^[ \t]+[^ \t]/ && L[te+1] !~ /^[ \t]*- /) te++
      if (ti >= s && ti <= e) exit 3
      for (i = 1; i <= NR; i++) {
        if (i >= s && i <= e) continue
        print L[i]
        if (i == te) for (k = s; k <= e; k++) print L[k]
      }
    }' "$1" > "$2"
}
# name~old line~new line~want (R1..R4)~[previous line]. `~` separates: the grammar line carries `|` and the block and reflog lines `%`.
RTABLE=""
IFS= read -r -d '' RTABLE <<'RTABLE_EOF' || :
r1-upstream~     `gh pr view <n> --json state,baseRefName,headRefName,headRefOid`. `<working>` is its~     `gh pr view <n> --json state,baseRefName,headRefName,headRefOid`. `<working>` is `@{u}`, not its~1000
r1-memory~     `baseRefName` and `<skill-branch>` is its `headRefName`, never remembered values, and a~     `baseRefName` and `<skill-branch>` is its `headRefName`, or the values remembered earlier, and a~1000
r1-headref~     `baseRefName` and `<skill-branch>` is its `headRefName`, never remembered values, and a~     `baseRefName` and `<skill-branch>` is the current branch, never remembered values, and a~1000
r1-noplus~     `git fetch origin "+refs/heads/<working>:refs/remotes/origin/<working>"`; a failed fetch~     `git fetch origin "refs/heads/<working>:refs/remotes/origin/<working>"`; a failed fetch~1000
r1-checkoutfirst~     grammar. (b) Run~     grammar. Run `git checkout <working>` at once. (b) Run~1000
r1-force~     `git checkout <working>`: never `-f`, never a stash, never~     `git checkout <working>`, adding `-f` if it refuses: never a stash, never~1000
r1-stash~     `git checkout <working>`: never `-f`, never a stash, never~     `git stash` first, then `git checkout <working>`: never `-f`, never~1000
r1-discard~     `git checkout <working>`: never `-f`, never a stash, never~     `git checkout <working>` (with `--discard-changes` if it refuses): never `-f`, never a stash, never~1000
r1-nonegf~     `git checkout <working>`: never `-f`, never a stash, never~     `git checkout <working>`: never a stash, never~1000
r1-nonegstash~     `git checkout <working>`: never `-f`, never a stash, never~     `git checkout <working>`: never `-f`, never~1000
r1-nonegdiscard~     `git switch --discard-changes`. On a refusal, STOP with git's error verbatim and the~     `git switch` either. On a refusal, STOP with git's error verbatim and the~1000
r1-norefusal~     `git switch --discard-changes`. On a refusal, STOP with git's error verbatim and the~     `git switch --discard-changes`. On a refusal, retry with git's error verbatim and the~1000
r1-noffonly~     lost. (e) Run `git merge --ff-only origin/<working>`. On a refusal, STOP with git's~     lost. (e) Run `git merge origin/<working>`. On a refusal, STOP with git's~1000
r1-remedyalways~     ahead), and add step 1's diverged remedy only when ahead is above 0. (f) When the local~     ahead), and add step 1's diverged remedy. (f) When the local~1000
r1-ungated~     skill branch still exists, delete it with `git branch -D <skill-branch>` ONLY when~     skill branch still exists, delete it with `git branch -D <skill-branch>`, and log whether~1000
r1-noop~     already switched and pulled is a no-op that reports "already on <working> at~     already switched and pulled runs every clause again and reports "done on <working> at~1000
r2-stopreinvoke~     from the procedure stops the re-invoke too: report that the self-update merged but the~     from the procedure is reported and the re-invoke runs anyway: report that the self-update merged but the~0100
r2-landed~     never that it landed, and do not re-invoke.~     and report that it landed, and do not re-invoke.~0100
r2-notmergedreinvoke~     never that it landed, and do not re-invoke.~     never that it landed, and re-invoke anyway.~0100
r2-afterreinvoke~   - **After the auto-merge, return the checkout before the re-invoke.** The auto-merge is~>>after:   - **Then STOP this invocation and re-invoke `/ai-dlc-update` automatically —~0100
r3-widegrammar~     `^ai-dlc-update/([0-9]+\.[0-9]+\.[0-9]+-reconcile-|self-update-|untangle-)`, the three~     `^ai-dlc-update/[a-z0-9.-]+`, the three~0010
r3-afterautopush~   - **Current branch is a skill branch** — a name matching~>>after:   - **Branch AHEAD of its upstream** (unpushed commits) → **AUTO-PUSH**: run~0010
r3-mergedonly~     `gh pr list --head <b> --state all --json number,state,baseRefName,headRefOid,isCrossRepository --jq '.[]|select(.isCrossRepository|not)|[.number,.state,.baseRefName,.headRefOid]|@tsv'`~     `gh pr list --head <b> --state merged --json number,state,baseRefName,headRefOid,isCrossRepository --jq '.[]|select(.isCrossRepository|not)|[.number,.state,.baseRefName,.headRefOid]|@tsv'`~0010
r3-skillbase~     does not match the skill-branch grammar. (3) The local tip, `git rev-parse HEAD`, equals~     may be any branch. (3) The local tip, `git rev-parse HEAD`, equals~0010
r3-noreinvoke~     PROCEDURE for that PR; when it succeeds, STOP this invocation and re-invoke~     PROCEDURE for that PR; when it succeeds, continue step 1 on <working> and run~0010
r3-elsenote~     failing) is a STOP that names the branch and every row's PR number and base, and~     failing) is a note that names the branch and every row's PR number and base, and~0010
r3-noapplying~     returns nowhere. That STOP also checks for `.claude/.ai-dlc-applying` and says whether~     returns nowhere. That STOP also says whether~0010
r4-delete~   `git branch -D` deletes only a tip the merge took, one equal to the merged PR's~   `git branch -D` deletes the skill branch, one equal to the merged PR's~0001
r4-nobase~   - **The PR's base is named, never defaulted:** `gh pr create --base <cut-from>`, where~   - **The PR's base is named, never defaulted:** `gh pr create`, where~0001
r1-nomergedstop~     compacted or resumed session derives them the same way. STOP, naming the state and the~     compacted or resumed session derives them the same way. Report the state and the~1000~
r1-noskillbase~     base, when the state is not `MERGED` or when `<working>` matches step 1's skill-branch~     base, when the state is not `MERGED`; a~1000~
r1-nofetchstop~     STOPs with its error (the ABANDON form below treats it as a note instead). (c) After that fetch and before any checkout, run **the~     is ignored (the ABANDON form below treats it as a note instead). (c) After that fetch and before any checkout, run **the~1000~
r1-unnamed~     working-tree check**, a named, self-contained block that another procedure may cite and~     check**, a block that another procedure may cite and~1000~
r1-nocd~     ( cd "$(git rev-parse --show-toplevel)" || { echo "STOP cannot cd to the repository toplevel"; exit; }~     (~1000~
r1-originonly~       { git rev-parse -q --verify "refs/heads/<working>" >/dev/null && git diff -z --name-only --no-renames HEAD <working>~       {~1000~
r1-nolocalguard~       { git rev-parse -q --verify "refs/heads/<working>" >/dev/null && git diff -z --name-only --no-renames HEAD <working>~       { git diff -z --name-only --no-renames HEAD <working>~1000~
r1-noorigguard~         git rev-parse -q --verify "refs/remotes/origin/<working>" >/dev/null && git diff -z --name-only --no-renames HEAD origin/<working>; } |~         git diff -z --name-only --no-renames HEAD origin/<working>; } |~1000~
r1-nonul~       sort -zu |~       sort -u |~1000~
r1-noread0~       while IFS= read -r -d '' p; do~       while IFS= read -r p; do~1000~
r1-noliteral~         if ! git diff --quiet HEAD -- ":(literal)$p"; then echo "DIRTY $p"~         if ! git diff --quiet HEAD -- "$p"; then echo "DIRTY $p"~1000~
r1-noondisk~         elif ! git cat-file -e "HEAD:$p" 2>/dev/null && { [ -e "$p" ] || [ -L "$p" ]; }; then echo "ON-DISK $p"~         elif false; then echo "ON-DISK $p"~1000~
r1-ondiskremedy~     stashes or forces. The remedy depends on the tag. `ON-DISK <path>`: move the file~     stashes or forces. The remedy depends on the tag. `ON-DISK <path>`: commit the file~1000~
r1-commitremedy~     aside, then re-run the block. `DIRTY <path>`: copy the file elsewhere, then run~     aside, then re-run the block. `DIRTY <path>`: commit it on the skill branch, then run~1000~
r1-checkbeforefetch~     grammar. (b) Run~     grammar. First run `( cd "$(git rev-parse --show-toplevel)" )`. (b) Run~1000~
r1-lowerd~     skill branch still exists, delete it with `git branch -D <skill-branch>` ONLY when~     skill branch still exists, delete it with `git branch -d <skill-branch>` ONLY when~1000~
r1-notipstop~     `git rev-parse <skill-branch>` equals the PR's `headRefOid`; otherwise STOP naming it,~     `git rev-parse <skill-branch>` equals the PR's `headRefOid`; otherwise keep it,~1000~
r1-nolocalkept~     gone, print `REMOTE-KEPT <skill-branch>: no local branch to gate on` and delete nothing~     gone, run the remote delete anyway and delete nothing~1000~
r1-unreadable~         grep -qF '(HTTP 404)' "$e" || echo "REMOTE-KEPT <skill-branch>: remote tip unreadable: $(tail -1 "$e")"~         :~1000~
r1-nomoved~       elif [ "$(cat "$o")" != "<headRefOid>" ]; then echo "REMOTE-KEPT <skill-branch>: remote tip moved"~       elif false; then echo "REMOTE-KEPT <skill-branch>: remote tip moved"~1000~
r1-no422~         grep -qF 'Reference does not exist' "$e" || echo "REMOTE-DELETE-FAILED <skill-branch>: $(tail -1 "$e")"~         echo "REMOTE-DELETE-FAILED <skill-branch>: $(tail -1 "$e")"~1000~
r1-deletefailstop~     `REMOTE-KEPT` or `REMOTE-DELETE-FAILED` line is never silent and never a STOP, because~     `REMOTE-KEPT` or `REMOTE-DELETE-FAILED` line is a STOP, because~1000~
r1-deletebeforea~     origin/<working>". (a) Run~     origin/<working>". First run `gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/<skill-branch>"`. (a) Run~1000~
r1-deleteinabandon~     skill branch is unmerged and stays. With no remote, (b) and (e) are skipped. When (b)'s~     skill branch is unmerged and stays; then run `gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/<skill-branch>"`. With no remote, (b) and (e) are skipped. When (b)'s~1000~
r1-abandonf~     invocation when no reflog line matches. It skips (a) and never runs (f), because the~     invocation when no reflog line matches. It skips (a) and then runs (f), because the~1000~
r1-abandonfetchstop~     fetch fails, ABANDON reports the fetch error as a note, skips (b) and (e), and goes on~     fetch fails, ABANDON STOPs with the fetch error, and goes on~1000~
r2-delbranch~     `gh pr merge <n> --squash --delete-branch=false --match-head-commit <sha>`, where `<sha>` is~     `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>`, where `<sha>` is~0100~   - **After the auto-merge, return the checkout before the re-invoke.** The auto-merge is
r2-nofalse~     `gh pr merge <n> --squash --delete-branch=false --match-head-commit <sha>`, where `<sha>` is~     `gh pr merge <n> --squash --match-head-commit <sha>`, where `<sha>` is~0100~   - **After the auto-merge, return the checkout before the re-invoke.** The auto-merge is
r2-noreturn~     RETURN PROCEDURE for that PR. With no remote configured there is no PR: run step 8's~     re-invoke. With no remote configured there is no PR: run step 8's~0100~
r2-noremote~     RETURN PROCEDURE in its ABANDON form to `<original-branch>`, then~     `git checkout <original-branch>`, then~0100~
r2-nobase~     The PR is opened with `gh pr create --base <original-branch>`; without `--base`, gh~     The PR is opened with `gh pr create`; without `--base`, gh~0100~
r2-nobasestop~     on this invocation, which is the prior behaviour. The return after the merge STOPs~     on this invocation, which is the prior behaviour. The return after the merge reports~0100~
r2-discardextra~     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` (the reflog-derived branch, or the branch step 1 confirmed in sync when no reflog line matches): its working-tree check runs first, the checkout on the next line IS that form's (d), run once and never as an extra step, and its (e) follows; if the check prints a line, ABANDON STOPs and so does this invocation, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports DEFERRED, and the next invocation's step 1 offers ABANDON;~     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` (the reflog-derived branch, or the branch step 1 confirmed in sync when no reflog line matches): its working-tree check runs first, the checkout on the next line runs after that form's (d) as an extra step, and its (e) follows; if the check prints a line, ABANDON STOPs and so does this invocation, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports DEFERRED, and the next invocation's step 1 offers ABANDON;~0100~
r2-discardgoeson~     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` (the reflog-derived branch, or the branch step 1 confirmed in sync when no reflog line matches): its working-tree check runs first, the checkout on the next line IS that form's (d), run once and never as an extra step, and its (e) follows; if the check prints a line, ABANDON STOPs and so does this invocation, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports DEFERRED, and the next invocation's step 1 offers ABANDON;~     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` (the reflog-derived branch, or the branch step 1 confirmed in sync when no reflog line matches): its working-tree check runs first, the checkout on the next line IS that form's (d), run once and never as an extra step, and its (e) follows; if the check prints a line, ABANDON STOPs but this invocation goes on, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports DEFERRED, and the next invocation's step 1 offers ABANDON;~0100~
r2-hookextra~     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` exactly as on a `TRANSPORT` exit: the checkout on the next line IS that form's (d), run once and never as an extra step; if its working-tree check prints a line, ABANDON STOPs and so does this invocation, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports `SELF-UPDATE-DEFER`, and the next invocation's step 1 offers ABANDON;~     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` exactly as on a `TRANSPORT` exit: the checkout on the next line runs after that form's (d) as an extra step; if its working-tree check prints a line, ABANDON STOPs and so does this invocation, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports `SELF-UPDATE-DEFER`, and the next invocation's step 1 offers ABANDON;~0100~
r2-hookgoeson~     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` exactly as on a `TRANSPORT` exit: the checkout on the next line IS that form's (d), run once and never as an extra step; if its working-tree check prints a line, ABANDON STOPs and so does this invocation, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports `SELF-UPDATE-DEFER`, and the next invocation's step 1 offers ABANDON;~     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` exactly as on a `TRANSPORT` exit: the checkout on the next line IS that form's (d), run once and never as an extra step; if its working-tree check prints a line, ABANDON STOPs but this invocation goes on, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports `SELF-UPDATE-DEFER`, and the next invocation's step 1 offers ABANDON;~0100~
r3-openstop~     Then four tests, in order. (1) Any row whose state is `OPEN`: STOP with "PR #N from~     Then four tests, in order. (1) Any row whose state is `OPEN`: note "PR #N from~0010~
r3-openfrombase~     <branch> is still open: merge or close it, then re-invoke from this branch." Merging~     <branch> is still open: merge or close it, then re-invoke from the branch it targets." Merging~0010~
r3-no4stop~     `MERGED` row's `baseRefName` equals it; otherwise STOP naming both, before any return,~     `MERGED` row's `baseRefName` equals it; otherwise go on, before any return,~0010~
r3-4noabandon~     and offer step 8's RETURN PROCEDURE to that `baseRefName` or its ABANDON form to the~     and offer `git checkout` to that `baseRefName` or to the~0010~
r3-notipgate~     When (2) and (3) both hold and (4) passed, run step 8's RETURN~     When (2) holds and (4) passed, run step 8's RETURN~0010~
r3-newest~     OLDEST line that begins with `checkout: moving from ` and ends with the fixed string~     NEWEST line that begins with `checkout: moving from ` and ends with the fixed string~0010~
r3-head1~     `git reflog --format=%gs | awk -v s=" to <skill-branch>" 'index($0, "checkout: moving from ") == 1 && length($0) > length(s) && substr($0, length($0) - length(s) + 1) == s' | tail -1`.~     `git reflog --format=%gs | awk -v s=" to <skill-branch>" 'index($0, "checkout: moving from ") == 1 && length($0) > length(s) && substr($0, length($0) - length(s) + 1) == s' | head -1`.~0010~
r3-pattern~     `git reflog --format=%gs | awk -v s=" to <skill-branch>" 'index($0, "checkout: moving from ") == 1 && length($0) > length(s) && substr($0, length($0) - length(s) + 1) == s' | tail -1`.~     `git reflog --format=%gs | grep -E "^checkout: moving from .+ to <skill-branch>$" | tail -1`.~0010~
r3-noremotecheckout~     local merge remedy: step 8's RETURN PROCEDURE in its ABANDON form to `<cut-from>` (the~     local merge remedy: `git checkout <cut-from>` (the~0010~
r3-noremotenostop~     and its work has not reached the working branch: STOP, name the branch, and give the~     and its work has not reached the working branch: name the branch, and give the~0010~
r4-step9delbranch~   Both literal `gh pr merge` commands pass `--delete-branch=false`, so gh's merge moves no~   Both literal `gh pr merge` commands pass `--delete-branch`, so gh's merge moves no~0001~
r4-mergedelbranch~     `gh pr merge <n> --squash --delete-branch=false --match-head-commit <sha>`, where `<sha>` is~     `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>`, where `<sha>` is~0001~   - **The merge command is literal:**
r4-mergenofalse~     `gh pr merge <n> --squash --delete-branch=false --match-head-commit <sha>`, where `<sha>` is~     `gh pr merge <n> --squash --match-head-commit <sha>`, where `<sha>` is~0001~   - **The merge command is literal:**
r4-norefuse~     way, because its step 6 is also a `git checkout -b`. Before any merge, refuse to create the~     way, because its step 6 is also a `git checkout -b`. Before any merge, mention the base of the~0001~
r4-fromlog~     `<cut-from>` is the branch this one was cut from, derived from HEAD's reflog exactly as~     `<cut-from>` is read from the `cut-from:` line of the reconcile log, derived from HEAD's reflog exactly as~0001~
r4-noreflog~     `<cut-from>` is the branch this one was cut from, derived from HEAD's reflog exactly as~     `<cut-from>` is the branch this one was cut from, taken from the session exactly as~0001~
r1-headc0~       sort -zu |~       sort -zu | head -c 0 |~1000~
r1-breakloop~       while IFS= read -r -d '' p; do~       while IFS= read -r -d '' p; do break~1000~
r1-deletefirst~       if ! gh api "repos/{owner}/{repo}/git/ref/heads/<skill-branch>" --jq .object.sha >"$o" 2>"$e"; then~       if ! gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/<skill-branch>" >/dev/null 2>"$e"; then :; elif ! gh api "repos/{owner}/{repo}/git/ref/heads/<skill-branch>" --jq .object.sha >"$o" 2>"$e"; then~1000~
r1-deletebeforegate~     grammar. (b) Run~     grammar. Run `gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/<skill-branch>"`. (b) Run~1000~
r2-dshort~     pushed; `--delete-branch=false` means gh moves no checkout and asks nothing. Then run step 8's~     pushed; `--delete-branch=false` means gh moves no checkout and asks nothing. Then also run `gh pr merge <n> -d`. Then run step 8's~0100~
RTABLE_EOF
if [ "$RFIX" = 1 ]; then
  _kills0="$kills"; _rn=0
  while IFS='~' read -r rname rold rnew rwant rprev; do
    [ -n "$rname" ] || continue
    _rn=$((_rn+1))
    mf="$WORK/mut-$rname.md"
    if ! mutate_r "$SUBJ" "$mf" "$rold" "$rnew" "${rprev:-}" || cmp -s "$SUBJ" "$mf"; then
      bad "mutant $rname DID NOT APPLY — its anchor line is not in $SUBJ exactly once"; continue
    fi
    mdec=""; mi=0
    for _a in r1 r2 r3 r4; do
      [ "${rwant:$mi:1}" = 1 ] && mdec="$_a"
      mi=$((mi+1))
    done
    hdec="$(mx_row "$rname" decides)"; htw="$(mx_row "$rname" twins)"
    if [ -z "$hdec" ] || [ -z "$htw" ] || [ "$hdec" != "$mdec" ]; then
      bad "FIXTURE BROKEN: mutant $rname has no single MUTANT-MATRIX row, or its decides=${hdec:-?} disagrees with the table's deciding arm ${mdec:-?}"; continue
    fi
    case "$hdec" in
      r1) score_row "${B_r1:-0}" "$rname" "$hdec" "$htw" "$rwant" "$mf" ;;
      r2) score_row "${B_r2:-0}" "$rname" "$hdec" "$htw" "$rwant" "$mf" ;;
      r3) score_row "${B_r3:-0}" "$rname" "$hdec" "$htw" "$rwant" "$mf" ;;
      r4) score_row "${B_r4:-0}" "$rname" "$hdec" "$htw" "$rwant" "$mf" ;;
      *) bad "FIXTURE BROKEN: mutant $rname names an arm $hdec that is not R1-R4" ;;
    esac
  done <<<"$RTABLE"
  [ "$_rn" -eq 86 ] || bad "the BL-986 mutant table parsed $_rn rows, not 86"
  # The mover and the replacer each refuse an anchor that matches nothing, and the replacer refuses a duplicated
  # line without its previous-line key (the merge-command line is in the file twice).
  _mc=0
  mutate_r "$SUBJ" "$WORK/nomatch-r.md" 'zq no such line anywhere zq' 'x' && _mc=$((_mc+1))
  mutate_r "$SUBJ" "$WORK/nomatch-r.md" '   - **Current branch is a skill branch** — a name matching' '>>after:zq no such line anywhere zq' && _mc=$((_mc+1))
  mutate_r "$SUBJ" "$WORK/nomatch-r.md" '     `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>`, where `<sha>` is' 'x' && _mc=$((_mc+1))
  [ "$_mc" -eq 0 ] || bad "mutate_r reported success on $_mc anchor(s) it must refuse -- every DID-NOT-APPLY guard above is vacuous"
  VR0="$(vector_r "$M0")"
  if [ "$VR0" = 0000 ] && [ $((kills - _kills0)) -eq "$_rn" ]; then
    ok "control: the unmutated copy scores 0000 on R1-R4, and $((kills - _kills0)) of $_rn BL-986 mutants were scored"
  else
    bad "control: the unmutated copy scored $VR0 on R1-R4 with $((kills - _kills0)) of $_rn BL-986 mutants scored — their verdicts mean nothing"
  fi
fi

# --- CWD INVARIANCE -----------------------------------------------------------------------
# The same vectors, recomputed with the process cwd at / where no relative path reaches the
# subject or the seeds. Both sides must be non-empty, or two empty strings compare equal.
V_CWD="$( cd / && vector "$SUBJ" )"
V_CWD_OFF="$( cd / && vector "$P_OFF" )"
VR_CWD="$( cd / && vector_r "$SUBJ" )"; VR_CWD_OFF="$( cd / && vector_r "$P_ROFF" )"
[ "$RFIX" = 1 ] || { VR_CWD=skip; VR_SUBJ=skip; }
if [ -n "$V_CWD" ] && [ "$V_CWD" = "$V_SUBJ" ] && [ "$V_CWD_OFF" = "$V_OFF" ] &&
   [ -n "$VR_CWD" ] && [ "$VR_CWD" = "$VR_SUBJ" ] && [ "$VR_CWD_OFF" = "$VR_OFF" ]; then
  ok "the subject ($V_CWD, R $VR_CWD) and offender ($V_CWD_OFF, R $VR_CWD_OFF) vectors are identical with the cwd at /"
else
  bad "the verdict moved with the cwd (subject $V_SUBJ vs $V_CWD, offender $V_OFF vs $V_CWD_OFF, R subject $VR_SUBJ vs $VR_CWD, R offender $VR_OFF vs $VR_CWD_OFF)"
fi

# RULE 9: a plain run executes NO matrix-only cell. Deciding and twin cells write the same ledger, so an
# empty matrix count cannot come from a ledger nothing writes.
mx_only="$(mx_count mx)"; mx_ctl="$(mx_count dec)"
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells means nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9: a plain run executed $mx_only matrix-only cell(s) -- the --matrix measurement leaked into the per-push run"
  else ok "rule-9: a plain run executed no matrix-only cell, while $mx_ctl deciding or twin cell(s) wrote the same ledger"; fi
else
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "$NAME: PASS"
  exit 0
fi
echo "$NAME: $fails FAILED" >&2
exit 1
