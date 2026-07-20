#!/usr/bin/env bash
# Seed for the push-candidate ledger closer (reconcile/ledger-reverify.sh).
#
# Builds a throwaway DISTRIBUTION git repo with a `base` and a `theirs` commit, and a
# consumer root whose ledger has three OPEN-looking entries that differ ONLY in what
# `theirs` contains:
#
#   Entry A  verify: theirs_lacks … "MARKER_A"  — theirs STILL lacks it  -> STILL-LIVE
#   Entry B  verify: theirs_lacks … "MARKER_B"  — theirs ADDED it        -> CLOSE-CANDIDATE
#   Entry C  same verify as B, but annotated ADOPTED UPSTREAM            -> skipped (closed)
#
# A and B carry IDENTICAL verify directives except the substring; the only reason they
# classify differently is what `theirs` holds. A closer that reads `base` (not `theirs`)
# sees neither marker and calls BOTH still-live — which is the mutation the fixture catches.
#
# Usage: seed.sh   -> prints "<dist> <base> <consumer> <theirs>" on one line.
set -eu

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ledger-reverify-XXXXXX")"
DIST="$TMP/dist"
CONS="$TMP/consumer"
mkdir -p "$DIST" "$CONS"

git -C "$DIST" init -q
git -C "$DIST" config user.email seed@fixture
git -C "$DIST" config user.name seed

mkdir -p "$DIST/core/skills/ai-dlc"
SK="$DIST/core/skills/ai-dlc/SKILL.md"

# --- base: neither marker present ---
printf '# SKILL\nrule one\nrule two\n' > "$SK"
printf '0.100.0\n' > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -qm base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# --- theirs: MARKER_B added (Entry B absorbed), MARKER_A still absent ---
printf '# SKILL\nrule one\nrule two\nMARKER_B a rule upstream just absorbed\n' > "$SK"
printf '0.101.0\n' > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -qm theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# --- consumer ledger ---
LED="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
mkdir -p "$(dirname "$LED")"
cat > "$LED" <<'LEDGER'
# AI/DLC Push-Candidate Ledger

## Open — filed for the fixture

- **Entry A still lacked upstream.** A generalizable improvement core does not carry.
  <br>Some prose. More prose describing the receipt.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **Entry B was live, now absorbed.** Another improvement, since taken upstream.
  <br>Receipt prose here.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

- **Entry C already closed.** This one was adopted last pull.
  <br>ADOPTED UPSTREAM (v0.99.0, verified 2026-07-19). Closed.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

- **Entry D has no verify line.** A legacy prose entry, hand-review as today.
  <br>No machine-runnable receipt; the closer must not emit a row for it.
LEDGER

printf '%s %s %s %s\n' "$DIST" "$BASE" "$CONS" "$THEIRS"
