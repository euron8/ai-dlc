#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# enforcement-map-sites — assert I8's site table cannot go quiet.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH. install.sh and reconcile/preclassify.sh's
# map_consumer() are two writers of the same consumer files, and they must agree on the
# destination or the consumer gets two copies at two paths — and the one the pull keeps
# fresh is not the one anything reads. I8 asserts that agreement. It has now been wrong
# three times, and the third is why this fixture exists:
#
#   fixtures     -> .claude/fixtures/     (dead; H1 reads tests/fixtures/)
#   ci-templates -> .claude/ci-templates/ (dead; workflows run from .github/workflows/)
#   git-hooks    -> .claude/git-hooks/    (dead; install.sh writes .githooks/)
#
# The first two were found and I8 gained a row for each. git-hooks was NOT found, and the
# reason is the whole lesson: I8's site list was HAND-MAINTAINED, so the check did not
# fail on core/git-hooks/ — it simply had no row for it, and a check that cannot fire
# reads exactly like a check that passed. v0.53.0's pre-push gate — shipped as the
# replacement for the deleted CI workflow — therefore reached the reference consumer at a
# path no runner, no `core.hooksPath`, and no script reads. That consumer had Actions
# disabled, so its ONLY automated gate could not fire, and nothing said so for two minors.
#
# So the assertions below are about the CHECK, not about today's table. A table with the
# right rows in it today proves nothing; what must hold is that a missing row, a wrong
# mapping, or a destination the installer never writes each FAILS. Assertion 0 exists
# because every negative assertion here would score a false pass against a validator that
# is simply broken and erroring for unrelated reasons.
#
# THE MUTANT MATRIX. Every mutant is named, and its row below names the arm that KILLS it
# (decides) and the arms it could plausibly co-trip but must leave green (twins). For a mutant
# scored through `vrun`, an arm is named by the site that scores it, so its deciding arm carries
# the mutant's own name. A plain run scores each mutant on its deciding arm and checks its twins
# against the SAME validator output, so a twin costs no validator run. The kill predicate of
# every row is single-sourced in `mx_sig`, and both the site and the twin check read it there.
# The matrix is re-measured whenever an arm or a mutant is added or changed, by the REMEASURE
# command below, run from the repo root. It scores every mutant against every arm of its own
# selected unit, and against every arm outside it by one full validator run of the same
# mutated tree, whose sorted FAIL: set must equal the selected run's.
# The cwd rows name every cell other than the deciding one as a twin: all four cells run on
# every push anyway, so each extra twin costs nothing, and each is a cwd that the mutation
# must leave reading the seed.
# MUTANT-MATRIX A01-m1 decides=A01-m1 twins=A03-m1
# MUTANT-MATRIX A02-m1 decides=A02-m1 twins=A08-m1
# MUTANT-MATRIX A03-m1 decides=A03-m1 twins=A02-m1
# MUTANT-MATRIX A04-m1 decides=A04-m1 twins=A05-m1
# MUTANT-MATRIX A05-m1 decides=A05-m1 twins=A04-m1
# MUTANT-MATRIX A06-m1 decides=A06-m1 twins=A07-m1
# MUTANT-MATRIX A07-m1 decides=A07-m1 twins=A06-m1
# MUTANT-MATRIX A08-m1 decides=A08-m1 twins=A02-m1
# MUTANT-MATRIX A09-m1 decides=A09-m1 twins=I16-vacuity
# MUTANT-MATRIX A11-m1 decides=A11-m1 twins=A12-m1
# MUTANT-MATRIX A12-m1 decides=A12-m1 twins=A11-m1
# MUTANT-MATRIX A13-m1 decides=A13-m1 twins=A11-m1
# MUTANT-MATRIX A14-m1 decides=A14-m1 twins=A15-m1
# MUTANT-MATRIX A15-m1 decides=A15-m1 twins=A14-m1
# MUTANT-MATRIX A16-m1 decides=A16-m1 twins=A17-m1
# MUTANT-MATRIX A17-m1 decides=A17-m1 twins=A16-m1
# MUTANT-MATRIX A18-m1 decides=A18-m1 twins=A19-m1
# MUTANT-MATRIX A19-m1 decides=A19-m1 twins=A18-m1
# MUTANT-MATRIX A20-m1 decides=A20-m1 twins=I26-span
# MUTANT-MATRIX A21-m1 decides=A21-m1 twins=A21-m2
# MUTANT-MATRIX A21-m2 decides=A21-m2 twins=A21-m1
# MUTANT-MATRIX A22-m1 decides=A22-m1 twins=A22-m2
# MUTANT-MATRIX A22-m2 decides=A22-m2 twins=A22-m1
# MUTANT-MATRIX A22-m3 decides=A22-m3 twins=A22-m4
# MUTANT-MATRIX A22-m4 decides=A22-m4 twins=A22-m3
# MUTANT-MATRIX A22-m5 decides=A22-m5 twins=A22-m4
# MUTANT-MATRIX A23-m1 decides=A23-m1 twins=A23-m2
# MUTANT-MATRIX A23-m2 decides=A23-m2 twins=A23-m1
# MUTANT-MATRIX A23-m3 decides=A23-m3 twins=A23-m1
# MUTANT-MATRIX A24-m1 decides=A24-m1 twins=A24-m2
# MUTANT-MATRIX A24-m2 decides=A24-m2 twins=A24-m1
# MUTANT-MATRIX A24-m3 decides=A24-m3 twins=A24-m2
# MUTANT-MATRIX A25-m1 decides=A25-m1 twins=A25-m5
# MUTANT-MATRIX A25-m2 decides=A25-m2 twins=A25-m1
# MUTANT-MATRIX A25-m3 decides=A25-m3 twins=A25-m1
# MUTANT-MATRIX A25-m4 decides=A25-m4 twins=A25-m5
# MUTANT-MATRIX A25-m5 decides=A25-m5 twins=A25-m1
# MUTANT-MATRIX A26-m1 decides=A26-m1 twins=A26-m2
# MUTANT-MATRIX A26-m2 decides=A26-m2 twins=A26-m1
# MUTANT-MATRIX A26-m3 decides=A26-m3 twins=A26-m1
# MUTANT-MATRIX A27-m1 decides=A27-m1 twins=A27-m2
# MUTANT-MATRIX A27-m2 decides=A27-m2 twins=A27-m1
# MUTANT-MATRIX A28-m1 decides=A28-m1 twins=A28-m2
# MUTANT-MATRIX A28-m2 decides=A28-m2 twins=A28-m1
# MUTANT-MATRIX A28-m3 decides=A28-m3 twins=A28-m2
# MUTANT-MATRIX A29-m1 decides=A29-m1 twins=A29-m3
# MUTANT-MATRIX A29-m2 decides=A29-m2 twins=A29-m3
# MUTANT-MATRIX A29-m3 decides=A29-m3 twins=A29-m2
# MUTANT-MATRIX A30-m1 decides=A30-m1 twins=A30-m2
# MUTANT-MATRIX A30-m2 decides=A30-m2 twins=A30-m1
# MUTANT-MATRIX A30-m3 decides=A30-m3 twins=A30-m1
# MUTANT-MATRIX A30-m4 decides=A30-m4 twins=A30-m3
# MUTANT-MATRIX A31-m1 decides=A31-m1 twins=A31-m2
# MUTANT-MATRIX A31-m2 decides=A31-m2 twins=A31-m3
# MUTANT-MATRIX A31-m3 decides=A31-m3 twins=A31-m2
# MUTANT-MATRIX A32-m1 decides=A32-m1 twins=A32-m2
# MUTANT-MATRIX A32-m2 decides=A32-m2 twins=A32-m1
# MUTANT-MATRIX A32-m3 decides=A32-m3 twins=A32-m1
# MUTANT-MATRIX A32-m4 decides=A32-m4 twins=A32-m5
# MUTANT-MATRIX A32-m5 decides=A32-m5 twins=A32-m4
# MUTANT-MATRIX A33-m1 decides=A33-m1 twins=A33-m2
# MUTANT-MATRIX A33-m2 decides=A33-m2 twins=A33-m3
# MUTANT-MATRIX A33-m3 decides=A33-m3 twins=A33-m2
# MUTANT-MATRIX A33-m4 decides=A33-m4 twins=A33-m2
# MUTANT-MATRIX A34-m1 decides=A34-m1 twins=A34-m2
# MUTANT-MATRIX A34-m2 decides=A34-m2 twins=A34-m3
# MUTANT-MATRIX A34-m3 decides=A34-m3 twins=A34-m2
# MUTANT-MATRIX A34-m4 decides=A34-m4 twins=A34-m3
# MUTANT-MATRIX A35-m1 decides=A35-m1 twins=A38-m1
# MUTANT-MATRIX A35-m2 decides=A35-m2 twins=A38-m1
# MUTANT-MATRIX A35-m3 decides=A35-m3 twins=A38-m1
# MUTANT-MATRIX A35-m4 decides=A35-m4 twins=A38-m1
# MUTANT-MATRIX A36-m1 decides=A36-m1 twins=A36-m2
# MUTANT-MATRIX A36-m2 decides=A36-m2 twins=A36-m1
# MUTANT-MATRIX A36-m3 decides=A36-m3 twins=A36-m2
# MUTANT-MATRIX A36-m4 decides=A36-m4 twins=A36-m1
# MUTANT-MATRIX A37-m1 decides=A37-m1 twins=A37-m2
# MUTANT-MATRIX A37-m2 decides=A37-m2 twins=A37-m1
# MUTANT-MATRIX A38-m1 decides=A38-m1 twins=A38-m2
# MUTANT-MATRIX A38-m2 decides=A38-m2 twins=A38-m1
# MUTANT-MATRIX A39-m1 decides=A39-m1 twins=A38-m1
# MUTANT-MATRIX A39-m2 decides=A39-m2 twins=A38-m1
# MUTANT-MATRIX A39-m3 decides=A39-m3 twins=A38-m1
# MUTANT-MATRIX A39-m4 decides=A39-m4 twins=A38-m1
# MUTANT-MATRIX A39-m5 decides=A39-m5 twins=A38-m1
# MUTANT-MATRIX I91-M1 decides=C1,C2,C3,C4 twins=- why=the mutation reverts the shared prologue every cell reads, so all four cells die by design (expected 0000) and none can stay green
# MUTANT-MATRIX I95-M1 decides=C1,C2,C3,C4 twins=- why=the mutation reverts the shared prologue every cell reads, so all four cells die by design (expected 0000) and none can stay green
# MUTANT-MATRIX I81-M2 decides=C1,C2,C3,C4 twins=- why=the deleted cd is the line every cell outside the seed relies on, so all four cells die by design (expected 0000) and none can stay green
# MUTANT-MATRIX I81-M3 decides=C3 twins=C1,C2,C4
# MUTANT-MATRIX I81-M4 decides=C4 twins=C1,C2,C3
# MUTANT-MATRIX I91-M5 decides=FULL twins=C1,C2,C3,C4
# MUTANT-MATRIX-DYNAMIC cwd_mutant why=cwd_mutant and cwd_full name each mutant as "$CW_ID-<tag>", so the names are composed at run time; every name they produce has its own row above
# MUTANT-MATRIX-CONTROL A10-c1 why=near-miss: an English 'core' and ai-dlc-update's by-design core/ paths must leave I16 silent, so nothing is mutated and there is no deciding arm
# MUTANT-MATRIX-CONTROL A29-c1 why=near-miss: an ordinary command piped into the reader must leave I54 silent, so nothing is mutated and there is no deciding arm
# MUTANT-MATRIX-CONTROL A35-c1 why=near-miss: the token only in a comment must leave I93 arm D silent while the run reaches its OK verdict, so there is no deciding arm
# MUTANT-MATRIX-CONTROL A39-c1 why=near-miss: the phrase only as a comment, an err() argument, a table row and a seed write must leave arm E silent, so there is no deciding arm
# MUTANT-MATRIX-CONTROL A39-c2 why=near-miss: a file already emitting the declared token must not be reported by arm E, so there is no deciding arm
# MUTANT-MATRIX-REMEASURE bash core/fixtures/enforcement-map-sites/run.sh --matrix
set -uo pipefail

# I10's scrub. Assertion 31 names a hook path (it mutates ai-dlc-dispatch-guard.sh to prove
# I56 fires), which puts this file in I10's hook-driving set. It never EXECUTES the hook, so
# the scrub is belt-and-braces rather than load-bearing — but the honest move on a check that
# fired is to satisfy it, not to narrow its grammar until it stops seeing this file.
#
# Ordered before HERE= and before the pool: the worker wrapper reads AI_DLC_EMS_SELF and
# AI_DLC_EMS_OUT in its own `bash -c`, ahead of the run.sh it then invokes, so unsetting them
# here cannot reach the values already resolved.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# Distribution-only. `validate-enforcement-map.sh` is not shipped by install.sh (it checks
# the distribution's own two writers against each other — a consumer has neither), so in a
# consumer tree there is nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$HERE/../../../scripts/validate-enforcement-map.sh" ]; then
  echo "enforcement-map-sites: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  exit 0
fi
# The validator is present and about to be driven; inputs.decl marks it REQUIRED.
echo "HERMETIC-CONSUMED scripts/validate-enforcement-map.sh" >&2

# ONE TREE PER ASSERTION, IN ONE PROCESS PER ASSERTION, AND THE REASON IS WALL CLOCK.
# Every assertion here mutates a pristine copy of the distribution and runs
# `validate-enforcement-map.sh` over it. There are 42 of those runs at ~2.5s each, and run
# end to end they made this fixture the entire critical path of the 8-way pre-push suite:
# measured 2026-07-29, it started at t=5s and finished at t=124.9s in a 124.9s suite, while
# the next-longest unit finished at t=85s with 40s to spare. The suite's wall clock WAS
# this file.
#
# Nothing about that is a property of the assertions. Each one already re-seeded a pristine
# tree before it ran (the old `restore`), so no assertion could see another's mutation --
# they were independent and merely happened to be written in a row. So each is now a
# function, each runs in its own process against its own seed, and the driver at the foot
# of this file runs them through a worker pool.
#
# WHAT THIS MUST NOT COST: fidelity. Same subject set, same mutations, same predicates,
# same messages, same order in the output. The proof is a byte-identical differential of
# this file's whole stdout against the serial version, plus the knock-out control described
# at the driver.
#
# THE CONTROL STAYS SERIAL AND STAYS FIRST. Assertion 0 asserts the PRISTINE tree passes;
# without it every "it failed as expected" below is a false pass against a validator that
# is simply broken. Running it concurrently with the assertions it licenses would report
# them in an order where that licence had not yet been established.
#
# SEEDED ONCE PER SHARD, COPIED PER TREE. `seed.sh` copies core/, scripts/, .githooks/ and
# templates/ out of the LIVE distribution, and every tree here -- one per `--run-one` cell, and
# once one per between-arm re-seed -- used to invoke it. Under the read-set deriver's sandbox tracer each of
# those copies was another full read of the distribution (90k-95k reports per traced run), and a
# later seed read no path the first had not. So the shard driver runs `seed.sh` ONCE into a
# template, checks it, and hands its path to every cell as an ARGUMENT; `seed_tree` copies the
# template. The tree each cell gets is the same tree `seed.sh` would have printed.
#
# EMS_TEMPLATE IS AN ARGUMENT SLOT, NEVER AN `AI_DLC_*` ENVIRONMENT NAME: the scrub above unsets
# those before `--run-one` reads anything (the same reason `--group` and the ledger are arguments).
# There is NO FALLBACK to `seed.sh` and none to the live root: a cell with no usable template
# exits 2, because a silent fallback re-creates the cost this removes and reads identically.
#
# EMS_DECOY is the A40-A43 cwd-battery root, a SECOND argument slot, built by the driver beside the
# template: a copy of it plus the distribution's VERSION and a `git init`. Cells never copy it, so
# every seeded ROOT still lacks VERSION (the validator's I45 guard keys on that); the decoy carries
# both markers so a validator that walks UP from its cwd for one resolves to the decoy, exactly as
# it resolved to the live root before. Same fail-closed rule: no usable decoy, exit 2.
EMS_TEMPLATE=""
EMS_DECOY=""
seed_tree() {
  # Refused HERE as well as at --run-one, because every subject calls this: an empty value would
  # make the copy below `cp -RX /.`, the whole filesystem.
  if [ -z "$EMS_TEMPLATE" ] || [ ! -f "$EMS_TEMPLATE/scripts/validate-enforcement-map.sh" ]; then
    echo "FIXTURE ERROR: seed_tree has no usable seed template (EMS_TEMPLATE='$EMS_TEMPLATE'); there is no fallback to seed.sh or to the live root" >&2
    exit 2
  fi
  ROOT="$(mktemp -d "${TMPDIR:-/tmp}/enforcement-map-sites.XXXXXX")" || { echo "FIXTURE ERROR: seed failed (mktemp)" >&2; exit 2; }
  cp -RX "$EMS_TEMPLATE/." "$ROOT/" || { echo "FIXTURE ERROR: seed failed (copy of template $EMS_TEMPLATE)" >&2; exit 2; }
  V="$ROOT/scripts/validate-enforcement-map.sh"
  PRECLASS="$ROOT/core/skills/ai-dlc-update/reconcile/preclassify.sh"
  INSTALL="$ROOT/scripts/install.sh"
}

fails=0
broken=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
# Every kill below is emitted through mutant_killed, behind a same-run test over CTL_RC (the exit
# status the shard driver captured from this shard's A00 control run, read from the file named
# in --run-one's slot 6), or behind a same-cell flag: B_a25m3/B_a35m1/B_a39m1 are set only after
# their own kill passed that gate, and B_cw beside the cwd battery's unmutated control's ok
# (cwd_control), which the driver reaches only after A00 passed.
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"

# NO RE-SEED BETWEEN THE ARMS OF ONE ASSERTION. A `restore()` used to copy the whole template
# again between arms; each arm here mutates exactly ONE pre-existing file, so the arm reverts that
# file instead (`mv`/`cp` back from its backup), which leaves the tree byte-identical to the seed.
# Some arms (A22 arms 1 and 1b, A24 arm 1, A32, A33 arm 1) keep that backup as a `.orig` INSIDE
# the tree while the arm runs; each moves or copies it back and removes it before the next arm. Measured: an `--arms` run of every multi-arm
# assertion's unit (I45, I47, I49, I57, I59, I60, and I60,I83,I84) leaves a seeded tree
# byte-identical (names, contents and exec bits, with a touch and a chmod as the controls),
# so the validator itself writes nothing a later arm could read. An arm that adds or deletes
# files must revert those exact paths, or take a fresh tree from `seed_tree`. A trailing
# re-seed was dropped outright: the cell's trap deletes the tree right after the assertion.

# `mkbak <path>` -> a backup of <path> OUTSIDE the seeded tree, printing the backup's path.
#
# THE OBVIOUS IDIOM PUTS A SECOND COPY OF THE SUBJECT INSIDE THE POPULATION UNDER TEST, and
# that is a fixture defect this file shipped for as long as it has had mutants. `cp "$X"
# "$X.orig"` leaves `$ROOT/core/scripts/<name>.sh.orig` or `$ROOT/scripts/<name>.sh.orig` on
# disk for the duration of the arm -- and those two directories are exactly the population
# I93's arms D and E sweep. The copy is a file emitting the declared token that the map
# declares nowhere, so arm D reports it; and when the arm has mutated the ORIGINAL to stop
# emitting, arm E reports the mutated original as a novel spelling as well.
#
# MEASURED, on the exemption arm at assertion 38: one `cp "$XP" "$XP.orig"` produced THREE
# I93 findings where the arm beside it asserts exactly 1 -- the wanted exemption finding, the
# `.orig` copy as an undeclared emitter, and arm E on the mutated original. It passed anyway
# because that arm greps for its own message rather than counting, which is why the count
# assertion now sits beside it.
#
# THE OTHER EIGHT WERE SILENT FOR A REASON THAT IS NOT SAFETY. Each of them neuters the very
# reporter that would name its own copy, so the extra finding had nowhere to print. That is a
# property of what each mutation happens to break, not of the idiom -- so the idiom is
# removed from every in-population site rather than from the one that showed.
mkbak() {
  local b
  b="$(mktemp)" || { echo "FIXTURE ERROR: mktemp failed for a backup of $1" >&2; exit 2; }
  cp "$1" "$b" || { echo "FIXTURE ERROR: could not back up $1" >&2; exit 2; }
  printf '%s\n' "$b"
}

# --- THE MUTANT MATRIX: per-push twins, and the --matrix measurement ------------------------
# The constants a kill signature names, defined once here because a twin or a matrix score can
# read a signature from outside the assertion that owns it. They are still ASSEMBLED at runtime,
# so this file carries no literal of any ghost (I49, I50, I52, I54 and I60 scan core/fixtures/).
ghost_a="validate-mutation""-gone.sh"
ghost_b="validate-audit""-vanished.sh"
ghost_c="$(printf 'validate-caf\303\251')-gone.sh"
ghost_m="No \`driver.sh\`"", deliberately"
GHOST="--is-""kore"
I54_TGT="core/fixtures/ledger-rotate/run.sh"
esv_tok=""; esv_xp=""; esv_xp2=""
# MX_MODE is "matrix" only under `--matrix`, and it arrives as an ARGUMENT slot (the scrub above
# unsets every AI_DLC_* name). MX_LEDGER is a file every MATRIX-ONLY cell appends its name to;
# the driver asserts a plain run leaves it empty. MX_DIR holds the full run vrun takes in matrix
# mode, for mx_score to diff. VRUN_NOMX marks a vrun site that scores no mutant (a near-miss).
MX_MODE=""
MX_LEDGER=""
MX_DIR=""
VRUN_NOMX=""
SELF_FILE="$HERE/$(basename "$0")"
# The crash shapes a matrix score refuses on: a crashed arm prints no FAIL and would read green.
MX_CRASH='unbound variable|command not found|syntax error'

mx_sig() { # mx_sig <arm> -> sets MXM (grep mode), MXP and MXQ; returns 1 for an unknown arm
  MXI=""; MXM=""; MXP=""; MXQ=""
  case "$1" in
    A01-m1) MXI=I17; MXM=q; MXP="core/brand-new-subtree/ has no destination row" ;;
    A02-m1) MXI=I17; MXM=q; MXP="disagree on where core/git-hooks/ goes" ;;
    A03-m1) MXI=I17; MXM=q; MXP="install.sh never writes" ;;
    A04-m1) MXI=I12; MXM=q; MXP="I12:.*does NOT scan them: schemas" ;;
    A05-m1) MXI=I12; MXM=q; MXP="core/brand-new-subtree/ has no drift-scan policy row" ;;
    A06-m1) MXI=I15; MXM=q; MXP="the anchor grammar has forked" ;;
    A07-m1) MXI=I15; MXM=q; MXP="I15 cannot find an ANCHOR_RE definition" ;;
    A08-m1) MXI=I17; MXM=q; MXP="sends core/session-driver/ to" ;;
    A09-m1) MXI=I16; MXM=q; MXP="runtime-pipeline prose cites a distribution path" ;;
    A11-m1) MXI=I21; MXM=q; MXP="I21 reconcile/apply.sh defines its own section_of()" ;;
    A12-m1) MXI=I21; MXM=q; MXP="I21 reconcile/register-drift.sh calls section_of() but never sources" ;;
    A13-m1) MXI=I21; MXM=q; MXP="I21 found no function definitions" ;;
    A14-m1) MXI=I31; MXM=q; MXP="I31: these core subtrees are I12 'scan'" ;;
    A15-m1) MXI=I31; MXM=q; MXP="I31: could not parse any case label" ;;
    A16-m1) MXI=I32; MXM=q; MXP="I32: Check 17's 'research-requirements phase' arm" ;;
    A17-m1) MXI=I32; MXM=q; MXP="I32 matched no bmad-\* skill pin" ;;
    A18-m1) MXI=I33; MXM=q; MXP="I33: these fixtures reach a core subtree by walking up" ;;
    A19-m1) MXI=I33; MXM=q; MXP="I33 found no \*.sh under core/fixtures/" ;;
    A20-m1) MXI=I26; MXM=q; MXP="restates the core path set" ;;
    A21-m1) MXI=I40; MXM=q; MXP="the anchor reading has forked" ;;
    A21-m2) MXI=I40; MXM=q; MXP="I40 cannot find a shadow_parts() definition" ;;
    A22-m1) MXI=I45; MXM=q; MXP="core allocates rule number(s) at or above the reserved consumer band" ;;
    A22-m2) MXI=I45; MXM=q; MXP="core allocates alphabetic check id(s) beginning with the reserved consumer prefix" ;;
    A22-m3) MXI=I45; MXM=q; MXP="could not read BAND_ALPHA_PREFIX" ;;
    A22-m4) MXI=I45; MXM=q; MXP="could not read BAND_FLOOR" ;;
    A22-m5) MXI=I45; MXM=q; MXP="extracted ZERO check anchors" ;;
    A23-m1) MXI=I47; MXM=q; MXP="the check-heading grammar has forked" ;;
    A23-m2) MXI=I47; MXM=q; MXP="could not find a CHECK_HEAD_RE= assignment" ;;
    A23-m3) MXI=I47; MXM=q; MXP="the DETECTORS' check-heading grammar and the REWRITER's have forked" ;;
    A24-m1) MXI=I49; MXM=q; MXP="mode(s) the script does not dispatch" ;;
    A24-m2) MXI=I49; MXM=q; MXP="its own usage() never names" ;;
    A24-m3) MXI=I49; MXM=q; MXP="parsed ZERO modes" ;;
    A25-m1) MXI=I50; MXM=q; MXP="$ghost_a" ;;
    A25-m2) MXI=I50; MXM=q; MXP="$ghost_b" ;;
    A25-m3) MXI=I50; MXM=qF; MXP="$ghost_c" ;;
    A25-m4) MXI=I50; MXM=ne; MXP="$ghost_c"; MXQ="I50 derived an EMPTY set" ;;
    A25-m5) MXI=I50; MXM=q; MXP="I50 derived an EMPTY set" ;;
    A26-m1) MXI=I51; MXM=q; MXP="tells the lead to write a subject the shipped matcher rejects" ;;
    A26-m2) MXI=I51; MXM=q; MXP="subject_example does not match backfill_commit.subject_pattern" ;;
    A26-m3) MXI=I51; MXM=q; MXP="I51 could not derive both sides" ;;
    A27-m1) MXI=I52; MXM=qF; MXP="$ghost_m" ;;
    A27-m2) MXI=I52; MXM=q; MXP="cannot read EXEMPT_MARKER out of validate-fixture-drivability.sh" ;;
    A28-m1) MXI=I53; MXM=q; MXP="mode(s) it does not dispatch" ;;
    A28-m2) MXI=I53; MXM=q; MXP="its own USAGE block never names" ;;
    A28-m3) MXI=I53; MXM=q; MXP="parsed ZERO modes out of validate-escalation-resolution.sh" ;;
    A29-m1) MXI=I54; MXM=qq; MXP="$I54_TGT"; MXQ='I54 found' ;;
    A29-m2) MXI=I54; MXM=q; MXP="grammar no longer matches the shape it bans" ;;
    A29-m3) MXI=I54; MXM=q; MXP="matches an ordinary command piped into" ;;
    A30-m1) MXI=I55; MXM=q; MXP="not bare top-level names" ;;
    A30-m2) MXI=I55; MXM=q; MXP="no longer excludes .git" ;;
    A30-m3) MXI=I55; MXM=q; MXP="reach a content-key-EXCLUDED path" ;;
    A30-m4) MXI=I55; MXM=q; MXP="inside the working tree" ;;
    A31-m1) MXI=I56; MXM=q; MXP="the model pin has forked" ;;
    A31-m2) MXI=I56; MXM=q; MXP="validate-spawn-ledger.sh (found 0)" ;;
    A31-m3) MXI=I56; MXM=q; MXP="ai-dlc-dispatch-guard.sh (found 2)" ;;
    A32-m1) MXI=I57; MXM=q; MXP="Check 17: stamp-story-provenance.sh" ;;
    A32-m2) MXI=I57; MXM=q; MXP="Check 14: validate-artifact-budget.sh" ;;
    A32-m3) MXI=I57; MXM=q; MXP="Check 25: wait-for-deliverable.sh" ;;
    A32-m4) MXI=I57; MXM=q; MXP="did not fire on a probe" ;;
    A32-m5) MXI=I57; MXM=q; MXP="exit-code LEGEND" ;;
    A33-m1) MXI=I59; MXM=q; MXP="readopt-override.sh --merge" ;;
    A33-m2) MXI=I59; MXM=q; MXP="did not fire on its own probe" ;;
    A33-m3) MXI=I59; MXM=q; MXP="reported the exempt --help arm on its own probe" ;;
    A33-m4) MXI=I59; MXM=q; MXP="I59 found only 0 shipped script(s)" ;;
    A34-m1) MXI=I60; MXM=q; MXP="core-paths.sh $GHOST" ;;
    A34-m2) MXI=I60; MXM=q; MXP="has lost the non-case form" ;;
    A34-m3) MXI=I60; MXM=q; MXP="did not fire on its own probe" ;;
    A34-m4) MXI=I60; MXM=q; MXP="I60 derived only" ;;
    A35-m1) MXI=I93; MXM=q; MXP="core/scripts/esv-newcomer.sh prints '$esv_tok' outside a comment" ;;
    A35-m2) MXI=I93; MXM=q; MXP="scripts/esv-dist-newcomer.sh prints '$esv_tok' outside a comment" ;;
    A35-m3) MXI=I93; MXM=q; MXP="core/scripts/esv-newcomer.js prints '$esv_tok' outside a comment" ;;
    A35-m4) MXI=I93; MXM=nk; MXP='esv-newcomer.sh'; MXQ='^OK: enforcement-map.yaml in sync' ;;
    A36-m1) MXI=I93; MXM=q; MXP="arm D exempts '$esv_xp' from the reverse join and no such file exists" ;;
    A36-m2) MXI=I93; MXM=q; MXP="arm D exempts '$esv_xp' and arm D's own sweep found no line of it outside a comment" ;;
    A36-m3) MXI=I93; MXM=q; MXP="'$esv_xp' is BOTH declared an emitter" ;;
    A36-m4) MXI=I93; MXM=q; MXP="exemption list carries '$esv_xp' with no reason after the path" ;;
    A37-m1) MXI=I93; MXM=q; MXP="I93's probe scored 1001000000" ;;
    A37-m2) MXI=I93; MXM=q; MXP="I93's probe scored 1110000000" ;;
    A38-m1) MXI=I93; MXM=q; MXP="did not finish reading its population" ;;
    A38-m2) MXI=I93; MXM=q; MXP="arm D exempts .* and arm D's own sweep found no line of it" ;;
    A39-m1) MXI=I93; MXM=q; MXP="core/scripts/esv-fourth.sh:2 states an empty-subject verdict in a spelling of its own" ;;
    A39-m2) MXI=I93; MXM=q; MXP="scripts/esv-fourth-dist.sh:2 states an empty-subject verdict" ;;
    A39-m3) MXI=I93; MXM=q; MXP="arm D exempts '$esv_xp2' and arm D's own sweep found no line of it" ;;
    A39-m4) MXI=I93; MXM=nk; MXP='esv-fourth.sh'; MXQ='^OK: enforcement-map.yaml in sync' ;;
    A39-m5) MXI=I93; MXM=q; MXP='states an empty-subject verdict in a spelling of its own' ;;
    I16-vacuity) MXI=I16; MXM=q; MXP="I16 derived an EMPTY core/ directory list" ;;
    I26-span) MXI=I26; MXM=q; MXP="I26 could not isolate the core-layer-immutability span" ;;
    *) return 1 ;;
  esac
}

