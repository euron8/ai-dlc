#!/usr/bin/env bash
# crosswalk-home-declaration — I69: prose naming where `consumer_crosswalk_file:` LIVES
#
# MUTANT-MATRIX m1 decides=I69 twins=I68
# MUTANT-MATRIX m2 decides=I69 twins=I68
# MUTANT-MATRIX m3 decides=I69 twins=I68
# MUTANT-MATRIX-CONTROL m4 why=the knock-out disables I69's own err line, so the I69 count is 0 and no other layer refuses the violating tree, and survival is the pass
# MUTANT-MATRIX-REMEASURE bash core/fixtures/crosswalk-home-declaration/run.sh --matrix
#
# Per push each mirror runs `validate-enforcement-map.sh --arms I69` and the verdict is the
# count of I69 lines only (the mirror carries no .githooks/, VERSION or CHANGELOG, so the exit
# code says nothing). m4 is the knock-out: I69's own err line disabled, count 0. `--matrix` runs
# every mirror through the WHOLE validator and prints one MATRIX row per world naming every arm
# that reported FAIL; the control row is the baseline. The matrix is re-measured whenever an arm
# or a mutant is added or changed. Measured (control subtracted): every mutant adds exactly I69
# and nothing else, so I68 is green for each. The per-push run also selects I68 and fails any
# mutant world on which it reports.
# must name a file that carries it.
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
# WHY THIS FIXTURE MIRRORS RATHER THAN MUTATES IN PLACE. Its subjects — `extensions/README.md`
# and the scaffold template — are read by `layer-crosswalk-home` and by I68 in the same suite,
# and the suite runs 16-way. An in-place mutation with a restoring trap is the established
# idiom in `enforcement-map-sites`, and under a pool it is a cross-talk failure waiting for a
# scheduler: a sibling reading core's README mid-mutation sees bytes no commit ever had.
# `core/` and `scripts/` copy in under a tenth of a second, so the isolated form is also the
# cheap one.
#
# THAT ISOLATION IS ALSO WHY THE ARMS CAN RUN AT ONCE, and they now do. Each arm already
# built its own mirror and shared nothing with any other; the serial ordering was only ever
# the cheapest way to write them down. Five runs of a ~8.5s validator cost 40s standalone and
# ~159s inside the 16-way pre-push suite, and that suite is POLE-BOUND — its makespan tracks
# its single longest unit, measured 268s against a 268s wall clock — so an internally-serial
# fixture sets the wall clock for the whole push whatever AI_DLC_FIXTURE_JOBS says.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the invariant regressed, 2 = fixture broken.
set -uo pipefail

# MATRIX MODE: `bash core/fixtures/crosswalk-home-declaration/run.sh --matrix` runs every mirror
# through the WHOLE validator (no --arms) and prints one `MATRIX` row per world naming every arm
# id that reported FAIL. The mirror carries no .githooks/, VERSION or CHANGELOG, so the control
# row is the baseline and a mutant's own trips are its row minus the control's.
MATRIX=""
case "${1:-}" in "") : ;; --matrix) MATRIX=1 ;; *) echo "usage: run.sh [--matrix]" >&2; exit 2 ;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"       # .dist-only: this fixture is never installed, so there is one layout
VEM="$ROOT/scripts/validate-enforcement-map.sh"
[ -f "$VEM" ] || { echo "FIXTURE ERROR: cannot locate scripts/validate-enforcement-map.sh from $HERE" >&2; exit 2; }

echo "HERMETIC-CONSUMED scripts/validate-enforcement-map.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/crosswalk-home-decl.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

# Kills route through mutant_killed behind B_ctl, set only by the passing unmutated control.
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# 1 premise + 1 control + 4 mutants, plus (plain run only) 1 arm asserting no matrix-only cell ran.
EXPECTED_ASSERTIONS=7
[ -n "$MATRIX" ] && EXPECTED_ASSERTIONS=6
MIRROR_RUNS=5   # control + m1..m4

echo "crosswalk-home-declaration:"

README_REL='core/skills/ai-dlc/extensions/README.md'
TPL_REL='core/skills/ai-dlc/templates/crosswalk.md'

RUNS="$WORK/runs"; : > "$RUNS"
MUTS="$WORK/muts"; mkdir -p "$MUTS"
OUTD="$WORK/out";  mkdir -p "$OUTD"

# reg <label> <expected I69 count>  — then zero or more `mut` lines for that label.
#
# PHASE 1 IS REGISTRATION ONLY. The arms below, and their reasoning, stay in declaration
# order and the report is rendered in that same order, which is what keeps this fixture's
# stdout byte-comparable against the serial version it replaces.
reg() { printf '%s\t%s\n' "$1" "$2" >> "$RUNS"; : > "$MUTS/$1.tsv"; }

# mut <label> <file-rel> <perl-expr>
#
# The expression goes to a FILE rather than through the pool's argument list. These carry
# backticks, `$` sigils and embedded newlines, and one that arrived at the worker having been
# through one more round of shell scanning would still apply, still satisfy `cmp -s`, and
# prove something other than what its call site says. The worker expands it from a variable,
# which the shell does not re-scan.
mut() { printf '%s\t%s\n' "$2" "$3" >> "$MUTS/$1.tsv"; }

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

