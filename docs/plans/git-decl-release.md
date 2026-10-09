# git.decl release — a seeded repository inside the hermetic sandbox

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/git-decl-release.md`. This section is the ONLY
CURRENT STATUS RECORD in this file.**

**What this is.** One release, built and verified, not yet gated. `core/scripts/hermetic-run.sh` reads an optional
`<fixture dir>/git.decl` and builds a git repository inside the sandbox: `seed` commits the copied tree, `pin <40-hex>`
imports one commit and its tree (no parents) from the project's own object store as a pack built at run time (exit 2 if
absent), `pin? <40-hex>` imports when present and otherwise prints `not imported` and leaves the fixture's own absent-pin
branch to decide. Nothing is written under `core/`, so arms I104, I113 and I65 see no second corpus — the reason the
0.760.0 CHANGELOG gives for leaving the procsub units undeclared no longer holds. Eight fixture directories are declared
with it: `procsub-staged-refusal{,-b,-c}`, `procsub-staged-refusal-boot{,-b,-c}`, `retired-layer-contract` (`pin?`,
it ships) and `prepush-pool-depth` (`seed`). `hr_store_put` refuses to record a pass when any `pin?` was skipped
(`[ "${hr_pin_skipped:-0}" = 0 ] || return 0`), because the store key carries no trace of the pin.

**State.** Branch `b218-git-decl` on GitHub at `febd40271741`, three commits on `7502966d` (branch
`release-0.762.0-durable`, ai-dlc-77's squashed release carrying the per-project verdict store and the
`# HR_SANDBOX_BEGIN`/`END` span). No VERSION, no CHANGELOG entry: both are written at push time. On that tip, all
measured in a scratch clone: `hermetic-runner` rc 0, 262 ok, 0 FAIL, mutants M12..M16 each failing exactly arm X; the
eight fixtures all rc 0, 0 FAIL (procsub-staged-refusal 170/106/111, -boot 62/52/52, retired-layer-contract 70 with four
`pre-fix differential` lines, prepush-pool-depth 48), one store entry each; `scripts/validate-enforcement-map.sh` rc 0;
the git.decl block sits inside the HR_SANDBOX span.

**What it is waiting on.** ai-dlc-77 stopped its 0.762.0 gate on the operator's order and is single-sourcing the verdict
store's key logic: the runner becomes the store's ONLY writer and the hook's writer is deleted, so the `pin?` rule in
`hr_store_put` covers every write. That moves code this branch touches; ai-dlc-77 will send a new base sha. Release order,
agreed between the sessions: ai-dlc-cc's self-update fix takes 0.762.0; ai-dlc-77's store release takes the next free
number after it lands; THIS release takes the next free number after that, read from `origin/main` at push time.

## Start here

- **Repos.** Read and write THIS repo only, through a fresh `mktemp -d` clone of `git@github-euron8:euron8/ai-dlc.git`
  under your scratchpad, with `git ls-remote` as the control on every sha you act on. The consumer repo (graph): read it,
  never write it. A scratch consumer built by `scripts/install.sh` into a `mktemp -d` is yours to write.
- **The main checkout `/Users/n8/git/ai-dlc` is shared with ai-dlc-77, ai-dlc-cc and ai-dlc-a3.** Before touching it,
  ask each what it holds and WAIT for every answer; gate from it only after the previous release's session sends LANDED.
- **Never message a `graph-*` session.**
- **Delegate.** The operator's instruction to the session that wrote this plan: do not do the work in the lead session,
  spawn agents. Every `Agent` spawn passes `isolation: "remote"`, works in its own `mktemp -d` under the scratchpad,
  never runs `rm -rf` on a variable path, and returns findings as text.
- **Ping the operator** on any question, on any decision, and on completion including an early stop.
- **The CHANGELOG body is drafted** in the last section of this file; put it in at push time with the version and date.
- **Why a declaration needs no read-set map rows.** The deriver skips any fixture carrying `inputs.decl`
  (`core/scripts/derive-fixture-readsets.sh:305`), and the hook keys it on its declaration under its fixture root
  (`.githooks/pre-push:431`). Do not edit `.ai-dlc-fixture-readsets.tsv` for this release.

## Next actions

1. Ask ai-dlc-77 by `SendMessage` for the new base sha of its single-sourced verdict store. **Blocked** until it sends one;
   confirm it with `git ls-remote` before using it.
