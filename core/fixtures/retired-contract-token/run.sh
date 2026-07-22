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
if printf '%s' "$out" | grep -q 'RETIRED-CONTRACT-TOKEN.*\$ROOT/\.chan'; then
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
MUTANT="$WORK/mutant.sh"
sed "s|grep -vE '\^\[\[:space:\]\]\*#'|cat|" "$DETECT" > "$MUTANT" || exit 2
if cmp -s "$DETECT" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the comment-strip line moved" >&2
  echo "  update the sed pattern in assertion 4" >&2
  exit 2
fi
bash -n "$MUTANT" 2>/dev/null || {
  echo "FIXTURE ERROR: mutant does not parse -- it would fail for the wrong reason" >&2
  exit 2; }
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
if printf '%s' "$out" | grep -q 'RETIRED-CONTRACT-TOKEN'; then
  bad "MUTATION: the comment strip is inert -- assertions 1-3 prove nothing"
else
  ok "MUTATION: without the strip, THEIRS' own doc-comment masks a real severed contract"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "retired-contract-token: PASS"
  exit 0
fi
echo "retired-contract-token: FAIL ($fails assertion(s))"
exit 1
