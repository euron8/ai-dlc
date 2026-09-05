#!/usr/bin/env bash
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

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

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

# --- 4. MUTATION: the comment strip is load-bearing -----------------------------
# Remove the comment-stripping and assertion 3 must break. Without this control,
# assertion 3 could be passing because the token never matched at all.
# Neuter the filter by swapping it for `cat` -- do NOT delete the line. Deleting it
# leaves a pipeline starting with `|`, so the mutant dies on a syntax error and
# produces no output, which reads as "did not fire" and passes the assertion for
# entirely the wrong reason. The first version of this fixture did exactly that.
# The mutant is built in a copy of the WHOLE reconcile directory. The detector resolves
# `preclassify.sh` beside itself, and a lone copy in $WORK had no sibling: it read zero
# rows on every input and was silent for THAT reason, so this arm scored a kill the
# strip never earned. The stderr control below is what exposes it -- a mutant that ran
# says it opened one file; one with no sibling says preclassify produced no rows.
MDIR="$WORK/mutant-strip"
cp -R "$(dirname "$DETECT")" "$MDIR" || exit 2
MUTANT="$MDIR/$(basename "$DETECT")"
sed "s|grep -vE '\^\[\[:space:\]\]\*#'|cat|" "$DETECT" > "$MUTANT" || exit 2
if cmp -s "$DETECT" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the comment-strip line moved" >&2
  echo "  update the sed pattern in assertion 4" >&2
  exit 2
fi
bash -n "$MUTANT" 2>/dev/null || {
  echo "FIXTURE ERROR: mutant does not parse -- it would fail for the wrong reason" >&2
  exit 2; }
[ -f "$MDIR/preclassify.sh" ] || { echo "FIXTURE ERROR: mutant has no preclassify.sh beside it" >&2; exit 2; }
# Re-seed assertion 1's input: a genuinely severed contract, which the real
# detector catches.
cat > "$CONS/scripts/ai-dlc/validate-artifact-budget.sh" <<'OURS'
#!/bin/bash
CHAN="$ROOT/.chan"
printf 'x\n' >> "$ROOT/.chan"
pool_report() { printf 'OVER\n' >> "$ROOT/.chan"; }
OURS
out="$(bash "$MUTANT" "$DIST" "$BASE_SHA" "$THEIRS_SHA" "$CONS" 2>/dev/null)"
# The failure direction is SILENCE, not noise, and that is the point. THEIRS'
# header documents the retirement by naming the old path. Counting comments makes
# that mention look like a live use, so the token reads as still-in-use, `retired`
# comes back empty, and a real severed contract reports nothing. A detector muted
# by the release note explaining the very change it is meant to police.
if grep -q 'RETIRED-CONTRACT-TOKEN' <<<"$out"; then
  bad "MUTATION: the comment strip is inert -- assertions 1-3 prove nothing"
else
  ok "MUTATION: without the strip, THEIRS' own doc-comment masks a real severed contract"
fi
# The silence above must be the RIGHT silence: the mutant opened the file and derived an
# empty retired set, and its own stderr says so. A mutant that never ran says something
# else, or nothing.
merr="$(bash "$MUTANT" "$DIST" "$BASE_SHA" "$THEIRS_SHA" "$CONS" 2>&1 >/dev/null)"
if grep -q '1 of 3 CLASSIFY file(s) opened, 0 carrying' <<<"$merr"; then
  ok "MUTATION control: the mutant's silence is a scan that opened 1 file and retired nothing, by its own stderr"
else
  bad "MUTATION control: the mutant's silence is unexplained -- it may never have scanned: ${merr:-<no stderr>}"
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
# a PRESENCE, so a copy that emits nothing fails by construction.
PRE="$(dirname "$DETECT")/preclassify.sh"
THIRD_OURS="$CONS/scripts/ai-dlc/third.sh"
# Consumer states. The second core file never has a consumer copy (listed, never opened).
# The third has one only where a seed writes it (listed, opened, retiring nothing).
seed_at_theirs() { cp "$DIST/$CORE_PATH" "$CONS/scripts/ai-dlc/validate-artifact-budget.sh"; rm -f "$THIRD_OURS"; }
seed_third_modified() { printf '#!/bin/bash\nX="$ROOT/.third"\ny=3\n' > "$THIRD_OURS"; }
seed_repointed() {
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
  rm -f "$THIRD_OURS"
}
# stderr only; stdout discarded. `2>&1 >/dev/null` in that order.
err_of() { bash "$1" "$DIST" "$2" "$THEIRS_SHA" "$CONS" 2>&1 >/dev/null; }
out_of() { bash "$1" "$DIST" "$2" "$THEIRS_SHA" "$CONS" 2>/dev/null; }

