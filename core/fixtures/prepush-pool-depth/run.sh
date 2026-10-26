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
# EVERY ARM RUNS AGAINST EACH HOOK THAT EXISTS in this layout (named, never derived from one
# another), and the mutants are cmp -s guarded COPIES of the resolved block, each of which must
# fail ONLY its own arm.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset PREPUSH_POOL_DEPTH
# PD_BARRIER_CEIL: the depth-0 barrier's ceiling in seconds, digits only with no leading zero, default 30. drive exports it so
# the stubs derive their own cap from it (ceiling + 10); mutant() passes a smaller one to ONE mutant.
case "${PD_BARRIER_CEIL:-}" in ''|*[!0-9]*|0*|????*) PD_BARRIER_CEIL=30 ;; esac

asserts=0; fails=0
ok()     { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad()    { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "prepush-pool-depth: FIXTURE BROKEN" >&2; exit 2; }

echo "prepush-pool-depth:"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || broken "not in a git repo"
HOOKS=""
for c in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$c" ] && HOOKS="$HOOKS $c"
done
[ -n "$HOOKS" ] || broken "no pre-push hook in either layout from $ROOT"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/prepush-pool-depth.XXXXXX")" || broken "mktemp failed"
trap '[ -s "$WORK/barrier.pid" ] && kill "$(cat "$WORK/barrier.pid")" 2>/dev/null; rm -rf "$WORK"' EXIT

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
# launcher out, and the log files are fresh per drive.
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
  rm -f "$WORK/release" "$WORK/barrier.n" "$WORK/barrier.pid"
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
    if [ -n "$bp" ]; then wait "$bp"; rm -f "$WORK/barrier.pid"; fi
    echo "$r"
  } )"
  printf '%s' "$rc"
}
# barrier_count: the driver's count at release ("_" if the poller never wrote one)
barrier_count() { local n; n="$(cat "$WORK/barrier.n" 2>/dev/null)"; printf '%s' "${n:-_}"; }
maxflight() { sort -n "$WORK/log.flight" 2>/dev/null | tail -1; }

