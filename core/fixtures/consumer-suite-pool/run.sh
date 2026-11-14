#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# consumer-suite-pool — the consumer's pre-push fixture suite ran SERIALLY and
# PASSED WHEN IT RAN NOTHING, and this is what stops either from coming back.
#
# THE DEFECT THIS EXISTS TO CATCH. Until v0.226.0 the suite runner in
# `core/git-hooks/pre-push` — the file install.sh copies into every consumer as
# `.githooks/pre-push`, and always overwrites — was:
#
#     for d in tests/fixtures/*/; do
#       [ -f "$d/run.sh" ] || continue
#       if bash "$d/run.sh" ...
#     done
#     return $rc
#
# with `rc` initialised to 0. Three consequences, all measured on the reference
# consumer before this release: 106 drivable fixtures run one at a time for 188.0s
# of wall clock (67.8s user against 102.3s SYSTEM — fork-bound, with 10.2x
# available from a pool); a `tests/fixtures/` whose glob matches nothing returns 0;
# and a `tests/fixtures/` whose directories carry no `run.sh` returns 0 as well.
# The last two are the gate reporting a pass it never earned, in the only fixture
# gate a consumer has.
#
# WHAT IT ASSERTS, and the two halves are deliberately not the same kind of claim:
#
#   CORRECTNESS  an empty suite FAILS in both its forms; a dropped worker is
#                reported as a missing VERDICT rather than silently shortening a
#                green report; a real failure names WHICH fixture and does not
#                mask its neighbours; the report is in list order whatever order
#                the work finished in.
#   SPEED        the pool is really a pool — measured by having the fixtures
#                OBSERVE each other running, not by timing the wall clock, because
#                a wall-clock threshold is the timing-sensitive assertion §7's gate
#                warns starts failing for reasons unrelated to what it tests.
#
# THE SUBJECT IS THE SHIPPED FILE, RESOLVED IN BOTH LAYOUTS. install.sh splits what
# shares a parent in this repo, so the hook is `core/git-hooks/pre-push` here and
# `.githooks/pre-push` in a consumer. Both are named from this fixture's OWN
# location; neither is reached by walking up from a path another resolver produced
# (I33), and if neither exists this fixture reports FIXTURE ERROR rather than
# scoring the absence as a pass.
#
# EVERY MUTANT IS A COPY GUARDED BY `cmp -s`, and an UNMUTATED control copy runs in
# the same battery: the hook is driven ten times here, so a harness that broke would
# otherwise let every mutant score a kill it had not earned.
#
# MUTANT MATRIX. Every mutant is driven once, on the world its base arm drives, and judged on named
# cells of that drive against the base values the unmutated hook gave in the same run. Per push a
# mutant runs its DECIDING cells (which must trip) and its TWIN cells (which the measured matrix
# shows stay green, so the kill is confined to the deciding cells). `--matrix` evaluates every cell
# and prints MATRIX rows (from matrix.sh) with the column names used below. This matrix replaces the
# earlier exact-vector assertions. The matrix is re-measured as .claude/rules/fixture-mutants.md
# clause 2 ("One run per distinct state") requires.
# MUTANT-MATRIX-DYNAMIC csp_score why=csp_score passes its first argument to mutant_killed; every csp_score call names a literal mutant that carries its own row in this block
# MUTANT-MATRIX-REMEASURE bash core/fixtures/consumer-suite-pool/run.sh --matrix
# MUTANT-MATRIX m1 decides=rc,nofix twins=- why=the guard's removal moves every cell of its drive (rc 1 to 0 and the message gone), so no cell stays green
# MUTANT-MATRIX-CONTROL m2 why=the per-fixture 'no verdict recorded' line still detects the dropped worker (rc 1, line present, count line absent), so the mutation survives by design
# MUTANT-MATRIX m2b decides=noverdict,countline twins=rc
# MUTANT-MATRIX m3 decides=maxpar_ge2 twins=rc
# MUTANT-MATRIX m4 decides=rec twins=rc
# MUTANT-MATRIX retain-off decides=copies twins=rec,shaped
# MUTANT-MATRIX retain-fixed-name decides=copies,seed19 twins=rec,h179
# MUTANT-MATRIX prune-off decides=shaped,oldest twins=copies,rec
# MUTANT-MATRIX prune-glob-wide decides=h179 twins=cleanc,rec
# MUTANT-MATRIX prune-suffix-unanchored decides=keepc twins=h179,cleanc
# MUTANT-MATRIX at-helper decides=at_dur,at_ver,at_stall twins=at_last,rc
# MUTANT-MATRIX at-last-entry decides=at_last twins=at_dur,rc
# MUTANT-MATRIX at-dur decides=at_dur twins=at_last,rc
# MUTANT-MATRIX at-fail decides=at_fail twins=rec,copies
# MUTANT-MATRIX lock-off decides=lockheld twins=rc
# MUTANT-MATRIX lock-empty-pid decides=lsf twins=lso
# MUTANT-MATRIX st-a decides=v_s twins=v_alpha
# MUTANT-MATRIX st-w decides=v_w twins=v_alpha
# MUTANT-MATRIX st-cpu decides=v_p twins=v_alpha
# MUTANT-MATRIX st-b decides=v_h,rc twins=v_alpha
# MUTANT-MATRIX st-c decides=live_h twins=v_h,v_alpha
# MUTANT-MATRIX st-d decides=live_gh twins=v_gh,v_alpha
# MUTANT-MATRIX st-e decides=wl,ul twins=- why=removing the liveness check makes the watcher outlive the worker and the unit's tree, so both cells of its drive trip
# MUTANT-MATRIX st-g decides=ul twins=wl
# MUTANT-MATRIX st-x decides=tv twins=rv
# MUTANT-MATRIX st-r decides=rv twins=tv
# MUTANT-MATRIX bl998-kw0 decides=s1.rec2 twins=s2.rec2
# MUTANT-MATRIX bl998-sw0 decides=s2.rec2 twins=s1.rec2
# MUTANT-MATRIX bl998-rd-early decides=s1.rec2 twins=s3.rec2
# MUTANT-MATRIX bl998-rd-pool decides=s3.rec2 twins=s1.rec2
# MUTANT-MATRIX bl998-carry-v decides=sv.rec2 twins=s1.rec2
# MUTANT-MATRIX bl998-carry-vs decides=s2.rec2 twins=s1.rec2
# MUTANT-MATRIX bl998-unrec-store decides=sk.pran twins=s2.vs
# MUTANT-MATRIX bl998-unrec-key decides=su.pran twins=s1.rec2
# st-c is built from two anchors (the helper calls st-c1 then st-c); st-c1 is the first layer of st-c and is not a mutant of its own.
set -uo pipefail

# HERMETICITY, and I10 is what required it rather than my remembering to. This fixture
# drives a hook, and the hook reads AI_DLC_FIXTURE_JOBS. An operator with that set to 1
# in their environment would fail the concurrency arm below against a hook behaving
# exactly as configured — and since the arm lives in the pre-push suite, that failure
# blocks every push they make. Scrub every AI_DLC_* before the first drive; the two
# arms that need a value set it explicitly on their own command.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "consumer-suite-pool: FIXTURE BROKEN" >&2; exit 2; }

echo "consumer-suite-pool:"

# `--matrix` (argv only) makes the mutant batteries evaluate EVERY cell of their own drive and
# print one MATRIX row per cell; a plain run evaluates only each mutant's deciding and twin cells.
MATRIX=0; [ "${1:-}" = --matrix ] && MATRIX=1

# lib/mutant.sh needs ok() and bad(); matrix.sh owns the cell judge and prints every MATRIX row.
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || broken "lib/mutant.sh not found beside $HERE"
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
[ -f "$HERE/matrix.sh" ] || broken "matrix.sh not found beside $HERE"
. "$HERE/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/consumer-suite-pool/matrix.sh"

# Both layouts, named rather than derived from one another. The root is found by walking UP from this
# fixture's own directory for a marker, the way ai_dlc_resolve_root() does in
# core/scripts/validate-provenance-block.sh, never by counting `..` hops. The marker is the layout's own
# hook, tried distribution first at each level (a distribution root carries .githooks/pre-push too), and
# the layout found names its runner: install.sh copies core/git-hooks/pre-push to .githooks/pre-push and
# core/scripts/* to scripts/ai-dlc/. Not .git/.claude: hermetic-run.sh's sandbox root carries neither, by design.
HOOK=""; HR_SRC=""; CSP_ROOT=""
d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
  if [ -f "$d/core/git-hooks/pre-push" ]; then HOOK="$d/core/git-hooks/pre-push"; HR_SRC="$d/core/scripts/hermetic-run.sh"; CSP_ROOT="$d"; break; fi
  if [ -f "$d/.githooks/pre-push" ]; then HOOK="$d/.githooks/pre-push"; HR_SRC="$d/scripts/ai-dlc/hermetic-run.sh"; CSP_ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$HOOK" ] || broken "cannot locate the pre-push hook in either layout (core/git-hooks/pre-push or .githooks/pre-push) above $HERE"

echo "HERMETIC-CONSUMED $(cd "$(dirname "$HOOK")" && pwd -P)/${HOOK##*/}"
# The hermetic runner, installed into the BL-998 world (arm 7b) as a consumer holds it.
[ -f "$HR_SRC" ] || broken "cannot locate hermetic-run.sh for this layout: $HR_SRC (core/scripts/ or scripts/ai-dlc/)"
echo "HERMETIC-CONSUMED $(cd "$(dirname "$HR_SRC")" && pwd -P)/hermetic-run.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/consumer-suite-pool.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT
WORK_P="$(cd "$WORK" && pwd -P)" && [ -n "$WORK_P" ] || broken "cannot resolve the physical path of $WORK"   # csp_own compares lsof's cwd, which is physical

# ---------------------------------------------------------------- seed helpers --
# A real git repository, because the hook's first act is
# `cd "$(git rev-parse --show-toplevel)"`. A seed without one would exercise a code
# path no push ever takes.
seed() {                       # seed <dir> <hookfile>
  local t="$1" h="$2"
  mkdir -p "$t/.githooks" "$t/tests/fixtures" || return 1
  cp "$h" "$t/.githooks/pre-push" || return 1
  chmod +x "$t/.githooks/pre-push"
  git -C "$t" init -q >/dev/null 2>&1 || return 1
  git -C "$t" config user.email f@x >/dev/null 2>&1
  git -C "$t" config user.name  f   >/dev/null 2>&1
  return 0
}

# A fixture whose driver exits with the code it is told to.
mkfx() {                       # mkfx <tree> <name> <exitcode>
  mkdir -p "$1/tests/fixtures/$2"
  printf '#!/usr/bin/env bash\nexit %s\n' "$3" > "$1/tests/fixtures/$2/run.sh"
}

# A fixture that PRINTS a distinctive token on both streams before exiting with the code it
# is told to. The token is what arm 2b traces from the worker to the durable record: an
# assertion that the record merely EXISTS would pass against a file the hook created and
# never filled, which is the same empty-artifact shape this fixture exists to refuse one
# layer out.
mkfx_noisy() {                 # mkfx_noisy <tree> <name> <exitcode> <token>
  mkdir -p "$1/tests/fixtures/$2"
  printf '#!/usr/bin/env bash\necho "%s-stdout"\necho "%s-stderr" >&2\nexit %s\n' \
    "$4" "$4" "$3" > "$1/tests/fixtures/$2/run.sh"
}

# A fixture that KILLS ITS OWN WORKER before the worker can record a verdict. This
# is the real shape of a dropped job — the pool loses the process, so no verdict
# file is written — and it is the only way to reach the completeness arm without
# reaching inside the hook to fake it.
#
# THE KILL WAITS FOR ITS NEIGHBOUR TO HAVE STARTED. xargs stops launching units once a child dies of a signal,
# and a nested pool is two wide, so whether the unit after the dropped one was launched at all followed the
# order in which two workers happened to be reaped: the drop worlds then ran 12 or 15 starts of that unit and the
# count moved with the load. The dropped unit now blocks (a `read` on a wake fifo, no process start, no bound) until
# `started` exists, and the neighbour (mkfx_marker) writes it as its first act and then wakes the read; a hook
# that never launches the neighbour hangs here, which is a hang to read and not a verdict.
mkfx_kill() {
  mkdir -p "$1/tests/fixtures/$2"
  cat > "$1/tests/fixtures/$2/run.sh" <<'FX'
#!/usr/bin/env bash
w="$(cd "$(dirname "$0")/../../.." && pwd)"
exec 9<>"$w/wake"
while [ ! -e "$w/started" ]; do read -u 9 x; done
kill -9 "$PPID" 2>/dev/null
FX
}
mkfx_marker() {                # mkfx_marker <tree> <name> <exitcode> : a unit that announces it has started, then exits
  mkdir -p "$1/tests/fixtures/$2"
  cat > "$1/tests/fixtures/$2/run.sh" <<FX
#!/usr/bin/env bash
w="\$(cd "\$(dirname "\$0")/../../.." && pwd)"
: > "\$w/started"; exec 9<>"\$w/wake"; echo w >&9
exit $3
FX
}

# A fixture that OBSERVES how many of its siblings are running at the same moment.
# Each writes its own marker, waits, counts the markers present, then REMOVES ITS
# OWN. Serially every fixture sees exactly 1; through a pool of width >= 2 at least
# one sees more. This is an observation of overlap, not a wall-clock threshold.
#
# THE REMOVAL IS THE INSTRUMENT, and leaving it out is how this arm first read
# green against a serial hook: markers that are never cleared count everything that
# has EVER run, so a serial suite reports 1, 2, 3, 4 and its maximum is the fixture
# count. The number looked like concurrency and was arithmetic. The `-P1` control
# below is what catches that, which is exactly why it is here.
#
# THE OVERLAP IS AWAITED ON A SENTINEL, NEVER ON A TIMER. Each unit holds its marker until it sees a
# sibling's marker (or a `seen` line that already records an overlap), so the verdict does not depend
# on how far apart a loaded scheduler starts the workers. CSP_BARRIER_N bounds the wait in 0.05s
# steps only where it is set: unset, the wait is unbounded on its condition, and the worlds that cannot overlap
# whatever the scheduling (-P1, and the m3 mutant) set it small because their bound decides nothing.
mkfx_observe() {
  mkdir -p "$1/tests/fixtures/$2"
  cat > "$1/tests/fixtures/$2/run.sh" <<'FX'
#!/usr/bin/env bash
: > "$CSP_OBSERVE/$$"
n=0
while :; do  # bl868-allow: csp-barrier-cap
  c="$(ls "$CSP_OBSERVE" | wc -l | tr -d ' ')"
  [ "$c" -ge 2 ] && break
  grep -q '^[2-9]' "$CSP_OBSERVE/../seen" 2>/dev/null && break
  n=$((n + 1)); [ -z "${CSP_BARRIER_N:-}" ] || [ "$n" -lt "$CSP_BARRIER_N" ] || break
  sleep 0.05
done
echo "$c" >> "$CSP_OBSERVE/../seen"
rm -f "$CSP_OBSERVE/$$"
exit 0
FX
}

# Seed what twenty EARLIER red runs would have retained, plus two records an operator saved by
# hand. The seeds carry year-2000 stamps so this run's own copy sorts newest, and each holds
# distinct content so "survived" is a content claim rather than an existence one.
#
# THREE DECOYS, AND ONLY ONE OF THE FIRST TWO CAN DISCRIMINATE A WIDE GLOB. The prune sorts by NAME, and
# `.clean` sorts ABOVE every digit-stamped copy, so under `ai-dlc-fixture-failures.*` it reads
# as the newest entry and survives anyway -- an arm keyed on it alone passes against the very
# mutant it exists for. `.179.1` sorts BELOW the year-2000 seeds, so a wide prune takes it
# first. `.clean` stays because it is the operator's real file on this machine; the kill comes
# from `.179.1`. ITS LAST FIELD IS ALL DIGITS ON PURPOSE: spelled `.179.saved` it was skipped by
# the end anchor even under a widened glob, so the wide-glob mutant survived. It has to fail the
# FRONT anchor only, which is the one that mutant removes.
seed_retained() {              # seed_retained <tree>
  local g="$1/.git" i
  for i in 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19; do
    printf 'SEED-%s-CONTENT\n' "$i" > "$g/ai-dlc-fixture-failures.20000101T0000${i}Z.1" || return 1
  done
  printf 'OPERATOR-CLEAN\n' > "$g/ai-dlc-fixture-failures.clean" || return 1
  printf 'OPERATOR-179\n'   > "$g/ai-dlc-fixture-failures.179.1" || return 1
  # THE THIRD DECOY: a retained copy an operator kept by appending `.keep`. It passes the glob's
  # FRONT anchor and sorts between the two oldest seeds, inside the band a prune of 22 shaped
  # names removes, so only the hook's end anchor (the all-digit last field) stands between it
  # and the prune. Neither decoy above can see that anchor. The fixture's own `retained_names`
  # grammar excludes it, so it never counts toward the bound of 20.
  printf 'OPERATOR-KEEP\n'  > "$g/ai-dlc-fixture-failures.20000101T000000Z.1.keep" || return 1
}

# Every name of the GENERATED shape, written with a stricter grammar than the hook's glob so
# the two cannot agree by sharing a mistake.
retained_names() {             # retained_names <tree>
  ls "$1/.git" | grep -E '^ai-dlc-fixture-failures\.2[0-9]{3}[01][0-9][0-3][0-9]T[0-9]{6}Z\.[0-9]+$'
}
# This run's copies: the shaped names that are not year-2000 seeds.
new_retained() {               # new_retained <tree>
  retained_names "$1" | grep -v '^ai-dlc-fixture-failures\.2000'
}

