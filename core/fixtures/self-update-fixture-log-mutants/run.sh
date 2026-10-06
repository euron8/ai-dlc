#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# self-update-fixture-log-mutants/run.sh -- the mutation battery behind `self-update-fixture-log`.
# DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh [--rows <file>]
#        --rows  append one `<label>TAB<line>` row per line a scored section emitted, in dispatch
#                order, which is the unsplit fixture's own serial order.
# Exit:  0 = every section emitted its declared lines and none of them was a FAIL,
#        1 = an assertion failed, 2 = fixture broken.
#
# WHY THIS IS SPLIT OUT. Held inside the shipped fixture, the forty-five mutant sections ran
# serially after the arms, each one driving copies of the runner through the arms' worlds, and
# they were most of the fixture's cost. Every one of them mutates a copy of core's own
# `self-update-fixtures.sh`, which a consumer is denied editing, so proving the arms can fail is a
# question about a file only this repository changes. The consumer keeps every behavioural arm.
#
# ONE COPY OF THE WORLDS AND THE READERS. Both fixtures source `self-update-fixture-log/lib.sh`, so
# a mutant is driven through the very seeded distribution, consumer trees and log readers the
# shipped arms use. Each section below is the unsplit fixture's own block, moved verbatim into a
# function; its scoring, its expected observable and its message are unchanged.
#
# A SECTION IS NOT A PREDICATE SET, AND THE VERDICT SAYS SO. Unlike `review-shard-merge-mutants`,
# where every mutant is scored against one shared list of predicates, each section here carries
# its own drive-and-assert and emits a fixed number of `ok`/`FAIL` lines (two for CONTROL, one for
# every other). The verdict is that line count and the FAIL count among them.
#
# SCORED IN PARALLEL, AND THE SILENT LOSS IS THE FAILURE MODE THIS SHAPE HAS TO CLOSE. A pool that
# drops a scorer reports fewer verdicts, and fewer verdicts read exactly like fewer failures. So:
#   - each scorer runs in its own subshell under `$WORK/s-<id>/`, holding PRIVATE COPIES of every
#     world a section WRITES -- the two consumer trees whose logs and records it rewrites (`$CONS2`,
#     `$GCONS`), Part 21's consumer, Part 22's stub, and the reconcile siblings its mutants are
#     built beside. The sections clear and read logs by a second-resolution name, so two scorers
#     sharing a consumer would read each other's runs. The repositories a section only READS
#     (`$DIST`, `$WREPO`, the filtered clone, Part 21's and Part Q's distributions, G21's) are
#     built once and shared;
#   - it writes ONE verdict file, temp-then-mv, carrying the lines it emitted and how many FAILed;
#   - the parent counts verdicts against dispatches, and judges each with `judge`, which treats a
#     missing verdict, a TIMEOUT, an emitted count other than the declared one, or any FAIL as a
#     FAIL;
#   - `judge` itself is probed every run, on a real verdict file, in both directions.
# The pool is a FIXED width of 8 (no knob); completion is read from sentinel files the scorers
# write, never from the process table.
#
# THE WATCHDOG. bash 3.2 has no `wait -n`, so each scorer runs under a slot that polls it and,
# past SCORER_BOUND seconds, writes a TIMEOUT marker and kills the scorer's whole process tree
# (stopped first, then children before parents, so nothing reparents to init and keeps spinning).
# The unsplit fixture's loaded cost was 2425s for its arms and forty-five sections, about 50s a
# section loaded, and a unit under the gate's pool has measured 4x its solo time. 900s is roughly
# 18x that per-section figure.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="self-update-fixture-log-mutants"
ROWS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --rows) ROWS="${2:-}"; [ -n "$ROWS" ] || { echo "usage: run.sh [--rows <file>]" >&2; exit 2; }; shift 2 ;;
    *) echo "usage: run.sh [--rows <file>]" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
SIB="$HERE/../self-update-fixture-log"
[ -f "$SIB/lib.sh" ] || { echo "FIXTURE BROKEN: $SIB/lib.sh is absent; no world exists to drive a mutant through" >&2; exit 2; }
[ -f "$SIB/run.sh" ] || { echo "FIXTURE BROKEN: $SIB/run.sh is absent; the arms these mutants prove have no home" >&2; exit 2; }
if [ -n "$ROWS" ]; then : >> "$ROWS" || { echo "FIXTURE ERROR: cannot write --rows $ROWS" >&2; exit 2; }; fi
SUFL_RUNNER_ARG=""
# shellcheck source=../self-update-fixture-log/lib.sh
. "$SIB/lib.sh"
echo "$NAME:"

# ------------------------------------------------------------------------ the mutation helpers
# --- MUTATION: prove the arms above can fail -----------------------------------------------
# The runner SOURCES lib.sh from its own directory and evals `map_consumer()` out of
# preclassify.sh beside it, so a lone copy is NOT a working harness: it refuses before it runs
# anything. Every copy is therefore taken into `$MUTDIR`, which holds every reconcile sibling, and
# checked with an unmutated control, because "the mutant emitted nothing" and "the mutant
# survived" are the same bytes.

# Every mutation is a copy, and the anchor must occur EXACTLY once. A `replace(...,1)` against
# an anchor that has moved edits nothing and comes back green, and one against an anchor that
# has become ambiguous edits the wrong site — both are mutants that prove nothing, and both
# read as a passing battery.
mkmutant() { # $1=dest $2=old $3=new
  MUT_OLD="$2" MUT_NEW="$3" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
old, new = os.environ["MUT_OLD"], os.environ["MUT_NEW"]
if s.count(old) != 1: sys.exit(3)
open(sys.argv[2], "w").write(s.replace(old, new, 1))' "$RUNNER" "$1" 2>/dev/null || return 1
  [ -s "$1" ] && ! cmp -s "$RUNNER" "$1"
}

# A TWO-LAYER revert, for a state two guards independently refuse. A partial revert leaves a
# mutant that proves whichever layer was left in place, and it comes out green — so where a
# second guard covers the first, both come off in one copy and the arm scores the pair. The
# second anchor is counted AFTER the first substitution, so an edit that makes it ambiguous is
# a refusal rather than a silent wrong-site replacement.
mkmutant2() { # $1=dest $2=old1 $3=new1 $4=old2 $5=new2
  MUT_O1="$2" MUT_N1="$3" MUT_O2="$4" MUT_N2="$5" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
for o, n in ((os.environ["MUT_O1"], os.environ["MUT_N1"]),
             (os.environ["MUT_O2"], os.environ["MUT_N2"])):
    if s.count(o) != 1: sys.exit(3)
    s = s.replace(o, n, 1)
open(sys.argv[2], "w").write(s)' "$RUNNER" "$1" 2>/dev/null || return 1
  [ -s "$1" ] && ! cmp -s "$RUNNER" "$1"
}

# ------------------------------------------------------- the N-series vector and its scorer
# --- MUTANTS N1 to N8: the PATH-FORM NORMALISATION, scored as a VECTOR ------------------------
# Eight wrong ways to accept the path form step 2 derives. An adversarial hand built four of them
# against the suite as it stood and THREE CAME BACK GREEN, which is why the arms above exist and
# why these are scored the way they are.
#
# EACH MUTANT IS SCORED ON THE WHOLE VECTOR, NOT ON ONE CELL. A wrong normalisation is wrong in
# several places at once — it is one predicate feeding every argument — so an arm-at-a-time
# scoring would let a mutant that moves three cells be signed off by whichever one was looked at.
# `nsig` below drives the SAME eleven observables the arms above assert, through whatever runner
# it is handed, and every mutant asserts an EXACT expected vector. The cells a mutant moves are
# then a measurement rather than a prediction, the arm that OWNS each kill is named in the
# message, and a mutant that starts moving a twelfth cell fails here instead of passing quietly.
#
# THE CONTROL IS THE FIRST THING SCORED. `nsig` over the unmutated copy must read the all-correct
# vector; a harness that died, or a copy that emitted nothing, produces a vector of zeros that
# would otherwise score as eight simultaneous kills.
#
# THE CELLS, in order — rc of a path-form COMPLETE set over a range whose diff TOUCHES a named
# fixture; whether that run's fixture-section list equals the bare-name run's; how many arguments
# it logged as rewritten; the trailing-slash form accepted and run; the tests/fixtures form
# accepted and run; a space-joined path list refused under the whitespace reason with its whole
# argument as the row's subject; the newline-joined form likewise; `foo/bar`, `/abs/x` and
# `core/fixtures/deep/er` each refused under a PATH-SHAPE reason with the original argument as
# subject; and `core/fixtures/` refused with that literal string as its row's subject.
nsig() { # $1=runner path -> the eleven-cell signature
  ns_a=2; ns_b=0; ns_n=0; ns_c=0; ns_d=0; ns_e=0; ns_f=0; ns_g1=0; ns_g2=0; ns_g3=0; ns_h=0
  # A / B / N: the complete path-form set and its bare-name twin, over base..theirs.
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$1" "$DIST" "$D_BASE" theirs-tag "$CONS2" \
       core/fixtures/touched-shippable core/fixtures/touched-named core/fixtures/green-one \
       >/dev/null 2>&1
  ns_a=$?
  ns_lp="$(newest_log2)"
  ns_secp="$(sec_set "$ns_lp")"
  ns_n="$(grep -cE '^NORMALISED: ' "${ns_lp:-/dev/null}" 2>/dev/null)" || ns_n=0
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$1" "$DIST" "$D_BASE" theirs-tag "$CONS2" \
       touched-shippable touched-named green-one >/dev/null 2>&1
  ns_secb="$(sec_set "$(newest_log2)")"
  { [ -n "$ns_secb" ] && [ "$ns_secp" = "$ns_secb" ]; } && ns_b=1
  # C / D: the two prefix strips and the trailing-slash strip, each alone.
  for ns_pair in "core/fixtures/green-one/:c" "tests/fixtures/green-one:d"; do
    ns_arg="${ns_pair%:*}"; ns_cell="${ns_pair##*:}"
    rm -f "$LOGDIR2"/self-update-fixtures-*.md
    bash "$1" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" "$ns_arg" >/dev/null 2>&1
    ns_r=$?; ns_l="$(newest_log2)"
    if [ "$ns_r" -eq 0 ] && [ -n "$ns_l" ] \
       && grep -qF "===== FIXTURE green-one =====" "$ns_l" \
       && grep -qF "NORMALISED: ${ns_arg} -> green-one" "$ns_l"; then
      [ "$ns_cell" = c ] && ns_c=1 || ns_d=1
    fi
  done
  # E / F: the joined list in the path form, space-joined and newline-joined.
  ns_sp="core/fixtures/touched-shippable core/fixtures/green-one"
  ns_nl="core/fixtures/touched-shippable
core/fixtures/green-one"
  # THE ROW IS MATCHED WITH ITS NEWLINES SQUASHED, and a plain `grep -F` here is WRONG in the
  # acquitting direction. A multi-line `-F` pattern is a list of ALTERNATIVES, not one string, so
  # the newline-joined seed's row matched whenever EITHER half appeared anywhere in the output —
  # measured on mutant N2, which rewrites the argument and destroys the row's subject, and still
  # scored this cell correct because the second half of the pattern matched the row's tail. Both
  # sides are folded onto one line first, so the comparison is the whole row or nothing.
  for ns_cell in e f; do
    [ "$ns_cell" = e ] && ns_arg="$ns_sp" || ns_arg="$ns_nl"
    rm -f "$LOGDIR2"/self-update-fixtures-*.md
    bash "$1" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" "$ns_arg" cwd-probe \
      >/dev/null 2>"$CONS2/err-nsig.txt"
    ns_r=$?; ns_l="$(newest_log2)"
    ns_flat="$(tr '\n' '\002' < "$CONS2/err-nsig.txt")"
    ns_want="$(printf '  %s — not a fixture NAME: it carries whitespace' "$ns_arg" | tr '\n' '\002')"
    ns_row=0
    case "$ns_flat" in *"$ns_want"*) ns_row=1 ;; esac
    if [ "$ns_r" -eq 2 ] && [ -n "$ns_l" ] && ! grep -qF "===== FIXTURE " "$ns_l" \
       && [ "$ns_row" -eq 1 ]; then
      [ "$ns_cell" = e ] && ns_e=1 || ns_f=1
    fi
  done
  # G1 / G2 / G3 / H: the slash forms that stay refused, and the empty name.
  for ns_pair in "foo/bar:g1" "/abs/x:g2" "core/fixtures/deep/er:g3" "core/fixtures/:h"; do
    ns_arg="${ns_pair%:*}"; ns_cell="${ns_pair##*:}"
    rm -f "$LOGDIR2"/self-update-fixtures-*.md
    bash "$1" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" "$ns_arg" cwd-probe \
      >/dev/null 2>"$CONS2/err-nsig.txt"
    ns_r=$?; ns_l="$(newest_log2)"
    if [ "$ns_r" -eq 2 ] && [ -n "$ns_l" ] && ! grep -qF "===== FIXTURE " "$ns_l" \
       && grep -qF "  ${ns_arg} — not a fixture NAME" "$CONS2/err-nsig.txt" \
       && ! grep -qF "  ${ns_arg} — not a fixture NAME: it carries whitespace" "$CONS2/err-nsig.txt"; then
      case "$ns_cell" in g1) ns_g1=1 ;; g2) ns_g2=1 ;; g3) ns_g3=1 ;; h) ns_h=1 ;; esac
    fi
  done
  printf '%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s' \
    "$ns_a" "$ns_b" "$ns_n" "$ns_c" "$ns_d" "$ns_e" "$ns_f" "$ns_g1" "$ns_g2" "$ns_g3" "$ns_h"
}

