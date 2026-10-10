# Carry-over backlog

Items this repo owes itself. An entry lives here when it is real, measured, and **not the
subject of any live plan** — the state that previously had no home, so it survived only by
being written into a plan about something else and vanished when that plan was discharged.

**This is the DISTRIBUTION's backlog, and it is not a push-candidate ledger.** A consumer's
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` tracks what that consumer wants pushed
UPSTREAM to ai-dlc, and its receipts resolve against a pull's `theirs` ref with the verbs
`theirs_has` / `theirs_lacks`. This file tracks what ai-dlc owes ITSELF, its receipts resolve
against this working tree, and its verbs are `sh` / `has` / `lacks`. The two grammars are
mutually unreadable by each other's engine on purpose. Entry ids are `BL-`, never `PC-`.

**Read by** `scripts/backlog-reverify.sh`, which executes each entry's `verify:` receipt and
emits a status. **Rotated by** `scripts/backlog-rotate.sh`, which moves closed entries to
`docs/backlog.archive.md` — it moves, it never deletes. Neither ships; both are
distribution-only, as `core/fixtures/plan-shape/.dist-only` already is.

## Receipts

```
verify: sh <one-liner>              exit 0 = the fix is present -> CLOSE-CANDIDATE
                                    exit 9 = the receipt cannot measure its subject -> NEEDS-REVIEW
                                    any other non-zero = still reproduces -> STILL-LIVE
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A receipt runs from the repo root with stdin closed, so it names
any input it reads as a file. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:334-335` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2929` reads it the other way — **exit 0
means the entry STILL REPRODUCES**, and non-zero proposes CLOSE-CANDIDATE. Carrying this file's
rule into a consumer receipt writes a predicate that proposes closing a LIVE defect, which is
the one direction that loses data permanently. Check which file your receipt lands in before
you fix its polarity, and read the emitter rather than either header.

**In a consumer receipt, guard the unresolvable subject too.** A RENAMED subject also exits
non-zero there, so a relocation reads as an absorption that never happened; `[ -n "$s" ] ||
exit 127` makes it NEEDS-REVIEW instead. This file's engine needs no such guard, because its
non-zero direction is the one that keeps the entry open.

**When you must use `has`/`lacks`, anchor on a token the fix CANNOT BE WRITTEN WITHOUT** — a
flag, a path, a function name — never a phrase describing the fix. The consumer's engine
detects that error by reading a third ref; this one has no third ref to read, so the rule is
enforced by the author and by review, not by the tool. `core/fixtures/ledger-reverify-unfalsifiable/README.md`
is the measurement: 13 entries on the reference consumer carried predicates that could never
have gone green, and would have reported "still open" forever.

**A closed entry is annotated in place and left for rotation**, in the form
`**LANDED (v<version>, verified <sha>).**` — the annotation FORM is what the rotator keys on,
never the word anywhere in prose, because an entry that merely discusses landing something is
not a closed entry.

## BL-465 — the suite-pole guard compares only at pool widths someone hand-calibrated

**DEFECT.** Operator ruling, batch 202. `docs/suite-pole-baseline.tsv` holds rows only for pool widths 12 and 16, and
`scripts/validate-suite-pole.sh` SKIPs at any other width: a push at `AI_DLC_FIXTURE_JOBS=8` printed
`SKIP -- pool width 8 has no baseline row (widths with a row: 12 16)`. The operator's spec: every gated push records its
pole result keyed by the width it ran at, and the guard compares against that width's own recorded history, so any width
the operator uses is covered without hand calibration. A guard that skips at every width nobody calibrated reads exactly
like one that passed.

verify: manual -- close when a gated push at a width with no prior row records one, and the next push at that width compares against it instead of printing SKIP.

**The manual close above is the operative receipt** (`scripts/backlog-reverify.sh` reads only an entry's first `verify:`
line), and it stays so: only a real gated push exercises the hook's width sidecar. The BEHAVIOURAL receipt for the
validator half is the fenced block at the end of this entry, described in the batch 216 paragraph above it.