# mx_red <arm> <output> -> 0 when <arm>'s kill condition holds on <output> (the arm is RED).
mx_red() {
  local o="$2"
  mx_sig "$1" || { bad "FIXTURE BROKEN: no kill signature for arm '$1' in mx_sig"; return 2; }
  case "$MXM" in
    q)  grep -q -- "$MXP" <<<"$o" ;;
    qF) grep -qF -- "$MXP" <<<"$o" ;;
    qq) grep -qF -- "$MXP" <<<"$o" && grep -q -- "$MXQ" <<<"$o" ;;
    ne) ! grep -qF -- "$MXP" <<<"$o" && ! grep -q -- "$MXQ" <<<"$o" ;;
    nk) ! grep -q -- "$MXP" <<<"$o" && grep -q -- "$MXQ" <<<"$o" ;;
    *)  bad "FIXTURE BROKEN: arm '$1' has an unknown signature mode '$MXM'"; return 2 ;;
  esac
}

# mx_row <name> <field> -> the field of <name>'s one MUTANT-MATRIX header row; empty unless
# exactly one row names it. The header IS the twin list: nothing else in this file restates it.
mx_row() {
  awk -v n="$1" -v f="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n {
      c++; for (i = 4; i <= NF; i++) if (index($i, f "=") == 1) v = substr($i, length(f) + 2)
    }
    END { if (c == 1) print v }' "$SELF_FILE"
}

# mx_twins <arm> <output> -- run after the arm's own kill. Plain mode: every twin must stay GREEN
# on the SAME output, which costs no validator run. Matrix mode: the full score (mx_score).
mx_twins() {
  local arm="$1" o="$2" tw t
  tw="$(mx_row "$arm" twins)"
  if [ -z "$tw" ]; then bad "FIXTURE BROKEN: $arm has no single MUTANT-MATRIX row naming its twins"; return; fi
  if [ "$MX_MODE" = matrix ]; then mx_score "$arm" "$o" "$tw"; return; fi
  [ -n "$MX_LEDGER" ] && printf 'plain-twins %s\n' "$arm" >> "$MX_LEDGER"
  [ "$tw" = - ] && return
  for t in $(printf '%s' "$tw" | tr ',' ' '); do
    if mx_red "$t" "$o"; then
      bad "$arm: its twin $t also fired on this mutant's output -- the kill is not confined to $arm's own arm"
    fi
  done
}

# mx_score <arm> <selected output> <twins> -- MATRIX-ONLY. Scores the mutant against every arm of
# its own selected unit, and against every arm outside it by the full run vrun took of the same
# mutated tree from the same cwd. Prints one MATRIX line.
mx_score() {
  local arm="$1" o="$2" tw="$3" id dec tws="" uex="" a g=0 t=0 frc extra=0 outside
  printf 'mx-score %s\n' "$arm" >> "$MX_LEDGER"
  [ -n "$esv_tok" ] || esv_tok="$(awk '/^empty_subject_verdict:/ { on = 1; next } on && /^[^[:space:]#]/ { exit } on && /^  token:/ { sub(/^  token:[[:space:]]*/, ""); print; exit }' "$EMS_TEMPLATE/core/skills/ai-dlc/enforcement-map.yaml")"
  [ -n "$esv_xp" ] || esv_xp="$(awk -F"'" '/^[[:space:]]*ESV_EXEMPT=/ { split($2, a, " "); print a[1]; exit }' "$EMS_TEMPLATE/scripts/validate-enforcement-map.sh")"
  [ -n "$esv_xp2" ] || esv_xp2="$esv_xp"
  frc="$(cat "$MX_DIR/full.rc" 2>/dev/null)"
  if grep -qE -- "$MX_CRASH" <<<"$o" || grep -qE -- "$MX_CRASH" "$MX_DIR/full.out" 2>/dev/null \
     || { [ "$frc" != 0 ] && [ "$frc" != 1 ]; }; then
    printf 'MATRIX BROKEN %s\n' "$arm"
    [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: MATRIX BROKEN %s -- a run crashed (full-run rc %s) or printed a crash shape, so no arm verdict on it means anything\n' "$arm" "${frc:-none}" >> "$VRUN_BROKEN"
    return
  fi
  mx_sig "$arm"; id="$MXI"
  if mx_red "$arm" "$o"; then dec="$arm:RED"; else dec="$arm:GREEN"; uex="$uex $arm:GREEN"; fi
  if [ "$tw" != - ]; then
    for a in $(printf '%s' "$tw" | tr ',' ' '); do
      if mx_red "$a" "$o"; then tws="$tws,$a:RED"; uex="$uex $a:RED"; else tws="$tws,$a:GREEN"; fi
    done
    tws="${tws#,}"
  else
    tws=-
  fi
  for a in $(sed -n 's/^    \([A-Z][A-Za-z0-9-]*\)) MXI=\([A-Z0-9]*\);.*/\1 \2/p' "$SELF_FILE" | awk -v i="$id" '$2 == i { print $1 }'); do
    [ "$a" = "$arm" ] && continue
    case ",$tw," in *",$a,"*) continue ;; esac
    t=$((t + 1)); mx_red "$a" "$o" || g=$((g + 1))
  done
  extra="$(LC_ALL=C comm -13 <(grep '^FAIL:' <<<"$o" | LC_ALL=C sort -u) <(grep '^FAIL:' "$MX_DIR/full.out" | LC_ALL=C sort -u) | grep -c .)" || extra=0
  if [ "$extra" -eq 0 ]; then outside=EQUAL; else outside="+$extra"; fi
  if [ -n "$uex" ]; then
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d outside=%s UNEXPECTED=%s\n' "$arm" "$dec" "$tws" "$g" "$t" "$outside" "$(printf '%s' "${uex# }" | tr ' ' ',')"
    bad "MATRIX $arm does not match its header row:$uex"
  else
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d outside=%s\n' "$arm" "$dec" "$tws" "$g" "$t" "$outside"
  fi
  [ "$extra" -eq 0 ] || grep '^FAIL:' "$MX_DIR/full.out" | LC_ALL=C sort -u | LC_ALL=C comm -13 <(grep '^FAIL:' <<<"$o" | LC_ALL=C sort -u) - | cut -c1-160 | sed 's/^/MATRIX-OUTSIDE   /'
}

