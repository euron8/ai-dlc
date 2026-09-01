#!/usr/bin/env bash
# reconcile-emit-report/seed.sh — a consumer with a real in-place core drift, and three candidate
# reports: one carrying emit-report's rendered mechanical region verbatim, one with NO region, and
# one whose region was hand-edited to drop the blocker. run.sh proves --verify passes the first and
# fails the other two. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/emit-report.sh" ]; then
  EMIT="$D_ROOT/core/skills/ai-dlc-update/reconcile/emit-report.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/emit-report.sh" ]; then
  EMIT="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/emit-report.sh"
else
  echo "FIXTURE ERROR: emit-report.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-emit.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/schemas" "$CONSUMER/.claude/schemas"

printf '{\n  "rule": "original"\n}\n' > "$DIST/core/schemas/thing.json"

# THE SUBJECT OF run.sh's MOVED-REF ARMS, and it is shaped to reproduce the incident exactly.
#
# Those arms move a branch across a core change and require the region to change. That proves
# nothing unless the region's OTHER rows hold still — if the move also adds a bucket row, the
# arm fires on the bucket and would pass against a renderer carrying no content key at all.
# So this file is upstream-modified base->theirs ALREADY: its bucket row exists in the approved
# render, and a further edit to its CONTENT moves the `core/` tree while every row keyed on
# STATUS+path stays byte-identical. The consumer carries the BASE bytes at the installed path
# (`core/scripts/<x>` lands at `scripts/ai-dlc/<x>`), which keeps it out of CLASSIFY and so out
# of the orientation block, whose sample WOULD render its bytes.
#
# Measured while building this: with the file merely PRESENT at base and theirs unchanged, the
# harmful move added `UPSTREAM-MOD+consumer-deleted->CLASSIFY` plus three orientation lines, and
# the arm passed for the wrong reason. run.sh re-derives that hold-still property on every run
# rather than trusting this comment.
mkdir -p "$DIST/core/scripts" "$CONSUMER/scripts/ai-dlc"
printf '#!/usr/bin/env bash\necho MOVED-REF-PROBE base\n' > "$DIST/core/scripts/moved-ref-probe.sh"
cp "$DIST/core/scripts/moved-ref-probe.sh" "$CONSUMER/scripts/ai-dlc/moved-ref-probe.sh"

git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"
THEIRS="$BASE"

# Consumer edits the core schema IN PLACE → a HARD blocker the mechanical region must carry.
printf '{\n  "rule": "consumer-edited"\n}\n' > "$CONSUMER/.claude/schemas/thing.json"

# A BOTH-ADDED file: upstream and the consumer each added the same path independently, with
# DISTINGUISHABLE exclusive content on each side. This is the CLASSIFY shape whose resolution
# is prose, and prose is where OURS and THEIRS get swapped -- the sentinels below let run.sh
# assert the orientation block attributes each side's line to the correct side.
mkdir -p "$DIST/core/skills/ai-dlc/templates" "$CONSUMER/.claude/skills/ai-dlc/templates"
printf 'shared line\nSENTINEL-THEIRS-ONLY upstream process class\n' \
  > "$DIST/core/skills/ai-dlc/templates/classes.md"
# The moved-ref probe is upstream-modified in this same commit, so its bucket row is already in
# the APPROVED render and a later content move cannot add one. See the block above.
printf '#!/usr/bin/env bash\necho MOVED-REF-PROBE approved\n' > "$DIST/core/scripts/moved-ref-probe.sh"
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs-adds-template
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
printf 'shared line\nSENTINEL-OURS-ONLY consumer domain class\n' \
  > "$CONSUMER/.claude/skills/ai-dlc/templates/classes.md"

# A SYMBOLIC spelling of theirs, parked at the same commit the sha-spelled assertions use.
# `--verify` re-renders from whatever the caller passes, so a branch is the shape of theirs an
# operator actually types (`origin/main`, `main`, "upstream HEAD") and the shape whose RESOLUTION
# can change between the dry run that was approved and the apply that writes. run.sh moves this
# ref; nothing above reads it.
MOVEREF="fixture-moving-theirs"
git -C "$DIST" branch -f "$MOVEREF" "$THEIRS"

# A PUSH-CANDIDATE LEDGER. Without one, `ledger-reverify.sh` short-circuits on a missing file
# and the region's ledger section renders `none` — so every assertion about that section passes
# on an empty string, which is how two label defects and a dropped DETAIL field shipped. Set
# LEDGER_SEEDED=0 in the environment to omit it: run.sh uses that as its vacuity mutant, and its
# ledger assertions must go RED when the section is `none`, not quietly stay green.
#
# Two entries, both mechanical faults rather than manual declarations, because HAND-REVIEW is
# the one status whose detail the report deliberately does not carry:
#   - an unknown verb            -> NEEDS-REVIEW, detail `unresolved: …`
#   - theirs_lacks on a substring present at base AND theirs -> NEEDS-REVIEW, `vacuous predicate:`
# The first id carries a parenthetical AFTER the id and BEFORE the em dash, which is the shape
# that used to be clipped mid-word: the split leaves more than seventy characters, so the clip
# fired on text that was already correct. Copied from the reference consumer, where the real
# heading's pre-dash text is 105 characters.
if [ "${LEDGER_SEEDED:-1}" != "0" ]; then
  mkdir -p "$CONSUMER/_bmad-output/ai-dlc-update"
  cat > "$CONSUMER/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'LEDGER'
# Push-candidate ledger (fixture)

## PC-FIXTURE-EMIT-UNKNOWN-VERB (a parenthetical this long pushes the pre-dash text past seventy characters) — the verb is not one of the four

verify: theirs_maybe core/schemas/thing.json "rule"

## PC-FIXTURE-EMIT-VACUOUS — theirs_lacks a substring both refs already carry

verify: theirs_lacks core/schemas/thing.json "rule"
LEDGER
fi

# The driver's rendered region — ground truth.
REGION="$WORK/region.md"
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$REGION" 2>/dev/null

# GOOD: header + the region verbatim.
{ echo "# Reconcile report (fixture)"; echo; cat "$REGION"; } > "$WORK/report-good.md"
# MISSING: no region at all (the narrated-report bug).
{ echo "# Reconcile report (fixture)"; echo; echo "## Blocking-layer"; echo "None."; } > "$WORK/report-missing.md"
# STALE: the region, but with the HARD blocker line hand-deleted (LLM edited a rendered region).
{ echo "# Reconcile report (fixture)"; echo; grep -v 'HARD-UNREGISTERED-CORE-DRIFT' "$REGION"; } > "$WORK/report-stale.md"

cat > "$WORK/env.sh" <<ENV
EMIT="$EMIT"
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONSUMER="$CONSUMER"
MOVEREF="$MOVEREF"
MOVED_PROBE_PATH="core/scripts/moved-ref-probe.sh"
REGION="$REGION"
REPORT_GOOD="$WORK/report-good.md"
REPORT_MISSING="$WORK/report-missing.md"
REPORT_STALE="$WORK/report-stale.md"
ENV

printf '%s\n' "$WORK"
