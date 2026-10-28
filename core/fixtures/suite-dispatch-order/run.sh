#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# suite-dispatch-order — the fixture pool dispatches longest-first, off a durations
# record the previous run wrote, and falls back to glob order whenever it cannot.
#
# WHY THIS IS A SEPARATE, `.dist-only` FIXTURE, and the measurement that put it here.
# These arms were written inside `consumer-suite-pool`, which is SHIPPED to consumers.
# They cost about 30s, because the only honest way to observe a dispatch order is to
# give the units distinguishable costs and then pay them. In THIS repository that was
# free: `consumer-suite-pool` went 8.8s -> 41s against a 151s pole, so it stayed a
# passenger with ~110s of slack and every slack figure said the change cost nothing.
#
# On the reference consumer it became THE POLE. Measured on a `git clone --local` after
# the real `apply.sh`: `consumer-suite-pool` 40s against a next-heaviest unit of 29s,
# and the consumer's whole pre-push went 41.07s -> 49.98s. The release that added those
# arms is the one that dispatches longest-first to SAVE the consumer 2.4s. It spent 9.
#
# THE ERROR WAS MEASURING THE SLACK IN THE WRONG SUITE, which is the same finding the
# arms below exist to prove, one layer down and in my own work: what a unit costs a
# schedule is a property of the SUITE IT LANDS IN, not of the unit. §7 gate item 6 says
# a new `.dist-only` fixture costs zero enumeration and runs concurrently, and to prefer
# that to growing one already on a critical path. It is the robust answer rather than
# the tuned one — trimming these arms to fit under the consumer's pole would work only
# until the consumer's pole moved, and that is a number core does not control.
#
# WHAT STAYS IN `consumer-suite-pool`: everything about the pool's CORRECTNESS — the
# empty-suite guard, the dropped-worker completeness arm, attribution, list-order
# reporting, and that the pool is really a pool. A consumer runs those. The dispatch
# ORDER cannot cost a consumer a verdict — the report and the expected count are both
# taken from the unordered list — so proving it is the distribution's job.
# THE MUTANT MATRIX. Each mutant runs per push on its DECIDING arm plus ONE measured-GREEN twin, and the
# kill must stay confined: the deciding arm FAILS under the mutant, the twin PASSES. The full mutant x arm
# matrix is measured by `--matrix` (an argv flag; every mutant against every arm, one MATRIX row each) and
# is re-measured whenever an arm or a mutant is added or changed. The recorded matrix plus the twin
# replaces a per-push check that no OTHER arm trips. The arms are the columns of the MATRIX rows:
#   order glob format outside (world lpt), badrec, merge mergeorder (world merge), prune, red green (world red).
# MUTANT-MATRIX m1 decides=order twins=badrec
# MUTANT-MATRIX m2 decides=order twins=badrec
# MUTANT-MATRIX m3 decides=format twins=badrec
# MUTANT-MATRIX m4 decides=merge twins=red
# MUTANT-MATRIX m5 decides=red twins=badrec
# MUTANT-MATRIX m6 decides=prune twins=badrec
# MUTANT-MATRIX m7 decides=prune twins=badrec
# MUTANT-MATRIX-REMEASURE bash core/fixtures/suite-dispatch-order/run.sh --matrix
set -uo pipefail

# `--matrix` is an ARGV flag. A plain run executes no matrix-only cell.
MATRIX=0
[ "${1:-}" = "--matrix" ] && MATRIX=1

# HERMETICITY. This fixture drives a hook that reads AI_DLC_FIXTURE_JOBS, and two arms
# below set it explicitly. An operator carrying a value in their environment would
# otherwise fail an arm against a hook behaving exactly as configured.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/matrix.sh" ] || { echo "FIXTURE ERROR: matrix.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/suite-dispatch-order/matrix.sh"

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "suite-dispatch-order: FIXTURE BROKEN" >&2; exit 2; }

echo "suite-dispatch-order:"

