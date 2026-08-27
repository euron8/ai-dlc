#!/usr/bin/env bash
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
# HOW IT DRIVES THE REAL SCRIPT. Nothing is stubbed. Two throwaway git repos and four consumer
# trees produce the three input shapes out of preclassify's own vocabulary:
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

echo "apply-restamp-worklist:"

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

# The operator's checkout is on something else entirely. Live condition, and the reason
# `apply-restamp-theirs` exists: the working tree says 9.9.9 while the pull brings 2.0.0.
printf '9.9.9\n' > "$DIST/VERSION"

DRIVER_REL=".claude/session-driver/ai-dlc-session-driver.sh"

mk_consumer() { # mk_consumer <dir> <green|worklist|decision>
  local c="$1" mode="$2"
  mkdir -p "$c/.claude/session-driver" "$c/tests/fixtures/synthetic-fx" "$c/scripts/ai-dlc" || return 1
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
stamp_ver()  { sed -n 's/^version:[[:space:]]*//p' "$1/.claude/.ai-dlc-version" 2>/dev/null | head -1; }
stamp_sha()  { sed -n 's/^commit:[[:space:]]*//p'  "$1/.claude/.ai-dlc-version" 2>/dev/null | head -1; }
marker()     { [ -f "$1/.claude/.ai-dlc-applying" ] && echo PRESENT || echo GONE; }
has_row()    { printf '%s\n' "$1" | awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {n++} END {exit !(n>0)}'; }
detail_of()  { printf '%s\n' "$1" | awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b && NF>=4 {print $4; exit}'; }

# ROWS EMITTED BEFORE THE GUARD IS READ. `handback` is a running counter, so what gates the
# stamp is the rows printed UP TO the re-stamp verdict, not the whole manifest. That distinction
# is load-bearing: apply.sh emits `DECISION hook-registration-unchecked` unconditionally after
# the re-stamp on any consumer lacking scripts/ai-dlc/validate-hook-registration.sh — measured on
# all four trees here, the clean one included. A counter read at exit instead of at the guard
# would withhold the stamp on EVERY correct pull and wedge every consumer. S1 is what separates
# the two readings.
pre_guard() {
  printf '%s\n' "$1" | awk -F'\t' '
    $1=="RESOLVED" && ($2=="restamp" || $2=="restamp-machinery") { exit }
    $1=="DECISION" && $2 ~ /^(restamp-withheld|restamp-failed|skill-restamp-withheld|skill-restamp-failed)$/ { exit }
    { print }'
}
n_handback() { pre_guard "$1" | awk -F'\t' '$1=="WORKLIST" || $1=="DECISION" {n++} END {print n+0}'; }

# --- SUBJECT PROBE: is the change installed at all? -------------------------------------------
# The guard fix and `--finish` land together, so one probe covers both halves. `--finish` with no
# positionals reaches the option parser and nothing else, so this costs a fork and writes nothing.
PROBE="$(bash "$APPLY" --finish 2>&1)"
if printf '%s\n' "$PROBE" | grep -q -- 'unknown option: --finish'; then
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
mk_consumer "$C_FIN" green || { echo "FIXTURE BROKEN — could not build the finish consumer" >&2; exit 2; }
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
if [ -n "$PREPUSH" ] && grep -q 'ai-dlc-applying' "$PREPUSH"; then
  ok "C6 premise: $PREPUSH still refuses while the marker exists, so a row with no escape really does wedge the tree"
else
  bad "C6 premise: no pre-push carrying the marker refusal was resolved (looked for core/git-hooks/pre-push and .githooks/pre-push). C6 asserts an escape from a refusal this fixture can no longer see, so its severity is unverified"
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

# --- MUTANTS ----------------------------------------------------------------------------------
# Each is a COPY of the whole reconcile directory — apply.sh `eval`s map_consumer() out of its
# sibling preclassify.sh and shells to retired-tokens.sh and unregistered-drift.sh, so a lone
# script copy dies before printing anything — guarded by `cmp -s` so an edit that matched nothing
# cannot pass as a mutation, and aimed at ONE arm.
build_rec() { # build_rec <dir>
  mkdir -p "$1" && cp "$REC"/* "$1"/ 2>/dev/null && [ -f "$1/apply.sh" ]
}
# Every mutant verdict is PRESENCE-shaped: a mutant that emits nothing must not score as a kill.
mut_stamp()  { # mut_stamp <rec-dir> <mode> [flag...] -> "<ver>|<marker>|<withheld?>|<driverUPSTREAM?>"
  local rec="$1" mode="$2"; shift 2
  local c="$WORK/m-$$-$RANDOM"
  mk_consumer "$c" "$mode" || { echo "BROKEN|||"; return; }
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
  CTL_W="$(mut_stamp "$WORK/mut-ctl" worklist)"
  CTL_G="$(mut_stamp "$WORK/mut-ctl" green)"
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
  M1="$(mut_stamp "$WORK/m1" worklist)"
  case "$M1" in
    "$THEIRS_VER|GONE|"*) ok "m1 (guard on mech_fail alone): C1 goes red — the WORKLIST run stamps $THEIRS_VER and clears the marker, which is the shipped defect" ;;
    "1.0.0|PRESENT|"*)    bad "m1 SURVIVED: the stamp was still withheld with the guard reading mech_fail only, so C1 is not testing the handback term ($M1)" ;;
    *)                    bad "m1 produced a verdict this fixture does not recognise ($M1) — it may have died for an unrelated reason, in which case C1's kill is unearned" ;;
  esac
  M1G="$(mut_stamp "$WORK/m1" green)"
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
  M2="$(mut_stamp "$WORK/m2" worklist)"
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
  M3D="$(mut_stamp "$WORK/m3" decision)"
  case "$M3D" in
    "$THEIRS_VER|GONE|"*) ok "m3 (handback counts WORKLIST only): C7 goes red — a gated deletion is outstanding work and it stamps anyway" ;;
    "1.0.0|"*)            bad "m3 SURVIVED: the DECISION-only run was still withheld with DECISION renamed inside say(), so C7 is not testing the DECISION half ($M3D)" ;;
    *)                    bad "m3 produced an unrecognised verdict ($M3D) — its kill would be unearned" ;;
  esac
  M3W="$(mut_stamp "$WORK/m3" worklist)"
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

# --- m5: the guard compares `-lt 0`. Must die on C1. -------------------------------------------
# A distinct mutation from m1 with the same target: m1 removes the term, this one keeps it and
# makes it unsatisfiable. A guard that is present and can never be true reads, in a diff, exactly
# like one that works.
if sed 's/"$handback" -gt 0/"$handback" -lt 0/' "$REC/apply.sh" | mut_apply "$WORK/m5"; then
  M5="$(mut_stamp "$WORK/m5" worklist)"
  case "$M5" in
    "$THEIRS_VER|GONE|"*) ok "m5 (handback compared -lt 0): C1 goes red — the term is present and unsatisfiable, which no diff distinguishes from a working guard" ;;
    "1.0.0|PRESENT|"*)    bad "m5 SURVIVED: the stamp was withheld with a term that can never be true, so something other than handback is withholding it ($M5)" ;;
    *)                    bad "m5 produced an unrecognised verdict ($M5)" ;;
  esac
else
  bad "m5 did not apply — the guard does not compare \`\"\$handback\" -gt 0\`, so this mutant proves nothing. Re-anchor it on the current spelling."
fi

# --- m6: over-broad — `--finish` withholds too. Must die on C4. --------------------------------
# The failure an over-cautious fix produces: every mode withholds, the marker never clears, and
# the consumer cannot push at all. Anchored on the flag variable, so it is skipped rather than
# guessed if the implementation names it something else.
if grep -q '^FINISH=0' "$REC/apply.sh"; then
  if sed 's/^\(if \[ "$mech_fail" -gt 0 \].*\); then$/\1 || [ "$FINISH" = 1 ]; then/' "$REC/apply.sh" \
     | mut_apply "$WORK/m6"; then
    M6="$(mut_stamp "$WORK/m6" green --finish)"
    case "$M6" in
      "1.0.0|"*)            ok "m6 (--finish withholds too): C4 goes red — the only exit from a withheld stamp is itself withheld and the tree can never push again" ;;
      "$THEIRS_VER|GONE|"*) bad "m6 SURVIVED: --finish still stamped with the guard extended to cover it, so C4 is not reading the stamp this mode writes ($M6)" ;;
      *)                    bad "m6 produced an unrecognised verdict ($M6)" ;;
    esac
    M6G="$(mut_stamp "$WORK/m6" green)"
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
  M7="$(mut_stamp "$WORK/m7" green --finish)"
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

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  apply-restamp-worklist: a run that hands back a WORKLIST or a DECISION row leaves"
  echo "      .ai-dlc-version at base and .ai-dlc-applying on disk, says so as DECISION"
  echo "      restamp-withheld rather than RESOLVED restamp, and names --finish so the operator"
  echo "      can stamp once the work is disposed; --finish stamps from theirs and runs no"
  echo "      resolution phase; and a pull with nothing outstanding still stamps as it did."
  exit 0
fi
echo "apply-restamp-worklist: FAIL ($fails)"
exit 1