**Two rulings landed with the fix, batch 204, by the coordinator after the tip adversary measured B2 wrong.** B(W) is the
max of EVERY usable row at the width since its rows were last dropped -- not of the 3 most recent, which with admission at
or below B ratcheted one way: calibrated at 500/520/510 then 300x3, every ordinary loaded figure from 410 to 500 failed.
And a tracked row is a CALIBRATING SEED while its width has fewer than 3 history rows: compared and reported, recorded,
never a FAIL -- the operator ruled the hand-calibrated 12/16 rows the defect, and a seed that could block would stop the
history that replaces it from forming. A recorded run also consumes the width sidecar, so one published measurement is
one history row however often it is re-read.

**The re-push bypass is closed in the same branch.** `fixture_suite_step` records the content key before the pole step
runs, so a push red on the pole alone used to leave a key that let the re-push skip the suite and hand the guard
`/dev/null`. `pole_guard_step` now removes `$KEY_RECORD` when the validator exits 1, so the next push measures again --
which matters at every width now that the guard fires at every width.

Scored at batch 204 against the tip: base exit 1 (it prints `SKIP -- pool width 4 has no baseline row`), tip 0,
admits-above-B 1, K-window-restored 1, history-never-read 1, SKIP-kept 1, records-at-coverage-SKIP 1.

**PARTIAL, re-adjudicated batch 209: the code is done and the manual close is unreachable on an ordinary push.** The
validator no longer SKIPs on a missing width (`scripts/validate-suite-pole.sh:653`): a width with no rows CALIBRATES
(`:756-763`) and `record_pole` (`:591-621`) appends a history row whenever it runs. A row is written only when ALL of
these hold: the suite was not skipped on its content key (`.githooks/pre-push:2067`); no earlier push's read-set trace is
still running (`:1962-1966` sets `READSET_TRACE_OVERLAP`, `:2076-2080` then hands the guard `/dev/null`); the pool was
green with a non-empty durations file (`:1980-1981`); this run timed at least `COV_MIN=90` percent of the cumulative
record's cost (`validate-suite-pole.sh:181`, checked at `:744-748`); and the `.jobs` sidecar equals `--jobs` (`:603`).
Batch 208's open question is answered: its width-4 gate printed `SKIP -- coverage 56.86% is below 90%`. Every gate since
the last width-12 row failed one condition: coverage SKIPs at 47.86, 50.63 and 56.86 percent, trace-overlap SKIPs on
every push whose predecessor's post-green trace was still alive (0.749.0 twice, 0.752.0, and 0.754.0's own gate at
width 4, which printed `SKIP: a read-set live trace overlapped this run`), and a no-measurement SKIP on 0.750.0.
`COV_MIN=90` was calibrated against 220 of 227 fixtures dispatched (`:96-103`, `:178-180`); read-set keys now dispatch
about 70 of 251, and no keyed push has yet reached the floor: the highest measured is 0.754.0's gate, whose 70 timed rows
replayed through the shipping validator on copies of the live durations read `coverage 83.24%` (54129s of 65021s), where
the earlier "roughly 57 percent" was a prediction from fixture count. Lowering the floor would admit exactly
the near-solo figure the guard exists to refuse. The three existing rows all came from full-suite runs at 99.8 percent.
No code remedy without an operator ruling on what a comparable measurement is under read-set skipping; the guard is
refusing correctly and the close keys on an event both mechanisms make rare.

**OPERATOR RULING, batch 215: redefine coverage over the DISPATCHED set.** A keyed push compares its pole against
the history of the fixtures it actually ran, and records a row keyed on width and on that set; `COV_MIN` is not
lowered. Buildable: `scripts/validate-suite-pole.sh:181` and the coverage check at `:744-748`, with the hook's
`.last` as the dispatched set. Ships from the main checkout detached at its release commit if the hook changes.

