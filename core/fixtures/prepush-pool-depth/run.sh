#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# prepush-pool-depth -- a fixture that drives a pre-push hook must not be able to recurse.
#
# THE DEFECT. A fixture drives a copy of the hook, the hook opens its own fixture pool over the
# fixtures it can see, and one of those fixtures drives a hook again. Nothing bounded the nesting;
# a live process table showed nine hooks nested seven deep, each with a 12-wide pool.
#
# THE GUARD, in the FIXTURE_POOL block both hooks carry (I66 holds them to one program):
#   * the pool exports PREPUSH_POOL_DEPTH = its own depth + 1 to every fixture it dispatches;
#   * a hook that STARTS at depth 1 keeps a pool of one or two and makes ANY other AI_DLC_FIXTURE_JOBS two:
#     larger, zero (BSD `xargs -P 0` is unlimited), not a number, or longer than five digits;
#   * a marker SET to a non-number or to more than five digits is depth 2 and refuses (fail closed);
#   * a hook that starts at depth 2 or more opens no pool and says so;
#   * the marker carries no AI_DLC_ prefix, because fixtures scrub that whole prefix before driving a hook.
#
# THE SUBJECT IS THE BLOCK, EXTRACTED between its sentinels and sourced in a scratch repository
# (the way readset-skip drives it). The real hook is never run here: it runs a whole gate.
#
# WHAT RUNS WHERE. I66 compares the two hooks' blocks (comments and blanks stripped, fixture root mapped),
# so the two blocks are one program. The arm battery and the watcher (nested-root) section therefore run
# against the FIRST resolved hook only, and the second hook keeps ONE end-to-end nest chain over its own
# fixture root. Measured by trace on the second hook's watcher drives: every traced line came from the
# block itself, none from outside it, so a second copy of those drives could only repeat the first.
#
# THE MUTANTS are cmp -s guarded COPIES of the resolved block. Each mutant is a row of the matrix below:
# the arm cells it moves (decides) and a cell of another arm that stays green (twins).
#
# MUTANT-MATRIX not-exported decides=raw_d0,raw_d1,nest_started,nest_depths,nest_b_present,nest_refusal_line twins=scrub_same
# MUTANT-MATRIX not-incremented decides=raw_d0,raw_d1,nest_started,nest_depths,nest_refusal_line twins=scrub_same
# MUTANT-MATRIX cap-ignored decides=width_d1_j12,width_d1_j12x,width_d1_j0,width_d1_jabc,width_d2_j12,width_d1_jlong,obs_d1_max twins=width_d1_j1
# MUTANT-MATRIX zero-admitted decides=width_d1_j0 twins=width_d1_jabc
# MUTANT-MATRIX nonnum-admitted decides=width_d1_jabc twins=width_d1_j0
# MUTANT-MATRIX jlong-admitted decides=width_d1_jlong twins=width_d1_jabc
# MUTANT-MATRIX depth-long-admitted decides=depth_long twins=depth_nonnum
# MUTANT-MATRIX depth-nonnum-zero decides=depth_nonnum twins=depth_long
# MUTANT-MATRIX octal-08 decides=depth_08 twins=depth_long
# MUTANT-MATRIX ai-dlc-named decides=scrub_same,nest_started,nest_depths,nest_b_present,nest_refusal_line twins=raw_d1
# MUTANT-MATRIX notice-at-load decides=notice_load twins=width_d1_j12
# MUTANT-MATRIX no-refusal decides=refuse_rc,refuse_line,refuse_ran,refuse_d5_rc,nest_started,nest_depths,nest_refusal_line twins=nest_b_present
# MUTANT-MATRIX leaks decides=leak twins=raw_d0
# MUTANT-MATRIX pool-capped-5 decides=obs_d0_max twins=raw_d0
# MUTANT-MATRIX i66-fork-seed decides=i66_seeded twins=i66_clean
# MUTANT-MATRIX m-appendreg decides=pn_ord twins=pn_grow
# MUTANT-MATRIX m-nofifoguard decides=pn_fifo twins=pn_ord
# MUTANT-MATRIX m-nomark decides=pn_grow twins=pn_ord
# MUTANT-MATRIX m-noread decides=pn_grow twins=pn_ord
# MUTANT-MATRIX m-novalidate decides=pn_hlink,pn_hout twins=pn_ord
# MUTANT-MATRIX td-old-traps decides=td_term,td_intp twins=td_queue
# MUTANT-MATRIX td-no-stop decides=td_term,td_queue twins=td_rc
# MUTANT-MATRIX td-plain-amp decides=td_term,td_int,td_intp twins=td_queue
# MUTANT-MATRIX td-no-pgid decides=td_decoy twins=td_term
# MUTANT-MATRIX ps-rewait decides=ps_sig twins=ps_exit
# MUTANT-MATRIX-DYNAMIC finish_mutant why=the one emission site passes the mutant name as a variable; each of the twenty-five literal callers (mutant, pn_eval, td_eval, the I66 arm and the pool_stop arm) has its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/prepush-pool-depth/run.sh --matrix
#
# The matrix is re-measured whenever an arm or a mutant is added or changed, with the command above, run
# from the repository root; its log names every mutant's dead cells. Each mutant co-trips no other arm
# than the ones it decides, measured at authoring. The decides and twins of a mutant are READ FROM THE
# ROWS ABOVE at run time (mrow), so the header cannot drift from what runs. A plain run drives, per
# mutant, only its decides cells and its twin cells, and requires that every cell it drove which moved is
# in decides. --matrix drives every cell of the mutant's family: the arm cells for the pool mutants, the
# watcher cells (pn_*) for the m-* mutants. The pool mutants are not driven through the watcher cells and
# the m-* mutants are not driven through the pool cells.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset PREPUSH_POOL_DEPTH
MATRIX=0; [ "${1:-}" = --matrix ] && MATRIX=1
MX_RAN=0
# PD_BARRIER_CEIL: the depth-0 barrier's ceiling in seconds, digits only with no leading zero, default 30. drive exports it so
# the stubs derive their own cap from it (ceiling + 10); mutant() passes a smaller one to ONE mutant.
case "${PD_BARRIER_CEIL:-}" in ''|*[!0-9]*|0*|????*) PD_BARRIER_CEIL=30 ;; esac
# The watcher section's clocks. PN_STALL is the pool's own AI_DLC_POOL_STALL knob (polls with no progress
# before a refusal; the block reads it from the environment, so lowering it edits no hook). PN_SECS is how
# long the nested stub keeps writing or sleeping, and must exceed three windows so a silent unit crosses
# the refusal threshold while a growing one does not. The watcher polls once a second (hard-coded in the
# block's xargs body), so one window is PN_STALL seconds.
PN_STALL=3; PN_SECS=10

