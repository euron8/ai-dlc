#!/usr/bin/env bash
# gate-series-rung — the SERIES arms of validate-gate-adjudication.sh --series.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = an arm regressed, 2 = fixture broken.
#
# Sibling of `gate-repair-record`, which covers the repair-record arm of the same mode. This
# one covers the other four: series_stall_run, series_boundary_run, series_nonce_sortable,
# and the legacy posture. Together they are the mode's fixture surface; neither duplicates
# the other's subject.
#
# THE DEFECT THIS EXISTS TO CATCH. The reference consumer ran ONE [story] gate for eleven
# adjudication passes with the same check failing the last seven, while the failure protocol
# already said "if still failing after remediation, escalate as HARD_BLOCK per Rule 12".
# Nothing counted, so nothing escalated. The loop was not unbounded by design — it was
# unbounded because no artifact carried the SERIES, so no run was expressible.
#
# WHY EVERY CASE COMES IN A PAIR. Each pair differs in exactly one variable and the fixture
# asserts that identity BEFORE it asserts any verdict. Three of the four arms here were
# written to catch a defeat that leaves the verdict values untouched — a re-sorted nonce, a
# series split in half, a deleted series id — so a fixture that let a second difference in
# would be proving something else and reading exactly like the property it claims. That is
# this repo's recurring defect, and it has already been reproduced once inside a test written
# to catch it.
#
# ASSERT ON THE MESSAGE, NEVER THE EXIT CODE ALONE. A validator with no series arms at all
# exits 0 everywhere; one whose stall rung fires on everything exits 1 everywhere. An
# exit-code-only fixture scores the first as a pass on every silent case and the second as a
# pass on every firing case.
set -u
# Scrub ambient AI_DLC_* — the validator reads AI_DLC_VERDICT_SCHEMA and AI_DLC_STATE_DIR,
# and a consumer that tunes either in settings.json would otherwise fail this against
# correct code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-gate-adjudication.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-gate-adjudication.sh" \
  "$DIR/../../core/scripts/validate-gate-adjudication.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
[ -n "$VALIDATOR" ] || { echo "FIXTURE BROKEN: cannot locate validate-gate-adjudication.sh from $DIR"; exit 2; }

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "FIXTURE BROKEN: seed.sh produced no root"; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

ASSERTIONS=0
FAILURES=0
note_fail() { echo "FAIL: $*"; FAILURES=$((FAILURES + 1)); }
gd() { printf '%s/%s/_bmad-output/gate-adjudication' "$ROOT" "$1"; }

# Run a case; set RC and OUT.
run_case() { OUT="$(bash "$VALIDATOR" --series "$(gd "$1")" 2>&1)"; RC=$?; }

# expect <case> <rc> <marker|-> <human name>
expect() {
  ASSERTIONS=$((ASSERTIONS + 1))
  run_case "$1"
  if [ "$RC" -ne "$2" ]; then
    note_fail "$1 exited $RC, expected $2. $4
  validator said: $(head -3 <<<"$OUT")"
    return
  fi
  if [ "$3" != "-" ] && ! grep -q "$3" <<<"$OUT"; then
    note_fail "$1 exited $2 as expected but did NOT carry '$3'. The right exit for the wrong
  reason is the failure this fixture is shaped to refuse. $4
  validator said: $(head -3 <<<"$OUT")"
  fi
}

# --------------------------------------------------------------------------
# 0. THE SEEDS. Every differential claim, checked before it is relied on.
# --------------------------------------------------------------------------
payloads() {
  python3 - "$1" <<'PY'
import json, os, sys
d = sys.argv[1]
out = []
for f in sorted(os.listdir(d)):
    if f.endswith(".json"):
        out.append(json.dumps(json.load(open(os.path.join(d, f)))["verdicts"], sort_keys=True))
print("\n".join(sorted(out)))
PY
}

ASSERTIONS=$((ASSERTIONS + 1))
if ! diff -q <(payloads "$(gd split-joined)") <(payloads "$(gd split-defeat)") >/dev/null; then
  note_fail "split-joined and split-defeat do NOT carry byte-identical verdict payloads.
  The entire claim of that pair is that gate_series_id is the ONLY difference; with a second
  one present, a validator could separate them by reading the verdicts and the boundary arm
  would score as held without existing."
fi

