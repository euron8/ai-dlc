#!/usr/bin/env bash
# backlog-receipt-binding -- exercise scripts/validate-backlog-receipts.sh, the arm that scores
# every live `verify: sh` receipt against a comment carrying that receipt's own grep literals.
#
# AN UNMUTATED CONTROL PLUS EIGHT MUTANTS, each driven against a throwaway repository under a
# temp dir. Exit 0 iff the control is green AND every mutant is killed by its own assertion.
#
# EVERY MUTANT IS KILLED BY A BEHAVIOURAL ARM AND NOT BY A BYTE-LOCK ON A SPELLING. What each
# one asserts is a VERDICT the subject produces over a seeded ledger -- a receipt classified,
# a count moved, an exit code -- so any implementation that gets the behaviour right passes and
# any that does not fails, whatever it looks like.
#
# FIVE THINGS HERE ARE A DELIBERATE COPY FROM core/fixtures/backlog-size-ceiling/run.sh, NOT AN
# INDEPENDENT INVENTION, AND THE COPY IS THE POINT. `seed()`, the env-passing runner, the
# `kill_check` shape, the `cmp -s` guard on every mutation, and the "assert the FAIL-line COUNT,
# not just the message" rule are that file's, worked out against sixteen probes over several
# releases -- and they are that file's copy of claude-rules-joins/run.sh in turn. Re-deriving
# them here would produce a third, weaker harness whose bugs nobody finds. They are copied
# rather than sourced because a fixture that sources a sibling cannot be run alone, and the
# suite's pool dispatches directories independently.
#
# EVERY MUTATION IS BYTE-COMPARED BEFORE ITS VERDICT IS READ. A mutant keyed on a token the
# target does not contain is a NO-OP that comes back green and reads exactly like a mutant that
# survived. Measured in this very file's development: two `sed` anchors matched nothing after
# the subject was reshaped, and both runs passed until the guard was added.
#
# WHY THE CONTROL IS NOT DECORATION. Each probe is a fresh seed plus one edit, and the subject
# resolves its own root by walking up for VERSION and sources reconcile/lib.sh beside it. A
# seed that fails to build makes the subject exit 2 having printed nothing, and "no output"
# would otherwise score as a kill on every probe below. The control is also PRESENCE-shaped --
# it demands the OK line and a named classification -- because a control asserting only
# rc=0-and-no-findings passes against a subject replaced by `exit 0`.
#
# THE PROBE LEDGERS ARE SEEDED FROM WHAT AN AUTHOR WRITES, NEVER FROM WHAT THE SUBJECT ACCEPTS.
# Each receipt below is a shape that exists in the real ledger: a literal grep against a file,
# a receipt that drives a script and reads its output, a precondition guard that exits 9, a
# predicate built from a variable.
#
# MUTANT-MATRIX. Each mutant is scored on its DECIDING ARM plus ONE named TWIN, an arm the measured matrix shows GREEN under
# it, read off the same capture. `--matrix` captures every mutant once and scores it on EVERY arm. The recorded matrix plus the twin
# replaces the exact-vector assertion that a mutant fails only its own assertion. The matrix is re-measured whenever an arm or a mutant
# is added or changed. c5-m4-open is the same mutation as c5-m4 over an OPEN receipt: a matrix-only cell, not run per push.
# MUTANT-MATRIX m1 decides=m1 twins=m6
# MUTANT-MATRIX m3 decides=m3 twins=m6
# MUTANT-MATRIX m2c decides=m2c twins=m3
# MUTANT-MATRIX m4 decides=m4 twins=m3
# MUTANT-MATRIX m14b decides=m14b twins=m3
# MUTANT-MATRIX m5b decides=m5b twins=m7b
# MUTANT-MATRIX m12 decides=m12 twins=m7b
# MUTANT-MATRIX m13 decides=m13 twins=m7b
# MUTANT-MATRIX m16 decides=m16 twins=m7b
# MUTANT-MATRIX gitdir-mutant decides=gitdir_mutant twins=m7b
# MUTANT-MATRIX m6 decides=m6 twins=m1
# MUTANT-MATRIX m7b decides=m7b twins=m16
# MUTANT-MATRIX m15 decides=m15 twins=m16
# MUTANT-MATRIX m8b-mut decides=m8b_mut twins=m8c_mut
# MUTANT-MATRIX m8d-mut decides=m8d_mut twins=m6
# MUTANT-MATRIX m8c-mut decides=m8c_mut twins=m8b_mut
# MUTANT-MATRIX m8e-mut decides=m8e_mut twins=m8c_mut
# MUTANT-MATRIX m17 decides=m17 twins=m18
# MUTANT-MATRIX m18 decides=m18 twins=m17
# MUTANT-MATRIX m-loose decides=m_loose twins=m_heading_only
# MUTANT-MATRIX m-heading-only decides=m_heading_only twins=m_loose
# MUTANT-MATRIX m-memo-unset decides=m_memo_unset twins=m_memo_name
# MUTANT-MATRIX m-memo-name decides=m_memo_name twins=m_memo_derive
# MUTANT-MATRIX m-memo-derive decides=m_memo_derive twins=m_memo_unset
# MUTANT-MATRIX m-noclose decides=m_noclose twins=m6
# MUTANT-MATRIX m-widenostep decides=m_widenostep twins=m6
# MUTANT-MATRIX m-nopathnarrow decides=m_nopathnarrow twins=m6
# MUTANT-MATRIX m-noseat decides=m_noseat twins=m6
# MUTANT-MATRIX m-seatword decides=m_seatword twins=m6
# MUTANT-MATRIX m-nofiling decides=m_nofiling twins=m6
# MUTANT-MATRIX m-noscript decides=m_noscript twins=m6
# MUTANT-MATRIX m-nofigs decides=m_nofigs twins=m6
# MUTANT-MATRIX m-nostep decides=m_nostep twins=m6
# MUTANT-MATRIX m-nobaseline decides=m_nobaseline twins=m6
# MUTANT-MATRIX m-nomovement decides=m_nomovement twins=m6
# MUTANT-MATRIX m-noscope decides=m_noscope twins=m6
# MUTANT-MATRIX c5-m1 decides=c5_m1 twins=c5_m2
# MUTANT-MATRIX c5-m4 decides=c5_m4 twins=c5_m1
# MUTANT-MATRIX c5-m2 decides=c5_m2 twins=c5_m1
# MUTANT-MATRIX c5-m3 decides=c5_m3 twins=c5_m5
# MUTANT-MATRIX c5-m5 decides=c5_m5 twins=c5_m6
# MUTANT-MATRIX c5-m6 decides=c5_m6 twins=c5_m5
# MUTANT-MATRIX c5-m7 decides=c5_m7 twins=c5_m8
# MUTANT-MATRIX c5-m8 decides=c5_m8 twins=c5_m7
# MUTANT-MATRIX c5-m9 decides=c5_m9 twins=c5_m10
# MUTANT-MATRIX c5-m11 decides=c5_m11 twins=c5_m10
# MUTANT-MATRIX c5-m12 decides=c5_m12 twins=c5_m10
# MUTANT-MATRIX c5-m10 decides=c5_m10 twins=c5_m9
# MUTANT-MATRIX c5-m4-open decides=c5_open twins=c5_m4
# MUTANT-MATRIX-REMEASURE bash core/fixtures/backlog-receipt-binding/run.sh --matrix
# Usage: run.sh
# Exit:  0 = every probe holds, 1 = one regressed, 2 = fixture broken.
set -u
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1

# CLEAR EVERY AMBIENT AI_DLC_* KEY BEFORE ANY PROBE RUNS, and I87 fails the push without it.
# This fixture parameterises the ceilings by passing them as `env` words into each run, but it
# passes them double-quoted, which I87's assignment scan does not recognise as an assignment --
# and correctly so: an assignment inside ONE invocation says nothing about the probes that do
# NOT set it. Those would otherwise read the operator's .claude/settings.json, so a probe
# asserting a DEFAULT would assert whatever that file happens to say: passing for the wrong
# reason here and failing on a build machine set differently.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# SCRUB THE REPOSITORY ENVIRONMENT BEFORE THIS FIXTURE BUILDS ANYTHING. Every probe below runs
# `git init` in a `mktemp` tree and relies on git's upward DISCOVERY to find it. Git exports
# GIT_DIR, ABSOLUTE, into any hook running from a linked worktree, so a suite dispatched by an
# unscrubbed caller -- or an operator running this file by hand, which is what the repo's own
# rules say to do when debugging a fixture -- has `git init` SILENTLY SUCCEED WITHOUT CREATING
# A REPOSITORY and every later git call write the CALLER's index. This fixture's subject then
# adds worktrees to the caller's repository rather than to the probe's, which is the same
# defect with a larger blast radius.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
# The validator's re-entry sentinel. Inherited from a receipt that runs this fixture, it would
# make every probe run below skip its corpus and score nothing.
unset BR_RECEIPTS_RUNNING

DIR="$(cd "$(dirname "$0")" && pwd)"

# Both install layouts named, the way I33c requires: a chain rooted at the fixture's own
# location and naming only one layout passes I33 and I33b and is the identical consumer-side
# failure.
VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-backlog-receipts.sh" \
  "$DIR/../../../scripts/validate-backlog-receipts.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "FIXTURE BROKEN: could not locate validate-backlog-receipts.sh" >&2; exit 2
fi
echo "HERMETIC-CONSUMED scripts/validate-backlog-receipts.sh"

LIBSRC=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/lib.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/lib.sh"; do
  [ -f "$cand" ] && LIBSRC="$cand" && break
done
if [ -z "$LIBSRC" ]; then
  echo "FIXTURE BROKEN: could not locate reconcile/lib.sh" >&2; exit 2
fi

# The file the subject's R0 arm binds its path-split class to. Resolved here because a probe
# tree without it makes the subject exit 2 for a reason no probe below is about.
REVSRC=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; do
  [ -f "$cand" ] && REVSRC="$cand" && break
done
if [ -z "$REVSRC" ]; then
  echo "FIXTURE BROKEN: could not locate reconcile/ledger-reverify.sh" >&2; exit 2
fi

# The extractor whose STEP_RE the subject reads its F-STEP vocabulary from (BL-817 item 2). A probe
# tree without it makes the subject refuse with exit 2 before any arm runs.
EXTRACT=""
for cand in \
  "$DIR/../../../docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py" \
  "$DIR/../../docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"; do
  [ -f "$cand" ] && EXTRACT="$cand" && break
done
if [ -z "$EXTRACT" ]; then
  echo "FIXTURE BROKEN: could not locate pipeline-efficiency-s317-s320/scripts/extract.py" >&2; exit 2
fi

# The shipping classifier: R2's declared-empty exemption asks it, so every seed carries it, and m8d
# reads its marker.
REVERIFY=""
for cand in "$DIR/../../../scripts/backlog-reverify.sh" "$DIR/../../scripts/backlog-reverify.sh"; do
  [ -f "$cand" ] && REVERIFY="$cand" && break
done
RLIB=""
for cand in "$DIR/../../../scripts/backlog-receipt-lib.sh" "$DIR/../../scripts/backlog-receipt-lib.sh"; do
  [ -f "$cand" ] && RLIB="$cand" && break
done
if [ -z "$RLIB" ]; then
  echo "FIXTURE BROKEN: could not locate scripts/backlog-receipt-lib.sh" >&2; exit 2
fi

