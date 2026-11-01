#!/usr/bin/env bash
# core/fixtures/prepush-pool-depth/receipt-bl881.sh [<hook>] -- the BL-881 backlog receipt: a TERM to the pre-push
# hook tears down its fixture pool, and it does so where /bin/ps cannot run.
#
# Drives the hook's OWN FIXTURE_POOL block (extracted between its BEGIN/END markers, the way
# core/fixtures/prepush-pool-depth/run.sh does) as `run_fixtures` over a seeded world of four stub units
# at width 2. Each stub first starts a grandchild under `set -m` (so the grandchild leads its OWN group),
# records both pids, and holds on a barrier FILE this receipt writes, so exactly two units are in flight
# and two are queued when the signal lands. The receipt then TERMs the one process it started (the shell
# running run_fixtures) and asserts:
#   A1  the parent exits, with status 143
#   A2  every stub pid it recorded is dead once the parent is gone, and so is every grandchild
#   A3  no queued stub ever started (2 recorded; the `.stop` record makes xargs stop dispatching)
#   A4  the pool root the stubs recorded is removed
#   A5  the out-of-group decoy record's process is still alive (a pool_stop that TERMs every `.k` record
#       kills it), and no UNRECORDED member of xargs' process group was signalled (see F-D1 below)
#   A6  every orphan each stub left is dead (see THE ORPHANS below)
# Exit 0 when all hold; 1 when any fails (each failing assertion prints a FAIL line naming it); 9 when the
# subject cannot be measured: no hook, an empty block, no fixture root, `pgrep` or `perl` missing, the
# liveness reader failing its own controls, or the pool never starting two stubs.
#
# THE SANDBOXED FAILURE IS REPRODUCED WITH A `ps` SHIM, NOT A NESTED SANDBOX. R8 runs `sh` receipts inside
# pk_step's sandbox-exec, where /bin/ps is denied and a nested sandbox-exec may be refused. So a `ps` that
# exits 71 with no output goes first on the PATH of the SUBJECT ONLY (the run_fixtures launch): every bare
# `ps` in the block (pool_stop, pool_walk, pool_run's `self=`) fails as it does under sandbox-exec, while
# `pgrep` stays real. The receipt therefore always measures the sandboxed case, run plainly or sandboxed.
#
# THE OBSERVER IS ps-FREE. A stub, grandchild or decoy is alive iff its pid is a whole line of
# `pgrep -g <pid>`: each leads its own group, which is asserted before the TERM, and a zombie leader lists
# nothing. `kill -0` is true on a zombie, so it is never the verdict. The reader is checked both ways first:
# the decoy, a live leader, must be listed, and a zombie leader (on which `kill -0` succeeds) must not.
#
# NO CLOCK AND NO BOUND (BL-868). Every wait ends on an event:
#   THE TERM. The receipt waits until the parent is gone OR the END RECORD was tested with ps. The END RECORD is
#     a receipt-owned process outside xargs' group, recorded as `.pr/zzz-end.k`, after every worker record and the
#     decoy in glob order; the `ps` shim writes `end.seen` when it is asked about that pid. A pool_stop that tests
#     each record with ps (the restored `ps -o pgid=` test, base 47102ad20) TERMs no worker under the shim and
#     never exits, and its kill loop marks the END RECORD last, so `end.seen` is its event: A1 FAIL, exit 1. The
#     fix never asks ps about a record, so for it the event is the parent's exit.
#   THE DEATHS. Once the parent is gone, every KILL the teardown sends has been sent: pool_stop's wait returned,
#     so xargs exited, and xargs waits for every worker, and each worker sends its KILLs before it exits. A
#     KILLed process runs no more user code, so the receipt writes `ping`, and every hold loop (stub,
#     grandchild, orphan, decoy) that is still running answers by writing `pong.<its recorded pid>`. For each
#     recorded pid the receipt waits until its reader no longer lists it (it died) OR it answered (it
#     survives), and then reads the reader. A survivor ends on the release, never by a kill.
#   THE ZOMBIE CONTROL. Its perl holder records the child only after SIGCHLD, which the kernel posts once the
#     child is waitable, which means a zombie, so one read decides the control (measured: 0 of 400 such
#     zombies listed by `pgrep -g`, plain and sandboxed, `kill -0` true on all 400).
#   THE SETUP. The receipt waits for two stub records, then for both stubs' reports, each paired with the
#     parent's exit. A stub's waits end on a record its own subshell writes, a watcher poll, or the freeze.
#     Every hold loop ends on the release, the directory's removal, or the receipt's own pid being gone.
# THE COUPLING, AND WHAT BREAKS IT, IN ONE PLACE. The setup waits have an event only if the pool dispatches
# two units at once (width 2) and the unit's watcher polls through a PATH `sleep`, which the shim counts and
# freezes. A pool whose width is below 2, or whose watcher waits any other way (`/bin/sleep`, `read -t`),
# HANGS this receipt instead of exiting 9. That case is outside what the receipt measures, and no clock
# stands in for the missing event. A teardown that STOPs a process and never KILLs it (none is scored) also
# hangs: the process can neither die nor answer the ping.
#
# THE ORPHANS (T-N1). `pgrep -P` cannot reach a process whose parent has exited, so each stub leaves two
# orphans with ppid 1, plus a third subject, all recorded by pid and asserted orphaned (`pgrep -P 1`) before the TERM:
#   m  stays in the UNIT's group; only a KILL to the unit's own group (pool_kill_tree's per-pid
#      `kill -KILL -- "-$p"`) reaches it. Alive iff it is a whole line of `pgrep -g <stub pid>`.
#   o  leads its OWN group (a `set -m` grandchild) and stays connected through its parent subshell until
#      the watcher has started two polls, then that parent exits; only a teardown that REMEMBERS a group
#      seen on an earlier poll reaches it. Alive iff `leads`.
#   n  a member (ppid 1) of the group of L, a `set -m` child the stub starts only after its watcher is
#      FROZEN, so no poll ever sees L. L stays connected, so the teardown's walk reaches it, and only a
#      KILL to each walked pid's group (pool_kill_tree's per-pid `kill -KILL -- "-$p"`) reaches n; a
#      remembered-group KILL cannot, which keeps this cell separate from m (the stub's own group is
#      remembered by a fix that records every group leader in the tree). Alive iff in `pgrep -g L`.
# The freeze: the shim's sleep, once `freeze.<watcher>` exists, writes `frozen.<watcher>` and blocks until
# the release; the TERM KILLs the watcher's group, the blocked shim with it.
# "Two polls" is read ps-free and load-free: the subject's PATH also carries a `sleep` shim that appends a
# line to `poll.<its parent pid>` and execs the real sleep, so the watcher's `sleep 1` counts its own polls.
# The stub finds its watcher as the other child of its worker that has a poll record, waits for two NEW
# poll starts (so a full poll body ran with the parent alive), orphans `o`, then waits two more (so a poll
# ran after the orphaning, the state the TERM lands in), then freezes the watcher and plants n. It
# reports `ok`, `nopoll` or `frozen` (planting failed); anything but `ok`
# from both stubs is exit 9, never a verdict. No assertion counts polls or reads a clock.
# The stub records its final report only after it has seen the watcher poll; a watcher that never polls
# through the shim leaves no report, and the receipt waits for one (see THE COUPLING above).
#
# F-D1: THE REJECTED `kill -TERM -- -"$pool_xp"` DESIGN IS SCORED, deterministically, by A5's sentinel. The
# receipt starts a perl process that blocks TERM, INT and HUP and JOINS xargs' process group (setpgid into the
# group of a recorded worker, asserted equal before the TERM). It is in no `.k` record, so a pool_stop that
# signals only recorded pids never reaches it, while a group signal does. After the parent exits and the
# barrier is released it reports whether a signal is pending. No timing decides it: the signal, if sent, is
# pending before the parent can exit.
#
# Signals go ONLY to the pid this receipt started; the stubs, grandchildren, decoy and sentinel end on the
# barrier release, never by a kill. Behaviour only: no hook line is grepped, so any spelling that tears the
# pool down passes, with ONE coupling: the watcher's poll wait must be a PATH `sleep`, which the shim counts
# and freezes. A watcher that waits any other way (`/bin/sleep`, `read -t`) reads exit 9 `nopoll`, never
# a verdict -- in fact a hang, per THE COUPLING above.
set -uo pipefail
r881_seam() { # walk up from $1 for the git-env seam; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/fixtures/lib/preamble.sh" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(r881_seam "$(cd "$(dirname "$0")" && pwd)")" || ROOT=""
[ -n "$ROOT" ] || { echo "REFUSED: no core/fixtures/lib/preamble.sh above $0" >&2; exit 9; }
. "$ROOT/core/fixtures/lib/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset PREPUSH_POOL_DEPTH
HOOK="${1:-$ROOT/.githooks/pre-push}"
[ -f "$HOOK" ] || { echo "REFUSED: no hook at $HOOK" >&2; exit 9; }
command -v pgrep > /dev/null 2>&1 || { echo "REFUSED: no pgrep, so liveness cannot be read" >&2; exit 9; }
command -v perl > /dev/null 2>&1 || { echo "REFUSED: no perl, so the group sentinel cannot be planted" >&2; exit 9; }
T="$(mktemp -d "${TMPDIR:-/tmp}/bl881.XXXXXX")" || exit 9
[ -d "$T" ] || exit 9
trap ': > "$T/s/release" 2>/dev/null; rm -rf "$T"' EXIT
sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK" > "$T/block.sh"
[ -s "$T/block.sh" ] || { echo "REFUSED: empty FIXTURE_POOL block in $HOOK" >&2; exit 9; }
FXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$T/block.sh" | sort -u)"
[ "$(printf '%s\n' "$FXR" | grep -c .)" -eq 1 ] || { echo "REFUSED: fixture root read as '$FXR', need exactly one" >&2; exit 9; }
mkdir -p "$T/s" "$T/store" "$T/shim" || exit 9
# the ps shim answers as the sandboxed /bin/ps does (no output, exit 71); asked about the END RECORD's pid it
# first marks `end.seen` (see NO CLOCK AND NO BOUND above)
printf '#!/bin/sh\nread -r e < "$R881_DIR/end.pid" 2> /dev/null || e=x\nfor a in "$@"; do [ "$a" = "$e" ] && : > "$R881_DIR/end.seen"; done\nexit 71\n' > "$T/shim/ps" \
  && chmod +x "$T/shim/ps" || exit 9
SLP="$(command -v sleep)"; case "$SLP" in /*) ;; *) echo "REFUSED: no sleep binary on PATH for the poll shim" >&2; exit 9 ;; esac
cat > "$T/shim/sleep" <<SHIM || exit 9
#!/bin/sh
[ -d "\$R881_DIR" ] || exec $SLP "\$@"
echo x >> "\$R881_DIR/poll.\$PPID"
if [ -e "\$R881_DIR/freeze.\$PPID" ]; then
  : > "\$R881_DIR/frozen.\$PPID"
  while [ ! -e "\$R881_DIR/release" ] && [ -d "\$R881_DIR" ] && kill -0 "\$R881_PID" 2> /dev/null; do $SLP 0.1; done
  exit 0
fi
exec $SLP "\$@"
SHIM
chmod +x "$T/shim/sleep" || exit 9
for i in 1 2 3 4; do
  mkdir -p "$T/w/$FXR/q$i" || exit 9
  cat > "$T/w/$FXR/q$i/run.sh" <<'FX'
#!/usr/bin/env bash
# up: the release is not written, the directory exists, and the receipt that started this run is alive
up() { [ ! -e "$R881_DIR/release" ] && [ -d "$R881_DIR" ] && kill -0 "$R881_PID" 2> /dev/null; }
# hold [<tag>]: until up fails; once the receipt has written `ping`, a tagged hold answers `pong.<tag>` (it is alive)
hold() { while up; do [ -n "${1:-}" ] && [ -e "$R881_DIR/ping" ] && : > "$R881_DIR/pong.$1"; sleep 0.1; done; }
set -m
( hold "g.$$" ) > /dev/null 2>&1 &
g=$!
set +m
printf '%s\n' "$g" > "$R881_DIR/tmp.g.$$" && mv "$R881_DIR/tmp.g.$$" "$R881_DIR/g.$$"
printf '%s %s\n' "$$" "${TMPDIR%/*}" > "$R881_DIR/tmp.s.$$" && mv "$R881_DIR/tmp.s.$$" "$R881_DIR/s.$$"
pw() { # pw: return once this unit's watcher (the worker's other child that sleeps) has STARTED two more sleeps
  local w="" c n0
  while :; do
    for c in $(pgrep -P "$PPID" 2>/dev/null); do [ "$c" != "$$" ] && [ -s "$R881_DIR/poll.$c" ] && w="$c"; done
    [ -n "$w" ] && break
    up || return 1; sleep 0.1
  done
  WP="$w"
  n0="$(grep -c . "$R881_DIR/poll.$w")"
  while [ "$(grep -c . "$R881_DIR/poll.$w")" -lt $((n0 + 2)) ]; do up || return 1; sleep 0.1; done
}
# m: a same-group orphan (its subshell parent exits at once, so ppid 1, in this unit's group, leading nothing).
( ( hold "m.$$" ) > /dev/null 2>&1 & printf '%s\n' "$!" > "$R881_DIR/tmp.m.$$" && mv "$R881_DIR/tmp.m.$$" "$R881_DIR/m.$$" )
# o: an own-group descendant, connected through its parent subshell for two watcher polls, then orphaned.
( set -m; ( hold "o.$$" ) > /dev/null 2>&1 & printf '%s\n' "$!" > "$R881_DIR/tmp.o.$$" && mv "$R881_DIR/tmp.o.$$" "$R881_DIR/o.$$"
  while [ ! -e "$R881_DIR/d.$$" ] && up; do sleep 0.1; done ) > /dev/null 2>&1 &
ip=$!
while [ ! -s "$R881_DIR/o.$$" ] && up; do sleep 0.1; done
r=nopoll
pw && { : > "$R881_DIR/d.$$"; wait "$ip"; pw && r=frozen; }
# l: freeze the watcher (its next sleep blocks), so no poll ever sees what follows; then start L, a connected
# own-group child, whose member n is orphaned inside L's group. Only a KILL to L's group reaches n.
if [ "$r" = frozen ]; then
  : > "$R881_DIR/freeze.$WP"
  while [ ! -e "$R881_DIR/frozen.$WP" ] && up; do sleep 0.1; done
  if [ -e "$R881_DIR/frozen.$WP" ]; then
    set -m
    ( set +m; ( ( hold "n.$$" ) > /dev/null 2>&1 & printf '%s\n' "$!" > "$R881_DIR/tmp.n.$$" && mv "$R881_DIR/tmp.n.$$" "$R881_DIR/n.$$" ); hold ) > /dev/null 2>&1 &
    L=$!
    set +m
    while [ ! -s "$R881_DIR/n.$$" ] && up; do sleep 0.1; done
    n=""; [ -s "$R881_DIR/n.$$" ] && read -r n < "$R881_DIR/n.$$"
    [ -n "$n" ] && printf '%s:%s\n' "$L" "$n" > "$R881_DIR/tmp.l.$$" && mv "$R881_DIR/tmp.l.$$" "$R881_DIR/l.$$" && r=ok
  fi
fi
printf '%s\n' "$r" > "$R881_DIR/tmp.r.$$" && mv "$R881_DIR/tmp.r.$$" "$R881_DIR/r.$$"
hold "s.$$"
exit 0
FX
done
( cd "$T/w" && git init -q . && git add -A && git -c user.email=r@r -c user.name=r commit -qm seed ) > /dev/null 2>&1
[ -d "$T/w/.git" ] || { echo "REFUSED: the stub world is not a repository" >&2; exit 9; }

leads() { # leads <pid>: true iff <pid> is a whole line of `pgrep -g <pid>` (a live group leader)
  case $'\n'"$(pgrep -g "$1" 2>/dev/null)"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac
  return 1
}
nstubs() { ls "$T/s" | grep -c '^s\.[0-9]*$'; }
stubs() { cat "$T/s"/s.* 2>/dev/null | cut -d' ' -f1; }
grands() { cat "$T/s"/g.* 2>/dev/null; }
alive() { # how many of the given pids are live group leaders
  local p n=0
  for p in "$@"; do leads "$p" && n=$((n + 1)); done
  printf '%s' "$n"
}

# The reader's own controls: a live leader is listed, and a ZOMBIE leader is not. The zombie is a perl child
# that leads its own group and exits while its perl parent holds it unreaped until the release; the parent
# records it only after SIGCHLD, which the kernel posts once the child is waitable (a zombie), so one read
# decides the control. `kill -0` succeeding on it proves the input is a zombie, not a reaped pid, so the
# control separates this reader from a `kill -0` one. The decoy DP is the live leader; it answers `pong.dp`.
export R881_DIR="$T/s" R881_PID="$$"
set -m
( while [ ! -e "$T/s/release" ] && [ -d "$T/s" ]; do [ -e "$T/s/ping" ] && : > "$T/s/pong.dp"; sleep 0.1; done ) > /dev/null 2>&1 &
DP=$!
set +m
perl -MPOSIX -e '
  my ($rel, $dir, $rec) = @ARGV; my $got = 0; $SIG{CHLD} = sub { $got = 1 };
  my $c = fork(); defined $c or exit 3;
  if ($c == 0) { setpgrp(0, 0); POSIX::_exit(0) }
  until ($got) { select(undef, undef, undef, 0.1) }
  open(my $f, ">", "$rec.t") or exit 3; print $f "$c\n"; close $f; rename("$rec.t", $rec) or exit 3;
  until (-e $rel || ! -d $dir) { select(undef, undef, undef, 0.1) }
  waitpid($c, 0); exit 0' "$T/s/release" "$T/s" "$T/zombie" > /dev/null 2>&1 &
ZH=$!
while [ ! -s "$T/zombie" ] && kill -0 "$ZH" 2>/dev/null; do sleep 0.1; done
ZP=""; [ -s "$T/zombie" ] && read -r ZP < "$T/zombie"
case "$ZP" in ''|*[!0-9]*) echo "REFUSED: the zombie control was not planted" >&2; exit 9 ;; esac
leads "$DP" || { echo "REFUSED: pgrep -g does not list a live group leader (pid $DP), so liveness cannot be read" >&2; exit 9; }
kill -0 "$ZP" 2>/dev/null || { echo "REFUSED: the zombie control (pid $ZP) is already reaped, so it cannot separate this reader from kill -0" >&2; exit 9; }
! leads "$ZP" || { echo "REFUSED: pgrep -g lists the exited, waitable group leader (pid $ZP), so liveness cannot be read" >&2; exit 9; }

set -m
( cd "$T/w" && export PATH="$T/shim:$PATH" AI_DLC_FIXTURE_JOBS=2 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 \
    AI_DLC_VERDICT_STORE="$T/store" \
  && exec bash -c '. "$1" > /dev/null 2>&1; run_fixtures > "$2" 2>&1' _ "$T/block.sh" "$T/out" ) > /dev/null 2>&1 &
P=$!
set +m
# until two stubs have recorded, or the parent is gone (P leads its own group, so a zombie P reads gone)
while [ "$(nstubs)" -lt 2 ] && leads "$P"; do sleep 0.1; done
if [ "$(nstubs)" -lt 2 ]; then
  : > "$T/s/release"; wait "$P"
  echo "REFUSED: the pool started $(nstubs) stub(s) before its parent exited, want 2" >&2; exit 9
fi
PROOT="$(sed -n '1s/^[0-9]* //p' "$T/s/$(ls "$T/s" | grep '^s\.[0-9]*$' | sed -n 1p)")"
ST="$(stubs | tr '\n' ' ')"; GC="$(grands | tr '\n' ' ')"
for p in $ST $GC; do
  leads "$p" || { : > "$T/s/release"; wait "$P"; echo "REFUSED: recorded pid $p does not lead its own group before the TERM, so pgrep -g cannot read it" >&2; exit 9; }
done
[ "$(printf '%s\n' $GC | grep -c .)" = 2 ] || { : > "$T/s/release"; wait "$P"; echo "REFUSED: $(printf '%s\n' $GC | grep -c .) grandchild(ren) recorded, want 2" >&2; exit 9; }
# The orphans (see THE ORPHANS above): wait for both stubs to report their watcher polled past the orphaning.
while [ "$(ls "$T/s" | grep -c '^r\.[0-9]*$')" -lt 2 ] && leads "$P"; do sleep 0.1; done
for p in $ST; do
  r=""; [ -s "$T/s/r.$p" ] && read -r r < "$T/s/r.$p"
  [ "$r" = ok ] || { : > "$T/s/release"; wait "$P"; echo "REFUSED: stub $p read '${r:-no report}' for its watcher's polls, want ok, so the orphans were never seen connected" >&2; exit 9; }
done
OC="$(cat "$T/s"/o.* 2>/dev/null | tr '\n' ' ')"
MC=""; for p in $ST; do m=""; [ -s "$T/s/m.$p" ] && read -r m < "$T/s/m.$p"; MC="$MC $p:$m"; done
member() { # member <pid> <group>: true iff <pid> is a whole line of `pgrep -g <group>`
  case $'\n'"$(pgrep -g "$2" 2>/dev/null)"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac
  return 1
}
mlive() { # mlive <leader:member>...: how many members are still in their leader's group
  local e n=0
  for e in "$@"; do member "${e#*:}" "${e%%:*}" && n=$((n + 1)); done
  printf '%s' "$n"
}
LC="$(cat "$T/s"/l.* 2>/dev/null | tr '\n' ' ')"
[ "$(printf '%s\n' $LC | grep -c .)" = 2 ] && [ "$(mlive $LC)" = 2 ] && [ "$(alive $(for e in $LC; do printf '%s ' "${e%%:*}"; done))" = 2 ] \
  || { : > "$T/s/release"; wait "$P"; echo "REFUSED: '$LC' unseen-group leader:member pair(s), want 2 with each leader live and each member in its group" >&2; exit 9; }
[ "$(printf '%s\n' $OC | grep -c .)" = 2 ] && [ "$(alive $OC)" = 2 ] \
  || { : > "$T/s/release"; wait "$P"; echo "REFUSED: $(alive $OC) of '$OC' own-group orphan(s) lead a live group before the TERM, want 2" >&2; exit 9; }
[ "$(mlive $MC)" = 2 ] || { : > "$T/s/release"; wait "$P"; echo "REFUSED: $(mlive $MC) of '$MC' same-group orphan(s) are in their unit's group before the TERM, want 2" >&2; exit 9; }
for p in $OC; do
  for q in $ST; do member "$p" "$q" && { : > "$T/s/release"; wait "$P"; echo "REFUSED: own-group orphan $p is in unit group $q, so it is not its own group" >&2; exit 9; }; done
done
P1=$'\n'"$(pgrep -P 1 2>/dev/null)"$'\n'
for e in $OC $MC $LC; do
  case "$P1" in *$'\n'"${e#*:}"$'\n'*) ;; *) : > "$T/s/release"; wait "$P"; echo "REFUSED: orphan ${e#*:} is not a child of pid 1 (pgrep -P 1), so it is not orphaned" >&2; exit 9 ;; esac
done

# The decoy: a live process NOT in xargs' group, planted as the stale record a SIGKILLed worker leaves.
[ -n "$PROOT" ] && [ -d "$PROOT/.pr" ] || { : > "$T/s/release"; wait "$P"; echo "REFUSED: no pool record directory under '$PROOT'" >&2; exit 9; }
printf '%s\n' "$DP" > "$PROOT/.pr/zz-decoy.k"
# The sentinel: joins the group of a recorded worker (xargs' group), blocks TERM/INT/HUP, records itself.
W=""
for k in "$PROOT"/.pr/*.k; do
  [ "$k" = "$PROOT/.pr/zz-decoy.k" ] && continue
  [ -s "$k" ] || continue
  read -r W < "$k"; case "$W" in ''|*[!0-9]*) W="" ;; *) break ;; esac
done
XG=""; [ -n "$W" ] && XG="$(perl -e 'print getpgrp($ARGV[0])' "$W")"
case "$XG" in ''|*[!0-9]*|0|-1) : > "$T/s/release"; wait "$P"; echo "REFUSED: no worker record to find xargs' group from (worker '$W', group '$XG')" >&2; exit 9 ;; esac
perl -MPOSIX -e '
  my ($pg, $rel, $dir, $rec) = @ARGV;
  pipe(my $r, my $w) or exit 3;
  my $c = fork(); defined $c or exit 3;
  if ($c == 0) {
    close $r; my $g = fork(); defined $g or exit 3; POSIX::_exit(0) if $g;
    sigprocmask(SIG_BLOCK, POSIX::SigSet->new(SIGTERM, SIGINT, SIGHUP)) or POSIX::_exit(4);
    setpgid(0, $pg) or POSIX::_exit(5);
    open(my $f, ">", "$rec.t") or POSIX::_exit(6); print $f "$$ ", getpgrp(0), "\n"; close $f;
    rename("$rec.t", $rec) or POSIX::_exit(6);
    syswrite($w, "r"); close $w;
    until (-e $rel || ! -d $dir) { select(undef, undef, undef, 0.1) }
    my $p = POSIX::SigSet->new; sigpending($p);
    my $hit = ($p->ismember(SIGTERM) || $p->ismember(SIGINT) || $p->ismember(SIGHUP)) ? "signalled" : "unsignalled";
    open($f, ">>", $rec) and print $f "$hit\n"; close $f; POSIX::_exit(0);
  }
  close $w; waitpid($c, 0); my $b = ""; sysread($r, $b, 1); exit($b eq "r" ? 0 : 7);' "$XG" "$T/s/release" "$T/s" "$T/sentinel" > /dev/null 2>&1
SRC=$?
SP=""; SG=""; [ -s "$T/sentinel" ] && read -r SP SG < "$T/sentinel"
if [ "$SRC" != 0 ] || [ "$SG" != "$XG" ]; then
  : > "$T/s/release"; wait "$P"; echo "REFUSED: the sentinel did not join xargs' group $XG (perl exit $SRC, joined '$SG')" >&2; exit 9
fi

# The workers recorded before the TERM (every worker `.k` pid): once the parent is gone, the deaths wait first
# waits for each to leave xargs' group (an exited worker is reaped by xargs or init and lists nothing), so the
# claim "every KILL was sent" rests on the workers' own exits, not on how xargs reaps them.
WK=""
for k in "$PROOT"/.pr/*.k; do
  [ "$k" = "$PROOT/.pr/zz-decoy.k" ] && continue
  [ -s "$k" ] || continue
  w=""; read -r w < "$k"; case "$w" in ''|*[!0-9]*) ;; *) WK="$WK $w" ;; esac
done
# The END RECORD (see NO CLOCK AND NO BOUND above): receipt-owned, outside xargs' group, last in glob order.
( while [ ! -e "$T/s/release" ] && [ -d "$T/s" ] && kill -0 "$R881_PID" 2> /dev/null; do sleep 0.1; done ) > /dev/null 2>&1 &
EP=$!
printf '%s\n' "$EP" > "$T/s/end.pid" && printf '%s\n' "$EP" > "$PROOT/.pr/zzz-end.k" \
  || { : > "$T/s/release"; wait "$P"; echo "REFUSED: the end record could not be planted" >&2; exit 9; }

kill -TERM "$P"
# until the parent is gone, or the END RECORD was tested with ps (a pool_stop that decided every earlier record
# with ps, and so TERMed no worker under the shim); no clock decides it
while leads "$P" && [ ! -e "$T/s/end.seen" ]; do sleep 0.1; done
pgone=1; leads "$P" && pgone=0
xmember() { member "$1" "$XG"; }
pwait() { # pwait <pong tag> <reader...>: until the reader stops listing the pid (it died) or the pid answered the ping
  local tag="$1"; shift
  while "$@" && [ ! -e "$T/s/pong.$tag" ]; do sleep 0.1; done
}
if [ "$pgone" = 1 ]; then
  for w in $WK; do while xmember "$w"; do sleep 0.1; done; done
  : > "$T/s/ping"
  for p in $ST; do
    pwait "s.$p" leads "$p"
    g=""; [ -s "$T/s/g.$p" ] && read -r g < "$T/s/g.$p"; [ -n "$g" ] && pwait "g.$p" leads "$g"
    o=""; [ -s "$T/s/o.$p" ] && read -r o < "$T/s/o.$p"; [ -n "$o" ] && pwait "o.$p" leads "$o"
    m=""; [ -s "$T/s/m.$p" ] && read -r m < "$T/s/m.$p"; [ -n "$m" ] && pwait "m.$p" member "$m" "$p"
    e=""; [ -s "$T/s/l.$p" ] && read -r e < "$T/s/l.$p"; [ -n "$e" ] && pwait "n.$p" member "${e#*:}" "${e%%:*}"
  done
  pwait dp leads "$DP"
fi
n_alive="$(alive $ST)"; g_alive="$(alive $GC)"; d_alive="$(alive "$DP")"; o_alive="$(alive $OC)"; m_alive="$(mlive $MC)"; l_alive="$(mlive $LC)"
: > "$T/s/release"
wait "$P"; st=$?
wait "$DP" 2>/dev/null
wait "$EP" 2>/dev/null
n_started="$(nstubs)"
# until the sentinel has reported, or it has left xargs' group (killed, so it never reports)
while [ "$(sed -n 2p "$T/sentinel")" = "" ] && member "$SP" "$SG"; do sleep 0.1; done
sent="$(sed -n 2p "$T/sentinel")"
rc=0
if [ "$pgone" = 1 ] && [ "$st" = 143 ]; then :; else
  rc=1; echo "FAIL: A1 parent gone after the TERM=$pgone (0: the end record was tested with ps first), exit status $st, want gone and 143"
fi
[ "$n_alive" = 0 ] || { rc=1; echo "FAIL: A2 $n_alive of 2 recorded stub pid(s) still alive after the TERM, want 0"; }
[ "$g_alive" = 0 ] || { rc=1; echo "FAIL: A2 $g_alive of 2 own-group grandchild(ren) still alive after the TERM, want 0 (the unit's tree was not walked)"; }
[ "$n_started" = 2 ] || { rc=1; echo "FAIL: A3 $n_started stub(s) started, want 2 (a queued unit was dispatched after the TERM)"; }
[ -n "$PROOT" ] && [ ! -d "$PROOT" ] || { rc=1; echo "FAIL: A4 pool root '${PROOT:-unrecorded}' survives the TERM"; }
[ "$d_alive" = 1 ] || { rc=1; echo "FAIL: A5 the out-of-group decoy record's process was killed, want it alive (a record was signalled outside xargs' group)"; }
[ "$sent" = unsignalled ] || { rc=1; echo "FAIL: A5 the unrecorded sentinel in xargs' group read '${sent:-no report: killed}', want unsignalled (pool_stop signalled xargs' group, not its recorded workers)"; }
[ "$m_alive" = 0 ] || { rc=1; echo "FAIL: A6 $m_alive of 2 same-group orphan(s) (ppid 1, in the unit's group) still alive after the TERM, want 0 (the unit's own group was not killed)"; }
[ "$o_alive" = 0 ] || { rc=1; echo "FAIL: A6 $o_alive of 2 own-group orphan(s) (ppid 1, leading a group the watcher saw) still alive after the TERM, want 0 (no group seen across polls was remembered)"; }
[ "$l_alive" = 0 ] || { rc=1; echo "FAIL: A6 $l_alive of 2 member(s) (ppid 1) of an own-group child no poll saw still alive after the TERM, want 0 (a walked pid's group was not killed)"; }
[ "$rc" = 0 ] && echo "PASS: TERM -> parent exit 143, 0 of 2 stubs, 0 of 2 grandchildren and 0 of 6 orphans alive, no queued unit started, pool root removed, decoy alive, xargs' group not signalled"
exit "$rc"
