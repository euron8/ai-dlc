<!-- unconditional: the boundary decides what a task may write before any file is opened, so no `paths:` glob can carry it; it must also reach subagents. -->

# The consumer boundary

This repo is the distribution. A consumer is a separate tree with AI/DLC installed into it.

## An ai-dlc session never writes to a consumer

- Write `core/` and the brief. Run the real machinery against a consumer only on a **scratch copy**, never in
  place; rehearse a bulk migration or pull on a `file://` clone first. Every figure in a brief comes from that
  run, not from a reading of the code.
- Plan across both trees, and close the goal with a measurement taken on the consumer side.
- The rehearsal clone carries committed HISTORY (gate logs, archives, artifact history). A brief states the
  mechanism from the code and what it is worth from that history: grep the clone for the consumer's own record
  before calling a change a risk.
- Never label a reachable measurement unreachable. State what you did not measure AND whether it was
  available.

## The distribution is not a consumer

- `install.sh` splits what shares a parent here: `core/scripts/<x>` lands at `scripts/ai-dlc/<x>`,
  `core/schemas/` lands at `.claude/schemas/`. A path that resolves in this tree can resolve nowhere in an
  installed one; invariant **I33** fails the build on locating one core file by walking up from another.
- Verify anything touching path resolution on a tree built by running `scripts/install.sh` into an empty
  directory, and run the suite there as a consumer runs it, in both layouts.

## A consumer runs its OWN installed engine

- Only steps 1-2 of the delivering pull run the old engine. Step 2 self-updates and re-invokes, so engine code
  is live from step 3 unless DEFERred; rulebook waits for the reconcile PR merge.
- A core fixture ships ahead of its subject: it must tolerate the subject being absent without reporting green
  as though it had checked something.
- A detector fix ships machinery-only, so the pull it arrives on is classified by the fixed detector.

## Packaging is enumerated in several places

- A consumer-facing script needs `core/scripts/` AND `install.sh`'s copy loop.
- A SHIPPING fixture needs `uninstall.sh` plus both manifest copies; a `.dist-only` fixture needs none.
- A hook needs registration in the settings template AND a committed executable bit.
- Derive rather than hand-list; where a list must stay hand-written, bind it in both directions by an
  invariant. `.claude/rules/fixture-ship-decl.md` carries the fixture half and the deliberate exceptions.
