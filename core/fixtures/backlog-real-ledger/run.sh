#!/usr/bin/env bash
# backlog-real-ledger -- the two arms whose verdict depends on the CONTENT of this repository's
# own docs/backlog.md, in a unit keyed on that file.
#
#   j1   the receipts validator's `sh` population covers the shipping classifier's resolved set
#        on the real ledger (scripts/validate-backlog-receipts.sh vs scripts/backlog-reverify.sh)
#   b16  the size ceiling's entry count equals the classifier's on the real ledger
#        (scripts/validate-backlog-size.sh vs scripts/backlog-reverify.sh)
#
# WHY THESE TWO LIVE HERE AND NOT IN THEIR SUBJECTS' FIXTURES. They were j1 of
# core/fixtures/backlog-receipt-binding/ and b16 of core/fixtures/backlog-size-ceiling/, and
# `docs` is an EXCLUDED top of scripts/suite-content-key.sh, so neither the outer suite key nor
# the hook's per-fixture key ever saw a backlog edit: a push carrying exactly the drift these arms
# exist to catch skipped them. They are MOVED, not copied, into this small unit, whose inputs.decl
# declares the ledger with a leading `+`. The hook's READSET_KEYROWS span keys a `+` file even
# under an excluded top, and suite-content-key.sh hashes every `+` file into the outer key, so a
# backlog-only push misses the outer key and the inner skip runs this unit alone -- seconds,
# where keying the two source fixtures on the ledger would have paid backlog-receipt-binding's
# whole run on every docs release.
#
# THE LEDGER IS NAMED THROUGH "$ROOT/docs/backlog.md" -- A SPELLING I55 READS. I55 arm 3 flags a
# fixture reaching a content-key-excluded path at the distribution root, and acquits one only
# where the reach names a file this fixture declares with `+`. A `$DIR/../../../docs/...` chain
# would be invisible to that grammar, so the acquittal could never be checked.
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

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../../.." 2>/dev/null && pwd || true)"

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
REAL_LEDGER=""
[ -n "$ROOT" ] && [ -f "$ROOT/docs/backlog.md" ] && REAL_LEDGER="$ROOT/docs/backlog.md"
for _p in RECEIPTS SIZE REVERIFY LIBSRC REVSRC REAL_LEDGER; do
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
rc=0
note() { printf '%s\n' "$*"; }

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
J1_ARGS="--max-prose-closable 9999 --max-unscorable 9999 --max-out-of-population 9999 --min-sh-receipts 0 --min-entries 0"
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
j1p_zero="$(j1_read "$(run_r "" "$TMP/j1p" $J1_ARGS)")"
printf '## %s\n\nverify: sh grep -q %s probe/subject.txt\n\n' "$J1_ANCHOR" "'MARKJ1ANCHOR'" >> "$TMP/j1p/docs/backlog.md"
( cd "$TMP/j1p" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m anchor >/dev/null 2>&1 )
# shellcheck disable=SC2086
j1p_anch="$(j1_read "$(run_r "" "$TMP/j1p" $J1_ARGS)")"
if [ -z "$j1p_zero" ] && [ "${j1p_anch#* }" = 1 ]; then
  note "ok    j1 probe -- a zero-scored ledger yields no SUMMARY reading, and the same ledger plus the anchor yields scored=1"
else
  note "FAIL  j1 probe -- zero-scored reading '$j1p_zero' (want none), anchored reading '$j1p_anch' (want '<n> 1'); the j1 reader or its anchor cannot discriminate, so j1 below proves nothing"; rc=1
fi
seed_r "$TMP/j1"
cp "$REAL_LEDGER" "$TMP/j1/docs/backlog.md"
# The anchor must be an id the real ledger does not carry, or it is a second entry under one id.
# Real entries are titled (`## BL-NNN — ...`), so the id is closed by a non-digit or line end.
# A real ledger DECLARED EMPTY carries no `## BL-` entry by construction, so that half of the
# precondition binds only when the classifier says the ledger is not declared empty; the anchor
# then supplies the arm's whole population and the join below still runs.
( cd "$TMP/j1" && bash scripts/backlog-reverify.sh --declared-empty docs/backlog.md >/dev/null 2>&1 ); j1_de=$?
if [ "$j1_de" -ne 0 ] && [ "$j1_de" -ne 1 ]; then
  note "FAIL  j1 -- backlog-reverify.sh --declared-empty exited $j1_de on the real ledger, an environment failure"; rc=1
