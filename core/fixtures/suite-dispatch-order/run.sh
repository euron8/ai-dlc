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

# --------------------------- 1. dispatch is LONGEST-FIRST, off a SEEDED record ------
# THE COSTS ARE SEEDED, AND THAT IS THIS ARM'S SUBJECT RATHER THAN A CONCESSION MADE TO
# GET IT GREEN. It used to give the three units real sleeps, run the pool once to record
# what they cost, and assert the second run's order against a hardcoded triple. That made
# the machine's scheduler the judge: a worker records `$SECONDS` off its OWN shell
# (`core/git-hooks/pre-push:541` — the hook this fixture RESOLVES first, whose numbering
# is not `.githooks/pre-push`'s), so under load the `sleep 0` unit's cost can RISE to meet
# the `sleep 1` unit's and the arm reads `zzz aaa mmm` on a tree with nothing wrong with
# it. Measured across pooled gate runs on trees that could not reach dispatch ordering at
# all: mostly `ok`, intermittently `FAIL`. A unit that fails intermittently is the shape
# that gets re-run until green, and a re-run-until-green unit certifies nothing.
# (`docs/backlog.archive.md`, `BL-008`.)
#
# IT ONLY HAS TO REACH A TIE, AND THAT IS WHY THE OLD MARGIN LOOKED SAFE AND WAS NOT.
# `sort -k1,1nr`'s `-r` is KEY-SCOPED, so tied keys fall through to a FORWARD whole-line
# last-resort compare -- `aaa 1 / mmm 1 / zzz 3` sorts to `zzz aaa mmm`, against an untied
# control `aaa 0 / mmm 1 / zzz 3` sorting to `zzz mmm aaa`. The cheaper unit never has to
# OUTRANK the dearer one; measured over 30 loaded repetitions it never did, and the arm
# failed anyway. The contended resource is `bash -c` startup, not CPU: pure spinners do not
# reproduce this and a fork storm does.
#
# So the seeded costs below are separated to make a TIE unconstructible, which is a
# different requirement from making an inversion unlikely.
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
#
# THE SAME HOLDS FOR THE THIS-RUN RECORD, and it is asserted here rather than left to the
# substring match above. `.git/ai-dlc-fixture-durations.last` is a SECOND file written by
# the same block, published only after a green pool; a copy of it at the tree root would be
# hashed by the content key exactly as the merged record would, and neither the arm above
# nor any other arm in this file looks at it. The positive conjunct (three rows, one per
# dispatched unit) is what keeps this from passing against a publish that never happened --
# an absent file is trivially not in the working tree.
: > "$SDO_TRACE"
rc="$(drive "$T" "$WORK/lpt4.out")"
n_rec="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
case "$n_rec" in ''|*[!0-9]*) n_rec=0 ;; esac
n_last="$(grep -c . "$T/.git/ai-dlc-fixture-durations.last" 2>/dev/null)"
case "$n_last" in ''|*[!0-9]*) n_last=0 ;; esac
if [ "$n_rec" -eq 3 ] && [ ! -f "$T/ai-dlc-fixture-durations" ] \
   && [ "$n_last" -eq 3 ] && [ ! -f "$T/ai-dlc-fixture-durations.last" ] \
   && ! grep -q 'ai-dlc-fixture-durations' <<<"$(git -C "$T" status --porcelain 2>/dev/null)"; then
  ok "both cost records — the merged one and this run's .last — hold one line per fixture under .git/ and git itself cannot see either"