TMP="$(mktemp -d)"
# A PROBE REPOSITORY REGISTERS ITS OWN WORKTREES, and the subject removes them; this catches
# a subject that did not, so a leak is cleaned up rather than left in $TMPDIR.
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
[ -f "$DIR/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
[ -f "$DIR/../lib/matrix.sh" ] || { echo "FIXTURE ERROR: lib/matrix.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"

# --- the mutant scorer ------------------------------------------------------------------------
# Each mutant's run is CAPTURED once (rc and output under $REC) and a mutant is scored by its
# DECIDING ARM, a predicate over that capture. The per-push twin is a second arm, read off the SAME
# capture, which the measured matrix shows green. `--matrix` evaluates every arm over every capture.
# An arm is the base fixture's own kill condition for that mutant, transcribed and not weakened.
REC="$TMP/rec"; mkdir -p "$REC"
SCORED=""; MROWS=0
cell() { printf '%s\n' "$2" > "$REC/$1.rc"; printf '%s\n' "$3" > "$REC/$1.out"; }
record() { cell "$@"; }
side() { printf 'SIDE %s\n' "$2" >> "$REC/$1.out"; }
drive() { # drive <name> <dir> <env> [<extra-args>...]
  local n="$1" d="$2" e="$3" o r; shift 3
  o="$(run_v "$e" "$d" "$@")"; r=$?
  record "$n" "$r" "$o"
}
r_rc() { cat "$REC/$1.rc"; }
r_has() { grep -qF -- "$2" "$REC/$1.out"; }
r_line() { grep -qxF -- "$2" "$REC/$1.out"; }
r_cls() { cls "$(cat "$REC/$1.out")" "$2"; }
# score <mutant> <base-pass flag> <message> [arm]   (arm defaults to the mutant's name, dashes to underscores)
score() {
  local m="$1" f="$2" a="${4:-${1//-/_}}"
  SCORED="$SCORED $m"
  if "arm_$a" "$m"; then mutant_killed "$f" "$m" "$3"
  else bad "$m SURVIVED: its deciding arm $a did not trip -- rc=$(r_rc "$m")"; sed -n '1,3p' "$REC/$m.out" | sed 's/^/      /'; fi
}

# ARMS. Each is the kill condition of the base fixture's chain for that mutant.
arm_m1() { [ "$(r_rc "$1")" = 2 ] && r_has "$1" "SELF-PROBE FAILED" && ! r_has "$1" "OK: validate-backlog-receipts"; }
arm_m2c() { [ "$(r_rc "$1")" != 0 ] && r_has "$1" "are satisfied by a COMMENT"; }
arm_m3() { [ "$(r_rc "$1")" != 0 ] && ! r_has "$1" "OK: validate-backlog-receipts" && grep -qE 'base-exit-9 receipt|exits 9 on' "$REC/$1.out"; }
arm_m4() { [ "$(r_cls "$1" BL-805)" != "ALREADY-PASSING" ] && [ "$(r_rc "$1")" != 0 ]; }
arm_m5b() { [ "$(r_cls "$1" BL-801)" != "UNSEEDED" ] && ! { [ "$(r_rc "$1")" = 0 ] && [ -z "$(r_cls "$1" BL-801)" ]; }; }
arm_m6() { [ "$(r_rc "$1")" = 2 ] && r_has "$1" "DRIFTED" && ! r_has "$1" "OK: validate-backlog-receipts"; }
arm_m7b() { r_has "$1" "SIDE escaped=1" && [ "$(r_rc "$1")" != 0 ]; }
arm_m8b_mut() { [ "$(r_rc "$1")" = 1 ] && r_has "$1" "produced ZERO scored receipts"; }
arm_m8c_mut() { [ "$(r_rc "$1")" = 0 ]; }
arm_m8e_mut() { [ "$(r_rc "$1")" != 0 ] && ! grep -qE '^FAIL: UNRECOGNISED.BL-851' "$REC/$1.out" && r_has "$1" "unrecognised-value arm did not name"; }
arm_m8d_mut() { [ "$(r_rc "$1")" = 0 ] && grep -q ' R2 declared-empty$' "$REC/$1.out"; }
arm_m12() { [ "$(r_cls "$1" BL-807)" != "PROSE-CLOSABLE" ] && ! { [ "$(r_rc "$1")" = 0 ] && [ -z "$(r_cls "$1" BL-807)" ]; }; }
arm_m13() { [ "$(r_cls "$1" BL-807)" != "PROSE-CLOSABLE" ] && ! { [ "$(r_rc "$1")" = 0 ] && [ -z "$(r_cls "$1" BL-807)" ]; }; }
arm_m14b() { [ "$(r_rc "$1")" = 0 ]; }
arm_m15() { [ "$(r_rc "$1")" != 0 ]; }
arm_m15b() { [ "$(r_rc "$1")" != 0 ] && r_has "$1" "produced a verdict"; }
arm_m16() { ! r_has "$1" "SIDE porc=0" && r_has "$1" "SIDE porc=" && ! { [ "$(r_rc "$1")" != 0 ] && r_has "$1" "working tree changed"; }; }
arm_m17() { [ "$(r_rc "$1")" != 0 ] && ! r_has "$1" "OK: validate-backlog-receipts" && r_has "$1" "not UNSTABLE"; }
arm_m18() { ! { [ "$(r_rc "$1")" = 2 ] && r_has "$1" "SELF-PROBE FAILED"; } && r_has "$1" "SIDE tree_complete=gone"; }
arm_gitdir_mutant() { { [ "$(r_rc "$1")" != 0 ] && r_has "$1" "OUT-OF-POPULATION"; } || r_has "$1" "SIDE hookspath=changed"; }
arm_m_loose() { [ "$(r_rc "$1")" = 2 ] && r_has "$1" "SELF-PROBE FAILED" && r_has "$1" "BL-632" && ! r_has "$1" "OK: validate-backlog-receipts"; }
arm_m_heading_only() { [ -z "$(r_cls "$1" BL-851)" ] && [ "$(r_cls "$1" BL-850)" = "PROSE-CLOSABLE" ] && grep -qE '^SUMMARY entries=1 sh-receipts=1 ' "$REC/$1.out"; }
# The three memo halves, one arm per (drive, expected cells). A capture holds a NONE line and, only
# under --matrix, a CALLER line.
arm_m_memo_unset() { r_line "$1" "NONE $LEAK_BOTH"; }
arm_m_memo_derive() { r_line "$1" "NONE $LEAK_PROBE"; }
arm_m_memo_name() { r_line "$1" "CALLER $LEAK_MEMO"; }
arm_memo_caller_both() { r_line "$1" "CALLER $LEAK_BOTH"; }
# The efficiency arms: a mutant is caught when the subject's own E0 self-probe refuses (exit 2) or,
# for the world-turned-green form, when the world red on the shipped subject exits 0.
ef_e0() { [ "$(r_rc "$1")" = 2 ] && r_has "$1" 'SELF-PROBE FAILED -- E0'; }
arm_m_noclose() { ef_e0 "$1" || [ "$(r_rc "$1")" = 0 ]; }
arm_m_widenostep() { ef_e0 "$1" || [ "$(r_rc "$1")" = 0 ]; }
arm_m_noseat() { ef_e0 "$1" || [ "$(r_rc "$1")" = 0 ]; }
arm_m_seatword() { ef_e0 "$1" || [ "$(r_rc "$1")" = 0 ]; }
arm_m_nofiling() { ef_e0 "$1" || [ "$(r_rc "$1")" = 0 ]; }
arm_m_nopathnarrow() { ef_e0 "$1" || { [ "$(r_rc "$1")" = 1 ] && r_has "$1" "SIDE rows=SHAPE BL-979|"; }; }
arm_m_noscript() { ef_e0 "$1"; }
arm_m_nofigs() { ef_e0 "$1"; }
arm_m_nostep() { ef_e0 "$1"; }
arm_m_nobaseline() { ef_e0 "$1"; }
arm_m_nomovement() { ef_e0 "$1"; }
arm_m_noscope() { ef_e0 "$1"; }
# The BL-836 corpus mutants. The wanted rows and the self-probe target a mutant names are set by
# c5_mut at its call, keyed by the mutant, so each arm reads the values its own call states.
c5_arm() { # c5_arm <capture> <mutant key>
  local c="$1" k="$2" w t
  eval "w=\${C5WANT_$k:-unset}; t=\${C5TARGET_$k:-}"
  if r_has "$c" "SELF-PROBE FAILED"; then
    [ -z "$t" ] && return 0
    grep -F 'SELF-PROBE FAILED' "$REC/$c.out" | grep -qF "seed $t:"; return
  fi
  r_line "$c" "SIDE rows=$w"
}
for _k in c5_m1 c5_m2 c5_m3 c5_m5 c5_m6 c5_m7 c5_m8 c5_m9 c5_m10 c5_m11 c5_m12; do
  eval "arm_$_k() { c5_arm \"\$1\" $_k; }"
done
# c5-m4: the sentinel ignored on entry. The bounded seed (depth cap 1) runs the receipt once under
# the control and twice when the inner run re-executes it instead of skipping.
arm_c5_m4() { r_line "$1" "SIDE rows=R8:BL-864, R7:" && r_line "$1" "SIDE runs=2"; }
# The same mutation over an OPEN receipt, a matrix-only cell (see c5-m4-open below).
arm_c5_open() {
  local c="$1" runs ctl row
  runs="$(sed -n 's/^SIDE runs=//p' "$REC/$c.out" | sed -n '1p')"
  ctl="$(sed -n 's/^SIDE ctlruns=//p' "$REC/$c.out" | sed -n '1p')"
  row="$(sed -n 's/^SIDE row=//p' "$REC/$c.out" | sed -n '1p')"
  [ -n "$runs" ] && [ -n "$ctl" ] || return 1
  r_has "$c" "SELF-PROBE FAILED" && return 1
  [ "$runs" -gt "$ctl" ] || return 1
  case "$row" in "ALREADY-PASSING|"*) return 1 ;; esac
  return 0
}
# Every arm, derived from the functions above.
all_arms() { declare -F | awk '$3 ~ /^arm_/ { sub(/^arm_/, "", $3); print $3 }'; }

# --- the seed ---------------------------------------------------------------
# A throwaway REPOSITORY, because the subject checks each receipt out of HEAD. A plain
# directory would make every receipt exit 2 for a reason no probe here is about.
#
# THE LEDGER'S SIX RECEIPTS ARE SIX BRANCHES OF THE SCORER, and each names a different
# subject file so no two probes can cover each other:
#   BL-801  greps a literal        -> PROSE-CLOSABLE   (the finding)
#   BL-802  drives a script        -> BOUND            (the near-miss)
#   BL-803  exits 9 at a guard     -> OUT-OF-POPULATION
#   BL-804  pattern from a var     -> UNSCORABLE
#   BL-805  base 0                 -> ALREADY-PASSING  (a 0 -> 1 flip is not a finding)
#   BL-806  reads git              -> PROSE-CLOSABLE, and its base exit proves the checkout
#                                     is a real repository rather than a bare extraction
#   BL-807  TWO files, TWO greps   -> PROSE-CLOSABLE only when EVERY path is seeded and EVERY
#                                     literal is extracted
#   BL-808  exit 9 then exit 1     -> UNSTABLE, never OUT-OF-POPULATION
#
# BL-808 COUNTS THROUGH A FILE OUTSIDE THE CHECKOUT, and it has to: each reading gets its own
# fresh tree, so state kept inside one cannot reach the next and the receipt could not differ
# between them. Its counter is initialised to a literal `0` rather than truncated -- an EMPTY
# file makes `$(cat)` yield the empty string, which is not `0`, so the first-reading branch
# never fires and the seeded non-determinism is not non-deterministic. Measured while building
# this: the probe read stable-at-1 and the arm it exists to exercise went untested while every
# other probe passed.
#
# BL-807 EXISTS BECAUSE EVERY OTHER RECEIPT HERE NAMES ONE FILE AND CARRIES ONE GREP, WHICH
# MAKES TWO WHOLE CLASSES OF WRONG SCORER INVISIBLE. A scorer that seeds only the first named
# path, and one that extracts only the first grep, satisfy every single-subject probe above --
# and on the real ledger they take a correct nine findings to six and to three, silently, in
# the direction that reads as a cleaner ledger. Neither literal is present at base, so the
# receipt reproduces at 1 and can only reach 0 when both halves of the seed arrive.
seed() { # seed <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile" "$d/probe"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-backlog-receipts.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$REVSRC" "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
  # The F-STEP vocabulary: the real extractor, and three step basenames (a main step, the gate,
  # and a SUBPROC sub-procedure the vocabulary must drop).
  mkdir -p "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts" "$d/core/skills/ai-dlc/steps"
  cp "$EXTRACT" "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"
  : > "$d/core/skills/ai-dlc/steps/implementation.md"
  : > "$d/core/skills/ai-dlc/steps/gate-validation.md"
  : > "$d/core/skills/ai-dlc/steps/_gate-procedures.md"
  # R2's declared-empty exemption asks the classifier, so every seed carries it; a seed without it
  # turns every zero-entry probe into an environment exit 2.
  [ -n "$REVERIFY" ] && cp "$REVERIFY" "$d/scripts/backlog-reverify.sh"
  # The could-not-measure rule both programs source from beside themselves.
  cp "$RLIB" "$d/scripts/backlog-receipt-lib.sh"
  printf 'alpha\nbeta\n' > "$d/probe/subject.txt"
  printf 'gamma\n' > "$d/probe/driven.txt"
  printf 'delta\n' > "$d/probe/guarded.txt"
  printf 'epsilon\n' > "$d/probe/varpat.txt"
  printf 'zeta\n' > "$d/probe/passing.txt"
  printf 'eta\n' > "$d/probe/gitsub.txt"
  # BL-807's two subjects. Neither carries its own literal, so the receipt reproduces at 1.
  printf 'theta\n' > "$d/probe/one.txt"
  printf 'iota\n' > "$d/probe/two.txt"
  printf '#!/usr/bin/env bash\nprintf %%s\\\\n WAIT\n' > "$d/probe/tool.sh"
  bl_seed_ledger "$d/docs/backlog.md"
  # A literal 0, never a truncation -- see BL-808's note above.
  printf 0 > "$BL_UNSTABLE_COUNTER"
  (
    cd "$d" && git init -q . >/dev/null 2>&1 \
      && git add -A >/dev/null 2>&1 \
      && git -c user.email=p@local -c user.name=p commit -q -m seed >/dev/null 2>&1
  )
  # ASSERT THE REPOSITORY EXISTS rather than assuming `git init` worked: under an inherited
  # GIT_DIR it exits 0 and creates nothing, and every probe would then run against the caller.
  [ -d "$d/.git" ] || { echo "FIXTURE BROKEN: the probe repository at $d has no .git" >&2; exit 2; }
}

bl_seed_ledger() { # bl_seed_ledger <file>
  {
    printf '# Probe backlog\n\nPreamble prose mentioning BL- ids.\n\n'
    printf '## BL-801\n\nBody.\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'MARK801'"
    printf '## BL-802\n\nBody.\n\nverify: sh o="$(bash probe/tool.sh)"; grep -q %s <<<"$o"\n\n' "'READY802'"
    printf '## BL-803\n\nBody.\n\nverify: sh grep -q %s probe/guarded.txt || exit 9\n\n' "'MARK803'"
    printf '## BL-804\n\nBody.\n\nverify: sh S=%s; grep -q "$S" probe/varpat.txt\n\n' "MARK804"
    printf '## BL-805\n\nBody.\n\nverify: sh ! grep -q %s probe/passing.txt\n\n' "'MARK805'"
    printf '## BL-806\n\nBody.\n\nverify: sh git rev-parse HEAD >/dev/null 2>&1 || exit 9; grep -q %s probe/gitsub.txt\n\n' "'MARK806'"
    printf '## BL-807\n\nBody.\n\nverify: sh grep -q %s probe/one.txt && grep -q %s probe/two.txt\n\n' "'MARK807A'" "'MARK807B'"
    printf '## BL-808\n\nBody.\n\nverify: sh C="$BL_UNSTABLE_COUNTER"; n=$(cat "$C" 2>/dev/null || echo 0); printf %%s $((n+1)) > "$C"; [ "$n" = "0" ] && exit 9; exit 1\n\n'
  } > "$1"
}

# The subject takes a whitespace-separated env list because some probes pin a ceiling. The
# split is the point of the function, not an oversight.
# shellcheck disable=SC2086
# `--max-cannot-measure 99` FIRST, so any probe's own argv can still pin it lower (the last flag
# wins). Every seed here carries `|| exit 9` receipts on purpose, and R7 (BL-836) ships at 0; the
# arms above R7's own (c5-*, which drive the subject without run_v) are about other ceilings.
run_v() { # run_v <env-string-or-empty> <dir> [<extra-args>...]
  local e="$1" d="$2"; shift 2
  ( cd "$d" && env $e bash scripts/validate-backlog-receipts.sh --max-cannot-measure 99 "$@" 2>&1 )
}

# The default arguments every probe uses unless it is pinning something. The seeded ledger has
# THREE prose-closable receipts -- BL-801, BL-806 and BL-807 -- so 3 is the AT-the-ceiling
# passing state and 2 is one over. Both sides are exercised, because an off-by-one written as
# `-ge` is green on the failing side alone.
BL_PC=3
# The floor pair tracks the SEED: seven entries, each carrying one `sh` receipt. Both numbers
# move with `bl_seed_ledger` and a stale pair makes the floor unable to fire -- measured, when
# BL-807 was added and this still read 6, m10's evasion dropped the count to exactly the floor
# and the probe came back SURVIVED.
BL_N=8

# BL-808's counter, outside every checkout and reset by `seed` so each probe's tree starts at
# a first reading. Exported because the receipt reads it by name through `eval`.
BL_UNSTABLE_COUNTER="$TMP/unstable.counter"
export BL_UNSTABLE_COUNTER
# `--max-unstable 1` because the seed carries BL-808 deliberately. The SHIPPED default is 0,
# which m17b asserts against this same seed -- so the flag here parameterises a probe corpus
# rather than relaxing the standard.
DEF="--max-prose-closable $BL_PC --max-unscorable 9 --max-out-of-population 9 --max-unstable 1 --min-sh-receipts $BL_N --min-entries $BL_N"

# Reads a receipt's classification back out of the subject's OWN row grammar. Empty if the
# subject never classified it, which every caller treats as a failure rather than as a zero.
cls() { # cls <output> <id>
  printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$2 == id { print $1 }' | sed -n '1p'
}

# THE STRONGEST ASSERTION IN THIS FILE, AND IT IS NOT A KILL. A battery that only asserts "the
# subject stayed quiet" cannot tell a scorer that classified six receipts correctly from one
# that classified two and missed four -- both are silent at a slack ceiling. Asserting the
# CLASSIFICATION of every seeded receipt catches every one of those in one comparison, and the
# fixture never restates the predicate: it reads the subject's own rows back.
class_check() { # class_check <name> <dir> <env> [<extra-args>...]
  local n="$1" d="$2" e="$3"; shift 3
  local out rc_v bad=""
  out="$(run_v "$e" "$d" $DEF "$@")"; rc_v=$?
  # Handed back, so arms asking a question about the SAME world read this run instead of paying
  # for an identical one (see the control below).
  CC_OUT="$out"; CC_RC="$rc_v"
  if [ "$rc_v" -ne 0 ]; then
    note "FAIL  $n -- the subject exited $rc_v on a tree that must pass"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  if ! grep -qF "OK: validate-backlog-receipts" <<<"$out"; then
    note "FAIL  $n -- no OK line, so the subject observed nothing and the quiet is not a reading"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  for want in "BL-801=PROSE-CLOSABLE" "BL-803=OUT-OF-POPULATION" \
              "BL-804=UNSCORABLE" "BL-805=ALREADY-PASSING" "BL-806=PROSE-CLOSABLE" \
              "BL-807=PROSE-CLOSABLE" "BL-808=UNSTABLE"; do
    id="${want%%=*}"; exp="${want#*=}"; got="$(cls "$out" "$id")"
    [ "$got" = "$exp" ] || bad="$bad $id(want=$exp got=${got:-NONE})"
  done
  # BL-802 IS ASSERTED BY ITS ABSENCE FROM THE ROWS AND ITS PRESENCE IN THE COUNT, because a
  # BOUND receipt is deliberately not reported by name -- naming every honest receipt would
  # bury the findings. Absence alone would be satisfied by a subject that never scored it at
  # all, so the count from the subject's own OK line is asserted too, and it is the conjunct
  # that a dropped receipt fails.
  [ -z "$(cls "$out" BL-802)" ] || bad="$bad BL-802(a bound receipt must not be reported by name, got $(cls "$out" BL-802))"
  local nbound
  nbound="$(printf '%s\n' "$out" | sed -n 's/^SUMMARY .*bound=\([0-9][0-9]*\) .*/\1/p')"
  [ "${nbound:-0}" -eq 1 ] || bad="$bad bound-count(want=1 got=${nbound:-NONE})"
  if [ -n "$bad" ]; then
    note "FAIL  $n -- the subject misclassified:$bad"
    rc=1; return
  fi
  note "ok    $n -- all six seeded receipts classified as the seed wrote them"
}

kill_check() { # kill_check <name> <dir> <env> <nfail> <substr> [<extra-args>...]
  KC_OK=0
  local n="$1" d="$2" e="$3" want="$4" pat="$5"; shift 5
  local out rc_v nfail
  out="$(run_v "$e" "$d" $DEF "$@")"; rc_v=$?
  nfail="$(printf '%s\n' "$out" | grep -c '^FAIL:')"
  if [ "$rc_v" -eq 0 ]; then note "FAIL  $n -- probe SURVIVED (the subject exited 0)"; rc=1; return; fi
  if [ "$rc_v" -eq 2 ]; then
    note "FAIL  $n -- the subject exited 2 (environment/self-probe), which is not this probe's assertion"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1; return
  fi
  if ! grep -qF "$pat" <<<"$out"; then
    note "FAIL  $n -- the subject failed, but not on this probe's assertion (wanted: $pat)"
    printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1; return
  fi
  if [ "$nfail" -ne "$want" ]; then
    note "FAIL  $n -- $nfail FAIL lines, expected $want"
    printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/      /' | head -4; rc=1; return
  fi
  KC_OK=1; note "ok    $n -- caught by its own assertion, and by exactly that many"
}

# mut <dir> <sed-expression> -- mutate the seeded copy of the subject IN PLACE and assert the
# edit applied. A `sed` that matched nothing is a mutant that never existed, and its "survived"
# reads exactly like a guard that does not work.
mut() { # mut <dir> <sed-expr>
  # TWO STATEMENTS, NOT ONE. `local` is a COMMAND, so every word on its line is expanded
  # before any of its assignments takes effect -- `local d="$1" f="$d/x"` reads `$d` from the
  # enclosing scope, which under `set -u` is an unbound-variable abort with no verdict.
  local d="$1" expr="$2"
  local f="$d/scripts/validate-backlog-receipts.sh"
  cp "$f" "$f.orig"
  sed "$expr" "$f.orig" > "$f" || { note "FAIL  mutation sed DIED, so no mutant exists"; rc=1; rm -f "$f.orig"; return 1; }
  if cmp -s "$f" "$f.orig"; then
    note "FAIL  the mutation was a NO-OP: the subject is byte-identical, so any verdict below means nothing"
    rc=1; rm -f "$f.orig"; return 1
  fi
  rm -f "$f.orig"
  return 0
}

# --- unmutated control ------------------------------------------------------
# ONE RUN, FOUR MORE ARMS READ IT. m2a (AT the ceiling), m3b (BL-806's class), m7 (the caller's
# tree unchanged) and m17c (BL-803's class) each used to seed this same tree and drive the same
# unmutated subject with the same $DEF -- a byte-identical world, so a byte-identical answer, paid
# for five times. Each still emits its own verdict by name, below, from this run's output (CTL_OUT)
# and from m7's before/after snapshots taken around it.
seed "$TMP/control"
m7_porc_before="$(git -C "$TMP/control" status --porcelain | grep -c . )"
m7_wt_before="$(git -C "$TMP/control" worktree list | grep -c . )"
m7_sum_before="$(cksum "$TMP/control/probe/subject.txt" | awk '{print $1}')"
CC_OUT=""; CC_RC=1
class_check "control -- clean seed passes and every receipt is classified" "$TMP/control" ""
CTL_OUT="$CC_OUT"; CTL_RC="$CC_RC"; CTL_OK="$rc"
m7_porc_after="$(git -C "$TMP/control" status --porcelain | grep -c . )"
m7_wt_after="$(git -C "$TMP/control" worktree list | grep -c . )"
m7_sum_after="$(cksum "$TMP/control/probe/subject.txt" | awk '{print $1}')"

# The control above is the harness's liveness proof. If it did not hold, every mutant below
# would be scored against a subject that never ran, and two inert runs compare equal.
if [ "$rc" -ne 0 ]; then
  note "FIXTURE BROKEN: the unmutated control did NOT pass. Every probe verdict below is meaningless."
  exit 1
fi
B_CTRL=1
record control "$CTL_RC" "ARGS $DEF
$CTL_OUT"

# ===== M1. THE SEED DROPS THE RECEIPT'S OWN TOKENS. ========================================
# A generic comment flips nothing -- measured at zero of the live receipts -- so a subject
# seeding one is an arm that cannot fire, reading exactly like a clean ledger. Its own R1
# self-probe must refuse before the corpus is reached, which is why the assertion is exit 2
# and a SELF-PROBE message, not a changed count.
seed "$TMP/m1"
if mut "$TMP/m1" 's|^  GENERIC_LINE="# probe"|  GENERIC_LINE="# probe"; SEED_LINE="# probe"|'; then
  drive m1 "$TMP/m1" "" $DEF
  score m1 "$B_CTRL" "m1 -- a token-free seed is refused by the self-probe, before the corpus"
fi

# ===== M2. THE CEILING COMPARISON IS `-ge`. ================================================
# "exceeds the ceiling" means a corpus AT the ceiling is legal. Both directions are asserted in
# the same probe: an off-by-one is green on the failing side alone.
# m2a is the control's own world ($DEF pins the ceiling AT $BL_PC), so it reads the control's run.
if [ "$CTL_OK" -eq 0 ] && [ "$CTL_RC" -eq 0 ]; then
  note "ok    m2a exactly AT the ceiling ($BL_PC) passes -- the control's run: all six seeded receipts classified as the seed wrote them"
else
  note "FAIL  m2a exactly AT the ceiling ($BL_PC) -- the control's run did not pass"; rc=1
fi
seed "$TMP/m2b"
kill_check "m2b one OVER the ceiling ($(( BL_PC - 1 ))) fails" "$TMP/m2b" "" 1 \
  "are satisfied by a COMMENT" --max-prose-closable "$(( BL_PC - 1 ))"
seed "$TMP/m2c"
if mut "$TMP/m2c" 's|^if \[ "$N_PC" -gt "$MAX_PC" \]; then|if [ "$N_PC" -ge "$MAX_PC" ]; then|'; then
  drive m2c "$TMP/m2c" "" $DEF
  score m2c "$B_CTRL" "m2c -- an off-by-one at the ceiling is caught by the AT-the-ceiling case"
fi

# ===== M3. A BASE EXIT OF 9 IS COUNTED AS POPULATION. ======================================
# A receipt that never reached its question is not reproducing, and seeding it scores a flip
# that is not about prose. THIS MUTANT HAS A SUBJECT ONLY BECAUSE THE CHECKOUT IS A REAL
# REPOSITORY: BL-806 reads git and its base exit proves it, which m3b asserts directly.
#
# IT IS KILLED BY THE SUBJECT'S OWN SELF-PROBE AND NOT BY THE CORPUS, and that is the stronger
# kill rather than a weaker one: the subject REFUSES (exit 2, nothing reported) instead of
# publishing a count computed over the wrong population. The probe asserts the refusal names
# the exit-9 receipt, so an unrelated exit 2 cannot score here.
seed "$TMP/m3"
if mut "$TMP/m3" 's|^  if \[ "$BASE_RC" -ne 0 \] && \[ "$BASE_RC" -ne 1 \]; then|  if false; then|'; then
  drive m3 "$TMP/m3" "" $DEF
  score m3 "$B_CTRL" "m3 -- with the exclusion gone the exit-9 receipt is scored, and the self-probe refuses before any corpus count"
fi

# m3b -- THE EXTRACTION IS FAITHFUL, asserted directly rather than inferred. A `git archive`
# extraction has no `.git`, and BL-806's receipt would exit 9 there and be excluded -- the
# population would be silently wrong and every count below it computed over the wrong set.
# The control's world and arguments, so the control's run is read rather than repeated.
m3b_out="$CTL_OUT"
m3b_806="$(cls "$m3b_out" BL-806)"
if [ "$m3b_806" != "PROSE-CLOSABLE" ]; then
  note "FAIL  m3b the checkout is not a faithful repository -- the git-reading receipt was classified '${m3b_806:-NONE}', not PROSE-CLOSABLE. Its guard exits 9 where there is no .git, so the whole git-reading population would be silently excluded."
  rc=1
else
  note "ok    m3b -- a receipt that runs git has base exit 1 in the checkout, so the subject tree is a real repository"
fi

# ===== M4. A 0 -> 1 FLIP IS COUNTED AS A FINDING. ==========================================
# BL-805 passes at base and the token seed drives it to 1. That is a receipt a comment BREAKS,
# a different defect with an unrelated remedy, and counting it inflates the ratchet with
# entries nobody can discharge.
seed "$TMP/m4"
if mut "$TMP/m4" 's|^    wr ALREADY-PASSING "base-exit=$BASE_RC-seed-exit=$SEED_RC"|    wr PROSE-CLOSABLE "base-exit=$BASE_RC-seed-exit=$SEED_RC"|'; then
  drive m4 "$TMP/m4" "" $DEF
  score m4 "$B_CTRL" "m4 -- counting a 0 -> 1 flip moves the count and breaks the ceiling, so the direction is load-bearing"
fi

# ===== M5. THE SEED SKIPS ITS `cmp -s` APPLIED-CHECK. ======================================
# A seed that changed nothing is a no-op whose "no flip" is indistinguishable from a receipt
# that resisted it. The probe makes one subject file UNWRITABLE in the checkout -- through the
# probe repository's own post-checkout hook, because git records no mode beyond the executable
# bit -- so the append genuinely fails and the guard has a real subject.
seed "$TMP/m5"
mkdir -p "$TMP/m5/.probehooks"
{ echo '#!/usr/bin/env bash'
  echo '[ -f probe/subject.txt ] && chmod 444 probe/subject.txt'
  echo 'exit 0'
} > "$TMP/m5/.probehooks/post-checkout"
chmod +x "$TMP/m5/.probehooks/post-checkout"
# SCRUBBED AT THE CALL, not only at the top of this file. Line 60 unsets the repository
# environment for THIS process, which is enough while nobody re-exports it -- but the arm below
# deliberately DOES, to drive the subject under an inherited GIT_DIR, and `git -C` does not
# override that variable for reads or for writes. Scrubbing here makes the site correct however
# the surrounding file evolves, rather than correct-by-distance from one unset.
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  git -C "$TMP/m5" config core.hooksPath "$TMP/m5/.probehooks" )
# Read BY PATH: a read through GIT_DIR would confirm the write by consulting the repository the
# write may wrongly have gone to.
[ "$(git config --file "$TMP/m5/.git/config" --get core.hooksPath 2>/dev/null)" = "$TMP/m5/.probehooks" ] || {
  note "FAIL  m5 -- the probe repository's own .git/config does not carry core.hooksPath, so its unwritable-subject seed has no subject and the UNSEEDED assertion below would pass for the wrong reason."
  rc=1; }
