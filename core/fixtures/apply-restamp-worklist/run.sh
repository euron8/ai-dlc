#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# THE RESOLVED PATH IS PRINTED, not inferred from the layout. Two candidates exist and the first
# that resolves wins, so a mutant edited into the other copy leaves every arm green and reads
# exactly like an arm that cannot fire. This line is what makes that visible in a suite log.
echo "apply-restamp-worklist: driving $APPLY"

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

# mk_consumer <dir> <green|worklist|decision> [hrv]
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
C_GREEN="$WORK/cons-green"; C_WORK="$WORK/cons-worklist"; C_DEC="$WORK/cons-decision"
mk_consumer "$C_GREEN" green    || { echo "FIXTURE BROKEN — could not build the green consumer" >&2; exit 2; }
mk_consumer "$C_WORK"  worklist || { echo "FIXTURE BROKEN — could not build the worklist consumer" >&2; exit 2; }
mk_consumer "$C_DEC"   decision || { echo "FIXTURE BROKEN — could not build the decision consumer" >&2; exit 2; }

OUT_GREEN="$(run_apply "$APPLY" "$C_GREEN")"
OUT_WORK="$(run_apply "$APPLY" "$C_WORK")"
OUT_DEC="$(run_apply "$APPLY" "$C_DEC")"

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
  ok "C3 a run with no hand-back still stamps $THEIRS_VER @ $THEIRS_SHORT and clears the marker"
else
  bad "C3 a CLEAN pull was withheld: stamp 'version: ${G_VER:-<absent>} / commit: ${G_SHA:-<absent>}', marker $G_MK. Every consumer with no unregistered-hook validator emits DECISION hook-registration-unchecked after the guard; counting that row withholds every correct pull and the tree can never push again"
fi

# --- C7: a DECISION row withholds it too, on its own -------------------------------------------
# The seed m3 needs. A counter watching `say WORKLIST` alone leaves every operator DECISION
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
mk_consumer "$C_FIN" green hrv || { echo "FIXTURE BROKEN — could not build the finish consumer" >&2; exit 2; }
# The state --finish is FOR: a previous run withheld, so the marker is on disk and the operator
# has since disposed of the worklist by hand.
printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_FIN/.claude/.ai-dlc-applying"
OUT_FIN="$(run_apply "$APPLY" "$C_FIN" --finish)"
F_VER="$(stamp_ver "$C_FIN")"; F_SHA="$(stamp_sha "$C_FIN")"; F_MK="$(marker "$C_FIN")"
if [ "$F_VER" = "$THEIRS_VER" ] && [ "$F_SHA" = "$THEIRS_SHORT" ] && [ "$F_MK" = GONE ]; then
  ok "C4 --finish writes version: $THEIRS_VER / commit: $THEIRS_SHORT and removes the marker"
else
  bad "C4 --finish left the stamp at 'version: ${F_VER:-<absent>} / commit: ${F_SHA:-<absent>}' with the marker $F_MK. This is the ONLY exit from a withheld stamp: with the marker present pre-push refuses every push, so a --finish that does not stamp leaves the consumer with no way forward"
fi
if ! grep -q 'UPSTREAM' "$C_FIN/$DRIVER_REL"; then
  ok "C5 --finish performed no resolution work — $DRIVER_REL is untouched"
else
  bad "C5 --finish overwrote $DRIVER_REL from theirs, so it ran the resolution phases. In the real workflow that deadlocks: a BOTH-CHANGED file the operator has just merged re-buckets to CLASSIFY on every subsequent run, so the hand-back never empties and the stamp is never reached"
fi

# --- C8: --finish TERMINATES over a DECISION row it cannot clear -------------------------------
# The same tree as C4 minus the hook-registration validator, so apply.sh emits
# `DECISION hook-registration-unchecked` and — under --finish alone — emits it BEFORE the stamp.
# A finisher gating on the same counter as the ordinary run withholds on that row, and the row's
# own remedy is to re-run the apply, which is the phase --finish exists to skip. The consumer is
# then wedged with the marker on disk and no invocation that can clear it, which is the failure
# this whole change exists to prevent, reintroduced one layer down by the change itself.
C_TERM="$WORK/cons-terminate"
mk_consumer "$C_TERM" green || { echo "FIXTURE BROKEN — could not build the terminate consumer" >&2; exit 2; }
printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$C_TERM/.claude/.ai-dlc-applying"
OUT_TERM="$(run_apply "$APPLY" "$C_TERM" --finish)"
if ! has_row "$OUT_TERM" DECISION hook-registration-unchecked; then
  bad "C8 setup: --finish emitted no DECISION row on a consumer with no validate-hook-registration.sh, so this arm cannot distinguish the two counters and its pass is vacuous"
elif [ "$(stamp_ver "$C_TERM")" = "$THEIRS_VER" ] && [ "$(marker "$C_TERM")" = GONE ]; then
  ok "C8 --finish stamps over a DECISION row it has no phase to clear — the escape terminates"
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
mk_consumer "$C_IDN" green hrv || { echo "FIXTURE BROKEN — could not build the no-record consumer" >&2; exit 2; }
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
  mk_consumer "$C_IDM" green hrv || { echo "FIXTURE BROKEN — could not build the mismatch consumer" >&2; exit 2; }
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
  # like F1 working. Mutant m10 below is that simplification, and this is the arm that kills it.
  C_IDD="$WORK/cons-id-docs"
  mk_consumer "$C_IDD" green hrv || { echo "FIXTURE BROKEN — could not build the docs-only consumer" >&2; exit 2; }
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

  # --- F3: IT NEVER FAILS FOR WANT OF THE RECORD ----------------------------------------------
  # The over-broad fix — refusing whenever identity could not be CONFIRMED — wedges the consumer
  # whose marker was cleared by hand, which is the remedy `core/git-hooks/pre-push` itself prints.
  # F0 above owns the ROW on this run; F3 owns the EFFECT, so neither is a restatement of the
  # other. Mutant m11 below is that over-broad fix.
  F3_VER="$(stamp_ver "$C_IDN")"; F3_MK="$(marker "$C_IDN")"
  if [ "$F3_VER" = "$OTHER_VER" ] && [ "$F3_MK" = GONE ] && has_row "$OUT_IDN" RESOLVED restamp; then
    ok "F3 an unusable record is UNCHECKED and not refused — the stamp still advanced to $OTHER_VER and the marker cleared"
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
EMIT="$REC/emit-report.sh"
mk_report() { # mk_report <consumer> <theirs-to-render-at>
  mkdir -p "$1/_bmad-output/ai-dlc-update" || return 1
  { printf '# reconcile report (fixture)\n\n'
    bash "$EMIT" "$DIST" "$BASE" "$1" "$2" 2>/dev/null
  } > "$1/_bmad-output/ai-dlc-update/reconcile-report.md"
}

C_U1="$WORK/cons-u1"; C_U2="$WORK/cons-u2"; C_U3="$WORK/cons-u3"; C_U4="$WORK/cons-u4"
for c in "$C_U1" "$C_U2" "$C_U3" "$C_U4"; do
  mk_consumer "$c" green || { echo "FIXTURE BROKEN — could not build a union-gate consumer" >&2; exit 2; }
