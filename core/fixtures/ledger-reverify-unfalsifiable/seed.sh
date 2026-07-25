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
