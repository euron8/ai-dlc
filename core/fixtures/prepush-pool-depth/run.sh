#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# The consumer-layout section (BL-1027) also extracts SUITE_STEP from .githooks/pre-push and drives fixture_suite_step.
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
# MUTANT-MATRIX cl-dist-keyed decides=cl_nl,cl_ni,cl_tp twins=cl_iv
# MUTANT-MATRIX cl-select-all decides=cl_ii,cl_nl,cl_ni,cl_tp twins=cl_i
# MUTANT-MATRIX cl-stamp-raw decides=cl_ii,cl_nl,cl_ni twins=cl_tp
# MUTANT-MATRIX cl-no-refusal decides=cl_ref,cl_fb5_sel twins=cl_fb5_state
# MUTANT-MATRIX cl-store-dist-project decides=cl_cstore twins=cl_v,cl_v_ctl
# MUTANT-MATRIX cl-publish-late decides=cl_resume,cl_census twins=cl_entry
# MUTANT-MATRIX cl-publish-worker decides=cl_nl twins=cl_iv
# MUTANT-MATRIX cl-record-on-red decides=cl_census,cl_i,cl_vii,cl_v twins=cl_ii
# MUTANT-MATRIX cl-depth1-honoured decides=cl_fb2 twins=cl_fb2_ran
# MUTANT-MATRIX cl-switch-on decides=cl_vi_out,cl_vi_list twins=cl_entry_ran
# MUTANT-MATRIX cl-no-entry decides=cl_entry twins=cl_iii
# MUTANT-MATRIX cl-fail-open decides=cl_inst_rc twins=cl_inst_arg
# MUTANT-MATRIX cl-no-arg decides=cl_inst_arg twins=cl_inst_rc
# MUTANT-MATRIX-DYNAMIC finish_mutant why=the one emission site passes the mutant name as a variable; each of the thirty-nine literal callers (mutant, pn_eval, td_eval, the I66 arm, the pool_stop arm, the td-life-fd lifeline arm and cl_mutant) has its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/prepush-pool-depth/run.sh --matrix
#
# The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run per distinct state")
# requires. Run the command above, from the repository root; its log names every mutant's dead cells.
# Each mutant co-trips no other arm
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
# NO WALL CLOCK, NO ps SAMPLE AND NO COUNT OF POLLS DECIDES OR BOUNDS ANYTHING HERE (BL-868, BL-985). Every cell is
# read at a state its subjects WRITE: a pool's width at the barrier rendezvous (pd_rendezvous: the flight files the
# workers wrote reaching the width xargs was GIVEN, read off its own argv), a watcher verdict at its verdict file, and
# a watcher hung on a FIFO at the event its FIFO's writer emits when the watcher opens it (pn_settle, which blocks on
# the drives' events and never samples a process table). A `sleep 0.1` left in this file only PACES a wait for such a
# state and carries no count. The ps-table settle this replaced bounded its waits by 200 rejected settles of one
# table, a bound a deadlock reached and a slow box could too (BL-985).
# NO PARTY OF A LOCKSTEP BLOCKS IN open() ON A FIFO. bash 3.2 does not retry an open that a signal interrupts: a
# SIGCHLD landing while it is blocked opening a FIFO fails the redirection ("Interrupted system call"), the token is
# never written or read, and the two parties then block opening different FIFOs for good -- measured, and forced by
# one `kill -CHLD` (BL-985). So every lockstep FIFO is held open read-write by its drive for the drive's life: a write
# lands in the buffer at once, a read blocks only in read(), which bash retries, and no token can be lost. A FIFO whose
# open IS the event (the HOLD gate, the fifo witness) retries its open until it succeeds.
# The watcher section's window. PN_STALL is the pool's own AI_DLC_POOL_STALL knob (still polls before a
# refusal; the block reads it from the environment, so lowering it edits no hook). The watcher's `sleep 1`
# is a gated stub there (pn.gbin/sleep), so ONE POLL IS ONE STEP OF THE UNIT, never one second: the unit
# writes step i, the watcher measures poll i, and only then does the unit write step i+1. PN_STEPS is how
# many steps a unit takes before it exits, three windows, so a silent unit crosses the refusal threshold (poll
# 1 + PN_STALL) while a growing one does not; a unit that is refused is killed at that poll, before its last step.
PN_STALL=3; PN_STEPS=$((3 * PN_STALL))

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
# STDIN IS /dev/null, WHATEVER THE CALLER GAVE (BL-1050). A `set -m` job inherits this shell's stdin, and bash 3.2
# skips BASH_ENV in a `bash -c` whose stdin is a socket and whose env SHLVL is 0 (its rshd/sshd startup branch, and
# a subshell's exec lowers SHLVL). The top-level teardown launches (td_drive, ts_launch) are such starts, so a caller
# handing this fixture a socket left them, and their workers' attribution, out of the invocation counter's log.
exec < /dev/null
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
trap 'pn_reap_writers; pd_release_all; [ -s "$WORK/barrier.pid" ] && kill "$(cat "$WORK/barrier.pid")" 2>/dev/null; [ -s "$WORK/pn.ticker" ] && kill "$(cat "$WORK/pn.ticker")" 2>/dev/null; rm -rf "$WORK"' EXIT
# pd_release_all: the EXIT trap's release, for a run that ends with a drive still holding (a FIXTURE BROKEN, a TERM).
# The barrier gate is replaced by a regular file, so every later open of it reads EOF, and killing the poller closes
# the only writer of the FIFO an earlier stub holds open. Each watcher-section FIFO is opened read-write once, which
# wakes a party blocked opening it (the HOLD gate, a fifo .pool-parent); a `q` on each step gate ends its stepper. The
# event FIFO pn.ev has no blocked opener to wake: its writers open it read-write (`1<>`) or write-only (`>`, the
# exported shim and pn_step), and neither blocks, because this shell holds it open read-write on fd 4. A normal
# run reaches this with every drive already reaped, so it finds nothing to release.
pd_release_all() {
  local g
  [ -n "${WORK:-}" ] && [ -d "$WORK" ] || return 0
  if [ -p "$WORK/gate" ]; then : > "$WORK/gate.open" && mv -f "$WORK/gate.open" "$WORK/gate"; fi
  for g in "$WORK"/pn.*/gate/stub-a/w "$WORK"/pn.*/gate/stub-b/hold "$WORK"/pn.*/hf/fx.fifo00/.pool-parent "$WORK/pn.ev"; do
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

# pd_gate_sleep: gives a drive's subshell a `sleep` FUNCTION, exported, so every bash the pool starts imports it and
# no process is added. It acts only on a pool WATCHER's `sleep 1` -- the only `sleep 1` with the worker's `$b`
# (its unit's name) in scope -- and passes every other call to the real sleep:
#   PD_GATE (the barrier): while the gate is a FIFO the watcher blocks reading it (the poller holds its write end, so
#     the open never blocks), so a held unit's watcher never polls; once the poller has put a regular file there it
#     sleeps as shipped.
#   PN_GATE (the watcher section): see the lockstep comment there. Its counter is the watcher's own shell variable.
#     The step gate's FIFOs are held open read-write by the drive, so neither the `p` write nor the `w` read can block
#     in open(); the HOLD gate's open IS its event, so an open a signal interrupts is retried until it succeeds.
pd_gate_sleep() {
  sleep() {
    local pn_g pn_t
    if [ "${1:-}" = 1 ] && [ -n "${b:-}" ] && [ -n "${wr:-}" ] && [ -n "${pr:-}" ]; then
      if [ -n "${PD_GATE:-}" ] && [ -p "$PD_GATE" ]; then read -r pn_t < "$PD_GATE"; return 0; fi
      if [ -n "${PN_GATE:-}" ] && [ -d "$PN_GATE/$b" ]; then
        pn_g="$PN_GATE/$b"
        if [ -p "$pn_g/hold" ]; then
          pn_o=0
          while [ "$pn_o" = 0 ] && [ -p "$pn_g/hold" ]; do { pn_o=1; read -r pn_t <&3; } 3< "$pn_g/hold" 2> /dev/null; done
          while kill -0 "$$" 2>/dev/null; do command sleep 1; done
          return 0
        fi
        pn_k=$(( ${pn_k:-0} + 1 ))
        # `>` everywhere here, never `1<>`: bash 3.2 re-prints an exported function's `1<>` as `0<>`, which would send
        # the token to /dev/null (BL-985). The drive holds p open read-write, so this write-only open finds a reader and
        # never blocks. Each operation is RECORDED (see the wait-for records at pn_settle); an ENTER also wakes pn_settle.
        if [ "$pn_k" -gt 1 ]; then
          { printf 'watcher enter write p %s\n' "$pn_k" >> "$PN_REC"; printf 'rec %s\n' "$PN_TAG" > "$PN_EV"; } 2> /dev/null
          printf 'p\n' > "$pn_g/p"; pn_c=$?
          printf 'watcher leave write p %s %s\n' "$pn_k" "$pn_c" >> "$PN_REC" 2> /dev/null
        fi
        { printf 'watcher enter read w %s\n' "$pn_k" >> "$PN_REC"; printf 'rec %s\n' "$PN_TAG" > "$PN_EV"; } 2> /dev/null
        read -r pn_t < "$pn_g/w"; pn_c=$?
        printf 'watcher leave read w %s %s\n' "$pn_k" "$pn_c" >> "$PN_REC" 2> /dev/null
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

# pd_rendezvous -> writes the barrier count to $WORK/barrier.n.
# THE RENDEZVOUS IS THE WIDTH xargs WAS GIVEN. The PATH shim pd_xshim records the value after `-P` on the pool's own
# xargs command line, an immutable value the subject wrote, before it execs the real xargs; the rendezvous is the
# flight files (each written by a worker's stub, which then blocks on the gate) reaching min(that width, 6), `-P 0`
# (BSD: unlimited) read as 6. xargs never runs more than its width at once and every stub it forks writes its flight
# file and holds, so at that count no further stub can start and none is on its way. The wait is a `sleep 0.1` PACING
# a subject-written state, with no count and no bound: a slow box only delays it. While the width is known and the
# count short, a look appends one line to barrier.rej only when the count CHANGED (a record of the look, never a
# decider; a stuck barrier writes nothing, so the outer pool's stall refusal can see it). A drive whose pool
# finished first is read as it stands. NO BOUND AND NO DEADLOCK VERDICT ARE OWED HERE, BY A DESIGN ARGUMENT (F-B4):
# every hook mutant that narrows the pool does so through `-P`, which moves the width read here with it, and a pool
# narrower than its own argv is real xargs failing its contract, which no subject here can construct. A cycle verdict
# keyed on records would be UNSOUND: the fork xargs is about to make is recorded nowhere (a worker's `.pr/<unit>.k`
# lands only after it starts), so "every dispatched worker holds at the gate, short of the width" is the ordinary
# state between two of xargs' forks, and a loaded box would read it as a deadlock. KNOWN ROUTE, NOT BOUNDED IN-FIXTURE:
# a barrier that never reaches its width (only real xargs breaking -P can do that) holds its drive and this fixture;
# what bounds it is the outer pool's stall refusal, which can fire because barrier.rej is written only when the count
# changes, so a stuck barrier writes nothing. The ps-table settle this replaced bounded the wait by 200 rejected settles of
# one unchanged table (BL-985); the settle before that read 5 of 6 when a forked worker had not reached its flight file.
# THE LOOK RECORD barrier.look is OVERWRITTEN IN PLACE (`1<>`, no truncation) on every look with a fixed-width `f=<NN> look=<NNNNNNNNNN>`, so its size
# never changes and the outer stall refusal still sees a stuck barrier; BL-924's receipt reads it to hold a late stub
# across one more look of the poller. The count written to barrier.n is the f the deciding look read (a recount after
# the pool finished first).
pd_rendezvous() {
  local p="" t=6 f lf="" lk=0
  while :; do
    [ -e "$WORK/pool.done" ] && { f="$(ls "$WORK/flight" | wc -l | tr -d ' ')"; break; }
    f="$(ls "$WORK/flight" | wc -l | tr -d ' ')"
    lk=$((lk + 1)); printf 'f=%02d look=%010d\n' "$f" "$lk" 1<> "$WORK/barrier.look"
    [ "$f" -ge 6 ] && break
    if [ -z "$p" ] && [ -s "$WORK/xargs.P" ]; then
      read -r p < "$WORK/xargs.P"
      case "$p" in ''|*[!0-9]*|??????*) t=6 ;; *) t=$((10#$p)); { [ "$t" -eq 0 ] || [ "$t" -gt 6 ]; } && t=6 ;; esac
    fi
    if [ -n "$p" ]; then
      [ "$f" -ge "$t" ] && break
      [ "$f" = "$lf" ] || printf 'P=%s want=%s f=%s\n' "$p" "$t" "$f" >> "$WORK/barrier.rej"; lf="$f"
    fi
    sleep 0.1
  done
  printf '%s\n' "$f" > "$WORK/barrier.n"
}
# pd_xshim: the PATH `xargs` of a barrier drive, a perl script (so it adds no bash start): it writes the argument
# after `-P` to $PD_XARGV atomically, then execs the real xargs in place with its argv unchanged.
PD_XREAL="$(command -v xargs)"; case "$PD_XREAL" in /*) ;; *) broken "no xargs binary on PATH for the barrier shim" ;; esac
mkdir -p "$WORK/xshim" && cat > "$WORK/xshim/xargs" <<'PL' && chmod +x "$WORK/xshim/xargs" || broken "could not write the barrier's xargs shim"
#!/usr/bin/env perl
my ($real, $rec) = ($ENV{PD_XREAL}, $ENV{PD_XARGV});
for my $i (0 .. $#ARGV) {
  next unless $ARGV[$i] =~ /^-P(\d*)$/;
  my $v = length($1) ? $1 : $ARGV[$i + 1];
  if (defined $rec && defined $v && open(my $f, ">", "$rec.t")) { print $f "$v\n"; close $f; rename("$rec.t", $rec) }
  last;
}
exec { $real } "xargs", @ARGV or exit 127;
PL
# drive <block> <world> <depth|-> <jobs|-> -> prints "<rc>" and leaves output in $WORK/last.out
# The block is sourced in a subshell standing in the world; AI_DLC_READSET_LIVE_TRACE=0 keeps the
# launcher out, and the log files are fresh per drive. The marker left in the sourcing shell after the
# pool ran is written to $WORK/leak.v.
#
# PD_BARRIER=1 drives the six stubs through a BARRIER, so a pool's width is a count of stubs IN FLIGHT AT
# ONCE that no scheduling can move. Each stub creates its flight file and then blocks reading the gate
# FIFO $WORK/gate. A poller started beside run_fixtures holds the gate's only write end, and counts the
# flight dir until it reaches the RENDEZVOUS (pd_rendezvous: as many flight files as the width the pool's xargs
# was given, read off its argv by the PATH shim, capped at six), so no further stub can start and none is still on
# its way. Only then does it write the count to $WORK/barrier.n, put a regular file in the gate's place and exit,
# which ends every held read. A pool narrower than six holds 5 or fewer at the rendezvous; a slow box only delays
# the count and never changes it. No clock decides it: a ps-table settle (the form before this) read 5 of 6 when a
# forked worker had not yet reached its flight file and was bounded by a count of settles, the PD_BARRIER_CEIL
# ceiling before it read 5 of 6 on a box loaded past it, and the sleep-overlap read before that read 3 and 5 against
# 6 under load with no hook defect. The poller's pid is recorded in $WORK/barrier.pid for the EXIT trap, whose
# pd_release_all ends any read still held.
drive() {
  local blk="$1" t="$2" depth="$3" jobs="$4" rc
  rm -rf "$WORK/flight"; mkdir -p "$WORK/flight"; : > "$WORK/log"
  rm -f "$WORK/gate" "$WORK/pool.done" "$WORK/barrier.n" "$WORK/barrier.pid" "$WORK/barrier.rej" "$WORK/barrier.look" "$WORK/leak.v" "$WORK/xargs.P"
  rc="$( cd "$t" && {
    [ "$depth" = - ] || export PREPUSH_POOL_DEPTH="$depth"
    [ "$jobs" = - ] || export AI_DLC_FIXTURE_JOBS="$jobs"
    export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PD_LOG="$WORK/log" PD_FLIGHT="$WORK/flight"
    . "$blk" > "$WORK/load.out" 2>&1
    bp=""
    if [ -n "${PD_BARRIER:-}" ]; then
      mkfifo "$WORK/gate" || { echo "nogate" > "$WORK/barrier.n"; echo 1; exit 0; }
      export PD_GATE="$WORK/gate" PATH="$WORK/xshim:$PATH" PD_XREAL PD_XARGV="$WORK/xargs.P"; pd_gate_sleep
      ( exec 9<> "$WORK/gate"
        # the poller pid, as the drive recorded it; its parent is the drive, whose death also ends the poller
        until [ -s "$WORK/barrier.pid" ]; do sleep 0.1; done
        read -r me < "$WORK/barrier.pid"; root="$(ps -o ppid= -p "$me" 2>/dev/null | tr -d ' ')"
        pd_rendezvous
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
    g="$(score "$m" $cells)"
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
#     its worker kills the watcher; a `q` read from p ends the unit (the fixture's release, below). w and p are
#     HELD OPEN READ-WRITE by the drive (fds 5 and 6) for its whole life, so a token write lands in the buffer at
#     once and a party blocks only in read(), waiting for its peer's token: an open a signal interrupted lost the
#     token and deadlocked the pair (BL-985), and a held FIFO has no such open.
#   stub-b (HOLD gate, FIFO hold): the inner watcher's first call blocks until stub B closes hold, so the inner
#     pool's own bookkeeping -- its pid and still-count records, which sit inside the nested root the outer
#     watcher counts -- never moves while it is measured. Stub B opens hold only once its worker's record is
#     written. After stub B is gone the call returns only once its worker is gone too (else the worker kills it).
#     Its open is the rendezvous itself, so it is not held: each side retries an open a signal interrupted.
# No wait has a bound, and none needs one: every lockstep wait is a read of a token its peer always writes.
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
# release the inner watcher's first call only by exiting (see PN_GATE: HOLD). The open is the rendezvous with that
# call, so one a signal interrupts is retried rather than lost.
until [ -s "${TMPDIR%/*}/.pr/stub-b.w" ]; do command sleep 0.1; done
until { exec 9> "$PN_GATE/stub-b/hold"; } 2> /dev/null; do [ -p "$PN_GATE/stub-b/hold" ] || exit 0; done
printf '%s\n' "$TMPDIR" > "$PN_DIR/btmp"
g=""; [ "$PN_MODE" = grow ] && g="$TMPDIR/grow"
. "$PN_DIR/step.sh"
i=0; while [ "$i" -lt "$PN_STEPS" ]; do pn_step "$g"; i=$((i + 1)); done
exit 0
FX
# pn_step <file or empty>: one step of the unit, with no fork: its byte, then the step token, then the poll token.
# The drive holds w and p open read-write, so the token write cannot block and the read blocks only in read().
# Each operation is RECORDED for the wait-for check (pn_settle); an ENTER also wakes pn_settle with one event line.
cat > "$PNT/step.sh" <<'FX'
pn_step() {
  pn_i=$(( ${pn_i:-0} + 1 ))
  [ -z "$1" ] || printf x >> "$1"
  { printf 'unit enter write w %s\n' "$pn_i" >> "$PN_REC"; printf 'rec %s\n' "$PN_TAG" > "$PN_EV"; } 2> /dev/null
  printf 's\n' 1<> "$PN_GATE/stub-a/w"; pn_c=$?
  printf 'unit leave write w %s %s\n' "$pn_i" "$pn_c" >> "$PN_REC" 2> /dev/null
  { printf 'unit enter read p %s\n' "$pn_i" >> "$PN_REC"; printf 'rec %s\n' "$PN_TAG" > "$PN_EV"; } 2> /dev/null
  read -r pn_t < "$PN_GATE/stub-a/p"; pn_c=$?
  printf 'unit leave read p %s %s\n' "$pn_i" "$pn_c" >> "$PN_REC" 2> /dev/null
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
  # reader opens it -- a watcher that reads the FIFO -- and then writes fifo.opened, emits `hung pn.<tag>` on the
  # event FIFO and holds the FIFO open with nothing in it, so that watcher's read never returns. Its open IS the
  # event, so an open a signal interrupted is retried. It is a child of this shell, outside the drive's tree.
  if [ "$mode" = fifo ]; then
    mkdir -p "$d/hf/fx.fifo00" && mkfifo "$d/hf/fx.fifo00/.pool-parent" || { bad "watcher drive $tag: could not build its FIFO"; return 1; }
    ( f="$d/hf/fx.fifo00/.pool-parent"
      until { exec 3> "$f"; } 2> /dev/null; do [ -p "$f" ] || exit 0; done
      : > "$d/fifo.opened"; printf 'hung %s\n' "pn.$tag" 1<> "$WORK/pn.ev"
      exec 8< "$f"; read -r _ <&8 ) > /dev/null 2>&1 &
    printf '%s\n' "$!" >> "$WORK/pn.writers"
  fi
  # THE DRIVE'S EVENT: the OUTER subshell emits `done pn.<tag>` once the inner one has exited by any means, a SIGKILL
  # included (the hook installs and clears its own EXIT trap, so a trap in the drive would not fire). The inner one
  # holds the step gate's two FIFOs open read-write (fds 5 and 6) for the drive's life.
  ( ( cd "$d/a" && export AI_DLC_POOL_STALL="$PN_STALL" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 PN_BLK="$blk" PN_MODE="$mode" PN_DIR="$d" PN_STEPS="$PN_STEPS" PN_GATE="$d/gate" \
        PN_REC="$WORK/pn.$tag.rec" PN_EV="$WORK/pn.ev" PN_TAG="pn.$tag"
      exec 5<> "$d/gate/stub-a/w" 6<> "$d/gate/stub-a/p"
      pd_gate_sleep
      . "$blk" >/dev/null 2>&1; run_fixtures > "$d/out" 2>&1
      if grep -q '^   ok    stub-a$' "$d/out"; then v=ok
      elif grep -q '^   REFUSED  stub-a  ' "$d/out"; then v=REFUSED
      else v=OTHER; fi
      printf '%s\n' "$v" > "$WORK/pn.$tag.v"
      if [ -s "$d/btmp" ]; then
        p="$(cat "$d/btmp")"; p="${p%/*}"
        case "${p##*/}" in fx.??????) [ -d "$p" ] && rm -rf -- "$p" ;; esac
      fi )
    printf 'done %s\n' "pn.$tag" 1<> "$WORK/pn.ev" ) > /dev/null 2>&1 &
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
  ( ( cd "$d/w" && export TMPDIR="$m" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1
      . "$blk" >/dev/null 2>&1; run_fixtures >/dev/null 2>&1
      awk 'NR == FNR { s[$0] = 1; next } !($0 in s) { n++; at = FNR } END { print (n == 1 ? at : "none") }' "$d/seed" "$m/.pool-nested" > "$WORK/ord.$tag.v" )
    printf 'done %s\n' "ord.$tag" 1<> "$WORK/pn.ev" ) > /dev/null 2>&1 &
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
# EVERY DRIVE ENDS ON AN EVENT ITS SUBJECTS EMIT, NEVER ON A DEADLINE, A ps SAMPLE OR A COUNT (BL-868, BL-985).
# pn_settle blocks reading the event FIFO pn.ev, which this shell holds open read-write on fd 4 for the whole watcher
# section (so a line outlives its writer and a read never sees end of file), until every drive is accounted for by
# one of two events: `done <tag>`, which the drive's outer subshell writes once the drive has exited by any means,
# or `hung pn.<tag>`, which the FIFO's writer (pn_drive) writes once a watcher has opened the FIFO and so hangs
# reading it. A hung drive cannot be done first: a hung watcher never polls again, so its unit never ends. pf.<tag>.at
# records `hung`, else the verdict -- the cell pn_fifo reads. A hung drive is then RELEASED: a `q` on its step gate
# ends the unit, its worker kills the watcher, and it writes the verdict it reaches released (the m-nofifoguard
# control: a hung drive was only blocked, and reaches `ok`). Every drive is then reaped by `wait`, and only then are
# the FIFO writers ended.
# A DEADLOCK IS A VERDICT, DECIDED BY A WAIT-FOR CYCLE IN RECORDS THE PARTIES WRITE (F-B5), never by a count or a
# clock. Each lockstep party appends `<party> <enter|leave> <read|write> <fifo> <seq> [rc]` to $WORK/pn.<tag>.rec --
# the unit (pn_step) and the watcher (the PN_GATE shim) -- before and after each FIFO operation. The file sits outside
# every root a watcher counts as progress, so it cannot move a REFUSED cell. Every ENTER also writes `rec <tag>` to
# pn.ev, so pn_settle checks that drive after each state change that can complete a cycle (the last party to block
# writes an ENTER). pn_cycle declares a cycle only when BOTH parties' last records are ENTERs on DIFFERENT FIFOs and,
# on each FIFO, the tokens sent (leave write, rc 0) equal the tokens received (leave read, rc 0): then neither has a
# token on its way, its only peer waits on the other FIFO, and neither can move. A buffered token (sent > received) is
# a transient and is never a cycle. A cycle is FIXTURE BROKEN naming the drive and both records.
# KNOWN ROUTE, NOT DETECTED: a write that returns 0 and puts its token NOWHERE (the `0<>` bash 3.2 re-prints for an
# exported `1<>`, which hung this section silently in BL-985) reads as a buffered token, so it is never a cycle; the
# shim's redirections are held to `>` and `>>` for that reason, as bash re-prints them.
# THE REMAINING WAITS, each with its guaranteed peer, so a drive that is not in a cycle ends:
#   watcher read of w   <- the unit's next step (held FIFO); a unit that exits or is killed: its worker KILLs the watcher
#   unit read of p      <- the watcher's next call (held FIFO), or the fixture's `q`; the watcher always comes back
#                          unless refused (the unit is then killed), killed, or hung on a FIFO .pool-parent (below)
#   stub B's hold open  <- the inner watcher's first call, which follows its start; an interrupted open is retried
#   inner hold read     <- stub B's open, then end of file when stub B exits; then its worker's exit. The retry is
#                          sound for this READER side only. RESIDUAL on the writer side: a signal can fail stub B's open
#                          after the reader's open has returned, so the inner watcher reads end of file at once; it then
#                          waits for its worker's exit and still never polls, so the inner bookkeeping does not move.
#   pn_settle's read    <- every drive's outer subshell (written on any exit of the drive) and the witness's `hung`
#   a watcher's read of a FIFO .pool-parent <- nobody, on purpose: the hang the witness reports and `q` releases
# KNOWN ROUTE, NOT BOUNDED HERE: a SUBJECT (the block or a mutant of it) that blocks forever outside the lockstep hangs
# its drive and so this fixture; nothing in the fixture turns that into FIXTURE BROKEN, and only the runner outside it
# bounds it: the outer pool's stall refusal, which fires because a stuck fixture writes nothing new (below). The witness's own open has no peer by design and is ended by pn_reap_writers. The ps-table settle this
# replaced bounded each drive by 200 rejected settles of one table: a lockstep a signal had deadlocked (an interrupted
# FIFO open, BL-985) reached it as FIXTURE BROKEN, and so could a slow box.
# A TICK, written every 0.1s by a pacer pn_settle starts and stops, wakes it to LOOK at every drive not yet accounted
# for: the same pn_cycle check, then pn.looked's completed-look counter (fixed width, in place: BL-924's receipt bounds
# its watcher forcing on it), and a `<tag> looked: no cycle (...)` line in pn.rej ONLY WHEN that drive's line
# differs from the last one written for it ($WORK/pn.<tag>.look) -- "this drive was looked at in a new state and had
# not reached its event". The tick only wakes: it decides nothing, it is not a bound, nothing counts ticks, and every
# line it writes is decided by the records. A STUCK FIXTURE THEREFORE WRITES NOTHING NEW (no look line repeats, no
# barrier line repeats, pn.tick.due is empty), so the KNOWN ROUTES above -- a subject blocked outside the lockstep, a
# stuck barrier -- are bounded by the outer pool's stall refusal, which counts the bytes under this unit's root.
# pn_cycle <rec file> -> "none" or "CYCLE <unit last> | <watcher last> | sent/received per FIFO"
pn_cycle() {
  [ -s "$1" ] || { printf 'none'; return 0; }
  awk '{ last[$1] = $0; k[$1] = $2; f[$1] = $4
         if ($2 == "leave" && $6 == "0") { if ($3 == "write") sn[$4]++; else rc[$4]++ } }
       END { if (k["unit"] == "enter" && k["watcher"] == "enter" && f["unit"] != f["watcher"] && sn["w"] + 0 == rc["w"] + 0 && sn["p"] + 0 == rc["p"] + 0)
               printf "CYCLE unit [%s] | watcher [%s] | w %d/%d p %d/%d", last["unit"], last["watcher"], sn["w"], rc["w"], sn["p"], rc["p"]
             else printf "none" }' "$1"
}
pn_settle() {
  local e t p2 pend="" hung="" ev tg tk cy ln lp nl=0
  for e in $PN_PIDS; do pend="$pend ${e#*:}"; done
  : > "$WORK/pn.ticking"; rm -f "$WORK/pn.tick.due"
  # AT MOST ONE TICK IN FLIGHT: the pacer writes a tick only while pn.tick.due is absent, creating it first; pn_settle
  # removes it when it handles that tick, so a slow reader never finds a backlog of ticks in the FIFO.
  ( while [ -e "$WORK/pn.ticking" ]; do sleep 0.1; [ -e "$WORK/pn.tick.due" ] && continue; : > "$WORK/pn.tick.due"; printf 'tick -\n' 1<> "$WORK/pn.ev"; done ) > /dev/null 2>&1 &
  tk=$!; printf '%s\n' "$tk" > "$WORK/pn.ticker"
  while [ -n "${pend// /}" ]; do
    read -r ev tg <&4 || broken "watcher section: the event FIFO could not be read, with drives pending:$pend"
    case "$ev" in
      tick)
        rm -f "$WORK/pn.tick.due"
        for t in $pend; do
          cy="$(pn_cycle "$WORK/$t.rec")"
          case "$cy" in CYCLE*) broken "watcher drive $t: DEADLOCK, a wait-for cycle in its lockstep records: ${cy#CYCLE }" ;; esac
          ln="$(printf '%s looked: no cycle (unit [%s] watcher [%s])' "${t#pn.}" "$(grep '^unit ' "$WORK/$t.rec" 2>/dev/null | tail -1)" "$(grep '^watcher ' "$WORK/$t.rec" 2>/dev/null | tail -1)")"
          lp=""; [ -f "$WORK/$t.look" ] && read -r lp < "$WORK/$t.look"
          [ "$ln" = "$lp" ] || { printf '%s\n' "$ln" >> "$WORK/pn.rej"; printf '%s\n' "$ln" > "$WORK/$t.look"; }
        done
        # the COMPLETED-LOOK counter, fixed width and overwritten in place (no growth): written after every pending
        # drive's line, so a reader that sees it advance twice past a moment knows a whole look began after it
        nl=$((nl + 1)); printf 'looks=%010d\n' "$nl" 1<> "$WORK/pn.looked"; continue ;;
      rec)
        case "$pend " in *" $tg "*) ;; *) continue ;; esac
        cy="$(pn_cycle "$WORK/$tg.rec")"
        case "$cy" in CYCLE*) broken "watcher drive $tg: DEADLOCK, a wait-for cycle in its lockstep records: ${cy#CYCLE }" ;; esac
        continue ;;
      done|hung) case "$pend " in *" $tg "*) ;; *) continue ;; esac ;;
      *) continue ;;
    esac
    [ "$ev" = hung ] && hung="$hung $tg"
    p2=""; for t in $pend; do [ "$t" = "$tg" ] || p2="$p2 $t"; done; pend="$p2"
  done
  rm -f "$WORK/pn.ticking"; kill "$tk" 2> /dev/null; wait "$tk" 2> /dev/null; rm -f "$WORK/pn.ticker" "$WORK/pn.tick.due"
  for e in $PN_PIDS; do
    t="${e#*:}"
    case "$t" in
      pn.*) case "$hung " in *" $t "*) echo hung ;; *) cat "$WORK/$t.v" 2>/dev/null ;; esac > "$WORK/pf.${t#pn.}.at" ;;
    esac
  done
  # HUNG: the stepper is blocked reading its poll FIFO (its watcher never came back). The drive holds that FIFO open,
  # so the `q` waits in it until it is read; the stepper exits, its unit ends, and its worker kills the hung watcher.
  for t in $hung; do [ -p "$WORK/$t/gate/stub-a/p" ] && printf 'q\n' 1<> "$WORK/$t/gate/stub-a/p"; done
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
# PN_CYCLE'S SELF-PROBE, before any drive: three seeded record files, each a state its verdict must match. A cycle
# (a lost token: each party entered a write on a different FIFO, nothing in flight) must fire; a buffered token (sent >
# received on w) and both parties on the SAME FIFO must not. A detector that cannot fire, or fires on a transient, is
# reported here rather than read as a clean watcher section.
printf '%s\n' 'watcher enter read w 1' 'unit enter write w 1' 'unit leave write w 1 0' 'unit enter read p 1' 'watcher leave read w 1 0' \
  'unit leave read p 1 1' 'unit enter write w 2' 'watcher enter write p 2' > "$WORK/probe.cycle.rec"
