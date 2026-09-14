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
HANDOFF=""
d="$HERE"
while [ "$d" != "/" ]; do
  for rel in core/skills/ai-dlc .claude/skills/ai-dlc; do
    if [ -f "$d/$rel/steps/route.md" ]; then
      ROUTE="$d/$rel/steps/route.md"
      MAP="$d/$rel/enforcement-map.yaml"
      HANDOFF="$d/$rel/steps/handoff.md"
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
[ -f "$HANDOFF" ] || { echo "FIXTURE ERROR: handoff.md not found beside route.md" >&2; exit 2; }

# The entry line the PRODUCER emits, derived from handoff.md's own fenced block
# rather than written here. A8/A9 join it to what the READER accepts; hard-coding
# the string would let the two drift apart with the fixture still green.
ENTRY_LINE="$(awk '/^```$/{f=!f;next} f && /^\/ai-dlc /{print;exit}' "$HANDOFF")"
if [ -z "$ENTRY_LINE" ]; then
  echo "FIXTURE ERROR: handoff.md emits no fenced /ai-dlc entry line, so the join in" >&2
  echo "  A8/A9 has no left-hand side and would pass over nothing." >&2
  exit 2
fi

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
    no-entry-line)
      # The reader forgets the entry line the producer emits. This is the state
      # BL-125 filed: handoff.md said "exactly /ai-dlc resume" while route.md's
      # resume grammar accepted only two prose forms that, measured over 67
      # recorded consumer prompts, had never matched once. Must fail A8 ALONE.
      sed 's|`/ai-dlc resume`|the bare invocation|g' "$ROUTE" > "$MUT"
      ;;
    no-handoff-token)
      # The `handoff` entry token loses its dispatch, so a session whose FIRST
      # input is the request falls through to Step 1 and is routed as a new
      # feature. Must fail A9 ALONE.
      sed 's|^   - \*\*`handoff`\*\* .*|   - (removed)|' "$ROUTE" > "$MUT"
      ;;
    no-since-route)
      # The beat instruction deleted outright. Must fail A10 ALONE.
      # Keyed on the SUBJECT'S OWN predicate -- the line that names the program
      # AND the flag -- never on a line number or a quoted copy of the sentence,
      # so a rewrap or a reword re-anchors itself and `cmp -s` below catches a
      # predicate that has genuinely lost its subject.
      awk '!(/wait-for-deliverable\.sh/ && /--since/)' "$ROUTE" > "$MUT"
      ;;
    since-at-eof)
      # SITING. The same sentence, byte-identical, moved out of the Step 0
      # window to the end of the file. Every token A10 looks for is still in
      # route.md, so a whole-file grep passes and only a windowed read fails.
      awk '/wait-for-deliverable\.sh/ && /--since/ { saved = saved $0 "\n"; next }
           { print }
           END { printf "%s", saved }' "$ROUTE" > "$MUT"
      ;;
    since-in-comment)
      # The sentence wrapped in an HTML comment: present in the window, invisible
      # to a reader following the file. Must fail A10 ALONE.
      awk '/wait-for-deliverable\.sh/ && /--since/ { print "<!--"; print $0; print "-->"; next }
           { print }' "$ROUTE" > "$MUT"
      ;;
    since-in-fence)
      # The sentence wrapped in a fenced block: an EXAMPLE, not an instruction.
      # Must fail A10 ALONE.
      awk '/wait-for-deliverable\.sh/ && /--since/ { print "```"; print $0; print "```"; next }
           { print }' "$ROUTE" > "$MUT"
      ;;
    since-negated)
      # The instruction inverted. Every token survives and the sentence now says
      # the opposite. Must fail A10 ALONE.
      awk '/wait-for-deliverable\.sh/ && /--since/ { t=$0; sub(/^[[:space:]]+/, "", t); print "     Do NOT run " t; next }
           { print }' "$ROUTE" > "$MUT"
      ;;
    since-other-program)
      # `--since` and `dispatched-at` attributed to a DIFFERENT program. The
      # flag is named, the cell is named, and the beat is never armed. Must fail
      # A10 ALONE.
      awk '/wait-for-deliverable\.sh/ && /--since/ { gsub(/wait-for-deliverable\.sh/, "validate-artifact-budget.sh") }
           { print }' "$ROUTE" > "$MUT"
      ;;
    blank)
      # Vacuity control. Must fail the POSITIVES while passing A2 -- the
      # demonstration that a bare absence check proves nothing. An empty Step 0
      # window is an ordinary A10 failure, not a broken fixture, so this mutant
      # stays a MUTANT REJECTED and does not exit 2.
      : > "$MUT"
      ;;
    *)
      echo "FIXTURE ERROR: unknown RESUME_FIXTURE_MUTANT '$MUTANT'" >&2
      echo "  known: section-read | no-budget | reorder | no-entry-line |" >&2
      echo "         no-handoff-token | no-since-route | since-at-eof |" >&2
      echo "         since-in-comment | since-in-fence | since-negated |" >&2
      echo "         since-other-program | blank" >&2
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