# Drive the hook. stdin is /dev/null, never a terminal: on a terminal the hook's own
# `[ -t 0 ]` guard leaves PUSH_REFS empty and arm 0 says so, which is a different run
# from the one a real push makes.
drive() {                      # drive <tree> <outfile>  -> rc
  ( cd "$1" && AI_DLC_READSET_LIVE_TRACE=0 bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}

# ------------------------------------------------- world cells, builders and the drive ---
# A CELL is one named observable of one driven world. A mutant is scored on cells of ITS OWN drive
# (matrix.sh judges them against the base values the UNMUTATED hook gave on the same world in this
# run); the worlds are built by the same cw_* functions for the base arms and for the mutants, so a
# base value and a mutant value are never taken from two different trees.
C_T=""; C_RC=""; C_O=""; C_LH=""; C_LGH=""; C_WL=""; C_UL=""; C_HOOK=""; C_TAG=""
yn() { if "$@"; then echo yes; else echo no; fi; }
csp_cell() {                   # csp_cell <cell> -> the value of one named observable of the loaded state
  local m
  case "$1" in
    rc) printf '%s' "$C_RC" ;;
    nofix) yn grep -q 'no fixtures found' "$C_O" ;;
    noverdict) yn grep -q 'no verdict recorded' "$C_O" ;;
    countline) yn grep -q 'fixtures produced a verdict' "$C_O" ;;
    maxpar_ge2) m="$(sort -n "$C_T/seen" 2>/dev/null | tail -1)"; yn [ "${m:-0}" -ge 2 ] ;;
    rec) yn [ -s "$C_T/.git/ai-dlc-fixture-failures" ] ;;
    copies) m="$(new_retained "$C_T" 2>/dev/null | grep -c .)" || m=0; printf '%s' "$m" ;;
    shaped) retained_names "$C_T" 2>/dev/null | wc -l | tr -d ' ' ;;
    oldest) yn [ -e "$C_T/.git/ai-dlc-fixture-failures.20000101T000000Z.1" ] ;;
    h179) yn [ -e "$C_T/.git/ai-dlc-fixture-failures.179.1" ] ;;
    keepc) yn [ -e "$C_T/.git/ai-dlc-fixture-failures.20000101T000000Z.1.keep" ] ;;
    cleanc) yn [ "$(cat "$C_T/.git/ai-dlc-fixture-failures.clean" 2>/dev/null)" = OPERATOR-CLEAN ] ;;
    seed19) yn [ "$(cat "$C_T/.git/ai-dlc-fixture-failures.20000101T000019Z.1" 2>/dev/null)" = SEED-19-CONTENT ] ;;
    v_*) stv "$C_O" "${1#v_}" ;;
    live_h) printf '%s' "$C_LH" ;;
    live_gh) printf '%s' "$C_LGH" ;;
    wl) printf '%s' "$C_WL" ;;
    ul) printf '%s' "$C_UL" ;;
    at_*) eval "printf '%s' \"\${C_AT_${1#at_}:-}\"" ;;
    lockheld) printf '%s' "$C_LOCK" ;;
    lsf) ls_judge "$C_HOOK" fresh ;;
    lso) ls_judge "$C_HOOK" old ;;
    tv) st_trace "$C_HOOK" "$C_TAG-t" t ;;
    rv) st_trace "$C_HOOK" "$C_TAG-r" r ;;
    s1.*|s2.*|s3.*|s4.*|s5.*|su.*|sv.*|sk.*|cl.*) bl_cell "$1" ;;
    *) echo "<unknown cell $1>" ;;
  esac
}
csp_vec() { local c; for c in "$@"; do printf '%s=%s\n' "$c" "$(csp_cell "$c")"; done; }
csp_load() { C_T="$1"; C_RC="$2"; C_O="$3"; }
# ------------------------------- shared records are replaced by rename (BL-1046) ---
# Pushes may run concurrently, and every record under the git common dir is shared by all of them. A
# record written IN PLACE (`cp` over it, `>` into it) hands a concurrent reader a torn file; one REPLACED
# BY RENAME leaves a reader holding the old file with the old bytes whole. So each seeded record is held
# open on its own descriptor ACROSS the drive -- a concurrent reader, without a race -- and judged after:
#   atomic     the descriptor still reads the seed and the path holds new bytes (a rename replaced it)
#   inplace    the descriptor reads what the path now holds (the hook wrote into the reader's file)
#   unwritten  the path still holds the seed
at_rec() { case "$1" in dur) echo ai-dlc-fixture-durations ;; last) echo ai-dlc-fixture-durations.last ;;
  ver) echo ai-dlc-fixture-verified ;; stall) echo ai-dlc-pool-stall.last ;; fail) echo ai-dlc-fixture-failures ;; esac; }
at_fd() { case "$1" in dur) echo 3 ;; last) echo 4 ;; ver) echo 5 ;; stall) echo 6 ;; fail) echo 7 ;; esac; }
AT_OPEN=""
at_seed() {                    # at_seed <tree> <key...>: seed each record with AT-OLD-<key> and hold it open
  local t="$1" k; shift; AT_OPEN=""
  for k in "$@"; do
    printf 'AT-OLD-%s\n' "$k" > "$t/.git/$(at_rec "$k")" || broken "could not seed $(at_rec "$k")"
    eval "exec $(at_fd "$k")<\"\$t/.git/\$(at_rec \"\$k\")\"" || broken "could not hold $(at_rec "$k") open"
    AT_OPEN="$AT_OPEN $k"
  done
}
at_snap() {                    # at_snap <tree>: read each held descriptor once, judge it, close it
  local k fd old cur
  C_AT_dur=""; C_AT_last=""; C_AT_ver=""; C_AT_stall=""; C_AT_fail=""
  for k in $AT_OPEN; do
    fd="$(at_fd "$k")"
    old="$(cat <&"$fd")"; eval "exec $fd<&-"
    cur="$(cat "$1/.git/$(at_rec "$k")" 2>/dev/null)" || cur=""
    if [ "$old" = "AT-OLD-$k" ] && [ -n "$cur" ] && [ "$cur" != "AT-OLD-$k" ]; then old=atomic
    elif [ "$cur" = "AT-OLD-$k" ]; then old=unwritten
    elif [ "$old" = "$cur" ]; then old=inplace
    else old=other; fi
    eval "C_AT_$k=\$old"
  done
  AT_OPEN=""
}
# THE DURATIONS MERGE IS A READ-MODIFY-WRITE, so it runs under a lock. The lock world holds that lock
# with a LIVE pid (this fixture's own) on a green suite: the record must come back byte-identical, the
# run must say it skipped the merge, and the lock must still be the holder's. The green world is its
# ALLOW twin: no lock, and the record is merged (at_dur atomic).
C_LOCK=""
cw_lock() {
  seed "$1" "$2" || broken "seed failed"
  mkfx "$1" alpha 0
  printf 'alpha 777\n' > "$1/.git/ai-dlc-fixture-durations" || broken "could not seed the durations record"
  mkdir "$1/.git/ai-dlc-fixture-durations.lock" && printf '%s %s\n' "$$" "$(date +%s)" > "$1/.git/ai-dlc-fixture-durations.lock/pid" \
    || broken "could not take the durations lock for the lock world"
}
lock_snap() {                  # lock_snap <tree> <outfile>
  C_LOCK=no
  [ "$(cat "$1/.git/ai-dlc-fixture-durations" 2>/dev/null)" = 'alpha 777' ] \
    && grep -q 'durations record: another push holds' "$2" \
    && [ "$(cut -d' ' -f1 "$1/.git/ai-dlc-fixture-durations.lock/pid" 2>/dev/null)" = "$$" ] && C_LOCK=yes
}
# AN EMPTY PID FILE IS A WRITER MID-WRITE, NOT A MALFORMED LOCK. readset_lock_stale, cut from the hook
# under test, judges a lock dir holding an empty pid file: a fresh one must read HELD (a concurrent push
# must not steal it); one whose dir is older than 60s must read STALE (a launcher that died).
ls_judge() {                   # ls_judge <hook> <fresh|old> -> held | stale | broken
  local d
  d="$(mktemp -d "$WORK/ls.XXXXXX")" || { echo broken; return; }
  { awk '/^readset_pid_start\(\) \{/,/^}/' "$1"; awk '/^readset_lock_stale\(\) \{/,/^}/' "$1"; } > "$d/lib.sh"
  grep -q '^readset_lock_stale() {' "$d/lib.sh" || { echo broken; return; }
  mkdir "$d/l.lock" && : > "$d/l.lock/pid" || { echo broken; return; }
  [ "$2" = old ] && { touch -t 200001010000 "$d/l.lock" || { echo broken; return; }; }
  if ( . "$d/lib.sh" && readset_lock_stale "$d/l.lock" ) >/dev/null 2>&1; then echo stale; else echo held; fi
}
cw_green() {                   # alpha waits for bravo's and charlie's verdicts so it finishes LAST; bravo is noisy and green
  seed "$1" "$2" || broken "seed failed"
  mkdir -p "$1/tests/fixtures/alpha"
  cat > "$1/tests/fixtures/alpha/run.sh" <<'FX'
#!/usr/bin/env bash
until [ -s "$AI_DLC_FX_OUT/bravo" ] && [ -s "$AI_DLC_FX_OUT/charlie" ]; do sleep 0.05; done
exit 0
FX
  mkfx_noisy "$1" bravo 0 GREENTOKEN; mkfx "$1" charlie 0
  at_seed "$1" dur last ver stall
}
cw_retain() {                  # the arm-2c world: twenty seeds, three decoys, one noisy red
  seed "$1" "$2" || broken "seed failed"
  seed_retained "$1" || broken "seeding retained copies failed"
  [ "$(retained_names "$1" | wc -l | tr -d ' ')" = 20 ] || broken "the retained-copy seed did not produce 20 shaped names — every arm below would read a world nobody built"
  mkfx "$1" alpha 0; mkfx_noisy "$1" bravo 1 CSPTOKEN; mkfx "$1" charlie 0
  at_seed "$1" fail
}
cw_empty() {                   # directories exist, none carries a run.sh
  seed "$1" "$2" || broken "seed failed"
  mkdir -p "$1/tests/fixtures/alpha" "$1/tests/fixtures/bravo"
  printf 'data\n' > "$1/tests/fixtures/alpha/seed.txt"
}
cw_drop() {                    # one fixture kills its own worker before it records a verdict
  seed "$1" "$2" || broken "seed failed"
  mkfifo "$1/wake" || broken "mkfifo failed"
  mkfx "$1" alpha 0; mkfx_kill "$1" bravo; mkfx_marker "$1" charlie 0
}
cw_pool() {
  seed "$1" "$2" || broken "seed failed"
  export CSP_OBSERVE="$1/observe"; mkdir -p "$CSP_OBSERVE"
  for n in alpha bravo charlie delta; do mkfx_observe "$1" "$n"; done
}
cw_run() {                     # cw_run <world> <tree> <hook> -> builds, drives and loads the world's state
  "cw_$1" "$2" "$3"
  csp_load "$2" "$(drive "$2" "$2.out")" "$2.out"
  at_snap "$2"
  [ "$1" = lock ] && lock_snap "$2" "$2.out"
  unset CSP_OBSERVE
}
# csp_score <mutant> <base-flag> <decides> <twins|-> <expected-lines> <all-cells> <base-vector> <message>
csp_score() {
  local cells got c
  cells="$(mx_cells "$6" "$3" "$4")"
  got="$(for c in $cells; do printf '%s=%s\n' "$c" "$(csp_cell "$c")"; done)"
  if mx_judge "$1" "$3" "$4" "$got" "$7" "$5"; then
    mutant_killed "$2" "$1" "$8"
  else
    bad "MUTANT $1: deciding [$3] twins [$4] did not behave as recorded:$MX_WHY"
  fi
}

# ------------------------------------------------------------- 1. green baseline --
# Asserted FIRST and positively. Every arm below reads the same output shape, so an
# assertion that the shape is produced at all has to come before any of them.
# ONE drive serves four questions about an all-green tree: the baseline, the report order (alpha
# waits on its siblings' verdict files so it finishes LAST and must still render first), the green-run CONTROL of arm 2b (bravo
# is noisy and green: a record naming its token would mean every unit is captured), and the
# mutant battery's base vector. Each question keeps its own assertion.
_f0=$fails
T="$WORK/green"
cw_run green "$T" "$HOOK"
g_rc="$C_RC"; rc="$g_rc"
BASE_green="$(csp_vec rc rec)"
BASE_at_green="$(csp_vec rc at_dur at_last at_ver at_stall)"
g_ret="$(retained_names "$T" | wc -l | tr -d ' ')"
if [ "$rc" = 0 ] && grep -q 'ok    alpha' "$WORK/green.out" \
                 && grep -q 'ok    bravo' "$WORK/green.out" \
                 && grep -q 'ok    charlie' "$WORK/green.out" \
                 && grep -q 'all gates green' "$WORK/green.out"; then
  ok "three drivable fixtures: all three report ok, hook exits 0"
else
  bad "green baseline did not pass (rc=$rc); every arm below reads this shape: $(tr '\n' ' ' < "$WORK/green.out" | tail -c 300)"
fi

# The step label carries the pool width, so an operator reading a push can see which
# schedule produced the verdicts below it.
grep -q 'fixture suite (.*-way)' "$WORK/green.out" \
  && ok "the suite step names its pool width" \
  || bad "the suite step does not name its pool width — the schedule that produced these verdicts is unstated"

# ------------------------------------------- 6. the report is in LIST order --------
# Work completes out of order under a pool; the report must not. A non-deterministic
# report cannot be diffed across runs, which is how a suite's own output stops being
# evidence about what changed. Read off the green drive above, where alpha finishes last.
# The `   done k/N  verdict unit` progress line also ends with the unit name but prints in
# COMPLETION order, so it is excluded on purpose: this arm reads the report rows only.
seen_order="$(grep -v '^   done ' "$WORK/green.out" | grep -oE '(alpha|bravo|charlie)$' | tr '\n' ' ')"
if [ "$g_rc" = 0 ] && [ "$seen_order" = "alpha bravo charlie " ]; then
  ok "verdicts render in list order even though 'alpha' finished last"
else
  bad "the report is not in list order (rc=$g_rc, got '$seen_order') — the output is not diffable across runs"
fi

# CONTROL, and it is the arm that stops the evidence arms below from passing on a hook that writes
# the record unconditionally. A green run must leave no record naming this token: without this,
# `grep CSPTOKEN` would be satisfied by a capture of every unit whether it failed or not, and
# the selector could be `true`. THE DISCRIMINATING INPUT is the noisy GREEN unit: it prints
# GREENTOKEN on both streams and exits 0, so a hook that captured every unit (mutant m4) writes
# the record and names GREENTOKEN, and this arm reads it. alpha's wait on its siblings only orders the
# report; it adds no output and no failure, so it cannot make the record appear or vanish.
if [ "$g_rc" = 0 ] && ! grep -q 'GREENTOKEN' "$T/.git/ai-dlc-fixture-failures" 2>/dev/null \
   && ! grep -q 'captured output for the failing unit' "$WORK/green.out" \
   && [ "$g_ret" = 0 ]; then
  ok "CONTROL: an all-green run records no failure, names no record and retains no copy — the selector is the verdict, not every unit"
else
  bad "a green run wrote a failure record, announced one, or retained $g_ret copies (rc=$g_rc) — the capture fires on units that passed"
fi
B_green=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)

# ------------------------------- 7. a green fixture's PENDING rows are counted (BL-998) --
# A shipped fixture whose subject is absent prints `PENDING  <what>` rows and exits 0, and its ok row used to read
# the same as a pass. pend prints two rows, one in each shape the shipped emitters use (indented, and at column 0);
# near is its near-miss, carrying the word where no row starts and once with one space, and must render bare. Its
# own world, because the green world's report rows are read by name at end of line.
T="$WORK/pend"
seed "$T" "$HOOK" || broken "seed failed"
mkdir -p "$T/tests/fixtures/pend" "$T/tests/fixtures/near"
printf '#!/usr/bin/env bash\necho "  PENDING  csp: the subject is absent"\necho "PENDING  csp: a second absent part"\nexit 0\n' > "$T/tests/fixtures/pend/run.sh"
printf '#!/usr/bin/env bash\necho "near: not PENDING  here"\necho "PENDING (one space, a different row)"\nexit 0\n' > "$T/tests/fixtures/near/run.sh"
p_rc="$(drive "$T" "$WORK/pend.out")"
if [ "$p_rc" = 0 ] \
   && grep -qxF '   ok    pend  (2 PENDING row(s): its subject is absent, so those parts checked nothing)' "$WORK/pend.out" \
   && grep -qxF '   ok    near' "$WORK/pend.out" \
   && grep -qxF '   PENDING: 1 green fixture(s) printed a PENDING row, so part of each checked nothing: pend' "$WORK/pend.out"; then
  ok "a green fixture's PENDING rows are counted on its ok row and named once after the report; its near-miss renders bare"
else
  bad "PENDING count (rc=$p_rc): $(grep -E 'ok    |PENDING' "$WORK/pend.out" | grep -v '^   done ' | tr '\n' '|' | tail -c 400)"
fi