# Both layouts, named rather than derived from one another (I33).
HOOK=""
for cand in "$HERE/../../git-hooks/pre-push" "$HERE/../../../.githooks/pre-push"; do
  [ -f "$cand" ] && { HOOK="$cand"; break; }
done
[ -n "$HOOK" ] || broken "cannot locate the pre-push hook in either layout (core/git-hooks/pre-push or .githooks/pre-push) from $HERE"

echo "HERMETIC-CONSUMED $(cd "$(dirname "$HOOK")" && pwd)/pre-push"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/suite-dispatch-order.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# A real git repository: the hook's first act is `cd "$(git rev-parse --show-toplevel)"`,
# and its durations record lives under `.git/`, so a seed without one would exercise a
# code path no push ever takes.
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

mkfx() {                       # mkfx <tree> <name> <exitcode>
  mkdir -p "$1/tests/fixtures/$2"
  printf '#!/usr/bin/env bash\nexit %s\n' "$3" > "$1/tests/fixtures/$2/run.sh"
}

# A fixture that RECORDS THE MOMENT IT WAS DISPATCHED and then costs a stated number of
# seconds. The cost is what the hook writes into its record; the trace is how the next
# run's dispatch order is read back.
mkfx_trace() {                 # mkfx_trace <tree> <name> <seconds>
  mkdir -p "$1/tests/fixtures/$2"
  cat > "$1/tests/fixtures/$2/run.sh" <<FX
#!/usr/bin/env bash
printf '%s\n' '$2' >> "\$SDO_TRACE"
sleep $3
exit 0
FX
}