done
mk_report "$C_U1" "$THEIRS"   # current: rendered at the ref apply will use
mk_report "$C_U2" "$BASE"     # stale:   rendered at an OLDER upstream
mk_report "$C_U4" "$BASE"     # stale, for the --finish arm

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
u5_build() { # u5_build <consumer> — approve WITH the blocker, then resolve it
  mk_consumer "$1" green || return 1
  u5_seed_blocker "$1" || return 1
  mk_report "$1" "$THEIRS" || return 1
  rm -rf "$1/.claude/skills/ai-dlc/overrides"
}
run_apply_err() { bash "$1" "$DIST" "$BASE" "$2" "$THEIRS" 2>"$3"; }
# u5_score <apply-path> -> "<rc>|<stamp>|<marker>|<CAUSE|->|<REMEDY|->|<FWD|->"
# PRESENCE-SHAPED IN EVERY FIELD, and a fresh consumer per drive so no arm reads a previous
# one's leftovers.
#
# FWD IS THE FORWARDED STDERR, and it is keyed on the two things only the forward produces: a
# `cause:` LINE at --verify's own indent, and at least one `<`/`>` diff line. The refusal message
# itself interpolates the cause TEXT, so a `BLOCKERS-RESOLVED` conjunct is satisfied whether or
# not the forward happened; and the message ends by telling the operator to read a diff, which
# without the forward apply.sh has discarded — a pointer to a tool they must re-run.
u5_score() {
  local a="$1" c="$WORK/u5-$$-$RANDOM" e rc
  u5_build "$c" || { echo "BROKEN|||||"; return; }
  e="$c/stderr.txt"
  run_apply_err "$a" "$c" "$e" >/dev/null; rc=$?
  printf '%s|%s|%s|%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" "$(marker "$c")" \
    "$(grep -q 'BLOCKERS-RESOLVED' "$e" && echo CAUSE || echo -)" \
    "$(grep -qF "re-render the region with emit-report.sh $DIST $BASE $c $THEIRS" "$e" \
       && grep -q 're-run apply with the same four arguments' "$e" && echo REMEDY || echo -)" \
    "$(grep -qE '^[[:space:]]*cause: ' "$e" && grep -qE '^[<>] ' "$e" && echo FWD || echo -)"
}

C_U5="$WORK/cons-u5"
mk_consumer "$C_U5" green || { echo "FIXTURE BROKEN — could not build the U5 consumer" >&2; exit 2; }
u5_seed_blocker "$C_U5" || { echo "FIXTURE BROKEN — could not seed the U5 blocker" >&2; exit 2; }
mk_report "$C_U5" "$THEIRS"
U5_APPROVED="$C_U5/_bmad-output/ai-dlc-update/reconcile-report.md"
u5_hard_appr="$(grep -c '^HARD-' "$U5_APPROVED")" || u5_hard_appr=0
rm -rf "$C_U5/.claude/skills/ai-dlc/overrides"
U5_AFTER="$WORK/u5-after-region.md"
bash "$EMIT" "$DIST" "$BASE" "$C_U5" "$THEIRS" > "$U5_AFTER" 2>/dev/null
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

U5="$(u5_score "$APPLY")"
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