# ------------------- 2. a real failure is attributed; 2b/2c its record is kept ------
# ONE red drive over the arm-2c world (twenty seeded copies, three decoys, one noisy red) serves the
# attribution arm, the evidence arms and the retention arms: all of them ask about the same red run.
# 2b's DEFECT. The worker used to run `bash "$d/run.sh" >/dev/null 2>&1`, so a red unit left
# exactly one line of evidence — `FAIL <name>` — and the temp dir holding everything else was
# `rm -rf`d on the way out. Filed by the graph consumer as
# PC-S302-FIXTURE-SUITE-POOL-PRODUCES-AN-UNREPRODUCIBLE-FAIL-AND-THE-EVIDENCE-IS-DELETED-WITH-THE-TEMP-DIR.
# 2c's DEFECT. The record is OVERWRITTEN by the next red run, so two reds in a row left only the
# second. Measured at batch 179: one intermittent red's got-vector was the only evidence of its
# cause, and it sat in a file the next red would replace. Seeded with twenty earlier copies and two
# hand-saved records, then ONE red drive: that is the N+1 case without twenty-one drives of the hook.
# TRACED BY TOKEN, NOT BY EXISTENCE, and both streams are asserted separately: a capture that
# took stdout and dropped stderr would satisfy a file-exists check and lose the half a shell
# fixture writes its diagnostics to.
_f0=$fails
T="$WORK/retain"
cw_run retain "$T" "$HOOK"
rc="$C_RC"
BASE_retain="$(csp_vec rc rec copies shaped oldest h179 keepc cleanc seed19)"
BASE_at_retain="$(csp_vec rc rec copies at_fail)"
if [ "$rc" = 1 ] && grep -q 'FAIL  bravo' "$WORK/retain.out" \
                 && grep -q 'ok    alpha' "$WORK/retain.out" \
                 && grep -q 'ok    charlie' "$WORK/retain.out"; then
  ok "a failing fixture is named, and its neighbours still report their own verdicts"
else
  bad "a failing fixture was not attributed (rc=$rc) — xargs collapses failures into one exit code, so the verdict has to come from the per-fixture files"
fi

REC="$T/.git/ai-dlc-fixture-failures"
if [ "$rc" = 1 ] && [ -s "$REC" ] \
   && grep -q 'CSPTOKEN-stdout' "$REC" && grep -q 'CSPTOKEN-stderr' "$REC"; then
  ok "a red unit's stdout AND stderr survive the run in a durable record"
else
  bad "the red unit's output did not reach $REC (rc=$rc, record $( [ -s "$REC" ] && echo present || echo absent)) — a fixture that fails under the pool leaves nothing to read"
fi

# The record is useless if nobody is told it exists. The BLOCKED line sits OUTSIDE the
# FIXTURE_POOL sentinels and is bound by no invariant, so the path is named from inside the
# pool where I66 holds the two hooks to one program.
grep -q 'captured output for the failing unit(s): .git/ai-dlc-fixture-failures' "$WORK/retain.out" \
  && ok "the run names the record's path, so the operator does not have to know it exists" \
  || bad "the failing run never named the record path — an artifact nobody is pointed at is one nobody reads"

R_NEW="$(new_retained "$T")"
R_NEWN="$(printf '%s' "$R_NEW" | grep -c . )" || R_NEWN=0
if [ "$rc" = 1 ] && [ "$R_NEWN" = 1 ] && grep -q 'CSPTOKEN-stdout' "$T/.git/$R_NEW" \
   && cmp -s "$T/.git/$R_NEW" "$T/.git/ai-dlc-fixture-failures"; then
  ok "a red run retains exactly one copy of its own record under a stamped name, byte-identical to the primary"
else
  bad "the red run did not retain one stamped copy of its record (rc=$rc, new copies $R_NEWN) — the next red overwrites the only evidence"
fi

R_ALL="$(retained_names "$T" | wc -l | tr -d ' ')"
if [ "$R_ALL" = 20 ] && [ ! -e "$T/.git/ai-dlc-fixture-failures.20000101T000000Z.1" ] \
   && [ "$(cat "$T/.git/ai-dlc-fixture-failures.20000101T000019Z.1" 2>/dev/null)" = SEED-19-CONTENT ] \
   && [ "$(cat "$T/.git/ai-dlc-fixture-failures.20000101T000001Z.1" 2>/dev/null)" = SEED-01-CONTENT ]; then
  ok "the twenty-first copy prunes the OLDEST by name; every younger earlier record survives with its own content"
else
  bad "the prune bound did not hold (shaped copies $R_ALL, expected 20; oldest seed $( [ -e "$T/.git/ai-dlc-fixture-failures.20000101T000000Z.1" ] && echo kept || echo gone)) — retention grows without bound or deletes the wrong records"
fi

if [ "$(cat "$T/.git/ai-dlc-fixture-failures.clean" 2>/dev/null)" = OPERATOR-CLEAN ] \
   && [ "$(cat "$T/.git/ai-dlc-fixture-failures.179.1" 2>/dev/null)" = OPERATOR-179 ]; then
  ok "records an operator saved under their own names survive the prune byte-intact"
else
  bad "the prune took a hand-saved record (.clean or .179.1) — its pattern is wider than the shape the hook generates"
fi

[ "$(cat "$T/.git/ai-dlc-fixture-failures.20000101T000000Z.1.keep" 2>/dev/null)" = OPERATOR-KEEP ] \
  && ok "a retained copy kept under a non-numeric suffix (.keep) survives — the prune is anchored at the name's END too" \
  || bad "the prune took a stamp-prefixed hand-saved copy (.1.keep) — the pattern is anchored at the front only"

grep -q "retained copy of this run: .git/$R_NEW" "$WORK/retain.out" \
  && ok "the run names its retained copy, so the operator knows which file is this run's" \
  || bad "the red run never named its retained copy"
B_retain=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)

# ------------------------------- 2d. shared records are replaced by rename (BL-1046) --
# Read off the green and retain drives above, through the descriptors their worlds held open across
# the drive. Each cell must read `atomic`; the mutants below put one write back in place.
_f0=$fails
if [ "$BASE_at_green" = "$(printf 'rc=0\nat_dur=atomic\nat_last=atomic\nat_ver=atomic\nat_stall=atomic')" ]; then
  ok "a green run replaces the durations, .last, verified and stall records by rename: a reader holding each open still reads the old bytes whole"
else
  bad "a green run wrote a shared record in place or not at all: $(printf '%s' "$BASE_at_green" | tr '\n' ' ')"
fi
B_at_green=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)
_f0=$fails
if [ "$BASE_at_retain" = "$(printf 'rc=1\nrec=yes\ncopies=1\nat_fail=atomic')" ] && grep -q CSPTOKEN-stdout "$WORK/retain/.git/ai-dlc-fixture-failures"; then
  ok "a red run replaces the failure record by rename, and the record it leaves is this run's"
else
  bad "a red run wrote the failure record in place or lost it: $(printf '%s' "$BASE_at_retain" | tr '\n' ' ')"
fi
B_at_retain=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)

# ------------------------------- 2e. a held durations lock is honoured, never stolen ---
_f0=$fails
C_LOCK=""
cw_run lock "$WORK/lock" "$HOOK"
BASE_lock="$(csp_vec rc lockheld)"
if [ "$C_RC" = 0 ] && [ "$C_LOCK" = yes ]; then
  ok "a durations lock held by a live pid is honoured: the record is untouched, the run says so, and the lock is still the holder's"
else
  bad "a held durations lock was not honoured (rc=$C_RC, lockheld=$C_LOCK): $(grep 'durations record' "$WORK/lock.out" | head -1)"
fi
B_lock=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)
_f0=$fails
C_HOOK="$HOOK"
BASE_ls="$(csp_vec lsf lso)"
if [ "$BASE_ls" = "$(printf 'lsf=held\nlso=stale')" ]; then
  ok "an empty lock pid file reads HELD while its dir is fresh and STALE once the dir is older than 60s"
else
  bad "the lock judge misreads an empty pid file: $(printf '%s' "$BASE_ls" | tr '\n' ' ')"
fi
B_ls=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)

# ------------------------------------------------- 3. the empty-suite guard, twice --
# FORM 1: tests/fixtures exists and the glob matches no directory.
T="$WORK/empty1"; seed "$T" "$HOOK" || broken "seed failed"
rc="$(drive "$T" "$WORK/empty1.out")"
if [ "$rc" = 1 ] && grep -q 'no fixtures found' "$WORK/empty1.out"; then
  ok "an empty tests/fixtures/ FAILS the push (glob matches nothing)"
else
  bad "an empty tests/fixtures/ did not fail (rc=$rc) — an empty suite passes every assertion it never made"
fi

# FORM 2: directories exist, none carries a run.sh. This is the form the old loop
# returned 0 on with no output at all, and it is the likelier one in practice: a
# half-applied pull, or a fixture set whose drivers were never written.
_f0=$fails
cw_run empty "$WORK/empty2" "$HOOK"
rc="$C_RC"
BASE_empty="$(csp_vec rc nofix)"
if [ "$rc" = 1 ] && grep -q 'no fixtures found' "$WORK/empty2.out"; then
  ok "fixture directories with no run.sh FAIL the push (the form that returned 0)"
else
  bad "driverless fixture directories did not fail (rc=$rc) — a directory nothing drives read exactly like one that passed"
fi
B_empty=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)

# --------------------------------------------- 4. a dropped worker is a FAILURE ----
# The completeness assertion. Without it the report simply gets SHORTER, and a
# suite printing two greens where three were expected reads exactly like one that
# passed — the check-that-cannot-fire class one layer out.
_f0=$fails
cw_run drop "$WORK/drop" "$HOOK"
rc="$C_RC"
BASE_drop="$(csp_vec rc noverdict countline)"
if [ "$rc" = 1 ] && grep -q 'bravo  (no verdict recorded)' "$WORK/drop.out" \
                 && grep -q 'fixtures produced a verdict' "$WORK/drop.out"; then
  ok "a worker that dies before it records its verdict FAILS as a missing verdict"
else
  bad "a dropped worker did not fail (rc=$rc) — the pool lost a job and the suite reported a shorter green"
fi
B_drop=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)

# -------------------------------------------------- 5. the pool really is a pool ---
# Positive arm: through the shipping default the fixtures observe each other.
_f0=$fails
T="$WORK/pool"
cw_run pool "$T" "$HOOK"
rc="$C_RC"
BASE_pool="$(CSP_OBSERVE="$T/observe" csp_vec rc maxpar_ge2)"
max_par="$(sort -n "$T/observe/../seen" 2>/dev/null | tail -1)"
if [ "$rc" = 0 ] && [ "${max_par:-0}" -ge 2 ]; then
  ok "four fixtures ran concurrently (max observed in flight: ${max_par:-0})"
else
  bad "the suite did not run concurrently (rc=$rc, max in flight ${max_par:-0}) — the pool is the whole speed half"
fi
B_pool=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)

# CONTROL for that arm, and it is the one that makes the number above mean something.
# At AI_DLC_FIXTURE_JOBS=1 the SAME fixtures must observe exactly one in flight. If
# they reported 4 here too, the observation instrument would be measuring something
# other than concurrency and the arm above would be satisfied by any hook at all.
T="$WORK/serial"; seed "$T" "$HOOK" || broken "seed failed"
export CSP_OBSERVE="$T/observe" CSP_BARRIER_N=12; mkdir -p "$CSP_OBSERVE"
for n in alpha bravo charlie delta; do mkfx_observe "$T" "$n"; done
rc="$( cd "$T" && AI_DLC_FIXTURE_JOBS=1 AI_DLC_READSET_LIVE_TRACE=0 bash .githooks/pre-push </dev/null >"$WORK/serial.out" 2>&1; echo $? )"
max_ser="$(sort -n "$T/observe/../seen" 2>/dev/null | tail -1)"
if [ "$rc" = 0 ] && [ "${max_ser:-0}" = 1 ]; then
  ok "AI_DLC_FIXTURE_JOBS=1 runs them one at a time (max observed in flight: 1) — the knob is live and the observation is real"
else
  bad "the knob did not serialise (rc=$rc, max in flight ${max_ser:-0}) — either AI_DLC_FIXTURE_JOBS is not read, or the arm above is not measuring concurrency"
fi
unset CSP_OBSERVE CSP_BARRIER_N

# =================================================================== MUTANTS =======
# Each is a COPY of the hook with one arm removed, guarded by `cmp -s` so a sed that
# matched nothing cannot pass as a mutation. Each mutant is driven ONCE on the world its base arm
# drove, and scored on cells of that drive through matrix.sh: its DECIDING cells must move, its TWIN
# cells (green under the mutant in the measured matrix) must not, and the kill is emitted only
# through mutant_killed behind the base arm's same-run pass flag.
# THE GUARD SETS `MUT` RATHER THAN PRINTING THE PATH, and v0.229.0's knock-out battery
# is what forced that. Written as `M="$(mut ...)"` the helper ran inside a command
# SUBSTITUTION, so its `cmp -s` failure message went into `$M` instead of to the report
# and its `asserts` increment happened in a subshell that then exited. A mutation which
# matched nothing therefore said NOTHING: the arm silently did not run, and the only
# thing that noticed was the EXPECTED_ASSERTIONS floor reporting `20 of 21` with no clue
# which one. The guard existed, was correct, and could not speak — this repo's named
# class inside the guard written to prevent it, found by knocking out a mechanism this
# release added and watching the wrong arm report.
mut() {                        # mut <label> <sed-expr>  -> sets MUT, or returns 1
  local lbl="$1" expr="$2" m="$WORK/hook.$1"
  sed "$expr" "$HOOK" > "$m" || { bad "MUTANT $lbl: sed failed"; return 1; }
  if cmp -s "$HOOK" "$m"; then
    bad "MUTANT $lbl matched nothing (cmp -s guard) — this arm proves nothing"
    return 1
  fi
  MUT="$m"
}

# UNMUTATED CONTROL, and it runs FIRST: an UNMUTATED COPY of the hook, driven on the green world,
# must reproduce the base vector. If the harness itself were what fails, every mutant below would
# score a kill it had not earned.
cp "$HOOK" "$WORK/hook.control" || broken "cannot copy the hook for the unmutated control"
cw_run green "$WORK/mctl" "$WORK/hook.control"
if [ "$B_green" = 1 ] && [ "$(csp_vec rc rec)" = "$BASE_green" ] && grep -q 'ok    alpha' "$WORK/mctl.out"; then
  ok "mutant-battery control: an unmutated copy of the hook, driven on the green world, reproduces the base vector (rc 0, no record) and reports ok alpha"
else
  bad "mutant-battery control is RED (rc=$C_RC) — no mutant verdict below is believable"
fi

# M1 — the empty-suite guard removed. The driverless tree must go green.
# The range takes the WHOLE `if`, not just its body: deleting a conditional's body
# and leaving the `if`/`fi` produces a syntax error, and a mutant that cannot parse
# fails for a reason that has nothing to do with the arm under test.
if mut m1 '/if \[ "\$n_expected" -eq 0 \]/,+3d'; then
  cw_run empty "$WORK/m1" "$MUT"
  csp_score m1 "$([ "$B_empty" = 1 ] && echo 1 || echo 0)" "rc,nofix" "-" $'rc=0\nnofix=no' "rc,nofix" "$BASE_empty" \
    "M1 without the empty-suite guard a driverless tree PASSES and the message is gone — the guard is what fails it"
fi

# m2 — the completeness assertion removed. THIS IS A CONTROL, NOT A MUTANT: the dropped worker still
# FAILS, because the per-fixture line detects it first. Its surviving state is the point.
if mut m2 '/n_actual" -ne "\$n_expected/,+4d'; then
  cw_run drop "$WORK/m2" "$MUT"
  if [ "$B_drop" = 1 ] && [ "$C_RC" = 1 ] && [ "$(csp_cell noverdict)" = yes ] && [ "$(csp_cell countline)" = no ]; then
    ok "CONTROL m2 with the count assertion removed the dropped worker still FAILS at rc=1 and the per-fixture 'no verdict recorded' line is still present while the 'fixtures produced a verdict' count line is absent — the count is a magnitude statement and the per-fixture line is the second, independent detector"
  else
    bad "CONTROL m2 dropped-worker detection collapsed (rc=$C_RC, noverdict $(csp_cell noverdict), countline $(csp_cell countline)) — removing the count assertion should leave the per-fixture line"
  fi
fi

# M2b — the PER-FIXTURE arm removed, count assertion left in place. This mutant was
# written to show that cutting both arms lets a lost worker pass silently; that
# premise is FALSE and measuring it is worth more than the arm it replaced.
#
# WHAT THE MEASUREMENT SAYS. The report walks the LIST, not the directory of
# verdicts, so a fixture with no verdict file still reaches the reader; with the
# `[ ! -f ]` branch gone it falls through to an unreadable `cat`, whose empty result
# is not `ok`, and it is reported as a plain `FAIL bravo`. The push still blocks.
# Two consequences, and the second is a finding about the hook rather than about
# this fixture:
#
#   1. The per-fixture arm's contribution is ATTRIBUTION, not detection. Without it
#      a worker the pool lost is indistinguishable from a fixture that ran and
#      failed, which sends someone to debug a fixture that never executed.
#   2. `n_actual` is incremented on exactly the path that branch skips, so the COUNT
#      assertion can only fire when the per-fixture arm has already fired. It is a
#      magnitude statement, not an independent detector — and the hook's comment
#      claiming "the count is asserted rather than assumed" is corrected in both
#      hooks to say which of the two does the detecting.
if mut m2b '/if \[ ! -f "\$out\/\$b" \]/,+2d'; then
  cw_run drop "$WORK/m2b" "$MUT"
  csp_score m2b "$([ "$B_drop" = 1 ] && echo 1 || echo 0)" "noverdict,countline" "rc" $'rc=1\nnoverdict=no\ncountline=no' "rc,noverdict,countline" "$BASE_drop" \
    "M2b without the per-fixture arm a lost worker is MISREPORTED as a failing fixture and the count assertion stays silent — so the count cannot fire alone"
fi

# M3 — the pool removed. The concurrency observation must collapse to 1.
if mut m3 's|xargs -P "\$FIXTURE_JOBS"|xargs -P 1|'; then
  export CSP_BARRIER_N=12
  cw_run pool "$WORK/m3" "$MUT"
  unset CSP_BARRIER_N
  csp_score m3 "$([ "$B_pool" = 1 ] && echo 1 || echo 0)" "maxpar_ge2" "rc" $'maxpar_ge2=no' "rc,maxpar_ge2" "$BASE_pool" \
    "M3 with the pool width pinned to 1 the fixtures no longer overlap — the pool is what produces the overlap"
