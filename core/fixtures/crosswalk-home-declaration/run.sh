#!/usr/bin/env bash
# crosswalk-home-declaration — I69: prose naming where `consumer_crosswalk_file:` LIVES
#
# The mirror runs `validate-enforcement-map.sh --arms I69,I68` and the verdict is the
# count of I69 lines only (the mirror carries no .githooks/, VERSION or CHANGELOG, so the exit
# code says nothing). The cli-pass arm requires I69 zero times and the program to answer as the in-process entry does.
#
# THE DEFECT. The release that moved the crosswalk table to a consumer-owned path shipped
# four statements of where the declaration lives, and all four named `core-manifest.md`.
# The key has never been in that file — it is in `layer-contract.yaml`, and the contract's
# own header explains at length why it is there rather than in the manifest. One of the four
# was W8's remedy string: the single sentence an operator reads WHILE migrating their rows
# told them to open a file with no declaration in it. That is v0.225.0's `anchor_form` class
# one string over — a remedy whose instructions cannot be followed literally.
#
# WHY THE GRAMMAR IS A HOME CLAIM AND NOT A CO-OCCURRENCE, which is the whole of its
# false-positive set. Two paragraphs name `core-manifest.md` next to the token precisely to
# say the declaration is NOT there, with the measurement behind the choice. A rule keyed on
# proximity reports both, and a check that fires on the rationale for its own subject is one
# the operator turns off. Measured against the tree that carried the defect, the shipped
# grammar returns the four real sites and neither rationale paragraph.
#
# The validator runs in a mirror of `core/` and `scripts/` under a mktemp dir, never in place.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the invariant regressed, 2 = fixture broken.
set -uo pipefail

case "${1:-}" in "") : ;; *) echo "usage: run.sh" >&2; exit 2 ;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"       # .dist-only: this fixture is never installed, so there is one layout
VEM="$ROOT/scripts/validate-enforcement-map.sh"
[ -f "$VEM" ] || { echo "FIXTURE ERROR: cannot locate scripts/validate-enforcement-map.sh from $HERE" >&2; exit 2; }

echo "HERMETIC-CONSUMED scripts/validate-enforcement-map.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/crosswalk-home-decl.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

FX_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$FX_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$FX_LIB"
# fx_inproc counts each in-process vem_entry pass (BL-982); every pass runs in an xargs bash -c worker below.
export -f fx_inproc
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# 1 premise + 1 cli twin.
EXPECTED_ASSERTIONS=2
MIRROR_RUNS=1   # control

echo "crosswalk-home-declaration:"

README_REL='core/skills/ai-dlc/extensions/README.md'
TPL_REL='core/skills/ai-dlc/templates/crosswalk.md'

RUNS="$WORK/runs"; : > "$RUNS"
OUTD="$WORK/out";  mkdir -p "$OUTD"

# reg <label> <expected I69 count>
reg() { printf '%s\t%s\n' "$1" "$2" >> "$RUNS"; }