asserts=0; fails=0
ok()     { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad()    { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "prepush-pool-depth: FIXTURE BROKEN" >&2; exit 2; }
# SIGINT IGNORED ON ENTRY IS A REFUSAL, NOT A RED. A plain `&` from a non-interactive shell starts this
# fixture with SIGINT ignored, every drive inherits that, and bash cannot re-enable a signal ignored at
# entry: the hook's `trap 'pool_stop 130' INT` and the workers' `trap pool_abort INT` never fire, so the
# INT cells (td_int, td_intp) and the mutants they score read red against a correct hook. Setting a trap
# on an ignored-at-entry signal silently does nothing, so `trap -p INT` then reads empty.
trap ':' INT; _ti="$(trap -p INT)"; trap - INT
[ -n "$_ti" ] || { echo "prepush-pool-depth: FIXTURE BROKEN: launched with SIGINT ignored (a plain & from a non-interactive shell); its INT cells cannot fire. Run it in the foreground or under set -m." >&2; exit 2; }
MUT_LIB="$(cd "$(dirname "$0")/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $0" >&2; exit 2; }
. "$MUT_LIB"

echo "prepush-pool-depth:"
if [ "$MATRIX" = 1 ]; then echo "  mode: FULL (--matrix: every mutant against every cell of its family)"
else echo "  mode: PUSH (each mutant drives its decides cells and its twin cells only)"; fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || broken "not in a git repo"
HOOKS=""
for c in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$c" ] && HOOKS="$HOOKS $c"
done
[ -n "$HOOKS" ] || broken "no pre-push hook in either layout from $ROOT"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/prepush-pool-depth.XXXXXX")" || broken "mktemp failed"
trap '[ -s "$WORK/barrier.pid" ] && kill "$(cat "$WORK/barrier.pid")" 2>/dev/null; rm -rf "$WORK"' EXIT

# the header rows are the single source of decides and twins
mrow() { # mrow <mutant> decides|twins -> the comma list from the MUTANT-MATRIX row
  awk -v n="$1" -v f="$2" '$1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n { for (i = 4; i <= NF; i++) { split($i, kv, "="); if (kv[1] == f) print kv[2] } }' "$0"
}

# A probe world: a git repository whose fixture root holds stub fixtures.
# Each stub records, to $PD_LOG, the marker it was handed (name-agnostic: any *POOL_DEPTH variable),
# the same after the scrub idiom every real fixture opens with, and how many stubs were in flight.
mkworld() { # mkworld <dir> <fxroot> <n>
  local t="$1" fxr="$2" n="$3" i
  mkdir -p "$t/$fxr" || return 1
  for i in $(seq 1 "$n"); do
    mkdir -p "$t/$fxr/fx$i"
    cat > "$t/$fxr/fx$i/run.sh" <<'FX'
#!/usr/bin/env bash
raw="$(env | sed -n 's/^[A-Za-z_]*POOL_DEPTH=//p' | sort -n | tail -1)"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
scr="$(env | sed -n 's/^[A-Za-z_]*POOL_DEPTH=//p' | sort -n | tail -1)"
: > "$PD_FLIGHT/$$"
if [ -n "${PD_RELEASE:-}" ]; then
  # THE BARRIER: hold until the driver releases, the flight dir is gone (the driver's WORK was
  # removed), or this stub's own cap -- the driver's ceiling + 10, so a stub never drains before the
  # driver has counted and never outlives the run.
  s=$SECONDS; cap=$(( ${PD_BARRIER_CEIL:-30} + 10 ))
  while [ ! -e "$PD_RELEASE" ] && [ -d "$PD_FLIGHT" ] && [ $((SECONDS - s)) -lt "$cap" ]; do sleep 0.1; done
else
  sleep "${PD_SLEEP:-0}"
fi
ls "$PD_FLIGHT" | wc -l | tr -d ' ' >> "$PD_LOG.flight"
rm -f "$PD_FLIGHT/$$"
printf 'raw=%s scrubbed=%s\n' "${raw:-_}" "${scr:-_}" >> "$PD_LOG"
exit 0
FX
  done
  ( cd "$t" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
}

# drive <block> <world> <depth|-> <jobs|-> -> prints "<rc>" and leaves output in $WORK/last.out
# The block is sourced in a subshell standing in the world; AI_DLC_READSET_LIVE_TRACE=0 keeps the
# launcher out, and the log files are fresh per drive. The marker left in the sourcing shell after the
# pool ran is written to $WORK/leak.v.
#
# PD_BARRIER=1 drives the six stubs through a BARRIER instead of a sleep, so the depth-0 width is a
# count that does not depend on scheduling. Each stub creates its flight file and then holds until
# the driver writes $WORK/release (or the flight dir is gone, or its own cap of PD_BARRIER_CEIL + 10
# seconds). A poller started beside run_fixtures counts the flight dir until all six are in flight,
# with a PD_BARRIER_CEIL ceiling (default 30s; mutant pool-capped-5 alone passes 3s), writes
# that count to $WORK/barrier.n and only then releases the stubs. A pool narrower than six can never
# hold six at once, so it reads 5 or fewer and the ceiling ends it; a slow box only delays the
# count. A sleep-overlap read (each stub sleeping 0.3s and ls-counting its peers) read 3 and 5
# against 6 under load with no hook defect. The poller's pid is recorded in $WORK/barrier.pid for
# the EXIT trap, which kills that pid alone; removing $WORK then releases any stub still holding.
drive() {
  local blk="$1" t="$2" depth="$3" jobs="$4" rc
  rm -rf "$WORK/flight"; mkdir -p "$WORK/flight"; : > "$WORK/log"; : > "$WORK/log.flight"
  rm -f "$WORK/release" "$WORK/barrier.n" "$WORK/barrier.pid" "$WORK/leak.v"
  rc="$( cd "$t" && {
    [ "$depth" = - ] || export PREPUSH_POOL_DEPTH="$depth"
    [ "$jobs" = - ] || export AI_DLC_FIXTURE_JOBS="$jobs"
    export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PD_LOG="$WORK/log" PD_FLIGHT="$WORK/flight" PD_SLEEP="${PD_SLEEP:-0}" PD_BARRIER_CEIL="$PD_BARRIER_CEIL"
    . "$blk" > "$WORK/load.out" 2>&1
    bp=""
    if [ -n "${PD_BARRIER:-}" ]; then
      export PD_RELEASE="$WORK/release"
      ( n=0; s=$SECONDS
        while :; do
          n="$(ls "$WORK/flight" | wc -l | tr -d ' ')"
          [ "$n" -ge 6 ] && break
          [ $((SECONDS - s)) -ge "$PD_BARRIER_CEIL" ] && break
          sleep 0.1
        done
        printf '%s\n' "$n" > "$WORK/barrier.n"; : > "$WORK/release" ) > /dev/null 2>&1 &
      bp=$!; printf '%s\n' "$bp" > "$WORK/barrier.pid"
    fi
    run_fixtures > "$WORK/last.out" 2>&1; r=$?
    printf '%s\n' "${PREPUSH_POOL_DEPTH-unset}" > "$WORK/leak.v"
    if [ -n "$bp" ]; then wait "$bp"; rm -f "$WORK/barrier.pid"; fi
    echo "$r"
  } )"
  printf '%s' "$rc"
}
# barrier_count: the driver's count at release ("_" if the poller never wrote one)
barrier_count() { local n; n="$(cat "$WORK/barrier.n" 2>/dev/null)"; printf '%s' "${n:-_}"; }
maxflight() { sort -n "$WORK/log.flight" 2>/dev/null | tail -1; }
raws() { sed -n 's/^raw=\([^ ]*\) .*/\1/p' "$WORK/log" | sort -u | tr '\n' ' ' | sed 's/ *$//'; }

# ------------------------------------------------------------------ hooks and blocks ------------
HN=0; FXRS=""
for HOOK in $HOOKS; do
  HN=$((HN+1))
  sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK" > "$WORK/block$HN.sh"
  [ -s "$WORK/block$HN.sh" ] || broken "extracted an empty FIXTURE_POOL block from $HOOK"
  FXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$WORK/block$HN.sh" | sort -u)"
  [ "$(printf '%s\n' "$FXR" | grep -c .)" -eq 1 ] || broken "read '$FXR' as the block's fixture root; need exactly one"
  printf '%s\n' "$FXR" > "$WORK/block$HN.fxr"
  FXRS="$FXRS $FXR"
done

# ------------------------------------------------------------------ the constructed nest ------
# THREE LEVELS OF STUB IN ONE WORLD: the outer pool dispatches stub A; A drives the block over its own
# tree holding stub B; B drives it again over a tree holding stub C. Count which stubs STARTED.
# Guarded: A runs, B runs (depth 1), C never starts (B's pool refuses at depth 2). The same world is
# driven for every block and every mutant: the stubs read the block to source from NEST_BLK, and sit
# under EVERY hook's fixture root, so each block's pool sees its own root's stubs.
NW="$WORK/nestworld"
nest_stub() { # nest_stub <lvl> <next-lvl or empty>
  printf '#!/usr/bin/env bash\n'
  printf 'for _v in $(env | sed -n "s/^\\(AI_DLC_[A-Za-z0-9_]*\\)=.*/\\1/p"); do unset "$_v"; done\n'
  printf 'printf "%%s depth=%%s\\n" "stub-%s" "${PREPUSH_POOL_DEPTH-unset}" >> "$NEST_LOG"\n' "$1"
  if [ -n "$2" ]; then
    printf '( cd "$NEST_ROOT/%s" && export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 && . "$NEST_BLK" >/dev/null 2>&1 && run_fixtures >> "$NEST_LOG.out" 2>&1 )\n' "$2"
  fi
  printf 'exit 0\n'
}
nest_build() { # nest_build <root> <fxroot...>
  local r="$1" lvl next fx; shift
  for lvl in a b c; do
    case "$lvl" in a) next=b ;; b) next=c ;; c) next="" ;; esac
    for fx in "$@"; do
      mkdir -p "$r/$lvl/$fx/stub-$lvl"
      nest_stub "$lvl" "$next" > "$r/$lvl/$fx/stub-$lvl/run.sh"
    done
    ( cd "$r/$lvl" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
  done
}
nest_build "$NW" $FXRS

# ------------------------------------------------------------------ the arm cells ---------------
ARM_CELLS="width_d0_j12 width_d1_j12 width_d1_j1 width_d1_j12x width_d1_j0 width_d1_jabc width_d2_j12 width_unset depth_long depth_nonnum depth_08 width_d1_jlong notice_load obs_d1_rc obs_d1_max raw_d1 scrub_same notice_dispatch obs_d1_j1_max obs_d0_max raw_d0 notice_d0 leak refuse_rc refuse_line refuse_ran refuse_d5_rc nest_started nest_depths nest_b_present nest_refusal_line"
# Expected value per cell. One owner per cell: the matrix above says which mutant moves which.
WANT="width_d0_j12=12
width_d1_j12=2
width_d1_j1=1
width_d1_j12x=2
width_d1_j0=2
width_d1_jabc=2
width_d2_j12=2
width_unset=12
depth_long=2
depth_nonnum=2
depth_08=8
width_d1_jlong=2
notice_load=0
obs_d1_rc=0
obs_d1_max=2
raw_d1=2
scrub_same=kept
notice_dispatch=1
obs_d1_j1_max=1
obs_d0_max=6
raw_d0=1
notice_d0=0
leak=unset
refuse_rc=1
refuse_line=1
refuse_ran=0
refuse_d5_rc=1
nest_started=stub-a stub-b
nest_depths=a=1 b=2
nest_b_present=1
nest_refusal_line=1"

