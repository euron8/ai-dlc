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
mkdir -p "$DIST/core/schemas" "$DIST/core/skills/ai-dlc/steps" \
         "$CONSUMER/.claude/schemas" "$CONSUMER/.claude/skills/ai-dlc/steps"

# THE WRONG-BASE ARTEFACT IS A NON-MACHINERY SCANNED FILE, AND THAT IS LOAD-BEARING.
# It used to be `schemas/moved.json`, and `core/schemas/*.json` is a `machinery:` glob — so once
# `unregistered-drift.sh` learned CORE-MACHINERY-CARRIED, preclassify bucketed this file
# `BOTH-CHANGED->CLASSIFY` against the pull's base, arm C would carry it, and the scan correctly
# stopped calling it drift. `hard-blockers.sh` lists only `HARD-` rows, so the pre side of
# assertion 2c no longer named it and the arm lost its subject to a RIGHT change. `steps/*.md` is
# in the scan set and in no machinery glob, which is what the reference consumer's own case was.
# The machinery half is not deleted: it is asserted in its own right by assertion 2d.
MOVED_REL="skills/ai-dlc/steps/moved.md"
MACH_REL="schemas/moved.json"

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
printf '# Moved step\n\nowner: {project_name}\npad line one, unchanged across the range.\npad line two, unchanged across the range.\nrule: base-text\n' > "$DIST/core/$MOVED_REL"
# ...and the SAME shape on a MACHINERY path, kept as its own case rather than deleted. Assertion
# 2d asserts the precedence directly: pre-apply this one reads CORE-MACHINERY-CARRIED (non-HARD,
# so absent from the blocking list) while the file above still reads HARD in the same run.
printf '{\n  "who": "{project_name}",\n  "pad": "unchanged",\n  "pad2": "unchanged",\n  "rule": "base-text"\n}\n' > "$DIST/core/$MACH_REL"
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

printf '# Moved step\n\nowner: {project_name}\npad line one, unchanged across the range.\npad line two, unchanged across the range.\nrule: theirs-text\n' > "$DIST/core/$MOVED_REL"
printf '{\n  "who": "{project_name}",\n  "pad": "unchanged",\n  "pad2": "unchanged",\n  "rule": "theirs-text"\n}\n' > "$DIST/core/$MACH_REL"
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS_ADV="$(git -C "$DIST" rev-parse HEAD)"

# THE SEED'S OWN PRECONDITION: the wrong-base artefact must be OUTSIDE every machinery glob and
# the second artefact must be INSIDE one. Asserted by eval'ing the shipping `machinery_paths()`
# rather than by reading the manifest, because that function is what arm C and the scan both use,
# and a manifest read is a second implementation of its glob dialect.
#
# THE CONTROL IS THE POINT. `machinery_paths()` resolves its manifest as
# `$(dirname "$0")/setup-sites.md`, so a probe run from anywhere else resolves an EMPTY set and
# every membership question answers 0 — including the ones that must answer non-zero. Measured
# exactly that way while writing this: the negative read 0 beside a control that also read 0.
# The probe is therefore written INTO the reconcile directory and the non-empty control is
# checked before either membership answer is believed.
_msd="$(dirname "$HB")"
_mprobe="$WORK/machinery-probe.sh"
cat > "$_mprobe" <<'MPROBE'
set -uo pipefail
eval "$(awk '/^machinery_paths\(\) \{/,/^\}/' "$(dirname "$0")/preclassify.sh" 2>/dev/null)"
command -v machinery_paths >/dev/null 2>&1 || exit 2
machinery_paths
MPROBE
cp "$_mprobe" "$_msd/.rbl-machinery-probe.sh"
_mset="$(DIST="$DIST" BASE="$BASE" THEIRS="$THEIRS_ADV" bash "$_msd/.rbl-machinery-probe.sh" 2>/dev/null)"
rm -f "$_msd/.rbl-machinery-probe.sh"
_mn="$(printf '%s\n' "$_mset" | grep -c .)" || _mn=0
_min="$(printf '%s\n' "$_mset" | grep -cxF "core/$MACH_REL")" || _min=0
_mout="$(printf '%s\n' "$_mset" | grep -cxF "core/$MOVED_REL")" || _mout=0
if [ "$_mn" -eq 0 ] || [ "$_min" -eq 0 ]; then
  echo "seed.sh: FIXTURE BROKEN — the machinery set resolved $_mn entries and core/$MACH_REL is in it $_min time(s)." >&2
  echo "  Both must be non-zero before the negative below means anything; a probe that cannot resolve" >&2
  echo "  setup-sites.md answers 0 for EVERY path, which reads exactly like the answer this seed wants." >&2
  exit 2
fi
if [ "$_mout" -ne 0 ]; then
  echo "seed.sh: FIXTURE BROKEN — core/$MOVED_REL is now INSIDE a machinery glob, so the scan will" >&2
  echo "  report it CORE-MACHINERY-CARRIED (non-HARD) and assertion 2c's pre side loses its subject." >&2
  echo "  Move the wrong-base artefact to a scanned path outside every machinery: glob." >&2
  exit 2
fi

# Consumer edits the core schema IN PLACE → unregistered-drift emits HARD-UNREGISTERED-CORE-DRIFT.
printf '{\n  "rule": "consumer-edited-in-place"\n}\n' > "$CONSUMER/.claude/$DRIFT_REL"
# ...and carries THEIRS' text for the template apply just wrote, with the token substituted as the
# installer leaves it. Untouched by the consumer; the only thing that makes it look drifted is
# asking the question against the wrong base.
printf '# Moved step\n\nowner: acme\npad line one, unchanged across the range.\npad line two, unchanged across the range.\nrule: theirs-text\n' > "$CONSUMER/.claude/$MOVED_REL"
# The machinery twin, same shape, same substitution. Assertion 2d's subject.
printf '{\n  "who": "acme",\n  "pad": "unchanged",\n  "pad2": "unchanged",\n  "rule": "theirs-text"\n}\n' > "$CONSUMER/.claude/$MACH_REL"

# The BAD report — the bug: it never names the drifted file.
cat > "$WORK/report-bad.md" <<'BAD'
# Reconcile report (fixture)
## Blocking-layer list
None — no unregistered core drift.
BAD

# The GOOD report — it names EVERY blocker's path. At the base==theirs pair the assertions below
# use, BOTH template files are blockers too: nothing has told the detector that their non-token
# line moved upstream, because at that pair it did not — and at that pair the range is empty, so
# no bucket is emitted and the machinery twin is not carried either.
cat > "$WORK/report-good.md" <<GOOD
# Reconcile report (fixture)
## Blocking-layer list
- HARD-UNREGISTERED-CORE-DRIFT  $DRIFT_REL — resolve before apply.
- HARD-UNREGISTERED-CORE-DRIFT  $MOVED_REL — resolve before apply.
- HARD-UNREGISTERED-CORE-DRIFT  $MACH_REL — resolve before apply.
GOOD

cat > "$WORK/env.sh" <<ENV
HB="$HB"
DIST="$DIST"
BASE="$BASE"
THEIRS="$BASE"
CONSUMER="$CONSUMER"
DRIFT_REL="$DRIFT_REL"
MOVED_REL="$MOVED_REL"
MACH_REL="$MACH_REL"
THEIRS_ADV="$THEIRS_ADV"
REPORT_BAD="$WORK/report-bad.md"
REPORT_GOOD="$WORK/report-good.md"
ENV

printf '%s\n' "$WORK"
