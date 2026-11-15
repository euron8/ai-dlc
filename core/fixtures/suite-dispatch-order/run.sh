#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
set -uo pipefail

# HERMETICITY. This fixture drives a hook that reads AI_DLC_FIXTURE_JOBS, and two arms
# below set it explicitly. An operator carrying a value in their environment would
# otherwise fail an arm against a hook behaving exactly as configured.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

for _lib in report.sh world.sh hook-drive.sh; do [ -f "$HERE/../lib/$_lib" ] || { echo "FIXTURE ERROR: lib/$_lib not found beside $HERE" >&2; exit 2; }; done
. "$HERE/../lib/report.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/report.sh"
. "$HERE/../lib/world.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/world.sh"
. "$HERE/../lib/hook-drive.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/hook-drive.sh"
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
  world_git init -q "$t" >/dev/null 2>&1 || return 1
  git -C "$t" config user.email f@x >/dev/null 2>&1
  git -C "$t" config user.name  f   >/dev/null 2>&1
  return 0
}

mkfx() {                       # mkfx <tree> <name> <exitcode>
  mkdir -p "$1/tests/fixtures/$2"
  printf '#!/usr/bin/env bash\nexit %s\n' "$3" > "$1/tests/fixtures/$2/run.sh"
}

# A fixture that RECORDS THE MOMENT IT WAS DISPATCHED. The trace is how a run's dispatch order is
# read back. It sleeps for nothing (BL-868): every cost an arm sorts on is SEEDED into the record,
# never slept to, so no verdict reads a wall clock -- the sleep this replaced was always `sleep 0`.
mkfx_trace() {                 # mkfx_trace <tree> <name>
  mkdir -p "$1/tests/fixtures/$2"
  cat > "$1/tests/fixtures/$2/run.sh" <<FX
#!/usr/bin/env bash
printf '%s\n' '$2' >> "\$SDO_TRACE"
exit 0
FX
}

# NO_SKIP: every drive here re-runs one tree and expects the whole suite dispatched. Without it the
# per-fixture key records the first green drive writes would skip every unit on the next one.
drive() {                      # drive <tree> <outfile>  -> rc
  hook_drive "$1" "$2" AI_DLC_FIXTURE_NO_SKIP=1
}

# THE READ-SET SKIP ON, for the arms whose subject is a unit the skip did not dispatch while its
# directory stayed on disk. The verdict store is a sibling of the tree, never `$HOME/.cache`.
drive_skip() {                 # drive_skip <tree> <outfile>  -> rc
  hook_drive "$1" "$2" AI_DLC_VERDICT_STORE="$1.vs"
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
  hook_drive "$1" "$2" AI_DLC_FIXTURE_JOBS=1 AI_DLC_FIXTURE_NO_SKIP=1
}

SEEDREC="$WORK/seed.durations"
printf 'aaa 1\nmmm 5\nzzz 9\n' > "$SEEDREC" || broken "could not write the seeded durations record"
# THE ORDER ARM'S OWN SEED, with red-run rows. mmm has ONLY a red row, so it is ordered by it (5) and not
# as unknown (999999, which would put it first); aaa has a clean 1 AND a red 99, so the clean row wins
# (a red row preferred would put aaa first). One drive tells all three apart.
LPTREC="$WORK/lpt.durations"
printf 'aaa 1\naaa@red 99\nmmm@red 5\nzzz 9\n' > "$LPTREC" || broken "could not write the order arm's seeded record"

# --------------------------------- THE WORLDS AND THE ARMS ---------------------------------------
# Every arm is a verdict on one seeded world, driven through a HOOK PATH given as an argument; the
# world function records each arm's result (0 = the arm passed, 1 = the arm failed) and emits the
# ok/FAIL line. The arms are:
#   order glob format outside   (world lpt)      badrec (world bad)     merge mergeorder (world merge)
#   prune (world prune)         red redlast green (world red)
RES="$WORK/res"; mkdir -p "$RES" || broken "could not create the result dir"
setres() { printf '%s\n' "$3" > "$RES/$1.$2"; }                  # setres <tag> <arm> <0|1>
getres() { if [ -f "$RES/$1.$2" ]; then cat "$RES/$1.$2"; else echo NA; fi; }
# chk <tag> <arm> <pass:0|1> <ok message> <fail message>
chk() {
  setres "$1" "$2" "$3"
  [ "$1" = base ] || return 0
  if [ "$3" = 0 ]; then ok "$4"; else bad "$5"; fi
}
# A world that cannot be built is FIXTURE BROKEN.
world_broken() { # world_broken <tag> <why> <arm>...
  broken "$2"
}