cell_group() {
  case "$1" in
    obs_d1_rc|obs_d1_max|raw_d1|scrub_same|notice_dispatch) echo D1 ;;
    obs_d1_j1_max) echo D1J1 ;;
    obs_d0_max|raw_d0|notice_d0|leak) echo BAR ;;
    refuse_rc|refuse_line|refuse_ran) echo REF2 ;;
    refuse_d5_rc) echo REF5 ;;
    nest_started|nest_depths|nest_b_present|nest_refusal_line) echo NEST ;;
    *) echo "IN:$1" ;;
  esac
}
# one in-process cell: FIXTURE_JOBS or POOL_DEPTH_IN as the block computes it. No pool, no git.
inproc_cell() { # inproc_cell <block> <cell>
  local b="$1" c="$2" r d j
  case "$c" in
    width_unset)
      r="$( cd "$W" && unset PREPUSH_POOL_DEPTH; export AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "$FIXTURE_JOBS" )" ;;
    # a marker SET to a non-number, or to 20 digits, FAILS CLOSED to depth 2. 18446744073709551616 is
    # 2^64: bash arithmetic wraps it to 0, so without the length guard it reads as depth 0 and opens a
    # full pool -- the value that discriminates (99999999999999999999 wraps to a large positive depth
    # and refuses either way, so it could not kill the mutant). 08 is eight, not an octal error.
    depth_long)
      r="$( cd "$W" && export PREPUSH_POOL_DEPTH=18446744073709551616 AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "${POOL_DEPTH_IN:-}" )" ;;
    depth_nonnum)
      r="$( cd "$W" && export PREPUSH_POOL_DEPTH=abc AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "${POOL_DEPTH_IN:-}" )" ;;
    depth_08)
      r="$( cd "$W" && export PREPUSH_POOL_DEPTH=08 AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "${POOL_DEPTH_IN:-}" )" ;;
    # a 20-digit jobs value at depth 1: `[` errors on it, so without the length guard it kept its width
    width_d1_jlong)
      r="$( cd "$W" && export PREPUSH_POOL_DEPTH=1 AI_DLC_FIXTURE_JOBS=99999999999999999999; . "$b" >/dev/null 2>&1; printf '%s' "$FIXTURE_JOBS" )" ;;
    # the notice prints at dispatch inside run_fixtures and never at block load
    notice_load)
      r="$( cd "$W" && export PREPUSH_POOL_DEPTH=1 AI_DLC_FIXTURE_JOBS=12 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1; . "$b" 2>&1 )"
      r="$(printf '%s\n' "$r" | grep -c 'nested:')" ;;
    width_d*_j*)
      d="${c#width_d}"; d="${d%%_j*}"; j="${c#*_j}"
      r="$( cd "$W" && export PREPUSH_POOL_DEPTH="$d" AI_DLC_FIXTURE_JOBS="${j%x}"; . "$b" >/dev/null 2>&1; printf '%s' "$FIXTURE_JOBS" )" ;;
    *) r="UNKNOWN-CELL" ;;
  esac
  printf '%s=%s\n' "$c" "$r"
}
# depth 1, jobs 12, 0.3s stubs: the cap is real parallelism of two; the worker receives parent + 1; the
# scrub idiom leaves the marker alone (scrubbed equals raw; a worker with no marker passes vacuously,
# which is why raw_d0 is the cell that demands one); the notice prints at dispatch
grp_D1() {
  local b="$1" r
  r="$(PD_SLEEP=0.3 drive "$b" "$W" 1 12)"
  printf 'obs_d1_rc=%s\nobs_d1_max=%s\nraw_d1=%s\n' "$r" "$(maxflight)" "$(raws)"
  printf 'scrub_same=%s\n' "$(awk '{ r=$1; s=$2; sub(/^raw=/, "", r); sub(/^scrubbed=/, "", s); if (r != "_" && r != s) bad=1 } END { print bad ? "SCRUBBED" : "kept" }' "$WORK/log")"
  printf 'notice_dispatch=%s\n' "$(grep -c 'nested: depth 1, width [0-9]' "$WORK/last.out")"
}
grp_D1J1() { local r; r="$(PD_SLEEP=0.3 drive "$1" "$W" 1 1)"; printf 'obs_d1_j1_max=%s\n' "$(maxflight)"; }
# depth unset, jobs 12, through the barrier: all six stubs in flight AT ONCE; the marker a depth-0 worker
# receives; no notice at depth 0; and no leak -- the sourcing shell's own environment is unchanged by a pool run
grp_BAR() {
  local b="$1" r
  r="$(PD_BARRIER=1 drive "$b" "$W" - 12)"
  printf 'obs_d0_max=%s\nraw_d0=%s\nnotice_d0=%s\nleak=%s\n' "$(barrier_count)" "$(raws)" "$(grep -c 'nested:' "$WORK/last.out")" "$(cat "$WORK/leak.v" 2>/dev/null)"
}
# depth 2 refuses: non-zero, one line naming depth and marker, and NO fixture ran
grp_REF2() {
  local r; r="$(drive "$1" "$W" 2 -)"
  printf 'refuse_rc=%s\nrefuse_line=%s\nrefuse_ran=%s\n' "$r" "$(grep -c 'depth 2.*PREPUSH_POOL_DEPTH' "$WORK/last.out")" "$(grep -c . "$WORK/log")"
}
grp_REF5() { local r; r="$(drive "$1" "$W" 5 12)"; printf 'refuse_d5_rc=%s\n' "$r"; }
# THE CHAIN: outer pool -> a -> pool -> b -> pool -> c, the marker as each stub sees it AFTER the scrub
grp_NEST() {
  local b="$1" st
  : > "$WORK/nest.log"; : > "$WORK/nest.log.out"
  ( cd "$NW/a" && export NEST_BLK="$b" NEST_ROOT="$NW" NEST_LOG="$WORK/nest.log" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1; unset PREPUSH_POOL_DEPTH
    . "$b" >/dev/null 2>&1; run_fixtures >> "$WORK/nest.log.out" 2>&1 )
  st="$(sed 's/ depth=.*//' "$WORK/nest.log" | tr '\n' ' ' | sed 's/ *$//')"
  printf 'nest_started=%s\n' "$st"
  printf 'nest_depths=%s\n' "$(sed 's/stub-//; s/ depth=/=/' "$WORK/nest.log" | tr '\n' ' ' | sed 's/ *$//')"
  printf 'nest_b_present=%s\n' "$(grep -c '^stub-b depth=[0-9]' "$WORK/nest.log")"
  if grep -q 'depth 2.*PREPUSH_POOL_DEPTH' "$WORK/nest.log.out"; then printf 'nest_refusal_line=1\n'; else printf 'nest_refusal_line=0\n'; fi
}
# score <block> <cells...> -> one "<cell>=<got>" line per cell, driving each group once. A group prints
# all its cells; an in-process cell is computed on its own.
score() {
  local b="$1" c g done_groups=" "; shift
  for c in "$@"; do
    g="$(cell_group "$c")"
    case "$g" in
      IN:*) inproc_cell "$b" "$c" ;;
      *) case "$done_groups" in *" $g "*) ;; *) done_groups="$done_groups$g "; "grp_$g" "$b" ;; esac ;;
    esac
  done
}
# moved_of <got> <want> -> the cells of <got> whose value differs from <want> (an unknown cell counts as moved)
moved_of() {
  awk -F= 'NR == FNR { if ($0 != "") { k = $1; w[k] = substr($0, length(k) + 2) } next }
           $0 != "" { k = $1; v = substr($0, length(k) + 2); if (!(k in w) || v != w[k]) printf "%s ", k }' <(printf '%s\n' "$2") <(printf '%s\n' "$1")
}
same_set() { [ "$(printf '%s\n' $1 | grep . | sort | tr '\n' ' ')" = "$(printf '%s\n' $2 | grep . | sort | tr '\n' ' ')" ]; }
mx_row() { # mx_row <name> <cells> <moved>: the matrix row, one format for every mutant
  local c d=" $3 " line="" dead
  for c in $2; do case "$d" in *" $c "*) line="$line $c:1" ;; *) line="$line $c:0" ;; esac; done
  dead="$(printf '%s' "$3" | tr -s ' ' ',' | sed 's/^,//; s/,$//')"
  printf '  MATRIX-ROW %s dead=%s |%s\n' "$1" "${dead:-none}" "$line"
}
# the only emission of a kill; a loop-free site that receives the name as a variable
finish_mutant() { # finish_mutant <base-pass flag> <name> <cond 0|1> <ok-message> <fail-message>
  if [ "$3" = 1 ]; then mutant_killed "$1" "$2" "$4"; else bad "$5"; fi
}

