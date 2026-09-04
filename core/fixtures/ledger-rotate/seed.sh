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

## PC-S900-ALPHA — open, and shares a SPRINT PREFIX with the two entries below it

A `PC-S<n>` prefix carried by two or more entries is what makes ledger-reverify emit a
NAMED-UPSTREAM-AMBIGUOUS row, and that row's detail carries `prefix_entry_count()`. Without a
prefix in this ledger the acceptance assertion in run.sh has no subject at all.

verify: theirs_has core/scripts/thing.sh "MARKER_A"

---

## PC-S900-BETA — open, and carries the same sprint prefix

The second live member. Two live members keep the prefix ambiguous on BOTH sides of the
rotation, so the row survives the move and only its COUNT changes — which is the whole
distinction between the row set and the bytes.

verify: theirs_has core/scripts/thing.sh "MARKER_B"

---

## PC-S900-GAMMA — closed in the same pass that rotates it, and the third member of the prefix

THIS ENTRY IS THE POINT OF THE TRIO. `prefix_entry_count()` counts the prefix over the CORPUS —
every entry line in both files, open or closed — so this entry is counted while it sits
annotated in the LIVE file and counted once it is on the archive side: 3 -> 3 across the move.
It used to count OPEN entries unioned with ARCHIVED labels, which put this entry on neither side
until the rotate and made the count dip 2 -> 3 across a move that can only shrink the live set.
Annotate-then-rotate in one pass is what SKILL.md step 8 prescribes, so this is the ordinary
case and not a constructed one.

<br>**ADOPTED UPSTREAM (v0.97.0, verified 2026-01-01).** Upstream took it.

verify: theirs_has core/scripts/thing.sh "MARKER_A"

---

## PC-CLOSED-FENCED — closed, and its derived block records a heading-shaped output line

THE SUBJECT OF PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS on the rotate
side. The fenced `## <ts> -- EVENT` line below is recorded output, not an entry. A fence-blind
boundary rule opened an entry there, so the head of this entry stayed live with an
unterminated fence while the tail — annotation, receipt, closing fence — archived under a
timestamp label. The reference consumer's live ledger carries exactly that residue today.

```derived
$ grep '^## ' pipeline-continuation-log.md | head -1
## 2000-01-01T00:00:00Z -- FENCED-EVENT
```

<br>**ADOPTED UPSTREAM (v0.95.0, verified 2026-01-01).** Upstream took it.

verify: theirs_has core/scripts/thing.sh "MARKER_A"

---

- **PC-OPEN-BULLET** — the bullet entry shape is also supported

  verify: theirs_has core/scripts/thing.sh "MARKER_B"

- **PC-CLOSED-BULLET** — a closed bullet entry

  <br>**ADOPTED UPSTREAM (v0.98.0, verified 2026-01-01).** Upstream took it.

- **Entry STUCK is closed for re-verification and unarchivable.** A genuine, deliberate,
  BOLDED close whose parenthetical carries no version, which is the form an operator writes
  when the absorption predates the pull's base.
  <br>**ADOPTED UPSTREAM (absorbed before base abc1234, verified 2026-01-01).**
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_STUCK"

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
# UPSTREAM CITES THE SHORT SPRINT ID, NEVER THE FULL SLUG, and both halves of that are load-
# bearing. `named_ambiguous()` returns nothing at all when the SLUG search hits, so a message
# naming `PC-S900-ALPHA` would suppress the ambiguous row this seed exists to produce. The
# prefix search is anchored (`PC-S900([^0-9A-Za-z-]|$)`), so the trailing space is what makes
# it match.
git -C "$WORK/dist" -c user.email=f@f -c user.name=f -c commit.gpgsign=false commit -q --allow-empty \
  -m 'upstream sprint work landed: PC-S900 and PC-S901 absorbed'
# PC-S910 GETS ITS OWN COMMIT, and that is not cosmetic. `named_ambiguous()` prints the sha it
# found and `named_absorbed()` prints how many commits named the id, so folding a third prefix
# into the message above would move the DETAIL column of every PC-S900 and PC-S901 row. The
# assertion that reads those details (`pfx_n`, the 3 -> 3 arm) would then be reading a string
# this addition changed rather than one the rotation changed.
git -C "$WORK/dist" -c user.email=f@f -c user.name=f -c commit.gpgsign=false commit -q --allow-empty \
  -m 'upstream sprint work landed: PC-S910 absorbed'
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