# ONE VALIDATOR RUN PER ASSERTION, AND THE ARM IT SELECTS IS DERIVED FROM THE CALLER'S NAME.
# `validate-enforcement-map.sh --arms I<n>` runs one selectable unit plus the prologue and the
# verdict block. Every assertion below already declares the invariant it tests in its own
# function name -- `A04_i12_scan_match` tests I12 -- so that embedded segment IS the selector.
# Nothing here hand-lists one, and that is the point: a second list would be this fixture's own
# subject defect one level out. A list that drifted from the assertions would select an arm for
# a mutation it never reads, the mutant would go unreported, and an unreported mutant reads
# exactly like a surviving one.
#
# THREE FAILURE SHAPES, and none of them may reach an assertion's predicate:
#   - a frame whose name carries no derivable `i<id>` segment;
#   - `--arms <id>` naming an id no arm declares, or any other selection/usage failure;
#   - a generated subprogram that never reached the verdict block.
# The validator answers all three with exit 2, which is never an invariant violation. Scoring
# one as a mutant surviving or dying would be a wrong answer in the exact register this file
# exists to protect, so each is FIXTURE BROKEN, named, with the validator's own message.
#
# THERE IS DELIBERATELY NO FALLBACK TO A FULL RUN. A fallback would run every arm, satisfy the
# grep, print the same green line, and leave a selector that resolves to nothing looking
# identical to one that resolved correctly -- a mechanism that cannot fire reading exactly like
# one that did.
#
# THE BROKEN SIGNAL GOES THROUGH A FILE, and that is not a style choice. `out="$(vrun)"` runs
# this function inside a command substitution, so an `exit 2` here kills the SUBSHELL: the
# assertion would carry on with an empty `$out`, fail its own grep, and report the mutant as
# surviving. `--run-one` reads the marker after the assertion returns and exits 2 itself, which
# is the code the driver already routes to FIXTURE BROKEN rather than to a regression.
VRUN_LOG=""
VRUN_BROKEN=""
# The validator's exit status, for a caller that asserts it. `vrun` runs inside `$( )`, so the
# status cannot come back as a variable; when this names a file, vrun writes the status there.
VRUN_RCF=""
# `vrun [validator-path]` -- the path defaults to "$V". The cwd-invariance cells pass a
# RELATIVE one, run from a subdirectory of the seeded tree.
vrun() {
  local frame seg id vout rc
  id=""
  for frame in "${FUNCNAME[@]}"; do
    case "$frame" in
      A[0-9]*_i[0-9]*)
        seg="${frame#A}"; seg="${seg#*_}"; seg="${seg%%_*}"
        case "$seg" in
          i[0-9]*) id="I${seg#i}"; break ;;
        esac
        ;;
    esac
  done
  if [ -z "$id" ]; then
    [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: vrun found no A<nn>_i<id>_ frame to derive an --arms selector from (frames: %s). The naming grammar the selector is derived from has moved, and there is no full-run fallback on purpose.\n' "${FUNCNAME[*]}" >> "$VRUN_BROKEN"
    return 2
  fi
  vout="$(bash "${1:-$V}" --arms "$id" 2>&1)"; rc=$?
  [ -n "$VRUN_RCF" ] && printf '%s\n' "$rc" > "$VRUN_RCF"
  if [ "$rc" = "2" ]; then
    [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: validate-enforcement-map.sh --arms %s exited 2. That is a SELECTION failure -- an unknown id, a malformed flag, or a generated subprogram that never reached the verdict -- not an invariant finding, so it is not scored as a mutant surviving or dying: %s\n' "$id" "$vout" >> "$VRUN_BROKEN"
    return 2
  fi
  [ -n "$VRUN_LOG" ] && printf '%s\n' "$id" >> "$VRUN_LOG"
  # MATRIX-ONLY: one FULL run of the same mutated tree from the same cwd, so mx_score can see the
  # arms outside the selected unit. A plain run never reaches it, and the driver asserts that.
  if [ "$MX_MODE" = matrix ] && [ -z "$VRUN_NOMX" ] && [ -n "$MX_DIR" ]; then
    printf 'mx-full %s\n' "$id" >> "$MX_LEDGER"
    bash "${1:-$V}" > "$MX_DIR/full.out" 2>&1; printf '%s\n' "$?" > "$MX_DIR/full.rc"
  fi
  printf '%s\n' "$vout"
}

# --- Assertion 0: SANITY ------------------------------------------------------
# The pristine tree must PASS. If it does not, the validator is erroring for some reason
# of its own and every "it failed as expected" below is a false pass.
#
# THE ONE ASSERTION THAT KEEPS A FULL RUN, and its claim is why. "The pristine tree passes"
# is an ABSENCE over EVERY arm, not over one, so `--arms` would license only the arm it
# selected and the licence the assertions below rely on would be narrower than the set of
# arms they use. A selected run says nothing whatever about the arms it did not run.
A00_sanity() {
if bash "$V" >/dev/null 2>&1; then
  ok "pristine distribution tree passes (the negatives below mean something)"
else
  bad "FIXTURE BROKEN — the pristine tree does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
fi
}

# --- Assertion 1: COMPLETENESS ------------------------------------------------
# A new core/<dir>/ with no row must be an ERROR, not a silent fall-through to the
# `core/*` catch-all. This is the one that would have caught git-hooks.
#
# THE NEXT THREE ARE NAMED i17, NOT i8, AND THAT IS A MEASUREMENT. Their failure text says
# "I8's site table", and the table is I8's by history -- but the SELECTABLE UNIT that reads
# it is I17's, and `--arms` selects units. Measured on a seeded tree with the completeness
# mutation applied: `--arms I8` exits 0 and reports nothing, `--arms I17` exits 1 and prints
# the row-missing finding. I8's own unit is fixture packaging, several thousand lines away.
# Naming these i8 would have selected an arm that cannot see the mutation, and a mutation no
# arm reads scores as a survivor -- which is this file's whole subject. The name states which
# unit runs the check, because that is what the selector is derived from.
A01_i17_sitetable_completeness() {
mkdir -p "$ROOT/core/brand-new-subtree"
echo 'x' > "$ROOT/core/brand-new-subtree/thing.sh"
out="$(vrun)"
if mx_red A01-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A01-m1 "A01-m1: a new core/ subtree with no site row FAILS (the catch-all can no longer swallow one silently)"
else
  bad "A01-m1 SURVIVED: a new core/ subtree with no site row did NOT fail — I8 is hand-listed again, and the next core/<dir>/ ships to a path nothing reads"
fi
mx_twins A01-m1 "$out"
}

# --- Assertion 2: AGREEMENT ---------------------------------------------------
# Delete map_consumer()'s git-hooks case and I8 must catch it. This replays the exact
# v0.55.1 state of the tree: install.sh writes .githooks/, the pull writes .claude/git-hooks/.
A02_i17_sitetable_agreement() {
grep -q 'core/git-hooks/\*)' "$PRECLASS" || bad "FIXTURE STALE: preclassify.sh has no core/git-hooks/ case to remove"
sed -i.bak '/core\/git-hooks\/\*)/d' "$PRECLASS"
out="$(vrun)"
if mx_red A02-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A02-m1 "A02-m1: map_consumer() losing its git-hooks case FAILS (the v0.53.0 regression cannot return)"
else
  bad "A02-m1 SURVIVED: map_consumer() with no git-hooks case did NOT fail — the pre-push gate would ship to .claude/git-hooks/ again"
fi
mx_twins A02-m1 "$out"
}

# --- Assertion 3: INSTALLER BINDING -------------------------------------------
# A row is only true if install.sh really writes there. Remove the .githooks write and the
# row must stop being satisfiable — otherwise the table could be kept "green" by asserting
# a destination the installer abandoned.
A03_i17_sitetable_installer_binding() {
grep -q 'PROJECT_ROOT/.githooks' "$INSTALL" || bad "FIXTURE STALE: install.sh has no .githooks write to remove"
sed -i.bak 's|"\$PROJECT_ROOT/\.githooks|"$PROJECT_ROOT/.githooks-REMOVED|g' "$INSTALL"
out="$(vrun)"
if mx_red A03-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A03-m1 "A03-m1: a site row whose destination install.sh abandoned FAILS (the table is bound to the installer, not to itself)"
else
  bad "A03-m1 SURVIVED: install.sh dropping .githooks did NOT fail — I8's table can assert a destination nothing writes"
fi
mx_twins A03-m1 "$out"
}

# --- Assertion 4: I12 SCAN-MATCH ----------------------------------------------
# unregistered-drift.sh's scan set is bound to I12's per-subtree policy. Drop a scan-marked
# subtree from the tool's ls-tree and I12 must catch the divergence — this is what stops the
# scan set silently rotting the way ai-dlc-setup/ and schemas/ did.
A04_i12_scan_match() {
UD="$ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
if grep -q 'core/hooks core/schemas' "$UD"; then
  sed -i.bak 's| core/hooks core/schemas | core/hooks |' "$UD"
  out="$(vrun)"
  if mx_red A04-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A04-m1 "A04-m1: unregistered-drift.sh dropping core/schemas from its scan FAILS I12 (the scan set is bound, not hand-listed)"
  else
    bad "A04-m1 SURVIVED: dropping core/schemas from the scan did NOT fail I12 — the scan set can rot silently again"
  fi
  mx_twins A04-m1 "$out"
else
  bad "FIXTURE STALE: unregistered-drift.sh no longer scans 'core/hooks core/schemas'"
fi
}

# --- Assertion 5: I12 COMPLETENESS --------------------------------------------
# A new core/<dir>/ with no policy row must FAIL — a new subtree cannot silently escape the scan.
A05_i12_completeness() {
mkdir -p "$ROOT/core/brand-new-subtree"
echo 'x' > "$ROOT/core/brand-new-subtree/thing.md"
out="$(vrun)"
if mx_red A05-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A05-m1 "A05-m1: a new core/ subtree with no I12 policy row FAILS (a new dir must be classified scan/exempt before it can ship)"
else
  bad "A05-m1 SURVIVED: a new core/ subtree with no I12 policy row did NOT fail — the scan set is hand-listed again"
fi
mx_twins A05-m1 "$out"
}

# --- Assertion 6: I15 GRAMMAR FORK --------------------------------------------
# layer-drift.sh REPORTS a heading-number collision; relabel-extension-checks.sh FIXES it.
# relabel shipped the narrower grammar for ~20 versions, so core's real `### H1.` yielded no
# anchor and a collision on it was unrelabellable — the operator was told to relabel with a
# tool that could not see the heading. Narrow one copy and I15 must catch the fork.
A06_i15_grammar_fork() {
RELABEL="$ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
if grep -q '^ANCHOR_RE=' "$RELABEL"; then
  sed -i.bak "s|^ANCHOR_RE=.*|ANCHOR_RE='^#{2,4} [0-9]+[a-z]*\\\\.'|" "$RELABEL"
  out="$(vrun)"
  if mx_red A06-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A06-m1 "A06-m1: narrowing relabel's ANCHOR_RE FAILS I15 (the reporter and the fixer cannot drift apart)"
  else
    bad "A06-m1 SURVIVED: narrowing relabel's ANCHOR_RE did NOT fail I15 — the two grammars can fork again and H1-style collisions go unrelabellable"
  fi
  mx_twins A06-m1 "$out"
  RELABEL="$ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
else
  bad "FIXTURE STALE: relabel-extension-checks.sh no longer defines ANCHOR_RE"
fi
}

# --- Assertion 7: I15 NON-VACUITY ---------------------------------------------
# I15 greps both files for ANCHOR_RE. If a definition simply vanishes, the check must say so
# rather than find nothing and pass — "no definitions to compare" must never read as "equal".
A07_i15_non_vacuity() {
# Bound here rather than inherited: when this file ran as one long script the name was
# still set from the assertion above. Each assertion now runs in its own process against
# its own tree, so an inherited path would be an unset variable under `set -u`.
RELABEL="$ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"

if grep -q '^ANCHOR_RE=' "$RELABEL"; then
  sed -i.bak '/^ANCHOR_RE=/d' "$RELABEL"
  out="$(vrun)"
  if mx_red A07-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A07-m1 "A07-m1: deleting an ANCHOR_RE definition FAILS I15 loudly (it cannot pass by comparing nothing)"
  else
    bad "A07-m1 SURVIVED: deleting an ANCHOR_RE definition did NOT fail I15 — the check goes vacuous exactly when the grammar is missing"
  fi
  mx_twins A07-m1 "$out"
fi
}

# --- Assertion 7b: I17 THE WRITER ---------------------------------------------
# map_consumer() only CLASSIFIES. reconcile/apply.sh is what actually PLACES files on a pull,
# and it was bound to nothing — it kept a private hand-listed copy of the site table and
# omitted session-driver, ci-templates and git-hooks, which therefore never applied while the
# same run re-stamped .ai-dlc-version anyway. Give apply.sh a private table again and I17
# must catch it, exactly as I8 catches map_consumer drifting.
A08_i17_the_writer() {
APPLY_F="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
if grep -q '^consumer_path() {' "$APPLY_F"; then
  python3 - "$APPLY_F" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
# Reintroduce the exact defect: a hand-listed table with no session-driver case.
mutant = '''consumer_path() {
  case "$1" in
    team-roles/*) printf '%s/.claude/team-roles/%s' "$CONSUMER" "${1#team-roles/}" ;;
    *) return 1 ;;
  esac
}'''
s = re.sub(r'^consumer_path\(\) \{.*?^\}', mutant, s, count=1, flags=re.S | re.M)
open(p, 'w').write(s)
PY
  out="$(vrun)"
  if mx_red A08-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A08-m1 "A08-m1: apply.sh regrowing a private path table FAILS I17 (the pull's WRITER is bound to the installer, not just the classifier)"
  else
    bad "A08-m1 SURVIVED: apply.sh with a hand-listed table missing session-driver did NOT fail I17 — a subtree can silently not apply while the run re-stamps, and the consumer's stamp claims a version its tree lacks"
  fi
  mx_twins A08-m1 "$out"
else
  bad "FIXTURE STALE: apply.sh no longer defines consumer_path()"
fi
}

# --- Assertion 8: I16 DEAD PROSE PATH -----------------------------------------
# The real bug: Check 19 cited `core/team-roles/code-reviewer.md`, a path that exists in the
# distribution and at NO consumer. install.sh maps core/<x> -> .claude/<x>, but that moves
# FILES, not the paths written inside them. Plant one and I16 must fire.
A09_i16_dead_prose_path() {
printf '\nSee `core/team-roles/dev.md` for the map.\n' >> "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
out="$(vrun)"
if mx_red A09-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A09-m1 "A09-m1: a core/-prefixed prose path in a runtime step file FAILS I16 (installed core cannot ship a dead citation)"
else
  bad "A09-m1 SURVIVED: a core/-prefixed prose path did NOT fail I16 — installed core can cite the distribution's layout again, and one dead link already cost a live gate rule"
fi
mx_twins A09-m1 "$out"
}

# --- Assertion 9: I16 PRECISION -----------------------------------------------
# The other side of the same check, and the one that keeps it usable. The word "core" is
# everywhere in this rulebook ("core rule", "core catalog", "core-path wiring"), and the
# update machinery cites `core/...` paths BY DESIGN — comparing distribution to consumer is
# its whole job. If I16 flags either, it gets switched off and stops catching the real thing.
A10_i16_precision() {
printf '\nThe core rule lives in the core catalog; core-path wiring is a core concern.\n' \
  >> "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
printf '\nDiff base->theirs restricted to `core/skills/ai-dlc-update/**` and `core/team-roles/dev.md`.\n' \
  >> "$ROOT/core/skills/ai-dlc-update/SKILL.md"
VRUN_NOMX=1; out="$(vrun)"; VRUN_NOMX=""
if grep -q "runtime-pipeline prose cites a distribution path" <<<"$out"; then
  bad "A10-c1: I16 fired on the English word 'core' or on ai-dlc-update's by-design core/ citations — a check with false positives is a check the operator turns off"
else
  ok "A10-c1: I16 ignores the English word 'core' and ai-dlc-update's by-design core/ paths (precise enough to stay on)"
fi
}

# --- Assertion 10: I21 FOURTH COPY --------------------------------------------
# `section_of()` shipped divergent twice (v0.52.0 weaker, v0.54.2 stricter), and both
# times the remedy was a hand-copy and a CHANGELOG line saying "there is one resolver".
# v0.90.0 collapsed the three copies into lib.sh — that fixed the INSTANCES. The HOLE is
# that nothing stopped a fourth file inlining its own, and a private resolver fails
# silently: the tool reports a confident verdict computed from a different section.
A11_i21_fourth_copy() {
RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
APPLY_F="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
printf '\nsection_of() { echo private; }\n' >> "$APPLY_F"
out="$(vrun)"
if mx_red A11-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A11-m1 "A11-m1: a fourth inline section_of() FAILS I21 (the resolver cannot fork a third time)"
else
  bad "A11-m1 SURVIVED: a fourth inline section_of() did NOT fail I21 — the divergence that shipped in v0.52.0 and v0.54.2 can return, and nothing compares the copies"
fi
mx_twins A11-m1 "$out"
RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
}

# --- Assertion 11: I21 UNSOURCED CALL -----------------------------------------
# The other direction. A classifier that calls section_of() without sourcing lib.sh gets
# an EMPTY section back on a consumer's pull, and an empty section reads as "no drift"
# rather than as an error — the same shape as the v0.52.0 cleared block.
A12_i21_unsourced_call() {
REG_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
if grep -q '^\. "\$SELF/lib\.sh"' "$REG_F"; then
  sed -i.bak '/^\. "\$SELF\/lib\.sh"/d' "$REG_F"
  out="$(vrun)"
  if mx_red A12-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A12-m1 "A12-m1: a classifier that drops its lib.sh source FAILS I21 (a call that resolves to nothing cannot ship)"
  else
    bad "A12-m1 SURVIVED: register-drift.sh dropping its lib.sh source did NOT fail I21 — section_of() resolves to nothing on a real pull and the empty section reads as 'no drift'"
  fi
  mx_twins A12-m1 "$out"
  RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
else
  bad "FIXTURE STALE: register-drift.sh no longer sources lib.sh at the expected anchor"
fi
}

# --- Assertion 12: I21 NON-VACUITY --------------------------------------------
# I21 derives the helper set from lib.sh's own definitions. If those stop matching — the
# library emptied, or its definition form changed — the check must say so rather than bind
# an empty set and pass. "Nothing to compare" must never read as "no second copy exists".
A13_i21_non_vacuity() {
# Bound here rather than inherited: when this file ran as one long script the name was
# still set from the assertion above. Each assertion now runs in its own process against
# its own tree, so an inherited path would be an unset variable under `set -u`.
RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"

if grep -qE '^[a-z_]+\(\) \{' "$RLIB_F"; then
  grep -vE '^[a-z_]+\(\) \{' "$RLIB_F" > "$RLIB_F.tmp" && mv "$RLIB_F.tmp" "$RLIB_F"
  out="$(vrun)"
  if mx_red A13-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A13-m1 "A13-m1: lib.sh losing its definitions FAILS I21 loudly (it cannot pass by binding an empty helper set)"
  else
    bad "A13-m1 SURVIVED: emptying lib.sh did NOT fail I21 — the check goes vacuous exactly when the single home stops being one"
  fi
  mx_twins A13-m1 "$out"
else
  bad "FIXTURE STALE: reconcile/lib.sh no longer defines helpers in the '<name>() {' form I21 derives from"
fi
}

# --- Assertion 13: I31 SCAN SET HAS A DISPOSITION -----------------------------
# I12 makes a subtree REPORTABLE; it says nothing about what the operator does next, and the
# report hands them exactly one command. `skills/ai-dlc-setup` and `schemas` were both
# scan-marked and both fell to register-drift.sh's `unrecognized core path` — a message that
# reads like a typo in a path the report itself supplied. Drop the named no-grain refusal and
# I31 must name the subtrees left without a disposition.
A14_i31_disposition() {
RD_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
if grep -q '^  schemas/\*|skills/ai-dlc-setup/\*)' "$RD_F"; then
  sed -i.bak 's@^  schemas/\*|skills/ai-dlc-setup/\*)@  never-matches-a-real-path/*)@' "$RD_F"
  out="$(vrun)"
  if mx_red A14-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A14-m1 "A14-m1: removing register-drift's no-grain refusal FAILS I31 (a scan-marked subtree cannot reach an unnamed refusal)"
  else
    bad "A14-m1 SURVIVED: removing the no-grain refusal did NOT fail I31 — a scan-marked subtree can be reported with no sanctioned disposition again"
  fi
  mx_twins A14-m1 "$out"
  RD_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
else
  bad "FIXTURE STALE: register-drift.sh no longer carries the schemas/ai-dlc-setup no-grain case"
fi
}

# --- Assertion 14: I31 NON-VACUITY --------------------------------------------
# I31 derives register-drift's side by parsing its `case` labels. If that parse yields nothing
# — the case block moved, or its formatting changed — the comparison binds an empty set and
# EVERY scan subtree reads as undisposed, or worse, the check quietly passes. It must say so.
A15_i31_non_vacuity() {
# Bound here rather than inherited: when this file ran as one long script the name was
# still set from the assertion above. Each assertion now runs in its own process against
# its own tree, so an inherited path would be an unset variable under `set -u`.
RD_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"

if grep -q '^case "\$REL" in' "$RD_F"; then
  # Remove the parse's opening anchor. Everything after it is untouched, so the case labels are
  # still there on disk and only the DERIVATION goes blind — which is the vacuity being tested.
  grep -v '^case "\$REL" in' "$RD_F" > "$RD_F.tmp" && mv "$RD_F.tmp" "$RD_F"
  out="$(vrun)"
  if mx_red A15-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A15-m1 "A15-m1: an unparseable case block FAILS I31 loudly (it cannot pass by comparing against nothing)"
  else
    bad "A15-m1 SURVIVED: an unparseable case block did NOT fail I31 — the check goes vacuous exactly when register-drift's dispositions become unreadable"
  fi
  mx_twins A15-m1 "$out"
else
  bad "FIXTURE STALE: register-drift.sh no longer opens with 'case \"\$REL\" in'"
fi
}

# --- Assertion 15: I32 PIN vs INVOCATION --------------------------------------
# Check 17's arms pin a provenance block to a skill NAME; the step file that runs the
# evaluation names the skill it INVOKES. Two files, one fact, nothing comparing them —
# v0.169.0 repointed research-requirements.md §3 to /bmad-prd and left the arm pinning the
# old name, and no check said so for three minors. Repoint an arm at a bmad skill its own
# step file does not name and I32 must catch it.
A16_i32_pin_vs_invocation() {
GV_F="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
if grep -qE '^  bmad-prd`\.$' "$GV_F"; then
  sed -i.bak 's/^  bmad-prd`\.$/  bmad-party-mode`./' "$GV_F"
  out="$(vrun)"
  if mx_red A16-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A16-m1 "A16-m1: an arm pinning a skill its step file never invokes FAILS I32 (a pin and an invocation are one fact in two files)"
  else
    bad "A16-m1 SURVIVED: repointing the PRD arm at an uninvoked skill did NOT fail I32 — the pin can fork from the step again"
  fi
  mx_twins A16-m1 "$out"
  GV_F="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
else
  bad "FIXTURE STALE: Check 17's PRD arm no longer pins bmad-prd on its own line"
fi
}

# --- Assertion 16: I32 NON-VACUITY --------------------------------------------
# Every I32 guard runs INSIDE the per-arm loop, so an arm grammar that stops matching scans
# nothing and reports clean — which is precisely the shape this check exists to end. Break
# the flag the arms are parsed on and the check must say it compared nothing.
A17_i32_non_vacuity() {
# Bound here rather than inherited: when this file ran as one long script the name was
# still set from the assertion above. Each assertion now runs in its own process against
# its own tree, so an inherited path would be an unset variable under `set -u`.
GV_F="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

if grep -q -- '--require-skill' "$GV_F"; then
  sed -i.bak 's/--require-skill/--require-SKILL/g' "$GV_F"
  out="$(vrun)"
  if mx_red A17-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A17-m1 "A17-m1: an unparseable arm grammar FAILS I32 loudly ('nothing to compare' never reads as 'the pins agree')"
  else
    bad "A17-m1 SURVIVED: breaking the arm grammar did NOT fail I32 — the check goes vacuous exactly when the arms become unreadable"
  fi
  mx_twins A17-m1 "$out"
else
  bad "FIXTURE STALE: Check 17's arms no longer carry --require-skill"
fi
}

# --- Assertion 17: I33 FIXTURE PATH WALK --------------------------------------
# A fixture that locates a core file by walking up from a path ANOTHER resolver produced is
# green in the distribution and red on every consumer, because the install mapping splits the
# subtrees (core/scripts -> scripts/ai-dlc, core/schemas -> .claude/schemas). Step 2 requires
# the derived fixtures green BEFORE the push, so that red is a permanent stop on the
# self-update — it shipped once and blocked a consumer's cycle. Reintroduce the walk and I33
# must name the offending fixture.
A18_i33_fixture_path_walk() {
SP_F="$ROOT/core/fixtures/story-provenance/run.sh"
# The walk is COMPOSED, never written literally. I33 greps for the pattern, so a fixture that
# spelled its own mutant out would flag itself — the same self-reference trap the ledger's close
# vocabulary hit. Split across the quote boundary, the two halves are not adjacent in THIS file
# and are adjacent in the file it writes, which is the only place it matters.
if grep -q -- '--print-schema' "$SP_F"; then
  walk='$(dirname "$WRITER")/..'"/schemas/provenance-block.json"
  sed -i.bak "s@^SCHEMA_SRC=.*\$@SCHEMA_SRC=\"$walk\"@" "$SP_F"
  out="$(vrun)"
  if mx_red A18-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A18-m1 "A18-m1: a fixture walking up from a resolved script into another core subtree FAILS I33"
  else
    bad "A18-m1 SURVIVED: the walk-up path was not caught by I33 — a fixture can go green here and red on every consumer again"
  fi
  mx_twins A18-m1 "$out"
  SP_F="$ROOT/core/fixtures/story-provenance/run.sh"
else
  bad "FIXTURE STALE: story-provenance/run.sh no longer resolves its schema via --print-schema"
fi
}

# --- Assertion 18: I33 NON-VACUITY --------------------------------------------
# I33 greps a tree. Empty that tree and it finds nothing and reports clean — the exact reading
# ("no hits" = "no defect") that the check exists to distinguish from a real pass.
A19_i33_non_vacuity() {
if [ -d "$ROOT/core/fixtures" ]; then
  find "$ROOT/core/fixtures" -name '*.sh' -type f -delete 2>/dev/null
  out="$(vrun)"
  if mx_red A19-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A19-m1 "A19-m1: an empty fixture tree FAILS I33 loudly (a scan over nothing never reads as clean)"
  else
    bad "A19-m1 SURVIVED: I33 reported clean over an empty fixture tree — 'no hits' is indistinguishable from 'no defect'"
  fi
  mx_twins A19-m1 "$out"
else
  bad "FIXTURE STALE: the seed no longer copies core/fixtures/"
fi
}

# --- Assertion 19: I26 — the core set stays DERIVED, never restated -----------
# I26 HAD NO FIXTURE AT ALL until v0.190.0, and it was found the way this repo usually finds
# them: while making the invariant FASTER. An optimisation to a check nothing self-tests is a
# change whose only evidence is that the output looked the same, which is the same standard the
# restated list itself passed for six releases.
#
# The mutation plants exactly what I26 exists to reject: one line naming three derived manifest
# entries, which is a LIST. A reference stands alone; a list puts them on one line, and that
# punctuation adjacency is the whole predicate. The entries are taken from the manifest the
# check derives from, so the mutation cannot go stale against a hand-list here.
A20_i26_derived_core_set() {
GV="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
if ! grep -q '<!-- CHECK_LOADED: core-layer-immutability -->' "$GV" 2>/dev/null; then
  bad "FIXTURE STALE: gate-validation.md has no core-layer-immutability span to mutate"
else
  cp "$GV" "$GV.orig"
  awk '{ print }
       /<!-- CHECK_LOADED: core-layer-immutability -->/ {
         print "The authoritative core paths are `team-roles/*.md`, `steps/*.md` and `templates/*.md`."
       }' "$GV.orig" > "$GV"
  if cmp -s "$GV.orig" "$GV"; then
    bad "FIXTURE BROKEN: the I26 mutation matched nothing, so this assertion is unproven"
  else
    out="$(vrun)"
    if mx_red A20-m1 "$out"; then
      mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A20-m1 "A20-m1: a line naming three manifest entries FAILS I26 (the derived set cannot be quietly replaced by a list)"
    else
      bad "A20-m1 SURVIVED: a restated core path list did NOT fail I26 — the check that stopped six core subtrees being silently skipped is not firing"
    fi
    mx_twins A20-m1 "$out"
  fi
fi
}

# --- Assertion 20: I40 — the anchor reading cannot fork -----------------------
# Three functions are byte-identical across `core/scripts/validate-layer-entries.sh` (ERRORs at
# authoring time) and `reconcile/lib.sh` (reports at pull time). They are COPIES because neither
# tree may source the other's file — I25's reason and I29's — so an assertion is the only thing
# stopping the drift, and every one of the three has already forked once in this repo's history.
#
# TWO ARMS, because the vacuity arm is the one that matters: I40 LOCATES its subjects by awk
# range, and a renamed or deleted function makes it find nothing. "Found nothing" and "found two
# identical bodies" are the same green unless the check says so itself.
A21_i40_anchor_reading() {
LIBSH="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
if [ ! -f "$LIBSH" ]; then
  bad "FIXTURE STALE: the seed no longer copies reconcile/lib.sh, so I40 has nothing to bind"
else
  cp "$LIBSH" "$LIBSH.orig"

  # ARM 1 — FORK. `length(hn) > 3` is the reverse-arm noise floor shared with span_of. Nudging
  # it in ONE copy is the exact shape of the divergence I40 exists to catch: both tools still
  # run, both still report, and they disagree about which anchors are loose.
  sed 's/if (length(hn) > 3 \&\& w != "" \&\& index(w, hn) > 0/if (length(hn) > 5 \&\& w != "" \&\& index(w, hn) > 0/' "$LIBSH.orig" > "$LIBSH"
  if cmp -s "$LIBSH.orig" "$LIBSH"; then
    bad "FIXTURE BROKEN: the I40 fork mutation matched nothing, so this assertion is unproven"
  else
    out="$(vrun)"
    if mx_red A21-m1 "$out"; then
      mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A21-m1 "A21-m1: a one-copy change to the anchor arm FAILS I40 (the linter and the pull classifier cannot disagree)"
    else
      bad "A21-m1 SURVIVED: a forked anchor_arm() did NOT fail I40 — the two tools can now answer the same question differently and the operator believes whichever they ran"
    fi
    mx_twins A21-m1 "$out"
  fi

  # ARM 2 — VACUITY. Delete one subject outright. I40 must say it cannot find it, not pass.
  awk 'BEGIN{s=0} /^shadow_parts\(\) \{/{s=1} s==0{print} /^\}/{if(s==1){s=2; next}}' "$LIBSH.orig" > "$LIBSH"
  if cmp -s "$LIBSH.orig" "$LIBSH"; then
    bad "FIXTURE BROKEN: the I40 deletion mutation matched nothing, so the vacuity assertion is unproven"
  else
    out="$(vrun)"
    if mx_red A21-m2 "$out"; then
      mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A21-m2 "A21-m2: a MISSING bound function FAILS I40 loudly (finding nothing never reads as agreement)"
    else
      bad "A21-m2 SURVIVED: I40 reported clean with shadow_parts() deleted from one side — a rename silently retires the binding"
    fi
    mx_twins A21-m2 "$out"
  fi
fi
}

# --- Assertion 21: I45 — core stays out of the reserved consumer band ---------
# I45 is the CORE half of E15's partition, and it is the half a consumer cannot check.
# E15 tells an author to renumber into the band at 900; the only thing that makes that
# advice safe is core never allocating there. If I45 stops firing, nothing anywhere
# notices until core ships the allocation, and by then the collision has landed
# retroactively across gate logs that are the audit record.
#
# THREE ARMS, and the two vacuity arms are the load-bearing ones. I45 reports an
# ABSENCE — "no core number is in the band" — so every way of finding nothing produces
# its PASS. It reads its floor and its two catalog extractors out of
# validate-layer-entries.sh, and a rename at either end returns empty rather than
# wrong. Arm 1 proves it can fire; arms 2 and 3 prove that not-firing means something.
#
# Each arm asserts on its OWN message, never on the shared token "I45": the fire arm
# and the vacuity arms would otherwise both match a grep for the invariant's name, and
# an assertion two arms can satisfy is one that tests neither.
A22_i45_reserved_band() {
SKB="$ROOT/core/skills/ai-dlc/SKILL.md"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 1 — FIRE, on the RULE side deliberately. The check side entangles: a `### 900.`
# heading in gate-validation.md also trips the CHECK_LOADED-anchor arm, so it produces
# two failures and neither one isolates I45. Measured, not assumed — 2 FAIL lines. The
# rulebook has no such second reader, so this mutation fires exactly one assertion.
#
# It is also the arm with the live detonation date: core is AT Rule 32, so Rule 33 is
# the next integer core allocates. The reference consumer no longer collides there — it
# has migrated its own rules into the reserved band (913-932), so the numbers it once
# held at 31 and 32 are free and core took both. Re-measure before quoting this: the
# detonation is real only while a consumer still allocates below the floor.
cp "$SKB" "$SKB.orig"
printf '\n### Rule 900 -- A core rule allocated inside the consumer band\n\nBody.\n' >> "$SKB"
if cmp -s "$SKB.orig" "$SKB"; then
  bad "FIXTURE BROKEN: the I45 fire mutation did not change SKILL.md, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A22-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A22-m1 "A22-m1: a core rule numbered 900 FAILS I45 (core cannot allocate from the range E15 tells consumers to move into)"
  else
    bad "A22-m1 SURVIVED: core allocated Rule 900 and I45 stayed silent — the band is a promise to consumers with nothing holding core to it"
  fi
  mx_twins A22-m1 "$out"
fi
cp "$SKB.orig" "$SKB"; rm -f "$SKB.orig"

# ARM 1b — THE ALPHABETIC HALF, which is a separate partition and needs its own fire
# arm. A band is numeric and alphabetic ids have no ordering in one, so they are
# partitioned by a reserved PREFIX instead: the consumer takes `X…`, core takes
# everything else. The numeric arm above cannot reach this — `XAP` has no leading
# integer — so without this assertion core could allocate straight into the range a
# consumer renamed `AP` into, and I45 would report clean. On the reference consumer that
# is not hypothetical: it defines `AP`, `VH`, and its own `H1` which core also defines,
# and four releases of a numeric-only band could see none of them.
GVB="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
cp "$GVB" "$GVB.orig"
printf '\n### XAP. A core check allocated inside the consumer alphabetic prefix\n<!-- CHECK_LOADED: XAP -->\n\nBody.\n' >> "$GVB"
if cmp -s "$GVB.orig" "$GVB"; then
  bad "FIXTURE BROKEN: the I45 alphabetic fire mutation did not change gate-validation.md, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A22-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A22-m2 "A22-m2: a core check id 'XAP' FAILS I45 (the alphabetic half of the partition has a mechanism, not just a paragraph)"
  else
    bad "A22-m2 SURVIVED: core allocated check 'XAP' and I45 stayed silent — a consumer that renamed 'AP' into the reserved prefix has bought nothing, and the collision it migrated to escape reappears upstream for every consumer at once"
  fi
  mx_twins A22-m2 "$out"
fi
cp "$GVB.orig" "$GVB"; rm -f "$GVB.orig"

# ARM 1c — VACUITY, the prefix. Same shape as the floor arm below and for the same
# reason: an unreadable BAND_ALPHA_PREFIX makes every core alphabetic id conforming,
# which is this arm's PASS. It has to fail loudly instead.
VLE="$ROOT/core/scripts/validate-layer-entries.sh"
VLE_BAK="$(mkbak "$VLE")"
sed 's/^BAND_ALPHA_PREFIX=/BAND_ALPHA_SUFFIX=/' "$VLE_BAK" > "$VLE"
if cmp -s "$VLE_BAK" "$VLE"; then
  bad "FIXTURE BROKEN: the I45 alphabetic-prefix mutation matched nothing, so its vacuity assertion is unproven"
else
  out="$(vrun)"
  if mx_red A22-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A22-m3 "A22-m3: an unreadable BAND_ALPHA_PREFIX FAILS I45 loudly (a prefix it cannot read would make every core alphabetic id conforming)"
  else
    bad "A22-m3 SURVIVED: I45 reported clean with BAND_ALPHA_PREFIX renamed — the alphabetic half retires itself silently the moment the constant moves"
  fi
  mx_twins A22-m3 "$out"
fi
cp "$VLE_BAK" "$VLE"; rm -f "$VLE_BAK"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 2 — VACUITY, the floor. Rename BAND_FLOOR and I45 can no longer say which
# numbers are core's. Reporting nothing would be indistinguishable from a conforming
# tree, and it would stay that way through every later release.
VLE_BAK="$(mkbak "$VLE")"
sed 's/^BAND_FLOOR=/BAND_CEILING=/' "$VLE_BAK" > "$VLE"
if cmp -s "$VLE_BAK" "$VLE"; then
  bad "FIXTURE BROKEN: the I45 floor mutation matched nothing, so the vacuity assertion is unproven"
else
  out="$(vrun)"
  if mx_red A22-m4 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A22-m4 "A22-m4: an unreadable BAND_FLOOR FAILS I45 loudly (a floor it cannot read would make every core number conforming)"
  else
    bad "A22-m4 SURVIVED: I45 reported clean with BAND_FLOOR renamed — the invariant retires itself silently the moment the constant moves"
  fi
  mx_twins A22-m4 "$out"
fi
cp "$VLE_BAK" "$VLE"; rm -f "$VLE_BAK"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 3 — VACUITY, the catalog. I45 runs the SHIPPING extractors rather than copies of
# their grammars, which is what stops it answering differently from the check it
# complements — but it also means a renamed extractor returns an empty catalog, and an
# empty catalog contains nothing above the floor. That is I45's PASS reached by finding
# nothing, which is this repo's named defect class sitting inside the invariant.
VLE_BAK="$(mkbak "$VLE")"
sed 's/^defined_anchors() {/defined_anchor_set() {/' "$VLE_BAK" > "$VLE"
if cmp -s "$VLE_BAK" "$VLE"; then
  bad "FIXTURE BROKEN: the I45 extractor mutation matched nothing, so the catalog vacuity assertion is unproven"
else
  out="$(vrun)"
  if mx_red A22-m5 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A22-m5 "A22-m5: a renamed catalog extractor FAILS I45 loudly (an empty catalog never reads as a conforming one)"
  else
    bad "A22-m5 SURVIVED: I45 reported clean with defined_anchors() renamed — it was scanning nothing and calling it agreement"
  fi
  mx_twins A22-m5 "$out"
fi
rm -f "$VLE_BAK"
}

# --- Assertion 22: I47 — the check-heading grammar cannot fork ----------------
# CHECK_HEAD_RE decides what counts as a check DEFINITION, and two tools reach
# opposite verdicts if it forks. The linter uses it to harvest the ids a layer
# entry allocates; the manifest resolver uses it to report a definition that never
# became loadable (GM1). GM1's whole subject is checks that NOTHING else reports —
# neither MISSING (needs a row) nor ORPHAN (needs an anchor) — so a narrowed copy
# in the resolver restores exactly the silence GM1 was written to end, with a green
# build and no other symptom anywhere.
#
# TWO ARMS, and the second is the load-bearing one for the same reason I45's are:
# I47 reports an absence, so a rename at either end makes it find nothing and pass.
# Each asserts on its OWN message — "has forked" vs "could not find" — because a
# grep for "I47" is satisfied by both and would test neither.
A23_i47_check_heading() {
VGM="$ROOT/core/scripts/validate-gate-manifest.sh"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 1 — FORK. Narrow the resolver's copy to headings of two or more digits. That
# is a real regression shape rather than a nonsense one: it still matches, still
# looks like the grammar, and silently drops every single-digit check definition.
VGM_BAK="$(mkbak "$VGM")"
sed "s/^CHECK_HEAD_RE='.*\$/CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?[0-9][0-9]+[a-z-]*\\\\.'/" "$VGM_BAK" > "$VGM"
if cmp -s "$VGM_BAK" "$VGM"; then
  bad "FIXTURE BROKEN: the I47 fork mutation matched nothing, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A23-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A23-m1 "A23-m1: a narrowed CHECK_HEAD_RE in the resolver FAILS I47 (a definition one tool sees and the other cannot)"
  else
    bad "A23-m1 SURVIVED: the two copies of the check-heading grammar diverged and I47 stayed silent — GM1's subject set can shrink with the build green"
  fi
  mx_twins A23-m1 "$out"
fi
cp "$VGM_BAK" "$VGM"; rm -f "$VGM_BAK"
VGM="$ROOT/core/scripts/validate-gate-manifest.sh"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 2 — VACUITY. Rename the assignment in the linter and I47 locates one side of
# the join. Comparing against nothing is its PASS.
VLE_BAK="$(mkbak "$VLE")"
sed "s/^CHECK_HEAD_RE=/CHECK_HEADING_RE=/" "$VLE_BAK" > "$VLE"
if cmp -s "$VLE_BAK" "$VLE"; then
  bad "FIXTURE BROKEN: the I47 vacuity mutation matched nothing, so the second arm is unproven"
else
  out="$(vrun)"
  if mx_red A23-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A23-m2 "A23-m2: a renamed CHECK_HEAD_RE FAILS I47 loudly (a join that cannot locate a side never passes by comparing nothing)"
  else
    bad "A23-m2 SURVIVED: I47 reported clean with the assignment renamed — it was comparing nothing and calling it agreement"
  fi
  mx_twins A23-m2 "$out"
fi
cp "$VLE_BAK" "$VLE"; rm -f "$VLE_BAK"
VGM="$ROOT/core/scripts/validate-gate-manifest.sh"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 3 — THE PAIR-OF-PAIRS FORK, and it is the one the other two cannot reach. Arms 1
# and 2 both move ONE detector, so both are caught by the lint-vs-resolver comparison
# alone. The failure this invariant was extended for moved NEITHER out of step with the
# other: the rewriter's ANCHOR_RE widened for alphabetic ids and the `—` terminator, both
# detectors stayed numeric-and-dot, and every pair-check stayed green while `Check AP` and
# `Check VH` were live and unreportable. So the mutation narrows BOTH detectors, together,
# back to that exact pre-release grammar — arm 1's comparison is satisfied by construction
# and only the detectors-vs-rewriter arm can fire.
#
# There is no fourth arm for the "cannot find ANCHOR_RE" branch on purpose. I15 reads the
# same assignment, so deleting or renaming it fails both invariants and neither mutant
# would be attributable — assertion 21 above already proves that absence fails loudly.
VGM_BAK="$(mkbak "$VGM")"; VLE_BAK="$(mkbak "$VLE")"
NARROW="CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?[0-9]+[a-z-]*\\\\.'"
sed "s|^CHECK_HEAD_RE=.*|$NARROW|" "$VGM_BAK" > "$VGM"
sed "s|^CHECK_HEAD_RE=.*|$NARROW|" "$VLE_BAK" > "$VLE"
if cmp -s "$VGM_BAK" "$VGM" || cmp -s "$VLE_BAK" "$VLE"; then
  bad "FIXTURE BROKEN: the I47 pair-of-pairs mutation matched nothing in one or both detectors, so this assertion is unproven"
elif ! cmp -s "$VGM" "$VLE" && ! diff <(grep '^CHECK_HEAD_RE=' "$VGM") <(grep '^CHECK_HEAD_RE=' "$VLE") >/dev/null; then
  bad "FIXTURE BROKEN: the two narrowed detectors are not byte-identical, so arm 1 could fire and this assertion would not be attributable"
else
  out="$(vrun)"
  if grep -q "the check-heading grammar has forked between" <<<"$out"; then
    bad "A23-m3: the pair-of-pairs mutant tripped arm 1 as well — the two mutations are entangled and this arm proves nothing"
  elif grep -q "the DETECTORS' check-heading grammar and the REWRITER's have forked" <<<"$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A23-m3 "A23-m3: narrowing BOTH detectors in step FAILS I47 (a heading the rewriter relabels that no detector reports — green under every pair-check)"
  else
    bad "A23-m3: both detectors reverted to the numeric grammar and I47 stayed silent — the fork that hid two live unloadable checks can reopen"
  fi
  mx_twins A23-m3 "$out"
fi
rm -f "$VGM_BAK" "$VLE_BAK"
}

# --- Assertion 23: I49 — a mode named in prose is a mode the script dispatches --
# Three of core's enforcement surfaces reach `core-paths.sh` through a STRING typed into a
# rule file an AGENT follows. A mode that does not exist prints usage and exits 2, and 2 is
# this resolver's "cannot determine what core is" — so a typo in a paragraph and an
# unreadable manifest arrive at the gate as the same answer, and the recoverable one wears
# the irrecoverable one's clothes.
#
# THREE ARMS, each asserting on its OWN message. A grep for "I49" is satisfied by all three
# and would test none of them — row 4's recorded trap, where two arms quoting one string let
# an assertion pass against a reverted fix.
A24_i49_resolver_modes() {
CP="$ROOT/core/scripts/core-paths.sh"
GV="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

# ARM 1 — GHOST MODE. The gate check body names a mode one character off. This is the
# realistic shape: a rename lands in the script and the paragraph keeps the old spelling.
#
# The ghost spelling is ASSEMBLED, never written out. I49 excludes core/fixtures/ from its
# citation corpus for exactly this reason, and a fixture that leans on that exclusion to
# hold its own text would go red the day the exclusion is reconsidered — for a reason with
# nothing to do with what it tests.
ghost="--audit-diff""s"
cp "$GV" "$GV.orig"
sed "s@core-paths\\.sh --audit-diff@core-paths.sh ${ghost}@" "$GV.orig" > "$GV"
if cmp -s "$GV.orig" "$GV"; then
  bad "FIXTURE BROKEN: the I49 ghost-mode mutation matched nothing, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A24-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A24-m1 "A24-m1: a rule file naming a core-paths.sh mode the dispatch rejects FAILS I49 (the call would exit 2, which the caller reads as 'cannot determine')"
  else
    bad "A24-m1 SURVIVED: the gate check body named a nonexistent resolver mode and I49 stayed silent — a typo in a paragraph now reports as an unreadable manifest"
  fi
  mx_twins A24-m1 "$out"
fi
cp "$GV.orig" "$GV"; rm -f "$GV.orig"
CP="$ROOT/core/scripts/core-paths.sh"
GV="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

# ARM 2 — UNDOCUMENTED MODE. Drop a mode from usage(). The callers are prose, updated by
# whoever read the usage text, so a mode missing from it is a mode no rename can reach.
CP_BAK="$(mkbak "$CP")"
grep -v 'core-paths.sh --list \[<manifest>\]" >&2' "$CP_BAK" > "$CP"
if cmp -s "$CP_BAK" "$CP"; then
  bad "FIXTURE BROKEN: the I49 undocumented-mode mutation matched nothing, so the second arm is unproven"
else
  out="$(vrun)"
  if mx_red A24-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A24-m2 "A24-m2: a dispatched mode missing from usage() FAILS I49 (a mode no operator can discover)"
  else
    bad "A24-m2 SURVIVED: a mode vanished from usage() and I49 reported clean — the discoverable set and the dispatched set can now diverge"
  fi
  mx_twins A24-m2 "$out"
fi
cp "$CP_BAK" "$CP"; rm -f "$CP_BAK"
CP="$ROOT/core/scripts/core-paths.sh"
GV="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

# ARM 3 — VACUITY. Rename the sentinel the dispatch extraction is bounded by. I49 reports an
# ABSENCE (nothing cited that is not dispatched), and an empty dispatched set makes every
# citation a ghost — or, without the zero guard, makes `comm` compare against nothing and
# report agreement it never computed.
CP_BAK="$(mkbak "$CP")"
sed 's@# MODE_DISPATCH_BEGIN@# MODE_TABLE_BEGIN@' "$CP_BAK" > "$CP"
if cmp -s "$CP_BAK" "$CP"; then
  bad "FIXTURE BROKEN: the I49 vacuity mutation matched nothing, so the third arm is unproven"
else
  out="$(vrun)"
  if mx_red A24-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A24-m3 "A24-m3: a renamed dispatch sentinel FAILS I49 loudly (an empty set is a subset of everything, so the join must refuse rather than agree)"
  else
    bad "A24-m3 SURVIVED: the dispatch extraction found nothing and I49 did not say so — it was comparing against an empty set and calling it agreement"
  fi
  mx_twins A24-m3 "$out"
fi
rm -f "$CP_BAK"
}

# --- Assertion 24: I50 — a validator named in prose is a validator core ships --
# install.sh DERIVES scripts/ai-dlc/ from core/scripts/, so a citation naming a file core
# does not ship resolves to nothing in every consumer tree. The agent told to run it gets
# a command that fails to start, and no report — which is what a clean run looks like.
#
# THREE ARMS. The two ghost arms differ by which half of the corpus they mutate and each
# asserts on ITS OWN ghost NAME, never on the shared message: an arm that greps only for
# "does not ship" would be satisfied by the other arm's mutation and would prove nothing
# about the corpus boundary it exists to hold.
#
# Both ghost names are ASSEMBLED at runtime. I50 excludes core/fixtures/ because thirteen
# fixtures deliberately name validators that do not exist, and an assertion that leans on
# that exclusion to hold its own text goes red the day the exclusion is reconsidered.
A25_i50_shipped_validators() {
DEV="$ROOT/core/team-roles/dev.md"
TPL="$ROOT/templates/audit-anchors.md.template"

# ARM 1 — GHOST IN A ROLE FILE. The realistic shape: a validator is renamed and the
# paragraph that tells the dev to run it keeps the old filename.
ghost_a="validate-mutation""-gone.sh"
cp "$DEV" "$DEV.orig"
sed "s@scripts/ai-dlc/validate-mutation-red\\.sh@scripts/ai-dlc/${ghost_a}@" "$DEV.orig" > "$DEV"
if cmp -s "$DEV.orig" "$DEV"; then
  bad "FIXTURE BROKEN: the I50 role-file ghost mutation matched nothing, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A25-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A25-m1 "A25-m1: a role file naming a validator core does not ship FAILS I50 (the command does not exist in any consumer tree)"
  else
    bad "A25-m1 SURVIVED: a role file told an agent to run a validator core does not ship and I50 stayed silent — the command that never ran reports what a clean run reports"
  fi
  mx_twins A25-m1 "$out"
fi
# Restoring the one mutated file, rather than re-seeding the whole tree: each `restore`
# copies ~1.4 MB and this fixture is already the suite's wall-clock floor. The mutation is
# one file plus its own .orig, so moving it back leaves the seed pristine.
mv "$DEV.orig" "$DEV"

# ARM 2 — GHOST IN A TEMPLATE. templates/ is installed into the consumer's tree, so a dead
# citation there is dead in the same place for the same reader. This arm exists because the
# corpus boundary is the part of I50 that can narrow silently: drop templates/ from the
# grep and arm 1 still passes.
ghost_b="validate-audit""-vanished.sh"
cp "$TPL" "$TPL.orig"
sed "/RENDERED from it by/s@scripts/ai-dlc/validate-audit-anchors\\.sh@scripts/ai-dlc/${ghost_b}@" "$TPL.orig" > "$TPL"
if cmp -s "$TPL.orig" "$TPL"; then
  bad "FIXTURE BROKEN: the I50 template ghost mutation matched nothing, so the second arm is unproven"
else
  out="$(vrun)"
  if mx_red A25-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A25-m2 "A25-m2: a consumer-installed template naming a validator core does not ship FAILS I50 (templates/ is inside the corpus)"
  else
    bad "A25-m2 SURVIVED: a template cited a validator core does not ship and I50 reported clean — half its corpus is outside what it reads"
  fi
  mx_twins A25-m2 "$out"
fi
mv "$TPL.orig" "$TPL"

# ARM 2b — A NON-ASCII GHOST. The citation class was `[A-Za-z0-9_.-]`, which cannot spell
# `café.sh`, so a role file naming a non-ASCII validator core does not ship was not a citation
# at all and I50 passed it. The ghost is assembled from octal escapes so this file carries no
# literal of it. Its mutant restores the ASCII class in the SEEDED validator copy and must go
# silent on the same mutation, so the kill is the class and not the corpus.
ghost_c="$(printf 'validate-caf\303\251')-gone.sh"
cp "$DEV" "$DEV.orig"
sed "s@scripts/ai-dlc/validate-mutation-red\\.sh@scripts/ai-dlc/${ghost_c}@" "$DEV.orig" > "$DEV"
if cmp -s "$DEV.orig" "$DEV"; then
  bad "FIXTURE BROKEN: the I50 non-ASCII ghost mutation matched nothing, so arm 2b is unproven"
else
  out="$(vrun)"
  if mx_red A25-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A25-m3 "A25-m3: a role file naming a NON-ASCII validator core does not ship FAILS I50 (the class spells it)" && B_a25m3=1
  else
    bad "A25-m3 SURVIVED: a role file named a non-ASCII validator core does not ship and I50 stayed silent — its class cannot spell the name"
  fi
  mx_twins A25-m3 "$out"
  cp "$V" "$V.orig"
  # The class is rewritten BY POSITION on the one `i50_cited=` line -- from `scripts/ai-dlc/[` to
  # the `]+\.(sh|js)` that closes it -- so this file carries no retyped copy of the shipped class.
  python3 -c 'import sys
L = open(sys.argv[1]).read().split("\n")
hit = [i for i, l in enumerate(L) if l.startswith("i50_cited=")]
if len(hit) != 1: sys.exit(3)
l = L[hit[0]]; a = l.find("scripts/ai-dlc/["); b = l.find("]+\\.(sh|js)", a + 16)
if a < 0 or b < 0: sys.exit(4)
L[hit[0]] = l[:a] + "scripts/ai-dlc/[A-Za-z0-9_.-" + l[b:]
open(sys.argv[1], "w").write("\n".join(L))' "$V" 2>/dev/null; m_rc=$?
  if [ "$m_rc" -ne 0 ] || cmp -s "$V.orig" "$V"; then
    bad "FIXTURE BROKEN: the I50 ASCII-class mutant did not apply (rc=$m_rc) -- the citation grep was respelled"
  else
    out="$(vrun)"
    if grep -qF "$ghost_c" <<<"$out"; then
      bad "A25-m4: mutant (I50 ASCII class) SURVIVED: the restored class still reported the non-ASCII ghost"
    elif grep -q "I50 derived an EMPTY set" <<<"$out"; then
      bad "A25-m4: mutant (I50 ASCII class) went EMPTY instead of narrow -- the mutation broke the grep, not the class"
    else
      mutant_killed "${B_a25m3:-0}" A25-m4 "A25-m4: mutant (I50 ASCII class) killed: the restored class cannot spell the non-ASCII ghost and I50 goes silent"
    fi
    mx_twins A25-m4 "$out"
  fi
  mv "$V.orig" "$V"
fi
mv "$DEV.orig" "$DEV"

# ARM 3 — VACUITY. I50 reports an ABSENCE (nothing cited that is not shipped). With the
# shipped set empty every citation is a ghost, and without the zero guard `comm` compares
# against nothing and reports an agreement it never computed. Other invariants also error
# in this run — core/scripts/ is where several of them read from — which is why the
# assertion is on I50's own EMPTY-set wording and not on the validator's exit status.
mv "$ROOT/core/scripts" "$ROOT/core/scripts.hidden"
out="$(vrun)"
mv "$ROOT/core/scripts.hidden" "$ROOT/core/scripts"
if mx_red A25-m5 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A25-m5 "A25-m5: an empty shipped-validator set FAILS I50 loudly (an empty set contains nothing, so every citation would be a ghost and the join must refuse)"
else
  bad "A25-m5 SURVIVED: the shipped-validator set was empty and I50 did not say so — it was comparing citations against nothing"
fi
mx_twins A25-m5 "$out"
# The mv back above is the restore: this arm moved a directory and moved it home again.
}

# --- Assertion 22: I51 — the licensed commit has one subject in two files ------
# Step 5b licenses one commit to the trunk outside a PR (not the pipeline's only one — §7a-post
# commits the log rotation there too — but the only one bounded at push time), and the subject
# it tells the lead to type is matched at push time by a regex in the schema. The two are
# not derivable from each other by equality — one is a template with <N>/<PR>, the other a
# regex — so the join fills the template and matches it, exactly as the lead and then the
# matcher do. Drift here surfaces at the worst possible moment: the retro PR has already
# merged, the SHA is only knowable now, and the one commit that carries it will not land.
#
# THREE ARMS, each asserting its OWN wording. All three would match a grep for "I51", so an
# assertion on the invariant's name is one that tests none of them.
A26_i51_licensed_commit() {
AAJ="$ROOT/core/schemas/audit-anchors.json"
RTR="$ROOT/core/skills/ai-dlc/steps/retro.md"

# ARM 1 — PROSE DRIFTS FROM THE MATCHER. The template still parses (it keeps the
# chore(s<N>) opening the extractor keys on), so this reaches the comparison rather than
# the vacuity arm. That distinction is the whole point of having arm 3 as well.
cp "$RTR" "$RTR.orig"
sed 's@SHA after retro PR #<PR> merge@SHA for retro PR #<PR>@' "$RTR.orig" > "$RTR"
if cmp -s "$RTR.orig" "$RTR"; then
  bad "FIXTURE BROKEN: the I51 template mutation matched nothing, so the prose-drift arm is unproven"
else
  out="$(vrun)"
  if mx_red A26-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A26-m1 "A26-m1: a Step 5b template the schema regex rejects FAILS I51 (a lead following the step file would write an unlandable commit)"
  else
    bad "A26-m1 SURVIVED: the step file and the push-time matcher disagreed on the licensed subject and I51 reported clean"
  fi
  mx_twins A26-m1 "$out"
fi
mv "$RTR.orig" "$RTR"

# ARM 2 — THE REMEDY CONTRADICTS THE RULE. --trunk-push prints subject_example as the fix
# on every rejection. An example its own pattern rejects sends the consumer round the loop
# a second time, which is worse than no example at all.
cp "$AAJ" "$AAJ.orig"
sed 's@"subject_example": "chore(s299)@"subject_example": "chore(S299)@' "$AAJ.orig" > "$AAJ"
if cmp -s "$AAJ.orig" "$AAJ"; then
  bad "FIXTURE BROKEN: the I51 example mutation matched nothing, so the remedy arm is unproven"
else
  out="$(vrun)"
  if mx_red A26-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A26-m2 "A26-m2: an example its own pattern rejects FAILS I51 (the rejection message would hand the consumer a subject the same run refuses)"
  else
    bad "A26-m2 SURVIVED: backfill_commit carried an example its own pattern rejects and I51 reported clean"
  fi
  mx_twins A26-m2 "$out"
fi
mv "$AAJ.orig" "$AAJ"

# ARM 3 — VACUITY. I51 reports an ABSENCE (no disagreement). Both sides are EXTRACTED —
# one by a JSON key, one by a regex over prose — and prose is the side that moves. Delete
# the template and there is nothing to disagree with, which is indistinguishable from
# agreement unless the derivation refuses. This arm is why the ZERO branch exists.
cp "$RTR" "$RTR.orig"
sed '/chore(s<N>): backfill audit-anchor SHA/d' "$RTR.orig" > "$RTR"
if cmp -s "$RTR.orig" "$RTR"; then
  bad "FIXTURE BROKEN: the I51 vacuity mutation matched nothing, so the zero guard is unproven"
else
  out="$(vrun)"
  if mx_red A26-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A26-m3 "A26-m3: a retro.md with no subject template FAILS I51 loudly (nothing to compare must not read as the two agreeing)"
  else
    bad "A26-m3 SURVIVED: the prose side of I51 vanished and the invariant reported agreement it never computed"
  fi
  mx_twins A26-m3 "$out"
fi
mv "$RTR.orig" "$RTR"
}

# --- Assertion 25: I52 — the drivability exemption marker cannot fork ----------
# `validate-fixture-drivability.sh` is SHIPPED and wired into the consumer's pre-push,
# and it judges tests/fixtures/ — where install.sh puts CORE's fixtures. Two of core's
# are legitimately driverless and pass only by carrying I20's marker in their READMEs.
# A diverged marker therefore does not fail the author who moved it; it fails every
# consumer's next push, on core files they did not write. That is why the join exists
# and why its arms assert on their own wording rather than on the exit status.
A27_i52_exemption_marker() {
FDS="$ROOT/core/scripts/validate-fixture-drivability.sh"

# ARM 1 — DIVERGENCE. The realistic shape: the marker is reworded in one home. Asserted
# on the GHOST text, not on the word "differs", so the vacuity arm below cannot satisfy it.
ghost_m="No \`driver.sh\`"", deliberately"
FDS_BAK="$(mkbak "$FDS")"
sed "s@^EXEMPT_MARKER='.*'\$@EXEMPT_MARKER='${ghost_m}'@" "$FDS_BAK" > "$FDS"
if cmp -s "$FDS_BAK" "$FDS"; then
  bad "FIXTURE BROKEN: the I52 divergence mutation matched nothing, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A27-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A27-m1 "A27-m1: a reworded marker in the shipped validator FAILS I52 (core's two driverless fixtures would fail every consumer's push)"
  else
    bad "A27-m1 SURVIVED: the shipped validator's exemption marker diverged from I20's and I52 stayed silent — core's own fixtures would start failing consumers who changed nothing"
  fi
  mx_twins A27-m1 "$out"
fi
cp "$FDS_BAK" "$FDS"; rm -f "$FDS_BAK"

# ARM 2 — VACUITY. I52 compares two EXTRACTED strings, and the extraction is a sed over a
# line shape. Break the shape and both sides can come back empty, where `!=` is false and
# the join reports an agreement it never computed. Asserted on I52's own read-failure
# wording, which names the file it could not read — arm 1's message never contains it.
FDS_BAK="$(mkbak "$FDS")"
sed "s@^EXEMPT_MARKER=.*\$@EXEMPT_MARKER=\"whatever\"@" "$FDS_BAK" > "$FDS"
if cmp -s "$FDS_BAK" "$FDS"; then
  bad "FIXTURE BROKEN: the I52 vacuity mutation matched nothing, so the zero guard is unproven"
else
  out="$(vrun)"
  if mx_red A27-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A27-m2 "A27-m2: an unreadable marker in the shipped validator FAILS I52 loudly (two empty strings compare equal, and that is not agreement)"
  else
    bad "A27-m2 SURVIVED: I52 could not extract the shipped validator's marker and passed anyway — it compared nothing against nothing"
  fi
  mx_twins A27-m2 "$out"
fi
cp "$FDS_BAK" "$FDS"; rm -f "$FDS_BAK"
}

# --- Assertion 26: I53 — a mode one core script asks another for is one it dispatches --
# `core-paths.sh --audit-diff` decides whether the operator authorized an in-place core edit
# by CALLING `validate-escalation-resolution.sh --any-authorized` instead of restating that
# script's citation grammar. Delegation beats restatement only while the mode on the other
# side is real: an unknown argument exits 2, the caller reads any non-zero as "no citation",
# and the backstop starts FAILing consumers whose trees are clean.
#
# Three arms, each on its OWN wording — I49's arrangement, and row 4's recorded trap is why.
A28_i53_escalation_modes() {
ESR="$ROOT/core/scripts/validate-escalation-resolution.sh"
CPS="$ROOT/core/scripts/core-paths.sh"

# ARM 1 — GHOST MODE. The caller keeps the old spelling after a rename. Assembled, never
# written out: I53 excludes core/fixtures/ from its citation corpus, and a fixture leaning on
# that exclusion to hold its own text goes red the day the exclusion is reconsidered.
i53_ghost="--any-authorize""d-by"
CPS_BAK="$(mkbak "$CPS")"
sed "s@validate-escalation-resolution\\.sh\" --any-authorized@validate-escalation-resolution.sh\" ${i53_ghost}@" "$CPS_BAK" > "$CPS"
if cmp -s "$CPS_BAK" "$CPS"; then
  bad "FIXTURE BROKEN: the I53 ghost-mode mutation matched nothing, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A28-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A28-m1 "A28-m1: one core script invoking a mode the other does not dispatch FAILS I53 (the call exits 2, and the citation arm reads that as 'no operator citation')"
  else
    bad "A28-m1 SURVIVED: core-paths.sh called an escalation mode that does not exist and I53 stayed silent — the core-layer-immutability backstop would FAIL trees that are clean"
  fi
  mx_twins A28-m1 "$out"
fi
cp "$CPS_BAK" "$CPS"; rm -f "$CPS_BAK"

# ARM 2 — UNDOCUMENTED MODE. Drop a mode from the USAGE block. The delegation is code, but
# the operator reproducing it by hand reads that block.
ESR_BAK="$(mkbak "$ESR")"
grep -v '^#   validate-escalation-resolution.sh --any-authorized' "$ESR_BAK" > "$ESR"
if cmp -s "$ESR_BAK" "$ESR"; then
  bad "FIXTURE BROKEN: the I53 undocumented-mode mutation matched nothing, so the second arm is unproven"
else
  out="$(vrun)"
  if mx_red A28-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A28-m2 "A28-m2: a dispatched escalation mode missing from the USAGE block FAILS I53 (a mode no operator can discover)"
  else
    bad "A28-m2 SURVIVED: a mode vanished from the USAGE block and I53 reported clean — the discoverable set and the dispatched set can now diverge"
  fi
  mx_twins A28-m2 "$out"
fi
cp "$ESR_BAK" "$ESR"; rm -f "$ESR_BAK"

# ARM 3 — VACUITY. Rename the sentinel bounding the dispatch extraction. I53 reports an
# ABSENCE, and an empty dispatched set makes `comm` compare against nothing and agree.
ESR_BAK="$(mkbak "$ESR")"
sed 's@# MODE_DISPATCH_BEGIN@# ARG_TABLE_BEGIN@' "$ESR_BAK" > "$ESR"
if cmp -s "$ESR_BAK" "$ESR"; then
  bad "FIXTURE BROKEN: the I53 vacuity mutation matched nothing, so the third arm is unproven"
else
  out="$(vrun)"
  if mx_red A28-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A28-m3 "A28-m3: a renamed dispatch sentinel FAILS I53 loudly (an empty set is a subset of everything, so the join must refuse rather than agree)"
  else
    bad "A28-m3 SURVIVED: the escalation dispatch extraction found nothing and I53 did not say so — it was comparing against an empty set and calling it agreement"
  fi
  mx_twins A28-m3 "$out"
fi
cp "$ESR_BAK" "$ESR"; rm -f "$ESR_BAK"
}

A29_i54_early_exit_reader() {
# I54 bans writing a shell variable into a reader that stops at its first match. Under
# pipefail such a pipeline reports the WRITER's status, and a writer that still had bytes
# to push has taken EPIPE -- so the test answers "not found" on input containing the
# pattern. Where a match means the tree is BAD that is a permanent, silent pass.
#
# EVERY LITERAL OF THE BANNED SHAPE IS ASSEMBLED AT RUNTIME. I54's scan covers
# core/fixtures/, so a fixture that spelled the shape out would be reported by the very
# invariant it exists to test -- the trap v0.194.0 paid for twice. `$_g` below is the
# reader; nothing on any line here forms the pattern I54 matches.
_g="gre""p -q"
I54_TGT="core/fixtures/ledger-rotate/run.sh"

# ARM 1 — THE BAN FIRES, and names the file. The injected line is inert (guarded by a
# false test) because I54 reads text and must not need the code to run; a realistic site
# is a line in a real script, not a scratch file no manifest knows about.
printf '\nif false; then\n  printf %s "$_i54" | %s I54_SENTINEL_ALPHA\nfi\n' "'%s'" "$_g" >> "$ROOT/$I54_TGT"
out="$(vrun)"
if grep -qF "$I54_TGT" <<<"$out" && grep -q 'I54 found' <<<"$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A29-m1 "A29-m1: a variable written into a first-match reader FAILS I54, naming the file (under pipefail that test answers 'not found' on input that contains the pattern)"
else
  bad "A29-m1 SURVIVED: the banned reader idiom was reintroduced and I54 stayed silent — the check that keeps a negative assertion able to fire is itself unable to fire"
fi
mx_twins A29-m1 "$out"

# ARM 2 — NO FALSE POSITIVE ON THE PERMITTED SHAPE. An ordinary command piped into the
# same reader is safe and ubiquitous; a blanket ban would be the unmeasured lint
# CLAUDE.md warns about. Asserted on I54 being SILENT about this file, with arm 1's
# injection removed first so the two cannot be confused.
git -C "$ROOT" checkout -- "$I54_TGT" 2>/dev/null || sed -i.bak '/I54_SENTINEL_ALPHA/,+1d' "$ROOT/$I54_TGT"
printf '\nif false; then\n  git log --oneline | %s I54_SENTINEL_BETA\nfi\n' "$_g" >> "$ROOT/$I54_TGT"
VRUN_NOMX=1; out="$(vrun)"; VRUN_NOMX=""
if grep -q 'I54 found' <<<"$out"; then
  bad "A29-c1: I54 reported an ordinary command piped into a first-match reader — that shape is permitted, and a check with that false-positive set is one the operator switches off"
else
  ok "A29-c1: an ordinary command piped into the same reader does NOT fail I54 (the subject set is a builtin writing a variable, not every pipe)"
fi

# ARM 3 — VACUITY. I54 reports an ABSENCE, so a grammar that matches nothing prints the
# same clean line as a tree with no defect. It carries a probe of the banned shape and
# must refuse when its own grammar stops matching it. Asserted on that refusal's wording,
# which arm 1's message never contains.
V_BAK="$(mkbak "$V")"
sed 's@\[|\]\[\[:space:\]\]\*grep@[|][[:space:]]*NOSUCHREADER@' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I54 grammar mutation matched nothing, so the vacuity guard is unproven"
else
  out="$(vrun)"
  if mx_red A29-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A29-m2 "A29-m2: a grammar that stops matching its own probe FAILS I54 loudly (a scan that matches nothing reads exactly like a clean tree)"
  else
    bad "A29-m2 SURVIVED: I54's grammar was broken and it reported a clean tree — it was scanning for a shape it could no longer match"
  fi
  mx_twins A29-m2 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"

# ARM 4 — OVER-WIDTH. The opposite failure: a grammar loose enough to match any pipe
# would fire on nearly every script. I54 carries a probe of the PERMITTED shape too and
# must refuse when it starts matching that. Asserted on its own distinct wording.
V_BAK="$(mkbak "$V")"
# The realistic over-width is a "simplification": drop the writer and its quoted
# argument and keep only the pipe-into-reader tail. A mutation that merely adds an
# alternative to the writer group changes bytes without widening anything -- cmp -s
# passes it and the assertion below is what catches it, which is the recorded trap.
sed 's@^i54_re=".*\[|\]@i54_re="[|]@' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I54 over-width mutation matched nothing, so the false-positive guard is unproven"
else
  out="$(vrun)"
  if mx_red A29-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A29-m3 "A29-m3: a grammar that starts matching the permitted shape FAILS I54 loudly (a check nobody can leave on enforces nothing)"
  else
    bad "A29-m3 SURVIVED: I54's grammar was widened to match ordinary pipelines and it did not object — its false-positive set is unguarded"
  fi
  mx_twins A29-m3 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"
}

A30_i55_suite_content_key() {
# I55 guards the fixture-suite content key: the pre-push hook skips the entire suite when
# the key is unchanged since the last fully green run, and the ONLY thing holding that up
# is that the key covers a superset of the suite's inputs. Four arms, four mutants, each
# asserted on its own distinct wording rather than on the shared token "I55" -- row 4's
# recorded trap, where two arms quoting the same subject let a reverted fix pass.
KEY="$ROOT/scripts/suite-content-key.sh"
PREPUSH="$ROOT/.githooks/pre-push"
if [ ! -f "$KEY" ] || [ ! -f "$PREPUSH" ]; then
  bad "FIXTURE BROKEN: the seed carries no scripts/suite-content-key.sh or .githooks/pre-push, so I55 has nothing to read"
  return
fi

# --- arm 1: an exclusion that is not a bare top-level name excludes NOTHING ----
KEY_BAK="$(mkbak "$KEY")"
sed 's@^docs$@docs/analysis@' "$KEY_BAK" > "$KEY"
if cmp -s "$KEY_BAK" "$KEY"; then
  bad "FIXTURE BROKEN: the I55 arm-1 mutation matched nothing, so the exclusion-shape arm is unproven"
else
  out="$(vrun)"
  if mx_red A30-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A30-m1 "A30-m1: an exclusion carrying a slash is REPORTED (it matches no top-level entry and silently excludes nothing)"
  else
    bad "A30-m1 SURVIVED: suite-content-key.sh declared an exclusion that its own exact-match filter can never apply, and the build stayed green"
  fi
  mx_twins A30-m1 "$out"
fi
cp "$KEY_BAK" "$KEY"; rm -f "$KEY_BAK"

# --- arm 2: dropping .git from the exclusion set --------------------------------
KEY_BAK="$(mkbak "$KEY")"
sed '/^# EXCLUDE_BEGIN$/,/^# EXCLUDE_END$/{/^\.git$/d;}' "$KEY_BAK" > "$KEY"
if cmp -s "$KEY_BAK" "$KEY"; then
  bad "FIXTURE BROKEN: the I55 arm-2 mutation matched nothing, so the .git arm is unproven"
else
  out="$(vrun)"
  if mx_red A30-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A30-m2 "A30-m2: including .git in the key is REPORTED (it moves every commit, so the skip could never fire again)"
  else
    bad "A30-m2 SURVIVED: the content key was widened to cover the object store and nothing objected — the suite skip became unreachable silently"
  fi
  mx_twins A30-m2 "$out"
fi
cp "$KEY_BAK" "$KEY"; rm -f "$KEY_BAK"

# --- arm 3: a fixture reaching an EXCLUDED path at the distribution root ---------
# Written into a real fixture's run.sh, because that is the corpus arm 3 reads.
#
# THE PROBE IS ASSEMBLED AT RUNTIME AND NOTHING ON ANY LINE HERE SPELLS IT OUT.
# Arm 3's scan covers core/fixtures/, so a literal would be reported by the very
# invariant this assertion exists to test -- and it was, on the first run, which is
# the trap v0.194.0 recorded and paid for twice.
I55_PROBE='probe="$'"RO""OT/do""cs/analysis\""
I55_TGT="core/fixtures/ledger-rotate/run.sh"
if [ ! -f "$ROOT/$I55_TGT" ]; then
  bad "FIXTURE BROKEN: $I55_TGT is not in the seed, so I55 arm 3 has no subject"
else
  cp "$ROOT/$I55_TGT" "$ROOT/$I55_TGT.orig"
  printf '%s\n' "$I55_PROBE" >> "$ROOT/$I55_TGT"
  if cmp -s "$ROOT/$I55_TGT.orig" "$ROOT/$I55_TGT"; then
    bad "FIXTURE BROKEN: the I55 arm-3 mutation changed no bytes"
  else
    out="$(vrun)"
    if mx_red A30-m3 "$out"; then
      mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A30-m3 "A30-m3: a fixture reading an excluded path at the distribution root is REPORTED (its input could change with the suite never re-running)"
    else
      bad "A30-m3 SURVIVED: a fixture took an unhashed path as input and I55 stayed silent — the skip would hold across a change to that fixture's own subject"
    fi
    mx_twins A30-m3 "$out"
  fi
  mv "$ROOT/$I55_TGT.orig" "$ROOT/$I55_TGT"
fi

# --- arm 4: EVERY cross-run record moved INSIDE the tree the key hashes ----------
# THE MUTATION IS DERIVED FROM THE HOOK, and v0.229.0 is why it had to become so. This
# arm named `KEY_RECORD` for as long as the hook kept exactly one record. That release
# gave it a SECOND -- the fixture durations the pool dispatches on -- and made I55's
# subject set a grammar rather than a name. Mutating only the record this fixture
# happened to know would then prove the arm FIRES without proving it covers what it now
# claims to: a record outside the derived set would sit in the tree, and this arm would
# go on printing the same green line about the other one.
#
# So the mutation moves every `<NAME>_RECORD=` the hook declares, and the assertion
# counts the records the report NAMES against the records the hook DECLARES. Both sides
# are read off the hook, so a third record is covered the day someone writes it, and a
# subject set that quietly stopped growing fails here instead of passing quietly.
cp "$PREPUSH" "$PREPUSH.orig"
i55_declared="$(grep -cE '^[A-Z][A-Z0-9_]*_RECORD="' "$PREPUSH.orig" 2>/dev/null)"
case "$i55_declared" in ''|*[!0-9]*) i55_declared=0 ;; esac
# THE ANCHOR IS THE RECORD'S PREFIX, WHICHEVER OF THE TWO LEGAL SPELLINGS IT USES.
# It was `"\.git/` alone until v0.608.0, when the hook stopped spelling the git dir
# literally: in a LINKED WORKTREE `.git` is a FILE, so every record failed to open and
# the suite lost its cross-run evidence silently (`BL-277`). The hook now resolves
# `GITDIR` from `--git-common-dir` and the records read `"$GITDIR/…`, which that `sed`
# matched NOTHING of — so this arm correctly refused, on the commit that fixed the
# defect, rather than passing over a mutation that never applied. Both spellings are
# anchored here because both are legal: the literal one in a program that has no
# worktree to serve, the resolved one in these two hooks.
sed -E 's@^([A-Z][A-Z0-9_]*_RECORD)="(\.git|\$GITDIR)/@\1="core/@' "$PREPUSH.orig" > "$PREPUSH"
if [ "$i55_declared" -lt 2 ]; then
  bad "FIXTURE BROKEN: the hook declares $i55_declared cross-run record(s) under .git/; this arm proves a DERIVED subject set and cannot do that over fewer than two"
elif cmp -s "$PREPUSH.orig" "$PREPUSH"; then
  bad "FIXTURE BROKEN: the I55 arm-4 mutation matched nothing, so the record-location arm is unproven"
else
  out="$(vrun)"
  i55_named="$(grep -oE '[A-Z][A-Z0-9_]*_RECORD=' <<<"$out" | sort -u | grep -c . 2>/dev/null)"
  case "$i55_named" in ''|*[!0-9]*) i55_named=0 ;; esac
  if grep -q "inside the working tree" <<<"$out" && [ "$i55_named" -eq "$i55_declared" ]; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A30-m4 "A30-m4: moving ALL $i55_declared cross-run records inside the tree they are hashed by is REPORTED, and the report names every one — the subject set is derived from the hook, not from a name this fixture knows"
  else
    bad "A30-m4 SURVIVED: the cross-run records were moved into the hashed tree and I55 named $i55_named of $i55_declared — a record outside the derived subject set sits in the tree while the skip becomes machinery that runs on every push and never pays"
  fi
  mx_twins A30-m4 "$out"
