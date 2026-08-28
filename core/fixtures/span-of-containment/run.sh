#!/usr/bin/env bash
# `span_of` is the shared oracle, and it had ONE other test.
#
# WHY THIS EXISTS. `lib.sh` states that `span_of` is THE matcher and that keeping a second copy
# is how the v0.52.0 and v0.54.2 divergences happened -- so everything that needs a section's
# line range asks this one function. By v0.431.0 that included a shipped fixture, the reference
# consumer's own `verify:` receipt, and a release's correctness claim, all three agreeing
# because they put the same question to the same function. **None of them can catch a defect IN
# it.** Measured at that release: exactly 2 of 146 shippable fixture directories exercised
# `span_of` at all, and one of them was the new arrival.
#
# This unit tests the function itself, on seeds that state the RULE rather than restating a
# caller's expectation. The properties are `lib.sh:70-83`'s own: a span ends at the next heading
# of level <= its own, a DEEPER heading does not end it, the match is containment in either
# direction with a length floor on the reverse arm, headings are normalised before comparison,
# and an unclosed section runs to EOF.
#
# THE SEEDS ARE NOT DRAWN FROM ANY CALLER. `fixture-mutants.md` forbids seeding from what the
# reader accepts; a seed lifted from `retro.md` would prove `span_of` handles `retro.md` and
# nothing more. These are minimal documents built to separate one rule per case.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

LIB=""; LOOKED=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/lib.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/lib.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/lib.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && LIB="$cand" && break
done
[ -n "$LIB" ] || { printf 'FAIL: cannot locate lib.sh from %s. Looked in:\n%s' "$DIR" "$LOOKED"; exit 1; }

# shellcheck source=/dev/null
. "$LIB" || { echo "FAIL: could not source $LIB"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILURES=0
ASSERTIONS=0
ok()  { ASSERTIONS=$((ASSERTIONS + 1)); printf '  ok    %-30s %s\n' "$1" "$2"; }
bad() { ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1)); printf '  FAIL  %-30s %s\n' "$1" "$2"; }

# want <name> <heading> <file> <expected-span> <why>
want() {
  local n="$1" h="$2" f="$3" e="$4" why="$5" got
  got="$(span_of "$h" < "$f")"
  if [ "$got" = "$e" ]; then ok "$n" "'$h' -> [$got]  ($why)"
  else bad "$n" "'$h' -> [${got:-<empty>}], want [$e]  ($why)"; fi
}

# --- the corpus -------------------------------------------------------------------------
# Deliberately minimal and one rule per document, so a failure names its own cause.
cat > "$TMP/nest.md" <<'EOF'
## Top
line
### Step One
body of step one
#### Child Of One
this child must NOT end step one
### Step Two
body of step two
## Another Top
EOF

cat > "$TMP/eof.md" <<'EOF'
## Only
### Last Section
runs to the end
with no closing heading
EOF

cat > "$TMP/norm.md" <<'EOF'
### `## Ticked Heading` — with a suffix
body
### Plain
EOF

# --- ARM 1: a DEEPER heading does not end a span ----------------------------------------
# This is the rule the v0.431.0 promotion turned on, and the one no other unit states.
want nesting-deeper-does-not-end 'Step One' "$TMP/nest.md" '3 6' \
  'the #### child at 5 is inside; the sibling ### at 7 ends it'

# --- ARM 2: an EQUAL-level heading DOES end a span --------------------------------------
want nesting-equal-ends 'Step Two' "$TMP/nest.md" '7 8' \
  'ended by the shallower ## at 9, not carried past it'

# --- ARM 3: a parent span SWALLOWS every deeper heading under it -------------------------
# The mirror of ARM 1 and the property the v0.431.0 promotion turned on: `## Top` is not ended
# by the ### or #### headings beneath it, so its span covers them all and stops only at the
# next ##. This is exactly why a shadow of a parent section displaces its children.
want nesting-parent-swallows 'Top' "$TMP/nest.md" '1 8' \
  'neither the ### at 3/7 nor the #### at 5 ends it; the ## at 9 does'

# --- ARM 4: an unclosed section runs to EOF ---------------------------------------------
want runs-to-eof 'Last Section' "$TMP/eof.md" '2 4' \
  'END block prints start..NR when no closing heading appears'

# --- ARM 5: normalisation — backticks and case are stripped before comparison ------------
want normalised-backticks 'ticked heading' "$TMP/norm.md" '1 2' \
  'nrm() lowercases and strips backticks, so a plain lowercase query matches a ticked title'

# --- ARM 6: the REVERSE containment arm, and its length floor ----------------------------
# `index(w, h) > 0` lets a LONGER query match a SHORTER heading, but only when the heading is
# longer than 3 characters. Both halves matter: without the arm a caller quoting a fuller title
# finds nothing; without the floor a 1-2 character heading matches almost any query.
want reverse-containment 'Plain and then some' "$TMP/norm.md" '3 3' \
  'query CONTAINS the heading: the index(w,h) arm, with the heading over the length floor'

# --- ARM 7: no match is EMPTY, not a span -----------------------------------------------
got="$(span_of 'No Such Heading Anywhere' < "$TMP/nest.md")"
if [ -z "$got" ]; then ok "no-match-is-empty" "an absent heading yields no span, so a caller can tell 'missing' from 'line 1'"
else bad "no-match-is-empty" "absent heading yielded [$got] — a caller cannot distinguish missing from found"; fi

# --- ARM 8: the MUTANT. Break the level rule and require ARM 1 to notice -----------------
# ARM 1 is the only arm whose subject is the <= comparison, so it is the one a mutant must
# move. Built as a copy, guarded with cmp -s, and sourced in a SUBSHELL so the real span_of is
# not clobbered for the arms above.
MUT="$TMP/lib-mutated.sh"
sed 's/if (lvl <= mylvl)/if (lvl < mylvl)/' "$LIB" > "$MUT"
if cmp -s "$LIB" "$MUT"; then
  bad "mutant-applied" "the level-rule sed matched nothing — `lib.sh` was not mutated and the arm below would score a kill it did not earn"
else
  ok "mutant-applied" "level rule <= weakened to < in the copy"
  mgot="$( . "$MUT" >/dev/null 2>&1; span_of 'Step One' < "$TMP/nest.md" )"
  if [ "$mgot" != '3 6' ]; then
    ok "mutant-killed" "mutated copy answers [${mgot:-<empty>}] for 'Step One', not 3 6 — ARM 1 discriminates"
  else
    bad "mutant-killed" "mutated copy still answers 3 6 — ARM 1 cannot tell the level rule from its own absence"
  fi
fi

# --- ARM 9: unmutated control, with a POSITIVE conjunct ---------------------------------
CTL="$TMP/lib-control.sh"
cp "$LIB" "$CTL"
cgot="$( . "$CTL" >/dev/null 2>&1; span_of 'Step One' < "$TMP/nest.md" )"
if [ "$cgot" = '3 6' ]; then
  ok "unmutated-control" "byte-identical copy reproduces [3 6] — a copy that died sourcing would answer empty and score as a kill"
else
  bad "unmutated-control" "byte-identical copy answered [${cgot:-<empty>}], want [3 6] — the harness is what failed, not the subject"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