else
  bad "a cost record is not where it must be (merged lines=$n_rec, .last lines=$n_last under .git/, root copies present=$([ -f "$T/ai-dlc-fixture-durations" ] && echo merged || echo no)/$([ -f "$T/ai-dlc-fixture-durations.last" ] && echo last || echo no)) — a record inside the tree is hashed by the key that decides whether the suite runs at all"
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
# NARROWED BY THE READ-SET SKIP ITSELF, WITH AAA'S DIRECTORY KEPT ON DISK. It used to be
# narrowed by MOVING aaa's directory away, which modelled a skipped unit as a deleted one.
# Since the merge prunes every row whose "${FXROOT}${name}/run.sh" is gone (BL-744), that
# shape is the prune's subject, not this arm's -- the two would now disagree about aaa,
# and arm 4c below owns the deleted case. Here a committed map gives each unit one source
# file and only mmm's and zzz's change, so the skip withholds aaa while its run.sh exists.
# `narrow_by_skip` refuses unless exactly mmm and zzz were dispatched. The unit withheld is
# the CHEAPEST one deliberately: losing the cost of the cheapest unit is what flips the
# dispatch order, because an unknown cost sorts first.
#
# AAA'S PRESERVED COST IS SEEDED AT 1 AND IS NEVER MEASURED HERE, because aaa is withheld
# from the run whose record is read. mmm and zzz sleep 2, and `$SECONDS` is
# integer elapsed, so neither can record less than 2 and pool contention only raises it.
# `aaa < mmm, zzz` therefore holds BY CONSTRUCTION rather than by luck. The old form
# asserted the whole triple `zzz mmm aaa` against three MEASURED costs and let the
# scheduler decide the verdict — `BL-008`, and the same defect as arm 1's.
T="$WORK/merge"; seed "$T" "$HOOK" || broken "seed failed"
export SDO_TRACE="$WORK/merge.trace"
mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 2; mkfx_trace "$T" zzz 2
seed_mapped "$T" || broken "could not seed the read-set map for arm 4"
rc="$(narrow_by_skip "$T" merge2 "$SEEDREC")"
case "$rc" in broken:*) broken "arm 4 ${rc#broken:}" ;; esac
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
# THE ARM READS AAA'S POSITION AND NOTHING ELSE. mmm and zzz both sleep 2, so they can TIE
# with each other, and a tie is resolved by `sort`'s last-resort compare rather than by the
# ordering rule -- which is the very thing that made the old form flake. Asking which of
# them lands first would reintroduce the defect inside its own fix. aaa cannot tie with
# either: its 1 is seeded and never measured, and `sleep 2` under integer-elapsed
# `$SECONDS` cannot record below 2.
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

# ------------- 4c. a row whose fixture DIRECTORY IS GONE is pruned by the merge ------
# BL-744. The record kept a row for every fixture it had ever timed, so after a family of
# dirs was retired the top of it named units that no longer exist, and the pole read off it
# was a dead one. The merge keeps a row only while "${FXROOT}${name}/run.sh" exists.
#
# THREE ROWS, ONE PROPERTY APART. `gone` is a dir deleted since its row was written, and it
# must go. `kept` is a live dir the skip did not dispatch, and it must stay at its seeded
# value -- that is arm 4's subject, re-asserted here in the same world so a prune keyed on
# the DISPATCH LIST rather than on the disk fails this arm and not only arm 4. `dead` is a
# dir that still exists with no run.sh, which the dispatch loop does not run either, so the
# prune's test and the list's test are shown to be the same test. The run is GREEN and
# narrowed, so the merge is reached; arm 5 owns the red case.
T="$WORK/prune"; seed "$T" "$HOOK" || broken "seed failed"
export SDO_TRACE="$WORK/prune.trace"
mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 0; mkfx_trace "$T" zzz 0
mkdir -p "$T/tests/fixtures/dead" && : > "$T/tests/fixtures/dead/notes.txt" || broken "could not seed the run.sh-less dir"
seed_mapped "$T" || broken "could not seed the read-set map for arm 4c"
printf 'aaa 1\nmmm 5\nzzz 9\ngone 777\ndead 555\n' > "$WORK/prune.seed" || broken "could not write the arm 4c seed"
rc="$(narrow_by_skip "$T" prune "$WORK/prune.seed")"
case "$rc" in broken:*) broken "arm 4c ${rc#broken:}" ;; esac
pr_gone="$(awk '$1 == "gone" || $1 == "dead"' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
pr_aaa="$(awk '$1 == "aaa" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
pr_n="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)" || pr_n=0
if [ "$rc" = 0 ] && [ -z "$pr_gone" ] && [ "$pr_aaa" = 1 ] && [ "$pr_n" -eq 3 ]; then
  ok "a green narrowed run drops the rows for a deleted dir and a run.sh-less dir and keeps the undispatched live unit at its seeded 1 (3 rows) — the prune keys on the disk, not on the dispatch list"
