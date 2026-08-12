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

**THAT FIGURE WENT STALE AND NOBODY NOTICED, WHICH IS ITS OWN LESSON. IT THEN WENT STALE
AGAIN, AND THAT IS WHY NO CURRENT COUNT APPEARS HERE.** A raw total written into this file
decays silently and reads identically to a fresh one; dating it is not available either,
because a date in resident rule prose is a tier-1 finding in `audit-rule-files.sh`. **Derive
the count, never quote one** — `find core/fixtures -mindepth 1 -maxdepth 1 -type d | wc -l` —
and read the CHANGELOG for when a figure was taken. Re-measured on a 133-fixture suite:
**7m40s at 1303% CPU**, 133 ok / 0 FAIL, which is a FLOOR because the suite has grown since.
The suite is
**POLE-BOUND** — wall clock tracks the single longest DIRECTORY, not the sum over the pool — so
the number to watch is the top of `.git/ai-dlc-fixture-durations`, not the total. Six fixtures
sit at 395–442s and everything else is under 220s. **A cost recorded there is a LOADED cost,
measured under the 16-way pool; running the same unit alone gives a completely different number
(one shard: 442s loaded, 112s solo at 424% CPU) and the two must never be compared.**

**A CHANGE TO A VALIDATOR THE POLE INVOKES IS A CHANGE TO THE SUITE'S WALL CLOCK.** One
invariant added to `validate-enforcement-map.sh` as a nested loop over (subtree × fixture file)
moved that validator from 13.0s to 18.1s — 39% — which the sharded mutation batteries multiply by
roughly thirty. The pole went 442s → 595s and the whole suite went to ten minutes.
Reshaped to one recursive grep per subtree it is back to 13.2s. **Time the validator before and
after, from inside the repo** — a copy run from `/tmp` resolves its root elsewhere and exits in
5ms, which reads as an enormous speed-up and is a broken measurement.

The inverse hazard is live too, and `core/fixtures/check-3b-locked-anchor/run.sh:125`
carries it: a fixture that is green only from the repo root may be asserting nothing,
because that is a cwd where its decoy files do not exist. A fixture that must hold from
any cwd asserts cwd-invariance itself, in its own arms — it does not get that from how
the suite is driven.

## Some authoring rules live in `.claude/rules/`, and load only on a Read

Rules that bind one subsystem are path-scoped files under `.claude/rules/`, each with a
`paths:` frontmatter list. Claude Code loads one **when a matching file is read** — MEASURED
on CC 2.1.226: Read fires it, Edit fires it (Edit requires a prior Read), and **Write, Grep,
Glob and Bash do not**. It fires **once per session**, on the first matching read, not once
per read. A subagent's read loads it inside the subagent only; it never reaches the parent.

That trigger shape is why the sections below stayed here rather than moving: a rule about a
BASH behaviour, or about authoring this file, cannot be carried by a file-read trigger.

**A PATH-SCOPED RULE IS NOT COMPACTION-DURABLE, AND NOTHING ABOUT THE FILE SAYS SO.** Measured
in a real interactive session: the per-session memo SURVIVES a compaction, so a scoped rule
loads once, early, and is then **permanently gone for the rest of the session** — a later read
of a matching file does NOT bring it back. Only rules with no `paths:` are re-injected
(`load_reason:"compact"`), and this file is too.

So the test for moving a section here is not just "does the work begin with a matching read".
It is **also** "is this rule carried by a mechanism that runs anyway". All three moved rules
are: `validate-mutation-red.sh`, I74 plus install.sh's `.dist-only` derivation, and
`validate-plan-shape.sh`. **A prose-only rule — one with no enforcer — must stay in this file**,
which is why "a zero is not a finding" and "prohibitions need mechanisms" did. Moving one into
`.claude/rules/` would delete it from every session that has compacted once, silently.

Today: `fixture-mutants.md`, `fixture-ship-decl.md`, `plan-shape.md`,
`plan-shape-measured.md`. Both directions are bound by **arms A1–A4 of
`scripts/validate-claude-rules.sh`** — a rule with no reader and a pointer with no rule both
fail the push. That validator is a standalone script and deliberately NOT an arm inside
`validate-enforcement-map.sh`, which the suite pole invokes; this file cited it as `I88` for
five releases, an ID no arm has ever carried, while `CHANGELOG.md` recorded the deviation.
Citations here are now joined to the live set — see `docs/invariant-index.md`.

