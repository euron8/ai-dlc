#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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

echo "HERMETIC-CONSUMED $(cd "$(dirname "$HOOK")" && pwd -P)/${HOOK##*/}"

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
g_ret="$(retained_names "$T" | wc -l | tr -d ' ')"
if [ "$rc" = 0 ] && ! grep -q 'GREENTOKEN' "$T/.git/ai-dlc-fixture-failures" 2>/dev/null \
   && ! grep -q 'captured output for the failing unit' "$WORK/evidence-green.out" \
   && [ "$g_ret" = 0 ]; then
  ok "CONTROL: an all-green run records no failure, names no record and retains no copy — the selector is the verdict, not every unit"
else
  bad "a green run wrote a failure record, announced one, or retained $g_ret copies (rc=$rc) — the capture fires on units that passed"
fi

# ------------------------- 2c. every red run keeps its OWN record, pruned to twenty ----
# THE DEFECT. The record above is OVERWRITTEN by the next red run, so two reds in a row left
# only the second. Measured at batch 179: one intermittent red's got-vector was the only
# evidence of its cause, and it sat in a file the next red would replace. Seeded with twenty
# earlier copies and two hand-saved records, then ONE red drive: that is the N+1 case without
# twenty-one drives of the hook.
T="$WORK/retain"; seed "$T" "$HOOK" || broken "seed failed"
seed_retained "$T" || broken "seeding retained copies failed"
[ "$(retained_names "$T" | wc -l | tr -d ' ')" = 20 ] || broken "the retained-copy seed did not produce 20 shaped names — every arm below would read a world nobody built"
mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 1 RETAINTOKEN
rc="$(drive "$T" "$WORK/retain.out")"
R_NEW="$(new_retained "$T")"
R_NEWN="$(printf '%s' "$R_NEW" | grep -c . )" || R_NEWN=0
if [ "$rc" = 1 ] && [ "$R_NEWN" = 1 ] && grep -q 'RETAINTOKEN-stdout' "$T/.git/$R_NEW" \
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
rc="$( cd "$T" && AI_DLC_FIXTURE_JOBS=1 AI_DLC_READSET_LIVE_TRACE=0 bash .githooks/pre-push </dev/null >"$WORK/serial.out" 2>&1; echo $? )"
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

# RETENTION MUTANTS. Each drives the arm-2c world -- twenty seeds, two decoys, one red -- and
# asserts the observable its own removal PRODUCES, never the absence of arm 2c's message.
#
# retain-off — the copy statement deleted. The primary record must still carry the token (so
# the run did go red and record) while no stamped copy appears.
if mut retain-off '/cp "\$FAILLOG_RECORD" "\$fl_copy"/d'; then M="$MUT"
  T="$WORK/retain-off"; seed "$T" "$M" || broken "seed failed"
  seed_retained "$T" || broken "seeding retained copies failed"
  mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 1 ROFFTOKEN
  rc="$(drive "$T" "$WORK/retain-off.out")"
  n="$(new_retained "$T" | grep -c .)" || n=0
  if [ "$rc" = 1 ] && grep -q 'ROFFTOKEN-stdout' "$T/.git/ai-dlc-fixture-failures" && [ "$n" = 0 ]; then
    ok "retain-off without the copy a red run records only the overwritable primary — the copy statement is what retains"
  else
    bad "retain-off did not behave as a removed copy (rc=$rc, new copies $n)"
  fi
fi

# retain-fixed-name — every run copies to ONE name, the overwrite this release exists to stop.
# The fixed name is a seed's, so the overwrite is visible as that seed's content changing.
if mut retain-fixed-name 's|fl_copy="\$GITDIR/ai-dlc-fixture-failures\.\$fl_stamp\.\$\$"|fl_copy="$GITDIR/ai-dlc-fixture-failures.20000101T000019Z.1"|'; then M="$MUT"
  T="$WORK/retain-fixed"; seed "$T" "$M" || broken "seed failed"
  seed_retained "$T" || broken "seeding retained copies failed"
  mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 1 RFIXTOKEN
  rc="$(drive "$T" "$WORK/retain-fixed.out")"
  n="$(new_retained "$T" | grep -c .)" || n=0
  if [ "$rc" = 1 ] && grep -q 'RFIXTOKEN-stdout' "$T/.git/ai-dlc-fixture-failures.20000101T000019Z.1" && [ "$n" = 0 ]; then
    ok "retain-fixed-name with one fixed copy name the earlier record is OVERWRITTEN — the per-run stamp is what keeps both"
  else
    bad "retain-fixed-name did not overwrite the earlier record (rc=$rc, new copies $n)"
  fi
