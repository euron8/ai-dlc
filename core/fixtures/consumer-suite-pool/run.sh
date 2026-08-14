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

# Drive the hook. stdin is /dev/null, never a terminal: on a terminal the hook's own
# `[ -t 0 ]` guard leaves PUSH_REFS empty and arm 0 says so, which is a different run
# from the one a real push makes.
drive() {                      # drive <tree> <outfile>  -> rc
  ( cd "$1" && bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
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

# ------------------------------- 2b. a red unit's OUTPUT survives the run ------------
# THE DEFECT. The worker used to run `bash "$d/run.sh" >/dev/null 2>&1`, so a red unit left
# exactly one line of evidence — `FAIL <name>` — and the temp dir holding everything else was
# `rm -rf`d on the way out. The honest local remedy became "push again", which is
# indistinguishable from bypassing a real failure, and this repository has spent several
# releases proposing and refuting causes for one intermittent because every investigation had
# to re-run the fixture out of band. Filed by the graph consumer as
# PC-S302-FIXTURE-SUITE-POOL-PRODUCES-AN-UNREPRODUCIBLE-FAIL-AND-THE-EVIDENCE-IS-DELETED-WITH-THE-TEMP-DIR.
#
# TRACED BY TOKEN, NOT BY EXISTENCE, and both streams are asserted separately: a capture that
# took stdout and dropped stderr would satisfy a file-exists check and lose the half a shell
# fixture writes its diagnostics to.
T="$WORK/evidence"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 1 CSPTOKEN; mkfx "$T" charlie 0
rc="$(drive "$T" "$WORK/evidence.out")"
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
grep -q 'captured output for the failing unit(s): .git/ai-dlc-fixture-failures' "$WORK/evidence.out" \
  && ok "the run names the record's path, so the operator does not have to know it exists" \
  || bad "the failing run never named the record path — an artifact nobody is pointed at is one nobody reads"

# CONTROL, and it is the arm that stops the one above from passing on a hook that writes the
# record unconditionally. A green run must leave no record naming this token: without this,
# `grep CSPTOKEN` would be satisfied by a capture of every unit whether it failed or not, and
# the selector could be `true`.
T="$WORK/evidence-green"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 0 GREENTOKEN; mkfx "$T" charlie 0
rc="$(drive "$T" "$WORK/evidence-green.out")"
if [ "$rc" = 0 ] && ! grep -q 'GREENTOKEN' "$T/.git/ai-dlc-fixture-failures" 2>/dev/null \
   && ! grep -q 'captured output for the failing unit' "$WORK/evidence-green.out"; then
  ok "CONTROL: an all-green run records no failure and names no record — the selector is the verdict, not every unit"
else
  bad "a green run wrote a failure record or announced one (rc=$rc) — the capture fires on units that passed"
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

# M4 — the failure record's SELECTOR removed, so every unit is written out whether it
# passed or not. The green-run control in arm 2b is an ABSENCE (`! grep GREENTOKEN`), and an
# absence passes against a hook that wrote no record at all — the same shape assertion 2's
# mutant exists for in `layer-debt-ledger`. This is the arm that makes that control mean
# "only red units are captured" rather than "something did not happen".
if mut m4 '/= ok \] && continue/d'; then M="$MUT"
  T="$WORK/m4"; seed "$T" "$M" || broken "seed failed"
  mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 0 M4TOKEN
  rc="$(drive "$T" "$WORK/m4.out")"
  if [ "$rc" = 0 ] && grep -q 'M4TOKEN-stdout' "$T/.git/ai-dlc-fixture-failures" 2>/dev/null; then
    ok "M4 without the verdict selector a GREEN unit is captured too — so the control is what proves only red units are"
  else
    bad "M4 the green unit was still not captured (rc=$rc) — arm 2b's green-run control passes whatever the selector does, and proves nothing"
  fi
fi

# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are
# emitted from inside a conditional: an assertion that never executed prints nothing,
# and a short green report reads exactly like a complete one. This is the same
# property the hook itself now asserts about its own workers, one layer out.
EXPECTED_ASSERTIONS=18
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
