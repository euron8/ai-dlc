# Authoring rules — ai-dlc itself

Scope: work in THIS repo (`core/`, `scripts/`, `core/fixtures/`).

Everything under `templates/` is the consumer distribution's output, not this repo's rulebook.
`install.sh` copies `coding-conventions.md.template` to the consumer's `docs/coding-conventions.md` and
`CLAUDE.md.template` to the consumer's `CLAUDE.md`. **That last one shares this file's basename and is a
different file** — put no ai-dlc-authoring rules in the template, do not treat the template as binding here,
and check which of the two you have open before editing.

## A zero is not a finding

Any command whose answer is an ABSENCE carries a control, in the same invocation, that must come back
non-zero. Report both. Without one you have established that your search ran, not that the thing is missing.

False-zero sources:

- **Unbraced `$ref:path` in zsh.** Always `"${r}:core/..."`; `.claude/rules/tool-hazards.md` owns the rest.
- **Case-sensitive grep against a differently-cased token** (`v8` against `V8`).
- **A per-file grep against a glob-declared list.** `core-manifest.md` declares `steps/*.md`; grepping it for
  one step file's name returns 0 for every file.
- **An empty or `.` pathspec.** `:(exclude)` with no value excludes the whole tree, and `git grep` then exits
  **1, not 128**.

**The control can be the thing that is wrong.** A negative control must be a token NO commit, file or corpus
entry carries — verify it is absent before trusting the zero beside it, and never reuse an id this repo's own
prose mentions. A control returning non-zero where zero was expected means the control is bad, not the query.

## A check that cannot fire reads exactly like one that passed

Before shipping a check, prove it can fail. Guard headers that restate this rule locally stay; do not
consolidate them here.

## Run the fixture suite the way the hook runs it, never a hand-rolled loop

- `.githooks/pre-push` is the runner: worker pool, content-keyed skip, and a check that every dispatched
  fixture gave a verdict. Invariant **I66** binds that runner to be one program across both pre-push hooks.
  Never loop over fixtures by hand; run one as `bash core/fixtures/<fx>/run.sh` from the repo root.
- A unit's push is its gate: a green push delivers that exact sha, merged as pushed, and fills the verdict
  store `<vs>` (`$AI_DLC_VERDICT_STORE`, default `~/.cache/ai-dlc/verdicts`) and its key records
  (`<vs>/fixture-keys/<root>/<fx>.key`). Never push to a throwaway ref.
- Pushes and pre-push suites may run concurrently. `scripts/predict-push-set.sh <tree> <empty dir>` prints,
  read-only, the set a push runs.
- After a red push the failing set is in `.git/ai-dlc-fixture-failures`; a re-push re-runs those and any
  whose key moved.
- Clear the shared verdict store by EXACT LISTING before a gate, never by glob or `rm -rf`.
- Pool width is `AI_DLC_FIXTURE_JOBS` (default 12; not `FIXTURE_JOBS`), read at the top of the hook's pool
  block. A nested pool (depth 1 or more) is capped at two workers. Re-measure on a smaller box.
- `<vs>/fixture-verified/<root>` (with its `.format` sidecar, which must read `v2`) is the
  verified-state record: written after a green fixture suite, even under a red step, as a copy of that run's
  file-content manifest; the read-set skip reads it to decide which fixtures' inputs moved. A red suite never
  writes it; an unstamped record means "run everything"; deleting it forces a full run.
- `<vs>/suite-key/<root>` is the whole-suite content key: when key and fixture count match the last green suite,
  the push prints `SKIPPED -- this exact tree already passed the whole suite` and runs no fixtures. Each
  decision appends `<utc stamp> HIT|MISS|FORCED|UNAVAILABLE <key>` to `.git/ai-dlc-suite-key.log`; count with
  `awk '{print $2}' .git/ai-dlc-suite-key.log | sort | uniq -c`.
- A push is judged on the PUSHING worktree's working tree, never on the sha the push names: `core.hooksPath`
  is the main checkout's `.githooks`, which does `cd "$(git rev-parse --show-toplevel)"` and reads the
  `<local sha>` stdin only in `push_delete_only` and `pregate_gate`. Push from a clean worktree whose
  `git rev-parse HEAD` is the exact sha.
