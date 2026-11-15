#!/usr/bin/env bash
# backlog-real-ledger -- the two joins and the one label probe whose verdict depends on the CONTENT
# of a real-sized ledger, run over a FROZEN SNAPSHOT of this repository's docs/backlog.md.
#
#   j1   the receipts validator's `sh` population covers the shipping classifier's resolved set
#        on the snapshot (scripts/validate-backlog-receipts.sh vs scripts/backlog-reverify.sh)
#   b16  the size ceiling's entry count equals the classifier's on the snapshot
#        (scripts/validate-backlog-size.sh vs scripts/backlog-reverify.sh)
#
# THE LEDGER IS ledger.snapshot BESIDE THIS FILE, NOT docs/backlog.md (BL-872). Keyed on the live
# ledger, this unit's invocations.decl counted validator STARTS over that content, so every backlog
# edit re-keyed it or turned it red. The snapshot was copied byte-identical from docs/backlog.md at
# the BL-872 base, and it is refreshed only when one of the three subjects changes shape enough to
# need a newer real corpus; the count then moves with it, in that change. It is not named `.md` so
# that no markdown scanner reads its frozen citations as live ones.
#
# WHAT THE SNAPSHOT MAKES VACUOUS, AND WHERE THAT MOVED. Over a frozen file j1 and b16 can no longer
# see LIVE drift -- a receipt or an entry shape filed after the snapshot. That half runs as arm R9
# of scripts/validate-backlog-receipts.sh in the `.githooks/pre-push` step "backlog receipts" (a
# keyed step whose key holds the ledger; AI_DLC_PRESUITE_SKIP=1 skips it), against the live ledger,
# through the same two readers and the same comparison. What
# stays here is the half a frozen corpus still answers: the three programs, as CHANGED, still agree
# on a real-sized ledger.
# The anchor-collision guard on BL-899 below is now a constant against the snapshot (max id BL-883);
# it can fire only when the snapshot is refreshed past it.
#
# j1's --base IS j1's OWN COMMIT (BL-899, lead ruling A, accepted by the lead). The seeded repository has no
# origin/main, and the snapshot's two open driver receipts (BL-868, BL-878) name scripts the seed does not carry;
# at j1's own commit those drivers are absent at HEAD and at the base, so M1 counts them EXCLUDED and j1-m1x
# asserts the VALUE `M1-EXCLUDED: 2`. Not the root commit: a root base would make every LANDED entry of the
# snapshot an R8 close of this branch and run its receipt.
#
# Usage: run.sh
# Exit:  0 = both arms hold, 1 = one regressed, 2 = fixture broken.
set -u

# CLEAR EVERY AMBIENT AI_DLC_* KEY (I87): b16 passes its ceiling as a double-quoted `env` word,
# which is not an assignment for the probes that do not set it.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# SCRUB THE REPOSITORY ENVIRONMENT: j1 runs `git init` in mktemp trees, and an inherited GIT_DIR
# makes `git init` succeed without creating a repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
# The receipts validator's re-entry sentinel: inherited, every run below would score nothing.
unset BR_RECEIPTS_RUNNING