**BUILT, batch 216: per-unit history of EVERY dispatched unit (option (a)), count-banded, with a regime ceiling.**
The design changed four times in review.
- **Per unit, not the width's pole.** A suite pole is undefined when the dispatched set varies. On the real 0.760.0
  `.last`, a keyed run at the same 117-unit count that dispatched an unchanged `adversarial-shard-merge-mutants`
  (1132s) FAILED against `self-update-gate`'s 606s, though nothing grew. So this run's pole unit is compared only
  against history rows naming that same unit, at the same width, from a dispatch whose count is within
  +-`COUNT_BAND`=25% of this run's. A unit is never failed against another unit's figure.
- **Option (a), operator ruling.** Every recorded run appends one row per dispatched on-disk unit, not only the
  pole's. So a unit that grows and overtakes the pole is judged against its own earlier, cheaper rows. With
  pole-only rows it calibrated at its grown figure.
- **Admission is per unit.** Each unit's row is admitted by that unit's own rule:
  - at or below its B when it has comparable rows;
  - within the regime ceiling when it has 3 rows and none comparable;
  - freely while it calibrates.

  A refused unit is counted on one summary line. A FAILing run appends nothing.
- **The regime ceiling replaces FROZEN.** A unit with 3 rows and none comparable FAILS `GROWN (regime)` past its own
  max plus `REGIME_BAND`=100%. Within that, it records and the new count range calibrates. FROZEN had passed a 13x
  regression at exit 0. `REGIME_BAND` is uncalibrated. On copies of the live record and `.last`, all 115
  comparable keys read 1.000 and 0 disagree, against a perturbed-key control that read 1. No pre-fold figure
  exists to calibrate it, and the per-unit rows recorded from now on are the first data that can.
- **One append per run, spelling pinned.** awk builds the rows and one `printf '%s' "$ROWS" >> "$HIST"` writes
  them. Under concurrency, awk-direct appends tore 2-112 lines; shell printf tore 0 of 400 up to 14KB on APFS.
  That is a measurement, not a guarantee.
- **The share is printed and is not an exit.** Legacy 5-column and malformed rows are never usable.

Comparability rates over the last 21 measuring commits (runs with at least 3 comparable earlier rows):

| Predicate | Runs |
|---|---|
| exact dispatched set | 0/21 |
| 90% cost-weighted Jaccard overlap of sets | 2-5/21 |
| load within +-25% | 10-17/21 |
| dispatched count within +-25% | 10-15/21 |
| same pole unit, count within +-25% | 10-15/21 |
| pole unit DISPATCHED in 3+ earlier runs, count within +-25% | 10-15/21 |

A 20000-row history costs the validator 0.63-0.75s, against 0.27-0.32s on an empty one. The stated acquittals
are in the validator's header:
- a unit's first 3 dispatches at a width;
- a unit new to the suite that is the pole from its first run;
- a regression shipped with a rename or shard;
- the noise ratchet;
- a regression under 2x at a dispatch count new to its unit.

The header, under COMPARABILITY, is the description, and the `suite-pole-guard` fixture's arms are its probes.
The fenced receipt below runs under `set -uo pipefail`. It drives the validator with the hook's argv in a fresh
git repo:
1. A 67.85%-share keyed run records.
2. Three runs of fx1 at 11 units calibrate fx1 and record fx2..fx11 beside it.
3. Every unit 40% slower FAILS `GROWN`.
4. fx2, cheap beside the pole, grows to 1000 and FAILS against fx2's own 100.
5. An unchanged heavy fx12 newly dispatched calibrates for fx12.
6. fx1 600 at a novel count FAILS `GROWN (regime)` and appends nothing.
7. fx1 700 at a count in band FAILS against fx1's own 150.

Scores, batch 216:

| Subject | Exit |
|---|---|
| tip | 0 |
| base (origin/main d03d5bd9) | 1 |
| ffe7cdb6 | 1 |
| record-pole-only mutant | 1 |
| the round-3 adversary's stub (`tip3_receipt.sh`) | 1 |

