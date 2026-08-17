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

## Run the shipping code against the real corpus

A hand-written probe is a second implementation whose bugs nobody finds. When a probe and
the shipping code disagree, the probe is wrong until proven otherwise. Reach for the real
program and the real tree; where that is impossible, say so in the same breath as the number.

## Verify the premise before building

Every plan, catalog entry, ledger row, handoff tag and consumer report is a HYPOTHESIS about
a tree that has moved since it was written. The measured base rate of expired premises here
is roughly one in two. A claim that names a real file reads as verified and is not — the
file existing is not the claim.

## Ask what SET a number was taken over

For every figure: what population produced this, and is it the population the mechanism
actually runs on? A recorded instance count is a FLOOR. Most failures of this kind are
failures of scope, not of arithmetic, and they read as precision.

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

## Verify a release the way the gate runs it

`AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`, and read the fixture by NAME in the full
output. `core/git-hooks/pre-push` is the CONSUMER's hook: run here it prints a green banner
having executed almost nothing. The content-key skip prints a green banner too, and it is
correct to — but neither is evidence that your change was exercised.