fi
mv "$PREPUSH.orig" "$PREPUSH"
}

# --- Assertion 31: I56 — the model pin cannot fork, and cannot be defined twice --
# `ai-dlc-dispatch-guard.sh` decides a role's pin at dispatch and binds the teammate's model
# to it; `validate-spawn-ledger.sh` re-asks the same question at the gate for Check 22. They
# share `pin_key()` and `matches_pin()` as byte-identical COPIES — I25's reason: a guard that
# sources a helper fails OPEN on a partial install, and a dispatch guard binding nothing is
# far worse than eleven duplicated lines.
#
# THREE ARMS, EACH ON ITS OWN WORDING. Arm 3 is the one with a real history: the guard shipped
# TWO definitions of `matches_pin()`, verbatim apart from one word of comment, with the first
# shadowed and dead. An awk-range extraction concatenates both spans, so a duplicate does not
# fork the rule — it disables the check that would have caught a fork. Arms 2 and 3 both land
# on I56's count message, so they are distinguished by the COUNT they report, never by the
# shared token: row 4's recorded trap.
A31_i56_model_pin_binding() {
GUARD="$ROOT/core/hooks/ai-dlc-dispatch-guard.sh"
LEDGERV="$ROOT/core/scripts/validate-spawn-ledger.sh"
if [ ! -f "$GUARD" ] || [ ! -f "$LEDGERV" ]; then
  bad "FIXTURE BROKEN: the seed carries no ai-dlc-dispatch-guard.sh or validate-spawn-ledger.sh, so I56 has nothing to bind"
  return
fi

# --- arm 1: FORK. Narrow the match tolerance in ONE copy. -------------------
# Dropping the containment case is the exact divergence I56 exists to catch: both files still
# run and both still answer, but the gate now reports a Rule 19(a) mismatch on every spawn the
# guard bound from a full model string (`claude-opus-5[1m]` against the key `opus`).
LEDGERV_BAK="$(mkbak "$LEDGERV")"
sed 's@^    \*"\$EXPECT"\*) return 0 ;;@    *"$EXPECT"*) return 1 ;;@' "$LEDGERV_BAK" > "$LEDGERV"
if cmp -s "$LEDGERV_BAK" "$LEDGERV"; then
  bad "FIXTURE BROKEN: the I56 fork mutation matched nothing, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A31-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A31-m1 "A31-m1: a one-copy change to the match tolerance FAILS I56 (the gate cannot classify a binding differently from the hook that made it)"
  else
    bad "A31-m1 SURVIVED: matches_pin() forked between the dispatch guard and the gate validator and I56 stayed silent — Check 22 would fail spawns the guard bound correctly"
  fi
  mx_twins A31-m1 "$out"
fi
cp "$LEDGERV_BAK" "$LEDGERV"; rm -f "$LEDGERV_BAK"

# --- arm 2: VACUITY. Delete one subject outright. ---------------------------
# I56 LOCATES its subjects by name. A rename or a deletion makes it find nothing, and
# "found nothing" reads exactly like "found two identical bodies" unless it says so.
LEDGERV_BAK="$(mkbak "$LEDGERV")"
awk 'BEGIN{s=0} /^pin_key\(\) \{/{s=1} s==0{print} /^\}/{if(s==1){s=2; next}}' "$LEDGERV_BAK" > "$LEDGERV"
if cmp -s "$LEDGERV_BAK" "$LEDGERV"; then
  bad "FIXTURE BROKEN: the I56 deletion mutation matched nothing, so the vacuity arm is unproven"
else
  out="$(vrun)"
  if mx_red A31-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A31-m2 "A31-m2: a MISSING bound function FAILS I56 loudly, naming the count it found (a rename never retires the binding in silence)"
  else
    bad "A31-m2 SURVIVED: pin_key() was deleted from the gate validator and I56 did not report a zero count — the binding can be retired by a rename"
  fi
  mx_twins A31-m2 "$out"
fi
cp "$LEDGERV_BAK" "$LEDGERV"; rm -f "$LEDGERV_BAK"

# --- arm 3: DUPLICATE. Define matches_pin() twice in the guard. -------------
# The state the guard actually shipped in until v0.211.0. Byte-identity alone passes it,
# because the extraction returns both spans from one side and one from the other — so the
# count arm has to come first.
cp "$GUARD" "$GUARD.orig"
{ cat "$GUARD.orig"
  printf 'matches_pin() {\n  [ -n "$EXPECT" ] || return 1\n  case "$1" in\n    "$EXPECT")   return 0 ;;\n    *)           return 1 ;;\n  esac\n}\n'
} > "$GUARD"
if cmp -s "$GUARD.orig" "$GUARD"; then
  bad "FIXTURE BROKEN: the I56 duplicate mutation wrote no second definition, so the third arm is unproven"
else
  out="$(vrun)"
  if mx_red A31-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A31-m3 "A31-m3: a SECOND definition of a bound function FAILS I56, naming the count (the later one shadows the earlier and the fork arm would compare two spans against one)"
  else
    bad "A31-m3 SURVIVED: the dispatch guard defined matches_pin() twice and I56 reported clean — this is the exact state it shipped in, and a genuine fork could hide behind it"
  fi
  mx_twins A31-m3 "$out"
fi
mv "$GUARD.orig" "$GUARD"
}

