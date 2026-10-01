#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# update-preflight-push — prove the ai-dlc-update step-1 AUTO-PUSH failure path is NOT fatal,
# that an UN-SYNCED branch reaches the dry-run with step 2 DEFERRED, and that step 6's
# re-confirm bullet never pushes and is the one place `apply` is refused.
#
# WHAT THE SUBJECT IS, AND WHAT THIS CANNOT OBSERVE. The subject is prose in
# `ai-dlc-update/SKILL.md`, eight units: the two AUTO-PUSH bullets of step 1's git preflight
# (no-upstream, ahead-only), step 1's detect paragraph, step 1's UN-SYNCED paragraph, step 2's
# UN-SYNCED DEFER paragraph, step 2's cycle bullet and its push-failure discard paragraph, and
# step 6's "Re-confirm the step-1 git preflight" bullet. No executable reads that text, so
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
# never merges. A push that fails after the gate's probe passed now discards the cycle: stage by
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
# Usage: run.sh
# Exit:  0 = every assertion holds (or the subject is absent: SKIP), 1 = the subject regressed,
#        2 = fixture broken.
set -uo pipefail

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

OFF="$HERE/offender.md"
NEAR="$HERE/nearmiss.md"
for f in "$OFF" "$NEAR"; do
  [ -s "$f" ] || { echo "$NAME: FIXTURE BROKEN — seed $f is missing or empty" >&2; exit 2; }
done

WORK="$(mktemp -d)" || { echo "$NAME: FIXTURE BROKEN — mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
B391=1   # every probe runs the full BL-391 predicate; the corpus may lower it, see below
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  FIXTURE BROKEN — %s\n' "$1"; echo; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }

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
  grep -qF 'un-synced' <<<"$_b" || return 1
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
V_SUBJ="$(vector "$SUBJ")"
arm() { # arm <digit> <ok text> <fail text>
  case "$1" in
    0) ok "$2" ;;
    3) bad "FIXTURE STALE: an anchor did not select exactly one unit in $SUBJ — the text moved or was renamed" ;;
    *) bad "$3" ;;
  esac
}
arm "$(printf '%s' "$V_SUBJ" | cut -c1)" \
  "step 1 no-upstream AUTO-PUSH: a failed push is non-fatal, continues, and marks the branch UN-SYNCED" \
  "step 1 no-upstream AUTO-PUSH: the push-failure path is fatal, or no longer says non-fatal + continue + UN-SYNCED"
arm "$(printf '%s' "$V_SUBJ" | cut -c2)" \
  "step 1 ahead-only AUTO-PUSH: a rejected or failed push is non-fatal, continues, and marks the branch UN-SYNCED" \
  "step 1 ahead-only AUTO-PUSH: the push-failure path is fatal, or no longer says non-fatal + continue + UN-SYNCED"
arm "$(printf '%s' "$V_SUBJ" | cut -c3)" \
  "step 6 re-confirm: carries the no-push sentence and no push instruction" \
  "step 6 re-confirm: instructs a push, or lost its no-push sentence — a write to origin from inside the isolation step"
arm "$(printf '%s' "$V_SUBJ" | cut -c4)" \
  "step 6 re-confirm: stops apply on an UN-SYNCED branch" \
  "step 6 re-confirm: no longer refuses apply on an UN-SYNCED branch"
arm "$(printf '%s' "$V_SUBJ" | cut -c5)" \
  "step 1 UN-SYNCED paragraph: proceeds to the dry-run, names step 2's defer, does not end the run" \
  "step 1 UN-SYNCED paragraph: absent, ends the run, or no longer sends the branch to the dry-run with step 2 deferred"
arm "$(printf '%s' "$V_SUBJ" | cut -c6)" \
  "step 2 UN-SYNCED paragraph: step 2 defers, and nothing in it pushes or commits locally" \
  "step 2 UN-SYNCED paragraph: absent, does not defer, or pushes / commits locally — the orphaned self-update branch"
if [ "$B391" = 1 ]; then
arm "$(printf '%s' "$V_SUBJ" | cut -c7)" \
  "step 1 detect paragraph: claims no clean-tree check, says step 1 does not check the working tree, names step 6" \
  "step 1 detect paragraph: claims a clean tree step 1 never checks, or no longer says where a dirty tree is refused"
arm "$(printf '%s' "$V_SUBJ" | cut -c8)" \
  "step 2 cycle bullet: names the push-failure case and pairs no failed push with a local commit" \
  "step 2 cycle bullet: a failed push commits locally, or the push-failure case vanished from the bullet"
arm "$(printf '%s' "$V_SUBJ" | cut -c9)" \
  "step 2 discard paragraph: pathspec staging, checkout original, file-list check gating the delete, STOP naming the branch, DEFER, UN-SYNCED, stamp unmoved" \
  "step 2 discard paragraph: absent, keeps a local commit, or lost a conjunct of the discard procedure"
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
post|wX-keepcommit|     error in one line;|     error in one line, and commit locally;|000000001
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
_want_n=26; [ "$B391" = 1 ] || _want_n=12
while IFS='|' read -r mscope mname mold mnew mwant; do
  [ -n "$mname" ] || continue
  case "$mscope:$B391" in all:*|post:1|pre:0) ;; *) continue ;; esac
  # Pre-BL-391 consumer text has no arms 7-9: compare the six older digits only.
  [ "$B391" = 1 ] || mwant="$(printf '%s' "$mwant" | cut -c1-6)000"
  _n=$((_n+1))
  mf="$WORK/mut-$mname.md"
  if ! mutate "$SUBJ" "$mf" "$mold" "$mnew" || cmp -s "$SUBJ" "$mf"; then
    bad "mutant $mname DID NOT APPLY — its anchor line is not in $SUBJ exactly once"; mut_ok=0; continue
  fi
  mv_="$(vector "$mf")"
  [ "$B391" = 1 ] || mv_="$(printf '%s' "$mv_" | cut -c1-6)000"
  if [ "$mv_" = "$mwant" ]; then
    ok "mutant $mname killed by its own arm alone ($mv_)"; kills=$((kills+1))
  else
    bad "mutant $mname scored $mv_, want $mwant — survived, or killed by an entangled arm"
  fi
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
  ok "control: the unmutated copy scores 000000000 through the mutant harness, and $kills of $_n mutants were killed"
else
  bad "control: the unmutated copy scored $V0 with $kills of $_n kills — the mutant verdicts above mean nothing"
fi

# --- CWD INVARIANCE -----------------------------------------------------------------------
# The same vectors, recomputed with the process cwd at / where no relative path reaches the
# subject or the seeds. Both sides must be non-empty, or two empty strings compare equal.
V_CWD="$( cd / && vector "$SUBJ" )"
V_CWD_OFF="$( cd / && vector "$P_OFF" )"
if [ -n "$V_CWD" ] && [ "$V_CWD" = "$V_SUBJ" ] && [ "$V_CWD_OFF" = "$V_OFF" ]; then
  ok "the subject ($V_CWD) and offender ($V_CWD_OFF) vectors are identical with the cwd at /"
else
  bad "the verdict moved with the cwd (subject $V_SUBJ vs $V_CWD, offender $V_OFF vs $V_CWD_OFF)"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "$NAME: PASS"
  exit 0
fi
echo "$NAME: $fails FAILED" >&2
exit 1
