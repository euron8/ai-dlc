# git.decl release — a seeded repository inside the hermetic sandbox — DISCHARGED

**DISCHARGED at `0.764.0`. DO NOT EXECUTE.** Every numbered action is done and the release is on `main`. This file is a
RECORD of what shipped and how it was gated; it carries no next action.

## LANDED

- **Merge.** `0.764.0` merged to `main` as `ec9d11c0` (PR #1092). Its tree equals the gated commit `4c99d60f`.
- **What shipped.** `core/scripts/hermetic-run.sh` reads an optional `<fixture dir>/git.decl` and builds a git repository
  inside the sandbox: `seed` commits the copied tree, `pin <40-hex>` imports one commit and its tree (no parents) from
  the project's own object store as a pack built at run time (exit 2 if absent), `pin? <40-hex>` imports when present
  and otherwise prints `not imported` and leaves the fixture's own absent-pin branch to decide. `hr_store_put` refuses to
  record a pass when any `pin?` was skipped. Eight fixture directories are declared with it:
  `procsub-staged-refusal{,-b,-c}`, `procsub-staged-refusal-boot{,-b,-c}`, `retired-layer-contract` (`pin?`, it ships)
  and `prepush-pool-depth` (`seed`). The full account is the `0.764.0` CHANGELOG entry.
- **Gate.** `release/0.764.0` was pushed from the main checkout: push rc 0, `pre-push: all gates green`, 0 FAIL lines,
  47 of 277 fixtures run. `hermetic-runner` and all eight git.decl fixtures each show `ok` by name, and none appears on
  a verdict-store skip line.
- **Post-green trace.** It exited 0 and recorded 2 of 5 fixtures. It discarded `fixture-git-env-seam`,
  `validator-fork-budget` and `hermetic-runner`.
- **Correction to an earlier citation.** This plan once cited `.githooks/pre-push:431` for the hook keying a declared
  fixture on its declaration. Line 431 only sets `FXROOT`; the declaration keying is at about `:1235`–`:1237`. The
  deriver skip is `core/scripts/derive-fixture-readsets.sh:305`.
- **Left forced, not declared.** `self-update-join-gate` walks a history range neither shape supplies;
  `validator-fork-budget`, `ledger-status-vocabulary` and `fixture-git-env-seam` read the whole tracked tree, so a
  declaration would key them on everything and save nothing.

## Start here

Nothing is left to execute. Read this file, never write it: it is a closed record. If asked to act on it, report to the
operator that it is discharged and ping the operator on any question about what remains.

Closed actions, all done and none to repeat:

1. Rebase `b218-git-decl` onto the single-sourced verdict store base: DONE.
2. Version, CHANGELOG entry, one squashed commit, `scripts/validate-release-version.sh` rc 0: DONE as `0.764.0`.
3. Gate from the main checkout, read the eight fixtures and `hermetic-runner` by name, squash-merge: DONE as `ec9d11c0`.
4. Re-derive this record after the merge: DONE by this commit.

## Filed from this release

`BL-495` in `docs/backlog.md`: fixtures declare whole directories as inputs, so one edit re-keys fixtures that may never
read it. The ledger owns it; this plan does not.