# NO_SKIP: every drive here re-runs one tree and expects the whole suite dispatched. Without it the
# per-fixture key records the first green drive writes would skip every unit on the next one.
drive() {                      # drive <tree> <outfile>  -> rc
  ( cd "$1" && AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}

# THE READ-SET SKIP ON, for the arms whose subject is a unit the skip did not dispatch while its
# directory stayed on disk. The verdict store is a sibling of the tree, never `$HOME/.cache`.
drive_skip() {                 # drive_skip <tree> <outfile>  -> rc
  ( cd "$1" && AI_DLC_VERDICT_STORE="$1.vs" AI_DLC_READSET_LIVE_TRACE=0 bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}

# A committed read-set map giving aaa, mmm and zzz one source file each, so changing src/mmm.txt
# and src/zzz.txt re-runs those two and the skip withholds aaa -- the real narrowing path.
seed_mapped() {                # seed_mapped <tree>
  local t="$1" n
  mkdir -p "$t/src" || return 1
  for n in aaa mmm zzz; do
    printf 'v1\n' > "$t/src/$n.txt" || return 1
    printf '%s\tsrc/%s.txt\n' "$n" "$n" >> "$t/.ai-dlc-fixture-readsets.tsv" || return 1
  done
  git -C "$t" add -A >/dev/null 2>&1 && git -C "$t" commit -qm seed >/dev/null 2>&1
}

# Narrow by the skip: record keys on a green run, install the seeded record, change mmm's and
# zzz's sources, and run again. Refuses unless exactly mmm and zzz were dispatched.
narrow_by_skip() {             # narrow_by_skip <tree> <label> <seed record>  -> rc of the narrowed run, or "broken:<why>"
  local t="$1" l="$2" s="$3" r nd
  r="$(drive_skip "$t" "$WORK/$l.keys.out")"
  [ "$r" = 0 ] || { echo "broken:key-recording run rc=$r"; return 0; }
  cp "$s" "$t/.git/ai-dlc-fixture-durations" || { echo "broken:could not install the seeded record"; return 0; }
  printf 'v2\n' > "$t/src/mmm.txt"; printf 'v2\n' > "$t/src/zzz.txt"
  : > "$SDO_TRACE"
  r="$(drive_skip "$t" "$WORK/$l.out")"
  nd="$(grep -c . "$SDO_TRACE")" || nd=0
  if [ "$nd" != 2 ] || grep -qx aaa "$SDO_TRACE"; then
    echo "broken:the skip dispatched $nd unit(s) ($(tr '\n' ' ' < "$SDO_TRACE")), not mmm and zzz alone"; return 0
  fi
  echo "$r"
}

# ONE AT A TIME, which is what makes dispatch order observable at all. Above width 1 the
# workers overlap and the trace records a race; at width 1 execution order IS dispatch
# order, so the trace reads the schedule directly rather than inferring it from a wall
# clock — the timing-sensitive assertion §7's gate warns about.
drive1() {                     # drive1 <tree> <outfile>  -> rc
  ( cd "$1" && AI_DLC_FIXTURE_JOBS=1 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}

SEEDREC="$WORK/seed.durations"
printf 'aaa 1\nmmm 5\nzzz 9\n' > "$SEEDREC" || broken "could not write the seeded durations record"

# --------------------------------- THE WORLDS AND THE ARMS ---------------------------------------
# Every arm is a verdict on one seeded world, driven through a HOOK PATH given as an argument. The
# shipped hook is driven under the tag `base`, which emits the ok/FAIL lines; a mutant is driven under
# its own tag through the SAME world functions, which only record each arm's result (0 = the arm
# passed, 1 = the arm failed). That is what makes the mutant x arm matrix measurable: one function per
# world, the arms read off it. The arms (matrix columns) are:
#   order glob format outside   (world lpt)      badrec (world bad)     merge mergeorder (world merge)
#   prune (world prune)         red green (world red)
ALL_ARMS="order glob format outside badrec merge mergeorder prune red green"
RES="$WORK/res"; mkdir -p "$RES" || broken "could not create the result dir"
setres() { printf '%s\n' "$3" > "$RES/$1.$2"; }                  # setres <tag> <arm> <0|1>
getres() { if [ -f "$RES/$1.$2" ]; then cat "$RES/$1.$2"; else echo NA; fi; }
# chk <tag> <arm> <pass:0|1> <ok message> <fail message>
chk() {
  setres "$1" "$2" "$3"
  [ "$1" = base ] || return 0
  if [ "$3" = 0 ]; then ok "$4"; else bad "$5"; fi
}
# A world that cannot be built is FIXTURE BROKEN for the shipped hook, and a TRIPPED arm for a mutant.
world_broken() { # world_broken <tag> <why> <arm>...
  local tag="$1" why="$2" a; shift 2
  [ "$tag" = base ] && broken "$why"
  for a in "$@"; do setres "$tag" "$a" 1; done
}

w_lpt() { # w_lpt <tag> <hook>
  local tag="$1" h="$2" T="$WORK/$1-lpt" rc order ctl_order bound nearmiss n_rec n_last p REC
  seed "$T" "$h" || broken "seed failed"
  export SDO_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 0; mkfx_trace "$T" zzz 0
  cp "$SEEDREC" "$T/.git/ai-dlc-fixture-durations" || broken "could not install the seeded durations record"
  : > "$SDO_TRACE"
  rc="$(drive1 "$T" "$WORK/$tag-lpt2.out")"
  order="$(tr '\n' ' ' < "$SDO_TRACE")"
  p=1; [ "$rc" = 0 ] && [ "$order" = "zzz mmm aaa " ] && p=0
  chk "$tag" order "$p" \
    "a record costing aaa=1 mmm=5 zzz=9 dispatches longest-first (zzz mmm aaa) — the ORDERING RULE, with no stopwatch in the assertion" \
    "the seeded record did not dispatch longest-first (rc=$rc, got '$order', glob order is 'aaa mmm zzz') — a pool's makespan is decided by when its longest unit starts"
  # CONTROL. Same tree, same fixtures, same width — only the record removed.
  rm -f "$T/.git/ai-dlc-fixture-durations"
  : > "$SDO_TRACE"
  rc="$(drive1 "$T" "$WORK/$tag-lpt3.out")"
  ctl_order="$(tr '\n' ' ' < "$SDO_TRACE")"
  p=1; [ "$rc" = 0 ] && [ "$ctl_order" = "aaa mmm zzz " ] && p=0
  chk "$tag" glob "$p" \
    "with the record deleted the SAME tree dispatches in glob order — the record is what reorders it, and a first run is correct without one" \
    "removing the record did not restore glob order (rc=$rc, got '$ctl_order') — arm 1 is not measuring the record"
  # The WRITER's format is the one the READER parses (the control run above wrote this record).
  REC="$T/.git/ai-dlc-fixture-durations"
  bound="$(awk 'NF == 2 && $2 ~ /^[0-9]+$/ { print $1 }' "$REC" 2>/dev/null | sort | tr '\n' ' ')"
  nearmiss="$(awk 'NF == 2 && $2 ~ /^[0-9]+$/ { print $1 }' <<<'aaa' | tr '\n' ' ')"
  p=1; [ "$bound" = "aaa mmm zzz " ] && [ -z "$nearmiss" ] && p=0
  chk "$tag" format "$p" \
    "every line the pool WROTE is accepted by the reader's own NF==2 parse and keys on the basename the reader derives, while a one-field near-miss is rejected" \
    "the written record does not join to the reader's parse (accepted '$bound', expected 'aaa mmm zzz '; near-miss yielded '$nearmiss') — a writer/reader format split makes every cost lookup miss and degrades the reorder to glob order in silence"
  # The record is written OUTSIDE the working tree.
  : > "$SDO_TRACE"
  rc="$(drive "$T" "$WORK/$tag-lpt4.out")"
  n_rec="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  case "$n_rec" in ''|*[!0-9]*) n_rec=0 ;; esac
  n_last="$(grep -c . "$T/.git/ai-dlc-fixture-durations.last" 2>/dev/null)"
  case "$n_last" in ''|*[!0-9]*) n_last=0 ;; esac
  p=1
  if [ "$n_rec" -eq 3 ] && [ ! -f "$T/ai-dlc-fixture-durations" ] \
     && [ "$n_last" -eq 3 ] && [ ! -f "$T/ai-dlc-fixture-durations.last" ] \
     && ! grep -q 'ai-dlc-fixture-durations' <<<"$(git -C "$T" status --porcelain 2>/dev/null)"; then p=0; fi
  chk "$tag" outside "$p" \
    "both cost records — the merged one and this run's .last — hold one line per fixture under .git/ and git itself cannot see either" \
    "a cost record is not where it must be (merged lines=$n_rec, .last lines=$n_last under .git/, root copies present=$([ -f "$T/ai-dlc-fixture-durations" ] && echo merged || echo no)/$([ -f "$T/ai-dlc-fixture-durations.last" ] && echo last || echo no)) — a record inside the tree is hashed by the key that decides whether the suite runs at all"
  unset SDO_TRACE
}

w_bad() { # w_bad <tag> <hook>   a record that makes no sense loses no fixture
  local tag="$1" h="$2" T="$WORK/$1-badrec" rc p
  seed "$T" "$h" || broken "seed failed"
  mkfx "$T" alpha 0; mkfx "$T" bravo 0; mkfx "$T" charlie 0
  printf 'this is not a record line\nghost 42\nalpha\n\n' > "$T/.git/ai-dlc-fixture-durations"
  rc="$(drive "$T" "$WORK/$tag-badrec.out")"
  p=1
  if [ "$rc" = 0 ] && grep -q 'ok    alpha' "$WORK/$tag-badrec.out" \
                   && grep -q 'ok    bravo' "$WORK/$tag-badrec.out" \
                   && grep -q 'ok    charlie' "$WORK/$tag-badrec.out" \
                   && ! grep -q 'produced a verdict' "$WORK/$tag-badrec.out"; then p=0; fi
  chk "$tag" badrec "$p" \
    "a malformed record naming a fixture that no longer exists still runs every live fixture" \
    "a malformed record cost the suite a fixture (rc=$rc) — the ordering step must never be able to shorten the run"
}

w_merge() { # w_merge <tag> <hook>   a run that dispatches a SUBSET keeps the costs of the rest
  local tag="$1" h="$2" T="$WORK/$1-merge" rc n1 kept mg_order mg_last p
  seed "$T" "$h" || broken "seed failed"
  export SDO_TRACE="$WORK/$tag-merge.trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 0; mkfx_trace "$T" zzz 0
  seed_mapped "$T" || broken "could not seed the read-set map for arm 4"
  rc="$(narrow_by_skip "$T" "$tag-merge2" "$SEEDREC")"
  case "$rc" in broken:*) world_broken "$tag" "arm 4 ${rc#broken:}" merge mergeorder; unset SDO_TRACE; return 0 ;; esac
  if [ "$rc" != 0 ]; then world_broken "$tag" "the narrowed run did not pass (rc=$rc)" merge mergeorder; unset SDO_TRACE; return 0; fi
  n1="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  case "$n1" in ''|*[!0-9]*) n1=0 ;; esac
  kept="$(awk '$1 == "aaa" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  p=1; [ "$n1" -eq 3 ] && [ "$kept" = 1 ] && p=0
  chk "$tag" merge "$p" \
    "a run that dispatched 2 of 3 units left the third's cost in the record UNCHANGED at its seeded 1 — the record MERGES, and a replace here loses every skipped unit's cost" \
    "a narrowed run cut the record to $n1 line(s) and aaa's cost is '${kept:-gone}' rather than the seeded 1 — a replace throws away exactly what the read-set skip decided not to re-run, and an unknown cost sorts FIRST"
  # mmm AND zzz ARE SEEDED AT 5 HERE, NOT SLEPT TO A COST: only aaa's merged row is under test, and a 5
  # beside its 1 cannot tie, so POSITION is decided by the sort on value.
  awk '$1 == "mmm" || $1 == "zzz" { print $1, 5; next } { print }' "$T/.git/ai-dlc-fixture-durations" > "$WORK/$tag-merge.rec" \
    && cp "$WORK/$tag-merge.rec" "$T/.git/ai-dlc-fixture-durations" || broken "could not re-seed mmm/zzz in the merged record"
  : > "$SDO_TRACE"
  rc="$(drive1 "$T" "$WORK/$tag-merge3.out")"
  mg_order="$(tr '\n' ' ' < "$SDO_TRACE")"
  mg_last="$(tail -1 "$SDO_TRACE")"
  p=1; [ "$rc" = 0 ] && [ "$mg_last" = aaa ] && p=0
  chk "$tag" mergeorder "$p" \
    "after the narrowed run the unit whose cost was PRESERVED sorts last on its value (order '$mg_order') — the preserved cost is the one being sorted on" \
    "the run after a narrowed one dispatched '$mg_order', ending on '$mg_last' rather than aaa — a cost lost to a narrowed run comes back as UNKNOWN, which sorts first and puts the poles last"
  unset SDO_TRACE
}

w_prune() { # w_prune <tag> <hook>   a row whose fixture DIRECTORY IS GONE is pruned by the merge
  local tag="$1" h="$2" T="$WORK/$1-prune" rc pr_gone pr_aaa pr_n p
  seed "$T" "$h" || broken "seed failed"
  export SDO_TRACE="$WORK/$tag-prune.trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 0; mkfx_trace "$T" zzz 0
  mkdir -p "$T/tests/fixtures/dead" && : > "$T/tests/fixtures/dead/notes.txt" || broken "could not seed the run.sh-less dir"
  seed_mapped "$T" || broken "could not seed the read-set map for arm 4c"
  printf 'aaa 1\nmmm 5\nzzz 9\ngone 777\ndead 555\n' > "$WORK/prune.seed" || broken "could not write the arm 4c seed"
  rc="$(narrow_by_skip "$T" "$tag-prune" "$WORK/prune.seed")"
  case "$rc" in broken:*) world_broken "$tag" "arm 4c ${rc#broken:}" prune; unset SDO_TRACE; return 0 ;; esac
  pr_gone="$(awk '$1 == "gone" || $1 == "dead"' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  pr_aaa="$(awk '$1 == "aaa" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  pr_n="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)" || pr_n=0
  p=1; [ "$rc" = 0 ] && [ -z "$pr_gone" ] && [ "$pr_aaa" = 1 ] && [ "$pr_n" -eq 3 ] && p=0
  chk "$tag" prune "$p" \
    "a green narrowed run drops the rows for a deleted dir and a run.sh-less dir and keeps the undispatched live unit at its seeded 1 (3 rows) — the prune keys on the disk, not on the dispatch list" \
    "after a green narrowed run the record holds $pr_n row(s), aaa='${pr_aaa:-gone}', dead rows '$(printf '%s' "$pr_gone" | tr '\n' ',')' (rc=$rc) — a row with no run.sh on disk survives and names a dead pole, or a skipped live unit lost its cost"
  unset SDO_TRACE
}

w_red() { # w_red <tag> <hook>   a RED pool leaves the record exactly as it found it
  local tag="$1" h="$2" T="$WORK/$1-red" rc g_good p
  seed "$T" "$h" || broken "seed failed"
  mkfx "$T" good 0; mkfx "$T" sick 1
  printf 'good 900\nsick 900\n' > "$T/.git/ai-dlc-fixture-durations" || broken "could not seed the red-run record"
  cp "$T/.git/ai-dlc-fixture-durations" "$WORK/$tag-red.before" || broken "could not keep the red-run record's before copy"
  rc="$(drive "$T" "$WORK/$tag-red.out")"
  p=1
  if [ "$rc" != 0 ] && grep -q 'FAIL  sick' "$WORK/$tag-red.out" && grep -q 'ok    good' "$WORK/$tag-red.out" \
     && cmp -s "$WORK/$tag-red.before" "$T/.git/ai-dlc-fixture-durations"; then p=0; fi
  chk "$tag" red "$p" \
    "a pool red on one unit leaves the durations record byte-identical, the ok unit it timed included" \
    "a red pool (rc=$rc) changed the durations record, or did not run as seeded: an ok unit of a red run is recorded at that run's load and becomes a phantom pole"
  mkfx "$T" sick 0
  rc="$(drive "$T" "$WORK/$tag-green.out")"
  g_good="$(awk '$1 == "good" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  p=1; [ "$rc" = 0 ] && [ -n "$g_good" ] && [ "$g_good" != 900 ] && p=0
  chk "$tag" green "$p" \
    "the same tree made green records this run's cost (good: 900 -> $g_good), so the red arm above is the gate and not a writer that never runs" \
    "the green control (rc=$rc) left good at '${g_good:-gone}', not this run's cost -- the red arm cannot tell a gated merge from no merge at all"
}

world_of() { case "$1" in order|glob|format|outside) echo lpt ;; badrec) echo bad ;; merge|mergeorder) echo merge ;; prune) echo prune ;; red|green) echo red ;; esac; }
run_world() { "w_$1" "$2" "$3"; }         # run_world <world> <tag> <hook>

