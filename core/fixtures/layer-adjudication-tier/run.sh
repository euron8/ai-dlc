#!/usr/bin/env bash
# layer-adjudication-tier — assert `level: ADJUDICATED` is a mechanism and not a declaration.
#
# Usage: run.sh [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = something regressed.
#
# THE LOAD-BEARING ASSERTION IS THE TRIPLE IN PARTS 1-3: no record blocks, a record clears, and
# ONE BYTE of change to the entry blocks again. A register keyed by PATH passes the first two and
# fails the third, and a path-keyed register is a permanent exemption wearing an adjudication's
# clothes — the failure this tier exists to foreclose. Parts 1 and 2 alone are satisfied by it.
#
# EVERY "a blocking row appeared" ASSERTION HAS A SAME-RUN CONTROL: the seeded contract also
# carries a clause at WARN, and Part 5 flips the adjudicable clause's LEVEL and re-runs. Without
# that, a classifier that had started emitting the blocking row unconditionally would score as a
# pass on all of Parts 1-4.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
DRIFT="$(pick "${1:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
[ -n "$DRIFT" ] || { echo "FIXTURE ERROR: cannot locate layer-drift.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"
BASE="$(git -C "$DIST" rev-parse --short HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"
ENTRY=".claude/skills/ai-dlc/extensions/adjudicable.md"
REG="$CONS/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
CONTRACT="$DIST/core/skills/ai-dlc/layer-contract.yaml"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

run()    { bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
blocks() { run | grep -c '^HARD-LAYER-ADJUDICATION-MISSING'; }
drifts() { run | grep -c '^EXTENSION-HOOK-DRIFT'; }
digest() { run | awk -F'\t' '$1 == "HARD-LAYER-ADJUDICATION-MISSING"' \
                 | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1; }

# EVERY PART RE-DERIVES ITS OWN DIGEST FROM A CLEARED REGISTER. Threading one `$DIG` through the
# file made Part 4b's precondition depend on Part 3's outcome: a mutant that broke the digest
# KEYING left Part 3 unblocked, `digest()` then returned empty, and Part 4b recorded against an
# empty key and reported a second failure for the first mutant's defect. Two failures from one
# mutation mean the assertions are entangled and one of them is measuring the other.
fresh_digest() { rm -f "$REG"; digest; }
need_digest() { # $1 part label -> echoes a 40-hex digest or records the failure
  local d; d="$(fresh_digest)"
  if [ ${#d} -ne 40 ]; then
    bad "$1 could not obtain a subject digest from a cleared register, so its own assertion below would measure the wrong thing. Read the earlier parts first: this is a consequence, not an independent finding"
    return 1
  fi
  printf '%s' "$d"
}

record() { # $1 digest, $2 verdict, [$3 supersedes]
  if [ -n "${3:-}" ]; then
    printf '{"clause":"LC-E4","entry":"%s","subject_digest":"%s","verdict":"%s","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded","supersedes":"%s"}\n' \
      "$ENTRY" "$1" "$2" "$3"
  else
    printf '{"clause":"LC-E4","entry":"%s","subject_digest":"%s","verdict":"%s","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded"}\n' \
      "$ENTRY" "$1" "$2"
  fi
}

echo "layer-adjudication-tier:"

command -v jq >/dev/null 2>&1 || { echo "  SKIP  jq is not on PATH; the register cannot be read and every assertion below would be vacuous" >&2; exit 0; }

# --- Part 0: the seed is a real range and the classifier ran ------------------
# Parts 2 and 5 assert a blocking row is ABSENT. A run that emitted nothing at all satisfies
# both, so the presence of the candidate row is established first.
if [ "$(drifts)" -eq 1 ]; then
  ok "the classifier emits exactly 1 EXTENSION-HOOK-DRIFT row (the candidate every absence assertion below is measured against)"
else
  bad "expected exactly 1 EXTENSION-HOOK-DRIFT row, got $(drifts) — the seeded range is not producing the candidate, so every absence assertion in this file would pass vacuously"
fi
if git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- core/skills/ai-dlc/steps/demo.md; then
  bad "the seeded range does not change the hooked file, so the re-read duty has nothing to fire on"
else
  ok "the seeded range really does change the hooked file"
fi

# --- Part 1: unrecorded BLOCKS ------------------------------------------------
[ -f "$REG" ] && rm -f "$REG"
if [ "$(blocks)" -eq 1 ]; then
  ok "no register: 1 HARD-LAYER-ADJUDICATION-MISSING — an adjudicable row with no verdict blocks"
else
  bad "no register produced $(blocks) blocking rows, expected 1 — the level is declared and not acted on, so ADJUDICATED is a WARN with extra prose"
fi

DIG="$(digest)"
if [ ${#DIG} -eq 40 ]; then
  ok "the blocking row carries a 40-hex subject_digest (the operator copies a value; nobody re-derives one)"
else
  bad "the blocking row carries no usable subject_digest ('$DIG') — an operator cannot record a verdict against a key the row does not print"
fi

# --- Part 2: recorded CLEARS, and the candidate row SURVIVES ------------------
record "$DIG" still-additive > "$REG"
if [ "$(blocks)" -eq 0 ]; then
  ok "verdict recorded: 0 blocking rows — the duty is discharged by the record"
else
  bad "a matching record left $(blocks) blocking rows — the register is not being read, or the digest the row prints is not the digest it looks up"
fi
if [ "$(drifts)" -eq 1 ]; then
  ok "the EXTENSION-HOOK-DRIFT row still prints once adjudicated — its clause's code stays live, so I36 is joining a code that is actually emitted"
else
  bad "recording a verdict suppressed the candidate row itself. Then LC-E4's declared code is emitted by nothing, its clause cannot fire, and I36's grep over this script would still pass on the string in a comment"
fi

# --- Part 3: ONE BYTE of entry change RE-FIRES it -----------------------------
# The arm a path-keyed register fails. Nothing about the register changes here.
printf '\n' >> "$CONS/$ENTRY"
if [ "$(blocks)" -eq 1 ]; then
  ok "entry body +1 byte: blocking again — the verdict was keyed to the subject STATE, not to the path"
else
  bad "the entry's body changed and the recorded verdict still cleared it. That record is a permanent exemption for the path: every future core change inherits a verdict made against text that no longer exists"
fi
# --- Part 4a: a verdict OUTSIDE the schema's enum does not discharge it -------
if DIG="$(need_digest 'Part 4a')"; then
record "$DIG" looks-fine-to-me > "$REG"
if [ "$(blocks)" -eq 1 ]; then
  ok "off-vocabulary verdict: still blocking — a record only counts when its verdict is one the schema defines"
else
  bad "the string 'looks-fine-to-me' cleared a blocking row. Any value would, and the adjudication is then a formality a typo passes"
fi
fi

# --- Part 4b: the vocabulary is READ from the schema, not restated ------------
# Mutate the schema's enum in the seeded distribution and re-commit: a verdict that WAS valid
# must stop discharging the duty. A reader with the three strings baked in passes Part 4a and
# fails only here.
if DIG="$(need_digest 'Part 4b')"; then
record "$DIG" retire > "$REG"
sed 's/"retire"/"retired-under-a-different-name"/' "$DIST/core/schemas/layer-adjudication-register.json" > "$DIST/core/schemas/x.json"
if cmp -s "$DIST/core/schemas/layer-adjudication-register.json" "$DIST/core/schemas/x.json"; then
  bad "the enum mutation matched nothing, so Part 4b's silence proves nothing about where the vocabulary comes from"
else
  mv "$DIST/core/schemas/x.json" "$DIST/core/schemas/layer-adjudication-register.json"
  git -C "$DIST" add -A && git -C "$DIST" commit -qm "mutate the verdict enum"
  THEIRS_M="$(git -C "$DIST" rev-parse --short HEAD)"
  n="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS_M" "$CONS" 2>/dev/null | grep -c '^HARD-LAYER-ADJUDICATION-MISSING')"
  if [ "$n" -ge 1 ]; then
    ok "the enum moved in the schema and 'retire' stopped discharging the duty — the vocabulary is read from the schema, not restated in the reader"
  else
    bad "'retire' still cleared the row after the schema's enum no longer contains it, so the reader carries its own copy of the vocabulary and the schema is decoration"
  fi
  git -C "$DIST" reset -q --hard HEAD~1
fi
fi

# --- Part 5: THE LEVEL IS WHAT DECIDES ---------------------------------------
# Flip the adjudicable clause to WARN in the seeded contract. Same code, same row, same
# register, no duty. This is the control for every "a blocking row appeared" assertion above.
rm -f "$REG"
[ "$(blocks)" -eq 1 ] || bad "Part 5's precondition failed: the row is not blocking before the level is flipped, so flipping it proves nothing"
sed 's/^    level: ADJUDICATED$/    level: WARN/' "$CONTRACT" > "$CONTRACT.mut"
if cmp -s "$CONTRACT" "$CONTRACT.mut"; then
  bad "the level mutation matched nothing in the seeded contract, so Part 5's silence proves nothing"
else
  mv "$CONTRACT.mut" "$CONTRACT"
  git -C "$DIST" add -A && git -C "$DIST" commit -qm "flip LC-E4 to WARN"
  THEIRS_W="$(git -C "$DIST" rev-parse --short HEAD)"
  n="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS_W" "$CONS" 2>/dev/null | grep -c '^HARD-LAYER-ADJUDICATION-MISSING')"
  d="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS_W" "$CONS" 2>/dev/null | grep -c '^EXTENSION-HOOK-DRIFT')"
  if [ "$n" -eq 0 ] && [ "$d" -eq 1 ]; then
    ok "clause flipped to WARN: 0 blocking rows and the candidate row unchanged — the CONTRACT's level decides, so migrating a clause needs no edit to the classifier"
  else
    bad "flipping the level to WARN left $n blocking row(s) and $d candidate row(s), expected 0 and 1 — the adjudicable set is not derived from the contract, so it is a hand-list somewhere and this tier has a second home"
  fi
  git -C "$DIST" reset -q --hard HEAD~1
fi

# --- Part 6: LC-A2, the contradiction arm ------------------------------------
# The contradiction is a property of the REGISTER, so this part needs a well-formed key but does
# not depend on whether any earlier part cleared its row.
DIG="$(need_digest 'Part 6')" || DIG=""
{ record "$DIG" still-additive; record "$DIG" retire; } > "$REG"
if [ "$(run | grep -c '^HARD-REGISTER-CONTRADICTION')" -ge 1 ]; then
  ok "two verdicts under one key with no supersedes: HARD-REGISTER-CONTRADICTION — a lookup would otherwise answer with whichever record was read last"
else
  bad "two records under one key state different verdicts and nothing reported it. Which one wins then depends on file order, and so does whether the pull blocks"
fi

{ record "$DIG" still-additive; record "$DIG" retire "the earlier reading missed core's new paragraph"; } > "$REG"
if [ "$(run | grep -c '^HARD-REGISTER-CONTRADICTION')" -eq 0 ]; then
  ok "the same pair WITH supersedes and a reason: no contradiction — retraction stays available, it just has to be declared"
else
  bad "a properly declared supersession still reported a contradiction. An operator who cannot change their mind will stop recording verdicts at all"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "layer-adjudication-tier: PASS"
  exit 0
fi
echo "layer-adjudication-tier: FAIL ($fails)"
exit 1
