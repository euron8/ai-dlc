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

# --------------------------- 1. dispatch is LONGEST-FIRST, off a SEEDED record ------
# THE COSTS ARE SEEDED, AND THAT IS THIS ARM'S SUBJECT RATHER THAN A CONCESSION MADE TO
# GET IT GREEN. It used to give the three units real sleeps, run the pool once to record
# what they cost, and assert the second run's order against a hardcoded triple. That made
# the machine's scheduler the judge: a worker records `$SECONDS` off its OWN shell
# (`core/git-hooks/pre-push:541` — the hook this fixture RESOLVES first, whose numbering
# is not `.githooks/pre-push`'s), so under a loaded 16-way pool a `sleep 0` unit can
# record 1 or 2 and outrank the `sleep 1` unit, and the arm reads `zzz aaa mmm` on a tree
# with nothing wrong with it. Measured across pooled gate runs on trees that could not
# reach dispatch ordering at all: mostly `ok`, intermittently `FAIL`. A unit that fails
# intermittently is the shape that gets re-run until green, and a re-run-until-green unit
# certifies nothing.
# (`docs/backlog.md`, `BL-008`.)
#
# A seeded record measures the ORDERING RULE, which is the only thing this arm ever
# claimed to measure. What the two-run shape bound INCIDENTALLY — that the writer's record
# format is the one the reader parses — is not lost with it: arm 1b asserts that directly,
# off a real run, so the determinism was not bought by trading the property away.
#
# The costs are 1, 5 and 9 against a whole-number record, so the sort key is unambiguous,
# the expected order is the exact reverse of glob order, and no unknown-cost fallback
# (999999, `core/git-hooks/pre-push:519`) is involved.
SEEDREC="$WORK/seed.durations"
printf 'aaa 1\nmmm 5\nzzz 9\n' > "$SEEDREC" || broken "could not write the seeded durations record"

T="$WORK/lpt"; seed "$T" "$HOOK" || broken "seed failed"
export SDO_TRACE="$T/trace"
mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 0; mkfx_trace "$T" zzz 0
cp "$SEEDREC" "$T/.git/ai-dlc-fixture-durations" || broken "could not install the seeded durations record"
: > "$SDO_TRACE"
rc="$(drive1 "$T" "$WORK/lpt2.out")"
lpt_order="$(tr '\n' ' ' < "$SDO_TRACE")"
if [ "$rc" = 0 ] && [ "$lpt_order" = "zzz mmm aaa " ]; then
  ok "a record costing aaa=1 mmm=5 zzz=9 dispatches longest-first (zzz mmm aaa) — the ORDERING RULE, with no stopwatch in the assertion"
else
  bad "the seeded record did not dispatch longest-first (rc=$rc, got '$lpt_order', glob order is 'aaa mmm zzz') — a pool's makespan is decided by when its longest unit starts"
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

# ------------------ 1b. the WRITER's format is the one the READER parses -------------
# The property arm 1's old two-run shape held incidentally, asserted directly and with no
# timing claim attached. The control run just above dispatched every unit and WROTE this
# record; the predicate below is the hook's own reader (`core/git-hooks/pre-push:517` —
# `NR==FNR { if (NF == 2) prev[$1] = $2 }`) joined to the basename it derives from the
# dispatch list at `:518`.
#
# THIS IS A JOIN AND NOT A RESTATEMENT, which is why it earns its own arm. A writer that
# changed its field count, its separator, or the name it keys on would leave the reader
# indexing on nothing at all: every lookup would miss, every unit would take the
# unknown-cost slot, the reorder would degrade silently to glob order — and every ORDER
# assertion in this file would still pass, because arm 1 seeds its own record and the
# control expects glob order anyway. Nothing else here can see that break.
REC="$T/.git/ai-dlc-fixture-durations"
bound="$(awk 'NF == 2 && $2 ~ /^[0-9]+$/ { print $1 }' "$REC" 2>/dev/null | sort | tr '\n' ' ')"
# BOTH DIRECTIONS IN THE SAME INVOCATION. Without the near-miss leg, "every line parsed"
# is a statement about a predicate that accepts everything, not about what the writer emits.
nearmiss="$(awk 'NF == 2 && $2 ~ /^[0-9]+$/ { print $1 }' <<<'aaa' | tr '\n' ' ')"
if [ "$bound" = "aaa mmm zzz " ] && [ -z "$nearmiss" ]; then
  ok "every line the pool WROTE is accepted by the reader's own NF==2 parse and keys on the basename the reader derives, while a one-field near-miss is rejected"
