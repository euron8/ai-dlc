---
paths:
  - "core/fixtures/**"
---

# The fixture contract

Every `core/fixtures/<f>/` is built to this contract. Each clause ends with its enforcer, and
`scripts/validate-claude-rules.sh` A7 fails the push on a clause with none or on a cite that resolves to nothing. A
fixture that predates a clause is a row of its arm's down-only allowlist: migrate it and drop the row in the same
change. Building good arms is `fixture-mutants.md`'s; shipping is `fixture-ship-decl.md`'s.

## The run.sh skeleton

- **C1** `run.sh` runs as `bash core/fixtures/<f>/run.sh` from the repository root, never after a `cd` into its
  directory, and resolves the root from the working directory. Enforcer: `core/scripts/hermetic-run.sh` HR_SANDBOX.
- **C2** Its first command sources `lib/preamble.sh`; the first statement after `set -uo pipefail` is the
  env-derived `AI_DLC_*` unset loop. Enforcer: `scripts/validate-fixture-git-env.sh`;
  `scripts/validate-fixture-hygiene.sh` H8.
- **C3** It sources `lib/report.sh` before any `lib/mutant.sh` it uses for `fx_inproc`, asserts only through `ok` and `bad`, and ends with
  `report_end <f> [<expected count>]`. Enforcer: `scripts/validate-fixture-hygiene.sh` H10.
- **C4** Every `lib/*.sh` source is guarded: a missing file exits non-zero. Enforcer:
  `scripts/validate-fixture-hygiene.sh` H6.
- **C5** A pre-push hook runs only through `hook_drive`. Enforcer: `scripts/validate-fixture-hygiene.sh` H11.
- **C6** No verdict or count depends on load: wait on the condition, never on elapsed time or an iteration bound.
  Enforcer: `scripts/validate-fixture-hygiene.sh` H9.
- **C7** Each `!` input prints `HERMETIC-CONSUMED <path>` at the point it is used. Enforcer:
  `core/scripts/hermetic-run.sh` HR_SANDBOX.

## The library, `core/fixtures/lib/`

- **C8** Use the entry point; never re-implement one in a fixture. `preamble.sh` (sourced first). `report.sh`: `ok`,
  `bad`, `report_end`. `world.sh`: `world_git` (scrubbed, fixed identity), `world_repo`, `world_commit`,
  `world_install <root> <dir>`. `hook-drive.sh`: `hook_drive [--hook <path>] <tree> <out> [NAME=value ...] [--
  <args>]`, which prints the hook's status and runs it with `GIT_*` unset, stdin `/dev/null`,
  `AI_DLC_READSET_LIVE_TRACE=0` and the store `<tree>.verdicts`; it sets no `AI_DLC_FIXTURE_JOBS` (a nested pool is
  capped at two workers). `inproc.sh`: `inproc_load`, `inproc_run`. `mutant.sh`: `fx_inproc`. `settled-net.sh`:
  `st_net`, `st_reap`. `layout.sh`: `fx_dist_layout`, `fx_skip_exit` (ends a subject-absent SKIP: exit 0 on a
  consumer, FIXTURE BROKEN in the distribution). `pool-span.sh`: `pool_span <hook> <out> <SPAN>...`, which writes the named hook spans under an
  exported store default of `<world>.verdicts` for the shell that sources `<out>` inside its world. Enforcer: `core/fixtures/suite-dispatch-order/run.sh` hook_drive, world_git, report_end;
  `scripts/validate-fixture-hygiene.sh` H10, H11, H14.
- **C9** No fixture carries a mutation battery: no `run.sh` or `lib.sh` calls or defines `mutant_killed`, `need_base`,
  `matrix_row`, `mkmut`, `mut_copy` or `mutate_file`, carries a `# MUTANT-MATRIX` line or sources `lib/matrix.sh`.
  That an arm can fail is proved once, by hand, at authoring. Enforcer: `scripts/validate-fixture-hygiene.sh` H12.
- **C11** An in-process pass is `inproc_load` then `inproc_run`, or a source paired with `fx_inproc`, and is counted
  on an `inproc:` row. Enforcer: `scripts/validate-fixture-invocations.sh` P2, J7.

## The declarations, `core/fixtures/<f>/`

- **C12** `inputs.decl`: one root-relative path per line; a trailing `/` declares a directory (keyed on its listing
  and every file under it); a leading `!` is REQUIRED (C7); a leading `+` keys a file outside the universe; `#` and
  blank lines are ignored. An absolute path, a `..`, `!+` together or `+` on a directory is refused. A directory
  line never keys another fixture's `inputs.decl` or `invocations.decl`; a fixture that reads every fixture's
  declaration declares `core/fixtures/*/inputs.decl`, which expands to one file row per match. Enforcer:
  `.githooks/pre-push` readset_decl_parse.
