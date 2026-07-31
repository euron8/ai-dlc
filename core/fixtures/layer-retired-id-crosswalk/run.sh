#!/usr/bin/env bash
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

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
CONS="$ROOT/consumer"

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

# EXPECTED_ASSERTIONS is not bookkeeping. A sibling fixture lost an entire mutant to a
# missing space in a helper call: `set -u` killed the `$( )` subshell, `if m="$( … )"`
# read that as a false branch, and the arm silently did not run — green lines, a PASS,
# and the mutant proving the load-bearing branch gone. Counting what actually ran is what
# closes it, and the count is a literal here or it disappears with the assertions.
# 2 premises + 1 pristine vector + 1 remedy + 2 shallow + 1 control + 4 mutants + 1 exit
# condition + 2 vacuity arms (no entries vs entries-but-no-resolvable-set).
EXPECTED_ASSERTIONS=14

echo "layer-retired-id-crosswalk:"

# vector <linter> <root> -> "33=<R|-> 34=<R|-> 5=<R|-> 933=<R|-> guard=<n>"
# A cell is R when the arm names that id as retired-without-a-row. `guard` is the count
# from the refusal line, so a run that refused and a run that found nothing are different
# values rather than the same silence.
vector() {
  local out cell v=''
  out="$(bash "$1" "$2" 2>&1)"
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
  git -C "$CONS" show "$1:$2" 2>/dev/null | grep -cE "^#{2,4}[[:space:]]+(Check[[:space:]]+)?$3[[:space:]]*[.—]"
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
  SHOUT="$(bash "$LINTER" "$SH" 2>&1)"
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

# --- Part 4: mutants -------------------------------------------------------------
# COPIES, never in-place edits, each `cmp -s`-guarded so a sed that matched nothing
# cannot pass as a mutation. The unmutated control runs FIRST: every assertion below is
# "this cell moved", and a copy that dies on startup moves every cell at once, which
# would score as a kill for all four.
MDIR="$ROOT/mutants"; mkdir -p "$MDIR"
cp "$LINTER" "$MDIR/control.sh"
CTRL="$(vector "$MDIR/control.sh" "$CONS")"
if [ "$CTRL" = "$WANT" ]; then
  ok "CONTROL: an unmutated copy reproduces the shipped vector (the mutants below run against a live linter)"
else
  bad "CONTROL FAILED — an unmutated COPY reports '$CTRL', not '$WANT'. Every mutant below would be scored against a linter that is not working."
fi

mutant() { # mutant <label> <sed> <want-vector> <root> <why>
  local label="$1" prog="$2" want="$3" root="$4" why="$5" f="$MDIR/m.sh" got
  sed "$prog" "$LINTER" > "$f"
  if cmp -s "$LINTER" "$f"; then
    bad "MUTATION VACUOUS ($label) — the sed matched nothing, so the assertion below would score an unchanged run as a kill"
    return
  fi
  got="$(vector "$f" "$root")"
  if [ "$got" = "$want" ]; then
    ok "MUTANT killed: $label"
  else
    bad "MUTANT '$label' did not produce its expected vector, so what it proves is unproven.
          got  '$got'
          want '$want'
        $why"
  fi
}

# M1 — the row lookup is what decides, not the retirement alone. Making every id look
# already-rowed must silence the one real finding and nothing else.
mutant "making the crosswalk lookup always match silences the retired id" \
  's|^          grep -Fxq -- "\$_rid" <<<"\$CROSSWALK_IDS" && continue|          true \&\& continue|' \
  '33=- 34=- 5=- 933=- guard=0' "$CONS" \
  "If 33 still reports, the arm is not consulting the table at all and adding a row could never clear it."

# M2 — the resolvability set is load-bearing. Narrowing it back to the entry's own ids
# must make BOTH resolvable cells report, and must not touch 933.
mutant "narrowing the resolvability set back to the entry's own ids reports both resolvable cells" \
  's|_now="\$LIVE_ANCHORS";|_now="$_mine";|' \
  '33=R 34=R 5=R 933=- guard=0' "$CONS" \
  "34 moved to a sibling and 5 is core's. This is the exact 25-of-32 false-positive set the arm was corrected for, and if this mutant does not reproduce it the correction is not what is keeping them quiet."

# M3 — the SHALLOW DETECTION is a real branch, and it is a positive test rather than an
# inference from an empty answer. Forcing it to `ok` makes the arm read the truncated
# history as if it were complete, and a depth-1 clone then yields exactly the ids the
# working tree already has: nothing retired, nothing refused, a clean bill of health for
# a tree whose retirement is simply not visible. That is the state the guard exists to
# make impossible, and it is what this mutant must produce.
#
# WORTH RECORDING: the first version of this mutant knocked out the PER-FILE guard
# instead and the shallow tree still refused — because two different branches produce a
# refusal and only one of them is reachable here. A mutant that fails to move its cell is
# telling you the arm it named is not the arm under test.
if [ -d "$SH" ]; then
  mutant "forcing the shallow probe to 'ok' makes a truncated history report CLEAN" \
    's|^    CROSSWALK_STATE=shallow$|    CROSSWALK_STATE=ok|' \
    '33=- 34=- 5=- 933=- guard=0' "$SH" \
    "If the guard count stays above 0, the refusal on a shallow clone is coming from somewhere other than the shallow probe, and the probe is decoration. If a cell reports R, the truncated run is inventing a retirement."
else
  bad "MUTANT m3 SKIPPED — no shallow clone was built, so the zero guard's branch is unproven."
fi

# M4 — the historical read is what supplies the subject. Emptying it must BOTH silence
# the finding and trip the guard, because an entry that defines ids whose history yields
# none of them is exactly the unreadable case. Two cells move together and that pairing
# is the point: a mutation that only silenced the finding would be M1.
mutant "emptying the historical read silences the finding AND trips the guard" \
  's|^  git -C "\$PROJECT_ROOT" log -p --format=.. -- "\$1" 2>/dev/null . sed -n .s/\^+//p. > "\$tmp"|  : > "$tmp"|' \
  '33=- 34=- 5=- 933=- guard=2' "$CONS" \
  "If the guard does NOT trip, an entry whose id history is unreadable reports clean — the defect the whole arm is built around, reproduced inside it."

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
MIGOUT="$(bash "$LINTER" "$MIG" 2>&1)"; MIGRC=$?
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
NEWOUT="$(bash "$LINTER" "$NEW" 2>&1)"; NEWRC=$?
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
BLINDOUT="$(bash "$LINTER" "$BLIND" 2>&1)"; BLINDRC=$?
if grep -qE '^ERROR[[:space:]]+E16' <<<"$BLINDOUT" && [ "$BLINDRC" -ne 0 ]; then
  ok "E16 — entries PRESENT and the resolvability set still empty is STILL an error (the guard was narrowed, not deleted)"
else
  bad "E16 stayed silent on a consumer that HAS an entry and still built an empty resolvability set (rc=$BLINDRC). That is the unreadable case the arm exists for, and fixing the fresh-install false positive has taken it with it — every historical id would read as retired and the arm would report clean doing it."
fi

echo
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "layer-retired-id-crosswalk: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. An arm did not execute at all, which is not the same as an arm that passed. Find the one that vanished before reading anything above as green."
  exit 1
fi
if [ "$fails" -eq 0 ]; then
  echo "layer-retired-id-crosswalk: PASS ($made assertions)"
  exit 0
fi
echo "layer-retired-id-crosswalk: $fails of $made assertion(s) failed"
exit 1