NSIG_OK="0-1-3-1-1-1-1-1-1-1-1"

# `mkmutant` counts its anchor and refuses anything but exactly one occurrence, so a mutation
# that matched nothing is reported as DID NOT APPLY rather than surviving as a no-op. The block
# relocations below cannot use it — they move text rather than replace it — so each one asserts
# the copy is non-empty, differs from the original, and differs from its sibling relocation.
n_score() { # $1=label $2=mutant path $3=expected vector $4=owning arm $5=what the mutant does
  ns_got="$(nsig "$2")"
  if [ "$ns_got" = "$3" ]; then
    ok "MUTATION $1 — $5: vector $ns_got against the correct $NSIG_OK. $4"
  else
    bad "MUTATION $1 — $5, and the vector did not move as predicted (got '$ns_got', expected '$3', correct is '$NSIG_OK'). A cell that did NOT move is an arm above asserting something this wrong implementation cannot break; a cell that moved and was not predicted is a second defect nobody has read"
  fi
}

# The whole normalisation block, lifted as text, for the two SITING mutants.
NBLK_A='# --- THE ARGUMENT IS A BARE NAME'
NBLK_B='# --- The COVERAGE join'


# ----------------------------------------------------------------------- the sibling builders
# A section whose `cmp -s` guard compares its copy against ANOTHER mutant's builds that sibling
# into its own scratch first. In a private scratch the sibling is otherwise absent, `cmp -s`
# fails, and `! cmp -s` passes for a file that does not exist.
b_M2() {
M2="$MUTDIR/m2-coverage-deleted.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The COVERAGE join"), s.index("n_run=0; n_ok=0")
open(sys.argv[2], "w").write(s[:a] + s[b:])' "$RUNNER" "$M2" 2>/dev/null
}
b_M6() {
M6="$MUTDIR/m6-overarm-deleted.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
open(sys.argv[2], "w").write(s[:a] + s[b:])' "$RUNNER" "$M6" 2>/dev/null
}
b_M9() {
M9="$MUTDIR/m9-overarm-above-refloop.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("for r in \"$BASE\" \"$THEIRS\"; do")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M9" 2>/dev/null
}
b_N5() {
N5="$MUTDIR/n5-sited-after-the-coverage-join.sh"
NBLK_A="$NBLK_A" NBLK_B="$NBLK_B" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
a, b = s.index(os.environ["NBLK_A"]), s.index(os.environ["NBLK_B"])
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("n_run=0; n_ok=0")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$N5" 2>/dev/null
}
b_MG5() {
MG5="$MUTDIR/mg5-inputs-unchecked.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a = s.index("    else\n      # THE INPUTS THE VERDICT READ")
b = s.index("  elif [ \"$gr_seen\" -eq 0 ]; then")
open(sys.argv[2], "w").write(s[:a] + "    fi\n" + s[b:])' "$RUNNER" "$MG5" 2>/dev/null
}

# ------------------------------------------------------------------------------ the sections
# Each section is the unsplit fixture's block, moved verbatim into a function. A scorer runs one
# in its own scratch, with every mutable world rebound there by `scorer_world`.
sec_CONTROL() {
# --- CONTROL --------------------------------------------------------------------------------
# Two arms, and the second one is why the first is not enough: an rc=2-and-nothing-reported
# control passes against a subject replaced by `exit 0`, because that is exactly what a clean
# copy looks like. The green arm demands a baseline row be THERE.
bash "$CTL" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "CONTROL: the unmutated copy still exits 2 on an empty set — the mutant verdicts below are their edits"
else
  bad "FIXTURE ERROR: the unmutated copy did not exit 2 on an empty set, so the copied harness is what is being measured"
fi
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$CTL" "$DIST" "$D_QUIET" "$D_SHIP" "$CONS2" touched-shippable green-one >/dev/null 2>&1
rc=$?
LC="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$LC" ] && grep -qF "===== FIXTURE green-one =====" "$LC"; then
  ok "CONTROL: the unmutated copy runs the named fixtures and writes their sections — a copy that emitted nothing would fail here rather than score as a kill"
else
  bad "FIXTURE ERROR: the unmutated copy did not produce a green run with a green-one section (rc=$rc). Every kill below would be the copied harness dying, not the mutation"
fi
}
sec_M0() {
# --- MUTANT 0: the empty-set guard returns 0 ------------------------------------------------
M0="$MUTDIR/m0-emptyset-green.sh"
if mkmutant "$M0" '  exit 2
fi

SELF=' '  exit 0
fi

SELF='; then
  bash "$M0" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ok "MUTATION — with the empty-set guard returning 0, naming nothing reads as a green suite: Part 4 is what catches that"
  else
    bad "MUTATION — the empty-set guard was neutered and the runner still refused; Part 4's assertion is vacuous"
  fi
else
  bad "FIXTURE ERROR: the empty-set anchor no longer occurs exactly once in the runner — Part 4 proves nothing. Re-anchor it on the runner's real empty-set guard"
fi
}
sec_M15() {
  if [ ! -d "$FILT/.git" ] || ! filt_ok; then
    ok "SKIP: Mutant 15 needs Part 20's DISCRIMINATING blob-filtered clone, and this git/transport did not produce one (missing=$f_missing, cat-file=$f_cat, rev-parse=$f_rev, control=$f_ctl)"
    return 0
  fi
    # MUTANT 15, scored HERE because the clone it needs is alive only inside this block. Both
    # arms above are the shape `fixture-mutants.md` warns about — one asserts an acquittal and
    # the other a presence, and a subject that emits nothing would satisfy the first. This is
    # what makes them load-bearing: put the blob-reading spelling back at the two `run.sh` probe sites.
    #
    # `mkmutant` writes into `$MUTDIR`, which already holds the reconcile siblings. A copy made
    # anywhere else cannot load `map_consumer()` out of `preclassify.sh` and exits 2 as a
    # REFUSAL — measured while building this arm, and it scored as a kill for both halves while
    # the mutation itself was never executed.
    M15="$MUTDIR/m15-probe-reads-the-blob.sh"
    MUT_N=0
    MUT_N="$(python3 -c 'import re,sys
s = open(sys.argv[1]).read()
pat = r"git -C \"\$DIST\" rev-parse -q --verify \"\$\{THEIRS\}:core/fixtures/([^\"]+)\" >/dev/null 2>&1"
out, n = re.subn(pat, lambda m: "git -C \"$DIST\" cat-file -e \"${THEIRS}:core/fixtures/" + m.group(1) + "\" 2>/dev/null", s)
open(sys.argv[2], "w").write(out)
print(n)' "$RUNNER" "$M15" 2>/dev/null || echo 0)"
    # TWO SITES, NOT FOUR: the two `.dist-only` probes are `memo_has_path` now (BL-403), and only
    # the two `run.sh` probes still resolve through `rev-parse`. Those are the ones a filtered
    # blob can fool, and they alone produce both halves of the observable below.
    if [ "${MUT_N:-0}" -ne 2 ] || cmp -s "$RUNNER" "$M15"; then
      bad "FIXTURE ERROR: expected 2 tree-resolving run.sh probe sites to mutate, moved ${MUT_N:-0} — Part 20 proves nothing"
    else
      rm -f "$LOGDIR2"/self-update-fixtures-*.md
      bash "$M15" "$FILT" "$f_base" filt-theirs "$CONS2" keeper mover >/dev/null 2>&1
      m_over="$(uns_set "$(newest_log2)")"
      rm -f "$LOGDIR2"/self-update-fixtures-*.md
      bash "$M15" "$FILT" "$f_base" filt-theirs "$CONS2" keeper >/dev/null 2>&1
      m_under="$(cov_set "$(newest_log2)")"
      if [ "$m_over" = "keeper,mover," ] && [ -z "$m_under" ]; then
        ok "MUTATION — reading the BLOB instead of the tree convicts the whole correct set (keeper,mover) AND silences the under-completeness join on the same clone: both halves of Part 20 are what catch that"
      else
        bad "MUTATION — the probes were reverted to \`cat-file -e\` and Part 20 did not see it (over refused '$m_over', expected 'keeper,mover,'; under reported '$m_under', expected empty). One or both halves are asserting something no mutation can move"
      fi
    fi
}
sec_M1() {
# --- MUTANT 1: the .dist-only exemption inverted ---------------------------------------------
M1="$MUTDIR/m1-exemption-inverted.sh"
if mkmutant "$M1" '    0)   continue ;;' \
                  '    0)   ;;'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M1" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >/dev/null 2>&1
  if [ "$(cov_set "$(newest_log2)")" = "touched-distonly,touched-shippable," ]; then
    ok "MUTATION — with the .dist-only exemption inverted a never-shipped fixture joins the refusal: Part 7's set equality is what catches that"
  else
    bad "MUTATION — the .dist-only exemption was inverted and the refusal list did not change. Part 7 asserts an exemption no run can move, so the exemption is untested"
  fi
else
  bad "FIXTURE ERROR: the .dist-only exemption anchor no longer occurs exactly once in the runner — the exemption half of Part 7 proves nothing"
fi
}
sec_M2() {
  b_M2
# --- MUTANT 2: the coverage join deleted outright --------------------------------------------
# The block is excised rather than edited, because a partial revert leaves a mutant that proves
# whichever layer was left in place.
if [ -s "$M2" ] && ! cmp -s "$RUNNER" "$M2"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M2" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && ! grep -qF "COVERAGE:" "$LM"; then
    ok "MUTATION — with the whole coverage join removed the incomplete slice runs green: Part 7 is what catches that"
  else
    bad "MUTATION — the coverage join was removed and the incomplete slice was still refused (rc=$rc). Something else is producing Part 7's verdict"
  fi
else
  bad "FIXTURE ERROR: the coverage block could not be excised — its start or end anchor has moved, and Part 7 proves nothing"
fi
}
sec_M3() {
  b_M2
# --- MUTANT 3: the coverage join moved AFTER the fixture loop ---------------------------------
# A placement mutant, and the reason Part 7 asserts on ordering rather than on the verdict: this
# copy still refuses, with the same list, having already run and reported every fixture first.
M3="$MUTDIR/m3-coverage-after-loop.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The COVERAGE join"), s.index("n_run=0; n_ok=0")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("{\n  echo \"# summary:")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M3" 2>/dev/null
if [ -s "$M3" ] && ! cmp -s "$RUNNER" "$M3" && ! cmp -s "$M2" "$M3"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M3" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >"$CONS2/out-m3.txt" 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ -n "$LM" ] && grep -qF "COVERAGE: the diff changes" "$LM" \
     && grep -qF "===== FIXTURE green-one =====" "$LM"; then
    ok "MUTATION — moved below the loop the join still refuses with the same list, having reported every fixture first: only Part 7's ordering arm sees it"
  else
    bad "MUTATION — the join was moved after the fixture loop and Part 7's ordering arm did not fire (rc=$rc). An arm that cannot tell before from after is asserting the verdict twice"
  fi
else
  bad "FIXTURE ERROR: the coverage block could not be relocated — an anchor has moved, or the relocated copy is byte-identical to the deleted one, and the ordering arm proves nothing"