ASSERTIONS=$((ASSERTIONS + 1))
if ! diff -q <(payloads "$(gd nonce-sortable)") <(payloads "$(gd nonce-unsortable)") >/dev/null; then
  note_fail "nonce-sortable and nonce-unsortable do NOT carry byte-identical verdict payloads.
  That pair asserts the NONCE alone re-sequences the run; a verdict-value difference would
  prove the ordinary stall rung instead."
fi

# The intended difference must actually be present, or a pair is one case twice.
ASSERTIONS=$((ASSERTIONS + 1))
n_sids="$(python3 -c '
import json,glob,sys
print(len({json.load(open(f))["gate_series_id"] for f in glob.glob(sys.argv[1]+"/*.json")}))' "$(gd split-defeat)")"
[ "$n_sids" = "2" ] || note_fail "split-defeat carries $n_sids distinct gate_series_id(s); expected 2.
  The independent variable is not set, so it is split-joined twice."

# K IS PINNED HERE. If K changes, this assertion tells you, instead of the silent cases
# quietly going red and being blamed on whatever else changed.
ASSERTIONS=$((ASSERTIONS + 1))
run_case stall-fires
if ! grep -q 'across 3 consecutive passes' <<<"$OUT"; then
  note_fail "the stall rung did not report a threshold of 3. This fixture's silent cases are
  built one short of K=3; a different K makes them meaningless rather than wrong, so the
  threshold is asserted here explicitly."
fi

# --------------------------------------------------------------------------
# 1. series_stall_run
# --------------------------------------------------------------------------
expect stall-fires 1 'STALLED' \
  "Check 7 holds FAIL across three consecutive passes. This is the eleven-pass cascade in
  miniature; a rung that cannot see it is the state the consumer shipped in."
expect stall-silent 0 '-' \
  "No check reaches three consecutive FAILs here. A rung that fires anyway blocks a loop
  that is converging, and gets switched off."

# --------------------------------------------------------------------------
# 2. series_boundary_run — a reset must not launder a live stall
# --------------------------------------------------------------------------
expect split-joined 1 'STALLED' \
  "Four consecutive FAILs under ONE series id: the ordinary rung owns this one."
expect split-defeat 1 'SPLIT SERIES' \
  "The same four FAILs with the series id changed midway. Neither half reaches K, so the
  ordinary rung is silent by construction and only the boundary arm can see it. If this
  case reports STALLED instead, the arms are entangled and one of them is vacuous."
expect split-honest-reset 0 '-' \
  "The same boundary, but the reset CLEARED the stall. Firing here would make the arm mean
  'series boundaries are illegal', which contradicts the reset semantics — minting a new id
  restarts the pass count — that the arm is supposed to leave intact."

# --------------------------------------------------------------------------
# 3. series_nonce_sortable — the nonce is the SORT KEY, not just a freshness anchor
# --------------------------------------------------------------------------
expect nonce-sortable 1 'STALLED' \
  "PASS then four FAILs: a run of 4, seen because the nonces sort chronologically."
expect nonce-unsortable 1 'does not match the required' \
  "The same five verdicts with the PASS re-nonced to '<timestamp>-arch' — the shape of the
  one non-conforming file in the reference corpus. It sorts into the middle and splits the
  run 2+2. Before this arm existed the mode returned exit 0 here: a silent skip path is a
  defeat anyone can produce by accident, and it reads exactly like a clean gate."

# --------------------------------------------------------------------------
# 4. the legacy posture — the mode's ONLY fail-open, and its boundary
# --------------------------------------------------------------------------
expect legacy-retained 0 'counted, not grouped' \
  "A prior series retained on disk after a reset — nothing is ever deleted — sorts strictly
  before the live series. It must be counted and NAMED, not silently dropped, and it must
  not block: failing closed here kills the mode at the first scan after any reset, which is
  exactly when it is meant to run."
expect legacy-interleaved 1 'falls at or after' \
  "The same legacy file moved INSIDE the live series' span. That is not a retained series,
  it is a live pass with its gate_series_id deleted — one field, and the run gets shorter.
  If the fail-open covered this case, the mechanism would ship its own opt-out."

# --------------------------------------------------------------------------
echo
if [ "$FAILURES" -eq 0 ]; then
  echo "ok: gate-series-rung — $ASSERTIONS assertion(s); the stall rung, the boundary arm,"
  echo "    the nonce sort key and both halves of the legacy posture each fire and each stay"
  echo "    silent on the case that must not fire."
  exit 0
fi
echo "FAILED: gate-series-rung — $FAILURES of $ASSERTIONS assertion(s)" >&2
exit 1