# The nest block is the FIRST resolved hook's, and the chain is rebuilt per scored block because
# the stubs source the file they were built with.
HOOK1="${HOOKS# }"; HOOK1="${HOOK1%% *}"
# ------------------------------------------------------------------ the constructed nest ------
# THREE LEVELS OF STUB: the outer pool dispatches stub A; A drives a copy of the block over its own
# tree holding stub B; B drives it again over a tree holding stub C. Count which stubs STARTED.
# Guarded: A runs, B runs (depth 1), C never starts (B's pool refuses at depth 2). The control is the
# same chain with the refusal removed, where C starts -- so the nest is constructible and the count
# can move.
NB="$WORK/nest.block.sh"; sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK1" > "$NB"
NFXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$NB" | sort -u)"
nest_build() { # nest_build <root> <blockfile>
  local r="$1" blk="$2" lvl next
  # the fixture root is the SCORED block's own: core/fixtures in one hook, tests/fixtures in the other
  NFXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$blk" | sort -u)"
  for lvl in a b c; do
    mkdir -p "$r/$lvl/$NFXR/stub-$lvl"
    case "$lvl" in a) next=b ;; b) next=c ;; c) next="" ;; esac
    {
      printf '#!/usr/bin/env bash\n'
      printf 'for _v in $(env | sed -n "s/^\\(AI_DLC_[A-Za-z0-9_]*\\)=.*/\\1/p"); do unset "$_v"; done\n'
      printf 'printf "%%s depth=%%s\\n" "stub-%s" "${PREPUSH_POOL_DEPTH-unset}" >> "$NEST_LOG"\n' "$lvl"
      if [ -n "$next" ]; then
        printf '( cd "%s/%s" && export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 && . "%s" >/dev/null 2>&1 && run_fixtures >> "$NEST_LOG.out" 2>&1 )\n' "$r" "$next" "$blk"
      fi
      printf 'exit 0\n'
    } > "$r/$lvl/$NFXR/stub-$lvl/run.sh"
    ( cd "$r/$lvl" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
  done
}
nest_run() { # nest_run <root> <blockfile> -> started stubs, space separated
  local r="$1" blk="$2"
  NFXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$blk" | sort -u)"
  : > "$WORK/nest.log"; : > "$WORK/nest.log.out"
  ( cd "$r/a" && export NEST_LOG="$WORK/nest.log" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1; unset PREPUSH_POOL_DEPTH
    . "$blk" >/dev/null 2>&1; run_fixtures >> "$WORK/nest.log.out" 2>&1 )
  sed 's/ depth=.*//' "$WORK/nest.log" | tr '\n' ' '
}
NESTN=0
nest_cells() { # nest_cells <blockfile> -> nest_started / nest_depths / nest_b_present cells
  local blk="$1" r st
  NESTN=$((NESTN+1)); r="$WORK/nestc$NESTN"; nest_build "$r" "$blk"
  st="$(nest_run "$r" "$blk" | sed 's/ *$//')"
  printf 'nest_started=%s\n' "$st"
  printf 'nest_depths=%s\n' "$(sed 's/stub-//; s/ depth=/=/' "$WORK/nest.log" | tr '\n' ' ' | sed 's/ *$//')"
  printf 'nest_b_present=%s\n' "$(grep -c '^stub-b depth=[0-9]' "$WORK/nest.log")"
}
HN=0
for HOOK in $HOOKS; do
  HN=$((HN+1)); TAG="$(basename "$(dirname "$HOOK")")"
  echo "  hook: ${HOOK#"$ROOT"/}"
  BLK="$WORK/block$HN.sh"
  sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK" > "$BLK"
  [ -s "$BLK" ] || broken "extracted an empty FIXTURE_POOL block from $HOOK"
  FXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$BLK" | sort -u)"
  [ "$(printf '%s\n' "$FXR" | grep -c .)" -eq 1 ] || broken "read '$FXR' as the block's fixture root; need exactly one"
  W="$WORK/w$HN"; mkworld "$W" "$FXR" 6 || broken "could not seed the probe world"

  # score <block> <label-prefix> -> prints one verdict line per arm: "<arm>=<got>"
  score() {
    local b="$1" r w1 w2
    # width: FIXTURE_JOBS as the block computes it, at each (depth, jobs).
    for cell in "0 12" "1 12" "1 1" "1 12x" "1 0" "1 abc" "2 12"; do
      set -- $cell
      r="$( cd "$W" && export PREPUSH_POOL_DEPTH="$1" AI_DLC_FIXTURE_JOBS="${2%x}"; . "$b" >/dev/null 2>&1; printf '%s' "$FIXTURE_JOBS" )"
      printf 'width_d%s_j%s=%s\n' "$1" "$2" "$r"
    done
    # an unset marker is depth 0
    r="$( cd "$W" && unset PREPUSH_POOL_DEPTH; export AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "$FIXTURE_JOBS" )"
    printf 'width_unset=%s\n' "$r"
    # a marker SET to a non-number, or to 20 digits, FAILS CLOSED to depth 2. 18446744073709551616 is
    # 2^64: bash arithmetic wraps it to 0, so without the length guard it reads as depth 0 and opens a
    # full pool -- the value that discriminates (99999999999999999999 wraps to a large positive depth
    # and refuses either way, so it could not kill the mutant). 08 is eight, not an octal error.
    r="$( cd "$W" && export PREPUSH_POOL_DEPTH=18446744073709551616 AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "${POOL_DEPTH_IN:-}" )"
    printf 'depth_long=%s\n' "$r"
    r="$( cd "$W" && export PREPUSH_POOL_DEPTH=abc AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "${POOL_DEPTH_IN:-}" )"
    printf 'depth_nonnum=%s\n' "$r"
    r="$( cd "$W" && export PREPUSH_POOL_DEPTH=08 AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "${POOL_DEPTH_IN:-}" )"
    printf 'depth_08=%s\n' "$r"
    # a 20-digit jobs value at depth 1: `[` errors on it, so without the length guard it kept its width
    r="$( cd "$W" && export PREPUSH_POOL_DEPTH=1 AI_DLC_FIXTURE_JOBS=99999999999999999999; . "$b" >/dev/null 2>&1; printf '%s' "$FIXTURE_JOBS" )"
    printf 'width_d1_jlong=%s\n' "$r"
    # observed in flight at depth 1, jobs 12: the cap is real parallelism of two, not a number
    r="$(PD_SLEEP=0.3 drive "$b" "$W" 1 12)"; printf 'obs_d1_rc=%s\nobs_d1_max=%s\n' "$r" "$(maxflight)"
    r="$(PD_SLEEP=0.3 drive "$b" "$W" 1 1)"; printf 'obs_d1_j1_max=%s\n' "$(maxflight)"
    # depth 0, jobs 12: all six stubs in flight AT ONCE, counted at a barrier (drive's PD_BARRIER)
    r="$(PD_BARRIER=1 drive "$b" "$W" 0 12)"; printf 'obs_d0_max=%s\n' "$(barrier_count)"
    # the marker a worker receives: parent + 1
    r="$(drive "$b" "$W" - -)"; printf 'raw_d0=%s\n' "$(sed -n 's/^raw=\([^ ]*\) .*/\1/p' "$WORK/log" | sort -u | tr '\n' ' ' | sed 's/ *$//')"
    r="$(drive "$b" "$W" 1 -)"; printf 'raw_d1=%s\n' "$(sed -n 's/^raw=\([^ ]*\) .*/\1/p' "$WORK/log" | sort -u | tr '\n' ' ' | sed 's/ *$//')"
    # the scrub idiom leaves the marker alone: scrubbed equals raw (a worker with no marker passes
    # vacuously, which is why raw_d0 above is the arm that demands one)
    printf 'scrub_same=%s\n' "$(awk '{ r=$1; s=$2; sub(/^raw=/, "", r); sub(/^scrubbed=/, "", s); if (r != "_" && r != s) bad=1 } END { print bad ? "SCRUBBED" : "kept" }' "$WORK/log")"
    # depth 2 refuses: non-zero, one line naming depth and marker, and NO fixture ran
    r="$(drive "$b" "$W" 2 -)"
    printf 'refuse_rc=%s\nrefuse_line=%s\nrefuse_ran=%s\n' "$r" \
      "$(grep -c 'depth 2.*PREPUSH_POOL_DEPTH' "$WORK/last.out")" "$(grep -c . "$WORK/log")"
    r="$(drive "$b" "$W" 5 12)"; printf 'refuse_d5_rc=%s\n' "$r"
    # the notice: at dispatch (inside run_fixtures) and never at block load
    r="$(drive "$b" "$W" 1 12)"
    printf 'notice_dispatch=%s\nnotice_load=%s\n' "$(grep -c 'nested: depth 1, width [0-9]' "$WORK/last.out")" "$(grep -c 'nested:' "$WORK/load.out")"
    r="$(drive "$b" "$W" 0 12)"; printf 'notice_d0=%s\n' "$(grep -c 'nested:' "$WORK/last.out")"
    # no leak: the sourcing shell's own environment is unchanged by a pool run
    r="$( cd "$W" && unset PREPUSH_POOL_DEPTH; export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PD_LOG="$WORK/log" PD_FLIGHT="$WORK/flight"
          mkdir -p "$PD_FLIGHT"; . "$b" >/dev/null 2>&1; run_fixtures >/dev/null 2>&1; printf '%s' "${PREPUSH_POOL_DEPTH-unset}" )"
    printf 'leak=%s\n' "$r"
    # THE CHAIN: outer pool -> a -> pool -> b -> pool -> c, the marker as each stub sees it AFTER the scrub
    nest_cells "$b"
  }

  # Expected value per arm. One owner per arm: the mutant table below says which mutant moves which.
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
obs_d1_rc=0
obs_d1_max=2
obs_d1_j1_max=1
obs_d0_max=6
raw_d0=1
raw_d1=2
scrub_same=kept
refuse_rc=1
refuse_line=1
refuse_ran=0
refuse_d5_rc=1
notice_dispatch=1
notice_load=0
notice_d0=0
leak=unset
nest_started=stub-a stub-b
nest_depths=a=1 b=2
nest_b_present=1"
  GOT="$(score "$BLK")"
  # BASELINE ASSERTED BEFORE ANY MUTANT: a harness that died prints nothing and would score every
  # mutant as a kill.
  if [ "$(printf '%s\n' "$GOT" | grep -c .)" -eq "$(printf '%s\n' "$WANT" | grep -c .)" ]; then
    ok "[$TAG] the probe emitted every arm ($(printf '%s\n' "$WANT" | grep -c .) cells)"
  else
    bad "[$TAG] the probe emitted $(printf '%s\n' "$GOT" | grep -c .) cells, want $(printf '%s\n' "$WANT" | grep -c .) -- a harness that died reads as clean"
  fi
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
  armcheck "the constructed chain: a and b start, c never does, and a/b see depths 1 and 2 after the scrub" nest_started nest_depths nest_b_present
  armcheck "a depth-2 hook caps the width it would have opened too" width_d2_j12
  armcheck "depth 1 makes jobs=0 two, not BSD xargs -P 0 (unlimited)" width_d1_j0
  armcheck "depth 1 makes a non-numeric jobs value two, not whatever xargs does with it" width_d1_jabc
  armcheck "depth 1 makes a 20-digit jobs value two, not the width [ cannot compare" width_d1_jlong
  armcheck "a 20-digit depth (2^64, which arithmetic wraps to 0) fails closed to depth 2" depth_long
  armcheck "a non-numeric depth fails closed to depth 2" depth_nonnum
  armcheck "a depth of 08 is eight, not an octal error" depth_08

  # ---------------------------------------------------------------- mutants ------------------
  # mutate <name> <sed-expr>: copy the block, apply one edit, refuse a no-op.
  MUTN=0; MUTBAD=0
  # MUTANTS RUN AGAINST THE FIRST RESOLVED HOOK ONLY: I66 holds both blocks to one program, and every drive
  # costs a full run_fixtures setup, so repeating the battery on the twin only buys wall clock.
  # An optional 4th argument is the barrier ceiling for that mutant's score alone, set inside the score's
  # own subshell so every other mutant and the baseline keep PD_BARRIER_CEIL.
  mutant() { # mutant <name> <expected-failing-keys, space separated> <sed-expr> [barrier-ceiling]
    [ "$HN" -eq 1 ] || return 0
    local name="$1" want="$2" ex="$3" ceil="${4:-$PD_BARRIER_CEIL}" m="$WORK/mut$HN.$1.sh" got diffk k
    sed "$ex" "$BLK" > "$m"
    MUTN=$((MUTN+1))
    if cmp -s "$BLK" "$m"; then bad "[$TAG] MUTANT $name: the edit matched nothing, so it is not a mutant"; return 0; fi
    local save="$GOT"; GOT="$(PD_BARRIER_CEIL="$ceil"; score "$m")"
    diffk=""
    for k in $(printf '%s\n' "$WANT" | sed 's/=.*//'); do
      [ "$(printf '%s\n' "$GOT" | sed -n "s/^$k=//p")" = "$(printf '%s\n' "$WANT" | sed -n "s/^$k=//p")" ] || diffk="$diffk $k"
    done
    GOT="$save"
    diffk="${diffk# }"
    if [ "$diffk" = "$want" ]; then ok "[$TAG] MUTANT $name killed by exactly: $diffk"
    else bad "[$TAG] MUTANT $name moved [$diffk], want [$want]"; fi
  }
  mutant not-exported   "raw_d0 raw_d1 nest_started nest_depths nest_b_present" 's/PREPUSH_POOL_DEPTH="\$((POOL_DEPTH_IN + 1))" //'
  mutant not-incremented "raw_d0 raw_d1 nest_started nest_depths" 's/PREPUSH_POOL_DEPTH="\$((POOL_DEPTH_IN + 1))"/PREPUSH_POOL_DEPTH="$POOL_DEPTH_IN"/'
  mutant cap-ignored    "width_d1_j12 width_d1_j12x width_d1_j0 width_d1_jabc width_d2_j12 width_d1_jlong obs_d1_max" 's/^if \[ "\$POOL_DEPTH_IN" -ge 1 \]; then$/if false; then/'
  # each half of the depth-1 cap admitted alone: zero passes the range test, a non-number skips the case
  mutant zero-admitted  "width_d1_j0" 's/^  if \[ "\$FIXTURE_JOBS" -lt 1 \] || /  if [ "$FIXTURE_JOBS" -lt 0 ] || /'
  mutant nonnum-admitted "width_d1_jabc" 's/^  case "\$FIXTURE_JOBS" in '"''"'|\*\[!0-9\]\*|/  case "$FIXTURE_JOBS" in '"''"'|/'
  mutant jlong-admitted "width_d1_jlong" 's/|??????\*) FIXTURE_JOBS=2 ;; esac$/) FIXTURE_JOBS=2 ;; esac/'
  mutant depth-long-admitted "depth_long" 's/^case "\$POOL_DEPTH_IN" in \*\[!0-9\]\*|??????\*) POOL_DEPTH_IN=2 ;; esac$/case "$POOL_DEPTH_IN" in *[!0-9]*) POOL_DEPTH_IN=2 ;; esac/'
  mutant depth-nonnum-zero "depth_nonnum" 's/^case "\$POOL_DEPTH_IN" in \*\[!0-9\]\*|??????\*) POOL_DEPTH_IN=2 ;; esac$/case "$POOL_DEPTH_IN" in *[!0-9]*) POOL_DEPTH_IN=0 ;; ??????*) POOL_DEPTH_IN=2 ;; esac/'
  mutant octal-08      "depth_08" 's/^POOL_DEPTH_IN=\$((10#\$POOL_DEPTH_IN))$/POOL_DEPTH_IN=$((POOL_DEPTH_IN))/'
  mutant ai-dlc-named   "scrub_same nest_started nest_depths nest_b_present" 's/PREPUSH_POOL_DEPTH="\$((POOL_DEPTH_IN + 1))"/AI_DLC_POOL_DEPTH="$((POOL_DEPTH_IN + 1))"/'
  mutant notice-at-load "notice_load" 's/^POOL_DEPTH_IN="\${PREPUSH_POOL_DEPTH:-0}"$/&; [ "$POOL_DEPTH_IN" -ge 1 ] \&\& printf "   nested: depth %s\\n" "$POOL_DEPTH_IN"/'
  mutant no-refusal     "refuse_rc refuse_line refuse_ran refuse_d5_rc nest_started nest_depths" 's/if \[ "\$POOL_DEPTH_IN" -ge 2 \]; then/if false; then/'
  mutant leaks          "leak" 's/^POOL_DEPTH_IN=\$((10#\$POOL_DEPTH_IN))$/&; export PREPUSH_POOL_DEPTH="$((POOL_DEPTH_IN + 1))"/'
  # a depth-0 pool capped at 5 never holds six, so the barrier waits its whole ceiling: 3s, for this mutant only
  mutant pool-capped-5  "obs_d0_max" 's/xargs -P "\$FIXTURE_JOBS" -I{}/xargs -P "$(( FIXTURE_JOBS < 5 ? FIXTURE_JOBS : 5 ))" -I{}/' 3
done

NR="$WORK/nest"; nest_build "$NR" "$NB"
N_GUARDED="$(nest_run "$NR" "$NB")"
if [ "$N_GUARDED" = "stub-a stub-b " ]; then
  ok "NEST: a three-level chain starts stubs a and b and never c ($N_GUARDED) -- depth 2 refuses"
else
  bad "NEST: guarded chain started [$N_GUARDED], want [stub-a stub-b ]"
fi
grep -q 'depth 2.*PREPUSH_POOL_DEPTH' "$WORK/nest.log.out" \
  && ok "NEST: the refusal line is in the inner pool's output" \
  || bad "NEST: no refusal line reached the inner pool's output"
sed 's/^\(  \)\{0,1\}if \[ "\$POOL_DEPTH_IN" -ge 2 \]; then/  if false; then/' "$NB" > "$WORK/nest.open.sh"
if cmp -s "$NB" "$WORK/nest.open.sh"; then bad "NEST CONTROL: the refusal removal matched nothing"
else
  N_OPEN="$(nest_run "$NR" "$WORK/nest.open.sh")"
  # the stubs source the block file they were BUILT with, so rebuild the chain on the open block
  NR2="$WORK/nest2"; nest_build "$NR2" "$WORK/nest.open.sh"; N_OPEN="$(nest_run "$NR2" "$WORK/nest.open.sh")"
  if [ "$N_OPEN" = "stub-a stub-b stub-c " ]; then ok "NEST CONTROL: with the refusal removed the same chain starts c as well ($N_OPEN) -- the nest builds and the count can move"
  else bad "NEST CONTROL: open chain started [$N_OPEN], want [stub-a stub-b stub-c ]"; fi
fi

# ------------------------------------------------- the nested root is watched (BL-691) ------
# A unit that drives the pool again makes its nested pool root at /tmp/fx.XXXXXX, outside its own watched
# root, so before the fix an outer unit whose only progress is its nested pool's scratch was refused. The
# fix makes the watched root discoverable (`.pool-unit`), the nested pool registers its root there
# (`.pool-nested`, with `.pool-parent` naming the marker dir), and the watcher walks validated entries.
# FORCED, not waited for: the outer pool's window is AI_DLC_POOL_STALL=5, exported before the block is
# sourced. Stub A sends its output to /dev/null (so the outer log never grows), scrubs AI_DLC_* (so the
# inner pool runs its default window), heartbeats into its own TMPDIR only until stub B has started, then
# waits on an inner pool over a tree holding stub B. Stub B writes one byte a second under ITS OWN TMPDIR
# for PN_SECS=16 seconds, more than three windows. So the nested scratch is the outer unit's only progress.
#   grow   -- fix: ok. base (the three edits reverted): REFUSED. The pair must DIFFER in this run.
#   silent -- B writes nothing for the same time: REFUSED under the fix (a registered root is not progress).
#   hlink  -- A lists a symlink (spelled bare and with a trailing slash) to a dir it grows, whose
#             .pool-parent names A's own root: REFUSED under the fix.
#   hout   -- A lists the OUTER pool root itself and grows a file in it: REFUSED (no .pool-parent there).
# Every drive runs in its own pair of worlds, concurrently; the inner root a killed inner pool leaves is
# removed by the drive only after its basename matches fx.?????? literally.
cat > "$WORK/pn.stub-a" <<'FX'
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
cat > "$WORK/pn.stub-b" <<'FX'
#!/usr/bin/env bash
printf '%s\n' "$TMPDIR" > "$PN_DIR/btmp"
# silent is ONE sleep, so the inner pool's own bookkeeping (its watcher's pid record) stays still too
[ "$PN_MODE" = grow ] || { sleep "$PN_SECS"; exit 0; }
i=0; while [ "$i" -lt "$PN_SECS" ]; do printf x >> "$TMPDIR/grow"; sleep 1; i=$((i + 1)); done
exit 0
FX
PN_PIDS=""
pn_drive() { # pn_drive <block> <mode> <tag>: backgrounded; writes ok, REFUSED or OTHER to $WORK/pn.<tag>.v
  local blk="$1" mode="$2" tag="$3" d="$WORK/pn.$3" fxr w
  fxr="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$blk" | sort -u)"
  mkdir -p "$d/a/$fxr/stub-a" "$d/b/$fxr/stub-b"
  cp "$WORK/pn.stub-a" "$d/a/$fxr/stub-a/run.sh"; cp "$WORK/pn.stub-b" "$d/b/$fxr/stub-b/run.sh"
  for w in a b; do
    ( cd "$d/$w" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
  done
  ( cd "$d/a" && export AI_DLC_POOL_STALL=5 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PN_BLK="$blk" PN_MODE="$mode" PN_DIR="$d" PN_SECS=16
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
PF_PIDS=""; PF_TAGS=""
pn_v() { local v; v="$(cat "$WORK/pn.$1.v" 2>/dev/null)"; printf '%s' "${v:-none}"; }
# THE NEWEST ROOT IS INSIDE THE WATCHER'S READ WINDOW. The watcher reads the first 16 lines of
# `.pool-nested`, so a registration that appended put a newer live root out of sight once 16 older live
# roots were listed. ord_drive seeds 17 live directories straight into an owned `.t.abcde` marker
# directory's list (no inner pools), runs ONE pool over a single no-op stub under that marker, and writes
# to $WORK/ord.<tag>.v the line number of the one entry that is not a seed ("none" if there is not exactly
# one, so a registration that wrote nothing cannot pass). Backgrounded beside the pn drives.
ord_drive() { # ord_drive <block> <tag>
  local blk="$1" tag="$2" d="$WORK/ord.$2" fxr i m
  fxr="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$blk" | sort -u)"
  mkdir -p "$d/w/$fxr/s" "$d/u/.t.abcde" && : > "$d/u/.t.abcde/.pool-unit" || return 1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/w/$fxr/s/run.sh"
  ( cd "$d/w" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
  m="$(cd "$d/u/.t.abcde" && pwd -P)"
  i=0; while [ "$i" -lt 17 ]; do mkdir -p "$d/old/$i"; printf '%s\n' "$d/old/$i" >> "$d/seed"; i=$((i + 1)); done
  cp "$d/seed" "$m/.pool-nested"
  ( cd "$d/w" && export TMPDIR="$m" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1
    . "$blk" >/dev/null 2>&1; run_fixtures >/dev/null 2>&1
    awk 'NR == FNR { s[$0] = 1; next } !($0 in s) { n++; at = FNR } END { print (n == 1 ? at : "none") }' "$d/seed" "$m/.pool-nested" > "$WORK/ord.$tag.v" ) > /dev/null 2>&1 &
  PN_PIDS="$PN_PIDS $!"
}
ord_v() { local v; v="$(cat "$WORK/ord.$1.v" 2>/dev/null)"; printf '%s' "${v:-none}"; }
# pn_mut <name> <sed-expr> <source block> -> sets PN_M to the mutant copy, or returns 1 (reported) on a
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
PN_HN=0
for HOOK in $HOOKS; do
  PN_HN=$((PN_HN + 1))
  PB="$WORK/pn.block$PN_HN.sh"; sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK" > "$PB"
  pn_mut "base$PN_HN" "$PN_BASE_EX" "$PB" || continue; PBASE="$PN_M"
  # the base must carry none of the three subjects, or it is not the base
  PN_CODE="$(grep -v '^ *#' "$PBASE")"
  if grep -q 'pool-unit\|pool-nested\|pool-parent' <<< "$PN_CODE"; then bad "[$PN_HN] the base block still names a subject"; continue; fi
  bash -n "$PBASE" || { bad "[$PN_HN] the base block does not parse"; continue; }
  pn_drive "$PB" grow "fix$PN_HN"; pn_drive "$PBASE" grow "base$PN_HN"
  pn_drive "$PB" silent "silent$PN_HN"; pn_drive "$PB" hlink "hlink$PN_HN"; pn_drive "$PB" hout "hout$PN_HN"
  pn_drive "$PB" fifo "fifo$PN_HN"; PF_TAGS="$PF_TAGS fifo$PN_HN"
  ord_drive "$PB" "ord$PN_HN"
  if [ "$PN_HN" -eq 1 ]; then
    # the registration as a plain append: the pruned rewrite (two lines) becomes one `>>` of the new root
    pn_mut appendreg '/^            { printf .%s\\n. "\$fx_p"$/{N;s/.*/            printf "%s\\n" "$fx_p" >> "$fx_m\/.pool-nested"; rm -f "$fx_t"/;}' "$PB" \
      && ord_drive "$PN_M" m-appendreg
    # the pre-fix watcher line: the regular-file check on .pool-parent dropped, so the read opens the FIFO
    pn_mut nofifoguard 's/ \[ -f "\$e\/.pool-parent" \] && \[ ! -L "\$e\/.pool-parent" \] &&//' "$PB" \
      && { pn_drive "$PN_M" fifo m-nofifoguard; PF_TAGS="$PF_TAGS m-nofifoguard"; }
    # mutants of the first resolved hook only, as above: I66 holds the twin to the same program
    pn_mut nomark 's/^      : > "\$wr\/.pool-unit"; /      /' "$PB" && pn_drive "$PN_M" grow m-nomark
    pn_mut noread 's/ \${1+"\$@"} -type f -ls/ -type f -ls/' "$PB" && pn_drive "$PN_M" grow m-noread
    pn_mut novalidate 's/case "\${e##\*\/}" in fx\.??????) .* ;; esac$/set -- ${1+"$@"} "$e"/' "$PB" \
      && { pn_drive "$PN_M" hlink m-novalidate-hlink; pn_drive "$PN_M" hout m-novalidate-hout; }
  fi
done
for p in $PN_PIDS; do wait "$p"; done
# THE FIFO ARM IS BOUNDED BY ITS OWN DEADLINE, never by the drive: a watcher that opens the FIFO blocks
# forever, so its unit can only end when its stub is released. Wait on the CONDITION (every fixed hook's
# verdict file present) up to PF_DEADLINE seconds from launch, snapshot every fifo verdict AT that moment,
# and only then release the stubs (each drive's own $d/release), so a hung watcher's unit exits, its
# worker kills the watcher, and every drive pid recorded in PF_PIDS is reaped by `wait`. The mutant's
# verdict is read from the snapshot: under it the watcher never polls again, so nothing is recorded in time.
PF_DEADLINE=40; pf_s=$SECONDS
while [ $((SECONDS - pf_s)) -lt "$PF_DEADLINE" ]; do
  pf_all=1
  for t in $PF_TAGS; do case "$t" in fifo*) [ -s "$WORK/pn.$t.v" ] || pf_all=0 ;; esac; done
  [ "$pf_all" = 1 ] && break
  sleep 1
done
# the mutant gets the same window past its twins' verdicts that they needed from launch, at least 10s
pf_el=$((SECONDS - pf_s)); [ "$pf_el" -lt 10 ] && pf_el=10
pf_s2=$SECONDS; while [ ! -s "$WORK/pn.m-nofifoguard.v" ] && [ $((SECONDS - pf_s2)) -lt "$pf_el" ]; do sleep 1; done
for t in $PF_TAGS; do printf '%s\n' "$(pn_v "$t")" > "$WORK/pf.$t.at"; : > "$WORK/pn.$t/release"; done
for p in $PF_PIDS; do wait "$p"; done
PN_HN=0
for HOOK in $HOOKS; do
  PN_HN=$((PN_HN + 1)); T="nested-root:${HOOK#"$ROOT"/}"
  f="$(pn_v "fix$PN_HN")"; b="$(pn_v "base$PN_HN")"
  if [ "$f" = ok ] && [ "$b" = REFUSED ]; then
    ok "[$T] an outer unit whose only progress is its nested pool's scratch is ok under the fix and REFUSED on the base block, in one run"
  else bad "[$T] forced nested arm: fix=$f base=$b, want fix=ok base=REFUSED"; fi
  v="$(pn_v "silent$PN_HN")"
  [ "$v" = REFUSED ] && ok "[$T] near-miss: a registered nested root that writes nothing is REFUSED" \
                     || bad "[$T] near-miss: a silent registered nested root read $v, want REFUSED"
  v="$(pn_v "hlink$PN_HN")"
  [ "$v" = REFUSED ] && ok "[$T] a listed symlink to a growing dir is never walked: REFUSED" \
                     || bad "[$T] a listed symlink to a growing dir read $v, want REFUSED"
  v="$(pn_v "hout$PN_HN")"
  [ "$v" = REFUSED ] && ok "[$T] a listed path naming the outer pool root itself is never walked: REFUSED" \
                     || bad "[$T] a listed outer pool root read $v, want REFUSED"
  v="$(ord_v "ord$PN_HN")"
  case "$v" in [1-9]|1[0-6]) ok "[$T] with 17 live roots already listed, the new root registers at line $v, inside the watcher's 16-line window" ;;
    *) bad "[$T] with 17 live roots already listed, the new root registered at line $v, want 1-16 (the watcher reads only the first 16)" ;; esac
  v="$(cat "$WORK/pf.fifo$PN_HN.at" 2>/dev/null)"
  [ "$v" = REFUSED ] && ok "[$T] a listed entry whose .pool-parent is a FIFO is never read: the silent unit is REFUSED inside ${PF_DEADLINE}s" \
                     || bad "[$T] a listed FIFO .pool-parent: the unit read ${v:-none} at the deadline, want REFUSED (a watcher blocked on the FIFO never refuses)"