w_lpt() { # w_lpt <tag> <hook>
  local tag="$1" h="$2" T="$WORK/$1-lpt" rc order ctl_order bound nearmiss n_rec n_last p REC
  seed "$T" "$h" || broken "seed failed"
  export SDO_TRACE="$T/trace"
  mkfx_trace "$T" aaa; mkfx_trace "$T" mmm; mkfx_trace "$T" zzz
  cp "$LPTREC" "$T/.git/ai-dlc-fixture-durations" || broken "could not install the seeded durations record"
  : > "$SDO_TRACE"
  rc="$(drive1 "$T" "$WORK/$tag-lpt2.out")"
  order="$(tr '\n' ' ' < "$SDO_TRACE")"
  p=1; [ "$rc" = 0 ] && [ "$order" = "zzz mmm aaa " ] && p=0
  chk "$tag" order "$p" \
    "a record costing aaa=1 (aaa@red=99) mmm@red=5 zzz=9 dispatches longest-first (zzz mmm aaa) — a clean row wins over a red one, a red-only unit is ordered by its red cost, with no stopwatch in the assertion" \
    "the seeded record did not dispatch longest-first (rc=$rc, got '$order', glob order is 'aaa mmm zzz'; 'mmm zzz aaa' = a red-only unit read as unknown, 'aaa zzz mmm' = a red row preferred over a clean one) — a pool's makespan is decided by when its longest unit starts"
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
  mkfx_trace "$T" aaa; mkfx_trace "$T" mmm; mkfx_trace "$T" zzz
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
  mkfx_trace "$T" aaa; mkfx_trace "$T" mmm; mkfx_trace "$T" zzz
  mkdir -p "$T/tests/fixtures/dead" && : > "$T/tests/fixtures/dead/notes.txt" || broken "could not seed the run.sh-less dir"
  seed_mapped "$T" || broken "could not seed the read-set map for arm 4c"
  # Red-run rows are pruned on the same test with `@red` stripped, `@consumer@red` included: aaa's two
  # red rows survive (its run.sh exists), the gone/dead ones go.
  printf 'aaa 1\naaa@consumer@red 2\naaa@red 4\nmmm 5\nzzz 9\ngone 777\ngone@red 7\ngone@consumer@red 8\ndead 555\ndead@red 6\n' > "$WORK/prune.seed" || broken "could not write the arm 4c seed"
  rc="$(narrow_by_skip "$T" "$tag-prune" "$WORK/prune.seed")"
  case "$rc" in broken:*) world_broken "$tag" "arm 4c ${rc#broken:}" prune; unset SDO_TRACE; return 0 ;; esac
  pr_gone="$(awk '$1 ~ /^(gone|dead)(@|$)/' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  pr_aaa="$(awk '$1 == "aaa" || $1 == "aaa@red" || $1 == "aaa@consumer@red" { print $1 "=" $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
  pr_n="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)" || pr_n=0
  p=1; [ "$rc" = 0 ] && [ -z "$pr_gone" ] && [ "$pr_aaa" = "aaa=1 aaa@consumer@red=2 aaa@red=4 " ] && [ "$pr_n" -eq 5 ] && p=0
  chk "$tag" prune "$p" \
    "a green narrowed run drops the rows, red ones included, for a deleted dir and a run.sh-less dir and keeps the undispatched live unit's rows (aaa=1, aaa@red=4, aaa@consumer@red=2; 5 rows) — the prune keys on the disk, not on the dispatch list" \
    "after a green narrowed run the record holds $pr_n row(s), aaa rows '${pr_aaa:-gone}', dead rows '$(printf '%s' "$pr_gone" | tr '\n' ',')' (rc=$rc) — a row with no run.sh on disk survives and names a dead pole, or a skipped live unit lost its cost"
  unset SDO_TRACE
}