- `scripts/suite-content-key.sh` declares which paths cannot change a fixture verdict, as the names between
  `# EXCLUDE_BEGIN` and `# EXCLUDE_END`. Both skips in `.githooks/pre-push` read it (the whole-suite key, and
  `readset_excluded_re` for the per-fixture read-set skip). A `+`-declared fixture input (e.g.
  `+docs/backlog.archive.md`) is hashed by BOTH keys, so every edit to it moves the whole-suite key and
  dispatches its declarers. Every added line needs the two-tree measurement its header describes.
- `core/scripts/derive-fixture-readsets.sh --reconcile` traces every stale, changed and unmapped fixture, no
  sudo; the hook prints that command when it finds stale fixtures. Traces go to
  `.git/ai-dlc-fixture-readsets.local` (the `--local-map` the hook passes); the committed map is
  `.ai-dlc-fixture-readsets.tsv`, which the hook never writes. `AI_DLC_READSET_LIVE_TRACE=0` disables the
  detached trace the hook starts after a green suite.
- `scripts/census-hermetic-coverage.sh` is a one-time census, not a gate: it compares each fixture's sandboxed
  run with a plain one. Its header states options and exit codes. It needs a clean root, never writes the
  durations record, and writes the real verdict store only on a consumer root.
- Derive the fixture count, never quote one: `ls core/fixtures/*/run.sh | wc -l`. The suite is WIDTH-BOUND:
  wall clock is summed unit cost / width, at least the longest; see `.git/ai-dlc-fixture-durations`. A cost
  recorded there is a LOADED cost; never compare it with a solo run.
- A change to a validator the pole invokes is a change to the suite's wall clock. Count the validator's execs
  and invocations before and after, from inside the repo (a copy run from `/tmp` resolves its root elsewhere);
  prefer one recursive grep per subtree over a nested loop.
- A fixture that must hold from any cwd asserts cwd-invariance in its own arms
  (`core/fixtures/check-3b-locked-anchor/run.sh:125`); one green only from the repo root may be asserting
  nothing.

## Some authoring rules live in `.claude/rules/`

Rules that bind one subsystem are path-scoped files under `.claude/rules/` with a `paths:` frontmatter list.
A scoped rule loads on the first matching Read or Edit (not Write, Grep, Glob or Bash), once per session, only
in the session or subagent that read it, and is NOT re-injected after a compaction. Only rules with no
`paths:` are re-injected (`load_reason:"compact"`), and this file is too. The three-clause scoping test is
stated once, in [`resident-context.md`](.claude/rules/resident-context.md).

A prose-only rule — one with no enforcer — must not be SCOPED. A `.claude/rules/` file with no `paths:` key is
durable like this file; it carries `paths:` or an `<!-- unconditional: <reason> -->` marker, never neither and
never both (arm A3b). Arm A6 holds the whole durable channel to a byte ceiling.

**The unconditional rulebooks**: [`verification-discipline.md`](.claude/rules/verification-discipline.md)
(how a thing is established true), [`tool-hazards.md`](.claude/rules/tool-hazards.md) (tool behaviours that
return a wrong answer rather than an error), [`consumer-boundary.md`](.claude/rules/consumer-boundary.md)
(what a session may write), [`mechanism-design.md`](.claude/rules/mechanism-design.md) (how to build an
enforcer), [`resident-context.md`](.claude/rules/resident-context.md) (what may occupy this channel), and
[`operator-rulings.md`](.claude/rules/operator-rulings.md) (standing decisions, including that merges are
preapproved and that every claim is ground-truth sourced).

**The scoped rules**: [`fixture-contract.md`](.claude/rules/fixture-contract.md),
[`fixture-mutants.md`](.claude/rules/fixture-mutants.md),
[`fixture-ship-decl.md`](.claude/rules/fixture-ship-decl.md), [`plan-shape.md`](.claude/rules/plan-shape.md),
[`plan-shape-measured.md`](.claude/rules/plan-shape-measured.md). Arms A1–A4 of
`scripts/validate-claude-rules.sh` bind both directions (a rule with no reader, a pointer with no rule). That
validator is deliberately NOT an arm inside `validate-enforcement-map.sh`. Bold invariant citations are joined
to the live set by arm A5 — see `docs/invariant-index.md`.

**Two triggers cannot fire on their own:**

- Before creating a NEW fixture directory, or editing `install.sh` or `uninstall.sh`, read
  `.claude/rules/fixture-ship-decl.md`. Whether a fixture ships is one declaration and it lives in the fixture.