m5_base="$(run_v "" "$TMP/m5" $DEF)"
m5_801="$(cls "$m5_base" BL-801)"
if [ "$m5_801" != "UNSEEDED" ]; then
  note "FAIL  m5 -- with its subject unwritable the literal-grep receipt was classified '${m5_801:-NONE}', not UNSEEDED. An unapplied seed must be reported as unseeded; reported as 'no flip' it is a silent acquittal."
  rc=1
else
  note "ok    m5 -- a seed that could not be applied is reported UNSEEDED, not read as a bound receipt"; B_M5=1
fi
# ...and the mutant: with the applied-check gone, that same receipt must stop being UNSEEDED.
if mut "$TMP/m5" 's|^      if cmp -s "$_st_d/$_p" "$_st_d/$_p.brpre"; then|      if false; then|'; then
  drive m5b "$TMP/m5" "" $DEF
  side m5b "world=unwritable"
  score m5b "${B_M5:-0}" "m5b -- without cmp -s the unapplied seed is no longer reported UNSEEDED, so the guard is what catches it"
fi

# ===== M6. THE PATH-SPLIT CLASS DRIFTS BETWEEN ITS TWO COPIES. =============================
# The class exists in two files by necessity, and a drift is silent in both directions at
# once. The subject must REFUSE (exit 2), not score a corpus with an unbound grammar.
#
# THE DRIFT IS SEEDED IN THE BOUND FILE, NOT IN THE SUBJECT. Mutating the subject's own
# `PATH_CLASS` trips its R0 self-probe first -- correctly, since that probe asserts the
# comparator accepts an unmutated class -- and the run then refuses for a reason that is not
# the drift. Editing the OTHER copy is the state R0 exists to catch and the one a real drift
# produces, and it reaches R0's corpus arm rather than its probe.
seed "$TMP/m6"
m6_rev="$TMP/m6/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
cp "$m6_rev" "$m6_rev.orig"
# AWK, NOT SED, BECAUSE THE SUBJECT LINE CONTAINS A PIPE. Every `sed` delimiter that is
# comfortable here (`|`, `/`, `,`) occurs inside the text being matched, and `s|...|` with an
# unescaped pipe in the pattern is a `bad flag in substitute command` -- which exits non-zero
# and leaves an EMPTY target file, so the drift the probe wanted becomes a missing function and
# R0 refuses for the wrong reason. Measured exactly that way on this probe's first cut.
awk '
  index($0, "receipt_path_tokens() {") == 1 && index($0, "A-Za-z0-9_./$-") > 0 {
    sub(/A-Za-z0-9_\.\/\$-/, "A-Za-z0-9_.-"); print; next
  }
  { print }
' "$m6_rev.orig" > "$m6_rev"
if cmp -s "$m6_rev" "$m6_rev.orig"; then
  note "FAIL  m6 -- the drift mutation was a NO-OP, so any verdict below means nothing"; rc=1
else
  drive m6 "$TMP/m6" "" $DEF
  score m6 "$B_CTRL" "m6 -- a drifted path-split class is refused with exit 2, naming both copies"
fi
rm -f "$m6_rev.orig"

# m6b -- R0's NEAR-MISS TWIN, and without it m6 proves nothing. An R0 that refused ANY edit to
# either file would be as useless as one that never refuses: an unrelated change to
# ledger-reverify.sh must leave the subject reporting normally.
seed "$TMP/m6b"
m6b_rev="$TMP/m6b/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
cp "$m6b_rev" "$m6b_rev.orig"
printf '\n# an unrelated comment appended by the fixture\n' >> "$m6b_rev"
if cmp -s "$m6b_rev" "$m6b_rev.orig"; then
  note "FAIL  m6b -- the near-miss edit was a NO-OP, so its quiet proves nothing"; rc=1
else
  class_check "m6b an unrelated edit to the bound file is NOT a drift" "$TMP/m6b" ""
fi
rm -f "$m6b_rev.orig"

# ===== M7. THE SUBJECT RUNS AGAINST THE WORKING TREE. ======================================
# Two assertions, because they fail differently: the caller's tree must be unchanged, and the
# seed must not be visible in it afterwards. A subject that seeded in place would leave the
# receipt's own literal in a probe file.
# The control's world, so its snapshots were taken around the control's run (see the control).
m7_out="$CTL_OUT"; m7_rc="$CTL_RC"
if [ "$m7_rc" -ne 0 ]; then
  note "FAIL  m7 -- the subject exited $m7_rc on a tree that must pass, so nothing about its writes is established"
  printf '%s\n' "$m7_out" | sed 's/^/      /' | head -4; rc=1
elif [ "$m7_porc_after" -ne "$m7_porc_before" ]; then
  note "FAIL  m7 the seed escaped -- the probe repo went from $m7_porc_before to $m7_porc_after dirty paths"; rc=1
elif [ "$m7_sum_after" != "$m7_sum_before" ]; then
  note "FAIL  m7 the seed escaped -- probe/subject.txt changed on disk, so a receipt was scored against a tree the arm had written"; rc=1
elif [ "$m7_wt_after" -ne "$m7_wt_before" ]; then
  note "FAIL  m7 checkouts leaked -- the probe repo has $m7_wt_after registered worktrees, was $m7_wt_before. Each is removed on every exit path or the repository fills with them."; rc=1
else
  note "ok    m7 -- the caller's tree, its files and its worktree registry are all unchanged across a run"
fi

# m7b -- THE OFFENDER TWIN. Without it, "the seed is confined" and "the subject never seeded
# anything" are the same green: m7 asserts an ABSENCE, and an absence passes for a program
# that never wrote anywhere. This makes the subject seed the SUBJECT ROOT -- the probe repo's
# own working tree -- and m7's two assertions must then both fire.
#
# THE MUTATION IS ON THE SEED HELPER'S TARGET, NOT ON ITS CALL. Replacing the call's result
# with `$SR` leaves `seed_tree` still creating and writing a checkout, so the escape would be
# partial and the arm would be scoring a shape nobody ships. Redirecting the helper's own
# target directory is the whole of the property: every append it makes then lands in the
# caller's tree.
seed "$TMP/m7b"
if mut "$TMP/m7b" 's|^    _st_d="$(mktree "$1")"|    _st_d="$SR"|'; then
  m7b_sum_before="$(cksum "$TMP/m7b/probe/subject.txt" | awk '{print $1}')"
  drive m7b "$TMP/m7b" "" $DEF
  m7b_sum_after="$(cksum "$TMP/m7b/probe/subject.txt" | awk '{print $1}')"
  m7b_porc="$(git -C "$TMP/m7b" status --porcelain | grep -c . )"
  if [ "$m7b_sum_after" != "$m7b_sum_before" ] || [ "$m7b_porc" -gt 0 ]; then side m7b "escaped=1"; else side m7b "escaped=0"; fi
  score m7b "$B_CTRL" "m7b -- with the seed redirected at the caller's tree it DOES escape and the subject refuses, so m7's silence is a measurement"
fi

# ===== M8. A ZERO POPULATION EXITS 0. ======================================================
# An empty parse, a fully-rotated ledger and a corpus of perfectly bound receipts all print
# the same zero. A ceiling that passes over it has stopped observing anything.
seed "$TMP/m8"
printf '# Probe backlog\n\nEntries were renamed to a shape the predicate does not know.\n\n## BACKLOG-001\n\nBody.\n' \
  > "$TMP/m8/docs/backlog.md"
( cd "$TMP/m8" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m empty >/dev/null 2>&1 )
kill_check "m8 a ledger that parses to ZERO receipts is a finding" "$TMP/m8" "" 1 \
  "produced ZERO scored receipts"

# ===== M8b. EVERY LIVE RECEIPT ALREADY PASSING IS AN OBSERVATION, NOT A ZERO. ===============
# A release that fixes the last live receipt leaves a ledger whose only `sh` receipt exits 0 at
# HEAD: scored is 0 because nothing is open, and every receipt WAS run and read. It must pass and
# say so; m8 above is the near-miss, where nothing was run at all.
seed "$TMP/m8b"
printf '# Probe backlog\n\n## BL-805\n\nBody.\n\nverify: sh ! grep -q %s probe/passing.txt\n\n' "'MARK805'" > "$TMP/m8b/docs/backlog.md"
( cd "$TMP/m8b" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m allpass >/dev/null 2>&1 )
M8B_ARGS="--max-prose-closable 0 --max-unscorable 0 --max-out-of-population 0 --max-unstable 0 --min-sh-receipts 1 --min-entries 1"
# shellcheck disable=SC2086
m8b_out="$(run_v "" "$TMP/m8b" $M8B_ARGS)"; m8b_rc=$?
if [ "$m8b_rc" -eq 0 ] && grep -q '^OK: validate-backlog-receipts.* R2 all-already-passing$' <<<"$m8b_out" \
   && [ "$(cls "$m8b_out" BL-805)" = ALREADY-PASSING ]; then
  note "ok    m8b -- a ledger whose only receipt already passes is OK and says R2 all-already-passing"; B_M8B=1
else
  note "FAIL  m8b -- a ledger whose only receipt already passes must pass and say so (rc=$m8b_rc)"
  printf '%s\n' "$m8b_out" | grep -E '^(FAIL|OK):' | sed 's/^/      /' | head -3; rc=1
fi
# ...and its mutant: the old condition restored, the same ledger must refuse as a zero.
if mut "$TMP/m8b" 's|^if \[ "$SCORED" -eq 0 \] \&\& \[ "$N_PASS" -eq 0 \] \&\& \[ -z "$R2_ALLMANUAL" \] \&\& \[ -z "$R2_DECLEMPTY" \] \&\& \[ -z "$R2_ALLDRIVER" \]; then|if [ "$SCORED" -eq 0 ]; then|'; then
  # shellcheck disable=SC2086
  drive m8b-mut "$TMP/m8b" "" $M8B_ARGS
  score m8b-mut "${B_M8B:-0}" "m8b-mut -- the old R2 condition refuses an all-already-passing ledger as a zero"
fi

# ===== M8c. EVERY LIVE ENTRY DECLARING `verify: manual` IS ACCOUNTED FOR, NOT A ZERO. ========
# A release that closes the last `sh`-receipted entry leaves a ledger whose every live entry
# says `verify: manual` by its own declaration: nothing CAN be scored, and each entry says why.
# It must pass and say `R2 all-manual`. Near-miss: the same ledger with one entry carrying NO
# receipt line is not accounted for entry by entry and must still refuse as a zero, so the
# exemption cannot be reached by deleting a receipt line (the escape R5 exists for).
seed "$TMP/m8c"
printf '# Probe backlog\n\n## BL-806\n\nBody.\n\nverify: manual -- close when observed\n\n## BL-807\n\nBody.\n\nverify: manual\n\n' > "$TMP/m8c/docs/backlog.md"
( cd "$TMP/m8c" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m allmanual >/dev/null 2>&1 )
M8C_ARGS="--max-prose-closable 0 --max-unscorable 0 --max-out-of-population 0 --max-unstable 0 --min-sh-receipts 0 --min-entries 1"
# shellcheck disable=SC2086
m8c_out="$(run_v "" "$TMP/m8c" $M8C_ARGS)"; m8c_rc=$?
if [ "$m8c_rc" -eq 0 ] && grep -q '^OK: validate-backlog-receipts.* R2 all-manual$' <<<"$m8c_out"; then
  note "ok    m8c -- a ledger whose every live entry declares verify: manual is OK and says R2 all-manual"
else
  note "FAIL  m8c -- an all-manual ledger must pass and say so (rc=$m8c_rc)"
  printf '%s\n' "$m8c_out" | grep -E '^(FAIL|OK):' | sed 's/^/      /' | head -3; rc=1
fi
seed "$TMP/m8cn"
printf '# Probe backlog\n\n## BL-806\n\nBody.\n\nverify: manual -- close when observed\n\n## BL-807\n\nBody, and no receipt line.\n\n' > "$TMP/m8cn/docs/backlog.md"
( cd "$TMP/m8cn" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m onemissing >/dev/null 2>&1 )
# shellcheck disable=SC2086
m8cn_out="$(run_v "" "$TMP/m8cn" $M8C_ARGS)"; m8cn_rc=$?
if [ "$m8cn_rc" -eq 1 ] && grep -qF "produced ZERO scored receipts" <<<"$m8cn_out"; then
  note "ok    m8c-near -- one live entry with no receipt line beside a manual one still refuses as a zero"; B_M8CN=1
else
  note "FAIL  m8c-near -- a ledger not accounted for entry by entry exited $m8cn_rc instead of refusing as a zero"; rc=1
fi
# ...and the mutant: the exemption keyed on ANY manual receipt rather than on every entry.
if mut "$TMP/m8cn" 's|\[ "${MANUAL_RECEIPTS:-0}" -eq "$ENTRIES" \] \&\& R2_ALLMANUAL=|[ "${MANUAL_RECEIPTS:-0}" -gt 0 ] \&\& R2_ALLMANUAL=|'; then
  # shellcheck disable=SC2086
  drive m8c-mut "$TMP/m8cn" "" $M8C_ARGS
  score m8c-mut "${B_M8CN:-0}" "m8c-mut -- keyed on any manual receipt, the near-miss ledger passes (rc=0) where the shipped condition refuses"
else
  note "FAIL  m8c-mut DID NOT APPLY"; rc=1
fi

# ===== M8e. A `verify:` VALUE THAT MATCHES NO RECEIPT FORM IS NAMED BY ENTRY ID. ==============
# `verify: manual. reason` carries a char after `manual` that is not a space, so it is neither
# `manual` nor `manual <reason>`; it used to fall through uncounted and R2 said only "ZERO".
# Offender BL-851 is named; near-misses BL-852 (`manual`) and BL-853 (`manual reason`) are not
# named and count as manual (so the all-manual ledger below still passes).
seed "$TMP/m8e"
printf '# Probe backlog\n\n## BL-851\n\nBody.\n\nverify: manual. no receipt shape fits\n\n## BL-852\n\nBody.\n\nverify: manual\n\n## BL-853\n\nBody.\n\nverify: manual reason\n\n## BL-854\n\nBody.\n\nverify: has VERSION "."\n\n' > "$TMP/m8e/docs/backlog.md"
( cd "$TMP/m8e" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m unrec >/dev/null 2>&1 )
M8E_ARGS="--max-prose-closable 0 --max-unscorable 0 --max-out-of-population 0 --max-unstable 0 --min-sh-receipts 0 --min-entries 1"
# shellcheck disable=SC2086
m8e_out="$(run_v "" "$TMP/m8e" $M8E_ARGS)"; m8e_rc=$?
if [ "$m8e_rc" -eq 1 ] && grep -qE '^FAIL: UNRECOGNISED.BL-851' <<<"$m8e_out" \
   && ! grep -qE 'UNRECOGNISED.BL-85[234]' <<<"$m8e_out"; then
  note "ok    m8e -- 'verify: manual.' is named by entry id; bare 'manual' and 'manual reason' are not"; B_M8E=1
