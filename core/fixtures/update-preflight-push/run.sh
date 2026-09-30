#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# update-preflight-push — prove the ai-dlc-update step-1 AUTO-PUSH failure path is NOT fatal,
# and that step 6's re-confirm bullet never pushes and is the one place `apply` is refused.
#
# WHAT THE SUBJECT IS, AND WHAT THIS CANNOT OBSERVE. The subject is prose in
# `ai-dlc-update/SKILL.md`: the two AUTO-PUSH bullets of step 1's git preflight (no-upstream,
# ahead-only) and step 6's "Re-confirm the step-1 git preflight" bullet. No executable reads
# that text, so nothing here observes whether a running update actually continued past a
# failed push. The observable is the declared text, and every assertion is scoped to it.
#
# THE DEFECT THIS EXISTS TO CATCH. A failed step-1 push STOPPED the whole run ("do not proceed
# on an un-synced branch"), so an auth or protected-branch rejection cost the operator the
# dry-run report as well as the apply; and step 6 AUTO-PUSHED "to re-sync exactly as in step
# 1" immediately before cutting the reconcile branch — a write to origin from inside the
# isolation step. The fix: a failed step-1 push marks the branch UN-SYNCED and continues to
# the dry-run, and step 6 pushes nothing and STOPs `apply` on an out-of-sync or UN-SYNCED
# branch. `offender.md` in this directory is the pre-fix text, cut byte-for-byte from the
# release that shipped the defect.
#
# WHY BULLET-SCOPED. The BEHIND and DIVERGED bullets sit beside the AHEAD bullet and say STOP,
# correctly, in the fixed text too. A list- or file-scoped grep for STOP flags the fixed text
# on their account. Probe direction 3 asserts that false finding is excluded.
#
# WHY WHITESPACE-COLLAPSED. A bullet is joined across its continuation lines before any
# pattern runs, so an anchor or a forbidden phrase split by a line wrap is still seen.
# `nearmiss.md` wraps all three anchors, and probe direction 4 asserts it really is wrapped.
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
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  FIXTURE BROKEN — %s\n' "$1"; echo; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }

echo "$NAME:"