done
v="$(ord_v m-appendreg)"
[ "$v" = 18 ] && ok "MUTANT m-appendreg killed: a plain >> append registers the new root at line 18, outside the watcher's window" \
              || bad "MUTANT m-appendreg: the appended root registered at line $v, want 18"
v="$(cat "$WORK/pf.m-nofifoguard.at" 2>/dev/null)"
[ "$v" = none ] && ok "MUTANT m-nofifoguard killed: with the regular-file check dropped the watcher blocks on the FIFO and no verdict is recorded by the deadline" \
                || bad "MUTANT m-nofifoguard: the FIFO arm read ${v:-unset} at the deadline, want none (no verdict)"
v="$(pn_v m-nofifoguard)"
[ "$v" = ok ] && ok "MUTANT m-nofifoguard control: released after the deadline, the same unit then reaches ok -- the drive ran and was only blocked" \
              || bad "MUTANT m-nofifoguard control: after release the drive read $v, want ok"
for m in m-nomark m-noread; do
  v="$(pn_v "$m")"
  [ "$v" = REFUSED ] && ok "MUTANT $m killed: the forced nested arm is REFUSED" || bad "MUTANT $m: the forced nested arm read $v, want REFUSED"
done
v="$(pn_v m-novalidate-hlink)"; w="$(pn_v m-novalidate-hout)"
[ "$v" = ok ] && [ "$w" = ok ] && ok "MUTANT m-novalidate killed: with the list unvalidated both hostile entries count as progress (ok, ok)" \
                              || bad "MUTANT m-novalidate: hostile entries read hlink=$v hout=$w, want ok ok"

echo
if [ "$fails" -gt 0 ]; then echo "FAIL: $fails of $asserts assertions wrong."; exit 1; fi
echo "PASS: all $asserts assertions correct."
exit 0