else
  note "FAIL  m8e -- the unrecognised value must be named by id and the near-misses left alone (rc=$m8e_rc)"
  printf '%s\n' "$m8e_out" | grep -E '^(FAIL|OK):' | sed 's/^/      /' | head -4; rc=1
fi
seed "$TMP/m8en"
printf '# Probe backlog\n\n## BL-852\n\nBody.\n\nverify: manual\n\n## BL-853\n\nBody.\n\nverify: manual reason\n\n' > "$TMP/m8en/docs/backlog.md"
( cd "$TMP/m8en" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m nearmiss >/dev/null 2>&1 )
# shellcheck disable=SC2086
m8en_out="$(run_v "" "$TMP/m8en" $M8E_ARGS)"; m8en_rc=$?
if [ "$m8en_rc" -eq 0 ] && grep -q ' R2 all-manual$' <<<"$m8en_out" && ! grep -q UNRECOGNISED <<<"$m8en_out"; then
  note "ok    m8e-near -- 'manual' and 'manual reason' count as manual (R2 all-manual) and are never named"
else
  note "FAIL  m8e-near -- the near-miss ledger must pass as all-manual with no UNRECOGNISED row (rc=$m8en_rc)"
  printf '%s\n' "$m8en_out" | grep -E '^(FAIL|OK):' | sed 's/^/      /' | head -3; rc=1
fi
# m8e-drift: the classifier's `has|lacks)` arm renamed in the seeded copy must make the subject exit 2.
seed "$TMP/m8ed"
printf '# Probe backlog\n\n## BL-854\n\nBody.\n\nverify: has VERSION "."\n\n' > "$TMP/m8ed/docs/backlog.md"
( cd "$TMP/m8ed" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m drift >/dev/null 2>&1 )
m8ed_f="$TMP/m8ed/scripts/backlog-reverify.sh"
if [ -f "$m8ed_f" ] && sed 's/has|lacks)/hasx|lacks)/' "$m8ed_f" > "$m8ed_f.new" && ! cmp -s "$m8ed_f" "$m8ed_f.new"; then
  mv "$m8ed_f.new" "$m8ed_f"
  # A COMMENT still carrying the arm text must not satisfy the guard: the arm is renamed but a
  # comment line reads `# has|lacks)`, so a whole-file grep would pass and the guard must still fire.
  printf '# the arm was has|lacks) once\n' >> "$m8ed_f"
  grep -qF 'has|lacks)' "$m8ed_f" || { note "FAIL  m8e-drift -- the decoy comment did not land"; rc=1; }
  # shellcheck disable=SC2086
  m8ed_out="$(run_v "" "$TMP/m8ed" $M8E_ARGS)"; m8ed_rc=$?
  if [ "$m8ed_rc" -eq 2 ] && grep -q 'has drifted' <<<"$m8ed_out"; then
    note "ok    m8e-drift -- with the classifier's has|lacks arm renamed (a comment still carrying the text) the subject exits 2 naming the drift"
  else
    note "FAIL  m8e-drift -- rc=$m8ed_rc; the drift guard did not fire"; rc=1
  fi
else
  note "FAIL  m8e-drift DID NOT APPLY (no reverify copy, or the rename matched nothing)"; rc=1
fi
# ...and the mutant: the fallthrough restored -- an unrecognised value is dropped, not recorded.
# The subject's own self-probe then refuses (exit 2) and no id is ever named, which is the
# pre-fix behaviour made loud; the assertion is that the id is NOT named and the run is not green.
if mut "$TMP/m8e" 's|>> "$WORK/unrec"; continue ;; esac|>/dev/null; continue ;; esac|'; then
  # shellcheck disable=SC2086
  drive m8e-mut "$TMP/m8e" "" $M8E_ARGS
  score m8e-mut "${B_M8E:-0}" "m8e-mut -- with the fallthrough unrecorded the 'manual.' entry is named nowhere and the subject's self-probe refuses"
else
  note "FAIL  m8e-mut DID NOT APPLY"; rc=1
fi

# ===== M8d. A LEDGER DECLARED EMPTY IS ACCOUNTED FOR, NOT A ZERO. ===========================
# The rotation of the last entry leaves zero entries and the empty marker as the last line. R2
# asks backlog-reverify.sh --declared-empty, only at zero entries, and passes with `R2
# declared-empty`. m8 above is its near-miss: zero entries, no marker, still refused. The marker
# text comes from the classifier's --print-marker, never typed here.
M8D_MARK=""
[ -n "$REVERIFY" ] && M8D_MARK="$(bash "$REVERIFY" --print-marker 2>/dev/null)"
M8D_ARGS="--max-prose-closable 0 --max-unscorable 0 --max-out-of-population 0 --max-unstable 0 --min-sh-receipts 0 --min-entries 0"
if [ -z "$M8D_MARK" ]; then
  note "FAIL  m8d -- backlog-reverify.sh --print-marker returned nothing, so the declared-empty seed cannot be built"; rc=1
else
  seed "$TMP/m8d"
  printf '# Probe backlog\n\nEvery entry was rotated to the archive.\n\n%s\n' "$M8D_MARK" > "$TMP/m8d/docs/backlog.md"
  ( cd "$TMP/m8d" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m declared >/dev/null 2>&1 )
  # shellcheck disable=SC2086
  m8d_out="$(run_v "" "$TMP/m8d" $M8D_ARGS)"; m8d_rc=$?
  if [ "$m8d_rc" -eq 0 ] && grep -q '^OK: validate-backlog-receipts.* R2 declared-empty$' <<<"$m8d_out"; then
    note "ok    m8d -- a ledger declared empty is OK and says R2 declared-empty"; B_M8D=1
  else
    note "FAIL  m8d -- a declared-empty ledger must pass and say so (rc=$m8d_rc)"
    printf '%s\n' "$m8d_out" | grep -E '^(FAIL|OK):' | sed 's/^/      /' | head -3; rc=1
  fi
  # ...and the mutant: the exemption granted at zero entries WITHOUT asking the classifier. m8's
  # undeclared ledger (no marker) must then pass, where the shipped arm refuses it.
  seed "$TMP/m8dm"
  printf '# Probe backlog\n\nEntries were renamed to a shape the predicate does not know.\n\n## BACKLOG-001\n\nBody.\n' \
    > "$TMP/m8dm/docs/backlog.md"
  ( cd "$TMP/m8dm" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m empty >/dev/null 2>&1 )
  if mut "$TMP/m8dm" 's|^  bash "$SELF_ROOT/scripts/backlog-reverify.sh" --declared-empty "$LEDGER" >/dev/null 2>\&1; _de=\$?$|  _de=0|'; then
    # shellcheck disable=SC2086
    drive m8d-mut "$TMP/m8dm" "" $M8D_ARGS
    score m8d-mut "${B_M8D:-0}" "m8d-mut -- an exemption that does not ask the classifier passes an undeclared zero as declared-empty"
  else
    note "FAIL  m8d-mut DID NOT APPLY"; rc=1
  fi
fi

# ===== THE RATCHETS THAT EXIST BECAUSE THE FIRST ONE IS ESCAPABLE. =========================
# Each of these is an edit that LOWERS the prose-closable count and fixes nothing. Without
# their own ceilings the headline number falls and the gate reports an improvement.

# m9 -- the pattern moves into a variable. BL-801 leaves the scored population entirely.
seed "$TMP/m9"
sed "s|verify: sh grep -q 'MARK801' probe/subject.txt|verify: sh S=MARK801; grep -q \"\$S\" probe/subject.txt|" \
  "$TMP/m9/docs/backlog.md" > "$TMP/m9/docs/backlog.md.new"
if cmp -s "$TMP/m9/docs/backlog.md" "$TMP/m9/docs/backlog.md.new"; then
  note "FAIL  m9 -- the evasion edit was a NO-OP, so its verdict means nothing"; rc=1
else
  mv "$TMP/m9/docs/backlog.md.new" "$TMP/m9/docs/backlog.md"
  ( cd "$TMP/m9" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m evade >/dev/null 2>&1 )
  kill_check "m9 moving the pattern into a variable is caught by the unscored ceiling" "$TMP/m9" "" 1 \
    "could not be scored at all" --max-unscorable 1
fi

# m10 -- the receipt's verb becomes `manual`. It leaves the `sh` population, which no ceiling
# above can see, and only the floor does.
seed "$TMP/m10"
sed "s|verify: sh grep -q 'MARK801' probe/subject.txt|verify: manual|" \
  "$TMP/m10/docs/backlog.md" > "$TMP/m10/docs/backlog.md.new"
if cmp -s "$TMP/m10/docs/backlog.md" "$TMP/m10/docs/backlog.md.new"; then
  note "FAIL  m10 -- the evasion edit was a NO-OP, so its verdict means nothing"; rc=1
else
  mv "$TMP/m10/docs/backlog.md.new" "$TMP/m10/docs/backlog.md"
  ( cd "$TMP/m10" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m evade >/dev/null 2>&1 )
  kill_check "m10 a sh -> manual rewrite is caught by the population floor" "$TMP/m10" "" 1 \
    "receipt population fell by"
fi

# m11 -- the floor's NEAR-MISS, and without it m10 proves nothing. A floor that fired whenever
# the count moved would fire on ROTATION, which is the ledger's sanctioned remedy and its most
# common edit -- wedging the push on ordinary work. An entry removed WITH its receipt moves
# both sides and must stay quiet.
seed "$TMP/m11"
awk '/^## BL-801/{skip=1} /^## BL-802/{skip=0} !skip' "$TMP/m11/docs/backlog.md" > "$TMP/m11/docs/backlog.md.new"
if cmp -s "$TMP/m11/docs/backlog.md" "$TMP/m11/docs/backlog.md.new"; then
  note "FAIL  m11 -- the rotation edit was a NO-OP, so its quiet proves nothing"; rc=1
else
  mv "$TMP/m11/docs/backlog.md.new" "$TMP/m11/docs/backlog.md"
  ( cd "$TMP/m11" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m rotate >/dev/null 2>&1 )
  # ROTATION REMOVES A PROSE-CLOSABLE RECEIPT TOO, so this probe's ceilings follow the ledger
  # it actually seeds -- BL-801 is gone, taking one finding with it. Passing the shared $DEF
  # here would fail on the PROSE-CLOSABLE ceiling, which is not what this probe asserts, and
  # its red would read as a floor that fires on rotation.
  m11_out="$(run_v "" "$TMP/m11" --max-prose-closable "$(( BL_PC - 1 ))" \
    --max-unscorable 9 --max-out-of-population 9 --max-unstable 1 \
    --min-sh-receipts "$BL_N" --min-entries "$BL_N")"
  m11_rc=$?
  if [ "$m11_rc" -ne 0 ]; then
    note "FAIL  m11 rotation must be QUIET -- the subject exited $m11_rc. An entry removed with its receipt moves both counts; a floor that fires on it wedges the ledger's only sanctioned remedy."
    printf '%s\n' "$m11_out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1
  else
    note "ok    m11 -- removing an entry AND its receipt moves both counts and the floor stays quiet"
  fi
fi

# ===== THE POPULATION JOIN MOVED. ==========================================================
# Arm j1 -- the validator's `sh` population against backlog-reverify.sh on the REAL ledger -- is
# core/fixtures/backlog-real-ledger/ now. Its verdict depends on docs/backlog.md, which sits under an
# excluded top of the content key, and that unit declares it `+` so a backlog-only push re-runs it.

# ===== M12 / M13. THE SEED AND THE TOKEN GRAMMAR MUST BE COMPLETE, NOT FIRST-ONLY. =========
# Two wrong cuts that pass every single-subject probe in this file and SHRINK the real answer
# without saying so. They are the reason BL-807 exists: it is the only seeded receipt that
# names two paths and carries two greps, so it is the only one either cut can be caught by.
# The direction matters -- both report FEWER findings, which reads as a cleaner ledger.

# m12 -- the seed reaches only the FIRST path the receipt names.
seed "$TMP/m12"
# The `@` delimiter is deliberate: the replacement text contains a `|`, and `s|…|…|` with a
# pipe in the body is `bad flag in substitute command` -- a `sed` that DIES, which the `cmp -s`
# guard cannot tell from one that matched nothing. Measured on this probe's first cut.
if mut "$TMP/m12" "s@^    for _p in \$PATHS; do@    for _p in \$(printf '%s\\\\n' \$PATHS | sed -n '1p'); do@"; then
  drive m12 "$TMP/m12" "" $DEF
  score m12 "$B_CTRL" "m12 -- seeding only the first named path stops the two-file receipt flipping, so the completeness of the seed is load-bearing"
fi

# m13 -- the token grammar reads only the FIRST grep in the receipt.
seed "$TMP/m13"
if mut "$TMP/m13" 's|^      emitpat(q); break|      emitpat(q); p = nt; break|'; then
  drive m13 "$TMP/m13" "" $DEF
  score m13 "$B_CTRL" "m13 -- reading only the first grep stops the two-literal receipt flipping, so every grep in a receipt is load-bearing"
fi

# ===== M14-M16. THREE ARMS NOTHING ELSE HERE EVER DRIVES OVER THEIR THRESHOLD. =============
# Each was reachable only in principle: every probe above passes a slack ceiling or a clean
# tree, so all three could have been deleted without moving a single cell. An arm no probe
# drives is a guard whose removal changes nothing.

# m14 -- R4 driven OVER its ceiling, by pinning it at 0 against the exit-9 receipt.
seed "$TMP/m14"
kill_check "m14 R4 fires when out-of-population exceeds its ceiling" "$TMP/m14" "" 1 \
  "have a base exit that is neither 0 nor 1" --max-out-of-population 0
B_M14=$KC_OK
# ...and the arm's mutant: with the comparison dead, the same corpus must pass.
seed "$TMP/m14b"
if mut "$TMP/m14b" 's|^if \[ "$N_OOP" -gt "$MAX_OOP" \]; then|if false; then|'; then
  drive m14b "$TMP/m14b" "" $DEF --max-out-of-population 0
  score m14b "${B_M14:-0}" "m14b -- with R4's comparison dead the breach passes, so R4 is the arm that catches it"
fi

# m15 -- the every-dispatched-receipt-produced-a-verdict assert. A worker that dies leaves no
# result file, and a smaller result set reads exactly like a smaller population.
seed "$TMP/m15"
if mut "$TMP/m15" 's|^  if \[ "$_sl_got" -ne "$_sl_i" \]; then|  if false; then|'; then
  # Make one worker produce no verdict at all: its write target is redirected to /dev/null,
  # so the receipt is dispatched, runs, and files nothing.
  if mut "$TMP/m15" 's|^  wr() { printf|  wr() { [ "$n" = "0001" ] \&\& return 0; printf|'; then
    drive m15 "$TMP/m15" "" $DEF
  fi
fi
# m15b -- and the arm itself must FIRE on that same tree, unmutated but for the lost verdict.
seed "$TMP/m15b"
if mut "$TMP/m15b" 's|^  wr() { printf|  wr() { [ "$n" = "0001" ] \&\& return 0; printf|'; then
  m15b_out="$(run_v "" "$TMP/m15b" $DEF)"; m15b_rc=$?
  if [ "$m15b_rc" -eq 0 ]; then
    note "FAIL  m15b a receipt that filed NO verdict passed unnoticed -- the subject exited 0 over a population smaller than the one it dispatched."; rc=1
  elif ! grep -qF "produced a verdict" <<<"$m15b_out"; then
    note "FAIL  m15b the subject refused, but not on the dispatched-verdict assertion"
    printf '%s\n' "$m15b_out" | sed 's/^/      /' | head -3; rc=1
  else
    note "ok    m15b -- a dispatched receipt that files no verdict is a refusal, not a smaller population"; B_M15B=1
  fi
fi
[ -f "$REC/m15.rc" ] && score m15 "${B_M15B:-0}" "m15 -- without the verdict-count assert a missing verdict changes the answer, so the assert is what catches a dead worker"

# m16 -- the caller-porcelain assert. m7 proves the tree is unchanged; nothing proved the ARM
# would notice if it were not. m7b makes the seed escape, so this asks whether the porcelain
# comparison is what reports it.
seed "$TMP/m16"
if mut "$TMP/m16" 's|^    _st_d="$(mktree "$1")"|    _st_d="$SR"|'; then
  if mut "$TMP/m16" 's|^if \[ "$PORC_AFTER" != "$PORC_BEFORE" \]; then|if false; then|'; then
    drive m16 "$TMP/m16" "" $DEF
    m16_porc="$(git -C "$TMP/m16" status --porcelain | grep -c . )"
    side m16 "porc=$m16_porc"
    score m16 "$B_CTRL" "m16 -- with the porcelain comparison dead an escaped seed is no longer reported as one, so that comparison is the reporter"
  fi
fi

# ===== C1 / C2. THE REGISTRY IS SHARED, AND THE ARM MUST ASK ONLY ABOUT ITS OWN. ===========
# A leak check counting the WHOLE worktree registry counts a SHARED resource. Measured before
# this was fixed: two concurrent runs produced identical SUMMARY lines and exits 2 and 0 --
# a correct verdict reported as a broken run, which is the shape an operator switches off.

# c1 -- an unrelated worktree appears mid-run. The arm must not read it as its own leak.
seed "$TMP/c1"
( sleep 2; git -C "$TMP/c1" worktree add --detach -q "$TMP/c1-outsider" HEAD >/dev/null 2>&1 ) &
c1_bg=$!
c1_out="$(run_v "" "$TMP/c1" $DEF)"; c1_rc=$?
wait "$c1_bg" 2>/dev/null
c1_saw="$(git -C "$TMP/c1" worktree list | grep -c 'c1-outsider' )" || c1_saw=0
if [ "$c1_saw" -eq 0 ]; then
  note "FAIL  c1 -- the outsider worktree was never registered, so this probe asserts nothing about a concurrent add"; rc=1
elif [ "$c1_rc" -ne 0 ]; then
  note "FAIL  c1 a concurrent worktree add broke the run -- the subject exited $c1_rc. The registry is shared; another process's checkout is not this run's leak."
  printf '%s\n' "$c1_out" | tail -3 | sed 's/^/      /'; rc=1
else
  note "ok    c1 -- a worktree added by another process mid-run leaves the verdict at 0"
fi
git -C "$TMP/c1" worktree remove --force "$TMP/c1-outsider" >/dev/null 2>&1
git -C "$TMP/c1" worktree prune >/dev/null 2>&1