- **C13** Declare the narrowest file or span the fixture reads, derived from
  `bash core/scripts/derive-fixture-readsets.sh --list "<f>" --tracer sandbox`, never hand-listed. A whole shared
  program or a whole directory carries a `whole` or `legacy` row in `docs/inputs-decl-whole-rows.tsv`. Enforcer:
  `scripts/invalidation-guard.sh` r1, r2, r3, r4, r5.
- **C14** `spans.decl`: `<path> <NAME>` rows key `<path>#<NAME>`, the `# <NAME>_BEGIN` .. `# <NAME>_END` span of a
  shared program. Enforcer: `.githooks/pre-push` readset_decl_parse.
- **C14a** `section.decl`: `<+ path> <heading>` keys that `+` file on its first section headed `<heading>`, in the
  fixture's key and in `scripts/suite-content-key.sh`. Enforcer: `.githooks/pre-push` readset_decl_parse.
- **C15** `tools.decl`: one tool name per line, keyed by content; `?name` is reachable and unkeyed, and only a name
  in `READSET_UNKEYED_TOOLS`. Enforcer: `.githooks/pre-push` readset_decl_parse.
- **C16** `invocations.decl`: `<n> *` (every bash start), `<n> <path>` (starts of a `!` subject), `<n> inproc:<path>`
  (`fx_inproc` passes), `<c>+<k>x<glob>` (a corpus count); every row exact, set from a counted run. Enforcer:
  `scripts/validate-fixture-invocations.sh` J3, J4, J6.
- **C17** `cells.decl`: `cli <subject> <id>`, `e2e <subject> <id> why=<reason>`,
  `nested <parent> <child> why=<reason>`; every start of a subject carries an `FXCELL` tag. Enforcer:
  `scripts/validate-fixture-invocations.sh` C1, C2, C3; `scripts/validate-fixture-inprocess.sh` C4, C5.
- **C18** `git.decl`: `seed`, `pin <sha>`, `pin? <sha>`, `range <ref-expr> <path>...`. Enforcer:
  `core/scripts/hermetic-run.sh` HR_SANDBOX.
- **C19** `.dist-only` (a non-empty reason) keeps a fixture off the consumer install; `.undeclarable` marks a fixture
  keyed without an `inputs.decl`. Enforcer: **I74**.

## Keys, the verdict store, the runner

- **C20** A declared fixture's key is the rows of its declarations, every file of its own directory, and the
  runner's `<runner>#HR_SANDBOX` and `<runner>#HR_EXIT` rows; the runner is keyed whole only for a fixture that
  declares it by name. One composer, the READSET_KEYROWS span, serves the hook and the runner. Enforcer:
  `core/fixtures/readset-skip/run.sh` rchg, rout; `core/fixtures/hermetic-runner/run.sh`; **I66**.
- **C21** The store identity is `#universe f<READSET_VS_FORMAT>` plus `#runner`; a code change in a `READSET_*` span
  carries a `# VS-IDENTITY <format> <sha> <reason>` pin row. A push reads only `counted-<vk>`. Enforcer:
  `scripts/validate-verdict-identity.sh`; `core/fixtures/readset-skip/run.sh` vs_world.
- **C22** A recorded pass is reused when every current key row is in it with the same value. The fixture's own
  `inputs.decl` is one of its rows, so any edit to it, a narrowing or a comment included, runs the fixture once in
  each layout before its pass is reused. Enforcer: `core/fixtures/readset-skip/run.sh` vs_world w, stale-declared dnar.
- **C23** No change invalidates a verdict whose read inputs it did not change: a fixture selected only by a change it
  cannot read fails the push. Enforcer: `.githooks/pre-push` readset_invalidation_guard; `scripts/invalidation-guard.sh`.
- **C24** A counted run outside the pool gives the fixture stdin `/dev/null`, as the pool does; seed a push with
  `scripts/seed-verdict-store.sh`. Enforcer: `core/fixtures/seed-verdict-store-red-print/run.sh` a4.
- **C25** A hook span that binds the record homes (`FIXTURE_POOL`, `RECORD_HOME`) is extracted only through
  `pool_span`, never by a `sed` or `awk` of its BEGIN marker, so a plain run never files a world's records in the real
  verdict store. Enforcer: `scripts/validate-fixture-hygiene.sh` H13.