fi

# M4 — the failure record's SELECTOR removed, so every unit is written out whether it
# passed or not. The green-run control in arm 2b is an ABSENCE (`! grep GREENTOKEN`), and an
# absence passes against a hook that wrote no record at all — the same shape assertion 2's
# mutant exists for in `layer-debt-ledger`. This is the arm that makes that control mean
# "only red units are captured" rather than "something did not happen".
if mut m4 '/= ok \] && continue/d'; then
  cw_run green "$WORK/m4" "$MUT"
  csp_score m4 "$([ "$B_green" = 1 ] && echo 1 || echo 0)" "rec" "rc" $'rec=yes' "rc,rec" "$BASE_green" \
    "M4 without the verdict selector a GREEN unit is captured too — so the control is what proves only red units are"
fi

# RETENTION MUTANTS. Each drives the arm-2c world -- twenty seeds, two decoys, one red -- and
# is scored on the observable its own removal PRODUCES, never the absence of arm 2c's message.
#
# retain-off — the copy statement deleted. The primary record must still carry the token (so
# the run did go red and record) while no stamped copy appears.
if mut retain-off '/cp "\$fl_tmp" "\$fl_copy"/d'; then
  cw_run retain "$WORK/retain-off" "$MUT"
  csp_score retain-off "$([ "$B_retain" = 1 ] && echo 1 || echo 0)" "copies" "rec,shaped" $'copies=0' "rc,rec,copies,shaped,oldest,h179,keepc,cleanc,seed19" "$BASE_retain" \
    "retain-off without the copy a red run records only the overwritable primary — the copy statement is what retains"
fi

# retain-fixed-name — every run copies to ONE name, the overwrite this release exists to stop.
# The fixed name is a seed's, so the overwrite is visible as that seed's content changing.
if mut retain-fixed-name 's|fl_copy="\$GITDIR/ai-dlc-fixture-failures\.\$fl_stamp\.\$\$"|fl_copy="$GITDIR/ai-dlc-fixture-failures.20000101T000019Z.1"|'; then
  cw_run retain "$WORK/retain-fixed" "$MUT"
  csp_score retain-fixed-name "$([ "$B_retain" = 1 ] && echo 1 || echo 0)" "copies,seed19" "rec,h179" $'copies=0\nseed19=no' "rc,rec,copies,shaped,oldest,h179,keepc,cleanc,seed19" "$BASE_retain" \
    "retain-fixed-name with one fixed copy name the earlier record is OVERWRITTEN — the per-run stamp is what keeps both"
fi

# prune-off — the prune loop deleted whole (six lines, so the body still parses). Twenty-one
# shaped copies must remain, the oldest seed among them.
if mut prune-off '/^    for fl_f in "\$GITDIR"/,+5d'; then
  cw_run retain "$WORK/prune-off" "$MUT"
  csp_score prune-off "$([ "$B_retain" = 1 ] && echo 1 || echo 0)" "shaped,oldest" "copies,rec" $'shaped=21\noldest=yes' "rc,rec,copies,shaped,oldest,h179,keepc,cleanc,seed19" "$BASE_retain" \
    "prune-off without the prune the twenty-first copy is kept too — the prune is what bounds retention"
fi

# prune-glob-wide — the anchored pattern widened to `ai-dlc-fixture-failures.*`. Under name
# order the hand-saved `.179.1` sorts below every stamped copy and is the first thing a
# wide prune deletes; that deletion is this mutant's observable. `.clean` sorts above them and
# survives even here, which is why it cannot be the arm that kills this mutant.
if mut prune-glob-wide 's|ai-dlc-fixture-failures\.2\[0-9\]\[0-9\]\[0-9\]\[01\]\[0-9\]\*Z\.\*|ai-dlc-fixture-failures.*|'; then
  cw_run retain "$WORK/prune-wide" "$MUT"
  csp_score prune-glob-wide "$([ "$B_retain" = 1 ] && echo 1 || echo 0)" "h179" "cleanc,rec" $'h179=no' "rc,rec,copies,shaped,oldest,h179,keepc,cleanc,seed19" "$BASE_retain" \
    "prune-glob-wide with the pattern widened a hand-saved record is DELETED — the anchor is what protects it"
fi

# prune-suffix-unanchored — the end anchor (the all-digit last-field `case`) deleted. The
# `.1.keep` decoy then passes the glob, sorts between the two oldest seeds, and is pruned
# with the oldest one.
# `.179.1` still survives here, which is why it cannot be the arm that kills this mutant.
if mut prune-suffix-unanchored '/case "\${fl_f##\*\.}" in/d'; then
  cw_run retain "$WORK/prune-suffix" "$MUT"
  csp_score prune-suffix-unanchored "$([ "$B_retain" = 1 ] && echo 1 || echo 0)" "keepc" "h179,cleanc" $'keepc=no' "rc,rec,copies,shaped,oldest,h179,keepc,cleanc,seed19" "$BASE_retain" \
    "prune-suffix-unanchored without the end anchor a .keep copy is DELETED — the all-digit last field is what protects it"
fi

# RENAME AND LOCK MUTANTS (BL-1046), each scored on the world its base arm read.
# at-helper — rec_put copies over the record in place: every record it writes reads `inplace`. `.last` is
# its twin: the pool entry already renamed an empty file over it, so the held descriptor keeps the seed.
if mut at-helper 's|  cp "\$1" "\$2.tmp.\$\$" 2>/dev/null \&\& mv -f "\$2.tmp.\$\$" "\$2" 2>/dev/null \&\& return 0|  cp "$1" "$2" 2>/dev/null \&\& return 0|'; then
  cw_run green "$WORK/at-helper" "$MUT"
  csp_score at-helper "$([ "$B_at_green" = 1 ] && echo 1 || echo 0)" "at_dur,at_ver,at_stall" "at_last,rc" $'at_dur=inplace\nat_ver=inplace\nat_stall=inplace' "rc,at_dur,at_last,at_ver,at_stall" "$BASE_at_green" \
    "at-helper with rec_put copying in place a concurrent reader sees each record rewritten under it — the rename is what keeps the old bytes whole"
fi
# at-last-entry — the pool-entry truncation of `.last` done in place: the held descriptor is emptied.
if mut at-last-entry 's|  { : > "\$LASTRUN_RECORD.tmp.\$\$" && mv -f "\$LASTRUN_RECORD.tmp.\$\$" "\$LASTRUN_RECORD"; } 2>/dev/null|  : > "$LASTRUN_RECORD" 2>/dev/null|'; then
  cw_run green "$WORK/at-last-entry" "$MUT"
  csp_score at-last-entry "$([ "$B_at_green" = 1 ] && echo 1 || echo 0)" "at_last" "at_dur,rc" $'at_last=other' "rc,at_dur,at_last,at_ver,at_stall" "$BASE_at_green" \
    "at-last-entry with the entry truncation in place a reader holding .last sees it emptied — the rename is what prevents it"
fi
# at-dur — ONE site reverted: the durations merge copies over the record; the others still rename.
if mut at-dur 's|\[ -s "\$out/.merged" \] && rec_put "\$out/.merged" "\$DURATIONS_RECORD"|[ -s "$out/.merged" ] \&\& cp "$out/.merged" "$DURATIONS_RECORD"|'; then
  cw_run green "$WORK/at-dur" "$MUT"
  csp_score at-dur "$([ "$B_at_green" = 1 ] && echo 1 || echo 0)" "at_dur" "at_last,rc" $'at_dur=inplace' "rc,at_dur,at_last,at_ver,at_stall" "$BASE_at_green" \
    "at-dur with the merge copying in place the durations record is rewritten under its reader — that site's rename is what prevents it"
fi
# at-fail — the failure record written into the primary in place instead of renamed over it.
if mut at-fail 's|\[ "\$fl_wrote" = 1 \] && mv -f "\$fl_tmp" "\$FAILLOG_RECORD" 2>/dev/null|[ "$fl_wrote" = 1 ] \&\& cat "$fl_tmp" > "$FAILLOG_RECORD"|'; then
  cw_run retain "$WORK/at-fail" "$MUT"
  csp_score at-fail "$([ "$B_at_retain" = 1 ] && echo 1 || echo 0)" "at_fail" "rec,copies" $'at_fail=inplace' "rc,rec,copies,at_fail" "$BASE_at_retain" \
    "at-fail with the failure record written in place its reader sees it rewritten — the rename is what prevents it"
fi
# lock-off — the merge no longer takes the lock: the held lock is ignored and the record merged.
if mut lock-off 's|    if rec_lock "\$DURATIONS_RECORD.lock"; then|    if :; then|'; then
  C_LOCK=""
  cw_run lock "$WORK/lock-off" "$MUT"
  csp_score lock-off "$([ "$B_lock" = 1 ] && echo 1 || echo 0)" "lockheld" "rc" $'lockheld=no' "rc,lockheld" "$BASE_lock" \
    "lock-off without the lock a held durations record is merged over — the lock is what serializes the read-modify-write"
fi
# lock-empty-pid — the judge reads an empty pid file as malformed again: a fresh lock reads stale.
if mut lock-empty-pid 's|  if \[ -s "\$lk/pid" \]; then|  if [ -f "$lk/pid" ]; then|'; then
  C_HOOK="$MUT"
  csp_score lock-empty-pid "$([ "$B_ls" = 1 ] && echo 1 || echo 0)" "lsf" "lso" $'lsf=stale' "lsf,lso" "$BASE_ls" \
    "lock-empty-pid with an empty pid file read as malformed a live lock mid-write is judged stale and stolen — the size test is what holds it"
  C_HOOK="$HOOK"
fi

# ================================================ 7. NO-PROGRESS REFUSAL (BL-606) ===
# THE DEFECT. Every pool run site ran its unit unbounded, so one hung unit hung the push with
# nothing to say which. `pool_run` now refuses a unit that writes no new bytes -- to its pool log or
# under its per-unit watched root (the TMPDIR the pool sets) -- for POOL_STALL polls, kills its tree
# (every process and every group found in it) by recorded ids, and records REFUSED.
# Stubs, each moving through ONE channel so no mutant is covered by another channel:
#   (h)  a hang whose `sleep` is a grandchild: REFUSED, and no recorded member survives;
#   (p)  a polling loop (a fresh child pid each pass, no output) for 6 x POOL_STALL passes, then
#        exit 0: REFUSED -- new pids and a moving CPU clock are not progress;
#   (s)  writes one log line between every two consecutive watcher polls, for 4 x POOL_STALL polls,
#        CPU-free and fork-free: ok -- the LOG alone carries its progress;
#   (w)  silent, appends one byte between every two watcher polls to a `mktemp` file under TMPDIR, for 4 x POOL_STALL polls:
#        ok -- the WATCHED ROOT alone carries its progress (it exits 4, a FAIL, if the file lands
#        outside the root, so a root the pool did not set cannot pass);
#   (g)  a grandchild in its OWN group burns CPU every second, writing nothing: REFUSED, BY DESIGN --
#        silent computation is not progress, and this stub documents that;
#   (gh) a grandchild in its own group, idle: REFUSED, and the grandchild's group is gone;
#   (f)  exits 1: FAIL, never REFUSED.
# Every pid a stub starts is RECORDED by the stub, and checked and stopped by that pid only.
# THE VERDICT IS BINARY: REFUSED or not, alive or gone; nothing is judged on elapsed time.
# EVERY PACED WORLD RUNS IN LOCKSTEP WITH THE WATCHER'S OWN POLLS, never against the clock. A stub `sleep`
# earlier on PATH (see GBIN) recognises the watcher's `sleep 1` (its parent is the pool worker's `bash -c`,
# whose last argument names the unit) and holds poll k until the unit has made step k; the unit makes step
# k+1 only after poll k has been measured. So a unit that must show progress shows new bytes between every
# two consecutive polls, and a unit that must stand still shows none for exactly the polls the verdict
# needs, whatever the load: a starved writer stalls the watcher, a starved watcher stalls the writer.
# Polls per world: (s), (w), (t) 4 x POOL_STALL (12) completed polls then the unit exits; (r), (p), (g)
# REFUSED at poll POOL_STALL + 1 (4) -- the unit offers up to 4 x or 6 x POOL_STALL steps and is killed
# at the refusal; the orphan arms grant exactly POOL_STALL polls. (h), (gh), (f) are hangs or instant
# exits whose verdict cannot flip with scheduling, so their watchers keep the real `sleep 1`.
st_stub() {                    # st_stub <tree> <name> : writes the stub and its helper
  local t="$1" n="$2" d="$1/tests/fixtures/$2"
  mkdir -p "$d"
  case "$n" in
    h) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
echo $$ >> "$CSP_PIDS/h"
bash -c 'echo $$ >> "$1"; /bin/cat < "$CSP_FIFO" > /dev/null & echo $! >> "$1"; wait $!; :' _ "$CSP_PIDS/h"
FX
    ;;
    s) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
echo $$ >> "$CSP_PIDS/s"
. "$CSP_GLIB"; i=0
while [ $i -lt $((4 * CSP_STALL)) ]; do i=$((i + 1)); echo "line $i"; gstep s $i $((4 * CSP_STALL)); done
exit 0
FX
    ;;
    g|gh) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
n="$(basename "$(cd "$(dirname "$0")" && pwd)")"
echo $$ >> "$CSP_PIDS/$n"
ps -o pgid= -p $$ | tr -d ' ' > "$CSP_PIDS/$n.pgid.parent"
bash -c 'set -m; bash "$1" & echo $! >> "$2"; wait $!; :' _ "$(dirname "$0")/gc.sh" "$CSP_PIDS/$n"
exit 0
FX
      if [ "$n" = g ]; then cat > "$d/gc.sh" <<'FX'
ps -o pgid= -p $$ | tr -d ' ' > "$CSP_PIDS/g.pgid.gc"
. "$CSP_GLIB"; k=0
while [ $k -lt $((4 * CSP_STALL)) ]; do
  k=$((k + 1)); j=0; while [ $j -lt 20000 ]; do j=$((j + 1)); done
  gstep g $k $((4 * CSP_STALL))
done
FX
      else cat > "$d/gc.sh" <<'FX'
ps -o pgid= -p $$ | tr -d ' ' > "$CSP_PIDS/gh.pgid.gc"
/bin/cat < "$CSP_FIFO" > /dev/null & echo $! >> "$CSP_PIDS/gh"; wait $!
FX
      fi
    ;;
    f) printf '#!/usr/bin/env bash\necho $$ >> "$CSP_PIDS/f"\n. "$CSP_GLIB"; gpolls f\nexit 1\n' > "$d/run.sh" ;;
    p) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
echo $$ >> "$CSP_PIDS/p"
. "$CSP_GLIB"; i=0; kid=""
while [ $i -lt $((6 * CSP_STALL)) ]; do
  i=$((i + 1)); [ -z "$kid" ] || kill "$kid" 2>/dev/null
  /bin/cat < "$CSP_FIFO" > /dev/null & kid=$!; disown "$kid"   # disown: a reaped job prints "Terminated" to the log, which is progress
  gstep p $i $((6 * CSP_STALL))
done
[ -z "$kid" ] || kill "$kid" 2>/dev/null
exit 0
FX
    ;;
    w) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
echo $$ >> "$CSP_PIDS/w"
f="$(mktemp "${TMPDIR:-/tmp}/w.XXXXXX")" || exit 3
case "$f" in "$AI_DLC_FX_OUT"/.t.*/w.*) ;; *) echo "w: scratch landed outside the watched root: $f" >&2; exit 4 ;; esac
. "$CSP_GLIB"; i=0
while [ $i -lt $((4 * CSP_STALL)) ]; do i=$((i + 1)); printf x >> "$f"; gstep w $i $((4 * CSP_STALL)); done
exit 0
FX
    ;;
  esac
}
ST=3                           # AI_DLC_POOL_STALL for every drive in this section
# GBIN: the gated `sleep` and the lockstep library, built once. The stub passes everything but a
# watcher's `sleep 1` through to /bin/sleep. For a watcher whose unit has a gate directory it counts its
# own calls (k), marks poll k-1 measured (polled.<k-1>), and returns only once step k exists
# (written.<k>); a unit (or, for the orphan arms, the harness) marks a step by creating written.<i>.
# The waits are unbounded on their condition; the stub dies with the watcher's group, so none outlives its world.
GBIN="$WORK/gate-bin"; mkdir -p "$GBIN" || broken "cannot create the gate stub dir"
cat > "$GBIN/sleep" <<'FX'
#!/usr/bin/env bash
if [ "${1:-}" = 1 ] && [ -n "${CSP_GATE:-}" ]; then
  a="$(/bin/ps -ww -o command= -p "$PPID" 2>/dev/null)"
  case "$a" in "bash -c "*) a="${a% }"; u="${a##* }"; u="${u%/}"; u="${u##*/}" ;; *) u="" ;; esac
  d="$CSP_GATE/$u"
  if [ -n "$u" ] && [ -d "$d" ]; then
    k=0; [ -f "$d/k" ] && read -r k < "$d/k"
    k=$((k + 1)); echo "$k" > "$d/k"
    [ "$k" -gt 1 ] && : > "$d/polled.$((k - 1))"
    while [ ! -e "$d/written.$k" ]; do /bin/sleep 0.02; done
    exit 0
  fi
fi
exec /bin/sleep "$@"
FX
chmod +x "$GBIN/sleep"
cat > "$GBIN/lib.sh" <<'FX'
gwait() { while [ ! -e "$1" ]; do /bin/sleep 0.02; done; }
# gpolls <unit>: an INSTANT unit's lockstep. It grants watcher poll 1, then holds until the watcher has STARTED
# its second gated sleep, so the watcher's stub start count is exactly 2 whether the kill lands early or
# late; without it, whether the watcher reached a stub start before the kill followed the load.
gpolls() { local f="$CSP_GATE/$1" k=0; : > "$f/written.1"
  while :; do [ -f "$f/k" ] && read -r k < "$f/k"; [ "${k:-0}" -ge 2 ] && return 0; /bin/sleep 0.02; done; }