else
  bad "the written record does not join to the reader's parse (accepted '$bound', expected 'aaa mmm zzz '; near-miss yielded '$nearmiss') — a writer/reader format split makes every cost lookup miss and degrades the reorder to glob order in silence"
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

# ------------- 4. a run that dispatches a SUBSET keeps the costs of the rest --------
# THE RECORD IS MERGED, NOT REPLACED, and this is the arm that says so. Only a
# DISPATCHED unit leaves a file in "$out/.dur/", and the read-set skip narrows the
# dispatch list before the pool is fed — so a whole-file replace deleted the cost of
# every unit the skip had decided not to run. Those units then re-entered the next run
# at the unknown-cost slot, which sorts FIRST, putting the real poles LAST.
#
# NARROWED BY TAKING A FIXTURE AWAY rather than by seeding the skip's own state. The
# code path is identical — a unit that is not dispatched writes no `.dur` file, and
# nothing downstream can tell why — and this way the arm does not depend on the read-set
# machinery, which needs a map and a verified-state record that a seeded tree does not
# have. The unit withheld is the CHEAPEST one deliberately: losing the cost of the
# cheapest unit is what flips the dispatch order, because an unknown cost sorts first.
#
# AAA'S PRESERVED COST IS SEEDED AT 1 AND IS NEVER MEASURED HERE, because aaa is withheld
# from the only run that dispatches anything. mmm and zzz sleep 2, and `$SECONDS` is
# integer elapsed, so neither can record less than 2 and pool contention only raises it.
# `aaa < mmm, zzz` therefore holds BY CONSTRUCTION rather than by luck. The old form
# asserted the whole triple `zzz mmm aaa` against three MEASURED costs and let the
# scheduler decide the verdict — `BL-008`, and the same defect as arm 1's.
T="$WORK/merge"; seed "$T" "$HOOK" || broken "seed failed"
export SDO_TRACE="$T/trace"
mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 2; mkfx_trace "$T" zzz 2
cp "$SEEDREC" "$T/.git/ai-dlc-fixture-durations" || broken "could not install the seeded durations record"

mv "$T/tests/fixtures/aaa" "$WORK/aaa.withheld" || broken "could not withhold a fixture"
: > "$SDO_TRACE"
rc="$(drive "$T" "$WORK/merge2.out")"
[ "$rc" = 0 ] || broken "the narrowed run did not pass (rc=$rc)"
n1="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
case "$n1" in ''|*[!0-9]*) n1=0 ;; esac
kept="$(awk '$1 == "aaa" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
if [ "$n1" -eq 3 ] && [ "$kept" = 1 ]; then
  ok "a run that dispatched 2 of 3 units left the third's cost in the record UNCHANGED at its seeded 1 — the record MERGES, and a replace here loses every skipped unit's cost"
else
  bad "a narrowed run cut the record to $n1 line(s) and aaa's cost is '${kept:-gone}' rather than the seeded 1 — a replace throws away exactly what the read-set skip decided not to re-run, and an unknown cost sorts FIRST"
fi

# And the consequence, observed rather than argued. With aaa's cost still KNOWN it sorts
# on its VALUE, which is the smallest here, so aaa goes LAST. Under a replace aaa would be
# unknown, unknown maps to 999999 (`core/git-hooks/pre-push:519`), and aaa would go FIRST
# — so POSITION is what discriminates, and the two states cannot collide on it.
#
# THE ARM READS AAA'S POSITION AND NOTHING ELSE. mmm and zzz both sleep 2, so which of the
# two lands first is a scheduler question, and asking it is exactly what made this arm
# flake. An assertion must not depend on an answer the assertion does not need.
mv "$WORK/aaa.withheld" "$T/tests/fixtures/aaa" || broken "could not restore the withheld fixture"
: > "$SDO_TRACE"
rc="$(drive1 "$T" "$WORK/merge3.out")"
mg_order="$(tr '\n' ' ' < "$SDO_TRACE")"
mg_last="$(tail -1 "$SDO_TRACE")"
if [ "$rc" = 0 ] && [ "$mg_last" = aaa ]; then
  ok "after the narrowed run the unit whose cost was PRESERVED sorts last on its value (order '$mg_order') — the preserved cost is the one being sorted on"