2. Spawn ONE rebase agent (`isolation: "remote"`). Its brief: rebase `b218-git-decl` (three commits on `7502966d`) onto the
   new base with `rebase --onto <new> 7502966d5f9856376a904c7e089c08f2fccf289d`; keep the git.decl block inside
   HR_SANDBOX_BEGIN/END and the `pin?` guard in `hr_store_put` reached on a passing run; assert by `grep` that no store
   writer remains in `.githooks/pre-push` or `core/git-hooks/pre-push`; then run `bash -n` on the changed scripts,
   `bash core/fixtures/hermetic-runner/run.sh` (rc 0, 0 lines starting `  FAIL`, M12..M16 each `fails exactly its own
   arms [X ]`), the eight fixtures each through `core/scripts/hermetic-run.sh` with its own `AI_DLC_VERDICT_STORE` under
   a `mktemp -d` (all rc 0, ok counts as in State), and `scripts/validate-enforcement-map.sh` (rc 0); count files under
   `$HOME/.cache/ai-dlc/verdicts` carrying `#fixture probe` before and after (must not rise); push with
   `--no-verify --force-with-lease=b218-git-decl:febd40271741` and confirm by `ls-remote`. Collect its report by content.
3. Wait for LANDED from the session gating ahead of you (ai-dlc-cc, then ai-dlc-77). **Blocked** until both have landed on
   `origin/main`.