```
V="$PWD/scripts/validate-suite-pole.sh"; [ -f "$V" ] || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; R="$(mktemp -d)" && git init -q "$R" && G="$(git -C "$R" rev-parse --path-format=absolute --git-common-dir)" && mkdir -p "$R/docs" && echo 0 > "$R/VERSION" && for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do mkdir -p "$R/core/fixtures/fx$i" && echo 'exit 0' > "$R/core/fixtures/fx$i/run.sh"; done && printf '# history-band: 33\n# band: 15\n# jobs: 12\n# fixtures: 18\nfx1 100\n' > "$R/docs/suite-pole-baseline.tsv" || exit 9; L="$G/ai-dlc-fixture-durations.last"; D="$G/ai-dlc-fixture-durations"; H="$G/ai-dlc-suite-pole.history"; hook() { cp "$L" "$D"; echo 4 > "$L.jobs"; o="$(cd "$R" && bash "$V" --durations "$L" --record "$D" --jobs 4 2>&1)"; c=$?; }; run() { rp="$1"; rn="$2"; rs="$3"; printf 'fx1 %s\n' "$rp" > "$L"; i=2; while [ "$i" -le "$rn" ]; do printf 'fx%s %s\n' "$i" "$rs" >> "$L"; i=$((i + 1)); done; hook; }; rows() { if [ -f "$H" ]; then awk -F'\t' -v u="$1" '$2 == u { n++ } END { print n + 0 }' "$H"; else echo 0; fi; }; printf 'fx1 60\nfx2 35\n' > "$L"; printf 'fx1 60\nfx2 35\nfx3 45\n' > "$D"; echo 4 > "$L.jobs"; o="$(cd "$R" && bash "$V" --durations "$L" --record "$D" --jobs 4 2>&1)"; c=$?; [ "$c" -eq 0 ] && [ "$(rows fx1)" -eq 1 ] || exit 1; : > "$H"; for n in 1 2 3; do run 150 11 100; [ "$c" -eq 0 ] && grep -qF "CALIBRATING ($n/3) for fx1" <<<"$o" || exit 1; done; [ "$(rows fx1)" -eq 3 ] && [ "$(rows fx2)" -eq 3 ] || exit 1; run 210 11 140; [ "$c" -eq 1 ] && grep -qF 'GROWN: fx1 at 210s against baseline fx1 at 150s' <<<"$o" || exit 1; printf 'fx1 150\nfx2 1000\n' > "$L"; i=3; while [ "$i" -le 11 ]; do printf 'fx%s 100\n' "$i" >> "$L"; i=$((i + 1)); done; hook; [ "$c" -eq 1 ] && grep -qF 'GROWN: fx2 at 1000s against baseline fx2 at 100s' <<<"$o" || exit 1; printf 'fx1 150\n' > "$L"; i=2; while [ "$i" -le 10 ]; do printf 'fx%s 100\n' "$i" >> "$L"; i=$((i + 1)); done; printf 'fx12 1132\n' >> "$L"; hook; [ "$c" -eq 0 ] && grep -qF 'CALIBRATING (1/3) for fx12' <<<"$o" && [ "$(rows fx12)" -eq 1 ] || exit 1; run 600 17 100; [ "$c" -eq 1 ] && grep -qF 'GROWN (regime): fx1 at 600s against its own max 150s' <<<"$o" || exit 1; [ "$(rows fx1)" -eq 4 ] || exit 1; run 700 14 100; [ "$c" -eq 1 ] && grep -qF 'GROWN: fx1 at 700s against baseline fx1 at 150s' <<<"$o" || exit 1; exit 0
```

## BL-474 — measure the first cross shard's serial tail before ruling on it