# c2 -- two concurrent runs against one repository. Both must exit 0; neither may see the
# other's checkouts as its own.
seed "$TMP/c2"
( run_v "" "$TMP/c2" $DEF > "$TMP/c2.a.out" 2>&1; echo $? > "$TMP/c2.a.rc" ) &
c2_a=$!
( run_v "" "$TMP/c2" $DEF > "$TMP/c2.b.out" 2>&1; echo $? > "$TMP/c2.b.rc" ) &
c2_b=$!
wait "$c2_a" 2>/dev/null; wait "$c2_b" 2>/dev/null
c2_arc="$(cat "$TMP/c2.a.rc" 2>/dev/null)"; c2_brc="$(cat "$TMP/c2.b.rc" 2>/dev/null)"
if [ "${c2_arc:-x}" != "0" ] || [ "${c2_brc:-x}" != "0" ]; then
  note "FAIL  c2 two concurrent runs did not both exit 0 (got '$c2_arc' and '$c2_brc'). Each run must ask the registry only about checkouts under its own working directory."
  tail -3 "$TMP/c2.a.out" 2>/dev/null | sed 's/^/      A: /'
  tail -3 "$TMP/c2.b.out" 2>/dev/null | sed 's/^/      B: /'
  rc=1
else
  note "ok    c2 -- two concurrent runs against one repository both exit 0"
fi

# ===== M17. A NON-DETERMINISTIC RECEIPT IS NAMED, NOT ABSORBED AND NOT MISFILED. ===========
# Measured once in thirty-three runs under three-way contention: a receipt guarding its
# preconditions with `|| exit 9` answered 9 on one reading and its usual answer on the next,
# which took the out-of-population count over its ceiling and FAILED THE PUSH by name -- a
# real failure attributed to a receipt that is fine. The re-read is what separates the two,
# and it is DIAGNOSTIC: taking the second reading as the answer would hide a receipt whose
# exit depends on when it ran, which is a defect in the receipt.

# m17 -- delete the re-read. The unstable receipt must stop being UNSTABLE.
#
# IT IS KILLED AT THE SUBJECT'S OWN SELF-PROBE, WHICH IS THE STRONGER KILL. The arm carries
# the same flapping receipt in its R1 corpus, so with the comparison dead it REFUSES (exit 2,
# nothing reported) rather than publishing a report that misfiles the receipt. The probe
# asserts the refusal names the unstable receipt, so an unrelated exit 2 cannot score here.
seed "$TMP/m17"
if mut "$TMP/m17" 's|^    if \[ "$REREAD_RC" != "$BASE_RC" \]; then|    if false; then|'; then
  drive m17 "$TMP/m17" "" $DEF
  score m17 "$B_CTRL" "m17 -- without the re-read the flapping receipt is misfiled as OUT-OF-POPULATION, and the self-probe refuses before any corpus verdict"
fi

# m17b -- and the ceiling SHIPS AT ZERO, so the same seed must FAIL under the default. Without
# this, `--max-unstable 1` in $DEF above would be indistinguishable from a ceiling that does
# not bind at all.
#
# IT DOES NOT GO THROUGH kill_check, WHICH APPENDS $DEF. That string already carries
# `--max-unstable 1`, and a later flag does not undo an earlier one here -- the probe would
# have run at a ceiling of 1 and reported SURVIVED against a working arm. Measured exactly
# that way on this probe's first cut. The run below passes NO unstable flag at all, so the
# compiled-in default is what decides, which is the whole claim.
seed "$TMP/m17b"
m17b_out="$(run_v "" "$TMP/m17b" --max-prose-closable "$BL_PC" --max-unscorable 9 \
  --max-out-of-population 9 --min-sh-receipts "$BL_N" --min-entries "$BL_N")"
m17b_rc=$?
m17b_nfail="$(printf '%s\n' "$m17b_out" | grep -c '^FAIL:')"
if [ "$m17b_rc" -eq 0 ]; then
  note "FAIL  m17b an unstable receipt PASSED at the shipped default, so that ceiling does not bind and \$DEF's --max-unstable 1 is indistinguishable from it."; rc=1
elif [ "$m17b_rc" -eq 2 ]; then
  note "FAIL  m17b -- the subject exited 2, which is not this probe's assertion"
  printf '%s\n' "$m17b_out" | sed 's/^/      /' | head -3; rc=1
elif ! grep -qF "gave DIFFERENT exits on two readings" <<<"$m17b_out"; then
  note "FAIL  m17b -- the subject failed, but not on the unstable ceiling"
  printf '%s\n' "$m17b_out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1
elif [ "$m17b_nfail" -ne 1 ]; then
  note "FAIL  m17b -- $m17b_nfail FAIL lines, expected 1"
  printf '%s\n' "$m17b_out" | grep '^FAIL:' | sed 's/^/      /' | head -4; rc=1
else
  note "ok    m17b -- an unstable receipt fails the push at the shipped default of 0, by name"
fi

# m17c -- THE NEAR-MISS, and without it m17 proves nothing. A re-read that reported UNSTABLE
# for any non-0/1 exit would take BL-803 -- which answers 9 EVERY time -- out of the
# out-of-population class, which is where a genuinely unreachable precondition belongs.
# The control's world and arguments, so the control's run is read rather than repeated.
m17c_out="$CTL_OUT"
m17c_803="$(cls "$m17c_out" BL-803)"
if [ "$m17c_803" != "OUT-OF-POPULATION" ]; then
  note "FAIL  m17c -- the receipt that exits 9 on EVERY reading was reported '${m17c_803:-NONE}', not OUT-OF-POPULATION. A stable exit 9 is a precondition that is genuinely unmet, and calling it unstable would empty the class the re-read is meant to protect."
  rc=1
else
  note "ok    m17c -- a receipt that exits 9 on both readings stays OUT-OF-POPULATION, so the re-read discriminates rather than reclassifying every non-0/1 exit"
fi

# m18 -- THE CHECKOUT-COMPLETENESS ASSERTION. `git worktree add` exiting 0 is not a usable
# tree, and an incomplete one produces a verdict about the checkout rather than the receipt.
# With the assertion dead, a tree missing its sentinel must still be handed to a receipt.
seed "$TMP/m18"
if mut "$TMP/m18" 's|^        if tree_complete "$_d"; then|        if true; then|'; then
  drive m18 "$TMP/m18" "" $DEF
  m18_still="$(grep -c 'if tree_complete' "$TMP/m18/scripts/validate-backlog-receipts.sh")" || m18_still=0
  if [ "$m18_still" -eq 0 ]; then side m18 "tree_complete=gone"; else side m18 "tree_complete=present"; fi
  score m18 "$B_CTRL" "m18 -- the completeness assertion is a distinct branch and its removal is observable, and the self-probe does not refuse"
fi

# ===== Q1. --quiet SUPPRESSES THE FINDING ROWS, NEVER THE PROVENANCE. ======================
# A caller asserting this arm RAN needs a token a program that seeds nothing cannot honestly
# print. Both directions: the clause is present under --quiet, and the finding rows are not.
seed "$TMP/q1"
q1_out="$(run_v "" "$TMP/q1" $DEF --quiet)"; q1_rc=$?
q1_rows="$(printf '%s\n' "$q1_out" | grep -c '^PROSE-CLOSABLE	')" || q1_rows=0
if [ "$q1_rc" -ne 0 ]; then
  note "FAIL  q1 -- the subject exited $q1_rc under --quiet on a tree that must pass"; rc=1
elif ! grep -qF "detached checkout of HEAD" <<<"$q1_out"; then
  note "FAIL  q1 -- --quiet suppressed the provenance clause. A caller keying on this arm having RUN would then be satisfied by any program that exits 0 in silence."
  printf '%s\n' "$q1_out" | sed 's/^/      /' | head -3; rc=1
elif [ "$q1_rows" -ne 0 ]; then
  note "FAIL  q1 -- --quiet still printed $q1_rows finding row(s), so it is not quiet"; rc=1
else
  note "ok    q1 -- --quiet drops the finding rows and keeps the provenance clause"
fi

# --- THE SELF-PROBE MUST NOT WRITE TO THE CALLER'S REPOSITORY -------------------------------
#
# `git -C <dir>` DOES NOT OVERRIDE AN INHERITED `GIT_DIR` -- the environment wins, for reads and
# for WRITES. MEASURED on two throwaway repositories: `GIT_DIR=A/.git git -C B config k v`
# writes into A's config and leaves B's untouched. Git exports GIT_DIR, ABSOLUTE, into every
# hook run from a LINKED WORKTREE, and this repo's gate runs the subject from one.
#
# So the subject's own self-probe -- which builds a throwaway repository and points it at a
# `.probehooks` directory -- wrote `core.hooksPath=<a mktemp path>` into the CALLER'S
# repository. The caller's pre-push hook was then aimed at a directory the run deletes on exit,
# and its next push ran NO GATE AT ALL while printing success. Measured on this repository: a
# release landed on origin ungated, found only because someone read the config by hand.
#
# THE ARM IS THE ONLY CHANNEL THAT COULD HAVE SEEN IT. The subject's self-probe still PASSES
# with the bug -- the probe repo does not need the hook it never finds -- and the caller shows
# nothing until a later, unrelated push quietly skips its hooks. Neither side reports.
#
# A THROWAWAY CALLER, NEVER A REAL ONE: the arm's whole subject is a repository being written
# to by mistake, so the repository it offers up must be one nothing depends on.
#
# THE THROWAWAY CALLER NEEDS A COMMIT, and that is not housekeeping. Under an inherited GIT_DIR
# the subject's `git -C "$SUBJECT_ROOT" rev-parse HEAD` reads the CALLER, not the subject tree --
# the same precedence this arm exists to demonstrate -- so an empty caller makes the subject exit
# at "has no HEAD commit" long before its self-probe, and the mutant then moves nothing for a
# reason the mutation does not own. MEASURED: exactly that, and it reported as "the arm cannot
# fire", which is the mutant doing its job.
gd_caller="$TMP/gd-caller"
mkdir -p "$gd_caller"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  cd "$gd_caller" && git init -q . >/dev/null 2>&1 \
    && git config core.hooksPath .githooks >/dev/null 2>&1 \
    && echo caller > callerfile.txt \
    && git add -A >/dev/null 2>&1 \
    && git -c user.email=c@local -c user.name=c commit -q -m caller >/dev/null 2>&1 )
gd_before="$(git config --file "$gd_caller/.git/config" --get core.hooksPath 2>/dev/null)" || gd_before=""
if [ ! -d "$gd_caller/.git" ] || [ "$gd_before" != ".githooks" ]; then
  note "FAIL  gitdir -- the throwaway caller did not build with a hooks path (got '${gd_before:-<unset>}'), so this arm has no subject and its 'unchanged' below would be vacuous"
  rc=1
else
  # The subject is driven with GIT_DIR pointed at the throwaway caller, which is exactly the
  # environment git hands a hook running from a linked worktree.
  seed "$TMP/gd1"
  gd_out="$(run_v "GIT_DIR=$gd_caller/.git" "$TMP/gd1" $DEF --quiet 2>&1)"; gd_rc=$?
  gd_after="$(git config --file "$gd_caller/.git/config" --get core.hooksPath 2>/dev/null)" || gd_after=""
  if [ "$gd_after" = "$gd_before" ]; then
    note "ok    gitdir -- the subject run under an inherited GIT_DIR leaves the caller's core.hooksPath byte-unchanged ($gd_after)"; B_GDa=1
  else
    note "FAIL  gitdir -- the subject REWROTE the caller's core.hooksPath from '$gd_before' to '$gd_after'. The caller's own pre-push hook now points at a directory this run deletes, so its next push runs no gate and reports success."
    rc=1
  fi
  # AND THE SUBJECT MUST STILL HAVE SCORED ITS OWN TREE. The hooks-path half above is satisfied
  # by a subject that redirects everything ELSE at the caller too -- `worktree add --detach HEAD`
  # under an inherited GIT_DIR checks out the CALLER'S HEAD for every receipt, so each one is
  # scored against a tree that carries none of the seeded subjects. MEASURED at the gate: that
  # surfaced as the self-probe's seeded receipts reading OUT-OF-POPULATION with base exits of 2,
  # which reads as a broken scorer rather than as a redirected one. So the arm asserts the run
  # SUCCEEDED and registered no worktree in the caller.
  gd_wt="$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
              git -C "$gd_caller" worktree list 2>/dev/null ) | grep -c . )" || gd_wt=0
  if [ "${gd_rc:-1}" -eq 0 ] && [ "$gd_wt" -le 1 ]; then
    note "ok    gitdir-scored -- under an inherited GIT_DIR the subject scored its OWN tree (exit 0) and registered no checkout in the caller (worktree rows: $gd_wt)"; B_GDb=1
  else
    note "FAIL  gitdir-scored -- the subject exited ${gd_rc:-?} and left $gd_wt worktree row(s) in the caller. Its receipt checkouts came from the CALLER'S HEAD, so every receipt was scored against a tree carrying none of its subjects."
    printf '%s\n' "$gd_out" | tail -4 | sed 's/^/      /'
    rc=1
  fi
  # THE MUTANT: the pre-fix line, restored. Without it the arm above passes whether the scrub is
  # present or absent -- an arm that cannot fire reads exactly like one that discriminates.
  # Reset the caller between the two drives, so the mutant is scored from the same start state.
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    git -C "$gd_caller" config core.hooksPath .githooks >/dev/null 2>&1 )
  seed "$TMP/gd2"
  # ONE LINE REVERTED -- the process-wide scrub, which is the whole fix. Anchored on the
  # unconditional `unset` at column zero, asserted unique below, and replaced by a `:` so the
  # mutant still PARSES: a mutant that fails to parse fails every arm for a reason the mutation
  # does not own, and scores a kill nobody earned.
  gd_anchor='^unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY$'
  gd_anchor_n="$(grep -cE "$gd_anchor" "$TMP/gd2/scripts/validate-backlog-receipts.sh")" || gd_anchor_n=0
  if [ "$gd_anchor_n" -ne 1 ]; then
    note "FAIL  gitdir-mutant -- the scrub anchor matches $gd_anchor_n line(s), not 1, so the mutation below would edit the wrong site or none"
    rc=1
  elif mut "$TMP/gd2" 's|^unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY$|: # scrub removed by the fixture mutant|'; then
    drive gitdir-mutant "$TMP/gd2" "GIT_DIR=$gd_caller/.git" $DEF --quiet
    gd_mut="$(git config --file "$gd_caller/.git/config" --get core.hooksPath 2>/dev/null)" || gd_mut=""
    if [ "$gd_mut" != "$gd_before" ]; then side gitdir-mutant "hookspath=changed"; else side gitdir-mutant "hookspath=same"; fi
    score gitdir-mutant "$(( ${B_GDa:-0} * ${B_GDb:-0} ))" "gitdir-mutant -- with the scrub removed the subject is redirected at the CALLER (it refuses on its own seeded probes, or rewrites the caller's hooks path), so the arm above reads the scrub and not merely the absence of a crash"
    ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
      git -C "$gd_caller" config core.hooksPath .githooks >/dev/null 2>&1 )
  fi
  # BOTH DRIVES REGISTER WORKTREES IN THE THROWAWAY CALLER, for the same reason the arm exists:
  # under an inherited GIT_DIR the subject's `worktree add` lands there rather than in the tree
  # it was pointed at. They are pruned so this arm leaves the caller as it found it -- the
  # directory is deleted with $TMP either way, but a registry left dirty is the shape the
  # subject's own leak check reports, and a fixture must not model bad hygiene.
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    git -C "$gd_caller" worktree prune >/dev/null 2>&1 ) || true
fi

# ===== PHANTOM. A PROSE LEAD-IN BULLET INSIDE AN ENTRY IS NOT AN ENTRY (BL-820). =============
# Its own seed, NOT bl_seed_ledger: class_check hardcodes that seed's classification set and the
# BL_N/BL_PC pair, and a stale pair is how m10 once went vacuous. BL-850 carries
# `- **BL-632 is LANDED** prose` BEFORE its receipt; BL-851 is the legitimate list form
# `- **BL-851** — t`. Both receipts grep a literal the probe file lacks, so each is PROSE-CLOSABLE
# by name -- a presence-shaped reading, and a subject that emits nothing fails it.
PH_ARGS="--max-prose-closable 9 --min-sh-receipts 0 --min-entries 0"
ph_world() { # ph_world <dir> [<sed-expr for the seed's lib.sh>] -- 0 built, 1 the sed did not apply
  local d="$1" l
  seed "$d"
  {
    printf '# Probe backlog\n\n## BL-850 — host\n\nBody.\n\n- **BL-632 is LANDED** prose about another entry\n\n'
    printf 'verify: sh grep -q %s probe/subject.txt\n\n' "'MARK850'"
    printf -- '- **BL-851** — a list entry\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'MARK851'"
  } > "$d/docs/backlog.md"
  if [ -n "${2:-}" ]; then
    l="$d/core/skills/ai-dlc-update/reconcile/lib.sh"
    sed "$2" "$LIBSRC" > "$l" || return 1
    cmp -s "$l" "$LIBSRC" && return 1
  fi
  ( cd "$d" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m phantom >/dev/null 2>&1 )
  return 0
}
# ph01 -- the fix: both entries classified, no BL-632 row, two sh receipts over two entries.
ph_world "$TMP/ph01"
# shellcheck disable=SC2086
ph_out="$(run_v "" "$TMP/ph01" $PH_ARGS)"; ph_rc=$?
if [ "$ph_rc" -eq 0 ] && [ "$(cls "$ph_out" BL-850)" = PROSE-CLOSABLE ] && [ "$(cls "$ph_out" BL-851)" = PROSE-CLOSABLE ] \
   && [ -z "$(cls "$ph_out" BL-632)" ] && grep -qE '^SUMMARY entries=2 sh-receipts=2 ' <<<"$ph_out"; then
  note "ok    ph01 -- the lead-in bullet inside BL-850 opens no entry: BL-850 keeps its receipt, the list entry BL-851 is scored, 2 entries"; B_PH=1
else
  note "FAIL  ph01 -- exit $ph_rc, BL-850=$(cls "$ph_out" BL-850) BL-851=$(cls "$ph_out" BL-851) BL-632=$(cls "$ph_out" BL-632)"
  printf '%s\n' "$ph_out" | grep -E '^SUMMARY|SELF-PROBE' | sed 's/^/      /'; rc=1
fi
# m-loose -- the strict bullet test deleted from the seed's lib.sh. The validator's OWN self-probe
# carries the same phantom inside its BL-902, so it refuses with exit 2 before the corpus is read.
# This is the committed mutant the self-probe's absence-shaped BL-632 arm needs: it proves that arm
# can fire. Keyed on the self-probe's sentence AND on BL-632, never on the exit code alone.
if ph_world "$TMP/phl" '/if (line !~ \/^BL-/d'; then
  # shellcheck disable=SC2086
  drive m-loose "$TMP/phl" "" $PH_ARGS
  score m-loose "${B_PH:-0}" "m-loose -- with the loose label rule the self-probe's phantom takes BL-902's receipt and the subject refuses (exit 2) naming BL-632"
else note "FAIL  m-loose -- the label mutation DID NOT APPLY"; rc=1; fi
# m-heading-only -- bullets never labelled. The self-probe ledger is all headings, so it passes;
# the list entry BL-851 then vanishes from the corpus and the entry count drops to 1.
if ph_world "$TMP/phh" 's/if (line !~ /if (1 || line !~ /'; then
  # shellcheck disable=SC2086
  drive m-heading-only "$TMP/phh" "" $PH_ARGS
  score m-heading-only "${B_PH:-0}" "m-heading-only -- with bullets never labelled the list entry BL-851 is not scored (1 entry), while BL-850 still is"
else note "FAIL  m-heading-only -- the label mutation DID NOT APPLY"; rc=1; fi