# ---------------------------------------------------------------------------
# premise — the shipped tree states the home somewhere, or every mutant below is
# rewriting text that is not there and the control's zero means nothing
#
# Evaluated HERE rather than in the pool: it reads the live tree with two greps, costs
# nothing, and its verdict is a precondition for reading every count the pool produces.
# ---------------------------------------------------------------------------
CLAIMS=$(grep -c 'declares as `consumer_crosswalk_file' "$ROOT/$README_REL" "$ROOT/core/skills/ai-dlc/layer-contract.yaml" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$CLAIMS" -ge 2 ]; then
  ok "premise: core states the declaration's home in $CLAIMS place(s) — there is a claim to get wrong"
else
  bad "premise: found $CLAIMS home claim(s) in the shipped tree, expected at least 2. Every mutant below would rewrite absent text and the cmp -s guard would report it, but the CONTROL's zero would read as clean."
fi

# ---------------------------------------------------------------------------
# the control — an unmutated mirror is SILENT on I69
# ---------------------------------------------------------------------------
reg control 0

# ==================== PHASE 2: mirror and count, in a pool ====================
# The zero guard: a registration grammar that stopped filling yields an empty list, and an
# empty list passes every assertion it never made.
N_RUNS="$(grep -c . "$RUNS" || true)"
if [ "$N_RUNS" -ne "$MIRROR_RUNS" ]; then
  echo "FIXTURE ERROR: registered $N_RUNS run(s) for $MIRROR_RUNS mirror-backed assertion(s) — the registry did not fill, so nothing below is evidence" >&2
  exit 2
fi

# FIVE, and fixed rather than tunable for the reason the sibling pools state in place: this
# pool nests inside the pre-push suite's own, so a knob here multiplies against the knob
# there and the PRODUCT is what lands on the machine. Five is the run count; a wider pool
# than there is work is pure contention for the sibling fixtures.
#
# I69 LINES ONLY, never the exit code. The mirror carries no .githooks/, VERSION or CHANGELOG,
# so several unrelated invariants fail in it and the exit status says nothing about this one.
# Keying on the count of I69 findings is what makes each verdict attributable to the arm under
# test — and M4, the knock-out, is what proves the count comes from I69 rather than from the
# run having died before reaching it.
# READSET_POOL_WIDTH narrows this pool when derive-fixture-readsets.sh traces the fixture (its nest launch sets 1):
# at full width the sweeps outrun `log stream` and the trace is discarded. It changes the schedule, not the work.
CHD_JOBS="${READSET_POOL_WIDTH:-5}"
case "$CHD_JOBS" in ''|*[!0-9]*|????*) echo "FIXTURE BROKEN: READSET_POOL_WIDTH='$CHD_JOBS' is not an integer from 1 to 64" >&2; exit 2 ;; esac
{ [ "$CHD_JOBS" -ge 1 ] && [ "$CHD_JOBS" -le 64 ]; } || { echo "FIXTURE BROKEN: READSET_POOL_WIDTH='$CHD_JOBS' is not an integer from 1 to 64" >&2; exit 2; }
CHD_ROOT="$ROOT" CHD_WORK="$WORK" CHD_OUT="$OUTD" \
  xargs -P "$CHD_JOBS" -I{} bash -c '
    l="$1"
    m="$CHD_WORK/mirror-$l"
    mkdir -p "$m" || { printf MIRRORFAIL > "$CHD_OUT/$l.state"; printf done > "$CHD_OUT/$l.done"; exit 0; }
    cp -R "$CHD_ROOT/core" "$CHD_ROOT/scripts" "$m/" || { printf MIRRORFAIL > "$CHD_OUT/$l.state"; printf done > "$CHD_OUT/$l.done"; exit 0; }
    if [ ! -f "$CHD_OUT/$l.state" ]; then
      _arms="--arms I69,I68"
      printf %s "$_arms" > "$CHD_OUT/$l.arms"
      # IN-PROCESS: the mirror validator is sourced ONCE by absolute path and run as a vem_entry subshell.
      # The cli cell (cells.decl) starts it as a program on the control (a pass) and must answer byte for
      # byte as the in-process run did.
      . "$m/scripts/validate-enforcement-map.sh"
      fx_inproc "$m/scripts/validate-enforcement-map.sh"
      ( vem_entry $_arms ) > "$CHD_OUT/$l.so" 2> "$CHD_OUT/$l.se"
      irc=$?
      cat "$CHD_OUT/$l.so" "$CHD_OUT/$l.se" > "$CHD_OUT/$l.full"
      grep -c "I69" "$CHD_OUT/$l.full" > "$CHD_OUT/$l.n" || true
      FXCELL=cli-pass bash "$m/scripts/validate-enforcement-map.sh" $_arms > "$CHD_OUT/$l.cso" 2> "$CHD_OUT/$l.cse"
      crc=$?
      if cmp -s "$CHD_OUT/$l.so" "$CHD_OUT/$l.cso" && cmp -s "$CHD_OUT/$l.se" "$CHD_OUT/$l.cse" && [ "$irc" = "$crc" ]; then
        printf same > "$CHD_OUT/$l.twin"
      else
        printf "DIFF rc=%s/%s" "$irc" "$crc" > "$CHD_OUT/$l.twin"
      fi
    fi
    printf done > "$CHD_OUT/$l.done"
    rm -rf "$m"
  ' _ {} < <(cut -f1 "$RUNS")

# ================= PHASE 3: evaluate, serially, in DECLARATION order =================
while IFS=$'\t' read -r label want; do
  [ -n "$label" ] || continue

  # A MISSING VERDICT IS A FAILURE, not a gap. `.done` is written after the run, so its
  # absence means the pool dropped the job — which otherwise contributes exactly what a
  # passing arm contributes: nothing.
  if [ ! -f "$OUTD/$label.done" ]; then
    bad "$label produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one"
    continue
  fi

  if [ -f "$OUTD/$label.state" ] && [ "$(cat "$OUTD/$label.state")" = MIRRORFAIL ]; then
    echo "FIXTURE ERROR: mirror failed" >&2; exit 2
  fi
done < "$RUNS"

# THE CLI TWIN (cells.decl): the program answers the control mirror (a pass) exactly as the
# in-process entry did, on stdout, stderr and exit. The twin file is written by the worker only when both
# sides were run, so an absent one reads as a failure and never as agreement.
_ci="$(grep -c I69 <<<"$(cat "$OUTD/control.cso" "$OUTD/control.cse" 2>/dev/null)")" || _ci=0
if [ "$(cat "$OUTD/control.twin" 2>/dev/null)" = same ] && [ "$_ci" -eq 0 ]; then
  ok "cli-pass: the program answers the control mirror exactly as the in-process entry does (stdout, stderr, exit)"
else
  bad "cli-pass: the program differs from the in-process entry on the control mirror ($(cat "$OUTD/control.twin" 2>/dev/null))"
fi

# ---------------------------------------------------------------------------
echo
report_end crosswalk-home-declaration "$EXPECTED_ASSERTIONS"