# p5's world lists the two consumer-deleted CLASSIFY files and opens neither, so the
# listed count in the NOTE is asserted as a number, not merely as present.
p5() {
  seed_at_theirs
  o="$(out_of "$1" "$BASE_SHA")"; e="$(err_of "$1" "$BASE_SHA")"
  [ -z "$(printf '%s' "$o" | grep . || true)" ] \
    && grep -q 'listed 2 CLASSIFY file(s) and opened NONE, so NO core file was scanned' <<<"$e" \
    && ! grep -q 'produced no rows' <<<"$e"
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
p7() {
  seed_severed
  o="$(out_of "$1" "$BASE_SHA")"; e="$(err_of "$1" "$BASE_SHA")"
  grep -q 'RETIRED-CONTRACT-TOKEN.*\$ROOT/\.chan' <<<"$o" && [ -z "$e" ]
}
p8() {
  seed_at_theirs
  o="$(out_of "$1" "$THEIRS_SHA")"; e="$(err_of "$1" "$THEIRS_SHA")"
  [ -z "$(printf '%s' "$o" | grep . || true)" ] \
    && grep -q 'produced no rows' <<<"$e" \
    && ! grep -q 'NOTE --' <<<"$e"
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

# --- 9. MUTANTS: each wrong fix flips exactly its own predicate -------------------
# Build as a copy, refuse a sed that dies or matches nothing, refuse a copy that does not
# parse. Then score p5..p8 and compare the whole vector: a mutant that flips more than
# its own cell means two predicates are entangled; one that flips none means the
# predicate cannot fire.
# The mutant lives in a COPY OF THE WHOLE DIRECTORY, not a lone file: the detector finds
# `preclassify.sh` beside itself, and a copy with no sibling reads zero rows on every
# world, so every mutant scores the same vector and the score is about the harness.
# Measured on the first cut of this block: five mutants, one vector, 0001.
mkmut() {  # name sed-expr -> path on stdout
  d="$WORK/mut-$1"
  cp -R "$(dirname "$DETECT")" "$d" || { echo "FIXTURE ERROR: could not copy the reconcile dir for $1" >&2; exit 2; }
  m="$d/$(basename "$DETECT")"
  sed "$2" "$DETECT" > "$m" || { echo "FIXTURE ERROR: mutation $1 DID NOT APPLY (sed died)" >&2; exit 2; }
  cmp -s "$DETECT" "$m" && { echo "FIXTURE ERROR: mutation $1 matched nothing -- its anchor moved" >&2; exit 2; }
  bash -n "$m" 2>/dev/null || { echo "FIXTURE ERROR: mutant $1 does not parse" >&2; exit 2; }
  [ -f "$d/preclassify.sh" ] || { echo "FIXTURE ERROR: mutant $1 has no preclassify.sh beside it" >&2; exit 2; }
  printf '%s\n' "$m"
}
vec() { v=""; for p in p5 p6 p7 p8; do if "$p" "$1"; then v="${v}1"; else v="${v}0"; fi; done; printf '%s' "$v"; }
score() {  # name path expected-vector
  got="$(vec "$2")"
  if [ "$got" = "$3" ]; then ok "MUTATION $1: flips exactly its own predicate ($3)"
  else bad "MUTATION $1: expected $3 got $got (p5 p6 p7 p8)"; fi
}

if [ "$(vec "$DETECT")" = "1111" ]; then ok "unmutated control: every predicate holds"
else bad "unmutated control: $(vec "$DETECT") -- a mutant score below is meaningless"; fi

# NOTE deleted outright: the pre-fix script. p5 alone falls.
score "no-vacuity-note" "$(mkmut nonote 's|^  echo "retired-tokens: NOTE -- this pull listed|  : "|')" "0111"
# Wrong fix 1: key the vacuity NOTE on preclassify emitting nothing, rather than on
# opening nothing. The measured incident HAD rows (every path ALREADY-AT-THEIRS), so
# this fix is silent on its own motivating case and prints the denominator NOTE with
# a zero in it instead. p5 alone falls.
score "keyed-on-no-rows" "$(mkmut norows 's|^if \[ "\$opened" -eq 0 \]; then|if [ -z "$ROWS" ]; then|')" "0111"
# Wrong fix 1b: key the NOTE on the LISTED count. A CLASSIFY file the consumer deleted is
# listed and never opened, so a pull made only of those reads as scanned. p5's world
# lists exactly one such file, so p5 alone falls.
score "keyed-on-listed" "$(mkmut listed 's|^if \[ "\$opened" -eq 0 \]; then|if [ "$listed" -eq 0 ]; then|')" "0111"
# Wrong fix 2: one NOTE for every quiet run, worded as "opened nothing". True for the
# incident, false for a scan that opened files and matched nothing. p6 alone falls.
score "denominator-collapsed" "$(mkmut collapse 's|^  echo "retired-tokens: NOTE -- \$opened of \$listed CLASSIFY file(s) opened,|  echo "retired-tokens: NOTE -- opened NONE, listed $listed, $opened opened,|')" "1011"
# Wrong fix 2b: the denominator is the opened count itself. Reads as a complete scan on
# a pull that listed more than it opened. p6 alone falls, because its world lists 2 and
# opens 1.
score "opened-of-opened" "$(mkmut ofopened 's|\$opened of \$listed CLASSIFY file(s) opened,|$opened of $opened CLASSIFY file(s) opened,|')" "1011"
# Wrong fix 2c: the retiring count is a constant. Every earlier world had exactly one
# file retiring a token, so this passed both channels until the third file existed.
score "hardcoded-retiring" "$(mkmut retiring 's|\$retiring carrying a token upstream retired|1 carrying a token upstream retired|')" "1011"
# Wrong fix 1c: the listed count in the opened-NONE NOTE is fabricated. p5 alone falls,
# because its world lists exactly two.
score "fabricated-listed" "$(mkmut fablisted 's|listed \$listed CLASSIFY file(s)\${ONLY:+|listed 47 CLASSIFY file(s)${ONLY:+|')" "0111"
# Wrong fix 3: a NOTE beside real rows. Drop the early exit after the rows print so the
# denominator NOTE follows every match. p7 alone falls.
score "note-beside-rows" "$(mkmut fallthrough '/^  printf '"'"'%s'"'"' "\$rows"$/{n;s|^  exit 0$|  :|;}')" "1101"
# Refusal neutered: an unresolvable input falls through to the vacuity NOTE. p8 alone falls.
score "refusal-neutered" "$(mkmut norefuse 's|^  echo "retired-tokens: preclassify.sh produced no rows|  : "|')" "1110"

echo ""
if [ "$fails" -eq 0 ]; then
  echo "retired-contract-token: PASS"
  exit 0
fi
echo "retired-contract-token: FAIL ($fails assertion(s))"
exit 1
