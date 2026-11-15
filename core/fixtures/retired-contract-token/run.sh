#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# retired-contract-token — assert the detector sees a severed contract, and only a real one.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# Upstream retires a shared contract -- a channel, a scratch path, a state file --
# and the consumer's own code, living inside the same upstream-maintained file,
# still speaks the old one. `diff3` merges it cleanly. `bash -n` passes. The gate
# goes silent.
#
# Measured on the reference consumer's 0.114.0 -> 0.118.2 pull: the consumer's
# WHOLE_READ_POOL block kept writing its OVER verdict to a retired temp path, and
# the merged script reported PASS at 1212% of budget and exited 0. Found by a
# hand-built functional test, which is the machine's job done by a person.
#
# The two halves are equally load-bearing. A detector that misses the severed
# contract is useless; a detector that fires on upstream's own comment explaining
# the retirement gets muted after one release, which is the same thing more slowly.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/retired-tokens.sh" ]; then
  DETECT="$ROOT/core/skills/ai-dlc-update/reconcile/retired-tokens.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/retired-tokens.sh" ]; then
  DETECT="$ROOT/.claude/skills/ai-dlc-update/reconcile/retired-tokens.sh"
else
  echo "FIXTURE ERROR: retired-tokens.sh not found in either layout" >&2
  exit 2
fi

echo "HERMETIC-CONSUMED $DETECT"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

CORE_PATH="core/scripts/validate-artifact-budget.sh"
DIST="$WORK/dist"
CONS="$WORK/consumer"

mkdir -p "$DIST/core/scripts" "$CONS/scripts/ai-dlc" || exit 2

# --- build the dist history: base retires nothing, theirs retires $ROOT/.chan ----
git -C "$DIST" init -q . 2>/dev/null || exit 2
git -C "$DIST" config user.email f@x >/dev/null 2>&1
git -C "$DIST" config user.name f >/dev/null 2>&1

cat > "$DIST/$CORE_PATH" <<'BASE'
#!/bin/bash
CHAN="$ROOT/.chan"
rm -f "$CHAN"
printf 'x\n' >> "$ROOT/.chan"
BASE
# A SECOND core file upstream modifies and the consumer has DELETED. It is listed as
# CLASSIFY and never opened, so every world has listed > opened, and a NOTE that prints
# "$opened of $opened" cannot pass for one that prints "$opened of $listed". Measured
# on the reference consumer's history: 8 listed, 7 opened, and the first cut of the
# denominator NOTE printed only the 7.
SECOND_PATH="core/scripts/second.sh"
printf '#!/bin/bash\nX="$ROOT/.second"\n' > "$DIST/$SECOND_PATH"
# A THIRD core file upstream modifies WITHOUT retiring its token. When the consumer
# carries a modified copy it is listed, opened, and contributes nothing to `retiring`,
# so a world exists where the retiring count is 0 and a NOTE that hardcodes "1 carrying"
# cannot pass. Found by the receipt adversary: every earlier world had retiring == 1.
THIRD_PATH="core/scripts/third.sh"
printf '#!/bin/bash\nX="$ROOT/.third"\n' > "$DIST/$THIRD_PATH"
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" commit -qm base >/dev/null 2>&1
BASE_SHA="$(git -C "$DIST" rev-parse HEAD)"

# theirs: the channel moves into a private dir, and -- as upstream really does --
# the header EXPLAINS the retirement by quoting the path it just retired.
cat > "$DIST/$CORE_PATH" <<'THEIRS'
#!/bin/bash
# The channel used to be $ROOT/.chan, which littered the project root.
TMPROOT="$(mktemp -d)"
CHAN="$TMPROOT/chan"
printf 'x\n' >> "$CHAN"
THEIRS
printf '#!/bin/bash\nX="$ROOT/.second"\ny=2\n' > "$DIST/$SECOND_PATH"
printf '#!/bin/bash\nX="$ROOT/.third"\ny=2\n' > "$DIST/$THIRD_PATH"
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" commit -qm theirs >/dev/null 2>&1
THEIRS_SHA="$(git -C "$DIST" rev-parse HEAD)"