printf '%s\n' 'watcher enter read w 1' 'unit enter write w 1' 'unit leave write w 1 0' 'unit enter read p 1' > "$WORK/probe.buffered.rec"
printf '%s\n' 'watcher enter read w 1' 'unit enter write w 1' > "$WORK/probe.samefifo.rec"
printf '%s\n' 'watcher enter read w 1' 'unit enter write w 1' 'unit leave write w 1 0' 'watcher leave read w 1 0' 'unit enter read p 1' \
  'watcher enter write p 2' 'watcher leave write p 2 1' 'watcher enter read w 2' > "$WORK/probe.readcycle.rec"
printf '%s\n' 'watcher enter read w 1' 'unit enter write w 1' 'unit leave write w 1 0' 'watcher leave read w 1 0' > "$WORK/probe.leave.rec"
case "$(pn_cycle "$WORK/probe.cycle.rec")" in CYCLE*) ok "[watcher] pn_cycle self-probe: a lost token (both parties entered writes on different FIFOs, nothing in flight) is a cycle" ;;
  *) bad "[watcher] pn_cycle self-probe: a seeded deadlock read as no cycle, so the detector cannot fire" ;; esac
case "$(pn_cycle "$WORK/probe.readcycle.rec")" in CYCLE*) ok "[watcher] pn_cycle self-probe: both parties entered READS on different FIFOs with equal counts (the watcher's p write failed, rc 1, so no token is on its way) is a cycle" ;;
  *) bad "[watcher] pn_cycle self-probe: the read-read lost-token shape read as no cycle" ;; esac