DIR="$(cd "$(dirname "$0")" && pwd)"
find_one() { # find_one <relative path>... -> the first candidate that is a file, both layouts
  local c
  for c in "$@"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done
  return 1
}
RECEIPTS="$(find_one "$DIR/../../scripts/validate-backlog-receipts.sh" "$DIR/../../../scripts/validate-backlog-receipts.sh")" || RECEIPTS=""
SIZE="$(find_one "$DIR/../../scripts/validate-backlog-size.sh" "$DIR/../../../scripts/validate-backlog-size.sh")" || SIZE=""
REVERIFY="$(find_one "$DIR/../../scripts/backlog-reverify.sh" "$DIR/../../../scripts/backlog-reverify.sh")" || REVERIFY=""
LIBSRC="$(find_one "$DIR/../../skills/ai-dlc-update/reconcile/lib.sh" "$DIR/../../../core/skills/ai-dlc-update/reconcile/lib.sh")" || LIBSRC=""
REVSRC="$(find_one "$DIR/../../skills/ai-dlc-update/reconcile/ledger-reverify.sh" "$DIR/../../../core/skills/ai-dlc-update/reconcile/ledger-reverify.sh")" || REVSRC=""
# The could-not-measure rule both the classifier and the receipts validator source from beside them.
RLIB="$(find_one "$DIR/../../scripts/backlog-receipt-lib.sh" "$DIR/../../../scripts/backlog-receipt-lib.sh")" || RLIB=""
# The frozen ledger (BL-872); see the header. REAL_LEDGER keeps its name: it is a real ledger, frozen.
REAL_LEDGER=""
[ -f "$DIR/ledger.snapshot" ] && REAL_LEDGER="$DIR/ledger.snapshot"
for _p in RECEIPTS SIZE REVERIFY LIBSRC REVSRC RLIB REAL_LEDGER; do
  eval "_v=\${$_p}"
  [ -n "$_v" ] || { echo "FIXTURE BROKEN: backlog-real-ledger could not resolve $_p" >&2; exit 2; }
done
echo "HERMETIC-CONSUMED scripts/validate-backlog-receipts.sh"
echo "HERMETIC-CONSUMED scripts/validate-backlog-size.sh"
echo "HERMETIC-CONSUMED scripts/backlog-reverify.sh"