# ---------------------------------- THE SHIPPED HOOK, EVERY ARM ----------------------------------
for _w in lpt bad merge prune red; do run_world "$_w" base "$HOOK"; done
B_ALL=1; [ "$fails" -eq 0 ] || B_ALL=0

# CONTROL, and it runs BEFORE any mutant verdict. An UNMUTATED COPY of the hook, driven through the same
# harness the mutants use, must be green on a one-fixture tree: if the harness itself were what fails,
# every mutant below would score a kill it had not earned.
cp "$HOOK" "$WORK/hook.ctl" || broken "could not copy the hook for the unmutated control"
T="$WORK/mctl"; seed "$T" "$WORK/hook.ctl" || broken "seed failed"
mkfx "$T" alpha 0
rc="$(drive "$T" "$WORK/mctl.out")"
if [ "$rc" = 0 ] && grep -q 'ok    alpha' "$WORK/mctl.out"; then
  ok "CONTROL unmutated-copy: a copy of the shipped hook is green on a one-fixture tree and dispatched alpha — the mutant harness runs the shipped behaviour"
else
  bad "CONTROL unmutated-copy is RED (rc=$rc) — no mutant verdict below is believable"
fi

# ================================================================== MUTANTS ========
# Each is a COPY of the hook with one arm removed, guarded by `cmp -s` so a sed that matched nothing
# cannot pass as a mutation. `mut` SETS `MUT` rather than printing it.
mut() {                        # mut <label> <sed-expr>  -> sets MUT, or returns 1
  local lbl="$1" expr="$2" m="$WORK/hook.$1"
  sed "$expr" "$HOOK" > "$m" || { bad "MUTANT $lbl: sed failed"; return 1; }
  if cmp -s "$HOOK" "$m"; then
    bad "MUTANT $lbl matched nothing (cmp -s guard) — this arm proves nothing"
    return 1
  fi
  MUT="$m"
}
# M1 dispatch reads the UNORDERED list; M2 the sort is broken outright (the fallback path); M3 the WRITER
# removed; M4 the MERGE removed (the old record is not read); M6 the PRUNE removed; M7 the prune keyed on a
# literal core/fixtures/ rather than FXROOT.
mut m1 's|< "\$out/\.order"|< "$out/list"|'
mut m2 's@| sort -k1,1nr@| sort-is-not-installed@'
mut m3 '/AI_DLC_FX_OUT\/\.dur\//d'
mut m4 's|\[ -s "\$DURATIONS_RECORD" \] && cat "\$DURATIONS_RECORD"|false|'
mut m6 '/while read -r k v; do \[ -f "\${FXROOT}\${k}\/run.sh" \]/d'
mut m7 's|\[ -f "\${FXROOT}\${k}/run.sh" \]|[ -f "core/fixtures/${k}/run.sh" ]|'
# M5 THE RUN-VERDICT GATE REMOVED FROM THE MERGE, and only from the merge. The `.last` publish opens with the
# same `if [ "$rc" -eq 0 ] && [ -s "$out/.durations" ]` text, so the edit is keyed on what separates them: the
# merge line ENDS at `then`, while `.last` continues `; then cp`. awk, because the replacement carries `&&`.
M5="$WORK/hook.m5"
M5_OLD='  if [ "$rc" -eq 0 ] && [ -s "$out/.durations" ]; then'
M5_NEW='  if [ -s "$out/.durations" ]; then'
MO="$M5_OLD" MN="$M5_NEW" awk '$0 == ENVIRON["MO"] { print ENVIRON["MN"]; next } { print }' "$HOOK" > "$M5" \
  || broken "could not write the M5 mutant"