# --- MUTANTS ----------------------------------------------------------------------------------
# Each is a COPY of the whole reconcile directory — apply.sh `eval`s map_consumer() out of its
# sibling preclassify.sh and shells to retired-tokens.sh and unregistered-drift.sh, so a lone
# script copy dies before printing anything — guarded by `cmp -s` so an edit that matched nothing
# cannot pass as a mutation, and aimed at ONE arm.
build_rec() { # build_rec <dir>
  mkdir -p "$1" && cp "$REC"/* "$1"/ 2>/dev/null && [ -f "$1/apply.sh" ]
}
# Every mutant verdict is PRESENCE-shaped: a mutant that emits nothing must not score as a kill.
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

# THE UNMUTATED CONTROL, and it carries a POSITIVE conjunct. A control asserting only "nothing
# went wrong" passes against a subject replaced by `exit 0`; this one requires the withheld row
# to be THERE and the green run to stamp, so a copy that cannot run reports as broken rather than
# as clean.
if build_rec "$WORK/mut-ctl"; then
  CTL_W="$(mut_stamp "$WORK/mut-ctl" worklist -)"
  CTL_G="$(mut_stamp "$WORK/mut-ctl" green -)"
  if [ "$CTL_W" = "1.0.0|PRESENT|WITHHELD|OVERWRITTEN" ] && [ "${CTL_G%%|*}" = "$THEIRS_VER" ]; then
    ok "CONTROL an unmutated copy in a fresh directory reproduces both verdicts, so a mutant's silence is the mutation and not the copy"
  else
    bad "CONTROL the unmutated copy did not reproduce the shipped behaviour (worklist=$CTL_W green=$CTL_G) — every mutant verdict below is unreadable"
  fi
else
  bad "CONTROL could not stage a copy of $REC — every mutant verdict below is unreadable"
fi

# mut <n> <label> <arm-it-must-kill> <transform-command...> reading apply.sh on stdin
mut_apply() { # mut_apply <dir> ; transform reads $REC/apply.sh from stdin, writes stdout
  build_rec "$1" || return 1
  cat > "$1/apply.sh"
  ! cmp -s "$REC/apply.sh" "$1/apply.sh"
}

# --- m1: the guard reverted to `mech_fail` alone — the unfixed program. Must die on C1. -------
if sed 's/^if \[ "$mech_fail" -gt 0 \].*$/if [ "$mech_fail" -gt 0 ]; then/' "$REC/apply.sh" \
   | mut_apply "$WORK/m1"; then
  M1="$(mut_stamp "$WORK/m1" worklist -)"
  case "$M1" in
    "$THEIRS_VER|GONE|"*) ok "m1 (guard on mech_fail alone): C1 goes red — the WORKLIST run stamps $THEIRS_VER and clears the marker, which is the shipped defect" ;;
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
    "1.0.0|GONE|WITHHELD|"*) ok "m2 (marker cleared outside the read-back): C1's marker half goes red while its stamp half stays green — the half a row-count assertion cannot see" ;;
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
    "$THEIRS_VER|GONE|"*) ok "m3 (handback counts WORKLIST only): C7 goes red — a gated deletion is outstanding work and it stamps anyway" ;;
    "1.0.0|"*)            bad "m3 SURVIVED: the DECISION-only run was still withheld with DECISION renamed inside say(), so C7 is not testing the DECISION half ($M3D)" ;;
    *)                    bad "m3 produced an unrecognised verdict ($M3D) — its kill would be unearned" ;;
  esac
  M3W="$(mut_stamp "$WORK/m3" worklist -)"
  case "$M3W" in
    "1.0.0|PRESENT|"*) ok "m3 and C1 stays green under it — the WORKLIST seed and the DECISION seed are separately losable, which is why both arms exist" ;;
    *)                 bad "m3 also killed C1 ($M3W): the two seeds are not independent and one of the arms proves nothing" ;;
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
    "")         bad "m4 killed the whole row rather than the token — the mutation was not confined and C6's kill is unearned" ;;
    *)          ok "m4 (the escape unnamed): C6 goes red — the operator is left with a refused push and a row that points nowhere" ;;
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
    "$THEIRS_VER|GONE|"*) ok "m5 (hand-back term compared -lt 0): C1 goes red — the term is present and unsatisfiable" ;;
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
  M8="$(mut_stamp "$WORK/m8" green - --finish)"
  case "$M8" in
    "1.0.0|PRESENT|WITHHELD|"*) ok "m8 (--finish gates on handback): C8 goes red — the finisher withholds over the DECISION row it emitted itself, and no invocation can clear it" ;;
    "$THEIRS_VER|GONE|"*)       bad "m8 SURVIVED: --finish still stamped while gating on handback, so C8's tree emits no DECISION row and the arm is vacuous ($M8)" ;;
    *)                          bad "m8 produced an unrecognised verdict ($M8)" ;;
  esac
  M8H="$(mut_stamp "$WORK/m8" green hrv --finish)"
  if [ "${M8H%%|*}" = "$THEIRS_VER" ]; then
    ok "m8 and C4 stays green under it — the two counters are separately observable, which is the whole reason C8 exists beside C4"
  else
    bad "m8 also killed C4 ($M8H): C4's consumer is emitting a hand-back row it should not, so the two arms read one input"
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
    M6="$(mut_stamp "$WORK/m6" green hrv --finish)"
    case "$M6" in
      "1.0.0|"*)            ok "m6 (--finish withholds too): C4 goes red — the only exit from a withheld stamp is itself withheld and the tree can never push again" ;;
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
if sed 's/^\([[:space:]]*\)--finish).*$/\1--finish) : ;;/' "$REC/apply.sh" | mut_apply "$WORK/m7"; then
  M7="$(mut_stamp "$WORK/m7" green hrv --finish)"
  case "$M7" in
    *"|OVERWRITTEN") ok "m7 (--finish runs the phases): C5 goes red — the driver file was overwritten from theirs, and in the real workflow a just-merged file re-buckets to CLASSIFY on every run so the hand-back never empties" ;;
    *"|UNTOUCHED")   bad "m7 SURVIVED: no resolution work ran with the --finish branch neutered, so C5 is not testing the phase skip ($M7)" ;;
    *)               bad "m7 produced an unrecognised verdict ($M7)" ;;
  esac
  case "$M7" in
    "$THEIRS_VER|GONE|"*) ok "m7 and C4 stays green under it — a full run on a clean consumer stamps too, so only C5 separates the two modes" ;;
    *)                    bad "m7 also killed C4 ($M7): the two arms are entangled" ;;
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
  mk_consumer "$c" green hrv || { echo "BROKEN||"; return; }
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
    ok "CONTROL(id) an unmutated copy refuses the offender and passes the docs-only near-miss, so m9/m10/m11's verdicts are the mutation and not the copy"
  else
    bad "CONTROL(id) the unmutated copy did not reproduce the shipped identity behaviour (offender=$IDCTL_O expected 1.0.0|PRESENT|MISMATCH, near-miss=$IDCTL_D expected $THEIRS_VER|GONE|NO) — m9/m10/m11 below are unreadable"
  fi
else
  bad "CONTROL(id) could not stage a copy of $REC — m9/m10/m11 below are unreadable"
fi

# --- m9: the guard PRESENT and unsatisfiable — the unfixed program. Must die on F1. ------------
# Made to match NOTHING rather than widened: a widening leaves the same output as the original on
# some inputs and scores a kill it did not earn.
if sed 's/\[ "$_m_tree" != "$_a_tree" \]/[ "$_m_tree" != "$_m_tree" ]/' "$REC/apply.sh" \
   | mut_apply "$WORK/m9"; then
  M9="$(mut_finish_id "$WORK/m9" "$OTHER")"
  case "$M9" in
    "$OTHER_VER|GONE|NO") ok "m9 (tree comparison unsatisfiable): F1 goes red — the offending ref is stamped $OTHER_VER and the marker cleared, which is the shipped defect" ;;
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
    "1.0.0|PRESENT|MISMATCH") ok "m10 (commit key instead of core/ tree key): F2 goes red — a docs-only move of <theirs> is refused and the consumer is wedged" ;;
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
    "1.0.0|"*"|MISMATCH") ok "m11 (unchecked treated as mismatched): F3 goes red — a consumer with no in-flight record can no longer finish at all" ;;
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
  mk_consumer "$c" green || { echo "BROKEN||"; return; }
  mk_report "$c" "$BASE" || { echo "BROKEN||"; return; }
  out="$(run_apply "$rec/apply.sh" "$c")"; rc=$?
  printf '%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" "$(marker "$c")"
}
# The same drive with a CURRENT report — U1's shape rather than U2's. A mutant that widened the
# gate's passing branch to accept every exit code produces the same verdict as one that widened it
# by exactly one, and this is the arm that separates them.
mut_union_current() { # mut_union_current <rec-dir> -> "<rc>|<ver>|<marker>"
  local rec="$1" c="$WORK/muc-$$-$RANDOM" out rc
  mk_consumer "$c" green || { echo "BROKEN||"; return; }
  mk_report "$c" "$THEIRS" || { echo "BROKEN||"; return; }
  out="$(run_apply "$rec/apply.sh" "$c")"; rc=$?
  printf '%s|%s|%s\n' "$rc" "$(stamp_ver "$c")" "$(marker "$c")"
}

if [ -d "$WORK/mut-ctl" ]; then
  UCTL="$(mut_union "$WORK/mut-ctl")"
  if [ "$UCTL" = "1|1.0.0|GONE" ]; then
    ok "CONTROL(m12) the unmutated copy refuses a stale region in a fresh directory, so m12's silence below is the mutation and not the copy"
  else
    bad "CONTROL(m12) the unmutated copy did not refuse a stale region ($UCTL) — m12's verdict is unreadable"
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
    "0|$THEIRS_VER|GONE") ok "m12 (gate reports instead of refusing): U2 goes red — a region rendered at another upstream applies and stamps, which is the defect the gate exists to stop" ;;
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
# demanding only the word survives A1 and proves nothing. `re-render the region with
# emit-report.sh <the four arguments>` is emitted by this branch alone.
if sed 's/^      elif \[ "$_ug_rc" -eq 3 \]; then$/      elif [ 1 -eq 0 ]; then/' "$REC/apply.sh" \
   | mut_apply "$WORK/a1"; then
  A1="$(u5_score "$WORK/a1/apply.sh")"
  case "$A1" in
    "1|1.0.0|GONE|CAUSE|-|FWD") ok "A1 (the exit-3 branch disarmed): U5's DIAGNOSIS half goes red while the refusal AND the forwarded stderr stand — the remedy that closes the state the consumer filed is the one thing gone" ;;
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
  A2="$(u5_score "$WORK/a2/apply.sh")"
  case "$A2" in
    "0|$THEIRS_VER|GONE|"*) ok "A2 (exit 3 treated as a pass): U5's REFUSAL half goes red — the apply writes and stamps $THEIRS_VER over a region nobody re-approved, which is what the carve-out costs" ;;
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
  bad "A2 did not apply — apply.sh no longer opens the union gate with \`if [ \"\$_ug_rc\" -eq 0 ]; then\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# A3: the forward deleted. THE MESSAGE SURVIVES IT INTACT, which is the whole reason this needs
# its own mutant: the refusal interpolates the cause TEXT and ends by telling the operator to read
# the diff, so with the forward gone every word of it still prints and the diff it points at does
# not exist. Only the FWD field records that. rc, the stamp and the marker must all hold, or the
# mutation reached the refusal instead of the forward.
if sed '/^      printf .%s\\n. "$_ug_verr" >&2$/d' "$REC/apply.sh" | mut_apply "$WORK/a3"; then
  A3="$(u5_score "$WORK/a3/apply.sh")"
  case "$A3" in
    "1|1.0.0|GONE|CAUSE|REMEDY|-") ok "A3 (--verify's stderr not forwarded): U5's FORWARD half goes red alone — the refusal, the named cause and the remedy all still print, and the diff the last sentence sends the operator to is gone" ;;
    *"|FWD")                       bad "A3 SURVIVED: the cause line and the diff still reached stderr with the forward deleted ($A3), so U5's forward conjunct is being carried by something else" ;;
    *)                             bad "A3 moved more than the forward ($A3, want 1|1.0.0|GONE|CAUSE|REMEDY|-) — the refusal itself changed, so the forward conjunct's kill is unattributed" ;;
  esac
else
  bad "A3 did not apply — apply.sh no longer forwards --verify's stderr with \`printf '%s\\n' \"\$_ug_verr\" >&2\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

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
ti_row_out() { # <consumer> -> the row types this consumer draws, or -NONE-
  local c="$1" out
  out="$( CONSUMER="$c" DIST="$DIST" bash -c '
    handback=0; worklist_n=0
    say() { printf "%s|%s\n" "$1" "$2"; }
    '"$(sed -n '/^transient_ignore_row() {/,/^}$/p' "$APPLY")"'
    transient_ignore_row' 2>/dev/null | tr '\n' ' ' )"
  printf '%s' "${out:--NONE-}"
}
ti_row_text() { # <consumer> -> the row's PROSE, for the arms that discriminate on diagnosis
  local c="$1"
  CONSUMER="$c" DIST="$DIST" bash -c '
    handback=0; worklist_n=0
    say() { printf "%s\n" "${4:-}"; }
    '"$(sed -n '/^transient_ignore_row() {/,/^}$/p' "$APPLY")"'
    transient_ignore_row' 2>/dev/null | tr '\n' ' '
}
mk_ti_consumer() { # <dir> <render yes|no> <ondisk yes|no> <tracked yes|no> <break yes|no>
  local c="$1" rnd="$2" od="$3" tr_="$4" brk="$5"
  mkdir -p "$c/scripts/ai-dlc" "$c/.claude/schemas" "$c/_bmad-output" || return 1
  git -C "$c" init -q . 2>/dev/null || return 1
  git -C "$c" config user.email t@t; git -C "$c" config user.name t
  cp "$REPO/core/schemas/pipeline-state-paths.json" "$c/.claude/schemas/" || return 1
  cp "$REPO/core/scripts/sync-transient-ignore.sh"  "$c/scripts/ai-dlc/"  || return 1
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
if [ ! -f "$REPO/core/scripts/sync-transient-ignore.sh" ] || [ ! -f "$REPO/core/schemas/pipeline-state-paths.json" ]; then
  # A core fixture ships AHEAD of its subject: say so rather than printing a green line.
  ok "T1-T4 skipped: sync-transient-ignore.sh / pipeline-state-paths.json are not in this tree, so the row's inputs cannot be built"
else
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
    TI_DUR="$WORK/ti-durable"
    if mk_ti_consumer "$TI_DUR" yes yes yes no; then
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

# bl_consumer <dir> <layer:hit|miss|none> <deriv:hit|miss|empty|none> <validator:yes|no>
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
    none)  : ;;
  esac
  if [ "$val" = yes ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
    chmod +x "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
  fi
  printf 'version: 1.0.0\ncommit: %s\n' "$BL_BASE" > "$c/.claude/.ai-dlc-version"
  rm -f "$c/.claude/.ai-dlc-applying"
}

bl_drive() { # bl_drive <apply-path> <consumer> [flag...]
  local a="$1" c="$2"; shift 2
  bash "$a" "$@" "$PD" "$BL_BASE" "$c" "$BL_THEIRS" 2>/dev/null
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
BL_PRESENT=1
if bl_run probe hit hit yes; then
  case "$BL_VEC" in
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
if bl_run both hit hit yes; then
  BL_BOTH="$BL_VEC"
  BL_CTL="$(bl_n "$BL_OUT" DECISION restamp-withheld)"
  if [ "$BL_BOTH" = "1|1|0|0" ]; then
    ok "BL-1 a consumer whose layer file reproduces the retired line AND whose artifact fence names the changed core path draws both WORKLIST rows (retired-layer-passage, artifact-derivations)"
  else
    bad "BL-1 the firing consumer drew row1|wl2|unreadable|unchecked = $BL_BOTH, not 1|1|0|0 — the classes BL-276 routes to the worklist are not reaching it"
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
if bl_run near miss miss yes; then
  if [ "$BL_VEC" = "0|0|0|0" ]; then
    ok "BL-2 a near-miss consumer — a PARAPHRASED layer line, and a fenced command naming an UNCHANGED core path while the changed one appears outside any fence — draws neither row"
  else
    bad "BL-2 the near-miss consumer drew $BL_VEC, not 0|0|0|0 — a row fired on a layer file that reproduces nothing core deleted, or on a fence this range does not touch (the unfenced line is the likely match)"
  fi
  if [ "$(bl_n "$BL_OUT" DECISION restamp-withheld)" -ge 1 ]; then
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
if bl_run nolayer none hit yes; then
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

# --- BL-4: THE ABSENT-VALIDATOR BRANCH IS A DECISION, AND IT IS GATED ON THE JOIN -------------
#
# TWO DIRECTIONS, AND THE SECOND ONE IS THE MEASURED FALSE POSITIVE. With real stranded
# citations and no `validate-artifact-derivations.sh` on the consumer, the run must SAY so --
# nothing can re-run those commands. But a consumer with no artifact corpus at all, or an empty
# one, must draw NOTHING from this site: keying the absent-branch on the TOOL rather than on the
# non-empty join fires on every consumer predating the mechanism, which is what failed C4 above
# and is the reason that arm's seed exists.
if bl_run noval hit hit no; then
  case "$BL_VEC" in
    "1|0|0|1") ok "BL-4 a consumer with stranded citations and no validate-artifact-derivations.sh draws DECISION artifact-derivations-unchecked instead of the WORKLIST row — nothing on that tree can re-run the commands, and the row says so" ;;
    *)         bad "BL-4 the validator-absent consumer drew $BL_VEC, not 1|0|0|1 — either the WORKLIST row was emitted naming a script that is not there, or the split reported nothing at all" ;;
  esac
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
    ok "BL-5 --finish over the very tree BL-1 fires both rows on emits NEITHER — the rows sit inside the FINISH=0 span, so the finisher never re-derives them"
  else
    bad "BL-5 --finish emitted $BL_VEC over a tree it cannot change: these rows raise worklist_n, which is the counter --finish gates its stamp on, and neither has work that clears in that mode. The consumer is wedged with .ai-dlc-applying on disk and pre-push refusing every push"
  fi
  if [ "$BL_FV" = "$BL_THEIRS_VER" ] && [ "$BL_FM" = GONE ] && [ "$BL_FR" -ge 1 ]; then
    ok "BL-5 and the finisher STAMPS — version $BL_FV, marker cleared, RESOLVED restamp — which is the exit the siting exists to preserve"
  else
    bad "BL-5 --finish did not stamp (version='${BL_FV:-<absent>}' expected $BL_THEIRS_VER, marker=$BL_FM, RESOLVED restamp=$BL_FR). A row this mode cannot clear withholds the stamp forever, and the applying marker keeps pre-push refusing"
  fi
else
  bad "BL-5 setup: could not build the finish consumer"
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

# --- BL-CTL: THE UNMUTATED COPY, WITH POSITIVE CONJUNCTS ON BOTH DIRECTIONS -------------------
# A control asserting only "nothing went wrong" passes against a subject replaced by `exit 0`.
# This one requires the firing world's two rows to be THERE and the near-miss world's to be
# absent, in the same copy, so a staging that cannot run reports as broken rather than as clean.
if printf '%s' "$(cat "$REC/apply.sh")" > /dev/null && mkdir -p "$BLROOT/mut-ctl" \
   && cp "$REC"/* "$BLROOT/mut-ctl/" 2>/dev/null && [ -s "$BLROOT/mut-ctl/setup-sites.md" ]; then
  BLC_P="$(bl_mut_vec "$BLROOT/mut-ctl" hit hit yes)"
  BLC_N="$(bl_mut_vec "$BLROOT/mut-ctl" miss miss yes)"
  if [ "$BLC_P" = "1|1|0|0" ] && [ "$BLC_N" = "0|0|0|0" ]; then
    ok "BL-CTL an unmutated copy of the reconcile directory reproduces BOTH directions (firing 1|1|0|0, near-miss 0|0|0|0), so a mutant's silence below is the mutation and not the copy"
  else
    bad "BL-CTL the unmutated copy did not reproduce the shipped behaviour (firing=$BLC_P near-miss=$BLC_N) — every BL mutant verdict below is unreadable"
  fi
else
  bad "BL-CTL could not stage a complete copy of $REC — every BL mutant verdict below is unreadable"
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
  case "$BLM1" in
    0\|1\|*) ok "BL-m1 (the whole passage block wrapped in a function nothing calls): BL-1 goes red — the row is lexically intact and unreachable, which is the first regression the filed receipt accepts" ;;
    1\|*)    bad "BL-m1 SURVIVED: the passage row was still emitted from inside an uncalled function ($BLM1), so BL-1 is not testing reachability" ;;
    *)       bad "BL-m1 produced a vector this fixture does not recognise ($BLM1) — it may have died for an unrelated reason, in which case BL-1's kill is unearned" ;;
  esac
  case "$BLM1" in
    *\|1\|0\|0) ok "BL-m1 and the derivation row is untouched by it — BL-1's two halves are not entangled" ;;
    *)          bad "BL-m1 also moved the derivation row ($BLM1): the passage and derivation arms are entangled and one of them proves nothing on its own" ;;
  esac
else
  bad "BL-m1 did not apply — apply.sh's passage block no longer opens with \`RLP_OUT=\"\$(bash \"\$SELF/retired-layer-passage.sh\"\` at column 0, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# --- BL-m2: the passage row under `if false` --------------------------------------------------
# The second receipt-passing regression. The detector is still invoked, the variable is still
# assigned from it, and the row is still lexically a `say WORKLIST` — only the condition is
# dead. This is the one a reachability conjunct keyed on the invocation cannot see.
if sed 's/^if \[ "\$RLP_N" -gt 0 \]; then$/if false; then/' "$REC/apply.sh" | bl_mut "$BLROOT/bl-m2"; then
  BLM2="$(bl_mut_vec "$BLROOT/bl-m2" hit hit yes)"
  case "$BLM2" in
    0\|1\|*) ok "BL-m2 (the passage row's condition replaced by \`if false\`): BL-1 goes red although the detector is still called and the row still reads as a say WORKLIST site" ;;
    1\|*)    bad "BL-m2 SURVIVED: the row was emitted with its guard dead ($BLM2), so BL-1 is not testing the condition" ;;
    *)       bad "BL-m2 produced a vector this fixture does not recognise ($BLM2)" ;;
  esac
  case "$BLM2" in
    *\|1\|0\|0) ok "BL-m2 and the derivation row is untouched by it" ;;
    *)          bad "BL-m2 also moved the derivation row ($BLM2): the two arms are entangled" ;;
  esac
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
  BLM3_P="$(bl_mut_vec "$BLROOT/bl-m3" hit hit yes)"
  BLM3_N="$(bl_mut_vec "$BLROOT/bl-m3" miss miss yes)"
  case "$BLM3_N" in
    1\|*) ok "BL-m3 (an unconditional row consulting no detector): BL-2 goes red — the near-miss consumer, which has no stale passage at all, is handed the row anyway" ;;
    0\|*) bad "BL-m3 SURVIVED: the near-miss consumer drew no passage row from an unconditional emitter ($BLM3_N), so BL-2 is not testing that the row is derived from the detector" ;;
    *)    bad "BL-m3 produced a vector this fixture does not recognise ($BLM3_N)" ;;
  esac
  case "$BLM3_P" in
    1\|1\|0\|0) ok "BL-m3 and BL-1 stays GREEN under it — an unconditional row does reach the firing consumer, which is exactly why BL-1 alone cannot catch this regression and BL-2 is not redundant" ;;
    *)          bad "BL-m3 also moved the firing world ($BLM3_P): BL-1 and BL-2 are entangled, and the near-miss kill above is not cleanly attributable" ;;
  esac
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
  BLM4_O="$(bl_mut_vec "$BLROOT/bl-m4" hit hit yes)"
  if [ -z "$BLM4_FC" ]; then
    bad "BL-m4 could not recover the consumer directory its finisher ran against, so the wedge conjunct below has no subject to read — this arm is unproven"
  elif [ "$BLM4_FV" = "1.0.0" ] && [ "$BLM4_FM" = PRESENT ]; then
    ok "BL-m4 and the wedge is observed on the TREE, not inferred from a row: the mutant's finisher left the stamp at 1.0.0 with .ai-dlc-applying still on disk, which is the state pre-push refuses every push over and which no further --finish can clear"
  else
    bad "BL-m4 the re-sited row did not withhold the finisher's stamp (version='${BLM4_FV:-<absent>}' marker=$BLM4_FM) — BL-5's second conjunct is then asserting a consequence this mutation does not produce, and the siting claim rests on the row count alone"
  fi
  case "$BLM4_F" in
    1\|*) ok "BL-m4 (the passage row re-sited beside the trailing rows, under --finish): BL-5 goes red — the finisher re-derives a row over a tree it never writes, raising worklist_n before write_stamp" ;;
    0\|*) bad "BL-m4 SURVIVED: --finish emitted no passage row with the block moved into its branch ($BLM4_F), so BL-5 is not testing the siting" ;;
    *)    bad "BL-m4 produced a vector this fixture does not recognise ($BLM4_F)" ;;
  esac
  case "$BLM4_O" in
    0\|1\|*) ok "BL-m4 and BL-1 goes red with it — the row left the ordinary path, which is the half a --finish-only fix gets wrong in the other direction" ;;
    *)       bad "BL-m4 left the ordinary-run row in place ($BLM4_O): the mutation did not move the block, so BL-5's kill above is not attributable to the siting" ;;
  esac
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
  BLM5_N="$(bl_mut_vec "$BLROOT/bl-m5" miss miss yes)"
  BLM5_P="$(bl_mut_vec "$BLROOT/bl-m5" hit hit yes)"
  case "$BLM5_N" in
    "0|0|0|0")
      bad "BL-m5 SURVIVED: the near-miss consumer drew nothing with the fence requirement removed ($BLM5_N), so BL-2's derivation half is not testing that the scan reads the FENCE — an unfenced command naming a changed core path would route work that no derivation records" ;;
    *)
      ok "BL-m5 (the relevance scan no longer requires the \`\`\`derived fence): BL-2 goes red — the near-miss consumer's unfenced quotation of the same command is matched, and a citation nothing recorded is routed to the validator" ;;
  esac
  case "$BLM5_P" in
    1\|*) ok "BL-m5 and the passage row is untouched by it — the derivation scan and the passage detector are separately gated" ;;
    *)    bad "BL-m5 also moved the passage row ($BLM5_P): the two sites are entangled" ;;
  esac
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
  BLM6_V="$(bl_mut_vec "$BLROOT/bl-m6" hit hit no)"
  BLM6_E="$(bl_mut_vec "$BLROOT/bl-m6" hit empty no)"
  case "$BLM6_V" in
    *\|1\|*) ok "BL-m6 (the WORKLIST branch stops asking whether the validator is present): BL-4's validator-absent half goes red — the consumer is handed a WORKLIST row naming a script that is not on its tree, and that row withholds its stamp" ;;
    *\|0\|0\|1) bad "BL-m6 SURVIVED: the validator-absent consumer still drew its unchecked DECISION ($BLM6_V), so BL-4 is not testing the branch — the split is being made somewhere this mutation does not reach" ;;
    *)       bad "BL-m6 produced a vector this fixture does not recognise ($BLM6_V)" ;;
  esac
  case "$BLM6_E" in
    "1|0|0|0") ok "BL-m6 and the empty-corpus world is untouched by it — that consumer never reaches the branch, so BL-4's two halves are not entangled" ;;
    *)         bad "BL-m6 also moved the empty-corpus world ($BLM6_E): BL-4's halves are entangled and one of them proves nothing on its own" ;;
  esac
else
  bad "BL-m6 did not apply — the derivation site's WORKLIST branch is no longer spelled \`elif [ \"\$VD_HITS\" -gt 0 ] && [ -f \"\$VD_VALIDATOR\" ]; then\`, so BL-4 is unproven against a row that names an absent validator"
fi

fi  # ---- end of the BL-S0 subject probe -------------------------------------------------------
fi  # ---- end of the BL-276 block ------------------------------------------------------------

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
# DRIVEN THROUGH `--finish`, ALWAYS. `hook_registration_row` is the same function in both modes;
# `--finish` skips the resolution phases, so a world costs one fork of apply.sh that reaches the
# row cheaply, and it is the mode where the row's COUNTER decides the stamp -- which is what (e)
# reads off the tree. The ordinary run calls the identical function after `write_stamp`.
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
#   (f) near-misses. A clean tree draws no hook-registration row and stamps. A tree whose
#       settings.local.json registers a LIVE hook (file present, so the validator lists it under
#       its NOTE, in the same bare shape as a DANGLING name) must not have that hook named in
#       either WORKLIST row -- the NOTE list is not a failure list.
#   (g) dangling, registered in BOTH settings.json and settings.local.json
#                                    -> named in the settings-merge row AND in a
#                                       `settings-local-dangling` row. The validator's NOTE list is
#                                       `local - main`, so the name is under DANGLING alone; the
#                                       merge clears settings.json and leaves the local block, so a
#                                       merge-only remedy leaves the validator at exit 1.
#
# MUTANTS: M-a (DANGLING parse removed), M-b (the dangling clause OVERWRITES the unregistered text
# instead of appending), M-c (local-only split removed), M-d (unparsed DECISION removed), M-g (the
# direct settings.local.json read ignored). R4 -- the "first non-4-space line ends the block" stop removed alone -- is NOT scored:
# against today's validator the NOTE header IS that first line, so the NOTE-mode switch covers
# the stop and the stop covers the switch; removing either alone changes no row. That is recorded
# in apply.sh beside the parse; a seed that separates them needs a validator section that does
# not exist yet.
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
  mk_consumer "$c" green || return 1
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
# hr_drive <apply.sh> <kind> -> prints the consumer dir; the rows land in <dir>/.hr-rows. A FILE,
# because every caller reads this through `$( )` and an assignment there is lost to the subshell.
hr_drive() {
  local c
  c="$(hr_world "$2")" || { printf 'BROKEN'; return; }
  bash "$1" --finish "$DIST" "$BASE" "$c" "$THEIRS" > "$c/.hr-rows" 2>/dev/null
  printf '%s' "$c"
}
hr_n()   { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {n++} END {print n+0}' "$1/.hr-rows" 2>/dev/null || echo 0; }
hr_det() { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {print $4; exit}' "$1/.hr-rows" 2>/dev/null; }
hr_sub() { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {print $3; exit}' "$1/.hr-rows" 2>/dev/null; }
# The DANGLING list the settings-merge row prints, verbatim, between its label and the dash.
hr_dlist() {
  awk -v s="$(hr_det "$1" WORKLIST settings-merge)" 'BEGIN {
    i = index(s, "(DANGLING): "); if (i == 0) { print "<none>"; exit }
    r = substr(s, i + 12); j = index(r, "\342\200\224 "); if (j == 0) { print "<unterminated>"; exit }
    print substr(r, 1, j - 1) }'
}
# The rows whose presence each arm keys on. Anything else in the manifest is someone else's arm.
hr_any() {
  echo $(( $(hr_n "$1" WORKLIST settings-merge) + $(hr_n "$1" WORKLIST settings-local-dangling) \
         + $(hr_n "$1" DECISION hook-registration-unparsed) + $(hr_n "$1" DECISION hook-registration-unreadable) \
         + $(hr_n "$1" DECISION hook-registration-unchecked) ))
}

hr_arm_a() { # dangling-only
  [ "$(hr_n "$1" WORKLIST settings-merge)" = 1 ] && [ "$(hr_dlist "$1")" = "ai-dlc-hra-beta.sh " ]
}
hr_arm_b() { # unregistered + dangling
  local d; d="$(hr_det "$1" WORKLIST settings-merge)"
  [ "$(hr_n "$1" WORKLIST settings-merge)" = 1 ] && [ "$(hr_dlist "$1")" = "ai-dlc-hra-beta.sh " ] \
    && case "$d" in *"UNREGISTERED after this apply: ai-dlc-hra-alpha.sh "*) true ;; *) false ;; esac
}
hr_arm_c() { # local-only dangling
  [ "$(hr_n "$1" WORKLIST settings-local-dangling)" = 1 ] \
    && [ "$(hr_sub "$1" WORKLIST settings-local-dangling)" = ".claude/settings.local.json" ] \
    && case "$(hr_det "$1" WORKLIST settings-local-dangling)" in *"(DANGLING): ai-dlc-hra-ghost.sh "*) true ;; *) false ;; esac \
    && [ "$(hr_n "$1" WORKLIST settings-merge)" = 0 ]
}
hr_arm_d() { # settings.json is []
  [ "$(hr_n "$1" DECISION hook-registration-unparsed)" = 1 ] && [ "$(hr_n "$1" WORKLIST settings-merge)" = 0 ]
}
hr_arm_e() { # --finish over the dangling-only tree withholds, read off the TREE
  [ "$(stamp_ver "$1")" = "1.0.0" ] && [ "$(marker "$1")" = PRESENT ] && [ "$(hr_n "$1" DECISION restamp-withheld)" -ge 1 ]
}
hr_arm_f() { # <clean-dir> <livelocal-dir>
  local d m l
  [ "$(hr_any "$1")" = 0 ] && [ "$(stamp_ver "$1")" = "$THEIRS_VER" ] || return 1
  # POSITIVE CONJUNCT: some hook-registration row exists, so the absence below is about a run
  # that reached the row and not about one that emitted nothing.
  [ "$(hr_any "$2")" -ge 1 ] || return 1
  m="$(hr_det "$2" WORKLIST settings-merge)"; l="$(hr_det "$2" WORKLIST settings-local-dangling)"
  case "$m$l" in *ai-dlc-hra-alpha.sh*) return 1 ;; esac
  return 0
}
hr_arm_g() { # dangling in BOTH files -> both rows name it
  [ "$(hr_n "$1" WORKLIST settings-merge)" = 1 ] && [ "$(hr_dlist "$1")" = "ai-dlc-hra-beta.sh " ] \
    && [ "$(hr_n "$1" WORKLIST settings-local-dangling)" = 1 ] \
    && [ "$(hr_sub "$1" WORKLIST settings-local-dangling)" = ".claude/settings.local.json" ] \
    && case "$(hr_det "$1" WORKLIST settings-local-dangling)" in *"(DANGLING): ai-dlc-hra-beta.sh "*) true ;; *) false ;; esac
}
# hr_vec <apply.sh> -> "a b c d e f g" as 1 (holds) / 0 (fails). All seven worlds are driven for
# every subject, so a mutant is scored on every arm and a two-arm kill cannot hide.
hr_vec() {
  local A="$1" cd cb cl ce cc cv cg v=""
  cd="$(hr_drive "$A" dangling)"; cb="$(hr_drive "$A" both)"; cl="$(hr_drive "$A" localdg)"
  ce="$(hr_drive "$A" emptyarr)"; cc="$(hr_drive "$A" clean)"; cv="$(hr_drive "$A" livelocal)"
  cg="$(hr_drive "$A" bothfiles)"
  for x in "$cd" "$cb" "$cl" "$ce" "$cc" "$cv" "$cg"; do [ -d "$x" ] || { printf 'BROKEN'; return; }; done
  hr_arm_a "$cd" && v="${v}1" || v="${v}0"
  hr_arm_b "$cb" && v="$v 1" || v="$v 0"
  hr_arm_c "$cl" && v="$v 1" || v="$v 0"
  hr_arm_d "$ce" && v="$v 1" || v="$v 0"
  hr_arm_e "$cd" && v="$v 1" || v="$v 0"
  hr_arm_f "$cc" "$cv" && v="$v 1" || v="$v 0"
  hr_arm_g "$cg" && v="$v 1" || v="$v 0"
  printf '%s' "$v"
}

if [ -n "$HR_SKIP" ]; then
  if [ "$IS_DIST" = 1 ]; then
    bad "HR setup: $HR_SKIP — HARD in the distribution, every BL-292 arm would be unreadable"
  else
    printf '  SKIP  %s\n' "HR-a..HR-f and HR-M-a/c/d — $HR_SKIP"
  fi
else
# --- HR-S0 SUBJECT PROBE: the pre-fix program is SILENT on a dangling-only tree ----------------
# That silence is the defect, so it is also the probe: an apply.sh with no hook-registration row
# of any kind over this tree predates BL-292. A consumer can receive this fixture a pull ahead of
# the apply.sh it tests; in the DISTRIBUTION the subject is always present, so absence is hard.
HR_PROBE="$(hr_drive "$APPLY" dangling)"
HR_PRESENT=1
if [ ! -d "$HR_PROBE" ]; then
  bad "HR-S0 setup: could not build the dangling-only consumer"; HR_PRESENT=0
elif [ "$(bash "$HR_PROBE/scripts/ai-dlc/validate-hook-registration.sh" --root "$HR_PROBE" >/dev/null 2>&1; echo $?)" != 1 ]; then
  bad "HR-S0 setup: the real validator does not exit 1 on the dangling-only world, so no arm below is scoring the shape BL-292 is about"; HR_PRESENT=0
elif [ "$(hr_any "$HR_PROBE")" = 0 ]; then
  HR_PRESENT=0
  if [ "$IS_DIST" = 1 ]; then
    bad "HR-S0 the resolved apply.sh ($APPLY) emitted NO hook-registration row over a tree whose validator exits 1 on a dangling registration — the BL-292 parse is absent. HARD in the distribution."
  else
    printf '  SKIP  %s\n' "HR-a..HR-f — the installed apply.sh predates the BL-292 DANGLING parse; it lands with a later pull than this fixture"
  fi
else
  ok "HR-S0 the real validator exits 1 on the dangling-only world and the resolved apply.sh answers it with a hook-registration row, so the arms below score a subject that is present"
fi

if [ "$HR_PRESENT" = 1 ]; then
HR_D="$HR_PROBE"
HR_B="$(hr_drive "$APPLY" both)"; HR_L="$(hr_drive "$APPLY" localdg)"; HR_E="$(hr_drive "$APPLY" emptyarr)"
HR_C="$(hr_drive "$APPLY" clean)"; HR_V="$(hr_drive "$APPLY" livelocal)"; HR_G="$(hr_drive "$APPLY" bothfiles)"

if hr_arm_a "$HR_D"; then
  ok "HR-a a dangling-only tree draws ONE WORKLIST settings-merge row whose DANGLING list is exactly ai-dlc-hra-beta.sh — and not the validator's FIX line that follows the list at the same indent"
else
  bad "HR-a the dangling-only tree drew settings-merge=$(hr_n "$HR_D" WORKLIST settings-merge) with DANGLING list '$(hr_dlist "$HR_D")', not one row listing exactly 'ai-dlc-hra-beta.sh ' — a registration Claude Code cannot run is not reaching the worklist (other rows: unparsed=$(hr_n "$HR_D" DECISION hook-registration-unparsed))"
fi
if hr_arm_b "$HR_B"; then
  ok "HR-b an unregistered hook AND a dangling one share the ONE settings-merge row, and it names both (alpha UNREGISTERED, beta DANGLING) — one merge clears both"
else
  bad "HR-b the unregistered+dangling tree drew settings-merge=$(hr_n "$HR_B" WORKLIST settings-merge), DANGLING list '$(hr_dlist "$HR_B")' — the row does not name both hooks"
fi
if hr_arm_c "$HR_L"; then
  ok "HR-c a dangling hook registered ONLY in settings.local.json draws WORKLIST settings-local-dangling on .claude/settings.local.json naming ai-dlc-hra-ghost.sh, and NO settings-merge row — that merge never touches the file"
else
  bad "HR-c the local-only dangling tree drew settings-local-dangling=$(hr_n "$HR_L" WORKLIST settings-local-dangling) (subject '$(hr_sub "$HR_L" WORKLIST settings-local-dangling)') and settings-merge=$(hr_n "$HR_L" WORKLIST settings-merge) — the operator is handed a remedy that cannot clear it, or none"
fi
if hr_arm_d "$HR_E"; then
  ok "HR-d a settings.json holding [] draws DECISION hook-registration-unparsed — a non-zero exit that named nothing is not read as clean"
else
  bad "HR-d the [] tree drew unparsed=$(hr_n "$HR_E" DECISION hook-registration-unparsed), settings-merge=$(hr_n "$HR_E" WORKLIST settings-merge) — the validator failed without a list and the row said nothing"
fi
if [ "$(stamp_ver "$HR_E")" = "$THEIRS_VER" ] && [ "$(marker "$HR_E")" = GONE ]; then
  ok "HR-d and --finish still stamps over that DECISION — it raises handback, not worklist_n, so a missing interpreter cannot wedge the finisher"
else
  bad "HR-d --finish withheld over DECISION hook-registration-unparsed (stamp '$(stamp_ver "$HR_E")', marker $(marker "$HR_E")) — the C8 wedge, reached through the new row"
fi
if hr_arm_e "$HR_D"; then
  ok "HR-e --finish over the dangling-only tree WITHHOLDS on the tree: version 1.0.0, .ai-dlc-applying present, DECISION restamp-withheld"
else
  bad "HR-e --finish over a dangling registration stamped (version '$(stamp_ver "$HR_D")', marker $(marker "$HR_D")) — the invocation meant to verify the finished tree passed a hook Claude Code cannot run"
fi
if hr_arm_f "$HR_C" "$HR_V"; then
  ok "HR-f near-misses: a clean tree draws no hook-registration row and stamps $THEIRS_VER; a LIVE hook listed under the validator's settings.local.json NOTE is named in neither WORKLIST row, while that tree's real dangling hook still draws one"
else
  bad "HR-f a near-miss fired: clean rows=$(hr_any "$HR_C") stamp='$(stamp_ver "$HR_C")'; live-local tree rows=$(hr_any "$HR_V"), settings-merge detail names alpha: $(case "$(hr_det "$HR_V" WORKLIST settings-merge)$(hr_det "$HR_V" WORKLIST settings-local-dangling)" in *ai-dlc-hra-alpha.sh*) echo yes ;; *) echo no ;; esac)"
fi
if hr_arm_g "$HR_G"; then
  ok "HR-g a dangling hook registered in BOTH settings.json and settings.local.json is named in the settings-merge row AND in a settings-local-dangling row on .claude/settings.local.json — the merge alone leaves the local block and the validator at exit 1"
else
  bad "HR-g the both-files tree drew settings-merge=$(hr_n "$HR_G" WORKLIST settings-merge) (DANGLING list '$(hr_dlist "$HR_G")') and settings-local-dangling=$(hr_n "$HR_G" WORKLIST settings-local-dangling) — the validator's NOTE list excludes a name also in settings.json, so the operator is sent round twice"
fi

# --- HR MUTANTS -------------------------------------------------------------------------------
# Copies of the whole reconcile directory (`mut_apply`), `cmp -s`-guarded, each anchor asserted
# UNIQUE before the edit so a respelled anchor reports DID NOT APPLY rather than a silent no-op.
HR_WANT_CTL="1 1 1 1 1 1 1"
hr_mut() { # hr_mut <dir> <anchor-literal> ; transform on stdin
  local n; n="$(grep -cF -- "$2" "$REC/apply.sh")" || n=0
  [ "$n" = 1 ] || { cat >/dev/null; return 1; }
  mut_apply "$1"
}
if build_rec "$WORK/hr-ctl"; then
  HRC_U="$(hr_drive "$WORK/hr-ctl/apply.sh" unreg)"
  HRC_V="$(hr_vec "$WORK/hr-ctl/apply.sh")"
  case "$(hr_det "$HRC_U" WORKLIST settings-merge)" in
    *"UNREGISTERED after this apply: ai-dlc-hra-alpha.sh "*) HRC_UOK=1 ;;
    *) HRC_UOK=0 ;;
  esac
  if [ "$HRC_UOK" = 1 ] && [ "$HRC_V" = "$HR_WANT_CTL" ]; then
    ok "HR-CTL an unmutated copy emits the UNREGISTERED settings-merge row naming ai-dlc-hra-alpha.sh and scores every arm ($HRC_V), so a mutant's vector below is the mutation and not the copy"
  else
    bad "HR-CTL the unmutated copy did not reproduce the shipped behaviour (unregistered row=$HRC_UOK, vector='$HRC_V', want '$HR_WANT_CTL') — every HR mutant verdict below is unreadable"
  fi
else
  bad "HR-CTL could not stage a copy of $REC — every HR mutant verdict below is unreadable"
fi

# hr_score <label> <dir> <want-vector> <what it removed>
hr_score() {
  local v; v="$(hr_vec "$2/apply.sh")"
  if [ "$v" = "$3" ]; then
    ok "$1 ($4): arm vector a..g = $v — killed exactly the arms it owns"
  elif [ "$v" = "$HR_WANT_CTL" ]; then
    bad "$1 SURVIVED ($4): every arm still holds ($v), so the arms it should kill are not testing that line"
  else
    bad "$1 ($4) scored $v, want $3 — it killed an arm it should not, or missed one it should, so the arms are entangled or one is vacuous"
  fi
}

# M-a: the DANGLING parse removed. The D list is also the ONLY source of a local-only dangling
# name (the split intersects it with the NOTE list), so (c) dies with (a)/(b)/(e) by construction:
# there is no DANGLING-less input on which (c) could hold. A dangling-only tree then exits 1 with
# nothing parsed, which the new rc!=0 branch reports as unparsed -- so (d) and (f) stay green,
# and (g) dies with the rest: its name reaches the function only through the D list.
HR_MA='    index($0, "  DANGLING ") == 1 { m = "D"; next }'
if awk -v a="$HR_MA" '$0 == a { next } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-ma" "$HR_MA"; then
  hr_score "HR-M-a" "$WORK/hr-ma" "0 0 0 1 0 1 0" "the DANGLING block parse deleted"
else
  bad "HR-M-a DID NOT APPLY — the DANGLING parse line is no longer spelled \`$HR_MA\` exactly once in apply.sh; HR-a/b/e are unproven. Re-anchor it."
fi

# M-c: the local-only split removed -- the case subject is emptied, so no name ever matches the
# NOTE list and every dangling name lands on the settings-merge row that cannot clear it. (The
# direct settings.local.json read still adds a local row, so (c) dies on the extra merge row.)
HR_MC='    case "$hr_local" in'
if awk -v a="$HR_MC" '$0 == a { print "    case \"\" in"; next } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-mc" "$HR_MC"; then
  hr_score "HR-M-c" "$WORK/hr-mc" "1 1 0 1 1 1 1" "the settings.local.json split deleted; local names go to settings-merge"
else
  bad "HR-M-c DID NOT APPLY — \`$HR_MC\` is not in apply.sh exactly once; HR-c is unproven. Re-anchor it."
fi

# M-d: the unparsed DECISION removed -- its branch made unreachable, leaving rc!=0-with-no-names
# silent exactly as before the fix.
HR_MD='  elif [ "$hr_rc" != "0" ]; then'
if awk -v a="$HR_MD" '$0 == a { print "  elif false; then"; next } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-md" "$HR_MD"; then
  hr_score "HR-M-d" "$WORK/hr-md" "1 1 1 0 1 1 1" "the hook-registration-unparsed branch made unreachable"
else
  bad "HR-M-d DID NOT APPLY — \`$HR_MD\` is not in apply.sh exactly once; HR-d is unproven. Re-anchor it."
fi

# M-b: the dangling clause OVERWRITES hr_what instead of appending, so a tree with an unregistered
# AND a dangling hook loses the unregistered name. Only (b) seeds both at once.
HR_MB='    [ -n "$hr_dangle" ] && hr_what="${hr_what}hook(s) REGISTERED'
if awk -v a="$HR_MB" 'index($0, a) == 1 { sub(/hr_what="\$\{hr_what\}hook/, "hr_what=\"hook") } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-mb" "$HR_MB"; then
  hr_score "HR-M-b" "$WORK/hr-mb" "1 0 1 1 1 1 1" "the dangling clause overwrites the unregistered text"
else
  bad "HR-M-b DID NOT APPLY — \`$HR_MB\` is not in apply.sh exactly once; HR-b's mixed row is unproven. Re-anchor it."
fi

# M-g: the direct settings.local.json read ignored -- a name in both files goes to the merge only.
HR_MG='                    case "$hr_inlocal" in'
if awk -v a="$HR_MG" 'index($0, a) == 1 { sub(/case "\$hr_inlocal" in/, "case \"\" in") } { print }' "$REC/apply.sh" | hr_mut "$WORK/hr-mg" "$HR_MG"; then
  hr_score "HR-M-g" "$WORK/hr-mg" "1 1 1 1 1 1 0" "the direct settings.local.json read ignored"
else
  bad "HR-M-g DID NOT APPLY — \`$HR_MG\` is not in apply.sh exactly once; HR-g is unproven. Re-anchor it."
fi
fi  # ---- end of HR_PRESENT
fi  # ---- end of the BL-292 block

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
echo "apply-restamp-worklist: FAIL ($fails)"
exit 1