A32_i57_predicate_binding() {
GVF="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
MAPF="$ROOT/core/skills/ai-dlc/enforcement-map.yaml"
if [ ! -f "$GVF" ] || [ ! -f "$MAPF" ]; then
  bad "FIXTURE BROKEN: the seed carries no gate-validation.md or enforcement-map.yaml, so I57 has nothing to join"
  return
fi

# --- arm 1: THE DEFECT, REPLAYED. Not a mutant — the state the tree shipped in. ---
# Until v0.212.0 nothing bound stamp-story-provenance.sh, while Check 17's two story
# readiness arms each say "exit 0 required" over it. Deleting the unit row restores exactly
# that tree, so this arm proves I57 fires on the real thing rather than on a contrivance.
cp "$MAPF" "$MAPF.orig"
awk '/^  - id: story-provenance-cross-check$/{s=1} s==1 && /^  - id: h2-attestation$/{s=0} s==0{print}' "$MAPF.orig" > "$MAPF"
if cmp -s "$MAPF.orig" "$MAPF"; then
  bad "FIXTURE BROKEN: the I57 unit-row deletion matched nothing, so the replay arm is unproven"
else
  out="$(vrun)"
  if mx_red A32-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A32-m1 "A32-m1: an unbound validator whose exit code the check's own body requires FAILS I57, named with its check (the v0.211.0 state of Check 17, replayed)"
  else
    bad "A32-m1 SURVIVED: Check 17 states 'exit 0 required' over stamp-story-provenance.sh with nothing in the map binding it, and I57 reported clean — the class this invariant exists to end is still open"
  fi
  mx_twins A32-m1 "$out"
fi
mv "$MAPF.orig" "$MAPF"
MAPF="$ROOT/core/skills/ai-dlc/enforcement-map.yaml"

# --- arm 2: THE TWO RESOLUTIONS. Break only the call-site route. -------------
# Check 14 cites the validator THROUGH verdict.sh (`verdict.sh validate-artifact-budget`),
# and its binding lives on the artifact-budget unit rather than on its own row. Repointing
# that one site is the only mutation here, and the message it must produce names
# validate-artifact-budget.sh at Check 14 — a string I57 can only print if it resolved the
# dispatcher's first argument AND looked at non_catalog_units call sites. A join that reads
# basenames and check rows alone prints nothing here, and prints five phantoms elsewhere.
cp "$MAPF" "$MAPF.orig"
sed 's@^      - site: gate-validation.md Check 14$@      - site: gate-validation.md Check 44@' "$MAPF.orig" > "$MAPF"
if cmp -s "$MAPF.orig" "$MAPF"; then
  bad "FIXTURE BROKEN: the I57 call-site repoint matched nothing, so the resolution arm is unproven"
else
  out="$(vrun)"
  if mx_red A32-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A32-m2 "A32-m2: a validator cited through the verdict.sh DISPATCHER and bound on a non_catalog_units call site is resolved both ways by I57 (repointing the site alone reports it)"
  else
    bad "A32-m2 SURVIVED: the artifact-budget unit stopped naming Check 14 as a call site and I57 did not report it — either the dispatcher's argument or the call-site route is not being resolved, and the join is reading wrapper basenames"
  fi
  mx_twins A32-m2 "$out"
fi
mv "$MAPF.orig" "$MAPF"
GVF="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

# --- arm 3: THE DISCRIMINATOR IS THE SENTENCE, NOT THE CITATION. ------------
# Check 25 cites wait-for-deliverable.sh as the REMEDY it offers on FAIL. That citation is
# correct and must stay unbound. Giving that same sentence an exit-code posture — and
# changing nothing else, not the citation, not the map — must flip it into the subject set.
# This is the arm that proves the release's actual claim: an imperative naming a validator
# is not the predicate; an assertion that its exit code binds the gate is.
cp "$GVF" "$GVF.orig"
sed 's@^  count\.$@  count; exit 0 required.@' "$GVF.orig" > "$GVF"
if cmp -s "$GVF.orig" "$GVF"; then
  bad "FIXTURE BROKEN: the I57 posture-injection matched nothing, so the discriminator arm is unproven"
else
  out="$(vrun)"
  if mx_red A32-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A32-m3 "A32-m3: adding an exit-code posture to an On-FAIL REMEDY — same citation, same map — moves it into I57's subject set (the discriminator reads the sentence, not the mention)"
  else
    bad "A32-m3 SURVIVED: Check 25's remedy citation gained 'exit 0 required' and I57 stayed silent — the selection is not keying on the posture, so it cannot be separating predicates from producers and remedies either"
  fi
  mx_twins A32-m3 "$out"
fi
mv "$GVF.orig" "$GVF"

# --- arm 4: THE LIVENESS PROBE. Kill the grammar; the probe must say so. -----
# With Check 17 bound there is no live subject left, so a grammar that stops matching
# reports the same clean line as one that found nothing to report. I57 answers that with a
# probe it builds itself. Break the posture term and the probe — not the corpus — is what
# fails.
#
# THE MUTATION NAMES ONLY THE POSTURE TERM, not the whole regex. It used to restate the
# expression from `exits?` onward, and v0.357.0's case-tolerant widening (`exits?` ->
# `[Ee]xits?`) left that restatement matching nothing — the arm reported itself broken and
# blocked the push, which is the guard working, but the arm was dead until someone repaired
# it. `required/` occurs exactly once in the validator (the closing delimiter pins it to the
# end of I57's own regex), so the smallest span that carries the semantics is also unique,
# and an edit to the case class, the quantifiers or the digit class no longer kills the probe.
V_BAK="$(mkbak "$V")"
sed 's@\[ \]+required/@[ ]+requiredZZZ/@' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I57 grammar mutation matched nothing, so the liveness arm is unproven"
else
  out="$(vrun)"
  if mx_red A32-m4 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A32-m4 "A32-m4: a posture grammar that can no longer match FAILS I57 against its own probe (an empty subject set never again reads as a clean tree)"
  else
    bad "A32-m4 SURVIVED: I57's posture grammar was broken so that it matches nothing, and the invariant still printed clean — the liveness probe is not wired, and this check would silently stop firing on its first grammar edit"
  fi
  mx_twins A32-m4 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"

# --- arm 5: THE NARROWNESS PROBE. Widen it back to the legend form. ---------
# `exit 0 = dropped, exit 1 = consumer-owned` is how Check 16 DESCRIBES a delegation
# validate-stub-audit.sh makes internally — correctly carried under reads:, and the nearest
# miss in the measured corpus. Widening the grammar to accept `=` is the one-character
# change that would report it, so the negative probe holds that door shut.
# (The same widening also reports Check 16 itself; that is the false positive the narrow
# grammar exists to avoid, and this arm asserts the probe's message, not the count.)
# Same narrowed target as arm 4, for the same reason: widen the posture ALTERNATIVE only,
# and let the case class and quantifiers ahead of it change without killing this probe.
V_BAK="$(mkbak "$V")"
sed 's@\[ \]+required/@[ ]+(required|=)/@' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I57 grammar widening matched nothing, so the narrowness arm is unproven"
else
  out="$(vrun)"
  if mx_red A32-m5 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A32-m5 "A32-m5: widening the posture to accept an exit-code LEGEND FAILS I57's negative probe (the measured-empty false-positive set is held by a mechanism, not by a paragraph)"
  else
    bad "A32-m5 SURVIVED: I57's posture grammar was widened to match 'exit 0 = ...' and the negative probe stayed silent — nothing stops this check from growing back onto delegations that are correctly carried under reads:"
  fi
  mx_twins A32-m5 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"
}