fi
}
sec_M4() {
# --- MUTANT 4: the ref-resolution loop neutered ------------------------------------------------
# `&& continue` becomes `; continue`, so every ref is accepted. On a BOGUS ref this changes
# almost nothing — the diff-failure arm underneath still exits 2 — which is why the mutant is
# scored on Part 12's input instead: `git diff <tree> <commit>` succeeds, so that arm never fires
# either, and the loop's peel to `^{commit}` is the only thing standing between a base that names
# no commit and a join taken over whatever fell out.
#
# SCORED ON THE MESSAGE AND NOT ON THE EXIT CODE, AND THE REASON IS A SECOND GUARD DOWNSTREAM.
# The gate-record arm peels both refs too, so an unpeelable base now reaches it and is refused
# there as an unidentifiable range — the copy still exits 2, and an arm reading the code alone
# would score a kill for a loop it never reached. That is the shape Parts 18 and 19 already own
# from the other side: an arm hoisted above a guard makes the guard unreachable, and which arm
# ANSWERS is the property, not whether something did. So the pair is asserted — the unmutated
# copy records UNRESOLVABLE for this input and the mutant does not — with the mutant's own
# refusal read as the control that says it RAN. Parts 10 to 12 key on the same message for the
# same reason.
M4="$MUTDIR/m4-refcheck-neutered.sh"
if mkmutant "$M4" 'rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1 && continue' \
                  'rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1; continue'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M4" "$DIST" "$D_TREE" theirs-tag "$CONS2" green-one >/dev/null 2>&1
  rc=$?
  LM4="$(newest_log2)"
  m4_mut_unres=1; { [ -n "$LM4" ] && grep -qF "COVERAGE: UNRESOLVABLE" "$LM4"; } || m4_mut_unres=0
  m4_mut_said=0; { [ -n "$LM4" ] && grep -qE "^(COVERAGE|GATE-RECORD):" "$LM4"; } && m4_mut_said=1
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$CTL" "$DIST" "$D_TREE" theirs-tag "$CONS2" green-one >/dev/null 2>&1
  LM4C="$(newest_log2)"
  m4_ctl_unres=0; { [ -n "$LM4C" ] && grep -qF "COVERAGE: UNRESOLVABLE" "$LM4C"; } && m4_ctl_unres=1
  if [ "$m4_ctl_unres" -eq 1 ] && [ "$m4_mut_unres" -eq 0 ] && [ "$m4_mut_said" -eq 1 ]; then
    ok "MUTATION — with the ref peel removed a base that names a TREE stops being reported as UNRESOLVABLE (the unmutated copy reports it on the same input, and the mutant still writes a log, so it ran): Part 12 is what catches that"
  else
    bad "MUTATION — the ref-resolution loop was neutered and Part 12's message did not move (unmutated UNRESOLVABLE=$m4_ctl_unres expected 1, mutant UNRESOLVABLE=$m4_mut_unres expected 0, mutant wrote a finding=$m4_mut_said expected 1). Either Part 12's input does not reach that loop, or the copy emitted nothing and its silence was about to score as a kill"
  fi
else
  bad "FIXTURE ERROR: the ref-resolution anchor no longer occurs exactly once in the runner — Parts 10 to 12 prove nothing"
fi
}
sec_M5() {
# --- MUTANT 5: the distribution check neutered ------------------------------------------------
# `if ! git cat-file -e ...` becomes `if false`, so any git repo is accepted. Part 13 is
# absence-shaped without this: the arm asks for a refusal, and a subject that refuses nothing
# at all — including one replaced by `exit 0` — is exactly what a wrong repo looks like once
# the guard is gone. The copy reports a GREEN SUITE over a checkout holding no fixtures.
#
# TWO LAYERS COME OFF, because a second guard now covers this one. The over-completeness arm
# below also refuses a wrong repo — every `cat-file -e` at a theirs with no `core/fixtures`
# tree fails, so it convicts the whole named set — and with the distribution check alone
# removed this copy would still exit 2, scoring a kill for a guard that had not been reached.
# Removing only the emission keeps the arm's own logic intact and reverts exactly the covering
# layer. Which of the two SHOULD answer is Part 19's subject, not this one's.
M5="$MUTDIR/m5-distcheck-neutered.sh"
if mkmutant2 "$M5" 'if ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures" 2>/dev/null; then' \
                   'if false; then' \
                   'if [ -n "$unshippable" ]; then' \
                   'if false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M5" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "COVERAGE:" "$LM"; then
    ok "MUTATION — with the distribution check removed a repo holding no core/fixtures runs to a green suite: Part 13 is what catches that"
  else
    bad "MUTATION — the distribution check was neutered and the wrong repo was still refused (rc=$rc). Part 13's verdict is coming from somewhere else, and the guard is untested"
  fi
else
  bad "FIXTURE ERROR: the distribution-check anchor no longer occurs exactly once in the runner — Part 13 proves nothing"
fi
}
sec_M6() {
  b_M6
# --- MUTANTS 6 to 13: the OVER-completeness arm --------------------------------------------
# Keyed on LOCATION and on observable BEHAVIOUR, never on a spelling — Mutant 13 is a competent
# author's OTHER phrasing of the same fix and every arm above has to pass it. Each mutant's
# scoring input is the input of the ONE part that owns it, so a mutant that moves two cells is
# a report that two arms are watching the same subject.

# --- MUTANT 6: the whole over-completeness arm excised ---------------------------------------
# Excised rather than edited: a partial revert leaves a mutant that proves whichever probe was
# left in place. The named set is Part 14's, and the surplus directory has a driver in the
# consumer seed — so the copy runs it and reports a GREEN suite, which is exactly what the
# reference consumer saw while the orphan was being committed.
if [ -s "$M6" ] && ! cmp -s "$RUNNER" "$M6"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M6" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE named-distonly =====" "$LM" \
     && ! grep -qF "COVERAGE: the named set contains" "$LM"; then
    ok "MUTATION — with the over-completeness arm removed, a set naming a never-shipped fixture RUNS it and reports green: Part 14 is what catches that"
  else
    bad "MUTATION — the over-completeness arm was removed and the surplus directory was still refused (rc=$rc). Something else is producing Part 14's verdict, and the arm is untested"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be excised — its start or end anchor has moved, and Parts 14 to 19 prove nothing"
fi
}
sec_M7() {
# --- MUTANT 7: the .dist-only probe neutered, the run.sh probe kept ---------------------------
# One exclusion at a time, because a mutant that removes both cannot say which arm saw it. The
# anchor is the over-arm's `elif` on the probe's status; the diff-side copy of the same probe
# reads its status through a `case`, so the substitution cannot land on the miss-join's exemption.
M7="$MUTDIR/m7-distonly-probe-gone.sh"
if mkmutant "$M7" '  elif [ "$_do_rc" -eq 0 ]; then' \
                  '  elif false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M7" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE named-distonly =====" "$LM"; then
    ok "MUTATION — with only the .dist-only probe gone the never-shipped directory has a run.sh at theirs, passes the surviving probe and is RUN: Part 14 is what catches that"
  else
    bad "MUTATION — the .dist-only probe was removed and the directory was still refused (rc=$rc). Part 14's verdict is coming from the run.sh probe, so the exclusion that produced the filed episode is untested"
  fi
else
  bad "FIXTURE ERROR: the .dist-only probe anchor no longer occurs exactly once in the runner — Part 14 proves nothing"
fi
}
sec_M8() {
# --- MUTANT 8: the run.sh probe neutered, the .dist-only probe kept ---------------------------
M8="$MUTDIR/m8-runsh-probe-gone.sh"
if mkmutant "$M8" '  elif ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/run.sh" >/dev/null 2>&1; then' \
                  '  elif false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M8" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       touched-deleted green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE touched-deleted =====" "$LM"; then
    ok "MUTATION — with only the run.sh probe gone a directory upstream DELETED is accepted and run: Part 15 is what catches that"
  else
    bad "MUTATION — the run.sh probe was removed and the deleted-driver directory was still refused (rc=$rc). Part 15 is being answered by the .dist-only probe, so the second exclusion is untested"
  fi
else
  bad "FIXTURE ERROR: the run.sh probe anchor no longer occurs exactly once in the runner — Part 15 proves nothing"
fi
}
sec_M9() {
  b_M6
  b_M9
# --- MUTANT 9: the arm relocated ABOVE the ref-resolution loop --------------------------------
# The placement mutant Part 18 owns. It is a strictly wider move than Mutant 10's — above the
# resolution loop is also above the wrong-repo guard — so Part 19 fires on this copy too. That
# is the direction that is allowed: Mutant 10 is the input only Part 19 can see, and it is what
# stops Part 19 from being an echo of Part 18.
if [ -s "$M9" ] && ! cmp -s "$RUNNER" "$M9" && ! cmp -s "$M6" "$M9"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M9" "$DIST" "$D_THEIRS" no-such-theirs-ref "$CONS2" green-one touched-shippable \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$LM")" = "green-one,touched-shippable," ] \
     && ! grep -qF "COVERAGE: UNRESOLVABLE" "$LM"; then
    ok "MUTATION — sited above the ref-resolution loop the arm probes an unresolvable theirs, every cat-file fails, and it convicts two directories the distribution ships: Part 18 is what catches that"
  else
    bad "MUTATION — the arm was moved above the ref-resolution loop and Part 18's arm did not fire (rc=$rc, refused '$(uns_set "$LM")'). An arm keyed on the exit code alone cannot tell the resolution refusal from this one, because both are 2"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be relocated above the ref loop — an anchor has moved, or the relocated copy is byte-identical to the deleted one, and Part 18 proves nothing"
fi
}
sec_M10() {
  b_M9
# --- MUTANT 10: the arm relocated ABOVE the wrong-repo guard, BELOW the ref loop ---------------
# The input only Part 19 can see. Both refs resolve here, so the resolution loop is satisfied and
# Part 18 passes against this copy — what it gets wrong is a checkout whose theirs carries no
# `core/fixtures` tree at all, where every probe fails again and the repo's defect is reported as
# the slice's.
M10="$MUTDIR/m10-overarm-above-distguard.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("# AND `$DIST` MUST BE THE DISTRIBUTION")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M10" 2>/dev/null
if [ -s "$M10" ] && ! cmp -s "$RUNNER" "$M10" && ! cmp -s "$M9" "$M10"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M10" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$LM")" = "green-one,touched-shippable," ] \
     && ! grep -qF "COVERAGE: WRONG-REPO" "$LM"; then
    ok "MUTATION — sited above the wrong-repo guard the arm indicts the named set of a checkout that is simply the wrong repo, and Part 18 cannot see it because both refs resolve: Part 19 is what catches that"
  else
    bad "MUTATION — the arm was moved above the wrong-repo guard and Part 19's arm did not fire (rc=$rc, refused '$(uns_set "$LM")'). Part 19 is then an echo of Part 18 and the ordering it asserts is untested"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be relocated above the wrong-repo guard — an anchor has moved, or the copy is byte-identical to Mutant 9's, and Part 19 proves nothing"
fi
}
sec_M11() {
# --- MUTANT 11: both probes read the DISTRIBUTION CHECKOUT instead of theirs -------------------
# The implementation a naive seed cannot distinguish from the right one. It returns the exact
# INVERSE of Part 17's set, and it is wrong in both directions at once: it acquits an orphan
# bound for the consumer and convicts two fixtures the pull genuinely delivers.
M11="$MUTDIR/m11-probes-read-disk.sh"
# The marker probe is spelled identically at both sites, so its anchor carries the over-arm's
# own status test on the next line, which the diff-side copy does not have.
if mkmutant2 "$M11" $'  memo_has_path "$DIST" "$THEIRS" "core/fixtures/${d}/.dist-only" || _do_rc=$?\n  if [ "$_do_rc" -ne 0 ] && [ "$_do_rc" -ne 128 ]; then' \
                    $'  [ -f "$DIST/core/fixtures/${d}/.dist-only" ] || _do_rc=128\n  if [ "$_do_rc" -ne 0 ] && [ "$_do_rc" -ne 128 ]; then' \
                    'elif ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/run.sh" >/dev/null 2>&1; then' \
                    'elif [ ! -f "$DIST/core/fixtures/${d}/run.sh" ]; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M11" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       theirs-only-distonly theirs-only-nodriver disk-only-distonly disk-missing-driver green-one \
       >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "disk-missing-driver,disk-only-distonly," ]; then
    ok "MUTATION — probing the checkout instead of theirs inverts the verdict exactly: the two orphans are acquitted and two shippable fixtures convicted. Part 17 is what catches that"
  else
    bad "MUTATION — the probes were pointed at the \$DIST worktree and Part 17 did not change its answer (rc=$rc, refused '$(uns_set "$(newest_log2)")'). Then disk and theirs agree for every directory Part 17 names, and the arm cannot tell the two implementations apart"
  fi
else
  bad "FIXTURE ERROR: one of the two probe anchors no longer occurs exactly once in the runner — Part 17 proves nothing"
fi
}
sec_M12() {
# --- MUTANT 12: the refusal degraded to a warning that falls through ---------------------------
# `exit 2` becomes `:`. The two refusal blocks in this runner end in BYTE-IDENTICAL three-line
# tails, so the anchor carries the remedy sentence that only this one has — keying on the shared
# tail would edit the miss-join and score a kill this arm did not earn.
#
# THE ANCHOR MOVED WHEN THE ARM GAINED A ROW, AND THE FIXTURE SAID SO RATHER THAN PASSING.
# The unparsable-argument row (PC-S310) added four remedy lines between the RETIRED-FIXTURE-
# ORPHAN sentence and the shared tail, so the old three-line anchor stopped resolving and this
# arm reported FIXTURE ERROR — correctly, since a mutant that cannot be built kills nothing.
# Re-keyed on the LAST line of that remedy, which is unique to this block (derived: 1
# occurrence, against 3 for the bare `log:`/`exit 2` tail it sits above). Any future row added
# here moves it again, and that is the intended behaviour: the anchor is meant to break loudly
# rather than silently edit the other refusal.
M12="$MUTDIR/m12-refusal-is-a-warning.sh"
if mkmutant "$M12" '  newline-joined list arrives as ONE argument; word-split it explicitly." >&2
  echo "  log: $LOG" >&2
  exit 2' \
                   '  newline-joined list arrives as ONE argument; word-split it explicitly." >&2
  echo "  log: $LOG" >&2
  :'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M12" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "COVERAGE: the named set contains" "$LM" \
     && grep -qF "===== FIXTURE named-distonly =====" "$LM"; then
    ok "MUTATION — reporting the surplus directory and then RUNNING it anyway exits 0, and a green exit is the only thing step 2 reads: Part 14's exit-code and ordering arms are what catch that"
  else
    bad "MUTATION — the refusal was degraded to a warning and the run still failed (rc=$rc). Part 14 is asserting on the message alone, and a finding printed above a green exit reaches nobody"
  fi
else
  bad "FIXTURE ERROR: the refusal-tail anchor no longer occurs exactly once in the runner — Part 14's exit-code arm proves nothing"
fi
}
sec_M13() {
# --- MUTANT 13: a SECOND SPELLING of the CORRECT fix, which must PASS --------------------------
# A competent author's other phrasing: the two probes lifted into a helper that returns the
# reason, the loop reduced to a call and an append. Same reads, same ref, same messages, same
# exit. A battery that rejects this is not testing the property, it is testing one author's
# formatting — and the next correct change to the runner would come back red for no reason.
SPELL2="$MUTDIR/second-spelling-body.txt"
cat > "$SPELL2" <<'SPELLEOF'
unship_reason() { # $1=directory name — echoes the reason it cannot ship, or nothing
  if git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${1}/.dist-only" >/dev/null 2>&1; then
    printf 'carries .dist-only at %s: never shipped, so no consumer can hold it' "$THEIRS"
  elif ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${1}/run.sh" >/dev/null 2>&1; then
    printf 'no run.sh at %s: upstream deleted the driver, so there is nothing to write' "$THEIRS"
  fi
}
unshippable=""
for d in "$@"; do
  why="$(unship_reason "$d")"
  [ -n "$why" ] || continue
  unshippable="$unshippable
  $d — $why"
done

if [ -n "$unshippable" ]; then
  { echo "COVERAGE: the named set contains fixture(s) no consumer can run:"
    printf '%s\n' "${unshippable#
}"
    echo ""; } >> "$LOG"
  echo "self-update-fixtures: the named set contains fixtures no consumer can run:" >&2
  printf '%s\n' "$unshippable" >&2
  echo "  Step 2 derives the covering set by hand and the exclusions are stated for the" >&2
  echo "  diff-side term. Writing one of these into the consumer creates a fixture core" >&2
  echo "  never ships — the RETIRED-FIXTURE-ORPHAN class. Drop them from the slice and re-run." >&2
  echo "  log: $LOG" >&2
  exit 2
