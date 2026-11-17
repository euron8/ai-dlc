#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# layer-retired-id-crosswalk — E16: an id that LEFT the rulebook needs a crosswalk row.
#
# THE ASSERTION. The migration LC-N5 requires renames consumer ids into the band. Every
# renamed id is a bare `Check N` already written into a gate log, and a gate log is the
# durable audit record — no rename reaches back into it. The crosswalk row is the only
# thing that keeps the citation resolvable, and E16 is what makes the row mandatory for
# the one case core can actually evaluate: an id leaving the rendered rulebook, read from
# the consumer's own history.
#
# WHAT SEPARATES THIS FROM A COUNT OF MISSING ROWS. The first cut of the arm asked "did
# an id leave THIS entry" and reported 32 subjects on the reference consumer, 25 of them
# wrong. Every wrong one was an entry that had stopped RESTATING a core section: nothing
# was retired, because core still defines the id and the citation still lands. So the
# seed carries all three cases and the fixture scores them as one vector — an arm that
# reports the retired id but also reports the two resolvable ones has not passed.
#
#   33  renamed to 934, defined nowhere now      -> REPORTED
#   34  moved to a SIBLING entry                 -> silent, the catalog still defines it
#   5   dropped, but CORE defines 5              -> silent, core is the source of truth
#   933 never retired                            -> silent, the liveness control
#
# Usage: run.sh [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS. install.sh splits what shares a parent here: core/fixtures/ becomes
# tests/fixtures/ and core/scripts/ becomes scripts/ai-dlc/. Every candidate is rooted at
# this file's own location — I33 fails the build on a fixture that reaches a core subtree
# by walking up from a path some other resolver produced.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "${1:-}" "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh from $HERE" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"
[ -f "$(dirname "$LINTER")/artifact-path-config.sh" ] && echo "HERMETIC-CONSUMED core/scripts/artifact-path-config.sh"

# IN PROCESS (BL-878). The validator is SOURCED ONCE into this shell (its guard returns after defining vle_main), and
# every drive calls vle_main inside the subshell of the `$( )` that captures it, so its `exit`, `set -u`, EXIT trap and
# function definitions stay there. It starts as a program only in the cli cells (cells.decl). A CORE FIXTURE SHIPS
# AHEAD OF ITS SUBJECT: a subject with neither its `vle_main() {` line nor the column-0 source guard predates the wrap
# and reads SKIP (exit 0, never an ok); exactly one half is a respelled subject and FAILs; a subject grep cannot READ
# (exit 2) is FIXTURE ERROR.
wrap_gate() { # wrap_gate <file> <entry> -> 0 wrapped, 3 predates the wrap, 1 one half only (FAIL printed), 2 unreadable
  local d g
  grep -q "^$2() {\$" "$1"; d=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; g=$?
  if [ "$d" -gt 1 ] || [ "$g" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $d/$g), so the in-process wrap cannot be judged; nothing was asserted" >&2
    return 2
  fi
  [ "$d$g" = 00 ] && return 0
  [ "$d$g" = 11 ] && return 3
  if [ "$d" = 1 ]; then echo "  FAIL  $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"
  else echo "  FAIL  $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; fi
  return 1
}
wrap_gate "$LINTER" vle_main; g_vle=$?
[ "$g_vle" = 2 ] && exit 2
[ "$g_vle" = 1 ] && { echo "layer-retired-id-crosswalk: 1 FAILED"; exit 1; }
[ "$g_vle" = 3 ] && { echo "SKIP: subject predates the in-process wrap"; exit 0; }

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
CONS="$ROOT/consumer"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
fx_inproc "$LINTER"
. "$LINTER" || { echo "FIXTURE ERROR: sourcing $LINTER failed" >&2; exit 2; }
declare -F vle_main > /dev/null || { echo "FIXTURE ERROR: sourcing $LINTER defined no vle_main" >&2; exit 2; }

# EXPECTED_ASSERTIONS is not bookkeeping: counting what actually ran is what stops an arm
# that silently did not execute from reading as a short green run, and the count is a
# literal here or it disappears with the assertions.
# 2 premises + 1 pristine vector + 1 remedy + 2 shallow + 1 exit condition + 2 vacuity arms
# (no entries vs entries-but-no-resolvable-set).
EXPECTED_ASSERTIONS=11

echo "layer-retired-id-crosswalk:"