case "$(pn_cycle "$WORK/probe.leave.rec")" in none) ok "[watcher] pn_cycle self-probe: a party whose last record is a leave is not in a cycle" ;;
  *) bad "[watcher] pn_cycle self-probe: a party on a leave read as a cycle" ;; esac
case "$(pn_cycle "$WORK/probe.buffered.rec")" in none) ok "[watcher] pn_cycle self-probe: a buffered token (sent 1 > received 0 on w) is not a cycle" ;;
  *) bad "[watcher] pn_cycle self-probe: a buffered token read as a cycle" ;; esac
case "$(pn_cycle "$WORK/probe.samefifo.rec")" in none) ok "[watcher] pn_cycle self-probe: both parties on the same FIFO is not a cycle" ;;
  *) bad "[watcher] pn_cycle self-probe: two parties on one FIFO read as a cycle" ;; esac
mkfifo "$WORK/pn.ev" && exec 4<> "$WORK/pn.ev" || broken "could not make or hold the watcher section's event FIFO"
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
exec 4<&-

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
# td_xwait <dir> <pids>: records the pids it waits on in <dir>/xwait, then blocks until each is gone, paced, with no
# bound: the end of the subject's xargs, an event
td_xwait() { local x d="$1"; shift; [ "$#" -gt 0 ] || { [ "${blk:-}" = "$PB" ] && bad "teardown drive: no xargs pid was read under the subject's parent, so nothing was waited for"; }; printf '%s\n' "$*" > "$d/xwait"; for x in "$@"; do while kill -0 "$x" 2>/dev/null; do sleep 0.1; done; done; }
# td_drive <block> <set> <term|int> -> appends the mode's cells to $WORK/td.<set>.v
# EVERY DRIVE ENDS WITH ITS SUBJECT'S xargs GONE (BL-985). xargs is the parent's only child once both stubs have
# recorded (the parent then sits in its wait for it), so it is read there, once, by `pgrep -P`. A parent that exits
# without tearing the pool down (td-old-traps: `exit 143` in place of pool_stop) leaves xargs orphaned, and after the
# release it dispatches the queued unit -- one more worker started -- after this drive had stopped waiting: whether
# that start was counted then depended on the fixture outliving it. So each mode waits for xargs to be gone before it
# records its cells, and every start the drive causes has happened by then.
td_drive() {
  local blk="$1" set="$2" mode="$3" d="$WORK/td.$2.$3" p n st root ks k wp t dp dn xp
  mkdir -p "$d/s" && cp -R "$TDT" "$d/w" || { bad "teardown drive $set/$mode: could not copy the template"; return 1; }
  set -m
  ( cd "$d/w" && unset PREPUSH_POOL_DEPTH && export AI_DLC_FIXTURE_JOBS=2 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 TD_DIR="$d/s" \
    && exec bash -c '. "$1" > /dev/null 2>&1; run_fixtures > "$2" 2>&1' _ "$blk" "$d/out" ) > /dev/null 2>&1 &
  p=$!
  set +m
  td_wait2 "$d/s"
  xp="$(pgrep -P "$p" 2>/dev/null | tr '\n' ' ')"
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
    : > "$d/s/release"; wait "$p"; st=$?; wait "$dp"; td_xwait "$d/s" $xp
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
    : > "$d/s/release"; wait "$p"; st=$?; td_xwait "$d/s" $xp
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

# ------------------------------------------------- consumer-layout jobs (BL-1027, BL-1043) -----
# The distribution hook's fixture_suite_step installs the tree into a scratch consumer tree and names it in the
# switch AI_DLC_FX_CL_TREE; run_fixtures (FIXTURE_POOL) reads the switch at depth 0 only, unsets it, and runs each
# selected SHIPPING fixture there as one pool unit `<fx>@consumer`. cl_select keys each candidate INSIDE the
# installed tree (BL-1043): its records (<store base>/consumer-placement-keys/<root commit>, published the moment a
# unit passes) hold installed paths and installed bytes, never the distribution records, and a push with no record at all FAILs the step
# naming scripts/census-consumer-layout.sh, the one-time census that records each candidate it ran green.
# THE SUBJECT IS THE REAL SPANS: FIXTURE_POOL and SUITE_STEP extracted from .githooks/pre-push (the step exists only
# there) and sourced in scratch worlds, fixture_suite_step driven with PREPUSH_CL_ENTRY=1 set the way the hook's main
# body sets it, and the REAL census script driven over the same (possibly mutated) FIXTURE_POOL span through --pool.
# Every world is a copy of ONE template: four stub fixtures (cl-ok passes in both layouts; cl-bad, cl-vs and cl-dist
# exit 1 wherever core/ is absent, i.e. in the consumer layout; cl-dist carries .dist-only; cl-vs declares
# lib/vs.txt), a stub runner at scripts/ai-dlc/hermetic-run.sh, and a stub scripts/install.sh that records its argv,
# ships core/fixtures/<fx> unless it carries .dist-only, copies lib/, and renders templates/rd.tpl (when present) over
# the installed lib/rd.txt, and writes a .claude/.ai-dlc-version whose volatile fields move on every install, as the
# real stamp's do (cl_select keys it on its stable fields). The A world adds the placement pair: cl-rd declares lib/rd.txt (the rendered file) and
# cl-dec declares lib/input.txt, both green in both layouts, beside notes/dev.txt, which the stub never installs.
# The B world is a LINKED WORKTREE, so the hook's GITDIR is absolute there, as on every real push from a worktree.
# One arm runs the REAL scripts/install.sh, which refuses this world, so the step's fail-closed path and its
# explicit argument are driven through the real program. Cells, one value each, compared to CL_WANT:
#   cl_census  the A world's census first: "<census rc>|<records>": cl-bad and cl-vs FAIL and get no record (rc 1)
#   cl_i       first push: "<step rc>|<cl-bad dist row>|<FAIL @consumer rows>": passes in the distribution layout,
#              FAILs as cl-bad@consumer (and cl-vs@consumer), which the census left unrecorded (case i)
#   cl_ii      cl-ok@consumer, green in both layouts and recorded by the census, is not re-run and keeps its record (case ii)
#   cl_iii     cl-dist ran in the distribution layout; no cl-dist@consumer anywhere (case iii)
#   cl_arg     the stub install.sh got exactly one argument, the tree the step announced (D2)
#   cl_vii     a no-change re-push after the red: cl-bad@consumer runs again and FAILs   (case vii)
#   cl_v       the same re-push with cl-vs's distribution pass in the verdict store: cl-vs@consumer runs and FAILs (case v)
#   cl_v_ctl   its CONTROL: the store entry is live, so the distribution unit cl-vs is skipped on it. The entry is
#              composed by the hook's own READSET_VS span (readset_vs_store/_ident_here/_input, the span the store's
#              writer hermetic-run.sh sources) over the rows of cl-vs's distribution key record, as hr_store_put does
#   cl_iv      a push moving only lib/input.txt (installed by the stub; no fixture file): cl-ok@consumer is selected,
#              "unmapped: closure changed"                                          (case iv)
#   cl_nl      a push moving only notes/dev.txt, which install.sh never installs: "<cl-ok@consumer>|<cl-ok>": the
#              consumer unit is NOT selected, the distribution unit (keyed on the whole tree) runs
#   cl_ni      a push moving only the stub scripts/install.sh by a comment, which installs no different byte: the same pair
#   cl_tp      a push moving only templates/rd.tpl: "<cl-rd@consumer>|<cl-dec@consumer>|<cl-rd>": the reader of the
#              rendered file runs in the consumer layout, the declared non-reader does not, and the distribution cl-rd
#              (keyed on the distribution lib/rd.txt, which did not move) does not either
#   cl_cstore  a no-change push with cl-dec's CONSUMER-LAYOUT store entry (the fixed consumer root's project, cl-dec's
#              installed-path rows) seeded and its record removed: "<cl-dec@consumer>|<record>": the store skips the
#              unit and the record is republished. With cl_v (a DISTRIBUTION entry never skips <fx>@consumer) this is
#              the invariant both ways: only a consumer-layout pass at the unit's placement satisfies it
#   cl_entry   PREPUSH_CL_ENTRY absent: rc 0, no tree announced, install.sh never ran, no @consumer row
#   cl_entry_ran  the same push: every distribution fixture ran (its positive conjunct)
#   cl_vi_out  the same push (switch unset, the consumer's state) prints exactly what a copy of the block with the
#              seam removed prints, `done` progress lines aside                    (case vi)
#   cl_vi_list the same push: no @consumer row and no consumer key records         (case vi)
#   cl_ref     the next push WITH the entry flag and no consumer record at all: "<rc>|<FAIL lines naming the census>|
#              <@consumer unit rows>|<keys dir>": the step FAILs, runs no unit and writes no record (F-B5's first push)
#   cl_fb5_sel  the census after it, a v2 verified record present (absolute GITDIR) and no consumer keys dir:
#               "<verified format>|<keys dir>|<census selection>": every candidate is selected (F-B5)
#   cl_fb5_state  the consumer record that census writes for cl-ok reads `#state ok`, never `#state seeded`
#               (A seed from the v2 record cannot skip a unit here: its keys are distribution paths, and every unit
#               is keyed on installed ones, so it is not guarded and not mutated.)
#   cl_fb2     run_fixtures at depth 1 with the switch inherited (exported) over a valid tree: rc 0, no @consumer row,
#              and the depth-1 notice printed (F-B2)
#   cl_fb2_ran the same drive: every distribution fixture ran
#   cl_fb2_d0  its ALLOW twin, the switch exported at depth 0 over a tree that moved since the C template's census:
#              three @consumer rows, and every unit saw the switch unset (run_fixtures unsets it before dispatch)
#   cl_inst_rc   the REAL install.sh refusing the tree: "<rc>|<FAIL line naming scripts/install.sh>|<unit rows>|<tree
#                removed>" -- fails closed, the pool never opens, the tree does not leak (D2)
#   cl_inst_arg  the target the real install.sh's log names is the tree the FAIL line names (D2)
#   cl_resume  a census stopped mid-run keeps the passes it made (cl_K)
# MUTANTS (rows in the header), each a cmp -s guarded copy of the span it edits, driven over only the stages its
# decides and twins need, each drive on a fresh copy of the template.
CLH="$ROOT/.githooks/pre-push"
CLC="$ROOT/scripts/census-consumer-layout.sh"
[ -f "$CLH" ] || broken "the consumer-layout section needs the distribution hook .githooks/pre-push"
[ -f "$CLC" ] || broken "the consumer-layout section needs the census scripts/census-consumer-layout.sh"
CLW="$WORK/cl"; mkdir -p "$CLW" || broken "mkdir $CLW"
sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$CLH" > "$CLW/pool.sh"
sed -n '/^# SUITE_STEP_BEGIN$/,/^# SUITE_STEP_END$/p' "$CLH" > "$CLW/step.sh"
grep -q '^cl_select() ' "$CLW/pool.sh" && grep -q '^fixture_suite_step() ' "$CLW/step.sh" && grep -q 'PREPUSH_CL_ENTRY' "$CLW/step.sh" \
  || broken "the extracted FIXTURE_POOL / SUITE_STEP spans of $CLH carry no consumer-layout seam"
CLT="$CLW/tpl"
mkdir -p "$CLT/core/fixtures/cl-ok" "$CLT/core/fixtures/cl-bad" "$CLT/core/fixtures/cl-dist" "$CLT/core/fixtures/cl-vs" \
  "$CLT/lib" "$CLT/scripts/ai-dlc" "$CLT/.githooks" || broken "could not build the consumer-layout template"
cp -p "$CLH" "$CLT/.githooks/pre-push" || broken "could not copy the hook into the template"
printf 'input\n' > "$CLT/lib/input.txt"; printf 'vs\n' > "$CLT/lib/vs.txt"
printf '#!/usr/bin/env bash\n[ -z "${CL_SAW:-}" ] || printf "%%s\\n" "${AI_DLC_FX_CL_TREE-unset}" >> "$CL_SAW"\nexit 0\n' > "$CLT/core/fixtures/cl-ok/run.sh"
for _f in cl-bad cl-dist cl-vs; do
  printf '#!/usr/bin/env bash\n[ -d core ] || { echo "%s: no core/ in this layout"; exit 1; }\nexit 0\n' "$_f" > "$CLT/core/fixtures/$_f/run.sh"
done
printf 'lib/vs.txt\n' > "$CLT/core/fixtures/cl-vs/inputs.decl"
printf 'fails in the consumer layout by construction; the seam must never select it\n' > "$CLT/core/fixtures/cl-dist/.dist-only"
cat > "$CLT/scripts/ai-dlc/hermetic-run.sh" <<'HR'
#!/usr/bin/env bash
# stub runner: --root <root> <fx> runs the fixture plainly from <root>, in either layout
cd "$2" || exit 2
for d in core/fixtures tests/fixtures; do [ -f "$d/$3/run.sh" ] && exec bash "$d/$3/run.sh"; done
exit 2
HR
cat > "$CLT/scripts/install.sh" <<'IN'
#!/usr/bin/env bash
# stub install.sh: records its argv, ships every core/fixtures/<fx> that has run.sh and no .dist-only, copies lib/,
# installs the hook as the real one does, renders templates/rd.tpl over the installed lib/rd.txt when the template
# exists, and writes a version stamp whose
# release, commit and install-time fields differ on every install, as the real one's do
[ -z "${CL_ARGV:-}" ] || { printf '%s\n' "$#"; printf '%s\n' "$@"; } > "$CL_ARGV"
t="${1:-.}"
[ -d "$t/_bmad" ] || exit 1
mkdir -p "$t/tests/fixtures" "$t/scripts/ai-dlc" || exit 1
for d in core/fixtures/*/; do
  [ -f "$d/run.sh" ] && [ ! -f "$d/.dist-only" ] || continue
  b="${d%/}"; b="${b##*/}"; mkdir -p "$t/tests/fixtures/$b" && cp "$d"* "$t/tests/fixtures/$b/" || exit 1