fi

# prune-off — the prune loop deleted whole (six lines, so the body still parses). Twenty-one
# shaped copies must remain, the oldest seed among them.
if mut prune-off '/^    for fl_f in "\$GITDIR"/,+5d'; then M="$MUT"
  T="$WORK/prune-off"; seed "$T" "$M" || broken "seed failed"
  seed_retained "$T" || broken "seeding retained copies failed"
  mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 1 POFFTOKEN
  rc="$(drive "$T" "$WORK/prune-off.out")"
  n="$(retained_names "$T" | wc -l | tr -d ' ')"
  if [ "$rc" = 1 ] && [ "$n" = 21 ] && [ -e "$T/.git/ai-dlc-fixture-failures.20000101T000000Z.1" ]; then
    ok "prune-off without the prune the twenty-first copy is kept too — the prune is what bounds retention"
  else
    bad "prune-off did not leave 21 shaped copies (rc=$rc, shaped $n)"
  fi
fi

# prune-glob-wide — the anchored pattern widened to `ai-dlc-fixture-failures.*`. Under name
# order the hand-saved `.179.1` sorts below every stamped copy and is the first thing a
# wide prune deletes; that deletion is this mutant's observable. `.clean` sorts above them and
# survives even here, which is why it cannot be the arm that kills this mutant.
if mut prune-glob-wide 's|ai-dlc-fixture-failures\.2\[0-9\]\[0-9\]\[0-9\]\[01\]\[0-9\]\*Z\.\*|ai-dlc-fixture-failures.*|'; then M="$MUT"
  T="$WORK/prune-wide"; seed "$T" "$M" || broken "seed failed"
  seed_retained "$T" || broken "seeding retained copies failed"
  mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 1 PWIDETOKEN
  rc="$(drive "$T" "$WORK/prune-wide.out")"
  if [ "$rc" = 1 ] && [ ! -e "$T/.git/ai-dlc-fixture-failures.179.1" ] \
     && [ "$(cat "$T/.git/ai-dlc-fixture-failures.clean" 2>/dev/null)" = OPERATOR-CLEAN ]; then
    ok "prune-glob-wide with the pattern widened a hand-saved record is DELETED — the anchor is what protects it"
  else
    bad "prune-glob-wide did not delete the low-sorting hand-saved record (rc=$rc)"
  fi
fi

# prune-suffix-unanchored — the end anchor (the all-digit last-field `case`) deleted. The
# `.1.keep` decoy then passes the glob, sorts between the two oldest seeds, and is pruned
# with the oldest one.
# `.179.1` still survives here, which is why it cannot be the arm that kills this mutant.
if mut prune-suffix-unanchored '/case "\${fl_f##\*\.}" in/d'; then M="$MUT"
  T="$WORK/prune-suffix"; seed "$T" "$M" || broken "seed failed"
  seed_retained "$T" || broken "seeding retained copies failed"
  mkfx "$T" alpha 0; mkfx_noisy "$T" bravo 1 PSUFTOKEN
  rc="$(drive "$T" "$WORK/prune-suffix.out")"
  if [ "$rc" = 1 ] && [ ! -e "$T/.git/ai-dlc-fixture-failures.20000101T000000Z.1.keep" ] \
     && [ "$(cat "$T/.git/ai-dlc-fixture-failures.179.1" 2>/dev/null)" = OPERATOR-179 ]; then
    ok "prune-suffix-unanchored without the end anchor a .keep copy is DELETED — the all-digit last field is what protects it"
  else
    bad "prune-suffix-unanchored did not delete the .1.keep decoy (rc=$rc)"
  fi
