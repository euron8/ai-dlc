#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# Drives the pre-push suite's per-fixture READ-SET SKIP.
#
# WHAT IS BEING PROVEN, and why each arm has to exist. The skip decides which fixtures do not
# run. Its failure mode is not a slow suite -- it is a SILENTLY SHORT one: a fixture that never
# ran reports nothing and the summary still says green. So every arm below asserts a POSITIVE
# outcome (this exact set was selected) rather than the absence of an old failure.
#
# THE DEFECT THIS FIXTURE EXISTS BECAUSE OF. During development the selection injected each
# changed path's synthesised PARENT DIRECTORY into the `.changed` set, which then failed the
# "changed path no fixture reads" test -- so the skip fell back to the full suite in EVERY
# scenario while announcing it in wording that read like caution. It was inert, green, and
# indistinguishable from a working skip by any test asserting "nothing regressed". Arm 2 is
# the one that catches it, and it catches it only because it asserts a subset was selected.
set -u

# A consumer that tunes AI_DLC_FIXTURE_JOBS or AI_DLC_FIXTURE_NO_SKIP in settings.json would
# otherwise have that value decide these arms, and the fixture would be testing the CONFIG
# rather than the CODE. Arms needing a value set it on their own command.
HR_ROOT_IN="${AI_DLC_PROJECT_ROOT:-}"   # read BEFORE the scrub below: the hermetic runner exports it as the sandbox root

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# NO WORLD HERE IS DECIDED BY THE POOL'S NO-PROGRESS WATCHDOG. Every run_fixtures this file drives (the ck, tk,
# trace and report worlds) runs seeded units whose run.sh is a printf and an exit, through the real pool_run, whose
# watcher refuses a unit after POOL_STALL consecutive one-second polls with no new bytes. The scrub above leaves the
# default, 600, so a unit left unreaped for 600 polls was REFUSED, went unrecorded, and re-ran on the next push --
# measured at load ~119, a checksum-key world read p2=delta|0 beside `REFUSED delta` in its push 1.
# A test whose verdict moves with load is a defect, so the window is pinned to the block's own ceiling (99999 is the
# largest value :527 of the hook accepts; a six-digit value is rejected to stderr, which these drives discard, and
# falls back to 600). ck_push and tk_push record the value their block computed, and the (no-refusal) arm after the
# tk worlds asserts every push saw this pin and none rendered a REFUSED verdict. The watchdog itself is tested by
# core/fixtures/consumer-suite-pool (worlds p, s, w, t, ST=3) and core/fixtures/prepush-pool-depth (PN_STALL).
AI_DLC_POOL_STALL=99999; export AI_DLC_POOL_STALL

RS_LIB="$(cd "$(dirname "$0")/../lib" && pwd)"
. "$RS_LIB/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "${NAME:-readset-skip}: FIXTURE BROKEN" >&2; exit 2; }
. "$RS_LIB/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
. "$RS_LIB/pool-span.sh" || { echo "FIXTURE BROKEN: cannot source lib/pool-span.sh" >&2; exit 2; }
# ---------------------------------------------------------------------------- shards ----
# THIS FILE IS FOUR SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT
# BOUNDARY. Every section below is a UNIT guarded by `if sg <unit>; then ... fi`; `--group <x>` runs
# the units dealt to shard <x>. The three siblings `readset-skip-{b,c,d}/run.sh` are one-line drivers
# that `exec bash` this file with their group (the shape the fold-architect-ledger-join battery used), so the
# pre-push pool can start each on its own and the suite's makespan stops tracking one 4600-line
# directory. No `--group` runs shard 'a', so `bash core/fixtures/readset-skip/run.sh` is shard a.
#
# THE SEED, THE HOOK AND THE SANDBOX PROBE ARE NOT UNITS: every shard pays them, because a shard that
# skipped them would score its worlds against a harness that never ran.
#
# THE COVERAGE JOIN runs in EVERY shard before anything else: the declared units are DERIVED from this
# file's own `if sg <unit>; then` lines, the dealt lists must be disjoint and their union must equal
# the declared set exactly, so no unit can fall out of every shard, and every declared shard must have
# a driver directory. The join proves it can fire first, on a seeded duplicate and a seeded omission.
#   a  arms ign man merge slot   pool selection worlds, the manifest, the deriver's merge and control, the trace-window slot (slot-world.sh)
#   b  loc hr tk dg              local map and trace report, hash rows, tool keys, committed digests
#   c  tracer rc                 trace tree, lossy window, --tracer both and its stub worlds, --reconcile
#   d  ckw vs                    shared verdict store (vs), checksum-key worlds (fourteen against the first hook, one wiring world on the second -- the only hook-2 world of the whole fixture)
# The per-fixture checksum-key section (contract k1) is the unit ckw, its worlds.
# `rc` rides with `tracer` because it drives the stub `sandbox-exec` and deriver copy that `tracer` builds.
# IN PROCESS. The deriver carries a BASH_SOURCE guard over its top level (rs_main); hermetic-run.sh and the decision
# drivers are plain scripts. Every world that ran one as `env ... bash <script>` now runs it through inproc (defined beside
# stub_reap): a subshell stripped to what a new process would inherit, the script sourced, its main called. The
# tracer unit's EQUIVALENCE cell drives two worlds both ways and compares output, set and exit. STILL PROCESSES, each
# because its decision IS process identity: the live-trace drivers (RT, CT, FX, FW: readset_live_trace names its trace
# root and judges its ceiling by `$$` and process groups), the lock start-time judge (PJ: `ps -o lstart= -p $$`), the
# derivers slot-world starts (the slot's holder is the deriver's `$$`), the (args) self-invocations, and the one
# end-to-end CLI run per outcome in the equivalence cell. Every start of the deriver is a declared cell (BL-879):
# slot-world's are `e2e` rows of readset-skip/cells.decl, the equivalence cell's two runs are `cli` rows of
# readset-skip-c/cells.decl. The stub derivers the launcher worlds hand to the hook live at the consumer layout path
# (LT_DVP, beside seed_lt), so the hook's own launches of them are no start of the deriver.
SHARDS="a b c d"
UNITS_a="arms ign man merge slot"
UNITS_b="loc hr tk dg"
UNITS_c="tracer rc"
UNITS_d="ckw vs"
GROUP=a
while [ $# -gt 0 ]; do
  case "$1" in
    --group) GROUP="${2:-}"
      [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
      shift; shift ;;
    *) echo "FIXTURE ERROR: unknown argument '$1' (usage: [--group <shard>])" >&2; exit 2 ;;
  esac
done
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
NAME="readset-skip"; [ "$GROUP" = a ] || NAME="readset-skip-$GROUP"
[ -n "$MINE" ] || broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
SELF="$0"
[ -f "$SELF" ] || broken "cannot read $SELF for the coverage join"
# PREAMBLE SELF-CHECK of the argument parser, run before anything is built: an unknown flag refuses with exit 2 and a
# message naming the cause.
PRE_ARMS=0
_ru="$(bash "$SELF" --no-such-flag 2>&1 >/dev/null)"; _rcu=$?
PRE_ARMS=$((PRE_ARMS+1))
if [ "$_rcu" = 2 ] && case "$_ru" in *"unknown argument '--no-such-flag'"*) true ;; *) false ;; esac; then ok "(args) an unknown flag refuses with exit 2 and names itself"
else bad "(args) an unknown flag must exit 2 naming it; got rc=$_rcu '$_ru'"; fi
HERE="$(cd "$(dirname "$SELF")" && pwd)"
partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/readset-skip-join.XXXXXX")" || broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$JW/pdup"; printf '%s\n' u1 u3 > "$JW/pmiss"; printf '%s\n' u3 u1 u2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  rm -rf "$JW"; broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
sed -n 's/^[[:space:]]*if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$SELF" > "$JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  rm -rf "$JW"; broken "$ndecl unit guards derived from $SELF ($ndupdecl declared twice)"
fi
if ! _why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  rm -rf "$JW"; broken "the shard partition does not cover the guarded units exactly -- $_why"
fi
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$HERE/../readset-skip-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    rm -rf "$JW"; broken "shard '$_s' is declared but $_drv does not drive it"
  fi
done
rm -rf "$JW"
echo "  [J0] coverage join: $ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"

echo "$NAME:"

# BOTH LAYOUTS, NAMED RATHER THAN DERIVED FROM ONE ANOTHER (I33). install.sh splits what
# shares a parent here, so walking up from one file to find the other is the thing that
# invariant fails the build on.
# THE ROOT COMES FROM AI_DLC_PROJECT_ROOT FIRST (read before the scrub above): the hermetic runner
# runs this file in a sandbox that is NOT a git repository, so `git rev-parse --show-toplevel` is
# the fallback for a plain pool run. An override is accepted only when this script lives under it.
ROOT=""
if [ -n "$HR_ROOT_IN" ] && [ -d "$HR_ROOT_IN" ]; then
  _hr="$(cd "$HR_ROOT_IN" && pwd -P)"; _hs="$(cd "$(dirname "$0")" && pwd -P)"
  case "$_hs" in "$_hr"/*) ROOT="$_hr" ;; esac
fi
[ -n "$ROOT" ] || ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || broken "not in a git repo and no AI_DLC_PROJECT_ROOT above this script"
HOOK=""
for c in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$c" ] && { HOOK="$c"; break; }
done
[ -n "$HOOK" ] || broken "no pre-push hook found in either layout"
# PRINT THE RESOLVED HOOK. Every world below runs THIS file's pool block; a run against the other
# layout's copy would score a different program.
echo "  hook: ${HOOK#"$ROOT"/}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/readset-skip.XXXXXX")" || broken "mktemp failed"
# A PRIVATE TRACE-WINDOW SLOT for every deriver copy this fixture drives (exported after the AI_DLC_ scrub
# above), so none of its stub worlds waits on, or holds, the box's real per-uid slot.
export AI_DLC_READSET_SLOT="$WORK/window-slot"
# THE LOCK PID FOR THE START-TIME WORLDS (BL-463) is a process of its own, started here, never `$$`.
# A lock naming `$$` shares its pid AND its start time with every judge the fixture forks, so a
# reader or helper that reads the start of `$$` instead of the lock's pid reads the right answer for
# the wrong reason and survives. Its fds are closed so it cannot hold the runner's output pipe open.
# It is killed by its literal recorded pid on exit, never found through the process table.
# `tail -f /dev/null`, NOT `sleep 600`: it lives until the exit trap kills it, so a run longer than any
# fixed bound (a loaded box) cannot outlive its lock pid.
tail -f /dev/null </dev/null >/dev/null 2>&1 &
LOCKPID=$!
# disowned so the exit trap's kill does not print a job-termination line over the verdict line.
disown "$LOCKPID" 2>/dev/null || :
LOCK_T0="$(date +%s)"
trap 'kill '"$LOCKPID"' 2>/dev/null; rm -rf "$WORK"' EXIT

# EVERY WAIT ON THE SUBJECT ENDS ON AN EVENT, NEVER ON A WALL CLOCK. The live-trace worlds used to
# poll for a fixed number of ticks and then read whatever state they found, so on a loaded box a
# correct launcher read as a lock HELD, a row MISSING or a sleep LEAKED -- the bound was the verdict.
# aw_wait ends on one of three things, each binary:
#   0  the event happened (a file appeared, a lock dir went, a pid or a group is gone)
#   1  the party that OWES the event is dead and the event did not happen -- the state is final and
#      the caller judges it as it stands. The owner is a pid the subject or a stub RECORDED (the status
#      file's `pid`, a stub's own `$$`), never the lock's line 1, which can name a
#      live process that never releases anything.
#   2  FINAL: the caller's final predicate holds -- a fact about KERNEL STATE that no amount of waiting
#      changes, never a count of polls: aw_group_settled (every live member of a group is blocked with
#      no signal pending, so the group will never empty on its own -- the leak itself) or aw_overslept (the
#      watchdog's own timer, blocked, has outlived the promised ceiling by its kernel-kept elapsed time).
# NO WAIT HERE ENDS ON A WINDOW OF POLLS OR ON ELAPSED TIME (BL-868). The no-progress net this replaced
# read "nothing moved for 100 polls" as a stall, so a loaded box read a dying member as a survivor and
# a slow trace as a hang, and refused the run. A process that was signalled is runnable, exiting or
# carries the signal pending -- never blocked with nothing pending -- so the predicates cannot fire on
# one that is still ending, at any load. A wait whose subject never reaches either state blocks until
# the gate's own watchdog takes the run, which is a hang to read, never a verdict.
AW_LIB="$WORK/aw.sh"; AW_STALL_LOG="$WORK/aw.stall"
export AW_LIB AW_STALL_LOG
cat > "$AW_LIB" <<'AW'
# Every local is `_aw_`-prefixed: the three commands are eval'd in the CALLER's scope, and the drivers'
# own names (`o`, `lk`, `tp`, `pid`) must not be shadowed while they are read.
aw_wait() { # <event cmd> <owner cmd, may be empty> <final cmd, may be empty>; 0 event, 1 owner gone, 2 final
  local _aw_ev="$1" _aw_ow="$2" _aw_fi="$3" _aw_pid
  while :; do
    eval "$_aw_ev" && return 0
    if [ -n "$_aw_ow" ]; then
      _aw_pid="$(eval "$_aw_ow")"
      case "$_aw_pid" in
        ''|*[!0-9]*) ;;
        *) if ! kill -0 "$_aw_pid" 2>/dev/null; then eval "$_aw_ev" && return 0; return 1; fi ;;
      esac
    fi
    if [ -n "$_aw_fi" ] && eval "$_aw_fi"; then eval "$_aw_ev" && return 0; return 2; fi
    ${AW_SLEEP:-sleep} 0.1
  done
}
# aw_blocked <pid>: 0 when <pid> is alive, BLOCKED (state S, I or T) and has NO signal pending -- a process
# nothing is going to end: it will not run until something signals it. A process that was signalled is R, E or Z
# with the signal taken, or still shows it pending, and reads 1, as does a gone one. A pid alive whose state `ps`
# will not give (a sandbox refuses the setuid /bin/ps) is a refusal in AW_STALL_LOG and reads 0, so the wait ends.
aw_blocked() {
  local _ab_st _ab_pd
  kill -0 "$1" 2>/dev/null || return 1
  _ab_st="$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')"; _ab_pd="$(ps -o pending= -p "$1" 2>/dev/null | tr -d ' ')"
  if [ -z "$_ab_st" ]; then
    kill -0 "$1" 2>/dev/null || return 1
    printf 'aw_blocked: ps gives no state for live pid %s, so whether it will end cannot be read\n' "$1" >> "$AW_STALL_LOG"; return 0
  fi
  case "$_ab_st" in S*|I*|T*) ;; *) return 1 ;; esac
  case "$_ab_pd" in ''|*[!0]*) return 1 ;; esac
  return 0
}
# aw_group_settled <pgid>: 0 when the group has a live member and EVERY live member is aw_blocked -- the group
# will never empty on its own. THIS REPLACES THE NO-PROGRESS NET, which read "nothing moved for AW_STALL polls"
# and so read a dying member on a loaded box as a survivor. A member that was signalled is never blocked with
# nothing pending, so a group that is emptying never settles, at any load; one that a missing kill left behind does.
aw_group_settled() {
  local _ag_l _ag_p _ag_n=0
  case "$1" in ''|0|*[!0-9]*) return 1 ;; esac
  _ag_l="$(pgrep -g "$1" 2>/dev/null)"
  for _ag_p in $_ag_l; do
    kill -0 "$_ag_p" 2>/dev/null || continue
    aw_blocked "$_ag_p" || return 1
    _ag_n=$((_ag_n + 1))
  done
  [ "$_ag_n" -gt 0 ]
}
# aw_overslept <pgid> <seconds>: 0 when the group holds a `sl``eep` that is aw_blocked and has run longer than
# <seconds> by its own kernel-kept elapsed time -- a timer longer than the promise. A timer that has run out is
# runnable (R) or gone, never blocked, so no load makes a correct ceiling read here.
aw_overslept() {
  local _ao_p _ao_c _ao_e
  case "$1" in ''|0|*[!0-9]*) return 1 ;; esac
  for _ao_p in $(pgrep -g "$1" 2>/dev/null); do
    _ao_c="$(ps -o comm= -p "$_ao_p" 2>/dev/null)"; _ao_c="${_ao_c##*/}"
    [ "$_ao_c" = "sl""eep" ] || continue
    aw_blocked "$_ao_p" || continue
    _ao_e="$(ps -o etime= -p "$_ao_p" 2>/dev/null | tr -d ' ' | awk -F'[-:]' '{ n = NF; t = $n + $(n - 1) * 60; if (n >= 3) t += $(n - 2) * 3600; if (n >= 4) t += $(n - 3) * 86400; print t }')"
    case "$_ao_e" in ''|*[!0-9]*) continue ;; esac
    [ "$_ao_e" -gt "$2" ] && return 0
  done
  return 1
}
aw_status_pid() { sed -n 's/^pid //p' "$1" 2>/dev/null; } # the trace subshell's pid, as IT wrote it
aw_stalled() { printf '%s\n' "$1" >> "$AW_STALL_LOG"; } # <subject neither exited nor advanced <marker>>
AW
. "$AW_LIB" || broken "could not load the wait library $AW_LIB"
aw_gate() { # refuse, in the fixture's own shell, on any no-progress net that fired inside a driver
  [ -s "$AW_STALL_LOG" ] || return 0
  broken "$(head -1 "$AW_STALL_LOG") ($(grep -c '' "$AW_STALL_LOG") no-progress refusal(s) in $AW_STALL_LOG)"
}

# STUB_STREAM_BEGIN
# THE STUB STREAM'S DELIVERY, sourced by every stub `log stream` and stub `sandbox-exec` this fixture and
# slot-world.sh write. A stream stub REGISTERS (ss_register) the file its stdout is -- the deriver's raw
# capture -- under <STUB_FEED>.streams/<its pid>, and then blocks. A stub sandbox-exec writes each report
# line STRAIGHT INTO every live registered capture (ss_emit) before it returns, and a read of a deriver's
# start or end marker first waits (ss_wait) until a stream of THAT deriver's trace root is registered. So
# the line the deriver's liveness, settle and flush polls look for is in the capture when the `sandboxed
# cat` returns, and each of those polls ends on its FIRST iteration at any load. A `tail -f` of the feed
# delivered it asynchronously, and the iteration count -- one sandbox-exec start each -- followed load.
# Delivery is otherwise what the tail gave: every live stream gets every line written after it registered.
# A `deaf` registration satisfies the wait and receives nothing: a stream that never delivers.
# THE WAIT IS ON A CONDITION AND HAS NO BOUND (BL-868): it ends when a stream of that root registers. A stream that
# never registers blocks the stub until the gate's own watchdog takes the run -- a hang to read, never a verdict
# and never a count of polls or a clock.
ss_register() { # <live|deaf>: record this stream ($$) and the file its stdout is
  local d="$STUB_FEED.streams" out="" f m p
  mkdir -p "$d" 2>/dev/null || return 1
  { out="$(python3 -c 'import fcntl;b=fcntl.fcntl(3,fcntl.F_GETPATH,bytes(1024));print(b.split(b"\0")[0].decode())' 2>/dev/null)"; } 3>&1
  [ -n "$out" ] || return 1
  for f in "$d"/[0-9]*; do
    [ -f "$f" ] || continue
    m=""; p=""; { read -r m p; } < "$f" 2>/dev/null
    [ "$p" = "$out" ] && rm -f "$f"
  done
  printf '%s %s\n' "$1" "$out" > "$d/.$$" && mv -f "$d/.$$" "$d/$$"
}
ss_emit() { # <text>: appended to the feed and to every live stream's capture, before this returns
  local d="$STUB_FEED.streams" f m p
  printf '%s\n' "$1" >> "$STUB_FEED"
  for f in "$d"/[0-9]*; do
    [ -f "$f" ] || continue
    kill -0 "${f##*/}" 2>/dev/null || continue
    m=""; p=""; { read -r m p; } < "$f" 2>/dev/null
    [ "$m" = live ] && [ -n "$p" ] && printf '%s\n' "$1" >> "$p"
  done
  return 0
}
ss_wait() { # <path read through the profile>: a marker read waits for its own window's stream
  local a="$1" root d="$STUB_FEED.streams" f m p i=0 got="" c="" want
  case "$a" in */m/.readset-sentinel|*/m/.readset-end) root="${a%/m/.readset-*}" ;; *) return 0 ;; esac
  # KEYED ON THE EXACT CAPTURE: the deriver writes `sentinel-<fx>`, `end-<fx>` or `liveness` into the marker
  # before it reads it, and that window's capture is <root>/w/<fx>.raw (liveness.raw). A registration of any
  # other window -- a stale one of this root, or one whose pid was reused -- never satisfies the wait.
  { read -r c; } < "$a" 2>/dev/null
  case "$c" in sentinel-?*) c="${c#sentinel-}" ;; end-?*) c="${c#end-}" ;; liveness) ;; *) c="" ;; esac
  want="$root/w/$c.raw"
  while :; do
    for f in "$d"/[0-9]*; do
      [ -f "$f" ] || continue
      kill -0 "${f##*/}" 2>/dev/null || continue
      m=""; p=""; { read -r m p; } < "$f" 2>/dev/null
      if [ -n "$c" ]; then [ "$p" = "$want" ] && { got="$m $p"; break; }
      else case "$p" in "$root"/w/*) got="$m $p"; break ;; esac; fi
    done
    [ -n "$got" ] && break
    /bin/sleep 0.1
  done
  # `--tracer both` (the stub world that sets STUB_FS) settles on the fs_usage capture as well: a sentinel
  # read waits for the stub fs_usage's sentinel line there, so that half of the settle also holds on the
  # first iteration. Keyed on STUB_FS, not on the capture existing, which its pipeline may not have opened yet.
  case "$a:$got" in
    */.readset-sentinel:"live "*)
      p="${got#live }"; i=0
      if [ -n "${STUB_FS:-}" ]; then
        until grep -q readset-sentinel "$p.fsu" 2>/dev/null; do
          /bin/sleep 0.1
        done
      fi ;;
  esac
  return 0
}
# STUB_STREAM_END
STUB_STREAM_LIB="$WORK/stub-stream.sh"; export STUB_STREAM_LIB
sed -n '/^# STUB_STREAM_BEGIN$/,/^# STUB_STREAM_END$/p' "$SELF" > "$STUB_STREAM_LIB"
grep -q '^ss_wait() ' "$STUB_STREAM_LIB" || broken "no STUB_STREAM span extracted from $SELF into $STUB_STREAM_LIB"

# INSIDE A SANDBOX: ONE DETECTOR. The read-set deriver's `--tracer sandbox` runs this fixture under
# `sandbox-exec`, and two things are refused there: `log stream` answers "Cannot run while sandboxed",
# and the setuid `/bin/ps` is not exec'd at all. The first is the POSITIVE detection; it is probed
# once, here, and read by the start-time worlds (ps_sandbox_skip).
# A `ps` that merely FAILS is never a reason to skip: outside a sandbox it is still `broken`, and
# inside one ps_sandbox_skip refuses unless `ps` really fails there, so a detector that claims a
# sandbox where `ps` works cannot hide the worlds it gates.
IN_SANDBOX=0
if [ -x /usr/bin/log ]; then
  /usr/bin/log stream --style compact --timeout 1s --predicate 'sender == "readset-skip-probe"' >/dev/null 2>"$WORK/ls.err"
  grep -q 'Cannot run while sandboxed' "$WORK/ls.err" && IN_SANDBOX=1
fi
ps_sandbox_skip() { # <group>: 0 (skip it, SKIP printed) inside a sandbox where ps is refused; 1 otherwise
  [ "$IN_SANDBOX" = 1 ] || return 1
  if ps -o lstart= -p "$$" >/dev/null 2>&1; then
    broken "the sandbox detector says this run is sandboxed, yet ps -o lstart= -p \$\$ works -- refusing to skip $1"
  fi
  printf '  SKIP  %s: inside a sandbox (log stream answers "Cannot run while sandboxed"), where the setuid /bin/ps is refused\n' "$1"
  return 0
}

# The block is extracted rather than the whole hook sourced: the hook runs a full gate on
# source. I66 holds the two copies of this block to one program, so proving it here proves it
# for the consumer's hook as well.
# THE WORLDS KEEP THEIR RECORDS UNDER THEIR OWN GIT DIR. The hook resolves KEYS_DIR and the verified record into the
# shared verdict store base (its RECORD_HOME span); every world here is a copy of one template, so they would share one
# root commit and so one set of records. Each extracted block is therefore followed by rs_rec_pin's three assignments,
# which put the records back under the world's own GITDIR: this fixture's subject is the skip decided from a record,
# not where the record lives (scripts/validate-verdict-identity.sh W1 holds the hook's own sites).
rs_rec_pin() { printf '%s\n' 'KEYS_DIR="$GITDIR/ai-dlc-fixture-keys"; VERIFIED_RECORD="$GITDIR/ai-dlc-fixture-verified"; VERIFIED_FORMAT="$VERIFIED_RECORD.format"'; }
POOL="$WORK/pool.sh"
pool_span "$HOOK" "$POOL" FIXTURE_POOL && rs_rec_pin >> "$POOL"
[ -s "$POOL" ] || broken "extracted an empty FIXTURE_POOL block from $HOOK"
grep -q 'apply_readset_skip' "$POOL" || broken "the extracted block carries no apply_readset_skip"
# THE RESOLVED BLOCK'S FIXTURE ROOT -- `core/fixtures` in the distribution's hook, `tests/fixtures` in
# the consumer's, which an installed tree resolves first. Read once here, so every world keyed on a
# fixture's own run.sh keys it where this hook will look it up.
FXROOT="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$POOL" | sort -u)"
[ "$(printf '%s\n' "$FXROOT" | grep -c .)" -eq 1 ] || broken "read '$FXROOT' as the pool block's fixture root; need exactly one"
# BOTH HOOKS ARE CONSUMED, AND IN THE DISTRIBUTION BOTH MUST BE PRESENT. HOOK above is whichever came
# first, so a run with the other copy dropped would pass on one hook alone; the sentinel is printed for
# each hook whose pool block is read and carries apply_readset_skip, which is what the hermetic runner's
# REQUIRED declaration for core/git-hooks/pre-push checks. A consumer holds one installed copy.
HK_N=0
for _hk in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$_hk" ] || continue
  pool_span "$_hk" "$WORK/hk.pool" FIXTURE_POOL
  grep -q 'apply_readset_skip' "$WORK/hk.pool" || broken "${_hk#"$ROOT"/} carries no FIXTURE_POOL block with apply_readset_skip"
  HK_N=$((HK_N+1))
  echo "HERMETIC-CONSUMED ${_hk#"$ROOT"/}"
done
if [ -d "$ROOT/core/scripts" ] && [ "$HK_N" -ne 2 ]; then
  broken "the distribution layout holds $HK_N of its two pre-push hooks; every world below is run against both"
fi

# ---------------------------------------------------------------------------- seed ----
# alpha reads a.sh and shared.sh; beta reads b.sh and shared.sh; gamma is DELIBERATELY absent
# from the map, which is the fail-closed subject.
seed() {
  local t="$1"
  mkdir -p "$t/core/fixtures/alpha" "$t/core/fixtures/beta" "$t/core/fixtures/gamma" "$t/src"
  local f
  for f in alpha beta gamma; do printf 'exit 0\n' > "$t/core/fixtures/$f/run.sh"; done
  # beta also names the src/ DIRECTORY, the way a fixture that globs a directory records it.
  # Without a directory entry anywhere in the map, `.match` and `.changed` are equivalent and
  # an injected parent directory would be unobservable.
  printf 'alpha\tsrc/a.sh\nalpha\tsrc/shared.sh\nbeta\tsrc/b.sh\nbeta\tsrc/shared.sh\nbeta\tsrc\n' \
    > "$t/.ai-dlc-fixture-readsets.tsv"
  for f in a b shared orphan; do printf 'v1\n' > "$t/src/$f.sh"; done
  ( cd "$t" && git init -q . && git add -A && \
    git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1 || return 1
}

# Run the selection in a seeded tree and echo the selected fixture names, space separated.
# SCRATCH LIVES OUTSIDE THE TREE. With it inside, `git ls-files` sweeps it into the manifest
# and the orphan branch fires on the harness's own files -- measured, it made all four
# development cases report "running all" and proved nothing.
select_in() {
  local t="$1" scratch; shift
  scratch="$(mktemp -d "$WORK/s.XXXXXX")" || return 1
  ( cd "$t" || exit 1
    # Only the launcher arms turn the live trace on, and they say so on their own drive.
    export AI_DLC_READSET_LIVE_TRACE=0
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$POOL" 2>/dev/null
    for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$scratch/list"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_manifest "$scratch"
    # SEEDED AS THE HOOK WRITES IT: the record AND its `v2` format stamp. An arm modelling a
    # record an OLDER hook wrote removes the stamp in its own mutation.
    cp "$scratch/.now" .git/ai-dlc-fixture-verified 2>/dev/null && printf 'v2\n' > .git/ai-dlc-fixture-verified.format
    eval "$*"                                   # the caller's mutation of the tree
    cp "$scratch/list" "$scratch/l"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    apply_readset_skip "$scratch/l" "$scratch" > "$scratch/msg" 2>&1
    sed 's|core/fixtures/||g; s|/$||' "$scratch/l" | tr '\n' ' '
    printf '\n---MSG---\n'
    cat "$scratch/msg"
    # THE DECISION, NOT THE PROSE. The whole-suite skip leaves the fixture list UNTOUCHED --
    # it is carried by a flag, because an empty list is a hard FAIL in run_fixtures by design.
    # So "skipped everything" and "ran everything" produce the SAME selected set, and an arm
    # scoring only on that set cannot tell them apart. Report the flag.
    printf '\n---FLAG---\n'
    printf '%s\n' "${READSET_NO_CHANGE:-0}"
  )
}
sel_of()  { printf '%s' "$1" | sed -n '1p' | tr -s ' ' | sed 's/ $//'; }
msg_of()  { printf '%s' "$1" | sed -n '/---MSG---/,/---FLAG---/p' | tail -n +2 | sed '$d'; }
flag_of() { printf '%s' "$1" | sed -n '/---FLAG---/,$p' | tail -n +2 | tr -d '[:space:]'; }

# F2-B HELPERS
# ONE SEED PER DISTINCT INPUT, COPIED PER WORLD. Every world below was a fresh `git init` plus one or more
# commits of byte-identical content; the seed functions take no input but their arguments, so the repo
# they build is the same every time. f2b_world runs <seed fn> ONCE per (fn, args) into a template under
# $WORK -- outside every world, so no world's manifest can list it -- and every later world is a
# `cp -Rp` of it, which the manifest battery's own drive() has always done with its TPL. Each world
# still mutates only its own copy. The `.ok` marker sits beside the template, never inside it, and is
# written only after the seed returned 0, so a failed seed is re-run rather than copied.
f2b_world() { # <seed fn> <dst> [seed args]
  local fn="$1" dst="$2" k; shift 2
  k="$WORK/f2b.tpl.$fn${1:+.$1}"
  if [ ! -f "$k.ok" ]; then "$fn" "$k" "$@" && : > "$k.ok" || return 1; fi
  # A world path may name parents the seed used to create with its own `mkdir -p` (rt_drive's carries the
  # pool copy's path); `cp -Rp` creates none, so they are made here. The world itself must not exist yet.
  [ ! -e "$dst" ] || return 1
  mkdir -p "$(dirname "$dst")" && cp -Rp "$k" "$dst"
}

# inproc [-i] [-u VAR]... [VAR=val]... -- <script> [args]: run <script> IN PROCESS, in the CALLER'S subshell, the way
# `env [-i] [-u VAR]... [VAR=val]... bash <script> [args]` runs it in a new process. Call it inside `( ... )`: it
# replaces the subshell's state. A new bash inherits only EXPORTED variables, no function and no trap of its parent,
# so this unsets every non-exported variable the fixture set (bash's own specials kept), every function, and the
# subshell's traps; `-i` also unsets every exported one but HOME and PATH unless re-set. Then the script is SOURCED:
# a program behind a BASH_SOURCE guard (the deriver) loads its definitions and returns at the guard, and its main
# (rs_main) is called with the args; a plain script (hermetic-run.sh, a decision driver) simply runs. `exit` in either
# ends this subshell with the status a process would have returned. Its output, files and exit are compared with the
# CLI's in the equivalence cell beside the tracer unit, which is what makes this a stand-in rather than a model.
# STATED DIFFERENCE: `$$` in the script is the fixture's pid (bash 3.2 has no BASHPID), so the deriver's
# `pkill -P $$ -x fs_usage` cannot reach a stub fs_usage forked from this subshell; every stub world reaps its stubs
# by recorded pid (stub_reap), so no verdict reads it. The --tracer both stub world's fs_usage reaping waits are
# injected (READSET_SLEEP_CMD) and keyed on the capture holding the stub's last line, not on the clock.
# EVERY DRIVE OF THE DERIVER IS ONE IN-PROCESS PASS (BL-982): fx_inproc (lib/mutant.sh) logs it when the sourced path IS
# the deriver's, core/scripts/derive-fixture-readsets.sh in whatever world the drive runs, keyed on the PATH and never the
# content -- a mutant copy at that path is a pass of the subject it copies, as lib/inproc.sh states for inproc_run. A
# renamed copy, a decision driver and hermetic-run.sh log nothing here. fx_inproc is kept through the function strip and
# unset on the line that sources, and that paired source covers the rs_main call after it. AN EXTRACTED SPAN IS LOGGED AT
# ITS DRIVE: every source of a span and every call of its entry functions carries its own fx_inproc naming the program the
# span was cut from -- "$DERIVER" for a deriver span, "$ROOT/core/git-hooks/pre-push" for a pool span (never $HOOK, which
# resolves to .githooks/pre-push here) -- and invocations.decl counts those passes on its inproc: rows.
inproc() {
  local _ip_v _ip_keep
  _ip_keep=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -i) for _ip_v in $(env | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p'); do
            case "$_ip_v" in HOME|PATH) ;; *) unset "$_ip_v" 2>/dev/null ;; esac
          done; shift ;;
      -u) unset "$2"; shift 2 ;;
      --) shift; break ;;
      *=*) export "$1"; shift ;;
      *) echo "inproc: not an env word: '$1'" >&2; return 97 ;;
    esac
  done
  [ -f "$1" ] || { echo "inproc: no script '$1'" >&2; return 97; }
  trap - EXIT INT TERM HUP
  for _ip_v in $(compgen -A function); do [ "$_ip_v" != fx_inproc ] || continue; unset -f "$_ip_v"; done
  _ip_keep=" $(compgen -e | tr '\n' ' ') "
  for _ip_v in $(compgen -v); do
    case "$_ip_v" in
      BASH*|DIRSTACK|EUID|FUNCNAME|GROUPS|HISTCMD|HOSTNAME|HOSTTYPE|IFS|LINENO|MACHTYPE|OPTERR|OPTIND|OSTYPE|PIPESTATUS|PPID|PS4|PWD|OLDPWD|RANDOM|SECONDS|SHELLOPTS|SHLVL|UID|_ip_v|_ip_keep) continue ;;
    esac
    case "$_ip_keep" in *" $_ip_v "*) continue ;; esac
    unset "$_ip_v" 2>/dev/null
  done
  unset _ip_keep
  set +u +e +m; set +o pipefail
  case "$1" in core/scripts/derive-fixture-readsets.sh|*/core/scripts/derive-fixture-readsets.sh) _ip_v=1 ;; *) _ip_v="" ;; esac
  [ -z "$_ip_v" ] || fx_inproc "$1"; unset -f fx_inproc; unset _ip_v; . "$@"
  if declare -F rs_main >/dev/null; then shift; rs_main "$@"; fi
}
# rs_drive [env words] -- <deriver> [args]: the deriver, in process. Call inside `( cd <repo> && rs_drive ... )`.
rs_drive() { inproc "$@"; }

if sg arms; then
# ------------------------------------------------------------------------- arm 1-6 ----
T="$WORK/t1"; f2b_world seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/a.sh')"; R1="$R"
if [ "$(sel_of "$R")" = "alpha gamma" ]; then
  ok "a change to src/a.sh selects alpha (reads it) and gamma (unmapped) — beta is SKIPPED"
else
  bad "expected 'alpha gamma', got '$(sel_of "$R")' — the skip selected the wrong set: $(msg_of "$R" | tr -d '\n')"
fi
case "$(msg_of "$R")" in
  *"read-set keys: 2 of 3 fixture(s) run"*"; skipping 1"*) ok "  and the run ANNOUNCES the skip rather than performing it silently" ;;
  *)          bad "  the skip was applied with no announcement naming what it skipped" ;;
esac

T="$WORK/t2"; f2b_world seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/shared.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "a change to a SHARED path selects both its readers, so the map is not merely per-fixture"
else
  bad "expected all three for src/shared.sh, got '$(sel_of "$R")'"
fi

T="$WORK/t3"; f2b_world seed "$T" || broken "seed failed"
# CONVERTED (contract k1): a changed path no read set names no longer runs the whole suite. It
# reruns exactly the fixtures keyed on the whole tree -- the unmapped gamma -- and nothing else.
R="$(select_in "$T" 'printf v2 > src/orphan.sh')"
if [ "$(sel_of "$R")" = "gamma" ] && printf '%s' "$(msg_of "$R")" | grep -qF 'gamma: unmapped: closure changed'; then
  ok "a changed path NO fixture reads reruns only the unmapped fixture, which is keyed on the whole tree"
else
  bad "an unmapped changed path did not select the unmapped fixture alone: '$(sel_of "$R")' / $(msg_of "$R" | tr -d '\n')"
fi

T="$WORK/t4"; f2b_world seed "$T" || broken "seed failed"
R="$(AI_DLC_FIXTURE_NO_SKIP=1 select_in "$T" 'printf v2 > src/a.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "AI_DLC_FIXTURE_NO_SKIP=1 runs everything — the drift sweep the map cannot check itself with"
else
  bad "AI_DLC_FIXTURE_NO_SKIP=1 still skipped: '$(sel_of "$R")'"
fi

T="$WORK/t5"; f2b_world seed "$T" || broken "seed failed"
rm -f "$T/.ai-dlc-fixture-readsets.tsv"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "no map at all runs everything, so an uninstalled map cannot silently disable the suite"
else
  bad "a missing map did not force a full run: '$(sel_of "$R")'"
fi

T="$WORK/t6"; f2b_world seed "$T" || broken "seed failed"
t6_apply() {
fx_inproc "$ROOT/core/git-hooks/pre-push"
R="$( cd "$T" && scratch="$(mktemp -d "$WORK/n.XXXXXX")" && . "$POOL" 2>/dev/null && \
      for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$scratch/list" && \
      rm -f .git/ai-dlc-fixture-verified && cp "$scratch/list" "$scratch/l" && \
      apply_readset_skip "$scratch/l" "$scratch" 2>&1 | tr -d '\n' )"
}
t6_apply
case "$R" in
  *"read-set keys: 3 of 3 fixture(s) run (0 changed, 3 unrecorded, 0 stale)"*) ok "with no verified state and no key records there is no seed: every fixture is unrecorded and runs" ;;
  *)                            bad "a missing verified-state record did not force a full run: $R" ;;
esac

T="$WORK/t7"; f2b_world seed "$T" || broken "seed failed"
R="$(select_in "$T" 'rm -f src/a.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "DELETING src/a.sh also selects beta, which globs src/ — a vanished entry changes what a listing returns"
else
  bad "a deletion did not select the directory's reader: '$(sel_of "$R")'"
fi

# SHARED DRIVE: t8 and t13 ask about the SAME state t1 built (the seed, then src/a.sh edited, through the
# pool), so the subject's output is identical; each reads its own property off t1's result.
R="$R1"
if [ "$(sel_of "$R")" = "alpha gamma" ]; then
  ok "  and EDITING the same file does NOT select beta — a parent rides along only on appearance"
else
  bad "  editing a file selected the directory's reader too ('$(sel_of "$R")'), which turns the skip back into a full run"
fi

T="$WORK/t9"; f2b_world seed "$T" || broken "seed failed"
# THE SUBJECT IS THE REF FILE, NOT `.git/HEAD`. HEAD holds `ref: refs/heads/<branch>` and does
# NOT change when you commit -- only the ref it points at does. An earlier version of this arm
# mapped `.git/HEAD` and passed even with the exclusion removed from BOTH sites, i.e. it could
# not fail. Derived here rather than hard-coded because the seed's default branch name is
# whatever the machine's git is configured for.
T9_REF=".git/$( cd "$T" && git symbolic-ref HEAD 2>/dev/null )"
case "$T9_REF" in
  .git/refs/heads/*) : ;;
  *) broken "could not resolve the seeded repo's ref file (got '$T9_REF'); the .git-scope arm would test nothing" ;;
esac
[ -f "$T/$T9_REF" ] || broken "resolved ref file '$T9_REF' does not exist in the seed"
printf 'gamma\t%s\n' "$T9_REF" >> "$T/.ai-dlc-fixture-readsets.tsv"
R="$(select_in "$T" 'git -c user.email=f@f -c user.name=f commit -q --allow-empty -m moveHEAD')"
if [ "$(flag_of "$R")" = "1" ] && [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "a commit moves the branch ref and the map sees NOTHING — git internals move on every push, and honouring them would select their readers every time"
else
  bad "a branch-ref move was visible to the selection ('$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

# ------------------------------------------------------------------------ arms 10-11 ----
# THE WHOLE-SUITE SKIP, AND THE ONE THING THAT MAKES IT SOUND.
#
# Arm 10 is the behaviour itself: when NOTHING in the universe moved, the suite does not run.
# This branch used to defer to the content key, and the two instruments deadlocked -- the key
# announced "changed, running the suite" while this announced "nothing changed", and neither
# ever skipped. Measured on the real repo, a commit touching only files under `docs/` -- a top
# the content key itself EXCLUDES -- ran all 161 fixtures.
#
# Arm 11 is the reason that skip is not reckless. `git ls-files` answers about the COMMITTED
# tree; a fixture reads the WORKING one. An untracked, unignored file is in no read-set by
# construction, so without it in the manifest universe `.changed` would be empty and arm 10
# would skip the suite over a tree nobody hashed. With it, the file is a CHANGED path no
# fixture reads -- the orphan case -- and the whole suite runs. The two arms pull in opposite
# directions on purpose: 10 says "skip when nothing moved", 11 says "and an untracked file IS
# something moving".
T="$WORK/t10"; f2b_world seed "$T" || broken "seed failed"
R="$(select_in "$T" ':')"
if [ "$(flag_of "$R")" = "1" ] && printf '%s' "$(msg_of "$R")" | grep -qF '0 of 3 fixture(s) run'; then
  ok "NOTHING changed since the last green run — the suite is SKIPPED WHOLE, not run whole"
else
  bad "an unchanged tree did not skip the suite (flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

T="$WORK/t11"; f2b_world seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v1 > src/untracked-newcomer.sh')"
if [ "$(flag_of "$R")" = "0" ] && [ "$(sel_of "$R")" = "beta gamma" ]; then
  ok "  an UNTRACKED, unignored new file is NOT nothing — it moves src/'s listing (beta) and the unmapped closure (gamma)"
else
  bad "  an untracked file was invisible to the manifest (flag $(flag_of "$R"), sel '$(sel_of "$R")') — the skip would run over a tree nobody hashed"
fi

# A GIT-IGNORED file must NOT block the skip, or the skip could never fire on a real tree:
# hooks and fixtures write into ignored paths WHILE the suite runs, so a universe covering
# them would differ from itself across the very run it is keyed on. This is the near-miss for
# arm 11 -- same shape, opposite required answer.
T="$WORK/t12"; f2b_world seed "$T" || broken "seed failed"
printf 'ignored-scratch/\n' > "$T/.gitignore"
( cd "$T" && git add -A && git -c user.email=f@f -c user.name=f commit -qm ignore ) >/dev/null 2>&1   || broken "could not seed a .gitignore"
R="$(select_in "$T" 'mkdir -p ignored-scratch && printf v1 > ignored-scratch/noise.txt')"
if [ "$(flag_of "$R")" = "1" ]; then
  ok "  and a GIT-IGNORED file does NOT block it — fixtures write into ignored paths as they run"
else
  bad "  an ignored file blocked the skip (flag $(flag_of "$R")): the skip could never fire on a real tree"
fi

# ------------------------------------------------------------------------- arms 13-14 ----
# THE MAP'S STALENESS IS ANNOUNCED, because nothing else can see it. A fixture directory with
# no entry runs on every push and the cost is invisible; a mapped path that gained a reader
# after the derivation is skipped for that reader and nothing reports it. Measured on the
# distribution: 510 commits between two derivations, 41 of 194 directories unmapped, 74 paths
# with untraced readers. The announce is the only mechanism -- the deriver needs root, so the
# hook cannot re-derive -- and an announce that cannot fire reads exactly like one that did.
# The seed maps alpha and beta and leaves gamma out, so the line must say 1 of 3 and name it.
R="$R1"   # t1's drive: the same seed and the same edit, read for the staleness announce
case "$(msg_of "$R")" in
  *"1 of 3 fixture dir(s) UNMAPPED (keyed on the whole tree): gamma"*)
    ok "the run ANNOUNCES the map's coverage gap by count and by name — an unmapped fixture is not a silent always-run" ;;
  *)
    bad "the coverage gap was not announced (expected '1 of 3 ... UNMAPPED ... gamma'): $(msg_of "$R" | tr -d '\n')" ;;
esac
# Near-miss: a map covering every directory announces ZERO unmapped and names nothing. The
# seed's map is tracked in its own repo, so the age half must resolve to a sha, never to
# 'UNTRACKED' -- the arm asserts both halves so an announce that lost its age cannot pass.
T="$WORK/t14"; f2b_world seed "$T" || broken "seed failed"
printf 'gamma\tsrc/b.sh\n' >> "$T/.ai-dlc-fixture-readsets.tsv"
( cd "$T" && git add -A && git -c user.email=f@f -c user.name=f commit -qm mapall ) >/dev/null 2>&1 || broken "could not commit the full map"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
M14="$(msg_of "$R")"
if grep -qE 'read-set map: derived at [0-9a-f]{7,}, 0 commit\(s\) ago; 0 of 3 fixture dir\(s\) UNMAPPED' <<< "$M14" \
   && ! grep -q 'trace them' <<< "$M14"; then
  ok "  and a map covering every directory announces its age and ZERO unmapped, with no remedy printed"
else
  bad "  a fully-mapped tree did not announce 'derived at <sha>, 0 commit(s) ago; 0 of 3 ... UNMAPPED' cleanly: $(printf '%s' "$M14" | tr -d '\n')"
fi

# CONTROL, from the same directory and driven the same way: a baseline selection must APPEAR, so a drive that
# died for a harness reason -- a seed that failed -- cannot pass as the clean case.
T="$WORK/ctl"; f2b_world seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
if [ "$(sel_of "$R")" = "alpha gamma" ]; then
  ok "CONTROL: a fresh seed and drive still selects 'alpha gamma'"
else
  bad "CONTROL: a fresh seed and drive did not reproduce the baseline ('$(sel_of "$R")')"
fi

fi

# ------------------------------------------------------- git-ignored paths, from every source ----
# THE DEFECT: the map arm of the manifest bypassed `--exclude-standard`, so a map row naming an
# IGNORED file was hashed whenever the file existed. A trace in the main checkout recorded three
# ignored `.DS_Store` files, a green run there wrote them into the verified record in the SHARED
# git dir, and a push from a worktree without them saw them VANISH: their parents joined `.match`
# and 11 changed paths selected 226 of 232 fixtures where their own rows select 55.
#
# The world: `src/x.bin` is ignored and named by alpha's map row, and beta names `src` -- so a
# vanished x.bin reaching `.match` selects beta, which is the motivating over-selection.
# `ign` creates x.bin untracked; `forced` force-adds it, so it is TRACKED and still matches
# the ignore pattern. Every arm edits src/a.sh too, so a correct run selects 'alpha gamma' and
# an over-selection and an orphan fallback both read as 'alpha beta gamma'.
if sg ign; then
IGN_ARMS=0
REAL_GIT="$(command -v git)" || broken "no git on PATH"
SHIM="$WORK/shim"; mkdir -p "$SHIM" || broken "could not make the check-ignore shim dir"
# The shim lives under $WORK, outside every seeded tree: inside one it would be an untracked
# file and an orphan. It scans argv because `-c core.quotePath=false` precedes the subcommand.
{ printf '#!/bin/bash\nfor a in "$@"; do [ "$a" = check-ignore ] && exit 128; done\n'
  printf 'exec "%s" "$@"\n' "$REAL_GIT"; } > "$SHIM/git" && chmod +x "$SHIM/git" \
  || broken "could not write the check-ignore shim"
seed_ign() { # <t> <none|ign|forced>
  local t="$1" mode="$2"
  f2b_world seed "$t" || return 1
  printf 'src/x.bin\n' > "$t/.gitignore"
  printf 'alpha\tsrc/x.bin\n' >> "$t/.ai-dlc-fixture-readsets.tsv"
  [ "$mode" = none ] || printf 'v1\n' > "$t/src/x.bin"
  ( cd "$t" && git add -A && { [ "$mode" != forced ] || git add -f src/x.bin; } && \
    git -c user.email=f@f -c user.name=f commit -qm ignored ) >/dev/null 2>&1 || return 1
  ( cd "$t" && [ "$mode" != forced ] || git ls-files --error-unmatch src/x.bin ) >/dev/null 2>&1 || return 1
  ( cd "$t" && [ "$mode" = forced ] || ! git ls-files --error-unmatch src/x.bin ) >/dev/null 2>&1 || return 1
  [ "$mode" = sub ] || return 0
  # A GITLINK the outer repo records at src/sub, and a map row naming a file inside it. One such
  # path makes `check-ignore` exit 128, so this world is the subject of the submodule guard.
  mkdir -p "$t/src/sub" && printf 'v1\n' > "$t/src/sub/f.txt" || return 1
  ( cd "$t/src/sub" && git init -q . && git add -A && \
    git -c user.email=f@f -c user.name=f commit -qm sub ) >/dev/null 2>&1 || return 1
  printf 'alpha\tsrc/sub/f.txt\n' >> "$t/.ai-dlc-fixture-readsets.tsv"
  ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm gitlink ) >/dev/null 2>&1 || return 1
  ( cd "$t" && git ls-files -s | grep -q '^160000 .*	src/sub$' ) || return 1
  ( cd "$t" && printf 'src/sub/f.txt\n' | git check-ignore --stdin ) >/dev/null 2>&1
  [ $? -eq 128 ]
}
# (a) the motivating case: a record from before the fix lists the ignored file, which is absent.
# A record from before the fix carries NO format stamp, so the stamp is removed first, and an
# unstamped record runs everything -- no over-selection is possible because nothing is selected.
IGN_A='rm -f .git/ai-dlc-fixture-verified.format && printf "src/x.bin\tdeadbeef\n" >> .git/ai-dlc-fixture-verified && sort -o .git/ai-dlc-fixture-verified .git/ai-dlc-fixture-verified && printf v2 > src/a.sh'
# (g) THE RECORD FILTER WAS A STANDING FILTER AND THAT WAS A WRONG SKIP. x.bin is FORCE-ADDED, so
# it is tracked, in the manifest and in the `v2` record. `git rm` makes it untracked AND ignored;
# filtering the record dropped its row, the vanish never reached `.changed`, and the whole suite
# was skipped over a deleted file beta's `src` row lists. The seed itself asserts the post-state.
IGN_G='git rm -q src/x.bin && git -c user.email=f@f -c user.name=f commit -qm rmforced >/dev/null && git check-ignore -q src/x.bin && [ -s .git/ai-dlc-fixture-verified.format ] && grep -q "^src/x.bin	" .git/ai-dlc-fixture-verified'
# (h) the upgrade path in the world it exists for: an OLDER hook (no stamp) hashed an untracked
# ignored file through the map arm, and the file has since been deleted. It runs everything: this
# world and (j)'s are byte-identical at read time, and filtering for this one skips (j)'s suite.
IGN_H='rm -f .git/ai-dlc-fixture-verified.format && printf "src/x.bin\t%s\n" "$(shasum -a 256 src/x.bin | cut -d" " -f1)" >> .git/ai-dlc-fixture-verified && sort -o .git/ai-dlc-fixture-verified .git/ai-dlc-fixture-verified && rm -f src/x.bin && printf v2 > src/a.sh'
# (i) a stamp this hook cannot read: the record format is unknown, so everything runs.
IGN_I='printf "v3\n" > .git/ai-dlc-fixture-verified.format && printf v2 > src/a.sh'
# (j) (g)'s world with NO stamp -- an older hook's record, or this hook's record copy landing and
# its stamp write failing. x.bin is force-added, recorded, then `git rm`'d, and NOTHING else
# changes, so a filter over the unstamped record drops the only change and skips the whole suite.
# The mutation asserts its own post-state: x.bin ignored now, in the record, and no stamp.
IGN_J='rm -f .git/ai-dlc-fixture-verified.format && git rm -q src/x.bin && git -c user.email=f@f -c user.name=f commit -qm rmforced >/dev/null && git check-ignore -q src/x.bin && [ ! -e .git/ai-dlc-fixture-verified.format ] && grep -q "^src/x.bin	" .git/ai-dlc-fixture-verified'
IGN_B='printf v2 > src/x.bin && printf v2 > src/a.sh'
IGN_C='rm -f src/a.sh'
IGN_D='printf v2 > src/x.bin'
IGN_E='PATH="$SHIM:$PATH"; printf v2 > src/a.sh'
ign_arm() { # <label> <seed mode> <mutation> <want sel> <want flag> <message needle> <ok text>
  local t; t="$(mktemp -d "$WORK/ig.XXXXXX")" || broken "mktemp failed"
  f2b_world seed_ign "$t/w" "$2" || broken "ignored-path seed ($2) failed"
  R="$(select_in "$t/w" "$3")"
  if [ "$(sel_of "$R")" = "$4" ] && [ "$(flag_of "$R")" = "$5" ] && msg_of "$R" | grep -qF "$6"; then
    ok "$7"
  else
    bad "$1: expected '$4' flag $5 with '$6', got '$(sel_of "$R")' flag $(flag_of "$R"): $(msg_of "$R" | tr -d '\n')"
  fi
  IGN_ARMS=$((IGN_ARMS+1))
}
ign_arm "(b)" ign "$IGN_B" "alpha gamma" 0 "read-set keys:" \
  "(b) an ignored file PRESENT and EDITED is no change and no orphan — only a.sh's reader runs"
ign_arm "(c)" ign "$IGN_C" "alpha beta gamma" 0 "read-set keys:" \
  "(c) in the same world a TRACKED file vanishing still adds its parent and selects beta"
ign_arm "(d)" forced "$IGN_D" "alpha gamma" 0 "read-set keys:" \
  "(d) a TRACKED file matching an ignore pattern still counts — editing it selects its reader"
ign_arm "(e)" none "$IGN_E" "alpha beta gamma" 0 "could not hash" \
  "(e) check-ignore failing (exit 128) fails CLOSED — the manifest is emptied and everything runs"
# The seed itself asserts the gitlink is recorded and that check-ignore exits 128 on the path
# inside it, so this arm cannot pass over a world that never expressed the case.
ign_arm "(f)" sub 'printf v2 > src/a.sh' "alpha gamma" 0 "read-set keys:" \
  "(f) a map path inside a SUBMODULE is never asked — check-ignore would exit 128 on it and run everything on every push"
# (g) under keys: the vanished path is ignored now, so it is no key (ignored paths are unkeyed by
# contract) and alpha skips; src/'s listing moved (beta) and the unmapped closure moved (gamma).
ign_arm "(g)" forced "$IGN_G" "beta gamma" 0 "read-set keys:" \
  "(g) a FORCE-ADDED ignored file in a v2 record, then git rm'd, is a VANISH — its directory's lister and the unmapped fixture run, never a whole skip"


fi

# ------------------------------------- the manifest's population and the bookkeeping exemption ----
# TWO DEFECTS, ONE SEED. The manifest fed its path list to `xargs` without `-0`, and `xargs`
# aborts at the first apostrophe in a name: every file sorted after it went unhashed, so an
# edit to any of them read as "nothing changed" and the whole suite was skipped. Separately, a
# commit touching only the update skill's own bookkeeping -- the version stamp and the flat
# files under `_bmad-output/ai-dlc-update/` -- hit the orphan branch and ran everything.
#
# THE SEED IS SHAPED BY THE FIRST DEFECT'S MECHANICS. `xargs -n 200` runs each batch it has
# finished reading, so an apostrophe inside the FIRST batch hashes nothing, empties the manifest
# and falls into "could not hash -- running all", which is safe and hides the defect. Two hundred
# and ten filler files under `aaa/` push the apostrophe into the second batch, where the first
# batch is hashed and the rest silently is not. That position is asserted before any verdict.
#
# Fixtures: alpha reads src/a.sh, apos reads the apostrophe file, beta reads zzz/b.sh (sorts
# after it), stamp reads the version stamp, delta is unmapped (always selected).
if sg man; then
APOS="src/x's.snap"
CAFE="src/caf$(printf '\303\251').md"
BK='printf "version: 2\n" > .claude/.ai-dlc-version; printf "l2\n" >> _bmad-output/ai-dlc-update/ledger.md; printf "r\n" > _bmad-output/ai-dlc-update/reconcile-log-1.md'
ALL5="alpha apos beta delta stamp"
NEW_ARMS=0
seed2() {
  local t="$1" i=0 f
  mkdir -p "$t/aaa" "$t/src" "$t/zzz" "$t/.claude" "$t/sub/.claude" "$t/_bmad-output/ai-dlc-update/sub" || return 1
  for f in alpha apos beta delta stamp; do
    mkdir -p "$t/core/fixtures/$f" && printf 'exit 0\n' > "$t/core/fixtures/$f/run.sh" || return 1
  done
  printf 'alpha\tsrc/a.sh\napos\t%s\nbeta\tzzz/b.sh\nstamp\t.claude/.ai-dlc-version\n' "$APOS" \
    > "$t/.ai-dlc-fixture-readsets.tsv"
  while [ "$i" -lt 210 ]; do printf '%s\n' "$i" > "$t/aaa/f$i"; i=$((i+1)); done
  printf 'v1\n' > "$t/src/a.sh"; printf 'v1\n' > "$t/zzz/b.sh"; printf 'q\n' > "$t/$APOS"; printf 'c\n' > "$t/$CAFE"
  printf 's\n' > "$t/.claude/settings.json"; printf 'version: 1\n' > "$t/.claude/.ai-dlc-version"
  printf 'version: 1\n' > "$t/sub/.claude/.ai-dlc-version"
  printf 'o\n' > "$t/_bmad-output/other.md"; printf 'x\n' > "$t/_bmad-output/ai-dlc-update/sub/x.md"
  printf 'l\n' > "$t/_bmad-output/ai-dlc-update/ledger.md"
  ( cd "$t" && git init -q . && git add -A && \
    git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1 || return 1
}
TPL="$WORK/tpl"; seed2 "$TPL" || broken "the manifest seed failed"

# THE SEED MUST CARRY EVERY PROPERTY BEFORE ANY VERDICT IS READ. A global excludesFile that
# ignores `.claude/` or `_bmad-output/` would leave the bookkeeping arms passing over files git
# never listed; and an apostrophe in the first batch, or one sorting after zzz/b.sh, would make
# the "after it" arm agree with the broken manifest.
N_TR="$( cd "$TPL" && git ls-files | grep -c . )" || N_TR=0
[ "$N_TR" -eq 226 ] || broken "the manifest seed tracks $N_TR files, not 226 — something (a global excludesFile?) dropped seeded paths"
( cd "$TPL" && git check-ignore -q _bmad-output/ai-dlc-update/reconcile-log-1.md ) \
  && broken "the untracked bookkeeping file the bookkeeping arm creates is git-ignored here, so the manifest would never list it"
SP0="$(mktemp -d "$WORK/p.XXXXXX")" || broken "mktemp failed"
sp0_manifest() {
( cd "$TPL" && fx_inproc "$ROOT/core/git-hooks/pre-push" && . "$POOL" 2>/dev/null && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_manifest "$SP0" )
}
sp0_manifest
IA="$(grep -nxF "$APOS" "$SP0/.files" | cut -d: -f1)"
IB="$(grep -nxF "zzz/b.sh" "$SP0/.files" | cut -d: -f1)"
[ -n "$IA" ] && [ -n "$IB" ] && [ "$IA" -gt 200 ] && [ "$IA" -lt "$IB" ] \
  || broken "the apostrophe file is not past the first 200-path batch and before zzz/b.sh in the hook's own sort (at '${IA:-absent}', zzz/b.sh at '${IB:-absent}') — the arms below could not express the xargs defect"

# drive <pool> <name> <mutation> [stale] [extra seed] -- fresh world per call, scratch at
# $WORK/x.<name>. `stale` writes a non-empty record no manifest produced, so a world whose
# manifest is empty from the first run still reaches the "could not hash" guard rather than
# stopping at "no verified-state record".
drive() {
  local pool="$1" name="$2" mut="$3" mode="${4:-}" extra="${5:-}" t="$WORK/w.$2" sc="$WORK/x.$2"
  cp -Rp "$TPL" "$t" && mkdir -p "$sc" || return 1
  if [ -n "$extra" ]; then
    ( cd "$t" && eval "$extra" && git add -A && \
      git -c user.email=f@f -c user.name=f commit -qm extra ) >/dev/null 2>&1 || return 1
  fi
  ( cd "$t" || exit 1
    export AI_DLC_READSET_LIVE_TRACE=0
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$pool" 2>/dev/null
    for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$sc/list"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_manifest "$sc"
    cp "$sc/.now" "$sc/seed.now"; cp "$sc/.files" "$sc/seed.files"
    if [ "$mode" = stale ]; then printf 'seed\tstale\n' > "$GITDIR/ai-dlc-fixture-verified"
    else cp "$sc/.now" "$GITDIR/ai-dlc-fixture-verified"; fi
    printf 'v2\n' > "$GITDIR/ai-dlc-fixture-verified.format"
    eval "$mut"
    READSET_NO_CHANGE=0
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    apply_readset_skip "$sc/list" "$sc" > "$sc/msg" 2>&1
    sed 's|core/fixtures/||g; s|/$||' "$sc/list" | tr '\n' ' '
    printf '\n---MSG---\n'; cat "$sc/msg"
    printf '\n---FLAG---\n%s\n' "${READSET_NO_CHANGE:-0}"
  )
}
# holds <result> <selected> <flag> <message needle>: the selected set, the decision flag and a
# line of the announce, all three. The flag alone cannot tell "skipped whole" from "ran whole";
# the set alone cannot either, since a whole-suite skip leaves the list untouched.
holds() {
  [ "$(sel_of "$1")" = "$2" ] && [ "$(flag_of "$1")" = "$3" ] && grep -qF -- "$4" <<< "$(msg_of "$1")"
}
# hashed <scratch>: the seed manifest carries exactly one row for the apostrophe file, one for
# zzz/b.sh, and as many rows as files it listed.
hashed() {
  local na nb nn nf
  na="$(grep -cF "$APOS	" "$1/seed.now")" || na=0
  nb="$(grep -c '^zzz/b\.sh	' "$1/seed.now")" || nb=0
  nn="$(grep -c . "$1/seed.now")" || nn=0
  nf="$(grep -c . "$1/seed.files")" || nf=0
  [ "$na" -eq 1 ] && [ "$nb" -eq 1 ] && [ "$nn" -eq "$nf" ] && [ "$nf" -gt 200 ]
}
NM1() { printf '1 changed path(s) are in NO fixture read-set (e.g. %s)' "$1"; }
UNHASH="could not hash the working tree -- running all"
WHY="$(id -u)"

R="$(drive "$POOL" n1 'printf "q2\n" > "$APOS"')"
NEW_ARMS=$((NEW_ARMS+1))
if hashed "$WORK/x.n1"; then
  ok "the APOSTROPHE-named file is hashed, and so is zzz/b.sh after it — the manifest has a row for every file it listed ($(grep -c . "$WORK/x.n1/seed.now"))"
else
  bad "the manifest lost the apostrophe file or what sorts after it: $(grep -c . "$WORK/x.n1/seed.now") hashed of $(grep -c . "$WORK/x.n1/seed.files") listed, apostrophe rows $(grep -cF "$APOS	" "$WORK/x.n1/seed.now")"
fi
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "apos delta" 0 "read-set keys:"; then
  ok "  and an edit to the apostrophe file selects its reader (apos) plus the unmapped delta"
else
  bad "  an edit to the apostrophe file did not select 'apos delta' (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

R="$(drive "$POOL" n2 'printf "v2\n" > zzz/b.sh')"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "beta delta" 0 "read-set keys:"; then
  ok "an edit to a mapped file sorting AFTER the apostrophe selects its reader (beta) — it was hashed, so it is not 'nothing changed'"
else
  bad "an edit to zzz/b.sh did not select 'beta delta' (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

R="$(drive "$POOL" n3 "$BK")"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "delta stamp" 0 "read-set keys:"; then
  ok "a BOOKKEEPING-ONLY change (version stamp, ledger edit, new reconcile log) selects only the stamp's reader and the unmapped fixture — neither all, nor nothing"
else
  bad "a bookkeeping-only change did not select exactly 'delta stamp' with the suite running (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

# THE FLAT `_bmad-output/` WAIVER. A consumer's pipeline commits flat state files directly under
# `_bmad-output/`, the map names no reader for them, and each one used to force the whole suite. The waiver covers ONLY the "unknown reader" verdict for a FLAT root file: a
# deeper path, a nested `_bmad-output/` under another top, and a non-bookkeeping `.claude/` file
# still run all (below), and a flat file the map DOES name still selects its reader.
# `mkdir -p` sits in the mutation, not in seed2, so the seed's tracked count and the apostrophe
# position asserted above stay exactly as they were.
BMNEAR=".claude/settings.json _bmad-output/ai-dlc-update/sub/x.md _bmad-output/sub/x.md sub/_bmad-output/pipeline-continuation-log.md"
NMK() { printf "%s; mkdir -p \"\$(dirname '%s')\"; printf 'n2\\\\n' > '%s'" "$BK" "$1" "$1"; }
# POSITIVE: a flat root file beside the bookkeeping is WAIVED, so the run selects exactly what
# the bookkeeping alone selects. Before the widening this was a near-miss that ran all.
R="$(drive "$POOL" n4.flat "$BK; printf 'n2\n' > _bmad-output/other.md")"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "delta stamp" 0 "read-set keys:"; then
  ok "  a FLAT _bmad-output/other.md beside the bookkeeping is waived — 'delta stamp', the bookkeeping's own selection, not all"
else
  bad "  a flat _bmad-output/other.md beside the bookkeeping did not select exactly 'delta stamp' (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
# POSITIVE: an edit to a zero-reader flat state file ALONE selects only the unmapped fixture.
PCL="_bmad-output/pipeline-continuation-log.md"
R="$(drive "$POOL" n4.pcl "printf 'p2\n' > '$PCL'" "" "printf 'p1\n' > '$PCL'")"
NEW_ARMS=$((NEW_ARMS+1))
if [ -f "$WORK/w.n4.pcl/$PCL" ] && holds "$R" "delta" 0 "read-set keys:"; then
  ok "an edit to a zero-reader flat $PCL selects only the unmapped delta — the pipeline's state file no longer forces the suite"
else
  bad "an edit to the zero-reader flat $PCL did not select exactly 'delta', or was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
# POSITIVE, TWO MORE SHAPES: the waiver is `[^/]+`, so it covers a flat file of ANY extension and a
# flat DOTFILE. With only `.md` seeds, a `[^/]+\.md` waiver and a `[^/.][^/]*` one both passed every
# arm here on behaviour. Each of these two is the one input that separates one of them.
for _fp in _bmad-output/arm-log.jsonl _bmad-output/.pipeline-state; do
  _fn="n4.fp$(printf '%s' "$_fp" | tr '/.' '__')"
  R="$(drive "$POOL" "$_fn" "printf 'f2\n' > '$_fp'" "" "printf 'f1\n' > '$_fp'")"
  NEW_ARMS=$((NEW_ARMS+1))
  if [ -f "$WORK/w.$_fn/$_fp" ] && holds "$R" "delta" 0 "read-set keys:"; then
    ok "an edit to a zero-reader flat $_fp selects only the unmapped delta — the waiver is not limited to .md or to non-dotfiles"
  else
    bad "an edit to the zero-reader flat $_fp did not select exactly 'delta', or was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
  fi
done
# POSITIVE: a flat file the map NAMES still selects its reader. This is what separates the waiver
# from dropping `_bmad-output` out of the manifest or the read-sets, which loses alpha here.
MAPPED="_bmad-output/mapped-state.md"
R="$(drive "$POOL" n4.mapped "printf 'm2\n' > '$MAPPED'" "" \
       "printf 'm1\n' > '$MAPPED'; printf 'alpha\t%s\n' '$MAPPED' >> .ai-dlc-fixture-readsets.tsv")"
NEW_ARMS=$((NEW_ARMS+1))
if grep -qxF "alpha	$MAPPED" "$WORK/w.n4.mapped/.ai-dlc-fixture-readsets.tsv" && holds "$R" "alpha delta" 0 "read-set keys:"; then
  ok "an edit to a MAPPED flat $MAPPED still selects its reader (alpha) plus delta — the waiver touches only unknown readers"
else
  bad "an edit to the mapped flat $MAPPED did not select 'alpha delta', or its map row was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
# THE NESTED NEAR-MISS is the only input for the version stamp that separates an anchored pattern
# from one that lost its `^`: the near-misses above differ from the stamp at its START or past its
# last `/` (the nested `sub/_bmad-output/` one guards the flat waiver's anchor, not the stamp's),
# so an unanchored stamp alternative drops none of them. A version stamp under a
# subdirectory ENDS like the real one and must still run all.

if [ "$WHY" = 0 ]; then
  printf '  SKIP  unreadable-file arm: running as root, where chmod 000 does not stop a read\n'
else
  R="$(drive "$POOL" n6 'chmod 000 aaa/f5')"
  NEW_ARMS=$((NEW_ARMS+1))
  if holds "$R" "$ALL5" 0 "$UNHASH"; then
    ok "an UNREADABLE file fails the hash and the manifest is emptied — 'could not hash', all run"
  else
    bad "an unreadable file did not fail closed through 'could not hash' (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
  fi
fi

R="$(drive "$POOL" n7 'printf "v2\n" > src/a.sh' stale "printf t > 'src/tab	name'")"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "$ALL5" 0 "$UNHASH"; then
  ok "a TAB-named file git still quotes fails closed — 'could not hash', all run"
else
  bad "a tab-named file did not fail closed (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
R="$(drive "$POOL" n8 'printf "v2\n" > src/a.sh' stale 'printf t > "src/back\\slash"')"
NEW_ARMS=$((NEW_ARMS+1))
if [ -f "$WORK/w.n8/src/back\\slash" ] && holds "$R" "$ALL5" 0 "$UNHASH"; then
  ok "  and so does a BACKSLASH-named one"
else
  bad "  a backslash-named file did not fail closed, or was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
# AN OPTION-SHAPED NAME. Without `--`, shasum reads a top-level `-x.sh` as an unknown option,
# exits non-zero, and the manifest is emptied on every push: correct, and the skip never fires.
DASH_SEED='printf t > ./-x.sh'
R="$(drive "$POOL" n9 'printf "v2\n" > src/a.sh' "" "$DASH_SEED")"
NEW_ARMS=$((NEW_ARMS+1))
if [ -f "$WORK/w.n9/-x.sh" ] && holds "$R" "alpha delta" 0 "read-set keys:"; then
  ok "a top-level file named -x.sh is hashed as a file, and an edit to a mapped sibling still selects its reader (alpha) plus delta"
else
  bad "with a top-level -x.sh present an edit to src/a.sh did not select 'alpha delta', or -x.sh was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

# CONTROL for the arms above, driven by the same helper: a baseline row must be
# THERE, so a drive that died for a harness reason cannot pass as the clean case.
R="$(drive "$POOL" ctl2 'printf "v2\n" > zzz/b.sh')"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "beta delta" 0 "read-set keys:" && grep -q 'read-set map: derived at' <<< "$(msg_of "$R")"; then
  ok "CONTROL: the block, driven through drive(), selects 'beta delta' and announces the map"
else
  bad "CONTROL: the block did not reproduce 'beta delta' through drive()"
fi

fi

# ------------------------------------------- the local map and the post-green trace ----
# An unmapped fixture ran on every push until someone hand-ran the deriver. Now a GREEN suite starts
# one detached, unprivileged `--tracer sandbox --local-map` run for the fixtures with no committed
# row and no valid local row, and the rows it records under the git dir are read at every site that
# reads the committed map. These arms drive the extracted pool block with a STUB deriver (it records
# its argv and appends a row), so they need no sandbox; the deriver's own `--local-map` mode is
# driven further down, in the stub-stream world. Every arm below is presence-shaped.
#   (a) a green run starts the trace for the unmapped fixture, detached, and a row lands
#   (b) a valid local row maps the fixture: skipped on an unrelated change, selected on its own input
#   (c) a moved run.sh (or deriver) invalidates the set: unmapped, and taken by the next trace
#   (d) committed rows win over local ones
#   (e) a linked worktree starts no trace and says so in one line (the deriver-side discards are below)
#   (f) the gate's exit is never the trace's: a failing deriver leaves the green run green
#   (g) the orphan universe and the manifest read local rows, so a local-only path is not an orphan
# WHAT THE LOC UNIT STILL COSTS, AND WHY NO CHEAPER CALL ANSWERS IT. The remaining wall clock is the real-time waits of the
# ceiling worlds (t1, t2, t3), each ending on the subject's own events. The longest, t1, waits
# for a hung deriver against a 3s ceiling: the fixture reads `start`, `ceiling` and the 5s TERM-to-KILL grace from the
# status file the subject wrote and calls the stall FINAL only once `start + ceiling + 5` has passed on the REAL clock (ct_final).
# That deadline is the question: "did the watchdog fire within its own promise?" It cannot be answered by calling a function,
# because the subject's `sleep "$cl"` is a real child and the verdict is whether it ended the deriver's group; injecting the clock would
# make ct_final stop waiting for a watchdog that has not yet had its promised time, which scores a correct slow watchdog as a missing ceiling.
# The one seam the subject honours, AI_DLC_READSET_TRACE_CEILING, is already at 3s, and the 5s grace is the hook's own constant. The
# stall window (AW_STALL polls of 0.1s) is NOT the cost here: a lower window gives false failures on a loaded box (the waits count
# polls, so load widens them), and every wait that can end on an event already does. Shortening any of these reads a slow correct
# subject as a defect, so the waits stay.
LT_ARMS=0
lt_arm() { LT_ARMS=$((LT_ARMS+1)); }
if sg loc; then
LT_CAN=1
{ command -v sandbox-exec >/dev/null 2>&1 && [ -x /usr/bin/log ] && command -v python3 >/dev/null 2>&1; } || LT_CAN=0
sha_of() { shasum -a 256 -- "$1" | cut -d' ' -f1; }
# lt_wait ENDS WHEN THE LOCK IS GONE OR ITS TRACE SUBSHELL IS. The rows (a) and (f) count are written
# by the stub before the subshell releases the lock, so a wait that gave up early read row=0 for a
# correct launcher. The owner is the status file's `pid`, written by the subshell itself.
lt_wait() { # <lock dir>
  local lw="$1"
  aw_wait '[ ! -d "$lw" ]' 'aw_status_pid "$READSET_LOCAL.status"' ''
  [ "$?" = 2 ] && aw_stalled "the live trace neither released $lw nor advanced its status file"
  :
}
# THE STUB'S GO WAIT ENDS ON GO, ON ITS OWNER'S DEATH, OR ON A LAUNCH THAT IS NOT DETACHED. It used to
# give up after 50 ticks and finish anyway, so under load a correct launcher's trace finished BEFORE
# run_fixtures returned and (a) read the lock released. Now it waits for STUB_GO while STUB_GO_OWNER,
# the process that will write it, is alive. One launch can never write GO while the stub waits: a
# SYNCHRONOUS one, whose caller is blocked on this very stub. That launch is told apart
# by an order fact, not a clock: a detached launcher writes `<lock>/pid` right after the fork, while
# the stub waits; a synchronous one cannot write it until the stub has returned, and meanwhile the
# owner is BLOCKED (state S, nothing pending) waiting on a child that is this stub's own ancestor, with
# no other child alive. A detached owner is running, or blocked on some other child (a command
# substitution inside readset_lock_write), so that state is never read for it. The stub leaves on that
# fact and records why it left in <GO>.left: `go`, `orphan` (its owner died) or `nolockpid` -- which the
# (a) arm refuses on.
# ONLY THE DETACHED TRACE WAITS. The in-pool trace invokes this stub with `--in-pool` and no
# `--local-map`, inside run_fixtures, where no lock exists to hold; it skips the wait and writes no
# `.left`, so the record is the detached stub's alone.
LT_STUB='#!/bin/bash
printf "%s\n" "$*" > "$STUB_ARGS"
if [ -n "${STUB_PPID:-}" ]; then printf "%s\n" "$PPID" > "$STUB_PPID"; fi
lm=""; ls=""
while [ $# -gt 0 ]; do case "$1" in --local-map) lm="$2"; shift ;; --list) ls="$2"; shift ;; esac; shift; done
if [ -n "${STUB_GO:-}" ] && [ -n "$lm" ]; then
  why=go; anc=" "; a="$$"
  while [ -n "$a" ] && [ "$a" -gt 1 ] 2>/dev/null; do anc="$anc$a "; a="$(ps -o ppid= -p "$a" 2>/dev/null | tr -d " ")"; done
  while [ ! -f "$STUB_GO" ]; do
    if [ -n "${STUB_GO_OWNER:-}" ] && ! kill -0 "$STUB_GO_OWNER" 2>/dev/null; then why=orphan; break; fi
    if [ ! -f "$lm.lock/pid" ] && [ -n "${STUB_GO_OWNER:-}" ]; then
      st="$(ps -o stat= -p "$STUB_GO_OWNER" 2>/dev/null | tr -d " ")"; pd="$(ps -o pending= -p "$STUB_GO_OWNER" 2>/dev/null | tr -d " ")"
      case "$st:$pd" in S*:0|I*:0)
        sync=1; for c in $(pgrep -P "$STUB_GO_OWNER" 2>/dev/null); do case "$anc" in *" $c "*) ;; *) sync=0 ;; esac; done
        [ -f "$lm.lock/pid" ] || { [ "$sync" = 1 ] && { why=nolockpid; break; }; } ;;
      esac
    fi
    sleep 0.1
  done
  printf "%s\n" "$why" > "$STUB_GO.left"
fi
for f in $ls; do printf "%s\tcore/fixtures/%s/run.sh\t-\n" "$f" "$f" >> "$lm"; done
exit "${STUB_RC:-0}"'
seed_lt() { # <t>: seed() plus a TRACKED stub deriver, so readset_deriver_path resolves and hashes it
  f2b_world seed "$1" || return 1
  mkdir -p "$1/core/scripts" && printf '%s\n' "$LT_STUB" > "$1/core/scripts/derive-fixture-readsets.sh" || return 1
  ( cd "$1" && git add -A && git -c user.email=f@f -c user.name=f commit -qm stub ) >/dev/null 2>&1
}
# A LAUNCHING WORLD'S STUB LIVES AT THE CONSUMER LAYOUT PATH (BL-878). Every world below whose drive makes the hook
# LAUNCH its deriver (readset_live_trace, the in-pool worker, the ct and fx watchdog worlds) gets its stub from LT_DVP,
# which readset_deriver_path resolves first, so the hook starts it exactly as it starts a real deriver. At
# core/scripts/derive-fixture-readsets.sh the invocation counter would log each stub start as a start of the deriver,
# which it is not: the subject of these worlds is the hook's launcher, kept end to end, and the stub only records what it
# was handed. The dist-layout resolution stays driven by the seed_lt worlds that hash the stub and name it in the
# remedy text (lrm, the held set).
LT_DVP=scripts/ai-dlc/derive-fixture-readsets.sh
seed_ltc() { # <t>: seed() plus the TRACKED stub deriver at LT_DVP
  f2b_world seed "$1" || return 1
  mkdir -p "$1/${LT_DVP%/*}" && printf '%s\n' "$LT_STUB" > "$1/$LT_DVP" || return 1
  ( cd "$1" && git add -A && git -c user.email=f@f -c user.name=f commit -qm stub ) >/dev/null 2>&1
}
# The local world: gamma's VALID rows (its run.sh, and src/orphan.sh, which no committed row names),
# and an alpha row on src/lonly.sh, a file NO committed row names. Alpha has committed rows, so its
# local rows must be ignored everywhere -- including the universe, where an ignored row would
# otherwise turn src/lonly.sh from an orphan into a known path. `nomap` removes the committed map.
seed_lw() { # <t> [sub|nomap]
  local t="$1" ds
  f2b_world seed_lt "$t" || return 1
  printf 'v1\n' > "$t/src/lonly.sh"
  ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm lonly ) >/dev/null 2>&1 || return 1
  if [ "${2:-}" = nomap ]; then
    ( cd "$t" && git rm -q .ai-dlc-fixture-readsets.tsv && git -c user.email=f@f -c user.name=f commit -qm nomap ) >/dev/null 2>&1 || return 1
  fi
  if [ "${2:-}" = sub ]; then
    mkdir -p "$t/src/sub" && printf 'v1\n' > "$t/src/sub/f.txt" || return 1
    ( cd "$t/src/sub" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm sub ) >/dev/null 2>&1 || return 1
    ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm gitlink ) >/dev/null 2>&1 || return 1
    ( cd "$t" && git ls-files -s | grep -q '^160000 .*	src/sub$' ) || return 1
  fi
  ds="$(sha_of "$t/core/scripts/derive-fixture-readsets.sh")"
  { printf 'gamma\tcore/fixtures/gamma/run.sh\t%s\n' "$(sha_of "$t/core/fixtures/gamma/run.sh")"
    printf 'gamma\tsrc/orphan.sh\t%s\n' "$(sha_of "$t/src/orphan.sh")"
    [ "${2:-}" = sub ] && printf 'gamma\tsrc/sub/f.txt\t%s\n' "$(sha_of "$t/src/sub/f.txt")"
    printf 'gamma\t#deriver\t%s\n' "$ds"
    printf 'alpha\tsrc/lonly.sh\t%s\n' "$(sha_of "$t/src/lonly.sh")"
    printf 'alpha\t#deriver\t%s\n' "$ds"
  } > "$t/.git/ai-dlc-fixture-readsets.local"
  # GHOSTS: `ghost` has VALID local rows and `zombie` a committed row, and neither has a directory
  # in `ghost` mode. Each names one file nobody else names. `ghostdir` is the near-miss: the same
  # rows with both directories present, so each row's fixture is dispatched and selects normally.
  case "${2:-}" in ghost|ghostdir)
    printf 'v1\n' > "$t/src/gonly.sh"; printf 'v1\n' > "$t/src/zonly.sh"
    printf 'zombie\tsrc/zonly.sh\n' >> "$t/.ai-dlc-fixture-readsets.tsv"
    if [ "$2" = ghostdir ]; then
      mkdir -p "$t/core/fixtures/ghost" "$t/core/fixtures/zombie" || return 1
      printf 'exit 0\n' > "$t/core/fixtures/ghost/run.sh"; printf 'exit 0\n' > "$t/core/fixtures/zombie/run.sh"
    fi
    ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm ghosts ) >/dev/null 2>&1 || return 1
    { printf 'ghost\tsrc/gonly.sh\t%s\n' "$(sha_of "$t/src/gonly.sh")"
      printf 'ghost\t#deriver\t%s\n' "$ds"
    } >> "$t/.git/ai-dlc-fixture-readsets.local" ;;
  esac
}
# select_in, plus the fixtures the post-green trace would take (`.trace`) and those it holds back.
lsel_in() {
  local t="$1" scratch; shift
  scratch="$(mktemp -d "$WORK/ls.XXXXXX")" || return 1
  ( cd "$t" || exit 1
    export AI_DLC_READSET_LIVE_TRACE=0
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    . "$POOL" 2>/dev/null
    for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$scratch/list"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_manifest "$scratch"
    cp "$scratch/.now" .git/ai-dlc-fixture-verified 2>/dev/null && printf 'v2\n' > .git/ai-dlc-fixture-verified.format
    eval "$*"
    cp "$scratch/list" "$scratch/l"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    apply_readset_skip "$scratch/l" "$scratch" > "$scratch/msg" 2>&1
    sed 's|core/fixtures/||g; s|/$||' "$scratch/l" | tr '\n' ' '
    printf '\n---MSG---\n'; cat "$scratch/msg"
    printf '\n---FLAG---\n%s\n' "${READSET_NO_CHANGE:-0}"
    printf -- '---TRACE---\n%s\n' "$(tr '\n' ' ' < "$scratch/.trace" 2>/dev/null | sed 's/ $//')"
    printf -- '---HELD---\n%s\n' "$(tr '\n' ' ' < "$scratch/.trace.held" 2>/dev/null | sed 's/ $//')"
  )
}
lflag_of() { printf '%s\n' "$1" | sed -n '/^---FLAG---$/{n;p;}'; }
trace_of() { printf '%s\n' "$1" | sed -n '/^---TRACE---$/{n;p;}'; }
held_of()  { printf '%s\n' "$1" | sed -n '/^---HELD---$/{n;p;}'; }
lw_run() { # <pool> <name> <mutation> [sub]: a fresh local world, driven through <pool>
  local t="$WORK/lw.$2" saved="$POOL"
  f2b_world seed_lw "$t" "${4:-}" || { printf 'SEED FAILED\n'; return 1; }
  POOL="$1"; lsel_in "$t" "$3"; POOL="$saved"
}
# Each result is scored by a predicate over it.
lb1() { [ "$(sel_of "$1")" = "alpha" ] && [ "$(trace_of "$1")" = "" ] && msg_of "$1" | grep -qF '0 of 3 fixture dir(s) UNMAPPED'; }
lb2() { [ "$(sel_of "$1")" = "gamma" ] && [ "$(lflag_of "$1")" = 0 ] && msg_of "$1" | grep -qF 'SKIPPING' && ! msg_of "$1" | grep -qF 'NO fixture read-set'; }
lc1() { [ "$(trace_of "$1")" = "gamma" ] && msg_of "$1" | grep -qF 'UNMAPPED (keyed on the whole tree): gamma'; }
lc2() { [ "$(trace_of "$1")" = "gamma" ]; }
ld()  { [ "$(sel_of "$1")" = "alpha beta gamma" ] && msg_of "$1" | grep -qF '1 changed path(s) are in NO fixture read-set (e.g. src/lonly.sh)'; }
lgs() { [ "$(sel_of "$1")" = "gamma" ] && [ "$(lflag_of "$1")" = 0 ] && msg_of "$1" | grep -qF 'SKIPPING'; }
le()  { [ "$(sel_of "$1")" = "beta gamma" ] && msg_of "$1" | grep -qF 'SKIPPING'; }
lgl() { [ "$(sel_of "$1")" = "alpha beta gamma" ] && msg_of "$1" | grep -qF '1 changed path(s) are in NO fixture read-set (e.g. src/gonly.sh)'; }
lgc() { [ "$(sel_of "$1")" = "alpha beta gamma" ] && msg_of "$1" | grep -qF '1 changed path(s) are in NO fixture read-set (e.g. src/zonly.sh)'; }
lgln() { [ "$(sel_of "$1")" = "ghost" ] && msg_of "$1" | grep -qF 'SKIPPING'; }
lgcn() { [ "$(sel_of "$1")" = "zombie" ] && msg_of "$1" | grep -qF 'SKIPPING'; }
LM_B1='printf v2 > src/a.sh'
LM_B2='printf v2 > src/orphan.sh'
LM_C1='printf "exit 0 # moved\n" > core/fixtures/gamma/run.sh'
LM_C2='printf "# moved\n" >> core/scripts/derive-fixture-readsets.sh'
LM_D='printf v2 > src/lonly.sh'
LM_GS='printf v2 > src/sub/f.txt'
LM_E='printf v2 > src/orphan.sh'
LM_GL='printf v2 > src/gonly.sh'
LM_GC='printf v2 > src/zonly.sh'
lt_case() { # <label> <predicate> <mutation> <ok text> [sub] [result of an identical drive already taken]
  local r; if [ -n "${6:-}" ]; then r="$6"; else r="$(lw_run "$POOL" "$1" "$3" "${5:-}")"; fi; lt_arm
  LT_LAST="$r"
  if "$2" "$r"; then ok "$4"
  else bad "$1: got sel '$(sel_of "$r")' flag $(lflag_of "$r") trace '$(trace_of "$r")': $(msg_of "$r" | tr -d '\n')"; fi
}
lt_case lc1 lc1 "$LM_C1" "(c) gamma's run.sh moved: its local set is ignored, it reads UNMAPPED, and the next trace takes it"; LC1_R="$LT_LAST"
lt_case lc2 lc2 "$LM_C2" "(c) the DERIVER moved: every local set it recorded is ignored, and gamma is taken by the next trace"
# THE REMEDY TEXT. Both announce lines tell the reader the next green push traces what is unmapped,
# and name the hand command beside it. Presence-shaped: each demands its own emitting line's text.
lrm() { msg_of "$1" | grep -qF 'UNMAPPED (keyed on the whole tree): gamma -- the next green push traces them automatically; by hand, with no sudo: bash core/scripts/derive-fixture-readsets.sh --list "gamma" --tracer sandbox'; }
# SHARED DRIVE: lrm reads lc1's state (the local world, gamma's run.sh moved, the pool), so it
# scores lc1's result rather than building and driving an identical world again.
lt_case lrm lrm "$LM_C1" "(c) the unmapped line names gamma, says the next green push traces it automatically, and gives the hand command" "" "$LC1_R"
# (h) GHOST ROWS. A fixture deleted or renamed after its trace keeps its local rows, and a committed
# map keeps a deleted fixture's rows until re-derived. Neither may make a path KNOWN: an edit to a
# path only a ghost names is an orphan, and the whole suite runs -- otherwise a present fixture that
# started reading that path after its own trace is skipped. The near-misses put both directories
# back, and the same edits then select the fixture whose row names the path.
# THE HELD SET (M5). Three consecutive discards on gamma's CURRENT key hold it back; two do not, and
# three on a key that has since moved do not.
lt_held() { # <label> <discards> <key: cur|old> <want trace> <want held>
  local t="$WORK/lh.$1" r k
  f2b_world seed_lt "$t" || broken "the held-set seed failed"
  if [ "$FXROOT" != core/fixtures ]; then
    mkdir -p "$t/$(dirname "$FXROOT")" && cp -R "$t/core/fixtures" "$t/$FXROOT" \
      && ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fxroot ) >/dev/null 2>&1 \
      || broken "could not seed the fixture root $FXROOT"
  fi
  k="$(sha_of "$t/$FXROOT/gamma/run.sh"):$(sha_of "$t/core/scripts/derive-fixture-readsets.sh")"
  [ "$3" = cur ] || k="0000:$(sha_of "$t/core/scripts/derive-fixture-readsets.sh")"
  printf 'gamma\t#discards\t%s\t%s\tLOSS CANARY\n' "$2" "$k" > "$t/.git/ai-dlc-fixture-readsets.local"
  r="$(lsel_in "$t" ':')"
  printf '%s|%s' "$(trace_of "$r")" "$(held_of "$r")"
}
LH3="$(lt_held h3 3 cur)"; lt_arm
[ "$LH3" = "|gamma" ] && { ok "(M5) three consecutive discards on gamma's current key HOLD it: no trace until the key changes"; } \
  || bad "(M5) three discards on the current key did not hold gamma back: trace|held '$LH3'"
LH2="$(lt_held h2 2 cur)"; lt_arm
[ "$LH2" = "gamma|" ] && ok "  two discards do not hold it — it is traced again" || bad "  two discards held gamma back: '$LH2'"
LHO="$(lt_held ho 3 old)"; lt_arm
[ "$LHO" = "gamma|" ] && ok "  three discards on a key that has since MOVED do not hold it" || bad "  three discards on a stale key held gamma back: '$LHO'"

# THE LAUNCHER, driven directly: a seeded `$out` naming gamma green with a captured log.
lt_drive() { # <pool> <world> <setup>; prints "<message>|<invoked|not>"
  local p="$1" t="$2" setup="$3" o
  o="$(mktemp -d "$WORK/lo.XXXXXX")" || return 1
  ( cd "$t" || exit 1
    export STUB_ARGS="$o/args" AI_DLC_READSET_LIVE_TRACE=1
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    . "$p" 2>/dev/null
    mkdir -p "$o/.log"; printf 'gamma\n' > "$o/.trace"; : > "$o/.trace.held"
    printf ok > "$o/gamma"; printf '  ok    g\n' > "$o/.log/gamma"
    eval "$setup"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_live_trace "$o" > "$o/msg" 2>&1
    grep -q 'started detached' "$o/msg" && lt_wait "$GITDIR/ai-dlc-fixture-readsets.local.lock"
    :
  )
  printf '%s|%s' "$(tr '\n' ' ' < "$o/msg")" "$([ -f "$o/args" ] && echo invoked || echo not)"
}
lt_fresh() { local t="$WORK/lf.$1"; f2b_world seed_ltc "$t" || broken "the launcher seed failed"; printf '%s' "$t"; }
LKLOCK='"$GITDIR/ai-dlc-fixture-readsets.local.lock"'
LK_LIVE="mkdir $LKLOCK && printf '%s %s\n' \$PPID \"\$(date +%s)\" > $LKLOCK/pid"
LK_DEAD="bash -c 'exit 0' & dp=\$!; wait \$dp; mkdir $LKLOCK && printf '%s %s\n' \$dp \"\$(date +%s)\" > $LKLOCK/pid"
LK_OLD="mkdir $LKLOCK && printf '%s %s\n' \$PPID 1000 > $LKLOCK/pid"
LK_NOPID_OLD="mkdir $LKLOCK && touch -t 200001010000 $LKLOCK"
LK_NOPID_NEW="mkdir $LKLOCK"
if [ "$LT_CAN" = 0 ]; then
  R="$(lt_drive "$POOL" "$(lt_fresh can0)" ':')"; lt_arm
  case "$R" in
    *"read-set live trace: skipped ("*"|not") ok "(L6) no sandbox-exec, /usr/bin/log or python3 here: the launcher says so in one line and starts nothing — today's behaviour" ;;
    *) bad "(L6) without the trace tools the launcher did not skip in one line: '$R'" ;;
  esac
  printf '  SKIP  launcher, lock and gate arms: this tree has no sandbox-exec, /usr/bin/log or python3\n'
else
  lt_l() { # <label> <setup> <want: invoked|not> <needle> <ok text>
    local r; r="$(lt_drive "$POOL" "$(lt_fresh "$1")" "$2")"; lt_arm
    case "$r" in
      *"$4"*"|$3") ok "$5" ;;
      *) bad "$1: expected '$4' and $3, got '$r'" ;;
    esac
  }
  lt_l k1 ':' invoked 'started detached for 1 unmapped fixture(s) (gamma)' "the launcher starts ONE detached trace for the green unmapped fixture and names it"
  lt_l k0 'export AI_DLC_READSET_LIVE_TRACE=0' not '' "AI_DLC_READSET_LIVE_TRACE=0 starts nothing"
  lt_l lk1 "$LK_LIVE" not 'another trace holds' "a LIVE lock is not stolen: no trace this push, and it says so"
  lt_l lk2 "$LK_DEAD" invoked 'started detached' "  a lock whose pid is DEAD is stale and recovered"
  lt_l lk3 "$LK_OLD" invoked 'started detached' "  a lock taken more than 6h ago is stale even with a live pid"
  lt_l lk4 "$LK_NOPID_OLD" invoked 'started detached' "  a lock with no pid file older than 60s is stale"
  lt_l lk5 "$LK_NOPID_NEW" not 'another trace holds' "  a lock with no pid file younger than 60s is held"
  lt_l hd "printf 'gamma\n' > \"\$o/.trace.held\"; : > \"\$o/.trace\"" not 'NOT re-tracing gamma' "(M5) a held fixture is named in one line and not traced"
  # (e) the hook half: a LINKED worktree starts nothing, in one line.
  LW_T="$(lt_fresh lw)"; ( cd "$LW_T" && git worktree add -q "$LW_T.wt" -b lwt ) >/dev/null 2>&1 || broken "could not add a linked worktree to the launcher seed"
  R="$(lt_drive "$POOL" "$LW_T.wt" ':')"; lt_arm
  case "$R" in
    *"skipped ("*"a linked worktree"*"|not") { ok "(e) from a LINKED worktree the launcher starts nothing and says so in one line"; } ;;
    *) bad "(e) a linked worktree started a trace or said nothing: '$R'" ;;
  esac
  # THE IN-POOL PREP (readset_pool_trace_prep), driven directly like the launcher: a seeded `$out/.trace`
  # naming gamma. It prints "<message>|<PT_LIST>". Two refusals share lines with readset_live_trace -- the
  # knob and the linked-worktree check -- so each is scored by its OWN arm, with a near-miss control that
  # lists gamma.
pt_drive() { # <pool> <world> <setup>; prints "<message>|<PT_LIST>"
    local p="$1" t="$2" setup="$3" o
    o="$(mktemp -d "$WORK/pt.XXXXXX")" || return 1
    ( cd "$t" || exit 1
      export AI_DLC_READSET_LIVE_TRACE=1
      fx_inproc "$ROOT/core/git-hooks/pre-push"
      . "$p" 2>/dev/null
      mkdir -p "$o/.log"; printf 'gamma\n' > "$o/.trace"
      eval "$setup"
      fx_inproc "$ROOT/core/git-hooks/pre-push"
      readset_pool_trace_prep "$o" > "$o/msg" 2>&1
      printf '%s|%s' "$(tr '\n' ' ' < "$o/msg")" "$PT_LIST"
    )
}
  R="$(pt_drive "$POOL" "$(lt_fresh pt1)" ':')"; lt_arm
  case "$R" in
    *"read-set in-pool trace: 1 fixture(s) traced in the pool: gamma"*"|gamma") { ok "(pt1) near-miss control: with AI_DLC_READSET_LIVE_TRACE=1 the in-pool prep announces gamma and lists it"; } ;;
    *) bad "(pt1) near-miss control failed, the prep did not list gamma with the knob at 1: '$R'" ;;
  esac
  R="$(pt_drive "$POOL" "$(lt_fresh pt0)" 'export AI_DLC_READSET_LIVE_TRACE=0')"; lt_arm
  case "$R" in
    "|") { ok "(pt0) AI_DLC_READSET_LIVE_TRACE=0: the in-pool prep prints nothing and PT_LIST is empty"; } ;;
    *) bad "(pt0) the knob at 0 did not silence the in-pool prep: '$R'" ;;
  esac
  # BL-701: the in-pool prep TRACES from a linked worktree (the deriver builds the clone's .git standalone),
  # where the detached launcher in (e) above still starts nothing. Same world as (e), opposite answer.
  R="$(pt_drive "$POOL" "$LW_T.wt" ':')"; lt_arm
  case "$R" in
    *"a linked worktree"*|*"skipped ("*) bad "(ptw) the in-pool prep still skips a LINKED worktree: '$R'" ;;
    *"read-set in-pool trace: 1 fixture(s) traced in the pool: gamma"*"|gamma") { ok "(ptw) from a LINKED worktree the in-pool prep announces gamma and lists it, as in the main checkout"; } ;;
    *) bad "(ptw) from a linked worktree the in-pool prep did not list gamma: '$R'" ;;
  esac
  R="$(pt_drive "$POOL" "$(lt_fresh ptm)" ':')"; lt_arm
  case "$R" in
    *"a linked worktree"*) bad "(ptw) near-miss control failed, the main checkout was called a linked worktree: '$R'" ;;
    *"traced in the pool: gamma"*"|gamma") ok "(ptw) near-miss control: in the main checkout the in-pool prep lists gamma" ;;
    *) bad "(ptw) near-miss control failed, the main checkout did not list gamma: '$R'" ;;
  esac
  # (a) and (f), through the real call site: run_fixtures in a seeded world.
  # run_fixtures GLOBS ITS OWN FIXTURE ROOT -- `core/fixtures/` in the distribution's hook,
  # `tests/fixtures/` in the consumer's, which is the one an installed tree resolves first. Read off
  # the resolved block's own glob, the way the deriver reads it, and the world is seeded under it;
  # seeded only under core/fixtures/ the consumer run found no fixtures and every arm here went red.
rf_drive() { # <pool> <name> <setup>; prints "<rc>|<lock held>|<invoked>|<verified>|<stashed>|<row>|<args>"; <lock held> is sampled at return under STUB_GO, and after lt_wait (the trace released its lock) otherwise
    local p="$1" t o
    t="$(lt_fresh "rf.$2")"; o="$WORK/rfo.$2"; mkdir -p "$o"
    if [ "$FXROOT" != core/fixtures ]; then
      mkdir -p "$t/$(dirname "$FXROOT")" && cp -R "$t/core/fixtures" "$t/$FXROOT" \
        && ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fxroot ) >/dev/null 2>&1 \
        || broken "could not seed the fixture root $FXROOT"
    fi
    ( cd "$t" || exit 1
      # THIS SUBSHELL WRITES GO, so it is the GO wait's owner; bash 3.2 has no BASHPID, so its pid is
      # read the way the hook reads its own subshell's: the PPID of a child it execs.
      export STUB_ARGS="$o/args" AI_DLC_READSET_LIVE_TRACE=1 STUB_GO_OWNER="$(exec bash -c 'printf %s "$PPID"')"
      eval "$3"
      fx_inproc "$ROOT/core/git-hooks/pre-push"
      . "$p" 2>/dev/null
      printf '%s\n' "${POOL_STALL:-}" > "$o/stall"
      fx_inproc "$ROOT/core/git-hooks/pre-push"
      run_fixtures > "$o/out" 2>&1; echo "$?" > "$o/rc"
      # `held` IS SAMPLED BEFORE lt_wait ONLY UNDER STUB_GO: the stub holds the trace there, so held=yes is
      # deterministic (arm (a): the launch returns with the lock held). Everywhere else it is sampled AFTER
      # lt_wait, where `no` means the trace released its lock; sampled at return it raced the trace on a red
      # push (arm RR).
      if [ -n "${STUB_GO:-}" ]; then
        if [ -d "$GITDIR/ai-dlc-fixture-readsets.local.lock" ]; then echo yes > "$o/held"; else echo no > "$o/held"; fi
        : > "$STUB_GO"
      fi
      lt_wait "$GITDIR/ai-dlc-fixture-readsets.local.lock"
      if [ -z "${STUB_GO:-}" ]; then
        if [ -d "$GITDIR/ai-dlc-fixture-readsets.local.lock" ]; then echo yes > "$o/held"; else echo no > "$o/held"; fi
      fi
    )
    printf '%s|%s|%s|%s|%s|%s|%s' "$(cat "$o/rc")" "$(cat "$o/held")" "$([ -f "$o/args" ] && echo invoked || echo not)" \
      "$([ -s "$t/.git/ai-dlc-fixture-verified" ] && echo verified || echo none)" \
      "$([ -f "$t/.git/ai-dlc-fixture-readsets.local.logs/gamma" ] && echo stashed || echo none)" \
      "$(grep -c '^gamma	core/fixtures/gamma/run.sh' "$t/.git/ai-dlc-fixture-readsets.local" 2>/dev/null || :)" \
      "$(cat "$o/args" 2>/dev/null)"
}
  RA="$(rf_drive "$POOL" a "export STUB_GO=\"$WORK/rf.go.a\"")"; lt_arm
  # THE STUB LEFT BY GO, OR THIS DRIVE PROVES NOTHING ABOUT DETACHMENT. `orphan` or `nolockpid` on the
  # launcher is a harness that lost its order fact, never a verdict on the launcher.
  [ "$(cat "$WORK/rf.go.a.left" 2>/dev/null)" = go ] \
    || broken "(a) the launcher's stub left its GO wait as '$(cat "$WORK/rf.go.a.left" 2>/dev/null)', not 'go' -- the detached-launch order fact was not observed"
  case "$RA" in
    "0|yes|invoked|verified|stashed|1|--list gamma --tracer sandbox --local-map .git/ai-dlc-fixture-readsets.local")
      ok "(a) a GREEN run_fixtures returns while the trace is still running, having started it for gamma with --tracer sandbox --local-map, stashed gamma's log, and the row lands" ;;
    *) bad "(a) the green run did not start a detached trace that recorded a row: '$RA' — $(tail -3 "$WORK/rfo.a/out" | tr '\n' ' ')" ;;
  esac
  RF="$(rf_drive "$POOL" f 'export STUB_RC=1')"; lt_arm
  case "$RF" in
    "0|"*"|invoked|verified|"*) ok "(f) a deriver that FAILS leaves the gate green and the verified record written — the trace never decides the push" ;;
    *) bad "(f) a failing trace changed the gate: '$RF'" ;;
  esac
  # A RED PUSH TRACES THE FIXTURE WHOSE OWN VERDICT IS ok (operator ruling: a good fixture run is a good fixture
  # run). alpha fails, gamma (unmapped) passes: the trace is invoked for gamma ALONE, gamma's log is stashed and
  # its row lands, alpha (failed, mapped) is never named, and NO whole-tree verified record is written.
  # The second world fails the UNMAPPED fixture itself: nothing is traced, because a failed fixture is never traced.
  RR="$(rf_drive "$POOL" r "printf 'exit 1\n' > $FXROOT/alpha/run.sh")"; lt_arm
  case "$RR" in
    "1|no|invoked|none|stashed|1|--list gamma --tracer sandbox --local-map .git/ai-dlc-fixture-readsets.local")
      ok "(f) a RED push still traces the unmapped fixture whose own verdict is ok (gamma), never the failing alpha, and writes no whole-tree verified record" ;;
    *) bad "(f) a red push did not trace exactly gamma without a verified record: '$RR'" ;;
  esac
  RRG="$(rf_drive "$POOL" rg "printf 'exit 1\n' > $FXROOT/gamma/run.sh")"; lt_arm
  case "$RRG" in
    "1|no|"*"|none|none||"*|"1|no|"*"|none|none|0|"*)
      # Keyed on the OUTCOME (no gamma row lands, nothing is stashed), not on whether a trace was invoked: the
      # in-pool trace starts the deriver for a failing fixture and discards it. The positive control is the
      # sibling world RR above, where a PASSING gamma lands exactly one row in the same field; it is re-read
      # here so this arm cannot pass while the row column is dead.
      case "$RR" in
        *"|stashed|1|"*) ok "(f) a FAILED unmapped fixture lands no gamma row and stashes nothing, even on a red push (control: a passing gamma landed its row)" ;;
        *) bad "(f) the positive control failed: a passing gamma landed no row, so the no-row verdict above proves nothing: '$RR'" ;;
      esac ;;
    *) bad "(f) a failed unmapped fixture landed a row or was stashed: '$RRG'" ;;
  esac
  # (k) THE LOCK ROUND TRIP (BL-463). The real readset_live_trace takes the lock while STUB_GO holds
  # the stub deriver, so the trace subshell is alive when the pid file is read. A verdict alone cannot
  # tell a right writer from a wrong one -- a lock with no start line reads HELD by design, and a
  # parent and its child share a start second -- so the arm is on the pid file's CONTENT: line 2 is
  # non-empty, line 2 is the normalised start of line 1's pid (computed by the hook's
  # readset_pid_start), and line 1 is not the pid of the process that ran the hook copy. HELD is a
  # conjunct. The driver is a separate `bash` launched with `&`, so `$!` here IS its `$$` (asserted).
  # After release the lock is gone, or stale.
  # LINE 1 IS JOINED TO A PID THE OTHER SIDE RECORDED. A pid file agreeing with itself proves only
  # that the writer read one pid twice: `tp="$PPID"` names a live process whose start it then records
  # correctly. So the stub deriver writes its own `$PPID` -- the trace subshell, seen from inside it
  # -- to STUB_PPID, and (k) demands line 1 equal it. The driver sleeps 1.1s before taking the lock,
  # so the trace subshell starts in a later second than the driver, and the control (sdiff) asserts
  # start($$) != start(the stub's recorded pid) in the same invocation, read by the fixture's own `ps`,
  # not the block's helper, which is a subject. The control is keyed on the
  # STUB's pid, not on line 1: a lock naming `$$` would make a control on line 1 read
  # "equal" for the wrong reason.
  RT_DRIVER="$WORK/rt-driver.sh"
  cat > "$RT_DRIVER" <<'RT'
pool="$1"; t="$2"; o="$3"; ref="$4"
cd "$t" || exit 1
printf '%s\n' "$$" > "$o/self"
export STUB_ARGS="$o/args" STUB_GO="$o/go" STUB_GO_OWNER="$$" STUB_PPID="$o/ppid" AI_DLC_READSET_LIVE_TRACE=1
. "$AW_LIB"
. "$pool" 2>/dev/null
mkdir -p "$o/.log"; printf 'gamma\n' > "$o/.trace"; : > "$o/.trace.held"
printf ok > "$o/gamma"; printf '  ok    g\n' > "$o/.log/gamma"
lk="$GITDIR/ai-dlc-fixture-readsets.local.lock"
# A FLOOR, NOT A BOUND: the trace subshell must start in a later second than this driver. Load can only
# lengthen it, and the sdiff control below asserts the property it buys in the same drive.
sleep 1.1  # bl868-allow: rs-trace-floor
readset_live_trace "$o" > "$o/msg" 2>&1
# THE STUB'S PPID, OR THE TRACE SUBSHELL'S DEATH. Nothing to wait for when no trace started.
if grep -q 'started detached' "$o/msg"; then
  aw_wait '[ -s "$o/ppid" ]' 'aw_status_pid "$READSET_LOCAL.status"' ''
  [ "$?" = 2 ] && aw_stalled "(k) the trace subshell neither wrote the stub's ppid nor advanced its status file or lock"
fi
cp "$lk/pid" "$o/pidfile" 2>/dev/null
p="$(sed -n 1p "$o/pidfile" 2>/dev/null | cut -d' ' -f1)"
sp="$(cat "$o/ppid" 2>/dev/null)"
a="$(LC_ALL=C TZ=UTC0 ps -o lstart= -p "$$" 2>/dev/null)"; b="$(LC_ALL=C TZ=UTC0 ps -o lstart= -p "${sp:-0}" 2>/dev/null)"
if [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ]; then echo sdiff; else echo "nosdiff($a/$b)"; fi > "$o/sdiff"
( . "$ref" 2>/dev/null; readset_pid_start "$p" ) > "$o/want" 2>/dev/null
( . "$ref" 2>/dev/null; readset_lock_stale "$lk" > "$o/judge" 2>&1; echo "$?" > "$o/rc" )
: > "$STUB_GO"
# THE LOCK GONE, OR THE SUBSHELL THAT OWES ITS RELEASE GONE -- either way `after` is final, and is read now.
aw_wait '[ ! -d "$lk" ]' 'aw_status_pid "$READSET_LOCAL.status"' ''
[ "$?" = 2 ] && aw_stalled "(k) the trace subshell neither released $lk nor advanced its status file after GO"
if [ ! -d "$lk" ]; then echo gone > "$o/after"
elif ( . "$ref" 2>/dev/null; readset_lock_stale "$lk" ) >/dev/null 2>&1; then echo stale > "$o/after"
else echo held > "$o/after"; fi
RT
  rt_drive() { # <pool> <name>; prints "<self=launched>|<l1!=launched>|<l2 set>|<l2=start(l1)>|<rc>|<after>|<started>|<l1=stub's ppid>|<control>"
    local t o lp l1 l2 sp
    t="$(lt_fresh "rt.$1.$2")"; o="$WORK/rto.$2"; mkdir -p "$o"
    bash "$RT_DRIVER" "$1" "$t" "$o" "$POOL" > "$o/driver.out" 2>&1 &
    lp=$!; wait "$lp"
    l1="$(sed -n 1p "$o/pidfile" 2>/dev/null | cut -d' ' -f1)"; l2="$(sed -n 2p "$o/pidfile" 2>/dev/null)"
    sp="$(cat "$o/ppid" 2>/dev/null)"
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s' \
      "$([ "$(cat "$o/self" 2>/dev/null)" = "$lp" ] && echo self || echo noself)" \
      "$([ -n "$l1" ] && [ "$l1" != "$lp" ] && echo child || echo "pid=${l1:-none}")" \
      "$([ -n "$l2" ] && echo start || echo nostart)" \
      "$([ -n "$l2" ] && [ "$l2" = "$(cat "$o/want" 2>/dev/null)" ] && echo match || echo nomatch)" \
      "$(cat "$o/rc" 2>/dev/null)" "$(cat "$o/after" 2>/dev/null)" \
      "$(grep -q 'started detached' "$o/msg" 2>/dev/null && echo started || echo notstarted)" \
      "$([ -n "$sp" ] && [ "$l1" = "$sp" ] && echo ppid || echo "noppid(${sp:-none})")" \
      "$(cat "$o/sdiff" 2>/dev/null || echo nosdiff)"
  }
  RT_OK='self|child|start|match|1|'*'|started|ppid|sdiff'
  if ! ps_sandbox_skip "(k) the launcher's lock round trip"; then
    RK="$(rt_drive "$POOL" k)"; lt_arm
    case "$RK" in
      $RT_OK) case "$RK" in *"|gone|"*|*"|stale|"*)
           ok "(k) the real launcher's lock names the trace subshell's pid with its own start time, reads HELD while it runs, and is gone or stale after: '$RK'" ;;
         *) bad "(k) the lock outlived its trace as HELD: '$RK'" ;; esac ;;
      *) bad "(k) the launcher's lock is not the trace subshell's pid with its start time, HELD: '$RK' -- $(tr '\n' '/' < "$WORK/rto.k/pidfile" 2>/dev/null)" ;;
    esac
  fi
  # (t) THE WALL-CLOCK CEILING. A consumer's detached trace outlived its push by 42 minutes holding a
  # `log stream` per fixture. The real launcher is driven against a stub deriver that forks a sleeping
  # GRANDCHILD (the `log stream` it stands for), writes its own pid, the grandchild's, a trace root and
  # a map temp, and then sleeps forever (hang) or until told to finish (finish). Every liveness read is
  # `kill -0` on a pid or group the subject or the stub RECORDED, each beside a LIVE control read in the
  # same drive before the ceiling, never a process-table grep. The driver's wait is bounded; on expiry
  # it reaps by those recorded groups and still scores, so a watchdog that never kills cannot hang the shard.
  #   (t1) hang, ceiling 3s: grandchild, deriver group and subshell group gone; status `exit timeout`;
  #        lock released; trace root and map temp removed; map unchanged; report reads TIMED OUT
  #   (t2) finish, ceiling 900s: the normal path -- `exit 0`, lock released, and group `$tp` empty,
  #        which is the watchdog's `sleep` reaped (it is the only other member of that group)
  #   (t3) hang, ceiling 900s, and a hand's `kill -TERM -- -<lock pid>`: the subshell forwards it to the
  #        deriver's group, so the grandchild is gone too and the exit is written
  LT_HANG='#!/bin/bash
tail -f /dev/null </dev/null >/dev/null 2>&1 &
printf "%s\n" "$!" > "$STUB_GC"
printf "%s\n" "$$" > "$STUB_SELF"
mkdir -p "$AI_DLC_READSET_TRACE_ROOT"
lm=""; while [ $# -gt 0 ]; do case "$1" in --local-map) lm="$2"; shift ;; esac; shift; done
printf "partial\n" > "$lm.tmp.$$"
if [ "$STUB_MODE" = hang ]; then while :; do sleep 1; done; fi
while [ ! -f "$STUB_GO" ] && kill -0 "$STUB_GO_OWNER" 2>/dev/null; do sleep 0.1; done
rm -f "$lm.tmp.$$"; kill "$(cat "$STUB_GC")" 2>/dev/null
exit 0'
  CT_DRIVER="$WORK/ct-driver.sh"
  cat > "$CT_DRIVER" <<'CT'
pool="$1"; t="$2"; o="$3"; ceil="$4"; mode="$5"; hk="$6"
cd "$t" || exit 1
mkdir -p "$o/tmp" "$o/.log"
export STUB_GC="$o/gc" STUB_SELF="$o/self" STUB_GO="$o/go" STUB_GO_OWNER="$(exec bash -c 'printf %s "$PPID"')" STUB_MODE="$mode" AI_DLC_READSET_LIVE_TRACE=1 AI_DLC_READSET_TRACE_CEILING="$ceil" TMPDIR="$o/tmp/"
. "$AW_LIB"
AW_SLEEP=/bin/sleep
. "$pool" 2>/dev/null
# THE CEILING'S CLOCK STARTS AFTER THE LIVE READ (BL-868). The watchdog's `sleep "$cl"` resolves on PATH, so a perl
# stand-in (perl, so it is no counted bash start) holds a sleep of exactly the ceiling until the driver has read its
# live controls, then runs the real sleep: the ceiling is still the subject's, but a box slow enough to take 3s
# between the stub's records and the live read can no longer read the groups `gone` before the kill. The real
# sleep is a FORKED child, never an exec: `ps etime` counts from fork, so an exec'd sleep would carry the hold in
# its elapsed time and aw_overslept would read a correct ceiling as overslept. Every other sleep (the grace loop,
# the stub's own, noceil's 600) is exec'd straight through.
mkdir -p "$o/sbin"
printf '%s\n' '#!/usr/bin/perl' \
  'if (@ARGV == 1 && $ARGV[0] eq $ENV{STUB_CEIL_ARG}) {' \
  '  select(undef, undef, undef, 0.05) until -e $ENV{STUB_REL};' \
  '  my $c = fork(); die "fork" unless defined $c; if ($c == 0) { exec "/bin/sleep", @ARGV; exit 127 }' \
  '  waitpid($c, 0); exit($? >> 8);' \
  '}' \
  'exec "/bin/sleep", @ARGV;' > "$o/sbin/sleep" && chmod +x "$o/sbin/sleep" || exit 1
export PATH="$o/sbin:$PATH" STUB_CEIL_ARG="$ceil" STUB_REL="$o/rel"
printf 'gamma\n' > "$o/.trace"; : > "$o/.trace.held"
printf ok > "$o/gamma"; printf '  ok    g\n' > "$o/.log/gamma"
printf 'alpha\t#deriver\tseeded\n' > "$READSET_LOCAL"; cp "$READSET_LOCAL" "$o/map.before"
lk="$GITDIR/ai-dlc-fixture-readsets.local.lock"
al() { kill -0 -- "$1" 2>/dev/null && echo alive || echo gone; }
readset_live_trace "$o" > "$o/msg" 2>&1
# THE STUB'S THREE RECORDS, OR THE TRACE SUBSHELL'S DEATH. The live controls below are read only once all
# three exist, so a slow stub start no longer reads as a dead one.
if grep -q 'started detached' "$o/msg"; then
  aw_wait '[ -s "$o/gc" ] && [ -s "$o/self" ] && ls "$READSET_LOCAL".tmp.* >/dev/null 2>&1' 'aw_status_pid "$READSET_LOCAL.status"' ''
  [ "$?" = 2 ] && aw_stalled "(t) the stub deriver neither wrote its gc, self and map-temp records nor advanced"
fi
# THE LOCK'S PID FILE is written by the trace subshell before it launches the deriver, so it exists once the
# stub's records do; read it here, never right after the launcher returns.
tp="$(sed -n 1p "$lk/pid" 2>/dev/null | cut -d' ' -f1)"
gc="$(cat "$o/gc" 2>/dev/null)"; dp="$(cat "$o/self" 2>/dev/null)"
tr="$(ls -d "$o/tmp/"ai-dlc-readset-live.* 2>/dev/null)"
case "$tp" in ''|*[!0-9]*) tp=0 ;; esac; case "$dp" in ''|*[!0-9]*) dp=0 ;; esac; case "$gc" in ''|*[!0-9]*) gc=0 ;; esac
printf '%s,%s,%s,%s,%s' "$(al "-$tp")" "$(al "-$dp")" "$(al "$gc")" "$([ -n "$tr" ] && [ -d "$tr" ] && echo tr || echo notr)" \
  "$(ls "$READSET_LOCAL".tmp.* >/dev/null 2>&1 && echo tmp || echo notmp)" > "$o/live"
: > "$o/rel"
[ "$hk" = hk ] && kill -TERM -- "-$tp" 2>/dev/null
[ "$mode" = finish ] && : > "$STUB_GO"
# THE LOCK GONE, OR ITS OWNER GONE, OR A FINAL STALL. It used to wait `ceiling + 8` seconds (4 at the
# 900s ceiling) and read `held` past that, so a correct watchdog slowed by load read as no ceiling at
# all. Now the wait ends on the release or on the trace subshell's death. The progress watched is the
# WATCHDOG's side only -- status file, lock, and group $tp's members with their state and CPU time --
# never the deriver's group: the hang stub forks a `sleep 1` there every second, so a signature that
# read it would never stall and a watchdog that never fires would be waited on forever. A stall is
# FINAL only when the subject owes nothing more: the deriver's group is gone (nothing left for a
# watchdog to end), or the subject's OWN promise has lapsed, read from the status file it wrote:
# `start + ceiling + 5`, the 5 being its own TERM-to-KILL grace. Neither is a fixture constant; a stall
# inside the promise is the watchdog asleep in its `sleep "$cl"`, and the wait goes on. That is how
# noceil (the watchdog sleeping 600s against a 3s promise) still reads `held`.
ct_cl="$(sed -n 's/^ceiling //p' "$READSET_LOCAL.status" 2>/dev/null)"; case "$ct_cl" in ''|*[!0-9]*) ct_cl="$ceil" ;; esac
aw_wait '[ ! -d "$lk" ]' 'aw_status_pid "$READSET_LOCAL.status"' 'aw_overslept "$tp" "$ct_cl"'
[ "$tp" != 0 ] && aw_wait '! kill -0 -- "-$tp" 2>/dev/null' '' 'aw_group_settled "$tp"'
printf '%s,%s,%s,%s,%s,%s,%s' "$([ -d "$lk" ] && echo held || echo released)" "$(al "-$tp")" "$(al "-$dp")" "$(al "$gc")" \
  "$([ -n "$tr" ] && [ -d "$tr" ] && echo tr || echo notr)" "$(ls "$READSET_LOCAL".tmp.* >/dev/null 2>&1 && echo tmp || echo notmp)" \
  "$(cmp -s "$o/map.before" "$READSET_LOCAL" && echo same || echo moved)" > "$o/after"
sed -n 's/^exit //p' "$READSET_LOCAL.status" 2>/dev/null > "$o/exit"
readset_trace_report "" > "$o/rep" 2>&1
# REAP BY RECORDED PID AND GROUP ONLY. A watchdog that never kills may have left all three alive; the kill is not scored.
[ "$dp" != 0 ] && kill -KILL -- "-$dp" 2>/dev/null; [ "$gc" != 0 ] && kill -KILL "$gc" 2>/dev/null
[ "$tp" != 0 ] && kill -KILL -- "-$tp" 2>/dev/null
:
CT
  seed_ct() { # <t>: seed() plus the TRACKED hanging stub deriver
    f2b_world seed "$1" || return 1
    mkdir -p "$1/${LT_DVP%/*}" && printf '%s\n' "$LT_HANG" > "$1/$LT_DVP" || return 1
    ( cd "$1" && git add -A && git -c user.email=f@f -c user.name=f commit -qm hang ) >/dev/null 2>&1
  }
  ct_drive() { # <pool> <name> <ceiling> <hang|finish> [hk]; prints "<live>|<after>|<exit>|<report>"
    local t="$WORK/ct.$2" o="$WORK/cto.$2" rp
    f2b_world seed_ct "$t" || { printf 'SEED FAILED'; return 1; }
    mkdir -p "$o"
    ( inproc -- "$CT_DRIVER" "$1" "$t" "$o" "$3" "$4" "${5:-}" ) > "$o/driver.out" 2>&1
    rp=other
    grep -qF 'TIMED OUT at the 3s ceiling' "$o/rep" 2>/dev/null && grep -qF 'WARN  trace-report warning: the last trace TIMED OUT' "$o/rep" && rp=timed
    grep -qF 'finished, exit timeout' "$o/rep" 2>/dev/null && rp=finished-timeout
    grep -qF 'finished, exit 0' "$o/rep" 2>/dev/null && rp=finished-0
    printf '%s|%s|%s|%s' "$(cat "$o/live" 2>/dev/null)" "$(cat "$o/after" 2>/dev/null)" "$(cat "$o/exit" 2>/dev/null)" "$rp"
  }
  # (t4) THE WATCHDOG'S SLEEP ON A FAST TRACE. A deriver that exits at once has the subshell stop the
  # watchdog while it is still starting its `sleep`; every TERM trap the watchdog carried could leave
  # that sleep reparented to init for the whole ceiling. The leaked sleep keeps its process group, so
  # `kill -0 -- -<trace pid>` once that pid is gone reads it directly: the group must empty. The trace
  # pid is the status file's `pid`, written by the subject. FX_REPS clean launches are required of the
  # fix. The traps it replaced leaked here too rarely for a verdict (the KILL-to-`jobs -p` trap 0 of 800
  # idle, 18 of 3600 under 12 concurrent drives), so this arm guards the post-reap sweep, which leaks on every
  # launch without it; a handler restored on the watchdog is scored on (t4w).
  # Control, same drive: a group this driver started under `set -m` reads alive by the same
  # `kill -0 -- -<pgid>` before it is killed by that pgid.
  FX_REPS=30
  FX_DRIVER="$WORK/fx-driver.sh"
  cat > "$FX_DRIVER" <<'FX'
pool="$1"; t="$2"; o="$3"; reps="$4"; stop1="$5"
cd "$t" || exit 1
mkdir -p "$o/tmp" "$o/.log"
export AI_DLC_READSET_LIVE_TRACE=1 AI_DLC_READSET_TRACE_CEILING=777 TMPDIR="$o/tmp/"
. "$AW_LIB"
AW_SLEEP=/bin/sleep
. "$pool" 2>/dev/null
lk="$GITDIR/ai-dlc-fixture-readsets.local.lock"
set -m; tail -f /dev/null </dev/null >/dev/null 2>&1 & cg=$!; set +m
if kill -0 -- "-$cg" 2>/dev/null; then ctl=alive; else ctl=dead; fi
kill -- "-$cg" 2>/dev/null; wait "$cg" 2>/dev/null
ran=0; leaks=0; fin=0; i=0
while [ "$i" -lt "$reps" ]; do
  i=$((i + 1))
  printf 'gamma\n' > "$o/.trace"; : > "$o/.trace.held"; printf ok > "$o/gamma"; printf '  ok    g\n' > "$o/.log/gamma"
  rm -f "$READSET_LOCAL.status"
  readset_live_trace "$o" > "$o/msg" 2>&1
  grep -q 'started detached' "$o/msg" || continue
  ran=$((ran + 1))
  # THE LOCK GONE OR ITS OWNER GONE; THEN THE OWNER GONE; THEN ITS GROUP GONE. Each used to be a tick
  # count (5s, 5s, 2s) and the last one, expiring, scored a LEAK -- so a box slow to reap read as the
  # defect this arm exists for. Now a leak is the binary fact the hook guarantees against: group $tp
  # still has a member after $tp itself is gone and that member, with its state and CPU time, moves
  # nothing for AW_STALL polls. The watchdog's leaked `sleep` is exactly that. A member that is dying or
  # still running changes the signature and resets the count. The two waits before it end on events.
  aw_wait '[ ! -d "$lk" ]' 'aw_status_pid "$READSET_LOCAL.status"' ''
  tp="$(sed -n 's/^pid //p' "$READSET_LOCAL.status" 2>/dev/null)"
  case "$tp" in ''|*[!0-9]*) continue ;; esac
  grep -qx 'exit 0' "$READSET_LOCAL.status" && fin=$((fin + 1))
  aw_wait '! kill -0 "$tp" 2>/dev/null' '' ''
  aw_wait '! kill -0 -- "-$tp" 2>/dev/null' '' 'aw_group_settled "$tp"'
  if kill -0 -- "-$tp" 2>/dev/null; then
    leaks=$((leaks + 1))
    kill -- "-$tp" 2>/dev/null
    [ "$stop1" = 1 ] && break
  fi
done
printf '%s|%s|%s|%s|%s' "$ctl" "$i" "$ran" "$fin" "$leaks" > "$o/res"
FX
  # (t4)'s deriver exits once the WATCHDOG'S SLEEP EXISTS, never before: it waits on that `sleep` in its
  # parent's process group (the trace subshell leads that group). Exiting at once, the stop could land before
  # the watchdog had forked its sleep, so that launch had nothing to leak and nosweep's stop-at-first-leak drive
  # ran a load-dependent number of launches. Ordered on the sleep, every launch leaves one to sweep: nosweep
  # leaks on the first and the shipped sweep is exercised on all FX_REPS. The wait has no bound: a deriver that
  # never shows the sleep hangs until the gate's watchdog, a hang to read and never a verdict.
  seed_fxw() { # <t>: seed() plus a TRACKED deriver stub that exits once the watchdog's sleep is up
    f2b_world seed "$1" || return 1
    mkdir -p "$1/${LT_DVP%/*}" && printf '%s\n' '#!/bin/bash' \
      'until pgrep -g "$PPID" -x sleep >/dev/null 2>&1; do' \
      '  /bin/sleep 0.01' \
      'done' 'exit 0' > "$1/$LT_DVP" || return 1
    ( cd "$1" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fastw ) >/dev/null 2>&1
  }
  fx_drive() { # <pool> <name> <reps> <stop at first leak: 0|1>; prints "<control>|<reps>|<started>|<exit 0>|<leaks>"
    local t="$WORK/fx.$2" o="$WORK/fxo.$2"
    f2b_world seed_fxw "$t" || { printf 'SEED FAILED'; return 1; }
    mkdir -p "$o"
    ( inproc -- "$FX_DRIVER" "$1" "$t" "$o" "$3" "$4" ) > "$o/driver.out" 2>&1
    cat "$o/res" 2>/dev/null
  }
  RT4="$(fx_drive "$POOL" t4 "$FX_REPS" 0)"; lt_arm
  case "$RT4" in
    "alive|$FX_REPS|$FX_REPS|$FX_REPS|0") ok "(t4) $FX_REPS fast traces (deriver exits once the watchdog's sleep is up, ceiling 777s): every one finished exit 0 and its process group was empty once its pid was gone -- the watchdog's sleep was never left behind (control: a live group read alive)" ;;
    *) bad "(t4) a fast trace left its watchdog's sleep alive, or the drive did not run: control|reps|started|exit0|leaks = '$RT4'" ;;
  esac
  # (t4w) THE WATCHDOG CARRIES NO TERM HANDLER WHILE ITS SLEEP RUNS. The forked child of the watchdog's
  # `sleep "$cl" &` holds any TERM handler the watchdog has until it execs, so a sweep TERM reaching it in that
  # window is handled and lost and the exec starts a sleep nothing stops. Whether a TERM lands in that window
  # follows the scheduler, so a leak count over traces reads 0 whenever the stop arrives after the exec, a
  # handler or not. This arm decides the property that window depends on, with no race in it: the shipped
  # watchdog subshell, extracted from readset_live_trace in the pool block, runs alone with a stub `sleep` that
  # TERMs its parent (the watchdog, blocked in `wait`) and then exits. The TERM is posted before the stub exits,
  # so a watchdog with no handler dies by it (status 143); a handler, or an ignore, leaves it to run on and exit 0.
  # Its `dp` is empty, so the code past the wait signals nothing. The stub's marker is the control.
  wd_probe() { # <pool> <tag>: prints "<watchdog lines>|<ran|notran>|<watchdog status>", or "EXTRACT <rc>"
    local d="$WORK/wd.$2" r
    mkdir -p "$d/bin"; rm -f "$d/ran"
    awk '
      /^readset_live_trace\(\) \{/ { inf = 1 }
      inf && /^}$/ { inf = 0 }
      inf { L[++n] = $0; if (index($0, "sleep \"$cl\" & s=$!")) { hit++; at = n } }
      END {
        if (hit != 1) exit 3
        for (b = at; b > 0 && L[b] != "    ("; b--) ;
        for (e = at; e <= n && L[e] != "    ) &"; e++) ;
        if (b == 0 || e > n) exit 4
        for (i = b; i <= e; i++) print L[i]
      }' "$1" > "$d/wd.sh" || { r=$?; printf 'EXTRACT %s' "$r"; return 0; }
    printf '#!/bin/bash\n: > "%s/ran"\nkill -TERM "$PPID"\nexit 0\n' "$d" > "$d/bin/sleep" && chmod +x "$d/bin/sleep" || broken "(t4w) cannot write the stub sleep"
    r="$( cl=777; dp=""; PATH="$d/bin:$PATH"; eval "$(cat "$d/wd.sh")"; wait "$!"; echo "$?" )"
    printf '%s|%s|%s' "$(grep -c . "$d/wd.sh")" "$([ -e "$d/ran" ] && echo ran || echo notran)" "$r"
  }
  RT4W="$(wd_probe "$POOL" t4w)"; lt_arm
  case "$RT4W" in
    [1-9]*"|ran|143") ok "(t4w) the shipped watchdog, TERMed by its own sleep while it waits on it, dies by that TERM (status 143): it carries no handler that its sleep's fork-to-exec window could lose a sweep TERM to (control: the stub sleep ran)" ;;
    *) bad "(t4w) the shipped watchdog did not die by the TERM its sleep sent, or the probe did not run: lines|stub|status = '$RT4W'" ;;
  esac
  CT_LIVE='alive,alive,alive,tr,tmp'
  CT_T1="$CT_LIVE|released,gone,gone,gone,notr,notmp,same|timeout|timed"
  RT1="$(ct_drive "$POOL" t1 3 hang)"; lt_arm
  if [ "$RT1" = "$CT_T1" ]; then
    ok "(t1) at a 3s ceiling a hung deriver's GRANDCHILD, its group and the subshell's group are gone (each alive in the same drive before it), status reads exit timeout, the lock is released, the trace root and map temp are removed, the map is unchanged, and the report says TIMED OUT"
  else
    bad "(t1) the ceiling did not end a hung trace cleanly: want '$CT_T1', got '$RT1'"
  fi
  RT2="$(ct_drive "$POOL" t2 900 finish)"; lt_arm
  case "$RT2" in
    "$CT_LIVE|released,gone,gone,gone,notr,notmp,same|0|finished-0") ok "(t2) at a 900s ceiling the normal finish is unchanged: exit 0, lock released, and group \$tp is empty -- the watchdog's sleep was reaped, not left for 900s" ;;
    *) bad "(t2) the normal finish changed under the ceiling: '$RT2'" ;;
  esac
  RT3="$(ct_drive "$POOL" t3 900 hang hk)"; lt_arm
  case "$RT3" in
    "$CT_LIVE|released,gone,gone,gone,notr,notmp,same|"[0-9]*"|"*) ok "(t3) a hand's kill -TERM of the lock's group is forwarded to the deriver's group: the grandchild is gone, the exit is written and the lock released" ;;
    *) bad "(t3) a TERM to the lock's group left the deriver or its child running, or wrote no exit: '$RT3'" ;;
  esac
  aw_gate
fi

# THE LOCK'S START TIME (BL-463). `kill -0` alone reads a REUSED pid as a live trace, so the lock
# records the start time of its pid on line 2 and the reader compares it. Six worlds, judged by
# calling readset_lock_stale directly and reading its exact return code (0 stale, 1 held, anything
# else is an error and never scores as either) and whether it printed the ps-fallback announcement.
# These run `ps`, which is setuid and refused by the read-set deriver's sandbox. Under that sandbox
# ps_sandbox_skip SKIPs them and the rest of the fixture runs to a verdict; on every ordinary run
# they run. Reaching a verdict is not being mapped: a hand `--tracer sandbox` trace can still OMIT
# this fixture when the stream drops reports in its window. The post-green `--local-map` trace
# discards its window as TRIP regardless, because the detector's own probe execs /usr/bin/log,
# which that profile tags.
# suite-pole-guard stays ps-free instead, so it carries none of these worlds.
#
# THE BLOCK BELOW IS NOT RE-INDENTED under its `if`: it carries a heredoc whose terminator must sit
# at column 0. It ends at the line `fi # end of the ps-dependent start-time worlds`.
#
# THE LOCK PID IS $LOCKPID, the `sleep` started at the top, NEVER `$$`. Each world is judged by a
# fresh `bash` (PJ_JUDGE) launched at least 2s after that sleep, and the judge asserts in the same
# invocation that its own start differs from the lock pid's (ctl). A judge sharing the lock pid's
# start second cannot tell a reader or helper that reads `$$` from a right one: the fixture refuses.
#
# EVERY SEED COMES FROM THE BLOCK'S OWN WRITER. The seed lib is readset_pid_start plus the block's own
# writer line, extracted, so the right-start lock is what the real writer emits, never a string typed
# here, so the seed and the judge cannot agree by symmetry.
#   wrong       a LIVE pid with a start time it never had (a reused pid)              -> stale
#   right       the real writer's lock for that pid, judged under LC_ALL=C TZ=UTC0     -> held, silent
#   legacylive  `pid epoch` only, as an older hook wrote it, live pid                  -> held, silent
#   legacydead  the same with a dead pid                                               -> stale, silent
#   psfail      the real writer's lock, written AND judged with a PATH `ps` that exits 1 -> held, silent
#               (BL-686: the helper's perl sysctl fallback reads the same start, as it must under
#               sandbox-exec, which refuses the setuid /bin/ps), the fallback's day FORCED to 19
#   psfailpad   the same with the fallback's day FORCED to 5                          -> held, silent
# THE FALLBACK'S DAY IS FORCED, NEVER THE CLOCK'S (BL-868). `perl`'s scalar gmtime pads a day of 1-9
# ("Nov  5") and not 10-31 ("Nov 19"), so whether the helper's word re-join matters on the fallback
# path is a property of the lock pid's start date. Left to the clock, a helper that kept the padding moved `psfail` on
# days 1-9 only. PJDay.pm (built below, loaded through PERL5OPT in these two worlds alone) shifts the
# fallback's gmtime to a chosen day of the same month, so every run holds one padded and one unpadded
# fallback string, and a guard refuses unless the padded raw string differs from its re-joined form
# and the unpadded one does not.
#   bothfail    the same, with a PATH `perl` that exits 1 as well                    -> held, announced
#   split       written under de_DE/Asia/Tokyo, judged under fr_FR/America/Los_Angeles -> whatever `right` reads
# `split` is scored RELATIVE to `right` under the same lib: on the shipped block `right` is asserted
# held and silent, so `split` is too.
# SANDBOX PROBE: the detector forced to "inside a sandbox" on a run where `ps` works must refuse
# (`broken`, exit 2), never SKIP. Run on every ordinary run; inside a real sandbox `ps` fails, so the
# refusal it proves cannot be reached there and the arm is not counted.
if [ "$IN_SANDBOX" = 0 ]; then
  lt_arm
  _sm="$( ( IN_SANDBOX=1; ps_sandbox_skip "forced-detector probe" ) 2>&1 >/dev/null; echo "rc=$?" )"
  [ -d "$WORK" ] && kill -0 "$LOCKPID" 2>/dev/null || broken "the SANDBOX PROBE subshell's exit ran the EXIT trap: WORK or the lock-pid sleep is gone"
  case "$_sm" in
    *"yet ps -o lstart= -p \$\$ works"*"FIXTURE BROKEN"*"rc=2")
      ok "CONTROL sandbox-detector: the detector forced to 'sandboxed' where ps works refuses (FIXTURE BROKEN, exit 2) instead of skipping the start-time worlds" ;;
    *) bad "CONTROL sandbox-detector: the detector forced to 'sandboxed' where ps works did not refuse: '$(printf '%s' "$_sm" | tr '\n' ' ')'" ;;
  esac
fi
if ! ps_sandbox_skip "lock start-time worlds (BL-463)"; then
PJW="$WORK/pj"; mkdir -p "$PJW" || broken "could not create the lock-start world"
pj_lib() { # <pool copy> <out>: the reader and its helper, as the hook defines them
  { awk '/^readset_pid_start\(\) \{/,/^}/' "$1"; awk '/^readset_lock_stale\(\) \{/,/^}/' "$1"; } > "$2"
}
PJ_LIB="$PJW/lib.sh"; pj_lib "$POOL" "$PJ_LIB"
[ "$(grep -c '^[a-z_]*() {' "$PJ_LIB")" -eq 2 ] && grep -q '^readset_pid_start() {' "$PJ_LIB" && grep -q '^readset_lock_stale() {' "$PJ_LIB" \
  || broken "could not extract readset_pid_start and readset_lock_stale from the pool block"
PJ_WLINE='    readset_lock_write "$lk" "$sp"'
PJ_N="$(grep -cxF -- "$PJ_WLINE" "$POOL")" || PJ_N=0
[ "$PJ_N" -eq 1 ] || broken "the lock writer line ($PJ_WLINE) occurs $PJ_N time(s) in the pool block, not 1"
PJ_SEEDLIB="$PJW/seed.sh"
{ awk '/^readset_pid_start\(\) \{/,/^}/' "$POOL"
  awk '/^readset_lock_write\(\) \{/,/^}/' "$POOL"
  printf 'pj_write_lock() { local sp="$1" lk="$2"\n'
  grep -xF -- "$PJ_WLINE" "$POOL"
  printf '}\n'
} > "$PJ_SEEDLIB"
grep -q '^readset_lock_write() {' "$PJ_SEEDLIB" || broken "could not extract readset_lock_write from the pool block"
kill -0 "$LOCKPID" 2>/dev/null || broken "the lock-pid sleep $LOCKPID is not alive"
pj_live_start() {
fx_inproc "$ROOT/core/git-hooks/pre-push"
PJ_LIVE="$( . "$PJ_SEEDLIB"; readset_pid_start "$LOCKPID" )" || PJ_LIVE=""
}
pj_live_start
[ -n "$PJ_LIVE" ] || broken "readset_pid_start printed nothing for the live lock pid $LOCKPID -- no world below can reach the start comparison"
for _w in wrong right legacylive legacydead psfail psfailpad bothfail split; do mkdir -p "$PJW/j.$_w.lock" || broken "could not create the $_w lock world"; done
printf '%s %s\n%s\n' "$LOCKPID" "$(date +%s)" 'Thu Jan  1 00:00:00 1970' > "$PJW/j.wrong.lock/pid"
_s="$(sed -n 2p "$PJW/j.wrong.lock/pid")"; _s="$(set -f; set -- $_s; printf '%s' "$*")"
[ "$_s" != "$PJ_LIVE" ] || broken "the wrong-start seed '$_s' equals the live start '$PJ_LIVE' -- the world cannot discriminate"
( . "$PJ_SEEDLIB"; pj_write_lock "$LOCKPID" "$PJW/j.right.lock" )
[ "$(sed -n 1p "$PJW/j.right.lock/pid" | cut -d' ' -f1)" = "$LOCKPID" ] && [ "$(sed -n 2p "$PJW/j.right.lock/pid")" = "$PJ_LIVE" ] \
  || broken "the real writer did not record pid $LOCKPID and its start '$PJ_LIVE': $(tr '\n' '/' < "$PJW/j.right.lock/pid")"
cp "$PJW/j.right.lock/pid" "$PJW/j.bothfail.lock/pid"
printf '%s %s\n' "$LOCKPID" "$(date +%s)" > "$PJW/j.legacylive.lock/pid"
bash -c 'exit 0' & _dp=$!; wait "$_dp"
printf '%s %s\n' "$_dp" "$(date +%s)" > "$PJW/j.legacydead.lock/pid"
_a="$(LC_ALL=de_DE.UTF-8 TZ=Asia/Tokyo ps -o lstart= -p "$LOCKPID")"; _b="$(LC_ALL=fr_FR.UTF-8 TZ=America/Los_Angeles ps -o lstart= -p "$LOCKPID")"
[ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" != "$_b" ] \
  || broken "unpinned ps reads the same start under the two split environments ('$_a' / '$_b') -- the split world cannot discriminate"
( export LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8 TZ=Asia/Tokyo; . "$PJ_SEEDLIB"; pj_write_lock "$LOCKPID" "$PJW/j.split.lock" )
[ "$(sed -n 2p "$PJW/j.split.lock/pid")" = "$PJ_LIVE" ] || broken "the writer under de_DE/Tokyo did not record the pinned start '$PJ_LIVE'"
mkdir -p "$PJW/psbin/both" && printf '#!/bin/bash\nexit 1\n' > "$PJW/psbin/ps" && chmod +x "$PJW/psbin/ps" || broken "could not build the failing ps stub"
cp "$PJW/psbin/ps" "$PJW/psbin/both/ps" && cp "$PJW/psbin/ps" "$PJW/psbin/both/perl" || broken "could not build the failing ps+perl stubs"
# The psfail world's positive answer comes from the fallback, so it must be able to give one HERE:
# a fixture on a host where the perl read is empty would score the fallback's absence as its presence.
# PERL IS OPTIONAL (BL-686): a host with no perl, or not macOS, cannot give it, and that is a SKIP of
# exactly the three cells that need it -- never `broken`, and never a false kill. PJ_PERL gates them.
pj_psfail_start() {
fx_inproc "$ROOT/core/git-hooks/pre-push"
_pf="$( . "$PJ_SEEDLIB"; PATH="$PJW/psbin:$PATH"; readset_pid_start "$LOCKPID" )" || _pf=""
}
pj_psfail_start
PJ_PERL=1
if [ "$_pf" != "$PJ_LIVE" ]; then
  PJ_PERL=0
  printf '  SKIP  psfail and psfailpad worlds: with ps stubbed the perl fallback read '"'"'%s'"'"' for the lock pid, not its start -- no usable perl here (it is optional)\n' "$_pf"
fi
# THE FORCED FALLBACK DAY (BL-868). PJDay.pm shifts perl's gmtime to day N of the same month, so the
# psfail world (N=19) and the psfailpad world (N=5) hold an unpadded and a padded fallback string on
# every calendar day. Each world is written by the real writer and judged under the same N.
mkdir -p "$PJW/psbin/p5" || broken "could not create the PJDay module dir"
cat > "$PJW/psbin/p5/PJDay.pm" <<'PM'
package PJDay;
sub import {
  my $d = $_[1];
  no warnings;
  *CORE::GLOBAL::gmtime = sub (;$) {
    my $t = @_ ? $_[0] : time;
    if (wantarray) { return CORE::gmtime($t); }
    my $s = scalar CORE::gmtime($t);
    substr($s, 8, 2) = sprintf("%2d", $d);
    return $s;
  };
}
1;
PM
if [ "$PJ_PERL" = 1 ]; then
  # DISCRIMINATION GUARD: the padded day's raw fallback text must differ from its re-joined form, and the
  # unpadded day's must not -- else the two worlds no longer separate a re-joining helper from one that does not.
  _r5="$(PERL5LIB="$PJW/psbin/p5" PERL5OPT=-MPJDay=5 perl -e 'print scalar gmtime')"
  _r19="$(PERL5LIB="$PJW/psbin/p5" PERL5OPT=-MPJDay=19 perl -e 'print scalar gmtime')"
  _n5="$(set -f; set -- $_r5; printf '%s' "$*")"; _n19="$(set -f; set -- $_r19; printf '%s' "$*")"
  [ -n "$_r5" ] && [ "$_r5" != "$_n5" ] && [ -n "$_r19" ] && [ "$_r19" = "$_n19" ] \
    || broken "the forced fallback days do not discriminate: day 5 raw '$_r5' vs joined '$_n5', day 19 raw '$_r19' vs joined '$_n19'"
  for _w in psfail:19 psfailpad:5; do
    ( . "$PJ_SEEDLIB"; PATH="$PJW/psbin:$PATH"; PERL5LIB="$PJW/psbin/p5"; PERL5OPT="-MPJDay=${_w#*:}"; export PERL5LIB PERL5OPT
      pj_write_lock "$LOCKPID" "$PJW/j.${_w%%:*}.lock" )
    _s="$(sed -n 2p "$PJW/j.${_w%%:*}.lock/pid")"
    # the writer recorded the forced day and the lock pid's own time of day and year
    [ "$(set -f; set -- $_s; printf '%s|%s|%s' "$3" "$4" "$5")" = "${_w#*:}|$(set -f; set -- $PJ_LIVE; printf '%s|%s' "$4" "$5")" ] \
      || broken "the ${_w%%:*} world's writer did not record day ${_w#*:} of the live start '$PJ_LIVE': '$_s'"
  done
fi
# ANTI-SKIP: the SKIP above must be UNREACHABLE where the fallback has what it needs, or a broken
# detector would skip these cells everywhere. The precondition is computed apart from the detector
# -- perl on PATH (probed, never run) and a Darwin kernel -- and a SKIP under it is a FAIL by name.
lt_arm
_uname_s="$(uname -s 2>/dev/null)" || broken "anti-SKIP: uname -s failed, so the Darwin gate would read 'not Darwin' and print ok vacuously"
if command -v perl >/dev/null 2>&1 && [ "$_uname_s" = Darwin ]; then
  [ "$PJ_PERL" = 1 ] && ok "anti-SKIP: perl is on PATH on Darwin, and the psfail and psfailpad worlds run" \
    || bad "anti-SKIP: perl is on PATH on Darwin, yet the psfail and psfailpad worlds were SKIPPED -- the fallback detector is broken"
else
  ok "anti-SKIP: no perl on PATH, or not Darwin -- the BL-686 SKIP is allowed here"
fi
# THE WRITER WITH NO PERL AT ALL (BL-686; perl is an optional source). PATH is ONLY a directory
# holding `date` and a `ps` that prints nothing and exits 0, so neither source can read the start.
# The writer must NOT record an empty start line: it writes the two-field lock and announces on
# stderr, and the reader judges that lock HELD on a live pid. Scored as `<lines>|<empty line 2?>|<ann>|<rc>`.
mkdir -p "$PJW/noperl" && printf '#!/bin/bash\nexit 0\n' > "$PJW/noperl/ps" && chmod +x "$PJW/noperl/ps" \
  && ln -sf "$(command -v date)" "$PJW/noperl/date" || broken "could not build the no-perl PATH"
[ -z "$(PATH="$PJW/noperl" command -v perl)" ] || broken "the no-perl PATH still finds perl"
pw_drive() { # <pool copy> <tag> -> the writer's outcome, then the reader's rc on that lock
  local o="$PJW/pw.$2"; mkdir -p "$o/l.lock" || return 1
  { awk '/^readset_pid_start\(\) \{/,/^}/' "$1"; awk '/^readset_lock_write\(\) \{/,/^}/' "$1"; awk '/^readset_lock_stale\(\) \{/,/^}/' "$1"; } > "$o/lib.sh"
  fx_inproc "$ROOT/core/git-hooks/pre-push"
  ( . "$o/lib.sh"; PATH="$PJW/noperl"; readset_lock_write "$o/l.lock" "$LOCKPID" ) 2> "$o/err"
  ( . "$o/lib.sh"; fx_inproc "$ROOT/core/git-hooks/pre-push"; readset_lock_stale "$o/l.lock" ) > /dev/null 2>&1; local rr=$?
  printf '%s|%s|%s|%s' "$(grep -c '' "$o/l.lock/pid" 2>/dev/null)" \
    "$(sed -n 2p "$o/l.lock/pid" 2>/dev/null | grep -q . && echo full || { [ "$(grep -c '' "$o/l.lock/pid")" -ge 2 ] && echo empty || echo none; })" \
    "$(grep -q 'could not read the start time of pid' "$o/err" && echo ann || echo noann)" "$rr"
}
PW_OK='1|none|ann|1'
lt_arm; _pw="$(pw_drive "$POOL" real)"
[ "$_pw" = "$PW_OK" ] && { ok "lock writer, no perl and an empty ps: records NO empty start line, announces on stderr, and the reader judges the lock HELD (BL-686)"; } \
  || bad "lock writer, no perl and an empty ps: got '$_pw', want '$PW_OK' (lines|line 2|announced|reader rc)"
# The judge: a fresh process. ctl is computed before any world's env by the fixture's OWN `ps` call,
# never the block's helper: the control is a fact about the harness, and a helper reading `$$`
# would otherwise blind the control that exists to separate it from a right helper.
PJ_JUDGE="$PJW/judge.sh"
cat > "$PJ_JUDGE" <<'PJ'
lib="$1"; seed="$2"; lk="$3"; w="$4"; o="$5"; lp="$6"; psbin="$7"
a="$(LC_ALL=C TZ=UTC0 ps -o lstart= -p "$$" 2>/dev/null)"; b="$(LC_ALL=C TZ=UTC0 ps -o lstart= -p "$lp" 2>/dev/null)"
if [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ]; then echo sdiff; else echo "nosdiff($a/$b)"; fi > "$o/ctl"
. "$lib"
case "$w" in
  right) export LC_ALL=C TZ=UTC0 ;;
  split) export LANG=fr_FR.UTF-8 LC_ALL=fr_FR.UTF-8 TZ=America/Los_Angeles ;;
  psfail|psfailpad) PATH="$psbin:$PATH"; [ "$(command -v ps)" = "$psbin/ps" ] || exit 7
    PERL5LIB="$psbin/p5"; PERL5OPT=-MPJDay=19; [ "$w" = psfail ] || PERL5OPT=-MPJDay=5; export PERL5LIB PERL5OPT ;;
  bothfail) PATH="$psbin/both:$PATH"; [ "$(command -v ps)" = "$psbin/both/ps" ] && [ "$(command -v perl)" = "$psbin/both/perl" ] || exit 7 ;;
esac
readset_lock_stale "$lk" > "$o/out" 2>&1; echo "$?" > "$o/rc"
PJ
# A FLOOR, NOT A BOUND, DECIDING NO VERDICT: each judge must start in a later `lstart` second than the lock pid; load only lengthens it, and the `sdiff` control above (refused in pj_eval) asserts the property itself.
while [ $(( $(date +%s) - LOCK_T0 )) -lt 2 ]; do sleep 0.2; done  # bl868-allow: rs-lstart-floor
pj_judge() { # <lib> <world> -> "<stale|held|err<rc>>|<ann|noann>"; refuses on a failed control
  local o rc c
  o="$(mktemp -d "$PJW/jo.$2.XXXXXX")" || broken "mktemp for the $2 judge failed"
  bash "$PJ_JUDGE" "$1" "$PJ_SEEDLIB" "$PJW/j.$2.lock" "$2" "$o" "$LOCKPID" "$PJW/psbin" > "$o/judge.out" 2>&1
  # pj_judge runs inside `$( )`, where `broken` would end only the substitution: the failed control
  # is recorded, and pj_eval refuses on it in the fixture's own shell.
  c="$(cat "$o/ctl" 2>/dev/null)"
  [ "$c" = sdiff ] || printf '%s %s\n' "$2" "${c:-none}" >> "$PJW/ctlfail"
  rc="$(cat "$o/rc" 2>/dev/null)"
  case "$rc" in 0) rc=stale ;; 1) rc=held ;; *) rc="err${rc:-none}" ;; esac
  printf '%s|%s' "$rc" "$(grep -q 'could not read the start time of lock pid' "$o/out" && echo ann || echo noann)"
}
PJ_WORLDS="wrong right legacylive legacydead psfail psfailpad bothfail split"
[ "$PJ_PERL" = 1 ] || PJ_WORLDS="wrong right legacylive legacydead bothfail split"
pj_want() { # <world> <right's result under the same lib>
  case "$1" in
    wrong|legacydead) printf 'stale|noann' ;;
    right|legacylive|psfail|psfailpad) printf 'held|noann' ;;
    bothfail) printf 'held|ann' ;;
    split) printf '%s' "$2" ;;
  esac
}
pj_eval() { # <lib>: sets PJ_R_<world> and PJ_FLIP, the worlds whose result is not the wanted one
  local w r rr
  rr="$(pj_judge "$1" right)"; PJ_FLIP=""
  for w in $PJ_WORLDS; do
    if [ "$w" = right ]; then r="$rr"; else r="$(pj_judge "$1" "$w")"; fi
    eval "PJ_R_$w=\$r"
    [ "$r" = "$(pj_want "$w" "$rr")" ] || PJ_FLIP="$PJ_FLIP${PJ_FLIP:+ }$w"
  done
  [ ! -s "$PJW/ctlfail" ] || broken "a judge's start equals the lock pid's, or could not be read -- a reader or helper reading \$\$ would pass: $(tr '\n' ';' < "$PJW/ctlfail")"
}
pj_eval "$PJ_LIB"
pj_arm() { # <world> <text>
  local r; lt_arm; eval "r=\$PJ_R_$1"
  if [ "$r" = "$(pj_want "$1" "$PJ_R_right")" ]; then ok "$2"; else bad "$2 -- got '$r', want '$(pj_want "$1" "$PJ_R_right")'"; fi
}
pj_arm wrong "lock start: a LIVE pid whose recorded start time is not its own (a reused pid) is STALE"
pj_arm right "  the real writer's lock for a live pid is HELD, with no ps-fallback announcement"
pj_arm legacylive "  a two-field lock from an older hook with a live pid is HELD, judged as before, with no announcement"
pj_arm legacydead "  a two-field lock from an older hook with a dead pid is STALE"
[ "$PJ_PERL" = 1 ] && pj_arm psfail "  a ps that fails (PATH stub exiting 1, as sandbox-exec refuses the setuid /bin/ps) still reads the start through the perl fallback: HELD, silent (BL-686), fallback day forced to 19 (unpadded)"
[ "$PJ_PERL" = 1 ] && pj_arm psfailpad "  the same with the fallback's day forced to 5, which perl pads ('Nov  5'): HELD, silent -- the helper re-joins the fallback's words too (BL-868)"
pj_arm bothfail "  a ps AND a perl that fail leave a live lock HELD and say so in one line"
pj_arm split "  written under de_DE/Asia/Tokyo and judged under fr_FR/America/Los_Angeles, the lock reads as it does under C/UTC0"
fi # end of the ps-dependent start-time worlds
# CONTROL, driven through lw_run: a baseline selection must APPEAR.
R="$(lw_run "$POOL" ctl3 "$LM_C1")"; lt_arm
if lc1 "$R" && msg_of "$R" | grep -q 'read-set map: derived at'; then
  ok "CONTROL: the block, driven through lw_run, maps gamma locally and selects alpha alone"
else
  bad "CONTROL: the block did not reproduce (b) through lw_run"
fi

# ----------------------------------------------------------- the read-set trace report ----
# THE DETACHED TRACE'S OUTCOMES WERE NEVER READ BACK. readset_trace_report prints them on every push,
# before the suite, from the local map's `#discards` rows, the last trace's log and its status file.
# Each world below seeds those three files the way the deriver and the launcher write them and calls
# the block's own function; every arm is a set of named lines that must APPEAR, so a report that
# prints nothing fails all of them.
#   (r1) a full world: discards at 1, 2, 3 on the current key and 3 on a moved key; a last trace
#        holding a discard, a clean recorded fixture and the TWO-LINE shape (`<fx>  N paths`, then
#        `could not hash <fx>'s set ... -- not recorded`). The held fixture is NOT in the last trace,
#        because a held fixture is never re-traced: that is the input that separates a standing held
#        line from one printed only on the push whose trace reached 3.
#   (r2) nothing on disk: every line still prints and says so
#   (r3) a running trace; (r4) one that died without its exit; (r5) a finished trace that recorded
#        nothing; (r6) a running trace an older hook started, with no status file
rp_world() { # <pool> <name> <setup, eval'd in the seeded tree with $o, $RL, key()>; prints the report
  local p="$1" t="$WORK/rp.$2" o="$WORK/rp.$2.out"
  f2b_world seed_lt "$t" || { printf 'SEED FAILED'; return 1; }
  if [ "$FXROOT" != core/fixtures ]; then
    mkdir -p "$t/$(dirname "$FXROOT")" && cp -R "$t/core/fixtures" "$t/$FXROOT" \
      && ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fxroot ) >/dev/null 2>&1 \
      || { printf 'SEED FAILED'; return 1; }
  fi
  mkdir -p "$o"
  ( cd "$t" || exit 1
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$p" 2>/dev/null
    RL="$READSET_LOCAL"
    key() { printf '%s:%s' "$(sha_of "$FXROOT$1/run.sh")" "$(sha_of core/scripts/derive-fixture-readsets.sh)"; }
    eval "$3"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_trace_report "$o" ) > "$o/rep" 2>&1
  cat "$o/rep"
}
RP_T0=1791000000
RP_FULL='printf "alpha\t#discards\t2\t%s\tthe stream dropped reports 5 time(s) in this window; VERDICT: the sandboxed run'"'"'s verdict lines differ from the normal run'"'"'s\n" "$(key alpha)" > "$RL"
printf "beta\t#discards\t3\t%s\tLOSS CANARY: 2 path(s) the fixture read (atime) are absent from the stream; VERDICT: the sandboxed run'"'"'s verdict lines differ from the normal run'"'"'s\n" "$(key beta)" >> "$RL"
printf "gamma\t#discards\t3\t0000:%s\tTRIP: 1 exec(s) of a refused binary (setuid/setgid, log, sandbox-exec)\n" "$(sha_of core/scripts/derive-fixture-readsets.sh)" >> "$RL"
printf "delta\t#discards\t1\tx:y\tfixture exited 1\n" >> "$RL"
printf "zeta\tcore/fixtures/zeta/run.sh\tabc\n" >> "$RL"
printf "  alpha                            OMITTED (the stream dropped reports 5 time(s) in this window) -- will always run\n  eps                                 9 paths\n  could not hash eps'"'"'s set in the trace copy -- not recorded\n  zeta                                4 paths\n" > "$RL.log"
printf "start %s\npid 1\nlist alpha eps zeta\nexit 0\nfinish %s\n" '"$RP_T0"' '"$((RP_T0 + 10))"' > "$RL.status"
printf "alpha\trun\tstale\ts\tstale\nbeta\trun\tunrecorded\tu\tok\ngamma\tskip\t\t\tok\n" > "$o/.kdec"
printf "alpha\nbeta\ngamma\n" > "$o/.kl"; printf "alpha\ngamma\n" > "$o/.mapped.all"'
# The (r1) lines, each NAMED, so a missing line is named.
RP_N_OUTCOME='trace-report last trace outcome: 3 given, 1 recorded, 1 discarded, 1 traced cleanly but NOT recorded;'
RP_N_OCAUSE='NOT recorded; causes stream-drop 1, not-hashed 1'
RP_N_DISC='trace-report discards: 4 fixture(s) carry a #discards row (at 1: 1, at 2: 1, at 3 or more: 2); causes stream-drop 1, verdict 2, loss-canary 1, trip 1, fixture-exit 1'
RP_N_TWO='trace-report at 2 of 3: alpha -- one more discard on the same key holds it'
RP_N_HELD='trace-report held: beta -- discarded 3 times in a row on its current run.sh and deriver, so it is NOT re-traced and runs on every push until one of them changes; a release that edits the deriver resets every #discards count'
RP_N_NOTREC='trace-report not recorded: eps -- traced cleanly, then could not hash its set in the trace copy'
RP_N_UNCL='trace-report uncleared this push: 1 stale and 1 unmapped fixture(s) run because no trace has cleared them'
RP_N_LAST='fixture(s); finished, exit 0'
rp_score() { # <report>: the names of the (r1) lines MISSING from it, space separated
  local r="$1" v miss=""
  for v in OUTCOME OCAUSE DISC TWO HELD NOTREC UNCL LAST; do
    eval "grep -qF -- \"\$RP_N_$v\" <<< \"\$r\"" || miss="$miss $v"
  done
  grep -q 'WARN' <<< "$r" && miss="$miss WARN"
  printf '%s' "${miss# }"
}
RP_R1="$(rp_world "$POOL" r1 "$RP_FULL")"; lt_arm
RP_R1_MISS="$(rp_score "$RP_R1")"
if [ -z "$RP_R1_MISS" ]; then
  ok "(r1) the report names every count and fixture: the outcome of the last trace with the two-line hash failure counted as NOT recorded, the discard buckets and causes, alpha at 2 of 3, beta HELD on its current key (gamma's moved key is not held), eps not recorded, and this push's uncleared stale and unmapped"
else
  bad "(r1) the report is missing line(s) [$RP_R1_MISS]: $(tr '\n' '|' <<< "$RP_R1")"
fi
RP_R2="$(rp_world "$POOL" r2 ':')"; lt_arm
case "$RP_R2" in
  *"trace-report last trace: none recorded (no status file at "*"trace-report local map: none at "*"trace-report last trace outcome: no trace log at "*"trace-report discards: none recorded"*"trace-report at 2 of 3: none"*"trace-report held: none"*"trace-report not recorded: none"*"trace-report uncleared this push: unknown -- no fixture keys were built this push"*)
    ok "(r2) with no local map, no log, no status file and no keys built, every report line still prints and says what is absent" ;;
  *) bad "(r2) an empty clone's report left a line out: $(tr '\n' '|' <<< "$RP_R2")" ;;
esac
RP_LIVE='mkdir "$RL.lock" && printf "%s %s\n" '"$LOCKPID"' "$(date +%s)" > "$RL.lock/pid"'
RP_R3="$(rp_world "$POOL" r3 "$RP_LIVE; printf 'start %s\npid %s\nlist gamma\n' \"\$(date +%s)\" $LOCKPID > \"\$RL.status\"")"; lt_arm
case "$RP_R3" in
  *"trace-report last trace: started "*", 1 fixture(s); RUNNING since "*"pid $LOCKPID"*) grep -q WARN <<< "$RP_R3" && bad "(r3) a RUNNING trace raised a warning: $(tr '\n' '|' <<< "$RP_R3")" \
      || ok "(r3) a trace whose status pid holds the lock reads RUNNING since its start, with its pid, and warns of nothing" ;;
  *) bad "(r3) a running trace was not reported as running: $(tr '\n' '|' <<< "$RP_R3")" ;;
esac
RP_R4="$(rp_world "$POOL" r4 "printf 'start %s\npid %s\nlist gamma\n' \"\$(date +%s)\" $LOCKPID > \"\$RL.status\"")"; lt_arm
case "$RP_R4" in
  *"DIED without writing its exit"*"WARN  trace-report warning: the last trace DIED"*) ok "(r4) a status with no exit and no lock reads DIED, with a WARN line" ;;
  *) bad "(r4) a trace that died without its exit was not reported: $(tr '\n' '|' <<< "$RP_R4")" ;;
esac
RP_R5="$(rp_world "$POOL" r5 "printf 'start 1791000000\npid 1\nlist alpha eps\nexit 0\nfinish 1791000100\n' > \"\$RL.status\"
printf '  alpha                            OMITTED (the stream dropped reports 5 time(s) in this window) -- will always run\n  eps                              OMITTED (the stream dropped reports 2 time(s) in this window; VERDICT: the sandboxed run differs) -- will always run\n' > \"\$RL.log\"")"; lt_arm
case "$RP_R5" in
  *"WARN  trace-report warning: the last trace recorded NOTHING for the 2 fixture(s) it was given; dominant cause stream-drop (2)"*) ok "(r5) a finished trace that recorded nothing is a WARN line naming the dominant cause" ;;
  *) bad "(r5) a trace that cleared nothing was silent: $(tr '\n' '|' <<< "$RP_R5")" ;;
esac
RP_R6="$(rp_world "$POOL" r6 "$RP_LIVE")"; lt_arm
case "$RP_R6" in
  *"trace-report last trace: RUNNING since "*"pid $LOCKPID; no status file"*) ok "(r6) a live lock with no status file (an older hook's trace) still reads RUNNING, and says the status file is absent" ;;
  *) bad "(r6) a running trace with no status file was not reported: $(tr '\n' '|' <<< "$RP_R6")" ;;
esac
# (r9)-(r12) THE STOP LINE. A deriver group the status file names, still alive, with no exit: the report
# prints the command that ends it when the trace subshell is gone (r9) or the trace is past its
# ceiling (r10), and stays quiet for a live trace inside its ceiling (r11) and for a deriver group that
# is already gone (r12). The live group is a `sleep` this fixture started under `set -m` and kills by
# its recorded group on exit; the dead pid is a child that has already been reaped.
set -m; tail -f /dev/null </dev/null >/dev/null 2>&1 & SDG=$!; set +m
trap 'kill '"$LOCKPID"' 2>/dev/null; kill -- -'"$SDG"' 2>/dev/null; rm -rf "$WORK"' EXIT
bash -c 'exit 0' & SDEAD=$!; wait "$SDEAD"
kill -0 -- "-$SDG" 2>/dev/null || broken "the stop-line worlds' live group -$SDG is not alive"
kill -0 "$SDEAD" 2>/dev/null && broken "the stop-line worlds' dead pid $SDEAD is alive"
RP_STOP="stop it with: kill -TERM -- -$SDG"
rp_stop_world() { # <pool> <name> <status pid> <deriver> <ceiling> <age>
  rp_world "$1" "$2" "printf 'start %s\npid %s\nlist gamma\nderiver %s\nceiling %s\n' \"\$((\$(date +%s) - $6))\" $3 $4 $5 > \"\$RL.status\""
}
RP_R9="$(rp_stop_world "$POOL" r9 "$SDEAD" "$SDG" 900 5)"; lt_arm
case "$RP_R9" in
  *"deriver group $SDG is still running and its trace subshell (pid $SDEAD) is gone; $RP_STOP"*) ok "(r9) a live deriver group whose trace subshell is gone: one WARN line naming kill -TERM -- -<deriver pgid>" ;;
  *) bad "(r9) an orphaned deriver group was not named with its stop command: $(tr '\n' '|' <<< "$RP_R9")" ;;
esac
RP_R10="$(rp_stop_world "$POOL" r10 "$LOCKPID" "$SDG" 10 100)"; lt_arm
case "$RP_R10" in
  *"deriver group $SDG is still running and it has run "*"s, past its 10s ceiling; $RP_STOP"*) ok "(r10) a live trace past its ceiling plus grace: the same line, naming the overrun" ;;
  *) bad "(r10) a trace past its ceiling was not named with its stop command: $(tr '\n' '|' <<< "$RP_R10")" ;;
esac
RP_R11="$(rp_stop_world "$POOL" r11 "$LOCKPID" "$SDG" 900 5)"; lt_arm
case "$RP_R11" in
  *"stop it with:"*) bad "(r11) a live trace inside its ceiling was told to stop: $(tr '\n' '|' <<< "$RP_R11")" ;;
  *"trace-report last trace: started"*) ok "(r11) near-miss: a live trace inside its ceiling gets no stop line" ;;
  *) bad "(r11) the near-miss report printed no last-trace line: $(tr '\n' '|' <<< "$RP_R11")" ;;
esac
RP_R12="$(rp_stop_world "$POOL" r12 "$SDEAD" "$SDEAD" 900 5)"; lt_arm
case "$RP_R12" in
  *"stop it with:"*) bad "(r12) a deriver group that is already gone was told to stop: $(tr '\n' '|' <<< "$RP_R12")" ;;
  *"DIED without writing its exit"*) ok "(r12) near-miss: a gone deriver group gets no stop line (the trace still reads DIED)" ;;
  *) bad "(r12) the near-miss report did not read DIED: $(tr '\n' '|' <<< "$RP_R12")" ;;
esac
# THE CALL SITE: run_fixtures prints the report on a push that runs the suite, before the suite runs.
rp_run() { # <pool> <name>; prints the run's output, also kept with its POOL_STALL in $WORK/rpo.<name>/
  local p="$1" t="$WORK/rpr.$2" o="$WORK/rpo.$2"
  f2b_world seed_lt "$t" || { printf 'SEED FAILED'; return 1; }
  if [ "$FXROOT" != core/fixtures ]; then
    mkdir -p "$t/$(dirname "$FXROOT")" && cp -R "$t/core/fixtures" "$t/$FXROOT" \
      && ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fxroot ) >/dev/null 2>&1 \
      || { printf 'SEED FAILED'; return 1; }
  fi
  mkdir -p "$o"
  ( cd "$t" || exit 1; export AI_DLC_READSET_LIVE_TRACE=0
    # shellcheck disable=SC1090
    fx_inproc "$ROOT/core/git-hooks/pre-push"; . "$p" 2>/dev/null; printf '%s\n' "${POOL_STALL:-}" > "$o/stall"; fx_inproc "$ROOT/core/git-hooks/pre-push"; run_fixtures ) > "$o/out" 2>&1
  cat "$o/out"
}
rp_called() { awk '/trace-report last trace:/ { r = NR } /^  *ok  *(alpha|beta|gamma)/ && !f { f = NR } END { exit !(r && f && r < f) }' <<< "$1"; }
RP_RUN="$(rp_run "$POOL" call)"; lt_arm
if rp_called "$RP_RUN"; then
  ok "(r7) run_fixtures prints the trace report on every push that builds its list, BEFORE the first fixture verdict"
else
  bad "(r7) run_fixtures printed no trace report before the suite: $(tr '\n' '|' <<< "$RP_RUN" | cut -c1-600)"
fi

fi

# stub_live <pid file>: how many of the recorded pids answer `kill -0`.
stub_live() { local p n=0; [ -f "$1" ] || { echo 0; return 0; }; while read -r p; do [ -n "$p" ] && kill -0 "$p" 2>/dev/null && n=$((n+1)); done < "$1"; echo "$n"; }
# stub_reap <world dir> -- moves <dir>/pids to pids.last (and appends it to pids.all), kills each recorded pid by number,
# waits up to 3s for them to go, and logs "<recorded> <live>" to <dir>/reap.log. Only a pid recorded by a stub this world started is ever signalled; nothing is found by pattern.
stub_reap() {
  local d="${1:-}" p i=0 n live
  [ -d "$d" ] || return 0
  [ -f "$d/pids" ] || : > "$d/pids"
  cat "$d/pids" > "$d/pids.last"; cat "$d/pids" >> "$d/pids.all"; : > "$d/pids"
  while read -r p; do [ -n "$p" ] && kill "$p" 2>/dev/null; done < "$d/pids.last"
  # GONE, OR NEVER GOING: a killed stub is dying and never reads blocked; one the kill missed blocks forever.
  while :; do
    live=0; i=1
    while read -r p; do [ -n "$p" ] && kill -0 "$p" 2>/dev/null || continue; live=1; aw_blocked "$p" || i=0; done < "$d/pids.last"
    [ "$live" = 0 ] || [ "$i" = 1 ] && break
    sleep 0.1
  done
  # A reaped stream's STUB_STREAM registration goes with it, so a later reuse of its pid cannot pass for a live
  # stream. The stub of one world may have registered under another world's feed (sbx_run uses $SB's stubs on $SX's feed).
  while read -r p; do [ -n "$p" ] && rm -f "$WORK"/*/feed.streams/"$p"; done < "$d/pids.last"
  live="$(stub_live "$d/pids.last")"; n="$(grep -c . "$d/pids.last")" || n=0
  printf '%s %s\n' "$n" "$live" >> "$d/reap.log"
}


# ------------------------------------------------------- the deriver's map merge ----
# `--list` exists so refreshing ONE fixture costs its own runtime instead of a full
# re-derivation. Its first version rewrote the map from only the fixtures it had just traced,
# silently dropping every other entry. That is SAFE -- an unmapped fixture always runs -- and
# therefore invisible: the suite stays correct and merely stops skipping, which reads as the
# feature underperforming rather than as a bug. These arms are why it cannot come back.
#
# THE DERIVER NOW SHIPS, and it lands under a different parent on each side: install.sh copies
# `core/scripts/<x>` to `scripts/ai-dlc/<x>`, so neither path can be assumed and neither may be
# located by walking up from the other (I33). The CONSUMER layout is probed first and the
# distribution second, which is the order every other two-layout resolver here uses.
#
# ITS ABSENCE IS STILL A SKIP RATHER THAN A FAILURE, and that is not leniency. A core fixture
# ships ahead of its subject: this fixture reaches a consumer in one pull and the deriver in
# the next, so an installed tree between those two pulls has the fixture and not the file. A
# SKIP says so; passing silently would make a vanished arm and a satisfied arm identical.

MERGE_ARMS=0
CONTROL_ARMS=0
TRACE_ARMS=0
BOTH_ARMS=0
DERIVER=""
for _d in "$ROOT/scripts/ai-dlc/derive-fixture-readsets.sh" "$ROOT/core/scripts/derive-fixture-readsets.sh"; do
  [ -f "$_d" ] && DERIVER="$_d" && break
done
if [ -n "$DERIVER" ]; then
. "$RS_LIB/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# PRE-WRAP CONSUMER GATE (BL-878): a consumer one pull behind carries this fixture with a subject that predates the
# in-process wrap, and loading it would run its whole body. Neither half is SKIP (FIXTURE BROKEN in the distribution,
# exit 0 on a consumer); exactly one half FAILS; an unreadable subject is FIXTURE ERROR.
grep -qxF 'rs_main() {' "$DERIVER"; _wg1=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$DERIVER"; _wg2=$?
[ "$_wg1" -le 1 ] && [ "$_wg2" -le 1 ] || { echo "FIXTURE ERROR: cannot read $DERIVER (grep exit $_wg1/$_wg2)" >&2; exit 2; }
case "$_wg1$_wg2" in
  00) : ;;
  11) echo "SKIP: readset-skip: $DERIVER predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) bad "$DERIVER carries one half of the in-process wrap (rs_main line: rc $_wg1, column-0 source guard: rc $_wg2) -- a respelled subject this fixture cannot drive"
     report_end "$NAME" ;;
esac
fi
# THE DERIVER IS CONSUMED in every shard: its LOCALMAP span is read by the digest worlds and by hr, and
# the sentinel is printed only when the span is really there, so a deriver declared but not read fails.
if [ -n "$DERIVER" ] && grep -q '^# READSET_LOCALMAP_BEGIN$' "$DERIVER"; then
  echo "HERMETIC-CONSUMED ${DERIVER#"$ROOT"/}"
fi
if [ -z "$DERIVER" ]; then
  printf '  SKIP  map-merge arms: derive-fixture-readsets.sh is in neither layout yet (core fixtures ship ahead of their subject)\n'
else
  if sg merge; then
  M="$WORK/merge.sh"
  sed -n '/# READSET_MERGE_BEGIN/,/# READSET_MERGE_END/p' "$DERIVER" > "$M"
  grep -q 'readset_merge_map()' "$M" || broken "extracted no readset_merge_map from $DERIVER"
  # shellcheck disable=SC1090
  . "$M"
  printf 'alpha\tsrc/a\nalpha\tsrc/x\nbeta\tsrc/b\ngamma\tsrc/g\n' > "$WORK/old.map"
  printf 'alpha\tsrc/NEW\n' > "$WORK/new.map"
  : > "$WORK/empty.map"

  fx_inproc "$DERIVER"
  G="$(readset_merge_map "$WORK/old.map" "$WORK/new.map" "alpha" | LC_ALL=C sort | tr '\n' ' ')"
  MERGE_ARMS=$((MERGE_ARMS+1))
  case "$G" in
    *"beta	src/b"*) ok "a --list run leaves an UNTRACED fixture's entries alone — refreshing one fixture does not cost the rest of the map" ;;
    *) bad "merging dropped an untraced fixture's entries: $G" ;;
  esac
  MERGE_ARMS=$((MERGE_ARMS+1))
  case "$G" in
    *"alpha	src/x"*) bad "merging kept a STALE entry for the fixture it just re-traced: $G" ;;
    *"alpha	src/NEW"*) ok "  and it REPLACES the traced fixture's entries rather than adding to them" ;;
    *) bad "the traced fixture's new entry is missing after the merge: $G" ;;
  esac
  # The case that matters most: a fixture that WAS mapped and is now omitted must lose its
  # read-set, or the map keeps asserting a dependency set nothing re-verified.
  fx_inproc "$DERIVER"
  G2="$(readset_merge_map "$WORK/old.map" "$WORK/empty.map" "beta" | LC_ALL=C sort | tr '\n' ' ')"
  MERGE_ARMS=$((MERGE_ARMS+1))
  case "$G2" in
    *"beta	"*) bad "a traced fixture that produced NO read-set kept its stale entries — it would go on being skipped on evidence nothing re-verified: $G2" ;;
    *"gamma	src/g"*) ok "a traced fixture that produced nothing loses its entries and becomes unmapped, which means it always runs" ;;
    *) bad "the merge lost an untraced fixture while dropping the omitted one: $G2" ;;
  esac

  # THE CALLER PASSES A NEWLINE-SEPARATED LIST, AND EVERY ARM ABOVE PASSES A SINGLE TOKEN.
  # That gap shipped a live defect: `LIST` is built by a `for` loop over core/fixtures/*/, so it
  # arrives newline-separated, and `awk -v traced=" $traced "` cannot carry a newline — awk died
  # with `newline in string` on line 1, the old-map branch emitted nothing, and every UNTRACED
  # fixture silently lost its entries. Invisible under --all, which re-traces everything; under
  # --list it unmaps the rest of the suite. Observed in a real `sudo ... --all` run.
  #
  # The arms above could not see it because a one-word list has no newline in it. This one
  # drives the shape the caller actually produces.
  fx_inproc "$DERIVER"
  G3="$(readset_merge_map "$WORK/old.map" "$WORK/new.map" "$(printf 'alpha\ndelta')" 2>"$WORK/g3.err" | LC_ALL=C sort | tr '\n' ' ')"
  MERGE_ARMS=$((MERGE_ARMS+1))
  if [ -s "$WORK/g3.err" ]; then
    bad "a NEWLINE-separated traced list — the form the caller builds — made the merge write to stderr: $(tr '\n' ' ' < "$WORK/g3.err")"
  else
    case "$G3" in
      *"beta	src/b"*)
        case "$G3" in
          *"alpha	src/x"*) bad "newline-separated list: the re-traced fixture kept a stale entry: $G3" ;;
          *) ok "a NEWLINE-separated traced list behaves as a space-separated one — untraced entries kept, traced ones replaced" ;;
        esac ;;
      *) bad "a NEWLINE-separated traced list dropped an untraced fixture's entries — the whole rest of the map: $G3" ;;
    esac
  fi

  # ------------------------------ the write pipeline drops `.git` through the hook's own predicate ----
  # THE MAP CARRIED `.git/**` ROWS THE HOOK STRIPS BEFORE KEYING. The deriver's write pipeline now ends in
  # readset_drop_git, the hook's predicate (READSET_UNIVERSE span), with a fallback inside the deriver's
  # READSET_BOTH span for a runner whose span carries none. The pipeline is EXTRACTED from the deriver (the one
  # line that redirects into "$WORK/$fx.set") and run over a seeded stream, so the shipped line is the subject.
  # The seed carries the nested `sub/.git/HEAD` (an unanchored predicate drops it) and `.gitignore` (the
  # near-miss a prefix match on `.git` would drop).
  DG="$WORK/dg"
  mkdir -p "$DG/r" "$DG/w" || broken "mkdir failed"
  ( cd "$DG/r" && git init -q . ) >/dev/null 2>&1 || broken "could not seed the .git-drop repo"
  printf '%s\n' .git/objects/ab/cd .git/HEAD .git sub/.git/HEAD .gitignore core/x.sh > "$DG/seed"
  printf '%s\n' .gitignore core/x.sh sub/.git/HEAD > "$DG/want"
  sed -n '/^# READSET_DROP_BEGIN$/,/^# READSET_DROP_END$/p' "$DERIVER" > "$DG/drop.span"
  sed -n '/^# READSET_PSEUDO_BEGIN$/,/^# READSET_PSEUDO_END$/p' "$DERIVER" > "$DG/pseudo.span"
  sed -n '/^# READSET_BOTH_BEGIN$/,/^# READSET_BOTH_END$/p' "$DERIVER" > "$DG/both.span"
  sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' "$HOOK" > "$DG/univ.span"
  grep -F '> "$WORK/$fx.set"' "$DERIVER" > "$DG/wline"
  # dg_pipe <deriver-for-the-write-line> <hook-span|-> : prints what the shipped write pipeline leaves of the seed
  dg_pipe() {
    local wl="$1" us="$2"
    {
      printf '. "%s"\n. "%s"\n' "$DG/drop.span" "$DG/pseudo.span"
      if [ "$us" = - ]; then :; else printf '. "%s"\n' "$us"; fi
      printf '. "%s"\n' "$DG/both.span"
      printf 'cd "%s" || exit 9\n' "$DG/r"
      printf 'cat "%s" | LC_ALL=C sort -u \\\n' "$DG/seed"
      cat "$wl"
    } > "$DG/pipe.sh"
    rm -f "$DG/w/dgfx.set"
    ( inproc TREE="$DG/r" WORK="$DG/w" fx=dgfx -- "$DG/pipe.sh" ) >/dev/null 2>&1
    cat "$DG/w/dgfx.set" 2>/dev/null
  }
  dg_verdict() { if [ "$(LC_ALL=C sort "$1" 2>/dev/null | tr '\n' ' ')" = "$(LC_ALL=C sort "$DG/want" | tr '\n' ' ')" ]; then echo exact; else echo wrong; fi; }
  MERGE_ARMS=$((MERGE_ARMS+1))
  if [ "$(grep -c . "$DG/wline")" -ne 1 ] || ! grep -q '^readset_drop_git()' "$DG/univ.span" || ! grep -q 'readset_drop_git()' "$DG/both.span"; then
    bad "(g) extracted no single write line from $DERIVER, no readset_drop_git from the hook's READSET_UNIVERSE span, or no fallback from the deriver's READSET_BOTH span — nothing below ran"
  else
    dg_pipe "$DG/wline" "$DG/univ.span" > "$DG/out.hook"
    dg_pipe "$DG/wline" - > "$DG/out.fallback"
    if [ "$(dg_verdict "$DG/out.hook")" = exact ]; then
      ok "(g) the shipped write pipeline over .git/objects/ab/cd, .git/HEAD, a bare .git, sub/.git/HEAD, .gitignore and core/x.sh leaves exactly sub/.git/HEAD, .gitignore and core/x.sh, with the hook's predicate sourced"
    else
      bad "(g) the write pipeline left [$(tr '\n' ' ' < "$DG/out.hook")], wanted exactly [$(tr '\n' ' ' < "$DG/want")]"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    if [ "$(dg_verdict "$DG/out.fallback")" = exact ]; then
      ok "(g) and the same holds with NO hook span sourced: the READSET_BOTH fallback carries the predicate (the deriver run against an older hook)"
    else
      bad "(g) with no hook span the write pipeline left [$(tr '\n' ' ' < "$DG/out.fallback")], wanted exactly [$(tr '\n' ' ' < "$DG/want")]"
    fi
    # BYTE-COMPARE the executable body of the fallback with the hook's definition: the lines between the
    # function header and its closing brace, whitespace-trimmed. The header line carries a comment and is not compared.
    dg_body() { awk '/^[[:space:]]*readset_drop_git\(\)/ { on = 1; next } on && /^}/ { exit } on { sub(/^[[:space:]]+/, ""); print }' "$1"; }
    dg_body "$DG/univ.span" > "$DG/body.hook"
    dg_body "$DG/both.span" > "$DG/body.fb"
    MERGE_ARMS=$((MERGE_ARMS+1))
    if [ -s "$DG/body.hook" ] && cmp -s "$DG/body.hook" "$DG/body.fb"; then
      ok "(g) the fallback's executable body is byte-identical to the hook's readset_drop_git"
    else
      bad "(g) the fallback body in the READSET_BOTH span differs from the hook's readset_drop_git (or is empty): [$(tr '\n' ' ' < "$DG/body.fb")] vs [$(tr '\n' ' ' < "$DG/body.hook")]"
    fi
    sed 's|index(\$0, "\.git/") != 1|index($0, ".git/") != 0|' "$DG/univ.span" > "$DG/univ.drift"
    dg_body "$DG/univ.drift" > "$DG/body.drift"
    MERGE_ARMS=$((MERGE_ARMS+1))
    if cmp -s "$DG/univ.span" "$DG/univ.drift"; then bad "(g) SEEDED MISMATCH did not apply"
    elif cmp -s "$DG/body.drift" "$DG/body.fb"; then bad "(g) SEEDED MISMATCH: a drifted hook predicate still compared equal to the fallback, so the byte-compare cannot fail"
    else ok "(g) a seeded drift in the hook's predicate FAILS the fallback byte-compare"
    fi
  fi


  # ------------------------------ a DECLARED fixture carries no map rows (readset_merge_map's 4th argument) ----
  # The hook maps a declared fixture (`inputs.decl`) before it reads the map, so its rows and `# digest` line
  # are dead. The merge drops them from the old map AND the new rows when given the fixture root; with three
  # arguments it is byte-identical to before. alpha is declared, beta is not.
  DM="$WORK/dm"
  mkdir -p "$DM/root/alpha" "$DM/root/beta" "$DM/root0" "$DM/rootnone" || broken "mkdir failed"
  : > "$DM/root/alpha/inputs.decl"; : > "$DM/root/alpha/run.sh"; : > "$DM/root/beta/run.sh"; : > "$DM/root0/beta.file"
  mkdir -p "$DM/root0/beta"; : > "$DM/root0/beta/run.sh"
  printf 'alpha\tsrc/a\nalpha\tsrc/x\nbeta\tsrc/b\nbeta\tsrc/c\n# digest alpha aaaa\n# digest beta bbbb\n' > "$DM/old.map"
  printf 'alpha\tsrc/NEW\nbeta\tsrc/NEWB\n' > "$DM/new.map"
  printf 'beta\tsrc/b\nbeta\tsrc/c\n# digest beta bbbb\nbeta\tsrc/NEWB\n' > "$DM/beta.want"
  dm_merge() { ( . "$1"; shift; fx_inproc "$DERIVER"; readset_merge_map "$@" ) 2>/dev/null; }
  dm_merge "$M" "$DM/old.map" "$DM/new.map" "" "$DM/root" > "$DM/out.4"
  dm_merge "$M" "$DM/old.map" "$DM/new.map" "" > "$DM/out.3"
  grep -v '^alpha' "$DM/out.4" | grep -v '^# digest alpha' > /dev/null
  MERGE_ARMS=$((MERGE_ARMS+1))
  if ! grep -q 'alpha' "$DM/out.4" && grep -q 'beta' "$DM/out.4"; then
    ok "(h) readset_merge_map with the fixture root: the declared alpha has no row and no digest line, from the old map or the new rows"
  else bad "(h) the 4-argument merge left alpha or lost beta: $(tr '\n' ' ' < "$DM/out.4")"
  fi
  MERGE_ARMS=$((MERGE_ARMS+1))
  if cmp -s "$DM/out.4" "$DM/beta.want"; then
    ok "(h) and the undeclared beta is byte-identical to its input rows (old rows, its digest line, its new row; cmp -s)"
  else bad "(h) beta's output differs from its input: $(tr '\n' ' ' < "$DM/out.4")"
  fi
  MERGE_ARMS=$((MERGE_ARMS+1))
  if grep -q 'alpha	src/a' "$DM/out.3" && grep -q '# digest alpha aaaa' "$DM/out.3" && grep -q 'alpha	src/NEW' "$DM/out.3"; then
    ok "(h) the same merge with THREE arguments keeps alpha's old rows, digest line and new row — the filter is opt-in"
  else bad "(h) the 3-argument merge no longer keeps alpha: $(tr '\n' ' ' < "$DM/out.3")"
  fi
  dm_merge "$M" "$DM/old.map" "$DM/new.map" "" "$DM/root0" > "$DM/out.0"
  dm_merge "$M" "$DM/old.map" "$DM/new.map" "" "$DM/rootnone" > "$DM/out.n"
  MERGE_ARMS=$((MERGE_ARMS+1))
  if cmp -s "$DM/out.0" "$DM/out.3" && cmp -s "$DM/out.n" "$DM/out.3" && [ -s "$DM/out.3" ]; then
    ok "(h) a root holding zero declared fixtures — and an empty root, where the glob does not expand — gives a merge byte-identical to the unfiltered one"
  else bad "(h) a root with no declared fixture changed the merge (the unexpanded glob read as a fixture?)"
  fi
  # A MAPPED fixture that gains inputs.decl is dropped by the merge on purpose; readset_untraced_lost must not report it.
  sed -n '/^# READSET_UNTRACED_BEGIN$/,/^# READSET_UNTRACED_END$/p' "$DERIVER" > "$DM/untraced.span"
  dm_merge "$M" "$DM/old.map" "/dev/null" "" "$DM/root" > "$DM/merged.map"
  dm_lost() { ( . "$DM/untraced.span"; fx_inproc "$DERIVER"; readset_untraced_lost "$DM/old.map" "$DM/merged.map" "" "$@" ) 2>/dev/null | tr '\n' ' '; }
  MERGE_ARMS=$((MERGE_ARMS+1))
  _l4="$(dm_lost "$DM/root")"; _l3="$(dm_lost)"
  if [ -z "$_l4" ] && [ "$_l3" = "alpha " ]; then
    ok "(h) a mapped fixture that gains inputs.decl is not reported lost with the root (control: without it readset_untraced_lost names 'alpha')"
  else bad "(h) readset_untraced_lost with the root says [$_l4]; without it [$_l3]; wanted empty and 'alpha '"
  fi
  # --all lists no declared fixture.
  sed -n '/^# READSET_ALLLIST_BEGIN$/,/^# READSET_ALLLIST_END$/p' "$DERIVER" > "$DM/alllist.span"
  MERGE_ARMS=$((MERGE_ARMS+1))
  fx_inproc "$DERIVER"
  _al="$( . "$DM/alllist.span"; readset_all_list "$DM/root" )"
  if [ "$_al" = beta ]; then ok "(h) readset_all_list skips the declared alpha (control: beta, which has a run.sh and no declaration, is listed)"
  else bad "(h) readset_all_list on a root with one declared and one undeclared fixture gave [$_al], wanted [beta]"
  fi


  # ------------------------- the --all subject list and the untraced-loss guard ----
  # THE `--all` LIST WAS BUILT NEWLINE-SEPARATED, AND TWO GUARDS SILENTLY NEVER MATCHED A NAME. Every
  # membership test on it is `case " $LIST " in *" $f "*)`, so under `--all` every fixture read as
  # untraced: one OMITTED fixture made the merge check die "merge dropped" and discard every good
  # trace, and the plan-shape controls never ran on any `--all` derivation. Three layers normalise
  # the list now -- the builder, the loss guard's own argument, and the merge -- and each is driven
  # here from its own sentinels, because a layered fix with one layer reverted
  # passes on the layers left in place.
  #
  # The SEED is the consumer's fixture-root shape, `tests/fixtures`, and it carries a directory with
  # no run.sh. The membership arms test the MIDDLE member: a list joined by any other separator still
  # starts and ends with a name, so only a middle member separates a space join from a tab join.
  AL="$WORK/alllist.sh"; UL="$WORK/untraced.sh"
  sed -n '/^# READSET_ALLLIST_BEGIN$/,/^# READSET_ALLLIST_END$/p' "$DERIVER" > "$AL"
  sed -n '/^# READSET_UNTRACED_BEGIN$/,/^# READSET_UNTRACED_END$/p' "$DERIVER" > "$UL"
  MERGE_ARMS=$((MERGE_ARMS+1))
  if ! grep -q '^readset_all_list()' "$AL" || ! grep -q '^readset_untraced_lost()' "$UL"; then
    bad "extracted no readset_all_list (READSET_ALLLIST) or no readset_untraced_lost (READSET_UNTRACED) from $DERIVER — the --all list and the untraced-loss guard cannot be driven, and nothing below them ran"
  else
    ok "the deriver carries both the READSET_ALLLIST and READSET_UNTRACED spans, each defining its function"
    ALR="$WORK/allroot/tests/fixtures"
    mkdir -p "$ALR/aa" "$ALR/mid" "$ALR/zz" "$ALR/norun" || broken "mkdir failed"
    : > "$ALR/aa/run.sh"; : > "$ALR/mid/run.sh"; : > "$ALR/zz/run.sh"; : > "$ALR/norun/other.sh"
    NLC='
'
    allist_with() { ( . "$1"; fx_inproc "$DERIVER"; readset_all_list "$ALR" ) 2>/dev/null; }
    # al_newline / al_middle / al_exact: one verdict word each.
    al_newline() { case "$1" in *"$NLC"*) echo newline ;; '') echo empty ;; *) echo clean ;; esac; }
    al_middle()  { case " $1 " in *" mid "*) echo member ;; *) echo absent ;; esac; }
    al_exact()   { if [ "$1" = "aa mid zz" ]; then echo exact; else echo wrong; fi; }
    allist_with "$AL" > "$WORK/al.raw"
    AV="$(cat "$WORK/al.raw")"
    MERGE_ARMS=$((MERGE_ARMS+1))
    if [ "$(al_newline "$AV")" = clean ] && [ "$(wc -c < "$WORK/al.raw" | tr -d ' ')" -eq "${#AV}" ]; then
      ok "readset_all_list on a tests/fixtures root: the command-substitution value carries no newline, and the raw output has no trailing one either"
    else
      bad "readset_all_list output is not one newline-free line ('$AV', $(wc -c < "$WORK/al.raw" | tr -d ' ') raw bytes for ${#AV} chars) — every case \" \$LIST \" membership test in the deriver misses"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    if [ "$(al_middle "$AV")" = member ]; then
      ok "  and its MIDDLE member is space-delimited on both sides — case \" \$LIST \" in *\" mid \"*) matches"
    else
      bad "  the middle member 'mid' is not space-delimited in '$AV' — a list joined by another separator passes the first and last names only"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    if [ "$(al_exact "$AV")" = exact ]; then
      ok "  and it is EXACTLY 'aa mid zz': the directory with no run.sh is excluded"
    else
      bad "  expected exactly 'aa mid zz' (norun/ has no run.sh), got '$AV'"
    fi

    # readset_untraced_lost: the omitted fixture is NOT first in a NEWLINE-separated list -- the shape
    # the base `--all` builder produced, where only the first name could ever have matched.
    printf 'traced-a\tp1\nfx-om\tp2\nkeep\tp3\ntraced-c\tp4\n' > "$WORK/ul.old"
    printf 'traced-a\tp1\nkeep\tp3\ntraced-c\tp4\n' > "$WORK/ul.m1"
    printf 'traced-a\tp1\ntraced-c\tp4\n' > "$WORK/ul.m2"
    printf 'fx\tp1\nfx-b\tp2\n' > "$WORK/ul.old3"; printf 'fx-b\tp2\n' > "$WORK/ul.m3"
    UL_NL="traced-a${NLC}fx-om${NLC}traced-c"
    ul_with() { # $1 span copy, $2 old, $3 merged, $4 traced; prints "<rc>|<output, space-joined>"
      local o r
      o="$( fx_inproc "$DERIVER"; . "$1"; fx_inproc "$DERIVER"; readset_untraced_lost "$2" "$3" "$4" 2>/dev/null )"; r=$?
      printf '%s|%s' "$r" "$(printf '%s' "$o" | tr '\n' ' ' | sed 's/ $//')"
    }
    MERGE_ARMS=$((MERGE_ARMS+1))
    U1="$(ul_with "$UL" "$WORK/ul.old" "$WORK/ul.m1" "$UL_NL")"
    if [ "$U1" = "0|" ]; then
      ok "m1: a newline-separated traced list whose OMITTED fixture is not first reports no loss — the omitted fixture was traced, and the untouched one was kept"
    else
      bad "m1: expected rc 0 and no lost fixture, got '$U1' — under --all one omitted fixture would make the merge check die and discard every good trace"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    U2="$(ul_with "$UL" "$WORK/ul.old" "$WORK/ul.m2" "$UL_NL")"
    if [ "$U2" = "0|keep" ]; then
      ok "m2: an UNTOUCHED fixture missing from the merged map is printed ('keep') — the guard still fires"
    else
      bad "m2: expected rc 0 printing exactly 'keep', got '$U2' — a merge losing an untraced fixture would be written"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    U3="$(ul_with "$UL" "$WORK/ul.old3" "$WORK/ul.m3" "fx-b")"
    if [ "$U3" = "0|fx" ]; then
      ok "m3: traced 'fx-b' does not count 'fx' as traced — membership is by exact name, so the lost 'fx' is printed"
    else
      bad "m3: expected 'fx' printed with only 'fx-b' traced, got '$U3' — a substring membership test reports 'fx' kept while it is gone"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    U4="$(ul_with "$UL" "$WORK/ul.old" "$WORK/ul.no-such-merged" "x")"
    if [ "$U4" = "2|" ]; then
      ok "an UNREADABLE merged map returns 2 with nothing printed, so the caller can tell 'did not look' from 'lost nothing'"
    else
      bad "an unreadable merged map did not return 2 with empty output: '$U4'"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    U5="$(ul_with "$UL" "$WORK/ul.old" "$WORK/ul.m2" "traced-a fx-om traced-c")"
    if [ "$U5" = "$U2" ] && [ "$U5" = "0|keep" ]; then
      ok "  and a SPACE-separated list gives the same answer as the newline-separated one"
    else
      bad "  the space-separated list answers '$U5' where the newline-separated one answers '$U2'"
    fi

  fi

  # ------------------------------------------- the deriver's discrimination control ----
  # WHAT THIS CONTROL IS FOR. The map exists to let fixtures be SKIPPED. A map in which every
  # read-set covers every path the map names selects the whole suite on every change and skips
  # nothing -- correct, useless, and indistinguishable from a working map by any arm that reads
  # the suite's verdict. The deriver refuses to WRITE such a map, and this is the arm that says
  # so.
  #
  # THE DEFECT THESE ARMS EXIST BECAUSE OF, AND WHY IT COULD NOT BE SEEN. The control built its
  # universe from the entries the run had just TRACED. Under `--list "<one fixture>"` that
  # universe IS that one fixture's read-set: the subset test is false for every possible input,
  # so the control refused every single-fixture refresh -- the mode the deriver's own header
  # advertises -- while printing the same FAIL line a genuinely non-discriminating map produces.
  # A wrong refusal and a right one read identically from outside, and the workaround (name more
  # fixtures) made the refusal go away without anyone learning why. Arm (d) below is the
  # motivating case and it is the one that would have been RED at base.
  #
  # THE CONTROL IS DRIVEN, NOT GREPPED. The rest of the deriver needs root and cannot run here,
  # so the shipped logic is extracted between its own sentinels and called -- a line-order grep
  # over the script would pass against a control that is present, correctly ordered, and wrong.
  #
  # A DERIVER PRESENT WITHOUT ITS CONTROL SPAN IS A FAILURE, NOT A SKIP, and the asymmetry with
  # the block above is deliberate. The ships-ahead-of-its-subject case is the deriver being
  # ABSENT, which is what a consumer sees between two pulls; a consumer never sees a deriver that
  # arrived without part of itself, because install.sh copies core/scripts and core/fixtures in
  # the same pull. Here, that state is a revision of this repo where the control has not landed.
  CTL="$WORK/control.sh"
  sed -n '/# READSET_CONTROL_BEGIN/,/# READSET_CONTROL_END/p' "$DERIVER" > "$CTL"
  if ! grep -q 'readset_discrimination_control()' "$CTL"; then
    bad "extracted no readset_discrimination_control from $DERIVER — the READSET_CONTROL span is absent, so the deriver's discrimination control cannot be driven and nothing below it ran"
  else
  # shellcheck disable=SC1090
  . "$CTL"

  # An independent recomputation of the control's own verdict, in shell rather than awk, so a
  # number the function PRINTS can be compared against one derived some other way. Echoes the
  # count of fixtures whose read-set is a PROPER subset of the map's union.
  ctl_proper_by_hand() {
    local map="$1" u f n p=0
    u="$(cut -f2 "$map" | LC_ALL=C sort -u | grep -c .)" || u=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      n="$(awk -F'\t' -v x="$f" '$1 == x { print $2 }' "$map" | LC_ALL=C sort -u | grep -c .)" || n=0
      [ "$n" -lt "$u" ] && p=$((p+1))
    done < <(cut -f1 "$map" | LC_ALL=C sort -u)
    printf '%s' "$p"
  }
  ctl_universe_of() { local n; n="$(cut -f2 "$1" | LC_ALL=C sort -u | grep -c .)" || n=0; printf '%s' "$n"; }
  ctl_fixtures_of() { local n; n="$(cut -f1 "$1" | LC_ALL=C sort -u | grep -c .)" || n=0; printf '%s' "$n"; }

  # SEEDS, each asserted to carry the property its arm turns on BEFORE any verdict is read. A
  # seed that quietly lost its property produces an arm that agrees with every implementation.
  printf 'alpha\tsrc/a\nalpha\tsrc/shared\nbeta\tsrc/b\nbeta\tsrc/shared\nbeta\tsrc/extra\n' > "$WORK/ctl.disc.map"
  printf 'alpha\tsrc/a\nalpha\tsrc/b\nbeta\tsrc/a\nbeta\tsrc/b\n' > "$WORK/ctl.cover.map"
  printf 'alpha\tsrc/NEW\n' > "$WORK/ctl.single.map"
  printf 'alpha\tsrc/a\nalpha\tsrc/x\nbeta\tsrc/b\ngamma\tsrc/g\n' > "$WORK/ctl.old.map"
  printf 'alpha\tsrc/ONLY\n' > "$WORK/ctl.new.map"
  [ "$(ctl_fixtures_of "$WORK/ctl.disc.map")" -ge 2 ] && [ "$(ctl_proper_by_hand "$WORK/ctl.disc.map")" -gt 0 ] \
    || broken "the discriminating seed carries no proper subset over >=2 fixtures; arm (a) would pass against a control that never compares anything"
  [ "$(ctl_proper_by_hand "$WORK/ctl.cover.map")" -eq 0 ] && [ "$(ctl_fixtures_of "$WORK/ctl.cover.map")" -ge 2 ] \
    || broken "the all-cover seed is not all-cover; arm (b) would be asserting a refusal of an input that ought to pass"
  [ "$(ctl_fixtures_of "$WORK/ctl.single.map")" -eq 1 ] \
    || broken "the single-fixture seed names more than one fixture; arm (c) tests the wrong shape"
  # THE PROPERTY ARM (d) TURNS ON. If the two maps' unions were equal, driving the
  # control on the merged map and on the traced map would return the same verdict and neither
  # arm could tell base from tip.
  [ "$(ctl_universe_of "$WORK/ctl.old.map")" -gt "$(ctl_universe_of "$WORK/ctl.new.map")" ] \
    || broken "the --list seeds' unions do not differ ($(ctl_universe_of "$WORK/ctl.old.map") vs $(ctl_universe_of "$WORK/ctl.new.map")); arm (d) would agree on every implementation"
  [ "$(ctl_proper_by_hand "$WORK/ctl.new.map")" -eq 0 ] \
    || broken "the traced-alone seed already discriminates, so the base defect it stands in for cannot be expressed"

  # (a) A MERGED MAP THAT DISCRIMINATES PASSES, and the verdict LINE is asserted, not just the
  # status: a control replaced by `true` returns 0 with nothing printed, which an rc-only arm
  # cannot tell from a control that looked.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  fx_inproc "$DERIVER"
  CA="$(readset_discrimination_control "$WORK/ctl.disc.map" 2>&1)"; CA_RC=$?
  case "$CA_RC:$CA" in
    0:*"PASS  CONTROL"*) ok "the deriver's control ACCEPTS a map in which a read-set is a proper subset of the union — the map can skip something" ;;
    *) bad "a discriminating map was not accepted (rc $CA_RC): $(printf '%s' "$CA" | tr -d '\n')" ;;
  esac

  # (b) EVERY READ-SET EQUAL TO THE UNION IS REFUSED. This is the map the control exists to
  # stop: it is written, it is correct, and it skips nothing.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  fx_inproc "$DERIVER"
  CB="$(readset_discrimination_control "$WORK/ctl.cover.map" 2>&1)"; CB_RC=$?
  case "$CB_RC:$CB" in
    1:*"FAIL  CONTROL"*) ok "  and it REFUSES a map in which every read-set covers the whole universe — that map would select the whole suite on every change" ;;
    *) bad "a map that discriminates nothing was not refused (rc $CB_RC): $(printf '%s' "$CB" | tr -d '\n')" ;;
  esac

  # (c) THE FIX BOUGHT THE PASS BY MERGING, NOT BY DISABLING THE CONTROL. A one-fixture map is
  # its own universe, so it still fails -- which is what makes arm (d) evidence about the merge
  # rather than about a control that was loosened until `--list` stopped complaining.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  fx_inproc "$DERIVER"
  CC="$(readset_discrimination_control "$WORK/ctl.single.map" 2>&1)"; CC_RC=$?
  case "$CC_RC:$CC" in
    1:*"FAIL  CONTROL"*) ok "  and a ONE-FIXTURE map still fails, so the single-fixture refresh was fixed by merging rather than by relaxing the control" ;;
    *) bad "a single-fixture map was accepted (rc $CC_RC) — the control was loosened, not the input widened: $(printf '%s' "$CC" | tr -d '\n')" ;;
  esac

  # (d) THE MOTIVATING CASE, COMPOSED FROM THE TWO SHIPPED BLOCKS. `--list "<one fixture>"`
  # traces one fixture, merges its entries over the committed map, and the control judges the
  # map the run will WRITE. Judged on the traced entries alone -- the base behaviour -- this
  # returns 1 and refuses a refresh that is entirely correct.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  fx_inproc "$DERIVER"
  readset_merge_map "$WORK/ctl.old.map" "$WORK/ctl.new.map" "alpha" | LC_ALL=C sort -u > "$WORK/ctl.merged.map"
  if [ "$(ctl_fixtures_of "$WORK/ctl.merged.map")" -lt 2 ]; then
    bad "the composed --list merge produced fewer than 2 fixtures, so arm (d) would test the single-fixture shape again instead of the merged one"
  else
    fx_inproc "$DERIVER"
    CD="$(readset_discrimination_control "$WORK/ctl.merged.map" 2>&1)"; CD_RC=$?
    case "$CD_RC:$CD" in
      0:*"PASS  CONTROL"*) ok "a --list refresh of ONE fixture is judged on the MERGED map and passes — the mode the deriver advertises is reachable" ;;
      *) bad "a --list refresh of one fixture was refused on its merged map (rc $CD_RC): $(printf '%s' "$CD" | tr -d '\n')" ;;
    esac
  fi

  # AND THE SHIPPED FUNCTION'S OWN ANSWER IS DERIVED FROM ONE FILE, shown by comparing the
  # number the function PRINTS against the same number recomputed in shell over the same map --
  # two independently derived values rather than one value read twice.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  fx_inproc "$DERIVER"
  CP_FN="$(readset_discrimination_control "$WORK/ctl.disc.map" 2>&1 | sed -n 's/.*CONTROL: \([0-9][0-9]*\) of .*/\1/p')"
  CP_HAND="$(ctl_proper_by_hand "$WORK/ctl.disc.map")"
  if [ -n "$CP_FN" ] && [ "$CP_FN" = "$CP_HAND" ]; then
    ok "  and the proper-subset count it reports ($CP_FN) equals one recomputed independently over that same file — both sides of the comparison come from one map"
  else
    bad "  the reported proper-subset count ('$CP_FN') does not match the hand-derived one ($CP_HAND) over the same map — the two sides are not being counted from the same file"
  fi

  # CONTROL, re-sourced from the extracted span. Presence-shaped on purpose: a function replaced by
  # nothing returns 0 and prints nothing, which is what a `bad` here catches and an rc-only
  # assertion would not.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  fx_inproc "$DERIVER"
  CTL_OUT="$( . "$CTL"; readset_discrimination_control "$WORK/ctl.disc.map" 2>&1 )"; CTL_RC=$?
  case "$CTL_RC:$CTL_OUT" in
    0:*"PROPER subset of the 4-path universe"*)
      ok "CONTROL: the span still reports the baseline verdict over the 4-path universe" ;;
    *)
      bad "CONTROL: the span did not reproduce the baseline (rc $CTL_RC): $(printf '%s' "$CTL_OUT" | tr -d '\n')" ;;
  esac

  # (e) THE CALL SITE, WHICH EVERY ARM ABOVE IS BLIND TO. Arms (a)-(d)
  # all drive the EXTRACTED function; none of them reads the line that CALLS it. A non-fix that
  # leaves the function byte-identical and passes the TRACED map at the call site --
  # `readset_discrimination_control "$WORK/map"` instead of `"$MERGED"` -- reproduces the
  # original defect exactly (every single-fixture `--list` refresh dies) and is green on all of
  # them. Text about a program is not the program: the span proves what the function DOES, and
  # this arm proves what the deriver ASKS it. Both halves of the fix are one shipped behaviour.
  #
  # DERIVED, NEVER HAND-LISTED. Line numbers move on every edit above them, so the facts are
  # computed by one awk pass over the shipped file: the sentinel span is skipped so the
  # definition's own name is not counted as a call, `#` comments and quoted text are stripped
  # so neither a mention in prose nor one inside a string is counted as a call, and the
  # remaining invocations are counted. Exactly one must survive, its argument must be the
  # MERGED map, and both the assignment and the merge that fills it must sit above it -- a call
  # above `MERGED=` reads an unset variable under `set -u` and one above the merge judges an
  # empty file.
  #
  # THE QUOTE STATE IS CARRIED ACROSS LINES, which is the only correct model here: this deriver
  # embeds a multi-line awk program, a multi-line `python3 -c`, and a `die` message wrapped over
  # two lines. A per-line scanner calls all six of those lines unbalanced and then reports
  # nothing about the call site. Balance is asserted at END instead, so a genuinely unterminated
  # quote still refuses to answer rather than answering wrongly.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CS="$(awk '
    BEGIN { TOK = "readset_discrimination_control"; L = length(TOK); SQ = sprintf("%c", 39); BS = "\\" }
    index($0, "# READSET_CONTROL_BEGIN") { span = 1; next }
    span { if (index($0, "# READSET_CONTROL_END")) span = 0; next }
    {
      code = ""; skel = ""; prev = ""; n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (q == SQ) {
          code = code c
          if (c == SQ) { skel = skel c; q = "" }
        } else if (q == "\"") {
          code = code c
          if (c == BS && i < n) { i++; code = code substr($0, i, 1); prev = c; continue }
          if (c == "\"") { skel = skel c; q = "" }
        } else {
          if (c == "#" && (i == 1 || prev == " " || prev == "\t")) break
          code = code c; skel = skel c
          if (c == BS && i < n) { i++; code = code substr($0, i, 1); skel = skel substr($0, i, 1) }
          else if (c == "\"" || c == SQ) q = c
        }
        prev = c
      }
      s = skel
      while ((p = index(s, TOK)) > 0) {
        ncall++; calls = calls " " FNR
        if (ncall == 1) {
          t = substr(code, index(code, TOK) + L)
          sub(/^[[:blank:]]+/, "", t)
          if (match(t, /^[^[:blank:]]+/)) arg = substr(t, 1, RLENGTH)
          cline = FNR
        }
        s = substr(s, p + L)
      }
      if (mline == 0 && code ~ /^[[:blank:]]*MERGED=/) mline = FNR
      if (rline == 0 && index(code, "readset_merge_map") && code ~ />[[:blank:]]*"\$MERGED"/) rline = FNR
      if (dline == 0 && index(code, "die \"controls failed")) dline = FNR
    }
    END {
      printf "%d %d %s %d %d %d %s\n", ncall, cline + 0, (arg == "" ? "-" : arg), \
        mline + 0, rline + 0, dline + 0, (q == "" ? "-" : "UNTERMINATED-QUOTE")
      printf "%s\n", (calls == "" ? "-" : calls)
    }
  ' "$DERIVER")"
  CS_HEAD="$(printf '%s\n' "$CS" | sed -n 1p)"
  CS_AT="$(printf '%s\n' "$CS" | sed -n 2p)"
  read -r E_N E_CALL E_ARG E_MERGED E_RUN E_DIE E_UNBAL <<EOF
$CS_HEAD
EOF
  if [ "$E_UNBAL" != "-" ]; then
    bad "(e) the call-site scan could not parse $DERIVER — a quote is left unterminated at end of file, so its comment and string stripping is unreliable and its counts are not evidence"
  elif [ "${E_N:-0}" -ne 1 ]; then
    bad "(e) the deriver makes $E_N calls to readset_discrimination_control outside the READSET_CONTROL span (lines$CS_AT) — exactly one is expected, and a second call site is judged by nothing here"
  elif [ "$E_ARG" != '"$MERGED"' ]; then
    bad "(e) the deriver's only call passes $E_ARG at line $E_CALL, not \"\$MERGED\" — the control is being driven on a map other than the merged one, which is the base defect (a single-fixture --list refresh is refused) with the function left byte-identical"
  elif [ "${E_MERGED:-0}" -eq 0 ] || [ "${E_RUN:-0}" -eq 0 ]; then
    bad "(e) the deriver has no MERGED= assignment (line ${E_MERGED:-0}) or no 'readset_merge_map ... > \"\$MERGED\"' (line ${E_RUN:-0}) — the argument named at line $E_CALL is not filled by the merge at all"
  elif [ "$E_MERGED" -ge "$E_CALL" ] || [ "$E_RUN" -ge "$E_CALL" ]; then
    bad "(e) the call at line $E_CALL runs before MERGED= (line $E_MERGED) or before the merge that fills it (line $E_RUN) — it would judge an unset or empty map"
  elif [ "${E_DIE:-0}" -eq 0 ] || [ "$E_CALL" -ge "$E_DIE" ]; then
    bad "(e) the call at line $E_CALL does not precede the 'die \"controls failed' at line ${E_DIE:-0} — its verdict is read after the run has already decided, or that die is gone and no verdict stops the write"
  else
    ok "the deriver's ONLY call of the control (line $E_CALL) passes the MERGED map, built by the merge at line $E_RUN into the variable assigned at line $E_MERGED, and is read by the die at line $E_DIE — the call site is bound, not just the function"
  fi
  fi

  # (f) THE CALL SITES OF THE TWO NEW SPANS. Every arm on readset_all_list and readset_untraced_lost
  # above drives the EXTRACTED function; a deriver that defines both and calls neither -- `--all`
  # back on its inline loop, the loss check deleted or demoted to a warning -- is green on all of
  # them. This scan reads what the deriver ASKS.
  #
  # THE (e) SCANNER CANNOT SEE `LIST="$(readset_all_list ...)"`: it drops quoted text, and that call
  # sits inside a double-quoted command substitution. This one carries a frame STACK, so a `$(`
  # inside double quotes returns to code until its own `)` and then back to the quote; balance of
  # both the quote state and the stack is asserted at END, so an unparseable file refuses to answer.
  # Both definition spans are skipped, so a definition is never counted as a call.
  rs_callscan() { # $1 deriver file; prints KEY<TAB>VALUE lines
    awk '
      BEGIN { SQ = sprintf("%c", 39); BS = "\\"; k = 0 }
      index($0, "# READSET_ALLLIST_BEGIN") == 1 || index($0, "# READSET_UNTRACED_BEGIN") == 1 { span = 1; next }
      span { if (index($0, "# READSET_ALLLIST_END") == 1 || index($0, "# READSET_UNTRACED_END") == 1) span = 0; next }
      {
        code = ""; skel = ""; prev = ""; n = length($0)
        for (i = 1; i <= n; i++) {
          c = substr($0, i, 1)
          if (q == SQ) {
            code = code c
            if (c == SQ) q = ""
          } else if (q == "\"") {
            code = code c
            if (c == BS && i < n) { i++; code = code substr($0, i, 1); prev = c; continue }
            if (c == "\"") q = ""
            else if (c == "$" && substr($0, i + 1, 1) == "(") { i++; code = code "("; k++; fr[k] = "\""; dep[k] = 0; q = "" }
          } else {
            if (c == "#" && (i == 1 || prev == " " || prev == "\t")) break
            code = code c; skel = skel c
            if (c == BS && i < n) { i++; code = code substr($0, i, 1); skel = skel substr($0, i, 1) }
            else if (c == "\"" || c == SQ) q = c
            else if (c == "$" && substr($0, i + 1, 1) == "(") { i++; code = code "("; skel = skel "("; k++; fr[k] = ""; dep[k] = 0 }
            else if (c == "(" && k > 0) dep[k]++
            else if (c == ")" && k > 0) { if (dep[k] == 0) { q = fr[k]; k-- } else dep[k]-- }
          }
          prev = c
        }
        if (index(skel, "readset_all_list")) { nal++; if (nal == 1) { alline = FNR; altext = code } }
        if (index(skel, "readset_untraced_lost")) { nul++; if (nul == 1) { ulline = FNR; ultext = code } }
        if (rline == 0 && index(code, "readset_merge_map") && code ~ />[[:blank:]]*"\$MERGED"/) rline = FNR
        if (cline == 0 && index(code, "die \"could not compare")) cline = FNR
        if (dline == 0 && index(code, "die \"merge dropped " SQ)) dline = FNR
        if (wline == 0 && code ~ /^}[[:blank:]]*>[[:blank:]]*"\$MAP_TMP"/) wline = FNR
      }
      END {
        printf "BAL\t%s\n", (q == "" && k == 0) ? "ok" : "UNBALANCED"
        printf "NAL\t%d\nALLINE\t%d\nALTEXT\t%s\n", nal, alline, altext
        printf "NUL\t%d\nULLINE\t%d\nULTEXT\t%s\n", nul, ulline, ultext
        printf "RLINE\t%d\nCLINE\t%d\nDLINE\t%d\nWLINE\t%d\n", rline, cline, dline, wline
      }
    ' "$1"
  }
  cs_get() { printf '%s\n' "$1" | sed -n "s/^$2	//p"; }
  # rs_callverdict <scan> -> one word per span: AL:<verdict> UL:<verdict>
  rs_callverdict() {
    local s="$1" alv ulv t n
    if [ "$(cs_get "$s" BAL)" != ok ]; then printf 'AL:unparsed UL:unparsed'; return; fi
    n="$(cs_get "$s" NAL)"; t="$(cs_get "$s" ALTEXT)"
    if [ "${n:-0}" -ne 1 ]; then alv="calls=$n"
    else case "$t" in
      *'--all)'*'LIST="$(readset_all_list "$TREE/$FIXTURE_ROOT")"'*) alv=bound ;;
      *) alv=wrongcall ;;
    esac; fi
    n="$(cs_get "$s" NUL)"; t="$(cs_get "$s" ULTEXT)"
    local ul r c d w; ul="$(cs_get "$s" ULLINE)"; r="$(cs_get "$s" RLINE)"; c="$(cs_get "$s" CLINE)"; d="$(cs_get "$s" DLINE)"; w="$(cs_get "$s" WLINE)"
    if [ "${n:-0}" -ne 1 ]; then ulv="calls=$n"
    else case "$t" in
      *'readset_untraced_lost "$MAP" "$MERGED" "$LIST"'*)
        if [ "$r" -eq 0 ] || [ "$r" -ge "$ul" ]; then ulv=beforemerge
        elif [ "$c" -eq 0 ] || [ "$c" -lt "$ul" ] || [ "$c" -gt $((ul+1)) ]; then ulv=unrefused
        elif [ "$d" -eq 0 ] || [ "$d" -le "$ul" ] || [ "$w" -eq 0 ] || [ "$d" -ge "$w" ]; then ulv=nodie
        else ulv=bound; fi ;;
      *) ulv=wrongcall ;;
    esac; fi
    printf 'AL:%s UL:%s' "$alv" "$ulv"
  }
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CSN="$(rs_callscan "$DERIVER")"
  CSV="$(rs_callverdict "$CSN")"
  case "$CSV" in
    "AL:bound UL:bound") ok "(f) the deriver's only readset_all_list call (line $(cs_get "$CSN" ALLINE)) builds LIST under --all from \$TREE/\$FIXTURE_ROOT, and its only readset_untraced_lost call (line $(cs_get "$CSN" ULLINE)) compares the merged map after the merge (line $(cs_get "$CSN" RLINE)), refuses on a failed compare (line $(cs_get "$CSN" CLINE)) and dies 'merge dropped' (line $(cs_get "$CSN" DLINE)) before the write (line $(cs_get "$CSN" WLINE))" ;;
    *) bad "(f) the call sites of the two new spans are not bound: $CSV — scan: $(printf '%s' "$CSN" | tr '\n\t' ' =')" ;;
  esac

  fi
  if sg tracer; then
  # ------------------------------------------------------- the trace tree's POPULATION ----
  # WHAT THE TRACE TREE HOLDS DECIDES WHAT A FIXTURE CAN READ WHILE IT IS TRACED. It was `cp -a`
  # of the whole working tree; it is now `.git/` plus `git ls-files --cached --others
  # --exclude-standard`. The copy is extracted between its own sentinels and DRIVEN on a seeded
  # repo carrying one member per property the copy must get right, and the population is
  # compared EXACTLY -- a count or a presence check would accept a copy that carries extra files.
  #
  # THE SEED CARRIES ONE MEMBER PER WAY THE COPY CAN GO WRONG: the populated SUBMODULE's files, the
  # untracked-not-ignored file, and the `.claude/rules/` NEGATION.
  CP="$WORK/copy.sh"
  sed -n '/# READSET_COPY_BEGIN/,/# READSET_COPY_END/p' "$DERIVER" > "$CP"
  CSEED="$WORK/copyseed"
  TRACE_ARMS=$((TRACE_ARMS+1))
  if ! grep -q 'readset_copy_tree()' "$CP"; then
    bad "extracted no readset_copy_tree from $DERIVER — the READSET_COPY span is absent, so the trace tree's population cannot be driven"
  else
    mkdir -p "$CSEED/inner" "$CSEED/src" || broken "mkdir failed"
    ( cd "$CSEED/inner" && git init -q . && echo i > in.txt && git add in.txt \
        && git -c user.email=f@f -c user.name=f commit -qm i ) >/dev/null 2>&1 || broken "could not seed the submodule's origin"
    ( cd "$CSEED/src" && git init -q . \
        && printf 'ignored.log\n.claude/*\n!.claude/rules/\n' > .gitignore \
        && echo t > tracked.txt && echo x > exec.sh && chmod 755 exec.sh && echo s > 'sp ace.txt' \
        && ln -s tracked.txt link && ln -s nowhere dangling \
        && mkdir -p .claude/rules && echo r > .claude/rules/x.md && echo '{}' > .claude/settings.local.json \
        && echo gone > deleted.txt \
        && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed \
        && git -c protocol.file.allow=always submodule -q add "file://$CSEED/inner" lib/sub \
        && git -c user.email=f@f -c user.name=f commit -qm sub \
        && echo u > untracked.txt && echo i > ignored.log && rm deleted.txt \
        && touch -m -t 200501010000 tracked.txt ) >/dev/null 2>&1 || broken "could not seed the copy's source repo"
    # THE SEED MUST CARRY EVERY PROPERTY BEFORE ANY VERDICT IS READ: a submodule that was not
    # populated cannot test the gitlink handling, and an unignored settings file cannot test the negation.
    [ -f "$CSEED/src/lib/sub/in.txt" ] && [ -f "$CSEED/src/.claude/settings.local.json" ] \
      && [ -f "$CSEED/src/untracked.txt" ] && [ -f "$CSEED/src/ignored.log" ] \
      && ( cd "$CSEED/src" && git ls-files -s | grep -q '^160000' ) \
      && ( cd "$CSEED/src" && git check-ignore -q .claude/settings.local.json ) \
      && ! ( cd "$CSEED/src" && git check-ignore -q .claude/rules/x.md ) \
      || broken "the copy seed lost a property (populated gitlink, ignored settings file, negated rules file, untracked file) — the arms below could not tell a right copy from a wrong one"

    # The one population a correct copy produces: every regular file and symlink outside `.git/`.
    printf '%s\n' ./.claude/rules/x.md ./.gitignore ./.gitmodules ./dangling ./exec.sh ./link \
      './sp ace.txt' ./tracked.txt ./untracked.txt | LC_ALL=C sort > "$CSEED/expected"

    # copy_with <impl-file> <label> -> leaves the tree at $CSEED/dst.<label>, its stdout in .out,
    # and prints the DEFECTS found: population diff lines and named property failures.
    copy_with() {
      local impl="$1" label="$2" dst="$CSEED/dst.$2" scr="$CSEED/scr.$2" v=""
      mkdir -p "$dst" "$scr"
      ( fx_inproc "$DERIVER"; . "$impl"; fx_inproc "$DERIVER"; readset_copy_tree "$CSEED/src" "$dst" "$scr" ) > "$CSEED/$label.out" 2>&1
      ( cd "$dst" && find . -path ./.git -prune -o \( -type f -o -type l \) -print ) | LC_ALL=C sort > "$CSEED/$label.pop"
      v="$(LC_ALL=C comm -3 "$CSEED/expected" "$CSEED/$label.pop" | sed 's/^\t/EXTRA:/; s/^\.\//MISSING:.\//' | tr '\n' ' ')"
      [ -L "$dst/link" ] && [ "$(readlink "$dst/link")" = tracked.txt ] || v="$v link-not-a-symlink"
      [ -L "$dst/dangling" ] || v="$v dangling-symlink-lost"
      [ -x "$dst/exec.sh" ] || v="$v exec-bit-lost"
      [ -n "$(find "$dst/tracked.txt" -newer "$CSEED/src/tracked.txt" 2>/dev/null)" ] && v="$v mtime-not-preserved"
      [ -d "$dst/lib/sub" ] || v="$v gitlink-dir-absent"
      [ -d "$dst/.git/modules/lib/sub" ] || v="$v git-dir-not-copied"
      printf '%s' "$v"
    }

    CV="$(copy_with "$CP" shipped)"
    if [ -z "$CV" ]; then
      ok "the shipped copy lands EXACTLY the tracked and untracked-not-ignored files — exec bit, mtime, a space in a name, a symlink and a dangling symlink kept; the ignored file, the ignored .claude/settings.local.json and the submodule's contents absent; the negated .claude/rules/x.md present; .git/ whole"
    else
      bad "the shipped copy's population is wrong: $CV"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    if [ -d "$CSEED/dst.shipped/lib/sub" ] && [ -z "$(ls -A "$CSEED/dst.shipped/lib/sub" 2>/dev/null)" ] \
       && grep -q "deleted.txt" "$CSEED/shipped.out"; then
      ok "  and the GITLINK lands as an EMPTY directory, and the deleted-unstaged path is skipped and NAMED rather than aborting the copy"
    else
      bad "  the gitlink is not an empty directory, or the deleted-unstaged path was not named: $(tr '\n' ' ' < "$CSEED/shipped.out")"
    fi

    # BL-701: FROM A LINKED WORKTREE the copy builds `.git` STANDALONE (readset_git_standalone, in the same
    # span), because the worktree's own `.git` is a gitlink file naming the real private gitdir. The copy must
    # answer HEAD like the worktree, resolve as its own repository, and a commit in it must leave the
    # worktree's HEAD untouched. The near-miss is the main-checkout copy above, which keeps `.git` whole.
    # THE WORKTREE COMMITS ONCE BEFORE THE COPY, so its HEAD differs from the main checkout's in both the branch
    # and the commit: a copy that kept the main checkout's HEAD and index and never laid the private gitdir over
    # them answers a DIFFERENT commit on a different branch, where a worktree still on main's commit cannot tell.
    TRACE_ARMS=$((TRACE_ARMS+1))
    ( cd "$CSEED/src" && git worktree add -q -b lwcopy "$CSEED/lw" && cd "$CSEED/lw" && echo c >> exec.sh \
        && git -c user.email=f@f -c user.name=f commit -qam in-worktree && echo w >> tracked.txt ) >/dev/null 2>&1 \
      || broken "could not add a linked worktree to the copy seed"
    [ "$(cd "$CSEED/lw" && git rev-parse HEAD 2>/dev/null)" != "$(cd "$CSEED/src" && git rev-parse HEAD 2>/dev/null)" ] \
      || broken "the linked worktree's HEAD is the main checkout's — the arm below could not tell an overlaid copy from one that kept main's HEAD"
    mkdir -p "$CSEED/dst.lw" "$CSEED/scr.lw"
    fx_inproc "$DERIVER"
    ( . "$CP"; readset_copy_tree "$CSEED/lw" "$CSEED/dst.lw" "$CSEED/scr.lw" ) > "$CSEED/lw.out" 2>&1
    LW_SRC_HEAD="$(cd "$CSEED/lw" && git rev-parse HEAD 2>/dev/null)"
    LW_PRIV_HEAD="$(cat "$CSEED/src/.git/worktrees/lw/HEAD" 2>/dev/null)"
    LW_DST="$(cd "$CSEED/dst.lw" && git symbolic-ref HEAD 2>/dev/null)|$(cd "$CSEED/dst.lw" && git rev-parse HEAD 2>/dev/null)|$(cd "$CSEED/dst.lw" && git rev-parse --git-dir 2>/dev/null)|$(cd "$CSEED/dst.lw" && git status --porcelain 2>/dev/null | tr '\n' ' ')"
    ( cd "$CSEED/dst.lw" && git add -A && git -c user.email=f@f -c user.name=f commit -qm in-copy ) >/dev/null 2>&1
    if [ -d "$CSEED/dst.lw/.git" ] && [ ! -e "$CSEED/dst.lw/.git/commondir" ] && [ -n "$LW_SRC_HEAD" ] \
       && [ "$LW_DST" = "refs/heads/lwcopy|$LW_SRC_HEAD|.git| M tracked.txt " ] \
       && [ "$(cat "$CSEED/src/.git/worktrees/lw/HEAD" 2>/dev/null)" = "$LW_PRIV_HEAD" ] \
       && [ "$(cd "$CSEED/lw" && git rev-parse HEAD 2>/dev/null)" = "$LW_SRC_HEAD" ]; then
      ok "  from a LINKED worktree the copy carries a standalone .git that answers HEAD and status like the worktree, and a commit in the copy leaves the worktree's HEAD unmoved"
    else
      bad "  the linked-worktree copy is not a standalone repository answering like its source (dst '$LW_DST', src HEAD '$LW_SRC_HEAD'): $(tr '\n' ' ' < "$CSEED/lw.out")"
    fi

    # BL-1211: `.git/worktrees/` is never COPIED, so an entry in it that `cp -a` cannot read (what a concurrent
    # `git worktree remove` leaves mid-copy, made deterministic here by mode 000) cannot fail the copy. THE SEED
    # MUST REPRODUCE THE FAILURE: a plain `cp -a` of that directory has to fail first, or the arm proves nothing.
    # The positive conjuncts (HEAD, objects, the submodule's modules dir, the `copied` line) are what an `exit 0`
    # subject cannot produce.
    TRACE_ARMS=$((TRACE_ARMS+1))
    : > "$CSEED/src/.git/worktrees/lw/unreadable" && chmod 000 "$CSEED/src/.git/worktrees/lw/unreadable" \
      || broken "could not seed an unreadable entry under .git/worktrees"
    if cp -a "$CSEED/src/.git/worktrees" "$CSEED/probe.wt" >/dev/null 2>&1; then
      broken "cp -a read the mode-000 entry (running as a user that bypasses file modes?) — the BL-1211 arm could not tell a copy that skips worktrees/ from one that copies it"
    fi
    UNR_V="$(copy_with "$CP" unr)"
    UNR_RC=0; grep -q '^readset_copy_tree: ' "$CSEED/unr.out" && UNR_RC=1
    if [ "$UNR_RC" -eq 0 ] && [ -z "$UNR_V" ] && [ -f "$CSEED/dst.unr/.git/HEAD" ] && [ -d "$CSEED/dst.unr/.git/objects" ] \
       && [ -d "$CSEED/dst.unr/.git/modules/lib/sub" ] && [ ! -e "$CSEED/dst.unr/.git/worktrees" ] \
       && grep -q '^copied [0-9]* path(s) plus .git/' "$CSEED/unr.out"; then
      ok "  an unreadable entry under .git/worktrees does not fail the copy: rc 0, .git has HEAD, objects and modules, and no worktrees/"
    else
      bad "  the copy failed or carried worktrees/ with an unreadable entry under it (rc $UNR_RC): $(tr '\n' ' ' < "$CSEED/unr.out")"
    fi
    chmod 600 "$CSEED/src/.git/worktrees/lw/unreadable"

    # BL-1211: `git branch -D` (an agent-worktree cleanup runs it beside `git worktree remove`) deletes a ref and
    # its reflog while the copy runs; `refs/`, `logs/` and `packed-refs` never pass through `cp`, so an entry
    # `cp -a` cannot read under refs/heads or logs/refs/heads (mode 000 stands for the vanishing one,
    # deterministically) cannot fail the copy, and the refs are rewritten by git. THE SEED MUST REPRODUCE THE
    # FAILURE: a plain `cp -a` of each directory has to fail first. The NEGATIVE: an unreadable entry under
    # objects/ is no vanishing ref and must still fail the copy rc 1 with its message.
    TRACE_ARMS=$((TRACE_ARMS+1))
    : > "$CSEED/src/.git/refs/heads/zz-unreadable" && chmod 000 "$CSEED/src/.git/refs/heads/zz-unreadable" \
      && : > "$CSEED/src/.git/logs/refs/heads/zz-unreadable" && chmod 000 "$CSEED/src/.git/logs/refs/heads/zz-unreadable" \
      || broken "could not seed unreadable entries under .git/refs/heads and .git/logs/refs/heads"
    if cp -a "$CSEED/src/.git/refs" "$CSEED/probe.refs" >/dev/null 2>&1 || cp -a "$CSEED/src/.git/logs" "$CSEED/probe.logs" >/dev/null 2>&1; then
      broken "cp -a read a mode-000 ref or reflog entry — the BL-1211 refs arm could not tell a copy that skips refs/ and logs/ from one that copies them"
    fi
    REF_V="$(copy_with "$CP" refs)"
    REF_RC=0; grep -q '^readset_copy_tree: ' "$CSEED/refs.out" && REF_RC=1
    REF_SRC="$(cd "$CSEED/src" && git rev-parse refs/heads/lwcopy 2>/dev/null)"
    REF_DST="$(cd "$CSEED/dst.refs" && git rev-parse refs/heads/lwcopy 2>/dev/null)"
    if [ "$REF_RC" -eq 0 ] && [ -z "$REF_V" ] && [ -n "$REF_SRC" ] && [ "$REF_DST" = "$REF_SRC" ] \
       && [ "$(cd "$CSEED/dst.refs" && git rev-parse HEAD 2>/dev/null)" = "$(cd "$CSEED/src" && git rev-parse HEAD 2>/dev/null)" ] \
       && [ ! -e "$CSEED/dst.refs/.git/worktrees" ] && grep -q '^copied [0-9]* path(s) plus .git/' "$CSEED/refs.out"; then
      ok "  an unreadable entry under .git/refs/heads and .git/logs/refs/heads does not fail the copy: rc 0, the copy resolves the source's branch and HEAD to the same commits"
    else
      bad "  the copy failed, or lost a ref, with an unreadable entry under refs/heads and logs/refs/heads (rc $REF_RC, branch '$REF_DST' vs '$REF_SRC'): $(tr '\n' ' ' < "$CSEED/refs.out")"
    fi
    chmod 600 "$CSEED/src/.git/refs/heads/zz-unreadable" "$CSEED/src/.git/logs/refs/heads/zz-unreadable"
    rm -f "$CSEED/src/.git/refs/heads/zz-unreadable" "$CSEED/src/.git/logs/refs/heads/zz-unreadable"

    TRACE_ARMS=$((TRACE_ARMS+1))
    : > "$CSEED/src/.git/objects/zz-unreadable" && chmod 000 "$CSEED/src/.git/objects/zz-unreadable" \
      || broken "could not seed an unreadable entry under .git/objects"
    copy_with "$CP" objbad >/dev/null
    if grep -q '^readset_copy_tree: copying .git failed' "$CSEED/objbad.out" && ! grep -q '^copied ' "$CSEED/objbad.out"; then
      ok "  a genuinely unreadable entry under .git/objects still fails the copy rc 1 with its message"
    else
      bad "  an unreadable entry under .git/objects did not fail the copy as 'copying .git failed': $(tr '\n' ' ' < "$CSEED/objbad.out")"
    fi
    chmod 600 "$CSEED/src/.git/objects/zz-unreadable"
    rm -f "$CSEED/src/.git/objects/zz-unreadable"

  fi

  # ---------------------------------------------- submodule rows and the ignore filter ----
  # `git check-ignore --stdin` REFUSES A WHOLE BATCH -- exit 128, "is in submodule" -- when one
  # row lies inside a submodule, and drop_ignored's fail-open branch then keeps every row. On a
  # tree with a gitlink the ignore filter never ran. The shipped filter collapses submodule rows
  # to the gitlink path before asking. Driven from its sentinels, on the same seeded repo.
  DR="$WORK/drop.sh"
  sed -n '/# READSET_DROP_BEGIN/,/# READSET_DROP_END/p' "$DERIVER" > "$DR"
  TRACE_ARMS=$((TRACE_ARMS+1))
  if ! grep -q 'drop_ignored()' "$DR"; then
    bad "extracted no drop_ignored from $DERIVER — the READSET_DROP span is absent"
  elif [ ! -d "$CSEED/src/.git" ]; then
    bad "the submodule arm has no seeded repo to run on (the copy arm above did not seed one)"
  else
    printf '%s\n' tracked.txt ignored.log .claude/settings.local.json lib/sub/in.txt untracked.txt .claude/rules/x.md > "$CSEED/batch"
    printf '%s\n' .claude/rules/x.md lib/sub tracked.txt untracked.txt | LC_ALL=C sort > "$CSEED/batch.expected"
    # THE SEED MUST REPRODUCE THE REFUSAL, or the arm proves a filter that was never at risk.
    ( cd "$CSEED/src" && git check-ignore --stdin --non-matching --verbose < "$CSEED/batch" ) >/dev/null 2>&1
    CI_RC=$?
    [ "$CI_RC" -ne 0 ] || broken "raw check-ignore on the submodule batch exited 0 — the seed no longer reproduces the refusal"
    fx_inproc "$DERIVER"
    DO="$( TREE="$CSEED/src"; . "$DR"; drop_ignored < "$CSEED/batch" )"
    if [ "$(printf '%s\n' "$DO" | LC_ALL=C sort)" = "$(cat "$CSEED/batch.expected")" ]; then
      ok "a batch carrying a SUBMODULE row still filters (raw check-ignore exits $CI_RC on it): both ignored rows dropped, tracked, untracked and negated rows kept, the inner row collapsed to the gitlink"
    else
      bad "the submodule batch did not filter to exactly the non-ignored rows (raw check-ignore rc $CI_RC): got $(printf '%s' "$DO" | tr '\n' ' ')"
    fi
    # A TRACED NAME GIT MUST QUOTE NEVER BECOMES A ROW. check-ignore hands a tab-bearing name back
    # C-quoted, and the runner's manifest empties `.now` on any `"`-led path -- one such map row ran
    # the whole suite on every push. Seeded from the producer's own text (apply.sh's RESOLVED
    # manifest row, the name a consumer fixture stat'd), beside a plain row and a non-ASCII row that
    # must survive UNQUOTED.
    TRACE_ARMS=$((TRACE_ARMS+1))
    printf 'RESOLVED\trelocate\tscripts/x.sh\tplaced\ntracked.txt\ncaf\303\251.md\n' > "$CSEED/qbatch"
    QR="$( cd "$CSEED/src" && git check-ignore --stdin --non-matching --verbose < "$CSEED/qbatch" 2>/dev/null | sed -n 's/^::[[:space:]]*//p' )"
    case "$QR" in *'"RESOLVED\t'*) ;; *) broken "raw check-ignore no longer quotes a tab-bearing name — the seed does not reproduce the defect" ;; esac
    fx_inproc "$DERIVER"
    DQ="$( TREE="$CSEED/src"; . "$DR"; drop_ignored < "$CSEED/qbatch" )"
    if grep -q '^"' <<< "$DQ" || grep -q 'RESOLVED' <<< "$DQ"; then
      bad "a tab-bearing traced name reached the read-set (a quoted row empties the runner's manifest): $(printf '%s' "$DQ" | tr '\n' ' ')"
    elif [ "$(printf '%s\n' "$DQ" | LC_ALL=C sort)" != "$(printf 'caf\303\251.md\ntracked.txt\n' | LC_ALL=C sort)" ]; then
      bad "the quote-name batch did not filter to exactly the plain and the unquoted non-ASCII row: $(printf '%s' "$DQ" | tr '\n' ' ')"
    else
      ok "a tab-bearing traced name is dropped and a non-ASCII one survives unquoted: no row the runner's manifest refuses can reach a map"
    fi
  fi


  # ------------------------------------------------- `--tracer both`: the comparison mode ----
  # The operator runs `sudo bash core/scripts/derive-fixture-readsets.sh --all --tracer both` to
  # decide whether the sandbox tracer may replace fs_usage. Its verdict must never read clean
  # having compared nothing, its refusals must never read as a verdict, and it must never write
  # the map. None of that needs root to prove: the verdict logic is driven from its sentinels, the
  # refusals are reached before any tracer starts, and the no-write guarantee is driven through
  # the WHOLE script in a stub world (stub fs_usage, sandbox-exec, sudo, id, and log stream).
  BOTH_SPAN="$WORK/both.sh"
  sed -n '/# READSET_BOTH_BEGIN/,/# READSET_BOTH_END/p' "$DERIVER" > "$BOTH_SPAN"
  BOTH_ARMS=$((BOTH_ARMS+1))
  if ! grep -q 'readset_both_verdict()' "$BOTH_SPAN" || ! grep -q 'readset_both_compare()' "$BOTH_SPAN"; then
    bad "extracted no readset_both_verdict/readset_both_compare from $DERIVER — the READSET_BOTH span is absent, so --tracer both cannot be driven"
  else
    ok "the READSET_BOTH span carries the comparison and the verdict"
    BW="$WORK/both"
    mkdir -p "$BW/r" || broken "mkdir failed"
    printf '*.log\n' > "$BW/r/.gitignore"
    ( cd "$BW/r" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm s ) >/dev/null 2>&1 \
      || broken "could not seed the --tracer both comparison repo"
    # fs_usage saw five paths; the sandbox saw two of them plus one fs_usage did not. Exactly ONE
    # is a sandbox miss: `.git` and `.git/HEAD` go by prefix, `build.log` by the ignore filter.
    printf '%s\n' .git .git/HEAD build.log src/a.sh src/miss.sh | LC_ALL=C sort > "$BW/fs"
    printf '%s\n' src/a.sh src/neg.sh | LC_ALL=C sort > "$BW/sb"
    both_compare_with() { # $1 span file; prints "<counts>|<sandbox-missed paths>"
      ( TREE="$BW/r"; . "$DR"; . "$1"
        fx_inproc "$DERIVER"
        c="$(readset_both_compare "$BW/fs" "$BW/sb" "$BW/cmp")" || c="rc=$?"
        printf '%s|%s' "$c" "$(tr '\n' ' ' < "$BW/cmp.sbmiss" 2>/dev/null)" )
    }
    BC="$(both_compare_with "$BOTH_SPAN")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    if [ "$BC" = "1 1|src/miss.sh " ]; then
      ok "a sandbox miss is fs_usage MINUS sandbox, outside .git/** and the ignored set: exactly src/miss.sh (1 sandbox-missed, 1 fs_usage-missed)"
    else
      bad "the comparison did not isolate exactly src/miss.sh as the one sandbox miss: got '$BC'"
    fi
    # One verdict driver; the results rows are the shape the loop writes.
    both_verdict_with() { # $1 span  $2 list  $3 results file; prints "<rc>|<line>"
      ( . "$1"; fx_inproc "$DERIVER"; l="$(readset_both_verdict "$2" "$3" "$BW/missed" "$BW")"; printf '%s|%s' "$?" "$l" )
    }
    printf 'fa\tcompared\t0\t2\t\nfb\tcompared\t0\t0\t\n' > "$BW/res.clean"
    printf 'fa\tcompared\t2\t0\t\nfb\tcompared\t1\t0\t\nfc\tcompared\t0\t0\t\n' > "$BW/res.miss"
    printf 'fa\tcompared\t0\t0\t\nfb\tuncompared\t-\t-\tsandbox set empty\n' > "$BW/res.part"
    V="$(both_verdict_with "$BOTH_SPAN" "fa fb" "$BW/res.clean")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V" in
      "0|SANDBOX-MISSES-NOTHING"*"2 of 2"*) ok "every listed fixture compared with no sandbox miss reads SANDBOX-MISSES-NOTHING, exit 0 — fs_usage-missed paths do not count against it" ;;
      *) bad "a clean comparison did not read SANDBOX-MISSES-NOTHING at exit 0: '$V'" ;;
    esac
    V="$(both_verdict_with "$BOTH_SPAN" "fa fb fc" "$BW/res.miss")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V" in
      "1|SANDBOX-MISSES 3 path(s) across 2 fixture(s)"*) ok "misses read SANDBOX-MISSES <n> path(s) across <m> fixture(s), exit 1 — summed over fixtures, counting only those that missed" ;;
      *) bad "misses did not read 'SANDBOX-MISSES 3 path(s) across 2 fixture(s)' at exit 1: '$V'" ;;
    esac
    # THE MOTIVATING CASE: three listed, one compared, one uncompared, one with no row at all.
    V="$(both_verdict_with "$BOTH_SPAN" "fa fb fc" "$BW/res.part")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V" in
      "2|REFUSED: compared 1 of 3"*"fb (sandbox set empty)"*"fc (no result row"*) ok "compared < listed REFUSES at exit 2, naming the uncompared fixture with its reason AND the one the loop never reached" ;;
      *) bad "a partial comparison was not refused at exit 2 naming fb and fc: '$V'" ;;
    esac
    V="$(both_verdict_with "$BOTH_SPAN" "" "$BW/res.clean")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V" in
      "2|REFUSED: EXAMINED NOTHING -- no fixture was listed"*) ok "an empty fixture list REFUSES at exit 2 rather than reading clean over nothing" ;;
      *) bad "an empty list was not refused at exit 2: '$V'" ;;
    esac
  fi

  # Arguments and refusals, driven through the WHOLE script in a seeded repo, as a normal user.
  # Base dies at the parse with `unknown --tracer 'both'`; the near-misses are the same refusal in
  # the other modes, which must stay at exit 1, and a fixture NAMED `both` in a --list.
  if [ "$(id -u)" = 0 ]; then
    printf '  SKIP  --tracer both refusal arms: running as root, so the not-root refusal cannot be reached\n'
  else
    BR="$WORK/bothrepo"
    mkdir -p "$BR/core/fixtures/fxa" "$BR/core/scripts" "$BR/.githooks" "$BR/src" || broken "mkdir failed"
    printf '#!/bin/bash\nFXROOT="core/fixtures/"\nfor d in "$FXROOT"*/; do :; done\n' > "$BR/.githooks/pre-push"
    # fxa echoes the width knob, which the stub-world width arm below reads from its log.
    printf '#!/bin/bash\necho "width=${VAS_INNER_POOL_WIDTH:-unset}"\necho "ems=${EMS_POOL_WIDTH:-unset}"\ncat src/a.sh >/dev/null\necho fxa ok\n' > "$BR/core/fixtures/fxa/run.sh"
    printf 'a\n' > "$BR/src/a.sh"; printf 'o\n' > "$BR/src/other.sh"
    # PRESENT names the pseudo-path arm below must keep: one whose angle pair does not span its last
    # component, and one that IS a whole `<...>` component but exists in the tree.
    mkdir -p "$BR/d" || broken "mkdir failed"
    printf 'x\n' > "$BR/a<b>c"; printf 'x\n' > "$BR/d/<real>"
    # A PRESENT file whose name leads with `-`: the option-shaped arm must keep it, as it keeps d/<real>.
    printf 'x\n' > "$BR/d/-p"
    # A DANGLING symlink with a whole `<...>` name: present by `-L`, absent by `-e`, so it is kept
    # only by a filter that tests both. Tracked, so readset_copy_tree carries it as a symlink.
    ln -s nowhere-at-all "$BR/<link>" || broken "could not seed the dangling symlink"
    printf '*.log\n' > "$BR/.gitignore"
    printf 'other\tsrc/other.sh\nother\tcore/fixtures/other/run.sh\n' > "$BR/.ai-dlc-fixture-readsets.tsv"
    cp "$DERIVER" "$BR/core/scripts/derive-fixture-readsets.sh"
    ( cd "$BR" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1 \
      || broken "could not seed the --tracer both repo"
    drive_in() { # $1 dir; rest = args. prints "<rc>|<first ERROR line>"
      local d="$1" r; shift
      ( cd "$d" && rs_drive -- core/scripts/derive-fixture-readsets.sh "$@" ) > "$WORK/br.out" 2>&1; r=$?
      printf '%s|%s' "$r" "$(grep -m1 'ERROR' "$WORK/br.out")"
    }
    V1="$(drive_in "$BR" --all --tracer both)"
    V2="$(drive_in "$BR" --all --tracer=both)"
    V3="$(drive_in "$BR" --all --tracer fs_usage)"
    V4="$(drive_in "$BR" --list both --tracer fs_usage)"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V1" in
      "2|ERROR: must run as root"*"--tracer both"*) ok "--all --tracer both PARSES and refuses a normal user at exit 2, naming the sudo command" ;;
      *) bad "--all --tracer both without root did not refuse at exit 2 for root: '$V1'" ;;
    esac
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V2|$V3|$V4" in
      "2|ERROR: must run as root"*"|1|ERROR: must run as root"*"|1|ERROR: must run as root"*) ok "  --tracer=both refuses at 2 too, and the same refusal stays at exit 1 in fs_usage mode — including for a fixture NAMED 'both'" ;;
      *) bad "the refusal exit codes do not separate both-mode from the others: '=both' $V2 / fs_usage $V3 / --list both $V4" ;;
    esac
    # A REPEATED --tracer: the parser keeps the LAST value, so the refusal code must follow the
    # last one too. Both orders, so a pre-scan that latches on any `both` and one that ignores
    # `both` entirely each fail one half.
    V5="$(drive_in "$BR" --all --tracer both --tracer fs_usage)"
    V6="$(drive_in "$BR" --all --tracer fs_usage --tracer both)"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V5|$V6" in
      "1|ERROR: must run as root"*"--tracer fs_usage"*"|2|ERROR: must run as root"*"--tracer both"*) ok "  a repeated --tracer refuses at the LAST value's code: 'both then fs_usage' at 1, 'fs_usage then both' at 2" ;;
      *) bad "a repeated --tracer did not refuse at the last value's exit code: both,fs_usage $V5 / fs_usage,both $V6" ;;
    esac
    # A LINKED WORKTREE dies at the gate just after the parse, before any tracer check, so its exit
    # code is the raw pre-scan's: 2 under both, still 1 otherwise.
    ( cd "$BR" && git worktree add -q "$WORK/bothwt" -b bothwt ) >/dev/null 2>&1 || broken "could not add a linked worktree to the --tracer both repo"
    W1="$(drive_in "$WORK/bothwt" --all --tracer both)"
    W2="$(drive_in "$WORK/bothwt" --all --tracer fs_usage)"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$W1|$W2" in
      "2|ERROR:"*"LINKED worktree"*"|1|ERROR:"*"LINKED worktree"*) ok "a LINKED worktree refuses --tracer both at exit 2 before any parse, and the same refusal stays at 1 in fs_usage mode" ;;
      *) bad "a linked worktree did not refuse at 2 under both / 1 otherwise: both $W1 / fs_usage $W2" ;;
    esac

    # THE NO-WRITE GUARANTEE, DRIVEN THROUGH THE WHOLE SCRIPT. Stubs stand in for every privileged
    # or kernel-backed tool; `/usr/bin/log` is called by absolute path and cannot be PATH-stubbed,
    # so a COPY of the deriver has its one LOG_BIN line pointed at a stub. The stub fs_usage sees
    # five paths and the stub sandbox two, so the real loop must report exactly 1 sandbox miss.
    # The seeded map carries a SECOND fixture's rows so that, with the guard deleted, the script
    # passes every control and reaches the write -- the md5 arm is then about the guard, not about
    # a control that happened to stop the run first.
    SB="$WORK/bothstub"; mkdir -p "$SB" || broken "mkdir failed"
    BOTH_TR="$(cd "$WORK" && pwd -P)/both.tr"
    cat > "$SB/id" <<'STUB'
#!/bin/bash
[ "$#" -eq 1 ] && [ "$1" = -u ] && { echo 0; exit 0; }
exec /usr/bin/id "$@"
STUB
    # The stub sudo models env_reset for the one variable that matters here: a VAS_INNER_POOL_WIDTH
    # exported or prefixed in FRONT of sudo does not reach the command it runs.
    cat > "$SB/sudo" <<'STUB'
#!/bin/bash
while [ "$#" -gt 0 ]; do case "$1" in -n) shift ;; -u) shift 2 ;; *) break ;; esac; done
exec env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH "$@"
STUB
    cat > "$SB/sandbox-exec" <<'STUB'
#!/bin/bash
. "$STUB_STREAM_LIB"
# STUB_PROFILES, when set, collects the CONTENT of every profile handed to `-f` (the profile-override arm reads it).
[ "$1" = -f ] && { [ -z "${STUB_PROFILES:-}" ] || cat "$2" >> "$STUB_PROFILES"; shift 2; }
# The deriver launches a fixture as `env VAS_INNER_POOL_WIDTH=1 bash <run.sh>`; look past that.
_c=1; [ "$1" = env ] && { _c=2; for _w in "${@:2}"; do case "$_w" in *=*) _c=$((_c+1)) ;; *) break ;; esac; done; }
if [ "${!_c}" = bash ]; then
  # A list line `M <path>` reports a lone file-read-metadata, the shape of a lookup whose existence report was lost.
  while IFS= read -r p; do
    case "$p" in
      '') ;;
      'M '*) ss_emit "x Sandbox: bash(1) allow file-read-metadata $PWD/${p#M }" ;;
      *) ss_emit "x Sandbox: bash(1) allow file-read-data $PWD/$p" ;;
    esac
  done < "$STUB_SB"
else
  for a in "$@"; do case "$a" in /*) ss_wait "$a"; ss_emit "x Sandbox: cat(1) allow file-read-data $a" ;; esac; done
fi
exec "$@"
STUB
    cat > "$SB/fs_usage" <<'STUB'
#!/bin/bash
echo $$ >> "${0%/*}/pids"   # the world reaps this pid by number (stub_reap); exec keeps it
# Exits on its own once nobody reads it: `git push` runs hooks with SIGPIPE ignored, and the
# deriver kills grep (the pipeline's last element), not this.
emit() { printf '%s\n' "$1" || exit 0; }
emit "00:00:00  open  F=3  (R_____)  $STUB_ROOT/m/.readset-sentinel  0.000010  cat.1"
while IFS= read -r p; do [ -n "$p" ] && emit "00:00:00  open  F=3  (R_____)  $STUB_ROOT/t/$p  0.000010  bash.2"; done < "$STUB_FS"
# The last line it will ever report, under the marker dir so the capture keeps it and no set does: stubflush waits on it.
emit "00:00:00  open  F=3  (R_____)  $STUB_ROOT/m/.stub-fs-done  0.000010  cat.1"
# NO BOUND (BL-868): the heartbeat runs until its reader goes, and `emit`'s `|| exit 0` (or SIGPIPE) ends it then;
# stub_reap kills it by pid either way. A 300-beat cap ended the stream on its own after 60s, so a deriver slowed past
# that by load read a tracer gone early -- the stub's lifetime followed the clock instead of its reader.
while :; do sleep 0.2; emit heartbeat; done
STUB
    # THE INJECTED WAIT (the deriver's rs_sleep, READSET_SLEEP_CMD). The deriver's fixed `sleep 1` before it kills
    # fs_usage stands for "the tracer's last events have reached the capture". This stub's last event is its
    # .stub-fs-done line, so the wait ends when the capture holds it: an event, not a clock. It has no bound (BL-868): a capture that never holds the line
    # hangs until the gate's watchdog, never a verdict.
    cat > "$SB/stubflush" <<'STUB'
#!/bin/bash
until grep -q '/m/\.stub-fs-done ' "$STUB_ROOT"/w/*.raw.fsu 2>/dev/null; do
  /bin/sleep 0.01
done
STUB
    chmod +x "$SB/stubflush"
    # The stream stub registers its capture (the STUB_STREAM span) and blocks until the deriver stops it.
    cat > "$SB/logstream" <<'STUB'
#!/bin/bash
echo $$ >> "${0%/*}/pids"   # the world reaps this pid by number (stub_reap); exec keeps it
. "$STUB_STREAM_LIB"
ss_register live
exec tail -f /dev/null
STUB
    chmod +x "$SB/id" "$SB/sudo" "$SB/sandbox-exec" "$SB/fs_usage" "$SB/logstream"
    : > "$SB/feed"
    # The eleven PSEUDO seeds go into BOTH lists, so they cancel in the miss count and every tracer's
    # set carries them to the one call site where the sets meet (the pseudo-path arm below).
    PSEUDO_SEEDS='<string>
sub/<unknown>
src/missing.sh
a<b>c
d/<real>
e<f>g.sh
<link>
x/y/<z>
<>
q/-x
d/-p'
    { printf '%s\n' core/fixtures/fxa/run.sh src/a.sh src/miss.sh .git/HEAD build.log; printf '%s\n' "$PSEUDO_SEEDS"; } > "$SB/fs.list"
    { printf '%s\n' core/fixtures/fxa/run.sh src/a.sh; printf '%s\n' "$PSEUDO_SEEDS"; } > "$SB/sb.list"
    : > "$SB/empty.list"
    STUB_DERIVER="$BR/core/scripts/derive-fixture-readsets.sh"
    sed "s|^LOG_BIN=/usr/bin/log\$|LOG_BIN=\"$SB/logstream\"|" "$DERIVER" > "$SB/deriver.sh"
    cmp -s "$DERIVER" "$SB/deriver.sh" && broken "the LOG_BIN line is gone from $DERIVER, so the stub world cannot point the stream at a stub"
    sum_of() { md5 -q "$1" 2>/dev/null || cksum < "$1"; }
    stub_run() { # $1 deriver copy  $2 sandbox path list; prints "<rc>|<verdict line>|<fxa line>|<map moved?>"
      local before after r
      cp "$1" "$STUB_DERIVER"
      before="$(sum_of "$BR/.ai-dlc-fixture-readsets.tsv")"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SB:$PATH" SUDO_USER="$(id -un)" STUB_ROOT="$BOTH_TR" STUB_FEED="$SB/feed" \
          STUB_FS="$SB/fs.list" STUB_SB="$2" READSET_SLEEP_CMD=stubflush AI_DLC_READSET_TRACE_ROOT="$BOTH_TR" \
          -- core/scripts/derive-fixture-readsets.sh --list fxa --tracer both ) > "$WORK/stub.out" 2>&1 </dev/null
      r=$?
      stub_reap "${SB:-}"
      after="$(sum_of "$BR/.ai-dlc-fixture-readsets.tsv")"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s|%s|%s' "$r" "$(grep -m1 -E '^(SANDBOX-MISSES|REFUSED)' "$WORK/stub.out")" \
        "$(grep -m1 -E '^  fxa ' "$WORK/stub.out" | tr -s ' ')" "$([ "$before" = "$after" ] && echo same || echo MOVED)"
    }
    S1="$(stub_run "$SB/deriver.sh" "$SB/sb.list")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$S1" in
      "1|SANDBOX-MISSES 1 path(s) across 1 fixture(s)"*"| fxa sandbox-missed 1 fs_usage-missed 0|same")
        ok "a full stub-world --tracer both run reports 'fxa sandbox-missed 1 fs_usage-missed 0', reads SANDBOX-MISSES at exit 1, and leaves the map's md5 unchanged" ;;
      *) bad "the stub-world --tracer both run did not read exactly one miss with the map unchanged: '$S1' — $(tail -3 "$WORK/stub.out" | tr '\n' ' ')" ;;
    esac
    # S1's own fxa log, captured NOW: later drives re-run the stub world, and the
    # width arm further down must read S1's run, not a later one.
    S1_LOG="$WORK/s1.fxa.log"; cp "$BOTH_TR/w/fxa.log" "$S1_LOG" 2>/dev/null || : > "$S1_LOG"
    # THE PSEUDO-PATH FILTER, read off the set the S1 run just wrote, where all three tracers' sets
    # meet. Nine seeds, in seed order: `<string>` and `sub/<unknown>` (absent, last component a whole
    # `<...>` token) must be DROPPED; `src/missing.sh` (absent, ordinary), `a<b>c` and `d/<real>`
    # (present), `e<f>g.sh` (absent, brackets inside the component) and `<link>` (a dangling
    # symlink) must be KEPT; `x/y/<z>` (absent, two directories deep) and `<>` (absent, empty
    # token) must be DROPPED. Each of the last four separates the fix from one wrong filter:
    # `e<f>g.sh` from an unanchored `<[^/]*>`, `<link>` from `-e` without `-L`, `x/y/<z>` from a
    # first-component strip `${p#*/}`, and `<>` from a non-empty token `'<'?*'>'`. Then the
    # option-shaped pair: `q/-x` (absent, last component leads with `-`, the shape of a grep option
    # read as an operand) must be DROPPED, and `d/-p` (present, same shape) must be KEPT.
    # Presence-shaped: six rows must APPEAR, so a run that wrote no set cannot score.
    pseudo_sig() { # prints one 0/1 per seed: is it in the last stub run's fxa.set
      local s out=""
      while IFS= read -r s; do
        if grep -qxF -- "$s" "$BOTH_TR/w/fxa.set" 2>/dev/null; then out="${out}1"; else out="${out}0"; fi
      done <<< "$PSEUDO_SEEDS"
      printf '%s' "$out"
    }
    PS0="$(pseudo_sig)"
    BOTH_ARMS=$((BOTH_ARMS+1))
    if [ "$PS0" = 00111110001 ]; then
      ok "PSEUDO: the merged set drops '<string>' and 'sub/<unknown>' (absent whole-<...> last component) and keeps src/missing.sh, a<b>c, d/<real>, e<f>g.sh and the dangling <link>; x/y/<z> and <> go too; absent option-shaped q/-x goes and present d/-p stays"
    else
      bad "PSEUDO: expected seed signature 00111110001 in fxa.set, got '$PS0' (order: <string> sub/<unknown> src/missing.sh a<b>c d/<real> e<f>g.sh <link> x/y/<z> <> q/-x d/-p) — $(tail -2 "$WORK/stub.out" | tr '\n' ' ')"
    fi
    # THE WIDTH KNOB UNDER `--tracer both`. This path runs the fixture through `sudo -n -u ...
    # sandbox-exec`, and the stub sudo strips VAS_INNER_POOL_WIDTH the way env_reset does, so only an
    # `env KNOB=1` placed AFTER sudo reaches the fixture. The log is read straight after each run,
    # before the next run clears the trace root. Presence-shaped: `fxa ok` must appear too.
    # EMS_POOL_WIDTH rides the same `env` and is read the same way, as a second field.
    stub_width() { # prints "<width line>|<ems line>|<fxa ok count>" from $1, default the last stub run's fxa log
      local l="${1:-$BOTH_TR/w/fxa.log}"
      printf '%s|%s|%s' "$(grep -m1 '^width=' "$l" 2>/dev/null)" "$(grep -m1 '^ems=' "$l" 2>/dev/null)" \
        "$(grep -cx 'fxa ok' "$l" 2>/dev/null || :)"
    }
    SW0="$(stub_width "$S1_LOG")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$SW0" in
      "width=1|ems=1|1") ok "WIDTH under --tracer both: the stub-world run of fxa, launched through sudo's env_reset, logs width=1 and ems=1" ;;
      *) bad "WIDTH under --tracer both: fxa's log did not read width=1 and ems=1 with 'fxa ok' present: '$SW0' — a knob does not survive the sudo launch" ;;
    esac
    S2="$(stub_run "$SB/deriver.sh" "$SB/empty.list")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$S2" in
      "2|REFUSED: compared 0 of 1"*"fxa ("*"sandbox set empty)"*"|same") ok "  and a sandbox that reported nothing for the fixture — how an unseen sudo -u child would look — is REFUSED at exit 2, not compared" ;;
      *) bad "an empty sandbox set was not refused at exit 2 naming fxa: '$S2'" ;;
    esac
    # THE LOSS CANARY UNDER `--tracer both`. The same empty-stream run: fxa really read run.sh and
    # src/a.sh, the stream reported neither, so its reason must also carry `LOSS CANARY: 2 path(s)`
    # -- a read both tracers lost would otherwise be invisible to the fs_usage comparison.
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$S2" in
      *"fxa (LOSS CANARY: 2 path(s)"*) ok "CANARY under --tracer both: the empty-stream run's UNCOMPARED reason names 'LOSS CANARY: 2 path(s)'" ;;
      *) bad "CANARY under --tracer both: the empty-stream run's reason does not name 'LOSS CANARY: 2 path(s)': '$S2'" ;;
    esac

    # THE LOSS CANARY, DETERMINISTICALLY, UNDER `--tracer sandbox`. This arm needs no real `log stream`,
    # so the canary is proven on every non-root run of this fixture and is never a check that cannot
    # fire. LIMIT: the real-kernel loss shape is assumed, not tested -- that an overloaded real stream
    # loses reads as a drop notice or an atime-only path is what this arm and the drop arms model. The
    # stub sandbox-exec reports ONLY the paths in the list it is handed, while fxa really reads
    # run.sh and src/a.sh, so the atime leg sees both:
    #   lossy list  run.sh alone, plus a lone metadata report on src/other.sh
    #                                 -> fxa OMITTED naming `LOSS CANARY: 1 path(s)` and `STAT LOSS: 1`, 0 drop notices;
    #   whole list  run.sh + src/a.sh -> fxa MAPPED.
    # Its own PATH dir carries ONLY the sandbox-exec stub: the `id` stub above answers uid 0, which
    # `--tracer sandbox` refuses.
    SX="$WORK/sbxstub"; mkdir -p "$SX" || broken "mkdir failed"
    cp "$SB/sandbox-exec" "$SX/sandbox-exec" || broken "could not copy the sandbox-exec stub"
    printf '%s\n' core/fixtures/fxa/run.sh 'M src/other.sh' > "$SX/lossy.list"
    printf '%s\n' core/fixtures/fxa/run.sh src/a.sh > "$SX/whole.list"
    : > "$SX/feed"
    SX_TR="$(cd "$WORK" && pwd -P)/sbx.tr"
    sbx_run() { # $1 deriver copy  $2 stream list; prints "<fxa line>|<drop notices>"
      local d
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$2" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" -- core/scripts/derive-fixture-readsets.sh --list fxa --tracer sandbox ) > "$WORK/sbx.o" 2> "$WORK/sbx.e" </dev/null
      echo "$?" > "$WORK/sbx.rc"
      cat "$WORK/sbx.o" "$WORK/sbx.e" > "$WORK/sbx.out"
      stub_reap "${SB:-}"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      d="$(grep -c 'dropped during' "$SX_TR/w/fxa.win" 2>/dev/null)" || d=0
      printf '%s|%s' "$(grep -m1 -E '^  fxa ' "$WORK/sbx.out" | tr -s ' ')" "$d"
    }
    CL="$(sbx_run "$SB/deriver.sh" "$SX/lossy.list")"
    cp "$WORK/sbx.o" "$WORK/eq.l.in"; cp "$WORK/sbx.e" "$WORK/eq.l.in.err"; cp "$WORK/sbx.rc" "$WORK/eq.l.in.rc"; cp "$SX_TR/w/fxa.set" "$WORK/eq.l.in.set" 2>/dev/null || : > "$WORK/eq.l.in.set"
    CW="$(sbx_run "$SB/deriver.sh" "$SX/whole.list")"
    cp "$SX_TR/w/fxa.log" "$WORK/width.log" 2>/dev/null || : > "$WORK/width.log"
    cp "$WORK/sbx.o" "$WORK/eq.w.in"; cp "$WORK/sbx.e" "$WORK/eq.w.in.err"; cp "$WORK/sbx.rc" "$WORK/eq.w.in.rc"; cp "$SX_TR/w/fxa.set" "$WORK/eq.w.in.set" 2>/dev/null || : > "$WORK/eq.w.in.set"
    # THE EQUIVALENCE CELL, and the tracer unit's end-to-end runs (one per distinct outcome: fxa OMITTED, fxa
    # MAPPED). The same two worlds driven through the CLI as a PROCESS must print the same output (the `[hh:mm:ss]`
    # stamps of say() masked), write the same set and leave the same rc as the in-process drive above. The two
    # worlds' answers differ (control), so an in-process path that answered both alike could not pass.
    # Each CLI run is the `cli` cell eq-<tag> of readset-skip-c/cells.decl (BL-879), started as FXCELL=eq-<tag>.
    # stdout, stderr and exit are compared separately; stdout with the say() stamps masked, since the clock moves
    # between the two runs, and stderr and exit byte for byte.
    eq_cli() { # <stream list> <tag>
      cp "$SB/deriver.sh" "$STUB_DERIVER"
      ( cd "$BR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$1" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" FXCELL="eq-$2" bash core/scripts/derive-fixture-readsets.sh --list fxa --tracer sandbox ) > "$WORK/eq.$2.cli" 2> "$WORK/eq.$2.cli.err" </dev/null
      echo "$?" > "$WORK/eq.$2.cli.rc"
      stub_reap "${SB:-}"
      cp "$SX_TR/w/fxa.set" "$WORK/eq.$2.cli.set" 2>/dev/null || : > "$WORK/eq.$2.cli.set"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
    }
    eq_mask() { sed 's/^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\] /[--:--:--] /' "$1"; }
    eq_cli "$SX/lossy.list" l; eq_cli "$SX/whole.list" w
    TRACE_ARMS=$((TRACE_ARMS+1))
    _eqd=""
    for _t in l w; do
      [ "$(eq_mask "$WORK/eq.$_t.in")" = "$(eq_mask "$WORK/eq.$_t.cli")" ] || _eqd="$_eqd $_t:stdout"
      cmp -s "$WORK/eq.$_t.in.err" "$WORK/eq.$_t.cli.err" || _eqd="$_eqd $_t:stderr"
      cmp -s "$WORK/eq.$_t.in.set" "$WORK/eq.$_t.cli.set" || _eqd="$_eqd $_t:set"
      cmp -s "$WORK/eq.$_t.in.rc" "$WORK/eq.$_t.cli.rc" || _eqd="$_eqd $_t:rc=$(cat "$WORK/eq.$_t.in.rc")/$(cat "$WORK/eq.$_t.cli.rc")"
    done
    if [ -z "$_eqd" ] && [ "$(eq_mask "$WORK/eq.l.cli")" != "$(eq_mask "$WORK/eq.w.cli")" ] && grep -q '^  fxa .* OMITTED' "$WORK/eq.l.cli" && grep -q '^  fxa .* paths$' "$WORK/eq.w.cli"; then
      ok "EQUIVALENCE: the in-process deriver and the CLI print the same output, write the same set and exit alike (lossy $(cat "$WORK/eq.l.cli.rc"), whole $(cat "$WORK/eq.w.cli.rc")) on the lossy world (fxa OMITTED) and the whole world (fxa MAPPED), two distinct answers"
    else
      bad "EQUIVALENCE: the in-process deriver and the CLI differ:${_eqd:- the two worlds read alike} — $(diff <(eq_mask "$WORK/eq.l.in") <(eq_mask "$WORK/eq.l.cli") | head -4 | tr '\n' ' ')"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    case "$CL" in
      " fxa OMITTED ("*"LOSS CANARY: 1 path(s)"*"|0") ok "CANARY: a sandbox-tracer window that lost a read with NO drop notice OMITS the fixture, naming 'LOSS CANARY: 1 path(s)'" ;;
      *) bad "CANARY: the lossy stub window was not omitted naming 'LOSS CANARY: 1 path(s)' with 0 drop notices: '$CL' — $(tail -2 "$WORK/sbx.out" | tr '\n' ' ')" ;;
    esac
    # THE STAT-PAIRING GUARD'S WIRING, end to end on the same run: the lossy window's lone metadata report on
    # src/other.sh must reach rs_fx_judge's call site and come out as the run's own STAT LOSS reason. The
    # whole run below, with no metadata report, is its twin.
    TRACE_ARMS=$((TRACE_ARMS+1))
    case "$CL" in
      " fxa OMITTED ("*"STAT LOSS: 1 metadata report(s)"*"|0") ok "STAT LOSS END TO END: the deriver run on a window with one lone metadata report omits fxa naming 'STAT LOSS: 1 metadata report(s)'" ;;
      *) bad "STAT LOSS END TO END: the lossy stub window's lone metadata report did not reach the run's omission reason: '$CL' — $(tail -2 "$WORK/sbx.out" | tr '\n' ' ')" ;;
    esac
    TRACE_ARMS=$((TRACE_ARMS+1))
    case "$CW" in
      " fxa "*" paths|0") ok "CANARY CONTROL: the same run with the stream reporting every read MAPS fxa — the canary does not fire on a whole window" ;;
      *) bad "CANARY CONTROL: the whole stub window did not map fxa: '$CW' — atime extras: $(LC_ALL=C comm -23 "$SX_TR/w/fxa.at" "$SX_TR/w/fxa.fs" 2>/dev/null | tr '\n' ' ')" ;;
    esac

    # ------------------------------ the deriver runs a traced fixture at inner pool width 1 ----
    # BL-375: validator-arm-selection's 6-way inner pool outruns `log stream` and its trace drops
    # reports, so the deriver launches every fixture as `... env VAS_INNER_POOL_WIDTH=1 bash`. This arm
    # binds the `sandboxed` line under `--tracer sandbox`, in the stub world: fxa echoes both knobs, and
    # the log the deriver captured for the CANARY CONTROL run above must read `width=1` and `ems=1`. The
    # same line under `--tracer both` goes through sudo and is bound by the --tracer both width arm. The
    # `fs_usage` line runs only as root and stays covered only by the operator's own `sudo` run. Two
    # controls, each presence-shaped (`fxa ok` must appear, so a run that never reached fxa cannot score):
    #   * fxa run OUTSIDE the deriver reads `width=unset`, so the 1 came from the deriver;
    #   * a deriver copy with the injection removed from the launch line yields `width=unset`.
    TRACE_ARMS=$((TRACE_ARMS+1))
    if grep -qx 'fxa ok' "$WORK/width.log" && grep -qx 'width=1' "$WORK/width.log" && grep -qx 'ems=1' "$WORK/width.log"; then
      ok "WIDTH: the deriver ran the traced fxa with VAS_INNER_POOL_WIDTH=1 and EMS_POOL_WIDTH=1 (its captured log reads width=1, ems=1)"
    else
      bad "WIDTH: the deriver's traced run of fxa did not see VAS_INNER_POOL_WIDTH=1 and EMS_POOL_WIDTH=1 with 'fxa ok' present: '$(tr '\n' ' ' < "$WORK/width.log" | cut -c1-120)'. validator-arm-selection would trace at full width and drop reports"
    fi
    W_OUT="$( cd "$BR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH bash core/fixtures/fxa/run.sh 2>/dev/null )"
    TRACE_ARMS=$((TRACE_ARMS+1))
    case "$W_OUT" in
      *"width=unset"*"ems=unset"*"fxa ok"*) ok "WIDTH CONTROL: fxa run outside the deriver reads width=unset and ems=unset, so the 1 above is the deriver's" ;;
      *) bad "WIDTH CONTROL: fxa run outside the deriver did not read width=unset and ems=unset: '$(printf '%s' "$W_OUT" | tr '\n' ' ')'" ;;
    esac

    # ----------------------- the deriver loads AI_DLC_READSET_SANDBOX_PROFILE when it is set ----
    # The override replaces the deriver's own profile: its @TREE@ is substituted with the trace tree and
    # the result is what every `sandboxed` call hands to `-f`. The stub sandbox-exec appends the CONTENT
    # of each profile it is handed to STUB_PROFILES, so the arm reads what `sandboxed` used, not what the
    # deriver wrote. Presence-shaped both ways: with the override every profile carries its token line with
    # @TREE@ substituted and none carries the default rule; the TWIN, the same run without the override,
    # carries the default rule and no token. fxa must map in both, so a run that never traced cannot score.
    printf '(version 3)\n; readset-skip-profile-token @TREE@\n(allow default)\n' > "$SX/override.sb"
    pf_run() { # [override profile]; prints "<profiles with the token>|<token lines with @TREE@ substituted>|<default-rule lines>|<fxa line>"
      local p="$WORK/pf.profiles" t s d
      : > "$p"
      cp "$SB/deriver.sh" "$STUB_DERIVER"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$SX/whole.list" \
          STUB_PROFILES="$p" ${1:+AI_DLC_READSET_SANDBOX_PROFILE="$1"} AI_DLC_READSET_TRACE_ROOT="$SX_TR" \
          -- core/scripts/derive-fixture-readsets.sh --list fxa --tracer sandbox ) > "$WORK/pf.out" 2>&1 </dev/null
      stub_reap "${SB:-}"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      t="$(grep -c 'readset-skip-profile-token' "$p")" || t=0
      s="$(grep -cxF "; readset-skip-profile-token $SX_TR/t" "$p")" || s=0
      d="$(grep -cF '(allow file* process-exec* (subpath' "$p")" || d=0
      printf '%s|%s|%s|%s' "$t" "$s" "$d" "$(grep -m1 -E '^  fxa ' "$WORK/pf.out" | tr -s ' ')"
    }
    PF_O="$(pf_run "$SX/override.sb")"; PF_T="$(pf_run "")"
    TRACE_ARMS=$((TRACE_ARMS+1))
    _pt="${PF_O%%|*}"; _pr="${PF_O#*|}"; _ps="${_pr%%|*}"; _pr="${_pr#*|}"; _pd="${_pr%%|*}"
    if [ "$_pt" -gt 0 ] && [ "$_ps" = "$_pt" ] && [ "$_pd" = 0 ] && case "$PF_O" in *" fxa "*" paths") true ;; *) false ;; esac; then
      ok "PROFILE: with AI_DLC_READSET_SANDBOX_PROFILE set, all $_pt profile(s) sandbox-exec was handed carry the override's token with @TREE@ substituted, and none the default rule"
    else
      bad "PROFILE: the override was not what sandbox-exec ran under: token|substituted|default|fxa = '$PF_O'"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    case "$PF_T" in
      0\|0\|[1-9]*" fxa "*" paths") ok "PROFILE TWIN: the same run without the override hands sandbox-exec the deriver's default rule and no token" ;;
      *) bad "PROFILE TWIN: without the override expected no token and the default rule with fxa mapped: '$PF_T'" ;;
    esac

    # THE CANARY'S UNREADABLE BRANCH, driven from its sentinels. No real trace produces an
    # unreadable stream set on demand, so the shipped readset_loss_canary is called on a missing
    # $fx.fs: it must print `unreadable`, and the deriver's guard must turn that into an OMITTED
    # reason. Two wrong builds each fail this arm and only this arm:
    #   C1  `unreadable` replaced by `0`, the fail-open direction;
    #   C2  comm's status discarded (`; then` -> `|| :; then`), so the empty output counts 0.
    CAN_SPAN="$WORK/canary.sh"
    sed -n '/^# READSET_CANARY_BEGIN$/,/^# READSET_CANARY_END$/p' "$DERIVER" > "$CAN_SPAN"
    printf 'a\nb\n' > "$WORK/can.at"
    can_with() { ( . "$1"; fx_inproc "$DERIVER"; readset_loss_canary "$WORK/can.at" "$WORK/can.no-such-fs" "$WORK/can.out" ) 2>/dev/null; }
    can_why() { # $1 canary value; runs the deriver's own guard line on it
      local canary="$1" why="" fx=fxa WORK="$WORK" g
      g="$(grep -m1 '^  \[ "\$canary" = 0 \]    || why=' "$DERIVER")"
      eval "$g"; printf '%s' "$why"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    CU="$(can_with "$CAN_SPAN")"; CUW="$(can_why "$CU")"
    if [ "$CU" = unreadable ] && case "$CUW" in "LOSS CANARY: unreadable path(s)"*) true ;; *) false ;; esac; then
      ok "CANARY UNREADABLE: a missing stream set makes readset_loss_canary print 'unreadable', and the deriver's guard omits the fixture for it"
    else
      bad "CANARY UNREADABLE: expected 'unreadable' and an omission reason, got '$CU' / '$CUW' (span lines: $(grep -c . "$CAN_SPAN"))"
    fi

    # THE STAT-PAIRING GUARD, driven from its sentinels on seeded windows in the kernel's own line shape.
    # The offender window holds two unpaired metadata reports, neither first: one lone, and one whose
    # existence report came from a DIFFERENT pid (the rule is per process). Its near-misses: a paired
    # lookup, an existence-only lookup, and an unpaired metadata report outside the tree. The twin adds
    # the two missing existence reports and must count 0; a missing window must read `unreadable`; and
    # the deriver's own guard line must omit on the count and on `unreadable` and stay quiet on 0.
    SP_SPAN="$WORK/statpair.sh"; SP_T="$WORK/sp.tree"
    sed -n '/^# READSET_STATPAIR_BEGIN$/,/^# READSET_STATPAIR_END$/p' "$DERIVER" > "$SP_SPAN"
    sp_line() { printf '2026-11-13 22:46:22.%s Df kernel[0:db9%s] [com.apple.sandbox.reporting:violation] Sandbox: %s allow %s %s\n' "$1" "$1" "$2" "$3" "$4"; }
    { sp_line 101 'cat(9)' file-test-existence "$WORK/sp.mark/.readset-sentinel"
      sp_line 102 'bash(10)' file-test-existence "$SP_T/src/a.sh"
      sp_line 103 'bash(10)' file-read-metadata "$SP_T/src/a.sh"
      sp_line 104 'bash(10)' file-test-existence "$SP_T/src/absent"
      sp_line 105 'git(20)' file-test-existence "$SP_T/core/x"
      sp_line 106 'git(21)' file-read-metadata "$SP_T/core/x"
      sp_line 107 'git(22)' file-read-metadata "$SP_T/src/b.sh"
      sp_line 108 'git(23)' file-read-metadata "$WORK/elsewhere/c.sh"
    } > "$WORK/sp.win"
    { cat "$WORK/sp.win"
      sp_line 109 'git(21)' file-test-existence "$SP_T/core/x"
      sp_line 110 'git(22)' file-test-existence "$SP_T/src/b.sh"
    } > "$WORK/sp.twin"
    sp_with() { # each call is one in-process pass of the deriver's span, logged by fx_inproc
      fx_inproc "$DERIVER"
      ( . "$SP_SPAN"; readset_stat_pairing "$1" "$SP_T" "$2" ) 2>/dev/null
    }
    sp_why() { # $1 statpair value; runs the deriver's own guard line on it
      local statpair="$1" why="" fx=fxa WORK="$WORK" g
      g="$(grep -m1 '^  \[ "\$statpair" = 0 \]  || why=' "$DERIVER")"
      eval "$g"; printf '%s' "$why"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    SPO="$(sp_with "$WORK/sp.win" "$WORK/sp.win.rows")"; SPW="$(sp_why "$SPO")"
    SPR="$(cat "$WORK/sp.win.rows" 2>/dev/null)"
    if [ "$SPO" = 2 ] && [ "$SPR" = "$(printf 'git(21)\tcore/x\ngit(22)\tsrc/b.sh')" ] \
      && case "$SPW" in "STAT LOSS: 2 metadata report(s)"*) true ;; *) false ;; esac; then
      ok "STAT PAIRING: a lone metadata report and one paired only in another pid count 2, named exactly, and the deriver's guard omits the fixture for them"
    else
      bad "STAT PAIRING: expected 2 rows git(21) core/x, git(22) src/b.sh and a STAT LOSS reason, got '$SPO' / '$SPR' / '$SPW' (span lines: $(grep -c . "$SP_SPAN"))"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    SPT="$(sp_with "$WORK/sp.twin" "$WORK/sp.twin.rows")"; SPTW="$(sp_why "$SPT")"
    SPU="$(sp_with "$WORK/sp.no-such-win" "$WORK/sp.u.rows")"; SPUW="$(sp_why "$SPU")"
    if [ "$SPT" = 0 ] && [ -z "$SPTW" ] && [ "$SPU" = unreadable ] \
      && case "$SPUW" in "STAT LOSS: unreadable"*) true ;; *) false ;; esac; then
      ok "STAT PAIRING TWIN: the same window with both existence reports added counts 0 and is not omitted; a missing window reads 'unreadable' and is"
    else
      bad "STAT PAIRING TWIN: expected 0 with no reason, then 'unreadable' with a reason, got '$SPT' / '$SPTW' / '$SPU' / '$SPUW'"
    fi
    # THE TRUST ROOT (READSET_STATPAIR_ALLOW), one window. Only Python(30) holds every property of the
    # allowlisted row (program Python, path core, its first report under the tree is that metadata
    # report) and is not counted. Each other row is a near-miss for one clause of the rule:
    #   bash(31) core          program equality (another program)
    #   Python3(36) core       program equality, not prefix (Python3 extends Python)
    #   Python(32) pkg         path equality (another path)
    #   Python(35) core/scripts path equality, not prefix (a real directory under core)
    #   Python(33) core        first-report KEY: its first report is a metadata report, of pkg/mod.py
    #                          (seeded before its existence half; pairing ignores order)
    #   Python(34) core        first-report OP: its first report is of core, but file-read-data
    # The acquitted row is not seeded first.
    mkdir -p "$SP_T/core/scripts" || broken "could not seed the trust-root tree"
    { sp_line 121 'bash(31)' file-read-metadata "$SP_T/core"
      sp_line 120 'Python(35)' file-read-metadata "$SP_T/core/scripts"
      sp_line 123 'Python(33)' file-read-metadata "$SP_T/pkg/mod.py"
      sp_line 122 'Python(33)' file-test-existence "$SP_T/pkg/mod.py"
      sp_line 128 'Python(34)' file-read-data "$SP_T/core"
      sp_line 124 'Python(30)' file-read-metadata "$SP_T/core"
      sp_line 125 'Python(32)' file-read-metadata "$SP_T/pkg"
      sp_line 126 'Python(33)' file-read-metadata "$SP_T/core"
      sp_line 129 'Python(34)' file-read-metadata "$SP_T/core"
      sp_line 127 'Python3(36)' file-read-metadata "$SP_T/core"
    } > "$WORK/sp.awin"
    TRACE_ARMS=$((TRACE_ARMS+1))
    SPA="$(sp_with "$WORK/sp.awin" "$WORK/sp.awin.rows")"; SPAR="$(cat "$WORK/sp.awin.rows" 2>/dev/null)"
    if [ "$SPA" = 6 ] && [ "$SPAR" = "$(printf 'Python(32)\tpkg\nPython(33)\tcore\nPython(34)\tcore\nPython(35)\tcore/scripts\nPython3(36)\tcore\nbash(31)\tcore')" ]; then
      ok "STAT PAIRING TRUST ROOT: a first metadata-only report of core by Python is not counted; the same report by bash or Python3, of another path, of a directory under core, after a metadata report of another path, or after another op on core counts 6, named exactly"
    else
      bad "STAT PAIRING TRUST ROOT: expected 6 rows Python(32) pkg, Python(33) core, Python(34) core, Python(35) core/scripts, Python3(36) core, bash(31) core, got '$SPA' / '$SPAR'"
    fi

    # A ONE-FIXTURE `--list` WHOSE FIXTURE IS OMITTED STILL WRITES THE MAP, DROPPING ITS STALE ROWS.
    # Seed a stale `fxa` row the trace can never produce, trace fxa with a lossy stream (the canary
    # omits it), and read the map: the stale row must be GONE, `other`'s rows kept, the map must carry
    # NO `# OMITTED` line (a line recording one run's omissions rewrote the tracked map whenever the
    # omitted set changed), and the run's stdout must name fxa as OMITTED.
    printf 'other\tsrc/other.sh\nother\tcore/fixtures/other/run.sh\nthird\tcore/fixtures/third/run.sh\nfxa\tsrc/STALE-ROW\n' > "$BR/.ai-dlc-fixture-readsets.tsv"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm stale ) >/dev/null 2>&1 || broken "could not seed the stale map row"
    omit_run() { # $1 deriver copy; prints "<stale rows>|<other rows>|<OMITTED map lines>|<stdout OMITTED report>"
      local s o h v
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$SX/lossy.list" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" -- core/scripts/derive-fixture-readsets.sh --list fxa --tracer sandbox ) > "$WORK/omit.out" 2>&1 </dev/null
      stub_reap "${SB:-}"
      s="$(grep -c 'STALE-ROW' "$BR/.ai-dlc-fixture-readsets.tsv")" || s=0
      o="$(grep -c '^other	' "$BR/.ai-dlc-fixture-readsets.tsv")" || o=0
      h="$(grep -c '^# OMITTED' "$BR/.ai-dlc-fixture-readsets.tsv")" || h=0
      v="$(grep -c ' OMITTED and therefore always run: fxa$' "$WORK/omit.out")" || v=0
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s|%s|%s' "$s" "$o" "$h" "$v"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    OR="$(omit_run "$SB/deriver.sh")"
    if [ "$OR" = "0|2|0|1" ]; then
      ok "OMITTED --list: a one-fixture refresh whose fixture is omitted writes the map, drops its stale row, keeps the other fixture's rows, writes no OMITTED line into the map and names it OMITTED on stdout"
    else
      bad "OMITTED --list: expected stale 0, other 2, OMITTED map lines 0, stdout OMITTED report 1, got '$OR' — $(tail -2 "$WORK/omit.out" | tr '\n' ' ')"
    fi

    # `--all` WITH ONE FIXTURE OMITTED, END TO END. The function arms above drive the extracted spans;
    # this drives the whole deriver the way the operator runs it. The stale-row map above is still
    # committed, and a `plan-shape` fixture reading its own subject is seeded beside fxa, so the
    # world has TWO fixture directories -- with one, the base newline list has no newline and base
    # does not die. The stub sandbox-exec reports ONE stream list for every launch, so each world is
    # a union list:
    #   world O  {fxa/run.sh, plan-shape/run.sh, validate-plan-shape.sh}: fxa's src/a.sh read is
    #            unreported, so the canary omits fxa and plan-shape maps. The fix writes the map, with
    #            no OMITTED line, names fxa OMITTED on stdout and prints the plan-shape PRESENCE line; base dies
    #            "merge dropped 'fxa'" and never reaches the plan-shape pair.
    #   world S  {fxa/run.sh, src/a.sh, plan-shape/run.sh}: plan-shape is the omitted one, fxa maps
    #            (with both omitted, `--all` dies "zero fixtures mapped"). The fix prints the SKIP
    #            line, writes the map with no OMITTED line and names plan-shape OMITTED on stdout.
    #            A MAPPED `plan-shape-x` sibling sits in both worlds: its rows begin with the string
    #            `plan-shape`, so a D1 guard that greps `^plan-shape` without the tab reads them as
    #            plan-shape's own and runs the pair on an omitted plan-shape, so the sibling
    #            is seeded.
    mkdir -p "$BR/core/fixtures/plan-shape" "$BR/core/fixtures/plan-shape-x" "$BR/scripts" || broken "mkdir failed"
    printf '#!/bin/bash\ncat scripts/validate-plan-shape.sh >/dev/null\n' > "$BR/core/fixtures/plan-shape/run.sh"
    printf '#!/bin/bash\nexit 0\n' > "$BR/core/fixtures/plan-shape-x/run.sh"
    printf '#!/bin/bash\nexit 0\n' > "$BR/scripts/validate-plan-shape.sh"
    printf '%s\n' core/fixtures/fxa/run.sh core/fixtures/plan-shape/run.sh core/fixtures/plan-shape-x/run.sh scripts/validate-plan-shape.sh > "$SX/allO.list"
    printf '%s\n' core/fixtures/fxa/run.sh src/a.sh core/fixtures/plan-shape/run.sh core/fixtures/plan-shape-x/run.sh > "$SX/allS.list"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm plan-shape ) >/dev/null 2>&1 || broken "could not seed the plan-shape fixture"
    [ "$(find "$BR/core/fixtures" -mindepth 2 -maxdepth 2 -name run.sh | grep -c .)" -ge 2 ] \
      || broken "the --all world holds fewer than two fixture directories, so the base newline list cannot carry a newline and the arm cannot discriminate"
    all_run() { # $1 deriver copy  $2 stream list  $3 omitted name; prints "<rc>|<OMITTED map lines>|<presence>|<skip>|<merge dropped>|<stdout OMITTED report>"
      local r h p k m v
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$2" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" -- core/scripts/derive-fixture-readsets.sh --all --tracer sandbox ) > "$WORK/all.out" 2>&1 </dev/null
      r=$?
      stub_reap "${SB:-}"
      h="$(grep -c '^# OMITTED' "$BR/.ai-dlc-fixture-readsets.tsv")" || h=0
      v="$(grep -c " OMITTED and therefore always run: $3\$" "$WORK/all.out")" || v=0
      p="$(grep -c "^  PASS  plan-shape's read-set names its own subject" "$WORK/all.out")" || p=0
      k="$(grep -cxF '  SKIP  plan-shape controls: plan-shape OMITTED this run' "$WORK/all.out")" || k=0
      m="$(grep -c "merge dropped 'fxa'" "$WORK/all.out")" || m=0
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s|%s|%s|%s|%s' "$r" "$h" "$p" "$k" "$m" "$v"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    AO="$(all_run "$SB/deriver.sh" "$SX/allO.list" fxa)"
    if [ "$AO" = "0|0|1|0|0|1" ]; then
      ok "--all, fxa OMITTED: the deriver writes the map with no OMITTED line, names fxa OMITTED on stdout, and the plan-shape pair RUNS under --all (its presence line printed)"
    else
      bad "--all, fxa OMITTED: expected rc 0, OMITTED map lines 0, plan-shape presence 1, skip 0, merge-dropped 0, stdout OMITTED report 1; got '$AO' — $(grep -m1 -E 'ERROR|merge dropped' "$WORK/all.out" | tr '\n' ' ')$(tail -2 "$WORK/all.out" | tr '\n' ' ')"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    AS="$(all_run "$SB/deriver.sh" "$SX/allS.list" plan-shape)"
    if [ "$AS" = "0|0|0|1|0|1" ]; then
      ok "--all, plan-shape OMITTED: the deriver prints the exact SKIP line for the plan-shape pair, writes the map with no OMITTED line and names plan-shape OMITTED on stdout"
    else
      bad "--all, plan-shape OMITTED: expected rc 0, OMITTED map lines 0, presence 0, SKIP line 1, merge-dropped 0, stdout OMITTED report 1; got '$AS' — $(tail -2 "$WORK/all.out" | tr '\n' ' ')"
    fi

    # THE UNREAD CONTROL. A fixture that reads the planted control file is the stand-in for a reset
    # that did not hold (the file's atime moves either way): it must be OMITTED naming the control.
    # The ordinary stub run above is the near-miss and already maps (CANARY CONTROL).
    mkdir -p "$BR/core/fixtures/fxu" || broken "mkdir failed"
    printf '#!/bin/bash\ncat .git/readset-unread-control >/dev/null\ncat src/a.sh >/dev/null\n' > "$BR/core/fixtures/fxu/run.sh"
    printf '%s\n' core/fixtures/fxu/run.sh src/a.sh > "$SX/fxu.list"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fxu ) >/dev/null 2>&1 || broken "could not seed fxu"
    unread_run() { # $1 deriver copy; prints the fxu line
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$SX/fxu.list" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" -- core/scripts/derive-fixture-readsets.sh --list fxu --tracer sandbox ) > "$WORK/unread.out" 2>&1 </dev/null
      stub_reap "${SB:-}"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      grep -m1 -E '^  fxu ' "$WORK/unread.out" | tr -s ' '
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    UR="$(unread_run "$SB/deriver.sh")"
    case "$UR" in
      " fxu OMITTED ("*"UNREAD CONTROL"*) ok "UNREAD CONTROL: a fixture whose window moved the planted control's atime is OMITTED naming the control" ;;
      *) bad "UNREAD CONTROL: expected fxu OMITTED naming the UNREAD CONTROL, got '$UR' — $(tail -2 "$WORK/unread.out" | tr '\n' ' ')" ;;
    esac

    # `--local-map`, THE DERIVER HALF, DRIVEN WHOLE IN THE STUB-STREAM WORLD. The hook starts this mode
    # detached and nobody reads its output, so each condition below is scored on what it WRITES to the
    # local map. fxl is a fixture the committed map does not name; it prints two verdict lines.
    # Its own stub sandbox-exec strips `-D FXTAG=<fx>` and tags every report it writes, the way the
    # profile's `(with message ...)` does; STUB_TRIP adds an exec of a refused binary, STUB_DROP a
    # drop notice, and the stream stub delivers nothing for the liveness probe when STUB_DEADLIVE is set.
    SL="$WORK/lmstub"; mkdir -p "$SL" || broken "mkdir failed"
    cat > "$SL/sandbox-exec" <<'STUB'
#!/bin/bash
. "$STUB_STREAM_LIB"
tag=""
[ "$1" = -D ] && { tag="${2#FXTAG=}"; shift 2; }
[ "$1" = -f ] && shift 2
emit() { ss_emit "$1"; [ -z "$tag" ] || ss_emit "FXTAG=$tag;"; }
_c=1; [ "$1" = env ] && { _c=2; for _w in "${@:2}"; do case "$_w" in *=*) _c=$((_c+1)) ;; *) break ;; esac; done; }
if [ "${!_c}" = bash ]; then
  while IFS= read -r p; do [ -n "$p" ] && emit "x Sandbox: bash(1) allow file-read-data $PWD/$p"; done < "$STUB_SB"
  [ -z "${STUB_TRIP:-}" ] || { ss_emit 'x Sandbox: bash(1) allow process-exec* /usr/bin/sudo'; ss_emit "FXTAG=$tag;TRIP"; }
  [ -z "${STUB_DROP:-}" ] || ss_emit '=== Messages dropped during live streaming'
else
  for a in "$@"; do case "$a" in /*) ss_wait "$a"; emit "x Sandbox: cat(1) allow file-read-data $a" ;; esac; done
fi
exec "$@"
STUB
    # STUB_DEADLIVE: the liveness probe's stream registers DEAF and stays up until the deriver kills it, so
    # the probe runs its whole bound and refuses -- a stream that is attached and never delivers.
    cat > "$SL/logstream" <<'STUB'
#!/bin/bash
echo $$ >> "${0%/*}/pids"   # the world reaps this pid by number (stub_reap); exec keeps it
. "$STUB_STREAM_LIB"
m=live
case "$*" in *FXTAG=__liveness__\;*) [ -z "${STUB_DEADLIVE:-}" ] || m=deaf ;; esac
ss_register "$m"
exec tail -f /dev/null
STUB
    chmod +x "$SL/sandbox-exec" "$SL/logstream"
    : > "$SL/feed"
    SL_TR="$(cd "$WORK" && pwd -P)/lm.tr"
    LMF="$BR/.git/ai-dlc-fixture-readsets.local"
    # `other` is the COMMITTED fixture whose local row the committed-wins prune drops. Its directory
    # is present, so the present-set prune cannot also drop that row.
    mkdir -p "$BR/core/fixtures/fxl" "$BR/core/fixtures/zz" "$BR/core/fixtures/other" || broken "mkdir failed"
    printf '#!/bin/bash\nexit 0\n' > "$BR/core/fixtures/other/run.sh"
    printf '#!/bin/bash\ncat src/a.sh >/dev/null\necho "  ok    one"\necho "  ok    two"\n' > "$BR/core/fixtures/fxl/run.sh"
    # zz is a PRESENT fixture whose local rows the trace leaves alone; gh, seeded by lm_seed, has no
    # directory, so its rows are pruned.
    printf '#!/bin/bash\nexit 0\n' > "$BR/core/fixtures/zz/run.sh"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fxl ) >/dev/null 2>&1 || broken "could not seed fxl"
    grep -q '^fxl	' "$BR/.ai-dlc-fixture-readsets.tsv" && broken "fxl has committed rows, so its local rows would be pruned and every arm below would read an empty map"
    printf '%s\n' core/fixtures/fxl/run.sh src/a.sh > "$SL/whole.list"
    printf '%s\n' core/fixtures/fxl/run.sh > "$SL/lossy.list"
    sed "s|^LOG_BIN=/usr/bin/log\$|LOG_BIN=\"$SL/logstream\"|" "$DERIVER" > "$SL/deriver.sh"
    cmp -s "$DERIVER" "$SL/deriver.sh" && broken "the LOG_BIN line is gone, so the --local-map world cannot point the stream at a stub"
    # lm_run <deriver copy> <stream list> <stash: same|diff|none> [env...]; prints
    # "<rc>|<fxl path rows>|<deriver row ok>|<discards n>|<other kept>|<zz kept>|<trace root gone>|<why>"
    lm_run() {
      local dv="$1" sl="$2" st="$3" r rows dok dn ok2 zz gone
      shift 3
      cp "$dv" "$STUB_DERIVER"
      mkdir -p "$LMF.logs"
      case "$st" in
        same) printf '  ok    one\n  ok    two\n' > "$LMF.logs/fxl" ;;
        diff) printf '  ok    one\n  FAIL  two\n' > "$LMF.logs/fxl" ;;
        none) rm -f "$LMF.logs/fxl" ;;
      esac
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SL:$PATH" STUB_FEED="$SL/feed" STUB_SB="$sl" "$@" \
          AI_DLC_READSET_TRACE_ROOT="$SL_TR" -- core/scripts/derive-fixture-readsets.sh --list fxl --tracer sandbox --local-map "$LMF" ) > "$WORK/lm.out" 2>&1 </dev/null
      r=$?
      stub_reap "${SL:-}"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      rows="$(grep -c '^fxl	[^#]' "$LMF" 2>/dev/null)" || rows=0
      # Keyed on the copy that RAN ($dv): the checkout above has already restored $STUB_DERIVER.
      dok=no; grep -qxF "fxl	#deriver	$(shasum -a 256 -- "$dv" | cut -d' ' -f1)" "$LMF" 2>/dev/null && dok=yes
      dn="$(awk -F'\t' '$1 == "fxl" && $2 == "#discards" { print $3 }' "$LMF" 2>/dev/null)"
      ok2=no; grep -q '^other	' "$LMF" 2>/dev/null && ok2=yes
      zz=no; grep -q '^zz	src/zz.sh	' "$LMF" 2>/dev/null && zz=yes
      gone=no; [ -e "$SL_TR" ] || gone=yes
      printf '%s|%s|%s|%s|%s|%s|%s|%s' "$r" "$rows" "$dok" "${dn:--}" "$ok2" "$zz" "$gone" \
        "$(grep -m1 -E '^  fxl +OMITTED|LIVENESS|LINKED' "$WORK/lm.out" | tr -s ' ' | sed 's/^ *//' | cut -c1-120)"
    }
    lm_seed() { printf 'gh\tsrc/gh.sh\tghi\ngh\t#deriver\tx\nother\tsrc/other.sh\tabc\nzz\tsrc/zz.sh\tdef\nzz\t#deriver\tx\n' > "$LMF"; }
    lm_arm() { # <label> <result> <glob> <ok text>; returns 0 when the arm passed, so a caller can bind a flag
      TRACE_ARMS=$((TRACE_ARMS+1))
      case "$2" in $3) ok "$4"; return 0 ;; *) bad "$1: expected '$3', got '$2' — $(tail -2 "$WORK/lm.out" | tr '\n' ' ')"; return 1 ;; esac
    }
    lm_seed; L1="$(lm_run "$SL/deriver.sh" "$SL/whole.list" same)"
    L1_COPY="$(grep -c 'copying the tree to' "$WORK/lm.out")" || L1_COPY=0
    TRACE_ARMS=$((TRACE_ARMS+1))
    if [ "$(grep -c '^gh	' "$LMF" 2>/dev/null)" = 0 ] && [ "$(grep -c '^zz	' "$LMF" 2>/dev/null)" = 2 ]; then
      ok "  and a fixture with NO directory loses every local row, while the untraced zz, whose directory is present, keeps both of its rows"
    else
      bad "  the ghost fixture gh kept local rows, or zz lost its own: $(cut -f1,2 "$LMF" | tr '\t\n' ': ')"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    if awk -F'\t' -v s="$(shasum -a 256 -- "$BR/src/a.sh" | cut -d' ' -f1)" '$1 == "fxl" && $2 == "src/a.sh" && $3 == s { f = 1 } END { exit !f }' "$LMF" \
       && ! grep -q '^fxl	' "$BR/.ai-dlc-fixture-readsets.tsv"; then
      ok "  and each row carries the sha256 of the file it names, while the committed map is untouched"
    else
      bad "  fxl's src/a.sh row does not carry its sha256, or the committed map gained an fxl row: $(grep '^fxl' "$LMF" | tr '\n' ' ')"
    fi
    lm_seed; L2="$(lm_run "$SL/deriver.sh" "$SL/whole.list" same STUB_TRIP=1)"
    L2B="$(lm_run "$SL/deriver.sh" "$SL/whole.list" same STUB_TRIP=1)"
    lm_arm "LOCAL TRIP x2" "$L2B" "0|0|no|2|*" "  and a second discard on the same key counts 2 — the hook holds the fixture back at 3"
    L2C="$(lm_run "$SL/deriver.sh" "$SL/whole.list" same)"
    lm_arm "LOCAL recover" "$L2C" "0|2|yes|-|*" "  and a clean trace after it records the rows and clears the discard count"
    lm_seed; L3="$(lm_run "$SL/deriver.sh" "$SL/whole.list" same STUB_DROP=1)"
    lm_arm "LOCAL drop" "$L3" "0|0|no|1|*|*|yes|fxl OMITTED (the stream dropped reports*" "LOCAL: a DROP NOTICE in fxl's window discards the trace"
    lm_seed; L4="$(lm_run "$SL/deriver.sh" "$SL/lossy.list" same)"
    lm_arm "LOCAL canary" "$L4" "0|0|no|1|*|*|yes|fxl OMITTED (LOSS CANARY: 1 path(s)*" "LOCAL: the LOSS CANARY (a read the stream never reported) discards the trace"
    # A FOREIGN DERIVER'S MARKERS IN THIS RUN'S STREAM (BL-798). The stream predicate is the FXTAG alone, so
    # a concurrent deriver tracing the same fixture name lands its own marker reads (another MARKDIR) in this
    # stream. The stub below interleaves them: a foreign sentinel and a foreign end between this run's two
    # reads, and a foreign end on the first end-marker read with this run's own end only on the second. A
    # window cut or a flush keyed on the bare marker name cuts at the foreign pair or flushes on the foreign
    # end; keyed on this run's own paths, fxl maps both reads. No real `log stream`, no timing: the second
    # end-marker read, not the clock, is what the flush must wait for.
    SG="$WORK/fgstub"; mkdir -p "$SG" || broken "mkdir failed"
    cat > "$SG/sandbox-exec" <<'STUB'
#!/bin/bash
. "$STUB_STREAM_LIB"
tag=""
[ "$1" = -D ] && { tag="${2#FXTAG=}"; shift 2; }
[ "$1" = -f ] && shift 2
emit() { ss_emit "$1"; [ -z "$tag" ] || ss_emit "FXTAG=$tag;"; }
FM=/private/tmp/ai-dlc-foreign-deriver/m
_c=1; [ "$1" = env ] && { _c=2; for _w in "${@:2}"; do case "$_w" in *=*) _c=$((_c+1)) ;; *) break ;; esac; done; }
if [ "${!_c}" = bash ]; then
  n=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    emit "x Sandbox: bash(1) allow file-read-data $PWD/$p"
    n=$((n+1))
    if [ "$n" = 1 ]; then
      emit "x Sandbox: cat(1) allow file-read-data $FM/.readset-sentinel"
      emit "x Sandbox: cat(1) allow file-read-data $FM/.readset-end"
    fi
  done < "$STUB_SB"
else
  for a in "$@"; do ss_wait "$a"; case "$a" in
    */.readset-end)
      emit "x Sandbox: cat(1) allow file-read-data $FM/.readset-end"
      k=0; [ -f "$FG_COUNT" ] && k="$(cat "$FG_COUNT")"
      echo $((k+1)) > "$FG_COUNT"
      [ "$k" -lt 1 ] || emit "x Sandbox: cat(1) allow file-read-data $a" ;;
    /*) emit "x Sandbox: cat(1) allow file-read-data $a" ;;
  esac; done
fi
exec "$@"
STUB
    chmod +x "$SG/sandbox-exec"
    fg_run() { rm -f "$SG/endn"; lm_seed; lm_run "$1" "$SL/whole.list" same PATH="$SG:$SL:$PATH" FG_COUNT="$SG/endn"; }
    FG0="$(fg_run "$SL/deriver.sh")"
    lm_arm "FOREIGN markers" "$FG0" "0|2|yes|-|*" "LOCAL: a foreign deriver's sentinel and end lines (same FXTAG, another MARKDIR), the end ahead of this run's own, leave the window cut at THIS run's markers — fxl maps both reads"
    lm_seed; L5="$(lm_run "$SL/deriver.sh" "$SL/whole.list" diff)"
    lm_arm "LOCAL verdict" "$L5" "0|0|no|1|*|*|yes|fxl OMITTED (VERDICT: the sandboxed run's verdict lines differ*" "LOCAL: a sandboxed run whose verdict lines differ from the normal run's is discarded"
    lm_seed; L6="$(lm_run "$SL/deriver.sh" "$SL/whole.list" none)"
    lm_arm "LOCAL nolog" "$L6" "0|0|no|1|*|*|yes|fxl OMITTED (VERDICT: no normal-run log*" "  and so is one with no stashed normal-run log to compare against"
    lm_seed; L7="$(lm_run "$SL/deriver.sh" "$SL/whole.list" same STUB_DEADLIVE=1)"
    L7_COPY="$(grep -c 'copying the tree to' "$WORK/lm.out")" || L7_COPY=0
    lm_arm "LOCAL liveness" "$L7" "1|0|no|-|yes|yes|yes|ERROR: LIVENESS*" "LOCAL: a stream that never sees the 1s liveness probe REFUSES before tracing — the local map is untouched and the trace root is removed"
    # THE REFUSAL PAYS NO TREE COPY. A consumer whose stream never delivers refuses on every green
    # push, so the copy must come after the probe. The clean run above is the control: it copies.
    TRACE_ARMS=$((TRACE_ARMS+1))
    if [ "$L7_COPY" = 0 ] && [ "$L1_COPY" = 1 ]; then
      ok "  and it refuses BEFORE copying the tree, while the clean trace above copies it once"
    else
      bad "  liveness refusal copied the tree (${L7_COPY}x), or the clean trace did not (${L1_COPY}x)"
    fi
    ( cd "$BR" && git worktree add -q "$WORK/lmwt" -b lmwt ) >/dev/null 2>&1 || broken "could not add a linked worktree for the --local-map arm"
    TRACE_ARMS=$((TRACE_ARMS+1))
    LW_R="$( ( cd "$WORK/lmwt" && rs_drive PATH="$SL:$PATH" -- core/scripts/derive-fixture-readsets.sh --list fxl --tracer sandbox --local-map "$WORK/lmwt.local" ) 2>&1 )"; LW_RC=$?
    stub_reap "${SL:-}"
    if [ "$LW_RC" -eq 1 ] && grep -q 'LINKED worktree' <<< "$LW_R" && [ ! -e "$WORK/lmwt.local" ]; then
      ok "LOCAL: from a LINKED worktree --local-map refuses at the worktree gate and writes no local map"
    else
      bad "LOCAL: a linked worktree did not refuse --local-map at 1 with no file written (rc $LW_RC): $(printf '%s' "$LW_R" | head -2 | tr '\n' ' ')"
    fi
    # BL-701: the pool's two modes are ADMITTED from the same linked worktree. `--merge-pool` on an empty pool
    # exits 0 having parsed; `--in-pool` with a two-name list reaches its own parse refusal, which it can only
    # print once the linked-worktree gate above has let it through. The --local-map refusal is the control.
    TRACE_ARMS=$((TRACE_ARMS+1))
    mkdir -p "$WORK/lmwt.mp" || broken "mkdir failed"
    LW_M="$( ( cd "$WORK/lmwt" && rs_drive PATH="$SL:$PATH" -- core/scripts/derive-fixture-readsets.sh --merge-pool "$WORK/lmwt.mp" --local-map "$WORK/lmwt.mpl" ) 2>&1 )"; LW_MRC=$?
    stub_reap "${SL:-}"
    LW_I="$( ( cd "$WORK/lmwt" && rs_drive PATH="$SL:$PATH" -- core/scripts/derive-fixture-readsets.sh --list "fxl fxa" --tracer sandbox --in-pool "$WORK/lmwt.ip" ) 2>&1 )"; LW_IRC=$?
    stub_reap "${SL:-}"
    if [ "$LW_MRC" -eq 0 ] && grep -q 'no in-pool trace to merge' <<< "$LW_M" && ! grep -q 'LINKED worktree' <<< "$LW_M$LW_I" \
       && [ "$LW_IRC" -eq 1 ] && grep -q 'needs --list with exactly ONE fixture' <<< "$LW_I"; then
      ok "LOCAL: from a LINKED worktree --merge-pool and --in-pool pass the worktree gate that still refuses --local-map"
    else
      bad "LOCAL: a linked worktree refused a pool mode (merge rc $LW_MRC, in-pool rc $LW_IRC): $(printf '%s %s' "$LW_M" "$LW_I" | head -3 | tr '\n' ' ')"
    fi

    # `--in-pool` AND `--merge-pool`, DRIVEN IN THE SAME STUB-STREAM WORLD. The worker traces ONE
    # fixture and leaves `<dir>/{log,rc,trip,rows,discard}`; `--merge-pool <parent>` is the one serial
    # writer that folds every `<parent>/<fx>/{rows,discard}` into the local map. Every arm below
    # DEMANDS a file or a row to appear. ip_run prints
    # "<rc>|<rows lines>|<rows carry src/a.sh's sha256>|<rc file>|<log>|<discard>|<trip>|<discard text>"
    # and mp_run prints "<rc>|<fxl path rows>|<deriver row>|<fxl discards n>|<zz rows>|<other rows>".
    IPP="$WORK/ippool"
    ip_run() { # <deriver copy> <stream list> [env...]
      local dv="$1" sl="$2" d="$IPP/fxl" r rows sh rcf lg ds tp dt
      shift 2
      cp "$dv" "$STUB_DERIVER"; rm -rf "$IPP" "$SL_TR"; mkdir -p "$d.logs-seed" || broken "mkdir failed"
      rm -rf "$d.logs-seed"; mkdir -p "$d"
      mkdir -p "$d/local.logs" && printf '  ok    one\n  ok    two\n' > "$d/local.logs/fxl" || broken "could not seed the in-pool normal-run log"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SL:$PATH" STUB_FEED="$SL/feed" STUB_SB="$sl" "$@" \
          AI_DLC_READSET_TRACE_ROOT="$SL_TR" -- core/scripts/derive-fixture-readsets.sh --list fxl --tracer sandbox --in-pool "$d" ) > "$WORK/ip.out" 2>&1 </dev/null
      r=$?
      stub_reap "${SL:-}"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      rows=0; [ -f "$d/rows" ] && rows="$(grep -c . "$d/rows")"
      sh=no; [ -f "$d/rows" ] && awk -F'\t' -v s="$(shasum -a 256 -- "$BR/src/a.sh" | cut -d' ' -f1)" '$1 == "fxl" && $2 == "src/a.sh" && $3 == s { f = 1 } END { exit !f }' "$d/rows" && sh=yes
      rcf=-; [ -f "$d/rc" ] && rcf="$(cat "$d/rc")"
      lg=no; [ -s "$d/log" ] && lg=yes
      ds=no; [ -f "$d/discard" ] && ds=yes
      tp=no; [ -e "$d/trip" ] && tp=yes
      dt=-; [ -f "$d/discard" ] && dt="$(awk -F'\t' '{ print $1; exit }' "$d/discard")"
      rm -rf "$SL_TR"
      printf '%s|%s|%s|%s|%s|%s|%s|%s' "$r" "$rows" "$sh" "$rcf" "$lg" "$ds" "$tp" "$dt"
    }
    mp_run() { # prints the merge's effect on $LMF; the pool under $IPP stays as ip_run left it
      local r fr dok dn zz ot
      ( cd "$BR" && rs_drive PATH="$SL:$PATH" -- core/scripts/derive-fixture-readsets.sh --merge-pool "$IPP" --local-map "$LMF" ) > "$WORK/mp.out" 2>&1 </dev/null
      r=$?
      stub_reap "${SL:-}"
      fr="$(grep -c '^fxl	[^#]' "$LMF" 2>/dev/null)" || fr=0
      dok=no; grep -qxF "fxl	#deriver	$(shasum -a 256 -- "$BR/core/scripts/derive-fixture-readsets.sh" | cut -d' ' -f1)" "$LMF" 2>/dev/null && dok=yes
      dn="$(awk -F'\t' '$1 == "fxl" && $2 == "#discards" { print $3 }' "$LMF" 2>/dev/null)"
      zz="$(grep -c '^zz	' "$LMF" 2>/dev/null)" || zz=0
      ot="$(grep -c '^other	' "$LMF" 2>/dev/null)" || ot=0
      printf '%s|%s|%s|%s|%s|%s' "$r" "$fr" "$dok" "${dn:--}" "$zz" "$ot"
    }
    ip_arm() { # <label> <result> <glob> <ok text>; returns 0 when the arm passed
      TRACE_ARMS=$((TRACE_ARMS+1))
      case "$2" in $3) ok "$4"; return 0 ;; *) bad "$1: expected '$3', got '$2' — $(tail -2 "$WORK/ip.out" "$WORK/mp.out" 2>/dev/null | tr '\n' ' ')"; return 1 ;; esac
    }
    # ip_world <deriver copy> [<scenarios>]: the scenarios (default A B C D E E2), results in IPW_*.
    # E's trace is A's input byte for byte (clean, whole list), so E reuses the pool A left, saved after A,
    # instead of tracing fxl a second time; only E's two extra empty directories are its own.
    ip_world() {
      local sc=" ${2:-A B C D E E2} "
      case "$sc" in *" A "*|*" E "*)
        lm_seed; IPW_A="$(ip_run "$1" "$SL/whole.list")"; rm -rf "$IPP.A"; cp -R "$IPP" "$IPP.A"; IPW_AM="$(mp_run)" ;; esac
      case "$sc" in *" B "*) lm_seed; IPW_B="$(ip_run "$1" "$SL/whole.list" STUB_DROP=1)"; IPW_BM="$(mp_run)" ;; esac
      case "$sc" in *" C "*) lm_seed; IPW_C="$(ip_run "$1" "$SL/lossy.list")"; IPW_CM="$(mp_run)" ;; esac
      case "$sc" in *" D "*) lm_seed; IPW_D="$(ip_run "$1" "$SL/whole.list" STUB_TRIP=1)" ;; esac
      # E: a traced fxl beside two directories with neither rows nor discard; their local rows stand.
      case "$sc" in *" E "*)
        lm_seed; rm -rf "$IPP"; cp -R "$IPP.A" "$IPP"; mkdir -p "$IPP/zz" "$IPP/other"; IPW_EM="$(mp_run)" ;; esac
      case "$sc" in *" E2 "*) ;; *) return 0 ;; esac
      # E2: only an empty directory -- nothing to merge, the map must stand byte for byte.
      lm_seed; cp "$LMF" "$WORK/ip.seeded"; rm -rf "$IPP"; mkdir -p "$IPP/zz"; IPW_EN="$(mp_run)"
      if cmp -s "$LMF" "$WORK/ip.seeded"; then IPW_EN="$IPW_EN|same"; else IPW_EN="$IPW_EN|changed"; fi
      IPW_ENMSG=no; grep -q 'no in-pool trace to merge' "$WORK/mp.out" && IPW_ENMSG=yes
    }
    ip_world "$SL/deriver.sh"
    ip_arm "IN-POOL clean" "$IPW_A" "0|2|yes|0|yes|no|no|-" "IN-POOL: a clean trace of fxl writes rows naming its paths with sha256 values, rc 0 and a log, and no discard or trip"
    ip_arm "MERGE-POOL clean" "$IPW_AM" "0|2|yes|-|2|1" "MERGE-POOL: the rows land in the local map with a #deriver row, while the untraced zz and other keep theirs"
    ip_arm "IN-POOL drop" "$IPW_B" "0|0|no|0|yes|yes|no|fxl" "IN-POOL: a drop notice in the window writes a discard and no rows"
    ip_arm "MERGE-POOL drop" "$IPW_BM" "0|0|no|1|2|1" "MERGE-POOL: the discard lands as a #discards row and no fxl path rows"
    ip_arm "IN-POOL canary" "$IPW_C" "0|0|no|0|yes|yes|no|fxl" "IN-POOL: the LOSS CANARY (a read the stream never reported) discards the trace"
    ip_arm "MERGE-POOL canary" "$IPW_CM" "0|0|no|1|2|1" "  and the merge records that discard"
    ip_arm "IN-POOL trip" "$IPW_D" "0|*|*|0|yes|*|yes|*" "IN-POOL: a refused exec leaves <dir>/trip and still writes rc"
    ip_arm "MERGE-POOL empty dirs" "$IPW_EM" "0|2|yes|-|2|1" "MERGE-POOL: a subdirectory with neither rows nor discard changes nothing, so zz and other keep their rows"
    ip_arm "MERGE-POOL nothing" "$IPW_EN|$IPW_ENMSG" "0|*|*|*|*|*|same|yes" "MERGE-POOL: a pool holding only an empty directory says so and writes nothing"

    # THE MAP IS WRITTEN AFTER EACH ACCEPTED FIXTURE, SO AN INTERRUPTED RUN KEEPS WHAT IT TRACED.
    # Three fixtures with OLD committed rows; a `--list "fxw1 fxw2 fxw3"` run is SIGKILLed while
    # fxw3 runs (fxw3 touches <flag>.at and waits; the fixture then kills the deriver's whole process
    # group, and removes the flag). The map must hold fxw1's and
    # fxw2's NEW rows, none of their OLD ones, fxw3's OLD row and no fxw3 NEW row.
    # The identity arm runs the same three UNINTERRUPTED, with fxw2 omitted by the canary (its read
    # of src/w2.sh is unreported), so the final map drops a mid-list fixture's rows and the run's
    # stdout names it OMITTED.
    mkdir -p "$BR/core/fixtures/fxw1" "$BR/core/fixtures/fxw2" "$BR/core/fixtures/fxw3" || broken "mkdir failed"
    printf '#!/bin/bash\ncat src/w1.sh >/dev/null\n' > "$BR/core/fixtures/fxw1/run.sh"
    printf '#!/bin/bash\ncat src/w2.sh >/dev/null\n' > "$BR/core/fixtures/fxw2/run.sh"
    printf '#!/bin/bash\ncat src/w3.sh >/dev/null\nif [ -n "${STUB_KILLFLAG:-}" ]; then : > "$STUB_KILLFLAG.at"; while [ -e "$STUB_KILLFLAG" ]; do sleep 0.1; done; fi\n' > "$BR/core/fixtures/fxw3/run.sh"
    printf 'w1\n' > "$BR/src/w1.sh"; printf 'w2\n' > "$BR/src/w2.sh"; printf 'w3\n' > "$BR/src/w3.sh"
    printf 'fxw1\tsrc/OLD-1\nfxw2\tsrc/OLD-2\nfxw3\tsrc/OLD-3\n' >> "$BR/.ai-dlc-fixture-readsets.tsv"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fxw ) >/dev/null 2>&1 || broken "could not seed fxw1-3"
    printf '%s\n' core/fixtures/fxw1/run.sh core/fixtures/fxw2/run.sh core/fixtures/fxw3/run.sh src/w1.sh src/w2.sh src/w3.sh > "$SX/fxw.list"
    printf '%s\n' core/fixtures/fxw1/run.sh core/fixtures/fxw2/run.sh core/fixtures/fxw3/run.sh src/w1.sh src/w3.sh > "$SX/fxw.omit.list"
    # THE KILL REAPS THE RUN'S WHOLE PROCESS GROUP (BL-900). The run starts under `set -m`, so it leads a group
    # whose id is its recorded pid, and the kill is `kill -9 -- -<pid>` until no member answers. A one-level
    # `pkill -P <pid>; kill <pid>` left any process the deriver forked BETWEEN the two signals alive: killing its
    # children woke it into the flush, whose `sandboxed cat` of the end marker is a stub that waits, unbounded, for
    # a live stream of `w/fxw3.raw`. That orphan outlived the run, and the next run on this SAME trace root and
    # feed registered exactly that stream at its own fxw3: the orphan's end-marker read landed in IU's capture
    # ahead of fxw3's own reads, and fxw3 was OMITTED (LOSS CANARY, with or without "no end sentinel"). Each run's
    # output goes to its own `<map out>.out`, so a later run cannot overwrite the reason an earlier one printed.
    # The group's state is written to `<map out>.grp` as "<alive before the kill>|<alive after the reap>".
    #
    # NO BOUND, A SETTLED-STATE REFUSAL (BL-868). The reaper loops until the group is gone, and refuses only on a
    # member that SURVIVED A KILL: a pid read settled (every live member aw_blocked -- state S, I or T with nothing
    # pending) that reads settled again after a later `kill -9 -- -<pgid>`. A SIGKILL wakes a blocked member at once,
    # so a pid blocked with nothing pending on BOTH sides of a kill is one the kill provably did not take -- it is not
    # in the group the kill named, or the kernel will not deliver to it. A FIRST settled read is never a refusal: a
    # `kill -9 -- -<pgid>` reaches every member present when it is sent, and the one it can miss is a member forked in
    # flight, which reads settled once and is taken by the next kill. So each settled read's pids are remembered, the
    # group is killed again, and only a remembered pid read settled again refuses -- however many in-flight
    # generations a run's chain forks, and however long its members take to exit. A member that took SIGKILL and is
    # still exiting on a loaded box is never blocked with nothing pending (aw_group_settled's contract), so it is
    # polled, and the remembered set is kept across those polls. The 5-round count this replaces assumed the chain
    # was five generations deep, which a run whose in-flight members kept settling past the count turned into FIXTURE
    # BROKEN. OUTCOME ON REFUSAL: the reaper writes "BROKEN" and each surviving remembered pid with its `ps` state into
    # AW_STALL_LOG; the caller's shell refuses on it with aw_gate before any verdict is read, because iw_run runs
    # inside `$( )` and a `broken` there would end only the subshell -- and the fixture's final aw_gate refuses on it
    # again, so a dropped call-site gate is still FIXTURE BROKEN and never a verdict. LIMITS: a member stuck in the
    # kernel with SIGKILL pending reads as dying forever and is polled, unbounded -- a hang for the gate's watchdog,
    # never a verdict; and a remembered pid that dies and is REUSED by a new in-flight member of the same group before
    # the next read would read as a survivor (a refusal, never a pass).
    # A zombie never answers `kill -0 -- -<pgid>` here (measured on Darwin: a zombie-only group reads rc 1, a live
    # one rc 0), so a killed leader not yet waited cannot hold the loop, and the reaper never `wait`s inside it:
    # a wait on a leader that never dies would block before the group is read.
    # iw_group_state <pgid>: "gone", "dying" (a live member is not blocked), or "missed <pid>..." (every live member
    # blocked with nothing pending). The reaper reads the group only through ${IW_GROUP_STATE:-iw_group_state}.
    iw_group_state() {
      kill -0 -- -"$1" 2>/dev/null || { echo gone; return 0; }
      if aw_group_settled "$1"; then printf 'missed %s\n' "$(pgrep -g "$1" 2>/dev/null | tr '\n' ' ')"; else echo dying; fi
    }
    iw_reap() { # <pgid> <refusal record>; 0 the group is gone, 1 a member read settled survived a later SIGKILL
      local g="$1" rec="$2" seen=" " st p s l
      # The first kill precedes the first read, so a group whose members all sleep before it is never read settled.
      kill -9 -- -"$g" 2>/dev/null
      while :; do
        st="$(${IW_GROUP_STATE:-iw_group_state} "$g")"
        case "$st" in
          gone) return 0 ;;
          missed*)
            l=""
            for p in ${st#missed}; do
              case "$seen" in *" $p "*)
                s="$(ps -o stat= -p "$p" 2>/dev/null | tr -d ' ')"; l="$l $p (${s:-state unreadable})" ;;
              esac
            done
            if [ -n "$l" ]; then
              printf 'BROKEN: iw_reap read group %s settled on both sides of a SIGKILL, and it still holds%s\n' "$g" "$l" >> "$rec"
              return 1
            fi
            for p in ${st#missed}; do seen="$seen$p "; done ;;
        esac
        kill -9 -- -"$g" 2>/dev/null
        [ "$st" = dying ] && sleep 0.1
      done
    }
    iw_run() { # <deriver copy> <stream list> <kill: yes|no> <map copy out>; prints "<rc or sigkill>|<reached fxw3>"
      local dv="$1" sl="$2" k="$3" out="$4" pid r at=no i=0 kf="" ga=0 gb=0
      cp "$dv" "$STUB_DERIVER"
      rm -f "$SX/kill" "$SX/kill.at" "${out%.tsv}.grp"
      [ "$k" = yes ] && { kf="$SX/kill"; : > "$kf"; }
      set -m
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$sl" STUB_KILLFLAG="$kf" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" -- core/scripts/derive-fixture-readsets.sh --list "fxw1 fxw2 fxw3" --tracer sandbox ) > "${out%.tsv}.out" 2>&1 </dev/null &
      pid=$!
      set +m
      if [ "$k" = yes ]; then
        # fxw3 REACHED, OR THE DERIVER GONE. A 60s tick count used to end this wait and score `at=no`, so
        # a deriver slowed past it by load read as a run that never reached fxw3. The net is no progress:
        # its output, the map and the trace root all unchanged for AW_STALL polls is a refusal.
        aw_wait '[ -e "$SX/kill.at" ]' 'printf %s "$pid"' ''
        [ -e "$SX/kill.at" ] && at=yes
        # PRESENCE FIRST: the recorded group answers before the kill, so a group never created cannot read as reaped.
        kill -0 -- -"$pid" 2>/dev/null && gb=1
        # GONE, ON A CONDITION, WITH NO BOUND: every member has taken SIGKILL once none answers, at any load.
        iw_reap "$pid" "$AW_STALL_LOG" && wait "$pid" 2>/dev/null; r=sigkill
        kill -0 -- -"$pid" 2>/dev/null && ga=1
        printf '%s|%s\n' "$gb" "$ga" > "${out%.tsv}.grp"
        rm -f "$SX/kill"
      else
        wait "$pid"; r=$?
      fi
      stub_reap "${SB:-}"
      cp "$BR/.ai-dlc-fixture-readsets.tsv" "$out"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s' "$r" "$at"
    }
    iw_sig() { # <map>; prints one 0/1 per row: fxw1 new, fxw1 old, fxw2 new, fxw2 old, fxw3 new, fxw3 old, then |<other rows>|<tmp files left>
      local m="$1" s="" row c t
      for row in 'fxw1	src/w1.sh' 'fxw1	src/OLD-1' 'fxw2	src/w2.sh' 'fxw2	src/OLD-2' 'fxw3	src/w3.sh' 'fxw3	src/OLD-3'; do
        c="$(grep -cxF "$row" "$m")" || c=0; s="$s$c"
      done
      c="$(grep -c '^other	' "$m")" || c=0
      t="$(find "$BR" -maxdepth 1 -name '.ai-dlc-fixture-readsets.tsv.tmp.*' | grep -c .)" || t=0
      printf '%s|%s|%s' "$s" "$c" "$t"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    IW="$(iw_run "$SB/deriver.sh" "$SX/fxw.list" yes "$WORK/iw.sigk.tsv")"
    aw_gate
    IWS="$(iw_sig "$WORK/iw.sigk.tsv")"
    if [ "$IW|$IWS" = "sigkill|yes|101001|2|0" ]; then
      ok "INTERRUPTED: a 3-fixture --list run SIGKILLed during fxw3 leaves a map holding fxw1's and fxw2's new rows, fxw3's old row, the untraced fixture's rows, and no temp file"
    else
      bad "INTERRUPTED: expected 'sigkill|yes|101001|2|0' (rc|reached fxw3|new/old rows fxw1..3|other rows|tmp files), got '$IW|$IWS' — $(tail -3 "$WORK/iw.sigk.out" | tr '\n' ' ')"
    fi
    # THE KILLED RUN'S GROUP IS EMPTY BEFORE IU STARTS (BL-900). The SIGKILLed run shares IU's trace root and feed,
    # so an orphan of it could read a marker in IU's fxw3 window. Presence-shaped on both sides: the recorded
    # group answered `kill -0` BEFORE its kill (1), so a group never created cannot pass as reaped, and none of it
    # answers AFTER the reap (0), read while fxw3's kill flag still holds its poller in the loop.
    TRACE_ARMS=$((TRACE_ARMS+1))
    IWG="$(cat "$WORK/iw.sigk.grp" 2>/dev/null)"
    if [ "$IWG" = "1|0" ]; then
      ok "INTERRUPTED GROUP: the interrupted run's recorded process group was alive before the kill and empty after the reap ('1|0', before|after), so no orphan reaches IU's trace root"
    else
      bad "INTERRUPTED GROUP: expected '1|0' (recorded group alive before the kill | alive after the reap), got '$IWG'"
    fi
    # The identity arm. The fix's run must have written per fixture and reached a map that MOVED (new
    # rows, fxw2's OLD row dropped, no OMITTED line in the map, fxw2 named OMITTED on stdout). The per-fixture call's output lands in $WORK/fxw1.write; it
    # prints the controls but no `wrote` line (that `say` follows only the final call), so the
    # evidence it ran is the discrimination control's PASS line, which precedes the write.
    TRACE_ARMS=$((TRACE_ARMS+1))
    IU="$(iw_run "$SB/deriver.sh" "$SX/fxw.omit.list" no "$WORK/iw.full.tsv")"
    IU_W="$(grep -c '^  PASS  CONTROL: ' "$SX_TR/w/fxw1.write" 2>/dev/null)" || IU_W=0
    IUS="$(iw_sig "$WORK/iw.full.tsv")"
    IUH="$(grep -c '^# OMITTED' "$WORK/iw.full.tsv")" || IUH=0
    IUV="$(grep -c ' OMITTED and therefore always run: fxw2$' "$WORK/iw.full.out")" || IUV=0
    if [ "$IU|$IU_W|$IUS|$IUH|$IUV" = "0|no|1|100010|2|0|0|1" ]; then
      ok "IDENTITY: an uninterrupted run that wrote after each fixture ends on a map holding fxw1's and fxw3's new rows, none of the old ones, the untraced fixture's rows and no OMITTED line, and names the mid-list fxw2 OMITTED on stdout"
    else
      bad "IDENTITY: expected '0|no|1|100010|2|0|0|1' (rc|reached fxw3|per-fixture controls|new/old rows fxw1..3|other rows|tmp files|OMITTED map lines|stdout OMITTED report), got '$IU|$IU_W|$IUS|$IUH|$IUV' — the fix run's omissions: $(grep -E '^  [a-z0-9_.-]+ +OMITTED \(' "$WORK/iw.full.out" | tr -s ' ' | tr '\n' ' ')"
    fi

    # THE DIGEST WRITER (BL-471), DRIVEN WHOLE. The BR runner carries only an FXROOT line, so it has no
    # READSET_UNIVERSE span: a --list run there writes NO `# digest` line and says so -- the fail-soft
    # direction, both arms of it. Then the runner gains the span, sed out of the resolved hook, and the
    # same run must write fxa's digest and CARRY other fixtures' digests through the merge:
    #   carried   a `# digest keep <sha>` line for an untraced fixture survives;
    #   replaced  fxa's stale seeded digest is gone and exactly one fxa digest is written;
    #   matches   the hook, sourced from the same span, recomputes fxa's digest over the tree and
    #             reads it `match` -- the producer and the consumer agree on the value;
    #   counted   the header's fixture count does not count a digest line as a fixture.
    TRACE_ARMS=$((TRACE_ARMS+1))
    printf 'other\tsrc/other.sh\nother\tcore/fixtures/other/run.sh\nkeep\tsrc/other.sh\n# digest keep 1111111111111111111111111111111111111111111111111111111111111111\n# digest fxa 2222222222222222222222222222222222222222222222222222222222222222\n' > "$BR/.ai-dlc-fixture-readsets.tsv"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm digests ) >/dev/null 2>&1 || broken "could not seed the digest map"
    dw_run() { # <deriver copy>; prints "<rc>|<keep digest>|<fxa digests>|<stale fxa digest>|<note>|<mapped count>"
      local r k a s n c
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$SX/whole.list" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" -- core/scripts/derive-fixture-readsets.sh --list fxa --tracer sandbox ) > "$WORK/dw.out" 2>&1 </dev/null
      r=$?
      stub_reap "${SB:-}"
      cp "$BR/.ai-dlc-fixture-readsets.tsv" "$WORK/dw.map"
      k="$(grep -c '^# digest keep 1111' "$WORK/dw.map")" || k=0
      a="$(grep -c '^# digest fxa [0-9a-f]\{64\}$' "$WORK/dw.map")" || a=0
      s="$(grep -c '^# digest fxa 2222' "$WORK/dw.map")" || s=0
      n="$(grep -c 'no # digest line written' "$WORK/dw.out")" || n=0
      c="$(sed -n 's/^# fixtures mapped: \([0-9]*\) .*/\1/p' "$WORK/dw.map")"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s|%s|%s|%s|%s' "$r" "$k" "$a" "$s" "$n" "$c"
    }
    DW0="$(dw_run "$SB/deriver.sh")"
    # mapped 3 (other, keep, fxa): a digest line counted as a fixture would read 5.
    if [ "$DW0" = "0|1|0|0|1|3" ]; then
      ok "DIGEST: under a runner with no READSET_UNIVERSE span a --list run writes NO # digest line, says so, drops fxa's stale digest and carries the untraced one"
    else
      bad "DIGEST: a span-less runner did not give rc 0, keep 1, fxa 0, stale 0, note 1, mapped 3: '$DW0' — $(tail -2 "$WORK/dw.out" | tr '\n' ' ')"
    fi
    sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' "$HOOK" >> "$BR/.githooks/pre-push"
    grep -q '^readset_digests() ' "$BR/.githooks/pre-push" || broken "the resolved hook carries no READSET_UNIVERSE span to seed the BR runner with"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm span ) >/dev/null 2>&1 || broken "could not commit the BR runner's span"
    TRACE_ARMS=$((TRACE_ARMS+1))
    DW1="$(dw_run "$SB/deriver.sh")"
    cp "$WORK/dw.map" "$WORK/dw.fix.map"
    sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' "$BR/.githooks/pre-push" > "$WORK/br.span"
    DW_V="$( cd "$BR" && cp "$WORK/dw.fix.map" .ai-dlc-fixture-readsets.tsv && s="$(mktemp -d "$WORK/dwm.XXXXXX")" \
      && READSET_MAP=.ai-dlc-fixture-readsets.tsv && READSET_LOCAL=/dev/null && . "$WORK/br.span" \
      && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_manifest "$s" && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_committed_digests "$s" && awk -F'\t' '$1 == "fxa" { print $2 }' "$s/.cdig"; git checkout -q -- . 2>/dev/null )"
    if [ "$DW1" = "0|1|1|0|0|3" ] && [ "$DW_V" = match ]; then
      ok "DIGEST: with the hook's span the run writes ONE fxa digest the hook recomputes as 'match', replaces the stale one, carries the untraced one, and counts 3 fixtures, not digest lines"
    else
      bad "DIGEST: expected '0|1|1|0|0|3' and fxa 'match', got '$DW1' / '$DW_V' — $(tail -2 "$WORK/dw.out" | tr '\n' ' ')"
    fi

    # A DECLARED FIXTURE GETS NO DIGEST (BL-897). The hook maps a fixture carrying inputs.decl before it reads the map,
    # so a `# digest` line for one is dead weight; the merge already drops its rows and its carried digest, and the
    # digests this run writes must pass the same filter. Two seeds in ONE --list run: fxd is DECLARED (its inputs.decl
    # committed into BR, so the trace copy carries it) and fxa is not. Both read src/a.sh, so the path is in the
    # runner's universe through fxa's row and fxd's digest IS computable: without the filter it is written. The commit is undone after the arm, so every later world sees BR as it was.
    mkdir -p "$BR/core/fixtures/fxd" || broken "mkdir failed"
    printf '#!/bin/bash\ncat src/a.sh >/dev/null\n' > "$BR/core/fixtures/fxd/run.sh"
    printf 'src/a.sh\n' > "$BR/core/fixtures/fxd/inputs.decl"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm declared ) >/dev/null 2>&1 || broken "could not commit the declared seed fxd"
    printf '%s\n' core/fixtures/fxa/run.sh core/fixtures/fxd/run.sh src/a.sh > "$SX/decl.list"
    dd_run() { # <deriver copy>; prints "<rc>|<fxa digests>|<fxd digests>|<keep digest>"
      local r a d k
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$SX/decl.list" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" -- core/scripts/derive-fixture-readsets.sh --list "fxa fxd" --tracer sandbox ) > "$WORK/dd.out" 2>&1 </dev/null
      r=$?
      stub_reap "${SB:-}"
      cp "$BR/.ai-dlc-fixture-readsets.tsv" "$WORK/dd.map"
      a="$(grep -c '^# digest fxa [0-9a-f]\{64\}$' "$WORK/dd.map")" || a=0
      d="$(grep -c '^# digest fxd [0-9a-f]\{64\}$' "$WORK/dd.map")" || d=0
      k="$(grep -c '^# digest keep 1111' "$WORK/dd.map")" || k=0
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s|%s|%s' "$r" "$a" "$d" "$k"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    DD="$(dd_run "$SB/deriver.sh")"
    if [ "$DD" = "0|1|0|1" ]; then
      ok "DIGEST DECLARED: one --list run tracing a declared fixture (fxd) and an undeclared one (fxa) that share src/a.sh writes fxa's digest and none for fxd, and carries the untraced one ('$DD' rc|fxa|fxd|keep)"
    else
      bad "DIGEST DECLARED: expected '0|1|0|1' (rc|fxa digests|fxd digests|keep), got '$DD' — $(tail -2 "$WORK/dd.out" | tr '\n' ' ')"
    fi
    ( cd "$BR" && git reset -q --hard HEAD^ ) >/dev/null 2>&1 || broken "could not undo the declared seed's commit in BR"
    [ ! -e "$BR/core/fixtures/fxd" ] || broken "the declared seed fxd is still in BR after the undo, so later worlds would see it"

    # `--declared-out` KEEPS A LOSS-ONLY WINDOW'S SET AS `#lower` ROWS, END TO END. fxa is declared here (its
    # inputs.decl committed into BR, undone after the arm) and traced on the lossy list: the stream reports run.sh
    # and a lone metadata stat, and loses fxa's src/a.sh read, which only the atime leg sees. Refused for loss
    # alone, the out file must carry fxa's `#omitted` row naming STAT LOSS AND a `#lower` row for src/a.sh, a path
    # the stream never reported. Its DENY twin is fxe, in the SAME run, one property apart: the same lossy window and
    # the same atime-only src/a.sh read, but it exits 1, a reason before the loss lines, so it must get its `#omitted`
    # row (naming the exit and STAT LOSS) and no `#lower` row.
    mkdir -p "$BR/core/fixtures/fxe" || broken "mkdir failed"
    printf '#!/bin/bash\ncat src/a.sh >/dev/null\nexit 1\n' > "$BR/core/fixtures/fxe/run.sh"
    printf 'src/a.sh\n' > "$BR/core/fixtures/fxe/inputs.decl"
    printf 'src/a.sh\n' > "$BR/core/fixtures/fxa/inputs.decl"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm declared-fxa-fxe ) >/dev/null 2>&1 || broken "could not commit fxa's and fxe's inputs.decl"
    cp "$SB/deriver.sh" "$STUB_DERIVER"; rm -f "$WORK/lo.out"
    ( cd "$BR" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$SX/lossy.list" \
        AI_DLC_READSET_TRACE_ROOT="$SX_TR" -- core/scripts/derive-fixture-readsets.sh --list "fxa fxe" --tracer sandbox --declared-out "$WORK/lo.out" ) > "$WORK/lo.log" 2>&1 </dev/null
    stub_reap "${SB:-}"
    ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
    LO_OM="$(grep -c '^fxa	#omitted	.*STAT LOSS: 1 metadata' "$WORK/lo.out" 2>/dev/null)" || LO_OM=0
    LO_A="$(grep -cxF "$(printf 'fxa\t#lower\tsrc/a.sh')" "$WORK/lo.out" 2>/dev/null)" || LO_A=0
    LO_R="$(grep -cxF "$(printf 'fxa\t#lower\tcore/fixtures/fxa/run.sh')" "$WORK/lo.out" 2>/dev/null)" || LO_R=0
    LO_EOM="$(grep -c '^fxe	#omitted	fixture exited 1; .*STAT LOSS: 1 metadata' "$WORK/lo.out" 2>/dev/null)" || LO_EOM=0
    LO_EL="$(grep -c '^fxe	#lower	' "$WORK/lo.out" 2>/dev/null)" || LO_EL=0
    TRACE_ARMS=$((TRACE_ARMS+1))
    if [ "$LO_OM" = 1 ] && [ "$LO_A" = 1 ] && [ "$LO_R" = 1 ]; then
      ok "LOWER END TO END: --declared-out on a window refused for loss alone writes fxa's #omitted row naming STAT LOSS and #lower rows for run.sh and for src/a.sh, the read only the atime leg saw"
    else
      bad "LOWER END TO END: expected 1|1|1 (#omitted naming STAT LOSS | #lower src/a.sh | #lower run.sh), got $LO_OM|$LO_A|$LO_R — $(tr '\t\n' '  ' < "$WORK/lo.out" 2>/dev/null | cut -c1-300) / $(tail -2 "$WORK/lo.log" | tr '\n' ' ')"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    if [ "$LO_EOM" = 1 ] && [ "$LO_EL" = 0 ]; then
      ok "LOWER DENY END TO END: in the same run, fxe (the same lossy window, but it exited 1) gets its #omitted row naming the exit and STAT LOSS, and no #lower row"
    else
      bad "LOWER DENY END TO END: expected 1|0 (fxe #omitted naming 'fixture exited 1' and STAT LOSS | fxe #lower rows), got $LO_EOM|$LO_EL — $(grep '^fxe' "$WORK/lo.out" 2>/dev/null | tr '\t\n' '  ' | cut -c1-300)"
    fi
    ( cd "$BR" && git reset -q --hard HEAD^ ) >/dev/null 2>&1 || broken "could not undo the fxa/fxe inputs.decl commit in BR"
    [ ! -e "$BR/core/fixtures/fxa/inputs.decl" ] && [ ! -e "$BR/core/fixtures/fxe" ] || broken "fxa's inputs.decl or fxe is still in BR after the undo, so later worlds would see them"

    # THE LOSS-ONLY TEST AND ITS NEAR-MISSES, one in-process pass of the deriver's READSET_LOWER span per call: a window
    # refused for loss alone (a) is the only one that keeps `#lower` rows; a reason BEFORE the loss lines (b), a
    # reason AFTER them (c), and no reason at all (d) do not. The writer handed a non-loss refusal writes its
    # `#omitted` row and no `#lower` row (w), the DENY twin of the end-to-end ALLOW above.
    LW_SPAN="$WORK/lower.sh"; LW_W="$WORK/lw"
    sed -n '/^# READSET_LOWER_BEGIN$/,/^# READSET_LOWER_END$/p' "$DERIVER" > "$LW_SPAN"
    mkdir -p "$LW_W" && printf 'src/a.sh\n' > "$LW_W/fxw.set" || broken "could not seed the READSET_LOWER world"
    LWO="$( . "$LW_SPAN"
      r=""
      fx_inproc "$DERIVER"; if readset_loss_only "" "STAT LOSS: 1" "STAT LOSS: 1"; then r="${r}a"; fi
      fx_inproc "$DERIVER"; if readset_loss_only "fixture exited 1" "fixture exited 1; STAT LOSS: 1" "fixture exited 1; STAT LOSS: 1"; then r="${r}b"; fi
      fx_inproc "$DERIVER"; if readset_loss_only "" "STAT LOSS: 1" "STAT LOSS: 1; empty read-set"; then r="${r}c"; fi
      fx_inproc "$DERIVER"; if readset_loss_only "" "" ""; then r="${r}d"; fi
      WORK="$LW_W" DECLARED_OUT="$LW_W/out"
      fx_inproc "$DERIVER"; rs_declared_write fxw "fixture exited 1" "" && r="${r}|$(grep -c '^fxw	#omitted	fixture exited 1$' "$LW_W/out")|$(grep -c '#lower' "$LW_W/out")"
      printf '%s' "$r" )" 2>/dev/null
    TRACE_ARMS=$((TRACE_ARMS+1))
    if [ "$LWO" = "a|1|0" ]; then
      ok "LOSS-ONLY TEST: only the loss-alone refusal keeps #lower rows (a); a reason before (b) or after (c) the loss lines, or none (d), does not; a non-loss refusal writes its #omitted row and no #lower row"
    else
      bad "LOSS-ONLY TEST: expected 'a|1|0' (cases kept | #omitted rows | #lower rows), got '$LWO' (span lines: $(grep -c . "$LW_SPAN"))"
    fi

    # `--local-map` WITH THE RUNNER'S READSET_UNIVERSE SPAN (BL-480), DRIVEN WHOLE. The local-map world above
    # runs before the BR runner gained the span (:3608), so it sees only the fallback. Here the runner carries
    # it, fxl's stream reports a read of the DIRECTORY src, and the local map must record that row by its
    # listing -- `fxl<TAB>src<TAB>#listing:<sha256>` -- which only a caller that hands readset_local_rows a
    # manifest of the trace copy can write.
    #
    # THE SHAPE ALONE CANNOT SEE A WRONG CALLER, so the arm also recomputes the value. A call site that
    # swaps `.now` and `.paths`, manifests another tree, or manifests after the loop still yields SOME
    # 64-hex listing. The oracle takes a manifest of $BR the way the deriver takes one of its trace copy
    # (the copy is gone by then -- --local-map traps its removal -- and $BR is the tree it was copied
    # from), lists `cut -f1 .now` through the same span, and the row must equal its `src/` value byte for
    # byte. THE GHOST ROW is the discriminating input for the swap: a committed map row naming a file
    # that is absent on disk enters `.paths` and never `.now`, so a listing taken off `.paths` gains
    # `ghost.sh`. Without it every BR path is a regular file, the two lists are identical, so a call
    # site that swapped them would pass.
    printf 'other\tsrc/ghost.sh\n' >> "$BR/.ai-dlc-fixture-readsets.tsv"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm ghost ) >/dev/null 2>&1 || broken "could not commit the ghost map row"
    [ ! -e "$BR/src/ghost.sh" ] || broken "src/ghost.sh exists on disk, so the ghost row cannot separate .paths from .now"
    printf '%s\n' core/fixtures/fxl/run.sh src/a.sh src > "$SL/dir.list"
    lmd_raw() { awk -F'\t' '$1 == "fxl" && $2 == "src" { print $3 }' "$LMF" 2>/dev/null; }
    lmd_row() { lmd_raw | sed 's/^\(#listing:\)[0-9a-f]\{64\}$/\1SHA/'; }
    TRACE_ARMS=$((TRACE_ARMS+1))
    lm_seed; LD="$(lm_run "$SL/deriver.sh" "$SL/dir.list" same)"; LD_ROW="$(lmd_row)"; LD_RAW="$(lmd_raw)"
    LD_WANT="$( cd "$BR" && s="$(mktemp -d "$WORK/ldm.XXXXXX")" \
      && READSET_MAP=.ai-dlc-fixture-readsets.tsv && READSET_LOCAL=/dev/null && . "$WORK/br.span" \
      && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_manifest "$s" && cut -f1 "$s/.now" > "$s/.p" && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_listings "$s/.p" "$s/ls" \
      && awk -F'\t' '$1 == "src/" { print $2 }' "$s/ls" )"
    case "$LD_WANT" in
      '#listing:'[0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) [ "${#LD_WANT}" -eq 73 ] || broken "the LOCAL oracle's src/ listing is not '#listing:' plus 64 hex: '$LD_WANT'" ;;
      *) broken "the LOCAL oracle produced no src/ listing: '$LD_WANT'" ;;
    esac
    case "$LD|$LD_ROW" in
      "0|3|yes|"*"|#listing:SHA")
        if [ "$LD_RAW" = "$LD_WANT" ]; then
          ok "LOCAL: with the runner's UNIVERSE span a --local-map trace records the directory src as 'fxl	src	#listing:<sha256>', byte-identical to the listing of the tree's own manifest"
        else
          bad "LOCAL: the src row has the listing SHAPE but not the tree's listing: row '$LD_RAW', oracle '$LD_WANT'"
        fi ;;
      *) bad "LOCAL: expected a '#listing:<sha256>' row for src from a 3-row clean trace, got '$LD' row '$LD_ROW' — $(tail -2 "$WORK/lm.out" | tr '\n' ' ')" ;;
    esac
  fi
    if [ -d "${SB:-/nonexistent}" ] || [ -d "${SL:-/nonexistent}" ]; then

    # ---- STUB REAP: every stub process a stub world starts is recorded by pid and reaped by pid. ----
    # The `log stream` stand-in (`exec tail -n 0 -f`) and the stub fs_usage run OUTSIDE slot-world.sh, which
    # reaps by process group. The deriver kills its stream on its normal paths only, and an exit it does not
    # trap (a SIGKILL, a die between the start and the kill) leaves the stub at ppid 1. Each stub appends $$ to
    # <world>/pids before its exec; stub_reap, called after every deriver invocation, kills those pids and
    # logs "<recorded> <live>" to <world>/reap.log. The two worlds are $SB (bothstub: also driven through
    # sbx_run, omit_run, all_run, unread_run, iw_run and dw_run) and $SL (lmstub: lm_run, fg_run, ip_run,
    # mp_run and the lmwt worlds). A process-table grep proves nothing here: liveness is `kill -0` on the
    # RECORDED pid. The pid files live under $WORK because the hermetic run is `env -i`.
    reap_world() { # <label> <world dir>
      local d="$2" inv rec live
      inv="$(grep -c . "$d/reap.log" 2>/dev/null)" || inv=0
      rec="$(grep -c . "$d/pids.all" 2>/dev/null)" || rec=0
      live="$(awk '{ s += $2 } END { print s + 0 }' "$d/reap.log" 2>/dev/null)"
      TRACE_ARMS=$((TRACE_ARMS+1))
      if [ "$inv" -gt 0 ] && [ "$rec" -gt 0 ] && [ "$live" = 0 ]; then
        ok "REAP $1: $inv deriver invocations, $rec stub pid(s) recorded in $d/pids.all, 0 live after the reap (kill -0 fails on every recorded pid)"
      else
        bad "REAP $1: $inv invocations, $rec recorded stub pid(s) in $d/pids.all, $live live after the reap — a stub outlived its world, or none was recorded so the arm saw nothing"
      fi
    }
    [ -n "${SB:-}" ] && [ -d "$SB" ] && reap_world "bothstub" "$SB"
    [ -n "${SL:-}" ] && [ -d "$SL" ] && reap_world "lmstub" "$SL"
    # The reap arm must be able to FAIL: a stub left running by its starter is recorded and reaped. The probe
    # world holds a copy of the stub, so its pid file is its own.
    RM="$WORK/reapprobe"; mkdir -p "$RM" || broken "mkdir failed"
    cp "${SB:-/nonexistent}/logstream" "$RM/logstream" 2>/dev/null || cp "${SL:-/nonexistent}/logstream" "$RM/logstream" || broken "no logstream stub to probe the reap with"
    : > "$RM/feed"
    reap_drive() { # prints "<recorded>|<live>" for one stub its starter left running
      local i rec live
      : > "$RM/pids"
      ( STUB_FEED="$RM/feed" "$RM/logstream" </dev/null >/dev/null 2>&1 & )
      # THE STUB'S OWN RECORD, ON A CONDITION WITH NO BOUND (BL-868): a 50-poll cap read a stub slow to start as
      # one never recorded ('0|0'). A stub that never records hangs until the gate's watchdog, never a verdict.
      until [ -s "$RM/pids" ]; do sleep 0.1; done
      stub_reap "$RM"
      rec="$(grep -c . "$RM/pids.last")" || rec=0
      live="$(stub_live "$RM/pids.last")"
      while read -r i; do [ -n "$i" ] && kill "$i" 2>/dev/null; done < "$RM/pids.last"
      printf '%s|%s' "$rec" "$live"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    RP_C="$(reap_drive)"
    if [ "$RP_C" = "1|0" ]; then ok "REAP probe: one stub left running by its starter is recorded (1) and reaped (0 live): '$RP_C'"
    else bad "REAP probe: expected '1|0' (recorded|live), got '$RP_C'"; fi
    fi
  fi
fi

# ------------------------------------------- per-fixture checksum keys (contract k1) ----
# THE SKIP IS PER FIXTURE: F is skipped iff its record `<gitdir>/ai-dlc-fixture-keys/F.key` exists,
# carries `#format k1`, is not `#state stale`, and every key in it still matches. Each world below
# drives the REAL call site, run_fixtures, in a fresh seeded repo, and reads which fixtures actually
# RAN off a log each seeded run.sh appends to -- presence-shaped, so a pool that ran nothing and a
# pool that skipped everything are told apart by the record files and the announce line.
#
# THE LOG AND THE CONTROL FILES LIVE OUTSIDE THE TREE. K(F) holds every file under F's own
# directory, so a marker written inside it would move the key under test. The env names carry no
# AI_DLC_ prefix because this fixture scrubs that prefix at its top.
#
# THE FIRST RESOLVED HOOK, AND ONE WIRING WORLD ON THE SECOND. Every world runs against the first
# candidate at the top of this file that exists; the second hook's FIXTURE_POOL block is held
# code-identical to the first's by I66 (scripts/validate-enforcement-map.sh) after comment strip, with
# the fixture root the one mapped difference, so it runs one world, (d), end to end with its own root.
# Every world is scored as ONE vector of cells against a want string.
#
# Dispatch is pinned to one worker (AI_DLC_FIXTURE_JOBS=1 on the drive) because world (l) kills a
# worker: BSD xargs stops dispatching when an invocation dies by signal, so the fixture after the
# killed one has no verdict -- which is the no-verdict half of (l), deterministic only serially.
CK_ARMS=0
CK_W="$WORK/ck"; mkdir -p "$CK_W" || broken "could not create the checksum-key worlds"
# CK_HELPERS_BEGIN -- the helpers the ck, tk and dg worlds share.
ck_sha() { shasum -a 256 -- "$1" | cut -d' ' -f1; }
# THE SEED IS BUILT ONCE PER SHAPE AND COPIED. A shape is (fixture root, extra fixture); ck_seed_build writes
# the git world into a template under $CK_W the first time a shape is asked for, and every later ck_seed of
# that shape is a `cp -Rp` of the template and its `.ctl` and `.bin` siblings. Each copy carries its OWN
# `.git` -- cp copies the directory, it does not link it -- and the separation is asserted by the (seedcopy)
# arm in ckw, which commits in one copy and reads the other's HEAD unmoved. A copy refuses a target that
# already exists, because `cp -R tpl t` onto an existing t nests the template inside it.
ck_seed() { # <t> <fixture root> [extra fixture]: alpha, beta, delta mapped; the extra one unmapped
  local t="$1" tp="$CK_W/tpl.$(printf '%s.%s' "$2" "${3:-}" | tr -c 'A-Za-z0-9._-' '_')"
  [ -d "$tp/.git" ] || ck_seed_build "$tp" "$2" "${3:-}" || return 1
  [ ! -e "$t" ] && [ ! -e "$t.ctl" ] && [ ! -e "$t.bin" ] || return 1
  cp -Rp "$tp" "$t" && cp -Rp "$tp.ctl" "$t.ctl" && cp -Rp "$tp.bin" "$t.bin"
}
ck_seed_build() { # <t> <fixture root> [extra fixture]: the template ck_seed copies
  local t="$1" x="$2" f
  mkdir -p "$t/src/d" "$t/src/e" "$t.ctl" || return 1
  for f in alpha beta delta ${3:-}; do
    mkdir -p "$t/$x/$f" || return 1
    printf '%s\n' "printf '%s\\n' $f >> \"\$CK_LOG\"" \
      "[ -f \"\$CK_CTL/kill.$f\" ] && kill -9 \$PPID" \
      "[ -f \"\$CK_CTL/fail.$f\" ] && exit 1" 'exit 0' > "$t/$x/$f/run.sh" || return 1
  done
  for f in a b c; do printf 'v1\n' > "$t/src/$f.sh"; done
  # TOOLS ARE KEYED PER FIXTURE: each word of a keyed `.sh` file that resolves on PATH is a key row
  # `<abs path>\t<sha of its content>`. Two shims outside the tree, first on PATH for every push:
  # `cktool` is named only by src/shared.sh, which alpha alone reads; `ckall` by src/all.sh, which
  # every mapped fixture reads. Growing a shim moves exactly the fixtures whose files name it.
  printf 'cktool v1\n' > "$t/src/shared.sh"; printf 'ckall v1\n' > "$t/src/all.sh"
  mkdir -p "$t.bin" || return 1
  for f in cktool ckall; do printf '#!/bin/sh\nexit 0\n' > "$t.bin/$f" && chmod +x "$t.bin/$f" || return 1; done
  printf '1\n' > "$t/src/d/one.txt"; printf '1\n' > "$t/src/e/one.txt"
  # beta names the DIRECTORY src/d, so its key carries a listing; nobody names src/e.
  printf 'alpha\tsrc/a.sh\nalpha\tsrc/shared.sh\nalpha\tsrc/all.sh\nbeta\tsrc/b.sh\nbeta\tsrc/d\nbeta\tsrc/all.sh\ndelta\tsrc/c.sh\ndelta\tsrc/all.sh\n' \
    > "$t/.ai-dlc-fixture-readsets.tsv"
  ( cd "$t" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
}
ck_push() { # <pool> <t> <tag>: one push's suite. Leaves <t>.o.<tag>/{out,rc,ran}
  local o="$2.o.$3"
  mkdir -p "$o" && : > "$o/log" || return 1
  ( cd "$2" || exit 1
    export CK_LOG="$o/log" CK_CTL="$2.ctl" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_JOBS=1 PATH="$2.bin:$PATH"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$1" 2>/dev/null
    # THE TOOL DIRS ARE THE BLOCK'S OWN FIXED LIST, NEVER PATH: the shim dir stands in for it, and an
    # exec-path stand-in that does not exist keeps the real git out of these worlds.
    READSET_TOOL_DIRS="$2.bin"; READSET_TOOL_XP="$2.xp"; printf '%s\n' "${POOL_STALL:-}" > "$o/stall"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    run_fixtures > "$o/out" 2>&1; echo "$?" > "$o/rc" )
  LC_ALL=C sort "$o/log" | tr '\n' ' ' | sed 's/ $//' > "$o/ran"
}
ck_r()   { printf '%s|%s' "$(cat "$1.o.$2/ran" 2>/dev/null)" "$(cat "$1.o.$2/rc" 2>/dev/null)"; }
ck_k()   { printf '%s/.git/ai-dlc-fixture-keys/%s.key' "$1" "$2"; }
ck_st()  { sed -n 2p "$(ck_k "$1" "$2")" 2>/dev/null; }
ck_has() { local f s=""; for f in alpha beta delta; do [ -f "$(ck_k "$1" "$f")" ] && s="$s $f"; done; printf '%s' "${s# }"; }
ck_ln()  { grep -cxF -- "$3" "$1.o.$2/out" 2>/dev/null; }
# CK_HELPERS_END
# THE WORLD DEFINITIONS BELOW ARE UNGUARDED: they are function and variable definitions that run nothing until a
# ck unit (ckw, ckm1, ckm2, ckm3) calls them, so every unit finds the same helpers, worlds and hook blocks.
CK_A0='   ..    read-set keys: 0 of 3 fixture(s) run (0 changed, 0 unrecorded, 0 stale); skipping 3'

# (a) record on pass, then skip on an unchanged rerun. Pins the record format and the announce.
ck_w_a() { local p="$1" x="$2" t="$3" k
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; ck_push "$p" "$t" 2; k="$(ck_k "$t" alpha)"
  # The own-directory row belongs to (d) and the listing row to (c); asserting them here as well
  # would entangle the worlds.
  printf 'p1=%s p2=%s hdr=%s tools=%s trow=%s row=%s sorted=%s ann=%s' "$(ck_r "$t" 1)" "$(ck_r "$t" 2)" \
    "$(sed -n '1,3p' "$k" 2>/dev/null | tr '\n' ',')" \
    "$(grep -cxF "$t.bin/cktool	$(ck_sha "$t.bin/cktool")" "$k" 2>/dev/null)" \
    "$( { grep -cE '^/[^	]*	[0-9a-f]{64}$' "$k" 2>/dev/null | grep -qvx 0; } && echo y || echo n)" \
    "$(grep -cxF "src/a.sh	$(ck_sha "$t/src/a.sh")" "$k" 2>/dev/null)" \
    "$( { [ -f "$k" ] && grep -v '^#' "$k" | LC_ALL=C sort -c; } >/dev/null 2>&1 && echo y || echo n)" \
    "$(ck_ln "$t" 2 "$CK_A0")"
}
CK_WANT_a='p1=alpha beta delta|0 p2=|0 hdr=#format k1,#state ok,#tools canonical, tools=1 trow=y row=1 sorted=y ann=1'

# (b) a read-set file change reruns F and skips the unrelated ones.
ck_w_b() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/b.sh"; ck_push "$p" "$t" 2
  printf 'p2=%s ann=%s why=%s' "$(ck_r "$t" 2)" \
    "$(ck_ln "$t" 2 '   ..    read-set keys: 1 of 3 fixture(s) run (1 changed, 0 unrecorded, 0 stale); skipping 2')" \
    "$(ck_ln "$t" 2 '   ..      beta: changed src/b.sh')"
}
CK_WANT_b='p2=beta|0 ann=1 why=1'

# (c) a new file in a directory F lists reruns F; a new file in a directory nobody lists does not.
# Elsewhere first, so the listed push is not confounded by a stale record.
ck_w_c() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf '2\n' > "$t/src/e/two.txt"; ck_push "$p" "$t" 2
  printf '2\n' > "$t/src/d/two.txt"; ck_push "$p" "$t" 3
  printf 'p2=%s p3=%s' "$(ck_r "$t" 2)" "$(ck_r "$t" 3)"
}
CK_WANT_c='p2=|0 p3=beta|0'

# (d) a file under F's own directory that no read set names reruns F only.
ck_w_d() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'x\n' > "$t/$x/alpha/extra.txt"; ck_push "$p" "$t" 2
  printf 'p2=%s' "$(ck_r "$t" 2)"
}
CK_WANT_d='p2=alpha|0'

# (e) an unmapped G keys on the whole universe: it skips only while nothing changed.
ck_w_e() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" gamma || { printf SEED; return; }
  ck_push "$p" "$t" 1; ck_push "$p" "$t" 2; printf 'v2\n' > "$t/src/c.sh"; ck_push "$p" "$t" 3
  printf 'p1=%s p2=%s p3=%s why=%s' "$(ck_r "$t" 1)" "$(ck_r "$t" 2)" "$(ck_r "$t" 3)" \
    "$(ck_ln "$t" 3 '   ..      gamma: unmapped: closure changed')"
}
CK_WANT_e='p1=alpha beta delta gamma|0 p2=|0 p3=delta gamma|0 why=1'

# (f) one fixture fails: the passes are still recorded, and the next push reruns only the failed
# fixture plus the changed one.
ck_w_f() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  : > "$t.ctl/fail.beta"; ck_push "$p" "$t" 1; local h1; h1="$(ck_has "$t")"
  rm -f "$t.ctl/fail.beta"; printf 'v2\n' > "$t/src/c.sh"; ck_push "$p" "$t" 2
  printf 'p1=%s keys=%s p2=%s' "$(ck_r "$t" 1)" "$h1" "$(ck_r "$t" 2)"
}
CK_WANT_f='p1=alpha beta delta|1 keys=alpha delta p2=beta delta|0'

# (g) a change to a tool every fixture's files name reruns every recorded fixture as `tools changed`,
# and does NOT stale them (lead ruling 1): `ckall` gains a line, so its content sha moves while no
# tree file does.
ck_w_g() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf '# grown\n' >> "$t.bin/ckall"; ck_push "$p" "$t" 2
  printf 'p2=%s why=%s st=%s' "$(ck_r "$t" 2)" "$(ck_ln "$t" 2 '   ..      beta: tools changed')" "$(ck_st "$t" beta)"
}
CK_WANT_g='p2=alpha beta delta|0 why=1 st=#state ok'

# (n) tools are keyed PER FIXTURE: a change to `cktool`, which only alpha's files name, leaves beta
# and delta skipped. Scored on the two that must NOT run, so a hook that reruns nothing on a tool
# change is (g)'s failure, not this one's.
ck_w_n() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf '# grown\n' >> "$t.bin/cktool"; ck_push "$p" "$t" 2
  printf 'others=%s rc=%s' "$(tr ' ' '\n' < "$t.o.2/ran" | grep -cxE 'beta|delta')" "$(cat "$t.o.2/rc" 2>/dev/null)"
}
CK_WANT_n='others=0 rc=0'

# (h) stale: alpha reran on a moved FILE key and is recorded stale; it runs again on the next push
# with nothing changed; once a trace replaces its rows with valid local rows, it skips. The trace is
# what the deriver records: `<F>\t<path>\t<sha>` rows plus `<F>\t#deriver\t<sha of the deriver>`,
# so the seed carries a tracked deriver for readset_deriver_path to resolve and hash.
ck_w_h() { local p="$1" x="$2" t="$3" ds
  ck_seed "$t" "$x" || { printf SEED; return; }
  mkdir -p "$t/core/scripts" && printf '#!/bin/bash\nexit 0\n' > "$t/core/scripts/derive-fixture-readsets.sh" \
    && ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm deriver ) >/dev/null 2>&1 || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2; local s2; s2="$(ck_st "$t" alpha)"
  ck_push "$p" "$t" 3; local s3; s3="$(ck_st "$t" alpha)"
  ds="$(ck_sha "$t/core/scripts/derive-fixture-readsets.sh")"
  { printf 'alpha\tsrc/a.sh\t%s\n' "$(ck_sha "$t/src/a.sh")"
    printf 'alpha\tsrc/shared.sh\t%s\n' "$(ck_sha "$t/src/shared.sh")"
    printf 'alpha\t#deriver\t%s\n' "$ds"; } > "$t/.git/ai-dlc-fixture-readsets.local"
  # The push straight after the trace SKIPS alpha (BL-471, D1): its local rows are valid and no key in
  # its record moved, so the stale record is republished `#state ok` without a run; the push after that
  # skips it too. Before BL-471 the traced push ran alpha once to rekey it.
  ck_push "$p" "$t" 4; local s4; s4="$(ck_st "$t" alpha)"; ck_push "$p" "$t" 5
  printf 'p2=%s s2=%s p3=%s why=%s s3=%s p4=%s s4=%s p5=%s' "$(ck_r "$t" 2)" "$s2" "$(ck_r "$t" 3)" \
    "$(ck_ln "$t" 3 '   ..      alpha: stale')" "$s3" "$(ck_r "$t" 4)" "$s4" "$(ck_r "$t" 5)"
}
CK_WANT_h='p2=alpha|0 s2=#state stale p3=alpha|0 why=1 s3=#state stale p4=|0 s4=#state ok p5=|0'

# (m) THE SUBTREE WALK: a walker that keys the fixture root is republished `#state ok` when a sibling
# fixture directory X appears (a listing change never stales, lead ruling 2), and the entries added
# are NOT walked into its keys because X is a fixture, not an input (0.748.0, BL-482). The cell that
# needs grow()'s subtree walk is a NON-fixture directory appearing under a directory the walker
# lists: here `src/d/sub` under src/d, which beta lists. A new directory inside a listed directory is
# walked into beta's keys so a later edit under it reruns beta; (p3=1). Which fixtures run on the sibling push is (o)'s subject; which run on a plain new
# file is (c)'s; neither is scored here.
ck_w_m() { local p="$1" x="$2" t="$3" k
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1
  mkdir -p "$t/src/d/sub" && printf '1\n' > "$t/src/d/sub/n.txt"; ck_push "$p" "$t" 2
  k="$(ck_k "$t" beta)"; local st row; st="$(ck_st "$t" beta)"; row="$(grep -cxF "src/d/sub/n.txt	$(ck_sha "$t/src/d/sub/n.txt")" "$k" 2>/dev/null)"
  printf '2\n' > "$t/src/d/sub/n.txt"; ck_push "$p" "$t" 3
  printf 'p2=%s st=%s row=%s p3=%s' "$(grep -cx beta "$t.o.2/log")" "$st" "$row" "$(grep -cx beta "$t.o.3/log")"
}
CK_WANT_m='p2=1 st=#state ok row=1 p3=1'

# (o) THE SIBLING EXCLUSION, owned alone: a walker that keys the fixture root SKIPS on the push that
# adds a sibling fixture directory X (p2=0), is republished `#state ok` with the new root listing
# (sib=1, the hook's own message), does not carry X's files as keys (row=0), and stays skipped on a
# later edit to X/run.sh alone (p4=0).
ck_w_o() { local p="$1" x="$2" t="$3" k
  ck_seed "$t" "$x" walker || { printf SEED; return; }
  printf 'walker\t%s\n' "$x" >> "$t/.ai-dlc-fixture-readsets.tsv"
  ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm walker ) >/dev/null 2>&1 || { printf SEED; return; }
  ck_push "$p" "$t" 1
  mkdir -p "$t/$x/newfx" && sed 's/walker/newfx/g' "$t/$x/walker/run.sh" > "$t/$x/newfx/run.sh"
  ck_push "$p" "$t" 2; k="$(ck_k "$t" walker)"
  local st row sib; st="$(ck_st "$t" walker)"; row="$(grep -cxF "$x/newfx/run.sh	$(ck_sha "$t/$x/newfx/run.sh")" "$k" 2>/dev/null)"
  sib="$(grep -c 'read-set listings: 1 record(s) skipped on a fixture-root listing' "$t.o.2/out" 2>/dev/null)"
  ck_push "$p" "$t" 3
  printf '# edited\n' >> "$t/$x/newfx/run.sh"; ck_push "$p" "$t" 4
  printf 'p2=%s st=%s row=%s sib=%s p3=%s p4=%s' "$(grep -cx walker "$t.o.2/log")" "$st" "$row" "$sib" "$(grep -cx walker "$t.o.3/log")" "$(grep -cx walker "$t.o.4/log")"
}
CK_WANT_o='p2=0 st=#state ok row=0 sib=1 p3=0 p4=0'

# (i) seed: a v2 whole-tree record and no key files. The v2 record is what the hook's own manifest
# writes on a green run -- `.now` copied, `v2` stamped. AFTER it is taken, alpha's input changes and
# a file appears in src/d, the directory beta lists: only a listing derived from the v2 PATH SET sees
# that entry as new, so beta running is the cell that separates it from a listing taken from now.
ck_w_i() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  ( cd "$t" && mkdir -p "$t.v2" && fx_inproc "$ROOT/core/git-hooks/pre-push" && . "$p" 2>/dev/null && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_manifest "$t.v2" \
    && [ -s "$t.v2/.now" ] && cp "$t.v2/.now" .git/ai-dlc-fixture-verified && printf 'v2\n' > .git/ai-dlc-fixture-verified.format ) \
    || { printf V2SEED; return; }
  # A new DIRECTORY entry, not a file: so this world stays independent of (c)'s
  # file-entry listing.
  printf 'v2\n' > "$t/src/a.sh"; mkdir -p "$t/src/d/sub" && printf '2\n' > "$t/src/d/sub/two.txt"; ck_push "$p" "$t" 1
  printf 'p1=%s delta=%s' "$(ck_r "$t" 1)" "$(ck_st "$t" delta)"
}
CK_WANT_i='p1=alpha beta|0 delta=#state seeded'

# (k) a record with no `#format k1` line is no record: that ONE fixture runs, not everything.
# And a `#pending` line whose value is not a non-negative integer reads as no `#pending` line, which is never a
# run reason: beta's is EMPTY and delta's is `x1`, so each SKIPS on its recorded pass and the push names the two
# as "count unrecorded" (never a zero). Both records are otherwise the hook's own push-1 records.
ck_w_k() { local p="$1" x="$2" t="$3" k
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; k="$(ck_k "$t" alpha)"
  # A WRONG format line, not a deleted one: with line 1 gone the reader's FNR==1 consumes `#state`,
  # and the record reads as unrecorded whether or not the format is checked.
  sed '1s/.*/#format k0/' "$k" > "$k.ed" && mv "$k.ed" "$k"
  for k in beta:'#pending ' delta:'#pending x1'; do
    sed "4s/^#pending .*/${k#*:}/" "$(ck_k "$t" "${k%%:*}")" > "$t.ed" && mv "$t.ed" "$(ck_k "$t" "${k%%:*}")"
    [ "$(sed -n 4p "$(ck_k "$t" "${k%%:*}")")" = "${k#*:}" ] || { printf PSEED; return; }
  done
  ck_push "$p" "$t" 2
  printf 'p2=%s why=%s pu=%s' "$(ck_r "$t" 2)" "$(ck_ln "$t" 2 '   ..      alpha: unrecorded')" \
    "$(ck_ln "$t" 2 '   PENDING: 2 skipped on a recorded pass whose PENDING count is unrecorded (count unrecorded: recorded before counts were kept, or seeded)')"
}
CK_WANT_k='p2=alpha|0 why=1 pu=1'

# (l) a killed fixture (beta) and one left with no verdict (delta, never dispatched once xargs saw a
# signal) are not recorded. That the pass before them IS recorded belongs to (f).
ck_w_l() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  : > "$t.ctl/kill.beta"; ck_push "$p" "$t" 1
  printf 'p1=%s bad=%s' "$(ck_r "$t" 1)" "$(ck_has "$t" | tr ' ' '\n' | grep -cxE 'beta|delta')"
}
CK_WANT_l='p1=alpha beta|1 bad=0'

CK_WORLDS="a b c d e f g h i k l m n o"
ck_all() { # <pool> <fixture root> <tag>: every world, vectors at $CK_W/<tag>.<w>.got
  local w
  for w in $CK_WORLDS; do "ck_w_$w" "$1" "$2" "$CK_W/$3.$w" > "$CK_W/$3.$w.got" 2>/dev/null; done
}
ck_want() { eval "printf '%s' \"\$CK_WANT_$1\""; }

CK_N=0
for _h in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$_h" ] || continue
  CK_N=$((CK_N+1)); CK_P="$CK_W/pool.$CK_N.sh"
  pool_span "$_h" "$CK_P" FIXTURE_POOL && rs_rec_pin >> "$CK_P"
  CK_X="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$CK_P" | sort -u)"
  [ "$(printf '%s\n' "$CK_X" | grep -c .)" -eq 1 ] || broken "read '$CK_X' as ${_h#"$ROOT"/}'s fixture root; need exactly one"
  eval "CK_H$CK_N=\"\$_h\"; CK_PP$CK_N=\"\$CK_P\"; CK_XX$CK_N=\"\$CK_X\""
  [ "$CK_N" -eq 1 ] && { CK_P1="$CK_P"; CK_X1="$CK_X"; }
done
# ckw: every world against the FIRST resolved hook, plus ONE wiring world against the second.
# THE SECOND HOOK'S POOL BLOCK IS NOT RE-DRIVEN THROUGH ALL FOURTEEN WORLDS, because invariant I66 in
# scripts/validate-enforcement-map.sh already fails the push when the two FIXTURE_POOL blocks differ in any
# executable line after comment strip, with the fixture root (core/fixtures/ against tests/fixtures/) the one
# mapped difference. Fourteen worlds over code I66 holds identical buy no information; what I66 cannot see is
# whether that one permitted difference WORKS, so world (d) -- which writes under the fixture root itself,
# `$x/alpha/extra.txt`, and must rerun alpha alone -- runs end to end against the second hook with the root
# read off that hook's own block. On a consumer only one hook exists and the wiring arm does not run.
if sg ckw; then
  if [ "$CK_N" -ge 1 ]; then
    ck_all "$CK_P1" "$CK_X1" h1
    for _w in $CK_WORLDS; do
      CK_ARMS=$((CK_ARMS+1)); _g="$(cat "$CK_W/h1.$_w.got")"
      if [ "$_g" = "$(ck_want "$_w")" ]; then ok "($_w) ${CK_H1#"$ROOT"/}: $_g"
      else bad "($_w) ${CK_H1#"$ROOT"/}: want '$(ck_want "$_w")' got '$_g'"; fi
    done
  fi
  if [ "$CK_N" -ge 2 ]; then
    CK_ARMS=$((CK_ARMS+1)); _g="$(ck_w_d "$CK_PP2" "$CK_XX2" "$CK_W/h2.d" 2>/dev/null)"
    if [ "$_g" = "$CK_WANT_d" ] && [ -f "$CK_W/h2.d/$CK_XX2/alpha/extra.txt" ] && [ "$CK_XX2" != "$CK_X1" ]; then
      ok "(d, wiring) ${CK_H2#"$ROOT"/} runs its pool block with its own fixture root '$CK_XX2/': $_g"
    else bad "(d, wiring) ${CK_H2#"$ROOT"/} with root '$CK_XX2/' (first hook's '$CK_X1/'): want '$CK_WANT_d' got '$_g'"; fi
  fi
  # (seedcopy) THE SEED COPIES DO NOT SHARE A `.git`. Two copies of one shape; a commit in the first must leave
  # the second's HEAD where the template put it, and the positive conjunct is that the first's HEAD DID move.
  CK_ARMS=$((CK_ARMS+1))
  if ck_seed "$CK_W/sc.1" "$CK_X1" && ck_seed "$CK_W/sc.2" "$CK_X1"; then
    _s0="$(git -C "$CK_W/sc.2" rev-parse HEAD 2>/dev/null)"
    printf 'x\n' > "$CK_W/sc.1/src/a.sh"
    git -C "$CK_W/sc.1" -c user.email=f@f -c user.name=f commit -qam moved >/dev/null 2>&1
    _s1="$(git -C "$CK_W/sc.1" rev-parse HEAD 2>/dev/null)"; _s2="$(git -C "$CK_W/sc.2" rev-parse HEAD 2>/dev/null)"
    if [ -n "$_s0" ] && [ "$_s2" = "$_s0" ] && [ -n "$_s1" ] && [ "$_s1" != "$_s0" ] && [ "$(cat "$CK_W/sc.2/src/a.sh")" = v1 ]; then
      ok "(seedcopy) two copies of one seed template carry separate .git dirs: a commit in one moved its HEAD and left the other's"
    else bad "(seedcopy) seed copies are not separate: HEAD before '$_s0', committed copy '$_s1', other copy '$_s2'"; fi
  else bad "(seedcopy) could not seed two copies of one template"; fi
  CK_ARMS=$((CK_ARMS+1))
  [ "$CK_N" -ge 1 ] && ok "the checksum-key worlds ran against the first of $CK_N hook(s)" || bad "no pre-push hook was found for the checksum-key worlds"
fi


# ------------------------------------ a DECLARED fixture's stale record is decided on its keys ----
# A fixture carrying `inputs.decl` has its declaration as its read set, so a record reading `#state stale`
# must not force a run: stale means "re-trace", and a declared fixture has no trace. Before this, the
# decision forced every stale declared fixture to run and wrote the record back stale, so it never left.
# Driven through the REAL decision (apply_readset_skip) in a process of its own, reading `.kdec` -- no
# fixture runs, so the hermetic runner is not involved. Cells, one world, one vector:
#   dsame  declared `decl`, record stale, no declared input moved       -> skip, c `v`, republished ok
#   unrel  the same, but an input NOBODY declared moved                 -> skip
#   dchg   the same, but the declared src/a.sh moved                    -> run, changed src/a.sh
#   rchg   the same, but one byte INSIDE the HR_SANDBOX span of the runner core/scripts/hermetic-run.sh, which decl
#          does NOT declare, moved -> run: every declared key carries the runner's span sha (a placeholder here,
#          never executed -- this world only decides). Without that row it reads skip.
#   rout   the same, but a code line added OUTSIDE that span and before the exit mapping (the HR_EXIT row) -> skip:
#          the key carries the span and the exit mapping, never the whole runner
#   dnar   the same, but decl's inputs.decl NARROWED from src/a.sh + src/b.sh to src/a.sh, every path still keyed ->
#          run, changed <root>decl/inputs.decl: a narrowing runs once (dsame is its skip twin on the same record)
#   dmode  decl's record carries `#modes v1`, and src/a.sh, which it keys, turns executable -> run, c `x`: a mode change
#          outranks the stale skip (dsame is its twin on the same record)
#   badopt the same push: beta's record has its `#modes v1` line stripped, nothing beta keys moved -> skip, c `a`, the
#          header-less record adopts (beta, same record WITH the header, is its plain-skip twin)
#   dempty the declared fixture's stale record holds NO key rows        -> run (a missing stored key is changed)
#   ctl    UNDECLARED alpha, record stale, nothing moved                -> run, reason stale (the near-miss)
#   beta   undeclared and ok in the same invocation                     -> skip (proves the driver decided)
if sg ckw && true; then
CKD_DRV="$WORK/ckd.drive.sh"
printf '%s\n' 'cd "$2" || exit 1' '. "$1" 2>/dev/null' \
  'for d in "$FXROOT"*/; do [ -f "$d/run.sh" ] && printf "%s\n" "$d"; done > "$3/list"' \
  'apply_readset_skip "$3/list" "$3" > "$3/ann" 2>&1' > "$CKD_DRV" || broken "could not write the stale-declared decision driver"
ckd_dec() { # <pool> <t> <tag> -> the decision dir $t.dd.<tag>
  mkdir -p "$2.dd.$3" && ( inproc AI_DLC_READSET_LIVE_TRACE=0 PATH="$2.bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin" -- "$CKD_DRV" "$1" "$2" "$2.dd.$3" )
}
ckd_cell() { awk -F'\t' -v f="$2" '$1 == f && ($2 == "run" || $2 == "skip") { printf "%s:%s:%s", $2, $4, $5 }' "$1/.kdec" 2>/dev/null; }
ckd_world() { local p="$1" x="$2" t="$3" k kd
  ck_seed "$t" "$x" || { printf SEED; return; }
  mkdir -p "$t/$x/decl" "$t/core/scripts" && printf 'exit 0\n' > "$t/$x/decl/run.sh" && printf 'src/a.sh\nsrc/b.sh\n' > "$t/$x/decl/inputs.decl" \
    && printf '# HR_SANDBOX_BEGIN\nr1\n# HR_SANDBOX_END\nf() {\n}\nexit 1\n' > "$t/core/scripts/hermetic-run.sh" \
    && ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm decl ) >/dev/null 2>&1 || { printf SEED; return; }
  kd="$t/.git/ai-dlc-fixture-keys"; mkdir -p "$kd" || { printf SEED; return; }
  ckd_dec "$p" "$t" rec
  for k in decl alpha beta; do
    [ -f "$t.dd.rec/.k/$k" ] || { printf NOREC; return; }
    sed '2s/.*/#state ok/' "$t.dd.rec/.k/$k" | awk '{ print } NR == 3 { print "#pending 0" }' > "$kd/$k.key"
  done
  # alpha and decl go stale; beta stays ok. The rows are kept: a stale record is a valid record.
  for k in decl alpha; do sed '2s/.*/#state stale/' "$kd/$k.key" > "$kd/$k.key.t" && mv "$kd/$k.key.t" "$kd/$k.key"; done
  ckd_dec "$p" "$t" same
  printf 'x\n' > "$t/src/c.sh"; ckd_dec "$p" "$t" unrel; printf 'v1\n' > "$t/src/c.sh"
  printf 'v2\n' > "$t/src/a.sh"; ckd_dec "$p" "$t" chg; printf 'v1\n' > "$t/src/a.sh"
  printf '# HR_SANDBOX_BEGIN\nr2\n# HR_SANDBOX_END\nf() {\n}\nexit 1\n' > "$t/core/scripts/hermetic-run.sh"; ckd_dec "$p" "$t" rchg
  printf '# HR_SANDBOX_BEGIN\nr1\n# HR_SANDBOX_END\nf() {\n  : store\n}\nexit 1\n' > "$t/core/scripts/hermetic-run.sh"; ckd_dec "$p" "$t" rout
  printf '# HR_SANDBOX_BEGIN\nr1\n# HR_SANDBOX_END\nf() {\n}\nexit 1\n' > "$t/core/scripts/hermetic-run.sh"
  printf 'src/a.sh\n' > "$t/$x/decl/inputs.decl"; ckd_dec "$p" "$t" nar; printf 'src/a.sh\nsrc/b.sh\n' > "$t/$x/decl/inputs.decl"
  grep -qx '#modes v1' "$kd/decl.key" && grep -qx '#modes v1' "$kd/beta.key" && cp "$kd/beta.key" "$kd/beta.key.h" || { printf NOMODES; return; }
  awk '$0 != "#modes v1" && index($0, "#mode\t") != 1' "$kd/beta.key.h" > "$kd/beta.key"; chmod +x "$t/src/a.sh"
  ckd_dec "$p" "$t" mode; chmod -x "$t/src/a.sh"; mv "$kd/beta.key.h" "$kd/beta.key"
  sed -n 1,3p "$kd/decl.key" > "$kd/decl.key.t" && mv "$kd/decl.key.t" "$kd/decl.key"; ckd_dec "$p" "$t" empty
  printf 'dsame=%s unrel=%s dchg=%s rchg=%s rout=%s dnar=%s dmode=%s badopt=%s dempty=%s ctl=%s beta=%s' "$(ckd_cell "$t.dd.same" decl)" "$(ckd_cell "$t.dd.unrel" decl)" \
    "$(ckd_cell "$t.dd.chg" decl)" "$(ckd_cell "$t.dd.rchg" decl)" "$(ckd_cell "$t.dd.rout" decl)" "$(ckd_cell "$t.dd.nar" decl)" "$(ckd_cell "$t.dd.mode" decl)" "$(ckd_cell "$t.dd.mode" beta)" \
    "$(ckd_cell "$t.dd.empty" decl)" "$(ckd_cell "$t.dd.same" alpha)" "$(ckd_cell "$t.dd.same" beta)"
}
CKD_WANT='dsame=skip:v:ok unrel=skip:v:ok dchg=run:k:ok rchg=run:k:ok rout=skip:v:ok dnar=run:k:ok dmode=run:x:ok badopt=skip:a:ok dempty=run:s:ok ctl=run:s:stale beta=skip::ok'
# THE FIRST RESOLVED HOOK ONLY: the decision this world drives is inside the FIXTURE_POOL block, which I66 holds
# code-identical across both hooks, and the second hook's own fixture root is proven wired by ckw's (d) arm.
CKD_N="$CK_N"; CKD_P1="${CK_P1:-}"; CKD_X1="${CK_X1:-}"
if [ "$CKD_N" -ge 1 ]; then
  CK_ARMS=$((CK_ARMS+1)); _g="$(ckd_world "$CKD_P1" "$CKD_X1" "$CK_W/ckd.h1" 2>/dev/null)"
  if [ "$_g" = "$CKD_WANT" ]; then ok "(stale-declared) ${CK_H1#"$ROOT"/}: $_g"
  else bad "(stale-declared) ${CK_H1#"$ROOT"/}: want '$CKD_WANT' got '$_g'"; fi
fi
CK_ARMS=$((CK_ARMS+1))
[ "$CKD_N" -ge 1 ] && ok "the stale-declared world ran against the first of $CKD_N hook(s)" || bad "no pre-push hook was found for the stale-declared world"

# A QUOTED MAP ROW MUST NOT TURN KEYING OFF FOR THE PUSH. The quoted-path guard in readset_manifest used to read
# `.paths`, which carries every committed-map and local-map path, so one C-quoted row emptied `.now` and the push
# printed `could not hash the working tree -- running all N`. It now reads the two ls-files streams only; a quoted
# map row is dropped from the universe and ITS fixture runs, every other fixture is still decided on its keys.
#   qrow   a quoted row on alpha in the committed map         -> alpha runs, beta and delta skip
#   qpath  a file git must quote (a tab in its name)          -> the guard still fires: all three run, and
#                                                                the announcement names the path (the near-miss)
#   qctl   neither                                            -> all three skip (proves the driver decides)
ckq_world() { local p="$1" x="$2" t="$3" k kd
  ck_seed "$t" "$x" || { printf SEED; return; }
  kd="$t/.git/ai-dlc-fixture-keys"; mkdir -p "$kd" || { printf SEED; return; }
  ckd_dec "$p" "$t" qrec
  for k in alpha beta delta; do
    [ -f "$t.dd.qrec/.k/$k" ] || { printf NOREC; return; }
    awk '{ print } NR == 3 { print "#pending 0" }' "$t.dd.qrec/.k/$k" > "$kd/$k.key"
  done
  ckd_dec "$p" "$t" qctl
  printf 'alpha\t"src/q\\tx.sh"\n' >> "$t/.ai-dlc-fixture-readsets.tsv"
  ckd_dec "$p" "$t" qrow
  git -C "$t" checkout -q -- .ai-dlc-fixture-readsets.tsv 2>/dev/null
  printf 'q\n' > "$t/src/tab	name.txt"
  ckd_dec "$p" "$t" qpath
  rm -f "$t/src/tab	name.txt"
  # THE LOCAL MAP, where graph's bad row lives: a deriver-written C-quoted row with a real tab in the quoted name.
  printf 'alpha\t"src/q\tx.sh"\t-\n' > "$t/.git/ai-dlc-fixture-readsets.local"
  ckd_dec "$p" "$t" qloc
  rm -f "$t/.git/ai-dlc-fixture-readsets.local"
  printf 'qctl=%s,%s,%s qrow=%s,%s,%s qpath=%s,%s,%s why=%s qloc=%s' \
    "$(ckd_cell "$t.dd.qctl" alpha)" "$(ckd_cell "$t.dd.qctl" beta)" "$(ckd_cell "$t.dd.qctl" delta)" \
    "$(ckd_cell "$t.dd.qrow" alpha)" "$(ckd_cell "$t.dd.qrow" beta)" "$(ckd_cell "$t.dd.qrow" delta)" \
    "$(ckd_cell "$t.dd.qpath" alpha)" "$(ckd_cell "$t.dd.qpath" beta)" "$(ckd_cell "$t.dd.qpath" delta)" \
    "$(grep -c 'cause: git quotes the path .*tab' "$t.dd.qpath/ann" 2>/dev/null)" \
    "$(ckd_cell "$t.dd.qloc" alpha),$(ckd_cell "$t.dd.qloc" beta),$(ckd_cell "$t.dd.qloc" delta)"
}
# graph's real shape: a quoted row in the LOCAL map on a fixture with NO committed rows. gamma is mapped by a valid
# local row (src/c.sh) and recorded; the local map then gains a deriver-written C-quoted tab-bearing row for gamma.
# gamma must RUN (its own read set names a quoted path), alpha/beta/delta must still SKIP on their keys.
ckq_local_world() { local p="$1" x="$2" t="$3" k kd ds lm
  ck_seed "$t" "$x" gamma || { printf SEED; return; }
  mkdir -p "$t/core/scripts" && printf '#!/bin/bash\nexit 0\n' > "$t/core/scripts/derive-fixture-readsets.sh" \
    && ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm deriver ) >/dev/null 2>&1 || { printf SEED; return; }
  ds="$(ck_sha "$t/core/scripts/derive-fixture-readsets.sh")"; lm="$t/.git/ai-dlc-fixture-readsets.local"
  { printf 'gamma\tsrc/c.sh\t%s\n' "$(ck_sha "$t/src/c.sh")"; printf 'gamma\t#deriver\t%s\n' "$ds"; } > "$lm"
  kd="$t/.git/ai-dlc-fixture-keys"; mkdir -p "$kd" || { printf SEED; return; }
  ckd_dec "$p" "$t" lrec
  for k in alpha beta delta gamma; do
    [ -f "$t.dd.lrec/.k/$k" ] || { printf NOREC; return; }
    awk '{ print } NR == 3 { print "#pending 0" }' "$t.dd.lrec/.k/$k" > "$kd/$k.key"
  done
  ckd_dec "$p" "$t" lctl
  printf 'gamma\t"src/q\\tx.sh"\t-\n' >> "$lm"
  ckd_dec "$p" "$t" lq
  printf 'ctl=%s,%s,%s,%s lq=%s,%s,%s,%s' \
    "$(ckd_cell "$t.dd.lctl" gamma)" "$(ckd_cell "$t.dd.lctl" alpha)" "$(ckd_cell "$t.dd.lctl" beta)" "$(ckd_cell "$t.dd.lctl" delta)" \
    "$(ckd_cell "$t.dd.lq" gamma)" "$(ckd_cell "$t.dd.lq" alpha)" "$(ckd_cell "$t.dd.lq" beta)" "$(ckd_cell "$t.dd.lq" delta)"
}
CKQL_WANT='ctl=skip::ok,skip::ok,skip::ok,skip::ok lq=run:k:ok,skip::ok,skip::ok,skip::ok'
# A run cell prints `run:<class>:<state>`; with no .kdec row (a run-all announcement writes none) it prints empty.
CKQ_WANT='qctl=skip::ok,skip::ok,skip::ok qrow=run:k:ok,skip::ok,skip::ok qpath=,, why=1 qloc=skip::ok,skip::ok,skip::ok'
if [ "$CKD_N" -ge 1 ]; then
  CK_ARMS=$((CK_ARMS+1)); _g="$(ckq_world "$CKD_P1" "$CKD_X1" "$CK_W/ckq.h1" 2>/dev/null)"
  if [ "$_g" = "$CKQ_WANT" ]; then ok "(quoted-row) a quoted map row runs its own fixture only, a quoted ls-files path still empties keying and is NAMED: $_g"
  else bad "(quoted-row) want '$CKQ_WANT' got '$_g'"; fi
  CK_ARMS=$((CK_ARMS+1)); _g="$(ckq_local_world "$CKD_P1" "$CKD_X1" "$CK_W/ckq.loc" 2>/dev/null)"
  if [ "$_g" = "$CKQL_WANT" ]; then ok "(quoted-local) a quoted LOCAL row on a fixture with no committed rows runs that fixture only; keying stays on for the rest: $_g"
  else bad "(quoted-local) want '$CKQL_WANT' got '$_g'"; fi
fi
fi

# ------------------------------------ tool keys do not depend on the invoker ----
# THE DEFECT: tools were resolved on the inherited $PATH. `git push` prepends git's exec-path to a hook's
# PATH and `self-update-push.sh`, a shell or a harness do not, so `git` keyed a different binary per
# invoker and each invocation's records read the other's tool rows as changed -- measured on the
# reference consumer, 57 against 149 of 199 fixtures on one tree, the two decisions differing in PATH
# alone. The block now resolves against git's real exec-path plus a fixed dir list, and migrates a
# record written the old way ONCE.
#   inv     one tree, one set of records, the decision under four environments: git's hook PATH (a FAKE
#           exec-path dir prepended, holding a `git` whose content differs, with GIT_EXEC_PATH naming
#           it), a plain PATH in a different order, `env -i PATH=/usr/bin:/bin`, and DEVELOPER_DIR set
#           (to an alternate developer dir where one exists). `.ftools`, `.tools` and `.kdec` must be
#           byte-identical, with exactly one `git` row, at git's real exec-path, and every fixture skipped.
#   pos     the positive arm: the block's tool dirs point at a stub dir that is NOT on PATH, and growing
#           the one binary there that only alpha's files name reruns alpha alone, as `tools changed`.
#   mig     records rewritten as the old hook wrote them (`#tools per-fixture`, tool rows at paths no
#           tool dir holds) skip on their tree keys, are republished `#tools canonical` with honest tool
#           rows and no old one, the next push migrates nothing, and a later binary change reruns alpha.
#   migrun  the amnesty never covers a tree key: an old-format record whose FILE moved runs, for that file.
if sg tk; then
# TK_WORLDS_BEGIN -- the tool-key worlds, defined after CK_HELPERS.
TK_ARMS=0
TK_FX="$WORK/tk.xp"; mkdir -p "$TK_FX" || broken "could not create the fake exec-path dir"
TK_GIT="$(command -v git)" || broken "no git on PATH"
printf '#!/bin/bash\n# readset-skip: a stand-in for the copy of git in an exec-path dir\nexec "%s" "$@"\n' "$TK_GIT" > "$TK_FX/git" && chmod +x "$TK_FX/git" \
  || broken "could not write the fake exec-path git"
cmp -s "$TK_FX/git" "$TK_GIT" && broken "the fake exec-path git is byte-identical to the real one, so no world could tell them apart"
TK_PLAIN="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
# THE EXPECTED git ROW, derived here from git itself rather than read off the block.
TK_XPE=""
for _g in /usr/bin/git /usr/local/bin/git /opt/homebrew/bin/git; do
  [ -x "$_g" ] && { TK_XPE="$(/usr/bin/env -u DEVELOPER_DIR -u GIT_EXEC_PATH "$_g" --exec-path 2>/dev/null)"; break; }
done
TK_EXP=""
[ -n "$TK_XPE" ] && [ -x "$TK_XPE/git" ] && TK_EXP="$TK_XPE/git"
if [ -z "$TK_EXP" ]; then
  for _d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin /usr/sbin /sbin; do [ -x "$_d/git" ] && { TK_EXP="$_d/git"; break; }; done
fi
[ -n "$TK_EXP" ] || broken "no git in git's exec-path or in any fixed tool dir, so the invariance world has no row to expect"
# AN ALTERNATE DEVELOPER DIR, where xcrun can switch to one: the only environment in which dropping
# `-u DEVELOPER_DIR` changes the answer. Where none exists the dev cell runs against $WORK/tk.nodev,
# whose xcrun shim fails, so that regression reads dev=differ on every box rather than dev=same.
TK_DEV=""
if [ -x /usr/bin/xcrun ] && [ -n "$TK_XPE" ]; then
  for _c in /Library/Developer/CommandLineTools /Applications/Xcode*.app/Contents/Developer; do
    [ -d "$_c" ] || continue
    _x="$(DEVELOPER_DIR="$_c" /usr/bin/env -u GIT_EXEC_PATH /usr/bin/git --exec-path 2>/dev/null)" || continue
    if [ -n "$_x" ] && [ "$_x" != "$TK_XPE" ] && [ -x "$_x/git" ]; then TK_DEV="$_c"; break; fi
  done
fi
[ -n "$TK_DEV" ] || TK_DEV="$WORK/tk.nodev"
# THE DECISION ALONE, in a process of its own so each environment is the one it is started under.
TK_DRV="$WORK/tk.drive.sh"
printf '%s\n' 'cd "$2" || exit 1' '. "$1" 2>/dev/null' \
  'for d in "$FXROOT"*/; do [ -f "$d/run.sh" ] && printf "%s\n" "$d"; done > "$3/list"' \
  'apply_readset_skip "$3/list" "$3" > "$3/ann" 2>&1' > "$TK_DRV" || broken "could not write the decision driver"
tk_push() { # <pool> <t> <tag> <canon|fixed>: ck_push with NO shim dir on PATH. `fixed` points the block's
  # tool dirs at the shim dir and its exec-path at a dir that does not exist; `canon` keeps the block's own.
  local o="$2.o.$3"
  mkdir -p "$o" && : > "$o/log" || return 1
  ( cd "$2" || exit 1
    export CK_LOG="$o/log" CK_CTL="$2.ctl" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_JOBS=1
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$1" 2>/dev/null
    if [ "$4" = fixed ]; then READSET_TOOL_DIRS="$2.bin"; READSET_TOOL_XP="$2.xp"; fi
    printf '%s\n' "${POOL_STALL:-}" > "$o/stall"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    run_fixtures > "$o/out" 2>&1; echo "$?" > "$o/rc" )
  LC_ALL=C sort "$o/log" | tr '\n' ' ' | sed 's/ $//' > "$o/ran"
}
tk_same() { # <ref dir> <dir>: same | differ, over the three files the decision derives tools into
  local f
  for f in .ftools .tools .kdec; do cmp -s "$1/$f" "$2/$f" || { printf differ; return; }; done
  printf same
}
tk_old() { # <t>: every record as the PATH-resolved hook wrote it, its tool rows at paths no tool dir holds
  local k
  for k in "$1/.git/ai-dlc-fixture-keys/"*.key; do
    [ -f "$k" ] || return 1
    awk -F'\t' 'NR == 3 { print "#tools per-fixture"; next }
      /^\// { n = $1; sub(/.*\//, "", n); print "/tk-old-path/" n "\t" $2; next } { print }' "$k" > "$k.t" && mv "$k.t" "$k" || return 1
  done
}
# tk_rec <pool> <fx root> <t> <decided dir>: THE SKIP-SET RECORD (BL-878). readset_pending_recorded is called directly, on a copy of
# the decision apply_readset_skip just wrote (every fixture skipped, so `list` is untouched and no verdict exists), after ONE
# fixture is given a verdict (it ran). The oracle is independent of `.kdec`: every run.sh the world
# lists, minus the names holding a verdict. Prints "<SKIP lines>/<eq|ne>/<headers>h<SKIP lines of a world with no skip row>s".
tk_rec() {
  local p="$1" x="$2" t="$3" o="$4" d b n eq=ne nc=ne w
  cp -Rp "$o" "$o.rec" && cp -Rp "$o" "$o.zero" && cp -Rp "$o" "$o.nc" || { printf SEED; return; }
  read -r d < "$o.rec/list"; b="${d%/}"; printf ok > "$o.rec/${b##*/}"
  { awk -F'\t' '$2 == "run"' "$o/.kdec"; printf 'zero-world-run-row\trun\n'; } > "$o.zero/.kdec"; rm -rf "$o.zero/.cl"
  : > "$o.rec.log"; : > "$o.zero.log"; : > "$o.nc.log"
  ( cd "$t" || exit 1
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    . "$p" 2>/dev/null
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_pending_recorded "$o.rec" "$o.rec.log"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_pending_recorded "$o.zero" "$o.zero.log"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    READSET_NO_CHANGE=1 readset_pending_recorded "$o.nc" "$o.nc.log" )
  for d in "$t/$x"/*/; do [ -f "$d/run.sh" ] || continue; b="${d%/}"; b="${b##*/}"; [ -f "$o.rec/$b" ] || printf '%s\n' "$b"; done | LC_ALL=C sort > "$o.rec.want"
  awk -F'\t' '$2 == "SKIP" && $4 == "dist" { print $5 }' "$o.rec.log" | LC_ALL=C sort > "$o.rec.got"
  n="$(grep -c . "$o.rec.got")" || n=0
  [ "$n" -gt 0 ] && cmp -s "$o.rec.want" "$o.rec.got" && eq=eq
  # The no-change path leaves `list` holding every fixture and skips every one, so the PUSH line's dist triple is
  # <fixtures>/0/<fixtures>, the fixture count taken from the run.sh files on disk, not from the writer.
  w="$(for d in "$t/$x"/*/; do [ -f "$d/run.sh" ] && echo "${d%/}"; done | grep -c .)" || w=0
  [ "$(awk -F'\t' '$2 == "PUSH" { c++; sub(/ .*/, "", $7); v = $7 } END { if (c == 1) print v }' "$o.nc.log")" = "dist=$w/0/$w" ] && [ "$w" -gt 0 ] && nc=eq
  printf '%s/%s/%sh%ss/%s' "$n" "$eq" "$(grep -c '	PUSH	' "$o.zero.log")" "$(grep -c '	SKIP	' "$o.zero.log")" "$nc"
}
tk_w_inv() { local p="$1" x="$2" t="$3" e r=""
  ck_seed "$t" "$x" || { printf SEED; return; }
  printf 'git status\njq . python3 timeout\n' >> "$t/src/all.sh"
  ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm tools ) >/dev/null 2>&1 || { printf SEED; return; }
  tk_push "$p" "$t" 1 canon
  mkdir -p "$t.d.ref" "$t.d.hook" "$t.d.envi" "$t.d.dev" || { printf SEED; return; }
  ( inproc -u GIT_EXEC_PATH -u DEVELOPER_DIR PATH="$TK_PLAIN" -- "$TK_DRV" "$p" "$t" "$t.d.ref" )
  ( inproc -u DEVELOPER_DIR PATH="$TK_FX:$PATH" GIT_EXEC_PATH="$TK_FX" -- "$TK_DRV" "$p" "$t" "$t.d.hook" )
  ( inproc -i HOME="$HOME" PATH=/usr/bin:/bin -- "$TK_DRV" "$p" "$t" "$t.d.envi" )
  ( inproc -u GIT_EXEC_PATH DEVELOPER_DIR="$TK_DEV" -- "$TK_DRV" "$p" "$t" "$t.d.dev" )
  for e in hook envi dev; do r="$r $e=$(tk_same "$t.d.ref" "$t.d.$e")"; done
  printf 'git=%s:%s tools=%s skip=%s%s rec=%s' "$(cut -f1 "$t.d.ref/.tools" 2>/dev/null | grep -c '/git$')" \
    "$(cut -f1 "$t.d.ref/.tools" 2>/dev/null | grep -cxF "$TK_EXP")" \
    "$([ -s "$t.d.ref/.tools" ] && echo y || echo n)" "$(awk -F'\t' '$2 == "skip"' "$t.d.ref/.kdec" 2>/dev/null | grep -c .)" "$r" \
    "$(tk_rec "$p" "$x" "$t" "$t.d.ref")"
}
TK_WANT_inv='git=1:1 tools=y skip=3 hook=same envi=same dev=same rec=2/eq/1h0s/eq'
tk_w_pos() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  tk_push "$p" "$t" 1 fixed; printf '# grown\n' >> "$t.bin/cktool"; tk_push "$p" "$t" 2 fixed
  printf 'p2=%s why=%s' "$(ck_r "$t" 2)" "$(ck_ln "$t" 2 '   ..      alpha: tools changed')"
}
TK_WANT_pos='p2=alpha|0 why=1'
TK_ANN3='   ..    read-set tool keys: 3 record(s) written before the fixed tool dirs skipped on their tree keys alone and are republished with canonical tool keys (once per record)'
tk_w_mig() { local p="$1" x="$2" t="$3" kd
  ck_seed "$t" "$x" || { printf SEED; return; }
  kd="$t/.git/ai-dlc-fixture-keys"
  tk_push "$p" "$t" 1 fixed; tk_old "$t" || { printf OLDSEED; return; }
  [ "$(grep -l '^/tk-old-path/' "$kd"/*.key 2>/dev/null | grep -c .)" = 3 ] || { printf OLDSEED; return; }
  tk_push "$p" "$t" 2 fixed
  local hdr old new
  hdr="$(for k in "$kd"/*.key; do sed -n 3p "$k"; done | grep -cx '#tools canonical')"
  old="$(grep -l '^/tk-old-path/' "$kd"/*.key 2>/dev/null | grep -c .)"
  new="$(grep -lxF "$t.bin/ckall	$(ck_sha "$t.bin/ckall")" "$kd"/*.key 2>/dev/null | grep -c .)"
  tk_push "$p" "$t" 3 fixed; printf '# grown\n' >> "$t.bin/cktool"; tk_push "$p" "$t" 4 fixed
  printf 'p2=%s ann2=%s hdr=%s old=%s new=%s p3=%s ann3=%s p4=%s' "$(ck_r "$t" 2)" "$(ck_ln "$t" 2 "$TK_ANN3")" \
    "$hdr" "$old" "$new" "$(ck_r "$t" 3)" "$(grep -c 'read-set tool keys:' "$t.o.3/out")" "$(ck_r "$t" 4)"
}
TK_WANT_mig='p2=|0 ann2=1 hdr=3 old=0 new=3 p3=|0 ann3=0 p4=alpha|0'
tk_w_migrun() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  tk_push "$p" "$t" 1 fixed; tk_old "$t" || { printf OLDSEED; return; }
  printf 'v2\n' > "$t/src/b.sh"; tk_push "$p" "$t" 2 fixed
  printf 'beta=%s why=%s' "$(grep -cx beta "$t.o.2/log")" "$(ck_ln "$t" 2 '   ..      beta: changed src/b.sh')"
}
TK_WANT_migrun='beta=1 why=1'
TK_WORLDS="inv pos mig migrun"
tk_all() { local w; for w in $TK_WORLDS; do "tk_w_$w" "$1" "$2" "$CK_W/tk.$3.$w" > "$CK_W/tk.$3.$w.got" 2>/dev/null; done; }
tk_want() { eval "printf '%s' \"\$TK_WANT_$1\""; }
# TK_WORLDS_END

TK_N=0
# EVERY WORLD RUNS AGAINST THE FIRST HOOK ONLY. I66 in scripts/validate-enforcement-map.sh fails the push on any
# difference between the two FIXTURE_POOL blocks after comment strip except FXROOT, so the worlds would score
# identical code twice; the second hook's FXROOT is driven end to end by ckw's (d, wiring) world, the one
# hook-2 world of this fixture.
for _h in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$_h" ] || continue
  TK_N=$((TK_N+1)); TK_P="$CK_W/tkpool.$TK_N.sh"
  pool_span "$_h" "$TK_P" FIXTURE_POOL && rs_rec_pin >> "$TK_P"
  TK_X="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$TK_P" | sort -u)"
  tk_all "$TK_P" "$TK_X" "h$TK_N"
  for _w in $TK_WORLDS; do
    TK_ARMS=$((TK_ARMS+1)); _g="$(cat "$CK_W/tk.h$TK_N.$_w.got")"
    if [ "$_g" = "$(tk_want "$_w")" ]; then ok "(tk-$_w) ${_h#"$ROOT"/}: $_g"
    else bad "(tk-$_w) ${_h#"$ROOT"/}: want '$(tk_want "$_w")' got '$_g'"; fi
  done
  break
done
TK_ARMS=$((TK_ARMS+1))
[ "$TK_N" -ge 1 ] && ok "the tool-key worlds ran against the first of the hook(s)" || bad "no pre-push hook was found for the tool-key worlds"

fi

# ------------------------------------- readset_hash_rows on a set's LAST path ----
# A TRACE THAT SUCCEEDED AND THEN LOST ITS RESULT. Spelled `[ -f "$p" ] && printf` as its loop's last
# command, the hash failed under `pipefail` whenever the set's LAST path was not a regular file, and
# the deriver dropped a clean trace as `could not hash <fx>'s set in the trace copy -- not recorded`.
#   (h1) a set ending on a directory hashes, under pipefail, with a `-` row for the directory
#   (h2) a set holding an UNREADABLE regular file still refuses, under pipefail AND without it -- the
#        second is the count assertion's own world: there the pipeline's status is awk's
# Each arm is driven on the deriver's own READSET_LOCALMAP span.
if sg hr; then
HR_SPAN="$WORK/hr.span.sh"
hr_drive() { # <span> <pipefail|nopipefail> <last|unread>: prints "<rc>|<rows>"
  local d; d="$(mktemp -d "$WORK/hr.XXXXXX")" || return 1
  mkdir -p "$d/t/dir" && printf 'x\n' > "$d/t/a" && printf 'y\n' > "$d/t/b" || return 1
  if [ "$3" = last ]; then printf 'a\nb\ndir\n' > "$d/set"; else chmod 000 "$d/t/b"; printf 'a\nb\n' > "$d/set"; fi
  ( if [ "$2" = pipefail ]; then set -o pipefail; else set +o pipefail; fi
    # shellcheck disable=SC1090
    fx_inproc "$DERIVER"; . "$1"; fx_inproc "$DERIVER"; readset_hash_rows "$d/t" fx "$d/set" > "$d/rows" ); printf '%s|%s' "$?" "$(grep -c . "$d/rows")"
  chmod 600 "$d/t/b" 2>/dev/null
}
if [ -z "$DERIVER" ]; then
  printf '  SKIP  readset_hash_rows arms: no deriver in either layout\n'
else
  sed -n '/^# READSET_LOCALMAP_BEGIN$/,/^# READSET_LOCALMAP_END$/p' "$DERIVER" > "$HR_SPAN"
  grep -q '^readset_hash_rows() {' "$HR_SPAN" || broken "no readset_hash_rows in the deriver's READSET_LOCALMAP span"
  HR_UNREAD_CAN=1; HR_P="$(mktemp -d "$WORK/hrp.XXXXXX")"; printf 'z\n' > "$HR_P/f"; chmod 000 "$HR_P/f"
  cat "$HR_P/f" >/dev/null 2>&1 && HR_UNREAD_CAN=0
  hr_arms() { # <span> <label>: prints the cells "h1 h2p h2n", each ok or the drive's result
    local a b c
    a="$(hr_drive "$1" pipefail last)"; b="$(hr_drive "$1" pipefail unread)"; c="$(hr_drive "$1" nopipefail unread)"
    printf '%s %s %s' "$([ "$a" = '0|3' ] && echo ok || echo "h1=$a")" "$([ "${b%%|*}" != 0 ] && echo ok || echo "h2p=$b")" "$([ "${c%%|*}" != 0 ] && echo ok || echo "h2n=$c")"
  }
  HR="$(hr_arms "$HR_SPAN")"; lt_arm
  case "$HR" in "ok "*) ok "(h1) a set whose LAST path is a directory hashes under pipefail, its directory a '-' row: 3 rows" ;;
    *) bad "(h1) a set ending on a directory did not hash: $HR" ;; esac
  if [ "$HR_UNREAD_CAN" = 0 ]; then
    printf '  SKIP  (h2) an unreadable regular file: chmod 000 does not stop this user reading it (root?)\n'
  else
    lt_arm
    case "$HR" in *" ok ok") ok "(h2) a set holding an UNREADABLE regular file refuses, with pipefail and without it" ;;
      *) bad "(h2) an unreadable file did not refuse in both shells: $HR" ;; esac
  fi
fi

fi

# ------------------------------------- committed digests clear a stale record (BL-471) ----
# A STALE KEY RECORD CLEARS ON A COMMITTED TRACE, NOT ONLY ON A LOCAL ONE. The deriver writes one
# `# digest <fx> <sha>` line per traced fixture into the committed map, and the hook recomputes that
# digest over its own `.now`: a match makes the committed rows VALID, so a stale record skips and is
# republished `ok`. A digest that predates the change, or rows with no digest at all (a map written
# before digests), never clear. Every digest seeded here is computed by the SHIPPED producer: the
# deriver's readset_hash_rows over the pool's own manifest, through the pool's readset_digests -- the
# function the deriver sources out of the hook -- so the seed is what a real trace writes.
# Each world is one vector against a want string, run against both hooks like the CK worlds.
DG_ARMS=0
# DG_WORLDS_BEGIN
DG_HASH="$WORK/dg.hashrows.sh"
if [ -n "$DERIVER" ]; then
  sed -n '/^# READSET_LOCALMAP_BEGIN$/,/^# READSET_LOCALMAP_END$/p' "$DERIVER" > "$DG_HASH"
  grep -q '^readset_hash_rows() {' "$DG_HASH" || broken "no readset_hash_rows in the deriver's READSET_LOCALMAP span, so no digest can be seeded the way the deriver writes one"
  grep -q '^readset_local_rows() {' "$DG_HASH" || broken "no readset_local_rows in the deriver's READSET_LOCALMAP span, so no local row can be seeded the way --local-map writes one"
fi
dg_digest() { # <pool> <t> <fixture>...: append the deriver's `# digest` line for each, as a trace would
  local p="$1" t="$2" s; shift 2
  s="$(mktemp -d "$WORK/dgs.XXXXXX")" || return 1
  ( cd "$t" || exit 1
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$p" 2>/dev/null; . "$DG_HASH"
    fx_inproc "$ROOT/core/git-hooks/pre-push"; readset_manifest "$s"; [ -s "$s/.paths" ] || exit 1
    for f in "$@"; do
      awk -F'\t' -v f="$f" '!/^#/ && $1 == f { print $2 }' .ai-dlc-fixture-readsets.tsv > "$s/$f.set"
      fx_inproc "$DERIVER"
      readset_hash_rows . "$f" "$s/$f.set" || exit 1
    done > "$s/rows"
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_dir_values "$s/rows" "$s/.now" "$s/.paths" "$s/rows2" || exit 1
    fx_inproc "$ROOT/core/git-hooks/pre-push"; readset_digests "$s/rows2" "$s/rows2.keep" .ai-dlc-fixture-readsets.tsv "$s/dg" ) > "$s/out" || return 1
  [ "$(grep -c . "$s/out")" -eq "$#" ] || return 1
  awk -F'\t' 'NF == 2 { print "# digest " $1 " " $2 }' "$s/out" >> "$t/.ai-dlc-fixture-readsets.tsv"
  ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm digest ) >/dev/null 2>&1
}
dg_deriver() { # <t>: a tracked deriver for readset_deriver_path to resolve and hash
  mkdir -p "$1/core/scripts" && printf '#!/bin/bash\nexit 0\n' > "$1/core/scripts/derive-fixture-readsets.sh" \
    && ( cd "$1" && git add -A && git -c user.email=f@f -c user.name=f commit -qm deriver ) >/dev/null 2>&1
}
# dg_local_rows <pool> <t> <fixture>: print <fixture>'s local rows the way the deriver's --local-map writes
# them -- its readset_local_rows over a manifest of <t> taken with no local map, as the deriver takes one of
# the trace copy. The UNIVERSE span comes from the POOL UNDER TEST (as dg_digest sources it), so a change to
# that pool's readset_dir_values reaches the seed too. Fails closed on an empty row set.
dg_local_rows() {
  local p="$1" t="$2" fx="$3" s
  s="$(mktemp -d "$WORK/dgl.XXXXXX")" || return 1
  ( cd "$t" || exit 1
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$p" 2>/dev/null; . "$DG_HASH"
    READSET_MAP=.ai-dlc-fixture-readsets.tsv; READSET_LOCAL=/dev/null
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_manifest "$s"; [ -s "$s/.paths" ] || exit 1
    awk -F'\t' -v f="$fx" '!/^#/ && $1 == f { print $2 }' .ai-dlc-fixture-readsets.tsv > "$s/$fx.set"
    fx_inproc "$DERIVER"
    readset_local_rows . "$fx" "$s/$fx.set" "$s/.now" "$s/.paths" ) > "$s/rows" || return 1
  [ -s "$s/rows" ] || return 1
  cat "$s/rows"
}
dg_local() { # <t> <deriver sha>: alpha's valid local rows, as the deriver's --local-map writes them
  { printf 'alpha\tsrc/a.sh\t%s\n' "$(ck_sha "$1/src/a.sh")"
    printf 'alpha\tsrc/shared.sh\t%s\n' "$(ck_sha "$1/src/shared.sh")"
    printf 'alpha\tsrc/all.sh\t%s\n' "$(ck_sha "$1/src/all.sh")"
    printf 'alpha\t#deriver\t%s\n' "$2"; } > "$1/.git/ai-dlc-fixture-readsets.local"
}
DG_STALE='   ..      alpha: stale'
DG_DIFFERS='   ..    stale, 1 fixture(s): committed # digest no longer matches this tree -- cleared by a committed trace whose # digest matches this tree, or a valid local row: alpha'
DG_NODIGEST='   ..    stale, 1 fixture(s): committed rows carry no # digest line (written before digests) -- cleared by a committed trace whose # digest matches this tree, or a valid local row: alpha'

# (w1) the motivating case: alpha goes stale, a committed trace lands for it (no local row, and a local
# map that names only another fixture, so a guard on the local map's existence cannot hide), and the
# push straight after skips alpha and republishes its record `ok`. No deriver in the tree: committed
# validation carries no deriver sha.
dg_w_w1() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2; local s2; s2="$(ck_st "$t" alpha)"
  printf 'other\t#discards\t1\tx:y\tz\n' > "$t/.git/ai-dlc-fixture-readsets.local"
  dg_digest "$p" "$t" alpha || { printf DIGEST; return; }
  ck_push "$p" "$t" 3; local s3; s3="$(ck_st "$t" alpha)"; ck_push "$p" "$t" 4
  printf 'p2=%s s2=%s p3=%s s3=%s p4=%s' "$(ck_r "$t" 2)" "$s2" "$(ck_r "$t" 3)" "$s3" "$(ck_r "$t" 4)"
}
DG_WANT_w1='p2=alpha|0 s2=#state stale p3=|0 s3=#state ok p4=|0'

# (w2) the digest PREDATES the change: it was taken over v1, so the push after the change finds it
# differing, alpha stays stale and runs, and the hook says what would clear it.
dg_w_w2() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_digest "$p" "$t" alpha || { printf DIGEST; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2; ck_push "$p" "$t" 3
  printf 'p3=%s why=%s ann=%s s3=%s' "$(ck_r "$t" 3)" "$(ck_ln "$t" 3 "$DG_STALE")" "$(ck_ln "$t" 3 "$DG_DIFFERS")" "$(ck_st "$t" alpha)"
}
DG_WANT_w2='p3=alpha|0 why=1 ann=1 s3=#state stale'

# (w3) a map written BEFORE digests: alpha and delta carry 2-field rows only, beta a digest. alpha's
# rows are UNVALIDATED -- it stays stale -- but they still SELECT: delta is not keyed on the whole
# tree, so the push after alpha's change runs alpha alone.
dg_w_w3() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_digest "$p" "$t" beta || { printf DIGEST; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2; ck_push "$p" "$t" 3
  printf 'p2=%s p3=%s ann=%s s3=%s' "$(ck_r "$t" 2)" "$(ck_r "$t" 3)" "$(ck_ln "$t" 3 "$DG_NODIGEST")" "$(ck_st "$t" alpha)"
}
DG_WANT_w3='p2=alpha|0 p3=alpha|0 ann=1 s3=#state stale'

# (w4) a valid LOCAL row still clears, as before, even where the committed digest differs.
dg_w_w4() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_deriver "$t" || { printf SEED; return; }
  dg_digest "$p" "$t" alpha || { printf DIGEST; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2
  dg_local "$t" "$(ck_sha "$t/core/scripts/derive-fixture-readsets.sh")"
  ck_push "$p" "$t" 3; local s3; s3="$(ck_st "$t" alpha)"; ck_push "$p" "$t" 4
  printf 'p3=%s s3=%s p4=%s' "$(ck_r "$t" 3)" "$s3" "$(ck_r "$t" 4)"
}
DG_WANT_w4='p3=|0 s3=#state ok p4=|0'

# (w5) the push AFTER a clearing push: the digest lines in the map reach no row set, so a change to
# delta's input runs delta alone -- alpha (cleared) and beta (unrelated, mapped) both skip.
dg_w_w5() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2
  dg_digest "$p" "$t" alpha beta delta || { printf DIGEST; return; }
  ck_push "$p" "$t" 3; printf 'v2\n' > "$t/src/c.sh"; ck_push "$p" "$t" 4
  printf 'p4=%s' "$(ck_r "$t" 4)"
}
DG_WANT_w5='p4=delta|0'

# (w6) a local row recorded by ANOTHER deriver is not valid: alpha stays stale with no committed digest.
dg_w_w6() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_deriver "$t" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2
  dg_local "$t" 0000000000000000000000000000000000000000000000000000000000000000
  ck_push "$p" "$t" 3
  printf 'p3=%s s3=%s' "$(ck_r "$t" 3)" "$(ck_st "$t" alpha)"
}
DG_WANT_w6='p3=alpha|0 s3=#state stale'

# (w7) w1 with a deriver in the tree and NO local map at all: committed validation runs without one.
dg_w_w7() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_deriver "$t" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2
  dg_digest "$p" "$t" alpha || { printf DIGEST; return; }
  ck_push "$p" "$t" 3
  printf 'p3=%s s3=%s lm=%s' "$(ck_r "$t" 3)" "$(ck_st "$t" alpha)" "$([ -e "$t/.git/ai-dlc-fixture-readsets.local" ] && echo y || echo n)"
}
DG_WANT_w7='p3=|0 s3=#state ok lm=n'

# (w8) THE MAP READS ITSELF (B2): alpha's read set names the committed map, so the commit that adds its
# own digest moves a path alpha reads. The digest skips the map's path, so it still matches: alpha reruns
# once on the moved map and is recorded `ok`, and the next push skips it.
dg_w_w8() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  printf 'alpha\t.ai-dlc-fixture-readsets.tsv\n' >> "$t/.ai-dlc-fixture-readsets.tsv"
  ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm self ) >/dev/null 2>&1 || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2
  dg_digest "$p" "$t" alpha || { printf DIGEST; return; }
  ck_push "$p" "$t" 3; local s3; s3="$(ck_st "$t" alpha)"; ck_push "$p" "$t" 4
  printf 'p3=%s s3=%s p4=%s' "$(ck_r "$t" 3)" "$s3" "$(ck_r "$t" 4)"
}
DG_WANT_w8='p3=alpha|0 s3=#state ok p4=|0'

# (w9) A DIRECTORY ROW'S DIGEST VALUE IS ITS LISTING. beta reads the directory src/d. The digest is taken
# over the seed, push 2 grows beta's key with a new file under src/d, the file is edited (push 3: stale,
# the grown key dropped), and push 4 must NOT clear the record on the seed-time digest: a digest that gives
# a directory the value `-` cannot see src/d gain an entry, so it matches, clears the record `ok` without
# the new file's key, and push 5 SKIPS beta over an edit to that file.
dg_w_w9() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_digest "$p" "$t" beta || { printf DIGEST; return; }
  ck_push "$p" "$t" 1
  printf 'new v1\n' > "$t/src/d/new.sh"; ck_push "$p" "$t" 2
  printf 'new v2\n' > "$t/src/d/new.sh"; ck_push "$p" "$t" 3
  ck_push "$p" "$t" 4; local s4; s4="$(ck_st "$t" beta)"
  printf 'new v3\n' > "$t/src/d/new.sh"; ck_push "$p" "$t" 5
  printf 'p4=%s s4=%s p5=%s' "$(ck_r "$t" 4)" "$s4" "$(ck_r "$t" 5)"
}
DG_WANT_w9='p4=beta|0 s4=#state stale p5=beta|0'

# (w10) LOCAL CLEARING SURVIVES A DIRECTORY ROW. beta reads the directory src/d; its local rows are seeded
# by the deriver's own readset_local_rows (dg_local_rows), which records src/d by its `#listing:<sha>`.
# beta goes stale on an edit to src/b.sh and the local map clears it, as w4 does for alpha (which has no
# directory row, so w4 cannot see this). The listing still matches, so the row set is valid.
dg_w_w10() { local p="$1" x="$2" t="$3" r
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_deriver "$t" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/b.sh"; ck_push "$p" "$t" 2
  r="$(dg_local_rows "$p" "$t" beta)" || { printf LOCALROWS; return; }
  { printf '%s\n' "$r"; printf 'beta\t#deriver\t%s\n' "$(ck_sha "$t/core/scripts/derive-fixture-readsets.sh")"; } > "$t/.git/ai-dlc-fixture-readsets.local"
  ck_push "$p" "$t" 3; local s3; s3="$(ck_st "$t" beta)"; ck_push "$p" "$t" 4
  printf 'p3=%s s3=%s p4=%s' "$(ck_r "$t" 3)" "$s3" "$(ck_r "$t" 4)"
}
DG_WANT_w10='p3=|0 s3=#state ok p4=|0'

# (w11) THE LOCAL MAP'S TWIN OF w9: A LOCAL DIRECTORY ROW IS ITS LISTING. beta's local rows are seeded at seed
# time through dg_local_rows. Push 2 grows src/d with a new file, push 3 edits it (stale), and push 4 must
# NOT clear the record on the seed-time local rows: a local row that gives src/d the value `-` would match
# while no FILE named src/d exists, clear the record `ok` without the new file's key, and push 5 would
# SKIP beta over an edit to that file.
dg_w_w11() { local p="$1" x="$2" t="$3" r
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_deriver "$t" || { printf SEED; return; }
  r="$(dg_local_rows "$p" "$t" beta)" || { printf LOCALROWS; return; }
  { printf '%s\n' "$r"; printf 'beta\t#deriver\t%s\n' "$(ck_sha "$t/core/scripts/derive-fixture-readsets.sh")"; } > "$t/.git/ai-dlc-fixture-readsets.local"
  ck_push "$p" "$t" 1
  printf 'new v1\n' > "$t/src/d/new.sh"; ck_push "$p" "$t" 2
  printf 'new v2\n' > "$t/src/d/new.sh"; ck_push "$p" "$t" 3
  ck_push "$p" "$t" 4; local s4; s4="$(ck_st "$t" beta)"
  printf 'new v3\n' > "$t/src/d/new.sh"; ck_push "$p" "$t" 5
  printf 'p4=%s s4=%s p5=%s' "$(ck_r "$t" 4)" "$s4" "$(ck_r "$t" 5)"
}
DG_WANT_w11='p4=beta|0 s4=#state stale p5=beta|0'

# (w12) A HAND-WRITTEN `-` ROW FOR A DIRECTORY IS REFUSED. w10's world with the rows the deriver wrote before
# directory rows carried a listing: src/d is `-`, and src/d IS a directory, so the trace never saw its
# listing and the row set is stale. beta stays stale and runs.
dg_w_w12() { local p="$1" x="$2" t="$3"
  ck_seed "$t" "$x" || { printf SEED; return; }
  dg_deriver "$t" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/b.sh"; ck_push "$p" "$t" 2
  { printf 'beta\tsrc/b.sh\t%s\n' "$(ck_sha "$t/src/b.sh")"
    printf 'beta\tsrc/d\t-\n'
    printf 'beta\tsrc/all.sh\t%s\n' "$(ck_sha "$t/src/all.sh")"
    printf 'beta\t#deriver\t%s\n' "$(ck_sha "$t/core/scripts/derive-fixture-readsets.sh")"; } > "$t/.git/ai-dlc-fixture-readsets.local"
  ck_push "$p" "$t" 3
  printf 'p3=%s s3=%s' "$(ck_r "$t" 3)" "$(ck_st "$t" beta)"
}
DG_WANT_w12='p3=beta|0 s3=#state stale'

# (w13) A `-` ROW IS AN ABSENT NAME: VALID WHILE NOTHING OF THAT NAME EXISTS, REFUSED ONCE A FILE DOES. alpha
# (no directory row, so no listing can move this world) also reads src/ghost.sh, which does not exist; its
# local rows, seeded through dg_local_rows, record it `-`. Push 3 clears alpha's stale record on them. Push 4
# creates the file (alpha runs on the changed input either way); push 5 changes nothing, so alpha running
# there is the refusal: an accepted `-` row would have cleared the record at push 4 and push 5 would skip.
dg_w_w13() { local p="$1" x="$2" t="$3" r
  ck_seed "$t" "$x" || { printf SEED; return; }
  printf 'alpha\tsrc/ghost.sh\n' >> "$t/.ai-dlc-fixture-readsets.tsv"
  ( cd "$t" && git add -A && git -c user.email=f@f -c user.name=f commit -qm ghost ) >/dev/null 2>&1 || { printf SEED; return; }
  dg_deriver "$t" || { printf SEED; return; }
  ck_push "$p" "$t" 1; printf 'v2\n' > "$t/src/a.sh"; ck_push "$p" "$t" 2
  r="$(dg_local_rows "$p" "$t" alpha)" || { printf LOCALROWS; return; }
  { printf '%s\n' "$r"; printf 'alpha\t#deriver\t%s\n' "$(ck_sha "$t/core/scripts/derive-fixture-readsets.sh")"; } > "$t/.git/ai-dlc-fixture-readsets.local"
  ck_push "$p" "$t" 3; local s3; s3="$(ck_st "$t" alpha)"
  printf 'boo\n' > "$t/src/ghost.sh"; ck_push "$p" "$t" 4; ck_push "$p" "$t" 5
  printf 'p3=%s s3=%s p4=%s p5=%s s5=%s' "$(ck_r "$t" 3)" "$s3" "$(ck_r "$t" 4)" "$(ck_r "$t" 5)" "$(ck_st "$t" alpha)"
}
DG_WANT_w13='p3=|0 s3=#state ok p4=alpha|0 p5=alpha|0 s5=#state stale'

DG_WORLDS="w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13"
dg_all() { # <pool> <fixture root> <tag>
  local w
  for w in $DG_WORLDS; do "dg_w_$w" "$1" "$2" "$CK_W/dg.$3.$w" > "$CK_W/dg.$3.$w.got" 2>/dev/null; done
}
dg_want() { eval "printf '%s' \"\$DG_WANT_$1\""; }
# DG_WORLDS_END

if sg dg; then
DG_N=0
[ -n "$DERIVER" ] || printf '  SKIP  committed-digest worlds: derive-fixture-readsets.sh is in neither layout yet, so no digest can be seeded the way it writes one\n'
for _h in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -n "$DERIVER" ] || break
  [ -f "$_h" ] || continue
  DG_N=$((DG_N+1)); DG_P="$CK_W/dgpool.$DG_N.sh"
  pool_span "$_h" "$DG_P" FIXTURE_POOL && rs_rec_pin >> "$DG_P"
  DG_X="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$DG_P" | sort -u)"
  # Every world runs against the first hook only. I66 holds the two FIXTURE_POOL blocks to one program except
  # FXROOT, which ckw's (d, wiring) world drives end to end on the second hook.
  dg_all "$DG_P" "$DG_X" "h$DG_N"
  for _w in $DG_WORLDS; do
    DG_ARMS=$((DG_ARMS+1)); _g="$(cat "$CK_W/dg.h$DG_N.$_w.got")"
    if [ "$_g" = "$(dg_want "$_w")" ]; then ok "($_w) ${_h#"$ROOT"/}: $_g"
    else bad "($_w) ${_h#"$ROOT"/}: want '$(dg_want "$_w")' got '$_g'"; fi
  done
  break
done
if [ -n "$DERIVER" ]; then
  DG_ARMS=$((DG_ARMS+1))
  [ "$DG_N" -ge 1 ] && ok "the committed-digest worlds ran against the first of the hook(s)" || bad "no pre-push hook was found for the committed-digest worlds"
fi

fi

# ------------------------------------------------- `--reconcile` derives what to trace (BL-472) ----
# Five fixtures in a seeded repo whose runner carries the resolved hook's READSET_UNIVERSE span:
#   un  a run.sh and no committed row                         -> unmapped
#   st  mapped, digest matching, key record `#state stale`    -> stale
#   ch  mapped, digest taken BEFORE its input changed, record `#state ok` -> changed. NON-stale on
#       purpose: a stale ch would be listed for the stale reason, and a build that dropped reason (c)
#       would still name it.
#   cl  mapped, digest matching, record ok                    -> the clean control, never listed
#   nd  mapped, NO digest line, record ok, input changed      -> not listed: a digest-less row set cannot
#       be judged changed, and listing it would trace every pre-digest fixture on every reconcile.
# The list is driven from the deriver's READSET_RECONCILE span; the whole deriver is then driven through
# the stub stream, and must name exactly those three and trace exactly those three. A clean repo prints
# `nothing to reconcile`, exits 0 and never creates its trace root.
if sg rc; then
RC_ARMS=0
if [ -z "$DERIVER" ] || [ -z "${SX:-}" ]; then
  printf '  SKIP  --reconcile arms: no deriver, or the stub-stream world did not run (root)\n'
else
  RCS="$WORK/rc.span"
  { sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' "$HOOK"
    sed -n '/^# READSET_RECONCILE_BEGIN$/,/^# READSET_RECONCILE_END$/p' "$DERIVER"; } > "$RCS"
  grep -q '^readset_reconcile_list() {' "$RCS" || broken "no readset_reconcile_list in the deriver's READSET_RECONCILE span"
  # The span reads READSET_MAP and READSET_LOCAL, which the pool block binds; dg_digest sources this.
  { printf 'READSET_MAP=.ai-dlc-fixture-readsets.tsv\nREADSET_LOCAL=/dev/null\n'; cat "$RCS"; } > "$WORK/rc.pool"
  # The key records live in the world's own store, <repo>.vs, under fixture-keys/<root commit> (the hook's RECORD_HOME).
  rc_kd() { printf '%s.vs/fixture-keys/%s' "$1" "$(git -C "$1" rev-list --max-parents=0 HEAD)"; }
  rc_seed() { # <repo> <change ch: yes|no> <stale st: yes|no> <unmapped un: yes|no>
    local r="$1" f k
    mkdir -p "$r/.githooks" "$r/core/scripts" "$r/src" || return 1
    pool_span "$HOOK" "$WORK/rc.rh.span" READSET_UNIVERSE READSET_VS RECORD_HOME || return 1
    { printf '#!/bin/bash\nFXROOT="core/fixtures/"\n'; cat "$WORK/rc.rh.span"; } > "$r/.githooks/pre-push"
    cp "$SB/deriver.sh" "$r/core/scripts/derive-fixture-readsets.sh" || return 1
    : > "$r/.ai-dlc-fixture-readsets.tsv"
    for f in ch cl nd st ${4:+un}; do
      [ "$4" = no ] && [ "$f" = un ] && continue
      mkdir -p "$r/core/fixtures/$f" && printf '#!/bin/bash\nexit 0\n' > "$r/core/fixtures/$f/run.sh" || return 1
      [ "$f" = un ] && continue
      printf 'v1\n' > "$r/src/$f.sh"
      printf '%s\tsrc/%s.sh\n%s\tcore/fixtures/%s/run.sh\n' "$f" "$f" "$f" "$f" >> "$r/.ai-dlc-fixture-readsets.tsv"
    done
    ( cd "$r" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1 || return 1
    dg_digest "$WORK/rc.pool" "$r" ch cl st || return 1
    # rc_list hands the span the legacy path; it names the same records the whole deriver reads from the store.
    f="$(rc_kd "$r")" && mkdir -p "$f" && ln -s "$f" "$r/.git/ai-dlc-fixture-keys" || return 1
    for k in ch cl nd st; do printf '#format k1\n#state ok\n#tools per-fixture\n' > "$f/$k.key"; done
    [ "$3" = yes ] && printf '#format k1\n#state stale\n#tools per-fixture\n' > "$f/st.key"
    if [ "$2" = yes ]; then
      printf 'v2\n' > "$r/src/ch.sh"; printf 'v2\n' > "$r/src/nd.sh"
      ( cd "$r" && git add -A && git -c user.email=f@f -c user.name=f commit -qm change ) >/dev/null 2>&1 || return 1
    fi
  }
  rc_list() { # <span> <repo>: the derived list, one `fx:reason` per line joined by spaces
    ( cd "$2" && READSET_MAP=.ai-dlc-fixture-readsets.tsv && READSET_LOCAL=/dev/null && . "$1" \
      && fx_inproc "$DERIVER" && readset_reconcile_list core/fixtures .git/ai-dlc-fixture-keys "$(mktemp -d "$WORK/rcl.XXXXXX")/s" ) 2>/dev/null \
      | tr '\t' ':' | tr '\n' ' ' | sed 's/ $//'
  }
  RC="$WORK/rcrepo"; rc_seed "$RC" yes yes yes || broken "could not seed the --reconcile repo"
  RC_ARMS=$((RC_ARMS+1))
  RL="$(rc_list "$RCS" "$RC")"
  if [ "$RL" = "ch:changed st:stale un:unmapped" ]; then
    ok "RECONCILE: the list names exactly the changed (ch, non-stale), stale (st) and unmapped (un) fixtures, and neither the clean control cl nor the digest-less nd"
  else
    bad "RECONCILE: expected 'ch:changed st:stale un:unmapped', got '$RL'"
  fi
  printf '%s\n' core/fixtures/ch/run.sh core/fixtures/st/run.sh core/fixtures/un/run.sh > "$WORK/rc.sb"
  RC_TR="$(cd "$WORK" && pwd -P)/rc.tr"
  rc_run() { # <repo> <trace root>; prints "<rc>|<announce>|<listed>|<traced>"
    local r="$1" x
    ( cd "$r" && rs_drive -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH AI_DLC_VERDICT_STORE="$r.vs" PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$WORK/rc.sb" \
        AI_DLC_READSET_TRACE_ROOT="$2" -- core/scripts/derive-fixture-readsets.sh --reconcile ) > "$WORK/rc.out" 2>&1 </dev/null
    x=$?
    stub_reap "${SB:-}"
    ( cd "$r" && git checkout -q -- . ) >/dev/null 2>&1
    printf '%s|%s|%s|%s' "$x" "$(grep -m1 -E '^(--reconcile: [0-9]+ fixture|nothing to reconcile)' "$WORK/rc.out")" \
      "$(grep -E '^  [a-z]+[[:blank:]][a-z]+$' "$WORK/rc.out" | tr '\t' ':' | tr -d ' ' | tr '\n' ' ' | sed 's/ $//')" \
      "$(grep -oE '^  (ch|cl|nd|st|un) ' "$WORK/rc.out" | tr -d ' ' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
  }
  RC_ARMS=$((RC_ARMS+1))
  RR="$(rc_run "$RC" "$RC_TR")"
  if [ "$RR" = "0|--reconcile: 3 fixture(s) to trace:|ch:changed st:stale un:unmapped|ch st un" ]; then
    ok "RECONCILE: the whole deriver prints the three with their reasons, traces exactly ch, st and un, and exits 0"
  else
    bad "RECONCILE: expected '0|--reconcile: 3 fixture(s) to trace:|ch:changed st:stale un:unmapped|ch st un', got '$RR' — $(tail -3 "$WORK/rc.out" | tr '\n' ' ')"
  fi
  RC2="$WORK/rcclean"; rc_seed "$RC2" no no no || broken "could not seed the clean --reconcile repo"
  RC2_TR="$(cd "$WORK" && pwd -P)/rc2.tr"
  RC_ARMS=$((RC_ARMS+1))
  RR2="$(rc_run "$RC2" "$RC2_TR")"
  if [ "$RR2" = "0|nothing to reconcile||" ] && [ ! -e "$RC2_TR" ]; then
    ok "RECONCILE: a fully-mapped clean repo prints 'nothing to reconcile', exits 0, traces nothing and never creates its trace root"
  else
    bad "RECONCILE: a clean repo did not print 'nothing to reconcile' at 0 with no trace root: '$RR2' root $([ -e "$RC2_TR" ] && echo CREATED || echo absent)"
  fi
  if [ "$(id -u)" != 0 ]; then
    RC_ARMS=$((RC_ARMS+1))
    chmod 000 "$(rc_kd "$RC2")"
    RR3="$(rc_run "$RC2" "$RC2_TR")"
    chmod 755 "$(rc_kd "$RC2")"
    case "$RR3" in
      1*) if grep -q 'cannot read the key records' "$WORK/rc.out"; then ok "RECONCILE: an unreadable key-record directory REFUSES at 1 rather than reading as 'no stale record'"
          else bad "RECONCILE: an unreadable keys dir exited 1 without naming it: $(tail -2 "$WORK/rc.out" | tr '\n' ' ')"; fi ;;
      *) bad "RECONCILE: an unreadable keys dir did not refuse: '$RR3'" ;;
    esac
  fi
  RC_ARMS=$((RC_ARMS+1))
  printf '#!/bin/bash\nFXROOT="core/fixtures/"\n' > "$RC2/.githooks/pre-push"
  RR4="$(rc_run "$RC2" "$RC2_TR")"
  ( cd "$RC2" && git checkout -q -- .githooks/pre-push ) >/dev/null 2>&1
  case "$RR4" in
    1*) if grep -q 'needs the READSET_UNIVERSE span' "$WORK/rc.out"; then ok "RECONCILE: a runner with no READSET_UNIVERSE span REFUSES at 1, because a changed read set cannot be judged without it"
        else bad "RECONCILE: a span-less runner exited 1 without naming the span: $(tail -2 "$WORK/rc.out" | tr '\n' ' ')"; fi ;;
    *) bad "RECONCILE: a span-less runner did not refuse: '$RR4'" ;;
  esac
fi

fi

# -------------------------------------------------- the shared verdict store (unit vs) ----
# A DECLARED fixture's pass is keyed on content alone, so a pass recorded in one clone is valid in any other clone at
# any path. hermetic-run.sh writes `$AI_DLC_VERDICT_STORE/<sha256 of body>` on a clean pass (rc 0, no REQUIRED input
# missing) and is the store's ONLY writer; the hook's decision turns a
# declared `run` into a `skip` (c `v`) when the store holds that entry. The body is the fixture name, the sha of the
# runner, the sha of the hook spans the runner sources, and the --key-only rows, so a pass under an older runner or
# universe is not reused. The reader fails closed. Undeclared fixtures never read the store.
# THE OVERRIDE IS PASSED ON EACH COMMAND, never exported: this file scrubs AI_DLC_* at its top, so an export made
# before the scrub would silently fall back to the default path and pass against whatever is there. Arm (a) asserts the
# override directory holds entries, and the real default store is snapshotted before and after the unit.
#   p  per project: the store is <base>/<root commit>; a file:// clone shares, another root commit does not, an unresolvable one is OFF
#   a  A's hermetic pass -> B (clone, other path, identical tree) SKIPS; announced by name; the store holds entries
#   b  one declared input byte changed in B -> RUN (the pass was recorded on a different tree)
#   t  A's own declared input changed after its pass -> RUN; B's fixture-own file added -> RUN
#   g  one byte added inside the runner's HR_SANDBOX span -> RUN; a line added inside the READSET_UNIVERSE span -> RUN;
#      g3/g4, edits OUTSIDE the runner's HR_SANDBOX span (store code, a trailing comment), SKIP: the declared key
#      carries the runner's span sha (readset_decl_keys' runner row), never its whole-file hash
#   c  failed run, REQUIRED-sentinel-missing run, undeclared run: nothing written; their fixtures RUN in B
#   d  an entry planted for an UNDECLARED fixture is ignored; the same plant for a declared one skips (the control)
#   e  truncated, emptied, edited entry -> RUN; the restored entry skips (the control)
#   f  an unwritable store, and no store and no HOME, drop the record and never fail the run
#   h  the hook writes NO store entry (readset_keys_write publishes ok records only); the runner writes one (the control)
VS_ARMS=0
if sg vs; then
VS_RUN=""
for _c in "$ROOT/core/scripts/hermetic-run.sh" "$ROOT/scripts/ai-dlc/hermetic-run.sh"; do [ -f "$_c" ] && { VS_RUN="$_c"; break; }; done
if [ -z "$VS_RUN" ]; then
  printf '  SKIP  verdict-store arms: no hermetic-run.sh in either layout\n'
else
echo "HERMETIC-CONSUMED ${VS_RUN#"$ROOT"/}"
VS_REAL_HOME="$(eval "printf '%s' ~$(id -un)")"
# Scored on the entries THIS unit could write (its own fixture names), because a peer session running real fixtures writes real entries into the default store concurrently.
# The real store holds thousands of entries and grows with every recorded pass, so the selection is ONE
# batched grep over the C-sorted list rather than a grep per file; `grep -l` prints its matches in
# argument order, so the set, the order and the digest are the per-file loop's (the receipt below).
vs_snap() { find "$1/.cache/ai-dlc/verdicts" -type f -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 grep -lxE '#fixture (decl|bad|nosent|undecl)' 2>/dev/null | while IFS= read -r _f; do printf '%s ' "$_f"; md5 -q "$_f"; done | md5 -q; }
# THE RECEIPT: on a seeded store carrying an empty file, a name with a space, a nested directory and a
# non-matching entry, vs_snap equals the per-file loop it replaced. The seed is CREATED in a
# fixed shuffle -- neither C order nor its reverse, which a creation-order or newest-first listing would
# return sorted -- so the order the sort imposes is observed.
vs_snap_ref() { find "$1/.cache/ai-dlc/verdicts" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r _f; do grep -lxE '#fixture (decl|bad|nosent|undecl)' "$_f" 2>/dev/null; done | while IFS= read -r _f; do printf '%s ' "$_f"; md5 -q "$_f"; done | md5 -q; }
VS_SR="$WORK/vs.snaprcpt"; _v="$VS_SR/.cache/ai-dlc/verdicts"
mkdir -p "$_v/sub dir" || broken "could not seed the vs_snap receipt store"
for _i in 13 24 02 19 07 22 11 04 16 09 21 01 18 06 14 23 03 12 20 08 15 05 17 10; do printf '#fixture decl\nk %s\n' "$_i" > "$_v/k$_i"; done
printf '#fixture bad\n' > "$_v/sub dir/with space"; : > "$_v/empty"; printf '#fixture other\n' > "$_v/nomatch"
_sel="$(vs_snap_ref "$VS_SR")"; _nsel="$(find "$_v" -type f | LC_ALL=C sort | while IFS= read -r _f; do grep -lxE '#fixture (decl|bad|nosent|undecl)' "$_f" || :; done | grep -c .)" || _nsel=0
VS_ARMS=$((VS_ARMS+1))
if [ "$(vs_snap "$VS_SR")" = "$_sel" ] && [ "$_nsel" -eq 25 ]; then ok "vs_snap equals the per-file loop on a 27-entry store (25 selected; an empty file, a space, a subdirectory, a non-match)"
else bad "vs_snap differs from the per-file loop on the seeded store (selected $_nsel, want 25)"; fi
VS_SNAP0="$(vs_snap "$VS_REAL_HOME")"; VS_SNAPH0="$(vs_snap "$HOME")"
VS_DRV="$WORK/vs.drive.sh"
printf '%s\n' 'cd "$2" || exit 1' '. "$1" 2>/dev/null' \
  'for d in "$FXROOT"*/; do [ -f "$d/run.sh" ] && printf "%s\n" "$d"; done > "$3/list"' \
  'apply_readset_skip "$3/list" "$3" > "$3/ann" 2>&1' > "$VS_DRV" || broken "could not write the verdict-store decision driver"
vs_dec() { # <pool> <t> <store> <tag> -> decision dir $t.vd.<tag>
  mkdir -p "$2.vd.$4" && ( inproc AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_VERDICT_STORE="$3" PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin" -- "$VS_DRV" "$1" "$2" "$2.vd.$4" )
}
vs_cell() { awk -F'\t' -v f="$2" '$1 == f && ($2 == "run" || $2 == "skip") { printf "%s", $2 }' "$1/.kdec" 2>/dev/null; }
vs_hr() { # <runner> <root> <fx> <store>: runs the declared fixture; prints its exit code
  ( inproc AI_DLC_VERDICT_STORE="$4" -- "$1" --root "$2" "$3" ) >/dev/null 2>&1; printf '%s' "$?"
}
vs_n() { find "$1" -maxdepth 1 -type f ! -name '.tmp*' 2>/dev/null | grep -c . || :; }
vs_mk() { # <t> <fixture root> <runner file>: a git repo holding the hook, the runner and four fixtures
  local t="$1" x="$2" f rd
  mkdir -p "$t/.githooks" "$t/src" || return 1
  cp "$HOOK" "$t/.githooks/pre-push" || return 1
  case "$x" in core/fixtures) rd=core/scripts ;; *) rd=scripts/ai-dlc ;; esac
  mkdir -p "$t/$rd" && cp "$3" "$t/$rd/hermetic-run.sh" || return 1
  printf 'v1\n' > "$t/src/a.sh"
  for f in decl bad nosent undecl; do mkdir -p "$t/$x/$f" || return 1; done
  printf '%s\n' 'if [ -f src/a.sh ]; then echo "HERMETIC-CONSUMED src/a.sh"; fi' 'exit 0' > "$t/$x/decl/run.sh"
  printf '%s\n' 'echo "HERMETIC-CONSUMED src/a.sh"' 'exit 1' > "$t/$x/bad/run.sh"
  printf '%s\n' 'exit 0' > "$t/$x/nosent/run.sh"; printf '%s\n' 'exit 0' > "$t/$x/undecl/run.sh"
  for f in decl bad nosent; do printf '!src/a.sh\n' > "$t/$x/$f/inputs.decl"; done
  ( cd "$t" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
}
vs_plant() { # <pool> <t> <decision dir> <store> <fx>: the entry the digest names, built from the hook's own functions
  ( cd "$2" || exit 1
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$1" 2>/dev/null
    fx_inproc "$ROOT/core/git-hooks/pre-push"; id="$(readset_vs_ident_here)" || exit 1
    grep -v '^#' "$3/.k/$5" > "$3/.pl.rows" && [ -s "$3/.pl.rows" ] || exit 1
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    readset_vs_input "$5" "$id" "$3/.pl.rows" > "$3/.pl.d" || exit 1
    mkdir -p "$4" && { printf '#format k1\n#state ok\n'; cat "$3/.pl.d"; printf '#pending 0\n'; } > "$4/$(shasum -a 256 < "$3/.pl.d" | cut -d' ' -f1)" )
}
vs_world() { # <pool> <fixture root> <runner file> <t> [<cells>]: one vector
  # <cells>, when given, is a space-joined subset of b t g e d f p: the base (rcd..ann, A's four runs, the
  # clone and decision a, which every later cell reads) always runs, and only the named later cells are
  # driven and printed. Empty or absent drives every cell.
  local p="$1" x="$2" rn="$3" t="$4" SB="$4.S" S A="$4/A" B="$4/B" rd e v n1 rcs ra cs=" ${5:-b t g e d f p w} "
  case "$x" in core/fixtures) rd=core/scripts ;; *) rd=scripts/ai-dlc ;; esac
  mkdir -p "$t" "$SB" || { printf SEED; return; }
  vs_mk "$A" "$x" "$rn" || { printf SEED; return; }
  # decl declares a second, unrequired path here, so cell w can NARROW it with every path still keyed
  printf 'v1\n' > "$A/src/b.sh" && printf '!src/a.sh\nsrc/b.sh\n' > "$A/$x/decl/inputs.decl" \
    && ( cd "$A" && git add -A && git -c user.email=f@f -c user.name=f commit -qm wide ) >/dev/null 2>&1 || { printf SEED; return; }
  ra="$(cd "$A" && git rev-list --max-parents=0 HEAD | sed -n 1p)"; S="$SB/$ra"
  v="rcd=$(vs_hr "$A/$rd/hermetic-run.sh" "$A" decl "$SB") rcb=$(vs_hr "$A/$rd/hermetic-run.sh" "$A" bad "$SB") rcn=$(vs_hr "$A/$rd/hermetic-run.sh" "$A" nosent "$SB") rcu=$(vs_hr "$A/$rd/hermetic-run.sh" "$A" undecl "$SB")"
  n1="$(vs_n "$S")"
  git clone -q "file://$A" "$B" >/dev/null 2>&1 || { printf CLONE; return; }
  vs_dec "$p" "$B" "$SB" a
  v="$v a=$(vs_cell "$B.vd.a" decl)/$(vs_cell "$B.vd.a" bad)/$(vs_cell "$B.vd.a" nosent)/$(vs_cell "$B.vd.a" undecl) n=$n1"
  v="$v ann=$(grep -cxF '   ..    verdict store: 1 fixture(s) skipped on a pass recorded elsewhere: decl' "$B.vd.a/ann" 2>/dev/null)"
  case "$cs" in *" b "*)
  printf 'v2\n' > "$B/src/a.sh"; vs_dec "$p" "$B" "$SB" b; printf 'v1\n' > "$B/src/a.sh"
  v="$v b=$(vs_cell "$B.vd.b" decl)" ;; esac
  case "$cs" in *" t "*)
  printf 'v2\n' > "$A/src/a.sh"; vs_dec "$p" "$A" "$SB" t1; printf 'v1\n' > "$A/src/a.sh"
  printf 'x\n' > "$B/$x/decl/extra.txt"; vs_dec "$p" "$B" "$SB" t2; rm -f "$B/$x/decl/extra.txt"
  v="$v t=$(vs_cell "$A.vd.t1" decl)/$(vs_cell "$B.vd.t2" decl)" ;; esac
  case "$cs" in *" g "*)
  cp "$B/$rd/hermetic-run.sh" "$t/rn.save"
  sed 's/^HR_ROOT_OPT=""$/HR_ROOT_OPT=""; : x/' "$t/rn.save" > "$B/$rd/hermetic-run.sh"; vs_dec "$p" "$B" "$SB" g1
  sed 's/^  hr_population key || return 0$/  : x; hr_population key || return 0/' "$t/rn.save" > "$B/$rd/hermetic-run.sh"; vs_dec "$p" "$B" "$SB" g3
  printf '# trailing\n' >> "$B/$rd/hermetic-run.sh"; vs_dec "$p" "$B" "$SB" g4
  cp "$t/rn.save" "$B/$rd/hermetic-run.sh"
  cp "$B/.githooks/pre-push" "$t/hk.save"
  sed 's/^# READSET_UNIVERSE_BEGIN$/&\n# one more line/' "$t/hk.save" > "$B/.githooks/pre-push"; vs_dec "$p" "$B" "$SB" g2; cp "$t/hk.save" "$B/.githooks/pre-push"
  # g5: READSET_VS_FORMAT bumped in B's hook alone (the runner's bytes unchanged) moves `#universe`, so A's pass is
  # not reused. g2, a comment line inside READSET_UNIVERSE, and g6, the same line outside every span, are reused: the
  # identity is a format version, not a hash of code. The bump must apply to exactly one line, or the cell reads BADINS.
  awk '/^READSET_VS_FORMAT=[0-9]+$/ { split($0, a, "="); $0 = "READSET_VS_FORMAT=" (a[2] + 1) } { print }' "$t/hk.save" > "$B/.githooks/pre-push"
  if ! cmp -s "$t/hk.save" "$B/.githooks/pre-push" && [ "$(grep -c '^READSET_VS_FORMAT=' "$B/.githooks/pre-push")" = 1 ]; then
    vs_dec "$p" "$B" "$SB" g5; g5="$(vs_cell "$B.vd.g5" decl)"; else g5=BADINS; fi
  awk '{ print } NR == 1 { print "# one more line" }' "$t/hk.save" > "$B/.githooks/pre-push"; vs_dec "$p" "$B" "$SB" g6
  cp "$t/hk.save" "$B/.githooks/pre-push"
  v="$v g=$(vs_cell "$B.vd.g1" decl)/$(vs_cell "$B.vd.g2" decl)/$(vs_cell "$B.vd.g3" decl)/$(vs_cell "$B.vd.g4" decl)/$g5/$(vs_cell "$B.vd.g6" decl)" ;; esac
  case "$cs" in *" e "*)
  e="$(find "$S" -maxdepth 1 -type f ! -name '.tmp*' | LC_ALL=C sort | while IFS= read -r _f; do grep -qxF '#fixture decl' "$_f" && { printf '%s' "$_f"; break; }; done)"
  if [ -f "$e" ]; then
    cp "$e" "$t/e.save"
    head -c 120 "$t/e.save" > "$e"; vs_dec "$p" "$B" "$SB" e1
    : > "$e"; vs_dec "$p" "$B" "$SB" e2
    sed '3s/decl/dec1/' "$t/e.save" > "$e"; vs_dec "$p" "$B" "$SB" e3
    cp "$t/e.save" "$e"; vs_dec "$p" "$B" "$SB" e4
    v="$v e=$(vs_cell "$B.vd.e1" decl)/$(vs_cell "$B.vd.e2" decl)/$(vs_cell "$B.vd.e3" decl)/$(vs_cell "$B.vd.e4" decl)"
  else v="$v e=NOENTRY"; fi ;; esac
  case "$cs" in *" d "*)
  rm -rf "$t.S2"; vs_plant "$p" "$B" "$B.vd.a" "$t.S2/$ra" undecl || v="$v PLANTFAIL"
  vs_dec "$p" "$B" "$t.S2" d1
  vs_plant "$p" "$B" "$B.vd.a" "$t.S2/$ra" decl || v="$v PLANTFAIL"
  vs_dec "$p" "$B" "$t.S2" d2
  v="$v d=$(vs_cell "$B.vd.d1" undecl)/$(vs_cell "$B.vd.d2" undecl)/$(vs_cell "$B.vd.d2" decl)" ;; esac
  case "$cs" in *" f "*)
  : > "$t.notadir"
  rcs="$(vs_hr "$A/$rd/hermetic-run.sh" "$A" decl "$t.notadir")"
  v="$v f=$rcs/$( ( inproc -u HOME -u AI_DLC_VERDICT_STORE -- "$A/$rd/hermetic-run.sh" --root "$A" decl ) >/dev/null 2>&1; printf '%s' "$?")/$([ -f "$t.notadir" ] && [ ! -s "$t.notadir" ] && echo intact)" ;; esac
  case "$cs" in *" p "*)
  mkdir -p "$t/C2" && cp -R "$A/." "$t/C2/" && rm -rf "$t/C2/.git" \
    && ( cd "$t/C2" && git init -q . && git add -A && git -c user.email=f@f -c user.name=g commit -qm other ) >/dev/null 2>&1
  vs_dec "$p" "$t/C2" "$SB" p1
  git clone -q --depth 1 "file://$A" "$t/Sh" >/dev/null 2>&1; vs_dec "$p" "$t/Sh" "$SB" p2
  vs_hr "$A/$rd/hermetic-run.sh" "$t/Sh" decl "$t.S3" >/dev/null 2>&1
  v="$v p=$(vs_cell "$t/C2.vd.p1" decl)/$(vs_cell "$t/Sh.vd.p2" decl)/$(grep -c 'verdict store OFF' "$t/Sh.vd.p2/ann" 2>/dev/null)/$(ls -A "$t.S3" 2>/dev/null | grep -c .)" ;; esac
  # w: B's decl NARROWED to `!src/a.sh` against A's pass under the wider declaration -> run (a's decl=skip is its twin)
  case "$cs" in *" w "*)
  cp "$B/$x/decl/inputs.decl" "$t/w.save"; printf '!src/a.sh\n' > "$B/$x/decl/inputs.decl"; vs_dec "$p" "$B" "$SB" w
  cp "$t/w.save" "$B/$x/decl/inputs.decl"
  v="$v w=$(vs_cell "$B.vd.w" decl)" ;; esac
  printf '%s' "$v"
}
VS_WANT='rcd=0 rcb=1 rcn=1 rcu=2 a=skip/run/run/run n=1 ann=1 b=run t=run/run g=run/skip/skip/skip/run/skip e=run/run/run/skip d=run/run/skip f=0/0/intact p=run/run/1/0 w=run'
# (v) THE SPAN CANNOT GO VACUOUS: the digested runner span is non-empty and still holds the env -i line and the copy loop.
VS_ARMS=$((VS_ARMS+1)); sed -n '/^# HR_SANDBOX_BEGIN$/,/^# HR_SANDBOX_END$/p' "$VS_RUN" > "$WORK/vs.span"
if [ "$(grep -c . "$WORK/vs.span")" -gt 50 ] && grep -qF 'env -i PATH=' "$WORK/vs.span" && grep -qF 'cp -Rp "$HR_FXDIR/."' "$WORK/vs.span" \
   && grep -qF 'REQUIRED input' "$WORK/vs.span" && ! grep -qF 'hr_store_put' "$WORK/vs.span"; then ok "(verdict store, v) the HR_SANDBOX span is non-empty, holds the env -i invocation, the copy loop and the REQUIRED check, and no store code"
else bad "(verdict store, v) the HR_SANDBOX span is empty, lost the env -i line, the copy or the REQUIRED check, or holds store code"; fi
VS_N=0
for _h in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$_h" ] || continue
  VS_N=$((VS_N+1)); VS_P="$WORK/vspool.$VS_N.sh"
  pool_span "$_h" "$VS_P" FIXTURE_POOL && rs_rec_pin >> "$VS_P"
  VS_X="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$VS_P" | sort -u)"
  [ "$VS_N" -eq 1 ] && { VS_P1="$VS_P"; VS_X1="$VS_X"; }
  VS_ARMS=$((VS_ARMS+1)); _g="$(vs_world "$VS_P" "$VS_X" "$VS_RUN" "$WORK/vs.h$VS_N" 2>/dev/null)"
  if [ "$_g" = "$VS_WANT" ]; then ok "(verdict store) ${_h#"$ROOT"/}: $_g"
  else bad "(verdict store) ${_h#"$ROOT"/}: want '$VS_WANT' got '$_g'"; fi
done
# (h) the hook writes NO store entry: the runner is the store's only writer. Control: the runner writes one for the same tree.
vs_h() { # <pool> <fixture root> <t>
  local p="$1" x="$2" t="$3" S="$3.S" C="$3/C" rd o
  case "$x" in core/fixtures) rd=core/scripts ;; *) rd=scripts/ai-dlc ;; esac
  local rc
  mkdir -p "$t" "$S" && vs_mk "$C" "$x" "$VS_RUN" || { printf SEED; return; }
  rc="$(cd "$C" && git rev-list --max-parents=0 HEAD | sed -n 1p)"
  vs_hr "$C/$rd/hermetic-run.sh" "$C" decl "$S" >/dev/null
  o="$(vs_n "$S/$rc")"
  rm -rf "$S"; mkdir -p "$S"
  vs_dec "$p" "$C" "$S" h
  ( cd "$C" && AI_DLC_VERDICT_STORE="$S" && export AI_DLC_VERDICT_STORE && fx_inproc "$ROOT/core/git-hooks/pre-push" && . "$p" 2>/dev/null && printf 'ok' > "$C.vd.h/decl" && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_keys_write "$C.vd.h" ) >/dev/null 2>&1
  printf 'runner=%s hook=%s rec=%s' "$o" "$(vs_n "$S/$rc")" "$([ -f "$C.vd.h/.k/decl" ] && echo 1 || echo 0)"
}
if [ "$VS_N" -ge 1 ]; then
  VS_ARMS=$((VS_ARMS+1)); _g="$(vs_h "$VS_P1" "$VS_X1" "$WORK/vs.hw" 2>/dev/null)"
  [ "$_g" = "runner=1 hook=0 rec=1" ] && ok "(verdict store, h) the hook writes no store entry for a declared fixture it records ok, where the runner writes one: $_g" \
    || bad "(verdict store, h) want 'runner=1 hook=0 rec=1' got '$_g'"
fi
# (k) THE KEY CENSUS: the rows the hook digests for a declared fixture's store entry (`.k/<fx>` after readset_keys)
# must equal the rows `hermetic-run.sh --key-only` prints, because the runner writes the entry the hook looks up and
# one differing row makes every recorded pass unfindable. A SYNTHETIC world holding the shapes that have diverged, so
# the unit stays keyed on the two hooks and the runner alone (a census over the real tree hashes the whole universe
# and would key this fixture on every file). Each world is driven TWICE through the hook's own functions, the way a
# push decides: fresh, then with every record republished `ok` and one foreign row injected, so the record-carry
# path (an `ok` record's keys carried into X while it holds a listing key) runs.
#   cen  a declared file, a declared dir with a nested subdir (listing keys), a declared dir under an excluded top, a tool
#   ctl  a declared file and two tools, no listing key: the shape on which the two sides agree (the inverse control).
#        Its second tool, cksum, is named by NO `.sh` in the world, so only the declared-tool hashing can key it (a
#        tool some world `.sh` mentions is hashed by readset_tools anyway).
#   ref  `src/a.sh` and `lib/`: the normalisation reference
#   dsl  the same with `lib//`: the shared parse strips EVERY trailing slash, so it keys exactly as ref
#   crlf the same with CRLF line ends: the shared parse strips the CR, so it keys exactly as ref
#   cons (consumer layout only, scripts/ai-dlc/core-paths.sh present) `core/scripts/m.sh` and `core/skills/mk/`:
#        both sides key the MAPPED paths, `scripts/ai-dlc/m.sh` and `.claude/skills/mk/`, and no `core/` row
# The world's declared fixture names are written to <t>.fx, in census order.
vs_cmk() { # <t> <fixture root> <runner file> <hook file>
  local t="$1" x="$2" rd f
  case "$x" in core/fixtures) rd=core/scripts ;; *) rd=scripts/ai-dlc ;; esac
  mkdir -p "$t/.githooks" "$t/scripts" "$t/$rd" "$t/src" "$t/lib/sub" "$t/docs" || return 1
  cp "$4" "$t/.githooks/pre-push" && cp "$3" "$t/$rd/hermetic-run.sh" || return 1
  printf '# EXCLUDE_BEGIN\ndocs\n# EXCLUDE_END\n' > "$t/scripts/suite-content-key.sh"
  printf 'v1\n' > "$t/src/a.sh"; printf 'l\n' > "$t/lib/l.txt"; printf 's\n' > "$t/lib/sub/s.txt"; printf 'n\n' > "$t/docs/n.md"
  printf '%s' 'ctl cen ref dsl crlf' > "$t.fx"
  for f in cen ctl ref dsl crlf; do mkdir -p "$t/$x/$f" && printf 'exit 0\n' > "$t/$x/$f/run.sh" && printf 'awk\n' > "$t/$x/$f/tools.decl" || return 1; done
  printf 'awk\ncksum\n' > "$t/$x/ctl/tools.decl"
  printf 'src/a.sh\nlib/\ndocs/\n' > "$t/$x/cen/inputs.decl"; printf 'src/a.sh\n' > "$t/$x/ctl/inputs.decl"
  printf 'src/a.sh\nlib/\n' > "$t/$x/ref/inputs.decl"; printf 'src/a.sh\nlib//\n' > "$t/$x/dsl/inputs.decl"
  printf 'src/a.sh\r\nlib/\r\n' > "$t/$x/crlf/inputs.decl"
  if [ "$rd" = scripts/ai-dlc ]; then
    # The mapper comes from beside the REAL runner, never beside <runner file>.
    cp "${VS_RUN%/*}/core-paths.sh" "$t/$rd/core-paths.sh" || return 1
    mkdir -p "$t/$x/cons" "$t/.claude/skills/mk/in" || return 1
    printf 'm\n' > "$t/$rd/m.sh"; printf 'k\n' > "$t/.claude/skills/mk/in/k.txt"; printf 'j\n' > "$t/.claude/skills/mk/j.txt"
    printf 'exit 0\n' > "$t/$x/cons/run.sh"; printf 'awk\n' > "$t/$x/cons/tools.decl"
    printf 'src/a.sh\ncore/scripts/m.sh\ncore/skills/mk/\n' > "$t/$x/cons/inputs.decl"
    printf '%s' ' cons' >> "$t.fx"
  fi
  ( cd "$t" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1
}
vs_cdrive() { # <pool> <world> <runner file>: decisions in <world>.cd/d1 (fresh) and <world>.cd/d2 (republished records, one foreign row each)
  ( cd "$2" || exit 1
    AI_DLC_READSET_LIVE_TRACE=0; AI_DLC_VERDICT_STORE="$2.cd/store"; export AI_DLC_READSET_LIVE_TRACE AI_DLC_VERDICT_STORE
    fx_inproc "$ROOT/core/git-hooks/pre-push"
    # shellcheck disable=SC1090
    . "$1" 2>/dev/null
    o="$2.cd"; mkdir -p "$o/d1" "$o/d2" || exit 1
    KEYS_DIR="$o/keys"; VERIFIED_RECORD="$o/none"; READSET_LOCAL="$o/none.l"
    fl="$(cat "$2.fx")" && [ -n "$fl" ] || exit 1
    for d in "$FXROOT"*/; do [ -f "$d/run.sh" ] && printf '%s\n' "$d"; done > "$o/list"
    fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_manifest "$o/d1" && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_local_validate "$o/list" "$o/d1" && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_keys "$o/list" "$o/d1" || exit 1
    # The runner's rows for THIS tree, taken per pass, because the tree changes between them (below).
    for f in $fl; do ( inproc -u AI_DLC_VERDICT_STORE -- "$3" --root "$2" --key-only "$f" ) > "$o/d1/ko.$f" 2>/dev/null; done
    mkdir -p "$KEYS_DIR" || exit 1
    for f in "$o/d1/.k"/*; do [ -f "$f" ] || continue; b="${f##*/}"
      { sed -n 1p "$f"; printf '#state ok\n'; sed -n 3p "$f"; tail -n +4 "$f"; printf 'zz-foreign/%s\t0000\n' "$b"; } > "$KEYS_DIR/$b.key"; done
    cp "$o/d1/.now" "$KEYS_DIR/.prev"
    # A declared input changes between the passes, so each shape decides `run` and PUBLISHES its record: a
    # record whose only difference from the tree is the foreign row is a `skip` under the single-sourced key,
    # which publishes nothing and leaves no rows to compare. Both shapes declare src/a.sh.
    printf 'v2\n' > src/a.sh
    fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_manifest "$o/d2" && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_local_validate "$o/list" "$o/d2" && fx_inproc "$ROOT/core/git-hooks/pre-push" && readset_keys "$o/list" "$o/d2" || exit 1
    for f in $fl; do ( inproc -u AI_DLC_VERDICT_STORE -- "$3" --root "$2" --key-only "$f" ) > "$o/d2/ko.$f" 2>/dev/null; done ) >/dev/null 2>&1
}
vs_census() { # <pool> <fixture root> <runner file> <t> <hook file>: "inj=<n> ctl=<fresh>/<carry> cen=<fresh>/<carry>"
  local p="$1" x="$2" t="$4" W="$4/W" rd f ps v n c
  case "$x" in core/fixtures) rd=core/scripts ;; *) rd=scripts/ai-dlc ;; esac
  mkdir -p "$t" && vs_cmk "$W" "$x" "$3" "$5" || { printf SEED; return; }
  vs_cdrive "$p" "$W" "$W/$rd/hermetic-run.sh" || { printf DRIVE; return; }
  v="inj=$(grep -l '^zz-foreign/' "$W.cd/keys"/*.key 2>/dev/null | grep -c .)"
  for f in $(cat "$W.fx"); do
    c=""
    for ps in d1 d2; do
      [ -s "$W.cd/$ps/ko.$f" ] || { c="$c/KO"; continue; }
      grep -v '^#' "$W.cd/$ps/.k/$f" > "$t/hk.$f.$ps" 2>/dev/null && [ -s "$t/hk.$f.$ps" ] || { c="$c/NOK"; continue; }
      if cmp -s "$W.cd/$ps/ko.$f" "$t/hk.$f.$ps"; then c="$c/same"
      else n="$(diff "$W.cd/$ps/ko.$f" "$t/hk.$f.$ps" | grep -c '^[<>]')"
        c="$c/differ:$n:$(diff "$W.cd/$ps/ko.$f" "$t/hk.$f.$ps" | grep '^[<>]' | head -1 | tr ' \t' '__')"; fi
    done
    v="$v $f=${c#/}"
  done
  printf '%s' "$v"
}
# THE REGRESSION BYTE-COMPARE: every shape, both hooks, fresh and carried. The fixture list differs by layout (cons is
# seeded in the consumer world only), so the want is named per layout rather than derived from what ran.
VS_CWANT_D='inj=5 ctl=same/same cen=same/same ref=same/same dsl=same/same crlf=same/same'
VS_CWANT_C='inj=6 ctl=same/same cen=same/same ref=same/same dsl=same/same crlf=same/same cons=same/same'
vs_cwant() { case "$1" in core/fixtures) printf '%s' "$VS_CWANT_D" ;; *) printf '%s' "$VS_CWANT_C" ;; esac; }
# THE NORMALISATION CELLS, read off a census world's fresh pass on BOTH sides: ref, dsl and crlf with each fixture's
# own-directory rows removed must be the same rows, and those rows must hold the listing keys of lib/ and lib/sub/ and
# no `lib//` row (the positive conjunct: three EMPTY row sets are also equal). cons, where seeded: the mapped file and
# the mapped directory's listing are keyed and no row names core/. Prints
# "dsl=<eq|ne> crlf=<eq|ne> lib=<n> sub=<n> dbl=<n> cons=<file>/<listing>/<core rows>|-" per side, `hk:` then `ko:`.
vs_cnorm() { # <census t> <fixture root>
  local t="$1" x="$2" W="$1/W" s f src v="" ok r
  for s in hk ko; do
    for f in ref dsl crlf cons; do
      if [ "$s" = hk ]; then src="$W.cd/d1/.k/$f"; [ -f "$src" ] && grep -v '^#' "$src" > "$t/n.$s.$f.all" || : > "$t/n.$s.$f.all"
      else src="$W.cd/d1/ko.$f"; [ -f "$src" ] && cp "$src" "$t/n.$s.$f.all" || : > "$t/n.$s.$f.all"; fi
      awk -F'\t' -v o="$x/$f/" 'index($1, o) != 1' "$t/n.$s.$f.all" > "$t/n.$s.$f"
    done
    r="$s:"
    if cmp -s "$t/n.$s.ref" "$t/n.$s.dsl"; then r="$r dsl=eq"; else r="$r dsl=ne"; fi
    if cmp -s "$t/n.$s.ref" "$t/n.$s.crlf"; then r="$r crlf=eq"; else r="$r crlf=ne"; fi
    ok="$(grep -c '^lib/	#listing:' "$t/n.$s.dsl")" || ok=0; r="$r lib=$ok"
    ok="$(grep -c '^lib/sub/	#listing:' "$t/n.$s.dsl")" || ok=0; r="$r sub=$ok"
    ok="$(grep -c '^lib//' "$t/n.$s.dsl")" || ok=0; r="$r dbl=$ok"
    if [ -s "$t/n.$s.cons.all" ]; then
      r="$r cons=$(grep -c '^scripts/ai-dlc/m\.sh	[0-9a-f]\{64\}$' "$t/n.$s.cons")/$(grep -c '^\.claude/skills/mk/	#listing:' "$t/n.$s.cons")/$(grep -c '^core/' "$t/n.$s.cons")"
    else r="$r cons=-"; fi
    v="$v $r"
  done
  printf '%s' "${v# }"
}
vs_cnwant() { # <fixture root>
  case "$1" in core/fixtures) printf 'hk: dsl=eq crlf=eq lib=1 sub=1 dbl=0 cons=- ko: dsl=eq crlf=eq lib=1 sub=1 dbl=0 cons=-' ;;
    *) printf 'hk: dsl=eq crlf=eq lib=1 sub=1 dbl=0 cons=1/1/0 ko: dsl=eq crlf=eq lib=1 sub=1 dbl=0 cons=1/1/0' ;; esac
}
VS_CN=0
for _h in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$_h" ] || continue
  VS_CN=$((VS_CN+1)); VS_CP="$WORK/vscpool.$VS_CN.sh"
  pool_span "$_h" "$VS_CP" FIXTURE_POOL && rs_rec_pin >> "$VS_CP"
  VS_CX="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$VS_CP" | sort -u)"
  [ "$VS_CN" -eq 1 ] && { VS_CX1="$VS_CX"; VS_CH1="$_h"; }
  _g="$(vs_census "$VS_CP" "$VS_CX" "$VS_RUN" "$WORK/vs.c$VS_CN" "$_h" 2>/dev/null)"
  VS_ARMS=$((VS_ARMS+1))
  case "$_g" in *" ctl=same/same "*) ok "(verdict store, k) ${_h#"$ROOT"/}: the agreeing shape (ctl) is identical fresh and after the carry -- the census can pass" ;;
    *) bad "(verdict store, k) ${_h#"$ROOT"/}: the control shape ctl does not agree: $_g" ;; esac
  VS_ARMS=$((VS_ARMS+1)); _w="$(vs_cwant "$VS_CX")"
  if [ "$_g" = "$_w" ]; then ok "(verdict store, k) ${_h#"$ROOT"/}: hook key rows equal --key-only for every declared shape, fresh and carried: $_g"
  else bad "(verdict store, k) ${_h#"$ROOT"/}: hook key rows differ from --key-only (fixture=fresh/carry, differ:<rows>:<first row>): want '$_w' got '$_g'"; fi
  VS_ARMS=$((VS_ARMS+1)); _n="$(vs_cnorm "$WORK/vs.c$VS_CN" "$VS_CX")"; _w="$(vs_cnwant "$VS_CX")"
  if [ "$_n" = "$_w" ]; then ok "(verdict store, k-norm) ${_h#"$ROOT"/}: lib// and a CRLF declaration key exactly as lib/ on both sides, with the listing keys present$( [ "$VS_CX" = core/fixtures ] || printf ', and the consumer world keys the MAPPED core/ file and directory and no core/ row'): $_n"
  else bad "(verdict store, k-norm) ${_h#"$ROOT"/}: want '$_w' got '$_n'"; fi
done
# A HOOK-FILE PROBE EDIT, for an edit the runner must SEE too. The runner sources READSET_KEYROWS out of the world's own
# hook, which vs_cmk copies from <hook file>, while the decision sources the pool; an edit made to the pool alone would
# leave the runner on the clean span. So the edit is made to a copy of the
# whole hook and the pool is re-extracted from it: both sides then run the edited span. Sets VS_HP (hook) and VS_HPP
# (its pool); returns 1 with a FAIL when the anchor is not unique or the pool did not change.
vs_hprobe() { # <name> <from> <to> [<source hook>]
  local s="${4:-$VS_CH1}" n
  VS_HP="$WORK/vs.hm.$1.hook"; VS_HPP="$WORK/vs.hm.$1.pool"
  n="$(grep -cF -- "$2" "$s")" || n=0
  [ "$n" = 1 ] || { bad "VS PROBE $1: anchor matched $n time(s) in ${s##*/}, not 1 -- DID NOT APPLY"; return 1; }
  MF="$2" MT="$3" awk '{ i = index($0, ENVIRON["MF"]); if (i > 0) $0 = substr($0, 1, i - 1) ENVIRON["MT"] substr($0, i + length(ENVIRON["MF"])); print }' "$s" > "$VS_HP" \
    || { bad "VS PROBE $1: awk DID NOT APPLY"; return 1; }
  pool_span "$s" "$VS_HPP.src" FIXTURE_POOL && rs_rec_pin >> "$VS_HPP.src"
  pool_span "$VS_HP" "$VS_HPP" FIXTURE_POOL && rs_rec_pin >> "$VS_HPP"
  if cmp -s "$s" "$VS_HP" || cmp -s "$VS_HPP.src" "$VS_HPP"; then bad "VS PROBE $1: the hook copy or its pool is unchanged"; return 1; fi
  return 0
}
# How many of the census world's declared fixtures carry the probe row `zz-tag<TAB>1` in the hook's fresh record and
# in --key-only: "tag=<hook>/<runner>".
vs_ctag() { # <census t>
  local W="$1/W" f h=0 k=0
  for f in $(cat "$W.fx" 2>/dev/null); do
    [ -f "$W.cd/d1/.k/$f" ] && grep -qxF "zz-tag	1" "$W.cd/d1/.k/$f" && h=$((h+1))
    [ -f "$W.cd/d1/ko.$f" ] && grep -qxF "zz-tag	1" "$W.cd/d1/ko.$f" && k=$((k+1))
  done
  printf 'tag=%s/%s' "$h" "$k"
}
if [ "$VS_CN" -ge 1 ]; then
  # (k-part) THE PARTITION. Equal rows do not prove ONE composer: two composers can agree on every seeded shape. So a
  # probe edit makes the span's readset_decl_keys emit one extra row, `zz-tag<TAB>1`, for every fixture it keys; a
  # side composing its rows anywhere else cannot carry it. Both sides must carry it for every declared fixture, and the
  # census must still read the regression want (the probe moves nothing else).
  VS_TAGA='for (f in FX) { n = split(TL[f], a, "\n");'
  VS_TAGB='for (f in FX) out(f, "zz-tag", "1"); for (f in FX) { n = split(TL[f], a, "\n");'
  VS_ARMS=$((VS_ARMS+1))
  if vs_hprobe probe "$VS_TAGA" "$VS_TAGB"; then
    VS_PH="$VS_HP"; VS_PP="$VS_HPP"
    _g="$(vs_census "$VS_PP" "$VS_CX1" "$VS_RUN" "$WORK/vs.cp" "$VS_PH" 2>/dev/null)"; _t="$(vs_ctag "$WORK/vs.cp")"; VS_TN="$(wc -w < "$WORK/vs.cp/W.fx" 2>/dev/null | tr -d " ")"; VS_TW="$(vs_cwant "$VS_CX1")"
    if [ -n "$VS_TN" ] && [ "$VS_TN" -gt 0 ] && [ "$_t" = "tag=$VS_TN/$VS_TN" ] && [ "$_g" = "$VS_TW" ]; then ok "(verdict store, k-part) a row only the READSET_KEYROWS span emits reaches the hook's record AND --key-only for all $VS_TN declared fixtures, census unmoved: one composer, $_t"
    else bad "(verdict store, k-part) the span's probe row did not reach both sides for every fixture (want tag=$VS_TN/$VS_TN and '$VS_TW'): $_t $_g"; fi
  fi
fi
# (s) VERSION SKEW: a runner newer than the hook it finds. With the READSET_KEYROWS span deleted from the world's hook,
# a SANDBOX run still runs the fixture (rc 0, its own rc line printed) with the store OFF (announced, no entry), and
# only --key-only refuses (exit 2). The control is the same world with the span: one entry, and key rows at rc 0.
vs_skew() { # <runner file> <t> <strip 0|1>: "rc=<n> ran=<n> off=<n> n=<entries> ko=<rc>/<rows>"
  local rn="$1" t="$2" A="$2/A" S="$2.S" rd o ra rc k
  case "$VS_X1" in core/fixtures) rd=core/scripts ;; *) rd=scripts/ai-dlc ;; esac
  mkdir -p "$t" "$S" && vs_mk "$A" "$VS_X1" "$rn" || { printf SEED; return; }
  if [ "$3" = 1 ]; then
    awk '$0 == "# READSET_KEYROWS_BEGIN" { s = 1 } !s { print } $0 == "# READSET_KEYROWS_END" { s = 0 }' "$A/.githooks/pre-push" > "$t/hk"
    { cmp -s "$t/hk" "$A/.githooks/pre-push" || grep -qx '# READSET_KEYROWS_BEGIN' "$t/hk" || grep -q '^readset_decl_parse() ' "$t/hk"; } && { printf STRIP; return; }
    cp "$t/hk" "$A/.githooks/pre-push"
  fi
  ra="$(cd "$A" && git rev-list --max-parents=0 HEAD | sed -n 1p)"
  o="$( ( inproc AI_DLC_VERDICT_STORE="$S" -- "$A/$rd/hermetic-run.sh" --root "$A" decl ) 2>&1)"; rc=$?
  k="$( ( inproc -u AI_DLC_VERDICT_STORE -- "$A/$rd/hermetic-run.sh" --root "$A" --key-only decl ) 2>/dev/null)"
  printf 'rc=%s ran=%s off=%s n=%s ko=%s/%s' "$rc" "$(grep -c '^hermetic-run: decl: rc=0 sandbox_files=' <<< "$o")" \
    "$(grep -c 'verdict store OFF: .* carries no READSET_KEYROWS span' <<< "$o")" "$(vs_n "$S/$ra")" \
    "$( ( inproc -u AI_DLC_VERDICT_STORE -- "$A/$rd/hermetic-run.sh" --root "$A" --key-only decl ) >/dev/null 2>&1; printf '%s' "$?")" "$(grep -c . <<< "$k")"
}
if [ -n "${VS_X1:-}" ]; then
  VS_ARMS=$((VS_ARMS+1)); _c="$(vs_skew "$VS_RUN" "$WORK/vs.sk0" 0 2>/dev/null)"
  case "$_c" in "rc=0 ran=1 off=0 n=1 ko=0/"[1-9]*) ok "(verdict store, s) CONTROL: with the span the run passes, records 1 entry and --key-only prints rows at rc 0: $_c" ;;
    *) bad "(verdict store, s) CONTROL: want rc=0 ran=1 off=0 n=1 ko=0/<rows>, got '$_c'" ;; esac
  VS_ARMS=$((VS_ARMS+1)); _s="$(vs_skew "$VS_RUN" "$WORK/vs.sk1" 1 2>/dev/null)"
  if [ "$_s" = "rc=0 ran=1 off=1 n=0 ko=2/0" ]; then ok "(verdict store, s) a hook with no READSET_KEYROWS span: the sandbox run still runs the fixture with the store OFF and records nothing, and --key-only exits 2: $_s"
  else bad "(verdict store, s) want 'rc=0 ran=1 off=1 n=0 ko=2/0' got '$_s'"; fi
fi
fi
# THE REAL DEFAULT STORE IS UNCHANGED BY THE UNIT, in the home this run sees and in the account's own.
if [ -n "$VS_RUN" ]; then
  VS_ARMS=$((VS_ARMS+1))
  if [ "$(vs_snap "$VS_REAL_HOME")" = "$VS_SNAP0" ] && [ "$(vs_snap "$HOME")" = "$VS_SNAPH0" ]; then ok "the real default store ($VS_REAL_HOME/.cache/ai-dlc/verdicts and \$HOME's) is byte-unchanged by the unit"
  else bad "the unit changed a default verdict store"; fi
fi
fi

if sg slot; then
# ------------------------------------------------------------- the trace-window SLOT ----
# BL-584: the deriver's `--local-map`/`--in-pool` windows take a per-uid slot so no two overlap. Driven
# WHOLE by slot-world.sh, beside this file, in a stub-stream world with no real `log stream` and no clock:
# every property is read off an ordering record the traced fixtures write or a line the deriver must
# print. The same driver is BL-584's evidence. Twelve scenarios (see its header) and a reaped line.
SLOT_ARMS=0
SLOT_W="$HERE/slot-world.sh"
if [ -z "$DERIVER" ] || [ ! -f "$SLOT_W" ]; then
  broken "the slot unit needs the deriver and $SLOT_W"
fi
SLOT_T="$WORK/slot"; mkdir -p "$SLOT_T" || broken "mkdir failed"
SLOT_WV="$SLOT_W"   # the slot-world program a score runs
# THE CALLER'S REAP (BL-875). slot-world appends every process group it starts, its live-pid control's included, to
# the SW_GROUPS file this caller names, and this caller kills every recorded group after the world returns, however
# it ended: a world taken down by SIGKILL runs no EXIT trap, and its groups are not its own, so they outlive it. A
# group the world already reaped is gone, and the kill finds nothing.
SLOT_REAP_LIB="$SLOT_T/reap.sh"
cat > "$SLOT_REAP_LIB" <<'SR'
slot_reap() { # <group record>: kill every recorded group, then its leader by pid
  local g
  [ -f "$1" ] || return 0
  while IFS= read -r g; do
    case "$g" in ''|0|*[!0-9]*) continue ;; esac
    kill -KILL -- "-$g" 2>/dev/null; kill -KILL "$g" 2>/dev/null
  done < "$1"
  return 0
}
SR
. "$SLOT_REAP_LIB" || broken "could not load $SLOT_REAP_LIB"
slot_score() { # <deriver copy> [scenario ...] -> "<rc>|<failed scenarios, sorted, space-joined>"
  local o r d="$1" gf; shift
  gf="$(mktemp "$SLOT_T/groups.XXXXXX")" || broken "mktemp failed for a slot-world group record"
  # slot-world itself runs in process; the derivers IT starts stay processes: the slot's decisions are keyed on the
  # holder's `$$` (readset_lock_write records it, rs_slot_release and readset_lock_stale judge it) and on reaping a
  # deriver's process group, so two derivers in one process would share the identity the slot exists to separate.
  o="$( ( inproc TMPDIR="$SLOT_T" SW_GROUPS="$gf" SW_CELL=slot -- "$SLOT_WV" "$d" "$HOOK" "$@" ) 2>/dev/null)"; r=$?
  slot_reap "$gf"
  printf '%s|%s' "$r" "$(printf '%s\n' "$o" | sed -n 's/^FAIL \([a-z]*\):.*/\1/p' | sort | tr '\n' ' ' | sed 's/ $//')"
  printf '%s\n' "$o" > "$SLOT_T/last.out"
}
SLOT_ARMS=$((SLOT_ARMS+1))
S0="$(slot_score "$DERIVER")"
# The shipped run is every scenario plus the reaped line: 13 scenarios and `reaped`, 14 PASS lines.
if [ "$S0" = "0|" ] && [ "$(grep -c '^PASS ' "$SLOT_T/last.out")" = 14 ]; then
  ok "SLOT: all twelve slot-world scenarios PASS on the shipped deriver (order, nested, stalemark, foreign, stale, beat, plain, file, stray, noparent, rebreak, oldempty)"
else
  bad "SLOT: the shipped deriver did not pass all twelve slot-world scenarios: '$S0' — $(grep -m1 '^FAIL' "$SLOT_T/last.out" | sed 's/^.*-- A: /A: /' | cut -c1-400)"
fi
# THE WORLD REAPS ITS OWN TREE. hold kills deriver A while its stream stub and `tail -f` are live; reaped
# then reads every process group the world recorded, by its own pgid, and requires at least one and no
# live member. Presence-shaped: both PASS lines must appear, so a world that started nothing cannot score.
SLOT_ARMS=$((SLOT_ARMS+1))
if grep -qx 'PASS hold' "$SLOT_T/last.out" && grep -qE '^PASS reaped \([1-9][0-9]* group\(s\), none alive\)$' "$SLOT_T/last.out"; then
  ok "SLOT REAPED: a deriver taken down by SIGKILL with its stream stub live leaves no member of any process group the world recorded ($(grep '^PASS reaped' "$SLOT_T/last.out" | sed 's/^PASS reaped //'))"
else
  bad "SLOT REAPED: the hold scenario or the reaped line did not PASS: $(grep -E '^(FAIL|PASS) (hold|reaped)' "$SLOT_T/last.out" | tr '\n' ' ' | cut -c1-300)"
fi
# (slot-kill) THE WORLD ITSELF TAKEN DOWN BY SIGKILL (BL-875). The world runs `hold` in the background in a TMPDIR of its
# own; once the fixture has recorded `a-hold`, the world writes SW_KILL_GATE and blocks with deriver A's tree still up (no
# clock: left unblocked, the world's own hold kill races the caller's), then it is SIGKILLed, so its EXIT trap never runs, and the caller's
# reap must leave no member of any recorded group and the live-pid control dead. The control's pid is read from the file
# the world's FIXTURE wrote, never from the group record, so a world that failed to record it is still censused.
# Survivors are judged by aw_wait on the settled-state predicates, never on a count of polls: a killed member is still
# exiting, never blocked with nothing pending, so no load reads it as a survivor. Prints
# "<pre>|<recorded groups>|<surviving groups>|<live control surviving>", pre=1 when the stream, the holding fixture,
# the live control and the last recorded group were all up when the kill landed, 0 when one was not, and `exited` when
# the world exited before writing the gate, with its evidence in $SLOT_T/pre.exit.<prefix>. The world's output goes to
# $T/world.out and its directory is kept (SW_KEEP).
# Whatever the verdict, every recorded group and the live control are reaped by their recorded ids before it returns.
# With a third argument (slot-shellkill) the teardown is that lib's pool_kill_tree applied to the world's shell pid, and the
# caller's reap does NOT run before the census: the hook's own teardown is the only reaper the census reads.
slot_kill_drive() { # <slot-world copy> <reap lib> <pool_kill_tree lib, or empty> <cell prefix>
  # (the cell prefix is the world's SW_CELL: its deriver A is the e2e cell <prefix>.hold of cells.decl)
  local T gf swp d lp pre=0 ng=0 sv=0 lv=0 g aw
  T="$(mktemp -d "$SLOT_T/kd.XXXXXX")" || broken "mktemp failed for the slot-kill world"
  gf="$T/groups"; : > "$gf"
  # The world's output goes to $T/world.out and SW_KEEP keeps its directory (deriver A's hold/aout) on a clean exit, so
  # a world that exits before its gate leaves its evidence behind; a SIGKILLed world never reaches that exit path.
  ( inproc TMPDIR="$T" SW_GROUPS="$gf" SW_KILL_GATE="$T/gate" SW_CELL="$4" SW_KEEP=1 -- "$1" "$DERIVER" "$HOOK" hold ) >"$T/world.out" 2>&1 &
  swp=$!
  # The world writes the gate file only with A's tree up and then blocks until killed, so the KILL is never early or late.
  # aw_wait 1 is the world gone with no gate: pre reads `exited`, and the evidence file names its output and A's aout.
  aw_wait '[ -e "$T/gate" ]' 'echo "$swp"' ''; aw=$?
  d="$(ls -d "$T"/slot-world.*/hold 2>/dev/null | head -1)"
  if [ "$aw" = 1 ]; then
    printf 'world FAIL lines: %s; world output tail: %s; A aout: %s; order: %s' \
      "$(grep '^FAIL ' "$T/world.out" 2>/dev/null | tr '\n' ' ' | cut -c1-300)" "$(tail -n 5 "$T/world.out" 2>/dev/null | tr '\n' ' ' | cut -c1-300)" \
      "$(tail -n 5 "$d/aout" 2>/dev/null | tr '\n' ' ' | cut -c1-300)" "$(tr '\n' ' ' < "$d/order" 2>/dev/null | cut -c1-200)" > "$SLOT_T/pre.exit.$4"
  fi
  lp="$(cat "$d/order.live" 2>/dev/null)"
  g="$(tail -1 "$gf")"
  # pre is the chain of eight tests below, each evaluated only if the one before held (as the && chain it replaces did);
  # the part file records each as 1 (held), 0 (failed) or - (not reached), so a red names the part that failed.
  local p1=- p2=- p3=- p4=- p5=- p6=- p7=- p8=-
  p1=0; [ -e "$T/gate" ] && p1=1
  if [ "$p1" = 1 ]; then p2=0; grep -qx a-hold "$d/order" 2>/dev/null && p2=1; fi
  if [ "$p2" = 1 ]; then p3=0; grep -qx a-stream-up "$d/order" && p3=1; fi
  if [ "$p3" = 1 ]; then p4=0; [ -n "$lp" ] && p4=1; fi
  if [ "$p4" = 1 ]; then p5=0; kill -0 "$lp" 2>/dev/null && p5=1; fi
  if [ "$p5" = 1 ]; then p6=0; [ -n "$g" ] && p6=1; fi
  if [ "$p6" = 1 ]; then p7=0; kill -0 -- "-$g" 2>/dev/null && p7=1; fi
  if [ "$p7" = 1 ]; then p8=0; kill -0 "$swp" 2>/dev/null && p8=1; fi
  printf 'gate=%s a-hold=%s a-stream-up=%s lp-set=%s lp-live=%s g-set=%s g-live=%s world-live=%s' "$p1" "$p2" "$p3" "$p4" "$p5" "$p6" "$p7" "$p8" > "$SLOT_T/pre.parts.$4"
  [ "$p8" = 1 ] && pre=1
  [ "$aw" = 1 ] && pre=exited
  if [ -n "${3:-}" ]; then
    ( . "$3" && pool_kill_tree "$swp" "" "" ) 2>/dev/null; wait "$swp" 2>/dev/null
  else
    kill -KILL "$swp" 2>/dev/null; wait "$swp" 2>/dev/null
    ( . "$2" && slot_reap "$gf" )
  fi
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    ng=$((ng + 1))
    aw_wait '! kill -0 -- "-$g" 2>/dev/null' '' 'aw_group_settled "$g"'; [ $? = 2 ] && sv=$((sv + 1))
  done < "$gf"
  if [ -n "$lp" ]; then aw_wait '! kill -0 "$lp" 2>/dev/null' '' 'aw_blocked "$lp"'; [ $? = 2 ] && lv=1; fi
  slot_reap "$gf"; [ -n "$lp" ] && kill -KILL "$lp" 2>/dev/null
  printf '%s|%s|%s|%s' "$pre" "$ng" "$sv" "$lv"
}
SLOT_ARMS=$((SLOT_ARMS+1))
_k="$(slot_kill_drive "$SLOT_W" "$SLOT_REAP_LIB" "" slot-kill)"
if [ "$_k" = "1|2|0|0" ]; then
  ok "SLOT KILL: slot-world SIGKILLed mid-hold leaves no member of its 2 recorded groups (deriver A, live control) alive after the caller's reap ('$_k' pre|groups|surviving|live)"
elif [ "${_k%%|*}" = exited ]; then bad "SLOT KILL: world exited before the gate, got '$_k' -- $(cat "$SLOT_T/pre.exit.slot-kill" 2>/dev/null)"
else bad "SLOT KILL: expected '1|2|0|0' (pre|groups|surviving|live), got '$_k' (pre parts: $(cat "$SLOT_T/pre.parts.slot-kill" 2>/dev/null))"; fi
# (slot-forkkill) THE WORLD SIGKILLed BETWEEN A LAUNCH AND THE STATEMENT AFTER IT (BL-875 item 5). The world once appended
# deriver A's `$!` on the statement after its launch, so a KILL between the fork and that append left a group nobody
# recorded. Now the launched child records itself. SW_FORK_GATE blocks the world on exactly that statement, once the child
# has recorded itself and passed its liveness check (sentinels, no clock), and the caller SIGKILLs it there and reaps
# the record. The census reads deriver A's group through the pid file the child wrote ($d/apid), never through the
# record, so a child that failed to record itself is still seen. Prints "<pre>|<recorded groups>|<A surviving>", pre=1
# when the gate, the pid file, A's live group and the world were all present when the KILL landed.
slot_fork_drive() { # <slot-world copy>
  local T gf swp d ap pre=0 ng sv=0
  T="$(mktemp -d "$SLOT_T/fk.XXXXXX")" || broken "mktemp failed for the slot-forkkill world"
  gf="$T/groups"; : > "$gf"
  ( inproc TMPDIR="$T" SW_GROUPS="$gf" SW_FORK_GATE="$T/gate" SW_CELL=slot-fork -- "$1" "$DERIVER" "$HOOK" hold ) >/dev/null 2>&1 &
  swp=$!
  aw_wait '[ -e "$T/gate" ]' 'echo "$swp"' ''
  d="$(ls -d "$T"/slot-world.*/hold 2>/dev/null | head -1)"
  ap="$(cat "$d/apid" 2>/dev/null)"
  if [ -e "$T/gate" ] && grep -qx a-hold "$d/order" 2>/dev/null && [ -n "$ap" ] && kill -0 -- "-$ap" 2>/dev/null && kill -0 "$swp" 2>/dev/null; then pre=1; fi
  kill -KILL "$swp" 2>/dev/null; wait "$swp" 2>/dev/null
  slot_reap "$gf"
  ng="$(grep -c . "$gf")" || ng=0
  if [ -n "$ap" ]; then aw_wait '! kill -0 -- "-$ap" 2>/dev/null' '' 'aw_group_settled "$ap"'; [ $? = 2 ] && sv=1; fi
  [ -n "$ap" ] && { kill -KILL -- "-$ap" 2>/dev/null; kill -KILL "$ap" 2>/dev/null; }
  printf '%s|%s|%s' "$pre" "$ng" "$sv"
}
SLOT_ARMS=$((SLOT_ARMS+1))
_k="$(slot_fork_drive "$SLOT_W")"
if [ "$_k" = "1|2|0" ]; then
  ok "SLOT FORKKILL: slot-world SIGKILLed on the statement after deriver A's launch leaves A's group recorded by A itself and reaped ('$_k' pre|groups|A surviving)"
else bad "SLOT FORKKILL: expected '1|2|0' (pre|groups|A surviving), got '$_k'"; fi
# (slot-shellkill) THE WORLD TORN DOWN BY THE HOOK'S OWN TEARDOWN (BL-875). The same gated hold world as slot-kill, but the
# KILL is the pre-push hook's pool_kill_tree applied to the world's shell pid, as the hook's xargs worker applies it to a
# unit's, and the fixture's slot_reap does NOT run before the census: the hook's teardown alone must leave no member of any
# recorded group and the live control dead. The functions are EXTRACTED from $HOOK at run time (pool_tree, which
# pool_kill_tree walks with, and pool_kill_tree), never copied, so a hook edit to either changes what this arm runs; an
# extraction that does not yield exactly those two definitions, each parsing and defined once sourced, is BROKEN.
SLOT_PKT_LIB="$SLOT_T/pool-kill-tree.sh"
awk '/^    pool_tree\(\) \{$/,/^    \}$/ {print} /^    pool_kill_tree\(\) \{$/,/^    \}$/ {print}' "$HOOK" > "$SLOT_PKT_LIB"
[ "$(grep -c '^    [a-z_]*() {$' "$SLOT_PKT_LIB")" = 2 ] && [ "$(grep -cx '    pool_tree() {' "$SLOT_PKT_LIB")" = 1 ] \
  && [ "$(grep -cx '    pool_kill_tree() {' "$SLOT_PKT_LIB")" = 1 ] \
  && bash -n "$SLOT_PKT_LIB" && ( . "$SLOT_PKT_LIB" && declare -F pool_tree >/dev/null && declare -F pool_kill_tree >/dev/null ) \
  || broken "could not extract exactly pool_tree and pool_kill_tree from ${HOOK#"$ROOT"/}"
SLOT_ARMS=$((SLOT_ARMS+1))
_k="$(slot_kill_drive "$SLOT_W" "$SLOT_REAP_LIB" "$SLOT_PKT_LIB" slot-shk)"
if [ "$_k" = "1|2|0|0" ]; then
  ok "SLOT SHELLKILL: slot-world torn down mid-hold by the hook's own pool_kill_tree on its shell pid, no caller reap, leaves no member of its 2 recorded groups alive ('$_k' pre|groups|surviving|live)"
elif [ "${_k%%|*}" = exited ]; then bad "SLOT SHELLKILL: world exited before the gate, got '$_k' -- $(cat "$SLOT_T/pre.exit.slot-shk" 2>/dev/null)"
else bad "SLOT SHELLKILL: expected '1|2|0|0' (pre|groups|surviving|live), got '$_k' (pre parts: $(cat "$SLOT_T/pre.parts.slot-shk" 2>/dev/null))"; fi
fi

# (no-refusal) NO CK OR TK PUSH WAS DECIDED BY THE WATCHDOG (the pin is at the scrub, at the top of this file). Every
# push directory this shard wrote must have recorded the pinned window, and no push may have rendered a REFUSED verdict
# line. Presence-shaped: a shard that drove pushes must find at least one, and the scan is self-probed both ways first.
nr_scan() { # <out file>...: "<pushes>|<pushes whose block did not take the pin>|<REFUSED verdict lines>"
  local f n=0 np=0 nr=0 c
  for f in "$@"; do
    [ -f "$f" ] || continue
    n=$((n+1)); [ "$(cat "${f%/out}/stall" 2>/dev/null)" = 99999 ] || np=$((np+1))
    c="$(grep -c '^   REFUSED  ' "$f")" || c=0; nr=$((nr+c))
  done
  printf '%s|%s|%s' "$n" "$np" "$nr"
}
ck_norefuse() { nr_scan "$1"/*.o.*/out; } # <dir>: every ck/tk push directory under it
NR_P="$(mktemp -d "$WORK/nr.XXXXXX")" || broken "mktemp failed for the no-refusal self-probe"
mkdir -p "$NR_P/r/w.o.1" "$NR_P/c/w.o.1" "$NR_P/u/w.o.1"
printf '   done 3/3  REFUSED delta\n   REFUSED  delta  (no progress for 600 polls; a refusal costs a re-run, never a verdict)\n' > "$NR_P/r/w.o.1/out"
printf '   done 3/3  ok delta\n   ok    delta\n' > "$NR_P/c/w.o.1/out"; cp "$NR_P/c/w.o.1/out" "$NR_P/u/w.o.1/out"
printf '99999\n' > "$NR_P/r/w.o.1/stall"; printf '99999\n' > "$NR_P/c/w.o.1/stall"; printf '600\n' > "$NR_P/u/w.o.1/stall"
[ "$(ck_norefuse "$NR_P/r")|$(ck_norefuse "$NR_P/c")|$(ck_norefuse "$NR_P/u")" = '1|0|1|1|0|0|1|1|0' ] \
  || broken "the no-refusal scan did not discriminate a seeded REFUSED push, a clean one and an unpinned one"
_nr="$(ck_norefuse "$CK_W")"
if [ "${_nr%%|*}" -gt 0 ]; then
  CK_ARMS=$((CK_ARMS+1))
  if [ "${_nr#*|}" = '0|0' ]; then ok "(no-refusal) all ${_nr%%|*} ck/tk push(es) ran under the pinned window 99999 and none was REFUSED by the pool watchdog"
  else bad "(no-refusal) ck/tk pushes|unpinned|REFUSED verdict lines = $_nr; a push decided by the load-bound watchdog is no verdict on the subject"; fi
elif sg ckw || sg tk; then
  CK_ARMS=$((CK_ARMS+1)); bad "(no-refusal) this shard runs ck/tk worlds and the scan found no push directory under $CK_W"
fi
# (no-refusal, loc) THE SAME FOR THE loc UNIT'S run_fixtures DRIVES: rf_drive's $WORK/rfo.<name>/ and rp_run's
# $WORK/rpo.<name>/ record the POOL_STALL their block computed beside the run's output. Same scan, same
# self-probe; presence-shaped: a shard running loc must find at least one. (`&& true`: not a unit guard, so the
# coverage join does not read it as loc declared twice.)
if sg loc && true; then
  LT_ARMS=$((LT_ARMS+1))
  _nl="$(nr_scan "$WORK"/rfo.*/out "$WORK"/rpo.*/out)"
  if [ "${_nl%%|*}" -gt 0 ] && [ "${_nl#*|}" = '0|0' ]; then ok "(no-refusal, loc) all ${_nl%%|*} rf/rp run_fixtures drive(s) ran under the pinned window 99999 and none was REFUSED by the pool watchdog"
  else bad "(no-refusal, loc) rf/rp drives|unpinned|REFUSED verdict lines = $_nl; a drive decided by the load-bound watchdog, or none found, is no verdict on the subject"; fi
fi

# A NO-PROGRESS NET THAT FIRED ANYWHERE IS A REFUSAL, NOT A VERDICT: the run is FIXTURE BROKEN, exit 2.
aw_gate

# THE SUMMARY IS ALSO A COMPLETENESS CHECK. This fixture once ended mid-file after an editing
# mistake: it printed two thirds of its arms, never reached a verdict line, and exited 0 --
# which the suite's worker records as `ok`. A fixture that dies silently reads exactly like one
# that passed, so the arm count is asserted against the number this file actually carries.
BASE_ARMS=0; sg arms && BASE_ARMS=16
EXPECTED=$(( BASE_ARMS + PRE_ARMS + ${IGN_ARMS:-0} + ${NEW_ARMS:-0} + ${MERGE_ARMS:-0} + ${CONTROL_ARMS:-0} + ${TRACE_ARMS:-0} + ${BOTH_ARMS:-0} + ${LT_ARMS:-0} + ${CK_ARMS:-0} + ${TK_ARMS:-0} + ${DG_ARMS:-0} + ${RC_ARMS:-0} + ${VS_ARMS:-0} + ${SLOT_ARMS:-0} ))
if [ $((oks + fails)) -lt "$EXPECTED" ]; then
  bad "only $((oks + fails)) assertions ran; this fixture carries $EXPECTED — it exited early and a short green run reads exactly like a passing one"
fi

echo
report_end "$NAME"