TMP="$(mktemp -d)"
cleanup() {
  for _r in "$TMP"/*; do
    [ -d "$_r/.git" ] && git -C "$_r" worktree prune >/dev/null 2>&1
  done
  rm -rf "$TMP"
}
trap cleanup EXIT
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

# --- j1's seed: a throwaway REPOSITORY, because the receipts validator checks each receipt out of
# HEAD. It carries the validator, both reconcile files it loads, the classifier (R2's declared-empty
# exemption asks it), and the two probe files the self-probe and the anchor name.
seed_r() { # seed_r <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile" "$d/probe"
  echo "0.0.0" > "$d/VERSION"
  cp "$RECEIPTS" "$d/scripts/validate-backlog-receipts.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$REVSRC" "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
  cp "$REVERIFY" "$d/scripts/backlog-reverify.sh"
  # The receipts validator reads its F-STEP vocabulary from the extractor and the step basenames.
  mkdir -p "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts" "$d/core/skills/ai-dlc/steps"
  # A seeded extractor: the validator reads only these two lines of it, and the step set is the one step file
  # seeded below, so the live extractor's content cannot move a verdict.
  printf '%s\n' 'STEP_RE = re.compile(r"skills/ai-dlc(?:-update)?/steps/([A-Za-z0-9_.-]+)\.md")' \
    'SUBPROC = {"_gate-procedures", "_dispatch-protocol"}' \
    > "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"
  # A seeded roll.py: the validator reads only its GROUPS list, the rows whose step set is None being
  # the Verdict/Step grammar's bucket tokens (b255 F2b); without one it refuses with exit 2.
  printf '%s\n' 'GROUPS = [' "    ('one step', 'pipeline', {'implementation'})," \
    "    ('the whole pipeline bucket', 'pipeline', None)," ']' \
    > "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py"
  : > "$d/core/skills/ai-dlc/steps/implementation.md"
  cp "$RLIB" "$d/scripts/backlog-receipt-lib.sh"
  printf 'alpha\nbeta\n' > "$d/probe/subject.txt"
  printf 'delta\n' > "$d/probe/guarded.txt"
  printf '# Probe backlog\n' > "$d/docs/backlog.md"
  (
    cd "$d" && git init -q . >/dev/null 2>&1 \
      && git add -A >/dev/null 2>&1 \
      && git -c user.email=p@local -c user.name=p commit -q -m seed >/dev/null 2>&1
  )
  [ -d "$d/.git" ] || { echo "FIXTURE BROKEN: the probe repository at $d has no .git" >&2; exit 2; }
}
# shellcheck disable=SC2086
run_r() { # run_r <env-string-or-empty> <dir> [<extra-args>...]
  local e="$1" d="$2"; shift 2
  ( cd "$d" && env $e bash scripts/validate-backlog-receipts.sh "$@" 2>&1 )
}

# --- b16's seed: a plain tree with the ceiling validator, its library and the classifier.
seed_s() { # seed_s <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile"
  echo "0.0.0" > "$d/VERSION"
  cp "$SIZE" "$d/scripts/validate-backlog-size.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$REVERIFY" "$d/scripts/backlog-reverify.sh"
  cp "$RLIB" "$d/scripts/backlog-receipt-lib.sh"
}
# shellcheck disable=SC2086
run_s() { # run_s <env-string-or-empty> <dir> [<extra-args>...]
  local e="$1" d="$2"; shift 2
  ( cd "$d" && env $e bash scripts/validate-backlog-size.sh "$@" 2>&1 )
}
# Reads the count back out of the ceiling's OWN ok line; empty when the arm did not speak.
bl_reported() { printf '%s\n' "$1" | sed -n 's|^OK: validate-backlog-size -- B1 \([0-9][0-9]*\)/[0-9]* entries in .*|\1|p'; }

# ===== j1: THE POPULATION JOIN. ===========================================================
# Bind the receipts validator's `sh` population to the SHIPPING classifier's view of the same
# ledger, at fixture time rather than on the gate's hot path. NO NUMBER IS HARDCODED: a literal
# would go stale on the next filed entry, and equality alone is satisfied by two broken
# predicates that both return 0, so both sides are asserted non-zero as well.
# R2 REFUSES BEFORE THE SUMMARY when this tree can score none of the real ledger's receipts, and
# that is a property of THIS tree, not of the ledger: it carries only the validator, lib.sh and
# ledger-reverify.sh, so most real receipts exit 9 or 0 here, and a correct fix closing the last
# one it could bind empties the scored set. Reading the population out of R2's refusal instead
# kept j1 green there, and cost j1 its second job: a validator that scored NOTHING read the same.
# So the j1 ledger carries one ANCHOR receipt, appended LAST and keyed on a seed file every
# seed tree holds, which this tree always scores (a literal grep: PROSE-CLOSABLE). The SUMMARY
# is then always printed, the population is read from it alone, and `scored=` must be non-zero.
# The anchor is one more sh receipt on BOTH sides of the join, so the comparison is unmoved.
J1_ANCHOR='BL-899'
J1_ARGS="--max-prose-closable 9999 --max-unscorable 9999 --max-out-of-population 9999 --max-unanchored 9999 --min-sh-receipts 0 --min-entries 0"
j1_read() { # j1_read <validator output> -> "<sh-receipts> <scored>", or nothing without a SUMMARY
  printf '%s\n' "$1" | sed -n 's/^SUMMARY .*sh-receipts=\([0-9][0-9]*\) scored=\([0-9][0-9]*\) .*/\1 \2/p'
}
# SELF-PROBE, BOTH DIRECTIONS, before the real ledger: a zero-scored ledger (one exit-9 receipt)
# must yield NO reading, and the same ledger plus the anchor must yield one with scored >= 1.
seed_r "$TMP/j1p"
printf '# Probe backlog\n\n## BL-803\n\nverify: sh grep -q %s probe/guarded.txt || exit 9\n\n' "'MARK803'" \
  > "$TMP/j1p/docs/backlog.md"
( cd "$TMP/j1p" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m zero >/dev/null 2>&1 )
# shellcheck disable=SC2086
j1p_zero_out="$(run_r "" "$TMP/j1p" $J1_ARGS)"
j1p_zero="$(j1_read "$j1p_zero_out")"
printf '## %s\n\nverify: sh grep -q %s probe/subject.txt\n\n' "$J1_ANCHOR" "'MARKJ1ANCHOR'" >> "$TMP/j1p/docs/backlog.md"
( cd "$TMP/j1p" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m anchor >/dev/null 2>&1 )
# shellcheck disable=SC2086
j1p_anch_out="$(run_r "" "$TMP/j1p" $J1_ARGS)"
j1p_anch="$(j1_read "$j1p_anch_out")"
if [ -z "$j1p_zero" ] && [ "${j1p_anch#* }" = 1 ]; then
  ok "j1 probe -- a zero-scored ledger yields no SUMMARY reading, and the same ledger plus the anchor yields scored=1"