**DEFECT, open by operator ruling, batch 204.** `0.744.0` shards code review and QA execution across their part agents,
but the first cross shard still runs the one canonical suite run and every replay a part HANDED OVER, all in the frozen
worktree (Rule 28, "Code review and QA shard their execution too"; `BL-464`'s Track B paragraph). A hand-over is an AC
whose replay cannot reach GREEN in a fresh detached worktree at the frozen sha, so a per-group fresh copy repeats the
failure. The operator ruled, choosing among build-it-now, accept-it-serial and measure-first: **measure first, then
decide.** Until then the residue is recorded as not serial by design, never as a ruling that it may stay serial.

Measure on the reference consumer's first sharded code review or QA after it pulls `0.744.0`, from the shard directory
`merge-review-shards.sh` joins, read-only:
- the part count K and the cross group count G;
- the hand-over count N, from the part shards' `handovers: <n>` lines, and the `handover-run:` lines in the first cross
  shard, which must equal N;
- the first cross shard's wall clock from its dispatch to its file's final write, split into the canonical suite run and
  the hand-over replays, against the slowest part shard's.

Then put the measured tail to the operator with three choices, each with a marked recommendation drawn from the numbers.
**Shard it:** each cross group replays its share in an APFS clone (`cp -c`) of the frozen worktree with its setup state,
never a fresh checkout. It is unproven against absolute paths, local services, ports and databases inside the
environment, and is built as its own release with its own adversary. **Rule it serial by design:** Rule 28 and `BL-464`
record the operator's ruling. **Keep it open:** take a second sprint's measurement.

verify: manual -- close when the measurement above is recorded in this entry from a real consumer review and the operator has ruled on it.


## BL-481 — two fixtures cannot be traced even on an idle box, and ten run on every push

**DEFECT, filed at batch 204's close.** The `0.745.0` map trace, run in a full clone with nothing else on the machine
(load 3-5), OMITTED `readset-skip-digest-mutants` (the sandbox log stream dropped reports 1491 times) and
`self-update-gate` (958). Those are properties of the fixtures under the tracer, not of load. The gate that shipped
`0.745.0` printed 10 of 248 fixture directories UNMAPPED and therefore always run:
`adversarial-shard-merge-mutants check-24-adversarial-convergence implementation-join-yield procsub-staged-refusal-boot
readset-skip-digest-mutants remediator-shard-join-mutants review-shard-merge-mutants self-update-fixture-log-mutants
self-update-gate subject-partition`. Derive the current set from any push's `read-set map: ... UNMAPPED` line rather
than from this list.

The hermetic-fixtures program (`docs/plans/hermetic-fixtures-poc.md`, ruled GO) keys a declared fixture without a
trace, so a declaration for each of these closes it for that fixture. Until then each costs its full loaded run on
every push.

**LIVE, re-derived batch 209.** The 0.754.0 gate's line read 7 of 251 UNMAPPED: `check-24-adversarial-convergence
hermetic-runner implementation-join-yield procsub-staged-refusal-boot readset-skip-digest-mutants self-update-gate
subject-partition`. Three of the original ten left by declaration or trace (`adversarial-shard-merge-mutants`,
`remediator-shard-join-mutants`, `self-update-fixture-log-mutants`, and `review-shard-merge-mutants` by committed rows);
`hermetic-runner` joined. `readset_trace_add`
(`.githooks/pre-push:812-814`) stops re-tracing a fixture at three discards on one key, so they stay unmapped until a
declaration lands or their key changes; re-derived from the local map (`.git/ai-dlc-fixture-readsets.local`, the one the
hook reads), six of the seven sit at `#discards 1` under the key the deriver's current sha minted, so each will be traced
twice more before it is held, and `subject-partition` holds 45 local trace rows with no discard row while the committed
map holds none for it. One of the seven, `implementation-join-yield`, is now declared, so six remain. The same morning's trace also OMITTED `adversarial-shard-merge-mutants` (3701
stream drops), `foreground-budget-deny` (89), `hermetic-runner` (551) and `readset-skip-digest-mutants` (786), so the
untraceable set is wider than the two filed.

