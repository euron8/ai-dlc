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
# FIVE, and it is a fan-out rather than an entanglement: the branch this deletes is the sole
# emitter of the exit code, the headline and the zero-entry clause, and TWO envelopes reach it —
# one carrying an unresolvable entry, one carrying no entry at all. Deleting an emitter takes
# every fact emitted from it. M16 isolates the clause and M17 isolates the byte-comparison, so
# neither of the two zero-entry cells is proven only by this total knock-out. The zero-entry
# cmp arm stays GREEN here, correctly: removing the branch stops it reporting, not writing.
expect_set exit3-becomes-clean 5 'resolved no story file exited|exit 3 printed no explanation|entry-less envelope exited|zero-entry exit-3 line does not name|does not say the mode cannot create an entry' \
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
# TWELVE as of v0.239.0 — re-derived at every release that touches this fixture, never inherited.
# It is a fan-out rather than an entanglement: detection, the exit code, both derived values, the
# floor, the byte count, the `none`-still-derives-status arm, the three v0.238.0 write arms and
# the two v0.239.0 arms that need a write to have happened are twelve different facts about one
# comparison, and a comparison that never finds drift writes nothing at all. The two new cells are
# that shape exactly: with no drift `--check` prints its PASS summary rather than its FAIL one, and
# the both-views write arm has no write to inspect. M4, M5, M9, M10, M11, M12, M13, M14 and M15
# each isolate one independently, so no cell is proven only by this total knock-out.
expect_set nothing-ever-drifts 12 'did not name the drift|--check exited|derived value is not the story file|only one declared field|status. was not derived|write touched|silenced .status. too|inline comment.s alignment|colon-space was written bare|unwritable value was accepted|quotes values that need no quoting|check FAIL prints no entry count|only one view was written' \
  's@^                if val == have:@                if True:@'

# M9 — the write re-emits the line instead of editing its value token, dropping the trailing
# comment entirely. Detection is untouched; only the document survives differently.
expect_set write-drops-comment 1 'inline comment.s alignment was destroyed' \
  's@^    return head + sep + yaml_scalar(new) + tail@    return head + sep + yaml_scalar(new)@'

# M10 — `yaml_scalar` returns the value unchanged. THIS IS v0.237.0 EXACTLY: the derived value
# is re-emitted bare and a title carrying `: ` writes a line that is not YAML. Held as a mutant
# because the fix and the defect differ by one function call, and a release that only says "now
# it quotes" cannot show that the arm sees the difference.
# THREE, and the fan-out is the design rather than an entanglement: with the value emitted bare
# the ROUND-TRIP GUARD has nothing to catch, because the envelope's own reader is a regex that
# reads a bare mangled line back as itself. That coupling is exactly why the quoting and the guard
# ship together — either alone is silent. M11 isolates the guard independently.
expect_set value-emitted-bare 3 'colon-space was written bare|unwritable value was accepted|guard reported and wrote anyway' \
  's@^    return head + sep + yaml_scalar(new) + tail@    return head + sep + new + tail@'

# M11 — the round-trip guard goes. The write still happens and nothing reads it back, which is
# the state that made v0.237.0's corruption SILENT rather than loud: the envelope's own reader is
# a regex and agrees with the mangled line.
expect_set roundtrip-guard-removed 2 'unwritable value was accepted|guard reported and wrote anyway' \
  's@^                        if rb is None or strip_value(rb.group(3)) != val:@                        if False:@'

# M12 — the counts go back to being per-view sums. THIS IS THE DEFECT AS IT SHIPPED, held as a
# mutant for the same reason M10 is: the fix and the defect differ by which variable the summary
# formats, and a release that only says "now it counts stories" cannot show the arm sees it. One
# red, not two: the union case declares a DIFFERENT entry in each view, so its per-view sum and
# its distinct count are the same number — which is exactly why that case is a separate assertion
# and cannot stand in for this one.
expect_set counts-per-view 1 'summary counted per view' \
  's@^    stories_n = len(seen_resolved)@    stories_n = files_matched@;
   s@^    entries_n = len(seen_entries)@    entries_n = entries_total@'

# M13 — the per-view breakdown goes. The summary is then a total with nothing behind it, which is
# the state that let the double count survive four releases: one number, no way to see it was the
# sum of two views that hold the same story.
expect_set breakdown-removed 1 'no per-view breakdown' \
  's@^    for view, note in per_view:@    for view, note in []:@'

# M14 — the declared-entry set stops being a UNION across views and keeps only the entry last
# seen. A tree whose two views agree still reads correctly, so this fires ONLY on the case where
# they differ — the arm that stops the fix being arithmetic on the per-view sum.
expect_set entry-set-not-union 1 'distinct count is not a union' \
  's@^            seen_entries.add(key)@            seen_entries = set([key])@'

# M15 — `--check` drops the declared entry count from both its verdict lines. The write path keeps
# it, which is precisely the pre-fix state: the number exists and is emitted only by the mode a
# gate must not call. TWO reds because `--check` has two summaries and they are built separately.
expect_set check-drops-entry-count 2 'check FAIL prints no entry count|check PASS prints no entry count' \
  's@entr%s declared@entr%s@g'

# M16 — the zero-entry clause is keyed off. The headline and the exit code are untouched, so the
# run still reports "matched no story files (exit 3) — 0 entries parsed": true, and read by a
# session sent here to repair a stale entry as a resolution near-miss rather than as "this mode
# cannot do what you were told to run it for". ONE red, and it is the clause arm alone — the
# near-miss arms assert the clause's ABSENCE on an envelope that carries an entry, and it is still
# absent there, which is what makes them a near-miss rather than a second copy of this cell.
expect_set zero-entry-clause-off 1 'does not say the mode cannot create an entry' \
  's@^        if entries_n == 0:@        if False:@'

# M17 — the write path CREATES the entry the envelope is missing, which is filing option (b) and
# the thing core must not do: it resolves files FROM the entries, so inferring which files on disk
# are stories is the consumer's membership rule and not core's. The mutation writes down the view
# that reported "no entry to derive", so the exit code, the headline and the clause all survive
# and only the byte-comparison moves. That isolation is the point — a create mode is invisible to
# every other assertion in the fixture, including the one that reads the message.
expect_set zero-entry-write-creates 1 'edited a canonical over a run that matched nothing' \
  's@^            per_view.append((view, "no entry to derive@            p.write_text(text + "  story-42-1:" + chr(10) + "    status: draft" + chr(10)); per_view.append((view, "no entry to derive@'

if [ "$fails" -eq 0 ]; then echo "PASS story-fields-derive-mutants"; exit 0; fi
echo "FAIL story-fields-derive-mutants ($fails)"; exit 1
