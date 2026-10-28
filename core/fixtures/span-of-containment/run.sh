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
#
# THE MUTANT MATRIX. The level-rule mutant is scored per push on its DECIDING arm (nesting-deeper-does-not-end)
# and its named TWIN (nesting-equal-ends), which the mutant must leave GREEN: it changes how a span is closed by
# a DEEPER heading, not by an equal-level one that sits under a shallower heading. `run.sh --matrix` scores the
# mutant against all seven span arms and prints one MATRIX line. The matrix is re-measured whenever an arm or a
# mutant is added or changed, by the REMEASURE command below, run from the repo root.
# also trips: level-rule -> nesting-parent-swallows,normalised-backticks
# MUTANT-MATRIX level-rule decides=nesting-deeper-does-not-end twins=nesting-equal-ends
# MUTANT-MATRIX-REMEASURE bash core/fixtures/span-of-containment/run.sh --matrix
set -u
MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "span-of-containment: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac
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
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILURES=0
ASSERTIONS=0
# Two-argument reporters under set -u: lib/mutant.sh calls them with ONE argument.
ok()  { ASSERTIONS=$((ASSERTIONS + 1)); printf '  ok    %-30s %s\n' "$1" "${2-}"; }
bad() { ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1)); printf '  FAIL  %-30s %s\n' "$1" "${2-}"; }
MUT_LIB="$DIR/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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
# This is the deciding arm of the level-rule mutant, so it sets the same-run base-pass flag in its passing
# branch (inlined from want(), whose generic reporter carries no flag).
got="$(span_of 'Step One' < "$TMP/nest.md")"
if [ "$got" = '3 6' ]; then ok nesting-deeper-does-not-end "'Step One' -> [$got]  (the #### child at 5 is inside; the sibling ### at 7 ends it)"; B_arm1=1
else bad nesting-deeper-does-not-end "'Step One' -> [${got:-<empty>}], want [3 6]  (the #### child at 5 is inside; the sibling ### at 7 ends it)"; fi

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
#
# mx_span <lib> <arm> -> the span that arm asks of the lib, one cell of the matrix.
mx_span() {
  ( . "$1" >/dev/null 2>&1
    case "$2" in
      nesting-deeper-does-not-end) span_of 'Step One' < "$TMP/nest.md" ;;
      nesting-equal-ends)          span_of 'Step Two' < "$TMP/nest.md" ;;
      nesting-parent-swallows)     span_of 'Top' < "$TMP/nest.md" ;;
      runs-to-eof)                 span_of 'Last Section' < "$TMP/eof.md" ;;
      normalised-backticks)        span_of 'ticked heading' < "$TMP/norm.md" ;;
      reverse-containment)         span_of 'Plain and then some' < "$TMP/norm.md" ;;
      no-match-is-empty)           span_of 'No Such Heading Anywhere' < "$TMP/nest.md" ;;
    esac )
}
mx_want() {
  case "$1" in
    nesting-deeper-does-not-end) echo '3 6' ;;  nesting-equal-ends) echo '7 8' ;;
    nesting-parent-swallows) echo '1 8' ;;      runs-to-eof) echo '2 4' ;;
    normalised-backticks) echo '1 2' ;;         reverse-containment) echo '3 3' ;;
    no-match-is-empty) echo '' ;;
  esac
}
MXL="$TMP/mx.ledger"; : > "$MXL"
mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  local n="$1" f="$2" l w c=0 v=""
  while IFS= read -r l; do
    case "$l" in
      "# MUTANT-MATRIX $n "*)
        c=$((c + 1))
        for w in ${l#"# MUTANT-MATRIX $n "}; do case "$w" in "$f="*) v="${w#"$f="}" ;; esac; done ;;
    esac
  done < "$DIR/run.sh"
  [ "$c" -eq 1 ] && printf '%s' "$v"
}
mx_count() { local k="$1" l n=0; while IFS= read -r l; do case "$l" in "$k "*) n=$((n + 1)) ;; esac; done < "$MXL"; printf '%s' "$n"; }
# mx_red <lib> <arm> -> 0 when the arm FAILS on that lib (RED), 1 when it holds (GREEN). A crashed cell is BROKEN, never GREEN.
mx_red() {
  local g; g="$(mx_span "$1" "$2" 2>"$TMP/mx.err")"
  case "$(cat "$TMP/mx.err")" in *"unbound variable"*|*"command not found"*|*"syntax error"*) echo "MATRIX BROKEN $2"; exit 2 ;; esac
  [ "$g" != "$(mx_want "$2")" ]
}