# vector <linter> <root> -> "33=<R|-> 34=<R|-> 5=<R|-> 933=<R|-> guard=<n>"
# A cell is R when the arm names that id as retired-without-a-row. `guard` is the count
# from the refusal line, so a run that refused and a run that found nothing are different
# values rather than the same silence.
vector() {
  local out cell v=''
  out="$( ( fx_inproc "$1"; vle_main "$2" ) 2>&1)"
  for id in 33 34 5 933; do
    cell='-'
    grep -qF "used to define '$id' and no longer does" <<<"$out" && cell=R
    v="$v${v:+ }$id=$cell"
  done
  local g
  g="$(grep -oE 'could not be evaluated for [0-9]+ entr' <<<"$out" | grep -oE '[0-9]+')"
  printf '%s guard=%s' "$v" "${g:-0}"
}

WANT='33=R 34=- 5=- 933=- guard=0'

# --- Part 0: the seed's premises, measured WITHOUT the code under test ----------
# "33 used to be defined and is not now" and "34 moved to a sibling" are this fixture's
# premises, and reading them back through the arm being tested would make the premise and
# the conclusion one measurement — an extractor that returned nothing would report every
# id retired AND satisfy every assertion below.
head_at() { # head_at <ref> <path> <id>
  git -C "$CONS" show "$1:$2" 2>/dev/null | grep -cE "^#{2,4}[[:space:]]+(Check[[:space:]]+)?$3[[:space:]]*(\.|—)"
}
C1="$(git -C "$CONS" rev-list --max-parents=0 HEAD)"
EP='.claude/skills/ai-dlc/extensions/checks/domain.md'
SP='.claude/skills/ai-dlc/extensions/checks/sibling.md'
if [ "$(head_at "$C1" "$EP" 33)" = 1 ] && [ "$(head_at HEAD "$EP" 33)" = 0 ]; then
  ok "premise: '33' is defined at the first commit and gone at HEAD (there is a retirement to find)"
else
  bad "premise: '33' is not defined-then-gone across this seed's history, so the whole fixture is measuring nothing. Got first=$(head_at "$C1" "$EP" 33) head=$(head_at HEAD "$EP" 33)."
fi
if [ "$(head_at "$C1" "$SP" 34)" = 0 ] && [ "$(head_at HEAD "$SP" 34)" = 1 ]; then
  ok "premise: '34' really did MOVE to the sibling entry (so its silence is earned, not absence)"
else
  bad "premise: '34' did not move to the sibling across this seed's history. Without the move, '34' being silent proves nothing about the resolvability set."
fi

# --- Part 1: the shipped verdict ------------------------------------------------
GOT="$(vector "$LINTER" "$CONS")"
if [ "$GOT" = "$WANT" ]; then
  ok "E16 — the arm reports the retired id and NEITHER resolvable one"
else
  bad "the retired-id vector moved.
          got  '$GOT'
          want '$WANT'
        33 is defined nowhere now and must report. 34 moved to a sibling and 5 is core's — both citations still land, and reporting either is the 25-of-32 false-positive shape this arm was corrected for. 933 was never retired; a cell there means the historical set is being read as the retired set. guard>0 means the arm refused instead of running."
fi

# --- Part 2: the remedy closes its own report ------------------------------------
# A finding whose prescribed fix does not clear it is a remedy that does not remedy —
# this repo has shipped that exact defect in this exact file (`heading_labelled`'s header
# records it). Adding the row the message asks for must produce the clean vector.
FIX="$ROOT/fixed"; rm -rf "$FIX"; cp -R "$CONS" "$FIX"
printf '%s\n' '| 33 | `[ext:domain]` | Cross-story test-strategy deliverable presence | (pre-band allocation) | renamed to 934 |' \
  >> "$FIX/.claude/skills/ai-dlc/extensions/README.md"
FIXED="$(vector "$LINTER" "$FIX")"
if [ "$FIXED" = '33=- 34=- 5=- 933=- guard=0' ]; then
  ok "E16 — adding the crosswalk row the message asks for CLEARS the finding"
else
  bad "adding the row did not clear the finding (got '$FIXED'). The remedy the message prescribes cannot be applied to clear the message, which is the 'remedy that does not remedy' defect this file's own heading_labelled header records."
fi

# --- Part 3: the zero guard ------------------------------------------------------
# A shallow clone's id history is truncated at the graft boundary, so an id retired
# before it is invisible — and an invisible retirement and no retirement produce the same
# empty set, which is this arm's PASS. It must refuse instead, and say which condition it
# hit, or a truncated run is indistinguishable from a clean one.
SH="$ROOT/shallow"; rm -rf "$SH"
if git clone -q --depth 1 "file://$CONS" "$SH" 2>/dev/null && \
   [ "$(git -C "$SH" rev-parse --is-shallow-repository)" = true ]; then
  SHOUT="$( ( fx_inproc "$LINTER"; vle_main "$SH" ) 2>&1)"
  if grep -q 'RETIRED-ID HISTORY UNREADABLE' <<<"$SHOUT"; then
    ok "on a SHALLOW clone the arm REFUSES rather than reporting the tree clean"
  else
    bad "the arm was silent on a shallow clone. A truncated id history and a clean one now produce identical output — the defect this guard exists to end."
  fi
  if grep -q 'SHALLOW clone' <<<"$SHOUT"; then
    ok "  and it names the shallow condition specifically, not a generic reason"
  else
    bad "  but it did not name the shallow condition, so the operator cannot tell which of the three unreadable cases they are in — and only one of them is fixed by 'git fetch --unshallow'."
  fi
