#!/usr/bin/env bash
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

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "suite-dispatch-order: FIXTURE BROKEN" >&2; exit 2; }

echo "suite-dispatch-order:"

# Both layouts, named rather than derived from one another (I33).
HOOK=""
for cand in "$HERE/../../git-hooks/pre-push" "$HERE/../../../.githooks/pre-push"; do
  [ -f "$cand" ] && { HOOK="$cand"; break; }
done
[ -n "$HOOK" ] || broken "cannot locate the pre-push hook in either layout (core/git-hooks/pre-push or .githooks/pre-push) from $HERE"

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

drive() {                      # drive <tree> <outfile>  -> rc
  ( cd "$1" && bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}

# ONE AT A TIME, which is what makes dispatch order observable at all. Above width 1 the
# workers overlap and the trace records a race; at width 1 execution order IS dispatch
# order, so the trace reads the schedule directly rather than inferring it from a wall
# clock — the timing-sensitive assertion §7's gate warns about.
drive1() {                     # drive1 <tree> <outfile>  -> rc
  ( cd "$1" && AI_DLC_FIXTURE_JOBS=1 bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}

# --------------------------- 1. dispatch is LONGEST-FIRST, off a real record --------
# THE TWO RUNS ARE THE WHOLE POINT, and seeding the record by hand would have made this
# arm worthless. The first run WRITES the record; the second READS it. The format is
# therefore bound end to end by the runner itself, and a hook whose writer and reader
# disagreed could not pass here. Hand-written seed data would restate the format instead
# of testing it, and the mechanism would be free to degrade silently to glob order — a
# check that cannot fire, with a stopwatch attached.
#
# The costs are 0, 1 and 3 seconds against a whole-second record, so the two orders are
# exact reverses and a full second of scheduling noise on the middle unit still cannot
# reorder them.
T="$WORK/lpt"; seed "$T" "$HOOK" || broken "seed failed"
export SDO_TRACE="$T/trace"
mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 1; mkfx_trace "$T" zzz 3
: > "$SDO_TRACE"
rc="$(drive "$T" "$WORK/lpt1.out")"
[ "$rc" = 0 ] || broken "the run that writes the durations record did not pass (rc=$rc); every arm here reads what it wrote"
: > "$SDO_TRACE"
rc="$(drive1 "$T" "$WORK/lpt2.out")"
lpt_order="$(tr '\n' ' ' < "$SDO_TRACE")"
if [ "$rc" = 0 ] && [ "$lpt_order" = "zzz mmm aaa " ]; then
  ok "the second run dispatches longest-first (zzz mmm aaa) off the costs the FIRST run recorded"
else
  bad "the second run did not dispatch longest-first (rc=$rc, got '$lpt_order', glob order is 'aaa mmm zzz') — a pool's makespan is decided by when its longest unit starts"
fi

# CONTROL. Same tree, same fixtures, same width — only the record removed. Without it
# the order must fall back to glob order, which is what says the RECORD reordered the
# dispatch rather than anything else about this tree.
rm -f "$T/.git/ai-dlc-fixture-durations"
: > "$SDO_TRACE"
rc="$(drive1 "$T" "$WORK/lpt3.out")"
ctl_order="$(tr '\n' ' ' < "$SDO_TRACE")"
if [ "$rc" = 0 ] && [ "$ctl_order" = "aaa mmm zzz " ]; then
  ok "with the record deleted the SAME tree dispatches in glob order — the record is what reorders it, and a first run is correct without one"
else
  bad "removing the record did not restore glob order (rc=$rc, got '$ctl_order') — arm 1 is not measuring the record"
fi

# ------------------------ 2. the record is written OUTSIDE the working tree ---------
# I55 arm 4's prohibition, observed rather than asserted about. A cost record inside the
# tree would be hashed by the distribution's own suite content key, so writing it would
# move the key it is trying to match and the skip could never hit again. For a consumer
# the same file would appear in every `git status` they ever ran.
: > "$SDO_TRACE"
rc="$(drive "$T" "$WORK/lpt4.out")"
n_rec="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
case "$n_rec" in ''|*[!0-9]*) n_rec=0 ;; esac
if [ "$n_rec" -eq 3 ] && [ ! -f "$T/ai-dlc-fixture-durations" ] \
   && ! grep -q 'ai-dlc-fixture-durations' <<<"$(git -C "$T" status --porcelain 2>/dev/null)"; then
  ok "the durations record holds one line per fixture under .git/ and git itself cannot see it"
else
  bad "the durations record is not where it must be (lines=$n_rec under .git/, root copy present=$([ -f "$T/ai-dlc-fixture-durations" ] && echo yes || echo no)) — a record inside the tree is hashed by the key that decides whether the suite runs at all"
fi
unset SDO_TRACE

# ------------------- 3. a record that makes no sense loses no fixture ---------------
# Garbage lines, a one-field line, and an entry for a fixture that no longer exists. The
# failure this refuses is the quiet one: an ordering step that drops a unit reads exactly
# like an ordering step that is fast.
T="$WORK/badrec"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" alpha 0; mkfx "$T" bravo 0; mkfx "$T" charlie 0
printf 'this is not a record line\nghost 42\nalpha\n\n' > "$T/.git/ai-dlc-fixture-durations"
rc="$(drive "$T" "$WORK/badrec.out")"
if [ "$rc" = 0 ] && grep -q 'ok    alpha' "$WORK/badrec.out" \
                 && grep -q 'ok    bravo' "$WORK/badrec.out" \
                 && grep -q 'ok    charlie' "$WORK/badrec.out" \
                 && ! grep -q 'produced a verdict' "$WORK/badrec.out"; then
  ok "a malformed record naming a fixture that no longer exists still runs every live fixture"
else
  bad "a malformed record cost the suite a fixture (rc=$rc) — the ordering step must never be able to shorten the run"
fi

# ================================================================== MUTANTS ========
# Each is a COPY of the hook with one arm removed, guarded by `cmp -s` so a sed that
# matched nothing cannot pass as a mutation. `mut` SETS `MUT` rather than printing it:
# called as `M="$(mut ...)"` the helper runs inside a command substitution, so its
# failure message goes into the variable and its `asserts` increment happens in a
# subshell that then exits — a mutation that matched nothing would say NOTHING. That is
# v0.229.0's finding, made in the fixture this one was split out of.
mut() {                        # mut <label> <sed-expr>  -> sets MUT, or returns 1
  local lbl="$1" expr="$2" m="$WORK/hook.$1"
  sed "$expr" "$HOOK" > "$m" || { bad "MUTANT $lbl: sed failed"; return 1; }
  if cmp -s "$HOOK" "$m"; then
    bad "MUTANT $lbl matched nothing (cmp -s guard) — this arm proves nothing"
    return 1
  fi
  MUT="$m"
}

# UNMUTATED CONTROL, and it runs FIRST. The hook is driven six times above; if the
# harness itself were what fails, every mutant below would go green and score a kill it
# had not earned.
T="$WORK/mctl"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" alpha 0
rc="$(drive "$T" "$WORK/mctl.out")"
[ "$rc" = 0 ] && ok "mutant-battery control: the unmutated hook is green on a one-fixture tree" \
              || bad "mutant-battery control is RED (rc=$rc) — no mutant verdict below is believable"

# M1 — dispatch reads the UNORDERED list. The reordering still computes; nothing uses it.
# THE RECORD THESE THREE COPY IS A REAL ONE, taken from arm 1's own first run. Writing
# one here would restate the format under test, and a mutant that restates the thing it
# tests proves the restatement.
if mut m1 's|< "\$out/\.order"|< "$out/list"|'; then M="$MUT"
  T="$WORK/m1"; seed "$T" "$M" || broken "seed failed"
  export SDO_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 1; mkfx_trace "$T" zzz 3
  cp "$WORK/lpt/.git/ai-dlc-fixture-durations" "$T/.git/ai-dlc-fixture-durations" \
    || broken "could not carry arm 1's real durations record into the M1 tree"
  : > "$SDO_TRACE"
  rc="$(drive1 "$T" "$WORK/m1.out")"
  m1_order="$(tr '\n' ' ' < "$SDO_TRACE")"
  [ "$m1_order" = "aaa mmm zzz " ] \
    && ok "M1 with dispatch reading the unordered list the same record produces glob order — the dispatch source is what arm 1 measures" \
    || bad "M1 dispatch still reordered (got '$m1_order') — arm 1 is not measuring which file the pool is fed"
  unset SDO_TRACE
fi

# M2 — THE FALLBACK PATH, driven rather than argued. The plan's §6c-12 required that the
# path taken when the ordering is unavailable be shown to produce a CORRECT suite and not
# merely a slower one, so the sort is broken outright and the whole suite is read back.
# The count guard then rejects the short reordering and the glob list stands.
if mut m2 's@| sort -k1,1nr@| sort-is-not-installed@'; then M="$MUT"
  T="$WORK/m2"; seed "$T" "$M" || broken "seed failed"
  export SDO_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 1; mkfx_trace "$T" zzz 3
  cp "$WORK/lpt/.git/ai-dlc-fixture-durations" "$T/.git/ai-dlc-fixture-durations" \
    || broken "could not carry arm 1's real durations record into the M2 tree"
  : > "$SDO_TRACE"
  rc="$(drive1 "$T" "$WORK/m2.out")"
  m2_order="$(tr '\n' ' ' < "$SDO_TRACE")"
  if [ "$rc" = 0 ] && [ "$m2_order" = "aaa mmm zzz " ] \
     && grep -q 'ok    aaa' "$WORK/m2.out" && grep -q 'ok    mmm' "$WORK/m2.out" \
     && grep -q 'ok    zzz' "$WORK/m2.out" && ! grep -q 'produced a verdict' "$WORK/m2.out"; then
    ok "M2 with the ordering broken the suite runs COMPLETE in glob order — the fallback loses speed and nothing else"
  else
    bad "M2 a broken ordering did not fall back cleanly (rc=$rc, order '$m2_order') — an unavailable schedule must cost time, never coverage"
  fi
  unset SDO_TRACE
fi

# M3 — the WRITER removed, reader intact. Without a run recording what it cost there is
# nothing for the next run to sort on, so the order stays glob. This is the half M1
# cannot reach: M1 proves the reader is wired to the pool, M3 proves the record it reads
# is produced by the workers rather than by anything else in the tree.
if mut m3 '/AI_DLC_FX_OUT\/\.dur\//d'; then M="$MUT"
  T="$WORK/m3"; seed "$T" "$M" || broken "seed failed"
  export SDO_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 1; mkfx_trace "$T" zzz 3
  : > "$SDO_TRACE"
  rc="$(drive "$T" "$WORK/m3a.out")"
  : > "$SDO_TRACE"
  rc="$(drive1 "$T" "$WORK/m3.out")"
  m3_order="$(tr '\n' ' ' < "$SDO_TRACE")"
  if [ "$rc" = 0 ] && [ "$m3_order" = "aaa mmm zzz " ] \
     && [ ! -s "$T/.git/ai-dlc-fixture-durations" ]; then
    ok "M3 with the workers not recording their cost no record is written and the second run stays in glob order"
  else
    bad "M3 an order appeared without the workers recording anything (rc=$rc, order '$m3_order') — the record arm 1 reads is not the one the pool writes"
  fi
  unset SDO_TRACE
fi

# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are emitted
# from inside a conditional: an assertion that never executed prints nothing, and a short
# green report reads exactly like a complete one.
EXPECTED_ASSERTIONS=8
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