# ------------------------------------------------------------------ hook loop -------------------
HN=0
for HOOK in $HOOKS; do
  HN=$((HN+1)); TAG="$(basename "$(dirname "$HOOK")")"
  echo "  hook: ${HOOK#"$ROOT"/}"
  BLK="$WORK/block$HN.sh"
  if [ "$HN" -gt 1 ]; then
    # EVERY HOOK AFTER THE FIRST keeps one end-to-end chain over its own fixture root (I66 binds the rest)
    GOT="$(score "$BLK" nest_started)"
    if [ "$(printf '%s\n' "$GOT" | grep -c .)" -eq 4 ]; then
      armcheck_label="[$TAG] the constructed chain over this hook's own fixture root: a and b start, c never does, a/b see depths 1 and 2 after the scrub, and the refusal line reaches the inner pool's output"
    else armcheck_label="[$TAG] the chain emitted $(printf '%s\n' "$GOT" | grep -c .) cells, want 4 -- a harness that died reads as clean"; fi
    mv_nest="$(moved_of "$GOT" "$WANT")"
    if [ "$(printf '%s\n' "$GOT" | grep -c .)" -eq 4 ] && [ -z "$mv_nest" ]; then ok "$armcheck_label"
    else bad "$armcheck_label -- moved: ${mv_nest:-none}"; fi
    continue
  fi
  W="$WORK/w$HN"; mkworld "$W" "$(cat "$WORK/block$HN.fxr")" 6 || broken "could not seed the probe world"

  GOT="$(score "$BLK" $ARM_CELLS)"
  # BASELINE ASSERTED BEFORE ANY MUTANT: a harness that died prints nothing and would score every
  # mutant as a kill.
  if [ "$(printf '%s\n' "$GOT" | grep -c .)" -eq "$(printf '%s\n' "$WANT" | grep -c .)" ]; then
    ok "[$TAG] the probe emitted every arm ($(printf '%s\n' "$WANT" | grep -c .) cells)"
  else
    bad "[$TAG] the probe emitted $(printf '%s\n' "$GOT" | grep -c .) cells, want $(printf '%s\n' "$WANT" | grep -c .) -- a harness that died reads as clean"
  fi
  [ "$MATRIX" = 1 ] && { MX_RAN=$((MX_RAN+1)); mx_row baseline "$ARM_CELLS" "$(moved_of "$GOT" "$WANT")"; }
  # the depth-0 barrier, named on its own: the baseline only (a mutant timing out is expected)
  B0="$(printf '%s\n' "$GOT" | sed -n 's/^obs_d0_max=//p')"
  if [ "$B0" = 6 ]; then ok "[$TAG] depth-0 barrier: 6 of 6 entered together"
  else bad "[$TAG] depth-0 barrier: $B0 of 6 entered within ${PD_BARRIER_CEIL}s"; fi
  armcheck() { # armcheck <label> <key...>: every named cell equals its want
    local label="$1" k g w badk=""; shift
    for k in "$@"; do
      g="$(printf '%s\n' "$GOT" | sed -n "s/^$k=//p")"; w="$(printf '%s\n' "$WANT" | sed -n "s/^$k=//p")"
      [ "$g" = "$w" ] || badk="$badk $k(got [$g] want [$w])"
    done
    if [ -z "$badk" ]; then ok "[$TAG] $label"; else bad "[$TAG] $label --$badk"; fi
  }
  armcheck "depth 1 narrows the pool to min(jobs,2): 12->2 and 1->1, an explicit job count does not lift it, depth 0 keeps 12" \
    width_d0_j12 width_d1_j12 width_d1_j1 width_d1_j12x width_unset
  armcheck "depth 1 is two in flight and not one or twelve; jobs=1 is one; depth 0 is untouched" obs_d1_rc obs_d1_max obs_d1_j1_max obs_d0_max
  armcheck "a worker receives the parent's depth + 1 (0->1, 1->2)" raw_d0 raw_d1
  armcheck "the AI_DLC_ scrub idiom every fixture opens with leaves the marker in place" scrub_same
  armcheck "depth 2 refuses: non-zero exit, one line naming depth and marker, no fixture ran; depth 5 too" refuse_rc refuse_line refuse_ran refuse_d5_rc
  armcheck "the notice prints at dispatch inside run_fixtures, never at block load, never at depth 0" notice_dispatch notice_load notice_d0
  armcheck "the marker does not leak into the caller's own environment" leak
  armcheck "the constructed chain: a and b start, c never does, a/b see depths 1 and 2 after the scrub, and the refusal line reaches the inner pool's output" nest_started nest_depths nest_b_present nest_refusal_line
  armcheck "a depth-2 hook caps the width it would have opened too" width_d2_j12
  armcheck "depth 1 makes jobs=0 two, not BSD xargs -P 0 (unlimited)" width_d1_j0
  armcheck "depth 1 makes a non-numeric jobs value two, not whatever xargs does with it" width_d1_jabc
  armcheck "depth 1 makes a 20-digit jobs value two, not the width [ cannot compare" width_d1_jlong
  armcheck "a 20-digit depth (2^64, which arithmetic wraps to 0) fails closed to depth 2" depth_long
  armcheck "a non-numeric depth fails closed to depth 2" depth_nonnum
  armcheck "a depth of 08 is eight, not an octal error" depth_08

  # ---------------------------------------------------------------- mutants ------------------
  # mutate <name> <sed-expr>: copy the block, apply one edit, refuse a no-op.
  MUTN=0
  # MUTANTS RUN AGAINST THE FIRST RESOLVED HOOK ONLY: I66 holds both blocks to one program.
  # An optional 5th argument is the barrier ceiling for that mutant's score alone, set inside the score's
  # own subshell so every other mutant and the baseline keep PD_BARRIER_CEIL.
  mutant() { # mutant <name> <sed-expr> [barrier-ceiling]; decides and twins come from the header row
    local name="$1" ex="$2" ceil="${3:-$PD_BARRIER_CEIL}" m="$WORK/mut$HN.$1.sh" dec tw cells g moved B_mut=1 c cond=0 n_all n_run
    dec="$(mrow "$name" decides)"; tw="$(mrow "$name" twins)"
    [ -n "$dec" ] || { bad "[$TAG] MUTANT $name: no MUTANT-MATRIX row in the header"; return 0; }
    dec="${dec//,/ }"; tw="${tw//,/ }"; [ "$tw" = - ] && tw=""
    sed "$ex" "$BLK" > "$m" || { bad "[$TAG] MUTANT $name: sed did not apply"; return 0; }
    MUTN=$((MUTN+1))
    if cmp -s "$BLK" "$m"; then bad "[$TAG] MUTANT $name: the edit matched nothing, so it is not a mutant"; return 0; fi
    # the base-pass flag: the unmutated run held every cell this mutant is judged on
    for c in $dec $tw; do
      [ "$(printf '%s\n' "$GOT" | sed -n "s/^$c=//p")" = "$(printf '%s\n' "$WANT" | sed -n "s/^$c=//p")" ] || B_mut=0
    done
    if [ "$MATRIX" = 1 ]; then
      cells="$ARM_CELLS"; n_all="$(printf '%s\n' $cells | grep -c .)"; n_run="$(printf '%s\n' $dec $tw | grep -c .)"
      MX_RAN=$((MX_RAN + n_all - n_run))
    else cells="$dec $tw"; fi
    g="$(PD_BARRIER_CEIL="$ceil"; score "$m" $cells)"
    moved="$(moved_of "$g" "$WANT")"
    [ "$MATRIX" = 1 ] && mx_row "$name" "$cells" "$moved"
    same_set "$moved" "$dec" && cond=1
    finish_mutant "$B_mut" "$name" "$cond" \
      "[$TAG] MUTANT $name kill confirmed: decides [$dec] moved, twin [${tw:--}] stayed green" \
      "[$TAG] MUTANT $name moved [${moved% }], want [$dec] (twin [${tw:--}])"
  }
  mutant not-exported    's/PREPUSH_POOL_DEPTH="\$((POOL_DEPTH_IN + 1))" //'
  mutant not-incremented 's/PREPUSH_POOL_DEPTH="\$((POOL_DEPTH_IN + 1))"/PREPUSH_POOL_DEPTH="$POOL_DEPTH_IN"/'
  mutant cap-ignored     's/^if \[ "\$POOL_DEPTH_IN" -ge 1 \]; then$/if false; then/'
  # each half of the depth-1 cap admitted alone: zero passes the range test, a non-number skips the case
  mutant zero-admitted   's/^  if \[ "\$FIXTURE_JOBS" -lt 1 \] || /  if [ "$FIXTURE_JOBS" -lt 0 ] || /'
  mutant nonnum-admitted 's/^  case "\$FIXTURE_JOBS" in '"''"'|\*\[!0-9\]\*|/  case "$FIXTURE_JOBS" in '"''"'|/'
  mutant jlong-admitted  's/|??????\*) FIXTURE_JOBS=2 ;; esac$/) FIXTURE_JOBS=2 ;; esac/'
  mutant depth-long-admitted 's/^case "\$POOL_DEPTH_IN" in \*\[!0-9\]\*|??????\*) POOL_DEPTH_IN=2 ;; esac$/case "$POOL_DEPTH_IN" in *[!0-9]*) POOL_DEPTH_IN=2 ;; esac/'
  mutant depth-nonnum-zero 's/^case "\$POOL_DEPTH_IN" in \*\[!0-9\]\*|??????\*) POOL_DEPTH_IN=2 ;; esac$/case "$POOL_DEPTH_IN" in *[!0-9]*) POOL_DEPTH_IN=0 ;; ??????*) POOL_DEPTH_IN=2 ;; esac/'
  mutant octal-08        's/^POOL_DEPTH_IN=\$((10#\$POOL_DEPTH_IN))$/POOL_DEPTH_IN=$((POOL_DEPTH_IN))/'
  mutant ai-dlc-named    's/PREPUSH_POOL_DEPTH="\$((POOL_DEPTH_IN + 1))"/AI_DLC_POOL_DEPTH="$((POOL_DEPTH_IN + 1))"/'
  mutant notice-at-load  's/^POOL_DEPTH_IN="\${PREPUSH_POOL_DEPTH:-0}"$/&; [ "$POOL_DEPTH_IN" -ge 1 ] \&\& printf "   nested: depth %s\\n" "$POOL_DEPTH_IN"/'
  # with the refusal removed the same chain starts c as well: the nest builds and the count can move
  mutant no-refusal      's/if \[ "\$POOL_DEPTH_IN" -ge 2 \]; then/if false; then/'
  mutant leaks           's/^POOL_DEPTH_IN=\$((10#\$POOL_DEPTH_IN))$/&; export PREPUSH_POOL_DEPTH="$((POOL_DEPTH_IN + 1))"/'
  # a depth-0 pool capped at 5 never holds six, so the barrier waits its whole ceiling: 3s, for this mutant only
  mutant pool-capped-5   's/xargs -P "\$FIXTURE_JOBS" -I{}/xargs -P "$(( FIXTURE_JOBS < 5 ? FIXTURE_JOBS : 5 ))" -I{}/' 3
done

# ------------------------------------------------- the nested root is watched (BL-691) ------
# A unit that drives the pool again makes its nested pool root at /tmp/fx.XXXXXX, outside its own watched
# root, so before the fix an outer unit whose only progress is its nested pool's scratch was refused. The
# fix makes the watched root discoverable (`.pool-unit`), the nested pool registers its root there
# (`.pool-nested`, with `.pool-parent` naming the marker dir), and the watcher walks validated entries.
# FORCED, not waited for: the outer pool's window is AI_DLC_POOL_STALL=$PN_STALL, exported before the block is
# sourced. Stub A sends its output to /dev/null (so the outer log never grows), scrubs AI_DLC_* (so the
# inner pool runs its default window), heartbeats into its own TMPDIR only until stub B has started, then
# waits on an inner pool over a tree holding stub B. Stub B writes one byte a second under ITS OWN TMPDIR
# for PN_SECS seconds, more than three windows. So the nested scratch is the outer unit's only progress.
#   pn_grow   -- fix: ok. base (the three edits reverted): REFUSED. The pair must DIFFER in this run.
#   pn_silent -- B writes nothing for the same time: REFUSED under the fix (a registered root is not progress).
#   pn_hlink  -- A lists a symlink (spelled bare and with a trailing slash) to a dir it grows, whose
#                .pool-parent names A's own root: REFUSED under the fix.
#   pn_hout   -- A lists the OUTER pool root itself and grows a file in it: REFUSED (no .pool-parent there).
#   pn_fifo   -- a listed entry whose .pool-parent is a FIFO is never read: REFUSED inside the deadline.
#   pn_ord    -- the newest root registers inside the watcher's 16-line read window.
# Every drive runs in its own pair of worlds, concurrently, copied from ONE template pair (two git inits
# for the whole section); the inner root a killed inner pool leaves is removed by the drive only after its
# basename matches fx.?????? literally.
PN_ALL="pn_grow pn_silent pn_hlink pn_hout pn_fifo pn_ord"
WANT_PN="pn_grow=ok
pn_silent=REFUSED
pn_hlink=REFUSED
pn_hout=REFUSED
pn_fifo=REFUSED
pn_ord=inwin"
PB="$WORK/block1.sh"; PFXR="$(cat "$WORK/block1.fxr")"
PNT="$WORK/pn.tpl"
mkdir -p "$PNT/a/$PFXR/stub-a" "$PNT/b/$PFXR/stub-b" "$PNT/ord/w/$PFXR/s" || broken "could not build the watcher template"
cat > "$PNT/a/$PFXR/stub-a/run.sh" <<'FX'
#!/usr/bin/env bash
for _v in $(env | sed -n "s/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p"); do unset "$_v"; done
exec > /dev/null 2>&1
g=""
case "$PN_MODE" in
  grow|silent)
    ( cd "$PN_DIR/b" && export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 && . "$PN_BLK" && run_fixtures ) &
    s=$SECONDS
    while [ ! -s "$PN_DIR/btmp" ] && [ $((SECONDS - s)) -lt 60 ]; do printf x >> "$TMPDIR/hb"; sleep 1; done
    wait
    exit 0 ;;
  hlink)
    me="$(cd "$TMPDIR" && pwd -P)"
    mkdir -p "$PN_DIR/hgrow" "$PN_DIR/hl"
    printf '%s\n' "$me" > "$PN_DIR/hgrow/.pool-parent"
    ln -s "$PN_DIR/hgrow" "$PN_DIR/hl/fx.hostil"
    printf '%s\n%s\n' "$PN_DIR/hl/fx.hostil" "$PN_DIR/hl/fx.hostil/" > "$TMPDIR/.pool-nested"
    g="$PN_DIR/hgrow/g" ;;
  hout)
    printf '%s\n' "${TMPDIR%/*}" > "$TMPDIR/.pool-nested"
    g="${TMPDIR%/*}/.hgrow" ;;
  fifo)
    # a listed fx.?????? directory whose .pool-parent is a FIFO; then no progress at all until the
    # fixture writes $PN_DIR/release (or a 90s cap), so only a refusal can end this unit early
    mkdir -p "$PN_DIR/hf/fx.fifo00" && mkfifo "$PN_DIR/hf/fx.fifo00/.pool-parent"
    printf '%s\n' "$PN_DIR/hf/fx.fifo00" > "$TMPDIR/.pool-nested"
    s=$SECONDS
    while [ ! -e "$PN_DIR/release" ] && [ $((SECONDS - s)) -lt 90 ]; do sleep 1; done
    exit 0 ;;