else
  bad "j1 probe -- zero-scored reading '$j1p_zero' (want none), anchored reading '$j1p_anch' (want '<n> 1'); the j1 reader or its anchor cannot discriminate, so j1 below proves nothing"
fi
seed_r "$TMP/j1"
cp "$REAL_LEDGER" "$TMP/j1/docs/backlog.md"
# THIS WORLD ALONE CARRIES THE CEILING, SO THE VALIDATOR'S OWN LIVE-LEDGER ARM R9 RUNS IN IT (BL-872).
# j1p above has none, so its anchored run must say `R9: NOT RUN`; this one must say `R9: OK` with the
# same counts this fixture derives independently below. Both are asserted after b16.
cp "$SIZE" "$TMP/j1/scripts/validate-backlog-size.sh"
# The anchor must be an id the real ledger does not carry, or it is a second entry under one id.
# Real entries are titled (`## BL-NNN — ...`), so the id is closed by a non-digit or line end.
# A real ledger DECLARED EMPTY carries no `## BL-` entry by construction, so that half of the
# precondition binds only when the classifier says the ledger is not declared empty; the anchor
# then supplies the arm's whole population and the join below still runs.
( cd "$TMP/j1" && bash scripts/backlog-reverify.sh --declared-empty docs/backlog.md >/dev/null 2>&1 ); j1_de=$?
if [ "$j1_de" -ne 0 ] && [ "$j1_de" -ne 1 ]; then
  bad "j1 -- backlog-reverify.sh --declared-empty exited $j1_de on the real ledger, an environment failure"
fi
if grep -qE "^## ${J1_ANCHOR}([^0-9]|\$)" "$TMP/j1/docs/backlog.md" \
   || { [ "$j1_de" -ne 0 ] && ! grep -q '^## BL-' "$TMP/j1/docs/backlog.md"; }; then
  bad "j1 -- the real ledger already carries ${J1_ANCHOR}, or carries no '## BL-' entry at all while not declared empty; the anchor cannot be told apart"
fi
printf '\n## %s\n\nverify: sh grep -q %s probe/subject.txt\n\n' "$J1_ANCHOR" "'MARKJ1ANCHOR'" >> "$TMP/j1/docs/backlog.md"
( cd "$TMP/j1" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m real >/dev/null 2>&1 )
# --base IS GIVEN EXPLICITLY (BL-899, lead ruling A): this repository has no origin/main, and the snapshot's open
# driver receipts name scripts the seed does not carry, so under M1 their drivers are absent at HEAD. At the j1
# commit itself they are absent at the base too, so they read EXCLUDED-DRIVER-ABSENT-AT-BASE (L3 (b)) and print in
# the M1-EXCLUDED count, never as R7 findings. The j1 commit, not the root: a root base would make every LANDED
# entry of the snapshot an R8 close of this branch and run its receipt.
# shellcheck disable=SC2086
j1_out="$(run_r "" "$TMP/j1" $J1_ARGS --base "$(git -C "$TMP/j1" rev-parse HEAD)")"
j1_rd="$(j1_read "$j1_out")"
j1_arm="${j1_rd%% *}"; j1_sc="${j1_rd#* }"
if [ -z "$j1_rd" ] || [ "$j1_sc" -eq 0 ]; then
  bad "j1 -- the validator printed no SUMMARY or scored nothing on the real ledger plus a receipt it always scores (reading '$j1_rd'); nothing was observed"
  j1_arm=""