# --- A8: the READER accepts the entry line the PRODUCER emits ----------------
# A JOIN, both sides derived: $ENTRY_LINE comes out of handoff.md's fenced block
# above, and route.md must name that exact string. Neither side is written here,
# so re-wording either one on its own turns this red instead of leaving it green
# over a disagreement.
#
# The state this exists for: handoff.md step 4 mandated `/ai-dlc resume` while
# route.md's Step 0 accepted only "Resuming an ai-dlc sprint" or a reference to
# "pipeline snapshot". Measured over 67 recorded prompts from the reference
# consumer, those two forms matched 0 and the emitted line matched 3 -- so the
# documented handoff entry line fell through Step 0 to Step 1 fresh-pipeline
# routing, and Step 6 archived as stale the snapshot the handoff had just spent
# five steps preserving.
case "$NORM" in
  *"$ENTRY_LINE"*)
    ok "A8 route.md accepts the entry line handoff.md emits ($ENTRY_LINE)" ;;
  *) bad "A8 route.md accepts the entry line handoff.md emits ($ENTRY_LINE)" ;;
esac

# --- A9: the `handoff` entry token dispatches to handoff.md ------------------
# PAIRED with A8 and separately mutated, because the two failed independently:
# teaching the reader the resume line leaves `/ai-dlc handoff` unrouted, and
# routing `handoff` leaves the successor's own entry line unrecognised.
#
# SKILL.md's handoff trigger (a) cannot cover this: it is a natural-language
# judgment a lead makes MID-SESSION, and a session whose first input IS the
# request has no lead in conversation to make it.
case "$NORM" in
  *'**`handoff`**'*'steps/handoff.md'*)
    ok "A9 route.md dispatches the handoff entry token to steps/handoff.md" ;;
  *) bad "A9 route.md dispatches the handoff entry token to steps/handoff.md" ;;
esac

# --- A10: the resume names the program that arms the beat, and its flag ------
# Step 0 path 2 told a resuming lead that "the beat resumes" for a row whose
# deliverable is older or absent and named neither the program nor the flag
# that makes it correct across a session boundary.
#
# WHAT A10 CAN AND CANNOT SCORE. It scores THREE properties and no others:
# PRESENCE (the program, the flag and the cell are named), SITING (they are
# named inside the Step 0 window, in text a reader following the file
# executes -- not in a fenced example, not in an HTML comment, not elsewhere
# in the file), and NON-NEGATION (the clause before the program name does not
# tell the reader to skip it). It CANNOT score whether the instruction is
# CORRECT -- whether `--since` takes that cell, whether the beat is the right
# beat, whether the value is well-formed. A rewrite that names all three
# tokens in one non-negated in-window sentence and gives wrong advice passes
# this arm. Correctness is the reviewer's, and the arm claims no more.
#
# THE WINDOW GRAMMAR IS `^###`, NOT `^##`. `^##[[:space:]]*Step 0` matches
# nothing in route.md -- every step heading is `###` -- and that grammar
# returned an EMPTY window, which read as a clean scan.
#
# An empty window is an ordinary `bad` here, never exit 2, so the `blank`
# mutant keeps exiting 0 as MUTANT REJECTED. Exit 2 is reserved above, for
# route.md itself being absent.
W10="$(awk '
  /^###[[:space:]]*Step 0a/           { inw = 0 }
  inw && /^[[:space:]]*```/           { fence = !fence; next }
  inw && fence                        { next }
  inw && /<!--/                       { cmt = 1 }
  inw && cmt                          { if (/-->/) cmt = 0; next }
  inw                                 { print }
  /^###[[:space:]]*Step 0:/           { inw = 1 }
' "$ROUTE")"

a10=0
if [ -n "$W10" ]; then
  # Every token on ONE line: the program, the flag, and the cell the flag is
  # fed from. Split across three sentences they can each be about something
  # else -- a bare see-also list carries all three and instructs nothing.
  CAND10="$(awk '/wait-for-deliverable\.sh/ && /--since/ && /dispatched-at/' <<<"$W10")"
  if [ -n "$CAND10" ]; then
    # NON-NEGATION, read off the clause BEFORE the program name. Padded with
    # spaces and lowercased so `not` inside `nothing` or `cannot` is not a
    # match. A here-string throughout: `printf ... | grep -q` reports
    # NOT-FOUND on matching input once the writer fills the pipe (I54/I54b).
    while IFS= read -r l10; do
      [ -n "$l10" ] || continue
      pre10="$(awk '{ i = index($0, "wait-for-deliverable.sh"); print substr($0, 1, i - 1) }' <<<"$l10" \
               | tr '[:upper:]' '[:lower:]')"
      case " $pre10 " in
        *' not '*|*' never '*|*' do not '*|*' never run '*) continue ;;
      esac
      a10=1
    done <<<"$CAND10"
  fi
fi
if [ "$a10" -eq 1 ]; then
  ok "A10 Step 0 arms the beat by name: wait-for-deliverable.sh --since <dispatched-at>"
else
  bad "A10 Step 0 arms the beat by name: wait-for-deliverable.sh --since <dispatched-at>"
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