esac
i=0; while [ "$i" -lt "$PN_SECS" ]; do printf x >> "$g"; sleep 1; i=$((i + 1)); done
exit 0
FX
cat > "$PNT/b/$PFXR/stub-b/run.sh" <<'FX'
#!/usr/bin/env bash
printf '%s\n' "$TMPDIR" > "$PN_DIR/btmp"
# silent is ONE sleep, so the inner pool's own bookkeeping (its watcher's pid record) stays still too
[ "$PN_MODE" = grow ] || { sleep "$PN_SECS"; exit 0; }
i=0; while [ "$i" -lt "$PN_SECS" ]; do printf x >> "$TMPDIR/grow"; sleep 1; i=$((i + 1)); done
exit 0
FX
printf '#!/usr/bin/env bash\nexit 0\n' > "$PNT/ord/w/$PFXR/s/run.sh"
for w in a b ord/w; do
  ( cd "$PNT/$w" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
done
[ -d "$PNT/a/.git" ] && [ -d "$PNT/b/.git" ] && [ -d "$PNT/ord/w/.git" ] || broken "the watcher template worlds are not repositories"

PN_PIDS=""; PF_PIDS=""; PF_TAGS=""; PF_HANG=""
pn_drive() { # pn_drive <block> <mode> <tag>: backgrounded; writes ok, REFUSED or OTHER to $WORK/pn.<tag>.v
  local blk="$1" mode="$2" tag="$3" d="$WORK/pn.$3"
  mkdir -p "$d" && cp -R "$PNT/a" "$d/a" && cp -R "$PNT/b" "$d/b" || { bad "watcher drive $tag: could not copy the template worlds"; return 1; }
  ( cd "$d/a" && export AI_DLC_POOL_STALL="$PN_STALL" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PN_BLK="$blk" PN_MODE="$mode" PN_DIR="$d" PN_SECS="$PN_SECS"
    . "$blk" >/dev/null 2>&1; run_fixtures > "$d/out" 2>&1
    if grep -q '^   ok    stub-a$' "$d/out"; then v=ok
    elif grep -q '^   REFUSED  stub-a  ' "$d/out"; then v=REFUSED
    else v=OTHER; fi
    printf '%s\n' "$v" > "$WORK/pn.$tag.v"
    if [ -s "$d/btmp" ]; then
      p="$(cat "$d/btmp")"; p="${p%/*}"
      case "${p##*/}" in fx.??????) [ -d "$p" ] && rm -rf -- "$p" ;; esac
    fi ) > /dev/null 2>&1 &
  case "$mode" in fifo) PF_PIDS="$PF_PIDS $!" ;; *) PN_PIDS="$PN_PIDS $!" ;; esac
}
pn_v() { local v; v="$(cat "$WORK/pn.$1.v" 2>/dev/null)"; printf '%s' "${v:-none}"; }
# THE NEWEST ROOT IS INSIDE THE WATCHER'S READ WINDOW. The watcher reads the first 16 lines of
# `.pool-nested`, so a registration that appended put a newer live root out of sight once 16 older live
# roots were listed. ord_drive seeds 17 live directories straight into an owned `.t.abcde` marker
# directory's list (no inner pools), runs ONE pool over a single no-op stub under that marker, and writes
# to $WORK/ord.<tag>.v the line number of the one entry that is not a seed ("none" if there is not exactly
# one, so a registration that wrote nothing cannot pass). Backgrounded beside the pn drives.
ord_drive() { # ord_drive <block> <tag>
  local blk="$1" tag="$2" d="$WORK/ord.$2" i m
  mkdir -p "$d/u/.t.abcde" && : > "$d/u/.t.abcde/.pool-unit" && cp -R "$PNT/ord/w" "$d/w" || { bad "watcher drive $tag: could not build the world"; return 1; }
  m="$(cd "$d/u/.t.abcde" && pwd -P)"
  i=0; while [ "$i" -lt 17 ]; do mkdir -p "$d/old/$i"; printf '%s\n' "$d/old/$i" >> "$d/seed"; i=$((i + 1)); done
  cp "$d/seed" "$m/.pool-nested"
  ( cd "$d/w" && export TMPDIR="$m" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1
    . "$blk" >/dev/null 2>&1; run_fixtures >/dev/null 2>&1
    awk 'NR == FNR { s[$0] = 1; next } !($0 in s) { n++; at = FNR } END { print (n == 1 ? at : "none") }' "$d/seed" "$m/.pool-nested" > "$WORK/ord.$tag.v" ) > /dev/null 2>&1 &
  PN_PIDS="$PN_PIDS $!"
}
ord_v() { local v; v="$(cat "$WORK/ord.$1.v" 2>/dev/null)"; printf '%s' "${v:-none}"; }
pn_launch() { # pn_launch <set> <block> <cell...>: tags are <set>_<mode>
  local set="$1" blk="$2" c; shift 2
  for c in "$@"; do
    case "$c" in
      pn_grow)   pn_drive "$blk" grow "${set}_grow" ;;
      pn_silent) pn_drive "$blk" silent "${set}_silent" ;;
      pn_hlink)  pn_drive "$blk" hlink "${set}_hlink" ;;
      pn_hout)   pn_drive "$blk" hout "${set}_hout" ;;
      pn_fifo)   pn_drive "$blk" fifo "${set}_fifo"; PF_TAGS="$PF_TAGS ${set}_fifo"
                 [ "$set" = m-nofifoguard ] && PF_HANG="$PF_HANG ${set}_fifo" ;;
      pn_ord)    ord_drive "$blk" "${set}_ord" ;;
      *) bad "watcher cell $c is not a cell" ;;
    esac
  done
}
pn_val() { # pn_val <set> <cell> -> the cell's value after pn_settle
  local v
  case "$2" in
    pn_ord) v="$(ord_v "${1}_ord")"; case "$v" in [1-9]|1[0-6]) printf 'inwin' ;; *) printf '%s' "$v" ;; esac ;;
    pn_fifo) v="$(cat "$WORK/pf.${1}_fifo.at" 2>/dev/null)"; printf '%s' "${v:-none}" ;;
    *) pn_v "${1}_${2#pn_}" ;;
  esac
}
# THE FIFO CELL IS BOUNDED BY ITS OWN DEADLINE, never by the drive: a watcher that opens the FIFO blocks
# forever, so its unit can only end when its stub is released. Wait on the CONDITION (every fixed hook's
# verdict file present) up to PF_DEADLINE seconds, snapshot every fifo verdict AT that moment, and only
# then release the stubs (each drive's own $d/release), so a hung watcher's unit exits, its worker kills
# the watcher, and every drive pid recorded in PF_PIDS is reaped by `wait`. The mutant (a PF_HANG tag)
# gets the same window past its twins' verdicts that they needed from launch, at least PF_MIN seconds; its
# verdict is read from the snapshot: under it the watcher never polls again, so nothing is recorded in time.
PF_DEADLINE=40; PF_MIN=6
pn_settle() {
  local t s el s2 all
  s=$SECONDS
  while [ $((SECONDS - s)) -lt "$PF_DEADLINE" ]; do
    all=1
    for t in $PF_TAGS; do case " $PF_HANG " in *" $t "*) ;; *) [ -s "$WORK/pn.$t.v" ] || all=0 ;; esac; done
    [ "$all" = 1 ] && break
    sleep 1
  done
  el=$((SECONDS - s)); [ "$el" -lt "$PF_MIN" ] && el="$PF_MIN"
  if [ -n "$PF_HANG" ]; then
    s2=$SECONDS
    while [ $((SECONDS - s2)) -lt "$el" ]; do
      all=1; for t in $PF_HANG; do [ -s "$WORK/pn.$t.v" ] && all=0; done
      [ "$all" = 1 ] || break
      sleep 1
    done
  fi
  for t in $PF_TAGS; do printf '%s\n' "$(pn_v "$t")" > "$WORK/pf.$t.at"; : > "$WORK/pn.$t/release"; done
  for p in $PN_PIDS $PF_PIDS; do wait "$p"; done
  PN_PIDS=""; PF_PIDS=""; PF_TAGS=""; PF_HANG=""
}
# pn_mut <name> <sed-expr> <source block> -> writes $WORK/pn.mut.<name>.sh, or returns 1 (reported) on a
# sed failure or a no-op. Never called inside $( ): `bad` must count in this shell.
pn_mut() {
  PN_M="$WORK/pn.mut.$1.sh"
  sed "$2" "$3" > "$PN_M" || { bad "MUTANT $1: sed did not apply"; return 1; }
  if cmp -s "$3" "$PN_M"; then bad "MUTANT $1: the edit matched nothing, so it is not a mutant"; return 1; fi
}
# the base block: all three edits reverted (marker write, registration, watcher read), plus their locals
PN_BASE_EX='/^      : > "\$wr\/.pool-unit"; wp=/d
/^  # A NESTED POOL REGISTERS ITS ROOT/,/^  done$/d
/^          set --; nn=0$/,/^          done < "\$wr\/.pool-nested"$/d
s/ \${1+"\$@"} -type f -ls/ -type f -ls/
s/ fx_m fx_p fx_t fx_e$//
s/^      local lg="\$1" rc wr wp$/      local lg="$1" rc wr/'
PN_OK=1
pn_mut base "$PN_BASE_EX" "$PB" || PN_OK=0; PBASE="$PN_M"
if [ "$PN_OK" = 1 ]; then
  # the base must carry none of the three subjects, or it is not the base
  PN_CODE="$(grep -v '^ *#' "$PBASE")"
  if grep -q 'pool-unit\|pool-nested\|pool-parent' <<< "$PN_CODE"; then bad "the watcher base block still names a subject"; PN_OK=0; fi