run_detect() { bash "$DETECT" "$DIST" "$BASE_SHA" "$THEIRS_SHA" "$CONS" 2>/dev/null; }

echo "retired-contract-token"

# --- 1. THE SEVERED CONTRACT IS CAUGHT -----------------------------------------
# Consumer carries its own block (upstream has no such thing) still writing to the
# retired path. This is the shape that merges clean and fails silent.
cat > "$CONS/scripts/ai-dlc/validate-artifact-budget.sh" <<'OURS'
#!/bin/bash
CHAN="$ROOT/.chan"
printf 'x\n' >> "$ROOT/.chan"
# consumer-only block below
pool_report() { printf 'OVER\n' >> "$ROOT/.chan"; }
OURS
out="$(run_detect)"
if grep -q 'RETIRED-CONTRACT-TOKEN.*\$ROOT/\.chan' <<<"$out"; then
  ok "a retired contract the consumer still references is caught"
else
  bad "the severed contract was NOT caught -- detector is inert"
fi

# --- 1b. `--bucket-rows` CHANGES WHO PAID, NEVER WHAT IS ANSWERED --------------
# `emit-report.sh` and `apply.sh` both hold `preclassify.sh <dist> <base> <theirs> <consumer>`
# rows already -- byte-for-byte this detector's own call -- and re-deriving them cost one
# preclassify per CLASSIFY file. The flag hands them down. These two arms are ported from
# `apply-drift-after-write/run.sh:430` and `:442`, which exist because this exact class of hole
# is invisible to every other arm: the world above stays green whether the flag is read or not.
#
# THE EMITTING WORLD IS THE SUBJECT ON PURPOSE. Scored against a world where the detector
# reports nothing, both the flagged and standalone runs are empty and agree for a reason
# neither owns.
RTF="$WORK/pc-rows"
bash "$(dirname "$DETECT")/preclassify.sh" "$DIST" "$BASE_SHA" "$THEIRS_SHA" "$CONS" > "$RTF" 2>/dev/null
RT_STAND="$out"
RT_FLAG="$(bash "$DETECT" --bucket-rows "$RTF" "$DIST" "$BASE_SHA" "$THEIRS_SHA" "$CONS" 2>/dev/null)"
if [ "$(grep -c . "$RTF")" -gt 0 ] && [ -n "$RT_FLAG" ] && [ "$RT_FLAG" = "$RT_STAND" ]; then
  ok "--bucket-rows changes no verdict: the flagged and standalone runs agree row-for-row"
elif [ "$(grep -c . "$RTF")" -eq 0 ]; then
  bad "the handed-down rows file is EMPTY, so this arm compares two empties and establishes nothing"
elif [ -z "$RT_FLAG" ]; then
  bad "the flagged run produced NO rows where the standalone run did -- a caller handing down rows would render RETIRED-CONTRACT-TOKEN: none over a live finding"
else
  bad "the flagged and standalone runs DISAGREE, so a report and a hand-run detector would differ: $(diff <(printf '%s\n' "$RT_STAND") <(printf '%s\n' "$RT_FLAG") | head -4 | tr '\n' '|')"
fi

# ...and an EMPTY rows file must NOT acquit. THIS IS THE FAIL-CLOSED CELL and the only input on
# which a read-the-file-and-trust-it implementation differs from the shipped one. The detector's
# refusal for "no rows" goes to STDERR, and BOTH callers discard stderr with `2>/dev/null` and
# render `RETIRED-CONTRACT-TOKEN: none` -- so an empty handed-down file, from a failed `mktemp`
# or a truncated write, is byte-indistinguishable from a clean tree at the only place an
# operator reads. Measured before this arm existed: all four reconcile fixtures stayed green
# with that hole open.
RT_EMPTY="$(bash "$DETECT" --bucket-rows /dev/null "$DIST" "$BASE_SHA" "$THEIRS_SHA" "$CONS" 2>/dev/null)"
if grep -q 'RETIRED-CONTRACT-TOKEN.*\$ROOT/\.chan' <<<"$RT_EMPTY"; then
  ok "an EMPTY --bucket-rows file does not acquit: the detector re-derives rather than reporting clean"
