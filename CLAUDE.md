# Authoring rules — ai-dlc itself

Scope: work in THIS repo (`core/`, `scripts/`, `core/fixtures/`).

Everything under `templates/` is the consumer distribution's output, not this
repo's rulebook. `install.sh` copies `coding-conventions.md.template` to the
consumer's `docs/coding-conventions.md` and `CLAUDE.md.template` to the
consumer's `CLAUDE.md`. **That last one shares this file's basename and is a
different file** — do not put ai-dlc-authoring rules in the template, do not
treat the template as binding here, and check which of the two you have open
before editing.

## A zero is not a finding

Any command whose answer is an ABSENCE carries a control, in the same invocation,
that must come back non-zero. Report both. Without one you have established that
your search ran, not that the thing is missing.

Measured false-zero sources, each of which has shipped a wrong conclusion here:

- **Unbraced `$ref:path` in zsh.** `:c` and `:t` are history modifiers and
  silently eat the next character — `"$r:core/..."` becomes `f70512eore/...` and
  git reports the path absent. Always `"${r}:core/..."`.
- **Case-sensitive grep against a differently-cased token** — a lowercase `v8`
  against an uppercase `V8` banner.
- **A per-file grep against a glob-declared list.** `core-manifest.md` declares
  `steps/*.md`; grepping it for one step file's name returns 0 for every step
  file and proves nothing.
- **An empty or `.` pathspec.** `:(exclude)` with no value excludes the whole
  tree, and `git grep` then exits **1, not 128** — indistinguishable from a real
  absence.

## A check that cannot fire reads exactly like one that passed

Before shipping a check, prove it can fail. This is the repo's recurring defect;
roughly a dozen files state it locally, in the header of whichever guard learned
it. Those statements stay where they are — each explains its own guard. This is
the general form.

## Mutants

- Build the mutant as a **copy**, never an in-place edit, and guard with `cmp -s`
  so a `sed` that matched nothing cannot pass as a mutation.
- **Revert every layer of a layered fix.** A partial revert produces a mutant
  that proves the layer you left in place, and it comes out green.
- Add an **unmutated control** from the same directory whenever the harness
  itself could be what fails — a lone script copy that dies sourcing `lib.sh`
  emits nothing, and "no output" otherwise scores as a kill.
- Assert a **positive outcome**, not the absence of the old failure message.
- A mutant must fail **only** its own assertion. Two failures mean the
  assertions are entangled and one of them is vacuous.

## Run the fixture suite the way the hook runs it, never a hand-rolled loop

`.githooks/pre-push` is the runner. It dispatches through a worker pool
(`xargs -P "$FIXTURE_JOBS"`, default 16), orders units by their own recorded costs so
the longest starts first, content-keys the skip, and asserts that every dispatched
fixture produced a verdict. Invariant **I66** binds that runner to be one program
across both pre-push hooks. Reach for it — `git push` is the cheapest way to run it —
rather than writing `for d in core/fixtures/*/`.

**A hand-rolled loop is not merely slower, it FABRICATES FAILURES, and that is the
reason this is a rule.** Measured on one branch, same tree, same fixtures, both ways:

```
for d in core/fixtures/*/; do (cd "$d" && bash run.sh); done   5 FAILED
bash "$d/run.sh"   (from the repo root, as the hook does)      0 FAILED
```

All five — `consumer-machinery-home`, `enforcement-map-derivations`,
`enforcement-map-sites`, `layer-contract-conformance`, `ledger-status-vocabulary` —
resolve the repo root from the process working directory, so `cd`-ing into the fixture
dir breaks their sanity arm. Four of the five said `FIXTURE BROKEN`, which reads
exactly like a regression in the change under test. The whole suite through the pool is
**4m57s at 949% CPU**; the serial loop was roughly ten times that and wrong.

The inverse hazard is live too, and `core/fixtures/check-3b-locked-anchor/run.sh:125`
carries it: a fixture that is green only from the repo root may be asserting nothing,
because that is a cwd where its decoy files do not exist. A fixture that must hold from
any cwd asserts cwd-invariance itself, in its own arms — it does not get that from how
the suite is driven.