gstep() { : > "$CSP_GATE/$1/written.$2"; gwait "$CSP_GATE/$1/polled.$2"; }   # the LAST step waits too: the watcher then starts exactly n+1 gated sleeps, so the start count is fixed
FX
[ -x "$GBIN/sleep" ] && [ -s "$GBIN/lib.sh" ] || broken "the gate stub was not built"
export CSP_GLIB="$GBIN/lib.sh"
mkfx_g() {                     # mkfx_g <tree> <name> <exitcode> : mkfx, in lockstep with its own watcher (see gpolls)
  mkdir -p "$1/tests/fixtures/$2" "$1/gate/$2"
  printf '#!/usr/bin/env bash\n. "$CSP_GLIB"; gpolls %s\nexit %s\n' "$2" "$3" > "$1/tests/fixtures/$2/run.sh"
}
st_world() {                   # st_world <tree> <hook> <stubs...> : seed, export CSP_* for this world
  local t="$1" h="$2" n; shift 2
  seed "$t" "$h" || broken "seed failed"
  mkdir -p "$t/pids" "$t/gate"; mkfifo "$t/fifo" || broken "mkfifo failed"
  for n in "$@"; do st_stub "$t" "$n"; case "$n" in p|s|w|g|f) mkdir -p "$t/gate/$n" ;; esac; done
  export CSP_PIDS="$t/pids" CSP_FIFO="$t/fifo" CSP_STALL="$ST" CSP_GATE="$t/gate"
}
st_drive() {                   # st_drive <tree> <outfile> -> rc
  ( cd "$1" && PATH="$GBIN:$PATH" AI_DLC_POOL_STALL="$ST" AI_DLC_READSET_LIVE_TRACE=0 bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}
# st_alive <tree> <stub>: count the stub's RECORDED pids still alive, and kill each by that pid.
st_alive() {
  local n=0 p f="$1/pids/$2"
  [ -s "$f" ] || { echo none; return; }
  while read -r p; do
    case "$p" in ''|*[!0-9]*) continue ;; esac
    if kill -0 "$p" 2>/dev/null; then n=$((n + 1)); kill -KILL "$p" 2>/dev/null; fi
  done < "$f"
  echo "$n"
}
st_refused() { grep -q "REFUSED  $2  (no progress for $ST polls; a refusal costs a re-run, never a verdict)" "$1"; }

_fs=$fails
T="$WORK/stall"; st_world "$T" "$HOOK" h p s w g gh f
rc="$(st_drive "$T" "$WORK/stall.out")"
# SEED VALIDITY FIRST: (gh)'s grandchild must really sit in another group, or the kill arm below
# would pass against a walk that never leaves the leader's group.
g_pp="$(cat "$T/pids/gh.pgid.parent" 2>/dev/null)"; g_gc="$(cat "$T/pids/gh.pgid.gc" 2>/dev/null)"
[ -n "$g_pp" ] && [ -n "$g_gc" ] && [ "$g_pp" != "$g_gc" ] \
  || broken "stub (gh)'s grandchild did not lead its own process group (parent $g_pp, grandchild $g_gc) -- the cross-group kill arm would read a world nobody built"
h_live="$(st_alive "$T" h)"; gh_live="$(st_alive "$T" gh)"; p_live="$(st_alive "$T" p)"; g_live="$(st_alive "$T" g)"
if st_refused "$WORK/stall.out" h && [ "$h_live" = 0 ]; then
  ok "(h) a hung unit is REFUSED and every member of its tree it recorded, the grandchild sleep included, is gone"
else
  bad "(h) a hung unit was not refused with its whole tree reaped (rc=$rc, live recorded members $h_live): $(grep ' h' "$WORK/stall.out" | tr '\n' ' ')"
fi
if st_refused "$WORK/stall.out" p && [ "$p_live" = 0 ]; then
  ok "(p) a polling loop that writes nothing is REFUSED -- fresh pids and CPU ticks are not progress"
else
  bad "(p) a polling loop was not refused (live recorded members $p_live): $(grep ' p' "$WORK/stall.out" | tr '\n' ' ')"
fi
if grep -q '^   ok    s$' "$WORK/stall.out"; then
  ok "(s) a unit that writes its log for 4x POOL_STALL polls is ok, not refused -- the log is part of the signature"
else
  bad "(s) a slow unit whose only progress is its log was not ok: $(grep ' s' "$WORK/stall.out" | tr '\n' ' ')"
fi
if grep -q '^   ok    w$' "$WORK/stall.out"; then
  ok "(w) a silent unit writing only under its TMPDIR is ok -- the watched root is part of the signature"
else
  bad "(w) a unit whose only progress is under its watched root was not ok: $(grep ' w' "$WORK/stall.out" | tr '\n' ' ')"
fi
if st_refused "$WORK/stall.out" g && [ "$g_live" = 0 ]; then
  ok "(g) silent computation in a cross-group grandchild is REFUSED, by design, and its tree is reaped"
else
  bad "(g) a silent CPU-only unit was not refused and reaped (live recorded members $g_live)"
fi
if st_refused "$WORK/stall.out" gh && [ "$gh_live" = 0 ]; then
  ok "(gh) an idle cross-group grandchild is REFUSED and its group is reaped"
else
  bad "(gh) a hung cross-group grandchild was not refused and reaped (live recorded members $gh_live)"
fi
if [ "$rc" = 1 ] && grep -q '^   FAIL  f$' "$WORK/stall.out" && ! st_refused "$WORK/stall.out" f; then
  ok "(f) a unit that exits 1 is FAIL, not REFUSED, and a real FAIL beside a refusal exits 1"
else
  bad "(f) exit 1 did not read FAIL with the push at 1 (rc=$rc)"
fi

# THE EXIT-2 CARRIER: a refusal alone exits 2, never 1 and never 0.
T="$WORK/stall2"; st_world "$T" "$HOOK" h
mkfx_g "$T" alpha 0
rc="$(st_drive "$T" "$WORK/stall2.out")"
h2_live="$(st_alive "$T" h)"
if [ "$rc" = 2 ] && st_refused "$WORK/stall2.out" h && grep -q '^   ok    alpha$' "$WORK/stall2.out" && [ "$h2_live" = 0 ]; then
  ok "a refusal with no FAIL beside it exits 2: the absence of a verdict, not a red verdict"
else
  bad "a lone refusal did not exit 2 (rc=$rc, live recorded members $h2_live)"
fi

# THE STALL DRIVE'S BASE VECTOR, read off the drives above in THIS run: every stall mutant is scored
# against these values, never against constants. `alpha` is a plain green unit each mutant world
# also carries; it is the twin cell that stays at `ok` under every stall mutant.
B_stall=$([ "$fails" = "$_fs" ] && echo 1 || echo 0)
S2_RC="$rc"
stv() { awk -v u="$2" '$1 ~ /^(ok|FAIL|REFUSED)$/ && $2 == u { print $1; f = 1; exit } END { if (!f) print "none" }' "$1"; }
BASE_stall="v_h=$(stv "$WORK/stall.out" h)
v_p=$(stv "$WORK/stall.out" p)
v_s=$(stv "$WORK/stall.out" s)
v_w=$(stv "$WORK/stall.out" w)
v_gh=$(stv "$WORK/stall.out" gh)
v_alpha=$(stv "$WORK/stall2.out" alpha)
rc=$S2_RC
live_h=$h_live
live_gh=$gh_live"
st_mrun() {                    # st_mrun <tag> <hook> <stubs...> : the stub world plus a green alpha, driven once
  local t="$WORK/$1" h="$2"; shift 2
  st_world "$t" "$h" "$@"
  mkfx_g "$t" alpha 0
  csp_load "$t" "$(st_drive "$t" "$t.out")" "$t.out"
  # UNCONDITIONAL REAP, and the live counts the st-c / st-d cells read. st_alive counts each recorded
  # pid still alive and SIGKILLs it, so no matrix or per-push path can leave a stub's tree running.
  # Before this line the helper never reaped: st-c leaves (h)'s grandchild sleep alive by design and
  # it outlived the run; and C_LH / C_LGH stayed empty, which differs from the base "0" for ANY
  # mutant and so made the live_h / live_gh trips vacuous.
  C_LH="$(st_alive "$t" h)"; C_LGH="$(st_alive "$t" gh)"
}

# MUTANTS of the refusal, each a copy of the RESOLVED hook, applied by exact-string replacement and
# guarded by `cmp -s`; each is driven once on its own stub world and scored on that drive's cells.
mutx() {                       # mutx <label> <old> <new> [<source>] -> sets MUT, or returns 1
  local m="$WORK/hook.$1" src="${4:-$HOOK}"
  OLD="$2" NEW="$3" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print } END { if (n != 1) exit 3 }' "$src" > "$m.t" \
    || { bad "MUTANT $1 did not apply (its anchor is not unique in $src)"; return 1; }
  cmp -s "$src" "$m.t" && { bad "MUTANT $1 matched nothing (cmp -s guard)"; return 1; }
  mv "$m.t" "$m"; MUT="$m"
}
# st-a: the signature omits the log, so (s), whose only progress is its log, is refused.
if mutx st-a 'cur="$(find "$wr" "$lg" ${wx:+"$wx"} ${1+"$@"} -type f -ls' 'cur="$(find "$wr" ${wx:+"$wx"} ${1+"$@"} -type f -ls'; then
  st_mrun st-a "$MUT" s
  csp_score st-a "$([ "$B_stall" = 1 ] && echo 1 || echo 0)" "v_s" "v_alpha" $'v_s=REFUSED' "v_s,v_alpha" "$BASE_stall" \
    "st-a without the log in the signature a log-only unit is REFUSED -- the log is what keeps (s) alive"
fi
# st-w: the signature ignores the watched root, so (w), whose only progress is under it, is refused.
if mutx st-w 'cur="$(find "$wr" "$lg" ${wx:+"$wx"} ${1+"$@"} -type f -ls' 'cur="$(find "$lg" ${wx:+"$wx"} ${1+"$@"} -type f -ls'; then
  st_mrun st-w "$MUT" w
  csp_score st-w "$([ "$B_stall" = 1 ] && echo 1 || echo 0)" "v_w" "v_alpha" $'v_w=REFUSED' "v_w,v_alpha" "$BASE_stall" \
    "st-w without the watched root in the signature a scratch-only unit is REFUSED -- the root is what keeps (w) alive"
fi
# st-cpu: the signature counts the tree's CPU and membership again, so (p) is never still and runs
# to its own exit 0 -- ok, not refused.
if mutx st-cpu '          if [ "$cur" = "$sg" ]; then still=$((still + 1)); else still=0; sg="$cur"; fi' '          cur="$cur;$wsig"; if [ "$cur" = "$sg" ]; then still=$((still + 1)); else still=0; sg="$cur"; fi'; then
  st_mrun st-cpu "$MUT" p
  csp_score st-cpu "$([ "$B_stall" = 1 ] && echo 1 || echo 0)" "v_p" "v_alpha" $'v_p=ok' "v_p,v_alpha" "$BASE_stall" \
    "st-cpu with CPU and membership back in the signature a polling loop is never refused -- bytes alone are what refuse (p)"
fi
# st-b: the refusal writes FAIL, so (h) reads FAIL and the push exits 1, not 2.
if mutx st-b 'printf REFUSED > "$AI_DLC_FX_OUT/$b"' 'printf FAIL > "$AI_DLC_FX_OUT/$b"'; then
  st_mrun st-b "$MUT" h
  csp_score st-b "$([ "$B_stall" = 1 ] && echo 1 || echo 0)" "v_h,rc" "v_alpha" $'v_h=FAIL\nrc=1' "v_h,v_alpha,rc" "$BASE_stall" \
    "st-b a refusal written as FAIL reads as a red verdict at exit 1 -- the REFUSED record is what keeps it out of the verdicts"
fi
# st-c: the kill covers the leader pid only (both the tree kill and the unit's own group kill go), so
# (h)'s grandchild sleep survives. Two anchors on two lines, each guarded.
if mutx st-c1 '            pool_kill "$pid" "$self" "$kp" "$kg"' '            kill -KILL "$pid"' \
   && mutx st-c '            kill -KILL -- "-$pid" 2>/dev/null' '            :' "$MUT"; then
  st_mrun st-c "$MUT" h
  csp_score st-c "$([ "$B_stall" = 1 ] && echo 1 || echo 0)" "live_h" "v_h,v_alpha" "" "v_h,v_alpha,live_h" "$BASE_stall" \
    "st-c killing the leader pid alone leaves recorded member(s) of (h)'s tree alive -- the tree kill is what reaps them"
fi
# st-d: the walk stays in the leader's group, so (gh)'s grandchild, in a group of its own, is never
# reached by the kill and survives the refusal.
if mutx st-d '} else if ((pp[i] in T) || (pg[i] in G)) { T[pid[i]] = 1; c = 1 }' '} else if (pg[i] == root) { T[pid[i]] = 1; c = 1 }'; then
  st_mrun st-d "$MUT" gh
  csp_score st-d "$([ "$B_stall" = 1 ] && echo 1 || echo 0)" "live_gh" "v_gh,v_alpha" $'v_gh=REFUSED' "v_gh,v_alpha,live_gh" "$BASE_stall" \
    "st-d a walk confined to the leader's group leaves (gh)'s cross-group grandchild alive -- the cross-group walk is what reaps it"
fi

