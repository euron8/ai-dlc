#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# those two counters, and nothing collapses them.
#
# AND THE ESCAPE'S ARGUMENT IS CHECKED FOR IDENTITY, NOT MERELY FOR RESOLVABILITY. `--finish` is
# retyped by hand from a row that prints <dist> and <consumer> as placeholders, and its only guard
# on <theirs> asked whether the ref resolves. A ref naming the WRONG thing resolves, so the stamp
# took its sha, `RESOLVED consistent` printed over a tree never brought there, and the marker was
# removed. `.ai-dlc-applying` already recorded `theirs:` and every reader in the tree was an
# existence test. F1/F2/F3 are that join, keyed on the `core/` tree so a docs-only move of the ref
# still finishes, and nothing else breaks the join.
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

. "$HERE/../lib/report.sh" || { echo "apply-restamp-worklist: FIXTURE BROKEN — lib/report.sh not found beside $HERE" >&2; exit 2; }

# ---------------------------------------------------------------------------- shards ----
# THIS FILE IS FOUR SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT
# BOUNDARY (the readset-skip shape). Every section below is a UNIT guarded by `if sg <unit>; then ... fi`;
# `--group <x>` runs the units dealt to shard <x>. `apply-restamp-worklist-{b,c,d}/run.sh` are one-line
# drivers that `exec bash` this file with their group, so the pre-push pool starts each on its own. No
# `--group` runs shard 'a'.
#
# THE SEED AND THE SUBJECT PROBE ARE NOT UNITS: every shard builds the synthetic pull, the three runs and
# the S0-S3 sanity arms, and runs the subject probe, because a shard that skipped them would score its
# units against a harness that never ran. The shared helpers (mk_report, u5_*, build_rec) and
# the hook-registration validator lookup are hoisted above the units for the same reason: units use
# each other's helpers, and a helper living inside a unit another shard owns would be undefined there.
#
# THE COVERAGE JOIN runs in EVERY shard before anything else: the declared units are DERIVED from this
# file's own `if sg <unit>; then` lines, the dealt lists must be disjoint and their union must equal the
# declared set exactly, and every declared shard must have a driver directory. The join proves it can
# fire first, on a seeded duplicate and a seeded omission.
#   a  cf u         C1-C8 / F1-F3 / CWD, U1-U5, RA0-RA9 and RA-X (the restamp guard, --finish and the union gate)
#   b  ar           AR first-verified region
#   c  t vf         T1-T4 transient-ignore row; VF finish-verifies-tree
#   d  bl hr hu   BL-276 routing rows; BL-292 hook-registration row; BL-103 unshipped-hook row. DIST-ONLY: every
#                 arm drives a cmp -s identical copy of the reconcile directory or of the located validator
SHARDS="a b c d"
UNITS_a="cf u"
UNITS_b="ar"
UNITS_c="t vf"
UNITS_d="bl hr hu"
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
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
# THE DIST-ONLY SHARDS: DIST_SHARDS reach no consumer. Each carries a non-empty .dist-only and no other shard does,
# and a consumer holds none of their directories, so only a DIST_SHARDS shard, whose inputs.decl declares its
# dist-only siblings, checks their drivers and markers; a shipped shard declares none and skips them.
DIST_SHARDS="d"
# The units that must stay in a shipped shard; the join fails if one is undeclared or dealt to a DIST_SHARDS shard:
# cf reads the installed pre-push and runs apply.sh in place; u and vf run apply.sh in place; ar runs the
# in-place reconcile directory; t walks up from apply.sh to a root and resolves by layout.
PLACED_UNITS="cf u ar t vf"
_decl=" "; while IFS= read -r _l; do _decl="$_decl$_l "; done < "$JW/declared"
for _u in $PLACED_UNITS; do
  case "$_decl" in *" $_u "*) ;; *) rm -rf "$JW"; shard_broken "PLACED_UNITS names '$_u', which no unit guard declares" ;; esac
  for _s in $DIST_SHARDS; do
    eval "_l=\" \${UNITS_$_s} \""
    case "$_l" in *" $_u "*) rm -rf "$JW"; shard_broken "unit '$_u' is in PLACED_UNITS but is dealt to dist-only shard '$_s'; it must stay in a shipped shard" ;; esac
  done
done
case " $DIST_SHARDS " in *" $GROUP "*) _me=dist ;; *) _me=ship ;; esac
[ ! -e "$HERE/.dist-only" ] || { rm -rf "$JW"; shard_broken "shard 'a' carries $HERE/.dist-only, but shard a ships"; }
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  case " $DIST_SHARDS " in *" $_s "*) _do=1 ;; *) _do=0 ;; esac
  [ "$_do" = 1 ] && [ "$_me" = ship ] && continue
  _drv="$HERE/../apply-restamp-worklist-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    rm -rf "$JW"; shard_broken "shard '$_s' is declared but $_drv does not drive it"
  fi
  if [ "$_do" = 1 ] && [ ! -s "${_drv%/run.sh}/.dist-only" ]; then
    rm -rf "$JW"; shard_broken "shard '$_s' is in DIST_SHARDS but ${_drv%/run.sh}/.dist-only is absent or empty"
  fi
  if [ "$_do" = 0 ] && [ -e "${_drv%/run.sh}/.dist-only" ]; then
    rm -rf "$JW"; shard_broken "shard '$_s' carries ${_drv%/run.sh}/.dist-only but is not in DIST_SHARDS"
  fi
done
rm -rf "$JW"
echo "  [J0] coverage join: $ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"

# THE RESOLVED PATH IS PRINTED, not inferred from the layout. Two candidates exist and the first
# that resolves wins, so an edit in the other copy leaves every arm green and reads
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

# --- THE RECORDED RE-APPROVAL (RA1-RA3, RA8-RA9f, MR1-MR2) -----------------------------------------
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
# and a proceed arm would then go red for the wrong reason.
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

