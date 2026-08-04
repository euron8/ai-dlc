#!/usr/bin/env bash
# self-update-join-gate — prove the self-update gate refuses to cut a branch when the
# machinery slice cannot be green without the rulebook.
#
# THE DEFECT. Step 2 of ai-dlc-update installs MACHINERY and deliberately excludes the
# RULEBOOK, on the stated premise that "a fixture's subject is always machinery". That
# premise is false. Measured on the reference consumer pulling 0.249.0 -> 0.261.0, 7 of
# that tree's 109 fixtures are red in the state step 2 constructs, through two couplings:
# enforcement-map.yaml (machinery) is joined to CHECK_LOADED anchors in gate-validation.md
# (rulebook), and some fixtures assert on the shipped SKILL.md directly. The operator who
# hit this had to cut a branch, write 17 paths and run 43 fixtures to find out.
#
# THE ASSERTION THAT CARRIES THE RELEASE IS 3, NOT 1. An arm that defers whenever a fixture
# merely MENTIONS rulebook would defer on every pull, stranding the machinery slice for no
# reason — the exact false positive self-update-gate.sh's own header warns about. The arm
# is a DIFFERENTIAL: it fires only when the rulebook is ALSO about to change. Assertion 3
# is the one that proves it, and if it ever goes red this release has become the thing it
# was written to prevent.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"
GATE="$D_ROOT/core/skills/ai-dlc-update/reconcile/self-update-gate.sh"

# Distribution-only, and say WHY accurately. The gate IS shipped to consumers (it lands at
# .claude/skills/ai-dlc-update/reconcile/), so "not present" would be a false reason. What a
# consumer lacks is the distribution's GIT HISTORY: this fixture derives BASE and THEIRS from
# the commit that adds a CHECK_LOADED anchor and installs two consumer trees from those refs.
# A skip whose stated reason is wrong is worse than no skip — it sends the next reader after
# a file that is sitting right there.
if [ ! -f "$GATE" ] || [ ! -d "$D_ROOT/.git" ]; then
  echo "self-update-join-gate: SKIP — distribution-only (needs the distribution's git history to derive a check-adding range)"
  exit 0
fi

WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
echo "self-update-join-gate:"

run_gate() { bash "${1:-$GATE}" "$DIST" "$BASE" "$THEIRS" "$2" 2>&1; }

# --- Assertion 1: a rulebook-joined pull DEFERS --------------------------------
out="$(run_gate "$GATE" "$CONS_OLD")"
if grep -q 'SELF-UPDATE-DEFER' <<<"$out"; then
  ok "a pull whose map declares checks the consumer has no anchor for DEFERS"
else
  bad "the gate returned no DEFER for a rulebook-joined pull — step 2 would cut a branch, write the slice, run the fixtures and revert"
  printf '%s\n' "$out" | sed 's/^/        /' | head -4
fi

# --- Assertion 2: it NAMES the missing anchors ---------------------------------
# The operator who hit this had to derive the collapsed ordering by hand. A defer that
# does not say which checks are unanchored costs exactly that again.
# Do not hardcode WHICH check: the seed derives its range from history, so the unanchored
# id moves as releases land. Require that the message names at least one concrete id.
if grep -q 'whose CHECK_LOADED anchor lives in' <<<"$out" && grep -qE 'check\(s\) \[[A-Za-z0-9]' <<<"$out"; then
  ok "the defer NAMES the unanchored check ids rather than only announcing a conflict"
else
  bad "the defer does not name the unanchored checks — the operator must re-derive them by hand"
fi

# --- Assertion 3: A MACHINERY-ONLY PULL STILL PROCEEDS -------------------------
# The false positive that would make this release worse than the defect. If the rulebook
# is not changing, no fixture can break on it, and step 2 must stay autonomous.
out_mo="$(run_gate "$GATE" "$CONS_CURRENT")"
if grep -q 'SELF-UPDATE-DEFER' <<<"$out_mo"; then
  bad "a pull with NO rulebook change DEFERRED — the arm is static, not differential, and it strands the machinery slice on every pull"
  printf '%s\n' "$out_mo" | sed 's/^/        /' | head -3
else
  ok "a pull that changes no rulebook file does NOT defer — the arm is a differential"
fi