else
  bad "FIXTURE: could not build a shallow clone of the seed, so the zero guard is UNTESTED. Do not read the assertions above as covering it."
  bad "FIXTURE: shallow-reason assertion skipped for the same reason."
fi

# --- Part 5: the migration's EXIT CONDITION --------------------------------------
#
# Every assertion above is "this arm fires". None of them says the migration TERMINATES.
# A partition that reports 49 subjects and a crosswalk arm that reports 4 are both
# consistent with a tree that can never be made clean — and a rule an author cannot
# satisfy is one they turn off, which is worse than no rule. So: migrate this consumer
# to completion, by hand, exactly as the messages prescribe, and require exit 0.
#
# This is the only assertion in the suite that says the standard is SATISFIABLE.
MIG="$ROOT/migrated"; rm -rf "$MIG"; cp -R "$CONS" "$MIG"
MSK="$MIG/.claude/skills/ai-dlc"
# Rename every out-of-band id into the band, as E15's own remedies say to.
sed -i.bak 's|^### 70\.|### 970.|; s|^### 34\.|### 935.|' "$MSK/extensions/checks/sibling.md"
rm -f "$MSK/extensions/checks/sibling.md.bak"
# ...and add a crosswalk row for every id that rename retires, plus the pre-existing 33.
{ printf '%s\n' '| 33 | `[ext:domain]` | Cross-story test-strategy deliverable presence | (pre-band allocation) | renamed to 934 |'
  printf '%s\n' '| 34 | `[ext:sibling]` | Passive-monitor carry-over ceilings | (pre-band allocation) | renamed to 935 |'
  printf '%s\n' '| 70 | `[ext:sibling]` | A sibling entry own allocation | (pre-band allocation) | renamed to 970 |'
} >> "$MSK/extensions/README.md"
git -C "$MIG" add -A >/dev/null 2>&1
GIT_AUTHOR_DATE='2026-06-20T09:00:00+00:00' GIT_COMMITTER_DATE='2026-06-20T09:00:00+00:00' \
  git -C "$MIG" -c user.email=fixture@example.invalid -c user.name=fixture \
    commit -q --no-verify -m 'migrate every id into the band and file its crosswalk row' >/dev/null 2>&1
MIGOUT="$( ( fx_inproc "$LINTER"; vle_main "$MIG" ) 2>&1)"; MIGRC=$?
if [ "$MIGRC" -eq 0 ]; then
  ok "a consumer migrated to completion exits 0 — the standard is SATISFIABLE, not just enforced"
else
  bad "a FULLY migrated consumer still fails (rc=$MIGRC). Every id is in band and every retired id has a crosswalk row, so if this does not exit 0 the rules cannot all be satisfied at once and an author's only way to clear the linter is to switch it off:
$(grep '^ERROR' <<<"$MIGOUT" | sed 's/^/        /' | cut -c1-200)"
fi

# --- E16's VACUITY ARM, BOTH DIRECTIONS -------------------------------------------------
#
# THE DEFECT THESE TWO ARMS SHIPPED FOR, and it is a FALSE POSITIVE where this repo's named
# class usually produces a false zero. E16 refuses to answer when the resolvability set it
# builds comes out empty, because an empty set makes every historical id read as retired. That
# guard was keyed on the SET being empty and nothing else — so it also fired on a consumer that
# has just run the installer and has no layer entries at all. Measured on a tree built by
# running scripts/install.sh into an empty directory: `1 error(s)`, EXIT 1, from a census cell
# reading `E16=LC-N6:1/0` — a clause firing once against a subject population of zero. A fresh
# install's pre-push refused, and a bare `1 error(s)` on a new tree reads like any other error.
#
# The two states are opposite and the old arm could not tell them apart: "no subject" versus
# "could not read the subject". So both are asserted here, together, because fixing the first
# by deleting the guard would silently take the second with it — and the second is the one the
# arm was written for.