# --- Assertion 33: I59 — a dispatched mode is a documented mode ---------------
# A `case` arm no line of prose names is a mode that exists and cannot be found. Nothing
# breaks, so nothing reports it: at v0.213.1 a consumer read `readopt-override.sh`'s usage
# block, concluded `--merge` did not exist, and filed a correct instruction as a defect.
#
# FOUR ARMS, each asserting its OWN wording. Three of them mutate the VALIDATOR rather than
# a subject, because this invariant reports an absence over a derived corpus and three
# separate things can turn that absence into a lie: the extraction can stop matching, the
# one enumerated exemption can widen, and the corpus can collapse to nothing. Each failure
# mode has its own message and each arm names only its own.
A33_i59_documented_modes() {
RO="$ROOT/core/skills/ai-dlc-update/reconcile/readopt-override.sh"

# ARM 1 — THE DEFECT ITSELF, and EVERY layer of the fix is reverted. A partial revert comes
# back green, proving whichever layer it left behind.
#
# THE MUTATION DERIVES ITS OWN TARGETS RATHER THAN NAMING THEM. It used to strip two hand-named
# sites — the `# Usage:` header line and the exit-2 usage string — and it went silently
# insufficient the moment a release added a third: v0.476.0's two-directional gate names
# `--merge` in its remedy prose, so the two-site mutant left the mode documented, I59 correctly
# stayed quiet, and this arm read as a regression in the change under test. So the deletion is
# keyed on I59's OWN documentation test, and the count it must reach is asserted here rather
# than assumed.
cp "$RO" "$RO.orig"
a33_doc_lines() { awk -v m='--merge' 'index($0,m) && ($0 ~ /^[[:space:]]*#/ || index($0,"usage"))' "$1" | grep -c .; }
awk 'index($0,"--merge") && $0 ~ /^[[:space:]]*#/ { next } { print }' "$RO.orig" \
  | sed 's@\[--check|--merge|--stamp <outcome>\]@[--check|--stamp <outcome>]@' > "$RO"
if cmp -s "$RO.orig" "$RO"; then
  bad "FIXTURE BROKEN: the I59 undocumented-mode mutation matched nothing, so the defect arm is unproven"
elif [ "$(a33_doc_lines "$RO")" -ne 0 ] || [ "$(a33_doc_lines "$RO.orig")" -eq 0 ]; then
  bad "FIXTURE BROKEN: after the mutation $(a33_doc_lines "$RO") line(s) still document --merge (the unmutated file has $(a33_doc_lines "$RO.orig")), so I59 staying silent below would say nothing about the invariant"
else
  out="$(vrun)"
  if mx_red A33-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A33-m1 "A33-m1: a dispatched mode named in neither the usage header nor the usage string FAILS I59, named with its file (the v0.213.1 defect, replayed)"
  else
    bad "A33-m1 SURVIVED: readopt-override.sh dispatched --merge with nothing naming it and I59 stayed silent — the mode is invisible again, and the next operator to read that block files the instruction that uses it as a defect"
  fi
  mx_twins A33-m1 "$out"
fi
mv "$RO.orig" "$RO"

# ARM 2 — THE EXTRACTION DIES. I59 reports an ABSENCE over a regex against a shell
# construct, and a regex that matches nothing returns the same empty set as a clean tree.
# The invariant answers that with a probe file it writes itself; break the grammar and the
# PROBE is what fails, not the corpus.
#
# The mutation targets the extraction's FINAL filter, not the case-arm regex. The first
# attempt at this arm edited the regex's leading alternation group — which is `(...)*`,
# so dropping it changed bytes and changed nothing: `cmp -s` passed, the mutant ran, and
# the arm reported a real failure against a validator that was still working. A byte
# guard proves the sed matched; only the assertion proves the mutant BITES.
#
# RE-ANCHORED WHEN I59 BECAME ONE AWK PASS. The filter was a `grep '^--'` at the end of a
# shell pipeline; it is now the `substr(...) == "--"` test inside `I59_UNDOC_AWK`, and the
# shell function that held the old spelling was DELETED rather than left beside the awk —
# left in place it would be a line nothing executes, and this `sed` would go on editing it
# and scoring a kill it did not earn. Measured before re-anchoring: against the batched
# implementation with that dead function still present, the old mutation applied cleanly
# (`cmp -s` passed it) and `--arms I59` exited 0 printing the OK line. Scored three ways as
# `.claude/rules/fixture-mutants.md` requires — the anchor is unique in the file (control:
# the same test at a length no token has returns 0 occurrences), the mutant fails on the
# PROBE rather than the corpus, and it fails only this arm.
V_BAK="$(mkbak "$V")"
sed 's@substr(parts\[i\], 1, 2) == "--"@substr(parts[i], 1, 2) == "ZZ"@' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I59 grammar mutation matched nothing, so the liveness arm is unproven"
else
  out="$(vrun)"
  if mx_red A33-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A33-m2 "A33-m2: a case-arm grammar that can no longer match FAILS I59 against its own probe (an extraction that finds nothing never again reads as a documented tree)"
  else
    bad "A33-m2 SURVIVED: I59's mode extraction was broken so that it matches nothing and the invariant still printed clean — it would stop firing on its first grammar edit and no one would learn of it"
  fi
  mx_twins A33-m2 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"

# ARM 3 — THE EXEMPTION DIES. `--help` is the ONE enumerated carve-out and it is what makes
# the measured false-positive set empty: six scripts dispatch `-h|--help` to print their own
# header. Remove it and those six become findings — the shape that gets a lint turned off.
V_BAK="$(mkbak "$V")"
grep -v 'I59_HELP_EXEMPTION' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I59 exemption mutation matched nothing, so the carve-out arm is unproven"
else
  out="$(vrun)"
  if mx_red A33-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A33-m3 "A33-m3: losing the --help carve-out FAILS I59 on its own probe (the measured-empty false-positive set is held by a mechanism, not by a paragraph)"
  else
    bad "A33-m3 SURVIVED: I59's --help exemption was deleted and the probe stayed silent — six scripts that dispatch -h|--help to print their own header become findings, and the carve-out is unheld"
  fi
  mx_twins A33-m3 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"

# ARM 4 — THE CORPUS COLLAPSES. The subject set is derived by `find`, not `git ls-files`,
# precisely because this fixture seeds a copy with no `.git` — and an empty corpus prints
# the same clean line as a fully documented one. The floor is what refuses.
#
# THE MUTATION IS ADDRESSED TO I59'S OWN CORPUS LINE, and that is measured, not tidiness. The
# `-type f -name '*.sh' -not -path` text is not I59's: the same `find` opens I60's corpus in
# `i60_ghosts_batch`, I83's and I84's, so an unaddressed `s@@@` rewrote four lines, sent I59,
# I60 and I83 red together, and `vrun` -- which reads only I59 -- could not see the other two
# die. The address is the one thing I59's line carries that the other three do not: it writes
# `$i59_flist`. Two guards keep it honest. The diff must be EXACTLY one line, so an address that
# widens back or matches a second site is FIXTURE BROKEN rather than a kill; and the sibling
# arms that share the anchor are run in the same arm and must stay GREEN, so the mutant is
# shown to fail I59 and nothing else. Under the unaddressed spelling the sibling run exits 1.
V_BAK="$(mkbak "$V")"
sed "/> \"\$i59_flist\"\$/s@-type f -name '\*\.sh' -not -path@-type f -name '*.zzz' -not -path@" "$V_BAK" > "$V"
# Captured before it is counted: under `pipefail` a `diff` that finds a difference exits 1, so
# `diff | grep -c` fails the pipeline on exactly the input it exists to count and the default
# overwrites the right answer with 0.
a33_diff="$(diff "$V_BAK" "$V")"
a33_nchg="$(grep -c '^<' <<<"$a33_diff")" || a33_nchg=0
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I59 corpus mutation matched nothing, so the floor arm is unproven"
elif [ "$a33_nchg" -ne 1 ]; then
  bad "FIXTURE BROKEN: the I59 corpus mutation changed $a33_nchg line(s) of the validator, not exactly 1 -- it is editing a corpus I59 does not own, and a kill read off it is not I59's"
else
  out="$(vrun)"
  if mx_red A33-m4 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A33-m4 "A33-m4: a corpus derivation that returns nothing FAILS I59 loudly (scanning zero files is not the same answer as finding zero findings)"
  else
    bad "A33-m4 SURVIVED: I59's corpus derivation matched no files and the invariant reported clean — every mode in core/ was unchecked and the run said so nowhere"
  fi
  mx_twins A33-m4 "$out"
  # THE COLLATERAL CONTROL. The arms whose `find` shares the anchor, run against the SAME
  # mutant. Exit 2 is a selection failure and is routed to FIXTURE BROKEN, never scored; the
  # positive conjunct is the verdict block's `OK:` line, which a run that never reached it
  # cannot print.
  a33_sib="$(bash "$V" --arms I60,I83,I84 2>&1)"; a33_src=$?
  if [ "$a33_src" = "2" ]; then
    [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: validate-enforcement-map.sh --arms I60,I83,I84 exited 2 under the I59 corpus mutant, a selection failure rather than a finding: %s\n' "$a33_sib" >> "$VRUN_BROKEN"
  elif [ "$a33_src" = "0" ] && grep -q '^OK: ' <<<"$a33_sib"; then
    ok "the I59 corpus mutant leaves I60, I83 and I84 green -- the arms sharing its find anchor are not collateral of this kill"
  else
    bad "the I59 corpus mutant also broke a sibling arm (--arms I60,I83,I84 exited $a33_src) -- the mutation is editing a corpus I59 does not own, and vrun cannot see it: $(printf '%s\n' "$a33_sib" | grep -m3 -E '^(FAIL|ERROR)' | tr '\n' ' ')"
  fi
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"
}

# --- Assertion 34: I60 — a CITED mode is a mode the target dispatches ---------
# The other half of I59's join, and the half no general invariant held. A file names
# `<script>.sh --mode`, the script does not accept it, and the call exits 2 — which I49's
# call site reads as "cannot determine what core is" and I53's reads as "no operator
# citation", so the same typo becomes an unreadable manifest at one gate and a FAIL on a
# clean tree at the other.
#
# FOUR ARMS. Three mutate the VALIDATOR rather than a subject, because this invariant
# reports an absence over two derived corpora and three separate things turn that absence
# into a lie: the citation grammar can stop matching, the dispatch grammar can widen until
# nothing is ever a ghost, and the corpus can collapse. Each arm names only its own message.
A34_i60_cited_modes() {

# ARM 1 — THE DEFECT ITSELF. Rename the mode at a REAL call site rather than planting a
# citation, so what is proven is the join reaching a live caller. The ghost spelling is
# ASSEMBLED, never written out: I60 excludes core/fixtures/ from its corpus, but this file
# is read by other invariants and a literal here is a citation somewhere.
GHOST="--is-""kore"
VICTIM="$(grep -rl --exclude-dir=fixtures -- 'core-paths\.sh --is-core' "$ROOT/core" 2>/dev/null | head -1)"
if [ -z "$VICTIM" ]; then
  bad "FIXTURE BROKEN: no file in the seed cites 'core-paths.sh --is-core', so the I60 defect arm has no live citation to rename and is unproven"
else
  cp "$VICTIM" "$VICTIM.orig"
  sed "s@core-paths\.sh --is-core@core-paths.sh $GHOST@" "$VICTIM.orig" > "$VICTIM"
  if cmp -s "$VICTIM.orig" "$VICTIM"; then
    bad "FIXTURE BROKEN: the I60 ghost-citation mutation matched nothing, so the defect arm is unproven"
  else
    out="$(vrun)"
    if mx_red A34-m1 "$out"; then
      mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A34-m1 "A34-m1: a shipped file naming a core-paths.sh mode the dispatch rejects FAILS I60, named with its mode (the call would exit 2, and both hand-listed call sites misread that 2)"
    else
      bad "A34-m1 SURVIVED: a shipped file named a resolver mode that does not exist and I60 stayed silent — the generalisation covers 25 targets on paper and reached none of them"
    fi
    mx_twins A34-m1 "$out"
  fi
  mv "$VICTIM.orig" "$VICTIM"
fi

# ARM 2 — THE NON-CASE DISPATCH FORM DIES. This is the arm that carries the row's actual
# finding. Six shipped scripts parse their mode with `[ "$1" = "--x" ]` rather than a case
# arm, and a dispatch side that reads only case arms turns every one of them into a false
# finding — the measured non-empty false-positive set that blocked this generalisation for
# two programs. The probe target dispatches one mode each way precisely so this regression
# is loud instead of quiet.
#
# RE-ANCHORED WHEN I60 BECAME ONE AWK PASS. The non-case form was a `grep -oE` inside the
# `i60_dispatches` pipeline; it is now the regex `i60_nc_form` prints, handed to the awk as
# `NCFORM`. It is a FUNCTION rather than an inline literal precisely so this mutation has one
# executable site to key on: the same regex appears in the prose above it, and a `sed` cannot
# tell a program from a sentence about the program. Measured before re-anchoring: the old
# mutation returned `cmp -s` equal — it matched NOTHING — so the arm would have reported
# FIXTURE BROKEN on the commit that made the invariant faster, which reads exactly like the
# change being wrong.
V_BAK="$(mkbak "$V")"
sed "s@i60_nc_form() { printf '%s' '==?\[\[:space:\]\]+\"--\[a-z\]\[a-z0-9-\]\*\"'@i60_nc_form() { printf '%s' '--zzz-no-such-form'@" "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I60 non-case-dispatch mutation matched nothing, so the false-positive arm is unproven"
else
  out="$(vrun)"
  if mx_red A34-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A34-m2 "A34-m2: a dispatch side that no longer reads \`[ \"\$1\" = \"--x\" ]\` FAILS I60 on its own probe (the empty false-positive set is held by a mechanism, not by a paragraph)"
  else
    bad "A34-m2 SURVIVED: I60's non-case dispatch form was removed and the probe stayed silent — six shipped scripts become false findings, which is the shape that gets a lint turned off"
  fi
  mx_twins A34-m2 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"

# ARM 3 — THE CITATION GRAMMAR DIES. A regex that matches nothing returns the same empty
# ghost set as a tree with no ghost in it. Break it and the PROBE is what fails.
V_BAK="$(mkbak "$V")"
sed "s@\[A-Za-z0-9_.-\]+\\\\\.sh\"?\[\[:space:\]\]+--\[a-z\]\[a-z0-9-\]\*@zzz-matches-no-citation@" "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I60 citation-grammar mutation matched nothing, so the liveness arm is unproven"
else
  out="$(vrun)"
  if mx_red A34-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A34-m3 "A34-m3: a citation grammar that can no longer match FAILS I60 against its own probe (an extraction that finds nothing never again reads as a tree with no ghost citation)"
  else
    bad "A34-m3 SURVIVED: I60's citation extraction was broken so that it matches nothing and the invariant still printed clean — it would stop firing on its first grammar edit and no one would learn of it"
  fi
  mx_twins A34-m3 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"

# ARM 4 — THE CORPUS COLLAPSES. The floor is what refuses a derivation that returns almost
# nothing. A probe that still passes plus a corpus of two pairs reads exactly like a clean
# tree, so the count is guarded separately from the grammar.
#
# The mutation repoints the CORPUS SCAN's root and leaves the probe's alone, and that is the
# whole point of the arm rather than an implementation detail. The first version of this arm
# broke the shared citation function instead: the probe reads it too, so the probe fired
# first, the floor was never reached, and the arm failed against a floor that was working.
# A guard downstream of a liveness probe can only be tested on an input the probe still
# passes.
V_BAK="$(mkbak "$V")"
sed 's@i60_citations "$REPO_ROOT"@i60_citations "$REPO_ROOT/nonexistent"@g' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I60 corpus mutation matched nothing, so the floor arm is unproven"
else
  out="$(vrun)"
  if mx_red A34-m4 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A34-m4 "A34-m4: a citation corpus that collapses to nothing FAILS I60 loudly (scanning zero files is not the same answer as finding zero ghosts)"
  else
    bad "A34-m4 SURVIVED: I60's citation corpus matched no files and the invariant reported clean — every cited mode in the tree was unchecked and the run said so nowhere"
  fi
  mx_twins A34-m4 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"
}
# `i93_token` -> the declared empty-subject verdict token, read out of the SEED's own owner.
#
# NEVER TYPED HERE, and that is the whole subject of I93 one level out. A fixture that
# restates a controlled vocabulary is a second copy of it, and a second copy drifts: the day
# the token changes at the owner, a hand-typed seed below would emit a string nothing declares
# and arm D would fire on it for the wrong reason, which is a green cell earned by accident.
# Callers must treat an empty result as FIXTURE BROKEN -- a seed emitting the empty string
# reaches no branch, arm D correctly stays quiet, and that silence would score as a kill.
i93_token() {
  awk '
    /^empty_subject_verdict:/ { on = 1; next }
    on && /^[^[:space:]#]/    { exit }
    on && /^  token:/         { sub(/^  token:[[:space:]]*/, ""); print; exit }
  ' "$ROOT/core/skills/ai-dlc/enforcement-map.yaml"
}

# --- Assertion 35: I93 arm D — the reverse join, over BOTH halves of its population ---
# Arms A and B ask whether every DECLARED emitter emits. Nothing asked the other direction
# until arm D, so a validator that adopted this vocabulary without registering joined it
# silently: docs/vocabulary-index.md under-reported the set, and nothing bound the new file to
# the token if the token ever changed. That is a join running one way, which is the mirror of a
# check that cannot fire -- green forever in the direction nobody watches.
#
# THE TWO POPULATION HALVES ARE SEPARATE ARMS ON PURPOSE. Arm D sweeps core/scripts/ (shipped)
# AND scripts/ (distribution-only), and the file that PROVED the gap -- the one exemption the
# arm carries -- lives in the second. An arm-1-only battery passes against a sweep narrowed to
# core/scripts/, and that narrowing deletes the only half with a live subject in it.
#
# ARM 2 IS THE SAME PATH AS ARM 1 WITH ONE CHARACTER CHANGED. arm D's false-positive narrowing
# is the emission SITE: a `#` line carrying the token is a validator's exit-code table, not an
# emission, and there are dozens of those. Seeding the near-miss at a different path would
# leave the two arms comparing two files; keeping the path fixed makes the pair a differential
# whose only variable is the thing the narrowing keys on.
A35_i93_reverse_join() {
esv_tok="$(i93_token)"
if [ -z "$esv_tok" ]; then
  bad "FIXTURE BROKEN: could not derive empty_subject_verdict.token from the seed's enforcement-map.yaml — every seed below would emit nothing, arm D would rightly stay quiet, and that silence would score as a kill"
  return
fi

# ARM 1 — AN UNDECLARED EMITTER UNDER core/scripts/. Deliberately not named validate-*.sh:
# arm D's population is every FILE in the directory, and a name matching the validator
# convention would leave the assertion unable to tell that from a narrower grammar.
esv_core_new="$ROOT/core/scripts/esv-newcomer.sh"
printf '%s\n' '#!/usr/bin/env bash' "echo \"$esv_tok: this run opened no file\"" > "$esv_core_new"
out="$(vrun)"
if mx_red A35-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A35-m1 "A35-m1: a core/scripts/ file emitting the declared token while the map declares it nowhere FAILS I93 (a validator cannot join this vocabulary without registering)" && B_a35m1=1
else
  bad "A35-m1 SURVIVED: an undeclared core/scripts/ emitter of the empty-subject verdict did not fail I93 — the reverse join is one-way again and docs/vocabulary-index.md under-reports the set by one file"
fi
mx_twins A35-m1 "$out"

# ARM 2 — THE NEAR-MISS, at the same path. The token in a COMMENT is what every emitter's
# exit-code table already carries; a whole-file `grep -qF` would fire on all of them.
printf '%s\n' '#!/usr/bin/env bash' "#   78 = $esv_tok, in an exit-code table" \
              "  #   and once more, indented, as a header records a retirement" > "$esv_core_new"
VRUN_NOMX=1; out="$(vrun)"; VRUN_NOMX=""
if grep -q 'esv-newcomer.sh' <<<"$out"; then
  bad "A35-c1: arm D fired on a file whose only mention of the token is a COMMENT — every emitter's own exit-code table is that shape, so the arm would demand a declaration for each of them"
elif grep -q '^OK: enforcement-map.yaml in sync' <<<"$out"; then
  ok "A35-c1: a core/scripts/ file carrying the token only in a comment does NOT fail I93, and the run still reaches its verdict (the narrowing is the emission site, not the token)"
else
  bad "A35-c1: the near-miss tree neither failed on the seeded path nor reached I93's OK verdict — the run did not get far enough for this arm's silence to mean anything"
fi
rm -f "$esv_core_new"

# ARM 3 — AN UNDECLARED EMITTER UNDER scripts/. This is the half a core/scripts-only reading
# of the arm would miss, and it is where the file that proved the gap lives.
esv_dist_new="$ROOT/scripts/esv-dist-newcomer.sh"
printf '%s\n' '#!/usr/bin/env bash' "echo \"$esv_tok: this run opened no file\"" > "$esv_dist_new"
out="$(vrun)"
if mx_red A35-m2 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A35-m2 "A35-m2: an undeclared emitter under scripts/ FAILS I93 too (the distribution-only half of arm D's population is swept, not just core/scripts/)"
else
  bad "A35-m2 SURVIVED: an undeclared scripts/ emitter did not fail I93 — arm D's sweep has narrowed to core/scripts/, and the only file that ever demonstrated this gap lives in the half it stopped reading"
fi
mx_twins A35-m2 "$out"
rm -f "$esv_dist_new"

# ARM 3b — AN UNDECLARED EMITTER THAT IS NOT A SHELL SCRIPT. Arm D is deliberately wider than
# arm C: arm C sweeps `*.sh` because a retired SPELLING is a shell-grammar question, while
# this arm asks who joined a vocabulary, which no file extension answers. The seed is a `.js`
# because core/scripts/gen-architecture-index.js exists TODAY, so an `*.sh` narrowing would
# reintroduce the same one-way blindness one grain over -- and the two arms above cannot see
# that narrowing, because both of their seeds end in .sh.
esv_js_new="$ROOT/core/scripts/esv-newcomer.js"
printf '%s\n' "console.log(\"$esv_tok: this run opened no file\");" > "$esv_js_new"
out="$(vrun)"
if mx_red A35-m3 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A35-m3 "A35-m3: an undeclared emitter that is NOT a .sh FAILS I93 (arm D's population is the directory, not an extension, and a JS validator can join this vocabulary too)"
else
  bad "A35-m3 SURVIVED: an undeclared .js emitter did not fail I93 — arm D has narrowed to *.sh, which is the blind spot it exists to close, moved one file type over"
fi
mx_twins A35-m3 "$out"
rm -f "$esv_js_new"

# ARM 4 — THE MUTANT, AND WHAT IT ESTABLISHES THAT ARM 1 DOES NOT. Arm 1 asserts a message
# APPEARS; it cannot tell whether arm D produced it or some other I93 arm did, and a kill
# credited to the wrong guard survives arm D's deletion. So arm D's reporter is neutered in a
# copy of the validator, with the SAME seed in place, and the two halves are asserted
# together: the seeded path is no longer named, AND the run still reaches its own OK verdict.
# The second half is what stops this being an absence — a subject replaced by `exit 0` prints
# no verdict and fails here — and it is also the check that the seed trips nothing else, which
# is what makes arm 1 arm D's kill rather than a finding it borrowed from a neighbour.
#
# ANCHORED ON `declares it neither an emitter`, which is arm D's reporter alone. Arm A's
# message and the exemption arm's both contain "outside a comment"; a mutation keyed on the
# shared phrase would edit more than one arm and move cells this assertion never earned.
printf '%s\n' '#!/usr/bin/env bash' "echo \"$esv_tok: this run opened no file\"" > "$esv_core_new"
V_BAK="$(mkbak "$V")"
sed 's@^\( *\)err "I93: .*declares it neither an emitter.*@\1:@' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the arm D reporter mutation matched nothing in the validator, so arm 1 above is a message somebody observed and not a finding attributed to arm D"
else
  out="$(vrun)"
  if grep -q 'esv-newcomer.sh' <<<"$out"; then
    bad "A35-m4: arm D's reporter was neutered and the seeded undeclared emitter was STILL named — the finding arm 1 scores as arm D's kill is coming from somewhere else, and deleting arm D would leave this battery green"
  elif grep -q '^OK: enforcement-map.yaml in sync' <<<"$out"; then
    mutant_killed "${B_a35m1:-0}" A35-m4 "A35-m4: neutering arm D's reporter makes the SAME seeded emitter go unreported while the rest of I93 still reaches its verdict (arm 1's kill belongs to arm D, and the seed trips no other arm)"
  else
    bad "A35-m4: with arm D's reporter neutered the run neither named the seeded emitter nor reached I93's OK verdict — the mutant broke something other than the arm it aimed at, so it proves nothing about arm D"
  fi
  mx_twins A35-m4 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"
rm -f "$esv_core_new"
}

# --- Assertion 36: I93 arm D — the exemption is itself checked, in four directions ---
# Arm D carries one exemption: the distribution-only validator that must NOT be declared,
# because enforcement-map.yaml SHIPS and a declared path would resolve nowhere in a consumer
# tree and could never be falsified where it is wrong. An exemption is a hole in a guard, so
# every way the hole can silently widen is its own arm, and each asserts its OWN wording --
# all four would satisfy a grep for "I93".
#
# ARM 2 IS ARM D'S POSITIVE CONTROL AND IS THE ONE THAT MATTERS MOST. Arm D reports an
# ABSENCE. If its sweep stops reading the population, it reports that same absence forever;
# the exemption is the one path the sweep is REQUIRED to find emitting, in the same invocation
# as the zero. An arm-2 that cannot fire makes every zero arm D prints worthless.
A36_i93_exemption_arms() {
esv_tok="$(i93_token)"
# The exempt path is DERIVED from the validator's own ESV_EXEMPT line rather than typed, for
# the reason the token is: a hand-copied path stays green after the exemption moves.
esv_xp="$(awk -F"'" '/^[[:space:]]*ESV_EXEMPT=/ { split($2, a, " "); print a[1]; exit }' "$V")"
if [ -z "$esv_tok" ] || [ -z "$esv_xp" ] || [ ! -f "$ROOT/$esv_xp" ]; then
  bad "FIXTURE BROKEN: could not derive the token and an existing exempt path from the seed (token='$esv_tok', exempt='$esv_xp') — the mutations below would have no subject"
  return
fi

# ARM 1 — THE EXEMPT FILE IS GONE. An exemption naming a path that has moved reads exactly
# like an exemption doing its job, while the sweep's blind spot now covers nothing at all.
mv "$ROOT/$esv_xp" "$ROOT/$esv_xp.hidden"
out="$(vrun)"
mv "$ROOT/$esv_xp.hidden" "$ROOT/$esv_xp"
if mx_red A36-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A36-m1 "A36-m1: an arm D exemption for a file that no longer exists FAILS I93 (a hole aimed at nothing is a hole nobody can audit)"
else
  bad "A36-m1 SURVIVED: arm D exempted a path that is not in the tree and I93 reported clean — the exemption list can be left pointing at moved files indefinitely"
fi
mx_twins A36-m1 "$out"

# ARM 2 — THE EXEMPT FILE NO LONGER EMITS. Two readings, and the arm must refuse both: the
# exemption has gone vestigial, or the sweep is not reading its population. Mutating the
# token OUT of the file (rather than deleting the file) is what separates this from arm 1.
esv_xp_bak="$(mkbak "$ROOT/$esv_xp")"
sed "s@$esv_tok@REDACTED BY THE FIXTURE@g" "$esv_xp_bak" > "$ROOT/$esv_xp"
if cmp -s "$esv_xp_bak" "$ROOT/$esv_xp"; then
  bad "FIXTURE BROKEN: the arm D positive-control mutation matched nothing in $esv_xp, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A36-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A36-m2 "A36-m2: an exempt file that stopped emitting FAILS I93 (arm D's positive control fires in the same invocation as the zero it licenses)"
  else
    bad "A36-m2 SURVIVED: the one file arm D's sweep is REQUIRED to find emitting stopped emitting and I93 said nothing — every 'no undeclared emitter' verdict from this arm is now a zero taken over a corpus nobody proved was read"
  fi
  mx_twins A36-m2 "$out"
fi
cp "$esv_xp_bak" "$ROOT/$esv_xp"; rm -f "$esv_xp_bak"

# ARM 3 — BOTH DECLARED AND EXEMPT. Two opposite claims about one file, and nothing
# downstream can tell which was meant. Inserted into the owner's emitters list, scoped to the
# block: the file exists and does emit, so arm A stays quiet and this arm owns the case.
MAPY="$ROOT/core/skills/ai-dlc/enforcement-map.yaml"
cp "$MAPY" "$MAPY.orig"
awk -v add="$esv_xp" '
  /^empty_subject_verdict:/ { on = 1; print; next }
  on && /^[^[:space:]#]/    { on = 0 }
  on && /^  emitters:/      { print; print "    - " add; on = 0; next }
                            { print }
' "$MAPY.orig" > "$MAPY"
if cmp -s "$MAPY.orig" "$MAPY"; then
  bad "FIXTURE BROKEN: the I93 both-declared-and-exempt mutation matched nothing in enforcement-map.yaml, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A36-m3 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A36-m3 "A36-m3: a path that is both declared in the map and exempted from arm D FAILS I93 (the two are opposite claims and nothing downstream can resolve them)"
  else
    bad "A36-m3 SURVIVED: one path was simultaneously declared an emitter and exempted from the reverse join and I93 accepted both — the map and the exemption list can disagree about the same file silently"
  fi
  mx_twins A36-m3 "$out"
fi
mv "$MAPY.orig" "$MAPY"

# ARM 4 — AN EXEMPTION WITH NO REASON. An unreasoned exemption is indistinguishable from a
# forgotten declaration, and the next author cannot tell which it was. This one mutates the
# VALIDATOR, since the exemption list lives there. The run also reports the now-unexempted
# file as undeclared, which is correct and is why the assertion is on this arm's OWN wording:
# a grep for the undeclared-emitter message would be satisfied by arm D's ordinary finding.
#
# THE MUTATION IS ANCHORED ON THE OPENING LINE ALONE AND KEEPS THE STRING OPEN. ESV_EXEMPT is
# a MULTI-LINE single-quoted string -- one `<path> <reason>` per line -- so a pattern that
# required the closing quote on the same line matched nothing the moment a second exemption
# was added, and `cmp -s` reported FIXTURE BROKEN rather than silently passing. Stripping the
# reason off the FIRST line only, and leaving the newline and every later line untouched, is
# what makes this a one-exemption mutation on a list of any length.
#
# THE BACKUP LIVES OUTSIDE THE SEEDED TREE for the reason recorded at A39 arm 5: `$V.orig`
# beside `$V` puts a second copy of the validator into `$ROOT/scripts/`, which is half the
# population arms D and E sweep, and that copy is an undeclared emitter of the declared token.
esv_bak="$(mkbak "$V")"
sed "s@^\\([[:space:]]*ESV_EXEMPT='[^ ']*\\) [^']*\$@\\1@" "$esv_bak" > "$V"
if cmp -s "$esv_bak" "$V"; then
  rm -f "$esv_bak"
  bad "FIXTURE BROKEN: the I93 unreasoned-exemption mutation matched nothing in the validator, so this assertion is unproven"
else
  out="$(vrun)"
  if mx_red A36-m4 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A36-m4 "A36-m4: an arm D exemption with no reason after the path FAILS I93 (a bare path reads exactly like a declaration somebody forgot)"
  else
    bad "A36-m4 SURVIVED: arm D accepted an exemption with no reason — a hole in the guard can be opened with no record of why, and the next author reading it cannot tell it from an omission"
  fi
  mx_twins A36-m4 "$out"
fi
cp "$esv_bak" "$V"
rm -f "$esv_bak"
}

# --- Assertion 37: I93 — arm D's four SELF-PROBE bits can actually fire ---------
# I93 runs a scored probe over a seeded tree BEFORE it reads the corpus, and arm D's decision
# (`esv_undeclared`) is factored out so the probe can drive it in all four directions. On a
# working tree that probe scores 0 and prints nothing, which is precisely the shape of a check
# that cannot fire: nothing else in this battery would notice if the four bits arm D added
# were unreachable, because every OTHER assertion here needs the probe to score 0 in order to
# reach the corpus at all.
#
# SO THE SUBJECT IS MUTATED, NOT THE TREE, and the assertion is on the EXACT SCORE. The score
# names which bits fired: a mutant that neuters the join and one that widens it to match
# everything must produce two DIFFERENT totals, and asserting on the number rather than on
# "the probe complained" is what stops one mutation scoring the other's kill.
A37_i93_probe_arm_d_bits() {
# ARM 1 — THE JOIN RETURNS NOTHING. `return 0` ahead of the body, so the guard matches
# NOTHING rather than everything: a widened guard often prints what the original printed and
# scores a kill it did not earn. Expected 1001000000 = +1000000 (the seeded undeclared path
# was not reported, which is the whole of arm D) +1000000000 (the result is not the one
# expected path). The declared/exempt suppression bits must stay quiet: an empty result
# contains neither, and a total that included them would mean the probe cannot tell a join
# that reports nothing from one that reports everything.
V_BAK="$(mkbak "$V")"
sed 's@^esv_undeclared() {$@esv_undeclared() { return 0@' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I93 esv_undeclared neutering mutation matched nothing, so the probe's arm D bits are unproven"
else
  out="$(vrun)"
  if mx_red A37-m1 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A37-m1 "A37-m1: a reverse join that reports nothing is caught by I93's own probe BEFORE the corpus is read (arm D's +1000000 and +1000000000 bits are reachable)"
  else
    bad "A37-m1 SURVIVED: esv_undeclared was neutered to return nothing and I93's probe still scored 0 — the four bits guarding arm D cannot fire, so arm D's silence over the real tree establishes only that it ran"
  fi
  mx_twins A37-m1 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"

# ARM 2 — THE JOIN REPORTS EVERYTHING. The two membership tests are anchored on the argument
# that SEPARATES them ($2 the declared list, $3 the exempt list), never on the shared call
# shape: one sed keyed on the common text would edit both lines, and a mutation that moves two
# cells scores a kill neither arm earned. Expected 1110000000 = +10000000 (a DECLARED emitter
# came back, so arm D would fire on every conforming file) +100000000 (an EXEMPT one came
# back, so the exemption is inert) +1000000000 (the result is not the one expected path). The
# +1000000 bit must stay quiet here: the undeclared path IS reported, and a total carrying it
# would mean the probe is scoring the mutation rather than the behaviour.
V_BAK="$(mkbak "$V")"
sed -e 's@in_lines "$esv_u_p" "$2" && continue@:@' \
    -e 's@in_lines "$esv_u_p" "$3" && continue@:@' "$V_BAK" > "$V"
if cmp -s "$V_BAK" "$V"; then
  bad "FIXTURE BROKEN: the I93 esv_undeclared widening mutation matched nothing, so the probe's suppression bits are unproven"
else
  out="$(vrun)"
  if mx_red A37-m2 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A37-m2 "A37-m2: a reverse join that reports DECLARED and EXEMPT files too is caught by the same probe (the suppression bits score separately from the fires-at-all bit)"
  else
    bad "A37-m2 SURVIVED: esv_undeclared was widened to report every file it was handed and I93's probe did not score it — arm D could fail the tree as it stands, on files the map declares, with nothing upstream to catch it"
  fi
  mx_twins A37-m2 "$out"
fi
cp "$V_BAK" "$V"; rm -f "$V_BAK"
}


# --- Assertion 38: I93 arm D -- an ABORTED sweep is attributed, and only once -----
# BSD awk ABORTS on a path it cannot open rather than skipping it, so ONE broken symlink in
# core/scripts/ or scripts/ ends arm D's walk. Before the scan-status arm existed the run still
# went red -- correctly, because the exemption control refused to certify a zero over a corpus
# nobody finished reading -- but the only message named the EXEMPTION, sending the reader to
# scripts/validate-plan-shape.sh when the cause was a dangling link somewhere else.
#
# THE ARM IS THE PAIR, NOT EITHER HALF. Asserting the new message APPEARS would pass while the
# exemption message also fired, which is the state this exists to end; asserting the exemption
# message is ABSENT would pass against a validator that stopped checking exemptions at all. So
# both are asserted in one arm, over one tree, and the finding COUNT is asserted too -- one
# cause must produce exactly one finding.
A38_i93_scan_status() {
esv_tok="$(i93_token)"
if [ -z "$esv_tok" ]; then
  bad "FIXTURE BROKEN: could not derive empty_subject_verdict.token from the seed, so this arm has no subject"
  return
fi

# A DANGLING SYMLINK, not a chmod 000 file: a permissions seed behaves differently for root,
# and a fixture whose subject depends on who runs it is a fixture that reports the runner.
esv_dangle="$ROOT/scripts/esv-dangling.sh"
ln -s /nonexistent/esv-target "$esv_dangle"
if [ -e "$esv_dangle" ]; then
  rm -f "$esv_dangle"
  bad "FIXTURE BROKEN: the seeded symlink RESOLVES, so awk can open it and this arm's subject does not exist"
  return
fi
out="$(vrun)"
rm -f "$esv_dangle"

esv_n="$(printf '%s\n' "$out" | grep -c '^FAIL: I93')"
if ! grep -q "did not finish reading its population" <<<"$out"; then
  bad "A38-m1: a path arm D cannot open ended its sweep and I93 did not say so -- the run's only diagnosis is a bare awk error on stderr, and every absence arm D reported came from a walk that stopped early"
elif grep -q "arm D exempts .* and arm D's own sweep found no line of it" <<<"$out"; then
  bad "A38-m1: an aborted sweep fired BOTH the scan-status arm and the exemption control -- one cause, two findings, and the second one names scripts/validate-plan-shape.sh, which is not the file at fault"
elif [ "$esv_n" -ne 1 ]; then
  bad "A38-m1: an aborted sweep produced $esv_n I93 finding(s) where exactly 1 is correct -- one cause must yield one finding, or the reader cannot tell which arm owns the case"
else
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A38-m1 "A38-m1: a path arm D cannot open is reported BY THE SCAN-STATUS ARM and by that arm alone (the exemption control stands down, so one cause yields one finding and it names the right question)"
fi
mx_twins A38-m1 "$out"

# THE STAND-DOWN MUST NOT HAVE DISARMED THE EXEMPTION CONTROL. Same tree, no dangling link,
# exempt file mutated to stop emitting: the control it just stood aside for must still fire on
# its OWN case. Without this, deleting the exemption check entirely would pass the arm above.
# DERIVED from the validator's own ESV_EXEMPT line rather than typed, for the reason A36
# derives it: a hand-copied path stays green after the exemption moves. The literal below was
# correct while there was one exemption and would have silently stopped matching the arm's
# subject the moment the list grew.
esv_xp="$(awk -F"'" '/^[[:space:]]*ESV_EXEMPT=/ { split($2, a, " "); print a[1]; exit }' "$V")"
if [ -z "$esv_xp" ] || [ ! -f "$ROOT/$esv_xp" ]; then
  bad "FIXTURE BROKEN: could not derive an existing exempt path from the validator, so the stand-down's counterpart has no subject"
  return
fi
XP="$ROOT/$esv_xp"
XP_BAK="$(mkbak "$XP")"
sed "s@$esv_tok@REDACTED BY THE FIXTURE@g" "$XP_BAK" > "$XP"
if cmp -s "$XP_BAK" "$XP"; then
  bad "FIXTURE BROKEN: the exempt-file mutation matched nothing, so the stand-down's counterpart is unproven"
else
  out="$(vrun)"
  esv_n2="$(printf '%s\n' "$out" | grep -c '^FAIL: I93')"
  if ! grep -q "arm D exempts .* and arm D's own sweep found no line of it" <<<"$out"; then
    bad "A38-m2: the exemption control no longer fires when an exempt file stops emitting -- the stand-down disarmed arm D's positive control, and every zero it licenses is now unproven"
  elif grep -q "$esv_xp:.* states an empty-subject verdict in a spelling of its own" <<<"$out"; then
    bad "A38-m2: arm E reported the EXEMPT file as needing a declaration -- its remedy says 'add the file to emitters:', which is the one thing an exempt path must never do, so the run now prints two contradictory instructions for one cause"
  elif [ "$esv_n2" -ne 1 ]; then
    # THE COUNT, AND WHY IT IS A SEPARATE CONJUNCT FROM THE MESSAGE ABOVE. The grep is
    # satisfied by its own finding no matter what ELSE the run reported, which is how this
    # arm passed for as long as the fixture backed a file up beside itself: measured, the
    # `cp "$XP" "$XP.orig"` idiom produced THREE I93 findings here -- the wanted one, the
    # `.orig` copy read as an undeclared emitter, and arm E reading the MUTATED original as
    # a novel spelling -- and the message assertion could not see either of the extras. One
    # seeded cause must yield one finding; anything else means the seed is tripping arms it
    # was never aimed at, and a reader cannot tell which arm owns the case.
    bad "A38-m2: a mutated exempt file produced $esv_n2 I93 finding(s) where exactly 1 is correct -- the seed is tripping arms beyond the exemption control, so this arm's kill is not attributable to it"
  else
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A38-m2 "A38-m2: the exemption control still fires on its OWN case when the sweep COMPLETED, and on that case ALONE (the stand-down narrowed it to the aborted-scan case rather than switching it off, and the seed trips nothing else)"
  fi
  mx_twins A38-m2 "$out"
fi
cp "$XP_BAK" "$XP"; rm -f "$XP_BAK"
}


# --- Assertion 39: I93 arm E -- a FOURTH spelling of the empty-subject verdict ------
# Arm C refuses three RETIRED spellings BY NAME and an enumeration cannot reach a spelling
# nobody has written yet; arm D joins on files that print the DECLARED token, so a file
# spelling the verdict its own way is outside its population by construction. Measured before
# arm E: a seeded validator whose only emission was `NOTHING TO EXAMINE HERE` drove the
# validator to rc 0 with no finding, while the same seed carrying the RETIRED `AUDITED
# NOTHING` from the same position WAS caught -- so the escape was the grammar, not the seat.
#
# THE SPELLING IS NOVEL BY CONSTRUCTION, NOT BY ASSERTION. The seed's phrase must be one no
# declared or retired spelling contains, or the arm-1 kill could be arm A's or arm C's. It is
# built from the DERIVED token and checked against it: if the token ever becomes the seed's
# own words this arm says FIXTURE BROKEN rather than scoring a kill it did not earn.
#
# FIVE ARMS, AND THE LAST TWO ARE WHY THE FIRST THREE MEAN ANYTHING. A fire-only battery
# passes against an arm that reports every `echo`, which would red the tree on every
# validator's diagnostics; a quiet-only battery passes against an arm deleted outright.
A39_i93_novel_spelling() {
esv_tok="$(i93_token)"
if [ -z "$esv_tok" ]; then
  bad "FIXTURE BROKEN: could not derive empty_subject_verdict.token, so arm E's seeds would be scored against nothing"
  return
fi
esv_novel_say='NOTHING TO EXAMINE HERE'
case "$esv_tok" in
  *"$esv_novel_say"*) bad "FIXTURE BROKEN: the declared token now CONTAINS this arm's novel phrase, so arm 1's kill could belong to arm A or arm C rather than to arm E"; return ;;
esac

# ARM 1 — A NOVEL SPELLING UNDER core/scripts/. Not named validate-*.sh, for arm 35's reason:
# arm E's population is every FILE in the directory, and a name matching the convention would
# leave this unable to tell that from a narrower grammar.
esv_core_new="$ROOT/core/scripts/esv-fourth.sh"
printf '%s\n' '#!/usr/bin/env bash' "echo \"esv-fourth: $esv_novel_say — the corpus was empty.\"" 'exit 0' > "$esv_core_new"
out="$(vrun)"
if mx_red A39-m1 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A39-m1 "A39-m1: a core/scripts/ validator stating the empty-subject verdict in a FOURTH spelling FAILS I93, reported by LINE (arm C's enumeration cannot reach a spelling nobody has written yet)" && B_a39m1=1
else
  bad "A39-m1 SURVIVED: a novel empty-subject spelling under core/scripts/ did not fail I93 — the fourth spelling seeds clean exactly as it did before arm E, and the vocabulary index reads as complete while a new emitter spells the verdict however it likes"
fi
mx_twins A39-m1 "$out"

# ARM 2 — THE SAME SEED UNDER scripts/. The distribution-only half of arm D's population, and
# the half where two of arm E's three real exemptions live.
rm -f "$esv_core_new"
esv_dist_new="$ROOT/scripts/esv-fourth-dist.sh"
printf '%s\n' '#!/usr/bin/env bash' "echo \"esv-fourth: $esv_novel_say — the corpus was empty.\"" 'exit 0' > "$esv_dist_new"
out="$(vrun)"
if mx_red A39-m2 "$out"; then
  mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A39-m2 "A39-m2: the same novel spelling under scripts/ FAILS I93 too (arm E sweeps the distribution-only half, not just core/scripts/)"
else
  bad "A39-m2 SURVIVED: a novel spelling under scripts/ did not fail I93 — arm E has narrowed to core/scripts/, and two of its three exemptions live in the half it stopped reading"
fi
mx_twins A39-m2 "$out"
rm -f "$esv_dist_new"

# ARM 3 — THE NEAR-MISSES, four shapes in ONE file, because each is a real thing in this
# corpus and any one of them firing reds the tree on a conforming validator:
#   a `#` comment      -- every emitter's exit-code table
#   an `err` argument  -- a FAILURE message, which is not the empty-subject state; eight lines
#                         INSIDE the I93 unit itself are this shape
#   a `%-Ns` row       -- sprint-status.sh's per-view report line
#   a `> path` write   -- a probe seeding a fixture tree, including arm E's own six seeds
printf '%s\n' '#!/usr/bin/env bash' \
  "#   0 = $esv_novel_say, in an exit-code table" \
  'err "the corpus is empty: found nothing to scan. Failing closed."' \
  'print("  %-15s no key — nothing to compare" % view)' \
  'printf "%s\n" "audited nothing" > "$TMP/seed.sh"' > "$esv_core_new"
VRUN_NOMX=1; out="$(vrun)"; VRUN_NOMX=""
if grep -q 'esv-fourth.sh' <<<"$out"; then
  bad "A39-c1: arm E fired on a comment, an err() argument, a padded table row or a probe seed write — each is a live shape in this corpus, so the arm would red the tree on validators that are conforming, and the first one alone appears eight times inside the I93 unit it lives in"
elif grep -q '^OK: enforcement-map.yaml in sync' <<<"$out"; then
  ok "A39-c1: a file carrying the phrase ONLY as a comment, an err() argument, a %-Ns table row and a file-redirected seed write does NOT fail I93, and the run still reaches its verdict (the narrowing is the emission site, not the words)"
else
  bad "A39-c1: the near-miss tree neither failed on the seeded path nor reached I93's OK verdict — the run did not get far enough for this arm's silence to mean anything"
fi

# ARM 4 — A FILE THAT ALREADY EMITS THE DECLARED TOKEN IS NOT REPORTED, even when it also
# states an empty subject in its own words elsewhere. This is validate-bmad-invocations.sh's
# real shape: it prints the token at one line for one state and says "nothing to resolve
# against" at another for a different one. Without this, arm E tells a conforming emitter to
# converge on a token it already prints.
printf '%s\n' '#!/usr/bin/env bash' "echo \"DISARMED — $esv_tok — no corpus.\"" \
  "echo \"and separately: $esv_novel_say\"" > "$esv_core_new"
VRUN_NOMX=1; out="$(vrun)"; VRUN_NOMX=""
if grep -q "esv-fourth.sh.* states an empty-subject verdict" <<<"$out"; then
  bad "A39-c2: arm E reported a file that ALREADY emits the declared token — a conforming emitter is told to adopt a token it prints, and every declared emitter carrying prose about an empty subject would red the tree"
else
  ok "A39-c2: a file already emitting the declared token is NOT reported by arm E even when it states an empty subject in its own words elsewhere (the join is per FILE, which is what the arm actually asks)"
fi

# ARM 4b — THE EXEMPT-SKIP DOES NOT COVER ARM E's OWN SUBJECT. Arm E skips a path arm D
# exempts, because its remedy ("add the file to `emitters:`") is forbidden for one -- and an
# exemption is a hole, so the question mechanism-design.md asks of every hole is what ELSE it
# acquits. The seed is a NOVEL SPELLING placed in an exempt file, which is the case the skip
# must NOT swallow silently: arm D's exemption control is required to find that file emitting
# the declared token, so a file that stops emitting it is reported there, by name, in the same
# run. Both halves are asserted -- arm E stays quiet AND arm D speaks -- because arm E's
# silence alone is what a skip that covers everything also looks like.
esv_xp2="$(awk -F"'" '/^[[:space:]]*ESV_EXEMPT=/ { split($2, a, " "); print a[1]; exit }' "$V")"
if [ -z "$esv_xp2" ] || [ ! -f "$ROOT/$esv_xp2" ]; then
  bad "FIXTURE BROKEN: could not derive an existing exempt path from the validator, so the exempt-skip's own acquittal is unproven"
else
  esv_xp2_bak="$(mkbak "$ROOT/$esv_xp2")"
  printf '%s\n' '#!/usr/bin/env bash' "echo \"exempt-but-novel: $esv_novel_say\"" 'exit 0' > "$ROOT/$esv_xp2"
  out="$(vrun)"
  if grep -q "$esv_xp2:.* states an empty-subject verdict" <<<"$out"; then
    bad "A39-m3: arm E reported an EXEMPT path, so the skip is not in force and the arm prints a remedy (declare it) that contradicts the exemption"
  elif grep -q "arm D exempts '$esv_xp2' and arm D's own sweep found no line of it" <<<"$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A39-m3 "A39-m3: an exempt file that swaps the declared token for a NOVEL spelling is reported by arm D's exemption control, not by arm E (the skip hands the case to the arm whose remedy is legal, and does not swallow it)"
  else
    bad "A39-m3: an exempt file that stopped emitting the declared token was reported by NEITHER arm -- arm E's skip has acquitted arm E's own subject and arm D's control did not pick it up, so this state is now unguarded in both directions"
  fi
  mx_twins A39-m3 "$out"
  cp "$esv_xp2_bak" "$ROOT/$esv_xp2"; rm -f "$esv_xp2_bak"
fi

# ARM 5 — THE MUTANT, AND WHAT IT ESTABLISHES THAT ARM 1 DOES NOT. Arm 1 asserts a message
# appears; it cannot tell whether arm E produced it. So arm E's reporter is neutered with the
# SAME seed in place and both halves are asserted: the seeded path is no longer named, AND the
# run still reaches its own OK verdict. The second half is what stops this being an absence.
#
# ANCHORED ON `states an empty-subject verdict in a spelling of its own`, which is arm E's
# reporter alone. Arm A's message and arm D's both contain "outside a comment"; a mutation
# keyed on a shared phrase would edit more than one arm.
#
# THE BACKUP LIVES OUTSIDE THE SEEDED TREE, and that is arm E's own subject biting the idiom
# every assertion above uses. `V_BAK="$(mkbak "$V")"` puts a SECOND copy of the validator in
# `$ROOT/scripts/`, which is half of the population arms D and E sweep -- so the backup is
# itself an undeclared emitter of the declared token, arm D reports it, and the run goes red
# for a reason this arm never seeded. Measured: with `$V.orig` beside `$V` the mutant run
# printed one finding naming `scripts/validate-enforcement-map.sh.orig` and neither named the
# seed nor reached the OK verdict, which reads exactly like a mutant that broke the wrong arm.
printf '%s\n' '#!/usr/bin/env bash' "echo \"esv-fourth: $esv_novel_say — the corpus was empty.\"" 'exit 0' > "$esv_core_new"
esv_bak="$(mkbak "$V")"
sed 's@^\( *\)err "I93: .*states an empty-subject verdict in a spelling of its own.*@\1:@' "$esv_bak" > "$V"
if cmp -s "$esv_bak" "$V"; then
  bad "FIXTURE BROKEN: the arm E reporter mutation matched nothing in the validator, so arm 1 above is a message somebody observed and not a finding attributed to arm E"
else
  out="$(vrun)"
  if grep -q 'esv-fourth.sh' <<<"$out"; then
    bad "A39-m4: arm E's reporter was neutered and the seeded novel spelling was STILL named — the finding arm 1 scores as arm E's kill comes from somewhere else, and deleting arm E would leave this battery green"
  elif grep -q '^OK: enforcement-map.yaml in sync' <<<"$out"; then
    mutant_killed "${B_a39m1:-0}" A39-m4 "A39-m4: neutering arm E's reporter makes the SAME seeded novel spelling go unreported while the rest of I93 still reaches its verdict (arm 1's kill belongs to arm E, and the seed trips no other arm)"
  else
    bad "A39-m4: with arm E's reporter neutered the run neither named the seed nor reached I93's OK verdict — the mutant broke something other than the arm it aimed at"
  fi
  mx_twins A39-m4 "$out"
fi
cp "$esv_bak" "$V"

# ARM 6 — THE OPPOSITE MUTANT: an arm E that flags EVERY emission. A fire-only battery cannot
# tell a discriminating grammar from one that reports the whole corpus, and the over-broad
# form is the likelier wrong build: it passes arms 1 and 2 and reds the tree on ~30 conforming
# lines. The verdict phrase test is replaced with an unconditional match, the seed is REMOVED
# so the tree is the clean one, and the run must still be green.
rm -f "$esv_core_new"
esv_bak="$(mkbak "$V")"
sed 's@^      if (u !~ VERD) next$@      if (0) next@' "$esv_bak" > "$V"
if cmp -s "$esv_bak" "$V"; then
  bad "FIXTURE BROKEN: the arm E over-broad mutation matched nothing, so this arm cannot tell a discriminating grammar from one that flags every echo"
else
  out="$(vrun)"
  if mx_red A39-m5 "$out"; then
    mutant_killed "$([ "$CTL_RC" = 0 ] && echo 1 || echo 0)" A39-m5 "A39-m5: an arm E whose verdict-phrase test is removed REDS the clean tree (the phrase grammar is load-bearing, not decoration on a scan that flags every emission)"
  else
    bad "A39-m5 SURVIVED: arm E with its verdict-phrase test removed still passed the clean tree — the grammar is doing no work, which means arm 1's kill would be scored by a scan that reports every echo and the arm has no false-positive story at all"
  fi
  mx_twins A39-m5 "$out"
fi
cp "$esv_bak" "$V"
rm -f "$esv_bak"
}

# --- Assertions 40-43: I91 / I94 / I95 / I81 READ THE TREE THEY VALIDATE, FROM ANY CWD ------
# THE DEFECT. Those four arms spelled their corpus relative to the PROCESS cwd, and the validator
# never moved there. A seeded copy run from a scratch directory reported the schema or the hooks
# "missing" (rc 1); the same copy run from the repo root read the LIVE tree and returned a false
# clean on an offender planted only in the seed. The fix makes the self path absolute once
# (VEM_SELF), derives REPO_ROOT from it, and cds there.
#
# FOUR CELLS PER ID, each against the SEEDED validator with the offender present ONLY in the
# seed. Every cell requires rc 1 AND the finding naming the seeded file AND output byte-equal
# to C1 -- a cell keyed on equality alone scores two identical "schema missing" runs as a pass:
#   C1  from a fresh `mktemp -d` cwd.
#   C2  from a DECOY ROOT ($EMS_DECOY): the shard's seed template plus the distribution's VERSION
#       and a `git init`, a complete tree carrying no offender. It used to be the LIVE distribution root, and it
#       is not any more because every mutant run from there read the whole live tree (~45 heavy
#       greps per traced run). The decoy discriminates for the same reason the live root did:
#       the old code read its CWD's tree, the cwd's tree has every file the validator wants and
#       no seeded offender, so a cwd-reading validator returns rc 0 there -- the BL-436 false
#       clean. M1 is REQUIRED to reproduce that on C2 (rc 0; for I95, whose M1 names the seeded
#       finding from every complete tree, the finding NAMED), which is the standing proof that
#       the decoy is a complete tree; an empty or partial decoy makes a cwd-reading validator
#       fail on "missing" files, the bits stay 0, and only that rc tells the two apart. The same
#       predicate is run in the same call from an EMPTY cwd and must come out the other way, so
#       a predicate that cannot fire fails rather than passes.
#       IT ALSO CARRIES THE MARKERS A WALK-UP KEYS ON. The decoy holds VERSION and a `.git`, so a
#       regression that walks UP from the cwd for VERSION, or asks `git rev-parse
#       --show-toplevel`, resolves to the decoy and reads it -- the live root had both, and a
#       VERSION-less decoy measurably passed a VERSION walk-up the live root failed. The cells'
#       own trees are copied from the template, NOT the decoy, so they still lack VERSION (the
#       validator's I45 guard is written for that).
#       The messages still say "live root" for this cell so that output stays byte-comparable
#       across the change; the word names the cell, and the cell is the decoy.
#   C3  from "$ROOT/core", by the RELATIVE path ../scripts/validate-enforcement-map.sh. A
#       cd-only fix broke this one: `--arms` re-reads its own file by name after the cd, so a
#       relative $0 resolved against the moved cwd and the run exited 2.
#   C4  from a fresh cwd with VEM_SELF EXPORTED, naming the decoy's validator (it named the live
#       one, for C2's reason). The validator
#       honours VEM_SELF only when its own shell set it; an inherited value redirected every arm
#       to the named tree and read the seeded offender as clean.
#
# SCORED AS A BIT STRING, NOT CELL BY CELL, because each mutant must move a specific SUBSET and
# nothing else. A mutant that kills C3 alone is told apart from one that kills all three only if
# every cell is reported.
#
# THE MUTANTS edit the seeded validator in place, so its siblings stay beside it, each from a
# backup held OUTSIDE the tree for A39's reason, each `cmp -s` guarded and each asserting its own
# post-mutation count, so a `sed` that matched only part of the fix is not scored as the mutant:
#   M1  the full base: the guard, the VEM_SELF lines, the cd line, and every $VEM_SELF read
#       back to $0. Expected 0000.
#   M2  only the cd line deleted. Expected 0000 -- without the cd, no cwd outside the seed reads it.
#   M3  the cd kept, VEM_SELF taken from $0 WITHOUT absolutisation. Expected 1101: the
#       absolute-path cells still pass and only the relative one dies.
#   M4  only the inherited-VEM_SELF guard deleted. Expected 1110: only C4 dies.
#
# A MUTANT RUN DOES NOT WRITE THE BROKEN MARKER. M3's relative cell exits 2 BY DESIGN -- that is
# the failure it must produce -- and vrun would otherwise record it as FIXTURE BROKEN. Control
# runs keep the marker, so an rc 2 from the UNMUTATED validator is still a broken fixture.
CWD_SELF_REL="../scripts/validate-enforcement-map.sh"

# cwd_cells <control|mutant> <ERE naming the seeded finding>
# Sets CW_BITS (e.g. 1111) and CW_RCS, and leaves C1's output in "$CW_DIR/s.out".
cwd_cells() {
  local mode="$1" want="$2" s rcf rc_s rc_r rc_rel rc_env b1=0 b2=0 b3=0 b4=0 keep_broken
  # The cells ARE the matrix for a cwd mutant: every cell runs on every push, so vrun's
  # matrix-only full run is not taken here. A cwd mutant edits only the prologue, which every
  # arm outside the unit reads identically, and cwd_full already holds the one full-mode cell.
  local VRUN_NOMX=1
  keep_broken="$VRUN_BROKEN"
  [ "$mode" = control ] || keep_broken=""
  s="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp -d failed" >&2; exit 2; }
  rcf="$CW_DIR/rc"
  printf 'none\n' > "$rcf"
  (VRUN_BROKEN="$keep_broken"; VRUN_RCF="$rcf"; cd "$s" && vrun) > "$CW_DIR/s.out"
  rc_s="$(cat "$rcf")"
  printf 'none\n' > "$rcf"
  (VRUN_BROKEN="$keep_broken"; VRUN_RCF="$rcf"; cd "$EMS_DECOY" && vrun) > "$CW_DIR/r.out"
  rc_r="$(cat "$rcf")"
  printf 'none\n' > "$rcf"
  (VRUN_BROKEN="$keep_broken"; VRUN_RCF="$rcf"; cd "$ROOT/core" && vrun "$CWD_SELF_REL") > "$CW_DIR/rel.out"
  rc_rel="$(cat "$rcf")"
  printf 'none\n' > "$rcf"
  (VRUN_BROKEN="$keep_broken"; VRUN_RCF="$rcf"; export VEM_SELF="$EMS_DECOY/scripts/validate-enforcement-map.sh"; cd "$s" && vrun) > "$CW_DIR/env.out"
  rc_env="$(cat "$rcf")"
  rmdir "$s" 2>/dev/null
  if [ "$rc_s" = 1 ] && grep -qE -- "$want" "$CW_DIR/s.out"; then b1=1; fi
  if [ "$rc_r" = 1 ] && grep -qE -- "$want" "$CW_DIR/r.out" && cmp -s "$CW_DIR/s.out" "$CW_DIR/r.out"; then b2=1; fi
  if [ "$rc_rel" = 1 ] && grep -qE -- "$want" "$CW_DIR/rel.out" && cmp -s "$CW_DIR/s.out" "$CW_DIR/rel.out"; then b3=1; fi
  if [ "$rc_env" = 1 ] && grep -qE -- "$want" "$CW_DIR/env.out" && cmp -s "$CW_DIR/s.out" "$CW_DIR/env.out"; then b4=1; fi
  CW_BITS="$b1$b2$b3$b4"
  CW_RCS="rc scratch=$rc_s live-root=$rc_r relative=$rc_rel inherited-VEM_SELF=$rc_env"
  CW_RC_ROOT="$rc_r"
}

# a1_holds <rc> <output file> <ERE> -- what M1 (the cwd-reading base) shows when its cwd is a
# COMPLETE tree carrying no offender. For I91, I94 and I81 that is the false clean, rc 0. I95 is
# different: its M1 C2 cell exits 1 from the live root too (measured at the base of this change),
# because its M1 run still names the seeded finding from a complete tree; so for I95 the
# predicate is that the seeded finding is NAMED. Both are presence-shaped against the empty-cwd
# probe in cwd_mutant, where a cwd-reading validator fails on missing files and names nothing.
a1_holds() { # a1_holds <rc> <output file> <ERE>
  if [ "$CW_ID" = I95 ]; then grep -qE -- "$3" "$2"; else [ "$1" = 0 ]; fi
}
a1_says() {
  if [ "$CW_ID" = I95 ]; then echo "the seeded finding named"; else echo "rc 0"; fi
}

# cwd_mutant <tag> <expected bits> <ERE> <sed program> <post-check ERE> <post-check count>
cwd_mutant() {
  local tag="$1" exp="$2" want="$3" prog="$4" pce="$5" pcn="$6" bak n
  bak="$(mkbak "$V")"
  if ! sed -e "$prog" "$bak" > "$V"; then
    bad "$CW_ID $tag DID NOT APPLY: its sed program failed, so no mutant existed to score"
    cp "$bak" "$V"; rm -f "$bak"; return
  fi
  n="$(grep -cE -- "$pce" "$V")" || n=0
  if cmp -s "$bak" "$V"; then
    bad "$CW_ID $tag DID NOT APPLY: the mutation matched nothing in the validator, so its verdict would be about the unmutated fix"
  elif [ "$n" != "$pcn" ]; then
    bad "$CW_ID $tag applied but is INSUFFICIENT: the post-mutation count of /$pce/ is $n where $pcn was expected, so it is not the mutant its verdict would be read as"
  else
    cwd_cells mutant "$want"
    # THE DECOY'S PRESENCE PROOF, WITH ITS OWN SELF-PROBE IN THE SAME CALL. M1 is the base code,
    # which reads its cwd's tree; run from a complete decoy carrying no offender, C2 must show what
    # the base code shows from a complete tree (a1_holds). An empty or partial decoy fails it on
    # missing files instead while the bits stay 0000, so without this a decoy that discriminates
    # nothing scores identically. The SAME predicate is then applied to the same M1 run from an
    # EMPTY cwd and must NOT hold there -- a predicate keyed on a value nobody sets, or one that
    # holds for any input, holds on both and fails here instead of passing silently. No ok line
    # of its own: the M1 line below reports it, and this file's stdout stays byte-comparable.
    # ONE CALL SITE FOR THE CHECK AND ITS PROBE. The loop's first pass reads C2's OWN result; the
    # second overwrites the very same variable and file with M1 run from an empty cwd. The
    # predicate is evaluated by one expression on both passes, so a predicate -- or an argument
    # at that call -- keyed on something nobody sets is wrong on both, and the probe fires.
    a1_fail=""
    if [ "$tag" = M1 ]; then
      local a1_pass a1_e a1_decoy=0 a1_empty=0 a1_rc_decoy a1_rc_empty
      a1_rc_decoy="$CW_RC_ROOT"
      for a1_pass in decoy empty; do
        if [ "$a1_pass" = empty ]; then
          a1_e="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp -d failed" >&2; exit 2; }
          printf 'none\n' > "$CW_DIR/rc"
          (VRUN_BROKEN=""; VRUN_RCF="$CW_DIR/rc"; VRUN_NOMX=1; cd "$a1_e" && vrun) > "$CW_DIR/r.out"
          CW_RC_ROOT="$(cat "$CW_DIR/rc")"; a1_rc_empty="$CW_RC_ROOT"
          rmdir "$a1_e" 2>/dev/null
        fi
        if a1_holds "$CW_RC_ROOT" "$CW_DIR/r.out" "$want"; then eval "a1_$a1_pass=1"; fi
      done
      if [ "$a1_decoy" != 1 ]; then
        a1_fail="$CW_ID M1 on C2 (decoy root $EMS_DECOY) does not show what the cwd-reading base shows from a complete tree ($(a1_says); $CW_RCS) -- the decoy is not a complete tree, so C2 discriminates nothing"
      elif [ "$a1_empty" != 0 ]; then
        a1_fail="$CW_ID M1 decoy-proof SELF-PROBE did not fire: the same predicate ($(a1_says)) also holds for M1 run from an EMPTY cwd (rc $a1_rc_empty; decoy rc $a1_rc_decoy), so it cannot tell a complete decoy from no tree at all"
      fi
    fi
    if [ -n "$a1_fail" ]; then
      bad "$a1_fail"
    elif [ "$CW_BITS" = "$exp" ]; then
      mutant_killed "${B_cw:-0}" "$CW_ID-$tag" "$CW_ID-$tag: $CW_ID $tag scores $CW_BITS on C1 scratch / C2 live root / C3 relative / C4 inherited VEM_SELF, exactly the cells it must kill ($CW_RCS)"
    else
      bad "$CW_ID-$tag SURVIVED: $CW_ID $tag scored $CW_BITS where $exp was expected ($CW_RCS) -- the cells do not discriminate this layer of the fix the way they claim to"
    fi
    cwd_mx "$CW_ID-$tag" "C1=${CW_BITS:0:1} C2=${CW_BITS:1:1} C3=${CW_BITS:2:1} C4=${CW_BITS:3:1}"
  fi
  cp "$bak" "$V"; rm -f "$bak"
}

# cwd_mx <name> "<cell>=<bit> ..." -- MATRIX-ONLY. A cell bit of 0 is RED (the mutant killed that
# cwd) and 1 is GREEN. The header row's decides= list must be all RED and its twins all GREEN.
# The selected-unit diff and the rc-outside-0/1 refusal do not apply: M3's relative cell exits
# 2 BY DESIGN, and the cells, not a FAIL: set, are what a cwd mutant is scored on.
cwd_mx() {
  local n="$1" cells="$2" dec tw c b col uex="" dl="" tl="" f
  [ "$MX_MODE" = matrix ] || return 0
  printf 'mx-score %s\n' "$n" >> "$MX_LEDGER"
  for f in s.out r.out rel.out env.out full.out; do
    if [ -f "$CW_DIR/$f" ] && grep -qE -- "$MX_CRASH" "$CW_DIR/$f"; then
      printf 'MATRIX BROKEN %s\n' "$n"
      [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: MATRIX BROKEN %s -- a cwd cell printed a crash shape\n' "$n" >> "$VRUN_BROKEN"
      return
    fi
  done
  dec="$(mx_row "$n" decides)"; tw="$(mx_row "$n" twins)"
  for c in $cells; do
    b="${c#*=}"; c="${c%%=*}"
    if [ "$b" = 0 ]; then col=RED; else col=GREEN; fi
    case ",$dec," in *",$c,"*) dl="$dl,$c:$col"; [ "$col" = RED ] || uex="$uex,$c:GREEN"; continue ;; esac
    case ",$tw," in *",$c,"*) tl="$tl,$c:$col"; [ "$col" = GREEN ] || uex="$uex,$c:RED"; continue ;; esac
    uex="$uex,$c:$col"
  done
  [ -n "$tl" ] || tl=",-"
  if [ -n "$uex" ]; then
    printf 'MATRIX %s decides=%s twins=%s others=0/0 UNEXPECTED=%s\n' "$n" "${dl#,}" "${tl#,}" "${uex#,}"
    bad "MATRIX $n does not match its header row: ${uex#,}"
  else
    printf 'MATRIX %s decides=%s twins=%s others=0/0\n' "$n" "${dl#,}" "${tl#,}"
  fi
}

