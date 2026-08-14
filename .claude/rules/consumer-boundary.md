<!-- unconditional: the boundary decides what a task may write before any file is opened, so no `paths:` glob can carry it — by the time a matching read fires, the wrong tree may already have been written. It must also reach subagents, which do most delegated work here. -->

# The consumer boundary

This repo is the distribution. A consumer is a separate tree with AI/DLC installed into it.
Most expensive mistakes here come from treating the two as one.

## An ai-dlc session never writes to a consumer

It writes `core/`, and it writes the brief. Running the real machinery against a consumer is
done on a **scratch copy**, never in place, and a bulk migration or pull is rehearsed on a
`file://` clone first. Every figure in a brief comes from that run, not from a reading of the
code.

"Land it in core and stop" is wrong as a planning stance, though. Plan across both trees, and
close the goal with a measurement taken on the consumer side — a change that cannot be shown
to have moved anything there has not been shown to work.

**The rehearsal clone carries committed HISTORY, so the stakes are almost always reachable —
and the failure is not looking.** A brief states the mechanism from the code; what it is worth
comes from what that consumer has actually been doing, and gate logs, archives and artifact
history are committed. Measured: a brief said a proposed change "could fail" at one gate, and
the consumer's own archived gate log — thirty-one files carrying the token, in the clone the
brief was rehearsed on — recorded that gate PASSING on that exact clause across ten sprints.
One `grep` in a tree already on disk separated "a risk to weigh" from "a regression, dated".

**Never label a reachable measurement unreachable.** That brief's limitations section called
the finding "reasoning about prose semantics, not a measurement", written as honesty and
read as a boundary: an unmeasured claim marked unmeasurable stops the next reader from
looking. State what you did not measure AND whether it was available — those are different
admissions, and only the second one is a limit.

## The distribution is not a consumer, and a green push here proves nothing about one

`install.sh` splits what shares a parent here: `core/scripts/<x>` lands at
`scripts/ai-dlc/<x>`, `core/schemas/` lands at `.claude/schemas/`. A path that resolves in
this tree can resolve nowhere in an installed one. Verify anything touching path resolution
on a tree built by running `scripts/install.sh` into an empty directory, and run the suite
there as a consumer runs it — in both layouts.

The failure this prevents is silent in the direction that matters: the fixture passes here,
reaches the consumer, and cannot fail there because its subject is absent.

## A consumer runs its OWN installed engine

Whatever is on `main` here is not what a consumer executes; the consumer executes what it
last installed. Three consequences, each of which has shipped a broken pull:

- **A fix to a bootstrapping step can never be delivered by that step.** The broken version
  is the one that runs the delivery.
- **A core fixture ships ahead of its subject.** The fixture arrives in one pull and the code
  it guards in the next, so it must tolerate the subject being absent without reporting green
  as though it had checked something.
- **A detector fix must ship machinery-only**, so the pull it arrives on is classified by the
  fixed detector rather than by the one being replaced.

## Packaging is enumerated in several places and every one of them rots

A consumer-facing script needs `core/scripts/` AND `install.sh`'s copy loop. A SHIPPING
fixture needs `uninstall.sh` plus both manifest copies. A `.dist-only` fixture needs none of
those. A hook needs registration in the settings template AND a committed executable bit.

Derive rather than hand-list wherever the tree allows it; where a list must stay hand-written
it is bound in both directions by an invariant. `.claude/rules/fixture-ship-decl.md` carries
the fixture half and the three deliberate exceptions.