fi

# ================================================ 7. NO-PROGRESS REFUSAL (BL-606) ===
# THE DEFECT. Every pool run site ran its unit unbounded, so one hung unit hung the push with
# nothing to say which. `pool_run` now refuses a unit that writes no new bytes -- to its pool log or
# under its per-unit watched root (the TMPDIR the pool sets) -- for POOL_STALL polls, kills its tree
# (every process and every group found in it) by recorded ids, and records REFUSED.
# Stubs, each moving through ONE channel so no mutant is covered by another channel:
#   (h)  a hang whose `sleep` is a grandchild: REFUSED, and no recorded member survives;
#   (p)  a polling loop (a fresh `sleep 1` each pass, no output) for 6 x POOL_STALL passes, then
#        exit 0: REFUSED -- new pids and a moving CPU clock are not progress;
#   (s)  writes one log line a second for 4 x POOL_STALL polls, CPU-free and fork-free (a `read -t`
#        on a fifo paces it): ok -- the LOG alone carries its progress;
#   (w)  silent, appends one byte a second to a `mktemp` file under TMPDIR for 4 x POOL_STALL polls:
#        ok -- the WATCHED ROOT alone carries its progress (it exits 4, a FAIL, if the file lands
#        outside the root, so a root the pool did not set cannot pass);
#   (g)  a grandchild in its OWN group burns CPU every second, writing nothing: REFUSED, BY DESIGN --
#        silent computation is not progress, and this stub documents that;
#   (gh) a grandchild in its own group, idle: REFUSED, and the grandchild's group is gone;
#   (f)  exits 1: FAIL, never REFUSED.
# Every pid a stub starts is RECORDED by the stub, and checked and stopped by that pid only.
# THE VERDICT IS BINARY: REFUSED or not, alive or gone; nothing is judged on elapsed time.
st_stub() {                    # st_stub <tree> <name> : writes the stub and its helper
  local t="$1" n="$2" d="$1/tests/fixtures/$2"
  mkdir -p "$d"
  case "$n" in
    h) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
echo $$ >> "$CSP_PIDS/h"
bash -c 'echo $$ >> "$1"; sleep 100000 & echo $! >> "$1"; wait $!; :' _ "$CSP_PIDS/h"
FX
    ;;
    s) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
echo $$ >> "$CSP_PIDS/s"
exec 3<>"$CSP_FIFO"; i=0
while [ $i -lt $((4 * CSP_STALL)) ]; do i=$((i + 1)); echo "line $i"; read -t 1 -u 3 x; done
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
exec 3<>"$CSP_FIFO"; k=0
while [ $k -lt $((4 * CSP_STALL)) ]; do
  k=$((k + 1)); j=0; while [ $j -lt 20000 ]; do j=$((j + 1)); done
  read -t 1 -u 3 x
done
FX
      else cat > "$d/gc.sh" <<'FX'
ps -o pgid= -p $$ | tr -d ' ' > "$CSP_PIDS/gh.pgid.gc"
sleep 100000 & echo $! >> "$CSP_PIDS/gh"; wait $!
FX
      fi
    ;;
    f) printf '#!/usr/bin/env bash\necho $$ >> "$CSP_PIDS/f"\nexit 1\n' > "$d/run.sh" ;;
    p) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
echo $$ >> "$CSP_PIDS/p"
i=0; while [ $i -lt $((6 * CSP_STALL)) ]; do i=$((i + 1)); sleep 1; done
exit 0
FX
    ;;
    w) cat > "$d/run.sh" <<'FX'
