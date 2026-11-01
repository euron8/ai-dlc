#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Hermetic against ambient AI_DLC_* tunables (enforcement-map I10). The BL-292 arms write hook
# registrations and drive `--finish` through the real validator, so an operator's exported
# tunable would otherwise be tested instead of the code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# apply-restamp-worklist — a run that HANDS WORK BACK must not stamp the tree as being at THEIRS,
# and must not clear the in-flight marker.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the behaviour regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# apply.sh's re-stamp is gated on ONE counter. `mech_fail` is incremented at fourteen sites and
# by `declared_bad`, and every one of them means the same thing: THIS PROGRAM did not know how to
# place a file the pull classified. That is a bug in apply.sh, and the guard is right to withhold
# the stamp for it.
#
# No `say WORKLIST` site increments it, and neither do the `say DECISION` sites that hand the
# operator a genuine call — a `deletion`, an unknown drift refile-vs-revert. So a run that ends
# with outstanding semantic merges on the operator's desk still wrote
# `version: <theirs>` into `.claude/.ai-dlc-version` and still removed
# `.claude/.ai-dlc-applying`. Measured on the synthetic pull below, against the pre-fix script:
# a consumer with a BOTH-CHANGED->CLASSIFY file got `WORKLIST semantic-merge`, `RESOLVED restamp`
# and `RESOLVED consistent` in one manifest.
#
# WHY THAT IS WORSE THAN A COSMETIC FIELD, TWICE OVER.
#
#   - The stamp is what the NEXT pull reads to compute its base. A stamp saying THEIRS over a
#     tree where a merge was never performed silently mis-bases the following merge, and the
#     damage surfaces a pull later, far from the run that caused it. This is the same failure
#     `apply-restamp-theirs` guards from the other direction (a version taken from the wrong ref).
#   - `RESOLVED consistent ... fixture suite re-enabled` is a claim, and clearing the marker
#     ACTS on it. `core/git-hooks/pre-push` refuses the fixture suite while that marker exists,
#     so removing it re-enables a suite over a tree whose merges are still outstanding — the one
#     state the marker was introduced to keep unjudged.
#
# THE FIX AND ITS OWN HAZARD. A `handback` counter incremented inside `say()` for every WORKLIST
# and DECISION row, read by the same guard, withholds both the stamp and the marker. That leaves
# the consumer WEDGED unless the operator is handed a way to finish: with the marker present
# pre-push refuses every push, and the run that would clear it is the one that just refused to.
# `apply.sh --finish <dist> <base> <consumer> <theirs>` is that escape — stamp and marker only,
# no resolution phases — and C6 asserts the withheld row NAMES it. A withheld stamp whose row
# does not reach the escape is not a safer program, it is a stuck one.
#
# AND THE ESCAPE HAS TO TERMINATE, WHICH IS WHY THERE ARE TWO COUNTERS. `--finish` re-derives the
# hook-registration row before it stamps, and on a consumer with no
# `scripts/ai-dlc/validate-hook-registration.sh` that row is `DECISION hook-registration-unchecked`
# — whose own stated remedy is to re-run the apply, which is the phase `--finish` skips. Gate the
# finisher on `handback` and it withholds forever over a row it can never clear. So the ordinary
# run gates on WORKLIST *and* DECISION rows, and `--finish` gates on `worklist_n` alone: a row
# naming concrete work, which clears when the work is done. C4 and C8 are two seeds that separate
# those two counters, and m8 is the mutant that collapses them.
#
# AND THE ESCAPE'S ARGUMENT IS CHECKED FOR IDENTITY, NOT MERELY FOR RESOLVABILITY. `--finish` is
# retyped by hand from a row that prints <dist> and <consumer> as placeholders, and its only guard
# on <theirs> asked whether the ref resolves. A ref naming the WRONG thing resolves, so the stamp
# took its sha, `RESOLVED consistent` printed over a tree never brought there, and the marker was
# removed. `.ai-dlc-applying` already recorded `theirs:` and every reader in the tree was an
# existence test. F1/F2/F3 are that join, keyed on the `core/` tree so a docs-only move of the ref
# still finishes, and m9/m10/m11 are the three ways to break it.
#
# HOW IT DRIVES THE REAL SCRIPT. Nothing inside apply.sh is stubbed. Two throwaway git repos and
# a consumer tree per arm produce the three input shapes out of preclassify's own vocabulary:
#
#   green      every core file at base, none locally edited  -> pure applies only, no hand-back
#   worklist   one core file edited on both sides            -> BOTH-CHANGED->CLASSIFY
#                                                            -> WORKLIST semantic-merge
#   decision   a core file deleted upstream, consumer's copy  -> UPSTREAM-DELETED
#              untouched                                     -> DECISION deletion
#
# The `decision` shape is its own arm rather than a variation of `worklist` because the two are
# separately losable: a counter that watches `say WORKLIST` alone leaves every operator DECISION
# stamping exactly as before, and the two rows are emitted from different phases.
#
# CWD. Everything resolves from `$0` and from absolute mktemp paths, and the suite runner
# dispatches `bash "$d/run.sh"` from the repo root. Arm CWD re-runs the decisive assertion from
# `/` rather than asserting that by inspection.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# TWO LAYOUTS. install.sh splits what shares a parent here: `core/skills/<x>` lands under
# `.claude/skills/<x>` on a consumer, `core/git-hooks/pre-push` under `.githooks/pre-push`.
# Both roots sit the same three levels above this file, so the discriminator is which of the
# two paths carries apply.sh, never a walk of a different depth.
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh"
else
  echo "apply-restamp-worklist: FIXTURE BROKEN — reconcile/apply.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/skills/... (distribution), $ROOT/.claude/skills/... (consumer)" >&2
  exit 2
fi
REC="$(dirname "$APPLY")"
echo "HERMETIC-CONSUMED $APPLY"

# The marker's READER, resolved in both layouts. C6 exists because pre-push refuses on the
# marker; if that refusal ever goes away, C6's whole premise goes with it and the arm should be
# re-examined rather than left quietly passing on a hazard that no longer exists.
PREPUSH=""
for cand in "$ROOT/core/git-hooks/pre-push" "$ROOT/.githooks/pre-push"; do
  [ -f "$cand" ] && PREPUSH="$cand" && break
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-restamp-worklist.XXXXXX")" || {
  echo "apply-restamp-worklist: FIXTURE BROKEN — mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0; asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# ---------------------------------------------------------------------------- shards ----
# THIS FILE IS THREE SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT
# BOUNDARY (the readset-skip shape). Every section below is a UNIT guarded by `if sg <unit>; then ... fi`;
# `--group <x>` runs the units dealt to shard <x>. `apply-restamp-worklist-{b,c}/run.sh` are one-line
# drivers that `exec bash` this file with their group, so the pre-push pool starts each on its own. No
# `--group` runs shard 'a'.
#
# THE SEED AND THE SUBJECT PROBE ARE NOT UNITS: every shard builds the synthetic pull, the three runs and
# the S0-S3 sanity arms, and runs the subject probe, because a shard that skipped them would score its
# units against a harness that never ran. The mutant helpers (mk_report, u5_*, build_rec, mut_apply) and
# the hook-registration validator lookup are hoisted above the units for the same reason: units use
# each other's helpers, and a helper living inside a unit another shard owns would be undefined there.
#
# THE COVERAGE JOIN runs in EVERY shard before anything else: the declared units are DERIVED from this
# file's own `if sg <unit>; then` lines, the dealt lists must be disjoint and their union must equal the
# declared set exactly, and every declared shard must have a driver directory. The join proves it can
# fire first, on a seeded duplicate and a seeded omission.
#   a  cf u mut   C1-C8 / F1-F3 / CWD, U1-U5, RA0-RA9 and the mutants of the restamp guard, --finish and the
#                 union gate that gate on those arms' B_ flags (a flag and the mutant it gates share a shard)
#   b  ar arm     AR first-verified region and M1-M10 of it, which gate on the AR arms' B_ flags
#   c  bl t hr hu vf  BL-276 routing rows; T1-T4 transient-ignore row; BL-292 hook-registration row; BL-103
#                 unshipped-hook row; VF finish-verifies-tree
SHARDS="a b c"
UNITS_a="cf u mut"
UNITS_b="ar arm"
UNITS_c="bl t hr hu vf"
GROUP=a
# `--matrix` is the RE-MEASUREMENT mode: every unit of every shard, each mutant battery scored across
# every world of its battery. Never per push. A unit carrying a full-vector mode adds itself to
# MATRIX_UNITS; every other unit prints that it has none, so a partial matrix cannot read as complete.
# The matrix is measured once and re-measured whenever an arm or a mutant is added or changed, and per push each mutant runs its deciding arm(s).
#   also trips (consequence, not decided): m1 C6,C7; m2 F1; m5 C6,C7; m6 C5,C8,F1,F2,F3; m7 F1; m11 C4,C5,C8; A1 RA2;
#   A2 RA1,RA2,RA3; MR1 U5,RA3; M1 R2,A,F1,F2A,F2,G1,G2,I3,J1,KF2,N1,N2E,N3; M2 A,F1,F2A,F2,I3;
#   M3 F1,F2A,F2,G1,G2,I3,N1,N2E,N3; M5 F2; M6 F2A,F2,G2,I1,I3,N3; M7b F1,F2;
# MUTANT-MATRIX-REMEASURE bash core/fixtures/apply-restamp-worklist/run.sh --matrix
# MUTANT-MATRIX BL-m1 decides=BL-1 twins=BL-3
# MUTANT-MATRIX BL-m2 decides=BL-1 twins=BL-3
# MUTANT-MATRIX BL-m3 decides=BL-2 twins=BL-1
# MUTANT-MATRIX BL-m4 decides=BL-5,BL-1 twins=BL-3
# MUTANT-MATRIX BL-m5 decides=BL-2 twins=BL-1
# MUTANT-MATRIX BL-m6 decides=BL-4 twins=BL-1
# MUTANT-MATRIX HR-M-a decides=a,b,c,e,g twins=d
# MUTANT-MATRIX HR-M-c decides=c twins=g
# MUTANT-MATRIX HR-M-d decides=d twins=a
# MUTANT-MATRIX HR-M-b decides=b twins=a
# MUTANT-MATRIX HR-M-g decides=g twins=c
# MUTANT-MATRIX HU-M1 decides=a twins=t
# MUTANT-MATRIX HU-M2 decides=t twins=a
# MUTANT-MATRIX HU-M3 decides=t twins=a
# MUTANT-MATRIX HU-M4 decides=a twins=t
# MUTANT-MATRIX HU-M5 decides=a twins=t
# MUTANT-MATRIX m1 decides=C1 twins=C3
# MUTANT-MATRIX m2 decides=C1 twins=C3
# MUTANT-MATRIX m3 decides=C7 twins=C1
# MUTANT-MATRIX m4 decides=C6 twins=C1
# MUTANT-MATRIX m5 decides=C1 twins=C3
# MUTANT-MATRIX m6 decides=C4 twins=C3
# MUTANT-MATRIX m7 decides=C5 twins=C4
# MUTANT-MATRIX m8 decides=C8 twins=C4
# MUTANT-MATRIX m9 decides=F1 twins=F2
# MUTANT-MATRIX m10 decides=F2 twins=F1
# MUTANT-MATRIX m11 decides=F3 twins=F2
# MUTANT-MATRIX m12 decides=U2 twins=C3
# MUTANT-MATRIX A1 decides=U5 twins=C3
# MUTANT-MATRIX A2 decides=U5 twins=U1
# MUTANT-MATRIX A3 decides=U5 twins=RA1
# MUTANT-MATRIX MR1 decides=RA1 twins=RA2
# MUTANT-MATRIX MR2 decides=RA3 twins=RA2
# MUTANT-MATRIX VF-m-cmp decides=r4 twins=r1
# MUTANT-MATRIX VF-m-distonly decides=r3,r4,do2 twins=r1
# MUTANT-MATRIX VF-m-noadd decides=r2 twins=r1
# MUTANT-MATRIX VF-m-first decides=r1,r2,ro twins=r3
# MUTANT-MATRIX VF-m-order decides=r6 twins=r1
# MUTANT-MATRIX VF-m-base decides=r5,r5b twins=r1
# MUTANT-MATRIX VF-m-wt decides=do1,do2,do3 twins=r1
# MUTANT-MATRIX M1 decides=R1 twins=I1
# MUTANT-MATRIX M2 decides=R2 twins=R1
# MUTANT-MATRIX M3 decides=A twins=R2
# MUTANT-MATRIX M4 decides=M-bad twins=M-absent
# MUTANT-MATRIX M5 decides=F1 twins=A
# MUTANT-MATRIX M6 decides=G1 twins=KF2
# MUTANT-MATRIX M7a decides=I2 twins=I1
# MUTANT-MATRIX M7b decides=I3 twins=I2
# MUTANT-MATRIX M8 decides=J1 twins=R1
# MUTANT-MATRIX M9 decides=KF2 twins=KA3
# MUTANT-MATRIX M10 decides=N1,N2E twins=N3
# MUTANT-MATRIX-CONTROL BL-CTL why=knock-out control: an unmutated copy of the reconcile directory must reproduce both verdicts, so a BL mutant's red cell is the mutation and not the copy
# MUTANT-MATRIX-CONTROL HR-CTL why=knock-out control: the cmp -s identical copy must hold all seven cells and emit the UNREGISTERED settings-merge row, so a mutant's cells are the mutation and not the copy
# MUTANT-MATRIX-CONTROL HU-CTL why=knock-out control: the cmp -s identical copy must score a, t, the quiet X world and the registered R world, so a mutant's cells are the mutation and not the copy
# MUTANT-MATRIX-CONTROL CONTROL why=knock-out control: the unmutated mut-ctl copy reproduces both verdicts and is the flag source for m1-m8 and A1-A3
# MUTANT-MATRIX-CONTROL CONTROL-id why=knock-out control: the unmutated copy refuses the offender and passes the docs-only near-miss, the flag source for m9-m11
# MUTANT-MATRIX-CONTROL CONTROL-m12 why=knock-out control: the unmutated copy refuses a stale region, the flag source for m12
# MUTANT-MATRIX-CONTROL CONTROL-MR why=knock-out control: the unmutated copy refuses RA1's world, the flag source for MR1 and MR2
# MUTANT-MATRIX-CONTROL VF-CTL why=knock-out control: the staged copy is byte-identical to the shipped directory and holds VF-R1, so a vf mutant's cells are the mutation and not the copy
# MUTANT-MATRIX-CONTROL CONTROL-AR why=knock-out control: the unmutated copy exits 0 and writes the record, the flag source for M1-M10
# MUTANT-MATRIX-DYNAMIC hr_mscore why=every call passes a literal id and each id has its own MUTANT-MATRIX row
# MUTANT-MATRIX-DYNAMIC hu_try why=every call passes a literal id and each id has its own MUTANT-MATRIX row
# MUTANT-MATRIX-DYNAMIC vf_score why=every call passes a literal id and each id has its own MUTANT-MATRIX row
# MUTANT-MATRIX-DYNAMIC ar_score why=every call passes a literal id and each id has its own MUTANT-MATRIX row
MATRIX=0; MATRIX_UNITS="bl hr hu mut vf ar arm"
MX_CELLS=0   # matrix-only blocks entered; the MATRIX-PLAIN arm at the foot reads it
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; shift; fi
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
  [ "${3:-}" = "--matrix" ] && MATRIX=1
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
if [ "$MATRIX" = 1 ] && [ "${1:-}" != "--group" ]; then MINE="$UNITS_a $UNITS_b $UNITS_c"; fi
if [ "$MATRIX" = 1 ]; then
  MX_CELLS=$((MX_CELLS + 1))
  for _u in $MINE; do
    case " $MATRIX_UNITS " in *" $_u "*) ;; *) echo "MATRIX-NONE unit $_u has no full-vector mode yet; its cells are NOT in this matrix" ;; esac
  done
fi
NAME="apply-restamp-worklist"; [ "$GROUP" = a ] || NAME="apply-restamp-worklist-$GROUP"
shard_broken() { echo "$NAME: FIXTURE BROKEN — $1" >&2; exit 2; }
[ -n "$MINE" ] || shard_broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
SELF="$0"
[ -f "$SELF" ] || shard_broken "cannot read $SELF for the coverage join"
partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/apply-restamp-join.XXXXXX")" || shard_broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$JW/pdup"; printf '%s\n' u1 u3 > "$JW/pmiss"; printf '%s\n' u3 u1 u2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  rm -rf "$JW"; shard_broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
sed -n 's/^[[:space:]]*if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$SELF" > "$JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  rm -rf "$JW"; shard_broken "$ndecl unit guards derived from $SELF ($ndupdecl declared twice)"
fi
if ! _why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  rm -rf "$JW"; shard_broken "the shard partition does not cover the guarded units exactly -- $_why"
fi
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$HERE/../apply-restamp-worklist-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    rm -rf "$JW"; shard_broken "shard '$_s' is declared but $_drv does not drive it"
  fi
done
rm -rf "$JW"
echo "  [J0] coverage join: $ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"

# THE RESOLVED PATH IS PRINTED, not inferred from the layout. Two candidates exist and the first
# that resolves wins, so a mutant edited into the other copy leaves every arm green and reads
# exactly like an arm that cannot fire. This line is what makes that visible in a suite log.
echo "$NAME: driving $APPLY"

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. On a consumer this file can arrive on the pull that
# also carries the apply.sh it tests, and the fixture batch is written last, so an interrupted
# pull can leave this here beside an older driver. "Subject not installed" is not "subject
# regressed", and reporting it as a failure is what deadlocks a self-update. In the DISTRIBUTION
# the subject is always present, so an absent one is a hard error and upstream cannot go green
# vacuously.
IS_DIST=0; [ -d "$ROOT/core/skills/ai-dlc" ] && IS_DIST=1

# --- the synthetic pull ---------------------------------------------------------------------
DIST="$WORK/dist"
mkdir -p "$DIST/core/session-driver" "$DIST/core/scripts" \
         "$DIST/core/fixtures/synthetic-fx" "$DIST/core/fixtures/doomed-fx" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "apply-restamp-worklist: FIXTURE BROKEN — git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

# BASE at 1.0.0.
printf '1.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v1\n'  > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
printf '#!/usr/bin/env bash\n# both v1\n'    > "$DIST/core/session-driver/ai-dlc-both-changed.sh"
# A real distribution ALWAYS ships core validators, and the manifest claims them as
# `core/scripts/ai-dlc/*` — one entry apply.sh expands against THEIRS' tree. A synthetic DIST
# shipping none makes that expansion empty, which apply.sh reports as manifest-unreadable and
# withholds the re-stamp for. Every assertion below would then pass for the wrong reason.
printf '#!/usr/bin/env bash\necho v\n'       > "$DIST/core/scripts/validate-synthetic.sh"
printf '#!/usr/bin/env bash\n# fx v1\n'      > "$DIST/core/fixtures/synthetic-fx/run.sh"
printf '#!/usr/bin/env bash\n# doomed v1\n'  > "$DIST/core/fixtures/doomed-fx/run.sh"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# THEIRS at 2.0.0 — the version a stamp is entitled to claim, and only when it is earned.
printf '2.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
printf '#!/usr/bin/env bash\n# both v2 UPSTREAM\n'   > "$DIST/core/session-driver/ai-dlc-both-changed.sh"
printf '#!/usr/bin/env bash\n# fx v2 UPSTREAM\n'     > "$DIST/core/fixtures/synthetic-fx/run.sh"
rm -rf "$DIST/core/fixtures/doomed-fx"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
THEIRS_SHORT="$(git -C "$DIST" rev-parse --short HEAD)"
THEIRS_VER="$(git -C "$DIST" show "${THEIRS}:VERSION")"

# TWO MORE REFS, FOR THE `--finish` IDENTITY ARMS F1/F2/F3. Both are committed BEFORE the working
# tree is dirtied below, so `gitc add -A` here cannot capture the 9.9.9 S0 depends on.
#
# DOCS IS THE NEAR-MISS, and it is the reason this guard is keyed on the `core/` TREE rather than
# on the commit: a different commit whose `core/` tree is byte-identical to THEIRS'. A
# distribution ships docs between releases, so a finisher naming the newer of two equivalent refs
# is the ordinary case, and a commit-keyed guard refuses it — wedging a consumer whose only sin is
# a fresher ref. VERSION is deliberately NOT bumped here, which is what a docs-only commit does.
mkdir -p "$DIST/docs" || exit 2
printf 'a docs-only commit between releases\n' > "$DIST/docs/note.md"
gitc add -A && gitc commit -q -m docs-only
DOCS="$(git -C "$DIST" rev-parse HEAD)"
DOCS_SHORT="$(git -C "$DIST" rev-parse --short HEAD)"

# OTHER IS THE OFFENDER: `core/` genuinely moved, so a tree finished to this ref is content the
# consumer does not carry. VERSION moves with it, so a wrongly advanced stamp is visible in the
# FILE and not only in a row — which is what F1 asserts, because a row count is true either way.
printf '3.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v3 OTHER\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
gitc add -A && gitc commit -q -m other
OTHER="$(git -C "$DIST" rev-parse HEAD)"
OTHER_VER="$(git -C "$DIST" show "${OTHER}:VERSION")"

# The operator's checkout is on something else entirely. Live condition, and the reason
# `apply-restamp-theirs` exists: the working tree says 9.9.9 while the pull brings 2.0.0.
printf '9.9.9\n' > "$DIST/VERSION"

DRIVER_REL=".claude/session-driver/ai-dlc-session-driver.sh"

# seed_map <core-path> -> the consumer-relative path a finished apply writes it to. Written out
# here rather than evaluated from preclassify.sh, so the seed is not derived from the reader's own
# grammar; S4 and RS1 check the seeded bytes against the tree the ORDINARY apply actually writes.
seed_map() {
  case "$1" in
    core/scripts/*)  echo "scripts/ai-dlc/${1#core/scripts/}" ;;
    core/fixtures/*) echo "tests/fixtures/${1#core/fixtures/}" ;;
    core/*)          echo ".claude/${1#core/}" ;;
  esac
}
# seed_ref <dist> <base> <ref> <consumer>
#
# A FINISHED TREE, which is the state `--finish` exists for: the operator has applied <ref>'s
# content by hand, so every core path base..ref changes holds <ref>'s bytes, a deleted one is gone,
# and a fixture `.dist-only` AT <ref> is not written at all. `--finish` verifies exactly this before
# it stamps, so a world handed to it without this seed is an UNAPPLIED tree and is correctly
# withheld -- which is what every `--finish` world here was until the verified finish landed.
seed_ref() {
  local d="$1" b="$2" r="$3" c="$4" rows st p f cp
  rows="$(git -C "$d" diff --name-status --no-renames "$b" "$r" -- core/ 2>/dev/null)" || return 1
  [ -n "$rows" ] || return 1
  while IFS="$(printf '\t')" read -r st p; do
    [ -n "${p:-}" ] || continue
    case "$p" in
      core/fixtures/*)
        f="${p#core/fixtures/}"; f="${f%%/*}"
        git -C "$d" cat-file -e "${r}:core/fixtures/${f}/.dist-only" 2>/dev/null && continue ;;
    esac
    cp="$(seed_map "$p")"
    case "$st" in
      D) rm -f "$c/$cp" ;;
      *) mkdir -p "$(dirname "$c/$cp")" && git -C "$d" show "${r}:${p}" > "$c/$cp" || return 1 ;;
    esac
  done <<< "$rows"
  return 0
}
# same_on_range <dist> <base> <ref> <seeded> <applied> -> 0 when every consumer path the range
# maps to holds the same bytes in both trees (or is absent from both), and at least one is present.
same_on_range() {
  local rows p cp present=0
  rows="$(git -C "$1" diff --name-only --no-renames "$2" "$3" -- core/ 2>/dev/null)"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    cp="$(seed_map "$p")"
    if [ -f "$4/$cp" ] || [ -f "$5/$cp" ]; then
      cmp -s "$4/$cp" "$5/$cp" || return 1
      present=$((present+1))
    fi
  done <<< "$rows"
  [ "$present" -gt 0 ]
}

# mk_consumer <dir> <green|worklist|decision|finished|merged> [hrv]
#
# `finished` is `green` with THEIRS applied by seed_ref. `merged` is `finished` with the session
# driver replaced by a hand merge that differs from BOTH base and theirs -- the file an operator
# resolved a semantic merge into, which preclassify buckets CLASSIFY and `--finish` must not count.
# Its text deliberately carries no `UPSTREAM`, so an overwrite from theirs is visible in it.
#
# `hrv` installs a stub `scripts/ai-dlc/validate-hook-registration.sh` that exits 0. That is the
# ONE thing separating C4's tree from C8's: without it apply.sh's hook-registration site emits
# `DECISION hook-registration-unchecked` on every run, and under `--finish` that row is emitted
# BEFORE the stamp. A finisher gating on `handback` therefore withholds on it, and the row's own
# remedy is the phase `--finish` skips. C4 runs without that row, C8 runs with it.
mk_consumer() {
  local c="$1" mode="$2"
  mkdir -p "$c/.claude/session-driver" "$c/tests/fixtures/synthetic-fx" "$c/scripts/ai-dlc" || return 1
  if [ "${3:-}" = hrv ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$c/scripts/ai-dlc/validate-hook-registration.sh"
    chmod +x "$c/scripts/ai-dlc/validate-hook-registration.sh"
  else
    rm -f "$c/scripts/ai-dlc/validate-hook-registration.sh"
  fi
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$c/$DRIVER_REL"
  printf '#!/usr/bin/env bash\n# fx v1\n'     > "$c/tests/fixtures/synthetic-fx/run.sh"
  printf '#!/usr/bin/env bash\necho v\n'      > "$c/scripts/ai-dlc/validate-synthetic.sh"
  case "$mode" in
    worklist) printf '#!/usr/bin/env bash\n# both v1 CONSUMER EDIT\n' > "$c/.claude/session-driver/ai-dlc-both-changed.sh" ;;
    *)        printf '#!/usr/bin/env bash\n# both v1\n'               > "$c/.claude/session-driver/ai-dlc-both-changed.sh" ;;
  esac
  if [ "$mode" = decision ]; then
    mkdir -p "$c/tests/fixtures/doomed-fx" || return 1
    printf '#!/usr/bin/env bash\n# doomed v1\n' > "$c/tests/fixtures/doomed-fx/run.sh"
  fi
  case "$mode" in
    finished|merged) seed_ref "$DIST" "$BASE" "$THEIRS" "$c" || return 1 ;;
  esac
  [ "$mode" = merged ] && printf '#!/usr/bin/env bash\n# driver v1 and v2 hand-merged by the operator\n' > "$c/$DRIVER_REL"
  printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$c/.claude/.ai-dlc-version"
  rm -f "$c/.claude/.ai-dlc-applying"
}

run_apply() { # run_apply <apply-path> <consumer> [flag...]
  local a="$1" c="$2"; shift 2
  bash "$a" "$@" "$DIST" "$BASE" "$c" "$THEIRS" 2>/dev/null
}

# run_finish_as <apply-path> <consumer> <argv-theirs>
#
# `run_apply` always passes THEIRS, which is precisely the argument F1/F2/F3 must vary: the
# defect is that the ref the operator RETYPES was never checked against the ref the tree was
# written from, and those two are the same value in every arm above.
run_finish_as() { bash "$1" --finish "$DIST" "$BASE" "$2" "$3" 2>/dev/null; }

stamp_ver()  { sed -n 's/^version:[[:space:]]*//p' "$1/.claude/.ai-dlc-version" 2>/dev/null | head -1; }
stamp_sha()  { sed -n 's/^commit:[[:space:]]*//p'  "$1/.claude/.ai-dlc-version" 2>/dev/null | head -1; }
marker()     { [ -f "$1/.claude/.ai-dlc-applying" ] && echo PRESENT || echo GONE; }
# HERE-STRINGS, NOT PIPES, wherever the reader stops at its first match. Under `pipefail` a
# reader that leaves early makes the pipeline answer with the WRITER's EPIPE, so the test reports
# "not found" on input that contains the pattern. It is a size threshold rather than a race:
# correct until the output after the match fills the pipe buffer, then wrong permanently and with
# no symptom. I54b in `validate-enforcement-map.sh` caught this file with four of them.
has_row()    { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {n++} END {exit !(n>0)}' <<< "$1"; }
detail_of()  { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b && NF>=4 {print $4; exit}' <<< "$1"; }

# ROWS EMITTED BEFORE THE GUARD IS READ. `handback` is a running counter, so what gates the
# stamp is the rows printed UP TO the re-stamp verdict, not the whole manifest. That distinction
# is load-bearing: apply.sh emits `DECISION hook-registration-unchecked` on any consumer lacking
# scripts/ai-dlc/validate-hook-registration.sh, and on an ordinary run it emits it AFTER the
# re-stamp — measured on every tree below that omits the validator, the clean one included. A
# counter read at exit instead of at the guard would withhold the stamp on EVERY correct pull and
# wedge every consumer. S1 is what separates the two readings.
pre_guard() {
  awk -F'\t' '
    $1=="RESOLVED" && ($2=="restamp" || $2=="restamp-machinery") { exit }
    $1=="DECISION" && $2 ~ /^(restamp-withheld|restamp-failed|skill-restamp-withheld|skill-restamp-failed)$/ { exit }
    { print }' <<< "$1"
}
n_handback() { awk -F'\t' '$1=="WORKLIST" || $1=="DECISION" {n++} END {print n+0}' <<< "$(pre_guard "$1")"; }

EMIT="$REC/emit-report.sh"
mk_report() { # mk_report <consumer> <theirs-to-render-at>
  mkdir -p "$1/_bmad-output/ai-dlc-update" || return 1
  { printf '# reconcile report (fixture)\n\n'
    bash "$EMIT" "$DIST" "$BASE" "$1" "$2" 2>/dev/null
  } > "$1/_bmad-output/ai-dlc-update/reconcile-report.md"
}


u5_seed_blocker() {
  mkdir -p "$1/.claude/skills/ai-dlc/overrides" || return 1
  cat > "$1/.claude/skills/ai-dlc/overrides/probe.md" <<'U5OVR'
---
shadows: core/rules/nonexistent.md#Nope
base_sha: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
reason: probe
---

## Nope

probe body
U5OVR
}
# u5_seed_unseen <consumer> — a NON-HARD finding the approval never saw. The override's base_sha
# RESOLVES (so it is not the HARD row probe.md is) and its `shadows:` target is absent at theirs,
# which layer-drift.sh renders as OVERRIDE-ANCHOR-UNRESOLVED: the shape reconcile-emit-report's V-U
# world uses, and the one --verify counts as `unseen=1`.
u5_seed_unseen() {
  mkdir -p "$1/.claude/skills/ai-dlc/overrides" || return 1
  cat > "$1/.claude/skills/ai-dlc/overrides/absent-anchor.md" <<U5UNS
---
shadows: core/rules/nonexistent.md#Nope
base_sha: $BASE
reason: probe
---

## Nope

probe body
U5UNS
}
u5_build() { # u5_build <consumer> [unseen] — approve WITH the blocker, then resolve it
  mk_consumer "$1" green || return 1
  u5_seed_blocker "$1" || return 1
  mk_report "$1" "$THEIRS" || return 1
  rm -rf "$1/.claude/skills/ai-dlc/overrides"
  [ "${2:-}" = unseen ] || return 0
  u5_seed_unseen "$1"
}
run_apply_err() { bash "$1" "$DIST" "$BASE" "$2" "$THEIRS" 2>"$3"; }
# u5_score <apply-path> -> "<rc>|<stamp>|<marker>|<CAUSE|->|<REMEDY|->|<FWD|->"
# PRESENCE-SHAPED IN EVERY FIELD, and a fresh consumer per drive so no arm reads a previous
# one's leftovers.
#
# THE WORLD CARRIES ONE UNSEEN ROW. A resolution that leaves NO unseen row now PROCEEDS (RA0
# below), so the refusal this scorer reads is the unseen>0 one with no recorded re-approval.
# REMEDY is keyed on `RE-APPROVAL OWED`, which only the exit-3 branch prints, plus the re-run.
#
# FWD IS THE FORWARDED STDERR, and it is keyed on the two things only the forward produces: a
# `cause:` LINE at --verify's own indent, and at least one `<`/`>` diff line. The refusal message
# itself interpolates the cause TEXT, so a `BLOCKERS-RESOLVED` conjunct is satisfied whether or
# not the forward happened; and the message ends by telling the operator to read a diff, which
# without the forward apply.sh has discarded — a pointer to a tool they must re-run.
u5_score() {
  local a="$1" c="$WORK/u5-$$-$RANDOM" e rc
  u5_build "$c" unseen || { echo "BROKEN|||||"; return; }
  e="$c/stderr.txt"
  run_apply_err "$a" "$c" "$e" >/dev/null; rc=$?
  printf '%s|%s|%s|%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" "$(marker "$c")" \
    "$(grep -q 'BLOCKERS-RESOLVED' "$e" && echo CAUSE || echo -)" \
    "$(grep -qF 'apply: RE-APPROVAL OWED.' "$e" \
       && grep -q 're-run apply with the same four arguments' "$e" && echo REMEDY || echo -)" \
    "$(grep -qE '^[[:space:]]*cause: ' "$e" && grep -qE '^[<>] ' "$e" && echo FWD || echo -)"
}

# --- THE RECORDED RE-APPROVAL (RA0-RA5, MR1-MR2) -------------------------------------------------
# --verify exit 3 prints `re-approval: digest=<sha256> unseen=<N> label="..."`, and apply.sh decides
# from it: unseen=0 proceeds; unseen>0 proceeds only on an AskUserQuestion record in
# _bmad-output/operator-answers-history.md whose Question line carries the full digest and whose
# answer body's first line begins with the label. The step this replaces told the session to
# re-render, verify to 0 and "have the operator re-approve it"; nothing read the re-approval, and
# the re-render erased the only evidence a reader could have used. Measured on the reference
# consumer, twice: re-rendered, verified 0, applied, no question between.
#
# RECORDS ARE WRITTEN BY DRIVING THE REAL HOOK with a synthetic PostToolUse payload, never by
# hand, so the record grammar the gate reads is the one the hook writes. `ra_answer` asserts the
# record LANDED (the AskUserQuestion header count rose): the hook exits 0 silently without jq,
# and a proceed arm would then go red for the wrong reason. RA5 is the one derived record: no hook
# writes a non-AskUserQuestion header into that file, so a hook-written correct record has its
# header token replaced exactly once — every other property kept, the near-miss for that conjunct.
ANSWER_HOOK=""
for cand in "$ROOT/core/hooks/ai-dlc-answer-capture.sh" "$ROOT/.claude/hooks/ai-dlc-answer-capture.sh"; do
  [ -f "$cand" ] && ANSWER_HOOK="$cand" && break
done
# SHIPS AHEAD OF ITS SUBJECT, like the --finish probe below: on a consumer this file can sit beside
# an apply.sh that predates the gate. In the distribution the subject is always present, so the
# arms run and go red rather than skipping.
RA_SKIP=""
if [ "$IS_DIST" = 0 ] && { ! grep -q '^ra_recorded() {' "$APPLY" || [ -z "$ANSWER_HOOK" ]; }; then
  RA_SKIP="the installed apply.sh predates the recorded re-approval gate, or the answer-capture hook is not installed; both land with the pull that carries this fixture"
fi
ra_answer() { # ra_answer <consumer> <question> <answer> -> 0 when one more AskUserQuestion record landed
  local h="$1/_bmad-output/operator-answers-history.md" n0 n1
  n0="$(grep -c '^## .* -- AskUserQuestion$' "$h" 2>/dev/null)" || n0=0
  jq -n --arg q "$2" --arg a "$3" \
    '{tool_name:"AskUserQuestion",session_id:"fx-ra",tool_use_id:"fx-ra-tu",tool_response:{answers:{($q):$a}}}' \
    > "$1/ra-payload.json" || return 1
  CLAUDE_PROJECT_DIR="$1" bash "$ANSWER_HOOK" < "$1/ra-payload.json" >/dev/null 2>&1
  # stderr, not stdout: callers capture stdout; hermetic-run merges both into the log it greps.
  [ -f "$ANSWER_HOOK" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-answer-capture.sh" >&2
  n1="$(grep -c '^## .* -- AskUserQuestion$' "$h" 2>/dev/null)" || n1=0
  [ "$n1" -gt "$n0" ]
}
# ra_line <consumer> -> the `re-approval:` payload --verify prints for this consumer's report
ra_line() {
  local v
  v="$(bash "$EMIT" --verify "$1/_bmad-output/ai-dlc-update/reconcile-report.md" "$DIST" "$BASE" "$1" "$THEIRS" 2>&1 >/dev/null)"
  sed -n 's/^[[:space:]]*re-approval: //p' <<< "$v"
}
# exact-once python replace; refuses (non-zero) unless the old text occurs exactly once
py_replace_once() { # py_replace_once <file> <old> <new>
  python3 - "$1" "$2" "$3" <<'PYREP'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
n = s.count(old)
if n != 1:
    sys.stderr.write("anchor occurs %d time(s), want 1\n" % n)
    sys.exit(1)
open(p, "w").write(s.replace(old, new))
PYREP
}
# ra_world <consumer> <plain|unseen> <none|right|wrongdg|wronglabel|pause> -> 0 when built as asked
ra_world() {
  local c="$1" ra dg lb wrong
  u5_build "$c" "$2" || return 1
  [ "$3" = none ] && return 0
  ra="$(ra_line "$c")"
  dg="${ra#digest=}"; dg="${dg%% *}"; lb="${ra#* label=\"}"; lb="${lb%\"}"
  [ "${#dg}" -eq 64 ] && [ -n "$lb" ] || return 1
  wrong="$(printf 'a different region\n' | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
  case "$3" in
    right)      ra_answer "$c" "Re-approve the reconcile report? Region digest ${dg}." "$lb" ;;
    wrongdg)    ra_answer "$c" "Re-approve the reconcile report? Region digest ${wrong}." "$lb" ;;
    wronglabel) ra_answer "$c" "Re-approve the reconcile report? Region digest ${dg}." "Not yet, keep the report" ;;
    embedded)   ra_answer "$c" "Re-approve the reconcile report? Region digest ab${dg}cd." "$lb" ;;
    labelplus)  ra_answer "$c" "Re-approve the reconcile report? Region digest ${dg}." "$lb -- no wait" ;;
    pause)      ra_answer "$c" "Re-approve the reconcile report? Region digest ${dg}." "$lb" \
                  && py_replace_once "$c/_bmad-output/operator-answers-history.md" " -- AskUserQuestion
" " -- USER_PAUSE
" ;;
    *) return 1 ;;
  esac
}
# ra_score <apply-path> <consumer> -> "<rc>|<stamp>|<WRITTEN|UNWRITTEN>|<NOTE|->"
# WRITTEN is read off a target file's BYTES (the session driver theirs rewrites), not off a row.
ra_score() {
  local out rc
  out="$(bash "$1" "$DIST" "$BASE" "$2" "$THEIRS" 2>"$2/ra-stderr.txt")"; rc=$?
  printf '%s|%s|%s|%s\n' "$rc" "$(stamp_ver "$2")" \
    "$(grep -q 'UPSTREAM' "$2/$DRIVER_REL" && echo WRITTEN || echo UNWRITTEN)" \
    "$(has_row "$out" NOTE blockers-resolved && echo NOTE || echo -)"
}
RA_GO="0|$THEIRS_VER|WRITTEN|NOTE"
RA_STOP="1|1.0.0|UNWRITTEN|-"
# ra_drive <apply-path> <tag> <plain|unseen> <record-kind> -> the ra_score cell, or BROKEN
ra_drive() {
  local c="$WORK/ra-$2-$$-$RANDOM"
  ra_world "$c" "$3" "$4" || { echo "BROKEN"; return; }
  ra_score "$1" "$c"
  cp "$c/ra-stderr.txt" "$WORK/ra-$2.stderr" 2>/dev/null
}
# ra_shim <dir> <grep|sha> -> a PATH directory whose one tool FAILS where the arm needs it to.
#   grep  exits 2 when its pattern is unseen_rows()'s (the only caller passing `0 HARD blockers`),
#         and runs the real grep otherwise -- the count's filter fails, nothing else does.
#   sha   shasum and sha256sum both exit 1, so --verify can compute no digest.
RA_REAL_GREP="$(command -v grep)"
#   none  a PATH that is EXACTLY a symlink farm of every tool on the current PATH except shasum and
#         sha256sum (ar_notool below): no sha256 tool exists, which is UNAVAILABLE. The `sha` shim is
#         the other state: a tool that EXISTS and fails, which is FAILED-shasum and never UNAVAILABLE.
ra_shim() {
  mkdir -p "$1" || return 1
  case "$2" in
    grep) printf '#!/bin/bash\nfor a in "$@"; do case "$a" in *"0 HARD blockers"*) exit 2 ;; esac; done\nexec %s "$@"\n' "$RA_REAL_GREP" > "$1/grep" ;;
    sha)  printf '#!/bin/bash\nexit 1\n' > "$1/shasum"; printf '#!/bin/bash\nexit 1\n' > "$1/sha256sum" ;;
    none) ar_notool "$1"; return ;;
  esac
  chmod +x "$1"/*
}
# ar_notool <dir> -> 0 when <dir> is a PATH carrying every tool the current PATH resolves except
# shasum and sha256sum. `ln -s` without -f keeps the FIRST of two same-named tools, so the farm
# resolves names in the order PATH does. Proved here, not assumed: git and awk resolve in it and
# neither sha256 tool does.
ar_notool() {
  local d
  mkdir -p "$1" || return 1
  local IFS=:
  for d in $PATH; do
    [ -d "$d" ] && [ "$d" != "$1" ] && ln -s "$d"/* "$1"/ 2>/dev/null
  done
  rm -f "$1/shasum" "$1/sha256sum"
  PATH="$1" command -v git >/dev/null 2>&1 && PATH="$1" command -v awk >/dev/null 2>&1 \
    && ! PATH="$1" command -v shasum >/dev/null 2>&1 && ! PATH="$1" command -v sha256sum >/dev/null 2>&1
}
# ra_drive_shim <tag> <grep|sha|none> -> "<ra_score cell>|<the re-approval line under the shim>"
# `none` REPLACES PATH with the farm; the others PREPEND the shim, so the real tool stays behind it.
ra_drive_shim() {
  local c="$WORK/ra-$1-$$-$RANDOM" s="$WORK/ra-shim-$1" out rc l sp
  u5_build "$c" unseen || { echo "BROKEN"; return; }
  ra_shim "$s" "$2" || { echo "BROKEN"; return; }
  sp="$s:$PATH"; [ "$2" = none ] && sp="$s"
  l="$(PATH="$sp" bash "$EMIT" --verify "$c/_bmad-output/ai-dlc-update/reconcile-report.md" "$DIST" "$BASE" "$c" "$THEIRS" 2>&1 >/dev/null)"
  l="$(sed -n 's/^[[:space:]]*re-approval: //p' <<< "$l")"
  out="$(PATH="$sp" bash "$APPLY" "$DIST" "$BASE" "$c" "$THEIRS" 2>"$WORK/ra-$1.stderr")"; rc=$?
  printf '%s|%s|%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" \
    "$(grep -q 'UPSTREAM' "$c/$DRIVER_REL" && echo WRITTEN || echo UNWRITTEN)" \
    "$(has_row "$out" NOTE blockers-resolved && echo NOTE || echo -)" "$l"
}

# Each is a COPY of the whole reconcile directory — apply.sh `eval`s map_consumer() out of its
# sibling preclassify.sh and shells to retired-tokens.sh and unregistered-drift.sh, so a lone
# script copy dies before printing anything — guarded by `cmp -s` so an edit that matched nothing
# cannot pass as a mutation, and aimed at ONE arm.
build_rec() { # build_rec <dir>
  mkdir -p "$1" && cp "$REC"/* "$1"/ 2>/dev/null && [ -f "$1/apply.sh" ]
}
# Every mutant verdict is PRESENCE-shaped: a mutant that emits nothing must not score as a kill.
# mut <n> <label> <arm-it-must-kill> <transform-command...> reading apply.sh on stdin
mut_apply() { # mut_apply <dir> ; transform reads $REC/apply.sh from stdin, writes stdout
  build_rec "$1" || return 1
  cat > "$1/apply.sh"
  ! cmp -s "$REC/apply.sh" "$1/apply.sh"
}

# The hook-registration validator is located ONCE, here, because both unit hr and unit hu read
# HR_SKIP and the two units may be dealt to different shards.
HR_VAL_SRC=""
for cand in "$ROOT/core/scripts/validate-hook-registration.sh" "$ROOT/scripts/ai-dlc/validate-hook-registration.sh"; do
  [ -f "$cand" ] && HR_VAL_SRC="$cand" && break
done
HR_SKIP=""
if [ -z "$HR_VAL_SRC" ] || [ ! -f "$REC/settings-merge.sh" ]; then
  HR_SKIP="the hook-registration validator or reconcile/settings-merge.sh is not on this tree (validator='${HR_VAL_SRC:-<none>}')"
elif ! command -v python3 >/dev/null 2>&1; then
  HR_SKIP="python3 is not on PATH, so the real validator cannot run and every world would read as unparsed"
fi

# --- SUBJECT PROBE: is the change installed at all? -------------------------------------------
# The guard fix and `--finish` land together, so one probe covers both halves. `--finish` with no
# positionals reaches the option parser and nothing else, so this costs a fork and writes nothing.
PROBE="$(bash "$APPLY" --finish 2>&1)"
if grep -q -- 'unknown option: --finish' <<< "$PROBE"; then
  if [ "$IS_DIST" = 1 ]; then
    bad "the resolved apply.sh ($APPLY) rejects --finish, so the whole subject of this fixture is absent. HARD in the distribution: the subject must be present here."
    echo
    echo "apply-restamp-worklist: FAIL ($fails)"
    exit 1
  fi
  printf '  SKIP  %s\n' "the installed apply.sh predates --finish and the handback guard; both land with this same pull"
  echo
  echo "apply-restamp-worklist: PASS (subject not installed on this consumer yet)"
  exit 0
fi

# --- S0 SANITY: the three versions are separated ----------------------------------------------
# Without this C4's content assertion is vacuous: if the working tree and theirs agreed, a stamp
# written from either would read the same and the arm could not fail.
WT_VER="$(cat "$DIST/VERSION")"
if [ "$WT_VER" != "$THEIRS_VER" ] && [ "$THEIRS_VER" != "1.0.0" ]; then
  ok "S0 setup: base 1.0.0, theirs $THEIRS_VER, working tree $WT_VER — a stamp taken from the wrong source is distinguishable"
else
  bad "S0 setup: working tree ($WT_VER) and theirs ($THEIRS_VER) are not separated — C4 would pass vacuously"
  echo; echo "apply-restamp-worklist: FIXTURE BROKEN" >&2; exit 2
fi

# --- the three runs ---------------------------------------------------------------------------
# ONLY units cf and vf READ OUT_*/C_* (and S1/S2 below), so only the shards that run one of them build
# and run the three consumers. Every other shard skips three full applies it never reads.
SEED_RUNS=0; if sg cf || sg vf; then SEED_RUNS=1; fi
if [ "$SEED_RUNS" = 1 ]; then
C_GREEN="$WORK/cons-green"; C_WORK="$WORK/cons-worklist"; C_DEC="$WORK/cons-decision"
mk_consumer "$C_GREEN" green    || { echo "FIXTURE BROKEN — could not build the green consumer" >&2; exit 2; }
mk_consumer "$C_WORK"  worklist || { echo "FIXTURE BROKEN — could not build the worklist consumer" >&2; exit 2; }
mk_consumer "$C_DEC"   decision || { echo "FIXTURE BROKEN — could not build the decision consumer" >&2; exit 2; }

OUT_GREEN="$(run_apply "$APPLY" "$C_GREEN")"
OUT_WORK="$(run_apply "$APPLY" "$C_WORK")"
OUT_DEC="$(run_apply "$APPLY" "$C_DEC")"
fi

if [ "$SEED_RUNS" = 1 ]; then
# --- S1 SANITY: the three inputs really are three different shapes ----------------------------
# Three arms below read three trees, and if the seeds collapsed into one shape they would agree
# for that reason rather than because the guard discriminates. Assert the discriminating property
# directly — the pre-guard hand-back count — before reading any verdict off it.
G_N="$(n_handback "$OUT_GREEN")"; W_N="$(n_handback "$OUT_WORK")"; D_N="$(n_handback "$OUT_DEC")"
if [ "$G_N" -eq 0 ] && [ "$W_N" -ge 1 ] && [ "$D_N" -ge 1 ] \
   && has_row "$OUT_WORK" WORKLIST semantic-merge \
   && has_row "$OUT_DEC"  DECISION deletion; then
  ok "S1 setup: the three seeds emit $G_N / $W_N / $D_N hand-back rows before the guard (green / WORKLIST semantic-merge / DECISION deletion)"
else
  bad "S1 setup: the seeds did not produce the three distinct shapes (green=$G_N worklist=$W_N decision=$D_N). Every arm below would be reading the same input, so agreement between them would prove nothing"
  pre_guard "$OUT_WORK" | sed 's/^/        /' | head -6
  echo; echo "apply-restamp-worklist: FIXTURE BROKEN" >&2; exit 2
fi

# --- S2 SANITY: the normal run DOES overwrite C5's subject ------------------------------------
# C5 asserts `--finish` leaves the session driver at v1. That is only a claim about `--finish` if
# a full run would have moved it, so establish the other side here rather than assuming it.
if grep -q 'UPSTREAM' "$C_GREEN/$DRIVER_REL"; then
  ok "S2 setup: a full apply overwrote $DRIVER_REL from theirs — C5's subject is one --finish must NOT touch"
else
  bad "S2 setup: a full apply left $DRIVER_REL unchanged, so C5 cannot distinguish --finish from a normal run"
fi
fi

# --- S3 SANITY: the two candidate identity keys CLASSIFY THE SEEDS DIFFERENTLY ----------------
# F1 and F2 are only a test of the TREE key if a COMMIT key would answer differently on at least
# one of them, so compute both semantics here and refuse unless they disagree. Without this the
# whole F block goes quietly vacuous: if DOCS ever stopped being core-identical to THEIRS, F2
# would become a second copy of F1 and both would pass under a commit-keyed guard.
S3_T="$(git -C "$DIST" rev-parse "${THEIRS}:core" 2>/dev/null || true)"
S3_D="$(git -C "$DIST" rev-parse "${DOCS}:core"   2>/dev/null || true)"
S3_O="$(git -C "$DIST" rev-parse "${OTHER}:core"  2>/dev/null || true)"
if [ -n "$S3_T" ] && [ "$S3_D" = "$S3_T" ] && [ "$DOCS" != "$THEIRS" ] \
   && [ -n "$S3_O" ] && [ "$S3_O" != "$S3_T" ] && [ "$OTHER_VER" != "$THEIRS_VER" ]; then
  ok "S3 setup: DOCS is a different COMMIT carrying THEIRS' exact core/ tree, OTHER differs in core/ AND in VERSION — a tree key and a commit key give different answers on DOCS"
else
  bad "S3 setup: the identity seeds collapsed (theirs:core=$S3_T docs:core=$S3_D other:core=$S3_O, docs==theirs? $([ "$DOCS" = "$THEIRS" ] && echo yes || echo no)). F2 can no longer tell a tree-keyed guard from a commit-keyed one, and F1's refusal would be unobservable in the stamp"
  echo; echo "apply-restamp-worklist: FIXTURE BROKEN" >&2; exit 2
fi

if sg cf; then
# --- C1: a WORKLIST run leaves the stamp and the marker alone ---------------------------------
# THE FILE CONTENT, not a row count. A manifest that says `restamp-withheld` while the stamp on
# disk reads THEIRS is exactly the false claim this fixture exists for, and a row-count assertion
# cannot see it. Both halves are asserted because they fail independently: the guard can withhold
# the stamp and a stray `rm -f` outside the read-back still clears the marker.
W_VER="$(stamp_ver "$C_WORK")"; W_SHA="$(stamp_sha "$C_WORK")"; W_MK="$(marker "$C_WORK")"
if [ "$W_VER" = "1.0.0" ] && [ "$W_SHA" = "$BASE" ]; then
  ok "C1 a run carrying a WORKLIST row leaves .ai-dlc-version at base (version: 1.0.0)"; B_C1s=1
else
  bad "C1 the stamp advanced to 'version: ${W_VER:-<absent>} / commit: ${W_SHA:-<absent>}' over a tree with an outstanding semantic merge. It should read 1.0.0 @ $BASE. The next pull computes its base from this file, so it will merge from a ref this tree never reached"
fi
if [ "$W_MK" = PRESENT ]; then
  ok "C1 and .ai-dlc-applying survives — the fixture suite stays blocked on a tree whose merges are outstanding"
  B_C1m=1
  [ "${B_C1s:-0}${B_C1m:-0}" = 11 ] && B_C1=1
else
  bad "C1 .ai-dlc-applying was removed on a run that handed back a semantic merge. pre-push re-enables the fixture suite over a partially reconciled tree, which is the one state the marker exists to keep unjudged"
fi

# --- C2: the manifest says so, in the row vocabulary the operator reads -----------------------
# Both directions in one arm. A withheld stamp reported as `RESOLVED restamp` is worse than
# either failure alone: the operator reads the resolution and stops looking.
if has_row "$OUT_WORK" DECISION restamp-withheld; then
  ok "C2 the run emits DECISION restamp-withheld"
else
  bad "C2 the run withheld nothing the operator can see — no DECISION restamp-withheld row"
fi
if has_row "$OUT_WORK" RESOLVED restamp || has_row "$OUT_WORK" RESOLVED consistent; then
  bad "C2 the same run also reported RESOLVED restamp / RESOLVED consistent. 'the tree matches theirs; fixture suite re-enabled' beside an outstanding merge is the strongest false claim this manifest can make"
else
  ok "C2 and does NOT also claim RESOLVED restamp or RESOLVED consistent"
fi

# --- C3: the pre-existing green path does not regress -----------------------------------------
# THE ARM THAT CATCHES AN OVER-BROAD FIX. A guard that counts rows emitted after it — or that is
# read at exit rather than at the guard — withholds the stamp on every clean pull, and a consumer
# that can never stamp can never push.
G_VER="$(stamp_ver "$C_GREEN")"; G_SHA="$(stamp_sha "$C_GREEN")"; G_MK="$(marker "$C_GREEN")"
if [ "$G_VER" = "$THEIRS_VER" ] && [ "$G_SHA" = "$THEIRS_SHORT" ] && [ "$G_MK" = GONE ] \
   && has_row "$OUT_GREEN" RESOLVED restamp; then
  ok "C3 a run with no hand-back still stamps $THEIRS_VER @ $THEIRS_SHORT and clears the marker"; B_C3=1
else
  bad "C3 a CLEAN pull was withheld: stamp 'version: ${G_VER:-<absent>} / commit: ${G_SHA:-<absent>}', marker $G_MK. Every consumer with no unregistered-hook validator emits DECISION hook-registration-unchecked after the guard; counting that row withholds every correct pull and the tree can never push again"
fi

# --- C7: a DECISION row withholds it too, on its own -------------------------------------------
# The seed m3 needs. A counter watching `say WORKLIST` alone leaves every operator DECISION
# stamping exactly as before, and the row is emitted from a different phase, so no arm above
# reaches it. C1 owns the marker half for both shapes; this arm asserts the stamp only.
D_VER="$(stamp_ver "$C_DEC")"; D_SHA="$(stamp_sha "$C_DEC")"
if [ "$D_VER" = "1.0.0" ] && [ "$D_SHA" = "$BASE" ] && has_row "$OUT_DEC" DECISION restamp-withheld; then
  ok "C7 a run whose only hand-back is a DECISION row also leaves the stamp at base"; B_C7=1
else
  bad "C7 a DECISION-only run stamped 'version: ${D_VER:-<absent>}'. An operator call — here a gated deletion — is outstanding work as much as a semantic merge is, and it is counted in a different phase from the WORKLIST rows"
fi

# --- C4/C5: --finish stamps, and does nothing else --------------------------------------------
C_FIN="$WORK/cons-finish"
# FINISHED, not green. `--finish` verifies the tree before it stamps, so a consumer still at base is
# an unapplied tree and is correctly withheld; the state --finish is FOR is the one the operator
# produced by doing the worklist -- theirs' content on disk, the marker still present.
mk_consumer "$C_FIN" finished hrv || { echo "FIXTURE BROKEN — could not build the finish consumer" >&2; exit 2; }
printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_FIN/.claude/.ai-dlc-applying"
OUT_FIN="$(run_apply "$APPLY" "$C_FIN" --finish)"
F_VER="$(stamp_ver "$C_FIN")"; F_SHA="$(stamp_sha "$C_FIN")"; F_MK="$(marker "$C_FIN")"
if [ "$F_VER" = "$THEIRS_VER" ] && [ "$F_SHA" = "$THEIRS_SHORT" ] && [ "$F_MK" = GONE ]; then
  ok "C4 --finish writes version: $THEIRS_VER / commit: $THEIRS_SHORT and removes the marker"; B_C4=1
else
  bad "C4 --finish left the stamp at 'version: ${F_VER:-<absent>} / commit: ${F_SHA:-<absent>}' with the marker $F_MK. This is the ONLY exit from a withheld stamp: with the marker present pre-push refuses every push, so a --finish that does not stamp leaves the consumer with no way forward"
fi

# C5 ON A MERGED TREE. The operator resolved the semantic merge into a copy that differs from BOTH
# base and theirs. --finish must leave those bytes exactly as they are AND stamp: a finisher that
# ran the resolution phases would re-bucket the merged file to CLASSIFY and withhold forever, and a
# finisher that compared each copy against theirs would withhold on it the same way.
C_MRG="$WORK/cons-merged"
mk_consumer "$C_MRG" merged hrv || { echo "FIXTURE BROKEN — could not build the merged consumer" >&2; exit 2; }
printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_MRG/.claude/.ai-dlc-applying"
cp "$C_MRG/$DRIVER_REL" "$WORK/merged-driver.before"
OUT_MRG="$(run_apply "$APPLY" "$C_MRG" --finish)"
if cmp -s "$WORK/merged-driver.before" "$C_MRG/$DRIVER_REL" \
   && [ "$(stamp_ver "$C_MRG")" = "$THEIRS_VER" ] && [ "$(marker "$C_MRG")" = GONE ] \
   && ! has_row "$OUT_MRG" WORKLIST finish-unapplied; then
  ok "C5 --finish over a hand-merged $DRIVER_REL leaves its bytes unchanged AND stamps $THEIRS_VER — no resolution work, and a merged file is not counted as unapplied"; B_C5=1
else
  bad "C5 --finish over a hand-merged tree: driver bytes $(cmp -s "$WORK/merged-driver.before" "$C_MRG/$DRIVER_REL" && echo unchanged || echo CHANGED), stamp '$(stamp_ver "$C_MRG")', marker $(marker "$C_MRG"), finish-unapplied $(has_row "$OUT_MRG" WORKLIST finish-unapplied && echo present || echo absent). In the real workflow a BOTH-CHANGED file the operator has just merged re-buckets to CLASSIFY on every run, so a finisher that resolves or that compares to theirs never reaches the stamp"
fi

# --- C8: --finish TERMINATES over a DECISION row it cannot clear -------------------------------
# The same tree as C4 minus the hook-registration validator, so apply.sh emits
# `DECISION hook-registration-unchecked` and — under --finish alone — emits it BEFORE the stamp.
# A finisher gating on the same counter as the ordinary run withholds on that row, and the row's
# own remedy is to re-run the apply, which is the phase --finish exists to skip. The consumer is
# then wedged with the marker on disk and no invocation that can clear it, which is the failure
# this whole change exists to prevent, reintroduced one layer down by the change itself.
C_TERM="$WORK/cons-terminate"
mk_consumer "$C_TERM" finished || { echo "FIXTURE BROKEN — could not build the terminate consumer" >&2; exit 2; }
printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_TERM/.claude/.ai-dlc-applying"
OUT_TERM="$(run_apply "$APPLY" "$C_TERM" --finish)"
if ! has_row "$OUT_TERM" DECISION hook-registration-unchecked; then
  bad "C8 setup: --finish emitted no DECISION row on a consumer with no validate-hook-registration.sh, so this arm cannot distinguish the two counters and its pass is vacuous"
elif [ "$(stamp_ver "$C_TERM")" = "$THEIRS_VER" ] && [ "$(marker "$C_TERM")" = GONE ]; then
  ok "C8 --finish stamps over a DECISION row it has no phase to clear — the escape terminates"; B_C8=1
else
  bad "C8 --finish withheld on DECISION hook-registration-unchecked (stamp '$(stamp_ver "$C_TERM")', marker $(marker "$C_TERM")). That row's remedy is to re-run the apply, which is the phase --finish skips, so the operator has a refused push, a marker on disk and no invocation that clears it"
fi

# === F1/F2/F3: --finish CHECKS THE IDENTITY OF <theirs>, NOT MERELY THAT IT RESOLVES ==========
#
# THE DEFECT. `--finish`'s only guard on <theirs> asked whether the ref RESOLVES. A ref that
# names the WRONG thing resolves perfectly, and every arm downstream then did its job over it:
# the stamp took its sha, the read-back agreed with what had just been written, `RESOLVED
# consistent "the tree matches <ref>"` printed over a tree never brought there, and the marker
# was removed. The stamp is what the NEXT pull computes its merge base from, so the damage
# surfaces a pull later. `--finish` is RETYPED BY HAND from a withheld row that prints <dist> and
# <consumer> as placeholders — apply.sh's own comment calls it the invocation in this program
# most exposed to a fumbled argument — and C4 above could never have caught it, because it passes
# the same value as both the record and the argument.
#
# THE SECOND SIDE OF THE JOIN ALREADY EXISTED AND NOTHING READ IT. `.ai-dlc-applying` records
# `theirs:` (this fixture has written that line since C1), is deliberately NOT rewritten under
# `--finish`, and every reader in the tree was an existence test — `core/git-hooks/pre-push` asks
# only whether the file is there. The same run then deleted it.
#
# SUBJECT PROBE, AND WHY IT IS NOT F1's OBSERVABLE. An apply.sh that predates this guard stamps
# and clears on F1's input, which is the DEFECT signature — so probing on that would report a
# regression on every consumer that simply has not received the fix yet. The no-record shape is
# the one that separates absent from present without being the thing F1 asserts: it stamps under
# BOTH programs, and only the fixed one says on its own row that it could not check.
C_IDN="$WORK/cons-id-norecord"
# Written from OTHER, the ref this finish names: with no record to dispute it, the legitimate case
# is a tree carrying the argument's content.
mk_consumer "$C_IDN" green hrv && seed_ref "$DIST" "$BASE" "$OTHER" "$C_IDN" \
  || { echo "FIXTURE BROKEN — could not build the no-record consumer" >&2; exit 2; }
rm -f "$C_IDN/.claude/.ai-dlc-applying"
OUT_IDN="$(run_finish_as "$APPLY" "$C_IDN" "$OTHER")"
if ! has_row "$OUT_IDN" DECISION restamp-identity-unchecked; then
  if [ "$IS_DIST" = 1 ]; then
    bad "the resolved apply.sh ($APPLY) emitted no DECISION restamp-identity-unchecked on a --finish with no in-flight record, so the identity guard is absent and F1/F2/F3 cannot be evaluated. HARD in the distribution: the subject must be present here."
  else
    printf '  SKIP  %s\n' "F1/F2/F3 — the installed apply.sh predates the --finish identity guard; it lands with this same pull"
  fi
else
  ok "F0 --finish says on its OWN row when it could not check identity, so \"could not check\" never prints the same as \"checked and agreed\""

  # --- F1: THE OFFENDER — a resolvable ref naming content this tree does not carry ------------
  # ASSERTED BY ITS EFFECT, NOT BY THE ROW. This repo has shipped a guard whose "refuses to
  # overwrite" was asserted by a row COUNT — true either way — while the refusal exited before
  # that row was ever read, so a mutant that both REPORTED and OVERWROTE passed everything. The
  # load-bearing conjuncts here are the stamp still holding BASE's version and the marker still
  # being on disk; the row is asserted too, but it is the weakest of the three.
  C_IDM="$WORK/cons-id-mismatch"
  mk_consumer "$C_IDM" finished hrv || { echo "FIXTURE BROKEN — could not build the mismatch consumer" >&2; exit 2; }
  printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_IDM/.claude/.ai-dlc-applying"
  # READ THE STAMP BEFORE THE RUN AND COMPARE AGAINST ITSELF. Comparing against a derived
  # constant would put a silent join between this arm and mk_consumer's literal; comparing
  # against the pre-run bytes cannot drift. The non-empty conjunct is what stops an absent
  # stamp making both sides equal and vacuously green.
  F1_PRE_VER="$(stamp_ver "$C_IDM")"; F1_PRE_SHA="$(stamp_sha "$C_IDM")"
  OUT_IDM="$(run_finish_as "$APPLY" "$C_IDM" "$OTHER")"
  F1_VER="$(stamp_ver "$C_IDM")"; F1_SHA="$(stamp_sha "$C_IDM")"; F1_MK="$(marker "$C_IDM")"
  if has_row "$OUT_IDM" DECISION restamp-identity-mismatch \
     && [ -n "$F1_PRE_VER" ] && [ "$F1_VER" = "$F1_PRE_VER" ] && [ "$F1_SHA" = "$F1_PRE_SHA" ] \
     && [ "$F1_MK" = PRESENT ]; then
    ok "F1 --finish to a ref whose core/ tree this tree was never written from is REFUSED: the stamp is byte-for-byte the $F1_PRE_VER it held before the run and .ai-dlc-applying is still on disk"; B_F1=1
  else
    bad "F1 --finish stamped a ref the recorded in-flight marker disagrees with. Recorded theirs=$THEIRS, argv=$OTHER, and the stamp moved from '$F1_PRE_VER @ $F1_PRE_SHA' to '$F1_VER @ $F1_SHA' with the marker $F1_MK (expected PRESENT and no movement at all). Resolvability was the only question asked of <theirs>, so a fumbled but valid ref advances the stamp the NEXT pull bases its merge on, over a tree that was never brought there"
  fi

  # --- F2: THE NEAR-MISS — a different COMMIT carrying the same core/ tree --------------------
  # THIS ARM EXISTS TO STOP A FUTURE AUTHOR "SIMPLIFYING" THE TREE KEY INTO A COMMIT KEY. The
  # distribution ships docs-only commits between releases, so two refs routinely differ as
  # commits while the bytes this pull WRITES are identical; refusing on the commit wedges a
  # finisher whose only sin is naming the newer of two equivalent refs, and it would look exactly
  # like F1 working. Mutant m10 below is that simplification, and this is the arm that kills it.
  C_IDD="$WORK/cons-id-docs"
  mk_consumer "$C_IDD" finished hrv || { echo "FIXTURE BROKEN — could not build the docs-only consumer" >&2; exit 2; }
  printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_IDD/.claude/.ai-dlc-applying"
  OUT_IDD="$(run_finish_as "$APPLY" "$C_IDD" "$DOCS")"
  F2_VER="$(stamp_ver "$C_IDD")"; F2_SHA="$(stamp_sha "$C_IDD")"; F2_MK="$(marker "$C_IDD")"
  if [ "$F2_VER" = "$THEIRS_VER" ] && [ "$F2_SHA" = "$DOCS_SHORT" ] && [ "$F2_MK" = GONE ] \
     && ! has_row "$OUT_IDD" DECISION restamp-identity-mismatch \
     && ! has_row "$OUT_IDD" DECISION restamp-identity-unchecked; then
    ok "F2 a docs-only move of <theirs> still finishes — stamped $F2_VER @ $DOCS_SHORT, marker cleared, and NEITHER identity row printed"; B_F2=1
  else
    bad "F2 a <theirs> differing from the record by a docs-only commit did not finish cleanly: stamp '$F2_VER @ $F2_SHA' (expected $THEIRS_VER @ $DOCS_SHORT), marker $F2_MK (expected GONE), mismatch row $(has_row "$OUT_IDD" DECISION restamp-identity-mismatch && echo present || echo absent), unchecked row $(has_row "$OUT_IDD" DECISION restamp-identity-unchecked && echo present || echo absent). ${DOCS} and ${THEIRS} carry the identical core/ tree $S3_T, so the bytes this pull writes are the same at both — a guard that stops here is keyed on the commit and wedges every finisher naming the newer of two equivalent refs"
  fi

  # --- F3: IT NEVER FAILS FOR WANT OF THE RECORD ----------------------------------------------
  # The over-broad fix — refusing whenever identity could not be CONFIRMED — wedges the consumer
  # whose marker was cleared by hand, which is the remedy `core/git-hooks/pre-push` itself prints.
  # F0 above owns the ROW on this run; F3 owns the EFFECT, so neither is a restatement of the
  # other. Mutant m11 below is that over-broad fix.
  F3_VER="$(stamp_ver "$C_IDN")"; F3_MK="$(marker "$C_IDN")"
  if [ "$F3_VER" = "$OTHER_VER" ] && [ "$F3_MK" = GONE ] && has_row "$OUT_IDN" RESOLVED restamp; then
    ok "F3 an unusable record is UNCHECKED and not refused — the stamp still advanced to $OTHER_VER and the marker cleared"; B_F3=1
  else
    bad "F3 --finish with no in-flight record refused to stamp: version '$F3_VER' (expected $OTHER_VER), marker $F3_MK (expected GONE), RESOLVED restamp $(has_row "$OUT_IDN" RESOLVED restamp && echo present || echo absent). A consumer that cleared the marker by hand — the remedy pre-push prints — then has a refused push, and the one invocation that clears it now refuses too"
  fi
fi

# --- C6: the withheld row hands the operator the escape ---------------------------------------
# A withheld stamp with no reachable finish command WEDGES the consumer. The premise is asserted
# beside the arm rather than assumed: if pre-push stops refusing on the marker, C6 is guarding a
# hazard that no longer exists and should be re-read, not left quietly green.
WITHHELD_DETAIL="$(detail_of "$OUT_WORK" DECISION restamp-withheld)"
case "$WITHHELD_DETAIL" in
  *--finish*) ok "C6 the withheld row names --finish, so the operator can stamp once the worklist is disposed"; B_C6=1 ;;
  "")         bad "C6 the withheld row carried NO detail field at all — the operator is told the stamp was withheld and nothing about how to finish" ;;
  *)          bad "C6 the withheld row does not name --finish: ${WITHHELD_DETAIL} — with the marker on disk pre-push refuses every push, and the row that caused it points nowhere" ;;
esac
# KEYED ON THE EMITTING TEST, NOT ON THE FILE. This arm was a whole-file `grep -q ai-dlc-applying`
# for one revision, and it was closable by prose: four lines in `core/git-hooks/pre-push` carry the
# token and only ONE of them is the refusal — the other three are a comment and two lines of the
# message the refusal prints. Measured on a copy with the refusal deleted and every comment kept,
# the whole-file grep still passed. So the premise for C6's severity would have survived the
# removal of the thing that gives C6 its severity.
#
# BOTH DIRECTIONS, in the same invocation, because a grammar that cannot spell its own subject
# scores that subject as a non-instance and returns a clean zero either way. The stripped copy is
# built by deleting exactly the lines this arm's grammar matches, so a grammar that matched
# nothing to begin with fails the control rather than passing the arm.
PP_TEST='^[[:space:]]*if[[:space:]]+\[[[:space:]]+-f[[:space:]]+\.claude/\.ai-dlc-applying[[:space:]]+\]'
if [ -z "$PREPUSH" ]; then
  bad "C6 premise: no pre-push was resolved in either layout (looked for core/git-hooks/pre-push and .githooks/pre-push). C6 asserts an escape from a refusal this fixture cannot see, so its severity is unverified"
else
  echo "HERMETIC-CONSUMED $PREPUSH"
  PP_STRIPPED="$WORK/pp-stripped"
  grep -vE "$PP_TEST" "$PREPUSH" > "$PP_STRIPPED"
  if ! grep -qE "$PP_TEST" "$PREPUSH"; then
    bad "C6 premise: $PREPUSH carries no \`if [ -f .claude/.ai-dlc-applying ]\` test. Either the refusal was removed — in which case a withheld stamp no longer wedges anything and C6's severity needs re-reading — or it was respelled and this grammar can no longer see it, which returns the same clean zero"
  elif grep -qE "$PP_TEST" "$PP_STRIPPED"; then
    bad "C6 premise CONTROL: the grammar still matches a copy with every matching line deleted, so it is not keyed on what it claims and its pass above proves nothing"
  else
    ok "C6 premise: $PREPUSH still TESTS for the marker, and the arm goes quiet on a copy with that test removed — so the wedge C6 hands an escape from is real"
  fi
fi

# --- CWD: the verdict does not depend on where the runner stands ------------------------------
# The suite dispatches `bash "$d/run.sh"` from the repo root. Everything above resolves from `$0`
# and from absolute mktemp paths, which is a claim, so re-drive the decisive assertion from `/`.
C_CWD="$WORK/cons-cwd"
mk_consumer "$C_CWD" worklist || { echo "FIXTURE BROKEN — could not build the cwd consumer" >&2; exit 2; }
OUT_CWD="$( cd / && run_apply "$APPLY" "$C_CWD" )"
if [ "$(stamp_ver "$C_CWD")" = "1.0.0" ] && [ "$(marker "$C_CWD")" = PRESENT ] \
   && has_row "$OUT_CWD" DECISION restamp-withheld; then
  ok "CWD the same run from / reaches the same verdict — no assertion here is a property of the runner's directory"
else
  bad "CWD driven from / the withheld stamp did not reproduce (stamp '$(stamp_ver "$C_CWD")', marker $(marker "$C_CWD")). Some path above resolves from the process cwd, so a green run from the repo root says nothing about a consumer's"
fi

fi  # ---- end of unit cf

if sg u; then
# --- U1-U4: union-gate condition (1) is DRIVEN by apply.sh, not narrated at it ----------------
# SKILL.md step 8 lets apply write only after `emit-report.sh --verify` exits 0. That was prose,
# and `theirs` was an argument the executing session supplied — so a session verifying the report
# against the ref the REPORT names, while apply resolves a NEWER one, got exit 0 over a region
# describing a different upstream. apply.sh now runs the verify itself with the `$THEIRS` it is
# about to apply, so the two values cannot differ.
#
# THE ROWS ARE `NOTE`, AND U1/U3 ARE WHAT HOLD THEM THERE. `say` counts WORKLIST and DECISION
# into `handback`, and a non-zero hand-back withholds the re-stamp. A DECISION on either arm
# would withhold it on every apply that has no report — which is every other fixture — and a
# withheld stamp with the marker down is the wedge this whole file exists to prevent.
# WORLDS ARE BUILT ONCE AND COPIED. A rendered report costs ~11s and every union-gate world needs
# one, so each report-carrying shape below is rendered ONCE and `cp -Rp`'d per drive. cfu_copy refuses
# (non-zero) unless the copy's report is byte-identical to the source's, so a drive can never read a
# world other than the one that was rendered, and every copy is taken BEFORE any apply touches the source.
cfu_copy() { # cfu_copy <src-world> <dst-world>
  cp -Rp "$1" "$2" || return 1
  [ -f "$1/_bmad-output/ai-dlc-update/reconcile-report.md" ] || return 0
  cmp -s "$1/_bmad-output/ai-dlc-update/reconcile-report.md" "$2/_bmad-output/ai-dlc-update/reconcile-report.md"
}
C_U1="$WORK/cons-u1"; C_U2="$WORK/cons-u2"; C_U3="$WORK/cons-u3"; C_U4="$WORK/cons-u4"
C_UCUR="$WORK/cons-ucur"; C_USTALE="$WORK/cons-ustale"
C_X0="$WORK/ra-x0-$$"; C_X1="$WORK/ra-x1-$$"
for c in "$C_UCUR" "$C_USTALE" "$C_U3"; do
  mk_consumer "$c" green || { echo "FIXTURE BROKEN — could not build a union-gate consumer" >&2; exit 2; }
done
mk_report "$C_UCUR"   "$THEIRS"   # current: rendered at the ref apply will use
mk_report "$C_USTALE" "$BASE"     # stale:   rendered at an OLDER upstream
# U1 and RA-X0 run on copies of the current world, U2 and RA-X1 on copies of the stale one (the worlds
# those arms built for themselves were these two states exactly). U4 drives --finish, so its tree must be
# FINISHED: an unapplied one is withheld by the tree check, and the arm would then be reading that
# refusal instead of whether the union gate was consulted. A finished tree is the green tree plus
# seed_ref's overwrite of every changed core path -- that is all `finished` mode adds -- so U4 is a copy
# of the STALE world with seed_ref applied: still a stale report, and --finish never reads it.
if ! { cfu_copy "$C_UCUR" "$C_U1" && cfu_copy "$C_UCUR" "$C_X0" \
       && cfu_copy "$C_USTALE" "$C_U2" && cfu_copy "$C_USTALE" "$C_X1" && cfu_copy "$C_USTALE" "$C_U4" \
       && seed_ref "$DIST" "$BASE" "$THEIRS" "$C_U4"; }; then
  echo "FIXTURE BROKEN — could not copy the union-gate worlds" >&2; exit 2
fi

# SANITY: the current and stale regions must actually DIFFER, or U2 passes vacuously — a
# differential whose two sides are the same input establishes nothing.
if ! cmp -s "$C_U1/_bmad-output/ai-dlc-update/reconcile-report.md" \
            "$C_U2/_bmad-output/ai-dlc-update/reconcile-report.md"; then
  ok "U0 setup: the region rendered at theirs and the region rendered at base DIFFER, so U2 tests a real mismatch"
else
  bad "U0 setup: the two rendered regions are byte-identical — U2 could not fail and proves nothing"
  echo; echo "apply-restamp-worklist: FIXTURE BROKEN" >&2; exit 2
fi

OUT_U1="$(run_apply "$APPLY" "$C_U1")"; RC_U1=$?
OUT_U2="$(run_apply "$APPLY" "$C_U2")"; RC_U2=$?
OUT_U3="$(run_apply "$APPLY" "$C_U3")"; RC_U3=$?

# U1: a report matching THIS run's theirs verifies, and the NOTE does not withhold the stamp.
if [ "$RC_U1" -eq 0 ] && has_row "$OUT_U1" NOTE report-verified \
   && [ "$(stamp_ver "$C_U1")" = "$THEIRS_VER" ]; then
  ok "U1 a report rendered at this run's theirs passes the union gate, and the NOTE row leaves the stamp alone"; B_U1=1
else
  bad "U1 a CURRENT report did not pass cleanly (rc=$RC_U1, stamp '$(stamp_ver "$C_U1")', row $(has_row "$OUT_U1" NOTE report-verified && echo present || echo ABSENT)) — either the gate rejects a good report, or it emitted a counting row and withheld a clean pull"
fi

# U2: THE DEFECT. A region rendered at a different upstream must stop the write.
if [ "$RC_U2" -ne 0 ] && [ "$(stamp_ver "$C_U2")" = "1.0.0" ] && [ "$(marker "$C_U2")" = GONE ]; then
  ok "U2 a report rendered at a DIFFERENT theirs refuses the apply (rc=$RC_U2), leaving the stamp at base and writing no in-flight marker"; B_U2=1
else
  bad "U2 a STALE region did not stop the apply (rc=$RC_U2, stamp '$(stamp_ver "$C_U2")', marker $(marker "$C_U2")) — upstream moving between the dry run and the apply writes content nobody reviewed"
fi

# U3: no report does NOT block — two dozen fixture directories drive this program without one —
# but the manifest says nobody checked rather than staying silent about it.
if [ "$RC_U3" -eq 0 ] && has_row "$OUT_U3" NOTE report-unverified \
   && [ "$(stamp_ver "$C_U3")" = "$THEIRS_VER" ]; then
  ok "U3 an absent report does not block, and says so as NOTE report-unverified rather than passing silently"
else
  bad "U3 an absent report changed the outcome (rc=$RC_U3, stamp '$(stamp_ver "$C_U3")', row $(has_row "$OUT_U3" NOTE report-unverified && echo present || echo ABSENT)) — either it wedged a driver that has never required a report, or it passed with no row at all"
fi

# U4: --finish must NOT consult the gate. It writes no core file, so there is no write to
# authorize, and a finisher that refuses leaves the marker down with no way to clear it.
printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_U4/.claude/.ai-dlc-applying"
OUT_U4="$(run_finish_as "$APPLY" "$C_U4" "$THEIRS")"; RC_U4=$?
if [ "$RC_U4" -eq 0 ] && [ "$(stamp_ver "$C_U4")" = "$THEIRS_VER" ]; then
  ok "U4 --finish stamps over a STALE report — the escape cannot be blocked by the gate that guards writes it does not make"
else
  bad "U4 --finish was blocked by a stale report (rc=$RC_U4, stamp '$(stamp_ver "$C_U4")') — the consumer is wedged: the marker is down, pre-push refuses the suite, and the run that clears it just refused"
fi

# --- U5: THE BLOCKER RESOLVED BETWEEN THE APPROVAL AND THE APPLY -------------------------------
# SKILL.md step 7 requires every HARD-* blocker resolved BEFORE this program writes, and every
# resolution REWRITES the region the operator approved — a `--stamp readopt` turns
# HARD-OVERRIDE-DRIFT-SECTION into OVERRIDE-OK, a register row removes
# HARD-LAYER-ADJUDICATION-MISSING. So the ordinary, prescribed sequence leaves an approved report
# listing findings that no longer exist, `--verify` fails, and the refusal used to name two causes
# — upstream moved, the region was hand-edited — of which neither is true. `--verify` now exits 3
# for this case and apply.sh refuses NAMING it, with the one-step remedy.
#
# THE BLOCKER IS SEEDED IN THE CONSUMER'S OWN LAYER, not stubbed into a detector: an override
# whose `base_sha` resolves in neither repo is what layer-drift.sh calls
# HARD-OVERRIDE-BASE-UNRESOLVABLE, and DELETING that file is a resolution of exactly the shape
# step 7 prescribes. Nothing about the dist changes, so the refs lines hold still and the only
# difference between the approved region and the fresh render is the blocking list.
#
# STILL A REFUSAL. The four conjuncts are asserted in TWO arms on purpose. A gate that refuses
# and a gate that refuses for the right reason are different claims, and the mutants below kill
# them separately: A1 leaves the refusal and takes the diagnosis, A2 takes the refusal.
#
# ONE WORLD, ONE APPLY RUN, TWO READERS. U5 (the diagnosis) and RA1 (the refusal with no recorded
# re-approval) drive the same state: the blocker approved, then resolved, with one unseen row and no
# record. U5 scores the cause/remedy/forward and RA1 scores rc/stamp/WRITTEN/NOTE plus its stderr arms,
# all off the one captured run. Both are the unseen world, so neither displaces the other's motivating
# world: U5-0 below still reads the approved-vs-after differential, and the unseen row it adds is a
# non-HARD finding (U5-0 asserts the after-render carries zero HARD-* rows).
U5_SRC="$WORK/u5-src-unseen"
u5_build "$U5_SRC" unseen || { echo "FIXTURE BROKEN — could not build the unseen U5/RA world" >&2; exit 2; }
U5_APPROVED="$U5_SRC/_bmad-output/ai-dlc-update/reconcile-report.md"
u5_hard_appr="$(grep -c '^HARD-' "$U5_APPROVED")" || u5_hard_appr=0
U5_AFTER="$WORK/u5-after-region.md"
bash "$EMIT" "$DIST" "$BASE" "$U5_SRC" "$THEIRS" > "$U5_AFTER" 2>/dev/null
u5_hard_after="$(grep -c '^HARD-' "$U5_AFTER")" || u5_hard_after=0

# U5-0 SELF-PROBE, and it runs before the verdict. Both sides reading the same rows establishes
# nothing, and a render that emitted nothing carries no HARD row either — so the after-render
# must still carry a baseline bucket row.
if [ "$u5_hard_appr" -eq 0 ]; then
  bad "U5-0 the approved region carries no HARD-* row, so there is no blocker to resolve and U5 below tests nothing"
elif ! grep -qF 'UPSTREAM-ONLY  core/session-driver/ai-dlc-session-driver.sh' "$U5_AFTER"; then
  bad "U5-0 the render taken AFTER the resolution carries no baseline bucket row — it is an empty or dead render, and its missing HARD row proves nothing"
elif [ "$u5_hard_after" -ne 0 ]; then
  bad "U5-0 deleting the override left $u5_hard_after HARD-* row(s) in a fresh render, so the blocker was not resolved and U5 is not the state it claims"
else
  ok "U5-0 setup: the approved region carries $u5_hard_appr HARD-* row(s) and the render after the resolution carries none while still rendering the baseline buckets — a real differential"
fi

C_U5="$WORK/cons-u5ra1"
cfu_copy "$U5_SRC" "$C_U5" || { echo "FIXTURE BROKEN — could not copy the U5/RA1 world" >&2; exit 2; }
OUT_U5="$(run_apply_err "$APPLY" "$C_U5" "$C_U5/stderr.txt")"; RC_U5=$?
cp "$C_U5/stderr.txt" "$WORK/ra-a1.stderr" 2>/dev/null
# PRESENCE-SHAPED IN EVERY FIELD. REMEDY is keyed on `RE-APPROVAL OWED`, which only the exit-3 branch
# prints, plus the re-run. FWD is the FORWARDED stderr, keyed on the two things only the forward
# produces: a `cause:` LINE at --verify's own indent and at least one `<`/`>` diff line. The refusal
# message itself interpolates the cause TEXT, so a `BLOCKERS-RESOLVED` conjunct is satisfied whether or
# not the forward happened.
U5="$(printf '%s|%s|%s|%s|%s|%s\n' "$RC_U5" "$(stamp_ver "$C_U5")" "$(marker "$C_U5")" \
    "$(grep -q 'BLOCKERS-RESOLVED' "$C_U5/stderr.txt" && echo CAUSE || echo -)" \
    "$(grep -qF 'apply: RE-APPROVAL OWED.' "$C_U5/stderr.txt" \
       && grep -q 're-run apply with the same four arguments' "$C_U5/stderr.txt" && echo REMEDY || echo -)" \
    "$(grep -qE '^[[:space:]]*cause: ' "$C_U5/stderr.txt" && grep -qE '^[<>] ' "$C_U5/stderr.txt" && echo FWD || echo -)")"
RA1="$(printf '%s|%s|%s|%s\n' "$RC_U5" "$(stamp_ver "$C_U5")" \
    "$(grep -q 'UPSTREAM' "$C_U5/$DRIVER_REL" && echo WRITTEN || echo UNWRITTEN)" \
    "$(has_row "$OUT_U5" NOTE blockers-resolved && echo NOTE || echo -)")"
case "$U5" in
  "1|1.0.0|GONE|"*) ok "U5 a report approved before its blocker was resolved REFUSES the apply (rc 1), leaving the stamp at base and writing no in-flight marker"; B_u5a=1 ;;
  *)                bad "U5 the apply did not refuse cleanly ($U5, want 1|1.0.0|GONE|...) — either step 7's own prescribed resolution now writes over a region nobody re-approved, or the refusal left a marker the operator has to clear by hand" ;;
esac
case "$U5" in
  *"|CAUSE|REMEDY|"*) ok "U5 and the refusal NAMES the cause (BLOCKERS-RESOLVED) and the one-step remedy with this run's four arguments — not the two false causes it used to offer"; B_u5b=1 ;;
  *)                  bad "U5 the refusal did not name the cause and the remedy ($U5) — the operator is told upstream moved or the region was hand-edited, both false, and the pull is unpassable by any sequence step 7 permits" ;;
esac
case "$U5" in
  *"|FWD") ok "U5 and --verify's own stderr is FORWARDED: the cause line and the want-vs-report diff reach the operator, so 'read the diff' points at a diff they have rather than at a tool they must re-run"; B_u5c=1 ;;
  *)       bad "U5 the refusal did not forward --verify's stderr ($U5) — the message quotes the cause text and then tells the operator to read a diff apply.sh discarded, which is a pointer to nothing" ;;
esac
[ "${B_u5a:-0}${B_u5b:-0}${B_u5c:-0}" = 111 ] && B_U5=1

# --- RA0-RA5: the recorded re-approval, and the exit-0 control --------------------------------
# EVERY RA WORLD IS A COPY of one of two builds: the unseen world above (U5_SRC) or one plain world
# (built below). The digest and label are read ONCE, from the RA-0 probe, and the records are written
# into each copy by the real hook. A copy carries the same report bytes (cfu_copy refuses otherwise) and
# the render is deterministic, so RA2's PROCEED is itself the control that the one digest is the digest
# of every copy: a record quoting a digest that differed would not proceed.
cfu_ra_world() { # cfu_ra_world <src> <dst> <none|right|wrongdg|wronglabel|pause|embedded|labelplus> -> 0 when built as asked
  local dg lb wrong
  cfu_copy "$1" "$2" || return 1
  [ "$3" = none ] && return 0
  dg="${RA_L#digest=}"; dg="${dg%% *}"; lb="${RA_L#* label=\"}"; lb="${lb%\"}"
  [ "${#dg}" -eq 64 ] && [ -n "$lb" ] || return 1
  wrong="$(printf 'a different region\n' | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
  case "$3" in
    right)      ra_answer "$2" "Re-approve the reconcile report? Region digest ${dg}." "$lb" ;;
    wrongdg)    ra_answer "$2" "Re-approve the reconcile report? Region digest ${wrong}." "$lb" ;;
    wronglabel) ra_answer "$2" "Re-approve the reconcile report? Region digest ${dg}." "Not yet, keep the report" ;;
    embedded)   ra_answer "$2" "Re-approve the reconcile report? Region digest ab${dg}cd." "$lb" ;;
    labelplus)  ra_answer "$2" "Re-approve the reconcile report? Region digest ${dg}." "$lb -- no wait" ;;
    pause)      ra_answer "$2" "Re-approve the reconcile report? Region digest ${dg}." "$lb" \
                  && py_replace_once "$2/_bmad-output/operator-answers-history.md" " -- AskUserQuestion
" " -- USER_PAUSE
" ;;
    *) return 1 ;;
  esac
}
cfu_ra_drive() { # cfu_ra_drive <apply-path> <tag> <src> <record-kind> -> the ra_score cell, or BROKEN
  local c="$WORK/ra-$2-$$-$RANDOM"
  cfu_ra_world "$3" "$c" "$4" || { echo "BROKEN"; return; }
  ra_score "$1" "$c"
  cp "$c/ra-stderr.txt" "$WORK/ra-$2.stderr" 2>/dev/null
}
cfu_ra_drive_shim() { # cfu_ra_drive_shim <tag> <grep|sha|none> -> "<ra_score cell>|<the re-approval line under the shim>"
  local c="$WORK/ra-$1-$$-$RANDOM" s="$WORK/ra-shim-$1" out rc l sp
  cfu_copy "$U5_SRC" "$c" || { echo "BROKEN"; return; }
  ra_shim "$s" "$2" || { echo "BROKEN"; return; }
  sp="$s:$PATH"; [ "$2" = none ] && sp="$s"
  l="$(PATH="$sp" bash "$EMIT" --verify "$c/_bmad-output/ai-dlc-update/reconcile-report.md" "$DIST" "$BASE" "$c" "$THEIRS" 2>&1 >/dev/null)"
  l="$(sed -n 's/^[[:space:]]*re-approval: //p' <<< "$l")"
  out="$(PATH="$sp" bash "$APPLY" "$DIST" "$BASE" "$c" "$THEIRS" 2>"$WORK/ra-$1.stderr")"; rc=$?
  printf '%s|%s|%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" \
    "$(grep -q 'UPSTREAM' "$c/$DRIVER_REL" && echo WRITTEN || echo UNWRITTEN)" \
    "$(has_row "$out" NOTE blockers-resolved && echo NOTE || echo -)" "$l"
}
if [ -n "$RA_SKIP" ]; then
  printf '  SKIP  RA0-RA5 -- %s\n' "$RA_SKIP"
else
  # RA-0 SELF-PROBE, before any verdict: the unseen world must print unseen=1 and a 64-hex digest,
  # the plain world unseen=0, and the hook must record. Without these the arms below read a world
  # that cannot express the case.
  RA_L=""; RA_L0=""; RA_PLAIN="$WORK/ra-probe0-$$"
  c="$WORK/ra-probe-$$"
  if ! cfu_copy "$U5_SRC" "$c"; then
    bad "RA-0 could not build the unseen world"
  else
    RA_L="$(ra_line "$c")"
    u5_build "$RA_PLAIN" >/dev/null 2>&1
    RA_L0="$(ra_line "$RA_PLAIN")"
    if grep -Eq '^digest=[0-9a-f]{64} unseen=1 label="Re-approve [0-9a-f]{12}, run apply"$' <<< "$RA_L" \
       && grep -Eq '^digest=[0-9a-f]{64} unseen=0 ' <<< "$RA_L0" \
       && ra_answer "$c" "probe question" "probe answer"; then
      ok "RA-0 setup: the unseen world prints unseen=1 with a 64-hex digest and its label, the plain world unseen=0, and the real answer-capture hook records an AskUserQuestion answer"; B_RA0S=1
    else
      bad "RA-0 setup: unseen world [$RA_L], plain world [$RA_L0], or the hook ($ANSWER_HOOK) wrote no record — the arms below cannot express the case"
    fi
  fi
  RA0="$(cfu_ra_drive "$APPLY" a0 "$RA_PLAIN" none)"
  # RA1 was scored above, off the same run as U5.
  RA2="$(cfu_ra_drive "$APPLY" a2 "$U5_SRC" right)"
  RA3="$(cfu_ra_drive "$APPLY" a3 "$U5_SRC" wrongdg)"
  RA4="$(cfu_ra_drive "$APPLY" a4 "$U5_SRC" wronglabel)"
  RA5="$(cfu_ra_drive "$APPLY" a5 "$U5_SRC" pause)"
  if [ "$RA0" = "$RA_GO" ]; then
    ok "RA0 exit 3 with unseen=0 and no record PROCEEDS with a NOTE blockers-resolved row — the approval saw a superset, so no pull that had a blocker is wedged"; B_RA0=1
  else
    bad "RA0 unseen=0 did not proceed ($RA0, want $RA_GO) — every pull that resolved a blocker now needs a question nobody can be asked"
  fi
  if [ "$RA1" = "$RA_STOP" ]; then
    ok "RA1 exit 3 with unseen>0 and no record REFUSES, the target file unwritten and the stamp at base"; B_RA1=1
  else
    bad "RA1 unseen>0 with no re-approval did not refuse ($RA1, want $RA_STOP) — the defect: a region nobody re-approved is written"
  fi
  if [ "$RA2" = "$RA_GO" ]; then
    ok "RA2 unseen>0 with a hook-written record quoting the digest and answered with the label PROCEEDS"; B_RA2=1
  else
    bad "RA2 a correct re-approval did not let the apply proceed ($RA2, want $RA_GO) — the gate cannot be satisfied"
  fi
  if [ "$RA3" = "$RA_STOP" ]; then
    ok "RA3 a record answered with the label but quoting a DIFFERENT digest refuses — a re-approval of another region is not this one"; B_RA3=1
  else
    bad "RA3 a wrong-digest record passed ($RA3, want $RA_STOP) — the label is a constant, so the digest is the only thing binding the record to this region"
  fi
  if [ "$RA4" = "$RA_STOP" ]; then
    ok "RA4 a record quoting the digest but answered with something other than the label refuses"; B_RA4=1
  else
    bad "RA4 a non-label answer passed ($RA4, want $RA_STOP) — a 'Not yet' re-approves"
  fi
  if [ "$RA5" = "$RA_STOP" ]; then
    ok "RA5 the digest and label inside a record that is not an AskUserQuestion answer refuse"; B_RA5=1
  else
    bad "RA5 a non-AskUserQuestion record passed ($RA5, want $RA_STOP) — any record the lead can cause to exist re-approves"
  fi
  # The refusal prints the question and label to ask, so a session on old prose recovers in one ask.
  if grep -qF 'apply: RE-APPROVAL OWED.' "$WORK/ra-a1.stderr" 2>/dev/null \
     && grep -Eq '^  option label: Re-approve [0-9a-f]{12}, run apply$' "$WORK/ra-a1.stderr"; then
    ok "RA1 and the refusal prints the question and the exact option label to ask"
  else
    bad "RA1 the refusal did not print the question and option label — a session cannot recover without composing the label itself"
  fi
  # RA1-R: the forwarded --verify stderr carries NO re-render instruction. The mismatch header's
  # generic "Re-render with emit-report.sh and re-emit the report." used to be line 2 of this
  # refusal, twenty lines above "Do NOT re-render". A present `Do NOT re-render` is the positive half.
  if [ -s "$WORK/ra-a1.stderr" ] && ! grep -qF 'Re-render with emit-report.sh' "$WORK/ra-a1.stderr" \
     && grep -qF 'Do NOT re-render' "$WORK/ra-a1.stderr"; then
    ok "RA1-R the exit-3 refusal carries no 'Re-render with emit-report.sh' line, only 'Do NOT re-render'"
  else
    bad "RA1-R the exit-3 refusal still tells the session to re-render, or says nothing either way — the evidence-destroying path is offered in the same message that forbids it"
  fi
  # RA6/RA7: the digest must stand alone and the answer must EQUAL the label.
  RA6="$(cfu_ra_drive "$APPLY" a6 "$U5_SRC" embedded)"
  RA7="$(cfu_ra_drive "$APPLY" a7 "$U5_SRC" labelplus)"
  if [ "$RA6" = "$RA_STOP" ]; then
    ok "RA6 a question quoting the digest inside a longer hex run (ab<digest>cd) refuses"
  else
    bad "RA6 an embedded digest passed ($RA6, want $RA_STOP) — a different, longer hash re-approves this region"
  fi
  if [ "$RA7" = "$RA_STOP" ]; then
    ok "RA7 an answer that starts with the label and goes on ('<label> -- no wait') refuses"
  else
    bad "RA7 a label-prefixed answer passed ($RA7, want $RA_STOP) — a retraction typed after the label re-approves"
  fi
  # RA8: the unseen count's filter FAILS (grep exit 2 on unseen_rows' own pattern). The count must
  # read UNDECIDED, never 0, and apply must refuse with the target unwritten. Before the fix it read
  # 0 and apply wrote with no ask.
  RA8="$(cfu_ra_drive_shim a8 grep)"
  case "$RA8" in
    "$RA_STOP|digest="*" unseen=UNDECIDED label="*) ok "RA8 a failing unseen filter prints unseen=UNDECIDED and the apply refuses, the target file unwritten" ;;
    *) bad "RA8 a failing unseen filter scored [$RA8], want $RA_STOP with unseen=UNDECIDED — the count fails open and a region nobody re-approved is written" ;;
  esac
  # RA9a/RA9f: the two digest states, one property apart. RA9 used to PREPEND two `exit 1` stubs and
  # call that "no sha256 tool"; both stubs are executable (ra_shim's closing chmod), so `shasum`
  # resolved to a stub that EXISTS and fails -- which the engine now reports as FAILED-shasum, never
  # UNAVAILABLE. RA9a builds a PATH with neither tool (UNAVAILABLE); RA9f keeps the failing stub.
  # RA9a: no sha256 tool. digest=UNAVAILABLE with unseen>0 refuses naming the missing tool, and
  # prints no question that could never be answered.
  RA9="$(cfu_ra_drive_shim a9 none)"
  case "$RA9" in
    "$RA_STOP|digest=UNAVAILABLE unseen=1 "*)
      if grep -qF 'no sha256 tool: install shasum' "$WORK/ra-a9.stderr" && ! grep -qF 'RE-APPROVAL OWED' "$WORK/ra-a9.stderr"; then
        ok "RA9a with no sha256 tool on PATH the digest is UNAVAILABLE and the apply refuses naming shasum, printing no unanswerable question"
      else
        bad "RA9a the refusal did not name the missing tool, or still printed a question quoting UNAVAILABLE"
      fi ;;
    *) bad "RA9a with no sha256 tool scored [$RA9], want $RA_STOP with digest=UNAVAILABLE unseen=1" ;;
  esac
  # RA9f: shasum EXISTS (an executable stub first on PATH) and exits 1. The digest is FAILED-shasum,
  # the apply refuses naming the failed tool, and the missing-tool remedy is NOT what it prints.
  RA9F="$(cfu_ra_drive_shim a9f sha)"
  case "$RA9F" in
    "$RA_STOP|digest=FAILED-shasum unseen=1 "*)
      if grep -qF 'could not digest the fresh region: shasum exists on this box' "$WORK/ra-a9f.stderr" \
         && grep -qF 'NOTHING HAS BEEN WRITTEN.' "$WORK/ra-a9f.stderr" \
         && ! grep -qF 'no sha256 tool: install shasum' "$WORK/ra-a9f.stderr" \
         && ! grep -qF 'RE-APPROVAL OWED' "$WORK/ra-a9f.stderr"; then
        ok "RA9f with a shasum that exists and exits 1 the digest is FAILED-shasum and the apply refuses naming the failed tool, not the missing one"
      else
        bad "RA9f the refusal did not name the failed shasum, or read it as a missing tool, or printed a question"
      fi ;;
    *) bad "RA9f with a failing shasum scored [$RA9F], want $RA_STOP with digest=FAILED-shasum unseen=1" ;;
  esac
fi

# --- RA-X: --verify's exit 0 and exit 1 print no re-approval line ------------------------------
# The line is emitted for exit 3 ONLY. A current report: stdout is exactly the one success line and
# stderr is EMPTY. A report rendered at base: exit 1 and no re-approval line. The two worlds are copies
# of the current and the stale union-gate worlds taken before any apply ran (C_X0, C_X1 above).
RX0_O="$(bash "$EMIT" --verify "$C_X0/_bmad-output/ai-dlc-update/reconcile-report.md" "$DIST" "$BASE" "$C_X0" "$THEIRS" 2>"$C_X0/x0.err")"; RX0=$?
bash "$EMIT" --verify "$C_X1/_bmad-output/ai-dlc-update/reconcile-report.md" "$DIST" "$BASE" "$C_X1" "$THEIRS" >/dev/null 2>"$C_X1/x1.err"; RX1=$?
RX1_N="$(grep -c 're-approval:' "$C_X1/x1.err")" || RX1_N=0
# The generic re-render line moved into the non-exit-3 cause branches; exit 1 must still print it.
grep -qF 'Re-render with emit-report.sh and re-emit the report.' "$C_X1/x1.err" || RX1_N=missing-rerender-line
RX1_C="$(grep -c '^  cause: ' "$C_X1/x1.err")" || RX1_C=0
if [ "$RX0" -eq 0 ] && [ "$RX0_O" = "emit-report: the report's mechanical region is present, current, and complete." ] && [ ! -s "$C_X0/x0.err" ] \
   && [ "$RX1" -eq 1 ] && [ "$RX1_C" -eq 1 ] && [ "$RX1_N" = 0 ]; then
  ok "RA-X --verify exit 0 prints exactly its one success line and nothing on stderr, and exit 1 prints its cause line and no re-approval line"
else
  bad "RA-X exit-0/exit-1 output moved (rc0=$RX0 out=[$RX0_O] err-bytes=$(wc -c < "$C_X0/x0.err" | tr -d ' '); rc1=$RX1 cause-lines=$RX1_C re-approval-lines=$RX1_N)"
fi

fi  # ---- end of unit u

if sg mut; then
# --- MUTANTS ----------------------------------------------------------------------------------
mut_stamp()  { # mut_stamp <rec-dir> <mode> <hrv|-> [flag...] -> "<ver>|<marker>|<withheld?>|<driver?>"
  local rec="$1" mode="$2" hrv="$3"; shift 3
  local c="$WORK/m-$$-$RANDOM"
  [ "$hrv" = hrv ] || hrv=""
  mk_consumer "$c" "$mode" "$hrv" || { echo "BROKEN|||"; return; }
  [ "${1:-}" = --finish ] && printf 'x\n' > "$c/.claude/.ai-dlc-applying"
  local out; out="$(run_apply "$rec/apply.sh" "$c" "$@")"
  printf '%s|%s|%s|%s\n' "$(stamp_ver "$c")" "$(marker "$c")" \
    "$(has_row "$out" DECISION restamp-withheld && echo WITHHELD || echo NO)" \
    "$(grep -q 'UPSTREAM' "$c/$DRIVER_REL" && echo OVERWRITTEN || echo UNTOUCHED)"
}

# REPORT-CARRYING WORLDS ARE BUILT ONCE AND COPIED. A rendered report costs ~11s, so the stale-union, current-union,
# unseen-U5 world is each rendered once here and `cp -Rp`'d per drive; mut_copy refuses (non-zero) unless the copy's
# report is byte-identical to the source's. Every copy is taken from a source no apply has touched. The copy under
# test IS the control: a drive of the unmutated mut-ctl copy on the same source world is the control for its mutants.
MUT_RPT="_bmad-output/ai-dlc-update/reconcile-report.md"
mut_copy() { # mut_copy <src-world> <dst-world>
  cp -Rp "$1" "$2" || return 1
  [ -f "$1/$MUT_RPT" ] || return 0
  cmp -s "$1/$MUT_RPT" "$2/$MUT_RPT"
}
MUT_UST="$WORK/mut-w-ust"; MUT_UCUR="$WORK/mut-w-ucur"; MUT_U5="$WORK/mut-w-u5"
if ! { mk_consumer "$MUT_UST" green && mk_report "$MUT_UST" "$BASE" \
       && mk_consumer "$MUT_UCUR" green && mk_report "$MUT_UCUR" "$THEIRS" \
       && u5_build "$MUT_U5" unseen; }; then
  echo "FIXTURE BROKEN — could not build the mut report worlds" >&2; exit 2
fi
MUT_RAL=""
if [ -z "$RA_SKIP" ]; then
  _mc="$WORK/mut-ral-$$"
  mut_copy "$MUT_U5" "$_mc" && MUT_RAL="$(ra_line "$_mc")"
fi
# mut_u5_score <apply-path> -> u5_score's cell, off a copy of the unseen U5 world
mut_u5_score() {
  local a="$1" c="$WORK/u5m-$$-$RANDOM" e rc
  mut_copy "$MUT_U5" "$c" || { echo "BROKEN|||||"; return; }
  e="$c/stderr.txt"
  run_apply_err "$a" "$c" "$e" >/dev/null; rc=$?
  printf '%s|%s|%s|%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" "$(marker "$c")" \
    "$(grep -q 'BLOCKERS-RESOLVED' "$e" && echo CAUSE || echo -)" \
    "$(grep -qF 'apply: RE-APPROVAL OWED.' "$e" \
       && grep -q 're-run apply with the same four arguments' "$e" && echo REMEDY || echo -)" \
    "$(grep -qE '^[[:space:]]*cause: ' "$e" && grep -qE '^[<>] ' "$e" && echo FWD || echo -)"
}
# mut_ra_world <src> <dst> <none|right|wrongdg|wronglabel|pause> -> the record is written into the COPY by the real hook
mut_ra_world() {
  local dg lb wrong
  mut_copy "$1" "$2" || return 1
  [ "$3" = none ] && return 0
  dg="${MUT_RAL#digest=}"; dg="${dg%% *}"; lb="${MUT_RAL#* label=\"}"; lb="${lb%\"}"
  [ "${#dg}" -eq 64 ] && [ -n "$lb" ] || return 1
  wrong="$(printf 'a different region\n' | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
  case "$3" in
    right)      ra_answer "$2" "Re-approve the reconcile report? Region digest ${dg}." "$lb" ;;
    wrongdg)    ra_answer "$2" "Re-approve the reconcile report? Region digest ${wrong}." "$lb" ;;
    wronglabel) ra_answer "$2" "Re-approve the reconcile report? Region digest ${dg}." "Not yet, keep the report" ;;
    pause)      ra_answer "$2" "Re-approve the reconcile report? Region digest ${dg}." "$lb" \
                  && py_replace_once "$2/_bmad-output/operator-answers-history.md" " -- AskUserQuestion
" " -- USER_PAUSE
" ;;
    *) return 1 ;;
  esac
}
mut_ra_drive() { # mut_ra_drive <apply-path> <tag> <src> <record-kind> -> the ra_score cell, or BROKEN
  local c="$WORK/mra-$2-$$-$RANDOM"
  mut_ra_world "$3" "$c" "$4" || { echo "BROKEN"; return; }
  ra_score "$1" "$c"
}

# THE UNMUTATED CONTROL, and it carries a POSITIVE conjunct. A control asserting only "nothing
# went wrong" passes against a subject replaced by `exit 0`; this one requires the withheld row
# to be THERE and the green run to stamp, so a copy that cannot run reports as broken rather than
# as clean.
if build_rec "$WORK/mut-ctl"; then
  CTL_W="$(mut_stamp "$WORK/mut-ctl" worklist -)"
  CTL_G="$(mut_stamp "$WORK/mut-ctl" green -)"
  if [ "$CTL_W" = "1.0.0|PRESENT|WITHHELD|OVERWRITTEN" ] && [ "${CTL_G%%|*}" = "$THEIRS_VER" ]; then
    ok "CONTROL an unmutated copy in a fresh directory reproduces both verdicts, so a mutant's silence is the mutation and not the copy"; B_mctl=1
  else
    bad "CONTROL the unmutated copy did not reproduce the shipped behaviour (worklist=$CTL_W green=$CTL_G) — every mutant verdict below is unreadable"
  fi
else
  bad "CONTROL could not stage a copy of $REC — every mutant verdict below is unreadable"
fi


# --- m1: the guard reverted to `mech_fail` alone — the unfixed program. Must die on C1. -------
if sed 's/^if \[ "$mech_fail" -gt 0 \].*$/if [ "$mech_fail" -gt 0 ]; then/' "$REC/apply.sh" \
   | mut_apply "$WORK/m1"; then
  M1="$(mut_stamp "$WORK/m1" worklist -)"
  case "$M1" in
    "$THEIRS_VER|GONE|"*) mutant_killed "$(( ${B_C1:-0} && ${B_mctl:-0} ))" m1 "m1 (guard on mech_fail alone): C1 goes red — the WORKLIST run stamps $THEIRS_VER and clears the marker, which is the shipped defect" ;;
    "1.0.0|PRESENT|"*)    bad "m1 SURVIVED: the stamp was still withheld with the guard reading mech_fail only, so C1 is not testing the handback term ($M1)" ;;
    *)                    bad "m1 produced a verdict this fixture does not recognise ($M1) — it may have died for an unrelated reason, in which case C1's kill is unearned" ;;
  esac
  M1G="$(mut_stamp "$WORK/m1" green -)"
  if [ "${M1G%%|*}" = "$THEIRS_VER" ]; then
    ok "m1 and C3 stays green under it — the two arms are not entangled"
  else
    bad "m1 also moved the clean path ($M1G): C1 and C3 are entangled and one of them proves nothing on its own"
  fi
else
  bad "m1 did not apply — the guard at apply.sh's re-stamp has been respelled away from \`if [ \"\$mech_fail\" -gt 0 ]\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# --- m2: the marker cleared outside the read-back. Must die on C1's MARKER half only. ----------
# ADDING an unconditional `rm -f "$APPLYING"` at the tail rather than moving the existing one:
# the move has two candidate sites once `--finish` exists, and a transform that catches both
# kills C4 as well and the verdict becomes unreadable.
if awk '/^exit 0$/ { print "rm -f \"$APPLYING\"" } { print }' "$REC/apply.sh" \
   | mut_apply "$WORK/m2"; then
  M2="$(mut_stamp "$WORK/m2" worklist -)"
  case "$M2" in
    "1.0.0|GONE|WITHHELD|"*) mutant_killed "$(( ${B_C1:-0} && ${B_mctl:-0} ))" m2 "m2 (marker cleared outside the read-back): C1's marker half goes red while its stamp half stays green — the half a row-count assertion cannot see" ;;
    "1.0.0|PRESENT|"*)       bad "m2 SURVIVED: the marker was still present with an unconditional rm at the tail, so C1 is not reading the file ($M2)" ;;
    *)                       bad "m2 moved the stamp as well ($M2) — the mutation was not confined to the marker and its kill is unearned" ;;
  esac
else
  bad "m2 did not apply — apply.sh no longer ends in a bare \`exit 0\`, so this mutant proves nothing"
fi

# --- m3: handback counted for WORKLIST only. Must die on C7. -----------------------------------
# Rewritten INSIDE say()'s body, so the transform is independent of whether the implementation
# spells the test as a `case` pattern, an `if`, or a comparison: any of them stops matching once
# the token is renamed. Nothing else in that function names DECISION.
if awk '
    /^say\(\) \{/ { inside=1 }
    inside { gsub(/DECISION/, "NODECISION") }
    inside && /^\}/ { inside=0 }
    { print }' "$REC/apply.sh" | mut_apply "$WORK/m3"; then
  M3D="$(mut_stamp "$WORK/m3" decision -)"
  case "$M3D" in
    "$THEIRS_VER|GONE|"*) mutant_killed "$(( ${B_C7:-0} && ${B_mctl:-0} ))" m3 "m3 (handback counts WORKLIST only): C7 goes red — a gated deletion is outstanding work and it stamps anyway" ;;
    "1.0.0|"*)            bad "m3 SURVIVED: the DECISION-only run was still withheld with DECISION renamed inside say(), so C7 is not testing the DECISION half ($M3D)" ;;
    *)                    bad "m3 produced an unrecognised verdict ($M3D) — its kill would be unearned" ;;
  esac
  M3W="$(mut_stamp "$WORK/m3" worklist -)"
  case "$M3W" in
    "1.0.0|PRESENT|"*) ok "m3 and C1 stays green under it — the WORKLIST seed and the DECISION seed are separately losable, which is why both arms exist" ;;
    *)                 bad "m3 also moved C1 ($M3W): the two seeds are not independent and one of the arms proves nothing" ;;
  esac
else
  bad "m3 did not apply — say() no longer opens with \`say() {\` at column 0, or no longer names DECISION, so this mutant proves nothing"
fi

# --- m4: `--finish` present but the withheld row does not name it. Must die on C6. -------------
# Follows shell line continuations from the `say DECISION restamp-withheld` statement, because
# that row's detail is long enough to be written across several lines.
if awk '
    /say DECISION restamp-withheld/ { inw=1 }
    inw { gsub(/--finish/, "--fnish") }
    inw && $0 !~ /\\$/ { inw=0 }
    { print }' "$REC/apply.sh" | mut_apply "$WORK/m4"; then
  # NOT another build_rec here: it would `cp` the pristine apply.sh back over the mutation and
  # the arm would score a survival against an unmutated program.
  mk_consumer "$WORK/c-m4" worklist || { echo "FIXTURE BROKEN — could not build the m4 consumer" >&2; exit 2; }
  M4_OUT="$(run_apply "$WORK/m4/apply.sh" "$WORK/c-m4")"
  case "$(detail_of "$M4_OUT" DECISION restamp-withheld)" in
    *--finish*) bad "m4 SURVIVED: the row still names --finish with the literal removed from that statement, so C6 is reading the token from somewhere this mutant does not reach" ;;
    "")         bad "m4 removed the whole row rather than the token — the mutation was not confined and C6's kill is unearned" ;;
    *)          mutant_killed "$(( ${B_C6:-0} && ${B_mctl:-0} ))" m4 "m4 (the escape unnamed): C6 goes red — the operator is left with a refused push and a row that points nowhere" ;;
  esac
else
  bad "m4 did not apply — the literal \`--finish\` is not on the \`say DECISION restamp-withheld\` statement or its continuation lines. If it is interpolated from a variable, re-anchor this mutant on that assignment; C6 is unproven until it is."
fi

# --- m5: the hand-back term present and unsatisfiable. Must die on C1. -------------------------
# A distinct mutation from m1 against the same arm: m1 REMOVES the term, this one keeps it and
# makes it never true. A guard that is present and cannot fire reads, in a diff, exactly like one
# that works — which is this repo's recurring defect, applied to the guard itself.
if sed 's/"$outstanding" -gt 0/"$outstanding" -lt 0/' "$REC/apply.sh" | mut_apply "$WORK/m5"; then
  M5="$(mut_stamp "$WORK/m5" worklist -)"
  case "$M5" in
    "$THEIRS_VER|GONE|"*) mutant_killed "$(( ${B_C1:-0} && ${B_mctl:-0} ))" m5 "m5 (hand-back term compared -lt 0): C1 goes red — the term is present and unsatisfiable" ;;
    "1.0.0|PRESENT|"*)    bad "m5 SURVIVED: the stamp was withheld with a term that can never be true, so something other than the hand-back count is withholding it ($M5)" ;;
    *)                    bad "m5 produced an unrecognised verdict ($M5)" ;;
  esac
else
  bad "m5 did not apply — the guard does not compare \`\"\$outstanding\" -gt 0\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# --- m8: the two counters collapsed into one. Must die on C8. ----------------------------------
# `--finish` gating on `handback` instead of `worklist_n`. Measured by the implementer on the
# first end-to-end run of this change: the finisher counted the hook-registration DECISION row it
# had itself just emitted and withheld forever. C4's tree cannot see it — that consumer carries
# the validator, so no such row exists — which is why C8 has a tree of its own.
if sed 's/^if \[ "$FINISH" = 1 \]; then outstanding="$worklist_n";/if [ "$FINISH" = 1 ]; then outstanding="$handback";/' \
   "$REC/apply.sh" | mut_apply "$WORK/m8"; then
  M8="$(mut_stamp "$WORK/m8" finished - --finish)"
  case "$M8" in
    "1.0.0|PRESENT|WITHHELD|"*) mutant_killed "$(( ${B_C8:-0} && ${B_mctl:-0} ))" m8 "m8 (--finish gates on handback): C8 goes red — the finisher withholds over the DECISION row it emitted itself, and no invocation can clear it" ;;
    "$THEIRS_VER|GONE|"*)       bad "m8 SURVIVED: --finish still stamped while gating on handback, so C8's tree emits no DECISION row and the arm is vacuous ($M8)" ;;
    *)                          bad "m8 produced an unrecognised verdict ($M8)" ;;
  esac
  M8H="$(mut_stamp "$WORK/m8" finished hrv --finish)"
  if [ "${M8H%%|*}" = "$THEIRS_VER" ]; then
    ok "m8 and C4 stays green under it — the two counters are separately observable, which is the whole reason C8 exists beside C4"
  else
    bad "m8 also moved C4 ($M8H): C4's consumer is emitting a hand-back row it should not, so the two arms read one input"
  fi
else
  bad "m8 did not apply — no \`outstanding=\"\$worklist_n\"\` assignment under the FINISH branch, so the two-counter design is unproven"
fi

# --- m6: over-broad — `--finish` withholds too. Must die on C4. --------------------------------
# The failure an over-cautious fix produces: every mode withholds, the marker never clears, and
# the consumer cannot push at all. Anchored on the flag variable, so it is skipped rather than
# guessed if the implementation names it something else.
if grep -q '^FINISH=0' "$REC/apply.sh"; then
  if sed 's/^\(if \[ "$mech_fail" -gt 0 \].*\); then$/\1 || [ "$FINISH" = 1 ]; then/' "$REC/apply.sh" \
     | mut_apply "$WORK/m6"; then
    M6="$(mut_stamp "$WORK/m6" finished hrv --finish)"
    case "$M6" in
      "1.0.0|"*)            mutant_killed "$(( ${B_C4:-0} && ${B_mctl:-0} ))" m6 "m6 (--finish withholds too): C4 goes red — the only exit from a withheld stamp is itself withheld and the tree can never push again" ;;
      "$THEIRS_VER|GONE|"*) bad "m6 SURVIVED: --finish still stamped with the guard extended to cover it, so C4 is not reading the stamp this mode writes ($M6)" ;;
      *)                    bad "m6 produced an unrecognised verdict ($M6)" ;;
    esac
    M6G="$(mut_stamp "$WORK/m6" green -)"
    if [ "${M6G%%|*}" = "$THEIRS_VER" ]; then
      ok "m6 and C3 stays green under it — the ordinary clean pull is untouched, so C4 owns this case alone"
    else
      bad "m6 also withheld the ordinary clean pull ($M6G): C3 and C4 are entangled and this kill is not C4's"
    fi
  else
    bad "m6 did not apply — the guard could not be extended with the FINISH term, so C4 is unproven against an over-broad fix"
  fi
else
  bad "m6 could not be built: apply.sh declares no \`FINISH=0\`, so this mutant cannot name the flag it must make the guard read. C4 is unproven against an over-broad fix until it is re-anchored on the real variable."
fi

# --- m7: `--finish` runs the full phases. Must die on C5. --------------------------------------
# Anchored on the option-parser branch rather than on any variable, so it holds whatever the flag
# is called: the option is still accepted and sets nothing, which is exactly a full run.
#
# DRIVEN ON C5's MERGED TREE. A full run re-buckets the hand-merged driver to CLASSIFY and hands it
# back as a semantic merge, so the stamp is withheld -- the real-workflow deadlock C5 names. The
# merged bytes survive either way (a CLASSIFY file is never overwritten), so the kill is the stamp
# half of C5, and `mut_stamp`'s driver field reads UNTOUCHED under both programs: the merged text
# carries no `UPSTREAM`.
if sed 's/^\([[:space:]]*\)--finish).*$/\1--finish) : ;;/' "$REC/apply.sh" | mut_apply "$WORK/m7"; then
  M7="$(mut_stamp "$WORK/m7" merged hrv --finish)"
  case "$M7" in
    "1.0.0|PRESENT|WITHHELD|UNTOUCHED") mutant_killed "$(( ${B_C5:-0} && ${B_mctl:-0} ))" m7 "m7 (--finish runs the phases): C5 goes red — the hand-merged driver re-buckets to CLASSIFY, is handed back as a semantic merge, and the stamp is withheld over a tree the operator has finished" ;;
    "$THEIRS_VER|GONE|"*)               bad "m7 SURVIVED: the merged tree still stamped with the --finish branch neutered ($M7), so C5 is not testing the phase skip" ;;
    *)                                  bad "m7 produced an unrecognised verdict ($M7)" ;;
  esac
  M7F="$(mut_stamp "$WORK/m7" finished hrv --finish)"
  case "$M7F" in
    "$THEIRS_VER|GONE|"*) ok "m7 and C4 stays green under it — a full run on a finished consumer stamps too, so only C5's merged tree separates the two modes" ;;
    *)                    bad "m7 also moved C4 ($M7F): the two arms are entangled" ;;
  esac
else
  bad "m7 did not apply — the option parser carries no \`--finish)\` branch, so this mutant proves nothing"
fi

# --- m9/m10/m11: THE --finish IDENTITY GUARD ---------------------------------------------------
# F1/F2/F3 are the arms these exist for. `mut_stamp` cannot drive them: it always passes THEIRS as
# argv and writes a marker with no `theirs:` line at all, so under it the identity guard is
# permanently in its UNCHECKED branch and none of these three mutations would change a cell.
#
# mut_finish_id <rec-dir> <argv-theirs> [nomarker] -> "<ver>|<marker>|<mismatch?>"
# PRESENCE-shaped like the rest: every expected verdict below requires either a row to APPEAR or
# the stamp to have MOVED, so a copy that dies emitting nothing fails rather than scoring a kill.
mut_finish_id() {
  local rec="$1" argv="$2" c="$WORK/mid-$$-$RANDOM"
  # Written from THEIRS, the ref the marker records. With no marker there is no record to
  # dispute, so the tree is written from the argument itself, as F3's is.
  mk_consumer "$c" finished hrv || { echo "BROKEN||"; return; }
  if [ "${3:-}" = nomarker ]; then
    seed_ref "$DIST" "$BASE" "$argv" "$c" || { echo "BROKEN||"; return; }
  fi
  [ "${3:-}" = nomarker ] || printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$c/.claude/.ai-dlc-applying"
  local out; out="$(run_finish_as "$rec/apply.sh" "$c" "$argv")"
  printf '%s|%s|%s\n' "$(stamp_ver "$c")" "$(marker "$c")" \
    "$(has_row "$out" DECISION restamp-identity-mismatch && echo MISMATCH || echo NO)"
}

# THE UNMUTATED CONTROL FOR THIS BATTERY, with positive conjuncts on BOTH sides: the offender must
# produce the mismatch ROW and the near-miss must MOVE the stamp. The control above cannot stand in
# for it — it never varies argv, so it exercises none of this code.
if build_rec "$WORK/mut-id-ctl"; then
  IDCTL_O="$(mut_finish_id "$WORK/mut-id-ctl" "$OTHER")"
  IDCTL_D="$(mut_finish_id "$WORK/mut-id-ctl" "$DOCS")"
  if [ "$IDCTL_O" = "1.0.0|PRESENT|MISMATCH" ] && [ "$IDCTL_D" = "$THEIRS_VER|GONE|NO" ]; then
    ok "CONTROL-id an unmutated copy refuses the offender and passes the docs-only near-miss, so m9/m10/m11's verdicts are the mutation and not the copy"; B_mid=1
  else
    bad "CONTROL-id the unmutated copy did not reproduce the shipped identity behaviour (offender=$IDCTL_O expected 1.0.0|PRESENT|MISMATCH, near-miss=$IDCTL_D expected $THEIRS_VER|GONE|NO) — m9/m10/m11 below are unreadable"
  fi
else
  bad "CONTROL-id could not stage a copy of $REC — m9/m10/m11 below are unreadable"
fi

# --- m9: the guard PRESENT and unsatisfiable — the unfixed program. Must die on F1. ------------
# Made to match NOTHING rather than widened: a widening leaves the same output as the original on
# some inputs and scores a kill it did not earn.
if sed 's/\[ "$_m_tree" != "$_a_tree" \]/[ "$_m_tree" != "$_m_tree" ]/' "$REC/apply.sh" \
   | mut_apply "$WORK/m9"; then
  M9="$(mut_finish_id "$WORK/m9" "$OTHER")"
  case "$M9" in
    "$OTHER_VER|GONE|NO") mutant_killed "$(( ${B_F1:-0} && ${B_mid:-0} ))" m9 "m9 (tree comparison unsatisfiable): F1 goes red — the offending ref is stamped $OTHER_VER and the marker cleared, which is the shipped defect" ;;
    "1.0.0|PRESENT|MISMATCH") bad "m9 SURVIVED: the mismatch still fired with the comparison made unsatisfiable, so F1 is reading the refusal from somewhere this mutation does not reach ($M9)" ;;
    *) bad "m9 produced a verdict this fixture does not recognise ($M9) — it may have died for an unrelated reason, in which case F1's kill is unearned" ;;
  esac
  M9D="$(mut_finish_id "$WORK/m9" "$DOCS")"
  if [ "$M9D" = "$THEIRS_VER|GONE|NO" ]; then
    ok "m9 and F2 stays green under it — F1 and F2 are not entangled"
  else
    bad "m9 also moved the near-miss ($M9D): F1 and F2 are entangled and one of them proves nothing on its own"
  fi
else
  bad "m9 did not apply — the guard no longer compares \`\"\$_m_tree\" != \"\$_a_tree\"\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# --- m10: the tree key "simplified" into a commit key. Must die on F2. ------------------------
# The exact edit F2's comment exists to prevent, and the one that looks like a tidy-up: drop
# `:core` from both sides and the guard still refuses F1's offender, so every arm but F2 stays
# green while the distribution's ordinary docs-only commit starts wedging finishers.
if sed 's/rev-parse "${_m_theirs}:core"/rev-parse "${_m_theirs}"/; s/rev-parse "${THEIRS}:core"/rev-parse "${THEIRS}"/' "$REC/apply.sh" \
   | mut_apply "$WORK/m10"; then
  M10="$(mut_finish_id "$WORK/m10" "$DOCS")"
  case "$M10" in
    "1.0.0|PRESENT|MISMATCH") mutant_killed "$(( ${B_F2:-0} && ${B_mid:-0} ))" m10 "m10 (commit key instead of core/ tree key): F2 goes red — a docs-only move of <theirs> is refused and the consumer is wedged" ;;
    "$THEIRS_VER|GONE|NO")    bad "m10 SURVIVED: the docs-only near-miss still finished with \`:core\` removed from both sides, so F2 cannot tell a tree key from a commit key ($M10)" ;;
    *) bad "m10 produced a verdict this fixture does not recognise ($M10) — F2's kill is unearned" ;;
  esac
  M10O="$(mut_finish_id "$WORK/m10" "$OTHER")"
  if [ "$M10O" = "1.0.0|PRESENT|MISMATCH" ]; then
    ok "m10 and F1 stays green under it — a commit key still catches a genuinely different ref, which is exactly why F2 is the only arm that can see this"
  else
    bad "m10 also moved the offender ($M10O): F1 and F2 are entangled"
  fi
else
  bad "m10 did not apply — the guard no longer resolves \`\${_m_theirs}:core\` and \`\${THEIRS}:core\`, so this mutant proves nothing"
fi

# --- m11: over-broad — an UNCHECKED identity refuses too. Must die on F3. ----------------------
# The fix that looks stricter and is worse: a consumer whose marker was cleared by hand, which is
# the remedy `core/git-hooks/pre-push` prints, then has a refused push and no invocation that
# clears it. Widening is safe to assert here because the observable genuinely changes — an
# unchecked run stops stamping — so this is not the case where a widened guard prints what the
# original did.
if sed 's/elif \[ -n "$finish_id_mismatch" \]; then/elif [ -n "$finish_id_mismatch" ] || [ -n "$finish_id_note" ]; then/' "$REC/apply.sh" \
   | mut_apply "$WORK/m11"; then
  M11="$(mut_finish_id "$WORK/m11" "$OTHER" nomarker)"
  case "$M11" in
    "1.0.0|"*"|MISMATCH") mutant_killed "$(( ${B_F3:-0} && ${B_mid:-0} ))" m11 "m11 (unchecked treated as mismatched): F3 goes red — a consumer with no in-flight record can no longer finish at all" ;;
    "$OTHER_VER|GONE|NO") bad "m11 SURVIVED: the no-record run still stamped with the note folded into the refusal, so F3 is not reading the unchecked path ($M11)" ;;
    *) bad "m11 produced a verdict this fixture does not recognise ($M11) — F3's kill is unearned" ;;
  esac
  M11D="$(mut_finish_id "$WORK/m11" "$DOCS")"
  if [ "$M11D" = "$THEIRS_VER|GONE|NO" ]; then
    ok "m11 and F2 stays green under it — a run with a usable record is untouched, so F3 owns this case alone"
  else
    bad "m11 also moved the near-miss ($M11D): F2 and F3 are entangled"
  fi
else
  bad "m11 did not apply — the re-stamp no longer branches on \`elif [ -n \"\$finish_id_mismatch\" ]; then\`, so this mutant proves nothing"
fi

# --- m12: the union gate REPORTS a stale region instead of refusing it. Must die on U2. -------
# The gate's whole value is the refusal. A version that notices the mismatch and prints a row is
# indistinguishable from the shipped one on every arm except the one that reads the exit code and
# the stamp — which is what U2 does, and this proves it is what U2 does.
mut_union() { # mut_union <rec-dir> -> "<rc>|<ver>|<marker>"
  local rec="$1" c="$WORK/mu-$$-$RANDOM" out rc
  mut_copy "$MUT_UST" "$c" || { echo "BROKEN||"; return; }
  out="$(run_apply "$rec/apply.sh" "$c")"; rc=$?
  printf '%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" "$(marker "$c")"
}
# The same drive with a CURRENT report — U1's shape rather than U2's. A mutant that widened the
# gate's passing branch to accept every exit code produces the same verdict as one that widened it
# by exactly one, and this is the arm that separates them.
mut_union_current() { # mut_union_current <rec-dir> -> "<rc>|<ver>|<marker>"
  local rec="$1" c="$WORK/muc-$$-$RANDOM" out rc
  mut_copy "$MUT_UCUR" "$c" || { echo "BROKEN||"; return; }
  out="$(run_apply "$rec/apply.sh" "$c")"; rc=$?
  printf '%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" "$(marker "$c")"
}

if [ -d "$WORK/mut-ctl" ]; then
  UCTL="$(mut_union "$WORK/mut-ctl")"
  if [ "$UCTL" = "1|1.0.0|GONE" ]; then
    ok "CONTROL-m12 the unmutated copy refuses a stale region in a fresh directory, so m12's silence below is the mutation and not the copy"; B_mu=1
  else
    bad "CONTROL-m12 the unmutated copy did not refuse a stale region ($UCTL) — m12's verdict is unreadable"
  fi
fi

# BOTH refusal sites, deliberately: the gate diagnoses a post-apply re-run on one branch and a
# moved upstream on the other, and both refuse. The mutant is "the gate never refuses", so it has
# to disarm both spellings — a mutant that disarmed one would leave U2 carried by the other and
# read as a survivor for the wrong reason.
if sed 's|^        err "the report at |        say NOTE report-stale-ignored "" "|' "$REC/apply.sh" \
   | mut_apply "$WORK/m12"; then
  M12="$(mut_union "$WORK/m12")"
  case "$M12" in
    "0|$THEIRS_VER|GONE") mutant_killed "$(( ${B_U2:-0} && ${B_mu:-0} ))" m12 "m12 (gate reports instead of refusing): U2 goes red — a region rendered at another upstream applies and stamps, which is the defect the gate exists to stop" ;;
    "1|1.0.0|GONE")       bad "m12 SURVIVED: the apply still refused with the err() replaced by a row, so U2 is being carried by something other than that refusal ($M12)" ;;
    *)                    bad "m12 produced a verdict this fixture does not recognise ($M12) — it may have died for an unrelated reason, in which case U2's kill is unearned" ;;
  esac
  M12G="$(mut_stamp "$WORK/m12" green -)"
  if [ "${M12G%%|*}" = "$THEIRS_VER" ]; then
    ok "m12 and the clean path stays green under it — U2 and C3 are not entangled"
  else
    bad "m12 also moved the clean path ($M12G): the mutation was not confined to the union gate and its kill is unearned"
  fi
else
  bad "m12 did not apply — apply.sh no longer refuses a stale region with \`err \"the report at \`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# --- A1/A2: the resolved-blockers branch. Must die on U5, and on the two halves separately. ---
# THE TWO HALVES ARE THE POINT. U5 asserts a refusal AND a diagnosis, and those are different
# claims about the same run: A1 takes the diagnosis and leaves the refusal, A2 takes the refusal.
# A mutant killing both at once would leave either half free to be vacuous.
#
# A1 ANCHORS ON THE BRANCH CONDITION, NOT ON `err "the report at `. The three refusal sites open
# with byte-identical text — m12 edits all three deliberately — so a mutation keyed on that opener
# moves three cells and scores a kill this arm did not earn. The condition is what separates them.
#
# AND THE MESSAGE CONJUNCT IS KEYED ON THE REMEDY, NOT ON THE WORD `BLOCKERS-RESOLVED`. The
# generic refusal quotes --verify's own `cause:` line, which carries that word too, so an arm
# demanding only the word survives A1 and proves nothing. `apply: RE-APPROVAL OWED.` is printed
# by this branch alone (u5_score's REMEDY field).
if sed 's/^      elif \[ "$_ug_rc" -eq 3 \]; then$/      elif [ 1 -eq 0 ]; then/' "$REC/apply.sh" \
   | mut_apply "$WORK/a1"; then
  A1="$(mut_u5_score "$WORK/a1/apply.sh")"
  case "$A1" in
    "1|1.0.0|GONE|CAUSE|-|FWD") mutant_killed "$(( ${B_U5:-0} && ${B_mctl:-0} ))" A1 "A1 (the exit-3 branch disarmed): U5's DIAGNOSIS half goes red while the refusal AND the forwarded stderr stand — the remedy that closes the state the consumer filed is the one thing gone" ;;
    "1|1.0.0|GONE|CAUSE|REMEDY|"*) bad "A1 SURVIVED: the remedy was still printed with the exit-3 branch disarmed ($A1), so U5's message half is being carried by some other site" ;;
    *)                      bad "A1 moved more than the message ($A1, want 1|1.0.0|GONE|CAUSE|-|FWD) — the refusal or the forward changed too, so U5's three halves are entangled and one of them proves nothing on its own" ;;
  esac
  A1G="$(mut_stamp "$WORK/a1" green -)"
  if [ "${A1G%%|*}" = "$THEIRS_VER" ]; then
    ok "A1 and the clean path stays green under it — U5 and C3 are not entangled"
  else
    bad "A1 also moved the clean path ($A1G): the mutation was not confined to the union gate's exit-3 branch and its kill is unearned"
  fi
else
  bad "A1 did not apply — apply.sh no longer branches on \`elif [ \"\$_ug_rc\" -eq 3 ]; then\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# A2 IS THE WRONG FIX, NOT A REVERT: exit 3 read as a pass. It is the tempting one — the cause is
# the operator's own work, so waving it through looks like removing a wedge — and it authorises a
# write against a region nobody re-approved, where a resolution can leave rows the operator has
# not seen. U1 must stay green under it, or the arm is measuring the gate rather than the carve-out.
if sed 's/^    if \[ "$_ug_rc" -eq 0 \]; then$/    if [ "$_ug_rc" -eq 0 ] || [ "$_ug_rc" -eq 3 ]; then/' "$REC/apply.sh" \
   | mut_apply "$WORK/a2"; then
  A2="$(mut_u5_score "$WORK/a2/apply.sh")"
  case "$A2" in
    "0|$THEIRS_VER|GONE|"*) mutant_killed "$(( ${B_U5:-0} && ${B_mctl:-0} ))" A2 "A2 (exit 3 treated as a pass): U5's REFUSAL half goes red — the apply writes and stamps $THEIRS_VER over a region nobody re-approved, which is what the carve-out costs" ;;
    "1|1.0.0|GONE|"*)       bad "A2 SURVIVED: the apply still refused with exit 3 folded into the passing branch ($A2), so U5's rc/stamp half is being carried by something other than that branch" ;;
    *)                      bad "A2 produced a verdict this fixture does not recognise ($A2) — it may have died for an unrelated reason, in which case U5's kill is unearned" ;;
  esac
  # THE NEIGHBOURING ARM, in the same run. A mutation that widened the passing branch to accept
  # everything would also produce A2's verdict, and U1 is what separates the two.
  if [ -d "$WORK/a2" ]; then
    A2U1="$(mut_union_current "$WORK/a2")"
    if [ "$A2U1" = "0|$THEIRS_VER|GONE" ]; then
      ok "A2 and U1 stays green under it — a report that genuinely verifies still passes, so the mutation widened the branch by exactly one exit code and not to everything"
    else
      bad "A2 also moved the clean union-gate path ($A2U1): the mutation is not confined to exit 3 and its kill on U5 is unearned"
    fi
  fi
else
  bad "A2 did not apply — apply.sh no longer passes the union gate on \`if [ \"\$_ug_rc\" -eq 0 ]; then\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# A3: the forward deleted. THE MESSAGE SURVIVES IT INTACT, which is the whole reason this needs
# its own mutant: the refusal interpolates the cause TEXT and ends by telling the operator to read
# the diff, so with the forward gone every word of it still prints and the diff it points at does
# not exist. Only the FWD field records that. rc, the stamp and the marker must all hold, or the
# mutation reached the refusal instead of the forward.
if sed '/^      printf .%s\\n. "$_ug_verr" >&2$/d' "$REC/apply.sh" | mut_apply "$WORK/a3"; then
  A3="$(mut_u5_score "$WORK/a3/apply.sh")"
  case "$A3" in
    "1|1.0.0|GONE|CAUSE|REMEDY|-") mutant_killed "$(( ${B_U5:-0} && ${B_mctl:-0} ))" A3 "A3 (--verify's stderr not forwarded): U5's FORWARD half goes red alone — the refusal, the named cause and the remedy all still print, and the diff the last sentence sends the operator to is gone" ;;
    *"|FWD")                       bad "A3 SURVIVED: the cause line and the diff still reached stderr with the forward deleted ($A3), so U5's forward conjunct is being carried by something else" ;;
    *)                             bad "A3 moved more than the forward ($A3, want 1|1.0.0|GONE|CAUSE|REMEDY|-) — the refusal itself changed, so the forward conjunct's kill is unattributed" ;;
  esac
else
  bad "A3 did not apply — apply.sh no longer forwards --verify's stderr with \`printf '%s\\n' \"\$_ug_verr\" >&2\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# --- MR1/MR2: the recorded re-approval. Each built by an exact-once replace in a whole-dir copy. --
# MR1 drops the answer check: an unseen>0 region proceeds with no record. RA1 must move; RA0 (no
# record needed) and RA2 (a correct record) are the controls that must not. RA3-RA5 moving under
# MR1 is the same property, so they are not read here.
# MR2 matches a record regardless of its digest. RA3 must move; RA4 and RA5 (the label and the
# header conjuncts) must still refuse, and RA2 still proceed.
ra_mut() { # ra_mut <dir> <old> <new> -> 0 when the copy differs from the shipped apply.sh
  build_rec "$1" || return 1
  py_replace_once "$1/apply.sh" "$2" "$3" 2>/dev/null || return 1
  ! cmp -s "$REC/apply.sh" "$1/apply.sh"
}
if [ -n "$RA_SKIP" ]; then
  printf '  SKIP  MR1/MR2 -- %s\n' "$RA_SKIP"
else
  if [ -d "$WORK/mut-ctl" ]; then
    RC_CTL="$(mut_ra_drive "$WORK/mut-ctl/apply.sh" mctl "$MUT_U5" none)"
    if [ "$RC_CTL" = "$RA_STOP" ]; then
      ok "CONTROL-MR the unmutated copy refuses RA1's world in a fresh directory, so MR1's proceed below is the mutation and not the copy"; B_mr=1
    else
      bad "CONTROL-MR the unmutated copy did not refuse RA1's world ($RC_CTL) — MR1/MR2's verdicts are unreadable"
    fi
  fi
  if ra_mut "$WORK/mr1" '        elif ra_recorded "$_ra_hist" "$_ra_dg" "$_ra_lb"; then' '        elif true; then'; then
    M1_1="$(mut_ra_drive "$WORK/mr1/apply.sh" m1a1 "$MUT_U5" none)"
    M1_2="$(mut_ra_drive "$WORK/mr1/apply.sh" m1a2 "$MUT_U5" right)"
    if [ "$M1_1" = "$RA_GO" ] && [ "$M1_2" = "$RA_GO" ]; then
      mutant_killed "$(( ${B_RA1:-0} && ${B_mr:-0} ))" MR1 "MR1 (answer check dropped): RA1 goes red — an unseen region nobody re-approved is written — while RA2 holds"
    else
      bad "MR1 scored RA1=[$M1_1] RA2=[$M1_2], want RA1=$RA_GO with RA2 unchanged at $RA_GO — RA1 is carried by something other than the answer check, or the mutant moved the twin"
    fi
  else
    bad "MR1 did not apply — the exit-3 branch no longer reads \`elif ra_recorded \"\$_ra_hist\" \"\$_ra_dg\" \"\$_ra_lb\"; then\` exactly once. Re-anchor it."
  fi
  if ra_mut "$WORK/mr2" '{ if (alone($0, dg)) q = 1; next }' '{ q = 1; next }'; then
    M2_3="$(mut_ra_drive "$WORK/mr2/apply.sh" m2a3 "$MUT_U5" wrongdg)"
    M2_2="$(mut_ra_drive "$WORK/mr2/apply.sh" m2a2 "$MUT_U5" right)"
    if [ "$M2_3" = "$RA_GO" ] && [ "$M2_2" = "$RA_GO" ]; then
      mutant_killed "$(( ${B_RA3:-0} && ${B_mr:-0} ))" MR2 "MR2 (any record regardless of digest): RA3 goes red — a re-approval of another region passes — while RA2 holds"
    else
      bad "MR2 scored RA3=[$M2_3] RA2=[$M2_2], want RA3=$RA_GO, RA2=$RA_GO"
    fi
  else
    bad "MR2 did not apply — ra_recorded no longer carries \`{ if (alone(\$0, dg)) q = 1; next }\` exactly once. Re-anchor it."
  fi
fi

# --- MUT MUTANT-BY-ARM MATRIX: a re-measurement mode, never run per push ------------------------
# Every mut mutant and the unmutated copies scored on EVERY cell of units cf, u and mut's RA arms, one `MATRIX` row each
# (1 = the cell holds as on the shipped program, 0 = the mutant moved it). The row label is the id the kill site passes
# to mutant_killed. Each cell is driven from a fresh copy of its world, so a drive never reads a previous one's leftovers.
mut_cell() { # mut_cell <cell> <rec-dir> -> 0 when the cell holds
  local r="$2" o c
  case "$1" in
    C1)  [ "$(mut_stamp "$r" worklist -)" = "1.0.0|PRESENT|WITHHELD|OVERWRITTEN" ] ;;
    C3)  o="$(mut_stamp "$r" green -)"; [ "${o%%|*}" = "$THEIRS_VER" ] ;;
    C7)  o="$(mut_stamp "$r" decision -)"; case "$o" in "1.0.0|"*) true ;; *) false ;; esac ;;
    C4)  o="$(mut_stamp "$r" finished hrv --finish)"; [ "${o%%|*}" = "$THEIRS_VER" ] ;;
    C8)  o="$(mut_stamp "$r" finished - --finish)"; [ "${o%%|*}" = "$THEIRS_VER" ] ;;
    C5)  o="$(mut_stamp "$r" merged hrv --finish)"; case "$o" in "$THEIRS_VER|GONE|"*) true ;; *) false ;; esac ;;
    C6)  c="$WORK/mxc6-$$-$RANDOM"; mk_consumer "$c" worklist || return 1
         o="$(run_apply "$r/apply.sh" "$c")"; case "$(detail_of "$o" DECISION restamp-withheld)" in *--finish*) true ;; *) false ;; esac ;;
    F1)  [ "$(mut_finish_id "$r" "$OTHER")" = "1.0.0|PRESENT|MISMATCH" ] ;;
    F2)  [ "$(mut_finish_id "$r" "$DOCS")" = "$THEIRS_VER|GONE|NO" ] ;;
    F3)  o="$(mut_finish_id "$r" "$OTHER" nomarker)"; [ "$o" = "$OTHER_VER|GONE|NO" ] ;;
    U1)  [ "$(mut_union_current "$r")" = "0|$THEIRS_VER|GONE" ] ;;
    U2)  [ "$(mut_union "$r")" = "1|1.0.0|GONE" ] ;;
    U5)  [ "$(mut_u5_score "$r/apply.sh")" = "1|1.0.0|GONE|CAUSE|REMEDY|FWD" ] ;;
    RA1) [ "$(mut_ra_drive "$r/apply.sh" mx1 "$MUT_U5" none)" = "$RA_STOP" ] ;;
    RA2) [ "$(mut_ra_drive "$r/apply.sh" mx2 "$MUT_U5" right)" = "$RA_GO" ] ;;
    RA3) [ "$(mut_ra_drive "$r/apply.sh" mx3 "$MUT_U5" wrongdg)" = "$RA_STOP" ] ;;
    *)   false ;;
  esac
}
if [ "$MATRIX" = 1 ]; then
  MX_CELLS=$((MX_CELLS + 1))
  MUT_CELLS="C1 C3 C4 C5 C6 C7 C8 F1 F2 F3 U1 U2 U5 RA1 RA2 RA3"
  echo "MATRIX-BEGIN mut cells=$MUT_CELLS"
  # <id>:<dir> pairs. The four controls are unmutated copies; CONTROL-id has its own copy, the others share mut-ctl.
  for _mp in CONTROL:mut-ctl CONTROL-id:mut-id-ctl CONTROL-m12:mut-ctl CONTROL-MR:mut-ctl \
             m1:m1 m2:m2 m3:m3 m4:m4 m5:m5 m6:m6 m7:m7 m8:m8 m9:m9 m10:m10 m11:m11 m12:m12 A1:a1 A2:a2 A3:a3 MR1:mr1 MR2:mr2; do
    _id="${_mp%%:*}"; _dir="$WORK/${_mp#*:}"
    if [ ! -f "$_dir/apply.sh" ]; then bad "MATRIX mut $_id: no staged copy at ${_dir}, so its row cannot be measured"; continue; fi
    _row="MATRIX $_id"
    for _c in $MUT_CELLS; do
      case "$_c" in RA*) [ -n "$RA_SKIP" ] && { _row="$_row $_c=-"; continue; } ;; esac
      if mut_cell "$_c" "$_dir"; then _row="$_row $_c=1"; else _row="$_row $_c=0"; fi
    done
    echo "$_row"
  done
  echo "MATRIX-END mut"
fi

fi  # ---- end of unit mut

if sg t; then
# --- T1-T4: transient_ignore_row() DISCRIMINATES, on the two states where a wrong row does not --
#
# WHY HERE AND NOT IN transient-ignore-block. That fixture's subject is the RENDERER; this one
# drives `apply.sh`, and the row is apply.sh's. The row shipped in 0.545.0 with a scratch probe
# behind it and no committed seed, and an adversary then built FOUR wrong implementations that
# passed every state that probe seeded. Two of the four are live defects, and both are killed by
# ONE state each that the probe never built. Those two states are seeded here.
#
# T1/T2 -- THE RENDERER EXITS 2. `sync-transient-ignore.sh` has six `exit 2` paths (an unresolvable
# declaration, an empty block marker, no jq, a declaration with no transient half). The row must
# call that UNREADABLE, because "the check could not run" and "the block is stale" are different
# facts with different remedies: re-rendering an unresolvable declaration does nothing, and a
# WORKLIST row saying "re-render it" sends the operator to a tool that will exit 2 again. A row
# written `!= "0"` instead of `= "1"` collapses the two, lands in the wrong hand-back bucket, and
# passes every other seed. That is the same distinction hook_registration_row() draws one function
# above, which is why the row is shaped like it.
#
# T3/T4 -- THE MARKER IS ON DISK AND UNTRACKED, BLOCK CURRENT. This is the ORDINARY mid-pipeline
# state: transient files exist on disk constantly and being untracked is exactly correct. The row
# must be SILENT. A row testing `[ -e ]` on the worktree instead of asking the INDEX fires here on
# every healthy consumer -- and a row that wedges a correct pull is worse than the defect it
# reports. The property is "git is tracking it", which only `ls-files` answers.
#
# BOTH ARMS ARE PRESENCE/ABSENCE PAIRS ON ONE INPUT, one property apart, so neither can pass by
# reporting everything or by reporting nothing.
# THE STAGING HELPERS THE ROW CALLS ARE EXTRACTED BESIDE IT, from the same apply.sh: the row reads its
# pattern list from a staged file, and an extraction without them reads as "nothing tracked" (T5).
# THE SEAM IS GUARDED BEFORE IT IS DRIVEN. Each function is cut out of $APPLY -- the subject this
# file resolves and every other arm drives -- and an extraction that is EMPTY, or whose first line is
# not that function's own header, would run a `bash -c` holding no row at all. Every T arm would
# then read `-NONE-`, which is T3's PASS. So a lost extraction is FIXTURE BROKEN, exit 2, here.
ti_seam_guard() {
  local fn x
  for fn in ap_stage ap_staging_refused ap_stage_or_refuse transient_ignore_row; do
    x="$(sed -n "/^${fn}() {/,/^}\$/p" "$APPLY")"
    # First and last line by parameter expansion: the hermetic sandbox declares no `tail`.
    if [ -z "$x" ] || [ "${x%%$'\n'*}" != "${fn}() {" ] || [ "${x##*$'\n'}" != "}" ]; then
      echo "$NAME: FIXTURE BROKEN — the T seam extracted nothing usable for ${fn}() from $APPLY (empty, wrong header, or unterminated); every T arm would score an empty row as silence" >&2
      exit 2
    fi
  done
}
ti_helpers() {
  printf 'AP_TMP="$(mktemp -d "%s/ti-stage.XXXXXX")"; ap_stage_dead=0; FINISH=0; mech_fail=0\n' "$WORK"
  sed -n -e '/^ap_stage() {/,/^}$/p' -e '/^ap_staging_refused() {/,/^}$/p' -e '/^ap_stage_or_refuse() {/,/^}$/p' "$APPLY"
}
ti_row_out() { # <consumer> -> the row types this consumer draws, or -NONE-
  local c="$1" out
  out="$( CONSUMER="$c" DIST="$DIST" bash -c '
    handback=0; worklist_n=0
    say() { printf "%s|%s\n" "$1" "$2"; }
    '"$(ti_helpers)"'
    '"$(sed -n '/^transient_ignore_row() {/,/^}$/p' "$APPLY")"'
    transient_ignore_row' 2>/dev/null | tr '\n' ' ' )"
  printf '%s' "${out:--NONE-}"
}
ti_row_text() { # <consumer> -> the row's PROSE, for the arms that discriminate on diagnosis
  local c="$1"
  CONSUMER="$c" DIST="$DIST" bash -c '
    handback=0; worklist_n=0
    say() { printf "%s\n" "${4:-}"; }
    '"$(ti_helpers)"'
    '"$(sed -n '/^transient_ignore_row() {/,/^}$/p' "$APPLY")"'
    transient_ignore_row' 2>/dev/null | tr '\n' ' '
}
mk_ti_consumer() { # <dir> <render yes|no> <ondisk yes|no> <tracked yes|no> <break yes|no>
  local c="$1" rnd="$2" od="$3" tr_="$4" brk="$5"
  mkdir -p "$c/scripts/ai-dlc" "$c/.claude/schemas" "$c/_bmad-output" || return 1
  git -C "$c" init -q . 2>/dev/null || return 1
  git -C "$c" config user.email t@t; git -C "$c" config user.name t
  cp "$TI_SCHEMA"   "$c/.claude/schemas/pipeline-state-paths.json" || return 1
  cp "$TI_RENDERER" "$c/scripts/ai-dlc/sync-transient-ignore.sh"   || return 1
  printf 'node_modules/\n' > "$c/.gitignore"
  git -C "$c" add -A >/dev/null 2>&1; git -C "$c" commit -qm base >/dev/null 2>&1
  [ "$rnd" = yes ] && bash "$c/scripts/ai-dlc/sync-transient-ignore.sh" --root "$c" >/dev/null 2>&1
  [ "$od"  = yes ] && : > "$c/_bmad-output/.handoff-in-progress"
  if [ "$tr_" = yes ]; then
    git -C "$c" add -f _bmad-output/.handoff-in-progress >/dev/null 2>&1
    git -C "$c" commit -qm tracked >/dev/null 2>&1
  fi
  # An EMPTY block marker: the renderer refuses rather than guessing, and exits 2.
  if [ "$brk" = yes ]; then
    sed -i.bak 's/"block_begin": "[^"]*"/"block_begin": ""/' "$c/.claude/schemas/pipeline-state-paths.json"
    rm -f "$c/.claude/schemas/pipeline-state-paths.json.bak"
  fi
  git -C "$c" add -A >/dev/null 2>&1; git -C "$c" commit -qm state >/dev/null 2>&1
  return 0
}

REPO="$(cd "$(dirname "$APPLY")/../../../.." && pwd)"
TI_RENDERER=""; TI_SCHEMA=""
for cand in "$REPO/core/scripts/sync-transient-ignore.sh" "$REPO/scripts/ai-dlc/sync-transient-ignore.sh"; do
  [ -f "$cand" ] && TI_RENDERER="$cand" && break
done
for cand in "$REPO/core/schemas/pipeline-state-paths.json" "$REPO/.claude/schemas/pipeline-state-paths.json"; do
  [ -f "$cand" ] && TI_SCHEMA="$cand" && break
done
if [ -z "$TI_RENDERER" ] || [ -z "$TI_SCHEMA" ]; then
  # A core fixture ships AHEAD of its subject: say so rather than printing a green line.
  ok "T1-T4 skipped: sync-transient-ignore.sh / pipeline-state-paths.json are not in this tree, so the row's inputs cannot be built"
else
  [ -f "$TI_RENDERER" ] && echo "HERMETIC-CONSUMED $TI_RENDERER"
  [ -f "$TI_SCHEMA" ] && echo "HERMETIC-CONSUMED $TI_SCHEMA"
  ti_seam_guard
  TI_UNREADABLE="$WORK/ti-unreadable"; TI_ONDISK="$WORK/ti-ondisk"; TI_TRACKED="$WORK/ti-tracked"
  if mk_ti_consumer "$TI_UNREADABLE" yes no no yes && mk_ti_consumer "$TI_ONDISK" yes yes no no \
     && mk_ti_consumer "$TI_TRACKED" yes yes yes no; then
    T_UNREAD="$(ti_row_out "$TI_UNREADABLE")"
    T_DISK="$(ti_row_out "$TI_ONDISK")"
    T_TRACK="$(ti_row_out "$TI_TRACKED")"

    # T0 -- the seeds DISCRIMINATE, keyed on the pair NO arm below owns.
    #
    # IT ASSERTS unreadable != tracked AND NOT unreadable/on-disk/tracked ALL-DIFFER, and the
    # narrowing is deliberate. The wider form ALSO fires on the worktree-test mutant -- which
    # collapses on-disk into tracked, exactly what T4 exists to catch -- so two arms went red on
    # one input and the harness could not say which was load-bearing. A setup arm must not overlap
    # the behaviour arms it introduces: these two worlds differ under every implementation that
    # reads the schema at all, so T0 fails only when the SEEDS are broken, which is its whole job.
    if [ "$T_UNREAD" != "$T_TRACK" ]; then
      ok "T0 setup: the unreadable and the tracked consumer draw different answers, so the arms below are reading more than one world"
    else
      bad "T0 setup: the unreadable and the tracked consumer both drew '$T_UNREAD' — the seeds do not separate and every verdict below is about one world"
    fi

    case "$T_UNREAD" in
      *"DECISION|transient-ignore-unreadable"*)
        ok "T1 a renderer that exits 2 is reported UNREADABLE, not as a stale block — re-rendering an unresolvable declaration is not the remedy" ;;
      *"WORKLIST|transient-ignore"*)
        bad "T2 the row told the operator to RE-RENDER a consumer whose declaration cannot be resolved at all ($T_UNREAD). \`--check\` exited 2, not 1; those are different facts with different remedies, and this row lands in the WORKLIST hand-back bucket where a DECISION is owed" ;;
      *) bad "T1 a consumer whose renderer exits 2 drew '$T_UNREAD' — neither the unreadable DECISION nor the stale WORKLIST, so the rc branches are not reached at all" ;;
    esac

    case "$T_DISK" in
      "-NONE-")
        ok "T3 a transient path present ON DISK and untracked, with the block current, draws NO row — the ordinary mid-pipeline state of every healthy consumer" ;;
      *) bad "T4 the row fired on a consumer that is CORRECT ($T_DISK): the marker is on disk and untracked, which is exactly what a transient path should be. The property is whether git TRACKS it, which only \`ls-files\` answers; a worktree test flags every healthy consumer on every pull" ;;
    esac

    case "$T_TRACK" in
      *"WORKLIST|transient-ignore-tracked"*)
        ok "T5 the same path, TRACKED, does draw the row — so T3's silence is discrimination and not a row that never fires" ;;
      *) bad "T5 a TRACKED transient path drew '$T_TRACK' — the arm T3 relies on cannot fire, so T3's silence proves nothing" ;;
    esac

    # T8 -- THE ROW REPORTS THE TRANSIENT HALF AND NOT THE WHOLE DECLARATION, PROVED ON A SCHEMA
    # THAT CAN TELL THE DIFFERENCE.
    #
    # `select(.transient)` in the row's jq is UNPROVABLE against the shipped declaration: today no
    # DURABLE entry carries an `ignore` key (control below), so dropping the filter changes nothing
    # and a mutant of it survives for a reason that has nothing to do with the predicate. That is a
    # loaded gun in `mechanism-design.md`'s sense -- the conjunct changes no outcome now and will
    # change one the day a durable entry gains an ignore pattern, with nobody looking.
    #
    # SO THE WORLD IS SYNTHESISED, exactly as `transient-ignore-block`'s own `renders-durable-too`
    # mutant synthesises a durable pattern rather than waiting for the schema to grow one. A durable
    # entry here gets an `ignore`, and the row must still report ONLY the transient set: a durable
    # path is a pipeline ARTIFACT the consumer is supposed to commit, and naming it as scratch state
    # to untrack is the one direction of this row that could cost a consumer real work.
    #
    # The arm is keyed on the tracked DURABLE path being ABSENT from the row's text while the
    # tracked TRANSIENT one is PRESENT -- both in the same world, one property apart, so it cannot
    # pass by reporting everything or by reporting nothing.
    #
    # THE WORLD IS T5's, REUSED AND NOT REBUILT. It was a second `mk_ti_consumer ... yes yes yes no`,
    # the identical builder call T5's consumer came from, so the two were one state built twice. T5
    # has already read T_TRACK off it above, and nothing below reads TI_TRACKED again, so mutating
    # its schema here moves no other arm. The `.git` test keeps the setup arm reachable.
    TI_DUR="$TI_TRACKED"
    if [ -d "$TI_DUR/.git" ] && [ -n "$T_TRACK" ]; then
      ti_dur_name="$(jq -r '[.paths[] | select(.transient|not)][0].name // empty' \
                       "$TI_DUR/.claude/schemas/pipeline-state-paths.json" 2>/dev/null)"
      ti_dur_root="$(jq -r '.root // empty' "$TI_DUR/.claude/schemas/pipeline-state-paths.json" 2>/dev/null)"
      if [ -z "$ti_dur_name" ] || [ -z "$ti_dur_root" ]; then
        bad "T8 setup: the declaration yields no durable entry to synthesise against, so this arm cannot discriminate"
      else
        # Give that durable entry an ignore pattern, and TRACK a file at its path.
        ti_tmp="$TI_DUR/.claude/schemas/pipeline-state-paths.json"
        jq --arg n "$ti_dur_name" --arg r "$ti_dur_root" \
           '(.paths[] | select(.name == $n) | .ignore) = ($r + "/" + $n)' "$ti_tmp" > "$ti_tmp.new" \
          && mv "$ti_tmp.new" "$ti_tmp"
        mkdir -p "$(dirname "$TI_DUR/${ti_dur_root}/${ti_dur_name}")" 2>/dev/null
        printf 'durable artifact\n' > "$TI_DUR/${ti_dur_root}/${ti_dur_name}"
        git -C "$TI_DUR" add -f "${ti_dur_root}/${ti_dur_name}" >/dev/null 2>&1
        git -C "$TI_DUR" commit -qm durable >/dev/null 2>&1
        ti_dur_n="$(jq '[.paths[] | select(.transient|not) | select(.ignore != null)] | length' "$ti_tmp" 2>/dev/null)"
        ti_dur_tracked="$(git -C "$TI_DUR" ls-files -- "${ti_dur_root}/${ti_dur_name}" | wc -l | tr -d ' ')"
        # THE TWO PREDICATES MUST ACTUALLY DIFFER ON THIS WORLD, ASSERTED AND NEVER ASSUMED.
        # Both counts are DERIVED here rather than written down: the transient set grows whenever a
        # path is declared, so a quoted figure would go stale and the arm would start comparing a
        # live tree against a remembered one. What must hold is the RELATION -- the filtered set is
        # strictly smaller than the unfiltered one. Without this, a schema in which the synthesised
        # durable entry collided with something already carrying an `ignore` would leave the two
        # predicates agreeing, and T8 would pass while testing nothing.
        ti_sel="$(jq -r '[.paths[] | select(.transient) | .ignore // empty] | length' "$ti_tmp" 2>/dev/null)"
        ti_all="$(jq -r '[.paths[] | .ignore // empty] | length' "$ti_tmp" 2>/dev/null)"
        if [ "${ti_dur_n:-0}" -lt 1 ] || [ "${ti_dur_tracked:-0}" -lt 1 ]; then
          bad "T8 setup: seeded a durable entry with an ignore ($ti_dur_n) tracked at its path ($ti_dur_tracked) and one of them did not take — the world cannot separate the two halves of the declaration"
        elif [ "${ti_sel:-0}" -ge "${ti_all:-0}" ]; then
          bad "T8 setup: the filtered and unfiltered predicates yield ${ti_sel} and ${ti_all} patterns — they do not SEPARATE on this world, so a row with \`select(.transient)\` and one without it read the same set and this arm cannot discriminate"
        else
          D_TXT="$(ti_row_text "$TI_DUR")"
          case "$D_TXT" in
            *"${ti_dur_root}/${ti_dur_name}"*)
              bad "T8 the row named the DURABLE path '${ti_dur_root}/${ti_dur_name}' as transient state to untrack. That path is a pipeline artifact the consumer is supposed to commit, and this row is telling them to \`git rm --cached\` it — the one direction of this arm that costs a consumer real work" ;;
            *".handoff-in-progress"*)
              ok "T8 with a durable entry carrying an ignore pattern, the row reports the TRANSIENT tracked path and NOT the durable one — \`select(.transient)\` is load-bearing on a declaration that can tell them apart" ;;
            *)
              bad "T8 the row named neither path in a world where a transient one IS tracked ('$(printf '%s' "$D_TXT" | cut -c1-70)') — the arm cannot discriminate because nothing fired" ;;
          esac
        fi
      fi
    else
      bad "T8 setup: could not build the durable-entry consumer"
    fi

    # T6/T7 -- NEVER-RENDERED AND DRIFTED ARE DIFFERENT DIAGNOSES, AND THE ROW MUST SAY WHICH.
    # `--check` exits 1 for both and distinguishes them in its text. A row that flattens them tells
    # a consumer whose block was never written that something "no longer matches" — a wrong cause,
    # in the only channel the operator reads, sending them after a declaration change that never
    # happened. Keyed on the row's PROSE and not on its type, because both are the same row type;
    # the type is what an earlier revision got right while the diagnosis was wrong.
    TI_NEVER="$WORK/ti-never"; TI_DRIFT="$WORK/ti-drift"
    if mk_ti_consumer "$TI_NEVER" no no no no && mk_ti_consumer "$TI_DRIFT" yes no no no; then
      # Drift the rendered block by deleting one pattern, leaving the markers in place.
      sed -i.bak '/handoff-in-progress/d' "$TI_DRIFT/.gitignore"; rm -f "$TI_DRIFT/.gitignore.bak"
      git -C "$TI_DRIFT" add -A >/dev/null 2>&1; git -C "$TI_DRIFT" commit -qm drift >/dev/null 2>&1
      N_TXT="$(ti_row_text "$TI_NEVER")"; D_TXT="$(ti_row_text "$TI_DRIFT")"
      if [ "$N_TXT" = "$D_TXT" ]; then
        bad "T6 a never-rendered consumer and a drifted one drew the SAME text — the row is flattening two causes that \`--check\` separates, and one of the two diagnoses is therefore wrong"
      else
        case "$N_TXT" in
          *"NEVER had a transient-state ignore block"*)
            ok "T6 a consumer whose block was never written is told so, rather than that something 'no longer matches' a declaration nothing changed" ;;
          *) bad "T6 a never-rendered consumer drew '$(printf '%s' "$N_TXT" | cut -c1-90)' — it must name the absence, not a mismatch" ;;
        esac
        case "$D_TXT" in
          *"no longer matches the declaration"*)
            ok "T7 a consumer whose block DRIFTED is told that, so T6's wording is a diagnosis and not the only sentence the row can say" ;;
          *) bad "T7 a drifted consumer drew '$(printf '%s' "$D_TXT" | cut -c1-90)' — T6 cannot be read as discrimination if this one does not say mismatch" ;;
        esac
      fi
    else
      bad "T6/T7 setup: could not build the never-rendered and drifted consumers"
    fi
  else
    bad "T1-T5 setup: could not build the transient-ignore consumers, so the row was never driven"
  fi
fi

fi  # ---- end of unit t

if sg bl; then
# ==============================================================================================
# BL-276 -- THE TWO ROUTING ROWS, AND THE SITING THAT KEEPS THE FINISHER ABLE TO EXIT
# ==============================================================================================
#
# WHAT IS BOUND HERE. `retired-layer-passage.sh` detects a consumer layer file still carrying a
# rulebook line core had at base and no longer has at theirs; its rows reached the REPORT and
# nothing else, while the sibling TOKEN class has been a worklist row since the `*CLASSIFY*` arm
# gained `retired-tokens.sh`. The same asymmetry one population over: a planning artifact whose
# ```derived fence EXECUTES a core path gets no row when a release re-sites the text that path
# carried. Both are now `say` sites inside apply.sh's `FINISH=0` span.
#
# WHY THESE ARMS LIVE IN THIS FIXTURE AND NOT IN A NEW ONE. The rows' load-bearing property is
# WHICH COUNTER they raise and WHEN -- `say` increments `handback` and `worklist_n`, `--finish`
# gates its stamp on `worklist_n` alone, and a row re-derived beside `hook_registration_row`
# would withhold the stamp on a tree `--finish` cannot change. That is this file's whole subject;
# C1/C4/C7/C8 and m8 already separate the two counters, `mk_consumer` already builds a consumer
# whose stamp and marker are read, and `run_apply`/`run_finish_as` already drive the unstubbed
# script in both modes. An arm asserting a row's SITING needs the stamp and the marker in the
# same verdict, and this is the only fixture that reads them.
#
# ITS OWN DIST, AND THAT IS NOT A CONVENIENCE. The pull above moves `core/session-driver/*` and
# `core/fixtures/*`; neither row can fire against it -- the passage detector diffs only the
# `rulebook:` globs from `setup-sites.md`, and nothing under those globs moves there. Seeding a
# retired rulebook LINE into the dist above would change what every arm from C1 down classifies.
# So these worlds get a second two-commit repository whose only change is one deleted rulebook
# line, and the arms above are untouched by it.
#
# COST. The passage detector is nearly free when it has nothing to compare -- it exits before
# opening a layer file -- and the expensive shape is a large removed-line set against a large
# layer corpus. These worlds carry ONE removed line and at most one layer file, which is why the
# whole block below runs in a couple of seconds rather than in the tens the reference consumer's
# 52-file corpus costs.
BLROOT="$WORK/bl276"
PD="$BLROOT/dist"
BL_OK=1
mkdir -p "$PD/core/skills/ai-dlc" "$PD/core/scripts" || BL_OK=0
if [ "$BL_OK" = 1 ]; then
  git -C "$PD" init -q 2>/dev/null || BL_OK=0
fi
pgitc() { git -C "$PD" -c user.email=f@f -c user.name=fixture "$@"; }

# THE RETIRED LINE AND ITS NEAR-MISS, AND THE NEAR-MISS CARRIES EVERY PROPERTY THE OFFENDER DOES
# EXCEPT THE ONE UNDER TEST. Both are ordinary rulebook prose, both are reproduced by a layer
# file under the same numbering and emphasis, both are inside the `rulebook:` globs. They differ
# in one thing: the offender reproduces the deleted line and the near-miss PARAPHRASES it, which
# is exactly the limit `retired-layer-passage.sh`'s own header states it cannot cross. A
# near-miss that simply omitted the line would discriminate against nothing.
BL_RETIRED='Every override entry must declare a shadows anchor before it is adopted'
BL_KEPT='An extension entry declares conforms_to and is never adopted by absorption'
BL_PARA='An override entry needs a declared shadow anchor prior to adoption'

if [ "$BL_OK" = 1 ]; then
  printf '1.0.0\n' > "$PD/VERSION"
  { printf '# AI/DLC\n\n'
    printf -- '- %s\n' "$BL_RETIRED"
    printf -- '- %s\n' "$BL_KEPT"
  } > "$PD/core/skills/ai-dlc/SKILL.md"
  # A REAL DISTRIBUTION SHIPS CORE VALIDATORS, and apply.sh withholds its re-stamp as
  # manifest-unreadable when `core/scripts/` expands empty at THEIRS. Without this the finish
  # arm below would pass for a reason that has nothing to do with the rows.
  printf '#!/usr/bin/env bash\necho v\n' > "$PD/core/scripts/validate-synthetic.sh"
  # THE SCOPE CLASSIFIER IS IN THE DIST AT BASE AND THEREFORE AT THEIRS, UNCHANGED. vd_join reads
  # check-owed-derivations.sh, sprint-status.sh and sprint-status.json out of the distribution at
  # THEIRS to decide which artifact files belong to the current sprint; a dist carrying none draws
  # DECISION artifact-derivations-unscoped instead of the row BL-1 asserts. Seeded in the BASE
  # commit so the three stay out of the moved set (BL-S1 still sees only SKILL.md change). The real
  # files are copied, never a stand-in: a stub classifier would score nothing about the scoping.
  BL_REPO="$(cd "$(dirname "$APPLY")/../../../.." && pwd)"
  BL_CLS_SH=""; BL_CLS_SS=""; BL_CLS_SCH=""
  for cand in "$BL_REPO/core/scripts/check-owed-derivations.sh" "$BL_REPO/scripts/ai-dlc/check-owed-derivations.sh"; do
    [ -f "$cand" ] && BL_CLS_SH="$cand" && break
  done
  for cand in "$BL_REPO/core/scripts/sprint-status.sh" "$BL_REPO/scripts/ai-dlc/sprint-status.sh"; do
    [ -f "$cand" ] && BL_CLS_SS="$cand" && break
  done
  for cand in "$BL_REPO/core/schemas/sprint-status.json" "$BL_REPO/.claude/schemas/sprint-status.json"; do
    [ -f "$cand" ] && BL_CLS_SCH="$cand" && break
  done
  if [ -n "$BL_CLS_SH" ] && [ -n "$BL_CLS_SS" ] && [ -n "$BL_CLS_SCH" ]; then
    echo "HERMETIC-CONSUMED $BL_CLS_SH"
    echo "HERMETIC-CONSUMED $BL_CLS_SS"
    echo "HERMETIC-CONSUMED $BL_CLS_SCH"
    mkdir -p "$PD/core/schemas" || BL_OK=0
    cp -p "$BL_CLS_SH" "$PD/core/scripts/check-owed-derivations.sh" || BL_OK=0
    cp -p "$BL_CLS_SS" "$PD/core/scripts/sprint-status.sh" || BL_OK=0
    cp -p "$BL_CLS_SCH" "$PD/core/schemas/sprint-status.json" || BL_OK=0
  fi
  pgitc add -A >/dev/null 2>&1 && pgitc commit -q -m bl276-base >/dev/null 2>&1 || BL_OK=0
fi
BL_BASE=""; BL_THEIRS=""; BL_THEIRS_VER=""
if [ "$BL_OK" = 1 ]; then
  BL_BASE="$(git -C "$PD" rev-parse HEAD)"
  printf '2.0.0\n' > "$PD/VERSION"
  { printf '# AI/DLC\n\n'
    printf -- '- %s\n' "$BL_KEPT"
  } > "$PD/core/skills/ai-dlc/SKILL.md"
  pgitc add -A >/dev/null 2>&1 && pgitc commit -q -m bl276-theirs >/dev/null 2>&1 || BL_OK=0
  BL_THEIRS="$(git -C "$PD" rev-parse HEAD)"
  BL_THEIRS_VER="$(git -C "$PD" show "${BL_THEIRS}:VERSION" 2>/dev/null)"
fi

# The two consumer-relative paths a `derived` fence can name. One is the mapping of a core path
# this range CHANGED; the other is a core path it did not touch. `map_consumer` is what apply.sh
# uses, so these are written as that mapper emits them.
BL_CHANGED_CONS=".claude/skills/ai-dlc/SKILL.md"
BL_UNCHANGED_CONS="scripts/ai-dlc/validate-synthetic.sh"

# bl_consumer <dir> <layer:hit|miss|none> <deriv:hit|miss|empty|hitzero|past|cur|none> <validator:yes|no>
#
# EVERY WORLD IS DEFINED WHOLE, INCLUDING WHAT IT DOES NOT WRITE. A builder that leaves the
# previous world's layer file or artifact behind hands the next arm a shape nobody seeded, and
# the resulting two-cell flip reads as entanglement between arms that are in fact independent.
bl_consumer() {
  local c="$1" layer="$2" deriv="$3" val="$4"
  rm -rf "$c" || return 1
  mkdir -p "$c/.claude" "$c/scripts/ai-dlc" || return 1
  # hook-registration validator present in every world: without it apply.sh emits
  # `DECISION hook-registration-unchecked` BEFORE the stamp under `--finish`, and the finish arm
  # below would then be reading that row's effect rather than the two rows under test.
  printf '#!/usr/bin/env bash\nexit 0\n' > "$c/scripts/ai-dlc/validate-hook-registration.sh"
  chmod +x "$c/scripts/ai-dlc/validate-hook-registration.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-synthetic.sh"
  case "$layer" in
    hit)  mkdir -p "$c/.claude/skills/ai-dlc/overrides" || return 1
          printf '# override\n\n3. **%s**\n' "$BL_RETIRED" \
            > "$c/.claude/skills/ai-dlc/overrides/steps__w__x.md" ;;
    miss) mkdir -p "$c/.claude/skills/ai-dlc/overrides" || return 1
          printf '# override\n\n3. **%s**\n' "$BL_PARA" \
            > "$c/.claude/skills/ai-dlc/overrides/steps__w__x.md" ;;
    none) : ;;
  esac
  case "$deriv" in
    hit)  mkdir -p "$c/_bmad-output/planning" || return 1
          printf '# plan\n\n```derived\n$ grep -c shadow %s\n3\n```\n' "$BL_CHANGED_CONS" \
            > "$c/_bmad-output/planning/plan.md" ;;
    # THE NEAR-MISS CARRIES EVERY PROPERTY THE OFFENDER KEYS ON EXCEPT ONE, TWICE OVER. Its
    # FENCED command names a core path this range did NOT change; and the changed path DOES
    # appear, in a line spelled exactly as the offender's is — leading `$ `, same command — but
    # OUTSIDE any fence. A near-miss whose unfenced line did not carry the `$ ` prefix would
    # discriminate against nothing that keys on the fence, because the prefix test alone would
    # already reject it. BL-m5 is the mutant that proves this half is load-bearing.
    miss) mkdir -p "$c/_bmad-output/planning" || return 1
          { printf '# plan\n\n```derived\n$ grep -c echo %s\n1\n```\n' "$BL_UNCHANGED_CONS"
            printf '\nQuoted below as prose, deliberately not inside a fence:\n\n'
            printf '$ grep -c shadow %s\n' "$BL_CHANGED_CONS"
          } > "$c/_bmad-output/planning/plan.md" ;;
    empty) mkdir -p "$c/_bmad-output" || return 1 ;;
    # The firing artifact plus a ZERO-BYTE markdown file beside it. An empty file has no first
    # record, so a scan counting `FNR == 1` as "opened" scores it unread and the corpus reads as
    # partly unreadable; it is readable, and the WORKLIST row must still be drawn.
    hitzero) mkdir -p "$c/_bmad-output/planning" || return 1
          printf '# plan\n\n```derived\n$ grep -c shadow %s\n3\n```\n' "$BL_CHANGED_CONS" \
            > "$c/_bmad-output/planning/plan.md"
          : > "$c/_bmad-output/empty-log.md" ;;
    # BL-631: the SAME firing fence, in a slotted directory, beside a canonical sprint-status.yaml
    # reading `sprint: 1` / `status: in_progress`. `past` is s0/ (a past sprint's artifact: the
    # classifier calls it PAST and the row must not exist at all); `cur` is s1/ (the current sprint:
    # CURRENT, and the WORKLIST row must be drawn), so the two differ in the slot and nothing else.
    past|cur) { [ "$deriv" = past ] && _bs=s0 || _bs=s1
          mkdir -p "$c/_bmad-output/planning-artifacts/$_bs" "$c/_bmad-output/implementation-artifacts" || return 1
          printf 'sprint: 1\nstatus: in_progress\n' > "$c/_bmad-output/implementation-artifacts/sprint-status.yaml"
          printf '# old\n\n```derived\n$ grep -c shadow %s\n3\n```\n' "$BL_CHANGED_CONS" \
            > "$c/_bmad-output/planning-artifacts/$_bs/old.md"; } ;;
    none)  : ;;
  esac
  if [ "$val" = yes ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
    chmod +x "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
  fi
  printf 'version: 1.0.0\ncommit: %s\n' "$BL_BASE" > "$c/.claude/.ai-dlc-version"
  rm -f "$c/.claude/.ai-dlc-applying"
}

# BL_DRIVE_THEIRS, when set, replaces the THEIRS ref (BL-6b drives a commit that has lost the classifier).
bl_drive() { # bl_drive <apply-path> <consumer> [flag...]
  local a="$1" c="$2"; shift 2
  bash "$a" "$@" "$PD" "$BL_BASE" "$c" "${BL_DRIVE_THEIRS:-$BL_THEIRS}" 2>/dev/null
}
bl_n() { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {n++} END {print n+0}' <<< "$1"; }
# The four observables every world below is read through, as one string. WORKLIST-vs-DECISION is
# the distinction that decides whether `--finish` can exit, so it is in the vector rather than
# collapsed into a hit count.
bl_vec() { # bl_vec <out> -> "row1|wl2|unreadable|unchecked"
  printf '%s|%s|%s|%s' \
    "$(bl_n "$1" WORKLIST retired-layer-passage)" \
    "$(bl_n "$1" WORKLIST artifact-derivations)" \
    "$(bl_n "$1" DECISION artifact-derivations-unreadable)" \
    "$(bl_n "$1" DECISION artifact-derivations-unchecked)"
}
# bl_run <label> <layer> <deriv> <val> [flag...] -> sets BL_OUT, BL_VEC; returns 1 if unbuildable
#
# THIS ONE MAY USE GLOBALS AND `bl_mut_vec` BELOW MAY NOT, AND THE DIFFERENCE IS THE CALL SHAPE
# RATHER THAN THE FUNCTION. Every call site here is `if bl_run ...; then`, a plain command in
# this shell, so its assignments survive. `bl_mut_vec` is read through `$( )` at every site, and
# an assignment inside a command substitution is lost to the subshell — which is why that one
# records its consumer in a FILE. Do not unify them by making this one return a string.
BL_OUT=""; BL_VEC=""
bl_run() {
  local lbl="$1" layer="$2" deriv="$3" val="$4"; shift 4
  local c="$BLROOT/c-$lbl"
  bl_consumer "$c" "$layer" "$deriv" "$val" || return 1
  [ "${1:-}" = --finish ] && printf 'theirs: %s\n' "$BL_THEIRS" > "$c/.claude/.ai-dlc-applying"
  BL_OUT="$(bl_drive "$BL_APPLY_UNDER_TEST" "$c" "$@")"
  BL_VEC="$(bl_vec "$BL_OUT")"
  BL_LAST_CONS="$c"
  return 0
}
BL_APPLY_UNDER_TEST="$APPLY"
BL_LAST_CONS=""

if [ "$BL_OK" != 1 ] || [ -z "$BL_BASE" ] || [ -z "$BL_THEIRS" ] || [ "$BL_BASE" = "$BL_THEIRS" ]; then
  bad "BL276 setup: could not build the two-commit dist whose range deletes one rulebook line (base='${BL_BASE:-<none>}' theirs='${BL_THEIRS:-<none>}') — every arm below would be unreadable"
else

# --- BL-S0 SUBJECT PROBE: are these two rows installed at all? --------------------------------
#
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT, AND THESE ROWS ARE A NEWER SUBJECT THAN `--finish`.
# The probe at the top of this file clears a consumer whose apply.sh predates the handback guard
# entirely; a consumer can have that guard and still be running an apply.sh from before BL-276,
# and every arm below would then read as a regression on a tree whose only fault is not having
# received the fix yet. The probe drives the FIRING world — the one BL-1 asserts draws both rows
# — and reads whether either reached the manifest. "Subject not installed" is not "subject
# regressed"; in the DISTRIBUTION the subject is always present, so an absent one is hard.
#
# ONE RUN PER STATE. The probe, BL-1 and BL-CTL's firing half all drove `hit hit yes` against the
# same refs, and BL-2 and BL-CTL's near-miss half both drove `miss miss yes`: two states, five
# apply.sh runs. Each state now runs ONCE, through the unmutated COPY BL-CTL scores, and every arm
# that asks about it reads the saved output. The copy is staged here and held BYTE-IDENTICAL to
# $REC file by file, so a run of it is a run of the resolved subject from a sibling directory; if
# the identity does not hold, BL-CTL goes red and the two runs fall back to $APPLY itself, so BL-1
# and BL-2 never score a staging that differs from the subject.
BL_CTL_DIR="$BLROOT/mut-ctl"; BL_CTL_ID=0; bl_ctl_n=0
if mkdir -p "$BL_CTL_DIR" && cp "$REC"/* "$BL_CTL_DIR"/ 2>/dev/null && [ -s "$BL_CTL_DIR/setup-sites.md" ]; then
  BL_CTL_ID=1
  for _f in "$REC"/*; do
    [ -f "$_f" ] || continue
    bl_ctl_n=$((bl_ctl_n+1))
    cmp -s "$_f" "$BL_CTL_DIR/$(basename "$_f")" || BL_CTL_ID=0
  done
  [ "$bl_ctl_n" -gt 0 ] || BL_CTL_ID=0
fi
[ "$BL_CTL_ID" = 1 ] && BL_APPLY_UNDER_TEST="$BL_CTL_DIR/apply.sh"
BL_BOTH_OK=0; BL_BOTH_OUT=""; BL_BOTH_VEC="BROKEN"
if bl_run both hit hit yes; then BL_BOTH_OK=1; BL_BOTH_OUT="$BL_OUT"; BL_BOTH_VEC="$BL_VEC"; fi
BL_NEAR_OK=0; BL_NEAR_OUT=""; BL_NEAR_VEC="BROKEN"
if bl_run near miss miss yes; then BL_NEAR_OK=1; BL_NEAR_OUT="$BL_OUT"; BL_NEAR_VEC="$BL_VEC"; fi
BL_APPLY_UNDER_TEST="$APPLY"
BL_PRESENT=1
if [ "$BL_BOTH_OK" = 1 ]; then
  case "$BL_BOTH_VEC" in
    "0|0|0|0") BL_PRESENT=0 ;;
  esac
else
  bad "BL-S0 setup: could not build the probe consumer, so whether the subject is installed was never established"
fi
if [ "$BL_PRESENT" = 0 ]; then
  if [ "$IS_DIST" = 1 ]; then
    bad "BL-S0 the resolved apply.sh ($APPLY) emitted NEITHER routing row over a consumer that carries both subjects — a layer file reproducing a line this range deleted, and an artifact fence naming a core path it changed. The BL-276 rows are absent. HARD in the distribution: the subject must be present here."
  else
    printf '  SKIP  %s\n' "BL-1..BL-5 and BL-m1..BL-m6 — the installed apply.sh predates the retired-layer-passage and artifact-derivations routing rows; they land with a later pull than the one carrying this fixture"
  fi
else
  ok "BL-S0 the resolved apply.sh routes at least one of the two classes, so the arms below are scoring a subject that is present"

# --- BL-S1 SANITY: the range this block drives actually deletes a rulebook line ---------------
# Both rows key on `git diff base..theirs -- core/`, one through the detector's rulebook globs
# and one through `map_consumer`. If that range were empty BOTH would be silent and every
# absence arm below would pass over a program that was never asked anything. Asserted with its
# own control in the same derivation: the diff names the rulebook file and does NOT name the
# validator whose consumer mapping the near-miss fence cites.
BL_DIFF="$(git -C "$PD" diff --name-only "$BL_BASE" "$BL_THEIRS" -- core/ 2>/dev/null)"
if grep -qxF 'core/skills/ai-dlc/SKILL.md' <<< "$BL_DIFF" \
   && ! grep -qxF 'core/scripts/validate-synthetic.sh' <<< "$BL_DIFF"; then
  ok "BL-S1 setup: the seeded range changes the rulebook file and NOT the validator — the offender and near-miss fences below cite two paths this range genuinely classifies differently"
else
  bad "BL-S1 setup: the seeded range is not the two-path shape the arms need (changed: $(printf '%s' "$BL_DIFF" | tr '\n' ' ')) — every derivation arm below would be vacuous"
fi

# --- BL-S2 SANITY: THE STAGING TRAP, ASSERTED BEFORE ANY ROW IS SCORED ------------------------
#
# MEASURED, AND IT FAILS IN THE DIRECTION THAT READS AS A PASS. `retired-layer-passage.sh`
# resolves its corpus from `$(dirname $0)/setup-sites.md`. A reconcile directory staged with
# `*.sh` and no `*.md` leaves it unable to read that declaration; it REFUSES rather than
# reporting clean -- but it refuses on stderr, and every call site in apply.sh discards stderr.
# So the detector returns no rows, apply.sh emits no row 1, and a fixture whose staging did that
# would score a passage arm against a detector that never opened a layer file.
#
# Measured on this repo's reconcile directory, same consumer, same range: `*.sh` only gives
# row1=0 while row2 still fires at 1; `*` gives row1=1. The two differ in the copy, not in the
# subject, which is why this is asserted here and not left to the reader.
if [ -s "$REC/setup-sites.md" ]; then
  ok "BL-S2 setup: the reconcile directory this fixture drives carries setup-sites.md, so the passage detector can read its rulebook corpus — a staging without it returns zero rows on stderr and reads exactly like a clean consumer"
else
  bad "BL-S2 setup: $REC has no setup-sites.md, so retired-layer-passage.sh refuses on stderr (which apply.sh discards) and returns no rows — BL-1 below would score a detector that never opened a layer file"
fi

# --- BL-1: BOTH ROWS FIRE ON A CONSUMER THAT CARRIES BOTH SUBJECTS ----------------------------
# The positive direction, and it is what makes every absence arm below readable. `semantic-merge`
# is NOT available as the same-invocation control here -- these worlds seed no both-changed file
# -- so the control is `DECISION restamp-withheld`, which apply.sh emits whenever a hand-back is
# outstanding and which therefore proves the run reached its re-stamp verdict.
if [ "$BL_BOTH_OK" = 1 ]; then
  BL_BOTH="$BL_BOTH_VEC"
  BL_CTL="$(bl_n "$BL_BOTH_OUT" DECISION restamp-withheld)"
  if [ "$BL_BOTH" = "1|1|0|0" ]; then
    ok "BL-1 a consumer whose layer file reproduces the retired line AND whose artifact fence names the changed core path draws both WORKLIST rows (retired-layer-passage, artifact-derivations)"; B_BL1=1
  else
    bad "BL-1 the firing consumer drew row1|wl2|unreadable|unchecked = $BL_BOTH, not 1|1|0|0 — the classes BL-276 routes to the worklist are not reaching it"
  fi
  # BL-706: the firing consumer is a NON-GIT tree with an installed validator, so the derivation differential REFUSES (no base
  # commit can be found) and apply.sh must say so loudly. The row is asserted by NAME and by its refusal arm, so a regression
  # that drops it (the call, the case arm, the DECISION) fails here. A real consumer is a git repo; a non-git one refusing is correct.
  BL_DD_ROWS="$(bl_n "$BL_BOTH_OUT" DECISION artifact-derivations-differential)"
  BL_DD_ARM="$(awk -F'\t' '$1 == "DECISION" && $2 == "artifact-derivations-differential" { print $4; exit }' <<<"$BL_BOTH_OUT")"
  case "$BL_DD_ARM" in
    *"REFUSED (exit 2)"*"consumer: "*"is not a git work tree with a HEAD"*) BL_DD_OK=1 ;;
    *) BL_DD_OK=0 ;;
  esac
  if [ "$BL_DD_ROWS" = 1 ] && [ "$BL_DD_OK" = 1 ]; then
    ok "BL-1 and the non-git consumer draws exactly one DECISION artifact-derivations-differential row quoting the consumer refusal (BL-706: a refused measurement is loud)"
  else
    bad "BL-1 the firing non-git consumer drew $BL_DD_ROWS DECISION artifact-derivations-differential row(s) (want 1) with refusal arm ok=$BL_DD_OK (want a 'REFUSED (exit 2)' quoting the consumer not-a-git-work-tree refusal; row text: $(printf '%s' "$BL_DD_ARM" | cut -c1-260)) — apply.sh's differential site no longer reports a refused measurement"
  fi
  if [ "$BL_CTL" -ge 1 ]; then
    ok "BL-1 and the same invocation emits DECISION restamp-withheld, so the run reached its re-stamp verdict rather than dying early"
  else
    bad "BL-1 the firing run emitted no DECISION restamp-withheld — it did not reach the re-stamp verdict, so the counts above are about a run that stopped, not about these rows"
  fi
else
  bad "BL-1 setup: could not build the firing consumer"
  BL_BOTH="BROKEN"
fi

# --- BL-2: THE NEAR-MISS IS SILENT, AND IT IS ONE PROPERTY AWAY FROM BL-1 ---------------------
# The layer file paraphrases instead of reproducing (the detector's own stated limit), and the
# fenced command names a core path this range did not change while the SAME command naming the
# changed path sits OUTSIDE the fence. Both halves of the offender are present in form; only the
# discriminating property is absent from each.
if [ "$BL_NEAR_OK" = 1 ]; then
  if [ "$BL_NEAR_VEC" = "0|0|0|0" ]; then
    ok "BL-2 a near-miss consumer — a PARAPHRASED layer line, and a fenced command naming an UNCHANGED core path while the changed one appears outside any fence — draws neither row"; B_BL2=1
  else
    bad "BL-2 the near-miss consumer drew $BL_NEAR_VEC, not 0|0|0|0 — a row fired on a layer file that reproduces nothing core deleted, or on a fence this range does not touch (the unfenced line is the likely match)"
  fi
  if [ "$(bl_n "$BL_NEAR_OUT" DECISION restamp-withheld)" -ge 1 ]; then
    ok "BL-2 and the near-miss run still reaches its re-stamp verdict, so its two zeros are an absence of rows and not an absence of a run"
  else
    bad "BL-2 the near-miss run emitted no DECISION restamp-withheld: its zeros may be a run that never got there, which is the shape an absence arm cannot tell from a pass"
  fi
else
  bad "BL-2 setup: could not build the near-miss consumer"
fi

# --- BL-3: THE TWO ROWS ARE INDEPENDENT -------------------------------------------------------
# A consumer with the artifact but NO layer directory, and one with the layer file but no
# artifact corpus. Without this pair a single shared gate emitting both rows together would
# satisfy BL-1 and BL-2 exactly as the shipped code does.
BL_NOLAYER_OK=0; BL_NOLAYER_OUT=""; BL_NOLAYER_VEC=""
if bl_run nolayer none hit yes; then
  # SAVED: BL-6a below is this same state (`none hit yes`, same refs) and reads it, never reruns it.
  BL_NOLAYER_OK=1; BL_NOLAYER_OUT="$BL_OUT"; BL_NOLAYER_VEC="$BL_VEC"
  case "$BL_VEC" in
    "0|1|0|0") ok "BL-3 a consumer with no layer directory still draws the derivation row alone — the two rows are separately gated" ;;
    *)         bad "BL-3 a consumer with no layer directory drew $BL_VEC, not 0|1|0|0 — the passage row fired with no layer file to have found it in, or the derivation row is gated on the passage one" ;;
  esac
else
  bad "BL-3 setup: could not build the no-layer consumer"
fi
if bl_run noart hit none yes; then
  case "$BL_VEC" in
    "1|0|0|0") ok "BL-3 and a consumer with no _bmad-output draws the passage row alone — neither row depends on the other's subject" ;;
    *)         bad "BL-3 a consumer with no artifact corpus drew $BL_VEC, not 1|0|0|0" ;;
  esac
else
  bad "BL-3 setup: could not build the no-artifact consumer"
fi
# The near-miss of BL-3's first world, one property apart: a zero-byte markdown file sits in the
# corpus beside the firing artifact. It is readable, so the vector must be the same 0|1|0|0.
if bl_run zerobyte none hitzero yes; then
  case "$BL_VEC" in
    "0|1|0|0") ok "BL-3z a zero-byte markdown file in the corpus is counted as opened — the derivation row is still drawn, not the unreadable DECISION" ;;
    *)         bad "BL-3z a corpus carrying one zero-byte markdown file drew $BL_VEC, not 0|1|0|0 — the scan scores an EMPTY file as unopened, so one empty log turns every pull into artifact-derivations-unreadable" ;;
  esac
else
  bad "BL-3z setup: could not build the zero-byte-file consumer"
fi

# --- BL-4: THE ABSENT-VALIDATOR BRANCH IS A DECISION, AND IT IS GATED ON THE JOIN -------------
#
# TWO DIRECTIONS, AND THE SECOND ONE IS THE MEASURED FALSE POSITIVE. With real stranded
# citations and no `validate-artifact-derivations.sh` on the consumer, the run must SAY so --
# nothing can re-run those commands. But a consumer with no artifact corpus at all, or an empty
# one, must draw NOTHING from this site: keying the absent-branch on the TOOL rather than on the
# non-empty join fires on every consumer predating the mechanism, which is what failed C4 above
# and is the reason that arm's seed exists.
if bl_run noval hit hit no; then
  if [ "$BL_VEC" = "1|0|0|1" ]; then
    ok "BL-4 a consumer with stranded citations and no validate-artifact-derivations.sh draws DECISION artifact-derivations-unchecked instead of the WORKLIST row — nothing on that tree can re-run the commands, and the row says so"; B_BL4=1
  else
    bad "BL-4 the validator-absent consumer drew $BL_VEC, not 1|0|0|1 — either the WORKLIST row was emitted naming a script that is not there, or the split reported nothing at all"
  fi
else
  bad "BL-4 setup: could not build the validator-absent consumer"
fi
if bl_run emptyart hit empty yes; then
  case "$BL_VEC" in
    "1|0|0|0") ok "BL-4 and a consumer whose _bmad-output holds no markdown draws NEITHER derivation branch — the gate is the non-empty join, not the presence of the tool, so a consumer predating the mechanism is not handed a row about work it does not have" ;;
    *)         bad "BL-4 an empty artifact corpus drew $BL_VEC, not 1|0|0|0 — a branch keyed on the tool rather than on the join fires on every older consumer, which is the C4 shape" ;;
  esac
else
  bad "BL-4 setup: could not build the empty-artifact consumer"
fi

# --- BL-5: THE SITING. NEITHER ROW IS EMITTED UNDER --finish, AND THE STAMP IS WRITTEN --------
#
# THIS IS THE ARM THE WHOLE SITING EXISTS FOR, AND IT IS THE ONE THAT CANNOT BE READ OFF THE
# ROWS ALONE. `say` raises `worklist_n`, and `--finish` gates its stamp on that counter. Both
# rows are re-derived from state `--finish` never writes -- a layer file is consumer-owned and
# this program never rewrites one, and the derivation remedy re-anchors a citation at a path
# that is itself in the changed set -- so a row sited beside `hook_registration_row` /
# `transient_ignore_row` / `agent_definitions_row`, which run under `--finish` BEFORE
# `write_stamp`, would withhold the stamp on every finish over this tree. `.ai-dlc-applying`
# would stay, `core/git-hooks/pre-push`'s applying guard would refuse every push, and the
# consumer would have no exit. The tree driven here is the SAME one BL-1 fires both rows on, so
# the zeros below are a property of the mode and not of the input.
if bl_run finish hit hit yes --finish; then
  BL_FV="$(sed -n 's/^version:[[:space:]]*//p' "$BL_LAST_CONS/.claude/.ai-dlc-version" 2>/dev/null | head -1)"
  BL_FM="$([ -f "$BL_LAST_CONS/.claude/.ai-dlc-applying" ] && echo PRESENT || echo GONE)"
  BL_FR="$(bl_n "$BL_OUT" RESOLVED restamp)"
  if [ "$BL_VEC" = "0|0|0|0" ]; then
    ok "BL-5 --finish over the very tree BL-1 fires both rows on emits NEITHER — the rows sit inside the FINISH=0 span, so the finisher never re-derives them"; B_BL5=1
  else
    bad "BL-5 --finish emitted $BL_VEC over a tree it cannot change: these rows raise worklist_n, which is the counter --finish gates its stamp on, and neither has work that clears in that mode. The consumer is wedged with .ai-dlc-applying on disk and pre-push refusing every push"
  fi
  if [ "$BL_FV" = "$BL_THEIRS_VER" ] && [ "$BL_FM" = GONE ] && [ "$BL_FR" -ge 1 ]; then
    ok "BL-5 and the finisher STAMPS — version $BL_FV, marker cleared, RESOLVED restamp — which is the exit the siting exists to preserve"; B_BL5S=1
  else
    bad "BL-5 --finish did not stamp (version='${BL_FV:-<absent>}' expected $BL_THEIRS_VER, marker=$BL_FM, RESOLVED restamp=$BL_FR). A row this mode cannot clear withholds the stamp forever, and the applying marker keeps pre-push refusing"
  fi
else
  bad "BL-5 setup: could not build the finish consumer"
fi

# --- BL-6: THE ROW IS SCOPED BY THE CLASSIFIER THE DISTRIBUTION CARRIES AT THEIRS (BL-631) -------
#
# vd_join keeps only the artifact files `check-owed-derivations.sh --scope-batch` calls CURRENT or
# LIVING, and reads that classifier (with sprint-status.sh and its schema) out of the DIST at
# THEIRS. A classifier that cannot be found anywhere is a loud DECISION, never a guessed row. The
# worlds below differ from BL-1 in one property each: BL-6a has the classifier, BL-6b has lost it
# at THEIRS with no consumer copy, BL-6c's only hit lives under a past sprint's slot.
if [ -z "${BL_CLS_SH:-}" ] || [ -z "${BL_CLS_SS:-}" ] || [ -z "${BL_CLS_SCH:-}" ]; then
  if [ "$IS_DIST" = 1 ]; then
    bad "BL-6 setup: the scope classifier (check-owed-derivations.sh, sprint-status.sh, sprint-status.json) is not in this tree, so the dist could not carry it — HARD in the distribution"
  else
    printf '  SKIP  %s\n' "BL-6a..BL-6c — the scope classifier is not in this tree; they land with the pull that carries it"
  fi
elif ! command -v python3 >/dev/null 2>&1; then
  printf '  SKIP  %s\n' "BL-6a..BL-6c — python3 is absent, so sprint-status.sh sprint-id cannot run (this is not a pass)"
else
  # BL-6a: classifier at THEIRS, consumer has a LIVING hit -> the WORKLIST row, no unscoped row.
  # The SAME state as BL-3's no-layer world (`none hit yes`, THEIRS, the classifier committed at
  # base), so it reads that run's saved output; BL-6b is the world that differs, in the ref.
  if [ "$BL_NOLAYER_OK" = 1 ]; then
    BL6A_U="$(bl_n "$BL_NOLAYER_OUT" DECISION artifact-derivations-unscoped)"
    if [ "$BL_NOLAYER_VEC" = "0|1|0|0" ] && [ "$BL6A_U" = 0 ]; then
      ok "BL-6a a dist carrying the classifier at THEIRS draws the WORKLIST artifact-derivations row and no artifact-derivations-unscoped row"
    else
      bad "BL-6a drew $BL_NOLAYER_VEC with $BL6A_U unscoped row(s), not 0|1|0|0 with 0 — the classifier at THEIRS did not scope the consumer's hit"
    fi
  else
    bad "BL-6a setup: could not build the consumer"
  fi
  # BL-6b: the same consumer, a THEIRS that has lost check-owed-derivations.sh, no consumer copy.
  BL_NOCLS=""
  if pgitc rm -q core/scripts/check-owed-derivations.sh >/dev/null 2>&1 \
     && pgitc commit -q -m bl276-nocls >/dev/null 2>&1; then
    BL_NOCLS="$(git -C "$PD" rev-parse HEAD)"
  fi
  if [ -n "$BL_NOCLS" ] && [ "$BL_NOCLS" != "$BL_THEIRS" ] \
     && ! git -C "$PD" cat-file -e "${BL_NOCLS}:core/scripts/check-owed-derivations.sh" 2>/dev/null; then
    BL_DRIVE_THEIRS="$BL_NOCLS"
    if bl_run six-b none hit yes; then
      BL6B_U="$(bl_n "$BL_OUT" DECISION artifact-derivations-unscoped)"
      BL6B_CTL="$(bl_n "$BL_OUT" DECISION restamp-withheld)"
      BL6B_HAS="$([ -e "$BL_LAST_CONS/scripts/ai-dlc/check-owed-derivations.sh" ] && echo PRESENT || echo ABSENT)"
      if [ "$BL6B_U" = 1 ] && [ "$BL_VEC" = "0|0|0|0" ] && [ "$BL6B_HAS" = ABSENT ]; then
        ok "BL-6b the same consumer against a THEIRS without check-owed-derivations.sh and with no consumer copy draws exactly one DECISION artifact-derivations-unscoped and no WORKLIST artifact-derivations row"
      else
        bad "BL-6b drew $BL_VEC with $BL6B_U unscoped row(s) (consumer copy $BL6B_HAS), not 0|0|0|0 with exactly 1 and ABSENT — a classifier that cannot be found must be loud, never a guessed row"
      fi
      if [ "$BL6B_CTL" -ge 1 ]; then
        ok "BL-6b and the same run reaches DECISION restamp-withheld, so the unscoped row is a verdict of a run that completed"
      else
        bad "BL-6b the run emitted no DECISION restamp-withheld — it stopped early, so the row counts above are about a run that did not finish"
      fi
    else
      bad "BL-6b setup: could not build the consumer"
    fi
    BL_DRIVE_THEIRS=""
  else
    bad "BL-6b setup: could not build a THEIRS commit that has lost check-owed-derivations.sh (got '${BL_NOCLS:-<none>}')"
  fi
  # BL-6c: the only hit is a past sprint's artifact -> no artifact-derivations row of ANY kind.
  # Its control is the identical artifact under the current sprint's slot, which MUST draw the row.
  if bl_run six-c none past yes; then
    BL6C_U="$(bl_n "$BL_OUT" DECISION artifact-derivations-unscoped)"
    if [ "$BL_VEC" = "0|0|0|0" ] && [ "$BL6C_U" = 0 ]; then
      ok "BL-6c a consumer whose only hit-bearing artifact is a past sprint's (planning-artifacts/s0/old.md, canonical sprint 1) draws no artifact-derivations row of any kind"
    else
      bad "BL-6c a past sprint's artifact drew $BL_VEC with $BL6C_U unscoped row(s), not 0|0|0|0 with 0 — a past sprint owes nothing to this pull"
    fi
  else
    bad "BL-6c setup: could not build the past-sprint consumer"
  fi
  if bl_run six-cc none cur yes; then
    if [ "$BL_VEC" = "0|1|0|0" ]; then
      ok "BL-6c control: the identical artifact under the current sprint's slot (planning-artifacts/s1/old.md) DOES draw the WORKLIST row, so the zero above is the scope and not the shape"
    else
      bad "BL-6c control: the current sprint's artifact drew $BL_VEC, not 0|1|0|0 — the past-sprint zero above proves nothing"
    fi
  else
    bad "BL-6c control setup: could not build the current-sprint consumer"
  fi
fi

# ==============================================================================================
# BL-276 MUTANTS
# ==============================================================================================
#
# FOUR REGRESSIONS THAT ALL PASS THE ENTRY'S FILED RECEIPT, plus the two that revert each row
# outright. The receipt anchors on `^[[:blank:]]*say WORKLIST` plus the class name, which
# establishes lexical non-comment position and neither reachability nor conditionality: a row in
# a function nothing calls, a row under `if false`, a row consulting no detector, and a row
# emitted only under `--finish` all satisfy it. The arms above are what must kill them, so each
# one below is scored against a named arm and against a second arm it must NOT move.
#
# EVERY MUTANT IS A COPY OF THE WHOLE RECONCILE DIRECTORY. apply.sh evals map_consumer() out of
# preclassify.sh and shells to its siblings; a lone script copy dies before printing anything,
# and `*.sh` without the `*.md` silences the passage detector specifically (BL-S2). `bl_mut`
# therefore asserts setup-sites.md landed in the copy, so a mutant scored 0 on row 1 cannot be
# a staging that refused.
bl_mut() { # bl_mut <dir> ; transform reads apply.sh on stdin, writes stdout
  mkdir -p "$1" || return 1
  cp "$REC"/* "$1"/ 2>/dev/null
  [ -f "$1/apply.sh" ] || return 1
  [ -s "$1/setup-sites.md" ] || { bad "MUTANT STAGING BROKEN — $1 has no setup-sites.md, so its row-1 score is the staging refusing and not the mutation"; return 1; }
  cat > "$1/apply.sh"
  ! cmp -s "$REC/apply.sh" "$1/apply.sh"
}
# bl_mut_vec <rec-dir> <layer> <deriv> <val> [flags...] -> the four-observable vector
# THE CONSUMER IT BUILT IS RECORDED IN A FILE, NOT IN A VARIABLE, AND THAT IS A MEASUREMENT.
# An arm may need the STAMP and the MARKER a mutant's run wrote rather than only the rows it
# printed — BL-m4's consequence is a withheld stamp, and a row count is true either way. The
# obvious shape is a global naming the directory this function built. It CANNOT be a global:
# every call site reads this function through `$( )`, and an assignment made inside a command
# substitution is lost to the subshell. Measured here while building BL-m4: the arm read
# `version=<absent> marker=GONE` off a path the caller never learned, which reads exactly like a
# mutation that failed to wedge the finisher. A file survives the subshell; a variable does not.
bl_mut_vec() {
  local rec="$1"; shift
  local layer="$1" deriv="$2" val="$3"; shift 3
  local c="$BLROOT/mc-$$-$RANDOM" out
  bl_consumer "$c" "$layer" "$deriv" "$val" || { echo "BROKEN"; return; }
  printf '%s' "$c" > "$BLROOT/.last-mut-consumer"
  [ "${1:-}" = --finish ] && printf 'theirs: %s\n' "$BL_THEIRS" > "$c/.claude/.ai-dlc-applying"
  out="$(bl_drive "$rec/apply.sh" "$c" "$@")"
  bl_vec "$out"
}
bl_last_mut_consumer() { cat "$BLROOT/.last-mut-consumer" 2>/dev/null; }
# bl_twin <mutant> <rec-dir> <twin-arm> <unmutated-vector> <layer> <deriv> <val>
# THE PER-PUSH TWIN: one arm the mutant could plausibly co-trip, driven through the MUTANT and
# required to read its UNMUTATED vector exactly. The vector carries at least one 1, so a copy that
# never ran fails the twin rather than holding it. Which arm is each mutant's twin is read off the
# mutant-by-arm matrix measured once; a twin that goes red means the kill is no longer confined.
bl_twin() {
  local m="$1" rec="$2" arm="$3" want="$4" got; shift 4
  got="$(bl_mut_vec "$rec" "$@")"
  if [ "$got" = "$want" ]; then
    ok "$m twin $arm holds under it — its world reads the unmutated $want, so the deciding arm's verdict is confined to that arm"
  else
    bad "$m twin $arm moved under it ($got, unmutated $want): the mutation reaches an arm it was measured not to, so the deciding arm's verdict is not cleanly attributable"
  fi
}

# --- BL-CTL: THE UNMUTATED COPY, WITH POSITIVE CONJUNCTS ON BOTH DIRECTIONS -------------------
# A control asserting only "nothing went wrong" passes against a subject replaced by `exit 0`.
# This one requires the firing world's two rows to be THERE and the near-miss world's to be
# absent, in the same copy, so a staging that cannot run reports as broken rather than as clean.
# The copy was staged before BL-S0 and the two runs it answers with are the ones BL-1 and BL-2
# read: the same states, so the same runs. Its first conjunct is the byte identity that licenses
# that sharing; a copy that differs from $REC in any file is staging broken, never a BL verdict.
if [ "$BL_CTL_ID" = 1 ]; then
  BLC_P="$BL_BOTH_VEC"
  BLC_N="$BL_NEAR_VEC"
  if [ "$BLC_P" = "1|1|0|0" ] && [ "$BLC_N" = "0|0|0|0" ]; then
    ok "BL-CTL an unmutated copy of the reconcile directory reproduces BOTH directions (firing 1|1|0|0, near-miss 0|0|0|0), so a mutant's silence below is the mutation and not the copy"; B_BLCTL=1
  else
    bad "BL-CTL the unmutated copy did not reproduce the shipped behaviour (firing=$BLC_P near-miss=$BLC_N) — every BL mutant verdict below is unreadable"
  fi
else
  bad "BL-CTL could not stage a complete copy of $REC byte-identical file by file ($bl_ctl_n file(s) compared, setup-sites.md required) — every BL mutant verdict below is unreadable, and BL-1/BL-2 ran \$APPLY directly instead"
fi

# --- BL-m1: the passage row moved into a function NOTHING CALLS -------------------------------
# The first of the four the filed receipt accepts. The emitting line keeps its exact spelling and
# its leading blank, so `^[[:blank:]]*say WORKLIST retired-layer-passage` still matches; the row
# is simply unreachable. BL-1 must go red and BL-3's derivation half must not.
if awk '
    /^RLP_OUT="\$\(bash "\$SELF\/retired-layer-passage\.sh"/ { print "bl276_dead_passage_row() {"; ded=1 }
    ded==1 && /^fi$/ { print $0; print "}"; ded=0; next }
    { print }
  ' "$REC/apply.sh" | bl_mut "$BLROOT/bl-m1"; then
  BLM1="$(bl_mut_vec "$BLROOT/bl-m1" hit hit yes)"
  case "$BLM1" in 0\|1\|*) blm_k=1 ;; *) blm_k=0 ;; esac
  if [ "$blm_k" = 1 ]; then
    mutant_killed "$(( ${B_BL1:-0} && ${B_BLCTL:-0} ))" BL-m1 "BL-m1 (the whole passage block wrapped in a function nothing calls): BL-1 goes red — the row is lexically intact and unreachable, which is the first regression the filed receipt accepts"
  else
    bad "BL-m1 SURVIVED: the firing world drew $BLM1, not 0|1|.. — the passage row was still emitted from inside an uncalled function, or the run died for an unrelated reason, so BL-1 is not testing reachability"
  fi
  case "$BLM1" in
    *\|1\|0\|0) ok "BL-m1 and the derivation row is untouched by it — BL-1's two halves are not entangled" ;;
    *)          bad "BL-m1 also moved the derivation row ($BLM1): the passage and derivation arms are entangled and one of them proves nothing on its own" ;;
  esac
  bl_twin BL-m1 "$BLROOT/bl-m1" BL-3 "0|1|0|0" none hit yes
else
  bad "BL-m1 did not apply — apply.sh's passage block no longer opens with \`RLP_OUT=\"\$(bash \"\$SELF/retired-layer-passage.sh\"\` at column 0, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# --- BL-m2: the passage row under `if false` --------------------------------------------------
# The second receipt-passing regression. The detector is still invoked, the variable is still
# assigned from it, and the row is still lexically a `say WORKLIST` — only the condition is
# dead. This is the one a reachability conjunct keyed on the invocation cannot see.
if sed 's/^if \[ "\$RLP_N" -gt 0 \]; then$/if false; then/' "$REC/apply.sh" | bl_mut "$BLROOT/bl-m2"; then
  BLM2="$(bl_mut_vec "$BLROOT/bl-m2" hit hit yes)"
  case "$BLM2" in 0\|1\|*) blm_k=1 ;; *) blm_k=0 ;; esac
  if [ "$blm_k" = 1 ]; then
    mutant_killed "$(( ${B_BL1:-0} && ${B_BLCTL:-0} ))" BL-m2 "BL-m2 (the passage row's condition replaced by \`if false\`): BL-1 goes red although the detector is still called and the row still reads as a say WORKLIST site"
  else
    bad "BL-m2 SURVIVED: the firing world drew $BLM2, not 0|1|.. — the row was emitted with its guard dead, or the run died, so BL-1 is not testing the condition"
  fi
  case "$BLM2" in
    *\|1\|0\|0) ok "BL-m2 and the derivation row is untouched by it" ;;
    *)          bad "BL-m2 also moved the derivation row ($BLM2): the two arms are entangled" ;;
  esac
  bl_twin BL-m2 "$BLROOT/bl-m2" BL-3 "0|1|0|0" none hit yes
else
  bad "BL-m2 did not apply — the passage row's guard is no longer spelled \`if [ \"\$RLP_N\" -gt 0 ]; then\` at column 0, so this mutant proves nothing"
fi

# --- BL-m3: an UNCONDITIONAL passage row consulting no detector -------------------------------
# The third, and the one that is most obviously a row while being least obviously wrong: the
# detector is never run and the row is emitted on every pull, so a consumer with no stale layer
# passage at all is handed work that does not exist. BL-2 is the arm that owns it; BL-1 must
# STAY GREEN, because an unconditional row does fire on the firing world too.
if awk '
    /^RLP_OUT="\$\(bash "\$SELF\/retired-layer-passage\.sh"/ { skip=1 }
    skip==1 && /^fi$/ { skip=0
                        print "RLP_N=1; RLP_NF=1; RLP_LIST=\"unknown\""
                        print "  say WORKLIST retired-layer-passage \".claude/skills/ai-dlc/\" \"${RLP_N} RETIRED-LAYER-PASSAGE row(s) across ${RLP_NF} layer file(s). RE-POINT each one at the wording core carries now. File(s): ${RLP_LIST}.\""
                        next }
    skip==1 { next }
    { print }
  ' "$REC/apply.sh" | bl_mut "$BLROOT/bl-m3"; then
  # ONE RUN, ON THE DECIDING WORLD. The firing world was driven too, to show BL-1 stays green; an
  # unconditional emitter reaches that world by construction, so the run answered nothing the
  # near-miss vector's other three fields do not: they must stay at the unmutated 0|0|0.
  BLM3_N="$(bl_mut_vec "$BLROOT/bl-m3" miss miss yes)"
  case "$BLM3_N" in 1\|*) blm_k=1 ;; *) blm_k=0 ;; esac
  if [ "$blm_k" = 1 ]; then
    mutant_killed "$(( ${B_BL2:-0} && ${B_BLCTL:-0} ))" BL-m3 "BL-m3 (an unconditional row consulting no detector): BL-2 goes red — the near-miss consumer, which has no stale passage at all, is handed the row anyway"
  else
    bad "BL-m3 SURVIVED: the near-miss consumer drew $BLM3_N, no passage row from an unconditional emitter, so BL-2 is not testing that the row is derived from the detector"
  fi
  case "$BLM3_N" in
    *\|0\|0\|0) ok "BL-m3 and only the passage field moved — the near-miss vector's derivation fields stay at the unmutated 0|0|0, so the kill is the unconditional emitter alone; an unconditional row reaches the firing consumer by construction, which is why BL-1 cannot catch this and BL-2 is not redundant" ;;
    *)          bad "BL-m3 also moved the near-miss world's derivation fields ($BLM3_N): the passage and derivation arms are entangled, and the near-miss kill above is not cleanly attributable" ;;
  esac
  bl_twin BL-m3 "$BLROOT/bl-m3" BL-1 "1|1|0|0" hit hit yes
else
  bad "BL-m3 did not apply — the passage block could not be replaced by an unconditional emitter; re-anchor it on the current spelling"
fi

# --- BL-m4: the passage row RE-SITED to where the finisher re-derives it ----------------------
#
# THE FOURTH RECEIPT-PASSING REGRESSION, AND THE ONE WITH THE WORST CONSEQUENCE. The row is
# moved out of the FINISH=0 span and emitted under `--finish` instead, beside the trailing
# hook/transient/agent rows and BEFORE write_stamp. It reads as a correct fix -- the row exists,
# it is derived from the detector, it is a say WORKLIST line -- and it wedges the consumer: the
# row raises worklist_n over a tree `--finish` cannot change, the stamp is withheld forever and
# `.ai-dlc-applying` never clears. BL-5 owns it. BL-1 must also go red, because the row leaves
# the ordinary path entirely; that is the one place two arms genuinely both fire, and BL-5 is
# the one that names the consequence.
if awk '
    /^RLP_OUT="\$\(bash "\$SELF\/retired-layer-passage\.sh"/ { cap=1 }
    cap==1 { blk = blk $0 "\n"; if ($0 ~ /^fi$/) cap=2; next }
    /^if \[ "\$FINISH" = 1 \]; then$/ { print; if (blk != "") { printf "%s", blk; blk="" } ; next }
    { print }
  ' "$REC/apply.sh" | bl_mut "$BLROOT/bl-m4"; then
  BLM4_F="$(bl_mut_vec "$BLROOT/bl-m4" hit hit yes --finish)"
  # THE WEDGE ITSELF, READ OFF THE TREE RATHER THAN OFF THE ROW COUNT. `bl_mut_vec` leaves its
  # consumer on disk, so the stamp and the marker this mutant's finisher wrote are still there.
  # A row count is the symptom; the stamp left at BASE with `.ai-dlc-applying` still present is
  # the CONSEQUENCE, and it is what `core/git-hooks/pre-push`'s applying guard acts on. This
  # repo has shipped a guard whose refusal was asserted by a row count that was true either way.
  BLM4_FC="$(bl_last_mut_consumer)"
  BLM4_FV="$(sed -n 's/^version:[[:space:]]*//p' "$BLM4_FC/.claude/.ai-dlc-version" 2>/dev/null | head -1)"
  BLM4_FM="$([ -n "$BLM4_FC" ] && [ -f "$BLM4_FC/.claude/.ai-dlc-applying" ] && echo PRESENT || echo GONE)"
  # THIS MUTANT TRIPS TWO ARMS BY DESIGN (BL-5 and BL-1), so both are asserted, on behaviour: the
  # ordinary run shows the row left the FINISH=0 path, and its derivation field at 1 is the presence
  # conjunct a copy that never ran cannot print.
  BLM4_O="$(bl_mut_vec "$BLROOT/bl-m4" hit hit yes)"
  if [ -z "$BLM4_FC" ]; then
    bad "BL-m4 could not recover the consumer directory its finisher ran against, so the wedge conjunct below has no subject to read — this arm is unproven"
  elif [ "$BLM4_FV" = "1.0.0" ] && [ "$BLM4_FM" = PRESENT ]; then
    mutant_killed "$(( ${B_BL5S:-0} && ${B_BLCTL:-0} ))" BL-m4 "BL-m4 and the wedge is observed on the TREE, not inferred from a row: the mutant's finisher left the stamp at 1.0.0 with .ai-dlc-applying still on disk, which is the state pre-push refuses every push over and which no further --finish can clear"
  else
    bad "BL-m4 SURVIVED: the re-sited row did not withhold the finisher's stamp (version='${BLM4_FV:-<absent>}' marker=$BLM4_FM) — BL-5's second conjunct is then asserting a consequence this mutation does not produce, and the siting claim rests on the row count alone"
  fi
  case "$BLM4_F" in 1\|*) blm_k=1 ;; *) blm_k=0 ;; esac
  if [ "$blm_k" = 1 ]; then
    mutant_killed "$(( ${B_BL5:-0} && ${B_BLCTL:-0} ))" BL-m4 "BL-m4 (the passage row re-sited beside the trailing rows, under --finish): BL-5 goes red — the finisher re-derives a row over a tree it never writes, raising worklist_n before write_stamp"
  else
    bad "BL-m4 SURVIVED: --finish drew $BLM4_F, no passage row with the block moved into its branch, so BL-5 is not testing the siting"
  fi
  case "$BLM4_O" in 0\|1\|*) blm_k=1 ;; *) blm_k=0 ;; esac
  if [ "$blm_k" = 1 ]; then
    mutant_killed "$(( ${B_BL1:-0} && ${B_BLCTL:-0} ))" BL-m4 "BL-m4 and BL-1 goes red with it — the row left the ordinary path, which is the half a --finish-only fix gets wrong in the other direction"
  else
    bad "BL-m4 SURVIVED on BL-1: the ordinary run drew $BLM4_O, not 0|1|.. — the mutation did not move the block, so BL-5's kill above is not attributable to the siting"
  fi
  bl_twin BL-m4 "$BLROOT/bl-m4" BL-3 "0|1|0|0" none hit yes
else
  bad "BL-m4 did not apply — either the passage block or apply.sh's \`if [ \"\$FINISH\" = 1 ]; then\` branch has been respelled, so BL-5 is unproven against a re-sited row"
fi

# --- BL-m5: the relevance scan stops reading the FENCE ----------------------------------------
#
# ANCHORED ON THE PREDICATE THAT DECIDES, NOT ON THE GUARD ABOVE IT — AND THAT IS A MEASUREMENT.
# The obvious mutation is `if [ -n "${VD_MOVED:-}" ] && [ "$VD_LISTED" -gt 0 ]` widened to
# `true`, and it SURVIVES: both conjuncts are already true on the near-miss consumer, which has
# a markdown artifact and a non-empty changed set. Widening a guard that already passes changes
# no decision, and a mutant that changes no decision reads exactly like an arm that cannot fire.
# What decides relevance is `VD_HITS`, and what computes it is the awk's `infence` test. Drop
# the fence requirement from the line that accumulates hits and the scan matches the SAME
# command wherever it appears — which is precisely the property BL-2's near-miss seeds, in a
# line spelled exactly as the offender's but outside any fence.
if sed 's/^          infence \&\& \/\^\[\[:blank:\]\]\*\\\$ \/ {$/          \/^[[:blank:]]*\\$ \/ {/' \
     "$REC/apply.sh" | bl_mut "$BLROOT/bl-m5"; then
  # ONE RUN, ON THE DECIDING WORLD; the separate-gating claim is read off its passage field.
  BLM5_N="$(bl_mut_vec "$BLROOT/bl-m5" miss miss yes)"
  # PRESENCE-SHAPED: the kill needs the derivation field at 1, so a copy that never ran scores SURVIVED.
  case "$BLM5_N" in *\|1\|*) blm_k=1 ;; *) blm_k=0 ;; esac
  if [ "$blm_k" = 1 ]; then
    mutant_killed "$(( ${B_BL2:-0} && ${B_BLCTL:-0} ))" BL-m5 "BL-m5 (the relevance scan no longer requires the \`\`\`derived fence): BL-2 goes red — the near-miss consumer's unfenced quotation of the same command is matched, and a citation nothing recorded is routed to the validator"
  else
    bad "BL-m5 SURVIVED: the near-miss consumer drew $BLM5_N with the fence requirement removed, no derivation row, so BL-2's derivation half is not testing that the scan reads the FENCE — an unfenced command naming a changed core path would route work that no derivation records"
  fi
  case "$BLM5_N" in
    0\|*) ok "BL-m5 and the passage field is untouched by it — still the unmutated 0 on the paraphrased layer line, so the derivation scan and the passage detector are separately gated" ;;
    *)    bad "BL-m5 also moved the passage field ($BLM5_N): the two sites are entangled" ;;
  esac
  bl_twin BL-m5 "$BLROOT/bl-m5" BL-1 "1|1|0|0" hit hit yes
else
  bad "BL-m5 did not apply — the derivation scan's fenced-command rule is no longer spelled \`infence && /^[[:blank:]]*\\\$ / {\`, so BL-2's derivation half is unproven against a scan that ignores the fence. Re-anchor it on the current spelling."
fi

# --- BL-m6: the WORKLIST row emitted whether or not the validator is there --------------------
#
# ANCHORED ON THE `elif` THAT SPLITS THE TWO BRANCHES, for the same reason BL-m5 is anchored
# where it is: the corpus guard and the join guard are both already satisfied on every world
# that reaches this site, so editing either changes nothing. The decision under test is which
# of the two branches a stranded-citation consumer lands in, and `[ -f "$VD_VALIDATOR" ]` on
# the first `elif` is the whole of it. Drop that conjunct and a consumer with no
# `validate-artifact-derivations.sh` is handed a WORKLIST row naming a script it does not have
# — work it cannot do, in the channel that withholds its stamp. BL-4's validator-absent half
# owns it; BL-4's empty-corpus half must stay green, because that world never reaches the
# branch at all.
if sed 's/^    elif \[ "\$VD_HITS" -gt 0 \] \&\& \[ -f "\$VD_VALIDATOR" \]; then$/    elif [ "$VD_HITS" -gt 0 ]; then/' \
     "$REC/apply.sh" | bl_mut "$BLROOT/bl-m6"; then
  # ONE RUN, ON THE DECIDING WORLD. The empty-corpus world never reaches the edited `elif`, so its
  # run could only repeat the unmutated answer; the non-entanglement claim is read off the deciding
  # vector's passage and unreadable fields, which must stay at the unmutated 1 and 0.
  BLM6_V="$(bl_mut_vec "$BLROOT/bl-m6" hit hit no)"
  case "$BLM6_V" in *\|1\|*) blm_k=1 ;; *) blm_k=0 ;; esac
  if [ "$blm_k" = 1 ]; then
    mutant_killed "$(( ${B_BL4:-0} && ${B_BLCTL:-0} ))" BL-m6 "BL-m6 (the WORKLIST branch stops asking whether the validator is present): BL-4's validator-absent half goes red — the consumer is handed a WORKLIST row naming a script that is not on its tree, and that row withholds its stamp"
  else
    bad "BL-m6 SURVIVED: the validator-absent consumer drew $BLM6_V, no WORKLIST row, so BL-4 is not testing the branch — the split is being made somewhere this mutation does not reach"
  fi
  if [ "$(printf '%s' "$BLM6_V" | cut -d'|' -f1)" = 1 ] && [ "$(printf '%s' "$BLM6_V" | cut -d'|' -f3)" = 0 ]; then
    ok "BL-m6 and only the branch split moved — the passage and unreadable fields stay at the unmutated 1 and 0, so the mutation reaches the WORKLIST/DECISION split and nothing upstream of it"
  else
    bad "BL-m6 also moved the passage or unreadable field ($BLM6_V): the mutation reaches more than the branch split, and BL-4's kill is not cleanly attributable"
  fi
  bl_twin BL-m6 "$BLROOT/bl-m6" BL-1 "1|1|0|0" hit hit yes
else
  bad "BL-m6 did not apply — the derivation site's WORKLIST branch is no longer spelled \`elif [ \"\$VD_HITS\" -gt 0 ] && [ -f \"\$VD_VALIDATOR\" ]; then\`, so BL-4 is unproven against a row that names an absent validator"
fi

# --- BL MUTANT-BY-ARM MATRIX: a re-measurement mode, never run per push ------------------------
# `bash core/fixtures/apply-restamp-worklist/run.sh --matrix` drives the unmutated copy and every
# BL mutant across every BL world and prints one `MATRIX` row each. The per-push twins above are
# read off it; the matrix is re-measured whenever an arm or mutant is added or changed.
if [ "$MATRIX" = 1 ]; then
  MX_CELLS=$((MX_CELLS + 1))
  mx_world() { # mx_world <rec> <name> -> "<name>=<vector>[/stamp/marker]"
    local r="$1" w="$2" v c
    case "$w" in
      both)     v="$(bl_mut_vec "$r" hit hit yes)" ;;
      near)     v="$(bl_mut_vec "$r" miss miss yes)" ;;
      nolayer)  v="$(bl_mut_vec "$r" none hit yes)" ;;
      noart)    v="$(bl_mut_vec "$r" hit none yes)" ;;
      zerobyte) v="$(bl_mut_vec "$r" none hitzero yes)" ;;
      noval)    v="$(bl_mut_vec "$r" hit hit no)" ;;
      emptyart) v="$(bl_mut_vec "$r" hit empty yes)" ;;
      finish)   v="$(bl_mut_vec "$r" hit hit yes --finish)"; c="$(bl_last_mut_consumer)"
                v="$v/$(sed -n 's/^version:[[:space:]]*//p' "$c/.claude/.ai-dlc-version" | head -1)/$([ -f "$c/.claude/.ai-dlc-applying" ] && echo PRESENT || echo GONE)" ;;
      sixb)     BL_DRIVE_THEIRS="${BL_NOCLS:-}"; v="$(bl_mut_vec "$r" none hit yes)"; BL_DRIVE_THEIRS="" ;;
      sixc)     v="$(bl_mut_vec "$r" none past yes)" ;;
      sixcc)    v="$(bl_mut_vec "$r" none cur yes)" ;;
    esac
    printf '%s=%s' "$w" "$v"
  }
  echo "MATRIX-BEGIN worlds(arm)=both(BL-1),near(BL-2),nolayer(BL-3/BL-6a),noart(BL-3),zerobyte(BL-3z),noval(BL-4),emptyart(BL-4),finish(BL-5 vec/stamp/marker),sixb(BL-6b),sixc(BL-6c),sixcc(BL-6c control) vector=row1|wl2|unreadable|unchecked"
  for _mr in mut-ctl bl-m1 bl-m2 bl-m3 bl-m4 bl-m5 bl-m6; do
    [ -f "$BLROOT/$_mr/apply.sh" ] || { bad "MATRIX $_mr has no staged copy, so its row cannot be measured"; continue; }
    _row="MATRIX $_mr"
    for _w in both near nolayer noart zerobyte noval emptyart finish sixb sixc sixcc; do
      _row="$_row $(mx_world "$BLROOT/$_mr" "$_w")"
    done
    echo "$_row"
  done
  echo "MATRIX-END"
fi

fi  # ---- end of the BL-S0 subject probe -------------------------------------------------------
fi  # ---- end of the BL-276 block ------------------------------------------------------------

fi  # ---- end of unit bl

# --- THE HOOK-REGISTRATION SEAM, shared by units hr and hu -------------------------------------
# Defined OUTSIDE both units because hr and hu are dealt to different shards, and a helper living
# inside one unit is undefined in the other's shard.
#
# WHY A SEAM, AND WHY IT IS NOT A COPY. Every row arm of hr and hu asks one question: what rows does
# `hook_registration_row` print over this tree? Driving a full `--finish` for each answer cost ~1s a
# world, 78 times across the two units, almost all of it in phases neither unit reads. The seam
# extracts `say`, `ap_stage`, `ap_staging_refused` and `hook_registration_row` VERBATIM from the
# apply.sh UNDER TEST -- the subject copy, or a mutant -- and calls that function with the globals
# `--finish` gives it (FINISH=1, a staging directory, CONSUMER/DIST/THEIRS). A mutant of the function
# is therefore seen by the seam exactly as by the program; nothing here restates its grammar. The
# seam's counters are apply.sh's own `say`, so `worklist_n` -- the value `--finish` gates the stamp
# on -- is read off the subject, not recomputed. HR-SEAM and HU-SEAM bind the seam to the program:
# on the worlds that also get an end-to-end run, the seam's rows must be BYTE-IDENTICAL to the
# hook-registration rows the full `--finish` printed over the same tree.
#
# THE WORLDS ARE READ-ONLY UNDER THE SEAM (the validator and the function read settings and hooks;
# staging goes to the seam's own mktemp), so each distinct world is built ONCE and every subject --
# the copy and each mutant -- is scored against the same tree. Rows land in files OUTSIDE the
# world, so a world stays the state it was built as.
hk_n()   { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {n++} END {print n+0}' "$1" 2>/dev/null || echo 0; }
hk_det() { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {print $4; exit}' "$1" 2>/dev/null; }
hk_sub() { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {print $3; exit}' "$1" 2>/dev/null; }
# hk_ran <rows> -> 0 when the seam reached its last line; hk_wl <rows> -> the seam's worklist_n, or -1
hk_ran() { awk -F'\t' '$1=="SEAM-RAN" {f=1} END {exit !f}' "$1" 2>/dev/null; }
hk_wl()  { awk -F'\t' '$1=="SEAM-RAN" {print $3; f=1; exit} END {if (!f) print -1}' "$1" 2>/dev/null; }
# The rows whose presence the hr arms key on. Anything else in a manifest is someone else's arm.
hk_any() {
  echo $(( $(hk_n "$1" WORKLIST settings-merge) + $(hk_n "$1" WORKLIST settings-local-dangling) \
         + $(hk_n "$1" DECISION hook-registration-unparsed) + $(hk_n "$1" DECISION hook-registration-unreadable) \
         + $(hk_n "$1" DECISION hook-registration-unchecked) ))
}
# hk_same_tree <copy> -> 0 when <copy> holds every file of $REC byte-identical (cmp -s) and nothing
# else. The copy is the subject every main arm runs on, so the main arms passing IS the control for
# the mutants built the same way; this is what makes that true rather than assumed.
# Counted with shell globs, NOT `ls`: `ls` is not in this fixture's tools.decl, so under
# hermetic-run it does not exist, the count reads empty, and the check refuses a correct copy.
hk_same_tree() {
  local f n=0 m=0
  for f in "$REC"/*; do
    [ -f "$f" ] || continue
    cmp -s "$f" "$1/${f##*/}" || return 1
    n=$((n+1))
  done
  for f in "$1"/* "$1"/.[!.]*; do [ -e "$f" ] && m=$((m+1)); done
  [ "$n" -gt 0 ] && [ "$n" = "$m" ]
}
# hk_seam <apply.sh> <consumer> <dist> <theirs> -> hook_registration_row's rows, then
# `SEAM-RAN <handback> <worklist_n>`. No SEAM-RAN line means the extraction or the call failed.
# hk_extract <file> <fn> -> the function's body, verbatim. GUARDED: the anchor occurs exactly once in
# <file>, the extraction is non-empty, its first line is the function's own header and its last is
# the closing brace. Anything else is FIXTURE BROKEN (exit 2) -- an empty or wrong extraction would
# otherwise run nothing and read as a subject that drew no row.
hk_extract() {
  local body n
  n="$(grep -c "^$2() {\$" "$1")" || n=0
  body="$(sed -n "/^$2() {\$/,/^}\$/p" "$1")"
  if [ "$n" != 1 ] || [ -z "$body" ] || [ "$(head -n 1 <<< "$body")" != "$2() {" ] \
     || [ "$(tail -n 1 <<< "$body")" != "}" ]; then
    echo "$NAME: FIXTURE BROKEN — the hook-registration seam could not extract $2() from $1 (header lines: $n)" >&2
    exit 2
  fi
  printf '%s\n' "$body"
}
hk_seam() {
  local fn st f x
  # Every extraction reads <apply.sh> -- the subject under test, mutated or not -- and nothing else.
  # `exit` inside `$( )` ends only the substitution, so the refusal is re-raised here, at the call
  # site; hk_seam is always called directly, never inside `$( )`, so this exit ends the fixture.
  fn=""
  for f in say ap_stage ap_staging_refused hook_registration_row; do
    x="$(hk_extract "$1" "$f")" || exit 2
    fn="$fn$x
"
  done
  st="$(mktemp -d "$WORK/hk-seam.XXXXXX")" || return 1
  CONSUMER="$2" DIST="$3" THEIRS="$4" AP_TMP="$st" bash -c '
    handback=0; worklist_n=0; reapply_owed=0; reapply_remedy="hk-seam: no reapply row is drawn here"
    FINISH=1; ap_stage_dead=0; ap_rerun_remedy="re-run --finish."
    NL_CH="
"
    '"$fn"'
    type hook_registration_row >/dev/null 2>&1 || exit 3
    hook_registration_row
    printf "SEAM-RAN\t%s\t%s\n" "$handback" "$worklist_n"' 2>/dev/null
}
# hk_ids <apply.sh> -> " id id ... " -- every row id `hook_registration_row` in <apply.sh> can say,
# DERIVED from the function's own `say` lines, not listed here. Called as `X="$(hk_ids ...)" || exit 2`.
hk_ids() {
  local ids body
  body="$(hk_extract "$1" hook_registration_row)" || exit 2
  ids="$(sed -n 's/.*say [A-Z][A-Z]* \([a-z][a-z-]*\) .*/\1/p' <<< "$body" | sort -u | tr '\n' ' ')"
  if [ -z "$ids" ]; then
    echo "$NAME: FIXTURE BROKEN — no row id derived from hook_registration_row() in $1" >&2; exit 2
  fi
  printf ' %s' "$ids"
}
# hk_only <rows> <ids> -> the rows of <rows> whose id is in <ids>
hk_only() { awk -F'\t' -v ids="$2" 'index(ids, " " $2 " ") > 0' "$1" 2>/dev/null; }

if sg hr; then
# ==============================================================================================
# BL-292 -- hook_registration_row() READS BOTH OF THE VALIDATOR'S FAILURE LISTS
# ==============================================================================================
#
# THE DEFECT. `validate-hook-registration.sh` prints two failure lists in two shapes: UNREGISTERED
# names carry a `.claude/hooks/` prefix, DANGLING names (registered, no file on disk) are printed
# BARE. The row parsed the prefix alone, so a tree whose only failure was a dangling registration
# exited 1 with nothing parsed and the function emitted NO row -- on `--finish` too, where it is
# the check that is meant to verify the finished tree. A `.claude/settings.json` holding `[]` was
# silent the same way: python raised, the validator exited 1 with no list, and the rc-1 arm keyed
# on names emitted nothing.
#
# WHY THE REAL VALIDATOR, AND NOT THE `exit 0` STUB C4/C8 USE. Every arm here is about the SHAPE
# of that program's output, so a stub would be a second implementation of the grammar the fix
# parses -- a seed derived from the reader's accept-set. Each world copies the shipped validator
# and `settings-merge.sh` (whose jq source the validator reads its ownership pattern out of) into
# a consumer built by `mk_consumer`, then seeds hook files and registrations.
#
# ONE WORLD PER STATE, THE ROWS THROUGH THE SEAM, THE STAMP END TO END. The eight worlds are built
# once. Every row cell is read off `hk_seam` over the subject copy. Two cells are about the STAMP,
# and each is one full `--finish` over its own world, one per distinct outcome: (e) WITHHELD over
# the dangling-only tree, and (d) STAMPED over a DECISION. The (e) run doubles as the HR-S0 subject
# probe, and HR-SEAM holds the seam to both runs' rows.
#
# THE ARMS, EACH PRESENCE-SHAPED (a row naming the hook must APPEAR):
#   (a) dangling-only                -> ONE `WORKLIST settings-merge` whose DANGLING list is
#                                       exactly the dangling hook. The validator follows that
#                                       list with its paste-able FIX block, whose first line is
#                                       indented like a list member (`    d="$(mktemp -d)" \`);
#                                       an exact list is what shows that line was not read as a
#                                       name.
#   (b) unregistered + dangling      -> the one settings-merge row names BOTH.
#   (c) dangling, registered ONLY in settings.local.json
#                                    -> `WORKLIST settings-local-dangling`, subject
#                                       `.claude/settings.local.json`, and NO settings-merge row:
#                                       settings-merge.sh never touches that file.
#   (d) settings.json is `[]`        -> `DECISION hook-registration-unparsed`, and --finish still
#                                       stamps over it (a DECISION does not raise worklist_n).
#   (e) --finish over (a)'s tree     -> the stamp is WITHHELD on the tree: version stays 1.0.0,
#                                       `.ai-dlc-applying` stays, `DECISION restamp-withheld`.
#                                       For a MUTANT, (e) is the seam's `worklist_n` over that
#                                       tree, which is the counter the withhold is decided on.
#   (f) near-misses. A clean tree draws no hook-registration row. A tree whose settings.local.json
#       registers a LIVE hook (file present, so the validator lists it under its NOTE, in the same
#       bare shape as a DANGLING name) must not have that hook named in either WORKLIST row -- the
#       NOTE list is not a failure list.
#   (g) dangling, registered in BOTH settings.json and settings.local.json
#                                    -> named in the settings-merge row AND in a
#                                       `settings-local-dangling` row. The validator's NOTE list is
#                                       `local - main`, so the name is under DANGLING alone; the
#                                       merge clears settings.json and leaves the local block, so a
#                                       merge-only remedy leaves the validator at exit 1.
#
# MUTANTS: M-a (DANGLING parse removed), M-b (the dangling clause OVERWRITES the unregistered text
# instead of appending), M-c (local-only split removed), M-d (unparsed DECISION removed), M-g (the
# direct settings.local.json read ignored). Each is scored ONLY on its deciding worlds plus one
# twin world it must leave holding, and must also show the REASON it removes in a named row -- so a
# mutant that broke the seam instead of the line cannot score. R4 -- the "first non-4-space line
# ends the block" stop removed alone -- is NOT scored: against today's validator the NOTE header IS
# that first line, so the NOTE-mode switch covers the stop and the stop covers the switch; removing
# either alone changes no row. That is recorded in apply.sh beside the parse; a seed that separates
# them needs a validator section that does not exist yet.

# hr_json <names> -> a settings document registering ai-dlc-hra-<name>.sh for each name
hr_json() {
  local n first=1
  printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":['
  for n in $1; do
    [ "$first" = 1 ] || printf ','
    first=0
    printf '{"type":"command","command":"bash \\"$CLAUDE_PROJECT_DIR\\"/.claude/hooks/ai-dlc-hra-%s.sh"}' "$n"
  done
  printf ']}]}}\n'
}
# hr_world <kind> -> prints a FRESH consumer dir. Every world is defined whole: its own mktemp
# directory, so nothing a previous world wrote can leak into the next one's shape.
hr_world() {
  local c on="alpha beta" main="alpha beta" loc="" h
  c="$(mktemp -d "$WORK/hr.XXXXXX")" || return 1
  # FINISHED: the stamp arms are driven through --finish, which verifies the tree before it
  # stamps, so a tree at base would be withheld for that and not for the row under test.
  mk_consumer "$c" finished || return 1
  cp "$HR_VAL_SRC" "$c/scripts/ai-dlc/validate-hook-registration.sh" || return 1
  chmod +x "$c/scripts/ai-dlc/validate-hook-registration.sh"
  mkdir -p "$c/.claude/hooks" "$c/.claude/skills/ai-dlc-update/reconcile" || return 1
  cp "$REC/settings-merge.sh" "$c/.claude/skills/ai-dlc-update/reconcile/" || return 1
  printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$c/.claude/.ai-dlc-applying"
  case "$1" in
    clean)     : ;;
    unreg)     main="beta" ;;
    dangling)  on="alpha" ;;
    both)      on="alpha"; main="beta" ;;
    localdg)   loc="ghost" ;;
    livelocal) on="alpha"; main="beta"; loc="alpha" ;;
    bothfiles) on="alpha"; loc="beta" ;;
    emptyarr)  : ;;
    *)         return 1 ;;
  esac
  for h in $on; do
    printf '#!/usr/bin/env bash\n# hra %s: a synthetic hook seeded by apply-restamp-worklist\nexit 0\n' "$h" \
      > "$c/.claude/hooks/ai-dlc-hra-$h.sh"
  done
  if [ "$1" = emptyarr ]; then printf '[]\n' > "$c/.claude/settings.json"
  else hr_json "$main" > "$c/.claude/settings.json"; fi
  [ -n "$loc" ] && hr_json "$loc" > "$c/.claude/settings.local.json"
  printf '%s' "$c"
}
# The world keys: D dangling (a, e), B both (b), L localdg (c), E emptyarr (d), C clean and
# V livelocal (f), G bothfiles (g), U unreg (the control's positive conjunct).
hr_kind() {
  case "$1" in
    D) echo dangling ;; B) echo both ;; L) echo localdg ;; E) echo emptyarr ;;
    C) echo clean ;; V) echo livelocal ;; G) echo bothfiles ;; U) echo unreg ;;
  esac
}
HR_R="$WORK/hr-rows"
# hr_seam_set <apply.sh> <tag> <world-key...> -> 0 when the seam ran over every named world;
# rows land in $HR_R/<tag>.<key>
hr_seam_set() {
  local a="$1" t="$2" K w
  shift 2
  for K in "$@"; do
    eval "w=\${HRW_$K:-}"
    [ -d "$w" ] || return 1
    hk_seam "$a" "$w" "$DIST" "$THEIRS" > "$HR_R/$t.$K"
    hk_ran "$HR_R/$t.$K" || return 1
  done
}
# The DANGLING list the settings-merge row prints, verbatim, between its label and the dash.
hr_dlist() {
  awk -v s="$(hk_det "$1" WORKLIST settings-merge)" 'BEGIN {
    i = index(s, "(DANGLING): "); if (i == 0) { print "<none>"; exit }
    r = substr(s, i + 12); j = index(r, "\342\200\224 "); if (j == 0) { print "<unterminated>"; exit }
    print substr(r, 1, j - 1) }'
}

# Every arm reads a ROWS file; (e)'s stamp half and (d)'s stamp half also read the world.
hr_arm_a() { # dangling-only
  [ "$(hk_n "$1" WORKLIST settings-merge)" = 1 ] && [ "$(hr_dlist "$1")" = "ai-dlc-hra-beta.sh " ]
}
hr_arm_b() { # unregistered + dangling
  local d; d="$(hk_det "$1" WORKLIST settings-merge)"
  [ "$(hk_n "$1" WORKLIST settings-merge)" = 1 ] && [ "$(hr_dlist "$1")" = "ai-dlc-hra-beta.sh " ] \
    && case "$d" in *"UNREGISTERED after this apply: ai-dlc-hra-alpha.sh "*) true ;; *) false ;; esac
}
hr_arm_c() { # local-only dangling
  [ "$(hk_n "$1" WORKLIST settings-local-dangling)" = 1 ] \
    && [ "$(hk_sub "$1" WORKLIST settings-local-dangling)" = ".claude/settings.local.json" ] \
    && case "$(hk_det "$1" WORKLIST settings-local-dangling)" in *"(DANGLING): ai-dlc-hra-ghost.sh "*) true ;; *) false ;; esac \
    && [ "$(hk_n "$1" WORKLIST settings-merge)" = 0 ]
}
hr_arm_d() { # settings.json is []
  [ "$(hk_n "$1" DECISION hook-registration-unparsed)" = 1 ] && [ "$(hk_n "$1" WORKLIST settings-merge)" = 0 ]
}
hr_arm_e() { # <world> <its end-to-end rows> -- --finish over the dangling-only tree withholds, read off the TREE
  [ "$(stamp_ver "$1")" = "1.0.0" ] && [ "$(marker "$1")" = PRESENT ] && [ "$(hk_n "$2" DECISION restamp-withheld)" -ge 1 ]
}
hr_arm_e_row() { # <seam rows> -- the counter that withhold is decided on, raised over the same tree
  [ "$(hk_wl "$1")" -ge 1 ]
}
hr_arm_f() { # <clean rows> <livelocal rows>
  local m l
  hk_ran "$1" && [ "$(hk_any "$1")" = 0 ] || return 1
  # POSITIVE CONJUNCT: some hook-registration row exists, so the absence below is about a run
  # that reached the row and not about one that emitted nothing.
  [ "$(hk_any "$2")" -ge 1 ] || return 1
  m="$(hk_det "$2" WORKLIST settings-merge)"; l="$(hk_det "$2" WORKLIST settings-local-dangling)"
  case "$m$l" in *ai-dlc-hra-alpha.sh*) return 1 ;; esac
  return 0
}
hr_arm_g() { # dangling in BOTH files -> both rows name it
  [ "$(hk_n "$1" WORKLIST settings-merge)" = 1 ] && [ "$(hr_dlist "$1")" = "ai-dlc-hra-beta.sh " ] \
    && [ "$(hk_n "$1" WORKLIST settings-local-dangling)" = 1 ] \
    && [ "$(hk_sub "$1" WORKLIST settings-local-dangling)" = ".claude/settings.local.json" ] \
    && case "$(hk_det "$1" WORKLIST settings-local-dangling)" in *"(DANGLING): ai-dlc-hra-beta.sh "*) true ;; *) false ;; esac
}
# hr_cell <cell> <tag> -> 1 (holds) / 0 (fails), read off the seam rows subject <tag> drew
hr_cell() {
  local r="$HR_R/$2"
  case "$1" in
    a) hr_arm_a "$r.D" ;; b) hr_arm_b "$r.B" ;; c) hr_arm_c "$r.L" ;; d) hr_arm_d "$r.E" ;;
    e) hr_arm_e_row "$r.D" ;; f) hr_arm_f "$r.C" "$r.V" ;; g) hr_arm_g "$r.G" ;;
    *) false ;;
  esac && echo 1 || echo 0
}

if [ -n "$HR_SKIP" ]; then
  if [ "$IS_DIST" = 1 ]; then
    bad "HR setup: $HR_SKIP — HARD in the distribution, every BL-292 arm would be unreadable"
  else
    printf '  SKIP  %s\n' "HR-a..HR-f and HR-M-a/c/d — $HR_SKIP"
  fi
else
HR_PRESENT=1
mkdir -p "$HR_R" || HR_PRESENT=0
# --- HR-CTL first half: the subject every arm below runs on is a byte-identical copy ------------
HR_SUB="$WORK/hr-sub"
if [ "$HR_PRESENT" = 0 ] || ! build_rec "$HR_SUB" || ! hk_same_tree "$HR_SUB"; then
  bad "HR-CTL could not stage a copy of $REC whose every file is cmp -s identical — FIXTURE BROKEN, no HR verdict below is read"
  HR_PRESENT=0
fi
if [ "$HR_PRESENT" = 1 ]; then
  for K in D B L E C V G U; do
    w="$(hr_world "$(hr_kind "$K")")" || w=""
    if [ ! -d "$w" ]; then
      bad "HR-S0 setup: could not build the $(hr_kind "$K") consumer"; HR_PRESENT=0; break
    fi
    eval "HRW_$K=\$w"
  done
fi
# --- HR-S0 SUBJECT PROBE: the pre-fix program is SILENT on a dangling-only tree ----------------
# That silence is the defect, so it is also the probe: an apply.sh with no hook-registration row
# of any kind over this tree predates BL-292. A consumer can receive this fixture a pull ahead of
# the apply.sh it tests; in the DISTRIBUTION the subject is always present, so absence is hard.
# This full `--finish` is also arm (e)'s run.
if [ "$HR_PRESENT" = 1 ]; then
  bash "$HR_SUB/apply.sh" --finish "$DIST" "$BASE" "$HRW_D" "$THEIRS" > "$HR_R/e2e.D" 2>/dev/null
  if [ "$(bash "$HRW_D/scripts/ai-dlc/validate-hook-registration.sh" --root "$HRW_D" >/dev/null 2>&1; echo $?)" != 1 ]; then
    bad "HR-S0 setup: the real validator does not exit 1 on the dangling-only world, so no arm below is scoring the shape BL-292 is about"; HR_PRESENT=0
  elif [ "$(hk_any "$HR_R/e2e.D")" = 0 ]; then
    HR_PRESENT=0
    if [ "$IS_DIST" = 1 ]; then
      bad "HR-S0 the resolved apply.sh ($APPLY) emitted NO hook-registration row over a tree whose validator exits 1 on a dangling registration — the BL-292 parse is absent. HARD in the distribution."
    else
      printf '  SKIP  %s\n' "HR-a..HR-f — the installed apply.sh predates the BL-292 DANGLING parse; it lands with a later pull than this fixture"
    fi
  else
    ok "HR-S0 the real validator exits 1 on the dangling-only world and the resolved apply.sh answers it with a hook-registration row, so the arms below score a subject that is present"
  fi
fi

if [ "$HR_PRESENT" = 1 ]; then
if ! hr_seam_set "$HR_SUB/apply.sh" sub D B L E C V G U; then
  bad "HR-SEAM setup: hook_registration_row could not be extracted from $HR_SUB/apply.sh and called over every world (no SEAM-RAN line) — FIXTURE BROKEN, no HR row verdict below is read"
  HR_PRESENT=0
fi
fi

if [ "$HR_PRESENT" = 1 ]; then
# (d)'s end-to-end run. It stamps, which moves `.ai-dlc-version` and removes `.ai-dlc-applying` --
# the only two files it writes, and neither is read by `hook_registration_row` or the validator, so
# the mutants that read this world after it still read the state it was built as.
bash "$HR_SUB/apply.sh" --finish "$DIST" "$BASE" "$HRW_E" "$THEIRS" > "$HR_R/e2e.E" 2>/dev/null

HR_IDS="$(hk_ids "$HR_SUB/apply.sh")" || exit 2
if [ "$(hk_any "$HR_R/e2e.D")" -ge 1 ] \
   && cmp -s <(hk_only "$HR_R/e2e.D" "$HR_IDS") <(hk_only "$HR_R/sub.D" "$HR_IDS") \
   && [ "$(hk_any "$HR_R/e2e.E")" -ge 1 ] \
   && cmp -s <(hk_only "$HR_R/e2e.E" "$HR_IDS") <(hk_only "$HR_R/sub.E" "$HR_IDS"); then
  ok "HR-SEAM the seam's hook-registration rows are byte-identical to the full --finish run's over the dangling-only and the [] trees, so every row cell below reads the function apply.sh runs"
else
  bad "HR-SEAM the seam and the full --finish disagree over the same tree (e2e D rows=$(hk_any "$HR_R/e2e.D"), seam D rows=$(hk_any "$HR_R/sub.D"); e2e [] rows=$(hk_any "$HR_R/e2e.E"), seam [] rows=$(hk_any "$HR_R/sub.E")) — the row cells below would score a function the program does not run"
fi

if hr_arm_a "$HR_R/sub.D"; then
  ok "HR-a a dangling-only tree draws ONE WORKLIST settings-merge row whose DANGLING list is exactly ai-dlc-hra-beta.sh — and not the validator's FIX line that follows the list at the same indent"; B_hra=1
else
  bad "HR-a the dangling-only tree drew settings-merge=$(hk_n "$HR_R/sub.D" WORKLIST settings-merge) with DANGLING list '$(hr_dlist "$HR_R/sub.D")', not one row listing exactly 'ai-dlc-hra-beta.sh ' — a registration Claude Code cannot run is not reaching the worklist (other rows: unparsed=$(hk_n "$HR_R/sub.D" DECISION hook-registration-unparsed))"
fi
if hr_arm_b "$HR_R/sub.B"; then
  ok "HR-b an unregistered hook AND a dangling one share the ONE settings-merge row, and it names both (alpha UNREGISTERED, beta DANGLING) — one merge clears both"; B_hrb=1
else
  bad "HR-b the unregistered+dangling tree drew settings-merge=$(hk_n "$HR_R/sub.B" WORKLIST settings-merge), DANGLING list '$(hr_dlist "$HR_R/sub.B")' — the row does not name both hooks"
fi
if hr_arm_c "$HR_R/sub.L"; then
  ok "HR-c a dangling hook registered ONLY in settings.local.json draws WORKLIST settings-local-dangling on .claude/settings.local.json naming ai-dlc-hra-ghost.sh, and NO settings-merge row — that merge never touches the file"; B_hrc=1
else
  bad "HR-c the local-only dangling tree drew settings-local-dangling=$(hk_n "$HR_R/sub.L" WORKLIST settings-local-dangling) (subject '$(hk_sub "$HR_R/sub.L" WORKLIST settings-local-dangling)') and settings-merge=$(hk_n "$HR_R/sub.L" WORKLIST settings-merge) — the operator is handed a remedy that cannot clear it, or none"
fi
if hr_arm_d "$HR_R/sub.E"; then
  ok "HR-d a settings.json holding [] draws DECISION hook-registration-unparsed — a non-zero exit that named nothing is not read as clean"; B_hrd=1
else
  bad "HR-d the [] tree drew unparsed=$(hk_n "$HR_R/sub.E" DECISION hook-registration-unparsed), settings-merge=$(hk_n "$HR_R/sub.E" WORKLIST settings-merge) — the validator failed without a list and the row said nothing"
fi
if [ "$(stamp_ver "$HRW_E")" = "$THEIRS_VER" ] && [ "$(marker "$HRW_E")" = GONE ]; then
  ok "HR-d and --finish still stamps over that DECISION — it raises handback, not worklist_n, so a missing interpreter cannot wedge the finisher"
else
  bad "HR-d --finish withheld over DECISION hook-registration-unparsed (stamp '$(stamp_ver "$HRW_E")', marker $(marker "$HRW_E")) — the C8 wedge, reached through the new row"
fi
if hr_arm_e "$HRW_D" "$HR_R/e2e.D"; then
  ok "HR-e --finish over the dangling-only tree WITHHOLDS on the tree: version 1.0.0, .ai-dlc-applying present, DECISION restamp-withheld"; B_hre=1
else
  bad "HR-e --finish over a dangling registration stamped (version '$(stamp_ver "$HRW_D")', marker $(marker "$HRW_D")) — the invocation meant to verify the finished tree passed a hook Claude Code cannot run"
fi
if hr_arm_f "$HR_R/sub.C" "$HR_R/sub.V"; then
  ok "HR-f near-misses: a clean tree draws no hook-registration row; a LIVE hook listed under the validator's settings.local.json NOTE is named in neither WORKLIST row, while that tree's real dangling hook still draws one"
else
  # The yes/no is computed BEFORE the message: a `case` inside `$( )` prints its own text instead
  # of its result under /bin/bash 3.2.57 (apply.sh documents the same hazard).
  HR_F_ALPHA=no
  case "$(hk_det "$HR_R/sub.V" WORKLIST settings-merge)$(hk_det "$HR_R/sub.V" WORKLIST settings-local-dangling)" in
    *ai-dlc-hra-alpha.sh*) HR_F_ALPHA=yes ;;
  esac
  bad "HR-f a near-miss fired: clean rows=$(hk_any "$HR_R/sub.C"); live-local tree rows=$(hk_any "$HR_R/sub.V"), settings-merge detail names alpha: $HR_F_ALPHA"
fi
if hr_arm_g "$HR_R/sub.G"; then
  ok "HR-g a dangling hook registered in BOTH settings.json and settings.local.json is named in the settings-merge row AND in a settings-local-dangling row on .claude/settings.local.json — the merge alone leaves the local block and the validator at exit 1"; B_hrg=1
else
  bad "HR-g the both-files tree drew settings-merge=$(hk_n "$HR_R/sub.G" WORKLIST settings-merge) (DANGLING list '$(hr_dlist "$HR_R/sub.G")') and settings-local-dangling=$(hk_n "$HR_R/sub.G" WORKLIST settings-local-dangling) — the validator's NOTE list excludes a name also in settings.json, so the operator is sent round twice"
fi

# --- HR-CTL second half: the positive conjunct --------------------------------------------------
# The copy is byte-identical (first half) and every arm above ran on it; this adds the one row no
# other arm demands on its own world, so a copy that reproduced only the dangling half cannot pass.
case "$(hk_det "$HR_R/sub.U" WORKLIST settings-merge)" in
  *"UNREGISTERED after this apply: ai-dlc-hra-alpha.sh "*) HRC_UOK=1 ;;
  *) HRC_UOK=0 ;;
esac
if [ "$HRC_UOK" = 1 ]; then
  ok "HR-CTL the subject is a cmp -s identical copy of $REC, it ran every arm above, and it emits the UNREGISTERED settings-merge row naming ai-dlc-hra-alpha.sh — so a mutant's cells below are the mutation and not the copy"; B_hrctl=1
else
  bad "HR-CTL the identical copy did not emit the UNREGISTERED settings-merge row naming ai-dlc-hra-alpha.sh (got '$(hk_det "$HR_R/sub.U" WORKLIST settings-merge)') — every HR mutant verdict below is unreadable"
fi

# --- HR MUTANTS -------------------------------------------------------------------------------
# Copies of the whole reconcile directory (`mut_apply`), `cmp -s`-guarded, each anchor asserted
# UNIQUE before the edit so a respelled anchor reports DID NOT APPLY rather than a silent no-op.
hr_mut() { # hr_mut <dir> <anchor-literal> ; transform on stdin
  local n; n="$(grep -cF -- "$2" "$REC/apply.sh")" || n=0
  [ "$n" = 1 ] || { cat >/dev/null; return 1; }
  mut_apply "$1"
}
# hr_mscore <flag> <label> <dir> <what> <worlds> <cells> <want> <reason-fn>
# Scored on the mutant's DECIDING worlds and one twin it must leave holding; <reason-fn> <label>
# must find the row the removed line's absence produces, so a mutant that killed its cells by
# breaking the seam cannot score.
hr_mscore() {
  local flag="$1" lab="$2" d="$3" what="$4" ws="$5" cs="$6" want="$7" why="$8" c v="" ones=""
  if ! hr_seam_set "$d/apply.sh" "$lab" $ws; then
    bad "$lab ($what): the seam did not run over {$ws} on the mutant — BROKEN, not a verdict"; return
  fi
  for c in $cs; do v="$v $(hr_cell "$c" "$lab")"; ones="$ones 1"; done
  v="${v# }"; ones="${ones# }"
  if [ "$v" = "$want" ] && "$why" "$lab"; then
    mutant_killed "$flag" "$lab" "$lab ($what): cells {$cs} over worlds {$ws} = $v — killed exactly the arms it owns, for the reason it removes"
  elif [ "$v" = "$ones" ]; then
    bad "$lab SURVIVED ($what): cells {$cs} all still hold ($v), so the arms it should kill are not testing that line"
  elif [ "$v" = "$want" ]; then
    bad "$lab ($what) scored $v as wanted but the row its removal produces is absent — it broke the cells some other way"
  else
    bad "$lab ($what) scored $v over {$cs}, want $want — it broke an arm it should not, or missed one it should, so the arms are entangled or one is vacuous"
  fi
}
hr_why_ma() { [ "$(hk_n "$HR_R/$1.D" DECISION hook-registration-unparsed)" = 1 ]; }
hr_why_mc() { case "$(hk_det "$HR_R/$1.L" WORKLIST settings-merge)" in *"(DANGLING): ai-dlc-hra-ghost.sh "*) true ;; *) false ;; esac; }
hr_why_md() { [ "$(hk_any "$HR_R/$1.E")" = 0 ]; }
hr_why_mb() {
  case "$(hk_det "$HR_R/$1.B" WORKLIST settings-merge)" in
    *"UNREGISTERED after this apply"*) false ;; *"(DANGLING): ai-dlc-hra-beta.sh "*) true ;; *) false ;;
  esac
}
hr_why_mg() { [ "$(hk_n "$HR_R/$1.G" WORKLIST settings-local-dangling)" = 0 ] && [ "$(hk_n "$HR_R/$1.G" WORKLIST settings-merge)" = 1 ]; }

# M-a: the DANGLING parse removed. The D list is also the ONLY source of a local-only dangling
# name (the split intersects it with the NOTE list), so (c) dies with (a)/(b)/(e) by construction:
# there is no DANGLING-less input on which (c) could hold. A dangling-only tree then exits 1 with
# nothing parsed, which the new rc!=0 branch reports as unparsed -- the reason row -- so (d) stays
# green as the twin, and (g) dies with the rest: its name reaches the function only through the D list.
HR_MA='    index($0, "  DANGLING ") == 1 { m = "D"; next }'
if awk -v a="$HR_MA" '$0 == a { next } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-ma" "$HR_MA"; then
  hr_mscore "$(( ${B_hrctl:-0} && ${B_hra:-0} && ${B_hrb:-0} && ${B_hrc:-0} && ${B_hrd:-0} && ${B_hre:-0} && ${B_hrg:-0} ))" "HR-M-a" "$WORK/hr-ma" "the DANGLING block parse deleted" "D B L E G" "a b c d e g" "0 0 0 1 0 0" hr_why_ma
else
  bad "HR-M-a DID NOT APPLY — the DANGLING parse line is no longer spelled \`$HR_MA\` exactly once in apply.sh; HR-a/b/e are unproven. Re-anchor it."
fi

# M-c: the local-only split removed -- the case subject is emptied, so no name ever matches the
# NOTE list and every dangling name lands on the settings-merge row that cannot clear it. (The
# direct settings.local.json read still adds a local row, so (c) dies on the extra merge row.)
# Twin (g): its local row comes from the direct read, which M-c leaves alone.
HR_MC='    case "$hr_local" in'
if awk -v a="$HR_MC" '$0 == a { print "    case \"\" in"; next } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-mc" "$HR_MC"; then
  hr_mscore "$(( ${B_hrctl:-0} && ${B_hrc:-0} && ${B_hrg:-0} ))" "HR-M-c" "$WORK/hr-mc" "the settings.local.json split deleted; local names go to settings-merge" "L G" "c g" "0 1" hr_why_mc
else
  bad "HR-M-c DID NOT APPLY — \`$HR_MC\` is not in apply.sh exactly once; HR-c is unproven. Re-anchor it."
fi

# M-d: the unparsed DECISION removed -- its branch made unreachable, leaving rc!=0-with-no-names
# silent exactly as before the fix. Twin (a): rc 1 WITH names never reaches that branch.
HR_MD='  elif [ "$hr_rc" != "0" ]; then'
if awk -v a="$HR_MD" '$0 == a { print "  elif false; then"; next } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-md" "$HR_MD"; then
  hr_mscore "$(( ${B_hrctl:-0} && ${B_hra:-0} && ${B_hrd:-0} ))" "HR-M-d" "$WORK/hr-md" "the hook-registration-unparsed branch made unreachable" "D E" "a d" "1 0" hr_why_md
else
  bad "HR-M-d DID NOT APPLY — \`$HR_MD\` is not in apply.sh exactly once; HR-d is unproven. Re-anchor it."
fi

# M-b: the dangling clause OVERWRITES hr_what instead of appending, so a tree with an unregistered
# AND a dangling hook loses the unregistered name. Only (b) seeds both at once; twin (a) has no
# unregistered text to lose.
HR_MB='    [ -n "$hr_dangle" ] && hr_what="${hr_what}hook(s) REGISTERED'
if awk -v a="$HR_MB" 'index($0, a) == 1 { sub(/hr_what="\$\{hr_what\}hook/, "hr_what=\"hook") } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-mb" "$HR_MB"; then
  hr_mscore "$(( ${B_hrctl:-0} && ${B_hra:-0} && ${B_hrb:-0} ))" "HR-M-b" "$WORK/hr-mb" "the dangling clause overwrites the unregistered text" "D B" "a b" "1 0" hr_why_mb
else
  bad "HR-M-b DID NOT APPLY — \`$HR_MB\` is not in apply.sh exactly once; HR-b's mixed row is unproven. Re-anchor it."
fi

# M-g: the direct settings.local.json read ignored -- a name in both files goes to the merge only.
# Twin (c): a local-only name is routed by the NOTE split, which M-g leaves alone.
HR_MG='                    case "$hr_inlocal" in'
if awk -v a="$HR_MG" 'index($0, a) == 1 { sub(/case "\$hr_inlocal" in/, "case \"\" in") } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-mg" "$HR_MG"; then
  hr_mscore "$(( ${B_hrctl:-0} && ${B_hrc:-0} && ${B_hrg:-0} ))" "HR-M-g" "$WORK/hr-mg" "the direct settings.local.json read ignored" "L G" "c g" "1 0" hr_why_mg
else
  bad "HR-M-g DID NOT APPLY — \`$HR_MG\` is not in apply.sh exactly once; HR-g is unproven. Re-anchor it."
fi

# --- HR MUTANT-BY-ARM MATRIX: a re-measurement mode, never run per push ------------------------
# Every HR mutant (and the unmutated copy) scored on EVERY world, all seven cells, one `MATRIX` row each.
if [ "$MATRIX" = 1 ]; then
  MX_CELLS=$((MX_CELLS + 1))
  echo "MATRIX-BEGIN hr cells=a(D),b(B),c(L),d(E),e(D rows),f(C+V),g(G) vector per mutant: a b c d e f g"
  for _mr in sub ma mc md mb mg; do
    _d="$WORK/hr-$_mr"; [ "$_mr" = sub ] && _d="$HR_SUB"
    if ! hr_seam_set "$_d/apply.sh" "mx$_mr" D B L E C V G U; then
      bad "MATRIX hr-$_mr: the seam did not run over every world — its row cannot be measured"; continue
    fi
    case "$_mr" in sub) _id=HR-CTL ;; *) _id="HR-M-${_mr#m}" ;; esac # the id its mutant_killed call carries
    _row="MATRIX $_id"
    for _c in a b c d e f g; do _row="$_row $_c=$(hr_cell "$_c" "mx$_mr")"; done
    echo "$_row"
  done
  echo "MATRIX-END hr"
fi
fi  # ---- end of HR_PRESENT
fi  # ---- end of the BL-292 block

fi  # ---- end of unit hr

if sg hu; then
# ==============================================================================================
# BL-103 -- AN UNREGISTERED ai-dlc- HOOK THEIRS NEITHER SHIPS NOR REGISTERS GETS ITS OWN ROW
# ==============================================================================================
#
# THE DEFECT. The `settings-merge` row prescribed the settings reconcile for every unregistered
# hook, and that merge registers only the TEMPLATE's hooks -- it strips every other `ai-dlc-*`
# block from settings.json. A hook upstream retired (apply emits `DECISION deletion` and never
# removes the file) therefore left the validator at exit 1 after the row's own remedy, and
# `--finish` withheld on every run with no in-band exit.
#
# ITS OWN DIST, because the partition is keyed on THEIRS' `templates/settings.json.template` and
# `core/hooks/`, and the global DIST carries neither -- which is also why every HR arm above is
# unchanged: with no template at THEIRS there is nothing to partition against, and the old row
# stands. Every world is FINISHED and runs the REAL validator.
#
# THE CELLS, each presence-shaped. The rows come from the seam (`hk_seam`, above unit hr); the
# stamp comes from a full `--finish`, one per distinct outcome, on (a)'s tree:
#   (a) orphan            ai-dlc-gone.sh on disk, in neither set -> WORKLIST hook-unshipped naming
#                         it, NOT named in a settings-merge row; end to end, the stamp WITHHELD.
#   (b) exit 3            (a)'s tree, the hook then registered in settings.local.json -> no gating
#                         row; end to end, --finish stamps.
#   (c) exit 1            an orphan deleted -> no gating row (the worklist count --finish gates on
#                         is 0, the state (b)'s end-to-end run stamps over).
#   (t) near-misses       ai-dlc-tmplonly.sh (template, not core/hooks) and ai-dlc-shipped.sh
#                         (core/hooks, not template), both unregistered -> ONE settings-merge row
#                         naming both, and no hook-unshipped row. Each name is the only seed that
#                         kills one half of the partition.
# MUTANTS: HU-M1 partition switched off, HU-M2 the core/hooks conjunct dropped, HU-M3 the template
# test made to match nothing, HU-M4 the row demoted to NOTE, HU-M5 the merge list not narrowed.
# Each is scored on the two worlds that decide them -- orphan (a) and near (t) -- where it must
# kill its own cell, leave the other holding, and show the row its edit produces.
HU_RUN=1
if [ -n "${HR_SKIP:-}" ]; then
  HU_RUN=0
  if [ "$IS_DIST" = 1 ]; then bad "HU setup: ${HR_SKIP} — HARD in the distribution"
  else printf '  SKIP  %s\n' "HU-a..HU-t — $HR_SKIP"; fi
elif ! grep -qF 'say WORKLIST hook-unshipped' "$APPLY"; then
  if [ "$IS_DIST" = 1 ]; then
    printf '  --    (BL-103: this apply.sh carries no hook-unshipped row; in the distribution the HU arms run anyway and must go red)\n'
  else
    HU_RUN=0
    printf '  SKIP  %s\n' "HU-a..HU-t — the installed apply.sh predates the hook-unshipped row; it lands with the pull that carries this fixture"
  fi
fi
if [ "$HU_RUN" = 1 ]; then
HU_D="$WORK/hu-dist"
mkdir -p "$HU_D/core/hooks" "$HU_D/core/session-driver" "$HU_D/templates" || exit 2
hu_g() { git -C "$HU_D" -c user.email=f@f -c user.name=fixture "$@"; }
hu_hook() { printf '#!/usr/bin/env bash\n# hu: a synthetic hook seeded by apply-restamp-worklist\nexit 0\n' > "$1" && chmod +x "$1"; }
hu_reg() { # hu_reg <file> <names...> -- in the template's own command spelling
  local f="$1" n first=1; shift
  { printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":['
    for n in "$@"; do [ "$first" = 1 ] || printf ','; first=0
      printf '{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/%s"}' "$n"; done
    printf ']}]}}\n'; } > "$f"
}
hu_hook "$HU_D/core/hooks/ai-dlc-kept.sh"; hu_hook "$HU_D/core/hooks/ai-dlc-shipped.sh"
hu_reg "$HU_D/templates/settings.json.template" ai-dlc-kept.sh ai-dlc-tmplonly.sh
printf '#!/usr/bin/env bash\n# hu s v1\n' > "$HU_D/core/session-driver/hu.sh"
printf '1.0.0\n' > "$HU_D/VERSION"
git -C "$HU_D" init -q 2>/dev/null && hu_g add -A && hu_g commit -qm base || { echo "FIXTURE BROKEN — HU base" >&2; exit 2; }
HU_B="$(git -C "$HU_D" rev-parse HEAD)"
printf '2.0.0\n' > "$HU_D/VERSION"; printf '#!/usr/bin/env bash\n# hu s v2\n' > "$HU_D/core/session-driver/hu.sh"
hu_g add -A && hu_g commit -qm theirs || { echo "FIXTURE BROKEN — HU theirs" >&2; exit 2; }
HU_T="$(git -C "$HU_D" rev-parse HEAD)"
# hu_world <kind> -> a FRESH finished consumer
hu_world() {
  local c main="ai-dlc-kept.sh ai-dlc-shipped.sh ai-dlc-tmplonly.sh"
  c="$(mktemp -d "$WORK/hu.XXXXXX")" || return 1
  mkdir -p "$c/.claude/hooks" "$c/.claude/session-driver" "$c/scripts/ai-dlc" "$c/.claude/skills/ai-dlc-update/reconcile" || return 1
  git -C "$HU_D" show "${HU_T}:core/session-driver/hu.sh" > "$c/.claude/session-driver/hu.sh" || return 1
  cp "$HR_VAL_SRC" "$c/scripts/ai-dlc/validate-hook-registration.sh" && chmod +x "$c/scripts/ai-dlc/validate-hook-registration.sh" || return 1
  cp "$REC/settings-merge.sh" "$c/.claude/skills/ai-dlc-update/reconcile/" || return 1
  hu_hook "$c/.claude/hooks/ai-dlc-kept.sh"; hu_hook "$c/.claude/hooks/ai-dlc-shipped.sh"; hu_hook "$c/.claude/hooks/ai-dlc-tmplonly.sh"
  case "$1" in
    orphan) hu_hook "$c/.claude/hooks/ai-dlc-gone.sh" ;;
    near)   main="ai-dlc-kept.sh" ;;
    *)      return 1 ;;
  esac
  hu_reg "$c/.claude/settings.json" $main
  printf 'version: 1.0.0\ncommit: %s\n' "$HU_B" > "$c/.claude/.ai-dlc-version"
  printf 'base: %s\ntheirs: %s\n' "$HU_B" "$HU_T" > "$c/.claude/.ai-dlc-applying"
  printf '%s' "$c"
}
HU_R="$WORK/hu-rows"
hu_seam() { # <apply.sh> <tag> <world-key> <world> -> 0 when the seam ran; rows in $HU_R/<tag>.<key>
  hk_seam "$1" "$4" "$HU_D" "$HU_T" > "$HU_R/$2.$3"
  hk_ran "$HU_R/$2.$3"
}
hu_fin() { bash "$1" --finish "$HU_D" "$HU_B" "$2" "$HU_T" > "$3" 2>/dev/null; } # <apply.sh> <world> <rows-out>
hu_arm_a() { # <rows> -- the orphan's own gating row, and the merge row does not claim it
  [ "$(hk_n "$1" WORKLIST hook-unshipped)" = 1 ] \
    && case "$(hk_det "$1" WORKLIST hook-unshipped)" in *": ai-dlc-gone.sh "*) true ;; *) false ;; esac \
    && ! case "$(hk_det "$1" WORKLIST settings-merge)" in *ai-dlc-gone.sh*) true ;; *) false ;; esac \
    && [ "$(hk_wl "$1")" -ge 1 ]
}
hu_arm_t() { # <rows> -- both near-miss names on the ONE merge row, no hook-unshipped row
  [ "$(hk_n "$1" WORKLIST hook-unshipped)" = 0 ] && [ "$(hk_n "$1" WORKLIST settings-merge)" = 1 ] \
    && case "$(hk_det "$1" WORKLIST settings-merge)" in *ai-dlc-shipped.sh*) true ;; *) false ;; esac \
    && case "$(hk_det "$1" WORKLIST settings-merge)" in *ai-dlc-tmplonly.sh*) true ;; *) false ;; esac
}
hu_quiet() { hk_ran "$1" && [ "$(hk_wl "$1")" = 0 ]; } # <rows> -- the seam ran and raised no WORKLIST

HU_OK=1
mkdir -p "$HU_R" || HU_OK=0
HU_SUB="$WORK/hu-sub"
if [ "$HU_OK" = 0 ] || ! build_rec "$HU_SUB" || ! hk_same_tree "$HU_SUB"; then
  bad "HU-CTL could not stage a copy of $REC whose every file is cmp -s identical — FIXTURE BROKEN, no HU verdict below is read"
  HU_OK=0
fi
if [ "$HU_OK" = 1 ]; then
  HUW_O="$(hu_world orphan)"; HUW_N="$(hu_world near)"; HUW_X="$(hu_world orphan)"
  rm -f "$HUW_X/.claude/hooks/ai-dlc-gone.sh"
  for x in "$HUW_O" "$HUW_N" "$HUW_X"; do [ -d "$x" ] || HU_OK=0; done
  [ "$HU_OK" = 1 ] || bad "HU setup: could not build the orphan / near / deleted-orphan consumers — FIXTURE BROKEN"
fi
if [ "$HU_OK" = 1 ] && ! { hu_seam "$HU_SUB/apply.sh" sub O "$HUW_O" && hu_seam "$HU_SUB/apply.sh" sub N "$HUW_N" \
                         && hu_seam "$HU_SUB/apply.sh" sub X "$HUW_X"; }; then
  bad "HU-SEAM setup: hook_registration_row could not be extracted from $HU_SUB/apply.sh and called over every world (no SEAM-RAN line) — FIXTURE BROKEN"
  HU_OK=0
fi
if [ "$HU_OK" = 1 ]; then
# SELF-PROBE, first half: the real validator exits 1 on the orphan world, or (a) would score the
# validator rather than the row.
hu_p1="$(bash "$HUW_O/scripts/ai-dlc/validate-hook-registration.sh" --root "$HUW_O" >/dev/null 2>&1; echo $?)"
# (a) end to end: the orphan world, withheld.
hu_fin "$HU_SUB/apply.sh" "$HUW_O" "$HU_R/e2e.O"
HU_IDS="$(hk_ids "$HU_SUB/apply.sh")" || exit 2
if [ "$(hk_n "$HU_R/e2e.O" WORKLIST hook-unshipped)" -ge 1 ] \
   && cmp -s <(hk_only "$HU_R/e2e.O" "$HU_IDS") <(hk_only "$HU_R/sub.O" "$HU_IDS"); then
  ok "HU-SEAM the seam's hook-registration rows are byte-identical to the full --finish run's over the orphan tree, so every HU row cell reads the function apply.sh runs"
else
  bad "HU-SEAM the seam and the full --finish disagree over the orphan tree (e2e hook-unshipped=$(hk_n "$HU_R/e2e.O" WORKLIST hook-unshipped), seam=$(hk_n "$HU_R/sub.O" WORKLIST hook-unshipped)) — the HU row cells would score a function the program does not run"
fi
if hu_arm_a "$HU_R/sub.O" && [ "$(stamp_ver "$HUW_O")" = 1.0.0 ] && [ "$(marker "$HUW_O")" = PRESENT ]; then
  ok "HU-a an ai-dlc- hook theirs neither ships nor registers draws WORKLIST hook-unshipped naming it, the settings-merge row does not claim it, and --finish withholds on the tree"; B_hua=1
else
  bad "HU-a the orphan hook did not draw its own gating row, or --finish stamped over it (hook-unshipped=$(hk_n "$HU_R/sub.O" WORKLIST hook-unshipped), stamp '$(stamp_ver "$HUW_O")', marker $(marker "$HUW_O")) — the operator is sent to a merge that cannot clear it"
fi
if hu_quiet "$HU_R/sub.X"; then
  ok "HU-c exit 1 — deleting the file — leaves no gating row, the state --finish stamps over (HU-b, end to end)"
else
  bad "HU-c deleting the orphan still drew a gating row (worklist_n=$(hk_wl "$HU_R/sub.X")) — the finisher stays withheld"
fi
if hu_arm_t "$HU_R/sub.N"; then
  ok "HU-t a hook in the template only and one in core/hooks only both stay on the ONE settings-merge row, and no hook-unshipped row fires"; B_hut=1
else
  bad "HU-t a template-carried or shipped hook was routed off the settings-merge row (hook-unshipped=$(hk_n "$HU_R/sub.N" WORKLIST hook-unshipped), settings-merge=$(hk_n "$HU_R/sub.N" WORKLIST settings-merge))"
fi

# --- HU MUTANTS, scored before (a)'s tree is moved to (b) ---------------------------------------
# hu_cell <cell> <tag> -> 1/0; a reads the orphan world, t the near world
hu_cell() {
  case "$1" in
    a) hu_arm_a "$HU_R/$2.O" ;; t) hu_arm_t "$HU_R/$2.N" ;; *) false ;;
  esac && echo 1 || echo 0
}
hu_mut() { # <dir> <anchor-literal> <replacement-literal>
  local n; n="$(grep -cF -- "$2" "$REC/apply.sh")" || n=0
  [ "$n" = 1 ] || return 1
  HU_A="$2" HU_R_="$3" awk '{ i = index($0, ENVIRON["HU_A"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["HU_R_"] substr($0, i + length(ENVIRON["HU_A"])); print }' \
    "$REC/apply.sh" | mut_apply "$1"
}
hu_why_m1() { case "$(hk_det "$HU_R/$1.O" WORKLIST settings-merge)" in *ai-dlc-gone.sh*) true ;; *) false ;; esac; }
hu_why_m2() { case "$(hk_det "$HU_R/$1.N" WORKLIST hook-unshipped)" in *ai-dlc-shipped.sh*) true ;; *) false ;; esac; }
hu_why_m3() { case "$(hk_det "$HU_R/$1.N" WORKLIST hook-unshipped)" in *ai-dlc-tmplonly.sh*) true ;; *) false ;; esac; }
hu_why_m4() { [ "$(hk_n "$HU_R/$1.O" NOTE hook-unshipped)" = 1 ]; }
hu_why_m5() { [ "$(hk_n "$HU_R/$1.O" WORKLIST hook-unshipped)" = 1 ] && hu_why_m1 "$1"; }
hu_try() { # <label> <dir> <anchor> <replacement> <want "a t"> <what> <reason-fn>
  local v
  if ! hu_mut "$2" "$3" "$4"; then bad "$1 DID NOT APPLY — \`$3\` is not in apply.sh exactly once; re-anchor it"; return; fi
  if ! { hu_seam "$2/apply.sh" "$1" O "$HUW_O" && hu_seam "$2/apply.sh" "$1" N "$HUW_N"; }; then
    bad "$1 ($6): the seam did not run on the mutant — BROKEN, not a verdict"; return
  fi
  v="$(hu_cell a "$1") $(hu_cell t "$1")"
  if [ "$v" = "$5" ] && "$7" "$1"; then mutant_killed "$(( ${B_hua:-0} && ${B_hut:-0} ))" "$1" "$1 ($6): HU cells a t = $v — killed exactly the arms it owns, for the reason it removes"
  elif [ "$v" = "1 1" ]; then bad "$1 SURVIVED ($6): every HU arm still holds"
  elif [ "$v" = "$5" ]; then bad "$1 ($6) scored $v as wanted but the row its edit produces is absent — it broke the cells some other way"
  else bad "$1 ($6) scored $v, want $5 — entangled or vacuous"; fi
}
hu_try HU-M1 "$WORK/hu-m1" 'if [ "$hr_tmpl_rc" -eq 0 ] \' 'if false \' "0 1" "the partition switched off" hu_why_m1
hu_try HU-M2 "$WORK/hu-m2" '&& ! git -C "$DIST" cat-file -e "${THEIRS}:core/hooks/${_hn}" 2>/dev/null; then' '; then' "1 0" "the core/hooks conjunct dropped" hu_why_m2
hu_try HU-M3 "$WORK/hu-m3" '*"/hooks/${_hn}"[!A-Za-z0-9._-]*) hr_merge_names=' '__hu_never__) hr_merge_names=' "1 0" "the template test matches nothing" hu_why_m3
hu_try HU-M4 "$WORK/hu-m4" 'say WORKLIST hook-unshipped' 'say NOTE hook-unshipped' "0 1" "the row demoted to a non-gating NOTE" hu_why_m4
hu_try HU-M5 "$WORK/hu-m5" '  hr_names="$hr_merge_names"' '  :' "0 1" "the settings-merge list not narrowed" hu_why_m5


# --- HU MUTANT-BY-ARM MATRIX: a re-measurement mode, never run per push ------------------------
if [ "$MATRIX" = 1 ]; then
  MX_CELLS=$((MX_CELLS + 1))
  echo "MATRIX-BEGIN hu cells=a(O),t(N),x(X quiet) vector per mutant: a t x"
  for _mr in sub m1 m2 m3 m4 m5; do
    _d="$WORK/hu-$_mr"; [ "$_mr" = sub ] && _d="$HU_SUB"
    if ! { hu_seam "$_d/apply.sh" "mx$_mr" O "$HUW_O" && hu_seam "$_d/apply.sh" "mx$_mr" N "$HUW_N" \
           && hu_seam "$_d/apply.sh" "mx$_mr" X "$HUW_X"; }; then
      bad "MATRIX hu-$_mr: the seam did not run over every world — its row cannot be measured"; continue
    fi
    _x=0; hu_quiet "$HU_R/mx$_mr.X" && _x=1
    case "$_mr" in sub) _id=HU-CTL ;; *) _id="HU-M${_mr#m}" ;; esac
    echo "MATRIX $_id a=$(hu_cell a "mx$_mr") t=$(hu_cell t "mx$_mr") x=$_x"
  done
  echo "MATRIX-END hu"
fi

# (b) on (a)'s own tree: the row's remedy, then the seam and --finish again.
hu_reg "$HUW_O/.claude/settings.local.json" ai-dlc-gone.sh
hu_p2="$(bash "$HUW_O/scripts/ai-dlc/validate-hook-registration.sh" --root "$HUW_O" >/dev/null 2>&1; echo $?)"
if [ "$hu_p1" = 1 ] && [ "$hu_p2" = 0 ]; then
  ok "HU-0 the real validator exits 1 on an orphan ai-dlc- hook and 0 once settings.local.json registers it — exit 3 is a real exit"
else
  bad "HU-0 the validator read $hu_p1 on the orphan world and $hu_p2 after a local registration (want 1 then 0) — the HU arms would score the validator, not the row"
fi
hu_seam "$HU_SUB/apply.sh" sub R "$HUW_O" >/dev/null 2>&1
hu_fin "$HU_SUB/apply.sh" "$HUW_O" "$HU_R/e2e.R"
if hu_quiet "$HU_R/sub.R" && [ "$(stamp_ver "$HUW_O")" = 2.0.0 ] && [ "$(marker "$HUW_O")" = GONE ]; then
  ok "HU-b exit 3 — registering it in .claude/settings.local.json — clears the gating row and lets --finish stamp 2.0.0 and clear the marker"
else
  bad "HU-b the row's own exit 3 left the finisher withheld (worklist_n=$(hk_wl "$HU_R/sub.R"), stamp '$(stamp_ver "$HUW_O")', marker $(marker "$HUW_O"))"
fi
# HU-CTL: the subject is the cmp -s identical copy, and it reproduced every HU arm above.
if hu_arm_a "$HU_R/sub.O" && hu_arm_t "$HU_R/sub.N" && hu_quiet "$HU_R/sub.X" && hu_quiet "$HU_R/sub.R"; then
  ok "HU-CTL the subject is a cmp -s identical copy of $REC and it scores every HU arm, so a mutant's cells above are the mutation and not the copy"; B_huctl=1
else
  bad "HU-CTL the identical copy did not score every HU arm — every HU mutant verdict above is unreadable"
fi
fi  # ---- end of HU_OK
fi  # ---- end of the BL-103 block

fi  # ---- end of unit hu

if sg vf; then
# ==============================================================================================
# VF -- `--finish` VERIFIES THE TREE IT STAMPS
# ==============================================================================================
#
# THE DEFECT. `--finish` skips the resolution phases, so `mech_fail` is always 0 there, and the
# finisher printed `RESOLVED consistent "the tree matches <theirs>"` over any tree handed to it --
# including one where no file had ever been applied. The stamp is the next pull's merge base, so a
# tree left at base and stamped at theirs mis-bases the following merge silently.
#
# WHAT THE FIX DOES, AND THEREFORE WHAT THESE ARMS READ. Under `--finish`, after the identity check
# and only when it did not refuse: BASE must be a commit whose `core/` tree is the tree of the
# stamp's `commit:`; then preclassify's OWN buckets are read, and every row in a pure-apply bucket
# (the ones phase 1 answers by overwriting from theirs) is a `WORKLIST finish-unapplied` row, which
# withholds the stamp. A CLASSIFY row never counts, so a hand-merged file cannot wedge the finisher,
# and preclassify reads `.dist-only` AT THEIRS, so a dist-only fixture that was correctly never
# written is not unapplied work.
#
# ITS OWN DIST. The pull at the top of this file changes one file per shape; these arms need TWO
# changed files with the unapplied one NOT first in ls-tree order (`a-first` < `m-added` <
# `z-second`), an ADDED file, a `.dist-only` fixture added in range, and a shipping fixture that is
# modified in range -- so a scan that stops at its first changed path, or that exempts only added
# files, reads differently from one that scans the set. VF-S1 asserts that shape before any arm.
#
# EVERY ARM IS KEYED ON BEHAVIOUR: the stamp's `commit:`/`version:`, the marker on disk, and the
# emitted row's KIND and SUBJECT, compared as an exact set where the arm is about which file.
VFROOT="$WORK/vf"; VD="$VFROOT/dist"; VDW="$VFROOT/dist-wt"
VF_OK=1
mkdir -p "$VD/core/session-driver" "$VD/core/scripts" "$VD/core/fixtures/ship-fx" || VF_OK=0
[ "$VF_OK" = 1 ] && { git -C "$VD" init -q 2>/dev/null || VF_OK=0; }
vfgit() { git -C "$VD" -c user.email=f@f -c user.name=fixture "$@"; }
VB=""; VT=""; VO=""
if [ "$VF_OK" = 1 ]; then
  printf '1.0.0\n' > "$VD/VERSION"
  printf '#!/usr/bin/env bash\necho v\n' > "$VD/core/scripts/validate-synthetic.sh"
  printf '# a v1\n'    > "$VD/core/session-driver/a-first.sh"
  printf '# z v1\n'    > "$VD/core/session-driver/z-second.sh"
  printf '# ship v1\n' > "$VD/core/fixtures/ship-fx/run.sh"
  vfgit add -A >/dev/null 2>&1 && vfgit commit -q -m vf-base >/dev/null 2>&1 || VF_OK=0
  VB="$(git -C "$VD" rev-parse HEAD 2>/dev/null)"
  printf '2.0.0\n' > "$VD/VERSION"
  printf '# a v2 UPSTREAM\n'    > "$VD/core/session-driver/a-first.sh"
  printf '# z v2 UPSTREAM\n'    > "$VD/core/session-driver/z-second.sh"
  printf '# m added UPSTREAM\n' > "$VD/core/session-driver/m-added.sh"
  printf '# ship v2 UPSTREAM\n' > "$VD/core/fixtures/ship-fx/run.sh"
  mkdir -p "$VD/core/fixtures/dist-fx" || VF_OK=0
  printf '# dist-only fixture\n' > "$VD/core/fixtures/dist-fx/run.sh"
  printf 'its subject is a distribution-only program\n' > "$VD/core/fixtures/dist-fx/.dist-only"
  vfgit add -A >/dev/null 2>&1 && vfgit commit -q -m vf-theirs >/dev/null 2>&1 || VF_OK=0
  VT="$(git -C "$VD" rev-parse HEAD 2>/dev/null)"
  # VO: `core/` genuinely moved again -- the ref a fumbled finisher names in VF-R6.
  printf '3.0.0\n' > "$VD/VERSION"
  printf '# a v3 OTHER\n' > "$VD/core/session-driver/a-first.sh"
  vfgit add -A >/dev/null 2>&1 && vfgit commit -q -m vf-other >/dev/null 2>&1 || VF_OK=0
  VO="$(git -C "$VD" rev-parse HEAD 2>/dev/null)"
  # The operator's checkout sits AT theirs, so the working tree and THEIRS agree on every marker.
  vfgit checkout -q --detach "$VT" >/dev/null 2>&1 || VF_OK=0
  # VDW: the same history, checkout at theirs, working tree DISAGREEING with THEIRS in both
  # directions about `.dist-only` -- dist-fx's marker removed, ship-fx given one.
  git clone -q "$VD" "$VDW" >/dev/null 2>&1 && git -C "$VDW" checkout -q --detach "$VT" >/dev/null 2>&1 || VF_OK=0
  rm -f "$VDW/core/fixtures/dist-fx/.dist-only"
  printf 'a working-tree-only marker THEIRS does not carry\n' > "$VDW/core/fixtures/ship-fx/.dist-only"
fi
VT_SHORT="$(git -C "$VD" rev-parse --short "$VT" 2>/dev/null)"

# vf_consumer <dir> <none|noadd|zonly|full|merged|noship>
#   none    installed at VB, nothing applied
#   noadd   theirs applied except the ADDED core file
#   zonly   theirs applied except z-second, which is NOT first in ls-tree order
#   full    theirs applied; dist-fx (dist-only at THEIRS) correctly never written
#   merged  full, with a-first hand-merged to differ from BOTH base and theirs
#   noship  full, with ship-fx (a SHIPPING fixture, modified in range) left at base
vf_consumer() {
  local c="$1" st="$2" p cp
  mkdir -p "$c/.claude" "$c/scripts/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$c/scripts/ai-dlc/validate-hook-registration.sh"
  chmod +x "$c/scripts/ai-dlc/validate-hook-registration.sh"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    cp="$(seed_map "$p")"
    mkdir -p "$(dirname "$c/$cp")" && git -C "$VD" show "${VB}:${p}" > "$c/$cp" || return 1
  done <<< "$(git -C "$VD" ls-tree -r --name-only "$VB" -- core/ 2>/dev/null)"
  [ "$st" = none ] || seed_ref "$VD" "$VB" "$VT" "$c" || return 1
  case "$st" in
    none|full) : ;;
    noadd)  rm -f "$c/.claude/session-driver/m-added.sh" ;;
    zonly)  git -C "$VD" show "${VB}:core/session-driver/z-second.sh" > "$c/.claude/session-driver/z-second.sh" ;;
    merged) printf '# a v1 and v2 hand-merged by the operator\n' > "$c/.claude/session-driver/a-first.sh" ;;
    noship) git -C "$VD" show "${VB}:core/fixtures/ship-fx/run.sh" > "$c/tests/fixtures/ship-fx/run.sh" ;;
    *) return 1 ;;
  esac
  printf 'version: 1.0.0\ncommit: %s\n' "$VB" > "$c/.claude/.ai-dlc-version"
  printf 'base: %s\ntheirs: %s\n' "$VB" "$VT" > "$c/.claude/.ai-dlc-applying"
}
# vf_run <rec> <state> <dist> <base-argv> <theirs-argv> -> sets VF_C; rows in $VF_C/.vf-rows
VF_C=""
vf_run() {
  VF_C="$(mktemp -d "$VFROOT/c.XXXXXX")" || return 1
  vf_consumer "$VF_C" "$2" || return 1
  ( cd "${VF_CWD:-$PWD}" && bash "$1/apply.sh" --finish "$3" "$4" "$VF_C" "$5" ) > "$VF_C/.vf-rows" 2>/dev/null
  return 0
}
vf_n()    { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {n++} END {print n+0}' "$1/.vf-rows" 2>/dev/null; }
vf_subj() { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {print $3}' "$1/.vf-rows" 2>/dev/null | sort | tr '\n' ' '; }
# Withheld AT BASE, read off the tree: the stamp's commit is still VB, the marker is still there.
vf_held()  { [ "$(stamp_sha "$1")" = "$VB" ] && [ "$(stamp_ver "$1")" = 1.0.0 ] && [ "$(marker "$1")" = PRESENT ] \
               && [ "$(vf_n "$1" DECISION restamp-withheld)" -ge 1 ]; }
vf_stamp() { [ "$(stamp_sha "$1")" = "$VT_SHORT" ] && [ "$(stamp_ver "$1")" = 2.0.0 ] && [ "$(marker "$1")" = GONE ] \
               && [ "$(vf_n "$1" RESOLVED restamp)" -ge 1 ] && [ "$(vf_n "$1" WORKLIST finish-unapplied)" = 0 ]; }

vf_r1() { vf_run "$1" none "$VD" "$VB" "$VT" || return 1
  vf_held "$VF_C" && case " $(vf_subj "$VF_C" WORKLIST finish-unapplied)" in *" .claude/session-driver/z-second.sh "*) true ;; *) false ;; esac; }
# vf_names <consumer> <must-name> <must-not-name...> -- keyed on the file that decides and on the
# APPLIED files beside it, not on the whole set: an exact set would also move under a mutant that
# adds an unrelated row (the dist-only one), and one mutant must fail only its own arm.
vf_names() {
  local s x; s=" $(vf_subj "$1" WORKLIST finish-unapplied)"; shift
  case "$s" in *" $1 "*) : ;; *) return 1 ;; esac; shift
  for x in "$@"; do case "$s" in *" $x "*) return 1 ;; esac; done
  return 0
}
vf_r2() { vf_run "$1" noadd "$VD" "$VB" "$VT" || return 1
  vf_held "$VF_C" && vf_names "$VF_C" .claude/session-driver/m-added.sh \
    .claude/session-driver/a-first.sh .claude/session-driver/z-second.sh tests/fixtures/ship-fx/run.sh; }
vf_ro() { vf_run "$1" zonly "$VD" "$VB" "$VT" || return 1
  vf_held "$VF_C" && vf_names "$VF_C" .claude/session-driver/z-second.sh \
    .claude/session-driver/a-first.sh .claude/session-driver/m-added.sh tests/fixtures/ship-fx/run.sh; }
vf_r3() { vf_run "$1" full "$VD" "$VB" "$VT" || return 1
  vf_stamp "$VF_C" && [ ! -e "$VF_C/tests/fixtures/dist-fx" ]; }
vf_r4() { vf_run "$1" merged "$VD" "$VB" "$VT" || return 1
  vf_stamp "$VF_C" && grep -q 'hand-merged' "$VF_C/.claude/session-driver/a-first.sh"; }
vf_r5() { vf_run "$1" none "$VD" "$VT" "$VT" || return 1
  vf_held "$VF_C" && [ "$(vf_n "$VF_C" WORKLIST finish-base-unverified)" = 1 ]; }
vf_r5b() {
  if [ "$1" = "$REC" ] && [ -n "${VF_PROBE_C:-}" ]; then VF_C="$VF_PROBE_C"; else vf_run "$1" none "$VD" vf-no-such-base-ref "$VT" || return 1; fi
  vf_held "$VF_C" && [ "$(vf_n "$VF_C" WORKLIST finish-base-unverified)" = 1 ]; }
# R6 IS NOT `vf_held`: an identity refusal is the `restamp-identity-mismatch` branch of the
# re-stamp, reached because nothing raised `worklist_n`, so no `restamp-withheld` row prints. The
# stamp and marker are read directly, as F1 reads them.
vf_r6() { vf_run "$1" none "$VD" "$VB" "$VO" || return 1
  [ "$(stamp_sha "$VF_C")" = "$VB" ] && [ "$(stamp_ver "$VF_C")" = 1.0.0 ] && [ "$(marker "$VF_C")" = PRESENT ] \
    && [ "$(vf_n "$VF_C" DECISION restamp-identity-mismatch)" = 1 ] \
    && [ "$(vf_n "$VF_C" WORKLIST finish-unapplied)" = 0 ] && [ "$(vf_n "$VF_C" WORKLIST finish-base-unverified)" = 0 ] \
    && [ "$(vf_n "$VF_C" WORKLIST finish-unverified-tree)" = 0 ]; }
# DO1 reads preclassify's own row for each fixture, against the SKEWED working tree.
vf_do1() {
  local c rows
  c="$(mktemp -d "$VFROOT/c.XXXXXX")" && vf_consumer "$c" none || return 1
  rows="$(bash "$1/preclassify.sh" "$VDW" "$VB" "$VT" "$c" 2>/dev/null)"
  [ "$(awk -F'\t' '$2=="core/fixtures/dist-fx/run.sh" {print $4}' <<< "$rows")" = DIST-ONLY-SKIP ] \
    && [ "$(awk -F'\t' '$2=="core/fixtures/ship-fx/run.sh" {print $4}' <<< "$rows")" = UPSTREAM-ONLY ]
}
vf_do2() { vf_run "$1" full "$VDW" "$VB" "$VT" || return 1; vf_stamp "$VF_C"; }
vf_do3() { vf_run "$1" noship "$VDW" "$VB" "$VT" || return 1
  vf_held "$VF_C" && vf_names "$VF_C" tests/fixtures/ship-fx/run.sh \
    .claude/session-driver/a-first.sh .claude/session-driver/m-added.sh .claude/session-driver/z-second.sh; }
VF_ARMS="r1 r2 ro r3 r4 r5 r5b r6 do1 do2 do3"
vf_vec() { # vf_vec <rec> -> one 1/0 per arm, in VF_ARMS order
  local a v=""
  for a in $VF_ARMS; do
    if "vf_$a" "$1"; then v="$v 1"; else v="$v 0"; fi
  done
  printf '%s' "${v# }"
}

if [ "$VF_OK" != 1 ] || [ -z "$VB" ] || [ -z "$VT" ] || [ -z "$VO" ] || [ -z "$VT_SHORT" ]; then
  bad "VF setup: could not build the verified-finish dist (base='${VB:-<none>}' theirs='${VT:-<none>}' other='${VO:-<none>}') — every VF arm would be unreadable"
else

# --- VF-S1: THE RANGE HAS THE SHAPE THE ARMS NEED ---------------------------------------------
VF_NS="$(git -C "$VD" diff --name-status --no-renames "$VB" "$VT" -- core/ 2>/dev/null | tr '\t' ' ' | tr '\n' '|')"
VF_ORDER="$(git -C "$VD" ls-tree -r --name-only "$VT" -- core/session-driver/ 2>/dev/null | tr '\n' ' ')"
if [ "$VF_NS" = "A core/fixtures/dist-fx/.dist-only|A core/fixtures/dist-fx/run.sh|M core/fixtures/ship-fx/run.sh|M core/session-driver/a-first.sh|A core/session-driver/m-added.sh|M core/session-driver/z-second.sh|" ] \
   && [ "$VF_ORDER" = "core/session-driver/a-first.sh core/session-driver/m-added.sh core/session-driver/z-second.sh " ] \
   && [ "$(git -C "$VD" rev-parse "${VO}:core" 2>/dev/null)" != "$(git -C "$VD" rev-parse "${VT}:core" 2>/dev/null)" ]; then
  ok "VF-S1 setup: base..theirs modifies two core files (a-first, z-second), ADDS one (m-added, between them in ls-tree order), adds a .dist-only fixture and modifies a shipping one; the other ref differs from theirs in core/"
else
  bad "VF-S1 setup: the range is not the shape the VF arms need (name-status '$VF_NS', ls-tree order '$VF_ORDER') — a first-path-only or an added-file-blind scan could not be told apart from the fix"
fi

# --- VF-S2: THE FINISHED SEED IS WHAT THE ORDINARY APPLY WRITES -------------------------------
# seed_ref is hand-written; the producer of a finished tree is apply.sh's ordinary run. Both are
# built from the same installed-at-base consumer and compared byte for byte over the range, and the
# ordinary run must not have written the dist-only fixture either.
VF_S2A="$(mktemp -d "$VFROOT/s2a.XXXXXX")"; VF_S2S="$(mktemp -d "$VFROOT/s2s.XXXXXX")"
if vf_consumer "$VF_S2A" none && vf_consumer "$VF_S2S" full; then
  rm -f "$VF_S2A/.claude/.ai-dlc-applying"
  bash "$APPLY" "$VD" "$VB" "$VF_S2A" "$VT" >/dev/null 2>&1
  if same_on_range "$VD" "$VB" "$VT" "$VF_S2S" "$VF_S2A" && [ ! -e "$VF_S2A/tests/fixtures/dist-fx" ] \
     && grep -q UPSTREAM "$VF_S2A/.claude/session-driver/z-second.sh"; then
    ok "VF-S2 setup: the 'full' seed is byte-identical over the range to the tree apply.sh's ordinary run writes, and neither writes the dist-only fixture"
  else
    bad "VF-S2 setup: the 'full' seed and the ordinary apply's tree differ over base..theirs, so the VF arms are finishing a tree the real producer never makes"
  fi
else
  bad "VF-S2 setup: could not build the seed-provenance consumers"
fi
# The main pull's `finished` seed, against the ordinary run C3 already drove over C_GREEN.
C_S4="$WORK/cons-s4"
if mk_consumer "$C_S4" finished && same_on_range "$DIST" "$BASE" "$THEIRS" "$C_S4" "$C_GREEN"; then
  ok "S4 setup: the 'finished' seed every --finish world above uses is byte-identical over base..theirs to what the ordinary apply wrote into C_GREEN"
else
  bad "S4 setup: the 'finished' seed differs from the ordinary apply's tree over base..theirs — C4, C8, F*, U4 and HR-* are finishing a tree the real producer never makes"
fi

# --- VF-S3: THE SKEWED CHECKOUT DISAGREES WITH THEIRS IN BOTH DIRECTIONS ----------------------
if [ ! -e "$VDW/core/fixtures/dist-fx/.dist-only" ] && [ -f "$VDW/core/fixtures/ship-fx/.dist-only" ] \
   && git -C "$VDW" cat-file -e "${VT}:core/fixtures/dist-fx/.dist-only" 2>/dev/null \
   && ! git -C "$VDW" cat-file -e "${VT}:core/fixtures/ship-fx/.dist-only" 2>/dev/null; then
  ok "VF-S3 setup: the skewed dist checkout LACKS dist-fx's .dist-only that THEIRS carries and HAS a ship-fx .dist-only THEIRS lacks — a working-tree read and a THEIRS read answer oppositely on both"
else
  bad "VF-S3 setup: the skewed checkout does not disagree with THEIRS in both directions, so VF-DO1..3 cannot tell a THEIRS-keyed dist_only() from a working-tree one"
fi

# --- VF0 SUBJECT PROBE ------------------------------------------------------------------------
# A consumer can hold this fixture a pull ahead of the apply.sh it tests. The probe is the
# unresolvable-BASE world: the pre-fix finisher stamps it with no row at all. In the DISTRIBUTION
# the subject must be present, so absence is a failure AND the arms still run, so the run says
# which of them the absent subject fails.
VF_PRESENT=1
vf_run "$REC" none "$VD" vf-no-such-base-ref "$VT"
VF_PROBE_C="$VF_C"   # VF0's world IS VF-R5b's state; vf_r5b reads it for the shipped program instead of building a second one
if [ "$(vf_n "$VF_C" WORKLIST finish-base-unverified)" = 0 ]; then
  VF_PRESENT=0
  if [ "$IS_DIST" = 1 ]; then
    bad "VF0 the resolved apply.sh ($APPLY) emitted no WORKLIST finish-base-unverified over a --finish naming an unresolvable base, so the verified finish is absent. HARD in the distribution; the arms below run anyway"
  else
    printf '  SKIP  %s\n' "VF-R1..VF-DO3 and VF-m* — the installed apply.sh predates the verified --finish; it lands with this same pull"
  fi
else
  ok "VF0 the resolved apply.sh withholds over an unresolvable base with its own WORKLIST row, so the verified finish is present"
fi

if [ "$VF_PRESENT" = 1 ] || [ "$IS_DIST" = 1 ]; then
vf_report() { # vf_report <arm-fn> <label> <ok-text> <bad-text>
  if "$1" "$REC"; then ok "$2 $3"
    case "$1" in
      vf_r1) B_vf_r1=1 ;; vf_r2) B_vf_r2=1 ;; vf_ro) B_vf_ro=1 ;; vf_r3) B_vf_r3=1 ;; vf_r4) B_vf_r4=1 ;;
      vf_r5) B_vf_r5=1 ;; vf_r5b) B_vf_r5b=1 ;; vf_r6) B_vf_r6=1 ;; vf_do1) B_vf_do1=1 ;; vf_do2) B_vf_do2=1 ;; vf_do3) B_vf_do3=1 ;;
    esac
  else
    bad "$2 $4 (stamp '$(stamp_ver "$VF_C") @ $(stamp_sha "$VF_C")', marker $(marker "$VF_C"), finish-unapplied: '$(vf_subj "$VF_C" WORKLIST finish-unapplied)', base-unverified=$(vf_n "$VF_C" WORKLIST finish-base-unverified), identity-mismatch=$(vf_n "$VF_C" DECISION restamp-identity-mismatch))"
  fi
}
vf_report vf_r1 VF-R1 "nothing applied: --finish withholds, the stamp stays at base, the marker stays, and z-second is named unapplied" \
  "--finish over a tree where NOTHING was applied did not withhold naming z-second"
vf_report vf_r2 VF-R2 "only the ADDED file missing: --finish withholds naming exactly .claude/session-driver/m-added.sh" \
  "--finish over a tree missing only the file this range ADDED did not withhold naming exactly that file"
vf_report vf_ro VF-RO "two changed files, the unapplied one NOT first in ls-tree order: --finish withholds naming exactly z-second" \
  "--finish with a-first applied and z-second still at base did not withhold naming exactly z-second — a scan that stops at its first changed path reads this tree as finished"
vf_report vf_r3 VF-R3 "fully applied, the .dist-only fixture added in range and correctly absent: --finish stamps 2.0.0 @ $VT_SHORT and clears the marker" \
  "--finish over a FULLY APPLIED tree did not stamp — a correctly finished consumer is wedged"
vf_report vf_r4 VF-R4 "a hand-merged file (differs from base AND theirs): --finish stamps and leaves the merge in place" \
  "--finish over a tree with a hand-merged file did not stamp — a merged file must never count as unapplied"
vf_report vf_r5 VF-R5 "BASE typed as THEIRS: --finish withholds with WORKLIST finish-base-unverified over a tree where nothing was applied" \
  "--finish with BASE typed as THEIRS did not withhold on the base — an empty range acquits every file"
vf_report vf_r5b VF-R5b "BASE unresolvable: --finish withholds with WORKLIST finish-base-unverified" \
  "--finish naming an unresolvable BASE did not withhold with finish-base-unverified"
vf_report vf_r6 VF-R6 "identity mismatch over an unapplied tree: the identity row prints, and NO finish-unapplied / finish-base-unverified / finish-unverified-tree row is computed against the fumbled ref" \
  "--finish naming a ref the marker disputes, over an unapplied tree, did not print the identity row alone"
vf_report vf_do1 VF-DO1 "preclassify classifies by THEIRS against a skewed checkout: dist-fx (marker at THEIRS, not on disk) is DIST-ONLY-SKIP, ship-fx (marker on disk, not at THEIRS) is UPSTREAM-ONLY" \
  "preclassify's dist_only() did not answer from THEIRS against a checkout that disagrees with it"
vf_report vf_do2 VF-DO2 "and --finish over the fully applied tree, driven from that skewed checkout, still stamps" \
  "--finish from a checkout lacking a .dist-only that THEIRS carries withheld over a correctly finished tree"
vf_report vf_do3 VF-DO3 "and with the SHIPPING fixture left at base, driven from that skewed checkout, --finish withholds naming exactly tests/fixtures/ship-fx/run.sh" \
  "--finish from a checkout carrying a .dist-only THEIRS lacks acquitted a shipping fixture that was never applied"
# CWD: the decisive withhold, re-driven from `/`.
if VF_CWD=/ vf_r1 "$REC"; then
  ok "VF-CWD VF-R1 driven from / reaches the same withheld verdict"
else
  bad "VF-CWD VF-R1 driven from / did not withhold (stamp '$(stamp_ver "$VF_C")', marker $(marker "$VF_C")) — some VF path resolves from the process cwd"
fi

# --- VF MUTANTS -------------------------------------------------------------------------------
# Copies of the whole reconcile directory; every anchor asserted to occur EXACTLY ONCE in the file
# it edits, and the copy asserted to DIFFER from the original, before any verdict is read. Each is
# scored on the whole arm vector so an entangled kill cannot hide.
VF_WANT_CTL="1 1 1 1 1 1 1 1 1 1 1"
vf_mut() { # vf_mut <dir> <apply.sh|preclassify.sh> <anchor-line> <replacement>
  local n; n="$(grep -cxF -- "$3" "$REC/$2")" || n=0
  [ "$n" = 1 ] || return 1
  build_rec "$1" || return 1
  VF_A="$3" VF_R="$4" awk '$0 == ENVIRON["VF_A"] { print ENVIRON["VF_R"]; next } { print }' "$REC/$2" > "$1/$2" || return 1
  [ -f "$1/preclassify.sh" ] && [ -f "$1/lib.sh" ] || return 1
  ! cmp -s "$REC/$2" "$1/$2"
}
# vf_score <flag> <label> <dir> <decides> <twins> <what it did> -- PER PUSH: the mutant runs on the arm(s) it must kill and the
# green twin(s) it must leave holding (the measured `--matrix` rows record the rest). The kill needs every arm it names
# to have held on the shipped program in this run (B_vf_<arm>) AND the copy-under-test control (B_vfctl).
vf_score() {
  local bf="$1" lab="$2" d="$3" dec="$4" tw="$5" what="$6" a ok=1 got=""
  for a in $dec; do if "vf_$a" "$d"; then ok=0; got="$got $a=1"; else got="$got $a=0"; fi; done
  for a in $tw; do if "vf_$a" "$d"; then got="$got $a=1"; else ok=0; got="$got $a=0"; fi; done
  if [ "$ok" = 1 ]; then
    mutant_killed "$bf" "$lab" "$lab ($what): killed {$dec} and left {$tw} holding —$got"
  elif [ -z "$(printf '%s' "$got" | grep -F '=0')" ]; then
    bad "$lab SURVIVED ($what): every arm still holds ($got)"
  else
    bad "$lab ($what) scored$got, want {$dec} red and {$tw} holding — it moved an arm it should not, or missed one it should"
  fi
}
# THE COPY UNDER TEST IS THE CONTROL: the staged copy must be byte-identical to the shipped directory, and a
# positive arm (R1: the withhold that names z-second) must hold on it. R1 is the deciding withhold arm, so a copy
# that cannot run reads as broken here and not as clean.
if build_rec "$WORK/vf-ctl"; then
  vfc_same=1
  for f in "$REC"/*; do cmp -s "$f" "$WORK/vf-ctl/$(basename "$f")" || vfc_same=0; done
  if [ "$vfc_same" = 1 ] && vf_r1 "$WORK/vf-ctl"; then
    ok "VF-CTL the staged copy is byte-identical to $REC and holds VF-R1, so a mutant's verdict below is the mutation and not the copy"; B_vfctl=1
  else
    bad "VF-CTL the staged copy differs from $REC or does not hold VF-R1 — every VF mutant verdict below is unreadable"
  fi
else
  bad "VF-CTL could not stage a copy of $REC — every VF mutant verdict below is unreadable"
fi

VF_CASE='      UPSTREAM-ONLY|UPSTREAM-ONLY-ADD|*SETUP-TOKENS*)'
# m-cmp: count a row whenever the consumer copy differs from theirs' blob, instead of reading
# preclassify's bucket. The design the fix's own header records as built and refuted.
if vf_mut "$WORK/vf-mcmp" apply.sh "$VF_CASE" \
  '      *) if [ "$_fv_bucket" = DIST-ONLY-SKIP ] || [ "$(git -C "$DIST" show "${THEIRS}:${_fv_path}" 2>/dev/null | git hash-object --stdin)" = "$(git hash-object "$CONSUMER/$_fv_cons" 2>/dev/null)" ]; then continue; fi'; then
  vf_score "$(( ${B_vfctl:-0} && ${B_vf_r4:-0} && ${B_vf_r1:-0} ))" VF-m-cmp "$WORK/vf-mcmp" "r4" "r1" "compare each copy to theirs' blob instead of preclassify's pure-apply buckets"
else
  bad "VF-m-cmp DID NOT APPLY — \`$VF_CASE\` is not in apply.sh exactly once; VF-R4 is unproven"
fi
# m-distonly: the dist-only exemption dropped -- DIST-ONLY-SKIP counted as unapplied. R3 OWNS it.
# It also kills R4 and DO2, and that overlap is the property rather than an entanglement: every
# world that STAMPS is finished over a range that adds the dist-only fixture, so without the
# exemption no finished tree over that range can ever stamp. R4's own subject is the merge (m-cmp),
# DO2's is the skewed checkout (m-wt); each of them has its own mutant that R3 does not see.
if vf_mut "$WORK/vf-mdo" apply.sh "$VF_CASE" '      UPSTREAM-ONLY|UPSTREAM-ONLY-ADD|*SETUP-TOKENS*|DIST-ONLY-SKIP)'; then
  vf_score "$(( ${B_vfctl:-0} && ${B_vf_r3:-0} && ${B_vf_r4:-0} && ${B_vf_do2:-0} && ${B_vf_r1:-0} ))" VF-m-distonly "$WORK/vf-mdo" "r3 r4 do2" "r1" "a DIST-ONLY-SKIP row counted as unapplied"
else
  bad "VF-m-distonly DID NOT APPLY — \`$VF_CASE\` is not in apply.sh exactly once; VF-R3 is unproven"
fi
# m-noadd: the added-file half dropped -- UPSTREAM-ONLY-ADD not counted.
if vf_mut "$WORK/vf-mna" apply.sh "$VF_CASE" '      UPSTREAM-ONLY|*SETUP-TOKENS*)'; then
  vf_score "$(( ${B_vfctl:-0} && ${B_vf_r2:-0} && ${B_vf_r1:-0} ))" VF-m-noadd "$WORK/vf-mna" "r2" "r1" "an UPSTREAM-ONLY-ADD row not counted"
else
  bad "VF-m-noadd DID NOT APPLY — \`$VF_CASE\` is not in apply.sh exactly once; VF-R2 is unproven"
fi
# m-first: only the first classified changed path is looked at (dist-only rows skipped, then stop).
VF_LOOP='    [ -n "${_fv_bucket:-}" ] || continue'
if vf_mut "$WORK/vf-mfp" apply.sh "$VF_LOOP" "$VF_LOOP
    [ -n \"\${_fv_one:-}\" ] && break
    case \"\$_fv_bucket\" in DIST-ONLY-SKIP) continue ;; esac
    _fv_one=1"; then
  vf_score "$(( ${B_vfctl:-0} && ${B_vf_r1:-0} && ${B_vf_r2:-0} && ${B_vf_ro:-0} && ${B_vf_r3:-0} ))" VF-m-first "$WORK/vf-mfp" "r1 r2 ro" "r3" "only the first changed path is checked"
else
  bad "VF-m-first DID NOT APPLY — \`$VF_LOOP\` is not in apply.sh exactly once; VF-RO is unproven"
fi
# m-order: the tree check no longer gated on the identity verdict, so it runs against a fumbled ref.
VF_GATE='  [ -z "$finish_id_mismatch" ] && finish_verify_tree'
if vf_mut "$WORK/vf-mor" apply.sh "$VF_GATE" '  finish_verify_tree'; then
  vf_score "$(( ${B_vfctl:-0} && ${B_vf_r6:-0} && ${B_vf_r1:-0} ))" VF-m-order "$WORK/vf-mor" "r6" "r1" "the tree check runs whatever the identity check decided"
else
  bad "VF-m-order DID NOT APPLY — \`$VF_GATE\` is not in apply.sh exactly once; VF-R6 is unproven"
fi
# m-base: BASE trusted from argv -- every base finding discarded just before it is read. One edit
# reverts every layer of the base check (commit, stamp present, commit: line, tree equality).
VF_WHY='  if [ -n "$_fv_why" ]; then'
if vf_mut "$WORK/vf-mbs" apply.sh "$VF_WHY" "  _fv_why=\"\"
$VF_WHY"; then
  vf_score "$(( ${B_vfctl:-0} && ${B_vf_r5:-0} && ${B_vf_r5b:-0} && ${B_vf_r1:-0} ))" VF-m-base "$WORK/vf-mbs" "r5 r5b" "r1" "BASE trusted from argv, never checked against the stamp"
else
  bad "VF-m-base DID NOT APPLY — \`$VF_WHY\` is not in apply.sh exactly once; VF-R5/R5b are unproven"
fi
# m-wt: preclassify's dist_only() reading the dist WORKING TREE again -- the pre-fix spelling. The
# THEIRS read is memo_has_path since BL-374 (its 128 is the absent marker); an installed
# preclassify.sh that predates that still carries the bare `cat-file -e`, so the mutant targets
# whichever spelling the subject carries.
VF_DO='      memo_has_path "$DIST" "$THEIRS" "core/fixtures/${_f}/.dist-only" || _do_rc=$?'
VF_DO_R='      [ -f "$DIST/core/fixtures/$_f/.dist-only" ] || _do_rc=128'
if ! grep -qxF -- "$VF_DO" "$REC/preclassify.sh"; then
  VF_DO='      git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${_f}/.dist-only" 2>/dev/null'
  VF_DO_R='      [ -f "$DIST/core/fixtures/$_f/.dist-only" ]'
fi
if vf_mut "$WORK/vf-mwt" preclassify.sh "$VF_DO" "$VF_DO_R"; then
  vf_score "$(( ${B_vfctl:-0} && ${B_vf_do1:-0} && ${B_vf_do2:-0} && ${B_vf_do3:-0} && ${B_vf_r1:-0} ))" VF-m-wt "$WORK/vf-mwt" "do1 do2 do3" "r1" "dist_only() reads the dist working tree instead of THEIRS"
else
  bad "VF-m-wt DID NOT APPLY — \`$VF_DO\` is not in preclassify.sh exactly once; VF-DO1..3 are unproven"
fi

# --- VF MUTANT-BY-ARM MATRIX: a re-measurement mode, never run per push -------------------------
# Every VF mutant and the unmutated copy on all eleven arms; one `MATRIX` row each, 1 = the arm holds, 0 = the mutant moved it.
if [ "$MATRIX" = 1 ]; then
  MX_CELLS=$((MX_CELLS + 1))
  echo "MATRIX-BEGIN vf cells=$VF_ARMS"
  for _mp in VF-CTL:vf-ctl VF-m-cmp:vf-mcmp VF-m-distonly:vf-mdo VF-m-noadd:vf-mna VF-m-first:vf-mfp VF-m-order:vf-mor VF-m-base:vf-mbs VF-m-wt:vf-mwt; do
    _dir="$WORK/${_mp#*:}"
    if [ ! -f "$_dir/apply.sh" ]; then bad "MATRIX vf ${_mp%%:*}: no staged copy, so its row cannot be measured"; continue; fi
    _row="MATRIX ${_mp%%:*}"; _v="$(vf_vec "$_dir")"
    for _a in $VF_ARMS; do _row="$_row $_a=${_v%% *}"; _v="${_v#* }"; done
    echo "$_row"
  done
  echo "MATRIX-END vf"
fi
fi  # ---- end of VF_PRESENT
fi  # ---- end of the VF block
fi  # ---- end of unit vf

# --- THE FIRST-VERIFIED REGION (units ar and arm) -----------------------------------------------
# A session that splices a fresh emit-report.sh region over the approved report before apply turned
# --verify's exit 3 into exit 0, and apply wrote with no ask. A plain --verify that exits 0 now
# records the region it verified in <consumer --absolute-git-dir>/ai-dlc-approved-region, first-wins
# per (base, theirs); apply.sh calls `emit-report.sh --for-apply --verify`, which compares the fresh
# render against THAT region and prints one `approved-region: first=<digest|UNAVAILABLE|FAILED-<tool>|NONE>`
# line apply.sh parses and strips. emit-report.sh's header owns the contract.
#
# EVERY WORLD `git init`s THE CONSUMER AS ITS OWN TOPLEVEL (the record needs a git-dir) except d2, the
# one world that must have none, and records its own refs as `.B`/`.T`(/`.T2`) beside the consumer:
# cell (j) is the one world whose theirs moves, and a helper reading a global would drive it with
# the wrong ref. Every refusal is PRESENCE-shaped (`RE-APPROVAL OWED`, the cause line, the FULL
# digest), and every accept asserts the target file's bytes AND a positive NOTE row.
#
# THE DIGEST AN ARM LOOKS FOR IS COMPUTED HERE from the report file's own region (ar_dg), never read
# off apply's `re-approval:` line: asserting apply prints what apply printed is circular. Only cell
# (f) builds its answer record from the question and option label apply PRINTS (R3), which is why M5
# (one character of that printed label) is killed by (f) alone; (b), (g) and (i) compose the label
# from the computed digest.
#
# A FLOW SETS AR_V, a space-separated list of tokens, one per conjunct, `X` held and `X!` broken, and
# AR_W, its world. Flows run in THIS shell, never inside $( ), so neither is lost to a subshell. The
# cells read the tokens of the shipped engine; each mutant re-drives the one flow that carries its
# arm through a mutated whole-directory copy and must flip its own token while a positive sibling
# token of the same flow holds (a mutant whose copy never ran holds nothing).
AR_RPT="_bmad-output/ai-dlc-update/reconcile-report.md"
# Copied from emit-report.sh's hand-edit refusal, never composed: cells n and n2 require it.
AR_N_CAUSE="cause: UNDECIDED — the report's region was hand-edited after the first --verify"
AR_SKIP=""
if [ "$IS_DIST" = 0 ] && { ! grep -q '^ar_record() {' "$EMIT" || [ -n "$RA_SKIP" ]; }; then
  AR_SKIP="the installed emit-report.sh predates the first-verified region record, or the answer-capture hook is absent; both land with the pull that carries this fixture"
fi
av()  { AR_V="$AR_V $1"; }
avc() { if "$@"; then :; fi; }
tk()  { case " $1 " in *" $2 "*) return 0 ;; esac; return 1; }
ar_B() { sed -n 1p "$1/.B"; }
# ar_D <world> -> the dist this world reads: the fixture's own, for every world.
ar_D() { printf '%s\n' "$DIST"; }
ar_T() { sed -n 1p "$1/.T"; }
# ar_w <tag> <green|worklist> <theirs> [nogit] -> the world dir on stdout; the caller checks it is a dir
ar_w() {
  local w="$WORK/ar-$1-$$-$RANDOM"
  mkdir -p "$w" || return 1
  printf '%s\n' "$BASE" > "$w/.B"; printf '%s\n' "$3" > "$w/.T"
  mk_consumer "$w/c" "$2" || return 1
  mkdir -p "$w/c/_bmad-output/ai-dlc-update" || return 1
  if [ "${4:-}" != nogit ]; then git -C "$w/c" init -q 2>/dev/null || return 1; fi
  printf '%s\n' "$w"
}
ar_rec() { printf '%s\n' "$1/c/.git/ai-dlc-approved-region"; }
# ar_render <world> [theirs] -- the SHIPPED renderer, as the session runs it; mutants are of the gate
ar_render() {
  local t="${2:-$(ar_T "$1")}"
  { printf '# reconcile report (fixture)\n\n'
    bash "$EMIT" "$(ar_D "$1")" "$(ar_B "$1")" "$1/c" "$t" 2>/dev/null
  } > "$1/c/$AR_RPT"
}
ar_ver() { local t="${3:-$(ar_T "$2")}"; bash "$1/emit-report.sh" --verify "$2/c/$AR_RPT" "$(ar_D "$2")" "$(ar_B "$2")" "$2/c" "$t" >"$2/v.out" 2>"$2/v.err"; }
ar_fa()  { local t="${3:-$(ar_T "$2")}"; bash "$1/emit-report.sh" --for-apply --verify "$2/c/$AR_RPT" "$(ar_D "$2")" "$(ar_B "$2")" "$2/c" "$t" >/dev/null 2>"$2/fa.err"; sed -n 's/^approved-region: first=//p' "$2/fa.err"; }
ar_app() { local t="${3:-$(ar_T "$2")}"; bash "$1/apply.sh" "$(ar_D "$2")" "$(ar_B "$2")" "$2/c" "$t" >"$2/a.out" 2>"$2/a.err"; }
# ar_wrote <world> [theirs] -> 0 when the session driver holds theirs' bytes (the write happened)
ar_wrote() {
  local t="${2:-$(ar_T "$1")}"
  git -C "$DIST" show "${t}:core/session-driver/ai-dlc-session-driver.sh" > "$1/drv.want" 2>/dev/null \
    && cmp -s "$1/drv.want" "$1/c/$DRIVER_REL"
}
# ar_dg <world> [theirs] -> sha256 of the report's GENERATED region as norm_dist leaves it, computed
# here; empty unless it is 64 hex.
ar_dg() {
  local t="${2:-$(ar_T "$1")}" d
  awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$1/c/$AR_RPT" \
    | sed -E "s|git -C .* show ${t}:|git -C <dist> show ${t}:|g" > "$1/region.txt"
  d="$(printf '%s\n' "$(cat "$1/region.txt")" | shasum -a 256 | cut -d' ' -f1)"
  case "$d" in *[!0-9a-f]*|'') d="" ;; esac
  [ "${#d}" -eq 64 ] && printf '%s\n' "$d"
}
ar_lbl() { printf 'Re-approve %s, run apply\n' "$(printf '%s' "$1" | cut -c1-12)"; }
ar_q()   { printf 'Re-approve the reconcile report? Region digest %s.\n' "$1"; }
ar_note() { detail_of "$(cat "$1/a.out")" NOTE "$2"; }
ar_owed() { # ar_owed <world> <cause> <digest> -> 0 when apply refused, left the tree unwritten, and said why
  [ -s "$1/a.err" ] && ! ar_wrote "$1" && grep -qF 'apply: RE-APPROVAL OWED.' "$1/a.err" \
    && grep -q "^  cause: $2 " "$1/a.err" && [ -n "$3" ] && grep -qF -- "$3" "$1/a.err"
}
# HERE-STRINGS, NOT PIPES, into a reader that stops at its first match (I54b): under pipefail the
# writer's EPIPE would answer "not found" once its output after the match fills the pipe buffer. The
# capture's own status is not what these read; grep's status is the function's, and an empty capture
# fails grep, which is the not-found answer either way.
ar_note_has() { # ar_note_has <world> <note-kind> <text> -> 0 when that NOTE row's detail carries <text>
  local n
  n="$(ar_note "$1" "$2")"
  grep -qF -- "$3" <<< "$n"
}
ar_rec_hard() { # ar_rec_hard <record> -> 0 when the record's region (line 3 on) carries a HARD-* row
  local g
  g="$(sed -n '3,$p' "$1" 2>/dev/null)"
  grep -q '^HARD-' <<< "$g"
}
ar_went() { # ar_went <world> <rc> <note-kind> <note-text> -> 0 when apply wrote, exited 0 and its NOTE says so
  [ "$2" -eq 0 ] && ar_wrote "$1" && ar_note_has "$1" "$3" "$4"
}

# FLOW A -- approved WITH a HARD blocker, blocker resolved, one unseen row, hand RE-RENDER, plain
# --verify 0, apply. Cells r1 (record written), r2 (first-wins), h3 (plain --verify bytes with and
# without the record), a (the refusal), f1 (R3 on the BLOCKERS-RESOLVED path).
# ar_flowA <rec-dir> <stop: r1|r2|a|f> [h]
ar_flowA() {
  local r="$1" w rc q l dg1 dg2 rec
  AR_V=""; AR_W=""
  w="$(ar_w A green "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"; rec="$(ar_rec "$w")"
  u5_seed_blocker "$w/c" || { AR_V=BROKEN; return; }
  ar_render "$w"
  grep -q '^HARD-' "$w/c/$AR_RPT" || { AR_V=BROKEN; return; }
  cp "$w/c/$AR_RPT" "$w/r1.md"; dg1="$(ar_dg "$w")"; printf '%s\n' "$dg1" > "$w/dg1"
  ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 0 ] && av V0 || av V0!
  if [ "$(sed -n 1p "$rec" 2>/dev/null)" = "ai-dlc-approved-region 1" ] \
     && [ "$(sed -n 2p "$rec" 2>/dev/null)" = "key $BASE $THEIRS" ] \
     && ar_rec_hard "$rec"; then av R1; else av R1!; fi
  [ "$2" = r1 ] && return
  cp "$rec" "$w/rec1" 2>/dev/null
  rm -rf "$w/c/.claude/skills/ai-dlc/overrides"; u5_seed_unseen "$w/c" || { av BROKEN; return; }
  ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 3 ] && av V3 || av V3!
  if [ "${3:-}" = h ]; then
    cp "$w/v.out" "$w/v3.out"; cp "$w/v.err" "$w/v3.err"
    mv "$rec" "$w/rec.aside"
    ar_ver "$r" "$w"; rc=$?
    if [ "$rc" -eq 3 ] && cmp -s "$w/v.out" "$w/v3.out" && cmp -s "$w/v.err" "$w/v3.err" && [ -s "$w/v3.err" ] \
       && [ ! -e "$rec" ]; then av H3; else av H3!; fi
    mv "$w/rec.aside" "$rec"
  fi
  ar_render "$w"
  cmp -s "$w/r1.md" "$w/c/$AR_RPT" && av RR! || av RR
  cp "$w/c/$AR_RPT" "$w/r2.md"; dg2="$(ar_dg "$w")"; printf '%s\n' "$dg2" > "$w/dg2"
  ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 0 ] && av V0b || av V0b!
  if [ -n "$dg2" ] && [ "$dg1" != "$dg2" ] && cmp -s "$w/rec1" "$rec" && ar_rec_hard "$rec"; then av R2; else av R2!; fi
  [ "$2" = r2 ] && return
  ar_app "$r" "$w"; rc=$?
  if [ "$rc" -ne 0 ] && ar_owed "$w" BLOCKERS-RESOLVED "$dg2" && ! grep -q '^approved-region:' "$w/a.err"; then av A; else av A!; fi
  [ "$2" = a ] && return
  ar_flowA_f "$r" "$w" "$dg2"
}
# ar_flowA_f <rec-dir> <world after A> <dg2> -- the R3 tail of flow A: the record built from exactly the question
# and label apply PRINTED, then the re-run. Appends F1 / F1! to AR_V. Split out so unit ar can run it on a COPY of
# the world flow A already built to its refusal, rather than building a second world to the same state.
ar_flowA_f() {
  local r="$1" w="$2" dg2="$3" q l rc
  q="$(sed -n 's/^  question: //p' "$w/a.err")"; l="$(sed -n 's/^  option label: //p' "$w/a.err")"
  if [ -n "$q" ] && [ -n "$l" ] && ra_answer "$w/c" "$q" "$l"; then
    ar_app "$r" "$w"; rc=$?
    ar_went "$w" "$rc" blockers-resolved "were re-approved" && ar_note_has "$w" blockers-resolved "$dg2" \
      && av F1 || av F1!
  else
    av F1!
  fi
}

# FLOW F2 -- approved with NO blocker, one unseen row appears, hand re-render, plain --verify 0, apply:
# RE-RENDERED-SINCE-APPROVAL (exit 3), then R3 from the printed question and label.
ar_flowF2() {
  local r="$1" w rc q l dg2
  AR_V=""; AR_W=""
  w="$(ar_w F green "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  ar_render "$w"
  grep -q '^HARD-' "$w/c/$AR_RPT" && { AR_V=BROKEN; return; }
  ar_ver "$r" "$w"; rc=$?; [ "$rc" -eq 0 ] && av FV0 || av FV0!
  u5_seed_unseen "$w/c" || { av BROKEN; return; }
  ar_render "$w"; dg2="$(ar_dg "$w")"
  ar_ver "$r" "$w"; rc=$?; [ "$rc" -eq 0 ] && av FV0b || av FV0b!
  ar_app "$r" "$w"; rc=$?
  [ "$rc" -ne 0 ] && ar_owed "$w" RE-RENDERED-SINCE-APPROVAL "$dg2" && av F2A || av F2A!
  q="$(sed -n 's/^  question: //p' "$w/a.err")"; l="$(sed -n 's/^  option label: //p' "$w/a.err")"
  if [ -n "$q" ] && [ -n "$l" ] && ra_answer "$w/c" "$q" "$l"; then
    ar_app "$r" "$w"; rc=$?
    ar_went "$w" "$rc" blockers-resolved "were re-approved" && ar_note_has "$w" blockers-resolved "$dg2" \
      && av F2 || av F2!
  else
    av F2!
  fi
}

# FLOW G -- the withheld-stamp reapply path: a WORKLIST consumer is verified and applied (written,
# stamp withheld), the report re-rendered as reapply_remedy says, apply re-run: it ASKS, printing the
# question; with a record of that question answered with the label it proceeds.
# ar_flowG <rec-dir> <stop: g1|g2>
ar_flowG() {
  local r="$1" w rc q dg
  AR_V=""; AR_W=""
  w="$(ar_w G worklist "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  ar_render "$w"
  ar_ver "$r" "$w"; rc=$?
  ar_app "$r" "$w"
  if [ "$rc" -eq 0 ] && ar_wrote "$w" && [ "$(stamp_ver "$w/c")" = 1.0.0 ] \
     && has_row "$(cat "$w/a.out")" DECISION restamp-withheld; then av G0; else av G0!; fi
  ar_render "$w"; dg="$(ar_dg "$w")"
  ar_app "$r" "$w"; rc=$?
  q="$(sed -n 's/^  question: //p' "$w/a.err")"
  # The tree was already written by the first run, so ar_owed's unwritten conjunct does not apply:
  # the refusal is read off its own lines.
  if [ "$rc" -ne 0 ] && grep -qF 'apply: RE-APPROVAL OWED.' "$w/a.err" \
     && grep -q '^  cause: RE-RENDERED-SINCE-APPROVAL ' "$w/a.err" && [ -n "$dg" ] && grep -qF -- "$dg" "$w/a.err" \
     && [ -n "$q" ] && [ "$(grep -c '^  question: ' "$w/a.err")" = 1 ]; then av G1; else av G1!; fi
  [ "$2" = g1 ] && return
  if [ -n "$q" ] && ra_answer "$w/c" "$q" "$(ar_lbl "$dg")"; then
    ar_app "$r" "$w"; rc=$?
    [ "$rc" -eq 0 ] && ar_note_has "$w" blockers-resolved "were re-approved" && av G2 || av G2!
  else
    av G2!
  fi
}

# FLOW I -- R1 approved, R2 = R1 with one row more, a record quoting R2's digest, apply. Compared
# against the twin world AR_I0 (no re-render, written), whose tree is the CURRENT state.
ar_flowI() {
  local r="$1" w rc dg1 dg2 f n=0 bad=0
  AR_V=""; AR_W=""
  w="$(ar_w I green "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  ar_render "$w"; cp "$w/c/$AR_RPT" "$w/r1.md"; dg1="$(ar_dg "$w")"
  ar_ver "$r" "$w"
  u5_seed_unseen "$w/c" || { av BROKEN; return; }
  ar_render "$w"; cp "$w/c/$AR_RPT" "$w/r2.md"; dg2="$(ar_dg "$w")"
  ar_ver "$r" "$w"
  if [ -z "$dg1" ] || [ -z "$dg2" ] || [ "$dg1" = "$dg2" ] || cmp -s "$w/r1.md" "$w/r2.md"; then av BROKEN; return; fi
  ra_answer "$w/c" "$(ar_q "$dg2")" "$(ar_lbl "$dg2")" || { av BROKEN; return; }
  rm -f "$w/c/ra-payload.json"
  ar_app "$r" "$w"; rc=$?
  ar_went "$w" "$rc" blockers-resolved "were re-approved" && av I0 || av I0!
  # (1) the written tree, file by file, against the twin; the overrides the seed added and the
  # report/answers under _bmad-output are not apply's writes and are excluded on both sides.
  if [ -d "${AR_I0:-}/c" ]; then
    while IFS= read -r f; do
      n=$((n+1)); cmp -s "$AR_I0/c/$f" "$w/c/$f" || bad=$((bad+1))
    done < <(cd "$AR_I0/c" && find . -type f ! -path './.git/*' ! -path './_bmad-output/*' ! -path './.claude/skills/ai-dlc/overrides/*' | sort)
    [ "$n" -ge 4 ] && [ "$bad" -eq 0 ] && grep -qF 'UPSTREAM' "$w/c/$DRIVER_REL" && av I1 || av I1!
  else
    av I1!
  fi
  cmp -s "$w/r2.md" "$w/c/$AR_RPT" && av I2 || av I2!
  # The NOTE also quotes the cause line, which names the FIRST region's digest as the first region --
  # correctly. What must not name it is the re-approval clause, so that clause's digest is extracted.
  local qd
  qd="$(ar_note "$w" blockers-resolved | sed -n 's/.*holds an AskUserQuestion record quoting digest \([0-9a-f]*\) answered.*/\1/p')"
  [ -n "$qd" ] && [ "$qd" = "$dg2" ] && [ "$qd" != "$dg1" ] && av I3 || av I3!
}

# ar_twin -- AR_I0, cell (i)'s twin: a current report, no re-render, verified and applied with the
# SHIPPED engine. Built by whichever of units ar and arm runs first in this shard, because the two
# units may be dealt to different shards and a twin built in the other one does not exist here.
# Leaves AR_I0_H0 (rc of the record-writing verify, rc of the record-finding verify, yes|no record)
# and AR_I0_RC (apply's rc) for unit ar's h0 and I0 arms.
ar_twin() {
  [ -d "${AR_I0:-}/c" ] && return 0
  AR_I0="$(ar_w I0 green "$THEIRS")"; [ -d "$AR_I0" ] || { AR_I0=""; return 1; }
  local a b r=no
  ar_render "$AR_I0"
  ar_ver "$REC" "$AR_I0"; a=$?; cp "$AR_I0/v.out" "$AR_I0/v0a.out"; cp "$AR_I0/v.err" "$AR_I0/v0a.err"
  [ -s "$(ar_rec "$AR_I0")" ] && r=yes
  ar_ver "$REC" "$AR_I0"; b=$?
  AR_I0_H0="$a $b $r"
  # n4's premise, measured BEFORE apply writes the tree: the report's region, the record's region and a fresh render are one text.
  ar_region_of "$AR_I0/c/$AR_RPT" "$(ar_T "$AR_I0")" > "$AR_I0/n4.report"
  sed -n '3,$p' "$(ar_rec "$AR_I0")" > "$AR_I0/n4.record" 2>/dev/null
  { printf '# x\n\n'; bash "$EMIT" "$(ar_D "$AR_I0")" "$(ar_B "$AR_I0")" "$AR_I0/c" "$(ar_T "$AR_I0")" 2>/dev/null; } > "$AR_I0/n4.fresh.md"
  ar_region_of "$AR_I0/n4.fresh.md" "$(ar_T "$AR_I0")" > "$AR_I0/n4.fresh"
  if [ -s "$AR_I0/n4.report" ] && cmp -s "$AR_I0/n4.report" "$AR_I0/n4.record" && cmp -s "$AR_I0/n4.report" "$AR_I0/n4.fresh"; then AR_I0_N4S=1; else AR_I0_N4S=0; fi
  ar_app "$REC" "$AR_I0"; AR_I0_RC=$?
}
# ar_flowNT_twin -> AR_V for (n)'s ALLOW twin, read off the SHIPPED engine's twin world AR_I0 (the same state ar_flowN plain builds)
ar_flowNT_twin() {
  AR_V=""; AR_W="$AR_I0"
  [ "${AR_I0_N4S:-0}" = 1 ] && av N4S || av N4S!
  ar_flowN_score "$AR_I0" "$AR_I0_RC" plain
}

# FLOW J -- record R1 under (B,T); plain --verify under (B,T2) exits 0 and REPLACES it (key T2);
# apply at T2 reads first= with T2's region and writes.
ar_flowJ() {
  local r="$1" w rc rec dgt2 fa
  AR_V=""; AR_W=""
  w="$(ar_w J green "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"; rec="$(ar_rec "$w")"
  printf '%s\n' "$OTHER" > "$w/.T2"
  ar_render "$w"
  ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 0 ] && [ "$(sed -n 2p "$rec" 2>/dev/null)" = "key $BASE $THEIRS" ] && av J0 || av J0!
  ar_render "$w" "$(sed -n 1p "$w/.T2")"; dgt2="$(ar_dg "$w" "$(sed -n 1p "$w/.T2")")"
  ar_ver "$r" "$w" "$(sed -n 1p "$w/.T2")"; rc=$?
  [ "$rc" -eq 0 ] && [ "$(sed -n 2p "$rec" 2>/dev/null)" = "key $BASE $(sed -n 1p "$w/.T2")" ] && av J1 || av J1!
  fa="$(ar_fa "$r" "$w" "$(sed -n 1p "$w/.T2")")"
  [ -n "$dgt2" ] && [ "$fa" = "$dgt2" ] && av J2 || av J2!
  ar_app "$r" "$w" "$(sed -n 1p "$w/.T2")"; rc=$?
  [ "$rc" -eq 0 ] && ar_wrote "$w" "$(sed -n 1p "$w/.T2")" && ! grep -qF 'RE-APPROVAL OWED' "$w/a.err" \
    && ar_note_has "$w" report-verified 'matches what the detectors render' && av J3 || av J3!
}

# FLOW K -- the two digest states, one property apart. KF: a `shasum` that EXISTS (an executable stub
# first on PATH) and exits 1. KA: a PATH with neither sha256 tool (ra_shim none).
ar_flowK() {
  local r="$1" w rc s="$WORK/ar-kstub-$$-$RANDOM" fa
  AR_V=""; AR_W=""
  mkdir -p "$s" && printf '#!/bin/bash\nexit 1\n' > "$s/shasum" && chmod +x "$s/shasum" || { AR_V=BROKEN; return; }
  w="$(ar_w K green "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  ar_render "$w"
  PATH="$s:$PATH" ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 0 ] && grep -qF 'present, current, and complete.' "$w/v.out" && [ ! -e "$(ar_rec "$w")" ] && av KV || av KV!
  ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 0 ] && [ -s "$(ar_rec "$w")" ] && av KV2 || av KV2!
  fa="$(PATH="$s:$PATH" ar_fa "$r" "$w")"
  [ "$fa" = FAILED-shasum ] && av KF1 || av KF1!
  PATH="$s:$PATH" ar_app "$r" "$w"; rc=$?
  if [ "$rc" -ne 0 ] && ! ar_wrote "$w" \
     && grep -qF 'apply: the union gate could not digest the approved region: shasum exists on this box' "$w/a.err" \
     && grep -qF 'NOTHING HAS BEEN WRITTEN.' "$w/a.err" && ! grep -qF 'install shasum' "$w/a.err"; then av KF2; else av KF2!; fi
  # KA: no sha256 tool at all. The record is still written (the region is what the comparison uses),
  # first=UNAVAILABLE, and a matching report writes.
  s="$WORK/ar-knone-$$-$RANDOM"
  ar_notool "$s" || { av BROKEN; return; }
  w="$(ar_w KA green "$THEIRS")"; [ -d "$w" ] || { av BROKEN; return; }
  ar_render "$w"
  PATH="$s" ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 0 ] && [ -s "$(ar_rec "$w")" ] && av KA1 || av KA1!
  fa="$(PATH="$s" ar_fa "$r" "$w")"
  [ "$fa" = UNAVAILABLE ] && av KA2 || av KA2!
  PATH="$s" ar_app "$r" "$w"; rc=$?
  ar_went "$w" "$rc" report-verified 'matches what the detectors render' && av KA3 || av KA3!
}

# FLOW N -- the report HAND-EDITED after step 5's plain --verify, with no re-render: a row of the
# region deleted and a bogus row added. Every other flow re-renders with the shipped renderer, so
# none of them can see a region that no renderer produced. ar_flowN <rec-dir> <edit|plain>; `plain`
# is the ALLOW twin one property apart: the same world, the report left as verified, which writes.
# ar_hand_edit <world> -> 0 when the report's region lost its session-driver rows and gained one bogus
# row, by awk, with no re-render; the edit is proved to have landed, not assumed.
ar_hand_edit() {
  local w="$1" n0 n1
  cp "$w/c/$AR_RPT" "$w/before.md" || return 1
  awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} /END GENERATED: reconcile-mechanical/{f=0}
    f && index($0, "ai-dlc-session-driver.sh") {next} {print}
    /BEGIN GENERATED: reconcile-mechanical/{print "HAND-EDITED ROW"}' "$w/before.md" > "$w/c/$AR_RPT" || return 1
  n0="$(grep -c 'ai-dlc-session-driver.sh' "$w/before.md")" || n0=0
  n1="$(grep -c 'ai-dlc-session-driver.sh' "$w/c/$AR_RPT")" || n1=0
  ! cmp -s "$w/before.md" "$w/c/$AR_RPT" && grep -qxF 'HAND-EDITED ROW' "$w/c/$AR_RPT" && [ "$n0" -gt "$n1" ]
}
# ar_region_of <file> <theirs> -- a report's GENERATED region as norm_dist leaves it
ar_region_of() {
  awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$1" \
    | sed -E "s|git -C .* show ${2}:|git -C <dist> show ${2}:|g"
}
ar_flowN() {
  local r="$1" w rc
  AR_V=""; AR_W=""
  w="$(ar_w N green "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  ar_render "$w"
  ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 0 ] && [ -s "$(ar_rec "$w")" ] && av N0 || av N0!
  if [ "$2" = edit ]; then
    ar_hand_edit "$w" || { av BROKEN; return; }
  else
    # n4's premise, measured: the report's region, the record's region and a fresh render are one text.
    ar_region_of "$w/c/$AR_RPT" "$(ar_T "$w")" > "$w/n4.report"
    sed -n '3,$p' "$(ar_rec "$w")" > "$w/n4.record" 2>/dev/null
    { printf '# x\n\n'; bash "$EMIT" "$(ar_D "$w")" "$(ar_B "$w")" "$w/c" "$(ar_T "$w")" 2>/dev/null; } > "$w/n4.fresh.md"
    ar_region_of "$w/n4.fresh.md" "$(ar_T "$w")" > "$w/n4.fresh"
    [ -s "$w/n4.report" ] && cmp -s "$w/n4.report" "$w/n4.record" && cmp -s "$w/n4.report" "$w/n4.fresh" && av N4S || av N4S!
  fi
  ar_app "$r" "$w"; rc=$?
  ar_flowN_score "$w" "$rc" "$2"
}
# ar_flowN2 <rec-dir> <n2|n3>
#   n2: record R1 WITH a HARD blocker, resolve it leaving NO unseen row, re-render to R2 with the
#       shipped renderer, then hand-edit R2 to R2' (one row changed). UNSEEN=0 IS THE DISCRIMINATING
#       SEED: without the edited-report comparison, record-vs-fresh reads BLOCKERS-RESOLVED unseen=0
#       and PROCEEDS (RA0), so only that comparison can refuse it. An unseen>0 seed refuses either way
#       and could not fail on the property this cell exists for. n2 is (n)'s case in a second shape.
#   n3: record R1, an unseen row appears, and the fresh region is spliced in by awk so the report
#       EQUALS the fresh render byte for byte: it keeps the re-render verdict.
ar_flowN2() {
  local r="$1" w rc
  AR_V=""; AR_W=""
  w="$(ar_w "$2" green "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  [ "$2" = n2 ] && { u5_seed_blocker "$w/c" || { AR_V=BROKEN; return; }; }
  ar_render "$w"
  [ "$2" = n2 ] && { grep -q '^HARD-' "$w/c/$AR_RPT" || { AR_V=BROKEN; return; }; }
  ar_ver "$r" "$w"; rc=$?
  [ "$rc" -eq 0 ] && [ -s "$(ar_rec "$w")" ] && av N0 || av N0!
  if [ "$2" = n2 ]; then
    rm -rf "$w/c/.claude/skills/ai-dlc/overrides"
  else
    u5_seed_unseen "$w/c" || { av BROKEN; return; }
  fi
  if [ "$2" = n3 ]; then
    # Not emit-report.sh's file: the fresh region is spliced in by awk over a report holding R1.
    { printf '# reconcile report (fixture)\n\n'
      bash "$EMIT" "$DIST" "$(ar_B "$w")" "$w/c" "$(ar_T "$w")" 2>/dev/null
    } > "$w/fresh.md"
    awk 'NR==FNR {print; next}' "$w/fresh.md" "$w/c/$AR_RPT" > "$w/c/$AR_RPT.new" && mv "$w/c/$AR_RPT.new" "$w/c/$AR_RPT"
    cmp -s "$w/fresh.md" "$w/c/$AR_RPT" || { av BROKEN; return; }
  else
    ar_render "$w"; cp "$w/c/$AR_RPT" "$w/r2.md"
    awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} /END GENERATED: reconcile-mechanical/{f=0}
      f && !done && index($0, "ai-dlc-session-driver.sh") {sub(/ai-dlc-session-driver\.sh/, "ai-dlc-session-driver.sh EDITED"); done=1} {print}' \
      "$w/r2.md" > "$w/c/$AR_RPT"
    [ "$(cmp -l "$w/r2.md" "$w/c/$AR_RPT" 2>/dev/null | wc -l)" -gt 0 ] && grep -qF 'ai-dlc-session-driver.sh EDITED' "$w/c/$AR_RPT" \
      || { av BROKEN; return; }
  fi
  ar_app "$r" "$w"; rc=$?
  ar_flowN_score "$w" "$rc" "$2"
}
# ar_flowN_score <world> <rc> <edit|plain|n2|n3>
ar_flowN_score() {
  local w="$1" rc="$2"
  case "$3" in
    n3)
      if [ "$rc" -ne 0 ] && ! ar_wrote "$w" && grep -qF 'apply: RE-APPROVAL OWED.' "$w/a.err" \
         && grep -q '^  cause: RE-RENDERED-SINCE-APPROVAL ' "$w/a.err" && ! grep -qF -- "$AR_N_CAUSE" "$w/a.err" \
         && ! has_row "$(cat "$w/a.out")" NOTE report-verified; then av N3; else av N3!; fi
      return ;;
    n2) # (n)'s case, second shape: the same cause, presence-shaped
      if [ "$rc" -ne 0 ] && ! ar_wrote "$w" && grep -qF -- "$AR_N_CAUSE" "$w/a.err" \
         && grep -qF 'NOTHING HAS BEEN WRITTEN.' "$w/a.err" && ! has_row "$(cat "$w/a.out")" NOTE report-verified; then av N2E; else av N2E!; fi
      # N2P is the MEASUREMENT that unseen=0 is the discriminating seed: held only when the world
      # PROCEEDED (exit 0, written, a blockers-resolved NOTE). It must read N2P! on the shipped engine
      # and N2P under M10, or n2 is not a cell that only the edited-report comparison refuses.
      [ "$rc" -eq 0 ] && ar_wrote "$w" && has_row "$(cat "$w/a.out")" NOTE blockers-resolved && av N2P || av N2P!
      return ;;
  esac
  if [ "$3" = edit ]; then
    if [ "$rc" -ne 0 ] && ! ar_wrote "$w" && grep -qF -- "$AR_N_CAUSE" "$w/a.err" \
       && grep -qF 'NOTHING HAS BEEN WRITTEN.' "$w/a.err" && ! has_row "$(cat "$w/a.out")" NOTE report-verified; then
      av N1
    else
      av N1!
    fi
  else
    ar_went "$w" "$rc" report-verified 'matches what the detectors render' && av NT || av NT!
  fi
}

# FLOW M -- the `approved-region:` line malformed (`first=not-a-digest`) or absent, from a harness
# copy whose emit-report.sh is edited and whose apply.sh is taken from <apply-src-dir>. A current
# report, no record: apply must refuse on the line before deciding anything.
# ar_flowM <apply-src-dir> <bad|absent>
ar_flowM() {
  local h="$WORK/ar-mh-$2-$$-$RANDOM" w rc new
  AR_V=""; AR_W=""
  build_rec "$h" && cp "$1/apply.sh" "$h/apply.sh" || { AR_V=BROKEN; return; }
  new='  :'; [ "$2" = bad ] && new='  echo "approved-region: first=not-a-digest" >&2'
  if ! py_replace_once "$h/emit-report.sh" '  echo "approved-region: first=${_ar_first_dg}" >&2' "$new" 2>/dev/null \
     || cmp -s "$REC/emit-report.sh" "$h/emit-report.sh"; then
    AR_V="MH!"; return
  fi
  w="$(ar_w M green "$THEIRS")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  ar_render "$w"
  ar_app "$h" "$w"; rc=$?
  local found='(found 1)'; [ "$2" = absent ] && found='(found 0)'
  if [ "$rc" -ne 0 ] && ! ar_wrote "$w" && grep -qF 'did not print exactly one well-formed' "$w/a.err" \
     && grep -qF -- "$found" "$w/a.err" && grep -qF 'NOTHING HAS BEEN WRITTEN.' "$w/a.err"; then
    av "M-$2"
  else
    av "M-$2!"
  fi
}

if sg ar; then
if [ -n "$AR_SKIP" ]; then
  printf '  SKIP  AR (first-verified region) -- %s\n' "$AR_SKIP"
else
  # AR-0 SELF-PROBE: the world helpers resolve their refs, the computed digest is 64 hex, and the
  # no-tool PATH really carries neither sha256 tool while git and awk still resolve.
  # The probe reads the twin world (green, rendered, verified, applied): the same state a separate probe world would be.
  ar_twin
  w0="$AR_I0"
  if [ -d "$w0" ] && [ "$(ar_T "$w0")" = "$THEIRS" ] && [ -s "$w0/c/$AR_RPT" ] && [ -n "$(ar_dg "$w0")" ] \
     && ar_notool "$WORK/ar-probe-notool-$$" && [ -d "$w0/c/.git" ]; then
    ok "AR-0 setup: a world records its own refs, its consumer is its own git toplevel, a rendered region digests to 64 hex, and the no-tool PATH resolves git and awk but neither sha256 tool"
  else
    bad "AR-0 setup: the world helpers, the digest or the no-tool PATH did not build — every AR arm below reads a world that cannot express the case"
  fi

  # Twin for (i), and (h0): a current report, no re-render. Plain --verify's exit-0 output is exactly
  # the one success line with an empty stderr on the run that WRITES the record and on the run that
  # finds it; apply then writes.
  if [ -d "${AR_I0:-}/c" ]; then
    read -r h0a h0b h0rec <<< "$AR_I0_H0"
    if [ "$h0a" -eq 0 ] && [ "$h0b" -eq 0 ] && [ "$h0rec" = yes ] \
       && [ "$(cat "$AR_I0/v0a.out")" = "emit-report: the report's mechanical region is present, current, and complete." ] \
       && [ ! -s "$AR_I0/v0a.err" ] && cmp -s "$AR_I0/v.out" "$AR_I0/v0a.out" && cmp -s "$AR_I0/v.err" "$AR_I0/v0a.err"; then
      ok "AR-h0 plain --verify exit 0 prints exactly its one success line and an empty stderr both on the run that writes the record and on the run that finds it"
    else
      bad "AR-h0 plain --verify's exit-0 output moved when the record is written or present (rc $h0a/$h0b, record $h0rec) — step 5's output is no longer byte-identical"
    fi
    ar_went "$AR_I0" "$AR_I0_RC" report-verified 'matches what the detectors render' || bad "AR-I0 the twin world for (i) did not write (rc $AR_I0_RC) — cell (i)'s tree comparison has no current state to compare against"
  else
    bad "AR-I0 could not build the twin world for (i)"
  fi

  ar_flowA "$REC" a h; FA="$AR_V"; WA="$AR_W"
  if tk "$FA" R1; then
    ok "AR-r1 a plain --verify exiting 0 writes the record in the consumer's git-dir: version line, key <base> <theirs>, and the approved region with its HARD row"; B_ar_r1=1
  else
    bad "AR-r1 no well-formed record after the first plain --verify [$FA]"
  fi
  tk "$FA" V3 && tk "$FA" H3 && ok "AR-h3 with the blocker resolved and no re-render plain --verify still exits 3, and its stdout and stderr are byte-identical with the record present and with it removed (and that run writes none)" \
              || bad "AR-h3 the un-re-rendered control or plain --verify's exit-3 bytes moved with the record [$FA]"
  if tk "$FA" RR && tk "$FA" V0b && tk "$FA" R2; then
    ok "AR-r2 after the hand re-render plain --verify exits 0 and the record is byte-identical to the first one, still carrying the HARD row (first-wins)"; B_ar_r2=1
  else
    bad "AR-r2 the re-render's plain --verify did not exit 0, or REWROTE the record [$FA]"
  fi
  if tk "$FA" A; then
    ok "AR-a a hand re-render with no answer record REFUSES: tree unwritten, RE-APPROVAL OWED, cause BLOCKERS-RESOLVED and the fresh region's full digest printed, the approved-region line stripped"; B_ar_a=1
  else
    bad "AR-a the 0.881.0 shape: a hand re-render with no re-approval was not refused with RE-APPROVAL OWED, its cause and its digest [$FA]"
  fi
  # F1 runs on a COPY of this world taken at its refusal, before (c) and (b) write records or the tree.
  WAF=""
  if [ -n "$WA" ] && [ -s "$WA/dg2" ]; then
    WAF="$WA-f"; cp -Rp "$WA" "$WAF" || WAF=""
  fi
  # (c) then (b) in the same world: a record quoting the FIRST region's digest, then one quoting the new.
  if [ -n "$WA" ] && [ -s "$WA/dg1" ] && [ -s "$WA/dg2" ]; then
    dg1="$(cat "$WA/dg1")"; dg2="$(cat "$WA/dg2")"
    if ra_answer "$WA/c" "$(ar_q "$dg1")" "$(ar_lbl "$dg2")"; then
      ar_app "$REC" "$WA"; rc=$?
      [ "$rc" -ne 0 ] && ar_owed "$WA" BLOCKERS-RESOLVED "$dg2" \
        && ok "AR-c a record quoting the FIRST region's digest, answered with the new label, refuses — RE-APPROVAL OWED, tree unwritten" \
        || bad "AR-c a re-approval of the first region passed as a re-approval of the re-rendered one (rc $rc)"
    else
      bad "AR-c the answer-capture hook wrote no record"
    fi
    if ra_answer "$WA/c" "$(ar_q "$dg2")" "$(ar_lbl "$dg2")"; then
      ar_app "$REC" "$WA"; rc=$?
      ar_went "$WA" "$rc" blockers-resolved "were re-approved" && ar_note_has "$WA" blockers-resolved "$dg2" \
        && ok "AR-b the re-render plus a hook-written record quoting the new digest with the exact label WRITES, its NOTE naming that digest" \
        || bad "AR-b a correct re-approval of the re-rendered region did not let apply write (rc $rc)"
    else
      bad "AR-b the answer-capture hook wrote no record"
    fi
  else
    bad "AR-b/c flow A built no world to continue [$FA]"
  fi

  AR_V=""; tk "$FA" A && AR_V="A"
  if [ -n "$WAF" ]; then ar_flowA_f "$REC" "$WAF" "$(cat "$WAF/dg2")"; else av F1!; fi
  FF1="$AR_V"
  if tk "$FF1" A && tk "$FF1" F1; then
    ok "AR-f1 R3 on the BLOCKERS-RESOLVED path: a record built from exactly the question and option label apply PRINTED lets the re-run write"; B_ar_f1=1
  else
    bad "AR-f1 apply's own printed question and label do not satisfy its own gate on the BLOCKERS-RESOLVED path [$FF1]"
  fi
  ar_flowF2 "$REC"; FF2="$AR_V"
  tk "$FF2" F2A && ok "AR-f2 the F3 path: a re-render after a blocker-free approval REFUSES as RE-RENDERED-SINCE-APPROVAL with RE-APPROVAL OWED and the full digest, tree unwritten" \
                || bad "AR-f2 a re-render after a blocker-free approval was not refused as RE-RENDERED-SINCE-APPROVAL [$FF2]"
  tk "$FF2" F2 && ok "AR-f2 R3 on the F3 path: the printed question and label, recorded by the hook, let the re-run write" \
               || bad "AR-f2 apply's own printed question and label do not satisfy its own gate on the F3 path [$FF2]"
  ar_flowG "$REC" g2; FG="$AR_V"
  if tk "$FG" G0 && tk "$FG" G1 && tk "$FG" G2; then
    ok "AR-g the withheld-stamp reapply path ASKS once, printing the question, and with that question recorded and the label answered it proceeds"; B_ar_g=1
  else
    bad "AR-g the withheld-stamp reapply path is wedged or unasked [$FG]"
  fi
  ar_flowI "$REC"; FI="$AR_V"
  tk "$FI" I0 && tk "$FI" I1 && ok "AR-i1 a re-render cleared by a recorded re-approval writes a tree byte-identical, file by file, to the one the same world writes with no re-render" \
              || bad "AR-i1 the re-approved re-render wrote a tree that is not the current state [$FI]"
  if tk "$FI" I2; then
    ok "AR-i2 the report still holds the re-rendered region R2 after apply — apply mode never wrote the first region back"; B_ar_i2=1
  else
    bad "AR-i2 the report no longer holds R2 after apply [$FI]"
  fi
  if tk "$FI" I3; then
    ok "AR-i3 the NOTE names R2's digest, not R1's"; B_ar_i3=1
  else
    bad "AR-i3 the NOTE does not name the re-approved region's digest, or names the first one [$FI]"
  fi
  ar_flowJ "$REC"; FJ="$AR_V"
  if tk "$FJ" J0 && tk "$FJ" J1 && tk "$FJ" J2 && tk "$FJ" J3; then
    ok "AR-j a ref move starts a fresh record: plain --verify at T2 replaces the T record (key T2), apply mode reads first= as T2's region and apply at T2 writes"; B_ar_j=1
  else
    bad "AR-j a record from another theirs was reused or not replaced [$FJ]"
  fi
  # (d) no record at all: d1 a git toplevel never verified, d2 not a git toplevel.
  for kind in d1 d2; do
    ng=""; [ "$kind" = d2 ] && ng=nogit
    wd="$(ar_w "$kind" green "$THEIRS" $ng)"
    if [ -d "$wd" ]; then
      ar_render "$wd"; ar_app "$REC" "$wd"; rc=$?
      if ar_went "$wd" "$rc" report-verified 'the re-render binding was not evaluated' \
         && { [ "$kind" = d2 ] || [ ! -e "$(ar_rec "$wd")" ]; } && { [ "$kind" = d1 ] || [ ! -d "$wd/c/.git" ]; }; then
        ok "AR-$kind no approved-region record ($([ "$kind" = d1 ] && echo 'a clean git-dir; apply mode wrote none either' || echo 'not a git toplevel')) WRITES, with the NOTE saying the re-render binding was not evaluated"
      else
        bad "AR-$kind a pull with no record did not write with the NONE note (rc $rc)"
      fi
    else
      bad "AR-$kind could not build the world"
    fi
  done
  ar_flowK "$REC"; FK="$AR_V"
  tk "$FK" KV && tk "$FK" KV2 && ok "AR-k plain --verify under a shasum that exists and fails exits 0 with its success line and writes NO record; the same world with a working shasum writes one" \
                              || bad "AR-k a failed digest was recorded, or a working one was not [$FK]"
  if tk "$FK" KF1 && tk "$FK" KF2; then
    ok "AR-k apply mode reads first=FAILED-shasum and apply REFUSES naming the failed tool, tree unwritten — never UNAVAILABLE, never proceeding"; B_ar_kf=1
  else
    bad "AR-k a failing shasum did not refuse as FAILED-shasum [$FK]"
  fi
  if tk "$FK" KA1 && tk "$FK" KA2 && tk "$FK" KA3; then
    ok "AR-k twin: with NO sha256 tool the record is still written, apply mode reads first=UNAVAILABLE, and a matching report writes as the engine documents"; B_ar_ka=1
  else
    bad "AR-k twin: the no-tool state does not behave as documented [$FK]"
  fi
  ar_flowM "$REC" bad; FMB="$AR_V"
  ar_flowM "$REC" absent; FMA="$AR_V"
  if tk "$FMB" M-bad; then
    ok "AR-m a malformed approved-region line (first=not-a-digest) REFUSES before anything is decided, tree unwritten — it is never read as NONE"; B_ar_mb=1
  else
    bad "AR-m a malformed approved-region line did not refuse [$FMB]"
  fi
  if tk "$FMA" M-absent; then
    ok "AR-m an absent approved-region line REFUSES (found 0), tree unwritten"; B_ar_ma=1
  else
    bad "AR-m an absent approved-region line did not refuse [$FMA]"
  fi
  # (n)-(n4): THE REPORT IS STILL COMPARED, FOR HAND EDITS. Every flow above re-renders with the
  # shipped renderer, so none can see a region no renderer produced.
  ar_flowN "$REC" edit; FN="$AR_V"
  if tk "$FN" N0 && tk "$FN" N1; then
    ok "AR-n a report hand-edited after the record was written (rows deleted, a bogus row added, no re-render) REFUSES with the edited-after-first-verify cause and NOTHING HAS BEEN WRITTEN, tree unwritten, no report-verified NOTE"; B_ar_n=1
  else
    bad "AR-n a hand-edited report was not refused as edited after the first --verify [$FN]"
  fi
  # (n)'s ALLOW twin is the twin world AR_I0 (green, rendered, verified, applied), the same state ar_flowN plain builds.
  ar_flowNT_twin; FNT="$AR_V"
  if tk "$FNT" N4S && tk "$FNT" NT; then
    ok "AR-n4 (also (n)'s ALLOW twin, one property apart): report, record and fresh render are one region, and apply writes with the report-verified NOTE"; B_ar_n4=1
  else
    bad "AR-n4 the unedited world did not write cleanly, or its three regions differ [$FNT]"
  fi
  ar_flowN2 "$REC" n2; FN2="$AR_V"
  if tk "$FN2" N2E && tk "$FN2" N2P!; then
    ok "AR-n2 a hand edit made AFTER a legitimate re-render (unseen=0, so nothing but the edited-report comparison refuses it) REFUSES with the same cause, tree unwritten"; B_ar_n2=1
  else
    bad "AR-n2 an edit of a re-rendered report was not refused as edited [$FN2]"
  fi
  ar_flowN2 "$REC" n3; FN3="$AR_V"
  if tk "$FN3" N3; then
    ok "AR-n3 a report spliced by awk to EQUAL the fresh render byte for byte keeps the re-render verdict: RE-RENDERED-SINCE-APPROVAL, RE-APPROVAL OWED, not acquitted as report-verified, not called edited"; B_ar_n3=1
  else
    bad "AR-n3 a byte-equal hand splice did not keep the re-render verdict [$FN3]"
  fi
fi
# --- AR MATRIX: unit ar owns no mutant; the mutants of its flows are the rows of unit arm below -----------------
if [ "$MATRIX" = 1 ]; then
  MX_CELLS=$((MX_CELLS + 1))
  echo "MATRIX-BEGIN ar (no mutants of its own; the AR flows' mutants are scored as the rows of unit arm)"
  echo "MATRIX-END ar"
fi
fi  # ---- end of unit ar

if sg arm; then
# --- M1-M9: the first-verified region's mutants. Each is a whole reconcile-directory copy (apply.sh
# shells to its siblings) made by an exact-once replace and `cmp -s`-guarded; a replace that matches
# nothing or more than once is DID NOT APPLY. Each re-drives the ONE flow carrying its arm and must
# flip its own token while a positive sibling token in that flow HOLDS — that sibling is what proves
# the copy ran. Arms sharing a mutant's subject further down the same property are named, not re-read:
# the record is the premise of every binding arm, so M1 also breaks (a)-(j), M2 also (a), M6 also
# (f2), and M9 also RA9f (the same ar_digest computes the re-approval digest).
ar_mut() { # ar_mut <dir> <file> <old> <new>
  build_rec "$1" || return 1
  py_replace_once "$1/$2" "$3" "$4" 2>/dev/null || return 1
  ! cmp -s "$REC/$2" "$1/$2"
}
# ar_score <flag> <id> <tokens> <must-flip> <must-hold> <what>
ar_score() {
  local bf="$1"; shift
  if tk "$2" "$3!" && tk "$2" "$4"; then
    mutant_killed "$bf" "$1" "$1 ($5): $3 goes red while $4 holds [$2]"
  else
    bad "$1 ($5) SURVIVED or broke its control: want $3! with $4 held, got [$2]"
  fi
}
if [ -n "$AR_SKIP" ]; then
  printf '  SKIP  M1-M9 -- %s\n' "$AR_SKIP"
else
  if build_rec "$WORK/arm-ctl"; then
    ar_flowA "$WORK/arm-ctl" r1
    if tk "$AR_V" V0 && tk "$AR_V" R1; then
      ok "CONTROL-AR the unmutated copy exits 0 and WRITES the record, so a mutant copy that never ran cannot score a kill"; B_arctl=1
    else
      bad "CONTROL-AR the unmutated copy did not write the record [$AR_V] — M1-M9 are unreadable"
    fi
  else
    bad "CONTROL-AR could not copy the reconcile directory"
  fi
  # Each mutant's kill needs the shipped arm it must flip AND the copy-under-test control to have passed in this run.
  if ar_mut "$WORK/arm1" emit-report.sh 'ar_record() {' 'ar_record() { return 0'; then
    ar_flowA "$WORK/arm1" r1; ar_score "$(( ${B_ar_r1:-0} && ${B_arctl:-0} ))" M1 "$AR_V" R1 V0 "the record write disabled"
  else bad "M1 DID NOT APPLY — \`ar_record() {\` is not in emit-report.sh exactly once"; fi
  if ar_mut "$WORK/arm2" emit-report.sh '  ar_read && return 0' '  :'; then
    ar_flowA "$WORK/arm2" r2; ar_score "$(( ${B_ar_r2:-0} && ${B_arctl:-0} ))" M2 "$AR_V" R2 R1 "first-wins made last-wins"
  else bad "M2 DID NOT APPLY — \`  ar_read && return 0\` is not in emit-report.sh exactly once"; fi
  # M3 and M7a anchor on the substitution as f4a56f21f spells it (it also sets _ar_sub). M3 reverts
  # BOTH layers: `got` stays the report's region and _ar_sub stays 0.
  if ar_mut "$WORK/arm3" emit-report.sh '    [ -n "$got" ] && { got="$_ar_first"; _ar_sub=1; }' '    :'; then
    ar_flowA "$WORK/arm3" a; ar_score "$(( ${B_ar_a:-0} && ${B_arctl:-0} ))" M3 "$AR_V" A R2 "apply mode ignores the record"
  else bad "M3 DID NOT APPLY — the record substitution is not in emit-report.sh exactly once"; fi
  if ar_mut "$WORK/arm4" apply.sh "      *[!0-9a-f]*|'') _ar_ok=0 ;;" "      *[!0-9a-f]*|'') _ar_ok=1; _ar_first=NONE ;;"; then
    ar_flowM "$WORK/arm4" bad; M4B="$AR_V"; ar_flowM "$WORK/arm4" absent; M4A="$AR_V"
    ar_score "$(( ${B_ar_mb:-0} && ${B_ar_ma:-0} && ${B_arctl:-0} ))" M4 "$M4B $M4A" M-bad M-absent "a malformed approved-region line read as NONE"
  else bad "M4 DID NOT APPLY — the malformed-line case is not in apply.sh exactly once"; fi
  if ar_mut "$WORK/arm5" apply.sh '            echo "  option label: ${_ra_lb}"' '            echo "  option label: ${_ra_lb/R/r}"'; then
    ar_flowA "$WORK/arm5" f; ar_score "$(( ${B_ar_f1:-0} && ${B_arctl:-0} ))" M5 "$AR_V" F1 A "one character of the PRINTED label changed"
  else bad "M5 DID NOT APPLY — the printed option label is not in apply.sh exactly once"; fi
  if ar_mut "$WORK/arm6" emit-report.sh '[ "$cause" = RE-RENDERED-SINCE-APPROVAL ] && exit 3' '[ "$cause" = RE-RENDERED-SINCE-APPROVAL ] && exit 1'; then
    ar_flowG "$WORK/arm6" g1; ar_score "$(( ${B_ar_g:-0} && ${B_arctl:-0} ))" M6 "$AR_V" G1 G0 "F3 classifies a re-render as exit 1"
  else bad "M6 DID NOT APPLY — the RE-RENDERED-SINCE-APPROVAL exit is not in emit-report.sh exactly once"; fi
  # M7a/M7b re-drive cell (i), whose I1 conjunct compares against the twin; build it here too.
  ar_twin || bad "M7 could not build cell (i)'s twin world, so I1 cannot hold under either M7 mutant"
  if ar_mut "$WORK/arm7a" emit-report.sh '    [ -n "$got" ] && { got="$_ar_first"; _ar_sub=1; }' '    [ -n "$got" ] && { got="$_ar_first"; _ar_sub=1; printf '"'"'%s\n'"'"' "$_ar_first" > "$REPORT"; }'; then
    ar_flowI "$WORK/arm7a"; ar_score "$(( ${B_ar_i2:-0} && ${B_arctl:-0} ))" M7a "$AR_V" I2 I1 "apply mode writes the first region back to the report"
  else bad "M7a DID NOT APPLY — the record substitution is not in emit-report.sh exactly once"; fi
  if ar_mut "$WORK/arm7b" apply.sh "quoting digest \${_ra_dg} answered '\${_ra_lb}'.\${_ar_note}\"" "quoting digest \${_ar_first} answered '\${_ra_lb}'.\${_ar_note}\""; then
    ar_flowI "$WORK/arm7b"; ar_score "$(( ${B_ar_i3:-0} && ${B_arctl:-0} ))" M7b "$AR_V" I3 I2 "the NOTE names the first region's digest as the re-approved one"
  else bad "M7b DID NOT APPLY — the re-approved NOTE is not in apply.sh exactly once"; fi
  if ar_mut "$WORK/arm8" emit-report.sh '  [ "$(sed -n 2p "$_ar_rec" 2>/dev/null)" = "key $_ar_key" ] || return 1' '  :'; then
    ar_flowJ "$WORK/arm8"; ar_score "$(( ${B_ar_j:-0} && ${B_arctl:-0} ))" M8 "$AR_V" J1 J0 "the record's key ignored"
  else bad "M8 DID NOT APPLY — the key comparison is not in emit-report.sh exactly once"; fi
  if ar_mut "$WORK/arm9" emit-report.sh "  if [ \"\$rc\" -eq 0 ]; then printf '%s\\n' \"\$d\"; else printf 'FAILED-%s\\n' \"\$t\"; fi" "  if [ \"\$rc\" -eq 0 ]; then printf '%s\\n' \"\$d\"; else printf 'UNAVAILABLE\\n'; fi"; then
    ar_flowK "$WORK/arm9"; ar_score "$(( ${B_ar_kf:-0} && ${B_arctl:-0} ))" M9 "$AR_V" KF2 KA3 "a failed tool conflated with no tool"
    tk "$AR_V" KV! && tk "$AR_V" KF1! || bad "M9 the record write or the apply-mode state did not move with the conflation [$AR_V]"
  else bad "M9 DID NOT APPLY — the FAILED-<tool> branch is not in emit-report.sh exactly once"; fi
  # M10: the edited-report comparison deleted. ONE CASE IN TWO SHAPES: (n) and n2 both go red, and
  # that is the property, not an entanglement -- n2 is the case after a legitimate re-render (its
  # unseen=0 seed is measured to PROCEED here, N2P). n3 and n4 must hold: the splice keeps its
  # re-render verdict and the unedited world still writes.
  if ar_mut "$WORK/arm10" emit-report.sh 'if [ "$_ar_sub" = 1 ] && [ "$_ar_report_got" != "$got" ] && [ "$_ar_report_got" != "$want" ]; then' 'if false; then'; then
    ar_flowN "$WORK/arm10" edit; M10N="$AR_V"
    ar_flowN2 "$WORK/arm10" n2; M10N2="$AR_V"
    ar_flowN2 "$WORK/arm10" n3; M10N3="$AR_V"
    ar_flowN "$WORK/arm10" plain; M10N4="$AR_V"
    ar_score "$(( ${B_ar_n:-0} && ${B_arctl:-0} ))" M10 "$M10N" N1 N0 "the edited-report comparison deleted: (n)"
    tk "$M10N2" N2E! && tk "$M10N2" N2P && ok "M10 and n2 goes red the same way: its unseen=0 world PROCEEDS (exit 0, written, blockers-resolved NOTE) [$M10N2]" \
                                       || bad "M10 n2 did not proceed under the deleted comparison [$M10N2] — n2 is not a cell only that comparison refuses"
    tk "$M10N3" N3 && tk "$M10N4" NT && tk "$M10N4" N4S && ok "M10 and n3 and n4 HOLD — the splice keeps its re-render verdict and the unedited world writes" \
                                                       || bad "M10 moved n3 or n4 [$M10N3 | $M10N4]"
  else bad "M10 DID NOT APPLY — the edited-report comparison is not in emit-report.sh exactly once"; fi
fi
# --- ARM MUTANT-BY-ARM MATRIX: a re-measurement mode, never run per push ------------------------
# The unmutated copy and every arm mutant driven through EVERY flow of unit ar; one
# `MATRIX` row each, 1 = the token held, 0 = it went red. The row label is the id the kill site passes to mutant_killed.
if [ "$MATRIX" = 1 ] && [ -z "$AR_SKIP" ]; then
  MX_CELLS=$((MX_CELLS + 1))
  AR_MX_CELLS="R1 R2 A F1 F2A F2 G1 G2 I1 I2 I3 J1 KF2 KA3 M-bad M-absent N1 N2E N3"
  echo "MATRIX-BEGIN arm cells=$AR_MX_CELLS"
  ar_twin
  for _mp in CONTROL-AR:arm-ctl M1:arm1 M2:arm2 M3:arm3 M4:arm4 M5:arm5 M6:arm6 M7a:arm7a M7b:arm7b M8:arm8 M9:arm9 M10:arm10; do
    _id="${_mp%%:*}"; _d="$WORK/${_mp#*:}"
    if [ ! -f "$_d/apply.sh" ]; then bad "MATRIX arm $_id: no staged copy, so its row cannot be measured"; continue; fi
    _t=""
    ar_flowA "$_d" f; _t="$_t $AR_V"
    ar_flowF2 "$_d"; _t="$_t $AR_V"
    ar_flowG "$_d" g2; _t="$_t $AR_V"
    ar_flowI "$_d"; _t="$_t $AR_V"
    ar_flowJ "$_d"; _t="$_t $AR_V"
    ar_flowK "$_d"; _t="$_t $AR_V"
    ar_flowM "$_d" bad; _t="$_t $AR_V"
    ar_flowM "$_d" absent; _t="$_t $AR_V"
    ar_flowN "$_d" edit; _t="$_t $AR_V"
    ar_flowN2 "$_d" n2; _t="$_t $AR_V"
    ar_flowN2 "$_d" n3; _t="$_t $AR_V"
    _row="MATRIX $_id"
    for _c in $AR_MX_CELLS; do
      if tk "$_t" "$_c"; then _row="$_row $_c=1"; else _row="$_row $_c=0"; fi
    done
    echo "$_row"
  done
  echo "MATRIX-END arm"
fi

fi  # ---- end of unit arm

# --- matrix-only cells: a plain run enters none, --matrix enters them (every shard reaches this)
if ( MX_CELLS=0; MX_CELLS=$((MX_CELLS + 1)); [ "$MX_CELLS" = 1 ] ); then
  if [ "$MATRIX" = 0 ]; then
    if [ "$MX_CELLS" -eq 0 ]; then ok "MATRIX-PLAIN a plain run executed no matrix-only cell (0 of 8 matrix blocks entered)"
    else bad "MATRIX-PLAIN a plain run entered $MX_CELLS matrix-only block(s) -- --matrix is the only mode that may run them"; fi
  else
    if [ "$MX_CELLS" -gt 0 ]; then ok "MATRIX-PLAIN matrix run entered $MX_CELLS matrix-only block(s)"
    else bad "FIXTURE BROKEN: --matrix entered no matrix block, so it measured nothing"; fi
  fi
else
  bad "FIXTURE BROKEN: the MATRIX cell counter does not count, so the plain-run arm could not fail"
fi

echo "  [shard $GROUP of apply-restamp-worklist: $asserts assertions, $fails failed]"
echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  apply-restamp-worklist: a run that hands back a WORKLIST or a DECISION row leaves"
  echo "      .ai-dlc-version at base and .ai-dlc-applying on disk, says so as DECISION"
  echo "      restamp-withheld rather than RESOLVED restamp, and names --finish so the operator"
  echo "      can stamp once the work is disposed; --finish stamps from theirs and runs no"
  echo "      resolution phase; and a pull with nothing outstanding still stamps as it did."
  echo "      --finish also checks that <theirs> IS the ref the tree was written from, keyed on"
  echo "      the core/ tree so a docs-only move still finishes, refusing by leaving the stamp"
  echo "      and the marker untouched, and saying UNCHECKED rather than nothing when the"
  echo "      in-flight record cannot answer."
  exit 0
fi
echo "$NAME: FAIL ($fails)"
exit 1
