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
# THE ONE MUTANT (m-loose, the strict bullet test deleted from the seed's lib.sh) is scored on its
# deciding arm p1-count (the ceiling reads the real ledger plus one host as +2, not +1) plus ONE named
# twin, b16-count, which must stay green: the same mutated tree reading the real ledger ALONE still
# agrees with the unmutated count, so the effect is confined to the phantom bullet. The mutant x arm
# matrix is MEASURED by the --matrix argv mode and is re-measured whenever an arm or a mutant is added
# or changed. The recorded matrix plus the twin replaces the exact-vector assertion.
# MUTANT-MATRIX m-loose decides=p1-count twins=b16-count
# MUTANT-MATRIX-REMEASURE bash core/fixtures/backlog-real-ledger/run.sh --matrix
set -u

MATRIX=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; fi
MROWS=0

# CLEAR EVERY AMBIENT AI_DLC_* KEY (I87): b16 passes its ceiling as a double-quoted `env` word,
# which is not an assignment for the probes that do not set it.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# SCRUB THE REPOSITORY ENVIRONMENT: j1 runs `git init` in mktemp trees, and an inherited GIT_DIR
# makes `git init` succeed without creating a repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
# The receipts validator's re-entry sentinel: inherited, every run below would score nothing.
unset BR_RECEIPTS_RUNNING

DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$DIR/../lib/mutant.sh" ] && [ -f "$DIR/../lib/matrix.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh or lib/matrix.sh not found" >&2; exit 2; }
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
EXTRACT="$(find_one "$DIR/../../../docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py" "$DIR/../../docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py")" || EXTRACT=""
# The could-not-measure rule both the classifier and the receipts validator source from beside them.
RLIB="$(find_one "$DIR/../../scripts/backlog-receipt-lib.sh" "$DIR/../../../scripts/backlog-receipt-lib.sh")" || RLIB=""
REAL_LEDGER=""
[ -n "$ROOT" ] && [ -f "$ROOT/docs/backlog.md" ] && REAL_LEDGER="$ROOT/docs/backlog.md"
for _p in RECEIPTS SIZE REVERIFY LIBSRC REVSRC EXTRACT RLIB REAL_LEDGER; do
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
ok()  { note "ok    $1"; }
bad() { note "FAIL  $1"; rc=1; }
. "$DIR/../lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
. "$DIR/../lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"
B_P1=0

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
  cp "$EXTRACT" "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"
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
#
# THE CLASSIFIER RUNS ONCE OVER THE REAL LEDGER FOR BOTH ARMS. It evaluates every receipt in the
# ledger, which is the cost of this unit, and b16 below asks it for the same ledger minus the anchor.
# Its rows are held here and b16 subtracts the anchor's row, a rule that is asserted to have removed
# exactly one row so the subtraction cannot decay into a no-op.
j1_rows="$( cd "$TMP/j1" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null )"
j1_rev="$(printf '%s\n' "$j1_rows" | awk -F'\t' '$3 ~ /^sh receipt exited/ { print $2 }' | sort -u | grep -c . )"
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
  [ "$b16_gone" -eq 1 ] || { note "FAIL  b16 -- removing the anchor's row from the classifier's rows removed $b16_gone rows, want exactly 1"; rc=1; }
fi
b16_rev="$(printf '%s\n' "$b16_rows" | cut -f2 | sort -u | grep -c . )"
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