#!/usr/bin/env bash
echo $$ >> "$CSP_PIDS/w"
f="$(mktemp "${TMPDIR:-/tmp}/w.XXXXXX")" || exit 3
case "$f" in "$AI_DLC_FX_OUT"/.t.*/w.*) ;; *) echo "w: scratch landed outside the watched root: $f" >&2; exit 4 ;; esac
exec 3<>"$CSP_FIFO"; i=0
while [ $i -lt $((4 * CSP_STALL)) ]; do i=$((i + 1)); printf x >> "$f"; read -t 1 -u 3 x; done
exit 0
FX
    ;;
  esac
}
ST=3                           # AI_DLC_POOL_STALL for every drive in this section
st_world() {                   # st_world <tree> <hook> <stubs...> : seed, export CSP_* for this world
  local t="$1" h="$2" n; shift 2
  seed "$t" "$h" || broken "seed failed"
  mkdir -p "$t/pids"; mkfifo "$t/fifo" || broken "mkfifo failed"
  for n in "$@"; do st_stub "$t" "$n"; done
  export CSP_PIDS="$t/pids" CSP_FIFO="$t/fifo" CSP_STALL="$ST"
}
st_drive() {                   # st_drive <tree> <outfile> -> rc
  ( cd "$1" && AI_DLC_POOL_STALL="$ST" AI_DLC_READSET_LIVE_TRACE=0 bash .githooks/pre-push </dev/null >"$2" 2>&1; echo $? )
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
  bad "(h) a hung unit was not refused with its whole tree killed (rc=$rc, live recorded members $h_live): $(grep ' h' "$WORK/stall.out" | tr '\n' ' ')"
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
  ok "(g) silent computation in a cross-group grandchild is REFUSED, by design, and its tree is killed"
else
  bad "(g) a silent CPU-only unit was not refused and killed (live recorded members $g_live)"
fi
if st_refused "$WORK/stall.out" gh && [ "$gh_live" = 0 ]; then
  ok "(gh) an idle cross-group grandchild is REFUSED and its group is killed"
else
  bad "(gh) a hung cross-group grandchild was not refused and killed (live recorded members $gh_live)"
fi
if [ "$rc" = 1 ] && grep -q '^   FAIL  f$' "$WORK/stall.out" && ! st_refused "$WORK/stall.out" f; then
  ok "(f) a unit that exits 1 is FAIL, not REFUSED, and a real FAIL beside a refusal exits 1"
else
  bad "(f) exit 1 did not read FAIL with the push at 1 (rc=$rc)"
fi

# THE EXIT-2 CARRIER: a refusal alone exits 2, never 1 and never 0.
T="$WORK/stall2"; st_world "$T" "$HOOK" h
mkfx "$T" alpha 0
rc="$(st_drive "$T" "$WORK/stall2.out")"
h2_live="$(st_alive "$T" h)"
if [ "$rc" = 2 ] && st_refused "$WORK/stall2.out" h && grep -q '^   ok    alpha$' "$WORK/stall2.out" && [ "$h2_live" = 0 ]; then
  ok "a refusal with no FAIL beside it exits 2: the absence of a verdict, not a red verdict"
else
  bad "a lone refusal did not exit 2 (rc=$rc, live recorded members $h2_live)"
fi

# MUTANTS of the refusal, each a copy of the RESOLVED hook, applied by exact-string replacement and
# guarded by `cmp -s`; each asserts the observable its own removal produces.
mutx() {                       # mutx <label> <old> <new> [<source>] -> sets MUT, or returns 1
  local m="$WORK/hook.$1" src="${4:-$HOOK}"
  OLD="$2" NEW="$3" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print } END { if (n != 1) exit 3 }' "$src" > "$m.t" \
    || { bad "MUTANT $1 did not apply (its anchor is not unique in $src)"; return 1; }
  cmp -s "$src" "$m.t" && { bad "MUTANT $1 matched nothing (cmp -s guard)"; return 1; }
  mv "$m.t" "$m"; MUT="$m"
}
# st-a: the signature omits the log, so (s), whose only progress is its log, is refused.
if mutx st-a 'cur="$(find "$wr" "$lg" ${wx:+"$wx"} -type f -ls' 'cur="$(find "$wr" ${wx:+"$wx"} -type f -ls'; then
  T="$WORK/st-a"; st_world "$T" "$MUT" s
  rc="$(st_drive "$T" "$WORK/st-a.out")"; st_alive "$T" s >/dev/null
  st_refused "$WORK/st-a.out" s && ok "st-a without the log in the signature a log-only unit is REFUSED -- the log is what keeps (s) alive" \
                                || bad "st-a (s) was not refused with the log dropped from the signature (rc=$rc)"