# ---------------------------------------------------------------------------
# M1 — the same-line home claim names a file with no declaration in it
# ---------------------------------------------------------------------------
reg m1 1
mut m1 "$README_REL" 's/`layer-contract\.yaml` declares as/`core-manifest.md` declares as/'

# ---------------------------------------------------------------------------
# M2 — the claim WRAPS. The window is two lines for exactly this reason: the
# template's claim spanned a line break, a line-scoped reader missed it, and its
# control fired anyway on the sites that happened to fit on one line.
# ---------------------------------------------------------------------------
reg m2 1
mut m2 "$TPL_REL" 's/`consumer_crosswalk_file:` in `\.claude\/skills\/ai-dlc\/layer-contract\.yaml`/`consumer_crosswalk_file:` in\n`.claude\/skills\/ai-dlc\/core-manifest.md`/'

# ---------------------------------------------------------------------------
# M3 — the ZERO GUARD. Every fix to this invariant removes one of its own
# subjects, so its failure mode is going quiet rather than going wrong.
# ---------------------------------------------------------------------------
reg m3 1
mut m3 "$README_REL" 's/declares as `consumer_crosswalk_file:`/is bound to the reader by/'
mut m3 "$TPL_REL"    's/declared as\n`consumer_crosswalk_file:` in/bound to the reader by\n`consumer_crosswalk_file:` via/'
mut m3 'core/skills/ai-dlc/layer-contract.yaml' 's/declares as `consumer_crosswalk_file:`/is bound to the reader by/g'

# ---------------------------------------------------------------------------
# M4 — the KNOCK-OUT. Deleting I69's own err line from the mirrored validator must
# take M1's finding with it. Without this arm every count above could be coming
# from a run that died before reaching this invariant.
# ---------------------------------------------------------------------------
reg m4 0
mut m4 "$README_REL" 's/`layer-contract\.yaml` declares as/`core-manifest.md` declares as/'
mut m4 'scripts/validate-enforcement-map.sh' 's/      err "I69 \$_cf names/      : "I69 \$_cf names/'

# ==================== PHASE 2: mirror, mutate and count, in a pool ====================
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
# The `cmp -s` guard stays INSIDE the worker, where the mutation is applied. It is what stops
# an expression that matched nothing from scoring a kill, and moving it to the parent would
# put it on the wrong side of the thing it checks.
#
# I69 LINES ONLY, never the exit code. The mirror carries no .githooks/, VERSION or CHANGELOG,
# so several unrelated invariants fail in it and the exit status says nothing about this one.
# Keying on the count of I69 findings is what makes each verdict attributable to the arm under
# test — and M4, the knock-out, is what proves the count comes from I69 rather than from the
# run having died before reaching it.
CHD_JOBS=5
CHD_MATRIX="$MATRIX" CHD_ROOT="$ROOT" CHD_WORK="$WORK" CHD_MUTS="$MUTS" CHD_OUT="$OUTD" \
  xargs -P "$CHD_JOBS" -I{} bash -c '
    l="$1"
    m="$CHD_WORK/mirror-$l"
    mkdir -p "$m" || { printf MIRRORFAIL > "$CHD_OUT/$l.state"; printf done > "$CHD_OUT/$l.done"; exit 0; }
    cp -R "$CHD_ROOT/core" "$CHD_ROOT/scripts" "$m/" || { printf MIRRORFAIL > "$CHD_OUT/$l.state"; printf done > "$CHD_OUT/$l.done"; exit 0; }
    while IFS="$(printf "\t")" read -r f e; do
      [ -n "$f" ] || continue
      cp "$m/$f" "$m/.before" || { printf VACUOUS > "$CHD_OUT/$l.state"; break; }
      perl -0pi -e "$e" "$m/$f" || { printf VACUOUS > "$CHD_OUT/$l.state"; break; }
      if cmp -s "$m/.before" "$m/$f"; then printf VACUOUS > "$CHD_OUT/$l.state"; break; fi
    done < "$CHD_MUTS/$l.tsv"
    rm -f "$m/.before"
    if [ ! -f "$CHD_OUT/$l.state" ]; then
      if [ -n "$CHD_MATRIX" ]; then _arms=""; else _arms="--arms I69,I68"; fi
      printf %s "$_arms" > "$CHD_OUT/$l.arms"
      bash "$m/scripts/validate-enforcement-map.sh" $_arms > "$CHD_OUT/$l.full" 2>&1
      grep -c "I69" "$CHD_OUT/$l.full" > "$CHD_OUT/$l.n" || true
    fi
    printf done > "$CHD_OUT/$l.done"
    rm -rf "$m"
  ' _ {} < <(cut -f1 "$RUNS")