else
  bad "after a green narrowed run the record holds $pr_n row(s), aaa='${pr_aaa:-gone}', dead rows '$(printf '%s' "$pr_gone" | tr '\n' ',')' (rc=$rc) — a row with no run.sh on disk survives and names a dead pole, or a skipped live unit lost its cost"
fi
unset SDO_TRACE

# ---------------------- 5. a RED pool leaves the record exactly as it found it -----
# BL-591. The merge folded every DISPATCHED unit's cost in whatever the run's verdict, so an ok
# unit of a run that went red elsewhere was recorded at that run's load -- readset-skip-d at 928s
# against 330-502s in every clean gate. The gate is on the RUN: those were ok units, so a per-unit
# gate would have kept them.
#
# BOTH UNITS ARE SEEDED AT 900, a cost no unit here can record (they sleep 0), so a merge that
# happened cannot leave the file byte-identical by coincidence -- with a seed the run could
# reproduce, M5 below would survive on equal values. The RED run is cmp'd whole; the GREEN control
# then asserts a SPECIFIC value, ok's row no longer 900, because the merge re-sorts and normalises
# and "the file changed" is satisfiable by formatting alone.
T="$WORK/red"; seed "$T" "$HOOK" || broken "seed failed"
mkfx "$T" good 0; mkfx "$T" sick 1
printf 'good 900\nsick 900\n' > "$T/.git/ai-dlc-fixture-durations" || broken "could not seed the red-run record"
cp "$T/.git/ai-dlc-fixture-durations" "$WORK/red.before" || broken "could not keep the red-run record's before copy"
rc="$(drive "$T" "$WORK/red.out")"
if [ "$rc" != 0 ] && grep -q 'FAIL  sick' "$WORK/red.out" && grep -q 'ok    good' "$WORK/red.out" \
   && cmp -s "$WORK/red.before" "$T/.git/ai-dlc-fixture-durations"; then
  ok "a pool red on one unit leaves the durations record byte-identical, the ok unit it timed included"
else
  bad "a red pool (rc=$rc) changed the durations record, or did not run as seeded: an ok unit of a red run is recorded at that run's load and becomes a phantom pole"
fi
mkfx "$T" sick 0
rc="$(drive "$T" "$WORK/green.out")"
g_good="$(awk '$1 == "good" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
if [ "$rc" = 0 ] && [ -n "$g_good" ] && [ "$g_good" != 900 ]; then
  ok "the same tree made green records this run's cost (good: 900 -> $g_good), so the red arm above is the gate and not a writer that never runs"