**OPERATOR RULING, batch 215: `hermetic-runner` is OUT of this entry's set.** It is the runner's own self-probe and
is undeclared by design. Measured at `31617801` (0.760.0): `self-update-gate` and the class-b four carry
`inputs.decl` (0.759.0), and `check-24-adversarial-convergence` plus its `-b`, `-c`, `-d` shards do (0.760.0);
`procsub-staged-refusal-boot` was sharded into `-boot`, `-boot-b`, `-boot-c` and NONE of the three is declared, nor
are `procsub-staged-refusal`, `-b`, `-c` (control: `implementation-join-yield` declared, an impossible name absent).
The six procsub directories are undeclared BY RULING (0.760.0's CHANGELOG: they read this repo's own history, and
pinned blobs failed I104, I113 and I65 as a second corpus), so their close path is a committed trace, not a
declaration. The 0.760.0 gate's line read 7 of 269 UNMAPPED: `hermetic-runner`, the six procsub directories and
`subject-partition`. The entry closes on the first push whose read-set line reports `hermetic-runner` as the ONLY
fixture UNMAPPED.

verify: manual -- close when a push's read-set line reports no fixture other than `hermetic-runner` UNMAPPED, by a trace or by a declaration.

**Re-derived batch 214 (0.760.0).** `check-24-adversarial-convergence` is declared (four shards). `procsub-staged-refusal-boot`
is sharded into three `.dist-only` directories and reported UNSANDBOXABLE: it stages pre-fix engines by
`git -C "$TREE_TOP" show <sha>:core/skills/ai-dlc-update/reconcile/<file>`, and committing the blobs under `core/` as
fixture data was built for the sibling `procsub-staged-refusal` and failed enforcement-map arms I104, I113 and I65 as a
second corpus. It leaves this list only by a committed trace; its three shards are three such traces. `hermetic-runner`,
`self-update-gate` and `subject-partition` are untouched here.

Moved here from BL-493 in batch 220, because its subject (the post-green trace step) is this entry's.
**Re-derived batch 219 (0.763.0).** The first half shipped: the deriver drops `--level debug`, the liveness window is
~10s, `readset-sandbox-root-clause` retries up to ten windows. A second defect in the same tracer, measured on this
box: a consumer's pre-push hook (`/Users/n8/git/graph/.githooks/pre-push`, pid 47147) survived its `git push` by 42
minutes with parent init, no client and no session, because the post-green trace step blocks on nothing that dies
with the push. It spawned one `log stream --level debug` subscription per fixture the whole time and held
`diagnosticd` at 30-50% CPU and `fseventsd` at 100% until the operator stopped it by its process group. The trace
step must hold its parent's pid and exit when that pid is gone; until it does, an orphaned hook is a load generator
nobody started on purpose. This stays open on the UNMAPPED receipt above; the orphan is a second subject and needs
its own receipt when the fix is built.