if [ -n "$MATRIX" ]; then
  while IFS=$'\t' read -r _l _w; do
    [ -n "$_l" ] || continue
    _ids="$(grep -o '^FAIL: I[0-9]*[a-c]*' "$OUTD/$_l.full" 2>/dev/null | sed 's/^FAIL: //' | sort -u | tr '\n' ' ')"
    echo "MATRIX $_l i69_lines=$(tr -d '[:space:]' < "$OUTD/$_l.n" 2>/dev/null) tripped=[${_ids}]"
  done < "$RUNS"
fi

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

  if [ -f "$OUTD/$label.state" ]; then
    case "$label" in
      m1) bad "MUTANT m1 did not apply (the expression matched nothing) — a mutation that changes nothing scores a kill it has not earned" ;;
      m2) bad "MUTANT m2 did not apply (the expression matched nothing) — the template's claim is not where this fixture thinks it is" ;;
      m3) bad "MUTANT m3 did not apply to all three claim sites — the zero guard is unproven" ;;
      m4) bad "KNOCK-OUT did not apply — the arm's attribution is unproven" ;;
      *)  bad "$label did not apply" ;;
    esac
    continue
  fi

  n="$(cat "$OUTD/$label.n" 2>/dev/null | tr -d '[:space:]')"
  if grep -q '^FAIL: I68' "$OUTD/$label.full" 2>/dev/null; then
    bad "$label: twin arm I68 tripped; the recorded matrix has it green for every world"
    continue
  fi
  case "$label" in
    control)
      if [ "$n" -eq 0 ]; then
        ok "CONTROL: an unmutated mirror reports I69 zero times — the mutants below run against a tree the invariant accepts"
        B_ctl=1
      else
        bad "CONTROL: the unmutated mirror already reports I69 $n time(s); every mutant verdict below is meaningless"
      fi ;;
    m1)
      if [ "$n" -eq "$want" ]; then
        mutant_killed "${B_ctl:-0}" m1 "MUTANT killed: a README claiming the declaration lives in core-manifest.md is reported once"
      else
        bad "MUTANT m1: expected exactly $want I69 finding, got $n — the shipped grammar does not see a same-line home claim"
      fi ;;
    m2)
      if [ "$n" -eq "$want" ]; then
        mutant_killed "${B_ctl:-0}" m2 "MUTANT killed: a home claim broken across a line break is still read, and still reported once"
      else
        bad "MUTANT m2: expected exactly $want I69 finding, got $n — a claim that wraps escapes the grammar, which is the shape the real defect had"
      fi ;;
    m3)
      if [ "$n" -eq "$want" ]; then
        mutant_killed "${B_ctl:-0}" m3 "MUTANT killed: with every home claim reworded away the ZERO GUARD speaks — an empty subject set is reported, not accepted"
      else
        bad "MUTANT m3: expected exactly $want I69 finding (the zero guard), got $n — a grammar that stopped matching would read exactly like core having stopped restating the home"
      fi ;;
    m4)
      # The surviving state, named twice: the I69 count is $want (0), AND no other layer picked the
      # violating README up -- the invariants that tripped are exactly the control's, so nothing but
      # I69's own err line was reporting M1's finding. The name `m4` is the one reg/mut used above.
      _t4="$(grep -o '^FAIL: I[0-9]*[a-c]*' "$OUTD/m4.full" 2>/dev/null | sort -u | tr '\n' ' ')"
      _tc="$(grep -o '^FAIL: I[0-9]*[a-c]*' "$OUTD/control.full" 2>/dev/null | sort -u | tr '\n' ' ')"
      if [ "$n" -eq "$want" ] && [ "$_t4" = "$_tc" ]; then
        ok "CONTROL m4: with I69's err disabled the same violating tree reports I69 $n time(s) (want $want) and no other layer refuses it (tripped set equals the unmutated control's) — M1's kill is attributable to this invariant alone"
      else
        bad "CONTROL m4: expected $want I69 findings and the control's tripped set, got $n I69 and tripped [$_t4] vs control [$_tc] — the counts above are not measuring what this fixture claims"
      fi ;;
  esac
done < "$RUNS"

# A PLAIN RUN EXECUTES NO MATRIX-ONLY CELL: every mirror must have run on the two-arm selection.
if [ -z "$MATRIX" ]; then
  _full=0
  while IFS=$'\t' read -r _l _w; do
    [ -n "$_l" ] || continue
    [ "$(cat "$OUTD/$_l.arms" 2>/dev/null)" = "--arms I69,I68" ] || _full=$((_full+1))
  done < "$RUNS"
  if [ "$_full" -eq 0 ]; then
    ok "a plain run executes no matrix-only cell — every mirror ran on --arms I69,I68 alone"
  else
    bad "a plain run executed $_full mirror(s) outside --arms I69,I68 — the matrix-only whole-validator path leaked into the per-push run"
  fi
fi

# ---------------------------------------------------------------------------
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "  FAIL  assertion count: ran $made, expected $EXPECTED_ASSERTIONS — an arm did not execute, and one that never ran is silent, not green"
  fails=$((fails+1))
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "crosswalk-home-declaration: PASS ($made assertions)"; exit 0
else
  echo "crosswalk-home-declaration: FAIL ($fails of $made)"; exit 1
fi