fi
[ "$PN_OK" = 1 ] && { bash -n "$PBASE" || { bad "the watcher base block does not parse"; PN_OK=0; }; }
# the registration as a plain append: the pruned rewrite (two lines) becomes one `>>` of the new root
pn_mut m-appendreg '/^            { printf .%s\\n. "\$fx_p"$/{N;s/.*/            printf "%s\\n" "$fx_p" >> "$fx_m\/.pool-nested"; rm -f "$fx_t"/;}' "$PB" || PN_OK=0
# the pre-fix watcher line: the regular-file check on .pool-parent dropped, so the read opens the FIFO
pn_mut m-nofifoguard 's/ \[ -f "\$e\/.pool-parent" \] && \[ ! -L "\$e\/.pool-parent" \] &&//' "$PB" || PN_OK=0
pn_mut m-nomark 's/^      : > "\$wr\/.pool-unit"; /      /' "$PB" || PN_OK=0
pn_mut m-noread 's/ \${1+"\$@"} -type f -ls/ -type f -ls/' "$PB" || PN_OK=0
pn_mut m-novalidate 's/case "\${e##\*\/}" in fx\.??????) .* ;; esac$/set -- ${1+"$@"} "$e"/' "$PB" || PN_OK=0
[ "$PN_OK" = 1 ] || broken "the watcher section could not build its blocks"

wantpn() { printf '%s\n' "$WANT_PN" | sed -n "s/^$1=//p"; }
# pn_eval <mutant>: the mutant's cells against the fix set's values; decides moved, twins stayed
pn_eval() {
  local name="$1" dec tw cells c got="" moved B_mut=1 cond=0 ctl=1 n_run
  dec="$(mrow "$name" decides)"; tw="$(mrow "$name" twins)"
  [ -n "$dec" ] || { bad "MUTANT $name: no MUTANT-MATRIX row in the header"; return 0; }
  dec="${dec//,/ }"; tw="${tw//,/ }"; [ "$tw" = - ] && tw=""
  if [ "$MATRIX" = 1 ]; then cells="$PN_ALL"; n_run="$(printf '%s\n' $dec $tw | grep -c .)"; MX_RAN=$((MX_RAN + 6 - n_run)); else cells="$dec $tw"; fi
  for c in $cells; do got="$got$c=$(pn_val "$name" "$c")"$'\n'; done
  for c in $dec $tw; do [ "$(pn_val fix "$c")" = "$(wantpn "$c")" ] || B_mut=0; done
  moved="$(moved_of "$got" "$WANT_PN")"
  [ "$MATRIX" = 1 ] && mx_row "$name" "$cells" "$moved"
  # released after the deadline, the hung unit then reaches ok: the drive ran and was only blocked
  if [ "$name" = m-nofifoguard ] && [ "$(pn_v m-nofifoguard_fifo)" != ok ]; then ctl=0; fi
  same_set "$moved" "$dec" && [ "$ctl" = 1 ] && cond=1
  finish_mutant "$B_mut" "$name" "$cond" \
    "MUTANT $name kill confirmed: decides [$dec] moved, twin [${tw:--}] stayed green" \
    "MUTANT $name moved [${moved% }], want [$dec] (twin [${tw:--}]); released-fifo control read $(pn_v m-nofifoguard_fifo)"
}
PN_MUTS="m-appendreg m-nofifoguard m-nomark m-noread m-novalidate"
if [ "$MATRIX" = 1 ]; then
  pn_launch fix "$PB" $PN_ALL; pn_launch base "$PBASE" pn_grow; pn_settle
  for _m in $PN_MUTS; do
    pn_launch "$_m" "$WORK/pn.mut.$_m.sh" $PN_ALL; pn_settle
    PN_NOW="$_m"
  done
else
  pn_launch fix "$PB" $PN_ALL; pn_launch base "$PBASE" pn_grow
  for _m in $PN_MUTS; do
    _cells="$(mrow "$_m" decides),$(mrow "$_m" twins)"; _cells="${_cells//,/ }"
    pn_launch "$_m" "$WORK/pn.mut.$_m.sh" $_cells
  done
  pn_settle
fi

T="nested-root:${PB##*/}"; T="nested-root:$(basename "$(dirname "$(printf '%s\n' $HOOKS | sed -n 1p)")")/pre-push"
f="$(pn_val fix pn_grow)"; b="$(pn_v base_grow)"
if [ "$f" = ok ] && [ "$b" = REFUSED ]; then
  ok "[$T] an outer unit whose only progress is its nested pool's scratch is ok under the fix and REFUSED on the base block, in one run"
else bad "[$T] forced nested arm: fix=$f base=$b, want fix=ok base=REFUSED"; fi
for _c in pn_silent pn_hlink pn_hout; do
  v="$(pn_val fix "$_c")"
  [ "$v" = REFUSED ] && ok "[$T] $_c: REFUSED (a registered root that writes nothing, a listed symlink to a growing dir, and a listed outer pool root are never progress)" \
                     || bad "[$T] $_c read $v, want REFUSED"
done
v="$(pn_val fix pn_ord)"
[ "$v" = inwin ] && ok "[$T] with 17 live roots already listed, the new root registers inside the watcher's 16-line window" \
                 || bad "[$T] with 17 live roots already listed, the new root registered at line $(ord_v fix_ord), want 1-16 (the watcher reads only the first 16)"
v="$(pn_val fix pn_fifo)"
[ "$v" = REFUSED ] && ok "[$T] a listed entry whose .pool-parent is a FIFO is never read: the silent unit is REFUSED inside ${PF_DEADLINE}s" \
                   || bad "[$T] a listed FIFO .pool-parent: the unit read ${v:-none} at the deadline, want REFUSED (a watcher blocked on the FIFO never refuses)"
for _m in $PN_MUTS; do pn_eval "$_m"; done

# ------------------------------------------------- I66 binds the two blocks (once per push) ------
# The hook-2 watcher and mutant drives were deleted on the strength of I66, which byte-compares the two
# FIXTURE_POOL blocks (comments and blanks stripped, fixture root mapped). This arm proves I66 can fail:
# the validator is driven with `--arms I66` over two trees of the eleven files it needs, one clean and one
# with a single non-FXROOT byte added on an executable line of hook 2's block. The clean tree is a hard
# precondition: a dependency missing from the copy set would fail I66 there too, and the seeded failure
# would then read as a catch. It runs outside the mutant loop, once per push, and drives no pool.
I66_FILES="scripts/validate-enforcement-map.sh scripts/render-invariant-index.sh .githooks/pre-push core/git-hooks/pre-push core/scripts/hermetic-run.sh core/scripts/derive-fixture-readsets.sh core/skills/ai-dlc/steps/gate-validation.md core/skills/ai-dlc/enforcement-map.yaml core/skills/ai-dlc/core-manifest.md core/skills/ai-dlc-update/fixture-manifest.md core/skills/ai-dlc-update/reconcile/setup-sites.md"
i66_tree() { # i66_tree <dir>
  local d="$1" f
  for f in $I66_FILES; do
    [ -f "$ROOT/$f" ] || broken "I66 copy set: $f is absent from $ROOT"
    mkdir -p "$d/$(dirname "$f")" && cp -p "$ROOT/$f" "$d/$f" || broken "I66 copy set: could not copy $f"
  done
}
i66_run() { # i66_run <tree> -> rc in $I66_RC, output in $WORK/i66.<name>.out; cwd is outside the tree
  ( cd "$WORK" && bash "$1/scripts/validate-enforcement-map.sh" --arms I66 ) > "$1.out" 2>&1; I66_RC=$?
}
I66_C="$WORK/i66.clean"; I66_S="$WORK/i66.seeded"
i66_tree "$I66_C"; i66_tree "$I66_S"
# the seed: one byte after the first executable POOL_DEPTH_IN= assignment inside hook 2's block
awk '/^# FIXTURE_POOL_BEGIN$/ { inb = 1 } /^# FIXTURE_POOL_END$/ { inb = 0 }
     inb && !done && /^POOL_DEPTH_IN=/ { sub(/^POOL_DEPTH_IN=/, "POOL_DEPTH_IN= "); done = 1 } { print }' \
  "$I66_S/core/git-hooks/pre-push" > "$I66_S/hook2.t" && cat "$I66_S/hook2.t" > "$I66_S/core/git-hooks/pre-push" && rm -f "$I66_S/hook2.t"