# A COPY of the whole reconcile directory — apply.sh `eval`s map_consumer() out of its sibling preclassify.sh and shells
# to retired-tokens.sh and unregistered-drift.sh, so a lone script copy dies before printing anything.
build_rec() { # build_rec <dir>
  mkdir -p "$1" && cp "$REC"/* "$1"/ 2>/dev/null && [ -f "$1/apply.sh" ]
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
    report_end apply-restamp-worklist
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
# ONLY units cf and vf READ OUT_GREEN/C_GREEN (and S2 below), and only unit cf reads the worklist and decision
# seeds (and S1), so a shard builds and runs only the consumers its units read.
SEED_RUNS=0; if sg cf || sg vf || sg u; then SEED_RUNS=1; fi
SEED_CF=0; if sg cf; then SEED_CF=1; fi
if [ "$SEED_RUNS" = 1 ]; then
C_GREEN="$WORK/cons-green"; C_WORK="$WORK/cons-worklist"; C_DEC="$WORK/cons-decision"
mk_consumer "$C_GREEN" green    || { echo "FIXTURE BROKEN — could not build the green consumer" >&2; exit 2; }
OUT_GREEN="$(run_apply "$APPLY" "$C_GREEN")"; RC_GREEN=$?
# U3's state is this one (a green consumer, no report), so U3 reads this run; later cf arms touch C_GREEN, so
# its stamp is read here, before any of them.
GREEN_VER0="$(stamp_ver "$C_GREEN")"
fi
if [ "$SEED_CF" = 1 ]; then
mk_consumer "$C_WORK"  worklist || { echo "FIXTURE BROKEN — could not build the worklist consumer" >&2; exit 2; }
mk_consumer "$C_DEC"   decision || { echo "FIXTURE BROKEN — could not build the decision consumer" >&2; exit 2; }
OUT_WORK="$(run_apply "$APPLY" "$C_WORK")"
OUT_DEC="$(run_apply "$APPLY" "$C_DEC")"
fi

if [ "$SEED_CF" = 1 ]; then
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
fi

if [ "$SEED_RUNS" = 1 ]; then
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
  ok "C1 a run carrying a WORKLIST row leaves .ai-dlc-version at base (version: 1.0.0)"
else
  bad "C1 the stamp advanced to 'version: ${W_VER:-<absent>} / commit: ${W_SHA:-<absent>}' over a tree with an outstanding semantic merge. It should read 1.0.0 @ $BASE. The next pull computes its base from this file, so it will merge from a ref this tree never reached"
fi
if [ "$W_MK" = PRESENT ]; then
  ok "C1 and .ai-dlc-applying survives — the fixture suite stays blocked on a tree whose merges are outstanding"
else
  bad "C1 .ai-dlc-applying was removed on a run that handed back a semantic merge. pre-push re-enables the fixture suite over a partially reconciled tree, which is the one state the marker exists to keep unjudged"
fi

# --- C3: the pre-existing green path does not regress -----------------------------------------
# THE ARM THAT CATCHES AN OVER-BROAD FIX. A guard that counts rows emitted after it — or that is
# read at exit rather than at the guard — withholds the stamp on every clean pull, and a consumer
# that can never stamp can never push.
G_VER="$(stamp_ver "$C_GREEN")"; G_SHA="$(stamp_sha "$C_GREEN")"; G_MK="$(marker "$C_GREEN")"
if [ "$G_VER" = "$THEIRS_VER" ] && [ "$G_SHA" = "$THEIRS_SHORT" ] && [ "$G_MK" = GONE ] \
   && has_row "$OUT_GREEN" RESOLVED restamp; then
  ok "C3 a run with no hand-back still stamps $THEIRS_VER @ $THEIRS_SHORT and clears the marker"
else
  bad "C3 a CLEAN pull was withheld: stamp 'version: ${G_VER:-<absent>} / commit: ${G_SHA:-<absent>}', marker $G_MK. Every consumer with no unregistered-hook validator emits DECISION hook-registration-unchecked after the guard; counting that row withholds every correct pull and the tree can never push again"
fi

# --- C7: a DECISION row withholds it too, on its own -------------------------------------------
# A counter watching `say WORKLIST` alone leaves every operator DECISION
# stamping exactly as before, and the row is emitted from a different phase, so no arm above
# reaches it. C1 owns the marker half for both shapes; this arm asserts the stamp only.
D_VER="$(stamp_ver "$C_DEC")"; D_SHA="$(stamp_sha "$C_DEC")"
if [ "$D_VER" = "1.0.0" ] && [ "$D_SHA" = "$BASE" ] && has_row "$OUT_DEC" DECISION restamp-withheld; then
  ok "C7 a run whose only hand-back is a DECISION row also leaves the stamp at base"
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
  ok "C4 --finish writes version: $THEIRS_VER / commit: $THEIRS_SHORT and removes the marker"
else
  bad "C4 --finish left the stamp at 'version: ${F_VER:-<absent>} / commit: ${F_SHA:-<absent>}' with the marker $F_MK. This is the ONLY exit from a withheld stamp: with the marker present pre-push refuses every push, so a --finish that does not stamp leaves the consumer with no way forward"
fi

# C5 (--finish over a hand-merged tree) and C8 (--finish over a DECISION row it cannot clear) were cut
# by the BL-918 kill matrix: every mutant either killed (m7, m8, m11) is also killed by U4 or C4, which stay.
# U4's world is the same shape as C8's (no hook-registration validator, so --finish emits the DECISION
# before its stamp), so U4 carries C8's property as well as its own.

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
    ok "F1 --finish to a ref whose core/ tree this tree was never written from is REFUSED: the stamp is byte-for-byte the $F1_PRE_VER it held before the run and .ai-dlc-applying is still on disk"
  else
    bad "F1 --finish stamped a ref the recorded in-flight marker disagrees with. Recorded theirs=$THEIRS, argv=$OTHER, and the stamp moved from '$F1_PRE_VER @ $F1_PRE_SHA' to '$F1_VER @ $F1_SHA' with the marker $F1_MK (expected PRESENT and no movement at all). Resolvability was the only question asked of <theirs>, so a fumbled but valid ref advances the stamp the NEXT pull bases its merge on, over a tree that was never brought there"
  fi

  # --- F2: THE NEAR-MISS — a different COMMIT carrying the same core/ tree --------------------
  # THIS ARM EXISTS TO STOP A FUTURE AUTHOR "SIMPLIFYING" THE TREE KEY INTO A COMMIT KEY. The
  # distribution ships docs-only commits between releases, so two refs routinely differ as
  # commits while the bytes this pull WRITES are identical; refusing on the commit wedges a
  # finisher whose only sin is naming the newer of two equivalent refs, and it would look exactly
  # like F1 working. That simplification is what this arm refuses.
  C_IDD="$WORK/cons-id-docs"
  mk_consumer "$C_IDD" finished hrv || { echo "FIXTURE BROKEN — could not build the docs-only consumer" >&2; exit 2; }
  printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_IDD/.claude/.ai-dlc-applying"
  OUT_IDD="$(run_finish_as "$APPLY" "$C_IDD" "$DOCS")"
  F2_VER="$(stamp_ver "$C_IDD")"; F2_SHA="$(stamp_sha "$C_IDD")"; F2_MK="$(marker "$C_IDD")"
  if [ "$F2_VER" = "$THEIRS_VER" ] && [ "$F2_SHA" = "$DOCS_SHORT" ] && [ "$F2_MK" = GONE ] \
     && ! has_row "$OUT_IDD" DECISION restamp-identity-mismatch \
     && ! has_row "$OUT_IDD" DECISION restamp-identity-unchecked; then
    ok "F2 a docs-only move of <theirs> still finishes — stamped $F2_VER @ $DOCS_SHORT, marker cleared, and NEITHER identity row printed"
  else
    bad "F2 a <theirs> differing from the record by a docs-only commit did not finish cleanly: stamp '$F2_VER @ $F2_SHA' (expected $THEIRS_VER @ $DOCS_SHORT), marker $F2_MK (expected GONE), mismatch row $(has_row "$OUT_IDD" DECISION restamp-identity-mismatch && echo present || echo absent), unchecked row $(has_row "$OUT_IDD" DECISION restamp-identity-unchecked && echo present || echo absent). ${DOCS} and ${THEIRS} carry the identical core/ tree $S3_T, so the bytes this pull writes are the same at both — a guard that stops here is keyed on the commit and wedges every finisher naming the newer of two equivalent refs"
  fi

  # F3 (an unusable record does not refuse) was cut by the BL-918 kill matrix: its one killer, m11,
  # is killed by C4 too (identical kill column), and m11's per-push kill now reads C4.
fi

# --- C6: the withheld row hands the operator the escape ---------------------------------------
# A withheld stamp with no reachable finish command WEDGES the consumer. The premise is asserted
# beside the arm rather than assumed: if pre-push stops refusing on the marker, C6 is guarding a
# hazard that no longer exists and should be re-read, not left quietly green.
WITHHELD_DETAIL="$(detail_of "$OUT_WORK" DECISION restamp-withheld)"
case "$WITHHELD_DETAIL" in
  *--finish*) ok "C6 the withheld row names --finish, so the operator can stamp once the worklist is disposed" ;;
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
C_U1="$WORK/cons-u1"; C_U2="$WORK/cons-u2"; C_U4="$WORK/cons-u4"
C_UCUR="$WORK/cons-ucur"; C_USTALE="$WORK/cons-ustale"
C_X0="$WORK/ra-x0-$$"; C_X1="$WORK/ra-x1-$$"
for c in "$C_UCUR" "$C_USTALE"; do
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
OUT_U3="$OUT_GREEN"; RC_U3="$RC_GREEN"; U3_VER="$GREEN_VER0"

# U1: a report matching THIS run's theirs verifies, and the NOTE does not withhold the stamp.
if [ "$RC_U1" -eq 0 ] && has_row "$OUT_U1" NOTE report-verified \
   && [ "$(stamp_ver "$C_U1")" = "$THEIRS_VER" ]; then
  ok "U1 a report rendered at this run's theirs passes the union gate, and the NOTE row leaves the stamp alone"
else
  bad "U1 a CURRENT report did not pass cleanly (rc=$RC_U1, stamp '$(stamp_ver "$C_U1")', row $(has_row "$OUT_U1" NOTE report-verified && echo present || echo ABSENT)) — either the gate rejects a good report, or it emitted a counting row and withheld a clean pull"
fi

# U2: THE DEFECT. A region rendered at a different upstream must stop the write.
if [ "$RC_U2" -ne 0 ] && [ "$(stamp_ver "$C_U2")" = "1.0.0" ] && [ "$(marker "$C_U2")" = GONE ]; then
  ok "U2 a report rendered at a DIFFERENT theirs refuses the apply (rc=$RC_U2), leaving the stamp at base and writing no in-flight marker"
else
  bad "U2 a STALE region did not stop the apply (rc=$RC_U2, stamp '$(stamp_ver "$C_U2")', marker $(marker "$C_U2")) — upstream moving between the dry run and the apply writes content nobody reviewed"
fi

# U3: no report does NOT block — two dozen fixture directories drive this program without one —
# but the manifest says nobody checked rather than staying silent about it.
if [ "$RC_U3" -eq 0 ] && has_row "$OUT_U3" NOTE report-unverified \
   && [ "$U3_VER" = "$THEIRS_VER" ]; then
  ok "U3 an absent report does not block, and says so as NOTE report-unverified rather than passing silently"
else
  bad "U3 an absent report changed the outcome (rc=$RC_U3, stamp '$U3_VER', row $(has_row "$OUT_U3" NOTE report-unverified && echo present || echo ABSENT)) — either it wedged a driver that has never required a report, or it passed with no row at all"
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
# and a gate that refuses for the right reason are different claims, and these arms hold
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
  "1|1.0.0|GONE|"*) ok "U5 a report approved before its blocker was resolved REFUSES the apply (rc 1), leaving the stamp at base and writing no in-flight marker" ;;
  *)                bad "U5 the apply did not refuse cleanly ($U5, want 1|1.0.0|GONE|...) — either step 7's own prescribed resolution now writes over a region nobody re-approved, or the refusal left a marker the operator has to clear by hand" ;;
esac
case "$U5" in
  *"|CAUSE|REMEDY|"*) ok "U5 and the refusal NAMES the cause (BLOCKERS-RESOLVED) and the one-step remedy with this run's four arguments — not the two false causes it used to offer" ;;
  *)                  bad "U5 the refusal did not name the cause and the remedy ($U5) — the operator is told upstream moved or the region was hand-edited, both false, and the pull is unpassable by any sequence step 7 permits" ;;
esac
case "$U5" in
  *"|FWD") ok "U5 and --verify's own stderr is FORWARDED: the cause line and the want-vs-report diff reach the operator, so 'read the diff' points at a diff they have rather than at a tool they must re-run" ;;
  *)       bad "U5 the refusal did not forward --verify's stderr ($U5) — the message quotes the cause text and then tells the operator to read a diff apply.sh discarded, which is a pointer to nothing" ;;
esac

# --- RA0-RA5: the recorded re-approval, and the exit-0 control --------------------------------
# EVERY RA WORLD IS A COPY of one of two builds: the unseen world above (U5_SRC) or one plain world
# (built below). The digest and label are read ONCE, from the RA-0 probe, and the records are written
# into each copy by the real hook. A copy carries the same report bytes (cfu_copy refuses otherwise) and
# the render is deterministic, so RA2's PROCEED is itself the control that the one digest is the digest
# of every copy: a record quoting a digest that differed would not proceed.
cfu_ra_world() { # cfu_ra_world <src> <dst> <none|right|wrongdg> -> 0 when built as asked
  local dg lb wrong
  cfu_copy "$1" "$2" || return 1
  [ "$3" = none ] && return 0
  dg="${RA_L#digest=}"; dg="${dg%% *}"; lb="${RA_L#* label=\"}"; lb="${lb%\"}"
  [ "${#dg}" -eq 64 ] && [ -n "$lb" ] || return 1
  wrong="$(printf 'a different region\n' | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
  case "$3" in
    right)      ra_answer "$2" "Re-approve the reconcile report? Region digest ${dg}." "$lb" ;;
    wrongdg)    ra_answer "$2" "Re-approve the reconcile report? Region digest ${wrong}." "$lb" ;;
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
      ok "RA-0 setup: the unseen world prints unseen=1 with a 64-hex digest and its label, the plain world unseen=0, and the real answer-capture hook records an AskUserQuestion answer"
    else
      bad "RA-0 setup: unseen world [$RA_L], plain world [$RA_L0], or the hook ($ANSWER_HOOK) wrote no record — the arms below cannot express the case"
    fi
  fi
  # RA1 was scored above, off the same run as U5. RA0, RA1-Q, RA1-R and RA4-RA7 were cut by the BL-918
  # kill matrix: each one's kill column is a subset of a surviving arm's (RA0 = RA2; RA4, RA5, RA7 = RA1;
  # RA6 = RA3; RA1-Q, RA1-R inside RA1 + RA2), so no mutant they kill escapes the arms that remain.
  RA2="$(cfu_ra_drive "$APPLY" a2 "$U5_SRC" right)"
  RA3="$(cfu_ra_drive "$APPLY" a3 "$U5_SRC" wrongdg)"
  if [ "$RA1" = "$RA_STOP" ]; then
    ok "RA1 exit 3 with unseen>0 and no record REFUSES, the target file unwritten and the stamp at base"
  else
    bad "RA1 unseen>0 with no re-approval did not refuse ($RA1, want $RA_STOP) — the defect: a region nobody re-approved is written"
  fi
  if [ "$RA2" = "$RA_GO" ]; then
    ok "RA2 unseen>0 with a hook-written record quoting the digest and answered with the label PROCEEDS"
  else
    bad "RA2 a correct re-approval did not let the apply proceed ($RA2, want $RA_GO) — the gate cannot be satisfied"
  fi
  if [ "$RA3" = "$RA_STOP" ]; then
    ok "RA3 a record answered with the label but quoting a DIFFERENT digest refuses — a re-approval of another region is not this one"
  else
    bad "RA3 a wrong-digest record passed ($RA3, want $RA_STOP) — the label is a constant, so the digest is the only thing binding the record to this region"
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
ti_helpers() { # [apply-file] -- the staging helpers, extracted from <apply-file> (default $APPLY)
  printf 'AP_TMP="$(mktemp -d "%s/ti-stage.XXXXXX")"; ap_stage_dead=0; FINISH=0; mech_fail=0\n' "$WORK"
  sed -n -e '/^ap_stage() {/,/^}$/p' -e '/^ap_staging_refused() {/,/^}$/p' -e '/^ap_stage_or_refuse() {/,/^}$/p' "${1:-$APPLY}"
}
ti_row_out() { # <consumer> [apply-file] -> the row types this consumer draws, or -NONE-
  local c="$1" a="${2:-$APPLY}" out
  out="$( CONSUMER="$c" DIST="$DIST" GIT_CEILING_DIRECTORIES="$TI_CEIL" bash -c '
    handback=0; worklist_n=0
    say() { printf "%s|%s\n" "$1" "$2"; }
    '"$(ti_helpers "$a")"'
    '"$(sed -n '/^transient_ignore_row() {/,/^}$/p' "$a")"'
    transient_ignore_row' 2>/dev/null | tr '\n' ' ' )"
  printf '%s' "${out:--NONE-}"
}
ti_row_text() { # <consumer> [apply-file] -> the row's PROSE, for the arms that discriminate on diagnosis
  local c="$1" a="${2:-$APPLY}"
  CONSUMER="$c" DIST="$DIST" GIT_CEILING_DIRECTORIES="$TI_CEIL" bash -c '
    handback=0; worklist_n=0
    say() { printf "%s\n" "${4:-}"; }
    '"$(ti_helpers "$a")"'
    '"$(sed -n '/^transient_ignore_row() {/,/^}$/p' "$a")"'
    transient_ignore_row' 2>/dev/null | tr '\n' ' '
}
# A REPOSITORY ONLY WHERE A CELL READS THE INDEX (BL-918 T2). The row's tracked half runs `ls-files`
# and is reached only when `rev-parse --git-dir` answers; T3, T5 and T8 read that half, so those worlds keep a
# git-dir. T1, T6 and T7
# read only the renderer's exit and its text, so their worlds are hand-written files with no repo.
# TI_CEIL bounds git's upward discovery at $WORK, so a no-git world under an enclosing repository
# cannot read that repository's index; T-NOGIT asserts it in both directions before any T arm.
TI_CEIL="$WORK"
mk_ti_consumer() { # <dir> <render yes|no> <ondisk yes|no> <tracked yes|no> <break yes|no> <git yes|no>
  local c="$1" rnd="$2" od="$3" tr_="$4" brk="$5" g="$6"
  [ "$g" = yes ] || [ "$tr_" = no ] || return 1
  mkdir -p "$c/scripts/ai-dlc" "$c/.claude/schemas" "$c/_bmad-output" || return 1
  if [ "$g" = yes ]; then
    git -C "$c" init -q . 2>/dev/null || return 1
    git -C "$c" config user.email t@t; git -C "$c" config user.name t
  fi
  cp "$TI_SCHEMA"   "$c/.claude/schemas/pipeline-state-paths.json" || return 1
  cp "$TI_RENDERER" "$c/scripts/ai-dlc/sync-transient-ignore.sh"   || return 1
  printf 'node_modules/\n' > "$c/.gitignore"
  [ "$g" = yes ] && { git -C "$c" add -A >/dev/null 2>&1; git -C "$c" commit -qm base >/dev/null 2>&1; }
  [ "$rnd" = yes ] && GIT_CEILING_DIRECTORIES="$TI_CEIL" bash "$c/scripts/ai-dlc/sync-transient-ignore.sh" --root "$c" >/dev/null 2>&1
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
  [ "$g" = yes ] && { git -C "$c" add -A >/dev/null 2>&1; git -C "$c" commit -qm state >/dev/null 2>&1; }
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
  if mk_ti_consumer "$TI_UNREADABLE" yes no no yes no && mk_ti_consumer "$TI_ONDISK" yes yes no no yes \
     && mk_ti_consumer "$TI_TRACKED" yes yes yes no yes; then
    # T-NOGIT: the no-git world is outside every repository under the ceiling the row runs with, and a
    # git world beside it is inside its own -- so T1 reads the renderer alone, and T3 still reads an index.
    if ! GIT_CEILING_DIRECTORIES="$TI_CEIL" git -C "$TI_UNREADABLE" rev-parse --git-dir >/dev/null 2>&1 \
       && GIT_CEILING_DIRECTORIES="$TI_CEIL" git -C "$TI_ONDISK" rev-parse --git-dir >/dev/null 2>&1; then
      ok "T-NOGIT setup: the hand-written T1 world resolves no git-dir under the row's ceiling and the T3 world resolves its own"
    else
      bad "T-NOGIT setup: the hand-written T1 world resolved a git-dir, or the T3 world did not — a no-git world would read an enclosing index"
    fi
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
    if mk_ti_consumer "$TI_NEVER" no no no no no && mk_ti_consumer "$TI_DRIFT" yes no no no no; then
      # Drift the rendered block by deleting one pattern, leaving the markers in place.
      sed -i.bak '/handoff-in-progress/d' "$TI_DRIFT/.gitignore"; rm -f "$TI_DRIFT/.gitignore.bak"
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
# C1/C4/C7/C8 already separate the two counters, `mk_consumer` already builds a consumer
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

# bl_consumer <dir> <layer:hit|miss|none> <deriv:hit|miss|past|cur|none> <validator:yes|no>
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
    # already reject it. 
    miss) mkdir -p "$c/_bmad-output/planning" || return 1
          { printf '# plan\n\n```derived\n$ grep -c echo %s\n1\n```\n' "$BL_UNCHANGED_CONS"
            printf '\nQuoted below as prose, deliberately not inside a fence:\n\n'
            printf '$ grep -c shadow %s\n' "$BL_CHANGED_CONS"
          } > "$c/_bmad-output/planning/plan.md" ;;
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
# ONE RUN PER STATE: the probe, BL-1 and BL-2 read these two runs of the resolved apply.sh.
BL_BOTH_OK=0; BL_BOTH_OUT=""; BL_BOTH_VEC="BROKEN"
if bl_run both hit hit yes; then BL_BOTH_OK=1; BL_BOTH_OUT="$BL_OUT"; BL_BOTH_VEC="$BL_VEC"; fi
BL_NEAR_OK=0; BL_NEAR_OUT=""; BL_NEAR_VEC="BROKEN"
if bl_run near miss miss yes; then BL_NEAR_OK=1; BL_NEAR_OUT="$BL_OUT"; BL_NEAR_VEC="$BL_VEC"; fi
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
    printf '  SKIP  %s\n' "BL-1..BL-5 — the installed apply.sh predates the retired-layer-passage and artifact-derivations routing rows; they land with a later pull than the one carrying this fixture"
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
    ok "BL-1 a consumer whose layer file reproduces the retired line AND whose artifact fence names the changed core path draws both WORKLIST rows (retired-layer-passage, artifact-derivations)"
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
    ok "BL-2 a near-miss consumer — a PARAPHRASED layer line, and a fenced command naming an UNCHANGED core path while the changed one appears outside any fence — draws neither row"
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
# BL-3's no-artifact half, BL-3z (zero-byte file) and BL-4's empty-corpus half were cut by the BL-918
# kill matrix: every mutant they kill is killed by BL-1 or BL-3 (identical kill columns).

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
    ok "BL-4 a consumer with stranded citations and no validate-artifact-derivations.sh draws DECISION artifact-derivations-unchecked instead of the WORKLIST row — nothing on that tree can re-run the commands, and the row says so"
  else
    bad "BL-4 the validator-absent consumer drew $BL_VEC, not 1|0|0|1 — either the WORKLIST row was emitted naming a script that is not there, or the split reported nothing at all"
  fi
else
  bad "BL-4 setup: could not build the validator-absent consumer"
fi
# BL-5 (--finish emits neither row and stamps) was cut by the BL-918 kill matrix: its one killer,
# BL-m4, is also killed by BL-1 (the re-sited row leaves the ordinary path), and BL-m4's kill reads BL-1.

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
# apply.sh UNDER TEST -- the subject copy -- and calls that function with the globals
# `--finish` gives it (FINISH=1, a staging directory, CONSUMER/DIST/THEIRS). A change to the function
# is therefore seen by the seam exactly as by the program; nothing here restates its grammar. The
# seam's counters are apply.sh's own `say`, so `worklist_n` -- the value `--finish` gates the stamp
# on -- is read off the subject, not recomputed. HR-SEAM and HU-SEAM bind the seam to the program:
# on the worlds that also get an end-to-end run, the seam's rows must be BYTE-IDENTICAL to the
# hook-registration rows the full `--finish` printed over the same tree.
#
# THE WORLDS ARE READ-ONLY UNDER THE SEAM (the validator and the function read settings and hooks;
# staging goes to the seam's own mktemp), so each distinct world is built ONCE and every subject --
# the copy -- is scored against the same tree. Rows land in files OUTSIDE the
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
# (e) --finish over the dangling-only tree withholds was cut by the BL-918 kill matrix: (e)'s kill column
# equals (a)'s. (f), the clean / live-local near-misses, is kept.
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

if [ -n "$HR_SKIP" ]; then
  if [ "$IS_DIST" = 1 ]; then
    bad "HR setup: $HR_SKIP — HARD in the distribution, every BL-292 arm would be unreadable"
  else
    printf '  SKIP  %s\n' "HR-a..HR-f — $HR_SKIP"
  fi
else
HR_PRESENT=1
mkdir -p "$HR_R" || HR_PRESENT=0
HR_SUB="$REC"
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
# the arms that read this world after it still read the state it was built as.
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
  ok "HR-a a dangling-only tree draws ONE WORKLIST settings-merge row whose DANGLING list is exactly ai-dlc-hra-beta.sh — and not the validator's FIX line that follows the list at the same indent"
else
  bad "HR-a the dangling-only tree drew settings-merge=$(hk_n "$HR_R/sub.D" WORKLIST settings-merge) with DANGLING list '$(hr_dlist "$HR_R/sub.D")', not one row listing exactly 'ai-dlc-hra-beta.sh ' — a registration Claude Code cannot run is not reaching the worklist (other rows: unparsed=$(hk_n "$HR_R/sub.D" DECISION hook-registration-unparsed))"
fi
if hr_arm_b "$HR_R/sub.B"; then
  ok "HR-b an unregistered hook AND a dangling one share the ONE settings-merge row, and it names both (alpha UNREGISTERED, beta DANGLING) — one merge clears both"
else
  bad "HR-b the unregistered+dangling tree drew settings-merge=$(hk_n "$HR_R/sub.B" WORKLIST settings-merge), DANGLING list '$(hr_dlist "$HR_R/sub.B")' — the row does not name both hooks"
fi
if hr_arm_c "$HR_R/sub.L"; then
  ok "HR-c a dangling hook registered ONLY in settings.local.json draws WORKLIST settings-local-dangling on .claude/settings.local.json naming ai-dlc-hra-ghost.sh, and NO settings-merge row — that merge never touches the file"
else
  bad "HR-c the local-only dangling tree drew settings-local-dangling=$(hk_n "$HR_R/sub.L" WORKLIST settings-local-dangling) (subject '$(hk_sub "$HR_R/sub.L" WORKLIST settings-local-dangling)') and settings-merge=$(hk_n "$HR_R/sub.L" WORKLIST settings-merge) — the operator is handed a remedy that cannot clear it, or none"
fi
if hr_arm_d "$HR_R/sub.E"; then
  ok "HR-d a settings.json holding [] draws DECISION hook-registration-unparsed — a non-zero exit that named nothing is not read as clean"
else
  bad "HR-d the [] tree drew unparsed=$(hk_n "$HR_R/sub.E" DECISION hook-registration-unparsed), settings-merge=$(hk_n "$HR_R/sub.E" WORKLIST settings-merge) — the validator failed without a list and the row said nothing"
fi
if [ "$(stamp_ver "$HRW_E")" = "$THEIRS_VER" ] && [ "$(marker "$HRW_E")" = GONE ]; then
  ok "HR-d and --finish still stamps over that DECISION — it raises handback, not worklist_n, so a missing interpreter cannot wedge the finisher"
else
  bad "HR-d --finish withheld over DECISION hook-registration-unparsed (stamp '$(stamp_ver "$HRW_E")', marker $(marker "$HRW_E")) — the C8 wedge, reached through the new row"
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
  ok "HR-g a dangling hook registered in BOTH settings.json and settings.local.json is named in the settings-merge row AND in a settings-local-dangling row on .claude/settings.local.json — the merge alone leaves the local block and the validator at exit 1"
else
  bad "HR-g the both-files tree drew settings-merge=$(hk_n "$HR_R/sub.G" WORKLIST settings-merge) (DANGLING list '$(hr_dlist "$HR_R/sub.G")') and settings-local-dangling=$(hk_n "$HR_R/sub.G" WORKLIST settings-local-dangling) — the validator's NOTE list excludes a name also in settings.json, so the operator is sent round twice"
fi

# --- HR-U: the unregistered half of the merge row ------------------------------------------------
# The one row no other arm demands on its own world, so a subject that emits only the dangling half fails.
case "$(hk_det "$HR_R/sub.U" WORKLIST settings-merge)" in
  *"UNREGISTERED after this apply: ai-dlc-hra-alpha.sh "*) HRC_UOK=1 ;;
  *) HRC_UOK=0 ;;
esac
if [ "$HRC_UOK" = 1 ]; then
  ok "HR-U the resolved apply.sh emits the UNREGISTERED settings-merge row naming ai-dlc-hra-alpha.sh"
else
  bad "HR-U the resolved apply.sh did not emit the UNREGISTERED settings-merge row naming ai-dlc-hra-alpha.sh (got '$(hk_det "$HR_R/sub.U" WORKLIST settings-merge)')"
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
HU_SUB="$REC"
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
  ok "HU-a an ai-dlc- hook theirs neither ships nor registers draws WORKLIST hook-unshipped naming it, the settings-merge row does not claim it, and --finish withholds on the tree"
else
  bad "HU-a the orphan hook did not draw its own gating row, or --finish stamped over it (hook-unshipped=$(hk_n "$HU_R/sub.O" WORKLIST hook-unshipped), stamp '$(stamp_ver "$HUW_O")', marker $(marker "$HUW_O")) — the operator is sent to a merge that cannot clear it"
fi
if hu_quiet "$HU_R/sub.X"; then
  ok "HU-c exit 1 — deleting the file — leaves no gating row, the state --finish stamps over (HU-b, end to end)"
else
  bad "HU-c deleting the orphan still drew a gating row (worklist_n=$(hk_wl "$HU_R/sub.X")) — the finisher stays withheld"
fi
if hu_arm_t "$HU_R/sub.N"; then
  ok "HU-t a hook in the template only and one in core/hooks only both stay on the ONE settings-merge row, and no hook-unshipped row fires"
else
  bad "HU-t a template-carried or shipped hook was routed off the settings-merge row (hook-unshipped=$(hk_n "$HU_R/sub.N" WORKLIST hook-unshipped), settings-merge=$(hk_n "$HU_R/sub.N" WORKLIST settings-merge))"
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

# vf_consumer <dir> <none|noadd|full|merged>
#   none    installed at VB, nothing applied
#   noadd   theirs applied except the ADDED core file
#   full    theirs applied; dist-fx (dist-only at THEIRS) correctly never written
#   merged  full, with a-first hand-merged to differ from BOTH base and theirs
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
    merged) printf '# a v1 and v2 hand-merged by the operator\n' > "$c/.claude/session-driver/a-first.sh" ;;
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
# APPLIED files beside it, not on the whole set: an exact set would also move under a change that
# adds an unrelated row (the dist-only one), and an arm must fail only for its own property.
vf_names() {
  local s x; s=" $(vf_subj "$1" WORKLIST finish-unapplied)"; shift
  case "$s" in *" $1 "*) : ;; *) return 1 ;; esac; shift
  for x in "$@"; do case "$s" in *" $x "*) return 1 ;; esac; done
  return 0
}
vf_r2() { vf_run "$1" noadd "$VD" "$VB" "$VT" || return 1
  vf_held "$VF_C" && vf_names "$VF_C" .claude/session-driver/m-added.sh \
    .claude/session-driver/a-first.sh .claude/session-driver/z-second.sh tests/fixtures/ship-fx/run.sh; }
vf_r3() { vf_run "$1" full "$VD" "$VB" "$VT" || return 1
  vf_stamp "$VF_C" && [ ! -e "$VF_C/tests/fixtures/dist-fx" ]; }
vf_r4() { vf_run "$1" merged "$VD" "$VB" "$VT" || return 1
  vf_stamp "$VF_C" && grep -q 'hand-merged' "$VF_C/.claude/session-driver/a-first.sh"; }
vf_r5() { vf_run "$1" none "$VD" "$VT" "$VT" || return 1
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
if [ "$(vf_n "$VF_C" WORKLIST finish-base-unverified)" = 0 ]; then
  VF_PRESENT=0
  if [ "$IS_DIST" = 1 ]; then
    bad "VF0 the resolved apply.sh ($APPLY) emitted no WORKLIST finish-base-unverified over a --finish naming an unresolvable base, so the verified finish is absent. HARD in the distribution; the arms below run anyway"
  else
    printf '  SKIP  %s\n' "VF-R1..VF-DO3 — the installed apply.sh predates the verified --finish; it lands with this same pull"
  fi
else
  ok "VF0 the resolved apply.sh withholds over an unresolvable base with its own WORKLIST row, so the verified finish is present"
fi

if [ "$VF_PRESENT" = 1 ] || [ "$IS_DIST" = 1 ]; then
vf_report() { # vf_report <arm-fn> <label> <ok-text> <bad-text>
  if "$1" "$REC"; then ok "$2 $3"
  else
    bad "$2 $4 (stamp '$(stamp_ver "$VF_C") @ $(stamp_sha "$VF_C")', marker $(marker "$VF_C"), finish-unapplied: '$(vf_subj "$VF_C" WORKLIST finish-unapplied)', base-unverified=$(vf_n "$VF_C" WORKLIST finish-base-unverified), identity-mismatch=$(vf_n "$VF_C" DECISION restamp-identity-mismatch))"
  fi
}
vf_report vf_r1 VF-R1 "nothing applied: --finish withholds, the stamp stays at base, the marker stays, and z-second is named unapplied" \
  "--finish over a tree where NOTHING was applied did not withhold naming z-second"
vf_report vf_r2 VF-R2 "only the ADDED file missing: --finish withholds naming exactly .claude/session-driver/m-added.sh" \
  "--finish over a tree missing only the file this range ADDED did not withhold naming exactly that file"
vf_report vf_r3 VF-R3 "fully applied, the .dist-only fixture added in range and correctly absent: --finish stamps 2.0.0 @ $VT_SHORT and clears the marker" \
  "--finish over a FULLY APPLIED tree did not stamp — a correctly finished consumer is wedged"
vf_report vf_r4 VF-R4 "a hand-merged file (differs from base AND theirs): --finish stamps and leaves the merge in place" \
  "--finish over a tree with a hand-merged file did not stamp — a merged file must never count as unapplied"
vf_report vf_r5 VF-R5 "BASE typed as THEIRS: --finish withholds with WORKLIST finish-base-unverified over a tree where nothing was applied" \
  "--finish with BASE typed as THEIRS did not withhold on the base — an empty range acquits every file"
vf_report vf_r6 VF-R6 "identity mismatch over an unapplied tree: the identity row prints, and NO finish-unapplied / finish-base-unverified / finish-unverified-tree row is computed against the fumbled ref" \
  "--finish naming a ref the marker disputes, over an unapplied tree, did not print the identity row alone"
vf_report vf_do1 VF-DO1 "preclassify classifies by THEIRS against a skewed checkout: dist-fx (marker at THEIRS, not on disk) is DIST-ONLY-SKIP, ship-fx (marker on disk, not at THEIRS) is UPSTREAM-ONLY" \
  "preclassify's dist_only() did not answer from THEIRS against a checkout that disagrees with it"
# VF-RO, VF-R5b, VF-DO2 and VF-DO3 were cut by the BL-918 kill matrix: their kill columns equal VF-R1's, VF-R5's
# and VF-DO1's respectively (VF-DO2 also VF-R3's), so every mutant they kill is killed by an arm that stays.
# CWD: the decisive withhold, re-driven from `/`.
if VF_CWD=/ vf_r1 "$REC"; then
  ok "VF-CWD VF-R1 driven from / reaches the same withheld verdict"
else
  bad "VF-CWD VF-R1 driven from / did not withhold (stamp '$(stamp_ver "$VF_C")', marker $(marker "$VF_C")) — some VF path resolves from the process cwd"
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
# (f) builds its answer record from the question and option label apply PRINTS (R3); (b), (g) and (i) compose the
# label from the computed digest.
#
# A FLOW SETS AR_V, a space-separated list of tokens, one per conjunct, `X` held and `X!` broken, and
# AR_W, its world. Flows run in THIS shell, never inside $( ), so neither is lost to a subshell.
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
# BUILT ONCE PER ARGUMENT LIST AND COPIED (fixture-mutants.md clause 4). The tag names the directory
# and nothing else, so the template is keyed on the REST of the argument list, %q-quoted so no two
# lists share a key ($WORK/.ar-tpl.idx maps each key to its template; ar_w runs inside $( ), so the
# map lives on disk). Every call, the first included, gets a `cp -Rp` copy at its own path.
ar_w() {
  local w="$WORK/ar-$1-$$-$RANDOM" k l t="" n=0; shift
  printf -v k '%q ' "$@"
  if [ -f "$WORK/.ar-tpl.idx" ]; then
    while IFS= read -r l; do n=$((n + 1)); [ "${l#*	}" = "$k" ] && t="$WORK/.ar-tpl.${l%%	*}"; done < "$WORK/.ar-tpl.idx"
  fi
  if [ -z "$t" ]; then
    t="$WORK/.ar-tpl.$((n + 1))"
    ar_w_build "$t" "$@" || return 1
    printf '%s\t%s\n' "$((n + 1))" "$k" >> "$WORK/.ar-tpl.idx" || return 1
  fi
  mkdir -p "$w" && cp -Rp "$t/." "$w/" || return 1
  printf '%s\n' "$w"
}
ar_w_build() { # ar_w_build <dir> <green|worklist> <theirs> [nogit|rendered] -- the world ar_w copies
  local w="$1"
  mkdir -p "$w" || return 1
  printf '%s\n' "$BASE" > "$w/.B"; printf '%s\n' "$3" > "$w/.T"
  mk_consumer "$w/c" "$2" || return 1
  mkdir -p "$w/c/_bmad-output/ai-dlc-update" || return 1
  if [ "${4:-}" != nogit ]; then git -C "$w/c" init -q 2>/dev/null || return 1; fi
  if [ "${4:-}" = rendered ]; then ar_render "$w" || return 1; fi
}
# ar_wr <tag> -> a green git world at THEIRS holding the shipped renderer's report, rendered ONCE in its template
# (clause 4). A plain render writes only the report, and neither the report nor a plain --verify record carries the
# world's path (two worlds at different paths read byte-identical), so a copy is the rendered state. AR-n4 re-proves
# it every run: the twin is an ar_wr copy, and N4S compares its report with a fresh render at the copy's own path.
ar_wr() { ar_w "$1" green "$THEIRS" rendered; }
# ar_wv <tag> -> a copy of AR_V1, the twin's world taken after its first plain --verify (rendered, record written),
# with that verify's rc in <world>/.vrc. Flows I, J, N and n3 start from that state; they do not re-render or
# re-verify it. No snapshot is BROKEN, never a fresh build.
ar_wv() {
  local w="$WORK/ar-$1-$$-$RANDOM"
  [ -n "${AR_V1:-}" ] && [ -s "$AR_V1/.vrc" ] || return 1
  mkdir -p "$w" && cp -Rp "$AR_V1/." "$w/" || return 1
  printf '%s\n' "$w"
}
ar_rec() { printf '%s\n' "$1/c/.git/ai-dlc-approved-region"; }
# ar_render <world> [theirs] -- the SHIPPED renderer, as the session runs it
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


# FLOW I -- R1 approved, R2 = R1 with one row more, a record quoting R2's digest, apply. Compared
# against the twin world AR_I0 (no re-render, written), whose tree is the CURRENT state.
ar_flowI() {
  local r="$1" w rc dg1 dg2 f n=0 bad=0
  AR_V=""; AR_W=""
  w="$(ar_wv I)"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  cp "$w/c/$AR_RPT" "$w/r1.md"; dg1="$(ar_dg "$w")"
  u5_seed_unseen "$w/c" || { av BROKEN; return; }
  ar_render "$w"; cp "$w/c/$AR_RPT" "$w/r2.md"; dg2="$(ar_dg "$w")"
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
  AR_I0="$(ar_wr I0)"; [ -d "$AR_I0" ] || { AR_I0=""; return 1; }
  local a b r=no
  ar_ver "$REC" "$AR_I0"; a=$?
  # AR_V1: this state (rendered, first plain --verify run, record written), copied before anything else lands in it.
  AR_V1="$WORK/.ar-v1"; rm -rf "$AR_V1"
  if mkdir -p "$AR_V1" && cp -Rp "$AR_I0/." "$AR_V1/" && printf '%s\n' "$a" > "$AR_V1/.vrc"; then :; else rm -rf "$AR_V1"; AR_V1=""; fi
  cp "$AR_I0/v.out" "$AR_I0/v0a.out"; cp "$AR_I0/v.err" "$AR_I0/v0a.err"
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
  w="$(ar_wv J)"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"; rec="$(ar_rec "$w")"
  printf '%s\n' "$OTHER" > "$w/.T2"
  rc="$(cat "$w/.vrc")"
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
  w="$(ar_wr K)"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
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
  w="$(ar_wr KA)"; [ -d "$w" ] || { av BROKEN; return; }
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
  w="$(ar_wv N)"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  rc="$(cat "$w/.vrc")"
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
# ar_flowN2 <rec-dir> n3 -- record R1, an unseen row appears, and the fresh region is spliced in by awk so the
# report EQUALS the fresh render byte for byte: it keeps the re-render verdict. (Its n2 shape was cut by the
# BL-918 kill matrix: N2E's kill column equals N1's.)
ar_flowN2() {
  local r="$1" w rc
  AR_V=""; AR_W=""
  w="$(ar_wv "$2")"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  rc="$(cat "$w/.vrc")"
  [ "$rc" -eq 0 ] && [ -s "$(ar_rec "$w")" ] && av N0 || av N0!
  u5_seed_unseen "$w/c" || { av BROKEN; return; }
  # Not emit-report.sh's file: the fresh region is spliced in by awk over a report holding R1.
  { printf '# reconcile report (fixture)\n\n'
    bash "$EMIT" "$DIST" "$(ar_B "$w")" "$w/c" "$(ar_T "$w")" 2>/dev/null
  } > "$w/fresh.md"
  awk 'NR==FNR {print; next}' "$w/fresh.md" "$w/c/$AR_RPT" > "$w/c/$AR_RPT.new" && mv "$w/c/$AR_RPT.new" "$w/c/$AR_RPT"
  cmp -s "$w/fresh.md" "$w/c/$AR_RPT" || { av BROKEN; return; }
  ar_app "$r" "$w"; rc=$?
  ar_flowN_score "$w" "$rc" "$2"
}
# ar_flowN_score <world> <rc> <edit|plain|n3>
ar_flowN_score() {
  local w="$1" rc="$2"
  case "$3" in
    n3)
      if [ "$rc" -ne 0 ] && ! ar_wrote "$w" && grep -qF 'apply: RE-APPROVAL OWED.' "$w/a.err" \
         && grep -q '^  cause: RE-RENDERED-SINCE-APPROVAL ' "$w/a.err" && ! grep -qF -- "$AR_N_CAUSE" "$w/a.err" \
         && ! has_row "$(cat "$w/a.out")" NOTE report-verified; then av N3; else av N3!; fi
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
  w="$(ar_wr M)"; [ -d "$w" ] || { AR_V=BROKEN; return; }
  AR_W="$w"
  ar_app "$h" "$w"; rc=$?
  local found='(found 1)'; [ "$2" = absent ] && found='(found 0)'
  if [ "$rc" -ne 0 ] && ! ar_wrote "$w" && grep -qF 'did not print exactly one well-formed' "$w/a.err" \
     && grep -qF -- "$found" "$w/a.err" && grep -qF 'NOTHING HAS BEEN WRITTEN.' "$w/a.err"; then
    av "M-$2"
  else
    av "M-$2!"
  fi
}

# --- UNIT ar: the SHIPPED-engine cells of the first-verified region (ar_seg is true for every segment, ARSEG=all) ----
ARSEG=all
ar_seg() { [ "$ARSEG" = all ] && return 0; case " $ARSEG " in *" $1 "*) return 0 ;; esac; return 1; }
ar_cells() {
if [ -n "$AR_SKIP" ]; then
  printf '  SKIP  AR (first-verified region) -- %s\n' "$AR_SKIP"
else
  if ar_seg I; then
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
  fi
  if ar_seg A; then
  ar_flowA "$REC" a h; FA="$AR_V"; WA="$AR_W"
  if tk "$FA" R1; then
    ok "AR-r1 a plain --verify exiting 0 writes the record in the consumer's git-dir: version line, key <base> <theirs>, and the approved region with its HARD row"
  else
    bad "AR-r1 no well-formed record after the first plain --verify [$FA]"
  fi
  tk "$FA" V3 && tk "$FA" H3 && ok "AR-h3 with the blocker resolved and no re-render plain --verify still exits 3, and its stdout and stderr are byte-identical with the record present and with it removed (and that run writes none)" \
              || bad "AR-h3 the un-re-rendered control or plain --verify's exit-3 bytes moved with the record [$FA]"
  if tk "$FA" RR && tk "$FA" V0b && tk "$FA" R2; then
    ok "AR-r2 after the hand re-render plain --verify exits 0 and the record is byte-identical to the first one, still carrying the HARD row (first-wins)"
  else
    bad "AR-r2 the re-render's plain --verify did not exit 0, or REWROTE the record [$FA]"
  fi
  if tk "$FA" A; then
    ok "AR-a a hand re-render with no answer record REFUSES: tree unwritten, RE-APPROVAL OWED, cause BLOCKERS-RESOLVED and the fresh region's full digest printed, the approved-region line stripped"
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
    ok "AR-f1 R3 on the BLOCKERS-RESOLVED path: a record built from exactly the question and option label apply PRINTED lets the re-run write"
  else
    bad "AR-f1 apply's own printed question and label do not satisfy its own gate on the BLOCKERS-RESOLVED path [$FF1]"
  fi
  fi
  # AR-f2 (flow F2), AR-g (flow G) and AR-i3 were cut by the BL-918 kill matrix: cells F2A, F2, G1, G2 and I3
  # kill only mutants a surviving cell also kills (R1, A, F1, I1, N3). G0 and the flows' FV0 tokens were
  # those flows' own preconditions and went with them.
  if ar_seg I; then
  ar_flowI "$REC"; FI="$AR_V"
  if tk "$FI" I0 && tk "$FI" I1; then
    ok "AR-i1 a re-render cleared by a recorded re-approval writes a tree byte-identical, file by file, to the one the same world writes with no re-render"
  else
    bad "AR-i1 the re-approved re-render wrote a tree that is not the current state [$FI]"
  fi
  if tk "$FI" I2; then
    ok "AR-i2 the report still holds the re-rendered region R2 after apply — apply mode never wrote the first region back"
  else
    bad "AR-i2 the report no longer holds R2 after apply [$FI]"
  fi
  fi
  if ar_seg J; then
  ar_flowJ "$REC"; FJ="$AR_V"
  if tk "$FJ" J0 && tk "$FJ" J1 && tk "$FJ" J2 && tk "$FJ" J3; then
    ok "AR-j a ref move starts a fresh record: plain --verify at T2 replaces the T record (key T2), apply mode reads first= as T2's region and apply at T2 writes"
  else
    bad "AR-j a record from another theirs was reused or not replaced [$FJ]"
  fi
  fi
  if ar_seg D; then
  # (d) no record at all: d1 a git toplevel never verified, d2 not a git toplevel.
  for kind in d1 d2; do
    if [ "$kind" = d1 ]; then
      wd="$(ar_wr d1)"
    else
      wd="$(ar_w d2 green "$THEIRS" nogit)"; [ -d "$wd" ] && ar_render "$wd"
    fi
    if [ -d "$wd" ]; then
      ar_app "$REC" "$wd"; rc=$?
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
  fi
  if ar_seg K; then
  ar_flowK "$REC"; FK="$AR_V"
  tk "$FK" KV && tk "$FK" KV2 && ok "AR-k plain --verify under a shasum that exists and fails exits 0 with its success line and writes NO record; the same world with a working shasum writes one" \
                              || bad "AR-k a failed digest was recorded, or a working one was not [$FK]"
  if tk "$FK" KF1 && tk "$FK" KF2; then
    ok "AR-k apply mode reads first=FAILED-shasum and apply REFUSES naming the failed tool, tree unwritten — never UNAVAILABLE, never proceeding"
  else
    bad "AR-k a failing shasum did not refuse as FAILED-shasum [$FK]"
  fi
  if tk "$FK" KA1 && tk "$FK" KA2 && tk "$FK" KA3; then
    ok "AR-k twin: with NO sha256 tool the record is still written, apply mode reads first=UNAVAILABLE, and a matching report writes as the engine documents"
  else
    bad "AR-k twin: the no-tool state does not behave as documented [$FK]"
  fi
  fi
  if ar_seg M; then
  ar_flowM "$REC" bad; FMB="$AR_V"
  ar_flowM "$REC" absent; FMA="$AR_V"
  if tk "$FMB" M-bad; then
    ok "AR-m a malformed approved-region line (first=not-a-digest) REFUSES before anything is decided, tree unwritten — it is never read as NONE"
  else
    bad "AR-m a malformed approved-region line did not refuse [$FMB]"
  fi
  if tk "$FMA" M-absent; then
    ok "AR-m an absent approved-region line REFUSES (found 0), tree unwritten"
  else
    bad "AR-m an absent approved-region line did not refuse [$FMA]"
  fi
  fi
  if ar_seg N; then
  # (n)-(n4): THE REPORT IS STILL COMPARED, FOR HAND EDITS. Every flow above re-renders with the
  # shipped renderer, so none can see a region no renderer produced.
  ar_flowN "$REC" edit; FN="$AR_V"
  if tk "$FN" N0 && tk "$FN" N1; then
    ok "AR-n a report hand-edited after the record was written (rows deleted, a bogus row added, no re-render) REFUSES with the edited-after-first-verify cause and NOTHING HAS BEEN WRITTEN, tree unwritten, no report-verified NOTE"
  else
    bad "AR-n a hand-edited report was not refused as edited after the first --verify [$FN]"
  fi
  fi
  if ar_seg NT; then
  # (n)'s ALLOW twin is the twin world AR_I0 (green, rendered, verified, applied), the same state ar_flowN plain builds.
  ar_flowNT_twin; FNT="$AR_V"
  if tk "$FNT" N4S && tk "$FNT" NT; then
    ok "AR-n4 (also (n)'s ALLOW twin, one property apart): report, record and fresh render are one region, and apply writes with the report-verified NOTE"
  else
    bad "AR-n4 the unedited world did not write cleanly, or its three regions differ [$FNT]"
  fi
  fi
  if ar_seg N2; then
  # AR-n2 was cut by the BL-918 kill matrix: N2E's kill column equals N1's (M10 only). Its N2P probe qualified N2E alone.
  ar_flowN2 "$REC" n3; FN3="$AR_V"
  if tk "$FN3" N3; then
    ok "AR-n3 a report spliced by awk to EQUAL the fresh render byte for byte keeps the re-render verdict: RE-RENDERED-SINCE-APPROVAL, RE-APPROVAL OWED, not acquitted as report-verified, not called edited"
  else
    bad "AR-n3 a byte-equal hand splice did not keep the re-render verdict [$FN3]"
  fi
  fi
fi
}
if sg ar; then
ARSEG=all; ar_cells
fi  # ---- end of unit ar

echo "  [shard $GROUP of apply-restamp-worklist: $((oks + fails)) assertions, $fails failed]"
echo
report_end "$NAME"
