#!/usr/bin/env bash
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

# Both layouts, named rather than derived from one another.
HOOK=""
for cand in "$HERE/../../git-hooks/pre-push" "$HERE/../../../.githooks/pre-push"; do
  [ -f "$cand" ] && { HOOK="$cand"; break; }
done
[ -n "$HOOK" ] || broken "cannot locate the pre-push hook in either layout (core/git-hooks/pre-push or .githooks/pre-push) from $HERE"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/consumer-suite-pool.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

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

# A fixture that KILLS ITS OWN WORKER before the worker can record a verdict. This
# is the real shape of a dropped job — the pool loses the process, so no verdict
# file is written — and it is the only way to reach the completeness arm without
# reaching inside the hook to fake it.
mkfx_kill() {
  mkdir -p "$1/tests/fixtures/$2"
  printf '#!/usr/bin/env bash\nkill -9 "$PPID" 2>/dev/null\nsleep 5\n' > "$1/tests/fixtures/$2/run.sh"
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
mkfx_observe() {
  mkdir -p "$1/tests/fixtures/$2"
  cat > "$1/tests/fixtures/$2/run.sh" <<'FX'
#!/usr/bin/env bash
: > "$CSP_OBSERVE/$$"
sleep 0.6
ls "$CSP_OBSERVE" | wc -l | tr -d ' ' >> "$CSP_OBSERVE/../seen"
rm -f "$CSP_OBSERVE/$$"
exit 0
FX
}

# A fixture that RECORDS THE MOMENT IT WAS DISPATCHED, by appending its own name, and
# then costs a stated number of seconds. The cost is what the hook writes into its
# durations record; the trace is how the next run's dispatch order is read back.
mkfx_trace() {                 # mkfx_trace <tree> <name> <seconds>
  mkdir -p "$1/tests/fixtures/$2"
  cat > "$1/tests/fixtures/$2/run.sh" <<FX
#!/usr/bin/env bash
printf '%s\n' '$2' >> "\$CSP_TRACE"
sleep $3
exit 0
FX
}

# Drive the hook. stdin is /dev/null, never a terminal: on a terminal the hook's own
# `[ -t 0 ]` guard leaves PUSH_REFS empty and arm 0 says so, which is a different run
# from the one a real push makes.
drive() {                      # drive <tree> <outfile>  -> rc
  ( cd "$1" && bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}

# Drive it ONE AT A TIME, which is what makes dispatch order observable at all. At any
# width above 1 the workers overlap and the trace records a race; at width 1 execution
# order IS dispatch order, so the trace reads the schedule directly rather than
# inferring it from a wall clock -- the timing-sensitive assertion §7's gate warns about.
drive1() {                     # drive1 <tree> <outfile>  -> rc
  ( cd "$1" && AI_DLC_FIXTURE_JOBS=1 bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
}

# ------------------------------------------------------------- 1. green baseline --
# Asserted FIRST and positively. Every arm below reads the same output shape, so an
# assertion that the shape is produced at all has to come before any of them.
T="$WORK/green"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" alpha 0; mkfx "$T" bravo 0; mkfx "$T" charlie 0
rc="$(drive "$T" "$WORK/green.out")"
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

# ------------------------------------------------- 2. a real failure is attributed --
T="$WORK/red"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" alpha 0; mkfx "$T" bravo 1; mkfx "$T" charlie 0
rc="$(drive "$T" "$WORK/red.out")"
if [ "$rc" = 1 ] && grep -q 'FAIL  bravo' "$WORK/red.out" \
                 && grep -q 'ok    alpha' "$WORK/red.out" \
                 && grep -q 'ok    charlie' "$WORK/red.out"; then
  ok "a failing fixture is named, and its neighbours still report their own verdicts"
else
  bad "a failing fixture was not attributed (rc=$rc) — xargs collapses failures into one exit code, so the verdict has to come from the per-fixture files"
fi

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
T="$WORK/empty2"; seed "$T" "$HOOK" || broken "seed failed"
mkdir -p "$T/tests/fixtures/alpha" "$T/tests/fixtures/bravo"
printf 'data\n' > "$T/tests/fixtures/alpha/seed.txt"
rc="$(drive "$T" "$WORK/empty2.out")"
if [ "$rc" = 1 ] && grep -q 'no fixtures found' "$WORK/empty2.out"; then
  ok "fixture directories with no run.sh FAIL the push (the form that returned 0)"
else
  bad "driverless fixture directories did not fail (rc=$rc) — a directory nothing drives read exactly like one that passed"
fi

# --------------------------------------------- 4. a dropped worker is a FAILURE ----
# The completeness assertion. Without it the report simply gets SHORTER, and a
# suite printing two greens where three were expected reads exactly like one that
# passed — the check-that-cannot-fire class one layer out.
T="$WORK/drop"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" alpha 0; mkfx_kill "$T" bravo; mkfx "$T" charlie 0
rc="$(drive "$T" "$WORK/drop.out")"
if [ "$rc" = 1 ] && grep -q 'bravo  (no verdict recorded)' "$WORK/drop.out" \
                 && grep -q 'fixtures produced a verdict' "$WORK/drop.out"; then
  ok "a worker killed before it records its verdict FAILS as a missing verdict"
else
  bad "a dropped worker did not fail (rc=$rc) — the pool lost a job and the suite reported a shorter green"
fi

# -------------------------------------------------- 5. the pool really is a pool ---
# Positive arm: through the shipping default the fixtures observe each other.
T="$WORK/pool"; seed "$T" "$HOOK" || broken "seed failed"
export CSP_OBSERVE="$T/observe"; mkdir -p "$CSP_OBSERVE"
for n in alpha bravo charlie delta; do mkfx_observe "$T" "$n"; done
rc="$(drive "$T" "$WORK/pool.out")"
max_par="$(sort -n "$T/observe/../seen" 2>/dev/null | tail -1)"
if [ "$rc" = 0 ] && [ "${max_par:-0}" -ge 2 ]; then
  ok "four fixtures ran concurrently (max observed in flight: ${max_par:-0})"
else
  bad "the suite did not run concurrently (rc=$rc, max in flight ${max_par:-0}) — the pool is the whole speed half"
fi

# CONTROL for that arm, and it is the one that makes the number above mean something.
# At AI_DLC_FIXTURE_JOBS=1 the SAME fixtures must observe exactly one in flight. If
# they reported 4 here too, the observation instrument would be measuring something
# other than concurrency and the arm above would be satisfied by any hook at all.
T="$WORK/serial"; seed "$T" "$HOOK" || broken "seed failed"
export CSP_OBSERVE="$T/observe"; mkdir -p "$CSP_OBSERVE"
for n in alpha bravo charlie delta; do mkfx_observe "$T" "$n"; done
rc="$( cd "$T" && AI_DLC_FIXTURE_JOBS=1 bash .githooks/pre-push </dev/null >"$WORK/serial.out" 2>&1; echo $? )"
max_ser="$(sort -n "$T/observe/../seen" 2>/dev/null | tail -1)"
if [ "$rc" = 0 ] && [ "${max_ser:-0}" = 1 ]; then
  ok "AI_DLC_FIXTURE_JOBS=1 runs them one at a time (max observed in flight: 1) — the knob is live and the observation is real"
else
  bad "the knob did not serialise (rc=$rc, max in flight ${max_ser:-0}) — either AI_DLC_FIXTURE_JOBS is not read, or the arm above is not measuring concurrency"
fi
unset CSP_OBSERVE

# ------------------------------------------- 6. the report is in LIST order --------
# Work completes out of order under a pool; the report must not. A non-deterministic
# report cannot be diffed across runs, which is how a suite's own output stops being
# evidence about what changed.
T="$WORK/order"; seed "$T" "$HOOK" || broken "seed failed"
mkdir -p "$T/tests/fixtures/aaa" "$T/tests/fixtures/mmm" "$T/tests/fixtures/zzz"
printf '#!/usr/bin/env bash\nsleep 0.9\nexit 0\n' > "$T/tests/fixtures/aaa/run.sh"
printf '#!/usr/bin/env bash\nexit 0\n'            > "$T/tests/fixtures/mmm/run.sh"
printf '#!/usr/bin/env bash\nexit 0\n'            > "$T/tests/fixtures/zzz/run.sh"
rc="$(drive "$T" "$WORK/order.out")"
seen_order="$(grep -oE '(aaa|mmm|zzz)$' "$WORK/order.out" | tr '\n' ' ')"
if [ "$rc" = 0 ] && [ "$seen_order" = "aaa mmm zzz " ]; then
  ok "verdicts render in list order even though 'aaa' finished last"
else
  bad "the report is not in list order (rc=$rc, got '$seen_order') — the output is not diffable across runs"
fi

# ------------------------------ 7. dispatch is LONGEST-FIRST, off a real record ----
# THE TWO RUNS ARE THE WHOLE POINT, and seeding the record by hand instead would have
# made this arm worthless. The first run WRITES the durations record; the second READS
# it. So the record's format is bound end to end by the runner itself, and a hook whose
# writer and reader disagreed about it could not pass here. Hand-written seed data
# would have restated the format instead of testing it, and the mechanism would then be
# free to degrade silently to glob order -- a check that cannot fire, with a stopwatch.
#
# The costs are 0, 1 and 3 seconds against a whole-second record, so the two orders are
# exact reverses of each other and a full second of scheduling noise on the middle unit
# still cannot reorder them.
T="$WORK/lpt"; seed "$T" "$HOOK" || broken "seed failed"
export CSP_TRACE="$T/trace"
mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 1; mkfx_trace "$T" zzz 3
: > "$CSP_TRACE"
rc="$(drive "$T" "$WORK/lpt1.out")"
[ "$rc" = 0 ] || broken "the run that writes the durations record did not pass (rc=$rc); arm 7 reads what it wrote"
: > "$CSP_TRACE"
rc="$(drive1 "$T" "$WORK/lpt2.out")"
lpt_order="$(tr '\n' ' ' < "$CSP_TRACE")"
if [ "$rc" = 0 ] && [ "$lpt_order" = "zzz mmm aaa " ]; then
  ok "the second run dispatches longest-first (zzz mmm aaa) off the costs the FIRST run recorded"
else
  bad "the second run did not dispatch longest-first (rc=$rc, got '$lpt_order', glob order is 'aaa mmm zzz') — the pool's makespan is decided by when its longest unit starts"
fi

# CONTROL for that arm. Same tree, same fixtures, same width — only the record removed.
# Without it the order must fall back to glob order, which is what says the RECORD is
# what reordered the dispatch rather than anything else about this tree.
rm -f "$T/.git/ai-dlc-fixture-durations"
: > "$CSP_TRACE"
rc="$(drive1 "$T" "$WORK/lpt3.out")"
ctl_order="$(tr '\n' ' ' < "$CSP_TRACE")"
if [ "$rc" = 0 ] && [ "$ctl_order" = "aaa mmm zzz " ]; then
  ok "with the record deleted the SAME tree dispatches in glob order — the record is what reorders it, and a first run is correct without one"
else
  bad "removing the record did not restore glob order (rc=$rc, got '$ctl_order') — arm 7 is not measuring the record"
fi

# ------------------------------- 8. the record is written OUTSIDE the working tree --
# I55 arm 4's prohibition, observed rather than asserted about. A cost record inside
# the tree would be hashed by the distribution's own suite content key, so writing it
# would move the key it is trying to match and the suite skip could never hit again.
# For a consumer the same file would turn up in every `git status` they ever ran.
: > "$CSP_TRACE"
rc="$(drive "$T" "$WORK/lpt4.out")"
n_rec="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
case "$n_rec" in ''|*[!0-9]*) n_rec=0 ;; esac
if [ "$n_rec" -eq 3 ] && [ ! -f "$T/ai-dlc-fixture-durations" ] \
   && ! git -C "$T" status --porcelain 2>/dev/null | grep -q 'ai-dlc-fixture-durations'; then
  ok "the durations record holds one line per fixture under .git/ and git itself cannot see it"
else
  bad "the durations record is not where it must be (lines=$n_rec under .git/, root copy present=$([ -f "$T/ai-dlc-fixture-durations" ] && echo yes || echo no)) — a record inside the tree is hashed by the key that decides whether this suite runs at all"
fi
unset CSP_TRACE

# ------------------------- 9. a record that makes no sense loses no fixture ---------
# Garbage lines, a one-field line, and an entry for a fixture that no longer exists.
# The failure this refuses is the quiet one: an ordering step that drops a unit reads
# exactly like an ordering step that is fast.
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

# =================================================================== MUTANTS =======
# Each is a COPY of the hook with one arm removed, guarded by `cmp -s` so a sed that
# matched nothing cannot pass as a mutation. Each asserts a POSITIVE outcome: the
# mutant goes GREEN on the tree the real hook goes RED on.
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

# UNMUTATED CONTROL, and it runs FIRST. The hook is driven ten times above; if the
# harness itself were what fails, every mutant below would go green and score a kill
# it had not earned.
T="$WORK/mctl"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" alpha 0
rc="$(drive "$T" "$WORK/mctl.out")"
[ "$rc" = 0 ] && ok "mutant-battery control: the unmutated hook is green on a one-fixture tree" \
              || bad "mutant-battery control is RED (rc=$rc) — no mutant verdict below is believable"

# M1 — the empty-suite guard removed. The two empty forms must go green.
# The range takes the WHOLE `if`, not just its body: deleting a conditional's body
# and leaving the `if`/`fi` produces a syntax error, and a mutant that cannot parse
# fails for a reason that has nothing to do with the arm under test. Both of this
# battery's structural mutants were written that way first and both exited 2.
if mut m1 '/if \[ "\$n_expected" -eq 0 \]/,+3d'; then M="$MUT"
  T="$WORK/m1"; seed "$T" "$M" || broken "seed failed"
  mkdir -p "$T/tests/fixtures/alpha"
  rc="$(drive "$T" "$WORK/m1.out")"
  [ "$rc" = 0 ] && ok "M1 without the empty-suite guard a driverless tree PASSES — the guard is what fails it" \
                || bad "M1 still red (rc=$rc): the empty-suite arm is not what produces that verdict"
fi

# M2 — the completeness assertion removed. The dropped worker must go green.
if mut m2 '/n_actual" -ne "\$n_expected/,+4d'; then M="$MUT"
  T="$WORK/m2"; seed "$T" "$M" || broken "seed failed"
  mkfx "$T" alpha 0; mkfx_kill "$T" bravo
  rc="$(drive "$T" "$WORK/m2.out")"
  if [ "$rc" = 1 ] && grep -q 'no verdict recorded' "$WORK/m2.out"; then
    ok "M2 the per-fixture 'no verdict recorded' line is a SECOND, independent arm on the same failure"
  else
    bad "M2 dropped-worker detection collapsed to a single arm (rc=$rc) — removing the count assertion should leave the per-fixture line"
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
if mut m2b '/if \[ ! -f "\$out\/\$b" \]/,+2d'; then M="$MUT"
  T="$WORK/m2b"; seed "$T" "$M" || broken "seed failed"
  mkfx "$T" alpha 0; mkfx_kill "$T" bravo
  rc="$(drive "$T" "$WORK/m2b.out")"
  if [ "$rc" = 1 ] && ! grep -q 'no verdict recorded' "$WORK/m2b.out" \
                   && ! grep -q 'fixtures produced a verdict' "$WORK/m2b.out"; then
    ok "M2b without the per-fixture arm a lost worker is MISREPORTED as a failing fixture, and the count assertion stays silent — so the count cannot fire alone"
  else
    bad "M2b did not behave as measured (rc=$rc) — re-derive which arm detects a dropped worker before trusting either comment"
  fi
fi

# M3 — the pool removed. The concurrency observation must collapse to 1.
if mut m3 's|xargs -P "\$FIXTURE_JOBS"|xargs -P 1|'; then M="$MUT"
  T="$WORK/m3"; seed "$T" "$M" || broken "seed failed"
  export CSP_OBSERVE="$T/observe"; mkdir -p "$CSP_OBSERVE"
  for n in alpha bravo charlie delta; do mkfx_observe "$T" "$n"; done
  rc="$(drive "$T" "$WORK/m3.out")"
  m3max="$(sort -n "$T/observe/../seen" 2>/dev/null | tail -1)"
  [ "${m3max:-0}" = 1 ] && ok "M3 with the pool width pinned to 1 the fixtures no longer overlap — the pool is what produces the overlap" \
                        || bad "M3 still overlapped (max ${m3max:-0}) — the concurrency arm is not measuring the pool"
  unset CSP_OBSERVE
fi

# M4 — dispatch reads the UNORDERED list. The reordering still computes; nothing uses
# it. Order must fall back to glob order, which is what says arm 7 measures the
# dispatch source and not some other property of that tree.
#
# THE RECORD THESE THREE COPY IS A REAL ONE, taken from arm 7's own first run. Writing
# one here would restate the format the hook produces, and a mutant that restates the
# thing under test proves the restatement.
if mut m4 's|< "\$out/\.order"|< "$out/list"|'; then M="$MUT"
  T="$WORK/m4"; seed "$T" "$M" || broken "seed failed"
  export CSP_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 1; mkfx_trace "$T" zzz 3
  cp "$WORK/lpt/.git/ai-dlc-fixture-durations" "$T/.git/ai-dlc-fixture-durations" \
    || broken "could not carry arm 7's real durations record into the M4 tree"
  : > "$CSP_TRACE"
  rc="$(drive1 "$T" "$WORK/m4.out")"
  m4_order="$(tr '\n' ' ' < "$CSP_TRACE")"
  [ "$m4_order" = "aaa mmm zzz " ] \
    && ok "M4 with dispatch reading the unordered list the same record produces glob order — the dispatch source is what arm 7 measures" \
    || bad "M4 dispatch still reordered (got '$m4_order') — arm 7 is not measuring which file the pool is fed"
  unset CSP_TRACE
fi

# M5 — THE FALLBACK PATH, driven rather than argued. §6c-12 required that the path
# taken when the ordering is unavailable be shown to produce a CORRECT suite and not
# merely a slower one, so the sort is broken outright and the whole suite is read back.
# The count guard then rejects the short reordering and the glob list stands.
if mut m5 's@| sort -k1,1nr@| sort-is-not-installed@'; then M="$MUT"
  T="$WORK/m5"; seed "$T" "$M" || broken "seed failed"
  export CSP_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 1; mkfx_trace "$T" zzz 3
  cp "$WORK/lpt/.git/ai-dlc-fixture-durations" "$T/.git/ai-dlc-fixture-durations" \
    || broken "could not carry arm 7's real durations record into the M5 tree"
  : > "$CSP_TRACE"
  rc="$(drive1 "$T" "$WORK/m5.out")"
  m5_order="$(tr '\n' ' ' < "$CSP_TRACE")"
  if [ "$rc" = 0 ] && [ "$m5_order" = "aaa mmm zzz " ] \
     && grep -q 'ok    aaa' "$WORK/m5.out" && grep -q 'ok    mmm' "$WORK/m5.out" \
     && grep -q 'ok    zzz' "$WORK/m5.out" && ! grep -q 'produced a verdict' "$WORK/m5.out"; then
    ok "M5 with the ordering broken the suite runs COMPLETE in glob order — the fallback loses speed and nothing else"
  else
    bad "M5 a broken ordering did not fall back cleanly (rc=$rc, order '$m5_order') — an unavailable schedule must cost time, never coverage"
  fi
  unset CSP_TRACE
fi

# M6 — the WRITER removed, reader intact. Without a run recording what it cost there is
# nothing for the next run to sort on, so the order stays glob. This is the half M4
# cannot reach: M4 proves the reader is wired to the pool, M6 proves the record it
# reads is produced by the workers rather than by anything else in the tree.
if mut m6 '/AI_DLC_FX_OUT\/\.dur\//d'; then M="$MUT"
  T="$WORK/m6"; seed "$T" "$M" || broken "seed failed"
  export CSP_TRACE="$T/trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 1; mkfx_trace "$T" zzz 3
  : > "$CSP_TRACE"
  rc="$(drive "$T" "$WORK/m6a.out")"
  : > "$CSP_TRACE"
  rc="$(drive1 "$T" "$WORK/m6.out")"
  m6_order="$(tr '\n' ' ' < "$CSP_TRACE")"
  if [ "$rc" = 0 ] && [ "$m6_order" = "aaa mmm zzz " ] \
     && [ ! -s "$T/.git/ai-dlc-fixture-durations" ]; then
    ok "M6 with the workers not recording their cost no record is written and the second run stays in glob order"
  else
    bad "M6 an order appeared without the workers recording anything (rc=$rc, order '$m6_order') — the record arm 7 reads is not the one the pool writes"
  fi
  unset CSP_TRACE
fi

# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are
# emitted from inside a conditional: an assertion that never executed prints nothing,
# and a short green report reads exactly like a complete one. This is the same
# property the hook itself now asserts about its own workers, one layer out.
EXPECTED_ASSERTIONS=21
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
