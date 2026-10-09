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


## BL-490 — readset-skip declares two distribution-only scripts, so the hermetic runner refuses it on every consumer

**DEFECT.** PC-S317-READSET-SKIP-DECLARES-DIST-ROOT-SCRIPTS-NO-CONSUMER-HOLDS. All four
`core/fixtures/readset-skip{,-b,-c,-d}/inputs.decl` declared `scripts/validate-enforcement-map.sh` and
`scripts/render-invariant-index.sh`. Neither is installed and `core-paths.sh` maps neither, so on a consumer
`hermetic-run.sh` stops with `declared file absent` and exit 2 for every shard, and every consumer push fails.
Their only reader was the one-hook-widened I66 arm in `readset-skip/run.sh`, which also accounted for five more
declared paths: `gate-validation.md`, `enforcement-map.yaml`, `core-manifest.md`, `setup-sites.md` and
`core/scripts/hermetic-run.sh`. That arm now lives in the `.dist-only` fixture `validator-arm-selection` as the phase
`i66-onehook` in shard a, with the mutant it lacked. The mutant widens `READSET_UNKEYED_TOOLS` in `.githooks/pre-push`
alone, and `--arms I66` must then exit non-zero naming the forked runners, beside an unmutated control that reads OK
at rc 0. All seven lines are removed from the four declarations.

The receipt installs the tree into an empty git repo with `_bmad/`, as `install.sh` requires, and runs
`hermetic-run.sh --key-only` for all four shards on that consumer tree. It then requires the moved phase. Scored under
`set -uo pipefail` in linked worktrees: tip 0, base (`d03d5bd9`) 1, and 1 for a mutant that re-adds
`scripts/validate-enforcement-map.sh` to `readset-skip-c/inputs.decl` alone. On a git-inited
`git -C /Users/n8/git/graph archive HEAD` copy with the readset-skip dirs overlaid, a full
`scripts/ai-dlc/hermetic-run.sh --root <copy> readset-skip` read rc 2 at base, naming both validators; rc 0 at tip
(`readset-skip: PASS (92 assertions)`, `sandbox_files=10`); and rc 2 with the validator line re-added to the tip decl.

verify: sh [ -f scripts/install.sh ] && [ -f core/scripts/hermetic-run.sh ] || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; T="$(mktemp -d)" && git init -q "$T" && mkdir "$T/_bmad" && bash scripts/install.sh "$T" >/dev/null 2>&1 && [ -f "$T/scripts/ai-dlc/hermetic-run.sh" ] && [ -f "$T/tests/fixtures/readset-skip/inputs.decl" ] && [ ! -e "$T/scripts/validate-enforcement-map.sh" ] && ( cd "$T" && git add -A && git -c user.email=r@r -c user.name=r commit -qm i ) >/dev/null 2>&1 || exit 9; for f in readset-skip readset-skip-b readset-skip-c readset-skip-d; do bash "$T/scripts/ai-dlc/hermetic-run.sh" --root "$T" --key-only "$f" >/dev/null 2>&1 || exit 1; done; grep -qF -- '--arms I66' core/fixtures/validator-arm-selection/run.sh && grep -qE '^PHASES_a=".* i66-onehook( |")' core/fixtures/validator-arm-selection/run.sh || exit 1; exit 0

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

## BL-491 — the hermetic runner copied a declared directory whole, so an ignored link refused it

**DEFECT, PC-S317-HERMETIC-RUN-REFUSES-CONSUMER-SKILL-SYMLINKS.** `core/scripts/hermetic-run.sh` copied each declared
directory with `cp -Rp` and refused any symlink found on disk under it, while the KEY covered only tracked plus
untracked-unignored files. On the reference consumer `.claude/skills/swap-integration` is a link listed in its
`.gitignore`, so every fixture declaring `core/skills/` exited 2 and every push failed. `.claude/skills` there holds
221 tracked files and over a thousand ignored ones, all copied and none keyed.

The fix copies a declared directory by its git population (the `readset_manifest` `.paths` stage, before its `-f`
filter), refuses any `-L` entry and any gitlink in that population, creates every declared directory, and copies with
`cp -p`. The key still reads `.now` only and is byte-identical. `--key-only` now exits 2 when hashing fails, and a root
that is not the top of a git work tree is exit 2. Arms P, Q, R, S, T, U and W in `core/fixtures/hermetic-runner`, with
mutants M7 to M11, carry it.