else
  bad "with the handed-down rows empty the retired token was ACQUITTED -- a detector that cannot read its subject must not clear it. Got: ${RT_EMPTY:-<no row>}"
fi

# --- 2. RE-POINTED CONSUMER IS CLEAN -------------------------------------------
# The control. Without it, assertion 1 could be passing because the detector flags
# everything, which is the same as flagging nothing.
cat > "$CONS/scripts/ai-dlc/validate-artifact-budget.sh" <<'OURS'
#!/bin/bash
TMPROOT="$(mktemp -d)"
CHAN="$TMPROOT/chan"
printf 'x\n' >> "$CHAN"
pool_report() { printf 'OVER\n' >> "$CHAN"; }
OURS
out="$(run_detect)"
if [ -z "$(printf '%s' "$out" | grep . || true)" ]; then
  ok "a correctly re-pointed consumer reports nothing"
else
  bad "false positive on a re-pointed consumer: $out"
fi

# --- 3. A COMMENT IS NOT A REFERENCE -------------------------------------------
# The consumer documents the old path in prose, exactly as upstream's own header
# does. Flagging this is how a detector gets muted after one release.
cat > "$CONS/scripts/ai-dlc/validate-artifact-budget.sh" <<'OURS'
#!/bin/bash
# Historical note: this used to write to $ROOT/.chan before the move.
TMPROOT="$(mktemp -d)"
CHAN="$TMPROOT/chan"
printf 'x\n' >> "$CHAN"
OURS
out="$(run_detect)"
if [ -z "$(printf '%s' "$out" | grep . || true)" ]; then
  ok "a retired path named only in a COMMENT is not a reference"
else
  bad "fired on documentation -- this detector will be muted within a release"
fi

# --- 5-8. A ZERO THAT OPENED NO FILE SAYS SO, AND ONLY THEN --------------------
# Measured on the reference consumer's 0.410.0 -> 0.412.0 pull: every path bucketed
# ALREADY-AT-THEIRS, the CLASSIFY set was empty, and the detector exited 0 with zero
# rows -- byte-identical on stdout to a full scan that matched nothing. The NOTE on
# stderr is the only thing that separates the two, so each quiet state gets a
# predicate, the loud state gets one asserting SILENCE on stderr, and each predicate
# is scored against the wrong fix that would satisfy the others:
#   p5  opened nothing (rows exist, none CLASSIFY)  -> NOTE says opened NONE
#   p6  opened a file, matched nothing              -> NOTE states the denominator
#   p7  matched (rows on stdout)                    -> stderr EMPTY
#   p8  preclassify produced no rows at all         -> refusal, not a clean NOTE
# Every predicate takes the script to drive, re-seeds its own consumer, and asserts
# a PRESENCE, so a script that emits nothing fails by construction.
PRE="$(dirname "$DETECT")/preclassify.sh"
SECOND_OURS="$CONS/scripts/ai-dlc/second.sh"
THIRD_OURS="$CONS/scripts/ai-dlc/third.sh"
# Consumer states. The second core file has no consumer copy except in the all-at-theirs
# world (listed, never opened). The third has one only where a seed writes it (listed,
# opened, retiring nothing).
seed_at_theirs() { cp "$DIST/$CORE_PATH" "$CONS/scripts/ai-dlc/validate-artifact-budget.sh"; rm -f "$SECOND_OURS" "$THIRD_OURS"; }
# THE INCIDENT'S OWN SHAPE: every path ALREADY-AT-THEIRS, so nothing is listed at all.
# The second and third files displaced it from every other world, and a wrong fix that
# requires something to have been listed passed the whole fixture until the adversarial
# hand put it back. `listed 0` is asserted here as a number.
seed_all_at_theirs() { seed_at_theirs; cp "$DIST/$SECOND_PATH" "$SECOND_OURS"; cp "$DIST/$THIRD_PATH" "$THIRD_OURS"; }
seed_third_modified() { printf '#!/bin/bash\nX="$ROOT/.third"\ny=3\n' > "$THIRD_OURS"; }
# EVERY seed defines the WHOLE consumer state. A predicate that returns early
# leaves whatever its last world wrote, and the next predicate's world then has a shape
# nobody seeded.
seed_repointed() {
  rm -f "$SECOND_OURS" "$THIRD_OURS"
  cat > "$CONS/scripts/ai-dlc/validate-artifact-budget.sh" <<'OURS'
#!/bin/bash
TMPROOT="$(mktemp -d)"
CHAN="$TMPROOT/chan"
pool_report() { printf 'OVER\n' >> "$CHAN"; }
OURS
  seed_third_modified
}
seed_severed() {
  cat > "$CONS/scripts/ai-dlc/validate-artifact-budget.sh" <<'OURS'
#!/bin/bash
CHAN="$ROOT/.chan"
pool_report() { printf 'OVER\n' >> "$ROOT/.chan"; }
OURS
  rm -f "$SECOND_OURS" "$THIRD_OURS"
}
# stderr only; stdout discarded. `2>&1 >/dev/null` in that order.
# An optional third argument is the per-path fifth argument both program callers pass.
err_of() { bash "$1" "$DIST" "$2" "$THEIRS_SHA" "$CONS" ${3:+"$3"} 2>&1 >/dev/null; }
out_of() { bash "$1" "$DIST" "$2" "$THEIRS_SHA" "$CONS" ${3:+"$3"} 2>/dev/null; }