fi
if grep -qE "^## ${J1_ANCHOR}([^0-9]|\$)" "$TMP/j1/docs/backlog.md" \
   || { [ "$j1_de" -ne 0 ] && ! grep -q '^## BL-' "$TMP/j1/docs/backlog.md"; }; then
  note "FAIL  j1 -- the real ledger already carries ${J1_ANCHOR}, or carries no '## BL-' entry at all while not declared empty; the anchor cannot be told apart"; rc=1
fi
printf '\n## %s\n\nverify: sh grep -q %s probe/subject.txt\n\n' "$J1_ANCHOR" "'MARKJ1ANCHOR'" >> "$TMP/j1/docs/backlog.md"
( cd "$TMP/j1" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m real >/dev/null 2>&1 )
# shellcheck disable=SC2086
j1_out="$(run_r "" "$TMP/j1" $J1_ARGS)"
j1_rd="$(j1_read "$j1_out")"
j1_arm="${j1_rd%% *}"; j1_sc="${j1_rd#* }"
if [ -z "$j1_rd" ] || [ "$j1_sc" -eq 0 ]; then
  note "FAIL  j1 -- the validator printed no SUMMARY or scored nothing on the real ledger plus a receipt it always scores (reading '$j1_rd'); nothing was observed"; rc=1
  j1_arm=""
fi
# Reverify's own view: one row per entry, id in field 2, restricted to the rows whose verb it
# resolved as `sh` -- which are exactly the ones it reports STILL-LIVE or CLOSE-CANDIDATE from an
# sh receipt. Counting its distinct ids for those statuses is its population.
j1_rev="$( cd "$TMP/j1" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null \
  | awk -F'\t' '$3 ~ /^sh receipt exited/ { print $2 }' | sort -u | grep -c . )"
if [ -z "$j1_arm" ] || [ -z "$j1_rev" ]; then
  note "FAIL  j1 -- a side produced no value (arm='$j1_arm' reverify='$j1_rev')"; rc=1
elif [ "$j1_arm" -eq 0 ] || [ "$j1_rev" -eq 0 ]; then
  note "FAIL  j1 -- a side counted ZERO (arm=$j1_arm reverify=$j1_rev); two predicates that both find nothing agree perfectly and prove nothing"; rc=1
elif [ "$j1_arm" -lt "$j1_rev" ]; then
  note "FAIL  j1 -- the arm sees $j1_arm sh receipts and backlog-reverify.sh resolves $j1_rev. The arm's population is SMALLER than the classifier's, so receipts exist that it never scores."; rc=1
else
  note "ok    j1 -- on the real ledger the arm's sh population ($j1_arm) covers the classifier's resolved set ($j1_rev)"
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
b16_rows="$( cd "$TMP/b16" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null )"
b16_rev="$(printf '%s\n' "$b16_rows" | cut -f2 | sort -u | grep -c . )"
( cd "$TMP/b16" && bash scripts/backlog-reverify.sh --declared-empty docs/backlog.md >/dev/null 2>&1 ); b16_de=$?
if [ "$b16_de" -eq 0 ]; then
  b16_nrow="$(printf '%s\n' "$b16_rows" | grep -c .)" || b16_nrow=0
  if [ "$b16_arm" = 0 ] && grep -qF ', declared empty (' <<<"$b16_out" \
     && [ "$b16_nrow" -eq 1 ] && [ "$(printf '%s\n' "$b16_rows" | cut -f1)" = DECLARED-EMPTY ]; then
    note "ok    b16 -- the real ledger is declared empty, and the ceiling (0, declared empty) and the classifier (one DECLARED-EMPTY row) both say so"
  else
    note "FAIL  b16 -- the real ledger is declared empty but the sides disagree (arm='$b16_arm', classifier rows=$b16_nrow first='$(printf '%s\n' "$b16_rows" | sed -n '1p' | cut -f1)')"; rc=1
  fi
elif [ "$b16_de" -ne 1 ]; then
  note "FAIL  b16 -- backlog-reverify.sh --declared-empty exited $b16_de on the real ledger, an environment failure"; rc=1
elif [ -z "$b16_arm" ] || [ -z "$b16_rev" ] || [ "$b16_arm" -eq 0 ] || [ "$b16_rev" -eq 0 ]; then
  note "FAIL  b16 -- a side produced no usable value (arm='$b16_arm' reverify='$b16_rev')"; rc=1
elif [ "$b16_arm" -ne "$b16_rev" ]; then
  note "FAIL  b16 -- on the REAL ledger the ceiling counts $b16_arm and backlog-reverify.sh classifies $b16_rev"; rc=1
else
  note "ok    b16 -- on the real ledger the ceiling and the classifier agree at $b16_arm entries"
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-real-ledger -- j1 and b16 hold on the real ledger"
fi
exit "$rc"