else
  bad "the run after a narrowed one dispatched '$mg_order', ending on '$mg_last' rather than aaa — a cost lost to a narrowed run comes back as UNKNOWN, which sorts first and puts the poles last"
fi
unset SDO_TRACE

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
#
# THE RECORD M1 AND M2 COPY IS ARM 1's SEEDED ONE, AND ARM 1 IS WHAT MAKES THAT SOUND.
# A mutant fed an input that could not produce a reordering under an UNMUTATED hook scores
# a kill it did not earn — the differential's two sides have to be proven to differ before
# either verdict is read. Arm 1 has already established, in this same run and against this
# exact record, that the unmutated hook reorders to `zzz mmm aaa`. That is a stronger
# guarantee than the real record this used to copy, whose separation was itself a
# measurement and could collapse to a tie under load.
if mut m1 's|< "\$out/\.order"|< "$out/list"|'; then M="$MUT"
  T="$WORK/m1"; seed "$T" "$M" || broken "seed failed"
  export SDO_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 0; mkfx_trace "$T" zzz 0
  cp "$SEEDREC" "$T/.git/ai-dlc-fixture-durations" \
    || broken "could not carry arm 1's seeded durations record into the M1 tree"
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
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 0; mkfx_trace "$T" zzz 0
  cp "$SEEDREC" "$T/.git/ai-dlc-fixture-durations" \
    || broken "could not carry arm 1's seeded durations record into the M2 tree"
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

# M4 — THE MERGE REMOVED, and arm 4 cannot fire without it. The old record is simply not
# read, so the last-wins pass has nothing to fall back on and the write degenerates to
# exactly the replace this release removed. One line, because that is the whole mechanism.
#
# WITHOUT THIS MUTANT ARM 4 WOULD PASS ON A HOOK THAT NEVER MERGED ANYTHING: on a run
# that dispatches every unit, a merge and a replace produce byte-identical records. The
# arm only discriminates on a NARROWED run, so the mutant is what proves the arm is
# reading the narrowing rather than the tree.
if mut m4 's|\[ -s "\$DURATIONS_RECORD" \] && cat "\$DURATIONS_RECORD"|false|'; then M="$MUT"
  T="$WORK/m4"; seed "$T" "$M" || broken "seed failed"
  export SDO_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 2; mkfx_trace "$T" zzz 2
  cp "$SEEDREC" "$T/.git/ai-dlc-fixture-durations" \
    || broken "could not install the seeded durations record under M4"
  mv "$T/tests/fixtures/aaa" "$WORK/m4.withheld" || broken "could not withhold a fixture under M4"
  : > "$SDO_TRACE"
  rc="$(drive "$T" "$WORK/m4b.out")"
  n_m4="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  case "$n_m4" in ''|*[!0-9]*) n_m4=0 ;; esac
  m4_kept="$(awk '$1 == "aaa" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  mv "$WORK/m4.withheld" "$T/tests/fixtures/aaa" || broken "could not restore the fixture withheld under M4"
  if [ "$rc" = 0 ] && [ "$n_m4" -eq 2 ] && [ -z "$m4_kept" ]; then
    ok "M4 with the old record not read the same narrowed run cuts it to 2 lines and loses aaa's seeded cost — arm 4 is measuring the merge and not the tree"
  else
    bad "M4 the record still held $n_m4 line(s) with aaa='${m4_kept:-gone}' — arm 4 would pass against a hook that replaces, which is the state this release removed"
  fi
  unset SDO_TRACE
fi

# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are emitted
# from inside a conditional: an assertion that never executed prints nothing, and a short
# green report reads exactly like a complete one.
EXPECTED_ASSERTIONS=12
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