n_m5="$(grep -c '^>' <<<"$(diff "$HOOK" "$M5")")" || n_m5=0
[ "$n_m5" -eq 1 ] || bad "MUTANT m5 changed $n_m5 line(s), not 1 -- the merge gate's anchor is not unique, so the mutant proves nothing"

# Deciding arm and measured-green twin per mutant: the MEASURED matrix is the `--matrix` rows.
DEC_m1=order;  TWIN_m1=glob
DEC_m2=order;  TWIN_m2=badrec
DEC_m3=format; TWIN_m3=badrec
DEC_m4=merge;  TWIN_m4=red
DEC_m5=red;    TWIN_m5=badrec
DEC_m6=prune;  TWIN_m6=badrec
DEC_m7=prune;  TWIN_m7=badrec
MUTANTS="m1 m2 m3 m4 m5 m6 m7"

score_mutant() { # score_mutant <name>
  local m="$1" dec twin w arm tripped="" worlds="" r hook="$WORK/hook.$1"
  eval "dec=\$DEC_$m; twin=\$TWIN_$m"
  if [ "$MATRIX" = 1 ]; then worlds="lpt bad merge prune red"; else worlds="$(world_of "$dec") $(world_of "$twin")"; fi
  for w in $(printf '%s\n' $worlds | awk '!s[$0]++'); do run_world "$w" "$m" "$hook"; done
  if [ "$MATRIX" = 1 ]; then
    for arm in $ALL_ARMS; do [ "$(getres "$m" "$arm")" = 1 ] && tripped="$tripped $arm"; done
    mx_row "$m" "${tripped# }" "$ALL_ARMS" "$dec" "$twin"
  fi
  if [ "$(getres "$m" "$dec")" = 1 ]; then
    mutant_killed "$B_ALL" "$m" "KILL $m: the deciding arm $dec fails under the mutant ($(mutant_what "$m"))"
  else
    bad "KILL $m: the deciding arm $dec still PASSES under the mutant — the arm cannot see the defect it is recorded as deciding"
  fi
  if [ "$(getres "$m" "$twin")" = 0 ]; then
    ok "TWIN $m: the twin arm $twin stays green under the mutant, as the measured matrix records — the kill is confined to $dec"
  else
    bad "TWIN $m: the twin arm $twin FAILED under the mutant, but the measured matrix has it green — the co-tripping changed"
  fi
}
mutant_what() { case "$1" in
  m1) echo "dispatch reading the unordered list: the same record produces glob order, so the dispatch source is what arm 1 measures" ;;
  m2) echo "the sort broken: the suite still runs COMPLETE, in glob order — the fallback loses speed and nothing else" ;;
  m3) echo "the workers not recording their cost: neither the merged record nor .last is written" ;;
  m4) echo "the old record not read: the same narrowed run cuts it to 2 lines and loses aaa's seeded cost" ;;
  m5) echo "the run-verdict gate removed from the merge: the same red pool rewrites the record" ;;
  m6) echo "the prune removed: the deleted dir's and the run.sh-less dir's rows survive the merge" ;;
  m7) echo "the prune keyed on a literal core/fixtures/: on the consumer layout the record is frozen, not the 3-row pruned one" ;;