else
  bad "the green control (rc=$rc) left good at '${g_good:-gone}', not this run's cost -- the red arm cannot tell a gated merge from no merge at all"
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
  # BOTH RECORDS, because both are fed from `$out/.dur/`. The merged record and this run's
  # `.last` publish are two readers of one producer, and the mutation removes the producer.
  # A `.last` left non-empty under M3 would be a file written from somewhere other than the
  # workers' own costs — which is exactly what the pole guard would then be comparing against
  # a full-suite baseline.
  if [ "$rc" = 0 ] && [ "$m3_order" = "aaa mmm zzz " ] \
     && [ ! -s "$T/.git/ai-dlc-fixture-durations" ] \
     && [ ! -s "$T/.git/ai-dlc-fixture-durations.last" ]; then
    ok "M3 with the workers not recording their cost neither the merged record nor .last is written and the second run stays in glob order"
  else
    bad "M3 an order or a cost record appeared without the workers recording anything (rc=$rc, order '$m3_order', .last non-empty=$([ -s "$T/.git/ai-dlc-fixture-durations.last" ] && echo yes || echo no)) — the record arm 1 reads is not the one the pool writes"
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
#
# NARROWED THE WAY ARM 4 IS, BY THE SKIP WITH AAA'S DIR KEPT. Narrowed by deleting aaa's dir
# instead, the prune would drop aaa's row under the unmutated hook too, and this mutant would
# score a kill against a state the merge itself produces.
if mut m4 's|\[ -s "\$DURATIONS_RECORD" \] && cat "\$DURATIONS_RECORD"|false|'; then M="$MUT"
  T="$WORK/m4"; seed "$T" "$M" || broken "seed failed"
  export SDO_TRACE="$WORK/m4.trace"
  mkfx_trace "$T" aaa 0; mkfx_trace "$T" mmm 2; mkfx_trace "$T" zzz 2
  seed_mapped "$T" || broken "could not seed the read-set map under M4"
  rc="$(narrow_by_skip "$T" m4b "$SEEDREC")"
  case "$rc" in broken:*) broken "M4 ${rc#broken:}" ;; esac
  n_m4="$(grep -c . "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  case "$n_m4" in ''|*[!0-9]*) n_m4=0 ;; esac
  m4_kept="$(awk '$1 == "aaa" { print $2 }' "$T/.git/ai-dlc-fixture-durations" 2>/dev/null)"
  if [ "$rc" = 0 ] && [ "$n_m4" -eq 2 ] && [ -z "$m4_kept" ]; then
    ok "M4 with the old record not read the same narrowed run cuts it to 2 lines and loses aaa's seeded cost — arm 4 is measuring the merge and not the tree"
  else
    bad "M4 the record still held $n_m4 line(s) with aaa='${m4_kept:-gone}' — arm 4 would pass against a hook that replaces, which is the state this release removed"
  fi
  unset SDO_TRACE
fi

# M5 -- THE RUN-VERDICT GATE REMOVED FROM THE MERGE, and only from the merge. The `.last` publish
# opens with the same `if [ "$rc" -eq 0 ] && [ -s "$out/.durations" ]` text, so the edit is keyed
# on what separates them: the merge line ENDS at `then`, while `.last` continues `; then cp`. awk
# rather than sed, because the replacement carries `&&` and sed would re-insert the match. Exactly
# one line must change, or the mutant would also lift the `.last` gate and be entangled.
M5="$WORK/hook.m5"
M5_OLD='  if [ "$rc" -eq 0 ] && [ -s "$out/.durations" ]; then'
M5_NEW='  if [ -s "$out/.durations" ]; then'
MO="$M5_OLD" MN="$M5_NEW" awk '$0 == ENVIRON["MO"] { print ENVIRON["MN"]; next } { print }' "$HOOK" > "$M5" \
  || broken "could not write the M5 mutant"
m5_diff="$(diff "$HOOK" "$M5")"
n_m5="$(grep -c '^>' <<<"$m5_diff")" || n_m5=0
if [ "$n_m5" -ne 1 ]; then
  bad "MUTANT m5 changed $n_m5 line(s), not 1 -- the merge gate's anchor is not unique, so the mutant proves nothing"
else
  T="$WORK/m5"; seed "$T" "$M5" || broken "seed failed"
  mkfx "$T" good 0; mkfx "$T" sick 1
  printf 'good 900\nsick 900\n' > "$T/.git/ai-dlc-fixture-durations" || broken "could not seed the M5 record"
  cp "$T/.git/ai-dlc-fixture-durations" "$WORK/m5.before" || broken "could not keep the M5 before copy"
  rc="$(drive "$T" "$WORK/m5.out")"
  if [ "$rc" != 0 ] && ! cmp -s "$WORK/m5.before" "$T/.git/ai-dlc-fixture-durations"; then
    ok "M5 with the run-verdict gate removed from the merge, the same red pool rewrites the record -- arm 5 is measuring the gate"
  else
    bad "M5 the ungated merge left the record unchanged after a red pool (rc=$rc) -- arm 5 would pass against the defect BL-591 fixed"
  fi
fi

