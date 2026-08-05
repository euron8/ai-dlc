#!/usr/bin/env bash
# self-update-fixtures.sh — run step 2's derived covering fixtures AND persist their
# output, so a red self-update leaves evidence behind instead of a discarded branch.
#
# WHY THIS EXISTS. Step 2's cycle cuts a branch, writes the machinery slice, runs the
# derived fixtures, and ON RED discards the branch and restores the tree — writing
# nothing. `reconcile-log-<ts>.md` is step-7 only; `reconcile-report.md` is not written
# until step 5, by which time the tree state the fixtures ran against is gone. So the
# one cycle in this skill that runs a TEST SUITE was the only one that persisted no
# record of it: the failing output survived in the operating agent's context and
# nowhere else, and no command in the report reproduced the state that produced it.
#
# MEASURED ON THE REFERENCE CONSUMER, TWICE. On the `0.249.0 -> 0.262.0` run the
# evidence had to be recovered afterwards by re-staging the discarded slice on a second
# throwaway branch. On `0.249.0 -> 0.263.0` the operator captured it by hand from inside
# the cycle — which is not something the skill instructs, and is therefore not something
# the next operator will do. Both runs turned on ONE fixture's output; without it the
# only available conclusion was "the self-update failed".
#
# SO THE FIX IS A CARRIER, NOT A SENTENCE. Step 2 previously said "report the fixture
# name and its output", and that instruction was obeyed by an agent that then discarded
# the tree. A prose duty with no artifact behind it is the class this repo keeps
# re-learning: prefer a mechanism the step INVOKES over a rule it must remember.
#
# Usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...
#   dist-repo      path to the distribution git checkout (recorded in the header only)
#   base-sha       the `commit` field from the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref
#   consumer-root  the consumer project root (contains .claude/)
#   fixture...     the derived covering fixture DIRECTORY NAMES, as step 2 derived them
#
# The fixture set is passed IN rather than re-derived here. Step 2 greps it from the
# fixtures themselves, and a second derivation in this file would be two derivations to
# keep in agreement — the exact drift `lib.sh` exists to end for the section resolver.
#
# Output: a per-fixture verdict line on stdout, then the log path.
# Exit:   0 all green · 1 at least one red · 2 the harness could not run
#         (no fixtures named, fixture root underivable, log unwritable). A run that
#         could not happen must NOT exit 0: "no failures" and "no assertions" are the
#         same byte to the caller, and this whole file exists because that difference
#         was invisible once already.
set -u

DIST="${1:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
BASE="${2:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
THEIRS="${3:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
CONSUMER="${4:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
shift 4

# Absolutized for the same reason layer-drift.sh absolutizes it: readers here run with a
# changed working directory, and a relative root would resolve against whichever one is
# current at the time.
CONSUMER="$(cd "$CONSUMER" 2>/dev/null && pwd)" || {
  echo "self-update-fixtures: consumer-root not a directory: ${4}" >&2; exit 2; }

if [ $# -eq 0 ]; then
  echo "self-update-fixtures: no fixtures named — refusing to report a green run over an empty set." >&2
  echo "  pass the derived covering fixture directory names as arguments." >&2
  exit 2
fi

SELF="$(cd "$(dirname "$0")" && pwd)"

# The consumer's fixture root, DERIVED from the mapper rather than written here — the
# same probe `retired-fixtures.sh` uses, and for the same reason: `install.sh` splits
# what shares a parent in `core/`, and I33 fails the build on anything that reaches one
# core path by walking up from another.
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)"
if ! command -v map_consumer >/dev/null 2>&1; then
  echo "self-update-fixtures: could not load map_consumer() from preclassify.sh — refusing to" >&2
  echo "  fall back to a private path table, which would answer for one layout and be silently" >&2
  echo "  wrong in the other." >&2
  exit 2
