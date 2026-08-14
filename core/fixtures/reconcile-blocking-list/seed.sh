#!/usr/bin/env bash
# reconcile-blocking-list/seed.sh — a consumer with a real in-place core drift, plus two candidate
# reports: one that OMITS the blocker (the bug) and one that names it. run.sh drives the real
# hard-blockers.sh to prove it renders the blocker and its --check catches a report that dropped it.
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/hard-blockers.sh" ]; then
  HB="$D_ROOT/core/skills/ai-dlc-update/reconcile/hard-blockers.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/hard-blockers.sh" ]; then
  HB="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/hard-blockers.sh"
else
  echo "FIXTURE ERROR: hard-blockers.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-blocking.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
DRIFT_REL="schemas/thing.json"
mkdir -p "$DIST/core/schemas" "$CONSUMER/.claude/schemas"

MOVED_REL="schemas/moved.json"

printf '{\n  "rule": "original"\n}\n' > "$DIST/core/$DRIFT_REL"
# A SECOND core file, and it is a TEMPLATE — it carries a `{token}` the installer substitutes.
# That is what makes it able to express the defect at all. A file the consumer holds byte-identical
# to theirs is already caught by `CORE-AT-THEIRS`, which unregistered-drift.sh added for the
# wrong-base mistake and which fires whatever base was passed. A substituted file is NOT
# byte-identical to theirs, so it falls past that guard and is classified by `is_unregistered`,
# which diffs against BASE. Upstream also changes a NON-token line across the range, so:
#   against the pull's base  two hunks differ, one of them not a token site -> HARD drift
#   against theirs           only the token site differs -> CORE-TEMPLATE-SUBSTITUTED
# The consumer edited nothing either way. This is the shape the reference consumer reported on
# `steps/deploy-validate.md`, twice, on two consecutive pulls.
printf '{\n  "who": "{project_name}",\n  "pad": "unchanged",\n  "pad2": "unchanged",\n  "rule": "base-text"\n}\n' > "$DIST/core/$MOVED_REL"
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

printf '{\n  "who": "{project_name}",\n  "pad": "unchanged",\n  "pad2": "unchanged",\n  "rule": "theirs-text"\n}\n' > "$DIST/core/$MOVED_REL"
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS_ADV="$(git -C "$DIST" rev-parse HEAD)"

# Consumer edits the core schema IN PLACE → unregistered-drift emits HARD-UNREGISTERED-CORE-DRIFT.
printf '{\n  "rule": "consumer-edited-in-place"\n}\n' > "$CONSUMER/.claude/$DRIFT_REL"
# ...and carries THEIRS' text for the template apply just wrote, with the token substituted as the
# installer leaves it. Untouched by the consumer; the only thing that makes it look drifted is
# asking the question against the wrong base.
printf '{\n  "who": "acme",\n  "pad": "unchanged",\n  "pad2": "unchanged",\n  "rule": "theirs-text"\n}\n' > "$CONSUMER/.claude/$MOVED_REL"

# The BAD report — the bug: it never names the drifted file.
cat > "$WORK/report-bad.md" <<'BAD'
# Reconcile report (fixture)
## Blocking-layer list
None — no unregistered core drift.
BAD

# The GOOD report — it names EVERY blocker's path. At the base==theirs pair the assertions below
# use, the template file is a blocker too: nothing has told the detector that its non-token line
# moved upstream, because at that pair it did not.
cat > "$WORK/report-good.md" <<GOOD
# Reconcile report (fixture)
## Blocking-layer list
- HARD-UNREGISTERED-CORE-DRIFT  $DRIFT_REL — resolve before apply.
- HARD-UNREGISTERED-CORE-DRIFT  $MOVED_REL — resolve before apply.
GOOD

cat > "$WORK/env.sh" <<ENV
HB="$HB"
DIST="$DIST"
BASE="$BASE"
THEIRS="$BASE"
CONSUMER="$CONSUMER"
DRIFT_REL="$DRIFT_REL"
MOVED_REL="$MOVED_REL"
THEIRS_ADV="$THEIRS_ADV"
REPORT_BAD="$WORK/report-bad.md"
REPORT_GOOD="$WORK/report-good.md"
ENV

printf '%s\n' "$WORK"