4. Rebase `b218-git-decl` onto `origin/main` (a no-op if 77's release landed unchanged). Read the next free version from
   `origin/main`'s `VERSION`, announce it to ai-dlc-77 and ai-dlc-cc BEFORE building on it, then write `VERSION`, the
   CHANGELOG heading and the drafted body (fill the version and date), squash to ONE commit whose subject starts with that
   version, and run `scripts/validate-release-version.sh` until it exits 0.
5. Gate it: send GATE START to every `ai-dlc-*` peer, push `release/<version>` from the main checkout detached at the
   commit (the hook's own run is the single gate; no `AI_DLC_FIXTURE_NO_SKIP`), read each of the eight fixtures and
   `hermetic-runner` BY NAME in the run's output, confirm the ref moved with `git ls-remote`, open the PR and squash-merge
   it (merges are preapproved), then send LANDED.
6. Re-derive this RESUME block AFTER THE MERGE from `origin/main`: mark the release landed with its merge sha, or rotate
   this plan with `scripts/plan-rotate.sh` if nothing is left. Commit and merge that docs change.
7. Fresh-resume check: read this file from a fresh checkout of `origin/main` as a stranger, re-run the shas in State with
   `git ls-remote`, assert no next action names work a commit on `origin/main` has shipped, and run
   `scripts/validate-plan-shape.sh` there.
8. Hand off: `ListAgents`; for each idle `ai-dlc-*` session (never `graph-*`), `SendMessage` exactly
   `READ and FOLLOW docs/plans/git-decl-release.md`, trying the next on a `REFUSED:` reply, until one replies
   `ACCEPTED`. Then stop.

## Done when

The release is merged to `main` with `VERSION`, the CHANGELOG heading and the commit subject naming one version
(`scripts/validate-release-version.sh` rc 0), its gate's output shows `hermetic-runner` and all eight git.decl fixture
directories `ok` by name, and `git ls-remote` shows `main` at the merge commit. Every part of that is reachable: each
of those fixtures has already passed through `hermetic-run.sh` on this branch, and the validator passed on the earlier
release-shaped commit until the version was withdrawn.

## Drafted CHANGELOG body

Replace `@@VERSION@@` and `@@DATE@@` at push time. Re-check every figure against the gate run before keeping it.

```
## [@@VERSION@@] - @@DATE@@

One release. `hermetic-run.sh` builds a git repository inside the sandbox when a fixture declares one
in `git.decl`, and eight fixture directories that ran on every push because they need a real repository are
declared: the three `procsub-staged-refusal` units, the three `procsub-staged-refusal-boot` units,
`retired-layer-contract` and `prepush-pool-depth`. No pre-push hook and no bootstrapping file change.

### `git.decl`

`<fixture dir>/git.decl` is optional and read only by `hermetic-run.sh`. `seed` makes the sandbox root a work tree
holding one commit of the copied tree (fixed date, no hooks, no signing). `pin <40-hex sha>` imports that commit and
its tree, never its parents, from the project's own object store, and a pin the project lacks is exit 2. `pin? <sha>`
imports when present; when absent it prints `not imported` and the fixture's own absent-pin branch decides, which is
the form a SHIPPING fixture uses because a consumer has no such commit. An abbreviated sha or any other line is exit 2.

The objects travel as a pack built at run time into the sandbox's own `.git`. Nothing is written under `core/`, and
no alternates file points at the project's store, which would be a read outside the declaration. The hook's key is
unchanged: `git.decl` is a file of the fixture's own directory and is keyed as one, and a sha names immutable content.

**A pass with an optional pin not imported is not recorded in the shared verdict store.** The store key carries no
trace of the pin, so a shallow clone's pass, whose pinned differential SKIPPED, would otherwise be reused by a full
clone where that differential runs. Measured on a depth-1 clone: `retired-layer-contract` rc 0, its own `SKIP the
pre-fix differential` line, 0 store entries; on the full clone rc 0, the four pre-fix lines, 1 entry.

### The procsub units are declared, and the 0.760.0 ruling's reason no longer holds

0.760.0 left `procsub-staged-refusal` and `procsub-staged-refusal-boot` undeclared by ruling: a build that committed
their 118 pinned blobs under `core/fixtures/.../pins/` passed `hermetic-run.sh` and then failed arms I104, I113 and
I65, which scan `core/` by content and found a fourth copy of the snapshot readers in the pinned hooks. `git.decl`
removes that reason by construction: the pinned commits reach the sandbox as git objects at run time, so no pinned
blob is ever in the tree those arms scan. `validate-enforcement-map.sh` on this tree: rc 0.

- **`procsub-staged-refusal{,-b,-c}`**: `seed` plus five required pins (`e4934e65`, `d1c72fa9`, `b0c310a3`,
  `322ef42c`, `1749b545`). The spelling arm diffs every `core/*.sh` outside `core/fixtures/` against `e4934e65` in the
  SEEDED repository, so every directory holding one is declared whole.
- **`procsub-staged-refusal-boot{,-b,-c}`**: two required pins (`a0a9c556`, `1749b545`), and the sibling
  `reconcile-emit-report/` whose `seed.sh` it stages. Control: with `git.decl` removed the parent exits 2, `could not
  stage layer-drift.sh and hard-blockers.sh at a0a9c556`, so the pins are what its failing controls consume.
- **`retired-layer-contract`** (ships): `pin? d1c72fa9`. On a scratch consumer built by `scripts/install.sh` it runs
  rc 0 with `optional pin ... not imported` and its own SKIP line, 65 ok, 0 store entries.
- **`prepush-pool-depth`**: `seed`, for its `git rev-parse --show-toplevel`.

Left forced, read from their code: `self-update-join-gate` walks a history range (`log -S`, `rev-list`) neither shape
supplies; `validator-fork-budget`, `ledger-status-vocabulary` and `fixture-git-env-seam` read the whole tracked tree,
so a declaration would key them on everything and save nothing.

**The abbreviated-index question, settled by a run, not a reading.** The sandbox repository holds far fewer objects
than this one, so git abbreviates its `index` lines to 7 hex digits where this repository uses 8. The spelling arm
reads `17144 line(s) added since the pin` in the sandbox and the same count run unsandboxed on the identical tree.

### Measured

Every fixture below run through `hermetic-run.sh` on this tree, each with its own verdict store, all rc 0, 0 FAIL:
`procsub-staged-refusal` a/b/c 170, 106, 111 ok; `procsub-staged-refusal-boot` a/b/c 62, 52, 52; `retired-layer-contract`
70 with all four pre-fix lines; `prepush-pool-depth` 48. Each wrote one store entry. Wall clock at load around 45:
52s to 225s per unit. Building the pin pack costs roughly 1 to 11 seconds per run on this box and is
load-dominated: 2.46, 1.38 and 3.22s for `procsub-staged-refusal-boot`'s two pins, interleaved with the six-pin form
at 2.27, 1.26 and 3.41s.

`hermetic-runner` gains arm X (seed, pin, a pin whose blob differs from the tree's, no `git.decl` as control, a
required pin absent, `pin?` absent and present with the store write checked both ways, an abbreviated sha, an unknown
line) and mutants M12 to M16, each failing exactly arm X: 262 ok, 0 FAIL, every mutant failing exactly its own arms.

The runner change re-keys every declared fixture's verdict-store entry once, because the digest hashes the runner's
HR_SANDBOX span and the git.decl block sits inside it.

The read-set map is not edited: a fixture with `inputs.decl` is keyed on its declaration and skipped by the deriver.
```