fi
# st-w: the signature ignores the watched root, so (w), whose only progress is under it, is refused.
if mutx st-w 'cur="$(find "$wr" "$lg" ${wx:+"$wx"} -type f -ls' 'cur="$(find "$lg" ${wx:+"$wx"} -type f -ls'; then
  T="$WORK/st-w"; st_world "$T" "$MUT" w
  rc="$(st_drive "$T" "$WORK/st-w.out")"; st_alive "$T" w >/dev/null
  st_refused "$WORK/st-w.out" w && ok "st-w without the watched root in the signature a scratch-only unit is REFUSED -- the root is what keeps (w) alive" \
                                || bad "st-w (w) was not refused with the watched root dropped from the signature (rc=$rc)"
fi
# st-cpu: the signature counts the tree's CPU and membership again, so (p) is never still and runs
# to its own exit 0 -- ok, not refused.
if mutx st-cpu '          if [ "$cur" = "$sg" ]; then still=$((still + 1)); else still=0; sg="$cur"; fi' '          cur="$cur;$wsig"; if [ "$cur" = "$sg" ]; then still=$((still + 1)); else still=0; sg="$cur"; fi'; then
  T="$WORK/st-cpu"; st_world "$T" "$MUT" p
  rc="$(st_drive "$T" "$WORK/st-cpu.out")"; st_alive "$T" p >/dev/null
  grep -q '^   ok    p$' "$WORK/st-cpu.out" && ok "st-cpu with CPU and membership back in the signature a polling loop is never refused -- bytes alone are what refuse (p)" \
                                         || bad "st-cpu (p) was still refused with CPU in the signature (rc=$rc)"
fi
# st-b: the refusal writes FAIL, so (h) reads FAIL and the push exits 1, not 2.
if mutx st-b 'printf REFUSED > "$AI_DLC_FX_OUT/$b"' 'printf FAIL > "$AI_DLC_FX_OUT/$b"'; then
  T="$WORK/st-b"; st_world "$T" "$MUT" h
  rc="$(st_drive "$T" "$WORK/st-b.out")"; st_alive "$T" h >/dev/null
  if [ "$rc" = 1 ] && grep -q '^   FAIL  h$' "$WORK/st-b.out" && ! st_refused "$WORK/st-b.out" h; then
    ok "st-b a refusal written as FAIL reads as a red verdict at exit 1 -- the REFUSED record is what keeps it out of the verdicts"
  else
    bad "st-b the refusal-as-FAIL mutant did not read FAIL at 1 (rc=$rc)"
  fi
fi
# st-c: the kill covers the leader pid only (both the tree kill and the unit's own group kill go), so
# (h)'s grandchild sleep survives. Two anchors on two lines, each guarded.
if mutx st-c1 '            pool_kill "$pid" "$self" "$kp" "$kg"' '            kill -KILL "$pid"' \
   && mutx st-c '            kill -KILL -- "-$pid" 2>/dev/null' '            :' "$MUT"; then
  T="$WORK/st-c"; st_world "$T" "$MUT" h
  rc="$(st_drive "$T" "$WORK/st-c.out")"; c_live="$(st_alive "$T" h)"
  [ "${c_live:-0}" != none ] && [ "${c_live:-0}" -ge 1 ] \
    && ok "st-c killing the leader pid alone leaves $c_live recorded member(s) of (h)'s tree alive -- the tree kill is what reaps them" \
    || bad "st-c with the leader-only kill no recorded member of (h) survived ($c_live) -- the arm cannot see a partial kill"