# M6 -- THE PRUNE REMOVED (BL-744's defect), and M7 -- THE PRUNE KEYED ON A LITERAL
# `core/fixtures/` rather than on FXROOT. Both are driven through arm 4c's world. M6 must leave
# the deleted dir's row in; M7, on the consumer hook this fixture resolves first (FXROOT
# `tests/fixtures/`), must fail arm 4c's predicate -- which is why arm 4c asserts the row count
# and aaa's value and not only the absence of the dead rows.
m67() {                        # m67 <label>  -> prints "<rc> <rows> <aaa> <gone-rows>"
  local t="$WORK/$1" r
  seed "$t" "$MUT" || { echo "broken"; return 0; }
  SDO_TRACE="$WORK/$1.trace"; export SDO_TRACE
  mkfx_trace "$t" aaa 0; mkfx_trace "$t" mmm 0; mkfx_trace "$t" zzz 0
  mkdir -p "$t/tests/fixtures/dead" && : > "$t/tests/fixtures/dead/notes.txt"
  seed_mapped "$t" || { echo "broken"; return 0; }
  r="$(narrow_by_skip "$t" "$1" "$WORK/prune.seed")"
  unset SDO_TRACE
  case "$r" in broken:*) echo "broken"; return 0 ;; esac
  printf '%s %s %s %s\n' "$r" "$(grep -c . "$t/.git/ai-dlc-fixture-durations" 2>/dev/null || :)" \
    "$(awk '$1 == "aaa" { print $2 }' "$t/.git/ai-dlc-fixture-durations" 2>/dev/null)" \
    "$(awk '$1 == "gone" || $1 == "dead"' "$t/.git/ai-dlc-fixture-durations" 2>/dev/null | grep -c . || :)"
}
if mut m6 '/while read -r k v; do \[ -f "\${FXROOT}\${k}\/run.sh" \]/d'; then
  read -r m6_rc m6_n m6_aaa m6_gone <<<"$(m67 m6)"
  [ "$m6_rc" = broken ] && broken "M6 the narrowed world did not build"
  if [ "$m6_rc" = 0 ] && [ "$m6_gone" = 2 ] && [ "$m6_aaa" = 1 ]; then
    ok "M6 with the prune removed the deleted dir's and the run.sh-less dir's rows survive the merge -- arm 4c is measuring the prune"
  else
    bad "M6 the unpruned merge left rc=$m6_rc rows=$m6_n aaa='$m6_aaa' dead-rows=$m6_gone -- arm 4c would pass against the defect BL-744 fixed"
  fi
fi
if mut m7 's|\[ -f "\${FXROOT}\${k}/run.sh" \]|[ -f "core/fixtures/${k}/run.sh" ]|'; then
  read -r m7_rc m7_n m7_aaa m7_gone <<<"$(m67 m7)"
  [ "$m7_rc" = broken ] && broken "M7 the narrowed world did not build"
  # On the consumer layout a literal key prunes EVERY row, `.merged` is then empty, and the
  # `[ -s ]` guard skips the copy -- so the record is FROZEN at its seed (5 rows), never written
  # again. Measured: rc=0 rows=5 aaa=1. Arm 4c's own predicate is what must fail here.
  if [ "$m7_rc" = 0 ] && ! { [ "$m7_n" = 3 ] && [ "$m7_aaa" = 1 ] && [ "$m7_gone" = 0 ]; }; then
    ok "M7 with the prune keyed on a literal core/fixtures/ the consumer-layout record is not the 3-row pruned one (rows=$m7_n) -- arm 4c reads the prune's KEY, not only its presence"
  else
    bad "M7 the literally-keyed prune produced the pruned record anyway (rc=$m7_rc rows=$m7_n aaa='$m7_aaa' dead-rows=$m7_gone) -- arm 4c cannot tell a FXROOT key from one that prunes every consumer row"
  fi
fi

# ------------------------------------------------------------------- floor ---------
# EXPECTED_ASSERTIONS, mandatory since v0.217.0 for any fixture whose arms are emitted
# from inside a conditional: an assertion that never executed prints nothing, and a short
# green report reads exactly like a complete one.
EXPECTED_ASSERTIONS=18
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
