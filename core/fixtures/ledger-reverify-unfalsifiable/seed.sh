#!/usr/bin/env bash
# ledger-reverify-unfalsifiable/seed.sh — a synthetic dist + consumer carrying TWO
# `theirs_lacks` entries whose substrings are absent at BOTH base and theirs.
#
# That is the state two refs cannot decide: it is the normal state of a live push
# candidate AND the state of a predicate no adoption will ever satisfy. The two entries
# differ in exactly ONE variable — whether the substring exists in the consumer's own
# implementation — so any verdict difference between them is attributable to that and
# nothing else.
#
#   PC-GOOD  anchors on `--strict-provenance`, a flag the consumer really implements.
#            A fix upstream cannot be written without naming it. Must stay STILL-LIVE.
#   PC-BAD   anchors on "strict provenance enforced by default", prose invented to
#            describe the fix. Exists nowhere and never will. Must be NEEDS-REVIEW.
#
# Self-contained: builds its own dist repo rather than pinning shas from the real
# history, so the fixture cannot rot when upstream moves. Idempotent.
set -uo pipefail

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
# Walk UP for the marker rather than counting `..` hops — the fixture must resolve from
# either layout (dist `core/`, consumer `.claude/`) and from any depth.
RV=""
d="$HERE"
while [ "$d" != "/" ]; do
  for cand in "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
              "$d/.claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; do
    [ -f "$cand" ] && { RV="$cand"; break 2; }
  done
  d="$(dirname "$d")"
done
[ -n "$RV" ] || { echo "FIXTURE ERROR: ledger-reverify.sh not found in either layout" >&2; exit 2; }

g() { git -C "$1" -c user.email=f@f -c user.name=f -c commit.gpgsign=false "${@:2}"; }

# --- synthetic distribution: base and theirs, neither carrying either substring -------
mkdir -p "$WORK/dist/core/scripts"
cd "$WORK/dist" || exit 2
git init -q .
printf '0.1.0\n' > VERSION
cat > core/scripts/validate-thing.sh <<'EOS'
#!/bin/bash
# upstream's version: no strict mode of any kind
run_thing() { :; }
EOS
# A file LARGER than the pipe buffer (~64 KB), carrying its needle at the very top. Any
# match test that pipes into `grep -q` under `set -o pipefail` reports this as NOT FOUND:
# grep exits on the first line, the writer takes SIGPIPE, and the pipeline's status becomes
# that failure. Under 64 KB the write completes first and the same code is correct, which is
# why the defect presents as flakiness rather than a size threshold. run.sh pins the verdict
# across repeated runs.
{
  printf 'NEEDLE_AT_TOP_OF_A_LARGE_FILE\n'
  i=0; while [ "$i" -lt 3000 ]; do
    printf 'padding line %s ---------------------------------------------------------\n' "$i"
    i=$((i + 1))
  done
} > core/scripts/big-rule-file.md
g "$WORK/dist" add -A; g "$WORK/dist" commit -qm base
BASE="$(git -C "$WORK/dist" rev-parse HEAD)"
printf '0.2.0\n' > VERSION
cat >> core/scripts/validate-thing.sh <<'EOS'
# theirs moved, but still has no strict mode
EOS
g "$WORK/dist" add -A; g "$WORK/dist" commit -qm theirs
THEIRS="$(git -C "$WORK/dist" rev-parse HEAD)"

# --- synthetic consumer: implements the innovation PC-GOOD anchors on -----------------
mkdir -p "$WORK/consumer/_bmad-output/ai-dlc-update" "$WORK/consumer/scripts"
cat > "$WORK/consumer/scripts/thing.sh" <<'EOS'
#!/bin/bash
# the local hardening this consumer built and wants upstreamed
case "${1:-}" in --strict-provenance) STRICT=1 ;; esac
EOS
# A file that SURVIVES run.sh's mutation. Without it, removing the anchor also empties the
# scan set, the undecidable path fires, and the mutation would "pass" for the wrong reason.
cat > "$WORK/consumer/scripts/keep.sh" <<'EOS'
#!/bin/bash
echo "unrelated; keeps the scan set non-empty under mutation"
EOS
# --- subjects for the `verify: sh` arm's unfalsifiability guard ------------------------
# The consumer's copy sits at BASE, which is the ordinary state and the one that makes a
# negated grep exit 0 (= still reproduces) while the token exists upstream at THEIRS.
# map_consumer() sends core/scripts/<x> to scripts/ai-dlc/<x>, so THAT is where a receipt
# naming this subject has to point; a copy under plain scripts/ maps to nothing and would
# make every arm below undecidable rather than testing anything.
mkdir -p "$WORK/consumer/scripts/ai-dlc"
git -C "$WORK/dist" show "${BASE}:core/scripts/validate-thing.sh" \
  > "$WORK/consumer/scripts/ai-dlc/validate-thing.sh"
