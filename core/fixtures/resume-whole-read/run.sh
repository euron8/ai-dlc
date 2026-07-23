#!/usr/bin/env bash
# resume-whole-read -- assert the resume path whole-reads the pipeline snapshot,
# and that a budget check stands in front of that read.
#
# Usage: run.sh [RESUME_FIXTURE_MUTANT=<name>]
# Exit:  0 = every assertion holds (or the named mutant was correctly rejected)
#        1 = the check regressed (or a mutant slipped through -- vacuity)
#        2 = fixture broken
#
# WHAT THIS PINS.
#
# Four places said the resume path whole-reads `pipeline-snapshot.md`:
# handoff.md ("for ALL state"), SKILL.md Rule 23(a) ("every gate, every resume,
# every compaction recovery"), SKILL.md's handoff-trigger section ("for all of
# it"), and this repo's own enforcement-map plus validate-artifact-budget.sh
# ("whole-read at every gate, on every resume"). The snapshot's 6,000-token
# budget is JUSTIFIED by that whole read.
#
# route.md -- the only one of the five that executes -- said "Read the snapshot's
# **Pipeline Position** section", unchanged since 1101e17, the commit that
# introduced the snapshot. It was written when the snapshot's only job was naming
# the next step file; six load-bearing sections accreted around it (In-Flight
# Teammates at v0.50.0, the Check 27 routing record later) and the read was never
# widened. The claim was asserted everywhere except where it ran.
#
# A lead following it literally dispatches without the In-Flight Teammates ledger
# -- the section that exists to stop it re-dispatching live teammates -- and pays
# three or four greps to avoid one ~2.5k-token Read.
#
# AND resume was the only path that read the snapshot with no budget check in
# front of it: Step 0 says "Skip the rest of this routing sequence. Steps 1-6",
# which skips Step 1a, and the next budget check is Check 14, AFTER the read.
#
# WHY THE ASSERTIONS ARE PAIRED.
#
# "route.md does not contain the section-scoped sentence" passes vacuously
# against an empty file -- the check-that-cannot-fire shape this suite exists to
# catch. Each absence assertion is joined to a positive one on the instruction
# that must be there instead. Run the `blank` mutant to see it: it fails the
# positives and passes the absence check, which is the whole point.

set -uo pipefail

MUTANT="${RESUME_FIXTURE_MUTANT:-}"

# Walk UP for a marker. Never count `..` hops: this file is reachable at
# core/fixtures/<name>/ in the distribution and tests/fixtures/<name>/ in a
# consumer, and a fixed hop count is wrong in one of them.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROUTE=""
MAP=""
d="$HERE"
while [ "$d" != "/" ]; do
  for rel in core/skills/ai-dlc .claude/skills/ai-dlc; do
    if [ -f "$d/$rel/steps/route.md" ]; then
      ROUTE="$d/$rel/steps/route.md"
      MAP="$d/$rel/enforcement-map.yaml"
      break 2
    fi
  done
  d="$(dirname "$d")"
done

if [ -z "$ROUTE" ]; then
  echo "FIXTURE ERROR: route.md not found in either layout" >&2
  echo "  walked up from: $HERE looking for {core,.claude}/skills/ai-dlc/steps/route.md" >&2
  exit 2
fi
[ -f "$MAP" ] || { echo "FIXTURE ERROR: enforcement-map.yaml not found beside route.md" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Mutants. Each rewrites route.md into the sandbox and names the assertions it
# MUST break. A mutant that passes every assertion means the assertion set is
# not testing what it claims.
# ---------------------------------------------------------------------------
if [ -n "$MUTANT" ]; then
  MUT="$WORK/route.md"
  case "$MUTANT" in
    section-read)
      # The pre-fix wording, restored. Must fail A1 (positive) and A2 (absence).
      sed 's|^2\. \*\*Load the snapshot\.\*\* Read `_bmad-output/pipeline-snapshot.md` \*\*in$|2. **Load the snapshot.** Read the snapshot'"'"'s **Pipeline Position** section to|' \
        "$ROUTE" > "$MUT"
      ;;
    no-budget)
      # Budget check deleted. Must fail A3 (positive) and A4 (ordering).
      grep -v 'verdict.sh validate-artifact-budget --only pipeline-snapshot.md' "$ROUTE" > "$MUT"
      ;;
    reorder)
      # Budget check moved AFTER the read, re-inserted past the END of the read
      # instruction so the read sentence itself is left intact. Must fail A4
      # ALONE -- A1 and A3 still pass, which is exactly why ordering is asserted
      # separately from presence.
      grep -v 'verdict.sh validate-artifact-budget --only pipeline-snapshot.md' "$ROUTE" \
        | sed 's|^\(   full\*\*\. This is the single load.*\)$|\1\n   `scripts/ai-dlc/verdict.sh validate-artifact-budget --only pipeline-snapshot.md`.|' \
        > "$MUT"
      ;;
    blank)
      # Vacuity control. Must fail the POSITIVES while passing A2 -- the
      # demonstration that a bare absence check proves nothing.
      : > "$MUT"
      ;;
    *)
      echo "FIXTURE ERROR: unknown RESUME_FIXTURE_MUTANT '$MUTANT'" >&2
      echo "  known: section-read | no-budget | reorder | blank" >&2
      exit 2
      ;;
  esac
  if cmp -s "$MUT" "$ROUTE" && [ "$MUTANT" != blank ]; then
    echo "FIXTURE ERROR: mutant '$MUTANT' changed nothing -- its anchor no longer" >&2
    echo "  matches route.md, so it cannot prove the assertions are live." >&2
    exit 2
  fi
  ROUTE="$MUT"