# --- Assertion 4: the fixture-coupling arm names its subjects ------------------
if grep -q 'rulebook-coupled-fixtures' <<<"$out"; then
  ok "the fixture-coupling arm fires and names itself"
else
  bad "the fixture-coupling arm never fired — postcompact-rulebook-recovery is exactly the case it exists for"
fi

# --- Assertion 5: an unparseable anchor side REFUSES, never agrees -------------
# A zero must not be a false zero: if the anchor grammar moves, an empty set compares
# equal to anything and the gate would report agreement it never computed.
t="$WORK/cons-noanchors"
rm -rf "$t"; cp -R "$CONS_OLD" "$t"
GVC="$t/.claude/skills/ai-dlc/steps/gate-validation.md"
if [ -f "$GVC" ]; then
  sed 's/^<!-- CHECK_LOADED:/<!-- XX_LOADED:/' "$GVC" > "$GVC.mut" && mv "$GVC.mut" "$GVC"
  out_na="$(run_gate "$GATE" "$t")"
  if grep -q 'SELF-UPDATE-UNDECIDED' <<<"$out_na"; then
    ok "an unparseable anchor side returns UNDECIDED — an empty set does not read as agreement"
  else
    bad "a consumer with no parseable anchors did not return UNDECIDED — a false zero would read as a clean join"
  fi
else
  bad "FIXTURE BROKEN — no gate-validation.md in the seeded consumer, so assertion 5 tests nothing"
fi

# ------------------------------------------------------------------------------
# MUTANTS. Copies, never in-place edits; `cmp -s` proves the mutation landed and `bash -n`
# proves the result is still a program. The unmutated control comes first: this gate
# shells out to git, and a copy that fails for its own reasons would score every mutant
# below as a kill.
# ------------------------------------------------------------------------------
CTRL="$WORK/gate-control.sh"; cp "$GATE" "$CTRL"
if grep -q 'SELF-UPDATE-DEFER' <<<"$(run_gate "$CTRL" "$CONS_OLD")"; then
  ok "UNMUTATED CONTROL reproduces the real verdict from a copy"
  CONTROL_OK=1
else
  bad "UNMUTATED CONTROL did not reproduce — every mutant below is uninterpretable"
  CONTROL_OK=0
fi

if [ "${CONTROL_OK:-0}" = "1" ]; then
  # MUTANT A: the anchor join stops comparing. Assertion 1's ANCHOR half must go quiet.
  MUT_A="$WORK/mutant-a.sh"
  sed 's/^    r1_missing=.*/    r1_missing=""/' "$CTRL" > "$MUT_A"
  if cmp -s "$CTRL" "$MUT_A"; then
    bad "MUTANT A changed nothing — the anchor is stale and the mutant is a no-op"
  elif ! bash -n "$MUT_A" 2>/dev/null; then
    bad "MUTANT A is not a valid program — its silence would have scored as a kill"
  else
    if grep -q 'whose CHECK_LOADED anchor lives in' <<<"$(run_gate "$MUT_A" "$CONS_OLD")"; then
      bad "MUTANT A DID NOT silence the anchor arm — assertion 2 is not testing the join"
    else
      ok "MUTANT A killed — without the anchor comparison the unanchored checks go unreported"
    fi
  fi

  # MUTANT B: the fixture arm stops being differential — drop the rulebook-changed guard.
  # It must then defer on the machinery-only pull, which is assertion 3's whole point.
  MUT_B="$WORK/mutant-b.sh"
  sed 's/^if \[ -n "\$R2_RB" \]; then/if true; then/' "$CTRL" > "$MUT_B"
  if cmp -s "$CTRL" "$MUT_B"; then
    bad "MUTANT B changed nothing — anchor stale"
  elif ! bash -n "$MUT_B" 2>/dev/null; then
    bad "MUTANT B is not a valid program"
  else
    if grep -q 'SELF-UPDATE-DEFER' <<<"$(run_gate "$MUT_B" "$CONS_CURRENT")"; then
      ok "MUTANT B killed — dropping the differential guard defers a machinery-only pull (assertion 3 has teeth)"
    else
      bad "MUTANT B DID NOT defer the machinery-only pull — assertion 3 is not testing the differential"
    fi
  fi
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "self-update-join-gate: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "self-update-join-gate: all assertions passed"