fi
# st-d: the walk stays in the leader's group, so (gh)'s grandchild, in a group of its own, is never
# reached by the kill and survives the refusal.
if mutx st-d '} else if ((pp[i] in T) || (pg[i] in G)) { T[pid[i]] = 1; c = 1 }' '} else if (pg[i] == root) { T[pid[i]] = 1; c = 1 }'; then
  T="$WORK/st-d"; st_world "$T" "$MUT" gh
  rc="$(st_drive "$T" "$WORK/st-d.out")"; d_live="$(st_alive "$T" gh)"
  st_refused "$WORK/st-d.out" gh && [ "${d_live:-0}" != none ] && [ "${d_live:-0}" -ge 1 ] \
    && ok "st-d a walk confined to the leader's group leaves (gh)'s cross-group grandchild alive -- the cross-group walk is what kills it" \
    || bad "st-d (gh) was not refused with its grandchild surviving under a leader-group walk (rc=$rc, live $d_live)"
fi
# THE WATCHER DIES WITH ITS WORKER. The hook's worker body is extracted and run as a lone worker over
# one hanging stub; the worker is then SIGKILLed by its recorded pid. The watcher pid the worker recorded
# (`.pr/<unit>.w`) must be gone within POOL_STALL polls, and so must every pid the stub recorded: a
# watcher whose only exit was a refusal outlived its worker with ppid 1.
st_orphan() {                  # st_orphan <hook> <tag> [<stub-dir>] -> prints "<watcher-left> <unit-left>" or BROKEN
  local h="$1" R="$WORK/orph.$2" SB="${3:-}" WK WP n p ul=0
  mkdir -p "$R/t/tests/fixtures/u" "$R/out/.log" "$R/out/.dur" "$R/out/.pr"
  awk '/xargs -P "\$FIXTURE_JOBS" -I\{\} bash -c /{f=1;next} /^  . _ \{\} < "\$out\/.order"$/{f=0} f' "$h" > "$R/body.sh"
  awk '/^POOL_WALK=/{f=1} f{print} f && /^}.$/{exit}' "$h" > "$R/walk.sh"
  POOL_WALK=""; . "$R/walk.sh"
  [ -s "$R/body.sh" ] && [ -n "$POOL_WALK" ] || { echo BROKEN; return; }
  printf 'echo $$ >> "%s/pids"\nsleep 100000 & echo $! >> "%s/pids"; wait $!\n' "$R" "$R" > "$R/t/tests/fixtures/u/run.sh"
  ( cd "$R/t" && PATH="${SB:+$SB:}$PATH" AI_DLC_FX_OUT="$R/out" AI_DLC_FX_TRACE="" AI_DLC_FX_TRACE_LIST="" AI_DLC_FX_DV="" \
     POOL_STALL=300 POOL_WALK="$POOL_WALK" exec bash -c "$(cat "$R/body.sh")" _ tests/fixtures/u/ ) >/dev/null 2>&1 &
  WK=$!
  n=0; while [ ! -s "$R/out/.pr/u.w" ] && [ "$n" -lt 50 ]; do n=$((n + 1)); sleep 0.1; done
  WP="$(cat "$R/out/.pr/u.w" 2>/dev/null)"
  case "$WP" in ''|*[!0-9]*) kill -KILL "$WK" 2>/dev/null; wait "$WK" 2>/dev/null
    [ -s "$R/pids" ] && while read -r p; do kill -KILL "$p" 2>/dev/null; done < "$R/pids"
    echo BROKEN; return ;; esac
  kill -0 "$WP" 2>/dev/null || { echo BROKEN; return; }
  kill -KILL "$WK" 2>/dev/null; wait "$WK" 2>/dev/null
  n=0; while kill -0 "$WP" 2>/dev/null && [ "$n" -lt "$ST" ]; do n=$((n + 1)); sleep 1; done
  local wl=0; if kill -0 "$WP" 2>/dev/null; then wl=1; kill -KILL -- "-$WP" 2>/dev/null; fi
  while read -r p; do kill -0 "$p" 2>/dev/null && { ul=$((ul + 1)); kill -KILL "$p" 2>/dev/null; }; done < "$R/pids"
  # A STUBBED drive must prove the stub refused the worker's own `-p` lookup, or `self` was never empty.
  [ -z "$SB" ] || [ -s "$SB/refused" ] || { echo BROKEN; return; }
  echo "$wl $ul"
}
o="$(st_orphan "$HOOK" fix)"
case "$o" in
  BROKEN) bad "orphan arm: the extracted worker recorded no live watcher pid -- the arm cannot read its subject" ;;
  "0 0") ok "a SIGKILLed worker's watcher exits within POOL_STALL polls and takes the unit's tree with it" ;;
  *) bad "a SIGKILLed worker left its watcher or unit alive (watcher-left unit-left: $o)" ;;