The receipt passes when an ignored link under a declared directory leaves the run at exit 0 with the link absent from
the sandbox, and the same link force-tracked exits 2. Scored under `set -uo pipefail`: tip 0, base 1, and 1 against
the copy loop reverted to `cp -Rp`.

verify: sh d="$(mktemp -d)" || exit 9; [ -f core/scripts/hermetic-run.sh ] && [ -f .githooks/pre-push ] || exit 9; mkdir -p "$d/lib" "$d/.githooks" "$d/core/fixtures/probe" && cp .githooks/pre-push "$d/.githooks/pre-push" && printf 'x\n' > "$d/lib/x.txt" && printf '#!/usr/bin/env bash\ncat lib/x.txt && [ ! -e lib/ilnk ] && [ ! -L lib/ilnk ]\n' > "$d/core/fixtures/probe/run.sh" && printf 'lib/\n' > "$d/core/fixtures/probe/inputs.decl" && printf 'lib/ilnk\n' > "$d/.gitignore" && ( cd "$d" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm p ) >/dev/null 2>&1 && ln -s /etc/hosts "$d/lib/ilnk" || exit 9; bash core/scripts/hermetic-run.sh --root "$d" probe >/dev/null 2>&1; a=$?; ( cd "$d" && git add -f lib/ilnk && git -c user.name=t -c user.email=t@t commit -qm t ) >/dev/null 2>&1 || exit 9; o="$(bash core/scripts/hermetic-run.sh --root "$d" probe 2>&1)"; b=$?; rm -rf "$d"; [ "$a" = 0 ] && [ "$b" = 2 ] && grep -q 'lib/ilnk is a symlink' <<<"$o"

## BL-492 — step 2's fixture run is not the run the consumer's push performs, and a fixture directory was written split

**DEFECT, filed batch 216 as PC-S317-SELF-UPDATE-FIXTURE-RUNNER-IS-NOT-THE-HERMETIC-RUN-PRE-PUSH-PERFORMS.** Two
mechanisms, one candidate.

**S1, the runner.** `core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh` ran every fixture plain
(`( cd "$CONSUMER" && bash "$FX_ROOT/$name/run.sh" )`) and never read `inputs.decl`. The consumer's pre-push
(`core/git-hooks/pre-push`, the FIXTURE_POOL `bash -c` body) runs a fixture carrying `inputs.decl` through
`hermetic-run.sh --root "$PWD" <name>`, fails it on any non-zero exit, fails it (never falls back) when the runner is
absent, and exports `PREPUSH_POOL_DEPTH` one deeper. On the reference consumer's 0.760 step 2, 90 fixtures read green here
and 76 were declared, and the push then refused 6. Fixed: a declared fixture runs through the consumer's
`map_consumer core/scripts/hermetic-run.sh` copy, with `PREPUSH_POOL_DEPTH` exported one deeper and the git variables the
hook unsets unset, ONLY when the consumer's on-disk hook carries the dispatch. The key is the whole-line
`# READSET_TOOLS_BEGIN` sentinel AND the dispatch line, never the bare word `inputs.decl`, which a pre-dispatch hook's
comments carry. A hook without the dispatch runs it plain and the log says why. A runner that is absent where the hook
dispatches is red, with the hook's own not-found line. Any non-zero exit is red. Undeclared fixtures run plain as before.
The rule is RESTATED, because it lives inside the I66-bound FIXTURE_POOL body and nothing can source it. Lifting it into a
shared span that both hooks and the runner read is a hook change, and it is a follow-up, not done here.

**S2, the split fixture directory.** The gate never sees a fixture path: `setup-sites.md`'s `machinery:` list holds no
`core/fixtures` entry, and graph's real gate record had 0 CARRY rows. The split happened in SKILL.md step 2's
fixture-write rule. The agent held back `artifact-path-conformance/run.sh` as BOTH-CHANGED and wrote the same directory's
upstream-only `inputs.decl`, whose new `!` REQUIRED line the old `run.sh` never consumes. The push refused it with
`required_missing=1`, reproduced on graph's archives at `f8c00ed4` (rc 1) and `c60a98d4` (rc 0). Fixed in prose: a fixture
directory is one unit, so if any path under it is held back, none of it is written and all of it is carried. The "if its
set and yours disagree, stop" sentence is scoped to machinery paths. No gate arm was added, and nothing sets
`GATE_CARRY_STATE=carried` for a fixture path, which would cost every consumer with a local fixture edit the SAFE-STOP
acquittal.