fi

SPELLEOF
M13="$MUTDIR/m13-second-spelling.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("unshippable=\"\"\n"), s.index("# The diff is taken into a variable")
open(sys.argv[2], "w").write(s[:a] + open(sys.argv[3]).read() + s[b:])' "$RUNNER" "$M13" "$SPELL2" 2>/dev/null
if [ -s "$M13" ] && ! cmp -s "$RUNNER" "$M13"; then
  s13=0
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  [ $? -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "named-distonly," ] || s13=$((s13+1))
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       theirs-only-distonly theirs-only-nodriver disk-only-distonly disk-missing-driver green-one \
       >/dev/null 2>&1
  [ $? -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "theirs-only-distonly,theirs-only-nodriver," ] || s13=$((s13+1))
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       green-one cwd-probe touched-named touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  { [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE touched-named =====" "$LM" \
      && ! grep -qF "COVERAGE: the named set contains" "$LM"; } || s13=$((s13+1))
  if [ "$s13" -eq 0 ]; then
    ok "SECOND SPELLING — the same fix written with a reason-returning helper passes Parts 14, 16 and 17 unchanged: the arms are keyed on the property, not on one author's phrasing"
  else
    bad "SECOND SPELLING — an equivalent implementation of the SAME fix failed $s13 of Parts 14, 16 and 17. A battery that only accepts the phrasing it was written against rejects the next correct change, and this repo has shipped a receipt that certified a regression and refused the real fix"
  fi
else
  bad "FIXTURE ERROR: the second spelling could not be built — the over-completeness block's anchors have moved, and nothing establishes that Parts 14 to 19 accept an equivalent implementation"
fi
}
sec_M13b() {
# --- MUTANT 13b: the NAME-SHAPE probe reverted to a TREE probe --------------------------------
# The mutant that rebuilds the fix's own first wrong cut, which passed a hand-written check and
# was caught only by Part 15 going red. Probing the containing TREE looks equivalent and is not:
# a genuine retirement removes the directory, so it fails a tree probe exactly as an unparsable
# argument does, and every real deleted-driver row is relabelled.
#
# IT MUST MOVE PART 15, NOT PART 15b. That asymmetry is the whole point — the mutant still emits
# the new row for the joined argument, so an arm keyed only on 15b would score it a pass. Scored
# on BOTH: 15b stays green, 15 goes red.
M13B="$MUTDIR/m13b-tree-probe-not-name-shape.sh"
if mkmutant "$M13B" '  elif [ "$d" != "$(printf '"'"'%s'"'"' "$d" | tr -d '"'"'[:space:]/'"'"')" ] || [ -z "$d" ]; then' \
                    '  elif ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}" >/dev/null 2>&1; then'; then
  s13b=0
  # (a) the joined argument still gets the new row — the mutant is NOT a simple deletion
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  EB="$CONS2/err-m13b-a.txt"
  bash "$M13B" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       "touched-shippable green-one" cwd-probe >/dev/null 2>"$EB"
  grep -qF "not a fixture NAME" "$EB" || s13b=$((s13b+1))
  # (b) ...and a GENUINE retirement is now relabelled, which is the damage
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  EC="$CONS2/err-m13b-b.txt"
  bash "$M13B" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       touched-deleted green-one cwd-probe touched-shippable >/dev/null 2>"$EC"
  grep -qF "upstream deleted the driver" "$EC" && s13b=$((s13b+1))
  if [ "$s13b" -eq 0 ]; then
    ok "MUTATION — a TREE probe in place of the name-shape test still names the joined argument, and SILENTLY relabels a real retirement as an unparsable name: Part 15 is what catches that, and Part 15b alone would not"
  else
    bad "MUTATION — the tree-probe revert did not produce the expected split ($s13b of 2 arms disagreed). Either Part 15b is not reading the new row, or a real retirement is no longer distinguishable, and the fix's discriminator is untested"
  fi
else
  bad "FIXTURE ERROR: the name-shape probe anchor no longer occurs exactly once in the runner — Part 15b's discriminator is untested"
fi
}
sec_NCTL() {
NSIG_CTL="$(nsig "$CTL")"
if [ "$NSIG_CTL" = "$NSIG_OK" ]; then
  ok "CONTROL: the unmutated copy reads the all-correct normalisation vector $NSIG_OK — the eight verdicts below are their edits, not a copy that died"
else
  bad "FIXTURE ERROR: the unmutated copy reads '$NSIG_CTL', not '$NSIG_OK'. Every mutant vector below would be scored against a harness that is already wrong, and a copy emitting nothing reads as eight kills at once"
fi
}
sec_N1() {
# --- MUTANT N1: the CHARACTER CLASS replaced by a GLOB taking the basename ---------------------
# The adversary's B1, and it is PC-S310 restored in the ACQUITTING direction. `core/fixtures/*`
# matches a space and a newline, so a joined list of fifteen names collapses to its LAST one, ONE
# fixture runs, the suite is green and step 2 reads the whole slice as covered. It is the mutation
# an author reaches for first because it is shorter than the class, and three of the four mutants
# the contract predicted were already green on this suite before the arms above were written.
N1="$MUTDIR/n1-glob-takes-the-basename.sh"
if mkmutant "$N1" '  _nb="$_na"
  _nc=""
  case "$_na" in
    core/fixtures/*)  _nc="${_na%/}"; _nc="${_nc#core/fixtures/}" ;;
    tests/fixtures/*) _nc="${_na%/}"; _nc="${_nc#tests/fixtures/}" ;;
  esac
  # The remainder is a NAME when it is non-empty and carries no slash and no whitespace — a
  # negation over what cannot be in one directory name, never an ASCII enumeration of what may.
  # `*[!A-Za-z0-9._-]*` refused `core/fixtures/café`, which the coverage join names under its raw
  # spelling, so a correct path-form set was convicted as unparsable. `.` and `..` carry no
  # slash and name no directory, so they are refused as non-names too.
  case "$_nc" in
    ""|.|..|*/*|*[[:space:]]*) ;;
    *) _nb="$_nc" ;;
  esac' \
                  '  case "$_na" in
    core/fixtures/*|tests/fixtures/*) _nb="${_na%/}"; _nb="${_nb##*/}" ;;
    *) _nb="$_na" ;;
  esac'; then
  n_score N1 "$N1" "0-1-3-1-1-0-0-1-1-0-0" \
    "Part 15b's path-form seed and Part 15c's newline one OWN this kill." \
    "a \`case core/fixtures/*)\` glob taking the basename collapses a joined list to its last name and runs ONE fixture green"
else
  bad "FIXTURE ERROR: the normalisation's character-class anchor no longer occurs exactly once in the runner — the joined-list acquittal is untested, and it is the direction that reports a green suite over half a slice"
fi
}
sec_N2() {
# --- MUTANT N2: only the `core/` prefix stripped -----------------------------------------------
# `core/fixtures/green-one` becomes `fixtures/green-one`, which still carries a slash and is still
# refused — with a row that now names a REWRITTEN argument the operator never passed.
N2="$MUTDIR/n2-strips-only-core.sh"
if mkmutant "$N2" '  _nb="$_na"
  _nc=""
  case "$_na" in
    core/fixtures/*)  _nc="${_na%/}"; _nc="${_nc#core/fixtures/}" ;;
    tests/fixtures/*) _nc="${_na%/}"; _nc="${_nc#tests/fixtures/}" ;;
  esac
  # The remainder is a NAME when it is non-empty and carries no slash and no whitespace — a
  # negation over what cannot be in one directory name, never an ASCII enumeration of what may.
  # `*[!A-Za-z0-9._-]*` refused `core/fixtures/café`, which the coverage join names under its raw
  # spelling, so a correct path-form set was convicted as unparsable. `.` and `..` carry no
  # slash and name no directory, so they are refused as non-names too.
  case "$_nc" in
    ""|.|..|*/*|*[[:space:]]*) ;;
    *) _nb="$_nc" ;;
  esac' \
                  '  _nb="${_na#core/}"'; then
  n_score N2 "$N2" "2-0-3-0-0-0-0-1-1-0-0" \
    "Part 15c2's complete-set run and Part 15c3's trailing-slash form OWN this kill." \
    "stripping only the \`core/\` prefix leaves \`fixtures/<name>\`, which is still a slash away from the name"
else
  bad "FIXTURE ERROR: the normalisation's character-class anchor no longer occurs exactly once in the runner — a prefix strip that stops one component short is untested"
