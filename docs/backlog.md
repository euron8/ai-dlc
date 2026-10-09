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

**BUILT, batch 216: comparability by DISPATCHED COUNT, with admission.** A dispatched-set comparison was measured first
and dropped. Over the last 21 measuring commits, a run with at least 3 comparable earlier rows was found for:
0/21 by the exact dispatched set; 2-5/21 by a 90% cost-weighted Jaccard overlap of sets; 10-17/21 by load within
+-25%; and 10-15/21 by dispatched count within +-25%. Count was chosen over load because a count does not move when
the code gets slower. Keyed on load, a uniform slowdown moved the run out of band, and the regression calibrated
and recorded (adversary, batch 216). Each history row now carries two more columns: the run's load (printed only)
and its dispatched count. A 7-column row is usable when three things hold: its pole directory exists, this run
timed its pole, and its count is within +-`COUNT_BAND`=25% of this run's count. Legacy 5-column rows are never
usable. So are malformed rows (6 columns, or a non-integer load or count). Both kinds are counted by reason,
never refused. ADMISSION covers the calibrating and seed paths: once a width holds 3 well-formed 7-column rows,
a run with no usable row records only at or below their max pole. Without that, a regression that made itself
incomparable laundered its figure into B. The adversary measured three ways to do that: a uniform slowdown, a
novel dispatch, and a keyed run skipping B's pole. The coverage SKIP is gone as an exit, and the share is
printed. The validator's header, under COMPARABILITY, is the description, and the `suite-pole-guard` fixture's
arms are its probes. The fenced receipt below runs under `set -uo pipefail`. It drives the validator with the
hook's argv in a fresh git repo, in four steps:
- A 67.85%-share keyed run must record a row. Base cannot: it SKIPs on coverage.
- Three calibrating runs (11 units dispatched) record three rows.
- Every unit grows 40% slower. With the same count, the run must FAIL `GROWN`.
- A regression at a novel count (fx1 600, 17 units) must pass and NOT be recorded. Then fx1 700 at 14 units, in
  band of both, must FAIL `GROWN` against 150.

Scored batch 216: tip 0, base 1, the no-admission mutant 1. Also 1 for a stub that records every run and fails
only on a ceiling over in-band rows.

```
V="$PWD/scripts/validate-suite-pole.sh"; [ -f "$V" ] || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; R="$(mktemp -d)" && git init -q "$R" && G="$(git -C "$R" rev-parse --path-format=absolute --git-common-dir)" && mkdir -p "$R/docs" && echo 0 > "$R/VERSION" && for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do mkdir -p "$R/core/fixtures/fx$i" && echo 'exit 0' > "$R/core/fixtures/fx$i/run.sh"; done && printf '# history-band: 33\n# band: 15\n# jobs: 12\n# fixtures: 18\nfx1 100\n' > "$R/docs/suite-pole-baseline.tsv" || exit 9; L="$G/ai-dlc-fixture-durations.last"; D="$G/ai-dlc-fixture-durations"; H="$G/ai-dlc-suite-pole.history"; hook() { o="$(cd "$R" && bash "$V" --durations "$L" --record "$D" --jobs 4 2>&1)"; c=$?; }; run() { rp="$1"; rn="$2"; rs="$3"; printf 'fx1 %s\n' "$rp" > "$L"; i=2; while [ "$i" -le "$rn" ]; do printf 'fx%s %s\n' "$i" "$rs" >> "$L"; i=$((i + 1)); done; cp "$L" "$D"; echo 4 > "$L.jobs"; hook; }; rows() { if [ -f "$H" ]; then awk 'END { print NR }' "$H"; else echo 0; fi; }; printf 'fx1 60\nfx2 35\n' > "$L"; printf 'fx1 60\nfx2 35\nfx3 45\n' > "$D"; echo 4 > "$L.jobs"; hook; [ "$c" -eq 0 ] && [ "$(rows)" -eq 1 ] || exit 1; : > "$H"; for n in 1 2 3; do run 150 11 100; [ "$c" -eq 0 ] && grep -qF "CALIBRATING ($n/3)" <<<"$o" || exit 1; done; [ "$(rows)" -eq 3 ] || exit 1; run 210 11 140; [ "$c" -eq 1 ] && grep -qF 'GROWN: fx1 at 210s against baseline fx1 at 150s' <<<"$o" || exit 1; run 600 17 100; [ "$c" -eq 0 ] && [ "$(rows)" -eq 3 ] && grep -qF "not recorded: 600s is above the width's max 150s" <<<"$o" || exit 1; run 700 14 100; [ "$c" -eq 1 ] && grep -qF 'GROWN: fx1 at 700s against baseline fx1 at 150s' <<<"$o" || exit 1; exit 0
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