- A plan you are still writing lives at `~/.claude/plans/<slug>.md`. The moment it becomes a HANDOFF (the thing
  a later session is told to READ AND FOLLOW), promote it to `docs/plans/<slug>.md` and commit it, so
  `scripts/validate-plan-shape.sh` covers it. A `PostToolUse` hook warns on writes under `~/.claude/plans/`.
  Never turn that hook into a `PreToolUse` deny: plan mode requires the file under `~/.claude/plans/` to exist. It
  stays in the operator's home directory and is not part of the distribution (`.claude/*` is gitignored and
  arm A1 fails the push on any tracked `.claude/` path that is not `.claude/rules/**/*.md`).

## The evidence behind these rules is not in this repo

The episodes behind these rules live in the operator's per-project memory directory,
`~/.claude/projects/-Users-n8-git-ai-dlc/memory/`, indexed by its own `MEMORY.md`. Read it before weakening or
deleting a rule that looks arbitrary or over-specified. No gate reaches it. When an
episode there carries a standing rule, the rule belongs in this file or a rulebook beside it.

## Prohibitions need mechanisms

A rule with no enforcer is a suggestion. Prefer deriving both sides of a join over hand-listing either; when
two files must agree, bind them — the numbered invariants in `scripts/validate-enforcement-map.sh` are the
pattern, and `docs/invariant-index.md` enumerates the live ones.

- `docs/invariant-index.md` is DERIVED. Never hand-edit it: change the arm header and re-run
  `scripts/render-invariant-index.sh`. An invariant declares itself by OPENING its arm header with its ID,
  closed by a colon.
- A closed VOCABULARY is bound the same way: `docs/vocabulary-index.md`, rendered by
  `scripts/render-vocabulary-index.sh`. Read it before restating a set from memory; change the OWNER, never
  this file. An arm whose header reads as a vocabulary join carries a `# vocabulary:` marker.

## An instruction that ships its own opt-out is not an instruction

Write the instruction and stop. No decision table beside it, no "for the record" figures, no argument for why
this target and not that one, no sentence telling the reader when the rule need not bind. A genuinely
conditional action states its condition in the numbered action list, where the executor decides it
deliberately. This applies to what is written into `CLAUDE.md` too; `validate-plan-shape.sh`'s P7 flags one
form.

## Before adding a check, measure its false-positive set

Ship it only if you have run it and the set is empty or enumerated.

## Build process

Builder:
1. Create a worktree outside the repo, detached at `origin/main`.
2. Decide the change from the code and the record (gate logs, `.git/ai-dlc-fixture-durations`, the backlog entry).
3. Make one commit on `origin/main`, carrying the entry's LANDED or PARTIAL line. When the change alters what
   `install.sh` ships, the subject, `VERSION` and the CHANGELOG heading name the next version and the commit
   runs `scripts/backlog-rotate.sh --apply`; otherwise the subject names no version.
4. Run `bash -n` on every edited script, one probe that fails without the change plus a mutant it kills (by
   hand, once; the output goes in the sha message, never into a fixture), and each fixture you edited, once.
5. Run `bash scripts/pregate-self-check.sh` on the exact tree (`--member` when it edits `.githooks/pre-push`).
6. Send the lead the sha and remove your worktree.

Lead:
1. Squash commits that ship together into one commit on `origin/main`; rerun builder step 5 on that tree.
2. Call the advisor in its own message, then push from a clean worktree at that sha, backgrounded, to a named
   branch, with the exit written to a file.
3. On a red, send each failing unit from the log to its owner.
4. If `origin/main` moved since the push, rebase, rerun builder step 5 and push again. Then `gh pr create` and
   `gh pr merge --squash`, subject and body from files.
5. Verify once: `origin/main`'s tree equals the pushed tree, with the previous main tree as a DIFF control.
6. Detach the main checkout at the new `origin/main`.

While builder sessions are active, the lead runs the roll call in `docs/roll-call.md` every 45 minutes, as written.

## Releases

Commit subject, `VERSION`, and the `CHANGELOG` heading are one claim, joined at pre-push by
`scripts/validate-release-version.sh`. Squash-merge only single-version branches: a squash of several takes the
first version in the subject. The range arms key on the CHANGELOG heading set across the range. Cut release
branches from `origin/main`, never from a local `main` that may be ahead of it.
