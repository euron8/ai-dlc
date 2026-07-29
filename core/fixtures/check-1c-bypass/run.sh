#!/usr/bin/env bash
# Drive the check-1c-bypass fixture and assert the expected match matrix.
# Exit 0 = the seeded adversary really is a bypass, and the anchored arms catch it
# while the naive forms do not.
#
# WHAT THIS DOES NOT PROVE. Check 1c is `adjudication: llm` with `enforcer: []` —
# there is no validator script to drive, unlike check-17-bypass whose run.sh calls
# the real `validate-provenance-block.sh`. So this driver evaluates the check's OWN
# PUBLISHED REGEXES (gate-validation.md, `CHECK_LOADED: 1c`) against the seed. It
# proves the FIXTURE's claim, not the ADJUDICATOR's behaviour: an LLM that ignores
# the published regexes entirely is not detected here and cannot be, from a script.
# Stating that plainly is the point — a driver that implied otherwise would be a
# worse lie than the echo it replaces.
#
# What it does prove, and what the echo never did:
#   - the seeded bypass branch EXISTS and genuinely exhibits the bypass property
#     (naive forms match it, anchored forms do not), so the adversary has something
#     real to attack;
#   - the anchored arms still accept an honest sprint (the positive control), so an
#     arm regex that matched nothing at all would go red here rather than look right.
#
# If the regexes below drift from gate-validation.md, this fixture silently tests a
# stale copy. They are quoted from the check body and must be updated with it.
#
# Usage: run.sh

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- the check's published regexes, quoted from gate-validation.md CHECK_LOADED: 1c
ARM_A_ANCHORED='^Sprint [0-9]+ (research-requirements|technical.*research|research.*technical|bmad-technical-research)'
ARM_B_MARKER='^(- |### )?\*{0,2}R[0-9]+[[:space:]]+(—|–|-)[[:space:]]'
ARM_B_SECTION='Research Findings'
# --- the naive forms the fixture exists to discriminate against
NAIVE_A='research'
NAIVE_B_MARKER='R[0-9]+'

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REPO="$(bash "$HERE/seed.sh" "$WORK")"
[ -d "$REPO/.git" ] || { echo "FAIL: seed did not produce a git repo at '$REPO'" >&2; exit 2; }

fails=0
note() { printf '  %-6s %-46s %s\n' "$1" "$2" "$3"; }

subjects() { ( cd "$REPO" && git log "main..$1" --format=%s ); }
prd()      { ( cd "$REPO" && git show "$1:_bmad-output/planning-artifacts/prd.md" ); }

# assert MATCH/NOMATCH of a pattern against stdin-producing command
expect() { # expect <want:yes|no> <label> <pattern> <text>
  local want="$1" label="$2" pat="$3" text="$4" got
  if grep -qE "$pat" <<<"$text"; then got=yes; else got=no; fi
  if [ "$got" = "$want" ]; then
    note "ok" "$label" "$( [ "$want" = yes ] && echo matched || echo "did not match" ) (as required)"
  else
    note "BAD" "$label" "wanted $want, got $got"
    fails=$((fails + 1))
  fi
}

echo "check-1c-bypass: evaluating Check 1c's published regexes against the seed"
echo

BYPASS_SUBJ="$(subjects bypass)"
HONEST_SUBJ="$(subjects honest)"
BYPASS_PRD="$(prd bypass)"
HONEST_PRD="$(prd honest)"

# ---- the adversary must defeat the naive forms and be caught by the anchored ones
expect no  "bypass  arm(a) anchored"        "$ARM_A_ANCHORED" "$BYPASS_SUBJ"
expect yes "bypass  arm(a) naive substring" "$NAIVE_A"        "$BYPASS_SUBJ"
expect no  "bypass  arm(b) anchored marker" "$ARM_B_MARKER"   "$BYPASS_PRD"
expect yes "bypass  arm(b) naive marker"    "$NAIVE_B_MARKER" "$BYPASS_PRD"
expect yes "bypass  arm(b) section present" "$ARM_B_SECTION"  "$BYPASS_PRD"

# ---- the positive control: the anchored arms must still accept an honest sprint.
# This is the mutant-detector. Break either anchored regex so it matches nothing and
# the two assertions below go red; without them, a never-matching regex would read as
# a correctly-rejected adversary.
expect yes "honest  arm(a) anchored"        "$ARM_A_ANCHORED" "$HONEST_SUBJ"
expect yes "honest  arm(b) anchored marker" "$ARM_B_MARKER"   "$HONEST_PRD"
expect yes "honest  arm(b) section present" "$ARM_B_SECTION"  "$HONEST_PRD"

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  check-1c-bypass: 8 assertions correct. The bypass branch satisfies the"
  echo "      naive forms and NEITHER anchored arm (Check 1c must FAIL it); the honest"
  echo "      branch satisfies both anchored arms (Check 1c must PASS it)."
  exit 0
fi
echo "FAIL  check-1c-bypass: $fails assertion(s) violated." >&2
exit 1