w_red() { # w_red <tag> <hook>   a RED pool records every verdict-giving unit under <unit>@red, never over a clean row
  local tag="$1" h="$2" T="$WORK/$1-red" rc g_good g_red p l_n l_names r_clean r_red r_n
  seed "$T" "$h" || broken "seed failed"
  mkfx "$T" good 0; mkfx "$T" sick 1
  printf 'good 900\nsick 900\n' > "$T/.git/ai-dlc-fixture-durations" || broken "could not seed the red-run record"
  rc="$(drive "$T" "$WORK/$tag-red.out")"
  r_clean="$(awk '$1 == "good" || $1 == "sick" { print $1 "=" $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
  r_red="$(awk '($1 == "good@red" || $1 == "sick@red") && $2 ~ /^[0-9]+$/ && $2 != 900 { print $1 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
  r_n="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)" || r_n=0
  p=1
  if [ "$rc" != 0 ] && grep -q 'FAIL  sick' "$WORK/$tag-red.out" && grep -q 'ok    good' "$WORK/$tag-red.out" \
     && [ "$r_clean" = "good=900 sick=900 " ] && [ "$r_red" = "good@red sick@red " ] && [ "$r_n" -eq 4 ]; then p=0; fi
  chk "$tag" red "$p" \
    "a pool red on one unit records both units it timed, the ok one and the failing one, as good@red and sick@red at this run's cost, and leaves the clean rows at their seeded 900 (4 rows)" \
    "a red pool (rc=$rc) left clean rows '$r_clean' (want good=900 sick=900), red rows '$r_red' (want good@red sick@red at this run's cost), $r_n row(s) (want 4): a red run's timings are thrown away, or an ok unit of a red run overwrote a clean row and becomes a phantom pole"
  # `.last` is this run's own measurement and is published on a red run too: one line per unit the pool timed.
  l_n="$(grep -c . "$T/.git/ai-dlc-fixture-durations.last" 2>/dev/null)" || l_n=0
  l_names="$(awk 'NF == 2 && $2 ~ /^[0-9]+$/ { print $1 }' "$T/.git/ai-dlc-fixture-durations.last" 2>/dev/null | sort | tr '\n' ' ')"
  p=1; [ "$l_n" -eq 2 ] && [ "$l_names" = "good sick " ] && p=0
  chk "$tag" redlast "$p" \
    "the same red pool published .last with one line per timed unit (good and sick), so the pole line has a run to read after a red push" \
    ".last holds $l_n line(s) (units '$l_names') after a red pool, want good and sick — a red push prints (no suite run, no pole)"
  mkfx "$T" sick 0
  rc="$(drive "$T" "$WORK/$tag-green.out")"
  g_good="$(awk '$1 == "good" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  g_red="$(awk '$1 == "good@red" || $1 == "sick@red" { print $1 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
  p=1; [ "$rc" = 0 ] && [ -n "$g_good" ] && [ "$g_good" != 900 ] && [ "$g_red" = "good@red sick@red " ] && p=0
  chk "$tag" green "$p" \
    "the same tree made green writes this run's cost to the CLEAN row (good: 900 -> $g_good) and keeps the red rows, so the red arm above is the suffix and not a writer that never runs" \
    "the green control (rc=$rc) left good at '${g_good:-gone}' and red rows '$g_red' (want good@red sick@red kept) -- the red arm cannot tell a suffixed merge from no clean merge at all"
}

run_world() { "w_$1" "$2" "$3"; }         # run_world <world> <tag> <hook>

# ---------------------------------- THE SHIPPED HOOK, EVERY ARM ----------------------------------
for _w in lpt bad merge prune red; do run_world "$_w" base "$HOOK"; done

# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are emitted from inside a
# conditional: an assertion that never executed prints nothing, and a short green report reads exactly
# like a complete one. 11 shipped-hook arms.
report_end suite-dispatch-order 11