# p5 drives THREE worlds. Two consumer-deleted CLASSIFY files listed and neither opened
# (the listed count asserted as a number); the incident's own shape, nothing listed at
# all; and the per-path form both program callers use, restricted to the deleted second
# file, whose NOTE names the path.
p5() {
  seed_at_theirs
  o="$(out_of "$1" "$BASE_SHA")"; e="$(err_of "$1" "$BASE_SHA")"
  [ -z "$(printf '%s' "$o" | grep . || true)" ] \
    && grep -q 'listed 2 CLASSIFY file(s) and opened NONE, so NO core file was scanned' <<<"$e" \
    && grep -q 'this zero does not cover it' <<<"$e" \
    && ! grep -q 'produced no rows' <<<"$e" || return 1
  seed_all_at_theirs
  o="$(out_of "$1" "$BASE_SHA")"; e="$(err_of "$1" "$BASE_SHA")"
  [ -z "$(printf '%s' "$o" | grep . || true)" ] \
    && grep -q 'listed 0 CLASSIFY file(s) and opened NONE' <<<"$e" \
    && ! grep -q 'produced no rows' <<<"$e" || return 1
  seed_at_theirs
  o="$(out_of "$1" "$BASE_SHA" "$SECOND_PATH")"; e="$(err_of "$1" "$BASE_SHA" "$SECOND_PATH")"
  [ -z "$(printf '%s' "$o" | grep . || true)" ] \
    && grep -q "listed 1 CLASSIFY file(s) at $SECOND_PATH and opened NONE" <<<"$e"
}
# p6 drives TWO worlds so every count in the denominator NOTE is bound by a world where
# it differs: re-pointed + third modified lists 3, opens 2, 1 retiring; third modified
# alone lists 2, opens 1, 0 retiring.
p6() {
  seed_repointed
  o="$(out_of "$1" "$BASE_SHA")"; e="$(err_of "$1" "$BASE_SHA")"
  [ -z "$(printf '%s' "$o" | grep . || true)" ] \
    && grep -q '2 of 3 CLASSIFY file(s) opened, 1 carrying' <<<"$e" \
    && ! grep -q 'opened NONE' <<<"$e" || return 1
  seed_at_theirs; seed_third_modified
  o="$(out_of "$1" "$BASE_SHA")"; e="$(err_of "$1" "$BASE_SHA")"
  [ -z "$(printf '%s' "$o" | grep . || true)" ] \
    && grep -q '1 of 2 CLASSIFY file(s) opened, 0 carrying' <<<"$e" \
    && ! grep -q 'opened NONE' <<<"$e"
}
# p7 drives the whole-run form and the per-path form apply.sh uses on a CLASSIFY path.
p7() {
  seed_severed
  o="$(out_of "$1" "$BASE_SHA")"; e="$(err_of "$1" "$BASE_SHA")"
  grep -q 'RETIRED-CONTRACT-TOKEN.*\$ROOT/\.chan' <<<"$o" && [ -z "$e" ] || return 1
  o="$(out_of "$1" "$BASE_SHA" "$CORE_PATH")"; e="$(err_of "$1" "$BASE_SHA" "$CORE_PATH")"
  grep -q 'RETIRED-CONTRACT-TOKEN.*\$ROOT/\.chan' <<<"$o" && [ -z "$e" ]
}
# p8 ASSERTS THE EXIT, NOT ONLY THE MESSAGE. Both callers discard this detector's stderr and read
# its rows and its exit, so a refusal that exits 0 reaches them as a clean run with no row -- the
# message alone was satisfied by exactly that. The exit must be 2, the refusal code.
#
# SKIPPED (the rc conjunct only) on a consumer whose installed detector predates the exit-2
# refusal: this fixture ships a pull ahead of the code. In the distribution it always binds.
case "$DETECT" in */core/skills/ai-dlc-update/reconcile/retired-tokens.sh) P8_ISDIST=1 ;; *) P8_ISDIST=0 ;; esac
P8_RC=1
P8_BLOCK="$(sed -n '/produced no rows/,/^fi$/p' "$DETECT")" || P8_BLOCK=""
if [ "$P8_ISDIST" = 0 ] && ! grep -q '^  exit 2$' <<<"$P8_BLOCK"; then
  printf '  SKIP  p8 exit-code conjunct -- the installed retired-tokens.sh predates the exit-2 refusal; it lands with the pull that carries this fixture (this is not a pass)\n'
  P8_RC=0