done
cp scripts/ai-dlc/hermetic-run.sh "$t/scripts/ai-dlc/hermetic-run.sh"
mkdir -p "$t/.githooks" && cp .githooks/pre-push "$t/.githooks/pre-push" || exit 1
cp -R lib "$t/lib" || exit 1
[ ! -f templates/rd.tpl ] || cp templates/rd.tpl "$t/lib/rd.txt" || exit 1
mkdir -p "$t/.claude" && printf 'version: 1.%s\ncommit: c%s\nskill_version: 1.%s\nskill_commit: c%s\ninstalled_at: %s\nupstream: u\n' $$ $$ $$ $$ $$ > "$t/.claude/.ai-dlc-version" || exit 1
IN
( cd "$CLT" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f -c commit.gpgsign=false commit -qm seed ) > /dev/null 2>&1 \
  || broken "could not commit the consumer-layout template"
cl_commit() { ( cd "$1" && git add -A && git -c user.email=f@f -c user.name=f -c commit.gpgsign=false commit -qm "$2" ) > /dev/null 2>&1; }
# cl_census <pool> <world> <tag>: the REAL census over <pool>, from the world's root; output in $CLW/census.<tag>, rc printed
cl_census() {
  local rc
  rc="$( cd "$2" && { unset PREPUSH_POOL_DEPTH PREPUSH_CL_ENTRY AI_DLC_FX_CL_TREE
    AI_DLC_VERDICT_STORE="$2.vs" AI_DLC_READSET_LIVE_TRACE=0 bash "$CLC" --jobs 2 --pool "$1" > "$CLW/census.$3" 2>&1; echo "$?"; } )"
  printf '%s' "$rc"
}
cl_recs() { ls "$1" 2>/dev/null | sed -n 's/\.key$//p' | sort | tr '\n' ' ' | sed 's/ *$//'; }
# cl_kdir <world>: the world's consumer-layout records dir, where cl_select puts it: the world's store base
# (<world>.vs, every drive's AI_DLC_VERDICT_STORE), consumer-placement-keys, the world's root commit
cl_kdir() { printf '%s.vs/consumer-placement-keys/%s' "$1" "$(git -C "$1" rev-list --max-parents=0 HEAD 2>/dev/null | LC_ALL=C sort | sed -n 1p)"; }
# the C template: a copy of the template carrying the base span's census records, and a committed stub-installed tree
# that moved since that census (one extra file), so a drive over a copy of it selects all three shipping fixtures
CLTC="$CLW/tpl.c"
cp -Rp "$CLT" "$CLTC" && [ "$(cl_census "$CLW/pool.sh" "$CLTC" tplc)" = 1 ] && [ "$(cl_recs "$(cl_kdir "$CLTC")")" = cl-ok ] \
  || broken "the C template's census did not record exactly cl-ok: $(tail -n 3 "$CLW/census.tplc" 2>/dev/null | tr '\n' ' ')"