fi
fx_rel="$(map_consumer "core/fixtures/__probe__/run.sh")"
FX_ROOT="${fx_rel%/__probe__/run.sh}"
if [ "$FX_ROOT" = "$fx_rel" ] || [ -z "$FX_ROOT" ]; then
  echo "self-update-fixtures: map_consumer() did not map a core fixture path to a consumer one," >&2
  echo "  so the consumer's fixture root could not be derived. Nothing was run." >&2
  exit 2
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$CONSUMER/_bmad-output/ai-dlc-update"
# `.md`, DELIBERATELY. A reference consumer's .gitignore carries `*.log` and `*.txt`, so
# either extension would produce an artifact that exists on disk and vanishes from every
# `git status` the operator reads afterwards.
LOG="$OUT_DIR/self-update-fixtures-${TS}.md"
mkdir -p "$OUT_DIR" 2>/dev/null || { echo "self-update-fixtures: cannot create $OUT_DIR" >&2; exit 2; }
: > "$LOG" 2>/dev/null || { echo "self-update-fixtures: cannot write $LOG" >&2; exit 2; }

{
  echo "# ai-dlc-update step-2 self-update — derived fixture run"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# base $BASE -> theirs $THEIRS"
  echo "# consumer: $CONSUMER   dist: $DIST"
  echo "# fixture root: $FX_ROOT   fixtures named: $#"
  echo "# The tree this ran against is the machinery slice, and step 2 DISCARDS it on red."
  echo "# Nothing below is reproducible from the tree once that has happened."
  echo ""
} >> "$LOG"

n_run=0; n_ok=0; n_fail=0; n_missing=0; reds=""
for name in "$@"; do
  dir="$CONSUMER/$FX_ROOT/$name"
  {
    echo "===== FIXTURE $name ====="
  } >> "$LOG"
  if [ ! -f "$dir/run.sh" ]; then
    # A named fixture with no driver is NOT a pass. It means the slice did not write what
    # the derivation said it would, which is a finding about the cycle rather than about
    # the fixture.
    n_missing=$((n_missing + 1)); reds="$reds $name"
    echo "self-update-fixtures: MISSING $FX_ROOT/$name/run.sh" >&2
    { echo "MISSING: $FX_ROOT/$name/run.sh — the slice did not write this fixture's driver."
      echo "----- rc=missing -----"; echo ""; } >> "$LOG"
    printf '   MISS  %s\n' "$name"
    continue
  fi
  # cwd is the CONSUMER ROOT, because that is where both pre-push hooks run a fixture
  # from (`bash "$d/run.sh"` with the repo root current). A fixture whose verdict depends
  # on the caller's directory has been shipped before — see v0.263.0 — so the runner that
  # decides a self-update must stand exactly where the gate that decides a push stands.
  ( cd "$CONSUMER" && bash "$FX_ROOT/$name/run.sh" ) >> "$LOG" 2>&1
  rc=$?
  { echo "----- rc=$rc -----"; echo ""; } >> "$LOG"
  n_run=$((n_run + 1))
  if [ "$rc" -eq 0 ]; then
    n_ok=$((n_ok + 1)); printf '   ok    %s\n' "$name"
  else
    n_fail=$((n_fail + 1)); reds="$reds $name"; printf '   FAIL  %s\n' "$name"
  fi
done

{
  echo "# summary: $n_ok green, $n_fail red, $n_missing missing, of $# named"
  [ -n "$reds" ] && echo "# red:${reds}"
} >> "$LOG"

echo ""
echo "self-update fixtures: $n_ok green, $n_fail red, $n_missing missing, of $# named"
echo "log: $LOG"

# The completeness assertion, and it is not decoration: a loop that silently skipped a
# fixture would otherwise report every fixture it DID run as green and exit 0.
if [ $((n_run + n_missing)) -ne $# ]; then
  echo "self-update-fixtures: ran $n_run + $n_missing missing, but $# were named — the loop did not reach every fixture." >&2
  exit 2
fi

[ "$n_fail" -eq 0 ] && [ "$n_missing" -eq 0 ]