# ===== p1: A PROSE LEAD-IN BULLET ON THE REAL LEDGER (BL-820). ==============================
# The real ledger plus one host entry that carries `- **BL-632 is LANDED** prose` before its
# receipt must count exactly ONE more than the real ledger alone -- the host, never the phantom.
# The ceiling is the cheap reader; the label rule is lib.sh's, shared by every BL- reader.
# Declared empty, the real ledger counts 0 and the marker is no longer last once the host is
# appended, so that branch is not a count comparison and is skipped by name.
# m-loose (the strict bullet test deleted from the seed's lib.sh) must read +2.
p1_seed() { # p1_seed <dir>
  seed_s "$1"; cp "$REAL_LEDGER" "$1/docs/backlog.md"
  printf '\n## BL-898 — host\n\nBody.\n\n- **BL-632 is LANDED** prose about another entry\n\nverify: manual\n' >> "$1/docs/backlog.md"
}
if [ "$b16_de" -eq 1 ] && [ -n "$b16_arm" ] && [ "$b16_arm" -gt 0 ]; then
  p1_seed "$TMP/p1"
  p1_arm="$(bl_reported "$(run_s "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/p1")")"
  if [ "$p1_arm" = "$(( b16_arm + 1 ))" ]; then
    note "ok    p1 -- a host carrying a '- **BL-632 is LANDED**' lead-in adds exactly one entry to the real ledger ($b16_arm -> $p1_arm)"; B_P1=1
  else
    note "FAIL  p1 -- the real ledger counts $b16_arm and with one host appended counts '${p1_arm}', want $(( b16_arm + 1 ))"; rc=1
  fi
  p1_seed "$TMP/p1m"
  p1m_lib="$TMP/p1m/core/skills/ai-dlc-update/reconcile/lib.sh"
  sed '/if (line !~ \/^BL-/d' "$LIBSRC" > "$p1m_lib"
  if cmp -s "$LIBSRC" "$p1m_lib"; then
    note "FAIL  p1 m-loose -- the label mutation DID NOT APPLY"; rc=1
  else
    p1m_arm="$(bl_reported "$(run_s "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/p1m")")"
    # The twin: the SAME mutated tree reading the real ledger alone (no host appended).
    seed_s "$TMP/p1mt"; cp "$REAL_LEDGER" "$TMP/p1mt/docs/backlog.md"; cp "$p1m_lib" "$TMP/p1mt/core/skills/ai-dlc-update/reconcile/lib.sh"
    p1mt_arm="$(bl_reported "$(run_s "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/p1mt")")"
    if [ "$p1m_arm" = "$(( b16_arm + 2 ))" ]; then
      mutant_killed "$B_P1" m-loose "m-loose [p1-count]: with the loose label rule the lead-in counts too ($b16_arm -> $p1m_arm)"
    else
      bad "p1 m-loose SURVIVED: the loose rule read '${p1m_arm}', want $(( b16_arm + 2 ))"
    fi
    if [ "$p1mt_arm" = "$b16_arm" ]; then
      ok "[b16-count] twin of m-loose stays green: the mutated tree reads the real ledger alone at $p1mt_arm, equal to the unmutated $b16_arm"
    else
      bad "[b16-count] the twin TRIPPED: the mutated tree reads the real ledger at '${p1mt_arm}', the unmutated tree at $b16_arm"
    fi
    if [ "$MATRIX" = 1 ]; then
      p1_t=GREEN; p1_k=no; [ "$p1m_arm" != "$(( b16_arm + 1 ))" ] && { p1_t=TRIPPED; p1_k=yes; }
      b16_t=GREEN; b16_k=no; [ "$p1mt_arm" != "$b16_arm" ] && { b16_t=TRIPPED; b16_k=yes; }
      matrix_row m-loose p1-count 0 "$p1_t" "$p1_k"
      matrix_row m-loose b16-count 0 "$b16_t" "$b16_k"
      MROWS=2
    fi
  fi
elif [ "$b16_de" -eq 0 ]; then
  note "SKIP  p1 -- the real ledger is declared empty, so there is no count to compare"
else
  note "FAIL  p1 -- no usable real-ledger count from b16 (arm='$b16_arm' declared-empty rc=$b16_de)"; rc=1
fi

if [ "$MATRIX" = 0 ]; then
  if [ "$MROWS" -eq 0 ]; then ok "[MX] a plain run executed no matrix-only cell (rows=0)"; else bad "[MX] a plain run executed $MROWS matrix rows"; fi
elif [ "$MROWS" -eq 2 ]; then ok "[MX] the matrix run measured 2 cells for the 1 mutant"
else bad "[MX] matrix rows=$MROWS, 2 expected"; fi

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-real-ledger -- j1 and b16 hold on the real ledger"
fi
exit "$rc"