fi
}
sec_N3() {
# --- MUTANT N3: only the `core/fixtures/` prefix accepted --------------------------------------
# The consumer-layout spelling is the half this one deletes, and `install.sh` splits exactly there:
# what is `core/fixtures/<name>` here is `tests/fixtures/<name>` on a consumer, so an operator
# reading the path off their own tree passes the form this copy refuses.
N3="$MUTDIR/n3-core-prefix-only.sh"
if mkmutant "$N3" '    tests/fixtures/*) _nc="${_na%/}"; _nc="${_nc#tests/fixtures/}" ;;
' '' ; then
  n_score N3 "$N3" "0-1-3-1-0-1-1-1-1-1-1" \
    "Part 15c3's tests/fixtures form OWNS this kill." \
    "accepting only the \`core/fixtures/\` prefix leaves the consumer-layout spelling refused"
else
  bad "FIXTURE ERROR: the tests/fixtures prefix arm no longer occurs exactly once in the runner — the second accepted prefix is untested, and it is the one a consumer's own tree spells"
fi
}
sec_N4() {
# --- MUTANT N4: the trailing slash never stripped ----------------------------------------------
# Step 2's derived term ends in a slash. Without the `%/` the remainder is `<name>/`, which fails
# the character class and falls through to the refusal — so the ONE form the step actually
# produces is the one form this copy cannot take.
N4="$MUTDIR/n4-no-trailing-slash-strip.sh"
if mkmutant2 "$N4" '    core/fixtures/*)  _nc="${_na%/}"; _nc="${_nc#core/fixtures/}" ;;' \
                   '    core/fixtures/*)  _nc="${_na#core/fixtures/}" ;;' \
                   '    tests/fixtures/*) _nc="${_na%/}"; _nc="${_nc#tests/fixtures/}" ;;' \
                   '    tests/fixtures/*) _nc="${_na#tests/fixtures/}" ;;'; then
  n_score N4 "$N4" "0-1-3-0-1-1-1-1-1-1-1" \
    "Part 15c3's trailing-slash form OWNS this kill." \
    "leaving the trailing slash on refuses \`core/fixtures/<name>/\`, which is the exact term step 2 derives"
else
  bad "FIXTURE ERROR: one of the two trailing-slash strips no longer occurs exactly once in the runner — the form step 2 spells is untested"
fi
}
sec_N5() {
  b_N5
# --- MUTANT N5: the block sited BELOW the arms that read the positionals ------------------------
# The siting mutant. MEASURED, rather than predicted: the refusal that fires is the
# OVER-completeness arm's — `self-update-fixtures: the named set contains fixtures no consumer can
# run`, with the path-form arguments convicted as unparsable NAMES — because that arm is the FIRST
# reader of `$@` below the block's correct home, sitting above the coverage join rather than below
# it. The prediction when this was written was the join's `case " $* " in *" ${d} "*` membership
# test; it is the SECOND reader, and it never gets the chance. Either way a wholly correct
# path-form set is refused and never reaches the loop, which is the property Part 15c2 asserts.
#
# N5 AND N7 SHARE A VECTOR, and that is reported rather than engineered away. Both leave `$@` in
# the path form for every reader above the fixture loop, so the same arm convicts both on the same
# input — they are one class reached two ways, not two subjects. What separates them is the repair:
# N5's block is in the wrong PLACE and N7's is in the wrong SCOPE.
if [ -s "$N5" ] && ! cmp -s "$RUNNER" "$N5"; then
  n_score N5 "$N5" "2-0-0-0-0-1-1-1-1-1-1" \
    "Part 15c2's rc=0 and its section-name equality OWN this kill." \
    "sited below the arms that read the positionals, a COMPLETE path-form set is convicted by the over-completeness probe and never reaches the loop"
else
  bad "FIXTURE ERROR: the normalisation block could not be relocated below the coverage join — an anchor has moved, or the relocated copy is byte-identical to the original, and the siting Part 15c2 asserts proves nothing"
fi
}
sec_N6() {
# --- MUTANT N6: the positionals rewritten by `set -- $list` ------------------------------------
# The adversary's B2. Word-splitting the rebuilt list is the very absence the joined-list refusal
# detects, so this copy deletes that arm from INSIDE the fix — and `set -f` does not save it,
# because the split is IFS and not glob. It is the idiom a shell author writes without thinking.
N6="$MUTDIR/n6-set-dash-dash-word-splits.sh"
if mkmutant2 "$N6" '_norm_n=$#
_norm_i=0
while [ "$_norm_i" -lt "$_norm_n" ]; do
  _na="$1"; shift' \
                   '_norm_list=""
for _na in "$@"; do' \
                   '  set -- "$@" "$_nb"
  _norm_i=$((_norm_i + 1))
done' \
                   '  _norm_list="$_norm_list $_nb"
done
set -f; set -- $_norm_list; set +f'; then
  n_score N6 "$N6" "0-1-3-1-1-0-0-1-1-1-1" \
    "Part 15b's and Part 15c's joined-list seeds OWN this kill, in both spellings." \
    "rebuilding the positionals with \`set -- \$list\` word-splits them and deletes the joined-list refusal"
else
  bad "FIXTURE ERROR: the rotation's head or tail no longer occurs exactly once in the runner — the one rewrite idiom that silently re-opens PC-S310 is untested"
fi
}
sec_N7() {
  b_N5
# --- MUTANT N7: the rewrite made LOOP-LOCAL ----------------------------------------------------
# The adversary's D6. `$@` is left alone and only the fixture loop's own variable is normalised,
# so every reader above the loop still sees the path form. It shares N5's vector for that reason —
# see N5's header — and the arm that convicts it is the same over-completeness probe. Where the
# two would diverge is a tree the over-arm acquits: there the loop runs, but the log's section
# headings carry whatever `$@` holds, so a bare-name and a path-form run of the same set produce
# DIFFERENT section lists while reporting IDENTICAL summary counts. That is why Part 15c2 compares
# the section NAMES and not the totals.
N7="$MUTDIR/n7-loop-local-rewrite.sh"
NBLK_A="$NBLK_A" NBLK_B="$NBLK_B" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
a, b = s.index(os.environ["NBLK_A"]), s.index(os.environ["NBLK_B"])
t = s[:a] + s[b:]
old = "for name in \"$@\"; do\n  dir=\"$CONSUMER/$FX_ROOT/$name\"\n"
if t.count(old) != 1: sys.exit(3)
new = ("for name in \"$@\"; do\n"
       "  case \"$name\" in\n"
       "    core/fixtures/*|tests/fixtures/*) name=\"${name%/}\"; name=\"${name##*/}\" ;;\n"
       "  esac\n"
       "  dir=\"$CONSUMER/$FX_ROOT/$name\"\n")
open(sys.argv[2], "w").write(t.replace(old, new, 1))' "$RUNNER" "$N7" 2>/dev/null
if [ -s "$N7" ] && ! cmp -s "$RUNNER" "$N7" && ! cmp -s "$N5" "$N7"; then
  n_score N7 "$N7" "2-0-0-0-0-1-1-1-1-1-1" \
    "Part 15c2's rc=0 and its section-NAME equality OWN this kill." \
    "normalising only the loop's own variable leaves \$@ in the path form for every reader above the loop"
else
  bad "FIXTURE ERROR: the loop-local rewrite could not be built — the fixture loop's head has moved, or the copy is byte-identical to the relocation mutant, and the arm that reads section NAMES rather than counts proves nothing"
fi
}
sec_N8() {
  b_N5
# --- MUTANT N8: the block sited BEFORE `$LOG` EXISTS -------------------------------------------
# The adversary's B4, and it is the one that fails LOUDLY — but only on an argument that gets
# rewritten. `$LOG` is assigned below the usage block, so a normalisation hoisted above it dies
# `LOG: unbound variable` at rc=1 the first time it logs a rewrite, and is perfectly quiet on a
# bare-name set. Every existing arm in this file passes bare names and is green on this copy.
N8="$MUTDIR/n8-sited-before-the-log-exists.sh"
NBLK_A="$NBLK_A" NBLK_B="$NBLK_B" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
a, b = s.index(os.environ["NBLK_A"]), s.index(os.environ["NBLK_B"])
blk, t = s[a:b], s[:a] + s[b:]
anchor = "TS=\"$(date -u +%Y%m%dT%H%M%SZ)\"\n"
if t.count(anchor) != 1: sys.exit(3)
c = t.index(anchor)
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$N8" 2>/dev/null
if [ -s "$N8" ] && ! cmp -s "$RUNNER" "$N8" && ! cmp -s "$N5" "$N8"; then
  n_score N8 "$N8" "1-0-0-0-0-1-1-1-1-1-1" \
    "Part 15c2's rc=0 OWNS this kill — every bare-name arm in this file is green on this copy." \
    "sited above the line that assigns \$LOG, the first rewrite dies on an unbound variable at rc=1"
else
  bad "FIXTURE ERROR: the normalisation block could not be relocated above the \$LOG assignment — an anchor has moved, or the copy is byte-identical to the other relocation, and the window the block must sit inside is untested"
fi
}
sec_M14() {
# --- MUTANT 14: the .dist-only probe WIDENED to convict every shippable directory -------------
# The mutation the other seven cannot produce. Every one of them makes the arm say LESS, and an
# arm that says less is caught by a set equality missing a member; this one makes it say MORE,
# and Part 16 is the only arm whose subject that is. It was the last arm here with no mutant at
# all, which is the state `fixture-mutants.md` names: an arm asserting that nothing was said
# passes against a subject that says nothing, and only a widening copy tells the two apart.
M14="$MUTDIR/m14-distonly-probe-widened.sh"
if mkmutant "$M14" '  elif [ "$_do_rc" -eq 0 ]; then' \
                   '  elif [ "$_do_rc" -eq 128 ]; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M14" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       green-one cwd-probe touched-named touched-shippable >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] \
     && [ "$(uns_set "$(newest_log2)")" = "cwd-probe,green-one,touched-named,touched-shippable," ]; then
    ok "MUTATION — with the .dist-only probe inverted the arm convicts every directory a consumer CAN run and wedges the self-update: Part 16 is what catches that"
  else
    bad "MUTATION — the .dist-only probe was widened to convict everything and the wholly shippable set was still accepted (rc=$rc, refused '$(uns_set "$(newest_log2)")'). Part 16 asserts an absence no run can produce, so it would pass against a subject that says nothing"
  fi
else
  bad "FIXTURE ERROR: the .dist-only probe anchor no longer occurs exactly once in the runner — Part 16 proves nothing"
fi
}
sec_MG1() {
# --- MUTANTS G1 to G4: the GATE-RECORD requirement --------------------------------------------
# Keyed on LOCATION and on observable BEHAVIOUR. Each is scored on the input of the ONE part
# that owns it, and the scoring runs in `$GCONS` — the only consumer tree with no acquitting
# record seeded into it.
#   G1  the requirement excised outright      Part G1
#   G2  the shas compared as STRINGS          Part G3 (the record's header is resolved; the
#                                             argument is a tag, so a string compare refuses
#                                             the right range and the arm reads it as a refusal
#                                             for the wrong reason — see the two-run scoring)
#   G3  the verdict check accepts DEFER       Part G2
#   G4  the candidates ordered OLDEST first   Part G5

# --- MUTANT G1: the whole gate-record requirement excised ------------------------------------
# Excised rather than edited: a partial revert leaves whichever layer was not touched, and this
# refusal has two (the peel and the record match). The named set is legitimate for this range, so
# the copy runs the fixtures and reports a GREEN suite over a cycle nothing authorised — exactly
# the state step 2 was in before this arm existed.
MG1="$MUTDIR/mg1-gaterecord-deleted.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- THE GATE RECORD"), s.index("# --- The OVER-completeness arm")
open(sys.argv[2], "w").write(s[:a] + s[b:])' "$RUNNER" "$MG1" 2>/dev/null
if [ -s "$MG1" ] && ! cmp -s "$RUNNER" "$MG1"; then
  gin_restore
  gin_seed "$SR_NO_INPUTS" 190
  bash "$MG1" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "GATE-RECORD:" "$LM"; then
    ok "MUTATION — with the gate-record requirement removed a record that names NOTHING authorises a green suite, and so would no record at all: Parts G1 and G7 are what catch that"
  else
    bad "MUTATION — the gate-record requirement was removed and the cycle was still refused (rc=$rc). Part G1's verdict is coming from somewhere else and the requirement is untested"
  fi
else
  bad "FIXTURE ERROR: the gate-record block could not be excised — its start or end anchor has moved, and Parts G1 to G5 prove nothing"
fi
}
sec_MG2() {
# --- MUTANT G2: the shas compared as STRINGS rather than resolved ------------------------------
# The implementation a naive seed cannot tell from the right one. Both sides are compared as the
# CALLER SPELLED them, so a record written for `theirs-tag` matches an argument of `theirs-tag`
# and everything looks fine — until the two spellings differ, which is the normal case, because
# step 2 passes a ref and the gate records what it resolved to.
#
# SCORED IN TWO RUNS, because a mutant that refuses EVERYTHING would satisfy a one-run arm keyed
# on a refusal. The first run is the legitimate range Part G4's shape uses, spelled as a TAG:
# correct code accepts it, the mutant refuses. The second is Part G3's wrong-range input, which
# BOTH implementations must refuse — so the kill is the pair, and a copy that simply always
# refuses fails the pair rather than scoring it.
MG2="$MUTDIR/mg2-sha-compared-as-string.sh"
if mkmutant2 "$MG2" 'gr_base="$(git -C "$DIST" rev-parse "${BASE}^{commit}" 2>/dev/null)"' \
                    'gr_base="$BASE"' \
                    'gr_theirs="$(git -C "$DIST" rev-parse "${THEIRS}^{commit}" 2>/dev/null)"' \
                    'gr_theirs="$THEIRS"'; then
  # A record for D_BASE..theirs-tag, written with RESOLVED shas exactly as the gate writes it.
  gin_restore
  gin_seed_clean 191
  bash "$MG2" "$DIST" "$D_BASE" theirs-tag "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  mg2_tag=$?
  mg2_tag_ref=0
  bash "$RUNNER" "$DIST" "$D_BASE" theirs-tag "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1 || mg2_tag_ref=1
  # ...and a record for a DIFFERENT range, which both implementations must refuse.
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 192 >/dev/null
  bash "$MG2" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  mg2_wrong=$?
  if [ "$mg2_tag" -eq 2 ] && [ "$mg2_tag_ref" -eq 0 ] && [ "$mg2_wrong" -eq 2 ]; then
    ok "MUTATION — comparing the ARGUMENT STRINGS instead of the resolved shas refuses a record written for this very range one minute earlier (tag ref: correct=accepted, mutant=exit 2), while still refusing the wrong range: Part G3's sha comparison is what catches that"
  else
    bad "MUTATION — the sha comparison was replaced by a string comparison and the fixture did not see it (mutant on the tag ref rc=$mg2_tag expected 2, unmutated rc=$mg2_tag_ref expected 0, wrong-range rc=$mg2_wrong expected 2). Step 2 passes a REF and the gate records a SHA, so a string comparison wedges every self-update whose theirs is not spelled as a raw sha"
  fi
else
  bad "FIXTURE ERROR: one of the two rev-parse anchors no longer occurs exactly once in the runner — the resolved-sha comparison is untested"
fi
}
sec_MG3() {
# --- MUTANT G3: the verdict check accepts DEFER ------------------------------------------------
# The presence-only reader: a record for the right range is enough and its verdict is never read.
# It passes Parts G1 and G3 — there is no record and a wrong-range record in those — and the only
# thing it gets wrong is the one case the gate explicitly refused.
MG3="$MUTDIR/mg3-verdict-unread.sh"
if mkmutant "$MG3" '    if [ "$gr_verdict" != "OK" ]; then' \
                   '    if [ -z "$gr_verdict" ]; then'; then
  gin_restore
  SR_INPUTS="$(sr_required_inputs "$GCONS")" gin_seed_defer 193
  bash "$MG3" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM"; then
    ok "MUTATION — with the verdict unread a DEFER record authorises the cycle, because a record EXISTS: Part G2 is what catches that"
  else
    bad "MUTATION — the verdict check was reduced to a presence check and the DEFER record still stopped the run (rc=$rc). Part G2 is being answered by the sha match, so the verdict itself is untested"
  fi
else
  bad "FIXTURE ERROR: the verdict-check anchor no longer occurs exactly once in the runner — Part G2 proves nothing"
fi
}
sec_MG4() {
# --- MUTANT G4: the newest-record selection picks the OLDEST -----------------------------------
# `sort -r` becomes `sort`. Every other part here seeds exactly one matching record, so this copy
# is correct for all of them; the only input that separates the two orderings is Part G5's pair.
MG4="$MUTDIR/mg4-oldest-record-wins.sh"
if mkmutant "$MG4" 'gr_cands="$(ls "$OUT_DIR"/self-update-gate-*.md 2>/dev/null | sort -r)"' \
                   'gr_cands="$(ls "$OUT_DIR"/self-update-gate-*.md 2>/dev/null | sort)"'; then
  gin_restore
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK    100 >/dev/null
  SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" DEFER 900 >/dev/null
  bash "$MG4" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM"; then
    ok "MUTATION — ordering the candidates oldest-first revives an OK the gate has already superseded with a DEFER: Part G5 is what catches that"
  else
    bad "MUTATION — the record ordering was reversed and Part G5 did not see it (rc=$rc). Where every part seeds one matching record the two orderings are the same program, and the arm asserts nothing"
  fi
else
  bad "FIXTURE ERROR: the record-ordering anchor no longer occurs exactly once in the runner — Part G5 proves nothing"
fi
}
sec_MG5() {
  b_MG5
# --- MUTANTS G5 to G9: the corrected input join and the re-keyed tolerance ---------------------
#   G5  the whole input comparison removed        Part G8   (a third hand walks in)
#   G6  the inputs COUNTED, never compared        Part G8   — the shape that reads as a check
#   G7  the THEIRS acceptance removed             Part G6   (the normal flow refused)
#   G8  the PRE-WRITTEN arm removed               Part G14  (a late gate accepted)
#   G9  the tolerance keyed on emptiness alone    Part G13a (deleted records acquitted)
#
# G7 and G8 are the pair the v2 correction turns on, and they pull in OPPOSITE directions: G7
# makes the reader stricter (it refuses the slice) and G8 makes it laxer (it accepts a verdict
# taken after the slice). A battery carrying only one of them would certify whichever error its
# author was not thinking about.

# --- MUTANT G5: the input comparison removed ---------------------------------------------------
# The whole `else` branch under the OK verdict, so a matching range and an OK verdict are the
# entire requirement again. Scored on Part G8's input: the record is real, its verdict is OK, and
# a third hand has put content in a gating script that this pull does not ship.
if [ -s "$MG5" ] && ! cmp -s "$RUNNER" "$MG5" && bash -n "$MG5" 2>/dev/null; then
  gin_restore
  gin_seed_clean 300
  printf '%s\n' 'neither the recorded content nor what the pull ships' > "$GCONS/$GIN_CHANGED"
  bash "$MG5" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "GATE-RECORD:" "$LM"; then
    ok "MUTATION — with the input comparison removed a verdict taken against a DIFFERENT consumer tree authorises this run: Part G8 is what catches that"
  else
    bad "MUTATION — the input comparison was removed and the third-hand edit was still refused (rc=$rc). Part G8's verdict is coming from the range match, so the tree binding is untested"
  fi
else
  bad "FIXTURE ERROR: the input-comparison block could not be excised or the result does not parse — an anchor has moved, and Parts G6 to G17 prove nothing"
fi
}
sec_MG6() {
  b_MG5
# --- MUTANT G6: the inputs COUNTED, never compared ---------------------------------------------
# The shape that looks exactly like a working check and is the one this repo keeps shipping: the
# record's input lines are counted, the count is asserted non-zero, and no byte of the consumer
# is ever read. It passes Part G7 — a record with no inputs still counts zero — and only an arm
# that MOVES a file can tell the two apart.
MG6="$MUTDIR/mg6-inputs-counted-not-compared.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a = s.index("    else\n      # THE INPUTS THE VERDICT READ")
b = s.index("  elif [ \"$gr_seen\" -eq 0 ]; then")
body = """    else
      gr_n_in="$(grep -c "^# input: " "$GATE_REC")" || gr_n_in=0
      gr_moved=""; gr_required=""; gr_prewritten=""
      if [ "$gr_n_in" -eq 0 ]; then
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") names NO input files"
      fi
    fi
"""
open(sys.argv[2], "w").write(s[:a] + body + s[b:])' "$RUNNER" "$MG6" 2>/dev/null
if [ -s "$MG6" ] && ! cmp -s "$RUNNER" "$MG6" && ! cmp -s "$MG5" "$MG6" && bash -n "$MG6" 2>/dev/null; then
  # BOTH DIRECTIONS, because a copy that refuses everything would satisfy a one-run arm: the
  # no-input record must still be refused (so the copy RAN and its count arm works) and the
  # third-hand edit must be accepted (so it never looked at the tree).
  gin_restore
  gin_seed "$SR_NO_INPUTS" 310
  bash "$MG6" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  mg6_empty=$?
  gin_seed_clean 311
  printf '%s\n' 'neither the recorded content nor what the pull ships' > "$GCONS/$GIN_CHANGED"
  bash "$MG6" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  mg6_moved=$?
  gin_restore
  if [ "$mg6_empty" -eq 2 ] && [ "$mg6_moved" -eq 0 ]; then
    ok "MUTATION — COUNTING the input lines instead of comparing them still refuses an empty record (so the copy ran) and accepts a tree a third hand has edited: Part G8 is what catches that"
  else
    bad "MUTATION — the inputs were counted rather than compared and the fixture did not see it (empty-record rc=$mg6_empty expected 2, third-hand rc=$mg6_moved expected 0). A count is true either way, and an arm asserting only that the record names SOMETHING passes against a check that never opens a file"
  fi
else
  bad "FIXTURE ERROR: the count-only mutant could not be built or does not parse — Part G8's comparison is untested"
fi
}
sec_MG7() {
# --- MUTANT G7: the THEIRS acceptance removed — the SHIPPED DEFECT, rebuilt --------------------
# This is the runner as it was actually shipped: an input that moved is refused, full stop. It
# refuses the legitimate flow, and Part G6 is the only arm that can see it — every other arm here
# either moves nothing or moves something to content the pull does not ship, and this copy is
# CORRECT on all of them. That is why the arm had to model the real order rather than run the
# gate and the runner back to back.
MG7="$MUTDIR/mg7-theirs-acceptance-removed.sh"
if mkmutant "$MG7" '              elif [ -n "$gr_tb" ] && [ "$gr_now" = "$gr_tb" ]; then' \
                   '              elif false; then' ; then
  gin_restore
  gin_seed_clean 320
  gin_write_slice
  bash "$MG7" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 2 ] && [ -n "$LM" ] && grep -qF "GATE-RECORD: INPUT-MOVED $GIN_CHANGED" "$LM"; then
    ok "MUTATION — without the theirs-blob acceptance the runner refuses the slice the cycle itself just wrote, which is every legitimate self-update whose range changes a gating script: Part G6 is what catches that"
  else
    bad "MUTATION — the theirs acceptance was removed and the NORMAL order still ran (rc=$rc). Part G6 is not modelling step 2's real order — gate, WRITE, runner — and the shipped defect would pass this battery unchanged"
  fi