## Whether a fixture ships is ONE declaration, and it lives in the fixture

A fixture ships to consumers unless its own directory carries a `.dist-only` file.
**`install.sh` derives its copy loop from that marker**; nothing hand-lists the shipped
set there any more.

**The criterion: a fixture is `.dist-only` when its SUBJECT is not present on a
consumer.** Three measured shapes, and they are the whole of today's twelve:

- the subject is a distribution-only program (`scripts/validate-enforcement-map.sh`,
  `validate-plan-shape.sh`, `suite-content-key.sh`, the distribution `.githooks/pre-push`);
- the subject is a corpus only this repo holds, so the same run on a consumer scans a
  smaller set and prints the same clean line — a narrower check reading identically to a
  full one;
- it is a MUTATION BATTERY behind a shipped fixture, editing copies of core's own sources.

**Write the reason in the marker.** It is required to be non-empty, because a marker with
no reason is a decision nobody can audit — and seven of the twelve were zero bytes until
this rule existed. Getting it wrong in the shipping direction is how a distribution-only
battery once became the reference consumer's suite pole; getting it wrong the other way
means a fixture reaches no consumer while this repo's own suite stays green over it.

**Three hand-written lists remain and they are deliberate.** `uninstall.sh` bounds a
DESTRUCTIVE loop and runs on a consumer where `core/fixtures/` does not exist, so it cannot
derive and must not glob the consumer's `tests/fixtures/` — that would delete fixtures the
consumer wrote. `core-manifest.md` and `setup-sites.md` are glob declarations read by
roughly twenty programs (the core guard hook, `core-paths.sh`, `validate-layer-entries.sh`,
the drift scan, a dozen fixtures); changing their grammar to a wildcard-with-exclusion
touches every one of those readers, and that blast radius is larger than the four edits it
would save. All three are joined to the derived set by **I74**, in both directions — so
they can be stale for exactly as long as one push.

## Two layouts

`install.sh` splits what shares a parent here: `core/scripts/<x>` →
`scripts/ai-dlc/<x>`, `core/schemas/` → `.claude/schemas/`. Never locate one core
file by walking up from another — invariant **I33** fails the build on it. Any
change touching path resolution is verified on a tree built by running
`scripts/install.sh` into an empty directory, not only in `core/`.

## Prohibitions need mechanisms

A rule with no enforcer is a suggestion, and the prohibitions being violated are
exactly the ones with nothing behind them. Prefer deriving both sides of a join
over hand-listing either; when two files must agree, bind them — the numbered
invariants in `scripts/validate-enforcement-map.sh` are the pattern, and its
final `OK:` line enumerates the ones currently live.

## An instruction that ships its own opt-out is not an instruction

**Measured on this repo's own runbook, in the revision about to be handed to a consumer
session.** A section told that session to run a consolidation pass. Beside it sat a fenced
decision table — `ok -> no target, stop` — and a paragraph of current sizes "for the
record, not as a gate". Every figure was true and freshly measured. **Together they were an
opt-out kit**: a session told to do a thing, reading in the same breath that its subject
looks healthy, talks itself out of the work and cites the plan while doing so.

**Write the instruction and stop.** No decision table beside it, no "for the record"
figures, no argument for why this target and not that one — the reader has been handed the
target by name and everything further is material for re-litigating a settled choice.

**A genuinely conditional action states its condition in the numbered action list**, where
the executor decides it deliberately and the operator can see the branch. Nowhere else.

**This applies to what you write into `CLAUDE.md` too, which is where it was broken the
first time it was written down.** A measurement is why a rule exists and belongs here; a
sentence telling the reader when the rule need not bind is an exception, and it will be
read as one. `validate-plan-shape.sh`'s P7 flags one form mechanically; its scope, and the
reason for that scope, are in its own header.

## Before adding a check, measure its false-positive set

