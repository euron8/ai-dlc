# context-provenance

Drives `ai-dlc-context-provenance.sh` — a SOURCED library, not a hook — through the two
hooks that reach its two event branches, and asserts on the only two things it produces:
a hook's emitted JSON, and `_bmad-output/.ai-dlc-context-nonce`.

`run.sh` takes no arguments and needs no fixture data. It builds every project it drives
under `mktemp` and writes nothing into the tree it is run from.

## Why two drivers

`ai-dlc-rules-floor.sh` passes a LITERAL `SessionStart` to `ai_dlc_provenance_tag`, so on
its own it can only ever exercise the rotating branch and the contract paragraph.
`ai-dlc-context-sensor.sh` passes its own `$EVENT`, and is the only end-to-end way to
reach the reuse branch and the no-contract branch. A single-driver fixture would assert
the event split against a library call the fixture made itself, leaving a hook that passed
the wrong event literal invisible — which is the case the split exists to catch.

The library is additionally driven directly at a third event, so the split is established
as a property of the EVENT rather than of either driver.

## What is asserted

| | |
|---|---|
| marker position | `additionalContext` opens with the token at byte 0, not merely contains it |
| marker shape | it names its hook, its event, a hex nonce and the store to verify against |
| payload survival | the marked context ends with the UNMARKED context byte for byte |
| membership | the emitted nonce is a member of the store; a nonce never minted is not |
| rotation | `SessionStart` mints and appends; any other event reuses the newest |
| append-only | after a rotation the OLD nonce is still a member |
| contract | `SessionStart` states it once; no other event restates it |
| fail-open | with the library absent the hook still emits its FULL payload, unmarked |
| bound | a mint trims to the newest 40, keeps the nonce it just minted, and drops the rest |

The unmarked context in the payload-survival row comes from the fail-open run, so those
two rows are one measurement read twice: the library-absent emission IS the payload, and
the marked emission must be that same byte string with a prefix.

## Shape

Every predicate is self-probed in both directions, under `mktemp`, before any of them is
pointed at the subject. Every absence-shaped assertion carries a control in the same arm
that must come back the other way. The three absence-shaped ARMS — no reuse-mint, no
restated contract, no line past the bound — each carry a committed mutant of the library,
copied and `cmp -s` guarded, beside an unmutated control with a positive conjunct.

Resolution is rooted at this file's own directory and names both install layouts
(`core/hooks/` and `.claude/hooks/`). There is deliberately no walk up for a `VERSION`
marker: an installed consumer has none at its root, so a walk-up would resolve to the
operator's enclosing checkout and the fixture would answer about the wrong tree exactly
where it matters most. Cwd-invariance is asserted in its own arm rather than inherited
from how the suite dispatches.

## Verdict

`context-provenance: PASS` on stdout and exit 0; `context-provenance: N assertion(s)
FAILED` on stderr and exit 1. Exit 2 means the fixture itself could not run — the library
or a driver did not resolve, or a driver emitted no payload of its own, which would make
every assertion below it a false pass.