B_i66=0
if cmp -s "$I66_C/core/git-hooks/pre-push" "$I66_S/core/git-hooks/pre-push"; then bad "I66 seed: the edit matched nothing, so it is not a seed"
else
  i66_run "$I66_C"
  if [ "$I66_RC" -ne 0 ]; then
    cat "$I66_C.out" >&2; echo "FIXTURE BROKEN: the I66 copy set is incomplete" >&2; exit 2
  fi
  if grep -q "$ROOT" "$I66_C.out"; then bad "[I66] the clean copy's output names the real tree $ROOT, so it did not run on the copy"
  elif grep -q 'FAIL: I66' "$I66_C.out"; then bad "[I66] the clean copy reports an I66 FAIL"
  else ok "[I66] i66_clean: on a clean copy of the eleven files the validator's I66 arm passes (rc 0)"; B_i66=1; fi
  i66_run "$I66_S"
  i66_cond=0
  [ "$I66_RC" -eq 1 ] && grep -q 'FAIL: I66' "$I66_S.out" && ! grep -q "$ROOT" "$I66_S.out" && i66_cond=1
  if [ "$MATRIX" = 1 ]; then
    if [ "$i66_cond" = 1 ]; then mx_row i66-fork-seed "i66_clean i66_seeded" "i66_seeded"; else mx_row i66-fork-seed "i66_clean i66_seeded" ""; fi
  fi
  finish_mutant "$B_i66" i66-fork-seed "$i66_cond" \
    "MUTANT i66-fork-seed kill confirmed: decides [i66_seeded] moved (rc 1, FAIL: I66), twin [i66_clean] stayed green" \
    "MUTANT i66-fork-seed: a one-byte fork of hook 2's block read rc $I66_RC with no I66 FAIL line"
fi

# ------------------------------------------------- an interrupt tears the pool down (BL-881) ------
# xargs runs in the background under `set -m` and the parent waits on it; INT/TERM/HUP reach the parent's
# pool_stop, which writes `.pr/.stop`, TERMs every worker recorded in `.pr/<unit>.k` and waits for xargs.
# FORCED, not waited for: three stubs at width 2, each recording "<pid> <pool root>" and then holding on a
# barrier FILE the fixture writes, so the pool holds exactly two units when the signal lands and ONE queued.
# ONE QUEUED UNIT, NEVER TWO, so the start count is the same on every run: when both workers die xargs
# dispatches the queue once per reaped exit until it reaps a 255. With two queued, whether the second dying
# worker or the first replacement's `.stop` refusal (255) is reaped first decided whether one or two refused
# replacement workers started -- measured 305 and 306 starts on one tree. With one queued, exactly one starts.
#   td_term  -- TERM to the parent: recorded stub pids still alive once the parent has exited (want 0)
#   td_queue -- stubs that ever started, counted after release (want 2: the queued unit is never run)
#   td_rc    -- the parent's exit status and whether its pool root survives (want 143:gone)
#   td_decoy -- a live process NOT in xargs' group, its pid planted in `.pr/zz-decoy.k` before the TERM (the
#               stale record a SIGKILLed worker leaves): alive once the parent has exited (want 1). The allow
#               twin of td_term: a pool_stop that TERMs every record, group or not, reads 0 here.
#   td_intp  -- after td_int, xargs dispatches the queued stub (an exit of 130 does not stop it); INT to
#               the parent then: "<rc>:<root>:<stubs alive>" (want 130:gone:0), the ^C an operator sends
#   td_int   -- INT to each worker recorded in `.k`: the two targeted stubs still alive once both workers
#               cleared their `.k` (want 0). Under a plain `&` bash starts xargs with SIGINT ignored, every
#               worker inherits that, and its `trap pool_abort INT` cannot fire (BL-881 D-f).
# Signals go only to the drive's own pid and to the pids the workers recorded; release ends every stub.
TD_ALL="td_term td_queue td_rc td_decoy td_int td_intp"
WANT_TD="td_term=0
td_queue=2
td_rc=143:gone
td_decoy=1
td_int=0
td_intp=130:gone:0"
# TD_CEIL is a HANG GUARD, never a verdict: on the unmutated block a ceiling that ends a wait (instead of the awaited
# event) is FIXTURE BROKEN (td_hang); on a mutant the ceiling is the mutant's expected observable and stays a cell value.
TD_CEIL=60
TDT="$WORK/td.tpl"
for _i in 1 2 3; do
  mkdir -p "$TDT/$PFXR/q$_i" || broken "could not build the teardown template"
  cat > "$TDT/$PFXR/q$_i/run.sh" <<'FX'
