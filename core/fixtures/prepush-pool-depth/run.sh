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
# The one exception is td-life-fd, which re-defines the fixture's own ts_launch with its single ' 9>&- &' removed instead of copying the block.
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
# MUTANT-MATRIX td-no-pgid decides=td_decoy twins=td_term
# MUTANT-MATRIX td-ps-pgid decides=td_sbx_stub,td_sbx_gc,td_sbx_orph,td_sbx_lead,td_sbx_sent twins=td_sbx_rc
# MUTANT-MATRIX td-no-tree decides=td_sbx_gc,td_sbx_lead twins=td_sbx_stub
# MUTANT-MATRIX td-no-pidgrp decides=td_sbx_orph twins=td_sbx_lead
# MUTANT-MATRIX td-no-memgrp decides=td_sbx_lead twins=td_sbx_orph
# MUTANT-MATRIX td-no-mem decides=td_sbx_lead twins=td_sbx_orph
# MUTANT-MATRIX td-life-fd decides=td_life twins=td_life_alive
# MUTANT-MATRIX ps-rewait decides=ps_sig twins=ps_exit
# MUTANT-MATRIX-DYNAMIC finish_mutant why=the one emission site passes the mutant name as a variable; each of the thirty literal callers (mutant, pn_eval, td_eval, the I66 arm, the pool_stop arm and the td-life-fd lifeline arm) has its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/prepush-pool-depth/run.sh --matrix
#
# The matrix is re-measured whenever an arm or a mutant is added or changed, with the command above, run
# from the repository root; its log names every mutant's dead cells. Each mutant co-trips no other arm
# than the ones it decides, measured at authoring. The decides and twins of a mutant are READ FROM THE
# ROWS ABOVE at run time (mrow), so the header cannot drift from what runs. A plain run drives, per
# mutant, only its decides cells and its twin cells, and requires that every cell it is SCORED ON (its
# decides and twins) which moved is in decides. A group drive prints every cell of its group, and a cell
# the mutant is not scored on is dropped before the verdict: a barrier drive run for raw_d0 also prints
# obs_d0_max, the poller's count at the barrier rendezvous (pd_rendezvous), which no marker mutant can
# change, so not-exported, not-incremented and leaks are decided on the marker the child received (raw_*,
# absent reads `_`) and never on that count. --matrix scores every cell it prints, on
# purpose: co-trips are its job. --matrix drives every cell of the mutant's family: the arm cells for the pool mutants, the
# watcher cells (pn_*) for the m-* mutants. The pool mutants are not driven through the watcher cells and
# the m-* mutants are not driven through the pool cells.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset PREPUSH_POOL_DEPTH
MATRIX=0; [ "${1:-}" = --matrix ] && MATRIX=1
MX_RAN=0
# NO WALL CLOCK AND NO ps SAMPLE DECIDES A CELL HERE (BL-868). Every cell is read at a state its subjects WRITE:
# a pool's width at the barrier rendezvous (pd_rendezvous: the settled table's forked-worker count equal to the
# flight files those workers wrote), a watcher verdict at its verdict file, and a watcher hung on a FIFO at the
# sentinel its FIFO's writer leaves when the watcher opens it (pn_settle). A settled ps table (pd_settle) only
# paces those waits and bounds them: a settle is a sample, not a proof, and on this box one read 5 of 6.
# The watcher section's window. PN_STALL is the pool's own AI_DLC_POOL_STALL knob (still polls before a
# refusal; the block reads it from the environment, so lowering it edits no hook). The watcher's `sleep 1`
# is a gated stub there (pn.gbin/sleep), so ONE POLL IS ONE STEP OF THE UNIT, never one second: the unit
# writes step i, the watcher measures poll i, and only then does the unit write step i+1. PN_STEPS is how
# many steps a unit takes before it exits, three windows, so a silent unit crosses the refusal threshold (poll
# 1 + PN_STALL) while a growing one does not; a unit that is refused is killed at that poll, before its last step.
PN_STALL=3; PN_STEPS=$((3 * PN_STALL))
# The safety bound of the barrier poller (see drive) and of pn_settle, in REJECTED SETTLES of one unchanged table:
# it can only turn a drive that never reaches its event into FIXTURE BROKEN, never into a pass or a value.
PD_REJ_MAX=200

asserts=0; fails=0
ok()     { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad()    { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "prepush-pool-depth: FIXTURE BROKEN" >&2; exit 2; }
# SIGINT IGNORED ON ENTRY IS A REFUSAL, NOT A RED. A plain `&` from a non-interactive shell starts this
# fixture with SIGINT ignored, every drive inherits that, and bash cannot re-enable a signal ignored at
# entry: the hook's `trap 'pool_stop 130' INT` and the workers' `trap pool_abort INT` never fire, so the
# INT cell (td_intp, after its worker-INT step) and the mutants they score read red against a correct hook. Setting a trap
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
trap 'pn_reap_writers; pd_release_all; [ -s "$WORK/barrier.pid" ] && kill "$(cat "$WORK/barrier.pid")" 2>/dev/null; rm -rf "$WORK"' EXIT
# pd_release_all: the EXIT trap's release, for a run that ends with a drive still holding (a FIXTURE BROKEN, a TERM).
# The barrier gate is replaced by a regular file, so every later open of it reads EOF, and killing the poller closes
# the only writer of the FIFO an earlier stub holds open. Each watcher-section FIFO is opened read-write once, which
# wakes a party blocked opening it; a stepper woken that way reads EOF and exits. A normal run reaches this with
# every drive already reaped, so it finds nothing to release.
pd_release_all() {
  local g
  [ -n "${WORK:-}" ] && [ -d "$WORK" ] || return 0
  if [ -p "$WORK/gate" ]; then : > "$WORK/gate.open" && mv -f "$WORK/gate.open" "$WORK/gate"; fi
  for g in "$WORK"/pn.*/gate/stub-a/w "$WORK"/pn.*/gate/stub-b/hold "$WORK"/pn.*/hf/fx.fifo00/.pool-parent; do
    [ -p "$g" ] && { : <> "$g"; } 2>/dev/null
  done
  for g in "$WORK"/pn.*/gate/stub-a/p; do [ -p "$g" ] && { printf 'q\n' 1<> "$g"; } 2>/dev/null; done
  return 0
}
# pn_reap_writers: ends every FIFO writer pn_drive started (each is a child of this shell, blocked in open() or in
# its hold read) and reaps it. Run after every drive of a set is reaped, and FIRST in the EXIT trap: a writer
# blocked in open() on a FIFO under $WORK outlives the rm of $WORK, and pd_release_all's open of that FIFO would
# otherwise wake it into its hold read for good.
pn_reap_writers() {
  local w
  [ -n "${WORK:-}" ] && [ -s "$WORK/pn.writers" ] || return 0
  while read -r w; do kill "$w" 2>/dev/null; wait "$w" 2>/dev/null; done < "$WORK/pn.writers"
  : > "$WORK/pn.writers"
}

# ------------------------------------------------------------------ the settled-state primitive --
# pd_tree <root pid> <excluded pid, or 0> -> one word, from ONE `ps` table: G (the root is gone), P (ps gave no
# table, so the state cannot be read), R (a member is runnable, exiting, a zombie, or has a signal pending), or
# S:<signature> (every member -- the root and every descendant by ppid, the excluded pid's subtree left out --
# is blocked, state S or I, with nothing pending; the signature is each member's pid and state). The word is a
# SAMPLE of one table, never proof that the tree cannot move: a member blocked on something the table does not
# show still has work to do, and two tables alike read a barrier at 5 of 6 on a loaded box with no hook defect.
# So no caller decides a cell on it: it paces a wait for an event the subjects write, and counts its rejections.
# A member that is a `sleep` is a TIMER, which ends by itself, so it reads R: a tree holding one has not settled.
# With a third argument the S word ends in `|X<n>:<k>`: n members of the tree whose command is xargs, and k
# members that are a DIRECT child of one, read off the same table, so two tables that agree agree on k too.
pd_tree() {
  local t
  t="$(ps -A -o pid=,ppid=,stat=,pending=,comm= 2>/dev/null)"
  [ -n "$t" ] || { printf 'P'; return 0; }
  awk -v root="$1" -v ex="$2" -v xc="${3:-}" '
    { n++; p[n] = $1; pp[$1] = $2; st[$1] = $3; pd[$1] = $4; cm[$1] = $5; if ($5 ~ /(^|\/)sleep$/) pd[$1] = "timer" }
    END {
      if (!(root in st)) { printf "G"; exit }
      m[root] = 1
      do { ch = 0
           for (i = 1; i <= n; i++) { q = p[i]; if (!(q in m) && q != ex && (pp[q] in m)) { m[q] = 1; ch = 1 } }
      } while (ch)
      sig = ""
      for (i = 1; i <= n; i++) {
        q = p[i]; if (!(q in m)) continue
        if (st[q] !~ /^[SI]/ || pd[q] !~ /^0+$/) { printf "R"; exit }
        sig = sig q ":" st[q] ","
      }
      if (xc != "") {
        nx = 0; k = 0
        for (i = 1; i <= n; i++) { q = p[i]; if ((q in m) && cm[q] ~ /(^|\/)xargs$/) { nx++; xp[q] = 1 } }
        for (i = 1; i <= n; i++) { q = p[i]; if ((q in m) && (pp[q] in xp)) k++ }
        sig = sig "|X" nx ":" k
      }
      printf "S:%s", sig
    }' <<< "$t"
}
# pd_settle <root pid> <excluded pid, or 0> <done command> -> 0 the done command held; 1 SETTLED: two consecutive
# tables read the same blocked member set and the done command still does not hold; 2 ps gave no table; 3 the
# root is gone and the done command does not hold. It ends on the event or on a settle, never on a count of polls
# or on elapsed time (the `sleep 0.1` only paces it); every caller treats a return of 1 as a rejection, not a value.
# A fourth argument is passed to pd_tree as its third; the settled table's word is left in PD_SETTLED.
pd_settle() {
  local s prev=""
  PD_SETTLED=""
  while :; do
    eval "$3" && return 0
    s="$(pd_tree "$1" "$2" "${4:-}")"
    case "$s" in
      G) eval "$3" && return 0; return 3 ;;
      P) return 2 ;;
      S:*) if [ "$s" = "$prev" ]; then PD_SETTLED="$s"; eval "$3" && return 0; return 1; fi; prev="$s" ;;
      *) prev="" ;;
    esac
    sleep 0.1
  done
}
# pd_gate_sleep: gives a drive's subshell a `sleep` FUNCTION, exported, so every bash the pool starts imports it and
# no process is added. It acts only on a pool WATCHER's `sleep 1` -- the only `sleep 1` with the worker's `$b`
# (its unit's name) in scope -- and passes every other call to the real sleep:
#   PD_GATE (the barrier): while the gate is a FIFO the watcher blocks reading it, so a held unit's watcher never
#     polls and the drive's tree can settle; once the poller has put a regular file there it sleeps as shipped.
#   PN_GATE (the watcher section): see the lockstep comment there. Its counter is the watcher's own shell variable.
pd_gate_sleep() {
  sleep() {
    local pn_g pn_t
    if [ "${1:-}" = 1 ] && [ -n "${b:-}" ] && [ -n "${wr:-}" ] && [ -n "${pr:-}" ]; then
      if [ -n "${PD_GATE:-}" ] && [ -p "$PD_GATE" ]; then read -r pn_t < "$PD_GATE"; return 0; fi
      if [ -n "${PN_GATE:-}" ] && [ -d "$PN_GATE/$b" ]; then
        pn_g="$PN_GATE/$b"
        if [ -p "$pn_g/hold" ]; then
          read -r pn_t < "$pn_g/hold"
          while kill -0 "$$" 2>/dev/null; do command sleep 1; done
          return 0
        fi
        pn_k=$(( ${pn_k:-0} + 1 ))
        [ "$pn_k" -gt 1 ] && printf 'p\n' > "$pn_g/p"
        read -r pn_t < "$pn_g/w"
        return 0
      fi
    fi
    command sleep "$@"
  }
  export -f sleep
}

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
# THE BARRIER: a read of the driver's gate, a FIFO whose only writer is the driver's poller. The read
# blocks, with no clock, until the poller has counted and exits (end of file); a stub that opens the gate
# after the count finds a regular empty file there and passes at once.
[ -z "${PD_GATE:-}" ] || read -r _ < "$PD_GATE"
rm -f "$PD_FLIGHT/$$"
printf 'raw=%s scrubbed=%s\n' "${raw:-_}" "${scr:-_}" >> "$PD_LOG"
exit 0
FX
  done
  ( cd "$t" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
}