esac
# st-e: the watcher's worker-liveness check removed, so it outlives the worker.
if mutx st-e '          if ! kill -0 "$$"; then pool_kill "$pid" "$self" "$kp" "$kg"; exit 0; fi' '          :'; then
  o="$(st_orphan "$MUT" st-e)"
  case "$o" in
    "1 "*) ok "st-e without the worker-liveness check the watcher outlives its SIGKILLed worker -- the check is what ends it" ;;
    *) bad "st-e the watcher did not outlive its worker with the liveness check removed ($o)" ;;
  esac
fi
# THE EMPTY-SELF PATH KILLS THE UNIT'S GROUP TOO (BL-677). A stub `ps` that FAILS on `-p` (and records that
# it did) leaves the worker's `self` empty, so the watcher's worker-death `pool_kill` takes its guard path,
# which kills the recorded pid and its group and walks nothing. The unit leads its own group and its
# `sleep` child is in it, so the child dies only if the guard signals the group. Every other `ps` call
# (the walk's `-A`) passes through to the real binary, resolved here before the stub dir is on PATH.
SP="$WORK/ps-stub"; mkdir -p "$SP"
PS_REAL="$(command -v ps)" || broken "no ps on PATH to wrap"
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = -p ] && { printf "%%s\\n" "$*" >> "%s/refused"; exit 1; }; done\nexec "%s" "$@"\n' "$SP" "$PS_REAL" > "$SP/ps"
chmod +x "$SP/ps"
o="$(st_orphan "$HOOK" eself "$SP")"
case "$o" in
  BROKEN) bad "empty-self arm: the stubbed worker recorded no watcher, or the stub never refused a -p lookup -- self was not shown empty" ;;
  "0 0") ok "with self empty (ps fails on -p) a SIGKILLed worker's watcher still kills the unit's whole group, its child included" ;;
  *) bad "with self empty a SIGKILLed worker left its watcher or a unit group member alive (watcher-left unit-left: $o)" ;;
esac
# st-g: the empty-self guard kills the recorded pid alone, so the unit's child survives the worker's death.
if mutx st-g '[ -n "$2" ] || { kill -KILL -- "-$1"; kill -KILL "$1"; return 0; }' '[ -n "$2" ] || { kill -KILL "$1"; return 0; }'; then
  : > "$SP/refused"
  o="$(st_orphan "$MUT" st-g "$SP")"
  case "$o" in
    "0 "[1-9]*) ok "st-g without the group kill on the empty-self path the unit's child outlives the worker -- the group kill is what reaps it" ;;
    *) bad "st-g the unit's child did not survive with the empty-self guard's group kill removed ($o)" ;;
  esac
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
# scripts/ai-dlc/ (consumer, per core-paths.sh --map), which is three hops up, as the hook lookup above is.
DV=""
for cand in "$HERE/../../scripts/derive-fixture-readsets.sh" "$HERE/../../../scripts/ai-dlc/derive-fixture-readsets.sh"; do
  [ -f "$cand" ] && { DV="$cand"; break; }