# --- THE EXTRACTOR -------------------------------------------------------------------------
# Prints every `- ` bullet of a file on ONE line: continuation lines (indented, non-bullet)
# are joined, `*` and backticks are dropped, whitespace runs collapse to one space, and the
# result is lowercased. A bullet ends at the next bullet, a blank line, or an unindented line
# (a numbered step heading). LC_ALL=C because the subject carries multibyte characters and a
# BSD awk otherwise aborts mid-file, which would read as "the bullet says nothing".
bullets() { # bullets <file>
  LC_ALL=C awk '
    function fin() { if (t != "") { gsub(/[*`]/, "", t); gsub(/[ \t]+/, " ", t); print tolower(t) } t = "" }
    /^[ \t]*- / { fin(); t = $0; next }
    /^[ \t]+[^ \t]/ && t != "" { t = t " " $0; next }
    { fin() }
    END { fin() }
  ' "$1"
}

# The ONE bullet whose joined text carries the anchor. rc 3 unless exactly one does: an
# anchor that selects nothing, or two bullets, is a stale fixture and never a verdict.
bullet() { # bullet <file> <lowercase anchor>
  _all="$(bullets "$1")"
  _n="$(grep -cF -- "$2" <<<"$_all")" || _n=0
  [ "$_n" -eq 1 ] || return 3
  grep -F -- "$2" <<<"$_all"
}

A_NOUP='remote exists but the current branch has no upstream'
A_AHEAD='branch ahead of its upstream'
A_BEHIND='branch behind its upstream'
A_RECONF='re-confirm the step-1 git preflight'

# THE PREDICATES, stated once and applied to probe, corpus and mutant alike. Each returns
# 0 = compliant, 1 = finding, 3 = bullet not located.
#
# fatal-on-failure: the push-failure bullet STOPs, ends the run, or refuses to proceed; or it
# no longer names its failure path or the UN-SYNCED state at all (a bullet that dropped the
# failure clause entirely is not compliant by silence).
push_fail_ok() { # push_fail_ok <file> <anchor>
  _b="$(bullet "$1" "$2")" || return 3
  grep -qE '(^|[^a-z])stop([^a-z]|$)|run ends|do not proceed' <<<"$_b" && return 1
  grep -qE 'fail|reject' <<<"$_b" || return 1
  grep -qF 'un-synced' <<<"$_b" || return 1
  return 0
}
# step 6 pushes: any auto-push or git push instruction in the re-confirm bullet.
reconf_nopush_ok() { # reconf_nopush_ok <file>
  _b="$(bullet "$1" "$A_RECONF")" || return 3
  grep -qE 'auto-push|git push|push(es|ed)? (it |the branch )?to re-sync' <<<"$_b" && return 1
  return 0
}
# step 6 refuses apply on an un-synced branch: a stop/refuse of apply in one clause, and the
# un-synced / not-in-sync condition named.
reconf_refuse_ok() { # reconf_refuse_ok <file>
  _b="$(bullet "$1" "$A_RECONF")" || return 3
  grep -qE '(stop|refuse)[^.;]*apply' <<<"$_b" || return 1
  grep -qE 'un-synced|not in sync' <<<"$_b" || return 1
  return 0
}

# The four-arm vector for one file: noupstream ahead nopush refuse, each digit the rc.
vector() { # vector <file>
  push_fail_ok "$1" "$A_NOUP"; r1=$?
  push_fail_ok "$1" "$A_AHEAD"; r2=$?
  reconf_nopush_ok "$1"; r3=$?
  reconf_refuse_ok "$1"; r4=$?
  printf '%s%s%s%s' "$r1" "$r2" "$r3" "$r4"
}

# --- SELF-PROBE, BEFORE THE CORPUS, IN BOTH DIRECTIONS ------------------------------------
# On mktemp copies of the shipped seeds, so no probe reads the fixture directory in place.
P_OFF="$WORK/offender.md";  cp "$OFF" "$P_OFF"   || broken "could not copy the offender seed"
P_NEAR="$WORK/nearmiss.md"; cp "$NEAR" "$P_NEAR" || broken "could not copy the near-miss seed"

# Direction 0: the extractor locates each anchor exactly once in both seeds.
for f in "$P_OFF" "$P_NEAR"; do
  for a in "$A_NOUP" "$A_AHEAD" "$A_RECONF"; do
    bullet "$f" "$a" >/dev/null || broken "anchor '$a' did not select exactly one bullet in $(basename "$f"); every direction below would be a false pass"
  done
done
ok "probe 0: every anchor selects exactly one bullet in the offender and in the near-miss"

# Direction 0b: two anchors extract two different bodies (an extractor returning the whole
# list for every anchor would pass direction 0 and score every arm identically).
if [ "$(bullet "$P_OFF" "$A_NOUP")" != "$(bullet "$P_OFF" "$A_AHEAD")" ]; then
  ok "probe 0b: the no-upstream and ahead-only anchors extract different bodies"
else
  broken "two anchors extracted the same text; the extractor is not bullet-scoped"
fi

# Direction 1 (REPORTS the offender): the pre-fix text scores a finding on all four arms.
V_OFF="$(vector "$P_OFF")"
if [ "$V_OFF" = 1111 ]; then
  ok "probe 1: the pre-fix text is flagged on all four arms (vector $V_OFF)"
else
  bad "probe 1: the pre-fix text scored $V_OFF, not 1111 — a predicate cannot see the defect it exists for"
fi

# Direction 2 (QUIET on the near-miss): a correct text sharing no sentence with the shipped
# fix. It says "refuse apply" where the fix says "STOP apply", mentions a push remedy in step
# 6 without a push instruction, and carries `git push` in the step-1 bullets, so a predicate
# that leaked across bullets into step 6 would fire here.
V_NEAR="$(vector "$P_NEAR")"
if [ "$V_NEAR" = 0000 ]; then
  ok "probe 2: a respelled correct text is quiet on all four arms (not vocabulary-bound)"
else
  bad "probe 2: a respelled correct text scored $V_NEAR, not 0000 — a predicate is keyed on a spelling or leaks across bullets"
fi

# Direction 3 (the list-scoped false finding): the BEHIND bullet DOES say STOP in the
# near-miss, and the ahead-only bullet beside it is still scored compliant.
B_BEHIND="$(bullet "$P_NEAR" "$A_BEHIND")" || broken "the near-miss BEHIND bullet did not extract, so direction 3 tests nothing"
if grep -qE '(^|[^a-z])stop([^a-z]|$)' <<<"$B_BEHIND"; then
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
_raw="$(LC_ALL=C tr 'A-Z' 'a-z' < "$P_NEAR" | LC_ALL=C tr -d '*`')"
_w=0
for a in "$A_NOUP" "$A_AHEAD" "$A_RECONF"; do
  grep -qF -- "$a" <<<"$_raw" && _w=$((_w+1))
done
_c="$(grep -cF -- 'branch behind its upstream' <<<"$_raw")" || _c=0
if [ "$_w" -eq 0 ] && [ "$_c" -eq 1 ]; then
  ok "probe 4: all three anchors are split across a line wrap in the near-miss (control: an unwrapped anchor reads 1)"
else
  broken "the near-miss is not wrapped as seeded (unwrapped anchors $_w, control $_c), so the join is unproven"
fi

# Direction 5: an absent anchor is rc 3, never the rc 0/1 of a verdict.
push_fail_ok "$P_OFF" 'no such bullet anywhere zq'; rc=$?
if [ "$rc" -eq 3 ]; then
  ok "probe 5: an anchor that selects no bullet returns rc 3, told apart from a verdict"
else
  bad "probe 5: an absent anchor returned rc $rc — indistinguishable from a verdict"
fi

# --- THE CORPUS ---------------------------------------------------------------------------
echo "  ..    subject: $SUBJ"
V_SUBJ="$(vector "$SUBJ")"
arm() { # arm <digit> <ok text> <fail text>
  case "$1" in
    0) ok "$2" ;;
    3) bad "FIXTURE STALE: an anchor did not select exactly one bullet in $SUBJ — the text moved or was renamed" ;;
    *) bad "$3" ;;
  esac
}
arm "$(printf '%s' "$V_SUBJ" | cut -c1)" \
  "step 1 no-upstream AUTO-PUSH: a failed push is non-fatal and marks the branch UN-SYNCED" \
  "step 1 no-upstream AUTO-PUSH: the push-failure path STOPs or refuses to proceed (or no longer names the failure and UN-SYNCED)"
arm "$(printf '%s' "$V_SUBJ" | cut -c2)" \
  "step 1 ahead-only AUTO-PUSH: a rejected or failed push is non-fatal and marks the branch UN-SYNCED" \
  "step 1 ahead-only AUTO-PUSH: the push-failure path STOPs or refuses to proceed (or no longer names the failure and UN-SYNCED)"
arm "$(printf '%s' "$V_SUBJ" | cut -c3)" \
  "step 6 re-confirm: carries no auto-push or git push to re-sync" \
  "step 6 re-confirm: instructs a push — a write to origin from inside the isolation step"
arm "$(printf '%s' "$V_SUBJ" | cut -c4)" \
  "step 6 re-confirm: stops apply on an out-of-sync or UN-SYNCED branch" \
  "step 6 re-confirm: no longer refuses apply on an un-synced branch"

# --- MUTANTS, EACH MUST FAIL ONLY ITS OWN ARM ---------------------------------------------
# Built as copies of the RESOLVED subject. The replace is a literal whole-line substitution
# that counts its matches: exactly one, or the mutant DID NOT APPLY and the fixture is stale.
mutate() { # mutate <src> <dst> <old line> <new line>
  LC_ALL=C awk -v o="$3" -v n="$4" '
    $0 == o { print n; c++; next } { print } END { exit (c == 1 ? 0 : 3) }
  ' "$1" > "$2"
}
M0="$WORK/control.md"; cp "$SUBJ" "$M0" || broken "could not copy the subject for the unmutated control"
M1="$WORK/wrong1.md"
M2="$WORK/wrong2.md"
W1_OLD='     NOT fatal**: report the `git push` error in one line, mark the branch'
W1_NEW='     fatal**: STOP the run and report the `git push` error in one line, mark the branch'
W2_OLD='     its upstream. **Do not push here, ever.** Time may have passed since the'
W2_NEW='     its upstream. If it drifted AHEAD, **auto-push** to re-sync exactly as in step 1. Time may have passed since the'

mut_ok=1
if ! mutate "$SUBJ" "$M1" "$W1_OLD" "$W1_NEW" || cmp -s "$SUBJ" "$M1"; then
  bad "mutant wrong1 DID NOT APPLY — its anchor line is not in $SUBJ exactly once"; mut_ok=0
fi
if ! mutate "$SUBJ" "$M2" "$W2_OLD" "$W2_NEW" || cmp -s "$SUBJ" "$M2"; then
  bad "mutant wrong2 DID NOT APPLY — its anchor line is not in $SUBJ exactly once"; mut_ok=0
fi
# Control for the mutator itself: an anchor that is nowhere must refuse, not pass through.
if mutate "$SUBJ" "$WORK/nomatch.md" 'zq no such line anywhere zq' 'x'; then
  bad "the mutator reported success on an anchor that matches nothing — every DID-NOT-APPLY guard above is vacuous"
fi

# Unmutated control, with a POSITIVE conjunct: the copy scores 0000 (every bullet located and
# compliant), so a harness that ran nothing cannot pass here.
V0="$(vector "$M0")"
if [ "$V0" = 0000 ]; then
  ok "control: the unmutated copy scores 0000 through the mutant harness"
else
  bad "control: the unmutated copy scored $V0 — the mutant verdicts below mean nothing"
fi
if [ "$mut_ok" -eq 1 ]; then
  V1="$(vector "$M1")"; V2="$(vector "$M2")"
  if [ "$V1" = 0100 ]; then
    ok "mutant wrong1 (ahead-only failure reworded to STOP the run) killed by the ahead-only arm alone (0100)"
  else
    bad "mutant wrong1 scored $V1, want 0100 — survived, or killed by an entangled arm"
  fi
  if [ "$V2" = 0010 ]; then
    ok "mutant wrong2 (step 6 auto-pushes to re-sync) killed by the no-push arm alone (0010)"
  else
    bad "mutant wrong2 scored $V2, want 0010 — survived, or killed by an entangled arm"
  fi
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