# pd_rendezvous <drive root pid> <poller pid> -> writes the barrier count to $WORK/barrier.n.
# THE RENDEZVOUS. A settled table is the pool's width only when every worker xargs has forked -- k, the direct
# children of the drive's one xargs, read off that SAME settled table -- has written its flight file (f, counted
# after it). A worker writes its flight file and then blocks on the gate, so once k = f every forked worker is
# held and xargs, blocked too, forks no more: the count cannot move. Any other settle -- nothing forked yet, or a
# forked worker that has not reached its flight file (a schedule a loaded box produced: settled at 5 of 6) -- is
# rejected, one line to barrier.rej, and settled again. A drive whose pool finished first is read as it stands.
# The one trust left: xargs blocked in two tables alike has dispatched every unit it will before a release.
# THE SAFETY BOUND is a count, never a verdict: PD_REJ_MAX rejections in a row of one unchanged table and flight
# count is a drive that will never rendezvous (a state that changes resets it). It writes barrier.hang, which
# hang_check turns into FIXTURE BROKEN in the main shell before any cell is read.
pd_rendezvous() {
  local root="$1" me="$2" st rj=0 lr="" f x nx k n
  while :; do
    pd_settle "$root" "$me" '[ "$(ls "$WORK/flight" | wc -l | tr -d " ")" -ge 6 ]' x; st=$?
    [ "$st" = 1 ] || break
    [ -e "$WORK/pool.done" ] && break
    f="$(ls "$WORK/flight" | wc -l | tr -d ' ')"; x="${PD_SETTLED##*|X}"; nx="${x%%:*}"; k="${x#*:}"
    [ "$nx" = 1 ] && [ "$k" -gt 0 ] && [ "$k" = "$f" ] && break
    printf 'X%s:%s f=%s\n' "$nx" "$k" "$f" >> "$WORK/barrier.rej"
    if [ "$PD_SETTLED f=$f" = "$lr" ]; then rj=$((rj + 1)); else rj=1; lr="$PD_SETTLED f=$f"; fi
    [ "$rj" -ge "$PD_REJ_MAX" ] && { printf 'X%s:%s f=%s\n' "$nx" "$k" "$f" > "$WORK/barrier.hang"; st=hang; break; }
  done
  n="$(ls "$WORK/flight" | wc -l | tr -d ' ')"
  [ "$st" = 2 ] && n=nops
  [ "$st" = hang ] && n=hang
  printf '%s\n' "$n" > "$WORK/barrier.n"
}
# drive <block> <world> <depth|-> <jobs|-> -> prints "<rc>" and leaves output in $WORK/last.out
# The block is sourced in a subshell standing in the world; AI_DLC_READSET_LIVE_TRACE=0 keeps the
# launcher out, and the log files are fresh per drive. The marker left in the sourcing shell after the
# pool ran is written to $WORK/leak.v.
#
# PD_BARRIER=1 drives the six stubs through a BARRIER, so a pool's width is a count of stubs IN FLIGHT AT
# ONCE that no scheduling can move. Each stub creates its flight file and then blocks reading the gate
# FIFO $WORK/gate. A poller started beside run_fixtures holds the gate's only write end, and counts the
# flight dir until either all six are in flight (the event, read off the stubs' own files) or the drive
# reaches the RENDEZVOUS (pd_rendezvous: its process tree settled AND every worker xargs forked has written
# its flight file, so no further stub can start and none is still on its way). Only then does it write the
# count to $WORK/barrier.n, put a regular file in the gate's place and exit, which ends every held read. A
# pool narrower than six holds 5 or fewer at the rendezvous; a slow box only delays the count and never
# changes it. No clock decides it: a settle alone (the form this replaced) read 5 of 6 when a forked worker
# had not yet reached its flight file, the PD_BARRIER_CEIL ceiling before it read 5 of 6 on a box loaded past
# it, and the sleep-overlap read before that read 3 and 5 against 6 under load with no hook defect. The poller's pid is
# recorded in $WORK/barrier.pid for the EXIT trap, whose pd_release_all ends any read still held.
drive() {
  local blk="$1" t="$2" depth="$3" jobs="$4" rc
  rm -rf "$WORK/flight"; mkdir -p "$WORK/flight"; : > "$WORK/log"
  rm -f "$WORK/gate" "$WORK/pool.done" "$WORK/barrier.n" "$WORK/barrier.pid" "$WORK/barrier.rej" "$WORK/leak.v"
  rc="$( cd "$t" && {
    [ "$depth" = - ] || export PREPUSH_POOL_DEPTH="$depth"
    [ "$jobs" = - ] || export AI_DLC_FIXTURE_JOBS="$jobs"
    export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PD_LOG="$WORK/log" PD_FLIGHT="$WORK/flight"
    . "$blk" > "$WORK/load.out" 2>&1
    bp=""
    if [ -n "${PD_BARRIER:-}" ]; then
      mkfifo "$WORK/gate" || { echo "nogate" > "$WORK/barrier.n"; echo 1; exit 0; }
      export PD_GATE="$WORK/gate"; pd_gate_sleep
      ( exec 9<> "$WORK/gate"
        # the poller pid, as the drive recorded it; the tree it settles on is that of its parent, itself left out
        until [ -s "$WORK/barrier.pid" ]; do sleep 0.1; done
        read -r me < "$WORK/barrier.pid"; root="$(ps -o ppid= -p "$me" 2>/dev/null | tr -d ' ')"
        pd_rendezvous "$root" "$me"
        # THE RELEASE. A regular file replaces the gate for every later open; every party that opened the FIFO,
        # at most the six stubs and their six watchers, each reading one line, gets a line. The write end stays
        # open until the pool is done, so a party that resolved the FIFO path just before the rename never
        # blocks opening it; the poller ends with the drive subshell too, which closes the FIFO for good.
        : > "$WORK/gate.open" && mv -f "$WORK/gate.open" "$WORK/gate"
        printf '\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n' >&9
        until [ -e "$WORK/pool.done" ] || ! kill -0 "$root" 2>/dev/null; do sleep 0.1; done ) > /dev/null 2>&1 &
      bp=$!; printf '%s\n' "$bp" > "$WORK/barrier.pid"
    fi
    run_fixtures > "$WORK/last.out" 2>&1; r=$?
    printf '%s\n' "${PREPUSH_POOL_DEPTH-unset}" > "$WORK/leak.v"
    if [ -n "$bp" ]; then : > "$WORK/pool.done"; wait "$bp"; rm -f "$WORK/barrier.pid"; fi
    echo "$r"
  } )"
  printf '%s' "$rc"
}
# barrier_count: the driver's count at release ("_" if the poller never wrote one)
barrier_count() { local n; n="$(cat "$WORK/barrier.n" 2>/dev/null)"; printf '%s' "${n:-_}"; }
# hang_check: run in the MAIN shell after every score, before any cell is read. barrier.hang is never removed by drive.
hang_check() { [ -e "$WORK/barrier.hang" ] && broken "a barrier drive never rendezvoused: $PD_REJ_MAX rejected settles of one table ($(cat "$WORK/barrier.hang"))"; return 0; }
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
# depth 1, jobs 12, through the barrier: the cap is real parallelism of two (two stubs held at once at the
# rendezvous, four queued); the worker receives parent + 1; the
# scrub idiom leaves the marker alone (scrubbed equals raw; a worker with no marker passes vacuously,
# which is why raw_d0 is the cell that demands one); the notice prints at dispatch
grp_D1() {
  local b="$1" r
  r="$(PD_BARRIER=1 drive "$b" "$W" 1 12)"
  printf 'obs_d1_rc=%s\nobs_d1_max=%s\nraw_d1=%s\n' "$r" "$(barrier_count)" "$(raws)"
  printf 'scrub_same=%s\n' "$(awk '{ r=$1; s=$2; sub(/^raw=/, "", r); sub(/^scrubbed=/, "", s); if (r != "_" && r != s) bad=1 } END { print bad ? "SCRUBBED" : "kept" }' "$WORK/log")"
  printf 'notice_dispatch=%s\n' "$(grep -c 'nested: depth 1, width [0-9]' "$WORK/last.out")"
}
grp_D1J1() { local r; r="$(PD_BARRIER=1 drive "$1" "$W" 1 1)"; printf 'obs_d1_j1_max=%s\n' "$(barrier_count)"; }
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
    GOT="$(score "$BLK" nest_started)"; hang_check
    if [ "$(printf '%s\n' "$GOT" | grep -c .)" -eq 4 ]; then
      armcheck_label="[$TAG] the constructed chain over this hook's own fixture root: a and b start, c never does, a/b see depths 1 and 2 after the scrub, and the refusal line reaches the inner pool's output"
    else armcheck_label="[$TAG] the chain emitted $(printf '%s\n' "$GOT" | grep -c .) cells, want 4 -- a harness that died reads as clean"; fi
    mv_nest="$(moved_of "$GOT" "$WANT")"
    if [ "$(printf '%s\n' "$GOT" | grep -c .)" -eq 4 ] && [ -z "$mv_nest" ]; then ok "$armcheck_label"
    else bad "$armcheck_label -- moved: ${mv_nest:-none}"; fi
    continue
  fi
  W="$WORK/w$HN"; mkworld "$W" "$(cat "$WORK/block$HN.fxr")" 6 || broken "could not seed the probe world"

  GOT="$(score "$BLK" $ARM_CELLS)"; hang_check
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
  else bad "[$TAG] depth-0 barrier: $B0 of 6 in flight at the rendezvous"; fi
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
  mutant() { # mutant <name> <sed-expr>; decides and twins come from the header row
    local name="$1" ex="$2" m="$WORK/mut$HN.$1.sh" dec tw cells g moved B_mut c cond=0 n_all n_run
    dec="$(mrow "$name" decides)"; tw="$(mrow "$name" twins)"
    [ -n "$dec" ] || { bad "[$TAG] MUTANT $name: no MUTANT-MATRIX row in the header"; return 0; }
    dec="${dec//,/ }"; tw="${tw//,/ }"; [ "$tw" = - ] && tw=""
    sed "$ex" "$BLK" > "$m" || { bad "[$TAG] MUTANT $name: sed did not apply"; return 0; }
    MUTN=$((MUTN+1))
    if cmp -s "$BLK" "$m"; then bad "[$TAG] MUTANT $name: the edit matched nothing, so it is not a mutant"; return 0; fi
    # the base-pass flag: the unmutated run held every cell this mutant is judged on
    B_mut="$(for c in $dec $tw; do
      [ "$(printf '%s\n' "$GOT" | sed -n "s/^$c=//p")" = "$(printf '%s\n' "$WANT" | sed -n "s/^$c=//p")" ] || { echo 0; exit 0; }
    done; echo 1)"
    if [ "$MATRIX" = 1 ]; then
      cells="$ARM_CELLS"; n_all="$(printf '%s\n' $cells | grep -c .)"; n_run="$(printf '%s\n' $dec $tw | grep -c .)"
      MX_RAN=$((MX_RAN + n_all - n_run))
    else cells="$dec $tw"; fi
    g="$(score "$m" $cells)"; hang_check
    # only the cells this mutant is scored on reach the verdict (a no-op under --matrix, where cells is every arm cell)
    g="$(printf '%s\n' "$g" | awk -F= -v cs=" $cells " 'index(cs, " " $1 " ") > 0')"
    moved="$(moved_of "$g" "$WANT")"
    [ "$MATRIX" = 1 ] && mx_row "$name" "$cells" "$moved"
    same_set "$moved" "$dec" && cond=1
    finish_mutant "$([ "$B_mut" = 1 ] && echo 1 || echo 0)" "$name" "$cond" \
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
  # a depth-0 pool capped at 5 never holds six: the barrier reads 5 at the rendezvous, five held and one queued
  mutant pool-capped-5   's/xargs -P "\$FIXTURE_JOBS" -I{}/xargs -P "$(( FIXTURE_JOBS < 5 ? FIXTURE_JOBS : 5 ))" -I{}/'
done

# ------------------------------------------------- the nested root is watched (BL-691) ------
# A unit that drives the pool again makes its nested pool root at /tmp/fx.XXXXXX, outside its own watched
# root, so before the fix an outer unit whose only progress is its nested pool's scratch was refused. The
# fix makes the watched root discoverable (`.pool-unit`), the nested pool registers its root there
# (`.pool-nested`, with `.pool-parent` naming the marker dir), and the watcher walks validated entries.
# FORCED, not waited for: the outer pool's window is AI_DLC_POOL_STALL=$PN_STALL, exported before the block is
# sourced. Stub A sends its output to /dev/null (so the outer log never grows), scrubs AI_DLC_* (so the
# inner pool runs its default window), and waits on an inner pool over a tree holding stub B. Stub B takes
# PN_STEPS steps, writing one byte under ITS OWN TMPDIR per step. So the nested scratch is the outer unit's
# only progress.
# THE WATCHERS RUN IN LOCKSTEP WITH THE UNITS, so no step can fall between two polls (BL-868: one byte per
# `sleep 1` against three one-second polls was a race a loaded box lost). pn_drive gives the drive a `sleep`
# FUNCTION, exported, so every bash the pool starts imports it and NO EXTRA PROCESS IS STARTED; it acts only
# on a watcher's `sleep 1` (the watcher's `$b` names its unit) whose unit has a gate directory under PN_GATE:
#   stub-a (STEP gate, FIFOs w and p): call k of the watcher writes p (poll k-1 is measured) and then reads w
#     (step k is written). The unit's step writes its byte, then w, then reads p, so poll k sees exactly k steps.
#     The last step waits too, so a unit that is never refused ends with its watcher blocked in call N+1, and
#     its worker kills the watcher; a `q` read from p ends the unit (the fixture's release, below).
#   stub-b (HOLD gate, FIFO hold): the inner watcher's first call blocks until stub B closes hold, so the inner
#     pool's own bookkeeping -- its pid and still-count records, which sit inside the nested root the outer
#     watcher counts -- never moves while it is measured. Stub B opens hold only once its worker's record is
#     written. After stub B is gone the call returns only once its worker is gone too (else the worker kills it).
# Every FIFO is opened per operation, so a party blocks in open() until its peer arrives and no wait has a bound.
#   pn_grow   -- fix: ok. base (the three edits reverted): REFUSED. The pair must DIFFER in this run.
#   pn_silent -- B takes its steps and writes nothing: REFUSED under the fix (a registered root is not progress).
#   pn_hlink  -- A lists a symlink (spelled bare and with a trailing slash) to a dir it grows, whose
#                .pool-parent names A's own root: REFUSED under the fix.
#   pn_hout   -- A lists the OUTER pool root itself and grows a file in it: REFUSED (no .pool-parent there).
#   pn_fifo   -- a listed entry whose .pool-parent is a FIFO is never read: REFUSED, on the drive's own polls.
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
    # a listed fx.?????? directory whose .pool-parent is a FIFO (pn_drive made it, with its writer); then steps
    # with no progress at all, so only a refusal ends this unit (or the fixture's `q`, for a watcher that opened
    # the FIFO and hangs reading it)
    [ -p "$PN_DIR/hf/fx.fifo00/.pool-parent" ] && printf '%s\n' "$PN_DIR/hf/fx.fifo00" > "$TMPDIR/.pool-nested" ;;
esac
. "$PN_DIR/step.sh"
i=0; while [ "$i" -lt "$PN_STEPS" ]; do pn_step "$g"; i=$((i + 1)); done
exit 0
FX
cat > "$PNT/b/$PFXR/stub-b/run.sh" <<'FX'
#!/usr/bin/env bash
# the inner worker's record is written once, just after it starts the inner watcher; wait for it, then
# release the inner watcher's first call only by exiting (see PN_GATE: HOLD)
until [ -s "${TMPDIR%/*}/.pr/stub-b.w" ]; do command sleep 0.1; done
exec 9> "$PN_GATE/stub-b/hold"
printf '%s\n' "$TMPDIR" > "$PN_DIR/btmp"
g=""; [ "$PN_MODE" = grow ] && g="$TMPDIR/grow"
. "$PN_DIR/step.sh"
i=0; while [ "$i" -lt "$PN_STEPS" ]; do pn_step "$g"; i=$((i + 1)); done
exit 0
FX
# pn_step <file or empty>: one step of the unit, with no fork: its byte, then the step token, then the poll token
cat > "$PNT/step.sh" <<'FX'
pn_step() {
  [ -z "$1" ] || printf x >> "$1"
  printf 's\n' > "$PN_GATE/stub-a/w"
  read -r pn_t < "$PN_GATE/stub-a/p"
  [ "$pn_t" != q ] || exit 0
}
FX
printf '#!/usr/bin/env bash\nexit 0\n' > "$PNT/ord/w/$PFXR/s/run.sh"
for w in a b ord/w; do
  ( cd "$PNT/$w" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
done
[ -d "$PNT/a/.git" ] && [ -d "$PNT/b/.git" ] && [ -d "$PNT/ord/w/.git" ] || broken "the watcher template worlds are not repositories"

PN_PIDS=""
pn_drive() { # pn_drive <block> <mode> <tag>: backgrounded; writes ok, REFUSED or OTHER to $WORK/pn.<tag>.v
  local blk="$1" mode="$2" tag="$3" d="$WORK/pn.$3"
  mkdir -p "$d/gate/stub-a" "$d/gate/stub-b" && cp -R "$PNT/a" "$d/a" && cp -R "$PNT/b" "$d/b" && cp "$PNT/step.sh" "$d/step.sh" \
    && mkfifo "$d/gate/stub-a/w" "$d/gate/stub-a/p" "$d/gate/stub-b/hold" || { bad "watcher drive $tag: could not build its worlds and gates"; return 1; }
  # THE FIFO'S WRITER IS THE HANG'S WITNESS. It blocks opening .pool-parent for write, which returns only when a
  # reader opens it -- a watcher that reads the FIFO -- and then writes fifo.opened and holds the FIFO open with
  # nothing in it, so that watcher's read never returns. It is a child of this shell, outside the drive's tree.
  if [ "$mode" = fifo ]; then
    mkdir -p "$d/hf/fx.fifo00" && mkfifo "$d/hf/fx.fifo00/.pool-parent" || { bad "watcher drive $tag: could not build its FIFO"; return 1; }
    ( exec 3> "$d/hf/fx.fifo00/.pool-parent"; : > "$d/fifo.opened"; exec 4< "$d/hf/fx.fifo00/.pool-parent"; read -r _ <&4 ) > /dev/null 2>&1 &
    printf '%s\n' "$!" >> "$WORK/pn.writers"
  fi
  ( cd "$d/a" && export AI_DLC_POOL_STALL="$PN_STALL" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PN_BLK="$blk" PN_MODE="$mode" PN_DIR="$d" PN_STEPS="$PN_STEPS" PN_GATE="$d/gate"
    pd_gate_sleep
    . "$blk" >/dev/null 2>&1; run_fixtures > "$d/out" 2>&1
    if grep -q '^   ok    stub-a$' "$d/out"; then v=ok
    elif grep -q '^   REFUSED  stub-a  ' "$d/out"; then v=REFUSED
    else v=OTHER; fi
    printf '%s\n' "$v" > "$WORK/pn.$tag.v"
    if [ -s "$d/btmp" ]; then
      p="$(cat "$d/btmp")"; p="${p%/*}"
      case "${p##*/}" in fx.??????) [ -d "$p" ] && rm -rf -- "$p" ;; esac
    fi ) > /dev/null 2>&1 &
  PN_PIDS="$PN_PIDS $!:pn.$tag"
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
  PN_PIDS="$PN_PIDS $!:ord.$tag"
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
      pn_fifo)   pn_drive "$blk" fifo "${set}_fifo" ;;
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
# EVERY DRIVE ENDS ON A STATE ITS SUBJECTS WRITE, NEVER ON A DEADLINE OR A ps SAMPLE (BL-868). pn_settle waits on
# each drive in turn for one of two events: its verdict file, or fifo.opened -- the FIFO's writer (pn_drive) got
# past its open, so a watcher opened the FIFO and now hangs reading it, and its unit blocks for its next step.
# The two cannot both come first: a hung watcher never polls again, so its unit never ends and never writes a
# verdict. It records in pf.<tag>.at `hung` on fifo.opened, else the verdict -- the cell pn_fifo reads. A hung
# drive is then RELEASED: a `q` on its step gate ends the unit, its worker kills the watcher, and it writes the
# verdict it reaches released (the m-nofifoguard control: a hung drive was only blocked, and reaches `ok`). Every
# drive is then reaped by `wait`, and only then are the FIFO writers ended.
# A settle with neither event is only a REJECTION (one line to pn.rej): the drive is waited on again. The safety
# bound, PD_REJ_MAX rejections of one unchanged table, can only turn a drive that never reaches either event into
# FIXTURE BROKEN. The settled table this replaced as the decider released a drive it caught between two steps,
# whose `q` then ended a unit that should have been REFUSED as `ok`, and read a slow fix verdict as a hang; the
# PF_DEADLINE=40 / PF_MIN=6 window before it did the latter on a loaded box.
pn_settle() {
  local e p t f d st rj lr
  for e in $PN_PIDS; do
    p="${e%%:*}"; t="${e#*:}"; f="$WORK/$t.v"; d="$WORK/$t"; rj=0; lr=""
    while :; do
      pd_settle "$p" 0 "[ -s \"$f\" ] || [ -e \"$d/fifo.opened\" ]"; st=$?
      [ "$st" = 2 ] && broken "watcher drive $t: ps gives no process table, so the wait for its verdict cannot be paced"
      [ "$st" = 1 ] || break
      printf '%s %s\n' "${t#pn.}" "$PD_SETTLED" >> "$WORK/pn.rej"
      if [ "$PD_SETTLED" = "$lr" ]; then rj=$((rj + 1)); else rj=1; lr="$PD_SETTLED"; fi
      [ "$rj" -ge "$PD_REJ_MAX" ] && broken "watcher drive $t: neither a verdict nor a FIFO open after $PD_REJ_MAX rejected settles of one table ($lr)"
    done
    case "$t" in
      pn.*) if [ -e "$d/fifo.opened" ]; then echo hung; else cat "$f" 2>/dev/null; fi > "$WORK/pf.${t#pn.}.at" ;;
    esac
    # HUNG: the stepper is blocked opening its step FIFO (its watcher never came back for the step) or reading its
    # poll FIFO. Both are held open read-write here until the drive is reaped, so the step write lands in the
    # buffer whichever open it is in, and the `q` waits in the poll FIFO until it is read; the stepper exits, its
    # unit ends, and its worker kills the hung watcher.
    if [ -e "$d/fifo.opened" ] && [ -p "$d/gate/stub-a/p" ]; then
      exec 7<> "$d/gate/stub-a/w" 8<> "$d/gate/stub-a/p"
      printf 'q\n' >&8
      wait "$p"
      exec 7>&- 8>&-
    fi
  done
  for e in $PN_PIDS; do wait "${e%%:*}" 2>/dev/null; done
  pn_reap_writers
  PN_PIDS=""
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
  local name="$1" dec tw cells c got="" moved B_mut cond=0 ctl=1 n_run
  dec="$(mrow "$name" decides)"; tw="$(mrow "$name" twins)"
  [ -n "$dec" ] || { bad "MUTANT $name: no MUTANT-MATRIX row in the header"; return 0; }
  dec="${dec//,/ }"; tw="${tw//,/ }"; [ "$tw" = - ] && tw=""
  if [ "$MATRIX" = 1 ]; then cells="$PN_ALL"; n_run="$(printf '%s\n' $dec $tw | grep -c .)"; MX_RAN=$((MX_RAN + 6 - n_run)); else cells="$dec $tw"; fi
  for c in $cells; do got="$got$c=$(pn_val "$name" "$c")"$'\n'; done
  B_mut="$(for c in $dec $tw; do [ "$(pn_val fix "$c")" = "$(wantpn "$c")" ] || { echo 0; exit 0; }; done; echo 1)"
  moved="$(moved_of "$got" "$WANT_PN")"
  [ "$MATRIX" = 1 ] && mx_row "$name" "$cells" "$moved"
  # released once its FIFO writer saw the open, the hung unit then reaches ok: the drive ran and was only blocked
  if [ "$name" = m-nofifoguard ] && [ "$(pn_v m-nofifoguard_fifo)" != ok ]; then ctl=0; fi
  same_set "$moved" "$dec" && [ "$ctl" = 1 ] && cond=1
  finish_mutant "$([ "$B_mut" = 1 ] && echo 1 || echo 0)" "$name" "$cond" \
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
[ "$v" = REFUSED ] && ok "[$T] a listed entry whose .pool-parent is a FIFO is never read: the silent unit is REFUSED on the drive's own polls" \
                   || bad "[$T] a listed FIFO .pool-parent: the unit read ${v:-none}$([ "$v" = hung ] && printf ' (hung: its watcher opened the FIFO)'), want REFUSED (a watcher blocked on the FIFO never refuses)"
for _m in $PN_MUTS; do pn_eval "$_m"; done

# ------------------------------------------------- I66 binds the two blocks (once per push) ------
# The hook-2 watcher and mutant drives were deleted on the strength of I66, which byte-compares the two
# FIXTURE_POOL blocks (comments and blanks stripped, fixture root mapped). This arm proves I66 can fail:
# the validator is driven with `--arms I66` over two trees of the eleven files it needs, one clean and one
# with a single non-FXROOT byte added on an executable line of hook 2's block. The clean tree is a hard
# precondition: a dependency missing from the copy set would fail I66 there too, and the seeded failure
# would then read as a catch. It runs outside the mutant loop, once per push, and drives no pool.
# I66_STUBS are prose files the validator's preamble requires to EXIST and I66 never reads: measured, an
# empty stub for each leaves the clean tree at rc 0 and the seeded tree at rc 1 with `FAIL: I66`, and the
# file absent is rc 2 (`tool-fail: required input not found`). They are seeded empty, so an edit to that
# prose cannot move this fixture's verdict and the fixture does not key on them.
I66_FILES="scripts/validate-enforcement-map.sh scripts/render-invariant-index.sh .githooks/pre-push core/git-hooks/pre-push core/scripts/hermetic-run.sh core/scripts/derive-fixture-readsets.sh core/skills/ai-dlc/enforcement-map.yaml"
I66_STUBS="core/skills/ai-dlc/steps/gate-validation.md core/skills/ai-dlc/core-manifest.md core/skills/ai-dlc-update/fixture-manifest.md core/skills/ai-dlc-update/reconcile/setup-sites.md"
i66_tree() { # i66_tree <dir>
  local d="$1" f
  for f in $I66_FILES; do
    [ -f "$ROOT/$f" ] || broken "I66 copy set: $f is absent from $ROOT"
    mkdir -p "$d/$(dirname "$f")" && cp -p "$ROOT/$f" "$d/$f" || broken "I66 copy set: could not copy $f"
  done
  for f in $I66_STUBS; do
    mkdir -p "$d/$(dirname "$f")" && : > "$d/$f" || broken "I66 copy set: could not stub $f"
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
#   td_intp  -- INT first to each worker recorded in `.k`; once both workers cleared their `.k` (and both
#               targeted stubs read dead), xargs dispatches the queued stub (an exit of 130 does not stop it); INT
#               to the parent then: "<rc>:<root>:<stubs alive>" (want 130:gone:0), the ^C an operator sends
# Signals go only to the drive's own pid and to the pids the workers recorded; release ends every stub.
TD_ALL="td_term td_queue td_rc td_decoy td_intp"
# THE SANDBOXED TERM DRIVE (BL-881): the same TERM drive, with ONLY the run_fixtures launch under
# `sandbox-exec -p '(version 1)(allow default)' /bin/bash -c ...`, where the setuid /bin/ps cannot run, so
# pool_stop's group listing and pool_kill's descendant walk must both work without ps. sandbox-exec execs in
# place, so the launch pid is the bash running run_fixtures. Each stub starts a `set -m` grandchild (its own
# group, so a kill of the stub's group misses it) and records the grandchild's pid BEFORE its own record, so
# two stub records imply two grandchild records. The observer stays OUTSIDE the sandbox. LIVENESS: a pid is
# alive iff it is a whole line of `pgrep -g <pid>` -- each stub and grandchild leads its own group (asserted
# before the TERM), a zombie leader lists nothing, and no clock or heartbeat decides it.
#   td_sbx_stub -- recorded stubs alive once the parent has exited (want 0)
#   td_sbx_gc   -- recorded grandchildren alive then (want 0): pool_kill's ps-free walk reaches them
#   td_sbx_rc   -- "<parent rc>:<pool root>:<stubs that ever started>" after release (want 143:gone:2)
#   td_sbx_orph -- recorded unit-group orphans alive then (want 0): each stub forks a child in its OWN group whose
#                  parent subshell exits at once (ppid 1), so no `pgrep -P` walk reaches it and only the per-pid
#                  group KILL of the stub's own group does
#   td_sbx_lead -- recorded orphaned group LEADERS alive then (want 0): each stub starts a `set -m` child under a
#                  subshell, waits for ONE WHOLE WATCHER POLL that began after the child existed, then lets the
#                  subshell exit, so the child is reparented and only the watcher's ps-free group memory reaches it.
#                  The event, with no clock: a `sleep` PATH shim GATES every watcher
#                  poll, so each watcher polls exactly once. Its FIRST sleep makes the fifo `ev.<watcher>`, holds it
#                  open read-write and blocks reading it; the stub reads the watcher from `.pr/<unit>.w` and, once
#                  its child exists, writes `go` there, so the one poll body that follows began after the child
#                  existed. The SECOND sleep writes `frozen.<watcher>` and blocks on the drive's LIFELINE lock
#                  (TL_ALL below says how) until it is released. The stub then reads `.g` with no write in flight and records `remembered` or
#                  `unremembered` (r.<stub>), and proceeds either way, so a hook without the memory reads
#                  td_sbx_lead=2 and never waits on `.g`; a `note` line names how many read remembered when not
#                  both did. THE FROZEN SLEEP NEVER RETURNS INTO THE WATCHER: the release does not end it, so no
#                  watcher polls again after the teardown begins, and every start in this drive happens a fixed
#                  number of times (a frozen sleep that returned on the release raced the worker's group KILL to
#                  one more poll, measured 11 and 12 ps starts under td-ps-pgid). It ends when its watcher's group
#                  is KILLed -- by pool_abort under the fix, by the worker once its unit exits under every mutant
#                  -- and otherwise at the lifeline lock's release: the drive closes fd 9 after the parent's exit, or
#                  dies, and the shim KILLs its own watcher and exits; a seam that cannot be set up execs the real
#                  sleep, so it degrades to the hook's own cadence and never spins, and first notes the fallback
#                  on the drive-death drive's evlog, so that drive reads nofreeze rather than waiting for a freeze.
#                  `fallback-poll` is COUPLED TO THE HOOK'S INTERNALS: it tells a watcher's poll from a unit's sleep
#                  by the rule that the block gives a unit a `$AI_DLC_FX_OUT/.t.*` TMPDIR while the watcher inherits
#                  the worker's own TMPDIR, so a hook that changes either TMPDIR breaks the note's test.
# NO CLOCK DECIDES A CELL (BL-868). Every wait ends on an event: a stub record, the parent's exit, a third stub, a
# cleared `.k`, or the END RECORD -- a pid planted in `.pr/zz-end.k`, after every worker record in glob order, and
# a `ps` PATH shim that runs the real ps and, AFTER it answers, writes `end.seen` when asked about that pid. A
# pool_stop that tests each record with ps (td-ps-pgid) therefore marks the end of its kill loop, and the drive
# reads its cells there instead of waiting for a parent that will not exit until the release. The fix never asks
# ps about a record (pgrep is declared), so for it the event is the parent's exit.
# LIVENESS, ps-free (sandbox-exec denies the setuid /bin/ps to the observer too, when the whole run is sandboxed):
# a group leader is alive iff it is a whole line of `pgrep -g <pid>`; a unit-group orphan iff it is a whole line of
# `pgrep -g <its stub>`; a non-leader (the decoy) iff it is a whole line of `pgrep -U <uid>`. Each lists a live pid
# and omits a zombie, measured plain and under allow-default sandbox-exec.
#   td_sbx_sent -- "<sentinel>:<end mark>" (want signalled:nomark): the SENTINEL is a recorded pid in xargs' group
#                  that blocks TERM, so the fix TERMs it and the TERM stays pending; the fix never asks ps about a
#                  record, so the END RECORD's ps shim never marks. A pool_stop testing records with ps reads
#                  unsignalled:mark, and the mark is the event its cells are read on.
TS_ALL="td_sbx_stub td_sbx_gc td_sbx_orph td_sbx_lead td_sbx_sent td_sbx_rc"
# THE LIFELINE (BL-868): a frozen sleep shim must end when the DRIVE dies before its cells are read (an interrupted
# push, an outer pool killing this tree, a traced run), and no clock may end it. The drive opens the file `life` on
# fd 9 and takes LOCK_EX on that open file description (ts_hold); a flock belongs to the DESCRIPTION, so it is held
# while any process holds fd 9 and released when the last one closes it: the drive's exit, by any death, or its own
# close once its cells are read. Every launch it makes closes fd 9 (`9>&-`: the subject's run_fixtures launch in
# ts_launch, the perl sentinel, the end record), and the frozen shim execs a perl that opens `life` afresh and
# blocks in flock(LOCK_SH), then KILLs its own watcher (still its parent) so it polls no more, and exits. The
# first-poll `go` wake stays on `ev.<watcher>`: each of the two sleeps waits for exactly one event.
# WHY A LOCK AND NOT A FIFO'S EOF: two readers blocked on one fifo whose last writer was KILLed, nothing else touching
# it, woke 1 of 2 on this kernel; the other stayed in read() for good. Two flock waiters woke 2 of 2 in 10 of 10 runs,
# plain and under allow-default sandbox-exec, and with a descendant keeping fd 9 the lock stayed held and 0 woke.
#   td_life_alive -- the CONTROL, the sub-drive alive: "<its answer to a probe>:<frozen shims listed in their
#                    watchers' groups after it>:<lifeline lock>" (want marker:2:held), or "nofreeze:<event>:<freezes>"
#                    when a fallback note or the subject's exit (`subject-exit`) ended the wait before both froze
#   td_life       -- the sub-drive KILLed by its recorded pid: "exited:<shims that took the lock and exited>", read
#                    once a fifo every shim holds open reads EOF (one reader, this drive), or "leaked:held" when a
#                    descendant still holds fd 9, read by one non-blocking lock attempt, so that read cannot hang (want exited:2)
# tl_drive HAS ONE REMAINING COUPLING: if the hook's pool starts but its watcher never polls through the PATH `sleep` and never takes a shim fallback, no event arrives and tl_drive blocks instead of reporting `nofreeze`. Every other failure ends on an event: a fallback-* note, a `subject-exit` line, or the lifeline's release.
TL_ALL="td_life_alive td_life"
WANT_TD="td_term=0
td_queue=2
td_rc=143:gone
td_decoy=1
td_intp=130:gone:0
td_sbx_stub=0
td_sbx_gc=0
td_sbx_orph=0
td_sbx_lead=0
td_sbx_sent=signalled:nomark
td_sbx_rc=143:gone:2
td_life_alive=marker:2:held
td_life=exited:2"
# THE SANDBOX DRIVE'S TOOLS ARE DECLARED, so their absence is FIXTURE BROKEN, never a SKIP: this fixture is
# .dist-only and every box that runs it has them. A refused allow-default profile (a nested sandbox) is the same.
command -v pgrep > /dev/null 2>&1 || broken "pgrep is declared in tools.decl and not found"
command -v sandbox-exec > /dev/null 2>&1 || broken "sandbox-exec is declared in tools.decl and not found"
sandbox-exec -p '(version 1)(allow default)' /usr/bin/true > /dev/null 2>&1 || broken "sandbox-exec refused an allow-default profile running /usr/bin/true (a nested sandbox?)"
TDT="$WORK/td.tpl"
for _i in 1 2 3; do
  mkdir -p "$TDT/$PFXR/q$_i" || broken "could not build the teardown template"
  cat > "$TDT/$PFXR/q$_i/run.sh" <<'FX'
#!/usr/bin/env bash
printf '%s %s\n' "$$" "${TMPDIR%/*}" > "$TD_DIR/s.$$"
while [ ! -e "$TD_DIR/release" ] && [ -d "$TD_DIR" ]; do sleep 0.1; done
exit 0
FX
done
( cd "$TDT" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
[ -d "$TDT/.git" ] || broken "the teardown template world is not a repository"
TST="$WORK/ts.tpl"
for _i in 1 2 3; do
  mkdir -p "$TST/$PFXR/q$_i" || broken "could not build the sandboxed teardown template"
  cat > "$TST/$PFXR/q$_i/run.sh" <<'FX'
#!/usr/bin/env bash
up() { [ ! -e "$TD_DIR/release" ] && [ -d "$TD_DIR" ]; }
hold() { while up; do "$TD_SLP" 0.1; done; }
set -m
( hold ) &
printf '%s\n' "$!" > "$TD_DIR/g.$$"
set +m
( hold & printf '%s\n' "$!" > "$TD_DIR/m.$$" )
( set -m; hold & printf '%s\n' "$!" > "$TD_DIR/o.$$"
  while [ ! -e "$TD_DIR/o.$$.go" ] && up; do "$TD_SLP" 0.1; done ) &
c=$!
read -r o < "$TD_DIR/o.$$" 2> /dev/null || o=""
while [ -z "$o" ] && [ -d "$TD_DIR" ]; do "$TD_SLP" 0.1; read -r o < "$TD_DIR/o.$$" 2> /dev/null || o=""; done
pr="$AI_DLC_FX_OUT/.pr/$(basename "$(dirname "$0")")"
read -r w < "$pr.w" 2> /dev/null || w=""
while [ -z "$w" ] && up; do "$TD_SLP" 0.1; read -r w < "$pr.w" 2> /dev/null || w=""; done
while [ ! -p "$TD_DIR/ev.$w" ] && up; do "$TD_SLP" 0.1; done
up && printf 'go\n' > "$TD_DIR/ev.$w"
while [ ! -e "$TD_DIR/frozen.$w" ] && up; do "$TD_SLP" 0.1; done
{ read -r _k; read -r _g; } < "$pr.g" 2> /dev/null || _g=""
case " $_g " in *" $o "*) echo remembered ;; *) echo unremembered ;; esac > "$TD_DIR/r.$$"
: > "$TD_DIR/o.$$.go"; wait "$c"
printf '%s %s\n' "$$" "${TMPDIR%/*}" > "$TD_DIR/s.$$"
hold
exit 0
FX
done
( cd "$TST" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
[ -d "$TST/.git" ] || broken "the sandboxed teardown template world is not a repository"
ts_alive() { # ts_alive <pid...> -> how many are a whole line of `pgrep -g <pid>` (alive leaders of their own group)
  local p n=0
  for p in "$@"; do
    case $'\n'"$(pgrep -g "$p" 2>/dev/null)"$'\n' in *$'\n'"$p"$'\n'*) n=$((n + 1)) ;; esac
  done
  printf '%s' "$n"
}
td_alive() { ts_alive "$@"; } # every plain-drive stub leads its own group (the pool starts each unit under set -m)
td_inl() { # td_inl <listing> <pid...> -> how many of the pids are a whole line of the listing
  local l="$1" p n=0; shift
  for p in "$@"; do case $'\n'"$l"$'\n' in *$'\n'"$p"$'\n'*) n=$((n + 1)) ;; esac; done
  printf '%s' "$n"
}
td_user() { td_inl "$(pgrep -U "$UID" 2>/dev/null)" "$@"; } # a NON-leader (the decoy): a live pid is listed, a zombie is not
td_orph() { # td_orph <stub pids> <orphan pids>: orphans listed in their stubs' groups (the stub pid names the group)
  local p l=""
  for p in $1; do l="$l"$'\n'"$(pgrep -g "$p" 2>/dev/null)"; done
  td_inl "$l" $2
}
td_stubs() { cat "$1"/s.* 2>/dev/null | cut -d' ' -f1 | tr '\n' ' '; }
td_wait2() { # td_wait2 <stub dir>: until two stubs have recorded; every stub starts (no mutant touches dispatch)
  while [ "$(ls "$1" | grep -c '^s\.')" -lt 2 ]; do sleep 0.1; done
}
# td_drive <block> <set> <term|int> -> appends the mode's cells to $WORK/td.<set>.v
td_drive() {
  local blk="$1" set="$2" mode="$3" d="$WORK/td.$2.$3" p n st root ks k wp t dp dn
  mkdir -p "$d/s" && cp -R "$TDT" "$d/w" || { bad "teardown drive $set/$mode: could not copy the template"; return 1; }
  set -m
  ( cd "$d/w" && unset PREPUSH_POOL_DEPTH && export AI_DLC_FIXTURE_JOBS=2 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 TD_DIR="$d/s" \
    && exec bash -c '. "$1" > /dev/null 2>&1; run_fixtures > "$2" 2>&1' _ "$blk" "$d/out" ) > /dev/null 2>&1 &
  p=$!
  set +m
  td_wait2 "$d/s"
  t="$(td_stubs "$d/s")"; root="$(sed -n '1s/^[0-9]* //p' "$d/s/$(ls "$d/s" | grep '^s\.' | sed -n 1p)")"
  # the readers' precondition, before any signal: both stubs read alive (a reader that reads everything dead fails here)
  q="$(td_alive $t)"
  [ "$q" = 2 ] || { [ "$blk" = "$PB" ] && broken "teardown drive: $q of 2 recorded stubs read alive by pgrep -g before the signal"; }
  if [ "$mode" = term ]; then
    # the decoy: blocks on the same barrier, so the release ends it and nothing here kills it; a NON-leader
    ( while [ ! -e "$d/s/release" ] && [ -d "$d/s" ]; do sleep 0.1; done ) > /dev/null 2>&1 &
    dp=$!; printf '%s\n' "$dp" > "$root/.pr/zz-decoy.k"
    q="$(td_user "$dp")"
    [ "$q" = 1 ] || { [ "$blk" = "$PB" ] && broken "teardown drive: the live decoy $dp read $q by pgrep -U before the TERM"; }
    kill -TERM "$p"
    # until the parent is gone, or a third stub (a queued unit) has started
    while kill -0 "$p" 2>/dev/null && [ "$(ls "$d/s" | grep -c '^s\.')" -le 2 ]; do sleep 0.1; done
    n="$(td_alive $(td_stubs "$d/s"))"; dn="$(td_user "$dp")"
    : > "$d/s/release"; wait "$p"; st=$?; wait "$dp"
    if [ -d "$root" ]; then root=present; else root=gone; fi
    printf 'td_term=%s\ntd_queue=%s\ntd_rc=%s:%s\ntd_decoy=%s\n' "$n" "$(ls "$d/s" | grep -c '^s\.')" "$st" "$root" "$dn" >> "$WORK/td.$set.v"
  else
    ks=""; wp=""
    for k in "$root"/.pr/*.k; do [ -s "$k" ] && { read -r n < "$k"; case "$n" in ''|*[!0-9]*) ;; *) wp="$wp $n"; ks="$ks $k" ;; esac; }; done
    for n in $wp; do kill -INT "$n"; done
    # until every targeted worker has cleared its record (pool_abort empties `.k` before it exits)
    while :; do
      n=0; for k in $ks; do [ -s "$k" ] && n=1; done
      [ "$n" = 0 ] && break
      sleep 0.1
    done
    if [ -z "$wp" ]; then n=norecord; else n="$(td_alive $t)"; fi
    # td_intp: once the workers have cleared, the queued stub starts; then INT to the parent itself
    if [ "$n" = 0 ]; then
      while [ "$(ls "$d/s" | grep -c '^s\.')" -lt 3 ]; do sleep 0.1; done
    fi
    kill -INT "$p"
    while kill -0 "$p" 2>/dev/null; do sleep 0.1; done
    dn="$(td_alive $(td_stubs "$d/s"))"
    : > "$d/s/release"; wait "$p"; st=$?
    if [ -d "$root" ]; then root=present; else root=gone; fi
    printf 'td_intp=%s:%s:%s\n' "$st" "$root" "$dn" >> "$WORK/td.$set.v"
  fi
}
# ts_shims <drive dir> -> writes the ps and sleep shims into <dir>/shim and sets slp to the real sleep
ts_shims() {
  # the ps shim answers as the sandboxed /bin/ps does (no output, exit 71); asked about the END RECORD pid it then
  # marks `end.seen`. It is first on the SUBJECT's PATH only, so ps fails for the block even when nothing is sandboxed.
  printf '#!/usr/bin/env bash\nread -r e < "$TD_DIR/end.pid" 2> /dev/null || e=x\nfor a in "$@"; do [ "$a" = "$e" ] && : > "$TD_DIR/end.seen"; done\nexit 71\n' > "$1/shim/ps" \
    && chmod +x "$1/shim/ps" || { bad "teardown drive: could not write the ps shim"; return 1; }
  # the sleep shim gates the watcher's polls (the td_sbx_lead header says how): a watcher's `sleep 1` (a pool
  # worker's env carries AI_DLC_FX_OUT) blocks on the fifo `ev.<parent>` until the stub's `go`; the second blocks
  # on the LIFELINE `life` until its group's KILL or the lifeline lock's release; any other sleep execs the real one.
  # EVERY FALLBACK A WATCHER CAN TAKE IS AN EVENT: where a watcher's poll execs the real sleep (it polls with other
  # than `sleep 1`, its fifo cannot be made, or `life` is absent), the shim first notes `fallback-poll`,
  # `fallback-fifo` or `fallback-life` on the drive-death drive's evlog, so that drive reports nofreeze instead of
  # waiting for a freeze that cannot come. Which processes reach the poll test: every `sleep` under the subject. One
  # with AI_DLC_FX_OUT unset is not in a pool worker (run_fixtures itself) and is never noted. In a worker's env the
  # block starts the unit with TMPDIR set to its watched root `$AI_DLC_FX_OUT/.t.XXXXX`, and the watcher inherits
  # the worker's own TMPDIR; the worker's shell sleeps nowhere, so a sleep with AI_DLC_FX_OUT set and TMPDIR outside
  # `$AI_DLC_FX_OUT/.t.*` is the watcher's poll, and a unit's sleep (a stub's, at any depth) is never noted.
  slp="$(command -v sleep)"; case "$slp" in /*) ;; *) bad "teardown drive: no sleep binary on PATH for the poll shim"; return 1 ;; esac
  { printf '#!/usr/bin/env bash\nS=%s\n' "$slp"
    cat <<'SH'
note() { [ -p "$TD_DIR/evlog" ] && printf '%s %s %s\n' "$1" "$PPID" "$$" 1<> "$TD_DIR/evlog"; return 0; }
case "${AI_DLC_FX_OUT:-}:$*" in
  ?*:1) ;;
  ?*:*) case "${TMPDIR:-}" in "$AI_DLC_FX_OUT"/.t.*) ;; *) note fallback-poll ;; esac; exec "$S" "$@" ;;
  *) exec "$S" "$@" ;;
esac
f="$TD_DIR/ev.$PPID"; L="$TD_DIR/life"
if [ ! -p "$f" ]; then
  mkfifo "$f" && exec 3<> "$f" || { note fallback-fifo; exec "$S" "$@"; }
  while read -r l <&3; do [ "$l" = go ] && exit 0; [ -p "$f" ] && [ -d "$TD_DIR" ] || exit 0; done
  exit 0
fi
[ -f "$L" ] || { note fallback-life; exec "$S" "$@"; }
[ -p "$TD_DIR/gone" ] && exec 8<> "$TD_DIR/gone"
: > "$TD_DIR/frozen.$PPID"
note frozen
exec perl -e 'use Fcntl ":flock"; my ($l, $w, $t) = @ARGV;
  open(my $f, "<", $l) or exit 3; flock($f, LOCK_SH) or exit 4;
  if (open(my $o, ">", $t)) { close $o }
  my $q = getppid(); kill("KILL", $q) if $q > 1 && $q == $w; exit 0' "$L" "$PPID" "$TD_DIR/thawed.$$"
SH
  } > "$1/shim/sleep" && chmod +x "$1/shim/sleep" || { bad "teardown drive: could not write the sleep shim"; return 1; }
}
# ts_hold <drive dir> -> THE LIFELINE: opens <dir>/s/life on fd 9 and takes LOCK_EX on that open file description
# through one perl child, the only launch that keeps fd 9; the lock lasts while any process holds the description
ts_hold() {
  : > "$1/s/life" && exec 9< "$1/s/life" || return 1
  perl -e 'use Fcntl ":flock"; open(my $f, "<&=", 9) or exit 3; flock($f, LOCK_EX | LOCK_NB) or exit 4; exit 0'
}
# ts_launch <drive dir> <block> -> the sandboxed run_fixtures launch, its pid in p. It CLOSES fd 9, the lifeline,
# so nothing under the subject can hold the lifeline lock after the drive has gone (td-life-fd).
ts_launch() {
  set -m
  ( cd "$1/w" && unset PREPUSH_POOL_DEPTH && export PATH="$1/shim:$PATH" TD_SLP="$slp" AI_DLC_FIXTURE_JOBS=2 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 TD_DIR="$1/s" \
    && exec sandbox-exec -p '(version 1)(allow default)' /bin/bash -c '. "$1" > /dev/null 2>&1; run_fixtures > "$2" 2>&1; r=$?; [ -p "$TD_DIR/evlog" ] && printf "subject-exit %s\n" "$r" 1<> "$TD_DIR/evlog"; exit "$r"' _ "$2" "$1/out" ) > /dev/null 2>&1 9>&- &
  p=$!
  set +m
}
# ts_drive <block> <set> -> appends the sandboxed TERM drive's cells to $WORK/td.<set>.v
ts_drive() {
  local blk="$1" set="$2" d="$WORK/td.$2.sbx" p n gn on ln st root sp gp mp op q w k xg ep hit mk f
  mkdir -p "$d/s" "$d/shim" && cp -R "$TST" "$d/w" || { bad "teardown drive $set/sbx: could not copy the template"; return 1; }
  ts_shims "$d" || return 1
  # THE LIFELINE: this drive holds the lock on fd 9 until its cells are read, and every launch below closes it
  ts_hold "$d" || { bad "teardown drive $set/sbx: could not take the lifeline lock"; return 1; }
  ts_launch "$d" "$blk"
  td_wait2 "$d/s"
  sp="$(td_stubs "$d/s")"; gp="$(cat "$d/s"/g.* 2>/dev/null | tr '\n' ' ')"; mp="$(cat "$d/s"/m.* 2>/dev/null | tr '\n' ' ')"
  op=""; for f in "$d/s"/o.*; do case "$f" in *.go) ;; *) [ -s "$f" ] && op="$op $(cat "$f")" ;; esac; done
  root="$(sed -n '1s/^[0-9]* //p' "$d/s/$(ls "$d/s" | grep '^s\.' | sed -n 1p)")"
  # what each stub read in `.g` after its frozen poll: printed beside td_sbx_lead when the block under test did not
  # remember both orphans, so a red td_sbx_lead names its cause (the cell itself is the verdict)
  q="$(cat "$d/s"/r.* 2>/dev/null | grep -c '^remembered$')" || q=0
  [ "$q" = 2 ] || [ "$blk" != "$PB" ] || printf '  note  sandboxed teardown drive: %s of 2 stubs read their orphan'"'"'s group in .g after a frozen poll\n' "$q"
  # the readers' precondition: every recorded stub, grandchild and orphaned leader leads its own group and is listed
  # now, each unit-group orphan is listed in its stub's group, and every orphan has been reparented to pid 1
  q="$(ts_alive $sp $gp $op):$(td_orph "$sp" "$mp"):$(td_inl "$(pgrep -P 1 2>/dev/null)" $mp $op)"
  [ "$q" = 6:2:4 ] || { [ "$blk" = "$PB" ] && broken "sandboxed teardown drive: read [$q] before the TERM, want [6:2:4] (leaders alive : unit-group orphans in their stubs' groups : orphans under pid 1)"; }
  # the SENTINEL: a RECORDED process in xargs' group (joined through a recorded worker's group) that blocks TERM, so a
  # TERM sent to it stays pending; told to report, it answers whether one is. The END RECORD: a drive-owned process
  # outside xargs' group, recorded last in glob order, so neither the fix nor a group-checking pool_stop TERMs it.
  w=""; for k in "$root"/.pr/q*.k; do [ -s "$k" ] && { read -r w < "$k"; break; }; done
  xg=""; case "$w" in ''|*[!0-9]*) ;; *) xg="$(perl -e 'print getpgrp($ARGV[0])' "$w")" ;; esac
  perl -MPOSIX -e '
    my ($pg, $dir, $rec) = @ARGV; pipe(my $r, my $w) or exit 3; my $c = fork(); defined $c or exit 3;
    if ($c == 0) {
      close $r; my $g = fork(); defined $g or POSIX::_exit(3); POSIX::_exit(0) if $g;
      sigprocmask(SIG_BLOCK, POSIX::SigSet->new(SIGTERM, SIGINT, SIGHUP)) or POSIX::_exit(4);
      setpgid(0, $pg) or POSIX::_exit(5);
      open(my $f, ">", "$rec.t") or POSIX::_exit(6); print $f "$$ ", getpgrp(0), "\n"; close $f; rename("$rec.t", $rec) or POSIX::_exit(6);
      syswrite($w, "r"); close $w; my $hit = "";
      until ($hit ne "" || ! -d $dir) {
        my $p = POSIX::SigSet->new; sigpending($p);
        if ($p->ismember(SIGTERM)) { $hit = "signalled" }
        elsif (-e "$dir/report") { sigpending($p); $hit = $p->ismember(SIGTERM) ? "signalled" : "unsignalled" }
        else { select(undef, undef, undef, 0.1) }
      }
      if (open($f, ">", "$rec.r.t")) { print $f "$hit\n"; close $f; rename("$rec.r.t", "$rec.r") }
      until (-e "$dir/release" || ! -d $dir) { select(undef, undef, undef, 0.1) }
      POSIX::_exit(0);
    }
    close $w; waitpid($c, 0); my $b = ""; sysread($r, $b, 1); exit($b eq "r" ? 0 : 7);' "${xg:-0}" "$d/s" "$d/s/sent" > /dev/null 2>&1 9>&-
  q="$?:$(sed -n '1s/^[0-9]* //p' "$d/s/sent" 2>/dev/null)"
  [ "$q" = "0:$xg" ] || { [ "$blk" = "$PB" ] && broken "sandboxed teardown drive: the sentinel did not join xargs' group [$xg] (read [$q])"; }
  [ -s "$d/s/sent" ] && read -r k _ < "$d/s/sent" && printf '%s\n' "$k" > "$root/.pr/zy-sent.k"
  ( while [ ! -e "$d/s/release" ] && [ -d "$d/s" ]; do sleep 0.1; done ) > /dev/null 2>&1 9>&- &
  ep=$!; printf '%s\n' "$ep" > "$d/s/end.pid"; printf '%s\n' "$ep" > "$root/.pr/zz-end.k"
  kill -TERM "$p"
  # until the parent is gone, a third stub (a queued unit) has started, or the END RECORD was tested with ps, which a
  # pool_stop does only after it has decided every earlier record, the sentinel's included; no clock decides it
  while kill -0 "$p" 2>/dev/null && [ "$(ls "$d/s" | grep -c '^s\.')" -le 2 ] && [ ! -e "$d/s/end.seen" ]; do sleep 0.1; done
  n="$(ts_alive $sp)"; gn="$(ts_alive $gp)"; on="$(td_orph "$sp" "$mp")"; ln="$(ts_alive $op)"
  : > "$d/s/report"
  while [ ! -s "$d/s/sent.r" ]; do sleep 0.1; done
  read -r hit < "$d/s/sent.r"
  if [ -e "$d/s/end.seen" ]; then mk=mark; else mk=nomark; fi
  : > "$d/s/release"; wait "$p"; st=$?; wait "$ep"
  # the fallback: closing the lifeline releases its lock, so a frozen shim its watcher's group KILL missed takes its
  # shared lock and exits; a first-poll shim still waiting for `go` is woken by a line and reads its fifo gone
  exec 9>&-
  for f in "$d/s"/ev.*; do [ -p "$f" ] || continue; exec 8<> "$f"; rm -f "$f"; printf 'end\n' >&8; exec 8>&-; done
  if [ -d "$root" ]; then root=present; else root=gone; fi
  printf 'td_sbx_stub=%s\ntd_sbx_gc=%s\ntd_sbx_orph=%s\ntd_sbx_lead=%s\ntd_sbx_sent=%s:%s\ntd_sbx_rc=%s:%s:%s\n' "$n" "$gn" "$on" "$ln" "$hit" "$mk" "$st" "$root" "$(ls "$d/s" | grep -c '^s\.')" >> "$WORK/td.$set.v"
}
tl_held() { # tl_held <file> -> held | free | noopen: one non-blocking shared-lock attempt; no clock decides it
  perl -e 'use Fcntl ":flock"; open(my $f, "<", $ARGV[0]) or do { print "noopen"; exit 0 }; print(flock($f, LOCK_SH | LOCK_NB) ? "free" : "held")' "$1"
}
# tl_drive <block> <set> -> appends the drive-death cells to $WORK/td.<set>.v
tl_drive() {
  local blk="$1" set="$2" d="$WORK/td.$2.life" sd p="" a b c n=0 fz="" sh="" fb="" l al wr res
  mkdir -p "$d/s" "$d/shim" && cp -R "$TST" "$d/w" || { bad "drive-death drive $set: could not copy the template"; return 1; }
  ts_shims "$d" || return 1
  mkfifo "$d/s/evlog" "$d/s/hold" "$d/s/done" "$d/s/gone" || { bad "drive-death drive $set: could not make its fifos"; return 1; }
  # evlog carries the events (held read-write here, so a line outlives its writer); done reads EOF once the
  # SUB-DRIVE and every process of the subject have exited: they hold its write end, and this drive only a read end.
  # hold: THIS DRIVE IS ITS ONLY WRITER (fd 3, opened read-write so the open cannot block on a missing reader).
  exec 7<> "$d/s/evlog" 5<> "$d/s/done" 6< "$d/s/done" 3<> "$d/s/hold"
  # THE SUB-DRIVE: ts_drive's lifeline and launch, and nothing else. Told `probe` on hold, it answers `marker`. It
  # opens hold READ-ONLY while its inherited fd 3 still makes a writer exist (so the open cannot block, whenever this
  # drive dies), then closes fd 3 before anything is launched: no process but this drive holds a write end, so when
  # this drive dies by any means (a ^C, a KILL of the fixture pid alone) the sub-drive's read sees EOF, it exits, and
  # the lifeline lock is released. The read end its launches inherit is never read and cannot delay that EOF.
  set -m
  ( exec 4< "$d/s/hold" 3>&- 6<&- 7<&-
    ts_hold "$d" || { printf 'failed\n' 1<> "$d/s/evlog"; exit 3; }
    ts_launch "$d" "$blk"
    printf 'launched %s\n' "$p" 1<> "$d/s/evlog"
    while read -r l <&4; do printf 'marker %s\n' "$l" 1<> "$d/s/evlog"; done ) > /dev/null 2>&1 &
  sd=$!
  set +m
  exec 5>&-
  # until the launch is recorded and both watchers' SECOND sleeps are frozen on the lifeline. A sub-drive that could
  # not open the lifeline (`failed`) ends the wait at once; a watcher's poll that fell back to the real sleep
  # (`fallback-poll`, `fallback-fifo`, `fallback-life`: the shim notes each before it execs) ends it once the launch
  # is recorded, so the subject's parent is known to the teardown. THE SUBJECT'S EXIT IS AN EVENT TOO: ts_launch's
  # sandboxed bash writes `subject-exit <rc>` once run_fixtures returns, so a block that fails before its pool starts
  # ends the wait (the `*)` arm) and reads nofreeze:subject-exit:<n>. evlog is held read-write by this shell, so its
  # read never fails, and without that line the loop blocked for good. The fix block's subject cannot return before
  # both freezes: its units hold until the release, which comes after the teardown's TERM below.
  while [ -z "$p" ] || { [ "$n" -lt 2 ] && [ -z "$fb" ]; }; do
    read -r a b c <&7 || break
    case "$a" in
      launched) p="$b" ;;
      frozen) n=$((n + 1)); fz="$fz $b"; sh="$sh $c" ;;
      fallback-*) fb="${fb:-$a}" ;;
      *) break ;;
    esac
  done
  if [ -n "$p" ] && [ "$n" = 2 ] && [ -z "$fb" ]; then
    # THE CONTROL, the drive alive: it answers a probe, and then both shims are still in their watchers' groups
    printf 'probe\n' >&3
    # the reply is MATCHED: the loop reads past any line other than the sub-drive's `marker` reply, and it cannot spin, because a read on fd 7 blocks rather than fails
    while read -r a b <&7 && [ "$a" != marker ]; do :; done
    l=""; for c in $fz; do l="$l"$'\n'"$(pgrep -g "$c" 2>/dev/null)"; done
    al="$a:$(td_inl "$l" $sh):$(tl_held "$d/s/life")"
  else
    al="nofreeze:${fb:-$a}:$n"; n=0
  fi
  # THE SUB-DRIVE DIES, by its recorded pid; once reaped none of its descriptors is open
  kill -KILL "$sd"; wait "$sd" 2>/dev/null
  wr="$(tl_held "$d/s/life")"
  if [ "$n" != 2 ]; then res=nofreeze
  elif [ "$wr" = free ]; then
    # the lock is released, so each frozen shim takes its shared lock and exits; gone reads EOF once both have exited
    exec 4<> "$d/s/gone" 8< "$d/s/gone" 4>&-
    read -r _ <&8; exec 8<&-
    res="exited:$(ls "$d/s" | grep -c '^thawed\.')"
  else
    res="leaked:$wr"
  fi
  # teardown: TERM the subject's parent (alive: its units hold until the release) and wait until it is gone, as
  # ts_drive does, so no unit can end normally and let xargs start the queued one before pool_stop writes `.stop`;
  # pool_stop's TERM and KILLs end the units without the release. Then release; done reads EOF once all of the
  # subject is gone. p is not this shell's child, so the wait is a kill -0 loop, ended by the parent's exit alone.
  case "$p" in ''|*[!0-9]*) ;; *) kill -TERM "$p"; while kill -0 "$p" 2>/dev/null; do sleep 0.1; done ;; esac
  : > "$d/s/release"
  read -r _ <&6
  exec 3>&- 6<&- 7<&-
  printf 'td_life_alive=%s\ntd_life=%s\n' "$al" "$res" >> "$WORK/td.$set.v"
}
td_run() { # td_run <block> <set> <cell...>: one drive per mode its cells need
  local blk="$1" set="$2" c tm=0 im=0 sm=0 lm=0; shift 2
  : > "$WORK/td.$set.v"
  for c in "$@"; do case "$c" in td_intp) im=1 ;; td_sbx_*) sm=1 ;; td_life*) lm=1 ;; *) tm=1 ;; esac; done
  [ "$tm" = 1 ] && td_drive "$blk" "$set" term
  [ "$im" = 1 ] && td_drive "$blk" "$set" int
  [ "$sm" = 1 ] && ts_drive "$blk" "$set"
  [ "$lm" = 1 ] && tl_drive "$blk" "$set"
  return 0
}
td_val() { sed -n "s/^$2=//p" "$WORK/td.$1.v" 2>/dev/null; }
wanttd() { printf '%s\n' "$WANT_TD" | sed -n "s/^$1=//p"; }
td_run "$PB" fix $TD_ALL $TS_ALL $TL_ALL
for _c in $TD_ALL $TS_ALL $TL_ALL; do
  v="$(td_val fix "$_c")"
  if [ "$v" = "$(wanttd "$_c")" ]; then ok "[$T] teardown $_c=$v"
  else bad "[$T] teardown $_c read [${v:-none}], want [$(wanttd "$_c")]"; fi
done
# td_mut <name> <sed-expr>: a copy of the block, one edit, exactly one line changed
td_eval() {
  local name="$1" m="$WORK/td.mut.$1.sh" dec tw cells c got="" moved bm cond=0 n_run fam="$TD_ALL"
  dec="$(mrow "$name" decides)"; tw="$(mrow "$name" twins)"
  [ -n "$dec" ] || { bad "MUTANT $name: no MUTANT-MATRIX row in the header"; return 0; }
  dec="${dec//,/ }"; tw="${tw//,/ }"
  sed "$2" "$PB" > "$m" || { bad "MUTANT $name: sed did not apply"; return 0; }
  if cmp -s "$PB" "$m"; then bad "MUTANT $name: the edit matched nothing, so it is not a mutant"; return 0; fi
  # the edit removed or changed exactly one line of the block (a multiset count, so a duplicate line elsewhere still counts)
  [ "$(awk 'NR == FNR { c[$0]++; next } { c[$0]-- } END { for (k in c) if (c[k] > 0) n += c[k]; print n + 0 }' "$PB" "$m")" -eq 1 ] \
    || { bad "MUTANT $name: the edit did not change exactly one line"; return 0; }
  # a mutant whose decides are sandboxed cells has the sandboxed drive as its family; every other td mutant has the plain drives
  case " $dec " in *" td_sbx_"*) fam="$TS_ALL" ;; esac
  if [ "$MATRIX" = 1 ]; then cells="$fam"; n_run="$(printf '%s\n' $dec $tw | grep -c .)"; MX_RAN=$((MX_RAN + $(printf '%s\n' $fam | grep -c .) - n_run)); else cells="$dec $tw"; fi
  ( td_run "$m" "$name" $cells )
  for c in $cells; do got="$got$c=$(td_val "$name" "$c")"$'\n'; done
  # the base-pass flag is COMPUTED in this run: 1 only when every decides and twin cell read its want on the unmutated block
  bm="$(for c in $dec $tw; do [ "$(td_val fix "$c")" = "$(wanttd "$c")" ] || { echo 0; exit 0; }; done; echo 1)"
  moved="$(moved_of "$got" "$WANT_TD")"
  [ "$MATRIX" = 1 ] && mx_row "$name" "$cells" "$moved"
  same_set "$moved" "$dec" && cond=1
  finish_mutant "$([ "$bm" = 1 ] && echo 1 || echo 0)" "$name" "$cond" \
    "MUTANT $name kill confirmed: decides [$dec] moved, twin [${tw:--}] stayed green" \
    "MUTANT $name moved [${moved% }], want [$dec] (twin [${tw:--}])"
}
td_eval td-old-traps "s/trap 'pool_stop 130' INT; trap 'pool_stop 143' TERM; trap 'pool_stop 129' HUP$/trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP/"
td_eval td-no-stop '/^    \[ -f "\$AI_DLC_FX_OUT\/.pr\/.stop" \] && { : > "\$pr.k"; exit 255; }$/d'
# the group guard removed: pool_stop TERMs every recorded pid, the planted stale record included
TS_CASE='^      case .*"\$pg".*) \(kill -TERM "\$p" 2>\/dev\/null\) ;; esac$'
td_eval td-no-pgid "s/$TS_CASE/      \\1/"
# the ps group test restored (BL-881): with ps failing it is always false and no worker is TERMed; the drive
# reads its cells on the END RECORD's ps mark, which this pool_stop makes after deciding every earlier record
td_eval td-ps-pgid "s/$TS_CASE/      [ \"\$(ps -o pgid= -p \"\$p\" 2>\\/dev\\/null | tr -d ' ')\" = \"\$pool_xp\" ] \\&\\& \\1/"
# pool_kill's ps-free walk removed: with ps failing it kills only the unit pid and the unit's own group
td_eval td-no-tree 's/^      \[ -n "\$2" \] || { pool_kill_tree "\$1" "\$3" "\$4"; return 0; }$/      [ -n "$2" ] || { kill -KILL -- "-$1"; kill -KILL "$1"; return 0; }/'
# pool_kill_tree's per-pid group KILL removed: a unit-group orphan (ppid 1) is reached by nothing else
td_eval td-no-pidgrp '/^      for p in \$l; do kill -KILL -- "-\$p"; done$/d'
# the remembered-group KILL removed: an orphaned group leader the watcher remembered is reached by nothing else
td_eval td-no-memgrp '/^      for g in \$3; do case " \$l " in/d'
# the ps-free memory removed (the 8713fbf6f shape): the watcher never writes the orphaned leader's group to `.g`, so
# the stub reads `unremembered` after its frozen poll and the leader survives; it must be KILLED, never hang
td_eval td-no-mem '/^          \[ -n "\$self" \] || { pool_mem "\$pid"/d'
# the lifeline's closure on the subject launch dropped: the mutant is ts_launch's own text, re-defined in a subshell
# with its one `9>&-` removed, so every process of the subject inherits fd 9's open file description and the EX
# lock stays held after the drive dies; td_life reads leaked:held by one non-blocking lock attempt, so no wait can hang
tl_m="$(declare -f ts_launch)"
if [ "$(printf '%s\n' "$tl_m" | grep -c ' 9>&- &')" != 1 ]; then bad "MUTANT td-life-fd: ts_launch carries no single ' 9>&- &', so it is not a mutant"
else
  ( eval "$(printf '%s\n' "$tl_m" | sed 's/ 9>&- &/ \&/')"; td_run "$PB" td-life-fd $TL_ALL )
  tl_got=""; for _c in $TL_ALL; do tl_got="$tl_got$_c=$(td_val td-life-fd "$_c")"$'\n'; done
  tl_bm="$(for _c in $TL_ALL; do [ "$(td_val fix "$_c")" = "$(wanttd "$_c")" ] || { echo 0; exit 0; }; done; echo 1)"
  tl_moved="$(moved_of "$tl_got" "$WANT_TD")"
  [ "$MATRIX" = 1 ] && mx_row td-life-fd "$TL_ALL" "$tl_moved"
  tl_cond=0; same_set "$tl_moved" "$(mrow td-life-fd decides)" && tl_cond=1
  finish_mutant "$([ "$tl_bm" = 1 ] && echo 1 || echo 0)" td-life-fd "$tl_cond" \
    "MUTANT td-life-fd kill confirmed: decides [td_life] moved ($(td_val td-life-fd td_life)), twin [td_life_alive] stayed green" \
    "MUTANT td-life-fd moved [${tl_moved% }], want [td_life] (read ${tl_got//$'\n'/ })"
fi

# ------------------------------------------------- pool_stop waits for xargs ONCE (BL-881) ---------
# pool_stop has set INT/TERM/HUP to '' before it waits, so a status above 128 can only mean xargs itself died
# by a signal, and bash 3.2 answers a second wait on that reaped pid with the SAME status, never 127. A
# re-wait loop keyed on "> 128" therefore spins forever with nothing able to stop it. The block's own
# pool_stop text is driven in a subshell whose pool_xp is a child that dies by a signal or by an exit; the
# subshell shadows `wait` with a counter: the FIRST call runs builtin wait, the SECOND exits the subshell with
# PS_SENTINEL, so the verdict is the exit status and no clock decides it. The drive ends on its own exit and
# nothing bounds the wait (BL-868): the fix exits 130 after one wait, a re-wait exits PS_SENTINEL on the second.
#   ps_sig  -- pool_xp died by SIGKILL (the defect needs only a death by signal; KILL because a fixture can be
#              launched with SIGPIPE or TERM ignored, and a bash child sending itself an ignored signal
#              lives on and exits 0, measured on bash 3.2): "exited:<rc>" or
#              "spun" (a second wait; want exited:130)
#   ps_exit -- pool_xp exited 1, the twin: a re-wait loop ends here too (want exited:130)
PS_SENTINEL=97
[ "$PS_SENTINEL" != 130 ] || { echo "FIXTURE BROKEN: PS_SENTINEL equals pool_stop's exit status"; exit 2; }
ps_drive() { # ps_drive <block> <sig|exit> -> exited:<rc> | spun | nofn
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
  wait "$p"; s=$?
  if [ "$s" = "$PS_SENTINEL" ]; then printf 'spun'; else printf 'exited:%s' "$s"; fi
}
PS_WANT=exited:130
# the children are `bash`, never `sh`: tools.decl does not declare sh, so under the hermetic sandbox an
# `exec sh` exits 127 and the signal world silently becomes a second exit world
ps_fix_sig="$(ps_drive "$PB" sig)"; ps_fix_exit="$(ps_drive "$PB" exit)"
for _c in sig exit; do
  eval "v=\$ps_fix_$_c"
  if [ "$v" = "$PS_WANT" ]; then ok "[$T] pool_stop ps_$_c=$v"
  else bad "[$T] pool_stop ps_$_c read [$v], want [$PS_WANT]"; fi
done
B_ps="$([ "$ps_fix_sig" = "$PS_WANT" ] && [ "$ps_fix_exit" = "$PS_WANT" ] && echo 1 || echo 0)"
PS_M="$WORK/ps.mut.sh"
sed 's/^    wait "\$pool_xp"$/    while :; do wait "$pool_xp"; [ "$?" -gt 128 ] || break; done/' "$PB" > "$PS_M"
if cmp -s "$PB" "$PS_M"; then bad "MUTANT ps-rewait: the edit matched nothing, so it is not a mutant"
else
  ps_m_sig="$(ps_drive "$PS_M" sig)"; ps_m_exit="$(ps_drive "$PS_M" exit)"
  ps_moved=""
  [ "$ps_m_sig" = "$PS_WANT" ] || ps_moved="${ps_moved}ps_sig "
  [ "$ps_m_exit" = "$PS_WANT" ] || ps_moved="${ps_moved}ps_exit "
  [ "$MATRIX" = 1 ] && mx_row ps-rewait "ps_sig ps_exit" "$ps_moved"
  ps_cond=0; same_set "$ps_moved" "$(mrow ps-rewait decides)" && ps_cond=1
  finish_mutant "$([ "$B_ps" = 1 ] && echo 1 || echo 0)" ps-rewait "$ps_cond" \
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