mkdir -p "$CLW/tree.tpl/_bmad" && ( cd "$CLT" && unset CL_ARGV && bash scripts/install.sh "$CLW/tree.tpl" ) \
  && [ -f "$CLW/tree.tpl/tests/fixtures/cl-ok/run.sh" ] && printf 'moved since the census\n' > "$CLW/tree.tpl/extra.txt" \
  && ( cd "$CLW/tree.tpl" && git init -q . ) > /dev/null 2>&1 && cl_commit "$CLW/tree.tpl" tree || broken "the stub install.sh built no tree"
# the no-seam block for case (vi): the switch read removed and the two seam entry points made empty
sed 's|^  if \[ "\$POOL_DEPTH_IN" -eq 0 \]; then cl_tree="\${AI_DLC_FX_CL_TREE:-}"; fi$|  :|' "$CLW/pool.sh" > "$CLW/noseam.sh"
printf 'cl_select() { return 0; }\ncl_write() { return 0; }\n' >> "$CLW/noseam.sh"
grep -q '^  :$' "$CLW/noseam.sh" && ! cmp -s "$CLW/pool.sh" "$CLW/noseam.sh" || broken "the no-seam block is the block: the switch read was not removed"
# cl_wt <dst>: a linked-worktree world, the template's repository at <dst>.main and its worktree at <dst>
cl_wt() {
  cp -Rp "$CLT" "$1.main" && git -C "$1.main" worktree add -q --detach "$1" HEAD > /dev/null 2>&1 && [ -f "$1/.githooks/pre-push" ]
}