**Two triggers cannot fire on their own and are restated here.**

Creating a NEW fixture directory reads nothing, so before you create one — or edit
`install.sh` or `uninstall.sh` — read `.claude/rules/fixture-ship-decl.md`. Whether a fixture
ships is one declaration and it lives in the fixture.

**A plan you are still writing lives at `~/.claude/plans/<slug>.md`, outside this repo.
Promote it to `docs/plans/<slug>.md` and commit it the moment it becomes a HANDOFF — the thing
a later session is told to READ AND FOLLOW.** Do it when that becomes true, not at the end.

That rule's own home, `.claude/rules/plan-shape.md`, is scoped `paths: docs/plans/**`, and its
comment assumes "work on a plan begins by reading `docs/plans/<slug>.md`, so the trigger fires."
**That is false for a NEW plan**, which is authored in `~/.claude/plans/` and reads nothing
under `docs/plans/` — so the rule telling you to promote a plan cannot load while you are
writing one. `scripts/validate-plan-shape.sh` cannot cover the gap either: its corpus IS
`docs/plans/*.md`, so an unpromoted plan is invisible to it and its clean run reads identically
whether the promotion happened or not.

Measured on the 0.357.0 program plan: it carried four unresolvable citations and no read/write
boundary for a whole session, unchecked, because it was never tracked. The validator found all
five within a second of the file entering its corpus. A `PostToolUse` hook now fires on every
write under `~/.claude/plans/`, escalating with the write count; it warns rather than denies
because plan mode's harness requires that path to exist and a deny would break plan mode.
**A warning is the weaker mechanism and it is chosen under constraint. Promote the file.**

**THE WARNING IS THE CEILING.** Four constraints hold it there, and none of them lifts with
more effort.

**The act cannot be denied.** Plan mode's harness requires the file to exist under the home
plans directory. A `PreToolUse` deny on that path breaks plan mode outright, so the write
cannot be refused.

**The omission cannot be detected, because no join exists.** The home plans directory and
`docs/plans/` hold filename sets whose intersection is **ZERO**, re-measured every time it has
been looked at. Plan mode mints a slug from the prompt plus a random word pair, and a promoted
handoff carries a hand-chosen slug. Which unpromoted plan was owed promotion is therefore not
derivable from the two sets, and a check keyed on an unpromoted plan file fires on every one
of them. The two counts move; the empty intersection is the durable part, so only it is stated.

**The predicate is intent, not an act.** Whether a plan is a handoff is a judgment about what
a later session will be told to do. The same write produces a handoff and an ordinary
throwaway draft. This repo's mechanisms deny an act and never evaluate a reason, and no act
here separates the two, so there is nothing to deny.

**The guard cannot be versioned in this repo either.** `.gitignore:41` ignores `.claude/*`,
and arm A1 at `scripts/validate-claude-rules.sh:95` fails the push on any tracked path
under `.claude/` that is not `.claude/rules/**/*.md`. Force-tracking a hook file or a
`settings.json` here breaks the push. So the hook stays in the operator's home directory, is
**NOT** part of the distribution, and reaches no consumer by design — a consumer tree gets no
`docs/plans/`, no plan-shape validator, and no promotion rule, which
`core/fixtures/plan-shape/.dist-only` already declares.

**Promote the file the moment it becomes a handoff. The reader is the enforcement.**

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
invariants in `scripts/validate-enforcement-map.sh` are the pattern, and
`docs/invariant-index.md` enumerates the ones currently live.

**That index is DERIVED. Do not hand-edit it — change the arm header and re-run
`scripts/render-invariant-index.sh`.** It renders from the arm headers themselves,
byte-compares at pre-push, and asserts that every emitter sits inside a declared arm, that
every declared arm can emit, and that no ID is claimed twice. **An invariant declares itself
by OPENING its arm header with its ID**, closed by a colon — a header that merely mentions an
ID elsewhere in its prose declares nothing.

**A hand-typed enumeration is what this replaced, and it had gone stale by 22 invariants** —
71 named against 93 live arms, I1 and I2 among the missing. The CHANGELOG carries the
measurement. Nothing read that sentence but a human, and nobody audits a 12,000-character
sentence.

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
