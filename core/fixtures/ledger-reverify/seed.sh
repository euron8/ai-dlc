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

mkdir -p "$DIST/core/skills/ai-dlc" "$DIST/core/scripts"
SK="$DIST/core/skills/ai-dlc/SKILL.md"

# `SKILL.md` is UNIQUE in this tree — that is what lets a consumer-namespace path resolve by
# basename. `validate-thing.sh` is DELIBERATELY duplicated across two directories so the
# ambiguous case has something to be ambiguous about: the fallback must refuse to guess when
# a basename matches more than one file, not pick the first.
printf '#!/bin/sh\necho thing\n' > "$DIST/core/scripts/validate-thing.sh"
printf '#!/bin/sh\necho thing\n' > "$DIST/core/skills/ai-dlc/validate-thing.sh"

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

- **Entry E declares manual.** No mechanical predicate exists for this claim.
  <br>Hand-review is the DECLARATION, not a malformed line — it must not share a verdict
  with a typo.
  verify: manual

- **Entry F declares manual with a stray backtick.** Prose formatting leaked into the verb.
  <br>A formatting slip must not change the verdict.
  verify: manual`

- **Entry G is Entry B filed in the consumer's install namespace.** Same claim, same
  substring; only the path layout differs (`core/.claude/skills/…` instead of
  `core/skills/…`). It MUST classify identically to Entry B — a closer that cannot resolve
  the path never compares the substring and silently reports nothing about the claim.
  verify: theirs_lacks core/.claude/skills/ai-dlc/SKILL.md "MARKER_B"

- **Entry H names an ambiguous basename.** Two files at theirs are called
  `validate-thing.sh`, so the fallback has no unique answer and must refuse to guess.
  verify: theirs_lacks core/scripts/ai-dlc/validate-thing.sh "MARKER_B"

- **Entry I names a basename that exists nowhere at theirs.** Nothing to fall back to.
  verify: theirs_has core/scripts/ai-dlc/no-such-file.sh "MARKER_B"

- **Entry J has an inverted verb.** MARKER_A names the FIX the entry wants, so the author
  reached for `theirs_has` when the claim needs `theirs_lacks`.
  <br>MARKER_A is absent at base AND at theirs, so this predicate could never have reported
  STILL-LIVE — it was born closed and no upstream change produced the verdict.
  verify: theirs_has core/skills/ai-dlc/SKILL.md "MARKER_A"

- **Entry K is the same vacuity in the other direction.** `rule one` is present at base AND
  at theirs, so `theirs_lacks` could never have reported STILL-LIVE either.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "rule one"

- **Entry L names TWO substrings.** Both are absent at theirs, so the entry is genuinely
  still live — but only if each is matched separately.
  <br>Joined into one literal (quotes and all) it matches nothing, which reports
  "still lacks" for the right verdict by accident.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A" "MARKER_C"

- **Entry M names two substrings that theirs BOTH carries.** `rule one` and `MARKER_B` are
  each present at theirs, so upstream holds everything the entry asked for.
  <br>This is the case the joined literal gets WRONG: it matches nothing, reports
  "still lacks", and the entry stays open forever against an upstream that already has it.
  Base carries `rule one` but NOT `MARKER_B`, so the close is real, not vacuous.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "rule one" "MARKER_B"

---

## PC-FIXTURE-HEADING-ABSORBED — the heading entry shape (filed for the fixture)

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

Entries grow into this shape once the receipt outgrows a bullet. Identical directive to
Entry B, so it must classify identically — a parser that treats a heading as a pure
terminator drops it silently and reports nothing to close.

---

## PC-FIXTURE-HEADING-CLOSED — heading shape, already adopted

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

ADOPTED UPSTREAM (v0.101.0, verified for the fixture). Closed — must not be re-emitted.

---

## PC-FIXTURE-HEADING-NO-VERIFY — heading shape, no directive

Prose only. Must NOT inherit the directive of the heading entry above it: a heading opens
an entry, so it also ends the one before it.
LEDGER

printf '%s %s %s %s\n' "$DIST" "$BASE" "$CONS" "$THEIRS"
