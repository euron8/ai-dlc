<!-- unconditional: method binds every task here and leaves no artifact a `paths:` glob could match — there is no file whose reading means "you are about to measure something". A scoped rule would also be gone after the first compaction, which is exactly when a long session starts trusting its own earlier numbers. -->

# Verification discipline

How to establish that a thing is true here. `CLAUDE.md` carries the two rules with the
longest scar histories — a zero needs a control, and a check that cannot fire reads like one
that passed. These are the rest.

## Every arm carries a self-probe, and the probe runs BEFORE the corpus

An arm reporting zero findings without first proving it can produce one has established that
it ran, not that the corpus is clean. Build probe trees under `mktemp`, never the real
corpus, and fire the probe in **both** directions: the arm reports a seeded offender, and
stays quiet on a seeded near-miss. One direction alone leaves a scan that flags everything
looking identical to a scan that discriminates.

This is the most-repeated rule in the repo and the one most often skipped in new work.

## Run the control on the input that DISCRIMINATES, and assert it discriminates first

A control passing on an input ADJACENT to the one that matters reads exactly like one that works.
Measured: an inclusive and an exclusive range return the same commit when walked from one step ahead
of the discriminating input, so the control passed under both the broken and the fixed
implementation. Where two candidate semantics exist, compute both and REFUSE unless they differ.

## Count a suite's distinct input SHAPES, not its arms

Channels written by different hands converge on the obvious way to build the input and then
agree for that reason rather than because the subject is right. Measured: a wrong fix passed a
self-probe, a receipt and twenty-one mutants, because every one seeded the duplicate ADJACENT to
the original — the receipt could only ever do so. The gap is in the SEED; the repair is one seed
per channel, never another arm.

## Point a search grammar at its own subject before trusting its zero

`CLAUDE.md`'s "prove it can fail" applied to a SCAN, where the failure is silent: the grammar
cannot spell the thing it hunts, so it scores its own subject as a non-instance. Measured twice
in one sweep — a scan keyed on `awk` pattern-action rules could not express `if (line ~ /…/)`
bodies, and `[^:]*` could not cross the colons inside `[[:blank:]]`. Both returned clean. That
zero is a floor of unknown depth; discard it rather than report it.

## Text about a program is not the program

Six instances in one program, by two parties both watching for it: a path a receipt READS vs
MENTIONS; a grep hit counted as a call site; a report's own sentence counted as a data row; a guard
testing that extracted text CONTAINED a function name, which mangled unparseable text still does.
Reading harder does not fix it — reading is the faculty that fails. Recompute and compare two
independently derived values; a count read off a rendering is not a derived count.

## A coverage proof over a DERIVED population cannot see outside it

Measured: a census from a pinned snapshot was fully accounted for and blind to entries filed after
the pin; a bucket labelled "nothing to compare" held the set's largest disagreement, because the
parser's grammar could not spell it. Ask separately what the population EXCLUDED.

## A prediction sent without its preconditions is a false finding

Measured: an expected-outcome row went to another session without stating that its population was an
unapplied document and its guard unreachable in the current state. That session measured zero,
correctly, and nearly filed a defect against a working engine.

## A receipt that reads a RENDERED artifact is closable by prose

Drive the shipping program; do not grep the document it produced. Measured: a backlog receipt
keyed on a row of a generated index, where that row's cell rendered from a COMMENT no arm
validates — three names appended to that one line returned receipt 0, render 0 and gate 0 with
no owner, no invariant and no behaviour changed. Ask of every receipt what ELSE satisfies it,
and prefer the arm that RUNS the subject over the one that reads its output.
Isolating the subject is not the PROGRAM: a CALLER defect stays invisible, and a movement it never reaches reads as behaviour.

**A receipt that accepts TWO candidate fixes has established neither.** Measured: an entry said
its receipt "takes either fix" and it did — one of the two was a regression that shipped nothing.
Build both and score them. Once an entry rotates its receipt is ARCHIVED and inert while the
FIXTURE still runs, so score a proposed receipt-weakness against the fixture before reading it as
a coverage gap: four implementations satisfied one receipt and the fixture killed three.

## A control that agrees with the verdict is not a control

Run the control against the thing the verdict claims is ABSENT, and read its output. A
control that proves only that the RUN happened says nothing about whether the ARM could have
fired; those are two separate claims and both need establishing. When a search returns
nothing, the control must be a token you already know is present in the same corpus, in the
same invocation.

## A differential must prove its two sides differ

Both runs reading the same tree establishes nothing. Measured: a `sed` making a probe's root
overridable expanded to the identical line, so both runs used the fixed copy and the outputs
matched perfectly — which reads as "no regression". Assert the sides differ, in the same
invocation, before reading the comparison.

**AND IT MUST BE ABLE TO RESOLVE THE EFFECT.** A differential whose spread across reps is the
size of the thing being measured reports a null that means nothing. Measured: a removal
differential read 7130 against 7130 with a spread of ±2 and shipped the claim "costs ZERO",
which a per-line attribution table then contradicted directly. Ask what a differential can
RESOLVE before reading a null off it.