# ===== MEMO. A RECEIPT MUST NOT INHERIT THE STATE reconcile/lib.sh EXPORTED IN THE PARENT. =====
# The parent sources lib.sh, which EXPORTS `AI_DLC_RECONCILE_MEMO`, and every `--score-one` worker
# inherited it through the environment -- so a receipt driving a reconcile script borrowed the
# parent's memo (backlog-reverify.sh's BL-382, the same defect). Functions do not reach a worker,
# which is a fresh `bash`; BL-824 records that and is not what any mutant below keys on.
#
# ITS OWN WORLD, NEVER bl_seed_ledger: BL_N's floor is keyed on that ledger's count. The receipts
# are shaped so the leaked and the clean readings are both REPORTED BY NAME -- a leak turns an
# ALREADY-PASSING receipt into an exit-9 OUT-OF-POPULATION one -- and BL-821 is the scored receipt
# that keeps the subject past its zero-scored refusal, which prints no rows at all.
#
# THE DERIVED HALF NEEDS A SUBJECT, SO THIS WORLD'S lib.sh EXPORTS A SECOND VARIABLE. The shipped
# lib.sh exports exactly one, which the fix also names outright, so a fix that dropped the
# derivation would pass every drive of an unmodified copy. BL-823 keys on the synthesised one.
# TWO DRIVES: no inbound memo (lib.sh makes one, so it is NEW to the parent) and a CALLER-exported
# memo (already there before lib.sh ran, so only the outright name removes it).
seed_memo() { # seed_memo <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile" "$d/probe"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-backlog-receipts.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  printf '\nLIBPROBE_EXPORTED=1\nexport LIBPROBE_EXPORTED\n' >> "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$REVSRC" "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
  [ -n "$REVERIFY" ] && cp "$REVERIFY" "$d/scripts/backlog-reverify.sh"
  mkdir -p "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts" "$d/core/skills/ai-dlc/steps"
  cp "$EXTRACT" "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"
  : > "$d/core/skills/ai-dlc/steps/implementation.md"
  cp "$RLIB" "$d/scripts/backlog-receipt-lib.sh"
  printf 'alpha\n' > "$d/probe/subject.txt"
  printf 'memo\n' > "$d/probe/memo.txt"
  printf 'probe\n' > "$d/probe/probe.txt"
  printf 'fn\n' > "$d/probe/fn.txt"
  {
    printf '# Probe backlog\n\n'
    printf '## BL-821\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'MARK821'"
    printf '## BL-822\n\nverify: sh [ -n "${AI_DLC_RECONCILE_MEMO:-}" ] && exit 9; ! grep -q %s probe/memo.txt\n\n' "'MARK822'"
    printf '## BL-823\n\nverify: sh [ -n "${LIBPROBE_EXPORTED:-}" ] && exit 9; ! grep -q %s probe/probe.txt\n\n' "'MARK823'"
    printf '## BL-824\n\nverify: sh type ai_dlc_memo_dir >/dev/null 2>&1 && exit 9; ! grep -q %s probe/fn.txt\n\n' "'MARK824'"
  } > "$d/docs/backlog.md"
  ( cd "$d" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
      && git -c user.email=p@local -c user.name=p commit -q -m seed >/dev/null 2>&1 )
  [ -d "$d/.git" ] || { echo "FIXTURE BROKEN: the memo probe repository at $d has no .git" >&2; exit 2; }
}
MEMO_ARGS="--max-prose-closable 1 --max-unscorable 9 --max-out-of-population 9 --max-unstable 0 --min-sh-receipts 4 --min-entries 4"
MEMO_IN="$TMP/inbound-memo"; mkdir -p "$MEMO_IN"
# memo_drive <dir> <none|caller> -> "BL-821=... BL-822=... BL-823=... BL-824=... rc=N"
memo_drive() {
  local d="$1" e="" o r id s
  [ "$2" = caller ] && e="AI_DLC_RECONCILE_MEMO=$MEMO_IN"
  o="$(run_v "$e" "$d" $MEMO_ARGS)"; r=$?
  s=""
  for id in BL-821 BL-822 BL-823 BL-824; do s="$s$id=$(cls "$o" "$id") "; done
  printf '%src=%s' "$s" "$r"
}
MEMO_WANT="BL-821=PROSE-CLOSABLE BL-822=ALREADY-PASSING BL-823=ALREADY-PASSING BL-824=ALREADY-PASSING rc=0"

# THE WORLD DISCRIMINATES: each sensitive receipt exits 9 with its variable set and 0 without, and
# the world's lib.sh copy carries the synthesised export the shipped one does not.
memo_rc0=$rc
seed_memo "$TMP/memo"
mw_lib="$TMP/memo/core/skills/ai-dlc-update/reconcile/lib.sh"
mw_n="$(grep -c '^export LIBPROBE_EXPORTED$' "$mw_lib")" || mw_n=0
mw_src="$(grep -c '^export LIBPROBE_EXPORTED$' "$LIBSRC")" || mw_src=0
mw_a="$(cd "$TMP/memo" && env -u AI_DLC_RECONCILE_MEMO bash -c '[ -n "${AI_DLC_RECONCILE_MEMO:-}" ] && exit 9; ! grep -q MARK822 probe/memo.txt' >/dev/null 2>&1; echo $?)"
mw_b="$(cd "$TMP/memo" && AI_DLC_RECONCILE_MEMO="$MEMO_IN" bash -c '[ -n "${AI_DLC_RECONCILE_MEMO:-}" ] && exit 9; ! grep -q MARK822 probe/memo.txt' >/dev/null 2>&1; echo $?)"
if [ "$mw_n" -eq 1 ] && [ "$mw_src" -eq 0 ] && [ "$mw_a" -eq 0 ] && [ "$mw_b" -eq 9 ]; then
  note "ok    memo-discriminates -- BL-822 exits 0 bare and 9 with the memo set, and only the world's lib.sh exports LIBPROBE_EXPORTED"
else
  note "FAIL  memo-discriminates -- bare $mw_a, memo-set $mw_b, world export $mw_n, shipped export $mw_src: the world cannot see a leak"; rc=1
fi
for mdrv in none caller; do
  mgot="$(memo_drive "$TMP/memo" "$mdrv")"
  if [ "$mgot" = "$MEMO_WANT" ]; then
    note "ok    memo-leak-$mdrv -- no receipt inherits lib.sh's exports ($mgot)"
  else
    note "FAIL  memo-leak-$mdrv -- a receipt read the parent's lib.sh state: got '$mgot', want '$MEMO_WANT'"; rc=1
  fi
done
[ -d "$MEMO_IN" ] || { note "FAIL  memo-caller-owned -- the subject removed a memo directory its caller owns"; rc=1; }
B_MEMO=0; [ "$rc" = "$memo_rc0" ] && B_MEMO=1

# THREE MUTANTS, one per half of the fix, each scored on BOTH drives against its own expected cells.
# memo_mut <name> <sed> <deciding drive: none|caller>. The deciding drive runs per push; --matrix runs both.
memo_mut() {
  local n="$1" expr="$2" cell="$3"
  seed_memo "$TMP/$n"
  mut "$TMP/$n" "$expr" || return
  record "$n" 0 "ARGS memo"
  if [ "$cell" = none ] || [ "$MATRIX" = 1 ]; then printf 'NONE %s\n' "$(memo_drive "$TMP/$n" none)" >> "$REC/$n.out"; fi
  if [ "$cell" = caller ] || [ "$MATRIX" = 1 ]; then printf 'CALLER %s\n' "$(memo_drive "$TMP/$n" caller)" >> "$REC/$n.out"; fi
  score "$n" "${B_MEMO:-0}" "$n -- the drive this half of the fix owns reads the leaked cells, so the half is load-bearing"
}
LEAK_BOTH="BL-821=PROSE-CLOSABLE BL-822=OUT-OF-POPULATION BL-823=OUT-OF-POPULATION BL-824=ALREADY-PASSING rc=0"
LEAK_MEMO="BL-821=PROSE-CLOSABLE BL-822=OUT-OF-POPULATION BL-823=ALREADY-PASSING BL-824=ALREADY-PASSING rc=0"
LEAK_PROBE="BL-821=PROSE-CLOSABLE BL-822=ALREADY-PASSING BL-823=OUT-OF-POPULATION BL-824=ALREADY-PASSING rc=0"
# The unset in the worker removed: every export leaks, in both drives.
memo_mut m-memo-unset 's|^  \[ -n "\${BR_LIB_VARS:-}" \] \&\& unset \$BR_LIB_VARS$|  : MUTANT|' none
# The outright name dropped: only a CALLER's memo leaks, because lib.sh's own is new to the diff.
memo_mut m-memo-name 's|^BR_LIB_VARS="AI_DLC_RECONCILE_MEMO \$(_br_added |BR_LIB_VARS="$(_br_added |' caller
# The derivation dropped: only the synthesised export leaks.
memo_mut m-memo-derive 's|^BR_LIB_VARS="AI_DLC_RECONCILE_MEMO \$(_br_added .*$|BR_LIB_VARS="AI_DLC_RECONCILE_MEMO"|' none

# ===== THE EFFICIENCY ARMS (BL-817): E1 close, E2 shape, E3 filing. =========================
# Driven through `--efficiency-only` on seeded ledgers, which runs the subject's own E0 self-probe
# and then the arms, and exits before the per-receipt checkout scorer. Every world is one entry;
# every verdict is read off the subject's own `FAIL: E<TAB><id><TAB><code>` rows, so each arm is
# PRESENCE-shaped: an expected row must APPEAR, and the quiet twin must carry the OK line.
#   ef-good     a valid close, a valid no-step close, a tagged entry citing the ruling, an untagged
#               docs/analysis/ citer carrying the no-step line, and a section preamble citing
#               docs/analysis/ after an entry (the narrowing) -> OK, zero rows
#   ef-noclose  a tagged LANDED entry with no outcome line                     -> NO-OUTCOME
#   ef-sprintless a sprintless line WITHOUT the no-step wording              -> NO-SPRINT
#   ef-untagged an untagged entry citing docs/analysis/                         -> F-UNTAGGED
#   ef-noseat   a sprint-branch line with all three labels and the words lead/subagent but only a
#               percentage and a call count beside them (no `<n> h` / `$<n>` seat figure) -> SHAPE
#   ef-second   the second spelling of a valid line (bold label, `sprint 321`, a Failure caught:
#               citation resolved by its phrase)                                -> OK
# Mutants (copies, cmp-guarded through `mut`): m-noclose removes the close arm's population test,
# m-widenostep widens the no-step branch to accept any sprintless line, m-nofiling removes the
# untagged-citing refusal. Each must turn exactly its own world red; E0 is part of the subject, so
# a mutant the self-probe catches exits 2 -- which is a kill BY THE SELF-PROBE, asserted as such.
EF_RUL='Cites "A step with no measured value goes" in `.claude/rules/operator-rulings.md`.'
EF_SEAT='token-equivalent $9 with API $8 beside it, 1.0 h gap-inclusive, lead active 0.4 h, subagent $5'
EF_SHP="$EF_SEAT, measured by docs/analysis/m.py, before 2.0 h and after 1.0 h"
ef_seed() { # ef_seed <dir> <ledger-body>
  seed "$1"
  mkdir -p "$1/docs/analysis"
  printf '| row | EFROW phrase |\n**M.** Failure caught: EFFC phrase\n' > "$1/docs/analysis/v.md"
  : > "$1/docs/analysis/m.py"
  printf '%s' "$2" > "$1/docs/backlog.md"
}
ef_rows() { printf '%s\n' "$1" | awk -F'\t' '$1 == "FAIL: E" { print $3 " " $2 }' | LC_ALL=C sort | tr '\n' '|'; }
EF_GOOD="# probe

## BL-971

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, $EF_SHP; fell from 2.0 h.

## BL-972

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: no graph pipeline step; the cost lives in scripts/x.sh.

## BL-973

**DEFECT (efficiency).** open. $EF_RUL

## BL-974

Filed from docs/analysis/x.md; there is no graph pipeline step.

## A section

Section prose citing docs/analysis/x.md.
"
ef_world() { # ef_world <name> <dir> <ledger> <want-rows> <want-rc>
  local out rc_v got
  ef_seed "$2" "$3"
  out="$( (cd "$2" && bash scripts/validate-backlog-receipts.sh --efficiency-only 2>&1) )"; rc_v=$?
  got="$(ef_rows "$out")"
  if [ "$rc_v" -eq "$5" ] && [ "$got" = "$4" ] && { [ "$5" -ne 0 ] || grep -qF 'OK: validate-backlog-receipts --efficiency-only' <<<"$out"; }; then
    note "ok    $1 -- rc $rc_v, rows [${got}]"; eval "B_${1//-/_}=1"
  else
    note "FAIL  $1 -- rc $rc_v (want $5), rows [${got}] (want [$4])"
    printf '%s\n' "$out" | grep -v '^FAIL: E' | sed 's/^/      /' | head -4; rc=1
  fi
}
ef_world ef-good "$TMP/efgood" "$EF_GOOD" "" 0
ef_world ef-noclose "$TMP/efnc" "# probe

## BL-975

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**
" "NO-OUTCOME BL-975|" 1
ef_world ef-sprintless "$TMP/efsl" "# probe

## BL-976

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: the cost fell.
" "NO-SPRINT BL-976|" 1
ef_world ef-untagged "$TMP/efut" "# probe

## BL-977

Filed from docs/analysis/x.md with no tag.
" "F-UNTAGGED BL-977|" 1
ef_world ef-second "$TMP/ef2" "# probe

## BL-978

**DEFECT (efficiency).** x. Cites \"A step with no measured value
goes\" in \`.claude/rules/operator-rulings.md\`.

<br>**LANDED (v0.1.0, verified abc1234).**

<br>**Outcome measured:** graph sprint 321, $EF_SHP; did not fall; \`docs/analysis/v.md:2\` \"EFFC phrase\".
" "" 0
EF_NOSEAT="# probe

## BL-980

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, token-equivalent \$9 with API \$8 beside it, 1.0 h gap-inclusive; lead 40% of calls, subagent 12 calls.
"
ef_world ef-noseat "$TMP/efns" "$EF_NOSEAT" "SHAPE BL-980|" 1
# ef-pathsprint: a no-step close whose only s<NNN> token sits inside a path segment (BL-821's shape)
# must take the no-step branch, so it reads OK; a sprint branch would refuse it as SHAPE.
EF_PATHSPRINT="# probe

## BL-979

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: no graph pipeline step; the cost lives in this repo's analysis scripts (\`docs/analysis/pipeline-efficiency-s317-s320/scripts/impl_passes.py\`), which are analysis tooling.
"
ef_world ef-pathsprint "$TMP/efps" "$EF_PATHSPRINT" "" 0

# ef_mut <name> <sed> <world-dir-name> <ledger> -- the mutant must turn its world from red to green
# (the arm stopped firing) OR be refused by the subject's own E0 self-probe (exit 2 naming E0).
ef_mut() { # ef_mut <name> <sed> <world-dir-name> <ledger>
  local d="$TMP/$1" out rc_v bf
  ef_seed "$d" "$4"
  mut "$d" "$2" || return
  out="$( (cd "$d" && bash scripts/validate-backlog-receipts.sh --efficiency-only 2>&1) )"; rc_v=$?
  record "$1" "$rc_v" "$out"
  side "$1" "world=$3"
  eval "bf=\${B_${3//-/_}:-0}"
  score "$1" "$bf" "$1 -- refused by the subject's own E0 self-probe, or the $3 world, red on the shipped subject, reads green with the arm mutated"
}
ef_mut m-noclose 's/^    if \[ "\$_ld" = "1" \] .. { \[ "\$_t" = "1" \] || \[ "\$_on" = "1" \]; }; then$/    if false; then/' ef-noclose "# probe

## BL-975

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**
"
ef_mut m-widenostep 's/^eff_nostep_ok() { case .*$/eff_nostep_ok() { return 0; }/' ef-sprintless "# probe

## BL-976

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: the cost fell.
"
# m-nopathnarrow reverts the standalone-word narrowing: the raw line is matched again, so the
# path-embedded s317 reads as a sprint. The ef-pathsprint world (green on the subject) is used as the
# seed, so a survivor is rc 0 there; the kill is E0's own BL-966 case refusing first (exit 2), or
# the world turning red. ef_mut scores rc 0 as a kill, so this one is scored here instead.
d_pn="$TMP/m-nopathnarrow"; ef_seed "$d_pn" "$EF_PATHSPRINT"
if mut "$d_pn" 's/^  _t="\$(sed -e .*$/  _t="$1"/'; then
  out="$( (cd "$d_pn" && bash scripts/validate-backlog-receipts.sh --efficiency-only 2>&1) )"; rc_v=$?
  record m-nopathnarrow "$rc_v" "$out"
  side m-nopathnarrow "rows=$(ef_rows "$out")"
  score m-nopathnarrow "${B_ef_pathsprint:-0}" "m-nopathnarrow -- refused by the subject's own E0 self-probe (BL-966), or the ef-pathsprint world reads SHAPE BL-979 with the narrowing reverted"
fi
# m-noseat: eff_shape_ok back to the three-label form, eff_seat_ok defined and never called.
ef_mut m-noseat 's#^eff_shape_ok() .*$#eff_shape_ok() { case "$1" in *token-equivalent*) ;; *) return 1 ;; esac; case "$1" in *API*) ;; *) return 1 ;; esac; case "$1" in *gap-inclusive*) return 0 ;; esac; return 1; }#' ef-noseat "$EF_NOSEAT"
# m-seatword: eff_seat_ok reduced to the words lead and subagent occurring (the word-only regression).
ef_mut m-seatword 's#^eff_seat_ok() {$#eff_seat_ok() { grep -qi lead <<<"$1" \&\& grep -qi subagent <<<"$1"; }; eff_seat_orig() {#' ef-noseat "$EF_NOSEAT"
ef_mut m-nofiling 's/^      \[ "\$_a" = "1" \] .. \[ "\$_t" != "1" \] .. \[ "\$_n" != "1" \] .. printf .F-UNTAGGED.*$/      :/' ef-untagged "# probe

## BL-977

Filed from docs/analysis/x.md with no tag.
"

# ===== BL-817 ITEM 1 REMAINDER AND ITEM 2: the measuring script, the before/after pair, and the
# filing shape. Each offender world has a quiet twin one property apart:
#   ef-noscript  a sprint line naming only an unresolved script and a RESOLVING `.sh:NN` value
#                citation                                                    -> NO-SCRIPT
#   ef-dirbase   the same line naming a resolving directory plus a bare basename under it -> OK
#   ef-nofigs    `before` alone and the sprint pair `s319 to s320`           -> NO-FIGURES
#   ef-topair    `$2.23 to 1.24` and no before/after word                    -> OK
#   ef-filing    origin/main at a commit whose ledger holds BL-985 (tagged, no filing fields);
#                the working ledger adds BL-986 (no fields) and BL-987 (all three)
#                                       -> F-BASELINE, F-STEP, F-MOVEMENT for BL-986 only
#   ef-filing-noref  the same ledger with no origin/main                     -> OK, "origin/main is absent"
EF_SL_HEAD="# probe

## BL-981

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, $EF_SEAT,"
ef_world ef-noscript "$TMP/efnsc" "$EF_SL_HEAD measured by docs/analysis/gone.py from \`scripts/validate-backlog-receipts.sh:12\`, before 2.0 h and after 1.0 h; fell.
" "NO-SCRIPT BL-981|" 1
ef_world ef-dirbase "$TMP/efdb" "$EF_SL_HEAD \`docs/analysis/\` (m.py), before 2.0 h and after 1.0 h; fell.
" "" 0
EF_NOFIGS="$EF_SL_HEAD graph s319 to s320, measured by docs/analysis/m.py, 2.0 h before; fell.
"
ef_world ef-nofigs "$TMP/efnf" "$EF_NOFIGS" "NO-FIGURES BL-981|" 1
ef_world ef-topair "$TMP/eftp" "$EF_SL_HEAD measured by docs/analysis/m.py, \$/shard \$2.23 to 1.24; fell.
" "" 0
EF_FBASE="# probe

## BL-985

**DEFECT (efficiency).** filed before the arm. $EF_RUL
"
EF_FADDED="$EF_FBASE
## BL-986

**DEFECT (efficiency).** added, no fields. $EF_RUL

## BL-987

**DEFECT (efficiency).** added, every field. $EF_RUL

Baseline: s320
Step: \`gate-validation[implementation]\`
Expected movement: lead dollars per story fall.
"
ef_filing() { # ef_filing <name> <dir> <with-origin 0|1> <want-rows> <want-rc> <want-scope-text>
  local out rc_v got
  ef_seed "$2" "$EF_FBASE"
  ( cd "$2" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m base >/dev/null 2>&1 )
  [ "$3" = 1 ] && git -C "$2" update-ref refs/remotes/origin/main HEAD
  printf '%s' "$EF_FADDED" > "$2/docs/backlog.md"
  out="$( (cd "$2" && bash scripts/validate-backlog-receipts.sh --efficiency-only 2>&1) )"; rc_v=$?
  got="$(ef_rows "$out")"
  if [ "$rc_v" -eq "$5" ] && [ "$got" = "$4" ] && grep -qF -- "$6" <<<"$out"; then
    note "ok    $1 -- rc $rc_v, rows [${got}], scope [$6]"; eval "B_${1//-/_}=1"
  else
    note "FAIL  $1 -- rc $rc_v (want $5), rows [${got}] (want [$4]), scope text [$6] $(grep -qF -- "$6" <<<"$out" && echo present || echo ABSENT)"
    printf '%s\n' "$out" | grep -v '^FAIL: E' | sed 's/^/      /' | head -4; rc=1
  fi
}
ef_filing ef-filing "$TMP/effl" 1 "F-BASELINE BL-986|F-MOVEMENT BL-986|F-STEP BL-986|" 1 "FAIL: E: 3 efficiency finding(s)"
ef_filing ef-filing-noref "$TMP/efflnr" 0 "" 0 "filing shape: 0 added entr(y/ies) judged, not evaluated -- origin/main is absent"
# One mutant per new predicate, each made ALWAYS TRUE (the fixture-mutants convention: the guard
# matches nothing). The kill is REQUIRED to be the subject's own E0 refusing (exit 2): a world
# without origin/main reads rc 0 on the shipped subject too, so ef_mut's "turned green" branch would
# score a survivor of a filing mutant as a kill. The unmutated controls are ef-noscript, ef-nofigs
# and ef-filing above, which pass E0 on the same seed builder.
ef_mut0() { # ef_mut0 <name> <sed> <ledger>
  local d="$TMP/$1" out rc_v f wf
  ef_seed "$d" "$3"
  mut "$d" "$2" || return
  out="$( (cd "$d" && bash scripts/validate-backlog-receipts.sh --efficiency-only 2>&1) )"; rc_v=$?
  record "$1" "$rc_v" "$out"
  case "$1" in m-noscript) f=ef_noscript ;; m-nofigs) f=ef_nofigs ;; *) f=ef_filing ;; esac
  eval "wf=\${B_$f:-0}"
  score "$1" "$wf" "$1 -- refused by the subject's own E0 self-probe before the corpus"
}
ef_mut0 m-noscript 's/^eff_script_ok() {$/eff_script_ok() { return 0;/' "$EF_SL_HEAD measured by docs/analysis/gone.py, before 2.0 h and after 1.0 h; fell.
"
ef_mut0 m-nofigs 's/^eff_figs_ok() {$/eff_figs_ok() { return 0;/' "$EF_NOFIGS"
ef_mut0 m-nostep 's/^eff_step_ok() {$/eff_step_ok() { return 0;/' "$EF_FADDED"
ef_mut0 m-nobaseline 's/f != "@NONE@" \&\& f ~ \/^`?s3\[0-9\]\[0-9\](\[^0-9\]|\$)\/) bas = 1/1) bas = 1/' "$EF_FADDED"
ef_mut0 m-nomovement 's/f != "@NONE@" \&\& f ~ \/\[A-Za-z0-9\]\/) mv = 1/1) mv = 1/' "$EF_FADDED"
ef_mut0 m-noscope 's/ \&\& \[ -n "\${4:-}" \] \&\& grep -qxF -- "\$_l" "\$4"; then$/; then/' "$EF_FADDED"

