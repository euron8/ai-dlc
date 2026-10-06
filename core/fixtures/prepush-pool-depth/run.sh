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
#   * a hook that STARTS at depth 1 narrows its pool to min(jobs, 2), whatever AI_DLC_FIXTURE_JOBS says;
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
trap 'rm -rf "$WORK"' EXIT

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
: > "$PD_FLIGHT/$$"; sleep "${PD_SLEEP:-0}"
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
drive() {
  local blk="$1" t="$2" depth="$3" jobs="$4" rc
  rm -rf "$WORK/flight"; mkdir -p "$WORK/flight"; : > "$WORK/log"; : > "$WORK/log.flight"
  rc="$( cd "$t" && {
    [ "$depth" = - ] || export PREPUSH_POOL_DEPTH="$depth"
    [ "$jobs" = - ] || export AI_DLC_FIXTURE_JOBS="$jobs"
    export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PD_LOG="$WORK/log" PD_FLIGHT="$WORK/flight" PD_SLEEP="${PD_SLEEP:-0}"
    . "$blk" > "$WORK/load.out" 2>&1
    run_fixtures > "$WORK/last.out" 2>&1; echo $?
  } )"
  printf '%s' "$rc"
}
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
NFXR="$(sed -n 's|^[[:space:]]*for d in \([A-Za-z0-9_./-]*\)/\*/;.*|\1|p' "$NB" | sort -u)"
nest_build() { # nest_build <root> <blockfile>
  local r="$1" blk="$2" lvl next
  # the fixture root is the SCORED block's own: core/fixtures in one hook, tests/fixtures in the other
  NFXR="$(sed -n 's|^[[:space:]]*for d in \([A-Za-z0-9_./-]*\)/\*/;.*|\1|p' "$blk" | sort -u)"
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
  NFXR="$(sed -n 's|^[[:space:]]*for d in \([A-Za-z0-9_./-]*\)/\*/;.*|\1|p' "$blk" | sort -u)"
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
  FXR="$(sed -n 's|^[[:space:]]*for d in \([A-Za-z0-9_./-]*\)/\*/;.*|\1|p' "$BLK" | sort -u)"
  [ "$(printf '%s\n' "$FXR" | grep -c .)" -eq 1 ] || broken "read '$FXR' as the block's fixture root; need exactly one"
  W="$WORK/w$HN"; mkworld "$W" "$FXR" 6 || broken "could not seed the probe world"

  # score <block> <label-prefix> -> prints one verdict line per arm: "<arm>=<got>"
  score() {
    local b="$1" r w1 w2
    # width: FIXTURE_JOBS as the block computes it, at each (depth, jobs).
    for cell in "0 12" "1 12" "1 1" "1 12x" "2 12"; do
      set -- $cell
      r="$( cd "$W" && export PREPUSH_POOL_DEPTH="$1" AI_DLC_FIXTURE_JOBS="${2%x}"; . "$b" >/dev/null 2>&1; printf '%s' "$FIXTURE_JOBS" )"
      printf 'width_d%s_j%s=%s\n' "$1" "$2" "$r"
    done
    # an unset marker is depth 0, and a non-numeric one is read as depth 0 rather than as a refusal
    r="$( cd "$W" && unset PREPUSH_POOL_DEPTH; export AI_DLC_FIXTURE_JOBS=12; . "$b" >/dev/null 2>&1; printf '%s' "$FIXTURE_JOBS" )"
    printf 'width_unset=%s\n' "$r"
    # observed in flight at depth 1, jobs 12: the cap is real parallelism of two, not a number
    r="$(PD_SLEEP=0.3 drive "$b" "$W" 1 12)"; printf 'obs_d1_rc=%s\nobs_d1_max=%s\n' "$r" "$(maxflight)"
    r="$(PD_SLEEP=0.3 drive "$b" "$W" 1 1)"; printf 'obs_d1_j1_max=%s\n' "$(maxflight)"
    r="$(PD_SLEEP=0.3 drive "$b" "$W" 0 12)"; printf 'obs_d0_max=%s\n' "$(maxflight)"
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
width_d2_j12=2
width_unset=12
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

  # ---------------------------------------------------------------- mutants ------------------
  # mutate <name> <sed-expr>: copy the block, apply one edit, refuse a no-op.
  MUTN=0; MUTBAD=0
  # MUTANTS RUN AGAINST THE FIRST RESOLVED HOOK ONLY: I66 holds both blocks to one program, and every drive
  # costs a full run_fixtures setup, so repeating the battery on the twin only buys wall clock.
  mutant() { # mutant <name> <expected-failing-keys, space separated> <sed-expr>
    [ "$HN" -eq 1 ] || return 0
    local name="$1" want="$2" ex="$3" m="$WORK/mut$HN.$1.sh" got diffk k
    sed "$ex" "$BLK" > "$m"
    MUTN=$((MUTN+1))
    if cmp -s "$BLK" "$m"; then bad "[$TAG] MUTANT $name: the edit matched nothing, so it is not a mutant"; return 0; fi
    local save="$GOT"; GOT="$(score "$m")"
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
  mutant cap-ignored    "width_d1_j12 width_d1_j12x width_d2_j12 obs_d1_max" 's/if \[ "\$POOL_DEPTH_IN" -ge 1 \] && \[ "\$FIXTURE_JOBS" -gt 2 \]; then FIXTURE_JOBS=2; fi/:/'
  mutant ai-dlc-named   "scrub_same nest_started nest_depths nest_b_present" 's/PREPUSH_POOL_DEPTH="\$((POOL_DEPTH_IN + 1))"/AI_DLC_POOL_DEPTH="$((POOL_DEPTH_IN + 1))"/'
  mutant notice-at-load "notice_load" 's/^POOL_DEPTH_IN="\${PREPUSH_POOL_DEPTH:-0}"$/&; [ "$POOL_DEPTH_IN" -ge 1 ] \&\& printf "   nested: depth %s\\n" "$POOL_DEPTH_IN"/'
  mutant no-refusal     "refuse_rc refuse_line refuse_ran refuse_d5_rc nest_started nest_depths" 's/if \[ "\$POOL_DEPTH_IN" -ge 2 \]; then/if false; then/'
  mutant leaks          "leak" 's/^POOL_DEPTH_IN="\${PREPUSH_POOL_DEPTH:-0}"$/&; export PREPUSH_POOL_DEPTH="$((POOL_DEPTH_IN + 1))"/'
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

echo
if [ "$fails" -gt 0 ]; then echo "FAIL: $fails of $asserts assertions wrong."; exit 1; fi
echo "PASS: all $asserts assertions correct."
exit 0