# THE WATCHER DIES WITH ITS WORKER. The hook's worker body is extracted and run as a lone worker over
# one hanging stub; the worker is then SIGKILLed by its recorded pid. The watcher pid the worker recorded
# (`.pr/<unit>.w`) must be gone within POOL_STALL polls, and so must every pid the stub recorded: a
# watcher whose only exit was a refusal outlived its worker with ppid 1.
# csp_state <pid>: sets CSP_ST to `gone`, `settled` or `moving`, read off kernel state alone, never off elapsed time.
#   gone     kill -0 fails, or the pid is a zombie (state Z): it has exited, and only its reaping is outstanding.
#   settled  alive and BLOCKED or STOPPED (state S, I or T): nothing it does will change whether it is alive.
#   moving   anything else (R, U). The pid is then sent SIGSTOP, so the next read settles it: a live process that
#            nobody signalled stops and reads T, a SURVIVOR; a pid already sent SIGKILL (or a default-action
#            SIGTERM) exits instead, because the kernel delivers the lower-numbered pending signal first.
# Every recorded pid at a settle point was either awaited by its parent or SIGKILLed by this fixture, so the
# states that remain are dying (R, then gone or Z) or leaked; a leaked busy loop STOPs and is named, never waited on.
# The `ps -o pending=` field is not used: on macOS it reads 0 even for a stopped process holding a caught signal
# and for one that blocked a signal it was then sent, so it cannot see a pending signal at all.
csp_state() {
  local _cs
  CSP_ST=gone
  kill -0 "$1" 2>/dev/null || return 0
  _cs="$(ps -o stat= -p "$1" 2>/dev/null)"; _cs="${_cs// /}"
  if [ -z "$_cs" ]; then
    kill -0 "$1" 2>/dev/null || return 0
    broken "csp_state: ps gives no state for live pid $1, so whether it will end cannot be read"
  fi
  case "$_cs" in
    Z*) CSP_ST=gone ;;
    S*|I*|T*) CSP_ST=settled ;;
    *) CSP_ST=moving; kill -STOP "$1" 2>/dev/null ;;
  esac
}
# csp_own <pid>: sets CSP_OWN to `gone`, `ours` or `reused`, BEFORE anything signals the pid. A recorded pid is free
# for reuse once its process is reaped, and a reused pid reads `S` like a leaked one. Every world runs with its cwd
# in its tree under $WORK, and a forked child holds that cwd from the instant it exists, before it execs; no other
# process stands under this run's mktemp dir. So a live pid whose cwd is under $WORK is this fixture's, and one whose
# cwd is elsewhere is a reused pid, which is the recorded process gone. A live pid whose cwd cannot be read is a
# refusal (exit 2), never a FAIL.
csp_own() {
  local _co="" _l
  CSP_OWN=gone
  kill -0 "$1" 2>/dev/null || return 0
  while IFS= read -r _l; do case "$_l" in n*) _co="${_l#n}" ;; esac; done <<<"$(lsof -a -p "$1" -d cwd -Fn 2>/dev/null)"
  case "$_co" in
    "$WORK_P"|"$WORK_P"/*) CSP_OWN=ours ;;
    '') kill -0 "$1" 2>/dev/null || return 0
        # No cwd: a process mid-exit has dropped it. Only a SETTLED one with no cwd is unreadable; any other state
        # goes to csp_state, whose STOP a SIGKILLed pid never obeys, so it reads gone on the next pass.
        _l="$(ps -o stat= -p "$1" 2>/dev/null)"; _l="${_l// /}"
        case "$_l" in
          Z*) return 0 ;;
          S*|I*|T*) broken "csp_own: lsof gives no cwd for live settled pid $1, so whether it is this fixture's process cannot be read" ;;
          *) CSP_OWN=ours ;;
        esac ;;
    *) CSP_OWN=reused ;;
  esac
}
st_orphan() {                  # st_orphan <hook> <tag> [<stub-dir> [alive]] -> prints "<watcher-left> <unit-left>" or BROKEN
  local h="$1" R="$WORK/orph.$2" SB="${3:-}" AL="${4:-}" WK WP n p ul=0
  mkdir -p "$R/t/tests/fixtures/u" "$R/out/.log" "$R/out/.dur" "$R/out/.pr" "$R/gate/u"
  awk '/xargs -P "\$FIXTURE_JOBS" -I\{\} bash -c /{f=1;next} /^  . _ \{\} < "\$out\/.order"$/{f=0} f' "$h" > "$R/body.sh"
  awk '/^POOL_WALK=/{f=1} f{print} f && /^}.$/{exit}' "$h" > "$R/walk.sh"
  POOL_WALK=""; . "$R/walk.sh"
  [ -s "$R/body.sh" ] && [ -n "$POOL_WALK" ] || { echo BROKEN; return; }
  # The unit's hang is `/bin/sleep`, not the gated `sleep` on PATH: the gate stub is a bash script, so a bare `sleep 100000`
  # was one counted start per arm, started or not depending on how far the unit got before the watcher's kill landed.
  mkfifo "$R/fifo" || broken "mkfifo failed"
  printf 'echo $$ >> "%s/pids"\n/bin/cat < "%s/fifo" > /dev/null & echo $! >> "%s/pids"; wait $!\n' "$R" "$R" "$R" > "$R/t/tests/fixtures/u/run.sh"
  ( cd "$R/t" && PATH="$GBIN:${SB:+$SB:}$PATH" CSP_GATE="$R/gate" AI_DLC_FX_OUT="$R/out" AI_DLC_FX_TRACE="" AI_DLC_FX_TRACE_LIST="" AI_DLC_FX_DV="" \
     POOL_STALL=300 POOL_WALK="$POOL_WALK" exec bash -c "$(cat "$R/body.sh")" _ tests/fixtures/u/ ) >/dev/null 2>&1 &
  WK=$!
  while [ ! -s "$R/out/.pr/u.w" ] && kill -0 "$WK" 2>/dev/null; do sleep 0.1; done
  WP="$(cat "$R/out/.pr/u.w" 2>/dev/null)"
  case "$WP" in ''|*[!0-9]*) kill -KILL "$WK" 2>/dev/null; wait "$WK" 2>/dev/null
    [ -s "$R/pids" ] && while read -r p; do kill -KILL "$p" 2>/dev/null; done < "$R/pids"
    echo BROKEN; return ;; esac
  kill -0 "$WP" 2>/dev/null || { echo BROKEN; return; }
  # The unit has recorded its own pid AND its sleep child before the worker is killed, or a survivor arm
  # would count a child that was never started (a condition, not a delay).
  while [ "$(wc -l < "$R/pids" 2>/dev/null | tr -d ' ')" != 2 ] && kill -0 "$WK" 2>/dev/null; do sleep 0.1; done
  [ "$(wc -l < "$R/pids" 2>/dev/null | tr -d ' ')" = 2 ] || { kill -KILL "$WK" 2>/dev/null; echo BROKEN; return; }
  kill -KILL "$WK" 2>/dev/null; wait "$WK" 2>/dev/null
  # The watcher's polls are GRANTED one at a time, exactly POOL_STALL of them, and each grant waits on the
  # CONDITION (that poll measured, or the watcher gone) -- never on elapsed seconds.
  n=0; while kill -0 "$WP" 2>/dev/null && [ "$n" -lt "$ST" ]; do
    n=$((n + 1)); : > "$R/gate/u/written.$n"
    while kill -0 "$WP" 2>/dev/null && [ ! -e "$R/gate/u/polled.$n" ]; do sleep 0.02; done
  done
  local wl=0; if kill -0 "$WP" 2>/dev/null; then wl=1; kill -KILL -- "-$WP" 2>/dev/null; fi
  # A pid SIGKILLed a moment ago can still answer `kill -0` until it is reaped, so the count blocks on the CONDITION:
  # every recorded pid gone, or every one not gone csp_state `settled`. An arm asserting a SURVIVOR (the `alive`
  # argument: st-e, st-g) reaches that at once, its survivor being a blocked `/bin/cat`; a busy survivor is STOPped
  # by csp_state and counted, so no state of the unit's tree can hold this loop open.
  while :; do
    ul=0; set_=1
    while read -r p; do csp_state "$p"; [ "$CSP_ST" = gone ] && continue; ul=$((ul + 1)); [ "$CSP_ST" = settled ] || set_=0; done < "$R/pids"
    [ "$ul" -eq 0 ] && break
    [ "$set_" = 1 ] && break
    sleep 0.1
  done
  ul=0; while read -r p; do csp_state "$p"; [ "$CSP_ST" = gone ] || { ul=$((ul + 1)); kill -KILL "$p" 2>/dev/null; }; done < "$R/pids"
  # A STUBBED drive must prove the stub refused the worker's own `-p` lookup, or `self` was never empty.
  [ -z "$SB" ] || [ -s "$SB/refused" ] || { echo BROKEN; return; }
  echo "$wl $ul"
}

orph_m() {                     # orph_m <tag> <hook> [<stub-dir> [alive]] -> loads C_WL C_UL, or refuses a BROKEN extraction
  local o
  o="$(st_orphan "$2" "$1" "${3-}" "${4-}")"
  case "$o" in BROKEN|"") bad "MUTANT $1: the extracted worker did not run ($o) -- no verdict below is believable"; return 1 ;; esac
  read -r C_WL C_UL <<<"$o"
}
_f0=$fails
o="$(st_orphan "$HOOK" fix)"
case "$o" in
  BROKEN) bad "orphan arm: the extracted worker recorded no live watcher pid -- the arm cannot read its subject" ;;
  "0 0") ok "a SIGKILLed worker's watcher exits within POOL_STALL polls and takes the unit's tree with it" ;;
  *) bad "a SIGKILLed worker left its watcher or unit alive (watcher-left unit-left: $o)" ;;
esac
B_orph=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)
BASE_orph="wl=${o%% *}
ul=${o##* }"
# st-e: the watcher's worker-liveness check removed, so it outlives the worker.
if mutx st-e '          if ! kill -0 "$$"; then pool_kill "$pid" "$self" "$kp" "$kg"; exit 0; fi' '          :' && orph_m st-e "$MUT" "" alive; then
  csp_score st-e "$([ "$B_orph" = 1 ] && echo 1 || echo 0)" "wl,ul" "-" $'wl=1' "wl,ul" "$BASE_orph" \
    "st-e without the worker-liveness check the watcher outlives its SIGKILLed worker -- the check is what ends it"
fi
# THE EMPTY-SELF PATH KILLS THE UNIT'S GROUP TOO (BL-677). A stub `ps` that FAILS on `-p` (and records that
# it did) leaves the worker's `self` empty, so the watcher's worker-death `pool_kill` takes its guard path,
# pool_kill_tree, which walks the unit's tree ps-free (`pgrep -P`) and KILLs each listed pid's group and each
# pid. The unit leads its own group and its `/bin/cat` child is in it, so the child dies only if the guard
# reaches past the recorded pid. Every other `ps` call (the walk's `-A`) passes through to the real binary,
# resolved here before the stub dir is on PATH.
SP="$WORK/ps-stub"; mkdir -p "$SP"
PS_REAL="$(command -v ps)" || broken "no ps on PATH to wrap"
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = -p ] && { printf "%%s\\n" "$*" >> "%s/refused"; exit 1; }; done\nexec "%s" "$@"\n' "$SP" "$PS_REAL" > "$SP/ps"
chmod +x "$SP/ps"
_f0=$fails
o="$(st_orphan "$HOOK" eself "$SP")"
case "$o" in
  BROKEN) bad "empty-self arm: the stubbed worker recorded no watcher, or the stub never refused a -p lookup -- self was not shown empty" ;;
  "0 0") ok "with self empty (ps fails on -p) a SIGKILLed worker's watcher still kills the unit's whole tree, its child included" ;;
  *) bad "with self empty a SIGKILLed worker left its watcher or a unit group member alive (watcher-left unit-left: $o)" ;;
esac
B_eself=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)
BASE_eself="wl=${o%% *}
ul=${o##* }"
# st-g: the empty-self guard kills the recorded pid alone instead of walking its tree (pool_kill_tree), so the
# unit's child survives the worker's death.
if mutx st-g '[ -n "$2" ] || { pool_kill_tree "$1" "$3" "$4"; return 0; }' '[ -n "$2" ] || { kill -KILL "$1"; return 0; }'; then
  : > "$SP/refused"
  if orph_m st-g "$MUT" "$SP" alive; then
    csp_score st-g "$([ "$B_eself" = 1 ] && echo 1 || echo 0)" "ul" "wl" "" "wl,ul" "$BASE_eself" \
      "st-g without the tree kill on the empty-self path the unit's child outlives the worker -- the tree kill is what reaps it"
  fi
fi

# THE IN-POOL TRACE SITE WATCHES THE TRACED FIXTURE'S OWN OUTPUT, AND NOT THE STREAM CAPTURE BESIDE IT.
# There the unit is the deriver, which writes the fixture's output to `$WORK/<fx>.log` under the trace root
# (outside the watched root; the pool log gets only say-lines) and its `log stream` capture to
# `$WORK/<fx>.raw` in the same dir. The extracted worker runs one traced unit through a STUB deriver:
#   (t)  only `<root>/w/u.log` grows, one line a second for 4 x POOL_STALL polls, then rc 0: ok;
#   (r)  only `<root>/w/u.raw` grows the same way: REFUSED -- stream reports are not the fixture's progress.
# SEED VALIDITY: the stub's layout is the real deriver's, read off the deriver itself, or the arm would
# pass against a path no deriver writes.
# Both layouts, named: core/fixtures/<fx> -> core/scripts/ (distribution); tests/fixtures/<fx> ->
# scripts/ai-dlc/ (consumer, per core-paths.sh --map), beside the runner the walked-up root's layout named above.
DV="${HR_SRC%/*}/derive-fixture-readsets.sh"
[ -f "$DV" ] || broken "cannot locate derive-fixture-readsets.sh in either layout from $HERE -- the trace-site arm would stub a layout nobody checked"
# The redirect is read off the SANDBOX writer line, the only one the in-pool trace site runs (--tracer sandbox).
# A file-wide grep is also satisfied by the fs_usage writer's identical redirect, so moving only the sandbox
# line's log path would leave this check green while the hook watched a file nobody writes.
DV_SB="$(grep -F '&& sandboxed env ' "$DV")" || DV_SB=""
grep -qxF 'WORK="$TRACE_ROOT/w"' "$DV" && grep -qF '>"$WORK/$fx.log" 2>&1 </dev/null' <<<"$DV_SB" && grep -qxF '  raw="$WORK/$fx.raw"' "$DV" \
  || broken "the deriver's sandbox writer no longer sends the fixture's output to \$TRACE_ROOT/w/<fx>.log beside <fx>.raw -- the hook's trace-site watch path and this arm's stub are both stale"
st_trace() {                   # st_trace <hook> <tag> <t|r> -> prints the unit's verdict, or BROKEN
  local h="$1" R="$WORK/trace.$2" p
  mkdir -p "$R/t/tests/fixtures/u" "$R/out/.log" "$R/out/.dur" "$R/out/.pr" "$R/out/.lt" "$R/tmp" "$R/gate/u"
  awk '/xargs -P "\$FIXTURE_JOBS" -I\{\} bash -c /{f=1;next} /^  . _ \{\} < "\$out\/.order"$/{f=0} f' "$h" > "$R/body.sh"
  awk '/^POOL_WALK=/{f=1} f{print} f && /^}.$/{exit}' "$h" > "$R/walk.sh"
  POOL_WALK=""; . "$R/walk.sh"
  [ -s "$R/body.sh" ] && [ -n "$POOL_WALK" ] || { echo BROKEN; return; }
  printf '#!/usr/bin/env bash\nexit 0\n' > "$R/t/tests/fixtures/u/run.sh"
  cat > "$R/dv.sh" <<'FX'
while [ $# -gt 0 ]; do case "$1" in --in-pool) ip="$2"; shift ;; esac; shift; done
echo $$ >> "$CSP_TR_PIDS"
mkdir -p "$ip" "$AI_DLC_READSET_TRACE_ROOT/w"; W="$(cd "$AI_DLC_READSET_TRACE_ROOT/w" && pwd -P)"
case "$CSP_TR_KIND" in t) f="$W/u.log" ;; *) f="$W/u.raw" ;; esac
. "$CSP_GLIB"; i=0
while [ $i -lt $((4 * CSP_STALL)) ]; do i=$((i + 1)); echo "line $i" >> "$f"; gstep u $i $((4 * CSP_STALL)); done
: >> "$W/u.log"; cp "$W/u.log" "$ip/log"; echo 0 > "$ip/rc"
FX
  ( cd "$R/t" && PATH="$GBIN:$PATH" CSP_GATE="$R/gate" TMPDIR="$R/tmp" CSP_TR_PIDS="$R/pids" CSP_TR_KIND="$3" CSP_STALL="$ST" \
     AI_DLC_FX_OUT="$R/out" AI_DLC_FX_TRACE="$R/tmp/trace" AI_DLC_FX_TRACE_LIST="u" AI_DLC_FX_DV="$R/dv.sh" \
     POOL_STALL="$ST" POOL_WALK="$POOL_WALK" bash -c "$(cat "$R/body.sh")" _ tests/fixtures/u/ ) >/dev/null 2>&1
  [ -s "$R/pids" ] && while read -r p; do kill -KILL "$p" 2>/dev/null; done < "$R/pids"
  [ -s "$R/pids" ] || { echo BROKEN; return; }
  cat "$R/out/u" 2>/dev/null || echo none
}
_f0=$fails
v_t="$(st_trace "$HOOK" t t)"
[ "$v_t" = ok ] && ok "(t) a traced unit whose only progress is the fixture's output under the trace root is ok, not refused" \
              || bad "(t) a traced unit progressing only through its output was not ok (verdict $v_t)"
v_r="$(st_trace "$HOOK" r r)"
[ "$v_r" = REFUSED ] && ok "(r) a traced unit whose only growth is the stream capture (.raw) is REFUSED -- stream reports are not progress" \
                   || bad "(r) a traced unit growing only its .raw was not refused (verdict $v_r) -- a hung traced unit would never be refused"
B_trace=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)
BASE_trace="tv=$v_t
rv=$v_r"
# st-x: the trace site does not watch the fixture's output, so (t) is REFUSED -- the defect itself.
if mutx st-x '; wx="$tr/w/$b.log"' ''; then
  C_HOOK="$MUT"; C_TAG=st-x
  csp_score st-x "$([ "$B_trace" = 1 ] && echo 1 || echo 0)" "tv" "rv" $'tv=REFUSED' "tv,rv" "$BASE_trace" \
    "st-x without the fixture's output watched a traced output-only unit is REFUSED -- the watch is what keeps (t) alive"
fi
# st-r: the watch widened to the whole work dir takes in the .raw, so (r) is never refused.
if mutx st-r 'wx="$tr/w/$b.log"' 'wx="$tr/w"'; then
  C_HOOK="$MUT"; C_TAG=st-r
  csp_score st-r "$([ "$B_trace" = 1 ] && echo 1 || echo 0)" "rv" "tv" $'rv=ok' "tv,rv" "$BASE_trace" \
    "st-r with the whole work dir watched a .raw-only unit is never refused -- watching the .log alone is what refuses (r)"
fi
unset CSP_PIDS CSP_FIFO CSP_STALL CSP_GATE CSP_GLIB

# ------------- 7b. a fixture skipped on a recorded pass keeps its PENDING count in sight (BL-998) --
# Arm 7 reads the count off a DISPATCHED fixture's log. From the second push on `pend` is skipped on a recorded
# pass and its log is never read, so the count has to travel with the pass record: line 4 `#pending <n>` of its key
# record (the hook writes it) and the last line of its store entry (hermetic-run.sh writes it). This world is arm 7's
# pend/near pair DECLARED (inputs.decl), committed (the store is keyed on the root commit), with the runner installed
# at scripts/ai-dlc/ and a mktemp verdict store passed on every drive -- never the operator's real store.
# P1 runs both and publishes; every seed below is a COPY of the post-P1 world and its store:
#   s1  unchanged re-push          every fixture skipped by the read-set (the unchanged-push return)
#   s2  pend.key deleted           pend skipped on its STORE entry, its count carried into the republished record
#   s4  s2 pushed again            the read-set skip of the record s2 wrote: store -> record -> read-set
#   s3  near's run.sh edited       near runs, pend skipped: the pool path
#   su  #pending stripped, entry gone  a record without the count is NO run reason: pend skips on it and the push
#                                  names it "count unrecorded" (never a zero)
#   s5  su pushed again            the same: still skipped, still named "count unrecorded"
#   sv  pend.key marked stale      republished without a run (.k.always, c v): the carried count survives it
#   sk  pend.key deleted, entry's `#pending` line cut  an entry written before the count, under the CURRENT digest:
#                                  pend skips on it (the store announce) and is named "count unrecorded"
#   cl  a census over a committed consumer-layout tree (the hook copy's cl_select in census mode, both units run,
#       cl_write), then two pushes each naming a FRESH committed tree in AI_DLC_FX_CL_TREE (the switch the
#       distribution hook sets; read at depth 0 only, so the drive pins PREPUSH_POOL_DEPTH=0) whose pend/run.sh moved
#       after the census: both units are undeclared, so each is keyed on the whole installed tree, and push a runs
#       both and writes their records to <store>/consumer-placement-keys/<root commit>/; push b must select 0 of the 2. Those records
#       never carry `#pending`, and a missing count is no run reason anywhere.
# Cells are <seed>.<observable>: rec2 = the recorded clause names pend with 2, pran = pend ran with its 2 rows,
# vs = the store-skip announce, kp2 = pend.key line 4 is `#pending 2`, unrec = the summary names pend's count unrecorded; cl.skip = push b selects 0 of 2 consumer-layout
# units and names none `pending count unrecorded`, cl.disp = push a's dispatched pend@consumer keeps its 2 rows on its
# ok row AND in the pool PENDING summary, cl.nopend = `<records>:<records carrying #pending>` in the consumer-layout dir.
BL_REC2='   PENDING: 1 skipped on a recorded pass that printed a PENDING row: pend(recorded)=2'
BL_PRAN='   ok    pend  (2 PENDING row(s): its subject is absent, so those parts checked nothing)'
BL_VS='   ..    verdict store: 1 fixture(s) skipped on a pass recorded elsewhere: pend'
BL_UNREC='   PENDING: 1 skipped on a recorded pass whose PENDING count is unrecorded (count unrecorded: recorded before counts were kept, or seeded)'
bl_mk() {                      # bl_mk <tree> <hook> <runner>: the declared, committed pend/near world
  seed "$1" "$2" || return 1
  mkdir -p "$1/scripts/ai-dlc" "$1/src" "$1/tests/fixtures/pend" "$1/tests/fixtures/near" || return 1
  cp "$3" "$1/scripts/ai-dlc/hermetic-run.sh" || return 1
  printf 'v1\n' > "$1/src/a.sh"
  printf '#!/usr/bin/env bash\necho "  PENDING  csp: the subject is absent"\necho "PENDING  csp: a second absent part"\nexit 0\n' > "$1/tests/fixtures/pend/run.sh"
  printf '#!/usr/bin/env bash\necho "near: not PENDING  here"\necho "PENDING (one space, a different row)"\nexit 0\n' > "$1/tests/fixtures/near/run.sh"
  printf 'src/a.sh\n' > "$1/tests/fixtures/pend/inputs.decl"; printf 'src/a.sh\n' > "$1/tests/fixtures/near/inputs.decl"
  ( cd "$1" && git add -A && git commit -qm seed ) >/dev/null 2>&1
}
bl_drv() {                     # bl_drv <tree> <outfile> -> rc; the store is <tree>.vs, the counter never armed inside
  ( cd "$1" && env -u FXCOUNT_DIR -u FXCOUNT_RC -u FXCOUNT_JUDGE AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_VERDICT_STORE="$1.vs" \
      bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}
bl_entry() { grep -lx '#fixture pend' "$1.vs"/*/* 2>/dev/null; }   # bl_entry <tree>: pend's store entry
bl_p1() {                      # bl_p1 <prefix> <hook> <runner>: builds and drives P1 at <prefix>.p1
  mkdir -p "$1.p1.vs" && bl_mk "$1.p1" "$2" "$3" || broken "BL-998 world seed failed"
  printf '%s' "$(bl_drv "$1.p1" "$1.p1.out")" > "$1.p1.rc"
}
bl_seed() {                    # bl_seed <seed> <prefix> <post-P1 tree> [<hook>]: copies, seeds and drives <prefix>.<seed>
  local s="$1" p="$2" b="$3" t="$2.$1" k e n
  if [ "$s" = s4 ]; then [ -f "$p.s2.out" ] || bl_seed s2 "$p" "$b" "${4:-}"; bl_drv "$p.s2" "$p.s4.out" > "$p.s4.rc"; return; fi
  if [ "$s" = s5 ]; then [ -f "$p.su.out" ] || bl_seed su "$p" "$b" "${4:-}"; bl_drv "$p.su" "$p.s5.out" > "$p.s5.rc"; return; fi
  if [ "$s" = cl ]; then cl_seed "$p" "$b" "${4:-}"; return; fi
  cp -Rp "$b" "$t" && cp -Rp "$b.vs" "$t.vs" || broken "BL-998 seed $s: copying the post-P1 world failed"
  [ -z "${4:-}" ] || cp "$4" "$t/.githooks/pre-push" || broken "BL-998 seed $s: installing the hook copy failed"
  k="$t/.git/ai-dlc-fixture-keys"
  [ -f "$k/pend.key" ] || broken "BL-998 seed $s: the post-P1 world holds no pend.key"
  case "$s" in
    s1) ;;
    s2) rm "$k/pend.key" ;;
    s3) printf ': edited\n' >> "$t/tests/fixtures/near/run.sh" ;;   # a code line: a comment no longer moves a run.sh key
    su) grep -v '^#pending ' "$k/pend.key" > "$t.k"; cp "$t.k" "$k/pend.key"
        # pend's store entry goes too: with it, the run the record now owes is answered by a store skip instead.
        e="$(bl_entry "$t")"; [ -f "$e" ] && rm "$e" || broken "BL-998 seed su: no store entry names pend" ;;
    sv) sed '2s/.*/#state stale/' "$k/pend.key" > "$t.k"; cp "$t.k" "$k/pend.key" ;;
    sk) rm "$k/pend.key"
        e="$(bl_entry "$t")"; n="$(printf '%s\n' "$e" | grep -c .)" || n=0
        [ "$n" = 1 ] || broken "BL-998 seed sk: $n store entries name pend, want 1"
        [ "$(tail -n 1 "$e")" = '#pending 2' ] || broken "BL-998 seed sk: pend's store entry does not end in '#pending 2'"
        sed '$d' "$e" > "$t.e"; cp "$t.e" "$e" ;;
    *) broken "BL-998: unknown seed $s" ;;
  esac
  bl_drv "$t" "$p.$s.out" > "$p.$s.rc"
}
cl_seed() {                    # cl_seed <prefix> <post-P1 tree> [<hook>]: the cl seed, two consumer-layout pushes a and b
  local p="$1" t="$1.cl" i
  cp -Rp "$2" "$t" && cp -Rp "$2.vs" "$t.vs" || broken "BL-998 seed cl: copying the post-P1 world failed"
  [ -z "${3:-}" ] || cp "$3" "$t/.githooks/pre-push" || broken "BL-998 seed cl: installing the hook copy failed"
  for i in 0 a b; do
    # A fresh committed tree per run: run_fixtures removes the one it was handed, and cl_select keys the INSTALLED
    # tree through git (BL-1043). Bare run.sh units, no inputs.decl. Trees a and b carry pend's run.sh edited once,
    # so push a has units to dispatch after the census.
    mkdir -p "$t.ct$i/tests/fixtures/pend" "$t.ct$i/tests/fixtures/near" \
      && cp "$t/tests/fixtures/pend/run.sh" "$t.ct$i/tests/fixtures/pend/run.sh" \
      && cp "$t/tests/fixtures/near/run.sh" "$t.ct$i/tests/fixtures/near/run.sh" \
      && { [ "$i" = 0 ] || printf '# moved after the census\n' >> "$t.ct$i/tests/fixtures/pend/run.sh"; } \
      && ( cd "$t.ct$i" && git init -q && git add -A && git commit -qm ct ) >/dev/null 2>&1 || broken "BL-998 seed cl: building consumer-layout tree $i failed"
  done
  # THE CENSUS over tree 0: no push runs every candidate, so the records a push reads come from a census first. The
  # distribution's census script does not ship; this is its core, driven through the hook copy's own FIXTURE_POOL span:
  # cl_select in census mode, each selected unit run from the tree and its pass published by cl_publish, cl_write.
  # The span is SOURCED here, an in-process pass of the hook: fx_inproc records it, and invocations.decl declares it.
  ( cd "$t" && sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' .githooks/pre-push > "$t.pool" || exit 1
    fx_inproc "$HOOK"
    . "$t.pool" >/dev/null 2>&1 || exit 1
    POOL_DEPTH_IN=0 && cl_tree="$t.ct0" && AI_DLC_VERDICT_STORE="$t.vs" && o="$t.census" && mkdir -p "$o" && cl_select "$o" census >"$p.cl0.out" 2>&1 \
      && while IFS= read -r i; do ( cd "$cl_tree" && bash "tests/fixtures/$i/run.sh" ) </dev/null >/dev/null 2>&1 && printf ok > "$o/$i@consumer" && cl_publish "$o" "$i"; done < "$o/.cl.sel" \
      && cl_write "$o" ) || broken "BL-998 seed cl: the census over tree 0 failed: $(tr '\n' '|' < "$p.cl0.out" | tail -c 300)"
  grep -qF '   ..    consumer layout: 2 of 2 shipping fixture(s) run as <fx>@consumer in ' "$p.cl0.out" \
    || broken "BL-998 seed cl: the census did not select both fixtures: $(tr '\n' '|' < "$p.cl0.out" | tail -c 300)"
  for i in a b; do
    ( cd "$t" && env -u FXCOUNT_DIR -u FXCOUNT_RC -u FXCOUNT_JUDGE PREPUSH_POOL_DEPTH=0 AI_DLC_FIXTURE_JOBS=2 AI_DLC_FX_CL_TREE="$t.ct$i" \
        AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_VERDICT_STORE="$t.vs" bash .githooks/pre-push </dev/null >"$p.cl$i.out" 2>&1; echo $? ) > "$p.cl$i.rc"
  done
  grep -qF '   ..    consumer layout: 2 of 2 shipping fixture(s) run as <fx>@consumer in ' "$p.cla.out" \
    || broken "BL-998 seed cl: push a did not run both fixtures in the consumer layout, so push b measures nothing: $(grep -E 'consumer layout|FAIL' "$p.cla.out" | tr '\n' '|' | tail -c 300)"
  cp "$p.clb.out" "$p.cl.out" && cp "$p.clb.rc" "$p.cl.rc"
}
bl_cell() {                    # bl_cell <seed>.<observable>, read off the loaded prefix C_T
  local s="${1%%.*}" c="${1#*.}" o="$C_T.${1%%.*}.out" t="$C_T.${1%%.*}" n m f
  [ "$s" = s4 ] && t="$C_T.s2"; [ "$s" = s5 ] && t="$C_T.su"
  case "$c" in
    rec2) yn grep -qxF "$BL_REC2" "$o" ;;
    pran) yn grep -qxF "$BL_PRAN" "$o" ;;
    vs)   yn grep -qxF "$BL_VS" "$o" ;;
    unrec) yn grep -qxF "$BL_UNREC" "$o" ;;
    kp2)  yn [ "$(sed -n 4p "$t/.git/ai-dlc-fixture-keys/pend.key" 2>/dev/null)" = '#pending 2' ] ;;
    skip) if [ "$(cat "$C_T.clb.rc" 2>/dev/null)" = 0 ] && grep -qF '   ..    consumer layout: 0 of 2 shipping fixture(s) run as <fx>@consumer in ' "$o" \
             && ! grep -qF '@consumer: pending count unrecorded' "$o"; then echo yes; else echo no; fi ;;
    disp) if [ "$(cat "$C_T.cla.rc" 2>/dev/null)" = 0 ] \
             && grep -qxF '   ok    pend@consumer  (2 PENDING row(s): its subject is absent, so those parts checked nothing)' "$C_T.cla.out" \
             && grep -qF ' green fixture(s) printed a PENDING row, so part of each checked nothing: pend@consumer' <<< "$(grep -E '^   PENDING: ' "$C_T.cla.out")"; then
            echo yes; else echo no; fi ;;
    nopend) n=0; m=0
            for f in "$t.vs/consumer-placement-keys/$(git -C "$t" rev-list --max-parents=0 HEAD | LC_ALL=C sort | sed -n 1p)"/*.key; do
              [ -f "$f" ] || continue; n=$((n + 1)); grep -q '^#pending' "$f" && m=$((m + 1))
            done
            printf '%s:%s' "$n" "$m" ;;
    *) echo "<unknown cell $1>" ;;
  esac
}
BL_CELLS="s1.rec2,s2.rec2,s2.vs,s2.kp2,s4.rec2,s3.rec2,su.pran,su.kp2,su.unrec,s5.unrec,sv.rec2,sv.kp2,sk.pran,sk.vs,sk.unrec,cl.skip,cl.rec2,cl.disp,cl.nopend"
bl_drive_cells() {             # bl_drive_cells <prefix> <post-P1 tree> <hook|-> <cells>: drives only the seeds the cells read
  local c s h="$3"; [ "$h" = - ] && h=""
  for c in $4; do s="${c%%.*}"; [ -f "$1.$s.out" ] || bl_seed "$s" "$1" "$2" "$h"; done
}
lmut() {                       # lmut <label> <src> <dst> <old> <new>: the ONE line holding <old> gets <new> in its place
  local n
  n="$(O="$4" awk 'index($0, ENVIRON["O"]) { c++ } END { print c + 0 }' "$2")"
  [ "$n" = 1 ] || { bad "MUTANT $1: its anchor matched $n line(s) of ${2##*/}, want 1 -- a lost subject, not a mutation"; return 1; }
  O="$4" N="$5" awk '{ i = index($0, ENVIRON["O"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["N"] substr($0, i + length(ENVIRON["O"])); print }' "$2" > "$3" \
    || { bad "MUTANT $1: the copy failed"; return 1; }
  cmp -s "$2" "$3" && { bad "MUTANT $1 DID NOT APPLY (cmp -s)"; return 1; }
  return 0
}