else
  bad "FIXTURE ERROR: the theirs-acceptance anchor no longer occurs exactly once in the runner — Part G6 proves nothing"
fi
}
sec_MG8() {
# --- MUTANT G8: the PRE-WRITTEN arm removed ----------------------------------------------------
# The opposite error to G7's, and no digest comparison can catch it: with this arm gone a gate run
# AFTER the write records digests that match the tree perfectly, so every other check here agrees
# and the OK means only that each file equals itself.
MG8="$MUTDIR/mg8-prewritten-arm-removed.sh"
if mkmutant "$MG8" '            if [ -n "$gr_tb" ] && [ -n "$gr_bb" ] && [ "$gr_bb" != "$gr_tb" ] \
               && [ "$gr_h" = "$gr_tb" ] && [ "$gr_sk" != "$gr_tb" ]; then' \
                   '            if false; then'; then
  gin_restore
  gin_write_slice
  gin_seed_clean 330
  bash "$MG8" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "GATE-RECORD:" "$LM"; then
    ok "MUTATION — with the PRE-WRITTEN arm gone a gate run AFTER the write authorises the cycle, and every digest in that record agrees with the tree: Part G14 is what catches that"
  else
    bad "MUTATION — the PRE-WRITTEN arm was removed and the late gate was still refused (rc=$rc). Nothing else here can see it — the record and the tree agree perfectly — so Part G14 is being answered by something that is not its subject"
  fi
else
  bad "FIXTURE ERROR: the PRE-WRITTEN anchor no longer occurs exactly once in the runner — Part G14 proves nothing"
fi
}
sec_MG8b() {
# --- MUTANT G8b: the split-stamp acquittal removed ---------------------------------------------
# G8 proves Part G14 by removing the arm the split-stamp exemption narrows. This is the mirror,
# and Part G14b is what it scores: with the exemption gone a legitimate split-stamp consumer is
# refused as PRE-WRITTEN on every invocation and its self-update can never land. Without this
# mutant, G14b would pass against a runner that reads no `skill-commit` at all and simply never
# enters the arm — an absence that reads exactly like the exemption working.
#
# THE ANCHOR IS THE CONJUNCT, NOT THE WHOLE CONDITION. Removing the condition is G8's mutation
# and would fail G14 as well; entangled failures mean one of the two arms is vacuous.
MG8B="$MUTDIR/mg8b-splitstamp-acquittal-removed.sh"
if mkmutant "$MG8B" ' && [ "$gr_sk" != "$gr_tb" ]; then' \
                    '; then'; then
  gin_restore
  gin_write_slice
  SR_SKILL_COMMIT="$(git -C "$DIST" rev-parse "${D_SPLIT}^{commit}" 2>/dev/null)" \
    gin_seed_clean 331
  bash "$MG8B" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 2 ] && [ -n "$LM" ] && grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LM"; then
    ok "MUTATION — without the split-stamp conjunct a consumer whose skill_commit already carried the blob is refused as PRE-WRITTEN, which wedges its self-update permanently: Part G14b is what catches that"
  else
    bad "MUTATION — the split-stamp conjunct was removed and the split-stamp world still ran (rc=$rc). Part G14b is being answered by something that is not its subject, so the exemption is unproven"
  fi
else
  bad "FIXTURE ERROR: the split-stamp conjunct no longer occurs exactly once in the runner — Part G14b proves nothing"
fi
}
sec_MG8c() {
# --- MUTANT G8c: the recorded sha compared as a STRING ------------------------------------------
# The peel removed, which is the defect the first cut of this fix shipped and Part G14d owns. An
# abbreviated recorded value then differs from the full sha as text, the equality guard never
# fires, and the post-write re-run is acquitted — a refusal defeated by a spelling rather than by
# a wrong decision. G14c stays green under this mutation (its seed writes a full sha), so this
# mutant and that arm are not entangled: only G14d can see it.
MG8C="$MUTDIR/mg8c-recorded-sha-unpeeled.sh"
if mkmutant "$MG8C" '      gr_rec_sk="$(git -C "$DIST" rev-parse -q --verify "${gr_rec_sk}^{commit}" 2>/dev/null || printf '"'"'%s'"'"' '"'"'-'"'"')"' \
                    '      gr_rec_sk="$gr_rec_sk"'; then
  gin_restore
  gin_write_slice
  SR_SKILL_COMMIT="$(git -C "$DIST" rev-parse --short=8 "${D_THEIRS}^{commit}" 2>/dev/null)" \
    gin_seed_clean 332
  bash "$MG8C" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -ne 2 ] || { [ -n "$LM" ] && ! grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LM"; }; then
    ok "MUTATION — with the recorded sha left unpeeled an ABBREVIATED value equal to theirs slips past the equality guard and acquits the post-write re-run: Part G14d is what catches that"
  else
    bad "MUTATION — the peel was removed and the abbreviated record was still refused (rc=$rc). Part G14d is being answered by something that is not its subject"
  fi
else
  bad "FIXTURE ERROR: the recorded-sha peel no longer occurs exactly once in the runner — Part G14d proves nothing"
fi
}
sec_MG9() {
# --- MUTANT G9: the tolerance keyed on EMPTINESS alone -----------------------------------------
# The exemption as it was first built: an empty record directory is the delivery pull. `rm -f
# self-update-gate-*.md` then reaches it at will, so the requirement is advisory for anyone
# willing to run one command — a mechanism defending its own defect.
MG9="$MUTDIR/mg9-tolerance-on-emptiness.sh"
if mkmutant "$MG9" '    if [ "$gr_tok_base" -gt 0 ]; then' \
                   '    if false; then'; then
  gin_restore
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  bash "$MG9" "$DIST" "$D_BASE_REC" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "NOT-REQUIRED" "$LM"; then
    ok "MUTATION — keyed on emptiness alone, deleting the records reaches the tolerance even where the gate at base DOES record: Part G13a is what catches that"
  else
    bad "MUTATION — the tolerance was keyed on the directory being empty and Part G13a did not fire (rc=$rc). Then \`rm -f\` is the whole bypass and nothing here would say so"
  fi
else
  bad "FIXTURE ERROR: the tolerance anchor no longer occurs exactly once in the runner — Part G13a proves nothing"
fi
}
sec_MG10() {
# --- MUTANTS G10 to G12: the digest column and the probe token --------------------------------
#   G10  the carried-content conjunct removed     Part G18  (all-zero forgery accepted)
#   G11  the set narrowed to the BASE blob        Part G21  (intermediate-blob consumer refused)
#   G12  the probe token back to GATE_REC_DIR     Part G22  (a declaring gate read as recording)
#
# G10 and G11 pull in opposite directions, exactly as G7 and G8 do: one makes the reader accept
# a record no gate produced, the other makes it refuse a consumer in a state this cycle itself
# creates. Either alone certifies whichever error its author was not thinking about.

# --- MUTANT G10: the carried-content conjunct removed -----------------------------------------
# ARM 2 back to a bare theirs-acceptance, which is what shipped. After the slice every gating
# script IS at theirs, so a record whose digests were never read off anything passes.
MG10="$MUTDIR/mg10-theirs-acceptance-unqualified.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a = s.index("                # ARM 2, and the second conjunct is what keeps the digest column")
b = s.index("              else\n                gr_moved=\"$gr_moved\n  $gr_p — recorded ${gr_h}, now ${gr_now:-<unhashable>}, which is neither")
open(sys.argv[2], "w").write(s[:a] + "                :\n" + s[b:])' "$RUNNER" "$MG10" 2>/dev/null
if [ -s "$MG10" ] && ! cmp -s "$RUNNER" "$MG10" && bash -n "$MG10" 2>/dev/null; then
  gin_restore
  gin_write_slice
  gin_seed "$(printf '# input: .githooks/pre-push\t%s\t-\n# input: %s\t%s\tcore/scripts/gate-changed.sh\n# input: %s\t%s\tcore/scripts/gate-steady.sh' \
    "$(git hash-object "$GCONS/.githooks/pre-push")" \
    "$GIN_CHANGED" "$GZERO" "$GIN_STEADY" "$GZERO")" 430
  bash "$MG10" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "GATE-RECORD:" "$LM"; then
    ok "MUTATION — with the carried-content conjunct gone an all-zero-digest record passes, because after the write every file IS at theirs: Part G18 is what catches that"
  else
    bad "MUTATION — the conjunct was removed and the forged record was still refused (rc=$rc). Part G18's verdict is coming from somewhere else, and the digest column's load-bearing half is untested"
  fi
else
  bad "FIXTURE ERROR: the carried-content conjunct could not be excised or the result does not parse — Part G18 proves nothing"
fi
}
sec_MG11() {
# --- MUTANT G11: the carried set narrowed to the BASE blob ------------------------------------
# The over-tight repair, and the one a hand reaching for the simplest fix writes. It refuses a
# consumer whose pre-write copy was an intermediate release's blob — the split-stamp state this
# cycle itself creates — while passing every other arm here, because the shared distribution has
# no intermediate commit touching a gating script.
MG11="$MUTDIR/mg11-carried-set-base-only.sh"
if mkmutant "$MG11" '                gr_hist="$(
                  { git -C "$DIST" rev-parse -q --verify "${BASE}:${gr_c}" 2>/dev/null
                    for gr_cm in $(git -C "$DIST" log --format=%H "${BASE}..${THEIRS}" -- "$gr_c" 2>/dev/null); do
                      git -C "$DIST" rev-parse -q --verify "${gr_cm}:${gr_c}" 2>/dev/null
                    done
                  } | sort -u
                )"' \
                    '                gr_hist="$(git -C "$DIST" rev-parse -q --verify "${BASE}:${gr_c}" 2>/dev/null)"'; then
  # Rebuilt here rather than reusing Part G21's, because that world is torn down with its own
  # temp dirs and a mutant reading a deleted tree is a mutant that never ran.
  M11K="$(mktemp -d)"
  mkdir -p "$M11K/_bmad-output/ai-dlc-update" "$M11K/tests/fixtures/probe" "$M11K/.githooks" "$M11K/scripts/ai-dlc"
  printf 'exit 0\n' > "$M11K/tests/fixtures/probe/run.sh"
  printf 'bash scripts/ai-dlc/gate-changed.sh\n' > "$M11K/.githooks/pre-push"
  IG show "${I_M}:core/scripts/gate-changed.sh" > "$M11K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
  printf '# base-sha: %s\n# theirs-sha: %s\n# input: .githooks/pre-push\t%s\t-\n# input: scripts/ai-dlc/gate-changed.sh\t%s\tcore/scripts/gate-changed.sh\n\n# verdict: OK\n' \
    "$I_B" "$I_T" "$(git hash-object "$M11K/.githooks/pre-push")" "$I_MB" \
    > "$M11K/_bmad-output/ai-dlc-update/self-update-gate-19700101T000000Z.md"
  IG show "${I_T}:core/scripts/gate-changed.sh" > "$M11K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
  bash "$MG11" "$I_D" "$I_B" "$I_T" "$M11K" probe >/dev/null 2>&1
  m11_int=$?
  # ...and the control: the SAME copy must still refuse the all-zero forgery, or the kill above
  # is a copy that refuses everything rather than one that narrowed the set.
  gin_restore
  gin_write_slice
  gin_seed "$(printf '# input: .githooks/pre-push\t%s\t-\n# input: %s\t%s\tcore/scripts/gate-changed.sh\n# input: %s\t%s\tcore/scripts/gate-steady.sh' \
    "$(git hash-object "$GCONS/.githooks/pre-push")" \
    "$GIN_CHANGED" "$GZERO" "$GIN_STEADY" "$GZERO")" 440
  bash "$MG11" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  m11_forge=$?
  gin_restore
  M11L="$(ls -t "$M11K"/_bmad-output/ai-dlc-update/self-update-fixtures-*.md 2>/dev/null | head -1)"
  if [ "$m11_int" -eq 2 ] && [ "$m11_forge" -eq 2 ] \
     && [ -n "$M11L" ] && grep -qF "INPUT-MOVED" "$M11L"; then
    ok "MUTATION — narrowing the carried set to the BASE blob refuses a consumer at an intermediate release's blob, while still refusing the forgery: Part G21 is what catches that"
  else
    bad "MUTATION — the carried set was narrowed to base-only and Part G21 did not see it (intermediate rc=$m11_int expected 2, forgery rc=$m11_forge expected 2). A split stamp is the normal state after any self-update, so this narrowing wedges those consumers and no arm here would say so"
  fi
  rm -rf "$M11K"
