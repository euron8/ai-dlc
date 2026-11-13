<!-- unconditional: method binds every task here and leaves no artifact a `paths:` glob could match; a scoped rule would be gone after the first compaction. -->

# Verification discipline

How to establish that a thing is true here. `CLAUDE.md` carries two rules: a zero needs a control, and a check
that cannot fire reads like one that passed. These are the rest.

## Every arm carries a self-probe, and the probe runs BEFORE the corpus

Build probe trees under `mktemp`, never the real corpus, and fire the probe in **both** directions: the arm
reports a seeded offender and stays quiet on a seeded near-miss.

## Run the control on the input that DISCRIMINATES

A control on an input ADJACENT to the one that matters reads as working. Where two candidate semantics exist
(inclusive/exclusive range), compute both and REFUSE unless they differ.

## Count a suite's distinct input SHAPES, not its arms

Channels converge on the obvious input and agree for that reason. Give each channel its own seed shape (for
example a duplicate NOT adjacent to the original); never add another arm instead.

A mutant that scores identical may mean the corpus lacks the discriminating input. Before reading a null as
"not load-bearing, drop the guard", construct the input that would separate them (for a miss-vs-empty-blob
memo, a corpus with an empty blob) and compare behaviour and call counts.

## Point a search grammar at its own subject before trusting its zero

A scan whose grammar cannot spell its subject (awk pattern-action rules against `if (line ~ /…/)` bodies;
`[^:]*` against `[[:blank:]]`) scores it as a non-instance. Discard such a zero.

## Text about a program is not the program

A path a receipt READS vs MENTIONS, a grep hit counted as a call site, a report's sentence counted as a data
row, extracted text CONTAINING a function name: reading harder does not fix it. Recompute and compare two
independently derived values; a count read off a rendering is not a derived count.

**A transcript replay counts EXECUTED calls, not attempted ones.** Pair each `tool_use` with its
`tool_result` by id and drop denied or `is_error` calls: a PreToolUse deny means PostToolUse never
fires.

## A coverage proof over a DERIVED population cannot see outside it

Ask separately what the population EXCLUDED: entries filed after a pinned snapshot, and a bucket labelled
"nothing to compare" that the parser's grammar cannot spell.

## A prediction sent without its preconditions is a false finding

State the population and reachability of the guard (for example "unapplied document, guard unreachable")
alongside any expected-outcome row sent to another session.

## A receipt that reads a RENDERED artifact is closable by prose

Drive the shipping program; do not grep the document it produced. Ask what ELSE satisfies a receipt, and prefer
the arm that RUNS the subject over the one that reads its output. Isolating the subject is not the PROGRAM: a
CALLER defect stays invisible.

A receipt that accepts TWO candidate fixes has established neither: build both and score them. An archived
receipt is inert while the FIXTURE still runs, so score a proposed receipt-weakness against the fixture before
reading it as a coverage gap.

## A control that agrees with the verdict is not a control

Run the control against the thing the verdict claims is ABSENT, and read its output; it must prove the ARM
could have fired, not only that the RUN happened. For an empty search the control is a token known present in
the same corpus, in the same invocation.

A landed branch is no positive control for a blob-equality "did it land" check (later main edits make it read
DIFF). Use a synthetic one, `git commit-tree -p <old base> origin/main^{tree}`, which must read EQUAL, paired
with an unlanded sha as the negative. The check keeps landed work that touched shared files and never deletes
unlanded work.

## A differential must prove its two sides differ

- Assert the sides differ in the same invocation, before reading the comparison (a `sed` that expands to the
  identical line makes both runs use the same copy).
- It must be able to RESOLVE the effect: a spread across reps the size of the effect makes a null meaningless.
- Ask what makes BOTH fail: two programs failing for a reason neither owns is non-discriminating; read the ARM
  each side NAMED, not its status.

## Count both sides the same way

A `mktemp` extraction counted against the live repo compares two TREES. Extract both sides alike.

A count over a derived corpus is a function of what is on disk, in both directions: extra copies of the subject
and agent worktrees (each carrying a full tree) move it. Take such a count in a clean `git worktree` checkout
and name the tree beside the number.

## Run the shipping code against the real corpus

A hand-written probe is a second implementation whose bugs nobody finds. When probe and shipping code disagree,
the probe is wrong until proven otherwise. Where the real program cannot be used, say so beside the number.

## Cross-check a parser against what EXECUTES it, never another parser

Use the executor (`bash -n -c` for shell) as the oracle; `shlex` and similar second parsers disagree with it.

## Read the CONSUMING mechanism's own remedy text before calling its input wrong

The contract is usually written inside whatever reads the value. A byte-comparison of two programs' shared
HELPERS is not a binding on their ANSWER.

## Verify the premise before building

Every plan, catalog entry, ledger row, handoff tag and consumer report is a hypothesis about a tree that has
moved. A claim that names a real file is not verified: the file existing is not the claim.

## Ask what SET a number was taken over

For every figure, ask what population produced it and whether it is the population the mechanism runs on. A
recorded instance count is a FLOOR.

## A correction is itself a measurement, and NARROWING is not the safe direction

Ask which row (of a multi-row table) a correction was measured on before believing it; a narrowed claim can be
wrong as easily as a wide one.

## Key a binding on the emission site

A whole-file `grep -qF` is satisfied by a comment. Bind to the line that EMITS the thing; a declaration of
intent is never evidence about content.

## How a false-positive set reached zero is part of the arm

Record the narrowing that got it there, beside the arm.

## Resolve the repo root by walking up for a marker

Never count `..` hops. `VERSION` exists only in the distribution, so a walk keyed on it cannot resolve an
installed tree. Walk up the way `ai_dlc_resolve_root()` at `core/scripts/validate-provenance-block.sh:138`
does; `core/fixtures/validator-path-resolution` holds both layouts to one answer.

## A glob that matches nothing must not report success

Count the corpus and fail on zero; an empty `for f in docs/plans/*.md` may iterate once over the literal
pattern or zero times, and either way exits 0.

## A calibration is a property of its text, not of its divisor

Re-measure a bytes-per-token figure whenever the corpus changes; carrying a divisor across populations gives
the same number with the opposite error.

## Ask what rate a hypothesis PREDICTS before a zero refutes it

Compute the predicted count FIRST; below one the run cannot discriminate, and a forced input beats a larger N.

## Verify a release the way the gate runs it

- Push, and let the hook's own run be the single gate. Do not force a full run with `AI_DLC_FIXTURE_NO_SKIP`
  to verify a release; only a measurement sweep on an unpushed throwaway branch may.
- Read each changed fixture by NAME in that run's output. A changed fixture ABSENT from the output was skipped:
  a read-set gap to chase, never a pass. One named on the `verdict store: N fixture(s) skipped` line was
  skipped on a recorded pass, which is not a gap.
- The CONSUMER's hook `core/git-hooks/pre-push` and the content-key skip print green banners having run almost
  nothing; neither is evidence your change ran.
- The TALLY is not the verdict: read the gate's exit, never a backgrounded wrapper's.
- A green gate is not a landed push. Confirm the remote ref moved (`git ls-remote --heads origin <branch>`
  non-empty, against a control) before opening a PR or reporting a release. Exit 141 is the transport dropping
  the idle SSH connection; the fix is `ServerAliveInterval 60` / `ServerAliveCountMax 30` on the alias in
  `~/.ssh/config`.

## An entry with two subjects expires only when both do

Enumerate an entry's distinct claims BEFORE reading a good measurement as a close, and say which survive. A
release note asserting the fix is not evidence.