#!/usr/bin/env bash
printf '%s %s\n' "$$" "${TMPDIR%/*}" > "$TD_DIR/s.$$"
s=$SECONDS
while [ ! -e "$TD_DIR/release" ] && [ -d "$TD_DIR" ] && [ $((SECONDS - s)) -lt 60 ]; do sleep 0.1; done
exit 0
FX
done
( cd "$TDT" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
[ -d "$TDT/.git" ] || broken "the teardown template world is not a repository"
td_alive() { # td_alive <pid...> -> how many are live and not exiting or zombie
  local p n=0 s
  for p in "$@"; do
    kill -0 "$p" 2>/dev/null || continue
    s="$(ps -o stat= -p "$p" 2>/dev/null)"
    case "$s" in Z*|E*|'') ;; *) n=$((n + 1)) ;; esac
  done
  printf '%s' "$n"
}
td_stubs() { cat "$1"/s.* 2>/dev/null | cut -d' ' -f1 | tr '\n' ' '; }
td_hang() { # td_hang <block> <what>: the ceiling ended a wait; on the unmutated block that is not measurable
  [ "$1" = "$PB" ] && broken "teardown drive: the ${TD_CEIL}s ceiling ended the wait for $2 on the unmutated block"
  return 0
}
td_wait2() { # td_wait2 <stub dir>: until two stubs recorded, at most TD_CEIL seconds
  local s=$SECONDS
  while [ "$(ls "$1" | grep -c '^s\.')" -lt 2 ] && [ $((SECONDS - s)) -lt "$TD_CEIL" ]; do sleep 0.1; done
  [ "$(ls "$1" | grep -c '^s\.')" -ge 2 ]
}
# td_drive <block> <set> <term|int> -> appends the mode's cells to $WORK/td.<set>.v
td_drive() {
  local blk="$1" set="$2" mode="$3" d="$WORK/td.$2.$3" p s n st root ks k wp t dp dn
  mkdir -p "$d/s" && cp -R "$TDT" "$d/w" || { bad "teardown drive $set/$mode: could not copy the template"; return 1; }
  set -m
  ( cd "$d/w" && unset PREPUSH_POOL_DEPTH && export AI_DLC_FIXTURE_JOBS=2 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 TD_DIR="$d/s" \
    && exec bash -c '. "$1" > /dev/null 2>&1; run_fixtures > "$2" 2>&1' _ "$blk" "$d/out" ) > /dev/null 2>&1 &
  p=$!
  set +m
  if ! td_wait2 "$d/s"; then
    td_hang "$blk" "two stubs to start"
    : > "$d/s/release"; wait "$p"
    case "$mode" in term) printf 'td_term=nostart\ntd_queue=nostart\ntd_rc=nostart\ntd_decoy=nostart\n' ;; int) printf 'td_int=nostart\ntd_intp=nostart\n' ;; esac >> "$WORK/td.$set.v"
    return 0
  fi
  t="$(td_stubs "$d/s")"; root="$(sed -n '1s/^[0-9]* //p' "$d/s/$(ls "$d/s" | grep '^s\.' | sed -n 1p)")"
  if [ "$mode" = term ]; then
    # the decoy: blocks on the same barrier, so the release ends it and nothing here kills it
    ( while [ ! -e "$d/s/release" ] && [ -d "$d/s" ]; do sleep 0.1; done ) > /dev/null 2>&1 &
    dp=$!; printf '%s\n' "$dp" > "$root/.pr/zz-decoy.k"
    kill -TERM "$p"
    # until the parent is gone, or a third stub (a queued unit) has started
    s=$SECONDS
    while kill -0 "$p" 2>/dev/null && [ "$(ls "$d/s" | grep -c '^s\.')" -le 2 ] && [ $((SECONDS - s)) -lt "$TD_CEIL" ]; do sleep 0.1; done
    if kill -0 "$p" 2>/dev/null && [ "$(ls "$d/s" | grep -c '^s\.')" -le 2 ]; then td_hang "$blk" "the parent to exit after TERM"; fi
    n="$(td_alive $(td_stubs "$d/s"))"; dn="$(td_alive "$dp")"
    : > "$d/s/release"; wait "$p"; st=$?; wait "$dp"
    if [ -d "$root" ]; then root=present; else root=gone; fi
    printf 'td_term=%s\ntd_queue=%s\ntd_rc=%s:%s\ntd_decoy=%s\n' "$n" "$(ls "$d/s" | grep -c '^s\.')" "$st" "$root" "$dn" >> "$WORK/td.$set.v"
  else
    ks=""; wp=""
    for k in "$root"/.pr/*.k; do [ -s "$k" ] && { read -r n < "$k"; case "$n" in ''|*[!0-9]*) ;; *) wp="$wp $n"; ks="$ks $k" ;; esac; }; done
    for n in $wp; do kill -INT "$n"; done
    # until every targeted worker has cleared its record (pool_abort empties `.k` before it exits)
    s=$SECONDS
    while [ $((SECONDS - s)) -lt "$TD_CEIL" ]; do
      n=0; for k in $ks; do [ -s "$k" ] && n=1; done
      [ "$n" = 0 ] && break
      sleep 0.1
    done
    n=0; for k in $ks; do [ -s "$k" ] && n=1; done
    [ "$n" = 1 ] && td_hang "$blk" "the workers to clear their records after INT"
    if [ -z "$wp" ]; then n=norecord; else n="$(td_alive $t)"; fi
    # td_intp: once the workers have cleared, the queued stub starts; then INT to the parent itself
    if [ "$n" = 0 ]; then
      s=$SECONDS
      while [ "$(ls "$d/s" | grep -c '^s\.')" -lt 3 ] && [ $((SECONDS - s)) -lt "$TD_CEIL" ]; do sleep 0.1; done
      [ "$(ls "$d/s" | grep -c '^s\.')" -lt 3 ] && td_hang "$blk" "the queued stub to start"
    fi
    kill -INT "$p"
    s=$SECONDS
    while kill -0 "$p" 2>/dev/null && [ $((SECONDS - s)) -lt "$TD_CEIL" ]; do sleep 0.1; done
    kill -0 "$p" 2>/dev/null && td_hang "$blk" "the parent to exit after INT"
    dn="$(td_alive $(td_stubs "$d/s"))"
    : > "$d/s/release"; wait "$p"; st=$?
    if [ -d "$root" ]; then root=present; else root=gone; fi
    printf 'td_int=%s\ntd_intp=%s:%s:%s\n' "$n" "$st" "$root" "$dn" >> "$WORK/td.$set.v"
  fi
}
td_run() { # td_run <block> <set> <cell...>: one drive per mode its cells need
  local blk="$1" set="$2" c tm=0 im=0; shift 2
  : > "$WORK/td.$set.v"
  for c in "$@"; do case "$c" in td_int|td_intp) im=1 ;; *) tm=1 ;; esac; done
  [ "$tm" = 1 ] && td_drive "$blk" "$set" term
  [ "$im" = 1 ] && td_drive "$blk" "$set" int
  return 0
}
td_val() { sed -n "s/^$2=//p" "$WORK/td.$1.v" 2>/dev/null; }
wanttd() { printf '%s\n' "$WANT_TD" | sed -n "s/^$1=//p"; }
td_run "$PB" fix $TD_ALL
for _c in $TD_ALL; do
  v="$(td_val fix "$_c")"
  if [ "$v" = "$(wanttd "$_c")" ]; then ok "[$T] teardown $_c=$v"
  else bad "[$T] teardown $_c read [${v:-none}], want [$(wanttd "$_c")]"; fi
done
# td_mut <name> <sed-expr>: a copy of the block, one edit, exactly one line changed
td_eval() {
  local name="$1" m="$WORK/td.mut.$1.sh" dec tw cells c got="" moved B_mut=1 cond=0 n_run
  dec="$(mrow "$name" decides)"; tw="$(mrow "$name" twins)"
  [ -n "$dec" ] || { bad "MUTANT $name: no MUTANT-MATRIX row in the header"; return 0; }
  dec="${dec//,/ }"; tw="${tw//,/ }"
  sed "$2" "$PB" > "$m" || { bad "MUTANT $name: sed did not apply"; return 0; }
  if cmp -s "$PB" "$m"; then bad "MUTANT $name: the edit matched nothing, so it is not a mutant"; return 0; fi
  # the edit removed or changed exactly one line of the block (a multiset count, so a duplicate line elsewhere still counts)
  [ "$(awk 'NR == FNR { c[$0]++; next } { c[$0]-- } END { for (k in c) if (c[k] > 0) n += c[k]; print n + 0 }' "$PB" "$m")" -eq 1 ] \
    || { bad "MUTANT $name: the edit did not change exactly one line"; return 0; }
  if [ "$MATRIX" = 1 ]; then cells="$TD_ALL"; n_run="$(printf '%s\n' $dec $tw | grep -c .)"; MX_RAN=$((MX_RAN + $(printf '%s\n' $TD_ALL | grep -c .) - n_run)); else cells="$dec $tw"; fi
  ( TD_CEIL="${3:-$TD_CEIL}"; td_run "$m" "$name" $cells )
  for c in $cells; do got="$got$c=$(td_val "$name" "$c")"$'\n'; done
  for c in $dec $tw; do [ "$(td_val fix "$c")" = "$(wanttd "$c")" ] || B_mut=0; done
  moved="$(moved_of "$got" "$WANT_TD")"
  [ "$MATRIX" = 1 ] && mx_row "$name" "$cells" "$moved"
  same_set "$moved" "$dec" && cond=1
  finish_mutant "$B_mut" "$name" "$cond" \
    "MUTANT $name kill confirmed: decides [$dec] moved, twin [${tw:--}] stayed green" \
    "MUTANT $name moved [${moved% }], want [$dec] (twin [${tw:--}])"
}
td_eval td-old-traps "s/trap 'pool_stop 130' INT; trap 'pool_stop 143' TERM; trap 'pool_stop 129' HUP$/trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP/"
td_eval td-no-stop '/^    \[ -f "\$AI_DLC_FX_OUT\/.pr\/.stop" \] && { : > "\$pr.k"; exit 255; }$/d'
# the INT drive waits its ceiling under this mutant (the workers never clear `.k`): 5s, for this mutant only
td_eval td-plain-amp '/^  set -m$/{N;s/^  set -m\n  { PREPUSH_POOL_DEPTH=/  { PREPUSH_POOL_DEPTH=/;}' 5
# the pgid guard removed: pool_stop TERMs every recorded pid, the planted stale record included
td_eval td-no-pgid "s/^      \[ \"\$(ps -o pgid= -p \"\$p\" 2>\/dev\/null | tr -d ' ')\" = \"\$pool_xp\" \] && kill -TERM/      kill -TERM/"

# ------------------------------------------------- pool_stop waits for xargs ONCE (BL-881) ---------
# pool_stop has set INT/TERM/HUP to '' before it waits, so a status above 128 can only mean xargs itself died
# by a signal, and bash 3.2 answers a second wait on that reaped pid with the SAME status, never 127. A
# re-wait loop keyed on "> 128" therefore spins forever with nothing able to stop it. The block's own
# pool_stop text is driven in a subshell whose pool_xp is a child that dies by a signal or by an exit; the
# subshell shadows `wait` with a counter: the FIRST call runs builtin wait, the SECOND exits the subshell with
# PS_SENTINEL, so the verdict is the exit status and no clock decides it. A hang guard (PS_HANG seconds) only
# stops a drive that neither exits nor re-waits; if it fires the fixture is BROKEN (exit 2), never a cell value.
#   ps_sig  -- pool_xp died by SIGKILL (the defect needs only a death by signal; KILL because a fixture can be
#              launched with SIGPIPE or TERM ignored, and a bash child sending itself an ignored signal
#              lives on and exits 0, measured on bash 3.2): "exited:<rc>" or
#              "spun" (a second wait; want exited:130)
#   ps_exit -- pool_xp exited 1, the twin: a re-wait loop ends here too (want exited:130)
PS_SENTINEL=97
PS_HANG=60
[ "$PS_SENTINEL" != 130 ] || { echo "FIXTURE BROKEN: PS_SENTINEL equals pool_stop's exit status"; exit 2; }
ps_drive() { # ps_drive <block> <sig|exit> -> exited:<rc> | spun | nofn | hung
  local d p s
  d="$(mktemp -d "$WORK/ps.XXXXXX")" && mkdir -p "$d/.pr" || { printf 'nodir'; return 0; }
  sed -n '/^pool_stop() {/,/^}/p' "$1" > "$d/fn"
  [ -s "$d/fn" ] || { printf 'nofn'; return 0; }
  # pool_xp is launched under `set -m`, mirroring how the hook launches xargs (a re-wait on bash 3.2 reads
  # the same status again with or without it)
  ( ps_n=0
    wait() { ps_n=$((ps_n + 1)); [ "$ps_n" -lt 2 ] || exit "$PS_SENTINEL"; builtin wait "$@"; }
    . "$d/fn"; out="$d"; set -m
    if [ "$2" = sig ]; then { exec bash -c 'kill -KILL $$'; } & else { exec bash -c 'exit 1'; } & fi
    pool_xp=$!; set +m; pool_stop 130 ) > /dev/null 2>&1 &
  p=$!
  s=$SECONDS
  while kill -0 "$p" 2>/dev/null && [ $((SECONDS - s)) -lt "$PS_HANG" ]; do sleep 0.1; done
  if kill -0 "$p" 2>/dev/null; then kill -KILL "$p" 2>/dev/null; wait "$p" 2>/dev/null; printf 'hung'
  else
    wait "$p"; s=$?
    if [ "$s" = "$PS_SENTINEL" ]; then printf 'spun'; else printf 'exited:%s' "$s"; fi
  fi
}
ps_check_hung() { case " $* " in *" hung "*) echo "FIXTURE BROKEN: a pool_stop drive neither exited nor re-waited within ${PS_HANG}s"; exit 2;; esac; }
PS_WANT=exited:130
# the children are `bash`, never `sh`: tools.decl does not declare sh, so under the hermetic sandbox an
# `exec sh` exits 127 and the signal world silently becomes a second exit world
ps_fix_sig="$(ps_drive "$PB" sig)"; ps_fix_exit="$(ps_drive "$PB" exit)"
ps_check_hung "$ps_fix_sig" "$ps_fix_exit"
B_ps=1
for _c in sig exit; do
  eval "v=\$ps_fix_$_c"
  if [ "$v" = "$PS_WANT" ]; then ok "[$T] pool_stop ps_$_c=$v"
  else bad "[$T] pool_stop ps_$_c read [$v], want [$PS_WANT]"; B_ps=0; fi
done
PS_M="$WORK/ps.mut.sh"
sed 's/^    wait "\$pool_xp"$/    while :; do wait "$pool_xp"; [ "$?" -gt 128 ] || break; done/' "$PB" > "$PS_M"
if cmp -s "$PB" "$PS_M"; then bad "MUTANT ps-rewait: the edit matched nothing, so it is not a mutant"
else
  ps_m_sig="$(ps_drive "$PS_M" sig)"; ps_m_exit="$(ps_drive "$PS_M" exit)"
  ps_check_hung "$ps_m_sig" "$ps_m_exit"
  ps_moved=""
  [ "$ps_m_sig" = "$PS_WANT" ] || ps_moved="${ps_moved}ps_sig "
  [ "$ps_m_exit" = "$PS_WANT" ] || ps_moved="${ps_moved}ps_exit "
  [ "$MATRIX" = 1 ] && mx_row ps-rewait "ps_sig ps_exit" "$ps_moved"
  ps_cond=0; same_set "$ps_moved" "$(mrow ps-rewait decides)" && ps_cond=1
  finish_mutant "$B_ps" ps-rewait "$ps_cond" \
    "MUTANT ps-rewait kill confirmed: decides [ps_sig] moved ($ps_m_sig), twin [ps_exit] stayed green" \
    "MUTANT ps-rewait moved [${ps_moved% }], want [ps_sig] (sig read $ps_m_sig, exit read $ps_m_exit)"
fi

# a plain run executes no matrix-only cell: the counter moves only on the --matrix path
if [ "$MATRIX" = 1 ]; then
  ok "matrix mode: $MX_RAN matrix-only cells were driven beyond the per-push decides and twins"
elif [ "$MX_RAN" -eq 0 ]; then
  ok "a plain run executed no matrix-only cell"
else
  bad "a plain run executed $MX_RAN matrix-only cells"
fi

echo
if [ "$fails" -gt 0 ]; then echo "FAIL: $fails of $asserts assertions wrong."; exit 1; fi
echo "PASS: all $asserts assertions correct."
exit 0