else
  bad "FIXTURE ERROR: the carried-set anchor no longer occurs exactly once in the runner — Part G21 proves nothing"
fi
}
sec_MG13() {
# --- MUTANT G13: the probe token back to the EXACT WRITE-SITE TEXT------------------------------------
# `/self-update-gate-$(date` scores correctly at both real revisions and is still wrong in the
# OTHER direction: a recording gate whose author moved the timestamp into its own variable scores
# 0, and a zero here is an acquittal — the records deleted on that consumer reach NOT-REQUIRED.
# The kill is the reflowed recording base reading NOT-REQUIRED; the control is the declaring base
# still reaching NOT-REQUIRED under the mutant, so the kill is an under-match and not a token
# that refuses everything.
MG13="$MUTDIR/mg13-token-is-the-exact-write-text.sh"
if mkmutant2 "$MG13" "gr_tok_base=\"\$(git -C \"\$DIST\" show \"\${BASE}:\${gr_gate_core}\" 2>/dev/null \\
                   | grep -v '^[[:space:]]*#' | grep -cE 'self-update-gate-.*\\.md')\" || gr_tok_base=0" \
                     "gr_tok_base=\"\$(git -C \"\$DIST\" show \"\${BASE}:\${gr_gate_core}\" 2>/dev/null \\
                   | grep -v '^[[:space:]]*#' | grep -cF '/self-update-gate-\$(date')\" || gr_tok_base=0" \
                     "gr_tok_theirs=\"\$(git -C \"\$DIST\" show \"\${THEIRS}:\${gr_gate_core}\" 2>/dev/null \\
                     | grep -v '^[[:space:]]*#' | grep -cE 'self-update-gate-.*\\.md')\" || gr_tok_theirs=0" \
                     "gr_tok_theirs=\"\$(git -C \"\$DIST\" show \"\${THEIRS}:\${gr_gate_core}\" 2>/dev/null \\
                     | grep -v '^[[:space:]]*#' | grep -cF '/self-update-gate-\$(date')\" || gr_tok_theirs=0"; then
  gin_restore
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  bash "$MG13" "$DIST" "$D_BASE_REFLOW" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  m13_reflow=$?
  M13L="$(newest_glog)"
  m13_waived=0
  { [ -n "$M13L" ] && grep -qF "GATE-RECORD: NOT-REQUIRED" "$M13L"; } && m13_waived=1
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  bash "$MG13" "$DIST" "$D_BASE_DECL" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  m13_decl=$?
  if [ "$m13_reflow" -eq 0 ] && [ "$m13_waived" -eq 1 ] && [ "$m13_decl" -eq 0 ]; then
    ok "MUTATION — keyed on the exact write-site text, a recording gate whose write was reflowed reads as NON-recording and deleted records reach NOT-REQUIRED (the declaring base still reaches it too, so this is an under-match): Part G23 is what catches that"
  else
    bad "MUTATION — the token was narrowed to the exact write-site text and the reflowed recording base was still refused (rc=$m13_reflow waived=$m13_waived decl-rc=$m13_decl). Part G23's verdict is coming from somewhere other than the token, and the acquitting direction is untested"
  fi
else
  bad "FIXTURE ERROR: the token anchor for MUTANT G13 no longer occurs exactly once in the runner — Part G23 proves nothing"
fi
}
sec_MG12() {
# --- MUTANT G12: the probe token back to the ASSIGNMENT ---------------------------------------
# `GATE_REC_DIR` scores correctly at both real revisions and is still wrong: it names an
# assignment, so a gate that declares the variable and never writes reads as a recording gate.
# Both directions, because a token that matched nothing would also "kill" Part G22 by making
# every base look non-recording — the recording base must still be seen.
MG12="$MUTDIR/mg12-token-names-an-assignment.sh"
if mkmutant2 "$MG12" "gr_tok_base=\"\$(git -C \"\$DIST\" show \"\${BASE}:\${gr_gate_core}\" 2>/dev/null \\
                   | grep -v '^[[:space:]]*#' | grep -cE 'self-update-gate-.*\\.md')\" || gr_tok_base=0" \
                     "gr_tok_base=\"\$(git -C \"\$DIST\" show \"\${BASE}:\${gr_gate_core}\" 2>/dev/null \\
                   | grep -v '^[[:space:]]*#' | grep -cF 'GATE_REC_DIR')\" || gr_tok_base=0" \
                     "gr_tok_theirs=\"\$(git -C \"\$DIST\" show \"\${THEIRS}:\${gr_gate_core}\" 2>/dev/null \\
                     | grep -v '^[[:space:]]*#' | grep -cE 'self-update-gate-.*\\.md')\" || gr_tok_theirs=0" \
                     "gr_tok_theirs=\"\$(git -C \"\$DIST\" show \"\${THEIRS}:\${gr_gate_core}\" 2>/dev/null \\
                     | grep -v '^[[:space:]]*#' | grep -cF 'GATE_REC_DIR')\" || gr_tok_theirs=0"; then
  gin_restore
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  bash "$MG12" "$DIST" "$D_BASE_DECL" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  m12_decl=$?
  M12L="$(newest_glog)"
  # SCORED BEFORE THE CLEAR, because the clear below deletes the very file this reads and a
  # grep over a missing path is a clean zero indistinguishable from a message that was absent.
  m12_missing=0
  { [ -n "$M12L" ] && grep -qF "GATE-RECORD: MISSING" "$M12L"; } && m12_missing=1
  # The control: the genuinely NON-recording base must still reach the tolerance under the
  # mutated token, or the kill is a token that matches nothing rather than one that over-matches.
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  bash "$MG12" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  m12_plain=$?
  if [ "$m12_decl" -eq 2 ] && [ "$m12_missing" -eq 1 ] && [ "$m12_plain" -eq 0 ]; then
    ok "MUTATION — keyed on the ASSIGNMENT, a gate that declares the record directory and never writes is read as recording, and the consumer is refused with a message saying its records were deleted: Part G22 is what catches that"
  else
    bad "MUTATION — the token was pointed back at the assignment and Part G22 did not fire (declaring-base rc=$m12_decl expected 2, MISSING line=$m12_missing expected 1, non-recording base rc=$m12_plain expected 0). Either the arm cannot see the over-match, or the mutated token matches nothing at all and the kill would be for the wrong reason"
  fi
else
  bad "FIXTURE ERROR: one of the two probe-token sites no longer occurs exactly once in the runner — Part G22 proves nothing"
fi
}
sec_P21CTL() {
  if [ "$P21_DISC" != "$P21_DISC_WANT" ]; then
    bad "FIXTURE BROKEN: Part 21's world does not discriminate ($P21_DISC, want $P21_DISC_WANT) -- this section cannot be scored"
    return 0
  fi
  # CONTROL: an unmutated copy beside its siblings gives both verdicts, so every kill below is the
  # mutation and not a copy that could not source lib.sh.
  p21_c="$(p21_over "$CTL") | $(p21_diff "$CTL")"
  if [ "$p21_c" = "rc=2 why=unconfirmed keeper=kept | rc=2 tag=unconfirmed subject=blobless" ]; then
    ok "Part 21 CONTROL: the unmutated copy in the mutant directory gives both refusals"
  else
    bad "Part 21 CONTROL: the unmutated copy read '$p21_c' — the mutant harness cannot run the runner, so the kills below prove nothing"
  fi
}
sec_M21a() {
  if [ "$P21_DISC" != "$P21_DISC_WANT" ]; then
    bad "FIXTURE BROKEN: Part 21's world does not discriminate ($P21_DISC, want $P21_DISC_WANT) -- this section cannot be scored"
    return 0
  fi
  # M21a: the over-arm's 125 branch made unreachable, so 125 falls to the old reading.
  M21A="$MUTDIR/m21a-overarm-125-ignored.sh"
  if mkmutant "$M21A" '  if [ "$_do_rc" -ne 0 ] && [ "$_do_rc" -ne 128 ]; then' '  if false; then'; then
    p21_g="$(p21_over "$M21A")"
    if [ "$p21_g" = "rc=2 why=deleted keeper=kept" ]; then
      ok "MUTATION 21a — with the over-arm's 125 branch gone the unreadable tree is reported as a driver upstream DELETED: Part 21a is what catches that"
    else
      bad "MUTATION 21a — the 125 branch was removed and Part 21a's input read '$p21_g', want 'rc=2 why=deleted keeper=kept'"
    fi
  else
    bad "FIXTURE ERROR: the over-arm's 125 anchor no longer occurs exactly once in the runner — Part 21a proves nothing"
  fi
}
sec_M21b() {
  if [ "$P21_DISC" != "$P21_DISC_WANT" ]; then
    bad "FIXTURE BROKEN: Part 21's world does not discriminate ($P21_DISC, want $P21_DISC_WANT) -- this section cannot be scored"
    return 0
  fi
  # M21b: the diff-side 125 branch falls through to the run.sh probe, as the old `&& continue` did.
  M21B="$MUTDIR/m21b-diffside-125-falls-through.sh"
  if mkmutant "$M21B" '    *)   cov_refused="$cov_refused $d"; continue ;;' '    *)   ;;'; then
    p21_g="$(p21_diff "$M21B")"
    if [ "$p21_g" = "rc=2 tag=uncovered subject=-" ]; then
      ok "MUTATION 21b — with the diff-side 125 branch falling through, the unreadable marker is read as 'not dist-only' and the directory is demanded of the slice: Part 21b is what catches that"
    else
      bad "MUTATION 21b — the diff-side 125 branch was removed and Part 21b's input read '$p21_g', want 'rc=2 tag=uncovered subject=-'"
    fi
  else
    bad "FIXTURE ERROR: the diff-side 125 anchor no longer occurs exactly once in the runner — Part 21b proves nothing"
  fi
}
sec_M22() {
M22="$MUTDIR/m22-stage-status-unread.sh"
if mkmutant "$M22" '  [ "$_rc" -eq 0 ] && return 0' '  return 0'; then
  p22_g="$(p22 "$M22" yes)"
  case "$p22_g" in
    *"staging=none fired=1")
      ok "MUTATION 22 — with su_stage's status unread the failed write is not refused and the run goes on to read a file that was never written ($p22_g): Part 22 is what catches that" ;;
    *)
      bad "MUTATION 22 — su_stage's status check was removed and Part 22 read '$p22_g', want staging=none with the stub fired" ;;
  esac
