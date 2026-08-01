#!/usr/bin/env bash
# story-fields-derive-mutants — the mutation battery behind `story-fields-derive`.
# DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 = every mutant moves exactly its own assertions, 1 = one did not, 2 = fixture broken.
#
# WHY THIS IS SPLIT OUT, and it is v0.230.0's rule applied before the cost is paid rather than
# after. The battery re-runs the subject fixture once per mutant, so held together the pair costs
# roughly an order of magnitude more than the assertions alone — and what a fixture COSTS is a
# property of the suite it runs in, not of this one. `consumer-suite-pool` became the reference
# consumer's pole exactly this way.
#
# WHY THE BATTERY IS THE HALF THAT MOVES. It mutates `sprint-status.sh`, which is CORE's:
# `ai-dlc-core-guard.sh` denies a consumer the in-place edit, so the surface these mutants perturb
# cannot change in a consumer tree. Proving the assertions can fail is a question about a file
# only this repository edits. The consumer keeps every CORRECTNESS arm.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

SUBJ="$HERE/../story-fields-derive/run.sh"
[ -f "$SUBJ" ] || { echo "FIXTURE ERROR: sibling story-fields-derive/run.sh not found" >&2; exit 2; }
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/sprint-status.sh" ]; then
  VAL="$ROOT/core/scripts/sprint-status.sh"
else
  echo "FIXTURE ERROR: sprint-status.sh not found — this fixture is distribution-only" >&2; exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
MUT="$WORK/mutants"; mkdir -p "$MUT"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

mut_reds() {
  local label="$1" prog="$2" copy="$MUT/$1.sh"
  if [ -z "$prog" ]; then cp "$VAL" "$copy"; else
    sed "$prog" "$VAL" > "$copy" 2>/dev/null
    if cmp -s "$VAL" "$copy"; then printf 'UNMUTATED\n'; return 0; fi
  fi
  AI_DLC_SFD_SCRIPT="$copy" bash "$SUBJ" 2>/dev/null | grep '^  FAIL  ' | sed 's/^  FAIL  //'
}
expect_set() { # $1 label, $2 expected count, $3 ERE every red must match, $4 sed
  local reds n unmatched
  reds="$(mut_reds "$1" "$4")"
  if [ "$reds" = "UNMUTATED" ]; then
    bad "MUTANT $1: the sed matched nothing — no mutation was applied, so nothing was proven"
    return
  fi
  n="$(grep -c . <<<"$reds" || true)"
  unmatched="$(grep -vE "$3" <<<"$reds" | grep -c . || true)"
  if [ "$n" -eq "$2" ] && [ "$unmatched" -eq 0 ]; then
    ok "MUTANT $1 moves exactly the $2 assertion(s) it should, and no others"
  else
    bad "MUTANT $1: expected $2 red(s) matching '$3', got ${n} (${unmatched} unexpected): $(tr '\n' ';' <<<"$reds")"
  fi
}

ctl="$(mut_reds control "")"
[ -z "$ctl" ] && ok "CONTROL: an unmutated copy of the script passes every assertion" \
              || bad "CONTROL: an unmutated copy FAILED ($(tr '\n' ';' <<<"$ctl")) — every kill below is unearned"

# M1 — `--check` stops being report-only and writes. A mode that edits while reporting passes
# every assertion about WHAT it reported.
# THE WRITE IS GUARDED TWICE, ON PURPOSE, and this mutant has to remove BOTH. The first cut
# removed only the inner `if dry: continue` and scored ZERO reds; the second removed only the
# outer `if changed and not dry` and also scored ZERO, because with the inner guard in place
# `changed` never becomes true. Each guard proves the other, `cmp -s` is satisfied either way,
# and a single-site mutant here reads exactly like a surviving one.
expect_set check-writes 1 'check WROTE to the envelope' \
  's@^                if dry:$@                if False:@; s@^        if changed and not dry:@        if changed:@'

# M2 — exit 3 collapses into the success path. "Matched no story files" becomes clean, which is
# the vacuous green every consumer implementation of this join has shipped at least once.
expect_set exit3-becomes-clean 2 'resolved no story file exited|exit 3 printed no explanation' \
  's@^    if files_matched == 0:@    if False:@'

# M3 — exit 4 collapses. Distinct from M2 and that is the point: "found nothing to read" and
# "read nothing from what it found" have different remedies and must not share a code.
expect_set exit4-becomes-clean 2 'compared on nothing exited|exit 4 did not name its subject' \
  's@^    if zero_comparison:@    if False:@'

# M4 — the floor stops coming from the schema. `status` is then derivable only if the consumer
# declares it, which is precisely the thing the split exists to prevent.
# `STATUS_FLOOR = [] or [k for k…]` was the first cut and it is a Python no-op — `[] or X` is X.
# It applied cleanly, `cmp -s` was satisfied, and it reported zero reds.
# THREE reds, and they are a fan-out: the value is not derived, the byte count moves with it, and
# a consumer declaring `none` is left deriving nothing at all. A FOURTH red disappeared when the
# subject fixture moved its hand-aligned comment off the `status` line — that one was an artefact
# of the test data, not a fact about the floor.
expect_set floor-not-from-schema 3 'status. was not derived|write touched|silenced .status. too' \
  's@^STATUS_FLOOR = \[k for k.*@STATUS_FLOOR = []@'

# M5 — the inline comment's whitespace run is normalised to one space. THIS IS THE DEFECT AS IT
# WAS FIRST WRITTEN, not a hypothetical: the comment survived and the hand-aligned column did
# not, on every commented line, on every run.
# The mutation keeps ONE space before the `#` rather than dropping the separator entirely. The
# blunter form corrupts the value on re-read (`in_review# note` parses as the whole string), so it
# also broke idempotence and scored TWO reds — a second consequence of the same defect, which
# reads as a kill while isolating nothing. This form moves exactly the column.
expect_set comment-column-collapsed 1 'inline comment.s alignment was destroyed' \
  's@^            tail = cm.group(2)@            tail = " " + cm.group(2).lstrip()@'

# M6 — a malformed declaration is read as an empty one, so a typo silently derives only the floor
# and reports success.
expect_set malformed-reads-empty 1 'malformed field list was treated as empty' \
  's@^    if state == "malformed":@    if False:@'

# M7 — the two silent states collapse into one message, so a consumer that answered `none` and
# one that has never seen the declaration are indistinguishable in the output.
expect_set silent-states-collapsed 1 'undeclared list and an empty one print the same' \
  's@so this project predates the declaration@so this project declares the literal `none`@'

# M8 — the drift comparison is inverted into always-equal, so nothing is ever derived and every
# run reports a clean check.
# SEVEN, and it is a fan-out rather than an entanglement: detection, the exit code, both derived
# values, the floor, the byte count and the `none`-still-derives-status arm are seven different
# facts about one comparison. M4, M5 and M9 each isolate one of them independently, so none is
# proven only by this total knock-out.
expect_set nothing-ever-drifts 7 'did not name the drift|--check exited|derived value is not the story file|only one declared field|status. was not derived|write touched|silenced .status. too|inline comment.s alignment' \
  's@^                if val == have:@                if True:@'

# M9 — the write re-emits the line instead of editing its value token, dropping the trailing
# comment entirely. Detection is untouched; only the document survives differently.
expect_set write-drops-comment 1 'inline comment.s alignment was destroyed' \
  's@^    return head + sep + new + tail@    return head + sep + new@'

if [ "$fails" -eq 0 ]; then echo "PASS story-fields-derive-mutants"; exit 0; fi
echo "FAIL story-fields-derive-mutants ($fails)"; exit 1