# The four mutants, defined once so that every id that runs one runs the SAME one.
# `cwd_battery <ERE> <tag>...` runs only the tags named. There is no default: an id that runs a
# mutant names it at the call site, where the placement below can be read.
#
# EACH MUTANT RUNS ON ONE NON-I95 ID, AND I95 KEEPS M1. Every mutant edits the validator's SHARED
# prologue (the VEM_SELF guard, the absolutisation, the cd), so its edit is byte-identical for
# every id. What differs between ids is only how the ARM resolves its inputs, read from the
# validator:
#   I91, I94, I81  read every input relative to the process cwd (`core/schemas/...` with -f,
#                  `grep -r core/ scripts/`, `core/hooks/...`), and nothing else.
#   I95            checks its schema relative to the cwd, but hands python "$REPO_ROOT", which is
#                  ABSOLUTE once computed -- so with the cd gone it still reads the SEEDED tree.
# So per mutant:
#   M1, M2  kill C2 for I91/I94/I81 by the SAME conjunct (rc 0: the cwd-reading arm reads the
#           offender-free decoy) and C1/C3/C4 by the same "required input missing" rc 1 with no
#           finding. For I95 they kill C2 by a DIFFERENT conjunct -- rc 1 and the finding named,
#           but output unequal to C1 -- which is why a1_holds special-cases it, and why I95 keeps
#           its own M1. I95 M2 is the twin of I95 M1: with the cd gone, nothing a cell observes
#           depends on the VEM_SELF lines M1 also reverts, so the two score the same cells for
#           the same reason.
#   M3      dies at the `--arms` block's `[ ! -r "$VEM_SELF" ]` (exit 2 on C3) BEFORE any arm is
#           evaluated, so the arm cannot influence it: a twin across all four ids.
#   M4      redirects the WHOLE run to the decoy on C4 (REPO_ROOT, the cd, and the --arms source
#           are all the decoy's), so every id, I95's absolute python read included, reads the
#           decoy and returns rc 0: a twin across all four ids.
# PLACEMENT IS BOUND BY THE DECOY PROOF, AND THE DECOY IS PER SHARD. Each shard builds its own
# decoy, and only M1 proves it complete (a1_holds, with its empty-cwd self-probe). M2's C2, M4's
# C4 and M5's full-mode cell each read 0 on a PARTIAL decoy too (missing files: rc 1, no
# finding), which is a kill for the wrong reason. So every one of those runs in a shard that also
# runs an M1: the round-robin deal puts A40 (I91) and A43 (I81) in shard a, A41 (I94) in b and
# A42 (I95) in c. I91 runs M1 and M5, I81 runs M2, M3 and M4, I95 runs its own M1, and I94 runs
# its control alone, because no decoy-reading mutant runs in shard b. Every id keeps its unmutated
# control, which is the only cell proving THAT id's own arm reads the seeded tree from every cwd;
# the mutants prove the CELLS discriminate, and that is a property of the prologue, not the arm.
cwd_battery() {
  local want="$1" t; shift
  [ "$#" -gt 0 ] || { bad "FIXTURE BROKEN: cwd_battery for $CW_ID was called with no mutant tags, so it would score nothing"; return; }
  for t in "$@"; do
    case "$t" in
      M1) cwd_mutant M1 0000 "$want" '/^\[ "\${VEM_SELF_PID:-}" = "\$\$" \] || unset VEM_SELF$/d
/^VEM_SELF_PID=\$\$$/d
/^case "\${VEM_SELF:-\$0}" in /d
/^\[ -n "\$REPO_ROOT" \] \&\& cd "\$REPO_ROOT" || {/d
s/\$VEM_SELF/$0/g' '^[^#]*VEM_SELF|cd "\$REPO_ROOT" \|\|' 0 ;;
      M2) cwd_mutant M2 0000 "$want" '/^\[ -n "\$REPO_ROOT" \] \&\& cd "\$REPO_ROOT" || {/d' 'cd "\$REPO_ROOT" \|\|' 0 ;;
      M3) cwd_mutant M3 1101 "$want" 's/^case "\${VEM_SELF:-\$0}" in .*/VEM_SELF="$0"/' '^VEM_SELF="\$0"$' 1 ;;
      M4) cwd_mutant M4 1110 "$want" '/^\[ "\${VEM_SELF_PID:-}" = "\$\$" \] || unset VEM_SELF$/d' '^\[ "\$\{VEM_SELF_PID:-\}" = "\$\$" \] \|\| unset VEM_SELF$' 0 ;;
      *) bad "FIXTURE BROKEN: cwd_battery for $CW_ID was asked for unknown mutant '$t'" ;;
    esac
  done
}

# The unmutated control. Its positive conjunct is the finding itself: every cell demands it be
# PRESENT, so a validator that prints nothing cannot score 1111.
cwd_control() {
  local want="$1"
  CW_DIR="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp -d failed" >&2; exit 2; }
  cwd_cells control "$want"
  B_cw=0
  if [ "$CW_BITS" = 1111 ]; then
    ok "$CW_ID: the seeded offender is named from a scratch cwd, and byte-identically from the live distribution root, from \$ROOT/core by a relative path, and with an inherited VEM_SELF naming the live validator ($CW_RCS)"
    B_cw=1
  else
    bad "$CW_ID: the unmutated validator scored $CW_BITS on the cwd cells ($CW_RCS) -- it does not read the seeded tree from every cwd, or the seeded offender went unreported"
  fi
}

# FULL MODE, scored on I91 only. Every cell above runs `--arms`, and so does the BL-436 receipt,
# but the pre-push hook and most seeded callers run the validator with NO flags. A fix that cds
# only inside the `--arms` block passed all four cells and the receipt while a full-mode run of
# the seeded tree from the live root still read the live tree and returned rc 0 -- measured by
# the tip adversary. One full run from the live root, requiring rc 1 and the seeded finding.
# M5 moves the cd into the `--arms` block and must leave the four cells at 1111 and kill this.
cwd_full_bit() { # cwd_full_bit <ERE> -> prints 1 or 0, and leaves the run in "$CW_DIR/full.out"
  local rc
  (cd "$EMS_DECOY" && bash "$V") > "$CW_DIR/full.out" 2>&1; rc=$?
  if [ "$rc" = 1 ] && grep -qE -- "$1" "$CW_DIR/full.out"; then echo 1; else echo 0; fi
}
cwd_full() {
  local want="$1" fb bak
  fb="$(cwd_full_bit "$want")"
  B_cwfull=0
  if [ "$fb" = 1 ]; then
    ok "$CW_ID FULL MODE: the seeded validator with no --arms, run from the live root, names the seeded offender"
    B_cwfull=1
  else
    bad "$CW_ID FULL MODE: the seeded validator with no --arms, run from the live root, did not name the seeded offender -- it read the live tree ($(grep -cE '^FAIL' "$CW_DIR/full.out") FAIL line(s))"
  fi
  bak="$(mkbak "$V")"
  sed -e '/^\[ -n "\$REPO_ROOT" \] \&\& cd "\$REPO_ROOT" || {/d' \
      -e 's/^  eval "\$arms_prog"$/  cd "$REPO_ROOT"; eval "$arms_prog"/' "$bak" > "$V"
  if cmp -s "$bak" "$V" || [ "$(grep -c '^  cd "\$REPO_ROOT"; eval "\$arms_prog"$' "$V")" != 1 ] \
     || grep -q '^\[ -n "\$REPO_ROOT" \] && cd' "$V"; then
    bad "$CW_ID M5 DID NOT APPLY: the cd was not moved into the --arms block, so no mutant existed to score"
  else
    cwd_cells mutant "$want"
    fb="$(cwd_full_bit "$want")"
    if [ "$CW_BITS$fb" = 11110 ]; then
      mutant_killed "$(( ${B_cw:-0} && ${B_cwfull:-0} ))" "$CW_ID-M5" "$CW_ID-M5: $CW_ID M5 (cd only inside --arms) scores ${CW_BITS}+full=$fb: the four --arms cells cannot see it and the full-mode cell kills it"
    else
      bad "$CW_ID-M5 SURVIVED: $CW_ID M5 (cd only inside --arms) scored ${CW_BITS}+full=$fb where 1111+full=0 was expected ($CW_RCS)"
    fi
    cwd_mx "$CW_ID-M5" "C1=${CW_BITS:0:1} C2=${CW_BITS:1:1} C3=${CW_BITS:2:1} C4=${CW_BITS:3:1} FULL=$fb"
  fi
  cp "$bak" "$V"; rm -f "$bak"
}

cwd_finish() { rm -f "$CW_DIR/s.out" "$CW_DIR/r.out" "$CW_DIR/rel.out" "$CW_DIR/env.out" "$CW_DIR/full.out" "$CW_DIR/rc"; rmdir "$CW_DIR" 2>/dev/null; }

A40_i91_cwd_invariance() {
CW_ID=I91
i91_pfx='<task-notification'
printf 'x="%s"\n' "$i91_pfx" > "$ROOT/core/scripts/zz-i91-cwd-offender.sh"
# A core/fixtures/ copy for that exemption, and every exempt file asserted to CARRY the prefix:
# a near-miss without it would be acquitted for having nothing to report, not by the exemption.
printf 'x="%s"\n' "$i91_pfx" > "$ROOT/core/fixtures/enforcement-map-sites/zz-i91-nearmiss.txt"
i91_nm_ok=1
for f in core/schemas/harness-origin.json core/scripts/validate-steering-budget.sh \
         scripts/validate-enforcement-map.sh core/fixtures/enforcement-map-sites/zz-i91-nearmiss.txt; do
  grep -qF -- "$i91_pfx" "$ROOT/$f" || { i91_nm_ok=0; bad "FIXTURE BROKEN: exempt file $f does not carry $i91_pfx, so the I91 near-miss would be acquitted for having nothing to report"; }
done
# I91 emits one indented `path:literal` line per copy (one grep -roF pass over core/ and scripts/).
want='^  core/scripts/zz-i91-cwd-offender\.sh:<task-notification$'
cwd_control "$want"
if [ "$i91_nm_ok" = 1 ]; then
  i91_hits="$(grep -E -- '^  [^[:space:]]+:' "$CW_DIR/s.out")"
  if [ -z "$i91_hits" ]; then
    bad "I91 near-miss: the scratch-cwd run printed no copy-hit line at all, so the exemption has nothing to be read against"
  elif grep -qE 'core/schemas/harness-origin\.json|core/scripts/validate-steering-budget\.sh|scripts/validate-enforcement-map\.sh|core/fixtures/' <<<"$i91_hits"; then
    bad "I91 near-miss: an exempt file (the schema, the JS predicate, the validator or a core/fixtures/ file) was reported as a copy from a scratch cwd -- the exclusion filters no longer match the paths the scan emits"
  else
    ok "I91 near-miss: the schema, validate-steering-budget.sh, the validator and a core/fixtures/ file all carry the prefix and none is reported, beside the seeded offender that is"
  fi
fi
cwd_battery "$want" M1
cwd_full "$want"
cwd_finish
}

A41_i94_cwd_invariance() {
CW_ID=I94
python3 - "$ROOT/core/schemas/pause-routing.json" "$ROOT/core/rules/zz-i94-cwd-offender.md" <<'PY' || { bad "FIXTURE BROKEN: could not seed the I94 offender from the declared pause_branch_text"; return; }
import json, sys
v = json.load(open(sys.argv[1]))["pause_branch_text"]
assert v
open(sys.argv[2], "w").write(v + "\n")
PY
want='pause_branch_text -> .*core/rules/zz-i94-cwd-offender\.md'
cwd_control "$want"
i94_hits="$(grep -E -- ' -> ' "$CW_DIR/s.out")"
if [ -z "$i94_hits" ]; then
  bad "I94 near-miss: the scratch-cwd run printed no copy-hit line at all, so the schema exclusion has nothing to be read against"
elif grep -q 'core/schemas/pause-routing\.json' <<<"$i94_hits"; then
  bad "I94 near-miss: the declaration itself was reported as a copy from a scratch cwd -- the compare against the schema path no longer matches what the scan emits"
else
  ok "I94 near-miss: the declaration carries every value and is not reported, beside the seeded copy that is"
fi
cwd_finish
}

A42_i95_cwd_invariance() {
CW_ID=I95
printf 'X="${STATE_DIR}/.zz-i95-cwd-undeclared"\n' > "$ROOT/core/hooks/zz-i95-cwd-offender.sh"
want='I95: \.zz-i95-cwd-undeclared is constructed at core/hooks/zz-i95-cwd-offender\.sh:1'
cwd_control "$want"
cwd_battery "$want" M1
cwd_finish
}

# I81 has no copy scan, so its offender is the invariant's own violating shape: the two hooks'
# live-series blocks made to differ, in the seed only.
A43_i81_cwd_invariance() {
CW_ID=I81
i81_h="$ROOT/core/hooks/ai-dlc-acknowledge.sh"
i81_bak="$(mkbak "$i81_h")"
awk '{ print } />>> I81 LIVE-SERIES BLOCK >>>/ { print "  : i81-cwd-seed" }' "$i81_bak" > "$i81_h"
rm -f "$i81_bak"
if [ "$(grep -c 'i81-cwd-seed' "$i81_h")" != 1 ]; then
  bad "FIXTURE BROKEN: the I81 seed did not land exactly once inside acknowledge.sh's live-series block"
  return
fi
want='i81-cwd-seed'
cwd_control "$want"
if grep -q 'derive the live adversarial series DIFFERENTLY' "$CW_DIR/s.out"; then
  ok "I81: the seeded divergence is reported as the two hooks disagreeing, not by another I81 message that happens to echo the block"
else
  bad "I81: the scratch-cwd run did not report the seeded block as a divergence between the two hooks"
fi
cwd_battery "$want" M2 M3 M4
cwd_finish
}


# ---------------------------------------------------------------------------
# THE DRIVER
# ---------------------------------------------------------------------------
# THE ASSERTION LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order. A
# hand-written list here would be this fixture's own subject defect one level out: an
# assertion dropped from the list runs nothing and prints nothing, and a suite reporting 28
# greens instead of 29 reads exactly like a suite that passed. The zero guard is the same
# argument -- a naming grammar that stops matching yields an empty list, and an empty list
# passes every assertion it never made.
#
# THE OPTIONAL LETTER IS LOAD-BEARING. The sibling enforcement-map-derivations carried the
# same `^A[0-9]{2}_` grammar and two lettered arms (A27b, A27c) that were defined, cited by a
# backlog receipt as a guard, and dispatched by no shard. `vrun` already derives the arm id
# from a lettered frame; only this enumerator could not spell one.
NAMES="$(grep -oE '^A[0-9]{2}[a-z]?_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
if [ "$N_LISTED" -lt 10 ]; then
  echo "FIXTURE ERROR: derived $N_LISTED assertion(s) from this file — the A<nn>_ naming grammar moved" >&2
  exit 2
fi

# EVERY DEFINED ASSERTION IS A DISPATCHED ASSERTION, AND THE TWO SIDES USE DIFFERENT GRAMMARS
# ON PURPOSE. A count taken with the enumerator's own regex agrees with the enumerator by
# construction, so it could never fire. This side is deliberately LOOSE: any function whose
# name starts `A<digit>`, with or without `function`, indentation or spacing before `()`. A
# definition the strict enumerator cannot spell is counted here and missed there, and the run
# refuses rather than shipping an arm that runs nowhere.
#
# False-positive set measured before shipping: EMPTY. On the tree that added this guard both
# grammars read 40, and no helper in this file starts with `A<digit>`. The shard partition
# below then deals N_LISTED - 1 non-control assertions, so defined == listed == dealt + 1.
N_DEFINED="$(grep -cE '^[[:space:]]*(function[[:space:]]+)?A[0-9][A-Za-z0-9_]*[[:space:]]*\(\)' "$0" || true)"
if [ "$N_DEFINED" -ne "$N_LISTED" ]; then
  echo "FIXTURE BROKEN: this file DEFINES $N_DEFINED assertion function(s) but the enumerator lists $N_LISTED." >&2
  echo "  The difference is defined, reads as coverage, and is dispatched by no shard. Rename it to A<nn>[a-z]_i<id>_<what> or widen the enumerator." >&2
  exit 2
fi