# A SECOND, INDEPENDENT subject. Without it the watchdog arm and the alternation arm would
# share one file, and a guard that mis-reads either would be covered by the other reaching
# the same bytes — two guards covering each other report ZERO failures, which is
# indistinguishable from two that never fired.
cat > "$WORK/consumer/scripts/ai-dlc/retired-marker.sh" <<'EOS'
#!/bin/bash
# the replacement token a STAYS-RETIRED watchdog asserts is present
use_new_anchor() { :; }
EOS
cat > "$WORK/consumer/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'EOM'
## PC-GOOD — anchored on a flag the fix cannot be written without

The consumer runs a strict provenance mode upstream lacks.

verify: theirs_lacks core/scripts/validate-thing.sh "--strict-provenance"

---

## PC-BAD — anchored on prose describing the wanted fix

Upstream should enforce provenance strictly by default.

verify: theirs_lacks core/scripts/validate-thing.sh "strict provenance enforced by default"

---

## PC-BIG — a defect in a file larger than the pipe buffer

Upstream still carries the marker, in a file over 64 KB.

verify: theirs_has core/scripts/big-rule-file.md "NEEDLE_AT_TOP_OF_A_LARGE_FILE"

---

## PC-SH-UPSTREAM — bucket 1: the receipt consults THEIRS, so a pull can settle it

Reads the upstream blob directly, which is what the falsifiable shape looks like.

verify: sh cd "$CONSUMER" && ! grep -qF ZZ_NEVER_EXISTS <<<"$(git -C "$DIST" show "${THEIRS}:core/scripts/validate-thing.sh")"

---

## PC-SH-INSTALLED — bucket 3: consumer-side only, but upstream SHIPS this subject

THE DEFECT, and the shape the reference consumer actually hit. The predicate never mentions
`$THEIRS` or `$DIST`, so it reads the consumer's INSTALLED copy — frozen at base until an
apply — while `core/scripts/validate-thing.sh` exists upstream and is where the fix lands.
The verdict can therefore never change, whatever tokens it keys on. Its token is deliberately
one that no fix would ever introduce, to make the point that TOKEN CHOICE IS NOT THE DEFECT:
a perfectly-anchored version of this same receipt is equally permanently green.

verify: sh cd "$CONSUMER" && [ -f scripts/ai-dlc/validate-thing.sh ] && ! grep -q ZZ_NEVER_EXISTS scripts/ai-dlc/validate-thing.sh

---

## PC-SH-CONSUMER-OWNED — bucket 2: consumer-side only, and upstream ships NO counterpart

THE ARM'S LOAD-BEARING DISTINCTION, paired with PC-SH-INSTALLED above. Structurally identical
receipt — same verb, same negation, same token, also never consulting upstream — differing in
ONE property: `scripts/keep.sh` has no core preimage, because map_consumer() sends
`core/scripts/<x>` to `scripts/ai-dlc/<x>` and never to bare `scripts/`. No pull can settle
this, and that is not a defective receipt but a standing consumer-side invariant, so it must
NOT be accused.

Its subject is a DIFFERENT FILE from PC-SH-INSTALLED's on purpose. Sharing one would let a
guard that mis-resolves the mapping reach the same bytes for both, and two guards covering one
subject report zero failures — indistinguishable from two that never fired.

verify: sh cd "$CONSUMER" && [ -f scripts/keep.sh ] && ! grep -q ZZ_NEVER_EXISTS scripts/keep.sh

---

## PC-SH-WATCHDOG — a STAYS-RETIRED watchdog, whose permanent exit 0 is CORRECT

Asserts a retired token has not come back and its replacement is present. Exit 0 forever is
the healthy steady state; it flips only on a regression. Scans tree-wide with no named
subject, which is the clause that must keep this out of the guard's population.

The `:(exclude)` pathspecs are copied from the two live receipts of this shape, not invented:
without them the scan finds the retired token IN THIS VERY ENTRY and the watchdog reports a
close it never earned. A seed built from what the reader accepts instead of what the real
producer emits would have missed that and tested a shape nobody ships.

verify: sh cd "$CONSUMER" && ! git grep -qF ZZ_RETIRED_TOKEN -- ":(exclude)_bmad-output" ":(exclude)docs" && git grep -qF use_new_anchor -- ":(exclude)_bmad-output" ":(exclude)docs"

---
EOM
cd "$WORK/consumer" || exit 2
git init -q .
g "$WORK/consumer" add -A; g "$WORK/consumer" commit -qm consumer

cat > "$WORK/env.sh" <<EOF
WORK="$WORK"
RV="$RV"
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
BASE="$BASE"
THEIRS="$THEIRS"
EOF

printf '%s\n' "$WORK"