# cl_drive <pool> <step> <world> <tag> <step|pool> [depth] [exported tree] [noentry] -> rc; output in $CLW/out.<tag>
cl_drive() {
  local rc
  rc="$( cd "$3" && {
    unset PREPUSH_POOL_DEPTH; [ -z "${6:-}" ] || export PREPUSH_POOL_DEPTH="$6"
    [ -z "${7:-}" ] || export AI_DLC_FX_CL_TREE="$7"
    export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_VERDICT_STORE="$3.vs" CL_ARGV="$CLW/argv.$4" CL_SAW="$CLW/saw.$4"
    fail=0; PENDING_N=0; SUITE_SKIPPED=0; SUITE_SKIP_CAUSE=""; unset PREPUSH_CL_ENTRY; [ "${8:-}" = noentry ] || PREPUSH_CL_ENTRY=1
    . "$1" > /dev/null 2>&1; . "$2" > /dev/null 2>&1
    if [ "$5" = step ]; then fixture_suite_step > "$CLW/out.$4" 2>&1; else run_fixtures > "$CLW/out.$4" 2>&1; fi
    echo "$?"; } )"
  printf '%s' "$rc"
}
cl_row() { awk -v n="$2" '($1 == "ok" || $1 == "FAIL") && NF == 2 && $2 == n { v = $1 } END { print (v == "" ? "none" : v) }' "$1" 2>/dev/null; }
cl_crows() { awk '($1 == "ok" || $1 == "FAIL") && NF == 2 && $2 ~ /@consumer$/' "$1" 2>/dev/null | grep -c .; }
cl_fails() { awk '$1 == "FAIL" && NF == 2 && $2 ~ /@consumer$/ { print $2 }' "$1" 2>/dev/null | sort | tr '\n' ' ' | sed 's/ *$//'; }
cl_dist() { awk '$1 == "ok" && NF == 2 && $2 !~ /@consumer$/ { print $2 }' "$1" 2>/dev/null | sort | tr '\n' ' ' | sed 's/ *$//'; }
cl_cnt() { local n; n="$(grep -c -- "$1" "$2" 2>/dev/null)" || n=0; printf '%s' "${n:-0}"; }
cl_seed_store() { # <world>: the store entry hermetic-run.sh would write for cl-vs's pass; then cl-vs's distribution record goes
  ( cd "$1" && export AI_DLC_VERDICT_STORE="$1.vs" && . "$CLW/pool.sh" > /dev/null 2>&1
    s="$(readset_vs_store "$PWD")" && [ -n "$s" ] && id="$(readset_vs_ident_here)" && [ -s "$KEYS_DIR/cl-vs.key" ] || exit 1
    readset_key_rows "$KEYS_DIR/cl-vs.key" > "$1.rows" && readset_vs_input cl-vs "$id" "$1.rows" > "$1.vsd" || exit 1
    dig="$(shasum -a 256 < "$1.vsd" | cut -d' ' -f1)"; [ "${#dig}" -eq 64 ] || exit 1
    mkdir -p "$s" && { printf '#format k1\n#state ok\n'; cat "$1.vsd"; printf '#pending 0\n'; } > "$s/$dig" && rm -f "$KEYS_DIR/cl-vs.key" )
}
# cl_seed_cstore <pool> <world> <fx>: the CONSUMER-LAYOUT store entry hermetic-run.sh would write for <fx>'s pass in
# the installed tree: project <store base>/<the fixed consumer root commit> (cl_tree_init in a scratch dir), the
# ident of the hook and runner the tree carries (the stub install copies both), and the rows of <fx>'s placement
# record. Then the record goes, so only the store can skip the unit.
cl_seed_cstore() {
  ( cd "$2" && . "$1" > /dev/null 2>&1
    k="$(cl_kdir "$2")/$3.key"; [ -s "$k" ] || exit 1
    rt="$(mktemp -d "$CLW/root.XXXXXX")" && cl_tree_init "$rt" > /dev/null 2>&1 && root="$(git -C "$rt" rev-parse HEAD)" || exit 1
    id="$(readset_vs_ident .githooks/pre-push scripts/ai-dlc/hermetic-run.sh)" && [ -n "$id" ] || exit 1
    readset_key_rows "$k" > "$2.crows" && readset_vs_input "$3" "$id" "$2.crows" > "$2.cvsd" || exit 1
    dig="$(shasum -a 256 < "$2.cvsd" | cut -d' ' -f1)"; [ "${#dig}" -eq 64 ] || exit 1
    mkdir -p "$2.vs/$root" && { printf '#format k1\n#state ok\n'; cat "$2.cvsd"; printf '#pending 0\n'; } > "$2.vs/$root/$dig" && rm -f "$k" )
}
# cl_A <pool> <step> <tag> <stages>: stage 1 the census and the first push, 2 the no-change re-push with the store
# seeded, 3 a push moving lib/input.txt only, 4 notes/dev.txt only, 5 the stub install.sh only, 6 templates/rd.tpl
# only, 7 a no-change push with cl-dec's consumer-layout store entry seeded and its record gone. Every stage after 1
# implies 1, and each moves one file, so any subset of 2-7 drives in order.
cl_A() {
  local P="$1" S="$2" g="$3" W="$CLW/$3.wa" o r t a
  cp -Rp "$CLT" "$W" && mkdir -p "$W/core/fixtures/cl-rd" "$W/core/fixtures/cl-dec" "$W/templates" "$W/notes" \
    || broken "could not copy the consumer-layout template"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/core/fixtures/cl-rd/run.sh"; printf 'lib/rd.txt\n' > "$W/core/fixtures/cl-rd/inputs.decl"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/core/fixtures/cl-dec/run.sh"; printf 'lib/input.txt\n' > "$W/core/fixtures/cl-dec/inputs.decl"
  printf 'rd plain\n' > "$W/lib/rd.txt"; printf 'rd rendered\n' > "$W/templates/rd.tpl"; printf 'dev\n' > "$W/notes/dev.txt"
  cl_commit "$W" placement || broken "could not commit the placement pair"
  r="$(cl_census "$P" "$W" "$g.A0")"
  printf 'cl_census=%s|%s\n' "$r" "$(cl_recs "$(cl_kdir "$W")")"
  r="$(cl_drive "$P" "$S" "$W" "$g.A1" step)"; o="$CLW/out.$g.A1"
  t="$(sed -n 's/^   consumer layout: scripts\/install\.sh built \([^ ]*\) (.*/\1/p' "$o")"
  a="$(tr '\n' ' ' < "$CLW/argv.$g.A1" 2>/dev/null)"
  printf 'cl_i=%s|%s|%s\n' "$r" "$(cl_row "$o" cl-bad)" "$(cl_fails "$o")"
  printf 'cl_ii=%s|%s\n' "$(cl_row "$o" cl-ok@consumer)" "$([ -f "$(cl_kdir "$W")/cl-ok.key" ] && echo rec || echo norec)"
  printf 'cl_iii=%s|%s\n' "$(cl_row "$o" cl-dist)" "$(cl_cnt 'cl-dist@consumer' "$o")"
  if [ -n "$t" ] && [ "$a" = "1 $t " ]; then printf 'cl_arg=explicit\n'; else printf 'cl_arg=[%s] for [%s]\n' "$a" "$t"; fi
  case " $4 " in *" 2 "*)
    if cl_seed_store "$W"; then r="$(cl_drive "$P" "$S" "$W" "$g.A2" step)"; o="$CLW/out.$g.A2"
      printf 'cl_vii=%s\ncl_v=%s\n' "$(cl_row "$o" cl-bad@consumer)" "$(cl_row "$o" cl-vs@consumer)"
      printf 'cl_v_ctl=%s|%s\n' "$(cl_cnt 'verdict store: 1 fixture(s) skipped on a pass recorded elsewhere: cl-vs$' "$o")" "$(cl_row "$o" cl-vs)"
    else printf 'cl_vii=noseed\ncl_v=noseed\ncl_v_ctl=noseed\n'; fi ;;
  esac
  case " $4 " in *" 3 "*)
    printf 'moved\n' > "$W/lib/input.txt"
    r="$(cl_drive "$P" "$S" "$W" "$g.A3" step)"; o="$CLW/out.$g.A3"
    printf 'cl_iv=%s|%s\n' "$(cl_row "$o" cl-ok@consumer)" "$(cl_cnt '^   \.\.      cl-ok@consumer: unmapped: closure changed$' "$o")" ;;
  esac
  case " $4 " in *" 4 "*)
    printf 'dev moved\n' > "$W/notes/dev.txt"
    r="$(cl_drive "$P" "$S" "$W" "$g.A4" step)"; o="$CLW/out.$g.A4"
    printf 'cl_nl=%s|%s\n' "$(cl_row "$o" cl-ok@consumer)" "$(cl_row "$o" cl-ok)" ;;
  esac
  case " $4 " in *" 5 "*)
    printf '# a comment: no installed byte moves\n' >> "$W/scripts/install.sh"
    r="$(cl_drive "$P" "$S" "$W" "$g.A5" step)"; o="$CLW/out.$g.A5"
    printf 'cl_ni=%s|%s\n' "$(cl_row "$o" cl-ok@consumer)" "$(cl_row "$o" cl-ok)" ;;
  esac
  case " $4 " in *" 6 "*)
    printf 'rd rendered, moved\n' > "$W/templates/rd.tpl"
    r="$(cl_drive "$P" "$S" "$W" "$g.A6" step)"; o="$CLW/out.$g.A6"
    printf 'cl_tp=%s|%s|%s\n' "$(cl_row "$o" cl-rd@consumer)" "$(cl_row "$o" cl-dec@consumer)" "$(cl_row "$o" cl-rd)" ;;
  esac
  case " $4 " in *" 7 "*)
    if cl_seed_cstore "$P" "$W" cl-dec; then r="$(cl_drive "$P" "$S" "$W" "$g.A7" step)"; o="$CLW/out.$g.A7"
      printf 'cl_cstore=%s|%s\n' "$(cl_row "$o" cl-dec@consumer)" "$([ -f "$(cl_kdir "$W")/cl-dec.key" ] && echo rec || echo norec)"
    else printf 'cl_cstore=noseed\n'; fi ;;
  esac
}
# cl_B <pool> <step> <tag> <stages>: a linked-worktree world. Stage 1 a push with no entry flag (the switch never
# set); stage 2 the next push with the flag and no consumer record; stage 3 the census after it, a v2 verified
# record present. Each stage implies the ones before it.
cl_B() {
  local P="$1" S="$2" g="$3" W="$CLW/$3.wb" o r a
  cl_wt "$W" || broken "could not build the linked-worktree world"
  r="$(cl_drive "$P" "$S" "$W" "$g.B0" step "" "" noentry)"; o="$CLW/out.$g.B0"
  printf 'cl_entry=%s|%s|%s|%s\n' "$r" "$(cl_cnt 'consumer layout' "$o")" "$([ -e "$CLW/argv.$g.B0" ] && echo ran || echo no)" "$(cl_crows "$o")"
  printf 'cl_entry_ran=%s\n' "$(cl_dist "$o")"
  # Every spelling of the world path (a resolved /private/var form, a doubled slash from TMPDIR): the world dirs are
  # named `<tag>.wb` under $CLW/, so the path is matched by that shape rather than by one literal spelling.
  grep -v '^   done ' "$o" | sed -E "s|[^ (]*/cl/[A-Za-z0-9._-]+\.wb(\.main)?|WORLD|g" > "$o.f"
  if [ -s "$o.f" ] && cmp -s "$o.f" "$CLW/noseam.f"; then printf 'cl_vi_out=same\n'; else printf 'cl_vi_out=differs\n'; fi
  printf 'cl_vi_list=%s|%s\n' "$(cl_cnt '@consumer' "$o")" "$([ -e "$(cl_kdir "$W")" ] && echo cl-keys || echo none)"
  case " $4 " in *" 2 "*|*" 3 "*)
    r="$(cl_drive "$P" "$S" "$W" "$g.B1" step)"; o="$CLW/out.$g.B1"
    printf 'cl_ref=%s|%s|%s|%s\n' "$r" "$(cl_cnt '^   FAIL  consumer layout: no consumer-layout record exists in .* -- run the one-time census from a clean worktree at this sha: bash scripts/census-consumer-layout.sh$' "$o")" \
      "$(cl_crows "$o")" "$([ -e "$(cl_kdir "$W")" ] && echo cl-keys || echo nocl)" ;;
  esac
  case " $4 " in *" 3 "*)
    a="$(cat "$W.main/.git/ai-dlc-fixture-verified.format" 2>/dev/null)|$([ -e "$(cl_kdir "$W")" ] && echo cl-keys || echo nocl)"
    r="$(cl_census "$P" "$W" "$g.B2")"
    printf 'cl_fb5_sel=%s|%s\n' "$a" "$(sed -n 's/^   \.\.    consumer layout: \([0-9]* of [0-9]*\) shipping.*/\1/p' "$CLW/census.$g.B2")"
    printf 'cl_fb5_state=%s\n' "$(sed -n 2p "$(cl_kdir "$W")/cl-ok.key" 2>/dev/null)" ;;
  esac
}
# cl_C <pool> <step> <tag> <stages>: stage 1 run_fixtures at depth 1 with the switch exported; stage 2 the same at
# depth 0. Both worlds are copies of the C template (census records present), each over a copy of the moved tree.
cl_C() {
  local P="$1" S="$2" g="$3" o r
  case " $4 " in *" 1 "*)
    cp -Rp "$CLTC" "$CLW/$g.wc1" && cp -Rp "$CLTC.vs" "$CLW/$g.wc1.vs" && cp -Rp "$CLW/tree.tpl" "$CLW/$g.t1" || broken "could not copy the F-B2 world"
    r="$(cl_drive "$P" "$S" "$CLW/$g.wc1" "$g.C1" pool 1 "$CLW/$g.t1")"; o="$CLW/out.$g.C1"
    printf 'cl_fb2=%s|%s|%s\n' "$r" "$(cl_crows "$o")" "$(cl_cnt 'nested: depth 1, width' "$o")"
    printf 'cl_fb2_ran=%s\n' "$(cl_dist "$o")" ;;
  esac
  case " $4 " in *" 2 "*)
    cp -Rp "$CLTC" "$CLW/$g.wc0" && cp -Rp "$CLTC.vs" "$CLW/$g.wc0.vs" && cp -Rp "$CLW/tree.tpl" "$CLW/$g.t0" || broken "could not copy the F-B2 world"
    r="$(cl_drive "$P" "$S" "$CLW/$g.wc0" "$g.C0" pool "" "$CLW/$g.t0")"; o="$CLW/out.$g.C0"
    printf 'cl_fb2_d0=%s|%s\n' "$(cl_crows "$o")" "$(sort -u "$CLW/saw.$g.C0" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')" ;;
  esac
}
# cl_K <pool> <step> <tag>: a census STOPPED mid-run, then a second census. One extra shipping fixture, cl-zhold,
# sorts last; in the consumer layout it writes the sentinel $CLW/hold.<tag> and waits, unbounded, for
# $CLW/hold.<tag>.go or for its parent to die (BL-868: no wait here is bounded by time or iterations). The first census runs one unit at a time in its own process group, so cl-bad, cl-ok and cl-vs have
# finished when the sentinel appears; the drive then TERMs that group. cl_resume = "<records left by the stopped
# census>|<the second census's selection>|<cl-ok@consumer lines in the second census>": cl-ok's pass survived the
# stop and is not run again. Kept only at the end, the stop would lose it and the second census would read 4 of 4.
cl_K() {
  local P="$1" g="$3" W="$CLW/$3.wk" pid r h="$CLW/hold.$3"
  cp -Rp "$CLT" "$W" && mkdir -p "$W/core/fixtures/cl-zhold" || broken "could not build the stop world"
  printf '#!/usr/bin/env bash\n[ -d core ] || [ -z "${CL_HOLD:-}" ] || { : > "$CL_HOLD"; while [ ! -f "$CL_HOLD.go" ] && kill -0 "$PPID" 2>/dev/null; do sleep 0.1; done; }\nexit 0\n' > "$W/core/fixtures/cl-zhold/run.sh"
  cl_commit "$W" hold || broken "could not commit the stop world"
  rm -f "$h" "$h.go"
  set -m
  ( cd "$W" && unset PREPUSH_POOL_DEPTH PREPUSH_CL_ENTRY AI_DLC_FX_CL_TREE
    CL_HOLD="$h" AI_DLC_VERDICT_STORE="$W.vs" AI_DLC_READSET_LIVE_TRACE=0 exec bash "$CLC" --jobs 1 --pool "$P" ) > "$CLW/census.$g.K1" 2>&1 &
  pid=$!
  set +m
  while [ ! -f "$h" ] && kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
  kill -TERM -- "-$pid" 2>/dev/null; wait "$pid" 2>/dev/null; : > "$h.go"
  r="$(cl_recs "$(cl_kdir "$W")")"
  [ "$(cl_census "$P" "$W" "$g.K2")" != "" ] || broken "the second census of the stop world printed no exit status"
  printf 'cl_resume=%s|%s|%s\n' "$r" "$(sed -n 's/^   \.\.    consumer layout: \([0-9]* of [0-9]*\) shipping.*/\1/p' "$CLW/census.$g.K2")" "$(cl_cnt '^cl-ok@consumer ' "$CLW/census.$g.K2")"
}
# cl_R <pool> <step> <tag>: the REAL scripts/install.sh, which refuses this world (no jq on a hermetic PATH, or no
# scaffold-ignore.sh beside it); its log tail names its target
cl_R() {
  local P="$1" S="$2" g="$3" W="$CLW/$3.wr" o r t n
  cp -Rp "$CLT" "$W" && cp -p "$ROOT/scripts/install.sh" "$W/scripts/install.sh" || broken "could not build the real-install world"
  r="$(cl_drive "$P" "$S" "$W" "$g.R" step)"; o="$CLW/out.$g.R"
  t="$(sed -n 's/^   FAIL  consumer-layout tree: scripts\/install\.sh \(.*\) failed, so no shipping fixture can run in the consumer layout$/\1/p' "$o")"
  printf 'cl_inst_rc=%s|%s|%s|%s\n' "$r" "$(printf '%s' "$t" | grep -c .)" "$(awk '($1 == "ok" || $1 == "FAIL") && NF == 2' "$o" | grep -c .)" \
    "$([ -n "$t" ] && [ ! -e "$t" ] && echo gone || echo left)"
  n="$(sed -n 's/^ *Target project: //p; s/^ *Nothing was written to \(.*\)\.$/\1/p' "$o" | sort -u | tr '\n' ' ' | sed 's/ *$//')"
  if [ -n "$t" ] && [ "$n" = "$t" ]; then printf 'cl_inst_arg=tree\n'; else printf 'cl_inst_arg=[%s] for [%s]\n' "$n" "$t"; fi
}
CL_CELLS="cl_census cl_i cl_ii cl_iii cl_arg cl_vii cl_v cl_v_ctl cl_iv cl_nl cl_ni cl_tp cl_cstore cl_entry cl_entry_ran cl_vi_out cl_vi_list cl_ref cl_fb5_sel cl_fb5_state cl_fb2 cl_fb2_ran cl_fb2_d0 cl_inst_rc cl_inst_arg cl_resume"
CL_WANT="cl_census=1|cl-dec cl-ok cl-rd
cl_i=1|ok|cl-bad@consumer cl-vs@consumer
cl_ii=none|rec
cl_iii=ok|0
cl_arg=explicit
cl_vii=FAIL
cl_v=FAIL
cl_v_ctl=1|none
cl_iv=ok|1
cl_nl=none|ok
cl_ni=none|ok
cl_tp=ok|none|none
cl_cstore=none|rec
cl_entry=0|0|no|0
cl_entry_ran=cl-bad cl-dist cl-ok cl-vs
cl_vi_out=same
cl_vi_list=0|none
cl_ref=1|1|0|nocl
cl_fb5_sel=v2|nocl|3 of 3
cl_fb5_state=#state ok
cl_fb2=0|0|1
cl_fb2_ran=cl-bad cl-dist cl-ok cl-vs
cl_fb2_d0=3|unset
cl_inst_rc=1|1|0|gone
cl_inst_arg=tree
cl_resume=cl-ok|3 of 4|0"
# cl_score <pool> <step> <tag> <cells...>: drives only the stages the cells need, prints only those cells
cl_score() {
  local P="$1" S="$2" g="$3" c a="" b="" cc="" r=0 k=0; shift 3
  for c in "$@"; do case "$c" in
    cl_census|cl_i|cl_ii|cl_iii|cl_arg) a="$a 1" ;; cl_vii|cl_v|cl_v_ctl) a="$a 2" ;; cl_iv) a="$a 3" ;;
    cl_nl) a="$a 4" ;; cl_ni) a="$a 5" ;; cl_tp) a="$a 6" ;; cl_cstore) a="$a 7" ;;
    cl_entry|cl_entry_ran|cl_vi_out|cl_vi_list) b="$b 1" ;; cl_ref) b="$b 2" ;; cl_fb5_sel|cl_fb5_state) b="$b 3" ;;
    cl_fb2|cl_fb2_ran) cc="$cc 1" ;; cl_fb2_d0) cc="$cc 2" ;; cl_inst_rc|cl_inst_arg) r=1 ;; cl_resume) k=1 ;; esac
  done
  { [ -z "$a" ] || cl_A "$P" "$S" "$g" "$a"
    [ -z "$b" ] || cl_B "$P" "$S" "$g" "$b"
    [ -z "$cc" ] || cl_C "$P" "$S" "$g" "$cc"
    [ "$r" = 0 ] || cl_R "$P" "$S" "$g"
    [ "$k" = 0 ] || cl_K "$P" "$S" "$g"; } | awk -F= -v cs=" $* " 'index(cs, " " $1 " ") > 0'
}
# the no-seam reference output for cl_vi_out: the same no-entry push under the block with the seam removed, in a
# linked-worktree world as the B world is
cl_wt "$CLW/ns.wb" || broken "could not build the no-seam linked-worktree world"
cl_ns_rc="$(cl_drive "$CLW/noseam.sh" "$CLW/step.sh" "$CLW/ns.wb" ns.B0 step "" "" noentry)"
grep -v '^   done ' "$CLW/out.ns.B0" | sed -E "s|[^ (]*/cl/[A-Za-z0-9._-]+\.wb(\.main)?|WORLD|g" > "$CLW/noseam.f"
[ "$cl_ns_rc" = 0 ] && [ "$(cl_dist "$CLW/out.ns.B0")" = "cl-bad cl-dist cl-ok cl-vs" ] \
  || broken "the no-seam reference push did not run the four fixtures green (rc $cl_ns_rc): $(tail -n 3 "$CLW/out.ns.B0" | tr '\n' ' ')"