fi
rc_of() { bash "$1" "$DIST" "$2" "$THEIRS_SHA" "$CONS" >/dev/null 2>&1; printf '%s' "$?"; }
p8() {
  seed_at_theirs
  o="$(out_of "$1" "$THEIRS_SHA")"; e="$(err_of "$1" "$THEIRS_SHA")"
  [ -z "$(printf '%s' "$o" | grep . || true)" ] \
    && grep -q 'produced no rows' <<<"$e" \
    && ! grep -q 'NOTE --' <<<"$e" || return 1
  [ "$P8_RC" = 0 ] || [ "$(rc_of "$1" "$THEIRS_SHA")" = 2 ]
}

# The world p5 drives must PRODUCE preclassify rows, or the wrong fix keyed on "no rows"
# is indistinguishable from the right one keyed on "opened nothing". Assert that first.
seed_at_theirs
nrows="$(bash "$PRE" "$DIST" "$BASE_SHA" "$THEIRS_SHA" "$CONS" 2>/dev/null | grep -c .)" || nrows=0
if [ "$nrows" -gt 0 ]; then
  ok "control: the ALREADY-AT-THEIRS world yields $nrows preclassify row(s); its CLASSIFY rows are the consumer-deleted second and third files, listed and never opened"
else
  echo "FIXTURE ERROR: the ALREADY-AT-THEIRS world produced no preclassify rows -- p5 cannot discriminate" >&2
  exit 2
fi

if p5 "$DETECT"; then ok "a run that opened no core file says so on stderr, with stdout empty"
else bad "opened nothing and said nothing -- the vacuous scan reads as a clean one"; fi
if p6 "$DETECT"; then ok "a run that opened a file and matched nothing states its denominator"
else bad "scanned-and-clean carries no denominator, or claims it opened nothing"; fi
if p7 "$DETECT"; then ok "a run that matched says nothing on stderr: the rows are the answer"
else bad "a NOTE was printed beside real rows, or the rows are gone"; fi
if p8 "$DETECT"; then ok "preclassify producing no rows is refused, not reported as a clean NOTE"
else bad "an unresolvable input reads as a clean scan"; fi

echo ""
report_end retired-contract-token