**DIFFERING SIDES ARE NOT ENOUGH: ASK WHAT MAKES BOTH FAIL.** Two different programs both failing
for a reason NEITHER owns is non-discriminating and its null reads as agreement. Measured: 16
series, 16 identical `1 -> 1` pairs, 0 findings — the subject fails CLOSED without a flag the probe
cannot pass. The signal was the ARM each side NAMED, not its status.

## Time both sides the same way, and interleave the reps

A `mktemp` extraction timed against the live repo compares two TREES, not two revisions.
Measured: that shape read +1.9s and nearly bought an optimisation pass against a regression
that does not exist. Extracted alike and interleaved, five reps: 17.29s vs 17.10s.

## Run the shipping code against the real corpus

A hand-written probe is a second implementation whose bugs nobody finds. When a probe and
the shipping code disagree, the probe is wrong until proven otherwise. Reach for the real
program and the real tree; where that is impossible, say so in the same breath as the number.

## Cross-check a parser against what EXECUTES it, never against another parser

A second implementation of a grammar is an opinion; the thing that runs the input is the
answer. Measured on a shell quote scanner over 3408 real commands: checked against python
`shlex` AND against `bash -n -c`, the two oracles disagreed on 23. `shlex` was wrong on 20 of
them, and the 2 the scanner itself got wrong were a real defect it was about to ship. Taking
`shlex` as the oracle buys 21 phantom cases and misses both true ones.

## Read the CONSUMING mechanism's own remedy text before calling its input wrong

The contract is usually written inside whatever reads the value. Measured: a fix made
`--is-core` refuse a path naming no file, and the guard that consumes that answer already said
the deny "stands whether or not the distribution ships a file by that name". Reverted one release
later. A byte-comparison of two programs' shared HELPERS is not a binding on their ANSWER, which
is why that gate stayed green throughout.

## Verify the premise before building

Every plan, catalog entry, ledger row, handoff tag and consumer report is a HYPOTHESIS about
a tree that has moved since it was written. The measured base rate of expired premises here
is roughly one in two. A claim that names a real file reads as verified and is not — the
file existing is not the claim.

## Ask what SET a number was taken over

For every figure: what population produced this, and is it the population the mechanism
actually runs on? A recorded instance count is a FLOOR. Most failures of this kind are
failures of scope, not of arithmetic, and they read as precision.

## A correction is itself a measurement, and NARROWING is not the safe direction

Correcting a claim toward "narrower" reads as honesty and is just as capable of being wrong.
Measured, inside one release: a shipped entry was corrected mid-batch to say a gate's blindness
held only outside one file class — which was one ROW of a two-row table read as the whole table.
On the other row the gate caught nothing at all, and a second hand had to WIDEN the claim back.
Ask which row a correction was measured on before believing it.

## Key a binding on the emission site

A whole-file `grep -qF` is satisfied by a comment. A grep hit inside a file is not a
statement about that file, a prose statement of provenance is not a reader, and a declaration
of intent is never evidence about content. Bind to the line that EMITS the thing, not to a
file that mentions it.

## How a false-positive set reached zero is part of the arm

`CLAUDE.md` requires the FP set measured before a check ships. Record the narrowing that got
it there, beside the arm. An arm with no narrowing story is unfinished, and the next author
widens it back.

## Resolve the repo root by walking up for a marker

Never count `..` hops. A validator that counts hops answers differently from the repo root,
from a subdirectory, and from a fixture sandbox that copied it — and the sandbox answer is
usually the silent one. Walk up for `VERSION`.

## A glob that matches nothing must not report success

`for f in docs/plans/*.md` with no matches iterates once over the literal pattern in some
shells and zero times in others. Either way an empty corpus exits 0 and reads exactly like
"every file passed". Count the corpus and fail on zero.

## A calibration is a property of its text, not of its divisor

A bytes-per-token figure measured on one population under-counts on another. Carrying a
divisor across populations produces the same number with the opposite error, and it survives
review because the arithmetic is right. Re-measure the calibration whenever the corpus
changes.

## Ask what rate a hypothesis PREDICTS before a zero refutes it

A zero consistent with the hypothesis is not evidence against it. Measured: 48 runs hunting a
0.83%-rate defect returned nothing, the expected count was 0.4, and that clean sweep read as a
refutation. Compute the predicted count FIRST; below one the run cannot discriminate, and a
forced input beats a larger N.

## Verify a release the way the gate runs it

`AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`, and read the fixture by NAME. The
CONSUMER's hook `core/git-hooks/pre-push` prints a green banner here having run almost
nothing; the content-key skip prints one too, correctly — neither is evidence your change ran.
The TALLY is not the verdict either: 159 ok / 0 FAIL while the gate exited 1 on a phase outside
the suite. Read the gate's exit, never a backgrounded wrapper's.

**And a green gate is not a landed push.** Twice, every phase PASS, `pre-push: all gates green`,
exit 141 from the transport, and the ref NOT on origin — `git ls-remote --heads origin <branch>`
empty against a control. Confirm the remote ref moved before opening a PR or reporting a release.

## An entry with two subjects expires only when both do

Measured on a proposed close: two verifiers agreed on every measurement and split on what the
entry CLAIMED. The named fix was real, the cited code was genuinely gone, and a second subject
one paragraph down was untouched. Enumerate the entry's distinct claims BEFORE reading a good
measurement as a close, and say which survive. A release note asserting the fix is not evidence
either — the one that shipped this half-landed fix says "both" in as many words.