CL_GOT="$(cl_score "$CLW/pool.sh" "$CLW/step.sh" base $CL_CELLS)"
if [ "$(printf '%s\n' "$CL_GOT" | grep -c .)" -eq "$(printf '%s\n' "$CL_WANT" | grep -c .)" ]; then
  ok "[cl] the consumer-layout drives emitted every cell ($(printf '%s\n' "$CL_WANT" | grep -c .))"
else
  bad "[cl] the consumer-layout drives emitted $(printf '%s\n' "$CL_GOT" | grep -c .) cells, want $(printf '%s\n' "$CL_WANT" | grep -c .) -- a harness that died reads as clean"
fi
[ "$MATRIX" = 1 ] && { MX_RAN=$((MX_RAN+1)); mx_row cl-baseline "$CL_CELLS" "$(moved_of "$CL_GOT" "$CL_WANT")"; }
clcheck() { # clcheck <label> <cell...>
  local label="$1" k g w badk=""; shift
  for k in "$@"; do
    g="$(printf '%s\n' "$CL_GOT" | sed -n "s/^$k=//p")"; w="$(printf '%s\n' "$CL_WANT" | sed -n "s/^$k=//p")"
    [ "$g" = "$w" ] || badk="$badk $k(got [$g] want [$w])"
  done
  if [ -z "$badk" ]; then ok "[cl] $label"; else bad "[cl] $label --$badk"; fi
}
clcheck "the census records only the candidates it ran green" cl_census
clcheck "(i) a shipping fixture green in the distribution layout and red in the consumer layout FAILs the step as <fx>@consumer" cl_i
clcheck "(ii) a fixture the census recorded green is not re-run and keeps its consumer-layout record" cl_ii
clcheck "(iii) a .dist-only fixture red in the consumer layout is never selected (absent from the installed tree)" cl_iii
clcheck "D2: the step passes install.sh exactly one argument, the tree it announces" cl_arg
clcheck "(vii) a no-change re-push after a red <fx>@consumer re-selects it, and it FAILs again" cl_vii
clcheck "(v) with the fixture's distribution pass in the verdict store, <fx>@consumer still runs and FAILs; the store skip is live for the distribution unit" cl_v cl_v_ctl
clcheck "(iv) a push moving only an installed read-set input (no file of the fixture) selects <fx>@consumer" cl_iv
clcheck "BL-1043: a push moving only a file install.sh never installs selects no <fx>@consumer, beside the distribution unit it runs" cl_nl
clcheck "BL-1043: a push moving install.sh without moving an installed byte selects no <fx>@consumer" cl_ni
clcheck "BL-1043: a push moving only a rendered template selects the reader of the rendered file, not a declared non-reader" cl_tp
clcheck "BL-1043: a consumer-layout pass in the shared store at a unit's placement key skips <fx>@consumer and republishes its record" cl_cstore
clcheck "the tree is built only on the hook's real entry: no PREPUSH_CL_ENTRY, no tree, no install, no @consumer row, every distribution fixture ran" cl_entry cl_entry_ran
clcheck "(vi) switch unset: the output is the no-seam block's, with no @consumer row and no consumer-layout record" cl_vi_out cl_vi_list
clcheck "BL-1043: a push with no consumer-layout record FAILs the step naming the census, runs no unit and writes no record" cl_ref
clcheck "F-B5: the census over a v2 verified record and no consumer keys dir selects every candidate, and the record written is ok, not seeded" cl_fb5_sel cl_fb5_state
clcheck "F-B2: a switch inherited at depth 1 is not honoured; exported at depth 0 it is, and no unit inherits it" cl_fb2 cl_fb2_ran cl_fb2_d0
clcheck "a census stopped mid-run keeps every pass it made, and the next census does not run them again" cl_resume
clcheck "D2 on the REAL scripts/install.sh: a refused install FAILs the step closed, names the step, opens no pool, leaves no tree, and was given the tree" cl_inst_rc cl_inst_arg
# THE DRIVES' OWN OUTPUT IS SCANNED HERE, because the EXIT trap deletes it and none of it reaches this fixture's
# stdout: a tool missing from the sandbox PATH inside the spans prints only there. The control is a line every
# baseline step drive with the entry flag and the stub install must print.
cl_err=0; cl_ctl=0
for _o in "$CLW"/out.base.* "$CLW"/out.ns.* "$CLW"/census.*; do
  [ -f "$_o" ] || continue
  _n="$(grep -cE 'command not found|No such file or directory' "$_o")" || _n=0; cl_err=$((cl_err + _n))
  _n="$(grep -c '^   consumer layout: scripts/install\.sh built ' "$_o")" || _n=0; cl_ctl=$((cl_ctl + _n))