# ===== THE RECEIPT / FIXTURE-ARM JOIN (BL-278). ==============================================
# A closed entry's receipt and the fixture arms covering the same subject divide the work: the
# receipt establishes the fix is present, the arms establish what the receipt cannot express. That
# division lived in a COMMENT in gate-verdict-grep-shape, and a comment goes stale in silence -- the
# next hand to widen the receipt reads an arm as redundant and deletes it. This arm asserts it.
#
# THE RECEIPT IS DERIVED, NEVER COPIED. It is read out of BL-040's archived entry at run time, so
# there is no second definition to drift; the entry id is the join key, the body is not in this
# file. A hardcoded body is the defect one level down, and BL-278's own receipt refuses it.
#
# THE SHAPES ARE DERIVED FROM THE PRODUCER. Every `mode == "..."` branch of gate-verdict-grep-shape's
# seed builder is a shape somebody decided to seed; each is built over a copy of gate-validation.md
# and the derived receipt run against it. A shape on which the receipt exits 0 is RECEIPT-BLIND --
# the receipt would close the entry over it -- so it MUST carry a row in one of that fixture's
# three verdict tables, and that row's verdict must be what that fixture's own join oracle actually
# returns on the seed: a row that is listed but not reproduced is not coverage, and a blind shape
# relabelled as a GREEN near-miss is the receipt's blindness blessed. A shape the receipt
# already fails (non-zero, STILL-LIVE in backlog-reverify.sh's polarity) is receipt-owned and needs
# no row. Known limit: deleting a seed branch AND its row together is invisible here.
#
# SELF-PROBED BEFORE THE CORPUS, IN BOTH DIRECTIONS, through the SAME scan function: a copy of the
# fixture with the `comment` row deleted must be reported UNCOVERED by name (a receipt-blind shape),
# and a copy with the `no-read` row deleted must stay quiet (the receipt exits 1 there, so it owns
# it). The two copies are one property apart and each is cmp-guarded, so a deletion that matched
# nothing cannot pass as a probe.
RJ_GVGS=""; RJ_GATE=""; RJ_ARCHIVE=""
for cand in "$DIR/../gate-verdict-grep-shape/run.sh"; do
  [ -f "$cand" ] && RJ_GVGS="$cand" && break
done
for cand in "$DIR/../../skills/ai-dlc/steps/gate-validation.md" "$DIR/../../../.claude/skills/ai-dlc/steps/gate-validation.md"; do
  [ -f "$cand" ] && RJ_GATE="$cand" && break
done
for cand in "$DIR/../../../docs/backlog.archive.md" "$DIR/../../docs/backlog.archive.md"; do
  [ -f "$cand" ] && RJ_ARCHIVE="$cand" && break
done
if [ -z "$RJ_GVGS" ] || [ -z "$RJ_GATE" ] || [ -z "$RJ_ARCHIVE" ]; then
  echo "FIXTURE BROKEN: receipt join cannot resolve gvgs='$RJ_GVGS' gate='$RJ_GATE' archive='$RJ_ARCHIVE'" >&2; exit 2
fi
RJ_ID="BL-040"
RJ_REC="$(awk -v id="$RJ_ID" '$0 == "## " id || index($0, "## " id " ") == 1 { f = 1; next }
  f && /^## / { exit }
  f && /^verify: sh / { sub(/^verify: sh /, ""); print; exit }' "$RJ_ARCHIVE")"
if [ -z "$RJ_REC" ]; then
  echo "FIXTURE BROKEN: no 'verify: sh' receipt derivable for $RJ_ID from $RJ_ARCHIVE" >&2; exit 2
fi
RJ="$TMP/rj"; mkdir -p "$RJ/tree/core/skills/ai-dlc/steps"
RJ_TGT="$RJ/tree/core/skills/ai-dlc/steps/gate-validation.md"

# rj_scan <gvgs-run.sh> -> one line per finding, then "SCANNED <n> BLIND <b> OWNED <o>".
# Exit 2 when the harness itself could not measure (a heredoc not found, a seed that did not build).
rj_scan() {
  local g="$1" w m want got r
  w="$(mktemp -d "$RJ/scan.XXXXXX")" || { echo "HARNESS mktemp failed"; return 2; }
  awk '/<<.GVSEEDPY.$/ { f = 1; next } /^GVSEEDPY$/ { f = 0 } f' "$g" > "$w/seed.py"
  awk '/<<.GVJOINPY.$/ { f = 1; next } /^GVJOINPY$/ { f = 0 } f' "$g" > "$w/join.py"
  [ -s "$w/seed.py" ] && [ -s "$w/join.py" ] || { echo "HARNESS seed.py or join.py not extractable"; return 2; }
  awk '/<<.GVMUTANTS.$/ { t = "M"; next } /<<.GVBOUNDS.$/ { t = "B"; next } /<<.GVNEARMISS.$/ { t = "N"; next }
    /^GV(MUTANTS|BOUNDS|NEARMISS)$/ { t = ""; next }
    t != "" && NF { split($0, a, "|"); w = (t == "M") ? a[2] : (t == "B") ? "BLOWN" : "GREEN"; print a[1] "|" w }' "$g" > "$w/rows"
  grep -oE 'mode == "[a-z0-9-]+"' "$w/seed.py" | sed 's/^mode == "//; s/"$//' > "$w/modes"
  local n=0 b=0 o=0
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    python3 "$w/seed.py" "$RJ_GATE" "$RJ_TGT" "$m" >/dev/null 2>&1 || { echo "HARNESS seed $m did not build"; return 2; }
    cmp -s "$RJ_GATE" "$RJ_TGT" && { echo "HARNESS seed $m changed no bytes"; return 2; }
    n=$((n + 1))
    ( cd "$RJ/tree" && bash -c "$RJ_REC" </dev/null >/dev/null 2>&1 ); r=$?
    if [ "$r" -ne 0 ]; then o=$((o + 1)); continue; fi
    b=$((b + 1))
    want="$(awk -F'|' -v m="$m" '$1 == m { print $2; exit }' "$w/rows")"
    if [ -z "$want" ]; then echo "UNCOVERED $m"; continue; fi
    got="$(python3 "$w/join.py" "$RJ_TGT" join 2>/dev/null)"
    case "$got" in "$want"*) ;; *) echo "UNREPRODUCED $m listed $want, oracle read '${got%% *}'" ;; esac
  done < "$w/modes"
  echo "SCANNED $n BLIND $b OWNED $o"
}

# Positive control first: the derived receipt must CLOSE on the live file, or every "blind" below
# is a receipt that fails everywhere rather than a shape it cannot see.
cp "$RJ_GATE" "$RJ_TGT"
( cd "$RJ/tree" && bash -c "$RJ_REC" </dev/null >/dev/null 2>&1 ); rj_live=$?
if [ "$rj_live" -ne 0 ]; then
  note "FAIL  rj-control -- $RJ_ID's derived receipt exits $rj_live on the live gate-validation.md, so it cannot distinguish any shape from the fix"; rc=1
else
  note "ok    rj-control -- $RJ_ID's receipt, derived from the archive, closes on the live gate-validation.md"
fi

# Self-probes, before the corpus.
rj_probe() { # rj_probe <name> <sed-expr>
  sed "$2" "$RJ_GVGS" > "$RJ/$1.sh"
  if cmp -s "$RJ_GVGS" "$RJ/$1.sh"; then echo "NOAPPLY"; return; fi
  rj_scan "$RJ/$1.sh"
}
rj_off="$(rj_probe probe-off '/^comment|/d')"
case "$rj_off" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-offender -- the probe did not measure: $rj_off"; rc=1 ;;
  *"UNCOVERED comment"*) note "ok    rj-probe-offender -- with the 'comment' row deleted the receipt-blind shape is reported UNCOVERED by name" ;;
  *) note "FAIL  rj-probe-offender -- a receipt-blind shape with no fixture row went unreported: $rj_off"; rc=1 ;;
esac
rj_nm="$(rj_probe probe-nm '/^no-read|/d')"
case "$rj_nm" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-near-miss -- the probe did not measure: $rj_nm"; rc=1 ;;
  *UNCOVERED*|*UNREPRODUCED*) note "FAIL  rj-probe-near-miss -- a shape the receipt already fails was reported as a gap: $rj_nm"; rc=1 ;;
  *SCANNED*) note "ok    rj-probe-near-miss -- with the receipt-owned 'no-read' row deleted the arm stays quiet" ;;
  *) note "FAIL  rj-probe-near-miss -- the scan printed no summary: $rj_nm"; rc=1 ;;
esac
# The row is present but its verdict is wrong: a blind shape relabelled as a near-miss.
rj_rl="$(rj_probe probe-relabel 's/^comment|RED|/comment|GREEN|/')"
case "$rj_rl" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-relabel -- the probe did not measure: $rj_rl"; rc=1 ;;
  *"UNREPRODUCED comment"*) note "ok    rj-probe-relabel -- a listed row whose verdict the oracle does not return is not coverage" ;;
  *) note "FAIL  rj-probe-relabel -- a relabelled row was accepted as coverage: $rj_rl"; rc=1 ;;
esac

# The corpus.
rj_out="$(rj_scan "$RJ_GVGS")"; rj_rc=$?
rj_sum="$(sed -n 's/^SCANNED \([0-9]*\) BLIND \([0-9]*\) OWNED \([0-9]*\)$/\1 \2 \3/p' <<<"$rj_out")"
rj_n="${rj_sum%% *}"; rj_b="$(printf '%s' "$rj_sum" | cut -d' ' -f2)"
if [ "$rj_rc" -ne 0 ] || [ -z "$rj_sum" ]; then
  note "FAIL  rj-join -- the scan did not measure: $rj_out"; rc=1
elif [ "$rj_b" -lt 1 ]; then
  note "FAIL  rj-join -- 0 receipt-blind shapes over $rj_n seeds: either the receipt got strong enough to retire the arms, or the scan reached nothing -- re-derive before reading it as either"; rc=1
elif grep -qE '^(UNCOVERED|UNREPRODUCED) ' <<<"$rj_out"; then
  note "FAIL  rj-join -- a shape $RJ_ID's receipt closes over has no fixture arm that fails it: $(grep -E '^(UNCOVERED|UNREPRODUCED) ' <<<"$rj_out" | tr '\n' ';')"; rc=1
else
  note "ok    rj-join -- $rj_b of $rj_n seeded shapes are receipt-blind, and every one carries a gate-verdict-grep-shape row its own oracle reproduces"
fi

# ===== BL-836. OPEN receipts that CANNOT MEASURE (R7), and closes on the branch whose receipts
# do not exit 0 (R8). =============================================================================
# One probe repository with a base commit and a branch commit, driven through the shipped script
# with --root (the subject ignores a probe tree otherwise: it resolves its root from the ledger)
# and --base at the base sha (a probe repository has no origin/main).
#   BL-861  stamped LANDED on the branch; its receipt greps a symbol the branch RENAMED -> R8 (d)
#   BL-862  OPEN; its receipt exits 9                                                 -> R7 (b)
#   BL-863  OPEN; its receipt exits 2, a reproduction code                            -> neither (a)
# Control: the unmutated subject FAILS naming exactly A under R8 and B under R7, and C nowhere.
# Mutants: c5-m1 the closed-on-branch population dropped (R8 must go silent on A); c5-m2 the
# cannot-measure ceiling back at 1 (R7 must go silent on B); c5-m3 exit 9 out of the FAIL set
# (the subject's self-probe refuses). Each is killed by its own row and only that row.
# BL-801 rides along unchanged from the main seed: it is the one SCORED receipt, so R2's zero-scored
# refusal does not pre-empt the two rows this arm reads.
c5_ledger() { # c5_ledger <stamp 0|1>
  printf '# Probe backlog\n\n'
  printf '## BL-801\n\nBody.\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'MARK801'"
  printf '## BL-861\n\n'; [ "$1" = 1 ] && printf '**LANDED (v0.0.1, verified probe).**\n\n'
  printf 'verify: sh grep -q %s probe/bg.sh\n\n' "'bg1_done'"
  printf '## BL-862\n\nverify: sh exit 9\n\n'
  printf '## BL-863\n\nverify: sh exit 2\n\n'
}
c5_seed() { # c5_seed <dir>
  local d="$1"
  seed "$d"
  printf 'bg1_done() { :; }\n' > "$d/probe/bg.sh"
  c5_ledger 0 > "$d/docs/backlog.md"
  ( cd "$d" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m c5base >/dev/null 2>&1 )
  git -C "$d" rev-parse HEAD > "$d/.c5base"
  printf 'bg1_convicts() { :; }\n' > "$d/probe/bg.sh"
  c5_ledger 1 > "$d/docs/backlog.md"
  ( cd "$d" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m c5branch >/dev/null 2>&1 )
  [ -s "$d/.c5base" ] || { echo "FIXTURE BROKEN: c5 probe has no base sha" >&2; exit 2; }
}
C5_ARGS="--max-prose-closable 9 --max-unscorable 9 --max-out-of-population 9 --max-unstable 0 --min-sh-receipts 0 --min-entries 0"
c5_run() { # c5_run <dir> -> output with rc on the last line
  local d="$1"
  ( cd "$TMP" && bash "$d/scripts/validate-backlog-receipts.sh" "$d/docs/backlog.md" --root "$d" --base "$(cat "$d/.c5base")" $C5_ARGS 2>&1; echo "rc=$?" )
}
c5_rows() { # c5_rows <output> -> "R8:<ids> R7:<ids>"
  printf 'R8:%s R7:%s' \
    "$(printf '%s\n' "$1" | awk -F'\t' '$1 == "FAIL: R8" { printf "%s,", $2 }')" \
    "$(printf '%s\n' "$1" | awk -F'\t' '$1 == "FAIL: R7" { printf "%s,", $2 }')"
}
c5_seed "$TMP/c5ctl"
c5_out="$(c5_run "$TMP/c5ctl")"
c5_got="$(c5_rows "$c5_out")"
if ! grep -qx 'rc=1' <<<"$c5_out"; then
  note "FAIL  c5-control -- the subject exited $(tail -1 <<<"$c5_out") over a branch closing BL-861 on a renamed symbol and carrying an exit-9 open receipt; it must exit 1"
  printf '%s\n' "$c5_out" | grep -E '^FAIL|SELF-PROBE|validate-backlog-receipts:' | sed 's/^/      /' | head -5; rc=1