# SEED.SH RUNS ONCE PER SHARD, AND THIS FILE HAS EXACTLY ONE CALL SITE FOR IT. The driver's.
# `seed_tree` copies the template; a second call site -- a `restore` or `seed_tree` reverted to
# `bash "$HERE/seed.sh"` -- produces the same trees and the same verdicts, so nothing behavioural
# can see it, and every cell would go back to re-copying the live distribution under the tracer.
# Counted the N_DEFINED way: a loose grammar (any `seed.sh` invocation, any quoting) against the
# one expected site, so a site spelled differently is counted rather than missed.
N_SEED_SITES="$(grep -cE '^[^#]*bash[[:space:]]+"?\$\{?HERE\}?/seed\.sh' "$0" || true)"
if [ "$N_SEED_SITES" -ne 1 ]; then
  echo "FIXTURE BROKEN: this file invokes seed.sh at $N_SEED_SITES site(s); exactly 1 (the shard driver's template build) is expected." >&2
  echo "  Every other tree is a copy of that template. A second call site re-seeds from the live distribution per tree, which is the cost this file was changed to remove." >&2
  exit 2
fi

# `--run-one <assertion>` is one assertion, in one process, against one freshly seeded
# tree. It is the unit the pool schedules and it is also how a human runs a single
# assertion while working on it.
#
# IT RUNS ONLY WHAT THE SHARDS WOULD. A name that is a defined function but not in $NAMES is
# refused, so a hand-run of an undispatched arm fails instead of printing `ok` for a guard the
# suite never executes.
if [ "${1:-}" = "--run-one" ]; then
  FN="${2:-}"
  declare -F "$FN" >/dev/null 2>&1 || {
    echo "FIXTURE ERROR: --run-one needs an assertion function name; '$FN' is not one" >&2
    exit 2
  }
  case "
$NAMES
" in
    *"
$FN
"*) ;;
    *) echo "FIXTURE ERROR: '$FN' is defined but is not in the dispatched assertion list, so no shard runs it; a hand-run here would certify a guard the suite never executes" >&2
       exit 2 ;;
  esac
  # THE LEDGER AND THE BROKEN MARKER ARRIVE AS ARGUMENTS, NEVER AS ENVIRONMENT, for the same
  # reason --group does: this file scrubs every ambient AI_DLC_* name above, so an environment
  # variable would be unset before the line that read it, the ledger would be silently empty,
  # and the selection control at the foot would report a conversion that never happened.
  VRUN_LOG="${3:-}"
  # THE TEMPLATE IS THE THIRD ARGUMENT AFTER THE NAME, and it is also the A40-A43 decoy root.
  # Same predicate `seed.sh` applies to the distribution: a directory carrying the validator.
  EMS_TEMPLATE="${4:-}"
  if [ -z "$EMS_TEMPLATE" ] || [ ! -d "$EMS_TEMPLATE" ] || [ ! -f "$EMS_TEMPLATE/scripts/validate-enforcement-map.sh" ]; then
    echo "FIXTURE ERROR: --run-one needs a seeded template as its 4th argument (EMS_TEMPLATE, after <assertion> and <vrun-ledger>); got '$EMS_TEMPLATE', which is unset, empty, not a directory, or carries no scripts/validate-enforcement-map.sh." >&2
    echo "  Build one by hand with: T=\"\$(bash core/fixtures/enforcement-map-sites/seed.sh)\"; D=\"\$(mktemp -d)\"; cp -RX \"\$T/.\" \"\$D/\"; cp VERSION \"\$D/\"; git init -q \"\$D\"; bash core/fixtures/enforcement-map-sites/run.sh --run-one $FN \"\" \"\$T\" \"\$D\"" >&2
    echo "  There is no fallback to seed.sh or to the live root on purpose." >&2
    exit 2
  fi
  # THE DECOY IS THE 5TH ARGUMENT: the template plus VERSION and a .git (see EMS_DECOY above).
  EMS_DECOY="${5:-}"
  if [ -z "$EMS_DECOY" ] || [ ! -d "$EMS_DECOY" ] || [ ! -f "$EMS_DECOY/scripts/validate-enforcement-map.sh" ] \
     || [ ! -f "$EMS_DECOY/VERSION" ] || [ ! -d "$EMS_DECOY/.git" ]; then
    echo "FIXTURE ERROR: --run-one needs a decoy root as its 5th argument (EMS_DECOY: the template plus VERSION and a .git); got '$EMS_DECOY', which is unset, empty, not a directory, or lacks scripts/validate-enforcement-map.sh, VERSION or .git." >&2
    echo "  The shard driver builds one; by hand, see the template message's recipe. There is no fallback to the live root on purpose." >&2
    exit 2
  fi
  # SLOTS 6-8: the file holding this shard's A00 exit status (every kill is gated on it reading 0;
  # empty, missing or nonzero and every kill prints FIXTURE BROKEN), the mode (plain or matrix),
  # and the matrix ledger. All arguments, for the scrub's reason.
  CTL_RC="$( [ -n "${6:-}" ] && [ -f "$6" ] && printf '%s' "$(< "$6")" )"
  case "${7:-plain}" in
    plain) MX_MODE="" ;;
    matrix) MX_MODE=matrix ;;
    *) echo "FIXTURE ERROR: --run-one slot 7 is '${7:-}', which is neither plain nor matrix" >&2; exit 2 ;;
  esac
  MX_LEDGER="${8:-}"
  if [ -z "$MX_LEDGER" ]; then
    echo "FIXTURE ERROR: --run-one needs the matrix ledger as its 8th argument, so a matrix-only cell has somewhere to record that it ran" >&2
    exit 2
  fi
  MX_DIR="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp -d failed for the matrix dir" >&2; exit 2; }
  VRUN_BROKEN="$(mktemp)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  seed_tree
  trap 'rm -rf "$ROOT"; rm -f "$VRUN_BROKEN" "$MX_DIR/full.out" "$MX_DIR/full.rc"; rmdir "$MX_DIR" 2>/dev/null' EXIT
  "$FN"
  # A SELECTION FAILURE IS NOT A FINDING. vrun cannot exit the process from inside a command
  # substitution, so it records here instead; 2 is the code the driver routes to FIXTURE
  # BROKEN, which is the answer "nothing was tested" rather than "the check regressed".
  if [ -s "$VRUN_BROKEN" ]; then
    cat "$VRUN_BROKEN" >&2
    exit 2
  fi
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

# ---------------------------------------------------------------------------
# THE SHARD SPLIT, AND IT IS A MEASUREMENT RATHER THAN A PREFERENCE
# ---------------------------------------------------------------------------
# This file's assertions were the pre-push suite's ENTIRE wall clock, and an inner pool did
# not fix it. The suite is POLE-BOUND: its makespan tracks its single longest unit, and the
# unit here is a DIRECTORY, because `core/fixtures/*/run.sh` is what the outer pool
# schedules. Measured across five outer pool sizes on one idle 18-core box, with this
# fixture's own 8-way inner pool already in place:
#
#     AI_DLC_FIXTURE_JOBS   16     12     10      8      4
#     suite makespan       256s   256s   248s   246s   (>240s)
#     this fixture         253s   ~250s  248s   246s
#
# The makespan EQUALS this unit at every setting, because it starts at t=0 and is still
# running when everything else has finished. No outer pool size reaches it, and no inner
# pool size does either: the inner pool is already 8-way and the unit still costs 130s with
# the machine entirely to itself.
#
# So the fixture is SHARDED ACROSS DIRECTORIES, which is the same move and the same reason
# as a mutation battery being split out of `trunk-audit-classes`. Each shard is a
# directory the outer pool can start independently and interleave with everything else.
#
# ROUND-ROBIN, NOT CONTIGUOUS THIRDS. These assertions differ by an order of magnitude in
# cost — several seed a tree and run one validator, a few run it three times over rebuilt
# trees — so a contiguous cut puts the expensive neighbours in one shard and rebuilds the
# pole inside it. Dealing them out in turn spreads that without anyone having to maintain a
# cost table that would go stale the first time an assertion changed.
#
# EVERY SHARD RUNS THE CONTROL. A00 is the arm that says the validator is not simply broken,
# and a shard without it would report its own assertions as kills earned against a tree
# nobody checked. It costs one validator run per shard and it is not optional.
#
# THREE SHARDS STAY AFTER THE CWD BATTERY AND THE BETWEEN-ARM RE-SEEDS WERE CUT, AND THE NUMBERS
# ARE WHY. Counted statically from this file: shard a went from 78 validator runs to 61, b from 51
# to 34 and c from 56 to 44, and the 42 whole-template re-seeds went to 0. Under the 8-way inner
# pool a shard's wall clock is bounded by its longest CELL, and A40 (I91, now 15 runs) is still
# shard a's. One directory would hold 139 runs over 46 cells, about 17 runs per pool slot, which
# is longer than A40. So a collapse would not shorten the pole. It would save two A00 full runs,
# two seeds and two decoys, and it would change the subject set that
# scripts/readset-stage1-{run,verdict}.sh and the readset-stage1-verdict fixture score across
# recorded runs. That is a measurement harness's population, and changing it is not a fixture
# edit.
SHARDS="a b c"

# THE SHARD ARRIVES AS AN ARGUMENT, NOT AS AN ENVIRONMENT VARIABLE, and that is not a style
# choice. This file scrubs every ambient AI_DLC_* name near the top for I10 — a fixture must
# not inherit a tunable that changes what it measures — and the scrub is deliberately ordered
# ahead of everything. An `AI_DLC_EMS_GROUP` would therefore be unset before this line ever
# read it, every shard would silently fall back to 'a', and the suite would run shard 'a'
# three times while reporting three green fixtures. Arguments survive the scrub.
GROUP=a
RUN_MODE=plain
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
elif [ "${1:-}" = "--matrix" ]; then
  # THE MATRIX DEALS EVERY ASSERTION, whatever the shard: the REMEASURE command must score every
  # mutant, and a shard-a-only matrix would miss two thirds of them. It runs as shard a.
  RUN_MODE=matrix
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac

# THE COVERAGE JOIN. Sharding moves assertions out of this directory, so the failure mode it
# introduces is a shard whose directory is deleted, renamed, or never installed: the suite
# then runs fewer assertions and reports a shorter green run, which is this repository's
# named recurring defect wearing a new hat. Shard `a` therefore DERIVES the set of shards
# that actually exist beside it and refuses to pass if any declared shard has no driver.
# The control is the same grep finding this file's own sibling directories at all.
if [ "$GROUP" = a ]; then
  missing=""
  for _s in $SHARDS; do
    [ "$_s" = a ] && continue
    [ -f "$HERE/../enforcement-map-sites-$_s/run.sh" ] || missing="$missing $_s"
  done
  if [ -n "$missing" ]; then
    echo "FIXTURE ERROR: shard(s)$missing declared in SHARDS have no driver directory beside this one." >&2
    echo "  Their assertions would run NOWHERE, and this suite would report a shorter green run." >&2
    exit 2
  fi
fi

NAME="enforcement-map-sites"
[ "$GROUP" = a ] || NAME="enforcement-map-sites-$GROUP"

# THE INNER POOL WIDTH, resolved BEFORE the control so a bad value refuses in milliseconds.
# Default 8 (the reasoning is beside the pool below). The read-set deriver runs every shard with
# EMS_POOL_WIDTH=1: at 8 the concurrent seed copies push the sandbox tracer's `log stream` into
# dropping reports, and a window carrying a drop notice is OMITTED from the map. The width changes
# the SCHEDULE, not the work -- every assertion in the shard is still dispatched and every seed
# still copied -- so a read-set traced at width 1 is the read-set at width 8.
# NO AI_DLC_ PREFIX, AND HERE THAT IS LOAD-BEARING: the scrub near the top of this file unsets
# every ambient AI_DLC_* name, so a prefixed knob would be gone before this line read it and a
# traced run would silently stay at 8 (the same reason --group is an argument, above).
# A value that is not an integer from 1 to 64 is FIXTURE BROKEN (exit 2), never a regression:
# `xargs -P 0` means UNLIMITED on BSD, and a non-number makes xargs refuse, which the verdict
# loop below would charge as dropped work -- a false finding about the subject. The length is
# bounded before any numeric test, because a 20-digit value overflows `test` into FALSE.
# No empty-string case: `${EMS_POOL_WIDTH:-8}` turns an empty or unset knob into 8, so JOBS is
# never empty here.
JOBS="${EMS_POOL_WIDTH:-8}"
case "$JOBS" in
  *[!0-9]*) echo "FIXTURE BROKEN: EMS_POOL_WIDTH='$JOBS' is not an integer from 1 to 64" >&2; exit 2 ;;
esac
if [ "${#JOBS}" -gt 3 ] || [ "$JOBS" -lt 1 ] || [ "$JOBS" -gt 64 ]; then
  echo "FIXTURE BROKEN: EMS_POOL_WIDTH='$JOBS' is not an integer from 1 to 64" >&2; exit 2
fi
SELF_W="$HERE/$(basename "$0")"
# The cheap re-entry mode the width arm below drives: the resolved width, and nothing else.
if [ "${1:-}" = "--print-width" ]; then
  printf '%s\n' "$JOBS"; exit 0
fi

echo "$NAME:"

# --- THE WIDTH KNOB: unset is 8, 1 reaches the pool, a bad value is FIXTURE BROKEN ----------
# Shard a only, so the knob is asserted once rather than three times. Driven through
# `--print-width`, which prints the very variable the pool reads. Each cell is presence-shaped:
# a resolver that ignored the knob fails the `1` cell, one that ignored the default fails the
# unset cell, one that accepted anything fails the refusal cells. `env -u` keeps the unset cell
# true when this fixture itself runs under the read-set deriver, where the knob IS set.
if [ "$GROUP" = a ]; then
  w_unset="$(env -u EMS_POOL_WIDTH bash "$SELF_W" --print-width 2>/dev/null)"; w_unset_rc=$?
  w_one="$(EMS_POOL_WIDTH=1 bash "$SELF_W" --print-width 2>/dev/null)"; w_one_rc=$?
  EMS_POOL_WIDTH=0 bash "$SELF_W" --print-width >/dev/null 2>&1; w_zero_rc=$?
  EMS_POOL_WIDTH=abc bash "$SELF_W" --print-width >/dev/null 2>&1; w_abc_rc=$?
  EMS_POOL_WIDTH=99999999999999999999 bash "$SELF_W" --print-width >/dev/null 2>&1; w_big_rc=$?
  EMS_POOL_WIDTH=65 bash "$SELF_W" --print-width >/dev/null 2>&1; w_65_rc=$?
  w_64="$(EMS_POOL_WIDTH=64 bash "$SELF_W" --print-width 2>/dev/null)"; w_64_rc=$?
  if [ "$w_unset_rc:$w_unset" = "0:8" ]; then
    ok "WIDTH: with EMS_POOL_WIDTH unset the inner pool width resolves to 8"
  else
    bad "WIDTH: with EMS_POOL_WIDTH unset --print-width gave rc $w_unset_rc and '$w_unset' (expected 0 and 8) — the pre-push default moved"
  fi
  if [ "$w_one_rc:$w_one" = "0:1" ]; then
    ok "WIDTH: EMS_POOL_WIDTH=1 resolves the inner pool width to 1, so the deriver's knob reaches the pool"
  else
    bad "WIDTH: EMS_POOL_WIDTH=1 gave rc $w_one_rc and '$w_one' (expected 0 and 1) — the deriver's knob does not reach the pool"
  fi
  if [ "$w_zero_rc" -eq 2 ] && [ "$w_abc_rc" -eq 2 ]; then
    ok "WIDTH: EMS_POOL_WIDTH=0 and =abc both exit 2 (FIXTURE BROKEN), never a regression"
  else
    bad "WIDTH: a bad width was not refused at exit 2: '0' exited $w_zero_rc, 'abc' exited $w_abc_rc"
  fi
  if [ "$w_big_rc" -eq 2 ] && [ "$w_65_rc" -eq 2 ] && [ "$w_64_rc:$w_64" = "0:64" ]; then
    ok "WIDTH: a 20-digit width and 65 both exit 2 (FIXTURE BROKEN), and 64 still resolves to 64"
  else
    bad "WIDTH: the width ceiling is wrong: 20 digits exited $w_big_rc and 65 exited $w_65_rc (expected 2 and 2); 64 gave rc $w_64_rc and '$w_64' (expected 0 and 64)"
  fi
fi

OUT="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
TPL=""
DCY=""
trap 'rm -rf "$OUT"; [ -n "$TPL" ] && rm -rf "$TPL"; [ -n "$DCY" ] && rm -rf "$DCY"' EXIT
SELF="$HERE/$(basename "$0")"

# THE SHARD'S ONE SEED AND ONE DECOY, built ABOVE the control so the control runs on the same
# trees as every cell after it. Every `--run-one` copies the template; A40-A43 run their C2, C4
# and full-mode cells from the decoy (the template plus the distribution's VERSION and a
# `git init`). Two checks before anything reads them, and the second is repeated after the pool:
#   presence  -- the validator, preclassify, and templates/ (I22 joins against
#                templates/settings.json.template; seed.sh copies it for that reason), and for
#                the decoy also VERSION and .git;
#   integrity -- a file count and an md5 over the sorted (path, md5) list of every file in each,
#                derived with `find` (never `git ls-files`, which cannot see an untracked file).
#                Re-taken after the pool: a cell that wrote into a shared tree -- rather than its
#                own copy -- changes it, and every cell after that write ran against a tree
#                nobody seeded. tree_state RECORDS the directory it actually hashed, and that is
#                compared against the very paths handed to the cells, so a digest taken over some
#                other directory refuses instead of comparing two equal readings of the wrong tree.
TPL="$(bash "$HERE/seed.sh")" || { echo "$NAME: FIXTURE ERROR — seed.sh failed to build the shard template" >&2; exit 2; }
DCY="$(mktemp -d "${TMPDIR:-/tmp}/enforcement-map-sites-decoy.XXXXXX")" || { echo "$NAME: FIXTURE ERROR — mktemp failed for the decoy" >&2; exit 2; }
cp -RX "$TPL/." "$DCY/" && cp "$HERE/../../../VERSION" "$DCY/VERSION" \
  && ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY; git init -q "$DCY" ) >/dev/null 2>&1 \
  || { echo "$NAME: FIXTURE ERROR — could not build the decoy root $DCY (copy of the template, the distribution's VERSION, git init)" >&2; exit 2; }
for _p in scripts/validate-enforcement-map.sh core/skills/ai-dlc-update/reconcile/preclassify.sh templates/settings.json.template; do
  [ -f "$TPL/$_p" ] || { echo "$NAME: FIXTURE ERROR — the seed template $TPL carries no $_p" >&2; exit 2; }
  [ -f "$DCY/$_p" ] || { echo "$NAME: FIXTURE ERROR — the decoy root $DCY carries no $_p" >&2; exit 2; }
done
[ -f "$DCY/VERSION" ] && [ -d "$DCY/.git" ] || { echo "$NAME: FIXTURE ERROR — the decoy root $DCY lacks VERSION or .git" >&2; exit 2; }
[ ! -e "$TPL/VERSION" ] || { echo "$NAME: FIXTURE ERROR — the seed template $TPL carries VERSION; seeded trees must not (the validator's I45 guard)" >&2; exit 2; }
# tree_state <dir> -> "<physical dir it hashed> <file count> <digest>"
tree_state() {
  (cd "$1" && printf '%s %s %s\n' "$(pwd -P)" "$(find . -type f | grep -c .)" \
     "$(find . -type f -print0 | LC_ALL=C sort -z | xargs -0 md5 -r | md5 -q)")
}
# The paths every cell is handed, fixed once here and used by the control, the pool AND the checks.
CELL_TPL="$TPL"
CELL_DCY="$DCY"
TPL_S0="$(tree_state "$CELL_TPL")"
DCY_S0="$(tree_state "$CELL_DCY")"
for _s in "$TPL_S0" "$DCY_S0"; do
  set -- $_s
  if [ "$#" -ne 3 ] || [ "${2:-0}" -lt 100 ]; then
    echo "$NAME: FIXTURE ERROR — a shared seed tree reads '$_s'; a partial tree is a decoy that discriminates nothing" >&2
    exit 2
  fi
done
set --

# The control, first and alone. Its verdict licenses every assertion after it, so a failure
# here stops the run rather than reporting 28 unattributable kills.
CTL="$(printf '%s\n' "$NAMES" | head -1)"
# The matrix ledger: every MATRIX-ONLY cell appends a line here. A plain run must leave its
# matrix-only lines at zero, while its plain-twins lines (written by the per-push twin check, the
# same call site) must be non-zero -- the control that the ledger writes at all.
MXL="$OUT/mx.ledger"; : > "$MXL"
bash "$SELF" --run-one "$CTL" "$OUT/$CTL.vrun" "$CELL_TPL" "$CELL_DCY" "" "$RUN_MODE" "$MXL" > "$OUT/$CTL" 2>"$OUT/$CTL.err"
ctl_rc=$?
printf '%s\n' "$ctl_rc" > "$OUT/ctl.rc" || { echo "$NAME: FIXTURE ERROR — could not record the control's exit status" >&2; exit 2; }
cat "$OUT/$CTL"
if [ "$ctl_rc" -ne 0 ]; then
  [ -s "$OUT/$CTL.err" ] && cat "$OUT/$CTL.err" >&2
  echo
  echo "$NAME: 1 assertion(s) FAILED" >&2
  exit 2
fi

# EIGHT BY DEFAULT, and the pre-push suite never sets EMS_POOL_WIDTH: this pool nests inside
# the suite's own pool, so the product is what lands on the machine. Eight against 18 cores
# leaves headroom for the seven sibling fixtures the suite runs beside this one. The knob
# exists only so the read-set deriver can narrow the schedule; JOBS is resolved above.
# Deal the non-control assertions out to the shards in turn. The partition is DERIVED from
# the same list the control came off, so an assertion added to this file lands in a shard
# automatically rather than needing a table updated in a second place.
printf '%s\n' "$NAMES" | tail -n +2 \
  | awk -v g="$GROUP" -v shards="$SHARDS" -v all="$RUN_MODE" '
      BEGIN { n = split(shards, S, " ") }
      { if (all == "matrix" || S[((NR - 1) % n) + 1] == g) print }
    ' > "$OUT/list"
N_MINE="$(grep -c . "$OUT/list" || true)"
if [ "$N_MINE" -eq 0 ]; then
  echo "$NAME: FIXTURE ERROR — shard '$GROUP' was dealt no assertions out of $N_LISTED; an empty shard passes every assertion it never made" >&2
  exit 2
fi
# The template, decoy, base-pass verdict, mode and ledger reach each worker as positional
# arguments ($2-$6), never environment names. Every cell receives the path of the control's
# recorded exit status, and every kill is gated on that status reading 0 in its own process.
AI_DLC_EMS_SELF="$SELF" AI_DLC_EMS_OUT="$OUT" \
  xargs -P "$JOBS" -I{} bash -c '
    n="$1"
    bash "$AI_DLC_EMS_SELF" --run-one "$n" "$AI_DLC_EMS_OUT/$n.vrun" "$2" "$3" "$4" "$5" "$6" \
      > "$AI_DLC_EMS_OUT/$n" 2> "$AI_DLC_EMS_OUT/$n.err"
    printf %s $? > "$AI_DLC_EMS_OUT/$n.rc"
  ' _ {} "$CELL_TPL" "$CELL_DCY" "$OUT/ctl.rc" "$RUN_MODE" "$MXL" < "$OUT/list"

TPL_S1="$(tree_state "$CELL_TPL")"
DCY_S1="$(tree_state "$CELL_DCY")"
for _pair in "template|$CELL_TPL|$TPL_S0|$TPL_S1" "decoy|$CELL_DCY|$DCY_S0|$DCY_S1"; do
  _what="${_pair%%|*}"; _r="${_pair#*|}"; _dir="${_r%%|*}"; _r="${_r#*|}"; _s0="${_r%%|*}"; _s1="${_r#*|}"
  _phys="$(cd "$_dir" && pwd -P)"
  if [ "${_s0%% *}" != "$_phys" ] || [ "${_s1%% *}" != "$_phys" ]; then
    echo "$NAME: FIXTURE BROKEN — the $_what integrity check hashed '${_s0%% *}' / '${_s1%% *}', not the directory handed to the cells ($_phys), so it compared readings of a tree no cell used." >&2
    exit 2
  fi
  if [ "$_s0" != "$_s1" ]; then
    echo "$NAME: FIXTURE BROKEN — the shared $_what changed during the pool ('$_s0' before, '$_s1' after). A cell wrote into it instead of its own copy, so the cells after that write ran against a tree nobody seeded." >&2
    exit 2
  fi
done

# Rendered in SOURCE order, never completion order, so the output is byte-comparable
# against the serial version and diffable across runs.
#
# A MISSING VERDICT IS A FAILURE, not a gap. Serially, an assertion that never ran could
# not print an `ok` -- the loop and the report were the same thing. With a pool they are
# not, and a dropped job is silent. So the verdict file's absence is asserted, and a worker
# that exited nonzero without printing a FAIL line (a crash, a failed seed) is charged one
# rather than counted as clean.
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ ! -f "$OUT/$n.rc" ]; then
    printf '  FAIL  %s produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one\n' "$n"
    fails=$((fails + 1))
    continue
  fi
  cat "$OUT/$n"
  [ -s "$OUT/$n.err" ] && cat "$OUT/$n.err" >&2
  wrc="$(cat "$OUT/$n.rc")"
  # 2 IS NOT 1. `FIXTURE BROKEN` (a failed seed, an unbuildable mutant) and `an assertion
  # regressed` are different answers, and this file has always used exit 2 for the first.
  # Routing an assertion through a worker would otherwise collapse them: the parent sees a
  # nonzero rc, charges one assertion and exits 1 — reporting a regression where the truth is
  # that nothing was tested.
  if [ "$wrc" = "2" ]; then broken=1; fi
  if [ "$wrc" != "0" ]; then
    c="$(grep -c '^  FAIL' "$OUT/$n" || true)"
    [ "$c" -gt 0 ] || { printf '  FAIL  %s exited nonzero without an assertion line — the assertion did not run to a verdict\n' "$n"; c=1; }
    fails=$((fails + c))
  fi
done < "$OUT/list"

# THE SELECTION CONTROL: A CONVERSION THAT STOPS SELECTING MUST BE RED, NOT MERELY SLOW.
# Each assertion runs the validator through `vrun`, which records the id it selected into a
# per-assertion ledger. A `vrun` call reverted to a full `bash "$V"` still passes its own
# predicate -- a full run contains everything a selected run would have printed -- so nothing
# in the assertions themselves can notice, and the only symptom would be the wall clock going
# back to where it was. That is exactly the shape of a mechanism that quietly stopped running.
#
# BOTH SIDES ARE DERIVED, and neither is a list. The expectation is this shard's own dealt
# assertion list; the observation is which of those wrote a ledger. The complement is derived
# too: the control assertion -- the one deliberately left on a FULL run, because "the pristine
# tree passes" is an absence-shaped claim over EVERY arm -- must have recorded nothing, so a
# control that quietly started selecting fails here as well. An empty dealt list is already a
# FIXTURE ERROR above, which is what stops this join being satisfied by having no subjects.
sel_got=0
sel_bad=""
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ -s "$OUT/$n.vrun" ]; then sel_got=$((sel_got + 1)); else sel_bad="$sel_bad $n"; fi
done < "$OUT/list"
if [ -s "$OUT/$CTL.vrun" ]; then sel_bad="$sel_bad $CTL(selected an arm; it must stay a full run)"; fi
if [ "$sel_got" -ne "$N_MINE" ] || [ -n "$sel_bad" ]; then
  printf '  FAIL  arm selection did not happen as dealt: %d of %d assertion(s) in shard %s recorded an --arms run (offenders:%s). Every assertion but the control selects the one arm it tests; one that stopped is running every arm and asserting nothing more for it\n' "$sel_got" "$N_MINE" "$GROUP" "$sel_bad"
  fails=$((fails + 1))
fi

# RULE 9: A PLAIN RUN EXECUTES NO MATRIX-ONLY CELL. Every matrix-only cell (the full run vrun
# takes, mx_score, cwd_mx) appends to the ledger before it does anything else. The CONTROL is
# the plain-twins lines the per-push twin check writes to the SAME ledger: they must be present,
# so an empty matrix count cannot come from a ledger nothing writes.
mx_only="$(grep -cE '^(mx-full|mx-score) ' "$MXL")" || mx_only=0
mx_ctl="$(grep -c '^plain-twins ' "$MXL")" || mx_ctl=0
if [ "$RUN_MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then
    printf '  FAIL  the matrix ledger control is EMPTY: no per-push twin check wrote to it, so a zero count of matrix-only cells below would mean nothing\n'
    fails=$((fails + 1))
  elif [ "$mx_only" -ne 0 ]; then
    printf '  FAIL  a plain run executed %d matrix-only cell(s) (%s) -- the --matrix measurement leaked into the per-push run\n' "$mx_only" "$(grep -E '^(mx-full|mx-score) ' "$MXL" | head -3 | tr '\n' ' ')"
    fails=$((fails + 1))
  else
    ok "a plain run executed no matrix-only cell, while its $mx_ctl per-push twin check(s) wrote to the same ledger"
  fi
else
  # THE HEADER IS BOUND TO THE MEASURED SET, BOTH WAYS: every MUTANT-MATRIX row must have printed
  # exactly one MATRIX line, and every MATRIX line must have a row. A hand-written header that
  # drifted from the mutants it describes is the second list this file forbids.
  mx_hdr="$(awk '$1 == "#" && $2 == "MUTANT-MATRIX" { print $3 }' "$SELF" | LC_ALL=C sort)"
  mx_got="$(while IFS= read -r n; do [ -n "$n" ] && cat "$OUT/$n" 2>/dev/null; done < "$OUT/list" | awk '$1 == "MATRIX" && $2 != "BROKEN" { print $2 }' | LC_ALL=C sort)"
  mx_dup="$(printf '%s\n' "$mx_got" | uniq -d | tr '\n' ' ')"
  mx_nohdr="$(LC_ALL=C comm -13 <(printf '%s\n' "$mx_hdr" | uniq) <(printf '%s\n' "$mx_got" | uniq) | tr '\n' ' ')"
  mx_norun="$(LC_ALL=C comm -23 <(printf '%s\n' "$mx_hdr" | uniq) <(printf '%s\n' "$mx_got" | uniq) | tr '\n' ' ')"
  if [ -n "${mx_dup// /}${mx_nohdr// /}${mx_norun// /}" ]; then
    printf '  FAIL  the MUTANT-MATRIX header and the measured set disagree: printed with no row: [%s]; row never measured: [%s]; measured twice: [%s]\n' "$mx_nohdr" "$mx_norun" "$mx_dup"
    fails=$((fails + 1))
  fi
  printf 'MATRIX-SUMMARY %d matrix-only cell(s) ran, %d header row(s), %d MATRIX line(s)\n' "$mx_only" "$(printf '%s\n' "$mx_hdr" | grep -c .)" "$(printf '%s\n' "$mx_got" | grep -c .)"
fi

echo
if [ "$broken" -ne 0 ]; then
  echo "$NAME: FIXTURE BROKEN — an assertion could not run to a verdict" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