Ship it only if you have run it and the set is empty or enumerated. An unmeasured
lint is one the operator turns off, which is worse than none.

## A plan that must survive the session lives in `docs/plans/`

Plan mode writes to `~/.claude/plans/`, outside the repo, where nothing can check it and
nobody else can read it. The moment a plan becomes a handoff — the thing a later session
is told to READ and FOLLOW — promote it to `docs/plans/<slug>.md` and commit it. Then it
is reviewable in the PR that does the work, and `scripts/validate-plan-shape.sh` holds it
to a shape a stranger can act on.

The shape, and the reason for each part, measured on this repo's first plan at the moment
it was handed off:

- **`## Start here`**, naming the repos and the read/write boundary. Without a declared
  entry point a resuming session acts on whichever section it reads first.
- **A numbered next-action list**, blocked items marked as blocked. A plan that records
  state and never says what to do next is a report.
- **One current status record.** It had two, and the older one predated a release; a
  superseded section is fine, but it has to say so where the reader is, not elsewhere.
- **Completed work marked completed.** Two release sections still read as work to do
  after they had merged. A session told to FOLLOW the file would have redone them.
- **Citations that resolve.** `path:line` is this repo's evidence form, and one that
  cannot be located at resume time is a promissory note against evidence.
- **An operator-ping instruction.** The plan is executed by a session the operator cannot see,
  where "still working" and "stopped, waiting on you" look identical from outside — so silence
  is a stall found only by polling. Every plan tells its executor to ping on any question, on
  any decision, and on completion (including an early stop). Measured across this repo's own
  runs: every consumer-session stall ended with the operator asking rather than the session
  reporting, including one sitting on a blocking question and one that had already FINISHED.

- **A done-when whose PASS you have CHECKED IS REACHABLE.** This repo's rule for a new check —
  prove it can fire — applies to acceptance criteria, and the plan that closed this program broke
  it twice in one file. *"`validate-artifact-budget.sh` green"* was unattainable when written: the
  only FAIL is an unrelated artifact at 309%, byte-identical before and after the work.
  *"confirm each still resolves"* was unverifiable: no file in that corpus produces a genuine
  anchored resolution, so the executor could not satisfy it literally at all. **Both read like
  ordinary criteria and neither could ever have gone green.** An executor then either invents a
  substitute — which is what happened, correctly, both times — or reports failure for work that
  succeeded. Run the command, or state the expected FAIL and what makes it unrelated.

  **AND REACHABLE AT THE MOMENT IT IS CHECKED, WHICH IS NOT THE SAME THING.** Measured on the
  0.341.0 → 0.345.0 runbook, whose done-when 5 asked that `ledger-reverify` report a receipt as
  `CLOSE-CANDIDATE`. Reachability was checked before the file shipped and the derivation was
  right — but the run's own later step CLOSES and ROTATES that entry, and a rotated entry emits no
  row, so the live ledger correctly reads **0** by the time the criterion is read. The executor
  materialized the pre-close ledger from its own commit and answered there, which is correct and is
  work the file should not have cost them. **When a run consumes its own subject, state the
  observation point** — before which step, against which ref. This is the third criterion in this
  repo's runbooks that an executor had to reinterpret rather than satisfy literally.

None of that is about writing quality. Each one makes the file produce WRONG WORK when
followed literally, which is the only thing a handoff is for.

## Releases

Commit subject, `VERSION`, and the `CHANGELOG` heading are **one claim**, joined
at pre-push. Squash-merge only single-version branches: a squash of several takes
the first version in the subject and breaks the triple.

Both halves are now mechanised in `scripts/validate-release-version.sh`, and the
second half is there because the first one could not see it — the triple is
per-commit, and a squash deletes the commits that would disagree, so it reported
PASS on the branch and PASS on the squash that swallowed three releases. The range
arms therefore key on the CHANGELOG heading set across the range, never on
agreement between the triple's three members. **Cut release branches from
`origin/main`, not from a local `main` that may be ahead of it** — that is the
precondition the second arm checks, and the one that actually fired.