MUT="$TMP/lib-mutated.sh"
sed 's/if (lvl <= mylvl)/if (lvl < mylvl)/' "$LIB" > "$MUT"
if cmp -s "$LIB" "$MUT"; then
  bad "mutant-applied" "the level-rule sed matched nothing — the lib was not mutated and the arm below would score a kill it did not earn"
else
  ok "mutant-applied" "level rule <= weakened to < in the copy"
  ARMS_ALL="nesting-deeper-does-not-end nesting-equal-ends nesting-parent-swallows runs-to-eof normalised-backticks reverse-containment no-match-is-empty"
  mdec="$(mx_row level-rule decides)"; mtw="$(mx_row level-rule twins)"
  if [ -z "$mdec" ] || [ -z "$mtw" ]; then bad "mutant-row" "no single MUTANT-MATRIX row names level-rule's deciding arm and twin"
  else
    printf 'dec level-rule %s\n' "$mdec" >> "$MXL"
    if mx_red "$MUT" "$mdec"; then dec_red=1; else dec_red=0; fi
    printf 'dec level-rule %s\n' "$mtw" >> "$MXL"
    if mx_red "$MUT" "$mtw"; then tw_red=1; else tw_red=0; fi
    mgot="$(mx_span "$MUT" nesting-deeper-does-not-end)"
    if [ "$dec_red" = 1 ]; then
      mutant_killed "${B_arm1:-0}" level-rule "mutant level-rule: mutated copy answers [${mgot:-<empty>}] for 'Step One', not 3 6 — ARM 1 discriminates"
    else
      bad "mutant level-rule SURVIVED: mutated copy still answers 3 6 — ARM 1 cannot tell the level rule from its own absence"
    fi
    if [ "$tw_red" = 1 ]; then bad "mutant level-rule: its twin $mtw also tripped — the mutant is not confined to its own arm"; fi
    if [ "$MODE" = matrix ]; then # mx-all-arms
      g=0; tot=0; rd=""
      for a in $ARMS_ALL; do
        if [ "$a" = "$mdec" ] || [ "$a" = "$mtw" ]; then continue; fi
        printf 'mx level-rule %s\n' "$a" >> "$MXL"
        tot=$((tot + 1)); if mx_red "$MUT" "$a"; then rd="$rd,$a"; else g=$((g + 1)); fi
      done
      d=GREEN; [ "$dec_red" = 1 ] && d=RED; t=GREEN; [ "$tw_red" = 1 ] && t=RED
      u=""; [ "$d" = GREEN ] && u=" UNEXPECTED=$mdec:GREEN"; [ "$t" = RED ] && u="$u UNEXPECTED=$mtw:RED"
      printf 'MATRIX level-rule decides=%s:%s twins=%s:%s others=%d/%d%s%s\n' "$mdec" "$d" "$mtw" "$t" "$g" "$tot" "${rd:+ red=${rd#,}}" "$u"
      if [ -n "$u" ]; then FAILURES=$((FAILURES + 1)); fi
    fi
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

# RULE 9: a plain run executes NO matrix-only cell. The deciding and twin cells write the same ledger, so
# an empty matrix count cannot come from a ledger nothing writes.
mx_only="$(mx_count mx)"; mx_ctl="$(mx_count dec)"
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9" "the matrix ledger control is EMPTY: no deciding or twin cell wrote to it, so a zero count of matrix-only cells means nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9" "a plain run executed $mx_only matrix-only cell(s) — the --matrix measurement leaked into the per-push run"
  else ok "rule-9" "a plain run executed no matrix-only cell, while $mx_ctl deciding or twin cell(s) wrote the same ledger"; fi
else
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