fi

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Wrapped prose: collapse to one line before matching, so a re-wrap of the same
# sentence is not read as its removal.
NORM="$(tr '\n' ' ' < "$ROUTE" | tr -s ' ')"

echo "resume-whole-read${MUTANT:+ [mutant: $MUTANT]}"

# --- A1/A2: the read is WHOLE, and the section-scoped read is gone -----------
# PAIRED. A2 alone passes against an empty file.
case "$NORM" in
  *'Read `_bmad-output/pipeline-snapshot.md` **in full**'*)
    ok "A1 route.md instructs a WHOLE read of pipeline-snapshot.md" ;;
  *) bad "A1 route.md instructs a WHOLE read of pipeline-snapshot.md" ;;
esac

case "$NORM" in
  *"Read the snapshot's **Pipeline Position** section"*)
    bad "A2 no section-scoped snapshot read survives" ;;
  *) ok "A2 no section-scoped snapshot read survives" ;;
esac

# --- A3: the budget check exists, by the invocation the gates already use ----
case "$NORM" in
  *'verdict.sh validate-artifact-budget --only pipeline-snapshot.md'*)
    ok "A3 Step 0a runs the snapshot budget check" ;;
  *) bad "A3 Step 0a runs the snapshot budget check" ;;
esac

# --- A4: the check PRECEDES the read it protects ----------------------------
# Presence is not enough. A budget check sitting after the read has already paid
# for the read it exists to prevent.
B_LINE="$(grep -n 'verdict.sh validate-artifact-budget --only pipeline-snapshot.md' "$ROUTE" | head -1 | cut -d: -f1)"
R_LINE="$(grep -n 'Read `_bmad-output/pipeline-snapshot.md`' "$ROUTE" | head -1 | cut -d: -f1)"
if [ -n "$B_LINE" ] && [ -n "$R_LINE" ] && [ "$B_LINE" -lt "$R_LINE" ]; then
  ok "A4 budget check precedes the read (line $B_LINE < $R_LINE)"
else
  bad "A4 budget check precedes the read (budget=${B_LINE:-absent} read=${R_LINE:-absent})"
fi

# --- A5: the resume consumes the teammate ledger ----------------------------
# The section that stops the lead re-dispatching a teammate that already
# delivered. The compaction twin (ai-dlc-recover.sh) has always reconciled it;
# the resume twin never read it.
case "$NORM" in
  *'Reconcile every `In-Flight Teammates` row'*)
    ok "A5 resume reconciles In-Flight Teammates rows" ;;
  *) bad "A5 resume reconciles In-Flight Teammates rows" ;;
esac

# --- A6: the call site is declared where the enforcement map can see it -----
# Not mutated: the map is a separate file, and a route.md mutant must not be
# able to mask a map regression.
if grep -q 'site: route.md Step 0a (resume)' "$MAP"; then
  ok "A6 enforcement-map declares the resume call site"
else
  bad "A6 enforcement-map declares the resume call site"
fi

if grep -q 'tests/fixtures/resume-whole-read' "$MAP"; then
  ok "A7 enforcement-map registers this fixture"
else
  bad "A7 enforcement-map registers this fixture"
fi

echo
if [ -n "$MUTANT" ]; then
  if [ "$fails" -gt 0 ]; then
    echo "MUTANT REJECTED: $fails assertion(s) failed, as required."
    exit 0
  fi
  echo "VACUOUS: mutant '$MUTANT' passed every assertion. The assertion set does" >&2
  echo "  not test what it claims." >&2
  exit 1
fi

if [ "$fails" -gt 0 ]; then
  echo "$fails assertion(s) failed"
  exit 1
fi
echo "all assertions hold"
exit 0