else
  bad "FIXTURE ERROR: su_stage's status anchor no longer occurs exactly once in the runner — Part 22 proves nothing"
fi
}
sec_QM() {
  q_consumer
# MUTANTS, each restoring ONE site. Q1's want under the diff mutant is the acquittal itself.
QM="$MUTDIR/q-unquoted-diff.sh"
if mkmutant "$QM" 'cov_raw="$(git -C "$DIST" -c core.quotePath=false diff --name-only' \
                  'cov_raw="$(git -C "$DIST" diff --name-only'; then
  got="$(q_run "$QM" utf8 green-one plain-touched)"
  if [ "$got" = "rc=0 cov= sec=green-one,plain-touched," ]; then
    ok "MUTATION — with the coverage diff C-quoted the slice omitting $QU runs green: Part Q1 is what catches that"
  else
    bad "MUTATION — the coverage diff was restored to the default quoting and Part Q1's run gave [$got], not the acquittal"
  fi
else
  bad "FIXTURE ERROR: the coverage diff anchor no longer occurs exactly once in the runner — Part Q1 proves nothing"
fi
}
sec_QM2() {
  q_consumer
QM2="$MUTDIR/q-ascii-name.sh"
if mkmutant "$QM2" '    ""|.|..|*/*|*[[:space:]]*) ;;' '    ""|*[!A-Za-z0-9._-]*) ;;'; then
  got="$(q_run "$QM2" c green-one plain-touched "core/fixtures/$QU/")"
  case "$got" in
    rc=2*) ok "MUTATION — with the ASCII name class the path form core/fixtures/$QU/ is refused under LC_ALL=C: Part Q3 (c) is what catches that" ;;
    *)     bad "MUTATION — the ASCII name class was restored and Part Q3's run gave [$got], not a refusal" ;;
  esac
else
  bad "FIXTURE ERROR: the name-shape anchor no longer occurs exactly once in the runner — Part Q3 proves nothing"
fi
}

# ------------------------------------------------------------------------- the shared read-only worlds
# Built ONCE, before any scorer copies anything: the filtered clone seeds its 030 record into the
# shared `$LOGDIR2`, and Part 21's world seeds its record into its consumer, so every private copy
# below carries both.
build_filt_world
build_i_world
build_p21_world
build_q_world
WORK="$(mktemp -d "${TMPDIR:-/tmp}/$NAME.XXXXXX")" || { echo "FIXTURE ERROR: cannot create a scratch directory" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"; sufl_tmp "$WORK"

# THE PRECONDITION, before anything is dispatched: every repository a section reads resolved, and
# the reconcile directory a scorer copies its siblings from is the one the runner sources. A
# section driven through a world that never built reads exactly like a mutant that survived.
N_REC="$(set -- "$RECONCILE"/*.sh; [ -e "$1" ] && echo "$#" || echo 0)"
if [ -n "$D_BASE" ] && [ -n "$D_THEIRS" ] && [ -n "$D_QUIET" ] && [ -n "$D_SHIP" ] && [ -n "$D_TREE" ] \
   && [ -n "$W_BASE" ] && [ -n "$W_THEIRS" ] && [ -n "$I_B" ] && [ -n "$I_M" ] && [ -n "$I_T" ] \
   && [ -n "$QD_B" ] && [ -n "$QD_T" ] && [ -f "$RECONCILE/lib.sh" ] && [ -f "$RECONCILE/preclassify.sh" ] \
   && [ "$N_REC" -ge 3 ]; then
  ok "MX-pre: every shared repository resolved its refs, and the runner's reconcile directory holds $N_REC sibling scripts to copy beside each mutant"
else
  bad "MX-pre: FIXTURE BROKEN -- a shared repository did not resolve its refs, or $RECONCILE lacks lib.sh/preclassify.sh ($N_REC .sh found). Every section verdict below is about a world that never built"
fi

# One scorer's private worlds: every tree a section WRITES, copied, and every global naming one
# rebound to the copy. Returns non-zero, naming what is missing, when a copy is incomplete.
scorer_world() { # <dir>
  local sw="$1" n
  mkdir -p "$sw" || return 1
  cp -Rp "$CONS2" "$sw/cons2" && CONS2="$sw/cons2" && LOGDIR2="$CONS2/_bmad-output/ai-dlc-update" || return 1
  cp -Rp "$GCONS" "$sw/gcons" && GCONS="$sw/gcons" && GLOG="$GCONS/_bmad-output/ai-dlc-update" || return 1
  cp -Rp "$P21C" "$sw/p21c" && P21C="$sw/p21c" && P21LOG="$P21C/_bmad-output/ai-dlc-update" || return 1
  p22_stub "$sw/stub" || return 1
  MUTDIR="$sw/mut"; mkdir -p "$MUTDIR" || return 1
  cp "$RECONCILE"/*.sh "$MUTDIR"/ 2>/dev/null
  CTL="$MUTDIR/control-unmutated.sh"; cp "$RUNNER" "$CTL" || return 1
  # A PARTIAL COPY OF THE SIBLINGS makes every mutant refuse before it runs and score as a kill.
  n="$(set -- "$MUTDIR"/*.sh; [ -e "$1" ] && echo "$#" || echo 0)"
  [ "$n" -eq "$((N_REC + 1))" ] || { echo "the reconcile copy holds $n scripts, want $((N_REC + 1))"; return 1; }
  # The G-parts' record directory exists in the unsplit fixture by the time its battery ran, because
  # every G-part seeds into it; here nothing has yet, so it is made, then asserted with the rest.
  mkdir -p "$GLOG" || return 1
  for n in "$P22S/mktemp" "$LOGDIR2" "$GLOG" "$P21LOG" "$CONS2/tests/fixtures/green-one/run.sh" \
           "$GCONS/.githooks/pre-push"; do
    [ -e "$n" ] || { echo "a private world is incomplete: $n is absent"; return 1; }
  done
}

POOL=8
SCORER_BOUND=900
VD="$WORK/verdicts"; mkdir -p "$VD" || { echo "FIXTURE ERROR: cannot create $VD" >&2; exit 2; }
IDX="$WORK/dispatch.tsv"; : > "$IDX"
NDISP=0

# One scorer: one section, in its own scratch, its lines captured, its verdict written once.
scorer() { # <id> <section>
  trap - EXIT
  local id="$1" sec="$2" sw why n f
  sw="$WORK/s-$id"
  WORK="$sw"
  # NOT inside `$( )`: every rebinding scorer_world makes would be lost to that subshell, and the
  # section would then drive the SHARED worlds -- or die on an unbound `$CTL` and leave no verdict.
  if scorer_world "$sw" > "$VD/$id.why" 2>&1; then
    "sec_$sec" > "$VD/$id.lines" 2> "$sw/stderr"
  else
    why="$(cat "$VD/$id.why" 2>/dev/null)"
    printf '  FAIL  %s: FIXTURE BROKEN -- %s\n' "$sec" "${why:-the private worlds could not be copied}" > "$VD/$id.lines"
  fi
  n="$(grep -c '' "$VD/$id.lines")" || n=0
  f="$(grep -c '^  FAIL  ' "$VD/$id.lines")" || f=0
  printf '%s\t%s\t%s\n' "$sec" "$n" "$f" > "$VD/$id.tmp" && mv "$VD/$id.tmp" "$VD/$id.v"
}
killtree() { # <pid>: stop it, take its children down first, then it
  local c
  kill -STOP "$1" 2>/dev/null
  for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done
  kill -9 "$1" 2>/dev/null
}
slot() { # <id> <section>: the scorer under its watchdog, then the completion sentinel
  trap - EXIT
  local id="$1" s t=0
  ( scorer "$@" ) &
  s=$!
  while kill -0 "$s" 2>/dev/null; do
    if [ "$t" -ge "$SCORER_BOUND" ]; then : > "$VD/$id.timeout"; killtree "$s"; break; fi
    sleep 1; t=$((t + 1))
  done
  wait "$s" 2>/dev/null
  : > "$VD/$id.done"
}
ndone() { set -- "$VD"/*.done; [ -e "$1" ] && echo "$#" || echo 0; }
dispatch() { # <section> <declared line count>
  local id
  while [ "$((NDISP - $(ndone)))" -ge "$POOL" ]; do sleep 1; done
  NDISP=$((NDISP + 1)); id="$(printf '%03d' "$NDISP")"
  printf '%s\t%s\t%s\n' "$id" "$1" "$2" >> "$IDX"
  slot "$id" "$1" &
}
# THE JUDGMENT, factored so it can be probed: no global is read or written but its arguments and
# SCORER_BOUND; it prints its one line and returns 0 (ok) or 1 (FAIL).
judge() { # <verdict-stem> <section> <declared line count>
  local stem="$1" label="$2" want="$3" lab n f
  if [ -e "$stem.timeout" ]; then printf '%s: TIMEOUT -- the scorer ran past %ss and was killed; no verdict\n' "$label" "$SCORER_BOUND"; return 1; fi
  if [ ! -f "$stem.v" ]; then printf '%s: NO VERDICT -- the scorer wrote nothing; a lost scorer is never a pass\n' "$label"; return 1; fi
  IFS='	' read -r lab n f < "$stem.v"
  if [ "$lab" != "$label" ]; then printf '%s: the verdict file carries the label [%s]\n' "$label" "$lab"; return 1; fi
  if [ "$n" != "$want" ]; then printf '%s: the section emitted %s line(s), declared %s -- a section that stopped early, or printed past its verdict, is not scored\n' "$label" "$n" "$want"; return 1; fi
  if [ "$f" != "0" ]; then printf '%s: the section emitted %s FAIL line(s)\n' "$label" "$f"; return 1; fi
  printf '%s: %s line(s), none a FAIL\n' "$label" "$n"; return 0
}

# ------------------------------------------------------------------------------ the dispatch
# The unsplit fixture's own serial order. CONTROL declares two lines, every other section one.
for _s in CONTROL M0 M15 M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13 M13b NCTL N1 N2 N3 N4 N5 N6 N7 N8 M14 MG1 MG2 MG3 MG4 MG5 MG6 MG7 MG8 MG8b MG8c MG9 MG10 MG11 MG13 MG12 P21CTL M21a M21b M22 QM QM2; do
  case "$_s" in CONTROL) dispatch "$_s" 2 ;; *) dispatch "$_s" 1 ;; esac
done

# ------------------------------------------------------------------------------ the reap
wait
nidx="$(grep -c . "$IDX")" || nidx=0
nd="$(ndone)"
if [ "$NDISP" -ge 2 ] && [ "$nidx" -eq "$NDISP" ] && [ "$nd" -eq "$NDISP" ]; then
  ok "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed"
else
  bad "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed -- a scorer was lost or never started"
fi
while IFS='	' read -r id label want; do
  if [ -f "$VD/$id.lines" ]; then
    while IFS= read -r _ln; do
      printf '%s\n' "$_ln"
      [ -n "$ROWS" ] && printf '%s\t%s\n' "$label" "$_ln" >> "$ROWS"
    done < "$VD/$id.lines"
  fi
  if line="$(judge "$VD/$id" "$label" "$want")"; then :; else bad "$line"; fi
done < "$IDX"

# THE JUDGMENT, PROBED ON A REAL VERDICT. M1's verdict file is copied aside and judged five ways
# against a scratch counter: its own declared count must PASS (else the probe proves nothing about
# a judge that always fails), and a wrong declared count, a TIMEOUT marker, a FAIL count of one --
# the direction a section that died quietly hides in -- and a deleted verdict must each FAIL.
pv="$(awk -F'\t' '$2 == "M1" { print $1; exit }' "$IDX")"
if [ -z "$pv" ] || [ ! -f "$VD/$pv.v" ]; then
  bad "MJ: FIXTURE BROKEN -- no M1 verdict file to probe the judgment with"
else
  pd="$(mktemp -d "$WORK/judge-probe.XXXXXX")" && cp "$VD/$pv.v" "$pd/p.v"
  red=0
  judge "$pd/p" M1 1 > /dev/null || red=$((red + 100))
  judge "$pd/p" M1 2 > /dev/null || red=$((red + 1))
  : > "$pd/p.timeout"
  judge "$pd/p" M1 1 > /dev/null || red=$((red + 1))
  rm -f "$pd/p.timeout"
  printf 'M1\t1\t1\n' > "$pd/p.v"
  judge "$pd/p" M1 1 > /dev/null || red=$((red + 1))
  rm -f "$pd/p.v"
  judge "$pd/p" M1 1 > /dev/null || red=$((red + 1))
  if [ "$red" -eq 4 ]; then
    ok "MJ: the judgment passes M1's real verdict against its declared count, and FAILS it against a wrong count, beside a TIMEOUT marker, with one FAIL line recorded, and with the verdict file deleted"
  else
    bad "MJ: the judgment probe scored $red (want 4: real+right ok; wrong count, timeout, one FAIL, deleted each red; +100 means the right count failed)"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
