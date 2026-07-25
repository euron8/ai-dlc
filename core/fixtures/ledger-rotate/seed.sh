#!/usr/bin/env bash
# ledger-rotate/seed.sh — a ledger holding CLOSED and OPEN entries in both supported shapes,
# plus a preamble that must never move and a decoy that must never be treated as closed.
#
# The decoys matter more than the happy path. "ADOPTED UPSTREAM" appearing in an OPEN entry's
# prose — an instruction saying what to annotate on close — is the realistic way a rotation
# eats live work, and it is exactly what this ledger's real entries contain.
set -uo pipefail

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
mkdir -p "$WORK/_bmad-output/ai-dlc-update"
L="$WORK/_bmad-output/ai-dlc-update/push-candidate-ledger.md"

cat > "$L" <<'EOM'
# Push-candidate ledger

Preamble prose that belongs to no entry and must always stay in the live file.

## PC-OPEN-A — still live upstream

Body text.

verify: theirs_has core/scripts/thing.sh "MARKER_A"

---

## PC-CLOSED-A — upstream took this

Body text.

<br>**ADOPTED UPSTREAM (v0.99.0, verified 2026-01-01).** Upstream took it.

verify: theirs_lacks core/scripts/thing.sh "MARKER_C"

---

## PC-OPEN-DECOY — mentions the phrase without being closed

This entry is OPEN. Its body instructs the operator to annotate
`ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` only once the grep is non-zero, and
notes the sentinel was ADOPTED UPSTREAM in v0.135.0 as narrative prose.

verify: theirs_has core/scripts/thing.sh "MARKER_D"

---

- **PC-OPEN-BULLET** — the bullet entry shape is also supported

  verify: theirs_has core/scripts/thing.sh "MARKER_B"

- **PC-CLOSED-BULLET** — a closed bullet entry

  <br>**ADOPTED UPSTREAM (v0.98.0, verified 2026-01-01).** Upstream took it.

  verify: theirs_lacks core/scripts/thing.sh "MARKER_E"
EOM

# A dist the classifier can resolve against, so ledger-reverify produces real verdicts to
# compare across the rotation rather than a wall of unresolved paths.
mkdir -p "$WORK/dist/core/scripts"
cd "$WORK/dist" || exit 2
git init -q .
printf '0.1.0\n' > VERSION
printf 'MARKER_A\nMARKER_B\nMARKER_D\n' > core/scripts/thing.sh
git -C "$WORK/dist" -c user.email=f@f -c user.name=f -c commit.gpgsign=false add -A
git -C "$WORK/dist" -c user.email=f@f -c user.name=f -c commit.gpgsign=false commit -qm base
BASE="$(git -C "$WORK/dist" rev-parse HEAD)"
git -C "$WORK/dist" -c user.email=f@f -c user.name=f -c commit.gpgsign=false commit -q --allow-empty -m theirs
THEIRS="$(git -C "$WORK/dist" rev-parse HEAD)"

cd "$WORK" || exit 2
git init -q .
git -C "$WORK" -c user.email=f@f -c user.name=f -c commit.gpgsign=false add -A >/dev/null 2>&1
git -C "$WORK" -c user.email=f@f -c user.name=f -c commit.gpgsign=false commit -qm consumer >/dev/null 2>&1

cat > "$WORK/env.sh" <<EOF
WORK="$WORK"
LEDGER="$L"
DIST="$WORK/dist"
CONSUMER="$WORK"
BASE="$BASE"
THEIRS="$THEIRS"
EOF

printf '%s\n' "$WORK"