**The orphan subject's receipt, batch 220 (0.768.0).** Pid 47147 was the DETACHED trace subshell, not the hook's main
body, so a parent-pid tie is the wrong fix: the trace is detached so the push never waits. The fix is a wall-clock
ceiling (`readset_trace_ceiling`: 3x the listed fixtures' recorded durations, floor 600s, cap 20000s) enforced by a
watchdog that kills the deriver's own process GROUP, then writes `exit timeout` and releases the lock. It is a HANG
guard: the incident's 42-fixture list would get 7272s and was a slow, working trace. The fixture arm that holds it is
`readset-skip-b` (t1); the fenced receipt below runs under `set -uo pipefail` from the repo root. It launches the real
`readset_live_trace` from the pre-push pool block against a stub deriver that forks a sleeping grandchild and never
exits, at a 2s ceiling, and exits 0 only if the lock is released, the deriver and its grandchild are both gone, and
the status reads `exit timeout`. This receipt is the orphan subject's; the entry's operative `verify:` above stays the
UNMAPPED one.

| Subject | Exit |
|---|---|
| fix (b220-ceiling) | 0 |
| base 9800057e | 1 |
| ceiling computed, never enforced (watchdog exits without signalling) | 1 |

```
H="$PWD/.githooks/pre-push"; [ -f "$H" ] || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; W="$(mktemp -d)" || exit 9; sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$H" > "$W/pool.sh"; T="$W/t"; mkdir -p "$T/core/scripts" "$T/core/fixtures/gamma" "$W/tmp" "$W/o/.log" && printf 'exit 0\n' > "$T/core/fixtures/gamma/run.sh" && printf '#!/bin/bash\nsleep 600 </dev/null >/dev/null 2>&1 &\necho "$!" > "$RC_GC"; echo "$$" > "$RC_DP"\nwhile :; do sleep 1; done\n' > "$T/core/scripts/derive-fixture-readsets.sh" && git init -q "$T" && git -C "$T" add -A && git -C "$T" -c user.email=r@r -c user.name=r commit -qm s || exit 9; printf 'gamma\n' > "$W/o/.trace"; : > "$W/o/.trace.held"; printf ok > "$W/o/gamma"; printf '  ok\n' > "$W/o/.log/gamma"; export RC_GC="$W/gc" RC_DP="$W/dp" AI_DLC_READSET_LIVE_TRACE=1 AI_DLC_READSET_TRACE_CEILING=2 TMPDIR="$W/tmp/"; cd "$T" || exit 9; . "$W/pool.sh" 2>/dev/null; readset_live_trace "$W/o" >/dev/null 2>&1; i=0; while { [ ! -s "$W/gc" ] || [ ! -s "$W/dp" ]; } && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done; gc="$(cat "$W/gc" 2>/dev/null)"; dp="$(cat "$W/dp" 2>/dev/null)"; case "$gc$dp" in ''|*[!0-9]*) exit 9 ;; esac; kill -0 "$gc" 2>/dev/null || exit 9; lk="$GITDIR/ai-dlc-fixture-readsets.local.lock"; i=0; while [ -d "$lk" ] && [ "$i" -lt 150 ]; do sleep 0.1; i=$((i+1)); done; r=1; [ ! -d "$lk" ] && ! kill -0 "$gc" 2>/dev/null && ! kill -0 "$dp" 2>/dev/null && grep -qx 'exit timeout' "$READSET_LOCAL.status" && r=0; kill -KILL "$dp" "$gc" 2>/dev/null; exit "$r"
```

**Re-derived batch 220 (0.767.0 gate, then 0.768.0).** The 0.767.0 gate's line read **3 of 277 UNMAPPED**:
`fixture-git-env-seam ledger-status-vocabulary validator-fork-budget`. `self-update-join-gate`, which no `git.decl`
form can seed (it clones and walks 1483 commits of history), left the set because that gate's in-pool trace RECORDED
it. 0.768.0 declares `fixture-git-env-seam` (`git.decl seed`; sandboxed rc 0, 21 arms; dropping its `!` input fails W
and V) and `ledger-status-vocabulary` (`git.decl seed`; sandboxed rc 0, 11 assertions; dropping `templates/` fails I22
and I119; stripping the sentinel fires `REQUIRED input … never consumed`). **`validator-fork-budget` stays
undeclared**: sandboxed it counts 3327 forks against `FORK_BUDGET=3324`, unsandboxed 3323. Its headroom was 4 at
0.766.0 (3320) and 0.767.0's `READSET_KEYROWS` sentinel arm in I66 spent 3 of them, so the budget is at its edge
outside the sandbox too. The entry closes when that fixture leaves the UNMAPPED line, by a recorded trace or by a
declaration whose sandboxed fork count fits the budget.


## BL-495 — fixtures declare whole directories as inputs, so one edit re-keys fixtures that may never read it

**DEFECT.** The 0.764.0 gate ran 47 of 277 fixtures although the release changed one shipped script
(`core/scripts/hermetic-run.sh`), one fixture's `run.sh`, and new `.decl` files in eight fixture directories. A
fixture whose `inputs.decl` declares a directory is re-keyed by any edit under it, and 31 `inputs.decl` files declare
`core/` (14) or `core/scripts/` (17). How many of those fixtures actually read the file whose change selected them is
NOT measured: a name-reference heuristic is not a read, because some (the `enforcement-map-*` units, through
`validate-enforcement-map.sh`) read every file under `core/` by content.

The fix narrows each broad declaration to the files the fixture reads, and each narrowing is checked against a
read-set trace of that fixture. An under-declared fixture is skipped when a file it reads changes, silently, so the
narrowing must never be justified by a declaration count alone.

verify: manual -- close when every `inputs.decl` line declaring exactly `core/` or `core/scripts/` is either narrowed against a read-set trace of its fixture or carries a stated reason it reads that whole directory by content

**Re-derived batch 220 (0.767.0).** The count is 29 rather than 31: of 233 `inputs.decl` files, 14 carry a whole
line `core/` and 15 a whole line `core/scripts/` (`grep -lxE`, control `ZZ-never/` 0). The receipt was `sh exit 9`,
which scored nothing and, once BL-493 closed, left the ledger with no scorable receipt and failed the gate's
`backlog receipts` step (R2); it is now a manual close stating the condition, because no mechanical predicate can
tell a narrowed declaration from an under-declared one without the trace.

## BL-496 — two shipped fixtures consume their REQUIRED input only in the distribution layout, and red on every consumer

**DEFECT, filed at batch 221.** Filed by the consumer as
`PC-S317-HERMETIC-REQUIRED-INPUT-NEVER-CONSUMED-REDS-TWO-SHIPPED-FIXTURES`. `core/scripts/hermetic-run.sh` requires a
whole-line `HERMETIC-CONSUMED <path>` for each `!` input in a fixture's output. `consumer-machinery-inventory` and
`extract-push-flag-decision` resolve their `!` input through an if/elif chain over both layouts and echoed the sentinel
only in the `core/` branch, so under an installed consumer's runner both report `required_missing=1` and rc 1. The
regression is 0.763.0 (`6f9da269`). A dynamic sweep of all 157 shipped `!` fixtures through an installed consumer's
runner gave 155 rc 0 and these 2 rc 1. Nothing in this repo could fail on it, because no gate here runs a fixture in
the installed layout.

The fix echoes the consumer path in each consumer branch (fix A; the `!` lines stay). The binding is
`scripts/validate-hermetic-consumption.sh`, a static scan run only by the `.dist-only` fixture
`core/fixtures/hermetic-consumption/`. Over the 157 shipped `!` fixtures it flags exactly these two at base `2db3f4c0`
and 0 at the fix. It scores 10 of 240 `!` inputs, and its header states the reach, so a clean result is a floor.

The receipt runs from the repo root under `set -uo pipefail`. It exits 9 when the validator, the mapper or either
fixture's `!` line is missing, or when the validator's self-probe refuses. It exits 1 when the scan names either fixture
or reports any flagged input. Scored against the fix tree, and against copies of that tree's scan inputs (VERSION,
`core-paths.sh`, the validator, `core/fixtures/`) with one variant of `consumer-machinery-inventory/run.sh`:

| Subject | Exit |
|---|---|
| fix (both consumer branches echo) | 0 |
| base: both `run.sh` at `origin/main` 2db3f4c0, fix validator | 1 |
| dist-only echo (the consumer echo removed) | 1 |
| `.bak` near-miss echoed in the consumer branch | 1 |
| top-of-file echo above the resolution | 1 |
| fix B: the declared spelling after the chain's `fi`, both branch echoes removed | 0 |
| a literal `origin/main` checkout (no validator) | 9 |

verify: sh V=scripts/validate-hermetic-consumption.sh; [ -f "$V" ] && [ -f core/scripts/core-paths.sh ] || exit 9; for f in consumer-machinery-inventory extract-push-flag-decision; do grep -q '^!' "core/fixtures/$f/inputs.decl" || exit 9; done; o="$(bash "$V" 2>&1)"; r=$?; [ "$r" = 2 ] && exit 9; grep -q '^self-probe: ok' <<< "$o" || exit 9; grep -Eq '^FAIL: core/fixtures/(consumer-machinery-inventory|extract-push-flag-decision):' <<< "$o" && exit 1; grep -Eq '^hermetic-consumption: scanned=[1-9][0-9]* .*flagged=0$' <<< "$o" || exit 1; exit "$r"