fi
# Reverify's own view: one row per entry, id in field 2, restricted to the rows whose verb it
# resolved as `sh` -- which are exactly the ones it reports STILL-LIVE or CLOSE-CANDIDATE from an
# sh receipt. Counting its distinct ids for those statuses is its population.
#
# THE CLASSIFIER RUNS ONCE OVER THE REAL LEDGER FOR BOTH ARMS. It evaluates every receipt in the
# ledger, which is the cost of this unit, and b16 below asks it for the same ledger minus the anchor.
# Its rows are held here and b16 subtracts the anchor's row, a rule that is asserted to have removed
# exactly one row so the subtraction cannot decay into a no-op.
j1_rows="$( cd "$TMP/j1" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null )"
j1_rev="$(printf '%s\n' "$j1_rows" | awk -F'\t' '$3 ~ /^sh receipt exited/ { print $2 }' | sort -u | grep -c . )"
if [ -z "$j1_arm" ] || [ -z "$j1_rev" ]; then
  bad "j1 -- a side produced no value (arm='$j1_arm' reverify='$j1_rev')"
elif [ "$j1_arm" -eq 0 ] || [ "$j1_rev" -eq 0 ]; then
  bad "j1 -- a side counted ZERO (arm=$j1_arm reverify=$j1_rev); two predicates that both find nothing agree perfectly and prove nothing"
elif [ "$j1_arm" -lt "$j1_rev" ]; then
  bad "j1 -- the arm sees $j1_arm sh receipts and backlog-reverify.sh resolves $j1_rev. The arm's population is SMALLER than the classifier's, so receipts exist that it never scores."
else
  ok "j1 -- on the real ledger the arm's sh population ($j1_arm) covers the classifier's resolved set ($j1_rev)"
fi

# ===== b16: THE CEILING JOIN ON THE REAL LEDGER. ============================================
# The same join core/fixtures/backlog-size-ceiling/ b15 makes on a seeded ledger, against the
# REAL one, which is the one that catches a drift filed after that fixture was written.
# WHEN THE REAL LEDGER IS DECLARED EMPTY the count join has no population, so the two sides are
# asked the declared state instead: the ceiling must report 0 with its declared-empty OK line,
# and the classifier must emit exactly one DECLARED-EMPTY row. Which branch runs is decided by the
# classifier's own --declared-empty on the real file, and each branch is presence-shaped.
seed_s "$TMP/b16"; cp "$REAL_LEDGER" "$TMP/b16/docs/backlog.md"
b16_out="$(run_s "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/b16")"
b16_arm="$(bl_reported "$b16_out")"
# The declared-empty answer for the real ledger was taken above on j1's byte-identical copy of it
# (before the anchor was appended), so it is not asked again. A declared-empty ledger has no
# receipts to evaluate, so only that branch asks the classifier for its own rows; otherwise the rows
# are j1's with the anchor's single row removed.
b16_de="$j1_de"
if [ "$b16_de" -eq 0 ]; then
  b16_rows="$( cd "$TMP/b16" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null )"
else
  b16_rows="$(printf '%s\n' "$j1_rows" | awk -F'\t' -v a="$J1_ANCHOR" '$2 != a')"
  b16_gone=$(( $(printf '%s\n' "$j1_rows" | grep -c .) - $(printf '%s\n' "$b16_rows" | grep -c .) ))
  [ "$b16_gone" -eq 1 ] || bad "b16 -- removing the anchor's row from the classifier's rows removed $b16_gone rows, want exactly 1"
fi
b16_rev="$(printf '%s\n' "$b16_rows" | cut -f2 | sort -u | grep -c . )"
if [ "$b16_de" -eq 0 ]; then
  b16_nrow="$(printf '%s\n' "$b16_rows" | grep -c .)" || b16_nrow=0
  if [ "$b16_arm" = 0 ] && grep -qF ', declared empty (' <<<"$b16_out" \
     && [ "$b16_nrow" -eq 1 ] && [ "$(printf '%s\n' "$b16_rows" | cut -f1)" = DECLARED-EMPTY ]; then
    ok "b16 -- the real ledger is declared empty, and the ceiling (0, declared empty) and the classifier (one DECLARED-EMPTY row) both say so"
  else
    bad "b16 -- the real ledger is declared empty but the sides disagree (arm='$b16_arm', classifier rows=$b16_nrow first='$(printf '%s\n' "$b16_rows" | sed -n '1p' | cut -f1)')"
  fi