**Disposition and order.** Step 2's order is pinned as gate, write, runner, commit; graph's `f8c00ed4` already carries
the runner log, so that is the real order. A runner red (exit 1, a fixture red or MISSING) takes the HOOK-REFUSED
disposition `SELF-UPDATE-DEFER`, and the old "A red derived fixture STOPS the self-update" text is REPLACED. The
uncommitted-red restore is written out: `git checkout --` the written tracked paths and the stamp, remove the new untracked
paths by explicit pathspec (never a glob, the two records kept), return to the original branch, delete the self-update
branch. The runner prints `# disposition: SELF-UPDATE-DEFER — carry slice + gate record + this log to step 7` on STDOUT on
the exit-1 path only; exit 2 stays a refusal.

**BOOTSTRAPPING.** `self-update-fixtures.sh` is machinery, and step 2's order is gate, then write, then runner, so the
runner on disk when step 2 calls it is the copy the slice just wrote: **S1 takes effect ON the delivering pull**,
including the printed DEFER token. S2 is SKILL.md prose, and the agent executing the delivering pull is still reading the
installed SKILL.md: **S2, the order and restore text and the replaced STOP sentence take effect on the re-invoke after a
landed self-update**, and on the delivering pull the printed token is the only carrier of the new disposition. No gate
change ships, so nothing here depends on the installed gate.

**OPEN HALF, out of this release (D6).** `reconcile/apply.sh` writes fixture paths one at a time too: its per-row loop at
`apply.sh:1142` reads one `kind path cons bucket` row per path, and fixture rows are only reordered to the end of the batch
(`apply.sh:1101-1105`), never grouped by directory. An operator is present at that apply, which is why it is not this
release. Do not read this entry's close as closing it.

Arms: `self-update-fixture-log` Parts H1-H7 and HD1 (one ten-cell vector), Part HR (the restore, with a control),
Parts W1-W4 with in-file mutants WM1-WM4. Battery: `self-update-fixture-log-mutants` HCTL and HM1-HM9.

verify: sh f=core/fixtures/self-update-fixture-log/run.sh; [ -f "$f" ] || exit 9; o="$(bash "$f" </dev/null 2>&1)"; rc=$?; grep -qF '  ok    Parts H1-H7, HD1: vector 1-1-1-1-1-1-1-1-1-1' <<<"$o" || exit 1; grep -qF '  ok    Parts W1-W4: ' <<<"$o" || exit 1; [ "$rc" -eq 0 ] || exit 1; exit 0

The receipt above runs the fixture and needs both mechanisms. The per-mechanism receipts below are recorded beside it
(`scripts/backlog-reverify.sh` reads only an entry's first `verify:` line). Each is run from the repo root under
`set -uo pipefail` with stdin closed.

S1 receipt, the runner. It drives the shipping runner through the fixture's own H world and keys on its vector:

```
L=core/fixtures/self-update-fixture-log/lib.sh; [ -f "$L" ] && grep -q '^hsig()' "$L" || exit 9; o="$(NAME=receipt SUFL_RUNNER_ARG= bash -c '. "$1"; build_h_world || exit 9; hsig "$RUNNER"' _ "$L" </dev/null 2>/dev/null)"; [ "$o" = "1-1-1-1-1-1-1-1-1-1" ]
```

S2 receipt, the fixture-write rule. It runs the fixture's own `wsig` over the shipped SKILL.md:

```
f=core/fixtures/self-update-fixture-log/run.sh; s=core/skills/ai-dlc-update/SKILL.md; [ -f "$f" ] && [ -f "$s" ] || exit 9; eval "$(awk '/^w_flat\(\) \{/,/^\}$/' "$f")"; eval "$(awk '/^wsig\(\) \{/,/^\}$/' "$f")"; command -v wsig >/dev/null || exit 9; [ "$(wsig "$s")" = "1-1-1-1" ]
```