_f0=$fails
BLF="$WORK/bl.fixed"
bl_p1 "$BLF" "$HOOK" "$HR_SRC"
BLP="$BLF.p1"
_pk="$BLP/.git/ai-dlc-fixture-keys"
_e="$(bl_entry "$BLP")"
_hn="$(sed -n 's/^   ok    pend  (\([0-9]*\) PENDING row(s).*/\1/p' "$BLF.p1.out")"
_rn="$(tail -n 1 "$_e" 2>/dev/null | sed -n 's/^#pending \([0-9]*\)$/\1/p')"
if [ "$(cat "$BLF.p1.rc")" = 0 ] && grep -qxF "$BL_PRAN" "$BLF.p1.out" && grep -qxF '   ok    near' "$BLF.p1.out" \
   && grep -qxF '   PENDING: 1 green fixture(s) printed a PENDING row, so part of each checked nothing: pend' "$BLF.p1.out" \
   && [ "$(sed -n 4p "$_pk/pend.key" 2>/dev/null)" = '#pending 2' ] && [ "$(sed -n 4p "$_pk/near.key" 2>/dev/null)" = '#pending 0' ] \
   && [ "$(sed -n 1,2p "$_e" 2>/dev/null | tr '\n' ,)" = '#format k1,#state ok,' ] && [ "$_rn" = 2 ]; then
  ok "7b P1: the declared pend runs through the installed runner, counts 2 rows, and both pass records carry it (key record line 4 '#pending 2', near '#pending 0'; store entry k1 ending '#pending 2')"
else
  bad "7b P1 (rc=$(cat "$BLF.p1.rc")): $(grep -E 'ok    |PENDING|hermetic-run' "$BLF.p1.out" | grep -v '^   done ' | tr '\n' '|' | tail -c 500) pend.key line 4 '$(sed -n 4p "$_pk/pend.key" 2>/dev/null)' entry '$(sed -n 1,2p "$_e" 2>/dev/null | tr '\n' ,)...$(tail -n 1 "$_e" 2>/dev/null)'"
fi
bl_drive_cells "$BLF" "$BLP" - "$(printf '%s' "$BL_CELLS" | tr , ' ')"
C_T="$BLF"
BASE_bl="$(for _c in ${BL_CELLS//,/ }; do printf '%s=%s\n' "$_c" "$(bl_cell "$_c")"; done)"
_bl_eq() { [ "$(mx_get "$BASE_bl" "$1")" = "$2" ]; }
if [ "$(cat "$BLF.s1.rc")" = 0 ] && _bl_eq s1.rec2 yes && ! grep -q '^   ok    ' "$BLF.s1.out" \
   && grep -qF '   ..    read-set keys: 0 of 2 fixture(s) run' "$BLF.s1.out"; then
  ok "7b s1 an unchanged re-push skips both on their records and still names pend with its 2 rows, marked recorded; near (0 rows) is not named"
else bad "7b s1 the unchanged-push return lost the count (rc=$(cat "$BLF.s1.rc")): $(grep -E 'PENDING|read-set|   ok ' "$BLF.s1.out" | tr '\n' '|' | tail -c 400)"; fi
if [ "$(cat "$BLF.s2.rc")" = 0 ] && _bl_eq s2.vs yes && _bl_eq s2.rec2 yes && _bl_eq s2.kp2 yes \
   && [ -n "$_hn" ] && [ "$_hn" = "$_rn" ] && grep -qxF "   PENDING: 1 skipped on a recorded pass that printed a PENDING row: pend(recorded)=$_rn" "$BLF.s2.out"; then
  ok "7b s2 pend skipped on its store entry: the hook's count ($_hn) equals the runner's entry count ($_rn), it is printed, and the republished record carries it"
else bad "7b s2 the store skip (hook n '$_hn', runner n '$_rn'): $(grep -E 'PENDING|verdict store' "$BLF.s2.out" | tr '\n' '|' | tail -c 400) pend.key line 4 '$(sed -n 4p "$BLF.s2/.git/ai-dlc-fixture-keys/pend.key" 2>/dev/null)'"; fi
if [ "$(cat "$BLF.s4.rc")" = 0 ] && _bl_eq s4.rec2 yes && ! grep -qxF "$BL_VS" "$BLF.s4.out"; then
  ok "7b s4 the record a store skip republished is read-set skipped on the next push and still names pend with 2 (store -> record -> read-set)"
else bad "7b s4 the carry chain broke: $(grep -E 'PENDING|verdict store' "$BLF.s4.out" | tr '\n' '|' | tail -c 400)"; fi
if [ "$(cat "$BLF.s3.rc")" = 0 ] && _bl_eq s3.rec2 yes && grep -qxF '   ok    near' "$BLF.s3.out" && ! grep -q '^   ok    pend' "$BLF.s3.out"; then
  ok "7b s3 near re-runs on the pool path while pend is skipped, and the pool path's summary names pend recorded with 2"