elif [ "$c5_got" != "R8:BL-861, R7:BL-862," ]; then
  note "FAIL  c5-control -- rows read '$c5_got', want 'R8:BL-861, R7:BL-862,' (BL-863 exits 2, a reproduction, and must be in neither)"; rc=1
elif ! grep -q '^CLOSED-POPULATION: 1 sh receipt(s) run over merge-base ' <<<"$c5_out"; then
  note "FAIL  c5-control -- no CLOSED-POPULATION line naming 1 receipt run"; rc=1
else
  note "ok    c5-control -- R8 names BL-861 (closed on the branch, renamed symbol, exit 1), R7 names BL-862 (open, exit 9), BL-863 (open, exit 2) is in neither"
  C5_BASE_OK=1
fi
c5_mut() { # c5_mut <name> <sed> <want-rows> <what> [<target seed id a self-probe refusal must name>]
  local n="$1" d="$TMP/$1" o r
  c5_seed "$d"
  mut "$d" "$2" || return
  o="$(c5_run "$d")"
  r="$(tail -1 <<<"$o" | sed 's/^rc=//')"
  eval "C5WANT_${n//-/_}=\$3; C5TARGET_${n//-/_}=\${5:-}"
  record "$n" "$r" "$o"
  side "$n" "rows=$(c5_rows "$o")"
  score "$n" "${C5_BASE_OK:-0}" "$n -- $4"
}
# Both mutants sit where the self-probe cannot see them -- the corpus call and the shipped ceiling --
# so the CORPUS row is what scores each. c5-m3 empties the FAIL set itself, which the self-probe's
# seed (b) refuses before the corpus, and is asserted as that.
c5_mut c5-m1 's#^CLOSED_OUT="\$(score_closed "\$LEDGER" "\$SUBJECT_ROOT" "\$BASE_REF")" || exit 2$#CLOSED_OUT=""#' \
  "R8: R7:BL-862," "with the closed-on-branch population dropped, the renamed-symbol close is never run"
c5_mut c5-m2 's|^DEFAULT_MAX_CM=0$|DEFAULT_MAX_CM=1|' \
  "R8:BL-861, R7:" "with the cannot-measure ceiling back at 1, the exit-9 open receipt passes"
c5_mut c5-m3 's|^      9) printf .exit-9. ;;$|      9) : ;;|' \
  "R8:BL-861, R7:" "with exit 9 out of the FAIL set, seed (b) no longer reads cannot-measure" BL-972

# ===== BL-836, RE-ENTRY (BR_RECEIPTS_RUNNING). A receipt that invokes pre-push re-enters this
# validator from inside the run executing it, through R8 (closed) or through the open scorer (R7). The probe repository carries a `.githooks/pre-push` holding the receipts step's own
# invocation, and BL-864, stamped LANDED on the branch, runs that hook and asserts the inner run
# printed `CLOSED-POPULATION: SKIPPED`. The seed BOUNDS ITSELF: the receipt counts its depth in
# C5R_DEPTH and exits 7 at depth 1, so a validator ignoring the sentinel stops after two runs
# instead of hanging. Every receipt run appends one line to C5R_LOG.
#   control  rc 0, no R8 row, BL-864 run once (log 1 line), the inner skip line seen by the receipt
#   c5-m4    the sentinel ignored on entry: BL-864 FAILs under R8, the log holds 2 lines (bounded)
# The OPEN half (BL-865): the same receipt on an OPEN entry, asserting `OPEN-POPULATION: SKIPPED`.
# The scorer runs an open receipt more than once (base, re-read, seed), so its run count is not 1;
# the control's count is recorded and the mutant must exceed it, with the receipt's base exit
# flipping from 0 to non-zero because the inner run no longer says SKIPPED.
#   c5r-open-control  rc 0, BL-865's row reads ALREADY-PASSING (base exit 0), the inner skip line seen
#   c5-m4 (open)      the sentinel ignored on entry: BL-865 no longer ALREADY-PASSING, more runs
c5r_seed() { # c5r_seed <dir> <closed|open> [<sed>] -- a mutant is applied BEFORE the base commit, so
  # the checkout every receipt runs in, and the validator the hook re-enters, are the mutated copy.
  local d="$1" mode="$2"
  seed "$d"
  if [ -n "${3:-}" ]; then mut "$d" "$3" || return 1; fi
  mkdir -p "$d/.githooks"
  printf '#!/usr/bin/env bash\nexec bash scripts/validate-backlog-receipts.sh docs/backlog.md --base HEAD~1 %s\n' "$C5_ARGS" > "$d/.githooks/pre-push"
  c5r_ledger() { # c5r_ledger <stamp 0|1> <closed|open>
    local id=BL-864 pop=CLOSED
    [ "$2" = open ] && { id=BL-865; pop=OPEN; }
    printf '# Probe backlog\n\n'
    printf '## BL-801\n\nBody.\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'MARK801'"
    printf '## %s\n\n' "$id"; [ "$1" = 1 ] && [ "$2" = closed ] && printf '**LANDED (v0.0.1, verified probe).**\n\n'
    printf 'verify: sh echo run >> "${C5R_LOG:-/dev/null}"; dp="${C5R_DEPTH:-0}"; [ "$dp" -lt 1 ] || exit 7; o="$(C5R_DEPTH=$(( dp + 1 )) bash .githooks/pre-push 2>&1)"; grep -q "^%s-POPULATION: SKIPPED " <<<"$o"\n\n' "$pop"
  }
  c5r_ledger 0 "$mode" > "$d/docs/backlog.md"
  ( cd "$d" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m c5rbase >/dev/null 2>&1 )
  git -C "$d" rev-parse HEAD > "$d/.c5base"
  c5r_ledger 1 "$mode" > "$d/docs/backlog.md"
  printf 'branch\n' > "$d/probe/branch.txt"
  ( cd "$d" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m c5rbranch >/dev/null 2>&1 )
  [ -s "$d/.c5base" ] || { echo "FIXTURE BROKEN: c5r probe has no base sha" >&2; exit 2; }
}
# THE TIMEOUT GUARD. The depth cap above bounds the recursion; the watchdog bounds everything else,
# so a regression that hangs this arm turns into a FAIL instead of a wedged suite. It kills only
# the pid it started.
C5R_TIMEOUT=600
c5r_case() { # c5r_case <name> <closed|open> <sed-or-empty> -> sets C5R_OUT, C5R_RUNS
  local d="$TMP/$1" p w
  c5r_seed "$d" "$2" "$3" || return 1
  : > "$TMP/$1.log"
  ( export C5R_LOG="$TMP/$1.log"; c5_run "$d" > "$TMP/$1.out" ) & p=$!
  ( sleep "$C5R_TIMEOUT" & s=$!; trap 'kill -TERM "$s" 2>/dev/null; exit 0' TERM; wait "$s"; kill -TERM "$p" 2>/dev/null ) >/dev/null 2>&1 & w=$!
  wait "$p"
  kill -TERM "$w" 2>/dev/null; wait "$w" 2>/dev/null
  C5R_OUT="$(cat "$TMP/$1.out")"
  grep -q '^rc=' <<<"$C5R_OUT" || C5R_OUT="$C5R_OUT
rc=timeout"
  C5R_RUNS="$(grep -c . "$TMP/$1.log")" || C5R_RUNS=0
  return 0
}
c5r_row() { printf '%s\n' "$C5R_OUT" | awk -F'\t' -v id="$1" '$2 == id { print $1 "|" $3 }'; }
# c5-m4: the sentinel ignored on entry -- the run-level decision is never "re-entry". It edits the
# CALL, not re_entry_of, so the self-probe (which drives re_entry_of directly) still passes and the
# corpus arm below is what kills it.
C5R_M4='s|^RE_ENTRY="\$(re_entry_of "\${BR_RECEIPTS_RUNNING:-}" "\$LEDGER_KEY")"$|RE_ENTRY=""|'
if c5r_case c5r-ctl closed ""; then
  c5r_rows="$(c5_rows "$C5R_OUT")"
  if ! grep -qx 'rc=0' <<<"$C5R_OUT"; then
    note "FAIL  c5r-control -- a closed receipt re-entering the validator through pre-push exited $(tail -1 <<<"$C5R_OUT"), rows '$c5r_rows', receipt runs $C5R_RUNS; it must exit 0 with BL-864 run once"
    printf '%s\n' "$C5R_OUT" | grep -E '^FAIL|SELF-PROBE|CLOSED-POPULATION' | sed 's/^/      /' | head -5; rc=1
  elif [ "$C5R_RUNS" != 1 ]; then
    note "FAIL  c5r-control -- BL-864's receipt ran $C5R_RUNS times, want exactly 1 (R8 once, the inner run skipping it)"; rc=1
  elif ! grep -q '^CLOSED-POPULATION: 1 sh receipt(s) run over merge-base .*, 0 not exiting 0\.$' <<<"$C5R_OUT"; then
    note "FAIL  c5r-control -- no CLOSED-POPULATION line naming 1 receipt run and 0 failing"; rc=1
  else
    note "ok    c5r-control -- BL-864 re-entered the validator through pre-push, the inner run printed SKIPPED, R8 ran it once and it exited 0"
    C5R_BASE_OK=1
  fi
fi
if c5r_case c5-m4 closed "$C5R_M4"; then
  record c5-m4 "$(tail -1 <<<"$C5R_OUT" | sed 's/^rc=//')" "$C5R_OUT"
  side c5-m4 "rows=$(c5_rows "$C5R_OUT")"
  side c5-m4 "runs=$C5R_RUNS"
  score c5-m4 "${C5R_BASE_OK:-0}" "c5-m4 -- with the sentinel ignored R8 re-ran inside itself: BL-864 FAILs and the receipt ran twice against the control's once"
fi
C5R_OPEN_RUNS=""
if c5r_case c5r-open-ctl open ""; then
  c5r_r="$(c5r_row BL-865)"
  if ! grep -qx 'rc=0' <<<"$C5R_OUT"; then
    note "FAIL  c5r-open-control -- an OPEN receipt re-entering the validator through pre-push exited $(tail -1 <<<"$C5R_OUT"), row '$c5r_r', receipt runs $C5R_RUNS; it must exit 0"
    printf '%s\n' "$C5R_OUT" | grep -E '^FAIL|SELF-PROBE|POPULATION' | sed 's/^/      /' | head -5; rc=1
  else
    # The corpus row prints STATUS and paths only; ALREADY-PASSING is the status of a base exit 0.
    case "$c5r_r" in
      "ALREADY-PASSING|"*) note "ok    c5r-open-control -- BL-865 (OPEN) re-entered the validator through pre-push, the inner run printed OPEN-POPULATION: SKIPPED, row ALREADY-PASSING (base exit 0), $C5R_RUNS receipt run(s)"; C5R_OPEN_RUNS="$C5R_RUNS" ;;
      *) note "FAIL  c5r-open-control -- BL-865's row read '$c5r_r', want ALREADY-PASSING (base exit 0: the inner run must say OPEN-POPULATION: SKIPPED)"; rc=1 ;;
    esac
  fi
fi
# c5-m4-open is the SAME mutation over an OPEN receipt. It is a second world for one mutant, not a
# second mutant: the closed world above decides c5-m4 on every push, and this cell is measured only
# under --matrix (the open scorer's export of the sentinel is held on every push by c5r-open-control
# and by c5-m5).
if [ "$MATRIX" = 1 ] && c5r_case c5-m4-open open "$C5R_M4"; then
  c5r_r="$(c5r_row BL-865)"
  record c5-m4-open "$(tail -1 <<<"$C5R_OUT" | sed 's/^rc=//')" "$C5R_OUT"
  side c5-m4-open "runs=$C5R_RUNS"
  side c5-m4-open "ctlruns=$C5R_OPEN_RUNS"
  side c5-m4-open "row=$c5r_r"
  score c5-m4-open "${C5R_OPEN_RUNS:+1}" "c5-m4-open -- with the sentinel ignored the open scorer re-ran inside itself and BL-865 is no longer ALREADY-PASSING" c5_open
fi
# The two exports, each dropped: the self-probe's BL-976 (open) and BL-987 (closed) refuse first.
c5_mut c5-m5 's|BR_RECEIPTS_RUNNING="\$_sl_key" xargs|xargs|' \
  "unreachable" "with the sentinel no longer exported to OPEN receipts, seed BL-976 fails" BL-976
c5_mut c5-m6 's|BR_RECEIPTS_RUNNING="\$_sc_key" xargs|xargs|' \
  "unreachable" "with the sentinel no longer exported to CLOSED receipts, seed BL-987 fails" BL-987
# The FAIL set's 126 arm and its >= 128 branch, each removed: seeds BL-977 and BL-978 refuse.
c5_mut c5-m7 "/^      126) printf 'exit-126' ;;\$/d" \
  "unreachable" "with the 126 arm deleted, seed BL-977 no longer reads cannot-measure=exit-126" BL-977
c5_mut c5-m8 's|^      \*) if \[ "\$1" -ge 128 \]; then|      *) if [ "$1" -ge 999 ]; then|' \
  "unreachable" "with the signal branch moved to >= 999, seed BL-978 no longer reads cannot-measure=exit-130" BL-978
# A rotation without its new-to-the-archive condition: the retitled archive heading BL-988 is run.
c5_mut c5-m9 '/^    grep -qxF -- "\$_l" <<<"\$_sc_archwas" \&\& continue$/d' \
  "unreachable" "with the new-to-the-archive condition dropped, the retitled archive heading BL-988 is run as a rotation" BL-988
# The rejected spelling of that condition -- removed from the live ledger -- drops a release's own
# close (BL-989: filed and rotated on the branch, live at neither end).
c5_mut c5-m10 's|^    grep -qxF -- "\$_l" <<<"\$_sc_archwas" \&\& continue$|    git -C "$_sc_root" show "${_sc_mb}:${_sc_rel}" 2>/dev/null \| grep -qF -- "## $_l" \|\| continue|' \
  "unreachable" "with the condition spelled removed-from-live, the filed-and-rotated close BL-989 is not run" BL-989
# The re-entry decision keyed on PRESENCE only, the shape before the key: a validator a receipt
# starts over a ledger of its own seeding reads as a re-entry (BL-227's archived receipt).
c5_mut c5-m11 "s|^  \\[ -n \"\\\$1\" \\] \\&\\& \\[ \"\\\$1\" = \"\\\$2\" \\] \\&\\& printf '1'\$|  [ -n \"\$1\" ] \\&\\& printf '1'|" \
  "unreachable" "with the skip keyed on presence only, a foreign-ledger run reads as a re-entry and would score nothing" BL-979
# The key without its repository half: two repositories with a ledger at one relative path share it.
c5_mut c5-m12 "s/^  printf '%s|%s' \"\\\$_lk_cd\" \"\\\$_lk_led\"\$/  printf '%s' \"\$_lk_led\"/" \
  "unreachable" "with the common dir dropped from the key, two repositories' docs/backlog.md share one key" BL-979

# --- per-push twins ----------------------------------------------------------------------------
# A TWIN is a different arm that the MEASURED matrix shows GREEN for the mutant. Every push reads it
# off the mutant's own capture, so a kill that spreads past its deciding arm is seen at no cost.
# The table is generated from a `--matrix` run; re-measure whenever an arm or a mutant changes.
twin_of() {
  case "$1" in
# TWINS-BEGIN
    m1) echo m6 ;;
    m3) echo m6 ;;
    m2c) echo m3 ;;
    m4) echo m3 ;;
    m14b) echo m3 ;;
    m5b) echo m7b ;;
    m12) echo m7b ;;
    m13) echo m7b ;;
    m16) echo m7b ;;
    gitdir-mutant) echo m7b ;;
    m6) echo m1 ;;
    m7b) echo m16 ;;
    m15) echo m16 ;;
    m8b-mut) echo m8c_mut ;;
    m8d-mut) echo m6 ;;
    m8c-mut) echo m8b_mut ;;
    m8e-mut) echo m8c_mut ;;
    m17) echo m18 ;;
    m18) echo m17 ;;
    m-loose) echo m_heading_only ;;
    m-heading-only) echo m_loose ;;
    m-memo-unset) echo m_memo_name ;;
    m-memo-name) echo m_memo_derive ;;
    m-memo-derive) echo m_memo_unset ;;
    m-noclose) echo m6 ;;
    m-widenostep) echo m6 ;;
    m-nopathnarrow) echo m6 ;;
    m-noseat) echo m6 ;;
    m-seatword) echo m6 ;;
    m-nofiling) echo m6 ;;
    m-noscript) echo m6 ;;
    m-nofigs) echo m6 ;;
    m-nostep) echo m6 ;;
    m-nobaseline) echo m6 ;;
    m-nomovement) echo m6 ;;
    m-noscope) echo m6 ;;
    c5-m1) echo c5_m2 ;;
    c5-m4) echo c5_m1 ;;
    c5-m2) echo c5_m1 ;;
    c5-m3) echo c5_m5 ;;
    c5-m5) echo c5_m6 ;;
    c5-m6) echo c5_m5 ;;
    c5-m7) echo c5_m8 ;;
    c5-m8) echo c5_m7 ;;
    c5-m9) echo c5_m10 ;;
    c5-m11) echo c5_m10 ;;
    c5-m12) echo c5_m10 ;;
    c5-m10) echo c5_m9 ;;
    c5-m4-open) echo c5_m4 ;;
    *) echo "" ;;
# TWINS-END
  esac
}
for m in $SCORED; do
  t="$(twin_of "$m")"
  [ -n "$t" ] && [ "$t" != "-" ] || continue
  if "arm_$t" "$m"; then bad "[twin] $m -- the twin arm $t TRIPPED on $m's capture, so the kill is not confined to its deciding arm"
  else ok "[twin] $m -- twin $t stays green on $m's capture: the kill is confined to its deciding arm"; fi
done
if [ "$MATRIX" = 1 ]; then
  mx_caps="$(ls "$REC" | sed -n 's/\.rc$//p')"
  mx_arms="$(all_arms)"
  for m in $mx_caps; do
    for a in $mx_arms; do
      if "arm_$a" "$m"; then matrix_row "$m" "$a" "$(r_rc "$m")" TRIPPED yes
      else matrix_row "$m" "$a" "$(r_rc "$m")" GREEN no; fi
      MROWS=$((MROWS + 1))
    done
  done
  mx_nc="$(printf '%s\n' $mx_caps | grep -c .)"; mx_na="$(printf '%s\n' $mx_arms | grep -c .)"
  if [ "$MROWS" -eq $((mx_nc * mx_na)) ] && [ "$MROWS" -gt 0 ]; then ok "[MX] the matrix run measured $MROWS cells for $mx_nc captures x $mx_na arms"
  else bad "[MX] matrix rows=$MROWS for $mx_nc captures x $mx_na arms"; fi
else
  if [ "$MROWS" -eq 0 ] && [ ! -f "$REC/c5-m4-open.rc" ]; then ok "[MX] a plain run executed no matrix-only cell (rows=0, no c5-m4-open capture)"
  else bad "[MX] a plain run executed matrix-only work (rows=$MROWS)"; fi
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-receipt-binding -- control green, every mutant caught by its own assertion"
fi
exit "$rc"