esac; }
for _m in $MUTANTS; do score_mutant "$_m"; done

# --- 11. A PLAIN RUN EXECUTES NO MATRIX-ONLY CELL, AND --matrix EXECUTES ALL OF THEM ---------------
if [ "$MATRIX" = 1 ]; then
  if [ "$MX_ROWS" -eq 7 ]; then ok "--matrix printed one MATRIX row per mutant ($MX_ROWS of 7)"
  else bad "--matrix printed $MX_ROWS MATRIX rows, want 7"; fi
else
  if [ "$MX_ROWS" -eq 0 ]; then ok "a plain run printed no MATRIX row ($MX_ROWS), so the matrix-only cells did not run"
  else bad "a plain run printed $MX_ROWS MATRIX rows -- the matrix path is running on every push"; fi
fi

# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are emitted from inside a
# conditional: an assertion that never executed prints nothing, and a short green report reads exactly
# like a complete one. 10 shipped-hook arms + 1 control + 7 kills + 7 twins + 1 plain-run arm.
EXPECTED_ASSERTIONS=26
if [ "$asserts" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf '  FAIL  %s assertions ran, %s expected — an arm did not execute, and a short green report reads exactly like a complete one\n' \
    "$asserts" "$EXPECTED_ASSERTIONS"
  fails=$((fails+1))
fi

if [ "$fails" -ne 0 ]; then
  printf '  suite-dispatch-order: %s FAILED\n' "$fails"
  exit 1
fi
printf '  suite-dispatch-order: %s assertions, all green\n' "$asserts"