done
[ -n "$DV" ] || broken "cannot locate derive-fixture-readsets.sh in either layout from $HERE -- the trace-site arm would stub a layout nobody checked"
# The redirect is read off the SANDBOX writer line, the only one the in-pool trace site runs (--tracer sandbox).
# A file-wide grep is also satisfied by the fs_usage writer's identical redirect, so moving only the sandbox
# line's log path would leave this check green while the hook watched a file nobody writes.
DV_SB="$(grep -F '&& sandboxed env ' "$DV")" || DV_SB=""
grep -qxF 'WORK="$TRACE_ROOT/w"' "$DV" && grep -qF '>"$WORK/$fx.log" 2>&1 </dev/null' <<<"$DV_SB" && grep -qxF '  raw="$WORK/$fx.raw"' "$DV" \
  || broken "the deriver's sandbox writer no longer sends the fixture's output to \$TRACE_ROOT/w/<fx>.log beside <fx>.raw -- the hook's trace-site watch path and this arm's stub are both stale"
st_trace() {                   # st_trace <hook> <tag> <t|r> -> prints the unit's verdict, or BROKEN
  local h="$1" R="$WORK/trace.$2" p
  mkdir -p "$R/t/tests/fixtures/u" "$R/out/.log" "$R/out/.dur" "$R/out/.pr" "$R/out/.lt" "$R/tmp"
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
i=0; while [ $i -lt $((4 * CSP_STALL)) ]; do i=$((i + 1)); echo "line $i" >> "$f"; sleep 1; done
: >> "$W/u.log"; cp "$W/u.log" "$ip/log"; echo 0 > "$ip/rc"
FX
  ( cd "$R/t" && TMPDIR="$R/tmp" CSP_TR_PIDS="$R/pids" CSP_TR_KIND="$3" CSP_STALL="$ST" \
     AI_DLC_FX_OUT="$R/out" AI_DLC_FX_TRACE="$R/tmp/trace" AI_DLC_FX_TRACE_LIST="u" AI_DLC_FX_DV="$R/dv.sh" \
     POOL_STALL="$ST" POOL_WALK="$POOL_WALK" bash -c "$(cat "$R/body.sh")" _ tests/fixtures/u/ ) >/dev/null 2>&1
  [ -s "$R/pids" ] && while read -r p; do kill -KILL "$p" 2>/dev/null; done < "$R/pids"
  [ -s "$R/pids" ] || { echo BROKEN; return; }
  cat "$R/out/u" 2>/dev/null || echo none
}
v="$(st_trace "$HOOK" t t)"
[ "$v" = ok ] && ok "(t) a traced unit whose only progress is the fixture's output under the trace root is ok, not refused" \
              || bad "(t) a traced unit progressing only through its output was not ok (verdict $v)"
v="$(st_trace "$HOOK" r r)"
[ "$v" = REFUSED ] && ok "(r) a traced unit whose only growth is the stream capture (.raw) is REFUSED -- stream reports are not progress" \
                   || bad "(r) a traced unit growing only its .raw was not refused (verdict $v) -- a hung traced unit would never be refused"
# st-x: the trace site does not watch the fixture's output, so (t) is REFUSED -- the defect itself.
if mutx st-x '; wx="$tr/w/$b.log"' ''; then
  v="$(st_trace "$MUT" st-x t)"
  [ "$v" = REFUSED ] && ok "st-x without the fixture's output watched a traced output-only unit is REFUSED -- the watch is what keeps (t) alive" \
                     || bad "st-x (t) was not refused with the trace-site watch removed (verdict $v)"
fi
# st-r: the watch widened to the whole work dir takes in the .raw, so (r) is never refused.
if mutx st-r 'wx="$tr/w/$b.log"' 'wx="$tr/w"'; then
  v="$(st_trace "$MUT" st-r r)"
  [ "$v" = ok ] && ok "st-r with the whole work dir watched a .raw-only unit is never refused -- watching the .log alone is what refuses (r)" \
                || bad "st-r (r) was still refused with the work dir watched (verdict $v)"
fi
unset CSP_PIDS CSP_FIFO CSP_STALL

# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are
# emitted from inside a conditional: an assertion that never executed prints nothing,
# and a short green report reads exactly like a complete one. This is the same
# property the hook itself now asserts about its own workers, one layer out.
EXPECTED_ASSERTIONS=50
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