# ARM A — a consumer with NO layer entries is not an error. This is the shape install.sh
# produces: the contract present, the two layer directories empty.
NEW="$ROOT/new-consumer"
mkdir -p "$NEW/.claude/skills/ai-dlc/extensions" "$NEW/.claude/skills/ai-dlc/overrides"
cp "$CONS/.claude/skills/ai-dlc/layer-contract.yaml" "$NEW/.claude/skills/ai-dlc/layer-contract.yaml"
NEWOUT="$( ( fx_inproc "$LINTER"; vle_main "$NEW" ) 2>&1)"; NEWRC=$?
# ANCHORED TO THE FINDING LINE, NOT TO THE TOKEN. A bare `grep E16` is satisfied by the
# LAYER_MEASURED census, which names every code every run — including `E16=LC-N6:0/0`, the
# cell that says it did NOT fire. The first draft of this assertion did exactly that and
# reported a failure against a clean tree.
if [ "$NEWRC" -eq 0 ] && ! grep -qE '^ERROR[[:space:]]+E16' <<<"$NEWOUT"; then
  ok "E16 — a consumer with ZERO layer entries exits 0: an empty set with no subject is not an unreadable one"
else
  bad "E16 fired on a brand-new consumer (rc=$NEWRC). A tree straight out of the installer has no entries, so its resolvability set is empty BECAUSE there is nothing to resolve — and its pre-push now refuses on a finding about ids it has never written:
$(grep '^ERROR' <<<"$NEWOUT" | sed 's/^/        /' | cut -c1-200)"
fi

# ARM B — THE ANTI-SILENCING HALF, and it is what makes arm A a fix rather than a deletion.
# Entries PRESENT and the resolvability set still empty is the case the guard exists for: the
# arm cannot be trusted in either direction, so it must refuse. The entry below is well-formed
# and defines no anchor or rule of its own, and it hooks a core file that defines none either.
BLIND="$ROOT/blind-consumer"
mkdir -p "$BLIND/.claude/skills/ai-dlc/steps" "$BLIND/.claude/skills/ai-dlc/extensions/checks" \
         "$BLIND/.claude/skills/ai-dlc/overrides"
cp "$CONS/.claude/skills/ai-dlc/layer-contract.yaml" "$BLIND/.claude/skills/ai-dlc/layer-contract.yaml"
BCV="$(awk '/^contract_version:/{print $2; exit}' "$BLIND/.claude/skills/ai-dlc/layer-contract.yaml")"
cat > "$BLIND/.claude/skills/ai-dlc/steps/prose-only.md" <<'BCORE'
---
name: prose-only
description: a core file that defines no numbered section and no rule
---

# Prose only

Nothing here is a numbered heading, so it contributes no anchor and no rule.
BCORE
cat > "$BLIND/.claude/skills/ai-dlc/extensions/checks/prose-only-domain.md" <<BEXT
---
kind: check
id: prose-only-domain
conforms_to: ${BCV}
hooks: steps/prose-only.md
push_candidate: false
---

## Prose only, extended

This entry allocates no id of its own either, so together with its hooked core file
the resolvability set comes out empty while an entry plainly exists.
BEXT
BLINDOUT="$( ( fx_inproc "$LINTER"; vle_main "$BLIND" ) 2>&1)"; BLINDRC=$?
if grep -qE '^ERROR[[:space:]]+E16' <<<"$BLINDOUT" && [ "$BLINDRC" -ne 0 ]; then
  ok "E16 — entries PRESENT and the resolvability set still empty is STILL an error (the guard was narrowed, not deleted)"
else
  bad "E16 stayed silent on a consumer that HAS an entry and still built an empty resolvability set (rc=$BLINDRC). That is the unreadable case the arm exists for, and fixing the fresh-install false positive has taken it with it — every historical id would read as retired and the arm would report clean doing it."
fi

# The cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome this fixture reads (exit 1
# the seeded consumer with its retired id, exit 0 the migrated one), each compared byte for byte with the in-process
# call on the same input (stdout, stderr and exit separately) and asserting its own outcome.
EQ="$ROOT/eq"; mkdir -p "$EQ" || exit 2
eqv() { # eqv <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the two answers are identical
  local id="$1"; shift
  ( fx_inproc "$LINTER"; vle_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$LINTER" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(tail -2 "$EQ/$1.ip.out")" "$(head -2 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(tail -2 "$EQ/$1.cl.out")" "$(head -2 "$EQ/$1.cl.err")"; }
if eqv cli-fail "$CONS" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] && grep -qF "used to define '33' and no longer does" "$EQ/cli-fail.cl.out"; then
  ok "cli-fail: the program reports the retired id exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 naming the retired '33' ($(eq_twin cli-fail))"; fi
if eqv cli-pass "$MIG" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && grep -q '^LAYER_CONFORMANCE v1 .* errors=0 ' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program passes the migrated consumer exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with errors=0 ($(eq_twin cli-pass))"; fi

echo
report_end layer-retired-id-crosswalk "$EXPECTED_ASSERTIONS"