else bad "7b s3 the pool path lost the count: $(grep -E 'PENDING|   ok ' "$BLF.s3.out" | grep -v '^   done ' | tr '\n' '|' | tail -c 400)"; fi
if [ "$(cat "$BLF.su.rc")" = 0 ] && _bl_eq su.pran no && _bl_eq su.kp2 no && _bl_eq su.unrec yes \
   && ! grep -q '^   ok    ' "$BLF.su.out" && [ "$(cat "$BLF.s5.rc")" = 0 ] && _bl_eq s5.unrec yes && ! grep -q '^   ok    ' "$BLF.s5.out"; then
  ok "7b su a record with no #pending line is no run reason: pend skips on it and the push names its count unrecorded (not a zero); s5 the next push does the same"
else bad "7b su/s5 the record without a count: $(grep -E 'PENDING|   ok |read-set|unrecorded' "$BLF.su.out" | grep -v '^   done ' | tr '\n' '|' | tail -c 400) s5: $(grep -E 'PENDING|   ok ' "$BLF.s5.out" | tr '\n' '|')"; fi
if [ "$(cat "$BLF.sv.rc")" = 0 ] && _bl_eq sv.rec2 yes && _bl_eq sv.kp2 yes \
   && [ "$(sed -n 2p "$BLF.sv/.git/ai-dlc-fixture-keys/pend.key")" = '#state ok' ]; then
  ok "7b sv a stale record republished without a run (state back to ok) keeps '#pending 2' and is named recorded with 2"
else bad "7b sv the stale republish: $(grep -E 'PENDING' "$BLF.sv.out" | tr '\n' '|') record '$(sed -n 1,4p "$BLF.sv/.git/ai-dlc-fixture-keys/pend.key" 2>/dev/null | tr '\n' ,)'"; fi
if [ "$(cat "$BLF.sk.rc")" = 0 ] && _bl_eq sk.pran no && _bl_eq sk.vs yes && _bl_eq sk.unrec yes; then
  ok "7b sk a store entry written before the count (no '#pending' line) under the current digest is reused: pend skips on it and is named count unrecorded"
else bad "7b sk the count-less entry (pran=$(mx_get "$BASE_bl" sk.pran) vs=$(mx_get "$BASE_bl" sk.vs) unrec=$(mx_get "$BASE_bl" sk.unrec)): $(grep -E 'PENDING|verdict store|   ok ' "$BLF.sk.out" | grep -v '^   done ' | tr '\n' '|' | tail -c 400)"; fi
if _bl_eq cl.skip yes && _bl_eq cl.rec2 yes && _bl_eq cl.disp yes && _bl_eq cl.nopend 2:0; then
  ok "7b cl the consumer layout: push a runs pend@consumer and names it in the pool PENDING summary; its 2 records carry no #pending; push b selects 0 of 2 and names none 'pending count unrecorded', while pend(recorded)=2 still prints"
else bad "7b cl the consumer layout (skip=$(mx_get "$BASE_bl" cl.skip) rec2=$(mx_get "$BASE_bl" cl.rec2) disp=$(mx_get "$BASE_bl" cl.disp) records:#pending=$(mx_get "$BASE_bl" cl.nopend)): a: $(grep -E 'consumer layout|@consumer|PENDING' "$BLF.cla.out" | grep -v '^   done ' | tr '\n' '|' | tail -c 300) b: $(grep -E 'consumer layout|@consumer|PENDING' "$BLF.cl.out" | grep -v '^   done ' | tr '\n' '|' | tail -c 300)"; fi
B_bl=$([ "$fails" = "$_f0" ] && echo 1 || echo 0)

# F10, VERSION SKEW: a runner sourcing a hook whose READSET_VS span predates the `#pending` entry line (no readset_vs_entry, no
# READSET_VS_PENDING) turns the store OFF, says so, and writes nothing; the same run under the current span wrote
# P1's entry (the control above). The old span is the current one with the two definitions cut, each cut counted.
_old="$WORK/hook.oldvs"
awk '/^READSET_VS_PENDING=/ { next } /^readset_vs_entry\(\) \{/ { skip = 1; next } skip && /^}$/ { skip = 0; next } !skip' "$HOOK" > "$_old"
_c0="$(grep -cE '^(readset_vs_entry\(\) |READSET_VS_PENDING=)' "$HOOK")" || _c0=0
_c1="$(grep -cE '^(readset_vs_entry\(\) |READSET_VS_PENDING=)' "$_old")" || _c1=0
[ "$_c0" = 2 ] && [ "$_c1" = 0 ] || broken "BL-998 F10: the old-span copy holds $_c1 of the two definitions (the hook $_c0), want 0 of 2"
cp -Rp "$BLP" "$WORK/bl.skew" && cp "$_old" "$WORK/bl.skew/.githooks/pre-push" && mkdir -p "$WORK/bl.skew.vs" || broken "BL-998 F10 world copy failed"
_sk="$( cd "$WORK/bl.skew" && env -u FXCOUNT_DIR -u FXCOUNT_RC -u FXCOUNT_JUDGE AI_DLC_VERDICT_STORE="$WORK/bl.skew.vs" \
          bash scripts/ai-dlc/hermetic-run.sh --root "$WORK/bl.skew" pend 2>&1)"
_skn="$(find "$WORK/bl.skew.vs" -type f | grep -c .)" || _skn=0
if grep -qxF 'hermetic-run: pend: verdict store OFF: the hook READSET_VS span lacks readset_vs_entry or READSET_VS_PENDING (version skew), so no entry is written' <<< "$_sk" \
   && grep -q '^hermetic-run: pend: rc=0 ' <<< "$_sk" && [ "$_skn" = 0 ]; then
  ok "7b F10 a runner sourcing a span without readset_vs_entry and READSET_VS_PENDING passes pend, says the store is OFF for version skew, and writes no entry"
else bad "7b F10 version skew: $_skn entr(ies) written; $(grep '^hermetic-run: pend' <<< "$_sk" | tr '\n' '|')"; fi

# UNMUTATED CONTROL for the reused worlds: a copy of the hook installed into a copy of the post-P1 world reproduces s1.
C_T="$WORK/bl.ctl"; bl_drive_cells "$C_T" "$BLP" "$WORK/hook.control" s1.rec2
if [ "$B_bl" = 1 ] && [ "$(bl_cell s1.rec2)" = yes ] && ! grep -q '^   ok    ' "$C_T.s1.out"; then
  ok "7b control: an unmutated hook copy installed into a copy of the post-P1 world reproduces s1 -- the reused worlds are sound"
else bad "7b control is RED: no BL-998 mutant verdict below is believable"; fi

# THE MUTANTS. One that edits the key writer, the runner, or a READSET_VS line (which moves #universe and so the store
# digest) rebuilds its world from P1; one that edits the decision or the render reuses the post-P1 world with its
# hook installed. Each drives only the seeds its deciding and twin cells read.
bl_score() {                   # bl_score <mutant> <decides> <twins> <expected> <prefix> <message>
  C_T="$5"
  csp_score "$1" "$([ "$B_bl" = 1 ] && echo 1 || echo 0)" "$2" "$3" "$4" "$BL_CELLS" "$BASE_bl" "$6"
}
bl_reuse() {                   # bl_reuse <mutant> <decides> <twins> <expected> <old> <new> <message>
  local h="$WORK/hook.$1" p="$WORK/bl.$1"
  lmut "$1" "$HOOK" "$h" "$5" "$6" || return 0
  bl_drive_cells "$p" "$BLP" "$h" "$(mx_cells "$BL_CELLS" "$2" "$3")"
  bl_score "$1" "$2" "$3" "$4" "$p" "$7"
}
bl_fresh() {                   # bl_fresh <mutant> <decides> <twins> <expected> <hook> <runner> <message>
  local p="$WORK/bl.$1"
  bl_p1 "$p" "$5" "$6"
  [ "$(cat "$p.p1.rc")" = 0 ] || { bad "MUTANT $1: its P1 drive failed (rc $(cat "$p.p1.rc")), so no cell of it is a verdict"; return 0; }
  bl_drive_cells "$p" "$p.p1" - "$(mx_cells "$BL_CELLS" "$2" "$3")"
  bl_score "$1" "$2" "$3" "$4" "$p" "$7"
}
if lmut bl998-kw0 "$HOOK" "$WORK/hook.bl998-kw0" 'print "#pending " n > o' 'print "#pending 0" > o'; then
  bl_fresh bl998-kw0 s1.rec2 s2.rec2 $'s1.rec2=no' "$WORK/hook.bl998-kw0" "$HR_SRC" \
    "bl998-kw0 with the key writer writing '#pending 0' the read-set skip names nothing, while the store skip (its count from the entry) still does"
fi
if lmut bl998-sw0 "$HR_SRC" "$WORK/hr.bl998-sw0" "#pending %s\\n' \"\$pn\"" "#pending %s\\n' 0"; then
  bl_fresh bl998-sw0 s2.rec2 s1.rec2 $'s2.rec2=no' "$HOOK" "$WORK/hr.bl998-sw0" \
    "bl998-sw0 with hermetic-run.sh writing '#pending 0' the store skip names nothing, while the read-set skip (the hook's own count) still does"
fi
bl_reuse bl998-rd-early s1.rec2 s3.rec2 $'s1.rec2=no' '    readset_pending_line 0 "" "$out/.precorded"' '    :' \
  "bl998-rd-early without the renderer on the unchanged-push return the s1 summary is gone, while the pool path's stays"
bl_reuse bl998-rd-pool s3.rec2 s1.rec2 $'s3.rec2=no' 'readset_pending_line "$pend_n" "$pend_fx" "$out/.precorded"' ':' \
  "bl998-rd-pool without the renderer on the pool path the s3 summary is gone, while the unchanged-push return's stays"
bl_reuse bl998-carry-v sv.rec2 s1.rec2 $'sv.rec2=no' 'if (!run && !seed && (f in RPN)) print f "\t" RPN[f] > ENVIRON["KPN"]' '' \
  "bl998-carry-v without the republish carry a stale record republished without a run loses its count, while a plain read-set skip keeps it"
bl_reuse bl998-carry-vs s2.rec2 s1.rec2 $'s2.rec2=no' "printf '%s\\t%s\\n' \"\$fx\" \"\$pn\" >> \"\$out/.kpn\"" ':' \
  "bl998-carry-vs without the store-skip carry a store-skipped fixture loses the entry's count, while a plain read-set skip keeps it"
# bl998-unrec-store: the store reader takes only an entry carrying a count, so an entry written before the count
# re-runs its fixture (the whole stored set, on a real store); decided on sk, where pend must skip on its entry,
# while s2 (an entry with its count) is still a store skip.
bl_reuse bl998-unrec-store sk.pran s2.vs $'sk.pran=yes' 'HIT[fx] = 1; print fx "\t" pn }' 'HIT[fx] = 1; if (pn != "-") print fx "\t" pn }' \
  "bl998-unrec-store with the store reader refusing a count-less entry pend re-runs on sk, while a store entry with its count (s2) still skips"
# bl998-unrec-key: a key record with no #pending line made a run reason again (the retired "re-run once"); decided on
# su, where pend must skip, while a record with its count (s1) still skips.
bl_reuse bl998-unrec-key su.pran s1.rec2 $'su.pran=yes' '        else run = 0' '        else run = (!seed && !(f in RPN))' \
  "bl998-unrec-key with a missing count made a run reason pend re-runs on su, while a record with its count (s1) still skips"

# BL-998's runner-wired receipt, beside this file.
_rb="$(bash "$HERE/receipt-bl998.sh" "$HOOK" 2>&1)"; _rbrc=$?; _rbn="$(grep -c '^CELL [^ ]* PASS' <<< "$_rb")" || _rbn=0
[ "$_rbrc" = 0 ] && [ "$_rbn" = 3 ] && ok "receipt-bl998.sh passes: 3 CELL PASS" || bad "receipt-bl998.sh exited $_rbrc with $_rbn CELL PASS line(s), want 0 and 3: $(printf '%s\n' "$_rb" | tail -5 | tr '\n' '|')"

# NO STALL WORLD LEAVES A PROCESS BEHIND. Every pid a stub recorded under a stall world's pids/ file, and
# every pid the extracted-worker (orphan) and trace worlds recorded, must be dead by now: `kill -0` fails
# for each. A mutant that keeps a unit's grandchild alive by design (st-c, st-g) is reaped by its own
# arm, so a leak here means a world was left running, which used to pass silently and burn a core.
# The `.pgid.*` files hold process-group numbers, not pids to reap, so they are not read.
# A pid killed a moment ago can still answer `kill -0` until it is reaped, so the count blocks on the CONDITION
# (every recorded pid gone, or every one not gone csp_state `settled`) with a builtin wait (`read -t 1` on a
# held fifo, no process start, pacing only). A leaked busy loop is STOPped by csp_state and named here as a leak;
# a SIGKILLed pid exits rather than stopping, so it is never named a survivor.
# Each live pid is first read by csp_own: only this fixture's own process is STOPped, named or killed; a reused pid
# is the recorded process gone, and is counted as such.
# THE ARM'S OWN PROBE, both directions, before it reads the worlds: a fifo reader standing under $WORK reads `ours`,
# the same reader standing outside it reads `reused`, and a reaped pid reads `gone`. Each reader writes its marker
# after its cd, so the read waits on that condition, not on time.
mkfifo "$WORK/lk.fifo" "$WORK/own.fifo" || broken "mkfifo failed"; exec 8<>"$WORK/lk.fifo"
( cd "$WORK" && : > "$WORK/own.in" && exec /bin/cat "$WORK/own.fifo" ) >/dev/null 2>&1 & _ow_in=$!
( cd / && : > "$WORK/own.out" && exec /bin/cat "$WORK/own.fifo" ) >/dev/null 2>&1 & _ow_out=$!
( : ) & _ow_dead=$!; wait "$_ow_dead"
while { [ ! -e "$WORK/own.in" ] || [ ! -e "$WORK/own.out" ]; } && kill -0 "$_ow_in" 2>/dev/null && kill -0 "$_ow_out" 2>/dev/null; do read -t 1 -u 8 _lk_x; done
csp_own "$_ow_in"; _ow_r="$CSP_OWN"; csp_own "$_ow_out"; _ow_r="$_ow_r $CSP_OWN"; csp_own "$_ow_dead"; _ow_r="$_ow_r $CSP_OWN"
kill -KILL "$_ow_in" "$_ow_out" 2>/dev/null; wait "$_ow_in" "$_ow_out" 2>/dev/null
[ "$_ow_r" = "ours reused gone" ] && ok "csp_own reads a reader under \$WORK as ours, one outside it as reused, a reaped pid as gone" \
                               || bad "csp_own probe read '$_ow_r', want 'ours reused gone' -- the leak arm cannot tell a leak from a reused pid"
while :; do
  _lk_n=0; _lk_live=""; _lk_settled=1; _lk_ru=0
  for _lk_f in "$WORK"/*/pids/* "$WORK"/orph.*/pids "$WORK"/trace.*/pids; do
    [ -f "$_lk_f" ] || continue
    case "$_lk_f" in *.pgid.*) continue ;; esac
    while read -r _lk_p; do
      case "$_lk_p" in ''|*[!0-9]*) continue ;; esac
      _lk_n=$((_lk_n + 1))
      csp_own "$_lk_p"
      case "$CSP_OWN" in gone) continue ;; reused) _lk_ru=$((_lk_ru + 1)); continue ;; esac
      csp_state "$_lk_p"
      [ "$CSP_ST" = gone ] || { _lk_live="$_lk_live $_lk_p"; [ "$CSP_ST" = settled ] || _lk_settled=0; }
    done < "$_lk_f"
  done
  [ -z "$_lk_live" ] && break
  [ "$_lk_settled" = 1 ] && break
  read -t 1 -u 8 _lk_x
done
exec 8>&-
if [ "$_lk_n" -gt 0 ] && [ -z "$_lk_live" ]; then
  ok "no stall world leaked a process: all $_lk_n recorded pids are dead (kill -0 fails, the pid is an unreaped zombie, or it now names a process outside \$WORK: $_lk_ru)"
else
  bad "stall worlds left ${_lk_live:-nothing} alive, or recorded no pid at all (read $_lk_n) -- a leaked unit tree burns a core after the fixture reports"
  for _lk_p in $_lk_live; do kill -KILL "$_lk_p" 2>/dev/null; done
fi

# ------------------------------------------------------- the matrix machinery itself ---
mx_probe && ok "matrix machinery probe: a seeded deciding trip is judged a kill, a seeded survivor is not, and a twin that trips is refused" \
         || bad "matrix machinery probe FAILED: the judge cannot tell a kill from a survivor, so no mutant verdict above is believable"
# A PLAIN run executes no matrix-only cell: only a --matrix run evaluates cells beyond decides+twins.
if [ "$MATRIX" = 1 ]; then
  [ "$MX_EXTRA" -gt 0 ] && ok "matrix mode evaluated $MX_EXTRA cells beyond the deciding and twin cells" \
                        || bad "matrix mode evaluated no extra cell -- the matrix flag is not reaching the judge"
else
  [ "$MX_EXTRA" = 0 ] && ok "a plain run executes no matrix-only cell (0 cells beyond decides+twins) -- only --matrix measures the full matrix" \
                      || bad "a plain run evaluated $MX_EXTRA matrix-only cells -- the matrix is running on every push"
fi


# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are
# emitted from inside a conditional: an assertion that never executed prints nothing,
# and a short green report reads exactly like a complete one. This is the same
# property the hook itself now asserts about its own workers, one layer out.
EXPECTED_ASSERTIONS=85
if [ "$asserts" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf '  FAIL  %s assertions ran, %s expected — an arm did not execute, and a short green report reads exactly like a complete one\n' \
    "$asserts" "$EXPECTED_ASSERTIONS"
  fails=$((fails+1))
fi

if [ "$fails" -ne 0 ]; then
  printf '  consumer-suite-pool: %s FAILED\n' "$fails"
  exit 1
fi
printf '  consumer-suite-pool: %s assertions, all green\n' "$asserts"