done
if [ "$cl_ctl" -eq 8 ] && [ "$cl_err" -eq 0 ]; then ok "[cl] the baseline drives' own output: 0 'command not found' / 'No such file or directory' lines beside 8 tree-built control lines"
else bad "[cl] the baseline drives' own output: $cl_err 'command not found' / 'No such file or directory' line(s), $cl_ctl tree-built control line(s) (want 0 and 8)"; fi

cl_mutant() { # cl_mutant <name> <pool|step> <sed-expr>; decides and twins come from the header row
  local name="$1" ex="$3" src m P S dec tw cells g moved cond=0 B_cl c
  dec="$(mrow "$name" decides)"; tw="$(mrow "$name" twins)"
  [ -n "$dec" ] || { bad "[cl] MUTANT $name: no MUTANT-MATRIX row in the header"; return 0; }
  dec="${dec//,/ }"; tw="${tw//,/ }"
  if [ "$2" = pool ]; then src="$CLW/pool.sh"; else src="$CLW/step.sh"; fi
  m="$CLW/mut.$name.sh"
  sed "$ex" "$src" > "$m" || { bad "[cl] MUTANT $name: sed DID NOT APPLY"; return 0; }
  if cmp -s "$src" "$m"; then bad "[cl] MUTANT $name: the edit matched nothing, so it is not a mutant"; return 0; fi
  P="$CLW/pool.sh"; S="$CLW/step.sh"; [ "$2" = pool ] && P="$m" || S="$m"
  B_cl="$(for c in $dec $tw; do
    [ "$(printf '%s\n' "$CL_GOT" | sed -n "s/^$c=//p")" = "$(printf '%s\n' "$CL_WANT" | sed -n "s/^$c=//p")" ] || { echo 0; exit 0; }
  done; echo 1)"
  if [ "$MATRIX" = 1 ]; then cells="$CL_CELLS"; MX_RAN=$((MX_RAN + $(printf '%s\n' $cells | grep -c .) - $(printf '%s\n' $dec $tw | grep -c .)))
  else cells="$dec $tw"; fi
  g="$(cl_score "$P" "$S" "m-$name" $cells)"
  moved="$(moved_of "$g" "$CL_WANT")"
  [ "$MATRIX" = 1 ] && mx_row "$name" "$cells" "$moved"
  same_set "$moved" "$dec" && cond=1
  finish_mutant "$([ "$B_cl" = 1 ] && echo 1 || echo 0)" "$name" "$cond" \
    "[cl] MUTANT $name kill confirmed: decides [$dec] moved, twin [$tw] stayed green" \
    "[cl] MUTANT $name moved [${moved% }], want [$dec] (twin [$tw])"
}
cl_mutant cl-dist-keyed      pool 's|^  ( cd "\$cl_tree" \|\| exit 1$|  ( :|'
cl_mutant cl-select-all      pool 's|^    awk -F'"'"'\\t'"'"' '"'"'\$2 == "run" { print \$1 }'"'"' "\$c/\.kdec" > "\$out/\.cl\.sel"$|    cp "$out/.cl.all" "$out/.cl.sel"|'
cl_mutant cl-stamp-raw       pool 's|^    if \[ -f \.claude/\.ai-dlc-version \]; then$|    if false; then|'
cl_mutant cl-no-refusal      pool 's|^  elif \[ "\$2" != census \] && ! cl_any_record "\$kd" |  elif false \&\& ! cl_any_record "$kd" |'
cl_mutant cl-store-dist-project pool 's|^    KEYS_DIR="\$kd"; FXROOT=|    readset_vs_store() { printf "%s" "$p"; }; KEYS_DIR="$kd"; FXROOT=|'
cl_mutant cl-publish-late     pool 's|^  \[ -n "\$kd" \] && \[ -s "\$1/\.cl/\.k/\$2" \] \|\| return 0$|  return 0|'
cl_mutant cl-publish-worker   pool 's|; \. "\$AI_DLC_FX_OUT/\.cl\.pub" && cl_publish "\$AI_DLC_FX_OUT" "\$cf"$||'
cl_mutant cl-record-on-red   pool 's|^    \[ "\$(cat "\$out/\$b@consumer" 2>/dev/null)" = ok \] \|\| rm -f "\$c/\.k/\$b"$|    printf ok > "$c/$b"|'
cl_mutant cl-depth1-honoured pool 's|^  if \[ "\$POOL_DEPTH_IN" -eq 0 \]; then cl_tree="\${AI_DLC_FX_CL_TREE:-}"; fi$|  cl_tree="${AI_DLC_FX_CL_TREE:-}"|'
cl_mutant cl-switch-on       pool 's|cl_tree="\${AI_DLC_FX_CL_TREE:-}"; fi$|cl_tree="${AI_DLC_FX_CL_TREE:-no-tree}"; fi|'
cl_mutant cl-no-entry        step 's|^  if \[ "\$POOL_DEPTH_IN" -eq 0 \] && \[ "\${PREPUSH_CL_ENTRY:-}" = 1 \]; then$|  if [ "$POOL_DEPTH_IN" -eq 0 ]; then|'
cl_mutant cl-fail-open       step '/^      eval "rm -rf -- \$cl_q"; trap - EXIT INT TERM HUP$/{n;s/^      return 1$/      :/;}'
cl_mutant cl-no-arg          step 's|bash scripts/install\.sh "\$cl_top" )|bash scripts/install.sh )|'

# ------------------------------------------------- BL-924's RECEIPT, against THIS run.sh ---------
# The receipt builds ONE scratch copy of this file, forces the two schedules BL-924 names (fx6 writes its flight
# file only after the barrier poller has counted or looked again after a look at five, read off barrier.look; the
# first step of fix_hlink, fix_fifo and fix_silent records `unit hold` and waits until the fixture has recorded that
# drive or written a new look line for it in pn.rej), and prints a `CELL <name> PASS|FAIL` line per cell. Its copy
# ends at the watcher mutant loop, so it never reaches this arm. Exit 9 is a refusal to measure: FIXTURE BROKEN.
# NECESSITY: the forced schedules are states no unforced drive above reaches, so no cheaper call shows them.
RCPT924="$(dirname "$0")/receipt-bl924.sh"
[ -f "$RCPT924" ] || { echo "FIXTURE ERROR: missing $RCPT924" >&2; exit 2; }
bash "$RCPT924" "$0" > "$WORK/rcpt924.out" 2> "$WORK/rcpt924.err"; rcpt924_rc=$?
if [ "$rcpt924_rc" = 0 ] && [ "$(grep -c '^CELL [a-z_0-9-]* PASS' "$WORK/rcpt924.out")" = 5 ]; then
  ok "[$T] BL-924 receipt: under the forced late-flight-file and late-writer schedules, $(grep '^CELL barrier ' "$WORK/rcpt924.out" | cut -d' ' -f4-9); pn_hlink, pn_fifo and pn_silent REFUSED; not-exported moves only its own decides"
elif [ "$rcpt924_rc" = 9 ]; then
  broken "receipt-bl924.sh refused to measure: $(sed -n 1p "$WORK/rcpt924.err")"
else
  bad "[$T] BL-924 receipt exited $rcpt924_rc against this run.sh: $(grep '^CELL [a-z_0-9-]* FAIL' "$WORK/rcpt924.out" | cut -d' ' -f2 | tr '\n' ' ')"
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