elif [ "$b16_de" -ne 1 ]; then
  bad "b16 -- backlog-reverify.sh --declared-empty exited $b16_de on the real ledger, an environment failure"
elif [ -z "$b16_arm" ] || [ -z "$b16_rev" ] || [ "$b16_arm" -eq 0 ] || [ "$b16_rev" -eq 0 ]; then
  bad "b16 -- a side produced no usable value (arm='$b16_arm' reverify='$b16_rev')"
elif [ "$b16_arm" -ne "$b16_rev" ]; then
  bad "b16 -- on the REAL ledger the ceiling counts $b16_arm and backlog-reverify.sh classifies $b16_rev"
else
  ok "b16 -- on the real ledger the ceiling and the classifier agree at $b16_arm entries"
fi

# ===== r9: THE VALIDATOR'S OWN LIVE-LEDGER ARM, BOTH DIRECTIONS (BL-872). ===================
# R9 of the receipts validator is where j1 and b16 run against the LIVE ledger now. Its OK line must
# carry the counts this fixture derived on its own above for the same world (the snapshot plus the
# anchor, so the ceiling reads b16 + 1), and the world with no size validator must say NOT RUN.
# Presence-shaped both ways: a validator with the arm deleted prints neither line.
if [ "$b16_de" -eq 1 ] && [ -n "$b16_arm" ] && [ -n "$j1_arm" ]; then
  r9_want="j1 the sh population $j1_arm covers the classifier's resolved set "
  r9_want2="b16 the ceiling and the classifier agree at $(( b16_arm + 1 )) entries"
  r9_line="$(printf '%s\n' "$j1_out" | grep '^R9: ')" || r9_line=""
  if grep -qF "$r9_want" <<<"$r9_line" && grep -qF "$r9_want2" <<<"$r9_line" && grep -q '^R9: OK -- ' <<<"$r9_line"; then
    ok "r9 -- the validator's live-ledger arm R9 ran in the world carrying the ceiling and agrees with this fixture ($j1_arm sh, $(( b16_arm + 1 )) entries)"
  else
    bad "r9 -- the validator's R9 line in the world carrying the ceiling is '${r9_line}', want R9: OK carrying '${r9_want}' and '${r9_want2}'"
  fi
  if grep -q '^R9: NOT RUN -- scripts/validate-backlog-size.sh is absent' <<<"$j1p_anch_out"; then
    ok "r9 -- the world with no size validator says R9: NOT RUN rather than a clean result"
  else
    bad "r9 -- the world with no size validator did not print R9: NOT RUN (got '$(printf '%s\n' "$j1p_anch_out" | grep '^R9' )')"
  fi
fi

# j1-m1x (BL-899, lead ruling A): the snapshot holds exactly TWO open receipts whose first command is `bash <P>` --
# BL-868 (`bash scripts/check-no-provisional-invocations.sh`) and BL-878 (`bash scripts/validate-fixture-inprocess.sh
# --complete`), derived by reading ledger.snapshot -- and seed_r carries neither script. With j1's --base at its own
# commit both drivers are absent at HEAD and at the base, so M1 counts them EXCLUDED (L3 (b)).
M1X_WANT="M1-EXCLUDED: 2 open sh receipt(s) EXCLUDED-DRIVER-ABSENT-AT-BASE"
if grep -qF "$M1X_WANT" <<<"$j1_out"; then
  ok "j1-m1x -- the validator counted BL-868 and BL-878 EXCLUDED-DRIVER-ABSENT-AT-BASE under j1's --base"
else
  bad "j1-m1x -- the M1 line is '$(printf '%s\n' "$j1_out" | grep '^M1-EXCLUDED' )', want '$M1X_WANT'"
fi

report_end backlog-real-ledger
